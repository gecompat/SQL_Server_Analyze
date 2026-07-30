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

## Vor jeder Änderung

- Prüfen Sie die für den betroffenen Pfad geltenden Anweisungen und die case-sensitive Namenskonsistenz.
- Lesen Sie vor Dokumentationsänderungen `Documentation/Quality/Documentation_Writing_Style.md`.
- Aktualisieren Sie ein kanonisches Einzelobjekt, generierte Installer, Inventare und Referenzdokumentation gemeinsam, soweit deren Vertrag betroffen ist.
- Führen Sie keine konkrete Installationsdatenbank und keine realen personen-, kunden-, firmen-, organisations-, betriebs- oder umgebungsbezogenen Werte in Repositoryartefakte ein.
- Beispiele und gespeicherte Testergebnisse verwenden ausschließlich eindeutig synthetische, generische Werte ohne Nachbildung einer realen internen Struktur.
- Halten Sie bei einem uneindeutigen Artefaktwert vor dem Schreiben an; eine Zustimmung hebt das Repositoryverbot nicht auf.

## Nach jeder Änderung

- Führen Sie die betroffenen statischen API-, Portabilitäts-, Dokumentations- und Quellenaudits aus.
- Führen Sie `python3 Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root . --self-test` und anschließend den Repositoryscan aus.
- Prüfen Sie die Commit Message mit `Code/Tests/Static/930_Validate_Commit_Message.py` im zutreffenden Delivery Mode.
- Erzeugen Sie betroffene Installer aus den kanonischen Einzeldateien neu und aktualisieren Sie abhängige Beispiele, Inventare und Referenzen.
- Wählen Sie funktionale Tests ausschließlich gemäß `Documentation/Quality/CI_Test_Strategy.md`. Eine gewöhnliche Änderung verlangt keinen pauschalen Lauf auf SQL Server 2019, 2022 und 2025.
- Aktualisieren Sie Laufzeitevidenz nur für tatsächlich ausgeführte Kombinationen. Compatibility-Level-Läufe dürfen nicht als native Engine-Nachweise ausgewiesen werden.

## Maßgebliche Fortsetzungsquellen

- `AGENTS.md`
- `AI_Metadata/PROJECT_CONTEXT.md`
- `Documentation/Quality/CI_Test_Strategy.md`
- `Documentation/Quality/CI_Impact_Selection.md`
- `Documentation/Quality/Test_Matrix.md`
- `Documentation/Architecture/TSQL_SCENARIO_ORCHESTRATION.md`
