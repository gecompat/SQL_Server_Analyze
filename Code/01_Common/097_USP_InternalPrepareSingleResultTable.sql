USE [DeineDatenbank];
GO

/*
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
@ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt den ursprünglichen @ResultName unter CS-Kollation, weshalb trotz AVAILABLE @TargetTable NULL bleiben kann.
@ResultName sysname, Default: kein Default (Pflichtparameter). Wird als @AllowedResultNames weitergereicht. NULL, leer oder nur leere Tokens ergibt keine zulässigen Namen. Der Wert wird als Pipe-Liste verarbeitet; | wird nicht escaped, nur U+0020 am Rand jedes Tokens wird entfernt. Der spätere Lookup vergleicht den ursprünglichen Wert unter CS-Kollation. Normalisierung oder Pipe-Aufteilung kann daher trotz AVAILABLE zu keinem Treffer und NULL in @TargetTable führen.
@TargetTable sysname, Default: kein Default, OUTPUT (Pflichtparameter). Argument muss angegeben werden; zum Empfang wird eine Aufrufervariable mit OUTPUT gebunden; Eingabewert wird ignoriert und beim Eintritt auf NULL gesetzt. Der sysname-Typ begrenzt die Länge bereits bei der Parameterbindung. Bei unterdrücktem Fehler oder fehlendem originalen CS-Lookup-Treffer bleibt der Wert NULL. Ein übergebener NULL-, Leertext- oder anderer Anfangswert wird nicht ausgewertet.
@ThrowOnError bit, Default: 1. Kann ausgelassen werden. 0 unterdrückt nur behandelte Fehler des weitergeleiteten Preflights; 1 lässt für solche Fehler 51011 auslösen. NULL wird als INVALID_PARAMETER behandelt, löst aber wegen NULL keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe.
Fehler- und Seiteneffektgrenzen: Eigene Mapping-Temp-DDL erfolgt vor dem Aufruf des Mehrfachbausteins und dessen Statusinitialisierung; Fehler werden erneut ausgelöst. Das Ziel wird durch den Mehrfachbaustein mit einer temporären Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen mit best-effort Bereinigung. Es erfolgt keine Erstellung oder dauerhafte Anpassung an Resultatspalten, keine atomare Rücknahmezusage. Eigene Mapping-DDL erhält 1000 ms; im CATCH wird der zuvor erfasste LOCK_TIMEOUT-Wert wieder gesetzt und der Fehler erneut ausgelöst. Nach Erfolg wird LOCK_TIMEOUT 0 gesetzt, Zielauflösung bleibt NOWAIT.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.InternalPrepareSingleResultTable 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalPrepareSingleResultTable"
-- schema_name: "monitor"
-- object_name: "InternalPrepareSingleResultTable"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter und gibt bei erfolgreicher Namensauflösung das lokale Ziel zurück."
-- source_path: "Code/01_Common/097_USP_InternalPrepareSingleResultTable.sql"
-- ---
-- 
-- # monitor.InternalPrepareSingleResultTable
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter und gibt bei erfolgreicher Namensauflösung das lokale Ziel zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare enthalten.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalPrepareSingleResultTable]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[monitor].[InternalPrepareResultTables]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @ResultTablesJson | nvarchar(max) | ja | kein Default |
-- | @ResultName | sysname | ja | kein Default |
-- | @TargetTable | sysname OUTPUT | ja | kein Default |
-- | @ThrowOnError | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt den ursprünglichen @ResultName unter CS-Kollation, weshalb trotz AVAILABLE @TargetTable NULL bleiben kann.
-- 
-- **@ResultName:** @ResultName sysname, Default: kein Default (Pflichtparameter). Wird als @AllowedResultNames weitergereicht. NULL, leer oder nur leere Tokens ergibt keine zulässigen Namen. Der Wert wird als Pipe-Liste verarbeitet; | wird nicht escaped, nur U+0020 am Rand jedes Tokens wird entfernt. Der spätere Lookup vergleicht den ursprünglichen Wert unter CS-Kollation. Normalisierung oder Pipe-Aufteilung kann daher trotz AVAILABLE zu keinem Treffer und NULL in @TargetTable führen.
-- 
-- **@TargetTable:** @TargetTable sysname, Default: kein Default, OUTPUT (Pflichtparameter). Argument muss angegeben werden; zum Empfang wird eine Aufrufervariable mit OUTPUT gebunden; Eingabewert wird ignoriert und beim Eintritt auf NULL gesetzt. Der sysname-Typ begrenzt die Länge bereits bei der Parameterbindung. Bei unterdrücktem Fehler oder fehlendem originalen CS-Lookup-Treffer bleibt der Wert NULL. Ein übergebener NULL-, Leertext- oder anderer Anfangswert wird nicht ausgewertet. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ThrowOnError:** @ThrowOnError bit, Default: 1. Kann ausgelassen werden. 0 unterdrückt nur behandelte Fehler des weitergeleiteten Preflights; 1 lässt für solche Fehler 51011 auslösen. NULL wird als INVALID_PARAMETER behandelt, löst aber wegen NULL keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe. Fehler- und Seiteneffektgrenzen: Eigene Mapping-Temp-DDL erfolgt vor dem Aufruf des Mehrfachbausteins und dessen Statusinitialisierung; Fehler werden erneut ausgelöst. Das Ziel wird durch den Mehrfachbaustein mit einer temporären Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen mit best-effort Bereinigung. Es erfolgt keine Erstellung oder dauerhafte Anpassung an Resultatspalten, keine atomare Rücknahmezusage. Eigene Mapping-DDL erhält 1000 ms; im CATCH wird der zuvor erfasste LOCK_TIMEOUT-Wert wieder gesetzt und der Fehler erneut ausgelöst. Nach Erfolg wird LOCK_TIMEOUT 0 gesetzt, Zielauflösung bleibt NOWAIT.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Kein Fach-Resultset. `@TargetTable sysname OUTPUT` wird beim Eintritt NULL und nach erfolgreicher JSON-Zuordnung auf genau das vom Aufrufer bereitgestellte lokale #Ziel gesetzt; ohne Treffer oder bei unterdrücktem Fehler bleibt es NULL. Die eigene Mapping-Temp-Tabelle ist nur ein interner Zwischenschritt. Mit `@ThrowOnError=1` entweicht ein Validierungs-/DDL-Fehler, mit 0 kann das Ziel NULL bleiben.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalPrepareSingleResultTable';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=NULL, @ResultName=NULL, @TargetTable=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- ===============================================================================
-- Objekt       : monitor.InternalPrepareSingleResultTable
-- Version      : 1.0.0
-- Stand        : 2026-07-20
-- Typ          : Interne Stored Procedure
-- Zweck        : Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter
--                und gibt bei erfolgreicher Namensauflösung das lokale Ziel
--                zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare
--                enthalten.
-- Parameter:
-- @ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalPrepareSingleResultTable
-- Version      : 1.0.0
-- Stand        : 2026-07-20
-- Typ          : Interne Stored Procedure
-- Zweck        : Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter
--                und gibt bei erfolgreicher Namensauflösung das lokale Ziel
--                zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare
--                enthalten.
-- Parameter:
-- @ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt den ursprünglichen @ResultName unter CS-Kollation, weshalb trotz AVAILABLE @TargetTable NULL bleiben kann.
-- @ResultName sysname, Default: kein Default (Pflichtparameter). Wird als @AllowedResultNames weitergereicht. NULL, leer oder nur leere Tokens ergibt keine zulässigen Namen. Der Wert wird als Pipe-Liste verarbeitet; | wird nicht escaped, nur U+0020 am Rand jedes Tokens wird entfernt. Der spätere Lookup vergleicht den ursprünglichen Wert unter CS-Kollation. Normalisierung oder Pipe-Aufteilung kann daher trotz AVAILABLE zu keinem Treffer und NULL in @TargetTable führen.
-- @TargetTable sysname, Default: kein Default, OUTPUT (Pflichtparameter). Argument muss angegeben werden; zum Empfang wird eine Aufrufervariable mit OUTPUT gebunden; Eingabewert wird ignoriert und beim Eintritt auf NULL gesetzt. Der sysname-Typ begrenzt die Länge bereits bei der Parameterbindung. Bei unterdrücktem Fehler oder fehlendem originalen CS-Lookup-Treffer bleibt der Wert NULL. Ein übergebener NULL-, Leertext- oder anderer Anfangswert wird nicht ausgewertet.
-- @ThrowOnError bit, Default: 1. Kann ausgelassen werden. 0 unterdrückt nur behandelte Fehler des weitergeleiteten Preflights; 1 lässt für solche Fehler 51011 auslösen. NULL wird als INVALID_PARAMETER behandelt, löst aber wegen NULL keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe.
-- Fehler- und Seiteneffektgrenzen: Eigene Mapping-Temp-DDL erfolgt vor dem Aufruf des Mehrfachbausteins und dessen Statusinitialisierung; Fehler werden erneut ausgelöst. Das Ziel wird durch den Mehrfachbaustein mit einer temporären Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen mit best-effort Bereinigung. Es erfolgt keine Erstellung oder dauerhafte Anpassung an Resultatspalten, keine atomare Rücknahmezusage. Eigene Mapping-DDL erhält 1000 ms; im CATCH wird der zuvor erfasste LOCK_TIMEOUT-Wert wieder gesetzt und der Fehler erneut ausgelöst. Nach Erfolg wird LOCK_TIMEOUT 0 gesetzt, Zielauflösung bleibt NOWAIT.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalPrepareSingleResultTable
CREATE OR ALTER PROCEDURE [monitor].[InternalPrepareSingleResultTable]
      @ResultTablesJson  nvarchar(max)
    , @ResultName        sysname
    , @TargetTable       sysname        OUTPUT
    , @ThrowOnError      bit            = 1
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalPrepareSingleResultTable
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalPrepareSingleResultTable') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalPrepareSingleResultTable"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalPrepareSingleResultTable"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter und gibt bei erfolgreicher Namensauflösung das lokale Ziel zurück."'
            + NCHAR(10)
            + N'source_path: "Code/01_Common/097_USP_InternalPrepareSingleResultTable.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalPrepareSingleResultTable'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter und gibt bei erfolgreicher Namensauflösung das lokale Ziel zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare enthalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalPrepareSingleResultTable]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[sys].[sp_executesql]`, `[monitor].[InternalPrepareResultTables]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | ja | kein Default |'
            + NCHAR(10)
            + N'| @ResultName | sysname | ja | kein Default |'
            + NCHAR(10)
            + N'| @TargetTable | sysname OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ThrowOnError | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt den ursprünglichen @ResultName unter CS-Kollation, weshalb trotz AVAILABLE @TargetTable NULL bleiben kann.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultName:** @ResultName sysname, Default: kein Default (Pflichtparameter). Wird als @AllowedResultNames weitergereicht. NULL, leer oder nur leere Tokens ergibt keine zulässigen Namen. Der Wert wird als Pipe-Liste verarbeitet; | wird nicht escaped, nur U+0020 am Rand jedes Tokens wird entfernt. Der spätere Lookup vergleicht den ursprünglichen Wert unter CS-Kollation. Normalisierung oder Pipe-Aufteilung kann daher trotz AVAILABLE zu keinem Treffer und NULL in @TargetTable führen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@TargetTable:** @TargetTable sysname, Default: kein Default, OUTPUT (Pflichtparameter). Argument muss angegeben werden; zum Empfang wird eine Aufrufervariable mit OUTPUT gebunden; Eingabewert wird ignoriert und beim Eintritt auf NULL gesetzt. Der sysname-Typ begrenzt die Länge bereits bei der Parameterbindung. Bei unterdrücktem Fehler oder fehlendem originalen CS-Lookup-Treffer bleibt der Wert NULL. Ein übergebener NULL-, Leertext- oder anderer Anfangswert wird nicht ausgewertet. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ThrowOnError:** @ThrowOnError bit, Default: 1. Kann ausgelassen werden. 0 unterdrückt nur behandelte Fehler des weitergeleiteten Preflights; 1 lässt für solche Fehler 51011 auslösen. NULL wird als INVALID_PARAMETER behandelt, löst aber wegen NULL keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe. Fehler- und Seiteneffektgrenzen: Eigene Mapping-Temp-DDL erfolgt vor dem Aufruf des Mehrfachbausteins und dessen Statusinitialisierung; Fehler werden erneut ausgelöst. Das Ziel wird durch den Mehrfachbaustein mit einer temporären Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen mit best-effort Bereinigung. Es erfolgt keine Erstellung oder dauerhafte Anpassung an Resultatspalten, keine atomare Rücknahmezusage. Eigene Mapping-DDL erhält 1000 ms; im CATCH wird der zuvor erfasste LOCK_TIMEOUT-Wert wieder gesetzt und der Fehler erneut ausgelöst. Nach Erfolg wird LOCK_TIMEOUT 0 gesetzt, Zielauflösung bleibt NOWAIT.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. `@TargetTable sysname OUTPUT` wird beim Eintritt NULL und nach erfolgreicher JSON-Zuordnung auf genau das vom Aufrufer bereitgestellte lokale #Ziel gesetzt; ohne Treffer oder bei unterdrücktem Fehler bleibt es NULL. Die eigene Mapping-Temp-Tabelle ist nur ein interner Zwischenschritt. Mit `@ThrowOnError=1` entweicht ein Validierungs-/DDL-Fehler, mit 0 kann das Ziel NULL bleiben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalPrepareSingleResultTable'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=NULL, @ResultName=NULL, @TargetTable=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + N'Objekt       : monitor.InternalPrepareSingleResultTable'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-20'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter'
            + NCHAR(10)
            + N'               und gibt bei erfolgreicher Namensauflösung das lokale Ziel'
            + NCHAR(10)
            + N'               zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare'
            + NCHAR(10)
            + N'               enthalten.'
            + NCHAR(10)
            + N'Parameter:'
            + NCHAR(10)
            + N'@ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt '
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : monitor.InternalPrepareSingleResultTable'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-20'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Die Procedure leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter'
            + NCHAR(10)
            + N'               und gibt bei erfolgreicher Namensauflösung das lokale Ziel'
            + NCHAR(10)
            + N'               zurück. Der JSON-Vertrag kann mehrere Schlüssel-Wert-Paare'
            + NCHAR(10)
            + N'               enthalten.'
            + NCHAR(10)
            + N'Parameter:'
            + NCHAR(10)
            + N'@ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). JSON-Objekt, keine Liste; NULL, leerer Text, {} oder kein Paar ist ungültig. Werte und Schlüssel müssen Zeichenketten sein. Der Mehrfachbaustein konvertiert Schlüssel und Ziel nach sysname vor seinen Guards. Zielwerte müssen rohe, unqualifizierte lokale #Temp-Namen ohne ## oder #Monitor-Präfix (CI) mit LEN höchstens 116 sein; sie werden nicht getrimmt. Doppelte konvertierte Schlüssel werden binär und doppelte Ziele unter Latin1_General_100_CI_AS erkannt. Ziele müssen existieren, leer sein und genau eine Seed-Spalte besitzen. Der Schlüssel wird gegen die normalisierte Whitelist geprüft; die spätere Einzelauflösung nutzt den ursprünglichen @ResultName unter CS-Kollation, weshalb trotz AVAILABLE @TargetTable NULL bleiben kann.'
            + NCHAR(10)
            + N'@ResultName sysname, Default: kein Default (Pflichtparameter). Wird als @AllowedResultNames weitergereicht. NULL, leer oder nur leere Tokens ergibt keine zulässigen Namen. Der Wert wird als Pipe-Liste verarbeitet; | wird nicht escaped, nur U+0020 am Rand jedes Tokens wird entfernt. Der spätere Lookup vergleicht den ursprünglichen Wert unter CS-Kollation. Normalisierung oder Pipe-Aufteilung kann daher trotz AVAILABLE zu keinem Treffer und NULL in @TargetTable führen.'
            + NCHAR(10)
            + N'@TargetTable sysname, Default: kein Default, OUTPUT (Pflichtparameter). Argument muss angegeben werden; zum Empfang wird eine Aufrufervariable mit OUTPUT gebunden; Eingabewert wird ignoriert und beim Eintritt auf NULL gesetzt. Der sysname-Typ begrenzt die Länge bereits bei der Parameterbindung. Bei unterdrücktem Fehler oder fehlendem originalen CS-Lookup-Treffer bleibt der Wert NULL. Ein übergebener NULL-, Leertext- oder anderer Anfangswert wird nicht ausgewertet.'
            + NCHAR(10)
            + N'@ThrowOnError bit, Default: 1. Kann ausgelassen werden. 0 unterdrückt nur behandelte Fehler des weitergeleiteten Preflights; 1 lässt für solche Fehler 51011 auslösen. NULL wird als INVALID_PARAMETER behandelt, löst aber wegen NULL keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe.'
            + NCHAR(10)
            + N'Fehler- und Seiteneffektgrenzen: Eigene Mapping-Temp-DDL erfolgt vor dem Aufruf des Mehrfachbausteins und dessen Statusinitialisierung; Fehler werden erneut ausgelöst. Das Ziel wird durch den Mehrfachbaustein mit einer temporären Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen mit best-effort Bereinigung. Es erfolgt keine Erstellung oder dauerhafte Anpassung an Resultatspalten, keine atomare Rücknahmezusage. Eigene Mapping-DDL erhält 1000 ms; im CATCH wird der zuvor erfasste LOCK_TIMEOUT-Wert wieder gesetzt und der Fehler erneut ausgelöst. Nach Erfolg wird LOCK_TIMEOUT 0 gesetzt, Zielauflösung bleibt NOWAIT.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalPrepareSingleResultTable
        RETURN;
    END;

    SET @TargetTable=NULL;

    -- Ein geerbter NOWAIT-Wert darf die eigene TempDB-Metadatenanlage
    -- nicht wegen einer kurzzeitigen Kollision abbrechen. Nur diese lokale
    -- Anlage erhält ein Zeitbudget von 1000 ms; die nachfolgende
    -- Auflösung fremder Tabellen bleibt bei LOCK_TIMEOUT 0.
    DECLARE @OwnDdlOriginalLockTimeout int=@@LOCK_TIMEOUT;
    BEGIN TRY
        SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#InternalPrepareSingleResultTable_Map]
        (
              [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY
            , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE
        );
    END TRY
    BEGIN CATCH
        DECLARE @OwnDdlRestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OwnDdlOriginalLockTimeout)+N';';
        EXEC [sys].[sp_executesql] @OwnDdlRestoreSql;
        THROW;
    END CATCH;

    SET LOCK_TIMEOUT 0;

    DECLARE @StatusCode varchar(40),@ErrorMessage nvarchar(2048);
    EXEC [monitor].[InternalPrepareResultTables]
          @ResultTablesJson=@ResultTablesJson
        , @AllowedResultNames=@ResultName
        , @MappingTable=N'#InternalPrepareSingleResultTable_Map'
        , @StatusCode=@StatusCode OUTPUT
        , @ErrorMessage=@ErrorMessage OUTPUT
        , @ThrowOnError=@ThrowOnError;

    IF @StatusCode='AVAILABLE'
        SELECT @TargetTable=[TargetTable]
        FROM [#InternalPrepareSingleResultTable_Map]
        WHERE [ResultName]=@ResultName COLLATE SQL_Latin1_General_CP1_CS_AS;
END;
GO
