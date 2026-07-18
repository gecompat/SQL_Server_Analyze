# Vertrag für ein späteres Snapshot- und Baseline-Paket

Stand: 2026-07-18  
Backlog: SC-023  
Status: `DESIGN_READY_APPROVAL_REQUIRED`

## Ziel und harte Grenze

Ein späteres, getrenntes Paket darf ausgewählte numerische und kategorische Diagnosewerte über die Zeit speichern. Der heutige Frameworkkern bleibt zustandslos. Dieses Dokument autorisiert weder Tabellen, Jobs, Datenbankänderungen noch eine konkrete Aufbewahrung.

Persistenz ist ein neuer Datenfluss und benötigt vor jeder Implementierung eine ausdrückliche Entscheidung. Laufzeit-Resultsets werden nicht automatisch als speichergeeignet behandelt.

## Vor Implementierung zu bestätigende Entscheidungen

| Entscheidung | Erforderliche Festlegung | Ohne Festlegung |
|---|---|---|
| Speicherort | getrennte Datenbank und verantwortlicher Betriebskontext | keine Persistenz |
| Erlaubte Felder | Positivliste stabiler Codes, UTC-Zeitpunkte und numerischer Messwerte | keine Übernahme ganzer JSON-/RAW-Resultsets |
| Verbotene Felder | Identitäten, Namen, freie Texte, SQL/Pläne, Pfade, Objektstrukturen und Umgebungsmetadaten | Liefergate blockiert |
| Frequenz | minimales Messintervall je Modul | kein Scheduler |
| Aufbewahrung | feste Retention je Datenklasse | keine Tabelle |
| Größenbudget | harte Obergrenze und Verhalten bei Erreichen | keine Sammlung |
| Löschung | Owner, Intervall, Nachweis und Fehlerweg | keine Sammlung |
| Reset-Epochen | Serverstart, Counterreset und Versionswechsel | keine Delta-/Trendbehauptung |
| Rechte | dedizierter Ausführer und minimale INSERT/DELETE-/Leserechte | keine Rechteänderung |
| Export | gesonderte Freigabe je Zielformat und Feldliste | kein Downloadartefakt |

## Erlaubter Kernvertrag

Nach Freigabe darf ein separates Paket ausschließlich explizit gemappte Felder übernehmen, beispielsweise `MetricCode`, `MetricValue`, `CollectedAtUtc`, `SourceVersion`, `ResetEpoch` und generische Statuscodes. Freie Child-JSONs, Fehlertexte und technische Scope-Namen werden nicht durchgereicht.

Jeder Sammler muss:

1. Quelle, Schema- und Vertragsversion prüfen;
2. nur eine Positivliste lesen;
3. unerwartete Felder ignorieren und den Lauf generisch ablehnen;
4. Retention und Größenbudget transaktional kontrollieren;
5. Restart-/Resetgrenzen vor Delta- oder Trendberechnung beachten;
6. niemals Rechte, Jobs oder Tabellen außerhalb des getrennten Pakets verändern.

## Abnahmekriterien

- UTC-, Restart-, Reset-, Retention-, Purge-, Größenlimit- und Versionswechseltests bestehen.
- Ein absichtlich hinzugefügtes verbotenes Feld stoppt die Persistenz ohne den gefundenen Wert zu protokollieren.
- Ein partieller Childstatus erzeugt keinen scheinbar vollständigen Trend.
- Löschen ist begrenzt, wiederholbar und nachweisbar.
- Alle Fixtures sind offensichtlich synthetisch und enthalten keine realen Namen oder Strukturen.

## Aktueller nächster Schritt

Der Benutzer beziehungsweise die verantwortliche Betriebsstelle bestätigt die zehn Entscheidungen der Tabelle. Erst danach darf ein eigenes persistentes Paket geplant werden.
