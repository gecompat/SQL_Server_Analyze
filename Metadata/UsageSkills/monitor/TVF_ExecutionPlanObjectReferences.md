---
skill_format_version: "1.0.0"
name: "monitor.TVF_ExecutionPlanObjectReferences"
schema_name: "monitor"
object_name: "TVF_ExecutionPlanObjectReferences"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Extrahiert statement- und operatorbezogene Objekt-/Indexreferenzen ausschließlich aus übergebenem Showplan-XML."
source_path: "Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql"
---

# monitor.TVF_ExecutionPlanObjectReferences

## Zweck und Einsatz

Extrahiert statement- und operatorbezogene Objekt-/Indexreferenzen ausschließlich aus übergebenem Showplan-XML. Keine Katalogzugriffe.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ExecutionPlanObjectReferences]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @PlanXml | xml | ja | kein Default |
| @StatementId | int | nein | NULL |

**@PlanXml:** Pflichtwert xml, kein Default. Bereits vorliegender Showplan; NULL/strukturell unpassend liefert keine Referenzzeilen. Ungültiger XML-Text scheitert bei Bindung vor der Funktion; die Funktion führt keinen Plan aus.

**@StatementId:** Optionaler int-Wert, Default NULL. NULL berücksichtigt alle gefundenen StmtSimple-Elemente; ein Wert filtert auf passende StatementId. Die Funktion löst Referenzen nicht im Katalog auf.

## Resultate und Ausgabe

Null bis mehrere Objektbezüge aus den XML-Statements. Spalten: `ReferenceOrdinal bigint`, `StatementOrdinal int`, `StatementId int`, `StatementCompId int`, `NodeId int`, `ReferenceType varchar(40)`, `ReferenceSource varchar(40)`, `DatabaseName nvarchar(256)`, `SchemaName nvarchar(256)`, `ObjectName nvarchar(256)`, `IndexName nvarchar(256)`, `AliasName nvarchar(256)`, `StorageType nvarchar(128)`, `PlanObjectId int`, `PlanIndexId int`, `IsTemporaryObject bit`, `IsTableVariable bit`, `IsRemoteObject bit`, `IsDmlTarget bit`, `ResolutionCapability varchar(40)` und `SourceElement nvarchar(128)`. Fehlende XML-Attribute ergeben NULL; Planbezüge belegen keine aktuelle Objektauflösung.

## Beispiel

```sql
DECLARE @PlanXml xml = N'<ShowPlanXML>
<BatchSequence><Batch><Statements><StmtSimple StatementId="1"
StatementCompId="1"><QueryPlan><RelOp NodeId="0" PhysicalOp="Index Seek">
<IndexScan><Object Database="[DemoDb]" Schema="[sales]"
  Table="[Orders]" Index="[IX_Orders]" Alias="[o]"
  Storage="RowStore" ObjectId="12"/></IndexScan>
</RelOp></QueryPlan></StmtSimple></Statements></Batch></BatchSequence>
</ShowPlanXML>';
SELECT *
FROM [monitor].[TVF_ExecutionPlanObjectReferences](@PlanXml, NULL);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
