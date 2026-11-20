---
skill_format_version: "1.0.0"
name: "monitor.USP_CheckAnalyseAccess"
schema_name: "monitor"
object_name: "USP_CheckAnalyseAccess"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Prüft die effektive Analyseklassen- und AD-Gruppenpolicy."
source_path: "Code/01_Common/050_USP_CheckAnalyseAccess.sql"
---

# monitor.USP_CheckAnalyseAccess

## Zweck und Einsatz

Prüft die effektive Analyseklassen- und AD-Gruppenpolicy.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CheckAnalyseAccess]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `sys.login_token`, `[monitor].[VW_AnalyseClassCatalog]`, `[monitor].[VW_AnalyseAccessCurrent]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @AnalyseKlasse | varchar(64) | nein | NULL |
| @NurGesperrte | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@AnalyseKlasse:** @AnalyseKlasse: varchar(64), Default NULL. Ausgelassen oder NULL wählt alle 31 Klassen. Sonst wird der Wert mit der Katalogspalte unter SQL_Latin1_General_CP1_CS_AS verglichen; es gibt kein LTRIM/RTRIM. Groß-/Kleinschreibung zählt; SQL-Gleichheit kann nachgestellte U+0020 auffüllen. Leer oder nicht passend ergibt INVALID_PARAMETER. Wirkung: auf eine Klasse begrenzen. Zulässige Klassen mit Bedeutung:

**@NurGesperrte:** @NurGesperrte: bit, Default 0. 0 liefert alle Accesszeilen; 1 nur Zeilen mit IsAllowed=0. NULL wirkt im SQL-Filter ebenfalls wie 1. Filtert nur Access, nicht Policies. Ausgelassen verwendet 0.

**@ResultSetArt:** @ResultSetArt: varchar(16), Default 'CONSOLE'. Werte: CONSOLE rendert Access und liefert Policies/Warnings zusätzlich; RAW liefert Meta, Access, Policies, Warnings als vier Resultsets; TABLE exportiert nur Access; NONE unterdrückt fachliche Resultsets. Eingabe wird mit LTRIM/RTRIM an äußeren U+0020 entfernt und mit UPPER normalisiert. NULL/sonst ungültig ergibt INVALID_PARAMETER. Ausgelassen = CONSOLE.

**@ResultTablesJson:** @ResultTablesJson: nvarchar(max), Default NULL. NULL/ausgelassen bedeutet keine Zuordnung. Für TABLE ist ein nichtleeres gültiges JSON-Objekt mit genau dem nach U+0020-Trimmen case-sensitiven Schlüssel "access" und einem nach U+0020-Trimmen nichtleeren JSON-String als Ziel erforderlich; Schlüssel und Ziele müssen eindeutig sein. Zielname: vorhandene lokale #temp-Tabelle, nie ##, höchstens LEN 116, nicht #Monitor* (case-insensitiv); muss leer sein und genau eine beliebig typisierte Seed-Spalte enthalten. Der Preflight fügt vorübergehend eine bit-NULL-Prüfspalte hinzu/entfernt sie wieder; das ist keine Seed-Typvorgabe. U+0020 außen am JSON wird für Objektklammern getrimmt; leere/ungültige JSON-Objekte, falsche Schlüssel/Werttypen, leere Namen, Duplikate, unzulässige Namen, fehlendes/gefülltes/mehrspaltiges Ziel scheitern im Preflight (bei Procedure-Aufruf THROW 51011). Außerhalb TABLE führt jede nichtleere Zuordnung zu THROW 51011.

**@JsonErzeugen:** @JsonErzeugen: bit, Default 0. 0/NULL erzeugt kein JSON; 1 erzeugt @Json mit meta sowie access-, policies- und warnings-Arrays. Ausgelassen verwendet 0.

**@Json:** @Json: nvarchar(max), Default NULL OUTPUT. Als OUTPUT-Variable binden, um das erzeugte Dokument zu erhalten; bei deaktiviertem JSON bleibt es NULL. Der Eingangswert wird zu Beginn vor TABLE-Preflight und Hilfe verworfen und auf NULL gesetzt. Ausgelassen ist möglich, dann wird kein Wert empfangen.

**@PrintMeldungen:** @PrintMeldungen: bit, Default 1. 1 gibt eine zusätzliche Severity-10-Meldung für behandelte Fehler aus; 0 oder NULL unterdrückt nur diese Meldung, nicht Hilfe, Resultsets, Warnings oder JSON. Ausgelassen = 1.

**@Hilfe:** @Hilfe: bit, Default 0. 1 druckt die Hilfe und beendet vor der fachlichen Accessauswertung; NULL/0 führt normal aus. Hilfe ist unabhängig von @PrintMeldungen. Bei TABLE läuft der Mapping-Preflight nur im normalen Pfad und kann TempDB-Metadaten ändern oder mit 51011 abbrechen. @Json ist vorher bereits NULL.

## Resultate und Ausgabe

RAW, CONSOLE, TABLE oder NONE; optional JSON mit access und policies.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| access | 1 | 1 | [AnalysisClass] varchar(64) NOT NULL , [AnalysisLevel] varchar(16) NOT NULL , [RequiresGroupGate] bit NOT NULL , [OriginalLoginName] sysname NULL , [EffectiveLoginName] sysname NULL , [IsSysadmin] bit NULL , [ActivePolicyCount] bigint NULL , [RelevantPolicyCount] bigint NULL , [IsAllowed] bit NOT NULL , [AccessReason] varchar(20) NULL , [MatchedGroupCount] bigint NULL , [StatusCode] varchar(40) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CheckAnalyseAccess] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CheckAnalyseAccess prüft den Framework-Gruppengate für Analyseklassen im aktuellen Login- und Execution-Kontext. Die Procedure führt keine Fachanalyse aus und vergibt keine SQL-Rechte.

Quellen: Klassenkatalog, VW_AnalyseAccessCurrent, VW_AnalyseAccessPolicy, sys.login_token und IS_MEMBER. Momentaufnahme gegen SYSUTCDATETIME(); kein Live-AD- oder Objektberechtigungsnachweis.

Ohne aktive Policy ist der Gate offen. Sobald global mindestens eine aktive Policy existiert, kann eine geschützte Klasse ohne spezifische oder *-Regel gesperrt sein. Token-Match hat Vorrang vor IS_MEMBER; sonst NO_MATCH.

  STANDARD_CURRENT = leichte aktuelle Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O

  EXTENDED_CURRENT = gezielte aktuelle Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CheckAnalyseAccess
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Prüft die effektive Analyseklassen- und AD-Gruppenpolicy.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optional JSON mit access und policies.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CheckAnalyseAccess prüft den Framework-Gruppengate für Analyseklassen im aktuellen Login- und Execution-Kontext. Die Procedure führt keine Fachanalyse aus und vergibt keine SQL-Rechte.
Quellen: Klassenkatalog, VW_AnalyseAccessCurrent, VW_AnalyseAccessPolicy, sys.login_token und IS_MEMBER. Momentaufnahme gegen SYSUTCDATETIME(); kein Live-AD- oder Objektberechtigungsnachweis.
Ohne aktive Policy ist der Gate offen. Sobald global mindestens eine aktive Policy existiert, kann eine geschützte Klasse ohne spezifische oder *-Regel gesperrt sein. Token-Match hat Vorrang vor IS_MEMBER; sonst NO_MATCH.
  STANDARD_CURRENT = leichte aktuelle Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O
  EXTENDED_CURRENT = gezielte aktuelle Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung
  PLAN_CACHE_CURRENT = begrenzte Query-Stats- und Plan-Cache-Auswertung ohne vollständiges XML-Shredding
  SHOWPLAN_TARGETED = gezielte Showplan-Extraktion/XML-Analyse für gefilterte Planhandles oder Query Hashes
  OBJECT_ANALYSIS_CURRENT = gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank
  EXTERNAL_RUNTIME_CURRENT = lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer Runtimes, ohne Testausführung
  CLR_CURRENT = lesende SQL-CLR-, Host-, AppDomain-, Task-, Request- und Speicheranalyse, ohne Assemblyausführung
  MISSING_INDEX_CURRENT = flüchtige begrenzte Missing-Index-Hinweise, keine automatische DDL
  STATISTICS_TARGETED = gezielte Statistik-Eigenschaften gefilterter Objekte
  COLUMNSTORE_CURRENT = gezielte Columnstore-Rowgroups aus Katalogen, kein Segment-/Dictionary-Vollscan
  LOCKS_DEEP = detaillierte sys.dm_tran_locks-Materialisierung für relevante Sessions
  LOG_VLF_DEEP = datenbankübergreifende VLF-Auswertung via sys.dm_db_log_info
  PLAN_CACHE_DEEP = breite oder vollständige Query-Stats- und Plan-Cache-Analyse
  SHOWPLAN_XML_DEEP = XML-Analyse gecachter/aktueller Showplans mit Warnings, Spills, Objekten, Statistiken
  CATALOG_DEEP = breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse
  PHYSICAL_STATS_DEEP = explizite sys.dm_db_index_physical_stats-Auswertung in gewähltem Modus
  INDEX_OPERATIONAL_DEEP = breite kumulative Index-Operational-Stats mit Lock/Latch/I/O/Page-Splits
  QUERY_STORE_CURRENT = gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan-/Force-Auswertung, enges Zeit-/Zeilenlimit
  EXTENDED_EVENTS_CURRENT = leichte Inventarisierung von Extended-Events-Definitionen und laufenden Sessions, ohne Targetdaten/Historie
  QUERY_STORE_DEEP = breite Query-Store-Historie, Regressionen, Planwechsel und Waits
  CROSS_DATABASE_DEEP = datenbankübergreifende Inventarisierung und Diagnose
  COLUMNSTORE_DEEP = breite Columnstore-Analyse mit Rowgroups, Deleted Rows, Dictionaries und Segmenten
  EXTENDED_EVENTS_FORENSICS_DEEP = optionale Analyse vorhandener XE-Sessions/Dateien, nie Primärquelle des Standardlaufs
  SERVER_HEALTH_CURRENT = CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der Instanz
  SERVER_CONFIGURATION_CURRENT = lesende Serverkonfiguration, Trace Flags und Startup-Parameter
  SECURITY_CONFIGURATION_CURRENT = lesende sicherheits- und dienstbezogene Betriebsparameter
  SQL_AGENT_CURRENT = lesender SQL-Agent-Status, Jobs, Schedules und Historie aus msdb
  RESOURCE_GOVERNOR_CURRENT = lesende Resource-Governor-Konfiguration und Laufzeit
  HA_DR_CURRENT = begrenzte lesende AG-, Backup-, Log-Shipping-, Replication-, CDC- und Change-Tracking-Analyse
  ENTERPRISE_TOPOLOGY_DEEP = vertiefte enterpriseweite HA/DR- und Replication-Topologie/Distribution
  DATA_PLATFORM_ADAPTER_CURRENT = optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Logs mit isolierter Existenz-/Rechteprüfung
CONSOLE rendert Access als Ergebnis und zeigt zusätzlich Policy- und Warning-Resultsets. RAW liefert Meta, Access, Policies und Warnings als vier technische Resultsets.
TABLE schreibt ausschließlich das benannte access-Resultset mit 12 Accessfeldern in eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte beliebigen Datentyps. Der Preflight prüft das Ziel durch vorübergehendes Hinzufügen und Entfernen einer bit-NULL-Prüfspalte.
access-Felder: AnalysisClass varchar(64), AnalysisLevel varchar(16), RequiresGroupGate bit, OriginalLoginName sysname NULL, EffectiveLoginName sysname NULL, IsSysadmin bit NULL, ActivePolicyCount bigint NULL, RelevantPolicyCount bigint NULL, IsAllowed bit, AccessReason varchar(20) NULL, MatchedGroupCount bigint NULL, StatusCode varchar(40).
TABLE-Preflight im normalen Pfad kann lokale TempDB-Metadaten per DDL ändern und bei ungültiger Zuordnung mit Fehler 51011/Preflightfehler abbrechen. Kein Max-Zeilen-Parameter.
NONE liefert keine fachlichen Resultsets. Statusmeldungen und JSON sind davon unabhängig; @PrintMeldungen=0 unterdrückt weder Hilfe noch JSON.
Beispiel – Hilfe: EXEC [monitor].[USP_CheckAnalyseAccess] @Hilfe=1;
Beispiel – Standard: EXEC [monitor].[USP_CheckAnalyseAccess];
Beispiel – Klasse und RAW: EXEC [monitor].[USP_CheckAnalyseAccess] @AnalyseKlasse='PLAN_CACHE_DEEP', @ResultSetArt='RAW';
Beispiel – nur gesperrte Klassen: EXEC [monitor].[USP_CheckAnalyseAccess] @NurGesperrte=1, @ResultSetArt='RAW';
Beispiel – JSON: DECLARE @j nvarchar(max); EXEC [monitor].[USP_CheckAnalyseAccess] @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;
Beispiel – NONE: EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt='NONE', @JsonErzeugen=1;
Beispiel – TABLE: CREATE TABLE #CheckAnalyseAccess_HelpExample (Seed bit NULL);
DECLARE @map nvarchar(max)=N'{"access":"#CheckAnalyseAccess_HelpExample"}'; EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt='TABLE', @ResultTablesJson=@map; DROP TABLE #CheckAnalyseAccess_HelpExample;
```

