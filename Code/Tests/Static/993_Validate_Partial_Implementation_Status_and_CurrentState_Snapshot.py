#!/usr/bin/env python3
"""Validate canonical partial-implementation status and Current-State snapshot slice."""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


ALLOWED_PRODUCT_STATUS = {
    "IMPLEMENTED_ACTIONS_GATE",
    "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING",
    "PARTIAL_PRODUCT_FUNCTION",
    "RESEARCHED_NOT_IMPLEMENTED",
    "OPTIONAL_FUTURE",
}
REQUIRED_STATUS = {
    "DIAG-003": "IMPLEMENTED_ACTIONS_GATE",
    "DIAG-004": "PARTIAL_PRODUCT_FUNCTION",
    "DIAG-005": "PARTIAL_PRODUCT_FUNCTION",
    "RUNTIME-001": "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING",
    "SC-023": "IMPLEMENTED_ACTIONS_GATE",
    "SC-023-EXPANSION": "OPTIONAL_FUTURE",
}
OWNER_SINGLE_READS = (
    "FROM [sys].[dm_exec_sessions]",
    "FROM [sys].[dm_exec_requests]",
    "FROM [sys].[dm_exec_connections]",
    "FROM [sys].[dm_os_waiting_tasks]",
    "FROM [sys].[dm_exec_query_memory_grants]",
    "FROM [sys].[dm_resource_governor_workload_groups]",
    "FROM [sys].[dm_resource_governor_resource_pools]",
    "OUTER APPLY [sys].[dm_exec_sql_text]",
)


def fail(code: str, location: str) -> None:
    print(
        f"Status-/Current-State-Snapshot-Vertrag verletzt: "
        f"code={code} location={location}",
        file=sys.stderr,
    )
    raise SystemExit(1)


def self_test() -> None:
    if len(ALLOWED_PRODUCT_STATUS) != 5:
        fail("SELF_TEST_STATUS_COUNT", "ALLOWED_PRODUCT_STATUS")
    if REQUIRED_STATUS["RUNTIME-001"] not in ALLOWED_PRODUCT_STATUS:
        fail("SELF_TEST_RUNTIME_STATUS", "REQUIRED_STATUS")
    print("Status/snapshot validator self-test passed: cases=2 findings=0")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=".")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    root = Path(args.repository_root).resolve()
    status_path = root / "Metadata/Quality/Implementation_Status.csv"
    with status_path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    indexed = {row["WorkItemId"]: row for row in rows}
    for work_item, expected in REQUIRED_STATUS.items():
        row = indexed.get(work_item)
        if row is None:
            fail("STATUS_ROW_MISSING", work_item)
        actual = row["ProductStatus"]
        if actual != expected:
            fail("STATUS_MISMATCH", f"{work_item}:{actual}")
        if actual not in ALLOWED_PRODUCT_STATUS:
            fail("STATUS_UNKNOWN", f"{work_item}:{actual}")

    model = (
        root / "Documentation/Architecture/Implementation_Status_Model.md"
    ).read_text(encoding="utf-8-sig")
    for status in sorted(ALLOWED_PRODUCT_STATUS):
        if f"`{status}`" not in model:
            fail("STATUS_MODEL_TOKEN", status)

    with (
        root / "Metadata/Quality/Future_Enhancement_Backlog.csv"
    ).open(encoding="utf-8", newline="") as handle:
        future = {row["EnhancementId"]: row for row in csv.DictReader(handle)}
    expected_future = {
        "DIAG-003": "IMPLEMENTED_ACTIONS_GATE",
        "DIAG-004": "PARTIAL_PRODUCT_FUNCTION",
        "DIAG-005": "PARTIAL_PRODUCT_FUNCTION",
    }
    for work_item, expected in expected_future.items():
        if future[work_item]["ImplementationStatus"] != expected:
            fail("FUTURE_BACKLOG_STATUS", work_item)

    diagnostic = (
        root
        / "AI_Metadata/Internal_Documentation/Architecture/"
        "Diagnostic_Information_Enrichment_Backlog.md"
    ).read_text(encoding="utf-8-sig")
    for token in (
        "DIAG-003: `IMPLEMENTED_ACTIONS_GATE`",
        "Status: `IMPLEMENTED_ACTIONS_GATE`",
        "Post-Candidate-Quelle",
        "USP_CurrentSessions",
        "USP_CurrentRequests",
    ):
        if token not in diagnostic:
            fail("DIAGNOSTIC_BACKLOG_CONTRACT", token)

    snapshot_contract = (
        root / "Documentation/Architecture/Snapshot_Baseline_Package_Contract.md"
    ).read_text(encoding="utf-8-sig")
    for token in ("IMPLEMENTED_ACTIONS_GATE", "OPTIONAL_FUTURE"):
        if token not in snapshot_contract:
            fail("SNAPSHOT_PRODUCT_STATUS", token)

    with (
        root / "Metadata/Quality/External_Evidence_Gates.csv"
    ).open(encoding="utf-8", newline="") as handle:
        external = {row["GateId"]: row for row in csv.DictReader(handle)}
    runtime_gate = external.get("RUNTIME-EXTERNAL-001")
    if runtime_gate is None:
        fail("RUNTIME_EXTERNAL_GATE", "missing")
    if (
        runtime_gate["BacklogId"] != "RUNTIME-001"
        or runtime_gate["ExecutionStatus"] != "NOT_EXECUTED"
        or runtime_gate["CommitSha"] != "NOT_EXECUTED"
    ):
        fail("RUNTIME_EXTERNAL_GATE", "invalid-state")

    runtime = (
        root / "Documentation/Architecture/External_Runtime_CLR_Analysis_Plan.md"
    ).read_text(encoding="utf-8-sig")
    if "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING" not in runtime:
        fail("RUNTIME_STATUS", "External_Runtime_CLR_Analysis_Plan.md")

    feature_inventory = (
        root / "Code/09_VersionAdaptive/020_USP_SpecialFeatureInventory.sql"
    ).read_text(encoding="utf-8-sig")
    encryption_contract = (
        "N''USP_EncryptionAnalysis'',''IMPLEMENTED''"
    )
    if encryption_contract not in feature_inventory:
        fail("ENCRYPTION_ROUTING_STATUS", "USP_SpecialFeatureInventory")

    owner_path = root / "Code/02_CurrentState/005_InternalCaptureCurrentStateSnapshot.sql"
    owner = owner_path.read_text(encoding="utf-8-sig")
    for token in OWNER_SINGLE_READS:
        if owner.count(token) != 1:
            fail("OWNER_SOURCE_READ_COUNT", f"{token}:{owner.count(token)}")
    for token in (
        "#CurrentOverview_CurrentStateSnapshot_SourceStatus",
        "@CaptureSqlText",
        "@MaxSqlTextHandles",
        "AVAILABLE_LIMITED",
    ):
        if token not in owner:
            fail("OWNER_CONTRACT_TOKEN", token)

    if "dm_exec_input_buffer" in owner:
        fail("OWNER_PRE_CANDIDATE_INPUT_BUFFER", owner_path.name)

    overview = (
        root / "Code/02_CurrentState/100_USP_CurrentOverview.sql"
    ).read_text(encoding="utf-8-sig")
    if overview.count("EXEC [monitor].[InternalCaptureCurrentStateSnapshot]") != 1:
        fail("OWNER_CALL_COUNT", "USP_CurrentOverview")
    if overview.count("@ParentCurrentStateSnapshotId=@SnapshotConsumerId") != 2:
        fail("PRIMARY_CONSUMER_COUNT", "USP_CurrentOverview")
    if overview.find("InternalCaptureCurrentStateSnapshot") > overview.find(
        "EXEC [monitor].[USP_CurrentSessions]"
    ):
        fail("OWNER_ORDER", "USP_CurrentOverview")
    for token in ("snapshotStatus", "#CurrentOverview_SnapshotStatus"):
        if token not in overview:
            fail("SNAPSHOT_STATUS_OUTPUT", token)

    for relative, local_source in (
        ("Code/02_CurrentState/010_USP_CurrentSessions.sql", "#CurrentSessions_SourceSessions"),
        ("Code/02_CurrentState/020_USP_CurrentRequests.sql", "#CurrentRequests_SourceRequests"),
    ):
        text = (root / relative).read_text(encoding="utf-8-sig")
        for token in (
            "@ParentCurrentStateSnapshotId",
            "INVALID_PARENT_SNAPSHOT",
            "#CurrentOverview_CurrentStateSnapshot_Context",
            local_source,
        ):
            if token not in text:
                fail("CONSUMER_CONTRACT_TOKEN", f"{relative}:{token}")

    requests = (
        root / "Code/02_CurrentState/020_USP_CurrentRequests.sql"
    ).read_text(encoding="utf-8-sig")
    input_buffer_token = "OUTER APPLY [sys].[dm_exec_input_buffer]"
    if requests.count(input_buffer_token) != 1:
        fail("POST_CANDIDATE_INPUT_BUFFER_COUNT", str(requests.count(input_buffer_token)))
    if requests.find(input_buffer_token) < requests.find(
        "INSERT [#CurrentRequests_Result]"
    ):
        fail("POST_CANDIDATE_INPUT_BUFFER_ORDER", "USP_CurrentRequests")

    inventory = (
        root / "Metadata/Inventory/ResultSets.csv"
    ).read_text(encoding="utf-8-sig")
    if "USP_CurrentOverview,snapshotStatus,0,1,1" not in inventory:
        fail("RESULTSET_INVENTORY", "USP_CurrentOverview/snapshotStatus")
    snapshot_inventory_row = next(
        line for line in inventory.splitlines()
        if line.startswith("USP_CurrentOverview,snapshotStatus,")
    )
    if "[SnapshotId] uniqueidentifier NOT NULL" not in snapshot_inventory_row:
        fail("RESULTSET_SNAPSHOT_ID", "USP_CurrentOverview/snapshotStatus")

    installer = (root / "Code/Install/Install_All.sql").read_text(
        encoding="utf-8-sig"
    )
    owner_pos = installer.find("005_InternalCaptureCurrentStateSnapshot.sql")
    session_pos = installer.find("010_USP_CurrentSessions.sql")
    if owner_pos < 0 or session_pos < 0 or owner_pos > session_pos:
        fail("INSTALL_ORDER", "Install_All.sql")

    release_gate = (root / "Code/Tests/Run_Release_Gate.sql").read_text(
        encoding="utf-8-sig"
    )
    if "199_CurrentState_Snapshot_Runtime_Contract.sql" not in release_gate:
        fail("RUNTIME_GATE_ENTRY", "Run_Release_Gate.sql")
    if "121_DIAG003_Parameter_Evidence_Runtime_Contract.sql" not in release_gate:
        fail("DIAG003_RUNTIME_GATE_ENTRY", "Run_Release_Gate.sql")

    print(
        "Status/snapshot contracts passed: status_rows=6 diag003=implemented external_gates=1 owner_sources=8 "
        "primary_consumers=2 findings=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
