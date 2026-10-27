#!/usr/bin/env python3
"""Validate the RLS and masking inventory's registered V1 contract."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path


PROCEDURE = "USP_RowLevelSecurityAndMaskingInventory"
SOURCE = "Code/08_ServerHealth/285_USP_RowLevelSecurityAndMaskingInventory.sql"
FIXTURE = "Code/Tests/ServerHealth/139_RowLevelSecurityAndMasking_Runtime_Contract.sql"
RESULTS = {
    "moduleStatus": "[ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
    "databaseContext": "[DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContainmentDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
    "securityPolicies": "[DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PolicyObjectId] int NOT NULL, [PolicyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SchemaId] int NOT NULL, [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [IsEnabled] bit NOT NULL, [IsNotForReplication] bit NOT NULL, [UsesDatabaseCollation] bit NOT NULL, [IsSchemabindingEnabled] bit NULL, [CreateDate] datetime NOT NULL, [ModifyDate] datetime NOT NULL",
    "securityPredicates": "[DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PolicyObjectId] int NOT NULL, [PredicateId] int NOT NULL, [TargetObjectId] int NOT NULL, [PredicateType] int NOT NULL, [PredicateTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [Operation] int NULL, [OperationDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "maskedColumns": "[DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObjectId] int NOT NULL, [ColumnId] int NOT NULL, [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsMasked] bit NOT NULL",
    "sourceStatus": "[DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL",
    "warnings": "[DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL",
}
PARAMETERS = [
    ("DatabaseNames", "nvarchar(max)", "NULL"),
    ("SystemdatenbankenEinbeziehen", "bit", "0"),
    ("DatabaseNamePattern", "nvarchar(4000)", "NULL"),
    ("MaxZeilen", "int", "1000"),
    ("LockTimeoutMs", "int", "0"),
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
]


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def fixture_schema_batch_error(fixture: str) -> str | None:
    combined_schema_batch = re.search(
        r"SET\s+@Sql\s*=\s*N'USE '\s*\+\s*QUOTENAME\(@FixtureDatabase\)\s*\+\s*N';\s*CREATE SCHEMA '\s*\+\s*QUOTENAME\(@Schema\)\s*\+\s*N';'",
        fixture,
        re.IGNORECASE,
    )
    if combined_schema_batch:
        return "CREATE SCHEMA must execute as the first statement in its database batch"
    schema_definition = re.search(
        r"SET\s+@Definition\s*=\s*N'CREATE SCHEMA '\s*\+\s*QUOTENAME\(@Schema\)\s*\+\s*N';';",
        fixture,
        re.IGNORECASE,
    )
    schema_dispatch = re.search(
        r"SET\s+@Sql\s*=\s*N'USE '\s*\+\s*QUOTENAME\(@FixtureDatabase\)\s*\+\s*N'; EXEC \[sys\]\.\[sp_executesql\] @Definition;';\s*"
        r"EXEC \[master\]\.\[sys\]\.\[sp_executesql\] @Sql,N'@Definition nvarchar\(max\)',@Definition=@Definition;",
        fixture,
        re.IGNORECASE,
    )
    if not schema_definition or not schema_dispatch:
        return "fixture must execute CREATE SCHEMA in a separate first-statement batch in the target database"
    return None


def policy_field_lookup_errors(source: str, fixture: str) -> list[str]:
    errors: list[str] = []
    fragments = (
        "FROM [sys].[all_objects] AS [o] WITH (NOLOCK)",
        "INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK)",
        "INNER JOIN [sys].[all_columns] AS [c] WITH (NOLOCK)",
        "[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''security_policies'' COLLATE SQL_Latin1_General_CP1_CS_AS",
        "[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''sys'' COLLATE SQL_Latin1_General_CP1_CS_AS",
        "[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''is_schemabinding_enabled'' COLLATE SQL_Latin1_General_CP1_CS_AS",
    )
    if any(fragment not in source for fragment in fragments):
        errors.append("policy-field capability lookup must use nonblocking, schema-qualified catalog metadata and exact CS_AS names")
    if "OBJECT_ID(N''sys.security_policies'')" in source:
        errors.append("policy-field capability lookup must not use the blocking OBJECT_ID metadata function")
    fixture_query = "FROM [sys].[all_objects] AS [o] WITH (NOLOCK)"
    if fixture.count(fixture_query) != 3 or any(fragment not in fixture for fragment in fragments):
        errors.append("independent fixture probes must use the same nonblocking exact catalog identity in all three databases")
    return errors


def optional_policy_field_errors(source: str, fixture: str) -> list[str]:
    errors: list[str] = []
    errors.extend(policy_field_lookup_errors(source, fixture))
    if "[sys].[all_columns] AS [c]" not in source or "N''is_schemabinding_enabled''" not in source:
        errors.append("policy source must detect whether the native schemabinding metadata field is exposed")
    field_fallback = "CASE WHEN @PolicyFieldAvailable=1 THEN N'[p].[is_schemabinding_enabled]' ELSE N'CAST(NULL AS bit)' END"
    if source.count(field_fallback) != 1:
        errors.append("policy source must preserve the native schemabinding bit or return typed NULL when the field is absent")
    missing_field_warning = "'SOURCE_UNAVAILABLE','SECURITY_POLICIES',N'Die Katalogansicht stellt IsSchemabindingEnabled nicht bereit"
    if missing_field_warning not in source:
        errors.append("missing policy-field metadata must produce a bounded source warning")
    fixture_field_fallback = "THEN N'[p].[is_schemabinding_enabled]' ELSE N'CAST(NULL AS bit)' END"
    if fixture.count(fixture_field_fallback) != 2 or not all(name in fixture for name in ("@PolicyFieldA", "@PolicyFieldB", "@PolicyFieldEmpty")):
        errors.append("native fixture oracle must independently handle the native policy field in both populated and empty databases")
    if "<>7+CASE WHEN @PolicyFieldA=0 THEN 1 ELSE 0 END+CASE WHEN @PolicyFieldB=0 THEN 1 ELSE 0 END" not in fixture:
        errors.append("global-limit warning oracle must include bounded policy-field warnings for each selected database")
    return errors


def predicate_id_mapping_errors(source: str, fixture: str) -> list[str]:
    errors: list[str] = []
    native_identifier = "[p].[security_predicate_id]"
    invalid_identifier = "[p].[predicate_id]"
    if source.count(native_identifier) != 1 or fixture.count(native_identifier) != 2:
        errors.append("predicate inventory and independent fixture must map the native security_predicate_id column")
    if invalid_identifier in source or invalid_identifier in fixture:
        errors.append("predicate inventory must not select a non-native predicate_id catalog column")
    return errors


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    source = (root / SOURCE).read_text(encoding="utf-8-sig")
    lowered = source.casefold()
    for forbidden in ("predicate_definition", "masking_function", "function_name", "execute as", "alter security policy", "create security policy", "drop security policy"):
        if forbidden in lowered:
            errors.append(f"product source contains excluded expression/behavior marker: {forbidden}")
    errors.extend(predicate_id_mapping_errors(source, (root / FIXTURE).read_text(encoding="utf-8-sig")))
    for required in (
        "[sys].[security_policies]", "[sys].[security_predicates]", "[sys].[masked_columns]",
        "[sys].[schemas]", "[sys].[tables]", "AVAILABLE_LIMITED", "VISIBLE_ONLY", "UNPROVEN",
        "DATABASE_SELECTION", "TARGET_SELECTION", "SECURITY_POLICIES", "SECURITY_PREDICATES", "MASKED_COLUMNS",
        "INCLUDE_NULL_VALUES", "@PreviousXactAbort=1 SET XACT_ABORT ON", "@RestoreLock",
    ):
        if required not in source:
            errors.append(f"source missing required contract marker: {required}")
    signature_match = re.search(
        r"CREATE OR ALTER PROCEDURE \[monitor\]\.\[USP_RowLevelSecurityAndMaskingInventory\](.*?)\nAS\nBEGIN",
        source,
        re.DOTALL | re.IGNORECASE,
    )
    if not signature_match:
        errors.append("procedure parameter declaration is not discoverable")
    else:
        signature = [
            (match.group(1), match.group(2).lower(), match.group(3))
            for match in re.finditer(
                r"@([A-Za-z0-9_]+)\s+([A-Za-z]+(?:\([^)]*\))?)\s*=\s*(NULL(?: OUTPUT)?|\d+|'CONSOLE')",
                signature_match.group(1),
                re.IGNORECASE,
            )
        ]
        if [(name, kind, default.upper() if default.upper().startswith("NULL") else default) for name, kind, default in signature] != [
            (name, kind, default.upper() if default.upper().startswith("NULL") else default)
            for name, kind, default in PARAMETERS
        ]:
            errors.append("procedure signature differs from the reviewed parameter order/type/default contract")

    if source.count("ERROR_MESSAGE()") != 1:
        errors.append("catalog-source catches must not copy variable SQL error text into output")
    console = source.split("ELSE IF @ConsoleResultRequested=1", 1)
    if len(console) != 2 or "[#285_USP_RowLevelSecurityAndMaskingInventory_securityPredicates]" in console[1] or "[#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns]" in console[1]:
        errors.append("CONSOLE must keep securityPolicies as its only standard feature inventory")

    object_rows = read_csv(root / "Metadata/Inventory/Objects.csv")
    if not any(row["ObjectName"] == PROCEDURE and row["SourcePath"] == SOURCE for row in object_rows):
        errors.append("product object inventory does not bind the canonical procedure source")

    parameter_rows = [row for row in read_csv(root / "Metadata/Inventory/Parameters.csv") if row["ProcedureName"] == PROCEDURE]
    observed_parameters = [(row["ParameterName"], row["DataType"], row["DefaultExpression"]) for row in parameter_rows]
    if observed_parameters != PARAMETERS:
        errors.append("parameter inventory differs from the reviewed 15-parameter order/type/default contract")

    result_rows = [row for row in read_csv(root / "Metadata/Inventory/ResultSets.csv") if row["ProcedureName"] == PROCEDURE]
    if [row["ResultName"] for row in result_rows] != list(RESULTS):
        errors.append("resultset inventory differs from the seven ordered V1 resultsets")
    for row in result_rows:
        if row["SourceSchema"] != RESULTS.get(row["ResultName"]):
            errors.append(f"{row['ResultName']} schema differs from the reviewed V1 field/type/nullability/collation contract")
        if row["IsRawExportable"] != "1" or row["IsTableExportable"] != "1":
            errors.append(f"{row['ResultName']} is not exported consistently by RAW and TABLE")
    product_schemas = {
        match.group(1): re.sub(r"\s+", "", match.group(2))
        for match in re.finditer(r"CREATE TABLE \[#285_USP_RowLevelSecurityAndMaskingInventory_(\w+)\]\((.*?)\);", source, re.DOTALL)
    }
    for result_name, schema in RESULTS.items():
        actual = product_schemas.get(result_name)
        if actual != re.sub(r"\s+", "", schema):
            errors.append(f"product temp schema/order differs from the canonical {result_name} contract")

    install_all = (root / "Code/Install/Install_All.sql").read_text(encoding="utf-8-sig")
    if ":r ../08_ServerHealth/285_USP_RowLevelSecurityAndMaskingInventory.sql" not in install_all:
        errors.append("canonical SQLCMD installer omits the procedure")
    release_gate = (root / "Code/Tests/Run_Release_Gate.sql").read_text(encoding="utf-8-sig")
    fixture_include = ":r ServerHealth/139_RowLevelSecurityAndMasking_Runtime_Contract.sql"
    if release_gate.count(fixture_include) != 1:
        errors.append("full release gate must execute the native runtime fixture exactly once")
    if "CAST(34 AS int) AS [ExecutedSuites]" not in release_gate:
        errors.append("release gate suite total changed without enumerating a new top-level suite")
    fixture = (root / "Code/Tests/ServerHealth/139_RowLevelSecurityAndMasking_Runtime_Contract.sql").read_text(encoding="utf-8-sig")
    errors.extend(optional_policy_field_errors(source, fixture))
    schema_batch_error = fixture_schema_batch_error(fixture)
    if schema_batch_error:
        errors.append(schema_batch_error)
    pass_marker = "RLS_MASKING_RUNTIME_CONTRACT_PASS"
    if fixture.count(pass_marker) != 1 or fixture.rfind("DROP DATABASE '+QUOTENAME(@DbEmpty)") > fixture.index(pass_marker):
        errors.append("runtime fixture must emit one fixed success marker after owned database cleanup")
    if re.search(r"@DatabaseNames\s*=\s*QUOTENAME\s*\(", fixture, re.IGNORECASE):
        errors.append("runtime fixture must bind computed database selections to variables before EXEC parameter assignment")
    if re.search(r"SET\s+LOCK_TIMEOUT\s+@", fixture, re.IGNORECASE):
        errors.append("runtime fixture must restore variable lock timeouts through a dynamic SET statement")
    restore_lock = "SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLock)+N';'; EXEC [sys].[sp_executesql] @Sql;"
    if fixture.count(restore_lock) != 2:
        errors.append("runtime fixture must restore caller lock timeout on both success and catch paths")
    for relative in (
        "Code/01_Common/021_VW_AnalysisCatalog.sql", "Code/01_Common/022_VW_AnalysisSearchTerm.sql",
        "Documentation/Analysis_Guides/Procedures/USP_RowLevelSecurityAndMaskingInventory.md",
        "Documentation/Reference/Procedure_Reference.md", "Documentation/Reference/Call_Catalog.md",
    ):
        if PROCEDURE not in (root / relative).read_text(encoding="utf-8-sig"):
            errors.append(f"missing procedure navigation/documentation registration: {relative}")
    guide = (root / "Documentation/Analysis_Guides/Procedures/USP_RowLevelSecurityAndMaskingInventory.md").read_text(encoding="utf-8-sig")
    if "SOURCE_UNAVAILABLE" not in guide or "IsSchemabindingEnabled" not in guide:
        errors.append("public guide must explain nullable policy-field behavior and its unavailable-field warning")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert len(RESULTS) == 7 and len(PARAMETERS) == 15
        assert "[IsSchemabindingEnabled] bit NULL" in RESULTS["securityPolicies"]
        valid_schema_setup = (
            "SET @Definition=N'CREATE SCHEMA '+QUOTENAME(@Schema)+N';'; "
            "SET @Sql=N'USE '+QUOTENAME(@FixtureDatabase)+N'; EXEC [sys].[sp_executesql] @Definition;'; "
            "EXEC [master].[sys].[sp_executesql] @Sql,N'@Definition nvarchar(max)',@Definition=@Definition;"
        )
        invalid_schema_setup = (
            "SET @Sql=N'USE '+QUOTENAME(@FixtureDatabase)+N'; CREATE SCHEMA '+QUOTENAME(@Schema)+N';'; "
            "EXEC [master].[sys].[sp_executesql] @Sql;"
        )
        assert fixture_schema_batch_error(valid_schema_setup) is None
        assert fixture_schema_batch_error(invalid_schema_setup) is not None
        lookup = (
            "FROM [sys].[all_objects] AS [o] WITH (NOLOCK) "
            "INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) "
            "INNER JOIN [sys].[all_columns] AS [c] WITH (NOLOCK) "
            "[o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''security_policies'' COLLATE SQL_Latin1_General_CP1_CS_AS "
            "[s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''sys'' COLLATE SQL_Latin1_General_CP1_CS_AS "
            "[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''is_schemabinding_enabled'' COLLATE SQL_Latin1_General_CP1_CS_AS"
        )
        field_source = lookup + " CASE WHEN @PolicyFieldAvailable=1 THEN N'[p].[is_schemabinding_enabled]' ELSE N'CAST(NULL AS bit)' END 'SOURCE_UNAVAILABLE','SECURITY_POLICIES',N'Die Katalogansicht stellt IsSchemabindingEnabled nicht bereit'"
        field_fixture = "@PolicyFieldA @PolicyFieldB @PolicyFieldEmpty <>7+CASE WHEN @PolicyFieldA=0 THEN 1 ELSE 0 END+CASE WHEN @PolicyFieldB=0 THEN 1 ELSE 0 END " + (lookup + " THEN N'[p].[is_schemabinding_enabled]' ELSE N'CAST(NULL AS bit)' END ") * 2 + lookup
        assert optional_policy_field_errors(field_source, field_fixture) == []
        assert optional_policy_field_errors(field_source.replace("CAST(NULL AS bit)", "NULL"), field_fixture)
        assert policy_field_lookup_errors(lookup, lookup * 3) == []
        assert policy_field_lookup_errors(lookup.replace("WITH (NOLOCK)", ""), lookup * 3)
        valid_predicate_source = "[p].[security_predicate_id]"
        valid_predicate_fixture = valid_predicate_source * 2
        assert predicate_id_mapping_errors(valid_predicate_source, valid_predicate_fixture) == []
        assert predicate_id_mapping_errors(valid_predicate_source.replace("security_predicate_id", "predicate_id"), valid_predicate_fixture)
        print("RLS and masking inventory validator self-test passed.")
        return 0
    errors = validate(args.repository_root.resolve())
    if errors:
        print("\n".join(f"ERROR: {item}" for item in errors), file=sys.stderr)
        return 1
    print("RLS and masking inventory contract is consistent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
