USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentIO
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Zeigt kumulative oder gesampelte Datei-I/O-Kennzahlen für eine
               exakte Datenbankliste, alle zulässigen Datenbanken oder ein
               Datenbank-Pattern. RAW-, CONSOLE- und JSON-Ausgabe.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentIO]
      @DatabaseNames                  nvarchar(max)  = N''
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @MaxDatenbanken                 int            = 16
    , @MinLatencyMs                   decimal(19,3)  = 0
    , @SampleSeconds                  tinyint         = 0
    , @MaxZeilen                      int             = 1000
    , @ResultSetArt                   varchar(16)      = 'CONSOLE'
    , @JsonErzeugen                   bit              = 0
    , @Json                           nvarchar(max)    = NULL OUTPUT
    , @PrintMeldungen                 bit              = 1
    , @Hilfe                          bit              = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint, 9223372036854775807)
                                 WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen) ELSE 0 END;
    DECLARE @Candidates bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint, 9223372036854775807)
                                      WHEN @MaxZeilen < 2147483647 THEN CONVERT(bigint, @MaxZeilen) + 1 ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentIO';
        PRINT N'@DatabaseNames: bracket-aware Pipe-Liste; N'''' = aktuelle DB; NULL = alle zulässigen DBs.';
        PRINT N'@DatabaseNamePattern: ein like:/regex:/regexi:-Pattern; exakte Liste und Pattern sind exklusiv.';
        PRINT N'Explizite Datenbanklisten werden nicht durch @MaxDatenbanken gekürzt.';
        PRINT N'@SampleSeconds=0 liefert kumulative Zähler; 1..60 liefert ein Delta.';
        PRINT N'@MaxZeilen positiv = begrenzt, NULL/0 = unbegrenzt.';
        PRINT N'@ResultSetArt = CONSOLE (Default)|RAW|NONE; Steuerwert case-insensitiv.';
        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;
    DECLARE @RowCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @Message nvarchar(2048);
    DECLARE @Delay char(8);

    CREATE TABLE [#DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname NOT NULL
        , [StateDesc] nvarchar(60) NULL
        , [UserAccessDesc] nvarchar(60) NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname NULL
        , [RecoveryModelDesc] nvarchar(60) NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
        , PRIMARY KEY ([DatabaseId])
    );
    CREATE TABLE [#DatabaseCandidateWarnings]
    (
          [RequestedName] sysname NULL
        , [StatusCode] varchar(40) NOT NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );
    CREATE TABLE [#Before]
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
        , PRIMARY KEY ([DatabaseId], [FileId])
    );
    CREATE TABLE [#After]
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
        , PRIMARY KEY ([DatabaseId], [FileId])
    );
    CREATE TABLE [#Result]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname NOT NULL
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

    IF @MaxZeilen < 0
       OR @MaxDatenbanken < 0
       OR @MinLatencyMs < 0
       OR @SampleSeconds > 60
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR @JsonErzeugen IS NULL
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens ein Parameter besitzt einen ungültigen Wert.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern
            , @MaxDatenbanken = @MaxDatenbanken
            , @AnalysisClass = 'CROSS_DATABASE_DEEP'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT;
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        DECLARE @DatabaseId int;
        DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId]
            FROM [#DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal], [DatabaseId]), [DatabaseId];

        OPEN [DatabaseCursor];
        FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT [#Before]
            (
                  [DatabaseId], [FileId], [SampleMs], [Reads], [ReadStallMs]
                , [ReadBytes], [Writes], [WriteStallMs], [WriteBytes], [SizeOnDiskBytes]
            )
            SELECT
                  [v].[database_id], [v].[file_id], [v].[sample_ms]
                , [v].[num_of_reads], [v].[io_stall_read_ms], [v].[num_of_bytes_read]
                , [v].[num_of_writes], [v].[io_stall_write_ms], [v].[num_of_bytes_written]
                , [v].[size_on_disk_bytes]
            FROM [sys].[dm_io_virtual_file_stats](@DatabaseId, NULL) AS [v];

            FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId;
        END;
        CLOSE [DatabaseCursor];
        DEALLOCATE [DatabaseCursor];

        IF @SampleSeconds > 0
        BEGIN
            SET @Delay = CONVERT(char(8), DATEADD(SECOND, @SampleSeconds, CONVERT(time(0), '00:00:00')), 108);
            WAITFOR DELAY @Delay;
        END;

        DECLARE [DatabaseCursorAfter] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId]
            FROM [#DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal], [DatabaseId]), [DatabaseId];

        OPEN [DatabaseCursorAfter];
        FETCH NEXT FROM [DatabaseCursorAfter] INTO @DatabaseId;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT [#After]
            (
                  [DatabaseId], [FileId], [SampleMs], [Reads], [ReadStallMs]
                , [ReadBytes], [Writes], [WriteStallMs], [WriteBytes], [SizeOnDiskBytes]
            )
            SELECT
                  [v].[database_id], [v].[file_id], [v].[sample_ms]
                , [v].[num_of_reads], [v].[io_stall_read_ms], [v].[num_of_bytes_read]
                , [v].[num_of_writes], [v].[io_stall_write_ms], [v].[num_of_bytes_written]
                , [v].[size_on_disk_bytes]
            FROM [sys].[dm_io_virtual_file_stats](@DatabaseId, NULL) AS [v];

            FETCH NEXT FROM [DatabaseCursorAfter] INTO @DatabaseId;
        END;
        CLOSE [DatabaseCursorAfter];
        DEALLOCATE [DatabaseCursorAfter];

        INSERT [#Result]
        (
              [DatabaseId], [DatabaseName], [FileId], [LogicalName]
            , [PhysicalName], [FileTypeDesc], [SampleSeconds]
            , [Reads], [ReadBytes], [ReadStallMs]
            , [Writes], [WriteBytes], [WriteStallMs]
            , [ReadLatencyMs], [WriteLatencyMs], [OverallLatencyMs]
            , [ReadThroughputMbPerSecond], [WriteThroughputMbPerSecond]
            , [SizeOnDiskMb]
        )
        SELECT TOP (@Candidates)
              [b].[DatabaseId]
            , [c].[DatabaseName]
            , [b].[FileId]
            , [mf].[name]
            , [mf].[physical_name]
            , [mf].[type_desc]
            , @SampleSeconds
            , CASE WHEN @SampleSeconds > 0 THEN [a].[Reads] - [b].[Reads] ELSE [a].[Reads] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[ReadBytes] - [b].[ReadBytes] ELSE [a].[ReadBytes] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[ReadStallMs] - [b].[ReadStallMs] ELSE [a].[ReadStallMs] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[Writes] - [b].[Writes] ELSE [a].[Writes] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[WriteBytes] - [b].[WriteBytes] ELSE [a].[WriteBytes] END
            , CASE WHEN @SampleSeconds > 0 THEN [a].[WriteStallMs] - [b].[WriteStallMs] ELSE [a].[WriteStallMs] END
            , CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0 THEN [a].[ReadStallMs] - [b].[ReadStallMs] ELSE [a].[ReadStallMs] END) * 1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0 THEN [a].[Reads] - [b].[Reads] ELSE [a].[Reads] END, 0))
            , CONVERT(decimal(19,3),
                (CASE WHEN @SampleSeconds > 0 THEN [a].[WriteStallMs] - [b].[WriteStallMs] ELSE [a].[WriteStallMs] END) * 1.0
                / NULLIF(CASE WHEN @SampleSeconds > 0 THEN [a].[Writes] - [b].[Writes] ELSE [a].[Writes] END, 0))
            , CONVERT(decimal(19,3),
                (
                    CASE WHEN @SampleSeconds > 0
                         THEN ([a].[ReadStallMs] - [b].[ReadStallMs]) + ([a].[WriteStallMs] - [b].[WriteStallMs])
                         ELSE [a].[ReadStallMs] + [a].[WriteStallMs] END
                ) * 1.0
                / NULLIF
                  (
                      CASE WHEN @SampleSeconds > 0
                           THEN ([a].[Reads] - [b].[Reads]) + ([a].[Writes] - [b].[Writes])
                           ELSE [a].[Reads] + [a].[Writes] END,
                      0
                  ))
            , CONVERT(decimal(19,3), CASE WHEN @SampleSeconds > 0 THEN ([a].[ReadBytes] - [b].[ReadBytes]) / 1048576.0 / NULLIF(@SampleSeconds, 0) END)
            , CONVERT(decimal(19,3), CASE WHEN @SampleSeconds > 0 THEN ([a].[WriteBytes] - [b].[WriteBytes]) / 1048576.0 / NULLIF(@SampleSeconds, 0) END)
            , CONVERT(decimal(19,2), [a].[SizeOnDiskBytes] / 1048576.0)
        FROM [#Before] AS [b]
        INNER JOIN [#After] AS [a]
          ON [a].[DatabaseId] = [b].[DatabaseId]
         AND [a].[FileId] = [b].[FileId]
        INNER JOIN [#DatabaseCandidates] AS [c]
          ON [c].[DatabaseId] = [b].[DatabaseId]
        LEFT JOIN [master].[sys].[master_files] AS [mf] WITH (NOLOCK)
          ON [mf].[database_id] = [b].[DatabaseId]
         AND [mf].[file_id] = [b].[FileId]
        WHERE CONVERT(decimal(19,3),
                (
                    CASE WHEN @SampleSeconds > 0
                         THEN ([a].[ReadStallMs] - [b].[ReadStallMs]) + ([a].[WriteStallMs] - [b].[WriteStallMs])
                         ELSE [a].[ReadStallMs] + [a].[WriteStallMs] END
                ) * 1.0
                / NULLIF
                  (
                      CASE WHEN @SampleSeconds > 0
                           THEN ([a].[Reads] - [b].[Reads]) + ([a].[Writes] - [b].[Writes])
                           ELSE [a].[Reads] + [a].[Writes] END,
                      0
                  )) >= @MinLatencyMs
        ORDER BY
              CONVERT(decimal(19,3),
                (
                    CASE WHEN @SampleSeconds > 0
                         THEN ([a].[ReadStallMs] - [b].[ReadStallMs]) + ([a].[WriteStallMs] - [b].[WriteStallMs])
                         ELSE [a].[ReadStallMs] + [a].[WriteStallMs] END
                ) * 1.0
                / NULLIF
                  (
                      CASE WHEN @SampleSeconds > 0
                           THEN ([a].[Reads] - [b].[Reads]) + ([a].[Writes] - [b].[Writes])
                           ELSE [a].[Reads] + [a].[Writes] END,
                      0
                  )) DESC,
              [c].[DatabaseName],
              [b].[FileId];

        SELECT @RowCount = COUNT_BIG(*) FROM [#Result];
        SET @HasMoreRows = CONVERT(bit, CASE WHEN @Limit < 9223372036854775807 AND @RowCount > @Limit THEN 1 ELSE 0 END);
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @StatusCode = CASE WHEN @ErrorNumber IN (229, 262, 297, 300, 916) THEN 'DENIED_PERMISSION'
                               WHEN @ErrorNumber = 1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
    END CATCH;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @Message = FORMATMESSAGE(N'WARNUNG USP_CurrentIO [%s]: %s', @StatusCode, COALESCE(@ErrorMessage, N'Unbekannter Fehler.'));
        RAISERROR(N'%s', 10, 1, @Message) WITH NOWAIT;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_CurrentIO' AS [ModuleName]
            , @Now AS [CollectionTimeUtc]
            , @StatusCode AS [StatusCode]
            , CONVERT(bit, CASE WHEN @StatusCode = 'AVAILABLE' THEN 0 ELSE 1 END) AS [IsPartial]
            , CASE WHEN @RowCount > @Limit THEN @Limit ELSE @RowCount END AS [ReturnedRowCount]
            , @HasMoreRows AS [HasMoreRows]
            , @CrossDatabaseRequested AS [CrossDatabaseRequested]
            , @SampleSeconds AS [SampleSeconds]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT TOP (@Limit) *
            FROM [#Result]
            ORDER BY [OverallLatencyMs] DESC, [DatabaseName], [FileId];
        END
        ELSE
        BEGIN
            SELECT TOP (@Limit)
                  N'Datenbankdatei I/O' AS [Ergebnis]
                , [DatabaseName] AS [Datenbank]
                , [FileId] AS [Datei-ID]
                , [LogicalName] AS [Logischer Name]
                , [FileTypeDesc] AS [Dateityp]
                , [PhysicalName] AS [Pfad]
                , CONCAT(CONVERT(varchar(30), [OverallLatencyMs]), N' ms') AS [Gesamtlatenz je I/O]
                , CONCAT(CONVERT(varchar(30), [ReadLatencyMs]), N' ms') AS [Leselatenz]
                , CONCAT(CONVERT(varchar(30), [WriteLatencyMs]), N' ms') AS [Schreiblatenz]
                , [Reads] AS [Lesevorgänge]
                , [Writes] AS [Schreibvorgänge]
                , CONCAT(CONVERT(varchar(30), [ReadThroughputMbPerSecond]), N' MB/s') AS [Lesedurchsatz]
                , CONCAT(CONVERT(varchar(30), [WriteThroughputMbPerSecond]), N' MB/s') AS [Schreibdurchsatz]
                , CONCAT(CONVERT(varchar(30), [SizeOnDiskMb]), N' MB') AS [Dateigröße]
            FROM [#Result]
            ORDER BY [OverallLatencyMs] DESC, [DatabaseName], [FileId];
        END;

        SELECT [RequestedName], [StatusCode], [ErrorMessage]
        FROM [#DatabaseCandidateWarnings]
        ORDER BY [RequestedName];
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max) =
        (
            SELECT N'CurrentIO' AS [resultName], 1 AS [schemaVersion], @Now AS [generatedAtUtc],
                   @StatusCode AS [statusCode], @MaxZeilen AS [requestedMaxRows],
                   CASE WHEN @RowCount > @Limit THEN @Limit ELSE @RowCount END AS [returnedRows],
                   @HasMoreRows AS [hasMoreRows], @SampleSeconds AS [sampleSeconds]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @Data nvarchar(max) =
        (
            SELECT TOP (@Limit) * FROM [#Result]
            ORDER BY [OverallLatencyMs] DESC, [DatabaseName], [FileId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        DECLARE @Warnings nvarchar(max) =
        (
            SELECT [RequestedName], [StatusCode], [ErrorMessage]
            FROM [#DatabaseCandidateWarnings]
            ORDER BY [RequestedName]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        SET @Json = CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"files":',COALESCE(@Data,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');
    END;
END;
GO
