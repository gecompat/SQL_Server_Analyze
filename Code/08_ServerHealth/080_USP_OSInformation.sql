USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_OSInformation
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liest Host-, Betriebssystem-Speicher-, SQL-Prozess-
               und Dienstdaten; jede optionale Quelle hat eine eigene Fehlergrenze.
Datenquellen : sys.dm_os_host_info, sys.dm_os_sys_memory, sys.dm_os_process_memory, sys.dm_server_services
Vertrag      : Resultset 1 ist immer Modulstatus; @ResultSetArt=NONE unterdrückt Resultsets; RAW und CONSOLE liefern unterschiedliche Projektionen. Optional JSON.
===============================================================================
*/

CREATE OR ALTER PROCEDURE [monitor].[USP_OSInformation]
 @PrintMeldungen bit=1,@Hilfe bit=0,@ResultSetArt varchar(16)='CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,
 @StatusCodeOut varchar(40)=NULL OUTPUT,@IsPartialOut bit=NULL OUTPUT,@ErrorNumberOut int=NULL OUTPUT,@ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON;SET @Json=NULL;DECLARE @ResultSetArtNormalisiert varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'host',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @MonitorPrintMessage nvarchar(2048);IF @Hilfe=1
 BEGIN
        PRINT N'monitor.USP_OSInformation';
        PRINT N'Erfasst Hostidentität, Betriebssystemspeicher, SQL-Prozessspeicher und SQL-Dienstdetails aus vier unabhängigen Quellen.';
        PRINT N'Die Hilfe läuft nach einem eventuellen TABLE-Preflight und vor Quellabfragen. Teilfehler bleiben pro Quelle sichtbar.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 gibt nach der Quellenprüfung bei einem Status ungleich AVAILABLE eine Statusmeldung aus; 0 unterdrückt sie. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1, da nur der Vergleich mit 1 die Ausgabe auslöst.';
        PRINT N'@Hilfe bit; Default: 0. 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei ResultSetArt TABLE wird der Ziel-Preflight vor der Hilfe ausgeführt.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Bindung an varchar(16): CONSOLE gibt ausschließlich host unter dem Label OSInformation aus; bei leerer host-Tabelle liefert der Helfer eine Leerzeile; die weiteren Quellresultate stehen in RAW beziehungsweise JSON; RAW liefert technische Resultsets; TABLE exportiert nur host; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden für reguläre Resultsets zu NONE und separat ausgegeben. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ist ein JSON-Objekt mit dem einzelnen Resultatnamen host erforderlich, abgebildet auf eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte. Permanente und globale ##-Tabellen, nichtleere Ziele und Ziele mit fertigem Ausgabeschema werden vom Preflight zurückgewiesen; er läuft vor der Hilfe und Fehler lösen 51011 aus. Außerhalb von TABLE sind NULL, Leertext oder Leerzeichen erlaubt; sonst wird 51011 ausgelöst.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erstellt JSON mit meta, sources, host, systemMemory, processMemory, services und warnings als leerem Array; 0 bzw. NULL unterdrückt die Erstellung; numerische 0 bleibt 0 und von 0 verschiedene konvertierbare Zahlen werden bit 1. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. AVAILABLE bei vier verfügbaren Quellen; PARTIAL bei mindestens einer verfügbaren und einer fehlgeschlagenen Quelle; INVALID_PARAMETER für ungültige ResultSetArt; bei Gesamtausfall DENIED_PERMISSION für Fehler 229/297/300/371, sonst ERROR_HANDLED. Zuweisung nach Quellversuchen, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, sonst 1 sobald eine Quelle ausfällt oder ResultSetArt ungültig ist. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer des ersten Fehlers aus einer fehlgeschlagenen Quelle; die Auswahl ist ohne explizite Sortierung, sonst NULL; im Hilfezweig keine Zuweisung.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Meldung der ersten fehlgeschlagenen Quelle oder Validierungstext, sonst NULL; im Hilfezweig keine Zuweisung.';
        PRINT N'EXEC [monitor].[USP_OSInformation] @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @j nvarchar(max); EXEC [monitor].[USP_OSInformation] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;';
        PRINT N'CREATE TABLE [#OSInformation_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_OSInformation] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"host":"#OSInformation_HelpExample"}''; END TRY BEGIN CATCH DROP TABLE [#OSInformation_HelpExample]; THROW; END CATCH; DROP TABLE [#OSInformation_HelpExample];';
        PRINT N'EXEC [monitor].[USP_OSInformation] @Hilfe=1;';










        RETURN;
 END;
 DECLARE @T datetime2(3)=SYSUTCDATETIME(),@S varchar(40)='AVAILABLE',@P bit=0,@E int=NULL,@M nvarchar(2048)=NULL;
 IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') SELECT @S='INVALID_PARAMETER',@P=1,@M=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
 CREATE TABLE [#OSInformation_Src]([SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 CREATE TABLE [#OSInformation_H]([host_platform] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[host_distribution] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[host_release] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[host_service_pack_level] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[host_sku] int,[os_language_version] int);
 CREATE TABLE [#OSInformation_SM]([total_physical_memory_kb] bigint,[available_physical_memory_kb] bigint,[total_page_file_kb] bigint,[available_page_file_kb] bigint,[system_memory_state_desc] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS);
 CREATE TABLE [#OSInformation_PM]([physical_memory_in_use_kb] bigint,[locked_page_allocations_kb] bigint,[large_page_allocations_kb] bigint,[process_physical_memory_low] bit,[process_virtual_memory_low] bit);
 CREATE TABLE [#OSInformation_Svc]([servicename] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[startup_type_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[status_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[process_id] int,[last_startup_time] datetime2 NULL,[service_account] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS,[instant_file_initialization_enabled] nvarchar(10) COLLATE SQL_Latin1_General_CP1_CS_AS);
 SET LOCK_TIMEOUT 0;
 BEGIN TRY INSERT [#OSInformation_H] SELECT [host_platform],[host_distribution],[host_release],[host_service_pack_level],[host_sku],[os_language_version] FROM [sys].[dm_os_host_info] WITH (NOLOCK);INSERT [#OSInformation_Src] VALUES(N'sys.dm_os_host_info','AVAILABLE',NULL,NULL);END TRY BEGIN CATCH INSERT [#OSInformation_Src] VALUES(N'sys.dm_os_host_info',CASE WHEN ERROR_NUMBER()IN(229,297,300,371)THEN'DENIED_PERMISSION'ELSE'ERROR_HANDLED'END,ERROR_NUMBER(),ERROR_MESSAGE());END CATCH;
 BEGIN TRY INSERT [#OSInformation_SM] SELECT [total_physical_memory_kb],[available_physical_memory_kb],[total_page_file_kb],[available_page_file_kb],[system_memory_state_desc] FROM [sys].[dm_os_sys_memory] WITH (NOLOCK);INSERT [#OSInformation_Src] VALUES(N'sys.dm_os_sys_memory','AVAILABLE',NULL,NULL);END TRY BEGIN CATCH INSERT [#OSInformation_Src] VALUES(N'sys.dm_os_sys_memory',CASE WHEN ERROR_NUMBER()IN(229,297,300,371)THEN'DENIED_PERMISSION'ELSE'ERROR_HANDLED'END,ERROR_NUMBER(),ERROR_MESSAGE());END CATCH;
 BEGIN TRY INSERT [#OSInformation_PM] SELECT [physical_memory_in_use_kb],[locked_page_allocations_kb],[large_page_allocations_kb],[process_physical_memory_low],[process_virtual_memory_low] FROM [sys].[dm_os_process_memory] WITH (NOLOCK);INSERT [#OSInformation_Src] VALUES(N'sys.dm_os_process_memory','AVAILABLE',NULL,NULL);END TRY BEGIN CATCH INSERT [#OSInformation_Src] VALUES(N'sys.dm_os_process_memory',CASE WHEN ERROR_NUMBER()IN(229,297,300,371)THEN'DENIED_PERMISSION'ELSE'ERROR_HANDLED'END,ERROR_NUMBER(),ERROR_MESSAGE());END CATCH;
 BEGIN TRY INSERT [#OSInformation_Svc] SELECT [servicename],[startup_type_desc],[status_desc],[process_id],[last_startup_time],[service_account],CONVERT(nvarchar(10),[instant_file_initialization_enabled])FROM [sys].[dm_server_services] WITH (NOLOCK);INSERT [#OSInformation_Src] VALUES(N'sys.dm_server_services','AVAILABLE',NULL,NULL);END TRY BEGIN CATCH INSERT [#OSInformation_Src] VALUES(N'sys.dm_server_services',CASE WHEN ERROR_NUMBER()IN(229,297,300,371)THEN'DENIED_PERMISSION'ELSE'ERROR_HANDLED'END,ERROR_NUMBER(),ERROR_MESSAGE());END CATCH;

 IF EXISTS(SELECT 1 FROM [#OSInformation_Src] WHERE [StatusCode]<>'AVAILABLE') SELECT @P=1,@S=CASE WHEN EXISTS(SELECT 1 FROM [#OSInformation_Src] WHERE [StatusCode]='AVAILABLE')THEN'PARTIAL'ELSE(SELECT TOP(1)[StatusCode] FROM [#OSInformation_Src] WHERE [StatusCode]<>'AVAILABLE')END,@E=(SELECT TOP(1)[ErrorNumber] FROM [#OSInformation_Src] WHERE [StatusCode]<>'AVAILABLE'),@M=(SELECT TOP(1)[ErrorMessage] FROM [#OSInformation_Src] WHERE [StatusCode]<>'AVAILABLE');
 SELECT @StatusCodeOut=@S,@IsPartialOut=@P,@ErrorNumberOut=@E,@ErrorMessageOut=@M;IF @PrintMeldungen=1 AND @S<>'AVAILABLE'BEGIN
    SET @MonitorPrintMessage = FORMATMESSAGE(N'USP_OSInformation: %s', COALESCE(@M,N'eine Quelle nicht verfügbar'));
    RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
END;
 IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT CAST('2.0' AS varchar(16)) [ContractVersion],@T [CollectionTimeUtc],N'monitor.USP_OSInformation' [ModuleName],@S [StatusCode],@P [IsPartial],@E [ErrorNumber],@M [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#OSInformation_Src] ORDER BY [SourceName];SELECT * FROM [#OSInformation_H] ;SELECT * FROM [#OSInformation_SM] ;SELECT * FROM [#OSInformation_PM] ;SELECT * FROM [#OSInformation_Svc] ORDER BY [servicename]; END ELSE BEGIN SELECT N'sources' [Ergebnis],[x].* FROM [#OSInformation_Src] [x] ORDER BY [SourceName];SELECT N'host' [Ergebnis],[x].* FROM [#OSInformation_H] [x] ;SELECT N'systemMemory' [Ergebnis],[x].* FROM [#OSInformation_SM] [x] ;SELECT N'processMemory' [Ergebnis],[x].* FROM [#OSInformation_PM] [x] ;SELECT N'services' [Ergebnis],[x].* FROM [#OSInformation_Svc] [x] ORDER BY [servicename]; END;END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'OSInformation' [resultName],1 [schemaVersion],@T [generatedAtUtc],@S [statusCode],@P [isPartial],@E [errorNumber],@M [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@J0 nvarchar(max)=(SELECT * FROM [#OSInformation_Src] ORDER BY [SourceName] FOR JSON PATH,INCLUDE_NULL_VALUES),@J1 nvarchar(max)=(SELECT * FROM [#OSInformation_H]  FOR JSON PATH,INCLUDE_NULL_VALUES),@J2 nvarchar(max)=(SELECT * FROM [#OSInformation_SM]  FOR JSON PATH,INCLUDE_NULL_VALUES),@J3 nvarchar(max)=(SELECT * FROM [#OSInformation_PM]  FOR JSON PATH,INCLUDE_NULL_VALUES),@J4 nvarchar(max)=(SELECT * FROM [#OSInformation_Svc] ORDER BY [servicename] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"sources":',COALESCE(@J0,N'[]'),N',"host":',COALESCE(@J1,N'[]'),N',"systemMemory":',COALESCE(@J2,N'[]'),N',"processMemory":',COALESCE(@J3,N'[]'),N',"services":',COALESCE(@J4,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#OSInformation_H'
            , @ResultLabel=N'OSInformation'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#OSInformation_H'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
