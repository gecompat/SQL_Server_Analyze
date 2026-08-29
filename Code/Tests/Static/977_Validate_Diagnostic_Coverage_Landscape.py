#!/usr/bin/env python3
"""Validate the durable SQL Server diagnostic coverage landscape."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path


EXPECTED_FIELDS = (
    "CoverageKey",
    "Domain",
    "Area",
    "CoverageStatus",
    "CurrentEvidence",
    "OpenQuestion",
    "Disposition",
    "Priority",
    "SuggestedOwner",
    "VersionPlatform",
    "PrimarySource",
)

ALLOWED_STATUS = {
    "IMPLEMENTED_DEEP",
    "IMPLEMENTED_BASELINE",
    "PARTIAL_PRODUCT_FUNCTION",
    "RESEARCHED_NOT_IMPLEMENTED",
    "EXTERNAL_EVIDENCE_REQUIRED",
    "OUT_OF_SCOPE",
}

ALLOWED_DISPOSITION = {
    "KEEP",
    "COMPLETE_EXISTING",
    "DOSSIER_CANDIDATE",
    "REGISTERED_ROADMAP",
    "EXTERNAL_COMPONENT",
    "EXPLICIT_EXCLUSION",
}

REQUIRED_DOMAINS = {
    "PLATFORM",
    "ENGINE",
    "CURRENT_STATE",
    "QUERY_PERFORMANCE",
    "STORAGE_RECOVERY",
    "HA_DR",
    "SECURITY",
    "DATA_FEATURES",
    "OPERATIONS",
    "INTEGRATION",
    "EXTERNAL_SCOPE",
}

REQUIRED_KEYS = {
    "LINUX_CONTAINER_LIMITS",
    "DEPRECATION_BREAKING_CHANGE",
    "DATABASE_SNAPSHOTS",
    "PLAN_GUIDES",
    "BACKUP_IMMUTABILITY_SECONDARY",
    "DATABASE_MIRRORING",
    "DISTRIBUTED_TRANSACTIONS",
    "PRINCIPALS_ROLE_PERMISSIONS",
    "AUTHENTICATION_LOGIN_LIFECYCLE",
    "TLS_NETWORK_ENDPOINTS",
    "RLS_DYNAMIC_MASKING",
    "SENSITIVITY_CLASSIFICATION",
    "LEDGER_INTEGRITY",
    "POLICY_BASED_MANAGEMENT",
    "CHANGE_EVENT_STREAMING",
    "FABRIC_MIRRORING",
    "EXTERNAL_REST_ENDPOINT",
    "GRAPH_DEEP",
    "SPATIAL_DEEP",
    "XML_DEEP",
    "FILESTREAM_FILETABLE",
    "DQS_MDS_LEGACY",
}


def read_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        fields = list(reader.fieldnames or [])
    return fields, rows


def validate_rows(fields: list[str], rows: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    if tuple(fields) != EXPECTED_FIELDS:
        errors.append("coverage landscape header differs from contract")
    if len(rows) < 100:
        errors.append(f"coverage landscape is too narrow: {len(rows)} rows")

    keys = [row.get("CoverageKey", "") for row in rows]
    for key, count in Counter(keys).items():
        if count > 1:
            errors.append(f"duplicate CoverageKey: {key}")
    for key in sorted(REQUIRED_KEYS - set(keys)):
        errors.append(f"required coverage area missing: {key}")

    domains: set[str] = set()
    status_counts: Counter[str] = Counter()
    for index, row in enumerate(rows, start=2):
        if any(value is None or not value.strip() for value in row.values()):
            errors.append(f"empty coverage field at row {index}")
            continue
        key = row["CoverageKey"]
        if not re.fullmatch(r"[A-Z][A-Z0-9_]+", key):
            errors.append(f"invalid CoverageKey at row {index}: {key}")
        domains.add(row["Domain"])
        status = row["CoverageStatus"]
        status_counts[status] += 1
        if status not in ALLOWED_STATUS:
            errors.append(f"unknown coverage status at row {index}: {status}")
        disposition = row["Disposition"]
        if disposition not in ALLOWED_DISPOSITION:
            errors.append(f"unknown disposition at row {index}: {disposition}")
        if not row["PrimarySource"].startswith("https://learn.microsoft.com/"):
            errors.append(f"non-Microsoft primary source at row {index}: {key}")

    for domain in sorted(REQUIRED_DOMAINS - domains):
        errors.append(f"required coverage domain missing: {domain}")
    if status_counts["RESEARCHED_NOT_IMPLEMENTED"] < 25:
        errors.append("too few explicit researched gaps")
    if status_counts["OUT_OF_SCOPE"] < 4:
        errors.append("explicit product exclusions are incomplete")
    return errors


def validate_repository(root: Path) -> list[str]:
    matrix_path = root / "Metadata/Quality/Diagnostic_Coverage_Landscape.csv"
    if not matrix_path.is_file():
        return ["coverage landscape matrix is missing"]
    fields, rows = read_rows(matrix_path)
    errors = validate_rows(fields, rows)

    document_path = (
        root
        / "AI_Metadata/Internal_Documentation/Research/SQL_Server_Diagnostic_Coverage_Landscape.md"
    )
    if not document_path.is_file():
        errors.append("coverage landscape documentation is missing")
    else:
        document = document_path.read_text(encoding="utf-8-sig")
        for token in (
            "**Referenz:** `WI-0010`",
            "106 fachliche Bereiche",
            "### Priorität P1",
            "### Priorität P2",
            "### Priorität P3 und bedingte Vertiefung",
            "## Bewusste Grenzen",
            "Microsoft SQL Assessment DefaultRuleset",
        ):
            if token not in document:
                errors.append(f"coverage documentation missing token: {token}")

    registry_path = root / "Metadata/Governance/Artifact_Registry.json"
    registry = json.loads(registry_path.read_text(encoding="utf-8-sig"))
    work_item = registry.get("artifacts", {}).get("WI-0010")
    if not isinstance(work_item, dict):
        errors.append("WI-0010 is not registered")
    else:
        expected = {
            "artifact_uid": "urn:uuid:01a04f38-f7be-7ec4-a2e7-c89f0725a5ad",
            "kind": "work_item",
            "registration_state": "REGISTERED",
            "status": "RESEARCHED_NOT_IMPLEMENTED",
            "wave": "CONTINUOUS_INTAKE",
            "locator": "AI_Metadata/Internal_Documentation/Research/SQL_Server_Diagnostic_Coverage_Landscape.md",
        }
        for field, value in expected.items():
            if work_item.get(field) != value:
                errors.append(f"WI-0010 registry field differs: {field}")
        if {"type": "parent", "target": "WI-0001"} not in work_item.get(
            "relations", []
        ):
            errors.append("WI-0010 lacks WI-0001 parent relation")

    roadmap = (
        root
        / "AI_Metadata/Internal_Documentation/Architecture/Long_Term_Development_Roadmap.md"
    ).read_text(encoding="utf-8-sig")
    next_steps = (
        root / "AI_Metadata/Internal_Documentation/Quality/Next_Steps.md"
    ).read_text(encoding="utf-8-sig")
    future = (root / "Metadata/Quality/Future_Enhancement_Backlog.csv").read_text(
        encoding="utf-8-sig"
    )
    implementation = (root / "Metadata/Quality/Implementation_Status.csv").read_text(
        encoding="utf-8-sig"
    )
    for label, text in (
        ("roadmap", roadmap),
        ("next steps", next_steps),
        ("future backlog", future),
        ("implementation status", implementation),
    ):
        if "WI-0010" not in text:
            errors.append(f"{label} does not reference WI-0010")
    return sorted(set(errors))


def self_test() -> None:
    sample = {
        field: "value" for field in EXPECTED_FIELDS
    }
    sample.update(
        {
            "CoverageKey": "SAMPLE_KEY",
            "Domain": "PLATFORM",
            "CoverageStatus": "IMPLEMENTED_DEEP",
            "Disposition": "KEEP",
            "PrimarySource": "https://learn.microsoft.com/example",
        }
    )
    errors = validate_rows(list(EXPECTED_FIELDS), [sample])
    if not any("too narrow" in error for error in errors):
        raise AssertionError("narrow fixture was accepted")
    duplicate = [dict(sample), dict(sample)]
    errors = validate_rows(list(EXPECTED_FIELDS), duplicate)
    if not any("duplicate CoverageKey" in error for error in errors):
        raise AssertionError("duplicate fixture was accepted")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        print("Diagnostic coverage landscape validator self-test passed.")
        return 0
    errors = validate_repository(args.repository_root.resolve())
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Diagnostic coverage landscape is consistent: areas=106 findings=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
