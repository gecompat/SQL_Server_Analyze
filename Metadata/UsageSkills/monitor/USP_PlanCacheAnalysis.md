---
skill_format_version: "1.0.0"
name: "monitor.USP_PlanCacheAnalysis"
schema_name: "monitor"
object_name: "USP_PlanCacheAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Orchestriert Plan-Cache- und Showplan-Module mit einheitlichen Listen-, Pattern-, Limit- und Ausgabeparametern."
source_path: "Code/04_PlanCache/060_USP_PlanCacheAnalysis.sql"
---

# monitor.USP_PlanCacheAnalysis

## Zweck und Einsatz

Orchestriert Plan-Cache- und Showplan-Module mit einheitlichen Listen-, Pattern-, Limit- und Ausgabeparametern.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_PlanCacheAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[InternalCheckAnalysisPath]`, `[sys].[dm_exec_query_stats]`, `[monitor].[USP_QueryStats]`, `[monitor].[USP_QueryHashAnalysis]`, `[monitor].[USP_PlanCacheHealth]`, `[monitor].[USP_ShowplanAnalysis]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MitQueryStats | bit | nein | 1 |
| @MitQueryHashAnalysis | bit | nein | 0 |
| @MitPlanCacheHealth | bit | nein | 0 |
| @MitShowplanAnalysis | bit | nein | 0 |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @QueryHash | binary(8) | nein | NULL |
| @QueryPlanHash | binary(8) | nein | NULL |
| @PlanHandle | varbinary(64) | nein | NULL |
| @TextPattern | nvarchar(4000) | nein | NULL |
| @Sortierung | varchar(32) | nein | 'CPU_TOTAL' |
| @AnalyseModus | varchar(16) | nein | 'TOP' |
| @MaxZeilen | int | nein | 100 |
| @MaxAnalyseobjekte | int | nein | 20 |
| @MaxDurationSeconds | int | nein | 30 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@MitQueryStats:** @MitQueryStats bit. Default ist 1. 1 aktiviert QueryStats, 0 deaktiviert. TOP/100 ohne Hash ist nicht per se PLAN_CACHE_DEEP geschützt. NULL aktiviert Child nicht.

**@MitQueryHashAnalysis:** @MitQueryHashAnalysis bit. Default ist 0. Der bit-Parameter nimmt 0, 1 oder NULL an; bei Auslassung gilt 0. 1 aktiviert den Hash-Child, 0 deaktiviert ihn. NULL deaktiviert den Child. Bei aktiviertem Child verlangt ein fehlender QueryHash das Deep-Gate; ein einzelner Hash mit TOP <=1000 nicht.

**@MitPlanCacheHealth:** @MitPlanCacheHealth bit. Default ist 0. Der bit-Parameter nimmt 0, 1 oder NULL an; bei Auslassung gilt 0. 1 aktiviert Health, 0 deaktiviert den Child. NULL deaktiviert den Child. TOP wird SUMMARY; VOLL wird VOLL mit Datenbankverteilung und Deep-Gate.

**@MitShowplanAnalysis:** @MitShowplanAnalysis bit. Default ist 0. Der bit-Parameter nimmt 0, 1 oder NULL an; bei Auslassung gilt 0. 1 aktiviert Showplan, 0 deaktiviert den Child. NULL deaktiviert den Child. TOP wird GEZIELT, VOLL bleibt VOLL.

**@DatabaseNames:** @DatabaseNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger Datenbanknamen bis 128 Zeichen. | trennt außerhalb [...], ]] maskiert ]. Segmentränder getrimmt. NULL/leer/Whitespace = kein Filter. Ungültig INVALID_PARAMETER. Nicht mit wirksamem DatabaseNamePattern kombinierbar.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet den Wert vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Eingabeformen unterliegen der SQL-Typkonvertierung, eine eigene Textnormalisierung oder Leertextauswahl erfolgt nicht, und Bindungsfehler treten vor dem Prozeduraufruf auf. Der Parent prüft oder normalisiert den Wert nicht und reicht ihn unverändert nur an QueryStats und Showplan weiter, jeweils wenn das Child aktiviert ist. Bei erreichtem Kandidatenhelfer schließt 0 master, tempdb, model und msdb aus; 1 lässt sie zu, sofern sie sichtbar, online und zugänglich sind und die übrigen Listen-, Pattern- und Snapshotfilter erfüllen. QueryStats ruft den Kandidatenhelfer bei Status AVAILABLE auch mit gesetztem @PlanHandle auf. Showplan ruft ihn nur bei Status AVAILABLE und @PlanHandle IS NULL auf; ein direkt übergebener Planhandle umgeht dort diesen Datenbankscopefilter. NULL wird vom Kandidatenhelfer als INVALID_PARAMETER abgelehnt, wenn er erreicht wird; frühere Fehler können Vorrang haben. Der Parent reicht diesen Schalter nicht an QueryHash oder PlanCacheHealth weiter. Er gewährt keine zusätzlichen Datenbankrechte.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000). Default ist NULL. LIKE oder Präfix like:/regex:/regexi:. Case-insensitive Präfix, außen getrimmt, Rest nicht. NULL kein Filter, leer ungültig. Nicht mit DatabaseNames kombinierbar. Regex nur SQL Server 2025 + Installations-DB Compat 170.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 1 bestätigt einen geschützten Pfad, wenn dessen Policy eine Bestätigung verlangt. Berechtigungen und Grenzwerte gelten weiterhin. 0 bestätigt den Pfad nicht und NULL ist für die Pfadprüfung ungültig. Der Parent prüft PLAN_CACHE_DEEP bei mindestens zwei Snapshot-Consumern, wenn ein Queryhash fehlt, VOLL gewählt ist oder das Zeilenlimit unbegrenzt beziehungsweise größer als 1000 ist. Die aufgerufenen Module prüfen ihre eigenen Gates. Als Snapshot-Consumer zählen Query Stats, Query Hash und Showplan ohne direkten Planhandle. Verweigert das Parent-Gate den gemeinsamen Zugriff, laufen die Module nicht. Schlägt die erlaubte Materialisierung fehl, können die Module frisch lesen.

**@QueryHash:** @QueryHash binary(8). Default ist NULL. Optionaler exakter Queryhashfilter für QueryStats/Hash/Showplan. Hash-Child ohne Hash braucht Deep-Gate. Einzelner Hash mit TOP/<=1000 nicht.

**@QueryPlanHash:** @QueryPlanHash binary(8). Default ist NULL. Optionaler exakter Planhashfilter für QueryStats/Showplan.

**@PlanHandle:** @PlanHandle varbinary(64). Default ist NULL. Optionaler Handlefilter. Showplan fügt Nicht-NULL direkt als Kandidat hinzu.

**@TextPattern:** @TextPattern nvarchar(4000). Default ist NULL; bei Auslassung gilt NULL und es wird kein Textfilter angefordert. Der Parser trimmt zuerst äußere U+0020-Leerzeichen, erkennt like:, regex: und regexi: ohne Beachtung der Groß- und Kleinschreibung und entfernt ein erkanntes Präfix ohne erneutes Trimmen. Ohne bekanntes Präfix gilt der gesamte Inhalt als LIKE-Muster, auch bei einem unbekannten Präfix. NULL ergibt NONE; leere Eingabe, nur U+0020-Leerzeichen und leerer Präfixrest ergeben intern EMPTY_PATTERN und beim tatsächlich erreichten Kindmodul INVALID_PARAMETER. LIKE verwendet %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. REGEX verwendet Flag c (case-sensitive), REGEXI Flag i (case-insensitive). Der Parser prüft keine Regexsyntax; Syntaxfehler entstehen erst bei tatsächlicher REGEXP_LIKE-Ausführung. Regexausführung erfordert SQL Server 2025 und Compatibility Level mindestens 170 der Installationsdatenbank. @TextPattern ist keine Pipe-Liste. Der PlanCache-Parent prüft das Pattern nicht und reicht es unverändert nur an QueryStats und Showplan weiter, nicht an QueryHash oder PlanCacheHealth. QueryStats wertet den Textfilter auch bei gesetztem @PlanHandle aus. Showplan prüft Form und Regexverfügbarkeit vor der Handleauswahl; ohne direkten Planhandle wendet es den Textfilter an. Mit nicht-NULL @PlanHandle wird der Handle direkt übernommen und nicht mit dem Pattern verglichen; Regexsyntax kann daher ungeprüft bleiben. Frühere Fehler oder deaktivierte Kindmodule können die Prüfung verhindern.

**@Sortierung:** @Sortierung varchar(32). Default ist 'CPU_TOTAL'. Die unterstützten Ränge hängen vom aktivierten Modul ab. QueryStats, QueryHashAnalysis und ShowplanAnalysis verstehen CPU_TOTAL für gesamte CPU, ELAPSED_TOTAL für gesamte Laufzeit, READS_TOTAL für logische Reads, EXECUTIONS für Ausführungen und SPILLS_TOTAL für Spills. QueryStats und QueryHashAnalysis unterstützen zusätzlich WRITES_TOTAL für logische Writes. QueryStats und ShowplanAnalysis unterstützen GRANT_MAX für maximalen Grant und LAST_EXECUTION für die letzte Ausführung. Nur QueryStats unterstützt CPU_AVG, ELAPSED_AVG, READS_AVG und WRITES_AVG für den jeweiligen Mittelwert je Ausführung sowie ROWS_TOTAL für die Gesamtzahl der Zeilen. Nur QueryHashAnalysis unterstützt PLAN_VARIANTS für die Zahl der Planvarianten. PlanCacheHealth verwendet den Wert nicht. NULL entspricht CPU_TOTAL. Die Empfänger trimmen Leerzeichen und normalisieren die Groß- und Kleinschreibung. Leertext und nicht unterstützte Werte sind im jeweiligen Modul ungültig.

**@AnalyseModus:** @AnalyseModus varchar(16). Default ist 'TOP'. TOP => QueryStats/Hash TOP, Health SUMMARY, Showplan GEZIELT. VOLL => QueryStats/Hash VOLL, Health VOLL+Datenbankverteilung, Showplan VOLL. Trim/Upper, NULL TOP, leer/sonst ungültig.

**@MaxZeilen:** @MaxZeilen int. Default ist 100. Je Child weitergereicht. Positiv begrenzt, NULL/0 unbegrenzt, negativ Parent INVALID_PARAMETER ohne Children. Unbegrenzt/>1000 oder VOLL kann Deep-Gate auslösen. SUMMARY Health nutzt den Wert nicht.

**@MaxAnalyseobjekte:** @MaxAnalyseobjekte int. Default ist 20. Showplan-Kandidatenlimit. Positiv begrenzt, 0/NULL unbegrenzt, negativ Parent INVALID_PARAMETER. >20/unbegrenzt kann Deep-Gate auslösen. VOLL zusätzlich SHOWPLAN_XML_DEEP.

**@MaxDurationSeconds:** @MaxDurationSeconds int. Default ist 30. Ganzzahl von 1 bis 3600 Sekunden. Der Parent lehnt NULL und Zahlen außerhalb des Bereichs ab. Das Zeitbudget gilt für Showplan und wird zwischen Kandidaten geprüft. Es unterbricht keine laufende XML-Analyse.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. RAW gibt zuerst die Resultsets der aufgerufenen Module aus, gefolgt vom Parentstatus und der Modulstatusliste. CONSOLE zeigt die beschriftete Modulstatusliste. TABLE schreibt nur moduleStatus. NONE unterdrückt die fachlichen Resultsets. Die Module erhalten bei CONSOLE, TABLE und NONE intern NONE. JSON ist separat wählbar. Leerzeichen am Rand und die Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Nur TABLE: Objekt exakt mit moduleStatus und Stringziel. Ziel vorhandene leere lokale #Temp mit genau einer Seed-Spalte, <=116 Zeichen, kein ##/#Monitor. Andere Modi nur NULL/leer/Whitespace, sonst 51011. Preflight vor Hilfe-Return.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt zusätzlich @Json. 0/NULL erzeugt kein Dokument.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. bei Eintritt NULL. Bei JsonErzeugen=1 Dokument mit meta, queryStats, queryHashes, planCacheHealth, showplan, modules, warnings. Nicht verfügbare Childobjekte null. OUTPUT nvarchar(max) binden.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent validiert oder normalisiert den Wert nicht. Er reicht ihn unverändert an tatsächlich ausgeführte QueryStats-, QueryHashAnalysis-, PlanCacheHealth- und Showplan-Aufrufe weiter. 1 fordert dort jeweils die optionale Meldungseinstellung an; 0 und NULL werden ebenfalls weitergereicht. Die konkrete Wirkung folgt dem jeweiligen Childvertrag; eine einheitliche Meldungs- oder Stillezusage gibt es nicht. Der Parent erzeugt im normalen Ablauf keine eigene PRINT- oder RAISERROR-Statusmeldung; seine Hilfeausgabe ist unabhängig. Im Showplan-Child entsteht dessen optionale Severity-10-Warnung nur am erreichten Ende bei einem Status ungleich AVAILABLE; der interne Interpreter erhält fest @PrintMeldungen=0. Der Parent-Schalter steuert keine Resultsets, JSON, Modulauswahl oder Fehlerbehandlung. Vorbereitungs- und SQL-Fehler bleiben unabhängig davon möglich.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 druckt Hilfe und RETURN vor Validierung/Analyse. Vorher @Json=NULL, Monitor-Temp-DDL, Locktimeout, TABLE-Mapping-Preflight. 0/NULL regulärer Ablauf.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ExecutionOrdinal] tinyint NOT NULL , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [InvocationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_PlanCacheAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_PlanCacheAnalysis

Die Procedure koordiniert Query Stats, Query Hash, Plan Cache Health und Showplan. Sie liefert den Modulstatus und kann die Ergebnisse der aufgerufenen Module als JSON zusammenführen.

Mindestens einer der vier Modulschalter muss exakt 1 sein. 0 und NULL gelten jeweils als deaktiviert.

Hilfe anzeigen. EXEC [monitor].[USP_PlanCacheAnalysis] @Hilfe=1;

Modulstatus als RAW lesen. EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt='RAW';


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_PlanCacheAnalysis
Version      : 2.1.0
Stand        : 2026-07-19
Zweck        : Orchestriert Plan-Cache- und Showplan-Module mit einheitlichen
               Listen-, Pattern-, Limit- und Ausgabeparametern.
Änderungen   : 2.1.0 - dm_exec_query_stats bei mehreren Consumern einmalig
                         laufgebunden materialisiert und wiederverwendet.
               2.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_PlanCacheAnalysis
Die Procedure koordiniert Query Stats, Query Hash, Plan Cache Health und Showplan. Sie liefert den Modulstatus und kann die Ergebnisse der aufgerufenen Module als JSON zusammenführen.
Mindestens einer der vier Modulschalter muss exakt 1 sein. 0 und NULL gelten jeweils als deaktiviert.
Hilfe anzeigen. EXEC [monitor].[USP_PlanCacheAnalysis] @Hilfe=1;
Modulstatus als RAW lesen. EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt='RAW';
Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Modulstatus in eine lokale Temp-Tabelle schreiben. CREATE TABLE #PlanCacheAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_PlanCacheAnalysis] @MitQueryStats=1, @MitQueryHashAnalysis=0, @MitPlanCacheHealth=0, @MitShowplanAnalysis=0, @QueryHash=0x0102030405060708, @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#PlanCacheAnalysis_HelpExample"}'; SELECT * FROM #PlanCacheAnalysis_HelpExample; DROP TABLE #PlanCacheAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #PlanCacheAnalysis_HelpExample; THROW; END CATCH;
```

