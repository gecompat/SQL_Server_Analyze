#!/usr/bin/env python3
"""Protect framework resolution and parameterized exact Query Store references."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

SOURCES = {
    "020_USP_QueryStoreRuntimeStats.sql": ("@ReferencedPredicate", "@ReferencedDatabaseNames", "@ReferencedPatternMode"),
    "030_USP_QueryStoreWaitStats.sql": ("@RefPredicate", "@ReferencedNames", "@RefMode"),
    "040_USP_QueryStorePlanChanges.sql": ("@RefPredicate", "@ReferencedNames", "@RefMode"),
    "050_USP_QueryStoreRegressions.sql": ("@RefPredicate", "@ReferencedNames", "@RefMode"),
    "060_USP_QueryStoreForcedPlans.sql": ("@RefPredicate", "@ReferencedNames", "@RefMode"),
}
QUALIFIER = "JOIN ' + QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID())) + N'.[monitor].[TVF_ParseSqlNameList]("
CS = "COLLATE SQL_Latin1_General_CP1_CS_AS"


def validate_source(source: str, spec: tuple[str, str, str]) -> list[str]:
    predicate, parameter, pattern = spec
    errors = []
    start = re.search(r"IF\s+@ReferencedDatabaseNames\s+IS\s+NOT\s+NULL\s+SET\s+" + re.escape(predicate) + r"\s*=", source)
    end = source.find("ELSE IF " + pattern, start.end()) if start else -1
    branch = source[start.start():end] if start and end > start.end() else ""
    if not branch or branch.count(QUALIFIER + parameter + ")") != 1:
        errors.append("exact reference JOIN must use the quoted outer framework database")
    if source.count(QUALIFIER) != 1 or "JOIN [monitor].[TVF_ParseSqlNameList](" in source:
        errors.append("dynamic parser resolution is missing or duplicated")
    if branch.count(CS) != 2 or not re.search(r"\[rf\]\.\[IsValid\]\s*=\s*1", branch):
        errors.append("exact reference validity/CS comparison changed")
    if "//Object[@Database]" not in branch or "PARSENAME(" not in branch or not re.search(r"AND\s+EXISTS\s*\(", branch):
        errors.append("existing Showplan EXISTS/name projection changed")
    validation = re.findall(r"FROM\s+\[monitor\]\.\[TVF_ParseSqlNameList\]\(@ReferencedDatabaseNames\)", source)
    if len(validation) != 1 or not re.search(r"WHERE\s+\[IsValid\]\s*=\s*0", source):
        errors.append("outer framework list validation changed")
    execution = source[source.find("EXEC [sys].[sp_executesql]"):]
    if not re.search(re.escape(parameter) + r"\s+nvarchar\(max\)", execution):
        errors.append("exact reference value must remain a sp_executesql parameter")
    if parameter == "@ReferencedNames":
        if not re.search(r"@ReferencedDatabaseNames\s*,\s*@RefValue\s*,\s*@RefFlags", execution):
            errors.append("caller reference list is no longer bound to the dynamic parameter")
    elif "@ReferencedDatabaseNames = @ReferencedDatabaseNames" not in execution:
        errors.append("runtime caller reference list binding changed")
    # Runtime's formatted assignment has spaces around '='; locate its dynamic USE.
    use = re.search(r"SET\s+@Sql\s*=\s*N'USE", source)
    if not start or not use or end >= use.start():
        errors.append("framework qualification must be evaluated before the source USE batch")
    return errors


def self_test(sources: dict[str, str]) -> int:
    count = 0
    for name, spec in SOURCES.items():
        source = sources[name]
        assert not validate_source(source, spec), name
        _, parameter, _ = spec
        mutations = [
            source.replace(QUALIFIER, "JOIN [monitor].[TVF_ParseSqlNameList](", 1),
            source.replace("QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()))", "N'[ExampleHardcodedFramework]'", 1),
            source.replace("QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()))", "QUOTENAME(@Db)", 1),
            source.replace("QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()))", "(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID())", 1),
            source.replace(QUALIFIER + parameter + ")", QUALIFIER + "@ExampleWrongList)", 1),
        ]
        start = source.index(QUALIFIER)
        at = source.index(CS, start)
        mutations.append(source[:at] + source[at:].replace(CS, "", 1))
        at = source.index(CS, at + len(CS))
        mutations.append(source[:at] + source[at:].replace(CS, "", 1))
        at = source.index("[rf].[IsValid]", start)
        mutations.append(source[:at] + source[at:].replace("[rf].[IsValid]", "[rf].[ItemOrdinal]", 1))
        mutations.append(source.replace("FROM [monitor].[TVF_ParseSqlNameList](@ReferencedDatabaseNames)", "FROM [monitor].[TVF_ParseSqlNameList](@ExampleWrongList)", 1))
        execution_start = source.index("EXEC [sys].[sp_executesql]")
        declaration = re.search(re.escape(parameter) + r"\s+nvarchar\(max\)", source[execution_start:])
        assert declaration
        at = execution_start + declaration.start()
        mutations.append(source[:at] + source[at:].replace(parameter, "@ExampleWrongList", 1))
        for mutated in mutations:
            assert mutated != source and validate_source(mutated, spec), name
            count += 1
    return count


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path("."))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    sources = {name: (args.repository_root / "Code/05_QueryStore" / name).read_text(encoding="utf-8-sig") for name in SOURCES}
    if args.self_test:
        count = self_test(sources)
        print(f"Query Store reference-list self-test PASS: {len(SOURCES)} sources, {count} rejected mutations.")
        return 0
    errors = [f"{name}: {error}" for name, source in sources.items() for error in validate_source(source, SOURCES[name])]
    if errors:
        print("\n".join(errors))
        return 1
    print("Query Store reference-list contract PASS: 5 sources.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
