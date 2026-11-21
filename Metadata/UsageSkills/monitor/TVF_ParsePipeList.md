---
skill_format_version: "1.0.0"
name: "monitor.TVF_ParsePipeList"
schema_name: "monitor"
object_name: "TVF_ParsePipeList"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Zerlegt @List anhand nicht bracket-quotierter Pipe-Zeichen in Elemente."
source_path: "Code/01_Common/078_TVF_ParsePipeList.sql"
---

# monitor.TVF_ParsePipeList

## Zweck und Einsatz

Zerlegt @List anhand nicht bracket-quotierter Pipe-Zeichen in Elemente. Pipe-Zeichen innerhalb bracket-quotierter Bereiche trennen nicht; ]] wird dort als maskierte schließende Klammer berücksichtigt.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParsePipeList]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @List | nvarchar(max) | ja | kein Default |

**@List:** Pflichtwert nvarchar(max), kein Default. NULL liefert keine Zeilen, N'' liefert eine EMPTY_LIST-Zeile. Pipe trennt Elemente; leere Segmente ergeben EMPTY_ITEM. Äußere Leerzeichen werden entfernt, Duplikate bleiben. Ein ungetrimmtes Segment über 4000 Zeichen führt zu ITEM_TOO_LONG und ItemText NULL.

## Resultate und Ausgabe

ItemOrdinal int NOT NULL, ItemText nvarchar(4000) NULL, IsBracketQuoted bit NOT NULL, IsValid bit NOT NULL, ErrorCode varchar(40) NULL und ErrorMessage nvarchar(4000) NULL. ItemOrdinal beginnt bei 1 und folgt der Eingabereihenfolge; für diese Reihenfolge ist ORDER BY ItemOrdinal erforderlich. Doppelte Elemente bleiben erhalten. IsValid ist 1, wenn ErrorCode NULL ist, andernfalls 0; ohne Fehler bleiben ErrorCode und ErrorMessage NULL. Text- und Fehlerwerte verwenden die Collation SQL_Latin1_General_CP1_CS_AS.


## Beispiel

```sql
SELECT [ItemOrdinal], [ItemText], [IsBracketQuoted], [IsValid],
                   [ErrorCode], [ErrorMessage]
               FROM [monitor].[TVF_ParsePipeList](
                   N'dbo|[Raum | Name]|[a]]b]')
               ORDER BY [ItemOrdinal];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die Funktion entfernt keine Klammern und entmaskiert ]] nicht. IsBracketQuoted kennzeichnet nur ein nach dem Trimmen mit [ beginnendes und mit ] endendes ItemText; das Flag bestätigt keine vollständige SQL-Identifiergrammatik. Die strukturelle Prüfung löst weder Objekte, Kataloge oder Typen auf noch validiert sie alle Regeln gültiger SQL-Bezeichner.

ErrorMessage ist zum ErrorCode gepaart. Bei mehreren Befunden gilt ITEM_TOO_LONG vor EMPTY_ITEM vor INVALID_BRACKET_SYNTAX. Die Grenze von 4000 Zeichen gilt für das ungetrimmte Segment vor dem Entfernen äußerer Leerzeichen; bei Überlänge ist ItemText NULL.

