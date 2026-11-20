---
skill_format_version: "1.0.0"
name: "monitor.USP_SsisExecutionBaseline"
schema_name: "monitor"
object_name: "USP_SsisExecutionBaseline"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "monitor.USP_SsisExecutionBaseline; Version 1.0.0; Stand 2026-10-26."
source_path: "Code/10_SSIS/060_USP_SsisExecutionBaseline.sql"
---

# monitor.USP_SsisExecutionBaseline

## Zweck und Einsatz

monitor.USP_SsisExecutionBaseline; Version 1.0.0; Stand 2026-10-26.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_SsisExecutionBaseline]. Die Quelle nennt insbesondere `monitor.USP_SsisPackageModelAnalysis`, `[monitor].[InternalPrepareResultTables]`, `sys.sp_executesql`, `[monitor].[InternalSsisExecutionMetrics]`, `[monitor].[InternalWriteResultTable]`, `[monitor].[InternalEmitConsoleResult]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @BaselineExecutionsJson | nvarchar(max) | nein | NULL |
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

**@BaselineExecutionsJson:** @BaselineExecutionsJson: Datentyp nvarchar(max), Default NULL. Äußeres JSON muss ein Array mit 1 bis 20 Einträgen sein. Jeder Eintrag ist ein JSON-Objekt mit genau vier case-sensitiven Schlüsseln; jeder der vier Werte ist ein JSON-String, nicht ein eingebettetes Objekt/Array: projectModelsJson (als String serialisierte vollständige Model-Set-JSON), scopeSnapshotJson (als String serialisiertes Scope-/Pipeline-Capture-JSON), scopeHandoverId (GUID-String zur lokal registrierten Handover-ID), executionId (positive kanonische Dezimalzeichenfolge). Die vier Namen sind vollständig, ohne Zusatzschlüssel; ihre Reihenfolge ist beliebig. Die beiden inneren JSON-Dokumente bleiben in ihren Stringwerten byte-/textgetreu erhalten. Jede Basisausführung wird anhand ihres Captures und des auf monitor.USP_SsisPackageModelAnalysis registrierten, dazu passenden lokalen Handover-Belegs unabhängig geprüft. executionId muss kanonisch dezimal sein: keine führenden Nullen, kein Pluszeichen, keine Leerzeichen, positive Ziffernfolge bis 9223372036854775807. Jeder Execution-ID-Wert muss von Kandidaten-ID und allen anderen Basis-IDs verschieden sein. Modelle/Captures sind gültiges JSON, pro Modell und Capture höchstens 16.777.216 DATALENGTH-Bytes (SQL-UTF-16). Gesamte Eingabegrenze: Summe DATALENGTH von BaselineExecutionsJson, CandidateProjectModelsJson und CandidateScopeSnapshotJson höchstens 67.108.864 Bytes (64 MiB, nvarchar UTF-16 Bytes, keine UTF-8-Dateigröße). Zusammengenommen höchstens 100.000 observations/events/componentPhases/pathTransfers-Quellzeilen, 400.000 materialisierte Kennzahlen und höchstens 400.000 Kennzahl-/Laufzellen; gemeinsames kooperatives Zeitbudget höchstens 60 Sekunden. NULL, Leerstring, Objekt statt äußerem Array, 0 oder mehr als 20 Einträge sowie falsche Transporttypen sind ungültig. projectModelsJson enthält ssis-project-model-set 1.0.0 mit rootPackageKey und packages (1 bis 16), einschließlich ssis-object-identities 1.2.0 und ssis-pipeline-identities 1.0.0; scopeSnapshotJson enthält ssis-execution-scopes 1.1.0 mit method SSISDB_CURRENT_PROJECT_PIPELINES_V1. Diese inneren Dokumente werden im äußeren JSON als korrekt maskierte JSON-Strings erhalten, nicht neu erzeugt oder als JSON-Objekte eingebettet. Der GUID-Beleg liegt auf dem Modellconsumer, nicht auf der Baselineprocedure. Einzelheiten entsprechen den separat erläuterten Kandidatenparametern und dem Modellvertrag.

**@CandidateProjectModelsJson:** @CandidateProjectModelsJson: Datentyp nvarchar(max), Default NULL. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben, nicht als Dateipfad. Erforderlich für die Kandidat-Seite. JSON-Objekt mit contract="ssis-project-model-set", version="1.0.0", rootPackageKey als String und packages als Array mit 1 bis 16 eindeutigen Paketen. Jedes Paket enthält packageKey und entryName als Strings, model als vollständiges Objekt mit contract="ssis-package-model" und version="1.0.0" sowie identities als Objekt mit contract="ssis-object-identities" und version="1.2.0". Für diesen Consumer müssen zusätzlich pipelineIdentities als Objekt mit contract="ssis-pipeline-identities" und version="1.0.0" vorhanden und an dieselben Paket-/Modellidentitäten gebunden sein. Der gemeinsame Consumer aktiviert Scope-, Pipelinekorrelations- und Pipeline-Diagnosepfade; dieses Argument ergänzt keine eigene Parser- oder Lineageauswertung. Das unveränderte Modellobjekt muss auf allen verglichenen Seiten bytegenau gleich sein: SHA-256 wird über die exakten nvarchar-UTF-16-Bytes gebildet; Neu-Serialisierung, geänderte Whitespace-/Property-Reihenfolge oder andere Bytes ändern den Exporthash. Höchstens 16.777.216 Bytes je Modell, gemessen mit SQL Server DATALENGTH(nvarchar), also UTF-16-Bytes und nicht UTF-8-Dateigröße. JSON-Objektschlüssel und Identitäten werden streng geprüft. NULL, Leerstring und ungültiges JSON sind unzulässig. Siehe den bestehenden SsisPackageModelAnalysis-Vertrag für vollständige Parser-/Modellregeln.

**@CandidateScopeSnapshotJson:** @CandidateScopeSnapshotJson: Datentyp nvarchar(max), Default NULL. Als einzelne nvarchar(max)-Variable oder N'…'-Literal übergeben. Erforderlich ist ein JSON-Objekt mit contract="ssis-execution-scopes", version="1.1.0", method="SSISDB_CURRENT_PROJECT_PIPELINES_V1", gebunden an project-model-set und passende pipelineIdentities; gültige Wurzel-/Ausführungsbindung umfasst execution als Objekt mit executionId, projectId, projectLsn, catalogDatabaseGuid, sourceBindingSha256 und packageFileName; archiveSha256 und modelSetSha256 liegen auf Wurzelebene (SHA-256 der exakten Kandidaten-Model-JSON-Bytes). Enthält observations- und events-Arrays sowie componentPhases- und pathTransfers-Arrays und genau die zwei pipelineSources-Einträge für componentPhases und pathTransfers; deren Statuswerte und Fehlernummern müssen dem Capturevertrag entsprechen. Alle Schlüssel, Namen, Pfade, IDs, Zeit-/Ergebniswerte und Quellgrenzen müssen die von 035–037 geprüften Formen erfüllen; höchstens 50.000 Einträge im Scope-/Pipeline-Capture. Der Transport muss bytegenau dem lokal registrierten Scope-Handover entsprechen; nicht neu serialisieren. Höchstens 16.777.216 Bytes je Capture, gemessen durch DATALENGTH(nvarchar) in SQL-UTF-16-Bytes. NULL, Leerstring und ungültiges JSON sind unzulässig. Vergleichsseiten werden unabhängig attestiert. Optional kann comparisonContext genau ein Objekt mit genau contract="ssis-comparison-context", version="1.0.0" und use32BitRuntime als JSON-Boolean enthalten; fehlt diese Zusatzinformation oder ist sie ungültig, bleibt der Capture nicht automatisch ungebunden, aber der Laufzeitkontext ist unbewiesen. Beide Seiten müssen dieselben exakten Export- und Quell-/Projektversionsfelder einschließlich archiveSha256 aufweisen.

**@CandidateScopeHandoverId:** @CandidateScopeHandoverId: Datentyp uniqueidentifier, Default NULL. Als uniqueidentifier-Parameter im üblichen GUID-Format übergeben. Erforderliche UUID eines lokal auf monitor.USP_SsisPackageModelAnalysis registrierten SSIS_SCOPE_<UUID> Extended-Property-Handover; die Registrierung bindet die exakten UTF-16-Bytes des zugehörigen ProjectModelsJson und ScopeSnapshotJson und ist zeitlich gültig. Die UUID ist nur der lokale Belegschlüssel, kein JSON-Trustflag und keine selbst behauptete Attestation; eine frei erfundene oder auf einem anderen Objekt registrierte ID genügt nicht. Jede Seite wird unabhängig gegen den zu ihren Dokumentbytes passenden registrierten Beleg geprüft. Die Procedure verlangt keine gesonderte Ungleichheit der GUIDs; die Execution-IDs müssen verschieden sein. NULL ist ungültig. Der Belegname verwendet die GUID in Kleinschreibung. issuedUtc muss höchstens beim Analysebeginn liegen; expiresUtc danach und höchstens 24 Stunden nach issuedUtc. Es gibt keine Mindestgültigkeitsdauer. Als uniqueidentifier-Variable oder konvertierbares GUID-Literal der Form 00000000-0000-0000-0000-000000000000 übergeben; die Null-GUID ersetzt keinen registrierten Beleg.

**@CandidateExecutionId:** @CandidateExecutionId: Datentyp bigint, Default NULL. Einzelne positive SSISDB Execution-ID im bigint-Bereich 1 bis 9.223.372.036.854.775.807. Muss zum Kandidaten-Capture passen und von sämtlichen Basis-Execution-IDs verschieden sein. NULL, 0, negative Werte oder jede Wiederholung einer Basis-ID sind ungültig.

**@MinDurationDeltaMs:** @MinDurationDeltaMs: Datentyp bigint, Default NULL. Optionale nichtnegative Dauergrenze in Millisekunden (ganzzahlig, 0 bis 9.223.372.036.854.775.807). NULL deaktiviert die Dauergrenze. Für einen Dauerhinweis muss die Kandidatendauer strikt größer als Median der verwendbaren Basiswerte plus dieser Grenzwert sein; bei gesetzter Prozentgrenze muss zugleich auch diese strikt überschritten sein. Zeilenänderungshinweise sind unabhängig von beiden Dauergrenzen. Negative Werte sind ungültig. Sind beide Dauergrenzen NULL, werden keine Dauergrenzhinweise erzeugt; andere Hinweisarten bleiben davon unabhängig.

**@MinDurationDeltaPercent:** @MinDurationDeltaPercent: Datentyp decimal(9,4), Default NULL. Optionale nichtnegative Prozentgrenze als Zahl in Prozent relativer Zunahme ohne %-Zeichen, bis vier Dezimalstellen: 0.0000 bis 99999.9999 (10.0000 entspricht zehn Prozent; SQL-Typkonvertierung/Rundung geschieht vor Procedure). NULL deaktiviert die Prozentgrenze. Die relative Dauerabweichung wird strikt geprüft; Median 0 bedeutet unbekannte Prozentabweichung und erfüllt sie nicht. Wenn zusätzlich Millisekunden gesetzt sind, müssen beide Dauergrenzen überschritten sein. Zeilenänderungshinweise bleiben unabhängig. Sind beide Dauergrenzen NULL, werden keine Dauergrenzhinweise erzeugt; andere Hinweisarten bleiben davon unabhängig.

**@MaxZeilen:** @MaxZeilen: Datentyp int, Default 1000. Maximale ausgegebene Zeilen je Resultgruppe, int. Zulässig sind positive Werte; NULL und 0 werden als unbegrenzte int-Obergrenze behandelt. Negative Werte sind ungültig. Die Grenze begrenzt Ausgabe, nicht die Kohorten-/Materialisierungslimits; abgeschnittene Ausgabe bleibt als partiell markiert. Der positive Wertebereich beträgt 1 bis 2147483647.

**@MaxDurationSeconds:** @MaxDurationSeconds: Datentyp int, Default 30. Gemeinsames kooperatives Zeitbudget für alle Basisläufe, Kandidat und Zusammenfassung, Sekunden; 1 bis 60. Ausgelassen bedeutet 30; explizites NULL ist ungültig. Bei überschrittener Frist wird keine Bindung behauptet und ein Zeitlimitgrund ausgegeben.

**@LockTimeoutMs:** @LockTimeoutMs: Datentyp int; einzelner skalarer SQL-int-Wert in Millisekunden. Default 0; ausgelassen ergibt 0. NULL oder Werte außerhalb 0 bis 60000 sind ungültig; Leertext kann vor Eintritt durch implizite SQL-Konvertierung zu 0 werden. Der SQL-Wert 0 bedeutet NOWAIT, positive Werte erlauben begrenztes Warten und -1 für unbegrenztes Warten ist unzulässig. Die Procedure prüft den Bereich und übergibt den Wert für jede Captureanalyse an InternalSsisExecutionMetrics. Ihr eigenes SET LOCK_TIMEOUT läuft in einem separaten dynamischen sp_executesql-Batch; es begrenzt daher nicht die anschließenden direkten Kohorten- und Ausgabeanweisungen. InternalSsisExecutionMetrics führt ebenfalls ein dynamisches SET aus und übergibt den Wert an USP_SsisPackageModelAnalysis im Scope-Modus. Dieser delegiert an InternalSsisExecutionScopes, das den Wert validiert und SET LOCK_TIMEOUT ebenfalls dynamisch ausführt; diese Einstellung begrenzt die anschließenden direkten Anweisungen des Scopes-Helpers nicht.

**@ResultSetArt:** @ResultSetArt: Datentyp varchar(16), Default CONSOLE. Textauswahl nach Entfernen äußerer Leerzeichen und Großschreibung. Geschlossene Menge: CONSOLE (kompakte Bindingausgabe), RAW (separate rohe Resultsets), TABLE (in lokale Zieltabellen schreiben), NONE (keine Resultsets). NULL/andere Werte sind ungültig. Leerwert ist ungültig; das Trim entfernt U+0020-Leerzeichen, keine beliebigen Whitespacezeichen. JSON ist kein Ausgabeartcode; verwenden Sie @JsonErzeugen.

**@ResultTablesJson:** @ResultTablesJson: Datentyp nvarchar(max), Default NULL. Nur bei TABLE zulässig und erforderlich: nichtleeres JSON-Objekt aus case-sensitiven Gruppennamen auf lokale Temp-Tabellennamen als Stringwerte, z. B. {"baselineBinding":"#SeedBinding"}. Zulässige Gruppen: baselineBinding (Kandidaten-/Kohortenbindung und Status), executionCohort (eine Zeile pro Basis-/Kandidatenlauf mit Rolle und Laufabdeckung), metricBaseline (Kennzahl je Vergleichsschlüssel mit Median/Min/Max, gültiger Basiszahl und Kandidatendelta), baselineFindings (versionierte INFO-Beobachtungshinweise), baselineCoverage (Quell-, Lauf-, Einschluss-/Ausschluss- und Ausgabedeckung). Jede beliebige nichtleere Teilmenge der fünf Gruppen ist zulässig. Jedes Ziel muss eine eindeutige bereits vorhandene, leere lokale #Temp-Tabelle sein (keine globale ##, kein reserviertes #Monitor-Präfix, höchstens 116 Zeichen) mit genau einer Seed-Spalte. Unbekannte Schlüssel, doppelte Namen/Ziele, Null-/Leerwerte oder ungültige Ziele werden vor fachlicher Verarbeitung abgewiesen. Außerhalb TABLE muss NULL übergeben werden. Keine gesonderte JSON-Größengrenze im Consumer belegt. Doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft.

**@JsonErzeugen:** @JsonErzeugen: Datentyp bit, Default 0. 0 deaktiviert JSON-OUTPUT, 1 erzeugt ein JSON-Objekt in @Json; NULL ist im normalen Pfad ungültig. JSON hat meta.schemaVersion=1, meta.baselineSchemaVersion=1 und meta.isPartial=true sowie top-level Arrays baselineBinding, executionCohort, metricBaseline, baselineFindings, baselineCoverage. Der aktuelle SQL-Meta-Block enthält kein statusCode; Status wird über @StatusCodeOut und Binding-/Coverage-Daten geliefert. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Json:** @Json: Datentyp nvarchar(max) OUTPUT, Default NULL OUTPUT. OUTPUT-Textparameter vom Typ nvarchar(max), mit OUTPUT an eine entsprechende Variable binden. Beim Eintritt wird @Json auf NULL gesetzt. Bei @JsonErzeugen=1 enthält es meta und echte JSON-Arrays für die fünf Gruppen, mit JSON-null-Werten statt Stringrepräsentation und [] bei leeren Gruppen. Ohne Erzeugung beziehungsweise im Hilfezweig bleibt es NULL.

**@PrintMeldungen:** @PrintMeldungen: Datentyp bit, Default 1. Wird im Procedure-Quelltext weder gelesen noch validiert; 0, 1 oder NULL ändern das Verhalten nicht. Keine andere Wirkung behaupten. Consoleausgabe richtet sich nach @ResultSetArt. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Hilfe:** @Hilfe: Datentyp bit, Default 0. 1 druckt die eingebaute Hilfe und kehrt vor Parameter-/Transportvalidierung, lokaler Handoverprüfung und Auswertung zurück; 0 folgt dem normalen Pfad. NULL erfüllt die IF-Bedingung nicht und verhält sich wie ausgeschaltet. Der JSON-OUTPUT wird vorher auf NULL gesetzt, die anderen OUTPUT-Werte bleiben im Hilfezweig unverändert. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@StatusCodeOut:** @StatusCodeOut: Datentyp varchar(40) OUTPUT, Default NULL OUTPUT. Als varchar(40)-Variable mit OUTPUT binden; Eingangswert hat keine Steuerwirkung. Geschlossene globale Ergebniswerte: BASELINE_CAPTURE_BOUND (alle expliziten Basis-Captures und Kandidat sind unabhängig gebunden, gleicher exakter Modell-Export und gleiche geprüfte Quell-/Projektversion; keine Vollständigkeits-/Kausalitätsaussage), BASELINE_BINDING_UNPROVEN (mindestens eine Bindung oder Eingabeverarbeitung blieb unbelegt) und INVALID_PARAMETER (ungültige Steuerwerte oder Kombination). Im aktuellen JSON meta ist kein statusCode vorhanden; maßgeblicher Gesamtstatus steht in diesem OUTPUT und in Bindungs-/Coverage-Arrays. Hilfezweig lässt den Wert unverändert; ungefangene Fehler können Zuweisung umgehen.

**@IsPartialOut:** @IsPartialOut: Datentyp bit OUTPUT, Default NULL OUTPUT. Mit bit-Variable und OUTPUT binden. Nach normaler Verarbeitung immer 1, da Scopeauswertung und Beobachtungsabdeckung partiell sind; Kohorten-/Kennzahl-/Quellenabdeckung erläutert Einschränkungen. Hilfezweig belässt den Eingangswert; ungefangene Fehler können Zuweisung umgehen.

**@ErrorNumberOut:** @ErrorNumberOut: Datentyp int OUTPUT, Default NULL OUTPUT. Mit int-Variable und OUTPUT binden. NULL bei keinem abgefangenen fachlichen Fehler; sonst SQL-Fehlernummer der zurückgehaltenen Eingabe-/Bindungs-/Grenzverletzung. Ungefangene Ausnahmen und geworfene TABLE-Mappingfehler können die Zuweisung umgehen; im Hilfezweig keine Zuweisung.

**@ErrorMessageOut:** @ErrorMessageOut: Datentyp nvarchar(2048) OUTPUT, Default NULL OUTPUT. Mit nvarchar(2048)-Variable und OUTPUT binden. Bei abgefangenem Fehler ein kurzer Reason-Code, sonst NULL; enthält nicht notwendigerweise ausführliche SQL-Fehlermeldung. Hilfezweig unverändert; ungefangene Ausnahmen können Zuweisung umgehen. nvarchar(2048) umfasst höchstens 2048 UTF-16-Codeeinheiten.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| baselineBinding | 1 | 1 | [CandidateExecutionId] bigint NULL,[BaselineExecutionCount] int NOT NULL,[AnalyzedExecutionCount] int NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ProjectLsn] bigint NULL,[ArchiveSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ModelExportSha256] binary(32) NULL, [MinimumFindingCount] int NOT NULL,[MetricCount] int NOT NULL,[WorkloadEquivalence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[ErrorNumber] int NULL |
| executionCohort | 1 | 1 | [RunOrdinal] int NOT NULL,[Role] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExecutionId] bigint NULL, [BindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionStatus] int NULL,[LoggingLevel] int NULL,[Use32BitRuntime] bit NULL, [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IncludedMetricCount] int NOT NULL,[ExcludedMetricCount] int NOT NULL,[IsPartial] bit NOT NULL |
| metricBaseline | 1 | 1 | [ComparisonKeySha256] binary(32) NOT NULL,[ObjectKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PackageKey] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ModelNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[FlowNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ExecutionPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PhaseName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PortRole] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Unit] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ValidBaselineCount] int NOT NULL,[ExcludedBaselineCount] int NOT NULL,[MedianValue] decimal(38,1) NULL,[MinValue] decimal(38,0) NULL,[MaxValue] decimal(38,0) NULL,[SpreadValue] decimal(38,0) NULL, [CandidateValue] decimal(38,0) NULL,[DeltaValue] decimal(38,1) NULL,[DeltaPercent] decimal(38,6) NULL, [ComparisonStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CandidateSourceId] bigint NULL,[IsPartial] bit NOT NULL |
| baselineFindings | 1 | 1 | [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RuleVersion] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ComparisonKeySha256] binary(32) NULL,[MetricName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ValidBaselineCount] int NOT NULL,[ObservedDelta] decimal(38,1) NULL, [ThresholdMs] bigint NULL,[ThresholdPercent] decimal(9,4) NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL |
| baselineCoverage | 1 | 1 | [RunOrdinal] int NULL,[ExecutionId] bigint NULL,[ComparisonKeySha256] binary(32) NULL,[SourceName] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ReasonCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceId] bigint NULL,[ObservedValue] decimal(38,0) NULL,[ObservedRowCount] int NOT NULL,[MappedRowCount] int NOT NULL,[UnknownValueCount] int NOT NULL,[OutputTruncated] bit NOT NULL,[IsPartial] bit NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_SsisExecutionBaseline] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_SsisExecutionBaseline vergleicht unabhängig gebundene Beobachtungen; kein Paket-, Datei-, SSISDB- oder Paket-SQL-Aufruf.

Ausgelassene Argumente verwenden den bezeichneten Default. SQL-JSON-Text als nvarchar(max)-Variable oder N-präfigiertes T-SQL-Literal übergeben. Pflichtdaten werden erst im normalen Pfad geprüft; Typkonvertierungen erfolgen bereits vor Eintritt. OUTPUT muss zum Empfang auch am Aufruf angegeben sein. Alle Ergebnisse bleiben beobachtungsbezogen und partiell.

Vier reine Hilfeaufrufe ohne Captureprüfung:

DECLARE @HelpJson nvarchar(max)=N'vorbelegt';

DECLARE @Code varchar(40)='CALLER', @Partial bit=0, @Error int=0;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
monitor.USP_SsisExecutionBaseline; Version 1.0.0; Stand 2026-10-26.
   Explizite, unabhängig gebundene Kohorte mit höchstens 20 Basisläufen und
   einem anderen Kandidaten desselben exakten Exports. Jede Captureanalyse
   erfolgt einmal. Kennzahlen und Positionsschlüssel stammen aus dem gemeinsamen
   nativen Consumer; Parser und Lineage bleiben ausschließlich im Toolbelt.
   Median, Minimum, Maximum und Spannweite beschreiben beobachtete Werte;
   Arbeitslastgleichheit und statistische Signifikanz werden nicht behauptet.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_SsisExecutionBaseline vergleicht unabhängig gebundene Beobachtungen; kein Paket-, Datei-, SSISDB- oder Paket-SQL-Aufruf.
Ausgelassene Argumente verwenden den bezeichneten Default. SQL-JSON-Text als nvarchar(max)-Variable oder N-präfigiertes T-SQL-Literal übergeben. Pflichtdaten werden erst im normalen Pfad geprüft; Typkonvertierungen erfolgen bereits vor Eintritt. OUTPUT muss zum Empfang auch am Aufruf angegeben sein. Alle Ergebnisse bleiben beobachtungsbezogen und partiell.
Vier reine Hilfeaufrufe ohne Captureprüfung:
DECLARE @HelpJson nvarchar(max)=N'vorbelegt';
DECLARE @Code varchar(40)='CALLER', @Partial bit=0, @Error int=0;
```

