---
skill_format_version: "1.0.0"
name: "monitor.USP_DiagnosticFindings"
schema_name: "monitor"
object_name: "USP_DiagnosticFindings"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Aggregiert normalisierte Befunde aus den zuvor implementierten Spezialfallmodulen über deren JSON-Ausgabeverträge."
source_path: "Code/08_ServerHealth/170_USP_DiagnosticFindings.sql"
---

# monitor.USP_DiagnosticFindings

## Zweck und Einsatz

Aggregiert normalisierte Befunde aus den zuvor implementierten Spezialfallmodulen über deren JSON-Ausgabeverträge.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DiagnosticFindings]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[sys].[databases]`, `[monitor].[USP_DatabaseIntegrityAnalysis]`, `[monitor].[USP_DatabaseCapacityAnalysis]`, `[monitor].[USP_BufferPoolAnalysis]`, `[monitor].[USP_BackupChainAnalysis]`, `[monitor].[USP_AvailabilityDeepAnalysis]`, `[monitor].[USP_AgentMonitoringAnalysis]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MitIntegritaet | bit | nein | 1 |
| @MitKapazitaet | bit | nein | 1 |
| @MitSpeicher | bit | nein | 1 |
| @MitBackupketten | bit | nein | 1 |
| @MitAvailability | bit | nein | 1 |
| @MitAgentMonitoring | bit | nein | 1 |
| @MitSchemaDesign | bit | nein | 0 |
| @MitStatistikverteilung | bit | nein | 0 |
| @MitIQP | bit | nein | 0 |
| @MitContention | bit | nein | 0 |
| @ContentionSampleSeconds | tinyint | nein | 5 |
| @ContentionMinWaitMs | bigint | nein | 1000 |
| @ParentIntegrityJson | nvarchar(max) | nein | NULL |
| @ParentCapacityJson | nvarchar(max) | nein | NULL |
| @ParentBufferPoolJson | nvarchar(max) | nein | NULL |
| @NurAbPrioritaet | varchar(16) | nein | 'INFO' |
| @MaxZeilen | int | nein | 1000 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max). Default ist NULL; bei Auslassung gilt NULL. Der Kandidatenhelfer behandelt den gesamten Listenwert NULL, leer oder nur aus U+0020-Leerzeichen bestehend als nicht angegeben; andere Whitespace-Zeichen wie Tabulatoren werden dabei nicht als Leerwert normalisiert. Das Pipe-Zeichen | trennt Elemente außerhalb von eckigen Klammern; innerhalb eines bracket-quotierten Elements maskiert ]] eine schließende Klammer. Äußere U+0020-Leerzeichen jedes Segments werden entfernt. Ein ungetrimmtes Rohsegment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; leere Segmente und fehlerhafte Klammerung sind ungültig. Die Namensprüfung verlangt, dass PARSENAME(Element, 1) nicht NULL und höchstens 128 Zeichen lang ist und PARSENAME(Element, 2) NULL ist. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Die Funktion prüft keine vollständige SQL-Bezeichnergrammatik. Gültige doppelte Namenswerte sind unter SQL_Latin1_General_CP1_CS_AS ungültig; Namen mit abweichender Groß- und Kleinschreibung bleiben verschieden. Erst wenn der gemeinsame Kandidatenhelfer erreicht wird, führen ungültige Elemente oder Duplikate zu INVALID_PARAMETER. Die Kandidatenauswahl bleibt durch Sichtbarkeit, Onlinezustand und HAS_DBACCESS begrenzt; die Liste garantiert weder die Existenz noch den Zugriff auf einen Namen und gewährt keine zusätzlichen Rechte. Der DiagnosticFindings-Parent reicht die unveränderte Liste an tatsächlich aufgerufene DatabaseIntegrityAnalysis-, DatabaseCapacityAnalysis-, BackupChainAnalysis-, SchemaDesignAnalysis-, StatisticsDistributionAnalysis- und IntelligentQueryProcessingAnalysis-Kindmodule weiter. Die Liste und ein nicht-NULL Pattern sind im erreichten Kandidatenhelfer nur dann unvereinbar, wenn nach der Normalisierung eine wirksame Namensliste vorliegt. ParentIntegrityJson- und ParentCapacityJson-Wiederverwendung überspringt den jeweiligen Kindmodulaufruf; übernommenes JSON wird durch die Liste nicht nachträglich gefiltert. Frühe Fehler oder nicht aufgerufene Kindmodule können die Kandidatenprüfung verhindern; der Parent garantiert keinen einheitlichen Status für Listenfehler.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent prüft oder normalisiert den Wert nicht. Er wird unverändert nur an tatsächlich aufgerufene DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis, BackupChainAnalysis, SchemaDesignAnalysis, StatisticsDistributionAnalysis und IntelligentQueryProcessingAnalysis weitergereicht, nicht an BufferPool, Availability, AgentMonitoring oder Contention. Bei erreichter Kandidatenprüfung weist der gemeinsame Helper NULL als INVALID_PARAMETER ab. 0 schließt Datenbanken mit database_id bis einschließlich 4 (master, tempdb, model und msdb) aus; 1 lässt sie unter den bestehenden Sichtbarkeits-, Online-, HAS_DBACCESS- und Empfängerfiltern zu. Der Schalter aktiviert kein Kindmodul und gewährt keine Rechte. Bei Wiederverwendung von ParentIntegrityJson oder ParentCapacityJson entfallen die jeweiligen Kindmodulaufrufe; dieser Schalter filtert übernommenes JSON nicht nachträglich. Frühere Fehler oder übersprungene Aufrufe können die Prüfung verhindern; der Parent garantiert keinen einheitlichen Status.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000). Default ist NULL; bei Auslassung gilt NULL und das Muster ist deaktiviert. Der Parser entfernt zuerst äußere U+0020-Leerzeichen. Er erkennt die Präfixe like:, regex: und regexi: ohne Beachtung der Groß- und Kleinschreibung; ohne bekanntes Präfix wird der gesamte Inhalt als LIKE-Muster verwendet, auch bei einem unbekannten Präfix. Nach Entfernen eines bekannten Präfixes wird nicht erneut getrimmt. NULL ergibt NONE. Leere Eingabe, nur U+0020-Leerzeichen und ein leerer Präfixrest ergeben intern EMPTY_PATTERN; bei erreichter Patternprüfung im Kindmodul wird INVALID_PARAMETER gemeldet. LIKE verwendet %, _ und [...] mit SQL_Latin1_General_CP1_CS_AS. REGEX verwendet Flag c und unterscheidet Groß- und Kleinschreibung; REGEXI verwendet Flag i und ignoriert sie. Die Präfixprüfung validiert keine Regexsyntax; Syntaxfehler entstehen erst, wenn REGEXP_LIKE tatsächlich ausgeführt wird. Regexausführung erfordert SQL Server 2025 und Compatibility Level mindestens 170 der Installationsdatenbank. Das Pattern ist keine Pipe-Liste. Der DiagnosticFindings-Parent normalisiert oder validiert das Pattern nicht und reicht es bei tatsächlichem Aufruf des jeweiligen Kindmoduls an DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis, BackupChainAnalysis, SchemaDesignAnalysis, StatisticsDistributionAnalysis und IntelligentQueryProcessingAnalysis weiter. Ein nicht-NULL Pattern ist im erreichten Kandidatenhelfer mit einer wirksamen expliziten Namensliste unzulässig; NULL, leerer oder nur aus U+0020 bestehender Listenwert ist keine wirksame Liste. ParentIntegrityJson- und ParentCapacityJson-Wiederverwendung überspringt den jeweiligen Kindmodulaufruf; das Pattern filtert übernommenes JSON nicht nachträglich. Frühe Fehler und übersprungene Aufrufe können die jeweilige Parserprüfung verhindern.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent prüft oder normalisiert den Wert nicht. Er wird unverändert nur an tatsächlich aufgerufene DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis, BackupChainAnalysis, SchemaDesignAnalysis, StatisticsDistributionAnalysis und IntelligentQueryProcessingAnalysis weitergereicht, nicht an BufferPool, Availability, AgentMonitoring oder Contention. Der gemeinsame Kandidatenhelper weist NULL als INVALID_PARAMETER ab, wenn er erreicht wird, auch bei @AnalysisClass=NULL. Integrity nutzt HA_DR_CURRENT und Capacity SERVER_HEALTH_CURRENT; laut Katalog verlangen beide keine RequiresGroupGate-Bestätigung. BackupChainAnalysis verwendet @AnalysisClass=NULL, sodass 0 oder 1 dort keine Klassenbestätigung auslösen. SchemaDesignAnalysis und IntelligentQueryProcessingAnalysis prüfen CATALOG_DEEP. StatisticsDistributionAnalysis prüft CATALOG_DEEP vor USP_Statistics; Findings ruft es im Modus VOLL auf, in dem USP_Statistics zunächst STATISTICS_TARGETED und danach ebenfalls CATALOG_DEEP prüft. Bei erreichtem CATALOG_DEEP-Gate führt 0 zu HIGH_IMPACT_CONFIRMATION_REQUIRED vor der Gruppenprüfung, NULL zu INVALID_PARAMETER und 1 bestätigt nur diese Anforderung. Aktuelle Policyfreigabe und SQL-Rechte gelten weiter. Der Wert aktiviert kein Kindmodul. Bei Wiederverwendung von ParentIntegrityJson oder ParentCapacityJson entfallen die jeweiligen Kindmodulaufrufe; dieser Schalter prüft oder verändert übernommenes JSON nicht nachträglich. Frühere Fehler oder übersprungene Aufrufe können Prüfungen verhindern; der Parent garantiert keinen einheitlichen Status.

**@MitIntegritaet:** @MitIntegritaet bit. Default ist 1. 1 aktiviert DatabaseIntegrityAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@MitKapazitaet:** @MitKapazitaet bit. Default ist 1. 1 aktiviert DatabaseCapacityAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@MitSpeicher:** @MitSpeicher bit. Default ist 1. 1 aktiviert BufferPoolAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@MitBackupketten:** @MitBackupketten bit. Default ist 1. 1 aktiviert BackupChainAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@MitAvailability:** @MitAvailability bit. Default ist 1. 1 aktiviert AvailabilityDeepAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@MitAgentMonitoring:** @MitAgentMonitoring bit. Default ist 1. 1 aktiviert AgentMonitoringAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@MitSchemaDesign:** @MitSchemaDesign bit. Default ist 0. 1 aktiviert SchemaDesignAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@MitStatistikverteilung:** @MitStatistikverteilung bit. Default ist 0. 1 aktiviert StatisticsDistributionAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@MitIQP:** @MitIQP bit. Default ist 0. 1 aktiviert IntelligentQueryProcessingAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@MitContention:** @MitContention bit. Default ist 0. 1 aktiviert InternalContentionAnalysis. 0 oder NULL lässt diesen Aufruf aus.

**@ContentionSampleSeconds:** @ContentionSampleSeconds tinyint. Default ist 5. Sekunden für das aktivierte Contention-Modul. 1 bis 60 fordert ein Intervalldelta an. 0 überspringt WAITFOR und liefert positive kumulative Zähler seit Serverstart. Werte über 60 sind ungültig. NULL überspringt die Wartezeit und liefert keine Latch- oder Spinlock-Deltazeilen. Raten bleiben unbekannt.

**@ContentionMinWaitMs:** @ContentionMinWaitMs bigint. Default ist 1000. Nichtnegative Mindestwartezeit in Millisekunden für Latch-Findings aus der Contention-Auswertung. Ein Wert ab der Grenze erfüllt den Vergleich. Bei NULL entstehen aus diesem Vergleich keine Latch-Findings. Negative Werte sind ungültig.

**@ParentIntegrityJson:** @ParentIntegrityJson nvarchar(max). Default ist NULL. Laufinternes JSON zur Wiederverwendung von DatabaseIntegrityAnalysis. NULL erhebt bei aktiviertem Modul frisch. Ein nicht-NULL-Wert muss gültiges JSON mit meta.resultName=DatabaseIntegrityAnalysis und meta.schemaVersion=1 enthalten. Leertext und falsche Kennungen sind ungültig. Verwenden Sie nur kontextgleiche Ergebnisse desselben Parent-Laufs.

**@ParentCapacityJson:** @ParentCapacityJson nvarchar(max). Default ist NULL. Laufinternes JSON zur Wiederverwendung von DatabaseCapacityAnalysis. NULL erhebt bei aktiviertem Modul frisch. Ein nicht-NULL-Wert muss gültiges JSON mit meta.resultName=DatabaseCapacityAnalysis und meta.schemaVersion=1 enthalten. Leertext und falsche Kennungen sind ungültig. Verwenden Sie nur kontextgleiche Ergebnisse desselben Parent-Laufs.

**@ParentBufferPoolJson:** @ParentBufferPoolJson nvarchar(max). Default ist NULL. Laufinternes JSON zur Wiederverwendung von BufferPoolAnalysis. NULL erhebt bei aktiviertem Modul frisch. Ein nicht-NULL-Wert muss gültiges JSON mit meta.resultName=BufferPoolAnalysis und meta.schemaVersion=1 enthalten. Leertext und falsche Kennungen sind ungültig. Verwenden Sie nur kontextgleiche Ergebnisse desselben Parent-Laufs.

**@NurAbPrioritaet:** @NurAbPrioritaet varchar(16). Default ist 'INFO'. INFO umfasst alle Prioritätsstufen. LOW lässt INFO aus. MEDIUM umfasst MEDIUM und HIGH. HIGH lässt nur HIGH zu. Die Filterung erfolgt nach der Erhebung. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.

**@MaxZeilen:** @MaxZeilen int. Default ist 1000. Eine positive ganze Zahl begrenzt die finale Findingmenge nach Prioritätsfilterung und wird an die Empfänger weitergereicht. NULL oder 0 hebt die Grenze auf. Negative Werte sind ungültig. Die Grenze begrenzt den gesamten Quellenaufwand nicht.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt beschriftete Findings. RAW liefert technische Ergebnis- und Statusmengen. TABLE schreibt ausschließlich findings. NONE unterdrückt die fachlichen Resultsets. Die Empfänger laufen mit NONE. JSON ist separat wählbar. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel findings erforderlich. Der Wert benennt eine vorhandene leere lokale #Temp-Tabelle mit einer Seed-Spalte. Erlaubt sind maximal 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Wird beim Eintritt auf NULL gesetzt und bei aktivierter JSON-Erzeugung gefüllt. Binden Sie eine nvarchar(max)-Variable mit OUTPUT.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent validiert oder normalisiert den Wert nicht. Der Wert wird unverändert an tatsächlich ausgeführte Kindaufrufe weitergereicht (10 Aufrufstellen). 1 fordert die jeweilige optionale Meldungseinstellung des Kindes an; 0 und NULL werden ebenfalls unverändert weitergereicht. Die konkrete Wirkung folgt dem Vertrag des jeweiligen Kindes; eine einheitliche Meldungs- oder Stillezusage gibt es nicht. Im normalen Ablauf verwendet der Parent den Schalter nicht für eine eigene PRINT- oder RAISERROR-Statusmeldung. Die Parameterhilfe ist unabhängig. Bei Wiederverwendung von ParentIntegrityJson, ParentCapacityJson oder ParentBufferPoolJson wird der jeweilige Kindaufruf übersprungen; der Schalter wird auf diese übernommenen Inhalte nicht erneut angewandt. Er steuert im Parent keine Resultsets, JSON, Analyseflags oder Fehlerbehandlung; Vorbereitungs- und SQL-Fehler bleiben unabhängig davon möglich.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der TABLE-Vorprüfung und beendet vor der fachlichen Analyse. 0 und NULL führen die Analyse aus.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT. Default ist NULL. Empfängt den Laufstatus. Binden Sie eine varchar(40)-Variable mit OUTPUT.

**@IsPartialOut:** @IsPartialOut bit OUTPUT. Default ist NULL. Empfängt das Partialitätsflag für die erreichbare Evidenz. Binden Sie eine bit-Variable mit OUTPUT.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT. Default ist NULL. Empfängt eine erfasste Fehlernummer oder NULL. Binden Sie eine int-Variable mit OUTPUT.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT. Default ist NULL. Empfängt eine erfasste Fehlermeldung oder NULL. Binden Sie eine nvarchar(2048)-Variable mit OUTPUT.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL , [SourceModule] sysname NOT NULL , [Category] varchar(60) NOT NULL , [Severity] varchar(16) NOT NULL , [Confidence] varchar(16) NOT NULL , [ScopeType] nvarchar(60) NOT NULL , [ScopeName] nvarchar(512) NULL , [FindingCode] varchar(120) NOT NULL , [EvidenceMetric] decimal(38,4) NULL , [Evidence] nvarchar(1000) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL , [RecommendedNextCheck] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DiagnosticFindings] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Priorität ist Triage, keine automatische Ursachenfeststellung. Kein READPAST; unvollständige Child-Evidenz bleibt sichtbar.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_DiagnosticFindings
Version      : 1.2.1
Stand        : 2026-10-20
Zweck        : Aggregiert normalisierte Befunde aus den zuvor implementierten
               Spezialfallmodulen über deren JSON-Ausgabeverträge.
Abhängigkeit : DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis,
               BufferPoolAnalysis, BackupChainAnalysis,
               AvailabilityDeepAnalysis, AgentMonitoringAnalysis sowie opt-in
               SchemaDesignAnalysis, StatisticsDistributionAnalysis,
               IntelligentQueryProcessingAnalysis und InternalContentionAnalysis.
Methodik     : Kindmodule laufen mit @ResultSetArt=NONE. Innerhalb eines
               Orchestratoraufrufs können kontextgleiche Parent-Ergebnisse
               wiederverwendet werden; sonst werden Quellen frisch gelesen.
               Der Aggregator liest nur definierte JSON-Felder und übernimmt
               keine freien SQL-, Mail-, Plan-, Pfad- oder Meldungstexte.
Grenzen      : Priorität ist Triage, keine automatische Ursachenfeststellung.
               Kein READPAST; unvollständige Child-Evidenz bleibt sichtbar.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DiagnosticFindings
Beispiel 1. EXEC [monitor].[USP_DiagnosticFindings] @Hilfe=1;
Beispiel 2. EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=0, @MitKapazitaet=0, @MitSpeicher=1, @MitBackupketten=0, @MitAvailability=0, @MitAgentMonitoring=0, @MaxZeilen=50, @ResultSetArt='RAW';
Beispiel 3. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=0, @MitKapazitaet=0, @MitSpeicher=1, @MitBackupketten=0, @MitAvailability=0, @MitAgentMonitoring=0, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Beispiel 4. CREATE TABLE #DiagnosticFindings_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=0, @MitKapazitaet=0, @MitSpeicher=1, @MitBackupketten=0, @MitAvailability=0, @MitAgentMonitoring=0, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#DiagnosticFindings_HelpExample"}'; SELECT * FROM #DiagnosticFindings_HelpExample; DROP TABLE #DiagnosticFindings_HelpExample; END TRY BEGIN CATCH DROP TABLE #DiagnosticFindings_HelpExample; THROW; END CATCH;
```

