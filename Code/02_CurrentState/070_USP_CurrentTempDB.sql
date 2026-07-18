USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentTempDB
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Zeigt aktuellen TempDB-Verbrauch je Session und optional die
               TempDB-Dateien. Unterstützt Sessionlisten, RAW, CONSOLE und JSON.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentTempDB]
      @SessionIds                 nvarchar(max) = NULL
    , @AktuelleSessionEinbeziehen bit           = 0
    , @MinNettoMb                 decimal(19,2)  = 0
    , @SystemSessionsEinbeziehen  bit           = 0
    , @MitDateien                 bit           = 1
    , @MaxZeilen                  int           = 1000
    , @ResultSetArt               varchar(16)    = 'CONSOLE'
    , @JsonErzeugen               bit            = 0
    , @Json                       nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen             bit            = 1
    , @Hilfe                      bit            = 0
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
        PRINT N'monitor.USP_CurrentTempDB';
        PRINT N'@SessionIds = N''57|61''; NULL = keine Einschränkung.';
        PRINT N'@MitDateien=1 liefert ein zweites Resultset beziehungsweise das JSON-Array tempdbFiles.';
        PRINT N'@MaxZeilen positiv = begrenzt, NULL/0 = unbegrenzt.';
        PRINT N'@ResultSetArt = CONSOLE (Default)|RAW|NONE; Steuerwert case-insensitiv.';
        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @RowCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @Message nvarchar(2048);

    CREATE TABLE [#SessionFilter]([SessionId] smallint NOT NULL PRIMARY KEY);
    CREATE TABLE [#Sessions]
    (
          [SessionId]                 smallint       NOT NULL
        , [LoginName]                 nvarchar(128)  NULL
        , [HostName]                  nvarchar(128)  NULL
        , [ProgramName]               nvarchar(128)  NULL
        , [SessionStatus]             nvarchar(30)   NULL
        , [UserObjectsAllocatedMb]    decimal(19,2)  NOT NULL
        , [UserObjectsDeallocatedMb]  decimal(19,2)  NOT NULL
        , [UserObjectsNetMb]          decimal(19,2)  NOT NULL
        , [InternalObjectsAllocatedMb] decimal(19,2) NOT NULL
        , [InternalObjectsDeallocatedMb] decimal(19,2) NOT NULL
        , [InternalObjectsNetMb]      decimal(19,2)  NOT NULL
        , [TotalNetMb]                decimal(19,2)  NOT NULL
    );
    CREATE TABLE [#Files]
    (
          [FileId]                 int            NOT NULL
        , [LogicalName]            sysname        NOT NULL
        , [PhysicalName]           nvarchar(260)  NOT NULL
        , [FileTypeDesc]           nvarchar(60)   NOT NULL
        , [SizeMb]                 decimal(19,2)  NOT NULL
        , [UsedMb]                 decimal(19,2)  NULL
        , [FreeMb]                 decimal(19,2)  NULL
        , [UsedPercent]            decimal(9,2)   NULL
        , [GrowthMb]               decimal(19,2)  NULL
        , [IsPercentGrowth]        bit            NOT NULL
    );
    CREATE TABLE [#Warnings]
    (
          [StatusCode] varchar(40) NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    IF @SessionIds IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1 FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            WHERE [IsValid] = 0 OR [NumberValue] NOT BETWEEN 0 AND 32767
        )
        OR EXISTS
        (
            SELECT [NumberValue]
            FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            WHERE [IsValid] = 1
            GROUP BY [NumberValue]
            HAVING COUNT(*) > 1
        )
        BEGIN
            SET @StatusCode = 'INVALID_PARAMETER';
            SET @ErrorMessage = N'@SessionIds ist ungültig oder enthält Duplikate.';
        END
        ELSE
        BEGIN
            INSERT [#SessionFilter]([SessionId])
            SELECT CONVERT(smallint, [NumberValue])
            FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            WHERE [IsValid] = 1;
        END;
    END;

    IF @StatusCode = 'AVAILABLE'
       AND
       (
           @MinNettoMb < 0
           OR @MaxZeilen < 0
           OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
           OR @JsonErzeugen IS NULL
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens ein Parameter besitzt einen ungültigen Wert.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#Sessions]
        (
              [SessionId], [LoginName], [HostName], [ProgramName], [SessionStatus]
            , [UserObjectsAllocatedMb], [UserObjectsDeallocatedMb], [UserObjectsNetMb]
            , [InternalObjectsAllocatedMb], [InternalObjectsDeallocatedMb], [InternalObjectsNetMb]
            , [TotalNetMb]
        )
        SELECT TOP (@Candidates)
              [su].[session_id]
            , [s].[login_name]
            , [s].[host_name]
            , [s].[program_name]
            , [s].[status]
            , CONVERT(decimal(19,2), [su].[user_objects_alloc_page_count] * 8.0 / 1024.0)
            , CONVERT(decimal(19,2), [su].[user_objects_dealloc_page_count] * 8.0 / 1024.0)
            , CONVERT(decimal(19,2), ([su].[user_objects_alloc_page_count] - [su].[user_objects_dealloc_page_count]) * 8.0 / 1024.0)
            , CONVERT(decimal(19,2), [su].[internal_objects_alloc_page_count] * 8.0 / 1024.0)
            , CONVERT(decimal(19,2), [su].[internal_objects_dealloc_page_count] * 8.0 / 1024.0)
            , CONVERT(decimal(19,2), ([su].[internal_objects_alloc_page_count] - [su].[internal_objects_dealloc_page_count]) * 8.0 / 1024.0)
            , CONVERT(decimal(19,2),
                (
                    [su].[user_objects_alloc_page_count] - [su].[user_objects_dealloc_page_count]
                    + [su].[internal_objects_alloc_page_count] - [su].[internal_objects_dealloc_page_count]
                ) * 8.0 / 1024.0)
        FROM [sys].[dm_db_session_space_usage] AS [su]
        LEFT JOIN [sys].[dm_exec_sessions] AS [s]
          ON [s].[session_id] = [su].[session_id]
        WHERE (@AktuelleSessionEinbeziehen = 1 OR [su].[session_id] <> @@SPID)
          AND (@SystemSessionsEinbeziehen = 1 OR COALESCE([s].[is_user_process], 1) = 1)
          AND
          (
              @SessionIds IS NULL
              OR EXISTS
                 (
                     SELECT 1 FROM [#SessionFilter] AS [f]
                     WHERE [f].[SessionId] = [su].[session_id]
                 )
          )
          AND
          (
              [su].[user_objects_alloc_page_count] - [su].[user_objects_dealloc_page_count]
              + [su].[internal_objects_alloc_page_count] - [su].[internal_objects_dealloc_page_count]
          ) * 8.0 / 1024.0 >= @MinNettoMb
        ORDER BY
          (
              [su].[user_objects_alloc_page_count] - [su].[user_objects_dealloc_page_count]
              + [su].[internal_objects_alloc_page_count] - [su].[internal_objects_dealloc_page_count]
          ) DESC,
          [su].[session_id];

        IF @MitDateien = 1
        BEGIN
            DECLARE @FileSql nvarchar(max) = N'USE [tempdb];
INSERT [#Files]
(
      [FileId], [LogicalName], [PhysicalName], [FileTypeDesc]
    , [SizeMb], [UsedMb], [FreeMb], [UsedPercent], [GrowthMb], [IsPercentGrowth]
)
SELECT
      [df].[file_id]
    , [df].[name]
    , [df].[physical_name]
    , [df].[type_desc]
    , CONVERT(decimal(19,2), [df].[size] * 8.0 / 1024.0)
    , CONVERT(decimal(19,2), FILEPROPERTY([df].[name], N''SpaceUsed'') * 8.0 / 1024.0)
    , CONVERT(decimal(19,2), ([df].[size] - FILEPROPERTY([df].[name], N''SpaceUsed'')) * 8.0 / 1024.0)
    , CONVERT(decimal(9,2), 100.0 * FILEPROPERTY([df].[name], N''SpaceUsed'') / NULLIF([df].[size], 0))
    , CONVERT(decimal(19,2), CASE WHEN [df].[is_percent_growth] = 0 THEN [df].[growth] * 8.0 / 1024.0 END)
    , [df].[is_percent_growth]
FROM [sys].[database_files] AS [df] WITH (NOLOCK)
ORDER BY [df].[file_id];';
            EXEC [sys].[sp_executesql] @FileSql;
        END;

        SELECT @RowCount = COUNT_BIG(*) FROM [#Sessions];
        SET @HasMoreRows = CONVERT(bit, CASE WHEN @Limit < 9223372036854775807 AND @RowCount > @Limit THEN 1 ELSE 0 END);
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @StatusCode = CASE WHEN @ErrorNumber IN (229, 262, 297, 300, 371, 916) THEN 'DENIED_PERMISSION'
                               WHEN @ErrorNumber = 1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
        INSERT [#Warnings] VALUES (@StatusCode, @ErrorNumber, @ErrorMessage);
    END CATCH;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @Message = FORMATMESSAGE(N'WARNUNG USP_CurrentTempDB [%s]: %s', @StatusCode, COALESCE(@ErrorMessage, N'Unbekannter Fehler.'));
        RAISERROR(N'%s', 10, 1, @Message) WITH NOWAIT;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_CurrentTempDB' AS [ModuleName]
            , @Now AS [CollectionTimeUtc]
            , @StatusCode AS [StatusCode]
            , CONVERT(bit, CASE WHEN @StatusCode = 'AVAILABLE' THEN 0 ELSE 1 END) AS [IsPartial]
            , CASE WHEN @RowCount > @Limit THEN @Limit ELSE @RowCount END AS [ReturnedRowCount]
            , @HasMoreRows AS [HasMoreRows]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT TOP (@Limit) *
            FROM [#Sessions]
            ORDER BY [TotalNetMb] DESC, [SessionId];
            IF @MitDateien = 1
                SELECT * FROM [#Files] ORDER BY [FileId];
        END
        ELSE
        BEGIN
            SELECT TOP (@Limit)
                  N'TempDB-Verbrauch einer Session' AS [Ergebnis]
                , [SessionId] AS [Session]
                , [LoginName] AS [Login]
                , [HostName] AS [Host]
                , [ProgramName] AS [Programm]
                , [SessionStatus] AS [Status]
                , CONCAT(CONVERT(varchar(30), [TotalNetMb]), N' MB') AS [Gesamt netto]
                , CONCAT(CONVERT(varchar(30), [UserObjectsNetMb]), N' MB') AS [User Objects netto]
                , CONCAT(CONVERT(varchar(30), [InternalObjectsNetMb]), N' MB') AS [Internal Objects netto]
            FROM [#Sessions]
            ORDER BY [TotalNetMb] DESC, [SessionId];

            IF @MitDateien = 1
                SELECT
                      N'TempDB-Datei' AS [Ergebnis]
                    , [FileId] AS [Datei-ID]
                    , [LogicalName] AS [Logischer Name]
                    , [PhysicalName] AS [Pfad]
                    , CONCAT(CONVERT(varchar(30), [SizeMb]), N' MB') AS [Größe]
                    , CONCAT(CONVERT(varchar(30), [UsedMb]), N' MB') AS [Verwendet]
                    , CONCAT(CONVERT(varchar(30), [FreeMb]), N' MB') AS [Frei]
                    , CONCAT(CONVERT(varchar(30), [UsedPercent]), N' %') AS [Auslastung]
                FROM [#Files]
                ORDER BY [FileId];
        END;

        SELECT * FROM [#Warnings] ORDER BY [StatusCode];
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max) =
        (
            SELECT N'CurrentTempDB' AS [resultName], 1 AS [schemaVersion], @Now AS [generatedAtUtc],
                   @StatusCode AS [statusCode], @MaxZeilen AS [requestedMaxRows],
                   CASE WHEN @RowCount > @Limit THEN @Limit ELSE @RowCount END AS [returnedRows],
                   @HasMoreRows AS [hasMoreRows]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @SessionsJson nvarchar(max) =
        (
            SELECT TOP (@Limit) * FROM [#Sessions]
            ORDER BY [TotalNetMb] DESC, [SessionId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        DECLARE @FilesJson nvarchar(max) =
        (
            SELECT * FROM [#Files] ORDER BY [FileId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        DECLARE @WarningsJson nvarchar(max) =
        (
            SELECT * FROM [#Warnings] ORDER BY [StatusCode]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        SET @Json = CONCAT(N'{"meta":', COALESCE(@Meta,N'{}'), N',"sessions":', COALESCE(@SessionsJson,N'[]'), N',"tempdbFiles":', COALESCE(@FilesJson,N'[]'), N',"warnings":', COALESCE(@WarningsJson,N'[]'), N'}');
    END;
END;
GO
