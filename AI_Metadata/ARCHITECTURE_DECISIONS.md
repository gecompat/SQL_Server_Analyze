# Architekturentscheidungen

1. Installationsdatenbank wird über den Platzhalter `[DeineDatenbank]` in jedem SQL-Skript explizit gewählt.
2. Das Schema lautet `[monitor]`.
3. Öffentliche API-Namen und Resultsetspalten sind exakt case-sensitiv.
4. Steuerwerte werden getrimmt und in eine kanonische Großschreibung überführt.
5. Gleiche Funktionalität verwendet überall denselben Parameternamen, Datentyp und dieselbe Semantik.
6. Ergebnisumfang, Analyseaufwand und Datenbank-Scope sind getrennte Budgets.
7. RAW-, CONSOLE- und JSON-Ausgabe basieren auf derselben kanonischen Datenbasis.
8. Datenbank-, Schema-, Objekt- und weitere exakte Filter können Mehrfachwerte über bracket-aware Pipe-Listen erhalten.
9. Regex ist ein optionales versionsabhängiges Feature und wird nie stillschweigend in LIKE umgedeutet.
10. Query Store ist datenbankbezogen; globale Top-N-Ausgaben verwenden lokale Kandidatenmengen und ein abschließendes globales Ranking.
11. Memory Grants werden mit Workload Group, Resource Pool, Resource Semaphore und fachlich benannten Prozentkennzahlen korreliert.
12. Historische, umgebungsspezifische Quellen werden nicht im Repository archiviert.
13. Git ist die maßgebliche Versions- und Integritätsquelle; ein zusätzliches per-Datei-Hash-Manifest wird nicht gepflegt.
14. Der Platzhalter `[DeineDatenbank]` darf nur als einleitender `USE`-Kontext oder in ausdrücklich gekennzeichneten Beispielen vorkommen, nie als ausführbares internes Stringliteral.
15. Historische Quellenanalysen werden ausschließlich abstrahiert als Systemquellen-, Capability-, Abhängigkeits- und Risikokatalog migriert.
