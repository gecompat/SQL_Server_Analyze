#!/usr/bin/env python3
"""Validate the evidence-backed Wait Type catalog curation contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


EXPECTED_SEED_FILES = 4
EXPECTED_ROWS = 347
EXPECTED_CATALOG_SHA256 = "13c380f7baf6298475eb11afde3c47ffc8b009fbc6c9002a90c7fccff44e0011"
EXPECTED_SOURCE_REFERENCE = (
    "https://learn.microsoft.com/en-us/sql/relational-databases/"
    "system-dynamic-management-objects/sys-dm-os-wait-stats-transact-sql"
    "?view=sql-server-ver17"
)
OBSOLETE_NAMES = frozenset(
    {
        "CURSOR",
        "DBTABLE",
        "IDES",
        "LCK_MSCH_M",
        "LCK_M_RI_NL",
        "LCK_M_RI_S",
        "LCK_M_RI_U",
        "LCK_M_RI_X",
        "NETWORKIO",
        "PAGESUPP",
        "PARALLEL_PAGE_SUPPLIER",
        "PSS_CHILD",
        "SLEEP",
        "UMSTHREAD",
    }
)
CORRECTED_NAMES = frozenset(
    {"LCK_M_RIn_NL", "LCK_M_RIn_S", "LCK_M_RIn_U", "LCK_M_RIn_X"}
)


@dataclass(frozen=True)
class Finding:
    rule: str
    path: str


def parse_seed_row(line: str) -> list[str] | None:
    if not line.startswith("(N'"):
        return None
    values: list[str] = []
    index = 1
    while index < len(line):
        while index < len(line) and line[index] in " ,":
            index += 1
        if index >= len(line) or line[index] == ")":
            break
        if line.startswith("N'", index):
            index += 2
            value: list[str] = []
            while index < len(line):
                if line[index] == "'":
                    if index + 1 < len(line) and line[index + 1] == "'":
                        value.append("'")
                        index += 2
                        continue
                    index += 1
                    break
                value.append(line[index])
                index += 1
            values.append("".join(value))
            continue
        end = index
        while end < len(line) and line[end] not in ",)":
            end += 1
        values.append(line[index:end].strip())
        index = end
    return values


def catalog_hash(wait_types: list[str]) -> str:
    payload = "\n".join(sorted(wait_types)) + "\n"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate(repository_root: Path) -> tuple[list[Finding], int]:
    seed_root = repository_root / "Code" / "01_Common"
    seed_files = sorted(seed_root.glob("074?_WaitTypeCatalog_Seed_*.sql"))
    findings: list[Finding] = []
    rows: list[tuple[str, list[str]]] = []

    if len(seed_files) != EXPECTED_SEED_FILES:
        findings.append(Finding("SEED_FILE_COUNT", "Code/01_Common"))

    for path in seed_files:
        relative = path.relative_to(repository_root).as_posix()
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            findings.append(Finding("SEED_FILE_READ", relative))
            continue
        if text.count(EXPECTED_SOURCE_REFERENCE) != 2:
            findings.append(Finding("SOURCE_REFERENCE", relative))
        for line in text.splitlines():
            parsed = parse_seed_row(line)
            if parsed is None:
                continue
            if len(parsed) != 10:
                findings.append(Finding("SEED_ROW_FORMAT", relative))
                continue
            rows.append((relative, parsed))

    if len(rows) != EXPECTED_ROWS:
        findings.append(Finding("SEED_ROW_COUNT", "Code/01_Common"))

    names = [values[0] for _, values in rows]
    for name, count in Counter(names).items():
        if count != 1:
            path = next(path for path, values in rows if values[0] == name)
            findings.append(Finding("WAIT_TYPE_UNIQUE", path))

    for path, values in rows:
        name, source, quality = values[0], values[8], values[9]
        if source != "FRAMEWORK_CURATED" or quality != "FRAMEWORK_CURATED":
            findings.append(Finding("CURATION_STATUS", path))
        if name in OBSOLETE_NAMES:
            findings.append(Finding("REMOVED_NAME_PRESENT", path))

    if not CORRECTED_NAMES.issubset(names):
        findings.append(Finding("CORRECTED_NAME_MISSING", "Code/01_Common"))
    if catalog_hash(names) != EXPECTED_CATALOG_SHA256:
        findings.append(Finding("CATALOG_NAME_SET", "Code/01_Common"))

    evidence_path = repository_root / "Metadata" / "Quality" / "Wait_Type_Curation_Evidence.json"
    evidence_relative = evidence_path.relative_to(repository_root).as_posix()
    try:
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        result = evidence["result"]
        decisions = evidence["decisions"]
        if (
            result["catalogRows"] != EXPECTED_ROWS
            or result["catalogNameSetSha256"] != EXPECTED_CATALOG_SHA256
            or decisions["reviewRequiredRows"] != 332
            or decisions["curatedWithoutRename"] != 318
            or decisions["renamed"] != 4
            or decisions["removed"] != 10
        ):
            findings.append(Finding("EVIDENCE_COUNTS", evidence_relative))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, KeyError, TypeError):
        findings.append(Finding("EVIDENCE_FORMAT", evidence_relative))

    return findings, len(rows)


def run_self_test() -> list[Finding]:
    valid = "(N'GENERIC_WAIT',N'GROUP',2,0,N'Meaning',N'Typical',N'Impact',N'Checks',N'FRAMEWORK_CURATED',N'FRAMEWORK_CURATED'),"
    escaped = "(N'GENERIC_WAIT',N'GROUP',2,0,N'It''s generic',N'Typical',N'Impact',N'Checks',N'FRAMEWORK_CURATED',N'FRAMEWORK_CURATED');"
    malformed = "(N'GENERIC_WAIT',N'GROUP');"
    cases = {
        "VALID": (valid, 10, "GENERIC_WAIT"),
        "ESCAPED_QUOTE": (escaped, 10, "GENERIC_WAIT"),
        "MALFORMED": (malformed, 2, "GENERIC_WAIT"),
    }
    findings: list[Finding] = []
    for case_id, (text, expected_count, expected_name) in cases.items():
        parsed = parse_seed_row(text)
        if parsed is None or len(parsed) != expected_count or parsed[0] != expected_name:
            findings.append(Finding("SELF_TEST", case_id))
    expected_hash = hashlib.sha256(b"GENERIC_WAIT\n").hexdigest()
    if catalog_hash(["GENERIC_WAIT"]) != expected_hash:
        findings.append(Finding("SELF_TEST", "HASH"))
    return findings


def report(findings: list[Finding], scope: str, row_count: int) -> int:
    counts = Counter((item.rule, item.path) for item in findings)
    for (rule, path), count in sorted(counts.items()):
        print(
            "Wait catalog validation finding: "
            f"scope={scope} rule={rule} "
            f"path={json.dumps(path, ensure_ascii=True)} count={count}"
        )
    if findings:
        print(
            "Wait catalog validation blocked: "
            f"scope={scope} rows={row_count} findings={len(findings)}"
        )
        return 1
    print(
        "Wait catalog validation passed: "
        f"scope={scope} rows={row_count} findings=0"
    )
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", type=Path, default=Path.cwd())
    parser.add_argument("--self-test", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return report(run_self_test(), "SELF_TEST", 3)
    findings, row_count = validate(args.repository_root.resolve())
    return report(findings, "REPOSITORY", row_count)


if __name__ == "__main__":
    sys.exit(main())
