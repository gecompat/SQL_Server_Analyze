# Nächste Arbeitsschritte

Stand: 2026-07-17

Der vor der Spezialfallwelle liegende Basisstand wurde nach Angabe des Projektverantwortlichen real getestet. Die neue Version `1.1.0-special.2` ist implementiert und statisch geprüft; reale Matrixläufe sind noch nicht dokumentiert. `NOT_EXECUTED` in der Testmatrix darf nicht als Testnachweis interpretiert werden.

Die vollständige Herleitung, Priorisierung und die False-Positive-Grenzen stehen in `Documentation/Research/Special_Case_Gap_Analysis.md`. Der maschinenlesbare Umsetzungsbacklog steht in `Metadata/Quality/Special_Case_Gap_Backlog.csv`.

Abgeschlossen:

1. Repository-Datenschutzvertrag und Liefergate dokumentiert.
2. Dokumentierbare Ziel-Testmatrix angelegt.
3. P0: Integrität, Kapazität, Performance Counter und kritische Engine-Ereignisse implementiert.
4. P1 vollständig: IQP, interne Contention, Buffer Pool, Backupketten, Schema-/Designkorrektheit, begrenzte Statistikverteilung, tiefe Availability-Evidenz, Agent-/Alert-Monitoring und zuletzt normalisierte Findings implementiert.
5. Installer, Orchestratoren, Inventare, Hilfe, Beispiele, Referenz und statische Verträge erweitert.
6. Statischen Release-Audit unter `Metadata/Quality/Special_Case_Release_Audit.json` dokumentiert; Laufzeitstatus bleibt `NOT_EXECUTED`.
7. Reproduzierbaren SQLCMD-Runner für vier verbindliche Integrationsverträge und acht Bereichs-Smoke-Tests, eine rein synthetische Suite-Evidenzvorlage sowie ein Test-Runbook ergänzt.

Nächste Freigabeschritte:

1. Gesamtinstaller auf SQL Server 2019, 2022 und 2025 gemäß `Test_Matrix.csv` kompilieren und installieren.
2. Pro Ziel `Code/Tests/Run_Release_Gate.sql` im SQLCMD-Modus aus `Code/Tests` ausführen; der Runner startet `110`, `163`, `165` und `167` in fester Reihenfolge und bricht beim ersten SQL-Fehler ab.
3. Für jedes neue Modul Capability-, Leerzustands-, Positiv-, Grenzwert-, Last-, Reset- und Berechtigungsfälle dokumentieren; reale Namen oder Strukturen nicht in die Nachweise übernehmen.
4. Kostenintensive opt-in Pfade separat testen: Page Details, Event-XML, Contention-Sample, Buffer-Pool-Verteilung, Schema-Design, Statistikverteilung und breite Cross-Database-Auswahl.
5. Erst nach vollständiger, anonym dokumentierter Zielmatrix den Stand als Laufzeit-Release freigeben.
6. Weitere Spezialfeatures wie In-Memory OLTP, Temporal, Service Broker, Full-Text und Verschlüsselung erst danach als nächste Welle planen.
