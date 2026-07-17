# Runbook: Eine Query ist plötzlich langsamer

## Erstaufruf

```sql
EXEC [monitor].[USP_QueryStoreRegressions]
      @QueryStoreDatabaseNames=N'[ExampleDatabase]',
      @MinAusfuehrungenJeFenster=10,
      @ResultSetArt='CONSOLE';
```

## Lesen

Baseline-/Vergleichsfenster, Stichprobe, absolute Änderung, Prozentänderung, Plananzahl und letzte Ausführung.

## Warum

Eine Regression ist belastbar, wenn vergleichbare Workload mit ausreichender Stichprobe im Vergleichsfenster mehr Ressourcen benötigt.

## Gegenprobe

`USP_QueryStorePlanChanges`, `USP_QueryStoreWaitStats`, Runtime Stats je Plan und `USP_ShowplanAnalysis`.

## Nicht tun

Keinen Plan allein wegen hoher Prozentänderung bei einer Ausführung forcieren. Parameter- und Datenmengenunterschiede prüfen.
