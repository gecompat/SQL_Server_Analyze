"""Leitet die nativen Feldprüfungen aus der unveränderten Toolbelt-Schemakopie ab."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = ROOT / "Metadata/Quality/SSIS_Exchange_V1.schema.json"
SOURCE = ROOT / "Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql"
BEGIN = "    -- BEGIN GENERATED SSIS EXCHANGE RULES\n"
END = "    -- END GENERATED SSIS EXCHANGE RULES"


def render() -> str:
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    definitions = schema["$defs"]

    def resolve(value):
        return resolve(definitions[value["$ref"].split("/")[-1]]) if "$ref" in value else value

    def types(value):
        value = resolve(value)
        if "oneOf" in value:
            return sorted({t for child in value["oneOf"] for t in types(child)})
        if "type" in value:
            return value["type"] if isinstance(value["type"], list) else [value["type"]]
        if "const" in value:
            return ["null" if value["const"] is None else "string"]
        return sorted({"null" if x is None else "boolean" if isinstance(x, bool) else "string" for x in value["enum"]})

    roles = {"ROOT": schema, "PRODUCER": schema["properties"]["producer"],
             "SOURCE": schema["properties"]["source"], "PROFILES": schema["properties"]["profiles"],
             "COVERAGE": definitions["coverage"], "NODE": definitions["node"],
             "EDGE": definitions["edge"], "DIAGNOSTIC": definitions["diagnostic"]}
    for conditional in definitions["node"]["allOf"]:
        kind = conditional["if"]["properties"]["kind"]["const"]
        fields = conditional["then"]["properties"]["attributes"]["required"]
        roles["ATTR_" + kind] = {"required": fields, "properties": {k: definitions["attributes"]["properties"][k] for k in fields}}
    type_ids = {"null": 0, "string": 1, "integer": 2, "number": 2, "boolean": 3, "array": 4, "object": 5}
    patterns = {definitions[k]["pattern"]: label for k, label in (("id", "ID"), ("sha256", "HEX64"), ("version", "VERSION"))}
    patterns[schema["properties"]["producer"]["properties"]["sourceCommit"]["pattern"]] = "HEX40"
    patterns[definitions["edge"]["properties"]["id"]["pattern"]] = "EDGEID"
    patterns[definitions["edge"]["properties"]["ruleId"]["pattern"]] = "RULEID"
    child_roles = {("ROOT", "producer"): "PRODUCER", ("ROOT", "source"): "SOURCE", ("ROOT", "profiles"): "PROFILES",
                   ("ROOT", "coverage"): "COVERAGE_ARRAY", ("ROOT", "nodes"): "NODES_ARRAY", ("ROOT", "edges"): "EDGES_ARRAY", ("ROOT", "diagnostics"): "DIAGNOSTICS_ARRAY"}
    rules = []
    for role, shape in roles.items():
        for name, raw in shape["properties"].items():
            field = resolve(raw)
            if "oneOf" in field:
                field = next(resolve(x) for x in field["oneOf"] if resolve(x).get("type") != "null")
            pattern = field.get("pattern")
            if pattern is not None and pattern not in patterns:
                raise ValueError("Unbekanntes zu übersetzendes Muster")
            rules.append({"role": role, "name": name, "types": "".join(str(x) for x in sorted({type_ids[t] for t in types(raw)})),
                          "required": name in shape.get("required", []), "enum": field.get("enum", [field["const"]] if "const" in field else None),
                          "maxLength": field.get("maxLength"), "min": field.get("minimum"), "max": field.get("maximum"),
                          "minItems": field.get("minItems"), "maxItems": field.get("maxItems"),
                          "pattern": patterns.get(pattern), "childRole": child_roles.get((role, name))})
    # SQL ist nur die deterministisch generierte Darstellung; das Schema bleibt die einzige Feldquelle.
    payload = json.dumps(rules, ensure_ascii=True, separators=(",", ":")).replace("'", "''")
    return BEGIN + "    DECLARE @FieldRulesJson nvarchar(max) = N'" + payload + "';\n" + END


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = SOURCE.read_text(encoding="utf-8")
    start, end = content.index(BEGIN), content.index(END) + len(END)
    expected = content[:start] + render() + content[end:]
    fixture_begin = "-- BEGIN GENERATED SSIS MODEL FIXTURE\n"
    fixture_end = "-- END GENERATED SSIS MODEL FIXTURE"
    example = json.loads((ROOT / "Metadata/Quality/SSIS_Exchange_V1.example.json").read_text(encoding="utf-8"))
    fixture_payload = json.dumps(example, ensure_ascii=True, separators=(",", ":")).replace("'", "''")
    fixtures = []
    for name in ("212_SsisPackageModelAnalysis_Runtime_Contract.sql", "213_SsisPackageViews_Runtime_Contract.sql", "214_SsisObjectRules_Runtime_Contract.sql", "215_SsisLocalHandover_Runtime_Contract.sql", "216_SsisExecutionCorrelation_Runtime_Contract.sql"):
        fixture_path = ROOT / "Code/Tests/Integration" / name
        fixture = fixture_path.read_text(encoding="utf-8")
        first, last = fixture.index(fixture_begin), fixture.index(fixture_end) + len(fixture_end)
        expected_fixture = fixture[:first] + fixture_begin + "DECLARE @Model nvarchar(max)=N'" + fixture_payload + "';\n" + fixture_end + fixture[last:]
        fixtures.append((fixture_path, fixture, expected_fixture))
    if args.check:
        if content != expected or any(original != generated for _, original, generated in fixtures):
            raise SystemExit("SSIS_EXCHANGE_RULES_DRIFT")
        print("SSIS_EXCHANGE_RULES_PASS")
    else:
        SOURCE.write_text(expected, encoding="utf-8")
        for path, _, generated in fixtures:
            path.write_text(generated, encoding="utf-8")
