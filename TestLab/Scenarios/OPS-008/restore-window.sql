USE [DeineDatenbank];
GO

/* Verwendet ausschließlich die vom neuen Lab-Runner erzeugte Backupfixture. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable'
      AND CONVERT(int,[value]) = 1
)
   OR DB_ID(N'ExampleOps008History') IS NULL
   OR DB_ID(N'ExampleOps008Restored') IS NOT NULL
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[restorehistory])
    THROW 54888, N'Die ausschließlich eigene Restorefixture ist nicht eindeutig vorbereitet.', 1;

DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit;
DECLARE @Stage int = 1, @RestoreId int, @ExpectedDate datetime2(3);
DECLARE @ShortStart datetime2(3) = '2025-01-01T12:00:00';
DECLARE @ShortEnd datetime2(3) = '2025-01-02T12:00:00';
DECLARE @LongStart datetime2(3) = '2000-01-01T12:00:00';
WHILE @Stage <= 3
BEGIN
    RESTORE DATABASE [ExampleOps008Restored]
        FROM DISK = N'/var/opt/mssql/data/ExampleOps008History.bak'
        WITH MOVE N'ExampleOps008History' TO N'/var/opt/mssql/data/ExampleOps008Restored.mdf',
             MOVE N'ExampleOps008History_log' TO N'/var/opt/mssql/data/ExampleOps008Restored_log.ldf',
             REPLACE;
    SELECT @RestoreId = MAX([restore_history_id]) FROM [msdb].[dbo].[restorehistory]
        WHERE [destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008Restored';
    SET @ExpectedDate = CASE @Stage WHEN 1 THEN @ShortStart WHEN 2 THEN @ShortEnd ELSE @LongStart END;
    UPDATE [msdb].[dbo].[restorehistory] SET [restore_date] = @ExpectedDate
        WHERE [restore_history_id] = @RestoreId
          AND [destination_database_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008Restored';
    IF @@ROWCOUNT <> 1
        THROW 54889, N'Der neue synthetische Restoredatensatz wurde nicht eindeutig gefunden.', 1;
    EXEC [monitor].[USP_MsdbHealthAnalysis]
        @MaxZeilen = 0, @ResultSetArt = 'NONE', @JsonErzeugen = 1,
        @Json = @Json OUTPUT, @PrintMeldungen = 0,
        @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT;
    IF @Status <> 'AVAILABLE' OR @Partial <> 0 OR NOT EXISTS
    (
        SELECT 1 FROM OPENJSON(@Json)
        WITH ([Area] varchar(40), [RowCount] bigint, [OldestUtc] datetime2(3),
              [NewestUtc] datetime2(3), [StatusCode] varchar(40))
        WHERE [Area] = 'RESTORE_HISTORY' AND [StatusCode] = 'AVAILABLE' AND [RowCount] = @Stage
          AND [OldestUtc] = CASE WHEN @Stage = 3 THEN @LongStart ELSE @ShortStart END
          AND [NewestUtc] = CASE WHEN @Stage = 1 THEN @ShortStart ELSE @ShortEnd END
    )
        THROW 54890, N'Die kontrollierte Restoreanzahl oder deren Zeitfenster ist nicht korrekt.', 1;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[restorehistory]) <> @Stage
        THROW 54891, N'Der Analyzer hat die kontrollierte Restoreanzahl verändert.', 1;
    SET @Stage += 1;
END;

GO
