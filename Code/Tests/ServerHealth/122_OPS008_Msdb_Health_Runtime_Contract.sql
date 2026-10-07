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

/* Die vorhandene Database-Mail-View muss als lesbare Quelle erkannt werden. */
IF OBJECT_ID(N'msdb.dbo.sysmail_allitems', N'V') IS NOT NULL
   AND EXISTS
   (
       SELECT COUNT_BIG(*), CONVERT(datetime2(3), MIN([send_request_date])),
              CONVERT(datetime2(3), MAX([send_request_date]))
       FROM [msdb].[dbo].[sysmail_allitems] WITH (NOLOCK)
       EXCEPT
       SELECT [j].[RowCount], [j].[OldestUtc], [j].[NewestUtc]
       FROM OPENJSON(@Json)
       WITH
       (
             [Area] varchar(40) '$.Area'
           , [SourceObject] nvarchar(256) '$.SourceObject'
           , [RowCount] bigint '$.RowCount'
           , [OldestUtc] datetime2(3) '$.OldestUtc'
           , [NewestUtc] datetime2(3) '$.NewestUtc'
           , [StatusCode] varchar(40) '$.StatusCode'
       ) AS [j]
       WHERE [j].[Area] = 'DATABASE_MAIL'
         AND [j].[SourceObject] = N'msdb.dbo.sysmail_allitems'
         AND [j].[StatusCode] = 'AVAILABLE'
   )
    THROW 54875, N'Die vorhandene Database-Mail-View fehlt als verfügbare Aggregatquelle.', 1;

/* Agent-Historie zählt Job- und Stepzeilen; Zeitgrenzen werden nicht ermittelt. */
IF EXISTS
(
    SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobhistory] WITH (NOLOCK)
    EXCEPT
    SELECT [j].[RowCount] FROM OPENJSON(@Json)
    WITH ([Area] varchar(40), [RowCount] bigint, [StatusCode] varchar(40)) AS [j]
    WHERE [j].[Area] = 'AGENT_HISTORY' AND [j].[StatusCode] = 'AVAILABLE'
)
    THROW 54876, N'Die Agent-Historienanzahl stimmt nicht mit der nativen Quelle überein.', 1;
IF EXISTS
(
    SELECT 1 FROM OPENJSON(@Json)
    WITH ([Area] varchar(40), [OldestUtc] datetime2(3), [NewestUtc] datetime2(3)) AS [j]
    WHERE [j].[Area] = 'AGENT_HISTORY'
      AND ([j].[OldestUtc] IS NOT NULL OR [j].[NewestUtc] IS NOT NULL)
)
    THROW 54877, N'Der Agent-Aggregatvertrag darf keine unbelegten Zeitgrenzen ausgeben.', 1;

/* NULL und 0 liefern alle Quellen; positive Limits gelten für jeden Consumer. */
DECLARE @ExpectedRows int = (SELECT COUNT(*) FROM OPENJSON(@Json));
DECLARE @LimitCase int = 0, @Limit int, @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
CREATE TABLE [#MsdbConsole122]
(
    [Ergebnis] nvarchar(200), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
WHILE @LimitCase < 3
BEGIN
    SET @Limit = CASE @LimitCase WHEN 0 THEN NULL WHEN 1 THEN 0 ELSE 1 END;
    CREATE TABLE [#MsdbTable122] ([Dummy] int);
    EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = @Limit,
        @ResultSetArt = 'TABLE', @ResultTablesJson = N'{"msdbHealth":"#MsdbTable122"}',
        @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
    EXEC [sys].[sp_executesql]
        N'SELECT @RowsJson = (SELECT * FROM [#MsdbTable122] ORDER BY [Area] FOR JSON PATH);',
        N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
    IF @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS <> @Json COLLATE SQL_Latin1_General_CP1_CS_AS
       OR (SELECT COUNT(*) FROM OPENJSON(@Json)) <> CASE WHEN @Limit = 1 THEN 1 ELSE @ExpectedRows END
        THROW 54878, N'Die TABLE-/JSON-Limitparität ist verletzt.', 1;
    DROP TABLE [#MsdbTable122];

    TRUNCATE TABLE [#MsdbConsole122];
    INSERT [#MsdbConsole122]
    EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = @Limit,
        @ResultSetArt = 'CONSOLE', @JsonErzeugen = 1, @Json = @Json OUTPUT, @PrintMeldungen = 0;
    SELECT @ConsoleJson = (SELECT [Area], [SourceObject], [RowCount], [OldestUtc],
        [NewestUtc], [SizeMb], [StatusCode], [EvidenceLimit]
        FROM [#MsdbConsole122] ORDER BY [Area] FOR JSON PATH);
    IF @ConsoleJson COLLATE SQL_Latin1_General_CP1_CS_AS <> @Json COLLATE SQL_Latin1_General_CP1_CS_AS
       OR @ConsoleJson COLLATE SQL_Latin1_General_CP1_CS_AS <> @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
       OR EXISTS (SELECT 1 FROM [#MsdbConsole122] WHERE [Ergebnis] IS NULL OR [Ergebnis] <> N'msdbHealth')
        THROW 54879, N'Die CONSOLE-/TABLE-/JSON-Limitparität ist verletzt.', 1;
    SET @LimitCase += 1;
END;
DROP TABLE [#MsdbConsole122];

EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = -1,
    @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT,
    @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT;
IF @Status <> 'INVALID_PARAMETER' OR @Partial <> 1 OR @Json <> N'[]'
    THROW 54950, N'Das negative Mengenlimit muss als Parameterstatus mit leerem JSON enden.', 1;

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
