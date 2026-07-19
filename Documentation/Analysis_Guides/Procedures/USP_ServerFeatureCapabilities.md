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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche versions-/editionsabhängigen Frameworkpfade sind auf dieser Instanz technisch möglich und lesbar?

### Technischer Hintergrund

Die Procedure verbindet Product Major Version, Edition/Engine Edition, Compatibility und die Existenz versionsabhängiger Systemobjekte/Spalten. Capability-Probes vermeiden Compilefehler durch statische Referenzen auf nicht vorhandene Quellen und führen optionale Abfragen geschützt dynamisch aus.

### Datenkette

`master.sys.all_objects`, `sys.databases`, `sys.dm_os_host_info`, `sys.objects`, `sys.query_store_replicas`, `sys.resource_governor_configuration`, `sys.schemas`, `sys.sp_executesql`, `sys.vector_indexes`, `sys.views`.

### Zeit- und Scope-Modell

Aktueller Instanz-/Datenbankzustand. Upgrade, Compatibilitywechsel, Failover oder Permissionänderung können Ergebnis ändern.

### Bewertung und Gegenprobe

Supported, ObjectExists, Compatibility, Permission/Queryable und Usable getrennt lesen. Fallbackpfad und Evidence Limit dokumentieren.

### Typische Fehlinterpretation

Version allein reicht nicht: SQL Server 2025 mit niedriger Compatibility kann Features nicht im Querykontext aktivieren. Objekt vorhanden beweist keine nutzbare Datenlage.

### Folgeanalyse

Das betroffene Spezialmodul nur bei `Usable=1` ausführen; sonst Status/Warnung beibehalten.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#1-monitorusp_serverfeaturecapabilities)
