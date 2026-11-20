---
skill_format_version: "1.0.0"
name: "monitor.USP_ServerNuma"
schema_name: "monitor"
object_name: "USP_ServerNuma"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung, den Scheduler-Skew und die Memory Nodes."
source_path: "Code/08_ServerHealth/020_USP_ServerNuma.sql"
---

# monitor.USP_ServerNuma

## Zweck und Einsatz

Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung, den Scheduler-Skew und die Memory Nodes.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_ServerNuma] im vorgesehenen Datenbankkontext. Die Procedure liest Scheduler, OS-Knoten und Memory-Knoten aus Server-DMVs. Ohne entsprechende Servermetadatenrechte ist das Ergebnis eingeschränkt.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bei 1 (auch Default) wird bei einem Status ungleich AVAILABLE eine Meldung niedriger Severity mit dem Fehlertext ausgegeben; 0 unterdrückt sie. NULL löst die IF-Bedingung ebenfalls nicht aus. Die Meldung erfolgt nach Befüllung der OUTPUT-Parameter und vor den Resultsets. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.

**@Hilfe:** @Hilfe bit; Default: 0. 0 oder NULL nimmt den normalen Analysepfad. 1 gibt die PRINT-Hilfe aus und kehrt vor Quellzugriff, regulärer Statusinitialisierung und allen vier Status-/Fehler-OUTPUT-Zuweisungen zurück. TABLE-Preflight und Ablehnung eines nichtleeren Mappings außerhalb TABLE laufen nur im normalen Pfad; sie können dort werfen. @Json ist beim Eintritt auf NULL gesetzt. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden bit 1.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Trim von U+0020-Leerzeichen und UPPER gelten CONSOLE, RAW, TABLE und NONE; NULL wird wie leer behandelt. CONSOLE gibt nur die Console-Helferausgabe der ersten Fachquelle aus, ohne separates Modulstatusresultset; eine Leerzeile des Helfers hat hier NULL für Status und Hinweis. RAW gibt Modulstatus und unbeschriftete Fachresultsets aus. TABLE schreibt ausschließlich die benannte Fachmenge in das gemappte Ziel und gibt kein separates Modulstatusresultset aus. NONE unterdrückt Resultsets. CONSOLE und TABLE werden vor dem regulären Ausgabezweig intern zu NONE. Andere Texte, leer und NULL ergeben INVALID_PARAMETER/IsPartial=1; der nicht normalisierte ungültige Modus gibt dennoch Modulstatus und beschriftete Fachresultsets des ELSE-Zweigs aus. JSON ist davon unabhängig.

**@ResultTablesJson:** @ResultTablesJson ordnet für TABLE genau numaNodes einer leeren lokalen #temp-Zieltabelle mit einer Seed-Spalte zu; sonst nur NULL/Leerwert. @JsonErzeugen steuert unabhängig davon das JSON in @Json.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Im normalen Pfad erzeugt 1 unabhängig von @ResultSetArt das JSON-Dokument in @Json; 0 oder NULL erzeugt keines. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück. Leere Fachmengen werden als leere Arrays ausgegeben. Numerische 0 bleibt bit 0; von 0 verschiedene konvertierbare Zahlen werden beim Binden bit 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Empfänger für das JSON-Dokument; bei Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Bindung erfolgt optional mit @Json=@Empfaenger OUTPUT; die Empfängervariable muss nvarchar(max) sein. Ohne OUTPUT-Bindung wird kein Rückgabewert an eine Aufrufervariable übertragen.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für AVAILABLE, INVALID_PARAMETER, DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED. AVAILABLE bedeutet kein abgefangener Quellfehler und keine festgestellte ungültige Eingabe; INVALID_PARAMETER bezeichnet ungültige ResultSetArt; DENIED_PERMISSION klassifiziert Quellfehler 229, 297, 300 oder 371; TIMEOUT klassifiziert Fehler 1222; ERROR_HANDLED steht für sonstige im Quell-TRY abgefangene Fehler. Bei Quellfehlern ist IsPartial=1. Bindung z.B. @StatusCodeOut=@Status OUTPUT mit varchar(40)-Variable. Zuweisung geschieht nach Quellversuch/Validierung, vor Meldung und Resultsetausgabe; bei frühem Preflight-THROW oder Hilfe keine reguläre Zuweisung. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER und bei abgefangenen Quellfehlern. Das Bit bezeichnet den implementierten Status-/Fehlerpfad, nicht Vollständigkeit einzelner leerer Quellgruppen. Bindung z.B. @IsPartialOut=@Partial OUTPUT mit bit-Variable; Zuweisung gemeinsam mit StatusCodeOut vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für die SQL-Fehlernummer eines im Quell-TRY abgefangenen Fehlers; bei AVAILABLE und INVALID_PARAMETER bleibt der Wert NULL. Die bekannten Berechtigungs-/Timeoutnummern werden zugleich klassifiziert. Bindung z.B. @ErrorNumberOut=@ErrorNumber OUTPUT mit int-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für den Text des im Quell-TRY abgefangenen Fehlers oder die konkrete INVALID_PARAMETER-Begründung; bei AVAILABLE bleibt er NULL. Bindung z.B. @ErrorMessageOut=@ErrorMessage OUTPUT mit nvarchar(2048)-Variable; Zuweisung vor Meldung und Resultsets. Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert, ohne TABLE-Preflight; ein früher THROW erreicht die reguläre Zuweisung nicht. Im normalen Pfad wird der Anfangswert ersetzt. Ohne OUTPUT-Bindung wird kein Aufruferwert empfangen.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| numaNodes | 1 | 1 | [node_id] int,[node_state_desc] nvarchar(60),[memory_node_id] int,[online_scheduler_count] int,[idle_scheduler_count] int,[active_worker_count] int,[avg_load_balance] bigint,[SchedulerCount] bigint,[VisibleOnline] bigint,[CurrentTasks] bigint,[RunnableTasks] bigint,[ActiveWorkers] bigint,[LoadFactor] bigint,[RunnablePerScheduler] decimal(19,4),[Finding] varchar(50) |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N'CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_ServerNuma

Server-Health-Momentaufnahme; read-only und nicht atomar.

Parameter: @PrintMeldungen schaltet Statusmeldungen; @Hilfe gibt diese Hilfe vor TABLE-Preflight und Quellzugriff aus. @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE (trim/UPPER).

RAW und eine ungültige ResultSetArt liefern zuerst Modulstatus (ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber, ErrorMessage); CONSOLE/TABLE verwenden ihre Ausgabehelper und liefern kein separates Statusresultset. JSON enthält meta mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage, danach `numaNodes`, `memoryNodes` sowie warnings als leeres Array.

Status und Quellumfang: NUMA-/Soft-NUMA-Nodes, Schedulerverteilung, Runnable-per-Scheduler und Memory-Node-Speicher. DMVs bleiben abhängig von Engineversion, Sichtbarkeit und Berechtigungen; Quellfehler werden klassifiziert. Snapshot ohne Workload-/Trenddiagnose.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ServerNuma
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liefert die NUMA- und Soft-NUMA-Verteilung,
               den Scheduler-Skew und die Memory Nodes.
Datenquellen : sys.dm_os_nodes, sys.dm_os_schedulers, sys.dm_os_memory_nodes
Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach zwei technische Fachresultsets.
               CONSOLE gibt nur die Console-Helferausgabe der NUMA-Knoten aus; TABLE schreibt ausschließlich das gemappte numaNodes-Resultset.
               Beide liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.
               Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ServerNuma
Server-Health-Momentaufnahme; read-only und nicht atomar.
Parameter: @PrintMeldungen schaltet Statusmeldungen; @Hilfe gibt diese Hilfe vor TABLE-Preflight und Quellzugriff aus. @ResultSetArt akzeptiert CONSOLE, RAW, TABLE oder NONE (trim/UPPER).
RAW und eine ungültige ResultSetArt liefern zuerst Modulstatus (ContractVersion, CollectionTimeUtc, ModuleName, StatusCode, IsPartial, ErrorNumber, ErrorMessage); CONSOLE/TABLE verwenden ihre Ausgabehelper und liefern kein separates Statusresultset. JSON enthält meta mit resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage, danach `numaNodes`, `memoryNodes` sowie warnings als leeres Array.
Status und Quellumfang: NUMA-/Soft-NUMA-Nodes, Schedulerverteilung, Runnable-per-Scheduler und Memory-Node-Speicher. DMVs bleiben abhängig von Engineversion, Sichtbarkeit und Berechtigungen; Quellfehler werden klassifiziert. Snapshot ohne Workload-/Trenddiagnose.
CREATE TABLE [#ServerNuma_HelpExample]([Seed] bit NULL); EXEC [monitor].[USP_ServerNuma] @ResultSetArt=N'TABLE',@ResultTablesJson=N'{"numaNodes":"#ServerNuma_HelpExample"}'; DROP TABLE [#ServerNuma_HelpExample];
```

