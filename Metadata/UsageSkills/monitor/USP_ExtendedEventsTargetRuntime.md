---
skill_format_version: "1.0.0"
name: "monitor.USP_ExtendedEventsTargetRuntime"
schema_name: "monitor"
object_name: "USP_ExtendedEventsTargetRuntime"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liest Laufzeitmetriken bereits laufender Extended-Events-Targets wie execution_count, execution_duration_ms und bytes_written."
source_path: "Code/06_ExtendedEvents/050_USP_ExtendedEventsTargetRuntime.sql"
---

# monitor.USP_ExtendedEventsTargetRuntime

## Zweck und Einsatz

Liest Laufzeitmetriken bereits laufender Extended-Events-Targets wie execution_count, execution_duration_ms und bytes_written. Targetdaten können optional begrenzt ausgegeben werden.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.dm_xe_sessions, sys.dm_xe_session_targets.

SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE STATE oder höher. Das Framework vergibt keine Rechte.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ExtendedEventSessionNames | nvarchar(max) | nein | NULL |
| @ExtendedEventSessionNamePattern | nvarchar(4000) | nein | NULL |
| @TargetNames | nvarchar(max) | nein | NULL |
| @TargetNamePattern | nvarchar(4000) | nein | NULL |
| @MitTargetData | bit | nein | 0 |
| @MaxTargetDataZeichen | int | nein | 4000 |
| @BestaetigeTargetFlush | bit | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@ExtendedEventSessionNames:** @ExtendedEventSessionNames nvarchar(max). Default ist NULL. NULL deaktiviert den Exaktnamenfilter. Andernfalls pipe-getrennte Liste exakter einteiliger SQL-Namen; geklammerte Namen und maskierte ]] sind zulässig. Leere Listen und ungültige Namen werden abgelehnt. Nicht mit ExtendedEventSessionNamePattern kombinierbar.

**@ExtendedEventSessionNamePattern:** @ExtendedEventSessionNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres LIKE-Muster, optional mit LIKE:, REGEX: oder REGEXI:; äußere Leerzeichen werden entfernt. Leeres Muster oder leerer Präfixwert ist ungültig. LIKE unterstützt % und _. Regex benötigt SQL Server 2025 mit Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit ExtendedEventSessionNames kombinierbar.

**@TargetNames:** @TargetNames nvarchar(max). Default ist NULL. NULL deaktiviert den Exaktnamenfilter. Andernfalls pipe-getrennte Liste exakter einteiliger SQL-Namen; geklammerte Namen und maskierte ]] sind zulässig. Leere Listen und ungültige Namen werden abgelehnt. Nicht mit TargetNamePattern kombinierbar.

**@TargetNamePattern:** @TargetNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert den Musterfilter. Andernfalls nichtleeres Muster mit optionalem LIKE:, REGEX: oder REGEXI:-Präfix; äußere Leerzeichen werden getrimmt. Leeres Muster oder leerer Präfixwert ungültig. LIKE verwendet % und _. Regex benötigt SQL Server 2025 / Compatibility Level 170 und wird nach Materialisierung angewandt. Nicht mit TargetNames kombinierbar.

**@MitTargetData:** @MitTargetData bit. Default ist 0. 1 projiziert target_data und Zeichen-/Byteumfang; 0 setzt TargetData NULL und TargetDataStatus auf NOT_REQUESTED.

**@MaxTargetDataZeichen:** @MaxTargetDataZeichen int. Default ist 4000. Negative Werte ungültig. 0 bedeutet unbegrenzte nvarchar(max)-Projektion; positiver Wert begrenzt Ausgabezeichen. Gilt nur bei MitTargetData=1; gekürzte Werte erhalten OUTPUT_VALUE_TRUNCATED und können Warnung auslösen.

**@BestaetigeTargetFlush:** @BestaetigeTargetFlush bit. Default ist 0. 1 bestätigt den möglichen Flush beim Lesen von sys.dm_xe_session_targets. 0 sperrt den Zugriff. NULL kann die bestehende Prüfung auf 0 passieren und den DMV-Zugriff auslösen. Verwenden Sie ausdrücklich 0 oder 1.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. Bestätigung für den Policycheck EXTENDED_EVENTS_FORENSICS_DEEP; Standard 0.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. Wird getrimmt und großgeschrieben. Zulässig: RAW, CONSOLE, NONE, TABLE. RAW gibt Status und rohe Targets aus; CONSOLE Status und lesbare Übersicht; NONE unterdrückt Resultsets; TABLE schreibt targets. Andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Nur mit ResultSetArt=TABLE zulässig. Nichtleeres JSON-Objekt mit genau dem Schlüssel targets und dem Namen einer vorhandenen, leeren lokalen #temp-Tabelle mit genau einer NULL-zulässigen Seed-Spalte. NULL/Leerwert, fehlerhafte Zuordnung, Zusatzschlüssel, befülltes Ziel, globale/permanente Tabelle und #Monitor-Präfix werden abgelehnt. Der Writer passt das Ziel an das Resultatschema an.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erstellt JSON unabhängig von ResultSetArt; 0 lässt @Json NULL.

**@Json:** @Json nvarchar(max). Default ist NULL. OUTPUT, anfangs NULL; bei JsonErzeugen=1 JSON-Objekt mit meta, targets und warnings.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt Warnungen als Severity-10-Meldungen aus; 0 unterdrückt sie.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 druckt Hilfe und kehrt vor der Ausführung zurück.

## Resultate und Ausgabe

1. Modulstatus. 2. Target-Laufzeitdaten.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| targets | 1 | 1 | [SourceType] varchar(32) NOT NULL, [SourceObject] nvarchar(256) NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [EvidenceScope] varchar(40) NOT NULL, [IsCurrent] bit NOT NULL, [IsCumulative] bit NOT NULL, [ValueStatus] varchar(40) NOT NULL, [SessionName] nvarchar(256) NOT NULL, [TargetName] nvarchar(60) NOT NULL, [SessionCreateTime] datetime NULL, [ExecutionCount] bigint NOT NULL, [ExecutionDurationMs] bigint NOT NULL, [BytesWritten] bigint NOT NULL, [TargetDataCharacters] bigint NULL, [TargetDataBytes] bigint NULL, [TargetDataIsTruncated] bit NOT NULL, [TargetDataStatus] varchar(40) NOT NULL, [TargetData] nvarchar(max) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC monitor.USP_ExtendedEventsTargetRuntime @ExtendedEventSessionNamePattern=N'system_health', @BestaetigeTargetFlush=1; EXEC monitor.USP_ExtendedEventsTargetRuntime @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Das Lesen von sys.dm_xe_session_targets erzwingt laut Microsoft einen Flush gesammelter Sessiondaten zum Target. Daher ist eine explizite Bestätigung zwingend.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ExtendedEventsTargetRuntime
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liest Laufzeitmetriken bereits laufender Extended-Events-Targets
               wie execution_count, execution_duration_ms und bytes_written.
               Targetdaten können optional begrenzt ausgegeben werden.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_xe_sessions, sys.dm_xe_session_targets.
Parameter    : @ExtendedEventSessionNamePattern, @TargetNamePattern, @MitTargetData,
               @MaxTargetDataZeichen, @BestaetigeTargetFlush,
               @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Target-Laufzeitdaten.
Berechtigung : SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE
               STATE oder höher. Das Framework vergibt keine Rechte.
Eigenlast    : Normalerweise gering, kann aber durch große target_data-Inhalte
               sowie einen Target-Flush merkbar werden.
Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte und keine Änderungen.
Nebenwirkung : Das Lesen von sys.dm_xe_session_targets erzwingt laut Microsoft
               einen Flush gesammelter Sessiondaten zum Target. Daher ist eine
               explizite Bestätigung zwingend.
Partial      : Fehlende Rechte oder gestoppte Sessions werden strukturiert gemeldet.
Beispiele    : EXEC monitor.USP_ExtendedEventsTargetRuntime
                   @ExtendedEventSessionNamePattern=N'system_health', @BestaetigeTargetFlush=1;
               EXEC monitor.USP_ExtendedEventsTargetRuntime @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 5.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ExtendedEventsTargetRuntime
Beispiel 1: EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @ExtendedEventSessionNames=N'ExampleXeSession', @TargetNames=N'ring_buffer', @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt='RAW';
Beispiel 3: DECLARE @xeJson nvarchar(max); EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @ExtendedEventSessionNames=N'ExampleXeSession', @TargetNames=N'ring_buffer', @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@xeJson OUTPUT; SELECT @xeJson AS JsonResult;
Beispiel 4: CREATE TABLE #ExtendedEventsTargetRuntime_HelpExample (Seed int NULL); BEGIN TRY EXEC [monitor].[USP_ExtendedEventsTargetRuntime] @ExtendedEventSessionNames=N'ExampleXeSession', @TargetNames=N'ring_buffer', @BestaetigeTargetFlush=1, @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"targets":"#ExtendedEventsTargetRuntime_HelpExample"}'; SELECT * FROM #ExtendedEventsTargetRuntime_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsTargetRuntime_HelpExample; THROW; END CATCH; DROP TABLE #ExtendedEventsTargetRuntime_HelpExample;
```

