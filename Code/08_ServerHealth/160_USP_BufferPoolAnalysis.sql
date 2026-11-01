USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_BufferPoolAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Die Procedure liefert eine korrelierte Momentaufnahme von
               Prozess-, Betriebssystem- und Resource-Semaphore-Speicherwerten
               sowie optionalen Memory-Clerk- und Buffer-Pool-Verteilungen.
Datenquellen : sys.dm_os_process_memory, sys.dm_os_sys_memory,
               sys.dm_exec_query_resource_semaphores,
               sys.dm_os_memory_clerks und optional sys.dm_os_buffer_descriptors.
Kosten       : Basis LOW; Buffer-Pool-Verteilung kann auf großen Instanzen HIGH
               sein und ist deshalb standardmäßig deaktiviert.
Grenzen      : Eine Momentaufnahme beweist keinen Trend und berechnet keine
               automatische max-server-memory-Empfehlung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_BufferPoolAnalysis]
      @MitMemoryClerks          bit            = 1
    , @MitBufferPoolVerteilung  bit            = 0
    , @MaxZeilen                int            = 100
    , @ResultSetArt             varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen             bit            = 0
    , @Json                     nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen           bit            = 1
    , @Hilfe                    bit            = 0
    , @StatusCodeOut            varchar(40)    = NULL OUTPUT
    , @IsPartialOut             bit            = NULL OUTPUT
    , @ErrorNumberOut           int            = NULL OUTPUT
    , @ErrorMessageOut          nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'memory',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
                                 THEN CONVERT(bigint, 9223372036854775807)
                                 ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_BufferPoolAnalysis';
        PRINT N'Sammelt Memory-/OS-Momentaufnahme und Resource Semaphores, ergänzt optional nach Clerktyp gruppierte Memory Clerks und aktiviert die nach Datenbanken gruppierte Buffer-Pool-Verteilung nur mit @MitBufferPoolVerteilung=1.';
        PRINT N'Der Descriptorpfad scannt sys.dm_os_buffer_descriptors vor Gruppierung; ein kleines MaxZeilen begrenzt nur ausgegebene Gruppen, nicht den Scan.';
        PRINT N'@Hilfe=1 druckt Kurzbeschreibung und kehrt vor Sammlung zurück; ein TABLE-Mapping wird davor vorbereitet.';
        PRINT N'@MitMemoryClerks bit; Default: 1. NULL, 0 oder 1. Nur 1 liest sys.dm_os_memory_clerks und gruppiert nach Clerktyp; 0/NULL überspringt diese Quelle und ihr Resultset bleibt leer. MemorySnapshot und Resource Semaphores werden unabhängig gesammelt.';
        PRINT N'@MitBufferPoolVerteilung bit; Default: 0. NULL, 0 oder 1. Nur 1 scannt sys.dm_os_buffer_descriptors und aggregiert gecachte Seiten nach Datenbank-ID und aufgelöstem Namen; 0/NULL ist der sichere Standard und überspringt den breiten Descriptorpfad. Die Quelle wird vor Gruppierung gelesen. MaxZeilen begrenzt nicht den Scan. Nicht aufgelöste Datenbanknamen bleiben NULL.';
        PRINT N'@MaxZeilen int; Default: 100. int-Eingabe: NULL oder 0 bedeutet unbegrenzt; positive Werte bis 2147483647 begrenzen Semaphore-, Clerk- und Buffer-Pool-Gruppen ausschließlich in RAW und JSON. Negative Werte sind INVALID_PARAMETER. MemorySnapshot bleibt ungekürzt; CONSOLE liefert nur den vollständigen MemorySnapshot, TABLE schreibt nur diesen Snapshot. Die Grenze folgt auf Sammlung und Aggregation und begrenzt insbesondere den Descriptor-Scan nicht.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. NULL oder Text, der nach Trim und Großschreibung CONSOLE, RAW, TABLE oder NONE ergibt. RAW liefert Statuskontext und vier Fachresultsets. CONSOLE wird intern zu NONE normalisiert und ruft danach den Console-Helper nur für MemorySnapshot auf; die direkte CONSOLE-Resultsetansicht im Procedurekörper ist dadurch nicht erreichbar. TABLE wird ebenfalls zu NONE normalisiert und schreibt ausschließlich MemorySnapshot in die lokale Zieltabellenzuordnung; NONE unterdrückt normale Resultsets. NULL/Leertext und andere Werte setzen INVALID_PARAMETER. Nichtleeres Mapping außerhalb TABLE wirft 51011; das TABLE-Mapping wird vor Hilfe und Parameterprüfung vorbereitet.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. NULL oder ein JSON-Objekt mit genau dem Schlüssel memory und einem Stringwert für den Namen einer vorhandenen lokalen #Temp-Tabelle, etwa N''{"memory":"#BufferPoolAnalysis_HelpExample"}''. Für TABLE muss das Ziel leer sein und genau eine beliebig typisierte Seed-Spalte besitzen. NULL, nach Trim von U+0020 leere Eingabe oder fehlerhaftes Mapping scheitern am Preflight vor @Hilfe und Sammlung. Der Preflight prüft das Ziel; erst beim TABLE-Schreiben werden seine Zielspalten eingerichtet. Außerhalb TABLE sind NULL oder nach diesem Trim leere Werte zulässig, sonst wird 51011 geworfen. Globale und permanente Tabellen sowie der reservierte #Monitor-Präfix sind unzulässig.';
        PRINT N'@JsonErzeugen bit; Default: 0. NULL, 0 oder 1. Nur 1 baut zusätzlich JSON in @Json; 0/NULL lässt @Json NULL. Die Gruppen memory, resourceSemaphores, memoryClerks und bufferPool werden unabhängig von der JSON-Ausgabe gesammelt, wenn ihre Quellen eingeschaltet sind. MaxZeilen begrenzt die drei Gruppenarrays, nicht memory.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Bindung nvarchar(max), mit vorab deklarierter nvarchar(max)-Variable und OUTPUT zu übergeben. Beim Eintritt wird sie auf NULL gesetzt; nur @JsonErzeugen=1 belegt sie nach Erfassung mit dem JSON-Dokument. Zusätzlicher Rückgabekanal, kein Resultset.';
        PRINT N'@PrintMeldungen bit; Default: 1. NULL, 0 oder 1. Der aktuelle Procedurekörper liest den Parameter nicht; er steuert keine PRINT-Ausgabe. Die Hilfeausgabe wird von @Hilfe gesteuert.';
        PRINT N'@Hilfe bit; Default: 0. NULL, 0 oder 1. Nur 1 druckt Objektname, Snapshotgrenze, Opt-in-Hinweis und Kurzangaben zu Limit/Modi und kehrt vor Quellensammlung zurück. TABLE-Mapping wird davor vorbereitet.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler varchar(40)-OUTPUT-Empfang. Werte und Bedeutungen: AVAILABLE (kein gesetzter Finding-, Teil- oder Fehlerstatus), AVAILABLE_WITH_FINDING (Semaphore-Waiter oder Speicher-Finding, sofern der Status zuvor AVAILABLE war), AVAILABLE_LIMITED (optionale Clerk- oder Descriptorquelle fehlerhaft), INVALID_PARAMETER (negatives Zeilenlimit oder ungültiger Ausgabemodus), DENIED_PERMISSION (klassifizierter Berechtigungsfehler einer Kernquelle), ERROR_HANDLED (sonstiger abgefangener Kernquellenfehler). Zuweisung nach Sammlung und vor JSON/Resultsets. Optional zum Empfang mit @StatusCodeOut=@Empfaenger OUTPUT und einer varchar(40)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionaler bit-OUTPUT-Empfang. 1 kennzeichnet ungültige Parameter, klassifizierte Berechtigungsfehler oder sonstige Kernquellenfehler einschließlich ERROR_HANDLED sowie Fehler optionaler Clerk-/Descriptorquellen. Ein optionaler Quellfehler führt zu AVAILABLE_LIMITED. Im regulären Ablauf ohne Teilfehler gilt 0, auch bei AVAILABLE_WITH_FINDING. Das Bit ist kein allgemeiner Vollständigkeitsbeweis. Optional zum Empfang mit @IsPartialOut=@Empfaenger OUTPUT und einer bit-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT-Bindung int. Bei abgefangenem Fehler einer Kernquelle oder optionalen Quelle enthält sie die SQL-Fehlernummer; sonst NULL. Bei mehreren optionalen Fehlern bleibt die erste Nummer erhalten. Mit int-Variable und OUTPUT binden; Hilfe weist nicht zu. Optional zum Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT und einer int-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT-Bindung nvarchar(2048). Enthält abgefangene Kernquellenmeldung oder ersten optionalen Quellenhinweis; sonst NULL. Mit kompatibler Variable und OUTPUT binden; Hilfe weist nicht zu. Optional zum Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT und einer nvarchar(2048)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.';
        PRINT N'EXEC [monitor].[USP_BufferPoolAnalysis] @MitMemoryClerks=1,@MitBufferPoolVerteilung=0,@MaxZeilen=50,@ResultSetArt=''RAW'';';
        PRINT N'DECLARE @JsonOut nvarchar(max); EXEC [monitor].[USP_BufferPoolAnalysis] @MitMemoryClerks=1,@MitBufferPoolVerteilung=0,@JsonErzeugen=1,@Json=@JsonOut OUTPUT,@ResultSetArt=''NONE''; SELECT @JsonOut AS [Json];';
        PRINT N'CREATE TABLE [#BufferPoolAnalysis_HelpExample]([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_BufferPoolAnalysis] @ResultSetArt=''TABLE'',@ResultTablesJson=N''{"memory":"#BufferPoolAnalysis_HelpExample"}''; SELECT * FROM [#BufferPoolAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#BufferPoolAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE IF EXISTS [#BufferPoolAnalysis_HelpExample];';
        PRINT N'EXEC [monitor].[USP_BufferPoolAnalysis] @Hilfe=1;';



        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;

    CREATE TABLE [#BufferPoolAnalysis_MemorySnapshot]
    (
          [PhysicalMemoryInUseKb] bigint NULL
        , [LockedPageAllocationsKb] bigint NULL
        , [LargePageAllocationsKb] bigint NULL
        , [MemoryUtilizationPercent] int NULL
        , [AvailableCommitLimitKb] bigint NULL
        , [ProcessPhysicalMemoryLow] bit NULL
        , [ProcessVirtualMemoryLow] bit NULL
        , [TotalPhysicalMemoryKb] bigint NULL
        , [AvailablePhysicalMemoryKb] bigint NULL
        , [AvailablePhysicalMemoryPercent] decimal(9,2) NULL
        , [SystemMemoryStateDesc] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FindingSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#BufferPoolAnalysis_ResourceSemaphores]
    (
          [PoolId] int NULL
        , [ResourceSemaphoreId] smallint NULL
        , [TotalMemoryKb] bigint NULL
        , [AvailableMemoryKb] bigint NULL
        , [GrantedMemoryKb] bigint NULL
        , [UsedMemoryKb] bigint NULL
        , [GranteeCount] int NULL
        , [WaiterCount] int NULL
        , [TimeoutErrorCount] bigint NULL
        , [ForcedGrantCount] bigint NULL
    );
    CREATE TABLE [#BufferPoolAnalysis_MemoryClerks]
    (
          [ClerkType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PagesKb] bigint NULL
        , [VirtualMemoryReservedKb] bigint NULL
        , [VirtualMemoryCommittedKb] bigint NULL
        , [LockedOrAweKb] bigint NULL
        , [ClerkCount] bigint NOT NULL
    );
    CREATE TABLE [#BufferPoolAnalysis_BufferPool]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CachedPages] bigint NOT NULL
        , [CachedSizeMb] decimal(19,2) NOT NULL
        , [DirtyPages] bigint NOT NULL
        , [DirtySizeMb] decimal(19,2) NOT NULL
        , [FreeSpaceMb] decimal(19,2) NOT NULL
        , [NumaNodeCount] bigint NOT NULL
    );

    IF @MaxZeilen < 0 OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER', @IsPartial = 1,
               @ErrorMessage = N'Ungültiger Zeilen- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        BEGIN TRY
            INSERT [#BufferPoolAnalysis_MemorySnapshot]
            SELECT
                  [p].[physical_memory_in_use_kb]
                , [p].[locked_page_allocations_kb]
                , [p].[large_page_allocations_kb]
                , [p].[memory_utilization_percentage]
                , [p].[available_commit_limit_kb]
                , [p].[process_physical_memory_low]
                , [p].[process_virtual_memory_low]
                , [s].[total_physical_memory_kb]
                , [s].[available_physical_memory_kb]
                , CONVERT(decimal(9,2), 100.0 * [s].[available_physical_memory_kb]
                  / NULLIF([s].[total_physical_memory_kb], 0))
                , [s].[system_memory_state_desc]
                , CASE WHEN [p].[process_physical_memory_low] = 1 THEN 'PROCESS_PHYSICAL_MEMORY_LOW'
                       WHEN [p].[process_virtual_memory_low] = 1 THEN 'PROCESS_VIRTUAL_MEMORY_LOW'
                       WHEN [s].[available_physical_memory_kb] * 100.0
                            / NULLIF([s].[total_physical_memory_kb], 0) < 5 THEN 'OS_AVAILABLE_MEMORY_BELOW_5_PERCENT'
                       ELSE 'NO_MEMORY_PRESSURE_FLAG' END
                , CASE WHEN [p].[process_physical_memory_low] = 1
                            OR [p].[process_virtual_memory_low] = 1 THEN 'HIGH'
                       WHEN [s].[available_physical_memory_kb] * 100.0
                            / NULLIF([s].[total_physical_memory_kb], 0) < 5 THEN 'MEDIUM'
                       ELSE 'INFO' END
                , N'Momentaufnahme; Verlauf, andere Prozesse und Betriebssystemgrenzen separat prüfen.'
            FROM [sys].[dm_os_process_memory] AS [p] WITH (NOLOCK)
            CROSS JOIN [sys].[dm_os_sys_memory] AS [s] WITH (NOLOCK);

            INSERT [#BufferPoolAnalysis_ResourceSemaphores]
            SELECT
                  [pool_id], [resource_semaphore_id], [total_memory_kb]
                , [available_memory_kb], [granted_memory_kb], [used_memory_kb]
                , [grantee_count], [waiter_count], [timeout_error_count]
                , [forced_grant_count]
            FROM [sys].[dm_exec_query_resource_semaphores] WITH (NOLOCK);
        END TRY
        BEGIN CATCH
            SELECT @StatusCode = CASE WHEN ERROR_NUMBER() IN (229, 297, 300, 371)
                                      THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
                   @IsPartial = 1, @ErrorNumber = ERROR_NUMBER(), @ErrorMessage = ERROR_MESSAGE();
        END CATCH;

        IF @StatusCode IN ('AVAILABLE', 'AVAILABLE_LIMITED') AND @MitMemoryClerks = 1
        BEGIN
            BEGIN TRY
                INSERT [#BufferPoolAnalysis_MemoryClerks]
                SELECT
                      [type], SUM(CONVERT(bigint, [pages_kb]))
                    , SUM(CONVERT(bigint, [virtual_memory_reserved_kb]))
                    , SUM(CONVERT(bigint, [virtual_memory_committed_kb]))
                    , SUM(CONVERT(bigint, [awe_allocated_kb]))
                      + SUM(CONVERT(bigint, [shared_memory_committed_kb]))
                    , COUNT_BIG(*)
                FROM [sys].[dm_os_memory_clerks] WITH (NOLOCK)
                GROUP BY [type];
            END TRY
            BEGIN CATCH
                SELECT @IsPartial = 1, @StatusCode = 'AVAILABLE_LIMITED';
                IF @ErrorNumber IS NULL
                    SELECT @ErrorNumber = ERROR_NUMBER(),
                           @ErrorMessage = CONCAT(N'Memory Clerks nicht lesbar: ', ERROR_MESSAGE());
            END CATCH;
        END;

        IF @StatusCode IN ('AVAILABLE', 'AVAILABLE_LIMITED') AND @MitBufferPoolVerteilung = 1
        BEGIN
            BEGIN TRY
                INSERT [#BufferPoolAnalysis_BufferPool]
                SELECT
                      [b].[database_id], [d].[name], COUNT_BIG(*)
                    , CONVERT(decimal(19,2), COUNT_BIG(*) * 8.0 / 1024.0)
                    , SUM(CONVERT(bigint, CASE WHEN [is_modified] = 1 THEN 1 ELSE 0 END))
                    , CONVERT(decimal(19,2),
                      SUM(CONVERT(bigint, CASE WHEN [is_modified] = 1 THEN 1 ELSE 0 END)) * 8.0 / 1024.0)
                    , CONVERT(decimal(19,2), SUM(CONVERT(bigint, [free_space_in_bytes])) / 1048576.0)
                    , COUNT_BIG(DISTINCT [numa_node])
                FROM [sys].[dm_os_buffer_descriptors] AS [b] WITH (NOLOCK)
                LEFT JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
                  ON [d].[database_id]=[b].[database_id]
                GROUP BY [b].[database_id],[d].[name];
            END TRY
            BEGIN CATCH
                SELECT @IsPartial = 1, @StatusCode = 'AVAILABLE_LIMITED';
                IF @ErrorNumber IS NULL
                    SELECT @ErrorNumber = ERROR_NUMBER(),
                           @ErrorMessage = CONCAT(N'Buffer-Pool-Verteilung nicht lesbar: ', ERROR_MESSAGE());
            END CATCH;
        END;

        IF (EXISTS (SELECT 1 FROM [#BufferPoolAnalysis_ResourceSemaphores] WHERE [WaiterCount] > 0)
            OR EXISTS (SELECT 1 FROM [#BufferPoolAnalysis_MemorySnapshot] WHERE [FindingCode] <> 'NO_MEMORY_PRESSURE_FLAG'))
           AND @StatusCode = 'AVAILABLE'
            SET @StatusCode = 'AVAILABLE_WITH_FINDING';
    END;

    SELECT @StatusCodeOut = @StatusCode, @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber, @ErrorMessageOut = @ErrorMessage;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
            (SELECT N'BufferPoolAnalysis' AS [resultName], 1 AS [schemaVersion],
                    @Now AS [generatedAtUtc], @StatusCode AS [statusCode], @IsPartial AS [isPartial],
                    @MitBufferPoolVerteilung AS [bufferPoolDistributionCollected]
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
        DECLARE @SnapshotJson nvarchar(max) =
            (SELECT * FROM [#BufferPoolAnalysis_MemorySnapshot] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @SemaphoreJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#BufferPoolAnalysis_ResourceSemaphores]
             ORDER BY [WaiterCount] DESC, [PoolId], [ResourceSemaphoreId]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @ClerkJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#BufferPoolAnalysis_MemoryClerks]
             ORDER BY [PagesKb] DESC, [ClerkType] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @BufferJson nvarchar(max) =
            (SELECT TOP (@Limit) * FROM [#BufferPoolAnalysis_BufferPool]
             ORDER BY [CachedPages] DESC, [DatabaseId] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson, N'{}'),
                           N',"memory":', COALESCE(@SnapshotJson, N'[]'),
                           N',"resourceSemaphores":', COALESCE(@SemaphoreJson, N'[]'),
                           N',"memoryClerks":', COALESCE(@ClerkJson, N'[]'),
                           N',"bufferPool":', COALESCE(@BufferJson, N'[]'), N'}');
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT N'USP_BufferPoolAnalysis' AS [ModuleName], @Now AS [CollectionTimeUtc],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial],
               @MitBufferPoolVerteilung AS [BufferPoolDistributionCollected],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage],
               N'Momentaufnahme; Buffer-Pool-Scan ist opt-in.' AS [Detail];
        SELECT * FROM [#BufferPoolAnalysis_MemorySnapshot];
        SELECT TOP (@Limit) * FROM [#BufferPoolAnalysis_ResourceSemaphores]
        ORDER BY [WaiterCount] DESC, [PoolId], [ResourceSemaphoreId];
        SELECT TOP (@Limit) * FROM [#BufferPoolAnalysis_MemoryClerks] ORDER BY [PagesKb] DESC, [ClerkType];
        SELECT TOP (@Limit) * FROM [#BufferPoolAnalysis_BufferPool] ORDER BY [CachedPages] DESC, [DatabaseId];
    END
    ELSE IF @OutputMode = 'CONSOLE'
    BEGIN
        SELECT N'Buffer Pool und Speicherdruck' AS [Ergebnis], @Now AS [Stand_UTC],
               @StatusCode AS [Status], @IsPartial AS [Teilweise], @ErrorMessage AS [Hinweis];
        SELECT N'Speichermomentaufnahme' AS [Ergebnis], [PhysicalMemoryInUseKb] AS [SQL_Physisch_KB],
               [AvailablePhysicalMemoryKb] AS [OS_Verfuegbar_KB],
               [AvailablePhysicalMemoryPercent] AS [OS_Verfuegbar_Prozent],
               [ProcessPhysicalMemoryLow] AS [SQL_Physisch_Niedrig],
               [ProcessVirtualMemoryLow] AS [SQL_Virtuell_Niedrig],
               [FindingCode] AS [Befund], [FindingSeverity] AS [Prioritaet], [EvidenceLimit] AS [Grenze]
        FROM [#BufferPoolAnalysis_MemorySnapshot];
        SELECT TOP (@Limit) N'Resource Semaphore' AS [Ergebnis], [PoolId] AS [Pool_ID],
               [ResourceSemaphoreId] AS [Semaphore_ID], [AvailableMemoryKb] AS [Verfuegbar_KB],
               [GrantedMemoryKb] AS [Zugewiesen_KB], [GranteeCount] AS [Zuteilungen],
               [WaiterCount] AS [Wartende], [TimeoutErrorCount] AS [Timeouts]
        FROM [#BufferPoolAnalysis_ResourceSemaphores]
        ORDER BY [WaiterCount] DESC, [PoolId], [ResourceSemaphoreId];
        SELECT TOP (@Limit) N'Memory Clerk' AS [Ergebnis], [ClerkType] AS [Typ],
               [PagesKb] AS [Pages_KB], [VirtualMemoryCommittedKb] AS [Virtuell_Committed_KB],
               [LockedOrAweKb] AS [Locked_oder_AWE_KB], [ClerkCount] AS [Instanzen]
        FROM [#BufferPoolAnalysis_MemoryClerks] ORDER BY [PagesKb] DESC, [ClerkType];
        SELECT TOP (@Limit) N'Buffer-Pool-Verteilung' AS [Ergebnis], [DatabaseName] AS [Datenbank],
               [CachedSizeMb] AS [Cache_MB], [DirtySizeMb] AS [Dirty_MB],
               [FreeSpaceMb] AS [Freiraum_in_Seiten_MB], [NumaNodeCount] AS [NUMA_Nodes]
        FROM [#BufferPoolAnalysis_BufferPool] ORDER BY [CachedPages] DESC, [DatabaseId];
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#BufferPoolAnalysis_MemorySnapshot'
            , @ResultLabel=N'BufferPoolAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#BufferPoolAnalysis_MemorySnapshot'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
