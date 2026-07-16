# Bekannte Restpunkte

- Der reale Compiletest des vorherigen Standes hat konkrete Fehler offengelegt; diese sind in `1.0.0-api.3` korrigiert. Der korrigierte Gesamtinstaller ist erneut vollständig auf SQL Server 2019, 2022 und 2025 auszuführen.
- Der installierte Katalogtest `163_Parameter_API_Vertrag.sql` ist nach jeder Zielinstallation auszuführen; im gelieferten Projekt konnte nach der Korrektur mangels SQL-Server-Instanz nur statisch geprüft werden.
- Importierte Wait-Beschreibungen mit `DescriptionQuality = IMPORTED_REVIEW_REQUIRED` sollten sukzessive fachlich kuratiert werden.
- Phase 7 liefert überwiegend Inventar- und Momentaufnahmen; zeitbasierte CPU-, NUMA- und Memory-Trends sind bewusst nicht Bestandteil dieses Ad-hoc-Pakets.
- DWH-/ETL-spezifische Adapter bleiben zurückgestellt.

- In `1.0.0-api.4` wurde die Aliasqualifizierung in `monitor.USP_CurrentRequests` korrigiert. Ein erneuter realer Compile-/Laufzeittest bleibt erforderlich.

<!-- BEGIN STATEMENT_CONTEXT_REST -->
- Die Offset-/Modul-/Input-Buffer-Erweiterungen wurden statisch geprüft, aber mangels SQL-Server-Instanz noch nicht real auf SQL Server 2019, 2022 und 2025 kompiliert und ausgeführt.
- Die optionale Ausgabe des tatsächlichen Ausführungsplans bleibt bewusst außerhalb des Defaultpfads; Plan-XML kann groß und die Abfrage des Plans ressourcenintensiv sein.
<!-- END STATEMENT_CONTEXT_REST -->
