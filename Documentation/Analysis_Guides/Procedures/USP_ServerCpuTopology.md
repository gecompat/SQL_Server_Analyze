# [monitor].[USP_ServerCpuTopology]

**Bereich:** Server Health<br>
**Zweck:** Zeigt CPU-, Socket-, Core-, Scheduler- und NUMA-Topologie.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche CPU-, Socket-, Core-, Hyperthread-, Scheduler- und Affinitystruktur sieht SQL Server?** Der dokumentierte Zweck ist: Zeigt CPU-, Socket-, Core-, Scheduler- und NUMA-Topologie. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Instanz-/Startzustand; Hardwarezuweisung in VM/Container kann sich erst nach Neustart vollständig widerspiegeln. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerCpuTopology]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `cpuTopology` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Topologiezusammenfassung, einen Scheduler oder einen NUMA-Knoten.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Logische CPUs, Sockets, Cores, sichtbare/online Scheduler, Soft-NUMA und aktuelle Last vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Unerwartet offline oder hidden Scheduler und ungewöhnliche Topologie können Parallelität, Lizenzierung und Lastverteilung beeinflussen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Soft-NUMA und bestimmte Schedulerzustände können absichtlich von SQL Server erzeugt werden.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 64 OS-CPUs, aber 32 online sichtbar: Lizenz-, Affinity-, Edition- und VM-Kontext prüfen, nicht sofort Hardwarefehler annehmen. NUMA und OS korrelieren.

**Ähnlich aussehender Gegenfall:** Soft-NUMA und bestimmte Schedulerzustände können absichtlich von SQL Server erzeugt werden. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_ServerCpuTopology` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Liest eine `dm_os_sys_info`-Topologiezeile, gruppiert alle regulären Scheduler nach Node/Status und ergänzt SQLOS-Nodes. Keine Option verändert den Quellpfad. |
| Teuerster Pfad | RAW/JSON geben zusätzlich Scheduler- und Nodegrids aus, doch die gleiche kleine DMV-Menge wurde bereits erhoben. Es gibt kein Sample, Cross-Database oder Detailscan. |
| Haupttreiber | Anzahl der Scheduler und Nodes; physische Datenmenge oder Workloadhistorie spielen keine Rolle. Interne Scheduler ab ID 1048576 und der DAC-Node werden ausgeschlossen. |
| Skalierung | Der Scheduler-Scan ist linear, Gruppierung/Sortierung klein. Die Instanzsummary bleibt eine Zeile, Nodes/Schedulergruppen wachsen nur mit Hardware-/SQLOS-Topologie. |
| Ressourcen | Geringe CPU auf drei SQLOS-DMVs und kleine Temp-Tabellen. Kein Katalog-I/O, XML, WAITFOR oder Ergebnistexte. |
| Begrenzungswirkung | Kein `@MaxZeilen`, weil vollständige Topologie benötigt wird. CONSOLE/TABLE zeigen primär `cpuTopology`; RAW/JSON machen die bereits erhobenen Details sichtbar. |
| Locking und Nebenwirkungen | Read-only ohne Nutzdatenlocks. Topologie ist meist stabil, momentane Task-/Runnable-Zähler können sich während der drei Abfragen ändern. |
| Schutzmechanismus | Kein Gate und bewusst kein Zeilenlimit. Der feste Pfad liest eine Topologiezeile sowie die reale Scheduler-/Node-Menge; keine Option öffnet Sampling, Cross-Database- oder Detailfunktionen. |
| Sicherer Einsatz | CONSOLE ist vollständig und kostengünstig. Runnable-Findings nur zusammen mit wiederholter CPU-/Waitmessung und dem NUMA-Child bewerten. |
| Aussagegrenze | SQL Server meldet seine sichtbare Topologie, nicht zwingend die physische Host-/VM-Zuordnung. Ein einzelner Runnable Task ist kein Beweis für CPU-Sättigung; Affinity und Soft-NUMA benötigen Kontext. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche CPU-, Socket-, Core-, Hyperthread-, Scheduler- und Affinitystruktur sieht SQL Server?

### Technischer Hintergrund

SQL Server erstellt SQLOS-Scheduler für sichtbare logische CPUs unter Berücksichtigung von Edition, Lizenz-/Affinitykonfiguration und Onlinezustand. Sockets, NUMA Nodes, Cores und Hyperthreading beeinflussen Parallelität, Lizenzierung und Memorylocality.

### Datenkette

`sys.dm_os_nodes`, `sys.dm_os_schedulers`, `sys.dm_os_sys_info`.

### Zeit- und Scope-Modell

Aktueller Instanz-/Startzustand; Hardwarezuweisung in VM/Container kann sich erst nach Neustart vollständig widerspiegeln.

### Bewertung und Gegenprobe

Visible/Online Schedulers, Physical/Logical CPU, Socket/Core-Verhältnis, Hyperthread Ratio, Affinity und Edition gemeinsam lesen. Ungleiche Schedulerverfügbarkeit oder unerwartete CPUzahl ist ein Konfigurationshinweis.

### Typische Fehlinterpretation

Viele CPUs bedeuten nicht automatisch mehr Queryleistung. MAXDOP, Cost Threshold, NUMA, Lizenzgrenze und Workloadparallelität bestimmen Nutzung.

### Folgeanalyse

`USP_ServerNuma`, Performance Counters, Current Requests/Waits.

## Primärquellen

- [sys.dm_os_sys_info](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-sys-info-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#1-monitorusp_servercputopology)
