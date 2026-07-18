#!/usr/bin/env python3
"""Finalize generic P2 evidence after the clean three-version release-gate run."""

from __future__ import annotations

import csv
import io
import json
import os
import re
import subprocess
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE_COMMIT = "40d54fdc195b5cfa0015e2cbe281da595e427ab0"
RUN_IDS = {
    "2019": 29656121684,
    "2022": 29656121674,
    "2025": 29656121672,
}
TARGETS = {
    "SQL2019-LINUX": "2019",
    "SQL2022-LINUX": "2022",
    "SQL2025-LINUX": "2025",
}
P2_MODULES = {
    "USP_SpecialFeatureInventory",
    "USP_InMemoryOltpAnalysis",
    "USP_TemporalAnalysis",
    "USP_ServiceBrokerAnalysis",
    "USP_FullTextAnalysis",
    "USP_DataCaptureDeepAnalysis",
    "USP_EncryptionAnalysis",
    "USP_MaintenanceOperations",
}
P2_SUITES = {
    "P2_FEATURE_INVENTORY_RUNTIME": "ACTIONS_SYNTHETIC_P2_FEATURE_INVENTORY_MIXED_FIXTURES",
    "P2_XTP_RUNTIME": "ACTIONS_SYNTHETIC_P2_XTP_NO_FORCED_HASH_SCAN",
    "P2_TEMPORAL_RUNTIME": "ACTIONS_SYNTHETIC_P2_TEMPORAL_NO_HISTORY_DATA",
    "P2_BROKER_RUNTIME": "ACTIONS_SYNTHETIC_P2_BROKER_NO_PAYLOAD",
    "P2_FULLTEXT_RUNTIME": "ACTIONS_SYNTHETIC_P2_FULLTEXT_NO_LINUX_DDL",
    "P2_DATA_CAPTURE_RUNTIME": "ACTIONS_SYNTHETIC_P2_DATA_CAPTURE_NO_PAYLOAD",
    "P2_ENCRYPTION_RUNTIME": "ACTIONS_SYNTHETIC_P2_ENCRYPTION_NO_SECRETS",
    "P2_MAINTENANCE_RUNTIME": "ACTIONS_SYNTHETIC_P2_MAINTENANCE_READ_ONLY",
}
P2_SUITE_FILES = (
    "179_P2_Special_Feature_Inventory_Runtime_Contract.sql",
    "180_P2_InMemory_Oltp_Runtime_Contract.sql",
    "181_P2_Temporal_Runtime_Contract.sql",
    "182_P2_Service_Broker_Runtime_Contract.sql",
    "183_P2_FullText_Runtime_Contract.sql",
    "184_P2_Data_Capture_Runtime_Contract.sql",
    "185_P2_Encryption_Runtime_Contract.sql",
    "186_P2_Maintenance_Runtime_Contract.sql",
)
RUNS = json.loads(Path(os.environ["RUNS_JSON"]).read_text(encoding="utf-8"))
SELECTED: dict[str, dict] = {}
for key, run_id in RUN_IDS.items():
    matches = [
        run for run in RUNS
        if int(run.get("id", 0)) == run_id
        and run.get("head_sha") == EVIDENCE_COMMIT
        and run.get("conclusion") == "success"
    ]
    if len(matches) != 1:
        raise SystemExit(f"Missing final SQL evidence: {key}")
    SELECTED[key] = matches[0]


def run_url(key: str) -> str:
    return str(SELECTED[key]["html_url"])


def tested_at(key: str) -> str:
    return str(SELECTED[key].get("updated_at") or SELECTED[key].get("created_at"))


def read_csv(relative: str) -> tuple[list[str], list[dict[str, str]]]:
    with (ROOT / relative).open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None:
            raise SystemExit(f"Missing CSV header: {relative}")
        return list(reader.fieldnames), list(reader)


def write_csv(relative: str, fields: list[str], rows: list[dict[str, str]]) -> None:
    buffer = io.StringIO(newline="")
    writer = csv.DictWriter(buffer, fieldnames=fields, lineterminator="\n", extrasaction="raise")
    writer.writeheader()
    writer.writerows(rows)
    (ROOT / relative).write_text(buffer.getvalue(), encoding="utf-8", newline="\n")


def regex_once(text: str, pattern: str, replacement: str, label: str, flags: int = 0) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"Missing documentation anchor: {label}")
    return updated


def write_text(relative: str, text: str) -> None:
    (ROOT / relative).write_text(text, encoding="utf-8", newline="\n")


# ---------------------------------------------------------------------------
# Machine-readable evidence
# ---------------------------------------------------------------------------
fields, rows = read_csv("Metadata/Quality/Special_Case_Test_Cases.csv")
p2_rows = [row for row in rows if row.get("Module") in P2_MODULES]
if len(p2_rows) != 124:
    raise SystemExit(f"Expected 124 P2 rows, found {len(p2_rows)}")
if sum(row.get("ExecutionStatus") == "NOT_EXECUTED" for row in p2_rows) != 115:
    raise SystemExit("Expected exactly 115 previously open P2 rows.")
for row in p2_rows:
    row["ExecutionStatus"] = "PASS_WITH_LIMITATIONS"
    row["EvidenceReference"] = run_url("2019")
write_csv("Metadata/Quality/Special_Case_Test_Cases.csv", fields, rows)

fields, rows = read_csv("Metadata/Quality/Release_Gate_Evidence.csv")
rows = [
    row for row in rows
    if not (row.get("TargetId") in TARGETS and row.get("SuiteId") in P2_SUITES)
]
for row in rows:
    if row.get("TargetId") in TARGETS and row.get("SuiteId") == "RELEASE_GATE_ALL":
        key = TARGETS[row["TargetId"]]
        row.update({
            "CommitSha": EVIDENCE_COMMIT,
            "TestStatus": "PASS",
            "EvidenceStatus": "INDEPENDENTLY_VERIFIED",
            "TestedAtUtc": tested_at(key),
            "LimitationCode": "ACTIONS_SYNTHETIC_ALL_SPECIAL_CASES",
            "EvidenceReference": run_url(key),
        })
for target_id, key in TARGETS.items():
    for suite_id, limitation in P2_SUITES.items():
        rows.append({
            "TargetId": target_id,
            "SuiteId": suite_id,
            "CommitSha": EVIDENCE_COMMIT,
            "TestStatus": "PASS_WITH_LIMITATIONS",
            "EvidenceStatus": "INDEPENDENTLY_VERIFIED",
            "TestedAtUtc": tested_at(key),
            "LimitationCode": limitation,
            "EvidenceReference": run_url(key),
        })
write_csv("Metadata/Quality/Release_Gate_Evidence.csv", fields, rows)

fields, rows = read_csv("Metadata/Quality/Test_Matrix.csv")
limitation = (
    "Synthetic Linux 31-suite and permission contract covering all 17 P0, all 40 P1 and all 124 P2 cases; "
    "feature-positive Windows or Azure MI behavior, forced load states, real failover, external restore, "
    "Full-Text DDL on Linux, payload inspection and operational mutations remain excluded."
)
for row in rows:
    target_id = row.get("TargetId", "")
    if target_id in TARGETS:
        key = TARGETS[target_id]
        row["CommitSha"] = EVIDENCE_COMMIT
        row["TestStatus"] = "PASS_WITH_LIMITATIONS"
        row["EvidenceStatus"] = "INDEPENDENTLY_VERIFIED"
        row["TestedAtUtc"] = tested_at(key)
        row["Limitations"] = limitation + (" SQL Server 2025 regex matrix passed." if key == "2025" else "")
write_csv("Metadata/Quality/Test_Matrix.csv", fields, rows)

fields, rows = read_csv("Metadata/Quality/Special_Case_Gap_Backlog.csv")
updated_gaps: set[str] = set()
for row in rows:
    if row.get("GapId") in {f"SC-{value:03d}" for value in range(15, 23)}:
        row["ImplementationStatus"] = "IMPLEMENTED_ACTIONS_GATE"
        updated_gaps.add(row["GapId"])
if updated_gaps != {f"SC-{value:03d}" for value in range(15, 23)}:
    raise SystemExit("P2 backlog rows are incomplete.")
write_csv("Metadata/Quality/Special_Case_Gap_Backlog.csv", fields, rows)

# ---------------------------------------------------------------------------
# Human-readable documentation
# ---------------------------------------------------------------------------
relative = "Documentation/Quality/Test_Matrix.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = regex_once(
    text,
    r"^\*\*Status:\*\*.*$",
    "**Status:** commitbezogene 31-Suite-Evidenz für alle 17 P0-, 40 P1- und 124 P2-Fälle vorhanden",
    "test-matrix status",
    re.MULTILINE,
)
text = regex_once(
    text,
    r"^Commit `[^`]+` hat Installer,.*?ausgeführt:$",
    f"Commit `{EVIDENCE_COMMIT}` hat Installer, den 31-Suite-Release-Gate-Vertrag einschließlich aller 181 Spezialfälle sowie die Berechtigungsmatrix auf den drei Linux-Targets erfolgreich abgeschlossen. Das SQL-Server-2025-Gate hat zusätzlich die eigenständige Regex-Matrix ausgeführt:",
    "test-matrix evidence intro",
    re.MULTILINE,
)
versions = {"2019": ("15.0.4480.2", "150"), "2022": ("16.0.4265.3", "160"), "2025": ("17.0.4065.4", "170")}
for key, (version, compatibility) in versions.items():
    suffix = "; `REGEX_MATRIX=PASS`" if key == "2025" else ""
    row = (
        f"| SQL Server {key} | `{version}` | {compatibility} | "
        f"[Run {RUN_IDS[key]}]({run_url(key)}) | `PASS_WITH_LIMITATIONS`; "
        f"alle 17 P0-, 40 P1- und 124 P2-Fälle{suffix} |"
    )
    text = regex_once(text, rf"^\| SQL Server {key} \|.*$", row, f"test-matrix row {key}", re.MULTILINE)
text = regex_once(
    text,
    r"^Der \[Dokumentations- und statische Vertrag\].*$",
    "Der Runtime-Nachweis ist commitbezogen; Dokumentations-, Commit-Message- und Datenschutzgates werden als getrennte Evidence-Klassen geführt. Die Linux-Evidence bleibt synthetisch und read-only. Feature-positive Windows-/Azure-MI-Zustände, Lasttests, externe Restorebeweise und operative Mutationen bleiben separate Nachweise.",
    "test-matrix evidence classes",
    re.MULTILINE,
)
text = text.replace("Er startet die fünfzehn folgenden Verträge", "Er startet die dreiundzwanzig folgenden Verträge")
if P2_SUITE_FILES[0] not in text:
    anchor = "   - `Integration/178_P1_Diagnostic_Findings_Runtime_Contract.sql`\n"
    addition = "".join(f"   - `Integration/{name}`\n" for name in P2_SUITE_FILES)
    if text.count(anchor) != 1:
        raise SystemExit("Missing P2 suite insertion anchor in Test_Matrix.md")
    text = text.replace(anchor, anchor + addition, 1)
write_text(relative, text)

relative = "Documentation/Quality/Next_Steps.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = regex_once(
    text,
    r"^Der Stand `1\.1\.0-special\.9`.*$",
    f"Der Stand `1.1.0-special.9` besitzt vollständige grüne Linux-Evidenz für alle 17 P0-, 40 P1- und 124 P2-Fälle. Die 31. Suite ist für Commit `{EVIDENCE_COMMIT}` auf SQL Server 2019, 2022 und 2025 nachgewiesen; die 115 zuvor offenen P2-Zeilen sind abgeschlossen.",
    "next-steps intro",
    re.MULTILINE,
)
if "36. Erste P2-Gruppe abgeschlossen" not in text:
    marker = "\nUnmittelbar offene Repository-Qualitätsaufgaben:"
    addition = (
        "\n36. Erste P2-Gruppe abgeschlossen: Suite `179` prüft 21 Feature-Inventurfälle mit echten portablen Katalogfixtures und version-adaptiven Verträgen.\n"
        "37. Zweite P2-Gruppe abgeschlossen: Suite `180` prüft 14 XTP-Fälle ohne erzwungenen vollständigen Hash-DMV-Scan.\n"
        "38. Dritte P2-Gruppe abgeschlossen: Suite `181` prüft 13 Temporal-Fälle ohne Current-/History-Nutzdaten.\n"
        "39. Vierte P2-Gruppe abgeschlossen: Suite `182` prüft 15 Service-Broker-Fälle ohne Nachrichtenkörper oder Conversation-Mutation.\n"
        "40. Fünfte P2-Gruppe abgeschlossen: Suite `183` prüft 16 Full-Text-Verträge ohne nichtportable Full-Text-DDL auf Linux.\n"
        "41. Sechste P2-Gruppe abgeschlossen: Suite `184` prüft 25 Change-Tracking-, CDC- und Replikationsverträge ohne Change-Zeilen oder Commands.\n"
        "42. Siebte P2-Gruppe abgeschlossen: Suite `185` prüft sieben zuvor offene Encryption-Verträge ohne Schlüssel-, Medien- oder Kontoinhalte.\n"
        "43. Achte P2-Gruppe abgeschlossen: Suite `186` prüft vier zuvor offene Maintenance-Verträge ohne RESUME, ABORT, KILL oder Jobmutation.\n"
    )
    if text.count(marker) != 1:
        raise SystemExit("Missing Next_Steps P2 completion anchor")
    text = text.replace(marker, addition + marker, 1)
text = regex_once(
    text,
    r"^1\. Pro manuellem Ziel.*$",
    "1. Pro weiterem Ziel `Code/Tests/Run_Release_Gate.sql` im SQLCMD-Modus aus `Code/Tests` ausführen; der Runner umfasst 23 Integrationsverträge und acht Bereichssuiten und bricht beim ersten SQL-Fehler ab.",
    "next-steps runner",
    re.MULTILINE,
)
text = regex_once(
    text,
    r"^2\. Die 115 noch offenen P2-Spezialfälle.*$",
    "2. Es bestehen keine offenen P0-, P1- oder P2-Zeilen in der Repository-Testmatrix. Als nächste Evidence-Klassen folgen feature-positive Windows-/Azure-MI-Targets, kontrollierte Lastfälle und externe Restore-/Host-Nachweise.",
    "next-steps remaining",
    re.MULTILINE,
)
write_text(relative, text)

relative = "Documentation/Quality/Known_Issues.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = regex_once(
    text,
    r"^Die Version `1\.1\.0-special\.9` besitzt.*$",
    f"Die Version `1.1.0-special.9` besitzt für Commit `{EVIDENCE_COMMIT}` grüne Actions-Gates auf SQL Server 2019, 2022 und 2025. Die Evidence deckt Installer, 31 Suiten, die versionsspezifischen Berechtigungsmatrizen sowie alle 181 P0-/P1-/P2-Fälle auf disposable synthetischen Linux-Zielen ab; in der Spezialfallmatrix verbleibt keine `NOT_EXECUTED`-Zeile.",
    "known-issues intro",
    re.MULTILINE,
)
if "- Die 21 P2-Feature-Inventurfälle" not in text:
    marker = "- Evidenzhinweis:"
    addition = (
        "- Die 21 P2-Feature-Inventurfälle sind als vierundzwanzigste Vertragsgruppe nachgewiesen; nicht portable Komponenten bleiben capability-adaptive Vertragsnachweise.\n"
        "- Die 14 P2-XTP-Fälle sind nachgewiesen; ein vollständiger Hashketten-DMV-Scan und echter Speicherdruck werden nicht erzwungen.\n"
        "- Die 13 P2-Temporal-Fälle sind nachgewiesen; History-Nutzdaten, Periodenüberlappungen und realer Cleanup-Fortschritt werden nicht gelesen.\n"
        "- Die 15 P2-Broker-Fälle sind nachgewiesen; Nachrichtenkörper, Queue-Payloads und Conversation-Mutationen bleiben ausgeschlossen.\n"
        "- Die 16 P2-Full-Text-Fälle sind nachgewiesen; positive Full-Text-DDL auf Linux bleibt wegen der MCR-Komponentengrenze ein separater Plattformnachweis.\n"
        "- Die 25 P2-Data-Capture-Fälle sind nachgewiesen; Change-Zeilen, Replikationscommands, Credentials und Remote-Topologien bleiben außerhalb der Repository-Evidence.\n"
        "- Die zehn Encryption- und zehn Maintenance-Fälle sind vollständig nachgewiesen; Schlüssel-/Medieninhalte und operative Wartungsänderungen bleiben ausgeschlossen.\n"
    )
    if text.count(marker) != 1:
        raise SystemExit("Missing Known_Issues P2 insertion anchor")
    text = text.replace(marker, addition + marker, 1)
write_text(relative, text)

relative = "Documentation/Quality/Release_Gate_Runbook.md"
text = (ROOT / relative).read_text(encoding="utf-8")
section = """Der Runner beendet sich beim ersten SQL-Fehler und führt folgende einunddreißig Suiten aus:

1. Smoke Test
2. Parameter-API-Vertrag
3. Filter- und Ausgabe-Vertrag
4. Spezialfall-API-Vertrag
5. Spezialfall-Laufzeitvertrag
6. P0-Laufzeitvertrag
7. P1-IQP-Laufzeitvertrag
8. P1-Contention-Laufzeitvertrag
9. P1-Speicher-Laufzeitvertrag
10. P1-Backupketten-Laufzeitvertrag
11. P1-Schema-/Design-Laufzeitvertrag
12. P1-Statistikverteilungs-Laufzeitvertrag
13. P1-Availability-Laufzeitvertrag
14. P1-Agent-/Alert-Laufzeitvertrag
15. P1-Findings-Laufzeitvertrag
16. P2-Spezialfeature-Inventur
17. P2-In-Memory-OLTP-Laufzeitvertrag
18. P2-Temporal-Laufzeitvertrag
19. P2-Service-Broker-Laufzeitvertrag
20. P2-Full-Text-Laufzeitvertrag
21. P2-Data-Capture-Laufzeitvertrag
22. P2-Encryption-Laufzeitvertrag
23. P2-Maintenance-Laufzeitvertrag
24. Common
25. Current State
26. Object und Index
27. Plan Cache
28. Query Store
29. Extended Events
30. Infrastructure
31. Server Health

Erwartung bei vollständigem Erfolg:

- Prozess-Exitcode `0`.
- Letztes Resultset: `StatusCode=AVAILABLE`, `IsPartial=0`, `ExecutedSuites=31`.
- Kein `THROW`, kein unbehandelter Fehler und kein vorzeitiges Ende.

"""
text = regex_once(
    text,
    r"Der Runner beendet sich beim ersten SQL-Fehler und führt folgende .*?## 4\. Spezialfallmatrix ausführen",
    section + "## 4. Spezialfallmatrix ausführen",
    "release-gate runbook suite section",
    re.DOTALL,
)
text = re.sub(r"\b23-Suite-Release-Gate\b", "31-Suite-Release-Gate", text)
text = re.sub(r"\bdreiundzwanzig Release-Gate-Suiten\b", "einunddreißig Release-Gate-Suiten", text)
write_text(relative, text)

relative = "Documentation/Quality/Release_Notes.md"
text = (ROOT / relative).read_text(encoding="utf-8")
section = f"""## Stand 2026-07-18 – vollständige P2-Evidenz und 31-Suite-Gate

- Commit `{EVIDENCE_COMMIT}` hat den vollständigen 31-Suite-Vertrag auf SQL Server 2019, 2022 und 2025 bestanden.
- Die 115 zuvor offenen P2-Zeilen sind als `PASS_WITH_LIMITATIONS` dokumentiert; damit besitzen alle 181 Spezialfallzeilen Evidence.
- Feature Inventory, XTP, Temporal, Service Broker, Full-Text, Data Capture, Encryption und Maintenance besitzen jeweils eine eigene Laufzeitsuite.
- Reale Nutzdaten, Payloads, Secrets, Credentials, SQL-/Jobtexte und Umgebungsbezeichner werden nicht in Repositoryartefakte übernommen.
- Full-Text-DDL auf Linux, feature-positive Windows-/Azure-MI-Zustände, Lasttests, echter Failover und externe Restorebeweise bleiben separate Evidence-Klassen.

"""
if "## Stand 2026-07-18 – vollständige P2-Evidenz und 31-Suite-Gate" not in text:
    text = text.replace("# Release Notes\n\n", "# Release Notes\n\n" + section, 1)
write_text(relative, text)

for relative in ("README.md", "Documentation/README.md"):
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    text, count = re.subn(
        r"Der Release-Gate-Vertrag umfasst nun \d+ Suiten;.*?Weitere Feature-Positiv-, Grenzwert-, Last- und externe Restorefälle bleiben separate Nachweise\.",
        "Der Release-Gate-Vertrag umfasst nun 31 Suiten; alle 17 P0-, 40 P1- und 124 P2-Fälle besitzen commitbezogene Drei-Versionen-Evidenz. Die 115 zuvor offenen P2-Zeilen sind abgeschlossen. Feature-positive Windows-/Azure-MI-Zustände, Lasttests und externe Restorefälle bleiben separate Nachweise.",
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit(f"Missing README release-gate status: {relative}")
    write_text(relative, text)

relative = "Documentation/Architecture/Special_Case_Modules.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = regex_once(
    text,
    r"^Der Codebestand besitzt Help-.*$",
    f"Der Codebestand besitzt Help-, Installer-, Objekt-, Parameter-, Smoke- und Spezialfall-API-Verträge. Commit `{EVIDENCE_COMMIT}` weist alle 181 P0-/P1-/P2-Fälle in 31 Suiten auf SQL Server 2019, 2022 und 2025 nach. Zusätzliche Plattform-, Last- und externe Evidence bleibt getrennt.",
    "special-case architecture status",
    re.MULTILINE,
)
write_text(relative, text)

# ---------------------------------------------------------------------------
# Static evidence validators
# ---------------------------------------------------------------------------
p1_validator = textwrap.dedent('''\
#!/usr/bin/env python3
"""Validate the completed P1 evidence contract without constraining later phases."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

P1_EVIDENCE_COMMIT = "bdb8f66e20f015e7c563e6d3747144400897b281"
FINAL_CASE_IDS = {
    "AG-NONE", "AG-SUSPEND", "AG-QUEUE", "AG-SEED",
    "AGENT-MISSING", "AGENT-ROUTE", "AGENT-JOB", "AGENT-MAIL",
    "FIND-CORE", "FIND-PARTIAL", "FIND-OPTOUT", "FIND-COMPAT",
}
FINAL_SUITE_IDS = {"P1_AVAILABILITY_RUNTIME", "P1_AGENT_RUNTIME", "P1_FINDINGS_RUNTIME"}
TARGET_IDS = {"SQL2019-LINUX", "SQL2022-LINUX", "SQL2025-LINUX"}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    cases = read_csv(root / "Metadata/Quality/Special_Case_Test_Cases.csv")
    rows = {row["CaseId"]: row for row in cases if row.get("CaseId") in FINAL_CASE_IDS}
    if set(rows) != FINAL_CASE_IDS:
        errors.append("Final P1 case rows are incomplete.")
    for case_id, row in rows.items():
        if row.get("ExecutionStatus") != "PASS_WITH_LIMITATIONS":
            errors.append(f"Final P1 case is not evidenced: {case_id}")
        if not row.get("EvidenceReference", "").startswith("https://github.com/gecompat/SQL_Server_Analyze/actions/runs/"):
            errors.append(f"Final P1 case evidence URL is invalid: {case_id}")

    evidence = read_csv(root / "Metadata/Quality/Release_Gate_Evidence.csv")
    for target_id in TARGET_IDS:
        for suite_id in FINAL_SUITE_IDS:
            suite_rows = [row for row in evidence if row.get("TargetId") == target_id and row.get("SuiteId") == suite_id]
            if len(suite_rows) != 1:
                errors.append(f"Final P1 suite row count differs: {target_id}/{suite_id}")
            elif suite_rows[0].get("CommitSha") != P1_EVIDENCE_COMMIT or suite_rows[0].get("TestStatus") != "PASS_WITH_LIMITATIONS":
                errors.append(f"Final P1 suite evidence differs: {target_id}/{suite_id}")

    backlog = read_csv(root / "Metadata/Quality/Special_Case_Gap_Backlog.csv")
    for gap_id in ("SC-012", "SC-013", "SC-014"):
        matches = [row for row in backlog if row.get("GapId") == gap_id]
        if len(matches) != 1 or matches[0].get("ImplementationStatus") != "IMPLEMENTED_ACTIONS_GATE":
            errors.append(f"Final P1 backlog status differs: {gap_id}")

    runner = (root / "Code/Tests/Run_Release_Gate.sql").read_text(encoding="utf-8")
    match = re.search(r"CAST\((\d+) AS int\) AS \[ExecutedSuites\]", runner)
    if match is None or int(match.group(1)) < 23:
        errors.append("Release gate no longer contains the complete P1 scope.")
    for suite_file in (
        "176_P1_Availability_Runtime_Contract.sql",
        "177_P1_Agent_Runtime_Contract.sql",
        "178_P1_Diagnostic_Findings_Runtime_Contract.sql",
    ):
        if suite_file not in runner:
            errors.append(f"Release gate is missing final P1 suite: {suite_file}")

    audit = json.loads((root / "Metadata/Quality/Special_Case_Release_Audit.json").read_text(encoding="utf-8"))
    static_checks = audit.get("staticChecks", {})
    for key in ("p1AvailabilityRuntimeContract", "p1AgentRuntimeContract", "p1FindingsRuntimeContract"):
        if static_checks.get(key, {}).get("validatedCommit") != P1_EVIDENCE_COMMIT:
            errors.append(f"Release audit final P1 contract differs: {key}")

    next_steps = (root / "Documentation/Quality/Next_Steps.md").read_text(encoding="utf-8")
    if "alle 17 P0-" not in next_steps or "40 P1-" not in next_steps:
        errors.append("Next-steps summary does not retain complete P1 evidence.")
    return sorted(set(errors))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=None)
    args = parser.parse_args()
    root = Path(args.repository_root).resolve() if args.repository_root else Path(__file__).resolve().parents[3]
    errors = validate(root)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("Complete P1 evidence validation succeeded.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
''')
write_text("Code/Tests/Static/960_Validate_Complete_P1_Evidence.py", p1_validator)

p2_validator = textwrap.dedent(f'''\
#!/usr/bin/env python3
"""Validate the complete P2 evidence contract without reading runtime output."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

EVIDENCE_COMMIT = "{EVIDENCE_COMMIT}"
P2_MODULES = {repr(P2_MODULES)}
P2_SUITE_IDS = {repr(set(P2_SUITES))}
TARGET_IDS = {repr(set(TARGETS))}
P2_SUITE_FILES = {repr(P2_SUITE_FILES)}
TEMPORARY_PATTERNS = (
    "Code/Tests/P2_Validation_Trigger.sql",
    ".github/workflows/fix-p2-",
    ".github/workflows/diagnose-p2-",
    ".github/workflows/finalize-p2-",
    ".github/scripts/finalize_p2_",
)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    cases = read_csv(root / "Metadata/Quality/Special_Case_Test_Cases.csv")
    p2_rows = [row for row in cases if row.get("Module") in P2_MODULES]
    if len(p2_rows) != 124:
        errors.append(f"P2 case row count differs: {{len(p2_rows)}}")
    for row in p2_rows:
        case_id = row.get("CaseId", "UNKNOWN")
        if row.get("ExecutionStatus") != "PASS_WITH_LIMITATIONS":
            errors.append(f"P2 case is not evidenced: {{case_id}}")
        if not row.get("EvidenceReference", "").startswith("https://github.com/gecompat/SQL_Server_Analyze/actions/runs/"):
            errors.append(f"P2 evidence URL is invalid: {{case_id}}")

    evidence = read_csv(root / "Metadata/Quality/Release_Gate_Evidence.csv")
    for target_id in TARGET_IDS:
        release_rows = [row for row in evidence if row.get("TargetId") == target_id and row.get("SuiteId") == "RELEASE_GATE_ALL"]
        if len(release_rows) != 1:
            errors.append(f"Release-gate row count differs: {{target_id}}")
        elif release_rows[0].get("CommitSha") != EVIDENCE_COMMIT or release_rows[0].get("TestStatus") != "PASS":
            errors.append(f"Release-gate evidence differs: {{target_id}}")
        for suite_id in P2_SUITE_IDS:
            rows = [row for row in evidence if row.get("TargetId") == target_id and row.get("SuiteId") == suite_id]
            if len(rows) != 1:
                errors.append(f"P2 suite row count differs: {{target_id}}/{{suite_id}}")
            elif rows[0].get("CommitSha") != EVIDENCE_COMMIT or rows[0].get("TestStatus") != "PASS_WITH_LIMITATIONS":
                errors.append(f"P2 suite evidence differs: {{target_id}}/{{suite_id}}")

    matrix = read_csv(root / "Metadata/Quality/Test_Matrix.csv")
    for row in matrix:
        if row.get("TargetId") in TARGET_IDS:
            if row.get("CommitSha") != EVIDENCE_COMMIT or row.get("TestStatus") != "PASS_WITH_LIMITATIONS":
                errors.append(f"P2 target matrix differs: {{row.get('TargetId')}}")

    backlog = read_csv(root / "Metadata/Quality/Special_Case_Gap_Backlog.csv")
    for gap_id in [f"SC-{{value:03d}}" for value in range(15, 23)]:
        rows = [row for row in backlog if row.get("GapId") == gap_id]
        if len(rows) != 1 or rows[0].get("ImplementationStatus") != "IMPLEMENTED_ACTIONS_GATE":
            errors.append(f"P2 backlog status differs: {{gap_id}}")

    runner = (root / "Code/Tests/Run_Release_Gate.sql").read_text(encoding="utf-8")
    if "CAST(31 AS int) AS [ExecutedSuites]" not in runner:
        errors.append("Release gate does not report 31 suites.")
    for suite_file in P2_SUITE_FILES:
        if suite_file not in runner:
            errors.append(f"Release gate is missing P2 suite: {{suite_file}}")

    audit = json.loads((root / "Metadata/Quality/Special_Case_Release_Audit.json").read_text(encoding="utf-8"))
    docs = audit.get("testDocumentation", {{}})
    if docs.get("specialCaseRowsNotExecuted") != 0:
        errors.append("Release audit still reports open special cases.")
    if docs.get("specialCaseRowsPassWithLimitations") != 181:
        errors.append("Release audit evidenced case count differs.")
    if docs.get("actionEvidence", {{}}).get("commitSha") != EVIDENCE_COMMIT:
        errors.append("Release audit runtime commit differs.")
    checks = audit.get("staticChecks", {{}})
    for key in (
        "p2FeatureInventoryRuntimeContract", "p2XtpRuntimeContract",
        "p2TemporalRuntimeContract", "p2BrokerRuntimeContract",
        "p2FullTextRuntimeContract", "p2DataCaptureRuntimeContract",
        "p2EncryptionRuntimeContract", "p2MaintenanceRuntimeContract",
    ):
        if checks.get(key, {{}}).get("validatedCommit") != EVIDENCE_COMMIT:
            errors.append(f"Release audit P2 contract differs: {{key}}")

    next_steps = (root / "Documentation/Quality/Next_Steps.md").read_text(encoding="utf-8")
    if "keine offenen P0-, P1- oder P2-Zeilen" not in next_steps:
        errors.append("Next-steps summary still reports repository P2 work.")

    for path in root.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        relative = path.relative_to(root).as_posix()
        if any(relative == pattern or relative.startswith(pattern) for pattern in TEMPORARY_PATTERNS):
            errors.append(f"Temporary P2 artifact remains: {{relative}}")
    return sorted(set(errors))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", default=None)
    args = parser.parse_args()
    root = Path(args.repository_root).resolve() if args.repository_root else Path(__file__).resolve().parents[3]
    errors = validate(root)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print("Complete P2 evidence validation succeeded.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
''')
write_text("Code/Tests/Static/970_Validate_Complete_P2_Evidence.py", p2_validator)

relative = ".github/workflows/documentation-validation.yml"
text = (ROOT / relative).read_text(encoding="utf-8")
if "Code/Tests/Static/970_Validate_Complete_P2_Evidence.py" not in text:
    path_line = "      - 'Code/Tests/Static/960_Validate_Complete_P1_Evidence.py'\n"
    if text.count(path_line) != 2:
        raise SystemExit("Documentation workflow P1 path anchors differ.")
    text = text.replace(path_line, path_line + "      - 'Code/Tests/Static/970_Validate_Complete_P2_Evidence.py'\n")
    step_anchor = """      - name: Validate procedure documentation
"""
    step = """      - name: Validate complete P2 evidence
        shell: bash
        run: |
          set -euo pipefail
          python3 ./Code/Tests/Static/970_Validate_Complete_P2_Evidence.py \\
            --repository-root .

"""
    if text.count(step_anchor) != 1:
        raise SystemExit("Documentation workflow step anchor differs.")
    text = text.replace(step_anchor, step + step_anchor, 1)
write_text(relative, text)

# ---------------------------------------------------------------------------
# Release audit
# ---------------------------------------------------------------------------
audit_path = ROOT / "Metadata/Quality/Special_Case_Release_Audit.json"
audit = json.loads(audit_path.read_text(encoding="utf-8"))
temporary = {
    ".github/workflows/finalize-p2-evidence.yml",
    ".github/scripts/finalize_p2_evidence.py",
}
tracked = subprocess.check_output(["git", "ls-files"], cwd=ROOT, text=True).splitlines()
tracked = [item for item in tracked if item not in temporary]
sql_files = [item for item in tracked if item.lower().endswith(".sql")]
canonical = [item for item in sql_files if item.startswith("Code/") and "/Tests/" not in item and "/Install/" not in item]
objects_fields, objects = read_csv("Metadata/Inventory/Objects.csv")
object_counts = {kind: sum(row.get("ObjectType") == kind for row in objects) for kind in ("PROCEDURE", "FUNCTION", "VIEW")}

audit["generatedAtUtc"] = max(str(run.get("updated_at") or run.get("created_at")) for run in SELECTED.values())
audit["status"] = "ACTIONS_PASS"
audit["scope"] = "green commit-specific 31-suite SQL Server 2019, 2022 and 2025 evidence for all 181 P0 P1 and P2 cases"
audit.setdefault("inventory", {}).update({
    "repositoryFiles": len(tracked),
    "canonicalSqlSources": len(canonical),
    "sqlFilesIncludingTestsAndExamples": len(sql_files),
    "objects": len(objects),
    "procedures": object_counts["PROCEDURE"],
    "functions": object_counts["FUNCTION"],
    "views": object_counts["VIEW"],
})
checks = audit.setdefault("staticChecks", {})
common_runs = {
    "validatedCommit": EVIDENCE_COMMIT,
    "sqlServer2019ActionsRun": run_url("2019"),
    "sqlServer2022ActionsRun": run_url("2022"),
    "sqlServer2025ActionsRun": run_url("2025"),
}
checks["p2FeatureInventoryRuntimeContract"] = {
    "status": "ACTIONS_PASS_WITH_LIMITATIONS", "suite": "Code/Tests/Integration/179_P2_Special_Feature_Inventory_Runtime_Contract.sql",
    "syntheticCases": 21, "portableCatalogFixturesUsed": True, "externalConnectionsCreated": False, **common_runs,
}
checks["p2XtpRuntimeContract"] = {
    "status": "ACTIONS_PASS_WITH_LIMITATIONS", "suite": "Code/Tests/Integration/180_P2_InMemory_Oltp_Runtime_Contract.sql",
    "syntheticCases": 14, "forcedFullHashDmvScan": False, **common_runs,
}
checks["p2TemporalRuntimeContract"] = {
    "status": "ACTIONS_PASS_WITH_LIMITATIONS", "suite": "Code/Tests/Integration/181_P2_Temporal_Runtime_Contract.sql",
    "syntheticCases": 13, "currentOrHistoryDataRead": False, **common_runs,
}
checks["p2BrokerRuntimeContract"] = {
    "status": "ACTIONS_PASS_WITH_LIMITATIONS", "suite": "Code/Tests/Integration/182_P2_Service_Broker_Runtime_Contract.sql",
    "syntheticCases": 15, "queuePayloadRead": False, "conversationMutationExecuted": False, **common_runs,
}
checks["p2FullTextRuntimeContract"] = {
    "status": "ACTIONS_PASS_WITH_LIMITATIONS", "suite": "Code/Tests/Integration/183_P2_FullText_Runtime_Contract.sql",
    "syntheticCases": 16, "linuxFullTextDdlExecuted": False, "indexedContentRead": False, **common_runs,
}
checks["p2DataCaptureRuntimeContract"] = {
    "status": "ACTIONS_PASS_WITH_LIMITATIONS", "suite": "Code/Tests/Integration/184_P2_Data_Capture_Runtime_Contract.sql",
    "syntheticCases": 25, "changeRowsOrReplicationCommandsRead": False, **common_runs,
}
checks["p2EncryptionRuntimeContract"] = {
    "status": "ACTIONS_PASS_WITH_LIMITATIONS", "suite": "Code/Tests/Integration/185_P2_Encryption_Runtime_Contract.sql",
    "newlyAutomatedCases": 7, "totalModuleCases": 10, "secretOrMediaContentRead": False, **common_runs,
}
checks["p2MaintenanceRuntimeContract"] = {
    "status": "ACTIONS_PASS_WITH_LIMITATIONS", "suite": "Code/Tests/Integration/186_P2_Maintenance_Runtime_Contract.sql",
    "newlyAutomatedCases": 4, "totalModuleCases": 10, "maintenanceMutationExecuted": False, **common_runs,
}

docs = audit.setdefault("testDocumentation", {})
docs.update({
    "targetRows": 6,
    "targetRowsNotExecuted": 3,
    "targetRowsPassWithLimitations": 3,
    "releaseGateSuiteRows": 80,
    "releaseGateSuiteRowsNotExecuted": 15,
    "releaseGateSuiteRowsPass": 8,
    "releaseGateSuiteRowsPassWithLimitations": 57,
    "specialCaseRows": 181,
    "specialCaseRowsNotExecuted": 0,
    "specialCaseRowsPassWithLimitations": 181,
    "specialCaseRowsAutomatedPending": 0,
    "runtimeStatus": "ACTIONS_PASS",
    "claim": f"Commit {EVIDENCE_COMMIT} passed the synthetic Linux installer, 31-suite release gate and permission contract on SQL Server 2019, 2022 and 2025 for all 181 special cases. Feature-positive Windows or Azure MI states, load tests, external restore and operational mutations remain separate evidence classes.",
})
for key in ("2019", "2022", "2025"):
    target = docs.setdefault("targetRuntimeEvidence", {}).setdefault(f"sqlServer{key}", {})
    target["actionRun"] = run_url(key)
docs.setdefault("actionEvidence", {}).update({
    "commitSha": EVIDENCE_COMMIT,
    "sqlServer2019Run": run_url("2019"),
    "sqlServer2022Run": run_url("2022"),
    "sqlServer2025Run": run_url("2025"),
    "sqlServer2025RegexRun": run_url("2025"),
    "runtimeEvidenceScope": "COMMIT_SPECIFIC_SQL_RUNTIME",
})
audit_path.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")

# Validate generated evidence before committing.
for validator in (
    "Code/Tests/Static/960_Validate_Complete_P1_Evidence.py",
    "Code/Tests/Static/970_Validate_Complete_P2_Evidence.py",
):
    result = subprocess.run(["python3", validator, "--repository-root", "."], cwd=ROOT, text=True, capture_output=True)
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout)

print("Complete P2 evidence finalized and validated.")
