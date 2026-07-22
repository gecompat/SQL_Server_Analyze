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
