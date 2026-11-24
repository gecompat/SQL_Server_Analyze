---
skill_format_version: "1.0.0"
name: "monitor.TVF_ParseSqlNameList"
schema_name: "monitor"
object_name: "TVF_ParseSqlNameList"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Prüft die Namen einer bracket-aware Pipe-Liste anhand von PARSENAME und liefert die in sysname konvertierten Namenswerte."
source_path: "Code/01_Common/080_TVF_ParseSqlNameList.sql"
---

# monitor.TVF_ParseSqlNameList

## Zweck und Einsatz

Prüft die Namen einer bracket-aware Pipe-Liste anhand von PARSENAME und liefert die in sysname konvertierten Namenswerte.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParseSqlNameList]. Die Funktion nutzt [monitor].[TVF_ParsePipeList] für die bracketbewusste Zerlegung und prüft die resultierenden Namen; sie liest selbst keine DMVs, fremden Datenbanken oder Dateien. Die Ausführbarkeit der installierten Funktionskette hängt vom Datenbankkontext und dessen Berechtigungsauflösung ab; ein gesonderter GRANT auf jede interne Abhängigkeit wird daraus nicht behauptet.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @List | nvarchar(max) | ja | kein Default |

**@List:** Pflichtwert nvarchar(max), kein Default. NULL liefert keine Zeile, N'' eine ungültige EMPTY_LIST-Zeile. Pipe trennt nur außerhalb eckiger Klammern, ]] maskiert eine schließende Klammer. Leere Elemente und Duplikate bleiben erhalten; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ITEM_TOO_LONG.

## Resultate und Ausgabe

ItemOrdinal und ItemText beschreiben die Eingabe. NameValue wird auch bei ungültigen Zeilen aus PARSENAME(ItemText,1) berechnet. IsValid, ErrorCode und ErrorMessage kennzeichnen die Prüfung; ein nicht leeres NameValue ersetzt deshalb keine IsValid-Prüfung.


## Beispiel

```sql
SELECT * FROM [monitor].[TVF_ParseSqlNameList](
                   N'[ColumnOne]|[Column With Spaces]|[Column|WithPipe]')
               ORDER BY ItemOrdinal;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

EMPTY_LIST ist der Sonderfall der leeren Eingabe. Für Elemente prüft der gemeinsame Parser zuerst ITEM_TOO_LONG, danach EMPTY_ITEM und danach INVALID_BRACKET_SYNTAX. Seine Fehler haben Vorrang. Für dort gültige Elemente folgt INVALID_SQL_NAME bei fehlendem Teil 1. Ein vorhandener Teil 2 oder ein Punkt außerhalb eines einzelnen vollständig quotierten Namens führt zu MULTIPART_NAME_NOT_ALLOWED. Das gilt auch für ausgelassene Qualifizierer. Die anschließende Längenprüfung von Teil 1 verwendet LEN und meldet SQL_NAME_TOO_LONG bei mehr als 128 Zeichen.

Ein Punkt innerhalb eines einzelnen mit eckigen Klammern oder doppelten Anführungszeichen quotierten Namens ist zulässig. Der Vergleich mit der quotierten Form des nativen Namens erfolgt bytegenau. Die Funktion prüft weder die vollständige SQL-Bezeichnergrammatik noch Katalogexistenz oder Berechtigungen. Sie gibt fehlerhafte Zeilen mit Fehlercode aus, liest keine Kataloge und schreibt keine Daten. Eine physische Reihenfolge erfordert ORDER BY ItemOrdinal.

