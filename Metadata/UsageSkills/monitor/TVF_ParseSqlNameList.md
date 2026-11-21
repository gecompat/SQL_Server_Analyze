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

EMPTY_LIST ist der Sonderfall der leeren Eingabe. Für Elemente prüft der gemeinsame Parser zuerst ITEM_TOO_LONG, danach EMPTY_ITEM und danach INVALID_BRACKET_SYNTAX. Seine Fehler haben Vorrang vor der nachfolgenden Namensprüfung. Für dort gültige Elemente prüft diese Funktion Teil 1 auf NULL (INVALID_SQL_NAME), danach Teil 2 auf einen Wert (MULTIPART_NAME_NOT_ALLOWED) und danach LEN(Teil 1)>128 (SQL_NAME_TOO_LONG). Für IsValid=1 muss Teil 1 ungleich NULL und Teil 2 gleich NULL sein; LEN(Teil 1) darf höchstens 128 ergeben.

Teile 3 und 4 werden nicht gesondert geprüft. Dies ist keine allgemeine SQL-Bezeichnervalidierung und keine Prüfung von Katalogexistenz oder Berechtigungen. Fehlerhafte Zeilen werden ausgegeben und nicht durch die Funktion als Fehler geworfen. Eine physische Reihenfolge ist erst mit ORDER BY ItemOrdinal zugesichert. Die Funktion liest keine Kataloge und speichert nichts.

