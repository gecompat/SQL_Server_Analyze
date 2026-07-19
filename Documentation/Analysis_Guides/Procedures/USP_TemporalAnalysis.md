# [monitor].[USP_TemporalAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen  
**Zweck:** Analysiert Temporal-Current-/History-Beziehungen, Retention, Größe, Indizes und Konsistenz.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_TemporalAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Temporal-Tabelle, History-Beziehung, Retention-/Cleanup-Evidenz, Index-/Kapazitätsinformation oder einem Finding.

## So lesen

Current-/History-Zuordnung, Historygröße, Retention, Konsistenzstatus, Indexierung und Wachstum vergleichen.

## Warum kann das problematisch sein?

Unbegrenzte oder wirkungslose Retention kann History stark wachsen lassen; ungeeignete Indizes verteuern Zeitabfragen und Cleanup.

## Wann ist es kein Problem?

Große History kann fachlich erforderlich und durch Partitionierung oder Archivierung kontrolliert sein.

## Beispiel und Folgeschritt

History wächst monatlich stark, Retention ist konfiguriert, Cleanup zeigt aber keine Wirkung: konkreter Betriebsbefund. Kapazität, Partitionierung, Cleanup und Pläne prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche system-versioned Tabellen besitzen welche History-, Period-, Retention-, Größen- und Indexkonfiguration?

### Technischer Hintergrund

Temporal Tables schreiben bei Update/Delete frühere Rowversionen in eine History Table; Period Columns definieren Gültigkeit. System Versioning, Data Consistency Check und Retention steuern Lebenszyklus. Historyzugriffe über `FOR SYSTEM_TIME` benötigen passende Indizes/Partitionierung.

### Datenkette

`sys.columns`, `sys.databases`, `sys.dm_db_partition_stats`, `sys.index_columns`, `sys.indexes`, `sys.periods`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Aktueller Schemastand plus angesammelte Historydaten innerhalb fachlicher/technischer Retention.

### Bewertung und Gegenprobe

Current/History Table, Period Columns, Retention, Historygröße/Rows, Index-/Partitionierung und Cleanupstatus lesen. Schreibrate und typische Zeitprädikate bestimmen Design.

### Typische Fehlinterpretation

Große History ist nicht automatisch Problem; sie kann Complianceanforderung sein. Temporal ON beweist keine erfolgreiche Retentionbereinigung.

### Folgeanalyse

Object/Index/Partition/Capacity, konkrete Temporal Querypläne und Retentionpolicy.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#4-monitorusp_temporalanalysis)
