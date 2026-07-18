# [monitor].[USP_InternalContentionAnalysis]

**Bereich:** Server Health  
**Zweck:** Analysiert Spinlocks, Latches und Hot Pages über ein begrenztes Sample.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InternalContentionAnalysis]
      @SampleSeconds = 5,
      @MitPageDetails = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Spinlockklasse, einem Latch-/Hot-Page-Kandidaten, Page Detail oder Finding.

## So lesen

Delta über Sample, Klasse, Waitdauer, Hot Page, Session-/Objektkontext und Wiederholung betrachten.

Delta-, Rate- und Resetlogik verwendet die reine Funktion `monitor.TVF_InterpretContentionCounter`. Fallende Zähler liefern weder eine Differenz noch eine Rate; die Procedure setzt stattdessen `CounterResetDetected=1`.

## Warum kann das problematisch sein?

Interne Synchronisationswartezeiten können CPU-Durchsatz begrenzen, obwohl einzelne Queries unauffällig wirken.

## Wann ist es kein Problem?

Hohe kumulative Zähler ohne aktuelles Delta sind schwach.

## Beispiel und Folgeschritt

Dieselbe Hot Page in mehreren Samples mit wachsender Waitzeit: belastbare Contention. Ein einmaliger kleiner Peak nicht. TempDB-/Indexdesign, Insertmuster und Requests prüfen.

[Technische Detailbeschreibung](../08_Server_Health.md#15-monitorusp_internalcontentionanalysis)
