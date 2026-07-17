# [monitor].[USP_CurrentBlocking]

**Bereich:** Current State  
**Zweck:** Rekonstruiert aktuelle Blockingkanten und -ketten bis zum Root Blocker.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentBlocking]
      @MinWaitMs = 1000,
      @ResultSetArt = 'CONSOLE';
```

Lockdetails nur gezielt aktivieren.

## Eine Zeile bedeutet

Im Kettenresultset beschreibt eine Zeile eine Blockingkante. Eine vollständige Kette besteht häufig aus mehreren Zeilen; Lockdetails besitzen eine eigene Granularität.

## So lesen

Vom `LeafSessionId` über jede Kante bis `RootBlockingSessionId` gehen. Waitzeit, Ressource, Aktivität und Transaktionszustand des Root Blockers vergleichen.

## Warum kann das problematisch sein?

Viele Opfer können von einer einzelnen Root-Session abhängen. Das Beenden eines Opfers beseitigt die gehaltene Ressource nicht.

## Wann ist es kein Problem?

Kurze Lockwartezeiten gehören zur transaktionalen Konsistenz. Kritischer sind wachsende, wiederkehrende Ketten und SLA-Auswirkungen.

## Beispiel und Folgeschritt

Zehn Sessions warten zwei Minuten auf eine sleeping Session mit offener Transaktion: starke Root-Blocker-Evidenz. Mit `USP_CurrentTransactions` und `USP_CurrentRequests` prüfen; erst danach betriebliche Eingriffe erwägen.

[Technische Detailbeschreibung](../02_Current_State.md#3-monitorusp_currentblocking)
