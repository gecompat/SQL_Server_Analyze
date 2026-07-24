#!/usr/bin/env python3
"""Validate the LAB-001 Welle 4 multi-container contract foundation."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


EXPECTED_SCENARIOS = {
    "LAB-AVAIL-001",
    "LAB-AVAIL-002",
    "LAB-LS-001",
    "LAB-LS-002",
    "LAB-REPL-001",
    "LAB-REPL-002",
    "LAB-REPL-003",
    "LAB-BACKUP-001",
    "LAB-BACKUP-002",
    "LAB-NET-001",
    "LAB-NET-002",
    "LAB-NET-003",
    "LAB-NET-004",
    "LAB-AGENT-001",
    "LAB-BROKER-001",
    "LAB-DTC-001",
    "LAB-LINK-001",
    "LAB-MAINT-001",
}

EXPECTED_HEADER = (
    "ScenarioId",
    "Title",
    "TopologyId",
    "EvidenceClass",
    "ScenarioClass",
    "RuntimeImplementationStatus",
    "PrimaryAnalyzers",
    "DependencyStatus",
    "RequiredCapabilities",
    "FaultClass",
    "RequireExplicitApproval",
    "RequireIndependentManagementPath",
    "ExternalEvidenceGateIds",
    "StatePreconditions",
    "AssertionBoundary",
    "CleanupPolicy",
)

REQUIRED_TOPOLOGIES = {
    "CTR-SINGLE",
    "CTR-PAIR",
    "CTR-TRIPLE",
    "HV-CROSS-PLATFORM",
}

REQUIRED_GATES = {
    "LAB-GATE-WAVE4-MULTI-CONTAINER": {
        "Status": "NOT_EXECUTED",
        "EvidencePolicy": "SYNTHETIC_SUMMARY_ONLY",
        "BlockingScope": "WAVE4_RUNTIME_NOT_IMPLEMENTED",
    },
    "LAB-GATE-WAVE4-NETWORK-FAULT": {
        "Status": "NOT_EXECUTED",
        "EvidencePolicy": "SYNTHETIC_SUMMARY_ONLY",
        "BlockingScope": "WAVE4_RUNTIME_NOT_IMPLEMENTED",
    },
}

REQUIRED_FILES = {
    ".github/workflows/lab-contract-validation.yml",
    "Code/Tests/Static/Validate_LAB001_Wave4_ContractFoundation.py",
    "Lab/Contracts/wave4-topology-profile.schema.json",
    "Lab/Scenarios/Infrastructure/README.md",
    "Lab/Scenarios/Infrastructure/wave4-contracts.csv",
    "Lab/Scenarios/Infrastructure/wave4-topology-profiles.json",
    "Lab/Validation/Invoke-LabValidation.ps1",
    "Metadata/Quality/Lab_External_Evidence_Gates.csv",
}

FORBIDDEN_PATTERNS = {
    r"(?i)\b(?:password|passwd|pwd|token|private[_ -]?key|connection[_ -]?string)\b\s*[:=]\s*[^,\r\n}\]]+": "secret-like literal",
    r"(?i)[A-Z]:\\Users\\": "Windows user path",
    r"(?i)/home/[^/\s]+": "Linux user path",
    r"\b(?:10|127|169\.254|172\.(?:1[6-9]|2[0-9]|3[01])|192\.168)\.\d{1,3}\.\d{1,3}\b": "private or loopback address",
    r"(?i)\b(?:docker|podman)\s+(?:system|container|image|network|volume)\s+prune\b": "broad container prune",
    r"(?i)\brm\s+-rf\b": "recursive shell deletion",
    r"(?i)Remove-Item[^\r\n]*-Recurse[^\r\n]*\*": "wildcard recursive deletion",
}


def load_json(path: Path) -> object:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def load_csv(path: Path) -> tuple[tuple[str, ...], list[dict[str, str]]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        return tuple(reader.fieldnames or ()), list(reader)


def split_values(value: str) -> list[str]:
    return [item for item in value.split(";") if item]


def require(condition: bool, message: str, findings: list[str]) -> None:
    if not condition:
        findings.append(message)


def validate_catalog_alignment(
    root: Path,
    rows: list[dict[str, str]],
    findings: list[str],
) -> None:
    catalog = load_json(root / "Lab/Scenarios/Catalog/scenarios.json")
    catalog_rows = {
        item["ScenarioId"]: item
        for item in catalog.get("Scenarios", [])
        if isinstance(item, dict) and item.get("PlannedWave") == 4
    }
    require(
        set(catalog_rows) == EXPECTED_SCENARIOS,
        "Welle 4 catalog membership is not the declared 18-scenario set.",
        findings,
    )

    contract_rows = {row.get("ScenarioId", ""): row for row in rows}
    require(
        set(contract_rows) == EXPECTED_SCENARIOS and len(rows) == len(contract_rows),
        "Welle 4 contract registry is incomplete or contains duplicate scenarios.",
        findings,
    )

    for scenario_id in sorted(EXPECTED_SCENARIOS):
        catalog_row = catalog_rows.get(scenario_id, {})
        contract_row = contract_rows.get(scenario_id, {})
        require(
            catalog_row.get("Title") == contract_row.get("Title"),
            f"{scenario_id}: title differs from the scenario catalog.",
            findings,
        )
        require(
            catalog_row.get("EvidenceClass") == contract_row.get("EvidenceClass"),
            f"{scenario_id}: evidence class differs from the scenario catalog.",
            findings,
        )
        require(
            catalog_row.get("TopologyId") == contract_row.get("TopologyId"),
            f"{scenario_id}: topology differs from the scenario catalog.",
            findings,
        )
        require(
            catalog_row.get("ImplementationStatus") == "PLANNED_NOT_IMPLEMENTED"
            and contract_row.get("RuntimeImplementationStatus")
            == "PLANNED_NOT_IMPLEMENTED",
            f"{scenario_id}: runtime status is overstated.",
            findings,
        )


def validate_topologies(
    root: Path,
    topology_contract: dict[str, object],
    findings: list[str],
) -> None:
    topology_catalog = load_json(root / "Lab/Scenarios/Catalog/topologies.json")
    topology_ids = {
        item.get("TopologyId")
        for item in topology_catalog.get("Topologies", [])
        if isinstance(item, dict)
    }
    require(
        REQUIRED_TOPOLOGIES.issubset(topology_ids),
        "Required Welle 4 topologies are absent from the topology catalog.",
        findings,
    )

    require(
        topology_contract.get("WaveId") == "LAB-001-WAVE4"
        and topology_contract.get("ContractStatus") == "VALIDATED_FOUNDATION"
        and topology_contract.get("RuntimeStatus") == "NOT_EXECUTED"
        and topology_contract.get("DataClassification") == "SYNTHETIC",
        "Welle 4 topology contract status or classification is invalid.",
        findings,
    )

    profiles = topology_contract.get("TopologyProfiles", [])
    profile_ids = {
        item.get("ProfileId")
        for item in profiles
        if isinstance(item, dict)
    }
    require(
        profile_ids
        == {
            "W4-CTR-SINGLE",
            "W4-CTR-PAIR",
            "W4-CTR-TRIPLE",
            "W4-HV-CROSS-PLATFORM-FAULT",
        },
        "Welle 4 topology profiles are incomplete.",
        findings,
    )

    for profile in profiles:
        if not isinstance(profile, dict):
            findings.append("Welle 4 topology profile is not an object.")
            continue
        require(
            profile.get("TopologyId") in topology_ids,
            f"{profile.get('ProfileId')}: unknown topology.",
            findings,
        )
        require(
            profile.get("ManagementPathIndependent") is True
            and "LAB_MANAGEMENT" in profile.get("NetworkSegments", [])
            and "LAB_DATA" in profile.get("NetworkSegments", []),
            f"{profile.get('ProfileId')}: management and data paths are not separate.",
            findings,
        )
        require(
            profile.get("RuntimeImplementationStatus")
            == "PLANNED_NOT_IMPLEMENTED"
            and profile.get("CleanupPolicy") == "REGISTERED_OBJECT_IDS_ONLY",
            f"{profile.get('ProfileId')}: runtime or cleanup status is overstated.",
            findings,
        )


def validate_dependencies(
    root: Path,
    rows: list[dict[str, str]],
    findings: list[str],
) -> None:
    _, inventory_rows = load_csv(root / "Metadata/Inventory/Objects.csv")
    installed_objects = {
        row.get("ObjectName", "")
        for row in inventory_rows
        if row.get("ObjectName")
    }

    for row in rows:
        scenario_id = row.get("ScenarioId", "UNKNOWN")
        analyzers = split_values(row.get("PrimaryAnalyzers", ""))
        status = row.get("DependencyStatus")
        require(
            len(analyzers) == len(set(analyzers)) and bool(analyzers),
            f"{scenario_id}: analyzer dependency list is empty or duplicated.",
            findings,
        )
        if status in {"AVAILABLE", "AVAILABLE_WITH_PLATFORM_LIMIT"}:
            for analyzer in analyzers:
                require(
                    analyzer in installed_objects,
                    f"{scenario_id}: analyzer {analyzer} is absent from the inventory.",
                    findings,
                )
        elif status == "BLOCKED_BY_OPS_005":
            require(
                scenario_id == "LAB-LINK-001"
                and analyzers == ["USP_LinkedServerAnalysis"]
                and "USP_LinkedServerAnalysis" not in installed_objects,
                "OPS-005 dependency boundary is inconsistent.",
                findings,
            )
        else:
            findings.append(f"{scenario_id}: unknown analyzer dependency status.")


def validate_safety(rows: list[dict[str, str]], findings: list[str]) -> None:
    for row in rows:
        scenario_id = row.get("ScenarioId", "UNKNOWN")
        capabilities = set(split_values(row.get("RequiredCapabilities", "")))
        gate_ids = set(split_values(row.get("ExternalEvidenceGateIds", "")))
        approval = row.get("RequireExplicitApproval")
        management_path = row.get("RequireIndependentManagementPath")
        boundary = row.get("AssertionBoundary", "").lower()

        require(
            row.get("CleanupPolicy") == "REGISTERED_OBJECT_IDS_ONLY",
            f"{scenario_id}: cleanup boundary is unsafe.",
            findings,
        )
        require(
            approval in {"0", "1"} and management_path in {"0", "1"},
            f"{scenario_id}: Boolean contract flags are invalid.",
            findings,
        )
        if "NETWORK_FAULT_LAYER" in capabilities:
            require(
                "LAB-GATE-WAVE4-NETWORK-FAULT" in gate_ids
                and approval == "1"
                and management_path == "1",
                f"{scenario_id}: network fault lacks approval, management path, or gate.",
                findings,
            )
        if row.get("ScenarioClass") == "NETWORK":
            require(
                approval == "1",
                f"{scenario_id}: network mutation lacks explicit approval.",
                findings,
            )
        require(
            any(
                fragment in boundary
                for fragment in (
                    "exact",
                    "do not",
                    "without asserting",
                    "not a benchmark",
                    "does not promise",
                    "do not claim",
                )
            ),
            f"{scenario_id}: assertion boundary accepts host-specific exact values.",
            findings,
        )
        require(
            len(row.get("StatePreconditions", "")) >= 80,
            f"{scenario_id}: state preconditions are insufficient.",
            findings,
        )


def validate_evidence_gates(
    root: Path,
    topology_contract: dict[str, object],
    findings: list[str],
) -> None:
    registry_gates = {
        item.get("GateId"): item
        for item in topology_contract.get("ExternalEvidenceGates", [])
        if isinstance(item, dict)
    }
    require(
        set(registry_gates) == set(REQUIRED_GATES),
        "Welle 4 topology contract external gates are incomplete.",
        findings,
    )

    _, gate_rows = load_csv(root / "Metadata/Quality/Lab_External_Evidence_Gates.csv")
    global_gates = {row.get("GateId"): row for row in gate_rows}
    for gate_id, expected in REQUIRED_GATES.items():
        registry_gate = registry_gates.get(gate_id, {})
        global_gate = global_gates.get(gate_id, {})
        require(
            registry_gate.get("Status") == "NOT_EXECUTED"
            and registry_gate.get("EvidencePolicy") == "SYNTHETIC_SUMMARY_ONLY",
            f"{gate_id}: topology contract evidence status is overstated.",
            findings,
        )
        require(
            all(global_gate.get(key) == value for key, value in expected.items()),
            f"{gate_id}: canonical external evidence gate is missing or overstated.",
            findings,
        )


def validate_status_boundary(root: Path, findings: list[str]) -> None:
    _, wave_rows = load_csv(root / "Metadata/Quality/Lab_Wave_Status.csv")
    wave_map = {row.get("WaveId"): row for row in wave_rows}
    wave_four = wave_map.get("LAB-001-WAVE4", {})
    require(
        wave_four.get("ContractStatus") == "PLANNED"
        and wave_four.get("RuntimeStatus") == "NOT_EXECUTED",
        "Welle 4 global status must remain planned until runtime actions exist.",
        findings,
    )


def validate_integration(root: Path, findings: list[str]) -> None:
    workflow = (root / ".github/workflows/lab-contract-validation.yml").read_text(
        encoding="utf-8"
    )
    validation = (root / "Lab/Validation/Invoke-LabValidation.ps1").read_text(
        encoding="utf-8"
    )
    readme = (root / "Lab/Scenarios/Infrastructure/README.md").read_text(
        encoding="utf-8"
    )

    for fragment in (
        "Validate_LAB001_Wave4_ContractFoundation.py",
        "Validate LAB-001 Wellen 0 to 4",
    ):
        require(fragment in workflow, f"Workflow integration lacks {fragment}.", findings)

    for fragment in (
        "wave4-topology-profiles.json",
        "wave4-topology-profile.schema.json",
        "Validate_LAB001_Wave4_ContractFoundation.py",
    ):
        require(
            fragment in validation,
            f"PowerShell validation integration lacks {fragment}.",
            findings,
        )

    for fragment in (
        "contract foundation",
        "NOT_EXECUTED",
        "registered object IDs",
        "independent management path",
        "OPS-005",
    ):
        require(
            fragment.lower() in readme.lower(),
            f"Welle 4 README lacks the boundary '{fragment}'.",
            findings,
        )


def validate_privacy(root: Path, findings: list[str]) -> None:
    paths = [
        root / "Lab/Contracts/wave4-topology-profile.schema.json",
        root / "Lab/Scenarios/Infrastructure/wave4-contracts.csv",
        root / "Lab/Scenarios/Infrastructure/wave4-topology-profiles.json",
        root / "Lab/Scenarios/Infrastructure/README.md",
    ]
    combined = "\n".join(path.read_text(encoding="utf-8") for path in paths)
    for pattern, label in FORBIDDEN_PATTERNS.items():
        if re.search(pattern, combined):
            findings.append(f"Forbidden {label} detected in the Welle 4 scope.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=".")
    args = parser.parse_args()
    root = Path(args.repository_root).resolve()
    findings: list[str] = []

    for relative_path in sorted(REQUIRED_FILES):
        require(
            (root / relative_path).is_file(),
            f"Missing required Welle 4 contract file: {relative_path}",
            findings,
        )

    contract_path = root / "Lab/Scenarios/Infrastructure/wave4-contracts.csv"
    topology_path = (
        root / "Lab/Scenarios/Infrastructure/wave4-topology-profiles.json"
    )
    if contract_path.is_file() and topology_path.is_file():
        header, rows = load_csv(contract_path)
        require(
            header == EXPECTED_HEADER,
            "Welle 4 contract CSV header is invalid.",
            findings,
        )
        topology_contract = load_json(topology_path)
        if not isinstance(topology_contract, dict):
            findings.append("Welle 4 topology contract root is not an object.")
        else:
            validate_catalog_alignment(root, rows, findings)
            validate_topologies(root, topology_contract, findings)
            validate_dependencies(root, rows, findings)
            validate_safety(rows, findings)
            validate_evidence_gates(root, topology_contract, findings)

    validate_status_boundary(root, findings)
    validate_integration(root, findings)
    validate_privacy(root, findings)

    if findings:
        for finding in findings:
            print(f"ERROR: {finding}")
        return 1

    print(
        "LAB-001 Welle 4 contract foundation validated: "
        "scenarios=18 topologies=4 external_gates=2 runtime=NOT_EXECUTED."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
