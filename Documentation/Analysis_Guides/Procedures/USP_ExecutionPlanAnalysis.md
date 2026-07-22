# [monitor].[USP_ExecutionPlanAnalysis]

**Bereich:** Plan Cache und Showplan<br>
**Zweck:** Analysiert genau ein direkt übergebenes oder gezielt beschafftes Showplan-XML statement- und operatorbezogen.<br>
**Beobachtungsart:** importierter, gecachter, letzter tatsächlicher, aktueller oder Query-Store-Plan<br>
**Kostenklasse:** MEDIUM bis HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure ist der eigenständig installierbare Einstieg für eine Plananalyse. Der direkte `@PlanXml`-Pfad benötigt weder Plan Cache noch Query Store. Statements, Operatoren, Runtime-Counter, Access Paths, verwendete Statistiken, Parameter, Memory Grants, Spills und Findings werden über dieselbe zentrale Engine verarbeitet wie der Framework-Multi-Plan-Pfad.

## Nicht beantwortete Fragen

Ein Plan allein liefert keine vollständige Workloadhistorie, keinen sicheren Geschäftsnutzen eines Indexes und keine Ursache außerhalb der sichtbaren Plan- und Runtimeevidenz. Estimated Cost ist keine gemessene Zeit. Query-Store- oder Compilepläne besitzen keine Actual Rows, wenn diese nicht aus einer getrennten Evidenzquelle stammen.

## Sicherer Einstieg

```sql
DECLARE @ExamplePlanXml xml = N'<ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" />';
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml = @ExamplePlanXml
    , @AnalyseTiefe = 'STANDARD'
    , @WorkloadProfil = 'BALANCED'
    , @EvidenzDatenschutzModus = 'DERIVED_ONLY'
    , @ResultSetArt = 'CONSOLE';
```

Das Minimal-XML dient nur als synthetischer Aufrufrahmen; für fachliche Ergebnisse ist ein vollständiger Example-Showplan erforderlich. `FULL`, breite Statistikmodi und Histogramm-Steps benötigen `@HighImpactConfirmed = 1`.

`@MitSqlText = 1` gibt potentiell literalen oder proprietären SQL-Text aus und benötigt deshalb `@SensitiveDataConfirmed = 1`. Dasselbe gilt für `@EvidenzDatenschutzModus = 'RAW'`. Direkt übergebenes `@EvidenzJson` wird unabhängig von seiner Herkunft immer erneut auf den angeforderten Evidenz- und Identifier-Datenschutzmodus normalisiert; `DERIVED_ONLY` bleibt der Standard.

## Resultsets und Leserichtung

CONSOLE zeigt priorisierte `findings`. RAW, TABLE und JSON trennen `moduleStatus`, Capabilities, PlanDocument, Statements, Operatorbaum, Runtime, Threadruntime, Access Paths, Statistics Usage, Parameter, Memory/Spills, Execution Evidence, Histogramme, Predicate-Mappings und Findings.

## Eine Zeile bedeutet

Je nach Resultset beschreibt eine Zeile einen Plan, ein Statement, einen Operator innerhalb eines Statements, einen Threadcounter, einen Access Path, eine Statistik oder ein Finding. `NodeId` ist nur zusammen mit `StatementOrdinal` eindeutig.

## So lesen

Zuerst Planquelle und `RuntimeCounterScope`, danach Statements und Operatorbaum. Absolute Zeilen- und Readmengen vor Ratios prüfen. Findings erst mit Severity, Confidence, Workloadprofil und Evidenzgrenze bewerten.

## Warum kann das problematisch sein?

Statementvermischung, unvollständige Runtime-Counter oder pauschale Schwellen erzeugen falsche Diagnosen. Große Estimate-Abweichungen können Joinwahl und Grants beeinflussen; hohe Rows-Read-Discard-Mengen, Spills oder Millionen Lookups können erhebliche CPU-, IO- oder TempDB-Last verursachen.

## Wann ist es kein Problem?

Ein Scan, Lookup, Sort oder paralleler Plan ist nicht grundsätzlich fehlerhaft. Kleine absolute Mengen, Maintenance-Workloads oder bewusst durchsatzorientierte Verarbeitung können dieselbe Planform legitimieren.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche objektiven Plan- und Runtimewerte liegen je Statement und Operator vor, und welche Auffälligkeiten sind unter dem gewählten Workloadprofil relevant?

### Technischer Hintergrund

Die Ausführung ist pull-basiert; ein Plan ist keine lineare zeitliche Schrittfolge. Die Analyse hält StatementOrdinal und NodeId gemeinsam, paart ActualRows und ActualRowsRead je Runtime-Counter-Zeile und berechnet erst danach aggregierte Kennzahlen.

### Datenkette

Direktes Showplan XML oder gezielte Quellen `sys.dm_exec_query_plan`, `sys.dm_exec_query_plan_stats`, `sys.dm_exec_query_statistics_xml` beziehungsweise `sys.query_store_plan`; optional Evidence JSON. Importierte Histogramm- und Predicate-Mappings passieren vor jeder Ausgabe erneut die öffentliche Privacy-Grenze.

### Source Select

Bei einem gezielten Plan-Handle wird genau dieses Cacheobjekt aufgelöst; der direkte `@PlanXml`-Pfad überspringt die Cachequelle vollständig:

```sql
SELECT
      [qp].[query_plan]
FROM [sys].[dm_exec_query_plan](@PlanHandle) AS [qp]
WHERE @PlanHandle IS NOT NULL;
```

Für einen aktuellen tatsächlichen Plan verwendet der alternative Pfad eine exakt bestimmte Session beziehungsweise ein exakt bestimmtes Handle und `sys.dm_exec_query_statistics_xml` oder `sys.dm_exec_query_plan_stats`.

**Wichtig für die Eigenlast:** Genau eine Planquelle bestimmen, bevor XML analysiert wird. `@StatementId`, `@MaxOperatoren`, `@MaxFindings` und `@MaxDurationSeconds` begrenzen die XML-Arbeit; breite Plan-Cache-Suche gehört nicht in diesen Procedurepfad.

### Zeit- und Scope-Modell

Compile-, Last-Actual-, Current-Actual-, Query-Store- und importierte Evidenz bleiben getrennt. Ein Last-Actual-Plan ist der letzte bekannte Aufruf, nicht zwingend der aktuelle.

### Bewertung und Gegenprobe

Relative Abweichung, absolute Arbeit je Ausführung, Wiederholung und kumulative Wirkung kombinieren. Statistiken, Query Store, IO/TIME und Indexkataloge dienen als unabhängige Gegenprobe.

### Typische Fehlinterpretation

Ein 100-facher Estimatefehler bei wenigen Zeilen ist nicht automatisch kritischer als ein zehnfacher Fehler bei Millionen Zeilen. Missing-Index-XML ist keine fertige DDL.

### Folgeanalyse

`USP_CreateExecutionEvidenceJson`, `USP_ShowplanAnalysis`, Query Store Regressionen, Index Usage und Statistics Distribution.

## Primärquellen

- [Showplan logical and physical operators](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference?view=sql-server-ver17)
- [sys.dm_exec_query_plan](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-query-plan-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../04_Plan_Cache.md#standalone-execution-plan-analysis)
