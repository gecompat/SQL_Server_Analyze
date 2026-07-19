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

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Objekte und physischen Zugriffsstrukturen existieren, wie groß sind sie und welche Eigenschaften besitzen sie?

### Technischer Hintergrund

Tabellen, Views, Indizes, Spalten, Partitionen, Kompression und Allocation Units bilden mehrere Katalogebenen. Rowcount und reservierte/benutzte Seiten kommen typischerweise aus Partition Stats; Definition und Schutzmerkmale aus Objekt-/Indexkatalogen. Ein Unique Constraint oder Primary Key ist fachlich/relational geschützt, auch wenn ein Index technisch ähnlich zu einem anderen wirkt.

### Datenkette

`master.sys.databases`, `sys.allocation_units`, `sys.columns`, `sys.data_spaces`, `sys.index_columns`, `sys.indexes`, `sys.objects`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Aktueller Metadaten- und Größenstand. Rowcounts aus DMVs sind für Diagnosezwecke geeignet, aber keine transaktional exakte `COUNT_BIG(*)`-Messung.

### Bewertung und Gegenprobe

Größe, Zeilen, Indexart, Schlüssel/Includes, Filter, Partitionierung, Kompression und Schutzmerkmale zusammen lesen. Ähnliche Schlüsselreihenfolgen können unterschiedliche Coverage, Sortierung oder Constraints bedienen.

### Typische Fehlinterpretation

Inventar zeigt Existenz, nicht Nutzen, Nutzung oder Redundanz. Eine kleine Tabelle mit vielen Indizes kann andere Trade-offs haben als eine große schreibintensive Tabelle.

### Folgeanalyse

`USP_IndexUsage`, `USP_IndexOperationalStats`, Query Store/Plan Cache und Abhängigkeitsprüfung.

[Technische Detailbeschreibung](../03_Object_Index.md#1-monitorusp_objectinventory)
