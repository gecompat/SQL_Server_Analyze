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

/* Dieser zweite Callerfall bindet einen gezielten DMV-DENY an eigene Server- und Datenbankprincipals. */
DECLARE @OwnSuffix nvarchar(32)=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
        @OwnLogin sysname,@OwnUser sysname,@OwnDatabase sysname=DB_NAME(),
        @OwnSid varbinary(16)=CRYPT_GEN_RANDOM(16),@OwnSidHex nvarchar(34),
        @OwnSessionIdInt int=@@SPID,
        @OwnSessionId nvarchar(20)=CONVERT(nvarchar(20),@@SPID),
        @OwnCredential nvarchar(128)=N'Example!'+CONVERT(nvarchar(36),NEWID()),
        @OwnSql nvarchar(max),@OwnMajor int=TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')),
        @OwnLoginId int=NULL,@OwnMasterUserId int=NULL,@OwnDatabaseUserId int=NULL,
        @OwnMadeLogin bit=0,@OwnMadeMasterUser bit=0,@OwnMadeDatabaseUser bit=0,
        @OwnImpersonating bit=0,@OwnNativeCount bigint=NULL,@OwnDirectError int=NULL,
        @OwnJson nvarchar(max)=NULL,@OwnStatus varchar(40)=NULL,@OwnPartial bit=NULL,
        @OwnError int=NULL,@OwnMessage nvarchar(2048)=NULL,@OwnReturn int=NULL,
        @OwnOriginalLoginSid varbinary(85)=SUSER_SID(),@OwnOriginalUser sysname=USER_NAME(),
        @OwnOriginalOptions int=@@OPTIONS,@OwnOriginalTransactions int=@@TRANCOUNT,
        @OwnOriginalLockTimeout int=@@LOCK_TIMEOUT,@OwnOriginalXact int,
        @OwnBeforeOptions int,@OwnBeforeTransactions int,@OwnBeforeLockTimeout int,
        @OwnBeforeXact int,@OwnAfterXact int,@OwnIdentityMatch int,@OwnOptionsMatch int,
        @OwnTransactionsMatch int,@OwnLockMatch int,@OwnXactMatch int,
        @OwnStatusDenied int,@OwnPartialMatch int,@OwnJsonEmpty int,
        @OwnDirectDiagnostic int,@OwnProductDiagnostic int,
        @OwnReturnDiagnostic int,@OwnMessagePresent int;
SELECT @OwnOriginalXact=XACT_STATE();
SELECT @OwnLogin=N'ExampleOps007Denied_'+@OwnSuffix,
       @OwnUser=N'ExampleOps007Denied_'+@OwnSuffix,
       @OwnSidHex=CONVERT(nvarchar(34),@OwnSid,1);
IF @OwnOriginalTransactions<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
   OR (@OwnMajor IS NULL OR @OwnMajor NOT IN(15,16,17)) OR DATALENGTH(@OwnSid)<>16
    THROW 58060,N'OPS007 dedicated denial requires an isolated supported sysadmin target.',1;
IF EXISTS(SELECT 1 FROM [sys].[server_principals]
          WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS
             OR [sid]=@OwnSid)
   OR EXISTS(SELECT 1 FROM [sys].[database_principals]
          WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
             OR [sid]=@OwnSid)
   OR EXISTS(SELECT 1 FROM [master].[sys].[database_principals]
          WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
             OR [sid]=@OwnSid)
    THROW 58061,N'OPS007 dedicated denial principal collision.',1;
BEGIN TRY
    SET @OwnSql=N'USE [master]; CREATE LOGIN '+QUOTENAME(@OwnLogin)
        +N' WITH PASSWORD '+N'= '+QUOTENAME(@OwnCredential,'''')
        +N', SID = '+@OwnSidHex+N', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;';
    EXEC [master].[sys].[sp_executesql] @OwnSql;
    SET @OwnMadeLogin=1;
    SET @OwnCredential=NULL; SET @OwnSql=NULL;
    SELECT @OwnLoginId=[principal_id] FROM [sys].[server_principals]
      WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS
        AND [sid]=@OwnSid;
    IF @OwnLoginId IS NULL
        THROW 58062,N'OPS007 own login SID binding failed.',1;
    IF @OwnMajor=15
        SET @OwnSql=N'USE [master]; GRANT VIEW SERVER STATE TO '+QUOTENAME(@OwnLogin)+N';';
    ELSE
        SET @OwnSql=N'USE [master]; GRANT VIEW SERVER PERFORMANCE STATE TO '+QUOTENAME(@OwnLogin)+N';';
    EXEC [master].[sys].[sp_executesql] @OwnSql;
    SET @OwnSql=N'USE '+QUOTENAME(@OwnDatabase)+N'; CREATE USER '+QUOTENAME(@OwnUser)
        +N' FOR LOGIN '+QUOTENAME(@OwnLogin)+N';';
    EXEC [sys].[sp_executesql] @OwnSql;
    SET @OwnMadeDatabaseUser=1;
    SELECT @OwnDatabaseUserId=[principal_id] FROM [sys].[database_principals]
      WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
        AND [sid]=@OwnSid;
    IF @OwnDatabaseUserId IS NULL
        THROW 58063,N'OPS007 own framework user SID binding failed.',1;
    SET @OwnSql=N'USE '+QUOTENAME(@OwnDatabase)+N'; GRANT EXECUTE ON [monitor].[USP_CurrentCursorAnalysis] TO '
        +QUOTENAME(@OwnUser)+N';';
    EXEC [sys].[sp_executesql] @OwnSql;
    SET @OwnSql=N'USE [master]; CREATE USER '+QUOTENAME(@OwnUser)+N' FOR LOGIN '
        +QUOTENAME(@OwnLogin)+N';';
    EXEC [master].[sys].[sp_executesql] @OwnSql;
    SET @OwnMadeMasterUser=1;
    SELECT @OwnMasterUserId=[principal_id] FROM [master].[sys].[database_principals]
      WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
        AND [sid]=@OwnSid;
    IF @OwnMasterUserId IS NULL
        THROW 58064,N'OPS007 own master user SID binding failed.',1;

    EXECUTE AS LOGIN=@OwnLogin;
    SET @OwnImpersonating=1;
    IF SUSER_SID()<>@OwnSid OR USER_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS
       <>@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
       OR DB_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS
       <>@OwnDatabase COLLATE SQL_Latin1_General_CP1_CS_AS
        THROW 58065,N'OPS007 native pre-DENY caller identity differs.',1;
    EXEC [sys].[sp_executesql]
        N'SELECT @Count=COUNT_BIG(*) FROM [sys].[dm_exec_cursors](@SessionId);',
        N'@SessionId int,@Count bigint OUTPUT',@SessionId=@OwnSessionIdInt,@Count=@OwnNativeCount OUTPUT;
    IF @OwnNativeCount IS NULL
        THROW 58065,N'OPS007 native pre-DENY source read did not complete.',1;
    REVERT; SET @OwnImpersonating=0;

    SET @OwnSql=N'USE [master]; DENY SELECT ON [sys].[dm_exec_cursors] TO '
        +QUOTENAME(@OwnUser)+N';';
    EXEC [master].[sys].[sp_executesql] @OwnSql;
    EXECUTE AS LOGIN=@OwnLogin;
    SET @OwnImpersonating=1;
    SELECT @OwnBeforeOptions=@@OPTIONS,@OwnBeforeTransactions=@@TRANCOUNT,
           @OwnBeforeLockTimeout=@@LOCK_TIMEOUT;
    SELECT @OwnBeforeXact=XACT_STATE();
    SET @OwnNativeCount=NULL;
    BEGIN TRY
        EXEC [sys].[sp_executesql]
            N'SELECT @Count=COUNT_BIG(*) FROM [sys].[dm_exec_cursors](@SessionId);',
            N'@SessionId int,@Count bigint OUTPUT',@SessionId=@OwnSessionIdInt,@Count=@OwnNativeCount OUTPUT;
    END TRY
    BEGIN CATCH
        SET @OwnDirectError=ERROR_NUMBER();
    END CATCH;
    SET @OwnDirectDiagnostic=COALESCE(@OwnDirectError,-1);
    IF @OwnDirectDiagnostic<>229
    BEGIN
        RAISERROR(N'OPS007_DENY_DIRECT direct=%d',10,1,@OwnDirectDiagnostic) WITH NOWAIT;
        THROW 58066,N'OPS007 direct native DMV DENY did not yield SQL 229.',1;
    END;

    EXEC @OwnReturn=[monitor].[USP_CurrentCursorAnalysis]
          @IncludeCursorDetails=1,@SessionIds=@OwnSessionId,@ResultSetArt='NONE',
          @JsonErzeugen=1,@Json=@OwnJson OUTPUT,@PrintMeldungen=0,
          @StatusCodeOut=@OwnStatus OUTPUT,@IsPartialOut=@OwnPartial OUTPUT,
          @ErrorNumberOut=@OwnError OUTPUT,@ErrorMessageOut=@OwnMessage OUTPUT;
    SELECT @OwnAfterXact=XACT_STATE();
    SELECT @OwnIdentityMatch=CASE WHEN SUSER_SID()=@OwnSid
        AND USER_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
        AND DB_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnDatabase COLLATE SQL_Latin1_General_CP1_CS_AS THEN 1 ELSE 0 END,
      @OwnOptionsMatch=CASE WHEN @@OPTIONS=@OwnBeforeOptions THEN 1 ELSE 0 END,
      @OwnTransactionsMatch=CASE WHEN @@TRANCOUNT=@OwnBeforeTransactions THEN 1 ELSE 0 END,
      @OwnLockMatch=CASE WHEN @@LOCK_TIMEOUT=@OwnBeforeLockTimeout THEN 1 ELSE 0 END,
      @OwnXactMatch=CASE WHEN @OwnAfterXact=@OwnBeforeXact THEN 1 ELSE 0 END,
      @OwnStatusDenied=CASE WHEN @OwnStatus COLLATE SQL_Latin1_General_CP1_CS_AS='DENIED_PERMISSION' THEN 1 ELSE 0 END,
      @OwnPartialMatch=CASE WHEN @OwnPartial=1 THEN 1 ELSE 0 END,
      @OwnJsonEmpty=CASE WHEN COALESCE(ISJSON(@OwnJson),0)=1
        AND DATALENGTH(@OwnJson)=4
        AND @OwnJson COLLATE SQL_Latin1_General_CP1_CS_AS=N'[]' THEN 1 ELSE 0 END;
    SELECT @OwnProductDiagnostic=COALESCE(@OwnError,-1),
           @OwnReturnDiagnostic=COALESCE(@OwnReturn,-1),
           @OwnMessagePresent=CASE WHEN NULLIF(@OwnMessage,N'') IS NOT NULL THEN 1 ELSE 0 END;
    IF @OwnDirectError<>229 OR @OwnProductDiagnostic<>229
       OR @OwnMessagePresent<>1 OR @OwnStatusDenied<>1
       OR @OwnPartialMatch<>1 OR @OwnJsonEmpty<>1 OR @OwnIdentityMatch<>1
       OR @OwnOptionsMatch<>1 OR @OwnTransactionsMatch<>1
       OR @OwnLockMatch<>1 OR @OwnXactMatch<>1
    BEGIN
        RAISERROR(N'OPS007_DENY direct=%d product=%d return=%d message=%d status=%d partial=%d json=%d identity=%d options=%d tran=%d lock=%d xact=%d',
          10,1,@OwnDirectDiagnostic,@OwnProductDiagnostic,@OwnReturnDiagnostic,@OwnMessagePresent,
          @OwnStatusDenied,@OwnPartialMatch,@OwnJsonEmpty,@OwnIdentityMatch,
          @OwnOptionsMatch,@OwnTransactionsMatch,@OwnLockMatch,@OwnXactMatch) WITH NOWAIT;
        THROW 58067,N'OPS007 product DMV DENY or caller-state contract failed.',1;
    END;
    REVERT; SET @OwnImpersonating=0;
    IF SUSER_SID()<>@OwnOriginalLoginSid OR USER_NAME() COLLATE SQL_Latin1_General_CP1_CS_AS
       <>@OwnOriginalUser COLLATE SQL_Latin1_General_CP1_CS_AS
       OR @@OPTIONS<>@OwnOriginalOptions OR @@TRANCOUNT<>@OwnOriginalTransactions
       OR @@LOCK_TIMEOUT<>@OwnOriginalLockTimeout
        THROW 58068,N'OPS007 original caller state after REVERT differs.',1;
    SELECT @OwnAfterXact=XACT_STATE();
    IF @OwnAfterXact<>@OwnOriginalXact
        THROW 58068,N'OPS007 original transaction state after REVERT differs.',1;

    IF NOT EXISTS(SELECT 1 FROM [master].[sys].[database_principals]
        WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
          AND [sid]=@OwnSid AND [principal_id]=@OwnMasterUserId)
        THROW 58068,N'OPS007 own master user binding changed before cleanup.',1;
    SET @OwnSql=N'USE [master]; REVOKE SELECT ON [sys].[dm_exec_cursors] FROM '
        +QUOTENAME(@OwnUser)+N'; DROP USER '+QUOTENAME(@OwnUser)+N';';
    EXEC [master].[sys].[sp_executesql] @OwnSql; SET @OwnMadeMasterUser=0;
    IF NOT EXISTS(SELECT 1 FROM [sys].[database_principals]
        WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
          AND [sid]=@OwnSid AND [principal_id]=@OwnDatabaseUserId)
        THROW 58068,N'OPS007 own framework user binding changed before cleanup.',1;
    SET @OwnSql=N'USE '+QUOTENAME(@OwnDatabase)+N'; DROP USER '+QUOTENAME(@OwnUser)+N';';
    EXEC [sys].[sp_executesql] @OwnSql; SET @OwnMadeDatabaseUser=0;
    IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals]
        WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS
          AND [sid]=@OwnSid AND [principal_id]=@OwnLoginId)
        THROW 58068,N'OPS007 own login binding changed before cleanup.',1;
    IF @OwnMajor=15
        SET @OwnSql=N'USE [master]; REVOKE VIEW SERVER STATE FROM '+QUOTENAME(@OwnLogin)+N';';
    ELSE
        SET @OwnSql=N'USE [master]; REVOKE VIEW SERVER PERFORMANCE STATE FROM '+QUOTENAME(@OwnLogin)+N';';
    SET @OwnSql+=N' DROP LOGIN '+QUOTENAME(@OwnLogin)+N';';
    EXEC [master].[sys].[sp_executesql] @OwnSql; SET @OwnMadeLogin=0;
    SET @OwnSql=NULL;
    IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [sid]=@OwnSid)
       OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [sid]=@OwnSid)
       OR EXISTS(SELECT 1 FROM [master].[sys].[database_principals] WHERE [sid]=@OwnSid)
       OR SUSER_SID()<>@OwnOriginalLoginSid OR @@OPTIONS<>@OwnOriginalOptions
       OR @@TRANCOUNT<>@OwnOriginalTransactions OR @@LOCK_TIMEOUT<>@OwnOriginalLockTimeout
        THROW 58069,N'OPS007 dedicated denial cleanup or caller state failed.',1;
    SELECT @OwnAfterXact=XACT_STATE();
    IF @OwnAfterXact<>@OwnOriginalXact
        THROW 58069,N'OPS007 dedicated denial transaction state failed.',1;
END TRY
BEGIN CATCH
    IF @OwnImpersonating=1 REVERT;
    SET @OwnCredential=NULL; SET @OwnSql=NULL;
    BEGIN TRY
        IF @OwnMadeMasterUser=1 AND EXISTS(SELECT 1 FROM [master].[sys].[database_principals]
           WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
             AND [sid]=@OwnSid AND (@OwnMasterUserId IS NULL OR [principal_id]=@OwnMasterUserId))
        BEGIN
            SET @OwnSql=N'USE [master]; DROP USER '+QUOTENAME(@OwnUser)+N';';
            EXEC [master].[sys].[sp_executesql] @OwnSql;
        END;
        IF @OwnMadeDatabaseUser=1 AND EXISTS(SELECT 1 FROM [sys].[database_principals]
           WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnUser COLLATE SQL_Latin1_General_CP1_CS_AS
             AND [sid]=@OwnSid AND (@OwnDatabaseUserId IS NULL OR [principal_id]=@OwnDatabaseUserId))
        BEGIN
            SET @OwnSql=N'USE '+QUOTENAME(@OwnDatabase)+N'; DROP USER '+QUOTENAME(@OwnUser)+N';';
            EXEC [sys].[sp_executesql] @OwnSql;
        END;
        IF @OwnMadeLogin=1 AND EXISTS(SELECT 1 FROM [sys].[server_principals]
           WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnLogin COLLATE SQL_Latin1_General_CP1_CS_AS
             AND [sid]=@OwnSid AND (@OwnLoginId IS NULL OR [principal_id]=@OwnLoginId))
        BEGIN
            SET @OwnSql=N'USE [master]; DROP LOGIN '+QUOTENAME(@OwnLogin)+N';';
            EXEC [master].[sys].[sp_executesql] @OwnSql;
        END;
        IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [sid]=@OwnSid)
           OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [sid]=@OwnSid)
           OR EXISTS(SELECT 1 FROM [master].[sys].[database_principals] WHERE [sid]=@OwnSid)
            THROW 58069,N'OPS007 owned principal cleanup remained incomplete.',1;
    END TRY
    BEGIN CATCH
        THROW 58069,N'OPS007 owned principal cleanup failed.',1;
    END CATCH;
    THROW;
END CATCH;
GO
