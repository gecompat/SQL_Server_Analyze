# Repository instructions for AI systems

<!-- AI_REPOSITORY_FOUNDATION:BEGIN v1 -->
## AI Repository Foundation baseline

Apply the native scoped `AGENTS.override.md`/`AGENTS.md` chain on every new session. Read `.ai/foundation/FOUNDATION_RULESET.md`, affected project sources, and only relevant additional policies. Project facts, domain contracts, selected overrides, and current state remain project-owned. Discovery links are not a demand to load every document.

Use `.ai/foundation/PROCESSING_EFFICIENCY_POLICY.md` for routine work, verified session-local rule reuse, proportionate review/delegation, shared wave budgets, and bounded waiting. Reuse requires current authority/content/scope/dependency checks and actually available analysis; no optional planner or persistent record is necessary. Persistent cache users additionally follow `.ai/foundation/RULE_CONTEXT_CACHE_POLICY.md`. Unknown discovery or lost analysis never becomes a fabricated hit.

A concrete task authorizes ordinary proportionate work inside its envelope; gate only real unresolved or exceeded boundaries. Preserve REQUIRED safety/privacy/integrity/evidence floors and compatible stronger project rules. Use `.ai/foundation/SEMANTIC_INTEGRATION_POLICY.md` for integration conflicts and efficiency recommendations. Keep active project governance transitively discoverable from this root outside the managed block; preserve/rehome unique adapter rules before thinning adapters.

Foundation validation establishes FOUNDATION_INTEGRITY only. Run affected project semantic/runtime checks and required independent reviews. Use optional routing/execution contracts only for relevant selected operations. Optional capabilities grant no execution authority. Requested models, chat history, fingerprints, and cached analysis are not evidence or durable project truth.
<!-- AI_REPOSITORY_FOUNDATION:END -->

## Projektspezifische Governance und Discovery

Für die Wiederverwendung bereits analysierter Regeln gilt zusätzlich
[`AI_Metadata/Rule_Context_Cache.md`](AI_Metadata/Rule_Context_Cache.md).
Standard ist die geprüfte sessionlokale Analyseverfügbarkeit gemäß
[`PROCESSING_EFFICIENCY_POLICY.md`](.ai/foundation/PROCESSING_EFFICIENCY_POLICY.md).
Vor einer weiteren Welle werden aktuelle Autorität, Discovery, ausgewählte
Quellen und transitive Abhängigkeiten lokal geprüft. Der optionale persistente
Cache ist nur bei seiner tatsächlichen Nutzung erforderlich.

Die Foundation ergänzt die projektspezifischen Regeln, ersetzt sie aber nicht.
Die folgenden Quellen bilden den Discoveryweg. Gelesen werden ausschließlich
die für die Aufgabe geltenden Regeln und ihre semantischen Abhängigkeiten;
ein Link aktiviert weder sämtliche Planungen noch alle technischen Verträge.

- [`AI_Metadata/PROJECT_CONTEXT.md`](AI_Metadata/PROJECT_CONTEXT.md) für feste Produkt- und Datenschutzverträge sowie den projektspezifischen GitHub-Veröffentlichungsweg;
- [`AI_Metadata/CONTINUATION_GUIDE.md`](AI_Metadata/CONTINUATION_GUIDE.md) für die verbindliche Fortsetzungs-, Änderungs- und Validierungsreihenfolge;
- [`AI_Metadata/ARCHITECTURE_DECISIONS.md`](AI_Metadata/ARCHITECTURE_DECISIONS.md) für dauerhafte Architekturentscheidungen;
- [`AI_Metadata/ARTIFACT_IDENTITY_AND_NOMENCLATURE.md`](AI_Metadata/ARTIFACT_IDENTITY_AND_NOMENCLATURE.md) für dauerhafte Artefaktkennungen, Arbeitselemente, Wellen und deren Vergabe;
- [`AI_Metadata/Internal_Documentation/Quality/Next_Steps.md`](AI_Metadata/Internal_Documentation/Quality/Next_Steps.md) für den aktuellen autonomen Entwicklungsauftrag, dessen Grenzen und die ausführbare Entwicklungswelle;
- [`AI_Metadata/Internal_Documentation/Architecture/Foundation_1_20_Upgrade.md`](AI_Metadata/Internal_Documentation/Architecture/Foundation_1_20_Upgrade.md) für die aktuelle Foundation-Upgradebewertung, Installationsprovenienz und die unter `DEC-0001` festgehaltenen Integrationsentscheidungen;
- die nachfolgend direkt referenzierten Qualitätsrichtlinien für Dokumentationsstil und CI-Testauswahl.

Der öffentliche Fehlerberichts-, Beitrags- und Reviewweg steht in
[`CONTRIBUTING.md`](CONTRIBUTING.md). Er ergänzt diese Regeln für externe Beiträge.

Historische, als Entwurf gekennzeichnete oder ausdrücklich abgelöste Inhalte sind keine aktive Governance.

## Verbindlicher Dokumentationsstil

Vor dem Erstellen oder Überarbeiten von Dokumentationsfreitexten ist die Richtlinie [Verbindlicher Schreibstil für Dokumentation](Documentation/Quality/Documentation_Writing_Style.md) vollständig zu lesen und einzuhalten.

Die Richtlinie gilt für alle berührten README-Dateien, Architektur- und Analyseunterlagen, Betriebs- und Referenzdokumente, Release- und Qualitätsdokumente sowie für dokumentierende Freitexte in SQL-Dateien. Technische Bezeichner, Code, festgelegte Statuswerte und öffentliche Verträge bleiben unverändert, sofern die Aufgabe keine fachliche Änderung verlangt.

Eine technische Änderung berechtigt nicht zu einer unverbundenen redaktionellen Gesamtüberarbeitung. Stilkorrekturen bleiben auf den sachlich betroffenen Dokumentationsumfang begrenzt.

Ordnerspezifische Ausschlussanweisungen für persönliche Notizen oder nicht maßgebliche Inhalte bleiben unabhängig von dieser Schreibstilrichtlinie verbindlich.

## Geschützter Lizenzblock der Root-README

Der zweisprachige Lizenzblock am Anfang der Root-Datei [`README.md`](README.md) ist vor jeder Bearbeitung dieser Datei vollständig zu lesen. Maßgeblich ist stets der zu Beginn der Aufgabe im Zielbranch vorhandene Stand; dadurch werden zwischenzeitliche Anpassungen des Repositoryinhabers nicht zurückgesetzt.

Ein automatisiertes Bearbeitungssystem muss den gesamten Block einschließlich des englischen Abschnitts `READ BEFORE USE`, des deutschen Abschnitts `Lizenzhinweis`, der Überschriften, Listen, Links, Trennlinien, Hervorhebungen, Zeichensetzung, Leerzeilen und sonstigen Formatierung unverändert erhalten. Allgemeine Aufträge zum Aktualisieren, Korrigieren, Formatieren oder stilistischen Überarbeiten der Root-README oder der Repositorydokumentation erteilen keine Berechtigung, diesen Block zu verändern.

Eine Änderung ist nur zulässig, wenn der Benutzer ausdrücklich und unmittelbar eine Änderung des Lizenzblocks verlangt. Bei jeder anderen Änderung der Root-README ist vor dem Commit zu prüfen, dass der Lizenzblock gegenüber dem zu Beginn der Aufgabe gelesenen Stand inhaltlich und formal unverändert geblieben ist.

## Verbindliche CI-Teststrategie

Für Testauswahl, CI-Umfang, Compatibility-Level-Läufe und native Versionsprüfungen gilt ausschließlich [Verbindliche CI-Teststrategie](Documentation/Quality/CI_Test_Strategy.md). Historische Nachweismatrizen und ältere Änderungsbeschreibungen sind keine Handlungsanweisungen.

Das verbindliche Standardmodell ist 1+0+N: impact-basierte funktionale Tests auf SQL Server 2025, keine zusätzliche native Engine ohne konkretes Versionsrisiko und gezielte zusätzliche Compatibility Levels, native Versionen oder Plattformen nur gemäß der kanonischen Strategie.

## Wirtschaftliche Verarbeitung und Koordination

Für aufgabenbezogene Lektüre, sessionlokale Analyseverfügbarkeit, gemeinsame
Wellenbudgets und Warteverhalten gilt
[PROCESSING_EFFICIENCY_POLICY.md](.ai/foundation/PROCESSING_EFFICIENCY_POLICY.md).
Für eine konkrete Modell- oder Runtimeauswahl wird zusätzlich die einschlägige
[Model-Routing-Policy](.ai/foundation/MODEL_ROUTING_POLICY.md) herangezogen.
Verfügbare Fähigkeiten, Kosten und Kontingente werden nicht erfunden. Ohne
belegte Kostenmessung wird ein endlicher Aufgaben- und Agentenumfang gewählt.

Ein Implementierer verantwortet einen kohärenten Änderungsschritt. Ein
unabhängiger Reviewer prüft ihn bei fachlichem Risiko oder vorgeschriebener
Unabhängigkeit. Weitere Reviewer benötigen eine konkrete offene Frage und
Abnahmekriterien. Mechanische Hash-, Manifest-, Mengen- und Bindungsnachweise
werden lokal geprüft. Ein abgeschlossener Review verlangt keinen Review des
Reviews. Unveränderte erfolgreiche Tests werden ausschließlich bei neuen
Eingaben, Befunden, Risiken oder ausdrücklichen Prüfvorgaben wiederholt.

Timer und Heartbeats lösen keine erneute semantische Arbeit an unveränderten
Blockern aus. Fortsetzung erfolgt bei relevantem Zustandswechsel oder einer
autorisierten begrenzten Nachprüfung. Erforderliche Sicherheits-, Datenschutz-,
Lizenz- und Validierungsgates bleiben verbindlich.
