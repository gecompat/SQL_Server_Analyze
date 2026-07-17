# [monitor].[USP_InMemoryOltpAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen  
**Zweck:** Analysiert XTP-Tabellen, Hashindizes, Checkpoints, Transaktionen und Resource Pools.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InMemoryOltpAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @MitHashIndexStats = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer XTP-Tabelle, einem Index, Hashstatistik, Checkpointzustand, Transaktionssignal, Pool oder Finding.

## So lesen

Tabellenmemory, Bucket Count, Chainlängen, leere Buckets, Checkpointfiles, aktive Transaktionen und Poolauslastung gemeinsam lesen.

## Warum kann das problematisch sein?

Lange Hashketten verursachen mehr Vergleiche; wartende Checkpointdaten oder hohe Poolauslastung können Persistenz-/Memorydruck anzeigen.

## Wann ist es kein Problem?

Große Memorynutzung ist bei bewusst großen XTP-Tabellen normal. Absolute Größe allein genügt nicht.

## Beispiel und Folgeschritt

Average Chain 20, Max 500, kaum leere Buckets und viele Equality Lookups: Bucketzahl wahrscheinlich zu klein. Workload, Indexart, Pool und Checkpoints prüfen.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#3-monitorusp_inmemoryoltpanalysis)
