# [monitor].[USP_MissingIndexes]

**Bereich:** Object und Index  
**Zweck:** Priorisiert flüchtige Missing-Index-Evidenz und erzeugt einen ausdrücklich unverbindlichen DDL-Entwurf.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_MissingIndexes]
      @DatabaseNames = N'[ExampleDatabase]',
      @MinUserReads = 10,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Missing-Index-Gruppe aus den Optimizer-DMVs, nicht einem fertig geprüften Indexdesign.

## So lesen

Reads und Compiles zuerst, danach Impact und Improvement Measure. Schlüssel und Includes mit vorhandenen Indizes vergleichen.

## Warum kann das problematisch sein?

Der Optimizer sieht mögliche Lesekosten, aber nicht vollständig Schreiblast, Speicher, Wartung, Redundanz und fachliche Abhängigkeiten.

## Wann ist es kein Problem?

98 % Impact bei zwei Reads ist plakativ, aber schwach. Ein ähnlicher vorhandener Index kann den Vorschlag überflüssig machen.

## Kommentiertes Beispiel

25 % Impact bei fünf Millionen Reads kann mehr Gesamtnutzen besitzen als 99 % bei einer Ausführung. Vor DDL immer Inventar, Usage, Querytext, Plan und Write-Last prüfen.

## Leere Ausgabe

Missing-Index-DMVs sind flüchtig und begrenzt. Leer kann Reset, fehlende Compiles oder nicht geeignete Queries bedeuten.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche zusätzlichen Nonclustered-Indexstrukturen hat der Optimizer während Kompilierungen als potenziell kostensenkend eingeschätzt?

### Technischer Hintergrund

Missing-Index-DMVs sammeln Gleichheits-, Ungleichheits- und Include-Spalten aus Optimizerentscheidungen. Der oft verwendete Improvement-Wert kombiniert geschätzte Kosten, Impact und Nutzungshäufigkeit; er ist eine Priorisierungsheuristik. Die Engine konsolidiert Vorschläge nicht automatisch mit bestehenden Indizes.

### Datenkette

`sys.dm_db_missing_index_details`, `sys.dm_db_missing_index_group_stats`, `sys.dm_db_missing_index_groups`, `sys.objects`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Flüchtig/kumulativ seit Restart/Reset und begrenzt in der Zahl gespeicherter Gruppen. Vorschläge können nach Plan Cache-/Metadatenänderungen verschwinden.

### Bewertung und Gegenprobe

Queryhäufigkeit, Kosten, tatsächliche Reads, vorhandene Präfixe/Includes, Selectivity, DML-Kosten, Speicher und Locking prüfen. Mehrere Vorschläge häufig zu einem tragfähigen Indexdesign konsolidieren.

### Typische Fehlinterpretation

Ein hoher Improvement-Wert ist keine gemessene Einsparung. Der Vorschlag kennt Write Amplification, andere Queries, Filtered Indexes und vollständige Datenverteilung nur begrenzt.

### Folgeanalyse

Betroffene Pläne/Query Store, `USP_ObjectInventory`, `USP_IndexUsage`; DDL nur nach Test und Rollbackplan.

[Technische Detailbeschreibung](../03_Object_Index.md#4-monitorusp_missingindexes)
