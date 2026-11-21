---
skill_format_version: "1.0.0"
name: "monitor.InternalPrepareSingleResultTable"
schema_name: "monitor"
object_name: "InternalPrepareSingleResultTable"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter und gibt bei erfolgreicher Namensauflösung das lokale Ziel zurück."
source_path: "Code/01_Common/097_USP_InternalPrepareSingleResultTable.sql"
---

# monitor.InternalPrepareSingleResultTable

## Zweck und Einsatz

Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter und gibt bei erfolgreicher Namensauflösung das lokale Ziel zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare enthalten.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalPrepareSingleResultTable]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[monitor].[InternalPrepareResultTables]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ResultTablesJson | nvarchar(max) | ja | kein Default |
| @ResultName | sysname | ja | kein Default |
| @TargetTable | sysname OUTPUT | ja | kein Default |
| @ThrowOnError | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@ResultTablesJson:** @ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt den ursprünglichen @ResultName unter CS-Kollation, weshalb trotz AVAILABLE @TargetTable NULL bleiben kann.

**@ResultName:** @ResultName sysname, Default: kein Default (Pflichtparameter). Wird als @AllowedResultNames weitergereicht. NULL, leer oder nur leere Tokens ergibt keine zulässigen Namen. Der Wert wird als Pipe-Liste verarbeitet; | wird nicht escaped, nur U+0020 am Rand jedes Tokens wird entfernt. Der spätere Lookup vergleicht den ursprünglichen Wert unter CS-Kollation. Normalisierung oder Pipe-Aufteilung kann daher trotz AVAILABLE zu keinem Treffer und NULL in @TargetTable führen.

**@TargetTable:** @TargetTable sysname, Default: kein Default, OUTPUT (Pflichtparameter). Argument muss angegeben werden; zum Empfang wird eine Aufrufervariable mit OUTPUT gebunden; Eingabewert wird ignoriert und beim Eintritt auf NULL gesetzt. Der sysname-Typ begrenzt die Länge bereits bei der Parameterbindung. Bei unterdrücktem Fehler oder fehlendem originalen CS-Lookup-Treffer bleibt der Wert NULL. Ein übergebener NULL-, Leertext- oder anderer Anfangswert wird nicht ausgewertet. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ThrowOnError:** @ThrowOnError bit, Default: 1. Kann ausgelassen werden. 0 unterdrückt nur behandelte Fehler des weitergeleiteten Preflights; 1 lässt für solche Fehler 51011 auslösen. NULL wird als INVALID_PARAMETER behandelt, löst aber wegen NULL keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe. Fehler- und Seiteneffektgrenzen: Eigene Mapping-Temp-DDL erfolgt vor dem Aufruf des Mehrfachbausteins und dessen Statusinitialisierung; Fehler werden erneut ausgelöst. Das Ziel wird durch den Mehrfachbaustein mit einer temporären Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen mit best-effort Bereinigung. Es erfolgt keine Erstellung oder dauerhafte Anpassung an Resultatspalten, keine atomare Rücknahmezusage. Eigene Mapping-DDL erhält 1000 ms; im CATCH wird der zuvor erfasste LOCK_TIMEOUT-Wert wieder gesetzt und der Fehler erneut ausgelöst. Nach Erfolg wird LOCK_TIMEOUT 0 gesetzt, Zielauflösung bleibt NOWAIT.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein Fach-Resultset. `@TargetTable sysname OUTPUT` wird beim Eintritt NULL und nach erfolgreicher JSON-Zuordnung auf genau das vom Aufrufer bereitgestellte lokale #Ziel gesetzt; ohne Treffer oder bei unterdrücktem Fehler bleibt es NULL. Die eigene Mapping-Temp-Tabelle ist nur ein interner Zwischenschritt. Mit `@ThrowOnError=1` entweicht ein Validierungs-/DDL-Fehler, mit 0 kann das Ziel NULL bleiben.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalPrepareSingleResultTable';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=NULL, @ResultName=NULL, @TargetTable=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

===============================================================================
Objekt       : monitor.InternalPrepareSingleResultTable
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter
               und gibt bei erfolgreicher Namensauflösung das lokale Ziel
               zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare
               enthalten.
Parameter:
@ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt 

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalPrepareSingleResultTable
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter
               und gibt bei erfolgreicher Namensauflösung das lokale Ziel
               zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare
               enthalten.
Parameter:
@ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt den ursprünglichen @ResultName unter CS-Kollation, weshalb trotz AVAILABLE @TargetTable NULL bleiben kann.
@ResultName sysname, Default: kein Default (Pflichtparameter). Wird als @AllowedResultNames weitergereicht. NULL, leer oder nur leere Tokens ergibt keine zulässigen Namen. Der Wert wird als Pipe-Liste verarbeitet; | wird nicht escaped, nur U+0020 am Rand jedes Tokens wird entfernt. Der spätere Lookup vergleicht den ursprünglichen Wert unter CS-Kollation. Normalisierung oder Pipe-Aufteilung kann daher trotz AVAILABLE zu keinem Treffer und NULL in @TargetTable führen.
@TargetTable sysname, Default: kein Default, OUTPUT (Pflichtparameter). Argument muss angegeben werden; zum Empfang wird eine Aufrufervariable mit OUTPUT gebunden; Eingabewert wird ignoriert und beim Eintritt auf NULL gesetzt. Der sysname-Typ begrenzt die Länge bereits bei der Parameterbindung. Bei unterdrücktem Fehler oder fehlendem originalen CS-Lookup-Treffer bleibt der Wert NULL. Ein übergebener NULL-, Leertext- oder anderer Anfangswert wird nicht ausgewertet.
@ThrowOnError bit, Default: 1. Kann ausgelassen werden. 0 unterdrückt nur behandelte Fehler des weitergeleiteten Preflights; 1 lässt für solche Fehler 51011 auslösen. NULL wird als INVALID_PARAMETER behandelt, löst aber wegen NULL keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe.
Fehler- und Seiteneffektgrenzen: Eigene Mapping-Temp-DDL erfolgt vor dem Aufruf des Mehrfachbausteins und dessen Statusinitialisierung; Fehler werden erneut ausgelöst. Das Ziel wird durch den Mehrfachbaustein mit einer temporären Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen mit best-effort Bereinigung. Es erfolgt keine Erstellung oder dauerhafte Anpassung an Resultatspalten, keine atomare Rücknahmezusage. Eigene Mapping-DDL erhält 1000 ms; im CATCH wird der zuvor erfasste LOCK_TIMEOUT-Wert wieder gesetzt und der Fehler erneut ausgelöst. Nach Erfolg wird LOCK_TIMEOUT 0 gesetzt, Zielauflösung bleibt NOWAIT.
```

