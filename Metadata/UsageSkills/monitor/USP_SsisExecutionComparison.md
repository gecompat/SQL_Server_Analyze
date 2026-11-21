---
skill_format_version: "1.0.0"
name: "monitor.USP_SsisExecutionComparison"
schema_name: "monitor"
object_name: "USP_SsisExecutionComparison"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "monitor.USP_SsisExecutionComparison; Version 1.0.0; Stand 2026-10-25."
source_path: "Code/10_SSIS/050_USP_SsisExecutionComparison.sql"
---

# monitor.USP_SsisExecutionComparison

## Zweck und Einsatz

monitor.USP_SsisExecutionComparison; Version 1.0.0; Stand 2026-10-25.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_SsisExecutionComparison]. Die Quelle nennt insbesondere `monitor.USP_SsisPackageModelAnalysis`, `[monitor].[InternalPrepareResultTables]`, `sys.sp_executesql`, `[monitor].[InternalSsisExecutionMetrics]`, `[monitor].[InternalWriteResultTable]`, `[monitor].[InternalEmitConsoleResult]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @BaselineProjectModelsJson | nvarchar(max) | nein | NULL |
| @BaselineScopeSnapshotJson | nvarchar(max) | nein | NULL |
| @BaselineScopeHandoverId | uniqueidentifier | nein | NULL |
| @BaselineExecutionId | bigint | nein | NULL |
| @CandidateProjectModelsJson | nvarchar(max) | nein | NULL |
| @CandidateScopeSnapshotJson | nvarchar(max) | nein | NULL |
| @CandidateScopeHandoverId | uniqueidentifier | nein | NULL |
| @CandidateExecutionId | bigint | nein | NULL |
| @MinDurationDeltaMs | bigint | nein | NULL |
| @MinDurationDeltaPercent | decimal(9,4) | nein | NULL |
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
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@BaselineProjectModelsJson:** @BaselineProjectModelsJson: Datentyp nvarchar(max), Default NULL. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben, nicht als Dateipfad. Erforderlich für die Basis-Seite. JSON-Objekt mit contract="ssis-project-model-set", version="1.0.0", rootPackageKey als String und packages als Array mit 1 bis 16 eindeutigen Paketen. Jedes Paket enthält packageKey und entryName als Strings, model als vollständiges Objekt mit contract="ssis-package-model" und version="1.0.0" sowie identities als Objekt mit contract="ssis-object-identities" und version="1.2.0". Für diesen Consumer müssen zusätzlich pipelineIdentities als Objekt mit contract="ssis-pipeline-identities" und version="1.0.0" vorhanden und an dieselben Paket-/Modellidentitäten gebunden sein. Der gemeinsame Consumer aktiviert Scope-, Pipelinekorrelations- und Pipeline-Diagnosepfade; dieses Argument ergänzt keine eigene Parser- oder Lineageauswertung. Das unveränderte Modellobjekt muss auf allen verglichenen Seiten bytegenau gleich sein: SHA-256 wird über die exakten nvarchar-UTF-16-Bytes gebildet; Neu-Serialisierung, geänderte Whitespace-/Property-Reihenfolge oder andere Bytes ändern den Exporthash. Höchstens 16.777.216 Bytes je Modell, gemessen mit SQL Server DATALENGTH(nvarchar), also UTF-16-Bytes und nicht UTF-8-Dateigröße. JSON-Objektschlüssel und Identitäten werden streng geprüft. NULL, Leerstring und ungültiges JSON sind unzulässig. Siehe den bestehenden SsisPackageModelAnalysis-Vertrag für vollständige Parser-/Modellregeln.

**@BaselineScopeSnapshotJson:** @BaselineScopeSnapshotJson: Datentyp nvarchar(max), Default NULL. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben. Erforderlich ist ein JSON-Objekt mit contract="ssis-execution-scopes", version="1.1.0", method="SSISDB_CURRENT_PROJECT_PIPELINES_V1", gebunden an project-model-set und passende pipelineIdentities; gültige Wurzel-/Ausführungsbindung umfasst execution als Objekt mit executionId, projectId, projectLsn, catalogDatabaseGuid, sourceBindingSha256 und packageFileName; archiveSha256 und modelSetSha256 liegen auf Wurzelebene (SHA-256 der exakten Basis-Model-JSON-Bytes). Enthält observations- und events-Arrays sowie componentPhases- und pathTransfers-Arrays und genau die zwei pipelineSources-Einträge für componentPhases und pathTransfers; deren Statuswerte und Fehlernummern müssen dem Capturevertrag entsprechen. Alle Schlüssel, Namen, Pfade, IDs, Zeit-/Ergebniswerte und Quellgrenzen müssen die von 035–037 geprüften Formen erfüllen; höchstens 50.000 Einträge im Scope-/Pipeline-Capture. Der Transport muss bytegenau dem lokal registrierten Scope-Handover entsprechen; nicht neu serialisieren. Höchstens 16.777.216 Bytes je Capture, gemessen durch DATALENGTH(nvarchar) in SQL-UTF-16-Bytes. NULL, Leerstring und ungültiges JSON sind unzulässig. Vergleichsseiten werden unabhängig attestiert. Optional kann comparisonContext genau ein Objekt mit genau contract="ssis-comparison-context", version="1.0.0" und use32BitRuntime als JSON-Boolean enthalten; fehlt diese Zusatzinformation oder ist sie ungültig, bleibt der Capture nicht automatisch ungebunden, aber der Laufzeitkontext ist unbewiesen. Beide Seiten müssen dieselben exakten Export- und Quell-/Projektversionsfelder einschließlich archiveSha256 aufweisen.

**@BaselineScopeHandoverId:** @BaselineScopeHandoverId: Datentyp uniqueidentifier, Default NULL. Als uniqueidentifier-Parameter im üblichen GUID-Format übergeben. Erforderliche UUID eines lokal in monitor.SsisHandoverReceipt registrierten Scopebelegs der Art 3; die Registrierung bindet die exakten UTF-16-Bytes des zugehörigen ProjectModelsJson und ScopeSnapshotJson und ist zeitlich gültig. Die UUID ist nur der lokale Belegschlüssel, kein JSON-Trustflag und keine selbst behauptete Attestation; eine frei erfundene UUID oder eine UUID einer anderen Belegart genügt nicht. Jede Seite wird unabhängig gegen den zu ihren Dokumentbytes passenden registrierten Beleg geprüft. Die Procedure verlangt keine gesonderte Ungleichheit der GUIDs; die Execution-IDs müssen verschieden sein. NULL ist ungültig. issuedUtc muss höchstens beim Analysebeginn liegen; expiresUtc danach und höchstens 24 Stunden nach issuedUtc. Es gibt keine Mindestgültigkeitsdauer. Als uniqueidentifier-Variable oder konvertierbares GUID-Literal der Form 00000000-0000-0000-0000-000000000000 übergeben; die Null-GUID ersetzt keinen registrierten Beleg.

**@BaselineExecutionId:** @BaselineExecutionId: Datentyp bigint, Default NULL. Einzelne positive SSISDB Execution-ID im Wertebereich 1 bis 9.223.372.036.854.775.807. Muss mit der Basis-Capture-Bindung übereinstimmen und von @CandidateExecutionId verschieden sein. NULL, 0, negative Werte und Duplikat zum Kandidaten sind ungültig. Als bigint-Zahl binden, keine Liste oder Text-Identität.

**@CandidateProjectModelsJson:** @CandidateProjectModelsJson: Datentyp nvarchar(max), Default NULL. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben, nicht als Dateipfad. Erforderlich für die Kandidaten-Seite. JSON-Objekt mit contract="ssis-project-model-set", version="1.0.0", rootPackageKey als String und packages als Array mit 1 bis 16 eindeutigen Paketen. Jedes Paket enthält packageKey und entryName als Strings, model als vollständiges Objekt mit contract="ssis-package-model" und version="1.0.0" sowie identities als Objekt mit contract="ssis-object-identities" und version="1.2.0". Für diesen Consumer müssen zusätzlich pipelineIdentities als Objekt mit contract="ssis-pipeline-identities" und version="1.0.0" vorhanden und an dieselben Paket-/Modellidentitäten gebunden sein. Der gemeinsame Consumer aktiviert Scope-, Pipelinekorrelations- und Pipeline-Diagnosepfade; dieses Argument ergänzt keine eigene Parser- oder Lineageauswertung. Das unveränderte Modellobjekt muss auf allen verglichenen Seiten bytegenau gleich sein: SHA-256 wird über die exakten nvarchar-UTF-16-Bytes gebildet; Neu-Serialisierung, geänderte Whitespace-/Property-Reihenfolge oder andere Bytes ändern den Exporthash. Höchstens 16.777.216 Bytes je Modell, gemessen mit SQL Server DATALENGTH(nvarchar), also UTF-16-Bytes und nicht UTF-8-Dateigröße. JSON-Objektschlüssel und Identitäten werden streng geprüft. NULL, Leerstring und ungültiges JSON sind unzulässig. Siehe den bestehenden SsisPackageModelAnalysis-Vertrag für vollständige Parser-/Modellregeln.

**@CandidateScopeSnapshotJson:** @CandidateScopeSnapshotJson: Datentyp nvarchar(max), Default NULL. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben. Erforderlich ist ein JSON-Objekt mit contract="ssis-execution-scopes", version="1.1.0", method="SSISDB_CURRENT_PROJECT_PIPELINES_V1", gebunden an project-model-set und passende pipelineIdentities; gültige Wurzel-/Ausführungsbindung umfasst execution als Objekt mit executionId, projectId, projectLsn, catalogDatabaseGuid, sourceBindingSha256 und packageFileName; archiveSha256 und modelSetSha256 liegen auf Wurzelebene (SHA-256 der exakten Kandidaten-Model-JSON-Bytes). Enthält observations- und events-Arrays sowie componentPhases- und pathTransfers-Arrays und genau die zwei pipelineSources-Einträge für componentPhases und pathTransfers; deren Statuswerte und Fehlernummern müssen dem Capturevertrag entsprechen. Alle Schlüssel, Namen, Pfade, IDs, Zeit-/Ergebniswerte und Quellgrenzen müssen die von 035–037 geprüften Formen erfüllen; höchstens 50.000 Einträge im Scope-/Pipeline-Capture. Der Transport muss bytegenau dem lokal registrierten Scope-Handover entsprechen; nicht neu serialisieren. Höchstens 16.777.216 Bytes je Capture, gemessen durch DATALENGTH(nvarchar) in SQL-UTF-16-Bytes. NULL, Leerstring und ungültiges JSON sind unzulässig. Vergleichsseiten werden unabhängig attestiert. Optional kann comparisonContext genau ein Objekt mit genau contract="ssis-comparison-context", version="1.0.0" und use32BitRuntime als JSON-Boolean enthalten; fehlt diese Zusatzinformation oder ist sie ungültig, bleibt der Capture nicht automatisch ungebunden, aber der Laufzeitkontext ist unbewiesen. Beide Seiten müssen dieselben exakten Export- und Quell-/Projektversionsfelder einschließlich archiveSha256 aufweisen.

**@CandidateScopeHandoverId:** @CandidateScopeHandoverId: Datentyp uniqueidentifier, Default NULL. Als uniqueidentifier-Parameter im üblichen GUID-Format übergeben. Erforderliche UUID eines lokal in monitor.SsisHandoverReceipt registrierten Scopebelegs der Art 3; die Registrierung bindet die exakten UTF-16-Bytes des zugehörigen ProjectModelsJson und ScopeSnapshotJson und ist zeitlich gültig. Die UUID ist nur der lokale Belegschlüssel, kein JSON-Trustflag und keine selbst behauptete Attestation; eine frei erfundene UUID oder eine UUID einer anderen Belegart genügt nicht. Jede Seite wird unabhängig gegen den zu ihren Dokumentbytes passenden registrierten Beleg geprüft. Die Procedure verlangt keine gesonderte Ungleichheit der GUIDs; die Execution-IDs müssen verschieden sein. NULL ist ungültig. issuedUtc muss höchstens beim Analysebeginn liegen; expiresUtc danach und höchstens 24 Stunden nach issuedUtc. Es gibt keine Mindestgültigkeitsdauer. Als uniqueidentifier-Variable oder konvertierbares GUID-Literal der Form 00000000-0000-0000-0000-000000000000 übergeben; die Null-GUID ersetzt keinen registrierten Beleg.

**@CandidateExecutionId:** @CandidateExecutionId: Datentyp bigint, Default NULL. Einzelne positive SSISDB Execution-ID im bigint-Bereich 1 bis 9.223.372.036.854.775.807. Muss zum Kandidaten-Capture passen und von @BaselineExecutionId verschieden sein. NULL, 0, negative Werte oder gleiche ID wie die Basis sind ungültig.

**@MinDurationDeltaMs:** @MinDurationDeltaMs: Datentyp bigint, Default NULL. Optionale nichtnegative Dauergrenze in Millisekunden (ganzzahlig, 0 bis 9.223.372.036.854.775.807). NULL deaktiviert diese Grenze; 0 lässt nur positive Daueränderungen über 0 passieren. Ein Dauerhinweis entsteht nur bei vergleichbarer bekannter Dauer und wenn die Kandidatenänderung strikt größer als jede gesetzte Grenze ist. Sind beide Grenzen gesetzt, müssen beide überschritten sein. Zeilen- und Statusänderungshinweise sind von dieser Dauerschwelle unabhängig. Negative Werte sind ungültig. Sind beide Dauergrenzen NULL, werden keine Dauergrenzhinweise erzeugt; andere Hinweisarten bleiben davon unabhängig.

**@MinDurationDeltaPercent:** @MinDurationDeltaPercent: Datentyp decimal(9,4), Default NULL. Optionale nichtnegative Prozentgrenze als Zahl in Prozent relativer Zunahme ohne %-Zeichen, mit höchstens vier Dezimalstellen und Präzision 9: 0.0000 bis 99999.9999 (z. B. 10.0000 bedeutet zehn Prozent; SQL-Typkonvertierung/Rundung erfolgt vor Eintritt in die Procedure). NULL deaktiviert die Prozentgrenze. Maßgeblich ist eine strikt größere relative Zunahme; bei Basisdauer 0 bleibt die Prozentänderung unbekannt und erfüllt die Grenze nicht. Bei zwei gesetzten Dauerschwellen müssen beide strikt überschritten sein. Negative Werte sind ungültig. Sind beide Dauergrenzen NULL, werden keine Dauergrenzhinweise erzeugt; andere Hinweisarten bleiben davon unabhängig.

**@MaxZeilen:** @MaxZeilen: Datentyp int, Default 1000. Maximale ausgegebene Zeilen je Resultgruppe, als int-Zahl. Positive Werte 1 bis 2.147.483.647 begrenzen JSON-, RAW-, TABLE- und Console-Ausgabe; darüber hinaus vorhandene Zeilen werden abgeschnitten und die Ausgabe bleibt partiell. NULL und 0 werden intern als unbegrenzte int-Obergrenze behandelt. Negative Werte sind ungültig.

**@MaxDurationSeconds:** @MaxDurationSeconds: Datentyp int, Default 30. Gemeinsames kooperatives Gesamtzeitbudget für beide Seiten und nachfolgende Vergleichsschritte, in Sekunden. Zulässig sind 1 bis 60. Ausgelassen ergibt 30; explizites NULL ist trotz internem COALESCE ungültig. Bei Fristüberschreitung wird die Bindung als nicht belegt ausgegeben und ein Zeitlimitgrund gemeldet.

**@LockTimeoutMs:** @LockTimeoutMs: Datentyp int; einzelner skalarer SQL-int-Wert in Millisekunden. Default 0; ausgelassen ergibt 0. NULL oder Werte außerhalb 0 bis 60000 sind ungültig; Leertext kann vor Eintritt durch implizite SQL-Konvertierung zu 0 werden. Der SQL-Wert 0 bedeutet NOWAIT, positive Werte erlauben begrenztes Warten und -1 für unbegrenztes Warten ist unzulässig. Die Procedure prüft den Bereich und übergibt den Wert für jede Captureanalyse an InternalSsisExecutionMetrics. Ihr eigenes SET LOCK_TIMEOUT läuft in einem separaten dynamischen sp_executesql-Batch; es begrenzt daher nicht die anschließenden direkten Vergleichs- und Ausgabeanweisungen. InternalSsisExecutionMetrics führt ebenfalls ein dynamisches SET aus und übergibt den Wert an USP_SsisPackageModelAnalysis im Scope-Modus. Dieser delegiert an InternalSsisExecutionScopes, das den Wert validiert und SET LOCK_TIMEOUT ebenfalls dynamisch ausführt; diese Einstellung begrenzt die anschließenden direkten Anweisungen des Scopes-Helpers nicht.

**@ResultSetArt:** @ResultSetArt: Datentyp varchar(16), Default CONSOLE. Ein Auswahlcode als Text; Rand-Leerzeichen werden entfernt und die Prüfung normalisiert auf Großbuchstaben. Geschlossene Wertemenge: CONSOLE (kompakte Console-Ausgabe des Binding-Resultsets), RAW (separates Resultset je aktivierter Gruppe mit Rohspalten), TABLE (schreibt ausgewählte Gruppen in lokale Seed-Temp-Tabellen), NONE (keine Resultsets/Consoleausgabe). NULL oder jeder andere Wert ist ungültig. Leerwert ist ungültig; das Trim entfernt U+0020-Leerzeichen, keine beliebigen Whitespacezeichen. JSON ist kein Ausgabeartcode; verwenden Sie @JsonErzeugen.

**@ResultTablesJson:** @ResultTablesJson: Datentyp nvarchar(max), Default NULL. Nur bei ResultSetArt=TABLE zulässig und dann erforderlich: nichtleeres JSON-Objekt aus case-sensitiven Gruppennamen auf Stringwerte lokaler Temp-Tabellennamen, z. B. {"comparisonBinding":"#SeedBinding"}. Erlaubte Gruppenschlüssel samt Bedeutung: comparisonBinding (ein Bindungs-/Statusdatensatz), objectComparison (Objekt-/Kennzahlzuordnung und beobachtete Werte/Deltas), comparisonFindings (versionierte INFO-Beobachtungshinweise), comparisonCoverage (Quell-, Vergleichs- und Ausgabedeckung). Jede beliebige nichtleere Teilmenge dieser vier Gruppen ist zulässig. Ziele müssen unterschiedliche, bereits vorhandene, leere lokale #Temp-Tabellen (keine ##, kein reserviertes #Monitor-Präfix, maximal 116 Zeichen) mit genau einer Seed-Spalte sein; unbekannte oder doppelte Schlüssel/Ziele, JSON-Null, Leerwerte, ungültige Ziele und leeres Objekt werden abgewiesen. Für CONSOLE/RAW/NONE muss der Parameter NULL sein. Keine zusätzliche Eingabegrößengrenze im Consumer belegt. Doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft.

**@JsonErzeugen:** @JsonErzeugen: Datentyp bit, Default 0. Schalter: 0 erzeugt keinen JSON-OUTPUT-Vertrag; 1 erzeugt @Json als JSON-Objekt. NULL ist im normalen Aufruf ungültig. SQL-bit-Konvertierungen sind vor der Procedure wirksam. Das JSON enthält meta mit schemaVersion=1, comparisonSchemaVersion=1, isPartial=true sowie die aktivierten/ausgegebenen Arraygruppen comparisonBinding, objectComparison, comparisonFindings und comparisonCoverage. Meta enthält im aktuellen SQL kein statusCode; der Status steht in @StatusCodeOut und in Binding-/Coverage-Daten. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Json:** @Json: Datentyp nvarchar(max) OUTPUT, Default NULL OUTPUT. OUTPUT-Textvariable vom Typ nvarchar(max), am Aufruf mit OUTPUT zu binden, wenn das JSON empfangen werden soll. Beim Eintritt wird der Parameter auf NULL gesetzt; mit @JsonErzeugen=1 wird ein JSON-Objekt mit meta und Gruppenarrays (inklusive JSON-null-Werten, nicht als JSON-Zeichenketten eingebettete Arrays) ausgegeben. Jede Gruppenproperty ist ein Array, auch bei null Zeilen: []. Ohne JSON-Erzeugung bleibt NULL. Im Hilfezweig bleibt der beim Einstieg gesetzte NULL-Wert.

**@PrintMeldungen:** @PrintMeldungen: Datentyp bit, Default 1. Im Quelltext nicht gelesen oder geprüft; 0, 1 und NULL haben keine unterschiedliche Wirkung. NULL wird nicht als ungültig abgewiesen. Keine Ausgabeunterdrückung darüber dokumentieren; Consoleausgabe wird durch @ResultSetArt gesteuert. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Hilfe:** @Hilfe: Datentyp bit, Default 0. Schalter für den reinen Hilfezweig: 1 druckt die eingebauten PRINT-Hinweise und kehrt vor Parametervalidierung, Capture-/Handoverprüfung und fachlicher Analyse zurück. 0 führt den normalen Pfad aus. NULL erfüllt IF @Hilfe=1 nicht und verhält sich wie kein Hilfeaufruf. SQL-bit-Konvertierungen gelten vor dem Eintritt. @Json wird zuvor auf NULL gesetzt; die übrigen OUTPUT-Parameter werden im Hilfezweig nicht neu initialisiert/zugewiesen. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@StatusCodeOut:** @StatusCodeOut: Datentyp varchar(40) OUTPUT, Default NULL OUTPUT. Als varchar(40)-Variable mit OUTPUT binden; der Eingabewert steuert die Analyse nicht. Geschlossene globale Rückgabemenge: COMPARISON_CAPTURE_BOUND (beide Seiten unabhängig gebunden, exakt gleicher Export sowie gleiche geprüfte Quell-/Projektversion; Aussage bleibt beobachtungs- und kontextbegrenzt), COMPARISON_BINDING_UNPROVEN (Bindung oder Eingabeverarbeitung nicht belegt) und INVALID_PARAMETER (ungültige Steuerwerte/-kombination). Im aktuellen JSON meta gibt es kein statusCode-Feld; der Laufstatus ist hier sowie in den Bindungs-/Coverage-Daten. Im Hilfezweig unverändert. Eine ungefangene Ausnahme kann Zuweisung umgehen.

**@IsPartialOut:** @IsPartialOut: Datentyp bit OUTPUT, Default NULL OUTPUT. Mit bit-Variable und OUTPUT binden. Bei normalem Abschluss wird stets 1 ausgegeben, auch bei gebundener Eingabe, weil Auswertung und Datenabdeckung partiell sind; Vorabschneidung/Limit wird zusätzlich in Coverage kenntlich. Im Hilfezweig bleibt der übergebene Eingangswert unverändert; ungefangene Fehler können die Zuweisung umgehen.

**@ErrorNumberOut:** @ErrorNumberOut: Datentyp int OUTPUT, Default NULL OUTPUT. Mit int-Variable und OUTPUT binden. NULL bedeutet, dass kein abgefangener fachlicher Eingabefehler protokolliert wurde; bei abgefangener Validierungs-/Bindungs-/Zeitgrenze wird die SQL-Fehlernummer ausgegeben. Vorzeitige/ungefangene Fehler, insbesondere geworfene TABLE-Mappingfehler, können die OUTPUT-Zuweisung umgehen. Im Hilfezweig unverändert.

**@ErrorMessageOut:** @ErrorMessageOut: Datentyp nvarchar(2048) OUTPUT, Default NULL OUTPUT. Mit nvarchar(2048)-Variable und OUTPUT binden. Enthält bei abgefangenem Fehler den knappen Reason-/Fehlercode (kein frei formulierter Eingabetext), sonst NULL. Im Hilfezweig unverändert; ungefangene Ausnahmen können die Zuweisung umgehen. nvarchar(2048) umfasst höchstens 2048 UTF-16-Codeeinheiten.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| comparisonBinding | 1 | 1 | [BaselineExecutionId] bigint NULL,[CandidateExecutionId] bigint NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CandidateStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [BaselineProjectLsn] bigint NULL,[CandidateProjectLsn] bigint NULL,[BaselineArchiveSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CandidateArchiveSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ModelExportMatch] bit NOT NULL,[BaselineLoggingLevel] int NULL,[CandidateLoggingLevel] int NULL,[BaselineUse32BitRuntime] bit NULL,[CandidateUse32BitRuntime] bit NULL, [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WorkloadEquivalence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[ErrorNumber] int NULL |
| objectComparison | 1 | 1 | [ComparisonKeySha256] binary(32) NOT NULL,[ObjectKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PhaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PortRole] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Unit] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [BaselineValue] decimal(38,0) NULL,[CandidateValue] decimal(38,0) NULL,[DeltaValue] decimal(38,0) NULL,[DeltaPercent] decimal(38,6) NULL, [ComparisonStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [BaselineSourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineSourceId] bigint NULL,[CandidateSourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CandidateSourceId] bigint NULL, [BaselineMatchCount] int NOT NULL,[CandidateMatchCount] int NOT NULL,[IsPartial] bit NOT NULL |
| comparisonFindings | 1 | 1 | [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RuleVersion] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ComparisonKeySha256] binary(32) NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[BaselineSourceId] bigint NULL,[CandidateSourceId] bigint NULL, [ObservedDelta] decimal(38,0) NULL,[ThresholdMs] bigint NULL,[ThresholdPercent] decimal(9,4) NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL |
| comparisonCoverage | 1 | 1 | [Scope] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceRowCount] int NOT NULL,[MappedRowCount] int NOT NULL,[UnassignedRowCount] int NOT NULL,[UnknownValueCount] int NOT NULL, [PairedMetricCount] int NOT NULL,[BaselineOnlyCount] int NOT NULL,[CandidateOnlyCount] int NOT NULL,[AmbiguousMetricCount] int NOT NULL,[NotComparableMetricCount] int NOT NULL, [OutputTruncated] bit NOT NULL,[IsPartial] bit NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_SsisExecutionComparison] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_SsisExecutionComparison vergleicht unabhängig gebundene Beobachtungen; kein Paket-, Datei-, SSISDB- oder Paket-SQL-Aufruf.

Ausgelassene Argumente verwenden den bezeichneten Default. SQL-JSON-Text als nvarchar(max)-Variable oder N-präfigiertes T-SQL-Literal übergeben. Pflichtdaten werden erst im normalen Pfad geprüft; Typkonvertierungen erfolgen bereits vor Eintritt. OUTPUT muss zum Empfang auch am Aufruf angegeben sein. Alle Ergebnisse bleiben beobachtungsbezogen und partiell.

Vier reine Hilfeaufrufe ohne Captureprüfung:

DECLARE @HelpJson nvarchar(max)=N'vorbelegt';

DECLARE @Code varchar(40)='CALLER', @Partial bit=0, @Error int=0;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
monitor.USP_SsisExecutionComparison; Version 1.0.0; Stand 2026-10-25.
   Vergleicht genau zwei unabhängig gebundene Captures desselben Exports.
   Modellvalidierung, Scopeauflösung und Kennzahlen bleiben bei den bestehenden
   Consumern. Es erfolgen weder SSISDB-Reads noch Paket-/SQL-Ausführung oder CLR.
   Pfade bezeichnen beobachtete Positionen; Arbeitslastgleichheit bleibt unbelegt.
   Zwei 16-MiB-Modelle und zwei 16-MiB-Captures, je 50000 Quellbelege, höchstens
   200000 Kennzahlen je Seite und ein gemeinsames kooperatives Zeitbudget.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_SsisExecutionComparison vergleicht unabhängig gebundene Beobachtungen; kein Paket-, Datei-, SSISDB- oder Paket-SQL-Aufruf.
Ausgelassene Argumente verwenden den bezeichneten Default. SQL-JSON-Text als nvarchar(max)-Variable oder N-präfigiertes T-SQL-Literal übergeben. Pflichtdaten werden erst im normalen Pfad geprüft; Typkonvertierungen erfolgen bereits vor Eintritt. OUTPUT muss zum Empfang auch am Aufruf angegeben sein. Alle Ergebnisse bleiben beobachtungsbezogen und partiell.
Vier reine Hilfeaufrufe ohne Captureprüfung:
DECLARE @HelpJson nvarchar(max)=N'vorbelegt';
DECLARE @Code varchar(40)='CALLER', @Partial bit=0, @Error int=0;
```

