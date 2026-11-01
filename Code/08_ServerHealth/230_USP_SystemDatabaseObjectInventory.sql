USE [DeineDatenbank];
GO

/* OPS-009: visible user-object inventory in master, model and msdb; no DDL. */
CREATE OR ALTER PROCEDURE [monitor].[USP_SystemDatabaseObjectInventory]
      @MaxZeilen int=2000,@ResultSetArt varchar(16)='CONSOLE',@ResultTablesJson nvarchar(max)=NULL,@JsonErzeugen bit=0,@Json nvarchar(max)=NULL OUTPUT,
      @PrintMeldungen bit=1,@Hilfe bit=0,@StatusCodeOut varchar(40)=NULL OUTPUT,@IsPartialOut bit=NULL OUTPUT,
      @ErrorNumberOut int=NULL OUTPUT,@ErrorMessageOut nvarchar(2048)=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET @Json=NULL;
 DECLARE @Status varchar(40)='AVAILABLE',@Partial bit=0,@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
 DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL;
 IF @Hilfe=1 BEGIN
        PRINT N'monitor.USP_SystemDatabaseObjectInventory';
        PRINT N'inventarisiert sichtbare, nicht als Microsoft-Objekte markierte Benutzerobjekte in online befindlichen Datenbanken master, model und msdb. Interne Tabellen und Objekte der Typen S und IT sind ausgeschlossen. Es liest Katalogmetadaten, keine Objektinhalte oder Definitionen, und führt keine DDL aus.';
        PRINT N'Das Inventar hängt vom aktuellen Sicherheitskontext ab; eine leere Ausgabe beweist keine Objektfreiheit. Fehlende Sicht oder Datenbankzugriff kann die Evidenz einschränken. @MaxZeilen begrenzt CONSOLE, RAW, TABLE und JSON auf dieselbe Mitgliedschaft. Die positive Grenze wählt deterministisch nach DatabaseName, SchemaName und ObjectName; RAW und JSON geben diese Zeilen sortiert aus, CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. Status und Teilsichtbarkeit beziehen sich auf das vollständige Inventar. Die Grenze reduziert den Katalogzugriff nicht.';
        PRINT N'@MaxZeilen int; Default: 2000. NULL wird zu 0; 0 bedeutet unbegrenzt. Positive Werte behalten nach DatabaseName, SchemaName und ObjectName sortiert die ersten Zeilen. Begrenzung erfolgt nach vollständiger Katalogabfrage und reduziert deren Aufwand nicht; Status/ObjectCount beziehen sich auf den vollen Scope. Negative Werte ergeben INVALID_PARAMETER und keine Inventarzeilen.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel systemDatabaseObjects und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.';
        PRINT N'@JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 serialisiert die nach @MaxZeilen begrenzten LimitedRows sortiert nach den drei Namen. NULL aktiviert IF nicht; leere Auswahl wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.';
        PRINT N'@PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und OUTPUT-Zuweisungen, daher bleiben gebundene OUTPUT-Empfänger unverändert. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Gesamtwerte: AVAILABLE, AVAILABLE_EMPTY (keine sichtbaren Inventarzeilen), AVAILABLE_LIMITED (fehlender Zugriff/Quellenfehler) und INVALID_PARAMETER (negative Grenze oder ungültige Ausgabeart). Zeilenstatus ist AVAILABLE, DENIED_PERMISSION oder SOURCE_UNAVAILABLE. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung bei ungültigen Parametern; sonst NULL. Fehler einzelner Datenbankquellen stehen in den Inventarzeilen, ohne automatische Übernahme. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.';
        PRINT N'EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE [#SystemDatabaseObjectInventory_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N''{"systemDatabaseObjects":"#SystemDatabaseObjectInventory_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt=''TABLE'', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#SystemDatabaseObjectInventory_HelpExample];
    DROP TABLE IF EXISTS [#SystemDatabaseObjectInventory_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#SystemDatabaseObjectInventory_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_SystemDatabaseObjectInventory] @Hilfe=1;';








        RETURN;
    END;
 DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
 SET LOCK_TIMEOUT 0;
 DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
 IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
 IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'systemDatabaseObjects',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; END;
 IF @TableResultRequested=1 OR @ConsoleResultRequested=1 SET @Mode='NONE';
 CREATE TABLE [#SystemDatabaseObjectInventory_Objects]
 (
      [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [ObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [CreateDate] datetime NULL
    , [ModifyDate] datetime NULL
    , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
 );
 IF @MaxZeilen<0 OR @Mode NOT IN('CONSOLE','RAW','NONE') SELECT @Status='INVALID_PARAMETER',@Partial=1,@ErrorMessage=N'Ungültiger Parameter.';
 IF @Status='AVAILABLE' BEGIN
  DECLARE @Db sysname,@Sql nvarchar(max); DECLARE [d] CURSOR LOCAL FAST_FORWARD FOR SELECT [name] FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id] IN(1,3,4) AND [state]=0;
  OPEN [d]; FETCH NEXT FROM [d] INTO @Db; WHILE @@FETCH_STATUS=0 BEGIN
   IF COALESCE(HAS_DBACCESS(@Db),0)<>1 BEGIN INSERT [#SystemDatabaseObjectInventory_Objects] VALUES(@Db,NULL,NULL,NULL,NULL,NULL,'DENIED_PERMISSION',N'Die Systemdatenbank ist für den aktuellen Sicherheitskontext nicht zugänglich.'); SET @Partial=1; END
   ELSE BEGIN TRY SET @Sql=N'INSERT [#SystemDatabaseObjectInventory_Objects] SELECT @Db,[s].[name],[o].[name],[o].[type_desc],[o].[create_date],[o].[modify_date],''AVAILABLE'',N''Sichtbares Inventar; Bewertung benötigt Objektverantwortung und Betriebszweck.'' FROM '+QUOTENAME(@Db)+N'.[sys].[objects] [o] WITH (NOLOCK) JOIN '+QUOTENAME(@Db)+N'.[sys].[schemas] [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id] WHERE [o].[is_ms_shipped]=0 AND [o].[type] NOT IN(''S'',''IT'');'; EXEC [sys].[sp_executesql] @Sql,N'@Db sysname',@Db; END TRY
   BEGIN CATCH INSERT [#SystemDatabaseObjectInventory_Objects] VALUES(@Db,NULL,NULL,NULL,NULL,NULL,CASE WHEN ERROR_NUMBER() IN (229,371,916) THEN 'DENIED_PERMISSION' ELSE 'SOURCE_UNAVAILABLE' END,CONCAT(N'Fehler ',ERROR_NUMBER(),N': ',LEFT(ERROR_MESSAGE(),800))); SET @Partial=1; END CATCH;
   FETCH NEXT FROM [d] INTO @Db; END; CLOSE [d]; DEALLOCATE [d]; IF NOT EXISTS(SELECT 1 FROM [#SystemDatabaseObjectInventory_Objects]) SET @Status='AVAILABLE_EMPTY'; ELSE IF @Partial=1 SET @Status='AVAILABLE_LIMITED';
 END;
 CREATE TABLE [#SystemDatabaseObjectInventory_LimitedRows] ([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ObjectType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[CreateDate] datetime NULL,[ModifyDate] datetime NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 INSERT [#SystemDatabaseObjectInventory_LimitedRows] SELECT TOP(CASE WHEN @MaxZeilen<0 OR COALESCE(@MaxZeilen,0)=0 THEN 2147483647 ELSE @MaxZeilen END) * FROM [#SystemDatabaseObjectInventory_Objects] ORDER BY [DatabaseName],[SchemaName],[ObjectName];
 IF @JsonErzeugen=1 SELECT @Json=COALESCE((SELECT * FROM [#SystemDatabaseObjectInventory_LimitedRows] ORDER BY [DatabaseName],[SchemaName],[ObjectName] FOR JSON PATH),N'[]');
 IF @Mode IN('CONSOLE','RAW') BEGIN SELECT @Status [StatusCode],@Partial [IsPartial],COUNT_BIG(*) [ObjectCount],@ErrorMessage [ErrorMessage] FROM [#SystemDatabaseObjectInventory_Objects]; SELECT * FROM [#SystemDatabaseObjectInventory_LimitedRows] ORDER BY [DatabaseName],[SchemaName],[ObjectName]; END;
 IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
 IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#SystemDatabaseObjectInventory_LimitedRows',@ResultLabel=N'systemDatabaseObjects',@EmptyMessage=N'Keine sichtbaren Benutzerobjekte in Systemdatenbanken';
 IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#SystemDatabaseObjectInventory_LimitedRows',@TargetTable=@TableTarget,@ThrowOnError=1;
 SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
 SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';'; EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
END;
GO
