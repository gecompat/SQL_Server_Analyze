#!/usr/bin/env python3
"""Validate the bounded Database Mirroring inventory contract and bindings."""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

PROCEDURE = "Code/08_ServerHealth/310_USP_DatabaseMirroringInventory.sql"
RUNTIME = "Code/Tests/ServerHealth/141_DatabaseMirroringInventory_Runtime_Contract.sql"
CANDIDATE_HELPER = "Code/01_Common/083_USP_PrepareDatabaseCandidates.sql"
RESULT_NAMES = ("moduleStatus", "databaseMirroring", "sourceStatus", "warnings")
PARAMETERS = (
    ("DatabaseNames", "nvarchar(max)", "NULL"),
    ("SystemdatenbankenEinbeziehen", "bit", "0"),
    ("DatabaseNamePattern", "nvarchar(4000)", "NULL"),
    ("MaxZeilen", "int", "1000"),
    ("ResultSetArt", "varchar(16)", "'CONSOLE'"),
    ("ResultTablesJson", "nvarchar(max)", "NULL"),
    ("JsonErzeugen", "bit", "0"),
    ("Json", "nvarchar(max)", "NULL OUTPUT"),
    ("PrintMeldungen", "bit", "1"),
    ("Hilfe", "bit", "0"),
    ("StatusCodeOut", "varchar(40)", "NULL OUTPUT"),
    ("IsPartialOut", "bit", "NULL OUTPUT"),
    ("ErrorNumberOut", "int", "NULL OUTPUT"),
    ("ErrorMessageOut", "nvarchar(2048)", "NULL OUTPUT"),
)
FIELDS = (
    ("DatabaseId", "int", "NOT NULL"),
    ("DatabaseName", "sysname", "NOT NULL"),
    ("MirroringState", "tinyint", "NULL"),
    ("MirroringStateDesc", "nvarchar(60)", "NULL"),
    ("MirroringRole", "tinyint", "NULL"),
    ("MirroringRoleDesc", "nvarchar(60)", "NULL"),
    ("MirroringSafetyLevel", "tinyint", "NULL"),
    ("MirroringSafetyLevelDesc", "nvarchar(60)", "NULL"),
    ("MirroringWitnessState", "tinyint", "NULL"),
    ("MirroringWitnessStateDesc", "nvarchar(60)", "NULL"),
    ("ConfiguredRedoQueueLimitMb", "int", "NULL"),
    ("RedoQueueLimitType", "nvarchar(60)", "NULL"),
)

def csv_rows(value: str) -> list[list[str]]:
    return list(csv.reader(value.splitlines()))

def validate_contract(
    procedure: str, runtime: str, candidate_helper: str, objects: str, parameters: str,
    resultsets: str, sources: str, maturity: str, coverage: str,
    procedure_guide: str, guide_index: str, call_catalog: str,
    release_gate: str, installer: str, generated: str, ops_install: str,
    ops_update: str, docs_review: str, dossier: str,
) -> list[str]:
    errors: list[str] = []
    proc_marker = "CREATE OR ALTER PROCEDURE [monitor].[USP_DatabaseMirroringInventory]"
    start = procedure.find(proc_marker)
    signature_end = procedure.find("AS", start + len(proc_marker))
    if start < 0 or signature_end < 0:
        return ["canonical procedure declaration or parameter signature is missing"]
    signature = procedure[start + len(proc_marker):signature_end]
    actual_params = []
    for line in signature.splitlines():
        if "@" not in line or "=" not in line:
            continue
        left, default = line.split("=", 1)
        parts = left.strip().lstrip(",").split()
        if len(parts) < 2 or not parts[0].startswith("@"):
            continue
        actual_params.append((parts[0][1:], parts[1], default.strip().rstrip(",").strip()))
    if tuple((n.lower(),t.lower(),d.lower()) for n,t,d in actual_params) != tuple((n.lower(),t.lower(),d.lower()) for n,t,d in PARAMETERS):
        errors.append("public parameter names, order, types, defaults, or OUTPUT modes differ from the dossier")

    body = procedure[signature_end:]
    help_start = body.find("IF @Hilfe=1")
    help_end = body.find("END;", help_start) if help_start >= 0 else -1
    help_block = body[help_start:help_end] if help_start >= 0 and help_end >= 0 else ""
    if not help_block:
        errors.append("help branch is absent or has no bounded ending")
    help_prints = []
    for line in help_block.splitlines():
        marker = "PRINT N'"
        position = line.find(marker)
        if position < 0 or not line.endswith("';"):
            continue
        encoded = line[position + len(marker):-2]
        help_prints.append(encoded.replace("''", "'"))
    help_text = "\n".join(help_prints)
    if not help_prints:
        errors.append("help branch has no literal PRINT documentation")
    for name, typ, default in PARAMETERS:
        expected = "@" + name + " " + typ + "=" + default
        if expected not in help_text:
            errors.append("help parameter default or OUTPUT mode differs: @" + name)
    for token in ("CONSOLE", "RAW", "TABLE", "NONE", "schemaVersion=1", "RESTORING",
                  "AVAILABLE_LIMITED", "VIEW SERVER PERFORMANCE STATE",
                  "keine weitere Serverberechtigung", "sysadmin", "like:", "regex:",
                  "regexi:", "SQL Server 2025", "170", "#Monitor", "116 Zeichen",
                  "@DatabaseNamePattern=N'like:Prod%'", "1 schließt sie ein",
                  "@Json=@Json OUTPUT"):
        if token not in help_text:
            errors.append("help omits required option, output, permission, or scope detail: " + token)
    mapping = "{\"moduleStatus\":\"#DbmiModule\",\"databaseMirroring\":\"#DbmiRows\",\"sourceStatus\":\"#DbmiSources\",\"warnings\":\"#DbmiWarnings\"}"
    if mapping not in help_text:
        errors.append("help TABLE mapping does not identify all four exact result names and local targets")
    if "exakt und Pattern schließen einander aus" not in help_text:
        errors.append("help must state the shared helper's mutually exclusive exact-name and pattern rule")
    if "@DatabaseNamePattern=N'like:Prod%', @ResultSetArt='CONSOLE'" not in help_text or "@DatabaseNames=N'[ExampleDatabase]'" not in help_text:
        errors.append("help examples do not demonstrate valid canonical pattern and exact-name selectors")
    json_example = "@DatabaseNames=N'[ExampleDatabase]', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json]"
    if json_example not in help_text:
        errors.append("help JSON example must capture the OUTPUT parameter and return it to the caller")
    if "@EffectiveDatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL" not in candidate_helper:
        errors.append("shared candidate helper no longer enforces the documented exact-name/pattern exclusion")
    if "@DatabaseNames=@DatabaseNames" not in body or "@DatabaseNamePattern=@DatabaseNamePattern" not in body:
        errors.append("procedure does not pass both documented selector parameters to the shared helper")
    if help_start < 0 or "USP_PrepareDatabaseCandidates" in body[:help_start] or "sys.database_mirroring" in body[:help_start]:
        errors.append("help must return before database selection or source access")
    if "@DatabaseNames" not in help_block or "@DatabaseNamePattern" not in help_block or "getrennt" not in help_block.lower():
        errors.append("help must explain separate exact-name and pattern selectors")
    if "[ExampleDatabase]" not in help_block:
        errors.append("help must include a canonical monitor call with a synthetic example database")

    if "@MaxZeilen<0" not in body or "@MaxZeilen IS NULL OR @MaxZeilen=0" not in body:
        errors.append("negative and NULL/zero row-limit semantics are missing")
    if "@Mode NOT IN ('CONSOLE','RAW','TABLE','NONE')" not in body:
        errors.append("CONSOLE/RAW/TABLE/NONE mode validation is incomplete")
    if "SET LOCK_TIMEOUT 0" not in body or "@RestoreLock" not in body:
        errors.append("source LOCK_TIMEOUT 0 and caller restoration are required")
    if "SET XACT_ABORT OFF" not in body or "@PreviousXactAbort" not in body:
        errors.append("caller XACT_ABORT preservation is missing")
    if "SET TRANSACTION ISOLATION LEVEL" in body:
        errors.append("procedure must preserve caller isolation without setting it")
    for source in ("[master].[sys].[databases] AS [d] WITH (NOLOCK)",
                   "[master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)"):
        if source not in body:
            errors.append("native source is not directly bound with NOLOCK: " + source)
    if "ON [m].[database_id]=[d].[database_id]" not in body or "[c].[DatabaseId]" not in body:
        errors.append("database selection and native catalog rows must join by database_id")
    for forbidden in ("mirroring_guid", "mirroring_partner_name", "mirroring_partner_instance",
                      "mirroring_witness_name", "mirroring_failover_lsn",
                      "mirroring_end_of_log_lsn", "mirroring_replication_lsn",
                      "EXECUTE AS", "OPENQUERY", "OPENDATASOURCE", "BEGIN TRANSACTION",
                      "COMMIT TRANSACTION", "ROLLBACK TRANSACTION", "GRANT ", "REVOKE "):
        if forbidden.lower() in body.lower():
            errors.append("out-of-scope or unsafe source field/operation: " + forbidden)
    for field, typ, nullability in FIELDS:
        declaration = next((line for line in body.splitlines() if "[" + field + "] " + typ in line), "")
        if not declaration or nullability not in declaration:
            errors.append("business ABI field/type is missing: " + field)
    raw_start = body.find("IF @Mode='RAW'")
    raw_end = body.find("ELSE IF @Mode='TABLE'", raw_start)
    raw = body[raw_start:raw_end] if raw_start >= 0 and raw_end >= 0 else ""
    positions = [raw.find("SELECT * FROM [#DatabaseMirroringInventory_" + name + "]") for name in RESULT_NAMES]
    if any(pos < 0 for pos in positions) or positions != sorted(positions):
        errors.append("RAW resultsets do not match the frozen four-set order")
    if "@AllowedResultNames=N'moduleStatus|databaseMirroring|sourceStatus|warnings'" not in body:
        errors.append("TABLE whitelist differs from the frozen four-result contract")
    for name in RESULT_NAMES:
        if "@Json_" + name not in body:
            errors.append("JSON array is missing for " + name)
    if "N'DatabaseMirroringInventory' AS [resultName],1 AS [schemaVersion]" not in body:
        errors.append("JSON metadata name or schemaVersion is not bound to V1")
    if "FOR JSON PATH,INCLUDE_NULL_VALUES" not in body:
        errors.append("JSON arrays must preserve native NULL values")
    if "AVAILABLE_LIMITED" not in body or "IsPartial" not in body:
        errors.append("successful inventory must remain explicitly partial and limited")
    for status in ("DENIED_PERMISSION", "ERROR_HANDLED", "SOURCE_UNAVAILABLE",
                   "ROLE_VISIBILITY_LIMIT", "MIRRORING_NULLS_UNINTERPRETED"):
        if status not in body:
            errors.append("source failure or native interpretation boundary is missing: " + status)
    if "@Status='ERROR_HANDLED'" not in body or "@StatusCodeOut='INVALID_PARAMETER'" not in body:
        errors.append("caught errors or invalid parameters may be reported as successful empty inventory")

    schema = resultsets.replace("COLLATE SQL_Latin1_General_CP1_CS_AS ", "")
    schema_shape = ", ".join("[" + n + "] " + t + " " + null for n,t,null in FIELDS)
    if schema_shape not in schema:
        errors.append("ResultSets.csv physical business schema/order differs from the dossier")
    result_rows = [r for r in csv_rows(resultsets) if r and r[0] == "USP_DatabaseMirroringInventory"]
    if tuple(r[1] for r in result_rows) != RESULT_NAMES:
        errors.append("ResultSets.csv must register exactly the four frozen result names in order")
    object_rows = [r for r in csv_rows(objects) if len(r) >= 3 and r[1] == "USP_DatabaseMirroringInventory"]
    if object_rows != [["PROCEDURE", "USP_DatabaseMirroringInventory", PROCEDURE]]:
        errors.append("Objects.csv must bind one canonical procedure source path")
    parameter_rows = [r for r in csv_rows(parameters) if len(r) >= 4 and r[0] == "USP_DatabaseMirroringInventory"]
    if tuple((r[1],r[2],r[3]) for r in parameter_rows) != PARAMETERS:
        errors.append("Parameters.csv does not match the public 14-parameter API in order")
    if "sys.database_mirroring" not in sources or PROCEDURE not in sources:
        errors.append("SystemSources.csv omits the catalog or canonical module binding")
    if "Database Mirroring,USP_DatabaseMirroringInventory,PLANNED,NO,NO,NO,,PARTIAL" not in maturity:
        errors.append("module maturity must remain PLANNED with no unearned native evidence")
    if "DATABASE_MIRRORING" not in coverage or "PARTIAL_PRODUCT_FUNCTION" not in coverage or "RESTORING" not in coverage:
        errors.append("WI-0010 intake must record only the implemented partial scope")
    if "RESTORING" not in procedure_guide or "VIEW SERVER PERFORMANCE STATE" not in procedure_guide or "mirroring_" not in procedure_guide:
        errors.append("public procedure guide omits selector, permission, or native NULL boundary")
    if "USP_DatabaseMirroringInventory" not in guide_index or "USP_DatabaseMirroringInventory" not in call_catalog:
        errors.append("human navigation or public examples omit the procedure")
    if "USP_DatabaseMirroringInventory" not in dossier or "RESTORING" not in dossier:
        errors.append("architecture dossier does not bind the ONLINE-only selection limit")
    if release_gate.count("141_DatabaseMirroringInventory_Runtime_Contract.sql") != 1:
        errors.append("runtime contract 141 must be bound exactly once in the existing release gate")
    if "CAST(34 AS int)" not in release_gate:
        errors.append("nested Phase 7 contract must not create a new top-level release suite")
    if installer.count("310_USP_DatabaseMirroringInventory.sql") != 1 or generated.count("-- BEGIN SOURCE: Code/08_ServerHealth/310_USP_DatabaseMirroringInventory.sql") != 1:
        errors.append("canonical/generated deployment installers must contain the procedure exactly once")
    if ops_install.count("-- BEGIN SOURCE: Code/08_ServerHealth/310_USP_DatabaseMirroringInventory.sql") != 1:
        errors.append("OPS-005 install/update snapshots must contain the new procedure exactly once")
    if "USP_DatabaseMirroringInventory,BASELINE,,1" not in docs_review:
        errors.append("documentation review manifest omits the new procedure page")

    for token in ("MIRRORING_NULLS_UNINTERPRETED", "ROLE_VISIBILITY_LIMIT", "DENIED_PERMISSION",
                  "SET LOCK_TIMEOUT 0"):
        if token not in runtime:
            errors.append("runtime fixture misses contract case: " + token)
    for token in ("#DbmiOut_moduleStatus]([Seed] int NULL)",
                  "#DbmiOut_databaseMirroring]([Seed] int NULL)",
                  "#DbmiOut_sourceStatus]([Seed] int NULL)",
                  "#DbmiOut_warnings]([Seed] int NULL)"):
        if token not in runtime:
            errors.append("runtime fixture lacks empty one-Seed TABLE target: " + token)
    for token in ("TYPE_NAME([c].[system_type_id])", "[c].[max_length]", "[c].[precision]",
                  "[c].[scale]", "[c].[is_nullable]", "[c].[collation_name]",
                  "[c].[is_identity]", "[c].[is_computed]"):
        if token not in runtime:
            errors.append("physical ABI oracle misses column facet: " + token)
    if "OPENJSON(@JsonNull,N'$.databaseMirroring')" not in runtime or "@NullFieldCount<>10" not in runtime:
        errors.append("runtime fixture must prove a non-vacuous native all-NULL tempdb row")
    for token in ("@MaxZeilen=1", "@SourceRows<2", "@MaxZeilen=0", "@MaxZeilen=NULL"):
        if token not in runtime:
            errors.append("runtime limit cases must prove one-row and both unlimited forms: " + token)
    for token in ("N'[Codex_Missing_Database]'", "@DatabaseNamePattern=N'like:%'",
                  "DENY VIEW SERVER PERFORMANCE STATE", "REVERT;", "DROP LOGIN", "DROP USER"):
        if token not in runtime:
            errors.append("runtime fixture misses restricted/negative cleanup case: " + token)
    if "IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) NOT IN (15,16,17)" not in runtime:
        errors.append("runtime fixture must admit its existing SQL Server 2019/2022/2025 release-gate targets")
    if "IF @ProductMajor>=16" not in runtime or "SQL Server 2019: no minimum catalog-denial permission is asserted" not in runtime:
        errors.append("runtime fixture must version-scope the 2022+ permission-denial case and state the 2019 boundary")
    if "sp_executesql] N'DROP USER" in runtime or "sp_executesql] N'DROP LOGIN" in runtime:
        errors.append("runtime cleanup passes concatenated expressions directly to sp_executesql instead of a variable")
    for token in ("SET @Sql=N'DROP USER '+QUOTENAME(@Login)+N';';\n    EXEC [sys].[sp_executesql] @Sql;",
                  "SET @Sql=N'DROP LOGIN '+QUOTENAME(@Login)+N';';\n    EXEC [sys].[sp_executesql] @Sql;"):
        if token not in runtime:
            errors.append("runtime fixture must assign each dynamic cleanup batch before sp_executesql")
    for mode in ("TABLE", "RAW", "CONSOLE", "NONE"):
        if "@ResultSetArt='" + mode + "'" not in runtime:
            errors.append("runtime fixture omits output mode " + mode)
    for source in ("master].[sys].[databases] AS [d] WITH (NOLOCK)",
                   "master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)"):
        if source not in runtime:
            errors.append("runtime oracle misses native NOLOCK source: " + source)
    for token in ("BEGIN TRANSACTION", "ROLLBACK TRANSACTION", "@@LOCK_TIMEOUT<>137",
                  "transaction_isolation_level", "@@TRANCOUNT<>1"):
        if token not in runtime:
            errors.append("runtime fixture misses caller-state condition: " + token)
    if "MirroringRole]=2" in runtime or "mirroring_role]=2" in runtime:
        errors.append("runtime fixture may not synthesize a positive mirrored role")
    if runtime.count("EXCEPT") < 7:
        errors.append("runtime fixture lacks sufficient native, JSON, and TABLE value comparisons")
    return errors

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    root = args.repository_root.resolve()
    paths = {
        "procedure": PROCEDURE, "runtime": RUNTIME,
        "candidate_helper": CANDIDATE_HELPER,
        "objects": "Metadata/Inventory/Objects.csv",
        "parameters": "Metadata/Inventory/Parameters.csv",
        "resultsets": "Metadata/Inventory/ResultSets.csv",
        "sources": "Metadata/Inventory/SystemSources.csv",
        "maturity": "Metadata/Inventory/Module_Maturity.csv",
        "coverage": "Metadata/Quality/Diagnostic_Coverage_Landscape.csv",
        "procedure_guide": "Documentation/Analysis_Guides/Procedures/USP_DatabaseMirroringInventory.md",
        "guide_index": "Documentation/Analysis_Guides/Procedures/README.md",
        "call_catalog": "Documentation/Reference/Call_Catalog.md",
        "release_gate": "Code/Tests/Run_Release_Gate.sql",
        "installer": "Code/Install/Install_All.sql",
        "generated": "Code/Install/generated/Deploy_All.generated.sql",
        "ops_install": "TestLab/Adapters/OPS-005/sql/install.sql",
        "ops_update": "TestLab/Adapters/OPS-005/sql/update.sql",
        "docs_review": "Metadata/Quality/Analysis_Documentation_Review.csv",
        "dossier": "AI_Metadata/Internal_Documentation/Architecture/Database_Mirroring_Inventory_Dossier.md",
    }
    try:
        text = {name: (root / rel).read_text(encoding="utf-8-sig") for name, rel in paths.items()}
    except OSError as error:
        print("ERROR: " + str(error), file=sys.stderr)
        return 2
    errors = validate_contract(**text)
    if args.self_test and not errors:
        mutations = (
            ("NOLOCK", "procedure", text["procedure"].replace("[master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)", "[master].[sys].[database_mirroring] AS [m]", 1), "native source"),
            ("ABI", "procedure", text["procedure"].replace("[ConfiguredRedoQueueLimitMb] int NULL", "[ConfiguredRedoQueueLimitMb] bigint NULL", 1), "business ABI"),
            ("PARAM_SIGNATURE", "procedure", text["procedure"].replace("@MaxZeilen int = 1000", "@MaxZeilen int = 500", 1), "public parameter names"),
            ("HELP_PARAMETER", "procedure", text["procedure"].replace("@ErrorMessageOut nvarchar(2048)=NULL OUTPUT", "RemovedHelpParam", 1), "help parameter default or OUTPUT mode"),
            ("HELP_DEFAULT", "procedure", text["procedure"].replace("@MaxZeilen int=1000", "@MaxZeilen int=500", 1), "help parameter default or OUTPUT mode"),
            ("HELP_OPTION", "procedure", text["procedure"].replace("regexi:", "regexx:", 1), "help omits required option"),
            ("HELP_SELECTOR", "procedure", text["procedure"].replace("exakt und Pattern schließen einander aus", "Filter sind verfügbar", 1), "mutually exclusive exact-name and pattern rule"),
            ("HELP_EXAMPLE", "procedure", text["procedure"].replace("@DatabaseNames=N''[ExampleDatabase]'', @JsonErzeugen=1, @Json=@Json OUTPUT;", "@DatabaseNames=N''[ExampleDatabase]'', @JsonErzeugen=1, @Json=@Json;", 1), "help JSON example"),
            ("SHARED_SELECTOR", "candidate_helper", text["candidate_helper"].replace("@EffectiveDatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL", "@EffectiveDatabaseNames IS NOT NULL AND 1=0", 1), "shared candidate helper"),
            ("LIMIT", "runtime", text["runtime"].replace("@SourceRows<2", "@SourceRows<1", 1), "limit cases"),
            ("NATIVE_VERSION_SCOPE", "runtime", text["runtime"].replace("NOT IN (15,16,17)", "<>17", 1), "existing SQL Server 2019/2022/2025 release-gate targets"),
            ("SP_EXECUTESQL_EXPRESSION", "runtime", text["runtime"].replace("SET @Sql=N'DROP USER '+QUOTENAME(@Login)+N';';\n    EXEC [sys].[sp_executesql] @Sql;", "EXEC [sys].[sp_executesql] N'DROP USER '+QUOTENAME(@Login)+N';';", 1), "concatenated expressions directly to sp_executesql"),
        )
        for name, key, changed, expected in mutations:
            candidate = dict(text)
            candidate[key] = changed
            if not any(expected in error for error in validate_contract(**candidate)):
                errors.append("validator self-test did not reject meaningful " + name + " mutation")
    if errors:
        for error in errors:
            print("ERROR: " + error)
        return 1
    print("PASS: Database Mirroring V1 source, metadata, runtime, documentation, and deployment bindings are consistent.")
    if args.self_test:
        print("PASS: meaningful source, ABI, help, runtime-limit, native-version-scope, and dynamic-cleanup mutations are rejected.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
