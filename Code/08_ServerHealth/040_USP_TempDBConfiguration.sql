USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_TempDBConfiguration
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Analysiert TempDB-Dateien, Größenverteilung, Growth und
               Konfiguration. Ein früherer CTE-Laufzeitfehler ist behoben.
Datenquellen : tempdb.sys.database_files, sys.configurations
Vertrag      : Resultset 1 ist immer Modulstatus; @ResultSetArt=NONE unterdrückt Resultsets; RAW und CONSOLE liefern unterschiedliche Projektionen. Optional JSON.
===============================================================================
*/

CREATE OR ALTER PROCEDURE [monitor].[USP_TempDBConfiguration]
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
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'files',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';IF @Hilfe=1 BEGIN PRINT N'monitor.USP_TempDBConfiguration: Server-Health-Snapshot; read-only, nicht atomar.';
        PRINT N'Parameter: @PrintMeldungen bit=1 gibt Meldungen aus (0 unterdrückt sie); @Hilfe bit=0 (0/1) druckt bei 1 diese Hilfe vor den Quellen. Bei TABLE läuft der Ziel-Preflight vorher. @ResultSetArt varchar(16)=CONSOLE: CONSOLE, RAW, TABLE oder NONE; Groß-/Kleinschreibung wird normalisiert.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL ist für TABLE erforderlich; außerhalb von TABLE sind nur NULL oder leere Werte zulässig. Der unten genannte Ergebnisname muss auf eine vorhandene, leere lokale #temp-Tabelle mit genau einer Platzhalterspalte (z.B. Seed bit NULL) zeigen; kein fertiges Ausgabeschema voranlegen.';
        PRINT N'@JsonErzeugen bit=0 (0/1) erzeugt bei 1 das JSON-Dokument in @Json nvarchar(max)=NULL OUTPUT. @StatusCodeOut varchar(40)=NULL liefert den Modulstatus, @IsPartialOut bit=NULL die Teilstatuskennzeichnung, @ErrorNumberOut int=NULL die Quellfehlernummer und @ErrorMessageOut nvarchar(2048)=NULL den Fehlertext; alle sind OUTPUT.';
        PRINT N'Ausgabe: RAW liefert Dateien und Konfiguration; CONSOLE zeigt files; TABLE exportiert nur files; JSON enthält files und configuration. JSON-Schlüssel: files, configuration; Modulstatus beschreibt Verfügbarkeit/Fehler.';
        PRINT N'Quelle und Umfang: TempDB-Dateimetadaten aus tempdb.sys.database_files sowie die drei Werte tempdb metadata memory-optimized, tempdb deferred drop und mixed page allocation aus sys.configurations. Katalogsnapshot ohne Zeilenlimit; keine Nutzungsmessung oder Änderung der TempDB-Konfiguration.';
        PRINT N'Kosten und Grenzen: kleiner Server-/Katalogsnapshot ohne persistente Datenänderung; LOCK_TIMEOUT 0 kann bei Sperren sofort abbrechen. Quellen sind zeitlich nicht atomar; Plattform-/Versionsverfügbarkeit und Berechtigungen können Ergebnisse begrenzen.';
        PRINT N'Beispiel: EXEC [monitor].[USP_TempDBConfiguration] @ResultSetArt=''CONSOLE'';';
        PRINT N'TABLE-Beispiel (nur bei Bedarf): CREATE TABLE [#TempDBConfiguration_HelpExample]([Seed] bit NULL); EXEC [monitor].[USP_TempDBConfiguration] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"files":"#TempDBConfiguration_HelpExample"}''; DROP TABLE [#TempDBConfiguration_HelpExample];';RETURN;END;
 DECLARE @T datetime2(3)=SYSUTCDATETIME(),@S varchar(40)='AVAILABLE',@P bit=0,@E int=NULL,@M nvarchar(2048)=NULL;
 IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') SELECT @S='INVALID_PARAMETER',@P=1,@M=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
 CREATE TABLE [#TempDBConfiguration_F]([file_id] int,[name] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[type_desc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[physical_name] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS,[SizeMb] decimal(19,2),[GrowthValue] decimal(19,2),[GrowthType] varchar(10) COLLATE SQL_Latin1_General_CP1_CS_AS,[max_size] int,[is_percent_growth] bit);
 CREATE TABLE [#TempDBConfiguration_Cfg]([name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[value_in_use] sql_variant);
 SET LOCK_TIMEOUT 0;BEGIN TRY
  INSERT [#TempDBConfiguration_F] SELECT [file_id],[name],[type_desc],[physical_name],CONVERT(decimal(19,2),[size]*8.0/1024),CONVERT(decimal(19,2),CASE WHEN [is_percent_growth]=1 THEN [growth] ELSE [growth]*8.0/1024 END),CASE WHEN [is_percent_growth]=1 THEN'PERCENT'ELSE'MB'END,[max_size],[is_percent_growth] FROM [tempdb].[sys].[database_files] WITH (NOLOCK);
  INSERT [#TempDBConfiguration_Cfg] SELECT [name],[value_in_use] FROM [sys].[configurations] WITH (NOLOCK) WHERE [name] IN('tempdb metadata memory-optimized','tempdb deferred drop','mixed page allocation');
 END TRY BEGIN CATCH SELECT @S=CASE WHEN ERROR_NUMBER()IN(229,297,300,371,916)THEN'DENIED_PERMISSION'WHEN ERROR_NUMBER()=1222 THEN'TIMEOUT'ELSE'ERROR_HANDLED'END,@P=1,@E=ERROR_NUMBER(),@M=ERROR_MESSAGE();END CATCH;
 SELECT @StatusCodeOut=@S,@IsPartialOut=@P,@ErrorNumberOut=@E,@ErrorMessageOut=@M;IF @PrintMeldungen=1 AND @S<>'AVAILABLE'RAISERROR(N'USP_TempDBConfiguration: %s',10,1,@M) WITH NOWAIT;
 IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT CAST('2.0' AS varchar(16)) [ContractVersion],@T [CollectionTimeUtc],N'monitor.USP_TempDBConfiguration' [ModuleName],@S [StatusCode],@P [IsPartial],@E [ErrorNumber],@M [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#TempDBConfiguration_F] ORDER BY [file_id];SELECT * FROM [#TempDBConfiguration_Cfg] ORDER BY [name]; END ELSE BEGIN SELECT N'files' [Ergebnis],[x].* FROM [#TempDBConfiguration_F] [x] ORDER BY [file_id];SELECT N'configuration' [Ergebnis],[x].* FROM [#TempDBConfiguration_Cfg] [x] ORDER BY [name]; END;END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'TempDBConfiguration' [resultName],1 [schemaVersion],@T [generatedAtUtc],@S [statusCode],@P [isPartial],@E [errorNumber],@M [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@J0 nvarchar(max)=(SELECT * FROM [#TempDBConfiguration_F] ORDER BY [file_id] FOR JSON PATH,INCLUDE_NULL_VALUES),@J1 nvarchar(max)=(SELECT [name],CONVERT(nvarchar(4000),[value_in_use]) [value_in_use] FROM [#TempDBConfiguration_Cfg] ORDER BY [name] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"files":',COALESCE(@J0,N'[]'),N',"configuration":',COALESCE(@J1,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#TempDBConfiguration_F'
            , @ResultLabel=N'TempDBConfiguration'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#TempDBConfiguration_F'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
