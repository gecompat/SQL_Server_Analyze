---
skill_format_version: "1.0.0"
name: "monitor.TVF_ProjectUnicodeText"
schema_name: "monitor"
object_name: "TVF_ProjectUnicodeText"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Projiziert einen bereits materialisierten nvarchar(max)-Wert mit messbarer, aufhebbarer und Surrogate-sicherer Begrenzung."
source_path: "Code/01_Common/087d_TVF_ProjectUnicodeText.sql"
---

# monitor.TVF_ProjectUnicodeText

## Zweck und Einsatz

Projiziert einen bereits materialisierten nvarchar(max)-Wert mit messbarer, aufhebbarer und Surrogate-sicherer Begrenzung.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ProjectUnicodeText]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @Value | nvarchar(max) | ja | kein Default |
| @MaxCharacters | int | ja | kein Default |

**@Value:** Pflichtwert nvarchar(max), kein Default. NULL liefert NULL für projizierten Text und beide Längen, IsTruncated=0. Der Wert wird nicht aus System- oder Benutzerdaten gelesen und nicht anonymisiert.

**@MaxCharacters:** Pflichtwert int, kein Default. NULL oder 0 bedeutet unbegrenzt; positiv begrenzt mit LEFT unter einer SC-Collation und trennt kein Surrogate-Paar. Negative Grenzen validiert der Aufrufer; LEFT kann bei negativem Wert fehlschlagen.

## Resultate und Ausgabe

OriginalCharacters (bigint), OriginalBytes (bigint), IsTruncated (bit) und ProjectedValue (nvarchar(max)). OriginalCharacters zählt unter Latin1_General_100_CI_AS_SC via LEN mit angehängtem NCHAR(1), damit abschließende Leerzeichen mitgezählt werden. OriginalBytes ist DATALENGTH(@Value).


## Beispiel

```sql
SELECT * FROM monitor.TVF_ProjectUnicodeText(N'Beispiel  ', 4);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Zeichen sind keine Grapheme. Es erfolgen keine Reparatur und keine Anonymisierung des Werts.

