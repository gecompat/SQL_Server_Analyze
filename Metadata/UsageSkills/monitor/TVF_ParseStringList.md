---
skill_format_version: "1.0.0"
name: "monitor.TVF_ParseStringList"
schema_name: "monitor"
object_name: "TVF_ParseStringList"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Liefert allgemeine Textwerte aus einer bracket-aware Pipe-Liste; ein Punkt besitzt hier keine Bedeutung als Mehrteilname."
source_path: "Code/01_Common/086_TVF_ParseStringList.sql"
---

# monitor.TVF_ParseStringList

## Zweck und Einsatz

Liefert allgemeine Textwerte aus einer bracket-aware Pipe-Liste; ein Punkt besitzt hier keine Bedeutung als Mehrteilname.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParseStringList]. Die Funktion verarbeitet nur ihre übergebenen Werte und gegebenenfalls andere installierte Frameworkparser; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @List | nvarchar(max) | ja | kein Default |

**@List:** Pflichtwert nvarchar(max), kein Default. NULL liefert keine Zeile, N'' eine ungültige EMPTY_LIST-Zeile. Pipe trennt nur außerhalb eckiger Klammern, ]] maskiert eine schließende Klammer. Leere Elemente und Duplikate bleiben. Bei bracket-quotierten Elementen wird der Wert entquotet; ein danach leerer Wert ist ungültig.

## Resultate und Ausgabe

ItemOrdinal, ItemText, StringValue, IsValid, ErrorCode und ErrorMessage beschreiben jedes Element. StringValue wird auch für ungültige Elemente berechnet; Verbraucher müssen IsValid prüfen und dürfen Gültigkeit nicht aus dem Wert allein ableiten.


## Beispiel

```sql
SELECT * FROM monitor.TVF_ParseStringList(
                   N'[Sample.Loader]|[Text with | delimiter]|[right]]bracket]')
               ORDER BY ItemOrdinal;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

EMPTY_LIST ist der Sonderfall der leeren Eingabe. Bei Elementen prüft der gemeinsame Parser zuerst ITEM_TOO_LONG, danach EMPTY_ITEM und danach INVALID_BRACKET_SYNTAX. Diese Fehler haben Vorrang; erst bei gültigem Parserergebnis kennzeichnet diese Funktion einen leeren entquoteten Wert als EMPTY_VALUE.

Fehlerhafte Elemente bleiben als Ergebniszeilen erhalten und werden nicht als Fehler geworfen. Eine physische Reihenfolge ist erst mit ORDER BY ItemOrdinal zugesichert. Die Funktion prüft keine Katalogexistenz und liest oder persistiert keine Fachdaten.

