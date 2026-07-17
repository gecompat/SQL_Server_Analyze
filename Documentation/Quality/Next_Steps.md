# Nächste Arbeitsschritte

Stand: 2026-07-17

Der aktuelle Gesamtstand ist nach Angabe des Projektverantwortlichen vollumfänglich real getestet. Die im Test gefundenen Korrekturen sind enthalten. Der statische Repository-, API-, Named-Argument-, Block- und Installer-Audit ist ebenfalls `PASS`.

Nächste sinnvolle Schritte:

1. Die tatsächlich verwendete Testumgebung als Testprotokoll dokumentieren: SQL-Server-Version, Edition, Betriebssystem, Compatibility Level, Collation und Berechtigungen.
2. Für jede zusätzlich unterstützte Zielmatrix `Code/Tests/Integration/110_Smoke_Test.sql`, `163_Parameter_API_Vertrag.sql` und `165_Filter_Output_Contract.sql` ausführen.
3. Query-Store-Ranglisten mit mehreren großen Datenbanken auf globale Korrektheit sowie I/O- und CPU-Verhalten prüfen.
4. Memory-Grant-Prozentwerte unter Default Pool und konfiguriertem Resource Governor anhand kontrollierter Grants verifizieren.
5. `USP_CurrentRequests` mit Ad-hoc-Batch, Stored Procedure, verschachteltem RPC und wartendem Request gegen Offset, Zeilenbereich, Modulauflösung und Input Buffer validieren.
6. Große Modultexte mit `@MaxSqlTextZeichen = 4000` und `0` auf Kürzungskennzeichen und vollständige Ausgabe prüfen.
7. CONSOLE-Projektionen in SSMS beziehungsweise ADS visuell prüfen und Frontend-Consumer gegen JSON-Schema-Version 1 testen.
8. Nach dokumentierter Zielmatrix den Stand als Release-Kandidat kennzeichnen und die Frameworkversion entsprechend der gewählten Releasepolitik erhöhen.
