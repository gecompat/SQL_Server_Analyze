# Fortsetzungshinweise

## Vor jeder Änderung

- Repositoryweit auf case-sensitive Namenskonsistenz prüfen.
- Einzelobjekt und alle daraus generierten Installer gemeinsam aktualisieren.
- Keine konkrete Installationsdatenbank in Code oder Dokumentation einführen.
- Keine realen Benutzer-, Organisations- oder Fachobjektnamen in Beispiele übernehmen.

## Nach jeder Änderung

- statischen API-, Portabilitäts-, Quellen- und Datenschutz-Audit ausführen;
- Installer aus den kanonischen Einzeldateien neu erzeugen;
- Beispielaufrufe und Referenz aktualisieren;
- auf SQL Server 2019, 2022 und 2025 kompilieren und Smoke-Tests ausführen;
- `Metadata/Quality/Migration_Audit.json` beziehungsweise einen neuen Release-Audit aktualisieren.

- Kein SHA-/Dateimanifest regenerieren; Git und die maschinenlesbaren Fachinventare sind maßgeblich.

## Maßgeblicher Ausgangsstand

Der real getestete Gesamtstand vom 17.07.2026 ist die kanonische Basis. Künftige Änderungen müssen die Tests `110_Smoke_Test.sql`, `163_Parameter_API_Vertrag.sql` und `165_Filter_Output_Contract.sql` berücksichtigen.
