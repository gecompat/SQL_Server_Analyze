USE [DeineDatenbank];
GO
SET NOCOUNT ON;
DECLARE @DatabaseId int=DB_ID(),@Database sysname=DB_NAME(),@Names nvarchar(max)=QUOTENAME(DB_NAME())+N'|[master]',
        @Profile nvarchar(max),@Json nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),
        @Case tinyint=0,@Limit int,@ExpectedSettings bigint,@FirstDriftDatabaseId int,
        @FirstDriftSetting nvarchar(128),@FirstDriftActual nvarchar(4000),@FirstDriftReference nvarchar(4000);
CREATE TABLE [#ExampleConfigurationNative]
(
    [DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SettingScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SettingName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ActualValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SecondaryValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsDefault] bit NULL,
    [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
INSERT [#ExampleConfigurationNative]
SELECT [d].[database_id],[d].[name],'DATABASE',[v].[SettingName],[v].[ActualValue],NULL,NULL,N'master.sys.databases'
FROM [master].[sys].[databases] AS [d] CROSS APPLY
(VALUES
 (CONVERT(nvarchar(128),N'COMPATIBILITY_LEVEL'),CONVERT(nvarchar(4000),[d].[compatibility_level])),
 (N'COLLATION',CONVERT(nvarchar(4000),[d].[collation_name])),(N'RECOVERY_MODEL',CONVERT(nvarchar(4000),[d].[recovery_model_desc])),
 (N'PAGE_VERIFY',CONVERT(nvarchar(4000),[d].[page_verify_option_desc])),
 (N'AUTO_CLOSE',CASE [d].[is_auto_close_on] WHEN 1 THEN N'ON' ELSE N'OFF' END),
 (N'AUTO_SHRINK',CASE [d].[is_auto_shrink_on] WHEN 1 THEN N'ON' ELSE N'OFF' END),
 (N'AUTO_CREATE_STATS',CASE [d].[is_auto_create_stats_on] WHEN 1 THEN N'ON' ELSE N'OFF' END),
 (N'AUTO_UPDATE_STATS',CASE [d].[is_auto_update_stats_on] WHEN 1 THEN N'ON' ELSE N'OFF' END),
 (N'AUTO_UPDATE_STATS_ASYNC',CASE [d].[is_auto_update_stats_async_on] WHEN 1 THEN N'ON' ELSE N'OFF' END),
 (N'READ_COMMITTED_SNAPSHOT',CASE [d].[is_read_committed_snapshot_on] WHEN 1 THEN N'ON' ELSE N'OFF' END),
 (N'SNAPSHOT_ISOLATION',CONVERT(nvarchar(4000),[d].[snapshot_isolation_state_desc])),
 (N'PARAMETERIZATION',CASE [d].[is_parameterization_forced] WHEN 1 THEN N'FORCED' ELSE N'SIMPLE' END),
 (N'QUERY_STORE',CASE [d].[is_query_store_on] WHEN 1 THEN N'ON' ELSE N'OFF' END),
 (N'ACCELERATED_DATABASE_RECOVERY',CASE [d].[is_accelerated_database_recovery_on] WHEN 1 THEN N'ON' ELSE N'OFF' END)
) AS [v]([SettingName],[ActualValue]) WHERE [d].[database_id] IN(DB_ID(),1);
IF COL_LENGTH(N'master.sys.databases',N'is_optimized_locking_on') IS NOT NULL
    EXEC [sys].[sp_executesql] N'INSERT [#ExampleConfigurationNative]
       SELECT [database_id],[name],''DATABASE'',N''OPTIMIZED_LOCKING'',CASE [is_optimized_locking_on] WHEN 1 THEN N''ON'' ELSE N''OFF'' END,NULL,NULL,N''master.sys.databases''
       FROM [master].[sys].[databases] WHERE [database_id] IN(@DatabaseId,1);',N'@DatabaseId int',@DatabaseId=@DatabaseId;
DECLARE @NativeDatabase sysname,@Sql nvarchar(max);
DECLARE [ExampleConfigurationCursor] CURSOR LOCAL FAST_FORWARD FOR
    SELECT [name] FROM [master].[sys].[databases] WHERE [database_id] IN(DB_ID(),1);
OPEN [ExampleConfigurationCursor]; FETCH NEXT FROM [ExampleConfigurationCursor] INTO @NativeDatabase;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @Sql=N'INSERT [#ExampleConfigurationNative]
        SELECT DB_ID(@Database),@Database,''SCOPED'',CONVERT(nvarchar(128),[name]),CONVERT(nvarchar(4000),[value]),
               CONVERT(nvarchar(4000),[value_for_secondary]),[is_value_default],N''sys.database_scoped_configurations''
        FROM '+QUOTENAME(@NativeDatabase)+N'.[sys].[database_scoped_configurations];
        INSERT [#ExampleConfigurationNative]
        SELECT DB_ID(@Database),@Database,''QUERY_STORE'',[v].[SettingName],[v].[ActualValue],NULL,NULL,N''sys.database_query_store_options''
        FROM '+QUOTENAME(@NativeDatabase)+N'.[sys].[database_query_store_options] AS [q] CROSS APPLY
        (VALUES
         (CONVERT(nvarchar(128),N''DESIRED_STATE''),CONVERT(nvarchar(4000),[q].[desired_state_desc])),
         (N''ACTUAL_STATE'',CONVERT(nvarchar(4000),[q].[actual_state_desc])),(N''READONLY_REASON'',CONVERT(nvarchar(4000),[q].[readonly_reason])),
         (N''CURRENT_STORAGE_SIZE_MB'',CONVERT(nvarchar(4000),[q].[current_storage_size_mb])),
         (N''MAX_STORAGE_SIZE_MB'',CONVERT(nvarchar(4000),[q].[max_storage_size_mb])),
         (N''STALE_QUERY_THRESHOLD_DAYS'',CONVERT(nvarchar(4000),[q].[stale_query_threshold_days])),
         (N''FLUSH_INTERVAL_SECONDS'',CONVERT(nvarchar(4000),[q].[flush_interval_seconds])),
         (N''INTERVAL_LENGTH_MINUTES'',CONVERT(nvarchar(4000),[q].[interval_length_minutes])),
         (N''QUERY_CAPTURE_MODE'',CONVERT(nvarchar(4000),[q].[query_capture_mode_desc])),
         (N''SIZE_BASED_CLEANUP_MODE'',CONVERT(nvarchar(4000),[q].[size_based_cleanup_mode_desc])),
         (N''WAIT_STATS_CAPTURE_MODE'',CONVERT(nvarchar(4000),[q].[wait_stats_capture_mode_desc]))
        ) AS [v]([SettingName],[ActualValue]);';
    EXEC [sys].[sp_executesql] @Sql,N'@Database sysname',@Database=@NativeDatabase;
    FETCH NEXT FROM [ExampleConfigurationCursor] INTO @NativeDatabase;
END;
CLOSE [ExampleConfigurationCursor]; DEALLOCATE [ExampleConfigurationCursor];
IF (SELECT COUNT(*) FROM [#ExampleConfigurationNative] WHERE [SettingName]=N'AUTO_CLOSE' AND [ActualValue]=N'OFF')<>2
    THROW 55900,N'Die eigenen frischen Testdatenbanken erfüllen die AUTO_CLOSE-Voraussetzung nicht.',1;
SET @Profile=N'[{"settingScope":"DATABASE","settingName":"COLLATION","expectedValue":"ExampleExpectedÄ"},{"settingScope":"DATABASE","settingName":"AUTO_CLOSE","expectedValue":"OFF"},{"settingScope":"SCOPED","settingName":"MAXDOP","expectedValue":"ExampleExpectedÜ"},{"settingScope":"QUERY_STORE","settingName":"ExampleMissingSetting","expectedValue":"ExampleExpectedValue"}]';
SELECT TOP(1) @FirstDriftDatabaseId=[n].[DatabaseId],@FirstDriftSetting=[n].[SettingName],
              @FirstDriftActual=[n].[ActualValue],@FirstDriftReference=[r].[ReferenceValue]
FROM [#ExampleConfigurationNative] AS [n] INNER JOIN
(
    SELECT [SettingName],MIN([ActualValue]) AS [ReferenceValue]
    FROM [#ExampleConfigurationNative] WHERE [SettingScope]='DATABASE'
    GROUP BY [SettingName] HAVING COUNT(DISTINCT [ActualValue])>1
) AS [r] ON [r].[SettingName]=[n].[SettingName]
WHERE [n].[SettingScope]='DATABASE' AND [n].[ActualValue]<>[r].[ReferenceValue]
ORDER BY [n].[SettingName],[n].[DatabaseName];
IF @FirstDriftDatabaseId IS NULL
    THROW 55900,N'Die frischen Testdatenbanken besitzen keine native lokale Optionsvariation.',1;
DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
WHILE @Case<3
BEGIN
    SET @Limit=CASE WHEN @Case=0 THEN 0 WHEN @Case=1 THEN 1 ELSE NULL END;
    CREATE TABLE [#ExampleConfigurationModule]([Dummy] int NULL);
    CREATE TABLE [#ExampleConfigurationSettings]([Dummy] int NULL);
    CREATE TABLE [#ExampleConfigurationDrift]([Dummy] int NULL);
    CREATE TABLE [#ExampleConfigurationProfile]([Dummy] int NULL);
    CREATE TABLE [#ExampleConfigurationSources]([Dummy] int NULL);
    CREATE TABLE [#ExampleConfigurationWarnings]([Dummy] int NULL);
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    EXEC [monitor].[USP_DatabaseConfigurationAnalysis] @DatabaseNames=@Names,@SystemdatenbankenEinbeziehen=1,
      @ProfileJson=@Profile,@MaxZeilen=@Limit,@ResultSetArt='TABLE',
      @ResultTablesJson=N'{"moduleStatus":"#ExampleConfigurationModule","settings":"#ExampleConfigurationSettings","drift":"#ExampleConfigurationDrift","profile":"#ExampleConfigurationProfile","sourceStatus":"#ExampleConfigurationSources","warnings":"#ExampleConfigurationWarnings"}',
      @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
      @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id] IN(OBJECT_ID(N'tempdb..#ExampleConfigurationModule'),OBJECT_ID(N'tempdb..#ExampleConfigurationSettings'),
          OBJECT_ID(N'tempdb..#ExampleConfigurationDrift'),OBJECT_ID(N'tempdb..#ExampleConfigurationProfile'),
          OBJECT_ID(N'tempdb..#ExampleConfigurationSources'),OBJECT_ID(N'tempdb..#ExampleConfigurationWarnings')) AND [collation_name] IS NOT NULL)<>32
       OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
        WHERE [object_id] IN(OBJECT_ID(N'tempdb..#ExampleConfigurationModule'),OBJECT_ID(N'tempdb..#ExampleConfigurationSettings'),
          OBJECT_ID(N'tempdb..#ExampleConfigurationDrift'),OBJECT_ID(N'tempdb..#ExampleConfigurationProfile'),
          OBJECT_ID(N'tempdb..#ExampleConfigurationSources'),OBJECT_ID(N'tempdb..#ExampleConfigurationWarnings'))
          AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55901,N'Die Konfigurationsexporte übernehmen eine fremde tempdb-Collation.',1;
    SELECT @ExpectedSettings=CASE WHEN @Case=1 THEN 1 ELSE COUNT_BIG(*) END FROM [#ExampleConfigurationNative];
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE' OR COALESCE(@Partial,1)<>0
       OR @Error IS NOT NULL OR @Message IS NOT NULL OR (SELECT COUNT_BIG(*) FROM [#ExampleConfigurationModule])<>1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleConfigurationSettings])<>@ExpectedSettings
       OR (@Case=1 AND (SELECT COUNT_BIG(*) FROM [#ExampleConfigurationDrift])<>1)
       OR (SELECT COUNT_BIG(*) FROM [#ExampleConfigurationProfile])<>4
       OR (SELECT COUNT_BIG(*) FROM [#ExampleConfigurationSources])<>6
       OR (SELECT COUNT_BIG(*) FROM [#ExampleConfigurationWarnings])<>1
       OR NOT EXISTS(SELECT 1 FROM [#ExampleConfigurationModule] WHERE [ModuleName]=N'USP_DatabaseConfigurationAnalysis'
          AND [StatusCode]='AVAILABLE' AND [IsPartial]=0 AND [DatabaseCount]=2 AND [CrossDatabaseRequested]=1
          AND [SettingRowCount]=@ExpectedSettings AND [DriftRowCount]=(SELECT COUNT_BIG(*) FROM [#ExampleConfigurationDrift])
          AND [ProfileEntryCount]=4 AND [HasMoreSettingRows]=CASE WHEN @Case=1 THEN 1 ELSE 0 END
          AND [HasMoreDriftRows]=CASE WHEN @Case=1 THEN 1 ELSE 0 END AND [ErrorNumber] IS NULL AND [ErrorMessage] IS NULL)
       OR EXISTS(SELECT 1 FROM [#ExampleConfigurationSources] GROUP BY [DatabaseId],[SourceName] HAVING COUNT_BIG(*)<>1)
       OR EXISTS(SELECT 1 FROM [#ExampleConfigurationSources] AS [s]
          WHERE [StatusCode]<>'AVAILABLE' OR [IsPartial]<>0 OR [ErrorNumber] IS NOT NULL OR [ErrorMessage] IS NOT NULL
             OR [DatabaseId] IS NULL OR [DatabaseId] NOT IN(DB_ID(),1) OR [DatabaseName] IS NULL OR [DatabaseName]<>DB_NAME([DatabaseId])
             OR [ReturnedRowCount]<>CASE [SourceName] WHEN N'databaseOptions' THEN 14
                  WHEN N'scopedConfigurations' THEN (SELECT COUNT_BIG(*) FROM [#ExampleConfigurationNative] AS [n] WHERE [n].[DatabaseId]=[s].[DatabaseId] AND [n].[SettingScope]='SCOPED')
                  WHEN N'queryStoreOptions' THEN (SELECT COUNT_BIG(*) FROM [#ExampleConfigurationNative] AS [n] WHERE [n].[DatabaseId]=[s].[DatabaseId] AND [n].[SettingScope]='QUERY_STORE') ELSE -1 END)
       OR NOT EXISTS(SELECT 1 FROM [#ExampleConfigurationWarnings] WHERE [WarningOrdinal]=1 AND [DatabaseName] IS NULL
          AND [SourceName]=N'profile' AND [StatusCode]='PROFILE_SETTING_NOT_VISIBLE' AND [ErrorNumber] IS NULL
          AND [Message]=N'Profileintrag nicht in sichtbarer Evidenz gefunden: QUERY_STORE/ExampleMissingSetting.')
        THROW 55902,N'Der Konfigurationsstatus-, Quellenzähler- oder Limitvertrag ist verletzt.',1;
    IF @Case=1 AND NOT EXISTS(SELECT 1 FROM [#ExampleConfigurationDrift] WHERE [DriftType]='LOCAL_VARIATION'
         AND [SettingScope]='DATABASE' AND [DatabaseId]=@FirstDriftDatabaseId AND [SettingName]=@FirstDriftSetting
         AND [ActualValue]=@FirstDriftActual AND [ReferenceValue]=@FirstDriftReference
         AND [MatchingDatabaseCount]=1 AND [ComparedDatabaseCount]=2 AND [FindingCode]='LOCAL_CONFIGURATION_VARIATION')
        THROW 55905,N'Das Driftlimit erhält nicht die nativ erwartete erste lokale Optionsvariation.',1;
    DELETE @Parity;
    INSERT @Parity VALUES
      ((SELECT * FROM [#ExampleConfigurationSettings] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.settings')),
      ((SELECT * FROM [#ExampleConfigurationDrift] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.drift')),
      ((SELECT * FROM [#ExampleConfigurationProfile] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.profile')),
      ((SELECT CONVERT(int,[j].[key])+1 AS [ProfileOrdinal],[p].[SettingScope],[p].[SettingName],[p].[ExpectedValue]
          FROM OPENJSON(@Profile) AS [j] CROSS APPLY OPENJSON([j].[value]) WITH([SettingScope] varchar(32) '$.settingScope',[SettingName] nvarchar(128) '$.settingName',[ExpectedValue] nvarchar(4000) '$.expectedValue') AS [p]
          FOR JSON PATH,INCLUDE_NULL_VALUES),(SELECT * FROM [#ExampleConfigurationProfile] FOR JSON PATH,INCLUDE_NULL_VALUES)),
      ((SELECT * FROM [#ExampleConfigurationSources] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.sourceStatus')),
      ((SELECT * FROM [#ExampleConfigurationWarnings] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.warnings')),
      ((SELECT TOP(CASE WHEN @Case=1 THEN 1 ELSE 2147483647 END) [DatabaseId],[DatabaseName],[SettingScope],[SettingName],
           CASE WHEN [SettingScope]='QUERY_STORE' AND [SettingName] IN(N'ACTUAL_STATE',N'READONLY_REASON',N'CURRENT_STORAGE_SIZE_MB') THEN N'ExampleVolatileValue' ELSE [ActualValue] END AS [ActualValue],
           [SecondaryValue],[IsDefault],[SourceObject] FROM [#ExampleConfigurationNative]
           ORDER BY [DatabaseName],[SettingScope],[SettingName] FOR JSON PATH,INCLUDE_NULL_VALUES),
       (SELECT [DatabaseId],[DatabaseName],[SettingScope],[SettingName],
           CASE WHEN [SettingScope]='QUERY_STORE' AND [SettingName] IN(N'ACTUAL_STATE',N'READONLY_REASON',N'CURRENT_STORAGE_SIZE_MB') THEN N'ExampleVolatileValue' ELSE [ActualValue] END AS [ActualValue],
           [SecondaryValue],[IsDefault],[SourceObject] FROM [#ExampleConfigurationSettings] FOR JSON PATH,INCLUDE_NULL_VALUES));
    IF EXISTS(SELECT 1 FROM @Parity AS [p]
       WHERE LEFT(COALESCE([p].[ModuleJson],N''),1)<>N'['
         OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[TableJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]))
         OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[TableJson]) AS [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]) AS [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
         OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]) AS [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[TableJson]) AS [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
        THROW 55903,N'Der native Konfigurations- oder TABLE-/JSON-Multimengenvertrag ist verletzt.',1;
    IF EXISTS(SELECT 1 FROM [#ExampleConfigurationSettings] WHERE [SettingScope]='QUERY_STORE' AND [SettingName]=N'ACTUAL_STATE'
                AND ([ActualValue] IS NULL OR [ActualValue] NOT IN(N'OFF',N'READ_ONLY',N'READ_WRITE',N'ERROR',N'READ_CAPTURE_SECONDARY')))
        THROW 55904,N'Der flüchtige Query-Store-Zustand ist ungültig.',1;
    IF EXISTS(SELECT 1 FROM [#ExampleConfigurationSettings]
        WHERE [SettingScope]='QUERY_STORE' AND [SettingName] IN(N'READONLY_REASON',N'CURRENT_STORAGE_SIZE_MB')
          AND (TRY_CONVERT(decimal(38,4),[ActualValue]) IS NULL OR TRY_CONVERT(decimal(38,4),[ActualValue])<0))
        THROW 55904,N'Ein flüchtiger Query-Store-Zustandswert ist numerisch ungültig.',1;
    IF @Case<>1 AND
       ((SELECT COUNT(*) FROM [#ExampleConfigurationDrift] WHERE [DriftType]='PROFILE_MISMATCH')<>4
        OR EXISTS(SELECT 1 FROM [#ExampleConfigurationDrift] WHERE [DriftType]='PROFILE_MISMATCH' GROUP BY [DatabaseId],[SettingName] HAVING COUNT_BIG(*)<>1)
        OR NOT EXISTS(SELECT 1 FROM [#ExampleConfigurationDrift] WHERE [DriftType]='LOCAL_VARIATION' AND [SettingName]=N'COLLATION')
        OR EXISTS(SELECT 1 FROM [#ExampleConfigurationDrift] AS [d] LEFT JOIN [#ExampleConfigurationNative] AS [n]
          ON [n].[DatabaseId]=[d].[DatabaseId] AND [n].[SettingScope]=[d].[SettingScope] AND [n].[SettingName]=[d].[SettingName]
          WHERE [d].[DriftType]='PROFILE_MISMATCH' AND
            ([n].[DatabaseId] IS NULL OR [d].[ActualValue] IS NULL OR [d].[ActualValue]<>[n].[ActualValue]
             OR [d].[ComparedDatabaseCount]<>1 OR [d].[MatchingDatabaseCount] IS NOT NULL
             OR [d].[FindingCode]<>'EXPLICIT_PROFILE_MISMATCH'
             OR [d].[ReferenceValue] IS NULL OR [d].[ReferenceValue]<>CASE [d].[SettingName] WHEN N'COLLATION' THEN N'ExampleExpectedÄ' WHEN N'MAXDOP' THEN N'ExampleExpectedÜ' ELSE N'ExampleUnexpected' END)))
        THROW 55905,N'Die native lokale Variation oder synthetische Profilzuordnung fehlt.',1;
    DROP TABLE [#ExampleConfigurationModule]; DROP TABLE [#ExampleConfigurationSettings]; DROP TABLE [#ExampleConfigurationDrift];
    DROP TABLE [#ExampleConfigurationProfile]; DROP TABLE [#ExampleConfigurationSources]; DROP TABLE [#ExampleConfigurationWarnings];
    SET @Case+=1;
END;
DROP TABLE [#ExampleConfigurationNative];
GO
