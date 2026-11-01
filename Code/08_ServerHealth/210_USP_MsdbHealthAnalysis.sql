USE [DeineDatenbank];
GO

/* OPS-008: bounded msdb history and size inventory; never deletes history. */
CREATE OR ALTER PROCEDURE [monitor].[USP_MsdbHealthAnalysis]
      @MaxZeilen       int            = 2000
    , @ResultSetArt    varchar(16)    = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen    bit            = 0
    , @Json            nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen  bit            = 1
    , @Hilfe           bit            = 0
    , @StatusCodeOut   varchar(40)    = NULL OUTPUT
    , @IsPartialOut    bit            = NULL OUTPUT
    , @ErrorNumberOut  int            = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET @Json=NULL;
    SET @MaxZeilen=COALESCE(@MaxZeilen,0);
    DECLARE @Status varchar(40)='AVAILABLE',@Partial bit=0,@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL;
    IF @Hilfe=1 BEGIN
        PRINT N'monitor.USP_MsdbHealthAnalysis';
        PRINT N'inventarisiert msdb-Dateigröße und sichtbare Aggregate ausgewählter Backup-, Restore-, Agent-, Database-Mail- und Maintenance-Plan-Quellen. Es ändert oder löscht keine Daten.';
        PRINT N'Die Auswertung zählt Quellzeilen und ermittelt verfügbare Zeitgrenzen; Agent-Historienzeilen erhalten keine Zeitgrenzen. Sie belegt weder fachlich richtige Retention noch Restorefähigkeit, Jobausführung, Mailzustellung, freien Speicher oder nötige Dateiverkleinerung. Große Aggregate können I/O verursachen. @MaxZeilen begrenzt die Ausgabe, nicht die Quellaggregation. Quellenfehler können partielle Evidenz ergeben.';
        PRINT N'@MaxZeilen int; Default: 2000. NULL wird vor der Validierung zu 0; 0 bedeutet unbegrenzt. Positive Werte behalten nach Area sortiert die ersten Zeilen. EvidenceRows wird vor dem Kürzen gezählt. Negative Werte ergeben INVALID_PARAMETER und verhindern Quellenaggregation.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel msdbHealth und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 serialisiert die bereits nach @MaxZeilen gekürzten Zeilen nach Area sortiert. NULL aktiviert IF nicht; leere Menge wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.';
        PRINT N'@PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und OUTPUT-Zuweisungen, daher bleiben gebundene OUTPUT-Empfänger unverändert. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Mögliche Gesamtwerte sind AVAILABLE (Auswertung ohne gemeldete Quellfehler), AVAILABLE_LIMITED (mindestens eine Quelle nicht lesbar), UNSUPPORTED (msdb fehlt) und INVALID_PARAMETER (negative Zeilengrenze oder ungültige Ausgabeart). Evidenzzeilen haben AVAILABLE, UNSUPPORTED (Objekt fehlt) oder SOURCE_UNAVAILABLE. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Parametern oder fehlender msdb; sonst NULL. Fehler einzelner Historienquellen stehen in den Fachzeilen. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE [#MsdbHealthAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N''{"msdbHealth":"#MsdbHealthAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#MsdbHealthAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_MsdbHealthAnalysis] @Hilfe=1;';








        RETURN;
    END;
    DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
    SET LOCK_TIMEOUT 0;
    DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'msdbHealth',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; END;
    IF @TableResultRequested=1 OR @ConsoleResultRequested=1 SET @Mode='NONE';
    CREATE TABLE [#MsdbHealthAnalysis_Health]
    (
          [Area] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RowCount] bigint NULL,[OldestUtc] datetime2(3) NULL,[NewestUtc] datetime2(3) NULL
        , [SizeMb] decimal(19,2) NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    IF @MaxZeilen<0 OR @Mode NOT IN('CONSOLE','RAW','NONE') SELECT @Status='INVALID_PARAMETER',@Partial=1,@ErrorMessage=N'Ungültiger Parameter.';
    IF @Status='AVAILABLE' AND NOT EXISTS (SELECT 1 FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id]=4)
        SELECT @Status='UNSUPPORTED',@Partial=1,@ErrorMessage=N'msdb ist nicht verfügbar.';
    IF @Status='AVAILABLE'
    BEGIN
        INSERT [#MsdbHealthAnalysis_Health]
        SELECT 'DATABASE_SIZE',N'master.sys.master_files',NULL,NULL,NULL,
               CONVERT(decimal(19,2),SUM(CONVERT(bigint,[size]))*8.0/1024.0),'AVAILABLE',
               N'Aktuelle Dateigröße; kein Wachstums- oder freier Speicherplatznachweis.'
        FROM [sys].[master_files] WITH (NOLOCK) WHERE [database_id]=4;
        DECLARE @Defs TABLE
        (
              [Area] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS
            , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS
            , [DateColumn] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        INSERT @Defs VALUES
          ('BACKUP_HISTORY','backupset','backup_finish_date'),('RESTORE_HISTORY','restorehistory','restore_date'),
          ('AGENT_HISTORY','sysjobhistory',NULL),('DATABASE_MAIL','sysmail_allitems','send_request_date'),
          ('MAINTENANCE_PLAN','sysmaintplan_log','start_time');
        DECLARE @Area varchar(40),@Obj sysname,@Date sysname,@Sql nvarchar(max),@Source nvarchar(256);
        DECLARE [d] CURSOR LOCAL FAST_FORWARD FOR SELECT [Area],[ObjectName],[DateColumn] FROM @Defs;
        OPEN [d]; FETCH NEXT FROM [d] INTO @Area,@Obj,@Date;
        WHILE @@FETCH_STATUS=0
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1
                FROM [msdb].[sys].[objects] AS [o] WITH (NOLOCK)
                INNER JOIN [msdb].[sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id]
                WHERE [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'dbo'
                  AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Obj COLLATE SQL_Latin1_General_CP1_CS_AS
                  AND [o].[type] COLLATE SQL_Latin1_General_CP1_CS_AS IN (N'U', N'V')
            )
                INSERT [#MsdbHealthAnalysis_Health] VALUES(@Area,N'msdb.dbo.'+@Obj,NULL,NULL,NULL,NULL,'UNSUPPORTED',N'Quelle ist auf dieser Instanz nicht vorhanden.');
            ELSE BEGIN TRY
                SET @Source=N'msdb.dbo.'+@Obj;
                SET @Sql=N'INSERT [#MsdbHealthAnalysis_Health] SELECT @Area,@Source,COUNT_BIG(*),' +
                    CASE WHEN @Date IS NULL THEN N'NULL,NULL' ELSE N'MIN('+QUOTENAME(@Date)+N'),MAX('+QUOTENAME(@Date)+N')' END +
                    N',NULL,''AVAILABLE'',N''Retentionbewertung ist kontextabhängig; es wird nichts gelöscht.'' FROM [msdb].[dbo].'+QUOTENAME(@Obj)+N' WITH (NOLOCK);';
                EXEC [sys].[sp_executesql] @Sql,N'@Area varchar(40),@Source nvarchar(256)',@Area,@Source;
            END TRY BEGIN CATCH
                INSERT [#MsdbHealthAnalysis_Health] VALUES(@Area,N'msdb.dbo.'+@Obj,NULL,NULL,NULL,NULL,'SOURCE_UNAVAILABLE',CONCAT(N'Fehler ',ERROR_NUMBER(),N': ',LEFT(ERROR_MESSAGE(),800)));
                SET @Partial=1;
            END CATCH;
            FETCH NEXT FROM [d] INTO @Area,@Obj,@Date;
        END; CLOSE [d]; DEALLOCATE [d];
        IF @Partial=1 SET @Status='AVAILABLE_LIMITED';
    END;
    DECLARE @EvidenceRows bigint=(SELECT COUNT_BIG(*) FROM [#MsdbHealthAnalysis_Health]);
    IF @MaxZeilen>0
    BEGIN
        ;WITH [LimitedRows] AS
        (
            SELECT ROW_NUMBER() OVER (ORDER BY [Area]) AS [Ordinal]
            FROM [#MsdbHealthAnalysis_Health]
        )
        DELETE FROM [LimitedRows] WHERE [Ordinal]>@MaxZeilen;
    END;
    IF @JsonErzeugen=1 SELECT @Json=COALESCE((SELECT * FROM [#MsdbHealthAnalysis_Health] ORDER BY [Area] FOR JSON PATH),N'[]');
    IF @Mode IN('CONSOLE','RAW') BEGIN SELECT @Status [StatusCode],@Partial [IsPartial],@EvidenceRows [EvidenceRows],@ErrorMessage [ErrorMessage]; SELECT * FROM [#MsdbHealthAnalysis_Health] ORDER BY [Area]; END;
    IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
    IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#MsdbHealthAnalysis_Health',@ResultLabel=N'msdbHealth',@EmptyMessage=N'Keine msdb-Health-Evidenz im sichtbaren Scope';
    IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#MsdbHealthAnalysis_Health',@TargetTable=@TableTarget,@ThrowOnError=1;
    SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
    SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
END;
GO
