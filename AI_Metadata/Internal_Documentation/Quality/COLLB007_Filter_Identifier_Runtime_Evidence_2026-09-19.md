# COLL-B007: Filter Identifier Runtime Evidence

**Date:** 19 September 2026  
**Scope:** `COLL-001`, `COLL-B007`, `[monitor].[USP_PrepareNameFilters]`  
**Result:** Runtime contract added

`Code/Tests/Integration/166_Filter_Identifier_Collation_Runtime_Contract.sql` passes four bracket-aware synthetic names through the central filter procedure: two names differ only by case and two differ by accent. The contract requires `AVAILABLE`, preserves four rows and verifies four distinct values under `SQL_Latin1_General_CP1_CS_AS`.

The contract covers central filter parsing and duplicate validation. Individual cross-database consumers and supplementary-character fixtures remain outside this evidence.

## Ergänzung vom 26. Oktober 2026: Datenbankprincipal-Consumer

[PR #467](https://github.com/gecompat/SQL_Server_Analyze/pull/467) ergänzt im
bestehenden Vertrag `ServerHealth/136_DatabasePrincipal_Runtime_Contract.sql`
einen einzelnen bracket-quotierten Datenbanknamen mit Pipe. Die positive
Auswahl muss genau die bekannte numerische Datenbank-ID liefern. Eine nur im
ersten Zeichen anders geschriebene Groß-/Kleinschreibung muss
`DATABASE_UNAVAILABLE`, einen leeren `databaseContext` und die entsprechende
`SELECTION`-Quellenwarnung liefern. Die bestehende Zwei-Datenbank-Auswahl wird
anschließend wiederhergestellt; es entstehen keine weiteren Testdatenbanken.

Der Head `1f1825ff` und Merge `e68cc4cf` besitzen denselben Baum. Der
unabhängige Review enthält keine offenen P1-/P2-Befunde. Alle sieben
Head-Prüfungen und alle vier Main-Prüfungen bestehen. Der kanonische Selector
wählt genau diesen SQL-2025-Vertrag; Runnererzeugung und erfolgreicher
Ausführungsschritt sind im
[Head-Lauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40363150981)
und im getrennten
[Main-Lauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40365613323)
belegt. Ein gesonderter Erfolgsstdout der beiden Assertions ist nicht
exportiert und wird nicht als separat erfasster PASS-Marker behauptet.

Lokal erfolgte keine SQL-Ausführung. Der Fall erweitert weder die garantierte
Collation noch native Versions- oder Compatibility-Level-Nachweise. Weitere
Consumer, Akzentvarianten und ergänzende Unicodefälle bleiben außerhalb
dieses begrenzten Nachweises.
