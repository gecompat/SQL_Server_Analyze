---
skill_format_version: "1.0.0"
name: "monitor.TVF_ParseBigintList"
schema_name: "monitor"
object_name: "TVF_ParseBigintList"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Zerlegt eine Liste ganzzahliger bigint-Werte."
source_path: "Code/01_Common/085_TVF_ParseBigintList.sql"
---

# monitor.TVF_ParseBigintList

## Zweck und Einsatz

Zerlegt eine Liste ganzzahliger bigint-Werte. Pipe, Beistrich und Strichpunkt sind gleichwertige Trennzeichen und dürfen gemischt auftreten.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParseBigintList]. Die Funktion verarbeitet nur ihre übergebenen Werte und gegebenenfalls andere installierte Frameworkparser; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @List | nvarchar(max) | ja | kein Default |

**@List:** Pflichtwert nvarchar(max), kein Default. NULL liefert keine Zeile, N'' eine ungültige EMPTY_LIST-Zeile. Pipe, Beistrich und Strichpunkt werden als Trenner verarbeitet, auch innerhalb eckiger Klammern. Negative konvertierbare bigint-Werte können gültig sein; ein fachlicher ID-Bereich wird hier nicht geprüft.

## Resultate und Ausgabe

ItemOrdinal, ItemText, NumberValue, IsValid, ErrorCode und ErrorMessage. Die Listenzerlegung erhält Reihenfolge und Duplikate; ungültige Elemente bleiben als Zeilen erhalten.


## Beispiel

```sql
SELECT * FROM monitor.TVF_ParseBigintList(N'57|61, -2;57') ORDER BY ItemOrdinal;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

EMPTY_LIST ist der Sonderfall der leeren Eingabe. Für Elemente gilt ITEM_TOO_LONG vor EMPTY_ITEM vor INVALID_BRACKET_SYNTAX. Erst bei gültiger Listenstruktur kennzeichnet eine gescheiterte bigint-Konvertierung das Element als INVALID_BIGINT.

