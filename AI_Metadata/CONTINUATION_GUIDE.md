# Fortsetzungshinweise

## Vor jeder Änderung

- Repositoryweit auf case-sensitive Namenskonsistenz prüfen.
- Einzelobjekt und alle daraus generierten Installer gemeinsam aktualisieren.
- Keine konkrete Installationsdatenbank in Code oder Dokumentation einführen.
- Das Repository-Liefergate darf Resultsets, OUTPUT-Parameter sowie RAW-, CONSOLE- und JSON-Ausgaben nicht anonymisieren oder fachlich reduzieren.
- Reale Benutzer-, Kunden-, Firmen-, Organisations-, Umgebungs- oder Fachwerte und proprietäre interne Strukturen dürfen niemals aus Screenshots, Hardcopys, Chats, Uploads, Skripten, Logs oder Diagnoseausgaben in Repository-, GitHub-, Dokumentations-, Test- oder Downloadartefakte übernommen werden.
- Beispiele und gespeicherte Testergebnisse verwenden ausschließlich eindeutig synthetische, generische Werte und bilden keine reale interne Struktur nach.
- Bei einem uneindeutigen Artefaktwert vor dem Schreiben anhalten und nach einer nicht sensitiven Alternative fragen; eine Zustimmung hebt das Repositoryverbot nicht auf.

## Nach jeder Änderung

- statischen API-, Portabilitäts- und Quellen-Audit ausführen;
- `python3 Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root . --self-test` und anschließend `python3 Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root .` ausführen;
- vor einer ZIP-Auslieferung zusätzlich `python3 Code/Tests/Static/910_Validate_Repository_Privacy.py --repository-root . --archive-path <ZIP>` gegen den vollständigen Lieferumfang ausführen; gefundene Inhalte werden niemals in der Prüfausgabe wiedergegeben;
- ausschließlich eine nicht leere, exakt einzeilige Commit Message verwenden; `python3 Code/Tests/Static/930_Validate_Commit_Message.py --repository-root . --self-test` lokal ausführen und den neuen Commit anschließend durch das Actions-Gate prüfen lassen;
- Installer aus den kanonischen Einzeldateien neu erzeugen;
- Beispielaufrufe und Referenz aktualisieren;
- auf SQL Server 2019, 2022 und 2025 kompilieren und Smoke-Tests ausführen;
- `Metadata/Quality/Migration_Audit.json` beziehungsweise einen neuen Release-Audit aktualisieren.

- Kein SHA-/Dateimanifest regenerieren; Git und die maschinenlesbaren Fachinventare sind maßgeblich.

## Maßgeblicher Ausgangsstand

Der Stand `1.1.0-special.9` schließt die lokalen P2-Module einschließlich Verschlüsselungslebenszyklus und Wartungsoperationen. `167_Special_Case_API_Contract.sql` prüft die statische Grenze; `168_Special_Case_Runtime_Contract.sql` wird in den versionsharten Actions-Gates auf SQL Server 2019, 2022 und 2025 ausgeführt. P3 bleibt getrennt: SC-023 benötigt ausdrückliche Persistenzentscheidungen, SC-024 eine externe Komponente und SC-025 eine autorisierte isolierte Restore-/Hostausführung.

Die priorisierte Ausbauplanung steht in `Documentation/Research/Special_Case_Gap_Analysis.md`; der maschinenlesbare Backlog steht in `Metadata/Quality/Special_Case_Gap_Backlog.csv`.
