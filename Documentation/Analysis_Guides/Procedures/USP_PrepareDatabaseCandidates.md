# [monitor].[USP_PrepareDatabaseCandidates]

**Bereich:** Common, interner Auswahlvertrag  
**Zweck:** Befüllt die vom Aufrufer bereitgestellte Datenbank-Kandidatenliste.

## Kein normaler Direktaufruf

Diese interne Procedure setzt exakt definierte lokale Temp-Tabellen voraus. Deren procedurebezogene Namen werden mit `@CandidateTable` und optional `@WarningTable` übergeben. Sie liefert keine normalen Analyse-Resultsets; die aufrufende Procedure ist der öffentliche Einstieg.

## Eine Zeile bedeutet

Eine Zeile in der über `@CandidateTable` benannten Tabelle entspricht einer für den aktuellen Lauf akzeptierten Datenbank. Warnzeilen in `@WarningTable` dokumentieren angeforderte, aber nicht nutzbare Scopes.

## So lesen

Kandidaten, Warnungen und OUTPUT-Status gemeinsam lesen. Prüfen, ob jede ausdrücklich angeforderte Datenbank tatsächlich in der Kandidatenliste enthalten ist.

## Warum kann das problematisch sein?

Eine offline, unsichtbare oder unzulässige Datenbank fehlt in der Fachanalyse. Wird die Warnung ignoriert, kann ein unvollständiger Scope fälschlich als Entwarnung erscheinen.

## Wann ist es kein Problem?

Eine große sichtbare Datenbankmenge ist allein kein Deep-Pfad. Die Auswahl wird
nicht vorab gekürzt; erst die tatsächlich aktivierte Analyseklasse entscheidet,
ob `@HighImpactConfirmed = 1` erforderlich ist.

## Beispiel und Folgeschritt

Zwei Datenbanken werden angefordert, eine ist offline. Das Fachergebnis enthält nur die online Datenbank; die fehlende Datenbank muss als nicht untersuchter Scope dokumentiert werden.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Datenbanken gehören tatsächlich zum Cross-Database-Auftrag und dürfen sicher verarbeitet werden?

### Technischer Hintergrund

Die Procedure bildet aus exakten Namen oder Pattern einen stabilen Kandidatenscope. Ohne explizite Einschränkung liefert sie alle sichtbaren, zugreifbaren und online befindlichen Benutzerdatenbanken. Es gibt keinen CURRENT-Scope und keine Vorabbegrenzung. Systemdatenbanken sind opt-in. Die Procedure prüft zusätzlich die vom Aufrufer tatsächlich aktivierte Analyseklasse und beendet einen bestätigungspflichtigen Pfad vor dem teuren Fachzugriff mit `HIGH_IMPACT_CONFIRMATION_REQUIRED`.

### Datenkette

`master.sys.databases`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Momentaufnahme der Datenbankliste. Zwischen Kandidatenermittlung und späterer dynamischer Abfrage kann eine Datenbank offline gehen, failovern oder gelöscht werden.

### Bewertung und Gegenprobe

Explizit angeforderte, aber ausgeschlossene Datenbanken müssen als fehlende Evidenz dokumentiert werden. Eine Analyse über neun von zehn angeforderten Datenbanken ist nicht automatisch eine vollständige Entwarnung.

### Typische Fehlinterpretation

Pattern und explizite Liste sind alternative Einschränkungen und dürfen nicht
gleichzeitig gesetzt werden. Eine explizit nicht verfügbare Datenbank bleibt als
Warning sichtbar; sie darf nicht als erfolgreich untersuchter Scope gelten.

### Folgeanalyse

Warnings und OUTPUT-Status zusammen mit jedem Cross-Database-Resultset lesen.

[Technische Detailbeschreibung](../01_Common.md#3-monitorusp_preparedatabasecandidates)
