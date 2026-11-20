---
skill_format_version: "1.0.0"
name: "monitor.TVF_ToolBackgroundQueryInfo"
schema_name: "monitor"
object_name: "TVF_ToolBackgroundQueryInfo"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Wertet aktivierte LIKE-Regeln aus ToolBackgroundQueryPattern aus."
source_path: "Code/01_Common/087c_TVF_ToolBackgroundQueryInfo.sql"
---

# monitor.TVF_ToolBackgroundQueryInfo

## Zweck und Einsatz

Wertet aktivierte LIKE-Regeln aus ToolBackgroundQueryPattern aus.

## Voraussetzungen und Rechte

Der Aufruf braucht SELECT auf [monitor].[TVF_ToolBackgroundQueryInfo] im vorgesehenen Datenbankkontext. Die Funktion liest aktive Muster aus `monitor.ToolBackgroundQueryPattern` und vergleicht den übergebenen Programmnamen; sie greift nicht auf laufende SQL-Texte zu.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ProgramName | nvarchar(128) | ja | kein Default |

**@ProgramName:** Pflichtwert nvarchar(128), kein Default. Ein einzelner Programmname für Musterabgleich; die Funktion liest nur monitor.ToolBackgroundQueryPattern, weder DMV noch SQL-Text. NULL oder leerer Text ergibt nach den vorhandenen Musterregeln keinen belegten Programmnamen.

## Resultate und Ausgabe

Genau eine Zeile pro Aufruf. Spalten: `IsToolBackgroundQuery bit`, `ToolBackgroundRuleCode varchar(64)`, `ToolBackgroundCategory varchar(40)`, `ToolBackgroundDetection varchar(40)` und `ToolBackgroundConfidence varchar(16)`. Die vier Regelspalten sind NULL ohne aktiv passende Regel. Ein TOP-1-Treffer folgt Priority absteigend und RuleCode; die Funktion liest nur konfigurierte Programmnamenmuster, keine laufenden Querytexte.

## Beispiel

```sql
SELECT * FROM [monitor].[TVF_ToolBackgroundQueryInfo](N'Beispielprogramm');
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
