USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ResourceGovernorAnalysis
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liest gespeicherte und aktive Resource-Governor-Konfiguration,
               Laufzeitkennzahlen und abgeleitete Memory-Grant-Grenzen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.resource_governor_configuration,
               sys.dm_resource_governor_configuration,
               sys.resource_governor_resource_pools,
               sys.resource_governor_workload_groups,
               sys.dm_resource_governor_resource_pools,
               sys.dm_resource_governor_workload_groups,
               sys.dm_exec_sessions.
Parameter    : @MitSessions, @MaxZeilen, @ResultSetArt, @JsonErzeugen,
               @Json OUTPUT, @PrintMeldungen, @Hilfe.
Resultsets   : RAW: Status, Konfiguration, Pools, Workload Groups, Sessions.
               CONSOLE: benannte und formatierte Projektionen. NONE: keine.
JSON         : Benannte Arrays configuration, resourcePools, workloadGroups,
               sessions und warnings.
Berechtigung : Nur lesender Zugriff. Das Framework vergibt keine Rechte und
               ändert keine Resource-Governor-Konfiguration.
Eigenlast    : Gering bis mittel.
Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
Änderungen   : 2.0.0 - Präziser RequestMaxMemoryGrantPercent ohne Datentyp im
                         Spaltennamen, Grant-Grenzen, RAW/CONSOLE/NONE und JSON.
               1.0.1 - gespeicherte und effektive Konfiguration getrennt.
               1.0.0 - Erstfassung Phase 6.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ResourceGovernorAnalysis]
      @MitSessions       bit            = 1
    , @MaxZeilen         int            = 5000
    , @ResultSetArt      varchar(16)    = 'CONSOLE'
    , @ResultTable                     sysname        = NULL
    , @JsonErzeugen      bit            = 0
    , @Json              nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen    bit            = 1
    , @Hilfe             bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    IF @TableResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen)
             ELSE CONVERT(bigint, 0) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_ResourceGovernorAnalysis';
        PRINT N'@MitSessions bit=1: aktuelle Benutzersessions je Workload Group.';
        PRINT N'@MaxZeilen int=5000: positive Werte begrenzen; NULL/0 = unbegrenzt.';
        PRINT N'@ResultSetArt=CONSOLE (Default)|RAW|TABLE|NONE; der Steuerwert ist case-insensitiv.';
        PRINT N'@JsonErzeugen=1 erzeugt @Json OUTPUT mit benannten Arrays.';
        PRINT N'RequestMaxMemoryGrantPercent wird als decimal(9,4) ausgegeben; der Datentyp ist kein Bestandteil des Spaltennamens.';
        PRINT N'Keine ALTER RESOURCE GOVERNOR- oder RECONFIGURE-Anweisung.';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;

    CREATE TABLE [#Cfg]
    (
          [ClassifierFunctionId]   int            NULL
        , [IsEnabled]              bit            NULL
        , [ReconfigurationPending] bit            NULL
        , [ClassifierFunctionName] nvarchar(517)  NULL
    );

    CREATE TABLE [#Pools]
    (
          [PoolId]                    int            NOT NULL
        , [PoolName]                  sysname        NOT NULL
        , [MinCpuPercent]             int            NULL
        , [MaxCpuPercent]             int            NULL
        , [MinMemoryPercent]          int            NULL
        , [MaxMemoryPercent]          int            NULL
        , [CapCpuPercent]             int            NULL
        , [MinIopsPerVolume]          int            NULL
        , [MaxIopsPerVolume]          int            NULL
        , [StatisticsStartTime]       datetime       NULL
        , [TotalCpuUsageMs]           bigint         NULL
        , [CacheMemoryMb]             decimal(19,2)  NULL
        , [UsedWorkspaceMemoryMb]     decimal(19,2)  NULL
        , [TargetWorkspaceMemoryMb]   decimal(19,2)  NULL
        , [MaxWorkspaceMemoryMb]      decimal(19,2)  NULL
        , [OutOfMemoryCount]          bigint         NULL
        , [ActiveMemgrantCount]       int            NULL
        , [PendingMemgrantCount]      int            NULL
        , [UsedOfTargetMemoryPercent] decimal(9,2)   NULL
        , [UsedOfMaxMemoryPercent]    decimal(9,2)   NULL
    );

    CREATE TABLE [#Groups]
    (
          [GroupId]                              int            NOT NULL
        , [GroupName]                            sysname        NOT NULL
        , [PoolId]                               int            NULL
        , [PoolName]                             sysname        NULL
        , [Importance]                           nvarchar(60)   NULL
        , [RequestMaxMemoryGrantPercent]         decimal(9,4)   NULL
        , [ConfiguredRequestMaxGrantMemoryMb]    decimal(19,2)  NULL
        , [TargetRequestMaxGrantMemoryMb]        decimal(19,2)  NULL
        , [HistoricalMaxRequestGrantMemoryMb]    decimal(19,2)  NULL
        , [RequestMaxCpuTimeSec]                 int            NULL
        , [RequestMemoryGrantTimeoutSec]         int            NULL
        , [MaxDop]                               int            NULL
        , [EffectiveMaxDop]                      int            NULL
        , [GroupMaxRequests]                     int            NULL
        , [TotalRequestCount]                    bigint         NULL
        , [TotalQueuedRequestCount]              bigint         NULL
        , [ActiveRequestCount]                   int            NULL
        , [QueuedRequestCount]                   int            NULL
        , [TotalReducedMemgrantCount]            bigint         NULL
        , [TotalCpuUsageMs]                      bigint         NULL
        , [TotalLockWaitCount]                   bigint         NULL
        , [TotalLockWaitTimeMs]                  bigint         NULL
    );

    CREATE TABLE [#Sessions]
    (
          [SessionId]        int            NOT NULL
        , [LoginName]        sysname        NULL
        , [HostName]         nvarchar(128)  NULL
        , [ProgramName]      nvarchar(128)  NULL
        , [GroupId]          int            NULL
        , [GroupName]        sysname        NULL
        , [PoolName]         sysname        NULL
        , [Status]           nvarchar(60)   NULL
        , [CpuTimeMs]        int            NULL
        , [MemoryUsagePages] int            NULL
        , [MemoryUsageMb]    decimal(19,2)  NULL
        , [Reads]            bigint         NULL
        , [Writes]           bigint         NULL
        , [LogicalReads]     bigint         NULL
    );

    CREATE TABLE [#Warnings]
    (
          [WarningCode]    varchar(40)     NOT NULL
        , [WarningMessage] nvarchar(2048)  NOT NULL
    );

    IF @MaxZeilen < 0
       OR @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültiger Parameter. @MaxZeilen darf nicht negativ sein; @ResultSetArt erlaubt CONSOLE (Default), RAW, TABLE oder NONE.';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#Cfg]
        (
              [ClassifierFunctionId], [IsEnabled]
            , [ReconfigurationPending], [ClassifierFunctionName]
        )
        SELECT
              [stored].[classifier_function_id]
            , [stored].[is_enabled]
            , [effective].[is_reconfiguration_pending]
            , CASE
                  WHEN [stored].[classifier_function_id] = 0 THEN NULL
                  WHEN [classifier_object].[object_id] IS NULL THEN N'<nicht sichtbar>'
                  ELSE QUOTENAME([classifier_schema].[name])
                       + N'.' + QUOTENAME([classifier_object].[name])
              END
        FROM [sys].[resource_governor_configuration] AS [stored]
        CROSS JOIN [sys].[dm_resource_governor_configuration] AS [effective]
        LEFT JOIN [master].[sys].[objects] AS [classifier_object] WITH (NOLOCK)
          ON [classifier_object].[object_id] = [stored].[classifier_function_id]
        LEFT JOIN [master].[sys].[schemas] AS [classifier_schema] WITH (NOLOCK)
          ON [classifier_schema].[schema_id] = [classifier_object].[schema_id];

        INSERT [#Pools]
        (
              [PoolId], [PoolName], [MinCpuPercent], [MaxCpuPercent]
            , [MinMemoryPercent], [MaxMemoryPercent], [CapCpuPercent]
            , [MinIopsPerVolume], [MaxIopsPerVolume], [StatisticsStartTime]
            , [TotalCpuUsageMs], [CacheMemoryMb], [UsedWorkspaceMemoryMb]
            , [TargetWorkspaceMemoryMb], [MaxWorkspaceMemoryMb]
            , [OutOfMemoryCount], [ActiveMemgrantCount], [PendingMemgrantCount]
            , [UsedOfTargetMemoryPercent], [UsedOfMaxMemoryPercent]
        )
        SELECT TOP (@EffectiveMaxZeilen)
              [p].[pool_id]
            , [p].[name]
            , [p].[min_cpu_percent]
            , [p].[max_cpu_percent]
            , [p].[min_memory_percent]
            , [p].[max_memory_percent]
            , [p].[cap_cpu_percent]
            , [p].[min_iops_per_volume]
            , [p].[max_iops_per_volume]
            , [d].[statistics_start_time]
            , [d].[total_cpu_usage_ms]
            , CONVERT(decimal(19,2), [d].[cache_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [d].[used_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [d].[target_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [d].[max_memory_kb] / 1024.0)
            , [d].[out_of_memory_count]
            , [d].[active_memgrant_count]
            , [d].[memgrant_waiter_count]
            , CONVERT(decimal(9,2), 100.0 * [d].[used_memory_kb] / NULLIF([d].[target_memory_kb], 0))
            , CONVERT(decimal(9,2), 100.0 * [d].[used_memory_kb] / NULLIF([d].[max_memory_kb], 0))
        FROM [sys].[resource_governor_resource_pools] AS [p]
        LEFT JOIN [sys].[dm_resource_governor_resource_pools] AS [d]
          ON [d].[pool_id] = [p].[pool_id]
        ORDER BY [p].[pool_id];

        INSERT [#Groups]
        (
              [GroupId], [GroupName], [PoolId], [PoolName], [Importance]
            , [RequestMaxMemoryGrantPercent]
            , [ConfiguredRequestMaxGrantMemoryMb]
            , [TargetRequestMaxGrantMemoryMb]
            , [HistoricalMaxRequestGrantMemoryMb]
            , [RequestMaxCpuTimeSec], [RequestMemoryGrantTimeoutSec]
            , [MaxDop], [EffectiveMaxDop], [GroupMaxRequests]
            , [TotalRequestCount], [TotalQueuedRequestCount]
            , [ActiveRequestCount], [QueuedRequestCount]
            , [TotalReducedMemgrantCount], [TotalCpuUsageMs]
            , [TotalLockWaitCount], [TotalLockWaitTimeMs]
        )
        SELECT TOP (@EffectiveMaxZeilen)
              [g].[group_id]
            , [g].[name]
            , [g].[pool_id]
            , [p].[name]
            , [g].[importance]
            , CONVERT(decimal(9,4), [g].[request_max_memory_grant_percent_numeric])
            , CONVERT
              (
                  decimal(19,2),
                  CONVERT(decimal(38,4), [dp].[max_memory_kb])
                  * CONVERT(decimal(38,4), [g].[request_max_memory_grant_percent_numeric])
                  / 100.0 / 1024.0
              )
            , CONVERT
              (
                  decimal(19,2),
                  CONVERT(decimal(38,4), [dp].[target_memory_kb])
                  * CONVERT(decimal(38,4), [g].[request_max_memory_grant_percent_numeric])
                  / 100.0 / 1024.0
              )
            , CONVERT(decimal(19,2), [dg].[max_request_grant_memory_kb] / 1024.0)
            , [g].[request_max_cpu_time_sec]
            , [g].[request_memory_grant_timeout_sec]
            , [g].[max_dop]
            , [dg].[effective_max_dop]
            , [g].[group_max_requests]
            , [dg].[total_request_count]
            , [dg].[total_queued_request_count]
            , [dg].[active_request_count]
            , [dg].[queued_request_count]
            , [dg].[total_reduced_memgrant_count]
            , [dg].[total_cpu_usage_ms]
            , [dg].[total_lock_wait_count]
            , [dg].[total_lock_wait_time_ms]
        FROM [sys].[resource_governor_workload_groups] AS [g]
        LEFT JOIN [sys].[resource_governor_resource_pools] AS [p]
          ON [p].[pool_id] = [g].[pool_id]
        LEFT JOIN [sys].[dm_resource_governor_workload_groups] AS [dg]
          ON [dg].[group_id] = [g].[group_id]
        LEFT JOIN [sys].[dm_resource_governor_resource_pools] AS [dp]
          ON [dp].[pool_id] = [g].[pool_id]
        ORDER BY [g].[group_id];

        IF @MitSessions = 1
        BEGIN
            INSERT [#Sessions]
            (
                  [SessionId], [LoginName], [HostName], [ProgramName]
                , [GroupId], [GroupName], [PoolName], [Status]
                , [CpuTimeMs], [MemoryUsagePages], [MemoryUsageMb]
                , [Reads], [Writes], [LogicalReads]
            )
            SELECT TOP (@EffectiveMaxZeilen)
                  [s].[session_id]
                , [s].[login_name]
                , [s].[host_name]
                , [s].[program_name]
                , [s].[group_id]
                , [g].[name]
                , [p].[name]
                , [s].[status]
                , [s].[cpu_time]
                , [s].[memory_usage]
                , CONVERT(decimal(19,2), [s].[memory_usage] * 8.0 / 1024.0)
                , [s].[reads]
                , [s].[writes]
                , [s].[logical_reads]
            FROM [sys].[dm_exec_sessions] AS [s]
            LEFT JOIN [sys].[dm_resource_governor_workload_groups] AS [g]
              ON [g].[group_id] = [s].[group_id]
            LEFT JOIN [sys].[dm_resource_governor_resource_pools] AS [p]
              ON [p].[pool_id] = [g].[pool_id]
            WHERE [s].[is_user_process] = 1
            ORDER BY [s].[cpu_time] DESC, [s].[session_id];
        END;
    END TRY
    BEGIN CATCH
        SET @StatusCode = CASE WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371)
                               THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END;
        SET @IsPartial = 1;
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        INSERT [#Warnings] VALUES(@StatusCode, @ErrorMessage);

        IF @PrintMeldungen = 1
        BEGIN
            DECLARE @PrintMessage nvarchar(2048) = FORMATMESSAGE
            (
                N'Resource Governor konnte nicht vollständig gelesen werden: %s',
                @ErrorMessage
            );
            RAISERROR(N'%s', 10, 1, @PrintMessage) WITH NOWAIT;
        END;
    END CATCH;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'ResourceGovernorAnalysis' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @MaxZeilen AS [requestedMaxRowsPerArray]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @CfgJson nvarchar(max) =
            (SELECT * FROM [#Cfg] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @PoolsJson nvarchar(max) =
            (SELECT * FROM [#Pools] ORDER BY [PoolId] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @GroupsJson nvarchar(max) =
            (SELECT * FROM [#Groups] ORDER BY [GroupId] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @SessionsJson nvarchar(max) =
            (SELECT * FROM [#Sessions] ORDER BY [CpuTimeMs] DESC, [SessionId] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max) =
            (SELECT [WarningCode] AS [code], [WarningMessage] AS [message]
             FROM [#Warnings] FOR JSON PATH, INCLUDE_NULL_VALUES);

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"configuration":', COALESCE(@CfgJson, N'[]')
            , N',"resourcePools":', COALESCE(@PoolsJson, N'[]')
            , N',"workloadGroups":', COALESCE(@GroupsJson, N'[]')
            , N',"sessions":', COALESCE(@SessionsJson, N'[]')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]')
            , N'}'
        );
    END;

    IF @ResultSetArtNormalisiert = 'RAW'
    BEGIN
        SELECT
              @CollectionTimeUtc AS [CollectionTimeUtc]
            , CAST(N'monitor.USP_ResourceGovernorAnalysis' AS nvarchar(256)) AS [ModuleName]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];
        SELECT * FROM [#Cfg];
        SELECT * FROM [#Pools] ORDER BY [PoolId];
        SELECT * FROM [#Groups] ORDER BY [GroupId];
        SELECT * FROM [#Sessions] ORDER BY [CpuTimeMs] DESC, [SessionId];
    END
    ELSE IF @ResultSetArtNormalisiert = 'CONSOLE'
    BEGIN
        SELECT
              N'Resource Governor' AS [Ergebnis]
            , @CollectionTimeUtc AS [Stand_UTC]
            , @StatusCode AS [Status]
            , @IsPartial AS [Teilresultat]
            , @ErrorMessage AS [Fehler];

        SELECT
              N'Resource-Governor-Konfiguration' AS [Ergebnis]
            , [ClassifierFunctionName] AS [Classifier_Function]
            , [IsEnabled] AS [Aktiv]
            , [ReconfigurationPending] AS [Reconfiguration_ausständig]
        FROM [#Cfg];

        SELECT
              N'Resource Pool' AS [Ergebnis]
            , [PoolId] AS [Pool_ID]
            , [PoolName] AS [Pool]
            , CONCAT([MinCpuPercent], N' %') AS [Min_CPU]
            , CONCAT([MaxCpuPercent], N' %') AS [Max_CPU]
            , CONCAT([MinMemoryPercent], N' %') AS [Min_Memory]
            , CONCAT([MaxMemoryPercent], N' %') AS [Max_Memory]
            , CONCAT(CONVERT(varchar(40), [UsedWorkspaceMemoryMb]), N' MB') AS [Workspace_verwendet]
            , CONCAT(CONVERT(varchar(40), [TargetWorkspaceMemoryMb]), N' MB') AS [Workspace_Target]
            , CONCAT(CONVERT(varchar(40), [MaxWorkspaceMemoryMb]), N' MB') AS [Workspace_Maximum]
            , CONCAT(CONVERT(varchar(40), [UsedOfTargetMemoryPercent]), N' %') AS [Verwendet_vom_Target]
            , [PendingMemgrantCount] AS [Wartende_Memory_Grants]
            , [OutOfMemoryCount] AS [Out_of_Memory]
        FROM [#Pools]
        ORDER BY [PoolId];

        SELECT
              N'Workload Group' AS [Ergebnis]
            , [GroupId] AS [Group_ID]
            , [GroupName] AS [Workload_Group]
            , [PoolName] AS [Resource_Pool]
            , [Importance] AS [Importance]
            , CONCAT(CONVERT(varchar(40), [RequestMaxMemoryGrantPercent]), N' %') AS [Max_Request_Grant]
            , CONCAT(CONVERT(varchar(40), [ConfiguredRequestMaxGrantMemoryMb]), N' MB') AS [Konfiguriertes_Request_Maximum]
            , CONCAT(CONVERT(varchar(40), [TargetRequestMaxGrantMemoryMb]), N' MB') AS [Aktuelles_Target_Request_Maximum]
            , CONCAT(CONVERT(varchar(40), [HistoricalMaxRequestGrantMemoryMb]), N' MB') AS [Historisch_größter_Grant]
            , [ActiveRequestCount] AS [Aktive_Requests]
            , [QueuedRequestCount] AS [Wartende_Requests]
            , [TotalReducedMemgrantCount] AS [Reduzierte_Memory_Grants]
        FROM [#Groups]
        ORDER BY [GroupId];

        IF @MitSessions = 1
        BEGIN
            SELECT
                  N'Resource-Governor-Session' AS [Ergebnis]
                , [SessionId] AS [Session]
                , [LoginName] AS [Login]
                , [HostName] AS [Host]
                , [ProgramName] AS [Programm]
                , [GroupName] AS [Workload_Group]
                , [PoolName] AS [Resource_Pool]
                , [Status] AS [Status]
                , CONCAT(CONVERT(varchar(40), [MemoryUsageMb]), N' MB') AS [Session_Memory]
                , [CpuTimeMs] AS [CPU_ms]
                , [LogicalReads] AS [Logical_Reads]
            FROM [#Sessions]
            ORDER BY [CpuTimeMs] DESC, [SessionId];
        END;
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#Cfg'
            , @ResultTable = @ResultTable
            , @ThrowOnError = 1;
    END;
END;
GO
