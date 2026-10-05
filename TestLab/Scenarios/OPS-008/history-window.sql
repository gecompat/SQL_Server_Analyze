USE [DeineDatenbank];
GO

/* Verändert ausschließlich die Historien und Dateien des neuen Wegwerf-Labs. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable'
      AND CONVERT(int, [value]) = 1
)
    THROW 54880, N'Der ausschließlich vom neuen Lab-Runner gesetzte Fixturemarker fehlt.', 1;
IF DB_ID(N'ExampleOps008History') IS NOT NULL
    THROW 54881, N'Der synthetische Datenbankname ist bereits belegt.', 1;

DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit;
EXEC [monitor].[USP_MsdbHealthAnalysis]
    @MaxZeilen = 0, @ResultSetArt = 'NONE', @JsonErzeugen = 1,
    @Json = @Json OUTPUT, @PrintMeldungen = 0,
    @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT;
IF @Status <> 'AVAILABLE' OR @Partial <> 0
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
       WITH ([Area] varchar(40), [RowCount] bigint, [OldestUtc] datetime2(3),
             [NewestUtc] datetime2(3), [StatusCode] varchar(40))
       WHERE [Area] IN ('BACKUP_HISTORY','RESTORE_HISTORY','AGENT_HISTORY','DATABASE_MAIL','MAINTENANCE_PLAN')
         AND [StatusCode] = 'AVAILABLE' AND [RowCount] = 0
         AND [OldestUtc] IS NULL AND [NewestUtc] IS NULL) <> 5
    THROW 54882, N'Die kontrollierte leere Historienbasis ist nicht gegeben; keine Historien werden verändert.', 1;

CREATE DATABASE [ExampleOps008History] COLLATE SQL_Latin1_General_CP1_CS_AS;
DECLARE @Stage int = 1, @BackupId int, @ExpectedDate datetime2(3);
DECLARE @ShortStart datetime2(3) = '2025-01-01T12:00:00';
DECLARE @ShortEnd datetime2(3) = '2025-01-02T12:00:00';
DECLARE @LongStart datetime2(3) = '2000-01-01T12:00:00';
WHILE @Stage <= 3
BEGIN
    BACKUP DATABASE [ExampleOps008History]
        TO DISK = N'/var/opt/mssql/data/ExampleOps008History.bak'
        WITH INIT, COPY_ONLY;
    SELECT @BackupId = MAX([backup_set_id]) FROM [msdb].[dbo].[backupset]
        WHERE [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008History';
    SET @ExpectedDate = CASE @Stage WHEN 1 THEN @ShortStart WHEN 2 THEN @ShortEnd ELSE @LongStart END;
    UPDATE [msdb].[dbo].[backupset]
        SET [backup_start_date] = @ExpectedDate, [backup_finish_date] = @ExpectedDate
        WHERE [backup_set_id] = @BackupId
          AND [database_name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'ExampleOps008History';
    IF @@ROWCOUNT <> 1
        THROW 54883, N'Der neu erzeugte synthetische Backupdatensatz wurde nicht eindeutig gefunden.', 1;

    EXEC [monitor].[USP_MsdbHealthAnalysis]
        @MaxZeilen = 0, @ResultSetArt = 'NONE', @JsonErzeugen = 1,
        @Json = @Json OUTPUT, @PrintMeldungen = 0,
        @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT;
    IF @Status <> 'AVAILABLE' OR @Partial <> 0 OR NOT EXISTS
    (
        SELECT 1 FROM OPENJSON(@Json)
        WITH ([Area] varchar(40), [RowCount] bigint, [OldestUtc] datetime2(3),
              [NewestUtc] datetime2(3), [StatusCode] varchar(40))
        WHERE [Area] = 'BACKUP_HISTORY' AND [StatusCode] = 'AVAILABLE'
          AND [RowCount] = @Stage
          AND [OldestUtc] = CASE WHEN @Stage = 3 THEN @LongStart ELSE @ShortStart END
          AND [NewestUtc] = CASE WHEN @Stage = 1 THEN @ShortStart ELSE @ShortEnd END
    )
        THROW 54884, N'Die kontrollierte Backupanzahl oder das kurze beziehungsweise lange Zeitfenster fehlt.', 1;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[backupset]) <> @Stage
        THROW 54885, N'Der Analyzer hat die kontrollierte Historienanzahl verändert.', 1;
    SET @Stage += 1;
END;

DECLARE @SizeBeforeGrowth decimal(19,2), @SizeAfterGrowth decimal(19,2);
SELECT @SizeBeforeGrowth = [SizeMb] FROM OPENJSON(@Json)
    WITH ([Area] varchar(40), [SizeMb] decimal(19,2)) WHERE [Area] = 'DATABASE_SIZE';
DECLARE @FileName sysname, @TargetSizeMb int, @Sql nvarchar(max);
SELECT TOP (1) @FileName = [name], @TargetSizeMb = CEILING([size] / 128.0) + 8
    FROM [msdb].[sys].[database_files] WHERE [type] = 0 ORDER BY [file_id];
IF @FileName IS NULL OR @TargetSizeMb > 128
    THROW 54886, N'Die msdb-Wachstumsfixture überschreitet die begrenzte Lab-Dateigröße.', 1;
SET @Sql = N'ALTER DATABASE [msdb] MODIFY FILE (NAME = ' + QUOTENAME(@FileName, '''')
    + N', SIZE = ' + CONVERT(nvarchar(10), @TargetSizeMb) + N'MB);';
EXEC [sys].[sp_executesql] @Sql;
EXEC [monitor].[USP_MsdbHealthAnalysis]
    @MaxZeilen = 0, @ResultSetArt = 'NONE', @JsonErzeugen = 1,
    @Json = @Json OUTPUT, @PrintMeldungen = 0,
    @StatusCodeOut = @Status OUTPUT, @IsPartialOut = @Partial OUTPUT;
SELECT @SizeAfterGrowth = [SizeMb] FROM OPENJSON(@Json)
    WITH ([Area] varchar(40), [SizeMb] decimal(19,2)) WHERE [Area] = 'DATABASE_SIZE';
IF @Status <> 'AVAILABLE' OR @Partial <> 0
   OR @SizeBeforeGrowth IS NULL OR @SizeAfterGrowth IS NULL
   OR @SizeAfterGrowth < @SizeBeforeGrowth + 8
   OR @SizeAfterGrowth <> (SELECT CONVERT(decimal(19,2), SUM(CONVERT(bigint,[size])) * 8.0 / 1024.0)
                          FROM [sys].[master_files] WHERE [database_id] = 4)
    THROW 54887, N'Die kontrollierte aktuelle Dateigröße stimmt nicht mit dem Wachstumszustand überein.', 1;
GO
