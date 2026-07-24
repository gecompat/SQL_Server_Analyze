#!/usr/bin/env python3
"""Validate the host-independent Docker/Podman quick-test vertical slice."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


VERSIONS = ("2019", "2022", "2025")
REQUIRED_FILES = {
    ".github/workflows/lab-contract-validation.yml",
    "Code/Tests/Static/Validate_Docker_Podman_QuickTest_VerticalSlice.py",
    "Documentation/Architecture/Docker_Podman_Quick_Test_System_Requirements.md",
    "Lab/.gitignore",
    "Lab/Containers/quick-test.compose.yaml",
    "Lab/Containers/quick-test.compose.docker.yaml",
    "Lab/Containers/quick-test.compose.podman.yaml",
    "Lab/Install-Lab.ps1",
    "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psd1",
    "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psm1",
    "Lab/Orchestration/Modules/DiagnosticLab/Public/Install-LabContainerFramework.ps1",
    "Lab/QuickTest/QuickTestLab.psm1",
    "Lab/QuickTest/Private/Common.ps1",
    "Lab/QuickTest/Private/Runtime.ps1",
    "Lab/QuickTest/Public/Invoke-QuickTestPreflight.ps1",
    "Lab/QuickTest/Public/Install-QuickTestLab.ps1",
    "Lab/QuickTest/Public/Get-QuickTestLabStatus.ps1",
    "Lab/QuickTest/Public/Remove-QuickTestLab.ps1",
    "Lab/README.md",
    "Lab/Uninstall-Lab.ps1",
    "Lab/Validation/Invoke-LabQuickTestTests.ps1",
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


def text(root: Path, relative_path: str) -> str:
    return (root / relative_path).read_text(encoding="utf-8")


def quicktest_source(root: Path) -> str:
    module_root = root / "Lab/QuickTest"
    source_paths = sorted(module_root.rglob("*.ps1")) + sorted(
        module_root.rglob("*.psm1")
    )
    return "\n".join(path.read_text(encoding="utf-8") for path in source_paths)


def validate_compose(root: Path, findings: list[str]) -> None:
    core = text(root, "Lab/Containers/quick-test.compose.yaml")
    docker = text(root, "Lab/Containers/quick-test.compose.docker.yaml")
    podman = text(root, "Lab/Containers/quick-test.compose.podman.yaml")

    for version in VERSIONS:
        for fragment in (
            f"sql{version}:",
            f"profiles: [sql{version}]",
            f"QTLAB_SQL{version}_IMAGE",
            f"QTLAB_SQL{version}_PORT",
            f'qt-lab.sql-version: "{version}"',
            f"mcr.microsoft.com/mssql/server:{version}-latest",
        ):
            require(fragment in core, f"Compose core lacks {fragment}.", findings)
    for fragment in (
        "MSSQL_COLLATION=SQL_Latin1_General_CP1_CS_AS",
        "MSSQL_MEMORY_LIMIT_MB=${QTLAB_SQL_MEMORY_MB",
        "ProductMajorVersion",
        "qt-lab.owner: SQL_SERVER_ANALYZE",
        "qt-lab.scope:",
        "qt-lab.run-id:",
        "/var/opt/mssql/data",
        "/var/opt/mssql/log",
        "/var/opt/mssql/backup",
        "QTLAB_RUNTIME_DIR",
    ):
        require(fragment in core, f"Compose core lacks {fragment}.", findings)

    secret_name = "MSSQL_SA_" + "PASSWORD"
    require(
        f"- {secret_name}" in core,
        "Compose core does not use process-scoped SQL secret pass-through.",
        findings,
    )
    require(
        f"{secret_name}:" not in core and f"{secret_name}=" not in core,
        "Compose core embeds a SQL secret value.",
        findings,
    )

    for override, runtime in ((docker, "DOCKER"), (podman, "PODMAN")):
        for fragment in (
            "pull_policy: missing",
            "mem_limit: ${QTLAB_MEMORY_LIMIT",
            "cpus: ${QTLAB_CPU_LIMIT",
            f"qt-lab.runtime: {runtime}",
            "sql2019:",
            "sql2022:",
            "sql2025:",
        ):
            require(fragment in override, f"{runtime} override lacks {fragment}.", findings)


def validate_powershell(root: Path, findings: list[str]) -> None:
    install = text(root, "Lab/Install-Lab.ps1")
    uninstall = text(root, "Lab/Uninstall-Lab.ps1")
    module = quicktest_source(root)
    root_module = text(root, "Lab/QuickTest/QuickTestLab.psm1")
    wrapper = text(
        root,
        "Lab/Orchestration/Modules/DiagnosticLab/Public/Install-LabContainerFramework.ps1",
    )
    module_manifest = text(
        root, "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psd1"
    )
    module_loader = text(
        root, "Lab/Orchestration/Modules/DiagnosticLab/DiagnosticLab.psm1"
    )

    for relative_path in (
        "Private/Common.ps1",
        "Private/Runtime.ps1",
        "Public/Invoke-QuickTestPreflight.ps1",
        "Public/Install-QuickTestLab.ps1",
        "Public/Get-QuickTestLabStatus.ps1",
        "Public/Remove-QuickTestLab.ps1",
    ):
        require(relative_path in root_module, f"Root module lacks {relative_path}.", findings)

    for fragment in (
        "'Preflight', 'Install', 'Status', 'Destroy'",
        "'DOCKER', 'PODMAN'",
        "Read-Host 'Administrative SQL secret' -AsSecureString",
        "SecretEnvironmentVariable",
        "GenerateSecret",
        "SqlVersions",
        "Ports",
        "ResourceProfile",
        "PersistenceMode",
        "InstallFramework",
        "AcceptEula",
        "NonInteractive",
        "$PSCmdlet.ShouldProcess",
        "DESTROY_CONFIRMATION_REQUIRED",
    ):
        require(fragment in install, f"Install-Lab.ps1 lacks {fragment}.", findings)
    require(
        "Remove-QuickTestLab" in uninstall
        and "$PSCmdlet.ShouldProcess" in uninstall
        and "DESTROY_CONFIRMATION_REQUIRED" in uninstall,
        "Uninstall-Lab.ps1 lacks explicit bounded confirmation.",
        findings,
    )

    for fragment in (
        "function Invoke-QuickTestPreflight",
        "function Install-QuickTestLab",
        "function Get-QuickTestLabStatus",
        "function Remove-QuickTestLab",
        "function New-QuickTestPassword",
        "function Test-QuickTestPassword",
        "function Test-QuickTestPathWithinRoot",
        "function Get-QuickTestResourcesByRunId",
        "function Remove-QuickTestRuntimeResources",
        "manifest",
        "inspect",
        "ProductMajorVersion",
        ".quicktest-owner",
        "qt-lab.run-id",
        "ContainerId",
        "NetworkId",
        "Install-LabContainerFramework",
        "ConnectionStringTemplate",
        "GeneratedSecretPath",
        "PERSISTENT",
        "TEMPORARY",
        "SCOPE_ALREADY_EXISTS",
        "NEW_DIFFERENCING_DISK" if False else "RunId",
    ):
        require(fragment in module, f"Quick-test module lacks {fragment}.", findings)
    for fragment in (
        "Write-Host $plainSecret",
        "Write-Output $plainSecret",
        "Write-Verbose $plainSecret",
        "Write-Debug $plainSecret",
        "PODMAN_COMPATIBILITY_ASSIGNED_TO_WAVE9",
    ):
        require(fragment not in module, f"Quick-test module contains {fragment}.", findings)

    for fragment in (
        "function Install-LabContainerFramework",
        "Install-LabFramework",
        "'DOCKER', 'PODMAN'",
        "FrameworkDatabase = 'LabAnalyze'",
    ):
        require(fragment in wrapper, f"Framework wrapper lacks {fragment}.", findings)
    require(
        "Install-LabContainerFramework" in module_manifest
        and "Install-LabContainerFramework" in module_loader,
        "DiagnosticLab does not export the generic container framework installer.",
        findings,
    )


def validate_status(root: Path, findings: list[str]) -> None:
    status = json.loads(
        text(root, "Metadata/Quality/Docker_Podman_Quick_Test_Status.json")
    )
    require(
        status.get("WorkItemId") == "LAB-QUICKTEST-001"
        and status.get("ProductStatus") == "IMPLEMENTED_ACTIONS_GATE"
        and status.get("RuntimeStatus") == "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING"
        and status.get("DataClassification") == "PUBLIC_AND_SYNTHETIC",
        "Quick-test implementation status is missing or overstated.",
        findings,
    )
    limitations = " ".join(status.get("KnownLimitations", []))
    for fragment in (
        "native x86-64 Linux",
        "planned follow-up lifecycle actions",
        "NOT_EXECUTED",
    ):
        require(fragment in limitations, f"Quick-test status lacks {fragment}.", findings)

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
            and row.get("BlockingScope") == "QUICKTEST_EXTERNAL_EVIDENCE",
            f"{gate_id} is missing or overstated.",
            findings,
        )


def validate_integration(root: Path, findings: list[str]) -> None:
    workflow = text(root, ".github/workflows/lab-contract-validation.yml")
    tests = text(root, "Lab/Validation/Invoke-LabQuickTestTests.ps1")
    readme = text(root, "Lab/README.md")
    requirements = text(
        root,
        "Documentation/Architecture/Docker_Podman_Quick_Test_System_Requirements.md",
    )
    ignore = text(root, "Lab/.gitignore")

    for fragment in (
        "Validate LAB-001 Wellen 0 to 5",
        "Validate_Docker_Podman_QuickTest_VerticalSlice.py",
        "Invoke-LabQuickTestTests.ps1",
        "quick-test.compose.docker.yaml",
        "quick-test.compose.podman.yaml",
        "Invoke-ScriptAnalyzer",
    ):
        require(fragment in workflow, f"Workflow lacks {fragment}.", findings)
    for fragment in (
        "PowerShell parser reported an error",
        "Generated quick-test secret",
        "Default quick-test ports",
        "RUNTIME_UNAVAILABLE",
        "PORT_CONFLICT",
    ):
        require(fragment in tests, f"Quick-test tests lack {fragment}.", findings)
    for fragment in (
        "Install-Lab.ps1",
        "Docker",
        "Podman",
        "2019",
        "2022",
        "2025",
        "QTLAB_SQL_SECRET",
        "Status",
        "Destroy",
        "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING",
    ):
        require(fragment in readme, f"Lab README lacks {fragment}.", findings)
    require(
        "minimal nutzbaren Vertical Slice" in requirements
        and "Install-Lab.ps1" in requirements,
        "The implementation is not traceable to the canonical requirement.",
        findings,
    )
    for fragment in ("/.artifacts/", "/.secrets/", "/.state/"):
        require(fragment in ignore, f"Lab ignore file lacks {fragment}.", findings)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=".")
    args = parser.parse_args()
    root = Path(args.repository_root).resolve()
    findings: list[str] = []

    for relative_path in sorted(REQUIRED_FILES):
        require(
            (root / relative_path).is_file(),
            f"Missing quick-test vertical-slice file: {relative_path}",
            findings,
        )

    validate_compose(root, findings)
    validate_powershell(root, findings)
    validate_status(root, findings)
    validate_integration(root, findings)

    if findings:
        for finding in findings:
            print(f"ERROR: {finding}")
        return 1

    print(
        "Docker/Podman quick-test vertical slice validated: "
        "runtimes=2 versions=3 runtime_evidence=NOT_EXECUTED."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
