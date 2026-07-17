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

[Technische Detailbeschreibung](../03_Object_Index.md#4-monitorusp_missingindexes)
