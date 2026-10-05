USE [DeineDatenbank];
GO
SET NOCOUNT ON;
-- Dieser Vertrag verwendet ausschließlich einen neuen eigenen lokalen Testcontainer.
-- Er liest die vorhandenen Pools und Gruppen; Konfiguration und Statistikreset bleiben unverändert.
DECLARE @Json nvarchar(max),@Case tinyint=0,@Limit int,@Sessions bit,@ExpectedLimit bigint,
        @OriginalLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @Exports TABLE([Name] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY,[TextColumns] int NOT NULL);
INSERT @Exports VALUES(N'#ExampleGovernorCfg',1),(N'#ExampleGovernorPools',1),(N'#ExampleGovernorGroups',3),
                      (N'#ExampleGovernorSessions',6),(N'#ExampleGovernorTempdb',5);
DECLARE @Parity TABLE([ExpectedJson] nvarchar(max),[ActualJson] nvarchar(max));
SELECT [stored].[classifier_function_id] AS [ClassifierFunctionId],[stored].[is_enabled] AS [IsEnabled],
       CONVERT(bit,[effective].[is_reconfiguration_pending]) AS [ReconfigurationPending],
       CONVERT(nvarchar(517),CASE WHEN [stored].[classifier_function_id]=0 THEN NULL
          WHEN [o].[object_id] IS NULL THEN N'<nicht sichtbar>' ELSE QUOTENAME([s].[name])+N'.'+QUOTENAME([o].[name]) END)
          COLLATE SQL_Latin1_General_CP1_CS_AS AS [ClassifierFunctionName]
INTO [#ExampleGovernorNativeCfg]
FROM [sys].[resource_governor_configuration] AS [stored]
CROSS JOIN [sys].[dm_resource_governor_configuration] AS [effective]
LEFT JOIN [master].[sys].[objects] AS [o] ON [o].[object_id]=[stored].[classifier_function_id]
LEFT JOIN [master].[sys].[schemas] AS [s] ON [s].[schema_id]=[o].[schema_id];
SELECT [pool_id] AS [PoolId],[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [PoolName],
       [min_cpu_percent] AS [MinCpuPercent],[max_cpu_percent] AS [MaxCpuPercent],
       [min_memory_percent] AS [MinMemoryPercent],[max_memory_percent] AS [MaxMemoryPercent],
       [cap_cpu_percent] AS [CapCpuPercent],[min_iops_per_volume] AS [MinIopsPerVolume],[max_iops_per_volume] AS [MaxIopsPerVolume]
INTO [#ExampleGovernorNativePools] FROM [sys].[resource_governor_resource_pools];
SELECT [g].[group_id] AS [GroupId],[g].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [GroupName],
       [g].[pool_id] AS [PoolId],[p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [PoolName],
       [g].[importance] COLLATE SQL_Latin1_General_CP1_CS_AS AS [Importance],
       CONVERT(decimal(9,4),[g].[request_max_memory_grant_percent_numeric]) AS [RequestMaxMemoryGrantPercent],
       [g].[request_max_cpu_time_sec] AS [RequestMaxCpuTimeSec],[g].[request_memory_grant_timeout_sec] AS [RequestMemoryGrantTimeoutSec],
       [g].[max_dop] AS [MaxDop],[g].[group_max_requests] AS [GroupMaxRequests],
       CONVERT(decimal(19,2),[g].[group_max_tempdb_data_mb]) AS [ConfiguredGroupMaxTempdbDataMb],
       CONVERT(decimal(9,4),[g].[group_max_tempdb_data_percent]) AS [ConfiguredGroupMaxTempdbDataPercent]
INTO [#ExampleGovernorNativeGroups] FROM [sys].[resource_governor_workload_groups] AS [g]
LEFT JOIN [sys].[resource_governor_resource_pools] AS [p] ON [p].[pool_id]=[g].[pool_id];
IF (SELECT COUNT_BIG(*) FROM [#ExampleGovernorNativeCfg])<>1
   OR (SELECT COUNT_BIG(*) FROM [#ExampleGovernorNativePools])<2
   OR (SELECT COUNT_BIG(*) FROM [#ExampleGovernorNativeGroups])<2
   OR EXISTS(SELECT 1 FROM [#ExampleGovernorNativeGroups]
             WHERE [ConfiguredGroupMaxTempdbDataMb] IS NOT NULL OR [ConfiguredGroupMaxTempdbDataPercent] IS NOT NULL)
    THROW 55940,N'Der frische native Resource-Governor-Inventarfall ist nicht vorhanden.',1;
WHILE @Case<4
BEGIN
    SELECT @Limit=CASE @Case WHEN 1 THEN 1 WHEN 2 THEN NULL ELSE 0 END,
           @Sessions=CASE WHEN @Case=3 THEN 0 ELSE 1 END,@Json=NULL;
    SET @ExpectedLimit=CASE WHEN @Limit=1 THEN 1 ELSE CONVERT(bigint,9223372036854775807) END;
    CREATE TABLE [#ExampleGovernorCfg]([Dummy] int NULL);
    CREATE TABLE [#ExampleGovernorPools]([Dummy] int NULL);
    CREATE TABLE [#ExampleGovernorGroups]([Dummy] int NULL);
    CREATE TABLE [#ExampleGovernorSessions]([Dummy] int NULL);
    CREATE TABLE [#ExampleGovernorTempdb]([Dummy] int NULL);
    EXEC [monitor].[USP_ResourceGovernorAnalysis] @MitSessions=@Sessions,@MaxZeilen=@Limit,@ResultSetArt='TABLE',
       @ResultTablesJson=N'{"configuration":"#ExampleGovernorCfg","resourcePools":"#ExampleGovernorPools","workloadGroups":"#ExampleGovernorGroups","sessions":"#ExampleGovernorSessions","tempdbGovernance":"#ExampleGovernorTempdb"}',
       @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF EXISTS(SELECT 1 FROM @Exports AS [e]
       WHERE (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
              WHERE [object_id]=OBJECT_ID(N'tempdb..'+[e].[Name]) AND [collation_name] IS NOT NULL)<>[e].[TextColumns]
          OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
              WHERE [object_id]=OBJECT_ID(N'tempdb..'+[e].[Name]) AND [collation_name] IS NOT NULL
                AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS'))
        THROW 55941,N'Der Resource-Governor-TABLE-Export übernimmt eine fremde tempdb-Collation.',1;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.productMajorVersion'),N'')<>N'17'
       OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]' OR @@LOCK_TIMEOUT<>@OriginalLockTimeout
       OR (SELECT COUNT_BIG(*) FROM [#ExampleGovernorCfg])<>1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleGovernorPools])<>CASE WHEN @Limit=1 THEN 1 ELSE (SELECT COUNT_BIG(*) FROM [#ExampleGovernorNativePools]) END
       OR (SELECT COUNT_BIG(*) FROM [#ExampleGovernorGroups])<>CASE WHEN @Limit=1 THEN 1 ELSE (SELECT COUNT_BIG(*) FROM [#ExampleGovernorNativeGroups]) END
       OR (SELECT COUNT_BIG(*) FROM [#ExampleGovernorTempdb])<>(SELECT COUNT_BIG(*) FROM [#ExampleGovernorGroups])
       OR (SELECT COUNT_BIG(*) FROM [#ExampleGovernorSessions])>@ExpectedLimit
       OR (@Sessions=0 AND EXISTS(SELECT 1 FROM [#ExampleGovernorSessions]))
       OR (@Sessions=1 AND @Limit=1 AND (SELECT COUNT_BIG(*) FROM [#ExampleGovernorSessions])<>1)
       OR (@Sessions=1 AND @Limit<>1 AND NOT EXISTS(SELECT 1 FROM [#ExampleGovernorSessions] WHERE [SessionId]=@@SPID))
       OR (@Sessions=1 AND @Limit IS NULL AND NOT EXISTS(SELECT 1 FROM [#ExampleGovernorSessions] WHERE [SessionId]=@@SPID))
        THROW 55942,N'Der Resource-Governor-Status-, Limit- oder Sessionvertrag ist verletzt.',1;
    INSERT @Parity VALUES
      ((SELECT * FROM [#ExampleGovernorNativeCfg] FOR JSON PATH,INCLUDE_NULL_VALUES),
       (SELECT * FROM [#ExampleGovernorCfg] FOR JSON PATH,INCLUDE_NULL_VALUES)),
      ((SELECT TOP(@ExpectedLimit) * FROM [#ExampleGovernorNativePools] ORDER BY [PoolId] FOR JSON PATH,INCLUDE_NULL_VALUES),
       (SELECT [PoolId],[PoolName],[MinCpuPercent],[MaxCpuPercent],[MinMemoryPercent],[MaxMemoryPercent],
               [CapCpuPercent],[MinIopsPerVolume],[MaxIopsPerVolume] FROM [#ExampleGovernorPools] FOR JSON PATH,INCLUDE_NULL_VALUES)),
      ((SELECT TOP(@ExpectedLimit) [GroupId],[GroupName],[PoolId],[PoolName],[Importance],[RequestMaxMemoryGrantPercent],
               [RequestMaxCpuTimeSec],[RequestMemoryGrantTimeoutSec],[MaxDop],[GroupMaxRequests]
        FROM [#ExampleGovernorNativeGroups] ORDER BY [GroupId] FOR JSON PATH,INCLUDE_NULL_VALUES),
       (SELECT [GroupId],[GroupName],[PoolId],[PoolName],[Importance],[RequestMaxMemoryGrantPercent],
               [RequestMaxCpuTimeSec],[RequestMemoryGrantTimeoutSec],[MaxDop],[GroupMaxRequests]
        FROM [#ExampleGovernorGroups] FOR JSON PATH,INCLUDE_NULL_VALUES)),
      ((SELECT TOP(@ExpectedLimit) [GroupId],[GroupName],[PoolId],[PoolName],
               [ConfiguredGroupMaxTempdbDataMb],[ConfiguredGroupMaxTempdbDataPercent]
        FROM [#ExampleGovernorNativeGroups] ORDER BY [GroupId] FOR JSON PATH,INCLUDE_NULL_VALUES),
       (SELECT [GroupId],[GroupName],[PoolId],[PoolName],[ConfiguredGroupMaxTempdbDataMb],[ConfiguredGroupMaxTempdbDataPercent]
        FROM [#ExampleGovernorTempdb] FOR JSON PATH,INCLUDE_NULL_VALUES));
    IF EXISTS(SELECT 1 FROM [#ExampleGovernorSessions] AS [s]
       LEFT JOIN [#ExampleGovernorNativeGroups] AS [g] ON [g].[GroupId]=[s].[GroupId]
       WHERE [g].[GroupId] IS NULL OR [s].[GroupName] IS NULL OR [s].[PoolName] IS NULL
          OR [s].[GroupName]<>[g].[GroupName] OR [s].[PoolName]<>[g].[PoolName]
          OR [s].[MemoryUsagePages] IS NULL OR [s].[MemoryUsagePages]<0 OR [s].[MemoryUsageMb] IS NULL
          OR [s].[MemoryUsageMb]<>CONVERT(decimal(19,2),[s].[MemoryUsagePages]*8.0/1024.0)
          OR [s].[CpuTimeMs] IS NULL OR [s].[CpuTimeMs]<0)
       OR EXISTS(SELECT 1 FROM [#ExampleGovernorTempdb]
          WHERE COALESCE([SourceStatusCode],'')<>'AVAILABLE' OR COALESCE([IsPartial],1)<>0
             OR COALESCE([EffectiveLimitSource],'')<>'NO_LIMIT_CONFIGURED'
             OR [EffectiveGroupMaxTempdbDataMb] IS NOT NULL OR [TempdbMaximumSizeMb] IS NOT NULL
             OR [EffectiveLimitUtilizationPercent] IS NOT NULL OR [IsPercentLimitEffective] IS NOT NULL
             OR [TempdbDataSpaceMb] IS NULL OR [TempdbDataSpaceMb]<0
             OR [PeakTempdbDataSpaceMb] IS NULL OR [PeakTempdbDataSpaceMb]<[TempdbDataSpaceMb]
             OR [TotalTempdbDataLimitViolationCount] IS NULL OR [TotalTempdbDataLimitViolationCount]<0
             OR [HasRecordedLimitViolation] IS NULL OR [HasRecordedLimitViolation]<>CASE WHEN [TotalTempdbDataLimitViolationCount]>0 THEN 1 ELSE 0 END)
        THROW 55943,N'Die native Sessionzuordnung oder TempDB-Governance ohne Limit ist verletzt.',1;
    INSERT @Parity VALUES
      ((SELECT * FROM [#ExampleGovernorCfg] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.configuration')),
      ((SELECT * FROM [#ExampleGovernorPools] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.resourcePools')),
      ((SELECT * FROM [#ExampleGovernorGroups] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.workloadGroups')),
      (COALESCE((SELECT * FROM [#ExampleGovernorSessions] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'),JSON_QUERY(@Json,N'$.sessions')),
      ((SELECT * FROM [#ExampleGovernorTempdb] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.tempdbGovernance'));
    DROP TABLE [#ExampleGovernorCfg]; DROP TABLE [#ExampleGovernorPools]; DROP TABLE [#ExampleGovernorGroups];
    DROP TABLE [#ExampleGovernorSessions]; DROP TABLE [#ExampleGovernorTempdb];
    SET @Case+=1;
END;
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
    THROW 55944,N'Der native Resource-Governor- oder TABLE-/JSON-Multimengenvertrag ist verletzt.',1;
DROP TABLE [#ExampleGovernorNativeCfg]; DROP TABLE [#ExampleGovernorNativePools]; DROP TABLE [#ExampleGovernorNativeGroups];
GO
