USE [DeineDatenbank];
GO

/* Prüft Opt-in, Einzelsession, Cursorbefund und Zeilenbegrenzung mit einer synthetischen Tabellenvariable. */
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
    CLOSE [ExampleOps007Cursor];
    DEALLOCATE [ExampleOps007Cursor];
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'ExampleOps007Cursor') >= 0 CLOSE [ExampleOps007Cursor];
    IF CURSOR_STATUS('local', 'ExampleOps007Cursor') > -3 DEALLOCATE [ExampleOps007Cursor];
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
