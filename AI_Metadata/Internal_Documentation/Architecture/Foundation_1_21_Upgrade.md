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


## Verarbeitung beim Fertigstellungsauftrag vom 13. Oktober 2026

Der neue Benutzerauftrag priorisiert fehlende Produktfunktionen. Der
begonnene zusätzliche gemischte Mailstatus-Nachweis wird dafür zurückgestellt;
er ist kein Eintrittsgate für eine unabhängige Funktionsimplementierung.
Aktueller Code und fachliche Verträge werden vor einer Statusentscheidung
abgeglichen. Ein Intake wird nicht als fehlende Procedure gezählt und eine
vorhandene Implementierung wird wegen eines veralteten Status nicht erneut
entwickelt. Neue öffentliche Verträge bleiben konkret freigabepflichtig.

Eine kohärente Funktionsänderung besitzt einen Implementierer und bei
fachlichem Risiko einen unabhängigen Reviewer. Native Tests folgen der
betroffenen Funktion und ihrer tatsächlichen Versionsabhängigkeit; der
1+0+N-Standard und die abschließenden Releasegates bleiben erhalten.
Unveränderte erfolgreiche Nachweise werden nicht wiederholt. Direkte lokale
Einzelprüfungen werden in einer späteren Suite am selben unveränderten
Eingabestand nicht erneut gezählt; neue Dateien und geänderte Eingaben
benötigen ihren eigenen betroffenen Liefercheck. Timer erweitern den
Prüfumfang nicht. Kosten und Kontingente bleiben unbekannt. Diese Änderung
betrifft die Reihenfolge und beendet keinen bestehenden Sicherheits- oder
Validierungsvertrag; eine Foundationinstallation findet nicht statt.

## Regelübernahme vom 19. Oktober 2026

Der direkte Benutzerauftrag übernimmt geeignete neue Regeln aus einem
externen Entwicklungsvorschlag. Die darin vorgeschlagene technische
CI-Optimierung wird damit nicht als ausgeführte Implementierung oder neue
Produktwelle behandelt. Maßgeblich für Testumfang und Evidenz ist weiterhin
die [CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md);
der [Fortsetzungsleitfaden](../../CONTINUATION_GUIDE.md) verweist auf diese
Regeln. Die Foundationbaselines und Installationsprovenienz werden nicht
geändert. Die vorhandene maschinenlesbare CI-Policy behält ihre Auswahlklassen,
Engines und Trigger; die Ergänzungen führen keine zusätzliche Testklasse ein.

Die lesende Ausgangsprüfung bindet den sauberen lokalen und entfernten
Mainstand `f41c3d4fcc76a883ee532184a1f3f26e48039578`. PR397 ist integriert;
offene PRs oder weitere aktive Worktrees sind zum Prüfzeitpunkt nicht
vorhanden. Die aktuellen Mainchecks sind erfolgreich. Die erste fehlgeschlagene
funktionale Ausführung und deren erfolgreiche Nachprüfung bleiben getrennte
historische Ergebnisse; der Erfolg beweist keine Ursache des vorherigen 1222.
Die autonome Produktarbeit ist beim Beginn der Regelübernahme pausiert.

| Geprüfter Auslöser oder Vorschlag | Befund und Disposition |
|---|---|
| Semantische SQL-Auswahl und Full-Fallback | Der Selector entfernt Kommentare, verfolgt erkannte Referenzen transitiv und wählt Tests und Sondergates. Änderungen an Installer, Setup, Runner, Selector oder funktionalem Workflow behalten das Full Gate. Eine nicht sicher zuordenbare Produktionsänderung fällt konservativ zurück. Diese Mechanismen werden erhalten. Zusammengesetzte dynamische Referenzen sind durch den regexbasierten Ansatz nicht allgemein bewiesen; eine Verengung benötigt eigene Gegenproben. |
| Repräsentative Produktänderung | PR397 ändert SSIS-Produkt, Integration207 und den zentralen Release-Runner. Bereits die Runneränderung erklärt das Full Gate; eine vermeidbare native Doppelprüfung ist damit nicht nachgewiesen. Die vorherigen SSIS-PRs 394 bis 396 betreffen ebenfalls Produkt und Release-Runner. Aus deren Laufzeit wird kein Einsparungswert abgeleitet. |
| Statische Suite und Dokumentationsworkflow | `SelfTestMode=Changed` sowie `ExcludePrivacy` und `ExcludeImpactSelector` vermeiden die entsprechenden Selbsttestwiederholungen im Dokumentationsgate. Der enge FoundationGovernance-Scope bleibt auf seine belegten Pfade begrenzt; unbekannte Validatorabhängigkeiten behalten die volle statische Suite. Die vorliegende Änderung an der kanonischen CI-Strategie fällt in diesen statischen Fallback, ohne SQL-Runtime zu begründen. |
| Datenschutz, Commit- und Registry-Gates | Repositoryscan und ZIP-Scan prüfen verschiedene Lieferrepräsentationen; Commitprüfung betrifft eingeführte Commits, Registryprüfung Identitäten und semantische Integration. Diese unabhängigen Schutzaufgaben sind keine entfernbaren SQL-Doppeltests. Die bedingten Datenschutz-, Commit- und Selector-Selbsttests bleiben erhalten. |
| SQL-Aufbau und Sonderverträge | Der funktionale Workflow führt die native Deploymentregression, Datenbankaufbau, Installation und ausgewählte Verträge aus. Rechte, Regex und Standalone laufen bei Auswahl; Snapshot besitzt eigenen Datenbankaufbau und Smoke. Die native Release-Matrix bleibt manuell mit eigenen Versions- und Rechteprüfungen. Installations- oder Rechtegates werden nicht wegen ähnlicher Setupschritte entfernt. |
| Deterministische Bewertung und Modellarbeit | Die kanonische Strategie ergänzt lokale Soll-Ist-Prüfung, wahrheitsgetreue Statussemantik, kompakte Erfolgsreferenzen und lokale Fehlerklassifikation. Ein vollständiger Erfolg verlangt keine weitere Modellbestätigung. Pflichtreview, Human-Acceptance und fehlende Qualifikation bleiben davon unberührt. Es wird kein neues Berichtssystem eingerichtet. |
| Local-to-Remote-Reuse | Im geprüften Workflowbestand gibt es keinen vertrauenswürdigen Host-Attestierungs- und Remote-Verifikationspfad. Ergebnis: NOT_IMPLEMENTED; bestehende Remoteausführung bleibt erforderlich. Herkunft, Scope, Umgebungsdrift, Aktualität, Cleanup, aktuelle Required Checks und Ereignisbindung sind verbindliche Bedingungen einer späteren Implementierung. Ein Workerreceipt oder Build-Provenienznachweis ersetzt diese Grenzen nicht. |
| Cleanup und Erfolgsgrenzen | Der bestehende Containercleanup läuft mit `always()` und toleriert einen Fehler des Entfernungsbefehls. Das ist kein unabhängiger Nachweis erfolgreicher Ressourcenentfernung. Ein künftiger kompakter Gesamtergebnisbericht oder Reusepfad muss diesen Nachweis liefern oder die Lücke offen ausweisen; die aktuelle Regelübernahme behauptet keine neue Cleanupqualifikation. |
| Logging, Reviews und Wartezustand | Der funktionale Fehlerpfad zeigt begrenzte Logstellen; die Dokumentations-CI lädt nur bei Fehlern ihr Log hoch. Ein gesondert vorgeschlagener 1222-Beobachter wird hier nicht implementiert oder freigegeben. Ein Implementierer und ein unabhängiger Regelreview bilden den endlichen Umfang. Timer, Erfolg und abgeschlossener Review begründen keine weitere Reviewkette oder Wiederaufnahme der pausierten Produktarbeit. |
| Datenschutz und Autorität des Vorschlags | Die synthetische Repositorygrenze und das Stop-Gate bei ungeklärten Werten bleiben erhalten. Ein hypothetischer Zweifel an beliebigen öffentlichen Fakten wird nicht zu einer neuen pauschalen Rückfragepflicht. Vor Transfer zählt die tatsächliche Daten- und Zieleinordnung. Der externe Vorschlag ist keine eigenständige Merge-, Upload-, Hoständerungs- oder Fortsetzungsbefugnis. |

Die Ergänzungen sind zu den bestehenden Foundationregeln komplementär;
die strengere synthetische Repositorygrenze bleibt PROJECT_STRONGER.
Gemeinsame Regeln werden in den vorhandenen kanonischen Quellen ergänzt,
statt eine zweite Policy aus dem externen Text anzulegen.
Die neuen Selektor- und Reusegegenfälle sind Abnahmeanforderungen für eine
betroffene spätere Implementierung, keine Behauptung bereits ausgeführter
Tests. Eine technische Optimierung muss aktuelle repräsentative Läufe nach
Scope, Oracles, Setup, Rechten und Cleanup vergleichen. Bis dahin sind
zusätzliche CI-Zeit-, Runner-, Token- und Kosteneinsparungen UNKNOWN.

Offene technische Punkte sind der nicht implementierte vertrauenswürdige
Reusepfad, die nicht allgemeingültig bewiesene dynamische Abhängigkeitsanalyse
und ein unabhängig prüfbarer Cleanupstatus für einen zukünftigen Gesamtbericht.
Keiner dieser Punkte erlaubt das Auslassen bestehender Gates. Ein eigener
begrenzter Implementierungsauftrag mit den in der CI-Strategie festgelegten
Gegenproben ist die Fortsetzungsbedingung. Die Regelübernahme schließt diese
technischen Punkte nicht als Effizienzimplementierung ab.

## Begrenzte CI-Sperrdiagnose vom 19. Oktober 2026

Der freigegebene Änderungsschritt ergänzt ausschließlich die CI-Protokollierung
für Fehler 1222. Die SSIS-Verträge 202 bis 207 erhalten Aufrufmarker; ein
Beobachter liest Requests und Sperren nur für markierte Sessions und deren
direkte Blocker. Er verwendet eine zusätzliche Verbindung, frühestens eine
Abfrage je 250 Millisekunden, höchstens zehn Minuten Laufzeit und einen
begrenzten Ringpuffer. Die Erfassung hat Eigenlast und garantiert insbesondere
bei einem sofortigen Timeout keinen Blockernachweis.

Der Workflow sichert bei Fehlern höchstens 50 MiB bereinigte Diagnoseartefakte
für einen Tag. Erfolgreiche gewöhnliche Läufe übertragen keine vollständigen
Logs an ein Modell und erzeugen keine Diagnoseartefakte. Die neue synthetische
Sperrabnahme läuft nur bei betroffener CI-Infrastruktur im vorhandenen
SQL-Server-2025-Container eines Pull Requests, mit einer Grenze von 60 Sekunden.
Änderungen an beiden Hilfsdateien sind in Pfadtrigger und Impact-Selector
eingebunden. Es entsteht keine weitere native Engine oder Release-Matrix.

Die Workflowänderung verlangt gemäß kanonischer Strategie das vollständige
funktionale Gate auf SQL Server 2025 sowie die betroffenen statischen Gates.
Unveränderte erfolgreiche Prüfungen werden lokal nicht wiederholt. Das
freigegebene Budget umfasst zwölf Dateien, einen Implementierer, einen
unabhängigen Reviewer mit höchstens zwei Reviewdurchgängen, einen
befundgebundenen Korrekturpass und insgesamt höchstens drei funktionale
CI-Qualifikationen einschließlich PR und Main. Die Offlineprüfung und die
synthetische Sperrabnahme erhalten jeweils höchstens eine gezielte
Fehlernachprüfung. Ein Budgetende lässt fehlende Nachweise offen.

Kosten, Tokenverbrauch und eingesparte CI-Minuten wurden nicht verlässlich
gemessen. Diese Grenzen sind Aufgaben- und Ausführungsgrenzen; sie behaupten
keine gemessene Kostenersparnis. Die übrige autonome Verarbeitung bleibt
pausiert. Die Abnahmeergebnisse werden commitgebunden im Pull Request und
in den CI-Artefakten ausgewiesen; geplante Prüfungen gelten nicht als bestanden.

Nach der ersten CI-Qualifikation wurde ein zusätzlicher gebündelter
Korrekturpass mit höchstens einer weiteren gezielten Offline-Nachprüfung
ausdrücklich freigegeben. Er betrifft die Benennung des aus der Umgebung
gelesenen Wertes und des synthetischen Prüfwertes sowie den SQLCMD-Aufruf
und die Erhaltung seiner ursprünglichen Startfehlermeldung. Das
Datenschutzgate, die zwölf Dateien, zwei Reviewdurchgänge und die Grenze
von insgesamt drei funktionalen CI-Qualifikationen bleiben unverändert.
