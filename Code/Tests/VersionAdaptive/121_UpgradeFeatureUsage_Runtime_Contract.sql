USE [DeineDatenbank];
GO
/* The owned native tests and explicitly synthetic source substitutions are separate.
   No server configuration is changed. The original module is never altered. */
IF OBJECT_ID(N'monitor.ExampleUpgradeRuntimeContract') IS NOT NULL THROW 57400,N'Owned fixture procedure collision.',1;
GO
CREATE PROCEDURE [monitor].[ExampleUpgradeRuntimeContract]
AS
BEGIN
SET NOCOUNT ON;
DECLARE @OriginalDb int=DB_ID(),@ParentLock int=@@LOCK_TIMEOUT,@ParentAbort bit=CASE WHEN (@@OPTIONS&16384)<>0 THEN 1 ELSE 0 END,
 @Json nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Return int,
 @BeforeCount bigint,@AfterCount bigint,@GrowthBefore bigint,@GrowthAfter bigint,@Original nvarchar(max),@Clone nvarchar(max),@Sql nvarchar(max),
 @Suffix nvarchar(32)=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),@Login sysname,@User sysname,@Module sysname,
 @LoginId int,@LoginSid varbinary(85),@UserId int,@UserSid varbinary(85),@ModuleId int,@ModuleHash varbinary(32),
 @OwnLogin bit=0,@OwnUser bit=0,@OwnModule bit=0,@Impersonated bit=0,@Failure nvarchar(2048),@Cleanup nvarchar(2048),
 @Case int=0,@FixtureCase int=0,@Major int=TRY_CONVERT(int,SERVERPROPERTY('ProductMajorVersion'));
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1 THROW 57401,N'Owned fixture requires isolated sysadmin and no caller transaction.',1;
SELECT @Original=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_UpgradeFeatureUsageAnalysis'));
IF @Original IS NULL THROW 57401,N'Installed public module definition missing.',1;
SELECT @Login=N'ExampleUpgradeLogin_'+@Suffix,@User=N'ExampleUpgradeUser_'+@Suffix,@Module=N'ExampleUpgradeModule_'+@Suffix;
CREATE TABLE [#ExampleUpgradeExpected_context] ([CollectionTimeUtc] datetime2(3) NOT NULL,[SourceMajorVersion] int NULL,[SourceBuild] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [TargetMajorVersion] int NULL,[SqlServerStartTimeLocal] datetime NULL,[SqlServerStartTimeMsTicks] bigint NULL,[EngineContextConfirmed] bit NOT NULL, [MeasurementStartUtc] datetime2(3) NULL,[MeasurementEndUtc] datetime2(3) NULL, [CounterReadState] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeCounterRows] bigint NULL,[ReturnedCounterRows] bigint NOT NULL, [OutputLimited] bit NOT NULL,[AssessmentCoverage] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RuleCatalogVersion] int NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL);
CREATE TABLE [#ExampleUpgradeExpected_deprecatedUsage] ([ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [FeatureName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeCounterType] int NOT NULL,[NativeCounterValue] bigint NOT NULL, [ObservationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetAssessment] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#ExampleUpgradeExpected_configuration] ([ConfigurationName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ConfiguredValue] int NULL,[ValueInUse] int NULL,[IsDynamic] bit NULL, [TargetMajorVersion] int NULL,[RuleCode] varchar(96) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RuleCatalogVersion] int NOT NULL, [AssessmentStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceReference] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#ExampleUpgradeExpected_sources] ([SourceOrdinal] smallint NOT NULL,[SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeReadState] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [NativeRows] bigint NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
CREATE TABLE [#ExampleUpgrade_context] ([Seed] int NULL);
CREATE TABLE [#ExampleUpgrade_deprecatedUsage] ([Seed] int NULL);
CREATE TABLE [#ExampleUpgrade_configuration] ([Seed] int NULL);
CREATE TABLE [#ExampleUpgrade_sources] ([Seed] int NULL);
CREATE TABLE [#ExampleUpgradeBefore]([ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[FeatureName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[NativeCounterType] int,[NativeCounterValue] bigint);
CREATE TABLE [#ExampleUpgradeAfter]([ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[FeatureName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS,[NativeCounterType] int,[NativeCounterValue] bigint);
BEGIN TRY
 SET LOCK_TIMEOUT 1379; SET XACT_ABORT ON;
 INSERT [#ExampleUpgradeBefore] SELECT [object_name],[counter_name],[instance_name],[cntr_type],[cntr_value] FROM sys.dm_os_performance_counters
  WHERE [object_name] LIKE N'%SQL%Deprecated Features%' AND RTRIM([counter_name])=N'Usage';
 EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @MaxZeilen=NULL,@ResultSetArt='TABLE',
  @ResultTablesJson=N'{"context":"#ExampleUpgrade_context","deprecatedUsage":"#ExampleUpgrade_deprecatedUsage","configuration":"#ExampleUpgrade_configuration","sources":"#ExampleUpgrade_sources"}',
  @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
 INSERT [#ExampleUpgradeAfter] SELECT [object_name],[counter_name],[instance_name],[cntr_type],[cntr_value] FROM sys.dm_os_performance_counters
  WHERE [object_name] LIKE N'%SQL%Deprecated Features%' AND RTRIM([counter_name])=N'Usage';
 IF COALESCE(@Return,-1)<>0 OR @Status<>'PARTIAL' OR @Partial<>1 OR @Error IS NOT NULL OR ISJSON(@Json)<>1
  OR @@LOCK_TIMEOUT<>1379 OR (@@OPTIONS&16384)=0 BEGIN SET @Message=LEFT(CONCAT(N'Native call failed: return=',@Return,N'; status=',@Status,N'; partial=',@Partial,N'; error=',@Error,N'; lock=',@@LOCK_TIMEOUT,N'; abort=',(@@OPTIONS&16384),N'; json=',ISJSON(@Json),N'; message=',@Message),2048);THROW 57402,@Message,1;END;
 IF EXISTS(SELECT [CollectionTimeUtc],[SourceMajorVersion],[SourceBuild],[TargetMajorVersion],[SqlServerStartTimeLocal],[SqlServerStartTimeMsTicks],[EngineContextConfirmed],[MeasurementStartUtc],[MeasurementEndUtc],[CounterReadState],[NativeCounterRows],[ReturnedCounterRows],[OutputLimited],[AssessmentCoverage],[RuleCatalogVersion],[StatusCode],[IsPartial] FROM [#ExampleUpgrade_context] EXCEPT SELECT [CollectionTimeUtc],[SourceMajorVersion],[SourceBuild],[TargetMajorVersion],[SqlServerStartTimeLocal],[SqlServerStartTimeMsTicks],[EngineContextConfirmed],[MeasurementStartUtc],[MeasurementEndUtc],[CounterReadState],[NativeCounterRows],[ReturnedCounterRows],[OutputLimited],[AssessmentCoverage],[RuleCatalogVersion],[StatusCode],[IsPartial] FROM OPENJSON(@Json,'$.context') WITH([CollectionTimeUtc] datetime2(3) '$.CollectionTimeUtc',[SourceMajorVersion] int '$.SourceMajorVersion',[SourceBuild] nvarchar(128) '$.SourceBuild',[TargetMajorVersion] int '$.TargetMajorVersion',[SqlServerStartTimeLocal] datetime '$.SqlServerStartTimeLocal',[SqlServerStartTimeMsTicks] bigint '$.SqlServerStartTimeMsTicks',[EngineContextConfirmed] bit '$.EngineContextConfirmed',[MeasurementStartUtc] datetime2(3) '$.MeasurementStartUtc',[MeasurementEndUtc] datetime2(3) '$.MeasurementEndUtc',[CounterReadState] varchar(16) '$.CounterReadState',[NativeCounterRows] bigint '$.NativeCounterRows',[ReturnedCounterRows] bigint '$.ReturnedCounterRows',[OutputLimited] bit '$.OutputLimited',[AssessmentCoverage] varchar(40) '$.AssessmentCoverage',[RuleCatalogVersion] int '$.RuleCatalogVersion',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial')) OR EXISTS(SELECT [CollectionTimeUtc],[SourceMajorVersion],[SourceBuild],[TargetMajorVersion],[SqlServerStartTimeLocal],[SqlServerStartTimeMsTicks],[EngineContextConfirmed],[MeasurementStartUtc],[MeasurementEndUtc],[CounterReadState],[NativeCounterRows],[ReturnedCounterRows],[OutputLimited],[AssessmentCoverage],[RuleCatalogVersion],[StatusCode],[IsPartial] FROM OPENJSON(@Json,'$.context') WITH([CollectionTimeUtc] datetime2(3) '$.CollectionTimeUtc',[SourceMajorVersion] int '$.SourceMajorVersion',[SourceBuild] nvarchar(128) '$.SourceBuild',[TargetMajorVersion] int '$.TargetMajorVersion',[SqlServerStartTimeLocal] datetime '$.SqlServerStartTimeLocal',[SqlServerStartTimeMsTicks] bigint '$.SqlServerStartTimeMsTicks',[EngineContextConfirmed] bit '$.EngineContextConfirmed',[MeasurementStartUtc] datetime2(3) '$.MeasurementStartUtc',[MeasurementEndUtc] datetime2(3) '$.MeasurementEndUtc',[CounterReadState] varchar(16) '$.CounterReadState',[NativeCounterRows] bigint '$.NativeCounterRows',[ReturnedCounterRows] bigint '$.ReturnedCounterRows',[OutputLimited] bit '$.OutputLimited',[AssessmentCoverage] varchar(40) '$.AssessmentCoverage',[RuleCatalogVersion] int '$.RuleCatalogVersion',[StatusCode] varchar(40) '$.StatusCode',[IsPartial] bit '$.IsPartial') EXCEPT SELECT [CollectionTimeUtc],[SourceMajorVersion],[SourceBuild],[TargetMajorVersion],[SqlServerStartTimeLocal],[SqlServerStartTimeMsTicks],[EngineContextConfirmed],[MeasurementStartUtc],[MeasurementEndUtc],[CounterReadState],[NativeCounterRows],[ReturnedCounterRows],[OutputLimited],[AssessmentCoverage],[RuleCatalogVersion],[StatusCode],[IsPartial] FROM [#ExampleUpgrade_context]) THROW 57402,N'Typed TABLE/JSON parity failed: context.',1;
IF EXISTS(SELECT [ObjectName],[CounterName],[FeatureName],[NativeCounterType],[NativeCounterValue],[ObservationStatus],[TargetAssessment],[EvidenceLimit] FROM [#ExampleUpgrade_deprecatedUsage] EXCEPT SELECT [ObjectName],[CounterName],[FeatureName],[NativeCounterType],[NativeCounterValue],[ObservationStatus],[TargetAssessment],[EvidenceLimit] FROM OPENJSON(@Json,'$.deprecatedUsage') WITH([ObjectName] nvarchar(128) '$.ObjectName',[CounterName] nvarchar(128) '$.CounterName',[FeatureName] nvarchar(128) '$.FeatureName',[NativeCounterType] int '$.NativeCounterType',[NativeCounterValue] bigint '$.NativeCounterValue',[ObservationStatus] varchar(40) '$.ObservationStatus',[TargetAssessment] varchar(40) '$.TargetAssessment',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit')) OR EXISTS(SELECT [ObjectName],[CounterName],[FeatureName],[NativeCounterType],[NativeCounterValue],[ObservationStatus],[TargetAssessment],[EvidenceLimit] FROM OPENJSON(@Json,'$.deprecatedUsage') WITH([ObjectName] nvarchar(128) '$.ObjectName',[CounterName] nvarchar(128) '$.CounterName',[FeatureName] nvarchar(128) '$.FeatureName',[NativeCounterType] int '$.NativeCounterType',[NativeCounterValue] bigint '$.NativeCounterValue',[ObservationStatus] varchar(40) '$.ObservationStatus',[TargetAssessment] varchar(40) '$.TargetAssessment',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit') EXCEPT SELECT [ObjectName],[CounterName],[FeatureName],[NativeCounterType],[NativeCounterValue],[ObservationStatus],[TargetAssessment],[EvidenceLimit] FROM [#ExampleUpgrade_deprecatedUsage]) THROW 57402,N'Typed TABLE/JSON parity failed: deprecatedUsage.',1;
IF EXISTS(SELECT [ConfigurationName],[ConfiguredValue],[ValueInUse],[IsDynamic],[TargetMajorVersion],[RuleCode],[RuleCatalogVersion],[AssessmentStatus],[SourceReference],[EvidenceLimit] FROM [#ExampleUpgrade_configuration] EXCEPT SELECT [ConfigurationName],[ConfiguredValue],[ValueInUse],[IsDynamic],[TargetMajorVersion],[RuleCode],[RuleCatalogVersion],[AssessmentStatus],[SourceReference],[EvidenceLimit] FROM OPENJSON(@Json,'$.configuration') WITH([ConfigurationName] nvarchar(128) '$.ConfigurationName',[ConfiguredValue] int '$.ConfiguredValue',[ValueInUse] int '$.ValueInUse',[IsDynamic] bit '$.IsDynamic',[TargetMajorVersion] int '$.TargetMajorVersion',[RuleCode] varchar(96) '$.RuleCode',[RuleCatalogVersion] int '$.RuleCatalogVersion',[AssessmentStatus] varchar(40) '$.AssessmentStatus',[SourceReference] nvarchar(512) '$.SourceReference',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit')) OR EXISTS(SELECT [ConfigurationName],[ConfiguredValue],[ValueInUse],[IsDynamic],[TargetMajorVersion],[RuleCode],[RuleCatalogVersion],[AssessmentStatus],[SourceReference],[EvidenceLimit] FROM OPENJSON(@Json,'$.configuration') WITH([ConfigurationName] nvarchar(128) '$.ConfigurationName',[ConfiguredValue] int '$.ConfiguredValue',[ValueInUse] int '$.ValueInUse',[IsDynamic] bit '$.IsDynamic',[TargetMajorVersion] int '$.TargetMajorVersion',[RuleCode] varchar(96) '$.RuleCode',[RuleCatalogVersion] int '$.RuleCatalogVersion',[AssessmentStatus] varchar(40) '$.AssessmentStatus',[SourceReference] nvarchar(512) '$.SourceReference',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit') EXCEPT SELECT [ConfigurationName],[ConfiguredValue],[ValueInUse],[IsDynamic],[TargetMajorVersion],[RuleCode],[RuleCatalogVersion],[AssessmentStatus],[SourceReference],[EvidenceLimit] FROM [#ExampleUpgrade_configuration]) THROW 57402,N'Typed TABLE/JSON parity failed: configuration.',1;
IF EXISTS(SELECT [SourceOrdinal],[SourceName],[StatusCode],[NativeReadState],[NativeRows],[ErrorNumber],[ErrorMessage],[EvidenceLimit] FROM [#ExampleUpgrade_sources] EXCEPT SELECT [SourceOrdinal],[SourceName],[StatusCode],[NativeReadState],[NativeRows],[ErrorNumber],[ErrorMessage],[EvidenceLimit] FROM OPENJSON(@Json,'$.sources') WITH([SourceOrdinal] smallint '$.SourceOrdinal',[SourceName] sysname '$.SourceName',[StatusCode] varchar(40) '$.StatusCode',[NativeReadState] varchar(16) '$.NativeReadState',[NativeRows] bigint '$.NativeRows',[ErrorNumber] int '$.ErrorNumber',[ErrorMessage] nvarchar(2048) '$.ErrorMessage',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit')) OR EXISTS(SELECT [SourceOrdinal],[SourceName],[StatusCode],[NativeReadState],[NativeRows],[ErrorNumber],[ErrorMessage],[EvidenceLimit] FROM OPENJSON(@Json,'$.sources') WITH([SourceOrdinal] smallint '$.SourceOrdinal',[SourceName] sysname '$.SourceName',[StatusCode] varchar(40) '$.StatusCode',[NativeReadState] varchar(16) '$.NativeReadState',[NativeRows] bigint '$.NativeRows',[ErrorNumber] int '$.ErrorNumber',[ErrorMessage] nvarchar(2048) '$.ErrorMessage',[EvidenceLimit] nvarchar(1000) '$.EvidenceLimit') EXCEPT SELECT [SourceOrdinal],[SourceName],[StatusCode],[NativeReadState],[NativeRows],[ErrorNumber],[ErrorMessage],[EvidenceLimit] FROM [#ExampleUpgrade_sources]) THROW 57402,N'Typed TABLE/JSON parity failed: sources.',1;
IF EXISTS(SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgrade_context') EXCEPT SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgradeExpected_context')) OR EXISTS(SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgradeExpected_context') EXCEPT SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgrade_context')) THROW 57402,N'Independent typed schema facets failed: context.',1;
IF EXISTS(SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgrade_deprecatedUsage') EXCEPT SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgradeExpected_deprecatedUsage')) OR EXISTS(SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgradeExpected_deprecatedUsage') EXCEPT SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgrade_deprecatedUsage')) THROW 57402,N'Independent typed schema facets failed: deprecatedUsage.',1;
IF EXISTS(SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgrade_configuration') EXCEPT SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgradeExpected_configuration')) OR EXISTS(SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgradeExpected_configuration') EXCEPT SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgrade_configuration')) THROW 57402,N'Independent typed schema facets failed: configuration.',1;
IF EXISTS(SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgrade_sources') EXCEPT SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgradeExpected_sources')) OR EXISTS(SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgradeExpected_sources') EXCEPT SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])) AS [Ordinal],[name] COLLATE SQL_Latin1_General_CP1_CS_AS,[system_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleUpgrade_sources')) THROW 57402,N'Independent typed schema facets failed: sources.',1;
 SELECT @BeforeCount=COUNT_BIG(*) FROM [#ExampleUpgradeBefore]; SELECT @AfterCount=COUNT_BIG(*) FROM [#ExampleUpgradeAfter];
 IF @BeforeCount=0 OR @BeforeCount<>@AfterCount OR @BeforeCount<>(SELECT COUNT_BIG(*) FROM [#ExampleUpgrade_deprecatedUsage])
  OR (SELECT COUNT_BIG(*) FROM [#ExampleUpgrade_sources])<>4 OR (SELECT COUNT_BIG(*) FROM [#ExampleUpgrade_context])<>1
  OR EXISTS(SELECT 1 FROM [#ExampleUpgrade_sources] WHERE [NativeReadState]<>'SUCCEEDED' OR [StatusCode]<>'AVAILABLE' OR [ErrorNumber] IS NOT NULL)
  OR EXISTS(SELECT 1 FROM [#ExampleUpgrade_context] WHERE [EngineContextConfirmed]<>1 OR [NativeCounterRows]<>@BeforeCount OR [ReturnedCounterRows]<>@BeforeCount OR [OutputLimited]<>0 OR [TargetMajorVersion] IS NOT NULL OR [AssessmentCoverage]<>'LIMITED_OBSERVATION')
  THROW 57403,N'Native source count or bounded context oracle failed.',1;
 IF EXISTS(SELECT [ObjectName],[CounterName],[FeatureName],[NativeCounterType] FROM [#ExampleUpgradeBefore] EXCEPT SELECT [ObjectName],[CounterName],[FeatureName],[NativeCounterType] FROM [#ExampleUpgrade_deprecatedUsage])
  OR EXISTS(SELECT 1 FROM [#ExampleUpgrade_deprecatedUsage] u JOIN [#ExampleUpgradeBefore] b ON u.[ObjectName]=b.[ObjectName] AND u.[CounterName]=b.[CounterName] AND u.[FeatureName]=b.[FeatureName] AND u.[NativeCounterType]=b.[NativeCounterType]
   JOIN [#ExampleUpgradeAfter] a ON u.[ObjectName]=a.[ObjectName] AND u.[CounterName]=a.[CounterName] AND u.[FeatureName]=a.[FeatureName] AND u.[NativeCounterType]=a.[NativeCounterType]
   WHERE u.[NativeCounterValue]<b.[NativeCounterValue] OR u.[NativeCounterValue]>a.[NativeCounterValue] OR u.[TargetAssessment]<>'TARGET_NOT_SELECTED'
    OR u.[ObservationStatus]<>CASE WHEN u.[NativeCounterValue]=0 THEN 'OBSERVED_ZERO' ELSE 'OBSERVED_POSITIVE' END)
  THROW 57404,N'Independent native rowset and raw value bounds failed.',1;
 IF EXISTS(SELECT [ConfigurationName],[ConfiguredValue],[ValueInUse],[IsDynamic] FROM [#ExampleUpgrade_configuration] EXCEPT
  SELECT [name] COLLATE SQL_Latin1_General_CP1_CS_AS,CONVERT(int,[value]),CONVERT(int,[value_in_use]),[is_dynamic] FROM sys.configurations WHERE [name]=N'lightweight pooling')
  OR (SELECT COUNT_BIG(*) FROM [#ExampleUpgrade_configuration])<>1 THROW 57405,N'Independent native configuration oracle failed.',1;
 SET @Case+=1;PRINT CONCAT(N'UPGRADE_NATIVE_GROUP_PASS ',@Case);
 SELECT @GrowthBefore=[cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE N'%SQL%Deprecated Features%' AND RTRIM([counter_name])=N'Usage' AND RTRIM([instance_name])=N'DATABASEPROPERTYEX(''IsFullTextEnabled'')';
 EXEC sys.sp_executesql N'DECLARE @Observed int=CONVERT(int,DATABASEPROPERTYEX(DB_NAME(),''IsFullTextEnabled''));';
 EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis] @TargetMajorVersion=17,@MaxZeilen=NULL,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 SELECT @GrowthAfter=[NativeCounterValue] FROM OPENJSON(@Json,'$.deprecatedUsage') WITH([FeatureName] nvarchar(128),[NativeCounterValue] bigint) WHERE RTRIM([FeatureName])=N'DATABASEPROPERTYEX(''IsFullTextEnabled'')';
 IF @GrowthBefore IS NULL OR @GrowthAfter IS NULL OR @GrowthAfter<=@GrowthBefore OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.deprecatedUsage') WITH([TargetAssessment] varchar(40)) WHERE [TargetAssessment]<>'UNMAPPED_SOURCE_FEATURE') THROW 57406,N'Native encounter growth and target separation failed.',1;
 DECLARE @UnlimitedCase int=0,@OutputLimit int;
 WHILE @UnlimitedCase<3
 BEGIN
  SET @OutputLimit=CASE WHEN @UnlimitedCase=0 THEN NULL WHEN @UnlimitedCase=1 THEN 0 ELSE 2147483647 END;
  EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @TargetMajorVersion=17,@MaxZeilen=@OutputLimit,@ResultSetArt='NONE',
   @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@ErrorNumberOut=@Error OUTPUT;
  IF COALESCE(@Return,-1)<>0 OR @Error IS NOT NULL OR COALESCE(ISJSON(@Json),0)<>1
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.deprecatedUsage'))<>@BeforeCount
   OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.context[0].NativeCounterRows')),-1)<>@BeforeCount
   OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.context[0].ReturnedCounterRows')),-1)<>@BeforeCount
   OR COALESCE(JSON_VALUE(@Json,'$.context[0].OutputLimited'),'')<>'false'
   THROW 57439,N'Framework NULL zero or large positive output-limit contract failed.',1;
  SET @UnlimitedCase+=1;
 END;
 EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis] @TargetMajorVersion=17,@MaxZeilen=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
 IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.deprecatedUsage'))<>1 OR COALESCE(JSON_VALUE(@Json,'$.context[0].OutputLimited'),N'<NULL>')<>'true'
  OR TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.context[0].NativeCounterRows'))<>@BeforeCount THROW 57407,N'Limit applied before full native read.',1;
 SET @Case+=1;PRINT CONCAT(N'UPGRADE_NATIVE_GROUP_PASS ',@Case);
 BEGIN TRANSACTION;
 EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@ErrorNumberOut=@Error OUTPUT;
 IF @Return<>51011 OR @Error<>51011 OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @Json IS NOT NULL THROW 57408,N'Caller transaction was not preserved and rejected.',1;
 ROLLBACK TRANSACTION;
 SET IMPLICIT_TRANSACTIONS ON;
 EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @ResultSetArt='NONE',@PrintMeldungen=0,@ErrorNumberOut=@Error OUTPUT;
 SET IMPLICIT_TRANSACTIONS OFF;
 IF @Return<>51011 OR @Error<>51011 OR @@TRANCOUNT<>0 THROW 57409,N'Implicit caller state was not rejected before work.',1;
 EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @MaxZeilen=-1,@ResultSetArt='NONE',@PrintMeldungen=0;
 IF @Return<>51011 THROW 57410,N'Invalid output limit accepted.',1;
 EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @TargetMajorVersion=14,@ResultSetArt='NONE',@PrintMeldungen=0;
 IF @Return<>51011 THROW 57410,N'Unsupported target accepted.',1;
 EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @ResultSetArt='NONE',@Hilfe=1,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
 IF @Return<>0 OR @Status<>'AVAILABLE' OR @Partial<>0 THROW 57411,N'Help contract failed.',1;
 CREATE TABLE [#ExampleUpgradeBad]([Seed] int CHECK ([Seed] IS NULL));
 EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @ResultSetArt='TABLE',@ResultTablesJson=N'{"deprecatedUsage":"#ExampleUpgradeBad"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@ErrorNumberOut=@Error OUTPUT;
 IF @Return=0 OR @Error IS NULL OR @Error=51011 OR @Json IS NOT NULL OR @@LOCK_TIMEOUT<>1379 OR (@@OPTIONS&16384)=0 THROW 57412,N'Technical TABLE failure contract failed.',1;
 SET @Case+=1;PRINT CONCAT(N'UPGRADE_NATIVE_GROUP_PASS ',@Case);
 -- Genuine native permission boundary: an owned login first lacks DMV rights, then receives the version-specific right.
 IF EXISTS(SELECT 1 FROM sys.server_principals WHERE [name]=@Login) OR EXISTS(SELECT 1 FROM sys.database_principals WHERE [name]=@User) THROW 57413,N'Owned principal collision.',1;
 SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Login)+N' WITH PASSWORD='+QUOTENAME(N'Example!'+CONVERT(nvarchar(36),NEWID()),'''')+N',CHECK_POLICY=OFF;';
 EXEC sys.sp_executesql @Sql;SET @OwnLogin=1;
 SELECT @LoginId=[principal_id],@LoginSid=[sid] FROM sys.server_principals WHERE [name]=@Login;
 SET @Sql=N'CREATE USER '+QUOTENAME(@User)+N' FOR LOGIN '+QUOTENAME(@Login)+N';';
 EXEC sys.sp_executesql @Sql;SET @OwnUser=1;
 SELECT @UserId=[principal_id],@UserSid=[sid] FROM sys.database_principals WHERE [name]=@User;
 SET @Sql=N'GRANT EXECUTE ON OBJECT::[monitor].[USP_UpgradeFeatureUsageAnalysis] TO '+QUOTENAME(@User)+N';';EXEC sys.sp_executesql @Sql;
 EXECUTE AS LOGIN=@Login;SET @Impersonated=1;
 EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
 REVERT;SET @Impersonated=0;
 IF @Return<>0 OR @Status<>'PARTIAL' OR @Error NOT IN(229,262,297,300,371,916)
  OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.sources') WITH([SourceOrdinal] int,[NativeReadState] varchar(16),[NativeRows] bigint) WHERE [SourceOrdinal] IN(1,2,3) AND [NativeReadState]='FAILED' AND [NativeRows] IS NULL)<>3
  OR COALESCE(JSON_VALUE(@Json,'$.sources[3].NativeReadState'),N'<NULL>')<>'SUCCEEDED' OR COALESCE(JSON_VALUE(@Json,'$.context[0].EngineContextConfirmed'),N'<NULL>')<>'false'
  BEGIN SET @Message=LEFT(CONCAT(N'Restricted caller: return=',@Return,N'; status=',@Status,N'; error=',@Error,N'; sources=',JSON_QUERY(@Json,'$.sources')),2048);THROW 57414,@Message,1;END;
 SET @Sql=N'GRANT '+CASE WHEN @Major=15 THEN N'VIEW SERVER STATE' ELSE N'VIEW SERVER PERFORMANCE STATE' END+N' TO '+QUOTENAME(@Login)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
 EXECUTE AS LOGIN=@Login;SET @Impersonated=1;
 EXEC @Return=[monitor].[USP_UpgradeFeatureUsageAnalysis] @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@ErrorNumberOut=@Error OUTPUT;
 REVERT;SET @Impersonated=0;
 IF @Return<>0 OR @Error IS NOT NULL OR COALESCE(JSON_VALUE(@Json,'$.context[0].EngineContextConfirmed'),N'<NULL>')<>'true'
  OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.sources') WITH([NativeReadState] varchar(16)) WHERE [NativeReadState]<>'SUCCEEDED') THROW 57415,N'Genuine granted native permission probe failed.',1;
 SET @Case+=1;PRINT CONCAT(N'UPGRADE_NATIVE_GROUP_PASS ',@Case);
 -- Synthetic engine/cache substitutions never claim native engine observations.
 WHILE @FixtureCase<11
 BEGIN
  IF @OwnModule=1
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE [object_id]=@ModuleId AND [object_id]=OBJECT_ID(N'monitor.'+@Module) AND HASHBYTES('SHA2_256',[definition])=@ModuleHash) THROW 57416,N'Owned fixture definition or name binding changed.',1;
   -- Stored CREATE headers are valid only for a new owned clone; never alter the public module.
   SET @Sql=N'DROP PROCEDURE [monitor].'+QUOTENAME(@Module);EXEC [sys].[sp_executesql] @Sql;
   SELECT @OwnModule=0,@ModuleId=NULL,@ModuleHash=NULL;
  END;
  SET @Clone=REPLACE(@Original,N'[monitor].[USP_UpgradeFeatureUsageAnalysis]',N'[monitor].'+QUOTENAME(@Module));
  SET @Clone=REPLACE(@Clone,N'SELECT @Phase,[sqlserver_start_time],[sqlserver_start_time_ms_ticks]'+NCHAR(13)+NCHAR(10)+N'                    FROM [sys].[dm_os_sys_info] WITH (NOLOCK);',N'SELECT @Phase,CONVERT(datetime,''20260101''),CASE WHEN @Phase=2 AND '+CONVERT(nvarchar(2),@FixtureCase)+N'=1 THEN 2 ELSE 1 END;');
  -- The installed source may use LF or CRLF. Normalize only this owned clone.
  SET @Clone=REPLACE(@Clone,NCHAR(13),N'');
  SET @Clone=REPLACE(@Clone,N'SELECT @Phase,[sqlserver_start_time],[sqlserver_start_time_ms_ticks]'+NCHAR(10)+N'                    FROM [sys].[dm_os_sys_info] WITH (NOLOCK);',N'SELECT @Phase,CONVERT(datetime,''20260101''),CASE WHEN @Phase=2 AND '+CONVERT(nvarchar(2),@FixtureCase)+N'=1 THEN 2 ELSE 1 END;');
  SET @Clone=REPLACE(@Clone,N'SELECT [object_name],[counter_name],[instance_name],[cntr_type],[cntr_value]'+NCHAR(10)+N'                    FROM [sys].[dm_os_performance_counters] WITH (NOLOCK)'+NCHAR(10)+N'                    WHERE [object_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N''%SQL%Deprecated Features%'''+NCHAR(10)+N'                      AND RTRIM([counter_name]) COLLATE Latin1_General_100_BIN2=N''Usage'';',
   CASE WHEN @FixtureCase=4 THEN N'SELECT N''ExampleSQL:Deprecated Features'',N''Usage'',N''ExampleFeature'',272,CONVERT(bigint,CONVERT(int,N''ExampleInvalid''));'
   ELSE N'SELECT N''ExampleSQL:Deprecated Features'',N''Usage'',N''ExampleFeature'',272,CONVERT(bigint,'+CASE WHEN @FixtureCase=5 THEN N'-1' ELSE N'7' END+N') WHERE '+CASE WHEN @FixtureCase=0 THEN N'1=0' ELSE N'1=1' END+N';' END);
  SET @Clone=REPLACE(@Clone,N'SELECT [name],[value],[value_in_use],[is_dynamic] FROM [sys].[configurations] WITH (NOLOCK)'+NCHAR(10)+N'                WHERE CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),N''lightweight pooling'');',
   N'SELECT N''lightweight pooling'',CONVERT(sql_variant,'+CASE WHEN @FixtureCase IN(2,3) THEN N'1' ELSE N'0' END+N'),CONVERT(sql_variant,'+CASE WHEN @FixtureCase=3 THEN N'1' ELSE N'0' END+N'),CONVERT(bit,0) WHERE '+CASE WHEN @FixtureCase=0 THEN N'1=0' ELSE N'1=1' END+N';');
  IF @FixtureCase=6
  BEGIN
   -- Explicitly synthetic source substitution; every actual read now needs the native DMV right.
   SET @Clone=REPLACE(REPLACE(@Original,NCHAR(13),N''),N'[monitor].[USP_UpgradeFeatureUsageAnalysis]',N'[monitor].'+QUOTENAME(@Module));
   SET @Clone=REPLACE(@Clone,N'SELECT [name],[value],[value_in_use],[is_dynamic] FROM [sys].[configurations] WITH (NOLOCK)'+NCHAR(10)+N'                WHERE CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),N''lightweight pooling'');',
     N'SELECT N''lightweight pooling'',CONVERT(sql_variant,0),CONVERT(sql_variant,0),CONVERT(bit,0) FROM [sys].[dm_os_sys_info] WITH (NOLOCK);');
   IF CHARINDEX(N'FROM [sys].[configurations]',@Clone)>0 THROW 57417,N'Permission fixture configuration substitution failed.',1;
  END;
  IF @FixtureCase IN(7,8)
   SET @Clone=REPLACE(@Clone,N'INSERT @Engine([Phase],[StartLocal],[StartTicks])',
      CASE WHEN @FixtureCase=8 THEN N'IF @Phase=1 THROW 53901,N''Example before failure'',1; ' ELSE N'' END+
      N'IF @Phase=2 THROW 53903,N''Example after failure'',1; INSERT @Engine([Phase],[StartLocal],[StartTicks])');
  IF @FixtureCase=8
  BEGIN
   SET @Clone=REPLACE(@Clone,N'INSERT [#UpgradeFeatureUsageAnalysis_CounterCache]',N'THROW 53902,N''Example counter failure'',1; INSERT [#UpgradeFeatureUsageAnalysis_CounterCache]');
   SET @Clone=REPLACE(@Clone,N'INSERT [#UpgradeFeatureUsageAnalysis_ConfigCache]',N'THROW 53904,N''Example configuration failure'',1; INSERT [#UpgradeFeatureUsageAnalysis_ConfigCache]');
  END;
  IF @FixtureCase=9
   SET @Clone=REPLACE(@Clone,N'CONVERT(sql_variant,0),CONVERT(sql_variant,0),CONVERT(bit,0)',N'CONVERT(sql_variant,N''1''),CONVERT(sql_variant,0),CONVERT(bit,0)');
  IF @FixtureCase=10
  BEGIN
   SET @Clone=REPLACE(@Clone,N'SELECT @Major=TRY_CONVERT(int,SERVERPROPERTY(''ProductMajorVersion'')),@Build=CONVERT(nvarchar(128),SERVERPROPERTY(''ProductVersion''));',N'SELECT @Major=18,@Build=N''ExampleUnsupported'';');
   IF CHARINDEX(N'SELECT @Major=18,@Build=N''ExampleUnsupported'';',@Clone)=0 THROW 57417,N'Unsupported-major substitution failed.',1;
  END;
  IF @FixtureCase<>6 AND (CHARINDEX(N'FROM [sys].[dm_os_performance_counters]',@Clone)>0 OR CHARINDEX(N'FROM [sys].[dm_os_sys_info]',@Clone)>0 OR CHARINDEX(N'FROM [sys].[configurations]',@Clone)>0) THROW 57417,N'Synthetic substitution did not cover each native source.',1;
  EXEC sys.sp_executesql @Clone;SET @OwnModule=1;
  SELECT @ModuleId=OBJECT_ID(N'monitor.'+@Module);SELECT @ModuleHash=HASHBYTES('SHA2_256',[definition]) FROM sys.sql_modules WHERE [object_id]=@ModuleId;
  SET @Sql=N'EXEC [monitor].'+QUOTENAME(@Module)+N' @TargetMajorVersion=17,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@S OUTPUT,@ErrorNumberOut=@E OUTPUT,@ErrorMessageOut=@M OUTPUT;';
  IF @FixtureCase=6
  BEGIN
   DECLARE @RightSql nvarchar(max)=N'REVOKE '+CASE WHEN @Major=15 THEN N'VIEW SERVER STATE' ELSE N'VIEW SERVER PERFORMANCE STATE' END+N' FROM '+QUOTENAME(@Login)+N';';
   EXEC [master].[sys].[sp_executesql] @RightSql;
   SET @RightSql=N'GRANT EXECUTE ON OBJECT::[monitor].'+QUOTENAME(@Module)+N' TO '+QUOTENAME(@User)+N';';
   EXEC [sys].[sp_executesql] @RightSql;
   EXECUTE AS LOGIN=@Login;SET @Impersonated=1;
  END;
  EXEC sys.sp_executesql @Sql,N'@J nvarchar(max) OUTPUT,@S varchar(40) OUTPUT,@E int OUTPUT,@M nvarchar(2048) OUTPUT',@J=@Json OUTPUT,@S=@Status OUTPUT,@E=@Error OUTPUT,@M=@Message OUTPUT;
  IF @Impersonated=1 BEGIN REVERT;SET @Impersonated=0;END;

  IF @FixtureCase=0 AND (@Status<>'EMPTY_UNPROVEN' OR COALESCE(JSON_VALUE(@Json,'$.sources[1].NativeReadState'),N'<NULL>')<>'SUCCEEDED' OR COALESCE(JSON_VALUE(@Json,'$.sources[1].NativeRows'),N'<NULL>')<>'0') THROW 57418,N'Successful empty source synthesized an observation.',1;
  IF @FixtureCase=1 AND (COALESCE(JSON_VALUE(@Json,'$.context[0].EngineContextConfirmed'),N'<NULL>')<>'false' OR COALESCE(JSON_VALUE(@Json,'$.deprecatedUsage[0].NativeCounterValue'),N'<NULL>')<>'7' OR COALESCE(JSON_VALUE(@Json,'$.deprecatedUsage[0].ObservationStatus'),N'<NULL>')<>'ENGINE_CONTEXT_UNBOUND' OR COALESCE(JSON_VALUE(@Json,'$.sources[1].NativeReadState'),N'<NULL>')<>'SUCCEEDED' OR COALESCE(JSON_VALUE(@Json,'$.sources[1].NativeRows'),N'<NULL>')<>'1') THROW 57419,N'Late drift destroyed successful native-cache provenance.',1;
  IF @FixtureCase=2 AND COALESCE(JSON_VALUE(@Json,'$.configuration[0].AssessmentStatus'),N'<NULL>')<>'PENDING_DEPRECATED_CONFIGURATION' THROW 57420,N'Configured and effective states were conflated.',1;
  IF @FixtureCase=3 AND COALESCE(JSON_VALUE(@Json,'$.configuration[0].AssessmentStatus'),N'<NULL>')<>'CONFIGURED_DEPRECATED_AT_TARGET' THROW 57421,N'Effective configured rule failed.',1;
  IF @FixtureCase=4 AND (@Status<>'PARTIAL' OR @Error<>245 OR COALESCE(JSON_VALUE(@Json,'$.sources[1].NativeReadState'),N'<NULL>')<>'FAILED' OR JSON_VALUE(@Json,'$.sources[1].NativeRows') IS NOT NULL) THROW 57422,N'Actual native-cache exception was suppressed or fabricated as zero.',1;
  IF @FixtureCase=5 AND COALESCE(JSON_VALUE(@Json,'$.deprecatedUsage[0].ObservationStatus'),N'<NULL>')<>'INVALID_NATIVE_VALUE' THROW 57423,N'Negative raw native value was interpreted as usage.',1;
  IF @FixtureCase=6 AND (COALESCE(@Status,'')<>'DENIED_PERMISSION' OR @Error NOT IN(229,262,297,300,371,916)
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.sources') WITH([NativeReadState] varchar(16),[NativeRows] bigint,[ErrorNumber] int) WHERE [NativeReadState]='FAILED' AND [NativeRows] IS NULL AND [ErrorNumber] IN(229,262,297,300,371,916))<>4
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.deprecatedUsage'))<>0 OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.configuration'))<>0) THROW 57434,N'Four-source native denied aggregation failed.',1;
  IF @FixtureCase=7 AND (COALESCE(@Status,'')<>'PARTIAL' OR COALESCE(@Error,-1)<>53903
   OR COALESCE(JSON_VALUE(@Json,'$.sources[2].NativeReadState'),'')<>'FAILED' OR JSON_VALUE(@Json,'$.sources[2].NativeRows') IS NOT NULL
   OR COALESCE(JSON_VALUE(@Json,'$.sources[1].NativeReadState'),'')<>'SUCCEEDED' OR COALESCE(JSON_VALUE(@Json,'$.sources[1].NativeRows'),'')<>'1'
   OR COALESCE(JSON_VALUE(@Json,'$.deprecatedUsage[0].NativeCounterValue'),'')<>'7' OR COALESCE(JSON_VALUE(@Json,'$.deprecatedUsage[0].ObservationStatus'),'')<>'ENGINE_CONTEXT_UNBOUND') THROW 57435,N'Late SQL exception destroyed successful counter provenance.',1;
  IF @FixtureCase=8 AND (COALESCE(@Status,'')<>'ERROR_HANDLED' OR COALESCE(@Error,-1)<>53901
   OR COALESCE(@Message,N'')<>N'Example before failure' OR COALESCE(JSON_VALUE(@Json,'$.meta.errorMessage'),N'')<>N'Example before failure'
   OR COALESCE(JSON_VALUE(@Json,'$.sources[0].ErrorMessage'),N'')<>N'Example before failure'
   OR COALESCE(JSON_VALUE(@Json,'$.sources[0].ErrorNumber'),'')<>'53901' OR COALESCE(JSON_VALUE(@Json,'$.sources[1].ErrorNumber'),'')<>'53902'
   OR COALESCE(JSON_VALUE(@Json,'$.sources[2].ErrorNumber'),'')<>'53903' OR COALESCE(JSON_VALUE(@Json,'$.sources[3].ErrorNumber'),'')<>'53904'
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.sources') WITH([NativeReadState] varchar(16),[NativeRows] bigint) WHERE [NativeReadState]='FAILED' AND [NativeRows] IS NULL)<>4) THROW 57436,N'First ordinal SQL error and distinct later errors were not retained.',1;
  IF @FixtureCase=9 AND (COALESCE(JSON_VALUE(@Json,'$.configuration[0].AssessmentStatus'),'')<>'INVALID_NATIVE_VALUE'
    OR JSON_VALUE(@Json,'$.configuration[0].ConfiguredValue') IS NOT NULL OR COALESCE(JSON_VALUE(@Json,'$.sources[3].NativeReadState'),'')<>'SUCCEEDED') THROW 57437,N'Unknown native configuration type was coerced into a confirmed value.',1;
  IF @FixtureCase=10 AND (COALESCE(@Status,'')<>'UNAVAILABLE_OBJECT'
    OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.sources') WITH([NativeReadState] varchar(16),[NativeRows] bigint) WHERE [NativeReadState]='NOT_STARTED' AND [NativeRows] IS NULL)<>4
    OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.deprecatedUsage'))<>0) THROW 57438,N'Unsupported source major produced confirmed observations.',1;
  SET @FixtureCase+=1;
 END;
 SET @Case+=1;PRINT CONCAT(N'UPGRADE_NATIVE_GROUP_PASS ',@Case);
END TRY
BEGIN CATCH
 IF @Impersonated=1 BEGIN REVERT;SET @Impersonated=0;END;
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 SET IMPLICIT_TRANSACTIONS OFF;
 SET @Failure=CONCAT(ERROR_NUMBER(),N' line ',ERROR_LINE(),N': ',ERROR_MESSAGE());
END CATCH;
BEGIN TRY
 IF @OwnModule=1
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE [object_id]=@ModuleId AND HASHBYTES('SHA2_256',[definition])=@ModuleHash AND [object_id]=OBJECT_ID(N'monitor.'+@Module)) THROW 57424,N'Owned module cleanup binding failed.',1;
  SET @Sql=N'DROP PROCEDURE [monitor].'+QUOTENAME(@Module);EXEC sys.sp_executesql @Sql;SET @OwnModule=0;
 END;
 IF @OwnUser=1
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE [principal_id]=@UserId AND [name]=@User AND [sid]=@UserSid) THROW 57425,N'Owned user cleanup binding failed.',1;
  SET @Sql=N'DROP USER '+QUOTENAME(@User);EXEC sys.sp_executesql @Sql;SET @OwnUser=0;
 END;
 IF @OwnLogin=1
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE [principal_id]=@LoginId AND [name]=@Login AND [sid]=@LoginSid) THROW 57426,N'Owned login cleanup binding failed.',1;
  SET @Sql=N'DROP LOGIN '+QUOTENAME(@Login);EXEC sys.sp_executesql @Sql;SET @OwnLogin=0;
 END;
 IF OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_UpgradeFeatureUsageAnalysis')) COLLATE SQL_Latin1_General_CP1_CS_AS<>@Original COLLATE SQL_Latin1_General_CP1_CS_AS OR DB_ID()<>@OriginalDb THROW 57427,N'Original module or database context changed.',1;
END TRY BEGIN CATCH SET @Cleanup=CONCAT(ERROR_NUMBER(),N': ',ERROR_MESSAGE());END CATCH;
SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@ParentLock);EXEC sys.sp_executesql @Sql;
IF @ParentAbort=1 SET XACT_ABORT ON;ELSE SET XACT_ABORT OFF;
IF @Cleanup IS NOT NULL BEGIN SET @Message=LEFT(CONCAT(N'Owned cleanup failed: ',@Cleanup,N'; primary: ',@Failure),2048);THROW 57428,@Message,1;END;
IF @Failure IS NOT NULL THROW 57429,@Failure,1;
IF @Case<>5 OR @FixtureCase<>11 OR COALESCE(@UnlimitedCase,-1)<>3 THROW 57430,N'Required native synthetic or unlimited-limit cases incomplete.',1;
SELECT N'UPGRADE_FEATURE_USAGE_CONTRACT_PASS' AS [Result],@Case AS [NativeGroups],@FixtureCase AS [SyntheticSourceCases],CONVERT(bit,1) AS [OwnedCleanupConfirmed];
END;
GO
DECLARE @FixtureId int=OBJECT_ID(N'monitor.ExampleUpgradeRuntimeContract'),@FixtureHash varbinary(32),
 @OuterLock int=@@LOCK_TIMEOUT,@OuterAbort bit=CASE WHEN (@@OPTIONS&16384)<>0 THEN 1 ELSE 0 END,@OuterTx int=@@TRANCOUNT,@OuterDb int=DB_ID(),@FixtureFailure nvarchar(2048);
SELECT @FixtureHash=HASHBYTES('SHA2_256',[definition]) FROM sys.sql_modules WHERE [object_id]=@FixtureId;
BEGIN TRY
 EXEC [monitor].[ExampleUpgradeRuntimeContract];
 IF @@LOCK_TIMEOUT<>@OuterLock OR @@TRANCOUNT<>@OuterTx OR DB_ID()<>@OuterDb OR CASE WHEN (@@OPTIONS&16384)<>0 THEN 1 ELSE 0 END<>@OuterAbort THROW 57431,N'Outer caller options were not restored by fixture scope.',1;
END TRY
BEGIN CATCH SET @FixtureFailure=CONCAT(ERROR_NUMBER(),N': ',ERROR_MESSAGE());END CATCH;
IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE [object_id]=@FixtureId AND HASHBYTES('SHA2_256',[definition])=@FixtureHash AND [object_id]=OBJECT_ID(N'monitor.ExampleUpgradeRuntimeContract')) THROW 57432,N'Owned fixture procedure cleanup binding failed.',1;
DROP PROCEDURE [monitor].[ExampleUpgradeRuntimeContract];
IF @FixtureFailure IS NOT NULL THROW 57433,@FixtureFailure,1;
GO
