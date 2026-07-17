# [monitor].[USP_AvailabilityDeepAnalysis]

**Bereich:** Infrastruktur  
**Zweck:** Vertieft Availability Groups mit Send-/Redo-Queues, Lag, Cluster- und Replica-Evidenz.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AvailabilityDeepAnalysis]
      @MitClusterNetzwerken = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Replica-/Datenbank-Beziehung, Queue-/Lagmetrik, Clusterkomponente oder ein Finding.

## So lesen

Send Queue, Redo Queue, geschätzte Lagzeit, Synchronisierungszustand, Rolle und Trend gemeinsam lesen.

## Warum kann das problematisch sein?

Wachsende Send Queue weist eher auf Transport/Primary hin; wachsende Redo Queue auf Secondary-Redo, I/O oder CPU.

## Wann ist es kein Problem?

Ein kurzer Peak nach großer Transaktion kann sich normal abbauen.

## Beispiel und Folgeschritt

Send Queue stabil klein, Redo Queue wächst über mehrere Messungen: Fokus auf Secondary-I/O/CPU/Redo statt Netzwerk. Counter, Storage und Cluster prüfen.

[Technische Detailbeschreibung](../07_Infrastructure.md#10-monitorusp_availabilitydeepanalysis)
