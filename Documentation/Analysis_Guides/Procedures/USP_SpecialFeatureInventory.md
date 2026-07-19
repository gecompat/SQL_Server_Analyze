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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche besonderen oder versionsabhängigen Datenbankfeatures und Objektarten sind im gewählten Scope konfiguriert?

### Technischer Hintergrund

Cross-Database-Katalogscans suchen Featuremarker für unter anderem Graph, Ledger, External Tables, FileTable/FILESTREAM, XML/Spatial/Columnstore, Memory Optimized, Vector oder weitere unterstützte Typen. Jede Featureart besitzt eigene Katalog- und Editionsbedingungen.

### Datenkette

`sys.assemblies`, `sys.change_tracking_databases`, `sys.change_tracking_tables`, `sys.column_encryption_keys`, `sys.column_master_keys`, `sys.columns`, `sys.configurations`, `sys.databases`, `sys.external_data_sources`, `sys.external_languages`, `sys.external_libraries`, `sys.external_tables`, `sys.filegroups`, `sys.fulltext_catalogs`, `sys.fulltext_indexes`, `sys.objects`, `sys.service_queues`, `sys.services`, `sys.sp_executesql`, `sys.tables`, `sys.types`, `sys.xml_indexes`.

### Zeit- und Scope-Modell

Aktueller Metadatenbestand je zugänglicher Datenbank; keine Nutzungs-/Historienmessung.

### Bewertung und Gegenprobe

Featuretyp, Objektanzahl, Datenbankscope, Version/Compatibility, Schutz-/Abhängigkeitsmerkmale und zuständiges Deep-Modul lesen. Inventar dient Migrations-/Upgrade-/Betriebsplanung.

### Typische Fehlinterpretation

Objekt vorhanden bedeutet nicht aktiv genutzt, performant oder korrekt konfiguriert. Null Zeilen kann durch Metadata Visibility oder ausgeschlossene Datenbanken entstehen.

### Folgeanalyse

Featurebezogene Deep Analysis, Query-/Dependencyanalyse und Ownerreview.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#2-monitorusp_specialfeatureinventory)
