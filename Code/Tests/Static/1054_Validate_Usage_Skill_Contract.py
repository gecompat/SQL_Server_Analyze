#!/usr/bin/env python3
"""Bind Usage Skill Markdown, SQL comments, Help and role Views to one source."""
from __future__ import annotations

import argparse
import importlib.util
from pathlib import Path
import sys
import re
import tempfile


def load_renderer(root: Path):
    path = root / "Code/Install/usage_skill_generator.py"
    spec = importlib.util.spec_from_file_location("usage_skill_generator", path)
    if spec is None or spec.loader is None:
        raise ValueError("Usage Skill generator cannot be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate(root: Path) -> None:
    renderer = load_renderer(root)
    skills = renderer.load_skills(root)
    failures = renderer.check_sources(root, skills)
    for role, path in (("framework", renderer.FRAMEWORK_VIEW),
                       ("snapshot_target", renderer.TARGET_VIEW)):
        actual = (root / path).read_text(encoding="utf-8-sig").replace("\r\n", "\n")
        if actual != renderer.view_projection(skills, role):
            failures.append(f"Role View projection mismatch: {path}")
    validate_usage_links(root)
    validate_parameter_contracts(root, skills)
    if failures:
        raise ValueError("; ".join(failures))



def validate_usage_links(root: Path) -> None:
    import urllib.parse
    markdown = sorted((root / "Metadata/UsageSkills").rglob("*.md"))
    link = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
    for path in markdown:
        fenced = False
        for line in path.read_text(encoding="utf-8").split("\n"):
            if line.startswith("```"):
                fenced = not fenced
                continue
            if fenced:
                continue
            # Inline SQL calls such as [fn](N'...') are not Markdown paths.
            line = re.sub(r"`[^`]*`", "", line)
            for match in link.finditer(line):
                target = match.group(1).split(" ", 1)[0]
                if target.startswith(("https://", "http://", "mailto:")):
                    continue
                if not (target.startswith(("./", "../", "#")) or ".md" in target or ".csv" in target):
                    continue
                pathname = urllib.parse.unquote(target.split("#", 1)[0])
                resolved = (path.parent / pathname).resolve() if pathname else path.resolve()
                if not resolved.is_relative_to(root.resolve()) or not resolved.is_file():
                    raise ValueError(f"Broken local Usage Skill link: {path} -> {target}")



def validate_parameter_contracts(root: Path, skills: list[tuple[dict, str]]) -> None:
    import csv
    renderer = load_renderer(root)
    with (root / "Metadata/Inventory/Parameters.csv").open(encoding="utf-8-sig", newline="") as stream:
        parameters = list(csv.DictReader(stream))
    by_proc: dict[str, list[dict[str, str]]] = {}
    for row in parameters:
        by_proc.setdefault(row["ProcedureName"], []).append(row)
    internal_help = 0
    for fields, md in skills:
        section = re.search(r"(?ms)^## Parameter und Eingabe\n([\s\S]*?)(?=^## |\Z)", md)
        if section is None:
            raise ValueError(f"Missing parameter section: {fields['name']}")
        body = section.group(1)
        rows = re.findall(r"(?m)^\| (@[A-Za-z0-9_]+) \| ([^|]+) \| (ja|nein) \| ([^|]+) \|$", body)
        individual = re.findall(r"(?m)^\*\*(@[A-Za-z0-9_]+):\*\*", body)
        if fields["object_type"] in {"TABLE", "VIEW"}:
            if rows or individual or "Keine Aufrufparameter." not in body:
                raise ValueError(f"Noncallable object has a parameter claim: {fields['name']}")
            continue
        if not rows or [row[0] for row in rows] != individual or len(set(individual)) != len(rows):
            raise ValueError(f"Usage Skill parameter rows and individual contracts differ: {fields['name']}")
        if "| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |" not in body:
            raise ValueError(f"Usage Skill parameter column contract missing: {fields['name']}")
        if fields["object_type"] == "PROCEDURE":
            expected = by_proc.get(fields["object_name"])
            if expected is None or len(expected) != len(rows):
                raise ValueError(f"Public procedure parameter inventory missing: {fields['name']}")
            for actual, inventory in zip(rows, expected):
                declared_default = inventory["DefaultExpression"]
                expected_default = ("kein Default; OUTPUT" if declared_default == "OUTPUT"
                                    else declared_default or "kein Default")
                required = "ja" if declared_default in {"", "OUTPUT"} else "nein"
                if (actual[0] != "@" + inventory["ParameterName"]
                    or actual[1].strip() != inventory["DataType"]
                    or actual[2] != required
                    or actual[3].strip() != expected_default):
                    raise ValueError(f"Public parameter type/order/default mismatch: {fields['name']} {actual[0]}")
        if fields["object_type"] in {"FUNCTION", "INTERNAL_PROCEDURE"}:
            signature = renderer.source_signature_parameters(root, fields)
            if len(signature) != len(rows):
                raise ValueError(f"SQL signature parameter count differs from Skill: {fields['name']}")
            for actual, (parameter, sql_type, required, default, output) in zip(rows, signature):
                formal_type = sql_type + (" OUTPUT" if output else "")
                if (actual[0], actual[1].strip(), actual[2], actual[3].strip()) != (
                    parameter, formal_type, required, default):
                    raise ValueError(f"SQL signature type/order/default differs from Skill: {fields['name']} {parameter}")
                paragraph = re.search(r"(?ms)^\*\*" + re.escape(parameter) + r":\*\*([\s\S]*?)(?=^\*\*@|^## |\Z)", body)
                if paragraph is None or (output and "OUTPUT" not in paragraph.group(1)):
                    raise ValueError(f"Output parameter contract missing: {fields['name']} {parameter}")
        if fields["object_type"] == "INTERNAL_PROCEDURE":
            if rows[-1] != ("@Hilfe", "bit", "nein", "0"):
                raise ValueError(f"Internal Help parameter is not last/default 0: {fields['name']}")
            internal_help += 1
    if internal_help != 25:
        raise ValueError(f"Internal Help population mismatch: {internal_help}")


def decode_sql_markdown(expression: str) -> str:
    prefix = "CONVERT(nvarchar(max),"
    if not expression.startswith(prefix):
        raise ValueError("Markdown expression has no max-length Unicode anchor")
    pos = len(prefix)
    result: list[str] = []
    piece_pattern = re.compile(r"N'(?P<string>(?:''|[^'])*)'|NCHAR\(10\)")
    first = True
    while pos < len(expression):
        if not first:
            glue = re.match(r"\s*\+\s*", expression[pos:])
            if glue is None:
                raise ValueError("Unexpected Markdown expression glue")
            pos += glue.end()
        match = piece_pattern.match(expression, pos)
        if match is None:
            raise ValueError("Unexpected Markdown expression token")
        result.append("\n" if match.group(0) == "NCHAR(10)"
                      else match.group("string").replace("''", "'"))
        pos = match.end()
        if first:
            if pos >= len(expression) or expression[pos] != ")":
                raise ValueError("Unicode anchor is not closed")
            pos += 1
            first = False
    return "".join(result)


def self_test(root: Path) -> None:
    import tempfile
    renderer = load_renderer(root)
    sample = ("x" * 999 + "😀" + "Apostroph ' und GO\n"
              + "    CREATE TABLE [nur Dokumentation]\n"
              + "create table [lower case]\n" + "z" * 5000 + "\n")
    expression = renderer.sql_markdown(sample)
    decoded = decode_sql_markdown(expression)
    if decoded != sample or len(decoded.encode("utf-16-le")) != len(sample.encode("utf-16-le")):
        raise ValueError("Full Unicode Markdown roundtrip or UTF-16 length changed")
    if "N'    C'\n            + N'REATE TABLE" not in expression or "N'c'\n            + N'reate table" not in expression:
        raise ValueError("Documentation CREATE TABLE literal was not split")
    if "N'CREATE TABLE" in expression or "N'    CREATE TABLE" in expression:
        raise ValueError("Documentation literal can be parsed as dynamic table DDL")
    try:
        truncated = decode_sql_markdown(expression[:-1])
    except ValueError:
        truncated = None
    if truncated == sample:
        raise ValueError("Truncated Markdown expression was accepted")
    physical = {("framework", "monitor", "TestTable",
                 "Code/Tests/UsageSkillFixture.sql", "TABLE")}
    binding = {"name": "monitor.TestTable", "schema_name": "monitor",
               "object_name": "TestTable", "object_type": "TABLE",
               "database_role": "framework",
               "source_path": "Code/Tests/UsageSkillFixture.sql"}
    renderer.validate_executable_binding(binding, physical)
    for mutation in (dict(binding, name="snapshot.TestTable", schema_name="snapshot"),
                     dict(binding, database_role="snapshot_target")):
        try:
            renderer.validate_executable_binding(mutation, physical)
        except ValueError:
            pass
        else:
            raise ValueError("Wrong executable schema or role passed validation")
    fields = {"name": "monitor.Test", "schema_name": "monitor", "object_name": "Test"}
    comment = renderer.comment(fields, "Zeile\nGO\n")
    if not all(line.startswith("-- ") or line.startswith("-- USAGE_SKILL_")
               for line in comment.split("\n") if line):
        raise ValueError("SQLCMD directive escaped the marked comment")
    with tempfile.TemporaryDirectory(prefix="usage-skill-contract-") as temporary:
        fixture_root = Path(temporary)
        source_path = "Code/Tests/UsageSkillFixture.sql"
        source = fixture_root / source_path
        source.parent.mkdir(parents=True)
        table = {"name": "monitor.TestTable", "object_name": "TestTable",
                 "schema_name": "monitor", "object_type": "TABLE",
                 "source_path": source_path}
        proc = {"name": "monitor.TestProcedure", "object_name": "TestProcedure",
                "schema_name": "monitor", "object_type": "INTERNAL_PROCEDURE",
                "source_path": source_path}
        table_md = "Tabelle\n"
        proc_md = "Prozedur\n"
        business = "SELECT N'Line1\r\nLine2' AS [BusinessText];\r\nSELECT 42 AS [BusinessToken];\r\n"
        sql = (business + renderer.comment(table, table_md).replace("\n", "\r\n")
               + renderer.comment(proc, proc_md)
               + "-- USAGE_SKILL_HELP_BEGIN monitor.TestProcedure\r\n"
               + renderer.help_projection(proc, proc_md)
               + "\r\n-- USAGE_SKILL_HELP_END monitor.TestProcedure\r\n")
        source.write_bytes(sql.encode("utf-8"))
        renderer.write_sources(fixture_root, [(table, table_md), (proc, proc_md)])
        first = source.read_bytes()
        renderer.write_sources(fixture_root, [(table, table_md), (proc, proc_md)])
        if source.read_bytes() != first or not first.startswith(business.encode("utf-8")) or first.count(b"SELECT 42 AS [BusinessToken]") != 1:
            raise ValueError("Multiobject source replay changed CRLF SQL outside markers or was not idempotent")
        renderer.write_sources(fixture_root, [(table, "Tabelle neu\n"), (proc, proc_md)])
        if source.read_bytes().count(b"Tabelle neu") != 1 or not source.read_bytes().startswith(business.encode("utf-8")):
            raise ValueError("Multiobject source replay changed CRLF SQL or failed to replace one marked object")
        invalid = fixture_root / "Metadata/UsageSkills/monitor/Test.md"
        invalid.parent.mkdir(parents=True)
        front = ('---\n'
                 'skill_format_version: "1.0.0"\n'
                 'name: "monitor.Test"\n'
                 'description: "Test"\n'
                 'schema_name: "monitor"\n'
                 'object_name: "Test"\n'
                 'object_type: "TABLE"\n'
                 'database_role: "framework"\n'
                 'is_internal: false\n'
                 'source_path: "Code/Tests/UsageSkillFixture.sql"\n'
                 '---\nText\n')
        invalid.write_text(front, encoding="utf-8", newline="\n")
        renderer.read_skill(invalid, fixture_root)
        for encoded_control in (r"\u0000", r"\nGO\n", r"\u0085", r"\u2028"):
            invalid.write_text(front.replace('description: "Test"',
                                             'description: "Test' + encoded_control + '"'),
                               encoding="utf-8", newline="\n")
            try:
                renderer.read_skill(invalid, fixture_root)
            except ValueError:
                pass
            else:
                raise ValueError("Decoded description control character passed validation")
        invalid.write_text(front.replace("is_internal: false", "is_internal: []"),
                           encoding="utf-8", newline="\n")
        try:
            renderer.read_skill(invalid, fixture_root)
        except (TypeError, ValueError):
            pass
        else:
            raise ValueError("Nonboolean is_internal passed validation")
        invalid.write_text(front.replace('object_type: "TABLE"', 'object_type: "INTERNAL_PROCEDURE"'),
                           encoding="utf-8", newline="\n")
        try:
            renderer.read_skill(invalid, fixture_root)
        except ValueError:
            pass
        else:
            raise ValueError("False internal classification passed validation")
        bad_source_path = "Code/Tests/LateMissingMarker.sql"
        bad = fixture_root / bad_source_path
        bad.write_text("SELECT 2 AS [Unmarked];\n", encoding="utf-8", newline="\n")
        bad_table = dict(table, name="monitor.BadTable", object_name="BadTable",
                         source_path=bad_source_path)
        before = source.read_text(encoding="utf-8")
        try:
            renderer.write_sources(fixture_root, [(table, "weiterer Text\n"),
                                                  (bad_table, "fehlender Marker\n")])
        except ValueError:
            pass
        else:
            raise ValueError("Missing later marker was accepted")
        if source.read_text(encoding="utf-8") != before:
            raise ValueError("Late validation failure partly rewrote an earlier source")
        bad.write_text(renderer.comment(bad_table, "Test\n") * 2,
                       encoding="utf-8", newline="\n")
        try:
            renderer.write_sources(fixture_root, [(table, "weiterer Text\n"),
                                                  (bad_table, "Test\n")])
        except ValueError:
            pass
        else:
            raise ValueError("Duplicated later marker was accepted")
        if source.read_text(encoding="utf-8") != before:
            raise ValueError("Duplicate marker partly rewrote an earlier source")
    print("Usage Skill projection self-test passed")

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    root = args.repository_root.resolve()
    if args.self_test:
        self_test(root)
    else:
        validate(root)
        print("Usage Skill Markdown, DDL, Help and role View binding passed")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as exc:
        print(f"USAGE_SKILL_CONTRACT_FAILURE: {exc}", file=sys.stderr)
        raise SystemExit(1)
