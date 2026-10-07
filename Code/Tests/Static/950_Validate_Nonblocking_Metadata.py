#!/usr/bin/env python3
"""Validate nonblocking metadata access and collision-resistant temp names."""

from __future__ import annotations

import collections
import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[3]
CODE = ROOT / "Code"

FORBIDDEN_METADATA_FUNCTIONS = (
    "OBJECT_ID",
    "OBJECT_NAME",
    "OBJECT_SCHEMA_NAME",
    "SCHEMA_NAME",
    "DB_NAME",
    "COL_LENGTH",
    "OBJECT_DEFINITION",
    "SCHEMA_ID",
    "DATABASEPROPERTYEX",
)

SYS_SOURCE = re.compile(
    r"\b(?:FROM|JOIN)\s+"
    r"(?P<source>(?:(?:\[[^\]\r\n]+\]|[A-Za-z_][A-Za-z0-9_]*)\.)?"
    r"\[?sys\]?\.\[?[A-Za-z_][A-Za-z0-9_]*\]?)",
    re.IGNORECASE,
)
SYSTEM_DATABASE_SOURCE = re.compile(
    r"\b(?:FROM|JOIN)\s+"
    r"(?P<source>\[?(?:master|msdb|tempdb)\]?\."
    r"\[?(?:dbo|sys|cdc)\]?\.\[?[A-Za-z_][A-Za-z0-9_]*\]?)",
    re.IGNORECASE,
)
NOLOCK_AFTER_SOURCE = re.compile(
    r"^\s*(?:(?:AS\s+)?(?:\[[A-Za-z_][A-Za-z0-9_]*\]|[A-Za-z_][A-Za-z0-9_]*)\s+)?"
    r"WITH\s*\(\s*NOLOCK\s*\)",
    re.IGNORECASE,
)
TEMP_CREATE = re.compile(
    r"(?:CREATE\s+TABLE|INTO)\s+\[?(?P<name>#(?!#)[A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)

# One controlled test fixture implements the existing parent's input contract.
# It remains visible to the ordinary producer inventory; only this exact pair
# may share the name after the test's ownership and cleanup checks succeed.
SNAPSHOT_NAME = "#plancacheanalysis_querystatssnapshot"
SNAPSHOT_PRODUCER = "Code/04_PlanCache/060_USP_PlanCacheAnalysis.sql"
SNAPSHOT_FIXTURE = "Code/Tests/Common/181_QueryHashAnalysis_Collation_Runtime_Contract.sql"


def without_comments(text: str) -> str:
    tokens = re.compile(r"N?'(?:''|[^'])*'|--[^\r\n]*|/\*.*?\*/", re.DOTALL)
    return tokens.sub(
        lambda match: match.group(0) if match.group(0).startswith(("'", "N'")) else " ",
        text,
    )


def controlled_fixture_errors(text: str) -> list[str]:
    """Check the literal ownership/cleanup contract, without hiding fixture DDL."""
    executable = without_comments(text)
    name = re.escape("#PlanCacheAnalysis_QueryStatsSnapshot")
    creates = [match for match in TEMP_CREATE.finditer(executable)
               if match.group("name").casefold() == SNAPSHOT_NAME]
    guard = re.search(
        rf"IF\s+OBJECT_ID\s*\(\s*N?'tempdb\.\.{name}'\s*\)\s+IS\s+NOT\s+NULL"
        r"\s+THROW\s+58301\s*,\s*N?'QUERY_HASH_FOREIGN_SNAPSHOT'\s*,\s*1\s*;",
        executable, re.IGNORECASE,
    )
    issues = []
    if len(creates) != 1:
        issues.append("controlled fixture must create its snapshot exactly once")
    if guard is None or not creates or guard.end() > creates[0].start():
        issues.append("foreign snapshot rejection must precede fixture creation")
    drops = list(re.finditer(rf"\bDROP\s+TABLE\s+\[?{name}\]?\s*;", executable, re.IGNORECASE))
    try_start = re.search(r"\bBEGIN\s+TRY\b", executable, re.IGNORECASE)
    catches = list(re.finditer(r"\bEND\s+TRY\s+BEGIN\s+CATCH\b", executable, re.IGNORECASE))
    outer_catch = catches[-1] if catches else None
    if (try_start is None or outer_catch is None or len(drops) != 2
        or not (try_start.end() < drops[0].start() < outer_catch.start())):
        issues.append("owned snapshot success cleanup must be inside the test TRY")
    catch_text = executable[outer_catch.end():] if outer_catch else ""
    catch_cleanup = re.search(
        rf"IF\s+OBJECT_ID\s*\(\s*N?'tempdb\.\.{name}'\s*\)\s+IS\s+NOT\s+NULL"
        rf"\s+DROP\s+TABLE\s+\[?{name}\]?\s*;",
        catch_text, re.IGNORECASE,
    )
    if catch_cleanup is None or not re.search(r"\bTHROW\s*;\s*END\s+CATCH\s*;", catch_text, re.IGNORECASE):
        issues.append("owned snapshot CATCH cleanup and rethrow are required")
    return issues


def controlled_collision(name: str, owners: list[str], fixture_valid: bool) -> bool:
    return (fixture_valid and name == SNAPSHOT_NAME and len(owners) == 2
            and {owner.replace("\\", "/") for owner in owners} == {SNAPSHOT_PRODUCER, SNAPSHOT_FIXTURE})


def self_test() -> None:
    source = (ROOT / SNAPSHOT_FIXTURE).read_text(encoding="utf-8-sig")
    assert not controlled_fixture_errors(source)
    guard = "IF OBJECT_ID(N'tempdb..#PlanCacheAnalysis_QueryStatsSnapshot') IS NOT NULL\n    THROW 58301,N'QUERY_HASH_FOREIGN_SNAPSHOT',1;"
    drop = "DROP TABLE #PlanCacheAnalysis_QueryStatsSnapshot;"
    assert source.count(guard) == 1 and source.count(drop) == 2
    create = source.index("CREATE TABLE #PlanCacheAnalysis_QueryStatsSnapshot")
    misplaced = source.replace(guard, "", 1)
    insertion = misplaced.index("CREATE TABLE #ExampleHashSchema")
    misplaced = misplaced[:insertion] + guard + "\n" + misplaced[insertion:]
    mutations = [
        source.replace(guard, "", 1),
        source.replace(guard, "/*" + guard + "*/", 1),
        source.replace(guard, guard.replace("IS NOT NULL", "IS NULL"), 1),
        misplaced,
        source.replace(drop, "", 1),
        source[:source.rfind(drop)] + source[source.rfind(drop):].replace(drop, "", 1),
        source.replace(drop, "/*" + drop + "*/", 1),
        source[:source.rfind(" THROW;")] + source[source.rfind(" THROW;"):].replace(" THROW;", "", 1),
        source[:create] + "CREATE TABLE #PlanCacheAnalysis_QueryStatsSnapshot(x int);\n" + source[create:],
    ]
    for mutation in mutations:
        assert controlled_fixture_errors(mutation), "undetected controlled-fixture mutation"
    pair = [SNAPSHOT_PRODUCER, SNAPSHOT_FIXTURE]
    assert controlled_collision(SNAPSHOT_NAME, pair, True)
    assert not controlled_collision(SNAPSHOT_NAME, pair, False)
    assert not controlled_collision(SNAPSHOT_NAME, pair + [SNAPSHOT_FIXTURE], True)
    assert not controlled_collision(SNAPSHOT_NAME, [SNAPSHOT_PRODUCER, "Code/Tests/Common/Other.sql"], True)
    assert not controlled_collision("#ordinarytemp", pair, True)
    assert controlled_collision(SNAPSHOT_NAME, [owner.replace("/", "\\") for owner in pair], True)
    assert not controlled_collision(SNAPSHOT_NAME, [SNAPSHOT_PRODUCER, SNAPSHOT_PRODUCER], True)
    assert not controlled_collision("#ordinarytemp", ["Code/One.sql", "Code/Two.sql"], True)
    print("Nonblocking metadata controlled-fixture self-test passed: mutations=9 collision_cases=8.")


if "--self-test" in sys.argv[1:]:
    self_test()
    raise SystemExit(0)


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def file_token(path: pathlib.Path) -> str:
    stem = re.sub(r"^\d+_", "", path.stem)
    stem = re.sub(r"^USP_", "", stem, flags=re.IGNORECASE)
    return re.sub(r"[^A-Za-z0-9]", "", stem).casefold()


def normalized_temp_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9]", "", name[1:]).casefold()


errors: list[str] = []
temp_owners: dict[str, list[str]] = collections.defaultdict(list)
snapshot_fixture_valid = False

for path in sorted(CODE.rglob("*.sql")):
    if "Install" in path.parts:
        continue

    relative = path.relative_to(ROOT)
    text = path.read_text(encoding="utf-8-sig")
    is_test_source = "Tests" in relative.parts
    if relative.as_posix() == SNAPSHOT_FIXTURE:
        fixture_issues = controlled_fixture_errors(text)
        errors.extend(f"{relative}: {issue}" for issue in fixture_issues)
        snapshot_fixture_valid = not fixture_issues

    if relative.as_posix() == "Code/02_CurrentState/030_USP_CurrentBlocking.sql":
        executable_text = re.sub(r"N?'(?:''|[^'])*'", "''", text, flags=re.DOTALL)
        executable_text = re.sub(r"/\*.*?\*/", "", executable_text, flags=re.DOTALL)
        executable_text = re.sub(r"--[^\r\n]*", "", executable_text)
        if re.search(r"\bSET\s+LOCK_TIMEOUT\s+0\b", executable_text, re.IGNORECASE):
            errors.append(
                f"{relative}: LOCK_TIMEOUT 0 darf den Blocking-Kern nicht global beeinflussen; "
                "nur einzelne Anreicherungs-Batches sind zulässig"
            )
        if len(re.findall(r"N'SET\s+LOCK_TIMEOUT\s+0\s*;", text, re.IGNORECASE)) < 5:
            errors.append(
                f"{relative}: isolierte LOCK_TIMEOUT-0-Batches für Datenbank, Datei, "
                "benannte Ressource, Page und Katalog fehlen"
            )

    if not is_test_source:
        for function_name in FORBIDDEN_METADATA_FUNCTIONS:
            match = re.search(rf"\b{function_name}\s*\(", text, re.IGNORECASE)
            if match:
                errors.append(
                    f"{relative}:{line_number(text, match.start())}: "
                    f"blockierende Metadatenfunktion {function_name} ist nicht zulässig"
                )

    for match in (() if is_test_source else re.finditer(r"\bDB_ID\s*\(\s*[^)\s]", text, re.IGNORECASE)):
        errors.append(
            f"{relative}:{line_number(text, match.start())}: "
            "DB_ID(name) muss über master.sys.databases WITH (NOLOCK) ersetzt werden"
        )

    if not is_test_source and re.search(r"CREATE\s+OR\s+ALTER\s+PROCEDURE", text, re.IGNORECASE):
        uses_zero_timeout = re.search(r"SET\s+LOCK_TIMEOUT\s+0", text, re.IGNORECASE)
        captures_timeout = re.search(
            r"DECLARE\s+@OriginalLockTimeout\s+int\s*=\s*@@LOCK_TIMEOUT", text, re.IGNORECASE
        )
        restores_timeout = re.search(
            r"SET\s+@LockTimeoutSql\s*=\s*N?'SET\s+LOCK_TIMEOUT\s+'\s*\+\s*"
            r"CONVERT\s*\(\s*nvarchar\s*\(\s*20\s*\)\s*,\s*@OriginalLockTimeout\s*\)",
            text,
            re.IGNORECASE,
        )
        uses_isolated_parameter_timeout = re.search(
            r"N'SET\s+LOCK_TIMEOUT\s+'\s*\+\s*"
            r"CONVERT\s*\(\s*nvarchar\s*\(\s*11\s*\)\s*,\s*@LockTimeoutMs\s*\)",
            text,
            re.IGNORECASE,
        )
        asserts_unchanged_timeout = re.search(
            r"IF\s+@@LOCK_TIMEOUT\s*<>\s*@OriginalLockTimeout",
            text,
            re.IGNORECASE,
        )
        if (
            not uses_zero_timeout
            and not (captures_timeout and restores_timeout)
            and not (
                captures_timeout
                and uses_isolated_parameter_timeout
                and asserts_unchanged_timeout
            )
        ):
            errors.append(
                f"{relative}: Procedure setzt keinen nichtblockierenden LOCK_TIMEOUT "
                "oder stellt den ursprünglichen Wert nicht nachweisbar wieder her"
            )

    catalog_matches = [] if is_test_source else (
        list(SYS_SOURCE.finditer(text)) + list(SYSTEM_DATABASE_SOURCE.finditer(text))
    )
    seen_offsets: set[int] = set()
    for match in sorted(catalog_matches, key=lambda item: item.start()):
        if match.start() in seen_offsets:
            continue
        seen_offsets.add(match.start())
        tail = text[match.end() : match.end() + 180]
        if re.match(r"^\s*\(", tail):
            continue
        if not NOLOCK_AFTER_SOURCE.match(tail):
            errors.append(
                f"{relative}:{line_number(text, match.start())}: "
                f"Systemquelle {match.group('source')} ohne direktes WITH (NOLOCK)"
            )

    expected_prefix = file_token(path)
    for match in TEMP_CREATE.finditer(text):
        name = match.group("name")
        owner_key = name.casefold()
        temp_owners[owner_key].append(str(relative))
        if len(name) > 116:
            errors.append(
                f"{relative}:{line_number(text, match.start())}: "
                f"lokaler Temp-Name {name} überschreitet 116 Zeichen"
            )
        normalized_name = normalized_temp_name(name)
        related_name = (
            normalized_name.startswith(expected_prefix)
            or (len(normalized_name) >= 12 and expected_prefix.startswith(normalized_name))
            or (
                len(normalized_name) >= 12
                and len(expected_prefix) >= 12
                and normalized_name[:12] == expected_prefix[:12]
            )
        )
        if not is_test_source and not related_name:
            errors.append(
                f"{relative}:{line_number(text, match.start())}: "
                f"Temp-Name {name} besitzt keinen Bezug zu {path.stem}"
            )

for name, owners in sorted(temp_owners.items()):
    distinct_owners = sorted(set(owners))
    if len(owners) > 1:
        if controlled_collision(name, owners, snapshot_fixture_valid):
            continue
        errors.append(
            f"{name}: derselbe logische Temp-Name wird mehrfach erzeugt: "
            + ", ".join(distinct_owners)
        )

if errors:
    print("Nonblocking-Metadaten-/Temp-Namensvertrag verletzt:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)

print(
    "Nonblocking-Metadaten-/Temp-Namensvertrag erfüllt: "
    f"{len(temp_owners)} eindeutige lokale Temp-Namen geprüft."
)
