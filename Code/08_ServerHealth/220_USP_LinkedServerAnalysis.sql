USE [DeineDatenbank];
GO

/* OPS-005: local inventory by default; connectivity is explicit double opt-in. */
CREATE OR ALTER PROCEDURE [monitor].[USP_LinkedServerAnalysis]
      @ConnectivityTestEnabled bit            = 0
    , @HighImpactConfirmed     bit            = 0
    , @MaxZeilen               int            = 2000
    , @ResultSetArt            varchar(16)    = 'CONSOLE'
    , @ResultTablesJson        nvarchar(max)  = NULL
    , @JsonErzeugen            bit            = 0
    , @Json                    nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen          bit            = 1
    , @Hilfe                   bit            = 0
    , @StatusCodeOut           varchar(40)    = NULL OUTPUT
    , @IsPartialOut            bit            = NULL OUTPUT
    , @ErrorNumberOut          int            = NULL OUTPUT
    , @ErrorMessageOut         nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @Json=NULL;
    DECLARE @Status varchar(40)='AVAILABLE',@Partial bit=0,@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@ServerStatusCode varchar(40)=N'SOURCE_UNAVAILABLE';
    IF @Hilfe=1 BEGIN
        PRINT N'monitor.USP_LinkedServerAnalysis inventarisiert lokal registrierte Linked Server und zeigt kumulative OLEDB-/REMOTE-Waits. Standardmäßig wird keine Remoteverbindung aufgebaut. sp_testlinkedserver läuft je sichtbarem Linked Server nur mit beiden ausdrücklichen Opt-ins @ConnectivityTestEnabled=1 und @HighImpactConfirmed=1.';
        PRINT N'Der Test belegt nur den Verbindungsaufbau zum Testzeitpunkt, keine Remoteobjektberechtigung, Abfragelaufzeit oder fachliche Erreichbarkeit. Waitwerte sind kumulativ und keiner Registrierung zugeordnet. @MaxZeilen begrenzt die Inventarzeilen in CONSOLE, RAW, TABLE und JSON auf dieselbe Mitgliedschaft. Die positive Grenze wählt deterministisch nach ServerName; RAW und JSON geben diese Zeilen sortiert aus, CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. RAW enthält zusätzlich Waitwerte. Status und Remote-Tests beziehen sich weiterhin auf das vollständige Inventar.';
        PRINT N'@ConnectivityTestEnabled bit=0 und @HighImpactConfirmed bit=0 (je 0/1); beide müssen 1 sein, um Tests zu starten. @MaxZeilen int=2000: NULL und 0 sind unbegrenzt, positive Werte begrenzen CONSOLE, RAW, TABLE und JSON auf dieselben Inventarzeilen; negative Werte setzen INVALID_PARAMETER und liefern keine Inventarzeilen. @ResultSetArt varchar(16)=CONSOLE: CONSOLE, RAW, TABLE oder NONE; Steuerwert ohne Beachtung der Groß-/Kleinschreibung.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL: nur TABLE, Schlüssel linkedServers; Ziel vorhandene leere lokale #Temp-Tabelle mit genau einer Platzhalterspalte. @JsonErzeugen bit=0 (0/1); @Json nvarchar(max)=NULL OUTPUT erhält dasselbe gegebenenfalls begrenzte Inventararray wie die Zeilenausgaben. @PrintMeldungen bit=1 und @Hilfe bit=0 (je 0/1); Hilfe zeigt diesen Text und beendet den Aufruf.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT, @IsPartialOut bit=NULL OUTPUT, @ErrorNumberOut int=NULL OUTPUT und @ErrorMessageOut nvarchar(2048)=NULL OUTPUT sind optionale technische Ausgaben; NULL-Defaults erlauben Auslassung. Bei fehlgeschlagenem Remote-Test kann ErrorMessage technische Fehlerdetails enthalten.';
        PRINT N'CONSOLE-Beispiel, lokales Inventar ohne Remotezugriff:';
        PRINT N'EXEC [monitor].[USP_LinkedServerAnalysis] @ConnectivityTestEnabled=0, @ResultSetArt=''CONSOLE'';';
        PRINT N'TABLE-Beispiel; Ziel vorher leer anlegen, modulpräfixierter eindeutiger Name bis 116 Zeichen:';
        PRINT N'CREATE TABLE [#LinkedServerAnalysis_Help_Result] ([Placeholder] int NULL);';
        PRINT N'EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"linkedServers":"#LinkedServerAnalysis_Help_Result"}'';';
        RETURN;
    END;
    DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
    SET LOCK_TIMEOUT 0;
    DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'linkedServers',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; END;
    IF @TableResultRequested=1 OR @ConsoleResultRequested=1 SET @Mode='NONE';
    CREATE TABLE [#LinkedServerAnalysis_Linked]
    (
      [ServerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Product] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Provider] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
      [IsDataAccessEnabled] bit NULL,[IsRpcOutEnabled] bit NULL,[IsCollationCompatible] bit NULL,
      [ConnectivityStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    IF @MaxZeilen<0 OR @Mode NOT IN('CONSOLE','RAW','NONE') OR @ConnectivityTestEnabled IS NULL OR @HighImpactConfirmed IS NULL
      SELECT @Status='INVALID_PARAMETER',@Partial=1,@ErrorMessage=N'Ungültiger Parameter.';
    IF @Status='AVAILABLE'
    BEGIN
      INSERT [#LinkedServerAnalysis_Linked]
      SELECT [name],[product],[provider],[is_data_access_enabled],[is_rpc_out_enabled],[is_collation_compatible],
             CASE WHEN @ConnectivityTestEnabled=0 THEN 'NOT_EXECUTED' WHEN @HighImpactConfirmed=0 THEN 'AUTHORIZATION_REQUIRED' ELSE 'PENDING' END,
             'AVAILABLE',N'Endpunkt und Datenquelle werden nicht ausgegeben; Erreichbarkeit ist ohne opt-in unbekannt.'
      FROM [sys].[servers] WITH (NOLOCK) WHERE [is_linked]=1;
      IF @ConnectivityTestEnabled=1 AND @HighImpactConfirmed=0 SELECT @Status='AUTHORIZATION_REQUIRED',@Partial=1,@ErrorMessage=N'Remotezugriff benötigt @HighImpactConfirmed=1.';
      IF @ConnectivityTestEnabled=1 AND @HighImpactConfirmed=1
      BEGIN
        DECLARE @Server sysname;
        DECLARE [s] CURSOR LOCAL FAST_FORWARD FOR SELECT [ServerName] FROM [#LinkedServerAnalysis_Linked];
        OPEN [s]; FETCH NEXT FROM [s] INTO @Server;
        WHILE @@FETCH_STATUS=0 BEGIN
          BEGIN TRY
            EXEC [master].[dbo].[sp_testlinkedserver] @servername=@Server;
            UPDATE [#LinkedServerAnalysis_Linked]
               SET [ConnectivityStatus]='SUCCEEDED'
             WHERE [ServerName]=@Server COLLATE SQL_Latin1_General_CP1_CS_AS;
          END TRY
          BEGIN CATCH
            SET @ErrorNumber=ERROR_NUMBER();
            SET @ErrorMessage=ERROR_MESSAGE();
            IF @ErrorNumber=229
                SET @ServerStatusCode=N'DENIED_PERMISSION';
            ELSE IF @ErrorNumber IN(-2,1222) OR @ErrorMessage LIKE N'%Timeout%' OR @ErrorMessage LIKE N'%timeout%'
                SET @ServerStatusCode=N'SOURCE_TIMEOUT';
            ELSE
                SET @ServerStatusCode=N'SOURCE_UNAVAILABLE';
            UPDATE [#LinkedServerAnalysis_Linked]
               SET [ConnectivityStatus]='FAILED',[StatusCode]=@ServerStatusCode,[EvidenceLimit]=CONCAT(N'Remote-Testfehler ',@ErrorNumber,N': ',LEFT(@ErrorMessage,800))
             WHERE [ServerName]=@Server COLLATE SQL_Latin1_General_CP1_CS_AS;
            SET @Partial=1;
          END CATCH;
          FETCH NEXT FROM [s] INTO @Server;
        END; CLOSE [s]; DEALLOCATE [s];
      END;
      IF NOT EXISTS(SELECT 1 FROM [#LinkedServerAnalysis_Linked]) SET @Status='AVAILABLE_EMPTY'; ELSE IF @Partial=1 AND @Status='AVAILABLE' SET @Status='AVAILABLE_LIMITED';
    END;
    CREATE TABLE [#LinkedServerAnalysis_LimitedRows] ([ServerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Product] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Provider] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsDataAccessEnabled] bit NULL,[IsRpcOutEnabled] bit NULL,[IsCollationCompatible] bit NULL,[ConnectivityStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    INSERT [#LinkedServerAnalysis_LimitedRows]
    SELECT TOP(CASE WHEN @MaxZeilen<0 OR COALESCE(@MaxZeilen,0)=0 THEN 2147483647 ELSE @MaxZeilen END) * FROM [#LinkedServerAnalysis_Linked] ORDER BY [ServerName];
    IF @JsonErzeugen=1 SELECT @Json=COALESCE((SELECT * FROM [#LinkedServerAnalysis_LimitedRows] ORDER BY [ServerName] FOR JSON PATH),N'[]');
    IF @Mode IN('CONSOLE','RAW') BEGIN SELECT @Status [StatusCode],@Partial [IsPartial],COUNT_BIG(*) [LinkedServerCount],@ErrorMessage [ErrorMessage] FROM [#LinkedServerAnalysis_Linked]; SELECT * FROM [#LinkedServerAnalysis_LimitedRows] ORDER BY [ServerName]; SELECT [wait_type],[waiting_tasks_count],[wait_time_ms] FROM [sys].[dm_os_wait_stats] WITH (NOLOCK) WHERE [wait_type] LIKE 'OLEDB%' OR [wait_type] LIKE 'REMOTE%' ORDER BY [wait_time_ms] DESC; END;
    IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
    IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#LinkedServerAnalysis_LimitedRows',@ResultLabel=N'linkedServers',@EmptyMessage=N'Keine verknüpften Server im sichtbaren Scope';
    IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#LinkedServerAnalysis_LimitedRows',@TargetTable=@TableTarget,@ThrowOnError=1;
    SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
END;
GO
