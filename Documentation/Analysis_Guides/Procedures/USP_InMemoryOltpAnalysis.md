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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sind Memory-Optimized-Objekte, Indizes, Memoryverbrauch und Persistenz-/Checkpointpfade konfiguriert und belastet?

### Technischer Hintergrund

In-Memory OLTP speichert Rows in Memory und nutzt MVCC statt klassischer Page Locks/Latches. Hashindizes verteilen Schlüssel auf Buckets; Rangeindizes verwenden Bw-Trees. Durable Tabellen schreiben Log und Checkpoint File Pairs; SCHEMA_ONLY nicht. Garbage Collection entfernt nicht mehr sichtbare Versionen.

### Datenkette

`sys.databases`, `sys.dm_db_xtp_checkpoint_files`, `sys.dm_db_xtp_hash_index_stats`, `sys.dm_db_xtp_memory_consumers`, `sys.dm_db_xtp_table_memory_stats`, `sys.dm_db_xtp_transactions`, `sys.dm_resource_governor_resource_pools`, `sys.filegroups`, `sys.hash_indexes`, `sys.schemas`, `sys.sp_executesql`, `sys.table_types`, `sys.tables`.

### Zeit- und Scope-Modell

Aktueller Katalog-/Runtimezustand; Memory-/Transaction-/Checkpointwerte teils seit Start, Objektbestand aktuell.

### Bewertung und Gegenprobe

Table Durability, Rows/Memory, Hash Bucket Count, Empty/Chainverteilung, Indexart, GC/Transactionalter, Checkpointstorage und Database Memoryquota zusammen lesen. Hashketten benötigen Datenverteilungs-/Lookupkontext.

### Typische Fehlinterpretation

Viele Empty Buckets allein sind nicht automatisch schlecht; lange Chains sind besonders bei häufigen Equality Lookups relevant. Memory-Optimized heißt nicht logfrei oder ohne Capacitygrenze.

### Folgeanalyse

Current Transactions/Memory, Querypläne, XTP DMVs und Checkpoint-/Logstorage.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#3-monitorusp_inmemoryoltpanalysis)
