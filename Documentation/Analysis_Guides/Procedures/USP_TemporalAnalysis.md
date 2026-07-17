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

[Technische Detailbeschreibung](../09_Version_Adaptive.md#4-monitorusp_temporalanalysis)
