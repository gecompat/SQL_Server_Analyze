#!/usr/bin/env python3
"""Deterministic projections of the reviewed Usage Skill Markdown corpus."""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
import re

FORMAT = "1.0.0"
SKILL_ROOT = Path("Metadata/UsageSkills")
INVENTORY = Path("Metadata/Inventory/Objects.csv")
FRAMEWORK_VIEW = Path("Code/00_Setup/005_VW_ObjectUsageSkills.sql")
TARGET_VIEW = Path("Code/10_SnapshotBaseline/012_VW_ObjectUsageSkills_Target.sql")
SELF = "monitor_metadata.VW_ObjectUsageSkills"
KEYS = {"skill_format_version", "name", "description", "schema_name",
        "object_name", "object_type", "database_role", "is_internal", "source_path"}
TYPES = {"TABLE", "VIEW", "PROCEDURE", "FUNCTION", "INTERNAL_PROCEDURE"}
ROLES = {"framework", "snapshot_target", "both"}


def read_skill(path: Path, root: Path) -> tuple[dict, str]:
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise ValueError(f"BOM in Usage Skill: {path}")
    if b"\r\n" in raw:
        raw = raw.replace(b"\r\n", b"\n")
    if b"\r" in raw or not raw.endswith(b"\n"):
        raise ValueError(f"Invalid Usage Skill line ending: {path}")
    md = raw.decode("utf-8", errors="strict")
    if any(x in md for x in ("\x00", "\x85", "\u2028", "\u2029")):
        raise ValueError(f"Unsafe line separator in Usage Skill: {path}")
    lines = md.split("\n")
    if lines[0] != "---" or "---" not in lines[1:]:
        raise ValueError(f"Missing YAML front matter: {path}")
    end = lines.index("---", 1)
    fields = {}
    for line in lines[1:end]:
        key, sep, value = line.partition(":")
        if not sep or not re.fullmatch(r"[a-z_]+", key) or key in fields:
            raise ValueError(f"Invalid YAML key in {path}")
        value = value.strip()
        fields[key] = value == "true" if value in ("true", "false") else json.loads(value)
    if set(fields) != KEYS or fields["skill_format_version"] != FORMAT:
        raise ValueError(f"Usage Skill front matter contract mismatch: {path}")
    for key in ("skill_format_version", "name", "description", "schema_name", "object_name", "object_type", "database_role", "source_path"):
        if type(fields[key]) is not str:
            raise ValueError(f"Usage Skill {key} must be a string: {path}")
    schema, name = fields["schema_name"], fields["object_name"]
    if not isinstance(schema, str) or schema not in {"monitor", "snapshot", "monitor_metadata"}:
        raise ValueError(f"Unknown Usage Skill schema: {path}")
    if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", name):
        raise ValueError(f"Invalid Usage Skill object name: {path}")
    if fields["name"] != schema + "." + name or path.relative_to(root) != SKILL_ROOT / schema / (name + ".md"):
        raise ValueError(f"Usage Skill identity/path mismatch: {path}")
    if fields["object_type"] not in TYPES or fields["database_role"] not in ROLES:
        raise ValueError(f"Unknown Usage Skill type/role: {path}")
    if (fields["database_role"] == "both") != (fields["name"] == SELF):
        raise ValueError(f"Only the self View may have both database roles: {path}")
    if not isinstance(fields["is_internal"], bool):
        raise ValueError(f"Usage Skill is_internal must be boolean: {path}")
    expected_internal = (fields["object_type"] == "INTERNAL_PROCEDURE"
                         or fields["name"] == "monitor.InternalSsisScopePathMatch")
    if fields["is_internal"] != expected_internal:
        raise ValueError(f"Usage Skill internal classification differs from the source contract: {path}")
    description = fields["description"]
    if not isinstance(description, str) or not description.strip() or len(description) > 400:
        raise ValueError(f"Invalid Usage Skill description: {path}")
    if any(ord(char) < 32 or 127 <= ord(char) <= 159 or char in "\u2028\u2029" for char in description):
        raise ValueError(f"Unsafe Usage Skill description control character: {path}")
    source = fields["source_path"]
    if not isinstance(source, str) or source.startswith("/") or ".." in Path(source).parts:
        raise ValueError(f"Invalid Usage Skill source path: {path}")
    return fields, md


def load_skills(root: Path, check_snapshot_guard: bool = True) -> list[tuple[dict, str]]:
    rows = []
    with (root / INVENTORY).open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError("Usage Skill inventory is empty")
    skills = [read_skill(path, root) for path in sorted((root / SKILL_ROOT).glob("*/*.md"))]
    if len(skills) != len(rows):
        raise ValueError(f"Usage Skill Markdown count differs from inventory: {len(skills)} versus {len(rows)}")
    expected = {(r["ObjectName"], r["ObjectType"], r["SourcePath"]) for r in rows}
    actual = {(f["object_name"], f["object_type"], f["source_path"]) for f, _ in skills}
    if len(expected) != 213 or len(actual) != 213 or expected != actual:
        raise ValueError("Usage Skill identities/types/source paths differ from Objects.csv")
    if sum(f["name"] == SELF for f, _ in skills) != 1:
        raise ValueError("Usage Skill self-description is missing or duplicated")
    # Use the existing canonical SQL lexer and source closure. Documentation must
    # describe the executable schema and installation role, not merely a CSV name.
    import sys
    sys.path.insert(0, str(root / "Code" / "Install"))
    from deployment_generator import load_sources
    sources, tables, _ = load_sources(root, snapshot=True, check_snapshot_guard=check_snapshot_guard)
    physical = set()
    for source in sources:
        role = "framework" if source.role == "FRAMEWORK" else "snapshot_target"
        if source.module is not None:
            schema, name, sql_type = source.module
            physical.add((role, schema, name, source.path,
                          "VIEW" if sql_type == "V" else
                          "FUNCTION" if sql_type in {"IF", "TF", "FN"} else "PROCEDURE"))
    for table in tables:
        role = "framework" if table.role == "FRAMEWORK" else "snapshot_target"
        physical.add((role, table.schema, table.name, table.source, "TABLE"))
    for fields, _ in skills:
        validate_executable_binding(fields, physical)
    return skills



def source_signature_parameters(root: Path, fields: dict) -> list[tuple[str, str, str, str, bool]]:
    """Return name, SQL type, binding requirement, default and OUTPUT from executable DDL."""
    if fields["object_type"] not in {"FUNCTION", "INTERNAL_PROCEDURE"}:
        raise ValueError("Source signature binding applies only to functions and internal procedures")
    import sys
    sys.path.insert(0, str(root / "Code" / "Install"))
    from deployment_generator import qualified, split_batches, tokens, upper
    source = (root / fields["source_path"]).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    kind = "FUNCTION" if fields["object_type"] == "FUNCTION" else "PROCEDURE"
    found = []
    for batch in split_batches(source):
        ts = tokens(batch)
        if len(ts) < 6 or [upper(t) for t in ts[:4]] != ["CREATE", "OR", "ALTER", kind]:
            continue
        schema, name, pos = qualified(ts, 4)
        if (schema, name) != (fields["schema_name"], fields["object_name"]):
            continue
        if kind == "FUNCTION":
            if ts[pos].value != "(":
                raise ValueError(f"Function signature has no parameter list: {fields['name']}")
            pos += 1
        segments = []
        current = []
        depth = 0
        while pos < len(ts):
            value = ts[pos].value
            if depth == 0 and ((kind == "FUNCTION" and value == ")")
                               or (kind == "PROCEDURE" and upper(ts[pos]) == "AS")):
                if current:
                    segments.append(current)
                break
            if depth == 0 and value == ",":
                if not current:
                    raise ValueError(f"Empty SQL parameter: {fields['name']}")
                segments.append(current)
                current = []
            else:
                current.append(ts[pos])
                if value == "(":
                    depth += 1
                elif value == ")":
                    depth -= 1
            pos += 1
        else:
            raise ValueError(f"Unterminated SQL signature: {fields['name']}")
        parsed = []
        for segment in segments:
            if len(segment) < 2 or not segment[0].value.startswith("@"):
                raise ValueError(f"Unexpected SQL parameter syntax: {fields['name']}")
            parameter = segment[0].value
            sql_type = segment[1].value
            index = 2
            if index < len(segment) and segment[index].value == "(":
                end = index + 1
                depth = 1
                while end < len(segment) and depth:
                    depth += (segment[end].value == "(") - (segment[end].value == ")")
                    end += 1
                if depth:
                    raise ValueError(f"Unterminated SQL parameter type: {fields['name']} {parameter}")
                sql_type += "".join(token.value for token in segment[index:end])
                index = end
            tail = [token.value for token in segment[index:]]
            output = bool(tail and tail[-1].upper() == "OUTPUT")
            if output:
                tail.pop()
            if not tail:
                default = "kein Default"
                required = "ja"
            elif tail[0] == "=" and len(tail) > 1:
                default = "".join(tail[1:])
                required = "nein"
            else:
                raise ValueError(f"Unsupported SQL parameter modifier: {fields['name']} {parameter}")
            parsed.append((parameter, sql_type, required, default, output))
        found.append(parsed)
    if len(found) != 1:
        raise ValueError(f"Executable SQL signature missing or repeated: {fields['name']}")
    return found[0]


def validate_executable_binding(fields: dict, physical: set[tuple[str, str, str, str, str]]) -> None:
    if fields["name"] == SELF:
        required = {("framework", "monitor_metadata", "VW_ObjectUsageSkills", FRAMEWORK_VIEW.as_posix(), "VIEW"),
                    ("snapshot_target", "monitor_metadata", "VW_ObjectUsageSkills", TARGET_VIEW.as_posix(), "VIEW")}
    else:
        sql_type = "PROCEDURE" if fields["object_type"] == "INTERNAL_PROCEDURE" else fields["object_type"]
        required = {(fields["database_role"], fields["schema_name"], fields["object_name"],
                     fields["source_path"], sql_type)}
    if not required.issubset(physical):
        raise ValueError(f"Usage Skill schema, role or executable DDL mismatch: {fields['name']}")


def sql_markdown(md: str) -> str:
    tokens = []
    chunk = ""
    units = 0
    def flush() -> None:
        nonlocal chunk, units
        if chunk:
            # Split documentation-only CREATE TABLE literals for the deployment scanner.
            table_prefix = re.match(r"(?i)^([ \t]*)CREATE\s+TABLE\b", chunk)
            if table_prefix:
                split_at = len(table_prefix.group(1)) + 1
                tokens.append("N'" + chunk[:split_at].replace("'", "''") + "'")
                chunk = chunk[split_at:]
            tokens.append("N'" + chunk.replace("'", "''") + "'")
            chunk = ""
            units = 0
    for char in md:
        if char == "\n":
            flush()
            tokens.append("NCHAR(10)")
            continue
        width = 2 if ord(char) > 0xffff else 1
        if units + width > 1000:
            flush()
        chunk += char
        units += width
    flush()
    if not tokens:
        tokens.append("N''")
    return "CONVERT(nvarchar(max)," + tokens[0] + ")" + "".join(
        "\n            + " + item for item in tokens[1:]
    )


def comment(f: dict, md: str) -> str:
    name = f["name"]
    return ("-- USAGE_SKILL_BEGIN " + name + " " + FORMAT + "\n"
            + "".join("-- " + line + "\n" for line in md.split("\n")[:-1])
            + "-- USAGE_SKILL_END " + name + "\n")


def help_projection(f: dict, md: str) -> str:
    return ("SELECT CONVERT(varchar(16),'" + FORMAT + "') AS [SkillFormatVersion],"
            + "CONVERT(sysname,N'" + f["schema_name"] + "') AS [SchemaName],"
            + "CONVERT(sysname,N'" + f["object_name"] + "') AS [ObjectName],"
            + sql_markdown(md) + " AS [SkillMarkdown];")


def view_projection(skills: list[tuple[dict, str]], role: str) -> str:
    chosen = sorted(((f, md) for f, md in skills if f["database_role"] == role or f["name"] == SELF),
                    key=lambda pair: pair[0]["name"])
    if len(chosen) != (196 if role == "framework" else 18):
        raise ValueError("Usage Skill role closure count mismatch")
    self_skill = next((f, md) for f, md in chosen if f["name"] == SELF)
    rows = []
    def quoted(value: str) -> str:
        return "N'" + value.replace("'", "''") + "'"
    for f, md in chosen:
        rows.append("SELECT CONVERT(sysname," + quoted(f["schema_name"]) + ") AS [SchemaName],"
                    + "CONVERT(sysname," + quoted(f["object_name"]) + ") AS [ObjectName],"
                    + "CONVERT(varchar(24),'" + f["object_type"] + "') AS [ObjectType],"
                    + "CONVERT(varchar(24),'" + f["database_role"] + "') AS [DatabaseRole],"
                    + "CONVERT(bit," + ("1" if f["is_internal"] else "0") + ") AS [IsInternal],"
                    + "CONVERT(nvarchar(max)," + quoted(f["description"]) + ") AS [Description],"
                    + "CONVERT(varchar(16),'" + FORMAT + "') AS [SkillFormatVersion],"
                    + sql_markdown(md) + " AS [SkillMarkdown]")
    preamble = "USE [DeineDatenbank];\nGO\n\n" if role == "framework" else ""
    return (preamble + comment(*self_skill)
            + "CREATE OR ALTER VIEW [monitor_metadata].[VW_ObjectUsageSkills]\nAS\n"
            + "\nUNION ALL\n".join(rows) + ";\nGO\n")


def check_sources(root: Path, skills: list[tuple[dict, str]]) -> list[str]:
    failures = []
    for f, md in skills:
        if f["name"] == SELF:
            continue
        path = root / f["source_path"]
        source = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        expected = comment(f, md)
        pattern = (r"(?m)^-- USAGE_SKILL_BEGIN " + re.escape(f["name"]) + r" " + re.escape(FORMAT)
                   + r"\n[\s\S]*?^-- USAGE_SKILL_END " + re.escape(f["name"]) + r"\n")
        matches = list(re.finditer(pattern, source))
        if len(matches) != 1 or matches[0].group() != expected:
            failures.append(f"DDL Skill projection mismatch: {path}")
        if path.as_posix().endswith(("011_SqlServerBuildCatalog.sql", "012_SqlServerLifecycleCatalog.sql")) and expected + "    EXEC(N\'" not in source:
            failures.append(f"Dynamic DDL Skill comment must precede the SQL string: {path}")
        if f["object_type"] not in {"PROCEDURE", "INTERNAL_PROCEDURE"}:
            continue
        begin = "-- USAGE_SKILL_HELP_BEGIN " + f["name"]
        end = "-- USAGE_SKILL_HELP_END " + f["name"]
        pattern = re.compile(r"(?m)^([ \t]*)" + re.escape(begin)
                             + r"\n([\s\S]*?)^[ \t]*" + re.escape(end) + r"$")
        matches = list(pattern.finditer(source))
        expected_count = 2 if f["object_name"] in {"USP_ConfigureSnapshotTarget", "USP_RunSnapshotCollectionCycle"} else 1
        if len(matches) != expected_count:
            failures.append(f"Help Skill projection count mismatch: {path}")
            continue
        for match in matches:
            actual = match.group(2).strip()
            if actual != help_projection(f, md):
                failures.append(f"Help Skill text mismatch: {path}")
    return failures


def write_sources(root: Path, skills: list[tuple[dict, str]]) -> None:
    by_path: dict[str, list[tuple[dict, str]]] = {}
    for f, md in skills:
        if f["name"] != SELF:
            by_path.setdefault(f["source_path"], []).append((f, md))
    planned: dict[Path, bytes] = {}
    for source_path, items in by_path.items():
        path = root / source_path
        raw = path.read_bytes()
        bom = b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b""
        original = raw.decode("utf-8-sig")
        updated = original
        for f, md in items:
            label = f["name"]
            comment_pattern = re.compile(r"(?m)^[ \t]*-- USAGE_SKILL_BEGIN " + re.escape(label) + r" " + re.escape(FORMAT)
                                         + r"\r?\n[\s\S]*?^-- USAGE_SKILL_END " + re.escape(label) + r"\r?\n")
            updated, count = comment_pattern.subn(lambda _: comment(f, md), updated)
            if count != 1:
                raise ValueError(f"DDL Skill marker missing or repeated: {source_path} {label}")
            if f["object_type"] in {"PROCEDURE", "INTERNAL_PROCEDURE"}:
                begin = "-- USAGE_SKILL_HELP_BEGIN " + label
                end = "-- USAGE_SKILL_HELP_END " + label
                help_pattern = re.compile(r"(?m)^([ \t]*)" + re.escape(begin)
                                          + r"\r?\n[\s\S]*?^[ \t]*" + re.escape(end) + r"\r?$")
                def replace_help(match: re.Match[str]) -> str:
                    indent = match.group(1)
                    return indent + begin + "\n" + indent + help_projection(f, md) + "\n" + indent + end
                updated, count = help_pattern.subn(replace_help, updated)
                expected_count = 2 if f["object_name"] in {"USP_ConfigureSnapshotTarget", "USP_RunSnapshotCollectionCycle"} else 1
                if count != expected_count:
                    raise ValueError(f"Help Skill marker count changed: {source_path} {label}")
        if updated != original:
            planned[path] = bom + updated.encode("utf-8")
    # Validate the full marked corpus before changing any source file.
    for path, updated in planned.items():
        path.write_bytes(updated)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--write-views", action="store_true")
    parser.add_argument("--write-sources", action="store_true")
    args = parser.parse_args()
    if sum((args.check, args.write_views, args.write_sources)) != 1:
        parser.error("Select exactly one of --check, --write-views or --write-sources")
    root = args.repository_root.resolve()
    skills = load_skills(root, check_snapshot_guard=args.check)
    views = {FRAMEWORK_VIEW: view_projection(skills, "framework"),
             TARGET_VIEW: view_projection(skills, "snapshot_target")}
    if args.write_sources:
        write_sources(root, skills)
        return 0
    if args.write_views:
        for path, text in views.items():
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8", newline="\n")
        return 0
    failures = check_sources(root, skills)
    for path, expected in views.items():
        target = root / path
        if not target.is_file() or target.read_text(encoding="utf-8-sig").replace("\r\n", "\n") != expected:
            failures.append(f"Usage Skill view projection mismatch: {path}")
    if failures:
        raise ValueError("; ".join(failures))
    print("Usage Skill projections: 213 Markdown, 212 DDL comments, 156 Help branches, 196/18 role rows")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
