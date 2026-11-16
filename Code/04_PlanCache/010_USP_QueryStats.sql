USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_QueryStats
Version      : 2.1.0
Stand        : 2026-07-19
Zweck        : Liefert kumulative Statement-Statistiken des aktuellen Plan
               Cache. Datenbanknamen unterstützen bracket-aware Pipe-Listen
               und LIKE-/Regex-Patterns. RAW, CONSOLE und JSON verwenden
               dieselbe intern materialisierte Datenbasis.
SQL-Version  : SQL Server 2019 oder neuer; Regex nur ab SQL Server 2025 und
               Compatibility Level 170.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_QueryStats]
      @DatabaseNames                  nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen   bit            = 0
    , @DatabaseNamePattern            nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @QueryHash                      binary(8)      = NULL
    , @QueryPlanHash                  binary(8)      = NULL
    , @SqlHandle                      varbinary(64)  = NULL
    , @PlanHandle                     varbinary(64)  = NULL
    , @TextPattern                    nvarchar(4000) = NULL
    , @Sortierung                     varchar(32)    = 'CPU_TOTAL'
    , @AnalyseModus                   varchar(16)    = 'TOP'
    , @MinExecutionCount              bigint         = 1
    , @VonUtc                         datetime2(7)    = NULL
    , @MaxZeilen                      int            = 100
    , @MaxSqlTextZeichen              int            = 4000
    , @ParentQueryStatsSnapshot       bit            = 0
    , @ResultSetArt                   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                   bit            = 0
    , @Json                           nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                 bit            = 1
    , @Hilfe                          bit            = 0
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
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'queries',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Mode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus, 'TOP'))));
    DECLARE @Order varchar(32) = UPPER(LTRIM(RTRIM(COALESCE(@Sortierung, 'CPU_TOTAL'))));
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint, 9223372036854775807)
                                 WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen) ELSE 0 END;
    DECLARE @CandidateRows bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint, 9223372036854775807)
                                         WHEN @MaxZeilen < 2147483647 THEN CONVERT(bigint, @MaxZeilen) + 1 ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_QueryStats';
        PRINT N'Die Procedure rangiert aktuell gecachte Statements nach Verbrauch, Ausführungszahl und letzter Ausführung. Der Cache erfasst nur die derzeit sichtbaren Einträge.';
        PRINT N'@DatabaseNames nvarchar(max). Default ist NULL. Pipe-Liste exakter Datenbanknamen; NULL, leer oder nur Leerzeichen = keine exakte Einschränkung. | trennt außerhalb von [...]; ]] maskiert ] innerhalb; äußere Segmentleerzeichen entfernt. Elemente einteilige Namen bis 128 Zeichen; ungültige Liste INVALID_PARAMETER.';
        PRINT N'@SystemdatenbankenEinbeziehen bit. Default ist 0. 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL führt zur Parameterablehnung; ausgelassen = 0. SQL-bit-Konvertierung kann numerische Nichtnullwerte als 1 abbilden.';
        PRINT N'@DatabaseNamePattern nvarchar(4000). Default ist NULL. Ein LIKE-Pattern oder Präfix like:, regex:, regexi:. Erkennung ohne Beachtung der Großschreibung; äußere Leerzeichen getrimmt, Musterrest nicht erneut. NULL = kein Pattern; leerer Inhalt ungültig. Nicht mit wirksamer @DatabaseNames-Liste kombinierbar. Regex Flag c/i und Ausführung nur SQL Server 2025 + Compatibility Level 170 der Installationsdatenbank; sonst UNAVAILABLE_FEATURE.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. 0 lässt den hohen Aufwand unbestätigt. 1 bestätigt einen geschützten Pfad. Die Berechtigung wird zusätzlich geprüft. NULL ist für die Pfadprüfung ungültig.';
        PRINT N'@QueryHash binary(8). Default ist NULL. Optionaler exakter 8-Byte Query Hash; NULL = kein Hashfilter. Andere Längen/Typkonvertierungen richten sich nach T-SQL-Bindung; keine zusätzliche Hexstring-Validierung im Procedurecode.';
        PRINT N'@QueryPlanHash binary(8). Default ist NULL. Optionaler exakter 8-Byte Planhash; NULL = kein Planhashfilter.';
        PRINT N'@SqlHandle varbinary(64). Default ist NULL. Optionaler SQL-Handle bis 64 Byte; NULL = kein Handlefilter.';
        PRINT N'@PlanHandle varbinary(64). Default ist NULL. Optionaler Plan-Handle bis 64 Byte; NULL = kein Handlefilter.';
        PRINT N'@TextPattern nvarchar(4000). Default ist NULL. SQL-Textpattern. NULL = kein Filter; Parser erkennt case-insensitive like:, regex:, regexi:, sonst LIKE. Außenleerzeichen getrimmt, Patternrest nicht. Leerer effektiver Inhalt INVALID_PARAMETER. Nicht als Pipe-Liste zerlegt. LIKE nutzt %/_/SQL LIKE-Syntax; Regex braucht SQL Server 2025 und Installations-DB-Kompatibilität 170, Syntaxfehler werden von Regex-Ausführung gemeldet.';
        PRINT N'@Sortierung varchar(32). Default ist ''CPU_TOTAL''. Case-insensitive nach LTRIM/RTRIM; geschlossene Menge: CPU_TOTAL = kumulative CPU; CPU_AVG = CPU je Ausführung; ELAPSED_TOTAL = kumulative Laufzeit; ELAPSED_AVG = Laufzeit je Ausführung; READS_TOTAL = kumulative logische Reads; READS_AVG = logische Reads je Ausführung; WRITES_TOTAL = kumulative logische Writes; WRITES_AVG = logische Writes je Ausführung; EXECUTIONS = Ausführungszahl; GRANT_MAX = maximaler Grant; SPILLS_TOTAL = kumulative Spills; ROWS_TOTAL = kumulative Zeilen; LAST_EXECUTION = letzte Ausführungszeit. NULL normalisiert auf Default. Ungültiger Wert INVALID_PARAMETER.';
        PRINT N'@AnalyseModus varchar(16). Default ist ''TOP''. TOP verwendet bei einem positiven Limit bis 1000 den aktuellen Plan-Cache-Pfad. VOLL prüft PLAN_CACHE_DEEP und behält das Zeilenlimit bei. NULL entspricht TOP. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte ergeben INVALID_PARAMETER.';
        PRINT N'@MinExecutionCount bigint. Default ist 1. Ganzzahliges Minimum für execution_count. 0 lässt auch Einträge mit 0 Ausführungen zu. Negative Werte ergeben INVALID_PARAMETER. Bei NULL trifft der Vergleich auf keine Zeile.';
        PRINT N'@VonUtc datetime2(7). Default ist NULL. Inklusiver Grenzwert für last_execution_time als datetime2-Wert, z. B. 2026-01-01T00:00:00. Die Procedure vergleicht direkt mit dem Cachewert und rechnet keine Zeitzone um. NULL lässt den Zeitfilter aus.';
        PRINT N'@MaxZeilen int. Default ist 100. Positiv begrenzt Ausgabe; NULL oder 0 bedeutet unbegrenzt; negativ INVALID_PARAMETER. Ausgelassen = 100. Unbegrenzt oder >1000 sowie VOLL erfordern PLAN_CACHE_DEEP. Positive Auswahl sammelt bis Limit+1 zur HasMoreRows-Ermittlung.';
        PRINT N'@MaxSqlTextZeichen int. Default ist 4000. Positiv kürzt Statement- und Batchtext auf Zeichenlimit; NULL oder 0 bedeutet ungekürzt; negativ INVALID_PARAMETER. Zeichenprojektion zählt unter SC-Collation, nicht Grapheme.';
        PRINT N'@ParentQueryStatsSnapshot bit. Default ist 0. 0 = DMV frisch lesen; 1 = ausschließlich laufinterne Wiederverwendung durch USP_PlanCacheAnalysis. NULL INVALID_PARAMETER. Schalter ist kein öffentlicher externer Snapshotvertrag.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. CONSOLE zeigt die beschriftete Abfrageauswahl. RAW liefert Modulstatus, Abfragezeilen und Auswahlwarnungen. TABLE schreibt das benannte Resultset queries. NONE unterdrückt die fachlichen Resultsets. Rand-Leerzeichen werden entfernt und die Groß- und Kleinschreibung normalisiert. NULL, leere Eingaben und andere Werte ergeben INVALID_PARAMETER.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein JSON-Objekt mit genau dem Schlüssel queries und einem Tabellennamen als Zeichenfolgenwert erforderlich. Verwenden Sie eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und das Präfix #Monitor sind ausgeschlossen. Bei den übrigen Ausgabearten sind nur NULL, die leere Zeichenfolge und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json zusätzlich zur gewählten Ausgabeart. 0 deaktiviert JSON. NULL ergibt INVALID_PARAMETER.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie das JSON-Dokument mit meta, queries und warnings.';
        PRINT N'@PrintMeldungen bit. Default ist 1. 1 gibt informative Meldungen zu Status und gegebenenfalls Textkürzung aus. 0 und NULL unterdrücken diese Meldungen.';
        PRINT N'@Hilfe bit. Default ist 0. 1 gibt die Hilfe aus und beendet den Aufruf vor der fachlichen Analyse. Die Initialisierung von @Json und die Prüfung der TABLE-Zuordnung laufen zuerst. 0 und NULL setzen den regulären Aufruf fort.';
        PRINT N'Hilfe anzeigen. EXEC [monitor].[USP_QueryStats] @Hilfe=1;';
        PRINT N'Technische Resultsets lesen. EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt=''RAW'';';
        PRINT N'Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];';
        PRINT N'Benanntes Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #QueryStats_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_QueryStats] @QueryHash=0x0000000000000001, @MaxZeilen=50, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"queries":"#QueryStats_HelpExample"}''; SELECT * FROM #QueryStats_HelpExample; DROP TABLE #QueryStats_HelpExample; END TRY BEGIN CATCH DROP TABLE #QueryStats_HelpExample; THROW; END CATCH;';
        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;
    DECLARE @Allowed bit = 1;
    DECLARE @RowCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @Message nvarchar(2048);
    DECLARE @Sql nvarchar(max);
    DECLARE @OrderExpression nvarchar(256);
    DECLARE @TextMode varchar(8);
    DECLARE @TextValue nvarchar(4000);
    DECLARE @TextRegexFlags varchar(8);
    DECLARE @TextPatternValid bit;

    CREATE TABLE [#QueryStats_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
    );
    CREATE TABLE [#QueryStats_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#QueryStats_Result]
    (
          [QueryHash] binary(8) NULL
        , [QueryPlanHash] binary(8) NULL
        , [PlanHandle] varbinary(64) NOT NULL
        , [SqlHandle] varbinary(64) NOT NULL
        , [StatementStartOffset] int NOT NULL
        , [StatementEndOffset] int NOT NULL
        , [PlanGenerationNumber] bigint NOT NULL
        , [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectId] int NULL
        , [StatementTextCharacters] bigint NULL
        , [StatementTextBytes] bigint NULL
        , [StatementTextIsTruncated] bit NOT NULL DEFAULT(0)
        , [StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [BatchTextCharacters] bigint NULL
        , [BatchTextBytes] bigint NULL
        , [BatchTextIsTruncated] bit NOT NULL DEFAULT(0)
        , [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CreationTime] datetime NOT NULL
        , [LastExecutionTime] datetime NOT NULL
        , [ExecutionCount] bigint NOT NULL
        , [TotalCpuMs] decimal(38,3) NULL
        , [LastCpuMs] decimal(38,3) NULL
        , [MinCpuMs] decimal(38,3) NULL
        , [MaxCpuMs] decimal(38,3) NULL
        , [AvgCpuMs] decimal(38,3) NULL
        , [TotalElapsedMs] decimal(38,3) NULL
        , [LastElapsedMs] decimal(38,3) NULL
        , [MinElapsedMs] decimal(38,3) NULL
        , [MaxElapsedMs] decimal(38,3) NULL
        , [AvgElapsedMs] decimal(38,3) NULL
        , [TotalLogicalReads] bigint NOT NULL
        , [LastLogicalReads] bigint NOT NULL
        , [AvgLogicalReads] decimal(38,3) NULL
        , [TotalLogicalWrites] bigint NOT NULL
        , [LastLogicalWrites] bigint NOT NULL
        , [AvgLogicalWrites] decimal(38,3) NULL
        , [TotalPhysicalReads] bigint NOT NULL
        , [LastPhysicalReads] bigint NOT NULL
        , [TotalRows] bigint NOT NULL
        , [LastRows] bigint NOT NULL
        , [MinRows] bigint NOT NULL
        , [MaxRows] bigint NOT NULL
        , [LastDop] bigint NOT NULL
        , [MinDop] bigint NOT NULL
        , [MaxDop] bigint NOT NULL
        , [MaxGrantKb] bigint NOT NULL
        , [LastGrantKb] bigint NOT NULL
        , [LastUsedGrantKb] bigint NOT NULL
        , [LastIdealGrantKb] bigint NOT NULL
        , [TotalSpilledPages] bigint NOT NULL
        , [LastSpilledPages] bigint NOT NULL
        , [CacheObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PlanUseCounts] int NULL
        , [PlanSizeBytes] bigint NULL
        , [ResourcePoolId] int NULL
        , [SetOptions] int NULL
        , [CompileUserId] int NULL
        , [SortValue] decimal(38,4) NULL
    );

    SELECT
          @TextMode = [PatternMode]
        , @TextValue = [PatternValue]
        , @TextRegexFlags = [RegexFlags]
        , @TextPatternValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@TextPattern);

    SET @OrderExpression = CASE @Order
        WHEN 'CPU_TOTAL' THEN N'[qs].[total_worker_time]'
        WHEN 'CPU_AVG' THEN N'[qs].[total_worker_time] * 1.0 / NULLIF([qs].[execution_count], 0)'
        WHEN 'ELAPSED_TOTAL' THEN N'[qs].[total_elapsed_time]'
        WHEN 'ELAPSED_AVG' THEN N'[qs].[total_elapsed_time] * 1.0 / NULLIF([qs].[execution_count], 0)'
        WHEN 'READS_TOTAL' THEN N'[qs].[total_logical_reads]'
        WHEN 'READS_AVG' THEN N'[qs].[total_logical_reads] * 1.0 / NULLIF([qs].[execution_count], 0)'
        WHEN 'WRITES_TOTAL' THEN N'[qs].[total_logical_writes]'
        WHEN 'WRITES_AVG' THEN N'[qs].[total_logical_writes] * 1.0 / NULLIF([qs].[execution_count], 0)'
        WHEN 'EXECUTIONS' THEN N'[qs].[execution_count]'
        WHEN 'GRANT_MAX' THEN N'[qs].[max_grant_kb]'
        WHEN 'SPILLS_TOTAL' THEN N'[qs].[total_spills]'
        WHEN 'ROWS_TOTAL' THEN N'[qs].[total_rows]'
        WHEN 'LAST_EXECUTION' THEN N'DATEDIFF_BIG(MILLISECOND, ''20000101'', [qs].[last_execution_time])'
    END;

    IF @Mode NOT IN ('TOP', 'VOLL')
       OR @OrderExpression IS NULL
       OR @MaxZeilen < 0

       OR @MinExecutionCount < 0
       OR @MaxSqlTextZeichen < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
       OR @TextPatternValid = 0
       OR @JsonErzeugen IS NULL
       OR @ParentQueryStatsSnapshot IS NULL
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens ein Parameter besitzt einen ungültigen Wert.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass = 'PLAN_CACHE_CURRENT'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT,@CandidateTable=N'#QueryStats_DatabaseCandidates',@WarningTable=N'#QueryStats_DatabaseCandidateWarnings';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND (@Mode = 'VOLL' OR @Limit > 1000 OR @Limit = 9223372036854775807)
    BEGIN
        EXEC [monitor].[InternalCheckAnalysisPath]
              @AnalysisClass='PLAN_CACHE_DEEP'
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT;
    END;

    IF @StatusCode = 'AVAILABLE'
       AND @TextMode IN ('REGEX', 'REGEXI')
       AND
       (
           TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) < 17
           OR NOT EXISTS
              (
                  SELECT 1
                  FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
                  WHERE [d].[database_id] = DB_ID()
                    AND [d].[compatibility_level] >= 170
              )
       )
    BEGIN
        SET @StatusCode = 'UNAVAILABLE_FEATURE';
        SET @ErrorMessage = N'Regex benötigt SQL Server 2025 und Compatibility Level 170 für die Installationsdatenbank.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        SET @Sql = CONVERT(nvarchar(max),N'') + N'
INSERT [#QueryStats_Result]
(
      [QueryHash], [QueryPlanHash], [PlanHandle], [SqlHandle]
    , [StatementStartOffset], [StatementEndOffset], [PlanGenerationNumber]
    , [DatabaseId], [DatabaseName], [ObjectId]
    , [StatementTextCharacters], [StatementTextBytes], [StatementTextIsTruncated], [StatementText]
    , [BatchTextCharacters], [BatchTextBytes], [BatchTextIsTruncated], [BatchText]
    , [CreationTime], [LastExecutionTime], [ExecutionCount]
    , [TotalCpuMs], [LastCpuMs], [MinCpuMs], [MaxCpuMs], [AvgCpuMs]
    , [TotalElapsedMs], [LastElapsedMs], [MinElapsedMs], [MaxElapsedMs], [AvgElapsedMs]
    , [TotalLogicalReads], [LastLogicalReads], [AvgLogicalReads]
    , [TotalLogicalWrites], [LastLogicalWrites], [AvgLogicalWrites]
    , [TotalPhysicalReads], [LastPhysicalReads]
    , [TotalRows], [LastRows], [MinRows], [MaxRows]
    , [LastDop], [MinDop], [MaxDop]
    , [MaxGrantKb], [LastGrantKb], [LastUsedGrantKb], [LastIdealGrantKb]
    , [TotalSpilledPages], [LastSpilledPages]
    , [CacheObjectType], [ObjectType], [PlanUseCounts], [PlanSizeBytes]
    , [ResourcePoolId], [SetOptions], [CompileUserId], [SortValue]
)
SELECT TOP (@CandidateRows)
      [qs].[query_hash]
    , [qs].[query_plan_hash]
    , [qs].[plan_handle]
    , [qs].[sql_handle]
    , [qs].[statement_start_offset]
    , [qs].[statement_end_offset]
    , [qs].[plan_generation_num]
    , [resolved].[DatabaseId]
    , [dbc].[DatabaseName]
    , [st].[objectid]
    , NULL,NULL,CONVERT(bit,0),[statementText].[StatementText]
    , NULL,NULL,CONVERT(bit,0),[st].[text]
    , [qs].[creation_time]
    , [qs].[last_execution_time]
    , [qs].[execution_count]
    , CONVERT(decimal(38,3), [qs].[total_worker_time] / 1000.0)
    , CONVERT(decimal(38,3), [qs].[last_worker_time] / 1000.0)
    , CONVERT(decimal(38,3), [qs].[min_worker_time] / 1000.0)
    , CONVERT(decimal(38,3), [qs].[max_worker_time] / 1000.0)
    , CONVERT(decimal(38,3), [qs].[total_worker_time] / NULLIF([qs].[execution_count],0) / 1000.0)
    , CONVERT(decimal(38,3), [qs].[total_elapsed_time] / 1000.0)
    , CONVERT(decimal(38,3), [qs].[last_elapsed_time] / 1000.0)
    , CONVERT(decimal(38,3), [qs].[min_elapsed_time] / 1000.0)
    , CONVERT(decimal(38,3), [qs].[max_elapsed_time] / 1000.0)
    , CONVERT(decimal(38,3), [qs].[total_elapsed_time] / NULLIF([qs].[execution_count],0) / 1000.0)
    , [qs].[total_logical_reads]
    , [qs].[last_logical_reads]
    , CONVERT(decimal(38,3), [qs].[total_logical_reads] * 1.0 / NULLIF([qs].[execution_count],0))
    , [qs].[total_logical_writes]
    , [qs].[last_logical_writes]
    , CONVERT(decimal(38,3), [qs].[total_logical_writes] * 1.0 / NULLIF([qs].[execution_count],0))
    , [qs].[total_physical_reads]
    , [qs].[last_physical_reads]
    , [qs].[total_rows]
    , [qs].[last_rows]
    , [qs].[min_rows]
    , [qs].[max_rows]
    , [qs].[last_dop]
    , [qs].[min_dop]
    , [qs].[max_dop]
    , [qs].[max_grant_kb]
    , [qs].[last_grant_kb]
    , [qs].[last_used_grant_kb]
    , [qs].[last_ideal_grant_kb]
    , [qs].[total_spills]
    , [qs].[last_spills]
    , [cp].[cacheobjtype]
    , [cp].[objtype]
    , [cp].[usecounts]
    , [cp].[size_in_bytes]
    , [cp].[pool_id]
    , TRY_CONVERT(int, [setOptions].[value])
    , TRY_CONVERT(int, [compileUser].[value])
    , CONVERT(decimal(38,4), ' + @OrderExpression + N')
FROM ' + CASE WHEN @ParentQueryStatsSnapshot=1
              THEN N'[#PlanCacheAnalysis_QueryStatsSnapshot] AS [qs]'
              ELSE N'[sys].[dm_exec_query_stats] AS [qs] WITH (NOLOCK)' END + N'
OUTER APPLY [sys].[dm_exec_sql_text]([qs].[sql_handle]) AS [st]
OUTER APPLY [monitor].[TVF_StatementText]
(
      [st].[text]
    , [qs].[statement_start_offset]
    , [qs].[statement_end_offset]
) AS [statementText]
OUTER APPLY
(
    SELECT TOP (1) TRY_CONVERT(int, [pa].[value]) AS [DatabaseId]
    FROM [sys].[dm_exec_plan_attributes]([qs].[plan_handle]) AS [pa]
    WHERE [pa].[attribute] = ''dbid''
) AS [planDb]
CROSS APPLY
(
    SELECT COALESCE([st].[dbid], [planDb].[DatabaseId]) AS [DatabaseId]
) AS [resolved]
INNER JOIN [#QueryStats_DatabaseCandidates] AS [dbc]
  ON [dbc].[DatabaseId] = [resolved].[DatabaseId]
LEFT JOIN [sys].[dm_exec_cached_plans] AS [cp] WITH (NOLOCK)
  ON [cp].[plan_handle] = [qs].[plan_handle]
OUTER APPLY
(
    SELECT TOP (1) [pa].[value]
    FROM [sys].[dm_exec_plan_attributes]([qs].[plan_handle]) AS [pa]
    WHERE [pa].[attribute] = ''set_options''
) AS [setOptions]
OUTER APPLY
(
    SELECT TOP (1) [pa].[value]
    FROM [sys].[dm_exec_plan_attributes]([qs].[plan_handle]) AS [pa]
    WHERE [pa].[attribute] = ''user_id''
) AS [compileUser]
WHERE [qs].[execution_count] >= @MinExecutions
  AND (@Since IS NULL OR [qs].[last_execution_time] >= @Since)
  AND (@QH IS NULL OR [qs].[query_hash] = @QH)
  AND (@QPH IS NULL OR [qs].[query_plan_hash] = @QPH)
  AND (@SH IS NULL OR [qs].[sql_handle] = @SH)
  AND (@PH IS NULL OR [qs].[plan_handle] = @PH)
  AND (@TextMode IN (''NONE'', ''REGEX'', ''REGEXI'') OR [st].[text] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @TextValue COLLATE SQL_Latin1_General_CP1_CS_AS)'
  + CASE WHEN @TextMode IN ('REGEX', 'REGEXI')
         THEN N'
  AND REGEXP_LIKE([st].[text], @TextValue, @TextFlags)'
         ELSE N'' END
  + N'
ORDER BY ' + @OrderExpression + N' DESC, [qs].[last_execution_time] DESC
OPTION (RECOMPILE, MAXDOP 1);';

        EXEC [sys].[sp_executesql]
              @Sql
            , N'@CandidateRows bigint, @TextChars int, @MinExecutions bigint, @Since datetime2(7), @QH binary(8), @QPH binary(8), @SH varbinary(64), @PH varbinary(64), @TextMode varchar(8), @TextValue nvarchar(4000), @TextFlags varchar(8)'
            , @CandidateRows = @CandidateRows
            , @TextChars = @MaxSqlTextZeichen
            , @MinExecutions = @MinExecutionCount
            , @Since = @VonUtc
            , @QH = @QueryHash
            , @QPH = @QueryPlanHash
            , @SH = @SqlHandle
            , @PH = @PlanHandle
            , @TextMode = @TextMode
            , @TextValue = @TextValue
            , @TextFlags = @TextRegexFlags;

        DECLARE @TruncatedValueCount bigint=0,@LargestRequiredCharacters bigint=NULL;
        DECLARE @ColumnTruncatedCount bigint=0,@ColumnLargestCharacters bigint=NULL;
        EXEC [monitor].[InternalProjectUnicodeTextColumn]
              @SourceTable=N'#QueryStats_Result',@TextColumn=N'StatementText'
            , @CharactersColumn=N'StatementTextCharacters',@BytesColumn=N'StatementTextBytes'
            , @IsTruncatedColumn=N'StatementTextIsTruncated',@MaxCharacters=@MaxSqlTextZeichen
            , @TruncatedValueCount=@ColumnTruncatedCount OUTPUT,@LargestRequiredCharacters=@ColumnLargestCharacters OUTPUT;
        SELECT @TruncatedValueCount=@TruncatedValueCount+@ColumnTruncatedCount,
               @LargestRequiredCharacters=CASE WHEN @LargestRequiredCharacters IS NULL OR @ColumnLargestCharacters>@LargestRequiredCharacters THEN @ColumnLargestCharacters ELSE @LargestRequiredCharacters END;
        EXEC [monitor].[InternalProjectUnicodeTextColumn]
              @SourceTable=N'#QueryStats_Result',@TextColumn=N'BatchText'
            , @CharactersColumn=N'BatchTextCharacters',@BytesColumn=N'BatchTextBytes'
            , @IsTruncatedColumn=N'BatchTextIsTruncated',@MaxCharacters=@MaxSqlTextZeichen
            , @TruncatedValueCount=@ColumnTruncatedCount OUTPUT,@LargestRequiredCharacters=@ColumnLargestCharacters OUTPUT;
        SELECT @TruncatedValueCount=@TruncatedValueCount+@ColumnTruncatedCount,
               @LargestRequiredCharacters=CASE WHEN @LargestRequiredCharacters IS NULL OR @ColumnLargestCharacters>@LargestRequiredCharacters THEN @ColumnLargestCharacters ELSE @LargestRequiredCharacters END;
        EXEC [monitor].[InternalEmitTruncationWarning]
              @TruncatedValueCount=@TruncatedValueCount,@ParameterName=N'@MaxSqlTextZeichen'
            , @ParameterValue=@MaxSqlTextZeichen,@LargestRequiredCharacters=@LargestRequiredCharacters
            , @PrintMeldungen=@PrintMeldungen;

        SELECT @RowCount = COUNT_BIG(*) FROM [#QueryStats_Result];
        SET @HasMoreRows = CONVERT(bit, CASE WHEN @Limit < 9223372036854775807 AND @RowCount > @Limit THEN 1 ELSE 0 END);
        ;WITH [Selection] AS
        (
            SELECT ROW_NUMBER() OVER (ORDER BY [SortValue] DESC, [LastExecutionTime] DESC) AS [SelectionOrdinal]
            FROM [#QueryStats_Result]
        )
        DELETE FROM [Selection] WHERE [SelectionOrdinal] > @Limit;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @IsPartial = 1;
        SET @StatusCode = CASE WHEN @ErrorNumber IN (229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                               WHEN @ErrorNumber = 1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
    END CATCH;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @Message = FORMATMESSAGE(N'WARNUNG USP_QueryStats [%s]: %s', @StatusCode, COALESCE(@ErrorMessage, N'Keine Details.'));
        RAISERROR(N'%s', 10, 1, @Message) WITH NOWAIT;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_QueryStats' AS [ModuleName]
            , @Now AS [CollectionTimeUtc]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , CASE WHEN @RowCount > @Limit THEN @Limit ELSE @RowCount END AS [ReturnedRowCount]
            , @HasMoreRows AS [HasMoreRows]
            , @CrossDatabaseRequested AS [CrossDatabaseRequested]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT TOP (@Limit)
                  [QueryHash], [QueryPlanHash], [PlanHandle], [SqlHandle]
                , [StatementStartOffset], [StatementEndOffset], [PlanGenerationNumber]
                , [DatabaseId], [DatabaseName], [ObjectId]
                , [StatementTextCharacters], [StatementTextBytes], [StatementTextIsTruncated], [StatementText]
                , [BatchTextCharacters], [BatchTextBytes], [BatchTextIsTruncated], [BatchText]
                , [CreationTime], [LastExecutionTime], [ExecutionCount]
                , [TotalCpuMs], [LastCpuMs], [MinCpuMs], [MaxCpuMs], [AvgCpuMs]
                , [TotalElapsedMs], [LastElapsedMs], [MinElapsedMs], [MaxElapsedMs], [AvgElapsedMs]
                , [TotalLogicalReads], [LastLogicalReads], [AvgLogicalReads]
                , [TotalLogicalWrites], [LastLogicalWrites], [AvgLogicalWrites]
                , [TotalPhysicalReads], [LastPhysicalReads]
                , [TotalRows], [LastRows], [MinRows], [MaxRows]
                , [LastDop], [MinDop], [MaxDop]
                , [MaxGrantKb], [LastGrantKb], [LastUsedGrantKb], [LastIdealGrantKb]
                , [TotalSpilledPages], [LastSpilledPages]
                , [CacheObjectType], [ObjectType], [PlanUseCounts], [PlanSizeBytes]
                , [ResourcePoolId], [SetOptions], [CompileUserId]
            FROM [#QueryStats_Result]
            ORDER BY [SortValue] DESC, [LastExecutionTime] DESC;
        END
        ELSE
        BEGIN
            SELECT TOP (@Limit)
                  N'Plan-Cache Statement' AS [Ergebnis]
                , [DatabaseName] AS [Datenbank]
                , [ExecutionCount] AS [Ausführungen]
                , CONCAT(CONVERT(varchar(30), [TotalCpuMs]), N' ms') AS [CPU gesamt]
                , CONCAT(CONVERT(varchar(30), [AvgCpuMs]), N' ms') AS [CPU je Ausführung]
                , CONCAT(CONVERT(varchar(30), [TotalElapsedMs]), N' ms') AS [Laufzeit gesamt]
                , CONCAT(CONVERT(varchar(30), [AvgElapsedMs]), N' ms') AS [Laufzeit je Ausführung]
                , [TotalLogicalReads] AS [Logical Reads gesamt]
                , [AvgLogicalReads] AS [Logical Reads je Ausführung]
                , CONCAT(CONVERT(varchar(30), [MaxGrantKb] / 1024.0), N' MB') AS [Maximaler Grant]
                , [TotalSpilledPages] AS [Spill-Seiten]
                , [LastExecutionTime] AS [Letzte Ausführung]
                , [DatabaseName] AS [Datenbank_SQL]
                , [StatementText] AS [Statement]
                , [BatchText] AS [Batch]
            FROM [#QueryStats_Result]
            ORDER BY [SortValue] DESC, [LastExecutionTime] DESC;
        END;

        SELECT [RequestedName], [StatusCode], [ErrorMessage]
        FROM [#QueryStats_DatabaseCandidateWarnings]
        ORDER BY [RequestedName];
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max) =
        (
            SELECT N'QueryStats' AS [resultName], 1 AS [schemaVersion], @Now AS [generatedAtUtc],
                   @StatusCode AS [statusCode], @MaxZeilen AS [requestedMaxRows],
                   CASE WHEN @RowCount > @Limit THEN @Limit ELSE @RowCount END AS [returnedRows],
                   @HasMoreRows AS [hasMoreRows], @Order AS [sortBy],
                   @ErrorNumber AS [errorNumber], @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @Data nvarchar(max) =
        (
            SELECT TOP (@Limit)
                  [QueryHash], [QueryPlanHash], [PlanHandle], [SqlHandle]
                , [StatementStartOffset], [StatementEndOffset], [PlanGenerationNumber]
                , [DatabaseId], [DatabaseName], [ObjectId]
                , [StatementTextCharacters], [StatementTextBytes], [StatementTextIsTruncated], [StatementText]
                , [BatchTextCharacters], [BatchTextBytes], [BatchTextIsTruncated], [BatchText]
                , [CreationTime], [LastExecutionTime], [ExecutionCount]
                , [TotalCpuMs], [LastCpuMs], [MinCpuMs], [MaxCpuMs], [AvgCpuMs]
                , [TotalElapsedMs], [LastElapsedMs], [MinElapsedMs], [MaxElapsedMs], [AvgElapsedMs]
                , [TotalLogicalReads], [LastLogicalReads], [AvgLogicalReads]
                , [TotalLogicalWrites], [LastLogicalWrites], [AvgLogicalWrites]
                , [TotalPhysicalReads], [LastPhysicalReads]
                , [TotalRows], [LastRows], [MinRows], [MaxRows]
                , [LastDop], [MinDop], [MaxDop]
                , [MaxGrantKb], [LastGrantKb], [LastUsedGrantKb], [LastIdealGrantKb]
                , [TotalSpilledPages], [LastSpilledPages]
                , [CacheObjectType], [ObjectType], [PlanUseCounts], [PlanSizeBytes]
                , [ResourcePoolId], [SetOptions], [CompileUserId]
            FROM [#QueryStats_Result]
            ORDER BY [SortValue] DESC, [LastExecutionTime] DESC
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        DECLARE @Warnings nvarchar(max) =
        (
            SELECT [RequestedName], [StatusCode], [ErrorMessage]
            FROM [#QueryStats_DatabaseCandidateWarnings]
            ORDER BY [RequestedName]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        SET @Json = CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"queries":',COALESCE(@Data,N'[]'),N',"warnings":',COALESCE(@Warnings,N'[]'),N'}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#QueryStats_Result'
            , @ResultLabel=N'QueryStats'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#QueryStats_Result'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
