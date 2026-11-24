USE [DeineDatenbank];
GO
-- Dieser Vertrag verwendet ausschließlich zwei eigene Datenbanken im neuen lokalen Testcontainer.
-- Er prüft CT-Metadaten und die Zuordnung registrierter CDC-Jobs. Er liest keine Change-Zeilen und startet keine Jobs.
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @First sysname=N'ExampleCaptureÄ',@Second sysname=N'ExampleCaptureÜ',@Missing sysname=N'ExampleCaptureMissing',
        @FirstCreated bit=0,@SecondCreated bit=0,@FirstId int,@SecondId int,@Db sysname,@Sql nvarchar(max),
        @Fixture tinyint=0,@Case tinyint=0,@Limit int,@Rows bigint,@CtRows bigint,@Names nvarchar(max),@Json nvarchar(max);
DECLARE @MappedJobName sysname=N'ExampleCaptureBoundCleanup',
        @DecoyJobName sysname=N'cdc.ExampleCaptureÄ_capture',
        @MappedJobId uniqueidentifier,@DecoyJobId uniqueidentifier,@DatabaseList nvarchar(258),
        @CleanupJobs nvarchar(max),@CleanupReader nvarchar(max),@ReaderSid varbinary(85),
        @Reader sysname=N'ExampleCaptureReader',@ReaderValue nvarchar(100),@NativeError int;
IF SUSER_ID(@Reader) IS NOT NULL OR USER_ID(@Reader) IS NOT NULL
   OR EXISTS(SELECT 1 FROM [msdb].[sys].[database_principals] WHERE [name]=@Reader COLLATE SQL_Latin1_General_CP1_CS_AS)
    THROW 55971,N'Die eigene CDC-Leseidentität ist nicht frei.',1;
IF EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [name] IN (@MappedJobName,@DecoyJobName))
    THROW 55966,N'Die eigenen CDC-Jobnamen sind nicht frei.',1;
IF DB_ID(@First) IS NOT NULL OR DB_ID(@Second) IS NOT NULL OR DB_ID(@Missing) IS NOT NULL
    THROW 55960,N'Die eigenen Change-Tracking-Fixturenamen sind nicht frei.',1;
SET @CleanupReader=N'
DECLARE @DropUser nvarchar(300)=N''DROP USER ''+QUOTENAME(@Name)+N'';'',
        @DropLogin nvarchar(300)=N''DROP LOGIN ''+QUOTENAME(@Name)+N'';'';
IF EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [name]=@Name AND [sid]=@Sid)
    EXEC [sys].[sp_executesql] @DropUser;
EXEC [msdb].[sys].[sp_executesql]
    N''IF EXISTS (SELECT 1 FROM [sys].[database_principals] WHERE [name]=@Name AND [sid]=@Sid)
          EXEC [sys].[sp_executesql] @DropUser;'',
    N''@Name sysname,@Sid varbinary(85),@DropUser nvarchar(300)'',
    @Name=@Name,@Sid=@Sid,@DropUser=@DropUser;
IF SUSER_SID(@Name)=@Sid
    EXEC [sys].[sp_executesql] @DropLogin;';
SET @CleanupJobs=N'
IF @Decoy IS NOT NULL AND EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@Decoy AND [name]=@DecoyName)
    EXEC [msdb].[dbo].[sp_delete_job] @job_id=@Decoy;
IF @DbId IS NOT NULL AND DB_ID(@DbName)=@DbId
   AND EXISTS (SELECT 1 FROM [master].[sys].[databases] WHERE [database_id]=@DbId AND [is_cdc_enabled]=1)
BEGIN
    DECLARE @Disable nvarchar(max)=N''USE ''+QUOTENAME(@DbName)+N''; EXEC [sys].[sp_cdc_disable_db];'';
    EXEC [sys].[sp_executesql] @Disable;
END;';
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
    SET @Sql=N'USE '+QUOTENAME(@First)+N';
        EXEC [sys].[sp_cdc_enable_db];
        EXEC [sys].[sp_cdc_add_job] @job_type=N''cleanup'',@start_job=0;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Sql=N'SELECT @JobId=[job_id] FROM [msdb].[dbo].[cdc_jobs]
        WHERE [database_id]=@DatabaseId AND [job_type]=N''cleanup'';';
    EXEC [sys].[sp_executesql] @Sql,N'@DatabaseId int,@JobId uniqueidentifier OUTPUT',
        @DatabaseId=@FirstId,@JobId=@MappedJobId OUTPUT;
    IF @MappedJobId IS NULL
       OR NOT EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id]=@MappedJobId)
        THROW 55967,N'Die native CDC-Zuordnung für den Bereinigungsjob fehlt.',1;
    EXEC [msdb].[dbo].[sp_update_job] @job_id=@MappedJobId,@new_name=@MappedJobName,@enabled=0;
    EXEC [msdb].[dbo].[sp_add_job] @job_name=@DecoyJobName,@enabled=0,@job_id=@DecoyJobId OUTPUT;
    SET @Sql=N'IF @Decoy IS NULL OR EXISTS(SELECT 1 FROM [msdb].[dbo].[cdc_jobs] WHERE [job_id]=@Decoy)
        THROW 55968,N''Der eigene Vergleichsjob darf keine CDC-Zuordnung besitzen.'',1;';
    EXEC [sys].[sp_executesql] @Sql,N'@Decoy uniqueidentifier',@Decoy=@DecoyJobId;
    SET @DatabaseList=QUOTENAME(@First);
    SET @Json=NULL;
    EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=@DatabaseList,@MaxZeilen=0,@ResultSetArt='NONE',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE'
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.databases')
            WHERE JSON_VALUE([value],N'$.IsCdcEnabled')=N'true')
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.cdcJobs'))<>1
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.cdcJobs')
            WHERE JSON_VALUE([value],N'$.DatabaseName')=@First
              AND JSON_VALUE([value],N'$.JobType')=N'CLEANUP'
              AND JSON_VALUE([value],N'$.JobName')=@MappedJobName
              AND JSON_VALUE([value],N'$.Enabled')=N'false')
        THROW 55969,N'Die CDC-Jobzuordnung stimmt nicht mit dem registrierten umbenannten Job überein.',1;

    EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=@DatabaseList,@HighImpactConfirmed=1,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus')
        WHERE JSON_VALUE([value],N'$.SourceCode')=N'CDC_JOBS'
          AND JSON_VALUE([value],N'$.StatusCode')=N'AVAILABLE')<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.cdcJobs'))<>1
       OR COALESCE(JSON_VALUE(@Json,N'$.cdcJobs[0].JobType'),N'')<>N'cleanup'
        THROW 55972,N'Die Tiefenanalyse liefert den registrierten CDC-Job im berechtigten Kontext nicht.',1;

    SET @ReaderValue=N'X!9q'+CONVERT(nvarchar(36),NEWID());
    SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Reader)+N' WITH PASSWORD '+N'= '+QUOTENAME(@ReaderValue,'''')+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @ReaderSid=SUSER_SID(@Reader);
    SET @Sql=N'CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';
        GRANT EXECUTE ON [monitor].[USP_DataCaptureDeepAnalysis] TO '+QUOTENAME(@Reader)+N';
        USE '+QUOTENAME(@First)+N';
        CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';
        GRANT VIEW DEFINITION TO '+QUOTENAME(@Reader)+N';
        GRANT VIEW DATABASE STATE TO '+QUOTENAME(@Reader)+N';
        USE [msdb];
        CREATE USER '+QUOTENAME(@Reader)+N' FOR LOGIN '+QUOTENAME(@Reader)+N';
        DENY SELECT ON [dbo].[cdc_jobs] TO '+QUOTENAME(@Reader)+N';';
    EXEC [sys].[sp_executesql] @Sql;
    SET @NativeError=NULL;
    SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Reader,'''')+N';
    BEGIN TRY
        IF EXISTS(SELECT 1 FROM [msdb].[sys].[tables] AS [t]
            INNER JOIN [msdb].[sys].[schemas] AS [s] ON [s].[schema_id]=[t].[schema_id]
            WHERE [s].[name]=N''dbo'' AND [t].[name]=N''cdc_jobs'')
            THROW 55973,N''Die CDC-Quelle ist für den eingeschränkten Testaufrufer sichtbar.'',1;
        BEGIN TRY
            EXEC [sys].[sp_executesql] N''DECLARE @Count bigint; SELECT @Count=COUNT_BIG(*) FROM [msdb].[dbo].[cdc_jobs];'';
        END TRY
        BEGIN CATCH
            SET @ReadError=ERROR_NUMBER();
        END CATCH;
        EXEC [monitor].[USP_DataCaptureDeepAnalysis] @DatabaseNames=@Names,@HighImpactConfirmed=1,
            @ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@Payload OUTPUT,@PrintMeldungen=0;
        REVERT;
    END TRY
    BEGIN CATCH
        REVERT;
        THROW;
    END CATCH;';
    EXEC [sys].[sp_executesql] @Sql,N'@Names nvarchar(258),@ReadError int OUTPUT,@Payload nvarchar(max) OUTPUT',
        @Names=@DatabaseList,@ReadError=@NativeError OUTPUT,@Payload=@Json OUTPUT;
    IF COALESCE(@NativeError,0)<>229
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'true'
       OR COALESCE(JSON_QUERY(@Json,N'$.cdcJobs'),N'')<>N'[]'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus')
           WHERE JSON_VALUE([value],N'$.SourceCode')=N'CDC_JOBS'
             AND JSON_VALUE([value],N'$.StatusCode')=N'DENIED_PERMISSION'
             AND JSON_VALUE([value],N'$.ErrorNumber')=N'229')<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.sourceStatus')
           WHERE JSON_VALUE([value],N'$.SourceCode')=N'CHANGE_TRACKING_TABLES'
             AND JSON_VALUE([value],N'$.StatusCode')=N'AVAILABLE'
             AND JSON_VALUE([value],N'$.RowCount')=N'2')<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.changeTrackingTables'))<>2
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.changeTrackingTables')
           WHERE JSON_VALUE([value],N'$.DatabaseName')=@First
             AND JSON_VALUE([value],N'$.SchemaName')=N'ExampleCtSchemaÄ'
             AND JSON_VALUE([value],N'$.TableName')=N'ExampleCtTableÄ'
             AND JSON_VALUE([value],N'$.IsTrackColumnsUpdatedOn')=N'true')
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.changeTrackingTables')
           WHERE JSON_VALUE([value],N'$.DatabaseName')=@First
             AND JSON_VALUE([value],N'$.SchemaName')=N'ExampleCtSchemaÄ'
             AND JSON_VALUE([value],N'$.TableName')=N'ExampleCtTableÜ'
             AND JSON_VALUE([value],N'$.IsTrackColumnsUpdatedOn')=N'false')
        THROW 55974,N'Die Tiefenanalyse muss verweigerte CDC-Jobdaten melden und zugängliche CT-Daten erhalten.',1;
    EXEC [sys].[sp_executesql] @CleanupReader,N'@Name sysname,@Sid varbinary(85)',@Name=@Reader,@Sid=@ReaderSid;
    IF SUSER_SID(@Reader) IS NOT NULL OR USER_ID(@Reader) IS NOT NULL
       OR EXISTS(SELECT 1 FROM [msdb].[sys].[database_principals] WHERE [sid]=@ReaderSid)
        THROW 55975,N'Die eigene CDC-Leseidentität wurde nicht entfernt.',1;

    EXEC [sys].[sp_executesql] @CleanupJobs,N'@DbId int,@DbName sysname,@Decoy uniqueidentifier,@DecoyName sysname',
        @DbId=@FirstId,@DbName=@First,@Decoy=@DecoyJobId,@DecoyName=@DecoyJobName;
    IF EXISTS(SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] IN (@MappedJobId,@DecoyJobId))
        THROW 55970,N'Die eigenen CDC-Jobs wurden nicht entfernt.',1;
    DROP TABLE [#ExampleCaptureNativeDb]; DROP TABLE [#ExampleCaptureNativeCt];
END TRY
BEGIN CATCH
    BEGIN TRY
        IF @ReaderSid IS NOT NULL
            EXEC [sys].[sp_executesql] @CleanupReader,N'@Name sysname,@Sid varbinary(85)',@Name=@Reader,@Sid=@ReaderSid;
    END TRY
    BEGIN CATCH
        PRINT CONCAT(N'CDC-Fixture: Leseidentität nicht entfernt. SQL-Fehler ',ERROR_NUMBER());
    END CATCH;

    BEGIN TRY
        EXEC [sys].[sp_executesql] @CleanupJobs,N'@DbId int,@DbName sysname,@Decoy uniqueidentifier,@DecoyName sysname',
            @DbId=@FirstId,@DbName=@First,@Decoy=@DecoyJobId,@DecoyName=@DecoyJobName;
    END TRY
    BEGIN CATCH
        PRINT CONCAT(N'CDC-Fixture: Jobbereinigung fehlgeschlagen. SQL-Fehler ',ERROR_NUMBER());
    END CATCH;

    BEGIN TRY
        IF @SecondCreated=1 AND DB_ID(@Second)=@SecondId BEGIN
            SET @Sql=N'DROP DATABASE '+QUOTENAME(@Second)+N';'; EXEC(@Sql);
        END;
    END TRY
    BEGIN CATCH
        PRINT CONCAT(N'CDC-Fixture: Zweite Datenbank nicht entfernt. SQL-Fehler ',ERROR_NUMBER());
    END CATCH;

    BEGIN TRY
        IF @FirstCreated=1 AND DB_ID(@First)=@FirstId BEGIN
            SET @Sql=N'DROP DATABASE '+QUOTENAME(@First)+N';'; EXEC(@Sql);
        END;
    END TRY
    BEGIN CATCH
        PRINT CONCAT(N'CDC-Fixture: Erste Datenbank nicht entfernt. SQL-Fehler ',ERROR_NUMBER());
    END CATCH;
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
