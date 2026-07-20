USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentIO
Version      : 3.0.0
Stand        : 2026-07-20
Zweck        : Leichtgewichtige serverweite Datei-I/O-Analyse mit optionalem
               Delta-Sampling und expliziter Datenbankeinschränkung.
Datenbanken  : Standardmäßig alle sichtbaren, online befindlichen
               Benutzerdatenbanken; kein CURRENT-Scope und keine Vorabgrenze.
DMV-Zugriff  : sys.dm_io_virtual_file_stats(NULL,NULL) genau einmal je
               Messzeitpunkt; keine Wiederholung pro Datenbank.
Ausgabe      : CONSOLE ein fachliches Grid; RAW und TABLE verwenden die stabilen
               Namen moduleStatus, files und warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentIO]
      @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @MinLatencyMs                   decimal(19,3)  = 0
    , @SampleSeconds                  tinyint         = 0
    , @MaxZeilen                      int             = 1000
    , @ResultSetArt                   varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max)   = NULL
    , @JsonErzeugen                   bit             = 0
    , @Json                           nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                 bit             = 1
    , @Hilfe                          bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,N''))));
    DECLARE @Limit bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint,9223372036854775807)
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint,@MaxZeilen)
             ELSE CONVERT(bigint,0) END;
    DECLARE @CandidateLimit bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint,9223372036854775807)
             WHEN @MaxZeilen BETWEEN 1 AND 2147483646
             THEN CONVERT(bigint,@MaxZeilen) + 1
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint,@MaxZeilen)
             ELSE CONVERT(bigint,0) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentIO';
        PRINT N'Ohne Datenbankfilter werden alle sichtbaren, online befindlichen Benutzerdatenbanken verarbeitet.';
        PRINT N'@DatabaseNames enthält eine exakte Liste; @DatabaseNamePattern ist eine alternative explizite Einschränkung.';
        PRINT N'@SystemdatenbankenEinbeziehen=1 aktiviert Systemdatenbanken.';
        PRINT N'@SampleSeconds=0 liefert kumulative Zähler; 1..60 liefert ein Delta.';
        PRINT N'@ResultSetArt=CONSOLE|RAW|TABLE|NONE; TABLE verwendet @ResultTablesJson mit moduleStatus, files und warnings.';
        PRINT N'USP_CurrentIO ist leichtgewichtig und benötigt keine High-Impact-Bestätigung.';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;
    DECLARE @RowCount bigint = 0;
    DECLARE @WarningCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @Message nvarchar(2048);
    DECLARE @Delay char(8);

    CREATE TABLE [#CurrentIO_ResultTableMap]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
    );

    CREATE TABLE [#CurrentIO_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) NULL
        , [UserAccessDesc] nvarchar(60) NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname NULL
        , [RecoveryModelDesc] nvarchar(60) NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
    );

    CREATE TABLE [#CurrentIO_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) NOT NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    CREATE TABLE [#CurrentIO_Before]
    (
          [DatabaseId] int NOT NULL
        , [FileId] int NOT NULL
        , [SampleMs] bigint NULL
        , [Reads] bigint NOT NULL
        , [ReadStallMs] bigint NOT NULL
        , [ReadBytes] bigint NOT NULL
        , [Writes] bigint NOT NULL
        , [WriteStallMs] bigint NOT NULL
        , [WriteBytes] bigint NOT NULL
        , [SizeOnDiskBytes] bigint NOT NULL
        , PRIMARY KEY ([DatabaseId],[FileId])
    );

    CREATE TABLE [#CurrentIO_After]
    (
          [DatabaseId] int NOT NULL
        , [FileId] int NOT NULL
        , [SampleMs] bigint NULL
        , [Reads] bigint NOT NULL
        , [ReadStallMs] bigint NOT NULL
        , [ReadBytes] bigint NOT NULL
        , [Writes] bigint NOT NULL
        , [WriteStallMs] bigint NOT NULL
        , [WriteBytes] bigint NOT NULL
        , [SizeOnDiskBytes] bigint NOT NULL
        , PRIMARY KEY ([DatabaseId],[FileId])
    );

    CREATE TABLE [#CurrentIO_Result]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FileId] int NOT NULL
        , [LogicalName] sysname NULL
        , [PhysicalName] nvarchar(260) NULL
        , [FileTypeDesc] nvarchar(60) NULL
        , [SampleSeconds] int NOT NULL
        , [Reads] bigint NOT NULL
        , [ReadBytes] bigint NOT NULL
        , [ReadStallMs] bigint NOT NULL
        , [Writes] bigint NOT NULL
        , [WriteBytes] bigint NOT NULL
        , [WriteStallMs] bigint NOT NULL
        , [ReadLatencyMs] decimal(19,3) NULL
        , [WriteLatencyMs] decimal(19,3) NULL
        , [OverallLatencyMs] decimal(19,3) NULL
        , [ReadThroughputMbPerSecond] decimal(19,3) NULL
        , [WriteThroughputMbPerSecond] decimal(19,3) NULL
        , [SizeOnDiskMb] decimal(19,2) NULL
    );

    CREATE TABLE [#CurrentIO_ModuleStatus]
    (
          [ModuleName] sysname NOT NULL
        , [CollectionTimeUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NOT NULL
        , [HasMoreRows] bit NOT NULL
        , [CrossDatabaseRequested] bit NOT NULL
        , [SampleSeconds] tinyint NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    IF @MaxZeilen < 0
       OR @MinLatencyMs < 0
       OR @SampleSeconds > 60
       OR @OutputMode NOT IN ('RAW','CONSOLE','TABLE','NONE')
       OR @JsonErzeugen IS NULL OR @JsonErzeugen NOT IN (0,1)
       OR (@OutputMode <> 'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens ein Parameter besitzt einen ungültigen Wert.';
    END;

    IF @StatusCode = 'AVAILABLE' AND @OutputMode = 'TABLE'
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson = @ResultTablesJson
            , @AllowedResultNames = N'moduleStatus|files|warnings'
            , @MappingTable = N'#CurrentIO_ResultTableMap'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @ThrowOnError = 1;
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern
            , @AnalysisClass = 'STANDARD_CURRENT'
            , @HighImpactConfirmed = 0
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT
            , @CandidateTable = N'#CurrentIO_DatabaseCandidates'
            , @WarningTable = N'#CurrentIO_DatabaseCandidateWarnings';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#CurrentIO_Before]
        (
              [DatabaseId],[FileId],[SampleMs],[Reads],[ReadStallMs]
            , [ReadBytes],[Writes],[WriteStallMs],[WriteBytes],[SizeOnDiskBytes]
        )
        SELECT
              [v].[database_id],[v].[file_id],[v].[sample_ms]
            , [v].[num_of_reads],[v].[io_stall_read_ms],[v].[num_of_bytes_read]
            , [v].[num_of_writes],[v].[io_stall_write_ms],[v].[num_of_bytes_written]
            , [v].[size_on_disk_bytes]
        FROM [sys].[dm_io_virtual_file_stats](NULL,NULL) AS [v]
        INNER JOIN [#CurrentIO_DatabaseCandidates] AS [c]
          ON [c].[DatabaseId] = [v].[database_id];

        IF @SampleSeconds > 0
        BEGIN
            SET @Delay = CONVERT(char(8),DATEADD(SECOND,@SampleSeconds,CONVERT(time(0),'00:00:00')),108);
            WAITFOR DELAY @Delay;

            INSERT [#CurrentIO_After]
            (
                  [DatabaseId],[FileId],[SampleMs],[Reads],[ReadStallMs]
                , [ReadBytes],[Writes],[WriteStallMs],[WriteBytes],[SizeOnDiskBytes]
            )
            SELECT
                  [v].[database_id],[v].[file_id],[v].[sample_ms]
                , [v].[num_of_reads],[v].[io_stall_read_ms],[v].[num_of_bytes_read]
                , [v].[num_of_writes],[v].[io_stall_write_ms],[v].[num_of_bytes_written]
                , [v].[size_on_disk_bytes]
            FROM [sys].[dm_io_virtual_file_stats](NULL,NULL) AS [v]
            INNER JOIN [#CurrentIO_DatabaseCandidates] AS [c]
              ON [c].[DatabaseId] = [v].[database_id];
        END
        ELSE
        BEGIN
            INSERT [#CurrentIO_After]
            SELECT * FROM [#CurrentIO_Before];
        END;

        INSERT [#CurrentIO_Result]
        (
              [DatabaseId],[DatabaseName],[FileId],[LogicalName],[PhysicalName]
            , [FileTypeDesc],[SampleSeconds],[Reads],[ReadBytes],[ReadStallMs]
            , [Writes],[WriteBytes],[WriteStallMs],[ReadLatencyMs]
            , [WriteLatencyMs],[OverallLatencyMs],[ReadThroughputMbPerSecond]
            , [WriteThroughputMbPerSecond],[SizeOnDiskMb]
        )
        SELECT TOP (@CandidateLimit)
              [b].[DatabaseId]
            , [c].[DatabaseName]
            , [b].[FileId]
            , [mf].[name]
            , [mf].[physical_name]
            , [mf].[type_desc]
            , @SampleSeconds
            , CASE WHEN @SampleSeconds > 0 THEN [a].[Reads]-[b].[Reads] ELSE [a].[Reads] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[ReadBytes]-[b].[ReadBytes] ELSE [a].[ReadBytes] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[ReadStallMs]-[b].[ReadStallMs] ELSE [a].[ReadStallMs] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[Writes]-[b].[Writes] ELSE [a].[Writes] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[WriteBytes]-[b].[WriteBytes] ELSE [a].[WriteBytes] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[WriteStallMs]-[b].[WriteStallMs] ELSE [a].[WriteStallMs] END
            , CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0 THEN [a].[ReadStallMs]-[b].[ReadStallMs] ELSE [a].[ReadStallMs] END)*1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0 THEN [a].[Reads]-[b].[Reads] ELSE [a].[Reads] END,0))
            , CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0 THEN [a].[WriteStallMs]-[b].[WriteStallMs] ELSE [a].[WriteStallMs] END)*1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0 THEN [a].[Writes]-[b].[Writes] ELSE [a].[Writes] END,0))
            , CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0
                      THEN ([a].[ReadStallMs]-[b].[ReadStallMs])+([a].[WriteStallMs]-[b].[WriteStallMs])
                      ELSE [a].[ReadStallMs]+[a].[WriteStallMs] END)*1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0
                              THEN ([a].[Reads]-[b].[Reads])+([a].[Writes]-[b].[Writes])
                              ELSE [a].[Reads]+[a].[Writes] END,0)) AS [OverallLatencyMs]
            , CONVERT(decimal(19,3),CASE WHEN @SampleSeconds > 0
                     THEN ([a].[ReadBytes]-[b].[ReadBytes])/1048576.0/NULLIF(@SampleSeconds,0) END)
            , CONVERT(decimal(19,3),CASE WHEN @SampleSeconds > 0
                     THEN ([a].[WriteBytes]-[b].[WriteBytes])/1048576.0/NULLIF(@SampleSeconds,0) END)
            , CONVERT(decimal(19,2),[a].[SizeOnDiskBytes]/1048576.0)
        FROM [#CurrentIO_Before] AS [b]
        INNER JOIN [#CurrentIO_After] AS [a]
          ON [a].[DatabaseId]=[b].[DatabaseId]
         AND [a].[FileId]=[b].[FileId]
        INNER JOIN [#CurrentIO_DatabaseCandidates] AS [c]
          ON [c].[DatabaseId]=[b].[DatabaseId]
        LEFT JOIN [master].[sys].[master_files] AS [mf] WITH (NOLOCK)
          ON [mf].[database_id]=[b].[DatabaseId]
         AND [mf].[file_id]=[b].[FileId]
        WHERE CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0
                      THEN ([a].[ReadStallMs]-[b].[ReadStallMs])+([a].[WriteStallMs]-[b].[WriteStallMs])
                      ELSE [a].[ReadStallMs]+[a].[WriteStallMs] END)*1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0
                              THEN ([a].[Reads]-[b].[Reads])+([a].[Writes]-[b].[Writes])
                              ELSE [a].[Reads]+[a].[Writes] END,0)) >= @MinLatencyMs
        ORDER BY
              [OverallLatencyMs] DESC
            , [c].[DatabaseName]
            , [b].[FileId];

        SELECT @RowCount=COUNT_BIG(*) FROM [#CurrentIO_Result];
        SELECT @WarningCount=COUNT_BIG(*) FROM [#CurrentIO_DatabaseCandidateWarnings];
        SET @HasMoreRows=CONVERT(bit,CASE WHEN @Limit<9223372036854775807 AND @RowCount>@Limit THEN 1 ELSE 0 END);

        IF @WarningCount > 0
        BEGIN
            SET @StatusCode = 'AVAILABLE_LIMITED';
            SET @IsPartial = 1;
        END;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @StatusCode = CASE
            WHEN @ErrorNumber IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
            WHEN @ErrorNumber = 1222 THEN 'TIMEOUT'
            ELSE 'ERROR_HANDLED' END;
        SET @IsPartial = 1;
    END CATCH;

    IF @StatusCode <> 'AVAILABLE' AND @StatusCode <> 'AVAILABLE_LIMITED'
        SET @IsPartial = 1;

    INSERT [#CurrentIO_ModuleStatus]
    (
          [ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial]
        , [ReturnedRowCount],[HasMoreRows],[CrossDatabaseRequested]
        , [SampleSeconds],[ErrorNumber],[ErrorMessage]
    )
    VALUES
    (
          N'USP_CurrentIO',@CollectionTimeUtc,@StatusCode,@IsPartial
        , CASE WHEN @RowCount>@Limit THEN @Limit ELSE @RowCount END
        , @HasMoreRows,@CrossDatabaseRequested,@SampleSeconds,@ErrorNumber,@ErrorMessage
    );

    IF @PrintMeldungen = 1 AND @StatusCode NOT IN ('AVAILABLE','AVAILABLE_LIMITED')
    BEGIN
        SET @Message = FORMATMESSAGE(N'WARNUNG USP_CurrentIO [%s]: %s',@StatusCode,COALESCE(@ErrorMessage,N'Keine Detailmeldung verfügbar.'));
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;

    IF @PrintMeldungen = 1 AND @WarningCount > 0
    BEGIN
        SET @Message = FORMATMESSAGE(N'HINWEIS USP_CurrentIO: %I64d explizit angeforderte Datenbank(en) konnten nicht verarbeitet werden.',@WarningCount);
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;

    IF @OutputMode = 'CONSOLE'
    BEGIN
        IF @RowCount > 0
        BEGIN
            SELECT TOP (@Limit)
                  N'Datenbankdatei I/O' AS [Ergebnis]
                , [DatabaseName] AS [Datenbank]
                , [FileId] AS [Datei-ID]
                , [LogicalName] AS [Logischer Name]
                , [FileTypeDesc] AS [Dateityp]
                , [PhysicalName] AS [Pfad]
                , CONCAT(CONVERT(varchar(30),[OverallLatencyMs]),N' ms') AS [Gesamtlatenz je I/O]
                , CONCAT(CONVERT(varchar(30),[ReadLatencyMs]),N' ms') AS [Leselatenz]
                , CONCAT(CONVERT(varchar(30),[WriteLatencyMs]),N' ms') AS [Schreiblatenz]
                , [Reads] AS [Lesevorgänge]
                , [Writes] AS [Schreibvorgänge]
                , CONCAT(CONVERT(varchar(30),[ReadThroughputMbPerSecond]),N' MB/s') AS [Lesedurchsatz]
                , CONCAT(CONVERT(varchar(30),[WriteThroughputMbPerSecond]),N' MB/s') AS [Schreibdurchsatz]
                , CONCAT(CONVERT(varchar(30),[SizeOnDiskMb]),N' MB') AS [Dateigröße]
            FROM [#CurrentIO_Result]
            ORDER BY [OverallLatencyMs] DESC,[DatabaseName],[FileId];
        END
        ELSE
        BEGIN
            SELECT
                  CASE WHEN @StatusCode IN ('AVAILABLE','AVAILABLE_LIMITED')
                       THEN N'Keine Datei-I/O-Daten entsprechen den Filtern.'
                       ELSE N'Die Datei-I/O-Analyse ist nicht verfügbar.' END AS [Ergebnis]
                , @StatusCode AS [Status]
                , @ErrorMessage AS [Hinweis];
        END;
    END
    ELSE IF @OutputMode = 'RAW'
    BEGIN
        SELECT * FROM [#CurrentIO_ModuleStatus];

        SELECT TOP (@Limit) *
        FROM [#CurrentIO_Result]
        ORDER BY [OverallLatencyMs] DESC,[DatabaseName],[FileId];

        SELECT [RequestedName],[StatusCode],[ErrorMessage]
        FROM [#CurrentIO_DatabaseCandidateWarnings]
        ORDER BY [RequestedName];
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max)=
        (
            SELECT
                  N'CurrentIO' AS [resultName]
                , 2 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @MaxZeilen AS [requestedMaxRows]
                , CASE WHEN @RowCount>@Limit THEN @Limit ELSE @RowCount END AS [returnedRows]
                , @HasMoreRows AS [hasMoreRows]
                , @SampleSeconds AS [sampleSeconds]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
        );
        DECLARE @Data nvarchar(max)=
        (
            SELECT TOP (@Limit) *
            FROM [#CurrentIO_Result]
            ORDER BY [OverallLatencyMs] DESC,[DatabaseName],[FileId]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        DECLARE @Warnings nvarchar(max)=
        (
            SELECT [RequestedName],[StatusCode],[ErrorMessage]
            FROM [#CurrentIO_DatabaseCandidateWarnings]
            ORDER BY [RequestedName]
            FOR JSON PATH,INCLUDE_NULL_VALUES
        );
        SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"files":',COALESCE(@Data,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');
    END;

    IF @OutputMode = 'TABLE'
    BEGIN
        DECLARE @TargetTable sysname;

        SELECT @TargetTable=[TargetTable]
        FROM [#CurrentIO_ResultTableMap]
        WHERE [ResultName]=N'moduleStatus';
        IF @TargetTable IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#CurrentIO_ModuleStatus'
                , @ResultTable=@TargetTable
                , @ThrowOnError=1;

        SET @TargetTable=NULL;
        SELECT @TargetTable=[TargetTable]
        FROM [#CurrentIO_ResultTableMap]
        WHERE [ResultName]=N'files';
        IF @TargetTable IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#CurrentIO_Result'
                , @ResultTable=@TargetTable
                , @ThrowOnError=1;

        SET @TargetTable=NULL;
        SELECT @TargetTable=[TargetTable]
        FROM [#CurrentIO_ResultTableMap]
        WHERE [ResultName]=N'warnings';
        IF @TargetTable IS NOT NULL
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=N'#CurrentIO_DatabaseCandidateWarnings'
                , @ResultTable=@TargetTable
                , @ThrowOnError=1;
    END;
END;
GO
