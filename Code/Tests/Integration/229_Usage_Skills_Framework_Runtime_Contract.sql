USE [DeineDatenbank];
GO

/*
Usage Skill native runtime contract. The metadata view documents source text; its rows
are not installation or permission attestations. This fixture uses only local #Temp
objects and Help calls. No diagnosis, source query or persistent write is requested.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'tempdb..#UsageSkillActual') IS NOT NULL
    THROW 59001,N'USAGE_SKILL_TEMP_COLLISION',1;
CREATE TABLE [#UsageSkillActual]
(
    [SkillFormatVersion] varchar(16) NULL,
    [SchemaName] sysname NULL,
    [ObjectName] sysname NULL,
    [SkillMarkdown] nvarchar(max) NULL
);

-- The catalog documents all framework sources. The Core installer leaves the
-- seven optional Snapshot Framework objects uninstalled; the canonical
-- Snapshot Target -> Framework fixture later exercises this file again with
-- all seven present. Mixed profiles are invalid.
DECLARE @SnapshotOptional TABLE
(
    [SchemaName] sysname NOT NULL,
    [ObjectName] sysname NOT NULL PRIMARY KEY,
    [ObjectType] varchar(24) NOT NULL
);
INSERT @SnapshotOptional([SchemaName],[ObjectName],[ObjectType]) VALUES
(N'monitor',N'SnapshotTargetConfiguration','TABLE'),
(N'monitor',N'InternalValidateSnapshotWaitTarget','INTERNAL_PROCEDURE'),
(N'monitor',N'USP_ConfigureSnapshotTarget','PROCEDURE'),
(N'monitor',N'InternalRunSnapshotWaitStatsCycle','INTERNAL_PROCEDURE'),
(N'monitor',N'InternalRunSnapshotFileIOCycle','INTERNAL_PROCEDURE'),
(N'monitor',N'USP_RunSnapshotCollectionCycle','PROCEDURE'),
(N'monitor',N'USP_PurgeSnapshotData','PROCEDURE');

DECLARE @SnapshotPresentCount int,@FullProfile bit,
        @RowBad int,@RoleBad int,@MetadataBad int,@OptionalCatalogBad int,
        @PresenceBad int,@RequiredMissing int,@TypeBad int,@DuplicateBad int;
SELECT @SnapshotPresentCount=COUNT(*)
FROM @SnapshotOptional AS [x]
JOIN [sys].[schemas] AS [s] ON [s].[name] COLLATE Latin1_General_100_BIN2
                              =[x].[SchemaName] COLLATE Latin1_General_100_BIN2
JOIN [sys].[objects] AS [o] ON [o].[schema_id]=[s].[schema_id]
                            AND [o].[name] COLLATE Latin1_General_100_BIN2
                               =[x].[ObjectName] COLLATE Latin1_General_100_BIN2;
SET @FullProfile=CASE WHEN @SnapshotPresentCount=7 THEN 1 ELSE 0 END;
SET @RowBad=CASE WHEN (SELECT COUNT_BIG(*) FROM [monitor_metadata].[VW_ObjectUsageSkills])=196 THEN 0 ELSE 1 END;
SET @RoleBad=CASE WHEN (SELECT COUNT_BIG(*) FROM [monitor_metadata].[VW_ObjectUsageSkills]
                       WHERE [DatabaseRole] IN ('framework','both'))=196 THEN 0 ELSE 1 END;
SELECT @MetadataBad=COUNT(*)
FROM [monitor_metadata].[VW_ObjectUsageSkills] AS [v]
WHERE [v].[SkillFormatVersion]<>'1.0.0' OR [v].[SkillFormatVersion] IS NULL
   OR [v].[Description] IS NULL OR NULLIF(LTRIM(RTRIM([v].[Description])),N'') IS NULL
   OR [v].[SkillMarkdown] IS NULL OR DATALENGTH([v].[SkillMarkdown])=0;
SELECT @OptionalCatalogBad=COUNT(*)
FROM @SnapshotOptional AS [x]
WHERE NOT EXISTS
(
    SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] AS [v]
    WHERE [v].[SchemaName] COLLATE Latin1_General_100_BIN2=[x].[SchemaName] COLLATE Latin1_General_100_BIN2
      AND [v].[ObjectName] COLLATE Latin1_General_100_BIN2=[x].[ObjectName] COLLATE Latin1_General_100_BIN2
      AND [v].[ObjectType]=[x].[ObjectType] AND [v].[DatabaseRole]='framework'
);
SET @PresenceBad=CASE WHEN @SnapshotPresentCount IN (0,7) THEN 0 ELSE 1 END;
SELECT @RequiredMissing=COUNT(*)
FROM [monitor_metadata].[VW_ObjectUsageSkills] AS [v]
WHERE (@FullProfile=1 OR NOT EXISTS
       (SELECT 1 FROM @SnapshotOptional AS [x]
        WHERE [x].[SchemaName] COLLATE Latin1_General_100_BIN2=[v].[SchemaName] COLLATE Latin1_General_100_BIN2
          AND [x].[ObjectName] COLLATE Latin1_General_100_BIN2=[v].[ObjectName] COLLATE Latin1_General_100_BIN2))
  AND NOT EXISTS
  (
      SELECT 1 FROM [sys].[objects] AS [o]
      JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id]
      WHERE [s].[name]=[v].[SchemaName] COLLATE DATABASE_DEFAULT
        AND [o].[name]=[v].[ObjectName] COLLATE DATABASE_DEFAULT
  );
SELECT @TypeBad=COUNT(*)
FROM [monitor_metadata].[VW_ObjectUsageSkills] AS [v]
WHERE EXISTS
(
    SELECT 1 FROM [sys].[objects] AS [o]
    JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id]
    WHERE [s].[name]=[v].[SchemaName] COLLATE DATABASE_DEFAULT
      AND [o].[name]=[v].[ObjectName] COLLATE DATABASE_DEFAULT
)
AND NOT EXISTS
(
    SELECT 1 FROM [sys].[objects] AS [o]
    JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id]
    WHERE [s].[name]=[v].[SchemaName] COLLATE DATABASE_DEFAULT
      AND [o].[name]=[v].[ObjectName] COLLATE DATABASE_DEFAULT
      AND (([v].[ObjectType]='TABLE' AND [o].[type]='U')
        OR ([v].[ObjectType]='VIEW' AND [o].[type]='V')
        OR ([v].[ObjectType] IN ('PROCEDURE','INTERNAL_PROCEDURE') AND [o].[type]='P')
        OR ([v].[ObjectType]='FUNCTION' AND [o].[type] IN ('FN','IF','TF')))
);
SELECT @DuplicateBad=COUNT(*)
FROM
(
    SELECT [SchemaName],[ObjectName]
    FROM [monitor_metadata].[VW_ObjectUsageSkills]
    GROUP BY [SchemaName],[ObjectName]
    HAVING COUNT_BIG(*)<>1
) AS [duplicates];
IF @RowBad<>0 OR @RoleBad<>0 OR @MetadataBad<>0 OR @OptionalCatalogBad<>0
   OR @PresenceBad<>0 OR @RequiredMissing<>0 OR @TypeBad<>0 OR @DuplicateBad<>0
BEGIN
    RAISERROR(N'USAGE_SKILL_ROLE_CATALOG row=%d role=%d metadata=%d optional=%d present=%d required_missing=%d type=%d duplicate=%d',
              10,1,@RowBad,@RoleBad,@MetadataBad,@OptionalCatalogBad,
              @SnapshotPresentCount,@RequiredMissing,@TypeBad,@DuplicateBad) WITH NOWAIT;
    THROW 59002,N'USAGE_SKILL_ROLE_CATALOG',1;
END;

DECLARE @PilotCount int=0;
IF NOT EXISTS (SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'USP_CurrentObjectPermissionAnalysis' AND [ObjectType]='PROCEDURE')
 OR NOT EXISTS (SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalWriteResultTable' AND [ObjectType]='INTERNAL_PROCEDURE')
 OR NOT EXISTS (SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'TVF_ParsePipeList' AND [ObjectType]='FUNCTION')
 OR NOT EXISTS (SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'VW_ModuleStatusCatalog' AND [ObjectType]='VIEW')
 OR NOT EXISTS (SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'FrameworkVersion' AND [ObjectType]='TABLE')
    THROW 59003,N'USAGE_SKILL_FIVE_TYPE_PILOT',1;
SET @PilotCount=5;
IF NOT EXISTS (SELECT 1 FROM [monitor].[FrameworkVersion])
 OR NOT EXISTS (SELECT 1 FROM [monitor].[VW_ModuleStatusCatalog] WHERE [StatusCode]='AVAILABLE')
 OR NOT EXISTS (SELECT 1 FROM [monitor].[TVF_ParsePipeList](N'UsageSkill')
                WHERE [ItemOrdinal]=1 AND [ItemText]=N'UsageSkill' AND [IsValid]=1)
    THROW 59022,N'USAGE_SKILL_FIVE_TYPE_PILOT_READ',1;
-- Independent UTF-16LE transport control: >4000 units, LF, quote, non-BMP, GO text.
DECLARE @SyntheticUnicode nvarchar(max)=REPLICATE(CONVERT(nvarchar(max),N'A'),4097)
    +NCHAR(10)+N'O''Brien'+CONVERT(nvarchar(max),0x3DD800DE)+NCHAR(10)+N'GO'+NCHAR(10);
IF DATALENGTH(@SyntheticUnicode)<>8222
 OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),@SyntheticUnicode))<>0x95518a6a562daf2bd920daabbf829094f21fca296329e2eda12dbc26bc8164c5
    THROW 59021,N'USAGE_SKILL_UNICODE_TRANSPORT_CONTROL',1;

-- Independently pinned UTF-16LE length and SHA-256 of seven canonical Markdown files.
-- The five type pilots and the longest Skill catch shared View/Help truncation.
DECLARE @CanonicalPilot TABLE([ObjectName] sysname PRIMARY KEY,[ExpectedBytes] bigint NOT NULL,[ExpectedSha] varbinary(32) NOT NULL);
INSERT @CanonicalPilot VALUES
(N'USP_CurrentObjectPermissionAnalysis',CONVERT(bigint,25040),0xf6e301e616229a733b6f52ed27dd28ac3794e62e0e2e81e6fafab130df9bc297),
(N'InternalWriteResultTable',CONVERT(bigint,35196),0xfbadb452dd7e883f826a9ad916ab6c33c42c5d5cfee9f2584dad43e44d33dd8a),
(N'TVF_ParsePipeList',CONVERT(bigint,5888),0x10eec0e891ef92f04c1ed218b2d279eaf1ff5e98e9c79ca9fa2d2224dec7b4a6),
(N'VW_ModuleStatusCatalog',CONVERT(bigint,7718),0x3cdf57076b7ec923c9424a743aca6238f45026bf112b0729d768240c9c22a8ae),
(N'FrameworkVersion',CONVERT(bigint,10402),0xb914a32160354a59f3f08208bf2e157bc33810b583d2e00900678fa328511bd0),
(N'USP_SsisPackageModelAnalysis',CONVERT(bigint,111392),0xa50ad055937b568f6c057bdae8d7be6a2bb8389fb41a752a4925ef5c40203468),
(N'InternalManageSsisHandoverReceipt',CONVERT(bigint,9604),0xf8ead827a4552956e0a117999bc1d3ae408116808cec6b2c2a99912484a52d89);
IF (SELECT COUNT_BIG(*) FROM @CanonicalPilot)<>7
 OR EXISTS
 (
   SELECT 1 FROM @CanonicalPilot AS [p]
   WHERE NOT EXISTS
   (
     SELECT 1 FROM [monitor_metadata].[VW_ObjectUsageSkills] AS [v]
     WHERE [v].[SchemaName]=N'monitor' AND [v].[ObjectName]=[p].[ObjectName]
       AND DATALENGTH([v].[SkillMarkdown])=[p].[ExpectedBytes]
       AND HASHBYTES('SHA2_256',CONVERT(varbinary(max),[v].[SkillMarkdown]))=[p].[ExpectedSha]
   )
 )
    THROW 59017,N'USAGE_SKILL_CANONICAL_TEXT_ORACLE',1;

DECLARE @ExpectedProcedureCount int=CASE WHEN @FullProfile=1 THEN 147 ELSE 141 END,@PilotProcedureCount int=2,
        @PilotPublic sysname=N'USP_CurrentObjectPermissionAnalysis',
        @PilotInternal sysname=N'InternalWriteResultTable';
IF (SELECT COUNT_BIG(*) FROM [monitor_metadata].[VW_ObjectUsageSkills] WHERE [ObjectType] IN ('PROCEDURE','INTERNAL_PROCEDURE'))<>147
    THROW 59004,N'USAGE_SKILL_PROCEDURE_POPULATION',1;

DECLARE @Stage int=0,@HelpCalls int=0,@Schema sysname,@Object sysname,@ObjectId int,
        @ExpectedMarkdown nvarchar(max),@ArgList nvarchar(max),@CallSql nvarchar(max),
        @BeforeDb int,@BeforeLogin int,@BeforeTran int,@BeforeLock int,@BeforeOptions int,@BeforeXact int,
        @AfterDb int,@AfterLogin int,@AfterTran int,@AfterLock int,@AfterOptions int,@AfterXact int;

WHILE @Stage<=1
BEGIN
    DECLARE [UsageSkillHelpCursor] CURSOR LOCAL FAST_FORWARD FOR
       SELECT [SchemaName],[ObjectName],[SkillMarkdown]
       FROM [monitor_metadata].[VW_ObjectUsageSkills]
       WHERE [ObjectType] IN ('PROCEDURE','INTERNAL_PROCEDURE')
         AND (@Stage=1 OR [ObjectName] IN (@PilotPublic,@PilotInternal))
          AND (@FullProfile=1 OR NOT EXISTS
               (SELECT 1 FROM @SnapshotOptional AS [x]
                WHERE [x].[SchemaName]=[VW_ObjectUsageSkills].[SchemaName]
                  AND [x].[ObjectName]=[VW_ObjectUsageSkills].[ObjectName]))
       ORDER BY [SchemaName],[ObjectName];
    OPEN [UsageSkillHelpCursor];
    FETCH NEXT FROM [UsageSkillHelpCursor] INTO @Schema,@Object,@ExpectedMarkdown;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @ObjectId=NULL;
        SELECT @ObjectId=[o].[object_id]
        FROM [sys].[objects] AS [o]
        JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id]
        WHERE [s].[name]=@Schema AND [o].[name]=@Object AND [o].[type]='P';
        IF @ObjectId IS NULL OR
           (SELECT COUNT_BIG(*) FROM [sys].[parameters]
            WHERE [object_id]=@ObjectId AND [name]=N'@Hilfe')<>1
        BEGIN
            CLOSE [UsageSkillHelpCursor];DEALLOCATE [UsageSkillHelpCursor];
            THROW 59006,N'USAGE_SKILL_HELP_SIGNATURE',1;
        END;
        SELECT @ArgList=STRING_AGG(CONVERT(nvarchar(max),[p].[name]+N'=NULL'),N',')
                        WITHIN GROUP (ORDER BY [p].[parameter_id])
        FROM [sys].[parameters] AS [p]
        WHERE [p].[object_id]=@ObjectId AND [p].[name]<>N'@Hilfe';
        SET @CallSql=N'EXEC '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Object)+N' '
                   +COALESCE(@ArgList+N',',N'')+N'@Hilfe=1;';
        DELETE FROM [#UsageSkillActual];
        SELECT @BeforeDb=DB_ID(),@BeforeLogin=SUSER_ID(),@BeforeTran=@@TRANCOUNT,
               @BeforeLock=@@LOCK_TIMEOUT,@BeforeOptions=(@@OPTIONS&16384);
        SELECT @BeforeXact=XACT_STATE();
        INSERT [#UsageSkillActual] ([SkillFormatVersion],[SchemaName],[ObjectName],[SkillMarkdown])
        EXEC [sys].[sp_executesql] @CallSql;
        SELECT @AfterDb=DB_ID(),@AfterLogin=SUSER_ID(),@AfterTran=@@TRANCOUNT,
               @AfterLock=@@LOCK_TIMEOUT,@AfterOptions=(@@OPTIONS&16384);
        SELECT @AfterXact=XACT_STATE();
        IF @AfterDb<>@BeforeDb OR @AfterLogin<>@BeforeLogin OR @AfterTran<>@BeforeTran
           OR @AfterLock<>@BeforeLock OR @AfterOptions<>@BeforeOptions OR @AfterXact<>@BeforeXact
           OR @AfterDb IS NULL OR @AfterLogin IS NULL
            THROW 59007,N'USAGE_SKILL_HELP_CALLER_STATE',1;
        IF (SELECT COUNT_BIG(*) FROM [#UsageSkillActual])<>1
           OR EXISTS
           (
             SELECT 1 FROM [#UsageSkillActual] AS [a]
             WHERE [a].[SkillFormatVersion]<>'1.0.0' OR [a].[SkillFormatVersion] IS NULL
                OR [a].[SchemaName] COLLATE Latin1_General_100_BIN2<>@Schema COLLATE Latin1_General_100_BIN2
                OR [a].[ObjectName] COLLATE Latin1_General_100_BIN2<>@Object COLLATE Latin1_General_100_BIN2
                OR [a].[SkillMarkdown] IS NULL
                OR DATALENGTH([a].[SkillMarkdown])<>DATALENGTH(@ExpectedMarkdown)
                OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),[a].[SkillMarkdown]))
                   <>HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ExpectedMarkdown))
           )
            THROW 59008,N'USAGE_SKILL_HELP_TEXT_PARITY',1;
        SET @HelpCalls+=1;
        FETCH NEXT FROM [UsageSkillHelpCursor] INTO @Schema,@Object,@ExpectedMarkdown;
    END;
    CLOSE [UsageSkillHelpCursor];DEALLOCATE [UsageSkillHelpCursor];
    SET @Stage+=1;
END;
IF @HelpCalls<>@ExpectedProcedureCount+@PilotProcedureCount
    THROW 59009,N'USAGE_SKILL_HELP_COVERAGE',1;
DECLARE @SentinelCalls TABLE([SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL,[CallSql] nvarchar(max) NOT NULL);
INSERT @SentinelCalls([SchemaName],[ObjectName],[CallSql]) VALUES
(N'monitor',N'InternalCheckAnalysisPath',N'DECLARE @u1 varchar(40)=''USAGE_SENTINEL'';DECLARE @u2 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass=NULL,@HighImpactConfirmed=NULL,@StatusCode=@u1 OUTPUT,@ErrorMessage=@u2 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalWriteResultTable',N'DECLARE @u1 bigint=CONVERT(bigint,17377);DECLARE @u2 varchar(40)=''USAGE_SENTINEL'';DECLARE @u3 int=CONVERT(int,1737);DECLARE @u4 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalWriteResultTable] @SourceTable=NULL,@TargetTable=NULL,@InsertedRows=@u1 OUTPUT,@StatusCode=@u2 OUTPUT,@ErrorNumber=@u3 OUTPUT,@ErrorMessage=@u4 OUTPUT,@ThrowOnError=NULL,@Hilfe=1;IF @u1 IS NULL OR @u1<>CONVERT(bigint,17377) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalPrepareResultTables',N'DECLARE @u1 varchar(40)=''USAGE_SENTINEL'';DECLARE @u2 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=NULL,@AllowedResultNames=NULL,@MappingTable=NULL,@StatusCode=@u1 OUTPUT,@ErrorMessage=@u2 OUTPUT,@ThrowOnError=NULL,@Hilfe=1;IF @u1 IS NULL OR @u1<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalPrepareSingleResultTable',N'DECLARE @u1 sysname=N''UsageSentinel'';EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=NULL,@ResultName=NULL,@TargetTable=@u1 OUTPUT,@ThrowOnError=NULL,@Hilfe=1;IF @u1 IS NULL OR @u1<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalEmitConsoleResult',N'EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=NULL,@ResultLabel=NULL,@EmptyMessage=NULL,@StatusCode=NULL,@StatusMessage=NULL,@Hilfe=1;'),
(N'monitor',N'InternalProjectUnicodeTextColumn',N'DECLARE @u1 bigint=CONVERT(bigint,17377);DECLARE @u2 bigint=CONVERT(bigint,17377);EXEC [monitor].[InternalProjectUnicodeTextColumn] @SourceTable=NULL,@TextColumn=NULL,@CharactersColumn=NULL,@BytesColumn=NULL,@IsTruncatedColumn=NULL,@MaxCharacters=NULL,@TruncatedValueCount=@u1 OUTPUT,@LargestRequiredCharacters=@u2 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1<>CONVERT(bigint,17377) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>CONVERT(bigint,17377) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalEmitTruncationWarning',N'EXEC [monitor].[InternalEmitTruncationWarning] @TruncatedValueCount=NULL,@ParameterName=NULL,@ParameterValue=NULL,@LargestRequiredCharacters=NULL,@PrintMeldungen=NULL,@Hilfe=1;'),
(N'monitor',N'InternalParseXmlText',N'SET QUOTED_IDENTIFIER ON;DECLARE @u1 xml=CONVERT(xml,N''<usage/>'');DECLARE @u2 varchar(40)=''USAGE_SENTINEL'';DECLARE @u3 int=CONVERT(int,1737);DECLARE @u4 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalParseXmlText] @XmlText=NULL,@XmlValue=@u1 OUTPUT,@StatusCode=@u2 OUTPUT,@ErrorNumber=@u3 OUTPUT,@ErrorMessage=@u4 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1.exist(''/usage[1]'')<>1 THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalCaptureCurrentStateSnapshot',N'EXEC [monitor].[InternalCaptureCurrentStateSnapshot] @SnapshotId=NULL,@CaptureSessions=NULL,@CaptureRequests=NULL,@CaptureConnections=NULL,@CaptureWaitingTasks=NULL,@CaptureMemoryGrants=NULL,@CaptureResourceGovernor=NULL,@CaptureTasks=NULL,@CaptureSchedulers=NULL,@CaptureTransactions=NULL,@CaptureTempDbUsage=NULL,@CaptureVersionStore=NULL,@CaptureSqlText=NULL,@MaxSqlTextHandles=NULL,@Hilfe=1;'),
(N'monitor',N'InternalCollectExecutionPlanMetadata',N'DECLARE @u1 varchar(40)=''USAGE_SENTINEL'';DECLARE @u2 bit=CONVERT(bit,1);DECLARE @u3 int=CONVERT(int,1737);DECLARE @u4 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalCollectExecutionPlanMetadata] @PlanXml=NULL,@StatistikEvidenzModus=NULL,@HistogrammModus=NULL,@QuellumgebungBestaetigt=NULL,@MitPredicateHistogramMap=NULL,@MaxStatistiken=NULL,@MaxHistogrammSchritte=NULL,@LockTimeoutMs=NULL,@HighImpactConfirmed=NULL,@StatusCodeOut=@u1 OUTPUT,@IsPartialOut=@u2 OUTPUT,@ErrorNumberOut=@u3 OUTPUT,@ErrorMessageOut=@u4 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalAnalyzeExecutionPlan',N'DECLARE @u1 varchar(40)=''USAGE_SENTINEL'';DECLARE @u2 bit=CONVERT(bit,1);DECLARE @u3 int=CONVERT(int,1737);DECLARE @u4 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalAnalyzeExecutionPlan] @AnalysisObjectId=NULL,@PlanXml=NULL,@PlanSource=NULL,@RuntimeCounterScope=NULL,@WorkloadProfile=NULL,@MinSeverity=NULL,@EvidenceJson=NULL,@MitThreadRuntime=NULL,@EvidenzDatenschutzModus=NULL,@IdentifierDatenschutzModus=NULL,@SourceObservedAtUtc=NULL,@ParameterEvidenceSessionId=NULL,@ParameterEvidenceRequestId=NULL,@PlanHandle=NULL,@QueryStoreDatabaseName=NULL,@QueryStorePlanId=NULL,@StatusCodeOut=@u1 OUTPUT,@IsPartialOut=@u2 OUTPUT,@ErrorNumberOut=@u3 OUTPUT,@ErrorMessageOut=@u4 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalSsisExecutionScopes',N'DECLARE @u1 nvarchar(max)=N''UsageSentinel'';DECLARE @u2 varchar(40)=''USAGE_SENTINEL'';DECLARE @u3 bit=CONVERT(bit,1);DECLARE @u4 int=CONVERT(int,1737);DECLARE @u5 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalSsisExecutionScopes] @IncludePipelineCorrelation=NULL,@Models=NULL,@Capture=NULL,@Handover=NULL,@ExecutionId=NULL,@MaxZeilen=NULL,@MaxDurationSeconds=NULL,@LockTimeoutMs=NULL,@ResultSetArt=NULL,@ResultTablesJson=NULL,@JsonErzeugen=NULL,@Json=@u1 OUTPUT,@StatusCodeOut=@u2 OUTPUT,@IsPartialOut=@u3 OUTPUT,@ErrorNumberOut=@u4 OUTPUT,@ErrorMessageOut=@u5 OUTPUT,@IncludePipelineDiagnostics=NULL,@PipelinePhaseThresholdMs=NULL,@Hilfe=1;IF @u1 IS NULL OR @u1<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u5 IS NULL OR @u5<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalManageSsisHandoverReceipt',N'EXEC [monitor].[InternalManageSsisHandoverReceipt] @Action=NULL,@Hilfe=1;'),
(N'monitor',N'InternalSsisPipelineCorrelation',N'EXEC [monitor].[InternalSsisPipelineCorrelation] @Models=NULL,@Capture=NULL,@Bound=NULL,@Deadline=NULL,@Limit=NULL,@Hilfe=1;'),
(N'monitor',N'InternalSsisPipelineDiagnostics',N'EXEC [monitor].[InternalSsisPipelineDiagnostics] @Models=NULL,@Bound=NULL,@Deadline=NULL,@Limit=NULL,@PipelinePhaseThresholdMs=NULL,@Hilfe=1;'),
(N'monitor',N'InternalValidateSnapshotWaitTarget',N'DECLARE @u1 int=CONVERT(int,1737);DECLARE @u2 datetime=CONVERT(datetime,''20010101'',112);DECLARE @u3 varchar(40)=''USAGE_SENTINEL'';DECLARE @u4 int=CONVERT(int,1737);DECLARE @u5 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalValidateSnapshotWaitTarget] @TargetDatabaseName=NULL,@ExpectedTargetDatabaseId=NULL,@ExpectedTargetCreateDate=NULL,@TargetDatabaseIdOut=@u1 OUTPUT,@TargetCreateDateOut=@u2 OUTPUT,@StatusCodeOut=@u3 OUTPUT,@ErrorNumberOut=@u4 OUTPUT,@ErrorMessageOut=@u5 OUTPUT,@CollectorCode=NULL,@Hilfe=1;IF @u1 IS NULL OR @u1<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>CONVERT(datetime,''20010101'',112) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u5 IS NULL OR @u5<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalRunSnapshotWaitStatsCycle',N'DECLARE @u1 bigint=CONVERT(bigint,17377);DECLARE @u2 sysname=N''UsageSentinel'';DECLARE @u3 varchar(40)=''USAGE_SENTINEL'';DECLARE @u4 bit=CONVERT(bit,1);DECLARE @u5 int=CONVERT(int,1737);DECLARE @u6 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalRunSnapshotWaitStatsCycle] @SchedulerType=NULL,@RunEvenIfNotDue=NULL,@CaptureRunIdOut=@u1 OUTPUT,@TargetDatabaseNameOut=@u2 OUTPUT,@StatusCodeOut=@u3 OUTPUT,@IsPartialOut=@u4 OUTPUT,@ErrorNumberOut=@u5 OUTPUT,@ErrorMessageOut=@u6 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1<>CONVERT(bigint,17377) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u5 IS NULL OR @u5<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u6 IS NULL OR @u6<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalRunSnapshotFileIOCycle',N'DECLARE @u1 bigint=CONVERT(bigint,17377);DECLARE @u2 sysname=N''UsageSentinel'';DECLARE @u3 varchar(40)=''USAGE_SENTINEL'';DECLARE @u4 bit=CONVERT(bit,1);DECLARE @u5 int=CONVERT(int,1737);DECLARE @u6 nvarchar(2048)=N''UsageSentinel'';EXEC [monitor].[InternalRunSnapshotFileIOCycle] @SchedulerType=NULL,@RunEvenIfNotDue=NULL,@CaptureRunIdOut=@u1 OUTPUT,@TargetDatabaseNameOut=@u2 OUTPUT,@StatusCodeOut=@u3 OUTPUT,@IsPartialOut=@u4 OUTPUT,@ErrorNumberOut=@u5 OUTPUT,@ErrorMessageOut=@u6 OUTPUT,@DatabaseNames=NULL,@SystemdatenbankenEinbeziehen=NULL,@DatabaseNamePattern=NULL,@Hilfe=1;IF @u1 IS NULL OR @u1<>CONVERT(bigint,17377) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u5 IS NULL OR @u5<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u6 IS NULL OR @u6<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;'),
(N'monitor',N'InternalSsisExecutionMetrics',N'DECLARE @u1 nvarchar(max)=N''UsageSentinel'';DECLARE @u2 varchar(40)=''USAGE_SENTINEL'';DECLARE @u3 bit=CONVERT(bit,1);DECLARE @u4 bit=CONVERT(bit,1);DECLARE @u5 nvarchar(max)=N''UsageSentinel'';DECLARE @u6 int=CONVERT(int,1737);DECLARE @u7 varchar(64)=''USAGE_SENTINEL'';EXEC [monitor].[InternalSsisExecutionMetrics] @RunOrdinal=NULL,@Models=NULL,@Capture=NULL,@HandoverId=NULL,@ExecutionId=NULL,@Deadline=NULL,@LockTimeoutMs=NULL,@AnalysisJson=@u1 OUTPUT,@StatusCodeOut=@u2 OUTPUT,@Use32BitRuntimeOut=@u3 OUTPUT,@BoundOut=@u4 OUTPUT,@MetricsJson=@u5 OUTPUT,@ErrorNumberOut=@u6 OUTPUT,@ReasonCodeOut=@u7 OUTPUT,@Hilfe=1;IF @u1 IS NULL OR @u1<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u2 IS NULL OR @u2<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u3 IS NULL OR @u3<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u4 IS NULL OR @u4<>CONVERT(bit,1) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u5 IS NULL OR @u5<>N''UsageSentinel'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u6 IS NULL OR @u6<>CONVERT(int,1737) THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;IF @u7 IS NULL OR @u7<>''USAGE_SENTINEL'' THROW 59005,N''USAGE_HELP_OUTPUT_SENTINEL'',1;');
IF (SELECT COUNT_BIG(*) FROM @SentinelCalls)<>19
    THROW 59010,N'USAGE_SKILL_OUTPUT_CONTRACT_COUNT',1;
DECLARE @SentinelCount int=0;
DECLARE [UsageSkillSentinelCursor] CURSOR LOCAL FAST_FORWARD FOR
 SELECT [SchemaName],[ObjectName],[CallSql] FROM @SentinelCalls AS [c]
 WHERE @FullProfile=1 OR NOT EXISTS
       (SELECT 1 FROM @SnapshotOptional AS [x]
        WHERE [x].[SchemaName]=[c].[SchemaName] AND [x].[ObjectName]=[c].[ObjectName])
 ORDER BY [SchemaName],[ObjectName];
OPEN [UsageSkillSentinelCursor];
FETCH NEXT FROM [UsageSkillSentinelCursor] INTO @Schema,@Object,@CallSql;
WHILE @@FETCH_STATUS=0
BEGIN
    SELECT @ExpectedMarkdown=[SkillMarkdown]
    FROM [monitor_metadata].[VW_ObjectUsageSkills]
    WHERE [SchemaName]=@Schema AND [ObjectName]=@Object AND [ObjectType]='INTERNAL_PROCEDURE';
    DELETE FROM [#UsageSkillActual];
    -- Compare the caller's QI and XACT_ABORT bits after the scoped XML parse.
    SELECT @BeforeDb=DB_ID(),@BeforeLogin=SUSER_ID(),@BeforeTran=@@TRANCOUNT,
           @BeforeLock=@@LOCK_TIMEOUT,@BeforeOptions=(@@OPTIONS&16640);
    SELECT @BeforeXact=XACT_STATE();
    INSERT [#UsageSkillActual] ([SkillFormatVersion],[SchemaName],[ObjectName],[SkillMarkdown])
    EXEC [sys].[sp_executesql] @CallSql;
    SELECT @AfterDb=DB_ID(),@AfterLogin=SUSER_ID(),@AfterTran=@@TRANCOUNT,
           @AfterLock=@@LOCK_TIMEOUT,@AfterOptions=(@@OPTIONS&16640);
    SELECT @AfterXact=XACT_STATE();
    IF @AfterDb<>@BeforeDb OR @AfterLogin<>@BeforeLogin OR @AfterTran<>@BeforeTran
       OR @AfterLock<>@BeforeLock OR @AfterOptions<>@BeforeOptions OR @AfterXact<>@BeforeXact
       OR @AfterDb IS NULL OR @AfterLogin IS NULL
        THROW 59011,N'USAGE_SKILL_OUTPUT_CALLER_STATE',1;
    IF @ExpectedMarkdown IS NULL OR (SELECT COUNT_BIG(*) FROM [#UsageSkillActual])<>1
       OR EXISTS (SELECT 1 FROM [#UsageSkillActual] AS [a]
          WHERE [a].[SkillFormatVersion]<>'1.0.0' OR [a].[SkillFormatVersion] IS NULL
             OR [a].[SchemaName] COLLATE Latin1_General_100_BIN2<>@Schema COLLATE Latin1_General_100_BIN2
             OR [a].[ObjectName] COLLATE Latin1_General_100_BIN2<>@Object COLLATE Latin1_General_100_BIN2
             OR [a].[SkillMarkdown] IS NULL OR DATALENGTH([a].[SkillMarkdown])<>DATALENGTH(@ExpectedMarkdown)
             OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),[a].[SkillMarkdown]))
                <>HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ExpectedMarkdown)))
        THROW 59012,N'USAGE_SKILL_OUTPUT_HELP_PARITY',1;
    SET @SentinelCount+=1;
    FETCH NEXT FROM [UsageSkillSentinelCursor] INTO @Schema,@Object,@CallSql;
END;
CLOSE [UsageSkillSentinelCursor];DEALLOCATE [UsageSkillSentinelCursor];
IF @SentinelCount<>CASE WHEN @FullProfile=1 THEN 19 ELSE 16 END THROW 59013,N'USAGE_SKILL_OUTPUT_COVERAGE',1;
-- SQL still binds required arguments even when the early Help branch would return.
BEGIN TRY
    EXEC [monitor].[InternalWriteResultTable] @Hilfe=1;
    THROW 59014,N'USAGE_SKILL_REQUIRED_BINDING_NOT_ENFORCED',1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()<>201 THROW;
END CATCH;

-- A type-valid but fachlich invalid TABLE request must return Help before its preflight.
DELETE FROM [#UsageSkillActual];
INSERT [#UsageSkillActual] ([SkillFormatVersion],[SchemaName],[ObjectName],[SkillMarkdown])
EXEC [monitor].[USP_CurrentObjectPermissionAnalysis]
     @SchemaName=N'',@ObjectName=N'',@ResultSetArt='TABLE',
     @ResultTablesJson=N'not-json',@Hilfe=1;
IF (SELECT COUNT_BIG(*) FROM [#UsageSkillActual])<>1
 OR NOT EXISTS
 (
   SELECT 1 FROM [#UsageSkillActual] AS [a]
   JOIN [monitor_metadata].[VW_ObjectUsageSkills] AS [v]
     ON [v].[SchemaName]=N'monitor' AND [v].[ObjectName]=N'USP_CurrentObjectPermissionAnalysis'
   WHERE [a].[SchemaName]=N'monitor' AND [a].[ObjectName]=N'USP_CurrentObjectPermissionAnalysis'
     AND [a].[SkillFormatVersion]='1.0.0'
     AND [a].[SkillMarkdown] IS NOT NULL
     AND DATALENGTH([a].[SkillMarkdown])=DATALENGTH([v].[SkillMarkdown])
     AND HASHBYTES('SHA2_256',CONVERT(varbinary(max),[a].[SkillMarkdown]))
        =HASHBYTES('SHA2_256',CONVERT(varbinary(max),[v].[SkillMarkdown]))
 )
    THROW 59015,N'USAGE_SKILL_EARLY_HELP_TABLE',1;

-- Existing public Help paths reset the five OUTPUT receivers before returning.
DECLARE @PublicJson nvarchar(max),@PublicStatus varchar(40),@PublicPartial bit,
        @PublicError int,@PublicMessage nvarchar(4000),@PublicName sysname;
DECLARE @PublicCase int,@PublicJsonBad int,@PublicStatusBad int,@PublicPartialBad int,
        @PublicErrorBad int,@PublicMessageBad int,@PublicRowsBad int,@PublicTextBad int;
DECLARE [UsageSkillPublicSentinelCursor] CURSOR LOCAL FAST_FORWARD FOR
 SELECT [ObjectName] FROM (VALUES
    (N'USP_SsisLegacyLogAnalysis'),
    (N'USP_SsisCatalogExecutionAnalysis'),
    (N'USP_CurrentObjectPermissionAnalysis')) AS [p]([ObjectName]);
OPEN [UsageSkillPublicSentinelCursor];
FETCH NEXT FROM [UsageSkillPublicSentinelCursor] INTO @PublicName;
WHILE @@FETCH_STATUS=0
BEGIN
    SELECT @PublicJson=N'UsageSentinel',@PublicStatus='USAGE_SENTINEL',@PublicPartial=1,
           @PublicError=1737,@PublicMessage=N'UsageSentinel';
    DELETE FROM [#UsageSkillActual];
    IF @PublicName=N'USP_SsisLegacyLogAnalysis'
    BEGIN
        INSERT [#UsageSkillActual] EXEC [monitor].[USP_SsisLegacyLogAnalysis]
             @Hilfe=1,@Json=@PublicJson OUTPUT,@StatusCodeOut=@PublicStatus OUTPUT,
             @IsPartialOut=@PublicPartial OUTPUT,@ErrorNumberOut=@PublicError OUTPUT,
             @ErrorMessageOut=@PublicMessage OUTPUT;
    END
    ELSE IF @PublicName=N'USP_SsisCatalogExecutionAnalysis'
    BEGIN
        INSERT [#UsageSkillActual] EXEC [monitor].[USP_SsisCatalogExecutionAnalysis]
             @Hilfe=1,@Json=@PublicJson OUTPUT,@StatusCodeOut=@PublicStatus OUTPUT,
             @IsPartialOut=@PublicPartial OUTPUT,@ErrorNumberOut=@PublicError OUTPUT,
             @ErrorMessageOut=@PublicMessage OUTPUT;
    END
    ELSE
    BEGIN
        INSERT [#UsageSkillActual] EXEC [monitor].[USP_CurrentObjectPermissionAnalysis]
             @SchemaName=N'',@ObjectName=N'',@Hilfe=1,
             @Json=@PublicJson OUTPUT,@StatusCodeOut=@PublicStatus OUTPUT,
             @IsPartialOut=@PublicPartial OUTPUT,@ErrorNumberOut=@PublicError OUTPUT,
             @ErrorMessageOut=@PublicMessage OUTPUT;
    END
    -- CurrentObjectPermissionAnalysis has always returned AVAILABLE/0 on
    -- Help; the two SSIS Help paths reset all five OUTPUT receivers to NULL.
    SELECT @PublicCase=CASE @PublicName
               WHEN N'USP_CurrentObjectPermissionAnalysis' THEN 1
               WHEN N'USP_SsisLegacyLogAnalysis' THEN 2
               WHEN N'USP_SsisCatalogExecutionAnalysis' THEN 3 ELSE 0 END,
           @PublicJsonBad=CASE WHEN @PublicJson IS NULL THEN 0 ELSE 1 END,
           @PublicStatusBad=CASE
               WHEN @PublicName=N'USP_CurrentObjectPermissionAnalysis'
                   THEN CASE WHEN @PublicStatus IS NULL OR @PublicStatus<>'AVAILABLE' THEN 1 ELSE 0 END
               ELSE CASE WHEN @PublicStatus IS NULL THEN 0 ELSE 1 END END,
           @PublicPartialBad=CASE
               WHEN @PublicName=N'USP_CurrentObjectPermissionAnalysis'
                   THEN CASE WHEN @PublicPartial IS NULL OR @PublicPartial<>0 THEN 1 ELSE 0 END
               ELSE CASE WHEN @PublicPartial IS NULL THEN 0 ELSE 1 END END,
           @PublicErrorBad=CASE WHEN @PublicError IS NULL THEN 0 ELSE 1 END,
           @PublicMessageBad=CASE WHEN @PublicMessage IS NULL THEN 0 ELSE 1 END,
           @PublicRowsBad=CASE WHEN (SELECT COUNT_BIG(*) FROM [#UsageSkillActual])=1 THEN 0 ELSE 1 END,
           @PublicTextBad=CASE WHEN EXISTS
           (
             SELECT 1 FROM [#UsageSkillActual] AS [a]
             JOIN [monitor_metadata].[VW_ObjectUsageSkills] AS [v]
               ON [v].[SchemaName]=N'monitor' AND [v].[ObjectName]=@PublicName
             WHERE [a].[SchemaName]=N'monitor' AND [a].[ObjectName]=@PublicName
               AND [a].[SkillFormatVersion]='1.0.0'
               AND [a].[SkillMarkdown] IS NOT NULL
               AND DATALENGTH([a].[SkillMarkdown])=DATALENGTH([v].[SkillMarkdown])
               AND HASHBYTES('SHA2_256',CONVERT(varbinary(max),[a].[SkillMarkdown]))
                  =HASHBYTES('SHA2_256',CONVERT(varbinary(max),[v].[SkillMarkdown]))
           ) THEN 0 ELSE 1 END;
    IF @PublicCase=0 OR @PublicJsonBad<>0 OR @PublicStatusBad<>0
       OR @PublicPartialBad<>0 OR @PublicErrorBad<>0 OR @PublicMessageBad<>0
       OR @PublicRowsBad<>0 OR @PublicTextBad<>0
    BEGIN
        RAISERROR(N'USAGE_SKILL_PUBLIC_HELP_OUTPUT case=%d json=%d status=%d partial=%d error=%d message=%d rows=%d text=%d',
                  10,1,@PublicCase,@PublicJsonBad,@PublicStatusBad,@PublicPartialBad,
                  @PublicErrorBad,@PublicMessageBad,@PublicRowsBad,@PublicTextBad) WITH NOWAIT;
        THROW 59016,N'USAGE_SKILL_PUBLIC_HELP_OUTPUT',1;
    END;
    FETCH NEXT FROM [UsageSkillPublicSentinelCursor] INTO @PublicName;
END;
CLOSE [UsageSkillPublicSentinelCursor];DEALLOCATE [UsageSkillPublicSentinelCursor];

-- Probe the early Help branch in an owned transaction and nondefault lock frame.
DECLARE @OuterXactBefore int;
SELECT @OuterXactBefore=XACT_STATE();
IF @@TRANCOUNT<>0 OR @OuterXactBefore<>0 OR (@@OPTIONS&2)<>0
    THROW 59018,N'USAGE_SKILL_CALLER_PROBE_PRECONDITION',1;
DECLARE @OuterLock int=@@LOCK_TIMEOUT,@OuterDb int=DB_ID(),@OuterLogin int=SUSER_ID(),
        @OuterOptions int=(@@OPTIONS&16384);
DELETE FROM [#UsageSkillActual];
EXEC [sys].[sp_executesql] N'
    SET LOCK_TIMEOUT 43;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @DbBefore int=DB_ID(),@LoginBefore int=SUSER_ID(),
                @TxBefore int=@@TRANCOUNT,@LockBefore int=@@LOCK_TIMEOUT,
                @OptionsBefore int=(@@OPTIONS&16384),@XactBefore int;
        SELECT @XactBefore=XACT_STATE();
        INSERT [#UsageSkillActual] EXEC [monitor].[USP_CurrentObjectPermissionAnalysis]
            @SchemaName=N'''',@ObjectName=N'''',@ResultSetArt=''TABLE'',
            @ResultTablesJson=N''not-json'',@Hilfe=1;
        DECLARE @DbAfter int=DB_ID(),@LoginAfter int=SUSER_ID(),
                @TxAfter int=@@TRANCOUNT,@LockAfter int=@@LOCK_TIMEOUT,
                @OptionsAfter int=(@@OPTIONS&16384),@XactAfter int;
        SELECT @XactAfter=XACT_STATE();
        IF @TxBefore<>1 OR @XactBefore<>1 OR @LockBefore<>43
           OR @DbAfter<>@DbBefore OR @LoginAfter<>@LoginBefore
           OR @TxAfter<>@TxBefore OR @LockAfter<>@LockBefore
           OR @OptionsAfter<>@OptionsBefore OR @XactAfter<>@XactBefore
           OR (SELECT COUNT_BIG(*) FROM [#UsageSkillActual])<>1
            THROW 59019,N''USAGE_SKILL_HELP_OWN_TRANSACTION_CALLER'',1;
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;';
DECLARE @OuterXactAfter int;
SELECT @OuterXactAfter=XACT_STATE();
IF @@TRANCOUNT<>0 OR @OuterXactAfter<>0 OR @@LOCK_TIMEOUT<>@OuterLock
   OR DB_ID()<>@OuterDb OR SUSER_ID()<>@OuterLogin
   OR (@@OPTIONS&16384)<>@OuterOptions
    THROW 59020,N'USAGE_SKILL_HELP_OUTER_CALLER_RESTORE',1;

DROP TABLE [#UsageSkillActual];
PRINT N'USAGE_SKILL_FRAMEWORK_RUNTIME_CONTRACT PASS';
GO
