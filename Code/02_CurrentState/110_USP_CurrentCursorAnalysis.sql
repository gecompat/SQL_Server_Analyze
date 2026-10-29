USE [DeineDatenbank];
GO

/* OPS-007: bounded, session-scoped cursor evidence; opt-in only. */
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentCursorAnalysis]
      @IncludeCursorDetails bit            = 0
    , @SessionIds          nvarchar(max)  = NULL
    , @MaxZeilen           int            = 200
    , @ResultSetArt        varchar(16)    = 'CONSOLE'
    , @ResultTablesJson    nvarchar(max)  = NULL
    , @JsonErzeugen        bit            = 0
    , @Json                nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen      bit            = 1
    , @Hilfe               bit            = 0
    , @StatusCodeOut       varchar(40)    = NULL OUTPUT
    , @IsPartialOut        bit            = NULL OUTPUT
    , @ErrorNumberOut      int            = NULL OUTPUT
    , @ErrorMessageOut     nvarchar(2048) = NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET @Json=NULL;
 SET @MaxZeilen=COALESCE(@MaxZeilen,0);
 DECLARE @Status varchar(40)='NOT_EXECUTED',@Partial bit=0,@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
 DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@TargetSessionId int=@@SPID;
 IF @Hilfe=1
 BEGIN
   PRINT N'monitor.USP_CurrentCursorAnalysis';
   PRINT N'Erfasst Cursor der aktuell gewählten Session ausschließlich aus sys.dm_exec_cursors(@TargetSessionId). Ohne @IncludeCursorDetails=1 wird kein Cursor-Quellscan ausgeführt; die Analyse ist opt-in und liefert eine begrenzte Momentaufnahme, keine Aussage über frühere oder spätere Cursorzustände.';
   PRINT N'@IncludeCursorDetails bit=0 deaktiviert das Lesen der Cursor-DMV und ergibt ein leeres Datenresultat. 1 liest Cursorinformationen; FindingContext unterscheidet INVENTORY_ONLY, RESOURCE_CONTEXT und DORMANT_CONTEXT anhand der im Resultat sichtbaren Werte.';
   PRINT N'@SessionIds nvarchar(max)=NULL verwendet die aufrufende Session. Eine gesetzte Liste muss nach Pipe-, Komma- oder Semikolontrennung genau eine gültige Session-ID zwischen 1 und 32767 enthalten; mehrere, ungültige oder leere Listenelemente führen zum Status INVALID_PARAMETER.';
   PRINT N'@MaxZeilen int=200 begrenzt positive Werte auf so viele Cursorzeilen. 0 oder NULL wird intern zu 0 und erlaubt bis zu 2147483647 Zeilen; negative Werte sind ungültig.';
   PRINT N'@ResultSetArt varchar(16)=''CONSOLE'' wählt CONSOLE (Default), RAW, TABLE oder NONE. Die Eingabe wird außen getrimmt und großgeschrieben. CONSOLE erzeugt eine lesbare Cursoransicht samt verständlicher Leerzeile, RAW Status-/Zähler- und optionales Detailresultset, TABLE exportiert cursors, NONE unterdrückt fachliche Resultsets.';
   PRINT N'@ResultTablesJson nvarchar(max)=NULL wird nur für TABLE verwendet und ordnet cursors genau einer lokalen Zieltabelle zu. Die Tabelle muss vorher leer und mit genau einer beliebigen Platzhalterspalte angelegt sein; globale oder permanente Ziele sind unzulässig.';
   PRINT N'@JsonErzeugen bit=0 deaktiviert JSON; 1 schreibt @Json. @Json nvarchar(max)=NULL OUTPUT enthält bei aktivierter Ausgabe ein JSON-Array der Cursorzeilen ohne Envelope; ein leerer Bestand ergibt []. @PrintMeldungen bit=1 gibt im NONE-Modus eine Statusmeldung aus; 0 unterdrückt diese Meldung.';
   PRINT N'@Hilfe bit=0 führt die Analyse aus; 1 zeigt diese Hilfe und kehrt vor dem Setzen des Lock-Timeouts und vor Quellenzugriffen zurück. @StatusCodeOut varchar(40)=NULL OUTPUT liefert StatusCode; @IsPartialOut bit=NULL OUTPUT den Teilstatus; @ErrorNumberOut int=NULL OUTPUT und @ErrorMessageOut nvarchar(2048)=NULL OUTPUT liefern Fehlerdetails, soweit vorhanden.';
   PRINT N'Die Quelle verlangt ausreichende Sichtbarkeit für sys.dm_exec_cursors; bei verweigertem Zugriff oder nicht verfügbarer Quelle stehen Status und Fehler im RAW-Status und in den Status-OUTPUTs. JSON enthält ausschließlich Cursorzeilen und keine Status- oder Fehlerfelder.';
   PRINT N'CONSOLE-Beispiel:';
   PRINT N'EXEC [monitor].[USP_CurrentCursorAnalysis] @IncludeCursorDetails=1,@ResultSetArt=''CONSOLE'';';
   PRINT N'TABLE-Beispiel:';
   PRINT N'DECLARE @Tables nvarchar(max)=N''{"cursors":"#CurrentCursorAnalysis_HelpExample"}''; CREATE TABLE [#CurrentCursorAnalysis_HelpExample]([Placeholder] int); EXEC [monitor].[USP_CurrentCursorAnalysis] @IncludeCursorDetails=1,@ResultSetArt=''TABLE'',@ResultTablesJson=@Tables; SELECT * FROM [#CurrentCursorAnalysis_HelpExample]; DROP TABLE [#CurrentCursorAnalysis_HelpExample];';
   PRINT N'JSON-Beispiel:';
   PRINT N'DECLARE @J nvarchar(max); EXEC [monitor].[USP_CurrentCursorAnalysis] @IncludeCursorDetails=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT; SELECT @J AS [Json];';
   PRINT N'Die Ausgabe ist ein JSON-Array.';
   RETURN; END;
 DECLARE @PreviousLockTimeout int=@@LOCK_TIMEOUT,@RestoreLockTimeoutSql nvarchar(100); SET LOCK_TIMEOUT 0;
 DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
 IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
 IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'cursors',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; END;
 IF @TableResultRequested=1 OR @ConsoleResultRequested=1 SET @Mode='NONE';
 CREATE TABLE [#CurrentCursorAnalysis_Cursors]
 (
      [SessionId] int
    , [CursorId] int
    , [CursorName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS
    , [Properties] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS
    , [CreationTime] datetime
    , [IsOpen] bit
    , [FetchStatus] int
    , [WorkerTime] bigint
    , [Reads] bigint
    , [Writes] bigint
    , [DormantDuration] bigint
    , [FindingContext] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS
 );
 IF NULLIF(LTRIM(RTRIM(COALESCE(@SessionIds,N''))),N'') IS NOT NULL
 BEGIN
   DECLARE @SessionSelection TABLE([NumberValue] bigint NULL,[IsValid] bit NOT NULL);
   INSERT @SessionSelection([NumberValue],[IsValid])
   SELECT [NumberValue],[IsValid] FROM [monitor].[TVF_ParseBigintList](@SessionIds);
   IF (SELECT COUNT_BIG(*) FROM @SessionSelection)<>1
      OR EXISTS(SELECT 1 FROM @SessionSelection WHERE [IsValid]=0 OR [NumberValue] NOT BETWEEN 1 AND 32767)
     SELECT @Status='INVALID_PARAMETER',@Partial=1,@ErrorMessage=N'@SessionIds muss genau eine gültige Session-ID enthalten.';
   ELSE
     SELECT @TargetSessionId=CONVERT(int,[NumberValue]) FROM @SessionSelection;
 END;
 IF @Status='NOT_EXECUTED' AND (@MaxZeilen<0 OR @Mode NOT IN('CONSOLE','RAW','NONE') OR @IncludeCursorDetails IS NULL) SELECT @Status='INVALID_PARAMETER',@Partial=1,@ErrorMessage=N'Ungültiger Parameter.';
 ELSE IF @Status='NOT_EXECUTED' AND @IncludeCursorDetails=1 BEGIN TRY
   INSERT [#CurrentCursorAnalysis_Cursors] SELECT TOP(CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END) [session_id],[cursor_id],[name],[properties],[creation_time],[is_open],[fetch_status],[worker_time],[reads],[writes],[dormant_duration],CASE WHEN [is_open]=1 AND [dormant_duration]>60000 THEN 'DORMANT_CONTEXT' WHEN [is_open]=1 AND ([worker_time]>0 OR [reads]>0 OR [writes]>0) THEN 'RESOURCE_CONTEXT' ELSE 'INVENTORY_ONLY' END FROM [sys].[dm_exec_cursors](@TargetSessionId) ORDER BY [worker_time] DESC,[reads] DESC,[cursor_id];
   SET @Status=CASE WHEN EXISTS(SELECT 1 FROM [#CurrentCursorAnalysis_Cursors]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END;
 END TRY BEGIN CATCH SELECT @Status=CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'SOURCE_UNAVAILABLE' END,@Partial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(); END CATCH;
 IF @JsonErzeugen=1 SELECT @Json=COALESCE((SELECT * FROM [#CurrentCursorAnalysis_Cursors] ORDER BY [WorkerTime] DESC,[CursorId] FOR JSON PATH),N'[]');
 IF @Mode IN('CONSOLE','RAW') BEGIN SELECT @Status [StatusCode],@Partial [IsPartial],@TargetSessionId [SessionId],COUNT_BIG(*) [CursorCount],@ErrorMessage [ErrorMessage] FROM [#CurrentCursorAnalysis_Cursors]; IF @IncludeCursorDetails=1 SELECT * FROM [#CurrentCursorAnalysis_Cursors] ORDER BY [WorkerTime] DESC,[CursorId]; END;
 IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
 IF @ConsoleResultRequested=1 EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#CurrentCursorAnalysis_Cursors',@ResultLabel=N'cursors',@EmptyMessage=N'Keine sichtbaren Cursor im gewählten Scope';
 IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#CurrentCursorAnalysis_Cursors',@TargetTable=@TableTarget,@ThrowOnError=1;
 SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';'; EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql; SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
END;
GO
