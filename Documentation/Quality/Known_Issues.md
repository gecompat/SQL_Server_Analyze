# Bekannte Restpunkte

Stand: 2026-07-17

Der vorliegende Gesamtstand wurde nach Angabe des Projektverantwortlichen vollumfänglich real installiert, kompiliert und funktional getestet. Die während dieses Tests gefundenen Fehler wurden im gelieferten Stand korrigiert.

Verbleibende fachliche beziehungsweise betriebliche Punkte:

- Die genaue Testumgebung mit SQL-Server-Version, Edition, Betriebssystem, Compatibility Level und Berechtigungsumfang ist noch nicht als maschinenlesbare Testmatrix dokumentiert.
- Bei jeder weiteren Zielversion oder abweichenden Plattform sind Installer, Smoke Tests, Parametervertrag und `165_Filter_Output_Contract.sql` erneut auszuführen.
- Importierte Wait-Beschreibungen mit `DescriptionQuality = IMPORTED_REVIEW_REQUIRED` sollten sukzessive fachlich kuratiert werden.
- Phase 7 liefert überwiegend Inventar- und Momentaufnahmen; zeitbasierte CPU-, NUMA- und Memory-Trends sind bewusst nicht Bestandteil dieses Ad-hoc-Pakets.
- DWH-/ETL-spezifische Adapter bleiben zurückgestellt.
- Die optionale Ausgabe des tatsächlichen Ausführungsplans bleibt bewusst außerhalb des Defaultpfads; Plan-XML kann groß und die Abfrage des Plans ressourcenintensiv sein.
