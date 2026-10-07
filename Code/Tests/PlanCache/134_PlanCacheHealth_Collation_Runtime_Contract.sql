USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
Datei: 134_PlanCacheHealth_Collation_Runtime_Contract.sql
Zweck: Prüft den vorhandenen Kategorienvertrag und die getrennten Detailmengen.
TABLE overview entspricht JSON categories; die Gesamtkennzahlen besitzen einen
anderen Vertrag. Nur Single-use-Details werden durch MaxZeilen begrenzt.
Nebenwirkungen: Keine Konfigurationsänderung, kein Workload und kein Snapshotowner.
Der Test liest den sichtbaren Cache. Bewegliche Cachewerte werden nur innerhalb
desselben Aufrufs verglichen; vollständige native Gegenproben liegen beim Runner.
Datenschutz: Die Abschlusszeile enthält keine Texte, Handles oder Detailwerte.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
SET LOCK_TIMEOUT 137;
IF CONVERT(sysname,DATABASEPROPERTYEX(DB_NAME(),'Collation'))<>N'SQL_Latin1_General_CP1_CS_AS'
    THROW 54950,N'HEALTH_FRAMEWORK_COLLATION',1;
CREATE TABLE [#ExampleHealthCategories]
(
    [CacheObjectType] nvarchar(34) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [ObjectType] nvarchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [PlanCount] bigint,
    [TotalSizeBytes] bigint,
    [SingleUsePlanCount] bigint,
    [SingleUseSizeBytes] bigint,
    [TotalUseCounts] bigint,
    [AverageUseCount] decimal(19,4)
);
CREATE TABLE [#ExampleHealthDatabases]
(
    [DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [PlanCount] bigint,
    [TotalSizeBytes] bigint,
    [SingleUsePlanCount] bigint
);
CREATE TABLE [#ExampleHealthSingle]
(
    [PlanHandle] varbinary(64),
    [CacheObjectType] nvarchar(34) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [ObjectType] nvarchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS,
    [UseCounts] int,
    [SizeBytes] int,
    [DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SqlTextCharacters] bigint NULL,
    [SqlTextBytes] bigint NULL,
    [SqlTextIsTruncated] bit NOT NULL DEFAULT(0),
    [SqlText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS
);
CREATE TABLE #ExampleHealthFieldKeys (ArrayName sysname COLLATE Latin1_General_100_BIN2, FieldName sysname COLLATE Latin1_General_100_BIN2, JsonType int);
INSERT #ExampleHealthFieldKeys VALUES
(N'categories',N'CacheObjectType',1),
(N'categories',N'ObjectType',1),
(N'categories',N'PlanCount',2),
(N'categories',N'TotalSizeBytes',2),
(N'categories',N'SingleUsePlanCount',2),
(N'categories',N'SingleUseSizeBytes',2),
(N'categories',N'TotalUseCounts',2),
(N'categories',N'AverageUseCount',2),
(N'databases',N'DatabaseId',2),
(N'databases',N'DatabaseName',1),
(N'databases',N'PlanCount',2),
(N'databases',N'TotalSizeBytes',2),
(N'databases',N'SingleUsePlanCount',2),
(N'singleUsePlans',N'PlanHandle',1),
(N'singleUsePlans',N'CacheObjectType',1),
(N'singleUsePlans',N'ObjectType',1),
(N'singleUsePlans',N'UseCounts',2),
(N'singleUsePlans',N'SizeBytes',2),
(N'singleUsePlans',N'DatabaseId',2),
(N'singleUsePlans',N'DatabaseName',1),
(N'singleUsePlans',N'SqlTextCharacters',2),
(N'singleUsePlans',N'SqlTextBytes',2),
(N'singleUsePlans',N'SqlTextIsTruncated',3),
(N'singleUsePlans',N'SqlText',1);
CREATE TABLE #ExampleHealthCases
(CaseId int PRIMARY KEY, Mode varchar(16), DbDetail bit, SingleDetail bit, RowLimit int NULL, TextLimit int NULL, HighImpact bit NULL, ExpectedStatus varchar(40));
INSERT #ExampleHealthCases VALUES
(0,'SUMMARY',0,0,NULL,4000,0,'AVAILABLE'),
(1,'SUMMARY',0,0,0,4000,0,'AVAILABLE'),
(2,'SUMMARY',0,0,1,4000,0,'AVAILABLE'),
(3,'SUMMARY',0,0,2,4000,0,'AVAILABLE'),
(4,'SUMMARY',0,0,2147483647,4000,0,'AVAILABLE'),
(5,'SUMMARY',0,0,-1,4000,0,'INVALID_PARAMETER'),
(6,'SUMMARY',0,0,1,-1,0,'INVALID_PARAMETER'),
(7,'ExampleInvalid',0,0,1,4000,0,'INVALID_PARAMETER'),
(8,'VOLL',0,0,1,4000,0,'HIGH_IMPACT_CONFIRMATION_REQUIRED'),
(9,'SUMMARY',0,1,1,4000,0,'HIGH_IMPACT_CONFIRMATION_REQUIRED'),
(10,'SUMMARY',0,1,1,4000,1,'INVALID_PARAMETER'),
(11,'SUMMARY',1,0,1,4000,1,'INVALID_PARAMETER'),
(12,'VOLL',0,0,1,4000,NULL,'INVALID_PARAMETER'),
(13,NULL,NULL,NULL,1,NULL,NULL,'AVAILABLE'),
(14,' summary ',0,0,1,0,0,'AVAILABLE'),
(15,'VOLL',0,0,1,4000,1,'AVAILABLE'),
(16,'VOLL',1,0,1,4000,1,'AVAILABLE'),
(17,'VOLL',0,1,1,1,1,'AVAILABLE'),
(18,'VOLL',1,1,2,0,1,'AVAILABLE'),
(19,'VOLL',0,1,0,NULL,1,'AVAILABLE');
DECLARE @Case int=0,@Mode varchar(16),@Db bit,@Single bit,@Limit int,@Text int,@High bit,@Status varchar(40),
        @Json nvarchar(max),@TableJson nvarchar(max),@Before datetime2(3),@After datetime2(3),@Map nvarchar(max)=N'{"overview":"#ExampleHealthTarget"}',
        @Core int=0,@Details int=0,@Consumers int=0,@Preflight int=0,@Parents int=0,@NullMutations int=0,@SqlConsolePositive int=0,@SqlConsoleEmpty int=0;
BEGIN TRY
WHILE @Case<20
BEGIN
    SELECT @Mode=Mode,@Db=DbDetail,@Single=SingleDetail,@Limit=RowLimit,@Text=TextLimit,@High=HighImpact,@Status=ExpectedStatus FROM #ExampleHealthCases WHERE CaseId=@Case;
    CREATE TABLE #ExampleHealthTarget (ExampleSeed int NULL);
    SET @Before=SYSUTCDATETIME(); SET @Json=NULL;
    EXEC monitor.USP_PlanCacheHealth @AnalyseModus=@Mode,@MitDatenbankVerteilung=@Db,@MitSingleUseDetails=@Single,
        @MaxZeilen=@Limit,@MaxSqlTextZeichen=@Text,@HighImpactConfirmed=@High,
        @ResultSetArt='TABLE',@ResultTablesJson=@Map,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    SET @After=SYSUTCDATETIME();
    IF @@LOCK_TIMEOUT<>137 THROW 54952,N'HEALTH_CALLER_TIMEOUT',1;
    IF (SELECT COUNT(*) FROM OPENJSON(@Json))<>6 OR EXISTS(SELECT [key] FROM OPENJSON(@Json) GROUP BY [key] HAVING COUNT(*)<>1)
       OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json) EXCEPT SELECT value FROM (VALUES(N'meta'),(N'overview'),(N'categories'),(N'databases'),(N'singleUsePlans'),(N'warnings'))k(value))
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [type]<>CASE WHEN [key] IN(N'meta',N'overview') THEN 5 ELSE 4 END)
       OR JSON_QUERY(@Json,'$.warnings')<>N'[]'
        THROW 54953,N'HEALTH_TOP_KEYS',1;
    IF (SELECT COUNT(*) FROM OPENJSON(@Json,'$.meta'))<>7 OR EXISTS(SELECT [key] FROM OPENJSON(@Json,'$.meta') GROUP BY [key] HAVING COUNT(*)<>1)
       OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,'$.meta') EXCEPT SELECT value FROM (VALUES(N'resultName'),(N'schemaVersion'),(N'generatedAtUtc'),(N'statusCode'),(N'isPartial'),(N'errorNumber'),(N'errorMessage'))k(value))
       OR JSON_VALUE(@Json,'$.meta.resultName')<>N'PlanCacheHealth' OR ISNULL(TRY_CONVERT(int,JSON_VALUE(@Json,'$.meta.schemaVersion')),0)<>1
       OR ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>@Status OR JSON_VALUE(@Json,'$.meta.isPartial')<>N'false'
       OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,'$.meta.generatedAtUtc')) IS NULL
       OR TRY_CONVERT(datetime2(3),JSON_VALUE(@Json,'$.meta.generatedAtUtc')) NOT BETWEEN @Before AND @After
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.meta') WHERE [type]<>CASE WHEN [key]=N'schemaVersion' THEN 2 WHEN [key]=N'isPartial' THEN 3 WHEN [key]=N'errorNumber' THEN 0 WHEN [key]=N'errorMessage' AND @Status='AVAILABLE' THEN 0 ELSE 1 END)
        THROW 54954,N'HEALTH_META_STATUS',1;
    IF EXISTS
    (SELECT ROW_NUMBER() OVER(ORDER BY column_id) ordinal,name,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID('tempdb..#ExampleHealthTarget')
     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID('tempdb..#ExampleHealthCategories'))
    OR EXISTS
    (SELECT ROW_NUMBER() OVER(ORDER BY column_id) ordinal,name,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID('tempdb..#ExampleHealthCategories')
     EXCEPT SELECT ROW_NUMBER() OVER(ORDER BY column_id),name,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name,is_identity FROM tempdb.sys.columns WHERE object_id=OBJECT_ID('tempdb..#ExampleHealthTarget'))
        THROW 54955,N'HEALTH_TABLE_8_SCHEMA',1;
    SELECT @TableJson=(SELECT * FROM #ExampleHealthTarget FOR JSON PATH,INCLUDE_NULL_VALUES);
    IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) n FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,'$.categories') GROUP BY value COLLATE Latin1_General_100_BIN2)
    OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) n FROM OPENJSON(@Json,'$.categories') GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2)
        THROW 54956,N'HEALTH_CATEGORIES_SAMECALL',1;
    IF EXISTS
    (SELECT 1 FROM OPENJSON(@Json) a CROSS APPLY OPENJSON(a.value) r WHERE a.[key] IN(N'categories',N'databases',N'singleUsePlans') AND
     (r.[type]<>5 OR (SELECT COUNT(*) FROM OPENJSON(r.value))<>(SELECT COUNT(*) FROM #ExampleHealthFieldKeys WHERE ArrayName=a.[key] COLLATE Latin1_General_100_BIN2)
      OR EXISTS(SELECT [key] FROM OPENJSON(r.value) GROUP BY [key] HAVING COUNT(*)<>1)
      OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2 FROM OPENJSON(r.value) EXCEPT SELECT FieldName FROM #ExampleHealthFieldKeys WHERE ArrayName=a.[key] COLLATE Latin1_General_100_BIN2)
      OR EXISTS(SELECT 1 FROM OPENJSON(r.value) f JOIN #ExampleHealthFieldKeys k ON k.ArrayName=a.[key] COLLATE Latin1_General_100_BIN2 AND k.FieldName=f.[key] COLLATE Latin1_General_100_BIN2 WHERE f.[type] NOT IN(0,k.JsonType) OR (f.[key]=N'SqlTextIsTruncated' AND f.[type]<>3))))
        THROW 54957,N'HEALTH_DETAIL_KEYS_TYPES',1;
    DECLARE @Overview nvarchar(max);
    SELECT @Overview=(SELECT COALESCE(SUM(PlanCount),0) planCount,COALESCE(SUM(TotalSizeBytes),0) totalSizeBytes,
        CONVERT(decimal(19,2),COALESCE(SUM(TotalSizeBytes),0)/1048576.0) totalSizeMb,COALESCE(SUM(SingleUsePlanCount),0) singleUsePlanCount,
        COALESCE(SUM(SingleUseSizeBytes),0) singleUseSizeBytes,CONVERT(decimal(9,2),100.0*SUM(SingleUseSizeBytes)/NULLIF(SUM(TotalSizeBytes),0)) singleUseMemoryPercent
        FROM OPENJSON(@TableJson) WITH(PlanCount bigint,TotalSizeBytes bigint,SingleUsePlanCount bigint,SingleUseSizeBytes bigint) x FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
    IF EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type],value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Overview) EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,[type],value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,'$.overview'))
       OR EXISTS(SELECT [key] COLLATE Latin1_General_100_BIN2,[type],value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Json,'$.overview') EXCEPT SELECT [key] COLLATE Latin1_General_100_BIN2,[type],value COLLATE Latin1_General_100_BIN2 FROM OPENJSON(@Overview))
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.overview'))<>6 OR EXISTS(SELECT [key] FROM OPENJSON(@Json,'$.overview') GROUP BY [key] HAVING COUNT(*)<>1)
        THROW 54958,N'HEALTH_OVERVIEW_INDEPENDENT_ARITHMETIC',1;
    IF @Status='AVAILABLE' AND NOT EXISTS(SELECT 1 FROM #ExampleHealthTarget) THROW 54959,N'HEALTH_VISIBLE_CACHE_POSITIVE',1;
    IF @Status<>'AVAILABLE' AND (EXISTS(SELECT 1 FROM #ExampleHealthTarget) OR JSON_QUERY(@Json,'$.databases')<>N'[]' OR JSON_QUERY(@Json,'$.singleUsePlans')<>N'[]') THROW 54960,N'HEALTH_INVALID_EMPTY',1;
    IF ISNULL(@Db,0)=0 AND JSON_QUERY(@Json,'$.databases')<>N'[]' THROW 54961,N'HEALTH_DB_OPTIN',1;
    IF ISNULL(@Single,0)=0 AND JSON_QUERY(@Json,'$.singleUsePlans')<>N'[]' THROW 54962,N'HEALTH_SINGLE_OPTIN',1;
    IF @Status='AVAILABLE' AND @Single=1 AND @Limit>0 AND (SELECT COUNT(*) FROM OPENJSON(@Json,'$.singleUsePlans'))>@Limit THROW 54963,N'HEALTH_DETAILS_ONLY_CAP',1;
    IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.singleUsePlans') WITH(UseCounts int,SqlText nvarchar(max),SqlTextCharacters bigint,SqlTextBytes bigint,SqlTextIsTruncated bit) s
        WHERE UseCounts>1 OR (SqlText IS NULL AND (SqlTextCharacters IS NOT NULL OR SqlTextBytes IS NOT NULL OR SqlTextIsTruncated<>0))
        OR (SqlText IS NOT NULL AND (SqlTextCharacters IS NULL OR SqlTextBytes IS NULL OR SqlTextBytes<DATALENGTH(SqlText) OR SqlTextCharacters<LEN((SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1
        OR (@Text>0 AND LEN((SqlText+NCHAR(1)) COLLATE Latin1_General_100_CI_AS_SC)-1>@Text))))
        THROW 54964,N'HEALTH_SINGLE_TEXT_COUNTS',1;
    IF @Case=0
    BEGIN
        DECLARE @Mutation int=0,@Mutated nvarchar(max),@MutationKey sysname;
        WHILE @Mutation<3
        BEGIN
            SET @MutationKey=CASE @Mutation WHEN 0 THEN N'CacheObjectType' WHEN 1 THEN N'ObjectType' ELSE N'PlanCount' END;
            SET @Mutated=JSON_MODIFY(@TableJson,N'strict $[0].'+@MutationKey,NULL);
            BEGIN TRY
                IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) n FROM OPENJSON(@Mutated) GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,'$.categories') GROUP BY value COLLATE Latin1_General_100_BIN2)
                OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) n FROM OPENJSON(@Json,'$.categories') GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Mutated) GROUP BY value COLLATE Latin1_General_100_BIN2)
                    THROW 54956,N'HEALTH_CATEGORIES_SAMECALL',1;
                THROW 54965,N'HEALTH_NULL_MUTATION_ACCEPTED',1;
            END TRY BEGIN CATCH
                IF ERROR_NUMBER()<>54956 THROW;
                SET @NullMutations+=1;
            END CATCH;
            SET @Mutation+=1;
        END;
    END;
    DROP TABLE #ExampleHealthTarget;
    SET @Core+=1; IF @Db=1 OR @Single=1 SET @Details+=1;
    SET @Case+=1;
END;

CREATE TABLE #ExampleHealthConsole
(Ergebnis nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 CacheObjectType nvarchar(34) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 ObjectType nvarchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 PlanCount bigint NULL,TotalSizeBytes bigint NULL,SingleUsePlanCount bigint NULL,SingleUseSizeBytes bigint NULL,TotalUseCounts bigint NULL,AverageUseCount decimal(19,4) NULL);
INSERT #ExampleHealthConsole EXEC monitor.USP_PlanCacheHealth @ResultSetArt='CONSOLE',@MaxZeilen=1,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
IF NOT EXISTS(SELECT 1 FROM #ExampleHealthConsole) OR EXISTS(SELECT 1 FROM #ExampleHealthConsole WHERE Ergebnis<>N'PlanCacheHealth' OR Ergebnis IS NULL)
    THROW 54966,N'HEALTH_POSITIVE_CONSOLE_LABEL',1;
SELECT @TableJson=(SELECT CacheObjectType,ObjectType,PlanCount,TotalSizeBytes,SingleUsePlanCount,SingleUseSizeBytes,TotalUseCounts,AverageUseCount FROM #ExampleHealthConsole FOR JSON PATH,INCLUDE_NULL_VALUES);
IF EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) n FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@Json,'$.categories') GROUP BY value COLLATE Latin1_General_100_BIN2)
OR EXISTS(SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) n FROM OPENJSON(@Json,'$.categories') GROUP BY value COLLATE Latin1_General_100_BIN2 EXCEPT SELECT value COLLATE Latin1_General_100_BIN2,COUNT_BIG(*) FROM OPENJSON(@TableJson) GROUP BY value COLLATE Latin1_General_100_BIN2)
    THROW 54967,N'HEALTH_POSITIVE_CONSOLE_SAMECALL',1;
SET @SqlConsolePositive+=1;
CREATE TABLE #ExampleHealthEmptyConsole (Ergebnis nvarchar(200),Status varchar(40),Hinweis nvarchar(2048));
INSERT #ExampleHealthEmptyConsole EXEC monitor.USP_PlanCacheHealth @MaxZeilen=-1,@ResultSetArt='CONSOLE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
IF (SELECT COUNT(*) FROM #ExampleHealthEmptyConsole)<>1 OR EXISTS(SELECT 1 FROM #ExampleHealthEmptyConsole WHERE Ergebnis IS NULL OR Ergebnis<>N'Keine fachlichen Ergebnisse' OR Status IS NOT NULL OR Hinweis IS NOT NULL)
    OR JSON_VALUE(@Json,'$.meta.statusCode')<>N'INVALID_PARAMETER' OR JSON_QUERY(@Json,'$.categories')<>N'[]'
    THROW 54968,N'HEALTH_EMPTY_CONSOLE',1;
SET @SqlConsoleEmpty+=1;
DECLARE @C int=0,@OutputMode varchar(16);
WHILE @C<3
BEGIN
    SET @OutputMode=CASE @C WHEN 0 THEN 'RAW' WHEN 1 THEN 'NONE' ELSE 'ExampleInvalid' END;
    EXEC monitor.USP_PlanCacheHealth @ResultSetArt=@OutputMode,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF ISNULL(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>CASE WHEN @C=2 THEN 'INVALID_PARAMETER' ELSE 'AVAILABLE' END
        THROW 54969,N'HEALTH_CONSUMER_STATUS',1;
    SET @Consumers+=1; SET @C+=1;
END;
CREATE TABLE #ExampleHealthHelp (ExampleSeed int NULL);
EXEC monitor.USP_PlanCacheHealth @ResultSetArt='TABLE',@ResultTablesJson=N'{"overview":"#ExampleHealthHelp"}',@Hilfe=1,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
IF @Json IS NOT NULL OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID('tempdb..#ExampleHealthHelp'))<>1 OR EXISTS(SELECT 1 FROM #ExampleHealthHelp)
    THROW 54970,N'HEALTH_HELP_SEED',1;
EXEC monitor.USP_PlanCacheHealth @ResultSetArt='NONE',@JsonErzeugen=NULL,@Json=@Json OUTPUT,@PrintMeldungen=0;
IF @Json IS NOT NULL THROW 54971,N'HEALTH_JSON_NULL_OPTION',1;
CREATE TABLE #ExampleHealthPreflight (ExampleSeed int NULL);
DECLARE @P int=0,@BadMap nvarchar(max),@BeforeRows bigint,@BadMode varchar(16),@BadHelp bit,@BadLimit int;
WHILE @P<8
BEGIN
    DELETE #ExampleHealthPreflight;
    IF @P=5 INSERT #ExampleHealthPreflight VALUES(4242);
    SELECT @BeforeRows=COUNT_BIG(*) FROM #ExampleHealthPreflight;
    SET @BadMap=CASE @P WHEN 0 THEN NULL WHEN 1 THEN N'{"unknown":"#ExampleHealthPreflight"}' WHEN 2 THEN N'{"overview":"#ExampleHealthAbsent"}'
        WHEN 3 THEN N'{"overview":"#ExampleHealthPreflight","overview":"#ExampleHealthPreflight"}' WHEN 4 THEN N'{"Overview":"#ExampleHealthPreflight"}'
        WHEN 6 THEN N'{"overview":1}' ELSE N'{"overview":"#ExampleHealthPreflight"}' END;
    SET @BadMode=CASE WHEN @P=7 THEN 'NONE' ELSE 'TABLE' END;
    SET @BadHelp=CASE WHEN @P=1 THEN 1 ELSE 0 END;
    SET @BadLimit=CASE WHEN @P=0 THEN -1 ELSE 1 END;
    SET @Json=N'ExampleSentinel';
    BEGIN TRY
        EXEC monitor.USP_PlanCacheHealth @ResultSetArt=@BadMode,@ResultTablesJson=@BadMap,@Hilfe=@BadHelp,@MaxZeilen=@BadLimit,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        THROW 54972,N'HEALTH_PREFLIGHT_ACCEPTED',1;
    END TRY BEGIN CATCH
        IF ERROR_NUMBER()<>51011 THROW;
        IF @Json<>N'ExampleSentinel' OR @Json IS NULL OR @@LOCK_TIMEOUT<>137
            OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID('tempdb..#ExampleHealthPreflight'))<>1
            OR (SELECT COUNT_BIG(*) FROM #ExampleHealthPreflight)<>@BeforeRows OR EXISTS(SELECT 1 FROM #ExampleHealthPreflight WHERE ExampleSeed<>4242)
            THROW 54973,N'HEALTH_PREFLIGHT_SEED_OUTPUT',1;
        SET @Preflight+=1;
    END CATCH;
    SET @P+=1;
END;
DECLARE @Parent int=0,@ParentMode varchar(16),@ParentOutput varchar(16),@Child nvarchar(max);
WHILE @Parent<4
BEGIN
    SET @ParentMode=CASE WHEN @Parent<2 THEN 'TOP' ELSE 'VOLL' END;
    SET @ParentOutput=CASE WHEN @Parent IN(0,2) THEN 'NONE' ELSE 'TABLE' END;
    IF @ParentOutput='TABLE'
        CREATE TABLE #ExampleHealthParent (ExampleSeed int NULL);
    SET @BadMap=CASE WHEN @ParentOutput='TABLE' THEN N'{"moduleStatus":"#ExampleHealthParent"}' ELSE NULL END;
    EXEC monitor.USP_PlanCacheAnalysis @MitQueryStats=0,@MitQueryHashAnalysis=0,@MitPlanCacheHealth=1,@MitShowplanAnalysis=0,
        @AnalyseModus=@ParentMode,@HighImpactConfirmed=1,@MaxZeilen=1,@ResultSetArt=@ParentOutput,@ResultTablesJson=@BadMap,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    SET @Child=JSON_QUERY(@Json,'$.planCacheHealth');
    IF ISJSON(@Child)<>1 OR ISNULL(JSON_VALUE(@Child,'$.meta.statusCode'),'')<>'AVAILABLE'
       OR JSON_QUERY(@Child,'$.categories') IS NULL OR JSON_QUERY(@Child,'$.singleUsePlans')<>N'[]' OR JSON_QUERY(@Child,'$.warnings')<>N'[]'
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.modules'))<>1
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.modules') WITH(ExecutionOrdinal int,ModuleName sysname,InvocationStatus varchar(40),ErrorNumber int,ErrorMessage nvarchar(2048))
            WHERE ExecutionOrdinal=3 AND ModuleName=N'USP_PlanCacheHealth' AND InvocationStatus='EXECUTED' AND ErrorNumber IS NULL AND ErrorMessage IS NULL)
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json) WHERE [key] IN(N'queryStats',N'queryHashes',N'showplan') AND [type]<>0)
        THROW 54974,N'HEALTH_ONLY_PARENT_CONTRACT',1;
    IF @ParentMode='TOP' AND JSON_QUERY(@Child,'$.databases')<>N'[]' THROW 54975,N'HEALTH_PARENT_TOP_DETAILS',1;
    IF @ParentOutput='TABLE'
    BEGIN
        SELECT @TableJson=(SELECT * FROM #ExampleHealthParent FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF @TableJson COLLATE Latin1_General_100_BIN2<>JSON_QUERY(@Json,'$.modules') COLLATE Latin1_General_100_BIN2 THROW 54976,N'HEALTH_PARENT_TABLE_JSON',1;
        DROP TABLE #ExampleHealthParent;
    END;
    SET @Parents+=1;SET @Parent+=1;
END;
IF @@LOCK_TIMEOUT<>137 THROW 54952,N'HEALTH_CALLER_TIMEOUT',1;
DECLARE @Restore nvarchar(80)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
EXEC(@Restore);
SELECT N'PASS' ContractStatus,@Core CoreCases,@Details DetailCases,@Consumers DirectConsumerCases,@Preflight PreflightCases,@Parents ParentCases,
    @NullMutations NullMutationRejections,@SqlConsolePositive PositiveSqlConsoleCases,@SqlConsoleEmpty EmptySqlConsoleCases,
    8 TableFields,2 TableTextCollations,24 LocalFields,7 LocalTextCollations;
END TRY
BEGIN CATCH
    DECLARE @RestoreOnError nvarchar(80)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC(@RestoreOnError);
    THROW;
END CATCH;
GO
