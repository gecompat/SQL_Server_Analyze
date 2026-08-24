#!/usr/bin/env python3
"""Validate consistency of roadmap, implementation and module maturity metadata."""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import Counter
from pathlib import Path


IMPLEMENTED = "IMPLEMENTED_ACTIONS_GATE"
ALLOWED_PRODUCT_STATUS = {
    IMPLEMENTED,
    "IMPLEMENTED_EXTERNAL_EVIDENCE_PENDING",
    "PARTIAL_PRODUCT_FUNCTION",
    "RESEARCHED_NOT_IMPLEMENTED",
    "OPTIONAL_FUTURE",
    "DESIGN_READY_EXTERNAL_COMPONENT_REQUIRED",
    "RUNBOOK_READY_EXTERNAL_EXECUTION_REQUIRED",
}
ALLOWED_MATURITY = {"COMPLETE", "PLANNED", "REMOVED"}
WORK_ITEM_PATTERN = re.compile(
    r"\b(?:DIAG|PLAN|OUT|OPS|SQL25|RUNTIME|FRAMEWORK-USAGE|COLL|SSIS|"
    r"ANALYZE-LAB|LAB|SC)-\d+(?:-EXPANSION)?\b"
)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
    if not reader.fieldnames or any(
        None in row or any(value is None for value in row.values()) for row in rows
    ):
        raise ValueError(f"CSV field count differs: {path}")
    return rows


def duplicate_values(rows: list[dict[str, str]], key: str) -> list[str]:
    counts = Counter(row[key] for row in rows)
    return sorted(value for value, count in counts.items() if count > 1)


def validate_rows(
    implementation: list[dict[str, str]],
    future: list[dict[str, str]],
    maturity: list[dict[str, str]],
) -> list[str]:
    errors: list[str] = []
    for label, rows, key in (
        ("Implementation_Status", implementation, "WorkItemId"),
        ("Future_Enhancement_Backlog", future, "EnhancementId"),
        ("Module_Maturity", maturity, "ModuleArea"),
    ):
        for value in duplicate_values(rows, key):
            errors.append(f"{label}: duplicate {key}={value}")

    implementation_by_id = {row["WorkItemId"]: row for row in implementation}
    for row in implementation:
        status = row["ProductStatus"]
        if status not in ALLOWED_PRODUCT_STATUS:
            errors.append(
                f"Implementation_Status: unknown status {row['WorkItemId']}={status}"
            )
        if not row["EvidenceReference"].strip():
            errors.append(
                f"Implementation_Status: missing evidence reference {row['WorkItemId']}"
            )

    for row in future:
        status = row["ImplementationStatus"]
        if status == IMPLEMENTED:
            continue
        implementation_row = implementation_by_id.get(row["EnhancementId"])
        if implementation_row is None:
            errors.append(
                "Future_Enhancement_Backlog: open item missing from "
                f"Implementation_Status {row['EnhancementId']}"
            )
        elif implementation_row["ProductStatus"] != status:
            errors.append(
                "Roadmap status differs: "
                f"{row['EnhancementId']} future={status} "
                f"implementation={implementation_row['ProductStatus']}"
            )

    for row in maturity:
        maturity_status = row["Maturity"]
        if maturity_status not in ALLOWED_MATURITY:
            errors.append(
                f"Module_Maturity: unknown maturity {row['ModuleArea']}={maturity_status}"
            )
        match = WORK_ITEM_PATTERN.search(row["Notes"])
        if not match:
            continue
        work_item_id = match.group(0)
        implementation_row = implementation_by_id.get(work_item_id)
        if (
            implementation_row
            and implementation_row["ProductStatus"] == IMPLEMENTED
            and maturity_status != "COMPLETE"
        ):
            errors.append(
                "Module maturity contradicts implemented status: "
                f"{row['ModuleArea']}->{work_item_id}={maturity_status}"
            )
        if (
            implementation_row
            and implementation_row["ProductStatus"] == "RESEARCHED_NOT_IMPLEMENTED"
            and maturity_status == "COMPLETE"
        ):
            errors.append(
                "Module maturity contradicts researched status: "
                f"{row['ModuleArea']}->{work_item_id}=COMPLETE"
            )
    return errors


def validate_repository(root: Path) -> list[str]:
    implementation = read_csv(root / "Metadata/Quality/Implementation_Status.csv")
    future = read_csv(root / "Metadata/Quality/Future_Enhancement_Backlog.csv")
    maturity = read_csv(root / "Metadata/Inventory/Module_Maturity.csv")
    errors = validate_rows(implementation, future, maturity)

    for row in implementation:
        reference = row["EvidenceReference"].strip()
        if reference.startswith(("http://", "https://")):
            continue
        if not (root / reference).is_file():
            errors.append(
                f"Implementation_Status: missing evidence file {row['WorkItemId']}={reference}"
            )

    next_steps = (
        root / "AI_Metadata/Internal_Documentation/Quality/Next_Steps.md"
    ).read_text(encoding="utf-8-sig")
    for token in (
        "### Abgeschlossen – SQL25-005",
        "`ANALYZE-LAB-001`",
        "`OPS-005`",
        "`OPS-006`",
        "`OPS-008`",
        "`COLL-001`",
    ):
        if token not in next_steps:
            errors.append(f"Next_Steps: missing canonical roadmap token {token}")
    return sorted(set(errors))


def self_test() -> None:
    implementation = [
        {
            "WorkItemId": "OPS-005",
            "ProductStatus": "RESEARCHED_NOT_IMPLEMENTED",
            "EvidenceReference": "example.md",
        }
    ]
    future = [
        {
            "EnhancementId": "OPS-005",
            "ImplementationStatus": "RESEARCHED_NOT_IMPLEMENTED",
        }
    ]
    maturity = [
        {
            "ModuleArea": "Linked Servers",
            "Maturity": "PLANNED",
            "Notes": "OPS-005 recherchiert und nicht implementiert",
        }
    ]
    if validate_rows(implementation, future, maturity):
        raise AssertionError("valid roadmap fixture was rejected")
    duplicate = maturity + [dict(maturity[0])]
    if not validate_rows(implementation, future, duplicate):
        raise AssertionError("duplicate roadmap fixture was accepted")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        print("Roadmap status validator self-test passed.")
        return 0
    errors = validate_repository(args.repository_root.resolve())
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Roadmap, implementation and module maturity metadata are consistent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
