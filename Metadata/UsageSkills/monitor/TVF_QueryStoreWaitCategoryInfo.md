---
skill_format_version: "1.0.0"
name: "monitor.TVF_QueryStoreWaitCategoryInfo"
schema_name: "monitor"
object_name: "TVF_QueryStoreWaitCategoryInfo"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Ordnet eine Query-Store-Wait-Kategorie einer normalisierten WaitGroup zu und"
source_path: "Code/01_Common/076_TVF_QueryStoreWaitCategoryInfo.sql"
---

# monitor.TVF_QueryStoreWaitCategoryInfo

## Zweck und Einsatz

Ordnet eine Query-Store-Wait-Kategorie einer normalisierten WaitGroup zu und

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_QueryStoreWaitCategoryInfo]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @WaitCategoryDesc | nvarchar(128) | ja | kein Default |

**@WaitCategoryDesc:** Pflichtwert nvarchar(128), kein Default. NULL, leerer Text und unbekannte Werte sind zulässig. NULL wird für WaitGroup als Unknown behandelt; leerer Text bleibt leer. Die SQL-Typbindung kann längere Eingaben bereits vor dem Funktionskörper kürzen.

## Resultate und Ausgabe

Eine Zeile pro Aufruf. Die Funktion bildet die Query-Store-Wait-Kategorie aus der Eingabe ab; NULL erhält die Gruppe UNKNOWN. Spalten: `WaitGroup nvarchar(64)`, `Meaning nvarchar(1000)`, `TypicalOccurrence nvarchar(1200)`, `HighWaitImpact nvarchar(1200)` und `RecommendedChecks nvarchar(1500)`. Die Texte sind Deutungshilfen und keine Messung einer laufenden Query.

## Beispiel

```sql
SELECT * FROM [monitor].[TVF_QueryStoreWaitCategoryInfo](N'Buffer IO');
SELECT * FROM [monitor].[TVF_QueryStoreWaitCategoryInfo](NULL);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
