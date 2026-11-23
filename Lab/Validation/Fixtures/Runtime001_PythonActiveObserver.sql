SET NOCOUNT ON;

DECLARE @TargetDatabase sysname=N'ExampleExternalRuntimeProbe',@WorkerSession smallint,
        @ExternalRequest uniqueidentifier,@SqlRequest int,@Language nvarchar(128),@Parallelism int,
        @NativeRows int,@Json nvarchar(max),@Return int,@LockTimeoutBefore int=@@LOCK_TIMEOUT,
        @Deadline datetime2(3)=DATEADD(SECOND,35,SYSUTCDATETIME());

WHILE @ExternalRequest IS NULL AND SYSUTCDATETIME()<@Deadline
BEGIN
    SELECT @WorkerSession=[SessionId]
    FROM [ExampleExternalRuntimeProbe].[dbo].[ExampleActiveRuntimeSignal] WHERE [Id]=1 AND [Finished]=0;

    SELECT @ExternalRequest=e.[external_script_request_id],@SqlRequest=r.[request_id],
           @Language=e.[language],@Parallelism=e.[degree_of_parallelism]
    FROM sys.dm_external_script_requests AS e
    JOIN sys.dm_exec_requests AS r ON r.[external_script_request_id]=e.[external_script_request_id]
    WHERE r.[session_id]=@WorkerSession AND r.[database_id]=DB_ID(@TargetDatabase)
      AND e.[language] COLLATE Latin1_General_100_CI_AS=N'Python';
    SET @NativeRows=@@ROWCOUNT;
    IF @ExternalRequest IS NULL WAITFOR DELAY '00:00:00.250';
END;

IF @ExternalRequest IS NULL OR @NativeRows<>1
    THROW 56985,N'The observer did not resolve the owned active Python request.',1;

EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
     @DatabaseNames=@TargetDatabase,@LanguageNames=@Language,
     @MitSitzungskontext=0,@MaxZeilen=0,@ResultSetArt='NONE',@PrintMeldungen=0,
     @JsonErzeugen=1,@Json=@Json OUTPUT;

IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
    THROW 56986,N'Analyze did not return valid active-runtime evidence and preserve the caller lock timeout.',1;

SELECT [ExternalScriptRequestId],[LanguageName],[DegreeOfParallelism],[SessionId],[RequestId],[DatabaseName],
       [LoginName],[HostName],[ProgramName],[ExternalWorkerAccount]
INTO [#ExampleActivePythonRequest]
FROM OPENJSON(@Json,N'$.activeRequests') WITH
(
    [ExternalScriptRequestId] uniqueidentifier,[LanguageName] nvarchar(128),[DegreeOfParallelism] int,
    [SessionId] smallint,[RequestId] int,[DatabaseName] sysname,
    [LoginName] sysname,[HostName] sysname,[ProgramName] nvarchar(128),[ExternalWorkerAccount] nvarchar(256)
)
WHERE [ExternalScriptRequestId]=@ExternalRequest;

IF (SELECT COUNT(*) FROM [#ExampleActivePythonRequest])<>1
   OR EXISTS(
        SELECT [LanguageName] COLLATE Latin1_General_100_BIN2,[DegreeOfParallelism],[SessionId],[RequestId],
               [DatabaseName] COLLATE Latin1_General_100_BIN2
        FROM [#ExampleActivePythonRequest]
        EXCEPT
        SELECT @Language COLLATE Latin1_General_100_BIN2,@Parallelism,@WorkerSession,@SqlRequest,
               @TargetDatabase COLLATE Latin1_General_100_BIN2)
   OR EXISTS(SELECT 1 FROM [#ExampleActivePythonRequest] WHERE [LoginName] IS NOT NULL OR [HostName] IS NOT NULL
             OR [ProgramName] IS NOT NULL OR [ExternalWorkerAccount] IS NOT NULL)
   OR (SELECT COUNT(*) FROM OPENJSON(@Json,N'$.sourceStatus') WITH
       ([SourceCode] varchar(80),[StatusCode] varchar(40),[IsPartial] bit,[RowCount] bigint)
       WHERE [SourceCode]='ACTIVE_EXTERNAL_REQUESTS' AND [StatusCode]='AVAILABLE' AND [IsPartial]=0 AND [RowCount]>=1)<>1
    THROW 56987,N'Analyze active-request identity, source status or caller metadata boundary differs.',1;

SET @Deadline=DATEADD(SECOND,40,SYSUTCDATETIME());
WHILE SYSUTCDATETIME()<@Deadline AND (
    NOT EXISTS(SELECT 1 FROM [ExampleExternalRuntimeProbe].[dbo].[ExampleActiveRuntimeSignal] WHERE [Id]=1 AND [Finished]=1)
    OR EXISTS(SELECT 1 FROM sys.dm_external_script_requests WHERE [external_script_request_id]=@ExternalRequest))
    WAITFOR DELAY '00:00:00.250';

IF NOT EXISTS(SELECT 1 FROM [ExampleExternalRuntimeProbe].[dbo].[ExampleActiveRuntimeSignal] WHERE [Id]=1 AND [Finished]=1)
   OR EXISTS(SELECT 1 FROM sys.dm_external_script_requests WHERE [external_script_request_id]=@ExternalRequest)
    THROW 56988,N'The owned Python request did not finish and disappear from the native DMV.',1;

SET @Json=NULL;
EXEC @Return=[monitor].[USP_ExternalRuntimeAnalysis]
     @DatabaseNames=@TargetDatabase,@LanguageNames=@Language,
     @MitSitzungskontext=0,@MaxZeilen=0,@ResultSetArt='NONE',@PrintMeldungen=0,
     @JsonErzeugen=1,@Json=@Json OUTPUT;

IF ISNULL(@Return,-1)<>0 OR ISNULL(ISJSON(@Json),0)<>1 OR @@LOCK_TIMEOUT<>@LockTimeoutBefore
   OR JSON_QUERY(@Json,N'$.activeRequests') IS NULL
   OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.activeRequests') WITH ([ExternalScriptRequestId] uniqueidentifier)
             WHERE [ExternalScriptRequestId]=@ExternalRequest)
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.sourceStatus') WITH
                 ([SourceCode] varchar(80),[StatusCode] varchar(40),[IsPartial] bit)
                 WHERE [SourceCode]='ACTIVE_EXTERNAL_REQUESTS' AND [StatusCode]='AVAILABLE' AND [IsPartial]=0)
    THROW 56989,N'The completed Python request was still visible or the source was unavailable.',1;
GO
