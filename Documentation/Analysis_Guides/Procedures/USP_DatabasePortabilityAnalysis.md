# [monitor].[USP_DatabasePortabilityAnalysis]

Inventarisiert sichtbare persistierte Edition-Features und uncontained dependencies je Benutzerdatenbank.

```sql
EXEC [monitor].[USP_DatabasePortabilityAnalysis] @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile steht für eine Portabilitätsevidenz aus genau einer Datenbank und Quellklasse.

## So lesen

Bewerten Sie Feature oder Abhängigkeit gegen Zielversion, Edition, Plattform und Anwendungsvertrag.

## Warum kann das problematisch sein?

Persistierte Features oder externe Abhängigkeiten können Restore, Attach oder Plattformwechsel erschweren.

## Wann ist es kein Problem?

Das Ziel kann das Feature vollständig unterstützen, oder die Abhängigkeit kann bewusst freigegeben sein.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Merkmale benötigen vor einer Migration einen Zielplattformtest?

### Technischer Hintergrund

Die Procedure liest zwei datenbanklokale Katalogsichten; Fehler einer Datenbank bleiben als partielle Quelle sichtbar.

### Datenkette

`master.sys.databases` → `sys.dm_db_persisted_sku_features` und `sys.dm_db_uncontained_entities` → Hinweise.

### Source Select

```sql
SELECT [feature_name] FROM [sys].[dm_db_persisted_sku_features] WITH (NOLOCK);
SELECT [class_desc], [statement_type], [feature_name] FROM [sys].[dm_db_uncontained_entities] WITH (NOLOCK);
```

**Wichtig für die Eigenlast:** Filtern Sie Datenbanken vor dem Kontextwechsel; Nutzdaten werden nicht gescannt.

### Zeit- und Scope-Modell

Datenbanken werden nacheinander gelesen; die Ausgabe ist kein atomarer serverweiter Snapshot.

### Bewertung und Gegenprobe

Bestätigen Sie Befunde mit Zielversion, Restoretest und Anwendungstest.

### Typische Fehlinterpretation

`AVAILABLE_EMPTY` schließt nicht jede denkbare Portabilitätsgrenze aus.

### Folgeanalyse

Nutzen Sie Feature-Capabilities, Konfigurationsanalyse und einen isolierten Migrationstest.

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/200_USP_DatabasePortabilityAnalysis.sql)
