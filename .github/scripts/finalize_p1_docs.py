from __future__ import annotations

import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMMIT = "bdb8f66e20f015e7c563e6d3747144400897b281"
RUNS = json.loads(Path(os.environ["RUNS_JSON"]).read_text(encoding="utf-8"))
NAMES = {
    "2019": "SQL Server 2019 Linux release gate",
    "2022": "SQL Server 2022 Linux release gate",
    "2025": "SQL Server 2025 Linux release gate",
    "docs": "Documentation validation",
    "privacy": "Repository privacy validation",
    "commit": "Commit message validation",
}
SELECTED = {}
for key, name in NAMES.items():
    matches = [r for r in RUNS if r.get("name") == name and r.get("head_sha") == COMMIT and r.get("conclusion") == "success"]
    if not matches:
        raise SystemExit(f"Missing successful workflow evidence: {key}")
    SELECTED[key] = max(matches, key=lambda r: int(r["id"]))


def url(key: str) -> str:
    return str(SELECTED[key]["html_url"])


def regex_once(text: str, pattern: str, replacement: str, label: str, flags: int = 0) -> str:
    value, count = re.subn(pattern, replacement, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"Missing documentation anchor: {label}")
    return value


def write(relative: str, text: str) -> None:
    (ROOT / relative).write_text(text, encoding="utf-8", newline="\n")


relative = "Documentation/Quality/Test_Matrix.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = regex_once(text, r"^\*\*Status:\*\*.*$", "**Status:** commitbezogene 23-Suite-Evidenz für alle 17 P0- und alle 40 P1-Fälle vorhanden", "matrix status", re.MULTILINE)
text = regex_once(text, r"^Commit `[^`]+` hat Installer,.*?ausgeführt:$", f"Commit `{COMMIT}` hat Installer, den 23-Suite-Release-Gate-Vertrag einschließlich aller 17 P0- und aller 40 P1-Fälle sowie die Berechtigungsmatrix auf den drei Linux-Targets erfolgreich abgeschlossen. Das SQL-Server-2025-Gate hat zusätzlich die eigenständige Regex-Matrix ausgeführt:", "matrix intro", re.MULTILINE)
versions = {"2019": ("15.0.4480.2", "150"), "2022": ("16.0.4265.3", "160"), "2025": ("17.0.4065.4", "170")}
for key, (version, compatibility) in versions.items():
    suffix = "; `REGEX_MATRIX=PASS`" if key == "2025" else ""
    row = f"| SQL Server {key} | `{version}` | {compatibility} | [Run {SELECTED[key]['id']}]({url(key)}) | `PASS_WITH_LIMITATIONS`; alle 17 P0- und alle 40 P1-Fälle{suffix} |"
    text = regex_once(text, rf"^\| SQL Server {key} \|.*$", row, f"matrix row {key}", re.MULTILINE)
text = regex_once(
    text,
    r"^Der \[Dokumentations- und statische Vertrag\]\([^)]*\), das \[Repository-Datenschutzgate\]\([^)]*\) und das \[Commit-Message-Gate\]\([^)]*\) sind für denselben Commit ebenfalls grün\.",
    f"Der [Dokumentations- und statische Vertrag]({url('docs')}), das [Repository-Datenschutzgate]({url('privacy')}) und das [Commit-Message-Gate]({url('commit')}) sind für denselben Commit ebenfalls grün.",
    "matrix static links",
    re.MULTILINE,
)
text = text.replace("Er startet die zwölf folgenden Verträge", "Er startet die fünfzehn folgenden Verträge")
if "Integration/176_P1_Availability_Runtime_Contract.sql" not in text:
    anchor = "   - `Integration/175_P1_Statistics_Runtime_Contract.sql`\n"
    if text.count(anchor) != 1:
        raise SystemExit("Missing matrix suite insertion anchor.")
    text = text.replace(anchor, anchor + "   - `Integration/176_P1_Availability_Runtime_Contract.sql`\n   - `Integration/177_P1_Agent_Runtime_Contract.sql`\n   - `Integration/178_P1_Diagnostic_Findings_Runtime_Contract.sql`\n", 1)
write(relative, text)

relative = "Documentation/Quality/Next_Steps.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = regex_once(text, r"^Der Stand `1\.1\.0-special\.9`.*$", f"Der Stand `1.1.0-special.9` besitzt vollständige grüne Evidenz für alle 17 P0- und alle 40 P1-Fälle. Die 23. Suite ist für Commit `{COMMIT}` auf SQL Server 2019, 2022 und 2025 nachgewiesen; als nächste Testgruppe folgt die P2-Spezialfeature-Inventur.", "next intro", re.MULTILINE)
if "33. Siebte P1-Gruppe abgeschlossen" not in text:
    marker = "\nUnmittelbar offene Repository-Qualitätsaufgaben:"
    addition = (
        "\n33. Siebte P1-Gruppe abgeschlossen: `176_P1_Availability_Runtime_Contract.sql` prüft HADR-Abwesenheit sowie Suspend-, Queue- und Seedingklassifikation über die produktiv verwendeten reinen Interpretationsfunktionen, ohne Failover oder Konfigurationsänderung."
        "\n34. Achte P1-Gruppe abgeschlossen: `177_P1_Agent_Runtime_Contract.sql` prüft fehlende kritische Alerts sowie Routing-, Job- und Database-Mail-Klassifikation ohne Änderung von `msdb`- oder Agentobjekten."
        "\n35. Neunte P1-Gruppe abgeschlossen: `178_P1_Diagnostic_Findings_Runtime_Contract.sql` prüft die Feld-Whitelist, partielle Child-Evidenz, deaktivierte teure Defaults und das vollständig rückgesetzte Compatibility-Gate.\n"
    )
    if text.count(marker) != 1:
        raise SystemExit("Missing next-steps completion anchor.")
    text = text.replace(marker, addition + marker, 1)
text = regex_once(text, r"^1\. Pro manuellem Ziel.*$", "1. Pro manuellem Ziel `Code/Tests/Run_Release_Gate.sql` im SQLCMD-Modus aus `Code/Tests` ausführen; der Runner umfasst 15 Integrationsverträge und acht Bereichssuiten und bricht beim ersten SQL-Fehler ab.", "next runner", re.MULTILINE)
text = regex_once(text, r"^2\. Die \d+ noch offenen Spezialfälle.*$", "2. Die 115 noch offenen P2-Spezialfälle in der festgelegten Reihenfolge abarbeiten, beginnend mit `USP_SpecialFeatureInventory`. Capability-, Leerzustands-, Positiv-, Grenzwert-, Last- und Berechtigungsfälle bleiben getrennte Nachweise.", "next remaining", re.MULTILINE)
write(relative, text)

relative = "Documentation/Quality/Known_Issues.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = regex_once(text, r"^Die Version `1\.1\.0-special\.9` besitzt.*$", f"Die Version `1.1.0-special.9` besitzt für Commit `{COMMIT}` grüne Actions-Gates auf SQL Server 2019, 2022 und 2025. Die Evidence deckt Installer, 23 Suiten, die versionsspezifischen Berechtigungsmatrizen sowie alle 17 P0- und alle 40 P1-Fälle auf disposable synthetischen Linux-Zielen ab; verbleibende `NOT_EXECUTED`-Zeilen betreffen 115 P2-Fälle und sind kein Testergebnis.", "issues intro", re.MULTILINE)
text = text.replace(" Als nächste Gruppe folgt die tiefe Availability-Evidenz.", "")
if "- Die vier P1-Availability-Fälle" not in text:
    marker = "- Evidenzhinweis:"
    addition = (
        "- Die vier P1-Availability-Fälle sind als einundzwanzigste Suite nachgewiesen. Suspend-, Queue- und Seeding-Positivpfade werden über produktiv verwendete reine Klassifikationsfunktionen geprüft; kein Failover, Suspend, Resume oder physisches Seeding wird ausgeführt.\n"
        "- Die vier P1-Agent-/Alert-Fälle sind als zweiundzwanzigste Suite nachgewiesen. Der echte Leerzustand und gemeinsame Statusklassifikationen werden geprüft; Alerts, Operatoren, Jobs, Mail und `msdb` werden nicht verändert.\n"
        "- Die vier P1-Findings-Fälle sind als dreiundzwanzigste Suite nachgewiesen. Synthetischer Benutzer und Compatibility Level werden garantiert zurückgesetzt; die Feld-Whitelist beweist keinen vollständigen fachlichen Positivzustand aller Child-Module.\n"
    )
    if text.count(marker) != 1:
        raise SystemExit("Missing known-issues insertion anchor.")
    text = text.replace(marker, addition + marker, 1)
write(relative, text)

relative = "Documentation/Quality/Release_Notes.md"
text = (ROOT / relative).read_text(encoding="utf-8")
if "- Die einundzwanzigste Suite automatisiert vier Availability-Fälle" not in text:
    marker = "- Der erste materialisierte Duplicate-Index-Fall"
    addition = (
        f"- Die einundzwanzigste Suite automatisiert vier Availability-Fälle. HADR-Abwesenheit wird real geprüft; Suspend-, Queue- und Seedingzustände verwenden dieselben reinen Klassifikationsfunktionen wie die Procedure. Commit `{COMMIT}` ist auf SQL Server 2019, 2022 und 2025 grün.\n"
        "- Die zweiundzwanzigste Suite automatisiert vier Agent-/Alert-Fälle, ohne Agent- oder `msdb`-Objekte anzulegen oder zu verändern. Keine Adress-, Mail-, Jobschritt- oder Meldungsinhalte werden gelesen.\n"
        "- Die dreiundzwanzigste Suite automatisiert vier normalisierte Findings-Fälle: Feld-Whitelist, partielle Child-Evidenz, opt-in Defaults und Compatibility-Gate. Synthetischer Benutzer und Compatibility Level werden in Erfolgs- und Fehlerpfad bereinigt.\n"
    )
    if text.count(marker) != 1:
        raise SystemExit("Missing release-notes insertion anchor.")
    text = text.replace(marker, addition + marker, 1)
write(relative, text)

relative = "Documentation/Quality/Release_Gate_Runbook.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = text.replace("dieselben dreizehn Release-Gate-Suiten", "dieselben dreiundzwanzig Release-Gate-Suiten")
text = re.sub(r"Installer, \d+-Suite-Release-Gate[^\n]+", "Installer, 23-Suite-Release-Gate einschließlich aller P0- und P1-Verträge und die SQL-Server-2022+-Berechtigungsmatrix", text, count=1)
section = """Der Runner beendet sich beim ersten SQL-Fehler und führt folgende dreiundzwanzig Suiten aus:

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
16. Common
17. Current State
18. Object und Index
19. Plan Cache
20. Query Store
21. Extended Events
22. Infrastructure
23. Server Health

Erwartung bei vollständigem Erfolg:

- Prozess-Exitcode `0`.
- Letztes Resultset: `StatusCode=AVAILABLE`, `IsPartial=0`, `ExecutedSuites=23`.
- Kein `THROW`, kein unbehandelter Fehler und kein vorzeitiges Ende.

"""
text = regex_once(text, r"Der Runner beendet sich beim ersten SQL-Fehler und führt folgende .*?## 4\. Spezialfallmatrix ausführen", section + "## 4. Spezialfallmatrix ausführen", "runbook section", re.DOTALL)
write(relative, text)

relative = "README.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = regex_once(text, r"Der Release-Gate-Vertrag umfasst nun \d+ Suiten;.*?Weitere Feature-Positiv-, Grenzwert-, Last- und externe Restorefälle bleiben separate Nachweise\.", "Der Release-Gate-Vertrag umfasst nun 23 Suiten; alle 17 P0- und alle 40 P1-Fälle besitzen commitbezogene Drei-Versionen-Evidenz. Als nächste Testgruppe folgt die P2-Spezialfeature-Inventur. Weitere Feature-Positiv-, Grenzwert-, Last- und externe Restorefälle bleiben separate Nachweise.", "README status")
write(relative, text)

relative = "Documentation/Architecture/Special_Case_Modules.md"
text = (ROOT / relative).read_text(encoding="utf-8")
text = regex_once(text, r"^Der Codebestand besitzt Help-.*$", f"Der Codebestand besitzt Help-, Installer-, Objekt-, Parameter-, Smoke- und Spezialfall-API-Verträge. Commit `{COMMIT}` weist alle 17 P0- und alle 40 P1-Fälle in 23 Suiten auf SQL Server 2019, 2022 und 2025 nach. Die verbleibenden 115 P2-Zeilen sind Planungsstand und keine Ausführungsevidenz.", "architecture status", re.MULTILINE)
write(relative, text)

for candidate in ROOT.rglob("*.md"):
    value = candidate.read_text(encoding="utf-8")
    if "# Projektkontext für KI-gestützte Fortsetzung" in value:
        value = re.sub(r"Actions führen Installer, \d+-Suite-Gate und synthetische Berechtigungsmatrix", "Actions führen Installer, 23-Suite-Gate und synthetische Berechtigungsmatrix", value)
        candidate.write_text(value, encoding="utf-8", newline="\n")

print("P1 documentation finalized.")
