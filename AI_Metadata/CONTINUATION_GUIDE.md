# Fortsetzungshinweise

## Vor jeder Änderung

- Prüfen Sie repositoryweit die case-sensitive Namenskonsistenz.
- Aktualisieren Sie ein Einzelobjekt und alle daraus generierten Installer gemeinsam.
- Führen Sie keine konkrete Installationsdatenbank in Code oder Dokumentation ein.
- Das Repository-Liefergate darf Resultsets, OUTPUT-Parameter sowie RAW-, CONSOLE-, TABLE- und JSON-Ausgaben nicht anonymisieren oder fachlich reduzieren.
- Reale Benutzer-, Kunden-, Firmen-, Organisations-, Umgebungs- oder Fachwerte und proprietäre interne Strukturen dürfen niemals aus Screenshots, Hardcopys, Chats, Uploads, Skripten, Logs oder Diagnoseausgaben in Repository-, GitHub-, Dokumentations-, Test- oder Downloadartefakte übernommen werden.
- Beispiele und gespeicherte Testergebnisse verwenden ausschließlich eindeutig synthetische, generische Werte und bilden keine reale interne Struktur nach.
- Halten Sie bei einem uneindeutigen Artefaktwert vor dem Schreiben an und fragen Sie nach einer nicht sensitiven Alternative; eine Zustimmung hebt das Repositoryverbot nicht auf.

## Nach jeder Änderung

- Führen Sie den statischen API-, Portabilitäts- und Quellenaudit aus.
- Führen Sie `python3 Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root . --self-test` und anschließend `python3 Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root .` aus.
- Führen Sie vor einer ZIP-Auslieferung zusätzlich `python3 Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root . --archive-path <ZIP>` gegen den vollständigen Lieferumfang aus; gefundene Inhalte werden niemals in der Prüfausgabe wiedergegeben.
- Legen Sie den Lieferweg vor dem Commit fest und führen Sie `python3 Code/Tests/Static/930_Validate_Commit_Message.py --repository-root . --self-test` lokal aus.
- Stellen Sie bei manueller Repositorypflege über ein downloadbares ZIP eine nicht leere, exakt einzeilige Commit Message ohne Zeilenumbruch bereit und prüfen Sie den neuen Commit mit `--delivery-mode MANUAL_ZIP`.
- Bei einem direkten Commit und Push durch die KI darf die Commit Message aus Betreff und optionalem mehrzeiligem Body bestehen; prüfen Sie den neuen Commit mit `--delivery-mode DIRECT_GIT` und lassen Sie ihn anschließend durch das Actions-Gate validieren.
- eine automatisch erzeugte mehrzeilige Squash-Message ist im direkten Git-Weg zulässig und erfordert weder leeren Korrekturcommit noch History-Rewrite;
- Erzeugen Sie die Installer aus den kanonischen Einzeldateien neu.
- Aktualisieren Sie Beispielaufrufe und Referenz.
- Kompilieren Sie auf SQL Server 2019, 2022 und 2025 und führen Sie die Smoke-Tests aus.
- Aktualisieren Sie `AI_Metadata/Internal_Documentation/Quality/Migration_Audit_History.json` beziehungsweise einen neuen Release-Audit.

- Regenerieren Sie kein SHA- oder Dateimanifest; Git und die maschinenlesbaren Fachinventare sind maßgeblich.

## Maßgeblicher Ausgangsstand

Der aktuelle Architekturstand ergänzt den frameworkweiten Datenbank-, CONSOLE- und benannten TABLE-Vertrag. `187_Table_Output_Runtime_Contract.sql`, `188_Framework_Output_Pilot_Runtime.sql` und `189_Framework_Output_Runtime_Contract.sql` prüfen den Mehrfach-Export, die Pilotmodule sowie die öffentliche Frameworkgrenze im 34-Suite-Gate auf SQL Server 2019, 2022 und 2025. P3 bleibt getrennt: SC-023 benötigt ausdrückliche Persistenzentscheidungen, SC-024 eine externe Komponente und SC-025 eine autorisierte isolierte Restore-/Hostausführung.

Die priorisierte Ausbauplanung steht in `AI_Metadata/Internal_Documentation/Research/Special_Case_Gap_Analysis.md`; der maschinenlesbare Backlog steht in `Metadata/Quality/Special_Case_Gap_Backlog.csv`.

## Änderungen 2026-07-25 (Collation-Portabilität und Framework-Verbesserungen)

### Collation-Architektur

- `Code/00_Setup/000_Preflight_und_Schema.sql` (v2.1.0): Collation-Prüfung von THROW auf RAISERROR severity 10 geändert. Die Installation wird bei abweichender Collation nicht mehr blockiert, sondern warnt.
- Das Framework verwendet durchgängig explizite `COLLATE SQL_Latin1_General_CP1_CS_AS`-Klauseln und funktioniert grundsätzlich auf beliebigen Collations. Getestet und garantiert bleibt ausschließlich `SQL_Latin1_General_CP1_CS_AS`.
- Dokumentation angepasst: `README.md`, `Documentation/Reference/Installation.md`, `AI_Metadata/PROJECT_CONTEXT.md`.

### Neue CI-Lane

- `.github/workflows/collation-portability-validation.yml`: SQL Server 2022 mit `Latin1_General_CI_AS` auf GitHub-hosted Ubuntu. Testet Installation (mit erwarteten Warnungen), Smoke Test, Filter-TVFs und Analysis Navigator. Keine Abhängigkeit zum Windows Self-Hosted Runner.

### Neue Procedure

- `Code/09_VersionAdaptive/500_USP_FrameworkUsageFromQueryStore.sql` (v1.0.0): Liest aus dem Query Store der Installationsdatenbank welche `monitor.*`-Procedures mit welcher Häufigkeit aufgerufen wurden. Zero-Footprint, read-only, keine zusätzlichen Objekte.

### Neue Dokumentation

- `Documentation/Reference/Scope_and_Limitations.md`: Aggregierte Übersicht was das Framework tut und ausdrücklich nicht tut. Ersetzt das Suchen in einzelnen Modulheadern.
- `Metadata/Inventory/Module_Maturity.csv`: Maschinenlesbare Reifegrad-Matrix aller Module mit CI-Evidenz, Lab-Szenarien und Dokumentationsstand.
- `Lab/Scenarios/LEARNING_PATH.md`: Pädagogische Lesereihenfolge für alle 39 Lab-Szenarien in 5 Stufen (Einsteiger → Spezialisten).

### Offene Folgeaufgaben

- `USP_FrameworkUsageFromQueryStore` in den Installer (`Install_All.sql`) und in die Referenzdokumentation aufnehmen.
- Erste Laufzeitevidenz der Collation-Portability-Lane auf GitHub sammeln; bei Fehlern implizite Collation-Abhängigkeiten korrigieren.
- `Module_Maturity.csv` bei neuen Modulen oder geänderten Evidenznachweisen aktualisieren.
- Windows Self-Hosted Runner: SQL-Server-Runtime-Tests ergänzen (nach externer Vorbereitung).
