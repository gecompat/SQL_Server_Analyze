# [monitor].[USP_ServerNuma]

**Bereich:** Server Health<br>
**Zweck:** Zeigt NUMA-Nodes, Schedulerverteilung und Memory-Node-Kontext.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie sind Scheduler und Memory auf SQLOS-/Hardware-NUMA-Nodes verteilt und gibt es sichtbare Ungleichgewichte?** Der dokumentierte Zweck ist: Zeigt NUMA-Nodes, Schedulerverteilung und Memory-Node-Kontext. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Node-/Schedulerzustand; Loadcounter sind Momentaufnahme oder kumulativ je Quelle. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerNuma]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `numaNodes` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem NUMA-/Memory-Node oder einem Scheduler.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Schedulerzahl, Online-/Idle-Zustand, Memory Node, Foreign Memory und Last je Node vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Persistente Asymmetrie kann lokale CPU-Engpässe und Remote-Memory-Zugriffe begünstigen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Momentan unterschiedliche Last je Node ist normal; erst wiederholte Asymmetrie ist belastbar.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein Node dauerhaft voll, anderer nahezu idle und Sessions konzentriert: Affinity, Verbindungslast, Soft-NUMA und Schedulerwaits prüfen.

**Ähnlich aussehender Gegenfall:** Momentan unterschiedliche Last je Node ist normal; erst wiederholte Asymmetrie ist belastbar. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_ServerNuma` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Aggregiert sichtbare Scheduler je Parent-NUMA-Node und liest anschließend SQLOS- sowie Memory-Nodes. RAW/JSON zeigen beide Granularitäten, TABLE nur `numaNodes`. |
| Teuerster Pfad | Es gibt keinen optionalen Deep-Pfad. Die maximale Quellmenge ist durch Scheduler- und Nodezahl der Instanz begrenzt; auch große Server bleiben gegenüber Workload-DMVs klein. |
| Haupttreiber | Zahl der SQLOS-Scheduler und NUMA-/Memory-Nodes. `scheduler_id >= 1048576` und der DAC-Node werden aus der fachlichen Sicht ausgeschlossen; Memory Nodes sind auf IDs unter 64 begrenzt. |
| Skalierung | Ein vollständiger Scheduler-Snapshot wird nach Parent gruppiert; CPU wächst linear mit der Schedulerzahl, Resultzeilen nur mit Nodes. |
| Ressourcen | Geringe SQLOS-DMV-CPU und kleine Temp-Tabellen. Keine Datenbankkataloge, Historie, XML oder Samplingverbindung. |
| Begrenzungswirkung | Es existiert kein Zeilen-/Scopeparameter, weil eine Teilmenge der NUMA-Topologie irreführend wäre. Ausgabeunterdrückung mit `NONE` spart die Quellerhebung nicht. |
| Locking und Nebenwirkungen | Read-only ohne Nutzdatenlocks. Schedulerlast kann sich zwischen Scheduler- und Nodeabfrage ändern; `RunnablePerScheduler` bleibt ein Momentwert, keine Intervallrate. |
| Schutzmechanismus | Kein Gate und bewusst kein Teil-Scope. Die reale Scheduler-/SQLOS-/Memory-Node-Zahl begrenzt die Quelle konstruktiv; eine künstliche TOP-Auswahl würde die Topologie eher verfälschen als die ohnehin kleine Abfrage sinnvoll schützen. |
| Sicherer Einsatz | CONSOLE direkt verwenden und Runnable-Signale mit wiederholten Messpunkten sowie CPU-/Wait-Evidenz gegenprüfen; ein eigener Scope ist nicht erforderlich. |
| Aussagegrenze | Der Snapshot zeigt SQLOS-Zuordnung und momentane Runnable Tasks, aber weder historische CPU-Sättigung noch VM-vNUMA-/Hosttopologie. Ein einzelner unbalancierter Moment beweist kein dauerhaftes NUMA-Problem. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sind Scheduler und Memory auf SQLOS-/Hardware-NUMA-Nodes verteilt und gibt es sichtbare Ungleichgewichte?

### Technischer Hintergrund

NUMA hält CPU und lokal angebundenes Memory zusammen. SQLOS-Nodes/Scheduler verteilen Workers; Memory Nodes verwalten Locality. Soft-NUMA kann zusätzliche logische Gruppen erzeugen. Remote Memory Access kann teurer sein.

### Datenkette

`sys.dm_os_memory_nodes`, `sys.dm_os_nodes`, `sys.dm_os_schedulers`.

### Source Select

Scheduler werden nach Parent-Node aggregiert und dem NUMA-Node zugeordnet:

```sql
SELECT
      [n].[node_id]
    , [n].[memory_node_id]
    , [n].[node_state_desc]
    , COUNT_BIG([s].[scheduler_id]) AS [SchedulerCount]
    , SUM(CONVERT(bigint, [s].[runnable_tasks_count])) AS [RunnableTasks]
    , SUM(CONVERT(bigint, [s].[active_workers_count])) AS [ActiveWorkers]
FROM [sys].[dm_os_nodes] AS [n] WITH (NOLOCK)
LEFT JOIN [sys].[dm_os_schedulers] AS [s] WITH (NOLOCK)
  ON [s].[parent_node_id] = [n].[node_id]
 AND [s].[scheduler_id] < 1048576
WHERE [n].[node_state_desc] <> N'ONLINE DAC'
GROUP BY [n].[node_id], [n].[memory_node_id], [n].[node_state_desc];
```

**Wichtig für die Eigenlast:** Interne/DAC-Scheduler an der Quelle ausschließen. `sys.dm_os_memory_nodes` ist eine separate Zeilengranularität und wird nur über Node-IDs interpretiert, nicht ungeprüft mit Schedulerzählern summiert.

### Zeit- und Scope-Modell

Aktueller Node-/Schedulerzustand; Loadcounter sind Momentaufnahme oder kumulativ je Quelle.

### Bewertung und Gegenprobe

Online/Idle Schedulers, Runnable Tasks, Active Workers, Load Factor, Memory Nodezuordnung und wiederholte Samples vergleichen. Ein persistentes einseitiges Muster ist relevanter als ein Snapshot.

### Typische Fehlinterpretation

Ungleiche Momentaufnahme ist bei zufälliger Workload normal. Node ID ist kein direkter physischer Socketbeweis bei Soft-NUMA/VM.

### Folgeanalyse

`USP_ServerCpuTopology`, Current Requests und Server Memory.

## Primärquellen

- [sys.dm_os_nodes](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-nodes-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#2-monitorusp_servernuma)
