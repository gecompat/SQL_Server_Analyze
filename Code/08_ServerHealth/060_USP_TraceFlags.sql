USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_TraceFlags
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Liefert globale und sitzungsbezogene Trace Flags, ohne deren
               Zustand zu ändern.
Datenquellen : DBCC TRACESTATUS
Vertrag      : Resultset 1 ist immer Modulstatus; @ResultSetArt=NONE unterdrückt Resultsets; RAW und CONSOLE liefern unterschiedliche Projektionen. Optional JSON.
===============================================================================
*/

CREATE OR ALTER PROCEDURE [monitor].[USP_TraceFlags]
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
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'traceFlags',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';IF @Hilfe=1 BEGIN PRINT N'monitor.USP_TraceFlags: Server-Health-Snapshot; read-only, nicht atomar.';
        PRINT N'Parameter: @PrintMeldungen bit=1 gibt Meldungen aus (0 unterdrückt sie); @Hilfe bit=0 (0/1) druckt bei 1 diese Hilfe vor den Quellen. Bei TABLE läuft der Ziel-Preflight vorher. @ResultSetArt varchar(16)=CONSOLE: CONSOLE, RAW, TABLE oder NONE; Groß-/Kleinschreibung wird normalisiert.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL ist für TABLE erforderlich; außerhalb von TABLE sind nur NULL oder leere Werte zulässig. Der unten genannte Ergebnisname muss auf eine vorhandene, leere lokale #temp-Tabelle mit genau einer Platzhalterspalte (z.B. Seed bit NULL) zeigen; kein fertiges Ausgabeschema voranlegen.';
        PRINT N'@JsonErzeugen bit=0 (0/1) erzeugt bei 1 das JSON-Dokument in @Json nvarchar(max)=NULL OUTPUT. @StatusCodeOut varchar(40)=NULL liefert den Modulstatus, @IsPartialOut bit=NULL die Teilstatuskennzeichnung, @ErrorNumberOut int=NULL die Quellfehlernummer und @ErrorMessageOut nvarchar(2048)=NULL den Fehlertext; alle sind OUTPUT.';
        PRINT N'Ausgabe: RAW und CONSOLE zeigen traceFlags; TABLE exportiert traceFlags; JSON enthält das traceFlags-Array. JSON-Schlüssel: traceFlags; Modulstatus beschreibt Verfügbarkeit/Fehler.';
        PRINT N'Quelle und Umfang: DBCC TRACESTATUS(-1) liest aktive globale Traceflags sowie Traceflags der aktuellen Verbindung. Sitzungsflags anderer Verbindungen werden nicht abgefragt. Die Statusabfrage verändert keine Flags und besitzt kein Zeilenlimit.';
        PRINT N'Berechtigung: Für DBCC TRACESTATUS genügt unter SQL Server die Rolle public; für den Procedure-Aufruf ist EXECUTE erforderlich. Fehler beim Lesen werden über die Status- und Fehlerausgaben gemeldet.';
        PRINT N'Beispiel: EXEC [monitor].[USP_TraceFlags] @ResultSetArt=''CONSOLE'';';
        PRINT N'TABLE-Beispiel (nur bei Bedarf): CREATE TABLE [#TraceFlags_HelpExample]([Seed] bit NULL); EXEC [monitor].[USP_TraceFlags] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"traceFlags":"#TraceFlags_HelpExample"}''; DROP TABLE [#TraceFlags_HelpExample];';RETURN;END;
 DECLARE @T datetime2(3)=SYSUTCDATETIME(),@S varchar(40)='AVAILABLE',@P bit=0,@E int=NULL,@M nvarchar(2048)=NULL;
 IF @ResultSetArtNormalisiert NOT IN('RAW','CONSOLE','NONE') SELECT @S='INVALID_PARAMETER',@P=1,@M=N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
 CREATE TABLE [#TraceFlags_X]([TraceFlag] int,[Status] int,[GlobalFlag] int,[SessionFlag] int);
 SET LOCK_TIMEOUT 0;BEGIN TRY INSERT [#TraceFlags_X] EXEC(N'DBCC TRACESTATUS(-1) WITH NO_INFOMSGS;');END TRY BEGIN CATCH SELECT @S=CASE WHEN ERROR_NUMBER()IN(229,297,300,371)THEN'DENIED_PERMISSION'ELSE'ERROR_HANDLED'END,@P=1,@E=ERROR_NUMBER(),@M=ERROR_MESSAGE();END CATCH;
 SELECT @StatusCodeOut=@S,@IsPartialOut=@P,@ErrorNumberOut=@E,@ErrorMessageOut=@M;IF @PrintMeldungen=1 AND @S<>'AVAILABLE'RAISERROR(N'USP_TraceFlags: %s',10,1,@M) WITH NOWAIT;
 IF @ResultSetArtNormalisiert<>'NONE' BEGIN SELECT CAST('2.0' AS varchar(16)) [ContractVersion],@T [CollectionTimeUtc],N'monitor.USP_TraceFlags' [ModuleName],@S [StatusCode],@P [IsPartial],@E [ErrorNumber],@M [ErrorMessage];IF @ResultSetArtNormalisiert='RAW' BEGIN SELECT * FROM [#TraceFlags_X] ORDER BY [TraceFlag]; END ELSE BEGIN SELECT N'traceFlags' [Ergebnis],[x].* FROM [#TraceFlags_X] [x] ORDER BY [TraceFlag]; END;END;
 IF @JsonErzeugen=1 BEGIN DECLARE @Meta nvarchar(max)=(SELECT N'TraceFlags' [resultName],1 [schemaVersion],@T [generatedAtUtc],@S [statusCode],@P [isPartial],@E [errorNumber],@M [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),@J0 nvarchar(max)=(SELECT * FROM [#TraceFlags_X] ORDER BY [TraceFlag] FOR JSON PATH,INCLUDE_NULL_VALUES);SET @Json=CONCAT(N'{"meta":',COALESCE(@Meta,N'{}'),N',"traceFlags":',COALESCE(@J0,N'[]'),N',"warnings":[]}');END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#TraceFlags_X'
            , @ResultLabel=N'TraceFlags'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#TraceFlags_X'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
