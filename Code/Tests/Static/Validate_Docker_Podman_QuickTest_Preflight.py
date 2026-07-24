#!/usr/bin/env python3
"""Validate the read-only Docker/Podman quick-test Preflight delivery."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


REQUIRED_FILES = {
    ".github/workflows/lab-contract-validation.yml",
    "Code/Tests/Static/Validate_Docker_Podman_QuickTest_ComposeFoundation.py",
    "Code/Tests/Static/Validate_Docker_Podman_QuickTest_Preflight.py",
    "Documentation/Architecture/Docker_Podman_Quick_Test_System_Requirements.md",
    "Lab/Install-Lab.ps1",
    "Lab/QuickTest/QuickTestPreflight.psm1",
    "Lab/QuickTest/README.md",
    "Lab/Validation/Invoke-LabQuickTestPreflightTests.ps1",
    "Metadata/Quality/Docker_Podman_Quick_Test_Status.json",
}


def require(condition: bool, message: str, findings: list[str]) -> None:
    if not condition:
        findings.append(message)


def read_text(root: Path, relative_path: str) -> str:
    return (root / relative_path).read_text(encoding="utf-8")


def validate_entrypoint(root: Path, findings: list[str]) -> None:
    entrypoint = read_text(root, "Lab/Install-Lab.ps1")
    module = read_text(root, "Lab/QuickTest/QuickTestPreflight.psm1")

    for fragment in (
        "'DOCKER', 'PODMAN'",
        "SqlVersions",
        "Ports",
        "AdminLogin",
        "AdminSecret",
        "SecretEnvironmentVariable",
        "GenerateSecret",
        "ResourceProfile",
        "PersistenceMode",
        "InstallFramework",
        "AcceptEula",
        "NonInteractive",
        "SkipImageAvailabilityCheck",
        "Invoke-QuickTestPreflightEntry @PSBoundParameters",
    ):
        require(fragment in entrypoint, f"Install-Lab.ps1 lacks {fragment}.", findings)

    for fragment in (
        "function Test-QuickTestSqlSecret",
        "function New-QuickTestSqlSecret",
        "function Resolve-QuickTestRuntime",
        "function Test-QuickTestPortAvailable",
        "function Get-QuickTestAvailableMemoryMiB",
        "function Invoke-QuickTestPreflight",
        "function Invoke-QuickTestPreflightEntry",
        "RUNTIME_UNAVAILABLE",
        "COMPOSE_UNAVAILABLE",
        "PORT_CONFLICT",
        "RESOURCE_LIMIT_EXCEEDED",
        "DATA_ROOT_UNAVAILABLE",
        "CREDENTIAL_POLICY_FAILED",
        "EULA_NOT_ACCEPTED",
        "IMAGE_UNAVAILABLE",
        "MutationPerformed = $false",
        "INSTALL_LIFECYCLE_NOT_IMPLEMENTED",
        "Read-Host 'Administrative SQL secret' -AsSecureString",
        "GENERATED_EPHEMERAL",
        "ENVIRONMENT",
        "INTERACTIVE",
    ):
        require(fragment in module, f"Preflight module lacks {fragment}.", findings)

    for forbidden in (
        "compose', 'up'",
        "container', 'run'",
        "container', 'create'",
        "container', 'rm'",
        "network', 'create'",
        "network', 'rm'",
        "Remove-Item -Recurse",
        "New-Item",
        "Set-Content",
        "Add-Content",
        "Out-File",
    ):
        require(
            forbidden not in module and forbidden not in entrypoint,
            f"Read-only Preflight contains mutating fragment {forbidden}.",
            findings,
        )
    for forbidden in (
        "Write-Host $plainValue",
        "Write-Output $plainValue",
        "Write-Verbose $plainValue",
        "Write-Debug $plainValue",
    ):
        require(forbidden not in module, f"Preflight can emit a secret: {forbidden}.", findings)


def validate_status(root: Path, findings: list[str]) -> None:
    status = json.loads(
        read_text(root, "Metadata/Quality/Docker_Podman_Quick_Test_Status.json")
    )
    require(
        status.get("WorkItemId") == "LAB-QUICKTEST-001"
        and status.get("ContractStatus") == "IMPLEMENTED_AUTOMATED_GATE"
        and status.get("RuntimeStatus") == "NOT_EXECUTED"
        and status.get("DataClassification") == "PUBLIC_AND_SYNTHETIC",
        "Quick-test Preflight status is missing or overstated.",
        findings,
    )
    delivered = " ".join(status.get("DeliveredScope", []))
    open_scope = " ".join(status.get("OpenScope", []))
    for fragment in (
        "Interactive and non-interactive PowerShell 7 Preflight entrypoint",
        "SecureString, environment, generated-ephemeral, and interactive credential sources",
        "read-only runtime, Compose, platform, port, memory, path, credential, EULA, and image checks",
        "structured blocker reason codes",
    ):
        require(fragment in delivered, f"Delivered scope lacks {fragment}.", findings)
    for fragment in (
        "Lifecycle execution",
        "Framework installation",
        "Status and Destroy",
        "Native Docker runtime evidence",
        "Native Podman runtime evidence",
    ):
        require(fragment in open_scope, f"Open scope lacks {fragment}.", findings)


def validate_integration(root: Path, findings: list[str]) -> None:
    workflow = read_text(root, ".github/workflows/lab-contract-validation.yml")
    tests = read_text(root, "Lab/Validation/Invoke-LabQuickTestPreflightTests.ps1")
    readme = read_text(root, "Lab/QuickTest/README.md")
    requirements = read_text(
        root,
        "Documentation/Architecture/Docker_Podman_Quick_Test_System_Requirements.md",
    )

    for fragment in (
        "Validate_Docker_Podman_QuickTest_Preflight.py",
        "Invoke-LabQuickTestPreflightTests.ps1",
        "Run Docker Podman quick-test Preflight tests",
        "Invoke-ScriptAnalyzer",
        "QuickTestPreflight.psm1",
        "Install-Lab.ps1",
    ):
        require(fragment in workflow, f"Workflow lacks {fragment}.", findings)
    for fragment in (
        "PowerShell parser reported an error",
        "Generated quick-test secret",
        "Quick-test default ports",
        "RUNTIME_UNAVAILABLE",
        "PORT_CONFLICT",
        "MutationPerformed",
        "INSTALL_LIFECYCLE_NOT_IMPLEMENTED",
    ):
        require(fragment in tests, f"Preflight tests lack {fragment}.", findings)
    for fragment in (
        "IMPLEMENTED_AUTOMATED_GATE",
        "NOT_EXECUTED",
        "read-only",
        "Install-Lab.ps1",
        "QTLAB_SQL_SECRET",
        "Docker",
        "Podman",
        "2019",
        "2022",
        "2025",
    ):
        require(fragment in readme, f"Quick-test README lacks {fragment}.", findings)
    require(
        "Preflight" in requirements
        and "CredentialInput" in requirements
        and "Install-Lab.ps1" in requirements,
        "Preflight delivery is not traceable to the canonical requirement.",
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
            f"Missing quick-test Preflight file: {relative_path}",
            findings,
        )

    validate_entrypoint(root, findings)
    validate_status(root, findings)
    validate_integration(root, findings)

    if findings:
        for finding in findings:
            print(f"ERROR: {finding}")
        return 1

    print(
        "Docker/Podman quick-test Preflight validated: "
        "interface=implemented runtime=NOT_EXECUTED mutation=false."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
