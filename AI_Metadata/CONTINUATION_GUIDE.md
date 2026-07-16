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
