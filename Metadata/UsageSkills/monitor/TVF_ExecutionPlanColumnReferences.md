---
skill_format_version: "1.0.0"
name: "monitor.TVF_ExecutionPlanColumnReferences"
schema_name: "monitor"
object_name: "TVF_ExecutionPlanColumnReferences"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Normalisiert Spaltenrollen aus Showplan-XML für zielgerichtete Index- und Statistikauflösung."
source_path: "Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql"
---

# monitor.TVF_ExecutionPlanColumnReferences

## Zweck und Einsatz

Normalisiert Spaltenrollen aus Showplan-XML für zielgerichtete Index- und Statistikauflösung. Keine Katalogzugriffe.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ExecutionPlanColumnReferences]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @PlanXml | xml | ja | kein Default |
| @StatementId | int | nein | NULL |

**@PlanXml:** Pflichtwert xml, kein Default. Bereits vorliegender Showplan; NULL/strukturell unpassend liefert keine ColumnReference-Zeilen. Die Funktion führt den Plan nicht aus und löst Namen nicht gegen Kataloge auf.

**@StatementId:** Optionaler int-Wert, Default NULL. NULL berücksichtigt alle gefundenen StmtSimple-Elemente; ein Wert filtert auf passende StatementId. Die Rollen beruhen nur auf den implementierten RelOp-Pfaden.

## Resultate und Ausgabe

Null bis mehrere Spaltenbezüge aus dem Plan-XML, nur bei vorhandenem ColumnRaw. Spalten: `ColumnReferenceOrdinal bigint`, `StatementOrdinal int`, `StatementId int`, `StatementCompId int`, `NodeId int`, `ColumnUsage varchar(40)`, `ExpressionContext varchar(80)`, `DatabaseName nvarchar(256)`, `SchemaName nvarchar(256)`, `ObjectName nvarchar(256)`, `AliasName nvarchar(256)`, `ColumnName nvarchar(256)` und die Bits `IsSeekColumn`, `IsResidualPredicateColumn`, `IsJoinColumn`, `IsGroupByColumn`, `IsOrderByColumn`, `IsOutputColumn`, `IsPartitionColumn`. XML-Namen können unvollständig sein; diese Bezüge ersetzen keine aktuelle Katalogprüfung.

## Beispiel

```sql
DECLARE @PlanXml xml = N'<ShowPlanXML>
<BatchSequence><Batch><Statements><StmtSimple StatementId="1"
StatementCompId="1"><QueryPlan><RelOp NodeId="0"><IndexScan>
<SeekPredicates><SeekPredicateNew><SeekKeys><Prefix>
  <ColumnReference Database="[DemoDb]" Schema="[sales]"
    Table="[Orders]" Column="[OrderId]"/>
</Prefix></SeekKeys></SeekPredicateNew></SeekPredicates>
</IndexScan></RelOp></QueryPlan></StmtSimple></Statements></Batch></BatchSequence>
</ShowPlanXML>';
SELECT *
FROM [monitor].[TVF_ExecutionPlanColumnReferences](@PlanXml, NULL);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
