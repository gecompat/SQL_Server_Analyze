---
skill_format_version: "1.0.0"
name: "monitor.TVF_StatementText"
schema_name: "monitor"
object_name: "TVF_StatementText"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Die Funktion ermittelt den Statement-Ausschnitt eines übergebenen nvarchar(max)-Batches anhand der Request-Offsets und liefert Offset-, Zeichen-, Zeilen-, Längen- und Textausgaben."
source_path: "Code/01_Common/087_TVF_StatementText.sql"
---

# monitor.TVF_StatementText

## Zweck und Einsatz

Die Funktion ermittelt den Statement-Ausschnitt eines übergebenen nvarchar(max)-Batches anhand der Request-Offsets und liefert Offset-, Zeichen-, Zeilen-, Längen- und Textausgaben.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_StatementText]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @BatchText | nvarchar(max) | ja | kein Default |
| @StatementStartOffsetBytes | int | ja | kein Default |
| @StatementEndOffsetBytes | int | ja | kein Default |

**@BatchText:** Pflichtwert nvarchar(max), kein Default. NULL macht den Statementtext ungültig und ergibt NULL-Text; die Funktion parst den Batch nicht als SQL. DATALENGTH bestimmt die UTF-16-Byte-/Codeunit-Grenze.

**@StatementStartOffsetBytes:** Pflichtwert int, kein Default. NULL bedeutet intern Start 0 und HasStatementOffsets=0; der öffentliche Startoffset bleibt NULL. Ein Wert muss nichtnegativ, gerade und innerhalb DATALENGTH des Batchs liegen.

**@StatementEndOffsetBytes:** Pflichtwert int, kein Default. NULL oder -1 bedeutet intern Batchende; bei gesetztem Startoffset wird öffentlich -1 ausgegeben. Ein anderer Wert muss gerade, nichtnegativ, mindestens Start und höchstens DATALENGTH sein; das Ende zählt inklusiv.

## Resultate und Ausgabe

HasStatementOffsets, IsStatementOffsetValid, StatementStartOffsetBytes, StatementEndOffsetBytes, StatementStartCharacter, StatementEndCharacter, StatementStartLine, StatementEndLine, StatementCharacterCount, BatchCharacterCount und StatementText. Ungültiger Text oder ungültige Positionen ergeben NULL-Text; Flags und Offsets folgen jeweils den obigen Quellregeln und sind nicht pauschal alle NULL.


## Beispiel

```sql
SELECT * FROM monitor.TVF_StatementText(N'SELECT 1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
