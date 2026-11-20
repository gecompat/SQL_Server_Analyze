---
skill_format_version: "1.0.0"
name: "monitor.USP_ExtendedEventsSessions"
schema_name: "monitor"
object_name: "USP_ExtendedEventsSessions"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert vorhandene serverweite Extended-Events-Sessions, deren Definitionen, Laufzeitstatus, Events, Actions, Targets und explizit konfigurierte Felder."
source_path: "Code/06_ExtendedEvents/010_USP_ExtendedEventsSessions.sql"
---

# monitor.USP_ExtendedEventsSessions

## Zweck und Einsatz

Inventarisiert vorhandene serverweite Extended-Events-Sessions, deren Definitionen, Laufzeitstatus, Events, Actions, Targets und explizit konfigurierte Felder. Es werden keine Sessions erstellt, gestartet, gestoppt, geändert oder gelöscht.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.server_event_sessions, sys.server_event_session_events, sys.server_event_session_actions, sys.server_event_session_targets, sys.server_event_session_fields, optional sys.dm_xe_sessions.

SQL Server 2019 VIEW SERVER STATE; SQL Server 2022+ VIEW SERVER PERFORMANCE STATE oder höher. Das Framework vergibt keine Rechte.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ExtendedEventSessionNames | nvarchar(max) | nein | NULL |
| @ExtendedEventSessionNamePattern | nvarchar(4000) | nein | NULL |
| @EventNames | nvarchar(max) | nein | NULL |
| @EventNamePattern | nvarchar(4000) | nein | NULL |
| @TargetNames | nvarchar(max) | nein | NULL |
| @TargetNamePattern | nvarchar(4000) | nein | NULL |
| @NurLaufend | bit | nein | 0 |
| @MitLaufzeitstatus | bit | nein | 1 |
| @MitEvents | bit | nein | 1 |
| @MitActions | bit | nein | 1 |
| @MitTargets | bit | nein | 1 |
| @MitFeldern | bit | nein | 0 |
| @MaxZeilen | int | nein | 5000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @MitZeitgrenzen | bit | nein | 0 |

**@ExtendedEventSessionNames:** @ExtendedEventSessionNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger SQL-Namen. Einträge können in eckigen Klammern stehen. Pipe trennt nur außerhalb der Klammern. Eine schließende Klammer wird innen verdoppelt. NULL deaktiviert den Filter. Leere und ungültige Einträge werden abgelehnt. Verwenden Sie für dieselbe Eigenschaft entweder die Liste oder das Muster.

**@ExtendedEventSessionNamePattern:** @ExtendedEventSessionNamePattern nvarchar(4000). Default ist NULL. Ohne Präfix oder mit LIKE: gilt SQL LIKE mit % und _. REGEX: ist ein Regex mit Beachtung der Groß- und Kleinschreibung. REGEXI: ignoriert sie. Regex benötigt SQL Server 2025 und Compatibility Level 170. NULL deaktiviert den Filter. Ein leeres Muster ist ungültig. Verwenden Sie entweder Liste oder Muster.

**@EventNames:** @EventNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger SQL-Namen. Einträge können in eckigen Klammern stehen. Pipe trennt nur außerhalb der Klammern. Eine schließende Klammer wird innen verdoppelt. NULL deaktiviert den Filter. Leere und ungültige Einträge werden abgelehnt. Verwenden Sie für dieselbe Eigenschaft entweder die Liste oder das Muster.

**@EventNamePattern:** @EventNamePattern nvarchar(4000). Default ist NULL. Ohne Präfix oder mit LIKE: gilt SQL LIKE mit % und _. REGEX: ist ein Regex mit Beachtung der Groß- und Kleinschreibung. REGEXI: ignoriert sie. Regex benötigt SQL Server 2025 und Compatibility Level 170. NULL deaktiviert den Filter. Ein leeres Muster ist ungültig. Verwenden Sie entweder Liste oder Muster.

**@TargetNames:** @TargetNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger SQL-Namen. Einträge können in eckigen Klammern stehen. Pipe trennt nur außerhalb der Klammern. Eine schließende Klammer wird innen verdoppelt. NULL deaktiviert den Filter. Leere und ungültige Einträge werden abgelehnt. Verwenden Sie für dieselbe Eigenschaft entweder die Liste oder das Muster.

**@TargetNamePattern:** @TargetNamePattern nvarchar(4000). Default ist NULL. Ohne Präfix oder mit LIKE: gilt SQL LIKE mit % und _. REGEX: ist ein Regex mit Beachtung der Groß- und Kleinschreibung. REGEXI: ignoriert sie. Regex benötigt SQL Server 2025 und Compatibility Level 170. NULL deaktiviert den Filter. Ein leeres Muster ist ungültig. Verwenden Sie entweder Liste oder Muster.

**@NurLaufend:** @NurLaufend bit. Default ist 0. 0 lässt laufende und gestoppte Sessions zu. 1 beschränkt die Auswahl auf laufende Sessions. NULL wird bei aktivierten Zeitgrenzen auf 1 gesetzt und erfüllt den Vergleich mit 0 auch sonst nicht.

**@MitLaufzeitstatus:** @MitLaufzeitstatus bit. Default ist 1. 1 ergänzt verfügbare Werte aus sys.dm_xe_sessions. 0 oder NULL lässt diese Erhebung aus.

**@MitEvents:** @MitEvents bit. Default ist 1. 1 liest konfigurierte Events. 0 oder NULL lässt diese Details aus.

**@MitActions:** @MitActions bit. Default ist 1. 1 liest konfigurierte Actions. 0 oder NULL lässt diese Details aus.

**@MitTargets:** @MitTargets bit. Default ist 1. 1 liest Targetdefinitionen. 0 oder NULL lässt diese Details aus.

**@MitFeldern:** @MitFeldern bit. Default ist 0. 1 liest explizit konfigurierte Felder. 0 oder NULL lässt diese Details aus.

**@MaxZeilen:** @MaxZeilen int. Default ist 5000. Eine positive Ganzzahl begrenzt die einzelnen Sammlungen. NULL oder 0 hebt das Limit auf. Negative Werte sind ungültig.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt beschriftete Ergebnisse. RAW liefert Status und die technischen Inventurresultsets. TABLE schreibt die zugeordneten Resultsets. NONE unterdrückt Datenresultsets. Rand-Leerzeichen werden entfernt und die Groß- und Kleinschreibung normalisiert. NULL, Leertext und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Ohne Zeitgrenzen ist sessions der einzige Schlüssel. Mit @MitZeitgrenzen=1 können Sie sessions, timeBounds oder beide zuordnen. Jeder Wert benennt als Zeichenfolge eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Ziele müssen verschieden sein. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, Leertext und reine Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt das JSON-Dokument unabhängig von der Ausgabeart. 0 oder NULL erzeugt kein JSON.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL und füllt sie bei @JsonErzeugen=1.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt informative Warnmeldungen aus. 0 oder NULL unterdrückt sie.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 gibt die Hilfe nach der Prüfung von @ResultTablesJson aus und beendet den Aufruf vor dem fachlichen Zugriff. 0 oder NULL setzt den normalen Aufruf fort.

**@MitZeitgrenzen:** @MitZeitgrenzen bit. Default ist 0. 1 ergänzt timeBounds und verwendet JSON-Schema 2. Eine Restzeit ist eine Schätzung. 0 oder NULL verwendet JSON-Schema 1 ohne timeBounds.

## Resultate und Ausgabe

1. Modulstatus. 2. Sessions. 3. Events. 4. Actions. 5. Targets. 6. konfigurierte Felder. 7. timeBounds nur mit @MitZeitgrenzen=1. Nicht aktivierte alte Resultsets bleiben leer.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| sessions | 1 | 1 | [EventSessionId] int NOT NULL, [SessionName] sysname NOT NULL, [IsRunning] bit NOT NULL, [StartupState] bit NULL, [EventRetentionMode] nchar(1) NULL, [EventRetentionModeDesc] nvarchar(60) NULL, [MaxDispatchLatencyMilliseconds] int NULL, [MaxMemoryKb] int NULL, [MaxEventSizeKb] int NULL, [MemoryPartitionMode] nchar(1) NULL, [MemoryPartitionModeDesc] nvarchar(60) NULL, [TrackCausality] bit NULL, [RunningSince] datetime NULL, [PendingBuffers] int NULL, [TotalRegularBuffers] int NULL, [RegularBufferSizeBytes] bigint NULL, [TotalLargeBuffers] int NULL, [LargeBufferSizeBytes] bigint NULL, [TotalBufferSizeBytes] bigint NULL, [BufferPolicyDesc] nvarchar(256) NULL, [DroppedEventCount] int NULL, [DroppedBufferCount] int NULL, [BlockedEventFireTimeMilliseconds] int NULL, [LargestEventDroppedSizeBytes] int NULL, [BufferProcessedCount] bigint NULL, [BufferFullCount] bigint NULL, [TotalBytesGenerated] bigint NULL, [TotalTargetMemoryBytes] bigint NULL, [EventCount] int NULL, [TargetCount] int NULL, [ActionCount] int NULL, [HasRingBuffer] bit NULL, [HasEventFile] bit NULL |
| timeBounds | 1 | 1 | [EventSessionId] int NOT NULL, [SessionName] sysname NOT NULL, [MaxDurationSeconds] bigint NULL, [IsTimeBound] bit NULL, [RuntimeState] varchar(40) NOT NULL, [RunningSince] datetime NULL, [RemainingSecondsEstimate] bigint NULL, [SourceStatus] varchar(40) NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) NULL, [CollectionTimeUtc] datetime2(3) NOT NULL, [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC monitor.USP_ExtendedEventsSessions; EXEC monitor.USP_ExtendedEventsSessions @SessionNameLike=N'system_health'; EXEC monitor.USP_ExtendedEventsSessions @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_ExtendedEventsSessions

Die Procedure inventarisiert serverweite Extended-Events-Sessions und ergänzt auf Wunsch Laufzeitwerte und Zeitgrenzen.

Hilfe anzeigen. EXEC [monitor].[USP_ExtendedEventsSessions] @Hilfe=1;

Technische Resultsets lesen. EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=N'ExampleXeSession', @MaxZeilen=100, @ResultSetArt='RAW';

Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=N'ExampleXeSession', @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ExtendedEventsSessions
Version      : 1.1.0
Stand        : 2026-10-13
Typ          : Stored Procedure
Zweck        : Inventarisiert vorhandene serverweite Extended-Events-Sessions,
               deren Definitionen, Laufzeitstatus, Events, Actions, Targets und
               explizit konfigurierte Felder. Es werden keine Sessions erstellt,
               gestartet, gestoppt, geändert oder gelöscht.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.server_event_sessions, sys.server_event_session_events,
               sys.server_event_session_actions, sys.server_event_session_targets,
               sys.server_event_session_fields, optional sys.dm_xe_sessions.
Parameter    : @SessionNameLike, @NurLaufend, @MitLaufzeitstatus, @MitEvents,
               @MitActions, @MitTargets, @MitFeldern, @MaxZeilen,
               @PrintMeldungen, @Hilfe, @MitZeitgrenzen.
Resultsets   : 1. Modulstatus. 2. Sessions. 3. Events. 4. Actions. 5. Targets.
               6. konfigurierte Felder. 7. timeBounds nur mit @MitZeitgrenzen=1.
               Nicht aktivierte alte Resultsets bleiben leer.
Berechtigung : SQL Server 2019 VIEW SERVER STATE; SQL Server 2022+ VIEW SERVER
               PERFORMANCE STATE oder höher. Das Framework vergibt keine Rechte.
Eigenlast    : Gering. Es werden nur Extended-Events-Katalogviews und optional
               sys.dm_xe_sessions gelesen. Targetdaten werden nicht gelesen.
Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte, keine Änderungen.
Partial      : Fehlende Berechtigungen liefern strukturierte Status- und leere
               Ergebnis-Resultsets; andere Framework-Module bleiben nutzbar.
Beispiele    : EXEC monitor.USP_ExtendedEventsSessions;
               EXEC monitor.USP_ExtendedEventsSessions @SessionNameLike=N'system_health';
               EXEC monitor.USP_ExtendedEventsSessions @Hilfe=1;
Änderungen   : 1.1.0 - Opt-in Zeitgrenzen mit isolierter Konfigurations-/Runtimeerfassung und unverändertem Defaultvertrag.
               1.0.2 - total_target_memory wird nur bei nachgewiesener Spaltenverfügbarkeit gelesen; SQL Server 2019 liefert NULL.
               1.0.1 - Alias [ObjectType] für die sortierte Feldklassifikation ergänzt.
               1.0.0 - Erstfassung Phase 5.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ExtendedEventsSessions
Die Procedure inventarisiert serverweite Extended-Events-Sessions und ergänzt auf Wunsch Laufzeitwerte und Zeitgrenzen.
Hilfe anzeigen. EXEC [monitor].[USP_ExtendedEventsSessions] @Hilfe=1;
Technische Resultsets lesen. EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=N'ExampleXeSession', @MaxZeilen=100, @ResultSetArt='RAW';
Nur JSON ausgeben. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=N'ExampleXeSession', @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Ein Resultset in eine lokale Temp-Tabelle schreiben. CREATE TABLE #ExtendedEventsSessions_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ExtendedEventsSessions] @ExtendedEventSessionNames=N'ExampleXeSession', @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"sessions":"#ExtendedEventsSessions_HelpExample"}'; SELECT * FROM #ExtendedEventsSessions_HelpExample; DROP TABLE #ExtendedEventsSessions_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsSessions_HelpExample; THROW; END CATCH;
```

