#!/usr/bin/env python3
"""Validate the bounded MSDTC inventory API and its release-contract bindings."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

PROCEDURE = "Code/08_ServerHealth/300_USP_DistributedTransactionInventory.sql"
RUNTIME = "Code/Tests/ServerHealth/140_DistributedTransactionInventory_Runtime_Contract.sql"
INSTALLER = "Code/Install/Install_All.sql"
RELEASE_GATE = "Code/Tests/Run_Release_Gate.sql"
RESULT_NAMES = (
    "moduleStatus",
    "serverContext",
    "promotionConfiguration",
    "linkedServerPromotion",
    "activeDistributedTransactions",
    "sourceStatus",
    "warnings",
)
NATIVE_PROJECTIONS = (
    "@ConfiguredValue=[c].[value],@RunningValue=[c].[value_in_use],@IsDynamic=[c].[is_dynamic]",
    "[s].[server_id],[s].[is_remote_proc_transaction_promotion_enabled],[s].[modify_date]",
    "[t].[transaction_id],[t].[transaction_type],[t].[transaction_begin_time],[t].[transaction_state]",
)
FORBIDDEN = re.compile(
    r"\b(?:transaction_name|transaction_uow|session_id|login_name|provider_string|data_source)\b"
    r"|\bOBJECT_ID\s*\(|\bEXECUTE\s+AS\b|\bOPENQUERY\b|\bOPENDATASOURCE\b"
    r"|\bsp_addlinkedserver\b|\bBEGIN\s+(?:DISTRIBUTED\s+)?TRANSACTION\b"
    r"|\b(?:GRANT|REVOKE)\b|\bCREATE\s+LOGIN\b",
    re.IGNORECASE,
)


def strip_comments(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    return re.sub(r"--[^\r\n]*", " ", sql)


def validate_contract(
    procedure: str,
    runtime: str,
    installer: str,
    release_gate: str,
    objects_csv: str,
    parameters_csv: str,
    resultsets_csv: str,
    catalog: str,
    guide: str,
    coverage: str,
    maturity: str,
    dossier: str = "",
) -> list[str]:
    errors: list[str] = []
    code = strip_comments(procedure)
    test = strip_comments(runtime)

    for projection in NATIVE_PROJECTIONS:
        if projection not in code:
            errors.append(f"native source projection is missing or differs: {projection}")
    if "[t].[transaction_begin_time]" not in code or "[t].[transaction_type]=4" not in code:
        errors.append("DMV transaction fields must use the exact documented names and type filter")
    if "[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''remote proc trans'' COLLATE SQL_Latin1_General_CP1_CS_AS" not in code:
        errors.append("native configuration name predicate must collate both operands explicitly")
    for value in ("@ConfigurationValue", "@ConfigurationValueInUse"):
        if f"SQL_VARIANT_PROPERTY({value},N'BaseType')" not in code or f"{value} IS NULL THEN NULL" not in code:
            errors.append(f"sql_variant source type and NULL contract is missing for {value}")
    if "TRY_CONVERT(int,@ConfigurationValue)" in code or "TRY_CONVERT(int,@ConfigurationValueInUse)" in code:
        errors.append("sql_variant config values must require the documented native int base type")
    if "CONFIG_VALUE_TYPE_UNSUPPORTED" not in code or "@ConfiguredBaseType IS NULL OR" not in code or "@RunningBaseType IS NULL OR" not in code:
        errors.append("unsupported non-NULL sql_variant values must become typed NULL with a fixed warning")
    if code.count("COLLATE SQL_Latin1_General_CP1_CS_AS=N'int' COLLATE SQL_Latin1_General_CP1_CS_AS") < 2:
        errors.append("both sql_variant values must compare their exact int base type with explicit collation")
    if re.search(r"\[(?:begin_time|type|state)\]", code, re.IGNORECASE):
        errors.append("DMV source uses a shorthand or non-native transaction column")
    forbidden = FORBIDDEN.search(code)
    if forbidden:
        errors.append(f"out-of-scope or unsafe SQL operation/field: {forbidden.group(0)}")
    for source in ("[sys].[configurations] AS [c] WITH (NOLOCK)", "[sys].[servers] AS [s] WITH (NOLOCK)"):
        if source not in code:
            errors.append(f"required direct NOLOCK catalog source is absent: {source}")
    if "[sys].[dm_tran_active_transactions] AS [t]" not in code:
        errors.append("active transaction source is not directly bound to its native DMV")
    if "[sys].[dm_tran_active_transactions] AS [t] WITH (NOLOCK)" not in code or "[sys].[dm_tran_active_transactions] WITH (NOLOCK)" not in test:
        errors.append("active DMV source and native oracle must use direct nonblocking reads")
    if code.count("VALUES('SERVER_CONFIGURATION'") != 2:
        errors.append("server configuration source does not have separate success/error status paths")
    for name in ("LINKED_SERVER_PROMOTION", "ACTIVE_DISTRIBUTED_TRANSACTIONS"):
        if f"VALUES('{name}'" not in code:
            errors.append(f"source-specific status binding is missing: {name}")
    if code.count("BEGIN CATCH") < 4:
        errors.append("source reads or module emission are not isolated behind error handling")
    if "TOP (@ProbeLimit)" not in code or "@ProbeLimit bigint=" not in code or "CONVERT(bigint,@MaxZeilen)+1" not in code:
        errors.append("bounded source probes do not read only the configured limit plus one row")
    if "@MaxZeilen<0" not in code or "@MaxZeilen IS NULL OR @MaxZeilen=0" not in code:
        errors.append("negative and NULL/zero row-limit semantics are not explicit")
    if "SET XACT_ABORT OFF" not in code or "SET LOCK_TIMEOUT 0" not in code or "@RestoreLock" not in code:
        errors.append("caller XACT_ABORT/LOCK_TIMEOUT restoration contract is missing")
    if re.search(r"\b(?:BEGIN|COMMIT|ROLLBACK)\s+(?:DISTRIBUTED\s+)?TRANSACTION\b", code, re.IGNORECASE):
        errors.append("product procedure starts or changes a caller transaction")
    raw_block = code.split("IF @Mode='RAW'", 1)[1].split("ELSE IF @Mode='TABLE'", 1)[0] if "IF @Mode='RAW'" in code else ""
    raw_names = re.findall(r"SELECT \* FROM \[\#DistributedTransactionInventory_([A-Za-z]+)\]", raw_block)
    if tuple(raw_names) != RESULT_NAMES:
        errors.append("RAW resultsets are not emitted in the seven-result contract order")
    for name in RESULT_NAMES:
        if f"DistributedTransactionInventory_{name}" not in code:
            errors.append(f"resultset name is missing: {name}")
    if "WHEN 'RAW'" not in code and "IF @Mode='RAW'" not in code:
        errors.append("RAW mode path is absent")
    if "@Mode='TABLE'" not in code:
        errors.append("TABLE mode path is absent")
    if "@Mode NOT IN ('CONSOLE','RAW','TABLE','NONE')" not in code:
        errors.append("NONE mode is not accepted by the public output contract")
    if "FOR JSON PATH,INCLUDE_NULL_VALUES" not in code:
        errors.append("JSON arrays must preserve native NULL values")
    if "SERVERPROPERTY(N'ProductMajorVersion')" not in code:
        errors.append("server context does not use the major-version property")
    if "TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) IS NULL\n   OR TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) NOT IN (15,16,17)" not in test:
        errors.append("runtime contract must allow its SQL Server 2019, 2022, and 2025 release-gate targets")
    permission_grant = (
        "IF @ProductMajor>=16\n"
        "        SET @Sql=N'GRANT VIEW SERVER PERFORMANCE STATE TO '+QUOTENAME(@RestrictedLogin)+N'; GRANT VIEW SERVER SECURITY STATE TO '+QUOTENAME(@RestrictedLogin)+N';';\n"
        "    ELSE\n"
        "        SET @Sql=N'GRANT VIEW SERVER STATE TO '+QUOTENAME(@RestrictedLogin)+N';'"
    )
    if permission_grant not in test:
        errors.append("restricted-caller permissions must map 2019 to VIEW SERVER STATE and 2022+ to the documented performance/security grants")
    if test.count("IF @ProductMajor>=16") != 3 or test.count("REVOKE VIEW SERVER STATE FROM '+QUOTENAME(@RestrictedLogin)") != 2:
        errors.append("restricted-caller success and failure cleanup must revoke the permissions granted for that engine version")

    seed_tables = re.findall(
        r"CREATE TABLE \[#MdtcOut_([A-Za-z]+)\]\(\[Seed\] int NULL\);",
        test,
        re.IGNORECASE,
    )
    expected_tables = re.findall(
        r"CREATE TABLE \[#MdtcExpected_([A-Za-z]+)\]",
        test,
        re.IGNORECASE,
    )
    if tuple(seed_tables) != RESULT_NAMES:
        errors.append("runtime TABLE targets must be seven empty one-Seed-column fixtures in API order")
    if tuple(expected_tables) != RESULT_NAMES:
        errors.append("runtime contract must retain seven independent typed expected ABI tables")
    if test.count(" EXCEPT SELECT ") < 14:
        errors.append("runtime contract does not compare both directions for each output resultset")
    if test.count("[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName]") != 2:
        errors.append("runtime physical ABI must include the exact column name for actual and expected tables")
    if "[a].[ColumnName] COLLATE SQL_Latin1_General_CP1_CS_AS<>[e].[ColumnName] COLLATE SQL_Latin1_General_CP1_CS_AS" not in test:
        errors.append("runtime physical ABI must compare actual and expected column names ordinal by ordinal")
    if "[a].[BaseType] COLLATE SQL_Latin1_General_CP1_CS_AS<>[e].[BaseType] COLLATE SQL_Latin1_General_CP1_CS_AS" not in test:
        errors.append("runtime physical ABI base type comparison must use an explicit collation")
    if "TYPE_NAME([c].[system_type_id]) COLLATE SQL_Latin1_General_CP1_CS_AS AS [BaseType]" not in test:
        errors.append("runtime physical ABI must map the native system base type")
    if "user_type_id" in test:
        errors.append("runtime physical ABI must not compare alias user_type identity")
    if "CONFIG_VALUE_TYPE_UNSUPPORTED" not in test or "[NativeConfiguredValue] IS NOT NULL" not in test or "[NativeRunningValue] IS NOT NULL" not in test:
        errors.append("runtime native oracle must check fixed warnings for non-NULL non-int variants")
    if "[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'remote proc trans' COLLATE SQL_Latin1_General_CP1_CS_AS" not in test:
        errors.append("native configuration oracle must collate both name predicate operands")
    for field in ("[value]", "[value_in_use]"):
        if f"CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY({field},N'BaseType')) COLLATE SQL_Latin1_General_CP1_CS_AS=N'int' COLLATE SQL_Latin1_General_CP1_CS_AS" not in test:
            errors.append(f"native config oracle lacks explicit strict int sql_variant mapping for {field}")
    if "#MdtcNativeActive] EXCEPT SELECT * FROM [#MdtcOut_activeDistributedTransactions]" not in test or "[#MdtcOut_activeDistributedTransactions] EXCEPT SELECT * FROM [#MdtcNativeActive]" not in test:
        errors.append("native active-DTC oracle must compare every type-4 metadata row in both directions")
    if "@Return<>0 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1 OR ISJSON(@JsonConsole)<>1" not in test:
        errors.append("console mode must assert return, status, partiality and JSON before interpreting values")
    for summary_field in ("@ConsoleStatus=[StatusCode]", "@ConsolePartial=[IsPartial]", "@ConsoleProductMajor=[ProductMajorVersion]", "@ConsoleConfigured=[ConfiguredValue]", "@ConsoleRunning=[RunningValue]", "@ConsoleLinked=[LinkedServerRowsReturned]", "@ConsoleActive=[ActiveTransactionRowsReturned]", "@ConsoleDetail=[Detail]"):
        if summary_field not in test:
            errors.append(f"CONSOLE native summary assertion omits {summary_field}")
    for mode in ("TABLE", "NONE", "CONSOLE", "RAW"):
        if f"VALUES('{mode}',@Json" not in test:
            errors.append(f"cross-mode parity fixture is missing the {mode} JSON payload")
    for name in ("serverContext", "promotionConfiguration", "linkedServerPromotion", "activeDistributedTransactions", "warnings"):
        if f"JSON_QUERY([Payload],N'$.{name}')" not in test:
            errors.append(f"cross-mode parity must compare every field in the {name} array")
    for projection in ("[ModuleName],[StatusCode],[IsPartial],[RowCount],[Detail]", "[SourceName],[StatusCode],[IsPartial],[RowsReturned],[LimitApplied],[ErrorNumber],[ErrorMessage],[VisibilityLimit]"):
        if projection not in test:
            errors.append("cross-mode parity stable moduleStatus/sourceStatus projection is incomplete")
    if "[a].[user_type_id]" in test or "[e].[user_type_id]" in test:
        errors.append("runtime physical ABI must compare system base type, not alias identity")
    mode_fields="[moduleStatus],[serverContext],[promotionConfiguration],[linkedServerPromotion],[activeDistributedTransactions],[sourceStatus],[warnings]"
    if test.count(mode_fields) < 4 or "#MdtcModePayload" not in test:
        errors.append("runtime mode parity must compare all seven stable arrays in both directions")
    if "[CapturedAtUtc]" in test[test.index("INSERT [#MdtcModePayload]"):test.index("THROW 57427")]:
        errors.append("cross-call module parity must omit only capture timestamps")
    if "[CaptureStartedAtUtc]" in test[test.index("INSERT [#MdtcModePayload]"):test.index("THROW 57427")]:
        errors.append("cross-call source parity must omit only capture timestamps")
    for limit, envelope_code, data_code in (("0", "57416", "57435"), ("NULL", "57417", "57436")):
        call=test.find(f"@MaxZeilen={limit},@ResultSetArt='NONE'")
        envelope_end=test.find(f"THROW {envelope_code}",call)
        data_end=test.find(f"THROW {data_code}",envelope_end)
        envelope=test[call:envelope_end] if call>=0 and envelope_end>=0 else ""
        data=test[envelope_end:data_end] if envelope_end>=0 and data_end>=0 else ""
        native_pairs=("[#MdtcNativeConfigActual] EXCEPT SELECT", "EXCEPT SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual]", "[#MdtcNativeLinkedActual] EXCEPT SELECT", "EXCEPT SELECT [ServerId],[RemoteProcTransactionPromotionEnabled],[ModifiedAt] FROM [#MdtcNativeLinkedActual]", "[#MdtcNativeActive] EXCEPT SELECT", "EXCEPT SELECT [TransactionId],[TransactionType],[TransactionBeginTime],[TransactionState] FROM [#MdtcNativeActive]")
        if not envelope or any(token not in envelope for token in ("@Return<>0", "@Status<>'AVAILABLE_LIMITED'", "@Partial<>1", "ISJSON(@Json)<>1")) or "OPENJSON" in envelope:
            errors.append(f"unlimited @MaxZeilen={limit} must validate return/status/partiality/JSON before reading arrays")
        if not data or data.count("EXCEPT SELECT") < 6 or any(pair not in data for pair in native_pairs) or "[LimitApplied]<>0" not in data:
            errors.append(f"unlimited @MaxZeilen={limit} must compare every native row bidirectionally and check full row counts/statuses")
    positive_prep_start=test.find("SELECT @NativeLinkedRows=COUNT_BIG(*) FROM [#MdtcNativeLinkedActual]")
    positive_call=test.find("@MaxZeilen=1,@ResultSetArt='NONE'",positive_prep_start)
    positive_envelope_end=test.find("THROW 57415",positive_call)
    positive_data_end=test.find("THROW 57434",positive_envelope_end)
    positive_prep=test[positive_prep_start:positive_call] if positive_prep_start>=0 and positive_call>=0 else ""
    positive_envelope=test[positive_call:positive_envelope_end] if positive_call>=0 and positive_envelope_end>=0 else ""
    positive_data=test[positive_envelope_end:positive_data_end] if positive_envelope_end>=0 and positive_data_end>=0 else ""
    if "SELECT TOP (1) CASE WHEN [value] IS NULL" not in test or "ORDER BY [name] COLLATE SQL_Latin1_General_CP1_CS_AS" not in test:
        errors.append("positive-limit config oracle must be a deterministic native TOP(1)")
    for source in ("[#MdtcNativeLinkedTopOne]", "[#MdtcNativeActiveTopOne]"):
        if source not in positive_prep or "SELECT TOP (1)" not in positive_prep:
            errors.append(f"positive-limit ordered native TOP(1) oracle is missing: {source}")
    if "ORDER BY [server_id]" not in positive_prep or "ORDER BY [transaction_begin_time],[transaction_id]" not in positive_prep:
        errors.append("positive-limit native TOP(1) oracles must use the exact canonical order")
    if not positive_envelope or any(token not in positive_envelope for token in ("@Return<>0", "@Status<>'AVAILABLE_LIMITED'", "@Partial<>1", "ISJSON(@Json)<>1")) or "OPENJSON" in positive_envelope:
        errors.append("positive @MaxZeilen=1 must validate return/status/partiality/JSON before reading arrays")
    positive_pairs=("[#MdtcNativeConfigActual] EXCEPT SELECT", "EXCEPT SELECT [ConfiguredValue],[RunningValue],[IsDynamic] FROM [#MdtcNativeConfigActual]", "FROM [#MdtcNativeLinkedTopOne] EXCEPT SELECT", "EXCEPT SELECT * FROM [#MdtcNativeLinkedTopOne]", "FROM [#MdtcNativeActiveTopOne] EXCEPT SELECT", "EXCEPT SELECT * FROM [#MdtcNativeActiveTopOne]")
    if not positive_data or positive_data.count("EXCEPT SELECT") < 6 or any(pair not in positive_data for pair in positive_pairs):
        errors.append("positive @MaxZeilen=1 must compare all exact native TOP(1) subsets bidirectionally")
    if "[RowsReturned]<>CASE [SourceName]" not in positive_data or "[LimitApplied]<>CASE" not in positive_data or "@NativeLinkedRows>1" not in positive_data or "@NativeActiveRows>1" not in positive_data:
        errors.append("positive limit must assert native observed counts, min(count,1) returned rows and exact truncation flags")
    for field in ("ROW_NUMBER() OVER(ORDER BY [c].[column_id])", "[c].[system_type_id]", "[c].[max_length]",
                  "[c].[precision]", "[c].[scale]", "[c].[is_nullable]", "[c].[collation_name]",
                  "[c].[is_identity]", "[c].[is_computed]"):
        if field not in test:
            errors.append(f"runtime physical ABI oracle omits {field}")
    for check in ("57406", "57408", "57409", "57415", "57418", "57419", "57423", "57424", "57425", "57426", "57427", "57428", "57429", "57430", "57431", "57434", "57435", "57436"):
        if check not in test:
            errors.append(f"runtime acceptance/negative assertion {check} is missing")
    if "DENY SELECT ON [sys].[dm_tran_active_transactions]" not in test or "[ErrorNumber]=229" not in test:
        errors.append("dedicated native DMV DENY 229 branch is missing")
    if re.search(r"INSERT\s+\[#MdtcOut_activeDistributedTransactions\].*?VALUES", test, re.IGNORECASE | re.DOTALL):
        errors.append("runtime test fabricates an active distributed transaction row")
    if "MSDTC_RUNTIME_CONTRACT_PASS" not in test:
        errors.append("runtime success marker is not present after the assertions and owned cleanup")

    if ":r ../08_ServerHealth/300_USP_DistributedTransactionInventory.sql" not in installer:
        errors.append("full installer does not register the public procedure")
    if ":r ServerHealth/140_DistributedTransactionInventory_Runtime_Contract.sql" not in release_gate:
        errors.append("full release gate does not include the runtime contract")

    rows = _csv_rows(objects_csv)
    if not any(row.get("ObjectType") == "PROCEDURE" and row.get("ObjectName") == "USP_DistributedTransactionInventory" for row in rows):
        errors.append("public procedure object registry entry is missing")
    rows = _csv_rows(parameters_csv)
    registered = {row.get("ParameterName") for row in rows if row.get("ProcedureName") == "USP_DistributedTransactionInventory"}
    if len(registered) != 12 or not {"MaxZeilen", "LockTimeoutMs", "ResultSetArt", "Json", "StatusCodeOut"} <= registered:
        errors.append("public parameter registry does not match the bounded 12-parameter API")
    rows = _csv_rows(resultsets_csv)
    registered_results = {row.get("ResultName") for row in rows if row.get("ProcedureName") == "USP_DistributedTransactionInventory"}
    if registered_results != set(RESULT_NAMES):
        errors.append("public resultset registry does not contain exactly the seven API resultsets")

    if "USP_DistributedTransactionInventory" not in catalog or "DTC-Dienst" not in catalog:
        errors.append("analysis catalog entry lacks the explicit external-health boundary")
    if "USP_DistributedTransactionInventory" not in guide or "kein" not in guide.lower() or "VIEW SERVER PERFORMANCE STATE" not in guide:
        errors.append("public guide omits API navigation, permission boundary, or external-health caveat")
    coverage_row = next((row for row in _csv_rows(coverage) if row.get("CoverageKey") == "DISTRIBUTED_TRANSACTIONS"), None)
    if not coverage_row or coverage_row.get("CoverageStatus") != "PARTIAL_PRODUCT_FUNCTION":
        errors.append("MSDTC coverage is not recorded as the bounded partial product slice")
    errors.extend(validate_maturity_evidence(maturity, dossier))

    return errors


class _CsvContext:
    def __init__(self, value: str):
        self.value = value
        self.handle = None

    def __enter__(self):
        import io
        self.handle = io.StringIO(self.value, newline="")
        return csv.DictReader(self.handle)

    def __exit__(self, exc_type, exc, tb):
        self.handle.close()


def _csv_rows(value: str):
    import io
    return list(csv.DictReader(io.StringIO(value, newline="")))


def _set_csv_value(value: str, column: str, replacement: str) -> str:
    import io
    reader = csv.DictReader(io.StringIO(value, newline=""))
    rows = list(reader)
    for row in rows:
        if row.get("PrimaryProcedure") == "USP_DistributedTransactionInventory":
            row[column] = replacement
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=reader.fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue()


def validate_maturity_evidence(maturity: str, dossier: str) -> list[str]:
    errors: list[str] = []
    maturity_row = next((row for row in _csv_rows(maturity) if row.get("PrimaryProcedure") == "USP_DistributedTransactionInventory"), None)
    if not maturity_row:
        return ["MSDTC module maturity row is missing"]
    if maturity_row.get("Maturity") != "PLANNED":
        errors.append("MSDTC module maturity must remain PLANNED until separately authorized closeout")
    for version in ("2019", "2022"):
        if maturity_row.get(f"CIEvidence{version}") != "NO":
            errors.append(f"SQL Server {version} evidence is unqualified")
    evidence_2025 = maturity_row.get("CIEvidence2025")
    if evidence_2025 not in {"NO", "YES"}:
        errors.append("SQL Server 2025 evidence must be NO or bound to a verified functional qualification")
    elif evidence_2025 == "YES":
        notes = maturity_row.get("Notes") or ""
        note_heads = set(re.findall(r"\b[0-9a-f]{40}\b", notes, re.IGNORECASE))
        dossier_heads = set(re.findall(r"\b[0-9a-f]{40}\b", dossier, re.IGNORECASE))
        note_runs = set(re.findall(r"\bRun\s+([0-9]{10,})\b", notes, re.IGNORECASE))
        dossier_runs = set(re.findall(r"actions/runs/([0-9]{10,})\b", dossier, re.IGNORECASE))
        evidence_is_cross_bound = (
            len(note_heads) == 1 and note_heads == dossier_heads
            and len(note_runs) == 1 and note_runs == dossier_runs
            and re.search(r"(?<![A-Za-z0-9_])full_suite=true(?![A-Za-z0-9_])", notes, re.IGNORECASE) is not None
            and re.search(r"(?<![A-Za-z0-9_])full_suite=true(?![A-Za-z0-9_])", dossier, re.IGNORECASE) is not None
            and "runtime contract 140" in notes.lower()
            and "exactly once" in notes.lower()
            and re.search(r"phase[- ]7", notes, re.IGNORECASE) is not None
            and "gebundene head-evidenz" in dossier.lower()
            and "140_distributedtransactioninventory_runtime_contract.sql" in dossier.lower()
            and "genau einmal" in dossier.lower()
            and "phase-7" in dossier.lower()
        )
        if not evidence_is_cross_bound:
            errors.append("SQL Server 2025 YES requires matching source-head/run evidence in maturity notes and the bound dossier")
    return errors


def repository_errors(root: Path) -> list[str]:
    def read(relative: str) -> str:
        return (root / relative).read_text(encoding="utf-8-sig")
    return validate_contract(
        read(PROCEDURE), read(RUNTIME), read(INSTALLER), read(RELEASE_GATE),
        read("Metadata/Inventory/Objects.csv"), read("Metadata/Inventory/Parameters.csv"),
        read("Metadata/Inventory/ResultSets.csv"), read("Code/01_Common/021_VW_AnalysisCatalog.sql"),
        read("Documentation/Analysis_Guides/Procedures/USP_DistributedTransactionInventory.md"),
        read("Metadata/Quality/Diagnostic_Coverage_Landscape.csv"), read("Metadata/Inventory/Module_Maturity.csv"),
        read("AI_Metadata/Internal_Documentation/Architecture/MSDTC_Distributed_Transaction_Inventory_Dossier.md"),
    )


def self_test() -> None:
    root = Path(__file__).resolve().parents[3]
    procedure = (root / PROCEDURE).read_text(encoding="utf-8")
    runtime = (root / RUNTIME).read_text(encoding="utf-8")
    maturity = (root / "Metadata/Inventory/Module_Maturity.csv").read_text(encoding="utf-8")
    dossier = (root / "AI_Metadata/Internal_Documentation/Architecture/MSDTC_Distributed_Transaction_Inventory_Dossier.md").read_text(encoding="utf-8")
    if validate_contract(
        procedure, runtime, (root / INSTALLER).read_text(encoding="utf-8"),
        (root / RELEASE_GATE).read_text(encoding="utf-8"),
        (root / "Metadata/Inventory/Objects.csv").read_text(encoding="utf-8"),
        (root / "Metadata/Inventory/Parameters.csv").read_text(encoding="utf-8"),
        (root / "Metadata/Inventory/ResultSets.csv").read_text(encoding="utf-8"),
        (root / "Code/01_Common/021_VW_AnalysisCatalog.sql").read_text(encoding="utf-8"),
        (root / "Documentation/Analysis_Guides/Procedures/USP_DistributedTransactionInventory.md").read_text(encoding="utf-8"),
        (root / "Metadata/Quality/Diagnostic_Coverage_Landscape.csv").read_text(encoding="utf-8"),
        maturity,
        dossier,
    ):
        raise AssertionError("current contract fixture failed")
    prequalification = _set_csv_value(_set_csv_value(maturity, "CIEvidence2025", "NO"), "Notes", "")
    if validate_maturity_evidence(prequalification, ""):
        raise AssertionError("prequalification SQL Server 2025 NO fixture was rejected")
    if validate_maturity_evidence(maturity, dossier):
        raise AssertionError("bound SQL Server 2025 source-head/run qualification was rejected")
    narrowed_runtime = runtime.replace("NOT IN (15,16,17)", "<>17", 1)
    if not any("allow its SQL Server 2019, 2022, and 2025" in error for error in validate_contract(
        procedure, narrowed_runtime, "", "", "", "", "", "", "", "", ""
    )):
        raise AssertionError("SQL Server 2025-only native runtime guard mutation escaped")
    wrong_legacy_permission = runtime.replace("GRANT VIEW SERVER STATE TO '+QUOTENAME(@RestrictedLogin)", "GRANT VIEW SERVER PERFORMANCE STATE TO '+QUOTENAME(@RestrictedLogin)", 1)
    if not any("map 2019 to VIEW SERVER STATE" in error for error in validate_contract(
        procedure, wrong_legacy_permission, "", "", "", "", "", "", "", "", ""
    )):
        raise AssertionError("SQL Server 2019 DMV permission mapping mutation escaped")
    missing_legacy_cleanup = runtime.replace("REVOKE VIEW SERVER STATE FROM '+QUOTENAME(@RestrictedLogin)", "REVOKE VIEW SERVER PERFORMANCE STATE FROM '+QUOTENAME(@RestrictedLogin)", 1)
    if not any("success and failure cleanup" in error for error in validate_contract(
        procedure, missing_legacy_cleanup, "", "", "", "", "", "", "", "", ""
    )):
        raise AssertionError("SQL Server 2019 permission cleanup mutation escaped")
    unbound_yes = _set_csv_value(maturity, "Notes", "")
    if not any("SQL Server 2025 YES requires matching" in error for error in validate_maturity_evidence(unbound_yes, dossier)):
        raise AssertionError("unbound SQL Server 2025 YES mutation escaped")
    maturity_notes = next(row["Notes"] for row in _csv_rows(maturity) if row.get("PrimaryProcedure") == "USP_DistributedTransactionInventory")
    mislabeled_suite = _set_csv_value(maturity, "Notes", maturity_notes.replace("full_suite=true", "source_full_suite=true", 1))
    if not any("SQL Server 2025 YES requires matching" in error for error in validate_maturity_evidence(mislabeled_suite, dossier)):
        raise AssertionError("incorrect CI suite-field label mutation escaped")
    for version in ("2019", "2022"):
        unsupported_version = _set_csv_value(maturity, f"CIEvidence{version}", "YES")
        if not any(f"SQL Server {version} evidence is unqualified" in error for error in validate_maturity_evidence(unsupported_version, dossier)):
            raise AssertionError(f"unsupported SQL Server {version} YES mutation escaped")
    complete_maturity = _set_csv_value(maturity, "Maturity", "COMPLETE")
    if not any("must remain PLANNED" in error for error in validate_maturity_evidence(complete_maturity, dossier)):
        raise AssertionError("maturity COMPLETE mutation escaped")
    mutated_native_name = procedure.replace("[t].[transaction_begin_time]", "[t].[begin_time]")
    if not any("exact documented names" in error for error in validate_contract(
        mutated_native_name, runtime, "", "", "", "", "", "", "", "", ""
    )):
        raise AssertionError("shorthand native DMV column mutation escaped")
    mutated_forbidden_projection = procedure.replace(
        "[t].[transaction_id],[t].[transaction_type]",
        "[t].[transaction_uow],[t].[transaction_id],[t].[transaction_type]",
    )
    if not any("out-of-scope" in error for error in validate_contract(
        mutated_forbidden_projection, runtime, "", "", "", "", "", "", "", "", ""
    )):
        raise AssertionError("sensitive transaction identity mutation escaped")
    if not any("bounded source probes" in error for error in validate_contract(
        procedure.replace("TOP (@ProbeLimit)", "TOP (1000000)"),
        runtime, "", "", "", "", "", "", "", "", "",
    )):
        raise AssertionError("unbounded source query mutation escaped")
    mutated_config_name = procedure.replace("[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''remote proc trans''", "[c].[name]=N''remote proc trans''", 1)
    if not any("configuration name predicate" in error for error in validate_contract(mutated_config_name, runtime, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("configuration name collation mutation escaped")
    mutated_native_name = runtime.replace("[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'remote proc trans' COLLATE SQL_Latin1_General_CP1_CS_AS", "[name]=N'remote proc trans'", 1)
    mutated_dmv_hint = procedure.replace("[sys].[dm_tran_active_transactions] AS [t] WITH (NOLOCK)", "[sys].[dm_tran_active_transactions] AS [t]", 1)
    if not any("active DMV source and native oracle" in error for error in validate_contract(mutated_dmv_hint, runtime, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("active DMV nonblocking hint mutation escaped")
    if not any("native configuration oracle must collate" in error for error in validate_contract(procedure, mutated_native_name, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("native configuration predicate collation mutation escaped")
    mutated_native_type = runtime.replace("COLLATE SQL_Latin1_General_CP1_CS_AS=N'int' COLLATE SQL_Latin1_General_CP1_CS_AS", "COLLATE SQL_Latin1_General_CP1_CS_AS=N'varchar' COLLATE SQL_Latin1_General_CP1_CS_AS", 1)
    if not any("native config oracle lacks explicit strict int" in error for error in validate_contract(procedure, mutated_native_type, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("native strict sql_variant oracle mutation escaped")
    mutated_variant_warning = procedure.replace("CONFIG_VALUE_TYPE_UNSUPPORTED", "UNBOUNDED_VARIANT_WARNING", 1)
    if not any("fixed warning" in error for error in validate_contract(mutated_variant_warning, runtime, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("unexpected sql_variant warning mutation escaped")
    mutated_native_variant = runtime.replace("SQL_VARIANT_PROPERTY([value],N'BaseType')", "SQL_VARIANT_PROPERTY([value],N'Precision')", 1)
    if not any("explicit strict int sql_variant mapping" in error for error in validate_contract(procedure, mutated_native_variant, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("native variant property mutation escaped")
    mutated_variant_type = procedure.replace("COLLATE SQL_Latin1_General_CP1_CS_AS=N'int'", "COLLATE SQL_Latin1_General_CP1_CS_AS=N'varchar'", 1)
    if not any("exact int base type" in error for error in validate_contract(mutated_variant_type, runtime, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("strict sql_variant base-type mutation escaped")
    mutated_abi_name = runtime.replace("[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName],", "", 1)
    if not any("physical ABI must include the exact column name" in error for error in validate_contract(procedure, mutated_abi_name, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("TABLE ABI column-name mutation escaped")
    mode_fields = "[moduleStatus],[serverContext],[promotionConfiguration],[linkedServerPromotion],[activeDistributedTransactions],[sourceStatus],[warnings]"
    mutated_mode_fields = runtime.replace(mode_fields, mode_fields.removesuffix(",[warnings]"), 1)
    if not any("all seven stable arrays" in error for error in validate_contract(procedure, mutated_mode_fields, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("cross-mode resultset omission mutation escaped")
    mutated_source_projection = runtime.replace("[ErrorMessage],[VisibilityLimit]", "[ErrorMessage]", 1)
    if not any("stable moduleStatus/sourceStatus projection" in error for error in validate_contract(procedure, mutated_source_projection, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("cross-mode sourceStatus field omission mutation escaped")
    mutated_console = runtime.replace("@ConsoleActive=[ActiveTransactionRowsReturned]", "@ConsoleActive=[LinkedServerRowsReturned]", 1)
    if not any("CONSOLE native summary assertion omits @ConsoleActive" in error for error in validate_contract(procedure, mutated_console, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("console summary row-count mutation escaped")
    zero_start = runtime.index("@MaxZeilen=0,@ResultSetArt='NONE'")
    zero_end = runtime.index("THROW 57416", zero_start)
    mutated_zero = runtime[:zero_start] + runtime[zero_start:zero_end].replace("@Return<>0", "@Return=0", 1) + runtime[zero_end:]
    if not any("unlimited @MaxZeilen=0" in error for error in validate_contract(procedure, mutated_zero, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("zero-limit status assertion mutation escaped")
    zero_start_values = runtime.index("@MaxZeilen=0,@ResultSetArt='NONE'")
    zero_end_values = runtime.index("THROW 57435", zero_start_values)
    mutated_zero_values = runtime[:zero_start_values] + runtime[zero_start_values:zero_end_values].replace("#MdtcNativeActive] EXCEPT", "#MdtcUnknownActive] EXCEPT", 1) + runtime[zero_end_values:]
    if not any("unlimited @MaxZeilen=0" in error for error in validate_contract(procedure, mutated_zero_values, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("zero-limit native value parity mutation escaped")
    null_start = runtime.index("@MaxZeilen=NULL,@ResultSetArt='NONE'")
    null_end = runtime.index("THROW 57417", null_start)
    mutated_null = runtime[:null_start] + runtime[null_start:null_end].replace("@Status<>'AVAILABLE_LIMITED'", "@Status='AVAILABLE_LIMITED'", 1) + runtime[null_end:]
    if not any("unlimited @MaxZeilen=NULL" in error for error in validate_contract(procedure, mutated_null, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("NULL-limit status assertion mutation escaped")

    positive_call_start = runtime.index("@MaxZeilen=1,@ResultSetArt='NONE'")
    positive_data_end = runtime.index("THROW 57434", positive_call_start)
    mutated_positive_oracle = runtime[:positive_call_start] + runtime[positive_call_start:positive_data_end].replace("[#MdtcNativeLinkedTopOne] EXCEPT", "[#MdtcMissingLinkedTopOne] EXCEPT", 1) + runtime[positive_data_end:]
    if not any("exact native TOP(1) subsets bidirectionally" in error for error in validate_contract(procedure, mutated_positive_oracle, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("positive TOP(1) native oracle mutation escaped")
    mutated_positive_flag = runtime[:positive_call_start] + runtime[positive_call_start:positive_data_end].replace("[LimitApplied]<>CASE", "[LimitApplied]=CASE", 1) + runtime[positive_data_end:]
    if not any("exact truncation flags" in error for error in validate_contract(procedure, mutated_positive_flag, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("positive limit truncation-flag mutation escaped")
    mutated_positive_status = runtime[:positive_call_start] + runtime[positive_call_start:positive_data_end].replace("@Status<>'AVAILABLE_LIMITED'", "@Status='AVAILABLE_LIMITED'", 1) + runtime[positive_data_end:]
    if not any("positive @MaxZeilen=1 must validate return/status/partiality/JSON" in error for error in validate_contract(procedure, mutated_positive_status, "", "", "", "", "", "", "", "", "")):
        raise AssertionError("positive limit status mutation escaped")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path.cwd())
    parser.add_argument("--self-test", action="store_true")
    arguments = parser.parse_args()
    if arguments.self_test:
        self_test()
        print("MSDTC inventory contract self-test passed.")
        return 0
    errors = repository_errors(arguments.repository_root.resolve())
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("MSDTC inventory contract is consistent; active-DTC positive evidence remains open.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
