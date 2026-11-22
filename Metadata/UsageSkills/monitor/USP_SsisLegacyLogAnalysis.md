---
skill_format_version: "1.0.0"
name: "monitor.USP_SsisLegacyLogAnalysis"
schema_name: "monitor"
object_name: "USP_SsisLegacyLogAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liest eine explizite Legacy-Loggingquelle für genau eine GUID."
source_path: "Code/10_SSIS/020_USP_SsisLegacyLogAnalysis.sql"
---

# monitor.USP_SsisLegacyLogAnalysis

## Zweck und Einsatz

Liest eine explizite Legacy-Loggingquelle für genau eine GUID.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_SsisLegacyLogAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `sys.all_objects`, `sys.schemas`, `sys.external_tables`, `sys.all_columns`, `sys.sp_executesql`, `sys.index_columns`, `sys.indexes` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @LoggingDatabase | sysname | nein | NULL |
| @LoggingSchema | sysname | nein | N'dbo' |
| @LoggingTable | sysname | nein | N'sysssislog' |
| @ExecutionId | uniqueidentifier | nein | NULL |
| @IncludeTimeline | bit | nein | 1 |
| @IncludeMessages | bit | nein | 1 |
| @HighImpactConfirmed | bit | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
| @MaxDurationSeconds | int | nein | 30 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(4000) | nein | NULL OUTPUT |
| @IncludeTaskAnalysis | bit | nein | 0 |
| @IncludeRowFlowAnalysis | bit | nein | 0 |
| @IncludeComponentPhaseAnalysis | bit | nein | 0 |
| @IncludeComponentLifecyclePhases | bit | nein | 0 |
| @IncludeLookupCacheAnalysis | bit | nein | 0 |
| @IncludeRowsWrittenAnalysis | bit | nein | 0 |
| @IncludeThroughputAnalysis | bit | nein | 0 |
| @IncludeFinalCommitAnalysis | bit | nein | 0 |
| @IncludePipelinePhaseBeginAnalysis | bit | nein | 0 |

**@LoggingDatabase:** @LoggingDatabase sysname; Default: NULL. Im normalen Analysepfad ist die Quelldatenbank ausdrücklich anzugeben; Default NULL ist dafür ungültig. Einzelnes sysname-Datenbanksegment, Punkte werden nicht als mehrteilige Adressierung zerlegt; NULL oder nach LTRIM/RTRIM leer ist ungültig. QUOTENAME quotiert es separat. Wirkung: wählt die explizite Quelldatenbank. Beim Auslassen gilt der deklarierte Default NULL. Als ungeklammerten Unicode-Namen ohne zusätzliche SQL-Identifierklammerung übergeben, zum Beispiel N'dbo' für das Schema; vorhandene Punkte oder Klammerzeichen sind wörtliche Teile dieses einzelnen Segments. sysname bindet höchstens 128 Zeichen und kann längere Textargumente kürzen. Nur die Leerprüfung entfernt äußere U+0020-Leerzeichen; der adressierte Name selbst wird nicht getrimmt.

**@LoggingSchema:** @LoggingSchema sysname; Default: N'dbo'. Auslassen verwendet dbo. Einzelnes sysname-Schemasegment; NULL oder nach LTRIM/RTRIM leer ist ungültig. Separates QUOTENAME. Beim Auslassen gilt der deklarierte Default N'dbo'. Als ungeklammerten Unicode-Namen ohne zusätzliche SQL-Identifierklammerung übergeben, zum Beispiel N'dbo' für das Schema; vorhandene Punkte oder Klammerzeichen sind wörtliche Teile dieses einzelnen Segments. sysname bindet höchstens 128 Zeichen und kann längere Textargumente kürzen. Nur die Leerprüfung entfernt äußere U+0020-Leerzeichen; der adressierte Name selbst wird nicht getrimmt.

**@LoggingTable:** @LoggingTable sysname; Default: N'sysssislog'. Auslassen verwendet sysssislog. Einzelnes sysname-Tabellensegment; NULL oder nach LTRIM/RTRIM leer ist ungültig. Separates QUOTENAME; ändert keinen Provider. Beim Auslassen gilt der deklarierte Default N'sysssislog'. Als ungeklammerten Unicode-Namen ohne zusätzliche SQL-Identifierklammerung übergeben, zum Beispiel N'dbo' für das Schema; vorhandene Punkte oder Klammerzeichen sind wörtliche Teile dieses einzelnen Segments. sysname bindet höchstens 128 Zeichen und kann längere Textargumente kürzen. Nur die Leerprüfung entfernt äußere U+0020-Leerzeichen; der adressierte Name selbst wird nicht getrimmt.

**@ExecutionId:** @ExecutionId uniqueidentifier; Default: NULL. Beim Auslassen ungültig. Erfordert eine Nicht-Null-GUID; NULL und 00000000-0000-0000-0000-000000000000 sind ungültig. Begrenzt die Analyse auf genau diese Ausführung. Beim Auslassen gilt der deklarierte Default NULL. Eingabeform: ein typisierter uniqueidentifier oder eine konvertierbare GUID-Zeichenfolge in der Form 00000000-0000-0000-0000-000000000001; keine Liste.

**@IncludeTimeline:** @IncludeTimeline bit; Default: 1. Auslassen: 1. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Werte: 0 deaktiviert nur den Timeline-Export, 1 aktiviert ihn. NULL wird zu 1. Beim Auslassen gilt der deklarierte Default 1.

**@IncludeMessages:** @IncludeMessages bit; Default: 1. Auslassen: 1. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). 0 schaltet Meldungstextzugriff/-ausgabe ab; textabhängige Opt-in-Ableitungen können nicht verfügbar oder partiell werden, ohne diesen Parameter abzulehnen. 1 schließt Meldungstexte ein; bei message nvarchar(max) nur mit @HighImpactConfirmed=1. NULL wird zu 1. Texte können sensible Werte enthalten. Beim Auslassen gilt der deklarierte Default 1.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Werte: 0 bestätigt nicht, 1 bestätigt die erforderliche Bedingung. NULL wird zu 0. Erforderlich bei @MaxZeilen NULL/0 oder eingeschlossenem message nvarchar(max); keine weitere Freigabe oder Laufzeitgarantie. Beim Auslassen gilt der deklarierte Default 0.

**@MaxZeilen:** @MaxZeilen NULL/0 bedeutet unbegrenzte Ereignissammlung und verlangt @HighImpactConfirmed=1. Eingeschlossenes message nvarchar(max) braucht dieselbe Bestätigung. Zeitbudget kooperativ.

**@MaxDurationSeconds:** @MaxDurationSeconds int; Default: 30. Auslassen: 30. Ganze Zahl 1 bis 60 einschließlich; NULL, 0 und Werte außerhalb sind ungültig. Kooperative Deadline, die an Schritten/Ableitungen geprüft wird; kein harter Abbruch. Beim Auslassen gilt der deklarierte Default 30.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Auslassen: 0. Ganze Zahl 0 bis 60000 Millisekunden einschließlich; NULL/außerhalb ungültig. 0 bedeutet NOWAIT. Wird für Quellzugriffe gesetzt; ursprüngliche Sitzungseinstellung wird vor Ausgabe wiederhergestellt. Eigene lokale Temp-DDL erhält bei geerbtem NOWAIT bis zu 1000 ms je Anlage. Gilt nicht als Timeout für TABLE-Ziele. Beim Auslassen gilt der deklarierte Default 0.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Auslassen: CONSOLE. Der Eingang wird zuerst in varchar(16) gespeichert, danach um äußere U+0020-Leerzeichen gekürzt und mit UPPER normalisiert; verglichen wird unter SQL_Latin1_General_CP1_CS_AS. Gültige Werte: CONSOLE (Übersicht), RAW (native Resultsets), TABLE (benannte Ausgabe), NONE (fachliche Grids unterdrücken). NULL, leer, nur U+0020 oder ein anderer normalisierter Wert ist ungültig. Vorherige Kürzung auf varchar(16) beachten; längere Eingabe ist nicht automatisch ungültig, wenn gespeicherter Wert einem Modus entspricht. Beim Auslassen gilt der deklarierte Default 'CONSOLE'.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Auslassen/NULL ist außerhalb TABLE gültig; dort ist auch leer oder nur U+0020-Leerzeichen erlaubt, nichtleerer Inhalt ungültig. In TABLE: gültiges nichtleeres JSON-Objekt von Resultsetnamen auf Zielnamen. Mindestens ein aktiver Schlüssel ist erforderlich; jede nichtleere Teilmenge der aktiven Basis- und Optionalnamen ist erlaubt; optionale Namen nur bei aktivem Opt-in. Vollständiger Preflight vor fachlichem Quellenzugriff. Ziele: vorhandene leere lokale #Temp-Tabellen mit genau einer Seed-Spalte beliebigen Namens und Typs ohne Seed-Zeile; keine ##Temp oder permanenten Tabellen. Unbekannte/inaktive Schlüssel, binär doppelte Schlüssel, case-insensitiv doppelte Ziele und unzulässige Ziele werden abgelehnt. Preflight wirft; OUTPUT ist nicht zugesichert. Zusätzlich gilt für rowFlowThroughput: @IncludeThroughputAnalysis=1 und zugleich @IncludeRowFlowAnalysis=1, weil beide Flags gemeinsam erforderlich sind. Beim Auslassen gilt der deklarierte Default NULL. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen. Zielnamen müssen Strings mit LEN höchstens 116 sein; #Monitor-Präfix ist case-insensitiv ausgeschlossen. Die Vorprüfung erfolgt nach Hilfe, vor der normalen Parameterprüfung; ein inaktiver optionaler Schlüssel ist auch dann ungültig, wenn die Tabelle existiert.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Werte: 0 erzeugt kein JSON, 1 befüllt @Json. NULL verhält sich wie 0. Beim Auslassen gilt der deklarierte Default 0.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Auslassen: Default NULL. Zur Übernahme OUTPUT-Variable übergeben. Eintritt setzt NULL zurück, auch bei Hilfe; nur mit @JsonErzeugen=1 am Ende befüllt. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Auslassen: 1. Format SQL bit; NULL bleibt als ungenutzter Wert ohne Wirkung. Die Werte 0 und 1 bewirken beide nichts, da der Parameter im Prozedurkörper nicht verwendet wird. Beim Auslassen gilt der deklarierte Default 1.

**@Hilfe:** @Hilfe bit; Default: 0. Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Werte: 0 normaler Pfad, 1 PRINT-Hilfe und RETURN vor TABLE-Vorprüfung sowie normaler Parameter-/Quellvalidierung. NULL wird zu 0. Alle fünf OUTPUTs werden zuerst auf NULL gesetzt und bleiben NULL; normaler SQL-Fehler-/PRINT-Vertrag bleibt unverändert. Beim Auslassen gilt der deklarierte Default 0.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Auslassen: Default NULL. Eintritt setzt NULL; Hilfe lässt NULL. Erreichbare Modulwerte: AVAILABLE = Ausführungseintrag vorhanden, nicht partiell; AVAILABLE_EMPTY = kein Ausführungseintrag, nicht partiell; AVAILABLE_LIMITED = partieller/begrenzter Lauf; INVALID_PARAMETER = ungültige Eingabe oder erforderliche Bestätigung fehlt; SOURCE_UNAVAILABLE = Quelle nicht verfügbar; DENIED = Quellzugriff verweigert; ERROR_HANDLED = behandelter Quellenfehler, geänderte Quellenidentität oder verworfener Puffer. Native SQL-Fehler/THROW können OUTPUT unerreichbar machen. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Auslassen: Default NULL. Eintritt setzt NULL. Normaler Pfad: 0 bedeutet nicht als partiell markiert, 1 partiell/begrenzt oder ungültige Eingabe. Hilfe lässt NULL; SQL-Fehler/THROW können OUTPUT unerreichbar machen. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Auslassen: Default NULL. Eintritt setzt NULL. Normaler Pfad: erfasste Fehlernummer, falls gesetzt, sonst NULL. Hilfe lässt NULL; SQL-Fehler/THROW können OUTPUT unerreichbar machen. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(4000) OUTPUT; Default: NULL. Auslassen: Default NULL. Eintritt setzt NULL. Normaler Pfad: erfasster Fehlertext, falls gesetzt, sonst NULL. Hilfe lässt NULL; SQL-Fehler/THROW können OUTPUT unerreichbar machen. Die Eingabe steuert den Aufruf nicht und wird beim Eintritt verworfen; nur für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. Beim Auslassen gilt der deklarierte Default NULL.

**@IncludeTaskAnalysis:** @IncludeTaskAnalysis ergänzt beobachtete Laufzeiten und Loggingabdeckung: RAW 11 Mengen, SchemaVersion 2; keine Tasktyp-/Konfigurationsbestimmung. Diese Ableitung ist nicht vom Meldungstext abhängig.

**@IncludeRowFlowAnalysis:** @IncludeRowFlowAnalysis ergänzt OnPipelineRowsSent-Pfade: SchemaVersion 3; RAW 11 Mengen oder mit Taskanalyse 13; keine Paketgesamtmenge.

**@IncludeComponentPhaseAnalysis:** @IncludeComponentPhaseAnalysis ergänzt PipelineComponentTime ProcessInput/PrimeOutput-Berichte: SchemaVersion 4 und zwei Mengen; keine CPU- oder exklusive Zeit.

**@IncludeComponentLifecyclePhases:** @IncludeComponentLifecyclePhases bit; Default: 0. Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert Validate/PreExecute/PostExecute-Berichte; NULL wird zu 0. Erfordert @IncludeComponentPhaseAnalysis=1, sonst INVALID_PARAMETER vor Quellenzugriff. Getrennte VALIDATE-/EXECUTE-Kontexte. Beim Auslassen gilt der deklarierte Default 0.

**@IncludeLookupCacheAnalysis:** @IncludeLookupCacheAnalysis ergänzt sechs Lookup-/Cacheprofile als Einzelberichte (SchemaVersion 6); keine Hit-Rate/Gesamtmengenaddition.

**@IncludeRowsWrittenAnalysis:** @IncludeRowsWrittenAnalysis ergänzt einzelne Schreibberichte (SchemaVersion 7); keine Summen/Commitgarantie.

**@IncludeThroughputAnalysis:** @IncludeThroughputAnalysis bit; Default: 0. Auslassen: 0. Format SQL bit (vor dem Prozedurkörper konvertiert: 0 bleibt 0, jeder von 0 verschiedene, SQL-bit-konvertierbare Zahlenwert wird 1). Bei den Optionen gilt: 0 deaktiviert, 1 aktiviert gemeldete Pfadübertragungen je beobachtetem EXECUTE-Intervall; NULL wird zu 0. Fügt rowFlowThroughput hinzu. Erfordert @IncludeRowFlowAnalysis=1, sonst INVALID_PARAMETER vor Quellenzugriff. Beim Auslassen gilt der deklarierte Default 0.

**@IncludeFinalCommitAnalysis:** @IncludeFinalCommitAnalysis ergänzt einzelne Final-Commit-Berichte (SchemaVersion 9); keine Persistenz-/Erfolgsgarantie.

**@IncludePipelinePhaseBeginAnalysis:** @IncludePipelinePhaseBeginAnalysis ergänzt sechs Phasenbeginnprofile (SchemaVersion 10); keine Phasendauer-/Abschlussgarantie.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SchemaVersion] int NOT NULL , [LoggingDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [LoggingSchema] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [LoggingTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ExecutionId] uniqueidentifier NULL , [MessagesIncluded] bit NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [CollectionTimeUtc] datetime2(3) NOT NULL |
| execution | 1 | 1 | [ExecutionId] uniqueidentifier NOT NULL , [AnalyzedEventCount] bigint NOT NULL , [SourceCount] bigint NOT NULL , [FirstObservedTime] datetime NULL , [LastObservedTime] datetime NULL , [ErrorEventCount] bigint NOT NULL , [WarningEventCount] bigint NOT NULL , [TaskFailedEventCount] bigint NOT NULL , [CancelRequestCount] bigint NOT NULL , [BoundaryStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [PackageStartLogId] int NULL , [PackageEndLogId] int NULL , [PackageDurationMs] bigint NULL , [ObservedOutcome] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FirstErrorLogId] int NULL , [FirstErrorMessage] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [IsCompleteSlice] bit NOT NULL |
| timeline | 1 | 1 | [TimelineOrdinal] bigint NOT NULL , [LogId] int NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceId] uniqueidentifier NULL , [EventTime] datetime NULL , [RawEndTime] datetime NULL , [DataCode] int NULL , [PreviousLogId] int NULL , [DeltaFromPreviousMs] bigint NULL , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| errorChain | 1 | 1 | [ErrorOrdinal] bigint NOT NULL , [LogId] int NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceId] uniqueidentifier NULL , [EventTime] datetime NULL , [DataCode] int NULL , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [PreviousRelevantLogId] int NULL , [RelationKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| iterations | 1 | 1 | [IterationOrdinal] bigint NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [SourceId] uniqueidentifier NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PairKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StartLogId] int NULL , [EndLogId] int NULL , [StartTime] datetime NULL , [EndTime] datetime NULL , [DurationMs] bigint NULL , [PairStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SampleIsPartial] bit NOT NULL |
| loggingQuality | 1 | 1 | [QualityOrdinal] int NOT NULL , [QualityCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [AffectedRowCount] bigint NULL , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| findings | 1 | 1 | [FindingOrdinal] int NOT NULL , [FindingCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [LogId] int NULL , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [SourceOrdinal] int NOT NULL , [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ObservedRowCount] bigint NULL , [ReturnedRowCount] bigint NULL , [IsTruncated] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CollectionTimeUtc] datetime2(3) NOT NULL |
| warnings | 1 | 1 | [WarningOrdinal] int NOT NULL , [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| taskDurations | 1 | 1 | [TaskDurationOrdinal] bigint NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [SourceId] uniqueidentifier NOT NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [PairKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [BasisFirstLogId] int NOT NULL , [BasisLastLogId] int NOT NULL , [EvidenceLogIdsJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [PairRowCount] bigint NOT NULL , [ValidPairCount] bigint NOT NULL , [UnknownTimePairCount] bigint NOT NULL , [NonMonotonicPairCount] bigint NOT NULL , [OpenStartCount] bigint NOT NULL , [OpenEndCount] bigint NOT NULL , [AmbiguousBoundaryCount] bigint NOT NULL , [TotalDurationMs] decimal(38,0) NULL , [AverageDurationMs] decimal(38,6) NULL , [MinDurationMs] bigint NULL , [MaxDurationMs] bigint NULL , [SourceNameConflict] bit NOT NULL , [InputIsTruncated] bit NOT NULL , [MetricStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| taskLoggingCoverage | 1 | 1 | [CoverageOrdinal] bigint NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [SourceId] uniqueidentifier NULL , [UnresolvedLogId] int NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [BasisFirstLogId] int NOT NULL , [BasisLastLogId] int NOT NULL , [EvidenceLogIdsJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ObservedEventCount] bigint NOT NULL , [ExecuteStartCount] bigint NOT NULL , [ExecuteEndCount] bigint NOT NULL , [ValidateStartCount] bigint NOT NULL , [ValidateEndCount] bigint NOT NULL , [KnownOtherEventCount] bigint NOT NULL , [UnknownEventNameCount] bigint NOT NULL , [MissingEventNameCount] bigint NOT NULL , [MissingEventTimeCount] bigint NOT NULL , [AmbiguousBoundaryCount] bigint NOT NULL , [UnresolvedBoundaryCount] bigint NOT NULL , [IncompleteBoundaryCount] bigint NOT NULL , [InvalidTimePairCount] bigint NOT NULL , [SourceNameConflict] bit NOT NULL , [InputIsTruncated] bit NOT NULL , [CoverageStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| rowFlowEvents | 1 | 1 | [RowFlowEventOrdinal] bigint NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [LogId] int NOT NULL , [SourceId] uniqueidentifier NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventTime] datetime NULL , [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [PathId] int NULL , [PathName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [DestinationComponentId] int NULL , [DestinationComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [InputId] int NULL , [InputName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RowsSent] bigint NULL , [OccurrenceStartLogId] int NULL , [OccurrenceEndLogId] int NULL , [GroupingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [InputIsTruncated] bit NOT NULL |
| rowFlow | 1 | 1 | [RowFlowOrdinal] bigint NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [SourceId] uniqueidentifier NOT NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [OccurrenceStartLogId] int NOT NULL , [OccurrenceEndLogId] int NOT NULL , [PathId] int NOT NULL , [PathName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [DestinationComponentId] int NOT NULL , [DestinationComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [InputId] int NOT NULL , [InputName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventCount] bigint NOT NULL , [RowsSentSum] decimal(38,0) NOT NULL , [MinRowsSent] bigint NOT NULL , [MaxRowsSent] bigint NOT NULL , [FirstObservedTime] datetime NOT NULL , [LastObservedTime] datetime NOT NULL , [EvidenceLogIdsJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceNameConflict] bit NOT NULL , [PathNameConflict] bit NOT NULL , [DestinationNameConflict] bit NOT NULL , [InputNameConflict] bit NOT NULL , [InputIsTruncated] bit NOT NULL , [CoverageStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| componentPhaseEvents | 1 | 1 | [PhaseEventOrdinal] bigint NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [LogId] int NOT NULL , [SourceId] uniqueidentifier NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventTime] datetime NULL , [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ComponentId] int NULL , [ComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PhaseName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ReportedDurationMs] bigint NULL , [OutputId] int NULL , [OutputName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ContextStartLogId] int NULL , [ContextEndLogId] int NULL , [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [InputIsTruncated] bit NOT NULL |
| componentPhaseTimes | 1 | 1 | [PhaseTimeOrdinal] bigint NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [SourceId] uniqueidentifier NOT NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ContextStartLogId] int NOT NULL , [ContextEndLogId] int NOT NULL , [ComponentId] int NULL , [ComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PhaseName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [OutputId] int NULL , [OutputName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventCount] bigint NOT NULL , [ReportedDurationSumMs] decimal(38,0) NOT NULL , [MinReportedDurationMs] bigint NOT NULL , [MaxReportedDurationMs] bigint NOT NULL , [AvgReportedDurationMs] decimal(38,6) NOT NULL , [FirstObservedTime] datetime NOT NULL , [LastObservedTime] datetime NOT NULL , [EvidenceLogIdsJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceNameConflict] bit NOT NULL , [ComponentNameConflict] bit NOT NULL , [OutputNameConflict] bit NOT NULL , [InputIsTruncated] bit NOT NULL , [CoverageStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| lookupCacheEvents | 1 | 1 | [LookupEventOrdinal] bigint NOT NULL , [LogId] int NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceId] uniqueidentifier NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventTime] datetime NULL , [DataCode] int NULL , [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ObservationKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ReportedRows] bigint NULL , [ReportedProcessingSeconds] decimal(28,3) NULL , [ReportedMemoryBytes] bigint NULL , [DiagnosticCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ContextStartLogId] int NULL , [ContextEndLogId] int NULL , [InputIsTruncated] bit NOT NULL , [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| rowsWrittenEvents | 1 | 1 | [RowsWrittenEventOrdinal] bigint NOT NULL , [LogId] int NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceId] uniqueidentifier NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventTime] datetime NULL , [DataCode] int NULL , [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ObservationKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ReportedRows] bigint NULL , [DiagnosticCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ContextStartLogId] int NULL , [ContextEndLogId] int NULL , [InputIsTruncated] bit NOT NULL , [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| rowFlowThroughput | 1 | 1 | [RowFlowOrdinal] bigint NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [SourceId] uniqueidentifier NOT NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [OccurrenceStartLogId] int NOT NULL , [OccurrenceEndLogId] int NOT NULL , [PathId] int NOT NULL , [PathName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [DestinationComponentId] int NOT NULL , [DestinationComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [InputId] int NOT NULL , [InputName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventCount] bigint NOT NULL , [RowsSentSum] decimal(38,0) NOT NULL , [MinRowsSent] bigint NOT NULL , [MaxRowsSent] bigint NOT NULL , [FirstObservedTime] datetime NOT NULL , [LastObservedTime] datetime NOT NULL , [EvidenceLogIdsJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceNameConflict] bit NOT NULL , [PathNameConflict] bit NOT NULL , [DestinationNameConflict] bit NOT NULL , [InputNameConflict] bit NOT NULL , [InputIsTruncated] bit NOT NULL , [CoverageStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [OccurrenceStartTime] datetime NULL , [OccurrenceEndTime] datetime NULL , [ObservedExecutionDurationMs] bigint NULL , [ReportedTransferRowsPerSecond] decimal(38,6) NULL , [RateStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RateTimeBasis] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| finalCommitEvents | 1 | 1 | [FinalCommitEventOrdinal] bigint NOT NULL , [LogId] int NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceId] uniqueidentifier NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventTime] datetime NULL , [DataCode] int NULL , [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ObservationKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ContextStartLogId] int NULL , [ContextEndLogId] int NULL , [InputIsTruncated] bit NOT NULL , [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| pipelinePhaseBeginEvents | 1 | 1 | [PipelinePhaseBeginEventOrdinal] bigint NOT NULL , [LogId] int NOT NULL , [ExecutionId] uniqueidentifier NOT NULL , [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceId] uniqueidentifier NULL , [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EventTime] datetime NULL , [DataCode] int NULL , [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ObservationKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PhaseName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ContextStartLogId] int NULL , [ContextEndLogId] int NULL , [InputIsTruncated] bit NOT NULL , [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

OnProgress-Zeilen mit exakt übereinstimmendem Ereignisnamen erscheinen als LEGACY_PROGRESS_EVENT mit INFO, RUNTIME_OBSERVED und der ursprünglichen LogId in findings. Die Auswertung benötigt keinen Meldungstext. Sie bestimmt weder einen Fortschrittsprozentsatz noch eine Laufzeitprognose. Fehlende Zeilen belegen keinen Stillstand. Bei aktivierter Taskanalyse zählt die Loggingabdeckung diese Zeilen als bekannte sonstige Ereignisse.

Der exakt gespeicherte Ereignisname OnVariableValueChanged erzeugt einen INFO-Befund LEGACY_VARIABLE_CHANGE_EVENT mit RUNTIME_OBSERVED und der ursprünglichen LogId in findings. Die Auswertung leitet aus der Meldung weder Variablennamen noch alte oder neue Werte ab. Bei aktivierter Taskanalyse zählt das Ereignis in KnownOtherEventCount.

Der exakt gespeicherte Ereignisname OnExecStatusChanged erzeugt einen INFO-Befund LEGACY_EXEC_STATUS_CHANGE_EVENT mit RUNTIME_OBSERVED und der ursprünglichen LogId in findings. Der Ereignisname unterscheidet nicht zwischen Anhalten und Fortsetzen eines Tasks beim Debuggen. Der Befund wertet keinen Meldungstext aus. Bei aktivierter Taskanalyse zählt das Ereignis in KnownOtherEventCount.

Der exakt gespeicherte Ereignisname DiagnosticEx erzeugt einen INFO-Befund LEGACY_DIAGNOSTIC_EX_EVENT mit RUNTIME_OBSERVED und der ursprünglichen LogId in findings. Der Befund wertet keinen Meldungstext aus. Der Ereignisname allein belegt keine Spaltenzuordnung oder vollständige Meldung. Bei aktivierter Taskanalyse zählt das Ereignis in KnownOtherEventCount.

## Beispiel

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Analysiert gespeicherte Legacy-Logereignisse für eine explizite Execution-GUID aus einer ausgewählten Datenbank und vorhandenen sysssislog-kompatiblen Tabelle. Standard ist dbo.sysssislog; keine implizite Datenbankwahl.

Alle Meldungstexte sind standardmäßig eingeschlossen. Zusätzliche Indizes sind keine Voraussetzung; ohne führenden executionid-Index kann ein Scan erfolgen. Die Procedure verändert weder Provider-Tabelle, Indizes noch Protokollierung.

RAW hat neun Basismengen; CONSOLE ist eine Übersicht; TABLE nutzt @ResultTablesJson; NONE unterdrückt fachliche Grids. JSON enthält optional denselben begrenzten Exportstand.

Beispiel Hilfe: EXEC [monitor].[USP_SsisLegacyLogAnalysis] @Hilfe=1;

Beispiel RAW mit synthetischer Quelle/GUID: EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=N'ExampleSsisLogs',@ExecutionId='00000000-0000-0000-0000-000000000001',@IncludeMessages=0,@MaxZeilen=100,@ResultSetArt='RAW';


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_SsisLegacyLogAnalysis
Version      : 1.9.0
Stand        : 2026-10-24
Typ          : Stored Procedure
Zweck        : Liest eine explizite Legacy-Loggingquelle für genau eine GUID.
Grenze       : Keine Quellaktionen; Meldungstexte bleiben Laufzeitausgaben.
```

### Weitere bestehende Hilfehinweise

```text
Analysiert gespeicherte Legacy-Logereignisse für eine explizite Execution-GUID aus einer ausgewählten Datenbank und vorhandenen sysssislog-kompatiblen Tabelle. Standard ist dbo.sysssislog; keine implizite Datenbankwahl.
Alle Meldungstexte sind standardmäßig eingeschlossen. Zusätzliche Indizes sind keine Voraussetzung; ohne führenden executionid-Index kann ein Scan erfolgen. Die Procedure verändert weder Provider-Tabelle, Indizes noch Protokollierung.
RAW hat neun Basismengen; CONSOLE ist eine Übersicht; TABLE nutzt @ResultTablesJson; NONE unterdrückt fachliche Grids. JSON enthält optional denselben begrenzten Exportstand.
Beispiel Hilfe: EXEC [monitor].[USP_SsisLegacyLogAnalysis] @Hilfe=1;
Beispiel RAW mit synthetischer Quelle/GUID: EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=N'ExampleSsisLogs',@ExecutionId='00000000-0000-0000-0000-000000000001',@IncludeMessages=0,@MaxZeilen=100,@ResultSetArt='RAW';
Beispiel JSON: DECLARE @j nvarchar(max); EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=N'ExampleSsisLogs',@ExecutionId='00000000-0000-0000-0000-000000000001',@IncludeMessages=0,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@j OUTPUT; SELECT @j;
```

