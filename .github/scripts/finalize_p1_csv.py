from __future__ import annotations

import csv
import io
import json
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMIT = "bdb8f66e20f015e7c563e6d3747144400897b281"
RUNS = json.loads(Path(os.environ["RUNS_JSON"]).read_text(encoding="utf-8"))
NAMES = {
    "2019": "SQL Server 2019 Linux release gate",
    "2022": "SQL Server 2022 Linux release gate",
    "2025": "SQL Server 2025 Linux release gate",
}
EXPECTED = {"2019": 29647983342, "2022": 29647983333, "2025": 29647983330}
SELECTED = {}
for key, name in NAMES.items():
    matches = [r for r in RUNS if r.get("name") == name and r.get("head_sha") == COMMIT and r.get("conclusion") == "success"]
    if not matches:
        raise SystemExit(f"Missing successful SQL evidence: {key}")
    SELECTED[key] = max(matches, key=lambda r: int(r["id"]))
    if int(SELECTED[key]["id"]) != EXPECTED[key]:
        raise SystemExit(f"Unexpected SQL run: {key}")


def url(key: str) -> str:
    return str(SELECTED[key]["html_url"])


def tested_at(key: str) -> str:
    return str(SELECTED[key]["created_at"])


def read_csv(relative: str):
    with (ROOT / relative).open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise SystemExit(f"Missing header: {relative}")
        return list(reader.fieldnames), list(reader)


def write_csv(relative: str, fields, rows) -> None:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fields, lineterminator="\n", extrasaction="raise")
    writer.writeheader()
    writer.writerows(rows)
    (ROOT / relative).write_text(output.getvalue(), encoding="utf-8", newline="\n")


case_ids = {
    "AG-NONE", "AG-SUSPEND", "AG-QUEUE", "AG-SEED",
    "AGENT-MISSING", "AGENT-ROUTE", "AGENT-JOB", "AGENT-MAIL",
    "FIND-CORE", "FIND-PARTIAL", "FIND-OPTOUT", "FIND-COMPAT",
}
fields, rows = read_csv("Metadata/Quality/Special_Case_Test_Cases.csv")
seen = set()
for row in rows:
    if row["CaseId"] in case_ids:
        row["TestStatus"] = "PASS_WITH_LIMITATIONS"
        row["EvidenceReference"] = url("2019")
        seen.add(row["CaseId"])
if seen != case_ids:
    raise SystemExit("Final P1 case rows missing.")
write_csv("Metadata/Quality/Special_Case_Test_Cases.csv", fields, rows)

targets = {"SQL2019-LINUX": "2019", "SQL2022-LINUX": "2022", "SQL2025-LINUX": "2025"}
final_suites = {
    "P1_AVAILABILITY_RUNTIME": "ACTIONS_SYNTHETIC_P1_AVAILABILITY_NO_CLUSTER_MUTATION",
    "P1_AGENT_RUNTIME": "ACTIONS_SYNTHETIC_P1_AGENT_NO_MSDB_MUTATION",
    "P1_FINDINGS_RUNTIME": "ACTIONS_SYNTHETIC_P1_FINDINGS_RESTORED_CONTEXT",
}
fields, rows = read_csv("Metadata/Quality/Release_Gate_Evidence.csv")
rows = [row for row in rows if not (row["TargetId"] in targets and row["SuiteId"] in final_suites)]
for row in rows:
    if row["TargetId"] in targets and row["SuiteId"] == "RELEASE_GATE_ALL":
        key = targets[row["TargetId"]]
        row.update({
            "CommitSha": COMMIT,
            "TestStatus": "PASS",
            "EvidenceStatus": "INDEPENDENTLY_VERIFIED",
            "TestedAtUtc": tested_at(key),
            "LimitationCode": "ACTIONS_SYNTHETIC_TARGET",
            "EvidenceReference": url(key),
        })
for target, key in targets.items():
    for suite, limitation in final_suites.items():
        rows.append({
            "TargetId": target,
            "SuiteId": suite,
            "CommitSha": COMMIT,
            "TestStatus": "PASS_WITH_LIMITATIONS",
            "EvidenceStatus": "INDEPENDENTLY_VERIFIED",
            "TestedAtUtc": tested_at(key),
            "LimitationCode": limitation,
            "EvidenceReference": url(key),
        })
write_csv("Metadata/Quality/Release_Gate_Evidence.csv", fields, rows)

fields, rows = read_csv("Metadata/Quality/Test_Matrix.csv")
limitations = (
    "Synthetic Linux 23-suite and permission contract including all 17 P0 and all 40 P1 cases; "
    "no failover suspend resume physical seeding or Agent and msdb mutation; restricted-user and "
    "compatibility contexts restored; exact public product metadata retained; 115 P2 feature-positive "
    "boundary load Windows Azure MI and external restore cases remain separate."
)
for row in rows:
    if row["TargetId"] in targets:
        key = targets[row["TargetId"]]
        row["CommitSha"] = COMMIT
        row["TestStatus"] = "PASS_WITH_LIMITATIONS"
        row["EvidenceStatus"] = "INDEPENDENTLY_VERIFIED"
        row["TestedAtUtc"] = tested_at(key)
        row["Limitations"] = limitations + (" SQL Server 2025 regex matrix passed." if key == "2025" else "")
write_csv("Metadata/Quality/Test_Matrix.csv", fields, rows)

fields, rows = read_csv("Metadata/Quality/Special_Case_Gap_Backlog.csv")
updated = set()
for row in rows:
    if row["GapId"] in {"SC-012", "SC-013", "SC-014"}:
        row["ImplementationStatus"] = "IMPLEMENTED_ACTIONS_GATE"
        updated.add(row["GapId"])
if updated != {"SC-012", "SC-013", "SC-014"}:
    raise SystemExit("Final P1 backlog rows missing.")
write_csv("Metadata/Quality/Special_Case_Gap_Backlog.csv", fields, rows)

print("P1 CSV evidence finalized.")
