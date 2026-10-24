USE [DeineDatenbank];
GO

/*
Objekt: monitor.USP_SsisPackageModelAnalysis; Version 1.0.0; Stand 2026-10-25.
Zweck: Validiert ein optional zugeliefertes neutrales SSIS-Modell ohne CLR.
Quelle: Ausschließlich Caller-JSON und optionale Originalbytes; kein Paket-SQL.
Vertrag: SSIS_Analyze_Toolbelt_Exchange_Contract.md; Schema aus Toolbelt.
Grenzen: 16 MiB JSON/Bytes, 32 JSON-Ebenen, 20000 Knoten, 50000 Kanten;
         kooperatives Zeitbudget. Producerangaben bleiben UNVERIFIED.
Seiteneffekte: Eigene lokale Temp-Tabellen und explizite TABLE-Ausgabeziele.
Die BIN2-Vergleiche gelten nur für den ordinalen Austauschvertrag; native
Resultsets behalten die explizite Frameworkcollation.
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_SsisPackageModelAnalysis]
      @PackageModelJson nvarchar(max) = NULL
    , @PackageBytes varbinary(max) = NULL
    , @MaxZeilen int = 1000
    , @MaxDurationSeconds int = 30
    , @LockTimeoutMs int = 0
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json=NULL;
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_SsisPackageModelAnalysis: natives SSIS-Modell 1.0.0; kein CLR, Toolbelt- oder Dateizugriff.';
        PRINT N'@PackageModelJson erforderlich; @PackageBytes optional zum unabhängigen Bytevergleich. ProducerTrust bleibt UNVERIFIED.';
        PRINT N'CONSOLE|RAW|TABLE|NONE; JSON über OUTPUT. TABLE-Namen: moduleStatus|sourceBinding|nodes|edges|coverage|findings|sourceStatus|warnings.';
        RETURN;
    END;
    IF XACT_STATE()=-1 THROW 50000,N'EXCHANGE_INVALID: Callertransaktion ist nicht schreibfähig.',1;
    SET XACT_ABORT OFF;
    DECLARE @Started datetime2(3)=SYSUTCDATETIME(),@Deadline datetime2(3),@Status varchar(40)='AVAILABLE_LIMITED',@Partial bit=1;
    DECLARE @OriginalLock int=@@LOCK_TIMEOUT,@LockSql nvarchar(80),@Error int=NULL,@Message nvarchar(2048)=NULL;
    DECLARE @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))) COLLATE SQL_Latin1_General_CP1_CS_AS;
    DECLARE @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 9223372036854775807 ELSE @MaxZeilen END;
    DECLARE @ProfileSupported bit=1,@SchemaVersion int=1;
    DECLARE @ValidationStage varchar(24)='PARAMETERS';

    CREATE TABLE #SsisModel_ResultTables([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    IF @Mode='TABLE'
        EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
            @AllowedResultNames=N'moduleStatus|sourceBinding|nodes|edges|coverage|findings|sourceStatus|warnings',
            @MappingTable=N'#SsisModel_ResultTables',@ThrowOnError=1;
    CREATE TABLE #SsisModel_ModuleStatus(
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CollectionTimeUtc] datetime2(3) NOT NULL,[SchemaVersion] int NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[NodeCount] int NOT NULL,[EdgeCount] int NOT NULL,
        [ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE #SsisModel_Binding(
        [PackageSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ByteLength] int NOT NULL,
        [BindingStatus] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ProducerTrust] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ProducerVersion] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceCommit] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[BuildSha256] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisModel_Nodes(
        [NodeOrdinal] int NOT NULL,[NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
        [NodeKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ParentNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [NodeName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[AttributesJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisModel_Edges(
        [EdgeOrdinal] int NOT NULL,[EdgeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,
        [EdgeKind] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ScopeNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [FromNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ToNodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Resolution] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Evidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[MappingRole] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsInterpretable] bit NOT NULL);
    CREATE TABLE #SsisModel_Coverage(
        [Feature] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[ReportedStatus] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ReasonCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsProfileSupported] bit NOT NULL);
    CREATE TABLE #SsisModel_Findings(
        [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceLevel] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Feature] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Finding] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisModel_SourceStatus(
        [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,[ReturnedRowCount] bigint NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE #SsisModel_Warnings(
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[WarningSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);

    -- BEGIN GENERATED SSIS EXCHANGE RULES
    DECLARE @FieldRulesJson nvarchar(max) = N'[{"role":"ROOT","name":"contract","types":"1","required":true,"enum":["ssis-package-model"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ROOT","name":"version","types":"1","required":true,"enum":["1.0.0"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ROOT","name":"identityProfile","types":"1","required":true,"enum":["document-order-v1"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ROOT","name":"producer","types":"5","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":"PRODUCER"},{"role":"ROOT","name":"source","types":"5","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":"SOURCE"},{"role":"ROOT","name":"profiles","types":"5","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":"PROFILES"},{"role":"ROOT","name":"coverage","types":"4","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":8,"maxItems":8,"pattern":null,"childRole":"COVERAGE_ARRAY"},{"role":"ROOT","name":"nodes","types":"4","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":1,"maxItems":20000,"pattern":null,"childRole":"NODES_ARRAY"},{"role":"ROOT","name":"edges","types":"4","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":50000,"pattern":null,"childRole":"EDGES_ARRAY"},{"role":"ROOT","name":"diagnostics","types":"4","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":1000,"pattern":null,"childRole":"DIAGNOSTICS_ARRAY"},{"role":"PRODUCER","name":"id","types":"1","required":true,"enum":["toolbelt.ssis-model"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"PRODUCER","name":"version","types":"1","required":true,"enum":null,"maxLength":32,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"VERSION","childRole":null},{"role":"PRODUCER","name":"sourceCommit","types":"1","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"HEX40","childRole":null},{"role":"PRODUCER","name":"buildSha256","types":"1","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"HEX64","childRole":null},{"role":"SOURCE","name":"kind","types":"1","required":true,"enum":["DTSX_BYTES"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"SOURCE","name":"packageSha256","types":"1","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"HEX64","childRole":null},{"role":"SOURCE","name":"byteLength","types":"2","required":true,"enum":null,"maxLength":null,"min":1,"max":16777216,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"SOURCE","name":"packageFormatVersion","types":"02","required":true,"enum":null,"maxLength":null,"min":0,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"SOURCE","name":"xmlProfile","types":"1","required":true,"enum":["2012/01","2014/01","UNKNOWN"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"PROFILES","name":"format","types":"1","required":true,"enum":null,"maxLength":32,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"VERSION","childRole":null},{"role":"PROFILES","name":"components","types":"1","required":true,"enum":null,"maxLength":32,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"VERSION","childRole":null},{"role":"PROFILES","name":"lineage","types":"1","required":true,"enum":null,"maxLength":32,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"VERSION","childRole":null},{"role":"COVERAGE","name":"feature","types":"1","required":true,"enum":["inventory","controlFlow","pipelineGraph","columnMetadata","directColumnMapping","valueLineage","rowLineage","expressionReferences"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"COVERAGE","name":"status","types":"1","required":true,"enum":["COMPLETE","PARTIAL","UNSUPPORTED","NOT_REQUESTED"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"COVERAGE","name":"reasonCode","types":"01","required":true,"enum":["PROFILE_LIMIT","UNKNOWN_COMPONENT","ENCRYPTED_CONTENT","EXPRESSION_UNRESOLVED","MISSING_CONTEXT","UNSUPPORTED_PACKAGE_FORMAT","SCOPE_NOT_REQUESTED"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"NODE","name":"id","types":"1","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"NODE","name":"kind","types":"1","required":true,"enum":["PACKAGE","EXECUTABLE","COMPONENT","PORT","COLUMN","VARIABLE","PARAMETER","CONNECTION","EXPRESSION"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"NODE","name":"parentId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"NODE","name":"name","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"NODE","name":"attributes","types":"5","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"id","types":"1","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"EDGEID","childRole":null},{"role":"EDGE","name":"kind","types":"1","required":true,"enum":["CONTROL_FLOW","PIPELINE_PATH","COLUMN_MAP","VALUE_DEPENDENCY","ROW_DEPENDENCY","EXPRESSION_REFERENCE"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"scopeId","types":"1","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"EDGE","name":"fromId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"EDGE","name":"toId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"EDGE","name":"resolution","types":"1","required":true,"enum":["RESOLVED","UNRESOLVED","UNSUPPORTED"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"evidence","types":"1","required":true,"enum":["DECLARED","DERIVED"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"mappingRole","types":"01","required":true,"enum":["DATA_TRANSFER","METADATA_REFERENCE",null],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"EDGE","name":"ruleId","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"RULEID","childRole":null},{"role":"DIAGNOSTIC","name":"code","types":"1","required":true,"enum":["UNKNOWN_COMPONENT","ENCRYPTED_CONTENT","EXPRESSION_UNRESOLVED","MISSING_CONTEXT","PARTIAL_LINEAGE","PROFILE_LIMIT","UNSUPPORTED_PACKAGE_FORMAT"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"DIAGNOSTIC","name":"objectId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"ATTR_PACKAGE","name":"protectionLevel","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_EXECUTABLE","name":"executableType","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_EXECUTABLE","name":"isDisabled","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_EXECUTABLE","name":"isEventHandler","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COMPONENT","name":"componentClassId","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_PORT","name":"direction","types":"01","required":true,"enum":["INPUT","OUTPUT",null],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_PORT","name":"portRole","types":"01","required":true,"enum":["REGULAR","ERROR","NO_MATCH","DEFAULT","UNKNOWN",null],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_PORT","name":"synchronousInputPortId","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":"ID","childRole":null},{"role":"ATTR_COLUMN","name":"columnRole","types":"1","required":true,"enum":["DATA","EXTERNAL_METADATA"],"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"typeCode","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"length","types":"02","required":true,"enum":null,"maxLength":null,"min":-1,"max":2147483647,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"precision","types":"02","required":true,"enum":null,"maxLength":null,"min":0,"max":255,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"scale","types":"02","required":true,"enum":null,"maxLength":null,"min":0,"max":255,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"codePage","types":"02","required":true,"enum":null,"maxLength":null,"min":0,"max":2147483647,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_COLUMN","name":"isNullable","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_VARIABLE","name":"namespace","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_VARIABLE","name":"typeCode","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_VARIABLE","name":"isReadOnly","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_VARIABLE","name":"evaluateAsExpression","types":"03","required":true,"enum":null,"maxLength":null,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_PARAMETER","name":"typeCode","types":"01","required":true,"enum":null,"maxLength":64,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_CONNECTION","name":"connectionKind","types":"01","required":true,"enum":null,"maxLength":128,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null},{"role":"ATTR_EXPRESSION","name":"propertyName","types":"01","required":true,"enum":null,"maxLength":256,"min":null,"max":null,"minItems":null,"maxItems":null,"pattern":null,"childRole":null}]';
    -- END GENERATED SSIS EXCHANGE RULES

    BEGIN TRY
        IF @MaxZeilen<0 OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 60
           OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000 OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
           OR @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR (@Mode<>'TABLE' AND @ResultTablesJson IS NOT NULL)
            THROW 50000,N'INVALID_PARAMETER',1;
        SET @Deadline=DATEADD(second,@MaxDurationSeconds,@Started);
        SET @LockSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@LockTimeoutMs)+N';'; EXEC [sys].[sp_executesql] @LockSql;
        IF DATALENGTH(@PackageModelJson)>16777216 OR DATALENGTH(@PackageBytes)>16777216 THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
        IF @PackageModelJson IS NULL OR ISJSON(@PackageModelJson)<>1 OR LEFT(LTRIM(REPLACE(REPLACE(REPLACE(@PackageModelJson,NCHAR(9),N' '),NCHAR(10),N' '),NCHAR(13),N' ')),1)<>N'{'
            THROW 50000,N'EXCHANGE_INVALID',1;
        IF COALESCE(JSON_VALUE(@PackageModelJson,'$.contract'),'') COLLATE Latin1_General_100_BIN2<>'ssis-package-model'
            OR COALESCE(JSON_VALUE(@PackageModelJson,'$.version'),'') COLLATE Latin1_General_100_BIN2<>'1.0.0'
            OR COALESCE(JSON_VALUE(@PackageModelJson,'$.identityProfile'),'') COLLATE Latin1_General_100_BIN2<>'document-order-v1'
            THROW 50000,N'EXCHANGE_VERSION_UNSUPPORTED',1;

        SET @ValidationStage='JSON_TREE';
        CREATE TABLE #SsisModel_Rules(
            [Role] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Name] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [Types] varchar(6) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Required] bit NOT NULL,[EnumJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [MaxLength] int NULL,[Minimum] bigint NULL,[Maximum] bigint NULL,[MinItems] int NULL,[MaxItems] int NULL,
            [Pattern] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ChildRole] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        INSERT #SsisModel_Rules
        SELECT [role],[name],[types],[required],[enum],[maxLength],[min],[max],[minItems],[maxItems],[pattern],[childRole]
        FROM OPENJSON(@FieldRulesJson) WITH([role] varchar(40),[name] nvarchar(128),[types] varchar(6),[required] bit,[enum] nvarchar(max) AS JSON,
            [maxLength] int,[min] bigint,[max] bigint,[minItems] int,[maxItems] int,[pattern] varchar(16),[childRole] varchar(40));
        CREATE TABLE #SsisModel_Tokens(
            [TokenId] int IDENTITY(1,1) NOT NULL PRIMARY KEY,[ParentId] int NULL,[Depth] int NOT NULL,[Role] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Name] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Value] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Type] int NOT NULL);
        INSERT #SsisModel_Tokens([ParentId],[Depth],[Role],[Name],[Value],[Type]) VALUES(NULL,1,'ROOT',NULL,@PackageModelJson,5);
        DECLARE @Depth int=1;
        WHILE EXISTS(SELECT 1 FROM #SsisModel_Tokens WHERE [Depth]=@Depth AND [Type] IN (4,5))
        BEGIN
            IF SYSUTCDATETIME()>=@Deadline THROW 50000,N'EXCHANGE_TIME_BUDGET_EXHAUSTED',1;
            IF @Depth>=32 THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
            INSERT #SsisModel_Tokens([ParentId],[Depth],[Role],[Name],[Value],[Type])
            SELECT [p].[TokenId],@Depth+1,
                CASE [p].[Role] WHEN 'NODES_ARRAY' THEN 'NODE' WHEN 'EDGES_ARRAY' THEN 'EDGE' WHEN 'COVERAGE_ARRAY' THEN 'COVERAGE' WHEN 'DIAGNOSTICS_ARRAY' THEN 'DIAGNOSTIC'
                    ELSE CASE WHEN [p].[Role]='NODE' AND [j].[key] COLLATE Latin1_General_100_BIN2='attributes'
                        THEN 'ATTR_'+JSON_VALUE([p].[Value],'$.kind') ELSE [r].[ChildRole] END END,
                [j].[key],[j].[value],[j].[type]
            FROM #SsisModel_Tokens AS [p] CROSS APPLY OPENJSON([p].[Value]) AS [j]
            LEFT JOIN #SsisModel_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[j].[key] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([j].[key])
            WHERE [p].[Depth]=@Depth AND [p].[Type] IN (4,5);
            IF EXISTS(SELECT 1 FROM #SsisModel_Tokens WHERE [Depth]=@Depth+1 AND [Role] IN ('NODE','EDGE','COVERAGE','DIAGNOSTIC') AND [Type]<>5) THROW 50000,N'EXCHANGE_INVALID',1;
            IF (SELECT COUNT_BIG(*) FROM #SsisModel_Tokens)>1000000 THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
            IF EXISTS(SELECT 1 FROM #SsisModel_Tokens AS [p] JOIN #SsisModel_Tokens AS [c] ON [c].[ParentId]=[p].[TokenId]
                WHERE [p].[Depth]=@Depth AND [p].[Type]=5 GROUP BY [p].[TokenId],[c].[Name] COLLATE Latin1_General_100_BIN2,DATALENGTH([c].[Name]) HAVING COUNT_BIG(*)>1)
                THROW 50000,N'EXCHANGE_INVALID',1;
            IF EXISTS(SELECT 1 FROM #SsisModel_Tokens AS [p] JOIN #SsisModel_Tokens AS [c] ON [c].[ParentId]=[p].[TokenId]
                LEFT JOIN #SsisModel_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[c].[Name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([c].[Name])
                WHERE [p].[Depth]=@Depth AND [p].[Type]=5 AND ([r].[Name] IS NULL OR CHARINDEX(CONVERT(varchar(1),[c].[Type]),[r].[Types])=0
                    OR [c].[Type]=1 AND [r].[MaxLength] IS NOT NULL AND DATALENGTH([c].[Value])/2>[r].[MaxLength]
                    OR [c].[Type]<>0 AND [r].[EnumJson] IS NOT NULL AND NOT EXISTS(SELECT 1 FROM OPENJSON([r].[EnumJson]) AS [v]
                        WHERE [v].[type]=[c].[Type] AND [v].[value] COLLATE Latin1_General_100_BIN2=[c].[Value] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([v].[value])=DATALENGTH([c].[Value]))))
                THROW 50000,N'EXCHANGE_INVALID',1;
            IF EXISTS(SELECT 1 FROM #SsisModel_Tokens AS [p] JOIN #SsisModel_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Required]=1
                WHERE [p].[Depth]=@Depth AND [p].[Type]=5 AND NOT EXISTS(SELECT 1 FROM #SsisModel_Tokens AS [c]
                    WHERE [c].[ParentId]=[p].[TokenId] AND [c].[Name] COLLATE Latin1_General_100_BIN2=[r].[Name] COLLATE Latin1_General_100_BIN2))
                THROW 50000,N'EXCHANGE_INVALID',1;
            IF EXISTS(SELECT 1 FROM #SsisModel_Tokens AS [c] JOIN #SsisModel_Tokens AS [p] ON [p].[TokenId]=[c].[ParentId]
                JOIN #SsisModel_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[c].[Name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([c].[Name])
                CROSS APPLY(SELECT COUNT_BIG(*) AS [N] FROM OPENJSON([c].[Value])) AS [a]
                WHERE [c].[Depth]=@Depth+1 AND [c].[Type]=4 AND ([a].[N]<COALESCE([r].[MinItems],0) OR [a].[N]>COALESCE([r].[MaxItems],2147483647)))
                THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
            SET @Depth+=1;
        END;

        -- Zahlenlexeme werden exakt auf Ganzzahligkeit geprüft. Float-/Decimal-
        -- Rundung darf einen kleinen Bruchteil nicht in eine gültige ID-Zahl verwandeln.
        SET @ValidationStage='NUMBERS';
        CREATE TABLE #SsisModel_Numbers([TokenId] int NOT NULL PRIMARY KEY,[NumberValue] bigint NULL);
        ;WITH [n0] AS(
            SELECT [TokenId],[Value],CASE WHEN LEFT([Value],1)='-' THEN 1 ELSE 0 END AS [Negative],CHARINDEX('e',LOWER([Value])) AS [ExpAt]
            FROM #SsisModel_Tokens WHERE [Type]=2),
        [n1] AS(
            SELECT *,CASE WHEN [ExpAt]=0 THEN [Value] ELSE LEFT([Value],[ExpAt]-1) END AS [Mantissa],
                CASE WHEN [ExpAt]=0 THEN 0 ELSE TRY_CONVERT(int,SUBSTRING([Value],[ExpAt]+1,4000)) END AS [Exponent] FROM [n0]),
        [n2] AS(
            SELECT *,REPLACE(REPLACE([Mantissa],'-',''),'.','') AS [Digits],
                CASE WHEN CHARINDEX('.',[Mantissa])=0 THEN 0 ELSE LEN([Mantissa])-CHARINDEX('.',[Mantissa]) END AS [Fraction] FROM [n1]),
        [n3] AS(
            SELECT *,SUBSTRING([Digits],NULLIF(PATINDEX('%[^0]%',[Digits]),0),2147483647) AS [Significant],
                CONVERT(bigint,[Fraction])-CONVERT(bigint,[Exponent]) AS [Scale] FROM [n2])
        INSERT #SsisModel_Numbers
        SELECT [TokenId],CASE WHEN [Significant] IS NULL THEN 0
            WHEN [Scale] IS NOT NULL AND [Scale]<=PATINDEX('%[^0]%',REVERSE([Significant]))-1
                AND CONVERT(bigint,LEN([Significant]))-[Scale] BETWEEN 1 AND 10
            THEN TRY_CONVERT(bigint,CASE WHEN [Negative]=1 THEN '-' ELSE '' END+
                CASE WHEN [Scale]>=0 THEN LEFT([Significant],CONVERT(int,CONVERT(bigint,LEN([Significant]))-[Scale]))
                ELSE [Significant]+REPLICATE('0',CONVERT(int,CASE WHEN -[Scale]<=10 THEN -[Scale] ELSE 0 END)) END) END
        FROM [n3];
        IF EXISTS(SELECT 1 FROM #SsisModel_Tokens AS [c] JOIN #SsisModel_Numbers AS [n] ON [n].[TokenId]=[c].[TokenId]
            JOIN #SsisModel_Tokens AS [p] ON [p].[TokenId]=[c].[ParentId] JOIN #SsisModel_Rules AS [r]
                ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[c].[Name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([c].[Name])
            WHERE [n].[NumberValue] IS NULL OR [n].[NumberValue]<[r].[Minimum] OR [n].[NumberValue]>[r].[Maximum]) THROW 50000,N'EXCHANGE_INVALID',1;

        -- Die Musterklassen werden vom kanonischen Schema abgeleitet; keine
        -- zweite Liste fachlicher Felder oder erlaubter Enumerationswerte.
        SET @ValidationStage='PATTERNS';
        IF EXISTS(SELECT 1 FROM #SsisModel_Tokens AS [c] JOIN #SsisModel_Tokens AS [p] ON [p].[TokenId]=[c].[ParentId]
            JOIN #SsisModel_Rules AS [r] ON [r].[Role]=[p].[Role] AND [r].[Name] COLLATE Latin1_General_100_BIN2=[c].[Name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([r].[Name])=DATALENGTH([c].[Name])
            WHERE [c].[Type]=1 AND (
                [r].[Pattern] IN ('HEX40','HEX64') AND (DATALENGTH([c].[Value])/2<>CASE WHEN [r].[Pattern]='HEX40' THEN 40 ELSE 64 END OR [c].[Value] COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9a-f]%')
                OR [r].[Pattern]='RULEID' AND ([c].[Value] COLLATE Latin1_General_100_BIN2 LIKE '%[^A-Z0-9_]%' OR LEFT([c].[Value],1) COLLATE Latin1_General_100_BIN2 NOT LIKE '[A-Z]')
                OR [r].[Pattern] IN ('ID','EDGEID') AND NOT EXISTS(
                    SELECT 1 FROM (VALUES('pkg'),('exe'),('cmp'),('port'),('col'),('var'),('par'),('con'),('expr'),('edge')) AS [prefix]([P])
                    WHERE LEFT([c].[Value],LEN([prefix].[P])) COLLATE Latin1_General_100_BIN2=[prefix].[P] COLLATE Latin1_General_100_BIN2
                        AND SUBSTRING([c].[Value],LEN([prefix].[P])+1,1) COLLATE Latin1_General_100_BIN2 LIKE '[1-9]'
                        AND SUBSTRING([c].[Value],LEN([prefix].[P])+1,4000) COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9]%'
                        AND ([r].[Pattern]='EDGEID' AND [prefix].[P]='edge' OR [r].[Pattern]='ID' AND [prefix].[P]<>'edge'))
                OR [r].[Pattern]='VERSION' AND (LEN([c].[Value])-LEN(REPLACE([c].[Value],'.',''))<>2 OR [c].[Value] COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9.]%'
                    OR EXISTS(SELECT 1 FROM STRING_SPLIT([c].[Value],'.') AS [v] WHERE [v].[value]='' OR LEN([v].[value])>1 AND LEFT([v].[value],1)='0')
                    OR LEFT([c].[Value],1)='.' OR RIGHT([c].[Value],1)='.' OR CHARINDEX('..',[c].[Value])>0)))
            THROW 50000,N'EXCHANGE_INVALID',1;

        SET @ValidationStage='REFERENCES';
        INSERT #SsisModel_Nodes
        SELECT CONVERT(int,[j].[key])+1,JSON_VALUE([j].[value],'$.id'),JSON_VALUE([j].[value],'$.kind'),JSON_VALUE([j].[value],'$.parentId'),JSON_VALUE([j].[value],'$.name'),JSON_QUERY([j].[value],'$.attributes')
        FROM OPENJSON(@PackageModelJson,'$.nodes') AS [j];
        INSERT #SsisModel_Edges
        SELECT CONVERT(int,[j].[key])+1,JSON_VALUE([j].[value],'$.id'),JSON_VALUE([j].[value],'$.kind'),JSON_VALUE([j].[value],'$.scopeId'),JSON_VALUE([j].[value],'$.fromId'),JSON_VALUE([j].[value],'$.toId'),
            JSON_VALUE([j].[value],'$.resolution'),JSON_VALUE([j].[value],'$.evidence'),JSON_VALUE([j].[value],'$.ruleId'),JSON_VALUE([j].[value],'$.mappingRole'),1
        FROM OPENJSON(@PackageModelJson,'$.edges') AS [j];
        INSERT #SsisModel_Coverage
        SELECT JSON_VALUE([value],'$.feature'),JSON_VALUE([value],'$.status'),JSON_VALUE([value],'$.reasonCode'),1 FROM OPENJSON(@PackageModelJson,'$.coverage');
        IF (SELECT COUNT(*) FROM #SsisModel_Nodes WHERE [NodeKind]='PACKAGE' AND [NodeId]='pkg1' AND [ParentNodeId] IS NULL)<>1
            OR EXISTS(SELECT 1 FROM #SsisModel_Nodes WHERE [NodeKind]='PACKAGE' AND ([NodeId]<>'pkg1' OR [ParentNodeId] IS NOT NULL))
            OR EXISTS(SELECT 1 FROM #SsisModel_Nodes AS [n] LEFT JOIN #SsisModel_Nodes AS [p] ON [p].[NodeId]=[n].[ParentNodeId]
                WHERE [n].[NodeKind]<>'PACKAGE' AND ([p].[NodeId] IS NULL OR NOT (
                    [n].[NodeKind]='EXECUTABLE' AND [p].[NodeKind] IN ('PACKAGE','EXECUTABLE') OR [n].[NodeKind]='COMPONENT' AND [p].[NodeKind]='EXECUTABLE'
                    OR [n].[NodeKind]='PORT' AND [p].[NodeKind]='COMPONENT' OR [n].[NodeKind]='COLUMN' AND [p].[NodeKind]='PORT'
                    OR [n].[NodeKind]='VARIABLE' AND [p].[NodeKind] IN ('PACKAGE','EXECUTABLE') OR [n].[NodeKind] IN ('PARAMETER','CONNECTION') AND [p].[NodeKind]='PACKAGE'
                    OR [n].[NodeKind]='EXPRESSION' AND [p].[NodeKind] IN ('PACKAGE','EXECUTABLE','COMPONENT','PORT','COLUMN','VARIABLE','CONNECTION'))))
            OR EXISTS(SELECT 1 FROM #SsisModel_Nodes AS [n] JOIN (VALUES('PACKAGE','pkg'),('EXECUTABLE','exe'),('COMPONENT','cmp'),('PORT','port'),('COLUMN','col'),('VARIABLE','var'),('PARAMETER','par'),('CONNECTION','con'),('EXPRESSION','expr')) AS [k]([Kind],[Prefix]) ON [n].[NodeKind]=[k].[Kind]
                WHERE LEFT([n].[NodeId],LEN([k].[Prefix]))<>[k].[Prefix])
            THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        CREATE TABLE #SsisModel_Owners([NodeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY,[ScopeId] varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [OwnerDepth] int NOT NULL,[ScopePath] varchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        INSERT #SsisModel_Owners VALUES('pkg1','pkg1',1,'/pkg1/');
        DECLARE @Added int=1;
        WHILE @Added>0
        BEGIN
            IF SYSUTCDATETIME()>=@Deadline THROW 50000,N'EXCHANGE_TIME_BUDGET_EXHAUSTED',1;
            INSERT #SsisModel_Owners
            SELECT [n].[NodeId],CASE WHEN [n].[NodeKind]='EXECUTABLE' THEN [n].[NodeId] ELSE [p].[ScopeId] END,[p].[OwnerDepth]+1,
                [p].[ScopePath]+CASE WHEN [n].[NodeKind]='EXECUTABLE' THEN [n].[NodeId]+'/' ELSE '' END
            FROM #SsisModel_Nodes AS [n] JOIN #SsisModel_Owners AS [p] ON [p].[NodeId]=[n].[ParentNodeId]
            WHERE NOT EXISTS(SELECT 1 FROM #SsisModel_Owners AS [o] WHERE [o].[NodeId]=[n].[NodeId]);
            SET @Added=@@ROWCOUNT;
            IF EXISTS(SELECT 1 FROM #SsisModel_Owners WHERE [OwnerDepth]>128) THROW 50000,N'EXCHANGE_LIMIT_EXCEEDED',1;
        END;
        IF (SELECT COUNT(*) FROM #SsisModel_Owners)<>(SELECT COUNT(*) FROM #SsisModel_Nodes) THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        IF EXISTS(SELECT 1 FROM #SsisModel_Coverage WHERE [ReportedStatus]='COMPLETE' AND [ReasonCode] IS NOT NULL OR [ReportedStatus]<>'COMPLETE' AND [ReasonCode] IS NULL)
            THROW 50000,N'EXCHANGE_INVALID',1;
        IF EXISTS(SELECT 1 FROM #SsisModel_Nodes AS [n] WHERE [n].[NodeKind]='PORT' AND JSON_VALUE([n].[AttributesJson],'$.synchronousInputPortId') IS NOT NULL
            AND NOT EXISTS(SELECT 1 FROM #SsisModel_Nodes AS [p] WHERE [p].[NodeId]=JSON_VALUE([n].[AttributesJson],'$.synchronousInputPortId') AND [p].[ParentNodeId]=[n].[ParentNodeId]
                AND [p].[NodeKind]='PORT' AND JSON_VALUE([p].[AttributesJson],'$.direction')='INPUT' AND JSON_VALUE([n].[AttributesJson],'$.direction')='OUTPUT'))
            THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@PackageModelJson,'$.diagnostics') AS [d] WHERE JSON_VALUE([d].[value],'$.objectId') IS NOT NULL
            AND NOT EXISTS(SELECT 1 FROM #SsisModel_Nodes AS [n] WHERE [n].[NodeId]=JSON_VALUE([d].[value],'$.objectId'))) THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        IF EXISTS(SELECT 1 FROM #SsisModel_Edges AS [e]
            LEFT JOIN #SsisModel_Nodes AS [f] ON [f].[NodeId]=[e].[FromNodeId] LEFT JOIN #SsisModel_Nodes AS [t] ON [t].[NodeId]=[e].[ToNodeId]
            LEFT JOIN #SsisModel_Nodes AS [s] ON [s].[NodeId]=[e].[ScopeNodeId]
            LEFT JOIN #SsisModel_Owners AS [so] ON [so].[NodeId]=[s].[NodeId]
            LEFT JOIN #SsisModel_Owners AS [fo] ON [fo].[NodeId]=[f].[NodeId] LEFT JOIN #SsisModel_Owners AS [to] ON [to].[NodeId]=[t].[NodeId]
            WHERE [s].[NodeId] IS NULL OR [s].[NodeKind] NOT IN ('PACKAGE','EXECUTABLE') OR [e].[FromNodeId] IS NULL AND [e].[ToNodeId] IS NULL
                OR [e].[FromNodeId] IS NOT NULL AND [f].[NodeId] IS NULL OR [e].[ToNodeId] IS NOT NULL AND [t].[NodeId] IS NULL
                OR [e].[Resolution]='RESOLVED' AND ([f].[NodeId] IS NULL OR [t].[NodeId] IS NULL)
                OR [e].[Evidence]='DECLARED' AND [e].[RuleId] IS NOT NULL OR [e].[Evidence]='DERIVED' AND [e].[RuleId] IS NULL
                OR [f].[NodeKind] IN ('VARIABLE','PARAMETER') AND CHARINDEX('/'+[f].[ParentNodeId]+'/',[so].[ScopePath])=0
                OR [e].[EdgeKind]='COLUMN_MAP' AND ([e].[MappingRole]='DATA_TRANSFER' AND (JSON_VALUE([f].[AttributesJson],'$.columnRole')<>'DATA' OR JSON_VALUE([t].[AttributesJson],'$.columnRole')<>'DATA')
                    OR [e].[MappingRole]='METADATA_REFERENCE' AND (JSON_VALUE([f].[AttributesJson],'$.columnRole')<>'DATA' OR JSON_VALUE([t].[AttributesJson],'$.columnRole')<>'EXTERNAL_METADATA'))
                OR [e].[EdgeKind]='COLUMN_MAP' AND COALESCE([e].[MappingRole],'') NOT IN ('DATA_TRANSFER','METADATA_REFERENCE') OR [e].[EdgeKind]<>'COLUMN_MAP' AND [e].[MappingRole] IS NOT NULL
                OR [f].[NodeId] IS NOT NULL AND NOT ([e].[EdgeKind]='CONTROL_FLOW' AND [f].[NodeKind]='EXECUTABLE' AND [f].[ParentNodeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='PIPELINE_PATH' AND [f].[NodeKind]='PORT' AND COALESCE(JSON_VALUE([f].[AttributesJson],'$.direction'),'')='OUTPUT' AND [fo].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='COLUMN_MAP' AND [f].[NodeKind]='COLUMN' AND [fo].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind] IN ('VALUE_DEPENDENCY','ROW_DEPENDENCY') AND [f].[NodeKind] IN ('COLUMN','VARIABLE','PARAMETER') AND ([f].[NodeKind]<>'COLUMN' OR [fo].[ScopeId]=[e].[ScopeNodeId])
                    OR [e].[EdgeKind]='EXPRESSION_REFERENCE' AND [f].[NodeKind] IN ('VARIABLE','PARAMETER'))
                OR [t].[NodeId] IS NOT NULL AND NOT ([e].[EdgeKind]='CONTROL_FLOW' AND [t].[NodeKind]='EXECUTABLE' AND [t].[ParentNodeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='PIPELINE_PATH' AND [t].[NodeKind]='PORT' AND COALESCE(JSON_VALUE([t].[AttributesJson],'$.direction'),'')='INPUT' AND [to].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind] IN ('COLUMN_MAP','VALUE_DEPENDENCY') AND [t].[NodeKind]='COLUMN' AND [to].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='ROW_DEPENDENCY' AND [t].[NodeKind] IN ('COLUMN','PORT') AND [to].[ScopeId]=[e].[ScopeNodeId]
                    OR [e].[EdgeKind]='EXPRESSION_REFERENCE' AND [t].[NodeKind]='EXPRESSION' AND [to].[ScopeId]=[e].[ScopeNodeId]))
            THROW 50000,N'EXCHANGE_REFERENCE_INVALID',1;
        SET @ValidationStage='PROFILES';
        IF JSON_VALUE(@PackageModelJson,'$.profiles.format')<>'1.0.0' THROW 50000,N'EXCHANGE_PROFILE_UNSUPPORTED',1;
        IF JSON_VALUE(@PackageModelJson,'$.profiles.components')<>'1.0.0' OR JSON_VALUE(@PackageModelJson,'$.profiles.lineage')<>'1.0.0'
        BEGIN
            SET @ProfileSupported=0; UPDATE #SsisModel_Coverage SET [IsProfileSupported]=0 WHERE [Feature] IN ('valueLineage','rowLineage','expressionReferences');
        END;
        UPDATE #SsisModel_Edges SET [IsInterpretable]=0 WHERE [Evidence]='DERIVED' AND (@ProfileSupported=0 OR NOT (
            [EdgeKind]='VALUE_DEPENDENCY' AND [RuleId] IN ('MAPPED_VALUE_INPUT','BOUND_EXPRESSION_INPUT') OR [EdgeKind]='ROW_DEPENDENCY' AND [RuleId] IN ('LOOKUP_ROW_SELECTION','SPLIT_ROW_SELECTION')));
        IF EXISTS(SELECT 1 FROM #SsisModel_Edges WHERE [IsInterpretable]=0)
            INSERT #SsisModel_Warnings VALUES('EXCHANGE_PROFILE_UNSUPPORTED','INFO',N'Abgeleitete Beziehungen ohne unterstütztes Regelprofil bleiben uninterpretiert.');

        SET @ValidationStage='BINDING';
        DECLARE @PackageHash varchar(64)=JSON_VALUE(@PackageModelJson,'$.source.packageSha256');
        DECLARE @DeclaredLength int=(SELECT [n].[NumberValue] FROM #SsisModel_Tokens AS [c] JOIN #SsisModel_Numbers AS [n] ON [n].[TokenId]=[c].[TokenId]
            JOIN #SsisModel_Tokens AS [p] ON [p].[TokenId]=[c].[ParentId] WHERE [p].[Role]='SOURCE' AND [c].[Name]='byteLength');
        IF @PackageBytes IS NOT NULL AND (DATALENGTH(@PackageBytes)<>@DeclaredLength OR CONVERT(varchar(64),HASHBYTES('SHA2_256',@PackageBytes),2) COLLATE Latin1_General_100_BIN2<>UPPER(@PackageHash) COLLATE Latin1_General_100_BIN2)
            THROW 50000,N'EXCHANGE_SOURCE_MISMATCH',1;
        INSERT #SsisModel_Binding VALUES(@PackageHash,@DeclaredLength,CASE WHEN @PackageBytes IS NULL THEN 'DECLARED_ONLY' ELSE 'PACKAGE_BYTES_MATCH' END,'UNVERIFIED',
            JSON_VALUE(@PackageModelJson,'$.producer.version'),JSON_VALUE(@PackageModelJson,'$.producer.sourceCommit'),JSON_VALUE(@PackageModelJson,'$.producer.buildSha256'));
        INSERT #SsisModel_Findings VALUES('SSIS_MODEL_UNVERIFIED_PRODUCER','INFO','IMPORTED_STATIC',NULL,N'Das Modell enthält statische Producerbehauptungen; die angegebenen Digests authentifizieren den Erzeuger nicht.');
        INSERT #SsisModel_Findings
        SELECT 'SSIS_MODEL_COVERAGE_LIMITED','INFO','IMPORTED_STATIC',[Feature],N'Die berichtete Abdeckung oder das unterstützte Profil reicht für eine uneingeschränkte Auswertung dieses Features nicht aus.'
        FROM #SsisModel_Coverage WHERE [ReportedStatus]<>'COMPLETE' OR [IsProfileSupported]=0;
        IF SYSUTCDATETIME()>=@Deadline THROW 50000,N'EXCHANGE_TIME_BUDGET_EXHAUSTED',1;
    END TRY
    BEGIN CATCH
        SET @Error=ERROR_NUMBER();
        SET @Message=CASE WHEN ERROR_NUMBER()=50000 THEN ERROR_MESSAGE() ELSE N'Native Modellvalidierung fehlgeschlagen; Fehlernummer '+CONVERT(nvarchar(12),ERROR_NUMBER())+N'.' END;
        SET @Message+=N' Stage='+@ValidationStage;
        SET @Status=CASE WHEN ERROR_NUMBER()=50000 AND ERROR_MESSAGE() IN ('INVALID_PARAMETER','EXCHANGE_INVALID','EXCHANGE_VERSION_UNSUPPORTED','EXCHANGE_LIMIT_EXCEEDED','EXCHANGE_REFERENCE_INVALID','EXCHANGE_PROFILE_UNSUPPORTED','EXCHANGE_SOURCE_MISMATCH','EXCHANGE_TIME_BUDGET_EXHAUSTED') THEN ERROR_MESSAGE() ELSE 'EXCHANGE_INVALID' END;
        DELETE #SsisModel_Binding; DELETE #SsisModel_Nodes; DELETE #SsisModel_Edges; DELETE #SsisModel_Coverage; DELETE #SsisModel_Findings; DELETE #SsisModel_Warnings;
    END CATCH;
    SET @LockSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@OriginalLock)+N';'; EXEC [sys].[sp_executesql] @LockSql;
    IF @Status='AVAILABLE_LIMITED' AND (EXISTS(SELECT 1 FROM #SsisModel_Nodes WHERE [NodeOrdinal]>@Limit) OR EXISTS(SELECT 1 FROM #SsisModel_Edges WHERE [EdgeOrdinal]>@Limit))
        INSERT #SsisModel_Warnings VALUES('RESULT_TRUNCATED','INFO',N'Nur die Ausgabe ist begrenzt; die Validierung verwendete den vollständigen Graphen.');
    INSERT #SsisModel_ModuleStatus VALUES('USP_SsisPackageModelAnalysis',@Started,@SchemaVersion,@Status,@Partial,(SELECT COUNT(*) FROM #SsisModel_Nodes),(SELECT COUNT(*) FROM #SsisModel_Edges),@Error,@Message);
    INSERT #SsisModel_SourceStatus VALUES(N'Caller SSIS-Modell',@Status,@Partial,(SELECT COUNT_BIG(*) FROM #SsisModel_Nodes),N'Native Strukturprüfung; ProducerTrust bleibt UNVERIFIED. Keine Paket- oder SQL-Ausführung.');
    SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
    IF @JsonErzeugen=1
        SET @Json=(SELECT @SchemaVersion AS [meta.schemaVersion],@Status AS [meta.statusCode],@Partial AS [meta.isPartial],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisModel_ModuleStatus FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [moduleStatus],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisModel_Binding FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [sourceBinding],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisModel_Nodes WHERE [NodeOrdinal]<=@Limit ORDER BY [NodeOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [nodes],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisModel_Edges WHERE [EdgeOrdinal]<=@Limit ORDER BY [EdgeOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [edges],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisModel_Coverage ORDER BY [Feature] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [coverage],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisModel_Findings FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [findings],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisModel_SourceStatus FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [sourceStatus],
            JSON_QUERY(COALESCE((SELECT * FROM #SsisModel_Warnings FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [warnings] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    -- Dieselbe begrenzte Materialisierung versorgt RAW, TABLE und JSON.
    DELETE #SsisModel_Nodes WHERE [NodeOrdinal]>@Limit; DELETE #SsisModel_Edges WHERE [EdgeOrdinal]>@Limit;
    IF @Mode='TABLE'
    BEGIN
        DECLARE @Target sysname;
        SET @Target=(SELECT [TargetTable] FROM #SsisModel_ResultTables WHERE [ResultName]='moduleStatus'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisModel_ModuleStatus',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisModel_ResultTables WHERE [ResultName]='sourceBinding'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisModel_Binding',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisModel_ResultTables WHERE [ResultName]='nodes'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisModel_Nodes',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisModel_ResultTables WHERE [ResultName]='edges'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisModel_Edges',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisModel_ResultTables WHERE [ResultName]='coverage'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisModel_Coverage',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisModel_ResultTables WHERE [ResultName]='findings'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisModel_Findings',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisModel_ResultTables WHERE [ResultName]='sourceStatus'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisModel_SourceStatus',@Target,@ThrowOnError=1;
        SET @Target=(SELECT [TargetTable] FROM #SsisModel_ResultTables WHERE [ResultName]='warnings'); IF @Target IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisModel_Warnings',@Target,@ThrowOnError=1;
    END;
    IF @Mode='RAW'
    BEGIN
        SELECT * FROM #SsisModel_ModuleStatus; SELECT * FROM #SsisModel_Binding;
        SELECT * FROM #SsisModel_Nodes ORDER BY [NodeOrdinal]; SELECT * FROM #SsisModel_Edges ORDER BY [EdgeOrdinal];
        SELECT * FROM #SsisModel_Coverage ORDER BY [Feature]; SELECT * FROM #SsisModel_Findings;
        SELECT * FROM #SsisModel_SourceStatus; SELECT * FROM #SsisModel_Warnings;
    END;
    IF @Mode='CONSOLE'
        EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#SsisModel_ModuleStatus',@ResultLabel=N'SsisPackageModelAnalysis',@EmptyMessage=N'Keine fachlichen Ergebnisse';
END;
GO
