#!/usr/bin/env python3
"""Validate the bounded Docker/Podman quick-test runtime lifecycle."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


REQUIRED_FILES = {
    ".github/workflows/lab-contract-validation.yml",
    "Code/Tests/Static/Validate_Docker_Podman_QuickTest_Lifecycle.py",
    "Lab/Install-Lab.ps1",
    "Lab/Uninstall-Lab.ps1",
    "Lab/QuickTest/Private/LifecycleState.ps1",
    "Lab/QuickTest/Private/LifecycleRuntime.ps1",
    "Lab/QuickTest/Public/Install-QuickTestLab.ps1",
    "Lab/QuickTest/Public/Get-QuickTestLabStatus.ps1",
    "Lab/QuickTest/Public/Remove-QuickTestLab.ps1",
    "Lab/QuickTest/QuickTestLab.psm1",
    "Lab/QuickTest/README.md",
    "Lab/Orchestration/Modules/DiagnosticLab/Public/Install-LabContainerFramework.ps1",
    "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psd1",
    "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psm1",
    "Lab/Validation/Invoke-LabQuickTestLifecycleTests.ps1",
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


def require_fragments(
    content: str, fragments: tuple[str, ...], scope: str, findings: list[str]
) -> None:
    for fragment in fragments:
        require(fragment in content, f"{scope} lacks {fragment}.", findings)


def validate_entrypoints(root: Path, findings: list[str]) -> None:
    entry = text(root, "Lab/Install-Lab.ps1")
    uninstall = text(root, "Lab/Uninstall-Lab.ps1")
    loader = text(root, "Lab/QuickTest/QuickTestLab.psm1")

    require_fragments(
        entry,
        (
            "'Preflight', 'Install', 'Status', 'Destroy'",
            "SupportsShouldProcess",
            "Install-QuickTestLab",
            "Get-QuickTestLabStatus",
            "Remove-QuickTestLab",
            "InstallFramework",
            "PersistGeneratedCredential",
            "-Force is supported only with -Action Destroy.",
            "DESTROY_CONFIRMATION_REQUIRED",
        ),
        "Install-Lab.ps1",
        findings,
    )
    require("RemoveData" not in entry, "Install entrypoint exposes partial Destroy.", findings)
    require_fragments(
        uninstall,
        (
            "SupportsShouldProcess",
            "Destroy all registered quick-test resources and local data",
            "Remove-QuickTestLab",
            "Confirm:$false",
            "Force",
        ),
        "Uninstall-Lab.ps1",
        findings,
    )
    require(
        "RemoveData" not in uninstall,
        "Uninstall entrypoint exposes partial Destroy.",
        findings,
    )
    require_fragments(
        loader,
        (
            "Private/LifecycleState.ps1",
            "Private/LifecycleRuntime.ps1",
            "Public/Install-QuickTestLab.ps1",
            "Public/Get-QuickTestLabStatus.ps1",
            "Public/Remove-QuickTestLab.ps1",
            "'Install-QuickTestLab'",
            "'Get-QuickTestLabStatus'",
            "'Remove-QuickTestLab'",
        ),
        "Quick-test module loader",
        findings,
    )


def validate_install(root: Path, findings: list[str]) -> None:
    install = text(root, "Lab/QuickTest/Public/Install-QuickTestLab.ps1")
    preflight = install.find("Invoke-QuickTestPreflight")
    approval = install.find("$PSCmdlet.ShouldProcess")
    state = install.find("LifecycleStatus = 'INSTALLING'")
    state_write = install.find("Write-QuickTestJson", state)
    compose = install.find("Invoke-QuickTestCompose")
    require(
        -1 not in (preflight, approval, state, state_write, compose)
        and preflight < approval < state < state_write < compose,
        "Install does not enforce Preflight, approval, and recovery state before mutation.",
        findings,
    )
    require_fragments(
        install,
        (
            "LOCAL_SCOPE_CONFLICT",
            "Set-QuickTestOwnerMarker",
            "Set-QuickTestPrivateDirectoryPermissions",
            "foreach ($version in $versions)",
            "@('up', '--detach', $service)",
            "Wait-QuickTestContainerHealthy",
            "SERVERPROPERTY('ProductMajorVersion')",
            "ProductMajorVersion = $expectedMajor",
            "Initialize-QuickTestAdminLogin",
            "Install-LabContainerFramework",
            "LifecycleStatus = 'READY'",
            "GeneratedCredentialPath",
            "ConnectionStringTemplate",
            "RecoveryContainerIds",
            "RecoveryNetworkIds",
            "LifecycleStatus = 'RECOVERY_CLEANUP'",
        ),
        "Install lifecycle",
        findings,
    )
    recovery = install.find("LifecycleStatus = 'RECOVERY_CLEANUP'")
    recovery_write = install.find("Write-QuickTestJson", recovery)
    recovery_remove = install.find("Remove-QuickTestRuntimeResources", recovery_write)
    require(
        -1 not in (recovery, recovery_write, recovery_remove)
        and recovery < recovery_write < recovery_remove,
        "Recovery IDs are not registered before cleanup.",
        findings,
    )
    for forbidden in (
        "system prune",
        "container prune",
        "network prune",
        "volume prune",
        "compose down",
        "rm -rf",
    ):
        require(forbidden not in install.lower(), f"Install contains {forbidden}.", findings)


def validate_helpers(root: Path, findings: list[str]) -> None:
    state = text(root, "Lab/QuickTest/Private/LifecycleState.ps1")
    runtime = text(root, "Lab/QuickTest/Private/LifecycleRuntime.ps1")
    require_fragments(
        state,
        (
            "Test-QuickTestPathWithinRoot",
            ".quicktest-owner",
            "Test-QuickTestOwnedDirectory",
            "Write-QuickTestJson",
            "New-QuickTestRunId",
            "Set-QuickTestPrivateDirectoryPermissions",
            "already exists without an ownership marker",
            "owned by a different run",
        ),
        "Lifecycle state helpers",
        findings,
    )
    require_fragments(
        runtime,
        (
            "label=qt-lab.run-id=$RunId",
            "{{.Id}}",
            "^[a-f0-9]{64}$",
            "Get-QuickTestObjectLabel",
            "Remove-QuickTestRuntimeResources",
            "qt-lab.owner",
            "SQL_SERVER_ANALYZE",
            "container', 'rm', '--force', $containerId",
            "network', 'rm', $networkId",
            "Wait-QuickTestContainerHealthy",
            "Invoke-QuickTestSqlQuery",
            "Invoke-QuickTestSqlInput",
            "--interactive",
            "-i /dev/stdin",
            "CHECK_POLICY = ON",
            "Save-QuickTestGeneratedCredential",
        ),
        "Lifecycle runtime helpers",
        findings,
    )
    require(
        "$listArguments.Add('--all')" in runtime
        and "if ($definition.Type -eq 'container')" in runtime,
        "Runtime discovery applies --all outside container listing.",
        findings,
    )
    require(
        "admin-login-$SqlVersion.sql" not in runtime and "RuntimeDirectory" not in runtime,
        "Administrative login creation still writes a credential SQL file.",
        findings,
    )
    for forbidden in (
        "system', 'prune'",
        "container', 'prune'",
        "network', 'prune'",
        "volume', 'prune'",
        "--filter', 'name=",
    ):
        require(forbidden not in runtime, f"Runtime helper contains {forbidden}.", findings)


def validate_status_destroy(root: Path, findings: list[str]) -> None:
    status = text(root, "Lab/QuickTest/Public/Get-QuickTestLabStatus.ps1")
    destroy = text(root, "Lab/QuickTest/Public/Remove-QuickTestLab.ps1")
    require_fragments(
        status,
        (
            "NOT_INSTALLED",
            "RUNTIME_UNAVAILABLE",
            "{{.State.Status}}|{{.State.Health.Status}}",
            "qt-lab.run-id",
            "qt-lab.owner",
            "OwnershipValid",
            "PARTIAL_SUCCESS",
            "non-canonical container ID",
        ),
        "Status lifecycle",
        findings,
    )
    require_fragments(
        destroy,
        (
            "SupportsShouldProcess",
            "DESTROY_CONFIRMATION_REQUIRED",
            "registeredContainerIds",
            "registeredNetworkIds",
            "unexpectedContainers",
            "unexpectedNetworks",
            "not registered in state",
            "Remove-QuickTestRuntimeResources",
            "Test-QuickTestOwnedDirectory",
            "Status = 'DESTROYED'",
            "DataRemoved = $true",
        ),
        "Destroy lifecycle",
        findings,
    )
    require(
        "PersistenceMode" not in destroy and "RemoveData" not in destroy,
        "Destroy contains a data-preserving path.",
        findings,
    )


def validate_framework(root: Path, findings: list[str]) -> None:
    wrapper = text(
        root,
        "Lab/Orchestration/Modules/DiagnosticLab/Public/Install-LabContainerFramework.ps1",
    )
    manifest = text(root, "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psd1")
    loader = text(root, "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psm1")
    require_fragments(
        wrapper,
        (
            "function Install-LabContainerFramework",
            "'DOCKER', 'PODMAN'",
            "Install-LabFramework",
            "Verify_Framework.sql",
            "FRAMEWORK_READY",
            "FrameworkDatabase = 'LabAnalyze'",
        ),
        "Framework wrapper",
        findings,
    )
    require(
        "Install-LabContainerFramework" in manifest
        and "Install-LabContainerFramework" in loader,
        "DiagnosticLab does not export the framework wrapper.",
        findings,
    )


def validate_status_and_gates(root: Path, findings: list[str]) -> None:
    status = json.loads(text(root, "Metadata/Quality/Docker_Podman_Quick_Test_Status.json"))
    require(
        status.get("WorkItemId") == "LAB-QUICKTEST-001"
        and status.get("ContractStatus") == "IMPLEMENTED_ACTIONS_GATE"
        and status.get("PreflightStatus") == "IMPLEMENTED_AUTOMATED_GATE"
        and status.get("RuntimeStatus") == "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING"
        and status.get("DataClassification") == "PUBLIC_AND_SYNTHETIC",
        "Lifecycle status is missing or overstated.",
        findings,
    )
    delivered = " ".join(status.get("DeliveredScope", []))
    opened = " ".join(status.get("OpenScope", []))
    require_fragments(
        delivered,
        (
            "Bounded Install action",
            "recovery state",
            "Full container and network object ID",
            "Status action",
            "Destroy action",
            "framework installation",
        ),
        "Delivered lifecycle status",
        findings,
    )
    require_fragments(
        opened,
        (
            "Start, Stop, Restart, and Reset",
            "UpdateFramework",
            "Down action",
            "Native Docker runtime evidence",
            "Native Podman runtime evidence",
        ),
        "Open lifecycle status",
        findings,
    )
    with (root / "Metadata/Quality/Lab_External_Evidence_Gates.csv").open(
        newline="", encoding="utf-8"
    ) as handle:
        gates = {row["GateId"]: row for row in csv.DictReader(handle)}
    for gate_id, capability in EXPECTED_GATES.items():
        row = gates.get(gate_id, {})
        require(
            row.get("RequiredCapability") == capability
            and row.get("Status") == "NOT_EXECUTED"
            and row.get("EvidencePolicy") == "SYNTHETIC_SUMMARY_ONLY"
            and row.get("BlockingScope") == "QUICKTEST_EXTERNAL_EVIDENCE_PENDING",
            f"{gate_id} overstates external evidence.",
            findings,
        )


def validate_integration(root: Path, findings: list[str]) -> None:
    workflow = text(root, ".github/workflows/lab-contract-validation.yml")
    tests = text(root, "Lab/Validation/Invoke-LabQuickTestLifecycleTests.ps1")
    readme = text(root, "Lab/QuickTest/README.md")
    require_fragments(
        workflow,
        (
            "Validate_Docker_Podman_QuickTest_Lifecycle.py",
            "Invoke-LabQuickTestLifecycleTests.ps1",
            "Run Docker Podman quick-test lifecycle tests",
            "Analyze quick-test lifecycle state helpers",
            "Analyze quick-test lifecycle runtime helpers",
            "Analyze quick-test Install lifecycle",
            "Analyze quick-test Status lifecycle",
            "Analyze quick-test Destroy lifecycle",
            "Analyze quick-test uninstall entrypoint",
            "Analyze quick-test framework wrapper",
        ),
        "Workflow integration",
        findings,
    )
    require_fragments(
        tests,
        (
            "FakeRuntime",
            "LOCAL_SCOPE_CONFLICT",
            "Install-QuickTestLab",
            "Get-QuickTestLabStatus",
            "Remove-QuickTestLab",
            "DESTROYED",
            "READ_ONLY_PREFLIGHT",
            "qt-lab.owner",
            "admin-login-*.sql",
            "container rm --force",
            "network rm",
        ),
        "Lifecycle tests",
        findings,
    )
    require_fragments(
        readme,
        (
            "## Install",
            "## Status",
            "## Destroy and uninstall",
            "TEMPORARY",
            "PERSISTENT",
            "InstallFramework",
            "full object IDs",
            "Destroy always removes the complete scope",
            "Down while preserving persistent data",
            "NOT_EXECUTED",
            "Docker-/Podman-Quick-Testsystem",
        ),
        "Quick-test README",
        findings,
    )
    require("-RemoveData" not in readme, "README documents partial Destroy.", findings)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=".")
    args = parser.parse_args()
    root = Path(args.repository_root).resolve()
    findings: list[str] = []

    for path in sorted(REQUIRED_FILES):
        require((root / path).is_file(), f"Missing lifecycle file: {path}", findings)

    if not findings:
        validate_entrypoints(root, findings)
        validate_install(root, findings)
        validate_helpers(root, findings)
        validate_status_destroy(root, findings)
        validate_framework(root, findings)
        validate_status_and_gates(root, findings)
        validate_integration(root, findings)

    if findings:
        for finding in findings:
            print(f"ERROR: {finding}")
        return 1

    print(
        "Docker/Podman quick-test lifecycle validated: "
        "actions=Install,Status,Destroy external_evidence=NOT_EXECUTED."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
