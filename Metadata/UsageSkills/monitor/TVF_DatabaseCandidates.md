---
skill_format_version: "1.0.0"
name: "monitor.TVF_DatabaseCandidates"
schema_name: "monitor"
object_name: "TVF_DatabaseCandidates"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Liefert sichtbare, online befindliche, zugreifbare Datenbanken, die den optionalen exakten Namen und das Pattern erfüllen."
source_path: "Code/01_Common/082_TVF_DatabaseCandidates.sql"
---

# monitor.TVF_DatabaseCandidates

## Zweck und Einsatz

Liefert sichtbare, online befindliche, zugreifbare Datenbanken, die den optionalen exakten Namen und das Pattern erfüllen.

## Voraussetzungen und Rechte

Der Aufruf braucht SELECT auf [monitor].[TVF_DatabaseCandidates] im vorgesehenen Datenbankkontext. Die Funktion nutzt `master.sys.databases`, HAS_DBACCESS und die beiden Namens-/Patternparser unter dem aktuellen Caller. Metadatensicht, ONLINE-Status und Zugang begrenzen die Zeilen; eine ausgeblendete Datenbank ist kein Existenzbeweis.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |

**@DatabaseNames:** Optionaler nvarchar(max)-Filter. NULL, leer oder nur U+0020 bedeutet keine Namenseinschränkung. Sonst verwendet die Funktion TVF_ParseSqlNameList; ungültige Elemente werden still ignoriert, doppelte gültige Namen können Zeilen vervielfachen.

**@SystemdatenbankenEinbeziehen:** bit, Default 0. Nur gebundenes 1 bezieht Datenbanken mit ID bis 4 ein; sonst bleiben sie ausgeschlossen. Die Funktion prüft die Sichtbarkeit, ONLINE und HAS_DBACCESS.

**@DatabaseNamePattern:** Optionales nvarchar(4000)-Pattern. NULL deaktiviert es. TVF_ParsePattern klassifiziert LIKE-/Regex-Form, diese Funktion selbst wertet REGEX/REGEXI nicht aus; der versionsadaptive Aufrufer trägt diese Verantwortung.

## Resultate und Ausgabe

Null bis mehrere sichtbare ONLINE-Datenbanken nach Filter. Spalten: `DatabaseId int`, `DatabaseName sysname`, `StateDesc nvarchar(60)`, `UserAccessDesc nvarchar(60)`, `IsReadOnly bit`, `CompatibilityLevel tinyint`, `CollationName sysname`, `RecoveryModelDesc nvarchar(60)`, `IsSystemDatabase bit`, `RequestedOrdinal int` (NULL ohne expliziten Namensfilter). Die Zeile beschreibt Katalogsicht und Zugriff des aktuellen Callers, keine garantierte spätere Erreichbarkeit.

## Beispiel

```sql
SELECT * FROM [monitor].[TVF_DatabaseCandidates](NULL, 0, NULL); SELECT * FROM [monitor].[TVF_DatabaseCandidates](N'AppDb', 0, N'App%');
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
