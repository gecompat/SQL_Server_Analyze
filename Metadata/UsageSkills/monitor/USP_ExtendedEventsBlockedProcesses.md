---
skill_format_version: "1.0.0"
name: "monitor.USP_ExtendedEventsBlockedProcesses"
schema_name: "monitor"
object_name: "USP_ExtendedEventsBlockedProcesses"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liest bereits erfasste blocked_process_report-Ereignisse aus vorhandenen Extended-Events-Targets und zerlegt die Reports in Summary-, Blocked- und Blocking-Process-Resultsets."
source_path: "Code/06_ExtendedEvents/040_USP_ExtendedEventsBlockedProcesses.sql"
---

# monitor.USP_ExtendedEventsBlockedProcesses

## Zweck und Einsatz

Liest bereits erfasste blocked_process_report-Ereignisse aus vorhandenen Extended-Events-Targets und zerlegt die Reports in Summary-, Blocked- und Blocking-Process-Resultsets.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

vorhandene serverweite XE-Session mit blocked_process_report, event_file oder optional ring_buffer; sys.configurations lesend.

SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE STATE oder höher. Das Framework vergibt keine Rechte.

Reports existieren nur, wenn blocked process threshold und eine erfassende Session bereits außerhalb des Frameworks konfiguriert sind.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SourceExtendedEventSessionName | nvarchar(258) | nein | NULL |
| @Quelle | varchar(20) | nein | 'AUTO' |
| @FilePath | nvarchar(4000) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @BisUtc | datetime2(7) | nein | NULL |
| @MaxZeilen | int | nein | 200 |
| @MitReportXml | bit | nein | 1 |
| @MitProcessXml | bit | nein | 0 |
| @BestaetigeTargetFlush | bit | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@SourceExtendedEventSessionName:** @SourceExtendedEventSessionName nvarchar(258). Default ist NULL. Bezeichnet optional eine konkrete vorhandene Session mit blocked_process_report. NULL sucht automatisch nach einer passenden Session. Ein expliziter Wert muss genau einen gültigen, optional geklammerten sysname ergeben. ungültige oder mehrfache Namen führen zu INVALID_PARAMETER. Leertext ist ungültig.

**@Quelle:** @Quelle varchar(20). Default ist 'AUTO'. Geschlossene Auswahl: AUTO wählt EVENT_FILE, wenn ein expliziter oder konfigurierter Dateipfad vorliegt. andernfalls wird RING_BUFFER nur bei bestätigtem Target-Flush gewählt. EVENT_FILE erzwingt das Dateiziel, RING_BUFFER das laufende Ring-Buffer-Ziel. NULL, leer oder ein anderer Wert ist ungültig. Werte werden getrimmt und in Großbuchstaben umgewandelt.

**@FilePath:** @FilePath nvarchar(4000). Default ist NULL. Expliziter XEL-Pfad oder URL. NULL oder leer verwendet den Eventfile-Pfad aus der Sessiondefinition. Endet der Pfad auf .xel, wird die Endung durch *.xel ersetzt. andernfalls wird *.xel angehängt, sofern noch kein * enthalten ist.

**@VonUtc:** @VonUtc datetime2(7). Default ist NULL. Untere UTC-Zeitgrenze einschließlich. NULL wird zur Laufzeit auf UTC jetzt minus 24 Stunden gesetzt.

**@BisUtc:** @BisUtc datetime2(7). Default ist NULL. Obere UTC-Zeitgrenze ausschließlich. NULL lässt die Obergrenze offen. Sind beide Grenzen gesetzt, muss @VonUtc kleiner als @BisUtc sein.

**@MaxZeilen:** @MaxZeilen int. Default ist 200. Begrenzt die ausgewählten Reports vor der XML-Zerlegung. NULL oder 0 bedeutet unbegrenzt. negative Werte sind ungültig. Die Begrenzung garantiert keinen frühen oder vollständigen Ausschluss des XEL-Dateiscans.

**@MitReportXml:** @MitReportXml bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert, ob das vollständige blocked_process_report-XML in der Summary ausgegeben wird. 0 unterdrückt die XML-Ausgabe, verhindert aber nicht das Parsing der strukturierten Prozessfelder.

**@MitProcessXml:** @MitProcessXml bit. Default ist 0. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ausgabe des vollständigen Prozess-XML in den Detailresultaten. 0 unterdrückt diese XML-Ausgabe. strukturierte Prozessfelder werden weiterhin extrahiert.

**@BestaetigeTargetFlush:** @BestaetigeTargetFlush bit. Default ist 0. 1 bestätigt den möglichen Target-Flush beim Ringbuffer-Lesen. 0 sperrt den expliziten Ringbufferzugriff. Beim expliziten Aufruf kann NULL die bestehende Prüfung auf 0 passieren. Verwenden Sie ausdrücklich 0 oder 1. AUTO wechselt nur bei 1 zum Ringbuffer.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 1 bestätigt einen geschützten Pfad nach der aktiven Policy für EXTENDED_EVENTS_FORENSICS_DEEP. 0 bestätigt ihn nicht. NULL ist für die Gate-Prüfung ungültig. Die aktuelle Berechtigung wird zusätzlich geprüft.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. Geschlossene Auswahl nach Trimmen und Umwandlung in Großbuchstaben: RAW gibt technische Rohresultate aus, CONSOLE dient der interaktiven Ausgabe, NONE unterdrückt Resultsets zugunsten des OUTPUT-JSON, TABLE schreibt das registrierte Fachresultat in ein bereitgestelltes Ziel. CONSOLE und TABLE werden intern auf NONE gesetzt. NULL, leer und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel reports erforderlich. Der Wert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und #Monitor als Präfix sind ausgeschlossen. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT-Parameter für das JSON-Ergebnis. Der Wert wird am Prozedurbeginn auf NULL gesetzt. NULL bedeutet, dass kein JSON geliefert wurde oder die Erzeugung nicht bis zu einem Ergebnis gelangte.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt bei Status außerhalb AVAILABLE und AVAILABLE_LIMITED eine Warnung mit Severity 10 aus. 0 unterdrückt sie. NULL verhält sich über die IF-Bedingung wie aus.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der TABLE-Zuordnungsprüfung und beendet den Aufruf vor dem Quellzugriff. 0 und NULL setzen den normalen Aufruf fort.

## Resultate und Ausgabe

1. Modulstatus. 2. Report-Summary. 3. blocked process. 4. blocking process. 5. Quellen-/Fehlerstatus.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| reports | 1 | 1 | [ReportId] int,[SourceType] varchar(20),[ReportTimeUtc] datetime2(7),[FileName] nvarchar(260),[FileOffset] bigint,[MonitorLoop] bigint NULL,[BlockedSessionId] int NULL,[BlockingSessionId] int NULL,[WaitTimeMs] bigint NULL,[DatabaseId] int NULL,[DatabaseName] nvarchar(256),[WaitResource] nvarchar(1024),[RequestedLockMode] nvarchar(64),[ReportXml] xml NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC monitor.USP_ExtendedEventsBlockedProcesses; EXEC monitor.USP_ExtendedEventsBlockedProcesses @ResolvedSourceExtendedEventSessionName=N'MeineBlockingSession', @Quelle='EVENT_FILE'; EXEC monitor.USP_ExtendedEventsBlockedProcesses @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ExtendedEventsBlockedProcesses
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liest bereits erfasste blocked_process_report-Ereignisse aus
               vorhandenen Extended-Events-Targets und zerlegt die Reports in
               Summary-, Blocked- und Blocking-Process-Resultsets.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : vorhandene serverweite XE-Session mit blocked_process_report,
               event_file oder optional ring_buffer; sys.configurations lesend.
Parameter    : @ResolvedSourceExtendedEventSessionName, @Quelle, @FilePath, @VonUtc, @BisUtc,
               @MaxZeilen, @MitReportXml, @MitProcessXml,
               @BestaetigeTargetFlush, @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Report-Summary. 3. blocked process.
               4. blocking process. 5. Quellen-/Fehlerstatus.
Berechtigung : SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE
               STATE oder höher. Das Framework vergibt keine Rechte.
Eigenlast    : Event-Datei- und XML-abhängig; begrenzte Ergebnismenge und
               Vorfilter vor XML-Zerlegung. XEL-Dateien können dennoch vollständig
               gelesen werden müssen.
Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte und keine Änderungen.
Nebenwirkung : Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1.
Voraussetzung: Reports existieren nur, wenn blocked process threshold und eine
               erfassende Session bereits außerhalb des Frameworks konfiguriert sind.
Partial      : Fehlende Konfiguration, Session, Datei oder Rechte werden als Status
               gemeldet und brechen andere Monitoring-Funktionen nicht ab.
Beispiele    : EXEC monitor.USP_ExtendedEventsBlockedProcesses;
               EXEC monitor.USP_ExtendedEventsBlockedProcesses
                   @ResolvedSourceExtendedEventSessionName=N'MeineBlockingSession', @Quelle='EVENT_FILE';
               EXEC monitor.USP_ExtendedEventsBlockedProcesses @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 5.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ExtendedEventsBlockedProcesses
Beispiel 1. EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @Hilfe=1;
Beispiel 2. DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitReportXml=0,@MitProcessXml=0,@HighImpactConfirmed=1,@ResultSetArt='RAW';
Beispiel 3. DECLARE @ExampleJson nvarchar(max); DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitReportXml=0,@MitProcessXml=0,@HighImpactConfirmed=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS ExampleJson;
Beispiel 4. CREATE TABLE #ExtendedEventsBlockedProcesses_HelpExample ([Seed] int NULL); BEGIN TRY DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitReportXml=0,@MitProcessXml=0,@HighImpactConfirmed=1,@ResultSetArt='TABLE',@ResultTablesJson=N'{"reports":"#ExtendedEventsBlockedProcesses_HelpExample"}'; SELECT * FROM #ExtendedEventsBlockedProcesses_HelpExample; DROP TABLE #ExtendedEventsBlockedProcesses_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsBlockedProcesses_HelpExample; THROW; END CATCH;
```

