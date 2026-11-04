# [monitor].[USP_ExtendedEventsBlockedProcesses]

**Bereich:** Extended Events<br>
**Zweck:** Liest historische Blocked-Process-Reports und zerlegt blockierte sowie blockierende Prozesse.<br>
**Beobachtungsart:** retentionbegrenzte Ereignishistorie<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Blockings überschritten den konfigurierten Threshold und wurden als Reports erfasst?** Sie unterstützt die Entscheidung, ob die konfigurierte Ereignisquelle die gesuchte Situation erfasst hat und welche einzelne Datei, Session oder XML-Struktur anschließend vertieft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ereignisse, die nicht konfiguriert, vor Sessionstart aufgetreten oder durch Rollover/Targetgrenzen verloren gegangen sind. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, SYSUTCDATETIME());

EXEC [monitor].[USP_ExtendedEventsBlockedProcesses]
      @Quelle = 'AUTO',
      @VonUtc = @ExampleVonUtc,
      @MitReportXml = 0,
      @MitProcessXml = 0,
      @MaxZeilen = 100,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Jeder fachliche Lauf ist als `EXTENDED_EVENTS_FORENSICS_DEEP` geschützt. Die Bestätigung ist für das Gruppengate nötig; Zeitfenster, Quelle und Ereignislimit bleiben die relevanten Schutzgrenzen.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@SourceExtendedEventSessionName` | `nvarchar(258)` | `NULL` | Bezeichnet optional eine konkrete vorhandene Session mit blocked_process_report. NULL sucht automatisch nach einer passenden Session. Ein expliziter Wert muss genau einen gültigen, optional geklammerten sysname ergeben. ungültige oder mehrfache Namen führen zu INVALID_PARAMETER. Leertext ist ungültig. |
| `@Quelle` | `varchar(20)` | `'AUTO'` | Geschlossene Auswahl: AUTO wählt EVENT_FILE, wenn ein expliziter oder konfigurierter Dateipfad vorliegt. andernfalls wird RING_BUFFER nur bei bestätigtem Target-Flush gewählt. EVENT_FILE erzwingt das Dateiziel, RING_BUFFER das laufende Ring-Buffer-Ziel. NULL, leer oder ein anderer Wert ist ungültig. Werte werden getrimmt und in Großbuchstaben umgewandelt. |
| `@FilePath` | `nvarchar(4000)` | `NULL` | Expliziter XEL-Pfad oder URL. NULL oder leer verwendet den Eventfile-Pfad aus der Sessiondefinition. Endet der Pfad auf .xel, wird die Endung durch *.xel ersetzt. andernfalls wird *.xel angehängt, sofern noch kein * enthalten ist. |
| `@VonUtc` | `datetime2(7)` | `NULL` | Untere UTC-Zeitgrenze einschließlich. NULL wird zur Laufzeit auf UTC jetzt minus 24 Stunden gesetzt. |
| `@BisUtc` | `datetime2(7)` | `NULL` | Obere UTC-Zeitgrenze ausschließlich. NULL lässt die Obergrenze offen. Sind beide Grenzen gesetzt, muss @VonUtc kleiner als @BisUtc sein. |
| `@MaxZeilen` | `int` | `200` | Begrenzt die ausgewählten Reports vor der XML-Zerlegung. NULL oder 0 bedeutet unbegrenzt. negative Werte sind ungültig. Die Begrenzung garantiert keinen frühen oder vollständigen Ausschluss des XEL-Dateiscans. |
| `@MitReportXml` | `bit` | `1` | 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert, ob das vollständige blocked_process_report-XML in der Summary ausgegeben wird. 0 unterdrückt die XML-Ausgabe, verhindert aber nicht das Parsing der strukturierten Prozessfelder. |
| `@MitProcessXml` | `bit` | `0` | 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ausgabe des vollständigen Prozess-XML in den Detailresultaten. 0 unterdrückt diese XML-Ausgabe. strukturierte Prozessfelder werden weiterhin extrahiert. |
| `@BestaetigeTargetFlush` | `bit` | `0` | 1 bestätigt den möglichen Target-Flush beim Ringbuffer-Lesen. 0 sperrt den expliziten Ringbufferzugriff. Beim expliziten Aufruf kann NULL die bestehende Prüfung auf 0 passieren. Verwenden Sie ausdrücklich 0 oder 1. AUTO wechselt nur bei 1 zum Ringbuffer. |
| `@HighImpactConfirmed` | `bit` | `0` | 1 bestätigt einen geschützten Pfad nach der aktiven Policy für EXTENDED_EVENTS_FORENSICS_DEEP. 0 bestätigt ihn nicht. NULL ist für die Gate-Prüfung ungültig. Die aktuelle Berechtigung wird zusätzlich geprüft. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Geschlossene Auswahl nach Trimmen und Umwandlung in Großbuchstaben: RAW gibt technische Rohresultate aus, CONSOLE dient der interaktiven Ausgabe, NONE unterdrückt Resultsets zugunsten des OUTPUT-JSON, TABLE schreibt das registrierte Fachresultat in ein bereitgestelltes Ziel. CONSOLE und TABLE werden intern auf NONE gesetzt. NULL, leer und andere Werte sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel reports erforderlich. Der Wert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und #Monitor als Präfix sind ausgeschlossen. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter für das JSON-Ergebnis. Der Wert wird am Prozedurbeginn auf NULL gesetzt. NULL bedeutet, dass kein JSON geliefert wurde oder die Erzeugung nicht bis zu einem Ergebnis gelangte. |
| `@PrintMeldungen` | `bit` | `1` | 1 gibt bei Status außerhalb AVAILABLE und AVAILABLE_LIMITED eine Warnung mit Severity 10 aus. 0 unterdrückt sie. NULL verhält sich über die IF-Bedingung wie aus. |
| `@Hilfe` | `bit` | `0` | 1 zeigt die Hilfe nach der TABLE-Zuordnungsprüfung und beendet den Aufruf vor dem Quellzugriff. 0 und NULL setzen den normalen Aufruf fort. |

## Aufrufbeispiele

```sql
EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @Hilfe=1;
```

```sql
DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc);
EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitReportXml=0,@MitProcessXml=0,@HighImpactConfirmed=1,@ResultSetArt='RAW';
```

```sql
DECLARE @ExampleJson nvarchar(max);
DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc);
EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitReportXml=0,@MitProcessXml=0,@HighImpactConfirmed=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@ExampleJson OUTPUT;
SELECT @ExampleJson AS ExampleJson;
```

```sql
CREATE TABLE #ExampleBlockedReports ([Seed] int NULL);
BEGIN TRY DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc);
EXEC [monitor].[USP_ExtendedEventsBlockedProcesses] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitReportXml=0,@MitProcessXml=0,@HighImpactConfirmed=1,@ResultSetArt='TABLE',@ResultTablesJson=N'{"reports":"#ExampleBlockedReports"}';
SELECT * FROM #ExampleBlockedReports;
DROP TABLE #ExampleBlockedReports;
END TRY BEGIN CATCH DROP TABLE #ExampleBlockedReports;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `reports`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Summary-Zeile = ein Report; Process-Zeile = blockierte oder blockierende Prozessdarstellung innerhalb dieses Reports.

## So lesen

Vergleichen Sie Konfigurierten Threshold, Waitdauer, Blocker/Blocked, Ressource, Statements und Wiederholungen über Zeit.

## Warum kann das problematisch sein?

Wiederholte Reports derselben Kette zeigen persistierendes Blocking statt eines kurzen Snapshots.

## Wann ist es kein Problem?

Ein einzelner Report knapp über dem Threshold kann ein einmaliger langsamer Vorgang sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Alle fünf Sekunden derselbe Root Blocker über zwei Minuten: starke Evidenz. Korrelieren Sie Live mit `USP_CurrentBlocking` und `USP_CurrentTransactions`.

**Ähnlich aussehender Gegenfall:** Ein einzelner Report knapp über dem Threshold kann ein einmaliger langsamer Vorgang sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Eine laufende Session kann ohne passendes Ereignis leer sein; außerdem können Target, Dateipfad, Rollover, Flushzustand und Berechtigung die Sicht einschränken.

Für `USP_ExtendedEventsBlockedProcesses` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Threshold 0, fehlende XE-Konfiguration oder abgelaufene Retention erlauben keine Entwarnung.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die Eigenlast hängt von der Eventdatei und dem XML ab. Die Ergebnismenge ist begrenzt, und ein Vorfilter wird vor der XML-Zerlegung angewandt. XEL-Dateien können dennoch vollständig gelesen werden müssen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | AUTO sucht eine Session mit `blocked_process_report`, bevorzugt deren Eventfile und liest bis zu 200 Reports. Report-XML ist standardmäßig in der Summary enthalten, Prozess-XML nicht; beide Prozessseiten werden dennoch strukturiert aus XML extrahiert. |
| Teuerster Pfad | Unbegrenzter XEL-Wildcard- oder großer Ring-Buffer-Pfad ohne Zeitfenster, `@MitReportXml = 1` und `@MitProcessXml = 1`; Ring Buffer benötigt zusätzlich bestätigten Target-Flush. |
| Haupttreiber | XEL-Rollovermenge beziehungsweise Ring-Buffer-Größe, Zahl ausgewählter Reports und XML-Größe der blockierten/blockierenden Prozessknoten. `sys.configurations` liefert nur den aktuellen Blocked-Process-Threshold. |
| Skalierung | Die Quelle wird auf Reports/UTC gefiltert und TOP-begrenzt, danach wird jeder Report in Summary, blockierten und blockierenden Prozess zerlegt. Vollständige Prozess-XML verbreitert Resultat und Transfer, spart bei `0` aber nicht das notwendige Strukturparsing. |
| Ressourcen | Datei-I/O über das SQL-Server-Dienstkonto, CPU/Speicher für XML-Parsing, TempDB/Transfer für zerlegte Ereignisse. |
| Begrenzungswirkung | UTC-Fenster und konkrete Datei/Session sind die wichtigsten Quellgrenzen. `@MaxZeilen` begrenzt Reports vor dem Prozess-Shredding, kann aber das vorgelagerte Lesen aller passenden Rolloverdateien nicht garantieren. XML-Schalter begrenzen hauptsächlich Ausgabe. |
| Locking und Nebenwirkungen | Keine Sessionkonfiguration wird geändert. Eventfilelesen verursacht Storage-I/O; nur Ring-Buffer-Zugriff liest `sys.dm_xe_session_targets` und kann nach `@BestaetigeTargetFlush = 1` Targetpuffer flushen. Es gibt keinen `sp_server_diagnostics`-Aufruf. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `EXTENDED_EVENTS_FORENSICS_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleSession` oder enges UTC-Fenster, beide XML-Ausgabeschalter aus, `@MaxZeilen = 100` und High-Impact-Bestätigung. Ring Buffer nur nach separater Flushentscheidung. |
| Aussagegrenze | Reports existieren nur bei konfiguriertem Threshold und aktivem Event. Ein Prozess kann im Report bereits beendet sein; gleiche SPID in mehreren Reports ist ohne Zeit/Report-ID nicht dieselbe Ausführung. Rollover und TOP begrenzen historische Vollständigkeit. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Blockings überschritten den konfigurierten Threshold und wurden als Reports erfasst?

### Technischer Hintergrund

`blocked_process_report` entsteht nur bei positivem Blocked Process Threshold und passender XE-Erfassung. XML enthält Blocked/Blocking Process, Waitresource, Lockmode und SQL-/Inputbufferkontext zum Reportzeitpunkt. Lange Blockings können mehrere Reports erzeugen.

### Datenkette

`sys.configurations`, `sys.dm_xe_session_targets`, `sys.dm_xe_sessions`, `sys.fn_xe_file_target_read_file`, `sys.server_event_session_events`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`.

### Source Select

Der Dateipfad filtert Blocked-Process-Events und Zeit bereits vor der XML-Zerlegung:

```sql
SELECT
      [x].[timestamp_utc]
    , [x].[file_name]
    , [x].[file_offset]
    , TRY_CAST([x].[event_data] AS xml) AS [EventXml]
FROM [sys].[fn_xe_file_target_read_file]
     (@EventFilePattern, NULL, NULL, NULL) AS [x]
WHERE [x].[object_name] = N'blocked_process_report'
  AND [x].[timestamp_utc] >= @VonUtc
ORDER BY [x].[timestamp_utc] DESC;
```

**Wichtig für die Eigenlast:** Legen Sie Session, Eventname und Zeitfenster vor XML-Parsing fest. Ring Buffer nur gezielt verwenden; dessen `target_data` wird als Ganzes materialisiert. Ein optionaler Flush ist eine bewusste Nebenwirkung, keine Filtertechnik.

### Zeit- und Scope-Modell

Die Auswertung berücksichtigt historische Thresholdereignisse während einer aktiven Erfassung; sie bildet keine lückenlose Lockhistorie.

### Bewertung und Gegenprobe

Korrelieren Sie Dauer/Anzahl, Rootblocker, offene Transaktion, Ressourcenmuster und wiederholte Reports derselben Kette. Mehrere Reports nicht ungeprüft als verschiedene Vorfälle zählen.

### Typische Fehlinterpretation

Blocking unter Threshold, vor Sessionstart oder nach Rollover fehlt. Reportzeit ist nicht zwingend Beginn/Ende der Blockierung.

### Folgeanalyse

Verwenden Sie bei einer Reproduktion Current Blocking und Current Transactions. Analysieren Sie Zyklen mit der Deadlockanalyse.

## Primärquellen

- [Extended Events](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/extended-events?view=sql-server-ver17)

[Technische Detailbeschreibung](../06_Extended_Events.md#4-monitorusp_extendedeventsblockedprocesses)
