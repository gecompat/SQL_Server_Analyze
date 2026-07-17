# [monitor].[USP_ServerFeatureCapabilities]

**Bereich:** Versionsadaptive Spezialanalysen  
**Zweck:** Zeigt versions-, editions-, plattform- und datenbankbezogene Featurefähigkeiten.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerFeatureCapabilities]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einer Featurefähigkeit in einem Server- oder Datenbank-Scope.

## So lesen

Serverversion, Edition, Plattform, Datenbank-Compatibility, Katalogsicht und einzelne Fähigkeit unterscheiden.

## Warum kann das problematisch sein?

Ein Codepfad kann auf der Hauptversion existieren, aber wegen Plattform, Edition, Build oder Compatibility nicht nutzbar sein.

## Wann ist es kein Problem?

Ein nicht unterstütztes Feature ist kein Fehler, wenn es nicht benötigt wird.

## Beispiel und Folgeschritt

SQL Server 2025 plus Compatibility 160: bestimmte 170-Funktionen sind für diese Datenbank noch nicht aktivierbar. Spezialmodule nur für passende Scopes ausführen.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#1-monitorusp_serverfeaturecapabilities)
