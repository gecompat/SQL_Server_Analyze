#!/usr/bin/env python3
"""Validate IQP typed results, comparison boundaries and shared signal export."""
from __future__ import annotations
import argparse
import re
from pathlib import Path

PROCEDURE_PATH = Path("Code/05_QueryStore/090_USP_IntelligentQueryProcessingAnalysis.sql")
COLLATION = "COLLATE SQL_Latin1_General_CP1_CS_AS"
PREFIX = "#IntelligentQueryProcessingAnalysis_"
SIGNALS = (("DatabaseId", "int", "NOT NULL"), ("DatabaseName", "sysname", "NOT NULL"),
           ("SignalCode", "varchar(80)", "NOT NULL"), ("IsSourceAvailable", "bit", "NOT NULL"),
           ("EvidenceCount", "bigint", "NULL"), ("Interpretation", "nvarchar(1000)", "NOT NULL"))
FIELDS = {
    "DatabaseState": (("DatabaseId", "int", "NOT NULL"), ("DatabaseName", "sysname", "NOT NULL"),
        ("CompatibilityLevel", "tinyint", "NULL"), ("QueryStoreActualStateDesc", "nvarchar(60)", "NULL"),
        ("QueryStoreDesiredStateDesc", "nvarchar(60)", "NULL"), ("QueryStoreReadonlyReason", "bigint", "NULL"),
        ("PspEligible", "bit", "NOT NULL"), ("OppoEligible", "bit", "NOT NULL"),
        ("FindingCode", "varchar(80)", "NOT NULL"), ("FindingSeverity", "varchar(16)", "NOT NULL"),
        ("EvidenceLimit", "nvarchar(1000)", "NOT NULL")),
    "Configuration": (("DatabaseId", "int", "NOT NULL"), ("DatabaseName", "sysname", "NOT NULL"),
        ("ConfigurationName", "sysname", "NOT NULL"), ("ConfigurationValue", "nvarchar(4000)", "NULL"),
        ("IsValueDefault", "bit", "NULL")),
    "AutomaticTuning": (("DatabaseId", "int", "NOT NULL"), ("DatabaseName", "sysname", "NOT NULL"),
        ("OptionName", "nvarchar(60)", "NOT NULL"), ("DesiredStateDesc", "nvarchar(60)", "NULL"),
        ("ActualStateDesc", "nvarchar(60)", "NULL"), ("ReasonDesc", "nvarchar(120)", "NULL")),
    "Signals": SIGNALS, "SignalsExport": SIGNALS,
}
AUX = {
    "DatabaseCandidates": {"DatabaseName": "sysname", "StateDesc": "nvarchar(60)",
        "UserAccessDesc": "nvarchar(60)", "CollationName": "sysname", "RecoveryModelDesc": "nvarchar(60)"},
    "DatabaseCandidateWarnings": {"RequestedName": "sysname", "StatusCode": "varchar(40)", "ErrorMessage": "nvarchar(2048)"},
    "Errors": {"DatabaseName": "sysname", "StatusCode": "varchar(40)", "ErrorMessage": "nvarchar(2048)"},
}
COMPARISONS = (
    "COALESCE(@ActualStateDesc, N''OFF'') " + COLLATION + " = N''OFF'' " + COLLATION,
    "@ActualStateDesc " + COLLATION + " = N''READ_ONLY'' " + COLLATION,
    "@DesiredStateDesc " + COLLATION + " = N''READ_WRITE'' " + COLLATION,
)
CONSUMERS = (
    "SELECT * FROM [" + PREFIX + "SignalsExport]\n             ORDER BY [DatabaseId], [SignalCode]\n             FOR JSON",
    "SELECT * FROM [" + PREFIX + "SignalsExport] ORDER BY [DatabaseId], [SignalCode];",
    "@SourceTable=N'" + PREFIX + "SignalsExport'",
    "@SourceTable = N'" + PREFIX + "SignalsExport'",
)
STATUS_BOUNDARIES = (
    "IF EXISTS (SELECT 1 FROM [" + PREFIX + "Errors])\n            SET @IsPartial = 1;",
    "ELSE IF @IsPartial = 1\n            SET @StatusCode = 'AVAILABLE_LIMITED';",
    "(SELECT 1 FROM [" + PREFIX + "DatabaseState] WHERE [FindingCode] <> 'IQP_EVIDENCE_AVAILABLE')\n            SET @StatusCode = 'AVAILABLE_WITH_FINDING';",
)


def table_ddl(source: str, suffix: str) -> str | None:
    m = re.search(r"CREATE TABLE \[" + re.escape(PREFIX + suffix) + r"\]\s*\((.*?)\);", source, re.S)
    return m.group(1) if m else None


def text_type(datatype: str) -> bool:
    return datatype == "sysname" or datatype.startswith(("varchar", "nvarchar"))


def validate_source(source: str) -> list[str]:
    failures = []
    for suffix, fields in FIELDS.items():
        ddl = table_ddl(source, suffix)
        if ddl is None:
            failures.append("missing typed table " + suffix)
            continue
        if tuple(re.findall(r"\[([^]]+)\]", ddl)) != tuple(n for n, _, _ in fields):
            failures.append("fields or ordinals differ: " + suffix)
        for name, datatype, nullable in fields:
            expected = f"[{name}] {datatype}" + (f" {COLLATION}" if text_type(datatype) else "") + f" {nullable}"
            m = re.search(r"\[" + re.escape(name) + r"\]([^\n]+)", ddl)
            if m is None or " ".join((f"[{name}]" + m.group(1)).split()) != expected:
                failures.append(f"field contract differs: {suffix}.{name}")
        if ddl.count(COLLATION) != sum(text_type(t) for _, t, _ in fields) or re.search(r"\bIDENTITY\b", ddl, re.I):
            failures.append("text count or identity differs: " + suffix)
    for suffix, fields in AUX.items():
        ddl = table_ddl(source, suffix)
        if ddl is None:
            failures.append("missing auxiliary table " + suffix)
            continue
        for name, datatype in fields.items():
            if not re.search(r"\[" + re.escape(name) + r"\]\s+" + re.escape(datatype + " " + COLLATION), ddl):
                failures.append(f"missing auxiliary collation: {suffix}.{name}")
        if ddl.count(COLLATION) != len(fields):
            failures.append("auxiliary text count differs: " + suffix)
    early = source.find("CREATE TABLE [" + PREFIX + "SignalsExport]")
    if early < 0 or early > source.find("EXEC [monitor].[USP_PrepareDatabaseCandidates]") or early > source.find("SET LOCK_TIMEOUT 0"):
        failures.append("export must exist before candidate helper and lock timeout")
    materialize = source.find("INSERT [" + PREFIX + "SignalsExport]")
    if materialize < source.find("SET @StatusCode = 'AVAILABLE_WITH_FINDING'") or materialize > source.find("IF @JsonErzeugen = 1"):
        failures.append("export must follow complete status evaluation before consumers")
    if not re.search(r"INSERT \[" + re.escape(PREFIX) + r"SignalsExport\]\s+SELECT TOP \(@Limit\) \*\s+FROM \[" + re.escape(PREFIX) + r"Signals\]\s+ORDER BY \[DatabaseId\], \[SignalCode\];", source):
        failures.append("shared signal cap or order differs")
    for consumer in CONSUMERS:
        if consumer not in source:
            failures.append("consumer does not use shared export: " + consumer)
    if "IF @MaxZeilen < 0 SET @Limit = 0;" not in source or source.find("IF @MaxZeilen < 0 SET @Limit = 0;") > source.find("EXEC [monitor].[USP_PrepareDatabaseCandidates]"):
        failures.append("negative limit must be safe before collection")
    for comparison in COMPARISONS:
        if source.count(comparison) != 2:
            failures.append("state comparison boundary differs: " + comparison)
    for boundary in STATUS_BOUNDARIES:
        if boundary not in source or source.find(boundary) > materialize:
            failures.append("complete status evaluation must precede export")
    for suffix in ("DatabaseState", "Configuration", "AutomaticTuning"):
        if source.count("SELECT TOP (@Limit) * FROM [" + PREFIX + suffix + "]") != 2:
            failures.append("existing RAW/JSON array cap differs: " + suffix)
    return failures


def validate(repository_root: Path) -> list[str]:
    return validate_source((repository_root / PROCEDURE_PATH).read_text(encoding="utf-8-sig"))


def self_test(source: str) -> None:
    assert not validate_source(source), validate_source(source)
    mutations = 0
    texts = {k: {n: t for n, t, _ in f if text_type(t)} for k, f in FIELDS.items()} | AUX
    for suffix, fields in texts.items():
        ddl = table_ddl(source, suffix)
        assert ddl is not None
        for name, datatype in fields.items():
            old = f"[{name}] {datatype} {COLLATION}"
            assert old in ddl
            assert validate_source(source.replace(ddl, ddl.replace(old, old.replace(COLLATION, ""), 1), 1))
            mutations += 1
    for suffix, fields in FIELDS.items():
        ddl = table_ddl(source, suffix)
        assert ddl is not None
        for old, new in (("[DatabaseId] int NOT NULL", "[DatabaseId] bigint NOT NULL"),
                         ("[DatabaseName] sysname " + COLLATION + " NOT NULL", "[DatabaseName] sysname " + COLLATION + " NULL"),
                         ("[DatabaseId] int NOT NULL", "[DatabaseId] int IDENTITY(1,1) NOT NULL")):
            assert validate_source(source.replace(ddl, ddl.replace(old, new, 1), 1))
            mutations += 1
    for old in CONSUMERS:
        assert validate_source(source.replace(old, old.replace("SignalsExport", "ExampleDifferentExport"), 1))
        mutations += 1
    for old in COMPARISONS:
        assert validate_source(source.replace(old, old.replace(COLLATION, ""), 1))
        mutations += 1
    for old in STATUS_BOUNDARIES:
        assert old in source
        assert validate_source(source.replace(old, "", 1))
        mutations += 1
    for old in ("IF @MaxZeilen < 0 SET @Limit = 0;", "SELECT TOP (@Limit) *\n    FROM [" + PREFIX + "Signals]\n    ORDER BY [DatabaseId], [SignalCode];"):
        assert old in source
        assert validate_source(source.replace(old, "", 1))
        mutations += 1
    print(f"IQP validator self-test passed ({mutations} mutations).")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    source = (args.repository_root / PROCEDURE_PATH).read_text(encoding="utf-8-sig")
    if args.self_test:
        self_test(source)
        return 0
    failures = validate_source(source)
    if failures:
        print("IQP validation failed: " + "; ".join(failures))
        return 1
    print("IQP typed/shared-signal collation validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
