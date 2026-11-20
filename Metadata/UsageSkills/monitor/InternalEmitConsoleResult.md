---
skill_format_version: "1.0.0"
name: "monitor.InternalEmitConsoleResult"
schema_name: "monitor"
object_name: "InternalEmitConsoleResult"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer bereits im Aufrufer materialisierten lokalen Temp-Tabelle."
source_path: "Code/01_Common/098_USP_InternalEmitConsoleResult.sql"
---

# monitor.InternalEmitConsoleResult

## Zweck und Einsatz

Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer bereits im Aufrufer materialisierten lokalen Temp-Tabelle.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalEmitConsoleResult]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SourceTable | sysname | ja | kein Default |
| @ResultLabel | nvarchar(200) | ja | kein Default |
| @EmptyMessage | nvarchar(200) | ja | kein Default |
| @StatusCode | varchar(40) | nein | NULL |
| @StatusMessage | nvarchar(2048) | nein | NULL |
| @Hilfe | bit | nein | 0 |

**@SourceTable:** @SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.

**@ResultLabel:** @ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].

**@EmptyMessage:** @EmptyMessage nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Keine Ergebnisse. Bei leerer Quelle erscheint der Wert als [Ergebnis].

**@StatusCode:** @StatusCode varchar(40). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Status] ausgegeben; NULL und Leerwerte bleiben erhalten. Der Helper führt keine eigene Prüfung einer Statuscode-Wertemenge durch.

**@StatusMessage:** @StatusMessage nvarchar(2048). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Hinweis] ausgegeben; NULL und Leerwerte bleiben erhalten. Die Procedure erzeugt keine Temp-Tabelle und hat keine OUTPUT-Parameter. Bei nichtleerer Quelle entsteht genau ein Resultset mit [Ergebnis] und src.*. Bei leerer Quelle entsteht genau eine Zeile mit [Ergebnis], [Status] und [Hinweis]. Es werden keine Sortierung oder Kappung hinzugefügt.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Genau ein CONSOLE-Resultset. Bei nichtleerer lokaler Quelle stehen `[Ergebnis] nvarchar(200)` und anschließend alle Spalten von `@SourceTable` in deren Quellschema; die Procedure fügt keine Sortierung und keine Zeilenkappung hinzu. Bei leerer Quelle entsteht genau eine Zeile mit `[Ergebnis] nvarchar(200)`, `[Status] varchar(40)` und `[Hinweis] nvarchar(2048)` aus den Argumenten. Es gibt keine OUTPUT-Parameter.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalEmitConsoleResult';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=NULL, @ResultLabel=NULL, @EmptyMessage=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

===============================================================================
Objekt       : monitor.InternalEmitConsoleResult
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer
               bereits im Aufrufer materialisierten lokalen Temp-Tabelle.
Vertrag      : Keine fachlichen Systemzugriffe. Nicht leere Quellen liefern
               eine beschriftete Fachansicht. Leere Quellen liefern genau eine
               verständliche Console-Zeile; RAW und TABLE verwenden den Helper
               nicht und erhalten deshalb keine künstlichen Datenzeilen.
Parameterverträge:
@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.
@ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].
@EmptyMessage nvar

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalEmitConsoleResult
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Rendert genau ein menschenlesbares CONSOLE-Resultset aus einer
               bereits im Aufrufer materialisierten lokalen Temp-Tabelle.
Vertrag      : Keine fachlichen Systemzugriffe. Nicht leere Quellen liefern
               eine beschriftete Fachansicht. Leere Quellen liefern genau eine
               verständliche Console-Zeile; RAW und TABLE verwenden den Helper
               nicht und erhalten deshalb keine künstlichen Datenzeilen.
Parameterverträge:
@SourceTable sysname. Default: keiner; Pflichtargument. Einzelner roher, unqualifizierter lokaler #Tabellenname; NULL, Name ohne #, ##Name oder LEN(Name)>116 lösen Guard-Fehler 51012 aus. Keine Liste oder SQL-Ausdruck. Es erfolgt kein Existenz- oder Schematest.
@ResultLabel nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Ergebnis. Bei nichtleerer Quelle erscheint der Wert als Spalte [Ergebnis].
@EmptyMessage nvarchar(200). Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM entfernt U+0020 am Anfang und Ende; NULL oder danach leer wird Keine Ergebnisse. Bei leerer Quelle erscheint der Wert als [Ergebnis].
@StatusCode varchar(40). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Status] ausgegeben; NULL und Leerwerte bleiben erhalten. Der Helper führt keine eigene Prüfung einer Statuscode-Wertemenge durch.
@StatusMessage nvarchar(2048). Default: NULL; INPUT-Argument. Im Leerfall unverändert als [Hinweis] ausgegeben; NULL und Leerwerte bleiben erhalten.
Die Procedure erzeugt keine Temp-Tabelle und hat keine OUTPUT-Parameter. Bei nichtleerer Quelle entsteht genau ein Resultset mit [Ergebnis] und src.*. Bei leerer Quelle entsteht genau eine Zeile mit [Ergebnis], [Status] und [Hinweis]. Es werden keine Sortierung oder Kappung hinzugefügt.
```

