USE [DeineDatenbank];
GO
/*
Prüft das gemeinsame gefilterte Featureexport mit synthetischen Katalogobjekten.
Die beiden eigenen Unicode-Datenbanken werden auch im Fehlerfall entfernt.
*/
SET NOCOUNT ON;
IF DB_ID(N'ExampleSpecialSourceÄ') IS NOT NULL OR DB_ID(N'ExampleSpecialSourceä') IS NOT NULL
    THROW 56050,N'Special feature fixture already exists.',1;
DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @OwnedUpperId int=NULL,@OwnedLowerId int=NULL;
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
    INSERT [#SpecialFeatureCollationRuntimeContract_Codes] VALUES
      ('IN_MEMORY_OLTP'),('TEMPORAL'),('SERVICE_BROKER'),('FULL_TEXT'),('CHANGE_TRACKING'),('CDC'),
      ('ENCRYPTION'),('CLR'),('EXTERNAL_TABLES'),('EXTERNAL_RUNTIME'),('EXTERNAL_SCRIPTS'),
      ('FILESTREAM_FILETABLE'),('GRAPH'),('SPATIAL'),('XML'),('JSON_NATIVE'),('VECTOR'),('USER_DEFINED_TYPES');
    CREATE TABLE [#SpecialFeatureCollationRuntimeContract_DetectedCounts]
    ([DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,[DetectedRows] bigint NOT NULL);
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
        IF COALESCE(@Count,-1)<>(SELECT COUNT_BIG(*) FROM OPENJSON(@Json,'$.features'))
           OR COALESCE(@TableJson,N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS<>COALESCE(JSON_QUERY(@Json,'$.features'),N'[]') COLLATE SQL_Latin1_General_CP1_CS_AS
           OR (@Limit=1 AND @Count<>1)
            THROW 56052,N'Special feature shared output filter or limit failed.',1;
        IF COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,'$.meta.featureRowCount')),-1)<>CASE WHEN @Case=5 THEN 0 ELSE 36 END
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
            IF @Count<>36 OR EXISTS
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
                         AND (COALESCE([j].[StatusCode],'')<>'AVAILABLE' OR COALESCE([j].[FeatureRows],-1)<>18
                              OR COALESCE([j].[DetectedFeatureRows],-1)<>[e].[DetectedRows] OR COALESCE(CONVERT(int,[j].[IsPartial]),-1)<>0))
                     OR ([j].[DatabaseName]=N'ExampleSpecialMissingÖ' AND (COALESCE([j].[StatusCode],'')<>'DATABASE_UNAVAILABLE'
                          OR COALESCE([j].[FeatureRows],-1)<>0 OR COALESCE([j].[DetectedFeatureRows],-1)<>0 OR COALESCE(CONVERT(int,[j].[IsPartial]),-1)<>1)))
            THROW 56060,N'Special feature per-database full status failed.',1;
        DROP TABLE [#SpecialFeatureCollationRuntimeContract_Collected];
        SET @Case+=1;
    END;
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
    DECLARE @RestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @RestoreSql;
    IF @OwnedLowerId IS NOT NULL AND DB_ID(N'ExampleSpecialSourceä')=@OwnedLowerId
    BEGIN
        ALTER DATABASE [ExampleSpecialSourceä] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleSpecialSourceä];
    END;
    IF @OwnedUpperId IS NOT NULL AND DB_ID(N'ExampleSpecialSourceÄ')=@OwnedUpperId
    BEGIN
        ALTER DATABASE [ExampleSpecialSourceÄ] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
        DROP DATABASE [ExampleSpecialSourceÄ];
    END;
    THROW;
END CATCH;
PRINT N'SPECIAL_FEATURE_COLLATION_RUNTIME_CONTRACT PASS';
GO
