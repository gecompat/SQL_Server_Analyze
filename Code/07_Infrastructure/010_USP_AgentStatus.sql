USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_AgentStatus
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_server_services, msdb.dbo.syssessions, msdb.dbo.sysjobs
Parameter    : @ResultSetArt, @ResultTablesJson, @JsonErzeugen, @Json OUTPUT,
               @PrintMeldungen, @Hilfe
Resultsets   : RAW: Modulstatus und Agentstatus. CONSOLE/TABLE: Agentstatus.
               NONE: keine Resultsets.
JSON         : meta, agentStatus.
Berechtigung : Nur lesender Zugriff. Das Framework vergibt keine Rechte.
Eigenlast    : Gering.
Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
Änderungen   : 2.0.0 - Einheitlicher RAW/CONSOLE/NONE- und JSON-Vertrag.
               1.0.0 - Erstfassung Phase 6.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_AgentStatus]
      @ResultSetArt   varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen   bit            = 0
    , @Json           nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen bit            = 1
    , @Hilfe          bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'agentStatus',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_AgentStatus';
        PRINT N'Ermittelt den sichtbaren Agentdienstsnapshot, den letzten in msdb sichtbaren Agentstart und aggregierte Jobzahlen.';
        PRINT N'Die Hilfe wird mit PRINT ausgegeben. Prüfung der ResultTables-Kombination und TABLE-Zielpreflight liegen davor; der Hilferücksprung erfolgt vor dem Zugriff auf Agentdaten.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. NULL wird zu leerem Text; äußere Leerzeichen werden entfernt und der Vergleich erfolgt ohne Beachtung der Groß-/Kleinschreibung. CONSOLE liefert eine beschriftete Console-Ausgabe, RAW den Modulstatus und die Rohzeile, TABLE exportiert agentStatus in das zugeordnete Ziel, NONE unterdrückt Resultsets. CONSOLE und TABLE unterdrücken zuerst direkte Resultsets und rufen anschließend ihren Ausgabeadapter auf. Andere Werte werden nach dem Hilferücksprung als INVALID_PARAMETER gemeldet. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL, leerer Text und nur aus Leerzeichen bestehender Text werden außerhalb von TABLE ignoriert. Ein nichtleerer Wert ist nur mit ResultSetArt=TABLE zulässig; andernfalls wird vor der Hilfe Fehler 51011 ausgelöst. TABLE erwartet die JSON-Objektform {"agentStatus":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel, ein String mit dem lokalen Zielnamen als Wert und keine weiteren Eigenschaften. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##-Tabellen, #Monitor-Namen und Namen über 116 Zeichen sind unzulässig. Eine fehlende oder fehlerhafte Zuordnung sowie ein ungeeignetes Ziel lösen beim Preflight vor der Hilfe Fehler 51011 aus. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. 0 oder NULL deaktiviert JSON; bei 1 wird @Json OUTPUT mit meta und agentStatus einschließlich NULL-Werten und einem leeren Array befüllt. SQL Server konvertiert das Argument vor Eintritt in den Prozedurcode zu bit: 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Die Procedure setzt sie zu Beginn auf NULL und befüllt sie nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. Bei 1 wird nach einem abgefangenen Lesefehler eine Meldung mit Severity 10 und NOWAIT ausgegeben; 0 und NULL unterdrücken sie. SQL Server konvertiert das Argument vor Eintritt zu bit; Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. 0 führt die normale Analyse aus. Bei 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt vor der Agentdatensammlung zurück; sie startet, stoppt oder konfiguriert den Dienst nicht. NULL wirkt wie 0. SQL Server konvertiert das Argument vor Eintritt zu bit. Die Prüfung der ResultTables-Kombination und der TABLE-Zieltabellen-Preflight liegen vor dem Hilfezweig und können auch dabei Fehler 51011 auslösen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_AgentStatus] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'Beispiel 3: DECLARE @AgentStatusJson nvarchar(max); EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@AgentStatusJson OUTPUT, @PrintMeldungen=0; SELECT @AgentStatusJson AS [Json];';
        PRINT N'Beispiel 4: CREATE TABLE #AgentStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentStatus] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"agentStatus":"#AgentStatus_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM #AgentStatus_HelpExample; DROP TABLE #AgentStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentStatus_HelpExample; THROW; END CATCH;';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;

    CREATE TABLE [#AgentStatus_AgentStatus]
    (
          [ServiceName]        nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StartupTypeDesc]    nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL
        , [StatusDesc]         nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS  NULL
        , [ProcessId]          int           NULL
        , [LastStartupTime]    datetime2(3)  NULL
        , [AgentSessionId]     int           NULL
        , [JobCount]           int           NULL
        , [EnabledJobCount]    int           NULL
    );

    IF @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @IsPartial = 1;
        SET @ErrorMessage = N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#AgentStatus_AgentStatus]
        (
              [ServiceName], [StartupTypeDesc], [StatusDesc], [ProcessId]
            , [LastStartupTime], [AgentSessionId], [JobCount], [EnabledJobCount]
        )
        SELECT TOP (1)
              [s].[servicename]
            , [s].[startup_type_desc]
            , [s].[status_desc]
            , [s].[process_id]
            , (SELECT MAX([agent_start_date]) FROM [msdb].[dbo].[syssessions] WITH (NOLOCK))
            , (SELECT MAX([session_id]) FROM [msdb].[dbo].[syssessions] WITH (NOLOCK))
            , (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs] WITH (NOLOCK))
            , (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs] WITH (NOLOCK) WHERE [enabled] = 1)
        FROM [sys].[dm_server_services] AS [s] WITH (NOLOCK)
        WHERE [s].[servicename] LIKE N'SQL Server Agent%'
        ORDER BY [s].[servicename];

        IF NOT EXISTS (SELECT 1 FROM [#AgentStatus_AgentStatus])
        BEGIN
            SET @StatusCode = 'UNAVAILABLE_FEATURE';
            SET @IsPartial = 1;
            SET @ErrorMessage = N'Kein sichtbarer SQL-Server-Agent-Dienst gefunden.';
        END;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = 'ERROR_HANDLED'
            , @IsPartial = 1
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = ERROR_MESSAGE();

        IF @PrintMeldungen = 1
            RAISERROR(N'Agentstatus konnte nicht vollständig gelesen werden: %s', 10, 1, @ErrorMessage) WITH NOWAIT;
    END CATCH;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              @CollectionTimeUtc AS [CollectionTimeUtc]
            , CAST(N'monitor.USP_AgentStatus' AS nvarchar(256)) AS [ModuleName]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT
                  [ServiceName], [StartupTypeDesc], [StatusDesc], [ProcessId]
                , [LastStartupTime], [AgentSessionId], [JobCount], [EnabledJobCount]
            FROM [#AgentStatus_AgentStatus];
        END;
        ELSE
        BEGIN
            SELECT
                  N'SQL Server Agent' AS [Ergebnis]
                , [ServiceName] AS [Dienst]
                , [StartupTypeDesc] AS [Starttyp]
                , [StatusDesc] AS [Dienststatus]
                , [ProcessId] AS [Prozess-ID]
                , [LastStartupTime] AS [Letzter Agent-Start]
                , [AgentSessionId] AS [Agent-Session]
                , [JobCount] AS [Jobs gesamt]
                , [EnabledJobCount] AS [Aktive Jobs]
            FROM [#AgentStatus_AgentStatus];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'AgentStatus' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

        DECLARE @DataJson nvarchar(max) =
        (
            SELECT
                  [ServiceName], [StartupTypeDesc], [StatusDesc], [ProcessId]
                , [LastStartupTime], [AgentSessionId], [JobCount], [EnabledJobCount]
            FROM [#AgentStatus_AgentStatus]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"agentStatus":', COALESCE(@DataJson, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#AgentStatus_AgentStatus'
            , @ResultLabel=N'AgentStatus'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#AgentStatus_AgentStatus'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
