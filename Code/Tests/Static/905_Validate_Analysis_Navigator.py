#!/usr/bin/env python3
"""Validate the Analysis Navigator metadata, discovery and documentation contract."""

from __future__ import annotations

import argparse
import csv
import re
import sys
import tempfile
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path


CATALOG_PATH = Path("Code/01_Common/021_VW_AnalysisCatalog.sql")
SEARCH_TERM_PATH = Path("Code/01_Common/022_VW_AnalysisSearchTerm.sql")
RELATION_PATH = Path("Code/01_Common/023_VW_AnalysisRelation.sql")
NAVIGATOR_PATH = Path("Code/01_Common/100_USP_AnalysisNavigator.sql")
ANALYSIS_CLASS_PATH = Path("Code/01_Common/020_VW_AnalyseClassCatalog.sql")
OBJECT_INVENTORY_PATH = Path("Metadata/Inventory/Objects.csv")
PARAMETER_INVENTORY_PATH = Path("Metadata/Inventory/Parameters.csv")
RESULT_SET_INVENTORY_PATH = Path("Metadata/Inventory/ResultSets.csv")
INSTALLER_PATH = Path("Code/Install/Install_All.sql")
PLAN_INSTALLER_PATH = Path("Code/Install/Install_ExecutionPlanAnalysis.sql")
SMOKE_TEST_PATH = Path("Code/Tests/Integration/110_Smoke_Test.sql")
NAVIGATOR_RUNTIME_PATH = Path("Code/Tests/Integration/196_Analysis_Navigator_Runtime_Contract.sql")
INSTALLED_PUBLIC_RUNTIME_PATH = Path("Code/Tests/Integration/189_Framework_Output_Runtime_Contract.sql")

CATALOG_COLUMNS = (
    "ProcedureName",
    "DisplayName",
    "PrimaryAreaCode",
    "PrimaryAreaName",
    "NavigationRole",
    "ScopeCode",
    "EvidenceType",
    "CostRangeCode",
    "RepresentativeAnalysisClass",
    "RequiresKnownTarget",
    "RequiresHighImpactForSafeStart",
    "HighImpactPathAvailable",
    "PackageCode",
    "DefaultRank",
    "Purpose",
    "PrerequisiteSummary",
    "SafeCall",
    "DocumentationPath",
    "RunbookPath",
)

SEARCH_TERM_COLUMNS = (
    "ProcedureName",
    "SearchTerm",
    "LanguageCode",
    "SearchWeight",
    "MatchReason",
)

RELATION_COLUMNS = (
    "FromProcedureName",
    "RelationType",
    "ToProcedureName",
    "RelationPriority",
    "ConditionSummary",
)

ALLOWED_ROLES = {"ENTRY", "FOLLOW_UP", "TARGETED", "SETUP", "SUPPORT"}
ALLOWED_PACKAGES = {"CORE", "CORE_PLAN_STANDALONE", "SNAPSHOT_OPTIONAL"}
ALLOWED_AREAS = {
    "NAVIGATION",
    "FRAMEWORK",
    "LIVE",
    "OBJECT",
    "PLAN",
    "QUERY_STORE",
    "EXTENDED_EVENTS",
    "OPERATIONS",
    "SERVER",
    "SPECIAL_FEATURE",
    "SNAPSHOT",
}
ALLOWED_SCOPES = {
    "FRAMEWORK",
    "SERVER",
    "DATABASE",
    "MULTI_DATABASE",
    "SESSION_REQUEST",
    "OBJECT",
    "QUERY",
    "PLAN_XML",
    "EVENT_SESSION",
    "EVENT_HISTORY",
    "INFRASTRUCTURE",
    "SNAPSHOT_TARGET",
}
ALLOWED_EVIDENCE_TYPES = {
    "FRAMEWORK_METADATA",
    "LIVE_SNAPSHOT",
    "SAMPLE_DELTA",
    "CUMULATIVE_DMV",
    "PERSISTED_HISTORY",
    "EVENT_HISTORY",
    "CATALOG_CONFIGURATION",
    "STATIC_INPUT",
    "MIXED",
    "PERSISTED_SNAPSHOT",
}
ALLOWED_COST_RANGES = {
    "LOW",
    "LOW_MEDIUM",
    "MEDIUM",
    "LOW_HIGH_OPT_IN",
    "MEDIUM_HIGH_OPT_IN",
    "HIGH_OPT_IN",
}
ALLOWED_RELATIONS = {"REFINE_WITH", "CONFIRM_WITH", "ALTERNATIVE_TO", "PREPARE_WITH"}
RELATION_EXEMPT_PROCEDURES = {
    "USP_AnalysisNavigator",
    "USP_PrepareDatabaseCandidates",
    "USP_PrepareNameFilters",
}
HIGH_IMPACT_SAFE_ENTRY_PROCEDURES = {
    "USP_DataCaptureDeepAnalysis",
    "USP_ExtendedEventsBlockedProcesses",
    "USP_ExtendedEventsDeadlocks",
    "USP_ExtendedEventsReadEvents",
    "USP_ExtendedEventsTargetRuntime",
    "USP_FullTextAnalysis",
    "USP_IndexPhysicalStats",
    "USP_IntelligentQueryProcessingAnalysis",
    "USP_PlanDetails",
    "USP_PlanCacheAnalysis",
    "USP_QueryHashAnalysis",
    "USP_SchemaDesignAnalysis",
    "USP_ServiceBrokerAnalysis",
    "USP_StatisticsDistributionAnalysis",
    "USP_TemporalAnalysis",
}

EXPECTED_SEARCH_CASES = {
    "Benutzer warten": "USP_CurrentBlocking",
    "CPU hoch": "USP_CurrentRequests",
    "TempDB wächst": "USP_CurrentTempDB",
    "Log voll": "USP_CurrentLog",
    "Query plötzlich langsamer": "USP_QueryStoreRegressions",
    "Plan XML analysieren": "USP_ExecutionPlanAnalysis",
    "Index ungenutzt": "USP_IndexUsage",
    "AG Lag Redo Queue Send Queue": "USP_AvailabilityDeepAnalysis",
    "Deadlock": "USP_ExtendedEventsDeadlocks",
    "SQL Server Version CU Lifecycle": "USP_ServerVersionInformation",
    "JSON-Index Pfade inventarisieren": "USP_ObjectInventory",
    "JSON-Index Capability Preview": "USP_ServerFeatureCapabilities",
    "TempDB Workload Group Limit Verletzung": "USP_CurrentTempDB",
    "TempDB Resource Governance Wirksamkeit": "USP_ResourceGovernorAnalysis",
    "lesbare Secondary Statistik Replikat Herkunft": "USP_Statistics",
}

PUBLIC_DOCUMENTATION_FORBIDDEN = (
    re.compile(r"AI_Metadata", re.IGNORECASE),
    re.compile(r"Internal_Documentation", re.IGNORECASE),
    re.compile(r"Documentation/(?:Research|Development|Requirements)/", re.IGNORECASE),
    re.compile(r"Analysis_Guides/Authoring", re.IGNORECASE),
    re.compile(r"\bChatGPT\b", re.IGNORECASE),
    re.compile(r"(?<![A-Za-zÄÖÜäöüß])KI(?![A-Za-zÄÖÜäöüß])"),
    re.compile(r"\bEntstehungsnachweis\b", re.IGNORECASE),
    re.compile(r"\bImplementierungswelle\b", re.IGNORECASE),
    re.compile(r"\bImplementierungsweg\b", re.IGNORECASE),
    re.compile(r"\bRedaktions(?:prozess|hinweis|status)\b", re.IGNORECASE),
    re.compile(r"\b[0-9a-f]{40}\b", re.IGNORECASE),
    re.compile(r"\bMigrationsumfang\b", re.IGNORECASE),
    re.compile(r"\bReihenfolge der Einführung\b", re.IGNORECASE),
    re.compile(r"\bvor Beginn der Migration\b", re.IGNORECASE),
)


def normalize_ci_ai(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value)
    without_accents = "".join(char for char in decomposed if not unicodedata.combining(char))
    return re.sub(r"\s+", " ", without_accents.casefold().strip())


def split_top_level(text: str, delimiter: str = ",") -> list[str]:
    values: list[str] = []
    start = 0
    depth = 0
    in_string = False
    index = 0
    while index < len(text):
        char = text[index]
        if in_string:
            if char == "'":
                if index + 1 < len(text) and text[index + 1] == "'":
                    index += 2
                    continue
                in_string = False
        elif char == "'":
            in_string = True
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        elif char == delimiter and depth == 0:
            values.append(text[start:index].strip())
            start = index + 1
        index += 1
    values.append(text[start:].strip())
    return values


def decode_sql_value(value_expression: str) -> str | int | None:
    value_expression = value_expression.strip()
    if value_expression.upper() == "NULL":
        return None
    if re.fullmatch(r"-?[0-9]+", value_expression):
        return int(value_expression)

    cast_match = re.fullmatch(
        r"CAST\s*\(\s*(N?'(?:''|[^'])*)'\s+AS\s+[^)]+\)",
        value_expression,
        re.IGNORECASE | re.DOTALL,
    )
    if cast_match:
        value_expression = cast_match.group(1) + "'"

    string_match = re.fullmatch(r"N?'((?:''|[^'])*)'", value_expression, re.DOTALL)
    if string_match:
        return string_match.group(1).replace("''", "'")
    raise ValueError(f"Unsupported SQL VALUES scalar: {value_expression!r}")


def extract_values_rows(sql_text: str, columns: tuple[str, ...]) -> list[dict[str, str | int | None]]:
    marker = re.search(r"\bFROM\s*\(\s*VALUES\s*", sql_text, re.IGNORECASE | re.DOTALL)
    if not marker:
        raise ValueError("VALUES block marker not found")
    suffix = re.search(r"\)\s+AS\s+\[v\]\s*\(", sql_text[marker.end() :], re.IGNORECASE)
    if not suffix:
        raise ValueError("VALUES block suffix not found")
    block = sql_text[marker.end() : marker.end() + suffix.start()]

    raw_rows: list[str] = []
    index = 0
    while index < len(block):
        while index < len(block) and (block[index].isspace() or block[index] == ","):
            index += 1
        if index >= len(block):
            break
        if block[index] != "(":
            raise ValueError(f"Unexpected character before VALUES row: {block[index:index + 30]!r}")
        row_start = index + 1
        depth = 1
        in_string = False
        index += 1
        while index < len(block) and depth:
            char = block[index]
            if in_string:
                if char == "'":
                    if index + 1 < len(block) and block[index + 1] == "'":
                        index += 2
                        continue
                    in_string = False
            elif char == "'":
                in_string = True
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    raw_rows.append(block[row_start:index])
                    index += 1
                    break
            index += 1
        if depth:
            raise ValueError("Unclosed VALUES row")

    rows: list[dict[str, str | int | None]] = []
    for row_number, raw_row in enumerate(raw_rows, start=1):
        tokens = split_top_level(raw_row)
        if len(tokens) != len(columns):
            raise ValueError(
                f"VALUES row {row_number} has {len(tokens)} fields; expected {len(columns)}"
            )
        rows.append(dict(zip(columns, (decode_sql_value(token) for token in tokens))))
    return rows


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def resolve_sqlcmd_includes(repository_root: Path, installer_path: Path) -> set[str]:
    """Resolve the direct SQLCMD include closure used by Install_All.sql."""
    if not installer_path.is_file():
        raise ValueError(f"Missing SQLCMD installer: {installer_path}")
    includes: set[str] = set()
    for line in installer_path.read_text(encoding="utf-8-sig").splitlines():
        match = re.fullmatch(r"\s*:r\s+([^\s]+)\s*", line, re.IGNORECASE)
        if not match:
            if line.lstrip().casefold().startswith(":r"):
                raise ValueError(f"Unsupported SQLCMD include form: {line.strip()}")
            continue
        include = (installer_path.parent / match.group(1).replace("\\", "/")).resolve()
        try:
            relative = include.relative_to(repository_root.resolve()).as_posix()
        except ValueError as exc:
            raise ValueError(f"SQLCMD include escapes repository: {match.group(1)}") from exc
        if not include.is_file():
            raise ValueError(f"SQLCMD include does not exist: {relative}")
        included_sql = strip_sql_comments_and_literals(
            include.read_text(encoding="utf-8-sig")
        )
        if re.search(r"^\s*:r(?:\s|$)", included_sql, re.IGNORECASE | re.MULTILINE):
            raise ValueError(f"Nested SQLCMD include is unsupported: {relative}")
        if relative in includes:
            raise ValueError(f"Duplicate SQLCMD include: {relative}")
        includes.add(relative)
    if not includes:
        raise ValueError(f"SQLCMD installer has no includes: {installer_path}")
    return includes


def derive_procedure_populations(
    object_rows: list[dict[str, str]], included_sources: set[str]
) -> tuple[int, int]:
    """Return catalog procedures and installed public procedures from inventory/closure."""
    procedures = [row for row in object_rows if row["ObjectType"] == "PROCEDURE"]
    installed_public = [
        row
        for row in procedures
        if row["SourcePath"] in included_sources
        and not row["ObjectName"].startswith("Internal")
        and not row["ObjectName"].startswith("USP_Prepare")
    ]
    return len(procedures), len(installed_public)


def validate_native_count_bindings(
    repository_root: Path, catalog_count: int, installed_public_count: int
) -> list[str]:
    errors: list[str] = []
    loaded: dict[Path, str] = {}
    for relative_path in (SMOKE_TEST_PATH, NAVIGATOR_RUNTIME_PATH, INSTALLED_PUBLIC_RUNTIME_PATH):
        path = repository_root / relative_path
        if not path.is_file():
            errors.append(f"Missing native count contract: {relative_path}")
            continue
        loaded[relative_path] = path.read_text(encoding="utf-8-sig")

    checks = (
        (SMOKE_TEST_PATH, "Smoke test catalog assertion", r"COUNT_BIG\s*\(\s*\*\s*\)\s*FROM\s*\[monitor\]\.\[VW_AnalysisCatalog\]\s*\)\s*<>\s*(\d+)", catalog_count),
        (NAVIGATOR_RUNTIME_PATH, "Navigator runtime catalog assertion", r"COUNT_BIG\s*\(\s*\*\s*\)\s*FROM\s*\[monitor\]\.\[VW_AnalysisCatalog\]\s*\)\s*<>\s*(\d+)", catalog_count),
        (INSTALLED_PUBLIC_RUNTIME_PATH, "Installed public procedure assertion", r"COUNT\s*\(\s*\*\s*\)\s*FROM\s*\[#FrameworkOutputRuntimeContract_Public\]\s*\)\s*<>\s*(\d+)", installed_public_count),
    )
    for relative_path, label, pattern, expected in checks:
        text = loaded.get(relative_path)
        if text is None:
            continue
        matches = list(re.finditer(pattern, text, re.IGNORECASE | re.DOTALL))
        if len(matches) != 1:
            errors.append(f"{label} has {len(matches)} matching assertions; expected exactly one.")
        elif int(matches[0].group(1)) != expected:
            errors.append(
                f"{label} is {matches[0].group(1)}; inventory/installer closure requires {expected}."
            )
        message_patterns = {
            SMOKE_TEST_PATH: r"THROW\s+54025\s*,\s*N'([^']*)'",
            NAVIGATOR_RUNTIME_PATH: r"VALUES\s*\(\s*N'CATALOG_COUNT'\s*,\s*N'([^']*)'",
            INSTALLED_PUBLIC_RUNTIME_PATH: r"VALUES\s*\(\s*N'PUBLIC_INVENTORY'\s*,\s*N'([^']*)'",
        }
        message_matches = list(
            re.finditer(message_patterns[relative_path], text, re.IGNORECASE)
        )
        if len(message_matches) != 1:
            errors.append(f"{label} has {len(message_matches)} matching messages; expected exactly one.")
        elif re.search(rf"\b{expected}\b", message_matches[0].group(1)) is None:
            errors.append(f"{label} message does not report expected count {expected}.")

    runtime_text = loaded.get(NAVIGATOR_RUNTIME_PATH)
    if runtime_text is not None:
        reported_matches = list(
            re.finditer(
                r"CAST\s*\(\s*(\d+)\s+AS\s+int\s*\)\s+AS\s+\[CatalogProcedureCount\]",
                runtime_text,
                re.IGNORECASE,
            )
        )
        if len(reported_matches) != 1:
            errors.append(
                f"Navigator CatalogProcedureCount has {len(reported_matches)} matching outputs; expected exactly one."
            )
        elif int(reported_matches[0].group(1)) != catalog_count:
            errors.append(
                f"Navigator reported CatalogProcedureCount is {reported_matches[0].group(1)}; inventory requires {catalog_count}."
            )

    installed_text = loaded.get(INSTALLED_PUBLIC_RUNTIME_PATH)
    if installed_text is not None:
        message_matches = list(
            re.finditer(
                r"N'[^']*?\b(\d+)\s+Vertragsobjekte\b[^']*'",
                installed_text,
                re.IGNORECASE,
            )
        )
        if len(message_matches) != 1:
            errors.append(
                f"Installed public procedure failure message has {len(message_matches)} matching literals; expected exactly one."
            )
        elif int(message_matches[0].group(1)) != installed_public_count:
            errors.append(
                f"Installed public procedure failure message reports {message_matches[0].group(1)}; installer closure requires {installed_public_count}."
            )
    return errors


def strip_sql_comments_and_literals(sql_text: str) -> str:
    text = re.sub(r"/\*.*?\*/", " ", sql_text, flags=re.DOTALL)
    text = re.sub(r"--[^\r\n]*", " ", text)
    return re.sub(r"N?'(?:''|[^'])*'", "''", text, flags=re.DOTALL)



MODULE_OBJECT_TYPES = {"PROCEDURE"}


def strip_sql_comments_preserving_literals(sql_text: str) -> str:
    """Remove SQL comments while retaining string literals used in defaults."""
    output: list[str] = []
    index = 0
    in_string = False
    while index < len(sql_text):
        if in_string:
            output.append(sql_text[index])
            if sql_text[index] == "'":
                if index + 1 < len(sql_text) and sql_text[index + 1] == "'":
                    output.append(sql_text[index + 1]); index += 2; continue
                in_string = False
            index += 1; continue
        if sql_text[index] == "'":
            in_string = True; output.append(sql_text[index]); index += 1
        elif sql_text.startswith("--", index):
            newline = sql_text.find("\n", index)
            if newline < 0: break
            output.append("\n"); index = newline + 1
        elif sql_text.startswith("/*", index):
            end = sql_text.find("*/", index + 2)
            if end < 0: raise ValueError("Unclosed SQL block comment in module declaration")
            output.extend("\n" for char in sql_text[index:end + 2] if char == "\n"); index = end + 2
        else:
            output.append(sql_text[index]); index += 1
    return "".join(output)


def normalize_sql_expression(value: str) -> str:
    """Collapse insignificant whitespace but preserve quoted literal contents."""
    result: list[str] = []; index = 0; in_string = False; pending_space = False
    while index < len(value):
        char = value[index]
        if in_string:
            result.append(char)
            if char == "'":
                if index + 1 < len(value) and value[index + 1] == "'":
                    result.append(value[index + 1]); index += 2; continue
                in_string = False
            index += 1; continue
        if char == "'":
            if pending_space and result: result.append(" ")
            pending_space = False; in_string = True; result.append(char)
        elif char.isspace(): pending_space = True
        else:
            if pending_space and result: result.append(" ")
            pending_space = False; result.append(char)
        index += 1
    return "".join(result).strip()


def find_top_level_equals(text: str) -> int:
    depth = 0; in_string = False; index = 0
    while index < len(text):
        char = text[index]
        if in_string:
            if char == "'":
                if index + 1 < len(text) and text[index + 1] == "'": index += 2; continue
                in_string = False
        elif char == "'": in_string = True
        elif char == "(": depth += 1
        elif char == ")": depth -= 1
        elif char == "=" and depth == 0: return index
        index += 1
    return -1


def parse_parameter_declaration(declaration: str) -> tuple[str, str, str] | None:
    """Return exact name, type, and inventory-form default/direction for one declaration."""
    text = normalize_sql_expression(declaration.strip().rstrip(","))
    name_match = re.match(r"(@[A-Za-z_][A-Za-z0-9_]*)\b", text)
    if not name_match: return None
    name = name_match.group(1)[1:]; remainder = text[name_match.end():].strip()
    equals = find_top_level_equals(remainder)
    has_default = equals >= 0
    if has_default: data_type, default = remainder[:equals].strip(), remainder[equals + 1:].strip()
    else: data_type, default = remainder, ""
    output = False
    if equals >= 0:
        output = bool(re.search(r"\s+(?:OUTPUT|OUT)\s*$", default, re.IGNORECASE))
        if output: default = re.sub(r"\s+(?:OUTPUT|OUT)\s*$", "", default, flags=re.IGNORECASE).strip()
    else:
        output = bool(re.search(r"\s+(?:OUTPUT|OUT)\s*$", data_type, re.IGNORECASE))
        if output: data_type = re.sub(r"\s+(?:OUTPUT|OUT)\s*$", "", data_type, flags=re.IGNORECASE).strip()
    if not data_type: return None
    inventory_default = normalize_sql_expression(default) if has_default else ""
    if output:
        inventory_default = (inventory_default + " OUTPUT").strip() if has_default else "OUTPUT"
    return name, normalize_sql_expression(data_type), inventory_default


def extract_module_parameters(source_text: str, object_name: str) -> list[tuple[str, str, str]]:
    """Extract parameters from one public procedure declaration."""
    cleaned = strip_sql_comments_preserving_literals(source_text)
    marker = rf"(?ims)^\s*CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[monitor\]\.\[([A-Za-z_][A-Za-z0-9_]*)\](.*?)(?=^\s*AS\s*$)"
    match = re.search(marker, cleaned)
    if not match:
        raise ValueError(f"procedure declaration not found for {object_name}")
    declared_name = match.group(1)
    if declared_name != object_name:
        raise ValueError(f"case-sensitive object name differs from Objects.csv for {object_name}: {declared_name}")
    raw_parameters = match.group(2).strip()
    if not raw_parameters:
        return []
    parsed = [parse_parameter_declaration(item) for item in split_top_level(raw_parameters)]
    if any(item is None for item in parsed):
        raise ValueError(f"unsupported parameter declaration for {object_name}")
    return [item for item in parsed if item is not None]

def compare_parameter_inventory(object_rows: list[dict[str, str]], parameter_rows: list[dict[str, str]], read_source) -> list[str]:
    """Compare every inventoried SQL module signature with the ordered CSV rows."""
    errors: list[str] = []
    modules = [row for row in object_rows if row.get("ObjectType") in MODULE_OBJECT_TYPES]
    module_names = [row["ObjectName"] for row in modules]
    if len(module_names) != len(set(module_names)): errors.append("Objects.csv contains duplicate procedure/function names for parameter parity.")
    module_by_name = {row["ObjectName"]: row for row in modules}; rows_by_module: dict[str, list[dict[str, str]]] = defaultdict(list); seen: set[tuple[str, str]] = set()
    for row in parameter_rows:
        module_name = row.get("ProcedureName", ""); parameter_name = row.get("ParameterName", ""); key = (module_name, parameter_name)
        if key in seen: errors.append(f"Duplicate Parameters.csv key: {module_name}/@{parameter_name}")
        seen.add(key)
        if module_name not in module_by_name: errors.append(f"Parameters.csv references a non-module inventory object: {module_name}/@{parameter_name}")
        rows_by_module[module_name].append(row)
    for module_name, object_row in module_by_name.items():
        try: source_parameters = extract_module_parameters(read_source(object_row["SourcePath"]), module_name)
        except (OSError, ValueError) as exc:
            errors.append(f"Cannot read SQL parameter signature for {module_name}: {exc}"); continue
        inventory_parameters = rows_by_module.get(module_name, [])
        if len(source_parameters) != len(inventory_parameters):
            errors.append(f"Parameter count differs between SQL source and Parameters.csv for {module_name}: source={len(source_parameters)}, inventory={len(inventory_parameters)}")
        for index in range(max(len(source_parameters), len(inventory_parameters))):
            source = source_parameters[index] if index < len(source_parameters) else None
            inventory = inventory_parameters[index] if index < len(inventory_parameters) else None
            if source is None:
                errors.append(f"Extra Parameters.csv row for {module_name}/@{inventory['ParameterName']}"); continue
            if inventory is None:
                errors.append(f"Missing Parameters.csv row for {module_name}/@{source[0]}"); continue
            source_name, source_type, source_default = source; inventory_name = inventory.get("ParameterName", "")
            if source_name != inventory_name: errors.append(f"Parameter name/order differs for {module_name} position {index + 1}: source=@{source_name}, inventory=@{inventory_name}")
            if normalize_sql_expression(source_type) != normalize_sql_expression(inventory.get("DataType", "")): errors.append(f"Parameter type differs for {module_name}/@{source_name}")
            if normalize_sql_expression(source_default) != normalize_sql_expression(inventory.get("DefaultExpression", "")): errors.append(f"Parameter default/direction differs for {module_name}/@{source_name}")
    return errors


def validate(repository_root: Path) -> list[str]:
    errors: list[str] = []

    required_paths = (
        CATALOG_PATH,
        SEARCH_TERM_PATH,
        RELATION_PATH,
        NAVIGATOR_PATH,
        ANALYSIS_CLASS_PATH,
        OBJECT_INVENTORY_PATH,
        PARAMETER_INVENTORY_PATH,
        RESULT_SET_INVENTORY_PATH,
        INSTALLER_PATH,
        PLAN_INSTALLER_PATH,
        Path("Documentation/Analysis_Guides/Start_Here.md"),
        Path("Documentation/Reference/Analysis_Navigator.md"),
        Path("Documentation/Analysis_Guides/Procedures/USP_AnalysisNavigator.md"),
    )
    for relative_path in required_paths:
        if not (repository_root / relative_path).is_file():
            errors.append(f"Missing Analysis Navigator contract file: {relative_path}")
    if errors:
        return errors

    try:
        catalog_rows = extract_values_rows(
            (repository_root / CATALOG_PATH).read_text(encoding="utf-8-sig"),
            CATALOG_COLUMNS,
        )
        term_rows = extract_values_rows(
            (repository_root / SEARCH_TERM_PATH).read_text(encoding="utf-8-sig"),
            SEARCH_TERM_COLUMNS,
        )
        relation_rows = extract_values_rows(
            (repository_root / RELATION_PATH).read_text(encoding="utf-8-sig"),
            RELATION_COLUMNS,
        )
    except ValueError as exc:
        return [f"Analysis Navigator metadata cannot be parsed: {exc}"]

    object_rows = read_csv(repository_root / OBJECT_INVENTORY_PATH)
    public_rows = [row for row in object_rows if row["ObjectType"] == "PROCEDURE"]
    try:
        included_sources = resolve_sqlcmd_includes(repository_root, repository_root / INSTALLER_PATH)
        catalog_count, installed_public_count = derive_procedure_populations(
            object_rows, included_sources
        )
        errors.extend(
            validate_native_count_bindings(repository_root, catalog_count, installed_public_count)
        )
    except (OSError, UnicodeError, ValueError) as exc:
        errors.append(f"Native procedure counts cannot be bound to inventory/installer closure: {exc}")
    public_procedures = {row["ObjectName"] for row in public_rows}
    catalog_names = [str(row["ProcedureName"]) for row in catalog_rows]
    catalog_procedures = set(catalog_names)

    if len(public_rows) != 121:
        errors.append(f"Public procedure inventory has {len(public_rows)} rows; expected 121.")
    if len(catalog_rows) != len(public_rows):
        errors.append(
            f"Analysis catalog has {len(catalog_rows)} rows; public inventory has {len(public_rows)}."
        )
    duplicate_catalog_names = sorted(
        name for name, count in Counter(catalog_names).items() if count != 1
    )
    if duplicate_catalog_names:
        errors.append("Duplicate catalog procedures: " + ", ".join(duplicate_catalog_names))
    missing_catalog = sorted(public_procedures - catalog_procedures)
    extra_catalog = sorted(catalog_procedures - public_procedures)
    if missing_catalog:
        errors.append("Public procedures missing from catalog: " + ", ".join(missing_catalog))
    if extra_catalog:
        errors.append("Catalog procedures absent from inventory: " + ", ".join(extra_catalog))

    class_text = (repository_root / ANALYSIS_CLASS_PATH).read_text(encoding="utf-8-sig")
    analysis_classes = set(
        re.findall(r"CAST\('([A-Z0-9_]+)'\s+AS\s+varchar\(64\)\)", class_text, re.IGNORECASE)
    )
    default_ranks: list[int] = []
    for row in catalog_rows:
        procedure = str(row["ProcedureName"])
        role = str(row["NavigationRole"])
        package = str(row["PackageCode"])
        cost = str(row["CostRangeCode"])
        area = str(row["PrimaryAreaCode"])
        scope = str(row["ScopeCode"])
        evidence_type = str(row["EvidenceType"])
        representative_class = row["RepresentativeAnalysisClass"]
        if role not in ALLOWED_ROLES:
            errors.append(f"Unknown navigation role for {procedure}: {role}")
        if package not in ALLOWED_PACKAGES:
            errors.append(f"Unknown package for {procedure}: {package}")
        if area not in ALLOWED_AREAS:
            errors.append(f"Unknown primary area for {procedure}: {area}")
        if scope not in ALLOWED_SCOPES:
            errors.append(f"Unknown scope for {procedure}: {scope}")
        if evidence_type not in ALLOWED_EVIDENCE_TYPES:
            errors.append(f"Unknown evidence type for {procedure}: {evidence_type}")
        if cost not in ALLOWED_COST_RANGES:
            errors.append(f"Unknown cost range for {procedure}: {cost}")
        if representative_class is not None and representative_class not in analysis_classes:
            errors.append(
                f"Unknown RepresentativeAnalysisClass for {procedure}: {representative_class}"
            )
        for bit_column in (
            "RequiresKnownTarget",
            "RequiresHighImpactForSafeStart",
            "HighImpactPathAvailable",
        ):
            if row[bit_column] not in (0, 1):
                errors.append(f"{procedure}.{bit_column} is not a bit literal.")
        if row["RequiresHighImpactForSafeStart"] == 1 and row["HighImpactPathAvailable"] != 1:
            errors.append(f"{procedure} requires High Impact but does not expose a High-Impact path.")
        expected_safe_high_impact = procedure in HIGH_IMPACT_SAFE_ENTRY_PROCEDURES
        if bool(row["RequiresHighImpactForSafeStart"]) != expected_safe_high_impact:
            errors.append(f"High-Impact safe-entry classification differs for {procedure}.")
        if bool(row["HighImpactPathAvailable"]) != ("HIGH" in cost):
            errors.append(f"High-Impact path flag and cost range differ for {procedure}.")
        if not str(row["DisplayName"] or "").strip():
            errors.append(f"Missing display name: {procedure}")
        if not str(row["Purpose"] or "").strip():
            errors.append(f"Missing purpose: {procedure}")
        if not str(row["PrerequisiteSummary"] or "").strip():
            errors.append(f"Missing prerequisite summary: {procedure}")
        safe_call = str(row["SafeCall"] or "")
        if role == "SUPPORT":
            if "[monitor].[USP_AnalysisNavigator]" not in safe_call:
                errors.append(f"Support SafeCall does not route through the Navigator: {procedure}")
        elif f"[monitor].[{procedure}]" not in safe_call:
            errors.append(f"SafeCall does not reference its procedure: {procedure}")

        documentation_path = Path(str(row["DocumentationPath"] or ""))
        if not documentation_path.as_posix().startswith(
            "Documentation/Analysis_Guides/Procedures/"
        ) or not (repository_root / documentation_path).is_file():
            errors.append(f"Invalid documentation path for {procedure}: {documentation_path}")
        runbook_value = row["RunbookPath"]
        if runbook_value is not None and not (repository_root / str(runbook_value)).is_file():
            errors.append(f"Invalid runbook path for {procedure}: {runbook_value}")

        rank = row["DefaultRank"]
        if rank is not None:
            if not isinstance(rank, int) or rank < 1:
                errors.append(f"Invalid DefaultRank for {procedure}: {rank}")
            else:
                default_ranks.append(rank)

    if sorted(default_ranks) != list(range(1, 17)):
        errors.append("DefaultRank must be unique and contiguous from 1 through 16.")

    term_names = [str(row["ProcedureName"]) for row in term_rows]
    term_procedures = set(term_names)
    if term_procedures != public_procedures:
        missing = sorted(public_procedures - term_procedures)
        extra = sorted(term_procedures - public_procedures)
        if missing:
            errors.append("Procedures without search terms: " + ", ".join(missing))
        if extra:
            errors.append("Search terms reference unknown procedures: " + ", ".join(extra))

    terms_by_procedure: dict[str, list[dict[str, str | int | None]]] = defaultdict(list)
    normalized_term_keys: Counter[tuple[str, str]] = Counter()
    exact_term_targets: dict[str, list[tuple[int, str]]] = defaultdict(list)
    for row in term_rows:
        procedure = str(row["ProcedureName"])
        language = str(row["LanguageCode"])
        term = str(row["SearchTerm"] or "")
        weight = row["SearchWeight"]
        terms_by_procedure[procedure].append(row)
        if language not in {"de", "en"}:
            errors.append(f"Invalid language for {procedure}: {language}")
        if not isinstance(weight, int) or not 1 <= weight <= 100:
            errors.append(f"Invalid search weight for {procedure}/{term}: {weight}")
            weight = 0
        if not term.strip() or not str(row["MatchReason"] or "").strip():
            errors.append(f"Incomplete search term metadata for {procedure}.")
        normalized = normalize_ci_ai(term)
        normalized_term_keys[(procedure, normalized)] += 1
        exact_term_targets[normalized].append((int(weight), procedure))

    duplicates = [key for key, count in normalized_term_keys.items() if count > 1]
    if duplicates:
        errors.append(
            "Duplicate CI/AI search terms: "
            + ", ".join(f"{procedure}/{term}" for procedure, term in duplicates)
        )
    for procedure in sorted(public_procedures):
        procedure_terms = terms_by_procedure.get(procedure, [])
        languages = {str(row["LanguageCode"]) for row in procedure_terms}
        if len(procedure_terms) < 2 or languages != {"de", "en"}:
            errors.append(f"{procedure} requires at least one German and one English search term.")

    for search_term, expected_procedure in EXPECTED_SEARCH_CASES.items():
        matches = exact_term_targets.get(normalize_ci_ai(search_term), [])
        if not matches:
            errors.append(f"Missing canonical search case: {search_term}")
            continue
        top_weight = max(weight for weight, _procedure in matches)
        top_targets = sorted(procedure for weight, procedure in matches if weight == top_weight)
        if top_targets != [expected_procedure]:
            errors.append(
                f"Canonical search case {search_term!r} resolves to {top_targets}, "
                f"expected {expected_procedure}."
            )

    relation_keys: Counter[tuple[str, str, str]] = Counter()
    relation_priorities: Counter[tuple[str, str, int]] = Counter()
    relation_sources: set[str] = set()
    for row in relation_rows:
        source = str(row["FromProcedureName"])
        target = str(row["ToProcedureName"])
        relation_type = str(row["RelationType"])
        priority = row["RelationPriority"]
        relation_sources.add(source)
        relation_keys[(source, relation_type, target)] += 1
        if source not in public_procedures or target not in public_procedures:
            errors.append(f"Relation has unknown endpoint: {source} -> {target}")
        if source == target:
            errors.append(f"Self relation is not allowed: {source}")
        if relation_type not in ALLOWED_RELATIONS:
            errors.append(f"Unknown relation type: {relation_type}")
        if not isinstance(priority, int) or not 1 <= priority <= 255:
            errors.append(f"Invalid relation priority: {source}/{relation_type}/{priority}")
        else:
            relation_priorities[(source, relation_type, priority)] += 1
        if not str(row["ConditionSummary"] or "").strip():
            errors.append(f"Missing relation condition: {source} -> {target}")

    duplicate_relations = [key for key, count in relation_keys.items() if count > 1]
    if duplicate_relations:
        errors.append("Duplicate analysis relations: " + ", ".join(map(str, duplicate_relations)))
    duplicate_priorities = [key for key, count in relation_priorities.items() if count > 1]
    if duplicate_priorities:
        errors.append(
            "Duplicate relation priorities per source/type: " + ", ".join(map(str, duplicate_priorities))
        )
    expected_relation_sources = public_procedures - RELATION_EXEMPT_PROCEDURES
    if relation_sources != expected_relation_sources:
        missing = sorted(expected_relation_sources - relation_sources)
        extra = sorted(relation_sources - expected_relation_sources)
        if missing:
            errors.append("Procedures without a next-step relation: " + ", ".join(missing))
        if extra:
            errors.append("Unexpected relation sources: " + ", ".join(extra))

    navigator_text = (repository_root / NAVIGATOR_PATH).read_text(encoding="utf-8-sig")
    executable_navigator = strip_sql_comments_and_literals(navigator_text)
    required_fragments = (
        "Latin1_General_100_CI_AI",
        "[monitor].[VW_AnalysisCatalog]",
        "[monitor].[VW_AnalysisSearchTerm]",
        "[monitor].[VW_AnalysisRelation]",
        "[monitor].[VW_AnalyseClassCatalog]",
        "[c].[ProcedureName] <> N'USP_AnalysisNavigator'",
        "@NurInstallierte",
        "@ResultSetArt",
        "@JsonErzeugen",
        "@MaxZeilen IS NULL OR @MaxZeilen = 0 THEN 2147483647",
        "TOP (@MaxZeilenEffektiv)",
        "COLLATE Latin1_General_100_CI_AI",
    )
    for fragment in required_fragments:
        if fragment not in navigator_text:
            errors.append(f"Navigator source is missing contract fragment: {fragment}")
    for forbidden_source in ("sys.dm_", "sys.query_store_", "fn_xe_file_target_read_file", "sp_executesql"):
        if forbidden_source.casefold() in executable_navigator.casefold():
            errors.append(f"Navigator executes a diagnostic/runtime source: {forbidden_source}")
    executable_calls = re.findall(
        r"\bEXEC(?:UTE)?\s+\[monitor\]\.\[([A-Za-z0-9_]+)\]",
        executable_navigator,
        re.IGNORECASE,
    )
    allowed_helper_calls = {
        "internalpreparesingleresulttable",
        "internalemitconsoleresult",
        "internalwriteresulttable",
    }
    unexpected_calls = sorted(
        {call for call in executable_calls if call.casefold() not in allowed_helper_calls}
    )
    if unexpected_calls:
        errors.append("Navigator executes non-renderer procedures: " + ", ".join(unexpected_calls))

    parameter_rows = read_csv(repository_root / PARAMETER_INVENTORY_PATH)
    errors.extend(
        compare_parameter_inventory(
            object_rows,
            parameter_rows,
            lambda source_path: (repository_root / source_path).read_text(encoding="utf-8-sig"),
        )
    )
    parameters_by_procedure: dict[str, set[str]] = defaultdict(set)
    for parameter_row in parameter_rows:
        parameters_by_procedure[parameter_row["ProcedureName"]].add(parameter_row["ParameterName"])

    for row in catalog_rows:
        procedure = str(row["ProcedureName"])
        safe_call = str(row["SafeCall"] or "")
        call_match = re.search(
            r"\bEXEC(?:UTE)?\s+\[monitor\]\.\[([A-Za-z0-9_]+)\]",
            safe_call,
            re.IGNORECASE,
        )
        if not call_match:
            errors.append(f"SafeCall is not an executable monitor call: {procedure}")
            continue
        called_procedure = call_match.group(1)
        if called_procedure not in public_procedures:
            errors.append(f"SafeCall references an unknown procedure: {procedure}/{called_procedure}")
            continue
        assigned_parameters = set(re.findall(r"@([A-Za-z_][A-Za-z0-9_]*)\s*=", safe_call))
        unknown_parameters = sorted(
            assigned_parameters - parameters_by_procedure.get(called_procedure, set())
        )
        if unknown_parameters:
            errors.append(
                f"SafeCall uses unknown parameters for {called_procedure}: "
                + ", ".join(unknown_parameters)
            )

    navigator_parameters = [
        row["ParameterName"] for row in parameter_rows if row["ProcedureName"] == "USP_AnalysisNavigator"
    ]
    expected_parameters = [
        "Suchbegriff",
        "Bereich",
        "Scope",
        "Navigationsrolle",
        "NurInstallierte",
        "MaxZeilen",
        "ResultSetArt",
        "ResultTablesJson",
        "JsonErzeugen",
        "Json",
        "PrintMeldungen",
        "Hilfe",
    ]
    if navigator_parameters != expected_parameters:
        errors.append("Navigator parameter inventory differs from the public signature.")

    result_rows = read_csv(repository_root / RESULT_SET_INVENTORY_PATH)
    navigator_results = [
        row for row in result_rows if row["ProcedureName"] == "USP_AnalysisNavigator"
    ]
    if len(navigator_results) != 1 or navigator_results[0]["ResultName"] != "navigation":
        errors.append("Navigator must expose exactly the named navigation result-set contract.")

    installer_text = (repository_root / INSTALLER_PATH).read_text(encoding="utf-8-sig")
    installer_files = (
        "021_VW_AnalysisCatalog.sql",
        "022_VW_AnalysisSearchTerm.sql",
        "023_VW_AnalysisRelation.sql",
        "100_USP_AnalysisNavigator.sql",
    )
    installer_positions = [installer_text.find(file_name) for file_name in installer_files]
    if any(position < 0 for position in installer_positions):
        errors.append("Install_All.sql does not install the complete Analysis Navigator object set.")
    elif installer_positions != sorted(installer_positions):
        errors.append("Analysis Navigator objects are not installed in dependency order.")

    standalone_text = (repository_root / PLAN_INSTALLER_PATH).read_text(encoding="utf-8-sig")
    if re.search(r"Analysis(?:Catalog|SearchTerm|Relation|Navigator)", standalone_text, re.IGNORECASE):
        errors.append("PLAN-001 standalone installer depends on the Analysis Navigator.")

    procedure_index = (
        repository_root / "Documentation/Analysis_Guides/Procedures/README.md"
    ).read_text(encoding="utf-8-sig")
    for procedure in sorted(public_procedures):
        if procedure not in procedure_index:
            errors.append(f"Procedure index does not reference {procedure}.")

    object_reference = (
        repository_root / "Documentation/Reference/Object_Reference.md"
    ).read_text(encoding="utf-8-sig")
    supporting_objects = {
        row["ObjectName"] for row in object_rows if row["ObjectType"] != "PROCEDURE"
    }
    for object_name in sorted(supporting_objects):
        if object_name not in object_reference:
            errors.append(f"Supporting-object reference does not mention {object_name}.")

    for object_name, source_path in (
        ("VW_AnalysisCatalog", CATALOG_PATH),
        ("VW_AnalysisSearchTerm", SEARCH_TERM_PATH),
        ("VW_AnalysisRelation", RELATION_PATH),
    ):
        section_match = re.search(
            rf"^### `\[monitor\]\.\[{re.escape(object_name)}\]`\s*$"
            rf"(.*?)(?=^### `\[monitor\]\.\[|\Z)",
            object_reference,
            re.MULTILINE | re.DOTALL,
        )
        if not section_match:
            errors.append(f"Missing detailed supporting-object section: {object_name}")
            continue
        section = section_match.group(1)
        if f"Quelle: `{source_path.as_posix()}`" not in section:
            errors.append(f"Supporting-object source path differs: {object_name}")
        for dimension in ("Aufgabe", "Schnittstelle", "Verwendung", "Last und Sperren", "Vertrag"):
            if not re.search(rf"^\|\s*{re.escape(dimension)}\s*\|\s*\S", section, re.MULTILINE):
                errors.append(f"{object_name} is missing documentation dimension: {dimension}")
        if len(re.findall(r"[^\W_][\w-]*", section, re.UNICODE)) < 90:
            errors.append(f"Supporting-object section is below the 90-word floor: {object_name}")

    navigator_reference = (
        repository_root / "Documentation/Reference/Analysis_Navigator.md"
    ).read_text(encoding="utf-8-sig")
    documented_taxonomy = (
        ALLOWED_AREAS
        | ALLOWED_ROLES
        | ALLOWED_SCOPES
        | ALLOWED_EVIDENCE_TYPES
        | ALLOWED_COST_RANGES
        | ALLOWED_PACKAGES
        | ALLOWED_RELATIONS
    )
    for code in sorted(documented_taxonomy):
        if f"`{code}`" not in navigator_reference:
            errors.append(f"Analysis Navigator reference does not document taxonomy code: {code}")

    navigator_page = (
        repository_root / "Documentation/Analysis_Guides/Procedures/USP_AnalysisNavigator.md"
    ).read_text(encoding="utf-8-sig")
    required_navigator_headings = (
        "## Entscheidungsfrage und Einsatz",
        "## Nicht beantwortete Fragen",
        "## Sicherer Einstieg",
        "## Resultsets und Leserichtung",
        "## Eine Zeile bedeutet",
        "## So lesen",
        "## Warum kann das problematisch sein?",
        "## Wann ist es kein Problem?",
        "## Beispiele und Gegenbeispiele",
        "## Leere oder partielle Ausgabe",
        "## Eigenlast und Grenzen",
        "## Technische Vertiefung",
        "### Leitfrage",
        "### Technischer Hintergrund",
        "### Datenkette",
        "### Zeit- und Scope-Modell",
        "### Bewertung und Gegenprobe",
        "### Typische Fehlinterpretation",
        "### Folgeanalyse",
        "## Primärquellen",
    )
    for heading in required_navigator_headings:
        if heading not in navigator_page:
            errors.append(f"Navigator procedure page is missing heading: {heading}")
    for cost_dimension in (
        "Kostenklasse",
        "Standardpfad",
        "Teuerster Pfad",
        "Haupttreiber",
        "Skalierung",
        "Ressourcen",
        "Begrenzungswirkung",
        "Locking und Nebenwirkungen",
        "Schutzmechanismus",
        "Sicherer Einsatz",
        "Aussagegrenze",
    ):
        if not re.search(rf"^\|\s*{re.escape(cost_dimension)}\s*\|", navigator_page, re.MULTILINE):
            errors.append(f"Navigator procedure page is missing cost dimension: {cost_dimension}")
    for fragment in (
        "[Technische Detailbeschreibung](../../Reference/Analysis_Navigator.md)",
        "[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)",
        "https://learn.microsoft.com/",
        "Example",
    ):
        if fragment not in navigator_page:
            errors.append(f"Navigator procedure page is missing documentation marker: {fragment}")
    if len(re.findall(r"[^\W_][\w-]*", navigator_page, re.UNICODE)) < 700:
        errors.append("Navigator procedure page is below the 700-word substantive floor.")

    public_documents = sorted(
        document
        for document in repository_root.rglob("*.md")
        if "AI_Metadata" not in document.relative_to(repository_root).parts
        and ".ai" not in document.relative_to(repository_root).parts
        and ".git" not in document.relative_to(repository_root).parts
        and document.name != "AGENTS.md"
    )
    stale_count = re.compile(
        r"\b(?:85|88|90|93|94)\s+(?:(?:öffentliche|inventarisierte|dokumentierte)\s+)?Procedures\b",
        re.IGNORECASE,
    )
    for document in public_documents:
        text = document.read_text(encoding="utf-8-sig")
        relative = document.relative_to(repository_root)
        for forbidden_pattern in PUBLIC_DOCUMENTATION_FORBIDDEN:
            match = forbidden_pattern.search(text)
            if match:
                line = text.count("\n", 0, match.start()) + 1
                errors.append(
                    f"Public documentation boundary violated in {relative}:{line}: {match.group(0)}"
                )
        match = stale_count.search(text)
        if match:
            line = text.count("\n", 0, match.start()) + 1
            errors.append(f"Stale procedure count in {relative}:{line}: {match.group(0)}")

    public_source_inventory = (
        repository_root / "Metadata/Inventory/SystemSources.csv"
    ).read_text(encoding="utf-8-sig")
    for historical_marker in (
        "sanitized prior research",
        "historical source paths",
        "Current canonical code",
        "Canonical implementation",
    ):
        if historical_marker.casefold() in public_source_inventory.casefold():
            errors.append(
                "Public system-source inventory contains an authoring-history marker: "
                + historical_marker
            )

    root_readme = (repository_root / "README.md").read_text(encoding="utf-8-sig")
    documentation_readme = (repository_root / "Documentation/README.md").read_text(
        encoding="utf-8-sig"
    )
    expected_public_count = str(len(public_rows))
    expected_inventory_count = str(len(object_rows))
    for label, text in (("README.md", root_readme), ("Documentation/README.md", documentation_readme)):
        for fragment in (
            expected_public_count,
            expected_inventory_count,
            "Start_Here.md",
            "USP_AnalysisNavigator",
        ):
            if fragment not in text:
                errors.append(f"{label} is missing discovery/inventory marker: {fragment}")

    return errors


def run_parameter_parity_self_test() -> None:
    objects = [{"ObjectType": "PROCEDURE", "ObjectName": "USP_Fixture", "SourcePath": "fixture.sql"}]
    source = """CREATE OR ALTER PROCEDURE [monitor].[USP_Fixture]
    @List nvarchar(100) = N'a,b', -- comma remains inside literal
    @Required int,
    @RequiredOutput int OUTPUT,
    @ExplicitNull int = NULL,
    @ExplicitNullOutput int = NULL OUTPUT,
    @Output int OUTPUT
AS
SELECT 1;
"""
    rows = [
        {"ProcedureName": "USP_Fixture", "ParameterName": "List", "DataType": "nvarchar(100)", "DefaultExpression": "N'a,b'"},
        {"ProcedureName": "USP_Fixture", "ParameterName": "Required", "DataType": "int", "DefaultExpression": ""},
        {"ProcedureName": "USP_Fixture", "ParameterName": "RequiredOutput", "DataType": "int", "DefaultExpression": "OUTPUT"},
        {"ProcedureName": "USP_Fixture", "ParameterName": "ExplicitNull", "DataType": "int", "DefaultExpression": "NULL"},
        {"ProcedureName": "USP_Fixture", "ParameterName": "ExplicitNullOutput", "DataType": "int", "DefaultExpression": "NULL OUTPUT"},
        {"ProcedureName": "USP_Fixture", "ParameterName": "Output", "DataType": "int", "DefaultExpression": "OUTPUT"},
    ]
    read_source = lambda path: source
    if compare_parameter_inventory(objects, rows, read_source):
        raise AssertionError("A matching SQL procedure signature and independent CSV rows were rejected.")
    mutations = [
        rows[1:],
        rows + [{"ProcedureName": "USP_Fixture", "ParameterName": "Extra", "DataType": "int", "DefaultExpression": "NULL"}],
        [rows[0], {**rows[1], "DataType": "bigint"}, *rows[2:]],
        [rows[0], {**rows[1], "DefaultExpression": "NULL"}, *rows[2:]],
        [*rows[:3], {**rows[3], "DefaultExpression": ""}, *rows[4:]],
        [*rows[:2], {**rows[2], "DefaultExpression": "NULL OUTPUT"}, *rows[3:]],
        [*rows[:2], {**rows[2], "DefaultExpression": ""}, *rows[3:]],
        [*rows[:4], {**rows[4], "DefaultExpression": "NULL"}, *rows[5:]],
        [rows[0], {**rows[1], "ParameterName": "required"}, *rows[2:]],
        [rows[1], rows[0], *rows[2:]],
        rows + [rows[1]],
        [{**rows[0], "DefaultExpression": "N'A,b'"}, *rows[1:]],
    ]
    for index, mutant in enumerate(mutations, start=1):
        if not compare_parameter_inventory(objects, mutant, read_source):
            raise AssertionError(f"Parameter parity accepted independent CSV mutation {index}.")
    source = source.replace("[USP_Fixture]", "[usp_Fixture]")
    if not compare_parameter_inventory(objects, rows, read_source):
        raise AssertionError("Parameter parity accepted a case-only SQL object-name mutation.")
    print(f"Parameter parity self-test passed: 1 positive with required/default/OUTPUT variants, {len(mutations)} negative CSV mutations, and 1 case-sensitive object-name rejection.")

def run_self_test() -> None:
    run_parameter_parity_self_test()
    sample = """
CREATE OR ALTER VIEW [monitor].[VW_Example] AS
SELECT *
FROM
(
    VALUES
      (N'USP_One',N'Text, with comma','de',100,N'It''s valid.')
    , (N'USP_Two',N'Parentheses (inside text)','en',95,NULL)
) AS [v]([ProcedureName],[SearchTerm],[LanguageCode],[SearchWeight],[MatchReason]);
"""
    rows = extract_values_rows(sample, SEARCH_TERM_COLUMNS)
    expected = [
        {
            "ProcedureName": "USP_One",
            "SearchTerm": "Text, with comma",
            "LanguageCode": "de",
            "SearchWeight": 100,
            "MatchReason": "It's valid.",
        },
        {
            "ProcedureName": "USP_Two",
            "SearchTerm": "Parentheses (inside text)",
            "LanguageCode": "en",
            "SearchWeight": 95,
            "MatchReason": None,
        },
    ]
    if rows != expected:
        raise AssertionError(f"VALUES parser self-test failed: {rows!r}")
    if normalize_ci_ai("BENÚTZER   WARTEN") != normalize_ci_ai("Benutzer warten"):
        raise AssertionError("CI/AI normalizer self-test failed.")

    with tempfile.TemporaryDirectory(prefix="analysis-navigator-includes-") as temporary:
        fixture_root = Path(temporary)
        installer = fixture_root / "Code/Install/Install_All.sql"
        included_sql = fixture_root / "Code/Core/Included.sql"
        installer.parent.mkdir(parents=True, exist_ok=True)
        included_sql.parent.mkdir(parents=True, exist_ok=True)
        installer.write_text(":r ../Core/Included.sql\n", encoding="utf-8")
        included_sql.write_text(
            "-- :r ../Target/Decoy.sql\nSELECT N':r ../Target/StringDecoy.sql';\n",
            encoding="utf-8",
        )
        if resolve_sqlcmd_includes(fixture_root, installer) != {"Code/Core/Included.sql"}:
            raise AssertionError("Comment/string SQLCMD decoys changed the flat include selection.")
        included_sql.write_text(":r ../Target/Nested.sql\n", encoding="utf-8")
        try:
            resolve_sqlcmd_includes(fixture_root, installer)
        except ValueError as exc:
            if "Nested SQLCMD include is unsupported" not in str(exc):
                raise AssertionError(f"Unexpected nested-include rejection: {exc}") from exc
        else:
            raise AssertionError("Nested SQLCMD include was accepted by the flat closure check.")

    fixture_includes = {
        "Code/Core/USP_Core.sql",
        "Code/Core/USP_PrepareLocal.sql",
    }
    base_rows = [
        {"ObjectType": "PROCEDURE", "ObjectName": "USP_Core", "SourcePath": "Code/Core/USP_Core.sql"},
        {"ObjectType": "PROCEDURE", "ObjectName": "USP_PrepareLocal", "SourcePath": "Code/Core/USP_PrepareLocal.sql"},
        {"ObjectType": "PROCEDURE", "ObjectName": "USP_TargetOnly", "SourcePath": "Code/Target/USP_TargetOnly.sql"},
    ]
    if derive_procedure_populations(base_rows, fixture_includes) != (3, 1):
        raise AssertionError("Procedure population fixture must separate metadata and core installation.")
    core_added = base_rows + [
        {"ObjectType": "PROCEDURE", "ObjectName": "USP_CoreAdded", "SourcePath": "Code/Core/USP_CoreAdded.sql"}
    ]
    if derive_procedure_populations(core_added, fixture_includes | {"Code/Core/USP_CoreAdded.sql"}) != (4, 2):
        raise AssertionError("A new core public procedure must increment both populations.")
    target_added = base_rows + [
        {"ObjectType": "PROCEDURE", "ObjectName": "USP_TargetAdded", "SourcePath": "Code/Target/USP_TargetAdded.sql"}
    ]
    if derive_procedure_populations(target_added, fixture_includes) != (4, 1):
        raise AssertionError("A target-only procedure must increment only the catalog population.")
    prepare_added = base_rows + [
        {"ObjectType": "PROCEDURE", "ObjectName": "USP_PrepareExtra", "SourcePath": "Code/Core/USP_PrepareExtra.sql"}
    ]
    if derive_procedure_populations(prepare_added, fixture_includes | {"Code/Core/USP_PrepareExtra.sql"}) != (4, 1):
        raise AssertionError("A Prepare procedure must increment only the catalog population.")

    with tempfile.TemporaryDirectory(prefix="analysis-navigator-counts-") as temporary:
        fixture_root = Path(temporary)
        pristine = {
            SMOKE_TEST_PATH: """IF (SELECT COUNT_BIG(*) FROM [monitor].[VW_AnalysisCatalog]) <> 3
    THROW 54025,N'The Analysis Catalog does not contain exactly 3 public Procedures.',1;
""",
            NAVIGATOR_RUNTIME_PATH: """IF (SELECT COUNT_BIG(*) FROM [monitor].[VW_AnalysisCatalog]) <> 3
    INSERT [#Failure] VALUES(N'CATALOG_COUNT',N'The catalog does not contain 3 public Procedures.');
SELECT CAST(3 AS int) AS [CatalogProcedureCount];
""",
            INSTALLED_PUBLIC_RUNTIME_PATH: """IF (SELECT COUNT(*) FROM [#FrameworkOutputRuntimeContract_Public])<>1
    INSERT [#Failure] VALUES(N'PUBLIC_INVENTORY',N'The installed public inventory does not contain 1 Vertragsobjekte.');
""",
        }
        for relative, source in pristine.items():
            target_path = fixture_root / relative
            target_path.parent.mkdir(parents=True, exist_ok=True)
            target_path.write_text(source, encoding="utf-8")
        if validate_native_count_bindings(fixture_root, 3, 1):
            raise AssertionError("Correct native count bindings were rejected.")

        def reject_mutant(relative: Path, mutant: str, label: str) -> None:
            target_path = fixture_root / relative
            target_path.write_text(mutant, encoding="utf-8")
            if not validate_native_count_bindings(fixture_root, 3, 1):
                raise AssertionError(f"Count-binding decoy/duplicate was accepted: {label}")
            target_path.write_text(pristine[relative], encoding="utf-8")

        stale_cases = (
            (SMOKE_TEST_PATH, "<> 3", "<> 2"),
            (SMOKE_TEST_PATH, "exactly 3", "exactly 2"),
            (NAVIGATOR_RUNTIME_PATH, "<> 3", "<> 2"),
            (NAVIGATOR_RUNTIME_PATH, "CAST(3 AS int)", "CAST(2 AS int)"),
            (INSTALLED_PUBLIC_RUNTIME_PATH, ")<>1", ")<>0"),
            (INSTALLED_PUBLIC_RUNTIME_PATH, "contain 1 Vertragsobjekte", "contain 0 Vertragsobjekte"),
        )
        for relative, old, new in stale_cases:
            if old not in pristine[relative]:
                raise AssertionError(f"Count-binding mutant source marker is missing: {relative} {old!r}")
            target_path = fixture_root / relative
            reject_mutant(
                relative,
                pristine[relative].replace(old, new, 1),
                f"{relative} {new!r}",
            )

        smoke_decoy = "-- IF (SELECT COUNT_BIG(*) FROM [monitor].[VW_AnalysisCatalog]) <> 3\n"
        smoke_stale_live = pristine[SMOKE_TEST_PATH].replace(
            "IF (SELECT COUNT_BIG(*) FROM [monitor].[VW_AnalysisCatalog]) <> 3",
            "IF (SELECT COUNT_BIG(*) FROM [monitor].[VW_AnalysisCatalog]) <> 2",
            1,
        )
        reject_mutant(
            SMOKE_TEST_PATH,
            smoke_decoy + smoke_stale_live,
            "expected comment before stale smoke assertion",
        )
        reject_mutant(
            NAVIGATOR_RUNTIME_PATH,
            "-- CAST(3 AS int) AS [CatalogProcedureCount]\n" + pristine[NAVIGATOR_RUNTIME_PATH],
            "duplicate Navigator output in comment",
        )
        reject_mutant(
            INSTALLED_PUBLIC_RUNTIME_PATH,
            "-- COUNT(*) FROM [#FrameworkOutputRuntimeContract_Public])<>1\n"
            + pristine[INSTALLED_PUBLIC_RUNTIME_PATH],
            "duplicate installed-public assertion in comment",
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        print("Analysis Navigator validator self-test passed.")
        return 0

    errors = validate(args.repository_root.resolve())
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Analysis Navigator metadata, discovery and documentation contracts passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
