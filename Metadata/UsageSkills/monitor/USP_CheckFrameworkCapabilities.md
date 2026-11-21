---
skill_format_version: "1.0.0"
name: "monitor.USP_CheckFrameworkCapabilities"
schema_name: "monitor"
object_name: "USP_CheckFrameworkCapabilities"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Prüft Framework-Capabilities serverweit und je ausgewählter DB."
source_path: "Code/01_Common/070_USP_CheckFrameworkCapabilities.sql"
---

# monitor.USP_CheckFrameworkCapabilities

## Zweck und Einsatz

Prüft Framework-Capabilities serverweit und je ausgewählter DB.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CheckFrameworkCapabilities]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `sys.dm_tran_locks`, `sys.dm_db_log_info`, `sys.dm_db_index_physical_stats`, `[monitor].[VW_AnalyseClassCatalog]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[monitor].[VW_FrameworkFeatureCatalog]`, `[monitor].[VW_AnalyseAccessCurrent]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @AnalyseKlasse | varchar(64) | nein | NULL |
| @NurNichtVerfuegbar | bit | nein | 0 |
| @MitGruppenpruefung | bit | nein | 1 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames: nvarchar(max), Default NULL. NULL, leer oder nur äußere U+0020 bedeutet keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger Datenbanknamen: | trennt außerhalb [..], ]] maskiert darin ]; äußere U+0020 je Element werden entfernt. Elemente müssen als einzelner SQL-Name via PARSENAME erkennbar und höchstens 128 Zeichen (sysname) sein; Rohsegment höchstens 4000 UTF-16-Codeeinheiten. Leere/fehlerhafte Elemente, ungültige Namen und Duplikate nach SQL_Latin1_General_CP1_CS_AS-Vergleich ergeben INVALID_PARAMETER. Groß-/Kleinschreibung wird unterschieden. Keine Anzahlgrenze im Helper. Nur bei einer nach dieser Normalisierung nichtleeren Liste ist ein nicht-NULL @DatabaseNamePattern unzulässig. Ausgelassen = unbeschränkte Auswahl sichtbarer, onlineer, zugänglicher Benutzerdatenbanken.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen: bit, Default 0. 0 schließt master, tempdb, model und msdb aus; 1 erlaubt sie. NULL ergibt INVALID_PARAMETER. Numerische Argumente konvertiert SQL Server vor Eintritt in bit: 0 bleibt 0, jeder Nichtnullwert wird 1. Ausgelassen = ausschließen.

**@DatabaseNamePattern:** @DatabaseNamePattern: nvarchar(4000), Default NULL. NULL bedeutet kein Pattern. Sonst äußere U+0020 mit LTRIM/RTRIM trimmen; Präfix regexi:, regex: oder like: wird ohne Beachtung der Großschreibung erkannt und entfernt, sonst LIKE. Rest nach Präfix wird nicht nochmals getrimmt. LIKE ist case-sensitiv, unterstützt %, _, [Zeichenklassen]; regex: ist case-sensitiv, regexi: case-insensitiv. Leere Eingabe oder leerer Rest ist ungültig. Jedes nicht-NULL Pattern ist mit einer nichtleeren @DatabaseNames-Liste exklusiv. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; sonst UNAVAILABLE_FEATURE. Ausgelassen = keine Einschränkung.

**@HighImpactConfirmed:** @HighImpactConfirmed: bit, Default 0. 1 übergibt die Bestätigung an den Datenbankkandidaten-Helper; 0 bestätigt nicht. NULL ergibt INVALID_PARAMETER. Numerische Werte werden vorab in bit konvertiert (Nichtnull wird 1). Diese Procedure übergibt Analyseklasse NULL an den Helper; daher wird hier kein klassenabhängiges High-Impact-Gate ausgelöst. Ausgelassen = 0.

**@AnalyseKlasse:** @AnalyseKlasse: varchar(64), Default NULL. NULL oder ausgelassen wählt alle Features. Sonst Vergleich mit VW_AnalyseClassCatalog unter SQL_Latin1_General_CP1_CS_AS, ohne LTRIM/RTRIM; Groß-/Kleinschreibung zählt, SQL-Gleichheit kann nachgestellte U+0020 auffüllen. Leer oder nicht passend ergibt INVALID_PARAMETER. Begrenzt Featurekombinationen vor den Probes. Zulässige Klassen mit Bedeutung:

**@NurNichtVerfuegbar:** @NurNichtVerfuegbar: bit, Default 0. 0 gibt alle Capabilityzeilen aus; 1 nur IsUsable=0. NULL wirkt wegen des tatsächlichen SQL-Prädikats ebenfalls als Filter auf IsUsable=0. Evaluation und Summary bleiben vollständig; der Filter spart keine Probes. Ausgelassen = 0.

**@MitGruppenpruefung:** @MitGruppenpruefung: bit, Default 1. 1 prüft je Feature die Access-View; bei Deny oder Prüfungsfehler wird die Probe übersprungen. 0 oder NULL überspringt die Gruppenprüfung. Numerische Nichtnullwerte werden vorab zu bit 1 konvertiert. Ausgelassen = 1.

**@ResultSetArt:** @ResultSetArt: varchar(16), Default 'CONSOLE'. Werte: CONSOLE übergibt Capabilities dem Console-Renderer; RAW liefert Meta, Capabilities, Summary und Warnings; TABLE exportiert ausschließlich Capabilities; NONE unterdrückt fachliche Resultsets. Äußere U+0020 werden mit LTRIM/RTRIM entfernt, danach UPPER. NULL/sonst ungültig ergibt INVALID_PARAMETER. Ausgelassen = CONSOLE.

**@ResultTablesJson:** @ResultTablesJson: nvarchar(max), Default NULL. NULL/ausgelassen bedeutet keine Zuordnung. Für TABLE ist ein gültiges JSON-Objekt mit genau dem nach U+0020-Trimmen case-sensitiven Schlüssel "capabilities" und einem nach U+0020-Trimmen nichtleeren JSON-String als Ziel erforderlich; Schlüssel und Ziele müssen eindeutig sein. Ziel: vorhandene leere lokale #temp-Tabelle, kein ##, LEN höchstens 116, nicht #Monitor* (case-insensitiv), genau eine beliebig typisierte Seed-Spalte. Der Preflight fügt vorübergehend eine bit-NULL-Prüfspalte hinzu und entfernt sie; daraus folgt kein bit/NULL-Zwang für die Seed-Spalte. U+0020 außen wird für Objektklammern getrimmt. Leeres/ungültiges JSON-Objekt, falsche Schlüssel/Werttypen, leere Namen, Duplikate, unzulässige Namen oder fehlendes/gefülltes/mehrspaltiges Ziel schlagen im Preflight fehl (THROW 51011). Außerhalb TABLE führt eine nichtleere Zuordnung zu THROW 51011.

**@JsonErzeugen:** @JsonErzeugen: bit, Default 0. 1 erzeugt @Json mit meta, capabilities, summary und warnings; 0 oder NULL erzeugt keines. Ausgelassen = 0.

**@Json:** @Json: nvarchar(max), Default NULL OUTPUT. Als OUTPUT-Variable binden, um JSON zu empfangen; ohne Erzeugung bleibt NULL. Der Eingangswert wird vor TABLE-Preflight und Hilfe auf NULL gesetzt. Ausgelassen ist möglich, dann kann kein Ergebnis empfangen werden.

**@PrintMeldungen:** @PrintMeldungen: bit, Default 1. 1 gibt Severity 10 bei Gesamtfehler oder mindestens einer nicht nutzbaren Capability aus. 0/NULL unterdrückt nur diese Meldung, nicht Resultsets oder JSON. Ausgelassen = 1.

**@Hilfe:** @Hilfe: bit, Default 0. 1 gibt Hilfe aus und beendet vor Kandidatenauswahl und Capability-Probes; NULL/0 führt normal aus. @Json wird zuvor auf NULL gesetzt. Der Hilfezweig kehrt vor dem TABLE-Preflight zurück; im normalen Pfad kann dieser TempDB-Metadaten ändern oder abbrechen. @PrintMeldungen unterdrückt Hilfe nicht.

## Resultate und Ausgabe

RAW, CONSOLE, TABLE oder NONE; optional JSON mit capabilities, summary, warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| capabilities | 1 | 1 | [FeatureOrdinal] smallint NOT NULL , [FeatureCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FeatureName] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ScopeType] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [AnalysisClass] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [AnalysisLevel] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsResourceIntensive] bit NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ServerMajorVersion] int NULL , [ServerProductVersion] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [MinimumMajorVersion] tinyint NOT NULL , [VersionSupported] bit NOT NULL , [GroupCheckApplied] bit NOT NULL , [GroupAccessAllowed] bit NULL , [AccessReason] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RequiredPermissionScope] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [PermissionCheckType] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RequiredPermission] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PermissionDisplayText] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [HasRequiredPermission] bit NULL , [IsQueryable] bit NOT NULL , [IsFeatureEnabled] bit NULL , [IsUsable] bit NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Description] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CheckFrameworkCapabilities] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CheckFrameworkCapabilities prüft katalogisierte Framework-Capabilities serverweit und je ausgewählter Datenbank. Quellen: Featurekatalog, Servereigenschaften, Datenbankkandidaten, Access-View, Permissionfunktionen und leichte dynamische Probe-/Enablementabfragen.

Eine Katalogzeile allein ist keine Laufzeitqualifikation. Die Procedure führt die katalogisierten Probe- und Enablement-SQL-Templates aus, ruft aber nicht automatisch spätere Fachmodule auf. Die Templates sind hinsichtlich Zugriffsumfang zu prüfen.

Die Procedure vergibt keine Rechte. Probeerfolg oder Metadatenrechte belegen weder vollständige Sichtbarkeit späterer Fachdaten noch externe Gesundheit oder erfolgreiche Fachanalyse.

  STANDARD_CURRENT = leichte aktuelle Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O

  EXTENDED_CURRENT = gezielte aktuelle Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CheckFrameworkCapabilities
Version      : 2.0.1
Stand        : 2026-07-16
Zweck        : Prüft Framework-Capabilities serverweit und je ausgewählter DB.
Datenbanken  : @DatabaseNames bracket-aware Pipe-Liste; NULL/N''=alle.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optional JSON mit capabilities, summary,
               warnings.
Änderungen   : 2.0.1 - SQL-Literal-Escaping für Datenbanknamen korrigiert.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CheckFrameworkCapabilities prüft katalogisierte Framework-Capabilities serverweit und je ausgewählter Datenbank. Quellen: Featurekatalog, Servereigenschaften, Datenbankkandidaten, Access-View, Permissionfunktionen und leichte dynamische Probe-/Enablementabfragen.
Eine Katalogzeile allein ist keine Laufzeitqualifikation. Die Procedure führt die katalogisierten Probe- und Enablement-SQL-Templates aus, ruft aber nicht automatisch spätere Fachmodule auf. Die Templates sind hinsichtlich Zugriffsumfang zu prüfen.
Die Procedure vergibt keine Rechte. Probeerfolg oder Metadatenrechte belegen weder vollständige Sichtbarkeit späterer Fachdaten noch externe Gesundheit oder erfolgreiche Fachanalyse.
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
CONSOLE übergibt capabilities an den Console-Renderer. RAW liefert vier Resultsets: Meta, Capabilities, Summary und Warnings. TABLE schreibt ausschließlich das benannte capabilities-Resultset; NONE unterdrückt fachliche Resultsets.
Bei @Hilfe=1 erfolgt kein TABLE-Preflight; im normalen Pfad validiert er das lokale Ziel per temporärer Metadaten-DDL und kann bei ungültigem Ziel mit Fehler abbrechen. @Json wird vor dem Hilfezweig auf NULL gesetzt; @PrintMeldungen unterdrückt sie nicht.
Beispiel – Hilfe: EXEC [monitor].[USP_CheckFrameworkCapabilities] @Hilfe=1;
Beispiel – Standard: EXEC [monitor].[USP_CheckFrameworkCapabilities];
Beispiel – Scope und RAW: EXEC [monitor].[USP_CheckFrameworkCapabilities] @DatabaseNames=N'[ExampleDb]', @AnalyseKlasse='STANDARD_CURRENT', @ResultSetArt='RAW';
Beispiel – JSON/NONE: DECLARE @j nvarchar(max); EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;
Beispiel – TABLE-Ziel: CREATE TABLE #CheckFrameworkCapabilities_HelpExample (Seed bit NULL);
DECLARE @map nvarchar(max)=N'{"capabilities":"#CheckFrameworkCapabilities_HelpExample"}'; EXEC [monitor].[USP_CheckFrameworkCapabilities] @ResultSetArt='TABLE', @ResultTablesJson=@map; DROP TABLE #CheckFrameworkCapabilities_HelpExample;
```

