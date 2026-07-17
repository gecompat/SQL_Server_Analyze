# [monitor].[USP_PrepareDatabaseCandidates]

**Bereich:** Common, interner Auswahlvertrag  
**Zweck:** Befüllt die vom Aufrufer bereitgestellte Datenbank-Kandidatenliste.

## Kein normaler Direktaufruf

Diese interne Procedure setzt exakt definierte lokale Temp-Tabellen voraus und liefert keine normalen Analyse-Resultsets. Die aufrufende Procedure ist der öffentliche Einstieg.

## Eine Zeile bedeutet

Eine Zeile in `#DatabaseCandidates` entspricht einer für den aktuellen Lauf akzeptierten Datenbank. Warnzeilen dokumentieren angeforderte, aber nicht nutzbare Scopes.

## So lesen

Kandidaten, Warnungen und OUTPUT-Status gemeinsam lesen. Prüfen, ob jede ausdrücklich angeforderte Datenbank tatsächlich in der Kandidatenliste enthalten ist.

## Warum kann das problematisch sein?

Eine offline, unsichtbare oder unzulässige Datenbank fehlt in der Fachanalyse. Wird die Warnung ignoriert, kann ein unvollständiger Scope fälschlich als Entwarnung erscheinen.

## Wann ist es kein Problem?

`@MaxDatenbanken=1` schneidet eine explizite Liste nicht still ab. Explizit genannte Datenbanken werden als vollständiger Auftrag behandelt und Abweichungen gemeldet.

## Beispiel und Folgeschritt

Zwei Datenbanken werden angefordert, eine ist offline. Das Fachergebnis enthält nur die online Datenbank; die fehlende Datenbank muss als nicht untersuchter Scope dokumentiert werden.

[Technische Detailbeschreibung](../01_Common.md#3-monitorusp_preparedatabasecandidates)
