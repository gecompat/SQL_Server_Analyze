---
skill_format_version: "1.0.0"
name: "monitor.USP_ExtendedEventsReadEvents"
schema_name: "monitor"
object_name: "USP_ExtendedEventsReadEvents"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liest Ereignisse aus einem bereits vorhandenen event_file- oder ring_buffer-Target."
source_path: "Code/06_ExtendedEvents/020_USP_ExtendedEventsReadEvents.sql"
---

# monitor.USP_ExtendedEventsReadEvents

## Zweck und Einsatz

Liest Ereignisse aus einem bereits vorhandenen event_file- oder ring_buffer-Target. Die Procedure ist eine optionale Forensik- quelle und wird von keinem Standard-Current-State-Modul benötigt.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.server_event_sessions/-targets/-fields, sys.fn_xe_file_target_read_file, optional sys.dm_xe_session_targets.

SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE STATE beziehungsweise für Filezugriff ggf. VIEW DATABASE PERFORMANCE STATE. Zusätzlich muss SQL Server die Datei lesen können.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SourceExtendedEventSessionName | nvarchar(258) | nein | N'system_health' |
| @Quelle | varchar(20) | nein | 'EVENT_FILE' |
| @FilePath | nvarchar(4000) | nein | NULL |
| @EventNames | nvarchar(max) | nein | NULL |
| @EventNamePattern | nvarchar(4000) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @BisUtc | datetime2(7) | nein | NULL |
| @MaxZeilen | int | nein | 1000 |
| @MitEventXml | bit | nein | 1 |
| @BestaetigeTargetFlush | bit | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@SourceExtendedEventSessionName:** @SourceExtendedEventSessionName nvarchar(258). Default ist N'system_health'. Genau ein einteiliger Name der serverweiten XE-Session, optional in eckigen Klammern. NULL, Leertext und mehrere Namen sind ungültig.

**@Quelle:** @Quelle varchar(20). Default ist 'EVENT_FILE'. EVENT_FILE liest XEL-Dateien. RING_BUFFER liest den Ringbuffer. AUTO wählt EVENT_FILE, wenn ein expliziter oder konfigurierter Dateipfad vorliegt. Ohne Pfad kann AUTO mit bestätigtem Flush den Ringbuffer wählen. Ein Lesefehler löst keinen Fallback aus. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.

**@FilePath:** @FilePath nvarchar(4000). Default ist NULL. XEL-Pfad, Muster oder URL für EVENT_FILE. NULL oder eine leere Zeichenfolge verwendet bei der Pfadauflösung den konfigurierten Pfad. Ein lokaler Dateiname kann zu einem Rollvermuster erweitert werden. Begrenzen Sie den Zugriff auf die benötigten Dateien.

**@EventNames:** @EventNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger SQL-Namen. Einträge können in eckigen Klammern stehen. Pipe trennt nur außerhalb der Klammern. Eine schließende Klammer wird innen verdoppelt. NULL deaktiviert den Filter. Leere und ungültige Einträge werden abgelehnt. Verwenden Sie für dieselbe Eigenschaft entweder die Liste oder das Muster.

**@EventNamePattern:** @EventNamePattern nvarchar(4000). Default ist NULL. Ohne Präfix oder mit LIKE: gilt SQL LIKE mit % und _. REGEX: ist ein Regex mit Beachtung der Groß- und Kleinschreibung. REGEXI: ignoriert sie. Regex benötigt SQL Server 2025 und Compatibility Level 170. NULL deaktiviert den Filter. Ein leeres Muster ist ungültig. Verwenden Sie entweder Liste oder Muster. Regex wird nach der Materialisierung angewandt.

**@VonUtc:** @VonUtc datetime2(7). Default ist NULL. Inklusive Untergrenze als UTC-Zeitwert, z. B. 2026-01-01T00:00:00. NULL lässt die Untergrenze aus.

**@BisUtc:** @BisUtc datetime2(7). Default ist NULL. Exklusive Obergrenze als UTC-Zeitwert. NULL lässt sie aus. Bei zwei Grenzen muss diese später als @VonUtc liegen.

**@MaxZeilen:** @MaxZeilen int. Default ist 1000. Eine positive Ganzzahl begrenzt die zurückgehaltenen Events. NULL oder 0 hebt das Limit auf. Negative Werte sind ungültig. Das Limit begrenzt den physischen XEL-Scan nicht zuverlässig.

**@MitEventXml:** @MitEventXml bit. Default ist 1. 1 liefert vollständiges Event-XML in RAW und JSON. 0 oder NULL lässt es dort aus. CONSOLE und TABLE enthalten EventXml weiterhin. Die XML-Konvertierung und Feldextraktion bleiben aktiv.

**@BestaetigeTargetFlush:** @BestaetigeTargetFlush bit. Default ist 0. Nur 1 bestätigt, dass der Zugriff auf sys.dm_xe_session_targets einen Flush auslösen kann. 0 oder NULL verweigert RING_BUFFER ohne DMV-Zugriff. Für einen AUTO-Fallback muss der Wert 1 sein. Verwenden Sie für bestätigten Ringbufferzugriff ausdrücklich 1.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 1 bestätigt den Pfad EXTENDED_EVENTS_FORENSICS_DEEP. 0 bestätigt ihn nicht und NULL ist für die Gate-Prüfung ungültig. Die aktuelle Berechtigung wird zusätzlich geprüft.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt beschriftete Ergebnisse. RAW liefert Modulstatus, Ereignisse und Quellenstatus. TABLE schreibt die zugeordneten Resultsets. NONE unterdrückt Datenresultsets. Rand-Leerzeichen werden entfernt und die Groß- und Kleinschreibung normalisiert. NULL, Leertext und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Der einzige zulässige Schlüssel ist events. Jeder Wert benennt als Zeichenfolge eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Ziele müssen verschieden sein. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, Leertext und reine Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt das JSON-Dokument unabhängig von der Ausgabeart. 0 oder NULL erzeugt kein JSON.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL und füllt sie bei @JsonErzeugen=1.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt informative Warnmeldungen aus. 0 oder NULL unterdrückt sie.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 gibt die Hilfe nach der Prüfung von @ResultTablesJson aus und beendet den Aufruf vor dem fachlichen Zugriff. 0 oder NULL setzt den normalen Aufruf fort.

## Resultate und Ausgabe

1. Modulstatus. 2. normalisierte Events. 3. Quell-/Fehlerstatus.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| events | 1 | 1 | [SourceType] varchar(20) NOT NULL, [EventName] sysname NULL, [TimestampUtc] datetime2(7) NULL, [FileName] nvarchar(260) NULL, [FileOffset] bigint NULL, [EventXml] xml NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC monitor.USP_ExtendedEventsReadEvents @ResolvedSourceExtendedEventSessionName=N'system_health', @Quelle='EVENT_FILE', @EventNamePattern=N'xml_deadlock_report', @MaxZeilen=100; EXEC monitor.USP_ExtendedEventsReadEvents @ResolvedSourceExtendedEventSessionName=N'system_health', @Quelle='RING_BUFFER', @BestaetigeTargetFlush=1; EXEC monitor.USP_ExtendedEventsReadEvents @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Das Lesen von sys.dm_xe_session_targets kann einen Target-Flush auslösen und erfordert daher @BestaetigeTargetFlush=1.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ExtendedEventsReadEvents
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liest Ereignisse aus einem bereits vorhandenen event_file- oder
               ring_buffer-Target. Die Procedure ist eine optionale Forensik-
               quelle und wird von keinem Standard-Current-State-Modul benötigt.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.server_event_sessions/-targets/-fields,
               sys.fn_xe_file_target_read_file, optional sys.dm_xe_session_targets.
Parameter    : @ResolvedSourceExtendedEventSessionName, @Quelle, @FilePath, @EventNamePattern, @VonUtc,
               @BisUtc, @MaxZeilen, @MitEventXml, @BestaetigeTargetFlush,
               @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. normalisierte Events. 3. Quell-/Fehlerstatus.
Berechtigung : SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE
               STATE beziehungsweise für Filezugriff ggf. VIEW DATABASE
               PERFORMANCE STATE. Zusätzlich muss SQL Server die Datei lesen können.
Eigenlast    : Abhängig von Anzahl und Größe der XEL-Dateien bzw. Ringbufferdaten.
               File-Lesen und XML-Konvertierung sind explizit Deep/opt-in.
Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte und keine Änderungen.
Nebenwirkung : Das Lesen von sys.dm_xe_session_targets kann einen Target-Flush
               auslösen und erfordert daher @BestaetigeTargetFlush=1.
Partial      : Fehlende Sessions, Targets, Dateien oder Rechte werden strukturiert
               gemeldet; andere Framework-Module bleiben funktionsfähig.
Beispiele    : EXEC monitor.USP_ExtendedEventsReadEvents
                   @ResolvedSourceExtendedEventSessionName=N'system_health', @Quelle='EVENT_FILE',
                   @EventNamePattern=N'xml_deadlock_report', @MaxZeilen=100;
               EXEC monitor.USP_ExtendedEventsReadEvents
                   @ResolvedSourceExtendedEventSessionName=N'system_health', @Quelle='RING_BUFFER',
                   @BestaetigeTargetFlush=1;
               EXEC monitor.USP_ExtendedEventsReadEvents @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 5.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ExtendedEventsReadEvents
Die Procedure liest Ereignisse aus XEL-Dateien oder dem Ringbuffer. Begrenzen Sie den Zugriff auf die benötigte Quelle und das benötigte UTC-Zeitfenster.
Hilfe anzeigen. EXEC [monitor].[USP_ExtendedEventsReadEvents] @Hilfe=1;
Technische Resultsets lesen. EXEC [monitor].[USP_ExtendedEventsReadEvents] @SourceExtendedEventSessionName=N'ExampleXeSession', @Quelle='EVENT_FILE', @VonUtc='2026-01-01T00:00:00', @BisUtc='2026-01-02T00:00:00', @MaxZeilen=100, @MitEventXml=0, @HighImpactConfirmed=1, @ResultSetArt='RAW';
Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_ExtendedEventsReadEvents] @SourceExtendedEventSessionName=N'ExampleXeSession', @Quelle='EVENT_FILE', @VonUtc='2026-01-01T00:00:00', @BisUtc='2026-01-02T00:00:00', @MaxZeilen=100, @MitEventXml=0, @HighImpactConfirmed=1, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Ein Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #ExtendedEventsReadEvents_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ExtendedEventsReadEvents] @SourceExtendedEventSessionName=N'ExampleXeSession', @Quelle='EVENT_FILE', @VonUtc='2026-01-01T00:00:00', @BisUtc='2026-01-02T00:00:00', @MaxZeilen=100, @MitEventXml=0, @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"events":"#ExtendedEventsReadEvents_HelpExample"}'; SELECT * FROM #ExtendedEventsReadEvents_HelpExample; DROP TABLE #ExtendedEventsReadEvents_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsReadEvents_HelpExample; THROW; END CATCH;
```

