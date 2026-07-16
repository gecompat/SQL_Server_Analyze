USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentMemoryGrants
Version      : 2.0.1
Stand        : 2026-07-16
Typ          : Stored Procedure
Zweck        : Liefert aktuell wartende und gewährte Query Memory Grants sowie
               Resource-Governor-, Pool- und Semaphore-Grenzen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_exec_query_memory_grants, sys.dm_exec_sessions,
               sys.dm_exec_requests, sys.dm_exec_sql_text, sys.databases,
               sys.dm_resource_governor_workload_groups,
               sys.dm_resource_governor_resource_pools,
               sys.dm_exec_query_resource_semaphores.
Parameter    : @SessionIds, @AktuelleSessionEinbeziehen, @NurWartende,
               @MinRequestedMb, @MinGrantedMb, @MitSqlText,
               @MaxSqlTextZeichen, @MaxZeilen, @ResultSetArt,
               @JsonErzeugen, @Json OUTPUT, @PrintMeldungen, @Hilfe.
Ausgabe      : RAW = stabile technische Resultsets; CONSOLE = formatierte,
               menschenlesbare Darstellung; NONE = keine Resultsets.
               @JsonErzeugen=1 erzeugt unabhängig davon ein JSON-Envelope.
Berechtigung : VIEW SERVER STATE (2019) bzw. VIEW SERVER PERFORMANCE STATE.
Eigenlast    : Gering; die DMV enthält nur aktuelle Grants/Anforderungen.
Locking      : Keine Benutzerobjekte.
Partial      : Fehlender SQL-Text oder nicht auflösbare Zusatzmetadaten bleiben
               NULL; Fehler werden strukturiert ausgegeben.
Beispiele    : EXEC monitor.USP_CurrentMemoryGrants;
               EXEC monitor.USP_CurrentMemoryGrants
                    @NurWartende=1,@ResultSetArt='console';
               DECLARE @J nvarchar(max);
               EXEC monitor.USP_CurrentMemoryGrants
                    @ResultSetArt='none',@JsonErzeugen=1,@Json=@J OUTPUT;
               SELECT @J AS [Json];
Änderungen   : 2.0.0 - Resource-Governor-Grenzen und Prozentkennzahlen ergänzt;
                         RAW/CONSOLE/NONE sowie JSON-Envelope eingeführt.
               1.0.0 - Erstfassung Phase 1B.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentMemoryGrants]
      @SessionIds                   nvarchar(max)  = NULL
    , @AktuelleSessionEinbeziehen   bit            = 0
    , @NurWartende                  bit            = 0
    , @MinRequestedMb               decimal(19,2)  = NULL
    , @MinGrantedMb                 decimal(19,2)  = NULL
    , @MitSqlText                   bit            = 1
    , @MaxSqlTextZeichen            int            = 3000
    , @MaxZeilen                    int            = 1000
    , @ResultSetArt                 varchar(16)    = 'CONSOLE'
    , @JsonErzeugen                 bit            = 0
    , @Json                         nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen               bit            = 1
    , @Hilfe                        bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @EffectiveMaxZeilen bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen)
             ELSE CONVERT(bigint, 0) END;
    DECLARE @CandidateMaxZeilen bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             WHEN @MaxZeilen > 0 AND @MaxZeilen < 2147483647
             THEN CONVERT(bigint, @MaxZeilen) + 1
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen)
             ELSE CONVERT(bigint, 0) END;
    DECLARE @MonitorPrintMessage nvarchar(2048);

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentMemoryGrants';
        PRINT N'Zweck: aktuelle wartende und gewährte Query Memory Grants einschließlich Resource-Governor-Grenzen.';
        PRINT N'@SessionIds=NULL (Pipe-Liste); @AktuelleSessionEinbeziehen=0; @NurWartende=0; @MinRequestedMb/@MinGrantedMb=NULL.';
        PRINT N'@MitSqlText=1; @MaxSqlTextZeichen positiv begrenzt, NULL/0 liefert vollständigen Text; @MaxZeilen positiv begrenzt, NULL/0 unbegrenzt.';
        PRINT N'@ResultSetArt=CONSOLE (Default)|RAW|NONE; Steuerwert wird case-insensitiv verarbeitet.';
        PRINT N'@JsonErzeugen=1 setzt @Json OUTPUT auf ein Envelope mit meta, memoryGrants und warnings.';
        PRINT N'RequestMaxMemoryGrantPercent ist decimal(9,4); der Datentyp ist nicht Bestandteil des Spaltennamens.';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @CandidateRowCount bigint = 0;
    DECLARE @RowCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;
    DECLARE @RequiredPermission nvarchar(256) =
        CASE WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16
             THEN N'VIEW SERVER PERFORMANCE STATE'
             ELSE N'VIEW SERVER STATE' END;

    CREATE TABLE [#SessionIdFilter]
    (
        [SessionId] smallint NOT NULL PRIMARY KEY
    );

    IF @SessionIds IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            WHERE [IsValid] = 0 OR [NumberValue] NOT BETWEEN 1 AND 32767
        )
        BEGIN
            SET @StatusCode = 'INVALID_PARAMETER';
            SET @ErrorMessage = N'@SessionIds enthält einen ungültigen Session-Identifier.';
        END
        ELSE
            INSERT [#SessionIdFilter]([SessionId])
            SELECT CONVERT(smallint,[NumberValue])
            FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            GROUP BY [NumberValue];
    END;

    CREATE TABLE [#Result]
    (
          [SessionId]                              smallint       NULL
        , [RequestId]                              int            NULL
        , [SchedulerId]                            int            NULL
        , [Dop]                                    smallint       NULL
        , [RequestTime]                            datetime       NULL
        , [GrantTime]                              datetime       NULL
        , [WaitTimeMs]                             bigint         NULL
        , [IsWaiting]                              bit            NOT NULL
        , [IsSmall]                                bit            NULL
        , [RequestedMemoryMb]                      decimal(19,2)  NULL
        , [RequiredMemoryMb]                       decimal(19,2)  NULL
        , [GrantedMemoryMb]                        decimal(19,2)  NULL
        , [UsedMemoryMb]                           decimal(19,2)  NULL
        , [MaxUsedMemoryMb]                        decimal(19,2)  NULL
        , [IdealMemoryMb]                          decimal(19,2)  NULL
        , [GroupId]                                int            NULL
        , [WorkloadGroupName]                      sysname        NULL
        , [PoolId]                                 int            NULL
        , [PoolName]                               sysname        NULL
        , [ResourceSemaphoreId]                    smallint       NULL
        , [RequestMaxMemoryGrantPercent]           decimal(9,4)   NULL
        , [PoolMaxWorkspaceMemoryMb]               decimal(19,2)  NULL
        , [PoolTargetWorkspaceMemoryMb]            decimal(19,2)  NULL
        , [PoolUsedWorkspaceMemoryMb]              decimal(19,2)  NULL
        , [ConfiguredRequestMaxGrantMemoryMb]      decimal(19,2)  NULL
        , [TargetRequestMaxGrantMemoryMb]          decimal(19,2)  NULL
        , [HistoricalMaxRequestGrantMemoryMb]      decimal(19,2)  NULL
        , [RequestedOfRequestMaxPercent]        decimal(9,2)   NULL
        , [GrantedOfRequestMaxPercent]          decimal(9,2)   NULL
        , [UsedOfRequestMaxPercent]             decimal(9,2)   NULL
        , [MaxUsedOfRequestMaxPercent]          decimal(9,2)   NULL
        , [IdealOfRequestMaxPercent]            decimal(9,2)   NULL
        , [RequestedOfTargetMaxPercent]            decimal(9,2)   NULL
        , [GrantedOfTargetMaxPercent]              decimal(9,2)   NULL
        , [UsedOfGrantedPercent]                   decimal(9,2)   NULL
        , [MaxUsedOfGrantedPercent]                decimal(9,2)   NULL
        , [SemaphoreTargetMemoryMb]                decimal(19,2)  NULL
        , [SemaphoreMaxTargetMemoryMb]             decimal(19,2)  NULL
        , [SemaphoreTotalMemoryMb]                 decimal(19,2)  NULL
        , [SemaphoreAvailableMemoryMb]             decimal(19,2)  NULL
        , [SemaphoreGrantedMemoryMb]               decimal(19,2)  NULL
        , [SemaphoreUsedMemoryMb]                  decimal(19,2)  NULL
        , [SemaphoreGranteeCount]                  int            NULL
        , [SemaphoreWaiterCount]                   int            NULL
        , [ReservedWorkerCount]                    bigint         NULL
        , [UsedWorkerCount]                        bigint         NULL
        , [MaxUsedWorkerCount]                     bigint         NULL
        , [QueueId]                                smallint       NULL
        , [WaitOrder]                              int            NULL
        , [LoginName]                              nvarchar(128)  NULL
        , [HostName]                               nvarchar(128)  NULL
        , [ProgramName]                            nvarchar(128)  NULL
        , [DatabaseId]                             smallint       NULL
        , [DatabaseName]                           sysname        NULL
        , [RequestStatus]                          nvarchar(30)   NULL
        , [Command]                                nvarchar(32)   NULL
        , [ElapsedMs]                              int            NULL
        , [CpuMs]                                  int            NULL
        , [LogicalReads]                           bigint         NULL
        , [CurrentStatement]                       nvarchar(max)  NULL
    );

    CREATE TABLE [#Warnings]
    (
          [WarningCode]    varchar(40)     NOT NULL
        , [WarningMessage] nvarchar(2048)  NOT NULL
    );

    IF @StatusCode = 'AVAILABLE'
       AND (COALESCE(@MinRequestedMb, 0) < 0
       OR COALESCE(@MinGrantedMb, 0) < 0
       OR @MaxZeilen < 0
       OR @MaxSqlTextZeichen < 0
       OR @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE'))
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültiger Parameterwert. @ResultSetArt erlaubt CONSOLE (Default), RAW oder NONE; die Schreibweise ist case-insensitiv.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#Result]
        (
              [SessionId], [RequestId], [SchedulerId], [Dop], [RequestTime], [GrantTime]
            , [WaitTimeMs], [IsWaiting], [IsSmall], [RequestedMemoryMb], [RequiredMemoryMb]
            , [GrantedMemoryMb], [UsedMemoryMb], [MaxUsedMemoryMb], [IdealMemoryMb]
            , [GroupId], [WorkloadGroupName], [PoolId], [PoolName], [ResourceSemaphoreId]
            , [RequestMaxMemoryGrantPercent], [PoolMaxWorkspaceMemoryMb]
            , [PoolTargetWorkspaceMemoryMb], [PoolUsedWorkspaceMemoryMb]
            , [ConfiguredRequestMaxGrantMemoryMb], [TargetRequestMaxGrantMemoryMb]
            , [HistoricalMaxRequestGrantMemoryMb], [RequestedOfRequestMaxPercent]
            , [GrantedOfRequestMaxPercent], [UsedOfRequestMaxPercent]
            , [MaxUsedOfRequestMaxPercent], [IdealOfRequestMaxPercent]
            , [RequestedOfTargetMaxPercent], [GrantedOfTargetMaxPercent]
            , [UsedOfGrantedPercent], [MaxUsedOfGrantedPercent]
            , [SemaphoreTargetMemoryMb], [SemaphoreMaxTargetMemoryMb]
            , [SemaphoreTotalMemoryMb], [SemaphoreAvailableMemoryMb]
            , [SemaphoreGrantedMemoryMb], [SemaphoreUsedMemoryMb]
            , [SemaphoreGranteeCount], [SemaphoreWaiterCount]
            , [ReservedWorkerCount], [UsedWorkerCount], [MaxUsedWorkerCount]
            , [QueueId], [WaitOrder], [LoginName], [HostName], [ProgramName]
            , [DatabaseId], [DatabaseName], [RequestStatus], [Command]
            , [ElapsedMs], [CpuMs], [LogicalReads], [CurrentStatement]
        )
        SELECT TOP (@CandidateMaxZeilen)
              [g].[session_id]
            , [g].[request_id]
            , [g].[scheduler_id]
            , [g].[dop]
            , [g].[request_time]
            , [g].[grant_time]
            , [g].[wait_time_ms]
            , CONVERT(bit, CASE WHEN [g].[grant_time] IS NULL THEN 1 ELSE 0 END)
            , [g].[is_small]
            , CONVERT(decimal(19,2), [g].[requested_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[required_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[granted_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[used_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[max_used_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [g].[ideal_memory_kb] / 1024.0)
            , [g].[group_id]
            , [wg].[name]
            , [g].[pool_id]
            , [rp].[name]
            , [g].[resource_semaphore_id]
            , [calc].[RequestMaxMemoryGrantPercent]
            , [calc].[PoolMaxWorkspaceMemoryMb]
            , [calc].[PoolTargetWorkspaceMemoryMb]
            , [calc].[PoolUsedWorkspaceMemoryMb]
            , [calc].[ConfiguredRequestMaxGrantMemoryMb]
            , [calc].[TargetRequestMaxGrantMemoryMb]
            , CONVERT(decimal(19,2), [wg].[max_request_grant_memory_kb] / 1024.0)
            , CONVERT(decimal(9,2), 100.0 * [g].[requested_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[granted_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[used_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[max_used_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[ideal_memory_kb]
                / NULLIF([calc].[ConfiguredRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[requested_memory_kb]
                / NULLIF([calc].[TargetRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[granted_memory_kb]
                / NULLIF([calc].[TargetRequestMaxGrantMemoryKb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[used_memory_kb]
                / NULLIF([g].[granted_memory_kb], 0))
            , CONVERT(decimal(9,2), 100.0 * [g].[max_used_memory_kb]
                / NULLIF([g].[granted_memory_kb], 0))
            , CONVERT(decimal(19,2), [sem].[target_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[max_target_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[total_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[available_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[granted_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [sem].[used_memory_kb] / 1024.0)
            , [sem].[grantee_count]
            , [sem].[waiter_count]
            , [g].[reserved_worker_count]
            , [g].[used_worker_count]
            , [g].[max_used_worker_count]
            , [g].[queue_id]
            , [g].[wait_order]
            , [s].[login_name]
            , [s].[host_name]
            , [s].[program_name]
            , [r].[database_id]
            , [d].[name]
            , [r].[status]
            , [r].[command]
            , [r].[total_elapsed_time]
            , [r].[cpu_time]
            , [r].[logical_reads]
            , CASE WHEN @MitSqlText = 1
                   THEN CASE
                            WHEN @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen = 0
                                THEN [statementText].[StatementText]
                            ELSE LEFT([statementText].[StatementText], @MaxSqlTextZeichen)
                        END
              END
        FROM [sys].[dm_exec_query_memory_grants] AS [g]
        LEFT JOIN [sys].[dm_exec_sessions] AS [s]
          ON [s].[session_id] = [g].[session_id]
        LEFT JOIN [sys].[dm_exec_requests] AS [r]
          ON [r].[session_id] = [g].[session_id]
         AND [r].[request_id] = [g].[request_id]
        LEFT JOIN [sys].[databases] AS [d] WITH (READUNCOMMITTED)
          ON [d].[database_id] = [r].[database_id]
        LEFT JOIN [sys].[dm_resource_governor_workload_groups] AS [wg]
          ON [wg].[group_id] = [g].[group_id]
        LEFT JOIN [sys].[dm_resource_governor_resource_pools] AS [rp]
          ON [rp].[pool_id] = [g].[pool_id]
        LEFT JOIN [sys].[dm_exec_query_resource_semaphores] AS [sem]
          ON [sem].[pool_id] = [g].[pool_id]
         AND [sem].[resource_semaphore_id] = [g].[resource_semaphore_id]
        OUTER APPLY [sys].[dm_exec_sql_text]
        (
            CASE WHEN @MitSqlText = 1 THEN [g].[sql_handle] END
        ) AS [t]
        OUTER APPLY [monitor].[TVF_StatementText]
        (
              [t].[text]
            , [r].[statement_start_offset]
            , [r].[statement_end_offset]
        ) AS [statementText]
        OUTER APPLY
        (
            SELECT
                  [RequestMaxMemoryGrantPercent] = CONVERT(decimal(9,4), [wg].[request_max_memory_grant_percent_numeric])
                , [PoolMaxWorkspaceMemoryMb] = CONVERT(decimal(19,2), [rp].[max_memory_kb] / 1024.0)
                , [PoolTargetWorkspaceMemoryMb] = CONVERT(decimal(19,2), [rp].[target_memory_kb] / 1024.0)
                , [PoolUsedWorkspaceMemoryMb] = CONVERT(decimal(19,2), [rp].[used_memory_kb] / 1024.0)
                , [ConfiguredRequestMaxGrantMemoryKb] =
                    CONVERT(decimal(38,4), [rp].[max_memory_kb])
                    * CONVERT(decimal(38,4), [wg].[request_max_memory_grant_percent_numeric]) / 100.0
                , [TargetRequestMaxGrantMemoryKb] =
                    CONVERT(decimal(38,4), [rp].[target_memory_kb])
                    * CONVERT(decimal(38,4), [wg].[request_max_memory_grant_percent_numeric]) / 100.0
                , [ConfiguredRequestMaxGrantMemoryMb] = CONVERT
                  (
                      decimal(19,2),
                      CONVERT(decimal(38,4), [rp].[max_memory_kb])
                      * CONVERT(decimal(38,4), [wg].[request_max_memory_grant_percent_numeric]) / 100.0 / 1024.0
                  )
                , [TargetRequestMaxGrantMemoryMb] = CONVERT
                  (
                      decimal(19,2),
                      CONVERT(decimal(38,4), [rp].[target_memory_kb])
                      * CONVERT(decimal(38,4), [wg].[request_max_memory_grant_percent_numeric]) / 100.0 / 1024.0
                  )
        ) AS [calc]
        WHERE (NOT EXISTS (SELECT 1 FROM [#SessionIdFilter]) OR EXISTS (SELECT 1 FROM [#SessionIdFilter] AS [sf] WHERE [sf].[SessionId] = [g].[session_id]))
          AND (@AktuelleSessionEinbeziehen = 1 OR [g].[session_id] <> @@SPID)
          AND (@NurWartende = 0 OR [g].[grant_time] IS NULL)
          AND (@MinRequestedMb IS NULL OR [g].[requested_memory_kb] >= @MinRequestedMb * 1024.0)
          AND (@MinGrantedMb IS NULL OR [g].[granted_memory_kb] >= @MinGrantedMb * 1024.0)
        ORDER BY
              CASE WHEN [g].[grant_time] IS NULL THEN 1 ELSE 0 END DESC
            , [g].[requested_memory_kb] DESC
            , [g].[wait_time_ms] DESC
            , [g].[session_id]
            , [g].[request_id];

        SELECT @CandidateRowCount = COUNT_BIG(*) FROM [#Result];
        SET @HasMoreRows = CONVERT(bit, CASE WHEN @CandidateRowCount > @EffectiveMaxZeilen THEN 1 ELSE 0 END);
        SET @RowCount = CASE WHEN @CandidateRowCount > @EffectiveMaxZeilen
                             THEN @EffectiveMaxZeilen ELSE @CandidateRowCount END;
        SET @Detail = CASE WHEN @RowCount = 0
                           THEN N'Aktuell keine passende Memory-Grant-Anforderung sichtbar.'
                           ELSE N'Memory Grants einschließlich Resource-Governor- und Semaphore-Kontext erfolgreich gelesen.' END;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @IsPartial = 1;
        SET @StatusCode = CASE WHEN @ErrorNumber IN (229, 262, 297, 300, 916) THEN 'DENIED_PERMISSION'
                               WHEN @ErrorNumber = 1222 THEN 'TIMEOUT'
                               ELSE 'ERROR_HANDLED' END;
        SET @Detail = N'Memory-Grant-Abfrage fehlgeschlagen.';
        INSERT [#Warnings] VALUES(@StatusCode, COALESCE(@ErrorMessage, @Detail));
    END CATCH;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @MonitorPrintMessage = FORMATMESSAGE
        (
            N'WARNUNG %s: %s',
            @StatusCode,
            COALESCE(@ErrorMessage, @Detail)
        );
        RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max);
        DECLARE @DataJson nvarchar(max);
        DECLARE @WarningsJson nvarchar(max);

        SET @MetaJson =
        (
            SELECT
                  N'CurrentMemoryGrants' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @MaxZeilen AS [requestedMaxRows]
                , @RowCount AS [returnedRows]
                , @HasMoreRows AS [resultLimited]
                , @HasMoreRows AS [hasMoreRows]
                , @RequiredPermission AS [requiredPermission]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
                , @Detail AS [detail]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

        SET @DataJson =
        (
            SELECT TOP (@EffectiveMaxZeilen) [r].*
            FROM [#Result] AS [r]
            ORDER BY [r].[IsWaiting] DESC, [r].[RequestedMemoryMb] DESC,
                     [r].[WaitTimeMs] DESC, [r].[SessionId], [r].[RequestId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @WarningsJson =
        (
            SELECT [WarningCode] AS [code], [WarningMessage] AS [message]
            FROM [#Warnings]
            ORDER BY [WarningCode]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"memoryGrants":', COALESCE(@DataJson, N'[]')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]')
            , N'}'
        );
    END;

    IF @ResultSetArtNormalisiert = 'RAW'
    BEGIN
        SELECT
              N'USP_CurrentMemoryGrants' AS [ModuleName]
            , @CollectionTimeUtc AS [CollectionTimeUtc]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @RowCount AS [RowCount]
            , @HasMoreRows AS [ResultLimited]
            , @RequiredPermission AS [RequiredPermission]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage]
            , @Detail AS [Detail];

        SELECT TOP (@EffectiveMaxZeilen) [r].*
        FROM [#Result] AS [r]
        ORDER BY [r].[IsWaiting] DESC, [r].[RequestedMemoryMb] DESC,
                 [r].[WaitTimeMs] DESC, [r].[SessionId], [r].[RequestId];
    END
    ELSE IF @ResultSetArtNormalisiert = 'CONSOLE'
    BEGIN
        SELECT
              N'Query Memory Grants' AS [Ergebnis]
            , @CollectionTimeUtc AS [Stand_UTC]
            , @StatusCode AS [Status]
            , @RowCount AS [Zeilen]
            , @HasMoreRows AS [Ergebnis_begrenzt]
            , @Detail AS [Hinweis];

        SELECT TOP (@EffectiveMaxZeilen)
              CASE WHEN [r].[IsWaiting] = 1
                   THEN N'Wartender Memory Grant'
                   ELSE N'Gewährter Memory Grant' END AS [Ergebnis]
            , [r].[SessionId] AS [Session]
            , [r].[RequestId] AS [Request]
            , [r].[LoginName] AS [Login]
            , [r].[HostName] AS [Host]
            , [r].[ProgramName] AS [Programm]
            , [r].[DatabaseName] AS [Datenbank]
            , [r].[RequestStatus] AS [Request_Status]
            , [r].[Command] AS [Command]
            , CASE WHEN [r].[IsWaiting] = 1
                   THEN CONCAT(CONVERT(varchar(30), [r].[WaitTimeMs]), N' ms')
                   ELSE N'läuft' END AS [Grant_Status]

            , [r].[SessionId] AS [Session_Memory]
            , CONCAT(CONVERT(varchar(40), [r].[RequestedMemoryMb]), N' MB') AS [Angefordert]
            , CONCAT(CONVERT(varchar(40), [r].[RequiredMemoryMb]), N' MB') AS [Mindestens_erforderlich]
            , CONCAT(CONVERT(varchar(40), [r].[GrantedMemoryMb]), N' MB') AS [Gewährt]
            , CONCAT(CONVERT(varchar(40), [r].[UsedMemoryMb]), N' MB') AS [Verwendet]
            , CONCAT(CONVERT(varchar(40), [r].[MaxUsedMemoryMb]), N' MB') AS [Maximal_verwendet]
            , CONCAT(CONVERT(varchar(40), [r].[IdealMemoryMb]), N' MB') AS [Ideal]
            , CONCAT(CONVERT(varchar(40), [r].[UsedOfGrantedPercent]), N' %') AS [Verwendet_vom_Grant]
            , CONCAT(CONVERT(varchar(40), [r].[MaxUsedOfGrantedPercent]), N' %') AS [Maximal_verwendet_vom_Grant]

            , [r].[SessionId] AS [Session_ResourceGovernor]
            , [r].[WorkloadGroupName] AS [Workload_Group]
            , [r].[PoolName] AS [Resource_Pool]
            , CONCAT(CONVERT(varchar(40), [r].[RequestMaxMemoryGrantPercent]), N' %') AS [Max_Request_Grant_Prozent]
            , CONCAT(CONVERT(varchar(40), [r].[ConfiguredRequestMaxGrantMemoryMb]), N' MB') AS [Konfiguriertes_Request_Maximum]
            , CONCAT(CONVERT(varchar(40), [r].[TargetRequestMaxGrantMemoryMb]), N' MB') AS [Aktuelles_Target_Request_Maximum]
            , CONCAT(CONVERT(varchar(40), [r].[RequestedOfRequestMaxPercent]), N' %') AS [Angefordert_vom_konfigurierten_Maximum]
            , CONCAT(CONVERT(varchar(40), [r].[GrantedOfRequestMaxPercent]), N' %') AS [Gewährt_vom_konfigurierten_Maximum]
            , CONCAT(CONVERT(varchar(40), [r].[UsedOfRequestMaxPercent]), N' %') AS [Verwendet_vom_konfigurierten_Maximum]
            , CONCAT(CONVERT(varchar(40), [r].[SemaphoreAvailableMemoryMb]), N' MB') AS [Semaphore_aktuell_verfügbar]
            , [r].[SemaphoreWaiterCount] AS [Semaphore_Wartende]
            , [r].[CurrentStatement] AS [Aktuelles_Statement]
        FROM [#Result] AS [r]
        ORDER BY [r].[IsWaiting] DESC, [r].[RequestedMemoryMb] DESC,
                 [r].[WaitTimeMs] DESC, [r].[SessionId], [r].[RequestId];
    END;
END;
GO
