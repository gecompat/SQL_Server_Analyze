---
skill_format_version: "1.0.0"
name: "monitor.InternalSsisScopePathMatch"
schema_name: "monitor"
object_name: "InternalSsisScopePathMatch"
object_type: "FUNCTION"
database_role: "framework"
is_internal: true
description: "Die Funktion vergleicht einen Pfad ordinal mit einem Root-Präfix und einer geordneten Folge bereits klassifizierter Toolbelt-Schritte."
source_path: "Code/10_SSIS/034_InternalSsisScopePathMatch.sql"
---

# monitor.InternalSsisScopePathMatch

## Zweck und Einsatz

Interne SSIS-Hilfsfunktion für vorab klassifizierte Toolbelt-Pfade; für die fachliche Diagnose ist der öffentliche SSIS-Bericht zu verwenden.

Die Funktion vergleicht einen Pfad ordinal mit einem Root-Präfix und einer geordneten Folge bereits klassifizierter Toolbelt-Schritte.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[InternalSsisScopePathMatch]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien. Sie ist ein interner SSIS-Helfer; Fachaufrufe verwenden die öffentliche SSIS-Analyse.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @Root | nvarchar(4000) | ja | kein Default |
| @Path | nvarchar(4000) | ja | kein Default |
| @Steps | nvarchar(max) | ja | kein Default |

**@Root:** Pflichtwert nvarchar(4000), kein Default. Ordinaler Root-Präfix ohne Wildcard; NULL ergibt IsMatch=0. Der Vergleich verwendet Latin1_General_100_BIN2 und UTF-16-Längen.

**@Path:** Pflichtwert nvarchar(4000), kein Default. Bereits klassifizierter Pfad; er muss genau am Ende der Root-/Schrittfolge enden. NULL ergibt IsMatch=0; es erfolgt kein DTSX-Read.

**@Steps:** Pflichtwert nvarchar(max), kein Default. JSON-Array mit höchstens 32 Schrittobjekten. Jeder Schritt benötigt einen nicht leeren `text`-Wert; `counter` wird mit TRY_CONVERT(bit, ...) umgewandelt und ist keine strikte JSON-Boolean-Prüfung. Bei `counter=1` ist ein nachfolgender Index in eckigen Klammern optional: 1 bis 19 Ziffern, keine führende Null und gültiger bigint-Bereich. JSON_VALUE liest Skalare nur bis nvarchar(4000). NULL kann als leere Folge wirken; das gesamte JSON-Schrittschema wird nicht validiert und ungültige Werte können ungefangene Fehler auslösen.

## Resultate und Ausgabe

Rückgabetyp und Spaltendeklarationen der Funktion:

```sql
RETURNS @Result TABLE([IsMatch] bit NOT NULL)
```


## Beispiel

```sql
SELECT [IsMatch] FROM [monitor].[InternalSsisScopePathMatch](N'ROOT',N'ROOT\NODE[12]',N'[{"text":"\\NODE","counter":1}]');
SELECT [IsMatch] FROM [monitor].[InternalSsisScopePathMatch](N'ROOT',N'ROOT',N'[]');
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
