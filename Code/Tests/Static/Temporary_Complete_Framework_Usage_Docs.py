#!/usr/bin/env python3
"""Complete documentation indexes and review metadata for FRAMEWORK-USAGE-001."""

from __future__ import annotations

import csv
import io
from pathlib import Path


reference = Path("Documentation/Reference/Procedure_Reference.md")
reference.write_text(reference.read_text(encoding="utf-8").rstrip() + "\n", encoding="utf-8")

index = Path("Documentation/Analysis_Guides/Procedures/README.md")
text = index.read_text(encoding="utf-8")
text = text.replace("**Strukturelle Abdeckung:** 97 Procedures<br>", "**Strukturelle Abdeckung:** 98 Procedures<br>", 1)
text = text.replace("**Tief geprüfte Seiten:** 91 Procedures", "**Tief geprüfte Seiten:** 92 Procedures", 1)
text = text.replace("91 Procedures besitzen eine am aktuellen T-SQL geprüfte", "92 Procedures besitzen eine am aktuellen T-SQL geprüfte", 1)
anchor = "- [USP_QueryStoreAnalysis](USP_QueryStoreAnalysis.md)\n"
addition = anchor + "- [USP_FrameworkUsageFromQueryStore](USP_FrameworkUsageFromQueryStore.md)\n"
if "USP_FrameworkUsageFromQueryStore](USP_FrameworkUsageFromQueryStore.md)" not in text:
    if anchor not in text:
        raise SystemExit("Procedure index Query Store anchor not found")
    text = text.replace(anchor, addition, 1)
index.write_text(text, encoding="utf-8")

documentation = Path("Documentation/README.md")
text = documentation.read_text(encoding="utf-8")
text = text.replace("alle 97 öffentlichen Procedures", "alle 98 öffentlichen Procedures", 1)
text = text.replace(
    "Der Inventarvertrag umfasst 165 Objekte: 97 öffentliche Procedures",
    "Der Inventarvertrag umfasst 166 Objekte: 98 öffentliche Procedures",
    1,
)
documentation.write_text(text, encoding="utf-8")

object_index = Path("Documentation/Analysis_Guides/Object_Index.md")
text = object_index.read_text(encoding="utf-8")
text = text.replace("alle 97 inventarisierten `USP_*`-Procedures", "alle 98 inventarisierten `USP_*`-Procedures", 1)
anchor = "| `[monitor].[USP_QueryStoreAnalysis]` | [Orchestrierte Query-Store-Analyse](Procedures/USP_QueryStoreAnalysis.md) |\n"
addition = anchor + "| `[monitor].[USP_FrameworkUsageFromQueryStore]` | [Framework-Nutzung und aggregierte Eigenlast aus Query Store](Procedures/USP_FrameworkUsageFromQueryStore.md) |\n"
if "Procedures/USP_FrameworkUsageFromQueryStore.md" not in text:
    if anchor not in text:
        raise SystemExit("Object index Query Store anchor not found")
    text = text.replace(anchor, addition, 1)
object_index.write_text(text, encoding="utf-8")

review_path = Path("Metadata/Quality/Analysis_Documentation_Review.csv")
rows = list(csv.reader(io.StringIO(review_path.read_text(encoding="utf-8"))))
rows = [row for row in rows if not row or row[0] != "USP_FrameworkUsageFromQueryStore"]
rows.append(["USP_FrameworkUsageFromQueryStore", "DEEP_REVIEWED", "2026-07-26", "3"])
output = io.StringIO(newline="")
csv.writer(output, lineterminator="\n").writerows(rows)
review_path.write_text(output.getvalue(), encoding="utf-8")
