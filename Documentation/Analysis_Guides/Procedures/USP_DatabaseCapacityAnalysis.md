# [monitor].[USP_DatabaseCapacityAnalysis]

**Bereich:** Server Health  
**Zweck:** Bewertet Dateien, Volumes, freien Platz, Autogrowth, MaxSize und Wachstumsspielraum.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabaseCapacityAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Für vollständige Volumenevidenz ist auf SQL Server 2019 `VIEW SERVER STATE`, ab SQL Server 2022 `VIEW SERVER PERFORMANCE STATE` erforderlich. Fehlt dieses Recht, bleibt zulässige Dateievidenz sichtbar, der Status lautet jedoch ausdrücklich `AVAILABLE_LIMITED` mit `IsPartial=1`.

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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie viel Datei-/Volumeplatz bleibt, wie sind Growth/MaxSize konfiguriert und welche Kapazitätsrisiken sind sichtbar?

### Technischer Hintergrund

Database Files wachsen innerhalb Volume-/MaxSizegrenzen. Percent Growth erzeugt mit wachsender Datei zunehmend große Schritte; kleine Growthsteps erzeugen häufige Growth Events. Loggrowth/Zero Initialization und Datafile IFI unterscheiden sich.

### Datenkette

`sys.database_files`, `sys.dm_os_volume_stats`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Snapshot. Ohne historische Messpunkte keine Wachstumsrate/Forecast.

### Bewertung und Gegenprobe

Absolute freie MB und Prozent, Filegröße, Growthtyp/-schritt, MaxSize, Volume Free, Dateityp und geplante Workloadspitzen kombinieren. Autogrowth als Sicherheitsnetz, proaktives Sizing als Betrieb.

### Typische Fehlinterpretation

Viel freier Platz im File bedeutet nicht freien Volumeplatz; viel Volumeplatz bedeutet nicht passende MaxSize/Growth. Forecast aus einem Snapshot ist Heuristik.

### Folgeanalyse

Current Log/IO, Backup-/Loadplanung und externes Capacitytrendmonitoring.

[Technische Detailbeschreibung](../08_Server_Health.md#12-monitorusp_databasecapacityanalysis)
