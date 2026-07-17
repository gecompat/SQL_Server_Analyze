# [monitor].[USP_ObjectAnalysis]

**Bereich:** Object und Index, Orchestrator  
**Zweck:** Orchestriert Inventar, Usage, Missing Indexes und optionale Tiefenmodule mit gemeinsamem Filtervertrag.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ObjectAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleTable]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Objekt/Index, Indexpartition, Statistik, Rowgroup, Partition oder Finding.

## So lesen

Childstatus zuerst, dann Inventar → Nutzung → konkrete Tiefenanalyse. Befunde verschiedener Children gemeinsam, aber nicht als identische Zeilen interpretieren.

## Warum kann das problematisch sein?

Ein Missing-Index-Vorschlag ohne Inventar kann Redundanz erzeugen; Fragmentierung ohne Page Count kann unnötige Wartung auslösen.

## Wann ist es kein Problem?

Nicht aktivierte Deep-Module fehlen absichtlich. Sie bedeuten keine partielle Ausführung.

## Beispiel und Folgeschritt

Inventar zeigt ähnlichen Index, Missing Index schlägt einen neuen vor, Usage zeigt geringe Nutzung: eher Konsolidierung prüfen als blind erstellen. Relevantes Child mit engem Scope wiederholen.

[Technische Detailbeschreibung](../03_Object_Index.md#11-monitorusp_objectanalysis)
