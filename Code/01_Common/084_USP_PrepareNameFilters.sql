USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PrepareNameFilters
Version      : 1.0.0
Stand        : 2026-07-15
Typ          : Öffentlicher Vorbereitungshelfer
Zweck        : Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und
               vollständige Objektbezüge und befüllt die vom Aufrufer benannte
               Temp-Tabelle.
Voraussetzung: @FilterTable(FilterType, ItemOrdinal, NameValue, DatabaseName,
               SchemaName, ObjectName).
Hinweis      : Werte werden exakt case-sensitiv unter
               SQL_Latin1_General_CP1_CS_AS behandelt.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_PrepareNameFilters 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_PrepareNameFilters"
-- schema_name: "monitor"
-- object_name: "USP_PrepareNameFilters"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und vollständige Objektbezüge und befüllt die vom Aufrufer benannte Temp-Tabelle."
-- source_path: "Code/01_Common/084_USP_PrepareNameFilters.sql"
-- ---
-- 
-- # monitor.USP_PrepareNameFilters
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und vollständige Objektbezüge und befüllt die vom Aufrufer benannte Temp-Tabelle.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufruf braucht EXECUTE auf [monitor].[USP_PrepareNameFilters] im vorgesehenen Datenbankkontext. Der Helper liest nur die im Framework installierten Namensparser und schreibt in ein ausdrücklich bereitgestelltes lokales #Ziel; er liest keine Fachobjekte der gefilterten Datenbanken.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SchemaNames | nvarchar(max) | nein | NULL |
-- | @ObjectNames | nvarchar(max) | nein | NULL |
-- | @FullObjectNames | nvarchar(max) | nein | NULL |
-- | @IndexNames | nvarchar(max) | nein | NULL |
-- | @StatisticsNames | nvarchar(max) | nein | NULL |
-- | @ColumnNames | nvarchar(max) | nein | NULL |
-- | @StatusCode | varchar(40) | ja | kein Default; OUTPUT |
-- | @ErrorMessage | nvarchar(2048) | ja | kein Default; OUTPUT |
-- | @FilterTable | sysname | nein | N'#PrepareNameFilters_Result' |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@SchemaNames:** @SchemaNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType SCHEMA in NameValue abgelegt.
-- 
-- **@ObjectNames:** @ObjectNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType OBJECT in NameValue abgelegt.
-- 
-- **@FullObjectNames:** @FullObjectNames: nvarchar(max), Default NULL. TVF_ParseFullObjectNameList: | trennt außerhalb [...], ]] maskiert ] darin; äußere Elementleerzeichen entfernt; Rohsegmente max. 4000 UTF-16-Codeeinheiten. Formen Objekt, Schema.Objekt, Datenbank.Schema.Objekt; bei 3 Teilen Schema erforderlich, 4 Teile ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Überlange PARSENAME-Bestandteile können NULL ergeben, Fehlercode nicht zugesichert. Case-sensitive Duplikate FULL_OBJECT ungültig. Keine vollständige Syntax-/Existenz-/Rechteprüfung. Exklusiv mit angegebener Schema- oder Objektliste. Gültige Teile werden in DatabaseName/SchemaName/ObjectName gespeichert.
-- 
-- **@IndexNames:** @IndexNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType INDEX in NameValue abgelegt.
-- 
-- **@StatisticsNames:** @StatisticsNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType STATISTICS in NameValue abgelegt.
-- 
-- **@ColumnNames:** @ColumnNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType COLUMN in NameValue abgelegt.
-- 
-- **@StatusCode:** @StatusCode: Datentyp varchar(40); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ varchar(40) mit OUTPUT binden, zum Beispiel @StatusCode=@CallerStatusCode OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. AVAILABLE bedeutet, dass die Listenprüfung erfolgreich war und gültige Zeilen angehängt wurden; bei sechs nicht angegebenen Listen bedeutet es erfolgreich keine neuen Zeilen. INVALID_PARAMETER kennzeichnet ungültige Listenstruktur/-namen, Exklusivitätsverletzung, case-sensitive Duplikate oder ungültigen Temp-Tabellennamen. INTERNAL_ERROR kennzeichnet eine fehlende oder nicht passende Filter-Temp-Tabelle bei der Schema-Prüfung. TIMEOUT wird bei SQL-Fehler 1222 gesetzt. DENIED_PERMISSION wird bei den abgefangenen Berechtigungsfehlernummern 229, 262, 297, 300, 371 oder 916 gesetzt. ERROR_HANDLED kennzeichnet einen anderen im Listen-/Vorbereitungspfad abgefangenen SQL-Fehler; dessen SQL-Fehlertext wird in @ErrorMessage ausgegeben. Bei @Hilfe=1 bleibt die Aufrufervariable unverändert.
-- 
-- **@ErrorMessage:** @ErrorMessage: Datentyp nvarchar(2048); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ nvarchar(2048) mit OUTPUT binden, zum Beispiel @ErrorMessage=@CallerErrorMessage OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. Bei erfolgreicher Vorbereitung ist der Wert NULL; andernfalls empfängt er die Fehlerbeschreibung beziehungsweise im abgefangenen SQL-Fehlerpfad ERROR_MESSAGE(). Bei @Hilfe=1 bleibt er unverändert.
-- 
-- **@FilterTable:** @FilterTable: sysname, Default #PrepareNameFilters_Result. Vorhandene lokale # Tabelle derselben Session, kein ##, max. 116 Zeichen; NULL/falscher Präfix/Überlänge ungültig. Spalten FilterType varchar(20) NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname NULL, DatabaseName sysname NULL, SchemaName sysname NULL, ObjectName sysname NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. Wird nicht geleert; gültige Worktable-Zeilen angehängt. Fehler vor Insert lässt Altzeilen; abschließender Insertfehler nicht umfassend abgefangen.
-- 
-- **@Hilfe:** @Hilfe: bit, Default 0. 0 verarbeitet; 1 druckt Hilfe und kehrt vor OUTPUT-Initialisierung/Zieltabellenverarbeitung zurück; NULL normaler Pfad. Ausgelassen =0; numerisch ungleich 0 wird bit-konvertiert zu 1. Für beide OUTPUT-Parameter sind auch bei Hilfe Argumente anzugeben. Für den Empfang Variable mit OUTPUT binden; im Hilfepfad bleiben die übergebenen Eingangswerte unverändert.
-- 
-- ## Resultate und Ausgabe
-- 
-- Kein Fach-Resultset. Der Helper füllt ausschließlich die vom Aufrufer benannte Filter-Temp-Tabelle mit gültigen, case-sensitiv eindeutigen Namenseinträgen. `@StatusCode varchar(40)` und `@ErrorMessage nvarchar(2048)` sind OUTPUTs; syntaktische Fehler oder Duplikate ergeben `INVALID_PARAMETER`, abgefangene Quellfehler erhalten einen Fehlerstatus. Der Helper wählt keine Fachobjekte aus und belegt keine Existenz.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=N'[ExampleSchema]', @ObjectNames=N'[ExampleObject]', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @FilterTable=N'#PrepareNameFilters_HelpExample';
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_PrepareNameFilters validiert Namenslisten und ergänzt eine vorhandene lokale Filtertabelle. Sie liefert keine Analyse-Resultsets.
-- 
-- Einzelne Werte werden entquotet und case-sensitiv unter SQL_Latin1_General_CP1_CS_AS verglichen. Parser prüfen Struktur und PARSENAME-Ergebnisse; das ist keine vollständige SQL-Bezeichnergrammatik. Katalogexistenz und Berechtigungen werden nicht geprüft. Duplikate je Filtertyp sind ungültig.
-- 
-- Die Zieltabelle wird nicht vorab geleert. Gültige Zeilen werden angehängt. Ein Fehler vor dem abschließenden Insert lässt vorhandene Zeilen bestehen; der Insert ist nicht umfassend abgefangen. NULL in allen sechs Listen fügt keine Zeilen hinzu und setzt AVAILABLE.
-- 
-- Beispiel: ausführbarer Aufruf mit frischer, korrekt typisierter lokaler Tabelle und synthetischen Namen:
-- 
-- CREATE TABLE #PrepareNameFilters_HelpExample (FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_PrepareNameFilters
-- Version      : 1.0.0
-- Stand        : 2026-07-15
-- Typ          : Öffentlicher Vorbereitungshelfer
-- Zweck        : Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und
--                vollständige Objektbezüge und befüllt die vom Aufrufer benannte
--                Temp-Tabelle.
-- Voraussetzung: @FilterTable(FilterType, ItemOrdinal, NameValue, DatabaseName,
--                SchemaName, ObjectName).
-- Hinweis      : Werte werden exakt case-sensitiv unter
--                SQL_Latin1_General_CP1_CS_AS behandelt.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_PrepareNameFilters validiert Namenslisten und ergänzt eine vorhandene lokale Filtertabelle. Sie liefert keine Analyse-Resultsets.
-- Einzelne Werte werden entquotet und case-sensitiv unter SQL_Latin1_General_CP1_CS_AS verglichen. Parser prüfen Struktur und PARSENAME-Ergebnisse; das ist keine vollständige SQL-Bezeichnergrammatik. Katalogexistenz und Berechtigungen werden nicht geprüft. Duplikate je Filtertyp sind ungültig.
-- Die Zieltabelle wird nicht vorab geleert. Gültige Zeilen werden angehängt. Ein Fehler vor dem abschließenden Insert lässt vorhandene Zeilen bestehen; der Insert ist nicht umfassend abgefangen. NULL in allen sechs Listen fügt keine Zeilen hinzu und setzt AVAILABLE.
-- Beispiel: ausführbarer Aufruf mit frischer, korrekt typisierter lokaler Tabelle und synthetischen Namen:
-- CREATE TABLE #PrepareNameFilters_HelpExample (FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
-- DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048);
-- DROP TABLE #PrepareNameFilters_HelpExample;
-- Bei Fehlern vor dem Insert bleibt das Ziel unverändert; es wird nicht geleert. Eine leere Tabelle kann auch einen erfolgreichen Aufruf mit ausschließlich NULL-Listen bedeuten.
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_PrepareNameFilters
CREATE OR ALTER PROCEDURE [monitor].[USP_PrepareNameFilters]
      @SchemaNames       nvarchar(max)  = NULL
    , @ObjectNames       nvarchar(max)  = NULL
    , @FullObjectNames   nvarchar(max)  = NULL
    , @IndexNames        nvarchar(max)  = NULL
    , @StatisticsNames   nvarchar(max)  = NULL
    , @ColumnNames       nvarchar(max)  = NULL
    , @StatusCode        varchar(40)    OUTPUT
    , @ErrorMessage      nvarchar(2048) OUTPUT
    , @FilterTable       sysname        = N'#PrepareNameFilters_Result'
    , @Hilfe             bit            = 0
AS
BEGIN
    ;

    SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_PrepareNameFilters validiert Namenslisten und ergänzt eine vorhandene lokale Filtertabelle. Sie liefert keine Analyse-Resultsets.';
        PRINT N'@SchemaNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType SCHEMA in NameValue abgelegt.';
        PRINT N'@ObjectNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType OBJECT in NameValue abgelegt.';
        PRINT N'@FullObjectNames: nvarchar(max), Default NULL. TVF_ParseFullObjectNameList: | trennt außerhalb [...], ]] maskiert ] darin; äußere Elementleerzeichen entfernt; Rohsegmente max. 4000 UTF-16-Codeeinheiten. Formen Objekt, Schema.Objekt, Datenbank.Schema.Objekt; bei 3 Teilen Schema erforderlich, 4 Teile ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Überlange PARSENAME-Bestandteile können NULL ergeben, Fehlercode nicht zugesichert. Case-sensitive Duplikate FULL_OBJECT ungültig. Keine vollständige Syntax-/Existenz-/Rechteprüfung. Exklusiv mit angegebener Schema- oder Objektliste. Gültige Teile werden in DatabaseName/SchemaName/ObjectName gespeichert.';
        PRINT N'@IndexNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType INDEX in NameValue abgelegt.';
        PRINT N'@StatisticsNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType STATISTICS in NameValue abgelegt.';
        PRINT N'@ColumnNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType COLUMN in NameValue abgelegt.';
        PRINT N'Einzelne Werte werden entquotet und case-sensitiv unter SQL_Latin1_General_CP1_CS_AS verglichen. Parser prüfen Struktur und PARSENAME-Ergebnisse; das ist keine vollständige SQL-Bezeichnergrammatik. Katalogexistenz und Berechtigungen werden nicht geprüft. Duplikate je Filtertyp sind ungültig.';
        PRINT N'@StatusCode: Datentyp varchar(40); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ varchar(40) mit OUTPUT binden, zum Beispiel @StatusCode=@CallerStatusCode OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. AVAILABLE bedeutet, dass die Listenprüfung erfolgreich war und gültige Zeilen angehängt wurden; bei sechs nicht angegebenen Listen bedeutet es erfolgreich keine neuen Zeilen. INVALID_PARAMETER kennzeichnet ungültige Listenstruktur/-namen, Exklusivitätsverletzung, case-sensitive Duplikate oder ungültigen Temp-Tabellennamen. INTERNAL_ERROR kennzeichnet eine fehlende oder nicht passende Filter-Temp-Tabelle bei der Schema-Prüfung. TIMEOUT wird bei SQL-Fehler 1222 gesetzt. DENIED_PERMISSION wird bei den abgefangenen Berechtigungsfehlernummern 229, 262, 297, 300, 371 oder 916 gesetzt. ERROR_HANDLED kennzeichnet einen anderen im Listen-/Vorbereitungspfad abgefangenen SQL-Fehler; dessen SQL-Fehlertext wird in @ErrorMessage ausgegeben. Bei @Hilfe=1 bleibt die Aufrufervariable unverändert.';
        PRINT N'@ErrorMessage: Datentyp nvarchar(2048); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ nvarchar(2048) mit OUTPUT binden, zum Beispiel @ErrorMessage=@CallerErrorMessage OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. Bei erfolgreicher Vorbereitung ist der Wert NULL; andernfalls empfängt er die Fehlerbeschreibung beziehungsweise im abgefangenen SQL-Fehlerpfad ERROR_MESSAGE(). Bei @Hilfe=1 bleibt er unverändert.';
        PRINT N'@FilterTable: sysname, Default #PrepareNameFilters_Result. Vorhandene lokale # Tabelle derselben Session, kein ##, max. 116 Zeichen; NULL/falscher Präfix/Überlänge ungültig. Spalten FilterType varchar(20) NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname NULL, DatabaseName sysname NULL, SchemaName sysname NULL, ObjectName sysname NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. Wird nicht geleert; gültige Worktable-Zeilen angehängt. Fehler vor Insert lässt Altzeilen; abschließender Insertfehler nicht umfassend abgefangen.';
        PRINT N'Die Zieltabelle wird nicht vorab geleert. Gültige Zeilen werden angehängt. Ein Fehler vor dem abschließenden Insert lässt vorhandene Zeilen bestehen; der Insert ist nicht umfassend abgefangen. NULL in allen sechs Listen fügt keine Zeilen hinzu und setzt AVAILABLE.';
        PRINT N'@Hilfe: bit, Default 0. 0 verarbeitet; 1 druckt Hilfe und kehrt vor OUTPUT-Initialisierung/Zieltabellenverarbeitung zurück; NULL normaler Pfad. Ausgelassen =0; numerisch ungleich 0 wird bit-konvertiert zu 1. Für beide OUTPUT-Parameter sind auch bei Hilfe Argumente anzugeben. Für den Empfang Variable mit OUTPUT binden; im Hilfepfad bleiben die übergebenen Eingangswerte unverändert.';
        PRINT N'Beispiel: ausführbarer Aufruf mit frischer, korrekt typisierter lokaler Tabelle und synthetischen Namen:';
        PRINT N'CREATE TABLE #PrepareNameFilters_HelpExample (FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);';
        PRINT N'DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048);';
        PRINT N'EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=N''[ExampleSchema]'', @ObjectNames=N''[ExampleObject]'', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @FilterTable=N''#PrepareNameFilters_HelpExample'';';
        PRINT N'SELECT @StatusCode AS StatusCode, @ErrorMessage AS ErrorMessage;';
        PRINT N'SELECT * FROM #PrepareNameFilters_HelpExample ORDER BY FilterType, ItemOrdinal;';
        PRINT N'DROP TABLE #PrepareNameFilters_HelpExample;';
        PRINT N'Bei Fehlern vor dem Insert bleibt das Ziel unverändert; es wird nicht geleert. Eine leere Tabelle kann auch einen erfolgreichen Aufruf mit ausschließlich NULL-Listen bedeuten.';
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_PrepareNameFilters
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_PrepareNameFilters') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_PrepareNameFilters"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_PrepareNameFilters"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und vollständige Objektbezüge und befüllt die vom Aufrufer benannte Temp-Tabelle."'
            + NCHAR(10)
            + N'source_path: "Code/01_Common/084_USP_PrepareNameFilters.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_PrepareNameFilters'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und vollständige Objektbezüge und befüllt die vom Aufrufer benannte Temp-Tabelle.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Aufruf braucht EXECUTE auf [monitor].[USP_PrepareNameFilters] im vorgesehenen Datenbankkontext. Der Helper liest nur die im Framework installierten Namensparser und schreibt in ein ausdrücklich bereitgestelltes lokales #Ziel; er liest keine Fachobjekte der gefilterten Datenbanken.'
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
            + N'| @SchemaNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @ObjectNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @FullObjectNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @IndexNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @StatisticsNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @ColumnNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @StatusCode | varchar(40) | ja | kein Default; OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorMessage | nvarchar(2048) | ja | kein Default; OUTPUT |'
            + NCHAR(10)
            + N'| @FilterTable | sysname | nein | N''#PrepareNameFilters_Result'' |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SchemaNames:** @SchemaNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType SCHEMA in NameValue abgelegt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ObjectNames:** @ObjectNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType OBJECT in NameValue abgelegt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@FullObjectNames:** @FullObjectNames: nvarchar(max), Default NULL. TVF_ParseFullObjectNameList: | trennt außerhalb [...], ]] maskiert ] darin; äußere Elementleerzeichen entfernt; Rohsegmente max. 4000 UTF-16-Codeeinheiten. Formen Objekt, Schema.Objekt, Datenbank.Schema.Objekt; bei 3 Teilen Schema erforderlich, 4 Teile ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Überlange PARSENAME-Bestandteile können NULL ergeben, Fehlercode nicht zugesichert. Case-sensitive Duplikate FULL_OBJECT ungültig. Keine vollständige Syntax-/Existenz-/Rechteprüfung. Exklusiv mit angegebener Schema- oder Objektliste. Gültige Teile werden in DatabaseName/SchemaName/ObjectName gespeichert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IndexNames:** @IndexNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType INDEX in NameValue abgelegt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatisticsNames:** @StatisticsNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType STATISTICS in NameValue abgelegt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ColumnNames:** @ColumnNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL bedeutet nicht angegeben; leere oder nur aus Leerzeichen bestehende Werte sind ungültig. Ein ausgelassenes Argument verwendet den Default NULL. Gültige Elemente werden als FilterType COLUMN in NameValue abgelegt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCode:** @StatusCode: Datentyp varchar(40); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ varchar(40) mit OUTPUT binden, zum Beispiel @StatusCode=@CallerStatusCode OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. AVAILABLE bedeutet, dass die Listenprüfung erfolgreich war und gültige Zeilen angehängt wurden; bei sechs nicht angegebenen Listen bedeutet es erfolgreich keine neuen Zeilen. INVALID_PARAMETER kennzeichnet ungültige Listenstruktur/-namen, Exklusivitätsverletzung, case-sensitive Duplikate oder ungültigen Temp-Tabellennamen. INTERNAL_ERROR kennzeichnet eine fehlende oder nicht passende Filter-Temp-Tabelle bei der Schema-Prüfung. TIMEOUT wird bei SQL-Fehler 1222 gesetzt. DENIED_PERMISSION wird bei den abgefangenen Berechtigungsfehlernummern 229, 262, 297, 300, 371 oder 916 gesetzt. ERROR_HANDLED kennzeichnet einen anderen im Listen-/Vorbereitungspfad abgef'
            + N'angenen SQL-Fehler; dessen SQL-Fehlertext wird in @ErrorMessage ausgegeben. Bei @Hilfe=1 bleibt die Aufrufervariable unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessage:** @ErrorMessage: Datentyp nvarchar(2048); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ nvarchar(2048) mit OUTPUT binden, zum Beispiel @ErrorMessage=@CallerErrorMessage OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. Bei erfolgreicher Vorbereitung ist der Wert NULL; andernfalls empfängt er die Fehlerbeschreibung beziehungsweise im abgefangenen SQL-Fehlerpfad ERROR_MESSAGE(). Bei @Hilfe=1 bleibt er unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@FilterTable:** @FilterTable: sysname, Default #PrepareNameFilters_Result. Vorhandene lokale # Tabelle derselben Session, kein ##, max. 116 Zeichen; NULL/falscher Präfix/Überlänge ungültig. Spalten FilterType varchar(20) NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname NULL, DatabaseName sysname NULL, SchemaName sysname NULL, ObjectName sysname NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. Wird nicht geleert; gültige Worktable-Zeilen angehängt. Fehler vor Insert lässt Altzeilen; abschließender Insertfehler nicht umfassend abgefangen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe: bit, Default 0. 0 verarbeitet; 1 druckt Hilfe und kehrt vor OUTPUT-Initialisierung/Zieltabellenverarbeitung zurück; NULL normaler Pfad. Ausgelassen =0; numerisch ungleich 0 wird bit-konvertiert zu 1. Für beide OUTPUT-Parameter sind auch bei Hilfe Argumente anzugeben. Für den Empfang Variable mit OUTPUT binden; im Hilfepfad bleiben die übergebenen Eingangswerte unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. Der Helper füllt ausschließlich die vom Aufrufer benannte Filter-Temp-Tabelle mit gültigen, case-sensitiv eindeutigen Namenseinträgen. `@StatusCode varchar(40)` und `@ErrorMessage nvarchar(2048)` sind OUTPUTs; syntaktische Fehler oder Duplikate ergeben `INVALID_PARAMETER`, abgefangene Quellfehler erhalten einen Fehlerstatus. Der Helper wählt keine Fachobjekte aus und belegt keine Existenz.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_PrepareNameFilters] @SchemaNames=N''[ExampleSchema]'', @ObjectNames=N''[ExampleObject]'', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @FilterTable=N''#PrepareNameFilters_HelpExample'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_PrepareNameFilters validiert Namenslisten und ergänzt eine vorhandene lokale Filtertabelle. Sie liefert keine Analyse-Resultsets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Einzelne Werte werden entquotet und case-sensitiv unter SQL_Latin1_General_CP1_CS_AS verglichen. Parser prüfen Struktur und PARSENAME-Ergebnisse; das ist keine vollständige SQL-Bezeichnergrammatik. Katalogexistenz und Berechtigungen werden nicht geprüft. Duplikate je Filtertyp sind ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Zieltabelle wird nicht vorab geleert. Gültige Zeilen werden angehängt. Ein Fehler vor dem abschließenden Insert lässt vorhandene Zeilen bestehen; der Insert ist nicht umfassend abgefangen. NULL in allen sechs Listen fügt keine Zeilen hinzu und setzt AVAILABLE.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel: ausführbarer Aufruf mit frischer, korrekt typisierter lokaler Tabelle und synthetischen Namen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE #PrepareNameFilters_HelpExample (FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);'
            + NCHAR(10)
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
            + N'Objekt       : monitor.USP_PrepareNameFilters'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-15'
            + NCHAR(10)
            + N'Typ          : Öffentlicher Vorbereitungshelfer'
            + NCHAR(10)
            + N'Zweck        : Die Procedure validiert bracket-aware Pipe-Listen für einteilige SQL-Namen und'
            + NCHAR(10)
            + N'               vollständige Objektbezüge und befüllt die vom Aufrufer benannte'
            + NCHAR(10)
            + N'               Temp-Tabelle.'
            + NCHAR(10)
            + N'Voraussetzung: @FilterTable(FilterType, ItemOrdinal, NameValue, DatabaseName,'
            + NCHAR(10)
            + N'               SchemaName, ObjectName).'
            + NCHAR(10)
            + N'Hinweis      : Werte werden exakt case-sensitiv unter'
            + NCHAR(10)
            + N'               SQL_Latin1_General_CP1_CS_AS behandelt.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_PrepareNameFilters validiert Namenslisten und ergänzt eine vorhandene lokale Filtertabelle. Sie liefert keine Analyse-Resultsets.'
            + NCHAR(10)
            + N'Einzelne Werte werden entquotet und case-sensitiv unter SQL_Latin1_General_CP1_CS_AS verglichen. Parser prüfen Struktur und PARSENAME-Ergebnisse; das ist keine vollständige SQL-Bezeichnergrammatik. Katalogexistenz und Berechtigungen werden nicht geprüft. Duplikate je Filtertyp sind ungültig.'
            + NCHAR(10)
            + N'Die Zieltabelle wird nicht vorab geleert. Gültige Zeilen werden angehängt. Ein Fehler vor dem abschließenden Insert lässt vorhandene Zeilen bestehen; der Insert ist nicht umfassend abgefangen. NULL in allen sechs Listen fügt keine Zeilen hinzu und setzt AVAILABLE.'
            + NCHAR(10)
            + N'Beispiel: ausführbarer Aufruf mit frischer, korrekt typisierter lokaler Tabelle und synthetischen Namen:'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE #PrepareNameFilters_HelpExample (FilterType varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, ItemOrdinal int NOT NULL, NameValue sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, SchemaName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ObjectName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);'
            + NCHAR(10)
            + N'DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048);'
            + NCHAR(10)
            + N'DROP TABLE #PrepareNameFilters_HelpExample;'
            + NCHAR(10)
            + N'Bei Fehlern vor dem Insert bleibt das Ziel unverändert; es wird nicht geleert. Eine leere Tabelle kann auch einen erfolgreichen Aufruf mit ausschließlich NULL-Listen bedeuten.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_PrepareNameFilters
        RETURN;
    END

    SET LOCK_TIMEOUT 0;
    SET @StatusCode = 'AVAILABLE';
    SET @ErrorMessage = NULL;

    IF @FilterTable IS NULL
       OR LEFT(@FilterTable,1)<>N'#'
       OR LEFT(@FilterTable,2)=N'##'
       OR LEN(@FilterTable)>116
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@FilterTable muss einen gültigen lokalen #Temp-Tabellennamen enthalten.';
        RETURN;
    END;

    DECLARE @FilterTableQuoted nvarchar(258)=QUOTENAME(@FilterTable);
    DECLARE @Sql nvarchar(max);

    CREATE TABLE [#PrepareNameFilters_Work]
    (
          [FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ItemOrdinal] int NOT NULL
        , [NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsValid] bit NOT NULL
    );

    BEGIN TRY
        SET @Sql=N'DECLARE @ProbeType varchar(20),@ProbeOrdinal int,@ProbeName sysname,@ProbeDatabase sysname,@ProbeSchema sysname,@ProbeObject sysname;
SELECT TOP (0) @ProbeType=[FilterType],@ProbeOrdinal=[ItemOrdinal],@ProbeName=[NameValue],@ProbeDatabase=[DatabaseName],@ProbeSchema=[SchemaName],@ProbeObject=[ObjectName] FROM '+@FilterTableQuoted+N';';
        EXEC [sys].[sp_executesql] @Sql;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INTERNAL_ERROR';
        SET @ErrorMessage = N'Die über @FilterTable benannte Temp-Tabelle wurde nicht angelegt.';
        RETURN;
    END CATCH;

    IF @FullObjectNames IS NOT NULL
       AND (@SchemaNames IS NOT NULL OR @ObjectNames IS NOT NULL)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@FullObjectNames ist mit @SchemaNames und @ObjectNames gegenseitig exklusiv.';
        RETURN;
    END;

    BEGIN TRY
        INSERT [#PrepareNameFilters_Work]
        ([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName],[IsValid])
        SELECT 'SCHEMA',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@SchemaNames)
        UNION ALL
        SELECT 'OBJECT',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@ObjectNames)
        UNION ALL
        SELECT 'INDEX',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@IndexNames)
        UNION ALL
        SELECT 'STATISTICS',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@StatisticsNames)
        UNION ALL
        SELECT 'COLUMN',[ItemOrdinal],[NameValue],NULL,NULL,NULL,[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@ColumnNames);

        INSERT [#PrepareNameFilters_Work]
        ([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName],[IsValid])
        SELECT 'FULL_OBJECT',[ItemOrdinal],NULL,[DatabaseName],[SchemaName],[ObjectName],[IsValid]
        FROM [monitor].[TVF_ParseFullObjectNameList](@FullObjectNames);
    END TRY
    BEGIN CATCH
        SET @StatusCode = CASE WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                               WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                               ELSE 'ERROR_HANDLED' END;
        SET @ErrorMessage = ERROR_MESSAGE();
        RETURN;
    END CATCH;

    IF EXISTS(SELECT 1 FROM [#PrepareNameFilters_Work] WHERE [IsValid]=0)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens eine Namensliste ist syntaktisch ungültig.';
        RETURN;
    END;

    DECLARE @HasDuplicates bit=0;
    SELECT @HasDuplicates=CONVERT(bit,CASE WHEN EXISTS
    (
        SELECT 1 FROM [#PrepareNameFilters_Work] WHERE [IsValid]=1
        GROUP BY [FilterType],
                 [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [SchemaName] COLLATE SQL_Latin1_General_CP1_CS_AS,
                 [ObjectName] COLLATE SQL_Latin1_General_CP1_CS_AS
        HAVING COUNT(*) > 1
    ) THEN 1 ELSE 0 END);

    IF @HasDuplicates=1
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Eine Namensliste enthält case-sensitiv doppelte Werte.';
        RETURN;
    END;

    SET @Sql=N'INSERT '+@FilterTableQuoted+N'
([FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName])
SELECT [FilterType],[ItemOrdinal],[NameValue],[DatabaseName],[SchemaName],[ObjectName]
FROM [#PrepareNameFilters_Work]
WHERE [IsValid]=1;';
    EXEC [sys].[sp_executesql] @Sql;
END;
GO
