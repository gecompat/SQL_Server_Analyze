#!/usr/bin/env python3
"""Validate the repository contract for the read-only SQL Audit analysis."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


PROCEDURE = "Code/08_ServerHealth/240_USP_AuditConfigurationAnalysis.sql"
REQUIRED = (
    "CREATE OR ALTER PROCEDURE [monitor].[USP_AuditConfigurationAnalysis]",
    "[sys].[server_audits]",
    "[sys].[server_audit_specifications]",
    "[sys].[database_audit_specifications]",
    "[sys].[dm_server_audit_status]",
    "InternalPrepareResultTables",
    "audits|serverSpecifications|databaseSpecifications|sourceStatus|warnings",
    "Auditlog-Payloads",
    "Auditobjekte erstellt, gestartet",
)
FORBIDDEN = ("fn_get_audit_file", "ALTER SERVER AUDIT", "CREATE SERVER AUDIT", "DROP SERVER AUDIT")


def validate(root: Path) -> list[str]:
    text = (root / PROCEDURE).read_text(encoding="utf-8-sig")
    errors = [f"missing {token}" for token in REQUIRED if token not in text]
    errors.extend(f"forbidden audit operation {token}" for token in FORBIDDEN if token in text)
    for relative in (
        "Code/Install/Install_All.sql",
        "Metadata/Inventory/Objects.csv",
        "Metadata/Inventory/Parameters.csv",
        "Metadata/Inventory/ResultSets.csv",
        "Documentation/Analysis_Guides/Procedures/USP_AuditConfigurationAnalysis.md",
    ):
        if "USP_AuditConfigurationAnalysis" not in (root / relative).read_text(encoding="utf-8-sig"):
            errors.append(f"missing registration in {relative}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert not [token for token in REQUIRED if token not in " ".join(REQUIRED)]
        print("Audit configuration contract validator self-test passed.")
        return 0
    errors = validate(args.repository_root.resolve())
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print("Audit configuration contract is consistent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
