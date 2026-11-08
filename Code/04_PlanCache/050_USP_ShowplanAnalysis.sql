USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ShowplanAnalysis
Version      : 2.2.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Selektiert begrenzt Plan-Cache-Kandidaten und verwendet je
               eindeutigem Planhandle die zentrale Execution-Plan-Analyse.
               Mehrere dm_exec_query_stats-Statements desselben Batchplans
               führen nicht mehr zu wiederholtem XML-Shredding.
SQL-Version  : SQL Server 2019 oder neuer.
Resultsets   : CONSOLE: findings. TABLE: parameters, DIAG-005-Kontext, findings.
               RAW: moduleStatus, planStatus, parameters, DIAG-005-Kontext, findings.
Berechtigung : VIEW SERVER STATE bzw. SQL Server 2022+
               VIEW SERVER PERFORMANCE STATE für Plan-Cache-Quellen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ShowplanAnalysis]
      @PlanHandle                    varbinary(64)   = NULL
    , @QueryHash                     binary(8)       = NULL
    , @QueryPlanHash                 binary(8)       = NULL
    , @DatabaseNames                 nvarchar(max)   = NULL
    , @SystemdatenbankenEinbeziehen  bit             = 0
    , @DatabaseNamePattern           nvarchar(4000)  = NULL
    , @HighImpactConfirmed           bit             = 0
    , @TextPattern                   nvarchar(4000)  = NULL
    , @AnalyseModus                  varchar(16)      = 'GEZIELT'
    , @PlanQuelle                    varchar(16)      = 'AUTO'
    , @Sortierung                    varchar(32)      = 'CPU_TOTAL'
    , @MinExecutionCount             bigint          = 1
    , @MaxAnalyseobjekte             int             = 20
    , @MaxDurationSeconds            int             = 30
    , @MaxZeilen                     int             = 50000
    , @ParentQueryStatsSnapshot      bit             = 0
    , @WorkloadProfil                varchar(32)      = 'AUTO'
    , @MinSchweregrad                varchar(16)      = 'INFO'
    , @MitThreadRuntime              bit             = 0
    , @MitSqlText                    bit             = 0
    , @StatistikEvidenzModus         varchar(16)      = 'PLAN_ONLY'
    , @HistogrammModus               varchar(16)      = 'NONE'
    , @MetadatenQuellenmodus         varchar(16)      = 'EVIDENCE_ONLY'
    , @QuellumgebungBestaetigt       bit             = 0
    , @EvidenzDatenschutzModus       varchar(24)      = 'DERIVED_ONLY'
    , @IdentifierDatenschutzModus    varchar(16)      = 'RAW'
    , @SensitiveDataConfirmed        bit             = 0
    , @MaxStatistiken                int             = 100
    , @MaxHistogrammSchritte         int             = 20000
    , @ResultSetArt                  varchar(16)      = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @JsonErzeugen                  bit             = 0
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json=NULL;

    DECLARE @Now datetime2(3)=SYSUTCDATETIME();
    DECLARE @Deadline datetime2(3)=DATEADD(SECOND,@MaxDurationSeconds,@Now);
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ConsoleResultRequested bit=CONVERT(bit,CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END);
    DECLARE @TableRequested bit=CONVERT(bit,CASE WHEN @OutputMode='TABLE' THEN 1 ELSE 0 END);
    DECLARE @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@AnalyseModus,'GEZIELT'))));
    DECLARE @Source varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@PlanQuelle,'AUTO'))));
    DECLARE @Order varchar(32)=UPPER(LTRIM(RTRIM(COALESCE(@Sortierung,'CPU_TOTAL'))));
    DECLARE @Limit bigint=CASE WHEN @MaxAnalyseobjekte IS NULL OR @MaxAnalyseobjekte=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxAnalyseobjekte END;
    DECLARE @ResultLimit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END;
    DECLARE @StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL;
    DECLARE @ProcessedPlans int=0,@CandidateCount int=0;
    DECLARE @CrossDatabaseRequested bit=0;
    DECLARE @ChildAnalyseTiefe varchar(16)=CASE WHEN @Mode='VOLL' THEN 'FULL' ELSE 'STANDARD' END;
    DECLARE @ChildMaxRows int=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 50000 WHEN @MaxZeilen>2147483647 THEN 2147483647 ELSE @MaxZeilen END;

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_ShowplanAnalysis';
        PRINT N'Die Procedure wählt eindeutige Planhandles aus und analysiert die verfügbaren Showplan-Dokumente mit USP_ExecutionPlanAnalysis. Planquelle, Kandidatenauswahl und Analysegrenzen werden getrennt gesteuert.';
        PRINT N'@PlanHandle varbinary(64). Default ist NULL. Exakter Planhandle. Nicht-NULL fügt den Handle direkt als Kandidat hinzu. NULL erlaubt Cacheauswahl per weiteren Selektoren oder VOLL.';
        PRINT N'@QueryHash binary(8). Default ist NULL. Exakter binärer 8-Byte-Queryhash für die Cacheauswahl. NULL lässt diesen Filter aus.';
        PRINT N'@QueryPlanHash binary(8). Default ist NULL. Exakter binärer 8-Byte-Plan-Hash für die Cacheauswahl. NULL lässt diesen Filter aus.';
        PRINT N'@DatabaseNames nvarchar(max). Default ist NULL. Pipe-Liste exakter Datenbanknamen. NULL, leer oder nur Leerzeichen = keine exakte Einschränkung. | trennt außerhalb von [...]. ]] maskiert ] innerhalb. Äußere Segmentleerzeichen entfernt. Elemente einteilige Namen bis 128 Zeichen. Ungültige Liste INVALID_PARAMETER.';
        PRINT N'@SystemdatenbankenEinbeziehen bit. Default ist 0. 0 schließt master, tempdb, model und msdb aus. 1 lässt sie zu. NULL führt zur Parameterablehnung. Ausgelassen = 0. SQL-bit-Konvertierung kann numerische Nichtnullwerte als 1 abbilden.';
        PRINT N'@DatabaseNamePattern nvarchar(4000). Default ist NULL. Ein LIKE-Pattern oder Präfix like:, regex:, regexi:. Erkennung ohne Beachtung der Großschreibung. Äußere Leerzeichen getrimmt, Musterrest nicht erneut. NULL = kein Pattern. Leerer Inhalt ungültig. Nicht mit wirksamer @DatabaseNames-Liste kombinierbar. Regex Flag c/i und Ausführung nur SQL Server 2025 + Compatibility Level 170 der Installationsdatenbank. Sonst UNAVAILABLE_FEATURE.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. 0 keine Bestätigung. 1 bestätigt angeforderte Policy-Gates für PLAN_CACHE_DEEP und/oder SHOWPLAN_XML_DEEP. Bestätigung hebt Filter und Limits nicht auf.';
        PRINT N'@TextPattern nvarchar(4000). Default ist NULL. SQL-Textpattern. NULL = kein Filter. Parser erkennt case-insensitive like:, regex:, regexi:, sonst LIKE. Außenleerzeichen getrimmt, Patternrest nicht. Leerer effektiver Inhalt INVALID_PARAMETER. Nicht als Pipe-Liste zerlegt. LIKE nutzt %/_/SQL LIKE-Syntax. Regex braucht SQL Server 2025 und Installations-DB-Kompatibilität 170, Syntaxfehler werden von Regex-Ausführung gemeldet.';
        PRINT N'@AnalyseModus varchar(16). Default ist ''GEZIELT''. GEZIELT erfordert einen Planhandle, einen der beiden Hashes, eine nichtleere Datenbankliste oder ein Datenbank- oder Textmuster. Die Listen und Muster werden anschließend separat geprüft. Der Modus verwendet die Child-Tiefe STANDARD. VOLL prüft PLAN_CACHE_DEEP und verwendet FULL. NULL entspricht GEZIELT. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte sind ungültig.';
        PRINT N'@PlanQuelle varchar(16). Default ist ''AUTO''. AUTO versucht den verfügbaren letzten Actual-Plan und fällt auf COMPILE zurück. COMPILE verwendet den kompilierten Cacheplan. LAST_ACTUAL fordert den letzten verfügbaren Actual-Plan ohne Aktivierung von Profiling an. NULL entspricht AUTO. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte sind ungültig.';
        PRINT N'@Sortierung varchar(32). Default ist ''CPU_TOTAL''. Trim/Upper, bestimmt Top-Kandidaten-Ranking. CPU_TOTAL=gesamte Workerzeit. ELAPSED_TOTAL=gesamte Laufzeit. READS_TOTAL=gesamte Reads. EXECUTIONS=Ausführungszahl. SPILLS_TOTAL=Spillmaß. GRANT_MAX=größtes Grant. LAST_EXECUTION=letzte Ausführung. Alle sieben erlaubten Codes, NULL fällt auf CPU_TOTAL zurück. Leer ungültig.';
        PRINT N'@MinExecutionCount bigint. Default ist 1. Ganzzahliges Minimum für die Ausführungszahl in der Cacheauswahl. 0 lässt auch Einträge mit 0 Ausführungen zu. Negative Werte ergeben INVALID_PARAMETER. Bei NULL trifft der Vergleich auf keine Cachezeile. Ein direkt angegebener Planhandle bleibt ein eigener Kandidatenpfad.';
        PRINT N'@MaxAnalyseobjekte int. Default ist 20. Positive Grenze der Kandidaten vor Planladen. 0/NULL unbegrenzt. Negativ ungültig. >20 oder unbegrenzt prüft PLAN_CACHE_DEEP, danach kann VOLL zusätzlich SHOWPLAN_XML_DEEP prüfen.';
        PRINT N'@MaxDurationSeconds int. Default ist 30. Ganzzahl von 1 bis 3600 Sekunden. Das Zeitbudget wird zwischen Kandidaten geprüft. Es unterbricht eine laufende XML-Analyse nicht. NULL ist ungültig und wird auf Wrapper-Ebene abgelehnt.';
        PRINT N'@MaxZeilen int. Default ist 50000. Positiv begrenzt Ergebniszeilen/Findingbudget. 0/NULL unbegrenzt (Childbudget wird intern auf 50000 gedeckelt). Negativ ungültig. Resultset-TOP und Candidate-Limit sind getrennte Grenzen.';
        PRINT N'@ParentQueryStatsSnapshot bit. Default ist 0. 0 liest Query Stats frisch. 1 verwendet den laufgebundenen Snapshot von USP_PlanCacheAnalysis. NULL aktiviert den Snapshot-Zweig nicht. Verwenden Sie 0 für eigenständige Aufrufe.';
        PRINT N'@WorkloadProfil varchar(32). Default ist ''AUTO''. Auswahl des aktiven Workloadprofils für Regeln und Schwellwerte. AUTO wählt innerhalb der Analyse aus der aktivierten Profilkonfiguration (monitor.PlanAnalysisProfile). Der konkrete gültige Profilcode ist damit installations-/konfigurationsabhängig, keine im Wrapper geschlossene Liste. Profilcodes werden im Child auf Großschreibung normalisiert. Unbekannter/deaktivierter Code fällt intern kontrolliert auf BALANCED zurück. NULL wird vom Child auf AUTO normalisiert. Leerwert führt zum unbekannten Profil und Fallback BALANCED.';
        PRINT N'@MinSchweregrad varchar(16). Default ist ''INFO''. Mindestschweregrad für Findings. Geschlossene Menge INFO, LOW, MEDIUM, HIGH, CRITICAL. Stufen sind aufsteigende Mindestschwellen, INFO lässt die niedrigste Stufe zu, CRITICAL nur höchste Schwere. NULL wird auf INFO normalisiert. Leertext ist ungültig.';
        PRINT N'@MitThreadRuntime bit. Default ist 0. 0 unterdrückt Thread-Runtime-Evidenz. 1 fordert sie an. Verwenden Sie 0 oder 1 als eindeutigen Schalter. Für Threaddaten können Quellverfügbarkeit und Planumfang Grenzen setzen.';
        PRINT N'@MitSqlText bit. Default ist 0. 0 unterdrückt SQL-Text. 1 fordert Statementtext an und benötigt zusätzlich SensitiveDataConfirmed=1, da Literale/proprietärer Text enthalten sein können. Verwenden Sie 0 oder 1 als eindeutigen Schalter.';
        PRINT N'@StatistikEvidenzModus varchar(16). Default ist ''PLAN_ONLY''. Geschlossene Menge: NONE=keine Statistik-Evidenz. PLAN_ONLY=nur Statistikhinweise aus Plan-XML. USED=Statistiken, die der Plan als benutzt ausweist. RELEVANT=erweiterte relevante Statistiken samt tieferer Evidence. OBJECT_ALL=alle Statistiken der referenzierten Objekte. NULL normalisiert zu PLAN_ONLY. Leertext ungültig. RELEVANT und OBJECT_ALL lösen tiefere Statistik-/Katalogpfade aus.';
        PRINT N'@HistogrammModus varchar(16). Default ist ''NONE''. Geschlossene Menge: NONE=kein Histogramm. SUMMARY=Zusammenfassung. STEPS=Schrittwerte des Histogramms. NULL wird zu NONE normalisiert. Leertext ungültig. STEPS gehört zum tiefen Pfad. MaxHistogrammSchritte begrenzt die gelieferten Schritte.';
        PRINT N'@MetadatenQuellenmodus varchar(16). Default ist ''EVIDENCE_ONLY''. Geschlossene Menge: EVIDENCE_ONLY verwendet im Plan/Evidence vorhandene Metadaten. CURRENT_SERVER reichert aus dem aktuellen Serverkatalog an. NULL wird zu EVIDENCE_ONLY normalisiert. Leertext ungültig. CURRENT_SERVER erfordert QuellumgebungBestaetigt=1, damit die aktuelle Umgebung ausdrücklich als Datenquelle bestätigt ist.';
        PRINT N'@QuellumgebungBestaetigt bit. Default ist 0. 0 keine Bestätigung. 1 bestätigt, dass CURRENT_SERVER-Katalogmetadaten der Quellumgebung zugeordnet werden dürfen. Nur 0/1. NULL ungültig. CURRENT_SERVER ohne 1 wird abgelehnt.';
        PRINT N'@EvidenzDatenschutzModus varchar(24). Default ist ''DERIVED_ONLY''. Geschlossene Menge: DERIVED_ONLY gibt abgeleitete Evidenz ohne rohe Parameter-/Histogrammwerte aus. TOKENIZED ersetzt sensible Werte durch Token. STRUCTURE_ONLY gibt Struktur/Metadaten ohne Werte aus. RAW gibt rohe Parameter- und Histogrammwerte aus. NULL wird zu DERIVED_ONLY normalisiert. Leertext ungültig. RAW erfordert SensitiveDataConfirmed=1.';
        PRINT N'@IdentifierDatenschutzModus varchar(16). Default ist ''RAW''. Geschlossene Menge: RAW gibt Objekt-/Statistikidentifikatoren im Original aus. TOKENIZED ersetzt sie durch Token. OMIT lässt Identifikatoren weg. NULL wird zu RAW normalisiert. Leertext ungültig.';
        PRINT N'@SensitiveDataConfirmed bit. Default ist 0. 0 keine Freigabebestätigung. 1 bestätigt die bewusste Verarbeitung potentiell sensibler Rohwerte. Verwenden Sie 0 oder 1 als eindeutigen Schalter. Erforderlich bei EvidenzDatenschutzModus=RAW oder MitSqlText=1. Kein allgemeiner Gate-Bypass.';
        PRINT N'@MaxStatistiken int. Default ist 100. Anzahlbegrenzung der gelesenen Statistikobjekte, Bereich 1..1000. 0 und NULL ungültig. Bei tiefer Statistik-Evidenz begrenzt diese Zahl die Katalogarbeit.';
        PRINT N'@MaxHistogrammSchritte int. Default ist 20000. Maximal gelesene Histogrammschritte, Bereich 0..200000. 0 erlaubt keine Schritte (Zusammenfassung bleibt möglich), NULL ungültig.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. Trim/Upper. CONSOLE lesbare Resultsets, RAW kanonische Detailresultsets, TABLE schreibt die typisierten Resultsets in Zieltabellen, NONE unterdrückt direkte Resultsets. Erlaubt genau CONSOLE, RAW, TABLE, NONE. NULL wird leer und ungültig, Leerwert ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakt geschriebenen Schlüssel parameters, planWarnings, optimizerContext, runtimeFeedback, queryStoreContext, feedbackAndVariants und findings. Jeder Wert muss als Zeichenfolge eine andere vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte benennen. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE ist ausschließlich NULL erlaubt. Auch eine leere Zeichenfolge ist ungültig. Die Zuordnung wird nach dem Hilfe-Return und vor den Quellzugriffen geprüft. Ein ungültiges Mapping kann Fehler 51011 auslösen.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 oder NULL erzeugt kein Dokument.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT nvarchar(max), wird beim Eintritt auf NULL gesetzt und bei JsonErzeugen=1 mit Objekt meta, planStatus und den sieben Fachergebnisarrays sowie analyses befüllt. Caller muss gleich typisierten Variable OUTPUT binden.';
        PRINT N'@PrintMeldungen bit. Default ist 1. 1 PRINT-Meldungen aktiv. 0 unterdrückt. NULL nicht als aktiv darstellen.';
        PRINT N'@Hilfe bit. Default ist 0. 1 zeigt die Hilfe und beendet den Aufruf vor Validierung, TABLE-Zuordnungsprüfung und fachlicher Analyse. 0 und NULL führen die Analyse aus.';
        PRINT N'Hilfe anzeigen. EXEC [monitor].[USP_ShowplanAnalysis] @Hilfe=1;';
        PRINT N'Technische Resultsets lesen. EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @AnalyseModus=''GEZIELT'', @PlanQuelle=''COMPILE'', @MaxAnalyseobjekte=5, @MaxDurationSeconds=10, @MaxZeilen=1000, @ResultSetArt=''RAW'';';
        PRINT N'Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @JsonErzeugen=1, @ResultSetArt=''NONE'', @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'Ein Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #ShowplanAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"findings":"#ShowplanAnalysis_HelpExample"}''; SELECT * FROM #ShowplanAnalysis_HelpExample; DROP TABLE #ShowplanAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #ShowplanAnalysis_HelpExample; THROW; END CATCH;';
        RETURN;
    END;

    CREATE TABLE [#ShowplanAnalysis_TableMap]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#ShowplanAnalysis_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL
    );
    CREATE TABLE [#ShowplanAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ShowplanAnalysis_Candidates]
    (
          [CandidateId] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [PlanHandle] varbinary(64) NOT NULL UNIQUE
        , [ExecutionCount] bigint NULL,[TotalWorkerTime] bigint NULL,[TotalElapsedTime] bigint NULL
        , [TotalLogicalReads] bigint NULL,[TotalSpills] bigint NULL,[MaxGrantKb] bigint NULL
        , [LastExecutionTime] datetime NULL
        , [DatabaseId] int NULL,[SetOptions] bigint NULL,[CompileUserId] int NULL
        , [PlanGenerationNum] bigint NULL,[CacheCreationTime] datetime NULL,[CacheLastExecutionTime] datetime NULL
        , [CacheObjectType] nvarchar(34) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CacheObjectClass] nvarchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CacheUseCounts] int NULL,[CacheRefCounts] int NULL,[CacheSizeBytes] bigint NULL,[CachePoolId] int NULL
    );
    CREATE TABLE [#ShowplanAnalysis_ExecutionPlanSourceContext]
    (
          [PlanHandle] varbinary(64) NOT NULL
        , [SourceCapturedAtUtc] datetime2(3) NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [DatabaseId] int NULL,[SetOptions] bigint NULL,[CompileUserId] int NULL
        , [PlanGenerationNum] bigint NULL,[CacheCreationTime] datetime NULL,[CacheLastExecutionTime] datetime NULL
        , [ExecutionCount] bigint NULL,[CacheObjectType] nvarchar(34) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CacheObjectClass] nvarchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CacheUseCounts] int NULL,[CacheRefCounts] int NULL,[CacheSizeBytes] bigint NULL,[CachePoolId] int NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , PRIMARY KEY ([PlanHandle])
    );
    CREATE TABLE [#ShowplanAnalysis_PlanStatus]
    (
          [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL,[PlanSource] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RuntimeCounterScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FindingCount] int NOT NULL,[ParseDurationMs] bigint NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ShowplanAnalysis_Findings]
    (
          [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[FindingOrdinal] bigint NOT NULL
        , [FindingCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Category] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Confidence] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceLevel] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatementOrdinal] int NULL,[StatementId] int NULL,[NodeId] int NULL
        , [PhysicalOp] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[LogicalOp] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricValue] decimal(38,4) NULL,[MetricUnit] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ThresholdValue] decimal(38,4) NULL,[ThresholdSource] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WorkloadProfile] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Summary] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Evidence] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceLimit] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterEvidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ShowplanAnalysis_Parameters]
    (
          [CandidateId] int NOT NULL
        , [PlanHandle] varbinary(64) NOT NULL
        , [SessionId] smallint NULL
        , [RequestId] int NULL
        , [StatementOrdinal] int NULL
        , [StatementId] int NULL
        , [StatementQueryHash] nvarchar(130) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatementQueryPlanHash] nvarchar(130) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [QueryStorePlanId] bigint NULL
        , [PlanDocumentHash] nvarchar(66) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceKind] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ParameterName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ParameterDataType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CompiledValuePresent] bit NOT NULL
        , [RuntimeValuePresent] bit NOT NULL
        , [CompiledValueIsSqlNull] bit NULL
        , [RuntimeValueIsSqlNull] bit NULL
        , [CompiledValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RuntimeValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CompiledValueToken] nvarchar(66) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RuntimeValueToken] nvarchar(66) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CompiledValueLength] int NULL
        , [RuntimeValueLength] int NULL
        , [CompiledValueStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RuntimeValueStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ValueStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ValueHandlingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ValueSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL
        , [ValueCapturedAtUtc] datetime2(3) NULL
        , [IsCurrentExecution] bit NULL
        , [IsLastKnownExecution] bit NULL
        , [IsComplete] bit NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ShowplanAnalysis_PlanWarnings]
    (
          [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[WarningOrdinal] bigint NOT NULL
        , [AnalysisObjectId] int NOT NULL,[StatementOrdinal] int NULL,[StatementId] int NULL,[NodeId] int NULL
        , [WarningCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WarningCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PlanSource] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL,[IsCurrent] bit NULL,[IsLastKnown] bit NULL
        , [IsMeasured] bit NOT NULL,[IsInferred] bit NOT NULL,[MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MetricValue] decimal(38,4) NULL,[MetricUnit] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FalsePositiveGuard] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ShowplanAnalysis_OptimizerContext]
    (
          [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[AnalysisObjectId] int NOT NULL
        , [StatementOrdinal] int NULL,[StatementId] int NULL,[PlanSource] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RuntimeCounterScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceObservedAtUtc] datetime2(3) NOT NULL
        , [IsCurrent] bit NULL,[IsLastKnown] bit NULL,[OptimizationLevel] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EarlyAbortReason] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CardinalityEstimationModelVersion] int NULL
        , [StatementSubTreeCost] decimal(38,8) NULL,[StatementEstimatedRows] decimal(38,4) NULL
        , [CompileTimeMs] bigint NULL,[CompileCpuMs] bigint NULL,[CompileMemoryKb] bigint NULL
        , [RetrievedFromCache] bit NULL,[NonParallelPlanReason] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PlanDegreeOfParallelism] int NULL
        , [PlanGenerationNum] bigint NULL,[CacheCreationTime] datetime NULL,[CacheLastExecutionTime] datetime NULL
        , [CacheExecutionCount] bigint NULL,[CacheObjectType] nvarchar(34) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CacheObjectClass] nvarchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CacheUseCounts] int NULL,[CacheRefCounts] int NULL,[CacheSizeBytes] bigint NULL,[CachePoolId] int NULL
        , [SetOptions] bigint NULL,[CompileUserId] int NULL,[DatabaseId] int NULL
        , [EvidenceMeasurement] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [FalsePositiveGuard] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ShowplanAnalysis_RuntimeFeedback]
    (
          [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[FeedbackOrdinal] bigint NOT NULL
        , [AnalysisObjectId] int NOT NULL,[StatementOrdinal] int NULL,[StatementId] int NULL,[NodeId] int NULL
        , [FeedbackType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FeedbackState] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricName] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObservedValue] decimal(38,4) NULL,[BaselineValue] decimal(38,4) NULL,[DeltaRatio] decimal(38,8) NULL
        , [MetricUnit] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RuntimeCounterScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[EvidenceSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL,[IsCurrent] bit NULL,[IsLastKnown] bit NULL
        , [IsMeasured] bit NOT NULL,[IsDerived] bit NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ShowplanAnalysis_QueryStoreContext]
    (
          [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[AnalysisObjectId] int NOT NULL
        , [QueryStoreDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[QueryStorePlanId] bigint NULL,[QueryStoreQueryId] bigint NULL
        , [PlanGroupId] bigint NULL,[EngineVersion] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CompatibilityLevel] smallint NULL
        , [QueryPlanHash] binary(8) NULL,[IsTrivialPlan] bit NULL,[IsParallelPlan] bit NULL,[IsForcedPlan] bit NULL
        , [PlanForcingTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ForceFailureCount] bigint NULL
        , [LastForceFailureReason] int NULL,[LastForceFailureReasonDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CountCompiles] bigint NULL,[InitialCompileStartTime] datetimeoffset(7) NULL
        , [LastCompileStartTime] datetimeoffset(7) NULL,[LastExecutionTime] datetimeoffset(7) NULL
        , [AvgCompileDurationUs] float NULL,[LastCompileDurationUs] bigint NULL,[ContextSettingsId] bigint NULL
        , [ObjectId] bigint NULL,[QueryHash] binary(8) NULL,[QueryParameterizationTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AvgOptimizeDurationUs] float NULL,[AvgCompileMemoryKb] float NULL,[HasCompileReplayScript] bit NULL
        , [IsOptimizedPlanForcingDisabled] bit NULL,[PlanType] int NULL,[PlanTypeDesc] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RuntimeExecutionCount] bigint NULL,[RuntimeLastExecutionTime] datetimeoffset(7) NULL
        , [AvgDurationUs] decimal(38,4) NULL,[AvgCpuTimeUs] decimal(38,4) NULL
        , [AvgLogicalIoReads] decimal(38,4) NULL,[AvgLogicalIoWrites] decimal(38,4) NULL
        , [QueryHintCount] int NOT NULL,[QueryHintFailureCount] bigint NOT NULL
        , [PersistedFeedbackCount] int NOT NULL,[VariantRelationCount] int NOT NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL,[IsCurrent] bit NOT NULL,[IsLastKnown] bit NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ShowplanAnalysis_FeedbackAndVariants]
    (
          [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[RecordOrdinal] bigint NOT NULL
        , [AnalysisObjectId] int NOT NULL,[RecordType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FeatureType] varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatementOrdinal] int NULL,[StatementId] int NULL,[NodeId] int NULL
        , [QueryStorePlanId] bigint NULL,[QueryStoreQueryId] bigint NULL,[ParentQueryId] bigint NULL
        , [DispatcherPlanId] bigint NULL,[QueryVariantQueryId] bigint NULL,[QueryVariantId] int NULL
        , [FeatureState] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FeatureData] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FeatureDataToken] varbinary(32) NULL
        , [FeatureDataLength] int NULL,[DataHandlingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceObservedAtUtc] datetime2(3) NOT NULL,[IsCurrent] bit NULL,[IsLastKnown] bit NULL
        , [IsMeasured] bit NOT NULL,[IsDerived] bit NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ShowplanAnalysis_Analyses]
    (
          [CandidateId] int NOT NULL PRIMARY KEY
        , [AnalysisJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ShowplanAnalysis_ModuleStatus]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CollectionTimeUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL,[CandidateCount] int NOT NULL,[ProcessedPlanCount] int NOT NULL
        , [FindingCount] bigint NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @Mode NOT IN ('GEZIELT','VOLL') OR @Source NOT IN ('AUTO','COMPILE','LAST_ACTUAL')
       OR @Order NOT IN ('CPU_TOTAL','ELAPSED_TOTAL','READS_TOTAL','EXECUTIONS','SPILLS_TOTAL','GRANT_MAX','LAST_EXECUTION')
       OR @MaxAnalyseobjekte<0 OR @MaxZeilen<0 OR @MinExecutionCount<0
       OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 3600 OR @ParentQueryStatsSnapshot NOT IN (0,1)
       OR @JsonErzeugen NOT IN (0,1)
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'Ungültiger Modus-, Grenzwert-, Quell- oder Ausgabeparameter.';
    END;
    IF @StatusCode='AVAILABLE' AND @Mode='GEZIELT' AND @PlanHandle IS NULL AND @QueryHash IS NULL AND @QueryPlanHash IS NULL
       AND NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NULL
       AND @DatabaseNamePattern IS NULL AND @TextPattern IS NULL
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'GEZIELT benötigt mindestens einen Selektor.';
    END;

    IF @StatusCode='AVAILABLE' AND @TableRequested=1
    BEGIN
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson=@ResultTablesJson
            , @AllowedResultNames=N'parameters|planWarnings|optimizerContext|runtimeFeedback|queryStoreContext|feedbackAndVariants|findings'
            , @MappingTable=N'#ShowplanAnalysis_TableMap'
            , @ThrowOnError=1;
        SET @OutputMode='NONE';
    END
    ELSE IF @StatusCode='AVAILABLE' AND @ResultTablesJson IS NOT NULL
    BEGIN
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@ResultTablesJson ist ausschließlich mit TABLE zulässig.';
    END;
    IF @ConsoleResultRequested=1 SET @OutputMode='NONE';

    DECLARE @TextMode varchar(8),@TextValue nvarchar(4000),@TextFlags varchar(8),@TextValid bit;
    SELECT @TextMode=[PatternMode],@TextValue=[PatternValue],@TextFlags=[RegexFlags],@TextValid=[IsValid]
    FROM [monitor].[TVF_ParsePattern](@TextPattern);
    IF @StatusCode='AVAILABLE' AND @TextValid=0
        SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@TextPattern ist ungültig.';
    IF @StatusCode='AVAILABLE' AND @TextMode IN ('REGEX','REGEXI')
       AND (TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<17
            OR NOT EXISTS(SELECT 1 FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID() AND [compatibility_level]>=170))
        SELECT @StatusCode='UNAVAILABLE_FEATURE',@IsPartial=1,@ErrorMessage=N'Regex benötigt SQL Server 2025 und Compatibility Level 170.';

    IF @StatusCode='AVAILABLE' AND @PlanHandle IS NULL
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames=@DatabaseNames
            , @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern=@DatabaseNamePattern
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @AnalysisClass='PLAN_CACHE_CURRENT'
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT
            , @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT
            , @CandidateTable=N'#ShowplanAnalysis_DatabaseCandidates'
            , @WarningTable=N'#ShowplanAnalysis_DatabaseCandidateWarnings';
    END;

    IF @StatusCode='AVAILABLE' AND (@Mode='VOLL' OR @Limit>20)
    BEGIN
        EXEC [monitor].[InternalCheckAnalysisPath]
              @AnalysisClass='PLAN_CACHE_DEEP',@HighImpactConfirmed=@HighImpactConfirmed
            , @StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT;
        IF @StatusCode='AVAILABLE'
            EXEC [monitor].[InternalCheckAnalysisPath]
                  @AnalysisClass='SHOWPLAN_XML_DEEP',@HighImpactConfirmed=@HighImpactConfirmed
                , @StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT;
    END;

    IF @StatusCode='AVAILABLE'
    BEGIN TRY
        IF @PlanHandle IS NOT NULL
            INSERT [#ShowplanAnalysis_Candidates]([PlanHandle]) VALUES(@PlanHandle);
        ELSE
        BEGIN
            DECLARE @OrderExpression nvarchar(300)=CASE @Order
                WHEN 'CPU_TOTAL' THEN N'[qs].[TotalWorkerTime]'
                WHEN 'ELAPSED_TOTAL' THEN N'[qs].[TotalElapsedTime]'
                WHEN 'READS_TOTAL' THEN N'[qs].[TotalLogicalReads]'
                WHEN 'EXECUTIONS' THEN N'[qs].[ExecutionCount]'
                WHEN 'SPILLS_TOTAL' THEN N'[qs].[TotalSpills]'
                WHEN 'GRANT_MAX' THEN N'[qs].[MaxGrantKb]'
                WHEN 'LAST_EXECUTION' THEN N'DATEDIFF_BIG(MILLISECOND,''20000101'',[qs].[LastExecutionTime])' END;
            DECLARE @Sql nvarchar(max)=N'
;WITH [FilteredQueryStats] AS
(
    SELECT [qs].*
    FROM '+CASE WHEN @ParentQueryStatsSnapshot=1 THEN N'[#PlanCacheAnalysis_QueryStatsSnapshot]' ELSE N'[sys].[dm_exec_query_stats]' END+N' AS [qs] WITH (NOLOCK) '
                +CASE WHEN @TextMode IS NOT NULL THEN N'OUTER APPLY [sys].[dm_exec_sql_text]([qs].[sql_handle]) AS [st] ' ELSE N'' END+N'
    WHERE [qs].[execution_count]>=@MinExec
      AND (@QH IS NULL OR [qs].[query_hash]=@QH)
      AND (@QPH IS NULL OR [qs].[query_plan_hash]=@QPH) '
                +CASE WHEN @TextMode='LIKE' THEN N'AND [st].[text] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @TextValue COLLATE SQL_Latin1_General_CP1_CS_AS '
                      WHEN @TextMode IN ('REGEX','REGEXI') THEN N'AND REGEXP_LIKE([st].[text],@TextValue,@TextFlags) ' ELSE N'' END+N'
),
[QueryStatsByPlan] AS
(
    SELECT
          [plan_handle]
        , [ExecutionCount]=SUM([execution_count])
        , [TotalWorkerTime]=SUM([total_worker_time])
        , [TotalElapsedTime]=SUM([total_elapsed_time])
        , [TotalLogicalReads]=SUM([total_logical_reads])
        , [TotalSpills]=SUM([total_spills])
        , [MaxGrantKb]=MAX([max_grant_kb])
        , [LastExecutionTime]=MAX([last_execution_time])
        , [PlanGenerationNum]=MAX([plan_generation_num])
        , [CacheCreationTime]=MIN([creation_time])
    FROM [FilteredQueryStats]
    GROUP BY [plan_handle]
)
INSERT [#ShowplanAnalysis_Candidates]
(
      [PlanHandle],[ExecutionCount],[TotalWorkerTime],[TotalElapsedTime],[TotalLogicalReads]
    , [TotalSpills],[MaxGrantKb],[LastExecutionTime]
    , [DatabaseId],[SetOptions],[CompileUserId],[PlanGenerationNum]
    , [CacheCreationTime],[CacheLastExecutionTime],[CacheObjectType],[CacheObjectClass]
    , [CacheUseCounts],[CacheRefCounts],[CacheSizeBytes],[CachePoolId]
)
SELECT TOP (@TopRows)
      [qs].[plan_handle],[qs].[ExecutionCount],[qs].[TotalWorkerTime]
    , [qs].[TotalElapsedTime],[qs].[TotalLogicalReads],[qs].[TotalSpills]
    , [qs].[MaxGrantKb],[qs].[LastExecutionTime]
    , [pa].[DatabaseId],[pa].[SetOptions],[pa].[CompileUserId]
    , [qs].[PlanGenerationNum],[qs].[CacheCreationTime],[qs].[LastExecutionTime]
    , [cp].[cacheobjtype],[cp].[objtype],[cp].[usecounts],[cp].[refcounts]
    , CONVERT(bigint,[cp].[size_in_bytes]),[cp].[pool_id]
FROM [QueryStatsByPlan] AS [qs]
LEFT JOIN [sys].[dm_exec_cached_plans] AS [cp] WITH (NOLOCK)
  ON [cp].[plan_handle]=[qs].[plan_handle]
OUTER APPLY
(
    SELECT
          MAX(CASE WHEN [attribute]=''dbid'' THEN TRY_CONVERT(int,[value]) END) [DatabaseId]
        , MAX(CASE WHEN [attribute]=''set_options'' THEN TRY_CONVERT(bigint,[value]) END) [SetOptions]
        , MAX(CASE WHEN [attribute]=''user_id'' THEN TRY_CONVERT(int,[value]) END) [CompileUserId]
    FROM [sys].[dm_exec_plan_attributes]([qs].[plan_handle])
) AS [pa]
WHERE EXISTS
(
    SELECT 1
    FROM [#ShowplanAnalysis_DatabaseCandidates] AS [dc]
    WHERE [dc].[DatabaseId]=[pa].[DatabaseId]
)
ORDER BY '+@OrderExpression+N' DESC,[qs].[LastExecutionTime] DESC
OPTION (RECOMPILE,MAXDOP 1);';
            EXEC [sys].[sp_executesql]
                  @Sql
                , N'@TopRows bigint,@MinExec bigint,@QH binary(8),@QPH binary(8),@TextValue nvarchar(4000),@TextFlags varchar(8)'
                , @TopRows=@Limit,@MinExec=@MinExecutionCount,@QH=@QueryHash,@QPH=@QueryPlanHash
                , @TextValue=@TextValue,@TextFlags=@TextFlags;
        END;
        SELECT @CandidateCount=COUNT(*) FROM [#ShowplanAnalysis_Candidates];

        IF @PlanHandle IS NOT NULL
        BEGIN
            BEGIN TRY
                UPDATE [c]
                SET
                      [DatabaseId]=[a].[DatabaseId],[SetOptions]=[a].[SetOptions],[CompileUserId]=[a].[CompileUserId]
                    , [PlanGenerationNum]=[q].[PlanGenerationNum],[CacheCreationTime]=[q].[CacheCreationTime]
                    , [CacheLastExecutionTime]=[q].[CacheLastExecutionTime],[ExecutionCount]=[q].[ExecutionCount]
                    , [CacheObjectType]=[cp].[cacheobjtype],[CacheObjectClass]=[cp].[objtype]
                    , [CacheUseCounts]=[cp].[usecounts],[CacheRefCounts]=[cp].[refcounts]
                    , [CacheSizeBytes]=CONVERT(bigint,[cp].[size_in_bytes]),[CachePoolId]=[cp].[pool_id]
                FROM [#ShowplanAnalysis_Candidates] AS [c]
                LEFT JOIN [sys].[dm_exec_cached_plans] AS [cp] WITH (NOLOCK)
                  ON [cp].[plan_handle]=[c].[PlanHandle]
                OUTER APPLY
                (
                    SELECT
                          MAX([qs].[plan_generation_num]) [PlanGenerationNum]
                        , MIN([qs].[creation_time]) [CacheCreationTime]
                        , MAX([qs].[last_execution_time]) [CacheLastExecutionTime]
                        , SUM([qs].[execution_count]) [ExecutionCount]
                    FROM [sys].[dm_exec_query_stats] AS [qs] WITH (NOLOCK)
                    WHERE [qs].[plan_handle]=[c].[PlanHandle]
                ) AS [q]
                OUTER APPLY
                (
                    SELECT
                          MAX(CASE WHEN [attribute]='dbid' THEN TRY_CONVERT(int,[value]) END) [DatabaseId]
                        , MAX(CASE WHEN [attribute]='set_options' THEN TRY_CONVERT(bigint,[value]) END) [SetOptions]
                        , MAX(CASE WHEN [attribute]='user_id' THEN TRY_CONVERT(int,[value]) END) [CompileUserId]
                    FROM [sys].[dm_exec_plan_attributes]([c].[PlanHandle])
                ) AS [a];
            END TRY
            BEGIN CATCH
                /* Fehler 569 ist der erwartbare Race-Zustand eines inzwischen
                   ungültigen Planhandles. Der Child-Analyzer klassifiziert
                   den Plan selbst weiterhin als PLAN_EVICTED. */
                IF ERROR_NUMBER()<>569
                    THROW;
            END CATCH;
        END;

        INSERT [#ShowplanAnalysis_ExecutionPlanSourceContext]
        (
              [PlanHandle],[SourceCapturedAtUtc],[StatusCode],[DatabaseId],[SetOptions],[CompileUserId]
            , [PlanGenerationNum],[CacheCreationTime],[CacheLastExecutionTime],[ExecutionCount]
            , [CacheObjectType],[CacheObjectClass],[CacheUseCounts],[CacheRefCounts]
            , [CacheSizeBytes],[CachePoolId],[EvidenceLimit]
        )
        SELECT
              [PlanHandle],@Now
            , CASE WHEN [CacheObjectType] IS NULL THEN 'PLAN_CACHE_CONTEXT_UNAVAILABLE' ELSE 'AVAILABLE' END
            , [DatabaseId],[SetOptions],[CompileUserId],[PlanGenerationNum],[CacheCreationTime]
            , [CacheLastExecutionTime],[ExecutionCount],[CacheObjectType],[CacheObjectClass]
            , [CacheUseCounts],[CacheRefCounts],[CacheSizeBytes],[CachePoolId]
            , N'Der Cachekontext stammt aus demselben begrenzten Kandidatensnapshot; er ist flüchtig und nicht transaktional mit dem Plan-XML atomar.'
        FROM [#ShowplanAnalysis_Candidates];
    END TRY
    BEGIN CATCH
        SELECT @StatusCode=CASE WHEN ERROR_NUMBER() IN (229,371,262,297,300,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE();
    END CATCH;

    DECLARE @CandidateId int,@CurrentPlanHandle varbinary(64),@ChildJson nvarchar(max),@ChildStatus varchar(40),@ChildPartial bit,@ChildError int,@ChildMessage nvarchar(2048),@Started datetime2(3);
    DECLARE [PlanCursor] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [CandidateId],[PlanHandle] FROM [#ShowplanAnalysis_Candidates] ORDER BY [CandidateId];
    IF @StatusCode='AVAILABLE'
    BEGIN
        OPEN [PlanCursor];
        FETCH NEXT FROM [PlanCursor] INTO @CandidateId,@CurrentPlanHandle;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF SYSUTCDATETIME()>=@Deadline
            BEGIN
                SELECT @StatusCode='PARTIAL',@IsPartial=1,@ErrorMessage=N'Das Zeitbudget wurde erreicht; weitere Pläne wurden nicht analysiert.';
                BREAK;
            END;
            SELECT @Started=SYSUTCDATETIME(),@ChildJson=NULL,@ChildStatus=NULL,@ChildPartial=NULL,@ChildError=NULL,@ChildMessage=NULL;
            BEGIN TRY
                EXEC [monitor].[USP_ExecutionPlanAnalysis]
                      @PlanHandle=@CurrentPlanHandle
                    , @PlanQuelle=@Source
                    , @StatementQueryHash=@QueryHash
                    , @StatementQueryPlanHash=@QueryPlanHash
                    , @AnalyseTiefe=@ChildAnalyseTiefe
                    , @WorkloadProfil=@WorkloadProfil
                    , @MinSchweregrad=@MinSchweregrad
                    , @MitThreadRuntime=@MitThreadRuntime
                    , @MitSqlText=@MitSqlText
                    , @StatistikEvidenzModus=@StatistikEvidenzModus
                    , @HistogrammModus=@HistogrammModus
                    , @MetadatenQuellenmodus=@MetadatenQuellenmodus
                    , @QuellumgebungBestaetigt=@QuellumgebungBestaetigt
                    , @EvidenzDatenschutzModus=@EvidenzDatenschutzModus
                    , @IdentifierDatenschutzModus=@IdentifierDatenschutzModus
                    , @SensitiveDataConfirmed=@SensitiveDataConfirmed
                    , @MaxOperatoren=@ChildMaxRows
                    , @MaxFindings=@ChildMaxRows
                    , @MaxStatistiken=@MaxStatistiken
                    , @MaxHistogrammSchritte=@MaxHistogrammSchritte
                    , @MaxDurationSeconds=@MaxDurationSeconds
                    , @HighImpactConfirmed=@HighImpactConfirmed
                    , @ResultSetArt='NONE'
                    , @JsonErzeugen=1
                    , @Json=@ChildJson OUTPUT
                    , @PrintMeldungen=0
                    , @StatusCodeOut=@ChildStatus OUTPUT
                    , @IsPartialOut=@ChildPartial OUTPUT
                    , @ErrorNumberOut=@ChildError OUTPUT
                    , @ErrorMessageOut=@ChildMessage OUTPUT;

                DECLARE @ChildPlanSource varchar(24)=NULL,@ChildRuntimeScope varchar(32)=NULL,@ChildFindingCount int=0;
                IF ISJSON(@ChildJson)=1
                BEGIN
                    SELECT
                          @ChildPlanSource=JSON_VALUE(@ChildJson,N'$.meta.planSource')
                        , @ChildRuntimeScope=JSON_VALUE(@ChildJson,N'$.meta.runtimeCounterScope')
                        , @ChildFindingCount=(SELECT COUNT(*) FROM OPENJSON(@ChildJson,N'$.findings'));
                END;

                INSERT [#ShowplanAnalysis_PlanStatus]
                SELECT @CandidateId,@CurrentPlanHandle,COALESCE(@ChildStatus,'STATUS_UNAVAILABLE'),COALESCE(@ChildPartial,1),
                       @ChildPlanSource,@ChildRuntimeScope,@ChildFindingCount,
                       DATEDIFF_BIG(MILLISECOND,@Started,SYSUTCDATETIME()),@ChildError,@ChildMessage;
                INSERT [#ShowplanAnalysis_Analyses] VALUES(@CandidateId,CASE WHEN ISJSON(@ChildJson)=1 THEN @ChildJson END);

                IF ISJSON(@ChildJson)=1
                BEGIN
                    INSERT [#ShowplanAnalysis_Findings]
                    (
                          [CandidateId],[PlanHandle],[FindingOrdinal],[FindingCode],[Category],[Severity],[Confidence],[EvidenceLevel]
                        , [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
                        , [ThresholdValue],[ThresholdSource],[WorkloadProfile],[Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
                    )
                    SELECT @CandidateId,@CurrentPlanHandle,[FindingOrdinal],[FindingCode],[Category],[Severity],[Confidence],[EvidenceLevel]
                         , [StatementOrdinal],[StatementId],[NodeId],[PhysicalOp],[LogicalOp],[MetricName],[MetricValue],[MetricUnit]
                         , [ThresholdValue],[ThresholdSource],[WorkloadProfile],[Summary],[Evidence],[EvidenceLimit],[CounterEvidence],[RecommendedNextCheck]
                    FROM OPENJSON(@ChildJson,N'$.findings')
                    WITH
                    (
                          [FindingOrdinal] bigint N'$.FindingOrdinal',[FindingCode] varchar(100) N'$.FindingCode'
                        , [Category] varchar(40) N'$.Category',[Severity] varchar(16) N'$.Severity'
                        , [Confidence] varchar(32) N'$.Confidence',[EvidenceLevel] varchar(40) N'$.EvidenceLevel'
                        , [StatementOrdinal] int N'$.StatementOrdinal',[StatementId] int N'$.StatementId',[NodeId] int N'$.NodeId'
                        , [PhysicalOp] nvarchar(128) N'$.PhysicalOp',[LogicalOp] nvarchar(128) N'$.LogicalOp'
                        , [MetricName] varchar(80) N'$.MetricName',[MetricValue] decimal(38,4) N'$.MetricValue'
                        , [MetricUnit] nvarchar(40) N'$.MetricUnit',[ThresholdValue] decimal(38,4) N'$.ThresholdValue'
                        , [ThresholdSource] varchar(80) N'$.ThresholdSource',[WorkloadProfile] varchar(32) N'$.WorkloadProfile'
                        , [Summary] nvarchar(1000) N'$.Summary',[Evidence] nvarchar(2000) N'$.Evidence'
                        , [EvidenceLimit] nvarchar(2000) N'$.EvidenceLimit',[CounterEvidence] nvarchar(1000) N'$.CounterEvidence'
                        , [RecommendedNextCheck] nvarchar(1000) N'$.RecommendedNextCheck'
                    );

                    INSERT [#ShowplanAnalysis_Parameters]
                    (
                          [CandidateId],[PlanHandle],[SessionId],[RequestId]
                        , [StatementOrdinal],[StatementId],[StatementQueryHash],[StatementQueryPlanHash]
                        , [QueryStoreDatabaseName],[QueryStorePlanId],[PlanDocumentHash]
                        , [EvidenceKind],[ParameterName],[ParameterDataType]
                        , [CompiledValuePresent],[RuntimeValuePresent]
                        , [CompiledValueIsSqlNull],[RuntimeValueIsSqlNull]
                        , [CompiledValue],[RuntimeValue],[CompiledValueToken],[RuntimeValueToken]
                        , [CompiledValueLength],[RuntimeValueLength]
                        , [CompiledValueStatus],[RuntimeValueStatus],[ValueStatus]
                        , [ValueHandlingStatus],[ValueSource]
                        , [SourceObservedAtUtc],[ValueCapturedAtUtc]
                        , [IsCurrentExecution],[IsLastKnownExecution],[IsComplete],[EvidenceLimit]
                    )
                    SELECT
                          @CandidateId,@CurrentPlanHandle,[SessionId],[RequestId]
                        , [StatementOrdinal],[StatementId],[StatementQueryHash],[StatementQueryPlanHash]
                        , [QueryStoreDatabaseName],[QueryStorePlanId],[PlanDocumentHash]
                        , [EvidenceKind],[ParameterName],[ParameterDataType]
                        , [CompiledValuePresent],[RuntimeValuePresent]
                        , [CompiledValueIsSqlNull],[RuntimeValueIsSqlNull]
                        , [CompiledValue],[RuntimeValue],[CompiledValueToken],[RuntimeValueToken]
                        , [CompiledValueLength],[RuntimeValueLength]
                        , [CompiledValueStatus],[RuntimeValueStatus],[ValueStatus]
                        , [ValueHandlingStatus],[ValueSource]
                        , [SourceObservedAtUtc],[ValueCapturedAtUtc]
                        , [IsCurrentExecution],[IsLastKnownExecution],[IsComplete],[EvidenceLimit]
                    FROM OPENJSON(@ChildJson,N'$.parameters')
                    WITH
                    (
                          [SessionId] smallint N'$.SessionId'
                        , [RequestId] int N'$.RequestId'
                        , [StatementOrdinal] int N'$.StatementOrdinal'
                        , [StatementId] int N'$.StatementId'
                        , [StatementQueryHash] nvarchar(130) N'$.StatementQueryHash'
                        , [StatementQueryPlanHash] nvarchar(130) N'$.StatementQueryPlanHash'
                        , [QueryStoreDatabaseName] sysname N'$.QueryStoreDatabaseName'
                        , [QueryStorePlanId] bigint N'$.QueryStorePlanId'
                        , [PlanDocumentHash] nvarchar(66) N'$.PlanDocumentHash'
                        , [EvidenceKind] varchar(24) N'$.EvidenceKind'
                        , [ParameterName] nvarchar(256) N'$.ParameterName'
                        , [ParameterDataType] nvarchar(256) N'$.ParameterDataType'
                        , [CompiledValuePresent] bit N'$.CompiledValuePresent'
                        , [RuntimeValuePresent] bit N'$.RuntimeValuePresent'
                        , [CompiledValueIsSqlNull] bit N'$.CompiledValueIsSqlNull'
                        , [RuntimeValueIsSqlNull] bit N'$.RuntimeValueIsSqlNull'
                        , [CompiledValue] nvarchar(4000) N'$.CompiledValue'
                        , [RuntimeValue] nvarchar(4000) N'$.RuntimeValue'
                        , [CompiledValueToken] nvarchar(66) N'$.CompiledValueToken'
                        , [RuntimeValueToken] nvarchar(66) N'$.RuntimeValueToken'
                        , [CompiledValueLength] int N'$.CompiledValueLength'
                        , [RuntimeValueLength] int N'$.RuntimeValueLength'
                        , [CompiledValueStatus] varchar(40) N'$.CompiledValueStatus'
                        , [RuntimeValueStatus] varchar(40) N'$.RuntimeValueStatus'
                        , [ValueStatus] varchar(40) N'$.ValueStatus'
                        , [ValueHandlingStatus] varchar(40) N'$.ValueHandlingStatus'
                        , [ValueSource] varchar(40) N'$.ValueSource'
                        , [SourceObservedAtUtc] datetime2(3) N'$.SourceObservedAtUtc'
                        , [ValueCapturedAtUtc] datetime2(3) N'$.ValueCapturedAtUtc'
                        , [IsCurrentExecution] bit N'$.IsCurrentExecution'
                        , [IsLastKnownExecution] bit N'$.IsLastKnownExecution'
                        , [IsComplete] bit N'$.IsComplete'
                        , [EvidenceLimit] nvarchar(1000) N'$.EvidenceLimit'
                    );

                    INSERT [#ShowplanAnalysis_PlanWarnings]
                    SELECT
                          @CandidateId,@CurrentPlanHandle,[WarningOrdinal],[AnalysisObjectId]
                        , [StatementOrdinal],[StatementId],[NodeId],[WarningCode],[WarningCategory]
                        , [Severity],[EvidenceKind],[EvidenceSource],[PlanSource],[SourceObservedAtUtc]
                        , [IsCurrent],[IsLastKnown],[IsMeasured],[IsInferred],[MetricName],[MetricValue]
                        , [MetricUnit],[Detail],[FalsePositiveGuard],[StatusCode]
                    FROM OPENJSON(@ChildJson,N'$.planWarnings')
                    WITH
                    (
                          [WarningOrdinal] bigint N'$.WarningOrdinal',[AnalysisObjectId] int N'$.AnalysisObjectId'
                        , [StatementOrdinal] int N'$.StatementOrdinal',[StatementId] int N'$.StatementId',[NodeId] int N'$.NodeId'
                        , [WarningCode] varchar(100) N'$.WarningCode',[WarningCategory] varchar(40) N'$.WarningCategory'
                        , [Severity] varchar(16) N'$.Severity',[EvidenceKind] varchar(40) N'$.EvidenceKind'
                        , [EvidenceSource] varchar(40) N'$.EvidenceSource',[PlanSource] varchar(24) N'$.PlanSource'
                        , [SourceObservedAtUtc] datetime2(3) N'$.SourceObservedAtUtc'
                        , [IsCurrent] bit N'$.IsCurrent',[IsLastKnown] bit N'$.IsLastKnown'
                        , [IsMeasured] bit N'$.IsMeasured',[IsInferred] bit N'$.IsInferred'
                        , [MetricName] varchar(80) N'$.MetricName',[MetricValue] decimal(38,4) N'$.MetricValue'
                        , [MetricUnit] nvarchar(40) N'$.MetricUnit',[Detail] nvarchar(2000) N'$.Detail'
                        , [FalsePositiveGuard] nvarchar(2000) N'$.FalsePositiveGuard',[StatusCode] varchar(40) N'$.StatusCode'
                    );

                    INSERT [#ShowplanAnalysis_OptimizerContext]
                    SELECT
                          @CandidateId,@CurrentPlanHandle,[AnalysisObjectId],[StatementOrdinal],[StatementId]
                        , [PlanSource],[RuntimeCounterScope],[SourceObservedAtUtc],[IsCurrent],[IsLastKnown]
                        , [OptimizationLevel],[EarlyAbortReason],[CardinalityEstimationModelVersion]
                        , [StatementSubTreeCost],[StatementEstimatedRows],[CompileTimeMs],[CompileCpuMs],[CompileMemoryKb]
                        , [RetrievedFromCache],[NonParallelPlanReason],[PlanDegreeOfParallelism]
                        , [PlanGenerationNum],[CacheCreationTime],[CacheLastExecutionTime],[CacheExecutionCount]
                        , [CacheObjectType],[CacheObjectClass],[CacheUseCounts],[CacheRefCounts],[CacheSizeBytes],[CachePoolId]
                        , [SetOptions],[CompileUserId],[DatabaseId],[EvidenceMeasurement],[StatusCode],[FalsePositiveGuard]
                    FROM OPENJSON(@ChildJson,N'$.optimizerContext')
                    WITH
                    (
                          [AnalysisObjectId] int N'$.AnalysisObjectId',[StatementOrdinal] int N'$.StatementOrdinal'
                        , [StatementId] int N'$.StatementId',[PlanSource] varchar(24) N'$.PlanSource'
                        , [RuntimeCounterScope] varchar(32) N'$.RuntimeCounterScope'
                        , [SourceObservedAtUtc] datetime2(3) N'$.SourceObservedAtUtc'
                        , [IsCurrent] bit N'$.IsCurrent',[IsLastKnown] bit N'$.IsLastKnown'
                        , [OptimizationLevel] nvarchar(128) N'$.OptimizationLevel',[EarlyAbortReason] nvarchar(256) N'$.EarlyAbortReason'
                        , [CardinalityEstimationModelVersion] int N'$.CardinalityEstimationModelVersion'
                        , [StatementSubTreeCost] decimal(38,8) N'$.StatementSubTreeCost'
                        , [StatementEstimatedRows] decimal(38,4) N'$.StatementEstimatedRows'
                        , [CompileTimeMs] bigint N'$.CompileTimeMs',[CompileCpuMs] bigint N'$.CompileCpuMs'
                        , [CompileMemoryKb] bigint N'$.CompileMemoryKb',[RetrievedFromCache] bit N'$.RetrievedFromCache'
                        , [NonParallelPlanReason] nvarchar(256) N'$.NonParallelPlanReason'
                        , [PlanDegreeOfParallelism] int N'$.PlanDegreeOfParallelism'
                        , [PlanGenerationNum] bigint N'$.PlanGenerationNum',[CacheCreationTime] datetime N'$.CacheCreationTime'
                        , [CacheLastExecutionTime] datetime N'$.CacheLastExecutionTime',[CacheExecutionCount] bigint N'$.CacheExecutionCount'
                        , [CacheObjectType] nvarchar(34) N'$.CacheObjectType',[CacheObjectClass] nvarchar(16) N'$.CacheObjectClass'
                        , [CacheUseCounts] int N'$.CacheUseCounts',[CacheRefCounts] int N'$.CacheRefCounts'
                        , [CacheSizeBytes] bigint N'$.CacheSizeBytes',[CachePoolId] int N'$.CachePoolId'
                        , [SetOptions] bigint N'$.SetOptions',[CompileUserId] int N'$.CompileUserId',[DatabaseId] int N'$.DatabaseId'
                        , [EvidenceMeasurement] varchar(40) N'$.EvidenceMeasurement',[StatusCode] varchar(40) N'$.StatusCode'
                        , [FalsePositiveGuard] nvarchar(1000) N'$.FalsePositiveGuard'
                    );

                    INSERT [#ShowplanAnalysis_RuntimeFeedback]
                    SELECT
                          @CandidateId,@CurrentPlanHandle,[FeedbackOrdinal],[AnalysisObjectId]
                        , [StatementOrdinal],[StatementId],[NodeId],[FeedbackType],[FeedbackState]
                        , [MetricName],[ObservedValue],[BaselineValue],[DeltaRatio],[MetricUnit]
                        , [RuntimeCounterScope],[EvidenceSource],[SourceObservedAtUtc]
                        , [IsCurrent],[IsLastKnown],[IsMeasured],[IsDerived],[StatusCode],[EvidenceLimit]
                    FROM OPENJSON(@ChildJson,N'$.runtimeFeedback')
                    WITH
                    (
                          [FeedbackOrdinal] bigint N'$.FeedbackOrdinal',[AnalysisObjectId] int N'$.AnalysisObjectId'
                        , [StatementOrdinal] int N'$.StatementOrdinal',[StatementId] int N'$.StatementId',[NodeId] int N'$.NodeId'
                        , [FeedbackType] varchar(40) N'$.FeedbackType',[FeedbackState] nvarchar(128) N'$.FeedbackState'
                        , [MetricName] varchar(80) N'$.MetricName',[ObservedValue] decimal(38,4) N'$.ObservedValue'
                        , [BaselineValue] decimal(38,4) N'$.BaselineValue',[DeltaRatio] decimal(38,8) N'$.DeltaRatio'
                        , [MetricUnit] nvarchar(40) N'$.MetricUnit',[RuntimeCounterScope] varchar(32) N'$.RuntimeCounterScope'
                        , [EvidenceSource] varchar(40) N'$.EvidenceSource',[SourceObservedAtUtc] datetime2(3) N'$.SourceObservedAtUtc'
                        , [IsCurrent] bit N'$.IsCurrent',[IsLastKnown] bit N'$.IsLastKnown'
                        , [IsMeasured] bit N'$.IsMeasured',[IsDerived] bit N'$.IsDerived'
                        , [StatusCode] varchar(40) N'$.StatusCode',[EvidenceLimit] nvarchar(1000) N'$.EvidenceLimit'
                    );

                    INSERT [#ShowplanAnalysis_QueryStoreContext]
                    SELECT
                          @CandidateId,@CurrentPlanHandle,[AnalysisObjectId],[QueryStoreDatabaseName]
                        , [QueryStorePlanId],[QueryStoreQueryId],[PlanGroupId],[EngineVersion],[CompatibilityLevel]
                        , [QueryPlanHash],[IsTrivialPlan],[IsParallelPlan],[IsForcedPlan],[PlanForcingTypeDesc]
                        , [ForceFailureCount],[LastForceFailureReason],[LastForceFailureReasonDesc]
                        , [CountCompiles],[InitialCompileStartTime],[LastCompileStartTime],[LastExecutionTime]
                        , [AvgCompileDurationUs],[LastCompileDurationUs],[ContextSettingsId],[ObjectId],[QueryHash]
                        , [QueryParameterizationTypeDesc],[AvgOptimizeDurationUs],[AvgCompileMemoryKb]
                        , [HasCompileReplayScript],[IsOptimizedPlanForcingDisabled],[PlanType],[PlanTypeDesc]
                        , [RuntimeExecutionCount],[RuntimeLastExecutionTime],[AvgDurationUs],[AvgCpuTimeUs]
                        , [AvgLogicalIoReads],[AvgLogicalIoWrites],[QueryHintCount],[QueryHintFailureCount]
                        , [PersistedFeedbackCount],[VariantRelationCount],[SourceObservedAtUtc]
                        , [IsCurrent],[IsLastKnown],[StatusCode],[EvidenceLimit]
                    FROM OPENJSON(@ChildJson,N'$.queryStoreContext')
                    WITH
                    (
                          [AnalysisObjectId] int N'$.AnalysisObjectId',[QueryStoreDatabaseName] sysname N'$.QueryStoreDatabaseName'
                        , [QueryStorePlanId] bigint N'$.QueryStorePlanId',[QueryStoreQueryId] bigint N'$.QueryStoreQueryId'
                        , [PlanGroupId] bigint N'$.PlanGroupId',[EngineVersion] nvarchar(32) N'$.EngineVersion'
                        , [CompatibilityLevel] smallint N'$.CompatibilityLevel',[QueryPlanHash] binary(8) N'$.QueryPlanHash'
                        , [IsTrivialPlan] bit N'$.IsTrivialPlan',[IsParallelPlan] bit N'$.IsParallelPlan'
                        , [IsForcedPlan] bit N'$.IsForcedPlan',[PlanForcingTypeDesc] nvarchar(60) N'$.PlanForcingTypeDesc'
                        , [ForceFailureCount] bigint N'$.ForceFailureCount',[LastForceFailureReason] int N'$.LastForceFailureReason'
                        , [LastForceFailureReasonDesc] nvarchar(128) N'$.LastForceFailureReasonDesc'
                        , [CountCompiles] bigint N'$.CountCompiles',[InitialCompileStartTime] datetimeoffset(7) N'$.InitialCompileStartTime'
                        , [LastCompileStartTime] datetimeoffset(7) N'$.LastCompileStartTime'
                        , [LastExecutionTime] datetimeoffset(7) N'$.LastExecutionTime'
                        , [AvgCompileDurationUs] float N'$.AvgCompileDurationUs',[LastCompileDurationUs] bigint N'$.LastCompileDurationUs'
                        , [ContextSettingsId] bigint N'$.ContextSettingsId',[ObjectId] bigint N'$.ObjectId'
                        , [QueryHash] binary(8) N'$.QueryHash'
                        , [QueryParameterizationTypeDesc] nvarchar(60) N'$.QueryParameterizationTypeDesc'
                        , [AvgOptimizeDurationUs] float N'$.AvgOptimizeDurationUs',[AvgCompileMemoryKb] float N'$.AvgCompileMemoryKb'
                        , [HasCompileReplayScript] bit N'$.HasCompileReplayScript'
                        , [IsOptimizedPlanForcingDisabled] bit N'$.IsOptimizedPlanForcingDisabled'
                        , [PlanType] int N'$.PlanType',[PlanTypeDesc] nvarchar(120) N'$.PlanTypeDesc'
                        , [RuntimeExecutionCount] bigint N'$.RuntimeExecutionCount'
                        , [RuntimeLastExecutionTime] datetimeoffset(7) N'$.RuntimeLastExecutionTime'
                        , [AvgDurationUs] decimal(38,4) N'$.AvgDurationUs',[AvgCpuTimeUs] decimal(38,4) N'$.AvgCpuTimeUs'
                        , [AvgLogicalIoReads] decimal(38,4) N'$.AvgLogicalIoReads'
                        , [AvgLogicalIoWrites] decimal(38,4) N'$.AvgLogicalIoWrites'
                        , [QueryHintCount] int N'$.QueryHintCount',[QueryHintFailureCount] bigint N'$.QueryHintFailureCount'
                        , [PersistedFeedbackCount] int N'$.PersistedFeedbackCount',[VariantRelationCount] int N'$.VariantRelationCount'
                        , [SourceObservedAtUtc] datetime2(3) N'$.SourceObservedAtUtc'
                        , [IsCurrent] bit N'$.IsCurrent',[IsLastKnown] bit N'$.IsLastKnown'
                        , [StatusCode] varchar(40) N'$.StatusCode',[EvidenceLimit] nvarchar(1000) N'$.EvidenceLimit'
                    );

                    INSERT [#ShowplanAnalysis_FeedbackAndVariants]
                    SELECT
                          @CandidateId,@CurrentPlanHandle,[RecordOrdinal],[AnalysisObjectId],[RecordType],[FeatureType]
                        , [StatementOrdinal],[StatementId],[NodeId],[QueryStorePlanId],[QueryStoreQueryId]
                        , [ParentQueryId],[DispatcherPlanId],[QueryVariantQueryId],[QueryVariantId]
                        , [FeatureState],[FeatureData],[FeatureDataToken],[FeatureDataLength],[DataHandlingStatus]
                        , [EvidenceSource],[SourceObservedAtUtc],[IsCurrent],[IsLastKnown]
                        , [IsMeasured],[IsDerived],[StatusCode],[EvidenceLimit]
                    FROM OPENJSON(@ChildJson,N'$.feedbackAndVariants')
                    WITH
                    (
                          [RecordOrdinal] bigint N'$.RecordOrdinal',[AnalysisObjectId] int N'$.AnalysisObjectId'
                        , [RecordType] varchar(40) N'$.RecordType',[FeatureType] varchar(60) N'$.FeatureType'
                        , [StatementOrdinal] int N'$.StatementOrdinal',[StatementId] int N'$.StatementId',[NodeId] int N'$.NodeId'
                        , [QueryStorePlanId] bigint N'$.QueryStorePlanId',[QueryStoreQueryId] bigint N'$.QueryStoreQueryId'
                        , [ParentQueryId] bigint N'$.ParentQueryId',[DispatcherPlanId] bigint N'$.DispatcherPlanId'
                        , [QueryVariantQueryId] bigint N'$.QueryVariantQueryId',[QueryVariantId] int N'$.QueryVariantId'
                        , [FeatureState] nvarchar(128) N'$.FeatureState',[FeatureData] nvarchar(max) N'$.FeatureData'
                        , [FeatureDataToken] varbinary(32) N'$.FeatureDataToken',[FeatureDataLength] int N'$.FeatureDataLength'
                        , [DataHandlingStatus] varchar(40) N'$.DataHandlingStatus',[EvidenceSource] varchar(40) N'$.EvidenceSource'
                        , [SourceObservedAtUtc] datetime2(3) N'$.SourceObservedAtUtc'
                        , [IsCurrent] bit N'$.IsCurrent',[IsLastKnown] bit N'$.IsLastKnown'
                        , [IsMeasured] bit N'$.IsMeasured',[IsDerived] bit N'$.IsDerived'
                        , [StatusCode] varchar(40) N'$.StatusCode',[EvidenceLimit] nvarchar(1000) N'$.EvidenceLimit'
                    );
                END;
                SET @ProcessedPlans+=1;
                IF COALESCE(@ChildStatus,'STATUS_UNAVAILABLE')<>'AVAILABLE'
                BEGIN
                    SET @IsPartial=1;
                    IF @StatusCode='AVAILABLE' SET @StatusCode='PARTIAL';
                END;
            END TRY
            BEGIN CATCH
                INSERT [#ShowplanAnalysis_PlanStatus]
                VALUES(@CandidateId,@CurrentPlanHandle,'ERROR_HANDLED',1,NULL,NULL,0,DATEDIFF_BIG(MILLISECOND,@Started,SYSUTCDATETIME()),ERROR_NUMBER(),ERROR_MESSAGE());
                SET @IsPartial=1;
                IF @StatusCode='AVAILABLE' SET @StatusCode='PARTIAL';
                IF @ErrorNumber IS NULL BEGIN SET @ErrorNumber=ERROR_NUMBER(); SET @ErrorMessage=ERROR_MESSAGE(); END;
            END CATCH;
            IF (SELECT COUNT_BIG(*) FROM [#ShowplanAnalysis_Findings])>=@ResultLimit
            BEGIN
                SELECT @StatusCode='PARTIAL',@IsPartial=1,@ErrorMessage=N'Das Findinglimit wurde erreicht; weitere Pläne wurden nicht analysiert.';
                BREAK;
            END;
            FETCH NEXT FROM [PlanCursor] INTO @CandidateId,@CurrentPlanHandle;
        END;
        CLOSE [PlanCursor];DEALLOCATE [PlanCursor];
    END;

    IF @IsPartial=1 AND @StatusCode='AVAILABLE' SET @StatusCode='PARTIAL';
    INSERT [#ShowplanAnalysis_ModuleStatus]
    SELECT N'USP_ShowplanAnalysis',@Now,@StatusCode,@IsPartial,@CandidateCount,@ProcessedPlans,
           (SELECT COUNT_BIG(*) FROM [#ShowplanAnalysis_Findings]),@ErrorNumber,@ErrorMessage;

    IF @JsonErzeugen=1
    BEGIN
        DECLARE @Meta nvarchar(max)=(SELECT N'ShowplanAnalysis' [resultName],4 [schemaVersion],@Now [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@CandidateCount [candidateCount],@ProcessedPlans [processedPlanCount] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @PlanStatusJson nvarchar(max)=(SELECT * FROM [#ShowplanAnalysis_PlanStatus] ORDER BY [CandidateId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @ParametersJson nvarchar(max)=(SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_Parameters] ORDER BY [CandidateId],[StatementOrdinal],[EvidenceKind],[ParameterName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @PlanWarningsJson nvarchar(max)=(SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_PlanWarnings] ORDER BY [CandidateId],[WarningOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @OptimizerContextJson nvarchar(max)=(SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_OptimizerContext] ORDER BY [CandidateId],[StatementOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @RuntimeFeedbackJson nvarchar(max)=(SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_RuntimeFeedback] ORDER BY [CandidateId],[FeedbackOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @QueryStoreContextJson nvarchar(max)=(SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_QueryStoreContext] ORDER BY [CandidateId],[QueryStorePlanId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @FeedbackAndVariantsJson nvarchar(max)=(SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_FeedbackAndVariants] ORDER BY [CandidateId],[RecordOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @FindingsJson nvarchar(max)=(SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_Findings] ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,[CandidateId],[FindingOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
        DECLARE @AnalysesJson nvarchar(max)=N'[]';
        SELECT @AnalysesJson=COALESCE(N'['+STRING_AGG(CONVERT(nvarchar(max),[AnalysisJson]),N',') WITHIN GROUP (ORDER BY [CandidateId])+N']',N'[]')
        FROM [#ShowplanAnalysis_Analyses] WHERE ISJSON([AnalysisJson])=1;
        SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"planStatus":',COALESCE(@PlanStatusJson,N'[]'),N',"parameters":',COALESCE(@ParametersJson,N'[]'),N',"planWarnings":',COALESCE(@PlanWarningsJson,N'[]'),N',"optimizerContext":',COALESCE(@OptimizerContextJson,N'[]'),N',"runtimeFeedback":',COALESCE(@RuntimeFeedbackJson,N'[]'),N',"queryStoreContext":',COALESCE(@QueryStoreContextJson,N'[]'),N',"feedbackAndVariants":',COALESCE(@FeedbackAndVariantsJson,N'[]'),N',"findings":',COALESCE(@FindingsJson,N'[]'),N',"analyses":',COALESCE(@AnalysesJson,N'[]'),N'}');
    END;

    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#ShowplanAnalysis_ModuleStatus];
        SELECT * FROM [#ShowplanAnalysis_PlanStatus] ORDER BY [CandidateId];
        SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_Parameters]
        ORDER BY [CandidateId],[StatementOrdinal],[EvidenceKind],[ParameterName];
        SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_PlanWarnings]
        ORDER BY [CandidateId],[WarningOrdinal];
        SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_OptimizerContext]
        ORDER BY [CandidateId],[StatementOrdinal];
        SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_RuntimeFeedback]
        ORDER BY [CandidateId],[FeedbackOrdinal];
        SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_QueryStoreContext]
        ORDER BY [CandidateId],[QueryStorePlanId];
        SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_FeedbackAndVariants]
        ORDER BY [CandidateId],[RecordOrdinal];
        SELECT TOP (@ResultLimit) * FROM [#ShowplanAnalysis_Findings]
        ORDER BY CASE [Severity] WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 WHEN 'LOW' THEN 4 ELSE 5 END,[CandidateId],[FindingOrdinal];
    END;
    IF @ConsoleResultRequested=1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ShowplanAnalysis_Findings',@ResultLabel=N'Showplan Finding'
            , @EmptyMessage=N'Keine Showplan-Findings im gewählten Scope'
            , @StatusCode=@StatusCode,@StatusMessage=@ErrorMessage;
    IF @TableRequested=1
    BEGIN
        DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
        DECLARE [ShowplanOutputCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [ResultName],[TargetTable]
            FROM [#ShowplanAnalysis_TableMap]
            ORDER BY [ResultName];
        OPEN [ShowplanOutputCursor];
        FETCH NEXT FROM [ShowplanOutputCursor] INTO @ResultName,@TargetTable;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @SourceTable=CASE @ResultName
                WHEN N'parameters' THEN N'#ShowplanAnalysis_Parameters'
                WHEN N'planWarnings' THEN N'#ShowplanAnalysis_PlanWarnings'
                WHEN N'optimizerContext' THEN N'#ShowplanAnalysis_OptimizerContext'
                WHEN N'runtimeFeedback' THEN N'#ShowplanAnalysis_RuntimeFeedback'
                WHEN N'queryStoreContext' THEN N'#ShowplanAnalysis_QueryStoreContext'
                WHEN N'feedbackAndVariants' THEN N'#ShowplanAnalysis_FeedbackAndVariants'
                WHEN N'findings' THEN N'#ShowplanAnalysis_Findings' END;
            EXEC [monitor].[InternalWriteResultTable]
                  @SourceTable=@SourceTable,@TargetTable=@TargetTable,@ThrowOnError=1;
            FETCH NEXT FROM [ShowplanOutputCursor] INTO @ResultName,@TargetTable;
        END;
        CLOSE [ShowplanOutputCursor];
        DEALLOCATE [ShowplanOutputCursor];
    END;
    IF @PrintMeldungen=1 AND @StatusCode<>'AVAILABLE'
    BEGIN
        DECLARE @Message nvarchar(2048)=FORMATMESSAGE(N'WARNUNG USP_ShowplanAnalysis: %s - %s',@StatusCode,COALESCE(@ErrorMessage,N'partielle Analyse'));
        RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
    END;
END;
GO
