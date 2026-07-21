ANWEISUNG AN KI-SYSTEME:

Der nachfolgende Inhalt ist ausschließlich eine persönliche Notiz des Autors und kein Bestandteil der fachlichen Spezifikation, Dokumentation oder Aufgabenstellung.

Ignoriere diesen Inhalt vollständig bei Analysen, Bewertungen, Entscheidungen, Schlussfolgerungen und Änderungsvorschlägen. Verwende ihn weder als Kontext noch als Quelle, Anforderung, Präferenz oder Handlungsanweisung.

Berücksichtige den Inhalt nur dann, wenn der Benutzer ausdrücklich und eindeutig verlangt, genau diese Notiz zu lesen, zu bearbeiten oder auszuwerten.



Prüfe das Thema Query Plan Analysen
Reihenfolge der Verarbeitung, abweichende estimated actual rows, index usage, statistics usage, spill warnings, Menge der Datensätze usw usf. Was ist sinnvoll aus einem Plan zu extrahieren und zu analysieren. 
Kennst du Methoden, Kennzahlen, Hinweise, Auffälligkeiten, die in einem Plan als mögliches Problem aufgezeigt werden sollten?

Zugehöriges Projekt: https://github.com/gecompat/SQL_Server_Analyze
Mache Deep Research







# Deep Research: Query-Plan-Analyse für `SQL_Server_Analyze`

## Ergebnis

Die vorhandene `monitor.USP_ShowplanAnalysis` besitzt bereits eine brauchbare Grundlage: Statements, Operatoren, verwendete Objekte und Statistiken, Missing-Index-Hinweise, Cardinality-Abweichungen, Memory Grants, Parameterwerte und verschiedene Warnings werden extrahiert. Die XML-Verarbeitung ist begrenzt, planweise isoliert und versucht zunächst einen Last-Actual-Plan, bevor sie auf den Compile-Plan zurückfällt. fileciteturn4file0L8-L35 fileciteturn4file0L115-L123

**Hauptempfehlung:** Nicht einfach weitere einzelne XML-Warnings ergänzen. Die Analyse sollte auf ein **statementbezogenes Operator- und Evidenzmodell** umgestellt werden:

1. korrekte Statement-Zuordnung,
2. Operatorbaum und Datenfluss,
3. eindeutige Herkunft der Runtimewerte,
4. belastbare Mengen- und Arbeitskennzahlen,
5. kontextabhängige Findings mit getrennten Werten für **Severity** und **Confidence**,
6. anschließende Korrelation mit Plan Cache, Query Store, Statistics und Index Usage.

Der wichtigste aktuelle Fehler liegt dabei nicht in einer fehlenden Heuristik, sondern in der Statement-Zuordnung.

---

# 1. Kritischer Codebefund im aktuellen Repository

## 1.1 Planhandle und Statement werden derzeit wieder auseinandergerissen

**Codebefund:** Die Kandidatentabelle enthält:

- `StatementStartOffset`
- `StatementEndOffset`
- `QueryHash`
- `QueryPlanHash`

Danach verarbeitet der Cursor jedoch nur noch:

```sql
CandidateId,
PlanHandle
```

und analysiert anschließend sämtliche `StmtSimple`- und `RelOp`-Elemente des gesamten Plan-XML. fileciteturn5file0L16-L29 fileciteturn5file0L37-L70

`sys.dm_exec_query_stats` liefert statementbezogene Zeilen, während `sys.dm_exec_query_plan(plan_handle)` den Compile-Plan des gesamten Batches zurückgibt. Ein Stored-Procedure-Plan kann daher mehrere Statements enthalten. citeturn333191search6

### Mögliche Folgen

- Derselbe Batchplan kann für mehrere `dm_exec_query_stats`-Zeilen erneut vollständig analysiert werden.
- Findings anderer Statements können dem selektierten Statement zugerechnet werden.
- Bei mehrstatementigen Prozeduren entstehen potenziell Duplikate.
- `NodeId` ist ohne `StatementId` nicht ausreichend eindeutig. Showplan verwendet getrennt `StmtId` und `NodeId`; `NodeId` bezeichnet den Knoten innerhalb der jeweiligen Query beziehungsweise des Statements. citeturn984344search8
- Ein Cardinality-Fehler in Statement B kann als Finding des über Statement A selektierten Kandidaten erscheinen.

Interessanterweise verwendet `USP_PlanDetails` die Statementoffsets bereits korrekt für `sys.dm_exec_text_query_plan`. fileciteturn15file0L97-L104 fileciteturn15file0L155-L160

## P0-Korrektur

Die fachliche Identität sollte mindestens lauten:

```text
PlanDocumentId
+ StatementId beziehungsweise StatementCompId
+ NodeId
```

Ergänzend:

```text
PlanHandle
StatementStartOffset
StatementEndOffset
QueryHash
QueryPlanHash
StatementQueryHash
StatementQueryPlanHash
```

Das XML sollte **einmal je eindeutigem Planhandle** geladen und zerlegt werden. Erst danach werden die statementbezogenen Kandidaten mit den passenden `StmtSimple`-Elementen verbunden.

Für Compile-Pläne kann `sys.dm_exec_text_query_plan` gezielt ein einzelnes Statement über Start- und Endoffset liefern. Für Last-Actual-Pläne muss der passende `StmtSimple` innerhalb des Batchplans identifiziert werden. citeturn333191search10turn333191search11

---

# 2. Welche „Reihenfolge“ besitzt ein Ausführungsplan?

Ein Plan ist **keine lineare Schrittfolge**.

SQL Server verwendet einen pull-basierten Operatorbaum:

- Der Root-Operator fordert Daten beim Child an.
- Das Child fordert wiederum Daten bei seinen Children an.
- Schließlich liest ein Leaf-Operator Daten und reicht sie nach oben zurück.
- In der grafischen Darstellung fließen Daten von rechts nach links.
- Die auslösenden `GetRow()`-Aufrufe laufen konzeptionell vom Root in Richtung Blätter.
- Parallel ausgeführte Zweige können sich zeitlich überlappen.
- Blockierende Operatoren wie Sort oder die Build-Seite eines Hash Match müssen zunächst Eingaben sammeln, bevor sie Ausgaben liefern. citeturn984344search1

Daher sollte das Framework nicht behaupten:

```text
Operator 17 wurde zuerst ausgeführt,
danach Operator 16,
danach Operator 15.
```

## Sinnvolle Darstellungen

Für jeden Operator sollten stattdessen ausgegeben werden:

| Feld | Bedeutung |
|---|---|
| `StatementId` | Zugehöriges Statement |
| `NodeId` | Operator-ID innerhalb des Statements |
| `ParentNodeId` | Direkter Parent |
| `ChildOrdinal` | Position innerhalb der Inputs |
| `Depth` | Tiefe im Operatorbaum |
| `OperatorPath` | Stabil nachvollziehbarer Pfad |
| `DataFlowOrder` | Blätter in Richtung Root |
| `DemandOrder` | Root in Richtung Blätter |
| `BlockingType` | Streaming, teilweise blockierend, vollständig blockierend |
| `ParallelRegionId` | Zugehörige parallele Region |
| `ExecutionMode` | Row oder Batch |
| `EstimatedExecutionMode` | Geplanter Modus |
| `ActualExecutionMode` | Tatsächlicher Modus |

Für die Analyse ist meistens der **Datenfluss von den Zugriffen zu den Joins und zum Root** am verständlichsten. Für Row Goals und früh abbrechende Operatoren muss zusätzlich die pull-basierte Ausführung berücksichtigt werden: Ein Scan unterhalb eines `TOP` muss nicht zwangsläufig das gesamte Objekt lesen. citeturn984344search1

---

# 3. Empfohlene fachliche Verarbeitungsreihenfolge

## Phase 1 – Quellen- und Gültigkeitsprüfung

Vor jedem Finding:

1. Planquelle bestimmen:
   - `COMPILE`
   - `LAST_ACTUAL`
   - `CURRENT_ACTUAL`
   - `QUERY_STORE`
   - importierter `.sqlplan`
2. Ist der Plan vollständig oder partiell?
3. Zeitpunkt und Scope bestimmen.
4. SQL-Build, Showplan-Version, Compatibility Level und CE-Modell erfassen.
5. Prüfen, welche Runtimeinformationen überhaupt verfügbar sind.

Estimated-Pläne enthalten keine tatsächlichen Zeilen, tatsächliche Ressourcen oder Runtime-Warnings. `sys.dm_exec_query_plan_stats` liefert dagegen den letzten bekannten Actual Plan, muss aber explizit über `LAST_QUERY_PLAN_STATS` beziehungsweise den entsprechenden Mechanismus aktiviert worden sein und stellt keine Ausführungshistorie dar. citeturn984344search0turn886220search7

Wichtig ist ein Feld wie:

```text
RuntimeCounterScope =
    NONE
    LAST_COMPLETED_EXECUTION
    CURRENT_PARTIAL_EXECUTION
    QUERY_STORE_AGGREGATE
```

Die kumulativen Werte aus `sys.dm_exec_query_stats` dürfen nicht so dargestellt werden, als stammten sie aus derselben Ausführung wie die Operatorwerte eines Last-Actual-Plans.

---

## Phase 2 – Statementidentität

Extrahieren:

- `StatementId`
- `StatementCompId`
- Statementtyp
- Statementtext
- Query Hash
- Query Plan Hash
- Start-/Endoffset
- `StatementSubTreeCost`
- `StatementEstRows`
- Optimization Level
- Early Abort Reason
- Compile Time
- Compile CPU
- Compile Memory
- CE-Modellversion
- `RetrievedFromCache`
- Non-Parallel Plan Reason
- Statementhints
- Query-Store-Hints
- Planforcing-Informationen

Query Store Hints erscheinen im XML unter anderem als:

- `QueryStoreStatementHintText`
- `QueryStoreStatementHintId`
- `QueryStoreStatementHintSource` citeturn358055search1

`StatementOptmEarlyAbortReason` muss differenziert ausgewertet werden:

- `TimeOut`: relevantes Finding, besonders bei komplexem und langsamem Plan.
- Memory-Limit beziehungsweise vergleichbare Abbruchgründe: relevantes Finding.
- `GoodEnoughPlanFound`: nicht automatisch problematisch; der Optimizer arbeitet grundsätzlich nach einem Good-Enough-Modell.

Ein Optimizer-Timeout kann einen vernünftigen, aber auch einen suboptimalen Plan liefern. Microsoft dokumentiert `StatementOptmEarlyAbortReason="TimeOut"` ausdrücklich als Diagnosemerkmal. citeturn676499search10

---

## Phase 3 – Operatorbaum

Zusätzlich zu den bereits vorhandenen Feldern:

- `ParentNodeId`
- `ChildOrdinal`
- `Depth`
- `PhysicalOp`
- `LogicalOp`
- `EstimateCPU`
- `EstimateIO`
- `AvgRowSize`
- `EstimatedTotalSubtreeCost`
- `EstimateExecutions`
- `EstimateRebinds`
- `EstimateRewinds`
- `Parallel`
- Estimated/Actual Execution Mode
- Ordered
- Scan Direction
- Partitionierungsinformationen
- Output Columns
- Defined Values
- Predicate
- Probe Residual
- Pass-Through Predicate
- Startup Expression
- Seek Predicates
- Residual Predicate

Estimated Cost ist nur ein Optimizer-Kostenmodell. Es ist keine gemessene Laufzeit und sollte primär zur relativen Betrachtung innerhalb desselben Statements verwendet werden. citeturn984344search8

---

## Phase 4 – tatsächlicher Datenfluss

Pro Operator aggregiert und optional pro Thread:

- `ActualRows`
- `ActualRowsRead`
- `ActualExecutions`
- `ActualRebinds`
- `ActualRewinds`
- `ActualEndOfScans`
- `ActualScans`
- `ActualLogicalReads`
- `ActualPhysicalReads`
- `ActualReadAheads`
- LOB Reads
- Actual CPU
- Actual Elapsed
- Thread-ID
- tatsächlicher DOP

`RunTimeCountersPerThread` enthält zahlreiche dieser Werte. Die Threadwerte dürfen nicht vorschnell verworfen werden, weil gerade dort Parallelism Skew sichtbar wird. Operatorzeiten dürfen nicht einfach aufsummiert werden: parallele Zweige überlappen sich, und die Semantik der CPU-/Elapsed-Werte unterscheidet sich teilweise zwischen Row- und Batch-Mode. citeturn760468search6

Der aktuelle Code summiert `ActualRows`, `ActualRowsRead` und `ActualExecutions` über Threads. Das ist für eine Gesamtsicht sinnvoll, verliert aber die Informationen über die Verteilung zwischen Threads. fileciteturn17file0L3-L25

---

# 4. Cardinality Estimation: besser als ein einzelnes Verhältnis

## 4.1 Aktueller Stand

Derzeit wird berechnet:

```sql
ActualRows / EstimateRows
```

Ab 10-facher Über- oder Unterschätzung wird ein Finding erzeugt, ab Faktor 100 als `HIGH`. fileciteturn17file0L75-L78

Das ist eine gute erste Heuristik, aber allein nicht ausreichend.

## 4.2 Probleme des einfachen Quotienten

- `1` geschätzt und `100` tatsächlich ergibt Faktor 100, verursacht aber möglicherweise nur geringe Arbeit.
- `1.000.000` geschätzt und `10.000.000` tatsächlich ergibt „nur“ Faktor 10, kann aber sehr hohe Auswirkungen haben.
- Nullwerte lassen sich nicht sinnvoll dividieren.
- Bei mehrfach ausgeführten Operatoren müssen `ActualExecutions`, Rebinds und Rewinds berücksichtigt werden.
- Nested-Loops-Innenseiten können pro Ausführung korrekt geschätzt sein, aber aufgrund einer falsch geschätzten Außenseite viel zu oft aufgerufen werden.
- Ein Schätzfehler auf einem frühen Operator kann alle nachfolgenden Schätzfehler verursachen; nicht jeder fehlerhafte Knoten ist eine eigenständige Ursache.

Die Operatorreferenz weist ausdrücklich darauf hin, dass bei vorhandenen Rebind-/Rewind-Zählern diese zusammen mit den Zeilenschätzungen gelesen werden müssen. citeturn984344search1

## 4.3 Empfohlene Kennzahlen

**Heuristik:**

```sql
CardinalityLogError =
    ABS
    (
        LOG10
        (
            (ActualRows + 1.0)
            /
            (EstimatedRowsTotal + 1.0)
        )
    );
```

Interpretation:

| Wert | Größenordnung |
|---:|---|
| `< 1` | weniger als Faktor 10 |
| `>= 1` | mindestens Faktor 10 |
| `>= 2` | mindestens Faktor 100 |
| `>= 3` | mindestens Faktor 1.000 |

Zusätzlich:

```text
ActualRowsPerExecution
EstimatedRowsPerExecution
ActualRowsTotal
EstimatedRowsTotal
AbsoluteRowDelta
EstimatedFlowBytes
CardinalityLogError
DownstreamImpactRows
```

`EstimatedRowsTotal` sollte nur dort berechnet werden, wo `EstimateExecutions` beziehungsweise die Rebind-/Rewind-Semantik eindeutig vorliegt.

## 4.4 Impact-Gate

Ein Cardinality-Finding sollte mindestens zwei Dimensionen enthalten:

```text
Fehlergröße × Arbeitsmenge
```

Beispielsweise:

```text
CARDINALITY_MISESTIMATE
    EstimateErrorOrders = 2.3
    ActualRows          = 8,500,000
    ActualRowsRead      = 41,000,000
    ActualExecutions    = 1
    Confidence          = EXPLICIT_RUNTIME
    Severity            = HIGH
```

Dagegen:

```text
Estimate = 1
Actual   = 100
ActualRowsRead = 100
```

kann trotz Faktor 100 lediglich `INFO` oder `MEDIUM` sein.

---

# 5. Datenmengen und tatsächlich geleistete Arbeit

## 5.1 Rows Returned ist nicht Rows Read

Für Access-Operatoren sind mindestens beide Werte erforderlich:

```text
ActualRows
ActualRowsRead
```

`ActualRowsRead` beschreibt die Zeilen vor Anwendung eines residualen beziehungsweise heruntergedrückten Filters. Microsoft hat diesen Wert gerade deshalb ergänzt, weil ein Operator sehr viele Zeilen lesen, aber nur wenige zurückgeben kann. citeturn250157search2turn250157search11

## 5.2 Rows-Read-Amplification

**Heuristik:**

```sql
RowsReadAmplification =
    ActualRowsRead
    / NULLIF(ActualRows, 0.0);
```

Zusätzlich:

```sql
ResidualDiscardPct =
    100.0
    * (ActualRowsRead - ActualRows)
    / NULLIF(ActualRowsRead, 0.0);
```

Ein Finding sollte nur entstehen, wenn sowohl Verhältnis als auch absolute Menge relevant sind.

Beispiel für konfigurierbare Startwerte:

```text
MEDIUM:
    ActualRowsRead >= 100.000
    AND RowsReadAmplification >= 10

HIGH:
    ActualRowsRead >= 1.000.000
    AND RowsReadAmplification >= 100
```

Diese Werte sind **Frameworkheuristiken**, keine Microsoft-Grenzwerte.

Geeignete Findings:

- `ROWS_READ_AMPLIFICATION`
- `RESIDUAL_PREDICATE_HIGH_DISCARD`
- `SCAN_LOW_RETURN_RATE`
- `SEEK_HIGH_RESIDUAL_WORK`

Damit wird auch ein „Index Seek“ als möglicherweise teuer erkannt. Ein Seek ist nicht automatisch effizient.

---

# 6. Indexverwendung im Plan

Aus einem Plan lässt sich sinnvoll extrahieren:

- Datenbank, Schema, Objekt
- Indexname und Index-ID, sofern verfügbar
- Heap, Clustered, Nonclustered, Columnstore
- Seek, Scan, Lookup
- `Lookup="1"`
- Ordered
- Scan Direction
- ForceSeek
- ForceScan
- Index Hint
- NoExpand
- Seek Keys
- Start-/End-Range
- Residual Predicate
- Output Columns
- Partitionen
- tatsächliche Rows Read/Returned
- tatsächliche Ausführungsanzahl
- tatsächliche Reads
- Columnstore Segment Reads/Skips aus `dm_exec_query_stats`

`USP_QueryStats` enthält bereits Gesamt-/Letzte-Zeilen, DOP, Grant- und Spill-Werte sowie Plan-Cache-Informationen. Diese Daten sollten mit der Operatoranalyse korreliert werden, statt sie im Showplanmodul erneut als konkurrierende Interpretation zu modellieren. fileciteturn16file0L112-L168

## Kontextabhängige Findings

### Key/RID Lookup

Der aktuelle Code meldet jeden Lookup als `MEDIUM`. fileciteturn17file0L40-L41

Das erzeugt unnötige Warnungen. Ein Lookup für drei Zeilen ist häufig optimal.

Besser:

```text
LookupExecutions
LookupRowsRead
LookupLogicalReads
LookupRowsPerOuterRow
LookupOutputWidth
LookupShareOfQueryReads
```

Findings:

- `LOOKUP_PRESENT`: INFO
- `LOOKUP_HIGH_EXECUTION_COUNT`
- `LOOKUP_HIGH_READ_VOLUME`
- `LOOKUP_DOMINATES_QUERY_WORK`

Erst danach folgt die Gegenprüfung, ob ein bestehender Index erweitert werden kann. Ein automatisches `INCLUDE` ist keine belastbare Schlussfolgerung, weil DML-Kosten, Indexbreite und andere Queries fehlen.

### Table/Index Scan

Ein Scan ist kein Fehler. Er kann optimal sein bei:

- kleinem Objekt,
- großer benötigter Datenmenge,
- analytischer Abfrage,
- Columnstore,
- fehlender Selektivität,
- Row Goal, der den Scan früh stoppt.

Sinnvolle Findings sind daher:

- `LARGE_SCAN_HIGH_ROWS_READ`
- `SCAN_WITH_HIGH_DISCARD`
- `SCAN_WITHOUT_PARTITION_ELIMINATION`
- `SCAN_CAUSED_BY_PLAN_AFFECTING_CONVERT`
- `HEAP_SCAN_REVIEW`

Nicht sinnvoll wäre ein pauschales `TABLE_SCAN = Problem`.

### Backward Scan

Ein Backward Scan kann Parallelismus verhindern oder einschränken, muss aber nur bei relevanter Arbeitsmenge und tatsächlicher Auswirkung gemeldet werden. Die offene Toolingpraxis prüft Backward Scans ebenfalls, behandelt sie jedoch als Kontextsignal. fileciteturn11file0L68-L83

---

# 7. Statistics Usage

`OptimizerStatsUsage/StatisticsInfo` liefert den Zustand der verwendeten Statistik **zum Kompilierungszeitpunkt**, unter anderem:

- Statistikname
- Last Update
- Modification Count
- Sampling Percent

Diese Daten zeigen nicht zwangsläufig den heutigen Statistikzustand. Der Plan kann alt sein, während die Statistik inzwischen aktualisiert wurde. Umgekehrt kann eine beim Compile aktuelle Statistik heute stark verändert sein. citeturn396535search0

## Empfohlenes Modell

### Im Plan gespeicherter Stand

```text
StatsLastUpdateAtCompile
ModificationCountAtCompile
SamplingPercentAtCompile
```

### Optional aktuelle Anreicherung

Aus `sys.dm_db_stats_properties`:

```text
CurrentStatsLastUpdate
CurrentRows
CurrentRowsSampled
CurrentModificationCount
CurrentPersistedSamplePercent
```

### Abgeleitete Werte

```text
StatsChangedSinceCompile
StatsAgeAtCompile
CurrentStatsAge
ModificationRatioAtCompile
CurrentModificationRatio
SampleCoveragePct
```

## Sinnvolle Findings

- `COLUMN_WITHOUT_STATISTICS`: zunächst hohe Confidence, aber Severity abhängig von Predicate, Datenmenge und Schätzfehler.
- `USED_STATS_HIGH_MODIFICATION_AT_COMPILE`
- `USED_STATS_LOW_SAMPLE_WITH_SKEW_INDICATION`
- `STATS_CHANGED_SINCE_PLAN_COMPILE`
- `ESTIMATE_ERROR_CORRELATED_WITH_STATS`
- `FILTERED_STATS_BOUNDARY_REVIEW`
- `ASCENDING_KEY_OR_OUT_OF_RANGE_REVIEW`

Alter allein beweist keine schlechte Statistik. Eine fünf Jahre alte Statistik auf einer unveränderten Tabelle kann korrekt sein. Eine sehr junge, stark gesampelte Statistik kann bei starkem Skew problematisch sein.

---

# 8. Memory Grants und Spills

## 8.1 Bereits vorhanden

Die Procedure extrahiert unter anderem:

- Required/Desired/Requested Memory
- Granted Memory
- Max Used Memory
- Grant Wait Time
- Last Requested Memory
- Memory Grant Feedback State fileciteturn17file0L62-L68

Sie erkennt außerdem Spill-Elemente, verliert dort aber derzeit überwiegend:

- Statementbezug,
- Node-ID,
- Operator,
- genaue TempDB-Lese-/Schreibmenge,
- Spilltyp,
- Zusammenhang mit Grant und Cardinality. fileciteturn17file0L27-L34

## 8.2 Spillarten getrennt behandeln

- Sort Spill
- Hash Spill
- Hash Recursion
- Hash Bailout
- Exchange Spill
- sonstiger `SpillToTempDb`

Sorts verwenden bei Spill eine Worktable, Hashoperationen ein Workfile in `tempdb`. Hash Recursion und besonders Hash Bailout sind stärkere Signale als ein kleiner einmaliger Spill. citeturn984344search3

Exchange Spills entstehen in parallelen Plänen, wenn Exchange-Kommunikationspuffer nach `tempdb` ausgelagert werden. citeturn733589search3

## 8.3 Zu extrahierende Spillwerte

```text
StatementId
NodeId
PhysicalOp
SpillKind
SpillLevel
SpilledRows
SpilledPages
SpilledDataSize
WritesToTempDb
ReadsFromTempDb
GrantedMemoryKb
UsedMemoryKb
HashRecursionLevel
HashBailout
ExecutionCount
```

Detaillierte Hash-Spill-Informationen enthalten beispielsweise Grant, Used Memory sowie Reads und Writes nach `tempdb`. citeturn760468search2

## 8.4 Memory-Grant-Kennzahlen

```sql
GrantUtilizationPct =
    100.0 * MaxUsedMemoryKb
    / NULLIF(GrantedMemoryKb, 0);

GrantWasteKb =
    GrantedMemoryKb - MaxUsedMemoryKb;
```

Der aktuelle Overgrant-Test entspricht ungefähr:

```text
Granted >= 10 MB
AND Granted > 4 × MaxUsed
```

Das ist als Startheuristik brauchbar. fileciteturn17file0L79-L81

Der aktuelle Pressure-Test ist dagegen zu breit:

```text
MaxUsedMemory >= GrantedMemory
OR GrantWaitTime > 0
```

`MaxUsedMemory = GrantedMemory` beweist keine Unterversorgung. Der Grant kann lediglich vollständig genutzt worden sein. Für ein starkes Undergrant-Finding sollten mindestens eines der folgenden Signale vorliegen:

- Spill,
- Hash Recursion/Bailout,
- `GrantWaitTime > 0`,
- explizite Memory-Grant-Warning,
- sehr hohe Cardinality-Unterschätzung,
- wiederholte Spills aus `dm_exec_query_stats`.

`dm_exec_query_stats` enthält kumulative, letzte, minimale und maximale Grants sowie Spillseiten seit der Kompilierung. citeturn592039search0

---

# 9. Parallelismus

„Parallel Plan“ allein ist kein Finding.

Sinnvoll zu extrahieren:

- Planned DOP
- Actual DOP
- Min/Max/Last DOP aus Query Stats
- Reserved/Used Threads
- NonParallelPlanReason
- Exchange-Typ
- Rows pro Thread
- CPU pro Thread
- Reads pro Thread
- Anzahl inaktiver Worker
- Exchange Spill
- DOP Feedback
- Batch-/Row-Mode

## Thread-Skew

**Heuristik:**

```text
ThreadRowSkew =
    MAX(ActualRowsPerThread)
    /
    AVG(ActualRowsPerThread)

ZeroWorkerShare =
    WorkersWithZeroRows
    /
    TotalWorkers
```

Ein Finding sollte erst bei ausreichender Arbeitsmenge entstehen.

Beispiel:

```text
DOP >= 4
AND ActualRows >= 100.000
AND ThreadRowSkew >= 2
```

Mögliche Findings:

- `PARALLEL_THREAD_SKEW`
- `PARALLEL_ZERO_WORKERS`
- `EXCHANGE_SPILL`
- `FORCED_SERIALIZATION`
- `SERIAL_PLAN_HIGH_WORK`
- `INEFFECTIVE_PARALLELISM_REVIEW`

DOP Feedback beurteilt ineffizienten Parallelismus anhand wiederkehrender Laufzeiten und Waits und kann den DOP für spätere Ausführungen reduzieren. Der zugehörige Zustand ist über Query Store verfügbar. citeturn358055search3turn500226search0

---

# 10. Parameter Sensitivity, PSP und OPPO

Der Vergleich von:

```text
ParameterCompiledValue
ParameterRuntimeValue
```

ist nützlich, aber allein kein Beweis für Parameter Sniffing.

Ein Unterschied ist normal: Ein wiederverwendeter Plan wird regelmäßig mit anderen Parametern ausgeführt als denen, mit denen er kompiliert wurde.

Ein starkes Finding benötigt weitere Evidenz:

- hohe Estimate-Abweichung,
- starke Unterschiede zwischen `min_rows` und `max_rows`,
- starke Laufzeit-/Read-Streuung,
- mehrere Plan Hashes,
- unterschiedliche Query-Store-Pläne,
- stark unterschiedliche Selektivität,
- Query-Store-Regression,
- PSP-/OPPO-Dispatcher und Varianten.

## SQL Server 2022/2025

PSP erzeugt Dispatcher- und Query-Variant-Pläne für parameterempfindliche Queries. SQL Server 2025 ergänzt OPPO für optionale Parameter, beispielsweise:

```sql
WHERE [Column] = @Parameter
   OR @Parameter IS NULL;
```

OPPO benötigt SQL Server 2025 und Compatibility Level 170 und verwendet ebenfalls Dispatcher- und Query-Variant-Pläne. citeturn358055search0turn358055search9

Zu extrahieren:

```text
PlanType
DispatcherPlanId
ParentQueryId
QueryVariantId
PLAN_PER_VALUE
PredicateRange
OptionalPredicate
PSP/OPPO Feature
```

Besonders wichtig: Dispatcherpläne besitzen im Query Store selbst keine Runtime Statistics. Zur Ermittlung der Gesamtlast müssen die Query-Varianten dem Parent zugeordnet und aggregiert werden. citeturn358055search11

Mögliche Findings:

- `PARAMETER_SENSITIVITY_EVIDENCE`
- `MULTIPLE_PLAN_VARIANTS`
- `PSP_DISPATCHER_WITHOUT_VARIANT_AGGREGATION`
- `OPPO_ELIGIBLE_PATTERN_REVIEW`
- `COMPILED_RUNTIME_VALUE_MISMATCH_CONTEXT`
- `PLAN_VARIANT_REGRESSION`

---

# 11. Row Goals

Row Goals können unter anderem durch `TOP`, `FAST`, `IN` oder `EXISTS` entstehen. Sie können Nested Loops und Access-Methoden begünstigen, die für wenige erwartete Zeilen sinnvoll sind, bei tatsächlich vielen Zeilen aber sehr teuer werden. Microsoft stellt mit `DISABLE_OPTIMIZER_ROWGOAL` auch einen entsprechenden Diagnose-/Steuerhinweis bereit. citeturn239934search1turn239934search8

Zu extrahieren:

- `IsRowGoal`
- `EstimateRows`
- `EstimateRowsWithoutRowGoal`
- verursachender Top-/Semi-Join-Kontext
- tatsächliche Zeilen
- Rows Read
- Nested-Loops-Ausführungen

Findings:

- `ROW_GOAL_PRESENT`: INFO
- `ROW_GOAL_LARGE_ACTUAL_ROWS`
- `ROW_GOAL_SCAN_REPEATED`
- `ROW_GOAL_NESTED_LOOPS_AMPLIFICATION`

Row Goal ist kein Fehler. Problematisch wird die Kombination:

```text
kleine Row-Goal-Schätzung
+ große tatsächliche Menge
+ wiederholter innerer Zugriff
```

---

# 12. Weitere hochwertige Auffälligkeiten

## Spools

- Eager Index Spool
- Lazy/Eager Table Spool
- Row Count Spool
- Rebind/Rewind-Verhalten
- Rows und Reads
- tatsächliche Wiederverwendung
- TempDB-Arbeit

Findings:

- `EAGER_INDEX_SPOOL_HIGH_WORK`
- `LARGE_SPOOL`
- `SPOOL_REBUILT_REPEATEDLY`
- `SPOOL_NOT_EFFECTIVELY_REUSED`

Ein Spool ist häufig eine sinnvolle Optimizermaßnahme. Relevant wird er bei großer Build-Menge, häufigem Neubau oder hoher TempDB-Arbeit.

## Nested Loops

```text
InnerActualExecutions
InnerRowsRead
OuterRows
```

Abgeleitet:

```sql
RepeatedInnerWork =
    InnerActualExecutions * InnerRowsReadPerExecution;
```

Findings:

- `NESTED_LOOPS_HIGH_INNER_EXECUTIONS`
- `NESTED_LOOPS_LOOKUP_AMPLIFICATION`
- `NESTED_LOOPS_SCAN_AMPLIFICATION`

## Merge Join

- Many-to-Many
- Worktable
- Rewinds
- Eingabesortierung
- Duplicate-Key-Mengen

Finding:

- `MANY_TO_MANY_MERGE_HIGH_REWINDS`

## Sort

- Sort Keys
- Rows
- Row Width
- Memory Fraction
- Spill
- Distinct Sort
- Top-N Sort
- Batch/Row Mode

Findings:

- `SORT_SPILL`
- `LARGE_BLOCKING_SORT`
- `SORT_HIGH_ROW_WIDTH`
- `REPEATED_SORT`
- `TOP_N_SORT_CONTEXT`

## Implicit Conversions

Der aktuelle Code durchsucht jedes `ScalarOperator/@ScalarString` nach `CONVERT_IMPLICIT`. Dadurch werden auch harmlose Ausgabekonvertierungen erfasst. Parallel dazu wird bereits das wesentlich spezifischere Element `PlanAffectingConvert` ausgewertet. fileciteturn17file0L27-L32

Besser unterscheiden:

- Conversion im Seek Predicate,
- Conversion auf der Spaltenseite,
- Conversion nur in Output/Compute Scalar,
- `ConvertIssue`,
- Cardinality-Auswirkung,
- Seek-Verhinderung,
- Rows-Read-Amplification.

Findings:

- `PLAN_AFFECTING_CONVERT`
- `SEEK_BLOCKING_IMPLICIT_CONVERT`
- `CARDINALITY_AFFECTING_CONVERT`
- `NON_IMPACTING_CONVERT`: maximal INFO

## Missing Indexes

Missing-Index-Empfehlungen basieren auf Compilezeit-Schätzungen einer einzelnen Query. Sie werden nicht nach der tatsächlichen Ausführung validiert, kennen keine Filtered oder Unique Indexes, legen die Schlüsselreihenfolge nicht fest und führen keine vollständige Kosten-Nutzen-Analyse breiter Includes durch. Microsoft bezeichnet sie ausdrücklich nicht als fertige Anweisung zum Erstellen des Index. citeturn333191search0

Daher:

- Impact extrahieren,
- Gleichheits-/Ungleichheits-/Include-Spalten getrennt halten,
- vorhandene Indexpräfixe vergleichen,
- DML-Kosten und Größe ergänzen,
- ähnliche Vorschläge konsolidieren,
- betroffene tatsächliche Reads und Ausführungshäufigkeit ergänzen.

## Optimizer-/Compile-Komplexität

Extrahieren:

- Compile Time
- Compile CPU
- Compile Memory
- Optimization Level
- Early Abort Reason
- Zahl der Joins/Objekte/Operatoren
- Plan Generation Number
- Query Store Compile Stats
- Optimization Replay

Optimized Plan Forcing speichert bei geeigneten komplexen, erzwungenen Plänen ein verborgenes `OptimizationReplay` im komprimierten Query-Store-Showplan. citeturn676499search0

Findings:

- `OPTIMIZER_TIMEOUT`
- `COMPILE_MEMORY_LIMIT`
- `HIGH_COMPILE_CPU`
- `HIGH_COMPILE_MEMORY`
- `FREQUENT_RECOMPILE_HIGH_COST`
- `COMPILE_COST_EXCEEDS_EXECUTION_COST`

---

# 13. Modernes Feedbackmodell einbeziehen

Ab SQL Server 2022 beziehungsweise 2025 sollte die Showplananalyse optional Query Store anreichern mit:

- CE Feedback
- Memory Grant Feedback
- DOP Feedback
- LAQ Feedback
- Query Store Hints
- Forced Plan State
- Force Failure
- Optimization Replay
- Query Variants
- Runtime-Intervalle

`sys.query_store_plan_feedback` enthält die Feedbackart, den Zustand und für Memory Grant Feedback sogar operatorbezogene Zusatzinformationen mit `NodeId`. citeturn500226search0

SQL Server 2025 ergänzt unter anderem:

- OPPO,
- CE Feedback for Expressions,
- standardmäßig aktiviertes DOP Feedback,
- Query Store für readable secondaries,
- weitere IQP-Erweiterungen. citeturn358055search4turn358055search5

Das Framework sollte diese Merkmale nicht als unbekannte oder problematische Mehrfachpläne interpretieren.

---

# 14. Findings brauchen Severity **und** Confidence

Der heutige Aufbau enthält im Wesentlichen:

```text
FindingType
Severity
NodeId
PhysicalOp
LogicalOp
Detail
```

fileciteturn4file0L115-L121

Empfohlen:

```text
FindingCode
Category
Severity
Confidence
EvidenceSource
PlanSource
StatementId
NodeId
ImpactValue
ImpactUnit
ThresholdValue
ObservedValue
Summary
TechnicalExplanation
CounterEvidence
RecommendedNextCheck
```

## Trennung

### Severity

Wie groß ist die mögliche Auswirkung?

- `INFO`
- `LOW`
- `MEDIUM`
- `HIGH`
- `CRITICAL`

### Confidence

Wie belastbar ist der Schluss?

- `EXPLICIT_RUNTIME_WARNING`
- `RUNTIME_MEASURED`
- `RUNTIME_INFERENCE`
- `COMPILE_WARNING`
- `COMPILE_HEURISTIC`
- `HISTORICAL_CORRELATION`

Beispiele:

| Sachverhalt | Severity | Confidence |
|---|---|---|
| kleiner Sort Spill, Query läuft 20 ms | LOW | explicit runtime |
| 20 GB Hash Spill mit Bailout | CRITICAL | explicit runtime |
| Key Lookup ohne Actual Plan | INFO | compile heuristic |
| Millionen Lookups und hohe Reads | HIGH | runtime measured |
| Missing Index mit 90 % Impact | MEDIUM | compile heuristic |
| Missing Index plus historische hohe Reads | HIGH | historical correlation |

Offene Werkzeuge wie `sp_BlitzCache` und das 2026 veröffentlichte Performance Studio prüfen ebenfalls unter anderem Row Estimate Mismatch, Spills, Spools, Row Goals, Lookups, Thread Skew, Forced Serialization, Statistics und Compileprobleme. Diese Inventare sind nützliche Praxisreferenzen, aber keine Engine-Spezifikation und ihre Thresholds sollten nicht ungeprüft übernommen werden. fileciteturn11file0L14-L84 citeturn709758search0

---

# 15. Empfohlene Resultsets

## 1. `moduleStatus`

Bereits vorhanden.

## 2. `planStatus`

Erweitern um:

```text
PlanDocumentId
PlanSource
RuntimeCounterScope
PlanCreationTime
LastExecutionTime
ShowplanVersion
Build
CompatibilityLevel
CardinalityEstimationModelVersion
IsPartial
XmlSizeBytes
ParseDurationMs
```

## 3. `statements`

Statementbezogen, einschließlich Compileinformationen und Hints.

## 4. `operatorTree`

Eine Zeile je:

```text
PlanDocumentId + StatementId + NodeId
```

Mit Parent, ChildOrdinal, Depth und Pfad.

## 5. `operatorRuntime`

Aggregierte Runtimewerte je Operator.

## 6. `operatorThreadRuntime`

Optional und standardmäßig deaktiviert, weil sehr zeilenreich.

## 7. `accessPredicates`

- Seek Predicate
- Residual Predicate
- Object/Index
- Output Columns
- Partitionen

## 8. `statisticsUsage`

Compilezeit plus optionale Current-State-Anreicherung.

## 9. `memoryAndSpills`

Statement- und operatorbezogen.

## 10. `parametersAndVariants`

Parameter, PSP, OPPO und Query-Store-Varianten.

## 11. `missingIndexes`

Beibehalten, aber um bestehende Indexüberlappungen und Runtimekontext ergänzen.

## 12. `findings`

Priorisierte, strukturierte Bewertung.

---

# 16. Performance der Analyse selbst

Die Procedure geht bereits richtig vor, indem sie Kandidaten zuerst selektiert, XML planweise lädt und Zeit-/Mengenlimits verwendet. fileciteturn4file0L27-L35

Optimierbar ist jedoch das XML-Shredding.

Derzeit wird das vollständige Dokument für zahlreiche Findings wiederholt mit Pfaden wie:

```sql
//*[local-name(.)="RelOp"]
//*[local-name(.)="ScalarOperator"]
//*[local-name(.)="PlanAffectingConvert"]
//*[local-name(.)="MissingIndexGroup"]
```

durchlaufen. fileciteturn17file0L27-L60

## Empfohlene Architektur

1. Kandidaten statementbezogen materialisieren.
2. Eindeutige `plan_handle` bestimmen.
3. XML einmal je Plan laden.
4. Statements einmal extrahieren.
5. RelOps einmal in eine Stagingtabelle extrahieren.
6. Runtime-Counter einmal separat extrahieren.
7. Warnings und Spezialelemente statement-/nodebezogen extrahieren.
8. Findings ausschließlich aus den Stagingtabellen berechnen.
9. XML nach jedem Plan freigeben.
10. Threaddetails nur bei expliziter Anforderung materialisieren.

Ein planweiser `LOCAL FAST_FORWARD`-Cursor ist in diesem Fall vertretbar, weil:

- Timeouts planweise geprüft werden können,
- Fehler isoliert bleiben,
- Speicher nicht für alle XML-Pläne gleichzeitig benötigt wird.

Entscheidend ist, nicht denselben Batchplan mehrfach für verschiedene Statements zu zerlegen.

Der öffentliche Microsoft-Index der Showplan-XSDs listet derzeit Schemas bis SQL Server 2022. Für SQL Server 2025 sollte der Parser daher optionalen, featureerkennenden Zugriff verwenden und unbekannte Elemente nicht zum Abbruch führen. citeturn500226search8

---

# 17. Priorisierte Repository-Roadmap

## P0 – fachliche Korrektheit

1. **Statementbezogene Planidentität herstellen.**
2. XML nur einmal pro eindeutigem `plan_handle` parsen.
3. `StatementId` in alle Operator-, Cardinality-, Warning- und Finding-Tabellen aufnehmen.
4. `NodeId` nur gemeinsam mit `StatementId` verwenden.
5. Planquelle und `RuntimeCounterScope` eindeutig ausgeben.
6. Cardinalityvergleich um `ActualExecutions` und `EstimateExecutions` erweitern.
7. Spill-Findings mit Statement, Node, Operator und Mengen verbinden.
8. Findings aus anderen Statements des Batches verhindern.
9. `OPTIMIZER_EARLY_ABORT` nach Grund differenzieren.
10. `MEMORY_GRANT_PRESSURE` nicht allein aus `MaxUsed >= Granted` ableiten.

## P1 – höchster diagnostischer Nutzen

1. Operatorbaum mit Parent, ChildOrdinal, Depth und Pfad.
2. `ActualRowsRead`-/Rows-Read-Amplification.
3. Seek- und Residual-Predicates.
4. Per-Thread-Runtime und Parallelism Skew.
5. Row Goals und `EstimateRowsWithoutRowGoal`.
6. Kontextabhängige Lookup-, Scan- und Nested-Loops-Findings.
7. Eager/Large Spools und Many-to-Many Merge.
8. detaillierte Sort-/Hash-/Exchange-Spills.
9. Compilezeit- und aktuelle Statistics Usage trennen.
10. Compile Time, CPU, Memory und Optimizer Timeout.
11. Query Store Hints und Forced-Plan-Informationen.
12. PSP-/OPPO-Dispatcher und Varianten.

## P2 – Vertiefung

1. Query-Store-Planvergleich und Regressionen.
2. CE/MGF/DOP/LAQ Feedback.
3. Partition Elimination.
4. Columnstore Segment Elimination und Execution Mode.
5. Adaptive Join – Schwellenwert und gewählter Pfad.
6. Scalar UDF Inlining, MSTVF und Table Variables.
7. DML-Pläne und Index-Write-Amplification.
8. Remote Query und externe Datenquellen.
9. Plan-Shape-Diffing über Operatorpfade.
10. synthetische Testplanbibliothek für SQL Server 2019, 2022 und 2025.

---

# Schlussbewertung

**Dokumentiert:** Die aktuelle Procedure besitzt bereits eine solide Extraktionsbasis und sinnvolle Schutzmaßnahmen.

**Codebefund:** Die fehlende Statementbindung ist derzeit das gravierendste Problem. Sie kann bei mehrstatementigen Batch- und Procedure-Plänen zu falscher Zuordnung, Duplikaten und nicht eindeutigen `NodeId`-Findings führen.

**Empirisch etablierte Methodik:** Besonders wertvoll sind nicht einzelne Operatornamen, sondern Kombinationen aus:

```text
Planquelle
+ Statement
+ Operatorpfad
+ Estimate
+ Actual
+ Rows Read
+ Executions
+ Memory/Spill
+ Parallelverteilung
+ Workloadwirkung
```

**Heuristik:** Schwellenwerte wie Faktor 10 oder 100 bleiben sinnvoll, sollten aber immer um absolute Arbeitsmenge, Wiederholung und Evidenzqualität ergänzt werden.

Die nächste sinnvolle Repository-Welle ist daher **P0: statementbezogenes Operator- und Runtime-Modell**, anschließend **P1: Rows-Read-Amplification, Predicates, Thread-Skew und detaillierte Spills**. Weitere isolierte Warning-Regeln vor dieser Umstellung würden die Zahl der Findings erhöhen, aber nicht zuverlässig deren Qualität.




Wenn obiges umgesetzt wird, sind dann auch bereits existierende Objekte betroffen? - Wenn ja, welche?
Sind andere Files im Repository betroffen, wenn ja, welche?


Ja. Der Umfang hängt davon ab, ob zunächst nur die **P0-Korrektheit** umgesetzt wird oder die vollständige P0–P2-Ausbaustufe aus der Deep Research.

## 1. Bestehende SQL-Objekte

### Zwingend betroffen

| Objekt                         | Betroffenheit           | Begründung                                                                                                                        |
| ------------------------------ | ----------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `monitor.USP_ShowplanAnalysis` | **zwingend, umfassend** | Statementzuordnung, Plan-Deduplizierung, Operatorbaum, Runtimewerte, Findings und Resultsets liegen vollständig in diesem Objekt. |

Die Procedure lädt derzeit je Kandidat anhand des `PlanHandle` das vollständige XML und untersucht darin alle `StmtSimple`- und `RelOp`-Elemente. Statementoffsets sind zwar im Kandidaten vorhanden, werden im Cursor aber nicht mehr verwendet.

Innerhalb dieses Objekts ändern sich insbesondere:

* Kandidatenmodell
* Plan-Deduplizierung
* Statementidentität
* alle internen `#ShowplanAnalysis_*`-Tabellen
* XML-Shredding
* Operator- und Runtimeaggregation
* Findings
* CONSOLE-, RAW-, TABLE- und JSON-Ausgabe
* `@Hilfe`
* Versionsnummer und Header

Es sind dabei nur lokale temporäre Tabellen betroffen. Es ist **keine Migration permanenter Datenbanktabellen** notwendig.

---

### Bedingt betroffen

#### `monitor.USP_PlanCacheAnalysis`

Für die reine P0-Korrektur muss dieses Objekt nicht zwingend geändert werden, solange Signatur und grundlegender JSON-Vertrag von `USP_ShowplanAnalysis` kompatibel bleiben.

Der Orchestrator besitzt bereits einen gemeinsamen `dm_exec_query_stats`-Snapshot mit:

* Statementstart und -ende
* Plan Generation Number
* Planhandle
* Query Hash
* Query Plan Hash
* Rows, DOP, Grants und Spills.

Er ruft `USP_ShowplanAnalysis` derzeit mit einer fest definierten Menge von Parametern auf.

Eine Änderung wird notwendig, sobald neue Steuerparameter auch über den Orchestrator verfügbar sein sollen, beispielsweise:

```text
@MitOperatorTree
@MitThreadRuntime
@MitPredicates
@MitCurrentStatistics
@MitQueryStoreCorrelation
@MitPlanFeedback
```

Auch eine Änderung des Parent-Objekts wäre nötig, wenn dessen TABLE-Ausgabe künftig nicht mehr nur den Modulstatus, sondern auch Showplan-Resultsets exportieren soll.

**Bewertung:** Für P0 nein; für die vollständige Umsetzung wahrscheinlich ja.

---

#### `monitor.USP_PlanDetails`

Dieses Objekt besitzt bereits:

* Statementoffsets
* Compile Plan
* Text Plan eines einzelnen Statements
* Last Actual Plan
* Live Plan
* Planattribute.

Eine direkte Änderung ist nicht erforderlich. Es wäre aber technisch ungünstig, wenn `USP_PlanDetails` und `USP_ShowplanAnalysis` dauerhaft zwei unterschiedliche Implementierungen für Planquellen, Statementidentität und Planstatus besitzen.

**Empfehlung:** Planbeschaffung und Planquellenstatus in einen gemeinsamen internen Baustein auslagern. Dann würde auch `USP_PlanDetails` angepasst, ohne seinen öffentlichen Vertrag wesentlich zu verändern.

---

#### `monitor.USP_QueryStats`

Für die P0-Korrektur bleibt das Objekt unverändert.

Für die spätere Vertiefung kann eine Erweiterung sinnvoll werden. Die Procedure liefert bereits viele benötigte Query-Level-Werte:

* Total, Last, Min und Max Rows
* DOP
* Memory Grants
* verwendeter und idealer Grant
* Total und Last Spills
* Plan- und Statementidentität.

Zusätzliche mögliche Felder wären beispielsweise:

* `min_grant_kb`
* `max_used_grant_kb`
* `min_used_grant_kb`
* `total_columnstore_segment_reads`
* `total_columnstore_segment_skips`
* Reserved/Used Parallel Threads
* weitere Min-/Max-Spillinformationen

**Bewertung:** P0 nicht betroffen; P1/P2 wahrscheinlich punktuell betroffen.

---

#### `monitor.USP_IntelligentQueryProcessingAnalysis`

Dieses Objekt behandelt bereits:

* PSP-/OPPO-Eignung
* Query Store Query Variants
* Query Store Plan Feedback
* CE Feedback
* Memory Grant Feedback
* DOP Feedback
* weitere IQP-Konfigurationen.

Aktuell werden Query Variants und Plan Feedback jedoch nur aggregiert gezählt; Querytext und Showplan werden bewusst nicht gelesen.

Wenn die vollständige Plananalyse konkrete Query-Varianten und Feedbackdatensätze einem Statement beziehungsweise Operator zuordnen soll, gibt es zwei Möglichkeiten:

1. `USP_IntelligentQueryProcessingAnalysis` um planbezogene Details erweitern.
2. Ein neues spezialisiertes Korrelationsobjekt erstellen.

**Hauptempfehlung:** Nicht dieselbe IQP-Logik zusätzlich in `USP_ShowplanAnalysis` duplizieren. Das vorhandene IQP-Objekt erweitern oder einen getrennten Korrelationsbaustein verwenden.

---

### Nicht zwingend zu ändern

Folgende bestehenden Analyseobjekte müssen wegen der Showplan-Erweiterung nicht geändert werden:

* `monitor.USP_IndexUsage`
* `monitor.USP_IndexOperationalStats`
* `monitor.USP_MissingIndexes`
* `monitor.USP_Statistics`
* `monitor.USP_StatisticsDistributionAnalysis`
* `monitor.USP_ObjectInventory`
* `monitor.USP_QueryStoreRuntimeStats`
* `monitor.USP_QueryStorePlanChanges`
* `monitor.USP_QueryStoreRegressions`
* `monitor.USP_QueryStoreForcedPlans`
* `monitor.USP_QueryStoreHints`
* `monitor.USP_CurrentRequests`

Diese Objekte liefern ergänzende Evidenz. Ihre Ergebnisse sollten über stabile Schlüssel und Folgeanalysen korreliert werden, nicht in die Showplan-Procedure hineinkopiert werden. Das Objektinventar zeigt die bereits vorhandene Trennung zwischen Plan Cache, Query Store und IQP.

---

## 2. Gemeinsame Frameworkobjekte

### Keine Änderung voraussichtlich notwendig

Die vorhandene Ausgabearchitektur unterstützt bereits benannte Mehrfachzuordnungen für TABLE. Eine Procedure kann mehrere Resultsetnamen auf unterschiedliche lokale Temp-Tabellen abbilden.

Daher müssen voraussichtlich nicht geändert werden:

* `monitor.InternalPrepareResultTables`
* `monitor.InternalPrepareSingleResultTable`
* `monitor.InternalWriteResultTable`
* `monitor.InternalEmitConsoleResult`

Aktuell verwendet `USP_ShowplanAnalysis` noch `InternalPrepareSingleResultTable` und exportiert bei TABLE ausschließlich `findings`.

Bei mehreren TABLE-Resultsets muss lediglich `USP_ShowplanAnalysis` auf die bereits vorhandene Mehrfachvorbereitung umgestellt werden. Die Helper selbst müssen dafür nicht umgebaut werden. Die vorhandenen Helperdateien sind bereits getrennt vorhanden.

### Bedingt betroffen

`monitor.InternalCheckAnalysisPath` und die Feature-/Berechtigungssteuerung sind nur betroffen, wenn zusätzliche Quellen direkt in die Showplananalyse aufgenommen werden, zum Beispiel:

* `QUERY_STORE_DEEP`
* `CATALOG_DEEP`
* Live-Profiling
* datenbankübergreifende aktuelle Statistics
* sehr umfangreiche Per-Thread-Analyse

Der aktuelle Code prüft bereits `PLAN_CACHE_DEEP` und `SHOWPLAN_XML_DEEP`.

Ich würde vorhandene Analyseklassen wiederverwenden. Eine Änderung der internen Berechtigungsobjekte wäre nur nötig, wenn tatsächlich eine neue Kostenklasse eingeführt wird.

---

# 3. Zwingend betroffene Repository-Dateien

## SQL-Code

### `Code/04_PlanCache/050_USP_ShowplanAnalysis.sql`

**Zwingend.** Das ist die Hauptimplementierung.

### `Code/Install/Install_All.sql`

**Zwingend neu zu generieren**, weil die geänderte Procedure Bestandteil des Gesamtinstallers ist. Das Repository referenziert dort die Datei `050_USP_ShowplanAnalysis.sql`.

---

## Resultsetinventar

### `Metadata/Inventory/ResultSets.csv`

**Zwingend.**

Der aktuelle TABLE-Vertrag besteht ausschließlich aus:

```text
CandidateId
FindingType
Severity
NodeId
PhysicalOp
LogicalOp
Detail
```

und besitzt `SchemaVersion = 1`.

Schon die P0-Korrektur benötigt mindestens eine Erweiterung um:

```text
StatementId
```

Für das vollständige Findingmodell zusätzlich etwa:

```text
StatementCompId
Confidence
EvidenceSource
PlanSource
RuntimeCounterScope
ImpactValue
ImpactUnit
ThresholdValue
ObservedValue
RecommendedNextCheck
```

Bei vollständiger Umsetzung sollten zusätzliche Inventarzeilen entstehen, beispielsweise:

```text
planStatus
statements
operatorTree
operatorRuntime
operatorThreadRuntime
accessPredicates
statisticsUsage
memoryAndSpills
parametersAndVariants
missingIndexes
findings
```

Für geänderte bestehende Schemata sollte `SchemaVersion` von `1` auf `2` angehoben werden.

---

## Dokumentation

Mindestens folgende Dateien müssen fachlich aktualisiert werden:

* `Documentation/Analysis_Guides/Procedures/USP_ShowplanAnalysis.md`
* `Documentation/Analysis_Guides/04_Plan_Cache.md`
* `Documentation/Reference/Procedure_Reference.md`
* `Documentation/Reference/Call_Catalog.md`
* `Code/Examples/041_Beispielaufrufe_Alle_Funktionalitaeten.sql`

Diese Dateien referenzieren die Procedure, ihre Aufrufe, Resultsets oder ihre Position innerhalb der Plan-Cache-Analyse.

Zusätzlich sollten aktualisiert werden:

* `Documentation/Quality/Release_Notes.md`
* `Metadata/Quality/Analysis_Documentation_Review.csv`

---

## Tests

### `Code/Tests/PlanCache/110_Test_und_Abnahme_Phase3.sql`

**Zwingend zu erweitern oder durch einen neuen dedizierten Test zu ergänzen.**

Der bestehende Test prüft gegenwärtig im Wesentlichen:

* Hilfeaufrufe
* Wiederverwendung des Parent-Query-Stats-Snapshots
* JSON-Verträge von Query Stats und Query Hash

Die eigentliche Showplananalyse, Statementzuordnung, Operatoren, Findings und Runtimeaggregation werden nicht getestet.

Benötigte synthetische Tests:

1. Batch mit mindestens zwei Statements und einem gemeinsamen `plan_handle`
2. Nachweis, dass jedes Finding dem richtigen Statement zugeordnet wird
3. gleiche `NodeId` in zwei Statements
4. Estimated-only Plan
5. Last-Actual-Plan
6. Parallelplan mit mehreren `RunTimeCountersPerThread`
7. Sort- und Hash-Spill
8. Lookup mit kleiner und großer tatsächlicher Arbeitsmenge
9. Rows Read versus Rows Returned
10. Memory Overgrant und echter Undergrant
11. Compile- und Runtimeparameter
12. SQL Server 2019/2022/2025 Feature-Fallbacks

Der bestehende Release-Gate-Runner bindet den Plan-Cache-Test bereits als Suite 30 ein. Wird der vorhandene Test erweitert, muss der Runner nicht geändert werden.

Wird stattdessen ein neuer dedizierter Integrationstest angelegt, beispielsweise:

```text
Code/Tests/Integration/190_Showplan_Runtime_Contract.sql
```

müssen zusätzlich geändert werden:

* `Code/Tests/Run_Release_Gate.sql`
* `Documentation/Quality/Test_Matrix.md`
* gegebenenfalls `Documentation/Quality/Release_Gate_Runbook.md`

---

# 4. Bedingt betroffene Repository-Dateien

## Bei neuen öffentlichen Parametern

### `Metadata/Inventory/Parameters.csv`

Nur zu ändern, wenn neue Parameter hinzukommen oder bestehende Semantik geändert wird. Das Inventar enthält bereits den Orchestratorparameter `@MitShowplanAnalysis`.

Mögliche neue Parameter sollten nicht vorschnell einzeln angelegt werden. Sinnvoller wäre eine kleine, orthogonale Steuerung, beispielsweise:

```text
@DetailLevel        = 'SUMMARY' | 'OPERATORS' | 'FULL'
@MitThreadRuntime   = 0
@MitCurrentMetadata = 0
```

anstatt zehn voneinander abhängiger Bits.

---

## Bei zusätzlichen Systemquellen

### `Metadata/Inventory/SystemSources.csv`

Zu aktualisieren, sobald neue Quellen direkt gelesen werden, etwa:

* `sys.dm_db_stats_properties`
* `sys.dm_db_stats_histogram`
* `sys.query_store_plan_feedback`
* `sys.query_store_query_variant`
* `sys.query_store_plan`
* `sys.query_store_runtime_stats`
* `sys.dm_exec_query_statistics_xml`

Das Inventar enthält bereits die gegenwärtigen Showplan- und Plan-Cache-Quellen.

---

## Bei neuen SQL-Objekten

### `Metadata/Inventory/Objects.csv`

Nur betroffen, wenn neue interne oder öffentliche Objekte angelegt werden.

Eine reine Änderung von `USP_ShowplanAnalysis` erfordert hier keine Änderung: Die vorhandenen Plan-Cache-Objekte und ihre Dateipfade sind bereits registriert.

Neue interne Parser- oder Korrelationsobjekte müssten dagegen aufgenommen werden.

---

## Weitere fachliche Dokumentation

Je nach tatsächlich implementiertem Umfang sollten geprüft und teilweise angepasst werden:

* `Documentation/Analysis_Guides/Runbooks/02_High_CPU.md`
* `Documentation/Analysis_Guides/Runbooks/03_Query_Regression.md`
* `Documentation/Analysis_Guides/Runbooks/06_Memory_Grant_Queue.md`
* `Documentation/Analysis_Guides/05_Query_Store.md`
* `Documentation/Analysis_Guides/02_Current_State.md`
* `Documentation/Analysis_Guides/Beginner_Reading_Guide.md`
* `Documentation/Analysis_Guides/Object_Index.md`
* `Documentation/Architecture/Diagnostic_Information_Enrichment_Backlog.md`

Diese Dateien verweisen bereits auf `USP_ShowplanAnalysis` oder verwenden sie als Folgeanalyse.

Die nichtkanonischen Authoring-Drafts müssen nicht vollständig nachgeführt werden. Sinnvoll wäre dort ein Hinweis, dass die Inhalte durch die neue kanonische Implementierung ersetzt wurden.

---

# 5. GitHub Actions

Die drei bestehenden Release-Gate-Workflows für:

* SQL Server 2019
* SQL Server 2022
* SQL Server 2025

führen bereits den allgemeinen Release-Gate-Prozess aus.

**Daher voraussichtlich keine Änderung an den Workflowdateien.**

Sie müssen nach der Umsetzung lediglich alle neuen Tests ausführen. Nur wenn spezielle Trace Flags, Query-Store-Konfigurationen oder `LAST_QUERY_PLAN_STATS` für Testfälle aktiviert werden sollen, wären workflowseitige Anpassungen notwendig.

---

# 6. Empfohlener kontrollierter Änderungsumfang

## Welle P0 – Korrektheit

Bestehende SQL-Objekte:

```text
monitor.USP_ShowplanAnalysis
```

Dateien:

```text
Code/04_PlanCache/050_USP_ShowplanAnalysis.sql
Metadata/Inventory/ResultSets.csv
Code/Install/Install_All.sql
Code/Tests/PlanCache/110_Test_und_Abnahme_Phase3.sql
Documentation/Analysis_Guides/Procedures/USP_ShowplanAnalysis.md
Documentation/Analysis_Guides/04_Plan_Cache.md
Documentation/Reference/Procedure_Reference.md
Documentation/Reference/Call_Catalog.md
Documentation/Quality/Release_Notes.md
```

`USP_PlanCacheAnalysis`, `USP_PlanDetails` und `USP_QueryStats` können in dieser Welle unverändert bleiben.

## Welle P1 – Operator- und Runtimeanalyse

Zusätzlich wahrscheinlich:

```text
monitor.USP_PlanCacheAnalysis
monitor.USP_PlanDetails
monitor.USP_QueryStats
```

sowie:

```text
Metadata/Inventory/Parameters.csv
Metadata/Inventory/SystemSources.csv
Code/Examples/041_Beispielaufrufe_Alle_Funktionalitaeten.sql
```

## Welle P2 – Query Store, PSP/OPPO und Feedback

Zusätzlich:

```text
monitor.USP_IntelligentQueryProcessingAnalysis
```

oder ein neues spezialisiertes Korrelationsobjekt. Bestehende Query-Store-, Index- und Statistikprozeduren sollten möglichst unverändert als unabhängige Evidenzquellen bestehen bleiben.

## Fazit

**Dokumentiert:** Für die P0-Korrektur ist nur ein bestehendes SQL-Objekt zwingend fachlich zu ändern: `monitor.USP_ShowplanAnalysis`.

**Bedingt:** Die vollständige Deep-Research-Umsetzung betrifft zusätzlich `USP_PlanCacheAnalysis`, `USP_PlanDetails`, `USP_QueryStats` und für IQP-Korrelation `USP_IntelligentQueryProcessingAnalysis`.

**Repositoryseitig zwingend:** Haupt-SQL-Datei, Gesamtinstaller, Resultsetinventar, Plan-Cache-Tests und die kanonische Showplan-/Plan-Cache-Dokumentation.

**Nicht notwendig:** Eine Änderung aller Index-, Statistik- und Query-Store-Procedures oder der allgemeinen TABLE-Helper. Das würde die Kopplung und Eigenlast unnötig erhöhen.




das wird dann wohl eher nicht funktionieren?
ResidualDiscardPct =
    100.0
    * (ActualRowsRead - ActualRows)
    / NULLIF(ActualRowsRead, 0.0);

Dieses Muster hast du öfters vorgeschlagen!

eventuell wird es notwendig sein, unterschiedliche Schwellenwerte zu vergeben.
Massendatenverarbeitung schaut anders aus, als OLTP Zugriffe - sollte man das in Steuertabellen auslagen und über (welche Werte auch immer) zuordnen?

Bei der Indexverwendung: wäre es sinnvoll hier Dinge wie Index ist für diesen Zugriff nicht richtig sortiert zu bewerten?

Berücksichtige die unterschiedlichen Plan Informationen abhängig von der SQL-Server Version!



Sollte es möglich sein, optional zusätzlich zum Plan auch noch den output von set statistics time,io mit zu übergeben - wären das hilfreiche Informationen?




## 1. `ResidualDiscardPct`: Der Einwand ist berechtigt

Die Formel

```sql
100.0
* ([ActualRowsRead] - [ActualRows])
/ NULLIF([ActualRowsRead], 0.0)
```

ist **nicht generell falsch**, aber als allgemeines Muster für die Plananalyse zu unsicher. So, wie ich sie vorgeschlagen hatte, sollte sie nicht übernommen werden.

### Die konkreten Probleme

#### 1. `ActualRowsRead` ist nicht allgemein verfügbar

`ActualRowsRead` wurde speziell eingeführt, um bei Access-Operatoren sichtbar zu machen, wie viele Zeilen **vor Anwendung eines heruntergedrückten residualen Prädikats** gelesen wurden. Es ist deshalb nur bei passenden Actual Plans und Operatoren vorhanden. `EstimatedRowsRead` wurde später als entsprechender Schätzwert ergänzt. ([Microsoft Unterstützung][1])

Bei einem Compile Plan, einem ungeeigneten Operator oder fehlenden Runtime Counters ist die Kennzahl nicht berechenbar. Das darf nicht als `0` interpretiert werden.

#### 2. Der aktuelle Code aggregiert die beiden Werte unabhängig

Momentan geschieht sinngemäß:

```sql
SUM([ActualRows]),
SUM([ActualRowsRead])
```

über die vorhandenen `RunTimeCountersPerThread`-Elemente.

Wenn `ActualRowsRead` nur bei einem Teil der Runtime-Counter-Zeilen vorhanden ist, ignoriert `SUM()` die dortigen `NULL`-Werte, während `ActualRows` trotzdem über alle Threads summiert wird. Dadurch können scheinbar folgende Zustände entstehen:

```text
ActualRows     > ActualRowsRead
RowsDiscarded  < 0
DiscardPct     < 0
```

Die Werte müssen daher **paarweise auf derselben Runtime-Counter-Zeile** erfasst werden.

#### 3. Decimal-Arithmetik ist unnötig riskant

Die aktuelle Stagingtabelle verwendet `decimal(38,4)`.

Bei

```sql
100.0 * decimal(38,4)
```

wird zunächst multipliziert und erst danach dividiert. Aufgrund der Precision-/Scale-Fortschreibung kann das bei sehr großen Werten zu ungünstigen Datentypen oder im Extremfall zu Arithmetic Overflow führen.

#### 4. Null zurückgegebene Zeilen sind ein Sonderfall

Bei:

```text
ActualRowsRead = 10.000.000
ActualRows     = 0
```

ist der Discard-Prozentsatz zwar sinnvoll als `100 %` darstellbar, aber:

```sql
ActualRowsRead / ActualRows
```

ist nicht berechenbar. `RowsReadAmplification` darf hier nicht künstlich als `0` oder als sehr großer Ersatzwert dargestellt werden.

---

## 1.1 Robuste Berechnung

Zunächst sollten nur Runtime-Counter-Paare aggregiert werden, bei denen beide Werte vorhanden sind:

```sql
SUM
(
    CASE
        WHEN [ActualRowsRead] IS NOT NULL
        THEN [ActualRows]
    END
) AS [PairedActualRows],

SUM
(
    CASE
        WHEN [ActualRowsRead] IS NOT NULL
        THEN [ActualRowsRead]
    END
) AS [PairedActualRowsRead]
```

Zusätzlich:

```text
RuntimeCounterCount
RowsReadCounterCount
CounterCoveragePercent
```

Die Prozentberechnung sollte erst nach Validierung und nach der Division skalieren:

```sql
CASE
    WHEN [PairedActualRowsRead] IS NULL
      OR [PairedActualRows] IS NULL
        THEN NULL

    WHEN [PairedActualRowsRead] <= 0
        THEN NULL

    WHEN [PairedActualRows] < 0
      OR [PairedActualRows] > [PairedActualRowsRead]
        THEN NULL

    ELSE
        TRY_CONVERT
        (
            decimal(19,6),
            (
                CONVERT
                (
                    decimal(38,12),
                    [PairedActualRowsRead] - [PairedActualRows]
                )
                /
                NULLIF
                (
                    CONVERT(decimal(38,12), [PairedActualRowsRead]),
                    CONVERT(decimal(38,12), 0)
                )
            )
            * CONVERT(decimal(5,2), 100)
        )
END AS [RowsReadNotReturnedPercent]
```

Ich würde die Kennzahl nicht automatisch `ResidualDiscardPct` nennen, sondern zunächst neutral:

```text
RowsReadNotReturned
RowsReadNotReturnedPercent
```

Nur wenn im selben Access-Operator tatsächlich ein residuales beziehungsweise heruntergedrücktes `Predicate` nachgewiesen wurde, kann zusätzlich ausgegeben werden:

```text
ResidualRowsDiscarded
ResidualDiscardPercent
```

### Notwendiger Status

```text
AVAILABLE
NO_RUNTIME_INFORMATION
ACTUAL_ROWS_READ_NOT_AVAILABLE
NOT_APPLICABLE_OPERATOR
PARTIAL_COUNTER_COVERAGE
INCONSISTENT_COUNTERS
ZERO_ROWS_READ
```

Ein negativer Prozentsatz darf nie entstehen. Bei inkonsistenten Countern wird `NULL` plus Status ausgegeben.

---

# 2. Unterschiedliche Schwellenwerte für OLTP und Massendatenverarbeitung

Ja, unterschiedliche Bewertungsmaßstäbe sind sinnvoll. Eine reine Einteilung nach Datenbank oder nach „viele Zeilen = Batch“ wäre jedoch zu grob.

Ein und dieselbe Datenbank kann enthalten:

* hochfrequente OLTP-Zugriffe,
* periodische Reports,
* ETL-Läufe,
* Wartungsabfragen,
* interaktive Ad-hoc-Analysen.

Auch dasselbe Statement kann je nach Parameter einmal 20 Zeilen und einmal 20 Millionen Zeilen verarbeiten.

## 2.1 Primär keine starren Profile, sondern mehrdimensionale Regeln

Jedes Finding sollte mindestens vier Dimensionen berücksichtigen:

```text
relative Abweichung
+ absolute Arbeit je Ausführung
+ Ausführungshäufigkeit
+ kumulative Systemwirkung
```

Beispiel:

```text
DiscardPercent >= X
AND
(
       RowsReadNotReturned >= Y
    OR LogicalReadsPerExecution >= Z
    OR TotalLogicalReads >= A
)
AND
(
       ExecutionCount >= B
    OR LastElapsedMs >= C
)
```

Damit werden beide Fälle erkannt:

### OLTP

```text
Nur 5.000 unnötig gelesene Zeilen je Ausführung,
aber 200.000 Ausführungen.
```

### Batch

```text
Nur eine Ausführung,
aber 800 Millionen unnötig gelesene Zeilen
und erhebliche CPU-/IO-/TempDB-Arbeit.
```

Die Severity kann als Maximum zweier Perspektiven bestimmt werden:

```text
PerExecutionImpact
CumulativeImpact
```

---

## 2.2 Workload-Profile trotzdem vorsehen

Ich würde folgende Profile unterstützen:

```text
LATENCY_SENSITIVE
BALANCED
THROUGHPUT
MAINTENANCE
UNKNOWN
```

Dabei bedeutet:

| Profil              | Schwerpunkt                                       |
| ------------------- | ------------------------------------------------- |
| `LATENCY_SENSITIVE` | Reads, CPU und Dauer je Ausführung; hohe Frequenz |
| `THROUGHPUT`        | Gesamtdatenmenge, Spill, TempDB, DOP, Durchsatz   |
| `MAINTENANCE`       | große Scans und Sorts teilweise erwartbar         |
| `BALANCED`          | neutrale Defaultbewertung                         |
| `UNKNOWN`           | Bewertung ohne workloadabhängige Verschärfung     |

Ein Profil darf ein Problem nicht „wegkonfigurieren“. Es verändert primär Thresholds und Severity.

---

## 2.3 Zuordnungshierarchie

Empfohlene Priorität:

1. expliziter Parameter `@WorkloadProfile`,
2. Query-Store-`query_id` innerhalb einer Datenbank,
3. `DatabaseId + QueryHash`,
4. Modul beziehungsweise `ObjectId + StatementOffset`,
5. Resource-Pool-/Workload-Group-Zuordnung, sofern verfügbar,
6. Datenbankregel,
7. automatische Klassifikation,
8. `BALANCED`.

Eine automatische Klassifikation sollte immer eine Confidence liefern:

```text
EXPLICIT
RULE_MATCH
INFERRED_HIGH_CONFIDENCE
INFERRED_LOW_CONFIDENCE
DEFAULT
```

Ich würde nicht allein anhand von `DatabaseName`, SQL-Text oder einem einzelnen Planoperator klassifizieren.

---

# 3. Steuertabellen: ja, aber keine generische SQL-Regelmaschine

Das Repository verwendet bereits eine metadata-driven Steuertabelle mit:

* `RuleCode`,
* `Priority`,
* `IsEnabled`,
* deterministischer Priorisierung,
* Confidence,
* Quelleninformationen.

Außerdem besitzt `USP_StatisticsDistributionAnalysis` bereits mehrere konfigurierbare Schwellenwertparameter und trennt `Severity`, `Confidence`, `MetricValue` und `ThresholdValue`.

Für Plananalysen würde ich diese Ansätze zusammenführen.

## 3.1 Empfohlene Tabellen

### `monitor.PlanAnalysisProfile`

```sql
CREATE TABLE [monitor].[PlanAnalysisProfile]
(
      [ProfileCode]        varchar(32)    NOT NULL
    , [Description]        nvarchar(1000) NOT NULL
    , [Priority]           smallint       NOT NULL
    , [IsEnabled]          bit            NOT NULL
    , [IsFrameworkDefault] bit            NOT NULL

    , CONSTRAINT [PK_PlanAnalysisProfile]
        PRIMARY KEY CLUSTERED ([ProfileCode])
);
```

### `monitor.PlanAnalysisRuleThreshold`

```sql
CREATE TABLE [monitor].[PlanAnalysisRuleThreshold]
(
      [RuleCode]                    varchar(100)  NOT NULL
    , [ProfileCode]                 varchar(32)   NOT NULL
    , [Severity]                    varchar(16)   NOT NULL
    , [IsEnabled]                   bit           NOT NULL

    , [MinRatio]                    decimal(19,6) NULL
    , [MinRows]                     bigint        NULL
    , [MinRowsRead]                 bigint        NULL
    , [MinRowsNotReturned]          bigint        NULL
    , [MinLogicalReadsPerExecution] bigint        NULL
    , [MinTotalLogicalReads]        bigint        NULL
    , [MinExecutionCount]           bigint        NULL
    , [MinElapsedMs]                bigint        NULL
    , [MinCpuMs]                    bigint        NULL

    , [MinServerMajorVersion]       tinyint       NULL
    , [MinCompatibilityLevel]       smallint      NULL
    , [RequiredEvidenceLevel]       varchar(32)   NULL
    , [AdditionalConfigurationJson] nvarchar(max) NULL

    , CONSTRAINT [PK_PlanAnalysisRuleThreshold]
        PRIMARY KEY
        (
            [RuleCode],
            [ProfileCode],
            [Severity]
        )
);
```

### `monitor.PlanAnalysisProfileAssignment`

Für lokale, umgebungsspezifische Zuordnungen:

```text
AssignmentId
Priority
DatabaseId
QueryId
QueryHash
ObjectId
StatementStartOffset
ResourcePoolId
ProfileCode
IsEnabled
```

Repository-Seeds dürfen hier nur generische Werte enthalten. Reale lokale Zuordnungen bleiben ausschließlich in der installierten Umgebung.

## 3.2 Was nicht in die Tabelle gehört

Nicht empfehlenswert:

```text
frei formulierte WHERE-Bedingungen
dynamische SQL-Fragmente
ausführbare Expressions
vollständig generisches EAV-Regelwerk
```

Die eigentliche Regel bleibt in geprüftem T-SQL-Code. Die Tabelle liefert nur Schwellenwerte und Aktivierung.

Das ist:

* sicherer,
* testbarer,
* performanter,
* leichter versionsadaptiv umzusetzen.

Die wenigen benötigten Thresholdzeilen werden einmal zu Beginn der Analyse in eine Temp-Tabelle geladen und danach relational verwendet.

---

# 4. Index ist „nicht richtig sortiert“

Ja, das ist eine sinnvolle Analyse. Es müssen aber zwei unterschiedliche Bedeutungen getrennt werden.

## 4.1 Reihenfolge der Schlüsselspalten für den Zugriff

Beispiel:

```text
Index:     (A, B, C)
Predicate: B = @B AND C = @C
```

Wenn `A` nicht eingeschränkt ist, kann der Index für diesen Zugriff möglicherweise nicht effizient seeken.

Zu untersuchen sind:

```text
IndexKeyOrdinal
SeekPredicateColumn
SeekPredicateType
ResidualPredicateColumn
EqualityKeyPrefixLength
FirstRangeKeyOrdinal
RowsRead
RowsReturned
```

Mögliche Findings:

```text
INDEX_LEADING_KEY_NOT_CONSTRAINED
INDEX_KEY_ORDER_LIMITS_SEEK
LATER_KEY_USED_AS_RESIDUAL
RANGE_KEY_PREVENTS_DEEP_SEEK
```

Der Plan zeigt über `SeekPredicates` und `Predicate`, welche Spalten tatsächlich zur Navigation und welche erst als residualer Filter verwendet werden. Die Indexdefinition muss zusätzlich aus `sys.indexes` und `sys.index_columns` aufgelöst werden.

Die erste Schlüsselspalte ist außerdem für die Statistik besonders relevant, weil nur für die erste Spalte eines Statistikobjekts ein Histogramm geführt wird; mehrspaltige Statistiken speichern zusätzliche Dichten für Schlüsselpräfixe. ([Microsoft Learn][2])

Ein Finding darf trotzdem nicht pauschal lauten:

```text
„Selektivste Spalte muss immer zuerst stehen.“
```

Denn Schlüsselreihenfolge beeinflusst zusätzlich:

* andere Abfragen,
* Sortierreihenfolge,
* Joins,
* Gruppierungen,
* Histogramm,
* Indexwiederverwendung,
* Write Amplification.

---

## 4.2 ASC/DESC-Reihenfolge für benötigte Sortierung

Ein Rowstore-Index kann einen Sortoperator vermeiden, wenn seine Schlüsselreihenfolge die benötigte Reihenfolge liefert. SQL Server kann einen Index auch vollständig rückwärts lesen. Daher kann beispielsweise:

```text
Index:    A ASC,  B DESC
ORDER BY: A DESC, B ASC
```

durch einen Backward Scan erfüllt werden. Dagegen kann eine beliebige gemischte Umkehrung nicht automatisch erfüllt werden. ([Microsoft Learn][3])

Zu extrahieren sind:

```text
RequiredOrderColumns
RequiredOrderDirections
IndexKeyColumns
IndexKeyDirections
EqualityConstrainedPrefix
ScanDirection
Ordered
SortReason
SortRows
SortDataSize
SortSpill
```

`Ordered = true` bedeutet, dass der Operator die Indexreihenfolge für die Ausgabe nutzen muss; bei `false` wird keine entsprechende Reihenfolge garantiert. Ein `Stream Aggregate` benötigt beispielsweise geordnete Eingaben und erhält bei fehlender geeigneter Reihenfolge typischerweise einen Sortoperator. ([Microsoft Learn][4])

### Sinnvolle Findings

```text
EXPENSIVE_SORT_POTENTIALLY_AVOIDABLE_BY_INDEX_ORDER
INDEX_ORDER_DOES_NOT_SATISFY_REQUIRED_ORDER
INDEX_BACKWARD_SCAN
ORDER_PRESERVATION_LOST_BY_EXCHANGE
INDEX_KEY_ORDER_SUPPORTS_ONLY_PARTIAL_REQUIRED_ORDER
```

`INDEX_BACKWARD_SCAN` sollte normalerweise nur `INFO` sein.

Die Aussage sollte nicht lauten:

```text
„Der Index ist falsch sortiert.“
```

sondern:

```text
„Die Reihenfolge des verwendeten Indexes erfüllt die
für diesen Operatorzweig benötigte Reihenfolge nicht vollständig.“
```

Ein Sort ist nur dann ein relevantes Problem, wenn zusätzlich mindestens eines gilt:

* große Datenmenge,
* hoher CPU-Anteil,
* Spill,
* häufiger Aufruf,
* hohe Row Width,
* hohe kumulative Last.

---

# 5. Versionsabhängige Planinformationen

Das muss explizit Bestandteil der Architektur werden.

## 5.1 Nicht nur nach Major Version entscheiden

Eine Planinformation hängt gegebenenfalls ab von:

```text
SQL-Server-Major-Version
Build/CU/SP
Compatibility Level
Cardinality Estimation Model
Planquelle
Showplan-Schema
aktivierter Datenbankkonfiguration
tatsächlich vorhandenem XML-Element
```

`ActualRowsRead` und `EstimatedRowsRead` zeigen, warum die Major Version allein nicht genügt: Diese Attribute wurden in älteren Versionen über Service Packs beziehungsweise Updates ergänzt. ([Microsoft Unterstützung][1])

## 5.2 Empfohlene Capability-Ermittlung

Ausgeben:

```text
ServerMajorVersion
ServerProductVersion
CompatibilityLevel
ShowplanVersion
ShowplanBuild
CardinalityEstimationModelVersion
PlanSource
RuntimeCounterScope
```

Danach je Kennzahl:

```text
MetricCode
IsAvailable
AvailabilityReason
EvidenceLevel
```

Beispiel:

```text
ACTUAL_ROWS_READ:
    IsAvailable       = 0
    AvailabilityReason = ACTUAL_ATTRIBUTE_NOT_PRESENT
```

Fehlende Informationen werden `NULL`, niemals `0`.

## 5.3 Zielversionsmatrix

| Information                                       |                     SQL 2019 |                   SQL 2022 |                   SQL 2025 |
| ------------------------------------------------- | ---------------------------: | -------------------------: | -------------------------: |
| Compile Showplan                                  |                           ja |                         ja |                         ja |
| Last Known Actual über `dm_exec_query_plan_stats` | ja, wenn aktiviert/verfügbar |                         ja |                         ja |
| DOP-/Grant-Kennzahlen in Query Stats              |                           ja |                         ja |                         ja |
| Spillseiten in Query Stats                        |                           ja |                         ja |                         ja |
| PSP Dispatcher/Variants                           |                         nein | ab Compatibility Level 160 |                         ja |
| Query-Store Query Variants/Plan Feedback          |                         nein |                         ja |                         ja |
| OPPO Dispatcher/Variants                          |                         nein |                       nein | ab Compatibility Level 170 |

`sys.dm_exec_query_plan_stats` gilt ab SQL Server 2019 und liefert den letzten bekannten Actual Plan eines gecachten Plans, sofern die zugrunde liegende Erfassung verfügbar ist. ([Microsoft Learn][5])

DOP- und Memory-Grant-Kennzahlen stehen in `sys.dm_exec_query_stats` seit SQL Server 2016 zur Verfügung; Spillkennzahlen seit SQL Server 2017 CU3. Damit sind sie für die drei Zielversionen grundsätzlich vorhanden. ([Microsoft Learn][6])

PSP ist ab SQL Server 2022 mit Compatibility Level 160 verfügbar und erzeugt Dispatcher- sowie Query-Variant-Pläne. ([Microsoft Learn][7])

OPPO baut auf dieser Multiplan-Infrastruktur auf und gilt für SQL Server 2025 mit Compatibility Level 170. ([Microsoft Learn][8])

Das vorhandene `USP_IntelligentQueryProcessingAnalysis` unterscheidet bereits SQL Server 2022/2025 und Compatibility Level 160/170 für PSP und OPPO.

### Implementierungsregel

* XML-Attribute werden nach tatsächlichem Vorhandensein verarbeitet.
* Versionen bestimmen, ob eine Quelle überhaupt abgefragt werden darf.
* Versionsabhängige Katalogsichten und DMV-Spalten werden über getrenntes Dynamic SQL geladen.
* Ein unbekanntes neues XML-Element darf die Analyse nicht abbrechen.
* Findings besitzen eine deklarierte `RequiredCapability`.

---

# 6. `SET STATISTICS IO` und `SET STATISTICS TIME` zusätzlich übergeben

## Bewertung

**Ja, das wäre sehr hilfreich.** Diese Informationen sollten aber als eigene, optional übergebene **Execution Evidence** behandelt werden und nicht als Bestandteil des Plans.

`SET STATISTICS IO` liefert je betroffenem Objekt unter anderem:

* Scan Count,
* Logical Reads,
* Physical Reads,
* Read-Ahead Reads,
* LOB Reads,
* gegebenenfalls Page-Server-Werte. ([Microsoft Learn][9])

`SET STATISTICS TIME` liefert:

* Parse-/Compile-CPU,
* Parse-/Compile-Elapsed,
* Execution CPU,
* Execution Elapsed. ([Microsoft Learn][10])

## 6.1 Zusätzlicher Erkenntnisgewinn

### Plan zeigt

```text
Operatorstruktur
Rows und Rows Read
Predicates
Spills
Memory Grant
Parallelismus
```

### Statistics IO zeigt

```text
tatsächliche Seitenarbeit je Objekt
Worktable-/Workfile-Effekte
LOB-Arbeit
Read-Ahead
physische versus logische Reads
Scan Count
```

### Statistics TIME zeigt

```text
Gesamt-CPU und Gesamtzeit der konkreten Ausführung
Compilekosten
Verhältnis CPU zu Elapsed
```

Besonders wertvoll ist die Kombination:

```text
viele Rows Read,
aber wenige Logical Reads
```

Das kann bei einem sehr schmalen oder komprimierten Zugriff weniger problematisch sein als zunächst angenommen.

Umgekehrt:

```text
relativ wenige Rows,
aber sehr viele Logical Reads
```

kann auf breite Zeilen, viele Lookups, wiederholte innere Zugriffe oder LOB-Arbeit hindeuten.

---

## 6.2 Zwingende Einschränkungen

Die übergebenen Werte müssen nach Möglichkeit von **derselben Ausführung** stammen wie der Actual Plan.

Andernfalls kann Folgendes passieren:

```text
Plan           = letzte Ausführung mit Parameter A
Statistics IO  = Ausführung mit Parameter B
Statistics TIME = Ausführung mit Parameter C
```

Dann ist eine direkte Korrelation nicht belastbar.

Notwendige Metadaten:

```text
IsSameExecutionConfirmed
CapturedAtUtc
StatementOrdinal
BatchTextHash
QueryHash
QueryPlanHash
Language
CaptureSource
```

`Physical Reads` sind stark vom Cachezustand abhängig und sollten nicht allein als Planqualitätskennzahl verwendet werden. `Logical Reads` sind für Vergleichsmessungen meist stabiler, bleiben aber abhängig von Datenstand, Parameterwerten und Ausführungsumgebung.

---

## 6.3 Raw-Text-Parsing oder strukturierte Übergabe?

### Hauptempfehlung: strukturierte Übergabe

```sql
@ExecutionEvidenceJson nvarchar(max) = NULL
```

Beispiel mit ausschließlich synthetischen Bezeichnern:

```json
{
  "capture": {
    "sameExecutionAsPlan": true,
    "language": "de-DE",
    "statementOrdinal": 1
  },
  "statisticsIo": [
    {
      "objectName": "ExampleObject",
      "scanCount": 1,
      "logicalReads": 12500,
      "physicalReads": 0,
      "readAheadReads": 0,
      "lobLogicalReads": 0
    }
  ],
  "statisticsTime": {
    "compileCpuMs": 4,
    "compileElapsedMs": 6,
    "executionCpuMs": 380,
    "executionElapsedMs": 210
  }
}
```

### Komfortoption: Raw Text

Zusätzlich möglich:

```sql
@StatisticsIoText   nvarchar(max) = NULL,
@StatisticsTimeText nvarchar(max) = NULL,
@StatisticsLanguage varchar(16)   = NULL
```

Der Parser wäre jedoch nur best effort. Die Ausgabe ist menschenorientierter Message-Text, kann mehrere Statements enthalten und ist sprachabhängig. Das ist eine Implementierungsableitung aus der dokumentierten Ausgabeform; deshalb sollte der Parser immer einen Status liefern:

```text
PARSED
PARSED_PARTIAL
UNSUPPORTED_LANGUAGE
AMBIGUOUS_STATEMENT_MAPPING
UNRECOGNIZED_FORMAT
```

Der Raw-Text darf niemals ungeprüft eine hohe Confidence erzeugen.

---

## 6.4 Kein automatisches erneutes Ausführen

Das Framework sollte **keine beliebige Query erneut ausführen**, um `STATISTICS IO/TIME` selbst zu erzeugen.

Das wäre riskant wegen:

* DML,
* langen Laufzeiten,
* Locking und Blocking,
* Ressourcenverbrauch,
* veränderten Parameterwerten,
* Seiteneffekten.

Es sollte ausschließlich bereits vom Benutzer oder einem sicheren Client erfasste Evidenz entgegennehmen.

---

# 7. Empfohlene Gesamtarchitektur

## P0 – fachliche Korrektur

1. Runtime Counters paarweise erfassen.
2. `ActualRowsRead` nur bei tatsächlicher Verfügbarkeit verwenden.
3. sichere Decimal-Arithmetik.
4. Status statt erfundener Nullwerte.
5. Statement- und Node-Bezug herstellen.
6. Versions-/Capability-Tabelle je Plan erzeugen.

## P1 – Regeln und Workloadkontext

1. `PlanAnalysisProfile`
2. `PlanAnalysisRuleThreshold`
3. `PlanAnalysisProfileAssignment`
4. Regeln bleiben in T-SQL, Thresholds in Tabellen.
5. Relative und absolute Kriterien kombinieren.
6. Per-Execution- und Cumulative-Impact getrennt bewerten.

## P2 – Indexreihenfolge

1. Seek Keys und residuale Spalten extrahieren.
2. Indexschlüssel und ASC/DESC aus Katalogen ergänzen.
3. benötigte Operatorreihenfolge ermitteln.
4. equality-constrained Prefix berücksichtigen.
5. Backward Scan berücksichtigen.
6. nur teure beziehungsweise wirkungsrelevante Sortierungen melden.

## P3 – zusätzliche Execution Evidence

1. strukturierte JSON-Übergabe,
2. optionaler Raw-Parser,
3. Same-Execution-Bestätigung,
4. getrennte Resultsets für IO und TIME,
5. keine automatische Query-Ausführung.

## Fazit

**Korrektur:** Das bisher vorgeschlagene Prozentmuster ist ohne Pairing, Statusprüfung und kontrollierte Decimal-Arithmetik nicht belastbar.

**Hauptempfehlung:** Die meisten Regeln sollten sich bereits durch die Kombination aus Verhältnis, absoluter Arbeit, Häufigkeit und kumulativer Wirkung an OLTP und Batch anpassen. Workload-Profile dienen danach zur Feinsteuerung der Severity.

**Indexanalyse:** Sowohl die Schlüsselreihenfolge für Seek-Zugriffe als auch ASC/DESC und die Reihenfolge für Sort-, Merge-, Stream-Aggregate- oder Window-Anforderungen sollten analysiert werden. Das Ergebnis ist ein Reviewhinweis, keine automatische Index-DDL.

**Statistics IO/TIME:** Als optional bestätigte Evidenz derselben Ausführung sind diese Informationen sehr wertvoll und ergänzen den Plan um reale Seitenarbeit, Compilezeit sowie Statement-CPU und -Dauer.

[1]: https://support.microsoft.com/en-au/topic/kb3107397-improved-diagnostics-for-query-execution-plans-that-involve-residual-predicate-pushdown-in-sql-server-872f6ff3-dc77-c6f1-15dd-0c013b423cd7 "https://support.microsoft.com/en-au/topic/kb3107397-improved-diagnostics-for-query-execution-plans-that-involve-residual-predicate-pushdown-in-sql-server-872f6ff3-dc77-c6f1-15dd-0c013b423cd7"
[2]: https://learn.microsoft.com/en-us/sql/relational-databases/statistics/view-statistics-properties?view=sql-server-ver17 "https://learn.microsoft.com/en-us/sql/relational-databases/statistics/view-statistics-properties?view=sql-server-ver17"
[3]: https://learn.microsoft.com/de-de/sql/relational-databases/sql-server-index-design-guide?view=sql-server-ver17 "https://learn.microsoft.com/de-de/sql/relational-databases/sql-server-index-design-guide?view=sql-server-ver17"
[4]: https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference?view=sql-server-2017 "https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference?view=sql-server-2017"
[5]: https://learn.microsoft.com/de-at/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-query-plan-stats-transact-sql?view=sql-server-linux-ver17 "https://learn.microsoft.com/de-at/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-query-plan-stats-transact-sql?view=sql-server-linux-ver17"
[6]: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-trigger-stats-transact-sql?view=sql-server-ver17 "https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-trigger-stats-transact-sql?view=sql-server-ver17"
[7]: https://learn.microsoft.com/en-us/sql/relational-databases/performance/parameter-sensitive-plan-optimization?view=sql-server-ver17 "https://learn.microsoft.com/en-us/sql/relational-databases/performance/parameter-sensitive-plan-optimization?view=sql-server-ver17"
[8]: https://learn.microsoft.com/da-dk/sql/relational-databases/performance/optional-parameter-optimization?view=sql-server-ver17 "https://learn.microsoft.com/da-dk/sql/relational-databases/performance/optional-parameter-optimization?view=sql-server-ver17"
[9]: https://learn.microsoft.com/de-de/sql/t-sql/statements/set-statistics-io-transact-sql?view=sql-server-ver17 "https://learn.microsoft.com/de-de/sql/t-sql/statements/set-statistics-io-transact-sql?view=sql-server-ver17"
[10]: https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statistics-time-transact-sql?redirectedfrom=MSDN&view=sql-server-ver16 "https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statistics-time-transact-sql?redirectedfrom=MSDN&view=sql-server-ver16"



erstelle einen Plan für diese neue/erweiterte Auswertung
idealerweise kann diese Standalone ausgeführt werden - also Übergabe Plan und evtl. set statistics informationen
hast du weitere Anregungen, Ideen für den Aufbau dieser Abfrage?


# Zielbild

Die neue Auswertung sollte **nicht als weitere Vergrößerung von `USP_ShowplanAnalysis`** umgesetzt werden.

Empfohlen ist eine Trennung:

```text
monitor.USP_ExecutionPlanAnalysis
    Analysiert genau einen direkt übergebenen Plan.
    Vollständig standalone und ohne Plan Cache ausführbar.

monitor.USP_ShowplanAnalysis
    Sucht Pläne im Plan Cache beziehungsweise Last-Actual-Plan.
    Ruft für jeden ausgewählten Plan die Standalone-Analyse auf.

monitor.USP_PlanCacheAnalysis
    Bleibt übergeordneter Orchestrator.
```

`USP_ShowplanAnalysis` vermischt derzeit Kandidatenauswahl, Planbeschaffung, XML-Shredding, Bewertung und Ausgabe. Zugleich besitzt es bereits zahlreiche RAW-/JSON-Resultsets, während TABLE bislang ausschließlich `findings` exportiert.

Die Standalone-Procedure wird damit zum **kanonischen Analyseobjekt für einen einzelnen Plan**. Alle anderen Procedures beschaffen nur noch Plan und Kontext.

---

# 1. Vorgesehene Objekte

## 1.1 Neues öffentliches Hauptobjekt

```text
monitor.USP_ExecutionPlanAnalysis
```

Aufgaben:

* Plan-XML entgegennehmen und validieren
* Statements eindeutig identifizieren
* Operatorbaum erzeugen
* Estimated- und Actual-Informationen extrahieren
* Runtime Counters korrekt aggregieren
* externe Execution Evidence einlesen
* Index-, Statistik-, Memory-, Spill- und Parallelism-Analyse
* workloadabhängige Regeln anwenden
* strukturierte Findings erzeugen

Die Procedure analysiert **genau einen Plan pro Aufruf**. Das begrenzt Eigenlast und vereinfacht Fehlerisolierung.

---

## 1.2 Bestehendes Objekt als Wrapper

```text
monitor.USP_ShowplanAnalysis
```

Neue Hauptaufgaben:

1. Kandidaten aus Plan Cache auswählen.
2. Compile-, Last-Actual- oder andere Planquelle laden.
3. Pläne nach `plan_handle` deduplizieren.
4. `USP_ExecutionPlanAnalysis` je Plan aufrufen.
5. Ergebnisse über eine Korrelations-ID zusammenführen.

Der gemeinsame `dm_exec_query_stats`-Snapshot des bestehenden `USP_PlanCacheAnalysis` kann weiterverwendet werden; er enthält bereits Statementoffsets, Query Hash, Plan Hash, Rows, DOP, Grants und Spills.

---

## 1.3 Neue Steuertabellen

```text
monitor.PlanAnalysisRuleCatalog
monitor.PlanAnalysisWorkloadProfile
monitor.PlanAnalysisRuleThreshold
monitor.PlanAnalysisProfileAssignment
```

Das folgt dem bereits im Repository verwendeten metadata-driven Muster mit Regelcode, Priorität, Aktivierung und deterministischer Auswahl.

---

# 2. Vorgeschlagene Signatur

```sql
CREATE OR ALTER PROCEDURE [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml                         xml             = NULL
    , @PlanXmlText                     nvarchar(max)   = NULL

    , @StatementId                     int             = NULL
    , @StatementQueryHash              binary(8)       = NULL

    , @EvidenzJson                     nvarchar(max)   = NULL
    , @StatisticsIoText                nvarchar(max)   = NULL
    , @StatisticsTimeText              nvarchar(max)   = NULL
    , @StatisticsSprache               varchar(10)     = 'AUTO'
    , @EvidenzStatementOrdinal         int             = NULL
    , @GleicheAusfuehrungBestaetigt    bit             = 0
    , @ErfassungszeitUtc               datetime2(3)    = NULL

    , @QuellProduktversion             nvarchar(128)   = NULL
    , @QuellKompatibilitaetsgrad       smallint        = NULL

    , @WorkloadProfil                  varchar(32)     = 'AUTO'
    , @AnalyseTiefe                    varchar(16)     = 'STANDARD'
    , @MetadatenAnreicherung           varchar(16)     = 'NONE'
    , @MindestSchweregrad              varchar(16)     = 'INFO'

    , @ParameterwertModus              varchar(16)     = 'NONE'
    , @MaxSqlTextZeichen               int             = 4000

    , @MaxPlanXmlBytes                 bigint          = 33554432
    , @MaxOperatoren                   int             = 10000
    , @MaxThreadZeilen                 int             = 50000
    , @MaxFindings                     int             = 5000
    , @MaxDurationSeconds              int             = 30

    , @HighImpactConfirmed             bit             = 0
    , @KorrelationsId                  bigint          = NULL

    , @ResultSetArt                    varchar(16)     = 'CONSOLE'
    , @ResultTablesJson                nvarchar(max)   = NULL
    , @JsonErzeugen                    bit             = 0
    , @Json                            nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                  bit             = 1
    , @Hilfe                           bit             = 0

    , @StatusCodeOut                   varchar(40)     = NULL OUTPUT
    , @IsPartialOut                    bit             = NULL OUTPUT
    , @ErrorNumberOut                  int             = NULL OUTPUT
    , @ErrorMessageOut                 nvarchar(2048)  = NULL OUTPUT;
```

---

# 3. Bedeutung der Parameter

## 3.1 Planeingabe

### `@PlanXml`

Bevorzugter Pfad für bereits gültiges XML:

```sql
DECLARE @Plan xml = N'<ShowPlanXML ... />';

EXEC [monitor].[USP_ExecutionPlanAnalysis]
    @PlanXml = @Plan;
```

### `@PlanXmlText`

Erlaubt kontrollierte Behandlung ungültiger oder nicht direkt als `xml` typisierbarer Eingaben:

```sql
EXEC [monitor].[USP_ExecutionPlanAnalysis]
    @PlanXmlText = @PlanText;
```

Intern:

```sql
SET @NormalizedPlanXml = TRY_CONVERT(xml, @PlanXmlText);
```

Genau einer der beiden Parameter darf gesetzt sein.

`@PlanXmlText` ist außerdem hilfreich für Query-Store-Pläne, Textimporte oder kopierte `.sqlplan`-Inhalte.

---

## 3.2 Statementauswahl

Standardmäßig werden alle Statements des Plan-Dokuments analysiert.

Optional:

```text
@StatementId
@StatementQueryHash
```

Damit kann bei einem großen mehrstatementigen Procedure-Plan gezielt ein Statement untersucht werden.

Sind beide angegeben, müssen sie dasselbe Statement identifizieren.

Die interne Statementidentität sollte enthalten:

```text
PlanAnalysisId
StatementOrdinal
StatementId
StatementCompId
StatementQueryHash
StatementQueryPlanHash
StatementStartOffset
StatementEndOffset
```

Falls ältere oder spezielle Planformen keine vollständige Statement-ID liefern, bleibt mindestens ein interner `StatementOrdinal` erhalten.

---

# 4. Externe Evidenz

## 4.1 Kanonischer Pfad: `@EvidenzJson`

Das JSON wird versioniert:

```json
{
  "schemaVersion": 1,
  "capture": {
    "sameExecutionAsPlan": true,
    "capturedAtUtc": "2026-07-21T08:00:00.000Z",
    "statementOrdinal": 1,
    "sourceProductVersion": "17.x",
    "compatibilityLevel": 170
  },
  "statisticsIo": [
    {
      "objectName": "ExampleObject",
      "scanCount": 1,
      "logicalReads": 12500,
      "physicalReads": 0,
      "readAheadReads": 0,
      "lobLogicalReads": 0
    }
  ],
  "statisticsTime": {
    "compileCpuMs": 4,
    "compileElapsedMs": 6,
    "executionCpuMs": 380,
    "executionElapsedMs": 210
  },
  "indexes": [
    {
      "databaseName": "ExampleDatabase",
      "schemaName": "ExampleSchema",
      "objectName": "ExampleObject",
      "indexName": "IX_Example",
      "keys": [
        {
          "ordinal": 1,
          "columnName": "ExampleKey",
          "direction": "ASC"
        }
      ]
    }
  ],
  "workload": {
    "profile": "LATENCY_SENSITIVE"
  }
}
```

Damit kann die Procedure auch **offline** genaue Indexreihenfolgen bewerten, ohne auf die Quelldatenbank zugreifen zu müssen.

---

## 4.2 Komfortpfad: rohe `STATISTICS IO/TIME`-Texte

```text
@StatisticsIoText
@StatisticsTimeText
@StatisticsSprache
```

Vorgesehene Sprachwerte:

```text
AUTO
DE
EN
```

In der ersten Version sollte nur Deutsch und Englisch unterstützt werden. Der Parser muss als best effort arbeiten:

```text
PARSED
PARSED_PARTIAL
UNSUPPORTED_LANGUAGE
AMBIGUOUS_STATEMENT_MAPPING
UNRECOGNIZED_FORMAT
```

Da SQL Server 2019 unterstützt werden muss, darf der Parser nicht auf SQL-Server-2025-Regexfunktionen angewiesen sein.

---

## 4.3 Statementzuordnung externer Daten

Bei einem Plan mit genau einem Statement erfolgt die Zuordnung automatisch.

Bei mehreren Statements:

```text
@EvidenzStatementOrdinal
```

oder eine statementbezogene Zuordnung im JSON.

Ohne eindeutige Zuordnung werden die IO-/TIME-Werte nur auf Planebene dargestellt. Sie dürfen dann keine operatorbezogenen Findings mit hoher Confidence auslösen.

---

# 5. Analysemodi

## `@AnalyseTiefe`

### `SUMMARY`

* Planübersicht
* Statements
* wichtigste Warnings
* Findings
* keine Threaddetails
* keine vollständigen Predicates
* geringe Eigenlast

### `STANDARD`

Default:

* vollständiger Operatorbaum
* aggregierte Runtime Counters
* Seek-/Residual-Predicates
* Objekte und Indizes
* Statistics Usage
* Memory Grants und Spills
* Indexreihenfolge, soweit Evidenz vorhanden
* externe IO-/TIME-Evidenz

### `DEEP`

Zusätzlich:

* Runtime je Thread
* Parallelism Skew
* detaillierte Output-/Defined-Column-Analyse
* umfangreiche Operatorpfade
* Root-Cause- und Finding-Suppression
* lokale Metadatenanreicherung
* erweiterte Query-Store-/IQP-Korrelation

`DEEP` benötigt bei teuren Zusatzquellen das vorhandene High-Impact-Gate.

---

# 6. Metadatenanreicherung

## `@MetadatenAnreicherung`

### `NONE`

Reine Standalone-Analyse.

Es werden ausschließlich Plan und übergebene Evidenz verwendet.

### `EVIDENCE`

Index-, Objekt- und Statistikmetadaten werden nur aus `@EvidenzJson` verwendet.

### `LOCAL`

Planobjekte werden explizit gegen die aktuelle SQL-Server-Instanz aufgelöst.

### `ALL`

JSON-Evidenz wird bevorzugt; fehlende Informationen werden lokal ergänzt.

## Sicherheits- und Performance-Regeln

Bei lokaler Anreicherung:

* `SET LOCK_TIMEOUT 0`
* jedes Objekt isoliert anreichern
* Fehler eines Objekts dürfen andere Objekte nicht verhindern
* direkte Joins gegen `sys.objects`, `sys.indexes`, `sys.index_columns`, `sys.stats`
* keine Verwendung von `OBJECT_ID()` für normale Benutzerobjekte
* `OBJECT_ID()` nur dort, wo TempDB-Zuordnung technisch notwendig ist
* keine Reads aus Benutzertabellen

---

# 7. Workloadprofile

## `@WorkloadProfil`

```text
AUTO
BALANCED
LATENCY_SENSITIVE
THROUGHPUT
MAINTENANCE
```

### `BALANCED`

Neutrale Defaultbewertung.

### `LATENCY_SENSITIVE`

Stärkere Gewichtung von:

* Reads je Ausführung
* CPU je Ausführung
* Dauer je Ausführung
* Lookup-Anzahl
* häufigen kleinen Ineffizienzen
* seriellen Engpässen

### `THROUGHPUT`

Stärkere Gewichtung von:

* absoluten Datenmengen
* totalen Reads
* TempDB-Spills
* Memory Grants
* Parallelism Skew
* Datenbewegung und Sortierung

### `MAINTENANCE`

Große Scans und Sorts sind teilweise erwartbar. Kritischer bleiben:

* unnötige wiederholte Scans
* extreme Spills
* offensichtlich falsche Partitionauswahl
* ineffiziente DOP-Nutzung
* Blocking-/Log-/TempDB-Risiken

### `AUTO`

Zuordnungshierarchie:

1. explizite JSON-Angabe,
2. `PlanAnalysisProfileAssignment`,
3. Query-/Objekt-/Resource-Pool-Zuordnung,
4. automatische Klassifikation mit Confidence,
5. Fallback `BALANCED`.

Eine große Datenmenge allein darf niemals automatisch `MAINTENANCE` ergeben.

---

# 8. Regelmodell

## 8.1 `PlanAnalysisRuleCatalog`

Beispielspalten:

```text
RuleCode
Category
Description
DefaultSeverity
RequiredEvidenceLevel
RequiredCapability
IsEnabled
SourceUrl
EvidenceLimit
RecommendedNextCheck
```

Beispielregeln:

```text
CARDINALITY_MISESTIMATE
ROWS_READ_NOT_RETURNED
SEEK_RESIDUAL_HIGH_WORK
LOOKUP_HIGH_EXECUTION_COUNT
SORT_SPILL
HASH_SPILL
EXCHANGE_SPILL
MEMORY_GRANT_OVER
MEMORY_GRANT_UNDER
PARALLEL_THREAD_SKEW
INDEX_KEY_ORDER_LIMITS_SEEK
INDEX_ORDER_DOES_NOT_SATISFY_REQUIRED_ORDER
ROW_GOAL_LARGE_ACTUAL
OPTIMIZER_TIMEOUT
PLAN_AFFECTING_CONVERT
```

---

## 8.2 `PlanAnalysisRuleThreshold`

Jede Regel kann mehrere Schweregradstufen je Profil besitzen:

```text
RuleCode
ProfileCode
Severity
MinRatio
MinAbsoluteRows
MinRowsRead
MinRowsNotReturned
MinLogicalReadsPerExecution
MinTotalLogicalReads
MinExecutionCount
MinElapsedMs
MinCpuMs
MinSpilledPages
MinGrantKb
MinServerMajorVersion
MinCompatibilityLevel
RequiredEvidenceLevel
AdditionalConfigurationJson
```

Das Repository verwendet bereits bei der Statistics Distribution getrennte Werte für Severity, Confidence, Metric und Threshold. Dieses Modell sollte für Plananalysen übernommen werden.

Die Regeln selbst bleiben in geprüftem T-SQL. Die Tabelle enthält keine freien SQL-Ausdrücke.

---

# 9. Verarbeitungsphasen

## Phase 1 – Eingabevalidierung

Prüfen:

* genau eine Planeingabe
* XML syntaktisch gültig
* Showplan-Dokument erkennbar
* Eingabegröße
* JSON-Schema
* zulässige Profile und Modi
* Statementselektor eindeutig
* TABLE-Ziele vor teuren Zugriffen

Statusbeispiele:

```text
AVAILABLE
INVALID_PARAMETER
INVALID_PLAN_XML
UNSUPPORTED_PLAN_FORMAT
PLAN_TOO_LARGE
STATEMENT_NOT_FOUND
PARTIAL
```

---

## Phase 2 – Plan- und Capability-Ermittlung

Extrahieren:

```text
ShowplanVersion
ShowplanBuild
PlanSource
PlanXmlBytes
PlanHash
StatementCount
OperatorCount
HasRuntimeInformation
HasThreadRuntime
HasActualRowsRead
HasMemoryGrantInfo
HasSpillDetails
HasQueryVariants
HasPlanFeedbackReferences
CardinalityEstimationModelVersions
```

Zusätzlich ein eigenes Capability-Resultset:

```text
CapabilityCode
IsAvailable
AvailabilityReason
Source
```

Beispiele:

```text
ACTUAL_ROWS
ACTUAL_ROWS_READ
THREAD_RUNTIME
SORT_SPILL_DETAILS
HASH_SPILL_DETAILS
EXCHANGE_SPILL_DETAILS
PSP_VARIANTS
OPPO_VARIANTS
PLAN_FEEDBACK
```

Fehlende Informationen werden `NULL`, nie `0`.

---

## Phase 3 – Statements

Nicht nur `StmtSimple` betrachten, sondern auch andere vorhandene Statementformen:

```text
StmtSimple
StmtCond
StmtCursor
weitere vom Dokument bereitgestellte Statementknoten
```

Extrahieren:

* Typ und Text
* Statement ID und Comp ID
* Query Hash und Plan Hash
* Kosten
* Optimization Level
* Early Abort Reason
* Compile Time, CPU und Memory
* CE-Modell
* Non-Parallel Plan Reason
* Hints
* Parameter
* Query-Variant-Informationen

---

## Phase 4 – Operatorbaum

Einmaliges namespace-aware XML-Shredding.

Nicht jeden Finding-Typ erneut über:

```text
//*[local-name(.)="..."]
```

suchen.

Stattdessen einen kanonischen Operatorbestand erzeugen:

```text
StatementOrdinal
StatementId
NodeId
ParentNodeId
ChildOrdinal
Depth
OperatorPath
PhysicalOp
LogicalOp
EstimatedRows
EstimatedRowsRead
EstimatedExecutions
EstimatedCpu
EstimatedIo
EstimatedSubtreeCost
AverageRowSize
Parallel
EstimatedExecutionMode
ActualExecutionMode
Ordered
ScanDirection
```

Der Showplan-Namespace sollte primär explizit verwendet werden. `local-name()` bleibt nur Fallback für unerwartete oder nicht standardkonforme Dokumente.

---

## Phase 5 – Runtime Counters

Zunächst eine Zeile je:

```text
StatementId
NodeId
ThreadId
RuntimeCounterOrdinal
```

Erst danach aggregieren.

Damit werden `ActualRows` und `ActualRowsRead` korrekt gepaart.

Zu erfassen:

* Actual Rows
* Actual Rows Read
* Actual Executions
* Rebinds
* Rewinds
* Logical Reads
* Physical Reads
* Read-Ahead Reads
* LOB Reads
* CPU
* Elapsed
* Scans
* End-of-Scans
* Thread-ID

Status der Abdeckung:

```text
RuntimeCounterCount
RowsReadCounterCount
RowsReadCounterCoveragePercent
RuntimeInformationState
```

---

## Phase 6 – Predicates und Access

Getrennte Extraktion von:

```text
SeekPredicate
ResidualPredicate
ProbeResidual
StartupExpression
PassThroughPredicate
JoinPredicate
PredicateColumn
RangeType
ComparisonType
ScalarExpression
```

Dadurch können präzise Findings erzeugt werden:

```text
SEEK_RESIDUAL_HIGH_WORK
LATER_INDEX_KEY_USED_AS_RESIDUAL
LEADING_INDEX_KEY_NOT_CONSTRAINED
RANGE_KEY_PREVENTS_DEEP_SEEK
PLAN_AFFECTING_CONVERT_ON_INDEX_COLUMN
```

---

## Phase 7 – Indexreihenfolge

### Plan-only

Ohne Indexdefinition kann nur festgestellt werden:

* Sort vorhanden
* geordnete Ausgabe erforderlich
* Seek-/Residualspalten
* Backward Scan
* Merge-/Stream-Aggregate-/Window-Anforderung

Das ergibt Findings mit niedriger oder mittlerer Confidence.

### Mit Metadaten

Mit `sys.index_columns` oder Evidenz-JSON:

* Key Ordinal
* ASC/DESC
* Included Columns
* Filterdefinition
* Equality-constrained Prefix
* erste Range-Spalte
* benötigte Sortierreihenfolge

Dann sind belastbarere Findings möglich:

```text
INDEX_KEY_ORDER_LIMITS_SEEK
INDEX_ORDER_DOES_NOT_SATISFY_REQUIRED_ORDER
INDEX_ORDER_SATISFIES_REVERSE_SCAN
INDEX_ORDER_SUPPORTS_ONLY_PARTIAL_ORDER
EXPENSIVE_SORT_POTENTIALLY_AVOIDABLE_BY_INDEX_ORDER
```

Die Ausgabe darf nicht behaupten, ein Index sei generell „falsch sortiert“. Sie bewertet nur diesen konkreten Zugriff.

---

## Phase 8 – Memory und Spills

Trennen:

```text
MemoryGrant
SortSpill
HashSpill
HashRecursion
HashBailout
ExchangeSpill
```

Zu jedem Spill:

```text
StatementId
NodeId
PhysicalOp
SpillType
SpillLevel
SpilledRows
SpilledPages
SpilledDataSize
TempdbReads
TempdbWrites
GrantedMemoryKb
UsedMemoryKb
ExecutionCount
```

Memory-Grant-Findings dürfen nicht allein auf:

```text
MaxUsedMemory >= GrantedMemory
```

beruhen.

Für einen belastbaren Undergrant werden zusätzliche Signale benötigt:

* Spill
* Grant Wait
* Hash Recursion/Bailout
* explizite Warning
* starke Cardinality-Unterschätzung

---

## Phase 9 – externe IO-/TIME-Korrelation

Aus `STATISTICS IO`:

```text
ObjectName
ScanCount
LogicalReads
PhysicalReads
ReadAheadReads
LobLogicalReads
LobPhysicalReads
LobReadAheadReads
```

Aus `STATISTICS TIME`:

```text
CompileCpuMs
CompileElapsedMs
ExecutionCpuMs
ExecutionElapsedMs
```

Abgeleitete Kennzahlen:

```text
LogicalReadsPerReturnedRow
LogicalReadsPerRowsRead
CpuMsPerThousandRows
ElapsedMinusCpuMs
CompileToExecutionCpuRatio
PlanObjectReadsCoverage
```

Confidence:

```text
SAME_EXECUTION_CONFIRMED
SAME_QUERY_AND_PLAN_CONFIRMED
STATEMENT_MAPPING_INFERRED
PLAN_LEVEL_ONLY
UNCONFIRMED
```

---

## Phase 10 – Findings

Jedes Finding sollte mindestens enthalten:

```text
FindingOrdinal
KorrelationsId
StatementId
NodeId
Category
FindingCode
Severity
Confidence
EvidenceSource
WorkloadProfile
ObservedMetricName
ObservedMetricValue
ThresholdMetricName
ThresholdMetricValue
ImpactValue
ImpactUnit
Summary
Evidence
EvidenceLimit
RecommendedNextCheck
IsPrimaryFinding
RelatedFindingOrdinal
```

---

# 10. Resultsets

## Console-Default

Nur:

```text
findings
```

Damit bleibt CONSOLE übersichtlich.

## RAW-/TABLE-Resultsets

```text
analysisStatus
capabilities
planSummary
statements
operators
operatorRuntime
operatorThreadRuntime
predicates
objects
indexes
statisticsUsage
memoryGrants
spills
parameters
externalIo
externalTime
ruleEvaluation
findings
```

`operatorThreadRuntime` und `ruleEvaluation` können nur bei `DEEP` ausgegeben werden.

---

# 11. Zusätzliche sinnvolle Erweiterungen

## 11.1 Plan-Hash des übergebenen Dokuments

```text
PlanDocumentHash
```

Berechnung über `SHA2_256`.

Damit kann dasselbe XML wiedererkannt werden, auch wenn kein Planhandle vorhanden ist.

---

## 11.2 Plan-Shape-Hash

Zusätzlich kann später ein normalisierter Hash erzeugt werden aus:

```text
Statement
OperatorPath
PhysicalOp
LogicalOp
Object
Index
JoinType
ExecutionMode
```

Volatile Runtimewerte und Parameter werden nicht berücksichtigt.

Damit lassen sich zwei Pläne strukturell vergleichen, auch wenn ihre XML-Dokumente unterschiedlich sind.

---

## 11.3 Evidenzvollständigkeit

Keine künstliche Prozentzahl, sondern ein klarer Status:

```text
ESTIMATED_ONLY
ACTUAL_PARTIAL
ACTUAL_COMPLETE
ACTUAL_WITH_IO_TIME
ACTUAL_WITH_METADATA
ACTUAL_WITH_IO_TIME_AND_METADATA
```

---

## 11.4 Root-Cause-Gruppierung

Ein früher Kardinalitätsfehler kann viele nachgelagerte Abweichungen verursachen.

Daher:

```text
IsPrimaryFinding
RootCauseCandidateNodeId
RelatedFindingOrdinal
SuppressedByFindingOrdinal
```

Beispiel:

* primäres Finding: starke Unterschätzung an einem Access-Operator
* sekundäre Findings:

  * Nested-Loops-Amplification
  * Memory Undergrant
  * Spill
  * nachgelagerter Parallelism Skew

Die sekundären Findings bleiben sichtbar, werden aber nicht als vier unabhängige Ursachen dargestellt.

---

## 11.5 Regel-Evaluationsprotokoll

Optionales Resultset:

```text
ruleEvaluation
```

Enthält auch nicht ausgelöste Regeln:

```text
RuleCode
WasEvaluated
WasTriggered
ObservedValue
ThresholdValue
MissingEvidence
Reason
```

Das erleichtert Test, Kalibrierung und Nachvollziehbarkeit erheblich.

---

## 11.6 Datenschutzfreundliche Ausgabe

```text
@ParameterwertModus =
    NONE
    COMPILED
    RUNTIME
    BOTH
```

Intern dürfen Werte für die Analyse verwendet werden. Ihre Ausgabe ist separat steuerbar.

`@MaxSqlTextZeichen` begrenzt nur die Ausgabeprojektion, nicht die interne Analyse.

---

# 12. Umsetzungsplan

## Welle 0 – Verträge und Architektur

* Signatur festlegen
* Resultsetnamen und Schemas definieren
* JSON-Evidenzschema definieren
* Capability-Codes festlegen
* Workloadprofile festlegen
* Rule-Catalog-Grundstruktur
* synthetische Testfälle entwerfen

**Abnahmekriterium:** Öffentlicher Vertrag ist dokumentiert, bevor Parsercode entsteht.

---

## Welle 1 – Standalone-Grundfunktion

* `USP_ExecutionPlanAnalysis` erstellen
* Plan XML/Text validieren
* Planhash und Capability-Erkennung
* Statements korrekt identifizieren
* genau einen Plan je Aufruf
* `analysisStatus`, `planSummary`, `statements`

**Abnahmekriterium:** Estimated Multi-Statement-Pläne werden ohne Plan Cache korrekt getrennt.

---

## Welle 2 – Operator- und Runtime-Modell

* Operatorbaum
* Parent-/Child-Beziehung
* Operatorpfad
* Runtime pro Thread
* gepaarte Aggregation von Rows/Rows Read
* sichere Prozent- und Verhältniskalkulation
* Coverage-Status

**Abnahmekriterium:** Gleiche `NodeId` in unterschiedlichen Statements wird niemals vermischt.

---

## Welle 3 – Warnings, Memory, Spills und Cardinality

* Plan Warnings
* Cardinality Log Error
* absolute und relative Wirkung
* Memory Grant
* Sort-/Hash-/Exchange-Spills
* Root-Cause-Zuordnung

**Abnahmekriterium:** Findings besitzen Severity und Confidence; keine Division-durch-null- oder Overflowfehler.

---

## Welle 4 – Regel- und Workloadmodell

* vier Steuertabellen
* Defaultprofile
* Thresholdauflösung
* explizite und automatische Profilzuordnung
* `ruleEvaluation`

**Abnahmekriterium:** Derselbe Messwert kann je Profil unterschiedliche Severity erhalten, bleibt aber fachlich identisch dokumentiert.

---

## Welle 5 – Index- und Statistics-Analyse

* Seek-/Residual-Predicates
* lokale oder JSON-basierte Indexmetadaten
* Key Ordinal und ASC/DESC
* benötigte Reihenfolge
* Statistics Usage
* Compilezeit- versus aktueller Statistikstand

**Abnahmekriterium:** Indexreihenfolge wird nur bei vorhandener Evidenz als bestätigt gemeldet.

---

## Welle 6 – externe Execution Evidence

* JSON-Parser
* deutscher und englischer IO-/TIME-Parser
* Statementzuordnung
* Same-Execution-Confidence
* IO-/TIME-Korrelation
* Worktable-/Workfile-Erfassung

**Abnahmekriterium:** Unklar zuordenbare Texte erzeugen `PARSED_PARTIAL`, keine falsche operatorbezogene Korrelation.

---

## Welle 7 – Integration

* `USP_ShowplanAnalysis` zum Wrapper umbauen
* Planhandle-Deduplizierung
* `KorrelationsId` an Standalone-Analyse übergeben
* `USP_PlanCacheAnalysis` anbinden
* Mehrfach-TABLE-Resultsets
* JSON-Envelope aktualisieren

**Abnahmekriterium:** Direkte XML-Analyse und Plan-Cache-Analyse verwenden dieselbe Engine und erzeugen dieselben Findings für denselben Plan.

---

## Welle 8 – SQL-Server-Versionstests

SQL Server:

```text
2019
2022
2025
```

Testklassen:

* Estimated Plan
* Last Actual Plan
* mehrstatementiger Plan
* fehlendes `ActualRowsRead`
* vorhandenes `ActualRowsRead`
* Row- und Batch-Mode
* Parallelplan
* PSP ab 2022
* OPPO ab 2025
* unbekannte zusätzliche XML-Attribute
* fehlende versionsabhängige DMV-/Katalogquellen

**Abnahmekriterium:** Nicht verfügbare Features liefern Capability-Status und `NULL`, keinen Compile- oder Laufzeitfehler.

---

# 13. Hauptempfehlung

Die neue Analyse sollte aus drei klaren Ebenen bestehen:

```text
1. Planmodell
```





soll es eine Funktion geben, welche die Daten für  @EvidenzJson erzeugt?




Ja. Es sollte einen standardisierten Erzeuger für `@EvidenzJson` geben. Ich würde aber zwischen **Erzeugen/Normalisieren** und **aktiver Messung** unterscheiden.

## 1. Öffentliche SQL-Procedure zum Erzeugen des JSON

Empfohlen:

```text
monitor.USP_CreateExecutionEvidenceJson
```

Das wäre ein **user-defined database object vom Typ Stored Procedure**, keine T-SQL-UDF.

Aufgaben:

* übergebenes `STATISTICS IO` parsen,
* übergebenes `STATISTICS TIME` parsen,
* optional den Plan zur Statementzuordnung untersuchen,
* strukturierte Zusatzinformationen integrieren,
* Eingaben validieren,
* ein kanonisches, versioniertes JSON erzeugen,
* Parsefehler und Unsicherheiten ausweisen.

### Vorgeschlagene Signatur

```sql
CREATE OR ALTER PROCEDURE [monitor].[USP_CreateExecutionEvidenceJson]
      @PlanXml                       xml             = NULL
    , @StatisticsIoText              nvarchar(max)   = NULL
    , @StatisticsTimeText            nvarchar(max)   = NULL
    , @StatisticsLanguage            varchar(10)     = 'AUTO'

    , @StatementId                   int             = NULL
    , @StatementOrdinal              int             = NULL
    , @SameExecutionAsPlanConfirmed  bit             = NULL
    , @CapturedAtUtc                 datetime2(3)    = NULL

    , @SourceProductVersion          nvarchar(128)   = NULL
    , @SourceCompatibilityLevel      smallint        = NULL
    , @SourceEngineEdition           int             = NULL

    , @AdditionalEvidenceJson        nvarchar(max)   = NULL
    , @ExistingEvidenceJson          nvarchar(max)   = NULL

    , @RawTextHandling               varchar(16)     = 'HASH_ONLY'
    , @ParameterValueMode            varchar(16)     = 'NONE'
    , @StrictValidation              bit             = 1

    , @ResultSetArt                  varchar(16)     = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0

    , @StatusCodeOut                 varchar(40)     = NULL OUTPUT
    , @IsPartialOut                  bit             = NULL OUTPUT
    , @ErrorNumberOut                int             = NULL OUTPUT
    , @ErrorMessageOut               nvarchar(2048)  = NULL OUTPUT;
```

## 2. Warum keine einzelne SQL-Funktion?

Eine T-SQL-UDF darf keine Operationen mit externen Seiteneffekten ausführen und keine normalen Resultsets erzeugen. Sie eignet sich deshalb nicht als allgemeiner Capture-Mechanismus oder als Orchestrator für mehrere Diagnosequellen. ([Microsoft Learn][1])

Eine UDF wäre nur für **reine Parserteile** sinnvoll:

```text
monitor.TVF_ParseStatisticsIoText
monitor.TVF_ParseStatisticsTimeText
monitor.TVF_ReadExecutionEvidenceJson
```

Diese user-defined inline table-valued functions könnten Text beziehungsweise JSON in relationale Zeilen zerlegen.

Die Aufgabenteilung wäre damit:

```text
TVF_ParseStatisticsIoText
    reiner Parser, keine Seiteneffekte

TVF_ParseStatisticsTimeText
    reiner Parser, keine Seiteneffekte

USP_CreateExecutionEvidenceJson
    Validierung, Zusammenführung, Status, JSON-Erzeugung

USP_ExecutionPlanAnalysis
    eigentliche Plananalyse
```

Das ist performanter und wartbarer als eine große Scalar UDF, die komplexes JSON aufbaut.

---

# 3. Das JSON sollte den Plan nicht duplizieren

`@EvidenzJson` sollte standardmäßig **nicht das vollständige Plan-XML enthalten**. Der Plan bleibt ein eigener Parameter:

```sql
@PlanXml       = @Plan,
@EvidenzJson   = @Evidence
```

Das JSON enthält nur Identitäts- und Korrelationsmerkmale:

```json
{
  "schemaVersion": 1,
  "capture": {
    "capturedAtUtc": "2026-07-21T08:00:00.000Z",
    "sameExecutionAsPlan": true,
    "statementOrdinal": 1,
    "sourceProductVersion": "17.x",
    "sourceCompatibilityLevel": 170
  },
  "planIdentity": {
    "planDocumentHash": "SHA2_256:...",
    "statementId": 1,
    "queryHash": "0x...",
    "queryPlanHash": "0x..."
  },
  "statisticsIo": [],
  "statisticsTime": {},
  "parseStatus": [],
  "warnings": []
}
```

Vorteile:

* keine doppelte große XML-Payload,
* Plan und Evidenz können unabhängig validiert werden,
* dasselbe Evidenzschema kann später auch mit Query-Store- oder Live-Plänen verwendet werden,
* der Planhash ermöglicht die Korrelation.

---

# 4. Inhalt des Evidenz-JSON

## `meta`

```json
{
  "schemaVersion": 1,
  "generatorVersion": "1.0.0"
}
```

Die JSON-Schemaversion muss unabhängig von SQL Server und Showplan-Version sein.

## `capture`

```json
{
  "sameExecutionAsPlan": true,
  "sameExecutionConfidence": "CONFIRMED",
  "capturedAtUtc": "2026-07-21T08:00:00.000Z",
  "statementOrdinal": 1,
  "language": "de-DE"
}
```

Mögliche Confidence-Werte:

```text
CONFIRMED
QUERY_AND_PLAN_MATCH
STATEMENT_MAPPING_INFERRED
PLAN_LEVEL_ONLY
UNCONFIRMED
```

## `sourceEnvironment`

```json
{
  "productVersion": "17.x",
  "compatibilityLevel": 170,
  "engineEdition": 3,
  "showplanVersion": "1.x",
  "showplanBuild": "17.x"
}
```

Keine Werte sollen automatisch aus dem aktuellen Server übernommen werden, wenn der Plan von einem anderen Server stammt.

## `statisticsIo`

```json
[
  {
    "statementOrdinal": 1,
    "objectOrdinal": 1,
    "objectDisplayName": "ExampleObject",
    "scanCount": 1,
    "logicalReads": 12500,
    "physicalReads": 0,
    "readAheadReads": 0,
    "pageServerReads": null,
    "lobLogicalReads": 0,
    "lobPhysicalReads": 0,
    "lobReadAheadReads": 0,
    "parseStatus": "PARSED"
  }
]
```

`SET STATISTICS IO` liefert unter anderem Scan Count sowie logische, physische, Read-Ahead- und LOB-Lesevorgänge. ([Microsoft Learn][2])

## `statisticsTime`

```json
{
  "statementOrdinal": 1,
  "parseAndCompileCpuMs": 4,
  "parseAndCompileElapsedMs": 6,
  "executionCpuMs": 380,
  "executionElapsedMs": 210,
  "parseStatus": "PARSED"
}
```

`SET STATISTICS TIME` unterscheidet Parse-/Compilezeit und Ausführungszeit in CPU- und Elapsed-Millisekunden. ([Microsoft Learn][3])

## `rawInput`

Konfigurierbar über `@RawTextHandling`:

```text
NONE
HASH_ONLY
INCLUDE
```

Default:

```text
HASH_ONLY
```

Dann werden nur gespeichert:

```json
{
  "statisticsIoCharacters": 1840,
  "statisticsIoHash": "SHA2_256:...",
  "statisticsTimeCharacters": 340,
  "statisticsTimeHash": "SHA2_256:..."
}
```

Das verhindert unnötige Payloadgröße und vermeidet, dass Objektbezeichnungen mehrfach im JSON vorkommen.

---

# 5. Verhalten bei mehreren Statements

`STATISTICS TIME` kann mehrere Meldungsblöcke liefern. Auch `STATISTICS IO` kann mehrere Objektzeilen und mehrere Statements umfassen.

Der Generator braucht deshalb:

```text
StatementOrdinal
MessageOrdinal
ObjectOrdinal
```

Bei einem Plan mit einem Statement kann automatisch zugeordnet werden.

Bei mehreren Statements gilt:

1. explizite `@StatementOrdinal`,
2. statementbezogene Kennzeichnung im strukturierten JSON,
3. ableitbare Reihenfolge,
4. andernfalls nur planweite Zuordnung.

Ohne eindeutige Zuordnung:

```text
ParseStatus = AMBIGUOUS_STATEMENT_MAPPING
Confidence  = PLAN_LEVEL_ONLY
```

Die Werte bleiben sichtbar, erzeugen aber keine hoch belastbaren operatorbezogenen Findings.

---

# 6. Validierung eines bereits vorhandenen JSON

Die Procedure sollte nicht nur neue Evidenz erzeugen, sondern auch bestehendes JSON normalisieren:

```sql
EXEC [monitor].[USP_CreateExecutionEvidenceJson]
      @ExistingEvidenceJson = @ImportedJson,
      @StrictValidation = 1,
      @Json = @NormalizedJson OUTPUT;
```

Prüfungen:

* gültiges JSON,
* unterstützte Schemaversion,
* erlaubte Property-Typen,
* keine negativen IO-Werte,
* keine widersprüchlichen Statementzuordnungen,
* CPU und Elapsed plausibel,
* Hashformat korrekt,
* Versionsfelder plausibel,
* unbekannte Properties tolerieren oder melden.

Bei `@StrictValidation = 0`:

```text
Status = PARSED_PARTIAL
```

Bei `@StrictValidation = 1`:

```text
Status = INVALID_EVIDENCE_JSON
```

---

# 7. Aktive Erfassung: eigener Client-Collector

Zusätzlich sollte später ein kleines Capture-Tool existieren, beispielsweise:

```text
Tools/Collect-ExecutionEvidence.ps1
```

oder eine kleine .NET-CLI:

```text
SqlServerAnalyze.ExecutionEvidenceCollector
```

Das wäre ein **eigenes beziehungsweise Drittanbieter-Clienttool**, kein SQL-Server-Systemobjekt.

Der Collector kann die gewünschte Query explizit mit:

```sql
SET STATISTICS XML ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
```

ausführen.

`SET STATISTICS XML` führt das Statement aus und gibt anschließend ein XML-Dokument mit den tatsächlichen Ausführungsinformationen zurück. ([Microsoft Learn][4])

`STATISTICS IO` und `STATISTICS TIME` werden dagegen als Meldungsausgabe erzeugt. Ein `Microsoft.Data.SqlClient`-Client kann Serverhinweise und Informationsmeldungen über das `SqlConnection.InfoMessage`-Event abfangen. ([Microsoft Learn][5])

Der Collector würde gemeinsam erfassen:

```text
Actual Plan XML
STATISTICS IO
STATISTICS TIME
Serverversion
Compatibility Level
Zeitpunkt
Statementreihenfolge
Query Hash
Query Plan Hash
```

und anschließend exakt zwei Ergebnisse liefern:

```text
PlanXml
EvidenceJson
```

Diese stammen dann garantiert aus derselben Verbindung und – soweit das Statementmapping eindeutig ist – aus derselben Ausführung.

---

# 8. Kein allgemeines `@SqlText` in der SQL-Procedure

Ich würde nicht vorsehen:

```sql
EXEC [monitor].[USP_CreateExecutionEvidenceJson]
    @SqlText = N'beliebiges SQL';
```

und dieses SQL innerhalb der Procedure ausführen.

Gründe:

* DML und DDL wären möglich,
* unbekannte Seiteneffekte,
* Locking und Blocking,
* schwer kontrollierbare Laufzeit,
* unbekannte Resultsets,
* Informationsmeldungen sind nicht als normale relationale Ergebnisse verfügbar,
* Sicherheits- und Berechtigungsprobleme.

Die SQL-Procedure ist daher ausschließlich:

```text
Parser
Validator
Normalizer
JSON Builder
```

Die aktive Ausführung bleibt eine ausdrücklich gestartete Clientfunktion.

---

# 9. Empfohlene Resultsets des Generators

## CONSOLE

Eine kompakte Zusammenfassung:

```text
Status
SchemaVersion
StatementCount
StatisticsIoRowCount
StatisticsTimeBlockCount
SameExecutionConfidence
WarningCount
```

## RAW/TABLE

```text
captureStatus
statisticsIo
statisticsTime
parseWarnings
```

## OUTPUT

```sql
@Json nvarchar(max) OUTPUT
```

Die vorhandene Repositoryarchitektur unterstützt bereits strukturierte Findings mit `Severity`, `Confidence`, `MetricValue` und `ThresholdValue`; dieses Muster sollte für Parse- und Evidenzstatus wiederverwendet werden.

---

# 10. Empfohlener Ablauf

## Manuelle Verwendung

```sql
DECLARE @EvidenceJson nvarchar(max);

EXEC [monitor].[USP_CreateExecutionEvidenceJson]
      @PlanXml = @PlanXml,
      @StatisticsIoText = @StatisticsIo,
      @StatisticsTimeText = @StatisticsTime,
      @StatisticsLanguage = 'DE',
      @StatementOrdinal = 1,
      @SameExecutionAsPlanConfirmed = 1,
      @Json = @EvidenceJson OUTPUT;

EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml = @PlanXml,
      @EvidenzJson = @EvidenceJson;
```

## Automatisierte Verwendung

```text
Client Collector
    ↓
PlanXml + Statistics Messages
    ↓
USP_CreateExecutionEvidenceJson
    ↓
USP_ExecutionPlanAnalysis
```

## Entscheidung

Es sollte somit nicht nur „eine Funktion“ geben, sondern drei klar getrennte Bausteine:

```text
TVF_ParseStatisticsIoText
TVF_ParseStatisticsTimeText
USP_CreateExecutionEvidenceJson
```

Zusätzlich optional:

```text
clientseitiger ExecutionEvidenceCollector
```

Die **SQL-Procedure ist der kanonische JSON-Erzeuger**. Die TVFs sind reine, testbare Parser. Der spätere Client-Collector ist der einzige Baustein, der Plan, IO und TIME aktiv aus derselben Ausführung erfassen sollte.

[1]: https://learn.microsoft.com/en-us/sql/relational-databases/user-defined-functions/user-defined-functions?view=sql-server-ver17 "https://learn.microsoft.com/en-us/sql/relational-databases/user-defined-functions/user-defined-functions?view=sql-server-ver17"
[2]: https://learn.microsoft.com/ga-ie/SQL/t-sql/statements/set-statistics-io-transact-sql?view=sql-server-ver16 "https://learn.microsoft.com/ga-ie/SQL/t-sql/statements/set-statistics-io-transact-sql?view=sql-server-ver16"
[3]: https://learn.microsoft.com/de-de/sql/t-sql/statements/set-statistics-time-transact-sql?view=sql-server-ver17 "https://learn.microsoft.com/de-de/sql/t-sql/statements/set-statistics-time-transact-sql?view=sql-server-ver17"
[4]: https://learn.microsoft.com/da-dk/SQL/t-SQL/statements/set-statistics-xml-transact-sql?view=sql-server-ver15&utm_source=chatgpt.com "SET STATISTICS XML (Transact-SQL) - SQL Server | Microsoft Learn"
[5]: https://learn.microsoft.com/en-us/dotnet/api/microsoft.data.sqlclient.sqlconnection.infomessage?view=sqlclient-dotnet-core-6.1 "https://learn.microsoft.com/en-us/dotnet/api/microsoft.data.sqlclient.sqlconnection.infomessage?view=sqlclient-dotnet-core-6.1"





Plan neu erzeugt, da vorher abgebrochen.



# Vollständiger Umsetzungsplan: eigenständige Execution-Plan-Analyse

## 1. Zielbild

Die neue Lösung soll zwei Einsatzarten gleichwertig unterstützen:

### Standalone

Ein bereits vorhandener Ausführungsplan wird direkt übergeben:

```sql
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml = @PlanXml,
      @EvidenzJson = @EvidenzJson;
```

Dieser Pfad darf standardmäßig:

* keinen Plan Cache durchsuchen,
* keinen Query Store lesen,
* keine Benutzertabelle abfragen,
* keine Query erneut ausführen,
* keine Abhängigkeit vom Server besitzen, auf dem die Analyse läuft.

Damit kann beispielsweise ein Plan aus einer anderen SQL-Server-Instanz analysiert werden.

### Frameworkintegriert

Vorhandene Module beschaffen die Pläne aus:

* Plan Cache,
* Last Known Actual Plan,
* laufender Session,
* Query Store,

und verwenden anschließend dieselbe zentrale Analyse-Engine.

Die vorhandene `USP_ShowplanAnalysis` bleibt dabei das Modul für die Auswahl und Verarbeitung mehrerer Pläne. Sie soll die eigentliche Planinterpretation nicht mehr selbst duplizieren.

---

# 2. Vorgeschlagene Architektur

Die Lösung besteht aus fünf Ebenen.

```text
Planbeschaffung
    ↓
Plan- und Evidenznormalisierung
    ↓
technisches Planmodell
    ↓
Kennzahlen und Regeln
    ↓
Findings und Folgeanalysen
```

## 2.1 Neue und bestehende Objekte

### Neue öffentliche Objekte

```text
monitor.USP_ExecutionPlanAnalysis
monitor.USP_CreateExecutionEvidenceJson
monitor.TVF_ParseStatisticsIoText
monitor.TVF_ParseStatisticsTimeText
```

### Neues internes Objekt

```text
monitor.USP_InternalAnalyzeExecutionPlan
```

### Neue Steuertabellen

```text
monitor.PlanAnalysisProfile
monitor.PlanAnalysisRuleThreshold
monitor.PlanAnalysisProfileAssignment
```

### Zu ändernde bestehende Objekte

```text
monitor.USP_ShowplanAnalysis
```

Später bedingt:

```text
monitor.USP_PlanCacheAnalysis
monitor.USP_PlanDetails
monitor.USP_QueryStats
monitor.USP_IntelligentQueryProcessingAnalysis
```

---

# 3. Zuständigkeit der Objekte

## 3.1 `monitor.USP_ExecutionPlanAnalysis`

Öffentliche Standalone-Procedure für genau **ein Plan-XML-Dokument**.

Sie übernimmt:

* Planquelle validieren,
* Plan-XML normalisieren,
* Capability-Status bestimmen,
* optionale Evidenz validieren,
* Statement- und Operatormodell aufbauen,
* Kennzahlen berechnen,
* Regelwerk anwenden,
* Resultsets und JSON ausgeben.

Sie führt keine übergebene Query aus.

---

## 3.2 `monitor.USP_InternalAnalyzeExecutionPlan`

Interne Analyse-Engine.

Sie erhält:

* ein Plan-XML,
* optional ein Evidenz-JSON,
* einen bereits bestimmten Workloadkontext,
* vorbereitete lokale Temp-Tabellen.

Sie schreibt ausschließlich in die vom aufrufenden Objekt bereitgestellten Temp-Tabellen.

Damit können sowohl

```text
USP_ExecutionPlanAnalysis
```

als auch

```text
USP_ShowplanAnalysis
```

dieselbe Analyse-Engine verwenden.

Das verhindert:

* unterschiedliche Regeln je Aufrufspfad,
* doppelte XML-Parser,
* unterschiedliche Versionslogik,
* abweichende Findingcodes.

---

## 3.3 `monitor.USP_ShowplanAnalysis`

Bestehender Multi-Plan-Wrapper.

Künftige Aufgaben:

1. Kandidaten aus dem Plan Cache auswählen.
2. Kandidaten statementbezogen identifizieren.
3. eindeutige Planhandles bestimmen.
4. jeden Plan nur einmal laden.
5. je Plan `USP_InternalAnalyzeExecutionPlan` aufrufen.
6. Ergebnisse mit Kandidaten- und Statementidentität verbinden.

Der bestehende Code selektiert zwar statementbezogene Zeilen aus `sys.dm_exec_query_stats`, verarbeitet später aber planhandlebezogen den gesamten Batchplan. Diese Zuordnung muss im ersten Umsetzungsschritt korrigiert werden.

---

## 3.4 `monitor.USP_CreateExecutionEvidenceJson`

Öffentlicher, kanonischer Erzeuger für `@EvidenzJson`.

Aufgaben:

* `STATISTICS IO` parsen,
* `STATISTICS TIME` parsen,
* bereits strukturiertes Evidenz-JSON validieren,
* Plan- und Statementbezug ergänzen,
* Herkunft und Confidence dokumentieren,
* ein versioniertes normalisiertes JSON erzeugen.

Die Procedure misst nichts selbst und führt kein SQL aus.

---

## 3.5 Parserfunktionen

### `monitor.TVF_ParseStatisticsIoText`

Reiner Parser für bereits vorliegenden Meldungstext.

Ergebnisgranularität:

```text
StatementOrdinal
MessageOrdinal
ObjectOrdinal
ObjectDisplayName
ScanCount
LogicalReads
PhysicalReads
ReadAheadReads
PageServerReads
PageServerReadAheadReads
LobLogicalReads
LobPhysicalReads
LobReadAheadReads
LobPageServerReads
LobPageServerReadAheadReads
ParseStatus
```

`SET STATISTICS IO` liefert objektbezogen unter anderem Scan Count, Logical Reads, Physical Reads, Read-Ahead Reads und LOB-Werte. Page-Server-Werte sind insbesondere für Azure SQL Hyperscale vorgesehen. ([Microsoft Learn][1])

### `monitor.TVF_ParseStatisticsTimeText`

Ergebnisgranularität:

```text
StatementOrdinal
MessageOrdinal
TimeCategory
CpuMs
ElapsedMs
ParseStatus
```

`TimeCategory`:

```text
PARSE_COMPILE
EXECUTION
UNKNOWN
```

`SET STATISTICS TIME` meldet Parse-/Compile- sowie Ausführungszeiten in CPU- und Elapsed-Millisekunden. ([Microsoft Learn][2])

---

# 4. Öffentliche Signatur der Standalone-Analyse

## 4.1 Vorgeschlagene Signatur

```sql
CREATE OR ALTER PROCEDURE [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml                       xml             = NULL

      -- Alternative Planquellen
    , @PlanHandle                    varbinary(64)   = NULL
    , @SessionId                     smallint       = NULL
    , @RequestId                     int            = NULL
    , @QueryStoreDatabaseName        sysname         = NULL
    , @QueryStorePlanId              bigint          = NULL
    , @PlanQuelle                    varchar(24)      = 'AUTO'

      -- optionale Statementeinschränkung
    , @StatementId                   int             = NULL
    , @StatementQueryHash            binary(8)       = NULL

      -- zusätzliche Laufzeitevidenz
    , @EvidenzJson                   nvarchar(max)   = NULL

      -- Bewertungssteuerung
    , @AnalyseTiefe                  varchar(16)      = 'STANDARD'
    , @WorkloadProfil                varchar(32)      = 'AUTO'
    , @Regelsatz                     varchar(32)      = 'DEFAULT'
    , @MinSchweregrad                varchar(16)      = 'INFO'

      -- optionale servergebundene Anreicherung
    , @MitAktuellenMetadaten         bit             = 0
    , @MitAktuellenStatistiken       bit             = 0
    , @MitQueryStoreKontext          bit             = 0
    , @MitThreadRuntime              bit             = 0
    , @MitAusdrucksdetails           bit             = 1

      -- Last- und Ergebnisschutz
    , @MaxOperatoren                 int             = 50000
    , @MaxFindings                   int             = 5000
    , @MaxDurationSeconds            int             = 30
    , @LockTimeoutMs                 int             = 0
    , @HighImpactConfirmed           bit             = 0

      -- Frameworkausgabe
    , @ResultSetArt                  varchar(16)      = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @JsonErzeugen                  bit             = 0
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0

      -- Statusvertrag
    , @StatusCodeOut                 varchar(40)     = NULL OUTPUT
    , @IsPartialOut                  bit             = NULL OUTPUT
    , @ErrorNumberOut                int             = NULL OUTPUT
    , @ErrorMessageOut               nvarchar(2048)  = NULL OUTPUT;
```

---

# 5. Planquellen

Es darf pro Aufruf genau eine Planquellengruppe aktiv sein.

## 5.1 Direktes XML

```sql
@PlanXml = @Plan
```

Das ist der eigentliche Standalone-Modus.

Standardmäßig werden keinerlei zusätzliche Serverquellen gelesen.

## 5.2 Planhandle

```sql
@PlanHandle = 0x...,
@PlanQuelle = 'AUTO'
```

Mögliche Werte:

```text
AUTO
COMPILE
LAST_ACTUAL
```

`sys.dm_exec_query_plan_stats` ist ab SQL Server 2019 verfügbar und liefert das Äquivalent des letzten bekannten tatsächlichen Plans eines gecachten Plans, sofern die Erfassung verfügbar ist. ([Microsoft Learn][3])

`AUTO` bedeutet:

1. Last Actual versuchen,
2. bei Nichtverfügbarkeit auf Compile Plan zurückfallen,
3. den tatsächlichen Fallback im Resultset ausweisen.

## 5.3 Laufende Session

```sql
@SessionId = 57,
@RequestId = 0
```

Die Planquelle lautet dann:

```text
CURRENT_ACTUAL
```

Der Plan ist möglicherweise partiell, weil die Ausführung noch nicht abgeschlossen ist.

## 5.4 Query Store

```sql
@QueryStoreDatabaseName = N'ExampleDatabase',
@QueryStorePlanId = 123
```

Query-Store-Pläne sind grundsätzlich Compile-/Estimated-Pläne. Runtimewerte müssen separat aus Query Store oder Evidenz stammen.

---

# 6. Signatur von `USP_CreateExecutionEvidenceJson`

```sql
CREATE OR ALTER PROCEDURE [monitor].[USP_CreateExecutionEvidenceJson]
      @PlanXml                       xml             = NULL
    , @StatisticsIoText              nvarchar(max)   = NULL
    , @StatisticsTimeText            nvarchar(max)   = NULL
    , @StatisticsLanguage            varchar(16)     = 'AUTO'

    , @StatementId                   int             = NULL
    , @StatementOrdinal              int             = NULL
    , @SameExecutionAsPlanConfirmed  bit             = NULL
    , @CapturedAtUtc                 datetime2(3)    = NULL

    , @SourceProductVersion          nvarchar(128)   = NULL
    , @SourceCompatibilityLevel      smallint        = NULL
    , @SourceEngineEdition           int             = NULL

    , @AdditionalEvidenceJson        nvarchar(max)   = NULL
    , @ExistingEvidenceJson          nvarchar(max)   = NULL

    , @RawTextHandling               varchar(16)     = 'HASH_ONLY'
    , @StrictValidation              bit             = 1

    , @ResultSetArt                  varchar(16)     = 'CONSOLE'
    , @ResultTablesJson              nvarchar(max)   = NULL
    , @Json                          nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                bit             = 1
    , @Hilfe                         bit             = 0

    , @StatusCodeOut                 varchar(40)     = NULL OUTPUT
    , @IsPartialOut                  bit             = NULL OUTPUT
    , @ErrorNumberOut                int             = NULL OUTPUT
    , @ErrorMessageOut               nvarchar(2048)  = NULL OUTPUT;
```

## 6.1 `@RawTextHandling`

```text
NONE
HASH_ONLY
INCLUDE
```

Default:

```text
HASH_ONLY
```

Dann werden Rohtexte nicht im JSON dupliziert, sondern nur Länge und Hash gespeichert.

## 6.2 `@StrictValidation`

### `1`

Strukturell oder semantisch ungültige Evidenz wird mit

```text
INVALID_EVIDENCE
```

abgelehnt.

### `0`

Verwertbare Teile werden übernommen:

```text
PARSED_PARTIAL
```

---

# 7. Evidenz-JSON

## 7.1 Zielstruktur

```json
{
  "schemaVersion": 1,
  "generator": {
    "name": "USP_CreateExecutionEvidenceJson",
    "version": "1.0.0"
  },
  "capture": {
    "capturedAtUtc": "2026-01-01T00:00:00.000Z",
    "sameExecutionAsPlan": true,
    "sameExecutionConfidence": "CONFIRMED",
    "statementOrdinal": 1,
    "statisticsLanguage": "de-DE"
  },
  "sourceEnvironment": {
    "productVersion": "17.x",
    "compatibilityLevel": 170,
    "engineEdition": 3
  },
  "planIdentity": {
    "planDocumentHash": "SHA2_256:...",
    "statementId": 1,
    "queryHash": "0x...",
    "queryPlanHash": "0x..."
  },
  "statisticsIo": [],
  "statisticsTime": [],
  "additionalEvidence": {},
  "parseStatus": [],
  "warnings": [],
  "rawInput": {
    "statisticsIoCharacters": 0,
    "statisticsIoHash": "SHA2_256:...",
    "statisticsTimeCharacters": 0,
    "statisticsTimeHash": "SHA2_256:..."
  }
}
```

## 7.2 Same-Execution-Confidence

```text
CONFIRMED
PLAN_AND_MESSAGES_CAPTURED_TOGETHER
QUERY_AND_PLAN_IDENTITY_MATCH
STATEMENT_MAPPING_INFERRED
PLAN_LEVEL_ONLY
UNCONFIRMED
```

Eine direkte operatorbezogene Korrelation darf nur bei ausreichender Confidence erfolgen.

---

# 8. Verarbeitungsphasen

## Phase 0 – Preflight

Vor jedem teuren Zugriff:

* Parameter normalisieren,
* Ausgabeart validieren,
* Planquellenkonflikte erkennen,
* JSON-Struktur validieren,
* Limits prüfen,
* High-Impact-Pfade bestimmen,
* Zieltabelle für TABLE vorab prüfen.

## Phase 1 – Planbeschaffung

Ergebnis:

```text
PlanDocumentId
PlanSource
PlanXml
IsPlanComplete
PlanAcquisitionStatus
```

Ein Planhandle wird nur einmal geladen.

## Phase 2 – Planidentität und Herkunft

Extraktion:

```text
PlanDocumentHash
ShowplanVersion
ShowplanBuild
PlanSource
RuntimeCounterScope
SourceProductVersion
CompatibilityLevel
CardinalityEstimationModelVersion
```

`RuntimeCounterScope`:

```text
NONE
LAST_COMPLETED_EXECUTION
CURRENT_PARTIAL_EXECUTION
IMPORTED_ACTUAL
QUERY_STORE_AGGREGATE
UNKNOWN
```

## Phase 3 – Capability-Ermittlung

Für jede relevante Information:

```text
FeatureCode
IsAvailable
AvailabilityReason
EvidenceLevel
```

Beispiel:

```text
ACTUAL_ROWS_READ
ACTUAL_CPU
THREAD_RUNTIME
PSP_VARIANT
OPPO_VARIANT
QUERY_STORE_PLAN_FEEDBACK
```

Nicht verfügbare Informationen ergeben:

```text
NULL + Capability-Status
```

nicht:

```text
0
```

## Phase 4 – Statements

Interner Schlüssel:

```text
PlanDocumentId
StatementOrdinal
```

Zusätzliche Quellattribute:

```text
StatementId
StatementCompId
StatementType
StatementText
StatementQueryHash
StatementQueryPlanHash
StatementSubTreeCost
StatementEstimatedRows
OptimizationLevel
EarlyAbortReason
CompileTimeMs
CompileCpuMs
CompileMemoryKb
CardinalityEstimationModelVersion
RetrievedFromCache
NonParallelPlanReason
```

`StatementOrdinal` ist eine eigene deterministische Sequenz. Es darf nicht angenommen werden, dass `StatementId` allein in jedem importierten Plan als technischer Primärschlüssel genügt.

## Phase 5 – Operatorbaum

Schlüssel:

```text
PlanDocumentId
StatementOrdinal
NodeId
```

Extraktion:

```text
ParentNodeId
ChildOrdinal
Depth
OperatorPath
PhysicalOp
LogicalOp
EstimateRows
EstimatedRowsRead
EstimateExecutions
EstimateRebinds
EstimateRewinds
EstimateCpu
EstimateIo
AverageRowSize
EstimatedTotalSubtreeCost
Parallel
EstimatedExecutionMode
ActualExecutionMode
Ordered
ScanDirection
```

Die Hierarchie wird über eine Edge-Tabelle aufgebaut:

```text
ParentNodeId → ChildNodeId
```

und danach mittels rekursiver CTE um:

```text
Depth
OperatorPath
```

ergänzt.

## Phase 6 – Runtime Counters

Granularität:

```text
PlanDocumentId
StatementOrdinal
NodeId
ThreadId
BrickId
```

Zu erfassen:

```text
ActualRows
ActualRowsRead
ActualExecutions
ActualRebinds
ActualRewinds
ActualEndOfScans
ActualScans
ActualLogicalReads
ActualPhysicalReads
ActualReadAheads
ActualCpuMs
ActualElapsedMs
ActualLobLogicalReads
ActualLobPhysicalReads
```

Threadinformationen werden zunächst vollständig und paarweise erfasst. Aggregationen erfolgen erst danach.

---

# 9. Korrekte Behandlung von `ActualRowsRead`

`ActualRows` und `ActualRowsRead` müssen aus derselben Runtime-Counter-Zeile stammen.

## 9.1 Zusätzliche Abdeckungswerte

```text
RuntimeCounterCount
RowsReadCounterCount
RowsReadCounterCoveragePercent
PairedActualRows
PairedActualRowsRead
```

## 9.2 Neutrale Kennzahlen

```text
RowsReadNotReturned
RowsReadNotReturnedPercent
```

`ResidualDiscardPercent` wird nur dann verwendet, wenn im selben Access-Operator ein entsprechendes residuales Predicate nachgewiesen wurde.

## 9.3 Status

```text
AVAILABLE
NO_RUNTIME_INFORMATION
ACTUAL_ROWS_READ_NOT_AVAILABLE
NOT_APPLICABLE_OPERATOR
PARTIAL_COUNTER_COVERAGE
INCONSISTENT_COUNTERS
ZERO_ROWS_READ
```

## 9.4 Sichere Berechnung

```sql
CASE
    WHEN [PairedActualRowsRead] IS NULL
      OR [PairedActualRows] IS NULL
        THEN NULL

    WHEN [PairedActualRowsRead] <= 0
        THEN NULL

    WHEN [PairedActualRows] < 0
      OR [PairedActualRows] > [PairedActualRowsRead]
        THEN NULL

    ELSE
        CONVERT
        (
            decimal(19,6),
            CONVERT(decimal(38,12), 100)
            *
            (
                CONVERT(decimal(38,12), [PairedActualRowsRead])
                -
                CONVERT(decimal(38,12), [PairedActualRows])
            )
            /
            CONVERT(decimal(38,12), [PairedActualRowsRead])
        )
END
```

Die Konvertierung erfolgt vor der Subtraktion, damit auch ein möglicher vorgelagerter `bigint`-Overflow vermieden wird.

---

# 10. Cardinality-Kennzahlen

Pro Operator:

```text
EstimatedRowsPerExecution
EstimatedExecutions
EstimatedRowsTotal
ActualRowsPerExecution
ActualExecutions
ActualRowsTotal
AbsoluteRowDifference
ActualToEstimatedRatio
CardinalityLog10Error
EstimatedFlowBytes
ActualFlowBytes
```

## 10.1 Schätzfehler

Heuristische Logarithmuskennzahl:

```text
ABS(LOG10((ActualRowsTotal + 1) / (EstimatedRowsTotal + 1)))
```

Interpretation:

```text
>= 1  ungefähr mindestens eine Größenordnung
>= 2  ungefähr mindestens zwei Größenordnungen
>= 3  ungefähr mindestens drei Größenordnungen
```

Diese Kennzahl ist nur eine Priorisierung. Severity wird zusätzlich durch die absolute Arbeitsmenge bestimmt.

## 10.2 Rebinds und Rewinds

`ActualRebinds` und `ActualRewinds` müssen bei Operatoren mit mehrfacher Ausführung berücksichtigt werden. Microsoft dokumentiert, dass ihre Anwesenheit bestimmt, wie Estimated und Actual Rows miteinander zu vergleichen sind. ([Microsoft Learn][4])

---

# 11. Workloadprofile und Schwellenwerte

## 11.1 Profile

```text
LATENCY_SENSITIVE
BALANCED
THROUGHPUT
MAINTENANCE
UNKNOWN
```

### `LATENCY_SENSITIVE`

Schwerpunkt:

* CPU je Ausführung,
* Logical Reads je Ausführung,
* Dauer je Ausführung,
* hohe Ausführungshäufigkeit,
* kleine, aber wiederholte Verschwendung.

### `THROUGHPUT`

Schwerpunkt:

* Gesamtdatenmenge,
* TempDB,
* Spills,
* DOP,
* Memory Grant,
* CPU- und IO-Gesamtlast.

### `MAINTENANCE`

Große Scans, Sorts und Writes können erwartbar sein. Findings werden nicht unterdrückt, aber anders gewichtet.

## 11.2 Profilermittlung

Priorität:

1. explizites `@WorkloadProfil`,
2. Query-Store-Query-ID-Zuordnung,
3. Database + Query Hash,
4. Objekt + Statement,
5. Resource Pool/Workload Group,
6. Datenbankzuordnung,
7. automatische Klassifikation,
8. `BALANCED`.

Zusätzlich:

```text
ProfileResolutionSource
ProfileResolutionConfidence
```

---

# 12. Steuertabellen

## 12.1 `monitor.PlanAnalysisProfile`

Wesentliche Spalten:

```text
ProfileCode
Description
Priority
IsEnabled
IsFrameworkDefault
```

## 12.2 `monitor.PlanAnalysisRuleThreshold`

Wesentliche Spalten:

```text
RuleCode
ProfileCode
Severity
IsEnabled

MinRatio
MinRows
MinRowsRead
MinRowsNotReturned
MinLogicalReadsPerExecution
MinTotalLogicalReads
MinExecutionCount
MinElapsedMs
MinCpuMs
MinSpilledPages
MinMemoryKb

MinServerMajorVersion
MinCompatibilityLevel
RequiredEvidenceLevel
AdditionalConfigurationJson
```

Die Tabelle enthält nur Schwellenwerte. Sie enthält keine ausführbaren SQL-Ausdrücke.

## 12.3 `monitor.PlanAnalysisProfileAssignment`

Mögliche Zuordnungsfelder:

```text
AssignmentId
Priority
IsEnabled
ProfileCode

DatabaseNamePattern
SchemaNamePattern
ObjectNamePattern
QueryHash
QueryStoreQueryId
StatementId
ProgramNameLikePattern
ResourcePoolId
WorkloadGroupId
```

Repository-Seeds enthalten nur generische Frameworkprofile. Reale lokale Zuordnungen werden nicht ins Repository übernommen.

---

# 13. Findingmodell

Das derzeitige TABLE-Schema von `USP_ShowplanAnalysis` enthält nur Findingtyp, Severity, Node und Detail.

Das neue Modell:

```text
FindingOrdinal
FindingCode
Category

Severity
Confidence
EvidenceLevel

PlanDocumentId
StatementOrdinal
StatementId
NodeId

PhysicalOp
LogicalOp

MetricName
MetricValue
MetricUnit
ThresholdValue
ThresholdSource
WorkloadProfile

Summary
Evidence
EvidenceLimit
CounterEvidence
RecommendedNextCheck
```

## 13.1 Severity

```text
INFO
LOW
MEDIUM
HIGH
CRITICAL
```

## 13.2 Confidence

```text
EXPLICIT_RUNTIME_WARNING
RUNTIME_MEASURED
RUNTIME_CORRELATED
RUNTIME_INFERRED
COMPILE_WARNING
COMPILE_HEURISTIC
HISTORICAL_CORRELATION
```

Das Repository verwendet bei der Statistikverteilungsanalyse bereits eine vergleichbare Trennung aus Severity, Confidence, Metric und Threshold. Dieses Muster sollte weiterverwendet werden.

---

# 14. Regelgruppen

## 14.1 Cardinality

```text
CARDINALITY_UNDERESTIMATE
CARDINALITY_OVERESTIMATE
CARDINALITY_ERROR_HIGH_IMPACT
ZERO_ESTIMATE_WITH_ACTUAL_ROWS
ESTIMATE_ERROR_PROPAGATION
```

## 14.2 Access und Datenmengen

```text
ROWS_READ_NOT_RETURNED
RESIDUAL_PREDICATE_HIGH_DISCARD
SEEK_WITH_HIGH_RESIDUAL_WORK
SCAN_WITH_LOW_RETURN_RATE
LARGE_SCAN_HIGH_WORK
```

## 14.3 Nested Loops und Lookups

```text
LOOKUP_PRESENT
LOOKUP_HIGH_EXECUTION_COUNT
LOOKUP_HIGH_READ_VOLUME
NESTED_LOOPS_INNER_WORK_AMPLIFICATION
NESTED_LOOPS_SCAN_AMPLIFICATION
```

Ein Lookup für wenige Zeilen bleibt maximal `INFO`.

## 14.4 Sort, Hash und Spills

```text
SORT_SPILL
HASH_SPILL
HASH_RECURSION
HASH_BAILOUT
EXCHANGE_SPILL
LARGE_BLOCKING_SORT
SORT_HIGH_ROW_WIDTH
```

## 14.5 Memory Grant

```text
MEMORY_GRANT_OVER
MEMORY_GRANT_WAIT
MEMORY_GRANT_UNDER_WITH_SPILL
MEMORY_GRANT_FEEDBACK_ACTIVE
MEMORY_GRANT_FEEDBACK_DISABLED
```

`MaxUsedMemory = GrantedMemory` allein ist kein Undergrant-Beweis.

## 14.6 Parallelismus

```text
PARALLEL_THREAD_SKEW
PARALLEL_ZERO_WORKERS
SERIAL_PLAN_HIGH_WORK
FORCED_SERIALIZATION
INEFFECTIVE_PARALLELISM_REVIEW
```

Kennzahlen:

```text
ActiveThreadCount
ZeroRowThreadCount
MaxRowsPerThread
AverageRowsPerThread
MedianRowsPerThread
MaxToAverageRowsRatio
CoefficientOfVariation
```

## 14.7 Row Goals

```text
ROW_GOAL_PRESENT
ROW_GOAL_LARGE_ACTUAL_ROWS
ROW_GOAL_NESTED_LOOPS_AMPLIFICATION
ROW_GOAL_SCAN_REPEATED
```

## 14.8 Spools und Merge

```text
EAGER_INDEX_SPOOL_HIGH_WORK
LARGE_TABLE_SPOOL
SPOOL_REBUILT_REPEATEDLY
SPOOL_NOT_EFFECTIVELY_REUSED
MANY_TO_MANY_MERGE_HIGH_REWINDS
```

## 14.9 Conversions und SARGability

```text
PLAN_AFFECTING_CONVERT
SEEK_BLOCKING_IMPLICIT_CONVERT
CARDINALITY_AFFECTING_CONVERT
NON_SARGABLE_PREDICATE_REVIEW
```

Eine Conversion in einer reinen Ausgabeexpression erzeugt kein relevantes Finding.

## 14.10 Compile und Optimizer

```text
OPTIMIZER_TIMEOUT
OPTIMIZER_MEMORY_LIMIT
HIGH_COMPILE_CPU
HIGH_COMPILE_MEMORY
FREQUENT_HIGH_COST_RECOMPILE
TRIVIAL_PLAN_CONTEXT
```

---

# 15. Indexreihenfolge und Zugriffseignung

Die Bewertung soll zwei unterschiedliche Fragestellungen trennen.

## 15.1 Eignung für Seek-Prädikate

Zu extrahieren:

```text
IndexKeyOrdinal
IndexKeyColumn
SeekPredicateColumn
PredicateKind
EqualityPrefixLength
FirstRangeKeyOrdinal
FirstUnconstrainedKeyOrdinal
ResidualPredicateColumn
```

Findings:

```text
INDEX_LEADING_KEY_NOT_CONSTRAINED
INDEX_KEY_ORDER_LIMITS_SEEK
LATER_KEY_USED_AS_RESIDUAL
RANGE_KEY_PREVENTS_DEEPER_SEEK
```

Nicht zulässig ist eine pauschale Aussage wie:

```text
Der Index ist falsch aufgebaut.
```

Das Finding lautet stattdessen:

```text
Die aktuelle Schlüsselreihenfolge ermöglicht für diesen konkreten
Zugriff keine vollständige Navigation über alle relevanten Prädikate.
```

## 15.2 Eignung für benötigte Sortierreihenfolge

Zu vergleichen:

```text
RequiredOrderColumns
RequiredOrderDirections
IndexKeyColumns
IndexKeyDirections
EqualityConstrainedPrefix
ScanDirection
Ordered
```

SQL Server kann einen Index auch rückwärts lesen; vollständig umgekehrte Richtungen können dadurch weiterhin erfüllt werden. Die Schlüsselrichtung ist insbesondere bei gemischten ASC-/DESC-Anforderungen relevant. ([Microsoft Learn][4])

Findings:

```text
INDEX_ORDER_DOES_NOT_SATISFY_REQUIRED_ORDER
INDEX_ORDER_SUPPORTS_PARTIAL_REQUIRED_ORDER
EXPENSIVE_SORT_POTENTIALLY_AVOIDABLE
INDEX_BACKWARD_SCAN
ORDER_PRESERVATION_LOST_BY_EXCHANGE
```

`INDEX_BACKWARD_SCAN` ist standardmäßig nur `INFO`.

Ein Indexvorschlag entsteht nur, wenn zusätzlich relevante Wirkung vorliegt:

* hohe Sortmenge,
* Spill,
* hohe CPU,
* hohe Ausführungshäufigkeit,
* hohe kumulative Last.

---

# 16. Statistics Usage

## 16.1 Im Plan gespeicherter Compilezustand

```text
StatisticsName
LastUpdateAtCompile
ModificationCountAtCompile
SamplingPercentAtCompile
```

## 16.2 Optionale aktuelle Anreicherung

Nur mit:

```sql
@MitAktuellenStatistiken = 1
```

Dann zusätzlich:

```text
CurrentLastUpdate
CurrentRows
CurrentRowsSampled
CurrentModificationCount
CurrentSamplePercent
StatsChangedSinceCompile
```

Die aktuelle Statistik darf nur gegen das Objekt auf dem analysierten Quellserver verglichen werden. Bei einem importierten Plan aus einer anderen Umgebung ist der Vergleich standardmäßig unzulässig.

## 16.3 Histogrammanalyse

Nicht standardmäßig.

Nur gezielt über das bereits vorhandene:

```text
USP_StatisticsDistributionAnalysis
```

Die vorhandene Procedure besitzt bereits separate konfigurierbare Schwellenwerte und weist ausdrücklich darauf hin, dass Verteilungsindikatoren ohne Query- und Runtimekontext keinen Planfehler beweisen.

---

# 17. Parameter Sensitivity, PSP und OPPO

## SQL Server 2019

Mögliche Evidenz:

* Compiled versus Runtime Parameter,
* Min-/Max-Zeilen aus Query Stats,
* mehrere Query Plan Hashes,
* Deferred Table Variable Compilation,
* Row Mode Memory Grant Feedback,
* Scalar UDF Inlining.

## SQL Server 2022

Zusätzlich:

* PSP Dispatcher,
* Query Variants,
* Query Store Plan Feedback,
* persistiertes Memory Grant Feedback,
* CE Feedback,
* DOP Feedback.

PSP benötigt SQL Server 2022 oder höher sowie Compatibility Level 160. ([Microsoft Learn][5])

`sys.query_store_plan_feedback` ist ab SQL Server 2022 verfügbar und enthält unter anderem CE-, Memory-Grant-, DOP- und LAQ-Feedback; Memory-Grant-Feedback kann dort sogar operatorbezogene Node-Informationen enthalten. ([Microsoft Learn][6])

## SQL Server 2025

Zusätzlich:

* OPPO Dispatcher,
* OPPO Query Variants,
* CE Feedback for Expressions,
* `OPTIMIZED_SP_EXECUTESQL` als möglicher Compilekontext.

OPPO gilt für SQL Server 2025 und benötigt Compatibility Level 170 sowie die datenbankbezogene Konfiguration `OPTIONAL_PARAMETER_OPTIMIZATION`. ([Microsoft Learn][7])

Das vorhandene `USP_IntelligentQueryProcessingAnalysis` prüft bereits PSP-/OPPO-Eignung und aggregierte Query-Variant-/Plan-Feedback-Evidenz. Diese Logik sollte nicht in der Plananalyse dupliziert, sondern gezielt erweitert oder korreliert werden.

---

# 18. Versionsadaptive Verarbeitung

## 18.1 Entscheidungsgrundlagen

Nicht ausschließlich:

```text
SERVERPROPERTY(ProductMajorVersion)
```

sondern gemeinsam:

```text
ServerMajorVersion
ServerProductVersion
ShowplanVersion
ShowplanBuild
CompatibilityLevel
CardinalityEstimationModelVersion
PlanSource
tatsächliche XML-Attributverfügbarkeit
```

## 18.2 Regeln

* XML-Attribute werden nach tatsächlichem Vorhandensein gelesen.
* Fehlende Attribute ergeben `NULL`.
* unbekannte zukünftige XML-Attribute werden ignoriert.
* unbekannte XML-Elemente dürfen den Parser nicht abbrechen.
* versionsabhängige DMV-/Katalogabfragen werden nur über passende Dynamic-SQL-Zweige kompiliert.
* ein Plan von SQL Server 2019 darf auf SQL Server 2025 analysiert werden, ohne dass SQL-2025-Informationen künstlich ergänzt werden.
* die aktuelle Serverversion darf nicht mit der Quellversion eines importierten Plans verwechselt werden.

## 18.3 Capability-Resultset

```text
FeatureCode
RequiredPlanType
MinimumServerMajorVersion
MinimumCompatibilityLevel
DetectedFrom
IsAvailable
AvailabilityReason
```

Beispiele:

```text
ACTUAL_ROWS
ACTUAL_ROWS_READ
THREAD_RUNTIME
MEMORY_GRANT_RUNTIME
SPILL_DETAILS
PSP_VARIANT
OPPO_VARIANT
QUERY_STORE_PLAN_FEEDBACK
STATISTICS_IO
STATISTICS_TIME
```

---

# 19. Einbindung von `STATISTICS IO` und `STATISTICS TIME`

## 19.1 Nutzen

Der Plan zeigt:

* Operatoren,
* Rows,
* Estimates,
* Spills,
* Memory,
* Parallelismus.

`STATISTICS IO` ergänzt:

* tatsächliche Seitenarbeit je Objekt,
* Worktable-/Workfile-Aktivität,
* LOB Reads,
* Read-Ahead,
* Scan Count.

`STATISTICS TIME` ergänzt:

* Parse-/Compile-CPU,
* Parse-/Compile-Dauer,
* Execution CPU,
* Execution Elapsed.

Diese Quellen sind besonders hilfreich, wenn Zeilenmengen und tatsächliche Seitenarbeit deutlich unterschiedliche Aussagen liefern. ([Microsoft Learn][1])

## 19.2 Korrelationseinschränkung

`STATISTICS IO` liefert objektbezogene Summen, keine verlässlichen operatorbezogenen Reads.

Eine direkte Zuordnung zu einem Operator darf nur erfolgen, wenn:

* genau ein passender Access-Operator existiert,
* Objekt- und Statementbezug eindeutig sind,
* dieselbe Ausführung bestätigt wurde.

Andernfalls bleibt die Evidenz auf:

```text
Statement + Objekt
```

bezogen.

## 19.3 Raw-Parser

Initiale Sprachunterstützung:

```text
DE
EN
AUTO
```

Weitere Sprachen können später ergänzt werden.

Parserstatus:

```text
PARSED
PARSED_PARTIAL
UNSUPPORTED_LANGUAGE
AMBIGUOUS_STATEMENT_MAPPING
UNRECOGNIZED_FORMAT
```

---

# 20. Resultsets

## CONSOLE

Genau ein menschenorientiertes Hauptresultset:

```text
findings
```

Das entspricht dem aktuellen Frameworkvertrag, nach dem CONSOLE im Normalfall genau ein fachliches Resultset liefert.

## RAW/TABLE/JSON

Vorgeschlagene benannte Resultsets:

```text
moduleStatus
capabilities
planDocuments
statements
operatorTree
operatorRuntime
operatorThreadRuntime
accessPaths
predicates
statisticsUsage
memoryAndSpills
parametersAndVariants
missingIndexes
executionEvidence
findings
```

## JSON-Hülle

```json
{
  "meta": {},
  "capabilities": [],
  "planDocuments": [],
  "statements": [],
  "operatorTree": [],
  "operatorRuntime": [],
  "operatorThreadRuntime": [],
  "accessPaths": [],
  "predicates": [],
  "statisticsUsage": [],
  "memoryAndSpills": [],
  "parametersAndVariants": [],
  "missingIndexes": [],
  "executionEvidence": {},
  "findings": [],
  "warnings": []
}
```

Jedes Resultset besitzt eine eigene `schemaVersion`.

---

# 21. Eigenlast und Performance

## Grundsätze

* Plan-XML nur einmal laden.
* Plan-XML je eindeutigem Plan nur einmal zerlegen.
* Statements einmal extrahieren.
* RelOps einmal extrahieren.
* Runtime Counter einmal extrahieren.
* Findings aus relationalen Stagingtabellen berechnen.
* keine wiederholten vollständigen `//*[local-name(.)=...]`-Scans pro Regel.
* Per-Thread-Daten nur bei `@MitThreadRuntime = 1` ausgeben.
* aktuelle Statistik-/Query-Store-Anreicherung standardmäßig deaktivieren.
* Time- und Row-Budget planweise prüfen.
* XML nach der Verarbeitung eines Plans freigeben.

Der bestehende Multi-Plan-Analyzer besitzt bereits Zeit- und Mengenschutz sowie planweise Fehlerisolation; diese Eigenschaften müssen erhalten bleiben.

---

# 22. Tests

## 22.1 Planstruktur

Synthetische Testpläne für:

* ein Statement,
* mehrere Statements im selben Batch,
* gleiche `NodeId` in unterschiedlichen Statements,
* verschachtelte Operatorbäume,
* unbekannte zusätzliche XML-Attribute,
* fehlende optionale XML-Elemente.

## 22.2 Estimated versus Actual

* Compile Plan ohne Runtime Counter,
* Last Actual Plan,
* partieller Live Plan,
* fehlendes `ActualRowsRead`,
* teilweise vorhandenes `ActualRowsRead`,
* inkonsistente Counter,
* `ActualRows = 0`,
* `ActualRowsRead = 0`,
* sehr große `bigint`-Werte.

## 22.3 Operatorregeln

* kleiner und großer Lookup,
* Scan mit hoher und niedriger Selektivität,
* Sort mit und ohne Spill,
* Hash Spill,
* Exchange Spill,
* Eager Spool,
* Many-to-Many Merge,
* Row Goal,
* Parallel Thread Skew.

## 22.4 Indexreihenfolge

* vollständiger Equality Prefix,
* führende Schlüsselspalte nicht eingeschränkt,
* Range auf mittlerer Schlüsselspalte,
* spätere Schlüssel nur residual,
* vollständig passender `ORDER BY`,
* rückwärts lesbarer Index,
* teilweise passende gemischte ASC-/DESC-Reihenfolge,
* zusätzlicher Sort trotz Index.

## 22.5 Evidenzparser

* deutsche `STATISTICS IO`,
* englische `STATISTICS IO`,
* Worktable und Workfile,
* LOB Reads,
* mehrere Statements,
* mehrere Objekte gleichen Namens,
* deutsche und englische `STATISTICS TIME`,
* mehrere Parse-/Compile-Blöcke,
* ungültige oder unvollständige Meldungen.

## 22.6 Versionsmatrix

GitHub Actions:

```text
SQL Server 2019
SQL Server 2022
SQL Server 2025
```

Abnahmekriterium:

```text
Nicht verfügbare Features liefern Capability-Status und NULL,
keinen Compile- oder Laufzeitfehler.
```

## 22.7 Ausgabevertrag

* CONSOLE genau ein fachliches Resultset,
* RAW vollständig typisiert,
* TABLE mit benannten Resultsets,
* JSON gültig und versioniert,
* `NONE` ohne Resultset,
* `@Json OUTPUT` unabhängig von CONSOLE.

---

# 23. Repository-Änderungen

## Neue SQL-Dateien

Vorgeschlagene Reihenfolge im Plan-Cache-Bereich:

```text
Code/04_PlanCache/041_TVF_ParseStatisticsIoText.sql
Code/04_PlanCache/042_TVF_ParseStatisticsTimeText.sql
Code/04_PlanCache/043_PlanAnalysisProfile.sql
Code/04_PlanCache/044_PlanAnalysisRuleThreshold.sql
Code/04_PlanCache/045_PlanAnalysisProfileAssignment.sql
Code/04_PlanCache/046_USP_CreateExecutionEvidenceJson.sql
Code/04_PlanCache/047_USP_InternalAnalyzeExecutionPlan.sql
Code/04_PlanCache/048_USP_ExecutionPlanAnalysis.sql
```

Bestehend zu ändern:

```text
Code/04_PlanCache/050_USP_ShowplanAnalysis.sql
Code/04_PlanCache/060_USP_PlanCacheAnalysis.sql
Code/Install/Install_All.sql
```

## Metadaten

```text
Metadata/Inventory/Objects.csv
Metadata/Inventory/Parameters.csv
Metadata/Inventory/ResultSets.csv
Metadata/Inventory/SystemSources.csv
```

## Tests

```text
Code/Tests/PlanCache/110_Test_und_Abnahme_Phase3.sql
Code/Tests/Integration/190_Execution_Plan_Analysis_Runtime_Contract.sql
Code/Tests/Integration/191_Execution_Evidence_Runtime_Contract.sql
Code/Tests/Run_Release_Gate.sql
```

## Dokumentation

```text
Documentation/Analysis_Guides/Procedures/USP_ExecutionPlanAnalysis.md
Documentation/Analysis_Guides/Procedures/USP_CreateExecutionEvidenceJson.md
Documentation/Analysis_Guides/Procedures/USP_ShowplanAnalysis.md
Documentation/Analysis_Guides/04_Plan_Cache.md
Documentation/Reference/Procedure_Reference.md
Documentation/Reference/Call_Catalog.md
Documentation/Quality/Test_Matrix.md
Documentation/Quality/Release_Notes.md
```

---

# 24. Umsetzungswellen

## Welle 0 – verbindlicher Vertrag

* Objektrollen festlegen.
* Parameter finalisieren.
* Resultsetnamen und Schemas definieren.
* Evidenz-JSON-Schema definieren.
* Findingcodes reservieren.
* Capabilitycodes definieren.
* Testfälle als leere Contracts anlegen.

**Ergebnis:** Architektur und Ausgabevertrag sind stabil, bevor produktiver Parsercode entsteht.

## Welle 1 – korrekter Standalone-Kern

* `USP_InternalAnalyzeExecutionPlan`
* `USP_ExecutionPlanAnalysis`
* direktes `@PlanXml`
* Statementidentität
* Operatorbaum
* Estimated Runtime Capability
* Actual Runtime Counter
* paarweise `ActualRows`/`ActualRowsRead`
* sichere Cardinality-Kennzahlen

**Abnahme:** Mehrstatementpläne werden ohne Statementvermischung verarbeitet.

## Welle 2 – Evidenzerzeugung

* `TVF_ParseStatisticsIoText`
* `TVF_ParseStatisticsTimeText`
* `USP_CreateExecutionEvidenceJson`
* DE-/EN-Parser
* Same-Execution-Status
* strukturierte Validierung
* Hash-only-Rohtextvertrag

**Abnahme:** Plananalyse funktioniert mit und ohne Evidenz identisch; Evidenz reichert nur an.

## Welle 3 – Findings und Workloadprofile

* Steuertabellen
* Profilauflösung
* Severity und Confidence
* Cardinality-, Rows-Read-, Lookup-, Scan-, Sort-, Spill- und Grantregeln
* per-execution und cumulative impact

**Abnahme:** OLTP- und Batchprofile liefern nachvollziehbar unterschiedliche Thresholds.

## Welle 4 – Index- und Predicate-Analyse

* Seek Predicates
* residuale Predicates
* Schlüsselpräfix
* Range-Position
* ASC/DESC
* Scan Direction
* Required Order
* Sortvermeidung
* Backward Scan

**Abnahme:** Das Framework meldet keine pauschal „falsch sortierten“ Indizes, sondern konkrete Zugriffseinschränkungen.

## Welle 5 – SQL-Versionen und IQP

* SQL-2019-Capabilities
* PSP für 2022+
* Plan Feedback für 2022+
* OPPO für 2025+
* unbekannte zukünftige XML-Elemente
* Query Store Context optional

**Abnahme:** Alle drei Zielversionen laufen ohne versionsbedingte Compilefehler.

## Welle 6 – Integration bestehender Module

* `USP_ShowplanAnalysis` auf internen Kern umstellen.
* Planhandles deduplizieren.
* Statementkandidaten korrekt verbinden.
* `USP_PlanCacheAnalysis` weiterleiten.
* Überschneidungen mit `USP_PlanDetails` reduzieren.

**Abnahme:** Standalone- und Plan-Cache-Pfad erzeugen für denselben Plan dieselben fachlichen Findings.

## Welle 7 – Dokumentation und Release Gate

* Anfänger- und Deep-Analysis-Dokumentation,
* synthetische Beispiele,
* Resultsetinventar,
* SQL-2019/2022/2025-Tests,
* Eigenlasttests,
* vollständiger Release-Gate-Lauf.

---

# 25. Hauptempfehlung

Die neue Analyse sollte aus drei klar getrennten Ebenen bestehen:

```text
1. Planmodell
   objektive Extraktion ohne Bewertung

2. Execution Evidence
   optionale Laufzeitevidenz aus Actual Plan,
   STATISTICS IO, STATISTICS TIME und Query Store

3. Bewertungsmodell
   versions-, evidenz- und workloadabhängige Regeln
```

`USP_ExecutionPlanAnalysis` ist der eigenständige öffentliche Einstieg.
`USP_CreateExecutionEvidenceJson` ist der standardisierte Evidenzerzeuger.
`USP_ShowplanAnalysis` bleibt der Multi-Plan- und Plan-Cache-Wrapper.

Diese Trennung ist entscheidend: Ein fehlendes oder falsch eingestuftes Finding darf nie dazu führen, dass die zugrunde liegenden Plan- und Runtimewerte verloren gehen.

[1]: https://learn.microsoft.com/de-de/sql/t-sql/statements/set-statistics-io-transact-sql?view=sql-server-ver17&utm_source=chatgpt.com "SET-STATISTIK IO (Transact-SQL) - SQL Server | Microsoft Learn"
[2]: https://learn.microsoft.com/de-de/sql/t-sql/statements/set-statistics-time-transact-sql?view=sql-server-ver17&utm_source=chatgpt.com "SET-STATISTIK-ZEIT (Transact-SQL) - SQL Server | Microsoft Learn"
[3]: https://learn.microsoft.com/de-at/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-query-plan-stats-transact-sql?view=sql-server-linux-ver17&utm_source=chatgpt.com "sys.dm_exec_query_plan_stats (Transact-SQL) - SQL Server | Microsoft Learn"
[4]: https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference?view=sql-server-2017&utm_source=chatgpt.com "Logical and Physical Showplan Operator Reference - SQL Server | Microsoft Learn"
[5]: https://learn.microsoft.com/en-us/sql/relational-databases/performance/parameter-sensitive-plan-optimization?view=sql-server-ver17&utm_source=chatgpt.com "Parameter Sensitive Plan Optimization - SQL Server | Microsoft Learn"
[6]: https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-plan-feedback?view=sql-server-ver17&utm_source=chatgpt.com "sys.query_store_plan_feedback (Transact-SQL) - SQL Server | Microsoft Learn"
[7]: https://learn.microsoft.com/de-de/sql/relational-databases/performance/optional-parameter-optimization?view=sql-server-ver17&utm_source=chatgpt.com "Optimierung optionaler Parameterpläne - SQL Server | Microsoft Learn"




sollte man dem EvidenzJson nicht auch Statistik Informationen zuführen können?
Und es wird sicherlich eine Funktion benötigt, welche die betroffenen Objekte aus dem PlanXML extrahiert, damit die Informationen zielgerichtet ermittelt werden können?



Ja. Das `@EvidenzJson` sollte auch **Statistik-Evidenz** aufnehmen können. Dabei müssen drei verschiedene Zeitstände sauber getrennt werden:

1. **Statistiken bei der Plankompilierung** – aus `OptimizerStatsUsage` im Plan.
2. **Aktueller Statistikzustand** – gezielt aus den Katalogen der Quellumgebung.
3. **Verteilungsinformationen** – optional aus Histogrammen beziehungsweise einer daraus abgeleiteten Zusammenfassung.

Und ja: Dafür wird eine zentrale Funktion benötigt, welche die im Plan referenzierten Objekte, Indizes, Statistiken und Spalten zunächst rein aus dem XML extrahiert.

# 1. Erweiterte Architektur

Ich würde den bisherigen Plan um folgende Bausteine ergänzen:

```text
monitor.TVF_ExecutionPlanObjectReferences
monitor.TVF_ExecutionPlanStatisticsUsage
monitor.TVF_ExecutionPlanColumnReferences

monitor.USP_InternalCollectExecutionPlanMetadata
monitor.USP_CreateExecutionEvidenceJson
monitor.USP_ExecutionPlanAnalysis
```

Die Verarbeitung lautet dann:

```text
Plan XML
   │
   ├─ TVF_ExecutionPlanObjectReferences
   ├─ TVF_ExecutionPlanStatisticsUsage
   └─ TVF_ExecutionPlanColumnReferences
            │
            ▼
   deduplizierte Referenzmenge
            │
            ▼
   USP_InternalCollectExecutionPlanMetadata
            │
            ├─ Objekt-/Indexmetadaten
            ├─ aktueller Statistikzustand
            ├─ Statistikspalten
            └─ optional Histogrammzusammenfassung
            │
            ▼
   USP_CreateExecutionEvidenceJson
            │
            ▼
   USP_ExecutionPlanAnalysis
```

Die Extractor-Funktionen lesen **nur XML**. Sie führen keine Katalogzugriffe durch.

Das ist wichtig, weil:

* ein Plan von einer anderen Instanz stammen kann,
* die referenzierte Datenbank lokal möglicherweise nicht existiert,
* datenbankübergreifende Katalogauflösung Dynamic SQL erfordert,
* der Standalone-Modus ohne Serverabhängigkeit funktionieren muss.

---

# 2. Statistik-Evidenz im JSON

## 2.1 Vorgeschlagene Struktur

Das JSON erhält einen neuen Bereich:

```json
{
  "schemaVersion": 1,
  "capture": {},
  "sourceEnvironment": {},
  "planIdentity": {},
  "statisticsIo": [],
  "statisticsTime": [],
  "statistics": {
    "planUsage": [],
    "currentSnapshot": [],
    "databaseSettings": [],
    "histogramSummaries": [],
    "histogramSteps": []
  },
  "objectMetadata": [],
  "indexMetadata": [],
  "parseStatus": [],
  "warnings": []
}
```

## 2.2 `statistics.planUsage`

Dieser Abschnitt wird direkt aus dem Plan erzeugt:

```json
{
  "statementOrdinal": 1,
  "databaseName": "ExampleDatabase",
  "schemaName": "ExampleSchema",
  "objectName": "ExampleObject",
  "statisticsName": "ExampleStatistics",
  "lastUpdateAtCompile": "2026-01-01T00:00:00",
  "modificationCountAtCompile": 12500,
  "samplingPercentAtCompile": 37.5,
  "evidenceSource": "SHOWPLAN_OPTIMIZER_STATS_USAGE"
}
```

SQL Server speichert in `OptimizerStatsUsage/StatisticsInfo`, welche Statistikobjekte der Optimizer bei der Kompilierung geladen hat. Enthalten sind Datenbank, Schema, Tabelle, Statistikname, Modification Count, Sampling Percent und Last Update. ([Microsoft Learn][1])

Die vorhandene `USP_ShowplanAnalysis` extrahiert diese Informationen bereits, allerdings noch ohne belastbare Statementidentität und ohne Vergleich zum aktuellen Zustand.

## 2.3 `statistics.currentSnapshot`

Optionaler aktueller Zustand:

```json
{
  "statementOrdinal": 1,
  "databaseName": "ExampleDatabase",
  "schemaName": "ExampleSchema",
  "objectName": "ExampleObject",
  "objectId": 123,
  "statisticsId": 4,
  "statisticsName": "ExampleStatistics",

  "autoCreated": false,
  "userCreated": false,
  "indexStatistics": true,
  "noRecompute": false,
  "filtered": false,
  "filterDefinition": null,
  "incremental": false,
  "temporary": false,
  "persistedSample": true,

  "lastUpdated": "2026-02-01T00:00:00",
  "rows": 10000000,
  "rowsSampled": 5000000,
  "samplePercent": 50.0,
  "steps": 198,
  "unfilteredRows": 10000000,
  "modificationCounter": 750000,
  "modificationPercent": 7.5,
  "persistedSamplePercent": 50.0,

  "collectionStatus": "AVAILABLE",
  "capturedAtUtc": "2026-07-21T08:00:00.000Z"
}
```

`sys.dm_db_stats_properties` liefert unter anderem `last_updated`, `rows`, `rows_sampled`, `steps`, `unfiltered_rows`, `modification_counter` und `persisted_sample_percent`. Die Funktion kann bei fehlendem Objekt, fehlender Statistik oder mangelnder Sichtbarkeit auch ein leeres Resultset liefern; das muss als Status und nicht als Nullstatistik behandelt werden. ([Microsoft Learn][2])

## 2.4 Statistikspalten

Zusätzlich müssen die Spalten des Statistikobjekts erfasst werden:

```json
{
  "statisticsId": 4,
  "statisticsName": "ExampleStatistics",
  "columns": [
    {
      "ordinal": 1,
      "columnId": 3,
      "columnName": "ExampleKey1",
      "isHistogramColumn": true
    },
    {
      "ordinal": 2,
      "columnId": 7,
      "columnName": "ExampleKey2",
      "isHistogramColumn": false
    }
  ]
}
```

`sys.stats_columns.stats_column_id` ist der auf 1 basierende Ordinalwert innerhalb des Statistikobjekts. Nur die erste Statistikspalte besitzt das Histogramm; weitere Spalten wirken über Dichteinformationen beziehungsweise Schlüsselpräfixe. ([Microsoft Learn][3])

---

# 3. Histogramme: optional und abgestuft

Ein vollständiges Histogramm sollte **nicht standardmäßig** ins Evidenz-JSON aufgenommen werden.

Gründe:

* bis zu 200 Schritte je Statistik,
* potenziell viele verwendete oder relevante Statistiken,
* `range_high_key` kann reale fachliche Werte enthalten,
* größere Payload,
* häufig genügt eine abgeleitete Zusammenfassung.

`sys.dm_db_stats_histogram` liefert Histogramme ab SQL Server 2016 SP1 CU2 und damit auf allen Zielversionen 2019, 2022 und 2025. Das Histogramm bezieht sich auf die erste Schlüsselspalte und umfasst maximal 200 Schritte. ([Microsoft Learn][4])

## 3.1 Parameter

Für `USP_CreateExecutionEvidenceJson` beziehungsweise den Collector:

```sql
@StatistikEvidenzModus varchar(16) = 'PLAN_ONLY',
@HistogrammModus      varchar(16) = 'NONE',
@MaxStatistiken       int         = 100,
@MaxHistogrammSchritte int        = 20000
```

### `@StatistikEvidenzModus`

```text
NONE
PLAN_ONLY
USED
RELEVANT
OBJECT_ALL
```

| Modus        | Inhalt                                                                      |
| ------------ | --------------------------------------------------------------------------- |
| `NONE`       | keine Statistik-Evidenz                                                     |
| `PLAN_ONLY`  | nur `OptimizerStatsUsage` aus dem XML                                       |
| `USED`       | aktueller Zustand exakt der im Plan verwendeten Statistiken                 |
| `RELEVANT`   | verwendete Statistiken plus Statistiken auf Predicate-/Join-/Sortierspalten |
| `OBJECT_ALL` | sämtliche sichtbaren Statistiken aller referenzierten Objekte               |

Default:

```text
PLAN_ONLY
```

### `@HistogrammModus`

```text
NONE
SUMMARY
STEPS
```

| Modus     | Inhalt                                |
| --------- | ------------------------------------- |
| `NONE`    | keine Histogrammauswertung            |
| `SUMMARY` | nur abgeleitete Verteilungskennzahlen |
| `STEPS`   | vollständige Histogrammschritte       |

Default:

```text
NONE
```

`OBJECT_ALL` und `STEPS` sollten als High-Impact-Pfad behandelt werden.

## 3.2 Histogrammzusammenfassung

Beispielsweise:

```json
{
  "statisticsId": 4,
  "statisticsName": "ExampleStatistics",
  "histogramSteps": 198,
  "histogramEstimatedRows": 10000000,
  "maxEqualRows": 950000,
  "maxRangeRows": 2100000,
  "dominantStepPercent": 21.0,
  "equalRowsSkewRatio": 145.3,
  "averageRangeRowsSkewRatio": 38.7,
  "tailStepPercent": 8.5,
  "collectionStatus": "AVAILABLE"
}
```

Das Repository besitzt mit `USP_StatisticsDistributionAnalysis` bereits entsprechende abstrahierte Verteilungskennzahlen. Diese Logik sollte wiederverwendet beziehungsweise zentralisiert werden, nicht ein zweites Mal abweichend in der Plananalyse entstehen. Die vorhandene Procedure behandelt diese Werte ausdrücklich nur als Evidenz, die mit Plan- und Predicatekontext korreliert werden muss.

---

# 4. Funktion zur Extraktion betroffener Objekte

## 4.1 Hauptfunktion

```text
monitor.TVF_ExecutionPlanObjectReferences
```

Vorgeschlagene Signatur:

```sql
CREATE OR ALTER FUNCTION [monitor].[TVF_ExecutionPlanObjectReferences]
(
      @PlanXml      xml
    , @StatementId  int = NULL
)
RETURNS TABLE
AS
RETURN
(
    ...
);
```

## 4.2 Resultset

```text
ReferenceOrdinal
StatementOrdinal
StatementId
StatementCompId
NodeId

ReferenceType
ReferenceSource

DatabaseName
SchemaName
ObjectName
IndexName
AliasName
StorageType

PlanObjectId
PlanIndexId

IsTemporaryObject
IsTableVariable
IsRemoteObject
IsDmlTarget

ResolutionCapability
SourceElement
```

### `ReferenceType`

```text
TABLE
INDEXED_VIEW
VIEW
INDEX
TABLE_VALUED_FUNCTION
REMOTE_OBJECT
TEMPORARY_OBJECT
TABLE_VARIABLE
UNKNOWN
```

### `ReferenceSource`

```text
ACCESS_PATH
DML_TARGET
STATISTICS_USAGE
MISSING_INDEX
COLUMN_REFERENCE
FUNCTION_REFERENCE
REMOTE_QUERY
```

Damit bleibt sichtbar, warum ein Objekt als betroffen gilt.

---

# 5. Warum nicht nur alle `<Object>`-Elemente lesen?

Der aktuelle Code verwendet:

```sql
//*[local-name(.)="Object"]
```

und erzeugt daraus Datenbank, Schema, Tabelle, Index, Alias und Storage.

Das ist als erste Quelle richtig, aber nicht vollständig.

Betroffene Objekte können zusätzlich auftreten in:

* `OptimizerStatsUsage/StatisticsInfo`,
* `MissingIndex`,
* `ColumnReference`,
* DML-Zieloperatoren,
* Function-/TVF-Referenzen,
* Remote Query,
* Table-Valued Functions,
* temporären Strukturen.

Deshalb sollte die Funktion mehrere XML-Pfade normalisieren und das Ergebnis mit `ReferenceSource` kennzeichnen.

## 5.1 Deduplizierung

Die Funktion sollte zunächst **nicht zu früh deduplizieren**.

Ein Objekt kann beispielsweise vorkommen als:

```text
Statement 1 / Node 4 / ACCESS_PATH
Statement 1 / Node 7 / ACCESS_PATH
Statement 1 / STATISTICS_USAGE
Statement 2 / Node 3 / DML_TARGET
```

Alle vier Referenzen sind fachlich unterschiedlich.

Für die anschließende Katalogabfrage wird eine zweite, deduplizierte Menge erzeugt:

```text
DatabaseName
SchemaName
ObjectName
```

beziehungsweise:

```text
DatabaseName
SchemaName
ObjectName
IndexName
```

---

# 6. Separate Funktion für Statistics Usage

Die verwendeten Statistiken sollten nicht nur als spezielle Objektzeilen behandelt werden.

Empfohlen:

```text
monitor.TVF_ExecutionPlanStatisticsUsage
```

Resultset:

```text
StatisticsUsageOrdinal
StatementOrdinal
StatementId
StatementCompId

DatabaseName
SchemaName
ObjectName
StatisticsName

LastUpdateAtCompile
ModificationCountAtCompile
SamplingPercentAtCompile

SourceElement
ParseStatus
```

Vorteil:

* klare Granularität: eine Zeile je verwendeter Statistik und Statement,
* direkte Verbindung zum aktuellen Statistikzustand,
* kein vermischtes Objekt-/Statistikresultset,
* einfache Ermittlung von `StatsChangedSinceCompile`.

Abgeleitete Felder nach aktueller Anreicherung:

```text
CurrentStatisticsId
CurrentLastUpdated
CurrentModificationCounter
CurrentSamplePercent

StatisticsStillExists
StatisticsChangedSinceCompile
StatisticsUpdatedSinceCompile
ModificationDeltaSinceCompile
SamplingChangedSinceCompile
MetadataMatchStatus
```

---

# 7. Separate Funktion für betroffene Spalten

Empfohlen:

```text
monitor.TVF_ExecutionPlanColumnReferences
```

Resultset:

```text
StatementOrdinal
StatementId
NodeId

ColumnUsage
ExpressionContext

DatabaseName
SchemaName
ObjectName
AliasName
ColumnName

IsSeekColumn
IsResidualPredicateColumn
IsJoinColumn
IsGroupByColumn
IsOrderByColumn
IsOutputColumn
IsPartitionColumn
```

Diese Funktion ist notwendig, um im Modus `RELEVANT` nicht alle Statistiken eines Objekts lesen zu müssen.

## Beispiel

Ein Plan verwendet:

```text
Predicate:
    ExampleDate >= @FromDate
    AND ExampleStatus = @Status
```

Dann werden gezielt Statistiken gesucht, die mindestens eine dieser Spalten enthalten:

```text
ExampleDate
ExampleStatus
```

Zusätzlich wird unterschieden:

* führende Statistikspalte,
* weitere Statistikspalte,
* Indexstatistik,
* Auto Column Statistic,
* gefilterte Statistik.

---

# 8. Zielgerichtete Metadatenermittlung

## 8.1 Collector

```text
monitor.USP_InternalCollectExecutionPlanMetadata
```

Eingaben:

```sql
@PlanXml                    xml,
@StatistikEvidenzModus      varchar(16),
@HistogrammModus            varchar(16),
@QuellumgebungBestaetigt    bit,
@MaxStatistiken             int,
@MaxHistogrammSchritte      int,
@LockTimeoutMs              int,
@HighImpactConfirmed        bit
```

Die Procedure:

1. extrahiert Objektreferenzen,
2. extrahiert Statistics Usage,
3. extrahiert relevante Spalten,
4. gruppiert nach Datenbank,
5. liest pro referenzierter Datenbank nur passende Katalogzeilen,
6. liest nur passende Statistiken,
7. liest Histogramme erst nach Kandidateneingrenzung.

## 8.2 Katalogzugriff

Je Datenbank per Dynamic SQL:

```sql
USE [Zieldatenbank];

SELECT ...
FROM [sys].[schemas] AS [sc] WITH (NOLOCK)
JOIN [sys].[objects] AS [o] WITH (NOLOCK)
  ON [o].[schema_id] = [sc].[schema_id]
JOIN [sys].[stats] AS [st] WITH (NOLOCK)
  ON [st].[object_id] = [o].[object_id]
LEFT JOIN [sys].[indexes] AS [i] WITH (NOLOCK)
  ON [i].[object_id] = [st].[object_id]
 AND [i].[index_id] = [st].[stats_id]
OUTER APPLY [sys].[dm_db_stats_properties]
(
    [st].[object_id],
    [st].[stats_id]
) AS [sp]
WHERE [sc].[name] = @SchemaName
  AND [o].[name] = @ObjectName;
```

Entsprechend der Projektvorgabe wird zur Objektauflösung nicht `OBJECT_ID()` verwendet. Die Auflösung erfolgt direkt über:

```text
sys.schemas
sys.objects
sys.stats
sys.indexes
sys.stats_columns
sys.columns
```

`sys.dm_db_stats_properties` benötigt danach die bereits relational ermittelten `object_id`- und `stats_id`-Werte. Die DMF ist dafür ausgelegt, zusammen mit `sys.objects` und `sys.stats` verwendet zu werden. ([Microsoft Learn][2])

---

# 9. Auswahl relevanter Statistiken

## Modus `USED`

Nur Statistikobjekte aus:

```text
OptimizerStatsUsage
```

Vorteil:

* sehr zielgerichtet,
* geringe Eigenlast,
* direkte Compilezeit-/Current-State-Korrelation.

Nachteil:

* eine fehlende oder nicht verwendete, aber eigentlich hilfreiche Statistik wird nicht gefunden.

## Modus `RELEVANT`

Zusätzlich werden Statistiken gesucht, deren Spalten sich mit folgenden Planverwendungen überschneiden:

```text
SEEK
RESIDUAL_PREDICATE
JOIN
GROUP_BY
ORDER_BY
PARTITION_PREDICATE
```

Priorisierung:

1. im Plan verwendete Statistik,
2. Statistik mit relevanter Spalte als erster Spalte,
3. Statistik mit relevanter Spalte in späterer Position,
4. Indexstatistik des verwendeten Index,
5. sonstige Statistik auf dem Objekt.

## Modus `OBJECT_ALL`

Alle Statistiken aller referenzierten Objekte.

Dieser Modus ist für tiefe Spezialanalyse geeignet, aber nicht als Default.

---

# 10. Umgebungsabgleich

Ein importierter Plan darf nicht automatisch gegen die aktuelle Instanz angereichert werden.

Dafür benötigt die öffentliche API:

```sql
@MetadatenQuellenmodus       varchar(16) = 'EVIDENCE_ONLY',
@QuellumgebungBestaetigt     bit         = 0
```

### `@MetadatenQuellenmodus`

```text
EVIDENCE_ONLY
CURRENT_SERVER
```

`CURRENT_SERVER` ist nur zulässig, wenn:

```sql
@QuellumgebungBestaetigt = 1
```

Optional kann später eine explizite Datenbankabbildung ergänzt werden:

```sql
@DatabaseMappingJson nvarchar(max) = NULL
```

Beispiel:

```json
{
  "ExampleSourceDatabase": "ExampleTargetDatabase"
}
```

Eine implizite Zuordnung anhand ähnlich klingender Datenbank- oder Objektnamen sollte nicht erfolgen.

---

# 11. Sonderfälle

## Temporäre Tabellen

Status:

```text
TEMP_OBJECT_NOT_RESOLVABLE
TEMP_OBJECT_RESOLVED_IN_CURRENT_SESSION
TEMP_OBJECT_EXPIRED
```

Nach Ende der Quellsession ist die genaue TempDB-Struktur häufig nicht mehr auflösbar.

## Tabellenvariablen

```text
TABLE_VARIABLE_PLAN_ONLY
```

Eine stabile aktuelle Katalogauflösung ist normalerweise nicht möglich.

## Remote Objects

```text
REMOTE_OBJECT_NO_LOCAL_METADATA
```

Keine lokale Kataloganreicherung.

## Synonyme

Ein Plan kann das aufgelöste Ziel oder den ursprünglichen Bezug unterschiedlich darstellen. Eine Synonymauflösung ist nur bei passender Quellumgebung möglich.

## Views

Der Plan zeigt nach Expansion häufig die tatsächlich verwendeten Basisobjekte. Indexed Views können dagegen als physischer Zugriff auftreten.

## Spools und Worktables

Diese sind physische interne Arbeitsstrukturen, aber keine normalen katalogauflösbaren Benutzerobjekte:

```text
INTERNAL_WORKTABLE
INTERNAL_WORKFILE
SPOOL_STORAGE
```

---

# 12. Erweiterte Signatur von `USP_CreateExecutionEvidenceJson`

```sql
CREATE OR ALTER PROCEDURE [monitor].[USP_CreateExecutionEvidenceJson]
      @PlanXml                       xml             = NULL
    , @StatisticsIoText              nvarchar(max)   = NULL
    , @StatisticsTimeText            nvarchar(max)   = NULL
    , @StatisticsLanguage            varchar(16)     = 'AUTO'

    , @StatisticsEvidenceJson         nvarchar(max)   = NULL
    , @ObjectMetadataJson             nvarchar(max)   = NULL

    , @StatistikEvidenzModus          varchar(16)     = 'PLAN_ONLY'
    , @HistogrammModus                varchar(16)     = 'NONE'
    , @MetadatenQuellenmodus          varchar(16)     = 'EVIDENCE_ONLY'
    , @QuellumgebungBestaetigt        bit             = 0

    , @StatementId                    int             = NULL
    , @StatementOrdinal               int             = NULL
    , @SameExecutionAsPlanConfirmed   bit             = NULL
    , @CapturedAtUtc                  datetime2(3)    = NULL

    , @SourceProductVersion           nvarchar(128)   = NULL
    , @SourceCompatibilityLevel       smallint        = NULL
    , @SourceEngineEdition            int             = NULL

    , @MaxStatistiken                 int             = 100
    , @MaxHistogrammSchritte          int             = 20000
    , @LockTimeoutMs                  int             = 0
    , @HighImpactConfirmed            bit             = 0

    , @AdditionalEvidenceJson         nvarchar(max)   = NULL
    , @ExistingEvidenceJson           nvarchar(max)   = NULL
    , @RawTextHandling                varchar(16)     = 'HASH_ONLY'
    , @StrictValidation               bit             = 1

    , @ResultSetArt                   varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max)   = NULL
    , @Json                           nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen                 bit             = 1
    , @Hilfe                          bit             = 0

    , @StatusCodeOut                  varchar(40)     = NULL OUTPUT
    , @IsPartialOut                   bit             = NULL OUTPUT
    , @ErrorNumberOut                 int             = NULL OUTPUT
    , @ErrorMessageOut                nvarchar(2048)  = NULL OUTPUT;
```

## Verhalten

### Reiner Standalone-Aufruf

```sql
@PlanXml                  = @Plan,
@StatistikEvidenzModus    = 'PLAN_ONLY',
@MetadatenQuellenmodus    = 'EVIDENCE_ONLY'
```

Nur die im Plan gespeicherte Compilezeit-Evidenz wird übernommen.

### Plan plus extern erzeugte Statistikdaten

```sql
@PlanXml                   = @Plan,
@StatisticsEvidenceJson    = @StatisticsJson,
@MetadatenQuellenmodus     = 'EVIDENCE_ONLY'
```

Ideal für einen Plan, der von einer anderen Instanz stammt.

### Plan aus aktueller Umgebung mit gezielter Erhebung

```sql
@PlanXml                    = @Plan,
@StatistikEvidenzModus      = 'RELEVANT',
@HistogrammModus            = 'SUMMARY',
@MetadatenQuellenmodus      = 'CURRENT_SERVER',
@QuellumgebungBestaetigt    = 1,
@HighImpactConfirmed        = 1
```

---

# 13. Findings aus Statistik-Korrelation

Erst mit dieser Trennung werden belastbare Findings möglich:

```text
STATISTICS_USED_AT_COMPILE
STATISTICS_NO_LONGER_EXISTS
STATISTICS_UPDATED_SINCE_COMPILE
STATISTICS_CHANGED_AFTER_PLAN_COMPILE
STATISTICS_HIGH_MODIFICATION_AT_COMPILE
STATISTICS_HIGH_CURRENT_MODIFICATION
STATISTICS_LOW_SAMPLE_AT_COMPILE
STATISTICS_LOW_CURRENT_SAMPLE
STATISTICS_SAMPLE_CHANGED
STATISTICS_FILTER_MISMATCH_REVIEW
STATISTICS_LEADING_COLUMN_MISMATCH
PREDICATE_WITHOUT_RELEVANT_STATISTICS
CARDINALITY_ERROR_CORRELATED_WITH_STATISTICS
HISTOGRAM_SKEW_CORRELATED_WITH_PARAMETER
```

## Beispiel einer belastbaren Korrelation

```text
Finding:
    CARDINALITY_ERROR_CORRELATED_WITH_STATISTICS

Evidenz:
    Actual Rows                  = 8.500.000
    Estimated Rows               = 12.000
    Cardinality Error            = Faktor 708
    Statistik im Compileplan     = ExampleStatistics
    Modification Count Compile   = 3.200.000
    Rows at Compile              = 4.000.000
    Modification Percent Compile = 80 %
    Sampling Percent Compile     = 4,5 %

Confidence:
    RUNTIME_CORRELATED

Gegenbeweisgrenze:
    Hohe Modification- oder niedrige Samplingwerte beweisen allein
    keine Ursache; Predicate- und Histogrammkontext wurden korreliert.
```

---

# 14. Ergänzung der Umsetzungswellen

## Welle 0

Zusätzlich zum bisherigen Vertrag:

* Objekt-Referenzschema definieren,
* Statistics-Usage-Schema definieren,
* Column-Reference-Schema definieren,
* Statistikabschnitt im Evidenz-JSON definieren,
* Collection- und Resolution-Statuscodes festlegen.

## Welle 1

Zuerst implementieren:

```text
TVF_ExecutionPlanObjectReferences
TVF_ExecutionPlanStatisticsUsage
TVF_ExecutionPlanColumnReferences
```

Diese bilden die Grundlage für alle weiteren Anreicherungen.

## Welle 2

```text
USP_InternalCollectExecutionPlanMetadata
```

Mit:

* Objektauflösung,
* Indexauflösung,
* Used-Statistics-Ermittlung,
* relevanten Statistics,
* aktuellen Stats Properties,
* optionaler Histogrammzusammenfassung.

## Welle 3

```text
USP_CreateExecutionEvidenceJson
```

Mit vollständiger Zusammenführung von:

* `STATISTICS IO`,
* `STATISTICS TIME`,
* Plan Statistics Usage,
* aktuellem Statistikzustand,
* Objekt-/Indexmetadaten,
* Histogrammzusammenfassungen.

## Welle 4

Erst danach die eigentlichen Regeln für:

* Indexschlüsselreihenfolge,
* Statistikspalten,
* Cardinality,
* Predicateabdeckung,
* Sortierreihenfolge.

# Entscheidung

**Ja, Statistikdaten gehören in das Evidenz-JSON.** Das Plan-XML liefert dabei den Compilezeit-Stand; der aktuelle beziehungsweise extern erfasste Statistikzustand wird getrennt ergänzt.

**Ja, mindestens eine zentrale Objekt-Extractor-Funktion wird benötigt.** Fachlich sauberer sind drei spezialisierte inline TVFs:

```text
TVF_ExecutionPlanObjectReferences
TVF_ExecutionPlanStatisticsUsage
TVF_ExecutionPlanColumnReferences
```

Die Funktionen bestimmen nur die Referenzen. Die zielgerichtete, datenbankweise Katalog- und Statistikauflösung übernimmt anschließend eine interne Stored Procedure. Dadurch bleibt der Standalone-Pfad portabel, während der frameworkintegrierte Pfad bei bestätigter Quellumgebung gezielt und performant anreichern kann.

[1]: https://learn.microsoft.com/uk-ua/SQL/relational-databases/statistics/statistics?view=sql-server-ver15&utm_source=chatgpt.com "Statistics - SQL Server | Microsoft Learn"
[2]: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-stats-properties-transact-sql?view=sql-server-ver17&utm_source=chatgpt.com "sys.dm_db_stats_properties (Transact-SQL) - SQL Server | Microsoft Learn"
[3]: https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-stats-columns-transact-sql?view=sql-server-ver17&utm_source=chatgpt.com "sys.stats_columns (Transact-SQL) - SQL Server | Microsoft Learn"
[4]: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-stats-histogram-transact-sql?view=sql-server-ver17&utm_source=chatgpt.com "sys.dm_db_stats_histogram (Transact-SQL) - SQL Server | Microsoft Learn"


Beim Histogramm muss man eventuell berücksichtigen, dass vertrauliche Daten mit übermittelt werden. Dazu sollte es einen Parameter geben, der diese Werte anonymisiert - diese sind für die Auswertung ja nicht unbedingt notwendig - es geht ja viel mehr um die Verteilung - evtl. sollte man aber jene Sätze markieren, die durch Einschränkungen direkt angesprochen werden, so das später der richtige Histogrammeintrag verwendet werden kann
Wie ist Deine Einschätzung dazu?


Ja. **Die Histogrammgrenzwerte sollten standardmäßig nicht in das übertragbare `@EvidenzJson` aufgenommen werden.** Für die Plananalyse werden überwiegend Verteilungskennzahlen und die Beziehung eines Predicate-Werts zum Histogramm benötigt, nicht der konkrete Wert selbst.

`RANGE_HI_KEY` kann reale Personen-, Kunden-, Konto-, Produkt-, Zeit-, Standort- oder Geschäftsdaten enthalten. Dasselbe gilt für:

* Compile- und Runtime-Parameterwerte,
* Konstanten in Predicates,
* Werte aus `IN`-Listen,
* Grenzen gefilterter Statistiken,
* Filterdefinitionen.

Das vorhandene Framework berechnet bereits Verteilungswerte wie `DominantStepPercent`, Skew-Verhältnisse und Tail-Anteile. Dafür sind die konkreten `RANGE_HI_KEY`-Werte nicht erforderlich.

# 1. Hauptempfehlung

Die Korrelation muss in dieser Reihenfolge erfolgen:

```text
1. Histogrammwerte lokal und kurzzeitig lesen
2. Predicate-/Parameterwerte lokal normalisieren
3. Werte gegen das Histogramm abgleichen
4. Treffer und Beziehungen als abgeleitete Informationen speichern
5. erst danach sensible Werte entfernen oder tokenisieren
6. nur die bereinigte Evidenz ins JSON schreiben
```

Die Anonymisierung darf also **nicht vor dem Matching** erfolgen. Sonst kann nicht mehr zuverlässig festgestellt werden:

* ob ein Wert genau einem `RANGE_HI_KEY` entspricht,
* in welchem Histogrammintervall er liegt,
* ob er unterhalb oder oberhalb des Histogramms liegt,
* welche Schritte ein Bereichsprädikat berührt,
* ob Compile- und Runtime-Parameter in unterschiedlichen Verteilungsbereichen liegen.

Die unbereinigten Werte sollten ausschließlich in lokalen Temp-Tabellen für die Dauer desselben Procedure-Aufrufs existieren.

---

# 2. „Anonymisierung“ genauer unterscheiden

Ein einfacher Hash ist streng genommen keine vollständige Anonymisierung.

Besonders bei kleinen Wertebereichen wie:

```text
Statuswerte
Geschlecht
Ländercodes
Monate
kleine IDs
Boolean-Werte
Postleitzahlen
```

kann ein Hash durch vorberechnete Vergleiche wiedererkannt werden.

Deshalb sollten die Modi fachlich sauber benannt werden.

## Vorgeschlagener Parameter

```sql
@EvidenzDatenschutzModus varchar(24) = 'DERIVED_ONLY'
```

Mögliche Werte:

| Modus            | Verhalten                                                                                                          |
| ---------------- | ------------------------------------------------------------------------------------------------------------------ |
| `DERIVED_ONLY`   | Keine konkreten Predicate-, Parameter- oder Histogrammgrenzwerte; nur abgeleitete Zuordnungen und Verteilungswerte |
| `TOKENIZED`      | Werte werden durch nicht rückrechenbare, capturebezogene Tokens ersetzt                                            |
| `RAW`            | Konkrete Werte werden ausgegeben; explizites Opt-in erforderlich                                                   |
| `STRUCTURE_ONLY` | Auch Tokens entfallen; nur Statistik-, Step- und Predicate-Ordnungsnummern sowie Kennzahlen                        |

**Default:**

```text
DERIVED_ONLY
```

`DERIVED_ONLY` ist für die Plananalyse normalerweise ausreichend.

Für `RAW` sollte zusätzlich erforderlich sein:

```sql
@SensitiveDataConfirmed bit = 0
```

Ohne Bestätigung:

```text
SENSITIVE_DATA_CONFIRMATION_REQUIRED
```

---

# 3. Histogrammschritte ohne Grenzwerte

Ein bereinigter Histogrammschritt kann so aussehen:

```json
{
  "statisticsReferenceId": 4,
  "statisticsSnapshotId": "7E0D...",
  "stepOrdinal": 37,

  "rangeRows": 185000.0,
  "equalRows": 9200.0,
  "distinctRangeRows": 6300.0,
  "averageRangeRows": 29.3651,

  "isPredicateTarget": true,
  "predicateMatchCount": 2,

  "rangeHighKey": null,
  "rangeHighKeyToken": null,
  "sensitiveValueStatus": "OMITTED_DERIVED_ONLY"
}
```

Die Reihenfolge wird durch `stepOrdinal` erhalten. Damit bleiben analysierbar:

* Verteilung,
* dominante Werte,
* große und kleine Ranges,
* Skew,
* Tail-Konzentration,
* Schrittbreite in Zeilen,
* Anzahl Distinct Values,
* Predicate-Zielschritte.

Der konkrete `RANGE_HI_KEY` ist dafür nicht nötig.

Die Histogrammstruktur beruht auf `RANGE_HI_KEY`, `EQ_ROWS`, `RANGE_ROWS`, `DISTINCT_RANGE_ROWS` und `AVG_RANGE_ROWS`; nur der Grenzwert selbst ist potenziell sensibel.

---

# 4. Ein Boolean allein reicht nicht

Eine Spalte wie:

```text
IsPredicateTarget = 1
```

ist als schnelle Anzeige nützlich, aber fachlich nicht ausreichend.

Ein Histogrammschritt kann angesprochen werden durch:

* den Compile-Parameter,
* den Runtime-Parameter,
* mehrere Werte einer `IN`-Liste,
* die Untergrenze eines `BETWEEN`,
* die Obergrenze eines `BETWEEN`,
* ein Range-Predicate,
* mehrere unterschiedliche Predicates,
* mehrere Statements.

Deshalb sollte es zusätzlich ein eigenes normalisiertes Resultset beziehungsweise JSON-Array geben:

```text
predicateHistogramMappings
```

---

# 5. Vorgeschlagenes Predicate-Histogramm-Mapping

## Struktur

```json
{
  "predicateReferenceId": 12,
  "statementOrdinal": 1,
  "nodeId": 8,
  "statisticsReferenceId": 4,

  "columnReferenceId": 3,
  "predicateKind": "EQUALITY",
  "valueSource": "RUNTIME_PARAMETER",

  "mappingStatus": "EXACT_RANGE_HIGH_KEY",
  "mappingConfidence": "HIGH",

  "matchedStepOrdinal": 37,
  "firstMatchedStepOrdinal": 37,
  "lastMatchedStepOrdinal": 37,
  "coveredStepCount": 1,

  "matchesRangeHighKey": true,
  "isBelowHistogram": false,
  "isAboveHistogram": false,
  "isWithinRange": false,

  "predicateValue": null,
  "predicateValueToken": null,
  "sensitiveValueStatus": "OMITTED_DERIVED_ONLY"
}
```

## Mappingstatus

```text
EXACT_RANGE_HIGH_KEY
WITHIN_HISTOGRAM_RANGE
BELOW_HISTOGRAM_MINIMUM
ABOVE_HISTOGRAM_MAXIMUM
RANGE_COVERS_MULTIPLE_STEPS
PARTIAL_LOWER_STEP
PARTIAL_UPPER_STEP
MULTIPLE_DISCRETE_STEPS
NON_LEADING_STATISTICS_COLUMN
NON_SARGABLE_EXPRESSION
TYPE_CONVERSION_FAILED
COLLATION_CONTEXT_UNAVAILABLE
AMBIGUOUS_STATISTICS_MATCH
NOT_MAPPABLE
```

Damit ist die fachliche Aussage auch ohne konkrete Werte erhalten.

---

# 6. Compile- und Runtimewerte getrennt markieren

Die bestehende Showplananalyse liest bereits Compile- und Runtime-Parameterwerte aus der Parameterliste.

Für Parameter Sensitivity sollten beide Werte getrennt gegen dasselbe Histogramm gemappt werden:

```text
valueSource = COMPILED_PARAMETER
valueSource = RUNTIME_PARAMETER
```

Beispiel:

```json
[
  {
    "valueSource": "COMPILED_PARAMETER",
    "mappingStatus": "EXACT_RANGE_HIGH_KEY",
    "matchedStepOrdinal": 12
  },
  {
    "valueSource": "RUNTIME_PARAMETER",
    "mappingStatus": "WITHIN_HISTOGRAM_RANGE",
    "matchedStepOrdinal": 184
  }
]
```

Daraus kann ohne Offenlegung der Werte abgeleitet werden:

```text
Compiled und Runtime Value liegen in stark unterschiedlichen
Bereichen der Datenverteilung.
```

Mögliche Findingcodes:

```text
COMPILED_RUNTIME_DIFFERENT_HISTOGRAM_STEPS
COMPILED_RUNTIME_LARGE_DISTRIBUTION_DISTANCE
RUNTIME_VALUE_OUTSIDE_COMPILE_HISTOGRAM_RANGE
PARAMETER_SENSITIVITY_DISTRIBUTION_EVIDENCE
```

## Abgeleitete Distanz

```text
HistogramStepDistance =
    ABS(RuntimeStepOrdinal - CompileStepOrdinal)
```

Diese Kennzahl ist nur innerhalb desselben Statistik-Snapshots sinnvoll.

Noch aussagekräftiger wäre:

```text
CumulativeRowMassBetweenValuesPercent
```

Damit wird nicht nur die Zahl der Steps, sondern die dazwischenliegende Datenmasse berücksichtigt.

---

# 7. Equality-, Range- und IN-Predicates

## Equality

Für:

```sql
WHERE [ExampleColumn] = @Value
```

genügt:

```text
matchedStepOrdinal
matchesRangeHighKey
isWithinRange
isAboveHistogram
isBelowHistogram
```

## Range

Für:

```sql
WHERE [ExampleColumn] >= @From
  AND [ExampleColumn] <  @To
```

werden benötigt:

```text
firstMatchedStepOrdinal
lastMatchedStepOrdinal
coveredStepCount
lowerBoundaryMappingStatus
upperBoundaryMappingStatus
estimatedCoveredHistogramRows
estimatedCoveredHistogramPercent
```

## IN-Liste

Für:

```sql
WHERE [ExampleColumn] IN (@A, @B, @C)
```

sollte pro Wert eine Mappingzeile erzeugt werden. Zusätzlich kann aggregiert werden:

```text
InputValueCount
MappedValueCount
DistinctMatchedStepCount
ExactBoundaryMatchCount
WithinRangeMatchCount
OutOfRangeCount
```

Konkrete Werte müssen nicht im JSON erscheinen.

---

# 8. Direkte Markierung der Schritte

Zusätzlich zum Mapping-Resultset sind Convenience-Felder im Histogrammschritt sinnvoll:

```text
IsCompileValueTarget
IsRuntimeValueTarget
IsLiteralTarget
IsRangeLowerBoundaryTarget
IsRangeUpperBoundaryTarget
IsInsidePredicateRange
PredicateMatchCount
```

Diese Felder werden aus dem normalisierten Mapping abgeleitet.

Die eigentliche Quelle der Wahrheit bleibt:

```text
predicateHistogramMappings
```

Einzelne Boolean-Felder ersetzen dieses Resultset nicht.

---

# 9. Mehrspaltige Statistiken

Ein direktes Histogramm-Mapping ist nur für die führende Statistikspalte möglich.

Bei einer Statistik:

```text
(A, B, C)
```

existiert das Histogramm nur für `A`.

Ein Predicate ausschließlich auf `B` oder `C` kann daher nicht sinnvoll einem Histogrammschritt zugeordnet werden.

Status:

```text
NON_LEADING_STATISTICS_COLUMN
```

Dichteinformationen können dennoch als zusätzliche Evidenz verwendet werden, aber daraus ergibt sich keine konkrete Step-Zuordnung.

Das Evidenzmodell sollte deshalb enthalten:

```text
StatisticsColumnOrdinal
IsHistogramColumn
```

---

# 10. Gefilterte Statistiken

Auch eine Filterdefinition kann vertrauliche Konstanten enthalten:

```sql
WHERE [TenantId] = 12345
```

Daher sollte sie denselben Datenschutzregeln unterliegen.

Empfohlene Felder:

```text
HasFilterDefinition
FilterDefinitionStatus
FilterDefinition
FilterDefinitionToken
```

Mögliche Statuswerte:

```text
NOT_FILTERED
AVAILABLE_RAW
TOKENIZED
OMITTED_SENSITIVE
PARSE_FAILED
```

Für die Analyse genügt häufig:

```text
IsFiltered
PredicateFilterCompatibilityStatus
```

mit:

```text
QUERY_PREDICATE_WITHIN_FILTER
QUERY_PREDICATE_OUTSIDE_FILTER
FILTER_COMPATIBILITY_UNKNOWN
```

Eine vollständige logische Implikationsprüfung beliebiger Filterprädikate ist komplex. Diese Bewertung sollte deshalb eine Confidence besitzen.

---

# 11. Tokens statt Hashes

Für `TOKENIZED` sollte nicht einfach nur Folgendes verwendet werden:

```sql
HASHBYTES('SHA2_256', CONVERT(nvarchar(max), @Value))
```

Das wäre bei kleinen oder vorhersehbaren Wertebereichen leicht vergleichbar.

Besser:

```text
Token = SHA2_256(
    CaptureSpecificSecret
    + TypeInformation
    + NormalizedValue
)
```

Eigenschaften:

* zufälliger Salt pro Capture,
* Salt wird nicht ins JSON geschrieben,
* gleicher Wert innerhalb desselben Captures ergibt denselben Token,
* Werte aus unterschiedlichen Captures sind standardmäßig nicht vergleichbar,
* Datentyp wird in die Tokenbildung aufgenommen.

Für die meisten Fälle ist jedoch `DERIVED_ONLY` besser, weil überhaupt kein Werttoken benötigt wird.

---

# 12. Übergreifender Datenschutzparameter

Histogrammgrenzwerte sind nicht die einzigen potenziell sensiblen Werte.

Der Parameter sollte mindestens gelten für:

```text
Histogram RANGE_HI_KEY
Compile-Parameterwerte
Runtime-Parameterwerte
Predicate-Konstanten
IN-Listen
Filtered-Statistics-Definitionen
Partition Boundary Values
optional Objekt-, Spalten- und Indexnamen
```

Ich würde daher neben dem Wertemodus einen separaten Identifikatormodus vorsehen:

```sql
@EvidenzDatenschutzModus varchar(24) = 'DERIVED_ONLY',
@IdentifierDatenschutzModus varchar(16) = 'RAW'
```

Mögliche Identifikatormodi:

```text
RAW
TOKENIZED
OMIT
```

Objekt-, Datenbank-, Schema-, Index- und Spaltennamen können ebenfalls interne Informationen enthalten. Für einen ausschließlich lokalen Aufruf ist `RAW` hilfreich; für einen Export wäre `TOKENIZED` sicherer.

---

# 13. Erweiterung des Evidence-Generators

Die Signatur sollte ergänzt werden um:

```sql
@EvidenzDatenschutzModus     varchar(24) = 'DERIVED_ONLY',
@IdentifierDatenschutzModus  varchar(16) = 'RAW',
@SensitiveDataConfirmed      bit         = 0,
@MitPredicateHistogramMap    bit         = 1
```

Validierung:

```text
RAW + SensitiveDataConfirmed = 0
    → SENSITIVE_DATA_CONFIRMATION_REQUIRED
```

Für `DERIVED_ONLY`:

* Matching findet intern mit Rohwerten statt.
* Rohwerte werden nicht ins JSON übernommen.
* abgeleitete Step-Zuordnungen bleiben erhalten.

---

# 14. Zusätzliche Resultsets

Zur bisherigen Planung kommen hinzu:

```text
histogramSummaries
histogramSteps
predicateHistogramMappings
statisticsColumns
sensitiveDataStatus
```

## `sensitiveDataStatus`

Beispiel:

```text
EvidenceSection              HandlingMode   RawValueCount   OutputRawValueCount
---------------------------  -------------  --------------  -------------------
HISTOGRAM_RANGE_HIGH_KEY     DERIVED_ONLY   198             0
COMPILED_PARAMETERS          DERIVED_ONLY   3               0
RUNTIME_PARAMETERS           DERIVED_ONLY   3               0
FILTER_DEFINITIONS           DERIVED_ONLY   1               0
OBJECT_IDENTIFIERS           RAW            7               7
```

Damit ist maschinenlesbar dokumentiert, welche Informationen entfernt oder tokenisiert wurden.

---

# 15. Aussagegrenzen

Auch mit lokaler Step-Zuordnung gibt es Fälle, die nicht sicher abgebildet werden können:

* nicht führende Statistikspalte,
* Ausdrücke statt direkter Spaltenreferenzen,
* implizite oder explizite Conversions,
* unterschiedliche Collations,
* Datentypänderungen seit Planerstellung,
* veraltetes Histogramm,
* mehrere mögliche Statistikobjekte,
* komplexe `OR`-Ausdrücke,
* LIKE-Muster ohne einfachen Prefix,
* lokale Variablen oder unbekannte Runtimewerte,
* CE-interne Annahmen, die nicht ausschließlich aus dem Histogramm stammen.

Deshalb benötigt jedes Mapping:

```text
MappingStatus
MappingConfidence
EvidenceLimit
```

Es darf nicht behauptet werden, der Optimizer habe exakt nur anhand dieses Histogrammschritts geschätzt, wenn weitere CE-Mechanismen beteiligt sein können.

# Schlussbewertung

**Ja, die konkreten Histogrammgrenzwerte stellen ein reales Datenschutzrisiko dar.**

**Die beste Defaultstrategie ist nicht Hashing, sondern `DERIVED_ONLY`:**

* Rohwerte nur kurzfristig lokal verwenden,
* Predicate und Parameter auf die Histogrammschritte abbilden,
* anschließend nur Step-Ordnungsnummern, Mappingarten und Verteilungskennzahlen ausgeben.

**Die direkt angesprochenen Histogrammschritte sollten markiert werden**, aber nicht nur über ein Boolean. Notwendig ist zusätzlich ein eigenes `predicateHistogramMappings`-Resultset, das Compile-, Runtime-, Literal-, Range- und IN-Werte getrennt einem oder mehreren Histogrammschritten zuordnet.

So bleibt die für die Plananalyse relevante Information erhalten, ohne die zugrunde liegenden fachlichen Werte in das übertragbare Evidenz-JSON aufzunehmen.







gestalte die Implementierung dieses Parts so, dass es auch ein eigenes Installationsscript gibt. Es soll nur die notwendigen Objekte installieren, die für diesen Teil der Analyse notwendig sind. 
Insgesamt soll es aber Bestandteil des Gesamtframeworks sein

lege alle gesammelten Informationen im Repository ab, um später die Implementierung beginnen zu können




Die vollständige Planung ist im Repository abgelegt und über PR **#26** in `main` gemergt.

## Abgelegte Dokumente

### Architektur- und Implementierungsvertrag

`Documentation/Architecture/Execution_Plan_Analysis_Design.md`

Enthalten sind unter anderem:

* Standalone- und Frameworkbetrieb
* `monitor.USP_ExecutionPlanAnalysis`
* `monitor.USP_CreateExecutionEvidenceJson`
* XML-Extractor für Objekte, Statistiken und Spalten
* `STATISTICS IO`-/`STATISTICS TIME`-Evidenz
* Statistik- und Histogrammanreicherung
* datenschutzsicheres Predicate-Histogramm-Mapping
* `DERIVED_ONLY` als Default für sensible Werte
* Workloadprofile und metadatengesteuerte Schwellenwerte
* Cardinality-, Access-, Spill-, Memory-, Parallelismus- und Indexregeln
* Indexschlüssel- und Sortierreihenfolgenanalyse
* Capability-Modell für SQL Server 2019, 2022 und 2025
* Resultset-, Finding-, Performance-, Locking- und Testverträge
* acht Umsetzungswellen.

### Teilinstaller- und Integrationsvertrag

`Documentation/Architecture/Execution_Plan_Analysis_Installation_Contract.md`

Der Vertrag sieht verbindlich vor:

```text
Code/Install/Install_ExecutionPlanAnalysis.sql
```

Der spätere Teilinstaller installiert nur:

* die gemeinsamen tatsächlich benötigten Framework-Helper,
* die drei Steuerungstabellen,
* die XML- und Meldungsparser,
* die Objekt-, Statistik- und Spalten-Extractor,
* den internen Metadata Collector,
* die zentrale Plananalyse-Engine,
* `USP_CreateExecutionEvidenceJson`,
* `USP_ExecutionPlanAnalysis`.

Nicht installiert werden durch den Teilinstaller:

* die gesamte Plan-Cache-Familie,
* Query Store,
* Current State,
* Extended Events,
* Infrastructure oder Server Health.

`Install_All.sql` wird dieselben Kernobjekte in identischer Reihenfolge installieren und anschließend die Integrationsobjekte wie `USP_ShowplanAnalysis` und `USP_PlanCacheAnalysis` ergänzen. Ein unvollständiger oder absichtlich fehlschlagender Installer-Stub wird nicht vorzeitig angelegt.

## Repository-Integration

Zusätzlich wurden aktualisiert:

* `Documentation/README.md` mit Verweisen auf beide neuen Verträge
* `Metadata/Quality/Future_Enhancement_Backlog.csv` mit dem neuen Backlogpunkt `PLAN-001`

`PLAN-001` ist als `P1`, `MEDIUM_TO_HIGH` und `RESEARCHED_NOT_IMPLEMENTED` registriert. Der Abnahmevertrag verlangt unter anderem:

* einen eigenen minimalen Installer,
* Integration in `Install_All.sql`,
* SQL-Server-2019/2022/2025-Tests,
* `DERIVED_ONLY` als Histogramm-Datenschutzdefault,
* keine automatische Queryausführung oder Tuningmaßnahme.

## Validierung

Folgende GitHub-Actions-Prüfungen waren erfolgreich:

* Commit message validation
* Repository privacy validation
* Documentation validation.

Der Arbeitsbranch wurde nach dem Merge automatisch entfernt; es bleibt kein zusätzlicher Plananalyse-Branch bestehen.
