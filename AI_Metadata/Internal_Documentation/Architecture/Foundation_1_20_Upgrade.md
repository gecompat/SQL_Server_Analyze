# Foundation 1.20: Integration und Arbeitsstandard

**Dauerhafte Entscheidungen:** DEC-0001 und DEC-0002 in der [Registration Authority](../../../Metadata/Governance/Artifact_Registry.json).

## Geprüfter Ausgangsstand

Installiert war Ruleset 1.19.0 vom Quellcommit `4aafd20442275d0fdedf291fc6e12e8fe1f683cc`. Das Zielrepository war auf `main` bei `c645efe7539057bf0002e4208c9d5dc61e233241` sauber. Nach Fetch von `origin/main` war das Quellrepository sauber und HEAD entsprach `39ae5c534bb0cf78046485754ed1be7867bf9534`. Dessen Manifest weist Version 1.20.0 aus. Dieser Commit ist die fixierte Quelle des Upgrades; spätere Änderungen an `origin/main` gehören nicht zu diesem Nachweis.

Der [Integrationsplan](Foundation_1_20_Integration.json) enthält Manifest- und Kataloghash, Ausgangscommit, anfänglichen Zustand und Integrationsstrategie jeder der 78 ausgewählten Dateien. Alle Quellhashes wurden vor Übertragung mit der portablen UTF-8-LF/CRLF-Regel geprüft. Bereits installierte Baselines entsprachen ihrem bisherigen Receipt; es gab keinen ungeklärten Drift. Der [aktuelle Receipt](../../../.ai/foundation/installation-provenance.json) dokumentiert die abschließenden installierten Hashes und die beiden intentionalen Overrides.

## Featurebewertung und Auswahl

Die [schemaförmige Bewertung](Foundation_1_20_Upgrade_Assessment.json) enthält genau alle 21 seit 1.19.0 eingeführten oder materiell geänderten Kandidaten aus dem fixierten Featurekatalog. Jede Klassifikation enthält Projektevidenz und Begründung. Die Adapter `github-copilot`, `claude-code` und `gemini` sowie die Capabilities `artifact-registry-github` und `rule-context-cache` bleiben ausgewählt. Die übrigen Manifestcapabilities bleiben ungewählt; Core-Schemas aktivieren keine ausführbare Fähigkeit.

Die Empfehlungen werden wie folgt behandelt:

- `bounded-processing-efficiency` und `rule-context-cache` sind innerhalb dieses ausdrücklichen Auftrags umgesetzt. Sessionlokale Analyseverfügbarkeit ist Standard; persistente Records bleiben optional. Leseprofile werden um deklarierte transitive Abhängigkeiten erweitert.
- `ai-work-orchestration` übernimmt die Core-Proportionalitätsregeln. Strukturierte Requests und Receipts gelten erst für die betroffene ausgewählte Orchestrierungsoperation; gewöhnliche Änderungen benötigen diese nicht.
- `ai-client-integration` bleibt eine bedarfsbezogene Empfehlung. Es werden keine Clientkonfiguration, Remotezugriffe oder Dispatchmechanismen eingerichtet. Eine spätere Auswahl verlangt tatsächliche Client- und Ausführungsevidenz.
- `repository-continuity-break-glass` bleibt eine administrative Empfehlung für getrennte Core-Safety-/CI-Gates und einen eng begrenzten PR-only-Bypass bei belegter Infrastrukturunverfügbarkeit. Bypassakteure, Rulesets und Branch Protection werden nicht gewählt oder geändert. Workflowdateien allein beweisen keine aktuelle serverseitige Durchsetzung; Live-Administration wurde hier nicht geprüft.
- `session-lifecycle-management` bleibt ereignisbezogen an natürlichen Grenzen. Automatische Rotation und numerische Kontextschwellen bleiben ungewählt. Unveränderte Blocker lösen keine timerbedingte Modellarbeit aus.

Es gibt keine ungeklärte Featureklassifikation `CONFLICT` oder `DECISION_REQUIRED`. Die genannten späteren Optionen werden durch dieses Upgrade nicht aktiviert.

## Semantische Überschneidungen

| Umfang | Klassifikation und Behandlung |
|---|---|
| Produkt-, Datenschutz- und Lizenzverträge | `PROJECT_STRONGER` beziehungsweise `COMPLEMENTARY`; erhalten. Root-README und Rootlizenz wurden nicht bearbeitet. |
| Identität und Registrierung | `EQUIVALENT`; bestehende v2-Authority, UIDs, Referenzen und ADOPT_FORWARD-Historie erhalten. Keine neue finale Sequenz oder Migration. |
| CI und lokale Prüfumfänge | `PROJECT_STRONGER` beziehungsweise `PROJECT_SELECTABLE_OVERRIDE`; 1+0+N und Schutz laufender SQL-CI erhalten. |
| Root-Entrypoint | `COMPLEMENTARY`; ausschließlich Foundationblock semantisch aktualisiert, Projekt-Discovery außerhalb des Blocks erhalten. |
| Umfangreiche Kosten- und Koordinationsregeln | `DUPLICATE_GOVERNANCE`; auf kanonische Core-Policies und verbleibende Projektgrenzen reduziert. Der Benutzer hat die Änderung ausdrücklich freigegeben. |
| Verpflichtender persistenter Cache und breiter Leseumfang | Bisher kompatibel, aber mit separater Effizienzempfehlung; durch autorisierten sessionlokalen Standard und Scopeindex Version 2 ersetzt. Persistente Vertragsgrenzen erhalten. |
| Copilot-, Claude- und Gemini-Adapter | `EQUIVALENT`; reine Discoverybrücken ohne verlorene Einzelgovernance. |
| Registrypfad im GitHub-Workflow | `PROJECT_SELECTABLE_OVERRIDE`; `Metadata/Governance/Artifact_Registry.json` erhalten und im Receipt begründet. |

Es wurden keine aktiven verwaisten Autoritäten, verlorenen Adapterregeln oder ungeklärten REQUIRED-Konflikte im betroffenen Integrationsumfang gefunden. Der vollständige Discoverybestand bleibt prüfbar; er ist keine pauschale Leseverpflichtung. Zusätzliche fachliche Scopes verlangen vor Wiederverwendung die Prüfung ihrer Regeln und transitiven Abhängigkeiten.

## Validierungsgrenzen

Foundationintegrität, Projektsemantik und synthetisches Ausführungsverhalten werden getrennt geprüft. Die konkreten Abschlussbefehle und Ergebnisse stehen im Abschnitt Validierung. Der Umfang verändert keine SQL-Produktfunktion und aktiviert gemäß CI-Teststrategie keine SQL-Server-Instanz. Unbekannte effektive Clientkonfiguration wird nicht geraten; lokale synthetische Discoverytests attestieren keine aktuelle Clientkonfiguration.

Die Aufgabe ist auf eine kohärente Upgrade-/Cachewelle mit einem Implementierer und höchstens einem unabhängigen Reviewer begrenzt. Kosten- und Kontingentmessung ist nicht zuverlässig verfügbar; eine monetäre Durchsetzung wird nicht behauptet. Die gemeinsame Grenze umfasst Korrekturen, Prüfungen und Koordination. Erforderliche offene Prüfungen bleiben als solche sichtbar und werden nicht aus Budgetgründen als abgeschlossen bezeichnet.

## Validierung

Die folgenden lokalen Nachweise wurden am 9. Oktober 2026 tatsächlich ausgeführt:

| Scope | Befehl beziehungsweise Verfahren | Ergebnis und Grenze |
|---|---|---|
| `FOUNDATION_INTEGRITY` | Quellwerkzeug `tools/foundation_validator.py --target TARGET --adapters github-copilot,claude-code,gemini --capabilities artifact-registry-github,rule-context-cache --profile full --json` | Bestanden; alle 78 ausgewählten Dateien sind aktuelle Baselines oder einer der zwei begründeten Overrides. |
| `PROJECT_SEMANTIC` | Vollständiger Feature-Delta-Vergleich, Schema-Constraints, Manifest-/Receiptzielmenge und Evidenzlocatorprüfung | Bestanden; 21 eindeutige Kandidaten, 78 ausgewählte Ziele und exakte Quellcommitbindung. Schema-Constraints wurden ohne zusätzliche Abhängigkeit lokal geprüft. |
| `PROJECT_SEMANTIC` | `python Code/Tests/Static/Validate_Rule_Context_Cache.py` | Bestanden; alle sieben Leseprofile und ihre lokalen Verweise sind auflösbar. Der Discoverybestand enthält 54 Quellen; das Standardprofil liest acht Regeln nach Abhängigkeitserweiterung. |
| `RUNTIME_EMPIRICAL` | `python Code/Tests/Static/Validate_Rule_Context_Cache.py --self-test` | 23 synthetische Vertragsfälle bestanden. Nach der abschließenden Filterung interner Kontrollschlüssel bestanden ausschließlich die zehn betroffenen Sessionfälle erneut. Die persistenten 13 Fälle wurden ohne neue Änderung ihres Vertrags nicht erneut ausgeführt. |
| `PROJECT_SEMANTIC` | `python .ai/foundation/artifact_registry_github/registry_semantic.py validate --registry Metadata/Governance/Artifact_Registry.json` | Bestanden; 15 registrierte Artefakte, keine neue Referenzvergabe oder historische Migration. |
| `PROJECT_SEMANTIC` | `python Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root . --self-test` sowie Repositoryscan | Bestanden; keine Datenschutzbefunde. |
| `PROJECT_SEMANTIC` | `python Code/Tests/Static/915_Validate_Documentation_Style.py --repository-root .` und `git diff --check` | Bestanden; keine Stilbefunde beziehungsweise Whitespacefehler. |
| `PROJECT_SEMANTIC` | Ein unabhängiger semantischer Review und begrenzte Nachprüfung seiner Korrekturen | Zwei P2-Befunde zu normativen Abhängigkeiten und Inline-Regelverweisen wurden behoben und durch Regressionen abgesichert. Keine verbleibenden Befunde im geprüften Umfang. Hashes und mechanische Nachweise wurden lokal geprüft. |

Der Core-Effizienzaudit wurde für die vier betroffenen Arbeitsregeldokumente auf Ausgangs- und Abschlussstand ausgeführt. Seine textuellen Hinweise sind ausschließlich beratend. Die tatsächlichen Änderungen beruhen auf der semantischen Prüfung und dem ausdrücklichen Auftrag, nicht auf einer automatischen Freigabe durch den Auditor.

SQL-Laufzeittests, fremde Labs, neue Runtimekonfiguration und Live-GitHub-Administrationsprüfungen wurden nicht ausgeführt. Der SQL-Produktvertrag bleibt unverändert; die CI-Teststrategie fordert für diesen Umfang keine SQL-Server-Instanz. Die synthetischen Tests belegen Adapterverhalten, nicht die unbekannte effektive Clientkonfiguration einer aktiven Session. Erforderliche Remote-CI bleibt vor einem tatsächlichen PR-Merge an dessen exakten Head gebunden.
