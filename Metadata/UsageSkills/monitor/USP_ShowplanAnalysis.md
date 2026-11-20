---
skill_format_version: "1.0.0"
name: "monitor.USP_ShowplanAnalysis"
schema_name: "monitor"
object_name: "USP_ShowplanAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Selektiert begrenzt Plan-Cache-Kandidaten und verwendet je eindeutigem Planhandle die zentrale Execution-Plan-Analyse."
source_path: "Code/04_PlanCache/050_USP_ShowplanAnalysis.sql"
---

# monitor.USP_ShowplanAnalysis

## Zweck und Einsatz

Selektiert begrenzt Plan-Cache-Kandidaten und verwendet je eindeutigem Planhandle die zentrale Execution-Plan-Analyse. Mehrere dm_exec_query_stats-Statements desselben Batchplans führen nicht mehr zu wiederholtem XML-Shredding.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_ShowplanAnalysis] im vorgesehenen Datenbankkontext. Die Procedure liest Cache-/Plan-DMVs und kann über Planhandles zusätzliche Planinformationen beziehen; Verfügbarkeit und Sichtbarkeit hängen von SQL-Version, Callerrechten und noch vorhandenen Cacheeinträgen ab.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @PlanHandle | varbinary(64) | nein | NULL |
| @QueryHash | binary(8) | nein | NULL |
| @QueryPlanHash | binary(8) | nein | NULL |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @TextPattern | nvarchar(4000) | nein | NULL |
| @AnalyseModus | varchar(16) | nein | 'GEZIELT' |
| @PlanQuelle | varchar(16) | nein | 'AUTO' |
| @Sortierung | varchar(32) | nein | 'CPU_TOTAL' |
| @MinExecutionCount | bigint | nein | 1 |
| @MaxAnalyseobjekte | int | nein | 20 |
| @MaxDurationSeconds | int | nein | 30 |
| @MaxZeilen | int | nein | 50000 |
| @ParentQueryStatsSnapshot | bit | nein | 0 |
| @WorkloadProfil | varchar(32) | nein | 'AUTO' |
| @MinSchweregrad | varchar(16) | nein | 'INFO' |
| @MitThreadRuntime | bit | nein | 0 |
| @MitSqlText | bit | nein | 0 |
| @StatistikEvidenzModus | varchar(16) | nein | 'PLAN_ONLY' |
| @HistogrammModus | varchar(16) | nein | 'NONE' |
| @MetadatenQuellenmodus | varchar(16) | nein | 'EVIDENCE_ONLY' |
| @QuellumgebungBestaetigt | bit | nein | 0 |
| @EvidenzDatenschutzModus | varchar(24) | nein | 'DERIVED_ONLY' |
| @IdentifierDatenschutzModus | varchar(16) | nein | 'RAW' |
| @SensitiveDataConfirmed | bit | nein | 0 |
| @MaxStatistiken | int | nein | 100 |
| @MaxHistogrammSchritte | int | nein | 20000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@PlanHandle:** @PlanHandle varbinary(64). Default ist NULL. Exakter Planhandle. Nicht-NULL fügt den Handle direkt als Kandidat hinzu. NULL erlaubt Cacheauswahl per weiteren Selektoren oder VOLL.

**@QueryHash:** @QueryHash binary(8). Default ist NULL. Exakter binärer 8-Byte-Queryhash für die Cacheauswahl. NULL lässt diesen Filter aus.

**@QueryPlanHash:** @QueryPlanHash binary(8). Default ist NULL. Exakter binärer 8-Byte-Plan-Hash für die Cacheauswahl. NULL lässt diesen Filter aus.

**@DatabaseNames:** @DatabaseNames nvarchar(max). Default ist NULL. Pipe-Liste exakter Datenbanknamen. NULL, leer oder nur Leerzeichen = keine exakte Einschränkung. | trennt außerhalb von [...]. ]] maskiert ] innerhalb. Äußere Segmentleerzeichen entfernt. Elemente einteilige Namen bis 128 Zeichen. Ungültige Liste INVALID_PARAMETER.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet den Wert vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Eingabeformen unterliegen der SQL-Typkonvertierung, eine eigene Textnormalisierung oder Leertextauswahl erfolgt nicht, und Bindungsfehler treten vor dem Prozeduraufruf auf. Bei Status AVAILABLE und @PlanHandle IS NULL ruft Showplan den Kandidatenhelfer auf: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu, sofern sie sichtbar, online und zugänglich sind und die übrigen Listen-, Pattern- und Snapshotbedingungen erfüllen. NULL wird vom Kandidatenhelfer als INVALID_PARAMETER abgelehnt, wenn diese Prüfung erreicht wird. Bei einem direkt übergebenen, nicht-NULL @PlanHandle wird der gebundene Wert im Prozedurcode nicht ausgewertet und filtert oder verwirft diesen Handle nicht. Frühere Fehler können die Kandidatenprüfung verhindern. Die sonstigen Validierungen und die jeweils geltenden SQL-Rechte sowie Deep- und Showplan-Gates bleiben unverändert.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000). Default ist NULL. Ein LIKE-Pattern oder Präfix like:, regex:, regexi:. Erkennung ohne Beachtung der Großschreibung. Äußere Leerzeichen getrimmt, Musterrest nicht erneut. NULL = kein Pattern. Leerer Inhalt ungültig. Nicht mit wirksamer @DatabaseNames-Liste kombinierbar. Regex Flag c/i und Ausführung nur SQL Server 2025 + Compatibility Level 170 der Installationsdatenbank. Sonst UNAVAILABLE_FEATURE.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 0 keine Bestätigung. 1 bestätigt angeforderte Policy-Gates für PLAN_CACHE_DEEP und/oder SHOWPLAN_XML_DEEP. Bestätigung hebt Filter und Limits nicht auf.

**@TextPattern:** @TextPattern nvarchar(4000). Default ist NULL; bei Auslassung gilt NULL und es wird kein Textfilter angefordert. Der Parser trimmt zuerst äußere U+0020-Leerzeichen, erkennt like:, regex: und regexi: ohne Beachtung der Groß- und Kleinschreibung und entfernt ein erkanntes Präfix ohne erneutes Trimmen. Ohne bekanntes Präfix gilt der gesamte Inhalt als LIKE-Muster, auch bei einem unbekannten Präfix. NULL ergibt NONE. Eine leere Eingabe, eine reine U+0020-Leerzeichenfolge oder ein leerer Präfixrest erzeugt intern EMPTY_PATTERN. Ist der Status bis dahin AVAILABLE, setzt Showplan dafür INVALID_PARAMETER. LIKE verwendet %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. REGEX verwendet Flag c (case-sensitive), REGEXI Flag i (case-insensitive). Der Parser prüft keine Regexsyntax; Syntaxfehler entstehen erst bei tatsächlicher REGEXP_LIKE-Ausführung. Regexausführung erfordert SQL Server 2025 und Compatibility Level mindestens 170 der Installationsdatenbank. @TextPattern ist keine Pipe-Liste. NULL ist in GEZIELT kein Selektor; ein anderer Selektor bleibt erforderlich. Bei Status AVAILABLE prüft Showplan Form, leeren Patternrest und gegebenenfalls Regexversion und Compatibility Level vor der Handleauswahl. Ohne direkten Planhandle wendet es das Pattern auf den SQL-Text an. Ein direkt übergebener, nicht-NULL @PlanHandle wird ohne Textvergleich übernommen; REGEXP_LIKE wird dann nicht ausgeführt, sodass Regexsyntax ungeprüft bleiben kann. Die sonstigen Validierungen und die jeweils geltenden SQL-Rechte sowie Deep- und Showplan-Gates bleiben unverändert.

**@AnalyseModus:** @AnalyseModus varchar(16). Default ist 'GEZIELT'. GEZIELT erfordert einen Planhandle, einen der beiden Hashes, eine nichtleere Datenbankliste oder ein Datenbank- oder Textmuster. Die Listen und Muster werden anschließend separat geprüft. Der Modus verwendet die Child-Tiefe STANDARD. VOLL prüft PLAN_CACHE_DEEP und verwendet FULL. NULL entspricht GEZIELT. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte sind ungültig.

**@PlanQuelle:** @PlanQuelle varchar(16). Default ist 'AUTO'. AUTO versucht den verfügbaren letzten Actual-Plan und fällt auf COMPILE zurück. COMPILE verwendet den kompilierten Cacheplan. LAST_ACTUAL fordert den letzten verfügbaren Actual-Plan ohne Aktivierung von Profiling an. NULL entspricht AUTO. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte sind ungültig.

**@Sortierung:** @Sortierung varchar(32). Default ist 'CPU_TOTAL'. Trim/Upper, bestimmt Top-Kandidaten-Ranking. CPU_TOTAL=gesamte Workerzeit. ELAPSED_TOTAL=gesamte Laufzeit. READS_TOTAL=gesamte Reads. EXECUTIONS=Ausführungszahl. SPILLS_TOTAL=Spillmaß. GRANT_MAX=größtes Grant. LAST_EXECUTION=letzte Ausführung. Alle sieben erlaubten Codes, NULL fällt auf CPU_TOTAL zurück. Leer ungültig.

**@MinExecutionCount:** @MinExecutionCount bigint. Default ist 1. Ganzzahliges Minimum für die Ausführungszahl in der Cacheauswahl. 0 lässt auch Einträge mit 0 Ausführungen zu. Negative Werte ergeben INVALID_PARAMETER. Bei NULL trifft der Vergleich auf keine Cachezeile. Ein direkt angegebener Planhandle bleibt ein eigener Kandidatenpfad.

**@MaxAnalyseobjekte:** @MaxAnalyseobjekte int. Default ist 20. Positive Grenze der Kandidaten vor Planladen. 0/NULL unbegrenzt. Negativ ungültig. >20 oder unbegrenzt prüft PLAN_CACHE_DEEP, danach kann VOLL zusätzlich SHOWPLAN_XML_DEEP prüfen.

**@MaxDurationSeconds:** @MaxDurationSeconds int. Default ist 30. Ganzzahl von 1 bis 3600 Sekunden. Das Zeitbudget wird zwischen Kandidaten geprüft. Es unterbricht eine laufende XML-Analyse nicht. NULL ist ungültig und wird auf Wrapper-Ebene abgelehnt.

**@MaxZeilen:** @MaxZeilen int. Default ist 50000. Positiv begrenzt Ergebniszeilen/Findingbudget. 0/NULL unbegrenzt (Childbudget wird intern auf 50000 gedeckelt). Negativ ungültig. Resultset-TOP und Candidate-Limit sind getrennte Grenzen.

**@ParentQueryStatsSnapshot:** @ParentQueryStatsSnapshot bit. Default ist 0. 0 liest Query Stats frisch. 1 verwendet den laufgebundenen Snapshot von USP_PlanCacheAnalysis. NULL aktiviert den Snapshot-Zweig nicht. Verwenden Sie 0 für eigenständige Aufrufe.

**@WorkloadProfil:** @WorkloadProfil varchar(32). Default ist 'AUTO'. Auswahl des aktiven Workloadprofils für Regeln und Schwellwerte. AUTO wählt innerhalb der Analyse aus der aktivierten Profilkonfiguration (monitor.PlanAnalysisProfile). Der konkrete gültige Profilcode ist damit installations-/konfigurationsabhängig, keine im Wrapper geschlossene Liste. Profilcodes werden im Child auf Großschreibung normalisiert. Unbekannter/deaktivierter Code fällt intern kontrolliert auf BALANCED zurück. NULL wird vom Child auf AUTO normalisiert. Leerwert führt zum unbekannten Profil und Fallback BALANCED.

**@MinSchweregrad:** @MinSchweregrad varchar(16). Default ist 'INFO'. Mindestschweregrad für Findings. Geschlossene Menge INFO, LOW, MEDIUM, HIGH, CRITICAL. Stufen sind aufsteigende Mindestschwellen, INFO lässt die niedrigste Stufe zu, CRITICAL nur höchste Schwere. NULL wird auf INFO normalisiert. Leertext ist ungültig.

**@MitThreadRuntime:** @MitThreadRuntime bit. Default ist 0. 0 unterdrückt Thread-Runtime-Evidenz. 1 fordert sie an. Verwenden Sie 0 oder 1 als eindeutigen Schalter. Für Threaddaten können Quellverfügbarkeit und Planumfang Grenzen setzen.

**@MitSqlText:** @MitSqlText bit. Default ist 0. 0 unterdrückt SQL-Text. 1 fordert Statementtext an und benötigt zusätzlich SensitiveDataConfirmed=1, da Literale/proprietärer Text enthalten sein können. Verwenden Sie 0 oder 1 als eindeutigen Schalter.

**@StatistikEvidenzModus:** @StatistikEvidenzModus varchar(16). Default ist 'PLAN_ONLY'. Geschlossene Menge: NONE=keine Statistik-Evidenz. PLAN_ONLY=nur Statistikhinweise aus Plan-XML. USED=Statistiken, die der Plan als benutzt ausweist. RELEVANT=erweiterte relevante Statistiken samt tieferer Evidence. OBJECT_ALL=alle Statistiken der referenzierten Objekte. NULL normalisiert zu PLAN_ONLY. Leertext ungültig. RELEVANT und OBJECT_ALL lösen tiefere Statistik-/Katalogpfade aus.

**@HistogrammModus:** @HistogrammModus varchar(16). Default ist 'NONE'. Geschlossene Menge: NONE=kein Histogramm. SUMMARY=Zusammenfassung. STEPS=Schrittwerte des Histogramms. NULL wird zu NONE normalisiert. Leertext ungültig. STEPS gehört zum tiefen Pfad. MaxHistogrammSchritte begrenzt die gelieferten Schritte.

**@MetadatenQuellenmodus:** @MetadatenQuellenmodus varchar(16). Default ist 'EVIDENCE_ONLY'. Geschlossene Menge: EVIDENCE_ONLY verwendet im Plan/Evidence vorhandene Metadaten. CURRENT_SERVER reichert aus dem aktuellen Serverkatalog an. NULL wird zu EVIDENCE_ONLY normalisiert. Leertext ungültig. CURRENT_SERVER erfordert QuellumgebungBestaetigt=1, damit die aktuelle Umgebung ausdrücklich als Datenquelle bestätigt ist.

**@QuellumgebungBestaetigt:** @QuellumgebungBestaetigt bit. Default ist 0. 0 keine Bestätigung. 1 bestätigt, dass CURRENT_SERVER-Katalogmetadaten der Quellumgebung zugeordnet werden dürfen. Nur 0/1. NULL ungültig. CURRENT_SERVER ohne 1 wird abgelehnt.

**@EvidenzDatenschutzModus:** @EvidenzDatenschutzModus varchar(24). Default ist 'DERIVED_ONLY'. Geschlossene Menge: DERIVED_ONLY gibt abgeleitete Evidenz ohne rohe Parameter-/Histogrammwerte aus. TOKENIZED ersetzt sensible Werte durch Token. STRUCTURE_ONLY gibt Struktur/Metadaten ohne Werte aus. RAW gibt rohe Parameter- und Histogrammwerte aus. NULL wird zu DERIVED_ONLY normalisiert. Leertext ungültig. RAW erfordert SensitiveDataConfirmed=1.

**@IdentifierDatenschutzModus:** @IdentifierDatenschutzModus varchar(16). Default ist 'RAW'. Geschlossene Menge: RAW gibt Objekt-/Statistikidentifikatoren im Original aus. TOKENIZED ersetzt sie durch Token. OMIT lässt Identifikatoren weg. NULL wird zu RAW normalisiert. Leertext ungültig.

**@SensitiveDataConfirmed:** @SensitiveDataConfirmed bit. Default ist 0. 0 keine Freigabebestätigung. 1 bestätigt die bewusste Verarbeitung potentiell sensibler Rohwerte. Verwenden Sie 0 oder 1 als eindeutigen Schalter. Erforderlich bei EvidenzDatenschutzModus=RAW oder MitSqlText=1. Kein allgemeiner Gate-Bypass.

**@MaxStatistiken:** @MaxStatistiken int. Default ist 100. Anzahlbegrenzung der gelesenen Statistikobjekte, Bereich 1..1000. 0 und NULL ungültig. Bei tiefer Statistik-Evidenz begrenzt diese Zahl die Katalogarbeit.

**@MaxHistogrammSchritte:** @MaxHistogrammSchritte int. Default ist 20000. Maximal gelesene Histogrammschritte, Bereich 0..200000. 0 erlaubt keine Schritte (Zusammenfassung bleibt möglich), NULL ungültig.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. Trim/Upper. CONSOLE lesbare Resultsets, RAW kanonische Detailresultsets, TABLE schreibt die typisierten Resultsets in Zieltabellen, NONE unterdrückt direkte Resultsets. Erlaubt genau CONSOLE, RAW, TABLE, NONE. NULL wird leer und ungültig, Leerwert ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakt geschriebenen Schlüssel parameters, planWarnings, optimizerContext, runtimeFeedback, queryStoreContext, feedbackAndVariants und findings. Jeder Wert muss als Zeichenfolge eine andere vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte benennen. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE ist ausschließlich NULL erlaubt. Auch eine leere Zeichenfolge ist ungültig. Die Zuordnung wird nach dem Hilfe-Return und vor den Quellzugriffen geprüft. Ein ungültiges Mapping kann Fehler 51011 auslösen.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 oder NULL erzeugt kein Dokument.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT nvarchar(max), wird beim Eintritt auf NULL gesetzt und bei JsonErzeugen=1 mit Objekt meta, planStatus und den sieben Fachergebnisarrays sowie analyses befüllt. Caller muss gleich typisierten Variable OUTPUT binden.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent validiert oder normalisiert den Wert nicht. 1 erzeugt nur am erreichten regulären Ende eine Severity-10-Warnung, wenn der Status nicht NULL und ungleich AVAILABLE ist; 0 und NULL erfüllen diese Bedingung nicht. Die Warnung verwendet FORMATMESSAGE und RAISERROR WITH NOWAIT, ist keine Ausnahme und kann durch Hilfe oder frühere Fehler ausbleiben. Der Interpreteraufruf erhält fest @PrintMeldungen=0; der Callerwert wird dafür nicht weitergereicht. Hilfe-PRINTs und Vorbereitungs-/SQL-Fehler sind unabhängig. Der Schalter steuert keine Resultsets, JSON, Analyseauswahl oder Fehlerbehandlung und garantiert keine vollständige Stille.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe und beendet den Aufruf vor Validierung, TABLE-Zuordnungsprüfung und fachlicher Analyse. 0 und NULL führen die Analyse aus.

## Resultate und Ausgabe

CONSOLE: findings. TABLE: parameters, DIAG-005-Kontext, findings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| parameters | 1 | 1 | [CandidateId] int NOT NULL , [PlanHandle] varbinary(64) NOT NULL , [SessionId] smallint NULL , [RequestId] int NULL , [StatementOrdinal] int NULL , [StatementId] int NULL , [StatementQueryHash] nvarchar(130) NULL , [StatementQueryPlanHash] nvarchar(130) NULL , [QueryStoreDatabaseName] sysname NULL , [QueryStorePlanId] bigint NULL , [PlanDocumentHash] nvarchar(66) NULL , [EvidenceKind] varchar(24) NOT NULL , [ParameterName] nvarchar(256) NULL , [ParameterDataType] nvarchar(256) NULL , [CompiledValuePresent] bit NOT NULL , [RuntimeValuePresent] bit NOT NULL , [CompiledValueIsSqlNull] bit NULL , [RuntimeValueIsSqlNull] bit NULL , [CompiledValue] nvarchar(4000) NULL , [RuntimeValue] nvarchar(4000) NULL , [CompiledValueToken] nvarchar(66) NULL , [RuntimeValueToken] nvarchar(66) NULL , [CompiledValueLength] int NULL , [RuntimeValueLength] int NULL , [CompiledValueStatus] varchar(40) NOT NULL , [RuntimeValueStatus] varchar(40) NOT NULL , [ValueStatus] varchar(40) NOT NULL , [ValueHandlingStatus] varchar(40) NOT NULL , [ValueSource] varchar(40) NOT NULL , [SourceObservedAtUtc] datetime2(3) NOT NULL , [ValueCapturedAtUtc] datetime2(3) NULL , [IsCurrentExecution] bit NULL , [IsLastKnownExecution] bit NULL , [IsComplete] bit NOT NULL , [EvidenceLimit] nvarchar(1000) NULL |
| planWarnings | 1 | 1 | [CandidateId] int NOT NULL , [PlanHandle] varbinary(64) NOT NULL , [WarningOrdinal] bigint NOT NULL , [AnalysisObjectId] int NOT NULL , [StatementOrdinal] int NULL , [StatementId] int NULL , [NodeId] int NULL , [WarningCode] varchar(100) NOT NULL , [WarningCategory] varchar(40) NOT NULL , [Severity] varchar(16) NOT NULL , [EvidenceKind] varchar(40) NOT NULL , [EvidenceSource] varchar(40) NOT NULL , [PlanSource] varchar(24) NULL , [SourceObservedAtUtc] datetime2(3) NOT NULL , [IsCurrent] bit NULL , [IsLastKnown] bit NULL , [IsMeasured] bit NOT NULL , [IsInferred] bit NOT NULL , [MetricName] varchar(80) NULL , [MetricValue] decimal(38,4) NULL , [MetricUnit] nvarchar(40) NULL , [Detail] nvarchar(2000) NOT NULL , [FalsePositiveGuard] nvarchar(2000) NOT NULL , [StatusCode] varchar(40) NOT NULL |
| optimizerContext | 1 | 1 | [CandidateId] int NOT NULL , [PlanHandle] varbinary(64) NOT NULL , [AnalysisObjectId] int NOT NULL , [StatementOrdinal] int NULL , [StatementId] int NULL , [PlanSource] varchar(24) NULL , [RuntimeCounterScope] varchar(32) NULL , [SourceObservedAtUtc] datetime2(3) NOT NULL , [IsCurrent] bit NULL , [IsLastKnown] bit NULL , [OptimizationLevel] nvarchar(128) NULL , [EarlyAbortReason] nvarchar(256) NULL , [CardinalityEstimationModelVersion] int NULL , [StatementSubTreeCost] decimal(38,8) NULL , [StatementEstimatedRows] decimal(38,4) NULL , [CompileTimeMs] bigint NULL , [CompileCpuMs] bigint NULL , [CompileMemoryKb] bigint NULL , [RetrievedFromCache] bit NULL , [NonParallelPlanReason] nvarchar(256) NULL , [PlanDegreeOfParallelism] int NULL , [PlanGenerationNum] bigint NULL , [CacheCreationTime] datetime NULL , [CacheLastExecutionTime] datetime NULL , [CacheExecutionCount] bigint NULL , [CacheObjectType] nvarchar(34) NULL , [CacheObjectClass] nvarchar(16) NULL , [CacheUseCounts] int NULL , [CacheRefCounts] int NULL , [CacheSizeBytes] bigint NULL , [CachePoolId] int NULL , [SetOptions] bigint NULL , [CompileUserId] int NULL , [DatabaseId] int NULL , [EvidenceMeasurement] varchar(40) NOT NULL , [StatusCode] varchar(40) NOT NULL , [FalsePositiveGuard] nvarchar(1000) NOT NULL |
| runtimeFeedback | 1 | 1 | [CandidateId] int NOT NULL , [PlanHandle] varbinary(64) NOT NULL , [FeedbackOrdinal] bigint NOT NULL , [AnalysisObjectId] int NOT NULL , [StatementOrdinal] int NULL , [StatementId] int NULL , [NodeId] int NULL , [FeedbackType] varchar(40) NOT NULL , [FeedbackState] nvarchar(128) NULL , [MetricName] varchar(80) NULL , [ObservedValue] decimal(38,4) NULL , [BaselineValue] decimal(38,4) NULL , [DeltaRatio] decimal(38,8) NULL , [MetricUnit] nvarchar(40) NULL , [RuntimeCounterScope] varchar(32) NULL , [EvidenceSource] varchar(40) NOT NULL , [SourceObservedAtUtc] datetime2(3) NOT NULL , [IsCurrent] bit NULL , [IsLastKnown] bit NULL , [IsMeasured] bit NOT NULL , [IsDerived] bit NOT NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| queryStoreContext | 1 | 1 | [CandidateId] int NOT NULL , [PlanHandle] varbinary(64) NOT NULL , [AnalysisObjectId] int NOT NULL , [QueryStoreDatabaseName] sysname NULL , [QueryStorePlanId] bigint NULL , [QueryStoreQueryId] bigint NULL , [PlanGroupId] bigint NULL , [EngineVersion] nvarchar(32) NULL , [CompatibilityLevel] smallint NULL , [QueryPlanHash] binary(8) NULL , [IsTrivialPlan] bit NULL , [IsParallelPlan] bit NULL , [IsForcedPlan] bit NULL , [PlanForcingTypeDesc] nvarchar(60) NULL , [ForceFailureCount] bigint NULL , [LastForceFailureReason] int NULL , [LastForceFailureReasonDesc] nvarchar(128) NULL , [CountCompiles] bigint NULL , [InitialCompileStartTime] datetimeoffset(7) NULL , [LastCompileStartTime] datetimeoffset(7) NULL , [LastExecutionTime] datetimeoffset(7) NULL , [AvgCompileDurationUs] float NULL , [LastCompileDurationUs] bigint NULL , [ContextSettingsId] bigint NULL , [ObjectId] bigint NULL , [QueryHash] binary(8) NULL , [QueryParameterizationTypeDesc] nvarchar(60) NULL , [AvgOptimizeDurationUs] float NULL , [AvgCompileMemoryKb] float NULL , [HasCompileReplayScript] bit NULL , [IsOptimizedPlanForcingDisabled] bit NULL , [PlanType] int NULL , [PlanTypeDesc] nvarchar(120) NULL , [RuntimeExecutionCount] bigint NULL , [RuntimeLastExecutionTime] datetimeoffset(7) NULL , [AvgDurationUs] decimal(38,4) NULL , [AvgCpuTimeUs] decimal(38,4) NULL , [AvgLogicalIoReads] decimal(38,4) NULL , [AvgLogicalIoWrites] decimal(38,4) NULL , [QueryHintCount] int NOT NULL , [QueryHintFailureCount] bigint NOT NULL , [PersistedFeedbackCount] int NOT NULL , [VariantRelationCount] int NOT NULL , [SourceObservedAtUtc] datetime2(3) NOT NULL , [IsCurrent] bit NOT NULL , [IsLastKnown] bit NOT NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| feedbackAndVariants | 1 | 1 | [CandidateId] int NOT NULL , [PlanHandle] varbinary(64) NOT NULL , [RecordOrdinal] bigint NOT NULL , [AnalysisObjectId] int NOT NULL , [RecordType] varchar(40) NOT NULL , [FeatureType] varchar(60) NOT NULL , [StatementOrdinal] int NULL , [StatementId] int NULL , [NodeId] int NULL , [QueryStorePlanId] bigint NULL , [QueryStoreQueryId] bigint NULL , [ParentQueryId] bigint NULL , [DispatcherPlanId] bigint NULL , [QueryVariantQueryId] bigint NULL , [QueryVariantId] int NULL , [FeatureState] nvarchar(128) NULL , [FeatureData] nvarchar(max) NULL , [FeatureDataToken] varbinary(32) NULL , [FeatureDataLength] int NULL , [DataHandlingStatus] varchar(40) NOT NULL , [EvidenceSource] varchar(40) NOT NULL , [SourceObservedAtUtc] datetime2(3) NOT NULL , [IsCurrent] bit NULL , [IsLastKnown] bit NULL , [IsMeasured] bit NOT NULL , [IsDerived] bit NOT NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| findings | 1 | 1 | [CandidateId] int NOT NULL,[PlanHandle] varbinary(64) NOT NULL,[FindingOrdinal] bigint NOT NULL , [FindingCode] varchar(100) NOT NULL,[Category] varchar(40) NOT NULL,[Severity] varchar(16) NOT NULL , [Confidence] varchar(32) NOT NULL,[EvidenceLevel] varchar(40) NOT NULL , [StatementOrdinal] int NULL,[StatementId] int NULL,[NodeId] int NULL , [PhysicalOp] nvarchar(128) NULL,[LogicalOp] nvarchar(128) NULL , [MetricName] varchar(80) NULL,[MetricValue] decimal(38,4) NULL,[MetricUnit] nvarchar(40) NULL , [ThresholdValue] decimal(38,4) NULL,[ThresholdSource] varchar(80) NULL,[WorkloadProfile] varchar(32) NOT NULL , [Summary] nvarchar(1000) NOT NULL,[Evidence] nvarchar(2000) NOT NULL,[EvidenceLimit] nvarchar(2000) NOT NULL , [CounterEvidence] nvarchar(1000) NULL,[RecommendedNextCheck] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ShowplanAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_ShowplanAnalysis

Die Procedure wählt eindeutige Planhandles aus und analysiert die verfügbaren Showplan-Dokumente mit USP_ExecutionPlanAnalysis. Planquelle, Kandidatenauswahl und Analysegrenzen werden getrennt gesteuert.

Hilfe anzeigen. EXEC [monitor].[USP_ShowplanAnalysis] @Hilfe=1;

Technische Resultsets lesen. EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @AnalyseModus='GEZIELT', @PlanQuelle='COMPILE', @MaxAnalyseobjekte=5, @MaxDurationSeconds=10, @MaxZeilen=1000, @ResultSetArt='RAW';

Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @JsonErzeugen=1, @ResultSetArt='NONE', @Json=@Json OUTPUT; SELECT @Json AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ShowplanAnalysis
Die Procedure wählt eindeutige Planhandles aus und analysiert die verfügbaren Showplan-Dokumente mit USP_ExecutionPlanAnalysis. Planquelle, Kandidatenauswahl und Analysegrenzen werden getrennt gesteuert.
Hilfe anzeigen. EXEC [monitor].[USP_ShowplanAnalysis] @Hilfe=1;
Technische Resultsets lesen. EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @AnalyseModus='GEZIELT', @PlanQuelle='COMPILE', @MaxAnalyseobjekte=5, @MaxDurationSeconds=10, @MaxZeilen=1000, @ResultSetArt='RAW';
Nur JSON ausgeben. DECLARE @Json nvarchar(max); EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @JsonErzeugen=1, @ResultSetArt='NONE', @Json=@Json OUTPUT; SELECT @Json AS [Json];
Ein Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #ShowplanAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ShowplanAnalysis_HelpExample"}'; SELECT * FROM #ShowplanAnalysis_HelpExample; DROP TABLE #ShowplanAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #ShowplanAnalysis_HelpExample; THROW; END CATCH;
```

