#!/usr/bin/env python3
from __future__ import annotations

import csv
import io
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8", newline="\n")


def append_once(path: str, marker: str, block: str) -> None:
    text = read(path)
    if marker not in text:
        if not text.endswith("\n"):
            text += "\n"
        text += "\n" + block.strip() + "\n"
        write(path, text)


def csv_line(values: list[str]) -> str:
    buffer = io.StringIO(newline="")
    writer = csv.writer(buffer, lineterminator="")
    writer.writerow(values)
    return buffer.getvalue()


def replace_csv_rows(path: str, key_columns: tuple[int, ...], new_rows: list[list[str]]) -> None:
    text = read(path)
    lines = text.splitlines()
    if not lines:
        raise RuntimeError(f"Empty CSV: {path}")
    new_keys = {tuple(row[index] for index in key_columns) for row in new_rows}
    retained = [lines[0]]
    for line in lines[1:]:
        if not line.strip():
            continue
        row = next(csv.reader([line]))
        key = tuple(row[index] for index in key_columns)
        if key not in new_keys:
            retained.append(line)
    retained.extend(csv_line(row) for row in new_rows)
    write(path, "\n".join(retained) + "\n")


def procedure_signature(sql_text: str, procedure_name: str) -> str:
    match = re.search(
        rf"(?ims)^\s*CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[monitor\]\.\[{re.escape(procedure_name)}\]\s*(.*?)^\s*AS\s*$",
        sql_text,
    )
    if not match:
        raise RuntimeError(f"Procedure signature not found: {procedure_name}")
    return match.group(1).strip()


def parameter_rows(procedure_name: str, signature: str) -> list[list[str]]:
    no_comments = re.sub(r"(?m)--.*$", "", signature)
    normalized = re.sub(r"\s+", " ", no_comments).strip().lstrip(",").strip()
    declarations = re.split(r",\s*(?=@[A-Za-z_])", normalized)
    rows: list[list[str]] = []
    pattern = re.compile(
        r"^@(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s+"
        r"(?P<type>[A-Za-z0-9_]+(?:\s*\([^)]*\))?)"
        r"(?:\s*=\s*(?P<default>.*?))?"
        r"(?P<output>\s+OUTPUT)?$",
        re.IGNORECASE,
    )
    for declaration in declarations:
        declaration = declaration.strip()
        match = pattern.match(declaration)
        if not match:
            raise RuntimeError(f"Unparsed parameter declaration for {procedure_name}: {declaration}")
        default = (match.group("default") or "").strip()
        if match.group("output"):
            default = (default + " OUTPUT").strip()
        rows.append([procedure_name, match.group("name"), re.sub(r"\s+", "", match.group("type")), default])
    return rows


def table_schema(sql_text: str, table_name: str) -> str:
    match = re.search(rf"CREATE\s+TABLE\s+\[{re.escape(table_name)}\]\s*\(", sql_text, re.IGNORECASE)
    if not match:
        raise RuntimeError(f"Temp table not found: {table_name}")
    start = match.end() - 1
    depth = 0
    in_string = False
    index = start
    while index < len(sql_text):
        char = sql_text[index]
        if char == "'":
            if in_string and index + 1 < len(sql_text) and sql_text[index + 1] == "'":
                index += 2
                continue
            in_string = not in_string
        elif not in_string:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    body = sql_text[start + 1 : index]
                    return re.sub(r"\s+", " ", body).strip().rstrip(",")
        index += 1
    raise RuntimeError(f"Unclosed CREATE TABLE: {table_name}")


def insert_before(text: str, anchor: str, block: str) -> str:
    if block.strip() in text:
        return text
    position = text.find(anchor)
    if position < 0:
        return text.rstrip() + "\n\n" + block.strip() + "\n"
    return text[:position] + block.strip() + "\n\n" + text[position:]


# 1. Align internal object naming with the existing framework convention.
rename_pairs = [
    (
        "Code/04_PlanCache/049_USP_InternalCollectExecutionPlanMetadata.sql",
        "Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql",
        "USP_InternalCollectExecutionPlanMetadata",
        "InternalCollectExecutionPlanMetadata",
    ),
    (
        "Code/04_PlanCache/051_USP_InternalAnalyzeExecutionPlan.sql",
        "Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql",
        "USP_InternalAnalyzeExecutionPlan",
        "InternalAnalyzeExecutionPlan",
    ),
]
for old_path, new_path, old_name, new_name in rename_pairs:
    old = ROOT / old_path
    new = ROOT / new_path
    if old.exists():
        content = old.read_text(encoding="utf-8").replace(old_name, new_name)
        new.write_text(content, encoding="utf-8", newline="\n")
        old.unlink()

for path in [
    "Code/04_PlanCache/050_USP_ShowplanAnalysis.sql",
    "Code/04_PlanCache/052_USP_CreateExecutionEvidenceJson.sql",
    "Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql",
    "Code/Install/Install_ExecutionPlanAnalysis.sql",
    "Code/Install/Install_All.sql",
    "Metadata/Inventory/ExecutionPlanAnalysisDependencies.csv",
    "Documentation/Architecture/Execution_Plan_Analysis_Design.md",
    "Documentation/Architecture/Execution_Plan_Analysis_Installation_Contract.md",
]:
    text = read(path)
    text = text.replace("USP_InternalCollectExecutionPlanMetadata", "InternalCollectExecutionPlanMetadata")
    text = text.replace("USP_InternalAnalyzeExecutionPlan", "InternalAnalyzeExecutionPlan")
    text = text.replace("049_USP_InternalCollectExecutionPlanMetadata.sql", "049_InternalCollectExecutionPlanMetadata.sql")
    text = text.replace("051_USP_InternalAnalyzeExecutionPlan.sql", "051_InternalAnalyzeExecutionPlan.sql")
    write(path, text)

# SQL Server 2025 permission error 371 must remain equivalent to 229.
for path in (ROOT / "Code/04_PlanCache").glob("*.sql"):
    if path.name[:3] in {"049", "050", "051", "052", "053"}:
        text = path.read_text(encoding="utf-8")
        text = re.sub(r"IN \(229,(?!371,)", "IN (229,371,", text)
        text = re.sub(r"IN\(229,(?!371,)", "IN(229,371,", text)
        path.write_text(text, encoding="utf-8", newline="\n")

# 2. Object inventory.
object_rows = [
    ["TABLE", "PlanAnalysisProfile", "Code/04_PlanCache/041_PlanAnalysisProfile.sql"],
    ["TABLE", "PlanAnalysisRuleThreshold", "Code/04_PlanCache/042_PlanAnalysisRuleThreshold.sql"],
    ["TABLE", "PlanAnalysisProfileAssignment", "Code/04_PlanCache/043_PlanAnalysisProfileAssignment.sql"],
    ["FUNCTION", "TVF_ParseStatisticsIoText", "Code/04_PlanCache/044_TVF_ParseStatisticsIoText.sql"],
    ["FUNCTION", "TVF_ParseStatisticsTimeText", "Code/04_PlanCache/045_TVF_ParseStatisticsTimeText.sql"],
    ["FUNCTION", "TVF_ExecutionPlanObjectReferences", "Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql"],
    ["FUNCTION", "TVF_ExecutionPlanStatisticsUsage", "Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql"],
    ["FUNCTION", "TVF_ExecutionPlanColumnReferences", "Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql"],
    ["INTERNAL_PROCEDURE", "InternalCollectExecutionPlanMetadata", "Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql"],
    ["INTERNAL_PROCEDURE", "InternalAnalyzeExecutionPlan", "Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql"],
    ["PROCEDURE", "USP_CreateExecutionEvidenceJson", "Code/04_PlanCache/052_USP_CreateExecutionEvidenceJson.sql"],
    ["PROCEDURE", "USP_ExecutionPlanAnalysis", "Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql"],
]
replace_csv_rows("Metadata/Inventory/Objects.csv", (0, 1), object_rows)

# 3. Public parameter inventory from canonical signatures.
public_procedures = {
    "USP_CreateExecutionEvidenceJson": "Code/04_PlanCache/052_USP_CreateExecutionEvidenceJson.sql",
    "USP_ExecutionPlanAnalysis": "Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql",
}
all_parameter_rows: list[list[str]] = []
for procedure, source in public_procedures.items():
    signature = procedure_signature(read(source), procedure)
    all_parameter_rows.extend(parameter_rows(procedure, signature))
replace_csv_rows("Metadata/Inventory/Parameters.csv", (0, 1), all_parameter_rows)

# 4. Result-set inventory generated from actual temp-table schemas.
evidence_sql = read(public_procedures["USP_CreateExecutionEvidenceJson"])
analysis_sql = read(public_procedures["USP_ExecutionPlanAnalysis"])
evidence_maps = {
    "captureStatus": "#EPE_CaptureStatus",
    "statisticsIo": "#EPE_StatisticsIoOutput",
    "statisticsTime": "#EPE_StatisticsTimeOutput",
    "planStatisticsUsage": "#EPE_PlanStatisticsUsageOutput",
    "objectReferences": "#EPE_ObjectReferencesOutput",
    "currentStatistics": "#EPE_StatisticsCurrentOutput",
    "histogramSummaries": "#EPE_HistogramSummaryOutput",
    "histogramSteps": "#EPE_HistogramStepsOutput",
    "predicateHistogramMappings": "#EPE_PredicateMappingsOutput",
    "collectionStatus": "#EPE_CollectionStatus",
    "warnings": "#EPE_Warnings",
}
analysis_maps = {
    "moduleStatus": "#EPA_ModuleStatus",
    "capabilities": "#EPA_Capabilities",
    "planDocuments": "#EPA_PlanDocuments",
    "statements": "#EPA_Statements",
    "operatorTree": "#EPA_Operators",
    "operatorRuntime": "#EPA_OperatorRuntime",
    "operatorThreadRuntime": "#EPA_OperatorThreadRuntime",
    "accessPaths": "#EPA_AccessPaths",
    "statisticsUsage": "#EPA_StatisticsUsage",
    "parametersAndVariants": "#EPA_Parameters",
    "memoryAndSpills": "#EPA_MemoryAndSpills",
    "executionEvidence": "#EPA_ExecutionEvidence",
    "histogramSummaries": "#EPA_HistogramSummaries",
    "histogramSteps": "#EPA_HistogramSteps",
    "predicateHistogramMappings": "#EPA_PredicateHistogramMappings",
    "findings": "#EPA_Findings",
}
result_rows: list[list[str]] = []
for result_name, table_name in evidence_maps.items():
    result_rows.append([
        "USP_CreateExecutionEvidenceJson", result_name,
        "1" if result_name == "captureStatus" else "0", "1", "1", table_name, "1",
        table_schema(evidence_sql, table_name[1:]),
        "Keine Ausführungsevidenz im gewählten Scope",
    ])
for result_name, table_name in analysis_maps.items():
    result_rows.append([
        "USP_ExecutionPlanAnalysis", result_name,
        "1" if result_name == "findings" else "0", "1", "1", table_name, "1",
        table_schema(analysis_sql, table_name[1:]),
        "Keine Plananalyseergebnisse im gewählten Scope",
    ])
replace_csv_rows("Metadata/Inventory/ResultSets.csv", (0, 1), result_rows)

# 5. System-source inventory.
system_source_rows = [
    ["Showplan XML", "ENGINE_XML_FORMAT", "PLAN_DOCUMENT", "SQL Server 2019+; optional attributes are detected from the supplied XML", "No server permission when XML is supplied directly; framework grants none", "MEDIUM_TO_HIGH", "Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql | Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql | Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql | Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql | Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql", "Canonical implementation; unknown future XML elements are tolerated"],
    ["sys.dm_exec_query_plan", "DMF", "SERVER", "SQL Server 2019+", "VIEW SERVER STATE or SQL Server 2022+ equivalent where applicable; framework grants none", "MEDIUM", "Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql | Code/04_PlanCache/050_USP_ShowplanAnalysis.sql", "Compile-plan source; plan cache evidence is volatile"],
    ["sys.dm_exec_query_plan_stats", "DMF", "SERVER", "SQL Server 2019+ and LAST_QUERY_PLAN_STATS evidence available", "VIEW SERVER STATE or SQL Server 2022+ equivalent where applicable; framework grants none", "MEDIUM", "Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql | Code/04_PlanCache/050_USP_ShowplanAnalysis.sql", "Last-known actual source; the framework does not activate collection"],
    ["sys.dm_exec_query_statistics_xml", "DMF", "SERVER_SESSION", "SQL Server 2019+ and live profiling information available", "VIEW SERVER STATE or ownership/visibility of target session; framework grants none", "MEDIUM_TO_HIGH", "Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql", "Current request plan can be partial"],
    ["sys.query_store_plan", "CATALOG_VIEW_OR_TABLE", "DATABASE", "Query Store enabled and selected plan visible", "VIEW DATABASE STATE or applicable Query Store visibility; framework grants none", "MEDIUM", "Code/04_PlanCache/053_USP_ExecutionPlanAnalysis.sql", "Query Store plan is compile evidence; runtime is separate"],
    ["sys.dm_db_stats_properties", "DMF", "DATABASE", "SQL Server 2019+", "Metadata visibility on referenced object/statistics; framework grants none", "MEDIUM_SCOPE_DEPENDENT", "Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql | Code/04_PlanCache/052_USP_CreateExecutionEvidenceJson.sql", "Current statistics snapshot; absent row is status not numeric zero"],
    ["sys.dm_db_stats_histogram", "DMF", "DATABASE", "SQL Server 2019+", "Metadata visibility on referenced object/statistics; framework grants none", "HIGH_OPT_IN", "Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql | Code/04_PlanCache/052_USP_CreateExecutionEvidenceJson.sql", "Histogram values are privacy-controlled; DERIVED_ONLY is default"],
]
replace_csv_rows("Metadata/Inventory/SystemSources.csv", (0,), system_source_rows)

# 6. Reference signatures.
reference_path = "Documentation/Reference/Procedure_Reference.md"
reference = read(reference_path)
for procedure, source in public_procedures.items():
    if f"## `[monitor].[{procedure}]`" in reference:
        continue
    signature = procedure_signature(read(source), procedure)
    section = f"""## `[monitor].[{procedure}]`

Quelle: `{source}`

```sql
{signature}
```

"""
    reference = insert_before(reference, "## `[monitor].[USP_ShowplanAnalysis]`", section)
write(reference_path, reference)

# 7. Procedure pages.
evidence_page = r'''# [monitor].[USP_CreateExecutionEvidenceJson]

**Bereich:** Plan Cache und Showplan<br>
**Zweck:** Normalisiert bereits erfasste Plan-, STATISTICS-IO-, STATISTICS-TIME- und Statistik-/Histogrammevidenz in ein versioniertes JSON.<br>
**Beobachtungsart:** importierte oder gezielt ergänzte Ausführungsevidenz<br>
**Kostenklasse:** LOW bis HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure ist passend, wenn vorhandene Laufzeitinformationen derselben oder einer nachvollziehbar zugeordneten Ausführung in ein gemeinsames Format überführt werden sollen. Sie führt die analysierte Query niemals aus. Der Standardmodus `DERIVED_ONLY` entfernt konkrete Parameter-, Predicate- und Histogrammgrenzwerte aus dem exportierbaren Ergebnis, nachdem eine mögliche lokale Zuordnung zu Histogrammschritten erfolgt ist.

## Nicht beantwortete Fragen

Das JSON beweist nicht automatisch, dass Plan, IO- und TIME-Meldungen aus derselben Ausführung stammen. Diese Beziehung wird über `SameExecutionConfidence` ausgewiesen. Ein aktueller Statistikzustand beweist zudem nicht, dass derselbe Zustand bei der Plankompilierung vorlag.

## Sicherer Einstieg

```sql
DECLARE @EvidenceJson nvarchar(max);
EXEC [monitor].[USP_CreateExecutionEvidenceJson]
      @StatisticsIoText = N'Table ''ExampleObject''. Scan count 1, logical reads 8, physical reads 0, read-ahead reads 0, lob logical reads 0.'
    , @StatisticsTimeText = N'SQL Server Execution Times: CPU time = 1 ms, elapsed time = 2 ms.'
    , @EvidenzDatenschutzModus = 'DERIVED_ONLY'
    , @ResultSetArt = 'NONE'
    , @Json = @EvidenceJson OUTPUT;
```

## Resultsets und Leserichtung

`captureStatus` beschreibt Umfang, Partialität und Datenschutzmodus. Danach folgen `statisticsIo`, `statisticsTime`, `planStatisticsUsage`, `objectReferences`, optionale aktuelle Statistiken und Histogramme, Predicate-Mappings, Collection-Status und Warnings. TABLE exportiert ausschließlich ausdrücklich benannte Ziele.

## Eine Zeile bedeutet

Die Granularität hängt vom Resultset ab: eine Capture-Zusammenfassung, eine IO-Objektzeile, ein TIME-Block, eine verwendete Statistik, eine Objektreferenz, ein Histogrammschritt oder eine Mappingbeziehung. Diese Zeilen dürfen nicht ohne Statement- und Quellenbezug zusammengeführt werden.

## So lesen

Zuerst `captureStatus`, `SameExecutionConfidence` und ParseStatus prüfen. Danach IO und TIME auf Statementebene lesen. Statistik- und Histogrammevidenz erst mit Compilezeit, Capturezeit und Datenschutzstatus bewerten.

## Warum kann das problematisch sein?

Ohne ein gemeinsames Evidenzformat werden Planoperatoren, objektbezogene Reads und Gesamtlaufzeit leicht aus unterschiedlichen Ausführungen vermischt. Rohwerte können außerdem vertrauliche Geschäftsdaten enthalten.

## Wann ist es kein Problem?

Fehlende optionale Statistik- oder Histogrammabschnitte sind im Standardpfad normal. Für viele Planfragen reichen Operator- und Runtime-Counter aus. `NULL` bedeutet unbekannt oder nicht erhoben und nicht gemessene Null.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche zusätzliche Ausführungsevidenz ist vorhanden, wie sicher ist ihre Zuordnung und welche Werte dürfen exportiert werden?

### Technischer Hintergrund

`SET STATISTICS IO` und `SET STATISTICS TIME` liefern Meldungstext, kein relationales Resultset. Die Parser sind deshalb best effort und markieren unbekannte oder partielle Formate. Histogrammgrenzwerte und Parameterwerte werden erst nach lokaler Korrelation entfernt oder tokenisiert.

### Datenkette

Bereits übergebenes Showplan XML, `TVF_ParseStatisticsIoText`, `TVF_ParseStatisticsTimeText`, Plan-Extractor-Funktionen und optional gezielte Statistik-/Histogrammmetadaten.

### Zeit- und Scope-Modell

Jeder Abschnitt besitzt einen eigenen Capture- oder Compilezeitbezug. Aktuelle Statistics Properties sind nicht rückwirkend der Compilezustand.

### Bewertung und Gegenprobe

Same-Execution-Status, Statementzuordnung, Planhash, Capturezeit und Parameterkontext gemeinsam prüfen. Bei importierter Evidenz die Quellumgebung ausdrücklich bestätigen.

### Typische Fehlinterpretation

Ein geparster Textblock ist nicht automatisch derselben Planexecution zugeordnet. Ein tokenisierter oder ausgelassener Wert ist auch kein SQL-NULL.

### Folgeanalyse

`USP_ExecutionPlanAnalysis`, Query Store Runtime/Regression und gezielte Statistikverteilungsanalyse.

## Primärquellen

- [SET STATISTICS IO](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statistics-io-transact-sql?view=sql-server-ver17)
- [SET STATISTICS TIME](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statistics-time-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../04_Plan_Cache.md#execution-evidence-json)
'''
analysis_page = r'''# [monitor].[USP_ExecutionPlanAnalysis]

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

Direktes Showplan XML oder gezielte Quellen `sys.dm_exec_query_plan`, `sys.dm_exec_query_plan_stats`, `sys.dm_exec_query_statistics_xml` beziehungsweise `sys.query_store_plan`; optional Evidence JSON.

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
'''
write("Documentation/Analysis_Guides/Procedures/USP_CreateExecutionEvidenceJson.md", evidence_page)
write("Documentation/Analysis_Guides/Procedures/USP_ExecutionPlanAnalysis.md", analysis_page)

# 8. Index and family documentation.
object_index_path = "Documentation/Analysis_Guides/Object_Index.md"
object_index = read(object_index_path)
object_rows_md = """| `[monitor].[USP_CreateExecutionEvidenceJson]` | [Normalisierte IO-, TIME-, Statistik- und Histogrammevidenz](Procedures/USP_CreateExecutionEvidenceJson.md) |
| `[monitor].[USP_ExecutionPlanAnalysis]` | [Eigenständige statement- und operatorbezogene Plananalyse](Procedures/USP_ExecutionPlanAnalysis.md) |
"""
object_index = insert_before(object_index, "| `[monitor].[USP_ShowplanAnalysis]`", object_rows_md)
object_index = re.sub(r"\*\*Abdeckung:\*\* alle \d+ Procedures", "**Abdeckung:** alle 87 Procedures", object_index)
write(object_index_path, object_index)

procedures_readme = "Documentation/Analysis_Guides/Procedures/README.md"
append_once(procedures_readme, "USP_CreateExecutionEvidenceJson.md", """
- [`USP_CreateExecutionEvidenceJson`](USP_CreateExecutionEvidenceJson.md) – normalisierte Execution Evidence mit Datenschutzstatus.
- [`USP_ExecutionPlanAnalysis`](USP_ExecutionPlanAnalysis.md) – eigenständig installierbare Analyse eines Showplan-XML.
""")

append_once("Documentation/Analysis_Guides/04_Plan_Cache.md", "## Standalone Execution Plan Analysis", r'''
## Standalone Execution Plan Analysis

`monitor.USP_ExecutionPlanAnalysis` analysiert genau ein Plan-XML ohne zwingenden Plan-Cache- oder Query-Store-Zugriff. Die technische Identität lautet `AnalysisObjectId + StatementOrdinal + NodeId`; gleiche NodeIds verschiedener Statements bleiben getrennt. Compile- und Runtimewerte werden nicht vermischt, fehlende Capabilities bleiben `NULL` mit Status.

## Execution Evidence JSON

`monitor.USP_CreateExecutionEvidenceJson` normalisiert bereits erfasste `SET STATISTICS IO`-/`TIME`-Meldungen sowie optionale Statistik- und Histogrammevidenz. `DERIVED_ONLY` ist der Datenschutzdefault: konkrete Histogrammgrenzen, Parameter und Predicatewerte werden nach lokaler Korrelation nicht exportiert. Predicate-Histogramm-Mappings erhalten StepOrdinal und Mappingstatus, sodass Verteilungsbeziehungen ohne fachliche Rohwerte analysierbar bleiben.
''')

append_once("Documentation/Reference/Call_Catalog.md", "USP_CreateExecutionEvidenceJson", r'''
## Eigenständige Execution-Plan-Analyse

```sql
EXEC [monitor].[USP_ExecutionPlanAnalysis]
      @PlanXml = @ExamplePlanXml
    , @EvidenzDatenschutzModus = 'DERIVED_ONLY'
    , @ResultSetArt = 'CONSOLE';

DECLARE @EvidenceJson nvarchar(max);
EXEC [monitor].[USP_CreateExecutionEvidenceJson]
      @StatisticsIoText = @ExampleStatisticsIoText
    , @StatisticsTimeText = @ExampleStatisticsTimeText
    , @ResultSetArt = 'NONE'
    , @Json = @EvidenceJson OUTPUT;
```
''')

# 9. Documentation review contract.
review_rows = [
    ["USP_CreateExecutionEvidenceJson", "BASELINE", "", "1"],
    ["USP_ExecutionPlanAnalysis", "BASELINE", "", "1"],
]
replace_csv_rows("Metadata/Quality/Analysis_Documentation_Review.csv", (0,), review_rows)

# 10. Installer and release-gate documentation.
append_once("Code/Install/README.md", "Install_ExecutionPlanAnalysis.sql", r'''
## Eigenständige Execution-Plan-Analyse

`Install_ExecutionPlanAnalysis.sql` installiert nur die für die direkte Plan- und Evidenzanalyse erforderlichen Objekte. Mit `Build-ExecutionPlanAnalysisInstaller.ps1` kann daraus ein vollständig eingebettetes SSMS-Artefakt `Install_ExecutionPlanAnalysis.generated.sql` erzeugt werden. Der Teilinstaller installiert nicht die übrigen Analysefamilien und kann idempotent neben einer vollständigen Frameworkinstallation ausgeführt werden.
''')
append_once("Documentation/Reference/Installation.md", "Install_ExecutionPlanAnalysis.sql", r'''
## Teilinstallation der Execution-Plan-Analyse

Für eine eigenständig nutzbare Plananalyse verwenden Sie `Code/Install/Install_ExecutionPlanAnalysis.sql` im SQLCMD-Modus. Alternativ erzeugt `Code/Install/Build-ExecutionPlanAnalysisInstaller.ps1` einen vollständig eingebetteten Installer. Verfügbar sind danach mindestens `monitor.USP_ExecutionPlanAnalysis` und `monitor.USP_CreateExecutionEvidenceJson`; Query Store, Current State, Extended Events und Server Health werden nicht mitinstalliert.
''')
append_once("Code/Examples/040_Schnellreferenz_Aufrufe.sql", "USP_ExecutionPlanAnalysis", r'''

-- Eigenständige Plananalyse: Signatur und sichere Modi anzeigen.
EXEC [monitor].[USP_ExecutionPlanAnalysis] @Hilfe=1;
EXEC [monitor].[USP_CreateExecutionEvidenceJson] @Hilfe=1;
''')
append_once("Code/Examples/041_Beispielaufrufe_Alle_Funktionalitaeten.sql", "USP_CreateExecutionEvidenceJson", r'''

-- PLAN-001: eigenständig installierbare Execution-Plan- und Evidence-Analyse.
EXEC [monitor].[USP_ExecutionPlanAnalysis] @Hilfe=1;
EXEC [monitor].[USP_CreateExecutionEvidenceJson] @Hilfe=1;
''')
append_once("Documentation/Quality/Release_Notes.md", "PLAN-001", r'''
- `PLAN-001`: eigenständig installierbarer Execution-Plan-Kern mit statementgenauer Operatoranalyse, Evidence JSON, Statistik-/Histogrammkorrelation, `DERIVED_ONLY`-Datenschutzdefault und Integration in den Gesamtinstaller; Release-Gate-Evidenz steht noch aus.
''')
append_once("Documentation/Quality/Test_Matrix.md", "ExecutionPlanAnalysis_Runtime_Contract", r'''
## Execution-Plan-Analyse

`PlanCache/120_ExecutionPlanAnalysis_Runtime_Contract.sql` prüft synthetische Mehrstatementpläne, gleiche NodeIds in unterschiedlichen Statements, paarweise ActualRows-/ActualRowsRead-Auswertung, DERIVED_ONLY und IO-/TIME-Parsing. Der Teilinstallervertrag wird zusätzlich durch `Integration/192_ExecutionPlanAnalysis_Installer_Contract.ps1` geprüft. Die Zielmatrix bleibt SQL Server 2019, 2022 und 2025.
''')

# 11. Release-gate and documentation workflow integration.
run_gate_path = "Code/Tests/Run_Release_Gate.sql"
run_gate = read(run_gate_path)
include_line = ":r PlanCache/120_ExecutionPlanAnalysis_Runtime_Contract.sql"
if include_line not in run_gate:
    run_gate = run_gate.replace(":r PlanCache/110_Test_und_Abnahme_Phase3.sql", ":r PlanCache/110_Test_und_Abnahme_Phase3.sql\n" + include_line)
write(run_gate_path, run_gate)

workflow_path = ".github/workflows/documentation-validation.yml"
workflow = read(workflow_path)
if "192_ExecutionPlanAnalysis_Installer_Contract.ps1" not in workflow:
    workflow = workflow.replace("      - 'Code/Tests/Static/996_Validate_Wave2_Contracts.py'", "      - 'Code/Tests/Static/996_Validate_Wave2_Contracts.py'\n      - 'Code/Tests/Integration/192_ExecutionPlanAnalysis_Installer_Contract.ps1'", 1)
    workflow = workflow.replace("      - 'Code/Tests/Static/996_Validate_Wave2_Contracts.py'", "      - 'Code/Tests/Static/996_Validate_Wave2_Contracts.py'\n      - 'Code/Tests/Integration/192_ExecutionPlanAnalysis_Installer_Contract.ps1'", 1)
    anchor = "      - name: Validate procedure documentation\n"
    step = """      - name: Validate Execution Plan Analysis installer contract
        shell: pwsh
        run: pwsh -NoLogo -NoProfile -File ./Code/Tests/Integration/192_ExecutionPlanAnalysis_Installer_Contract.ps1

"""
    workflow = workflow.replace(anchor, step + anchor)
write(workflow_path, workflow)

# 12. Backlog and architecture status.
backlog_path = "Metadata/Quality/Future_Enhancement_Backlog.csv"
backlog = read(backlog_path)
lines = []
for line in backlog.splitlines():
    if line.startswith("PLAN-001,"):
        line = line.replace("RESEARCHED_NOT_IMPLEMENTED", "IMPLEMENTED_PENDING_RELEASE_GATE")
    lines.append(line)
write(backlog_path, "\n".join(lines) + "\n")
for path in [
    "Documentation/Architecture/Execution_Plan_Analysis_Design.md",
    "Documentation/Architecture/Execution_Plan_Analysis_Installation_Contract.md",
]:
    text = read(path).replace("`RESEARCHED_NOT_IMPLEMENTED`", "`IMPLEMENTED_PENDING_RELEASE_GATE`")
    write(path, text)

# 13. Fail early on privacy- or repository-contract regressions in new sources.
for path in (ROOT / "Code/04_PlanCache").glob("0*.sql"):
    if path.name[:3] in {"041", "042", "043", "044", "045", "046", "047", "048", "049", "050", "051", "052", "053"}:
        text = path.read_text(encoding="utf-8")
        if re.search(r"\bOBJECT_ID\s*\(", text, re.IGNORECASE):
            raise RuntimeError(f"Blocking metadata function OBJECT_ID found: {path}")

print("Execution Plan Analysis framework integration completed.")
