# [monitor].[USP_WorkerPressureAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Trennt Worker-Warteschlangen von CPU-Runnable-Queues und korreliert begrenzten Laufzeitkontext.<br>
**Beobachtungsart:** kurzer Scheduler-Delta- und flüchtiger Worker-/Wait-/Request-Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet: **Warten Tasks auf einen Worker, warten bereits gebundene Worker auf CPU oder ist im kurzen Sample keine solche Queue sichtbar?** Bei positivem `@SampleSeconds` werden sichtbare Online-Scheduler zweimal beobachtet; bei 0 bleibt es bei einer Aufnahme ohne Deltas. Worker werden sofort je Scheduler aggregiert; `THREADPOOL`, Blocking sowie begrenzte laufende Requests ergänzen den Kontext am Sampleende. SQL-, Plan-, Login-, Host- und Programmnamen werden nicht gelesen.

Die Trennung ist zentral: `work_queue_count` beschreibt Tasks, die auf einen Worker warten. `runnable_tasks_count` beschreibt Worker mit gebundener Task, die auf Schedulerzeit warten. Ein positiver Runnable-Wert ist deshalb CPU-Kontext und kein Beleg für Worker-Erschöpfung. Das Summary priorisiert sichtbare Worker-Queues und `THREADPOOL`; es empfiehlt niemals automatisch, `max worker threads` zu ändern.

## Nicht beantwortete Fragen

Ein einsekündiges Sample ist keine Historie. Kurze Bursts vor oder nach dem Aufruf fehlen. Workerzahl und konfigurierte/effective Grenzwerte erklären nicht, welche Workload die Kapazität bindet. Ohne Query-, Plan- oder externen Verlaufskontext werden weder verursachende Statements noch ein dauerhaftes Kapazitätsproblem bewiesen. `AvailableWorkerCapacity` ist ein technischer Kontextwert, kein SLO.

Die Procedure misst keine reine OS-CPU-Auslastung und keine Hypervisor-Sättigung. Ein Runnable-Signal kann durch SQL-Workload, externe CPU-Konkurrenz, Präemption oder andere Faktoren entstehen. Blocking kann Worker binden, muss aber nicht die primäre Ursache sein. Parallelität, lange Requests und Ressourcenengpässe bleiben Hypothesen für Folgeanalysen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_WorkerPressureAnalysis]
      @SampleSeconds = 1,
      @MinRequestElapsedMs = 5000,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

`@MinRequestElapsedMs = 2147483647` begrenzt die Aufnahme allein über die Laufzeit; `THREADPOOL`- und blockierte Requests bleiben unabhängig davon enthalten. Ein leerer Requestkontext ist damit nicht garantiert. Vermeiden Sie mehrere parallele Sampler. Variieren Sie den Zeitraum erst bei wiederholter Queue-Evidenz und korrelieren Sie anschließend unabhängige CPU-, Wait- und Requestdaten.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@SampleSeconds` | `tinyint` | `1` | Legt das Scheduler-Sample in Sekunden fest. Zulässig sind 0 bis 60. 0 verwendet eine Scheduleraufnahme und liefert keine Deltas; 1 bis 60 warten für die angegebene Dauer zwischen zwei Scheduleraufnahmen und berechnen daraus Deltas. Worker-, Wait- und Requestdaten bleiben Snapshots am Sampleende. NULL ist ungültig. |
| `@MinRequestElapsedMs` | `int` | `5000` | Schließt aktuelle Requests ab dieser Laufzeit in Millisekunden in den Requestkontext ein. Zulässig sind 0 bis 2.147.483.647; 0 nimmt alle aktuellen Requests auf, sofern sie nicht bereits wegen THREADPOOL oder Blocking erfasst werden. THREADPOOL- und blockierte Requests werden unabhängig von diesem Mindestwert berücksichtigt. Der Wert begrenzt weder die Sampledauer noch die Gesamtzahl der Serverrequests. NULL ist ungültig. |
| `@MaxZeilen` | `int` | `1000` | Begrenzt nur die ausgegebenen Requestzeilen, nicht Scheduler, Waits oder andere Gruppen. Ein positiver Wert ist die Höchstzahl; 0 oder NULL bedeutet unbegrenzt. Negative Werte sind ungültig. Für Werte von 1 bis 2.147.483.646 werden höchstens eine zusätzliche Requestzeile als Kürzungssentinel materialisiert und danach entfernt; die Ausgabe priorisiert THREADPOOL, danach blockierte Requests, danach lange Requests und sortiert innerhalb der Gruppen nach Laufzeit absteigend. Bei 2.147.483.647 gilt die Integer-Obergrenze; es wird keine zusätzliche Sentinelzeile angefordert. Der Statusdatensatz weist eine erkannte Kürzung über HasMoreRequestRows aus. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Wählt die Resultsetausgabe. Nach Entfernen führender und nachfolgender Leerzeichen und Umwandlung in Großbuchstaben sind genau CONSOLE, RAW, TABLE und NONE zulässig. CONSOLE liefert eine beschriftete Summary-Ansicht. RAW liefert sieben getrennte Resultsets in der Reihenfolge moduleStatus, summary, schedulers, waits, requests, sourceStatus, warnings. TABLE schreibt nur die in @ResultTablesJson gemappten Gruppen in bereits vorhandene lokale #Temp-Tabellen. NONE erzeugt keine regulären Resultsets. NULL, Leertext und andere Werte sind ungültig. @JsonErzeugen steuert unabhängig davon die JSON-OUTPUT-Ausgabe. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Enthält eine TABLE-Zuordnung als JSON-Objekt, etwa {"summary":"#WorkerSummary"}. Erlaubte Namen: moduleStatus, summary, schedulers, waits, requests, sourceStatus, warnings. Ziele müssen vorhandene leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein; globale Tabellen, reservierte #Monitor-Namen, unbekannte Namen sowie doppelte Zuordnungen oder Ziele werden abgewiesen. Außerhalb von TABLE akzeptiert die Validierung NULL, leeren Text oder nur U+0020-Leerzeichen; jeder andere nichtleere Wert ist ungültig. In TABLE muss der gemeinsame Preflight ein gültiges nichtleeres Mapping und passende Seed-Tabellen validieren. Zielnamen sind höchstens 116 Zeichen lang. Der Preflight prüft die Zuordnung und Ziele; der spätere Writer ersetzt die Seed-Spalte durch das Ergebnisschema. Die Gruppen bedeuten: moduleStatus Modulstatus, summary Zusammenfassung, schedulers Schedulerwerte, waits Wartegruppen, requests Requestkontext, sourceStatus Quellenstatus, warnings Warnungen. |
| `@JsonErzeugen` | `bit` | `0` | 0 lässt @Json NULL; 1 erzeugt das JSON-Dokument unabhängig von @ResultSetArt. NULL ist ungültig. Die Eingabe wird auf bit konvertiert: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. Das Dokument enthält meta, summary, schedulers, waits, requests, sourceStatus und warnings; requests folgt dem Zeilenlimit. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter für das optionale JSON-Dokument. Wird am Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Ein gebundener Variablenwert kann mit OUTPUT empfangen werden; das Argument darf ausgelassen werden, wenn kein JSON benötigt wird. |
| `@PrintMeldungen` | `bit` | `1` | Steuert nur die Zusatzmeldung mit RAISERROR-Schweregrad 10 und NOWAIT bei einem Status ungleich AVAILABLE. 0 unterdrückt die Meldung, 1 gibt sie aus; Resultsets und OUTPUT-Werte bleiben unabhängig. NULL ist ungültig. Die Eingabe wird auf bit konvertiert: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@Hilfe` | `bit` | `0` | Bei 1 wird die PRINT-Hilfe ausgegeben und vor Validierung sowie Fachabfragen zurückgekehrt. @Json ist zu diesem Zeitpunkt NULL; Status-OUTPUT-Parameter werden nicht zugewiesen. Bei 0 oder NULL läuft die normale Analyse. Die Eingabe wird auf bit konvertiert: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | OUTPUT-Status im normalen Analysepfad: AVAILABLE bedeutet keine Teilquellenwarnung; AVAILABLE_LIMITED kennzeichnet mindestens eine eingeschränkte Quelle; INVALID_PARAMETER bezeichnet ungültige Parameter; DENIED_PERMISSION meldet verweigerte Schedulerquelle; TIMEOUT meldet ein Scheduler-Timeout; ERROR_HANDLED meldet einen sonstigen abgefangenen Schedulerfehler. Fehler der Worker-, Wait- und Requestquellen werden als Teilstatus/Warnungen aggregiert und ergeben typischerweise AVAILABLE_LIMITED. Im Hilfe-Pfad erfolgt keine Zuweisung. Das OUTPUT-Argument kann ausgelassen werden, wenn der Status nicht empfangen werden soll. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | OUTPUT-Bit: 0 für AVAILABLE, 1 bei AVAILABLE_LIMITED oder Fehlerstatus. Im Hilfe-Pfad erfolgt keine Zuweisung; ein gebundener NULL-Eingang bleibt NULL, ein anderer Anfangswert unverändert. Das OUTPUT-Argument kann ausgelassen werden, wenn der Wert nicht empfangen werden soll. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT-Fehlernummer, sofern für eine maßgebliche Warnung oder einen Schedulerfehler verfügbar, sonst NULL. Im Hilfe-Pfad erfolgt keine Zuweisung; ein gebundener Anfangswert bleibt erhalten. Das OUTPUT-Argument kann ausgelassen werden, wenn der Wert nicht empfangen werden soll. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT-Fehler- oder Hinweismeldung, sofern vorhanden, sonst NULL. Im Hilfe-Pfad erfolgt keine Zuweisung; ein gebundener Anfangswert bleibt erhalten. Das OUTPUT-Argument kann ausgelassen werden, wenn der Wert nicht empfangen werden soll. |

### RAW-Resultsets

```sql
EXEC [monitor].[USP_WorkerPressureAnalysis]
      @SampleSeconds=0
    , @ResultSetArt='RAW';
```

### JSON ohne reguläre Resultsets

```sql
DECLARE @WorkerJson nvarchar(max);
EXEC [monitor].[USP_WorkerPressureAnalysis]
      @SampleSeconds=0
    , @ResultSetArt='NONE'
    , @JsonErzeugen=1
    , @Json=@WorkerJson OUTPUT;
SELECT @WorkerJson AS [WorkerPressureAnalysisJson];
```

### TABLE in eine lokale Temp-Tabelle

```sql
CREATE TABLE #WorkerPressureAnalysis_HelpExample (Seed int NULL);
DECLARE @WorkerTableMap nvarchar(max)=N'{"summary":"#WorkerPressureAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_WorkerPressureAnalysis]
          @SampleSeconds=0
        , @ResultSetArt='TABLE'
        , @ResultTablesJson=@WorkerTableMap;
    SELECT * FROM #WorkerPressureAnalysis_HelpExample;
    DROP TABLE IF EXISTS #WorkerPressureAnalysis_HelpExample;
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS #WorkerPressureAnalysis_HelpExample;
    THROW;
END CATCH;
```

### Eingebaute Hilfe

```sql
EXEC [monitor].[USP_WorkerPressureAnalysis] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte Vertrag umfasst `moduleStatus`, `summary`, `schedulers`, `waits`, `requests`, `sourceStatus` und `warnings`. Berücksichtigen Sie zuerst `moduleStatus` und `sourceStatus`. Das Scheduler-Resultset ist die Primärevidenz; Worker, Waits und Requests sind unabhängig isolierte Kontextquellen. Prüfen Sie danach `summary`, anschließend auffällige Scheduler und zuletzt den begrenzten Requestkontext. Ein partieller Worker-Scan macht Scheduler-Queues nicht null, begrenzt aber Workerbelegung und Zustandsverteilung.

Die bereits collatierte TABLE-Zuordnung und alle weiteren 24 Textspalten der
lokalen Snapshot-, Ergebnis- und Statustabellen verwenden explizit
`SQL_Latin1_General_CP1_CS_AS`. Die sieben TABLE-Exporte übernehmen diese
Frameworkcollation für ihre insgesamt 22 Textspalten auch bei abweichender
Server- oder `tempdb`-Collation. Numerische Scheduler- und Workerwerte bleiben
unverändert. `@MaxZeilen` begrenzt die Requestausgabe in RAW, TABLE und JSON
einheitlich. Summary und Quellenstatus berücksichtigen weiterhin den zusätzlich
gelesenen Kandidaten zur Begrenzungsprüfung; `HasMoreRequestRows` zeigt ihn an,
während `ReturnedRequestRows` die tatsächlich ausgegebene Zeilenzahl nennt.

## Eine Zeile bedeutet

In `summary` bedeutet eine Zeile den gesamten Aufruf. In `schedulers` ist eine Zeile ein sichtbarer Online-Scheduler am zweiten Messpunkt samt optionalem Delta. In `waits` ist eine Zeile ein aggregierter `THREADPOOL`-Waittyp. In `requests` ist eine Zeile ein aktuell sichtbarer Request, der `THREADPOOL`, Blocking oder die Mindestlaufzeit erfüllt. Die Zeilen besitzen verschiedene Granularität und dürfen nicht additiv verbunden werden.

## So lesen

Berücksichtigen Sie `TotalWorkQueueCount` und `ThreadpoolWaitingTaskCount` gemeinsam, aber nicht als identischen Zähler. `MaxWorkQueuePerScheduler` zeigt mögliche Ungleichverteilung. `TotalRunnableTasks` und `MaxRunnablePerScheduler` bilden den getrennten CPU-Pfad. Workerbelegung, fehlgeschlagene Worker-Erzeugung, Blocking und lange Requests sind Kontext. Bei einem Sample zeigen kumulative Schedulerzähler Deltas; `CounterResetDetected=1` macht diese Deltas unbekannt. Gauge-Differenzen wie Runnable- oder Workeränderung dürfen negativ sein.

## Warum kann das problematisch sein?

Wenn Tasks auf Worker warten, können neue Requests verzögert werden, obwohl CPU nicht vollständig ausgelastet erscheint. Lange blockierte oder hochparallele Requests können Worker binden. Runnable-Queues zeigen hingegen, dass vorhandene Worker CPU-Zeit benötigen. Beide Situationen beeinträchtigen Latenz, verlangen aber verschiedene Gegenproben und mögliche Maßnahmen.

## Wann ist es kein Problem?

Ein einzelner Runnable Task oder eine kurze Queue während eines geplanten Bursts ist nicht automatisch ein Kapazitätsproblem. Hohe Workerbelegung ohne Work Queue und ohne `THREADPOOL` ist nur Kontext. Der automatisch berechnete Default von `max worker threads` ist in vielen Installationen angemessen; eine Änderung ohne Root-Cause-Evidenz kann Nebenwirkungen erzeugen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Mehrere Samples zeigen `work_queue_count > 0`, gleichzeitige `THREADPOOL`-Waits und viele blockierte `ExampleDatabase`-Requests. Blocking und Parallelität sind als Ursachenhypothesen stark; zuerst Blocker und Workload untersuchen.

**Gegenbeispiel:** `runnable_tasks_count > 0`, aber Work Queue und `THREADPOOL` bleiben null. Das ist CPU-Scheduler-Kontext, kein Workerpoolnachweis.

**Nicht entscheidbar:** Scheduler verfügbar, Worker-DMV verweigert. Queue-Evidenz bleibt gültig, Workerbelegung und Zustandsverteilung sind partiell. Leiten Sie keine Konfigurationsänderung aus dem unvollständigen Bild ab.

## Leere oder partielle Ausgabe

Das Summary wird auch ohne Druck erzeugt. `NO_WORKER_PRESSURE_VISIBLE_IN_SAMPLE` bedeutet nur, dass im begrenzten Fenster keine Worker-Queue sichtbar war. `AVAILABLE_LIMITED` weist auf eine fehlende Kontextquelle hin. Ist die Schedulerquelle selbst verweigert, fehlt die Primärevidenz und der Modulstatus übernimmt deren Fehlerstatus. NULL ist unbekannt, nicht Nullmessung.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Zwei Schedulerbeobachtungen über eine Sekunde, ein aggregierter Worker-Scan und kleine Wait-/Request-Snapshots. |
| Teuerster Pfad | 60-Sekunden-Verbindung mit wiederholten Aufrufen und sehr vielen sichtbaren Workern/Requests. |
| Haupttreiber | Workerzahl, Schedulerzahl, aktuelle Requests und parallele Sampler. |
| Skalierung | Worker werden vollständig gelesen, aber sofort je Scheduler aggregiert; Requestausgabe ist Top-N-begrenzt. |
| Ressourcen | SQLOS-DMV-CPU, kleine TempDB-Tabellen und eine wartende Session während des Samples. |
| Begrenzungswirkung | `@MaxZeilen` begrenzt Requestausgabe, nicht Worker- oder Schedulerquellscan. |
| Locking und Nebenwirkungen | Read-only, `LOCK_TIMEOUT 0`; WAITFOR hält eine Verbindung, keine absichtlichen Nutzdatenlocks. |
| Schutzmechanismus | Sample maximal 60 Sekunden, SQL-/Plan-/Clientidentität ausgeschlossen, getrennte Quellstatus. |
| Sicherer Einsatz | Ein Sampler, eine Sekunde, begrenzte Requests; bei Befund zeitlich getrennt wiederholen. |
| Aussagegrenze | Momentaufnahme ohne Historie oder OS-CPU; kein universeller Worker-Schwellenwert und keine automatische Konfigurationsempfehlung. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist im Messfenster Workerbedarf oder eine getrennte CPU-Runnable-Queue sichtbar?

### Technischer Hintergrund

SQLOS bindet Tasks an Worker und Worker an Scheduler. Pending Work Queues entstehen vor Workerzuweisung; Runnable Queues nach Zuweisung beim Warten auf CPU. `sys.dm_os_workers` wird nur aggregiert ausgegeben. `max_workers_count` ist der effektive Enginewert, während `sys.configurations` den konfigurierten Wert einschließlich `0` für automatisch zeigt.

### Datenkette

`sys.dm_os_schedulers`, `sys.dm_os_workers`, `sys.dm_os_sys_info`, `sys.configurations`, `sys.dm_os_waiting_tasks`, `sys.dm_exec_requests`.

### Source Select

Scheduler und vollständig aggregierte Worker werden über `scheduler_address` verbunden:

```sql
WITH [Workers] AS
(
    SELECT
          [w].[scheduler_address]
        , COUNT_BIG(*) AS [WorkerCount]
        , SUM(CASE WHEN [w].[state] = N'RUNNABLE' THEN 1 ELSE 0 END)
          AS [RunnableWorkerCount]
    FROM [sys].[dm_os_workers] AS [w] WITH (NOLOCK)
    GROUP BY [w].[scheduler_address]
)
SELECT
      [s].[scheduler_id]
    , [s].[parent_node_id]
    , [s].[runnable_tasks_count]
    , [s].[work_queue_count]
    , [w].[WorkerCount]
    , [w].[RunnableWorkerCount]
FROM [sys].[dm_os_schedulers] AS [s] WITH (NOLOCK)
LEFT JOIN [Workers] AS [w]
  ON [w].[scheduler_address] = [s].[scheduler_address]
WHERE [s].[scheduler_id] < 1048576
  AND [s].[status] = N'VISIBLE ONLINE';
```

**Wichtig für die Eigenlast:** `dm_os_workers` wird vollständig gelesen, aber sofort je Scheduler aggregiert. THREADPOOL-Waits und auffällige Requests sind getrennte, bereits gefilterte Snapshots; SQL- und Plantexte werden nicht gelesen.

### Zeit- und Scope-Modell

Die Auswertung vergleicht den Schedulerzustand vor und nach dem Sample; Worker, Waits und Requests werden am Sampleende erfasst. Kumulative Zähler können beim Engine-Neustart zurückgesetzt werden. Queues und Workerzahlen sind flüchtige Gauges.

### Bewertung und Gegenprobe

Prüfen Sie Worker Queue und `THREADPOOL` wiederholt. Korrelieren Sie anschließend Blocking, Parallelität, lange Requests und CPU anhand unabhängiger Quellen.

### Typische Fehlinterpretation

Eine Runnable Queue ist nicht ohne weitere Evidenz als Worker-Erschöpfung zu interpretieren. Eine hohe Workerbelegung stellt außerdem keinen unmittelbaren Änderungsauftrag für `max worker threads` dar.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_CurrentBlocking`, `USP_CurrentRequests`, `USP_CurrentWaits`, CPU-Topologie und externe OS-Telemetrie.

## Primärquellen

- [sys.dm_os_schedulers](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-schedulers-transact-sql?view=sql-server-ver17)
- [sys.dm_os_workers](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-workers-transact-sql?view=sql-server-ver17)
- [max worker threads](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-the-max-worker-threads-server-configuration-option?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#18-monitorusp_workerpressureanalysis)
