# [monitor].[USP_QueryStoreReplicaAnalysis]

`USP_QueryStoreReplicaAnalysis` trennt Query-Store-Runtime-, Wait- und
Plan-Forcing-Evidenz nach `replica_group_id` und ordnet sie den in
`sys.query_store_replicas` sichtbaren Rollen zu. Die Procedure ist auf SQL
Server 2019 und 2022 installierbar, referenziert dort aber keine
SQL-Server-2025-Kataloge und liefert kontrolliert `UNAVAILABLE_VERSION`.

## Eine Zeile bedeutet

Eine Zeile in `replicas` beschreibt eine vom Query Store beobachtete Rolle einer
Datenbank. Eine Zeile in `runtimeByReplica` beschreibt die über das gewählte
Zeitfenster aggregierten Runtimeintervalle einer `replica_group_id`.
`waitsByReplica` ergänzt Ausführungstyp und Waitkategorie.
`forcingByReplica` inventarisiert nur sichtbare Plan-Forcing-Locations.

## So lesen

1. Zuerst `moduleStatus` auf Version, Partialität und Ausgabegrenzen prüfen.
2. Danach `sourceStatus` je Datenbank und Quelle lesen.
3. `replicas` trennt beobachtete Rolle und aktuelle Verbindungsrolle.
4. `runtimeByReplica` und `waitsByReplica` nur innerhalb desselben Zeitfensters vergleichen.
5. `MappingStatusCode` prüfen, bevor eine Messung einer Rolle zugeschrieben wird.
6. `EvidenceLimit` bei jeder Interpretation mitlesen.

Mehrere beobachtete Rollen können nach Failover korrekt sein. Die aktuelle
Verbindungsrolle und die historische Query-Store-Rolle sind bewusst getrennt.

## Warum kann das problematisch sein?

Ohne Trennung nach Replica-Rolle können Laufzeit- oder Waitaggregate aus
Primary-, Secondary- und Named-Replica-Ausführungen vermischt werden. Dadurch
kann eine Verschiebung des Read-Workloads wie eine allgemeine Queryregression
erscheinen. Eine fehlende Rollenzuordnung kann außerdem zu falschen
Healthaussagen führen, wenn Messwerte stillschweigend dem Primary zugeschrieben
werden.

## Wann ist es kein Problem?

Unterschiedliche Laufzeitwerte zwischen Primary und Secondary sind nicht
automatisch ein Fehler. Hardware, Cachezustand, Parallelität, Datenbewegung,
Read-Intent-Routing und zeitlich unterschiedlicher Workload können die Werte
legitim unterscheiden. Eine beobachtete frühere Rolle nach Failover ist
ebenfalls kein aktueller Störungsnachweis.

## Sicherer Einstieg

```sql
DECLARE @Json nvarchar(max);

EXEC [monitor].[USP_QueryStoreReplicaAnalysis]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]'
    , @VonUtc = DATEADD(HOUR,-1,SYSUTCDATETIME())
    , @BisUtc = SYSUTCDATETIME()
    , @MaxZeilen = 100
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT;

SELECT @Json AS [QueryStoreReplicaAnalysisJson];
```

`@ReplicaGroupIds` kann eine numerische Pipe-, Beistrich- oder
Strichpunktliste enthalten. `@MaxZeilen = 0` bedeutet unbegrenzt und ist für den
Ersteinstieg nicht empfohlen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query-Store-Evidenz wurde auf welcher beobachteten Replica-Rolle
erfasst, und ist die Zuordnung vollständig genug für einen Rollenvergleich?

### Technischer Hintergrund

SQL Server 2025 ergänzt die Query-Store-Runtime- und Waitquellen um
`replica_group_id`. `sys.query_store_replicas` ordnet diese Gruppen beobachteten
Rollen zu. `sys.query_store_plan_forcing_locations` hält replica-spezifische
Forcing-Locations. Die Procedure liest keine Querytexte, Plan-XMLs oder
Hint-Payloads.

### Datenkette

Je Zieldatenbank werden zuerst Product Major Version, Query-Store-Zustand,
Systemobjekte und Pflichtspalten geprüft. Erst danach werden die
versionsspezifischen Quellen dynamisch referenziert. Jede Quelle wird höchstens
einmal pro Datenbank gelesen und lokal materialisiert. Runtimewerte werden mit
`count_executions` gewichtet; Waitwerte bleiben nach Ausführungstyp und
Waitkategorie getrennt.

### Source Select

```sql
SELECT
      [rs].[replica_group_id]
    , SUM([rs].[count_executions]) AS [ExecutionCount]
    , SUM(CONVERT(float,[rs].[avg_cpu_time])*[rs].[count_executions]) AS [CpuWeighted]
FROM [sys].[query_store_runtime_stats] AS [rs]
JOIN [sys].[query_store_runtime_stats_interval] AS [i]
  ON [i].[runtime_stats_interval_id]=[rs].[runtime_stats_interval_id]
WHERE [i].[end_time]>@VonUtc
  AND [i].[start_time]<@BisUtc
GROUP BY [rs].[replica_group_id];
```

**Wichtig für die Eigenlast:** Datenbank- und Zeitfilter werden vor der
Aggregation angewendet. `@MaxZeilen` begrenzt die Ausgabe; breite Zeitfenster
und viele Datenbanken erhöhen CPU und I/O des Query-Store-Katalogzugriffs.

### Zeit- und Scope-Modell

`CapturedAtUtc` ist der aufrufweite Erfassungszeitpunkt. Runtime- und Waitwerte
stammen aus Query-Store-Intervallen innerhalb von `@VonUtc` und `@BisUtc`.
`replicas` ist sichtbarer Katalogzustand zum Lesezeitpunkt. Die Quellen bilden
keine transaktional atomare Momentaufnahme.

### Bewertung und Gegenprobe

Rollenunterschiede zuerst mit Ausführungszahl, Zeitraum, Routing und
`USP_QueryStoreRuntimeStats` gegenprüfen. Bei Planwechseln oder Regressionen
anschließend `USP_QueryStorePlanChanges` beziehungsweise
`USP_QueryStoreRegressions` verwenden. Aktuelle AG-Synchronität und Routing
werden separat über die Availability-Group-Analysen geprüft.

### Typische Fehlinterpretation

`SECONDARY` bedeutet nicht, dass die aktuelle Verbindung gerade auf einer
Secondary läuft. Es ist die beobachtete Rolle der gespeicherten
Query-Store-Evidenz. `REPLICA_METADATA_MISSING` bedeutet ebenfalls nicht, dass
die Messung ungültig ist; nur die Rollenzuschreibung bleibt unvollständig.

### Folgeanalyse

`USP_QueryStoreRuntimeStats` liefert Query- und Plandetails im gleichen
Zeitfenster. `USP_QueryStoreWaitStats` vertieft Waitkategorien.
`USP_AvailabilityGroups` und `USP_AvailabilityDeepAnalysis` ergänzen aktuelle
Replica-, Routing- und Datenbewegungsevidenz.

## Primärquellen

- [sys.query_store_replicas](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-replicas?view=sql-server-ver17)
- [Query Store for secondary replicas](https://learn.microsoft.com/en-us/sql/relational-databases/performance/query-store-for-secondary-replicas?view=sql-server-ver17)
- [sys.query_store_runtime_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-runtime-stats-transact-sql?view=sql-server-ver17)
- [sys.query_store_wait_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-wait-stats-transact-sql?view=sql-server-ver17)
- [sys.query_store_plan_forcing_locations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-query-store-plan-forcing-locations-transact-sql?view=sql-server-ver17)
