# Foundation 1.21: Integration und Prüfaufwand

**Bewertung:** [Foundation_1_21_Upgrade_Assessment.json](Foundation_1_21_Upgrade_Assessment.json)

**Vorheriger Stand:** [Foundation_1_20_Upgrade.md](Foundation_1_20_Upgrade.md)

## Quelle und Auswahl

Die installierte Foundation-Version war 1.20.0 mit dem Quellcommit `39ae5c534bb0cf78046485754ed1be7867bf9534`. Die neue Quelle ist das saubere `origin/main` von `D:\r\pu\AI_Repository_Foundation` bei Commit `d720db4f2f0d043756a958d5195d0e62090b1c8f`. Das dortige Manifest weist Version 1.21.0 aus; sein SHA-256 lautet `f1532ebdee4325227e72fbe111450ee8f9401d2933adf4ac9e4beaab84d64311`. Der Kataloghash lautet `46940b1baef4404dd6abd9e440f79a190cc51b07c773dcef52e5ff0924ac40d1`. Beide Dateien wurden am fixierten Commit gelesen.

Die bisherigen Adapter `github-copilot`, `claude-code` und `gemini` sowie die Capabilities `artifact-registry-github` und `rule-context-cache` bleiben ausgewählt. Alle 78 ausgewählten Manifestziele sind im Installationsreceipt einzeln mit Quell- und Zielhash aufgeführt. Vor der Übertragung wurden die Quellhashes gegen das Manifest und die bisherigen Zielhashes gegen das vorhandene Receipt geprüft. Neun geänderte Foundation-Baselines wurden übertragen. Der Root-Entrypoint integriert den neuen Absatz in seinen verwalteten Foundationblock und erhält die Projektregeln außerhalb des Blocks. Der Registry-Workflow behält seinen projektspezifischen Registrypfad; beide Abweichungen bleiben begründete Overrides. Weitere optionale Capabilities wurden nicht aktiviert.

Der Featurekatalog enthält sechs materiell geänderte und einen neu eingeführten Kandidaten für 1.20.0 bis 1.21.0. Die schemaförmige Bewertung klassifiziert alle sieben Kandidaten genau einmal. Die Empfehlung `bounded-processing-efficiency` ist durch den aktuellen Auftrag angenommen und in den Projektregeln und Workflows umgesetzt. Es bleiben keine offenen `CONFLICT`- oder `DECISION_REQUIRED`-Klassifikationen.

## Tatsächliche Aufwandsprüfung

| Bereich und bisheriger Auslöser | Schutzvertrag und Änderung |
|---|---|
| Die Dokumentations-CI startete bei jedem passenden PR die gesamte statische Suite. Diese rief 71 Validator-Selbsttests, überwiegend dieselben Repositoryvalidatoren und weitere Prüfungen auf. | Reine Foundation- und Regelkontextänderungen nutzen nun ausschließlich Dokumentationsstil- und Regelkontextvalidator. Andere Pfade behalten die vollständige statische Suite. Ein leerer oder nicht zuordenbarer Dateisatz kann den engen Scope nicht aktivieren. |
| Die statische Suite wiederholte unveränderte Validator-Selbsttests; Datenschutz und Impact-Selector liefen zusätzlich in eigenen Workflows. | Die CI-Suite führt Selbsttests nur für geänderte Validatoren, deren bekannte Abhängigkeiten oder eine Änderung an der Suite selbst aus. Datenschutz und Impact-Selector sind aus dieser CI-Suite ausgenommen; ihre eigenen Gates bleiben aktiv. Der manuell vollständige Suiteaufruf behält seine bisherigen Selbsttests. |
| Der Fortsetzungsleitfaden verlangte nach jedem kohärenten Schritt einen Datenschutz-Selbsttest und anschließenden Vollscan. | Der Scan gilt am stabilen Lieferstand; ein erneuter lokaler Scan braucht eine relevante Änderung. Der Selbsttest folgt einer Änderung des Prüfwerkzeugs, seiner Abhängigkeiten oder Prüfumgebung oder einem neuen Befund. Die repositoryweite Datenschutz-CI prüft weiterhin jeden PR-Lieferbaum und dessen ZIP; ihr Selbsttest läuft bei betroffenem Validator, Allowlist, Workflow oder unbekannter Revisionsbindung. |
| Die Commit- und funktionalen Impact-Workflows starteten ihre Validator-Selbsttests auch bei unveränderten Prüfwerkzeugen. | Beide prüfen neue Commits beziehungsweise den aktuellen SQL-Impact weiterhin an jedem relevanten Head. Ihre Selbsttests laufen bei betroffenem Prüfwerkzeug, Workflow oder unbekannter Revisionsbindung. |
| Dokumentations-CI speichert Fehlerlogs als Artefakt; lokale Regeln begrenzen Modellarbeit bereits auf offene Fragen. | Fehlerstatus und relevante Logstellen werden lokal gelesen. Der Workflow lädt nur bei Fehlschlag ein Log hoch; es gibt keine automatische vollständige Logübertragung an ein Modell. Ein neues Logwerkzeug oder eine Reviewkette wird nicht eingerichtet. |
| Die Arbeitsregeln verlangen einen Implementierer, Review bei Risiko und keine timerbedingte Wiederholung. | Diese Begrenzung bleibt erhalten. Mechanische Hash- und Revisionsprüfungen laufen lokal; zusätzliche Reviews oder Modellaufrufe brauchen einen neuen Befund, geänderte Eingaben oder eine konkrete Pflicht. Im betroffenen Repositorybestand wurde kein wiederkehrender Testtimer als Entwicklungsgate gefunden. |

Der vollständige statische Fallback bleibt begründet, solange die Abhängigkeiten der übrigen Validatoren nicht vollständig als verlässlicher Selector beschrieben sind. Eine Verkleinerung allein anhand breiter Dateinamen könnte betroffene Produktverträge übersehen. Das funktionale 1+0+N-Gate, die native Releasequalifikation, Datenschutz und Commitprüfung sowie erfolgreiche erforderliche Checks am exakten PR-Head bleiben verbindlich. `cancel-in-progress: false` für laufende SQL-Validierung bleibt wegen des nicht belegten Cleanup nach hartem Abbruch bestehen. Diese Ausnahmen haben begrenzte Auslöser; sie verpflichten nicht zu unveränderten lokalen Testwiederholungen.

Die Vorher-/Nachher-Bewertung beschreibt strukturell vermiedene Aufrufe. CI-Minuten, Modelltoken und Kontingentkosten wurden nicht verlässlich gemessen und werden nicht als Einsparung beziffert. Die Auswahl trennt Entwicklung und betroffene Integration von vollständiger Qualifikation und Release; fehlende Qualifikationsnachweise werden durch einen fokussierten Entwicklungscheck nicht ersetzt.

## Nachweise und Grenzen

Die folgenden lokalen Nachweise wurden am 9. Oktober 2026 ausgeführt:

| Umfang | Ergebnis |
|---|---|
| Foundation-Quellvalidator, Profil `full`, am fixierten Manifest und neuen Receipt | Bestanden; 78 ausgewählte Ziele, zwei begründete Overrides, keine Fehler oder Warnungen. |
| Katalogdelta und Bewertung | Bestanden; sieben Kandidaten mit eindeutiger Klassifikation und übereinstimmenden Kandidatengründen. |
| Regelkontext und Dokumentation | Enger Governance-Scope bestanden; 23 synthetische Cache-Vertragsfälle, Regelkontext-Repositoryprüfung und Dokumentationsstil bestanden. Ein zweiter Lauf mit unverändertem Validator bestätigte den Weg ohne Selbsttest. |
| Vollständiger statischer Fallback nach Änderung des Suitewerkzeugs | Bestanden; 73 eingeschlossene Validatoren sowie Dokumentations- und TestLab-Verträge. Eigenständige Datenschutz- und Impact-Gates wurden nicht darin wiederholt. |
| Scope-Gegenproben und Workflows | Sieben zulässige und fünf Rückfallpfade bestanden; erzwungener unzulässiger Governance-Scope wurde abgewiesen. Die Bash-Syntax von 18 Workflowblöcken wurde geprüft. |
| Eigenständige Validatoren und Lieferstand | Datenschutz-Selbsttest und Repositoryscan mit 1118 Dateien, Impact-Selector-Selbsttest, Commit-Selbsttest und Prüfung des neuen Commits bestanden. |

Der Core-Impact-Selector klassifiziert die Änderung des funktionalen Workflows als vollständiges SQL-Server-2025-Gate; der Snapshot-Scope benötigt keinen zusätzlichen Runtimejob. SQL-Produktcode wurde nicht verändert. Ein lokaler SQL-Server-Lauf wurde nicht ausgeführt. Der erforderliche funktionale Remote-Check und die weiteren PR-Checks müssen vor Integration am exakten PR-Head erfolgreich sein. Unbekannte Clientkonfiguration und GitHub-Rulesets werden durch diese lokalen Tests nicht attestiert.
