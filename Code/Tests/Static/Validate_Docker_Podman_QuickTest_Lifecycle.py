#!/usr/bin/env python3
"""Validate the bounded Docker/Podman quick-test runtime lifecycle."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

REQUIRED_FILES = {
    ".github/workflows/lab-contract-validation.yml",
    ".github/workflows/quicktest-lifecycle-validation.yml",
    "Lab/Install-Lab.ps1",
    "Lab/Uninstall-Lab.ps1",
    "Lab/QuickTest/Public/Install-QuickTestLab.ps1",
    "Lab/QuickTest/Public/Get-QuickTestLabStatus.ps1",
    "Lab/QuickTest/Public/Invoke-QuickTestLabDown.ps1",
    "Lab/QuickTest/Public/Start-QuickTestLab.ps1",
    "Lab/QuickTest/Public/Start-QuickTestStoppedLab.ps1",
    "Lab/QuickTest/Public/Stop-QuickTestLab.ps1",
    "Lab/QuickTest/Public/Remove-QuickTestLab.ps1",
    "Lab/QuickTest/QuickTestLab.psm1",
    "Lab/QuickTest/README.md",
    "Lab/Validation/Invoke-LabQuickTestLifecycleTests.ps1",
    "Lab/Validation/Invoke-LabQuickTestStopTests.ps1",
    "Metadata/Quality/Docker_Podman_Quick_Test_Status.json",
    "Metadata/Quality/Lab_External_Evidence_Gates.csv",
}

EXPECTED_GATES = {
    "LAB-GATE-QUICKTEST-DOCKER": "DOCKER_ENGINE",
    "LAB-GATE-QUICKTEST-PODMAN": "PODMAN_ENGINE",
}


def require(condition: bool, message: str, findings: list[str]) -> None:
    if not condition:
        findings.append(message)


def text(root: Path, path: str) -> str:
    return (root / path).read_text(encoding="utf-8")


def fragments(
    content: str, required: tuple[str, ...], scope: str, findings: list[str]
) -> None:
    for fragment in required:
        require(fragment in content, f"{scope} lacks {fragment}.", findings)


def validate_entrypoint(root: Path, findings: list[str]) -> None:
    entry = text(root, "Lab/Install-Lab.ps1")
    loader = text(root, "Lab/QuickTest/QuickTestLab.psm1")
    fragments(
        entry,
        (
            "'Preflight', 'Install', 'Status', 'Stop', 'Down', 'Start', 'Destroy'",
            "Stop-QuickTestLab",
            "Start-QuickTestStoppedLab",
            "Start-QuickTestLab",
            "Get-QuickTestLabStatus",
            "-Force is supported only with -Action Down or Destroy.",
        ),
        "Install entrypoint",
        findings,
    )
    prompt = entry.find("if (-not $PSBoundParameters.ContainsKey('Runtime'))")
    require(
        0 <= entry.find("if ($Action -eq 'Stop')") < prompt,
        "Stop is dispatched after install-time prompts.",
        findings,
    )
    require(
        0 <= entry.find("if ($Action -eq 'Start')") < prompt,
        "Start is dispatched after install-time prompts.",
        findings,
    )
    fragments(
        loader,
        (
            "Public/Stop-QuickTestLab.ps1",
            "Public/Start-QuickTestStoppedLab.ps1",
            "'Stop-QuickTestLab'",
            "'Start-QuickTestStoppedLab'",
        ),
        "Module loader",
        findings,
    )


def validate_install_down(root: Path, findings: list[str]) -> None:
    install = text(root, "Lab/QuickTest/Public/Install-QuickTestLab.ps1")
    preflight = install.find("Invoke-QuickTestPreflight")
    approval = install.find("$PSCmdlet.ShouldProcess")
    state = install.find("LifecycleStatus = 'INSTALLING'")
    write = install.find("Write-QuickTestJson", state)
    mutation = install.find("Invoke-QuickTestCompose", write)
    require(
        -1 not in (preflight, approval, state, write, mutation)
        and preflight < approval < state < write < mutation,
        "Install does not persist recovery state before mutation.",
        findings,
    )
    fragments(
        install,
        (
            "LifecycleStatus = 'READY'",
            "LifecycleStatus = 'RECOVERY_CLEANUP'",
            "RecoveryContainerIds",
            "RecoveryNetworkIds",
            "Wait-QuickTestContainerHealthy",
            "SERVERPROPERTY('ProductMajorVersion')",
        ),
        "Install lifecycle",
        findings,
    )

    down = text(root, "Lab/QuickTest/Public/Invoke-QuickTestLabDown.ps1")
    down_state = down.find("LifecycleStatus = 'DOWN_IN_PROGRESS'")
    down_write = down.find("Write-QuickTestJson", down_state)
    down_remove = down.find("Remove-QuickTestRuntimeResources", down_write)
    down_final = down.find("LifecycleStatus = 'DOWN'", down_remove)
    require(
        -1 not in (down_state, down_write, down_remove, down_final)
        and down_state < down_write < down_remove < down_final,
        "Down does not bracket removal with recovery state.",
        findings,
    )
    require("Remove-Item" not in down, "Down deletes local files.", findings)


def validate_stop(root: Path, findings: list[str]) -> None:
    stop = text(root, "Lab/QuickTest/Public/Stop-QuickTestLab.ps1")
    fragments(
        stop,
        (
            "STOP_STATE_INVALID",
            "STOP_SCOPE_CONFLICT",
            "LifecycleStatus = 'STOPPING'",
            "LifecycleStatus = 'STOPPED'",
            "LifecycleStatus = 'STOP_FAILED'",
            "'container'",
            "'stop'",
            "'--time'",
            "qt-lab.run-id",
            "qt-lab.owner",
            "SQL_SERVER_ANALYZE",
            "AlreadyStopped",
            "NetworkPreserved = $true",
            "DataPreserved = $true",
        ),
        "Stop lifecycle",
        findings,
    )
    state = stop.find("LifecycleStatus = 'STOPPING'")
    write = stop.find("Write-QuickTestJson", state)
    mutation = stop.find("'stop'", write)
    final = stop.find("LifecycleStatus = 'STOPPED'", mutation)
    require(
        -1 not in (state, write, mutation, final) and state < write < mutation < final,
        "Stop does not persist STOPPING before container stop.",
        findings,
    )
    require("Remove-Item" not in stop, "Stop deletes local files.", findings)
    for forbidden in ("prune", "compose down", "container rm", "network rm"):
        require(forbidden not in stop.lower(), f"Stop contains {forbidden}.", findings)


def validate_stopped_start(root: Path, findings: list[str]) -> None:
    start = text(root, "Lab/QuickTest/Public/Start-QuickTestStoppedLab.ps1")
    fragments(
        start,
        (
            "LifecycleStatus -ne 'STOPPED'",
            "START_SCOPE_CONFLICT",
            "LifecycleStatus = 'STARTING'",
            "'container', 'start'",
            "Wait-QuickTestContainerHealthy",
            "SERVERPROPERTY('ProductMajorVersion')",
            "FRAMEWORK_READY",
            "LifecycleStatus = 'READY'",
            "START_STOPPED_RECOVERY",
            "START_STOPPED_RECOVERY_FAILED",
            "RecreatedContainers = $false",
            "LoadedStoredCredential = $false",
        ),
        "Stopped Start lifecycle",
        findings,
    )
    state = start.find("LifecycleStatus = 'STARTING'")
    write = start.find("Write-QuickTestJson", state)
    mutation = start.find("'start'", write)
    require(
        -1 not in (state, write, mutation) and state < write < mutation,
        "Stopped Start does not persist STARTING before container start.",
        findings,
    )
    recovery = start.find("START_STOPPED_RECOVERY")
    recovery_write = start.find("Write-QuickTestJson", recovery)
    rollback = start.find("'stop'", recovery_write)
    require(
        -1 not in (recovery, recovery_write, rollback)
        and recovery < recovery_write < rollback,
        "Stopped Start recovery is not persisted before rollback.",
        findings,
    )
    require("Invoke-QuickTestCompose" not in start, "Stopped Start uses Compose.", findings)
    require("AdminSecret" not in start, "Stopped Start requests a credential.", findings)
    require("Remove-Item" not in start, "Stopped Start deletes local files.", findings)


def validate_status_destroy(root: Path, findings: list[str]) -> None:
    status = text(root, "Lab/QuickTest/Public/Get-QuickTestLabStatus.ps1")
    fragments(
        status,
        (
            "Status = 'DOWN'",
            "'READY'",
            "'STOPPED'",
            "Stopped = $stopped",
            "NetworkPreserved",
            "OwnershipValid",
        ),
        "Status lifecycle",
        findings,
    )
    destroy = text(root, "Lab/QuickTest/Public/Remove-QuickTestLab.ps1")
    fragments(
        destroy,
        (
            "DESTROY_CONFIRMATION_REQUIRED",
            "Remove-QuickTestRuntimeResources",
            "Test-QuickTestOwnedDirectory",
            "Status = 'DESTROYED'",
            "DataRemoved = $true",
        ),
        "Destroy lifecycle",
        findings,
    )
    require("RemoveData" not in destroy, "Destroy exposes partial cleanup.", findings)


def validate_metadata(root: Path, findings: list[str]) -> None:
    status = json.loads(text(root, "Metadata/Quality/Docker_Podman_Quick_Test_Status.json"))
    require(
        status.get("ContractStatus") == "IMPLEMENTED_ACTIONS_GATE"
        and status.get("RuntimeStatus") == "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING"
        and status.get("DataClassification") == "PUBLIC_AND_SYNTHETIC",
        "Quick-test status is missing or overstated.",
        findings,
    )
    delivered = " ".join(status.get("DeliveredScope", []))
    opened = " ".join(status.get("OpenScope", []))
    fragments(
        delivered,
        ("Install action", "Stop action", "Down action", "Start action", "Destroy action"),
        "Delivered scope",
        findings,
    )
    fragments(
        opened,
        ("Restart and Reset", "UpdateFramework", "Native Docker runtime evidence", "Native Podman runtime evidence"),
        "Open scope",
        findings,
    )
    require("Stop action" not in opened, "Delivered Stop remains open.", findings)

    with (root / "Metadata/Quality/Lab_External_Evidence_Gates.csv").open(
        newline="", encoding="utf-8"
    ) as handle:
        gates = {row["GateId"]: row for row in csv.DictReader(handle)}
    for gate_id, capability in EXPECTED_GATES.items():
        row = gates.get(gate_id, {})
        require(
            row.get("RequiredCapability") == capability
            and row.get("Status") == "NOT_EXECUTED"
            and row.get("EvidencePolicy") == "SYNTHETIC_SUMMARY_ONLY",
            f"{gate_id} overstates external evidence.",
            findings,
        )


def validate_integration(root: Path, findings: list[str]) -> None:
    lab = text(root, ".github/workflows/lab-contract-validation.yml")
    focused = text(root, ".github/workflows/quicktest-lifecycle-validation.yml")
    tests = text(root, "Lab/Validation/Invoke-LabQuickTestStopTests.ps1")
    readme = text(root, "Lab/QuickTest/README.md")
    require(
        "Validate_Docker_Podman_QuickTest_Lifecycle.py" in lab,
        "LAB workflow no longer runs the lifecycle validator.",
        findings,
    )
    fragments(
        focused,
        (
            "Invoke-LabQuickTestStopTests.ps1",
            "Run focused Stop lifecycle contract",
            "Analyze quick-test Stop lifecycle",
            "Analyze stopped quick-test Start lifecycle",
        ),
        "Focused lifecycle workflow",
        findings,
    )
    fragments(
        tests,
        (
            "LifecycleStatus\": \"STOPPING",
            "LifecycleStatus\": \"STARTING",
            "Stop-QuickTestLab",
            "Start-QuickTestStoppedLab",
            "Status -ne 'STOPPED'",
            "RecreatedContainers",
            "container stop",
            "container start",
        ),
        "Stop tests",
        findings,
    )
    fragments(
        readme,
        (
            "## Stop",
            "## Start",
            "STOPPED",
            "does not remove",
            "without requiring the SQL credential",
            "Destroy always removes the complete scope",
            "NOT_EXECUTED",
        ),
        "Quick-test README",
        findings,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=".")
    args = parser.parse_args()
    root = Path(args.repository_root).resolve()
    findings: list[str] = []
    for path in sorted(REQUIRED_FILES):
        require((root / path).is_file(), f"Missing lifecycle file: {path}", findings)
    if not findings:
        validate_entrypoint(root, findings)
        validate_install_down(root, findings)
        validate_stop(root, findings)
        validate_stopped_start(root, findings)
        validate_status_destroy(root, findings)
        validate_metadata(root, findings)
        validate_integration(root, findings)
    if findings:
        for finding in findings:
            print(f"ERROR: {finding}")
        return 1
    print(
        "Docker/Podman quick-test lifecycle validated: "
        "actions=Install,Status,Stop,Down,Start,Destroy "
        "external_evidence=NOT_EXECUTED."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
