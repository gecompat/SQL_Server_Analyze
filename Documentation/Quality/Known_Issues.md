# Bekannte Restpunkte

Stand: 2026-07-17

Der Basisstand vor der Spezialfallwelle wurde nach Angabe des Projektverantwortlichen vollumfänglich real installiert, kompiliert und funktional getestet. Die danach ergänzte Version `1.1.0-special.2` ist statisch geprüft, aber noch nicht durch dokumentierte Zielmatrixläufe als Laufzeit-Release nachgewiesen.

Verbleibende fachliche beziehungsweise betriebliche Punkte:

- Die Zielumgebungen sind maschinenlesbar definiert; konkrete Produktversion, Edition, Berechtigungsprofil, Commit-SHA und Ausführungsevidenz fehlen noch und stehen auf `NOT_EXECUTED`.
- Bei jeder weiteren Zielversion oder abweichenden Plattform sind Installer, Smoke Tests, Parametervertrag und `165_Filter_Output_Contract.sql` erneut auszuführen.
- Importierte Wait-Beschreibungen mit `DescriptionQuality = IMPORTED_REVIEW_REQUIRED` sollten sukzessive fachlich kuratiert werden.
- Phase 7 liefert überwiegend Inventar- und Momentaufnahmen; zeitbasierte CPU-, NUMA- und Memory-Trends sind bewusst nicht Bestandteil dieses Ad-hoc-Pakets.
- DWH-/ETL-spezifische Adapter bleiben zurückgestellt.
- Die optionale Ausgabe des tatsächlichen Ausführungsplans bleibt bewusst außerhalb des Defaultpfads; Plan-XML kann groß und die Abfrage des Plans ressourcenintensiv sein.
