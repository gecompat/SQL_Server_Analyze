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


def read_text(root: Path, relative_path: str) -> str:
    return (root / relative_path).read_text(encoding="utf-8")


def require_fragments(
    text: str,
    fragments: tuple[str, ...],
    scope: str,
    findings: list[str],
) -> None:
    for fragment in fragments:
        require(fragment in text, f"{scope} lacks {fragment}.", findings)


def validate_entrypoints(root: Path, findings: list[str]) -> None:
    install_entrypoint = read_text(root, "Lab/Install-Lab.ps1")
    uninstall_entrypoint = read_text(root, "Lab/Uninstall-Lab.ps1")
    loader = read_text(root, "Lab/QuickTest/QuickTestLab.psm1")

    require_fragments(
        install_entrypoint,
        (
            "'Preflight', 'Install', 'Status', 'Destroy'",
            "Install-QuickTestLab",
            "Get-QuickTestLabStatus",
            "Remove-QuickTestLab",
            "InstallFramework",
            "Force",
            "PersistGeneratedCredential",
            "Destroy all registered quick-test resources and local data",
        ),
        "Install-Lab.ps1",
        findings,
    )
    require(
        "SupportsShouldProcess" in uninstall_entrypoint
        and "if (-not $Force)" in uninstall_entrypoint
        and "Remove-QuickTestLab" in uninstall_entrypoint
        and "-Confirm:$false" in uninstall_entrypoint,
        "Uninstall-Lab.ps1 lacks confirmation-bound full-scope cleanup.",
        findings,
    )
    require(
        "RemoveData" not in install_entrypoint
        and "RemoveData" not in uninstall_entrypoint,
        "Destroy still exposes the obsolete partial-data cleanup switch.",
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
        "Quick-test loader",
        findings,
    )


def validate_install(root: Path, findings: list[str]) -> None:
    install = read_text(root, "Lab/QuickTest/Public/Install-QuickTestLab.ps1")
    preflight_position = install.find("Invoke-QuickTestPreflight")
    should_process_position = install.find("$PSCmdlet.ShouldProcess")
    state_position = install.find("LifecycleStatus = 'INSTALLING'")
    state_write_position = install.find("Write-QuickTestJson", state_position)
    compose_position = install.find("Invoke-QuickTestCompose")
    require(
        -1 not in (
            preflight_position,
            should_process_position,
            state_position,
            state_write_position,
            compose_position,
        )
        and preflight_position < should_process_position
        and state_position < state_write_position < compose_position,
        "Install ordering does not enforce Preflight and recovery state before mutation.",
        findings,
    )
    require_fragments(
        install,
        (
            "foreach ($version in $versions)",
            "@('up', '--detach', $service)",
            "Wait-QuickTestContainerHealthy",
            "SERVERPROPERTY('ProductMajorVersion')",
            "Get-QuickTestContainerId",
            "Get-QuickTestResourcesByRunId",
            "ProductMajorVersion = $expectedMajor",
            "Initialize-QuickTestAdminLogin",
            "Install-LabContainerFramework",
            "LifecycleStatus = 'READY'",
            "GeneratedCredentialPath",
            "ConnectionStringTemplate",
        ),
        "Install lifecycle",
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
        require(
            forbidden not in install.lower(),
            f"Install lifecycle contains broad mutation fragment {forbidden}.",
            findings,
        )


def validate_helpers(root: Path, findings: list[str]) -> None:
    state = read_text(root, "Lab/QuickTest/Private/LifecycleState.ps1")
    runtime = read_text(root, "Lab/QuickTest/Private/LifecycleRuntime.ps1")
    require_fragments(
        state,
        (
            "Test-QuickTestPathWithinRoot",
            ".quicktest-owner",
            "Test-QuickTestOwnedDirectory",
            "Write-QuickTestJson",
            "New-QuickTestRunId",
        ),
        "Lifecycle state helper",
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
            "container', 'rm', '--force', $containerId",
            "network', 'rm', $networkId",
            "Wait-QuickTestContainerHealthy",
            "Invoke-QuickTestSqlQuery",
            "Save-QuickTestGeneratedCredential",
            "$listArguments.Add('--all')",
            "if ($definition.Type -eq 'container')",
        ),
        "Lifecycle runtime helper",
        findings,
    )
    for forbidden in (
        "system', 'prune'",
        "container', 'prune'",
        "network', 'prune'",
        "volume', 'prune'",
        "--filter', 'name=",
    ):
        require(
            forbidden not in runtime,
            f"Runtime helper contains unsafe discovery fragment {forbidden}.",
            findings,
        )


def validate_status_destroy(root: Path, findings: list[str]) -> None:
    status = read_text(root, "Lab/QuickTest/Public/Get-QuickTestLabStatus.ps1")
    destroy = read_text(root, "Lab/QuickTest/Public/Remove-QuickTestLab.ps1")
    require_fragments(
        status,
        (
            "NOT_INSTALLED",
            "RUNTIME_UNAVAILABLE",
            "{{.State.Status}}|{{.State.Health.Status}}",
            "OwnershipValid",
            "PARTIAL_SUCCESS",
            "Test-QuickTestOwnedDirectory",
        ),
        "Status lifecycle",
        findings,
    )
    require_fragments(
        destroy,
        (
            "SupportsShouldProcess",
            "DESTROY_CONFIRMATION_REQUIRED",
            "Get-QuickTestResourcesByRunId",
            "Remove-QuickTestRuntimeResources",
            "unexpectedContainers",
            "unexpectedNetworks",
            "registeredContainerIds",
            "registeredNetworkIds",
            "Test-QuickTestOwnedDirectory",
            "CredentialDirectory",
            "DataRemoved = $true",
            "Status = 'DESTROYED'",
        ),
        "Destroy lifecycle",
        findings,
    )
    require(
        "Remove-Item -LiteralPath" in destroy
        and "-Recurse" in destroy
        and "Test-QuickTestOwnedDirectory" in destroy,
        "Destroy local cleanup is not marker and boundary gated.",
        findings,
    )
    require(
        "PersistenceMode -eq 'TEMPORARY'" not in destroy
        and "RemoveData" not in destroy,
        "Destroy does not remove the complete owned scope.",
        findings,
    )


def validate_framework(root: Path, findings: list[str]) -> None:
    wrapper = read_text(
        root,
        "Lab/Orchestration/Modules/DiagnosticLab/Public/Install-LabContainerFramework.ps1",
    )
    manifest = read_text(
        root, "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psd1"
    )
    loader = read_text(
        root, "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psm1"
    )
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
        "DiagnosticLab module does not export the container framework wrapper.",
        findings,
    )


def validate_status_gates(root: Path, findings: list[str]) -> None:
    status = json.loads(
        read_text(root, "Metadata/Quality/Docker_Podman_Quick_Test_Status.json")
    )
    require(
        status.get("WorkItemId") == "LAB-QUICKTEST-001"
        and status.get("ContractStatus") == "IMPLEMENTED_ACTIONS_GATE"
        and status.get("PreflightStatus") == "IMPLEMENTED_AUTOMATED_GATE"
        and status.get("RuntimeStatus")
        == "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING"
        and status.get("DataClassification") == "PUBLIC_AND_SYNTHETIC",
        "Quick-test lifecycle status is missing or overstated.",
        findings,
    )
    delivered = " ".join(status.get("DeliveredScope", []))
    open_scope = " ".join(status.get("OpenScope", []))
    for fragment in (
        "Bounded Install action",
        "recovery state",
        "Full container and network object ID",
        "Status action",
        "Destroy action",
        "framework installation",
    ):
        require(fragment in delivered, f"Delivered scope lacks {fragment}.", findings)
    for fragment in (
        "Start, Stop, Restart, and Reset",
        "UpdateFramework",
        "Native Docker runtime evidence",
        "Native Podman runtime evidence",
    ):
        require(fragment in open_scope, f"Open scope lacks {fragment}.", findings)

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
            f"{gate_id} does not preserve pending external evidence.",
            findings,
        )


def validate_integration(root: Path, findings: list[str]) -> None:
    workflow = read_text(root, ".github/workflows/lab-contract-validation.yml")
    tests = read_text(root, "Lab/Validation/Invoke-LabQuickTestLifecycleTests.ps1")
    readme = read_text(root, "Lab/QuickTest/README.md")
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
        ),
        "Workflow integration",
        findings,
    )
    require_fragments(
        tests,
        (
            "FakeRuntime",
            "Install-QuickTestLab",
            "Get-QuickTestLabStatus",
            "Remove-QuickTestLab",
            "DESTROYED",
            "READ_ONLY_PREFLIGHT",
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
            "NOT_EXECUTED",
            "Destroy always removes",
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
            f"Missing quick-test lifecycle file: {relative_path}",
            findings,
        )

    if not findings:
        validate_entrypoints(root, findings)
        validate_install(root, findings)
        validate_helpers(root, findings)
        validate_status_destroy(root, findings)
        validate_framework(root, findings)
        validate_status_gates(root, findings)
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
