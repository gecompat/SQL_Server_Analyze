#!/usr/bin/env python3
"""Validate the executable contracts added for the maturity-closeout wave."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


OPS_RUNTIME_CONTRACTS = {
    "Code/Tests/ServerHealth/120_OPS005_Linked_Server_Runtime_Contract.sql": (
        "ExampleOps005Linked",
        "AUTHORIZATION_REQUIRED",
        "sp_dropserver",
    ),
    "Code/Tests/ServerHealth/121_OPS006_Database_Portability_Runtime_Contract.sql": (
        "ExampleOps006Portable",
        "ExampleOps006Uncontained",
        "UNCONTAINED_ENTITY",
        "EXEC(N''CREATE OR ALTER PROCEDURE",
    ),
    "Code/Tests/ServerHealth/122_OPS008_Msdb_Health_Runtime_Contract.sql": (
        "USP_MsdbHealthAnalysis",
        "DATABASE_SIZE",
        "EXECUTE AS USER",
    ),
    "Code/Tests/CurrentState/120_OPS007_Current_Cursor_Runtime_Contract.sql": (
        "NOT_EXECUTED",
        "INVALID_PARAMETER",
        "DECLARE [ExampleOps007Cursor] CURSOR",
    ),
    "Code/Tests/ServerHealth/123_OPS009_System_Database_Objects_Runtime_Contract.sql": (
        "ExampleOps009Object",
        "master",
        "model",
        "msdb",
    ),
}

DEEP_REVIEWED_PROCEDURES = {
    "USP_CreateExecutionEvidenceJson",
    "USP_ExecutionPlanAnalysis",
    "USP_ConfigureSnapshotTarget",
    "USP_RunSnapshotCollectionCycle",
    "USP_PurgeSnapshotData",
    "USP_VectorIndexAnalysis",
    "USP_QueryStoreReplicaAnalysis",
    "USP_LinkedServerAnalysis",
    "USP_DatabasePortabilityAnalysis",
    "USP_MsdbHealthAnalysis",
    "USP_CurrentCursorAnalysis",
    "USP_SystemDatabaseObjectInventory",
}

LAB_EXAMPLES = {
    "BLOCKING-001": "Blocking",
    "QUERY-STORE-001": "QUERY-STORE-001",
    "TEMPDB-001": "TEMPDB-001",
    "STATISTICS-001": "STATISTICS-001",
    "MEMORY-GRANTS-001": "MEMORY-GRANTS-001",
    "EXECUTION-PLAN-001": "EXECUTION-PLAN-001",
    "INDEX-USAGE-001": "INDEX-USAGE-001",
}

COLLATION_SLICES = {
    "Code/08_ServerHealth/220_USP_LinkedServerAnalysis.sql": 6,
    "Code/08_ServerHealth/200_USP_DatabasePortabilityAnalysis.sql": 10,
    "Code/08_ServerHealth/210_USP_MsdbHealthAnalysis.sql": 8,
    "Code/02_CurrentState/110_USP_CurrentCursorAnalysis.sql": 3,
    "Code/08_ServerHealth/230_USP_SystemDatabaseObjectInventory.sql": 6,
    "Code/02_CurrentState/100_USP_CurrentOverview.sql": 15,
}


def missing_tokens(text: str, tokens: tuple[str, ...]) -> list[str]:
    return [token for token in tokens if token not in text]


def validate_repository(root: Path) -> list[str]:
    errors: list[str] = []
    release_gate = (root / "Code/Tests/Run_Release_Gate.sql").read_text(
        encoding="utf-8-sig"
    )
    for relative_path, tokens in OPS_RUNTIME_CONTRACTS.items():
        path = root / relative_path
        if not path.is_file():
            errors.append(f"missing OPS runtime contract: {relative_path}")
            continue
        text = path.read_text(encoding="utf-8-sig")
        if not text.startswith("USE [DeineDatenbank];\nGO\n"):
            errors.append(f"OPS runtime contract lacks canonical header: {relative_path}")
        for token in missing_tokens(text, tokens):
            errors.append(f"OPS runtime contract missing {token}: {relative_path}")
        if Path(relative_path).name not in release_gate:
            errors.append(f"release gate does not include {relative_path}")

    review_path = root / "Metadata/Quality/Analysis_Documentation_Review.csv"
    with review_path.open(encoding="utf-8-sig", newline="") as handle:
        review_rows = {row["ProcedureName"]: row for row in csv.DictReader(handle)}
    for procedure in DEEP_REVIEWED_PROCEDURES:
        row = review_rows.get(procedure)
        if row is None:
            errors.append(f"documentation review row missing: {procedure}")
        elif row.get("ReviewStatus") != "DEEP_REVIEWED" or row.get(
            "ReviewContractVersion"
        ) != "3":
            errors.append(f"documentation review is not v3 deep-reviewed: {procedure}")

    catalog_path = root / "TestLab/Catalog/examples.json"
    catalog_text = catalog_path.read_text(encoding="utf-8-sig")
    runner_text = (root / "TestLab/Test-AnalyzeExample.ps1").read_text(
        encoding="utf-8-sig"
    )
    start_runner_text = (root / "TestLab/Start-AnalyzeExample.ps1").read_text(
        encoding="utf-8-sig"
    )
    for example, documentation_directory in LAB_EXAMPLES.items():
        if f'"id": "{example}"' not in catalog_text:
            errors.append(f"Analyze example missing from catalog: {example}")
        if not (
            root / f"TestLab/Examples/{documentation_directory}/README.md"
        ).is_file():
            errors.append(f"Analyze example README missing: {example}")
    if "[string] $Example = 'BLOCKING-001'" not in runner_text:
        errors.append("Analyze validator lacks selectable example parameter")
    if "-Example $Example" not in runner_text:
        errors.append("Analyze validator does not pass selected example to runtime")
    if "$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())" not in start_runner_text:
        errors.append("Analyze runner does not pin its allowed temporary root")
    if start_runner_text.count("-AllowedRoot $systemTempRoot") < 4:
        errors.append("Analyze runner recalculates a mutable temporary root")
    if "($Mode -eq 'Verify' -or $failed)" not in start_runner_text:
        errors.append("Analyze runner does not clean up failed Interactive setup")
    shared_setup_text = (
        root / "Lab/Scenarios/Performance/_Shared/Setup.sql"
    ).read_text(encoding="utf-8-sig")
    if (
        "EXEC [dbo].[LabQueryStoreProcedure]\n"
        "          @GroupId = CASE" in shared_setup_text
    ):
        errors.append("Query Store setup passes an unsupported CASE expression to EXEC")
    shared_observe_text = (
        root / "Lab/Scenarios/Performance/_Shared/Observe.sql"
    ).read_text(encoding="utf-8-sig")
    for token in (
        "[tempdb].[sys].[dm_db_session_space_usage]",
        "[tempdb].[sys].[dm_db_task_space_usage]",
    ):
        if token not in shared_observe_text:
            errors.append(f"TempDB example lacks allocation evidence source: {token}")
    if "('AVAILABLE', 'AVAILABLE_LIMITED', 'PARTIAL')" not in shared_observe_text:
        errors.append("Analyze examples do not accept the public PARTIAL status")
    if "@PlanQuelle = 'IMPORTED'" in shared_observe_text:
        errors.append("Execution Plan example passes a derived source as input")

    collation = "COLLATE SQL_Latin1_General_CP1_CS_AS"
    for relative_path, minimum_count in COLLATION_SLICES.items():
        text = (root / relative_path).read_text(encoding="utf-8-sig")
        if text.count(collation) < minimum_count:
            errors.append(
                f"collation boundary is not explicit enough: {relative_path}"
            )
    table_output_contract = (
        root / "Code/Tests/Integration/187_Table_Output_Runtime_Contract.sql"
    ).read_text(encoding="utf-8-sig")
    for token in ("COLLATION_MISMATCH_SAFE", "[c].[collation_name]"):
        if token not in table_output_contract:
            errors.append(f"TABLE collation contract missing token: {token}")
    return sorted(set(errors))


def self_test() -> None:
    if missing_tokens("alpha beta", ("alpha", "beta")):
        raise AssertionError("valid token fixture was rejected")
    if missing_tokens("alpha", ("alpha", "beta")) != ["beta"]:
        raise AssertionError("missing token fixture was accepted")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        print("Maturity-closeout contract validator self-test passed.")
        return 0
    errors = validate_repository(args.repository_root.resolve())
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Maturity-closeout contracts are consistent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
