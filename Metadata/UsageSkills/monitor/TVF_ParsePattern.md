---
skill_format_version: "1.0.0"
name: "monitor.TVF_ParsePattern"
schema_name: "monitor"
object_name: "TVF_ParsePattern"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Zerlegt ein optionales LIKE- oder Regex-Präfix und liefert den unverändert verbleibenden Patterninhalt samt Modus und Flags."
source_path: "Code/01_Common/079_TVF_ParsePattern.sql"
---

# monitor.TVF_ParsePattern

## Zweck und Einsatz

Zerlegt ein optionales LIKE- oder Regex-Präfix und liefert den unverändert verbleibenden Patterninhalt samt Modus und Flags.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParsePattern]. Die Funktion verarbeitet nur ihre übergebenen Werte und gegebenenfalls andere installierte Frameworkparser; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @Pattern | nvarchar(4000) | ja | kein Default |

**@Pattern:** Pflichtwert nvarchar(4000), kein Default. NULL ergibt gültigen Modus NONE; leerer oder nur aus Leerzeichen bestehender Text ergibt EMPTY_PATTERN. Äußere Leerzeichen werden entfernt, dann wird regexi:, regex: oder like: ohne Beachtung der Großschreibung erkannt. Ein leerer Inhalt nach Präfix ergibt EMPTY_PATTERN. Die Funktion validiert keine Regex-Syntax.

## Resultate und Ausgabe

Genau eine Zeile pro Aufruf. Spalten: `PatternMode varchar(8)` (NONE, LIKE, REGEX oder REGEXI), `PatternValue nvarchar(4000)` in binär unterscheidender Kollation, `RegexFlags varchar(8)` (c/i oder NULL), `IsRegex bit`, `IsValid bit`, `ErrorCode varchar(40)` und `ErrorMessage nvarchar(4000)` (beide NULL bei gültiger Eingabe). Die Funktion prüft Syntaxform und Leerwert, führt aber keinen Regex aus.

## Beispiel

```sql
SELECT * FROM [monitor].[TVF_ParsePattern](N' regexi:^App '); SELECT * FROM [monitor].[TVF_ParsePattern](N'LIKE:');
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
