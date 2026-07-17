# [monitor].[USP_ExtendedEventsBlockedProcesses]

**Bereich:** Extended Events  
**Zweck:** Liest historische Blocked-Process-Reports und zerlegt blockierte sowie blockierende Prozesse.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsBlockedProcesses]
      @Quelle = 'AUTO',
      @VonUtc = DATEADD(HOUR, -1, SYSUTCDATETIME()),
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Summary-Zeile = ein Report; Process-Zeile = blockierte oder blockierende Prozessdarstellung innerhalb dieses Reports.

## So lesen

Konfigurierten Threshold, Waitdauer, Blocker/Blocked, Ressource, Statements und Wiederholungen über Zeit vergleichen.

## Warum kann das problematisch sein?

Wiederholte Reports derselben Kette zeigen persistierendes Blocking statt eines kurzen Snapshots.

## Wann ist es kein Problem?

Ein einzelner Report knapp über dem Threshold kann ein einmaliger langsamer Vorgang sein.

## Beispiel und Folgeschritt

Alle fünf Sekunden derselbe Root Blocker über zwei Minuten: starke Evidenz. Live mit `USP_CurrentBlocking` und `USP_CurrentTransactions` korrelieren.

## Leere Ausgabe

Threshold 0, fehlende XE-Konfiguration oder abgelaufene Retention erlauben keine Entwarnung.

[Technische Detailbeschreibung](../06_Extended_Events.md#4-monitorusp_extendedeventsblockedprocesses)
