# [monitor].[USP_DatabaseCapacityAnalysis]

**Bereich:** Server Health  
**Zweck:** Bewertet Dateien, Volumes, freien Platz, Autogrowth, MaxSize und Wachstumsspielraum.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabaseCapacityAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Datenbankdatei, einem Volume, einer Datenbankaggregation oder einem Finding.

## So lesen

Dateigröße, belegt/frei, Volume Free, Growthsetting, MaxSize und absoluten Wachstumsspielraum gemeinsam lesen.

## Warum kann das problematisch sein?

Wenig freier Raum plus kleine häufige Autogrowths kann Pausen erzeugen; MaxSize oder volles Volume kann Wachstum vollständig verhindern.

## Wann ist es kein Problem?

Niedriger Prozentwert bei sehr großem Volume kann absolut ausreichend sein; hoher Prozentwert auf kleinem Volume nicht.

## Kommentiertes Beispiel

5 % von 20 TB = 1 TB; 20 % von 10 GB = 2 GB. Prozent und absolute Menge gemeinsam lesen. Wachstumstrend, Log-/Backupstatus und Storage prüfen.

[Technische Detailbeschreibung](../08_Server_Health.md#12-monitorusp_databasecapacityanalysis)
