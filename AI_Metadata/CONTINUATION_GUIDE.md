# Fortsetzungshinweise

## Normativer Status

Die verbindlichen Repositoryanweisungen stehen in `AGENTS.md` und `AI_Metadata/PROJECT_CONTEXT.md`. Für Testauswahl, CI-Umfang, Compatibility-Level-Läufe und native Versionsprüfungen gilt ausschließlich `Documentation/Quality/CI_Test_Strategy.md`.

Historische Commitbeschreibungen und frühere Workflow-Namen gehören in die Git-Historie. Sie sind keine Fortsetzungsanweisungen und werden in diesem Dokument nicht wiederholt.

## Lab-Zentralisierung

Allgemeine Lab-Provisionierung wurde aus diesem Repository entfernt und liegt in `https://github.com/gecompat/SQL_Server_Lab`.

In diesem Repository verbleiben ausschließlich analyserspezifische Inhalte:

- `Lab/Orchestration/` für das DiagnosticLab-Modul;
- `Lab/Contracts/` für Szenario-, Finding- und Evidenzschemas;
- `Lab/Scenarios/` für analyserspezifische Szenarien; und
- `Lab/Validation/` für analyserspezifische Validierung.

Eine zusätzlich benötigte allgemeine Lab-Funktion wird nicht stillschweigend in SQL_Server_Analyze implementiert. Sie muss als Änderungsvorschlag für SQL_Server_Lab benannt und vor einer dortigen Umsetzung freigegeben werden.

## Vor einem kohärenten Änderungsschritt

- Prüfen Sie aktuelle Autorität, effektive Discovery-Konfiguration, ausgewählte Quellen und transitive Abhängigkeiten gemäß [Regelkontext](Rule_Context_Cache.md), bevor Sie verfügbare Sessionanalyse wiederverwenden. Der persistente Cache ist optional. Fehlende Analyse oder unvollständige Discovery verlangt den vollständigen Leseweg des betroffenen Umfangs.
- Prüfen Sie die für den betroffenen Pfad geltenden Anweisungen und die case-sensitive Namenskonsistenz.
- Lesen Sie vor Dokumentationsänderungen `Documentation/Quality/Documentation_Writing_Style.md`.
- Aktualisieren Sie ein kanonisches Einzelobjekt, generierte Installer, Inventare und Referenzdokumentation gemeinsam, soweit deren Vertrag betroffen ist.
- Führen Sie keine konkrete Installationsdatenbank und keine realen personen-, kunden-, firmen-, organisations-, betriebs- oder umgebungsbezogenen Werte in Repositoryartefakte ein.
- Beispiele und gespeicherte Testergebnisse verwenden ausschließlich eindeutig synthetische, generische Werte ohne Nachbildung einer realen internen Struktur.
- Halten Sie bei einem uneindeutigen Artefaktwert vor dem Schreiben an; eine Zustimmung hebt das Repositoryverbot nicht auf.

## Abschluss eines kohärenten Änderungsschritts

- Führen Sie die für den geänderten Vertrag betroffenen statischen API-, Portabilitäts-, Dokumentations- und Quellenaudits am kohärenten Abschlussstand aus. Unveränderte erfolgreiche Prüfungen werden nicht allein wegen einer weiteren Dateiänderung wiederholt.
- Prüfen Sie den stabilen Lieferstand mit `python3 Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root .`. Führen Sie den Selbsttest zusätzlich aus, wenn der Validator, seine Abhängigkeiten oder die Prüfumgebung betroffen sind oder ein neuer Befund dies verlangt. Ein unveränderter Zwischenstand löst keinen weiteren Scan aus.
- Prüfen Sie die endgültige Commit Message mit `Code/Tests/Static/930_Validate_Commit_Message.py` im zutreffenden Delivery Mode. Eine unveränderte Commitfolge wird lokal nicht erneut geprüft.
- Erzeugen Sie betroffene Installer aus den kanonischen Einzeldateien neu und aktualisieren Sie abhängige Beispiele, Inventare und Referenzen.
- Wählen Sie funktionale Tests ausschließlich gemäß `Documentation/Quality/CI_Test_Strategy.md`. Eine gewöhnliche Änderung verlangt keinen pauschalen Lauf auf SQL Server 2019, 2022 und 2025.
- Aktualisieren Sie Laufzeitevidenz nur für tatsächlich ausgeführte Kombinationen. Compatibility-Level-Läufe dürfen nicht als native Engine-Nachweise ausgewiesen werden.

## Koordination und Budget

Ein Implementierer bearbeitet den kohärenten Umfang. Ein unabhängiger Review erfolgt bei fachlichem Risiko oder verbindlicher Unabhängigkeitsvorgabe. Weitere Reviews benötigen eine konkrete offene Frage. Hashes, Manifestdeckung, Mengen und Revisionsbindungen werden lokal geprüft. Timerbedingte Modellarbeit und unveränderte Testwiederholungen sind kein Fortsetzungsschritt.

Vor längerer autonomer Arbeit wird ein gemeinsamer endlicher Wellenumfang einschließlich Implementierer, aller Nachkommen, Wiederholungen und Koordination festgelegt. Bei verlässlicher Messung werden Einheit, Quelle, Checkpointschwelle und Obergrenze gewählt. Fehlt diese Messung, gilt ein endlicher Aufgaben- und Agentenumfang; Kosten- oder Kontingentdurchsetzung wird nicht behauptet. Standard sind ein kohärenter Änderungsschritt, ein Implementierer und höchstens ein unabhängiger Reviewer. An der Abschlussgrenze werden Ergebnis und verbleibende Arbeit gesichert. Neue Arbeit beginnt nur innerhalb des freigegebenen Umfangs; eine notwendige offene Prüfung verhindert die Abschlussbehauptung.

## Maßgebliche Fortsetzungsquellen

Diese Quellen sind aufgabenbezogen auffindbar. Historische Nachweismatrizen und technische Lab-Verträge werden nur gelesen, wenn ihr Umfang tatsächlich betroffen ist.


- `AGENTS.md`
- `AI_Metadata/PROJECT_CONTEXT.md`
- `Documentation/Quality/CI_Test_Strategy.md`
- `Documentation/Quality/CI_Impact_Selection.md`
- `Documentation/Quality/Test_Matrix.md`
- `Documentation/Architecture/TSQL_SCENARIO_ORCHESTRATION.md`
