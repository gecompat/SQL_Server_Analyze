USE [DeineDatenbank];
GO

/* Prüft Quellenstatus, Begrenzung und eingeschränkten Zugriff, ohne msdb zu verändern. */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Json nvarchar(max) = NULL;
DECLARE @Status varchar(40) = NULL;
DECLARE @Partial bit = NULL;

EXEC [monitor].[USP_MsdbHealthAnalysis]
      @MaxZeilen = 1
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0
    , @StatusCodeOut = @Status OUTPUT
    , @IsPartialOut = @Partial OUTPUT;

IF COALESCE(ISJSON(@Json), 0) <> 1
   OR @Status NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) > 1
    THROW 54870, N'Der begrenzte msdb-Health-Vertrag ist verletzt.', 1;

SET @Json = NULL;
EXEC [monitor].[USP_MsdbHealthAnalysis]
      @MaxZeilen = 100
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @PrintMeldungen = 0;

IF NOT EXISTS
(
    SELECT 1 FROM OPENJSON(@Json)
    WITH ([Area] varchar(40) '$.Area', [StatusCode] varchar(40) '$.StatusCode', [EvidenceLimit] nvarchar(1000) '$.EvidenceLimit') AS [j]
    WHERE [j].[Area] = 'DATABASE_SIZE'
      AND [j].[StatusCode] IN ('AVAILABLE', 'SOURCE_UNAVAILABLE')
      AND NULLIF([j].[EvidenceLimit], N'') IS NOT NULL
)
    THROW 54871, N'Die msdb-Größen- oder Quellenstatusevidenz fehlt.', 1;

IF EXISTS
(
    SELECT [ExpectedArea]
    FROM (VALUES
        ('BACKUP_HISTORY'),
        ('RESTORE_HISTORY'),
        ('AGENT_HISTORY'),
        ('DATABASE_MAIL'),
        ('MAINTENANCE_PLAN')
    ) AS [e]([ExpectedArea])
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM OPENJSON(@Json)
        WITH
        (
              [Area] varchar(40) '$.Area'
            , [RowCount] bigint '$.RowCount'
            , [StatusCode] varchar(40) '$.StatusCode'
        ) AS [j]
        WHERE [j].[Area] = [e].[ExpectedArea]
    )
)
    THROW 54873, N'Eine erwartete msdb-Historienquelle fehlt im Resultset.', 1;

IF EXISTS
(
    SELECT 1
    FROM OPENJSON(@Json)
    WITH
    (
          [Area] varchar(40) '$.Area'
        , [RowCount] bigint '$.RowCount'
        , [StatusCode] varchar(40) '$.StatusCode'
    ) AS [j]
    WHERE [j].[Area] IN
          ('BACKUP_HISTORY','RESTORE_HISTORY','AGENT_HISTORY','DATABASE_MAIL','MAINTENANCE_PLAN')
      AND
      (
          [j].[StatusCode] NOT IN ('AVAILABLE','UNSUPPORTED','SOURCE_UNAVAILABLE')
          OR ([j].[StatusCode] = 'AVAILABLE' AND [j].[RowCount] IS NULL)
          OR ([j].[StatusCode] = 'UNSUPPORTED' AND [j].[RowCount] IS NOT NULL)
          OR ([j].[StatusCode] = 'SOURCE_UNAVAILABLE' AND [j].[RowCount] IS NOT NULL)
      )
)
    THROW 54874, N'Der msdb-Historienquellenstatus ist nicht konsistent.', 1;

DROP USER IF EXISTS [ExampleOps008RestrictedUser];
CREATE USER [ExampleOps008RestrictedUser] WITHOUT LOGIN;
GRANT EXECUTE ON [monitor].[USP_MsdbHealthAnalysis] TO [ExampleOps008RestrictedUser];
BEGIN TRY
    EXECUTE AS USER = N'ExampleOps008RestrictedUser';
    SET @Json = NULL;
    EXEC [monitor].[USP_MsdbHealthAnalysis]
          @MaxZeilen = 20
        , @ResultSetArt = 'NONE'
        , @JsonErzeugen = 1
        , @Json = @Json OUTPUT
        , @PrintMeldungen = 0;
    REVERT;
    IF COALESCE(ISJSON(@Json), 0) <> 1
        THROW 54872, N'Der eingeschränkte msdb-Pfad lieferte kein gültiges JSON.', 1;
END TRY
BEGIN CATCH
    IF USER_NAME() = N'ExampleOps008RestrictedUser' REVERT;
    DROP USER IF EXISTS [ExampleOps008RestrictedUser];
    THROW;
END CATCH;
DROP USER [ExampleOps008RestrictedUser];
GO
