---
skill_format_version: "1.0.0"
name: "monitor.TVF_ExecutionPlanStatisticsUsage"
schema_name: "monitor"
object_name: "TVF_ExecutionPlanStatisticsUsage"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Extrahiert OptimizerStatsUsage je Statement aus Showplan-XML."
source_path: "Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql"
---

# monitor.TVF_ExecutionPlanStatisticsUsage

## Zweck und Einsatz

Extrahiert OptimizerStatsUsage je Statement aus Showplan-XML. Die Werte beschreiben den im Plan gespeicherten Compilezeitstand.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ExecutionPlanStatisticsUsage]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @PlanXml | xml | ja | kein Default |
| @StatementId | int | nein | NULL |

**@PlanXml:** Pflichtwert xml, kein Default. Bereits vorliegender Showplan mit OptimizerStatsUsage; NULL/strukturell unpassend liefert keine Fundzeilen. Werte beschreiben den gespeicherten Compilezeitstand, nicht heutige Frische.

**@StatementId:** Optionaler int-Wert, Default NULL. NULL berücksichtigt alle gefundenen StmtSimple-Elemente; ein Wert filtert auf passende StatementId. Die Funktion beweist keine Statistikverwendung bei einer konkreten Ausführung.

## Resultate und Ausgabe

Null bis mehrere Statistikbezüge aus OptimizerStatsUsage im Plan-XML. Spalten: `StatisticsUsageOrdinal bigint`, `StatementOrdinal int`, `StatementId int`, `StatementCompId int`, `DatabaseName nvarchar(256)`, `SchemaName nvarchar(256)`, `ObjectName nvarchar(256)`, `StatisticsName nvarchar(256)`, `LastUpdateAtCompile datetime2(7)`, `ModificationCountAtCompile bigint`, `SamplingPercentAtCompile decimal(19,6)`, `SourceElement nvarchar(128)` und `ParseStatus varchar(40)`. Fehlende XML-Attribute bleiben NULL; der Wert bezieht sich auf den Kompilierzeitpunkt, nicht die aktuelle Statistik.

## Beispiel

```sql
DECLARE @PlanXml xml = N'<ShowPlanXML>
<BatchSequence><Batch><Statements><StmtSimple StatementId="1"
StatementCompId="1"><QueryPlan><OptimizerStatsUsage>
<StatisticsInfo Database="[DemoDb]" Schema="[sales]"
  Table="[Orders]" Statistics="[IX_Orders]"
  LastUpdate="2026-01-01T00:00:00" ModificationCount="2"
  SamplingPercent="100"/>
</OptimizerStatsUsage></QueryPlan></StmtSimple></Statements></Batch></BatchSequence>
</ShowPlanXML>';
SELECT *
FROM [monitor].[TVF_ExecutionPlanStatisticsUsage](@PlanXml, NULL);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
