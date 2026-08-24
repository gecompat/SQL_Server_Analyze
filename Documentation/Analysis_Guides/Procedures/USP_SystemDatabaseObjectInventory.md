# [monitor].[USP_SystemDatabaseObjectInventory]

Inventarisiert sichtbare, nicht von Microsoft gelieferte Objekte in `master`, `model` und `msdb`, ohne DDL auszuführen.

```sql
EXEC [monitor].[USP_SystemDatabaseObjectInventory] @MaxZeilen = 200, @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile beschreibt ein Benutzerobjekt mit Datenbank, Schema, Typ sowie Erstellungs- und Änderungszeit.

## So lesen

Ordnen Sie jedes Objekt einem Eigentümer und dokumentierten Betriebszweck zu.

## Warum kann das problematisch sein?

Undokumentierte Objekte können Upgrades, Betrieb, Berechtigungen oder neue Datenbanken aus `model` beeinflussen.

## Wann ist es kein Problem?

Freigegebene administrative oder Monitoringobjekte können betrieblich gewollt sein.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Benutzerobjekte benötigen Eigentümer-, Zweck- und Upgradeevidenz?

### Technischer Hintergrund

Die Procedure liest `sys.objects` mit `sys.schemas` in drei isolierten Datenbankkontexten.

### Datenkette

`master.sys.databases` → datenbanklokale `sys.objects` und `sys.schemas` → Inventar.

### Source Select

```sql
SELECT [s].[name], [o].[name], [o].[type_desc], [o].[create_date], [o].[modify_date]
FROM [sys].[objects] [o] WITH (NOLOCK)
JOIN [sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id] = [o].[schema_id]
WHERE [o].[is_ms_shipped] = 0;
```

**Wichtig für die Eigenlast:** Der Zugriff bleibt auf Systemkataloge begrenzt; Objektinhalte werden nicht gelesen.

### Zeit- und Scope-Modell

Die Datenbanken werden nacheinander gelesen; Berechtigungsgrenzen können eine partielle Momentaufnahme erzeugen.

### Bewertung und Gegenprobe

Vergleichen Sie Objekt, Eigentümer, Quellcode, Deploymentpfad, Backup und Upgradevertrag.

### Typische Fehlinterpretation

`is_ms_shipped = 0` bedeutet benutzererstellt, nicht automatisch unerlaubt.

### Folgeanalyse

Prüfen Sie Sicherheit, Abhängigkeiten und einen isolierten Upgrade- beziehungsweise Restoretest.

[Technische Detailbeschreibung](../../../Code/08_ServerHealth/230_USP_SystemDatabaseObjectInventory.sql)
