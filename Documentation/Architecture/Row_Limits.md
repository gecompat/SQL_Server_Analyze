# Verbindliche Zeilenbegrenzung

Stand: 2026-07-20

- Öffentliche Ergebnisbegrenzung heißt ausschließlich `@MaxZeilen`.
- Standardaufrufe sind konservativ begrenzt.
- `@MaxZeilen = NULL` oder `0` liefert technisch alle fachlich passenden Zeilen.
- Negative Werte liefern `INVALID_PARAMETER`, bevor teure Datenzugriffe beginnen.
- `TOP` besitzt immer ein fachlich stabiles `ORDER BY`.
- `@MaxAnalyseobjekte` bleibt ein eigenständiges Tiefenanalysebudget und darf nicht mit `@MaxZeilen` vermischt werden.
- Bei globalen Query-Store-Ranglisten wird je Quelldatenbank lokal `N+1` gelesen und anschließend global `TOP (N)` gebildet. Dadurch wird nicht der vollständige Query Store aller Datenbanken materialisiert.
- Datenbankkandidaten werden vor der globalen Bewertung oder Sortierung nicht willkürlich gekürzt.
