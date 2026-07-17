# Nächste Arbeitsschritte

Stand: 2026-07-17

Der vor der Spezialfallwelle liegende Basisstand wurde nach Angabe des Projektverantwortlichen real getestet. Die neue Version `1.1.0-special.1` ist implementiert und statisch zu prüfen; reale Matrixläufe sind noch nicht dokumentiert. `NOT_EXECUTED` in der Testmatrix darf nicht als Testnachweis interpretiert werden.

Die vollständige Herleitung, Priorisierung und die False-Positive-Grenzen stehen in `Documentation/Research/Special_Case_Gap_Analysis.md`. Der maschinenlesbare Umsetzungsbacklog steht in `Metadata/Quality/Special_Case_Gap_Backlog.csv`.

Abgeschlossen:

1. Repository-Datenschutzvertrag und Liefergate dokumentiert.
2. Dokumentierbare Ziel-Testmatrix angelegt.
3. P0: Integrität, Kapazität, Performance Counter und kritische Engine-Ereignisse implementiert.
4. P1 in der festgelegten Reihenfolge: IQP, interne Contention, Buffer Pool, Backupketten, Schema-/Designkorrektheit, tiefe Availability-Evidenz, Agent-/Alert-Monitoring und zuletzt normalisierte Findings implementiert.
5. Installer, Orchestratoren, Inventare, Hilfe, Beispiele, Referenz und statische Verträge erweitert.
6. Statischen Release-Audit unter `Metadata/Quality/Special_Case_Release_Audit.json` dokumentiert; Laufzeitstatus bleibt `NOT_EXECUTED`.

Nächste Freigabeschritte:

1. Gesamtinstaller auf SQL Server 2019, 2022 und 2025 gemäß `Test_Matrix.csv` kompilieren und installieren.
2. Pro Ziel `110_Smoke_Test.sql`, `163_Parameter_API_Vertrag.sql`, `165_Filter_Output_Contract.sql` und `167_Special_Case_API_Contract.sql` ausführen.
3. Für jedes neue Modul Capability-, Leerzustands-, Positiv-, Grenzwert-, Last-, Reset- und Berechtigungsfälle dokumentieren; reale Namen oder Strukturen nicht in die Nachweise übernehmen.
4. Kostenintensive opt-in Pfade separat testen: Page Details, Event-XML, Contention-Sample, Buffer-Pool-Verteilung, Schema-Design und breite Cross-Database-Auswahl.
5. Erst nach vollständiger, anonym dokumentierter Zielmatrix den Stand als Laufzeit-Release freigeben.
6. Weitere Spezialfeatures wie In-Memory OLTP, Temporal, Service Broker, Full-Text und Verschlüsselung erst danach als nächste Welle planen.
