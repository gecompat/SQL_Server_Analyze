# Nächste Arbeitsschritte

Stand: 2026-07-16

1. Den korrigierten Gesamtinstaller auf einer isolierten SQL-Server-2019-Instanz vollständig neu ausführen; bereits teilweise angelegte Objekte dürfen durch `CREATE OR ALTER` beziehungsweise idempotente DDL erneut verarbeitet werden.
2. Die vollständige Meldungsausgabe sichern. Treten weitere Compilefehler auf, sind sie vor funktionalen Smoke Tests zu korrigieren.
3. Anschließend `18_Qualitaetssicherung/110_Smoke_Test.sql` und `18_Qualitaetssicherung/163_Parameter_API_Vertrag.sql` ausführen.
4. Denselben Test auf SQL Server 2022 durchführen; insbesondere `VIEW SERVER PERFORMANCE STATE` und `VIEW DATABASE PERFORMANCE STATE` prüfen.
5. SQL Server 2025 mit Compatibility Level 170 testen; Regex-Pfade gegen LIKE- und exakte Listenfilter vergleichen.
6. Query-Store-Ranglisten mit mehreren großen Datenbanken auf globale Korrektheit und IO/CPU prüfen.
7. Memory-Grant-Prozentwerte unter Default Pool und konfiguriertem Resource Governor anhand kontrollierter Grants verifizieren.
8. CONSOLE-Projektionen in SSMS/ADS visuell prüfen und Identifier nur an tatsächlich erforderlichen fachlichen Blockgrenzen wiederholen.
9. Frontend-Consumer gegen JSON-Schema-Version 1 und benannte Arrays testen.

Der statische Repository-, API-, Named-Argument-, Block- und Installer-Audit ist PASS. Ein erneuter realer Compiletest des korrigierten Standes ist noch offen.

<!-- BEGIN NEXT_AFTER_STATEMENT_CONTEXT -->
1. Gesamtinstaller real auf SQL Server 2019 kompilieren und Smoke Tests ausführen.
2. Dieselben Compile-/Laufzeittests auf SQL Server 2022 und SQL Server 2025 wiederholen.
3. `USP_CurrentRequests` mit Ad-hoc-Batch, Stored Procedure, verschachteltem RPC und wartendem Request gegen Offset, Zeilenbereich, Modulauflösung und Input Buffer validieren.
4. Große Modultexte mit `@MaxSqlTextZeichen = 4000` und `0` auf Kürzungskennzeichen und vollständige Ausgabe prüfen.
5. Erst nach realem Test den Vertragsstand als Release-Kandidat markieren.
<!-- END NEXT_AFTER_STATEMENT_CONTEXT -->
