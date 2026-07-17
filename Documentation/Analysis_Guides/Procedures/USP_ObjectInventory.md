# [monitor].[USP_ObjectInventory]

**Bereich:** Object und Index  
**Zweck:** Liefert Objekt- und Indexinventar mit Größe, Zeilen, Partitionierung, Kompression und Definition.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ObjectInventory]
      @DatabaseNames = N'[ExampleDatabase]',
      @SchemaNames = N'[ExampleSchema]',
      @ObjectNames = N'[ExampleTable]',
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Inventarzeile beschreibt typischerweise eine Objekt-/Index-Kombination. Objektgesamtwerte können deshalb je Index wiederholt erscheinen.

## So lesen

Objektgröße und Zeilen zuerst, dann Indexart, Schlüssel/Includes, Partitionierung, Kompression und Sonderzustände.

## Warum kann das problematisch sein?

Große deaktivierte, hypothetische oder redundante Indizes können Speicher- und Wartungskosten erzeugen. Die Definition allein beweist aber keine Entbehrlichkeit.

## Wann ist es kein Problem?

Gemischte Kompression oder ähnliche Indizes können Teil einer Hot-/Cold-, Constraint- oder Coverage-Strategie sein.

## Beispiel und Folgeschritt

Zwei Indizes besitzen gleiche Schlüssel, aber einer sichert eine Unique Constraint. Er darf nicht wie ein normaler Duplikatindex behandelt werden. Usage, Operational Stats und Pläne prüfen.

[Technische Detailbeschreibung](../03_Object_Index.md#1-monitorusp_objectinventory)
