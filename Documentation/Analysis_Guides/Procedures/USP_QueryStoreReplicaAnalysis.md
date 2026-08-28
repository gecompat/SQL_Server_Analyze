# [monitor].[USP_QueryStoreReplicaAnalysis]

`USP_QueryStoreReplicaAnalysis` trennt Query-Store-Runtime-, Wait- und
Plan-Forcing-Evidenz nach `replica_group_id` und ordnet sie den in
`sys.query_store_replicas` sichtbaren Rollen zu. Die Procedure ist auf SQL
Server 2019 und 2022 installierbar, referenziert dort aber keine
SQL-Server-2025-Kataloge und liefert kontrolliert `UNAVAILABLE_VERSION`.

**Bereich:** Query Store und SQL Server 2025
**Zweck:** Trennt Query-Store-Runtime-, Wait- und Forcingevidenz nach beobachteter Replica-Gruppe und Rollenmetadaten.
**Beobachtungsart:** versionsadaptiver historischer Query-Store-Aggregationssnapshot
**Kostenklasse:** MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure wird eingesetzt, wenn Query-Store-Messwerte eines begrenzten Zeitfensters nicht über Primary-, Secondary- und andere beobachtete Rollen vermischt werden sollen. Sie liefert die Rollenabbildung als eigene Evidenz und eignet sich vor einem Vergleich von Runtime- oder Waitaggregaten zwischen Replicas.

## Nicht beantwortete Fragen

Die Analyse prüft keine aktuelle AG-Synchronität, kein Routing und keine Hardwaregleichheit. Sie liest keine Querytexte, Plan-XMLs oder Hint-Payloads. Unterschiedliche Rollenaggregate beweisen deshalb weder Regression noch fehlerhafte Lastverteilung. Fehlende Replica-Metadaten machen eine Messung nicht wertlos, begrenzen aber ihre Rollenzuschreibung.

## Resultsets und Leserichtung

RAW, TABLE und JSON trennen `moduleStatus`, `sourceStatus`, `replicas`, `runtimeByReplica`, `waitsByReplica` und `forcingByReplica`. CONSOLE priorisiert den fachlichen Einstieg. Lesen Sie Datenbank-, Versions- und Query-Store-Status vor Rollen und Aggregaten. Vergleichen Sie nur identische Zeitfenster und berücksichtigen Sie `MappingStatusCode`.

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

## Beispiele und Gegenbeispiele

Ein geeigneter Example-Fall verwendet ein synthetisches Query-Store-Workloadfenster und prüft auf SQL Server 2025, ob Runtimezeilen eine explizite oder als fehlend markierte Rollenzuordnung besitzen. Ein Gegenbeispiel ist die pauschale Zuordnung jeder nicht gemappten Zeile zum Primary. Ebenso ist ein höherer Mittelwert auf einer Secondary ohne Ausführungszahl, Zeitraum und Hardwarekontext keine Regression.

## Leere oder partielle Ausgabe

`UNAVAILABLE_VERSION` ist auf SQL Server 2019 und 2022 der vorgesehene Fallback. Ein deaktivierter oder leerer Query Store erzeugt keine künstlichen Runtimezeilen. Fehlt eine einzelne 2025-Quelle oder Berechtigung, bleiben andere Quellen erhalten und `sourceStatus` beschreibt die Partialität. `NOT_RECORDED` und fehlende Metadaten sind keine erfundene Rollenidentität.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `MEDIUM` |
| Standardpfad | Begrenztes Zeitfenster in einer explizit ausgewählten Datenbank |
| Teuerster Pfad | Breites Zeitfenster und mehrere Query-Store-Datenbanken |
| Haupttreiber | Runtimeintervalle, Pläne, Waitzeilen und Replica-Gruppen |
| Skalierung | Sequenziell je Datenbank; Aggregation innerhalb des Zeitfensters |
| Ressourcen | Query-Store-Katalog-I/O, CPU für gewichtete Aggregate und lokale Sortierung |
| Begrenzungswirkung | Datenbank-, Zeit-, Replica- und Zeilengrenzen |
| Locking und Nebenwirkungen | Read-only; kein Planforcing, Hint oder Query-Store-Flush |
| Schutzmechanismus | Versions-/Spaltenprobes und getrennte Quellenstatus |
| Sicherer Einsatz | Kleine Datenbankmenge und enges UTC-Zeitfenster |
| Aussagegrenze | Rollenaggregate sind keine AG-Health- oder Regressionsentscheidung |

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


[Technische Detailbeschreibung](../05_Query_Store.md)
