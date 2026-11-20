---
skill_format_version: "1.0.0"
name: "monitor.TVF_ClassifyErrorLogEvent"
schema_name: "monitor"
object_name: "TVF_ClassifyErrorLogEvent"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Die Inline-TVF ordnet eine übergebene Errorlogmeldung genau einer Kategorie zu und liefert stets eine Zeile mit [Category]."
source_path: "Code/01_Common/087e_TVF_ClassifyErrorLogEvent.sql"
---

# monitor.TVF_ClassifyErrorLogEvent

## Zweck und Einsatz

Die Inline-TVF ordnet eine übergebene Errorlogmeldung genau einer Kategorie zu und liefert stets eine Zeile mit [Category]. Sie liest selbst keine Errorlogdaten und persistiert keine Ergebnisse. @ProductName bezeichnet das Produkt, @RuleCategory die zuvor ermittelte Regelkategorie und @MessageText den Meldungstext; alle drei Eingaben sind erforderlich.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ClassifyErrorLogEvent]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ProductName | varchar(32) | ja | kein Default |
| @RuleCategory | varchar(80) | ja | kein Default |
| @MessageText | nvarchar(max) | ja | kein Default |

**@ProductName:** Pflichtwert varchar(32), kein Default. Produktbezeichner für die erste SQL_AGENT-Regel; der Vergleich folgt der Datenbankkollation. NULL löst keinen separaten Fehler aus, und andere Namen können über Meldungsmuster klassifiziert werden.

**@RuleCategory:** Pflichtwert varchar(80), kein Default. Bereits ermittelte Regelkategorie als Fallback, falls kein priorisiertes Meldungsmuster greift. NULL ergibt UNCLASSIFIED, leer bleibt leer; die Ausgabe wird auf varchar(80) konvertiert.

**@MessageText:** Pflichtwert nvarchar(max), kein Default. Bereits vorliegender Errorlogtext; die Funktion liest keinen Log. Englische Teilzeichenfolgen werden mit expliziter CI-Collation heuristisch geprüft; NULL führt ohne Sonderfehler zum Fallback.

## Resultate und Ausgabe

Genau eine Zeile mit `Category varchar(80)`. Der CASE klassifiziert den übergebenen Ereignistext und ProductName; ohne passende interne Regel wird der übergebene RuleCategory-Wert oder UNCLASSIFIED verwendet. Die Funktion liest selbst kein Fehlerlog.

## Beispiel

```sql
SELECT *
FROM [monitor].[TVF_ClassifyErrorLogEvent]
     ('SQL', 'CUSTOM_RULE', N'Autogrow completed');
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
