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

[Technische Detailbeschreibung](../08_Server_Health.md#4-monitorusp_tempdbconfiguration)
