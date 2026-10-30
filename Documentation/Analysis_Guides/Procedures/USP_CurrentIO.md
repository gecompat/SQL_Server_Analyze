# [monitor].[USP_CurrentIO]

**Bereich:** Current State<br>
**Zweck:** Bewertet Datei-I/O kumulativ oder als kurzes Delta-Sample.<br>
**Beobachtungsart:** kumulative Datei-/Counterwerte + optionale Stichprobe<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wie viele I/O-Operationen und Bytes wurden pro Datei verarbeitet, und wie lange dauerten sie?** Sie unterstützt die Entscheidung, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentIO]
      @DatabaseNames = N'[ExampleDatabase]',
      @SampleSeconds = 5,
      @PendingIoEinbeziehen = 1,
      @NurWiederholtPending = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Ohne `@DatabaseNames` oder `@DatabaseNamePattern` werden alle sichtbaren,
online befindlichen Benutzerdatenbanken ausgewertet. Systemdatenbanken bleiben
mit `@SystemdatenbankenEinbeziehen = 0` ausgeschlossen. Das Modul ist
leichtgewichtig und verlangt keine High-Impact-Bestätigung.

Alle `Example*`-Werte im Aufruf sind synthetisch.
Ein Aufruf mit @Hilfe = 1 gibt die vollständigen Parameterverträge und kopierbare CONSOLE-, TABLE- und JSON-Beispiele aus, bevor die fachliche Verarbeitung beginnt.


### Einzelne Parameterverträge

| Parameter | Vollständiger Vertrag |
|---|---|
| `@DatabaseNames` | @DatabaseNames nvarchar(max), Default=NULL; Eingabe: bracket-aware Pipe-Liste exakter, einteiliger Datenbanknamen, z. B. N'[DbA]&#124;[DbB]'; Namen werden case-sensitive verglichen. Ausgelassen/NULL/leer/nur Leerzeichen wählt alle sichtbaren, zugreifbaren, ONLINE befindlichen Benutzerdatenbanken; doppelte oder ungültige Namen erzeugen Auswahlfehler/Warnings, Systemdatenbanken benötigen das Opt-in. Exklusiv mit @DatabaseNamePattern. Das Zeichen `\|` trennt nur außerhalb von `[...]`; in `[...]` bleibt `\|` im Namen, und `]]` maskiert ein inneres `]`. |
| `@SystemdatenbankenEinbeziehen` | @SystemdatenbankenEinbeziehen bit, Default=0; Schalter: 0 schließt master, tempdb, model und msdb aus; 1 erlaubt diese sichtbaren, zugreifbaren ONLINE Datenbanken zusätzlich. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. |
| `@DatabaseNamePattern` | @DatabaseNamePattern nvarchar(4000), Default=NULL; Eingabe: genau ein nichtleeres Pattern, exklusiv mit @DatabaseNames. Kein Präfix oder like: bedeutet case-sensitive SQL-LIKE mit %, _, [...]; regex: case-sensitive regulärer Ausdruck; regexi: case-insensitive regulärer Ausdruck. Präfixerkennung ist case-insensitive, äußere Leerzeichen werden entfernt, Patterninhalt bleibt erhalten. NULL/ausgelassen deaktiviert, leer/Whitespace/Präfix ohne Pattern ist ungültig. regex/regexi benötigen SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. |
| `@HighImpactConfirmed` | @HighImpactConfirmed bit, Default=0; numerischer Schalter: 0/ausgelassen bestätigt nicht, jeder numerische Wert ungleich 0 wird vor Eintritt zu 1 und bestätigt dann. NULL wird wegen ungenutztem Parameter nicht geprüft. Dieser Parameter wird von dieser Procedure nicht gelesen/weitergereicht; tatsächlicher Zugriff bleibt STANDARD_CURRENT ohne High-Impact-Bestätigungsprüfung. |
| `@MinLatencyMs` | @MinLatencyMs decimal(19,3), Default=0 ms; nichtnegative Mindest-Durchschnittslatenz je Datei aus kumulativen Zählern oder Sample-Deltas. Ausgelassen verwendet 0; NULL oder negativer Wert ist INVALID_PARAMETER. Bei null Lese- und Schreiboperationen ist OverallLatencyMs NULL und besteht den Filter nicht. |
| `@SampleSeconds` | @SampleSeconds tinyint, Default=0 Sekunden; ganze Zahl 0..60. 0 nutzt kumulative Counter und einen Pending-Punkt; 1..60 wartet per WAITFOR DELAY zwischen zwei Dateimessungen und bildet Deltas sowie zwei Pending-Beobachtungen. Ausgelassen nutzt 0; NULL ist INVALID_PARAMETER. Laufzeit/Scheduling können Abstand verlängern; Counterreset erhält keinen eigenen Resetstatus. |
| `@PendingIoEinbeziehen` | @PendingIoEinbeziehen bit, Default=1; 1 liest Pending-I/O und Schedulerkontext, 0 überspringt beide Quellen und liefert leere Pending-Menge. Ausgelassen ergibt 1; NULL ist INVALID_PARAMETER. Quellfehler lassen Dateiwerte bestehen und können Status/IsPartial setzen. |
| `@NurWiederholtPending` | @NurWiederholtPending bit, Default=0; 1 verlangt dieselbe Requestadresse in beiden Beobachtungen und setzt @SampleSeconds=1..60 voraus; 0 genügt Sichtbarkeit am letzten Messpunkt. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. Bei 0-Sample ist Wiederholung nicht nachgewiesen. |
| `@MinPendingIoMs` | @MinPendingIoMs bigint, Default=0 ms; nichtnegative Untergrenze für dm_io_pending_io_requests.PendingDurationMs, informational/internal Enginewert. Ausgelassen ergibt 0; NULL oder negativ ist INVALID_PARAMETER. Einzelwert beweist weder Fehler noch Ursache. |
| `@PhysischePfadeEinbeziehen` | @PhysischePfadeEinbeziehen bit, Default=0; 1 gibt pendingIo.PhysicalPath aus, wenn auflösbar; 0 unterdrückt dieses optionale Pfadfeld, während files.PhysicalName bleibt. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. |
| `@MaxZeilen` | @MaxZeilen int, Default=1000 Zeilen; ganze Zahl 0..2147483647. NULL oder 0 ist unbegrenzt; positiv begrenzt Datei- und Pending-Kandidaten getrennt nach ihrer Sortierung (N+1-Prüfung), CONSOLE zusätzlich mit gemeinsamem TOP, Pending zuerst. Negativ ist INVALID_PARAMETER. Ausgelassen ergibt 1000; beschränkt nicht die instanzweite DMV-Erhebung. |
| `@ResultSetArt` | @ResultSetArt varchar(16), Default='CONSOLE'; nach Trim/UPPER taxativ CONSOLE (gemeinsames 10-Spalten-Evidenzgrid), RAW (moduleStatus 13, sourceStatus 10, files 19, pendingIo 20, warnings 3 Spalten), TABLE (nur angeforderte benannte Temp-Tabellenexporte), NONE (keine Resultsets). Ausgelassen ergibt CONSOLE; NULL/leer normalisiert zu '' und ist ungültig. Andere Werte INVALID_PARAMETER. |
| `@ResultTablesJson` | @ResultTablesJson nvarchar(max), Default=NULL; nur TABLE: JSON-Objekt mit einer nichtleeren Teilmenge der exakten Keys moduleStatus (Modulstatus), sourceStatus (Quellstatus), files (Dateimessungen), pendingIo (offene E/A-Anforderungen), warnings (Warnungen); jeder Wert ist ein lokaler #Temp-Zielname als JSON-String. Ziel muss vorhanden und leer sein und genau eine Seed-Platzhalterspalte besitzen; Zuordnung wird vor semantischer Parameterprüfung validiert, ungültig wirft 51011. Bei anderem Modus nur NULL/leer, sonst 51011. Ausgelassen/NULL oder leer ist nur außerhalb TABLE zulässig; TABLE benötigt die nichtleere Zuordnung. |
| `@JsonErzeugen` | @JsonErzeugen bit, Default=0; 1 erzeugt zusätzlich JSON unabhängig von @ResultSetArt; 0 deaktiviert es. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. JSON enthält meta, sourceStatus, files, pendingIo, warnings, aber kein moduleStatus-Array. |
| `@Json` | @Json nvarchar(max) OUTPUT, Default=NULL; optionale Empfangsvariable gleichen Typs, beim Aufruf mit OUTPUT zu binden. Procedure setzt sie beim Eintritt auf NULL; bei @JsonErzeugen=1 empfängt sie das Dokument, bei 0 bleibt sie NULL. Ausgelassen ist zulässig, wenn JSON-Ausgabe nicht benötigt wird. |
| `@PrintMeldungen` | @PrintMeldungen bit, Default=1; 1 sendet Severity-10-Status-/Quellmeldungen, 0 unterdrückt nur Meldungen. Ausgelassen ergibt 1; NULL ist INVALID_PARAMETER. Status, Resultsets, Warnings und JSON bleiben davon unberührt. |
| `@Hilfe` | @Hilfe bit, Default=0; 1 druckt Hilfe und kehrt vor Parameter-, Snapshot- und Fachquellenprüfung zurück; @Json wird zuvor auf NULL gesetzt. 0 führt Normalpfad aus. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. Numerische Eingaben werden vor Eintritt in bit konvertiert, jeder Wert ungleich 0 wird 1. |
| `@ParentCurrentStateSnapshotId` | @ParentCurrentStateSnapshotId uniqueidentifier, Default=NULL; NULL/ausgelassen erhebt Kontext direkt. GUID muss zur laufenden USP_CurrentOverview-Ausführung derselben Session (OwnerSessionId=@@SPID, ContractVersion=2) gehören; sonst INVALID_PARENT_SNAPSHOT. Bei gültiger ID und aktiviertem Pending stammen Kontext und Startzeit vom Parent, Datei-/Pending-DMVs bleiben live. |

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind `moduleStatus`, `sourceStatus`, `files`, `pendingIo` und `warnings` registriert. `files` enthält kumulative oder gesampelte Dateiwerte. `pendingIo` enthält den flüchtigen Pending-I/O-Snapshot beziehungsweise bei einem Sample die zweite Beobachtung; `ObservationCount=2` bedeutet, dass dieselbe Requestadresse an beiden Messpunkten eines Samples sichtbar war. Bei `@SampleSeconds=0` wird die erste Beobachtung kopiert; `WasPresentInFirstSample=1` und `ObservationCount=1` belegen dabei keine zweite Messung. Schedulerwerte sind nur gleichzeitiger Kontext und keine kausale Requestzuordnung. Physische Pfade erscheinen in `pendingIo` nur bei `@PhysischePfadeEinbeziehen=1`; `files.PhysicalName` ist davon unabhängig. CONSOLE enthält eine gemeinsame lesbare Menge aus Pending-I/O und Dateien. Status und Vollständigkeit stehen in RAW, den typisierten Statuszielen und JSON. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung bestimmt; JSON übernimmt die fachliche Hüllensemantik.

## Eine Zeile bedeutet

In `files` entspricht eine Zeile einer Datenbankdatei im gewählten Scope. Im Samplemodus beschreiben Raten und Latenzen die Differenz zwischen zwei Messpunkten. In `pendingIo` entspricht eine Zeile einer am letzten Messpunkt noch ausstehenden I/O-Requestadresse, die über das File Handle auf eine sichtbare Datenbankdatei abgebildet werden konnte.

## So lesen

Trennen Sie kumulative Durchschnittswerte vom Sample-Delta. Vergleichen Sie Operationen, Bytes und Latenz für Reads und Writes je Datei.

## Warum kann das problematisch sein?

Hohe aktuelle Latenz bei vielen I/O-Operationen kann Requests direkt bremsen. Ein alter kumulativer Durchschnitt kann hingegen durch ein historisches Ereignis verzerrt sein.

## Wann ist es kein Problem?

Eine einzige seltene langsame Operation kann einen extremen Durchschnitt erzeugen, ohne aktuelle Relevanz.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 500 ms Durchschnitt bei einer Operation seit Start: schwach. 25 ms im 10-Sekunden-Sample bei zehntausenden Reads plus `PAGEIOLATCH`: starke I/O-Spur. Korrelieren Sie betroffene Queries und externes Storage-Monitoring.

**Ähnlich aussehender Gegenfall:** Eine einzige seltene langsame Operation kann einen extremen Durchschnitt erzeugen, ohne aktuelle Relevanz. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentIO` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Mit Default `@SampleSeconds = 0` wird `sys.dm_io_virtual_file_stats(NULL,NULL)` einmal und Pending I/O als Snapshot gelesen; die Dateiwerte sind kumulativ, keine aktuelle Rate. |
| Teuerster Pfad | `@SampleSeconds = 60`, Pending I/O an, alle sichtbaren Datenbanken und unbegrenzte Ausgabe: Datei- und Pending-Quellen werden zweimal beobachtet, dazwischen bleibt die Session im WAITFOR. |
| Haupttreiber | Anzahl Dateien, Pending Requests und Schedulerkontext sowie ein oder zwei instanzweite Beobachtungen. |
| Skalierung | Snapshotkosten wachsen annähernd mit der Dateizahl. Das Delta benötigt zwei vollständige Messpunkte; Sortierung nach Latenz erfolgt danach. Transferkosten hängen vom Limit ab, die DMV-Aufrufe selbst nicht im selben Maß. |
| Ressourcen | SQLOS-DMV-CPU, kleine Temp-Tabellen, Join auf `master.sys.master_files` und bei Sampling eine wartende Verbindung. Kein Dateiinhalt und keine Nutzdatentabelle werden gelesen. |
| Begrenzungswirkung | Datenbankscope filtert die behaltenen DMV-Zeilen, ändert aber nicht die Funktionssignatur `dm_io_virtual_file_stats(NULL,NULL)`. `@MaxZeilen` begrenzt zunächst die sortierten Kandidaten auf N+1. Nach Zählern und Statusbewertung werden Datei- und Pending-Menge mit ihrer bestehenden Sortierung auf N begrenzt. RAW, TABLE und JSON verwenden diese Mengen; CONSOLE wendet zusätzlich ein gemeinsames TOP mit Pending-I/O vor Dateien an. NULL und 0 bedeuten unbegrenzt. Die Quelle wird dadurch nicht auf N Zeilen beschränkt. |
| Locking und Nebenwirkungen | Read-only; WAITFOR hält die Session, aber die Procedure hält keine Nutzdatenlocks absichtlich über das Intervall. Ein Restart oder Counterreset zwischen den Messpunkten kann Differenzen unbrauchbar machen; die Procedure besitzt dafür keinen eigenen Reset-Guard. |
| Schutzmechanismus | Scope, maximal 60 Sekunden, Zeilenlimit, getrennte Quellstatus und opt-in physische Pfade. `@NurWiederholtPending=1` verlangt ein Sample. |
| Sicherer Einsatz | Eine `ExampleDatabase`, fünf Sekunden, `@MaxZeilen = 100` und nur ein Sampler. Für Baselinefragen mehrere getrennte Intervalle statt vieler paralleler Aufrufe erfassen. |
| Aussagegrenze | Kumulative Latenz ist ein Lebenszeitmittel und kann aktuelle Probleme verdünnen; ein kurzes Delta kann einzelne Bursts überbetonen. Nicht ausgewählte Datenbanken fehlen, und Top-N nach Latenz kann stark ausgelastete, aber schnellere Dateien verdrängen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie viele I/O-Operationen und Bytes wurden pro Datei verarbeitet, und wie lange dauerten sie?

### Technischer Hintergrund

`sys.dm_io_virtual_file_stats` liefert kumulative Read-/Writeanzahl, Bytes und Stalls pro Datei. Aus Differenzen zweier Messungen entstehen Durchsatz und Latenz. `sys.dm_io_pending_io_requests` liefert flüchtige ausstehende Requestadressen und einen informational/internal Pending-Zähler. File Handles verbinden diese Sicht mit Dateien. Scheduler-, Request- und I/O-Wait-Anzahlen werden nur aggregiert als gleichzeitiger Kontext ergänzt.

### Ausgabe

CONSOLE liefert ohne separates Meta-Grid eine gemeinsame zehnspaltige Ansicht aus Pending-I/O und Dateien. Das gemeinsame Zeilenlimit bevorzugt Pending-I/O; die Ansicht entspricht deshalb nicht der Summe beider JSON-Arrays. Bei leerer Ausgabe erscheint eine Zeile mit `Ergebnis`, `Status` und `Hinweis`.

TABLE verwendet `@ResultTablesJson` mit `moduleStatus` (13 Felder), `sourceStatus` (10), `files` (19), `pendingIo` (20) und `warnings` (3). Alle 23 Textfelder dieser Exporte besitzen die Framework-Collation. Einzelne Zuordnungen sind zulässig; nicht zugeordnete Ziele werden nicht verändert. Gültige Zuordnungen werden vor der semantischen Parameterprüfung vorbereitet. Ungültige Zuordnungen werfen weiterhin 51011. Bei semantischer Ablehnung gelten die vollständigen angeforderten Schemata und `INVALID_PARAMETER`; Datei- und Pending-Mengen bleiben leer, Status- und Warnungsevidenz wird weiter ausgegeben. NULL für Sample oder Pending wird nur im nichtnullfähigen `moduleStatus` als 0 dargestellt; JSON behält die übergebenen NULL-Argumente.

Die Quellstatuszähler beschreiben die N+1-Vorauswahl beziehungsweise den Schedulerkontext. Sie sind keine Zähler eines unbegrenzten Instanzbestands. Der Kontextzugriff findet auch bei einer erfolgreich gelesenen, leeren Pending-Quelle statt; Quellfehler müssen im Quellstatus geprüft werden und erscheinen nicht automatisch als Datenbankwarning.

### Datenkette

`master.sys.master_files`, `sys.dm_io_virtual_file_stats`, `sys.dm_io_pending_io_requests`, `sys.dm_os_schedulers`, `sys.dm_os_tasks`, `sys.dm_os_waiting_tasks`, `sys.dm_exec_requests`.

### Source Select

Die Datei-DMV wird je Messzeitpunkt genau einmal gelesen und erst dann mit dem gewünschten Datenbankscope verbunden:

```sql
SELECT
      [d].[name] AS [DatabaseName]
    , [v].[file_id]
    , [v].[num_of_reads]
    , [v].[io_stall_read_ms]
    , [v].[num_of_writes]
    , [v].[io_stall_write_ms]
FROM [sys].[dm_io_virtual_file_stats](NULL, NULL) AS [v]
JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id] = [v].[database_id]
WHERE [d].[name] = N'ExampleDatabase';
```

**Wichtig für die Eigenlast:** Rufen Sie die DMV nicht in einer Datenbankschleife erneut auf. Pending-I/O und Scheduler- beziehungsweise Taskkontext sind optionale zweite Quellen. Aktivieren Sie diese nur, wenn die Dateiwerte oder das Symptom die Vertiefung rechtfertigen.

### Zeit- und Scope-Modell

Dateizähler sind kumulativ seit Start/Dateizustand oder ein Sampledelta. Pending I/O ist ein flüchtiger Snapshot; eine wiederholte Adresse in zwei Samples erhöht die Relevanz, beweist aber weder Dauer außerhalb des Fensters noch Storageursache.

### Bewertung und Gegenprobe

Bewerten Sie Reads und Writes getrennt. Berücksichtigen Sie die Latenz immer zusammen mit Operationszahl, Bytes und Sampledauer. Daten- und Logdateien besitzen unterschiedliche I/O-Muster. Parallel sichtbare PAGEIOLATCH-, WRITELOG- und Requestwerte erhöhen die Evidenz.

### Typische Fehlinterpretation

Eine einzelne Operation mit 500 ms erzeugt 500 ms Durchschnitt, aber keine anhaltende Last. DMV-Stall enthält Queueing aus SQL-Sicht, nicht automatisch reine Geräte-Servicezeit.

### Folgeanalyse

Verwenden Sie für die weitere Analyse `USP_CurrentRequests`, `USP_CurrentWaits`, `USP_CurrentLog` sowie externe OS- und Storage-Telemetrie.

## Primärquellen

- [sys.dm_io_virtual_file_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-io-virtual-file-stats-transact-sql?view=sql-server-ver17)
- [sys.dm_io_pending_io_requests](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-io-pending-io-requests-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#8-monitorusp_currentio)
