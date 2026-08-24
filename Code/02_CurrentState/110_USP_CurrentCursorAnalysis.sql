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
 DECLARE @Status varchar(40)='NOT_EXECUTED',@Partial bit=0,@Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
 DECLARE @ErrorNumber int=NULL,@ErrorMessage nvarchar(2048)=NULL,@TargetSessionId int=@@SPID;
 IF @Hilfe=1 BEGIN PRINT N'monitor.USP_CurrentCursorAnalysis'; PRINT N'Cursor-Details sind opt-in und auf genau eine Session sowie @MaxZeilen begrenzt.'; RETURN; END;
 DECLARE @PreviousLockTimeout int=@@LOCK_TIMEOUT,@RestoreLockTimeoutSql nvarchar(100); SET LOCK_TIMEOUT 0;
 DECLARE @TableResultRequested bit=CASE WHEN @Mode='TABLE' THEN 1 ELSE 0 END,@TableTarget sysname=NULL;
 IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
 IF @TableResultRequested=1 BEGIN EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'cursors',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1; SET @Mode='NONE'; END;
 CREATE TABLE [#CurrentCursorAnalysis_Cursors]([SessionId]int,[CursorId]int,[CursorName]nvarchar(256),[Properties]nvarchar(256),[CreationTime]datetime,[IsOpen]bit,[FetchStatus]int,[WorkerTime]bigint,[Reads]bigint,[Writes]bigint,[DormantDuration]bigint,[FindingContext]varchar(40));
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
   INSERT [#CurrentCursorAnalysis_Cursors] SELECT TOP(CASE WHEN @MaxZeilen=0 THEN 2147483647 ELSE @MaxZeilen END) [session_id],[cursor_id],[name],[properties],[creation_time],[is_open],[fetch_status],[worker_time],[reads],[writes],[dormant_duration],CASE WHEN [is_open]=1 AND ([worker_time]>0 OR [reads]>0 OR [writes]>0) THEN 'RESOURCE_CONTEXT' WHEN [dormant_duration]>60000 THEN 'DORMANT_CONTEXT' ELSE 'INVENTORY_ONLY' END FROM [sys].[dm_exec_cursors](@TargetSessionId) ORDER BY [worker_time] DESC,[reads] DESC,[cursor_id];
   SET @Status=CASE WHEN EXISTS(SELECT 1 FROM [#CurrentCursorAnalysis_Cursors]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END;
 END TRY BEGIN CATCH SELECT @Status='SOURCE_UNAVAILABLE',@Partial=1,@ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(); END CATCH;
 IF @JsonErzeugen=1 SELECT @Json=COALESCE((SELECT * FROM [#CurrentCursorAnalysis_Cursors] ORDER BY [WorkerTime] DESC,[CursorId] FOR JSON PATH),N'[]');
 IF @Mode IN('CONSOLE','RAW') BEGIN SELECT @Status [StatusCode],@Partial [IsPartial],@TargetSessionId [SessionId],COUNT_BIG(*) [CursorCount],@ErrorMessage [ErrorMessage] FROM [#CurrentCursorAnalysis_Cursors]; IF @IncludeCursorDetails=1 SELECT * FROM [#CurrentCursorAnalysis_Cursors] ORDER BY [WorkerTime] DESC,[CursorId]; END;
 IF @PrintMeldungen=1 AND @Mode='NONE' PRINT CONCAT(N'Status: ',@Status);
 IF @TableResultRequested=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#CurrentCursorAnalysis_Cursors',@TargetTable=@TableTarget,@ThrowOnError=1;
 SET @RestoreLockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';'; EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql; SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;
END;
GO
