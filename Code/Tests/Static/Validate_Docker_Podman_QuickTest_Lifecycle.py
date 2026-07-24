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
    "Code/Tests/Static/Validate_Docker_Podman_QuickTest_Lifecycle.py",
    "Lab/Install-Lab.ps1",
    "Lab/Uninstall-Lab.ps1",
    "Lab/QuickTest/Private/LifecycleState.ps1",
    "Lab/QuickTest/Private/LifecycleRuntime.ps1",
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
    "Lab/Orchestration/Modules/DiagnosticLab/Public/Install-LabContainerFramework.ps1",
    "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psd1",
    "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psm1",
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


def read_text(root: Path, relative_path: str) -> str:
    return (root / relative_path).read_text(encoding="utf-8")


def require_fragments(
    content: str, fragments: tuple[str, ...], scope: str, findings: list[str]
) -> None:
    for fragment in fragments:
        require(fragment in content, f"{scope} lacks {fragment}.", findings)


def validate_entrypoint(root: Path, findings: list[str]) -> None:
    entry = read_text(root, "Lab/Install-Lab.ps1")
    loader = read_text(root, "Lab/QuickTest/QuickTestLab.psm1")
    require_fragments(
        entry,
        (
            "'Preflight', 'Install', 'Status', 'Stop', 'Down', 'Start', 'Destroy'",
            "Stop-QuickTestLab",
            "Start-QuickTestStoppedLab",
            "Start-QuickTestLab",
            "Get-QuickTestLabStatus",
            "Invoke-QuickTestLabDown",
            "Remove-QuickTestLab",
            "-Force is supported only with -Action Down or Destroy.",
        ),
        "Install-Lab.ps1",
        findings,
    )
    stop_position = entry.find("if ($Action -eq 'Stop')")
    runtime_prompt = entry.find("if (-not $PSBoundParameters.ContainsKey('Runtime'))")
    require(
        -1 not in (stop_position, runtime_prompt) and stop_position < runtime_prompt,
        "Stop is not dispatched before runtime and credential prompts.",
        findings,
    )
    start_position = entry.find("if ($Action -eq 'Start')")
    require(
        -1 not in (start_position, runtime_prompt) and start_position < runtime_prompt,
        "Start is not dispatched before install-time prompts.",
        findings,
    )
    require_fragments(
        loader,
        (
            "Public/Stop-QuickTestLab.ps1",
            "Public/Start-QuickTestStoppedLab.ps1",
            "'Stop-QuickTestLab'",
            "'Start-QuickTestStoppedLab'",
        ),
        "Quick-test module loader",
        findings,
    )


def validate_install(root: Path, findings: list[str]) -> None:
    install = read_text(root, "Lab/QuickTest/Public/Install-QuickTestLab.ps1")
    preflight = install.find("Invoke-QuickTestPreflight")
    approval = install.find("$PSCmdlet.ShouldProcess")
    state = install.find("LifecycleStatus = 'INSTALLING'")
    state_write = install.find("Write-QuickTestJson", state)
    compose = install.find("Invoke-QuickTestCompose", state_write)
    require(
        -1 not in (preflight, approval, state, state_write, compose)
        and preflight < approval < state < state_write < compose,
        "Install does not persist recovery state before Compose mutation.",
        findings,
    )
    require_fragments(
        install,
        (
            "LifecycleStatus = 'READY'",
            "LifecycleStatus = 'RECOVERY_CLEANUP'",
            "RecoveryContainerIds",
            "RecoveryNetworkIds",
            "Wait-QuickTestContainerHealthy",
            "SERVERPROPERTY('ProductMajorVersion')",
            "Install-LabContainerFramework",
        ),
        "Install lifecycle",
        findings,
    )


def validate_down(root: Path, findings: list[str]) -> None:
    down = read_text(root, "Lab/QuickTest/Public/Invoke-QuickTestLabDown.ps1")
    require_fragments(
        down,
        (
            "LifecycleStatus = 'DOWN_IN_PROGRESS'",
            "RecoveryContainerIds",
            "RecoveryNetworkIds",
            "Remove-QuickTestRuntimeResources",
            "PreviousContainerId",
            "PreviousNetworkId",
            "LifecycleStatus = 'DOWN'",
            "DataPreserved = $true",
            "StatePreserved = $true",
        ),
        "Down lifecycle",
        findings,
    )
    state = down.find("LifecycleStatus = 'DOWN_IN_PROGRESS'")
    state_write = down.find("Write-QuickTestJson", state)
    remove = down.find("Remove-QuickTestRuntimeResources", state_write)
    final = down.find("LifecycleStatus = 'DOWN'", remove)
    require(
        -1 not in (state, state_write, remove, final)
        and state < state_write < remove < final,
        "Down does not bracket removal with recovery state.",
        findings,
    )
    require("Remove-Item" not in down, "Down deletes local files.", findings)


def validate_stop(root: Path, findings: list[str]) -> None:
    stop = read_text(root, "Lab/QuickTest/Public/Stop-QuickTestLab.ps1")
    require_fragments(
        stop,
        (
            "function Stop-QuickTestLab",
            "STOP_STATE_INVALID",
            "STOP_SCOPE_CONFLICT",
            "LifecycleStatus = 'STOPPING'",
            "LifecycleStatus = 'STOPPED'",
            "LifecycleStatus = 'STOP_FAILED'",
            "container",
            "stop",
            "--time",
            "qt-lab.run-id",
            "qt-lab.owner",
            "SQL_SERVER_ANALYZE",
            "AlreadyStopped",
            "NetworkPreserved = $true",
            "DataPreserved = $true",
            "StatePreserved = $true",
        ),
        "Stop lifecycle",
        findings,
    )
    state = stop.find("LifecycleStatus = 'STOPPING'")
    state_write = stop.find("Write-QuickTestJson", state)
    mutation = stop.find("'stop'", state_write)
    final = stop.find("LifecycleStatus = 'STOPPED'", mutation)
    require(
        -1 not in (state, state_write, mutation, final)
        and state < state_write < mutation < final,
        "Stop does not persist STOPPING before runtime mutation.",
        findings,
    )
    require("Remove-Item" not in stop, "Stop deletes local files.", findings)
    for forbidden in ("prune", "compose down", "container rm", "network rm"):
        require(forbidden not in stop.lower(), f"Stop contains {forbidden}.", findings)


def validate_stopped_start(root: Path, findings: list[str]) -> None:
    start = read_text(root, "Lab/QuickTest/Public/Start-QuickTestStoppedLab.ps1")
    require_fragments(
        start,
        (
            "function Start-QuickTestStoppedLab",
            "LifecycleStatus -ne 'STOPPED'",
            "START_SCOPE_CONFLICT",
            "LifecycleStatus = 'STARTING'",
            "container', 'start'",
            "Wait-QuickTestContainerHealthy",
            "SERVERPROPERTY('ProductMajorVersion')",
            "FRAMEWORK_READY",
            "LifecycleStatus = 'READY'",
            "START_STOPPED_RECOVERY",
            "START_STOPPED_RECOVERY_FAILED",
            "LifecycleStatus = 'STOPPED'",
            "RecreatedContainers = $false",
            "LoadedStoredCredential = $false",
        ),
        "Stopped Start lifecycle",
        findings,
    )
    state = start.find("LifecycleStatus = 'STARTING'")
    state_write = start.find("Write-QuickTestJson", state)
    mutation = start.find("'start'", state_write)
    require(
        -1 not in (state, state_write, mutation) and state < state_write < mutation,
        "Stopped Start does not persist STARTING before runtime mutation.",
        findings,
    )
    recovery = start.find("START_STOPPED_RECOVERY")
    recovery_write = start.find("Write-QuickTestJson", recovery)
    recovery_stop = start.find("'stop'", recovery_write)
    require(
        -1 not in (recovery, recovery_write, recovery_stop)
        and recovery < recovery_write < recovery_stop,
        "Stopped Start recovery is not persisted before rollback.",
        findings,
    )
    require("Invoke-QuickTestCompose" not in start, "Stopped Start uses Compose.", findings)
    require("AdminSecret" not in start, "Stopped Start requests a credential.", findings)
    require("Remove-Item" not in start, "Stopped Start deletes local files.", findings)


def validate_status_and_destroy(root: Path, findings: list[str]) -> None:
    status = read_text(root, "Lab/QuickTest/Public/Get-QuickTestLabStatus.ps1")
    destroy = read_text(root, "Lab/QuickTest/Public/Remove-QuickTestLab.ps1")
    require_fragments(
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
    require_fragments(
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
    status = json.loads(
        read_text(root, "Metadata/Quality/Docker_Podman_Quick_Test_Status.json")
    )
    require(
        status.get("ContractStatus") == "IMPLEMENTED_ACTIONS_GATE"
        and status.get("RuntimeStatus") == "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING"
        and status.get("DataClassification") == "PUBLIC_AND_SYNTHETIC",
        "Quick-test status is missing or overstated.",
        findings,
    )
    delivered = " ".join(status.get("DeliveredScope", []))
    opened = " ".join(status.get("OpenScope", []))
    require_fragments(
        delivered,
        (
            "Install action",
            "Down action",
            "Start action",
            "Stop action",
            "Destroy action",
        ),
        "Delivered quick-test scope",
        findings,
    )
    require_fragments(
        opened,
        (
            "Restart and Reset",
            "UpdateFramework",
            "Native Docker runtime evidence",
            "Native Podman runtime evidence",
        ),
        "Open quick-test scope",
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
    lab_workflow = read_text(root, ".github/workflows/lab-contract-validation.yml")
    focused_workflow = read_text(
        root, ".github/workflows/quicktest-lifecycle-validation.yml"
    )
    tests = read_text(root, "Lab/Validation/Invoke-LabQuickTestStopTests.ps1")
    readme = read_text(root, "Lab/QuickTest/README.md")
    require_fragments(
        lab_workflow,
        (
            "Invoke-LabQuickTestStopTests.ps1",
            "Analyze quick-test Stop lifecycle",
            "Analyze stopped quick-test Start lifecycle",
        ),
        "LAB workflow",
        findings,
    )
    require_fragments(
        focused_workflow,
        (
            "Invoke-LabQuickTestStopTests.ps1",
            "Run focused Stop lifecycle contract",
        ),
        "Focused lifecycle workflow",
        findings,
    )
    require_fragments(
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
    require_fragments(
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

    for relative_path in sorted(REQUIRED_FILES):
        require(
            (root / relative_path).is_file(),
            f"Missing lifecycle file: {relative_path}",
            findings,
        )

    if not findings:
        validate_entrypoint(root, findings)
        validate_install(root, findings)
        validate_down(root, findings)
        validate_stop(root, findings)
        validate_stopped_start(root, findings)
        validate_status_and_destroy(root, findings)
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
