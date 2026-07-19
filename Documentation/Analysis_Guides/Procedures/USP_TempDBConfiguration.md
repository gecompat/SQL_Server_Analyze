# [monitor].[USP_TempDBConfiguration]

**Bereich:** Server Health  
**Zweck:** Bewertet TempDB-Dateien, Größen, Wachstum, Gleichheit und Konfigurationsrisiken.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_TempDBConfiguration]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer TempDB-Datei, Konfigurationseigenschaft oder einem Finding.

## So lesen

Dateianzahl, Größen-/Growth-Gleichheit, Autogrowth-Einheit, freien Platz, Version Store und Contentionkontext gemeinsam lesen.

## Warum kann das problematisch sein?

Ungleich große Datenfiles werden proportional unterschiedlich genutzt; kleine Growthschritte erzeugen viele Wachstumsereignisse.

## Wann ist es kein Problem?

Nicht jede Instanz benötigt acht Dateien. CPU, Contention und Workload entscheiden.

## Beispiel und Folgeschritt

Vier gleich große Dateien ohne Contention können besser sein als acht ungleich große. Current TempDB, Filegrowth-Historie und Contention prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist TempDB hinsichtlich Dateianzahl, Größe, Growth, Layout und Optionen robust konfiguriert?

### Technischer Hintergrund

TempDB wird bei jedem Start neu erstellt. Datafiles bilden Allocationkonkurrenz ab; gleich große Dateien begünstigen Proportional Fill. Autogrowth ist Notfallkapazität, kein laufendes Sizingmodell. Version Store, Internal/User Objects verursachen Runtimebelegung.

### Datenkette

`sys.configurations`, `tempdb.sys.database_files`.

### Zeit- und Scope-Modell

Aktueller Katalog-/Dateistand; TempDB-Inhalt seit Engine-Start.

### Bewertung und Gegenprobe

Datafile Count relativ zu Workload/CPU, gleiche Initialgröße/Growth, absolute Growthgröße, Volumeplatz, Logfile und versionsabhängige Optionen prüfen. Änderungen anhand gemessener Contention statt pauschaler Maximalzahl.

### Typische Fehlinterpretation

Mehr Dateien lösen nicht jeden PAGELATCH-Wait; zu viele Dateien erhöhen Verwaltung/Recovery/Storage. Gleichheit beweist keine ausreichende Kapazität.

### Folgeanalyse

`USP_CurrentTempDB`, Internal Contention, Current IO.

[Technische Detailbeschreibung](../08_Server_Health.md#4-monitorusp_tempdbconfiguration)
