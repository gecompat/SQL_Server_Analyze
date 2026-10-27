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

# Only named bounded deliveries may convert a researched gap into partial coverage.
KNOWN_RESEARCH_TO_PARTIAL_KEYS = {
    "DEPRECATION_BREAKING_CHANGE",
    "RLS_DYNAMIC_MASKING",
    "DISTRIBUTED_TRANSACTIONS",
}
RESEARCH_GAP_COHORT_FLOOR = 25  # Preserve the explicit research-gap cohort across named promotions.

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
    accounted_promotions = {
        row["CoverageKey"]
        for row in rows
        if row.get("CoverageKey") in KNOWN_RESEARCH_TO_PARTIAL_KEYS
        and row.get("CoverageStatus") == "PARTIAL_PRODUCT_FUNCTION"
    }
    research_gap_cohort = status_counts["RESEARCHED_NOT_IMPLEMENTED"] + len(
        accounted_promotions
    )
    if research_gap_cohort < RESEARCH_GAP_COHORT_FLOOR:
        errors.append(
            "too few explicit researched gaps and accounted known promotions "
            f"({research_gap_cohort} < {RESEARCH_GAP_COHORT_FLOOR})"
        )
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
        for required_marker in (
            "**Referenz:** `WI-0010`",
            "106 fachliche Bereiche",
            "### Priorität P1",
            "### Priorität P2",
            "### Priorität P3 und bedingte Vertiefung",
            "## Bewusste Grenzen",
            "Microsoft SQL Assessment DefaultRuleset",
        ):
            if required_marker not in document:
                errors.append(
                    f"coverage documentation missing required marker: {required_marker}"
                )

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


def coverage_fixture() -> list[dict[str, str]]:
    keys = sorted(REQUIRED_KEYS)
    sample_index = 0
    while len(keys) < 100:
        sample_key = f'SAMPLE_AREA_{sample_index:03d}'
        if sample_key not in keys:
            keys.append(sample_key)
        sample_index += 1

    researched = {
        'DEPRECATION_BREAKING_CHANGE',
        'RLS_DYNAMIC_MASKING',
        'DISTRIBUTED_TRANSACTIONS',
        *(f'SAMPLE_AREA_{index:03d}' for index in range(22)),
    }
    out_of_scope = {f'SAMPLE_AREA_{index:03d}' for index in range(23, 27)}
    domains = sorted(REQUIRED_DOMAINS)
    rows: list[dict[str, str]] = []
    for index, key in enumerate(keys):
        status = (
            'RESEARCHED_NOT_IMPLEMENTED'
            if key in researched
            else 'OUT_OF_SCOPE' if key in out_of_scope else 'IMPLEMENTED_BASELINE'
        )
        rows.append(
            {
                'CoverageKey': key,
                'Domain': domains[index % len(domains)],
                'Area': key.replace('_', ' '),
                'CoverageStatus': status,
                'CurrentEvidence': 'Synthetic validator fixture',
                'OpenQuestion': 'Bounded validator scenario',
                'Disposition': 'KEEP',
                'Priority': 'P1',
                'SuggestedOwner': 'Validator fixture',
                'VersionPlatform': 'SQL Server 2025',
                'PrimarySource': 'https://learn.microsoft.com/example',
            }
        )
    return rows


def self_test() -> None:
    all_researched_fixture = coverage_fixture()
    if validate_rows(list(EXPECTED_FIELDS), all_researched_fixture):
        raise AssertionError('all-researched fixture was rejected')

    prior_promotion_state = [dict(row) for row in all_researched_fixture]
    for row in prior_promotion_state:
        if row['CoverageKey'] == 'DEPRECATION_BREAKING_CHANGE':
            row['CoverageStatus'] = 'PARTIAL_PRODUCT_FUNCTION'
    if validate_rows(list(EXPECTED_FIELDS), prior_promotion_state):
        raise AssertionError('known deprecation promotion was rejected')

    current_promotions = [dict(row) for row in prior_promotion_state]
    for row in current_promotions:
        if row['CoverageKey'] == 'RLS_DYNAMIC_MASKING':
            row['CoverageStatus'] = 'PARTIAL_PRODUCT_FUNCTION'
    if validate_rows(list(EXPECTED_FIELDS), current_promotions):
        raise AssertionError('RLS and deprecation promotions were rejected')

    distributed_promotion = [dict(row) for row in prior_promotion_state]
    for row in distributed_promotion:
        if row['CoverageKey'] == 'DISTRIBUTED_TRANSACTIONS':
            row['CoverageStatus'] = 'PARTIAL_PRODUCT_FUNCTION'
    if validate_rows(list(EXPECTED_FIELDS), distributed_promotion):
        raise AssertionError('named MSDTC promotion was rejected')

    unrelated_promotion = [dict(row) for row in prior_promotion_state]
    for row in unrelated_promotion:
        if row['CoverageKey'] == 'SAMPLE_AREA_000':
            row['CoverageStatus'] = 'PARTIAL_PRODUCT_FUNCTION'
    if not any(
        'too few explicit researched gaps' in error
        for error in validate_rows(list(EXPECTED_FIELDS), unrelated_promotion)
    ):
        raise AssertionError('unrelated promotion reduced the research cohort')

    dropped_required_key = [
        dict(row)
        for row in distributed_promotion
        if row['CoverageKey'] != 'DISTRIBUTED_TRANSACTIONS'
    ]
    errors = validate_rows(list(EXPECTED_FIELDS), dropped_required_key)
    if not any('required coverage area missing: DISTRIBUTED_TRANSACTIONS' in e for e in errors):
        raise AssertionError('dropped MSDTC key was accepted')
    if not any('too few explicit researched gaps' in e for e in errors):
        raise AssertionError('dropped promotion reduced the cohort unnoticed')

    invalid_status = [dict(row) for row in distributed_promotion]
    for row in invalid_status:
        if row['CoverageKey'] == 'DISTRIBUTED_TRANSACTIONS':
            row['CoverageStatus'] = 'UNKNOWN_STATUS'
    errors = validate_rows(list(EXPECTED_FIELDS), invalid_status)
    if not any('unknown coverage status' in e for e in errors):
        raise AssertionError('invalid coverage status was accepted')
    if not any('too few explicit researched gaps' in e for e in errors):
        raise AssertionError('invalid promotion reduced the cohort unnoticed')

    duplicate = current_promotions + [dict(current_promotions[0])]
    if not any(
        'duplicate CoverageKey' in error
        for error in validate_rows(list(EXPECTED_FIELDS), duplicate)
    ):
        raise AssertionError('duplicate coverage key was accepted')


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
