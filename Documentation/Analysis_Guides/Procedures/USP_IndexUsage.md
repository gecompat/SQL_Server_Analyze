# [monitor].[USP_IndexUsage]

**Bereich:** Object und Index  
**Zweck:** Zeigt kumulative Read-/Write-Nutzung klassischer und optional In-Memory-Indizes.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IndexUsage]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem Index im sichtbaren DMV-Scope; XTP-Indizes erscheinen in einem separaten Resultset mit eigener Zählersemantik.

## So lesen

Resetzeit, Reads, Updates, letzte Nutzung und Schutzmerkmale wie PK, Unique oder Constraint gemeinsam lesen.

## Warum kann das problematisch sein?

Viele Updates ohne Reads bedeuten mögliche Schreib-, Log-, Lock- und Speicherlast ohne sichtbaren Lesebedarf.

## Wann ist es kein Problem?

Kurzes Beobachtungsfenster, saisonale Reports oder Constraintfunktionen machen `0 Reads` unzureichend für eine Löschungsentscheidung.

## Kommentiertes Beispiel

0 Reads, 8 Mio. Updates, 180 Tage Beobachtung: starker Reviewkandidat. 0 Reads, 40 Updates, zwei Stunden seit Restart: praktisch keine belastbare Aussage.

## Folgeschritt

Query Store, Abhängigkeiten, Constraints und `USP_IndexOperationalStats` prüfen. Niemals allein aus dieser DMV einen Index löschen.

[Technische Detailbeschreibung](../03_Object_Index.md#2-monitorusp_indexusage)
