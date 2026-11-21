USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_LogShippingStatus
Version      : 1.0.1
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : msdb.dbo.log_shipping_primary_databases, log_shipping_monitor_primary, log_shipping_monitor_secondary, log_shipping_secondary_databases
Parameter    : @MaxZeilen, @ResultSetArt, @ResultTablesJson, @JsonErzeugen,
               @Json OUTPUT, @PrintMeldungen, @Hilfe
Resultsets   : RAW: Modulstatus, Primary und Secondary. CONSOLE/TABLE: Primary.
               NONE: keine Resultsets.
Berechtigung : Nur lesender Zugriff auf die genannten Systemobjekte. Das
               Framework vergibt keine Rechte und ändert keine Konfiguration.
Eigenlast    : Gering.
Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
Partial      : Fehlende erforderliche Tabellen ergeben UNAVAILABLE_FEATURE
               ohne Partialflag. Abgefangene Lesefehler ergeben ERROR_HANDLED
               mit IsPartial=1; andere Module bleiben ausführbar.
Änderungen   : 1.0.1 - Alertschwellen und History-Retention aus den
               Log-Shipping-Monitor-Tabellen gelesen.
               1.0.0 - Erstfassung Phase 6.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_LogShippingStatus 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_LogShippingStatus"
-- schema_name: "monitor"
-- object_name: "USP_LogShippingStatus"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken."
-- source_path: "Code/07_Infrastructure/060_USP_LogShippingStatus.sql"
-- ---
-- 
-- # monitor.USP_LogShippingStatus
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- SQL Server 2019 oder neuer.
-- 
-- msdb.dbo.log_shipping_primary_databases, log_shipping_monitor_primary, log_shipping_monitor_secondary, log_shipping_secondary_databases
-- 
-- Nur lesender Zugriff auf die genannten Systemobjekte. Das Framework vergibt keine Rechte und ändert keine Konfiguration.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @MaxZeilen | int | nein | 5000 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@MaxZeilen:** @MaxZeilen int=5000; Default: 5000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte setzen `INVALID_PARAMETER`; NULL oder 0 werden als unbegrenzte Obergrenze interpretiert. Ein positiver Wert wird getrennt als TOP-Grenze auf Primary- und Secondary-Resultat angewandt, nicht als gemeinsames Gesamtlimit; nach der jeweiligen Sortierung können später eingeordnete Konfigurationen fehlen. Die Eingabe begrenzt nur die ausgegebenen lokalen Konfigurations-/Monitorzeilen, nicht Backup- oder Jobhistory, da solche Quellen nicht abgefragt werden. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Nach Trim und Umwandlung in Großbuchstaben sind ausschließlich `CONSOLE`, `RAW`, `TABLE` und `NONE` gültig; NULL und andere Werte erzeugen `INVALID_PARAMETER`. CONSOLE liefert ausschließlich eine formatierte Primary-Ausgabe ohne zusätzliches Modulstatus- oder Secondary-Resultset; bei leerer Primary-Menge erscheint eine verständliche Hinweiszeile, RAW liefert technische Resultsets, TABLE schreibt das registrierte `primary`-Resultset, NONE unterdrückt Resultsets. CONSOLE und TABLE setzen den internen Resultsetpfad zunächst auf NONE und laufen danach über ihren Ausgabeadapter. Diese Auswahl steuert JSON nicht. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Bei `TABLE` ist ein nichtleeres JSON-Objekt erforderlich, in der Form {"primary":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel mit einem lokalen Zielnamen als JSON-Stringwert, keine weiteren Eigenschaften. Das Ziel muss leer sein und genau eine Seed-Spalte besitzen. Unbekannte oder doppelte Resultsetnamen, doppelte Ziele, globale/reservierte Ziele, ungültige Namen/Schemas oder fehlende Ziele lösen den TABLE-Preflightfehler 51011 aus. Der Preflight fügt dem Ziel vorübergehend eine Marker-Spalte hinzu und entfernt sie wieder. Außerhalb von TABLE sind NULL und Leer-/Whitespacewerte zulässig; ein nichtleeres Mapping löst 51011 aus. Die Zielnamen dürfen höchstens 116 Zeichen lang sein. Zielnamen-Duplikate werden ohne Beachtung der Groß-/Kleinschreibung geprüft; Resultset-Schlüssel müssen dagegen exakt einschließlich Groß-/Kleinschreibung stimmen. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 1 erzeugt JSON; 0 oder NULL lässt `@Json` nach der initialen Rücksetzung NULL. Das Root-Objekt enthält `meta` (u. a. resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage), `primary` und `secondary`. Die JSON-Ausgabe ist unabhängig von der Resultsetart. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT-Empfangsparameter für das erzeugte JSON. Zu Beginn wird er auf NULL gesetzt; nur bei `@JsonErzeugen = 1` weist die Procedure den JSON-Text zu. Die Struktur ist im Vertrag von `@JsonErzeugen` beschrieben. Bei HELP oder deaktivierter JSON-Erzeugung bleibt der Wert NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. 1 lässt bei einem behandelten Lesefehler eine Severity-10-Informationsmeldung mit `RAISERROR ... WITH NOWAIT` ausgeben; 0 unterdrückt diese Meldung. NULL wird durch `IF @PrintMeldungen = 1` nicht aktiviert. Der Schalter ändert weder Status noch Resultset-/JSON-Ausgabe. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- **@Hilfe:** @Hilfe bit=0; Default: 0. 1 gibt die Hilfe mit PRINT aus und kehrt vor Quellenverfügbarkeitsprüfung, Primary-/Secondary-Abfrage und Resultset-/JSON-Erzeugung zurück; 0 führt den normalen Ablauf aus. NULL aktiviert die Hilfe nicht. Die Prüfung von @ResultTablesJson sowie der TABLE-Zielpreflight liegen vor dem Hilfezweig. Ein ungültiges Mapping kann deshalb auch mit @Hilfe=1 Fehler 51011 auslösen; ein gültiges TABLE-Ziel wird bereits vor dem Hilferücksprung durch temporäres Hinzufügen und Entfernen einer Marker-Spalte geprüft. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.
-- 
-- ## Resultate und Ausgabe
-- 
-- RAW: Modulstatus, Primary und Secondary. CONSOLE/TABLE: Primary.
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | primary | 1 | 1 | [PrimaryServer] sysname,[PrimaryDatabase] sysname,[BackupDirectory] nvarchar(500),[BackupShare] nvarchar(500),[BackupRetentionPeriod] int,[BackupThreshold] int,[ThresholdAlertEnabled] bit,[LastBackupFile] nvarchar(500),[LastBackupDate] datetime,[BackupAgeMinutes] int,[LastBackupDateUtc] datetime,[HistoryRetentionPeriod] int |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_LogShippingStatus
-- 
-- Die Hilfe kehrt vor Verfügbarkeitsprüfung, Quellenabfrage und Ergebnisausgabe zurück. Die TABLE-Zielprüfung läuft davor, auch bei @Hilfe=1.
-- 
-- Der normale Pfad liest ausschließlich lokale Log-Shipping-Konfigurations- und Monitorzeilen aus msdb. Er fragt keine Jobhistory, Backuphistory, Remoteinstanz oder Logdatei ab und löst keine Backup-, Copy- oder Restoreaktion aus.
-- 
-- Primary- und Secondary-Zeilen werden getrennt begrenzt und ausgegeben. Die Ergebnisse sind ein nicht atomarer Snapshot lokaler Konfigurations-/Monitorwerte und belegen keine vollständige Datenbewegung.
-- 
-- Beispiel 1: EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_LogShippingStatus
-- Version      : 1.0.1
-- Stand        : 2026-07-14
-- Typ          : Stored Procedure
-- Zweck        : Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken.
-- SQL-Version  : SQL Server 2019 oder neuer.
-- Datenquellen : msdb.dbo.log_shipping_primary_databases, log_shipping_monitor_primary, log_shipping_monitor_secondary, log_shipping_secondary_databases
-- Parameter    : @MaxZeilen, @ResultSetArt, @ResultTablesJson, @JsonErzeugen,
--                @Json OUTPUT, @PrintMeldungen, @Hilfe
-- Resultsets   : RAW: Modulstatus, Primary und Secondary. CONSOLE/TABLE: Primary.
--                NONE: keine Resultsets.
-- Berechtigung : Nur lesender Zugriff auf die genannten Systemobjekte. Das
--                Framework vergibt keine Rechte und ändert keine Konfiguration.
-- Eigenlast    : Gering.
-- Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
-- Partial      : Fehlende erforderliche Tabellen ergeben UNAVAILABLE_FEATURE
--                ohne Partialflag. Abgefangene Lesefehler ergeben ERROR_HANDLED
--                mit IsPartial=1; andere Module bleiben ausführbar.
-- Änderungen   : 1.0.1 - Alertschwellen und History-Retention aus den
--                Log-Shipping-Monitor-Tabellen gelesen.
--                1.0.0 - Erstfassung Phase 6.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_LogShippingStatus
-- Die Hilfe kehrt vor Verfügbarkeitsprüfung, Quellenabfrage und Ergebnisausgabe zurück. Die TABLE-Zielprüfung läuft davor, auch bei @Hilfe=1.
-- Der normale Pfad liest ausschließlich lokale Log-Shipping-Konfigurations- und Monitorzeilen aus msdb. Er fragt keine Jobhistory, Backuphistory, Remoteinstanz oder Logdatei ab und löst keine Backup-, Copy- oder Restoreaktion aus.
-- Primary- und Secondary-Zeilen werden getrennt begrenzt und ausgegeben. Die Ergebnisse sind ein nicht atomarer Snapshot lokaler Konfigurations-/Monitorwerte und belegen keine vollständige Datenbewegung.
-- Beispiel 1: EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;
-- Beispiel 2: EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt='RAW';
-- Beispiel 3: DECLARE @LogShippingJson nvarchar(max); EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@LogShippingJson OUTPUT; SELECT @LogShippingJson AS [Json];
-- Beispiel 4: CREATE TABLE #LogShippingStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"primary":"#LogShippingStatus_HelpExample"}'; SELECT * FROM #LogShippingStatus_HelpExample; DROP TABLE #LogShippingStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #LogShippingStatus_HelpExample; THROW; END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_LogShippingStatus
CREATE OR ALTER PROCEDURE [monitor].[USP_LogShippingStatus]
 @MaxZeilen int=5000,@ResultSetArt varchar(16)='CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,@PrintMeldungen bit=1,@Hilfe bit=0
AS
BEGIN
 SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_LogShippingStatus';
        PRINT N'Die Hilfe kehrt vor Verfügbarkeitsprüfung, Quellenabfrage und Ergebnisausgabe zurück. Die TABLE-Zielprüfung läuft davor, auch bei @Hilfe=1.';
        PRINT N'Der normale Pfad liest ausschließlich lokale Log-Shipping-Konfigurations- und Monitorzeilen aus msdb. Er fragt keine Jobhistory, Backuphistory, Remoteinstanz oder Logdatei ab und löst keine Backup-, Copy- oder Restoreaktion aus.';
        PRINT N'Primary- und Secondary-Zeilen werden getrennt begrenzt und ausgegeben. Die Ergebnisse sind ein nicht atomarer Snapshot lokaler Konfigurations-/Monitorwerte und belegen keine vollständige Datenbewegung.';
        PRINT N'@MaxZeilen int=5000; Default: 5000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte setzen `INVALID_PARAMETER`; NULL oder 0 werden als unbegrenzte Obergrenze interpretiert. Ein positiver Wert wird getrennt als TOP-Grenze auf Primary- und Secondary-Resultat angewandt, nicht als gemeinsames Gesamtlimit; nach der jeweiligen Sortierung können später eingeordnete Konfigurationen fehlen. Die Eingabe begrenzt nur die ausgegebenen lokalen Konfigurations-/Monitorzeilen, nicht Backup- oder Jobhistory, da solche Quellen nicht abgefragt werden. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Nach Trim und Umwandlung in Großbuchstaben sind ausschließlich `CONSOLE`, `RAW`, `TABLE` und `NONE` gültig; NULL und andere Werte erzeugen `INVALID_PARAMETER`. CONSOLE liefert ausschließlich eine formatierte Primary-Ausgabe ohne zusätzliches Modulstatus- oder Secondary-Resultset; bei leerer Primary-Menge erscheint eine verständliche Hinweiszeile, RAW liefert technische Resultsets, TABLE schreibt das registrierte `primary`-Resultset, NONE unterdrückt Resultsets. CONSOLE und TABLE setzen den internen Resultsetpfad zunächst auf NONE und laufen danach über ihren Ausgabeadapter. Diese Auswahl steuert JSON nicht. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. Bei `TABLE` ist ein nichtleeres JSON-Objekt erforderlich, in der Form {"primary":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel mit einem lokalen Zielnamen als JSON-Stringwert, keine weiteren Eigenschaften. Das Ziel muss leer sein und genau eine Seed-Spalte besitzen. Unbekannte oder doppelte Resultsetnamen, doppelte Ziele, globale/reservierte Ziele, ungültige Namen/Schemas oder fehlende Ziele lösen den TABLE-Preflightfehler 51011 aus. Der Preflight fügt dem Ziel vorübergehend eine Marker-Spalte hinzu und entfernt sie wieder. Außerhalb von TABLE sind NULL und Leer-/Whitespacewerte zulässig; ein nichtleeres Mapping löst 51011 aus. Die Zielnamen dürfen höchstens 116 Zeichen lang sein. Zielnamen-Duplikate werden ohne Beachtung der Groß-/Kleinschreibung geprüft; Resultset-Schlüssel müssen dagegen exakt einschließlich Groß-/Kleinschreibung stimmen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. 1 erzeugt JSON; 0 oder NULL lässt `@Json` nach der initialen Rücksetzung NULL. Das Root-Objekt enthält `meta` (u. a. resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage), `primary` und `secondary`. Die JSON-Ausgabe ist unabhängig von der Resultsetart. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT-Empfangsparameter für das erzeugte JSON. Zu Beginn wird er auf NULL gesetzt; nur bei `@JsonErzeugen = 1` weist die Procedure den JSON-Text zu. Die Struktur ist im Vertrag von `@JsonErzeugen` beschrieben. Bei HELP oder deaktivierter JSON-Erzeugung bleibt der Wert NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. 1 lässt bei einem behandelten Lesefehler eine Severity-10-Informationsmeldung mit `RAISERROR ... WITH NOWAIT` ausgeben; 0 unterdrückt diese Meldung. NULL wird durch `IF @PrintMeldungen = 1` nicht aktiviert. Der Schalter ändert weder Status noch Resultset-/JSON-Ausgabe. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. 1 gibt die Hilfe mit PRINT aus und kehrt vor Quellenverfügbarkeitsprüfung, Primary-/Secondary-Abfrage und Resultset-/JSON-Erzeugung zurück; 0 führt den normalen Ablauf aus. NULL aktiviert die Hilfe nicht. Die Prüfung von @ResultTablesJson sowie der TABLE-Zielpreflight liegen vor dem Hilfezweig. Ein ungültiges Mapping kann deshalb auch mit @Hilfe=1 Fehler 51011 auslösen; ein gültiges TABLE-Ziel wird bereits vor dem Hilferücksprung durch temporäres Hinzufügen und Entfernen einer Marker-Spalte geprüft. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3: DECLARE @LogShippingJson nvarchar(max); EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@LogShippingJson OUTPUT; SELECT @LogShippingJson AS [Json];';
        PRINT N'Beispiel 4: CREATE TABLE #LogShippingStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"primary":"#LogShippingStatus_HelpExample"}''; SELECT * FROM #LogShippingStatus_HelpExample; DROP TABLE #LogShippingStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #LogShippingStatus_HelpExample; THROW; END CATCH;';
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_LogShippingStatus
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_LogShippingStatus') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_LogShippingStatus"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_LogShippingStatus"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken."'
            + NCHAR(10)
            + N'source_path: "Code/07_Infrastructure/060_USP_LogShippingStatus.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_LogShippingStatus'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'msdb.dbo.log_shipping_primary_databases, log_shipping_monitor_primary, log_shipping_monitor_secondary, log_shipping_secondary_databases'
            + NCHAR(10)
            + NCHAR(10)
            + N'Nur lesender Zugriff auf die genannten Systemobjekte. Das Framework vergibt keine Rechte und ändert keine Konfiguration.'
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
            + N'| @MaxZeilen | int | nein | 5000 |'
            + NCHAR(10)
            + N'| @ResultSetArt | varchar(16) | nein | ''CONSOLE'' |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JsonErzeugen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Json | nvarchar(max) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @PrintMeldungen | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int=5000; Default: 5000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte setzen `INVALID_PARAMETER`; NULL oder 0 werden als unbegrenzte Obergrenze interpretiert. Ein positiver Wert wird getrennt als TOP-Grenze auf Primary- und Secondary-Resultat angewandt, nicht als gemeinsames Gesamtlimit; nach der jeweiligen Sortierung können später eingeordnete Konfigurationen fehlen. Die Eingabe begrenzt nur die ausgegebenen lokalen Konfigurations-/Monitorzeilen, nicht Backup- oder Jobhistory, da solche Quellen nicht abgefragt werden. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Nach Trim und Umwandlung in Großbuchstaben sind ausschließlich `CONSOLE`, `RAW`, `TABLE` und `NONE` gültig; NULL und andere Werte erzeugen `INVALID_PARAMETER`. CONSOLE liefert ausschließlich eine formatierte Primary-Ausgabe ohne zusätzliches Modulstatus- oder Secondary-Resultset; bei leerer Primary-Menge erscheint eine verständliche Hinweiszeile, RAW liefert technische Resultsets, TABLE schreibt das registrierte `primary`-Resultset, NONE unterdrückt Resultsets. CONSOLE und TABLE setzen den internen Resultsetpfad zunächst auf NONE und laufen danach über ihren Ausgabeadapter. Diese Auswahl steuert JSON nicht. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Bei `TABLE` ist ein nichtleeres JSON-Objekt erforderlich, in der Form {"primary":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel mit einem lokalen Zielnamen als JSON-Stringwert, keine weiteren Eigenschaften. Das Ziel muss leer sein und genau eine Seed-Spalte besitzen. Unbekannte oder doppelte Resultsetnamen, doppelte Ziele, globale/reservierte Ziele, ungültige Namen/Schemas oder fehlende Ziele lösen den TABLE-Preflightfehler 51011 aus. Der Preflight fügt dem Ziel vorübergehend eine Marker-Spalte hinzu und entfernt sie wieder. Außerhalb von TABLE sind NULL und Leer-/Whitespacewerte zulässig; ein nichtleeres Mapping löst 51011 aus. Die Zielnamen dürfen höchstens 116 Zeichen lang sein. Zielnamen-Duplikate werden ohne Beachtung der Groß-/Kleinschreibung geprüft; Resultset-Schlüssel müssen dagegen exakt einschließlich Groß-/Kleinschreibung stimmen. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 1 erzeugt JSON; 0 oder NULL lässt `@Json` nach der initialen Rücksetzung NULL. Das Root-Objekt enthält `meta` (u. a. resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, errorNumber und errorMessage), `primary` und `secondary`. Die JSON-Ausgabe ist unabhängig von der Resultsetart. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT-Empfangsparameter für das erzeugte JSON. Zu Beginn wird er auf NULL gesetzt; nur bei `@JsonErzeugen = 1` weist die Procedure den JSON-Text zu. Die Struktur ist im Vertrag von `@JsonErzeugen` beschrieben. Bei HELP oder deaktivierter JSON-Erzeugung bleibt der Wert NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. 1 lässt bei einem behandelten Lesefehler eine Severity-10-Informationsmeldung mit `RAISERROR ... WITH NOWAIT` ausgeben; 0 unterdrückt diese Meldung. NULL wird durch `IF @PrintMeldungen = 1` nicht aktiviert. Der Schalter ändert weder Status noch Resultset-/JSON-Ausgabe. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit=0; Default: 0. 1 gibt die Hilfe mit PRINT aus und kehrt vor Quellenverfügbarkeitsprüfung, Primary-/Secondary-Abfrage und Resultset-/JSON-Erzeugung zurück; 0 führt den normalen Ablauf aus. NULL aktiviert die Hilfe nicht. Die Prüfung von @ResultTablesJson sowie der TABLE-Zielpreflight liegen vor dem Hilfezweig. Ein ungültiges Mapping kann deshalb auch mit @Hilfe=1 Fehler 51011 auslösen; ein gültiges TABLE-Ziel wird bereits vor dem Hilferücksprung durch temporäres Hinzufügen und Entfernen einer Marker-Spalte geprüft. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'RAW: Modulstatus, Primary und Secondary. CONSOLE/TABLE: Primary.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| primary | 1 | 1 | [PrimaryServer] sysname,[PrimaryDatabase] sysname,[BackupDirectory] nvarchar(500),[BackupShare] nvarchar(500),[BackupRetentionPeriod] int,[BackupThreshold] int,[ThresholdAlertEnabled] bit,[LastBackupFile] nvarchar(500),[LastBackupDate] datetime,[BackupAgeMinutes] int,[LastBackupDateUtc] datetime,[HistoryRetentionPeriod] int |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_LogShippingStatus'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Hilfe kehrt vor Verfügbarkeitsprüfung, Quellenabfrage und Ergebnisausgabe zurück. Die TABLE-Zielprüfung läuft davor, auch bei @Hilfe=1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der normale Pfad liest ausschließlich lokale Log-Shipping-Konfigurations- und Monitorzeilen aus msdb. Er fragt keine Jobhistory, Backuphistory, Remoteinstanz oder Logdatei ab und löst keine Backup-, Copy- oder Restoreaktion aus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Primary- und Secondary-Zeilen werden getrennt begrenzt und ausgegeben. Die Ergebnisse sind ein nicht atomarer Snapshot lokaler Konfigurations-/Monitorwerte und belegen keine vollständige Datenbewegung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Beispiel 1: EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;'
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
            + N'Objekt       : monitor.USP_LogShippingStatus'
            + NCHAR(10)
            + N'Version      : 1.0.1'
            + NCHAR(10)
            + N'Stand        : 2026-07-14'
            + NCHAR(10)
            + N'Typ          : Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Die Procedure liest vorhandene Log-Shipping-Konfiguration und Monitorzustände für Primary- und Secondary-Datenbanken.'
            + NCHAR(10)
            + N'SQL-Version  : SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + N'Datenquellen : msdb.dbo.log_shipping_primary_databases, log_shipping_monitor_primary, log_shipping_monitor_secondary, log_shipping_secondary_databases'
            + NCHAR(10)
            + N'Parameter    : @MaxZeilen, @ResultSetArt, @ResultTablesJson, @JsonErzeugen,'
            + NCHAR(10)
            + N'               @Json OUTPUT, @PrintMeldungen, @Hilfe'
            + NCHAR(10)
            + N'Resultsets   : RAW: Modulstatus, Primary und Secondary. CONSOLE/TABLE: Primary.'
            + NCHAR(10)
            + N'               NONE: keine Resultsets.'
            + NCHAR(10)
            + N'Berechtigung : Nur lesender Zugriff auf die genannten Systemobjekte. Das'
            + NCHAR(10)
            + N'               Framework vergibt keine Rechte und ändert keine Konfiguration.'
            + NCHAR(10)
            + N'Eigenlast    : Gering.'
            + NCHAR(10)
            + N'Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.'
            + NCHAR(10)
            + N'Partial      : Fehlende erforderliche Tabellen ergeben UNAVAILABLE_FEATURE'
            + NCHAR(10)
            + N'               ohne Partialflag. Abgefangene Lesefehler ergeben ERROR_HANDLED'
            + NCHAR(10)
            + N'               mit IsPartial=1; andere Module bleiben ausführbar.'
            + NCHAR(10)
            + N'Änderungen   : 1.0.1 - Alertschwellen und History-Retention aus den'
            + NCHAR(10)
            + N'               Log-Shipping-Monitor-Tabellen gelesen.'
            + NCHAR(10)
            + N'               1.0.0 - Erstfassung Phase 6.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_LogShippingStatus'
            + NCHAR(10)
            + N'Die Hilfe kehrt vor Verfügbarkeitsprüfung, Quellenabfrage und Ergebnisausgabe zurück. Die TABLE-Zielprüfung läuft davor, auch bei @Hilfe=1.'
            + NCHAR(10)
            + N'Der normale Pfad liest ausschließlich lokale Log-Shipping-Konfigurations- und Monitorzeilen aus msdb. Er fragt keine Jobhistory, Backuphistory, Remoteinstanz oder Logdatei ab und löst keine Backup-, Copy- oder Restoreaktion aus.'
            + NCHAR(10)
            + N'Primary- und Secondary-Zeilen werden getrennt begrenzt und ausgegeben. Die Ergebnisse sind ein nicht atomarer Snapshot lokaler Konfigurations-/Monitorwerte und belegen keine vollständige Datenbewegung.'
            + NCHAR(10)
            + N'Beispiel 1: EXEC [monitor].[USP_LogShippingStatus] @Hilfe=1;'
            + NCHAR(10)
            + N'Beispiel 2: EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'Beispiel 3: DECLARE @LogShippingJson nvarchar(max); EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@LogShippingJson OUTPUT; SELECT @LogShippingJson AS [Json];'
            + NCHAR(10)
            + N'Beispiel 4: CREATE TABLE #LogShippingStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_LogShippingStatus] @MaxZeilen=100, @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"primary":"#LogShippingStatus_HelpExample"}''; SELECT * FROM #LogShippingStatus_HelpExample; DROP TABLE #LogShippingStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #LogShippingStatus_HelpExample; THROW; END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_LogShippingStatus
        RETURN;
    END

 SET @Json=NULL;
 DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'primary',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    ;
 DECLARE @CollectionTimeUtc datetime2(3)=SYSUTCDATETIME(),@StatusCode varchar(40)='AVAILABLE',@IsPartial bit=0,@ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL;
 IF @MaxZeilen<0 SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@MaxZeilen darf nicht negativ sein; NULL/0 bedeutet unbegrenzt.';
 CREATE TABLE [#LogShippingStatus_P]([PrimaryServer] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[PrimaryDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[BackupDirectory] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS,[BackupShare] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS,[BackupRetentionPeriod] int,[BackupThreshold] int,[ThresholdAlertEnabled] bit,[LastBackupFile] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS,[LastBackupDate] datetime,[BackupAgeMinutes] int,[LastBackupDateUtc] datetime,[HistoryRetentionPeriod] int);
 CREATE TABLE [#LogShippingStatus_S]([SecondaryServer] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[SecondaryDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[PrimaryServer] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[PrimaryDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[RestoreDelay] int,[RestoreThreshold] int,[ThresholdAlertEnabled] bit,[LastCopiedFile] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS,[LastCopiedDate] datetime,[CopyAgeMinutes] int,[LastRestoredFile] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS,[LastRestoredDate] datetime,[RestoreAgeMinutes] int,[LastRestoredLatency] int,[RestoreMode] int,[DisconnectUsers] bit);
 IF @ResultSetArtNormalisiert NOT IN ('RAW','CONSOLE','NONE') SELECT @StatusCode='INVALID_PARAMETER',@IsPartial=1,@ErrorMessage=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
 SET LOCK_TIMEOUT 0;
 IF @StatusCode='AVAILABLE'
 BEGIN
  BEGIN TRY
  IF (SELECT COUNT(*)
      FROM [msdb].[sys].[tables] AS [t] WITH (NOLOCK)
      JOIN [msdb].[sys].[schemas] AS [s] WITH (NOLOCK)
        ON [s].[schema_id]=[t].[schema_id]
      WHERE [s].[name]=N'dbo'
        AND [t].[name] IN
            (N'log_shipping_primary_databases',N'log_shipping_monitor_primary',N'log_shipping_secondary_databases',N'log_shipping_monitor_secondary'))<>4
  BEGIN
   SET @StatusCode='UNAVAILABLE_FEATURE';
   SET @ErrorMessage=N'Erforderliche Log-Shipping-Konfigurations- oder Monitor-Tabellen sind nicht vorhanden.';
  END
  ELSE BEGIN
   INSERT [#LogShippingStatus_P]
   (
       [PrimaryServer], [PrimaryDatabase], [BackupDirectory], [BackupShare],
       [BackupRetentionPeriod], [BackupThreshold], [ThresholdAlertEnabled],
       [LastBackupFile], [LastBackupDate], [BackupAgeMinutes],
       [LastBackupDateUtc], [HistoryRetentionPeriod]
   )
   SELECT TOP (@EffectiveMaxZeilen)
       [mp].[primary_server], [p].[primary_database], [p].[backup_directory],
       [p].[backup_share], [p].[backup_retention_period], [mp].[backup_threshold],
       [mp].[threshold_alert_enabled], [mp].[last_backup_file],
       [mp].[last_backup_date], DATEDIFF(MINUTE, [mp].[last_backup_date], GETDATE()),
       [mp].[last_backup_date_utc], [mp].[history_retention_period]
   FROM [msdb].[dbo].[log_shipping_primary_databases] AS [p] WITH (NOLOCK)
   LEFT JOIN [msdb].[dbo].[log_shipping_monitor_primary] AS [mp] WITH (NOLOCK)
     ON [mp].[primary_id] = [p].[primary_id]
   ORDER BY [p].[primary_database];

   INSERT [#LogShippingStatus_S]
   (
       [SecondaryServer], [SecondaryDatabase], [PrimaryServer], [PrimaryDatabase],
       [RestoreDelay], [RestoreThreshold], [ThresholdAlertEnabled],
       [LastCopiedFile], [LastCopiedDate], [CopyAgeMinutes],
       [LastRestoredFile], [LastRestoredDate], [RestoreAgeMinutes],
       [LastRestoredLatency], [RestoreMode], [DisconnectUsers]
   )
   SELECT TOP (@EffectiveMaxZeilen)
       [ms].[secondary_server], [s].[secondary_database], [ms].[primary_server],
       [ms].[primary_database], [s].[restore_delay], [ms].[restore_threshold],
       [ms].[threshold_alert_enabled], [ms].[last_copied_file],
       [ms].[last_copied_date], DATEDIFF(MINUTE, [ms].[last_copied_date], GETDATE()),
       [ms].[last_restored_file], [ms].[last_restored_date],
       DATEDIFF(MINUTE, [ms].[last_restored_date], GETDATE()),
       [ms].[last_restored_latency], [s].[restore_mode], [s].[disconnect_users]
   FROM [msdb].[dbo].[log_shipping_secondary_databases] AS [s] WITH (NOLOCK)
   LEFT JOIN [msdb].[dbo].[log_shipping_monitor_secondary] AS [ms] WITH (NOLOCK)
     ON [ms].[secondary_id] = [s].[secondary_id]
   ORDER BY [s].[secondary_database];
  END
  END TRY BEGIN CATCH SELECT @StatusCode='ERROR_HANDLED',@IsPartial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(); IF @PrintMeldungen=1 RAISERROR(N'Log Shipping konnte nicht vollständig gelesen werden: %s',10,1,@ErrorMessage) WITH NOWAIT; END CATCH;
 END;

 IF @ResultSetArtNormalisiert<>'NONE'
 BEGIN
  SELECT @CollectionTimeUtc AS [CollectionTimeUtc],CAST(N'monitor.USP_LogShippingStatus' AS nvarchar(256)) AS [ModuleName],@StatusCode AS [StatusCode],@IsPartial AS [IsPartial],@ErrorNumber AS [ErrorNumber],@ErrorMessage AS [ErrorMessage];
  IF @ResultSetArtNormalisiert='RAW'
  BEGIN SELECT * FROM [#LogShippingStatus_P] ORDER BY [PrimaryDatabase];SELECT * FROM [#LogShippingStatus_S] ORDER BY [SecondaryDatabase];END
  ELSE
  BEGIN
   SELECT N'Log-Shipping Primary' AS [Ergebnis],[x].*,CASE WHEN [BackupAgeMinutes] IS NULL THEN N'kein Zeitpunkt' ELSE CONCAT([BackupAgeMinutes],N' min') END AS [Backup-Alter] FROM [#LogShippingStatus_P] AS [x] ORDER BY [PrimaryDatabase];
   SELECT N'Log-Shipping Secondary' AS [Ergebnis],[x].*,CASE WHEN [RestoreAgeMinutes] IS NULL THEN N'kein Zeitpunkt' ELSE CONCAT([RestoreAgeMinutes],N' min') END AS [Restore-Alter] FROM [#LogShippingStatus_S] AS [x] ORDER BY [SecondaryDatabase];
  END
 END;
 IF @JsonErzeugen=1
 BEGIN
  DECLARE @MetaJson nvarchar(max)=(SELECT N'LogShippingStatus' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
  DECLARE @PrimaryJson nvarchar(max)=(SELECT * FROM [#LogShippingStatus_P] ORDER BY [PrimaryDatabase] FOR JSON PATH,INCLUDE_NULL_VALUES);
  DECLARE @SecondaryJson nvarchar(max)=(SELECT * FROM [#LogShippingStatus_S] ORDER BY [SecondaryDatabase] FOR JSON PATH,INCLUDE_NULL_VALUES);
  SET @Json=CONCAT(N'{"meta":',COALESCE(@MetaJson,N'{}'),N',"primary":',COALESCE(@PrimaryJson,N'[]'),N',"secondary":',COALESCE(@SecondaryJson,N'[]'),N'}');
 END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#LogShippingStatus_P'
            , @ResultLabel=N'LogShippingStatus'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#LogShippingStatus_P'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
