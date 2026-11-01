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
        PRINT N'monitor.USP_LinkedServerAnalysis';
        PRINT N'inventarisiert lokal registrierte Linked Server und zeigt kumulative OLEDB-/REMOTE-Waits. Standardmäßig wird keine Remoteverbindung aufgebaut. sp_testlinkedserver läuft je sichtbarem Linked Server nur mit beiden ausdrücklichen Opt-ins @ConnectivityTestEnabled=1 und @HighImpactConfirmed=1.';
        PRINT N'Der Test belegt nur den Verbindungsaufbau zum Testzeitpunkt, keine Remoteobjektberechtigung, Abfragelaufzeit oder fachliche Erreichbarkeit. Waitwerte sind kumulativ und keiner Registrierung zugeordnet. @MaxZeilen begrenzt die Inventarzeilen in CONSOLE, RAW, TABLE und JSON auf dieselbe Mitgliedschaft. Die positive Grenze wählt deterministisch nach ServerName; RAW und JSON geben diese Zeilen sortiert aus, CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. RAW enthält zusätzlich Waitwerte. Status und Remote-Tests beziehen sich weiterhin auf das vollständige Inventar.';
        PRINT N'@ConnectivityTestEnabled bit; Default: 0. 0 führt keinen Remote-Test aus; 1 fordert ihn an und startet ihn nur gemeinsam mit @HighImpactConfirmed=1. NULL ist ungültig und ergibt INVALID_PARAMETER. sp_testlinkedserver läuft für jeden inventarisierten Linked Server. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. 0 bestätigt den Remotezugriff nicht; 1 bestätigt ihn. NULL ist ungültig. Tests starten nur bei @ConnectivityTestEnabled=1 und diesem Schalter=1. Bei aktivem Test und fehlender Bestätigung lautet der Status AUTHORIZATION_REQUIRED; allein aktiviert dieser Schalter keinen Test. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@MaxZeilen int; Default: 2000. NULL wird zu 0; 0 bedeutet unbegrenzt. Positive Werte wählen nach ServerName sortierte Inventarzeilen für RAW/CONSOLE/TABLE/JSON. Inventarisierung und Remoteprüfungen laufen vollständig vor Begrenzung; Status und LinkedServerCount beziehen sich auf alle Server. Negative Werte ergeben INVALID_PARAMETER und keine begrenzten Zeilen.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Wählt CONSOLE für die beschriftete Linked-Server-Ansicht, RAW für Status, Inventarzeilen und zusätzliche kumulative Waitwerte, TABLE für die benannte Tabellenausgabe oder NONE ohne reguläre Resultsets. Äußere U+0020-Leerzeichen werden entfernt und Groß-/Kleinschreibung normalisiert. JSON enthält nur Linked-Server-Zeilen und wird unabhängig über @JsonErzeugen angefordert. NULL, Leertext oder andere Werte ergeben INVALID_PARAMETER.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel linkedServers und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 serialisiert LimitedRows nach ServerName sortiert, also dieselbe begrenzte Auswahl wie die Inventar-Zeilenausgaben. NULL aktiviert IF nicht; leer wird []. Waitwerte sind nicht Teil des JSON-Arrays. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.';
        PRINT N'@PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und OUTPUT-Zuweisungen, daher bleiben gebundene OUTPUT-Empfänger unverändert. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Gesamtwerte: AVAILABLE, AVAILABLE_EMPTY (kein Linked Server), AVAILABLE_LIMITED (Remoteprüfung teilweise fehlgeschlagen), AUTHORIZATION_REQUIRED (Test angefordert, zweites Opt-in fehlt), INVALID_PARAMETER (ungültige Ausgabeart, Zeilengrenze oder NULL-Opt-in). Zeilenstatus: AVAILABLE oder bei Remotefehler DENIED_PERMISSION, SOURCE_TIMEOUT, SOURCE_UNAVAILABLE; ConnectivityStatus ist NOT_EXECUTED, AUTHORIZATION_REQUIRED, SUCCEEDED oder FAILED. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss NULL ohne abgefangenen Remote-Testfehler. Andernfalls enthält der Wert ERROR_NUMBER() des zuletzt abgefangenen Remote-Testfehlers; mehrere Fehler überschreiben den Wert jeweils. Die Einzelzeilen behalten ihre jeweiligen Fehlerhinweise. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Parametern oder fehlender Remote-Testbestätigung. Bei abgefangenen Remote-Testfehlern enthält der Wert die letzte ERROR_MESSAGE(); sonst NULL. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE [#LinkedServerAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N''{"linkedServers":"#LinkedServerAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#LinkedServerAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#LinkedServerAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#LinkedServerAnalysis_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_LinkedServerAnalysis] @Hilfe=1;';









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
