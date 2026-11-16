#!/usr/bin/env python3
"""Validate the bounded current-caller OBJECT permission report and bindings."""
from __future__ import annotations

import argparse
import csv
from pathlib import Path
import re
import sys

SOURCE = "Code/08_ServerHealth/281_USP_CurrentObjectPermissionAnalysis.sql"
NATIVE = "Code/Tests/ServerHealth/145_CurrentObjectPermission_Runtime_Contract.sql"
GUIDE = "Documentation/Analysis_Guides/Procedures/USP_CurrentObjectPermissionAnalysis.md"
INSTALL = "Code/Install/Install_All.sql"
GATE = "Code/Tests/Run_Release_Gate.sql"
OBJECTS = "Metadata/Inventory/Objects.csv"
PARAMETERS = "Metadata/Inventory/Parameters.csv"
RESULTS = "Metadata/Inventory/ResultSets.csv"
GROUPS = ("moduleStatus", "callerContexts", "objectPermissions", "sourceStatus", "warnings")
SIGNATURE = (
    ("DatabaseNames", "nvarchar(max)", "NULL"),
    ("SystemdatenbankenEinbeziehen", "bit", "0"),
    ("DatabaseNamePattern", "nvarchar(4000)", "NULL"),
    ("SchemaName", "nvarchar(max)", "NULL"),
    ("ObjectName", "nvarchar(max)", "NULL"),
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
)


def read(root: Path, path: str) -> str:
    return (root / path).read_text(encoding="utf-8-sig")


def rows(root: Path, path: str) -> list[dict[str, str]]:
    with (root / path).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def require(condition: bool, label: str, errors: list[str]) -> None:
    if not condition:
        errors.append(label)


def validate(root: Path, overrides: dict[str, str] | None = None) -> list[str]:
    overrides = overrides or {}
    errors: list[str] = []
    text = {p: overrides.get(p) if p in overrides else read(root, p)
            for p in (SOURCE, NATIVE, GUIDE, INSTALL, GATE)}
    source, native, guide, install, gate = (text[p] for p in (SOURCE, NATIVE, GUIDE, INSTALL, GATE))
    require(source.startswith("USE [DeineDatenbank];\nGO"), "source header", errors)
    require("CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentObjectPermissionAnalysis]" in source, "public procedure", errors)
    for name, data_type, default in SIGNATURE:
        signature = re.compile(r"@" + re.escape(name) + r"\s+" + re.escape(data_type)
                               + r"\s*=\s*" + re.escape(default) + r"(?=\s|,|\r|$)", re.I)
        require(bool(signature.search(source)), "signature: " + name, errors)
        require("| `@" + name + "` |" in guide, "guide parameter: " + name, errors)
        require("PRINT N'@" + name + " " in source, "help parameter: " + name, errors)
    for name in ("SchemaName", "ObjectName"):
        require("DATALENGTH(@" + name + ")>256" in source, "untruncated raw name: " + name, errors)
        require("QUOTENAME(CONVERT(sysname,@" + name + "))" in source, "quoted exact name: " + name, errors)
    require("DATALENGTH(@QuotedSchema+N'.'+@QuotedObject)>256" in source, "qualified sysname capacity", errors)
    require("[sys].[fn_my_permissions](@TargetObject,N''OBJECT'')" in source, "caller-context native OBJECT source", errors)
    require("EXECUTE AS" not in source.upper(), "no impersonation", errors)
    require("InternalPrepareResultTables" in source and "InternalWriteResultTable" in source
            and "InternalEmitConsoleResult" in source, "result helpers", errors)
    for group in GROUPS:
        require("CREATE TABLE [#CurrentObjectPermissionAnalysis_" + group + "]" in source,
                "source group: " + group, errors)
        require(group in guide, "guide group: " + group, errors)
    require("OBJECT_CURRENT_PERMISSIONS" in source and "EMPTY_UNPROVEN" in source
            and "ERROR_HANDLED" in source, "source evidence limits", errors)
    require("IF @Hilfe=1" in source and "RETURN 0;" in source, "help early return", errors)
    require("@MaxZeilen IS NULL OR @MaxZeilen=0" in source, "unlimited NULL/0 limit", errors)
    require("ROLLBACK TRANSACTION" in native and "SELECT @BeforeXact=XACT_STATE();" in native
            and "SELECT @BeforeTran=@@TRANCOUNT;" in native, "isolated caller transaction checks", errors)
    require("CREATE DATABASE" in native and "CREATE LOGIN" in native
            and "DENY SELECT ON OBJECT::" in native, "owned positive and denied native cases", errors)
    require("sys.fn_my_permissions(N''[dbo].[ExampleObjectProbe]'',N''OBJECT'')" in native,
            "independent native OBJECT parity", errors)
    require("OBJECT_FIXTURE_DIRECT_DENY_229" in native and "OBJECT_FIXTURE_OWNED_OBJECTS_REMAIN" in native,
            "direct deny and owned cleanup", errors)
    require(install.count(":r ../08_ServerHealth/281_USP_CurrentObjectPermissionAnalysis.sql") == 1,
            "installer source once", errors)
    require(gate.count(":r ServerHealth/145_CurrentObjectPermission_Runtime_Contract.sql") == 1,
            "native release gate once", errors)
    object_rows = rows(root, OBJECTS)
    require(sum(row["ObjectType"] == "PROCEDURE" and row["ObjectName"] == "USP_CurrentObjectPermissionAnalysis"
                and row["SourcePath"] == SOURCE for row in object_rows) == 1, "object inventory", errors)
    parameter_rows = [row for row in rows(root, PARAMETERS)
                      if row["ProcedureName"] == "USP_CurrentObjectPermissionAnalysis"]
    require([(row["ParameterName"], row["DataType"], row["DefaultExpression"]) for row in parameter_rows]
            == list(SIGNATURE), "parameter inventory", errors)
    result_rows = [row for row in rows(root, RESULTS)
                   if row["ProcedureName"] == "USP_CurrentObjectPermissionAnalysis"]
    require([row["ResultName"] for row in result_rows] == list(GROUPS), "result group inventory", errors)
    for row in result_rows:
        require(row["SourceTable"] == "#CurrentObjectPermissionAnalysis_" + row["ResultName"]
                and row["IsRawExportable"] == "1" and row["IsTableExportable"] == "1"
                and row["SchemaVersion"] == "1", "result contract: " + row["ResultName"], errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    root = args.repository_root.resolve()
    errors = validate(root)
    if args.self_test and not errors:
        source = read(root, SOURCE)
        native = read(root, NATIVE)
        for path, before, after, label in (
            (SOURCE, "DATALENGTH(@SchemaName)>256", "LEN(@SchemaName)>128", "raw capacity"),
            (SOURCE, "[sys].[fn_my_permissions](@TargetObject,N''OBJECT'')",
             "[sys].[fn_my_permissions](@TargetObject,N''DATABASE'')", "native class"),
            (NATIVE, "OBJECT_FIXTURE_DIRECT_DENY_229", "OBJECT_FIXTURE_DIRECT_DENY_0", "direct deny"),
            (INSTALL, ":r ../08_ServerHealth/281_USP_CurrentObjectPermissionAnalysis.sql",
             ":r ../08_ServerHealth/missing.sql", "installer source"),
            (GATE, ":r ServerHealth/145_CurrentObjectPermission_Runtime_Contract.sql",
             ":r ServerHealth/missing.sql", "release gate"),
        ):
            original = read(root, path)
            if before not in original:
                errors.append("self-test marker missing: " + label)
                continue
            mutant = original.replace(before, after, 1)
            if not validate(root, {path: mutant}):
                errors.append("self-test did not reject: " + label)
    if errors:
        for error in errors:
            print("ERROR: " + error, file=sys.stderr)
        return 1
    print("PASS: current-caller OBJECT permission source, native evidence, metadata and deployment bindings.")
    if args.self_test:
        print("PASS: bounded contract mutations were rejected.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
