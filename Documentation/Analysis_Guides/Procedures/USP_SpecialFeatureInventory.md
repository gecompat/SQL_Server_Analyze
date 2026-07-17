# [monitor].[USP_SpecialFeatureInventory]

**Bereich:** Versionsadaptive Spezialanalysen  
**Zweck:** Erkennt leichtgewichtig verwendete Spezialfeatures und empfiehlt passende Tiefenanalysen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SpecialFeatureInventory]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurErkannteFeatures = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile entspricht einem Featurecode und dessen Erkennung in einem Datenbank-Scope.

## So lesen

FeatureCode, Detection Status, sichtbaren Nutzungsumfang, empfohlenes Deep-Dive und `EvidenceLimit` lesen.

## Warum kann das problematisch sein?

Spezialfeatures benötigen eigene Backup-, Kapazitäts-, Betriebs- und Performancebetrachtung, die Standardanalysen nicht vollständig abdecken.

## Wann ist es kein Problem?

Erkennung ist Inventar, kein Fehlerbefund.

## Beispiel und Folgeschritt

Temporal Tables erkannt bedeutet nicht, dass Retention falsch ist; es macht `USP_TemporalAnalysis` zum sinnvollen nächsten Check.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#2-monitorusp_specialfeatureinventory)
