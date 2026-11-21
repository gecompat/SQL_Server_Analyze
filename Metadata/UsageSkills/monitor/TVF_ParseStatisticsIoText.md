---
skill_format_version: "1.0.0"
name: "monitor.TVF_ParseStatisticsIoText"
schema_name: "monitor"
object_name: "TVF_ParseStatisticsIoText"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Die Funktion wertet bereits vorliegenden Meldungstext aus SET STATISTICS IO aus."
source_path: "Code/04_PlanCache/044_TVF_ParseStatisticsIoText.sql"
---

# monitor.TVF_ParseStatisticsIoText

## Zweck und Einsatz

Die Funktion wertet bereits vorliegenden Meldungstext aus SET STATISTICS IO aus. Sie führt keine SQL-Anweisung aus und erfasst keine Meldungen selbst.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ParseStatisticsIoText]. Die Funktion verarbeitet nur ihre übergebenen Werte und gegebenenfalls andere installierte Frameworkparser; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @StatisticsIoText | nvarchar(max) | ja | kein Default |
| @StatisticsLanguage | varchar(16) | nein | 'AUTO' |

**@StatisticsIoText:** Pflichtwert nvarchar(max), kein Default. Bereits vorliegender SET STATISTICS IO-Meldungstext; NULL/leer liefert keine Zeile. CRLF/CR/LF trennen Zeilen, @Line nvarchar(4000) kürzt längere Zeilen vor dem Parsing.

**@StatisticsLanguage:** varchar(16), Default 'AUTO'. AUTO, EN und DE werden ohne Beachtung der Schreibweise akzeptiert; NULL/andere Werte werden zu AUTO. Der Wert beeinflusst die Erkennung nicht, die über hinterlegte Scan-Labels erfolgt.

## Resultate und Ausgabe

Jede erkannte Zeile mit „scan count“ oder „scananzahl“ erzeugt eine Zeile. Die elf Messspalten enthalten ScanCount, LogicalReads, PhysicalReads, PageServerReads, ReadAheadReads, PageServerReadAheadReads sowie die entsprechenden fünf Lob-Messwerte. Nicht erkannte oder nicht konvertierbare Werte bleiben NULL. ObjectDisplayName enthält den Text zwischen den ersten beiden einfachen Anführungszeichen, falls beide vorhanden sind; der Ausgabepuffer fasst höchstens 512 Zeichen. LanguageDetected meldet EN oder DE anhand des Scan-Labels. ParseStatus ist PARSED, wenn Objektname, ScanCount und LogicalReads vorliegen; andernfalls ist PARSED_PARTIAL. RawLine enthält die getrimmte Eingabezeile, höchstens 4000 Zeichen. MessageOrdinal und ObjectOrdinal zählen erkannte Zeilen in der Verarbeitung; StatementOrdinal ist immer NULL. Die Funktion ordnet Meldungen keinem SQL-Statement zu und legt keine Resultatreihenfolge fest.


## Beispiel

```sql
SELECT * FROM [monitor].[TVF_ParseStatisticsIoText] (N'Table ''[demo].[Orders]''. Scan count 1, logical reads 8, ' + N'physical reads 0, read-ahead reads 0, lob logical reads 0.', 'AUTO');
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Nur Zeilen mit einem erkannten Scan-Label werden ausgegeben; andere Zeilen bleiben unberücksichtigt. Messwerte werden aus Ziffern und einem möglichen Minuszeichen nach den hinterlegten englischen oder deutschen Labels mit TRY_CONVERT(bigint) gelesen. PARSED bestätigt nur die genannten Pflichtfelder, nicht die Richtigkeit oder Vollständigkeit aller Messwerte. Der Beispieltext ist synthetisch.

