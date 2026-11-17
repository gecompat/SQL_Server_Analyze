USE [DeineDatenbank];
GO
/*
Prüft das gemeinsame gefilterte Featureexport mit synthetischen Katalogobjekten.
Nach sechs unveränderten Fällen prüft ein eigener leerer NODE-/EDGE-Katalogfall die Graph-Erkennung.
Die beiden eigenen Unicode-Datenbanken werden auch im Fehlerfall entfernt.
*/
SET NOCOUNT ON;
IF DB_ID(N'ExampleSpecialSourceÄ') IS NOT NULL OR DB_ID(N'ExampleSpecialSourceä') IS NOT NULL
    THROW 56050,N'Special feature fixture already exists.',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @OwnedUpperId int=NULL,@OwnedLowerId int=NULL;
DECLARE @OwnCodesCreated bit=0,@OwnCountsCreated bit=0,@OwnCollectedCreated bit=0;
BEGIN TRY
    CREATE DATABASE [ExampleSpecialSourceÄ] COLLATE Latin1_General_100_CI_AS;
    SET @OwnedUpperId=DB_ID(N'ExampleSpecialSourceÄ');
    CREATE DATABASE [ExampleSpecialSourceä] COLLATE SQL_Latin1_General_CP1_CS_AS;
    SET @OwnedLowerId=DB_ID(N'ExampleSpecialSourceä');
    EXEC(N'USE [ExampleSpecialSourceÄ]; CREATE TYPE [dbo].[ExampleAlias] FROM int;');
    EXEC(N'USE [ExampleSpecialSourceä]; CREATE TYPE [dbo].[ExampleAlias] FROM int;');
    EXEC(N'USE [ExampleSpecialSourceÄ]; CREATE TABLE [dbo].[ExampleFeatureTable]([ExampleAlias] [dbo].[ExampleAlias], [ExampleXml] xml, [ExampleSpatial] geometry);');
    EXEC(N'USE [ExampleSpecialSourceä]; CREATE TABLE [dbo].[ExampleFeatureTable]([ExampleAlias] [dbo].[ExampleAlias], [ExampleXml] xml, [ExampleSpatial] geometry);');
    CREATE TABLE [#SpecialFeatureCollationRuntimeContract_Codes]
    ([FeatureCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY);
    SET @OwnCodesCreated=1;
    INSERT [#SpecialFeatureCollationRuntimeContract_Codes] VALUES
      ('IN_MEMORY_OLTP'),('TEMPORAL'),('SERVICE_BROKER'),('FULL_TEXT'),('CHANGE_TRACKING'),('CDC'),
      ('ENCRYPTION'),('CLR'),('EXTERNAL_TABLES'),('EXTERNAL_RUNTIME'),('EXTERNAL_SCRIPTS'),('EXTERNAL_MODELS'),
      ('FILESTREAM_FILETABLE'),('GRAPH'),('SPATIAL'),('XML'),('JSON_NATIVE'),('VECTOR'),('USER_DEFINED_TYPES');
    CREATE TABLE [#SpecialFeatureCollationRuntimeContract_DetectedCounts]
    ([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,[DetectedRows] bigint NOT NULL);
    SET @OwnCountsCreated=1;
    DECLARE @Case int=0,@Limit int,@DetectedOnly bit,@Selection nvarchar(max),@Json nvarchar(max);
    DECLARE @TableJson nvarchar(max),@Count bigint,@Status varchar(40),@Partial bit,@FullDetectedCount bigint;
    DECLARE @FirstDatabase sysname,@FirstCode varchar(64);
    SELECT TOP(1) @FirstDatabase=[d].[DatabaseName],@FirstCode=[e].[FeatureCode]
    FROM (VALUES(CONVERT(sysname,N'ExampleSpecialSourceÄ') COLLATE SQL_Latin1_General_CP1_CS_AS),
                (CONVERT(sysname,N'ExampleSpecialSourceä') COLLATE SQL_Latin1_General_CP1_CS_AS)) [d]([DatabaseName])
    CROSS JOIN [#SpecialFeatureCollationRuntimeContract_Codes] [e]
    ORDER BY [d].[DatabaseName],[e].[FeatureCode];
    WHILE @Case<6
    BEGIN
        SET @Limit=CASE WHEN @Case IN(1,3,4) THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END;
        SET @DetectedOnly=CASE WHEN @Case IN(2,3) THEN 1 ELSE 0 END;
        SELECT @Json=NULL,@TableJson=NULL,@Count=NULL,@Status=NULL,@Partial=NULL;
        SET @Selection=CASE WHEN @Case=5 THEN N'[ExampleSpecialMissingÖ]'
                            WHEN @Case=4 THEN N'[ExampleSpecialSourceä]|[ExampleSpecialSourceÄ]|[ExampleSpecialMissingÖ]'
                            ELSE N'[ExampleSpecialSourceä]|[ExampleSpecialSourceÄ]' END;
        CREATE TABLE [#SpecialFeatureCollationRuntimeContract_Collected]([Seed] bit NULL);
        SET @OwnCollectedCreated=1;
        SET LOCK_TIMEOUT 739;
        EXEC [monitor].[USP_SpecialFeatureInventory]
              @DatabaseNames=@Selection,@NurErkannteFeatures=@DetectedOnly,@MaxZeilen=@Limit,
              @ResultSetArt='TABLE',@ResultTablesJson=N'{"features":"#SpecialFeatureCollationRuntimeContract_Collected"}',
              @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
              @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
        IF @@LOCK_TIMEOUT<>739 THROW 56053,N'Special feature lock timeout restore failed.',1;
        IF ISJSON(@Json)<>1 OR LEFT(COALESCE(JSON_QUERY(@Json,'$.features'),N''),1)<>N'['
           OR LEFT(COALESCE(JSON_QUERY(@Json,'$.databaseStatus'),N''),1)<>N'['
            THROW 56054,N'Special feature JSON envelope failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_Collected') AND [collation_name] IS NOT NULL)<>9
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                     WHERE [object_id]=OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_Collected')
                       AND [collation_name] IS NOT NULL AND [collation_name]<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 56051,N'Special feature TABLE text collation failed.',1;
        EXEC [sys].[sp_executesql]
             N'SELECT @pCount=COUNT_BIG(*) FROM [#SpecialFeatureCollationRuntimeContract_Collected];
               SELECT @pJson=(SELECT * FROM [#SpecialFeatureCollationRuntimeContract_Collected]
                              ORDER BY [DatabaseName],[FeatureCode] FOR JSON PATH,INCLUDE_NULL_VALUES);',
             N'@pCount bigint OUTPUT,@pJson nvarchar(max) OUTPUT',@pCount=@Count OUTPUT,@pJson=@TableJson OUTPUT;
        SELECT N'FEATURE_MATRIX_BEFORE_ASSERTION' [FrameType],@Case [CaseNumber],@Count [PhysicalRowCount],@Status [StatusCode],@Partial [IsPartial],@Json [JsonOutput],@TableJson [PhysicalTableJson];
        IF COALESCE(@Count,-1)<>(SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.features'))
           OR COALESCE(@TableJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,'$.features'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
           OR (@Limit=1 AND @Count<>1)
            THROW 56052,N'Special feature shared output filter or limit failed.',1;
        IF COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.meta.featureRowCount')),-1)<>CASE WHEN @Case=5 THEN 0 ELSE 38 END
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.databaseStatus'))<>CASE WHEN @Case=5 THEN 1 WHEN @Case=4 THEN 3 ELSE 2 END
           OR COALESCE(@Status,'')<>CASE WHEN @Case=5 THEN 'DATABASE_UNAVAILABLE' WHEN @Case=4 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END
           OR COALESCE(CONVERT(int,@Partial),-1)<>CASE WHEN @Case>=4 THEN 1 ELSE 0 END
           OR COALESCE(JSON_VALUE(@Json,'$.meta.statusCode'),'')<>@Status
           OR COALESCE(JSON_VALUE(@Json,'$.meta.isPartial'),'')<>CASE WHEN @Case>=4 THEN 'true' ELSE 'false' END
            THROW 56055,N'Special feature complete status preservation failed.',1;
        IF EXISTS
          (SELECT [d].[DatabaseName] FROM
           (VALUES(CONVERT(sysname,N'ExampleSpecialSourceÄ') COLLATE SQL_Latin1_General_CP1_CS_AS),
                  (CONVERT(sysname,N'ExampleSpecialSourceä') COLLATE SQL_Latin1_General_CP1_CS_AS),
                  (CONVERT(sysname,N'ExampleSpecialMissingÖ') COLLATE SQL_Latin1_General_CP1_CS_AS)) [d]([DatabaseName])
           WHERE (@Case<5 AND [d].[DatabaseName]<>N'ExampleSpecialMissingÖ')
              OR (@Case>=4 AND [d].[DatabaseName]=N'ExampleSpecialMissingÖ')
           EXCEPT SELECT [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                  FROM OPENJSON(@Json,'$.databaseStatus') WITH([DatabaseName] nvarchar(128)))
            THROW 56061,N'Special feature exact database status identity failed.',1;
        IF @Case IN(1,4) AND NOT EXISTS
          (SELECT 1 FROM OPENJSON(@Json,'$.features') WITH([DatabaseName] nvarchar(128),[FeatureCode] varchar(64))
           WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=@FirstDatabase
             AND [FeatureCode] COLLATE SQL_Latin1_General_CP1_CS_AS=@FirstCode)
            THROW 56062,N'Special feature limited first row identity failed.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.features') [j] WHERE (SELECT COUNT_BIG(*) FROM OPENJSON([j].[value]))<>10)
           OR EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.features') WITH([DatabaseName] nvarchar(128),[FeatureCode] varchar(64),[DetectionStatus] varchar(40)) [j]
                     WHERE COALESCE([j].[DatabaseName],N'') COLLATE SQL_Latin1_General_CP1_CS_AS NOT IN(N'ExampleSpecialSourceÄ',N'ExampleSpecialSourceä')
                        OR NOT EXISTS(SELECT 1 FROM [#SpecialFeatureCollationRuntimeContract_Codes] [e] WHERE [e].[FeatureCode]=[j].[FeatureCode] COLLATE SQL_Latin1_General_CP1_CS_AS)
                        OR (@DetectedOnly=1 AND COALESCE([j].[DetectionStatus],'') NOT IN('DETECTED','CONFIGURED_ONLY')))
            THROW 56056,N'Special feature output identity failed.',1;
        IF @Case=0
        BEGIN
            IF @Count<>38 OR EXISTS
              (SELECT [d].[DatabaseName],[e].[FeatureCode]
               FROM (VALUES(N'ExampleSpecialSourceÄ'),(N'ExampleSpecialSourceä')) [d]([DatabaseName])
               CROSS JOIN [#SpecialFeatureCollationRuntimeContract_Codes] [e]
               EXCEPT SELECT [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS,[FeatureCode] COLLATE SQL_Latin1_General_CP1_CS_AS
                      FROM OPENJSON(@Json,'$.features') WITH([DatabaseName] nvarchar(128),[FeatureCode] varchar(64)))
                THROW 56057,N'Special feature full database-code matrix failed.',1;
            IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.features') WITH([FeatureCode] varchar(64),[DetectedItemCount] bigint,[DetectionStatus] varchar(40))
                WHERE [FeatureCode] IN('XML','SPATIAL','USER_DEFINED_TYPES') AND [DetectedItemCount]=1 AND [DetectionStatus]='DETECTED')<>6
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.features') WITH([FeatureCode] varchar(64),[DetectedItemCount] bigint)
                   WHERE [FeatureCode] IN('JSON_NATIVE','VECTOR') AND [DetectedItemCount]=0)<>4
                THROW 56058,N'Special feature synthetic positive and negative catalogue counters failed.',1;
            SELECT @FullDetectedCount=COUNT_BIG(*) FROM OPENJSON(@Json,'$.features') WITH([DetectionStatus] varchar(40))
            WHERE [DetectionStatus] IN('DETECTED','CONFIGURED_ONLY');
            INSERT [#SpecialFeatureCollationRuntimeContract_DetectedCounts]
            SELECT [DatabaseName],SUM(CONVERT(bigint,CASE WHEN [DetectionStatus] IN('DETECTED','CONFIGURED_ONLY') THEN 1 ELSE 0 END))
            FROM OPENJSON(@Json,'$.features') WITH([DatabaseName] nvarchar(128),[DetectionStatus] varchar(40))
            GROUP BY [DatabaseName];
        END;
        IF @Case<5 AND (COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.meta.detectedFeatureRowCount')),-1)<>@FullDetectedCount
                       OR (@Case=2 AND @Count<>@FullDetectedCount))
            THROW 56059,N'Special feature full detected count changed by export selection.',1;
        IF EXISTS(SELECT 1 FROM OPENJSON(@Json,'$.databaseStatus') WITH([DatabaseName] nvarchar(128),[StatusCode] varchar(40),[FeatureRows] bigint,[DetectedFeatureRows] bigint,[IsPartial] bit) [j]
                  LEFT JOIN [#SpecialFeatureCollationRuntimeContract_DetectedCounts] [e]
                    ON [e].[DatabaseName]=[j].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                  WHERE ([j].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS IN(N'ExampleSpecialSourceÄ',N'ExampleSpecialSourceä')
                         AND (COALESCE([j].[StatusCode],'')<>'AVAILABLE' OR COALESCE([j].[FeatureRows],-1)<>19
                              OR COALESCE([j].[DetectedFeatureRows],-1)<>[e].[DetectedRows] OR COALESCE(CONVERT(int,[j].[IsPartial]),-1)<>0))
                     OR ([j].[DatabaseName]=N'ExampleSpecialMissingÖ' AND (COALESCE([j].[StatusCode],'')<>'DATABASE_UNAVAILABLE'
                          OR COALESCE([j].[FeatureRows],-1)<>0 OR COALESCE([j].[DetectedFeatureRows],-1)<>0 OR COALESCE(CONVERT(int,[j].[IsPartial]),-1)<>1)))
            THROW 56060,N'Special feature per-database full status failed.',1;
        DROP TABLE [#SpecialFeatureCollationRuntimeContract_Collected];
        SET @OwnCollectedCreated=0;
        SET @Case+=1;
    END;
    /* Eigene Graph-Positivphase: NODE-Kontrolle und EDGE-Erkennung, ohne Graphdaten. */
    DECLARE @GraphDbBefore int=DB_ID(),@GraphLoginBefore int=SUSER_ID(),
            @GraphTranBefore int=@@TRANCOUNT,@GraphLockBefore int=@@LOCK_TIMEOUT,
            @GraphAbortBefore int=CASE WHEN (@@OPTIONS & 16384)<>0 THEN 1 ELSE 0 END,
            @GraphXactBefore int=NULL,@GraphDbAfter int=NULL,@GraphLoginAfter int=NULL,
            @GraphTranAfter int=NULL,@GraphLockAfter int=NULL,@GraphAbortAfter int=NULL,
            @GraphXactAfter int=NULL,@GraphNodeId int=NULL,@GraphEdgeId int=NULL,
            @GraphNativeCount bigint=NULL,@GraphBaselineDetected bigint=NULL,
            @GraphJson nvarchar(max)=NULL,@GraphTableJson nvarchar(max)=NULL,
            @GraphStatus varchar(40)=NULL,@GraphPartial bit=NULL,
            @GraphOwnCollectedCreated bit=0,@GraphTableCount bigint=NULL;
    SELECT @GraphXactBefore=XACT_STATE();
    BEGIN TRY
        SELECT @GraphBaselineDetected=[DetectedRows]
        FROM [#SpecialFeatureCollationRuntimeContract_DetectedCounts]
        WHERE [DatabaseName]=N'ExampleSpecialSourceÄ' COLLATE SQL_Latin1_General_CP1_CS_AS;
        SELECT @GraphNativeCount=COUNT_BIG(*)
        FROM [ExampleSpecialSourceÄ].[sys].[tables]
        WHERE [is_ms_shipped]=0 AND ([is_node]=1 OR [is_edge]=1);
        IF @OwnedUpperId IS NULL OR DB_ID(N'ExampleSpecialSourceÄ')<>@OwnedUpperId
           OR @GraphBaselineDetected IS NULL OR @GraphNativeCount<>0
            THROW 56880,N'Special feature own graph precondition failed.',1;
        EXEC(N'USE [ExampleSpecialSourceÄ];
CREATE TABLE [dbo].[ExampleFeatureGraphNodeÄ]([ExampleId] int NULL) AS NODE;
CREATE TABLE [dbo].[ExampleFeatureGraphEdgeÄ]([ExampleId] int NULL) AS EDGE;');
        SELECT @GraphNodeId=[object_id]
        FROM [ExampleSpecialSourceÄ].[sys].[tables]
        WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleFeatureGraphNodeÄ'
          AND [is_node]=1 AND [is_edge]=0;
        SELECT @GraphEdgeId=[object_id]
        FROM [ExampleSpecialSourceÄ].[sys].[tables]
        WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleFeatureGraphEdgeÄ'
          AND [is_edge]=1 AND [is_node]=0;
        SELECT @GraphNativeCount=COUNT_BIG(*)
        FROM [ExampleSpecialSourceÄ].[sys].[tables]
        WHERE [is_ms_shipped]=0 AND ([is_node]=1 OR [is_edge]=1);
        IF DB_ID(N'ExampleSpecialSourceÄ')<>@OwnedUpperId
           OR @GraphNodeId IS NULL OR @GraphEdgeId IS NULL OR @GraphNodeId=@GraphEdgeId
           OR @GraphNativeCount<>2
            THROW 56881,N'Special feature native NODE EDGE binding failed.',1;
        IF OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_GraphCollected') IS NOT NULL
            THROW 56882,N'Special feature graph TABLE target collision.',1;
        CREATE TABLE [#SpecialFeatureCollationRuntimeContract_GraphCollected]([Seed] bit NULL);
        SET @GraphOwnCollectedCreated=1;
        EXEC [monitor].[USP_SpecialFeatureInventory]
             @DatabaseNames=N'[ExampleSpecialSourceÄ]',@NurErkannteFeatures=1,@MaxZeilen=0,
             @ResultSetArt='TABLE',
             @ResultTablesJson=N'{"features":"#SpecialFeatureCollationRuntimeContract_GraphCollected"}',
             @JsonErzeugen=1,@Json=@GraphJson OUTPUT,@PrintMeldungen=0,
             @StatusCodeOut=@GraphStatus OUTPUT,@IsPartialOut=@GraphPartial OUTPUT;
        SELECT @GraphTableCount=COUNT_BIG(*) FROM [#SpecialFeatureCollationRuntimeContract_GraphCollected];
        SELECT @GraphTableJson=
          (SELECT * FROM [#SpecialFeatureCollationRuntimeContract_GraphCollected]
           ORDER BY [DatabaseName],[FeatureCode] FOR JSON PATH,INCLUDE_NULL_VALUES);
        IF COALESCE(ISJSON(@GraphJson),0)<>1
           OR COALESCE(@GraphStatus,'')<>'AVAILABLE'
           OR COALESCE(CONVERT(int,@GraphPartial),-1)<>0
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@GraphJson,N'$.meta.featureRowCount')),-1)<>19
           OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@GraphJson,N'$.meta.detectedFeatureRowCount')),-1)<>@GraphBaselineDetected+1
           OR COALESCE(@GraphTableCount,-1)<>@GraphBaselineDetected+1
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@GraphJson,N'$.features'))<>@GraphBaselineDetected+1
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@GraphJson,N'$.databaseStatus'))<>1
           OR NOT EXISTS
              (SELECT 1 FROM OPENJSON(@GraphJson,N'$.databaseStatus') WITH
                 ([DatabaseName] sysname '$.DatabaseName',[StatusCode] varchar(40) '$.StatusCode',
                  [IsPartial] bit '$.IsPartial',[FeatureRows] bigint '$.FeatureRows',
                  [DetectedFeatureRows] bigint '$.DetectedFeatureRows')
               WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSpecialSourceÄ'
                 AND [StatusCode]='AVAILABLE' AND [IsPartial]=0
                 AND [FeatureRows]=19 AND [DetectedFeatureRows]=@GraphBaselineDetected+1)
            THROW 56883,N'Special feature graph status or feature counts failed.',1;
        DECLARE @GraphExpectedSchema TABLE
          ([Ordinal] int NOT NULL PRIMARY KEY,
           [ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
           [SystemTypeId] tinyint NOT NULL,[MaxLength] smallint NOT NULL,
           [IsNullable] bit NOT NULL,
           [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        INSERT @GraphExpectedSchema VALUES
          (1,N'DatabaseName',231,256,0,N'SQL_Latin1_General_CP1_CS_AS'),
          (2,N'FeatureCode',167,64,0,N'SQL_Latin1_General_CP1_CS_AS'),
          (3,N'FeatureFamily',231,240,0,N'SQL_Latin1_General_CP1_CS_AS'),
          (4,N'DetectionStatus',167,40,0,N'SQL_Latin1_General_CP1_CS_AS'),
          (5,N'DetectedItemCount',127,8,1,NULL),
          (6,N'ConfigurationState',231,240,1,N'SQL_Latin1_General_CP1_CS_AS'),
          (7,N'SourceObjects',231,2000,0,N'SQL_Latin1_General_CP1_CS_AS'),
          (8,N'RecommendedModule',231,256,1,N'SQL_Latin1_General_CP1_CS_AS'),
          (9,N'RecommendedModuleStatus',167,40,0,N'SQL_Latin1_General_CP1_CS_AS'),
          (10,N'EvidenceLimit',231,2000,0,N'SQL_Latin1_General_CP1_CS_AS');
        IF EXISTS
           (SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])),
                   [name] COLLATE SQL_Latin1_General_CP1_CS_AS,
                   [system_type_id],[max_length],[is_nullable],
                   [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_GraphCollected')
            EXCEPT
            SELECT [Ordinal],[ColumnName],[SystemTypeId],[MaxLength],[IsNullable],[CollationName]
            FROM @GraphExpectedSchema)
           OR EXISTS
           (SELECT [Ordinal],[ColumnName],[SystemTypeId],[MaxLength],[IsNullable],[CollationName]
            FROM @GraphExpectedSchema
            EXCEPT
            SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY [column_id])),
                   [name] COLLATE SQL_Latin1_General_CP1_CS_AS,
                   [system_type_id],[max_length],[is_nullable],
                   [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS
            FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_GraphCollected'))
            THROW 56887,N'Special feature graph TABLE typed schema failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
            WHERE [object_id]=OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_GraphCollected'))<>10
           OR (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
               WHERE [object_id]=OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_GraphCollected')
                 AND [collation_name] IS NOT NULL)<>9
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                     WHERE [object_id]=OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_GraphCollected')
                       AND [collation_name] IS NOT NULL
                       AND [collation_name]<>N'SQL_Latin1_General_CP1_CS_AS')
           OR NOT EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                         WHERE [object_id]=OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_GraphCollected')
                           AND [name]=N'DetectedItemCount' AND [system_type_id]=127 AND [is_nullable]=1)
           OR EXISTS
              (SELECT 1 FROM OPENJSON(@GraphJson,N'$.features') [j]
               WHERE (SELECT COUNT_BIG(*) FROM OPENJSON([j].[value]))<>10)
           OR DATALENGTH(COALESCE(@GraphTableJson,N''))<>DATALENGTH(COALESCE(JSON_QUERY(@GraphJson,N'$.features'),N''))
           OR COALESCE(@GraphTableJson,N'') COLLATE SQL_Latin1_General_CP1_CS_AS
              <>COALESCE(JSON_QUERY(@GraphJson,N'$.features'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            THROW 56884,N'Special feature graph TABLE JSON ten-field parity failed.',1;
        IF (SELECT COUNT_BIG(*) FROM [#SpecialFeatureCollationRuntimeContract_GraphCollected]
            WHERE [FeatureCode]='GRAPH' AND [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSpecialSourceÄ'
              AND [DetectionStatus]='DETECTED' AND [DetectedItemCount]=@GraphNativeCount)<>1
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@GraphJson,N'$.features') WITH
               ([DatabaseName] sysname '$.DatabaseName',[FeatureCode] varchar(64) '$.FeatureCode',
                [DetectionStatus] varchar(40) '$.DetectionStatus',[DetectedItemCount] bigint '$.DetectedItemCount')
               WHERE [DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS=N'ExampleSpecialSourceÄ'
                 AND [FeatureCode]='GRAPH' AND [DetectionStatus]='DETECTED'
                 AND [DetectedItemCount]=@GraphNativeCount)<>1
            THROW 56885,N'Special feature graph native count or identity failed.',1;
        DROP TABLE [#SpecialFeatureCollationRuntimeContract_GraphCollected];
        SET @GraphOwnCollectedCreated=0;
    END TRY
    BEGIN CATCH
        BEGIN TRY
            IF @GraphOwnCollectedCreated=1
               AND OBJECT_ID(N'tempdb..#SpecialFeatureCollationRuntimeContract_GraphCollected') IS NOT NULL
                DROP TABLE [#SpecialFeatureCollationRuntimeContract_GraphCollected];
        END TRY
        BEGIN CATCH
            /* Der ursprüngliche Fehler bleibt für den bestehenden Outer-CATCH erhalten. */
        END CATCH;
        THROW;
    END CATCH;
    SELECT @GraphDbAfter=DB_ID(),@GraphLoginAfter=SUSER_ID(),
           @GraphTranAfter=@@TRANCOUNT,@GraphLockAfter=@@LOCK_TIMEOUT,
           @GraphAbortAfter=CASE WHEN (@@OPTIONS & 16384)<>0 THEN 1 ELSE 0 END;
    SELECT @GraphXactAfter=XACT_STATE();
    IF COALESCE(@GraphDbBefore,-1)<>COALESCE(@GraphDbAfter,-1)
       OR COALESCE(@GraphLoginBefore,-1)<>COALESCE(@GraphLoginAfter,-1)
       OR @GraphTranBefore<>@GraphTranAfter OR @GraphLockBefore<>@GraphLockAfter
       OR @GraphAbortBefore<>@GraphAbortAfter OR @GraphXactBefore<>@GraphXactAfter
    BEGIN
        DECLARE @GraphDbBeforeDiag int=COALESCE(@GraphDbBefore,-1),@GraphDbAfterDiag int=COALESCE(@GraphDbAfter,-1),
                @GraphLoginBeforeDiag int=COALESCE(@GraphLoginBefore,-1),@GraphLoginAfterDiag int=COALESCE(@GraphLoginAfter,-1),
                @GraphXactBeforeDiag int=COALESCE(@GraphXactBefore,-1),@GraphXactAfterDiag int=COALESCE(@GraphXactAfter,-1);
        RAISERROR(N'SPECIAL_GRAPH_CALLER db=%d/%d login=%d/%d tran=%d/%d lock=%d/%d abort=%d/%d xact=%d/%d',
                  10,1,@GraphDbBeforeDiag,@GraphDbAfterDiag,@GraphLoginBeforeDiag,@GraphLoginAfterDiag,
                  @GraphTranBefore,@GraphTranAfter,@GraphLockBefore,@GraphLockAfter,
                  @GraphAbortBefore,@GraphAbortAfter,@GraphXactBeforeDiag,@GraphXactAfterDiag) WITH NOWAIT;
        THROW 56886,N'Special feature graph caller state changed.',1;
    END;
    DROP TABLE [#SpecialFeatureCollationRuntimeContract_DetectedCounts];SET @OwnCountsCreated=0;
    DROP TABLE [#SpecialFeatureCollationRuntimeContract_Codes];SET @OwnCodesCreated=0;
    IF COALESCE(DB_ID(N'ExampleSpecialSourceä'),-1)<>COALESCE(@OwnedLowerId,-2)
       OR COALESCE(DB_ID(N'ExampleSpecialSourceÄ'),-1)<>COALESCE(@OwnedUpperId,-2)
        THROW 56063,N'Special feature owned database identity changed.',1;
    DROP DATABASE [ExampleSpecialSourceä];
    SET @OwnedLowerId=NULL;
    DROP DATABASE [ExampleSpecialSourceÄ];
    SET @OwnedUpperId=NULL;
    DECLARE @SuccessRestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @SuccessRestoreSql;
END TRY
BEGIN CATCH
    SELECT N'ORIGINAL_FEATURE_MATRIX_FAILURE' [FrameType],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    DECLARE @RestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    BEGIN TRY
        EXEC [sys].[sp_executesql] @RestoreSql;
    END TRY
    BEGIN CATCH
        SELECT N'OWN_FEATURE_MATRIX_CLEANUP_FAILURE' [FrameType],N'CALLER_RESTORE' [CleanupStep],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    END CATCH;
    BEGIN TRY
        IF @OwnCollectedCreated=1 DROP TABLE [#SpecialFeatureCollationRuntimeContract_Collected];
    END TRY
    BEGIN CATCH
        SELECT N'OWN_FEATURE_MATRIX_CLEANUP_FAILURE' [FrameType],N'Collected' [CleanupStep],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    END CATCH;
    BEGIN TRY
        IF @OwnCountsCreated=1 DROP TABLE [#SpecialFeatureCollationRuntimeContract_DetectedCounts];
    END TRY
    BEGIN CATCH
        SELECT N'OWN_FEATURE_MATRIX_CLEANUP_FAILURE' [FrameType],N'DetectedCounts' [CleanupStep],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    END CATCH;
    BEGIN TRY
        IF @OwnCodesCreated=1 DROP TABLE [#SpecialFeatureCollationRuntimeContract_Codes];
    END TRY
    BEGIN CATCH
        SELECT N'OWN_FEATURE_MATRIX_CLEANUP_FAILURE' [FrameType],N'Codes' [CleanupStep],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    END CATCH;
    BEGIN TRY
        IF @OwnedLowerId IS NOT NULL AND DB_ID(N'ExampleSpecialSourceä')=@OwnedLowerId
        BEGIN
            ALTER DATABASE [ExampleSpecialSourceä] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
            DROP DATABASE [ExampleSpecialSourceä];
        END;
    END TRY
    BEGIN CATCH
        SELECT N'OWN_FEATURE_MATRIX_CLEANUP_FAILURE' [FrameType],N'OwnedLowerId' [CleanupStep],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    END CATCH;
    BEGIN TRY
        IF @OwnedUpperId IS NOT NULL AND DB_ID(N'ExampleSpecialSourceÄ')=@OwnedUpperId
        BEGIN
            ALTER DATABASE [ExampleSpecialSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
            DROP DATABASE [ExampleSpecialSourceÄ];
        END;
    END TRY
    BEGIN CATCH
        SELECT N'OWN_FEATURE_MATRIX_CLEANUP_FAILURE' [FrameType],N'OwnedUpperId' [CleanupStep],ERROR_NUMBER() [ErrorNumber],ERROR_MESSAGE() [ErrorMessage];
    END CATCH;
    THROW;
END CATCH;
PRINT N'SPECIAL_FEATURE_COLLATION_RUNTIME_CONTRACT PASS';
GO
