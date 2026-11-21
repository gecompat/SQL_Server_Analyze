---
skill_format_version: "1.0.0"
name: "monitor.USP_ExtendedEventsDeadlocks"
schema_name: "monitor"
object_name: "USP_ExtendedEventsDeadlocks"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen in Summary-, Victim-, Process- und Resource-Resultsets."
source_path: "Code/06_ExtendedEvents/030_USP_ExtendedEventsDeadlocks.sql"
---

# monitor.USP_ExtendedEventsDeadlocks

## Zweck und Einsatz

Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen in Summary-, Victim-, Process- und Resource-Resultsets.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

system_health oder andere bestehende Session; event_file über sys.fn_xe_file_target_read_file, optional ring_buffer über sys.dm_xe_session_targets.

SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE STATE oder höher. Das Framework vergibt keine Rechte.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SourceExtendedEventSessionName | nvarchar(258) | nein | N'system_health' |
| @Quelle | varchar(20) | nein | 'AUTO' |
| @FilePath | nvarchar(4000) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @BisUtc | datetime2(7) | nein | NULL |
| @MaxZeilen | int | nein | 100 |
| @MitDeadlockXml | bit | nein | 1 |
| @MitProcessDetails | bit | nein | 1 |
| @MitResourceDetails | bit | nein | 1 |
| @BestaetigeTargetFlush | bit | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@SourceExtendedEventSessionName:** @SourceExtendedEventSessionName nvarchar(258). Default ist N'system_health'. Bezeichnet genau eine vorhandene Extended-Events-Session, die xml_deadlock_report erfasst. Der Name darf optional geklammert sein. NULL, eine ungültige Angabe oder mehrere Namen ergeben INVALID_PARAMETER. Leertext ist ungültig.

**@Quelle:** @Quelle varchar(20). Default ist 'AUTO'. Geschlossene Auswahl: AUTO wählt EVENT_FILE, wenn ein expliziter oder konfigurierter Dateipfad vorliegt. andernfalls wird RING_BUFFER nur bei bestätigtem Target-Flush gewählt. EVENT_FILE erzwingt das Dateiziel, RING_BUFFER das laufende Ring-Buffer-Ziel. NULL, leer oder ein anderer Wert ist ungültig. Werte werden getrimmt und in Großbuchstaben umgewandelt.

**@FilePath:** @FilePath nvarchar(4000). Default ist NULL. Expliziter XEL-Pfad oder URL. NULL oder leer verwendet den in der Sessiondefinition konfigurierten Eventfile-Pfad. Endet der Pfad auf .xel, wird diese Endung durch *.xel ersetzt. Enthält er kein * und endet nicht auf .xel, wird *.xel angehängt. Ein expliziter Pfad kann AUTO zur Wahl des Eventfiles führen.

**@VonUtc:** @VonUtc datetime2(7). Default ist NULL. Untere UTC-Zeitgrenze einschließlich. NULL wird zur Laufzeit auf UTC jetzt minus 24 Stunden gesetzt. Ein expliziter Wert ersetzt diesen Standard.

**@BisUtc:** @BisUtc datetime2(7). Default ist NULL. Obere UTC-Zeitgrenze ausschließlich. NULL lässt die Obergrenze offen. Sind beide Grenzen gesetzt, muss @VonUtc kleiner als @BisUtc sein.

**@MaxZeilen:** @MaxZeilen int. Default ist 100. Begrenzt die ausgewählten Deadlockereignisse vor der Graphzerlegung. NULL oder 0 bedeutet unbegrenzt. negative Werte sind ungültig. Eine Begrenzung kann den vollständigen physischen Scan von XEL-Rolloverdateien nicht verhindern.

**@MitDeadlockXml:** @MitDeadlockXml bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ausgabe des vollständigen Deadlock-XML in der Summary. 0 unterdrückt diese XML-Spalte, verhindert aber nicht das Einlesen und die für die übrigen Resultate erforderliche Graphverarbeitung.

**@MitProcessDetails:** @MitProcessDetails bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Prozessdetailausgabe und deren Detailzerlegung. Die für Victim- und Summary-Ausgaben erforderliche Verarbeitung bleibt davon unberührt.

**@MitResourceDetails:** @MitResourceDetails bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ressourcendetails einschließlich Owner-/Waiter-XML. 0 fordert diese Detailausgabe nicht an.

**@BestaetigeTargetFlush:** @BestaetigeTargetFlush bit. Default ist 0. 1 bestätigt den möglichen Target-Flush beim Ringbuffer-Lesen. 0 sperrt den expliziten Ringbufferzugriff. Beim expliziten Aufruf kann NULL die bestehende Prüfung auf 0 passieren. Verwenden Sie ausdrücklich 0 oder 1. AUTO wechselt nur bei 1 zum Ringbuffer.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 1 bestätigt einen geschützten Pfad nach der aktiven Policy für EXTENDED_EVENTS_FORENSICS_DEEP. 0 bestätigt ihn nicht. NULL ist für die Gate-Prüfung ungültig. Die aktuelle Berechtigung wird zusätzlich geprüft.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. Geschlossene Auswahl nach Trimmen und Umwandlung in Großbuchstaben: RAW gibt technische Rohresultate aus, CONSOLE dient der interaktiven Ausgabe, NONE unterdrückt Resultsets zugunsten des OUTPUT-JSON, TABLE schreibt das registrierte Fachresultat in ein bereitgestelltes Ziel. CONSOLE und TABLE werden intern auf NONE gesetzt, bevor die Fachresultate ausgegeben/geschrieben werden. NULL, leer und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel deadlocks erforderlich. Der Wert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und #Monitor als Präfix sind ausgeschlossen. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT-Parameter für das erzeugte JSON. Der Wert wird am Prozedurbeginn auf NULL gesetzt. NULL bedeutet daher, dass kein JSON geliefert wurde oder die Erzeugung nicht bis zu einem Ergebnis gelangte.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt bei Status außerhalb AVAILABLE und AVAILABLE_LIMITED eine Warnung mit Severity 10 aus. 0 unterdrückt diese Warnmeldung. NULL verhält sich über die IF-Bedingung wie aus, da nur exakt 1 wahr ist.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der TABLE-Zuordnungsprüfung und beendet den Aufruf vor dem Quellzugriff. 0 und NULL setzen den normalen Aufruf fort.

## Resultate und Ausgabe

1. Modulstatus. 2. Deadlock-Summary. 3. Victims. 4. Processes. 5. Resources. 6. Quellen-/Fehlerstatus.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| deadlocks | 1 | 1 | [DeadlockId] int,[SourceType] varchar(20),[DeadlockTimeUtc] datetime2(7),[FileName] nvarchar(260),[FileOffset] bigint,[VictimCount] int,[ProcessCount] int,[ResourceCount] int,[FirstDatabaseId] int NULL,[DeadlockXml] xml NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC monitor.USP_ExtendedEventsDeadlocks; EXEC monitor.USP_ExtendedEventsDeadlocks @Quelle='RING_BUFFER', @BestaetigeTargetFlush=1; EXEC monitor.USP_ExtendedEventsDeadlocks @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1, weil die Abfrage von sys.dm_xe_session_targets einen Flush auslösen kann.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ExtendedEventsDeadlocks
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer
               vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen
               in Summary-, Victim-, Process- und Resource-Resultsets.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : system_health oder andere bestehende Session; event_file über
               sys.fn_xe_file_target_read_file, optional ring_buffer über
               sys.dm_xe_session_targets.
Parameter    : @ResolvedSourceExtendedEventSessionName, @Quelle, @FilePath, @VonUtc, @BisUtc, @MaxZeilen,
               @MitDeadlockXml, @MitProcessDetails, @MitResourceDetails,
               @BestaetigeTargetFlush, @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Deadlock-Summary. 3. Victims. 4. Processes.
               5. Resources. 6. Quellen-/Fehlerstatus.
Berechtigung : SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE
               STATE oder höher. Das Framework vergibt keine Rechte.
Eigenlast    : Event-Datei- und XML-abhängig; Maximalzahl und UTC-Filter werden
               vor der XML-Zerlegung angewandt. Trotzdem können XEL-Dateien
               vollständig gelesen werden müssen.
Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte und keine Änderungen.
Nebenwirkung : Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1, weil die
               Abfrage von sys.dm_xe_session_targets einen Flush auslösen kann.
Partial      : Fehlende Session, Target, Datei oder Rechte liefern Status statt
               Abbruch. Deadlockhistorie ist für den Framework-Core optional.
Beispiele    : EXEC monitor.USP_ExtendedEventsDeadlocks;
               EXEC monitor.USP_ExtendedEventsDeadlocks
                   @Quelle='RING_BUFFER', @BestaetigeTargetFlush=1;
               EXEC monitor.USP_ExtendedEventsDeadlocks @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 5.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ExtendedEventsDeadlocks
Beispiel 1. EXEC [monitor].[USP_ExtendedEventsDeadlocks] @Hilfe=1;
Beispiel 2. DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt='RAW';
Beispiel 3. DECLARE @ExampleJson nvarchar(max); DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS ExampleJson;
Beispiel 4. CREATE TABLE #ExtendedEventsDeadlocks_HelpExample ([Seed] int NULL); BEGIN TRY DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt='TABLE',@ResultTablesJson=N'{"deadlocks":"#ExtendedEventsDeadlocks_HelpExample"}'; SELECT * FROM #ExtendedEventsDeadlocks_HelpExample; DROP TABLE #ExtendedEventsDeadlocks_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsDeadlocks_HelpExample; THROW; END CATCH;
```

