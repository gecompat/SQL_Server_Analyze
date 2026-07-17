# Nächste Arbeitsschritte

Stand: 2026-07-17

Der aktuelle Gesamtstand ist nach Angabe des Projektverantwortlichen vollumfänglich real getestet. Die im Test gefundenen Korrekturen sind enthalten. Der statische Repository-, API-, Named-Argument-, Block- und Installer-Audit ist ebenfalls `PASS`.

Die vollständige Herleitung, Priorisierung und die False-Positive-Grenzen stehen in `Documentation/Research/Special_Case_Gap_Analysis.md`. Der maschinenlesbare Umsetzungsbacklog steht in `Metadata/Quality/Special_Case_Gap_Backlog.csv`.

Nächste sinnvolle Schritte:

1. Den neuen Datenschutzvertrag als Liefer-Gate operationalisieren: Runtime-Ausgaben bleiben diagnostisch vollständig, reale Werte werden jedoch in Dokumenten, Tests, Audits, Beispielen und ZIP-Inhalten blockiert; unklare Funde lösen eine Nachfrage aus.
2. P0-Welle umsetzen: `USP_DatabaseIntegrityAnalysis`, `USP_DatabaseCapacityAnalysis`, `USP_CriticalEngineEvents` und `USP_PerformanceCounters`.
3. P1-Ursachenauflösung umsetzen: Intelligent Query Processing, interne Contention, Buffer Pool, Backupketten und korrelierte Findings.
4. Danach Schema-/Designkorrektheit, tiefe AG-Diagnose sowie Agent-/Alert-/Database-Mail-Auswertung ergänzen.
5. Spezialmodule nur nach Featureinventur aktivieren: In-Memory OLTP, Temporal, Service Broker, Full-Text, CDC/Change Tracking/Replikation, Verschlüsselung und externe Features.
6. Snapshot-, Baseline- und Anomaliefunktionen als eigenes Paket behandeln und erst nach Datenschutz-, Retention-, Berechtigungs-, Lösch- und Größenentscheidung implementieren.
7. Die tatsächlich verwendete Testumgebung als Testprotokoll dokumentieren: SQL-Server-Version, Edition, Betriebssystem, Compatibility Level, Collation und Berechtigungen.
8. Für jede unterstützte Zielmatrix `Code/Tests/Integration/110_Smoke_Test.sql`, `163_Parameter_API_Vertrag.sql` und `165_Filter_Output_Contract.sql` ausführen; neue Module erhalten zusätzlich Capability-, Leerzustands-, Positiv-, Last-, Reset- und Datenschutztests.
9. Query-Store-Ranglisten, Memory-Grant-Prozentwerte, Statementkontext, Volltextkürzung, CONSOLE-Projektionen und JSON-Schema weiterhin mit kontrollierten Szenarien verifizieren.
10. Erst nach dokumentierter Zielmatrix den Stand als Release-Kandidat kennzeichnen und die Frameworkversion entsprechend der gewählten Releasepolitik erhöhen.
