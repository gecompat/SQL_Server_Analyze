USE [DeineDatenbank];
GO
-- Dieser Vertrag verwendet ausschließlich zwei eigene Datenbanken im neuen lokalen Testcontainer.
-- Er liest CT-Metadaten; Change-Zeilen, CDC-Enablement und Jobausführung sind nicht Bestandteil des Tests.
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @First sysname=N'ExampleCaptureÄ',@Second sysname=N'ExampleCaptureÜ',@Missing sysname=N'ExampleCaptureMissing',
        @FirstCreated bit=0,@SecondCreated bit=0,@FirstId int,@SecondId int,@Db sysname,@Sql nvarchar(max),
        @Fixture tinyint=0,@Case tinyint=0,@Limit int,@Rows bigint,@CtRows bigint,@Names nvarchar(max),@Json nvarchar(max);
IF DB_ID(@First) IS NOT NULL OR DB_ID(@Second) IS NOT NULL OR DB_ID(@Missing) IS NOT NULL
    THROW 55960,N'Die eigenen Change-Tracking-Fixturenamen sind nicht frei.',1;
CREATE TABLE [#ExampleCaptureNativeDb]
(
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,
 [IsCdcEnabled] bit,[IsChangeTrackingEnabled] bit,[RetentionPeriod] bigint,
 [RetentionPeriodUnitsDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS,[IsAutoCleanupOn] bit,[CurrentCtVersion] bigint,
 [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS
);
CREATE TABLE [#ExampleCaptureNativeCt]
(
 [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,
 [TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS,[ObjectId] int,[IsTrackColumnsUpdatedOn] bit,
 [BeginVersion] bigint,[CleanupVersion] bigint,[MinValidVersion] bigint
);
DECLARE @Parity TABLE([ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
BEGIN TRY
    WHILE @Fixture<2
    BEGIN
        SET @Db=CASE WHEN @Fixture=0 THEN @First ELSE @Second END;
        SET @Sql=N'CREATE DATABASE '+QUOTENAME(@Db)+N' COLLATE Latin1_General_100_CS_AS;'; EXEC(@Sql);
        IF @Fixture=0 SELECT @FirstCreated=1,@FirstId=DB_ID(@Db);
        ELSE SELECT @SecondCreated=1,@SecondId=DB_ID(@Db);
        SET @Sql=N'ALTER DATABASE '+QUOTENAME(@Db)+N' SET CHANGE_TRACKING=ON (CHANGE_RETENTION=2 DAYS,AUTO_CLEANUP=ON);'; EXEC(@Sql);
        SET @Sql=N'USE '+QUOTENAME(@Db)+N';
EXEC(N''CREATE SCHEMA [ExampleCtSchemaÄ];'');
CREATE TABLE [ExampleCtSchemaÄ].[ExampleCtTableÄ]([Id] int NOT NULL PRIMARY KEY,[Changed] int NULL);
CREATE TABLE [ExampleCtSchemaÄ].[ExampleCtTableÜ]([Id] int NOT NULL PRIMARY KEY,[Changed] int NULL);
ALTER TABLE [ExampleCtSchemaÄ].[ExampleCtTableÄ] ENABLE CHANGE_TRACKING WITH(TRACK_COLUMNS_UPDATED=ON);
ALTER TABLE [ExampleCtSchemaÄ].[ExampleCtTableÜ] ENABLE CHANGE_TRACKING WITH(TRACK_COLUMNS_UPDATED=OFF);
INSERT [ExampleCtSchemaÄ].[ExampleCtTableÄ] VALUES(1,1);
INSERT [ExampleCtSchemaÄ].[ExampleCtTableÜ] VALUES(1,1);
INSERT [#ExampleCaptureNativeDb]
SELECT [d].[name],[d].[state_desc],[d].[is_cdc_enabled],CONVERT(bit,1),[ct].[retention_period],
       [ct].[retention_period_units_desc],[ct].[is_auto_cleanup_on],CHANGE_TRACKING_CURRENT_VERSION(),''AVAILABLE'',NULL
FROM [sys].[databases] AS [d] JOIN [sys].[change_tracking_databases] AS [ct] ON [ct].[database_id]=[d].[database_id]
WHERE [d].[database_id]=DB_ID();
INSERT [#ExampleCaptureNativeCt]
SELECT DB_NAME(),[s].[name],[t].[name],[ct].[object_id],[ct].[is_track_columns_updated_on],
       [ct].[begin_version],[ct].[cleanup_version],CHANGE_TRACKING_MIN_VALID_VERSION([ct].[object_id])
FROM [sys].[change_tracking_tables] AS [ct] JOIN [sys].[tables] AS [t] ON [t].[object_id]=[ct].[object_id]
JOIN [sys].[schemas] AS [s] ON [s].[schema_id]=[t].[schema_id];'; EXEC(@Sql);
        SET @Fixture+=1;
    END;
    IF (SELECT COUNT_BIG(*) FROM [#ExampleCaptureNativeDb])<>2 OR (SELECT COUNT_BIG(*) FROM [#ExampleCaptureNativeCt])<>4
       OR EXISTS(SELECT 1 FROM [#ExampleCaptureNativeDb] WHERE COALESCE([IsCdcEnabled],1)<>0
          OR COALESCE([IsChangeTrackingEnabled],0)<>1 OR COALESCE([IsAutoCleanupOn],0)<>1
          OR COALESCE([RetentionPeriod],0)<>2 OR COALESCE([RetentionPeriodUnitsDesc],N'')<>N'DAYS'
          OR COALESCE([CurrentCtVersion],0)<=0 OR COALESCE([StateDesc],N'')<>N'ONLINE')
       OR (SELECT COUNT_BIG(*) FROM [#ExampleCaptureNativeCt] WHERE [IsTrackColumnsUpdatedOn]=1)<>2
       OR (SELECT COUNT_BIG(*) FROM [#ExampleCaptureNativeCt] WHERE [IsTrackColumnsUpdatedOn]=0)<>2
        THROW 55960,N'Die positiven nativen Change-Tracking-Fixtures sind nicht vorhanden.',1;
    WHILE @Case<4
    BEGIN
        SELECT @Limit=CASE WHEN @Case IN(1,3) THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END,
               @Rows=CASE WHEN @Case IN(1,3) THEN 1 ELSE 2 END,@CtRows=CASE WHEN @Case IN(1,3) THEN 1 ELSE 4 END,
               @Names=QUOTENAME(@First)+N'|'+QUOTENAME(@Second)+CASE WHEN @Case=3 THEN N'|'+QUOTENAME(@Missing) ELSE N'' END,@Json=NULL;
        CREATE TABLE [#ExampleCaptureDb]([Dummy] int NULL);
        EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=@Names,@MaxZeilen=@Limit,@ResultSetArt='TABLE',
           @ResultTablesJson=N'{"databases":"#ExampleCaptureDb"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
        IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCaptureDb') AND [collation_name] IS NOT NULL)<>5
           OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCaptureDb')
             AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
            THROW 55961,N'Der Data-Capture-Datenbankexport übernimmt eine fremde tempdb-Collation.',1;
        IF COALESCE(ISJSON(@Json),0)<>1
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>CASE WHEN @Case=3 THEN N'PARTIAL_RESULT' ELSE N'AVAILABLE' END
           OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @Case=3 THEN N'true' ELSE N'false' END
           OR (SELECT COUNT_BIG(*) FROM [#ExampleCaptureDb])<>@Rows
           OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.changeTrackingTables'))<>@CtRows
           OR COALESCE(JSON_QUERY(@Json,N'$.cdcTables'),N'')<>N'[]' OR COALESCE(JSON_QUERY(@Json,N'$.cdcJobs'),N'')<>N'[]'
           OR (@Case<>3 AND COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]')
           OR (@Case=3 AND ((SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.warnings'))<>1
              OR COALESCE(JSON_VALUE(@Json,N'$.warnings[0].DatabaseName'),N'')<>@Missing
              OR COALESCE(JSON_VALUE(@Json,N'$.warnings[0].SourceName'),N'')<>N'DATABASE_SELECTION'
              OR COALESCE(JSON_VALUE(@Json,N'$.warnings[0].StatusCode'),N'')<>N'DATABASE_UNAVAILABLE'
              OR NULLIF(JSON_VALUE(@Json,N'$.warnings[0].ErrorMessage'),N'') IS NULL))
            THROW 55962,N'Der Data-Capture-Status-, globale Limit- oder Warningvertrag ist verletzt.',1;
        DELETE @Parity;
        INSERT @Parity VALUES
           ((SELECT TOP(@Rows) * FROM [#ExampleCaptureNativeDb] ORDER BY [DatabaseName] FOR JSON PATH,INCLUDE_NULL_VALUES),
            (SELECT * FROM [#ExampleCaptureDb] FOR JSON PATH,INCLUDE_NULL_VALUES)),
           ((SELECT * FROM [#ExampleCaptureDb] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.databases')),
           ((SELECT TOP(@CtRows) * FROM [#ExampleCaptureNativeCt] ORDER BY [DatabaseName],[SchemaName],[TableName] FOR JSON PATH,INCLUDE_NULL_VALUES),
            JSON_QUERY(@Json,N'$.changeTrackingTables'));
        IF EXISTS(SELECT 1 FROM @Parity AS [p] WHERE LEFT(COALESCE([p].[ActualJson],N''),1)<>N'['
           OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]))
           OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
              EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ActualJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
              EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ExpectedJson]) AS [r]
              CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
              GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
            THROW 55964,N'Die native Data-Capture- oder TABLE-/JSON-Multimengenparität fehlt.',1;
        DROP TABLE [#ExampleCaptureDb];
        SET @Case+=1;
    END;
    DROP TABLE [#ExampleCaptureNativeDb]; DROP TABLE [#ExampleCaptureNativeCt];
END TRY
BEGIN CATCH
    IF @SecondCreated=1 AND DB_ID(@Second)=@SecondId BEGIN
        SET @Sql=N'DROP DATABASE '+QUOTENAME(@Second)+N';'; EXEC(@Sql);
    END;
    IF @FirstCreated=1 AND DB_ID(@First)=@FirstId BEGIN
        SET @Sql=N'DROP DATABASE '+QUOTENAME(@First)+N';'; EXEC(@Sql);
    END;
    THROW;
END CATCH;
IF @SecondCreated=1 AND DB_ID(@Second)=@SecondId BEGIN
    SET @Sql=N'DROP DATABASE '+QUOTENAME(@Second)+N';'; EXEC(@Sql);
END;
IF @FirstCreated=1 AND DB_ID(@First)=@FirstId BEGIN
    SET @Sql=N'DROP DATABASE '+QUOTENAME(@First)+N';'; EXEC(@Sql);
END;
IF DB_ID(@First) IS NOT NULL OR DB_ID(@Second) IS NOT NULL
    THROW 55965,N'Die eigenen Change-Tracking-Fixtures wurden nicht entfernt.',1;
GO
