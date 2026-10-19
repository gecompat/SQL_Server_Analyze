USE [DeineDatenbank];
GO
-- New L1-L9 lifecycle contracts; synthetic source only. No SSIS package execution.
DECLARE @DbId int=DB_ID(),@OuterOptions int=@@OPTIONS,@OuterLock int=@@LOCK_TIMEOUT,@OuterTran int=@@TRANCOUNT;
IF OBJECT_ID(N'dbo.ExampleLifecycleLogSource') IS NOT NULL OR OBJECT_ID(N'dbo.ExampleLifecycleFixtureScope') IS NOT NULL OR OBJECT_ID(N'tempdb..#ExampleLifecycleOwnership') IS NOT NULL OR DATABASE_PRINCIPAL_ID(N'ExampleLifecycleReader') IS NOT NULL THROW 56890,N'L_SOURCE_COLLISION',1;
CREATE TABLE #ExampleLifecycleOwnership(TableId int NULL,UserId int NULL);INSERT #ExampleLifecycleOwnership VALUES(NULL,NULL);
DECLARE @OwnershipId int=OBJECT_ID(N'tempdb..#ExampleLifecycleOwnership'),@TableId int,@ProcId int;
BEGIN TRY
 EXEC(N'CREATE PROCEDURE dbo.ExampleLifecycleFixtureScope @OwnedTableId int OUTPUT AS BEGIN

SET NOCOUNT ON;
DECLARE @Db sysname=DB_NAME(),@Id uniqueidentifier=NEWID(),@A uniqueidentifier=NEWID(),@B uniqueidentifier=NEWID(),@T datetime=''20000101'';
DECLARE @InitialOptions int=@@OPTIONS,@InitialLock int=@@LOCK_TIMEOUT,@InitialTran int=@@TRANCOUNT;
CREATE TABLE dbo.ExampleLifecycleLogSource(id int NOT NULL,event nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,source nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,sourceid uniqueidentifier NULL,executionid uniqueidentifier NULL,starttime datetime NULL,endtime datetime NULL,datacode int NULL,message nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
SET @OwnedTableId=OBJECT_ID(N''dbo.ExampleLifecycleLogSource'');UPDATE #ExampleLifecycleOwnership SET TableId=@OwnedTableId;
DECLARE @CallSeq int=0;
DECLARE @J nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(4000);
-- L-S01: all sixteen flag combinations, including invalid dependency before source reads.
DECLARE @F int=0,@Task bit,@Row bit,@Phase bit,@Life bit,@ExpectedVersion int;
WHILE @F<16
BEGIN
 SELECT @Task=CONVERT(bit,@F&1),@Row=CONVERT(bit,@F&2),@Phase=CONVERT(bit,@F&4),@Life=CONVERT(bit,@F&8);
 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
 EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeTaskAnalysis=@Task,@IncludeRowFlowAnalysis=@Row,@IncludeComponentPhaseAnalysis=@Phase,@IncludeComponentLifecyclePhases=@Life,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@PrintMeldungen=0,@IsPartialOut=@Partial OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
 IF ISNULL(ISJSON(@J),0)<>1 THROW 56824,N''L_CAPTURE_JSON_INVALID'',1;
 IF @Phase=1 OR @CallSeq>16 BEGIN IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseEvents'' AND [type]=4) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseTimes'' AND [type]=4) THROW 56827,N''L_ARRAY_TYPES'',1; END;
 IF @Life=1 AND @Phase=0
 BEGIN
  IF ISNULL(@Status,'''')<>''INVALID_PARAMETER'' OR EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.StatusCode'')<>''NOT_READ'') THROW 56801,N''L_S01_DEPENDENCY'',1;
 END
 ELSE
 BEGIN
  SET @ExpectedVersion=CASE WHEN @Life=1 THEN 5 WHEN @Phase=1 THEN 4 WHEN @Row=1 THEN 3 WHEN @Task=1 THEN 2 ELSE 1 END;
  IF @J IS NULL OR @Error IS NOT NULL OR @Status=''INVALID_PARAMETER'' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@J,''$.meta.SchemaVersion'')),-1)<>@ExpectedVersion THROW 56802,N''L_S01_VERSION'',1;
  IF @Phase=1 AND ISNULL(TRY_CONVERT(int,JSON_VALUE(@J,''$.meta.ComponentPhaseCatalogVersion'')),-1)<>CASE WHEN @Life=1 THEN 2 ELSE 1 END THROW 56803,N''L_S01_CATALOG'',1;
 END;
 SET @F+=1;
END;
 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeComponentPhaseAnalysis=1,@IncludeComponentLifecyclePhases=NULL,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
 IF ISNULL(ISJSON(@J),0)<>1 THROW 56824,N''L_CAPTURE_JSON_INVALID'',1;
 IF @Phase=1 OR @CallSeq>16 BEGIN IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseEvents'' AND [type]=4) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseTimes'' AND [type]=4) THROW 56827,N''L_ARRAY_TYPES'',1; END;
IF ISNULL(JSON_VALUE(@J,''$.meta.SchemaVersion''),N'''')<>N''4'' OR ISNULL(JSON_VALUE(@J,''$.meta.ComponentPhaseCatalogVersion''),N'''')<>N''1'' THROW 56804,N''L_S01_NULL'',1;
 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @Hilfe=1,@IncludeComponentLifecyclePhases=1,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
IF NOT EXISTS(SELECT 1 FROM sys.parameters WHERE object_id=OBJECT_ID(N''monitor.USP_SsisLegacyLogAnalysis'') AND parameter_id=24 AND name COLLATE SQL_Latin1_General_CP1_CS_AS=N''@IncludeComponentLifecyclePhases'') THROW 56805,N''L_S01_POSITION'',1;
CREATE TABLE #ExampleLifecycleCases(CaseId int,Label nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS,EventName nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,TextValue nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS,Parser varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS,ParseStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,Method varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS,Ms bigint,ComponentId int,OutputName nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS,Life bit,ContextStatus varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS);
INSERT #ExampleLifecycleCases VALUES
(1,N''Validate'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in Validate.'',N''PCT_EN_3'',N''PARSED'',N''Validate'',7,NULL,NULL,1,N''ASSIGNED''),
(2,N''PreExecute'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in PreExecute.'',N''PCT_EN_3'',N''PARSED'',N''PreExecute'',7,NULL,NULL,1,N''ASSIGNED''),
(3,N''PostExecute'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in PostExecute.'',N''PCT_EN_3'',N''PARSED'',N''PostExecute'',7,NULL,NULL,1,N''ASSIGNED''),
(4,N''ProcessInput'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in ProcessInput.'',N''PCT_EN_3'',N''PARSED'',N''ProcessInput'',7,NULL,NULL,1,N''ASSIGNED''),
(5,N''Prime'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in PrimeOutput filling buffers on ExampleComponent.Outputs[ExampleOutput].'',N''PCT_EN_3'',N''PARSED'',N''PrimeOutput'',7,NULL,N''ExampleOutput'',1,N''ASSIGNED''),
(6,N''Zero'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 0 milliseconds in Validate.'',N''PCT_EN_3'',N''PARSED'',N''Validate'',0,NULL,NULL,1,N''ASSIGNED''),
(7,N''Max'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 9223372036854775807 milliseconds in PostExecute.'',N''PCT_EN_3'',N''PARSED'',N''PostExecute'',9223372036854775807,NULL,NULL,1,N''ASSIGNED''),
(8,N''EN1'',N''PipelineComponentTime'',N''The component "ExampleComponent" (1) spent 7 milliseconds in ProcessInput.'',N''PCT_EN_1'',N''PARSED'',N''ProcessInput'',7,1,NULL,1,N''ASSIGNED''),
(9,N''Default'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in Validate.'',N''PCT_EN_2'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,0,N''NOT_PARSED''),
(10,N''Unknown'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in AcquireConnections.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(11,N''Case'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(12,N''Prefix'',N''User:PipelineComponentTime'',N'' The ExampleComponent spent 7 milliseconds in Validate.'',NULL,N''UNSUPPORTED_FORMAT'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(13,N''Suffix'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in Validate. '',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(14,N''Negative'',N''User:PipelineComponentTime'',N''The ExampleComponent spent -1 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(15,N''LeadingZero'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 01 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(16,N''Decimal'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 1.0 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(17,N''Exponent'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 1e3 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(18,N''Overflow'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 9223372036854775808 milliseconds in Validate.'',N''PCT_EN_3'',N''NUMERIC_OUT_OF_RANGE'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(19,N''OpenBracket'',N''User:PipelineComponentTime'',N''The Example[Component spent 7 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(20,N''Quote'',N''User:PipelineComponentTime'',N''The Example"Component spent 7 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(21,N''RepeatedDelimiter'',N''User:PipelineComponentTime'',N''The Example spent Component spent 7 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(22,N''Localized'',N''User:PipelineComponentTime'',N''Die ExampleComponent spent 7 milliseconds in Validate.'',NULL,N''UNSUPPORTED_FORMAT'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(23,N''NullMessage'',N''User:PipelineComponentTime'',NULL,NULL,N''MESSAGE_MISSING'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(24,N''SuffixNul'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in Validate.''+NCHAR(0)+N'''',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(25,N''CR'',N''User:PipelineComponentTime'',N''The Example''+NCHAR(13)+N''Component spent 7 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(26,N''LF'',N''User:PipelineComponentTime'',N''The Example''+NCHAR(10)+N''Component spent 7 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(27,N''TAB'',N''User:PipelineComponentTime'',N''The Example''+NCHAR(9)+N''Component spent 7 milliseconds in Validate.'',N''PCT_EN_3'',N''MALFORMED_PAYLOAD'',NULL,NULL,NULL,NULL,1,N''NOT_PARSED''),
(28,N''MissingSource'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in PreExecute.'',N''PCT_EN_3'',N''PARSED'',N''PreExecute'',7,NULL,NULL,1,N''SOURCE_ID_MISSING''),
(29,N''MissingTime'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in PostExecute.'',N''PCT_EN_3'',N''PARSED'',N''PostExecute'',7,NULL,NULL,1,N''EVENT_TIME_MISSING''),
(30,N''MissingValidate'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in Validate.'',N''PCT_EN_3'',N''PARSED'',N''Validate'',7,NULL,NULL,1,N''NO_OBSERVED_PAIR''),
(31,N''LateValidate'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in Validate.'',N''PCT_EN_3'',N''PARSED'',N''Validate'',7,NULL,NULL,1,N''NO_OBSERVED_PAIR''),
(32,N''MissingExecute'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in PreExecute.'',N''PCT_EN_3'',N''PARSED'',N''PreExecute'',7,NULL,NULL,1,N''NO_OBSERVED_PAIR''),
(33,N''TimeOutside'',N''User:PipelineComponentTime'',N''The ExampleComponent spent 7 milliseconds in PreExecute.'',N''PCT_EN_3'',N''PARSED'',N''PreExecute'',7,NULL,NULL,1,N''TIME_OUTSIDE_PAIR'');
DECLARE @C int=1,@Label nvarchar(64),@Event nvarchar(128),@Text nvarchar(2048),@Parser varchar(32),@ParseStatus varchar(40),@Method varchar(32),@Ms bigint,@Cid int,@Output nvarchar(4000),@Context varchar(40);
WHILE @C<=33
BEGIN
 SELECT @Label=Label,@Event=EventName,@Text=TextValue,@Parser=Parser,@ParseStatus=ParseStatus,@Method=Method,@Ms=Ms,@Cid=ComponentId,@Output=OutputName,@Life=Life,@Context=ContextStatus FROM #ExampleLifecycleCases WHERE CaseId=@C;
 TRUNCATE TABLE dbo.ExampleLifecycleLogSource;
 INSERT dbo.ExampleLifecycleLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,@T,NULL),(2,N''OnPreValidate'',N''ExampleFlow'',@A,@Id,@T,NULL),(3,@Event,N''ExampleFlow'',CASE WHEN @Label=N''MissingSource'' THEN NULL ELSE @A END,@Id,CASE WHEN @Label=N''MissingTime'' THEN NULL WHEN @Label=N''TimeOutside'' THEN DATEADD(second,-1,@T) ELSE @T END,@Text),(4,N''OnPostValidate'',N''ExampleFlow'',@A,@Id,@T,NULL),(5,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,@T,NULL);
 IF @Label=N''MissingValidate'' DELETE dbo.ExampleLifecycleLogSource WHERE id=4;
 IF @Label=N''LateValidate'' UPDATE dbo.ExampleLifecycleLogSource SET id=6 WHERE id=3;
 IF @Label=N''MissingExecute'' DELETE dbo.ExampleLifecycleLogSource WHERE id=5;
 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
 EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeComponentPhaseAnalysis=1,@IncludeComponentLifecyclePhases=@Life,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@PrintMeldungen=0,@IsPartialOut=@Partial OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
 IF ISNULL(ISJSON(@J),0)<>1 THROW 56824,N''L_CAPTURE_JSON_INVALID'',1;
 IF @Phase=1 OR @CallSeq>16 BEGIN IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseEvents'' AND [type]=4) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseTimes'' AND [type]=4) THROW 56827,N''L_ARRAY_TYPES'',1; END;
 SELECT N''L-Case'' AS CaptureLabel,@Label AS CaseLabel,@J AS CaptureJson,@Error AS OutputError;
 IF @Error IS NOT NULL OR @J IS NULL OR (SELECT COUNT(*) FROM OPENJSON(@J,''$.componentPhaseEvents''))<>1 THROW 56806,N''L_CASE_BUFFER'',1;
 IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J,''$.componentPhaseEvents'') WITH(ParserId varchar(32),ParseStatus varchar(40),ComponentId int,ComponentName nvarchar(4000),PhaseName varchar(32),ReportedDurationMs bigint,OutputId int,OutputName nvarchar(4000),ContextStatus varchar(40),ContextStartLogId int,ContextEndLogId int) e
 WHERE e.ParseStatus=@ParseStatus AND e.ContextStatus=@Context AND ((e.ParserId=@Parser) OR(e.ParserId IS NULL AND @Parser IS NULL)) AND ((e.PhaseName=@Method) OR(e.PhaseName IS NULL AND @Method IS NULL)) AND ((e.ReportedDurationMs=@Ms) OR(e.ReportedDurationMs IS NULL AND @Ms IS NULL)) AND ((e.ComponentId=@Cid) OR(e.ComponentId IS NULL AND @Cid IS NULL)) AND ((CONVERT(varbinary(max),e.OutputName)=CONVERT(varbinary(max),@Output)) OR(e.OutputName IS NULL AND @Output IS NULL)) AND e.OutputId IS NULL
 AND ((@ParseStatus=''PARSED'' AND e.ComponentName=N''ExampleComponent'') OR(@ParseStatus<>''PARSED'' AND e.ComponentName IS NULL))
 AND ((@Context=''ASSIGNED'' AND e.ContextStartLogId=CASE WHEN @Method=''Validate'' THEN 2 ELSE 1 END AND e.ContextEndLogId=CASE WHEN @Method=''Validate'' THEN 4 ELSE 5 END) OR(@Context<>''ASSIGNED'' AND e.ContextStartLogId IS NULL AND e.ContextEndLogId IS NULL)))
 BEGIN SELECT @Label AS FailedCase;THROW 56807,N''L_CASE_EXACT_PAYLOAD_CONTEXT'',1;END;
 IF (SELECT COUNT(*) FROM OPENJSON(@J,''$.componentPhaseEvents[0]''))<>18 OR (SELECT COUNT(*) FROM OPENJSON(@J,''$.componentPhaseTimes''))<>CASE WHEN @Context=''ASSIGNED'' THEN 1 ELSE 0 END THROW 56808,N''L_CASE_SCHEMA_OR_GROUP'',1;
 IF @Context=''ASSIGNED'' AND NOT EXISTS(SELECT 1 FROM OPENJSON(@J,''$.componentPhaseTimes'') WITH(EventCount bigint,ReportedDurationSumMs decimal(38,0),MinReportedDurationMs bigint,MaxReportedDurationMs bigint,AvgReportedDurationMs decimal(38,6),ComponentName nvarchar(4000),PhaseName varchar(32),ComponentId int,OutputId int,OutputName nvarchar(4000),EvidenceLogIdsJson nvarchar(max),SourceNameConflict bit,ComponentNameConflict bit,OutputNameConflict bit,InputIsTruncated bit,CoverageStatus varchar(40)) g WHERE EventCount=1 AND ReportedDurationSumMs=CONVERT(decimal(38,0),@Ms) AND MinReportedDurationMs=@Ms AND MaxReportedDurationMs=@Ms AND AvgReportedDurationMs=CONVERT(decimal(38,6),@Ms) AND ComponentName=N''ExampleComponent'' AND PhaseName=@Method AND ((ComponentId=@Cid) OR(ComponentId IS NULL AND @Cid IS NULL)) AND OutputId IS NULL AND ((CONVERT(varbinary(max),OutputName)=CONVERT(varbinary(max),@Output)) OR(OutputName IS NULL AND @Output IS NULL)) AND EvidenceLogIdsJson=N''[3]'' AND SourceNameConflict=0 AND ComponentNameConflict=0 AND OutputNameConflict=0 AND InputIsTruncated=0 AND CoverageStatus=''OBSERVED_REPORTS'') THROW 56809,N''L_CASE_EXACT_AGGREGATE'',1;
 SET @C+=1;
END;
-- L-S05/06/08/09: separate repeated VALIDATE contexts, binary names, source identity and exact half-up aggregate.
TRUNCATE TABLE dbo.ExampleLifecycleLogSource;
INSERT dbo.ExampleLifecycleLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES
(1,N''OnPreExecute'',N''ExampleFlow'',@A,@Id,@T,NULL),(2,N''OnPreValidate'',N''ExampleFlow'',@A,@Id,@T,NULL),
(3,N''User:PipelineComponentTime'',N''ExampleFlow'',@A,@Id,@T,N''The ExampleComponent spent 3 milliseconds in Validate.''),
(4,N''User:PipelineComponentTime'',N''ExampleFlow'',@A,@Id,@T,N''The ExampleComponent spent 4 milliseconds in Validate.''),
(5,N''User:PipelineComponentTime'',N''ExampleFlow'',@A,@Id,@T,N''The ExampleComponent spent 4 milliseconds in Validate.''),
(6,N''OnPostValidate'',N''ExampleFlow'',@A,@Id,@T,NULL),(7,N''OnPreValidate'',N''ExampleFlow'',@A,@Id,@T,NULL),
(8,N''User:PipelineComponentTime'',N''ExampleFlow'',@A,@Id,@T,N''The ExampleComponent spent 0 milliseconds in Validate.''),
(9,N''OnPostValidate'',N''ExampleFlow'',@A,@Id,@T,NULL),
(10,N''User:PipelineComponentTime'',N''ExampleFlow'',@A,@Id,@T,N''The ExampleComponent  spent 7 milliseconds in PreExecute.''),
(11,N''User:PipelineComponentTime'',N''ExampleFlow'',@A,@Id,@T,N''The ExampleComponent spent 7 milliseconds in PreExecute.''),
(12,N''OnPreExecute'',N''ExampleFlow'',@B,@Id,@T,NULL),(13,N''User:PipelineComponentTime'',N''ExampleFlow'',@B,@Id,@T,N''The ExampleComponent spent 7 milliseconds in PostExecute.''),(14,N''OnPostExecute'',N''ExampleFlow'',@B,@Id,@T,NULL),(15,N''OnPostExecute'',N''ExampleFlow'',@A,@Id,@T,NULL);
CREATE TABLE #ExampleLifecycleEvents(Seed int NULL);CREATE TABLE #ExampleLifecycleTimes(Seed int NULL);
 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeComponentPhaseAnalysis=1,@IncludeComponentLifecyclePhases=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''TABLE'',@ResultTablesJson=N''{"componentPhaseEvents":"#ExampleLifecycleEvents","componentPhaseTimes":"#ExampleLifecycleTimes"}'',@JsonErzeugen=1,@Json=@J OUTPUT,@ErrorNumberOut=@Error OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
 IF ISNULL(ISJSON(@J),0)<>1 THROW 56824,N''L_CAPTURE_JSON_INVALID'',1;
 IF @Phase=1 OR @CallSeq>16 BEGIN IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseEvents'' AND [type]=4) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseTimes'' AND [type]=4) THROW 56827,N''L_ARRAY_TYPES'',1; END;
EXEC sys.sp_executesql N''
IF (SELECT COUNT(*) FROM #ExampleLifecycleTimes)<>5 OR NOT EXISTS(SELECT 1 FROM #ExampleLifecycleTimes WHERE ContextStartLogId=2 AND ContextEndLogId=6 AND PhaseName=''''Validate'''' AND EventCount=3 AND ReportedDurationSumMs=11 AND AvgReportedDurationMs=3.666667 AND EvidenceLogIdsJson=N''''[3,4,5]'''') THROW 56810,N''''L_GROUP_CONTEXT_ROUNDING'''',1;
IF (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id IN(OBJECT_ID(N''''tempdb..#ExampleLifecycleEvents''''),OBJECT_ID(N''''tempdb..#ExampleLifecycleTimes'''')))<>42 THROW 56811,N''''L_PHYSICAL_COLUMN_COUNT'''',1;
IF EXISTS(SELECT 1 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N''''tempdb..#ExampleLifecycleTimes'''') AND name=N''''ComponentId'''' AND (is_nullable<>1 OR TYPE_NAME(system_type_id)<>N''''int'''')) THROW 56812,N''''L_PHYSICAL_NULL_ID'''',1;
IF EXISTS(SELECT * FROM #ExampleLifecycleEvents EXCEPT SELECT * FROM OPENJSON(@P,''''$.componentPhaseEvents'''') WITH(PhaseEventOrdinal bigint,ExecutionId uniqueidentifier,LogId int,SourceId uniqueidentifier,SourceName nvarchar(4000),EventTime datetime,ParserId varchar(32),ParseStatus varchar(40),ComponentId int,ComponentName nvarchar(4000),PhaseName varchar(32),ReportedDurationMs bigint,OutputId int,OutputName nvarchar(4000),ContextStartLogId int,ContextEndLogId int,ContextStatus varchar(40),InputIsTruncated bit)) OR EXISTS(SELECT * FROM OPENJSON(@P,''''$.componentPhaseEvents'''') WITH(PhaseEventOrdinal bigint,ExecutionId uniqueidentifier,LogId int,SourceId uniqueidentifier,SourceName nvarchar(4000),EventTime datetime,ParserId varchar(32),ParseStatus varchar(40),ComponentId int,ComponentName nvarchar(4000),PhaseName varchar(32),ReportedDurationMs bigint,OutputId int,OutputName nvarchar(4000),ContextStartLogId int,ContextEndLogId int,ContextStatus varchar(40),InputIsTruncated bit) EXCEPT SELECT * FROM #ExampleLifecycleEvents) THROW 56823,N''''L_ALL_FIELD_PARITY'''',1;
IF EXISTS(SELECT * FROM #ExampleLifecycleTimes EXCEPT SELECT * FROM OPENJSON(@P,''''$.componentPhaseTimes'''') WITH(PhaseTimeOrdinal bigint,ExecutionId uniqueidentifier,SourceId uniqueidentifier,SourceName nvarchar(4000),ContextStartLogId int,ContextEndLogId int,ComponentId int,ComponentName nvarchar(4000),PhaseName varchar(32),OutputId int,OutputName nvarchar(4000),EventCount bigint,ReportedDurationSumMs decimal(38,0),MinReportedDurationMs bigint,MaxReportedDurationMs bigint,AvgReportedDurationMs decimal(38,6),FirstObservedTime datetime,LastObservedTime datetime,EvidenceLogIdsJson nvarchar(max),SourceNameConflict bit,ComponentNameConflict bit,OutputNameConflict bit,InputIsTruncated bit,CoverageStatus varchar(40))) OR EXISTS(SELECT * FROM OPENJSON(@P,''''$.componentPhaseTimes'''') WITH(PhaseTimeOrdinal bigint,ExecutionId uniqueidentifier,SourceId uniqueidentifier,SourceName nvarchar(4000),ContextStartLogId int,ContextEndLogId int,ComponentId int,ComponentName nvarchar(4000),PhaseName varchar(32),OutputId int,OutputName nvarchar(4000),EventCount bigint,ReportedDurationSumMs decimal(38,0),MinReportedDurationMs bigint,MaxReportedDurationMs bigint,AvgReportedDurationMs decimal(38,6),FirstObservedTime datetime,LastObservedTime datetime,EvidenceLogIdsJson nvarchar(max),SourceNameConflict bit,ComponentNameConflict bit,OutputNameConflict bit,InputIsTruncated bit,CoverageStatus varchar(40)) EXCEPT SELECT * FROM #ExampleLifecycleTimes) THROW 56823,N''''L_ALL_FIELD_PARITY'''',1;
SELECT * FROM #ExampleLifecycleEvents ORDER BY PhaseEventOrdinal;SELECT * FROM #ExampleLifecycleTimes ORDER BY PhaseTimeOrdinal;'',N''@P nvarchar(max)'',@P=@J;
EXEC sys.sp_executesql N''
SELECT ROW_NUMBER() OVER(ORDER BY v.LogId) AS PhaseEventOrdinal,@Id AS ExecutionId,v.LogId,v.SourceId,N''''ExampleFlow'''' AS SourceName,@T AS EventTime,CONVERT(varchar(32),''''PCT_EN_3'''') AS ParserId,CONVERT(varchar(40),''''PARSED'''') AS ParseStatus,CONVERT(int,NULL) AS ComponentId,v.ComponentName,v.PhaseName,CONVERT(bigint,v.Ms) AS ReportedDurationMs,CONVERT(int,NULL) AS OutputId,CONVERT(nvarchar(4000),NULL) AS OutputName,v.StartId AS ContextStartLogId,v.EndId AS ContextEndLogId,CONVERT(varchar(40),''''ASSIGNED'''') AS ContextStatus,CONVERT(bit,0) AS InputIsTruncated
INTO #ExampleLifecycleExpectedEvents
FROM(VALUES(3,@A,N''''ExampleComponent'''',''''Validate'''',3,2,6),(4,@A,N''''ExampleComponent'''',''''Validate'''',4,2,6),(5,@A,N''''ExampleComponent'''',''''Validate'''',4,2,6),(8,@A,N''''ExampleComponent'''',''''Validate'''',0,7,9),(10,@A,N''''ExampleComponent '''',''''PreExecute'''',7,1,15),(11,@A,N''''ExampleComponent'''',''''PreExecute'''',7,1,15),(13,@B,N''''ExampleComponent'''',''''PostExecute'''',7,12,14)) v(LogId,SourceId,ComponentName,PhaseName,Ms,StartId,EndId);
SELECT ROW_NUMBER() OVER(ORDER BY v.SourceId,v.StartId,v.EndId,v.PhaseName COLLATE Latin1_General_100_BIN2,CONVERT(varbinary(8000),v.ComponentName)) AS PhaseTimeOrdinal,@Id AS ExecutionId,v.SourceId,N''''ExampleFlow'''' AS SourceName,v.StartId AS ContextStartLogId,v.EndId AS ContextEndLogId,CONVERT(int,NULL) AS ComponentId,v.ComponentName,v.PhaseName,CONVERT(int,NULL) AS OutputId,CONVERT(nvarchar(4000),NULL) AS OutputName,CONVERT(bigint,v.N) AS EventCount,CONVERT(decimal(38,0),v.SumMs) AS ReportedDurationSumMs,CONVERT(bigint,v.MinMs) AS MinReportedDurationMs,CONVERT(bigint,v.MaxMs) AS MaxReportedDurationMs,CONVERT(decimal(38,6),v.AvgMs) AS AvgReportedDurationMs,@T AS FirstObservedTime,@T AS LastObservedTime,v.Ids AS EvidenceLogIdsJson,CONVERT(bit,0) AS SourceNameConflict,CONVERT(bit,0) AS ComponentNameConflict,CONVERT(bit,0) AS OutputNameConflict,CONVERT(bit,0) AS InputIsTruncated,CONVERT(varchar(40),''''OBSERVED_REPORTS'''') AS CoverageStatus
INTO #ExampleLifecycleExpectedTimes
FROM(VALUES(@A,2,6,N''''ExampleComponent'''',''''Validate'''',3,11,3,4,CONVERT(decimal(38,6),3.666667),N''''[3,4,5]''''),(@A,7,9,N''''ExampleComponent'''',''''Validate'''',1,0,0,0,CONVERT(decimal(38,6),0),N''''[8]''''),(@A,1,15,N''''ExampleComponent '''',''''PreExecute'''',1,7,7,7,CONVERT(decimal(38,6),7),N''''[10]''''),(@A,1,15,N''''ExampleComponent'''',''''PreExecute'''',1,7,7,7,CONVERT(decimal(38,6),7),N''''[11]''''),(@B,12,14,N''''ExampleComponent'''',''''PostExecute'''',1,7,7,7,CONVERT(decimal(38,6),7),N''''[13]'''')) v(SourceId,StartId,EndId,ComponentName,PhaseName,N,SumMs,MinMs,MaxMs,AvgMs,Ids);
IF (SELECT COUNT(*) FROM #ExampleLifecycleEvents)<>7 OR EXISTS(SELECT * FROM #ExampleLifecycleEvents EXCEPT SELECT * FROM #ExampleLifecycleExpectedEvents) OR EXISTS(SELECT * FROM #ExampleLifecycleExpectedEvents EXCEPT SELECT * FROM #ExampleLifecycleEvents) THROW 56825,N''''L_ALL_EVENT_EXPECTATIONS'''',1;
IF (SELECT COUNT(*) FROM #ExampleLifecycleTimes)<>5 OR EXISTS(SELECT * FROM #ExampleLifecycleTimes EXCEPT SELECT * FROM #ExampleLifecycleExpectedTimes) OR EXISTS(SELECT * FROM #ExampleLifecycleExpectedTimes EXCEPT SELECT * FROM #ExampleLifecycleTimes) THROW 56826,N''''L_ALL_GROUP_EXPECTATIONS'''',1;
IF EXISTS(SELECT 1 FROM #ExampleLifecycleEvents a JOIN #ExampleLifecycleExpectedEvents e ON a.PhaseEventOrdinal=e.PhaseEventOrdinal WHERE (a.SourceName IS NULL AND e.SourceName IS NOT NULL OR a.SourceName IS NOT NULL AND e.SourceName IS NULL OR CONVERT(varbinary(max),a.SourceName)<>CONVERT(varbinary(max),e.SourceName)) OR (a.ComponentName IS NULL AND e.ComponentName IS NOT NULL OR a.ComponentName IS NOT NULL AND e.ComponentName IS NULL OR CONVERT(varbinary(max),a.ComponentName)<>CONVERT(varbinary(max),e.ComponentName)) OR (a.OutputName IS NULL AND e.OutputName IS NOT NULL OR a.OutputName IS NOT NULL AND e.OutputName IS NULL OR CONVERT(varbinary(max),a.OutputName)<>CONVERT(varbinary(max),e.OutputName))) THROW 56829,N''''L_EXPECTED_ORDINAL_BINARY_NAMES'''',1;
IF EXISTS(SELECT 1 FROM #ExampleLifecycleTimes a JOIN #ExampleLifecycleExpectedTimes e ON a.PhaseTimeOrdinal=e.PhaseTimeOrdinal WHERE (a.SourceName IS NULL AND e.SourceName IS NOT NULL OR a.SourceName IS NOT NULL AND e.SourceName IS NULL OR CONVERT(varbinary(max),a.SourceName)<>CONVERT(varbinary(max),e.SourceName)) OR (a.ComponentName IS NULL AND e.ComponentName IS NOT NULL OR a.ComponentName IS NOT NULL AND e.ComponentName IS NULL OR CONVERT(varbinary(max),a.ComponentName)<>CONVERT(varbinary(max),e.ComponentName)) OR (a.OutputName IS NULL AND e.OutputName IS NOT NULL OR a.OutputName IS NOT NULL AND e.OutputName IS NULL OR CONVERT(varbinary(max),a.OutputName)<>CONVERT(varbinary(max),e.OutputName))) THROW 56829,N''''L_EXPECTED_ORDINAL_BINARY_NAMES'''',1;
DROP TABLE #ExampleLifecycleExpectedEvents;DROP TABLE #ExampleLifecycleExpectedTimes;
'',N''@Id uniqueidentifier,@A uniqueidentifier,@B uniqueidentifier,@T datetime'',@Id=@Id,@A=@A,@B=@B,@T=@T;
IF (SELECT COUNT(*) FROM OPENJSON(@J,''$.componentPhaseTimes''))<>5 OR (SELECT COUNT(*) FROM OPENJSON(@J,''$.componentPhaseTimes[0]''))<>24 THROW 56814,N''L_GROUP_JSON_SCHEMA'',1;
-- L-S12: new lifecycle RAW13 combination; the capture adapter counts between markers.
SELECT N''L-RAW13-Begin'' AS CaptureLabel;
SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeTaskAnalysis=1,@IncludeComponentPhaseAnalysis=1,@IncludeComponentLifecyclePhases=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''RAW'',@JsonErzeugen=1,@Json=@J OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@PrintMeldungen=0;
SELECT N''L-RAW13-End'' AS CaptureLabel,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
IF ISNULL(ISJSON(@J),0)<>1 OR @Error IS NOT NULL OR ISNULL(JSON_VALUE(@J,''$.meta.SchemaVersion''),N'''')<>N''5'' THROW 56828,N''L_RAW13_STATUS'',1;
-- L-S10/11: no messages, bounded prefix, duplicate ID and possible-capacity truncation.
 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeComponentPhaseAnalysis=1,@IncludeComponentLifecyclePhases=1,@IncludeMessages=0,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
 IF ISNULL(ISJSON(@J),0)<>1 THROW 56824,N''L_CAPTURE_JSON_INVALID'',1;
 IF @Phase=1 OR @CallSeq>16 BEGIN IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseEvents'' AND [type]=4) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseTimes'' AND [type]=4) THROW 56827,N''L_ARRAY_TYPES'',1; END;
IF ISNULL(JSON_QUERY(@J,''$.componentPhaseEvents''),N''MISSING'')<>N''[]'' OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J,''$.sourceStatus'') WHERE JSON_VALUE(value,''$.SourceOrdinal'')=N''7'' AND JSON_VALUE(value,''$.Detail'')=N''MESSAGES_DISABLED'' AND JSON_VALUE(value,''$.ObservedRowCount'') IS NULL) THROW 56815,N''L_MESSAGES_DISABLED'',1;
 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeComponentPhaseAnalysis=1,@IncludeComponentLifecyclePhases=1,@MaxZeilen=3,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
 IF ISNULL(ISJSON(@J),0)<>1 THROW 56824,N''L_CAPTURE_JSON_INVALID'',1;
 IF @Phase=1 OR @CallSeq>16 BEGIN IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseEvents'' AND [type]=4) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseTimes'' AND [type]=4) THROW 56827,N''L_ARRAY_TYPES'',1; END;
IF ISNULL(JSON_QUERY(@J,''$.componentPhaseTimes''),N''MISSING'')<>N''[]'' OR ISNULL(JSON_VALUE(@J,''$.componentPhaseEvents[0].ContextStatus''),N'''')<>N''NO_OBSERVED_PAIR'' OR ISNULL(JSON_VALUE(@J,''$.componentPhaseEvents[0].InputIsTruncated''),N'''')<>N''true'' THROW 56816,N''L_PREFIX_VALIDATE'',1;
INSERT dbo.ExampleLifecycleLogSource SELECT * FROM dbo.ExampleLifecycleLogSource WHERE id=3;
 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeComponentPhaseAnalysis=1,@IncludeComponentLifecyclePhases=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
 IF ISNULL(ISJSON(@J),0)<>1 THROW 56824,N''L_CAPTURE_JSON_INVALID'',1;
 IF @Phase=1 OR @CallSeq>16 BEGIN IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseEvents'' AND [type]=4) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseTimes'' AND [type]=4) THROW 56827,N''L_ARRAY_TYPES'',1; END;
IF ISNULL(JSON_QUERY(@J,''$.componentPhaseEvents''),N''MISSING'')<>N''[]'' THROW 56817,N''L_DUPLICATE_BUFFER'',1;
TRUNCATE TABLE dbo.ExampleLifecycleLogSource;
INSERT dbo.ExampleLifecycleLogSource(id,event,source,sourceid,executionid,starttime,message) VALUES(1,N''OnPreValidate'',N''ExampleFlow'',@A,@Id,@T,NULL),(2,N''User:PipelineComponentTime'',N''ExampleFlow'',@A,@Id,@T,REPLICATE(CONVERT(nvarchar(max),N''x''),2048)),(3,N''OnPostValidate'',N''ExampleFlow'',@A,@Id,@T,NULL);
 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeComponentPhaseAnalysis=1,@IncludeComponentLifecyclePhases=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
 IF ISNULL(ISJSON(@J),0)<>1 THROW 56824,N''L_CAPTURE_JSON_INVALID'',1;
 IF @Phase=1 OR @CallSeq>16 BEGIN IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseEvents'' AND [type]=4) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseTimes'' AND [type]=4) THROW 56827,N''L_ARRAY_TYPES'',1; END;
IF ISNULL(JSON_VALUE(@J,''$.componentPhaseEvents[0].ParseStatus''),N'''')<>N''POTENTIALLY_TRUNCATED'' THROW 56818,N''L_CAPACITY_GUARD'',1;
-- L-S13: direct native denial counterprobe on the same own source and current new flag.
CREATE USER ExampleLifecycleReader WITHOUT LOGIN;
DECLARE @OwnedUserId int=(SELECT principal_id FROM sys.database_principals WHERE name=N''ExampleLifecycleReader'');UPDATE #ExampleLifecycleOwnership SET UserId=@OwnedUserId;
GRANT EXECUTE ON SCHEMA::monitor TO ExampleLifecycleReader;GRANT VIEW DEFINITION ON dbo.ExampleLifecycleLogSource TO ExampleLifecycleReader;DENY SELECT ON dbo.ExampleLifecycleLogSource TO ExampleLifecycleReader;
DECLARE @DirectError int,@DirectMessage nvarchar(4000),@Impersonated bit=0;
BEGIN TRY
 EXECUTE AS USER=''ExampleLifecycleReader'';SET @Impersonated=1;
 BEGIN TRY EXEC(N''SELECT TOP(1) id FROM dbo.ExampleLifecycleLogSource'');END TRY BEGIN CATCH SELECT @DirectError=ERROR_NUMBER(),@DirectMessage=ERROR_MESSAGE();END CATCH;
 SELECT @DirectError AS DirectNativeError,@DirectMessage AS DirectNativeMessage;

 SELECT @J=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
 EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N''ExampleLifecycleLogSource'',@ExecutionId=@Id,@IncludeComponentPhaseAnalysis=1,@IncludeComponentLifecyclePhases=1,@MaxZeilen=0,@HighImpactConfirmed=1,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
 SET @CallSeq+=1;SELECT N''L-SUT-Capture'' AS CaptureLabel,@CallSeq AS CallOrdinal,@J AS CaptureJson,@Status AS OutputStatus,@Partial AS OutputPartial,@Error AS OutputError,@Message AS OutputMessage,@@OPTIONS AS CallerOptions,@@LOCK_TIMEOUT AS CallerLockTimeout,@@TRANCOUNT AS CallerTranCount,XACT_STATE() AS CallerXactState,DB_ID() AS CallerDatabaseId,SUSER_SID() AS CallerSid,OBJECT_ID(N''dbo.ExampleLifecycleLogSource'') AS OwnSourceTableId,OBJECT_ID(N''dbo.ExampleLifecycleFixtureScope'') AS OwnFixtureProcedureId;
 IF ISNULL(ISJSON(@J),0)<>1 THROW 56824,N''L_CAPTURE_JSON_INVALID'',1;
 IF @Phase=1 OR @CallSeq>16 BEGIN IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseEvents'' AND [type]=4) OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J) WHERE [key]=N''componentPhaseTimes'' AND [type]=4) THROW 56827,N''L_ARRAY_TYPES'',1; END;
 REVERT;SET @Impersonated=0;
END TRY BEGIN CATCH
 IF @Impersonated=1 BEGIN TRY REVERT;END TRY BEGIN CATCH SELECT ERROR_NUMBER() AS RevertError;END CATCH;THROW;
END CATCH;
IF @DirectError IS NULL OR @Error IS NULL OR @DirectMessage IS NULL OR @Message IS NULL OR @DirectError<>229 OR @Error<>229 OR CONVERT(varbinary(max),@Message)<>CONVERT(varbinary(max),@DirectMessage) OR JSON_QUERY(@J,''$.componentPhaseEvents'')<>N''[]'' THROW 56819,N''L_DENIAL_FIRST_ERROR'',1;
IF (SELECT principal_id FROM sys.database_principals WHERE name=N''ExampleLifecycleReader'')<>@OwnedUserId THROW 56820,N''L_READER_CHANGED'',1;
DROP USER ExampleLifecycleReader;UPDATE #ExampleLifecycleOwnership SET UserId=NULL;
DROP TABLE #ExampleLifecycleEvents;DROP TABLE #ExampleLifecycleTimes;DROP TABLE #ExampleLifecycleCases;
IF @@OPTIONS<>@InitialOptions OR @@LOCK_TIMEOUT<>@InitialLock OR @@TRANCOUNT<>@InitialTran THROW 56821,N''L_CALLER_STATE'',1;
SELECT N''PASS'' AS LifecycleSyntheticStatus,CONVERT(int,33) AS NewPayloadAndContextCases;

 END;');
 SET @ProcId=OBJECT_ID(N'dbo.ExampleLifecycleFixtureScope');
 EXEC dbo.ExampleLifecycleFixtureScope @OwnedTableId=@TableId OUTPUT;
 IF DB_ID()<>@DbId OR OBJECT_ID(N'dbo.ExampleLifecycleLogSource')<>@TableId OR OBJECT_ID(N'dbo.ExampleLifecycleFixtureScope')<>@ProcId THROW 56891,N'L_CLEANUP_BINDING',1;
 DROP TABLE dbo.ExampleLifecycleLogSource;DROP PROCEDURE dbo.ExampleLifecycleFixtureScope;
 IF @@OPTIONS<>@OuterOptions OR @@LOCK_TIMEOUT<>@OuterLock OR @@TRANCOUNT<>@OuterTran THROW 56892,N'L_OUTER_CALLER',1;
END TRY BEGIN CATCH
 DECLARE @Err int=ERROR_NUMBER(),@Msg nvarchar(4000)=ERROR_MESSAGE(),@Cleanup nvarchar(4000)=N'',@UserId int;
 DECLARE @OwnScope bit=0;
 BEGIN TRY
  IF DB_ID()<>@DbId OR OBJECT_ID(N'tempdb..#ExampleLifecycleOwnership')<>@OwnershipId THROW 56893,N'L_FAILURE_SCOPE',1;
  SELECT @TableId=TableId,@UserId=UserId FROM #ExampleLifecycleOwnership;SET @OwnScope=1;
 END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup,N'Scope:',ERROR_MESSAGE(),N';');END CATCH;
 IF @OwnScope=1
 BEGIN
  BEGIN TRY IF @UserId IS NOT NULL AND DATABASE_PRINCIPAL_ID(N'ExampleLifecycleReader')=@UserId DROP USER ExampleLifecycleReader;END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup,N'User:',ERROR_MESSAGE(),N';');END CATCH;
  BEGIN TRY IF @TableId IS NOT NULL AND OBJECT_ID(N'dbo.ExampleLifecycleLogSource')=@TableId DROP TABLE dbo.ExampleLifecycleLogSource;END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup,N'Table:',ERROR_MESSAGE(),N';');END CATCH;
  BEGIN TRY IF @ProcId IS NOT NULL AND OBJECT_ID(N'dbo.ExampleLifecycleFixtureScope')=@ProcId DROP PROCEDURE dbo.ExampleLifecycleFixtureScope;END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup,N'Proc:',ERROR_MESSAGE(),N';');END CATCH;
  BEGIN TRY IF OBJECT_ID(N'tempdb..#ExampleLifecycleOwnership')=@OwnershipId DROP TABLE #ExampleLifecycleOwnership;END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup,N'Temp:',ERROR_MESSAGE(),N';');END CATCH;
 END;
 SELECT @Err AS OriginalError,@Msg AS OriginalMessage,@Cleanup AS CleanupError;THROW;
END CATCH;
DROP TABLE #ExampleLifecycleOwnership;
GO
