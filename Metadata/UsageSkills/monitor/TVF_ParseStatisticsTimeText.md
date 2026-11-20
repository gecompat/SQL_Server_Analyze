---
skill_format_version: "1.0.0"
name: "monitor.TVF_ParseStatisticsTimeText"
schema_name: "monitor"
object_name: "TVF_ParseStatisticsTimeText"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Die Funktion wertet bereits vorliegenden Meldungstext aus SET STATISTICS TIME aus."
source_path: "Code/04_PlanCache/045_TVF_ParseStatisticsTimeText.sql"
---

# monitor.TVF_ParseStatisticsTimeText

## Zweck und Einsatz

Die Funktion wertet bereits vorliegenden Meldungstext aus SET STATISTICS TIME aus. Sie führt keine SQL-Anweisung aus und erfasst keine Meldungen selbst.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParseStatisticsTimeText]. Die Funktion verarbeitet nur ihre übergebenen Werte und gegebenenfalls andere installierte Frameworkparser; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @StatisticsTimeText | nvarchar(max) | ja | kein Default |
| @StatisticsLanguage | varchar(16) | nein | 'AUTO' |

**@StatisticsTimeText:** Pflichtwert nvarchar(max), kein Default. NULL oder leerer Text liefert keine Zeile. CRLF, CR und LF trennen Zeilen; äußere Leerzeichen entfallen. Eingabezeilen über 4000 Zeichen werden vor der Auswertung auf nvarchar(4000) gekürzt.

**@StatisticsLanguage:** Optionaler varchar(16)-Parameter mit Default 'AUTO'. Der Funktionskörper verwendet ihn derzeit nicht; sein Wert ändert die Auswertung nicht.

## Resultate und Ausgabe

Eine Zeile entsteht für eine Zeile mit „cpu time =“, „cpu-zeit =“, „elapsed time =“ oder „verstrichene zeit =“. CpuMs und ElapsedMs enthalten die nach dem jeweiligen Label mit TRY_CONVERT(bigint) gelesene Zahl; fehlende oder nicht konvertierbare Werte bleiben NULL. TimeCategory ist PARSE_COMPILE, EXECUTION oder UNKNOWN und folgt den im Meldungstext erkannten Überschriften; ohne passende Überschrift bleibt der anfängliche Wert UNKNOWN. LanguageDetected meldet EN oder DE anhand der erkannten Überschrift und bleibt EN, wenn keine Überschrift erkannt wurde. ParseStatus ist PARSED, wenn eine bekannte Kategorie sowie beide Messwerte vorliegen; andernfalls ist PARSED_PARTIAL. RawLine enthält die getrimmte Eingabezeile, höchstens 4000 Zeichen. MessageOrdinal zählt ausgegebene Zeilen; StatementOrdinal ist immer NULL. Die Funktion ordnet Meldungen keinem SQL-Statement zu und legt keine Resultatreihenfolge fest.


## Beispiel

```sql
SELECT * FROM [monitor].[TVF_ParseStatisticsTimeText] (N'SQL Server parse and compile time: CPU time = 3 ms, ' + N'elapsed time = 5 ms.', 'AUTO');
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Parser erkennt nur die im Funktionskörper hinterlegten englischen und deutschen Textteile. Die Kategorie bleibt über nachfolgende Zeilen erhalten, bis eine andere Überschrift erkannt wird. PARSED bestätigt nur bekannte Kategorie und beide konvertierten Werte, nicht deren Richtigkeit oder Vollständigkeit. Der Beispieltext ist synthetisch.

