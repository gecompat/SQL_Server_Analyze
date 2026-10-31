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
   PRINT N'@IncludeCursorDetails: bit, Default 0. 0 liest keine Zeilen aus sys.dm_exec_cursors und lässt Status NOT_EXECUTED (sofern kein Parameterfehler vorliegt); 1 aktiviert den Quellscan. NULL ist ungültig und ergibt INVALID_PARAMETER. Andere bit-Werte sind bei T-SQL-Konvertierung nicht darstellbar. Das Opt-in betrifft genau @TargetSessionId; es erfolgt kein instanzweiter Cursor-Scan.';
   PRINT N'@SessionIds: nvarchar(max), Default NULL. NULL sowie eine nach LTRIM/RTRIM leere Eingabe (äußere U+0020-Leerzeichen) wählen die aufrufende Session @@SPID. Sonst ersetzt die Funktion zunächst jedes Komma und Semikolon durch Pipe und zerlegt danach an Pipes außerhalb bracket-quotierter Bereiche [ ... ]; innerhalb eines solchen Bereichs trennt Pipe nicht und ]] maskiert eine schließende Klammer. Der Parser trimmt äußere U+0020-Leerzeichen, entquotet Klammern aber nicht. Ein Rohsegment über 4000 UTF-16-Codeeinheiten wird ITEM_TOO_LONG; leere Segmente werden EMPTY_ITEM und ungültige/unvollständige Klammerstruktur INVALID_BRACKET_SYNTAX. Für eine gültige Parserzeile muss TRY_CONVERT(bigint, ItemText) gelingen. Nach der Zahlenkonvertierung muss genau ein gültiger Zahlenwert im Bereich 1 bis 32767 verbleiben. Mehrere Elemente (auch Duplikate), ungültige Segmente, nicht konvertierbare Zahlenwerte und Werte außerhalb des Bereichs ergeben INVALID_PARAMETER. Es findet keine Deduplikation statt und es wird nicht vorab geprüft, ob die Session existiert oder sichtbar ist. Tabs oder sonstige Zeichen werden nicht pauschal als ungültig eingestuft; die Parser- und TRY_CONVERT-Ergebnisse entscheiden.';
   PRINT N'@MaxZeilen: int, Default 200. NULL wird ausdrücklich zu 0 normalisiert. Negative Werte ergeben INVALID_PARAMETER. 0 bedeutet keine praktische Limitierung bis TOP(2147483647), nicht null Zeilen; positive Werte begrenzen die in die lokale Tabelle übernommenen Zeilen auf höchstens diesen Wert. Auswahlreihenfolge für TOP: WorkerTime absteigend, Reads absteigend, CursorId aufsteigend. JSON ordnet WorkerTime absteigend, CursorId aufsteigend; die materialisierten Zeilen bleiben dieselben.';
   PRINT N'@ResultSetArt: varchar(16), Default ''CONSOLE''. NULL und nach LTRIM/RTRIM (Entfernung äußerer U+0020-Leerzeichen) leere Eingaben ergeben nach UPPER einen ungültigen Modus und INVALID_PARAMETER. Geschlossene Werte: CONSOLE erzeugt über InternalEmitConsoleResult ein lesbares Resultset mit Ergebnislabel cursors (bei leerer Quelle eine verständliche Leerzeile); RAW gibt ein Status-/Zähler-Resultset und nur bei @IncludeCursorDetails=1 zusätzlich Cursorzeilen aus; TABLE materialisiert die erlaubte Zuordnung cursors in eine geprüfte lokale #Temp-Zieltabelle; NONE gibt keine fachlichen Resultsets aus. Es gibt keine weiteren erlaubten Werte. Groß-/Kleinschreibung wird durch UPPER vereinheitlicht, äußere U+0020-Leerzeichen werden entfernt. CONSOLE und TABLE setzen intern den Modus für die Statusmeldung auf NONE; @PrintMeldungen=1 kann daher auch bei diesen beiden Ausgabearten eine Status-PRINT-Meldung auslösen.';
   PRINT N'@ResultTablesJson: nvarchar(max), Default NULL. Für CONSOLE, RAW und NONE muss der Wert NULL oder nach LTRIM/RTRIM (Entfernung äußerer U+0020-Leerzeichen) leer sein; ein anderer Wert löst 51011 aus. Für TABLE ist ein gültiges JSON-Objekt mit genau der Zuordnung des Resultnamens cursors zu einer lokalen #Temp-Tabelle erforderlich, z. B. N''{"cursors":"#CursorExport"}''. NULL/leer, falsche Schlüssel oder Typen, globale ##- und permanente Tabellen, reserviertes Präfix #Monitor, zu lange/fehlende Ziele sowie doppelte Ziele werden abgelehnt. Das Ziel muss vorab vorhanden und leer sein und genau eine Seed-/Dummy-Spalte haben; diese wird an das Cursor-Resultatschema angepasst. Die TABLE-Vorprüfung läuft vor Parameter-/Quellenprüfung und kann bei Fehlern mit THROW abbrechen.';
   PRINT N'@JsonErzeugen: bit, Default 0. 0 oder NULL erzeugt kein JSON; @Json bleibt NULL. 1 erzeugt @Json als JSON-Array der materialisierten Cursorzeilen ohne Status-/Fehler-Envelope; bei null Cursorzeilen ist der Wert []. Das Array enthält dieselbe begrenzte Materialisierung und wird nach WorkerTime absteigend und CursorId aufsteigend geordnet. Der Parameter wird nicht separat validiert; nur der Vergleich mit 1 aktiviert die Erzeugung.';
   PRINT N'@Json: nvarchar(max), OUTPUT, Default NULL (Bindung als OUTPUT erforderlich, wenn der Aufrufer den Wert empfangen soll). Der bisherige Eingabewert wird beim Eintritt sofort überschrieben und auf NULL gesetzt; bei @JsonErzeugen=1 wird er später durch das JSON-Array ersetzt, sonst bleibt er NULL. Bei @Hilfe=1 ist er ebenfalls bereits NULL, weil die Initialisierung vor dem Hilfezweig liegt. Das JSON enthält keine Status- oder Fehlerhülle.';
   PRINT N'@PrintMeldungen: bit, Default 1. 1 gibt nach der Analyse Status: <Status> per PRINT aus, wenn der interne Modus NONE ist; dies gilt direkt für NONE und wegen der internen Umschaltung auch für CONSOLE und TABLE. 0 oder NULL unterdrückt diese Statusmeldung. Der Hilfezweig liegt davor und druckt seine Hilfe unabhängig von diesem Parameter.';
   PRINT N'@Hilfe: bit, Default 0. 1 druckt die eingebettete Hilfe und Beispielaufrufe und kehrt vor Lock-Timeout-Änderung, TABLE-Vorprüfung, Parameter-Validierung und Quellenzugriff zurück. 0 oder NULL setzt den normalen Pfad fort. Im Hilfezweig wird @Json zuvor auf NULL gesetzt; die vier Status-/Fehler-OUTPUT-Parameter werden nicht beschrieben und behalten daher ihre übergebenen Eingangswerte. Die Hilfe-PRINTs hängen nicht von @PrintMeldungen ab.';
   PRINT N'@StatusCodeOut: varchar(40), OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert überschrieben. Geschlossene Statusmenge: NOT_EXECUTED bedeutet, dass Cursordetails nicht angefordert wurden; INVALID_PARAMETER kennzeichnet ungültige Parameter; AVAILABLE bedeutet, dass mindestens eine Cursorzeile gelesen wurde; AVAILABLE_EMPTY bedeutet, dass keine Cursorzeile sichtbar war; DENIED_PERMISSION kennzeichnet abgefangene Fehler 229, 297, 300, 371 oder 916 beim DMV-Zugriff; SOURCE_UNAVAILABLE kennzeichnet einen anderen abgefangenen Fehler beim Quellzugriff. Der Hilfezweig kehrt vor der Zuweisung zurück und lässt den Eingangswert bestehen. Ein THROW vor normalem Rücklauf erreicht die Zuweisung am Prozedurende nicht.';
   PRINT N'@IsPartialOut: bit, OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert mit 0 (vollständig im Modulstatus) oder 1 überschrieben. 1 wird bei INVALID_PARAMETER und abgefangenem DMV-Fehler gesetzt. Der Hilfezweig weist den Parameter nicht zu; ein THROW vor normalem Rücklauf erreicht die Zuweisung nicht.';
   PRINT N'@ErrorNumberOut: int, OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert mit der abgefangenen SQL-Fehlernummer überschrieben; ohne abgefangenen Fehler bleibt das Ergebnis NULL. Der Hilfezweig weist ihn nicht zu; ein THROW vor normalem Rücklauf erreicht die Zuweisung nicht.';
   PRINT N'@ErrorMessageOut: nvarchar(2048), OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert mit der Validierungs-/abgefangenen DMV-Fehlermeldung überschrieben; wenn keine gesetzt ist, ist das Ergebnis NULL. Der Hilfezweig weist ihn nicht zu; ein THROW vor normalem Rücklauf erreicht die Zuweisung nicht.';
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
