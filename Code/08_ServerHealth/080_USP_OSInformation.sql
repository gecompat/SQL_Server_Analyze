USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_OSInformation
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Liefert Host-, Speicher-, Prozess- und Dienstinformationen. Jede
               optionale Quelle besitzt eine eigene Fehlergrenze.
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
        PRINT N'monitor.USP_OSInformation: Erfasst lesend Hostidentität, Betriebssystemspeicher, SQL-Prozessspeicher und SQL-Dienstdetails; jede Quelle meldet ihren Status unabhängig.';
        PRINT N'@PrintMeldungen bit=1: Gibt Informationsmeldungen für teilweise oder nicht verfügbare Quellen aus (1) oder unterdrückt sie (0).';
        PRINT N'@Hilfe bit=0: Gibt diese Hilfe aus (1) oder erhebt Daten (0). Die Hilfe wird vor der Erhebung ausgegeben; bei TABLE wird zuvor das Tabellenziel geprüft. Für die Hilfe den Standardaufruf verwenden.';
        PRINT N'@ResultSetArt varchar(16)=CONSOLE: CONSOLE, RAW, TABLE oder NONE. CONSOLE ist für die interaktive Ausgabe; RAW liefert technische Resultsets; TABLE schreibt nur das benannte Resultat host; NONE unterdrückt Resultsets.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL: Für TABLE erforderlich; ordnet den einzelnen Resultatnamen host einer bereits vorhandenen, leeren lokalen #temp-Tabelle mit genau einer Seed-Spalte zu. Permanente oder globale ##-Tabellen, nichtleere Tabellen und Ziele mit bereits festgelegtem Ausgabeschema werden abgewiesen.';
        PRINT N'@JsonErzeugen bit=0: Erzeugt zusätzlich JSON (1) oder nicht (0). @Json nvarchar(max)=NULL OUTPUT nimmt es entgegen.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT und @IsPartialOut bit=NULL OUTPUT: Gesamtstatus der Quellen und Kennzeichen für Teilergebnisse. @ErrorNumberOut int=NULL OUTPUT und @ErrorMessageOut nvarchar(2048)=NULL OUTPUT: erster verfügbarer Quellenfehler.';
        PRINT N'Berechtigungen und Grenzen: Liest sys.dm_os_host_info, sys.dm_os_sys_memory, sys.dm_os_process_memory und sys.dm_server_services. Vier unabhängige kurze Lesezugriffe; fehlende Plattformobjekte oder DMV-Berechtigungen können zu Teilergebnissen führen. Kein Datenbankbereich und kein Zeilenlimit.';
        PRINT N'Dienstkonten und Prozessdetails sind betriebliche sensible Angaben und nur mit berechtigten Empfängern zu teilen. Die Hostausgabe bildet weder die vollständige Betriebssystem- noch Hypervisor-Telemetrie ab.';
        PRINT N'Beispiele (synthetisch): EXEC [monitor].[USP_OSInformation] @Hilfe=1;  EXEC [monitor].[USP_OSInformation] @ResultSetArt=''CONSOLE'';';
        PRINT N'TABLE-Beispiel (synthetisch): CREATE TABLE #OSInformation_HelpExample(Seed bit NULL); EXEC [monitor].[USP_OSInformation] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"host":"#OSInformation_HelpExample"}''; DROP TABLE #OSInformation_HelpExample;';
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
