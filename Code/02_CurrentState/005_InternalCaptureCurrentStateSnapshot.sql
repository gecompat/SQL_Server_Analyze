USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalCaptureCurrentStateSnapshot
Version      : 1.0.0
Stand        : 2026-07-22
Typ          : Interne Stored Procedure
Zweck        : Befüllt die vom aufrufenden Orchestrator angelegten lokalen
               Snapshot-Tabellen. Jede aktivierte Systemquelle wird genau
               einmal gelesen; nicht angeforderte Quellen werden nicht berührt.
Lebensdauer  : Der Aufrufer besitzt die lokalen Temp-Tabellen. Sie verschwinden
               mit dessen Procedure-Scope und können von einem späteren
               Einzelaufruf nicht wiederverwendet werden.
Sicherheit   : Read-only. Keine Konfiguration, Persistenz oder Rechtevergabe.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalCaptureCurrentStateSnapshot]
      @SnapshotId              uniqueidentifier
    , @CaptureSessions         bit = 0
    , @CaptureRequests         bit = 0
    , @CaptureConnections      bit = 0
    , @CaptureWaitingTasks     bit = 0
    , @CaptureMemoryGrants     bit = 0
    , @CaptureResourceGovernor bit = 0
    , @CaptureSqlText          bit = 0
    , @MaxSqlTextHandles       int = 1000
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    IF @SnapshotId IS NULL
        THROW 51020, N'@SnapshotId darf nicht NULL sein.', 1;

    IF @CaptureSessions IS NULL OR @CaptureSessions NOT IN (0,1)
       OR @CaptureRequests IS NULL OR @CaptureRequests NOT IN (0,1)
       OR @CaptureConnections IS NULL OR @CaptureConnections NOT IN (0,1)
       OR @CaptureWaitingTasks IS NULL OR @CaptureWaitingTasks NOT IN (0,1)
       OR @CaptureMemoryGrants IS NULL OR @CaptureMemoryGrants NOT IN (0,1)
       OR @CaptureResourceGovernor IS NULL OR @CaptureResourceGovernor NOT IN (0,1)
       OR @CaptureSqlText IS NULL OR @CaptureSqlText NOT IN (0,1)
       OR @MaxSqlTextHandles IS NULL OR @MaxSqlTextHandles < 0
        THROW 51020, N'Ungültiger Current-State-Snapshot-Parameter.', 1;

    IF OBJECT_ID(N'tempdb..#CurrentStateSnapshot_Context') IS NULL
       OR OBJECT_ID(N'tempdb..#CurrentStateSnapshot_SourceStatus') IS NULL
       OR OBJECT_ID(N'tempdb..#CurrentStateSnapshot_Sessions') IS NULL
       OR OBJECT_ID(N'tempdb..#CurrentStateSnapshot_Requests') IS NULL
       OR OBJECT_ID(N'tempdb..#CurrentStateSnapshot_Connections') IS NULL
       OR OBJECT_ID(N'tempdb..#CurrentStateSnapshot_WaitingTasks') IS NULL
       OR OBJECT_ID(N'tempdb..#CurrentStateSnapshot_MemoryGrants') IS NULL
       OR OBJECT_ID(N'tempdb..#CurrentStateSnapshot_WorkloadGroups') IS NULL
       OR OBJECT_ID(N'tempdb..#CurrentStateSnapshot_ResourcePools') IS NULL
       OR OBJECT_ID(N'tempdb..#CurrentStateSnapshot_SqlText') IS NULL
        THROW 51020, N'Der aufrufende Snapshot-Owner hat den Temp-Table-Vertrag nicht vollständig angelegt.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM [#CurrentStateSnapshot_Context]
        WHERE [SnapshotId] = @SnapshotId
    )
        THROW 51020, N'Diese Snapshot-ID wurde im aktuellen Aufruf bereits verwendet.', 1;

    INSERT [#CurrentStateSnapshot_Context]
    (
        [SnapshotId],[OwnerSessionId],[CreatedAtUtc],[ContractVersion]
    )
    VALUES
    (
        @SnapshotId,CONVERT(smallint,@@SPID),SYSUTCDATETIME(),1
    );

    DECLARE @HasFullView bit =
        CASE
            WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1
            WHEN TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) >= 16
                THEN COALESCE(HAS_PERMS_BY_NAME(NULL,N'SERVER',N'VIEW SERVER PERFORMANCE STATE'),0)
            ELSE COALESCE(HAS_PERMS_BY_NAME(NULL,N'SERVER',N'VIEW SERVER STATE'),0)
        END;
    DECLARE @CapturedAtUtc datetime2(3);
    DECLARE @CompletedAtUtc datetime2(3);
    DECLARE @RowCount bigint;
    DECLARE @ErrorNumber int;
    DECLARE @ErrorMessage nvarchar(2048);
    DECLARE @StatusCode varchar(40);
    DECLARE @IsPartial bit;
    DECLARE @BaseStatusCode varchar(40)=CASE WHEN @HasFullView=1 THEN 'AVAILABLE' ELSE 'AVAILABLE_LIMITED' END;
    DECLARE @BaseIsPartial bit=CASE WHEN @HasFullView=1 THEN 0 ELSE 1 END;

    IF @CaptureSessions=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentStateSnapshot_Sessions]
            (
                [SnapshotId],[CapturedAtUtc],[session_id],[is_user_process],[status],
                [login_name],[original_login_name],[host_name],[program_name],
                [client_interface_name],[login_time],[last_request_start_time],
                [last_request_end_time],[open_transaction_count],
                [transaction_isolation_level],[cpu_time],[reads],[writes],
                [logical_reads],[memory_usage],[row_count]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[s].[session_id],[s].[is_user_process],[s].[status],
                [s].[login_name],[s].[original_login_name],[s].[host_name],[s].[program_name],
                [s].[client_interface_name],[s].[login_time],[s].[last_request_start_time],
                [s].[last_request_end_time],[s].[open_transaction_count],
                [s].[transaction_isolation_level],[s].[cpu_time],[s].[reads],[s].[writes],
                [s].[logical_reads],[s].[memory_usage],[s].[row_count]
            FROM [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,10,'SESSIONS',N'sys.dm_exec_sessions',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,10,'SESSIONS',N'sys.dm_exec_sessions',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureRequests=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentStateSnapshot_Requests]
            (
                [SnapshotId],[CapturedAtUtc],[session_id],[request_id],[status],[command],
                [start_time],[sql_handle],[statement_start_offset],[statement_end_offset],
                [plan_handle],[database_id],[connection_id],[blocking_session_id],
                [wait_type],[wait_time],[last_wait_type],[wait_resource],
                [open_transaction_count],[open_resultset_count],[transaction_id],
                [context_info],[percent_complete],[estimated_completion_time],
                [cpu_time],[total_elapsed_time],[scheduler_id],[task_address],
                [reads],[writes],[logical_reads],[transaction_isolation_level],
                [row_count],[nest_level],[executing_managed_code],[group_id],
                [query_hash],[query_plan_hash],[statement_sql_handle],
                [statement_context_id],[dop],[parallel_worker_count],[is_resumable]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[r].[session_id],[r].[request_id],[r].[status],[r].[command],
                [r].[start_time],[r].[sql_handle],[r].[statement_start_offset],[r].[statement_end_offset],
                [r].[plan_handle],[r].[database_id],[r].[connection_id],[r].[blocking_session_id],
                [r].[wait_type],[r].[wait_time],[r].[last_wait_type],[r].[wait_resource],
                [r].[open_transaction_count],[r].[open_resultset_count],[r].[transaction_id],
                [r].[context_info],[r].[percent_complete],[r].[estimated_completion_time],
                [r].[cpu_time],[r].[total_elapsed_time],[r].[scheduler_id],[r].[task_address],
                [r].[reads],[r].[writes],[r].[logical_reads],[r].[transaction_isolation_level],
                [r].[row_count],[r].[nest_level],[r].[executing_managed_code],[r].[group_id],
                [r].[query_hash],[r].[query_plan_hash],[r].[statement_sql_handle],
                [r].[statement_context_id],[r].[dop],[r].[parallel_worker_count],[r].[is_resumable]
            FROM [sys].[dm_exec_requests] AS [r] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,20,'REQUESTS',N'sys.dm_exec_requests',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,20,'REQUESTS',N'sys.dm_exec_requests',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureConnections=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentStateSnapshot_Connections]
            (
                [SnapshotId],[CapturedAtUtc],[session_id],[connection_id],
                [most_recent_sql_handle],[client_net_address],[net_transport],
                [protocol_type],[encrypt_option],[auth_scheme]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[c].[session_id],[c].[connection_id],
                [c].[most_recent_sql_handle],[c].[client_net_address],[c].[net_transport],
                [c].[protocol_type],[c].[encrypt_option],[c].[auth_scheme]
            FROM [sys].[dm_exec_connections] AS [c] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,30,'CONNECTIONS',N'sys.dm_exec_connections',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,30,'CONNECTIONS',N'sys.dm_exec_connections',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureWaitingTasks=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentStateSnapshot_WaitingTasks]
            (
                [SnapshotId],[CapturedAtUtc],[waiting_task_address],[session_id],
                [exec_context_id],[wait_duration_ms],[wait_type],[resource_address],
                [blocking_task_address],[blocking_session_id],
                [blocking_exec_context_id],[resource_description]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[w].[waiting_task_address],[w].[session_id],
                [w].[exec_context_id],[w].[wait_duration_ms],[w].[wait_type],[w].[resource_address],
                [w].[blocking_task_address],[w].[blocking_session_id],
                [w].[blocking_exec_context_id],[w].[resource_description]
            FROM [sys].[dm_os_waiting_tasks] AS [w] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,40,'WAITING_TASKS',N'sys.dm_os_waiting_tasks',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,40,'WAITING_TASKS',N'sys.dm_os_waiting_tasks',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureMemoryGrants=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentStateSnapshot_MemoryGrants]
            (
                [SnapshotId],[CapturedAtUtc],[session_id],[request_id],
                [requested_memory_kb],[granted_memory_kb],[used_memory_kb],
                [ideal_memory_kb],[group_id],[pool_id]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[g].[session_id],[g].[request_id],
                [g].[requested_memory_kb],[g].[granted_memory_kb],[g].[used_memory_kb],
                [g].[ideal_memory_kb],[g].[group_id],[g].[pool_id]
            FROM [sys].[dm_exec_query_memory_grants] AS [g] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,50,'MEMORY_GRANTS',N'sys.dm_exec_query_memory_grants',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,50,'MEMORY_GRANTS',N'sys.dm_exec_query_memory_grants',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureResourceGovernor=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentStateSnapshot_WorkloadGroups]
            (
                [SnapshotId],[CapturedAtUtc],[group_id],[name],[pool_id]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[g].[group_id],[g].[name],[g].[pool_id]
            FROM [sys].[dm_resource_governor_workload_groups] AS [g] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,60,'WORKLOAD_GROUPS',N'sys.dm_resource_governor_workload_groups',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,60,'WORKLOAD_GROUPS',N'sys.dm_resource_governor_workload_groups',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;

        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            INSERT [#CurrentStateSnapshot_ResourcePools]
            (
                [SnapshotId],[CapturedAtUtc],[pool_id],[name]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[p].[pool_id],[p].[name]
            FROM [sys].[dm_resource_governor_resource_pools] AS [p] WITH (NOLOCK);

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,70,'RESOURCE_POOLS',N'sys.dm_resource_governor_resource_pools',@CapturedAtUtc,@CompletedAtUtc,
             @BaseStatusCode,@BaseIsPartial,@RowCount,NULL,NULL);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,70,'RESOURCE_POOLS',N'sys.dm_resource_governor_resource_pools',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

    IF @CaptureSqlText=1
    BEGIN
        SET @CapturedAtUtc=SYSUTCDATETIME();
        BEGIN TRY
            CREATE TABLE [#CurrentStateSnapshot_SqlHandleCandidate]
            (
                [SqlHandle] varbinary(64) NOT NULL PRIMARY KEY
            );

            INSERT [#CurrentStateSnapshot_SqlHandleCandidate]([SqlHandle])
            SELECT [h].[SqlHandle]
            FROM
            (
                SELECT [r].[sql_handle] AS [SqlHandle]
                FROM [#CurrentStateSnapshot_Requests] AS [r]
                WHERE [r].[SnapshotId]=@SnapshotId
                  AND [r].[sql_handle] IS NOT NULL
                UNION
                SELECT [c].[most_recent_sql_handle]
                FROM [#CurrentStateSnapshot_Connections] AS [c]
                WHERE [c].[SnapshotId]=@SnapshotId
                  AND [c].[most_recent_sql_handle] IS NOT NULL
            ) AS [h];

            DECLARE @SqlTextCandidateCount bigint=
                (SELECT COUNT_BIG(*) FROM [#CurrentStateSnapshot_SqlHandleCandidate]);

            IF @MaxSqlTextHandles>0 AND @SqlTextCandidateCount>@MaxSqlTextHandles
            BEGIN
                ;WITH [Limited] AS
                (
                    SELECT
                        [SqlHandle],
                        [RowNumber]=ROW_NUMBER() OVER(ORDER BY [SqlHandle])
                    FROM [#CurrentStateSnapshot_SqlHandleCandidate]
                )
                DELETE FROM [Limited]
                WHERE [RowNumber]>@MaxSqlTextHandles;
            END;

            INSERT [#CurrentStateSnapshot_SqlText]
            (
                [SnapshotId],[CapturedAtUtc],[SqlHandle],[Text],[DatabaseId],
                [ObjectId],[ObjectNumber],[IsEncrypted],[EvidenceStatus]
            )
            SELECT
                @SnapshotId,@CapturedAtUtc,[h].[SqlHandle],[t].[text],[t].[dbid],
                [t].[objectid],[t].[number],[t].[encrypted],
                CONVERT(varchar(40),CASE WHEN [t].[text] IS NULL THEN 'TEXT_UNAVAILABLE' ELSE 'AVAILABLE' END)
            FROM [#CurrentStateSnapshot_SqlHandleCandidate] AS [h]
            OUTER APPLY [sys].[dm_exec_sql_text]([h].[SqlHandle]) AS [t];

            SET @RowCount=@@ROWCOUNT;
            SET @CompletedAtUtc=SYSUTCDATETIME();
            SET @IsPartial=CASE WHEN @MaxSqlTextHandles>0 AND @SqlTextCandidateCount>@MaxSqlTextHandles THEN 1 ELSE @BaseIsPartial END;
            SET @StatusCode=CASE WHEN @IsPartial=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END;
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,80,'SQL_TEXT',N'sys.dm_exec_sql_text',@CapturedAtUtc,@CompletedAtUtc,
             @StatusCode,@IsPartial,@RowCount,NULL,
             CASE WHEN @MaxSqlTextHandles>0 AND @SqlTextCandidateCount>@MaxSqlTextHandles
                  THEN N'Die Zahl unterschiedlicher SQL-Handles überschritt @MaxSqlTextHandles.'
                  ELSE NULL END);
        END TRY
        BEGIN CATCH
            SELECT @ErrorNumber=ERROR_NUMBER(),@ErrorMessage=ERROR_MESSAGE(),@CompletedAtUtc=SYSUTCDATETIME();
            INSERT [#CurrentStateSnapshot_SourceStatus]
            VALUES
            (@SnapshotId,80,'SQL_TEXT',N'sys.dm_exec_sql_text',@CapturedAtUtc,@CompletedAtUtc,
             CASE WHEN @ErrorNumber=1222 THEN 'TIMEOUT' WHEN @ErrorNumber IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
             1,0,@ErrorNumber,@ErrorMessage);
        END CATCH;
    END;

END;
GO
