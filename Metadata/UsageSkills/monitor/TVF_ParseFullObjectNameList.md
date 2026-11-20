---
skill_format_version: "1.0.0"
name: "monitor.TVF_ParseFullObjectNameList"
schema_name: "monitor"
object_name: "TVF_ParseFullObjectNameList"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Zerlegt eine Pipe-Liste und prüft ein-, zwei- oder dreiteilige"
source_path: "Code/01_Common/081_TVF_ParseFullObjectNameList.sql"
---

# monitor.TVF_ParseFullObjectNameList

## Zweck und Einsatz

Zerlegt eine Pipe-Liste und prüft ein-, zwei- oder dreiteilige

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParseFullObjectNameList]. Die Funktion verarbeitet nur ihre übergebenen Werte und gegebenenfalls andere installierte Frameworkparser; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @List | nvarchar(max) | ja | kein Default |

**@List:** Pflichtwert nvarchar(max), kein Default. NULL liefert keine Zeile, N'' eine ungültige EMPTY_LIST-Zeile. Pipe trennt nur außerhalb eckiger Klammern; ]] maskiert eine schließende Klammer. Äußere Leerzeichen entfallen, Duplikate bleiben; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ITEM_TOO_LONG. Es wird kein fehlender Datenbank- oder Schemaname ergänzt.

## Resultate und Ausgabe

ItemOrdinal, ItemText, DatabaseName, SchemaName, ObjectName, PartCount, IsValid, ErrorCode und ErrorMessage. Die drei Namensfelder enthalten die von PARSENAME entquoteten Bestandteile als sysname. PartCount ist 3 bei vorhandenem Teil 3, sonst 2 bei Teil 2, sonst 1 bei Teil 1 und sonst 0; Teil 4 wird dabei nicht gezählt. Dieser Wert wird unabhängig von IsValid berechnet. Ungültige Listenelemente behalten ihre Fehlerangaben; vorhandene Namenswerte oder PartCount beweisen allein keine Gültigkeit. Duplikate bleiben erhalten. Die physische Reihenfolge erfordert ORDER BY ItemOrdinal.


## Beispiel

```sql
SELECT * FROM [monitor].[TVF_ParseFullObjectNameList]( N'[DeineDatenbank].dbo.[IrgendeinObjekt]|dbo.AnderesObjekt') ORDER BY ItemOrdinal;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Fehler der Listenzerlegung werden übernommen. Bei leerer Eingabe gilt EMPTY_LIST als Sonderfall. Für Elementfehler gilt danach ITEM_TOO_LONG vor EMPTY_ITEM vor INVALID_BRACKET_SYNTAX. Bei gültiger Listenstruktur folgen INVALID_OBJECT_REFERENCE bei fehlendem Objektteil, FOUR_PART_NAME_NOT_ALLOWED bei vorhandenem Teil 4 und SCHEMA_NAME_REQUIRED bei Teil 3 ohne Teil 2. Die letzte CASE-Regel SQL_NAME_TOO_LONG prüft die Länge geparster Teile. PARSENAME liefert für überlange Bestandteile bereits NULL; daher ist für eine Längenverletzung kein bestimmter Fehlercode zugesichert und eine frühere Regel kann greifen.

