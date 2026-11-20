USE [DeineDatenbank];
GO

SET QUOTED_IDENTIFIER ON;
GO

/*
===============================================================================
Objekt       : monitor.USP_ExtendedEventsDeadlocks
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer
               vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen
               in Summary-, Victim-, Process- und Resource-Resultsets.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : system_health oder andere bestehende Session; event_file über
               sys.fn_xe_file_target_read_file, optional ring_buffer über
               sys.dm_xe_session_targets.
Parameter    : @ResolvedSourceExtendedEventSessionName, @Quelle, @FilePath, @VonUtc, @BisUtc, @MaxZeilen,
               @MitDeadlockXml, @MitProcessDetails, @MitResourceDetails,
               @BestaetigeTargetFlush, @PrintMeldungen, @Hilfe.
Resultsets   : 1. Modulstatus. 2. Deadlock-Summary. 3. Victims. 4. Processes.
               5. Resources. 6. Quellen-/Fehlerstatus.
Berechtigung : SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE
               STATE oder höher. Das Framework vergibt keine Rechte.
Eigenlast    : Event-Datei- und XML-abhängig; Maximalzahl und UTC-Filter werden
               vor der XML-Zerlegung angewandt. Trotzdem können XEL-Dateien
               vollständig gelesen werden müssen.
Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte und keine Änderungen.
Nebenwirkung : Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1, weil die
               Abfrage von sys.dm_xe_session_targets einen Flush auslösen kann.
Partial      : Fehlende Session, Target, Datei oder Rechte liefern Status statt
               Abbruch. Deadlockhistorie ist für den Framework-Core optional.
Beispiele    : EXEC monitor.USP_ExtendedEventsDeadlocks;
               EXEC monitor.USP_ExtendedEventsDeadlocks
                   @Quelle='RING_BUFFER', @BestaetigeTargetFlush=1;
               EXEC monitor.USP_ExtendedEventsDeadlocks @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 5.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_ExtendedEventsDeadlocks 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_ExtendedEventsDeadlocks"
-- schema_name: "monitor"
-- object_name: "USP_ExtendedEventsDeadlocks"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen in Summary-, Victim-, Process- und Resource-Resultsets."
-- source_path: "Code/06_ExtendedEvents/030_USP_ExtendedEventsDeadlocks.sql"
-- ---
-- 
-- # monitor.USP_ExtendedEventsDeadlocks
-- 
-- ## Zweck und Einsatz
-- 
-- Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen in Summary-, Victim-, Process- und Resource-Resultsets.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- SQL Server 2019 oder neuer.
-- 
-- system_health oder andere bestehende Session; event_file über sys.fn_xe_file_target_read_file, optional ring_buffer über sys.dm_xe_session_targets.
-- 
-- SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE STATE oder höher. Das Framework vergibt keine Rechte.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SourceExtendedEventSessionName | nvarchar(258) | nein | N'system_health' |
-- | @Quelle | varchar(20) | nein | 'AUTO' |
-- | @FilePath | nvarchar(4000) | nein | NULL |
-- | @VonUtc | datetime2(7) | nein | NULL |
-- | @BisUtc | datetime2(7) | nein | NULL |
-- | @MaxZeilen | int | nein | 100 |
-- | @MitDeadlockXml | bit | nein | 1 |
-- | @MitProcessDetails | bit | nein | 1 |
-- | @MitResourceDetails | bit | nein | 1 |
-- | @BestaetigeTargetFlush | bit | nein | 0 |
-- | @HighImpactConfirmed | bit | nein | 0 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@SourceExtendedEventSessionName:** @SourceExtendedEventSessionName nvarchar(258). Default ist N'system_health'. Bezeichnet genau eine vorhandene Extended-Events-Session, die xml_deadlock_report erfasst. Der Name darf optional geklammert sein. NULL, eine ungültige Angabe oder mehrere Namen ergeben INVALID_PARAMETER. Leertext ist ungültig.
-- 
-- **@Quelle:** @Quelle varchar(20). Default ist 'AUTO'. Geschlossene Auswahl: AUTO wählt EVENT_FILE, wenn ein expliziter oder konfigurierter Dateipfad vorliegt. andernfalls wird RING_BUFFER nur bei bestätigtem Target-Flush gewählt. EVENT_FILE erzwingt das Dateiziel, RING_BUFFER das laufende Ring-Buffer-Ziel. NULL, leer oder ein anderer Wert ist ungültig. Werte werden getrimmt und in Großbuchstaben umgewandelt.
-- 
-- **@FilePath:** @FilePath nvarchar(4000). Default ist NULL. Expliziter XEL-Pfad oder URL. NULL oder leer verwendet den in der Sessiondefinition konfigurierten Eventfile-Pfad. Endet der Pfad auf .xel, wird diese Endung durch *.xel ersetzt. Enthält er kein * und endet nicht auf .xel, wird *.xel angehängt. Ein expliziter Pfad kann AUTO zur Wahl des Eventfiles führen.
-- 
-- **@VonUtc:** @VonUtc datetime2(7). Default ist NULL. Untere UTC-Zeitgrenze einschließlich. NULL wird zur Laufzeit auf UTC jetzt minus 24 Stunden gesetzt. Ein expliziter Wert ersetzt diesen Standard.
-- 
-- **@BisUtc:** @BisUtc datetime2(7). Default ist NULL. Obere UTC-Zeitgrenze ausschließlich. NULL lässt die Obergrenze offen. Sind beide Grenzen gesetzt, muss @VonUtc kleiner als @BisUtc sein.
-- 
-- **@MaxZeilen:** @MaxZeilen int. Default ist 100. Begrenzt die ausgewählten Deadlockereignisse vor der Graphzerlegung. NULL oder 0 bedeutet unbegrenzt. negative Werte sind ungültig. Eine Begrenzung kann den vollständigen physischen Scan von XEL-Rolloverdateien nicht verhindern.
-- 
-- **@MitDeadlockXml:** @MitDeadlockXml bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ausgabe des vollständigen Deadlock-XML in der Summary. 0 unterdrückt diese XML-Spalte, verhindert aber nicht das Einlesen und die für die übrigen Resultate erforderliche Graphverarbeitung.
-- 
-- **@MitProcessDetails:** @MitProcessDetails bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Prozessdetailausgabe und deren Detailzerlegung. Die für Victim- und Summary-Ausgaben erforderliche Verarbeitung bleibt davon unberührt.
-- 
-- **@MitResourceDetails:** @MitResourceDetails bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ressourcendetails einschließlich Owner-/Waiter-XML. 0 fordert diese Detailausgabe nicht an.
-- 
-- **@BestaetigeTargetFlush:** @BestaetigeTargetFlush bit. Default ist 0. 1 bestätigt den möglichen Target-Flush beim Ringbuffer-Lesen. 0 sperrt den expliziten Ringbufferzugriff. Beim expliziten Aufruf kann NULL die bestehende Prüfung auf 0 passieren. Verwenden Sie ausdrücklich 0 oder 1. AUTO wechselt nur bei 1 zum Ringbuffer.
-- 
-- **@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 1 bestätigt einen geschützten Pfad nach der aktiven Policy für EXTENDED_EVENTS_FORENSICS_DEEP. 0 bestätigt ihn nicht. NULL ist für die Gate-Prüfung ungültig. Die aktuelle Berechtigung wird zusätzlich geprüft.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. Geschlossene Auswahl nach Trimmen und Umwandlung in Großbuchstaben: RAW gibt technische Rohresultate aus, CONSOLE dient der interaktiven Ausgabe, NONE unterdrückt Resultsets zugunsten des OUTPUT-JSON, TABLE schreibt das registrierte Fachresultat in ein bereitgestelltes Ziel. CONSOLE und TABLE werden intern auf NONE gesetzt, bevor die Fachresultate ausgegeben/geschrieben werden. NULL, leer und andere Werte sind ungültig.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel deadlocks erforderlich. Der Wert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und #Monitor als Präfix sind ausgeschlossen. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT-Parameter für das erzeugte JSON. Der Wert wird am Prozedurbeginn auf NULL gesetzt. NULL bedeutet daher, dass kein JSON geliefert wurde oder die Erzeugung nicht bis zu einem Ergebnis gelangte.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt bei Status außerhalb AVAILABLE und AVAILABLE_LIMITED eine Warnung mit Severity 10 aus. 0 unterdrückt diese Warnmeldung. NULL verhält sich über die IF-Bedingung wie aus, da nur exakt 1 wahr ist.
-- 
-- **@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der TABLE-Zuordnungsprüfung und beendet den Aufruf vor dem Quellzugriff. 0 und NULL setzen den normalen Aufruf fort.
-- 
-- ## Resultate und Ausgabe
-- 
-- 1. Modulstatus. 2. Deadlock-Summary. 3. Victims. 4. Processes. 5. Resources. 6. Quellen-/Fehlerstatus.
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | deadlocks | 1 | 1 | [DeadlockId] int,[SourceType] varchar(20),[DeadlockTimeUtc] datetime2(7),[FileName] nvarchar(260),[FileOffset] bigint,[VictimCount] int,[ProcessCount] int,[ResourceCount] int,[FirstDatabaseId] int NULL,[DeadlockXml] xml NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC monitor.USP_ExtendedEventsDeadlocks; EXEC monitor.USP_ExtendedEventsDeadlocks @Quelle='RING_BUFFER', @BestaetigeTargetFlush=1; EXEC monitor.USP_ExtendedEventsDeadlocks @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1, weil die Abfrage von sys.dm_xe_session_targets einen Flush auslösen kann.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_ExtendedEventsDeadlocks
-- Version      : 2.0.0
-- Stand        : 2026-07-15
-- Typ          : Stored Procedure
-- Zweck        : Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer
--                vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen
--                in Summary-, Victim-, Process- und Resource-Resultsets.
-- SQL-Version  : SQL Server 2019 oder neuer.
-- Datenquellen : system_health oder andere bestehende Session; event_file über
--                sys.fn_xe_file_target_read_file, optional ring_buffer über
--                sys.dm_xe_session_targets.
-- Parameter    : @ResolvedSourceExtendedEventSessionName, @Quelle, @FilePath, @VonUtc, @BisUtc, @MaxZeilen,
--                @MitDeadlockXml, @MitProcessDetails, @MitResourceDetails,
--                @BestaetigeTargetFlush, @PrintMeldungen, @Hilfe.
-- Resultsets   : 1. Modulstatus. 2. Deadlock-Summary. 3. Victims. 4. Processes.
--                5. Resources. 6. Quellen-/Fehlerstatus.
-- Berechtigung : SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE
--                STATE oder höher. Das Framework vergibt keine Rechte.
-- Eigenlast    : Event-Datei- und XML-abhängig; Maximalzahl und UTC-Filter werden
--                vor der XML-Zerlegung angewandt. Trotzdem können XEL-Dateien
--                vollständig gelesen werden müssen.
-- Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte und keine Änderungen.
-- Nebenwirkung : Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1, weil die
--                Abfrage von sys.dm_xe_session_targets einen Flush auslösen kann.
-- Partial      : Fehlende Session, Target, Datei oder Rechte liefern Status statt
--                Abbruch. Deadlockhistorie ist für den Framework-Core optional.
-- Beispiele    : EXEC monitor.USP_ExtendedEventsDeadlocks;
--                EXEC monitor.USP_ExtendedEventsDeadlocks
--                    @Quelle='RING_BUFFER', @BestaetigeTargetFlush=1;
--                EXEC monitor.USP_ExtendedEventsDeadlocks @Hilfe=1;
-- Änderungen   : 1.0.0 - Erstfassung Phase 5.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_ExtendedEventsDeadlocks
-- Beispiel 1. EXEC [monitor].[USP_ExtendedEventsDeadlocks] @Hilfe=1;
-- Beispiel 2. DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt='RAW';
-- Beispiel 3. DECLARE @ExampleJson nvarchar(max); DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS ExampleJson;
-- Beispiel 4. CREATE TABLE #ExtendedEventsDeadlocks_HelpExample ([Seed] int NULL); BEGIN TRY DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N'system_health',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt='TABLE',@ResultTablesJson=N'{"deadlocks":"#ExtendedEventsDeadlocks_HelpExample"}'; SELECT * FROM #ExtendedEventsDeadlocks_HelpExample; DROP TABLE #ExtendedEventsDeadlocks_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsDeadlocks_HelpExample; THROW; END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_ExtendedEventsDeadlocks
CREATE OR ALTER PROCEDURE [monitor].[USP_ExtendedEventsDeadlocks]
      @SourceExtendedEventSessionName nvarchar(258)         = N'system_health'
    , @Quelle                  varchar(20)     = 'AUTO'
    , @FilePath                nvarchar(4000)  = NULL
    , @VonUtc                  datetime2(7)    = NULL
    , @BisUtc                  datetime2(7)    = NULL
    , @MaxZeilen               int             = 100
    , @MitDeadlockXml          bit             = 1
    , @MitProcessDetails       bit             = 1
    , @MitResourceDetails      bit             = 1
    , @BestaetigeTargetFlush   bit             = 0
    , @HighImpactConfirmed     bit             = 0
    , @ResultSetArt                   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                   bit            = 0
    , @Json                            nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen          bit             = 1
    , @Hilfe                   bit             = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_ExtendedEventsDeadlocks';
        PRINT N'@SourceExtendedEventSessionName nvarchar(258). Default ist N''system_health''. Bezeichnet genau eine vorhandene Extended-Events-Session, die xml_deadlock_report erfasst. Der Name darf optional geklammert sein. NULL, eine ungültige Angabe oder mehrere Namen ergeben INVALID_PARAMETER. Leertext ist ungültig.';
        PRINT N'@Quelle varchar(20). Default ist ''AUTO''. Geschlossene Auswahl: AUTO wählt EVENT_FILE, wenn ein expliziter oder konfigurierter Dateipfad vorliegt. andernfalls wird RING_BUFFER nur bei bestätigtem Target-Flush gewählt. EVENT_FILE erzwingt das Dateiziel, RING_BUFFER das laufende Ring-Buffer-Ziel. NULL, leer oder ein anderer Wert ist ungültig. Werte werden getrimmt und in Großbuchstaben umgewandelt.';
        PRINT N'@FilePath nvarchar(4000). Default ist NULL. Expliziter XEL-Pfad oder URL. NULL oder leer verwendet den in der Sessiondefinition konfigurierten Eventfile-Pfad. Endet der Pfad auf .xel, wird diese Endung durch *.xel ersetzt. Enthält er kein * und endet nicht auf .xel, wird *.xel angehängt. Ein expliziter Pfad kann AUTO zur Wahl des Eventfiles führen.';
        PRINT N'@VonUtc datetime2(7). Default ist NULL. Untere UTC-Zeitgrenze einschließlich. NULL wird zur Laufzeit auf UTC jetzt minus 24 Stunden gesetzt. Ein expliziter Wert ersetzt diesen Standard.';
        PRINT N'@BisUtc datetime2(7). Default ist NULL. Obere UTC-Zeitgrenze ausschließlich. NULL lässt die Obergrenze offen. Sind beide Grenzen gesetzt, muss @VonUtc kleiner als @BisUtc sein.';
        PRINT N'@MaxZeilen int. Default ist 100. Begrenzt die ausgewählten Deadlockereignisse vor der Graphzerlegung. NULL oder 0 bedeutet unbegrenzt. negative Werte sind ungültig. Eine Begrenzung kann den vollständigen physischen Scan von XEL-Rolloverdateien nicht verhindern.';
        PRINT N'@MitDeadlockXml bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ausgabe des vollständigen Deadlock-XML in der Summary. 0 unterdrückt diese XML-Spalte, verhindert aber nicht das Einlesen und die für die übrigen Resultate erforderliche Graphverarbeitung.';
        PRINT N'@MitProcessDetails bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Prozessdetailausgabe und deren Detailzerlegung. Die für Victim- und Summary-Ausgaben erforderliche Verarbeitung bleibt davon unberührt.';
        PRINT N'@MitResourceDetails bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ressourcendetails einschließlich Owner-/Waiter-XML. 0 fordert diese Detailausgabe nicht an.';
        PRINT N'@BestaetigeTargetFlush bit. Default ist 0. 1 bestätigt den möglichen Target-Flush beim Ringbuffer-Lesen. 0 sperrt den expliziten Ringbufferzugriff. Beim expliziten Aufruf kann NULL die bestehende Prüfung auf 0 passieren. Verwenden Sie ausdrücklich 0 oder 1. AUTO wechselt nur bei 1 zum Ringbuffer.';
        PRINT N'@HighImpactConfirmed bit. Default ist 0. 1 bestätigt einen geschützten Pfad nach der aktiven Policy für EXTENDED_EVENTS_FORENSICS_DEEP. 0 bestätigt ihn nicht. NULL ist für die Gate-Prüfung ungültig. Die aktuelle Berechtigung wird zusätzlich geprüft.';
        PRINT N'@ResultSetArt varchar(16). Default ist ''CONSOLE''. Geschlossene Auswahl nach Trimmen und Umwandlung in Großbuchstaben: RAW gibt technische Rohresultate aus, CONSOLE dient der interaktiven Ausgabe, NONE unterdrückt Resultsets zugunsten des OUTPUT-JSON, TABLE schreibt das registrierte Fachresultat in ein bereitgestelltes Ziel. CONSOLE und TABLE werden intern auf NONE gesetzt, bevor die Fachresultate ausgegeben/geschrieben werden. NULL, leer und andere Werte sind ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel deadlocks erforderlich. Der Wert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und #Monitor als Präfix sind ausgeschlossen. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.';
        PRINT N'@JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument.';
        PRINT N'@Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT-Parameter für das erzeugte JSON. Der Wert wird am Prozedurbeginn auf NULL gesetzt. NULL bedeutet daher, dass kein JSON geliefert wurde oder die Erzeugung nicht bis zu einem Ergebnis gelangte.';
        PRINT N'@PrintMeldungen bit. Default ist 1. 1 gibt bei Status außerhalb AVAILABLE und AVAILABLE_LIMITED eine Warnung mit Severity 10 aus. 0 unterdrückt diese Warnmeldung. NULL verhält sich über die IF-Bedingung wie aus, da nur exakt 1 wahr ist.';
        PRINT N'@Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der TABLE-Zuordnungsprüfung und beendet den Aufruf vor dem Quellzugriff. 0 und NULL setzen den normalen Aufruf fort.';
        PRINT N'Beispiel 1. EXEC [monitor].[USP_ExtendedEventsDeadlocks] @Hilfe=1;';
        PRINT N'Beispiel 2. DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N''system_health'',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3. DECLARE @ExampleJson nvarchar(max); DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N''system_health'',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS ExampleJson;';
        PRINT N'Beispiel 4. CREATE TABLE #ExtendedEventsDeadlocks_HelpExample ([Seed] int NULL); BEGIN TRY DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N''system_health'',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt=''TABLE'',@ResultTablesJson=N''{"deadlocks":"#ExtendedEventsDeadlocks_HelpExample"}''; SELECT * FROM #ExtendedEventsDeadlocks_HelpExample; DROP TABLE #ExtendedEventsDeadlocks_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsDeadlocks_HelpExample; THROW; END CATCH;';
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_ExtendedEventsDeadlocks
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_ExtendedEventsDeadlocks') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_ExtendedEventsDeadlocks"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_ExtendedEventsDeadlocks"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen in Summary-, Victim-, Process- und Resource-Resultsets."'
            + NCHAR(10)
            + N'source_path: "Code/06_ExtendedEvents/030_USP_ExtendedEventsDeadlocks.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_ExtendedEventsDeadlocks'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen in Summary-, Victim-, Process- und Resource-Resultsets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'system_health oder andere bestehende Session; event_file über sys.fn_xe_file_target_read_file, optional ring_buffer über sys.dm_xe_session_targets.'
            + NCHAR(10)
            + NCHAR(10)
            + N'SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE STATE oder höher. Das Framework vergibt keine Rechte.'
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
            + N'| @SourceExtendedEventSessionName | nvarchar(258) | nein | N''system_health'' |'
            + NCHAR(10)
            + N'| @Quelle | varchar(20) | nein | ''AUTO'' |'
            + NCHAR(10)
            + N'| @FilePath | nvarchar(4000) | nein | NULL |'
            + NCHAR(10)
            + N'| @VonUtc | datetime2(7) | nein | NULL |'
            + NCHAR(10)
            + N'| @BisUtc | datetime2(7) | nein | NULL |'
            + NCHAR(10)
            + N'| @MaxZeilen | int | nein | 100 |'
            + NCHAR(10)
            + N'| @MitDeadlockXml | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @MitProcessDetails | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @MitResourceDetails | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @BestaetigeTargetFlush | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @HighImpactConfirmed | bit | nein | 0 |'
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
            + N'**@SourceExtendedEventSessionName:** @SourceExtendedEventSessionName nvarchar(258). Default ist N''system_health''. Bezeichnet genau eine vorhandene Extended-Events-Session, die xml_deadlock_report erfasst. Der Name darf optional geklammert sein. NULL, eine ungültige Angabe oder mehrere Namen ergeben INVALID_PARAMETER. Leertext ist ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Quelle:** @Quelle varchar(20). Default ist ''AUTO''. Geschlossene Auswahl: AUTO wählt EVENT_FILE, wenn ein expliziter oder konfigurierter Dateipfad vorliegt. andernfalls wird RING_BUFFER nur bei bestätigtem Target-Flush gewählt. EVENT_FILE erzwingt das Dateiziel, RING_BUFFER das laufende Ring-Buffer-Ziel. NULL, leer oder ein anderer Wert ist ungültig. Werte werden getrimmt und in Großbuchstaben umgewandelt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@FilePath:** @FilePath nvarchar(4000). Default ist NULL. Expliziter XEL-Pfad oder URL. NULL oder leer verwendet den in der Sessiondefinition konfigurierten Eventfile-Pfad. Endet der Pfad auf .xel, wird diese Endung durch *.xel ersetzt. Enthält er kein * und endet nicht auf .xel, wird *.xel angehängt. Ein expliziter Pfad kann AUTO zur Wahl des Eventfiles führen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@VonUtc:** @VonUtc datetime2(7). Default ist NULL. Untere UTC-Zeitgrenze einschließlich. NULL wird zur Laufzeit auf UTC jetzt minus 24 Stunden gesetzt. Ein expliziter Wert ersetzt diesen Standard.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@BisUtc:** @BisUtc datetime2(7). Default ist NULL. Obere UTC-Zeitgrenze ausschließlich. NULL lässt die Obergrenze offen. Sind beide Grenzen gesetzt, muss @VonUtc kleiner als @BisUtc sein.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int. Default ist 100. Begrenzt die ausgewählten Deadlockereignisse vor der Graphzerlegung. NULL oder 0 bedeutet unbegrenzt. negative Werte sind ungültig. Eine Begrenzung kann den vollständigen physischen Scan von XEL-Rolloverdateien nicht verhindern.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitDeadlockXml:** @MitDeadlockXml bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ausgabe des vollständigen Deadlock-XML in der Summary. 0 unterdrückt diese XML-Spalte, verhindert aber nicht das Einlesen und die für die übrigen Resultate erforderliche Graphverarbeitung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitProcessDetails:** @MitProcessDetails bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Prozessdetailausgabe und deren Detailzerlegung. Die für Victim- und Summary-Ausgaben erforderliche Verarbeitung bleibt davon unberührt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitResourceDetails:** @MitResourceDetails bit. Default ist 1. 1 aktiviert die beschriebene Funktion. 0 und NULL deaktivieren sie. Steuert die Ressourcendetails einschließlich Owner-/Waiter-XML. 0 fordert diese Detailausgabe nicht an.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@BestaetigeTargetFlush:** @BestaetigeTargetFlush bit. Default ist 0. 1 bestätigt den möglichen Target-Flush beim Ringbuffer-Lesen. 0 sperrt den expliziten Ringbufferzugriff. Beim expliziten Aufruf kann NULL die bestehende Prüfung auf 0 passieren. Verwenden Sie ausdrücklich 0 oder 1. AUTO wechselt nur bei 1 zum Ringbuffer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 1 bestätigt einen geschützten Pfad nach der aktiven Policy für EXTENDED_EVENTS_FORENSICS_DEEP. 0 bestätigt ihn nicht. NULL ist für die Gate-Prüfung ungültig. Die aktuelle Berechtigung wird zusätzlich geprüft.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16). Default ist ''CONSOLE''. Geschlossene Auswahl nach Trimmen und Umwandlung in Großbuchstaben: RAW gibt technische Rohresultate aus, CONSOLE dient der interaktiven Ausgabe, NONE unterdrückt Resultsets zugunsten des OUTPUT-JSON, TABLE schreibt das registrierte Fachresultat in ein bereitgestelltes Ziel. CONSOLE und TABLE werden intern auf NONE gesetzt, bevor die Fachresultate ausgegeben/geschrieben werden. NULL, leer und andere Werte sind ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem Schlüssel deadlocks erforderlich. Der Wert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte. Der Name darf höchstens 116 Zeichen lang sein. Globale Tabellen und #Monitor als Präfix sind ausgeschlossen. Außerhalb von TABLE sind nur NULL, Leertext und Leerzeichen erlaubt. Die Prüfung läuft vor der Hilfe und kann Fehler 51011 auslösen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. OUTPUT-Parameter für das erzeugte JSON. Der Wert wird am Prozedurbeginn auf NULL gesetzt. NULL bedeutet daher, dass kein JSON geliefert wurde oder die Erzeugung nicht bis zu einem Ergebnis gelangte.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 gibt bei Status außerhalb AVAILABLE und AVAILABLE_LIMITED eine Warnung mit Severity 10 aus. 0 unterdrückt diese Warnmeldung. NULL verhält sich über die IF-Bedingung wie aus, da nur exakt 1 wahr ist.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der TABLE-Zuordnungsprüfung und beendet den Aufruf vor dem Quellzugriff. 0 und NULL setzen den normalen Aufruf fort.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'1. Modulstatus. 2. Deadlock-Summary. 3. Victims. 4. Processes. 5. Resources. 6. Quellen-/Fehlerstatus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| deadlocks | 1 | 1 | [DeadlockId] int,[SourceType] varchar(20),[DeadlockTimeUtc] datetime2(7),[FileName] nvarchar(260),[FileOffset] bigint,[VictimCount] int,[ProcessCount] int,[ResourceCount] int,[FirstDatabaseId] int NULL,[DeadlockXml] xml NULL |'
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
            + N'EXEC monitor.USP_ExtendedEventsDeadlocks; EXEC monitor.USP_ExtendedEventsDeadlocks @Quelle=''RING_BUFFER'', @BestaetigeTargetFlush=1; EXEC monitor.USP_ExtendedEventsDeadlocks @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1, weil die Abfrage von sys.dm_xe_session_targets einen Flush auslösen kann.'
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
            + N'Objekt       : monitor.USP_ExtendedEventsDeadlocks'
            + NCHAR(10)
            + N'Version      : 2.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-15'
            + NCHAR(10)
            + N'Typ          : Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Liest bereits erfasste xml_deadlock_report-Ereignisse aus einer'
            + NCHAR(10)
            + N'               vorhandenen Extended-Events-Session und zerlegt Deadlockgraphen'
            + NCHAR(10)
            + N'               in Summary-, Victim-, Process- und Resource-Resultsets.'
            + NCHAR(10)
            + N'SQL-Version  : SQL Server 2019 oder neuer.'
            + NCHAR(10)
            + N'Datenquellen : system_health oder andere bestehende Session; event_file über'
            + NCHAR(10)
            + N'               sys.fn_xe_file_target_read_file, optional ring_buffer über'
            + NCHAR(10)
            + N'               sys.dm_xe_session_targets.'
            + NCHAR(10)
            + N'Parameter    : @ResolvedSourceExtendedEventSessionName, @Quelle, @FilePath, @VonUtc, @BisUtc, @MaxZeilen,'
            + NCHAR(10)
            + N'               @MitDeadlockXml, @MitProcessDetails, @MitResourceDetails,'
            + NCHAR(10)
            + N'               @BestaetigeTargetFlush, @PrintMeldungen, @Hilfe.'
            + NCHAR(10)
            + N'Resultsets   : 1. Modulstatus. 2. Deadlock-Summary. 3. Victims. 4. Processes.'
            + NCHAR(10)
            + N'               5. Resources. 6. Quellen-/Fehlerstatus.'
            + NCHAR(10)
            + N'Berechtigung : SQL 2019 VIEW SERVER STATE; SQL 2022+ VIEW SERVER PERFORMANCE'
            + NCHAR(10)
            + N'               STATE oder höher. Das Framework vergibt keine Rechte.'
            + NCHAR(10)
            + N'Eigenlast    : Event-Datei- und XML-abhängig; Maximalzahl und UTC-Filter werden'
            + NCHAR(10)
            + N'               vor der XML-Zerlegung angewandt. Trotzdem können XEL-Dateien'
            + NCHAR(10)
            + N'               vollständig gelesen werden müssen.'
            + NCHAR(10)
            + N'Locking      : LOCK_TIMEOUT 0; keine Benutzerobjekte und keine Änderungen.'
            + NCHAR(10)
            + N'Nebenwirkung : Ringbuffer-Lesen erfordert @BestaetigeTargetFlush=1, weil die'
            + NCHAR(10)
            + N'               Abfrage von sys.dm_xe_session_targets einen Flush auslösen kann.'
            + NCHAR(10)
            + N'Partial      : Fehlende Session, Target, Datei oder Rechte liefern Status statt'
            + NCHAR(10)
            + N'               Abbruch. Deadlockhistorie ist für den Framework-Core optional.'
            + NCHAR(10)
            + N'Beispiele    : EXEC monitor.USP_ExtendedEventsDeadlocks;'
            + NCHAR(10)
            + N'               EXEC monitor.USP_ExtendedEventsDeadlocks'
            + NCHAR(10)
            + N'                   @Quelle=''RING_BUFFER'', @BestaetigeTargetFlush=1;'
            + NCHAR(10)
            + N'               EXEC monitor.USP_ExtendedEventsDeadlocks @Hilfe=1;'
            + NCHAR(10)
            + N'Änderungen   : 1.0.0 - Erstfassung Phase 5.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_ExtendedEventsDeadlocks'
            + NCHAR(10)
            + N'Beispiel 1. EXEC [monitor].[USP_ExtendedEventsDeadlocks] @Hilfe=1;'
            + NCHAR(10)
            + N'Beispiel 2. DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N''system_health'',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'Beispiel 3. DECLARE @ExampleJson nvarchar(max); DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N''system_health'',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS ExampleJson;'
            + NCHAR(10)
            + N'Beispiel 4. CREATE TABLE #ExtendedEventsDeadlocks_HelpExample ([Seed] int NULL); BEGIN TRY DECLARE @ExampleBisUtc datetime2(7)=SYSUTCDATETIME(); DECLARE @ExampleVonUtc datetime2(7)=DATEADD(HOUR,-1,@ExampleBisUtc); EXEC [monitor].[USP_ExtendedEventsDeadlocks] @SourceExtendedEventSessionName=N''system_health'',@VonUtc=@ExampleVonUtc,@BisUtc=@ExampleBisUtc,@MaxZeilen=25,@MitDeadlockXml=0,@MitProcessDetails=0,@MitResourceDetails=0,@HighImpactConfirmed=1,@ResultSetArt=''TABLE'',@ResultTablesJson=N''{"deadlocks":"#ExtendedEventsDeadlocks_HelpExample"}''; SELECT * FROM #ExtendedEventsDeadlocks_HelpExample; DROP TABLE #ExtendedEventsDeadlocks_HelpExample; END TRY BEGIN CATCH DROP TABLE #ExtendedEventsDeadlocks_HelpExample; THROW; END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_ExtendedEventsDeadlocks
        RETURN;
    END

    SET @Json=NULL;
    DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'deadlocks',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @ResolvedSourceExtendedEventSessionName sysname=NULL;
    DECLARE @EffectiveMaxZeilen bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @MonitorPrintMessage nvarchar(2048);

    ;

    IF @SourceExtendedEventSessionName IS NULL OR (SELECT COUNT_BIG(*) FROM [monitor].[TVF_ParseSqlNameList](@SourceExtendedEventSessionName) WHERE [IsValid]=1)<>1 OR EXISTS(SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@SourceExtendedEventSessionName) WHERE [IsValid]=0)
    BEGIN SET @ResolvedSourceExtendedEventSessionName=NULL;END
    ELSE SELECT @ResolvedSourceExtendedEventSessionName=MIN([NameValue]) FROM [monitor].[TVF_ParseSqlNameList](@SourceExtendedEventSessionName) WHERE [IsValid]=1;

    DECLARE
        @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME(),
        @StatusCode varchar(40) = 'AVAILABLE',
        @IsPartial bit = 0,
        @ErrorNumber int = NULL,
        @ErrorMessage nvarchar(2048) = NULL,
        @RowCount bigint = 0,
        @Allowed bit = 1,
        @ResolvedSource varchar(20) = UPPER(LTRIM(RTRIM(COALESCE(@Quelle, '')))),
        @ConfiguredFilePath nvarchar(4000) = NULL,
        @ResolvedFilePath nvarchar(4000) = NULL,
        @TargetData xml = NULL;

    IF @VonUtc IS NULL SET @VonUtc = DATEADD(HOUR, -24, SYSUTCDATETIME());

    CREATE TABLE [#ExtendedEventsDeadlocks_Raw]
    (
        [SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [TimestampUtc] datetime2(7) NULL,
        [FileName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [FileOffset] bigint NULL,
        [EventXml] xml NULL
    );

    CREATE TABLE [#ExtendedEventsDeadlocks_Deadlocks]
    (
        [DeadlockId] int IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [DeadlockTimeUtc] datetime2(7) NULL,
        [FileName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [FileOffset] bigint NULL,
        [DeadlockXml] xml NULL
    );

    CREATE TABLE [#ExtendedEventsDeadlocks_Victims]
    (
        [DeadlockId] int NOT NULL,
        [DeadlockTimeUtc] datetime2(7) NULL,
        [VictimProcessId] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        PRIMARY KEY(DeadlockId, VictimProcessId)
    );

    CREATE TABLE [#ExtendedEventsDeadlocks_SourceStatus]
    (
        [SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SessionName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ResolvedPath] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    IF @ResolvedSourceExtendedEventSessionName IS NULL BEGIN SET @StatusCode='INVALID_PARAMETER';SET @ErrorMessage=N'@SourceExtendedEventSessionName muss genau einen gültigen, optional geklammerten sysname enthalten.';END;

    IF @ResolvedSource NOT IN ('AUTO','EVENT_FILE','RING_BUFFER')
    BEGIN SET @StatusCode='INVALID_PARAMETER'; SET @ErrorMessage=N'@Quelle muss AUTO, EVENT_FILE oder RING_BUFFER sein.'; END;
    IF @MaxZeilen<0 OR @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE')
    BEGIN SET @StatusCode='INVALID_PARAMETER'; SET @ErrorMessage=N'@MaxZeilen darf nicht negativ sein; NULL/0 bedeutet unbegrenzt.'; END;
    IF @VonUtc IS NOT NULL AND @BisUtc IS NOT NULL AND @VonUtc >= @BisUtc
    BEGIN SET @StatusCode='INVALID_PARAMETER'; SET @ErrorMessage=N'@VonUtc muss kleiner als @BisUtc sein.'; END;

    IF @StatusCode='AVAILABLE'
        EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass='EXTENDED_EVENTS_FORENSICS_DEEP',@HighImpactConfirmed=@HighImpactConfirmed,@StatusCode=@StatusCode OUTPUT,@ErrorMessage=@ErrorMessage OUTPUT;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode='AVAILABLE'
    BEGIN
        BEGIN TRY
            SELECT @ConfiguredFilePath=MAX(CONVERT(nvarchar(4000),[f].[value]))
            FROM [sys].[server_event_sessions] AS s WITH (NOLOCK)
            JOIN [sys].[server_event_session_targets] AS t WITH (NOLOCK)
              ON [t].[event_session_id]=[s].[event_session_id] AND [t].[name]=N'event_file'
            LEFT JOIN [sys].[server_event_session_fields] AS f WITH (NOLOCK)
              ON [f].[event_session_id]=[t].[event_session_id] AND [f].[object_id]=[t].[target_id] AND [f].[name]=N'filename'
            WHERE [s].[name]=@ResolvedSourceExtendedEventSessionName;
        END TRY
        BEGIN CATCH
            SET @IsPartial=1;
            INSERT [#ExtendedEventsDeadlocks_SourceStatus] VALUES('CATALOG',@ResolvedSourceExtendedEventSessionName,NULL,
              CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
              ERROR_NUMBER(),ERROR_MESSAGE(),N'Pfadermittlung fehlgeschlagen; ein expliziter @FilePath kann weiterhin verwendet werden.');
        END CATCH;

        IF @ResolvedSource='AUTO'
        BEGIN
            IF @FilePath IS NOT NULL OR @ConfiguredFilePath IS NOT NULL SET @ResolvedSource='EVENT_FILE';
            ELSE IF @BestaetigeTargetFlush=1 SET @ResolvedSource='RING_BUFFER';
            ELSE
            BEGIN SET @StatusCode='AVAILABLE_DISABLED'; SET @ErrorMessage=N'Kein event_file-Pfad; Ringbuffer ohne Bestätigung nicht gelesen.'; END;
        END;
    END;

    IF @StatusCode='AVAILABLE' AND @ResolvedSource='EVENT_FILE'
    BEGIN
        SET @ResolvedFilePath=COALESCE(NULLIF(@FilePath,N''),NULLIF(@ConfiguredFilePath,N''));
        IF @ResolvedFilePath IS NULL
        BEGIN
            SET @StatusCode='UNAVAILABLE_OBJECT'; SET @ErrorMessage=N'Kein event_file-Pfad verfügbar.';
            INSERT [#ExtendedEventsDeadlocks_SourceStatus] VALUES('EVENT_FILE',@ResolvedSourceExtendedEventSessionName,NULL,@StatusCode,NULL,@ErrorMessage,N'Keine XEL-Datei gelesen.');
        END
        ELSE
        BEGIN
            IF (RIGHT(LOWER(@ResolvedFilePath),4) = N'.xel')
                SET @ResolvedFilePath=LEFT(@ResolvedFilePath,LEN(@ResolvedFilePath)-4)+N'*.xel';
            ELSE IF CHARINDEX(N'*',@ResolvedFilePath)=0
                SET @ResolvedFilePath=@ResolvedFilePath+N'*.xel';

            BEGIN TRY
                INSERT [#ExtendedEventsDeadlocks_Raw]([SourceType],[TimestampUtc],[FileName],[FileOffset],[EventXml])
                SELECT TOP (@EffectiveMaxZeilen)
                    'EVENT_FILE',[r].[timestamp_utc],[r].[file_name],[r].[file_offset],CONVERT([xml],[r].[event_data])
                FROM sys.fn_xe_file_target_read_file(@ResolvedFilePath,NULL,NULL,NULL) AS r
                WHERE [r].[object_name]=N'xml_deadlock_report'
                  AND (@VonUtc IS NULL OR [r].[timestamp_utc]>=@VonUtc)
                  AND (@BisUtc IS NULL OR [r].[timestamp_utc]<@BisUtc)
                ORDER BY [r].[timestamp_utc] DESC,[r].[file_name] DESC,[r].[file_offset] DESC;
                INSERT [#ExtendedEventsDeadlocks_SourceStatus] VALUES('EVENT_FILE',@ResolvedSourceExtendedEventSessionName,@ResolvedFilePath,'AVAILABLE',NULL,NULL,N'xml_deadlock_report aus XEL gelesen.');
            END TRY
            BEGIN CATCH
                SET @StatusCode=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN(6335,6336,6337) THEN 'XML_UNAVAILABLE_LIMIT' WHEN ERROR_NUMBER() BETWEEN 9400 AND 9431 THEN 'XML_INVALID' ELSE 'ERROR_HANDLED' END;
                SET @ErrorNumber=ERROR_NUMBER(); SET @ErrorMessage=ERROR_MESSAGE();
                INSERT [#ExtendedEventsDeadlocks_SourceStatus] VALUES('EVENT_FILE',@ResolvedSourceExtendedEventSessionName,@ResolvedFilePath,@StatusCode,@ErrorNumber,@ErrorMessage,N'XEL-Datei konnte nicht gelesen werden.');
            END CATCH;
        END;
    END;

    IF @StatusCode='AVAILABLE' AND @ResolvedSource='RING_BUFFER'
    BEGIN
        IF @BestaetigeTargetFlush=0
        BEGIN
            SET @StatusCode='AVAILABLE_DISABLED'; SET @ErrorMessage=N'RING_BUFFER erfordert @BestaetigeTargetFlush=1.';
            INSERT [#ExtendedEventsDeadlocks_SourceStatus] VALUES('RING_BUFFER',@ResolvedSourceExtendedEventSessionName,NULL,@StatusCode,NULL,@ErrorMessage,N'Targetdaten wurden nicht gelesen.');
        END
        ELSE
        BEGIN
            BEGIN TRY
                SELECT @TargetData=CONVERT([xml],[t].[target_data])
                FROM [sys].[dm_xe_session_targets] AS t WITH (NOLOCK)
                JOIN [sys].[dm_xe_sessions] AS s WITH (NOLOCK) ON [s].[address]=[t].[event_session_address]
                WHERE [s].[name]=@ResolvedSourceExtendedEventSessionName AND [t].[target_name]=N'ring_buffer';

                IF @TargetData IS NULL
                BEGIN
                    SET @StatusCode='UNAVAILABLE_OBJECT'; SET @ErrorMessage=N'Kein lesbares laufendes ring_buffer-Target gefunden.';
                    INSERT [#ExtendedEventsDeadlocks_SourceStatus] VALUES('RING_BUFFER',@ResolvedSourceExtendedEventSessionName,NULL,@StatusCode,NULL,@ErrorMessage,N'Session gestoppt oder Ringbuffer nicht vorhanden.');
                END
                ELSE
                BEGIN
                    INSERT [#ExtendedEventsDeadlocks_Raw]([SourceType],[TimestampUtc],[FileName],[FileOffset],[EventXml])
                    SELECT TOP (@EffectiveMaxZeilen)
                        'RING_BUFFER',x.e.value('(@timestamp)[1]','datetime2(7)'),NULL,NULL,x.e.query('.')
                    FROM @TargetData.nodes('/RingBufferTarget/event[@name="xml_deadlock_report"]') AS [x]([e])
                    WHERE (@VonUtc IS NULL OR x.e.value('(@timestamp)[1]','datetime2(7)')>=@VonUtc)
                      AND (@BisUtc IS NULL OR x.e.value('(@timestamp)[1]','datetime2(7)')<@BisUtc)
                    ORDER BY x.e.value('(@timestamp)[1]','datetime2(7)') DESC;
                    INSERT [#ExtendedEventsDeadlocks_SourceStatus] VALUES('RING_BUFFER',@ResolvedSourceExtendedEventSessionName,NULL,'AVAILABLE',NULL,NULL,N'Ringbuffer bewusst gelesen; Target-Flush ist möglich.');
                END;
            END TRY
            BEGIN CATCH
                SET @StatusCode=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' WHEN ERROR_NUMBER() IN(6335,6336,6337) THEN 'XML_UNAVAILABLE_LIMIT' WHEN ERROR_NUMBER() BETWEEN 9400 AND 9431 THEN 'XML_INVALID' ELSE 'ERROR_HANDLED' END;
                SET @ErrorNumber=ERROR_NUMBER(); SET @ErrorMessage=ERROR_MESSAGE();
                INSERT [#ExtendedEventsDeadlocks_SourceStatus] VALUES('RING_BUFFER',@ResolvedSourceExtendedEventSessionName,NULL,@StatusCode,@ErrorNumber,@ErrorMessage,N'Ringbuffer konnte nicht gelesen werden.');
            END CATCH;
        END;
    END;

    IF @StatusCode='AVAILABLE'
    BEGIN
        INSERT [#ExtendedEventsDeadlocks_Deadlocks]([SourceType],[DeadlockTimeUtc],[FileName],[FileOffset],[DeadlockXml])
        SELECT [SourceType],[TimestampUtc],[FileName],[FileOffset],
               EventXml.query('(/event/data[@name="xml_report"]/value/deadlock)[1]')
        FROM [#ExtendedEventsDeadlocks_Raw]
        WHERE EventXml.exist('/event/data[@name="xml_report"]/value/deadlock')=1;

        INSERT [#ExtendedEventsDeadlocks_Victims]([DeadlockId],[DeadlockTimeUtc],[VictimProcessId])
        SELECT [d].[DeadlockId],[d].[DeadlockTimeUtc],v.p.value('(@id)[1]','nvarchar(256)')
        FROM [#ExtendedEventsDeadlocks_Deadlocks] AS d
        CROSS APPLY d.DeadlockXml.nodes('/deadlock/victim-list/victimProcess') AS [v]([p]);

        SELECT @RowCount=COUNT_BIG(*) FROM [#ExtendedEventsDeadlocks_Deadlocks];
        IF @RowCount=0
        BEGIN
            SET @StatusCode='AVAILABLE_LIMITED'; SET @IsPartial=1;
            SET @ErrorMessage=N'Quelle lesbar, aber keine passenden Deadlockgraphen gefunden.';
        END;
    END;

    IF @IsPartial=1 AND @StatusCode='AVAILABLE' SET @StatusCode='AVAILABLE_LIMITED';


    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE','AVAILABLE_LIMITED')
        BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG USP_ExtendedEventsDeadlocks: %s - %s', @StatusCode, COALESCE(@ErrorMessage,N'Keine Details.'));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;

    CREATE TABLE [#ExtendedEventsDeadlocks_DeadlockSummary]([DeadlockId] int,[SourceType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS,[DeadlockTimeUtc] datetime2(7),[FileName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS,[FileOffset] bigint,[VictimCount] int,[ProcessCount] int,[ResourceCount] int,[FirstDatabaseId] int NULL,[DeadlockXml] xml NULL);
    CREATE TABLE [#ExtendedEventsDeadlocks_DeadlockProcesses]([DeadlockId] int,[DeadlockTimeUtc] datetime2(7),[ProcessId] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsVictim] bit,[SessionId] int NULL,[ExecutionContextId] int NULL,[ProcessStatus] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitResource] nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitTimeMs] bigint NULL,[LockMode] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS,[TransactionName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsolationLevel] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[DatabaseId] int NULL,[ClientApplication] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[HostName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[LoginName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[HostProcessId] int NULL,[TransactionCount] int NULL,[LogUsed] bigint NULL,[InputBuffer] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS,[ProcessXml] xml NULL);
    CREATE TABLE [#ExtendedEventsDeadlocks_DeadlockResources]([DeadlockId] int,[DeadlockTimeUtc] datetime2(7),[ResourceType] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[DatabaseId] int NULL,[ObjectId] bigint NULL,[IndexId] bigint NULL,[AssociatedObjectId] bigint NULL,[ResourceId] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS,[ResourceMode] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS,[OwnerListXml] xml NULL,[WaiterListXml] xml NULL,[ResourceXml] xml NULL);
    INSERT [#ExtendedEventsDeadlocks_DeadlockSummary] SELECT [d].[DeadlockId],[d].[SourceType],[d].[DeadlockTimeUtc],[d].[FileName],[d].[FileOffset],[d].[DeadlockXml].value('count(/deadlock/victim-list/victimProcess)','int'),[d].[DeadlockXml].value('count(/deadlock/process-list/process)','int'),[d].[DeadlockXml].value('count(/deadlock/resource-list/*)','int'),TRY_CONVERT(int,[d].[DeadlockXml].value('(/deadlock/process-list/process[1]/@currentdb)[1]','nvarchar(32)')),CASE WHEN @MitDeadlockXml=1 THEN [d].[DeadlockXml] END FROM [#ExtendedEventsDeadlocks_Deadlocks] [d];
    IF @MitProcessDetails=1 INSERT [#ExtendedEventsDeadlocks_DeadlockProcesses] SELECT [d].[DeadlockId],[d].[DeadlockTimeUtc],[p].[n].value('(@id)[1]','nvarchar(256)'),CONVERT(bit,CASE WHEN [v].[VictimProcessId] IS NOT NULL THEN 1 ELSE 0 END),TRY_CONVERT(int,[p].[n].value('(@spid)[1]','nvarchar(32)')),TRY_CONVERT(int,[p].[n].value('(@ecid)[1]','nvarchar(32)')),[p].[n].value('(@status)[1]','nvarchar(128)'),[p].[n].value('(@waitresource)[1]','nvarchar(1024)'),TRY_CONVERT(bigint,[p].[n].value('(@waittime)[1]','nvarchar(64)')),[p].[n].value('(@lockMode)[1]','nvarchar(64)'),[p].[n].value('(@transactionname)[1]','nvarchar(256)'),[p].[n].value('(@isolationlevel)[1]','nvarchar(256)'),TRY_CONVERT(int,[p].[n].value('(@currentdb)[1]','nvarchar(32)')),[p].[n].value('(@clientapp)[1]','nvarchar(512)'),[p].[n].value('(@hostname)[1]','nvarchar(512)'),[p].[n].value('(@loginname)[1]','nvarchar(512)'),TRY_CONVERT(int,[p].[n].value('(@hostpid)[1]','nvarchar(32)')),TRY_CONVERT(int,[p].[n].value('(@trancount)[1]','nvarchar(32)')),TRY_CONVERT(bigint,[p].[n].value('(@logused)[1]','nvarchar(64)')),[p].[n].value('(inputbuf/text())[1]','nvarchar(4000)'),[p].[n].query('.') FROM [#ExtendedEventsDeadlocks_Deadlocks] [d] CROSS APPLY [d].[DeadlockXml].nodes('/deadlock/process-list/process') [p]([n]) LEFT JOIN [#ExtendedEventsDeadlocks_Victims] [v] ON [v].[DeadlockId]=[d].[DeadlockId] AND [v].[VictimProcessId]=[p].[n].value('(@id)[1]','nvarchar(256)');
    IF @MitResourceDetails=1 INSERT [#ExtendedEventsDeadlocks_DeadlockResources] SELECT [d].[DeadlockId],[d].[DeadlockTimeUtc],[r].[n].value('local-name(.)','sysname'),TRY_CONVERT(int,[r].[n].value('(@dbid)[1]','nvarchar(32)')),TRY_CONVERT(bigint,[r].[n].value('(@objectid)[1]','nvarchar(64)')),TRY_CONVERT(bigint,[r].[n].value('(@indexid)[1]','nvarchar(64)')),TRY_CONVERT(bigint,[r].[n].value('(@associatedObjectId)[1]','nvarchar(64)')),[r].[n].value('(@id)[1]','nvarchar(512)'),[r].[n].value('(@mode)[1]','nvarchar(64)'),[r].[n].query('(owner-list)[1]'),[r].[n].query('(waiter-list)[1]'),[r].[n].query('.') FROM [#ExtendedEventsDeadlocks_Deadlocks] [d] CROSS APPLY [d].[DeadlockXml].nodes('/deadlock/resource-list/*') [r]([n]);

    IF @ResultSetArtNormalisiert<>'NONE'
    BEGIN
      SELECT N'USP_ExtendedEventsDeadlocks' [ModuleName],@CollectionTimeUtc [CollectionTimeUtc],@StatusCode [StatusCode],@IsPartial [IsPartial],@RowCount [RowCount],@ResolvedSource [ResolvedSource],@ErrorNumber [ErrorNumber],@ErrorMessage [ErrorMessage];
      IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#ExtendedEventsDeadlocks_DeadlockSummary] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId];SELECT * FROM [#ExtendedEventsDeadlocks_Victims] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId],[VictimProcessId];SELECT * FROM [#ExtendedEventsDeadlocks_DeadlockProcesses] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId],[SessionId],[ExecutionContextId];SELECT * FROM [#ExtendedEventsDeadlocks_DeadlockResources] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId],[ResourceType];SELECT * FROM [#ExtendedEventsDeadlocks_SourceStatus] ORDER BY [SourceType];END
      ELSE BEGIN SELECT N'Deadlock' [Ergebnis],[x].* FROM [#ExtendedEventsDeadlocks_DeadlockSummary] [x] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId];SELECT N'Deadlock Victim' [Ergebnis],[x].* FROM [#ExtendedEventsDeadlocks_Victims] [x] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId],[VictimProcessId];SELECT N'Deadlock Prozess' [Ergebnis],[DeadlockId] [Deadlock],[SessionId] [Session],[ExecutionContextId] [ECID],[IsVictim] [Victim],[WaitTimeMs] [Wait ms],[WaitResource] [Wait-Ressource],[LoginName] [Login],[HostName] [Host],[SessionId] [Session SQL],[InputBuffer] [SQL] FROM [#ExtendedEventsDeadlocks_DeadlockProcesses] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId],[SessionId],[ExecutionContextId];SELECT N'Deadlock Ressource' [Ergebnis],[x].* FROM [#ExtendedEventsDeadlocks_DeadlockResources] [x] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId],[ResourceType];SELECT N'Extended-Events Quelle' [Ergebnis],[x].* FROM [#ExtendedEventsDeadlocks_SourceStatus] [x] ORDER BY [SourceType];END;
    END;
    IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'ExtendedEventsDeadlocks' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@RowCount [returnedRows],@ResolvedSource [source],@ErrorNumber [errorNumber],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@D nvarchar(max)=(SELECT [DeadlockId],[SourceType],[DeadlockTimeUtc],[FileName],[FileOffset],[VictimCount],[ProcessCount],[ResourceCount],[FirstDatabaseId],CONVERT(nvarchar(max),[DeadlockXml]) [DeadlockXml] FROM [#ExtendedEventsDeadlocks_DeadlockSummary] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId] FOR JSON PATH,INCLUDE_NULL_VALUES),@V nvarchar(max)=(SELECT * FROM [#ExtendedEventsDeadlocks_Victims] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId],[VictimProcessId] FOR JSON PATH,INCLUDE_NULL_VALUES),@P nvarchar(max)=(SELECT [DeadlockId],[DeadlockTimeUtc],[ProcessId],[IsVictim],[SessionId],[ExecutionContextId],[ProcessStatus],[WaitResource],[WaitTimeMs],[LockMode],[TransactionName],[IsolationLevel],[DatabaseId],[ClientApplication],[HostName],[LoginName],[HostProcessId],[TransactionCount],[LogUsed],[InputBuffer],CONVERT(nvarchar(max),[ProcessXml]) [ProcessXml] FROM [#ExtendedEventsDeadlocks_DeadlockProcesses] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId],[SessionId],[ExecutionContextId] FOR JSON PATH,INCLUDE_NULL_VALUES),@R nvarchar(max)=(SELECT [DeadlockId],[DeadlockTimeUtc],[ResourceType],[DatabaseId],[ObjectId],[IndexId],[AssociatedObjectId],[ResourceId],[ResourceMode],CONVERT(nvarchar(max),[OwnerListXml]) [OwnerListXml],CONVERT(nvarchar(max),[WaiterListXml]) [WaiterListXml],CONVERT(nvarchar(max),[ResourceXml]) [ResourceXml] FROM [#ExtendedEventsDeadlocks_DeadlockResources] ORDER BY [DeadlockTimeUtc] DESC,[DeadlockId],[ResourceType] FOR JSON PATH,INCLUDE_NULL_VALUES),@S nvarchar(max)=(SELECT * FROM [#ExtendedEventsDeadlocks_SourceStatus] ORDER BY [SourceType] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"deadlocks":',COALESCE(@D,N'[]'),N',"victims":',COALESCE(@V,N'[]'),N',"processes":',COALESCE(@P,N'[]'),N',"resources":',COALESCE(@R,N'[]'),N',"sources":',COALESCE(@S,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#ExtendedEventsDeadlocks_DeadlockSummary'
            , @ResultLabel=N'ExtendedEventsDeadlocks'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#ExtendedEventsDeadlocks_DeadlockSummary'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
