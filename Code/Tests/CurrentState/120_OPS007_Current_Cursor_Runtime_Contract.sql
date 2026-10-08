USE [DeineDatenbank];
GO

/* Prüft Opt-in, Einzelsession, Cursorbefund sowie positive, unbegrenzte und negative Zeilenlimits mit synthetischen Daten. TABLE und JSON werden auf derselben Materialisierung verglichen. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;
DECLARE @Partial bit = NULL;
DECLARE @SessionId nvarchar(20) = CONVERT(nvarchar(20), @@SPID);
DECLARE @Synthetic TABLE([SyntheticId] int NOT NULL PRIMARY KEY);
INSERT @Synthetic VALUES (1), (2), (3);

EXEC [monitor].[USP_CurrentCursorAnalysis]
      @IncludeCursorDetails = 0
    , @SessionIds = @SessionId
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0
    , @StatusCodeOut = @Status OUTPUT
    , @IsPartialOut = @Partial OUTPUT;
IF @Status <> 'NOT_EXECUTED' OR @Partial <> 0 OR COALESCE(ISJSON(@Json), 0) <> 1
    THROW 54880, N'Der sichere Cursor-Defaultvertrag ist verletzt.', 1;

SET @Json = NULL;
SET @Status = NULL;
EXEC [monitor].[USP_CurrentCursorAnalysis]
      @IncludeCursorDetails = 1
    , @SessionIds = N'1|2'
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0
    , @StatusCodeOut = @Status OUTPUT;
IF @Status <> 'INVALID_PARAMETER'
    THROW 54881, N'Die Einzelsessionbegrenzung ist verletzt.', 1;

DECLARE [ExampleOps007Cursor] CURSOR LOCAL STATIC FOR
    SELECT [SyntheticId] FROM @Synthetic ORDER BY [SyntheticId];
DECLARE [ExampleOps007DormantCursor] CURSOR LOCAL STATIC FOR
    SELECT [SyntheticId] FROM @Synthetic ORDER BY [SyntheticId];
BEGIN TRY
    OPEN [ExampleOps007Cursor];
    FETCH NEXT FROM [ExampleOps007Cursor];
    SET @Json = NULL;
    SET @Status = NULL;
    EXEC [monitor].[USP_CurrentCursorAnalysis]
          @IncludeCursorDetails = 1
        , @SessionIds = @SessionId
        , @MaxZeilen = 1
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT;
    IF @Status NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 1
       OR NOT EXISTS
          (
              SELECT 1 FROM OPENJSON(@Json)
              WITH ([CursorName] nvarchar(256) '$.CursorName') AS [j]
              WHERE [j].[CursorName] = N'ExampleOps007Cursor'
          )
        THROW 54882, N'Der begrenzte aktive Cursorvertrag ist verletzt.', 1;
    /* NULL und 0 erhalten das native Inventar; negative Grenzen liefern den bestehenden Parameterstatus. */
    DECLARE [ExampleOps007LimitCursor] CURSOR LOCAL STATIC FOR
        SELECT [SyntheticId] FROM @Synthetic ORDER BY [SyntheticId];
    OPEN [ExampleOps007LimitCursor];
    DECLARE @LimitFetched int;
    FETCH NEXT FROM [ExampleOps007LimitCursor] INTO @LimitFetched;
    DECLARE @ExpectedCursors TABLE
        ([CursorId] int NOT NULL PRIMARY KEY,[IsOpen] bit,[FetchStatus] int);
    INSERT @ExpectedCursors
        SELECT [cursor_id],[is_open],[fetch_status] FROM [sys].[dm_exec_cursors](@@SPID);
    IF (SELECT COUNT(*) FROM @ExpectedCursors WHERE [IsOpen]=1)<2
        THROW 54885,N'Die positive Mehrcursorfixture fehlt.',1;
    DECLARE @Case int=1,@Limit int,@LimitMode varchar(16),@LimitMapping nvarchar(max);
    DECLARE @LimitError int,@LimitMessage nvarchar(2048);
    DECLARE @LimitLock int=@@LOCK_TIMEOUT,@LimitOptions int=@@OPTIONS,
        @LimitTran int,@LimitXact int;
    SET @LimitXact=XACT_STATE();
    SET @LimitTran=@@TRANCOUNT;
    WHILE @Case<=6
    BEGIN
        SELECT @Limit=CASE WHEN @Case IN(1,4) THEN NULL WHEN @Case IN(2,5) THEN 0 ELSE -1 END,
            @LimitMode=CASE WHEN @Case<=3 THEN 'NONE' ELSE 'TABLE' END;
        SET @LimitMapping=CASE WHEN @LimitMode='TABLE' THEN N'{"cursors":"#ExampleOps007LimitExport"}' ELSE NULL END;
        DROP TABLE IF EXISTS [#ExampleOps007LimitExport];
        CREATE TABLE [#ExampleOps007LimitExport]([Seed] int NULL);
        SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@LimitError=NULL,@LimitMessage=NULL;
        EXEC [monitor].[USP_CurrentCursorAnalysis]
            @IncludeCursorDetails=1,@SessionIds=@SessionId,@MaxZeilen=@Limit,
            @ResultSetArt=@LimitMode,@ResultTablesJson=@LimitMapping,
            @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
            @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
            @ErrorNumberOut=@LimitError OUTPUT,@ErrorMessageOut=@LimitMessage OUTPUT;
        DECLARE @ObservedTran int,@ObservedXact int;
        SET @ObservedXact=XACT_STATE();
        SET @ObservedTran=@@TRANCOUNT;
        IF @@LOCK_TIMEOUT<>@LimitLock OR @@OPTIONS<>@LimitOptions
            OR @ObservedTran<>@LimitTran OR @ObservedXact<>@LimitXact
            THROW 54886,N'Der Cursoraufruf verändert den Callerzustand.',1;
        IF COALESCE(ISJSON(@Json),0)<>1
            THROW 54887,N'Der Cursorlimitvertrag liefert kein JSON-Array.',1;
        IF @Limit<0
        BEGIN
            IF @Status IS NULL OR @Status<>'INVALID_PARAMETER' OR @Partial IS NULL OR @Partial<>1
                OR @LimitError IS NOT NULL OR @LimitMessage IS NULL
                OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>0
                OR EXISTS(SELECT 1 FROM [#ExampleOps007LimitExport])
                THROW 54888,N'Der negative Cursorlimitvertrag ist verletzt.',1;
        END
        ELSE
        BEGIN
            IF @Status IS NULL OR @Status<>'AVAILABLE' OR @Partial IS NULL OR @Partial<>0
                OR @LimitError IS NOT NULL OR @LimitMessage IS NOT NULL
                OR (SELECT COUNT(*) FROM OPENJSON(@Json))<>(SELECT COUNT(*) FROM @ExpectedCursors)
                THROW 54889,N'NULL oder 0 begrenzt das Cursorinventar.',1;
            IF EXISTS
            (
                SELECT [CursorId],[IsOpen],[FetchStatus] FROM @ExpectedCursors
                EXCEPT
                SELECT [CursorId],[IsOpen],[FetchStatus] FROM OPENJSON(@Json)
                    WITH([CursorId] int,[IsOpen] bit,[FetchStatus] int)
            ) OR EXISTS
            (
                SELECT [CursorId],[IsOpen],[FetchStatus] FROM OPENJSON(@Json)
                    WITH([CursorId] int,[IsOpen] bit,[FetchStatus] int)
                EXCEPT
                SELECT [CursorId],[IsOpen],[FetchStatus] FROM @ExpectedCursors
            )
                THROW 54890,N'Das unbegrenzte Cursorinventar weicht von den nativen Identitäten ab.',1;
            IF @LimitMode='TABLE'
            BEGIN
                DECLARE @TableParityOk bit=0,@ExpectedCursorCount int;
                SELECT @ExpectedCursorCount=COUNT(*) FROM @ExpectedCursors;
                EXEC [sys].[sp_executesql]
                    N'SELECT @Valid=CONVERT(bit,CASE WHEN
                        (SELECT COUNT(*) FROM [#ExampleOps007LimitExport])=@ExpectedCount
                        AND (SELECT COUNT(DISTINCT [CursorId]) FROM [#ExampleOps007LimitExport])=@ExpectedCount
                        AND NOT EXISTS
                        (
                            SELECT * FROM [#ExampleOps007LimitExport]
                            EXCEPT
                            SELECT * FROM OPENJSON(@Payload) WITH
                            ([SessionId] int,[CursorId] int,[CursorName] nvarchar(256),[Properties] nvarchar(256),
                             [CreationTime] datetime,[IsOpen] bit,[FetchStatus] int,[WorkerTime] bigint,
                             [Reads] bigint,[Writes] bigint,[DormantDuration] bigint,[FindingContext] varchar(40))
                        ) THEN 1 ELSE 0 END);',
                    N'@Payload nvarchar(max),@ExpectedCount int,@Valid bit OUTPUT',
                    @Payload=@Json,@ExpectedCount=@ExpectedCursorCount,@Valid=@TableParityOk OUTPUT;
                IF @TableParityOk IS NULL OR @TableParityOk<>1
                    THROW 54891,N'Die zwölf TABLE-Felder weichen von JSON ab.',1;
            END;
        END;
        IF EXISTS
        (
            SELECT [CursorId],[IsOpen],[FetchStatus] FROM @ExpectedCursors
            EXCEPT
            SELECT [cursor_id],[is_open],[fetch_status] FROM [sys].[dm_exec_cursors](@@SPID)
        ) OR (SELECT COUNT(*) FROM [sys].[dm_exec_cursors](@@SPID))<>(SELECT COUNT(*) FROM @ExpectedCursors)
            THROW 54892,N'Der Cursoraufruf verändert das native Inventar.',1;
        SET @Case+=1;
    END;
    CLOSE [ExampleOps007LimitCursor];
    DEALLOCATE [ExampleOps007LimitCursor];
    DROP TABLE [#ExampleOps007LimitExport];
    CLOSE [ExampleOps007Cursor];
    DEALLOCATE [ExampleOps007Cursor];

    OPEN [ExampleOps007DormantCursor];
    WAITFOR DELAY '00:01:01';
    SET @Json = NULL;
    SET @Status = NULL;
    EXEC [monitor].[USP_CurrentCursorAnalysis]
          @IncludeCursorDetails = 1
        , @SessionIds = @SessionId
        , @MaxZeilen = 10
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT;
    IF @Status NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
       OR NOT EXISTS
          (
              SELECT 1 FROM OPENJSON(@Json)
              WITH
              (
                    [CursorName] nvarchar(256) '$.CursorName'
                  , [FindingContext] varchar(40) '$.FindingContext'
              ) AS [j]
              WHERE [j].[CursorName] = N'ExampleOps007DormantCursor'
                AND [j].[FindingContext] = 'DORMANT_CONTEXT'
          )
        THROW 54884, N'Der ruhende Cursorvertrag ist verletzt.', 1;
    CLOSE [ExampleOps007DormantCursor];
    DEALLOCATE [ExampleOps007DormantCursor];
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'ExampleOps007LimitCursor') >= 0 CLOSE [ExampleOps007LimitCursor];
    IF CURSOR_STATUS('local', 'ExampleOps007LimitCursor') > -3 DEALLOCATE [ExampleOps007LimitCursor];
    IF CURSOR_STATUS('local', 'ExampleOps007Cursor') >= 0 CLOSE [ExampleOps007Cursor];
    IF CURSOR_STATUS('local', 'ExampleOps007Cursor') > -3 DEALLOCATE [ExampleOps007Cursor];
    IF CURSOR_STATUS('local', 'ExampleOps007DormantCursor') >= 0 CLOSE [ExampleOps007DormantCursor];
    IF CURSOR_STATUS('local', 'ExampleOps007DormantCursor') > -3 DEALLOCATE [ExampleOps007DormantCursor];
    THROW;
END CATCH;

DROP USER IF EXISTS [ExampleOps007RestrictedUser];
CREATE USER [ExampleOps007RestrictedUser] WITHOUT LOGIN;
GRANT EXECUTE ON [monitor].[USP_CurrentCursorAnalysis] TO [ExampleOps007RestrictedUser];
BEGIN TRY
    EXECUTE AS USER = N'ExampleOps007RestrictedUser';
    SET @Json = NULL;
    SET @Status = NULL;
    SET @Partial = NULL;
    EXEC [monitor].[USP_CurrentCursorAnalysis]
          @IncludeCursorDetails = 1
        , @SessionIds = N'1'
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0
        , @StatusCodeOut = @Status OUTPUT
        , @IsPartialOut = @Partial OUTPUT;
    REVERT;
    IF @Status NOT IN ('DENIED_PERMISSION', 'AVAILABLE_EMPTY')
       OR (@Status = 'DENIED_PERMISSION' AND @Partial <> 1)
       OR (@Status = 'AVAILABLE_EMPTY' AND @Partial <> 0)
       OR COALESCE(ISJSON(@Json), 0) <> 1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 0
        THROW 54883, N'Der eingeschränkte Cursorpfad ist weder als Berechtigungsfehler noch als leere Sicht abgegrenzt.', 1;
END TRY
BEGIN CATCH
    IF USER_NAME() = N'ExampleOps007RestrictedUser' REVERT;
    DROP USER IF EXISTS [ExampleOps007RestrictedUser];
    THROW;
END CATCH;
DROP USER [ExampleOps007RestrictedUser];
GO
