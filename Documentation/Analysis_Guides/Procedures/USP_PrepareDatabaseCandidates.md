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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Datenbanken gehören tatsächlich zum Cross-Database-Auftrag und dürfen sicher verarbeitet werden?

### Technischer Hintergrund

Die Procedure bildet aus exakten Namen oder Pattern einen stabilen Kandidatenscope. Sie liest Datenbankstatus aus Systemkatalogen, berücksichtigt Systemdatenbanken, Zugriffsregeln, Online-/User-Access-Zustand und explizite Auswahl. Sie stellt den Scope über eine Temp-Tabelle für aufrufende Module bereit.

### Datenkette

`master.sys.databases`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Momentaufnahme der Datenbankliste. Zwischen Kandidatenermittlung und späterer dynamischer Abfrage kann eine Datenbank offline gehen, failovern oder gelöscht werden.

### Bewertung und Gegenprobe

Explizit angeforderte, aber ausgeschlossene Datenbanken müssen als fehlende Evidenz dokumentiert werden. Eine Analyse über neun von zehn angeforderten Datenbanken ist nicht automatisch eine vollständige Entwarnung.

### Typische Fehlinterpretation

`@MaxDatenbanken`, Pattern und explizite Liste dürfen nicht stillschweigend als derselbe Auftrag behandelt werden. Ein Partialstatus ist fachlich relevant.

### Folgeanalyse

Warnings und OUTPUT-Status zusammen mit jedem Cross-Database-Resultset lesen.

[Technische Detailbeschreibung](../01_Common.md#3-monitorusp_preparedatabasecandidates)
