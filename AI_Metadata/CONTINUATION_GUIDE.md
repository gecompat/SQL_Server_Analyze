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

- statischen API-, Portabilitäts-, Quellen- und Datenschutz-Audit ausführen;
- Datenschutzprüfung auf Repositoryänderungen, GitHub-Inhalte und den vollständigen Lieferumfang anwenden, ohne gefundene sensitive Werte in der Prüfausgabe zu vervielfältigen;
- Installer aus den kanonischen Einzeldateien neu erzeugen;
- Beispielaufrufe und Referenz aktualisieren;
- auf SQL Server 2019, 2022 und 2025 kompilieren und Smoke-Tests ausführen;
- `Metadata/Quality/Migration_Audit.json` beziehungsweise einen neuen Release-Audit aktualisieren.

- Kein SHA-/Dateimanifest regenerieren; Git und die maschinenlesbaren Fachinventare sind maßgeblich.

## Maßgeblicher Ausgangsstand

Der real getestete Gesamtstand vom 17.07.2026 ist die kanonische Basis. Künftige Änderungen müssen die Tests `110_Smoke_Test.sql`, `163_Parameter_API_Vertrag.sql` und `165_Filter_Output_Contract.sql` berücksichtigen.

Die priorisierte Ausbauplanung steht in `Documentation/Research/Special_Case_Gap_Analysis.md`; der maschinenlesbare Backlog steht in `Metadata/Quality/Special_Case_Gap_Backlog.csv`.
