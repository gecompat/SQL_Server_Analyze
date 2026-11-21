---
skill_format_version: "1.0.0"
name: "monitor.USP_ServerHealthAnalysis"
schema_name: "monitor"
object_name: "USP_ServerHealthAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Orchestriert alle Server-Health-Module."
source_path: "Code/08_ServerHealth/100_USP_ServerHealthAnalysis.sql"
---

# monitor.USP_ServerHealthAnalysis

## Zweck und Einsatz

Orchestriert alle Server-Health-Module. RAW reicht Child-Resultsets durch; CONSOLE zeigt die beschriftete Modulstatusliste. TABLE schreibt ausschließlich moduleStatus; NONE unterdrückt Resultsets. Optionales JSON enthält benannte Modulobjekte.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_ServerHealthAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[USP_ServerCpuTopology]`, `[monitor].[USP_ServerNuma]`, `[monitor].[USP_ServerMemory]`, `[monitor].[USP_TempDBConfiguration]`, `[monitor].[USP_ServerConfiguration]`, `[monitor].[USP_TraceFlags]`, `[monitor].[USP_StartupParameters]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MitCpu | bit | nein | 1 |
| @MitNuma | bit | nein | 1 |
| @MitMemory | bit | nein | 1 |
| @MitTempDB | bit | nein | 1 |
| @MitConfiguration | bit | nein | 1 |
| @MitTraceFlags | bit | nein | 1 |
| @MitStartup | bit | nein | 1 |
| @MitOS | bit | nein | 1 |
| @MitSecurity | bit | nein | 1 |
| @MitIntegritaet | bit | nein | 0 |
| @MitKapazitaet | bit | nein | 0 |
| @MitPerformanceCounters | bit | nein | 0 |
| @MitCriticalEvents | bit | nein | 0 |
| @MitContention | bit | nein | 0 |
| @MitBufferPool | bit | nein | 0 |
| @MitFindings | bit | nein | 0 |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MaxZeilen | int | nein | 100 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@MitCpu:** @MitCpu bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerCpuTopology auf. Bestandteil des mindestens-ein-Modul-Gates.

**@MitNuma:** @MitNuma bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerNuma auf. Standardpfad.

**@MitMemory:** @MitMemory bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerMemory auf. Standardpfad.

**@MitTempDB:** @MitTempDB bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_TempDBConfiguration auf. Standardpfad.

**@MitConfiguration:** @MitConfiguration bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerConfiguration auf. Standardpfad.

**@MitTraceFlags:** @MitTraceFlags bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_TraceFlags auf. Standardpfad.

**@MitStartup:** @MitStartup bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_StartupParameters auf. Standardpfad.

**@MitOS:** @MitOS bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_OSInformation auf. Standardpfad.

**@MitSecurity:** @MitSecurity bit. Default ist 1. NULL/0 deaktiviert, 1 ruft USP_ServerSecurityConfiguration auf. Standardpfad.

**@MitIntegritaet:** @MitIntegritaet bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_DatabaseIntegrityAnalysis für ausgewählte Datenbanken auf. page details bleiben aus. High-Impact-Pfad.

**@MitKapazitaet:** @MitKapazitaet bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_DatabaseCapacityAnalysis im Datenbankscope auf. High-Impact-Pfad.

**@MitPerformanceCounters:** @MitPerformanceCounters bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_PerformanceCounters mit SampleSeconds=0 auf. keine Warte-Samplingrunde.

**@MitCriticalEvents:** @MitCriticalEvents bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_CriticalEngineEvents mit system_health an, ServerDiagnostics und EventXML aus.

**@MitContention:** @MitContention bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_InternalContentionAnalysis mit SampleSeconds=5 und PageDetails=0 auf. Sampling wartet bis zu fünf Sekunden.

**@MitBufferPool:** @MitBufferPool bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_BufferPoolAnalysis ohne Verteilungsdetail auf. High-Impact-Pfad.

**@MitFindings:** @MitFindings bit. Default ist 0. NULL/0 deaktiviert, 1 ruft USP_DiagnosticFindings. Parent JSON-Ergebnisse von Integrity/Capacity/BufferPool werden zur Wiederverwendung übergeben, sofern diese erzeugt wurden.

**@DatabaseNames:** @DatabaseNames nvarchar(max). Default ist NULL; bei Auslassung gilt NULL. Der Kandidatenhelfer behandelt den gesamten Listenwert NULL, leer oder nur aus U+0020-Leerzeichen bestehend als nicht angegeben; andere Whitespace-Zeichen wie Tabulatoren werden dabei nicht als Leerwert normalisiert. Das Pipe-Zeichen | trennt Elemente außerhalb von eckigen Klammern; innerhalb eines bracket-quotierten Elements maskiert ]] eine schließende Klammer. Äußere U+0020-Leerzeichen jedes Segments werden entfernt. Ein ungetrimmtes Rohsegment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; leere Segmente und fehlerhafte Klammerung sind ungültig. Die Namensprüfung verlangt, dass PARSENAME(Element, 1) nicht NULL und höchstens 128 Zeichen lang ist und PARSENAME(Element, 2) NULL ist. Sie prüft keine vollständige SQL-Bezeichnergrammatik und kontrolliert die Teile 3 und 4 nicht zusätzlich. Gültige doppelte Namenswerte sind unter SQL_Latin1_General_CP1_CS_AS ungültig; Namen mit abweichender Groß- und Kleinschreibung bleiben verschieden. Erst wenn der gemeinsame Kandidatenhelfer erreicht wird, führen ungültige Elemente oder Duplikate zu INVALID_PARAMETER. Die Kandidatenauswahl bleibt durch Sichtbarkeit, Onlinezustand und HAS_DBACCESS begrenzt; die Liste garantiert weder die Existenz noch den Zugriff auf einen Namen und gewährt keine zusätzlichen Rechte. Der ServerHealth-Parent reicht die unveränderte Liste an die aufgerufenen DatabaseIntegrityAnalysis-, DatabaseCapacityAnalysis- und DiagnosticFindings-Kindmodule weiter. Die Liste und ein nicht-NULL Pattern sind im erreichten Kandidatenhelfer nur dann unvereinbar, wenn nach der Normalisierung eine wirksame Namensliste vorliegt. Frühe Fehler oder nicht aufgerufene Kindmodule können die Kandidatenprüfung verhindern; der Parent garantiert keinen einheitlichen Status für Listenfehler.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent prüft oder normalisiert den Wert nicht. Er wird unverändert nur an tatsächlich aufgerufene DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis und DiagnosticFindings weitergereicht. Bei erreichter Kandidatenprüfung weist der gemeinsame Helper NULL als INVALID_PARAMETER ab. 0 schließt Datenbanken mit database_id bis einschließlich 4 (master, tempdb, model und msdb) aus; 1 lässt sie unter den bestehenden Sichtbarkeits-, Online-, HAS_DBACCESS- und Empfängerfiltern zu. Der Schalter aktiviert kein Kindmodul und gewährt keine Rechte. Frühere Fehler oder übersprungene Kindmodule können die Prüfung verhindern; der Parent garantiert keinen einheitlichen Status.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000). Default ist NULL; bei Auslassung gilt NULL und das Muster ist deaktiviert. Der Parser entfernt zuerst äußere U+0020-Leerzeichen. Er erkennt die Präfixe like:, regex: und regexi: ohne Beachtung der Groß- und Kleinschreibung; ohne bekanntes Präfix wird der gesamte Inhalt als LIKE-Muster verwendet, auch bei einem unbekannten Präfix. Nach Entfernen eines bekannten Präfixes wird nicht erneut getrimmt. NULL ergibt NONE. Leere Eingabe, nur U+0020-Leerzeichen und ein leerer Präfixrest ergeben intern EMPTY_PATTERN; bei erreichter Patternprüfung im Kindmodul wird INVALID_PARAMETER gemeldet. LIKE verwendet %, _ und [...] mit SQL_Latin1_General_CP1_CS_AS. REGEX verwendet Flag c und unterscheidet Groß- und Kleinschreibung; REGEXI verwendet Flag i und ignoriert sie. Die Präfixprüfung validiert keine Regexsyntax; Syntaxfehler entstehen erst, wenn REGEXP_LIKE tatsächlich ausgeführt wird. Regexausführung erfordert SQL Server 2025 und Compatibility Level mindestens 170 der Installationsdatenbank. Das Pattern ist keine Pipe-Liste. Der ServerHealth-Parent normalisiert oder validiert das Pattern nicht und reicht es an DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis und DiagnosticFindings weiter, wenn die jeweiligen Kindmodule aufgerufen werden. Der erreichte Kandidatenhelfer schließt ein nicht-NULL Pattern mit einer wirksamen expliziten Namensliste aus; NULL, leerer oder nur aus U+0020 bestehender Listenwert ist keine wirksame Liste. Der Kandidatenhelfer prüft Pattern und Liste nur, wenn sein Auswahl-/Parserpfad tatsächlich erreicht wird.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0; bei Auslassung gilt 0. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent prüft oder normalisiert den Wert nicht. Er wird unverändert nur an tatsächlich aufgerufene DatabaseIntegrityAnalysis, DatabaseCapacityAnalysis und DiagnosticFindings weitergereicht. Der gemeinsame Kandidatenhelper weist NULL als INVALID_PARAMETER ab, wenn er erreicht wird, auch bei @AnalysisClass=NULL. Integrity nutzt HA_DR_CURRENT und Capacity SERVER_HEALTH_CURRENT; beide verlangen laut Katalog keine RequiresGroupGate-Bestätigung. Findings reicht diesen Wert unter den hier festgelegten Defaults nur an seine tatsächlich aufgerufenen Integrity-, Capacity- und BackupChain-Kindmodule weiter; BackupChain verwendet @AnalysisClass=NULL. Für diese tatsächlich erreichten Klassen lösen 0 und 1 keine High-Impact-Bestätigungspflicht aus. Andere Policyfreigaben und SQL-Rechte bleiben unverändert. Der Wert aktiviert kein Kindmodul oder tiefes Modul. Frühere Fehler, übersprungene Aufrufe und wiederverwendete JSON-Ergebnisse können Prüfungen verhindern; der Parent garantiert keinen einheitlichen Status.

**@MaxZeilen:** @MaxZeilen int. Default ist 100; bei Auslassung gilt 100. SQL Server bindet den ganzzahligen int-Wert vor Prozedureintritt; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent normalisiert keinen Text. @Hilfe=1 druckt die Hilfe und kehrt vor der Prüfung zurück; sonst führt ein negativer Wert zu INVALID_PARAMETER/partial und verhindert alle Kindaufrufe. 0 und NULL passieren diesen Guard. Der unveränderte Wert wird nur an aktive direkte Aufrufe von USP_ServerMemory, USP_DatabaseIntegrityAnalysis, USP_DatabaseCapacityAnalysis, USP_PerformanceCounters, USP_CriticalEngineEvents, USP_InternalContentionAnalysis, USP_BufferPoolAnalysis und USP_DiagnosticFindings übergeben, nicht an die übrigen acht Standardmodule. Die Parent-Modulstatusliste wird nicht gekürzt. In den genannten Kindern bedeuten 0 und NULL jeweils unbegrenzt; positive Werte wirken nur auf die jeweilige lokale Auswahl oder Ausgabe. Das ist keine Gesamtgrenze für Resultsets, JSON, Scan-, Sammel- oder Zeitaufwand; Metadaten, Warnungen und andere Ergebnisse können mehr Zeilen enthalten, und Quellenarbeit kann vor einer Ausgabebegrenzung stattfinden.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt die beschriftete Modulstatusliste. RAW liefert die Ergebnisse der aufgerufenen Module, danach den Parentstatus und die Modulstatusliste. TABLE schreibt ausschließlich moduleStatus. NONE unterdrückt die fachlichen Resultsets. CONSOLE und TABLE reichen intern NONE an die Module weiter. JSON wird separat gesteuert. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel moduleStatus erforderlich. Der Wert benennt eine vorhandene leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Erlaubt sind maximal 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, Leertext und reine Leerzeichen zulässig. Die Vorprüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt das Parent-JSON in Json. 0 und NULL lassen Json auf NULL. Bei MitFindings=1 fordert der Parent zusätzlich die JSON-Ergebnisse von Integrität, Kapazität und BufferPool zur Wiederverwendung an, auch wenn kein Parent-JSON angefordert wurde.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 erhält der Empfänger JSON mit meta, cpuTopology, numa, memory, tempdb, configuration, traceFlags, startupParameters, operatingSystem, security, databaseIntegrity, databaseCapacity, performanceCounters, criticalEngineEvents, internalContention, bufferPool, diagnosticFindings und warnings. Deaktivierte/nicht angeforderte Module erscheinen als JSON null. Mit lokaler nvarchar(max)-Variablen und OUTPUT binden.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1; bei Auslassung gilt 1. SQL Server bindet vor Prozedureintritt an bit: numerische 0 wird 0, numerische Werte ungleich 0 werden 1, NULL bleibt NULL; andere Literalformen unterliegen der SQL-Typkonvertierung, Bindungsfehler treten vor dem Prozedurcode auf. Der Parent validiert oder normalisiert den Wert nicht. Der Wert wird unverändert an tatsächlich ausgeführte Kindaufrufe weitergereicht (16 Aufrufstellen). 1 fordert die jeweilige optionale Meldungseinstellung des Kindes an; 0 und NULL werden ebenfalls unverändert weitergereicht. Die konkrete Wirkung folgt dem Vertrag des jeweiligen Kindes; eine einheitliche Meldungs- oder Stillezusage gibt es nicht. Im normalen Ablauf verwendet der Parent den Schalter nicht für eine eigene PRINT- oder RAISERROR-Statusmeldung. Die Hilfeausgabe ist unabhängig. Der Schalter steuert im Parent keine Resultsets, JSON, Analyseflags oder Fehlerbehandlung; Vorbereitungs- und SQL-Fehler bleiben unabhängig davon möglich.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 druckt Parameterbeschreibung und Beispiele, danach RETURN vor Erhebung und Output-Statuszuweisung. 0 oder NULL führt normalen Aufruf aus. Eintrittsreset setzt @Json dennoch auf NULL. TABLE-Preflight/Mappingprüfung erfolgt vor Hilfezweig.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [Ordinal] tinyint NOT NULL , [ModuleName] sysname NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ServerHealthAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_ServerHealthAnalysis

Beispiel 1. EXEC [monitor].[USP_ServerHealthAnalysis] @Hilfe=1;

Beispiel 2. EXEC [monitor].[USP_ServerHealthAnalysis] @MitCpu=1,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,@MitIntegritaet=0,@MitKapazitaet=0,@MitPerformanceCounters=0,@MitCriticalEvents=0,@MitContention=0,@MitBufferPool=0,@MitFindings=0,@MaxZeilen=100,@ResultSetArt='RAW';

Beispiel 3. DECLARE @HealthJson nvarchar(max)=NULL; EXEC [monitor].[USP_ServerHealthAnalysis] @MitCpu=1,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,@MitIntegritaet=0,@MitKapazitaet=0,@MitPerformanceCounters=0,@MitCriticalEvents=0,@MitContention=0,@MitBufferPool=0,@MitFindings=0,@MaxZeilen=100,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@HealthJson OUTPUT; SELECT @HealthJson AS [HealthJson];

Beispiel 4. DECLARE @HealthTablesJson nvarchar(max)=N'{"moduleStatus":"#ServerHealthAnalysis_HelpExample"}'; CREATE TABLE #ServerHealthAnalysis_HelpExample([Seed] bit NULL); EXEC [monitor].[USP_ServerHealthAnalysis] @MitCpu=1,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,@MitIntegritaet=0,@MitKapazitaet=0,@MitPerformanceCounters=0,@MitCriticalEvents=0,@MitContention=0,@MitBufferPool=0,@MitFindings=0,@MaxZeilen=100,@ResultSetArt='TABLE',@ResultTablesJson=@HealthTablesJson; SELECT * FROM #ServerHealthAnalysis_HelpExample; DROP TABLE #ServerHealthAnalysis_HelpExample;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ServerHealthAnalysis
Version      : 3.2.0
Stand        : 2026-07-19
Zweck        : Orchestriert alle Server-Health-Module. RAW reicht Child-Resultsets
               durch; CONSOLE zeigt die beschriftete Modulstatusliste.
               TABLE schreibt ausschließlich moduleStatus; NONE unterdrückt Resultsets.
               Optionales JSON enthält benannte Modulobjekte.
Änderungen   : 3.2.0 - Bereits erhobene Integritäts-, Kapazitäts- und
                         Buffer-Pool-Ergebnisse im Findings-Child wiederverwendet.
               3.1.0 - Spezialfallmodule und normalisierte Befunde als opt-in.
               3.0.1 - IF/TRY/CATCH-Blöcke syntaktisch eindeutig strukturiert;
                         Child-Statusvariablen vor jedem Aufruf zurückgesetzt.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ServerHealthAnalysis
Beispiel 1. EXEC [monitor].[USP_ServerHealthAnalysis] @Hilfe=1;
Beispiel 2. EXEC [monitor].[USP_ServerHealthAnalysis] @MitCpu=1,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,@MitIntegritaet=0,@MitKapazitaet=0,@MitPerformanceCounters=0,@MitCriticalEvents=0,@MitContention=0,@MitBufferPool=0,@MitFindings=0,@MaxZeilen=100,@ResultSetArt='RAW';
Beispiel 3. DECLARE @HealthJson nvarchar(max)=NULL; EXEC [monitor].[USP_ServerHealthAnalysis] @MitCpu=1,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,@MitIntegritaet=0,@MitKapazitaet=0,@MitPerformanceCounters=0,@MitCriticalEvents=0,@MitContention=0,@MitBufferPool=0,@MitFindings=0,@MaxZeilen=100,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@HealthJson OUTPUT; SELECT @HealthJson AS [HealthJson];
Beispiel 4. DECLARE @HealthTablesJson nvarchar(max)=N'{"moduleStatus":"#ServerHealthAnalysis_HelpExample"}'; CREATE TABLE #ServerHealthAnalysis_HelpExample([Seed] bit NULL); EXEC [monitor].[USP_ServerHealthAnalysis] @MitCpu=1,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,@MitIntegritaet=0,@MitKapazitaet=0,@MitPerformanceCounters=0,@MitCriticalEvents=0,@MitContention=0,@MitBufferPool=0,@MitFindings=0,@MaxZeilen=100,@ResultSetArt='TABLE',@ResultTablesJson=@HealthTablesJson; SELECT * FROM #ServerHealthAnalysis_HelpExample; DROP TABLE #ServerHealthAnalysis_HelpExample;
```

