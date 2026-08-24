# Repository instructions for AI systems

<!-- AI_REPOSITORY_FOUNDATION:BEGIN v1 -->
## AI Repository Foundation baseline

Before project work, read `.ai/foundation/FOUNDATION_RULESET.md` and then only the Foundation rule files relevant to the current scope. Project-specific instructions in this repository remain the source of truth for project facts, domain rules, architecture, state, and selected overrides.

Active project-specific governance must be transitively discoverable from this root `AGENTS.md`. If this repository keeps authoritative project rules elsewhere, preserve or add a concise project-owned discovery section outside this managed Foundation block that points to their canonical entrypoints or documents the scoped-`AGENTS.md` convention. Do not copy project rule text into this Foundation block. Active authority that cannot be discovered is an integration defect.

The current explicit task authorizes ordinary, reasonably expected and proportionate operations inside the project's authorization envelope. Do not create repeated confirmation gates for normal work. Escalate only for unresolved handling/authorization boundaries, unexpected material scope/effects, or destructive/irreversible effects lacking exact authority.

Foundation `REQUIRED` rules are a minimum protected floor; a project may intentionally be stricter. Foundation `DEFAULT` rules may be intentionally overridden by project-specific rules. Use `.ai/foundation/SEMANTIC_INTEGRATION_POLICY.md` to classify overlaps instead of replacing richer project governance.

Tool-specific adapters must lead back to this repository entry point and may not define parallel governance. When an existing adapter contains unique project rules, preserve/rehome those rules before thinning the adapter.

Foundation validation covers Foundation integration integrity only. Preserve and use the target repository's existing semantic validators, static contracts, tests, reviews, and manual validation when their contracts are affected. A green Foundation validator is not evidence that the entire project is validated.

Chat history, memory, prior scratchpads, and vendor-specific project prompts are not durable project truth.
<!-- AI_REPOSITORY_FOUNDATION:END -->

## Projektspezifische Governance und Discovery

Die Foundation ergänzt die projektspezifischen Regeln, ersetzt sie aber nicht. Für den jeweiligen Arbeitsumfang sind die folgenden kanonischen Projektquellen heranzuziehen:

- [`AI_Metadata/PROJECT_CONTEXT.md`](AI_Metadata/PROJECT_CONTEXT.md) für feste Produkt- und Datenschutzverträge sowie den projektspezifischen GitHub-Veröffentlichungsweg;
- [`AI_Metadata/CONTINUATION_GUIDE.md`](AI_Metadata/CONTINUATION_GUIDE.md) für die verbindliche Fortsetzungs-, Änderungs- und Validierungsreihenfolge;
- [`AI_Metadata/ARCHITECTURE_DECISIONS.md`](AI_Metadata/ARCHITECTURE_DECISIONS.md) für dauerhafte Architekturentscheidungen;
- [`AI_Metadata/ARTIFACT_IDENTITY_AND_NOMENCLATURE.md`](AI_Metadata/ARTIFACT_IDENTITY_AND_NOMENCLATURE.md) für dauerhafte Artefaktkennungen, Arbeitselemente, Wellen und deren Vergabe;
- die nachfolgend direkt referenzierten Qualitätsrichtlinien für Dokumentationsstil und CI-Testauswahl.

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

## Anbieterneutrale Richtlinie zur kosten- und qualitätsoptimierten Verarbeitung

Diese Richtlinie gilt unabhängig vom verwendeten KI-Anbieter, Modell, Agenten-Framework oder Ausführungsort. Sie ist insbesondere anwendbar auf:

- ChatGPT, Codex und OpenAI-Modelle
- Claude und andere Anthropic-Systeme
- Gemini und andere Google-Systeme
- GitHub Copilot und vergleichbare Coding-Agenten
- lokal ausgeführte Open-Source-Modelle
- selbst gehostete oder unternehmensinterne KI-Systeme
- Systeme, die keinen automatischen Modellwechsel unterstützen

Anbieterspezifische Begriffe wie „Reasoning Effort“, „Thinking Budget“, „Model Tier“, „Agent Mode“ oder „Pro Mode“ sind als funktional vergleichbare Steuerungsmöglichkeiten zu verstehen. Nutze nur Funktionen, die im tatsächlich eingesetzten System verfügbar sind.

### Ziel

Bearbeite jede Aufgabe mit möglichst geringen Gesamtkosten, ohne die erforderliche Qualität, Sicherheit, Zuverlässigkeit oder Nachprüfbarkeit zu unterschreiten.

Gesamtkosten umfassen insbesondere:

- Modell-, Token- und API-Kosten
- lokale Rechenzeit, GPU-, CPU-, Energie- und Infrastrukturkosten
- Reasoning- oder Thinking-Aufwand
- Werkzeug-, Such- und externe API-Aufrufe
- Kontextgröße und wiederholte Kontextübertragungen
- fehlgeschlagene Versuche und Nacharbeiten
- Test-, Build- und Validierungsaufwand
- menschlichen Prüf- und Korrekturaufwand
- Laufzeit und unnötige Parallelverarbeitung

Die optimale Verarbeitung ist nicht zwingend die billigste einzelne Anfrage. Entscheidend sind die Gesamtkosten bis zu einem verlässlich geprüften Ergebnis.

### Verfügbare Möglichkeiten feststellen

Ermittle vor umfangreichen Arbeiten, soweit dies ohne nennenswerten Aufwand möglich ist:

- welches KI-System und welche Modelle tatsächlich verfügbar sind,
- ob ein Modellwechsel technisch unterstützt wird,
- welche Kontext-, Werkzeug- und Reasoning-Funktionen vorhanden sind,
- ob separate Kontingente oder Flatrates bestehen,
- ob lokale Modelle oder lokale Werkzeuge verfügbar sind,
- welche Test-, Build- und Entwicklungsumgebung das Projekt bereits bereitstellt.

Erfinde keine Preise, Fähigkeiten, Kontingente oder Modellwechsel. Wenn keine zuverlässigen Kosteninformationen verfügbar sind, arbeite mit relativen Kategorien:

- günstig und schnell,
- ausgewogen,
- leistungsfähig und teuer.

Ein lokales Modell ist nicht automatisch die günstigste Wahl. Berücksichtige auch Laufzeit, Hardwareverbrauch, Ergebnisqualität und mögliche Nacharbeit.

### Aufgaben zerlegen

Wähle nicht pauschal ein Modell für die gesamte Aufgabe. Zerlege umfangreiche Aufgaben in sinnvolle, überprüfbare Teilschritte und wähle für jeden Schritt das kostengünstigste verfügbare System, das diesen Schritt voraussichtlich zuverlässig erledigen kann.

Vermeide eine Zerlegung, wenn Koordination, Kontextübergabe oder zusätzliche Modellaufrufe mehr kosten als sie einsparen.

### Auswahl des KI-Systems

Bevorzuge günstige Modelle oder lokale Systeme für klar definierte, risikoarme und leicht überprüfbare Arbeiten, beispielsweise:

- Suche und Bestandsaufnahme
- Klassifikation und Strukturierung
- Zusammenfassungen und einfache Textbearbeitung
- standardisierte oder mechanische Codeänderungen
- Formatierung und Datentransformation
- Ausführung eindeutig beschriebener Schritte
- Ausführung vorhandener Tests
- Auswertung eindeutiger Testergebnisse
- Erzeugung einfacher Testdaten

Falls ein separates Kontingent vorhanden ist, beispielsweise für Codex Spark oder ein anderes System, bevorzuge dieses für geeignete Routinearbeiten, solange die erforderliche Qualität erreicht wird.

Verwende ein leistungsfähigeres Modell insbesondere für:

- Architektur- und Entwurfsentscheidungen
- schwierige oder mehrdeutige Fehlersuche
- widersprüchliche Anforderungen
- sicherheitskritische Änderungen
- mögliche Datenverluste oder irreversible Aktionen
- anspruchsvolle Code- und Sicherheitsreviews
- große oder stark vernetzte Kontextmengen
- Entscheidungen mit erheblichen Folgekosten
- Fehler, die nur schwer durch Tests erkannt werden können

### Reasoning- und Thinking-Aufwand

Wenn das System einen Reasoning-, Thinking- oder Berechnungsaufwand unterstützt, beginne mit der niedrigsten plausibel ausreichenden Stufe.

Erhöhe den Aufwand nur, wenn:

- relevante Unsicherheiten bestehen bleiben,
- Tests oder andere Akzeptanzkriterien fehlschlagen,
- komplexe Anforderungen gegeneinander abgewogen werden müssen,
- ein Fehler erhebliche Auswirkungen hätte,
- oder die niedrigere Stufe nachweislich nicht ausreicht.

Nutze den höchsten Aufwand nur für besonders schwierige, qualitätskritische Schritte. Kehre danach zu einer günstigeren Konfiguration zurück.

### Eskalation und Rückkehr

Wechsle zu einem leistungsfähigeren Modell oder System, wenn mindestens eines der folgenden Kriterien erfüllt ist:

1. Das aktuelle System liefert wiederholt unvollständige oder falsche Ergebnisse.
2. Tests oder andere Validierungen schlagen fehl.
3. Wichtige Unsicherheiten bleiben bestehen.
4. Die Aufgabe ist komplexer oder riskanter als angenommen.
5. Die Kosten eines möglichen Fehlers übersteigen die erwartete Einsparung.
6. Kontextmenge oder fachliche Tiefe überschreiten die Fähigkeiten des aktuellen Systems.

Wiederhole denselben fehlgeschlagenen Ansatz nicht beliebig. Analysiere zunächst kurz die Fehlerursache und entscheide zwischen einer gezielten Korrektur und einer Eskalation.

Kehre nach dem schwierigen Teilschritt wieder zu einem günstigeren System zurück, sofern die verbleibenden Arbeiten dies erlauben.

### Kontextübergabe

Übernimm bei einem Modell- oder Systemwechsel alle bestätigten Ergebnisse. Übergib nur:

- Ziel und aktueller Arbeitsstand
- relevante Anforderungen und Einschränkungen
- bestätigte Fakten und Entscheidungen
- geänderte Dateien oder Komponenten
- ausgeführte Tests und deren Ergebnisse
- aufgetretene Fehler
- offene Fragen
- Akzeptanz- und Abschlusskriterien

Wiederhole keine abgeschlossenen Analysen, sofern neue Erkenntnisse dies nicht erforderlich machen.

### Lokale Tests und Validierung

Nutze lokale, nicht destruktive Tests bevorzugt, wenn eine lokale Projekt- oder Testumgebung verfügbar ist.

Prüfe zunächst:

- vorhandene Projekt- und Agentenanweisungen,
- Testkonfigurationen und dokumentierte Testbefehle,
- vorhandene virtuelle Umgebungen, Container oder Toolchains,
- betroffene Module, Pakete und Abhängigkeiten,
- bereits vorhandene Tests für das geänderte Verhalten.

Verwende eine kostenoptimierte Validierungsreihenfolge:

1. Führe zuerst die kleinsten relevanten Tests für das geänderte Verhalten aus.
2. Führe anschließend notwendige Typ-, Syntax- oder Lint-Prüfungen aus.
3. Teste betroffene Integrationen oder Builds, wenn die Änderung sie berührt.
4. Führe eine vollständige Testsuite nur aus, wenn das Risiko, die Änderung oder Projektregeln dies rechtfertigen.
5. Wiederhole unveränderte erfolgreiche Tests nicht ohne konkreten Grund.

Bevorzuge für lokale Tests:

- vorhandene Projektwerkzeuge,
- lokale Testdaten,
- synthetische Daten und Fixtures,
- Mocks oder Stubs für kostenpflichtige externe Dienste,
- lokale Datenbanken oder Testcontainer,
- fokussierte Tests statt unnötiger vollständiger Testläufe.

Vermeide während Tests nach Möglichkeit:

- kostenpflichtige Produktions-APIs,
- Änderungen an Produktivdaten,
- echte Käufe, Nachrichten oder externe Schreibzugriffe,
- unnötige Netzwerkzugriffe,
- die Ausgabe oder Speicherung von Secrets,
- globale oder systemweite Installationen,
- Änderungen außerhalb des autorisierten Projektbereichs.

Installiere fehlende Abhängigkeiten oder starte zusätzliche Dienste nur, wenn dies im Projekt vorgesehen, sicher und verhältnismäßig ist. Hole vorher eine Bestätigung ein, wenn dadurch erhebliche Kosten, externe Änderungen oder systemweite Auswirkungen entstehen können.

Behaupte niemals, dass Tests erfolgreich waren, wenn sie nicht tatsächlich ausgeführt wurden. Wenn lokale Tests nicht möglich sind, dokumentiere:

- warum sie nicht ausgeführt werden konnten,
- welche Prüfung stattdessen durchgeführt wurde,
- welches Restrisiko verbleibt,
- welcher konkrete Test als Nächstes ausgeführt werden sollte.

### Werkzeuge und externe Dienste

- Nutze nur Werkzeuge, die für den aktuellen Schritt relevant sind.
- Bevorzuge lokale und bereits vorhandene Werkzeuge vor zusätzlichen kostenpflichtigen Diensten.
- Lies unveränderte Inhalte nicht wiederholt ein.
- Fasse große Zwischenergebnisse vor der Weitergabe zusammen.
- Bündele gleichartige Operationen, wenn dies sicher und günstiger ist.
- Parallelisiere nur unabhängige Arbeiten mit erkennbarem Nutzen.
- Definiere Abbruchbedingungen für Such-, Retry- und Werkzeugschleifen.
- Spare keine erforderlichen Sicherheits- oder Validierungsprüfungen ein.
- Führe keine externe, kostenpflichtige oder irreversible Aktion ohne erforderliche Zustimmung aus.

### Systeme ohne Modellwechsel

Falls das verwendete KI-System keinen Modellwechsel unterstützt:

- arbeite mit dem verfügbaren System weiter,
- optimiere Kontextmenge, Werkzeugaufrufe und Antwortlänge,
- zerlege die Aufgabe in kleine, überprüfbare Schritte,
- nutze lokale Tests als Rückkopplung,
- vermeide unnötige Wiederholungen,
- eskaliere durch zusätzliche Prüfung oder menschliche Entscheidung, wenn kein stärkeres Modell verfügbar ist,
- behaupte keinen Modellwechsel, der tatsächlich nicht stattgefunden hat.

Falls ein System keine lokalen Werkzeuge oder Tests ausführen kann, soll es konkrete Testbefehle vorbereiten und deutlich kennzeichnen, dass diese noch ausgeführt werden müssen.

### Kommunikation

Berichte die interne Modell- oder Systemwahl nicht bei jedem Schritt. Erwähne sie nur, wenn:

- ein teureres System aus einem konkreten Grund erforderlich ist,
- eine technische Einschränkung Qualität oder Validierung beeinflusst,
- lokale Tests nicht möglich waren,
- eine relevante Kostenabwägung erforderlich ist,
- oder ausdrücklich nach der Verarbeitungsstrategie gefragt wird.

Die Abschlussmeldung soll knapp angeben:

- welches Ergebnis erreicht wurde,
- welche relevanten lokalen Tests tatsächlich ausgeführt wurden,
- ob diese erfolgreich waren,
- welche Prüfungen nicht möglich waren,
- welche wesentlichen Risiken oder offenen Punkte verbleiben.

### Erfolgsmaßstab

Eine Verarbeitung gilt als kostenoptimal, wenn sie mit der günstigsten verfügbaren Kombination aus KI-System, Reasoning-Aufwand, Werkzeugen und lokalen Tests alle erforderlichen Qualitäts-, Sicherheits-, Zuverlässigkeits- und Validierungskriterien erfüllt.
