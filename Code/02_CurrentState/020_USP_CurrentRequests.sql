USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentRequests
Version      : 2.1.0
Stand        : 2026-07-16
Typ          : Stored Procedure
Zweck        : Aktive Requests mit Session-, Wait-, Memory-Grant-, Modul- und
               exakt abgegrenztem SQL-Statement- sowie Ausführungs-/Verschachtelungskontext.
Filter       : Session-ID-Liste, exakte bracket-aware Textlisten und getrennte
               LIKE-/Regex-Patterns.
SQL-Text     : Das laufende Statement wird über statement_start_offset und
               statement_end_offset aus dem Batch beziehungsweise persistenten
               Modul extrahiert. Optional sind vollständiger Batch-/Modultext,
               Input Buffer und Modulauflösung verfügbar.
Ausgabe      : CONSOLE (Default), RAW, NONE sowie optionales JSON-Envelope mit
               benannten Arrays requests, statements, batches, inputBuffers
               und warnings.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentRequests]
      @SessionIds                    nvarchar(max)  = NULL
    , @EigeneSessionsModus           varchar(16)    = 'ALLE'
    , @AktuelleSessionEinbeziehen    bit            = 0
    , @SystemSessionsEinbeziehen     bit            = 0
    , @NurBlockierte                 bit            = 0
    , @NurMitWait                    bit            = 0
    , @MinLaufzeitSekunden           int            = NULL
    , @MinCpuMs                      bigint         = NULL
    , @MinLogicalReads               bigint         = NULL
    , @LoginNames                    nvarchar(max)  = NULL
    , @LoginNamePattern              nvarchar(4000) = NULL
    , @HostNames                     nvarchar(max)  = NULL
    , @HostNamePattern               nvarchar(4000) = NULL
    , @ProgramNames                  nvarchar(max)  = NULL
    , @ProgramNamePattern            nvarchar(4000) = NULL
    , @DatabaseNames                 nvarchar(max)  = NULL
    , @DatabaseNamePattern           nvarchar(4000) = NULL
    , @TextPattern                   nvarchar(4000) = NULL
    , @MitSqlText                    bit            = 1
    , @GesamtenSqlTextEinbeziehen    bit            = 0
    , @InputBufferEinbeziehen        bit            = 0
    , @ModulInfoEinbeziehen          bit            = 1
    , @MaxSqlTextZeichen             int            = 4000
    , @MaxZeilen                     int            = 500
    , @Sortierung                    varchar(32)    = 'RELEVANZ'
    , @ResultSetArt                  varchar(16)    = 'CONSOLE'
    , @ResultTable                     sysname        = NULL
    , @JsonErzeugen                  bit            = 0
    , @Json                          nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                bit            = 1
    , @Hilfe                         bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @ModuleName sysname = N'USP_CurrentRequests';
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @RowCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @Detail nvarchar(2000) = NULL;
    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    IF @TableResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @RequiredPermission nvarchar(256) =
        CASE
            WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16
                THEN N'VIEW SERVER PERFORMANCE STATE'
            ELSE N'VIEW SERVER STATE'
        END;
    DECLARE @HasFullView bit =
        CASE
            WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1
            WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16
                THEN COALESCE(HAS_PERMS_BY_NAME(NULL, N'SERVER', N'VIEW SERVER PERFORMANCE STATE'), 0)
            ELSE COALESCE(HAS_PERMS_BY_NAME(NULL, N'SERVER', N'VIEW SERVER STATE'), 0)
        END;
    DECLARE @MonitorPrintMessage nvarchar(2048);
    DECLARE @CandidateMaxZeilen bigint;
    DECLARE @SqlTextErforderlich bit;
    DECLARE @StatementTextErforderlich bit;
    DECLARE @BatchTextErforderlich bit;

    SET @EigeneSessionsModus = UPPER(LTRIM(RTRIM(COALESCE(@EigeneSessionsModus, 'ALLE'))));
    SET @Sortierung = UPPER(LTRIM(RTRIM(COALESCE(@Sortierung, 'RELEVANZ'))));
    SET @StatementTextErforderlich =
        CASE WHEN @MitSqlText = 1 OR @TextPattern IS NOT NULL THEN 1 ELSE 0 END;
    SET @BatchTextErforderlich =
        CASE WHEN @GesamtenSqlTextEinbeziehen = 1 OR @TextPattern IS NOT NULL THEN 1 ELSE 0 END;
    SET @SqlTextErforderlich =
        CASE
            WHEN @StatementTextErforderlich = 1
              OR @BatchTextErforderlich = 1
              OR @ModulInfoEinbeziehen = 1
                THEN 1
            ELSE 0
        END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentRequests';
        PRINT N'@SessionIds: Pipe-Liste. Exakte Namenslisten und die zugehörigen ...Pattern sind gegenseitig exklusiv.';
        PRINT N'Pattern: LIKE (Default/like:), regex: oder regexi:. @TextPattern prüft das aktuelle Statement und den vollständigen Batch-/Modultext.';
        PRINT N'@MitSqlText=1 gibt das exakt über die Request-Offsets ermittelte Statement aus.';
        PRINT N'@GesamtenSqlTextEinbeziehen=1 gibt zusätzlich den vollständigen Batch beziehungsweise persistenten Modultext aus.';
        PRINT N'@InputBufferEinbeziehen=1 ergänzt den ursprünglich an SQL Server übergebenen Befehl, z. B. EXEC/RPC-Aufruf.';
        PRINT N'@ModulInfoEinbeziehen=1 löst dbid/objectid über die Systemtabellen der jeweiligen Datenbank auf.';
        PRINT N'@MaxSqlTextZeichen: positiver Wert kürzt die Darstellung; NULL/0 gibt den jeweiligen Text vollständig aus.';
        PRINT N'@MaxZeilen: positiver Wert begrenzt; NULL/0 unbegrenzt. @ResultSetArt CONSOLE (Default), RAW, TABLE oder NONE; optional @Json OUTPUT.';
        RETURN;
    END;

    CREATE TABLE [#SessionIdFilter]
    (
        [SessionId] smallint NOT NULL PRIMARY KEY
    );

    CREATE TABLE [#StringFilter]
    (
          [FilterType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StringValue] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([FilterType], [StringValue])
    );

    CREATE TABLE [#Warnings]
    (
          [WarningId] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [SessionId] smallint NULL
        , [RequestId] int NULL
        , [DatabaseName] sysname NULL
        , [Code] varchar(40) NOT NULL
        , [Message] nvarchar(2048) NOT NULL
    );

    DECLARE @LoginMode varchar(8), @LoginPattern nvarchar(4000), @LoginFlags varchar(8), @LoginValid bit;
    DECLARE @HostMode varchar(8), @HostPattern nvarchar(4000), @HostFlags varchar(8), @HostValid bit;
    DECLARE @ProgramMode varchar(8), @ProgramPattern nvarchar(4000), @ProgramFlags varchar(8), @ProgramValid bit;
    DECLARE @DatabaseMode varchar(8), @DatabasePattern nvarchar(4000), @DatabaseFlags varchar(8), @DatabaseValid bit;
    DECLARE @TextMode varchar(8), @TextPatternValue nvarchar(4000), @TextFlags varchar(8), @TextValid bit;

    SELECT @LoginMode = [PatternMode], @LoginPattern = [PatternValue], @LoginFlags = [RegexFlags], @LoginValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@LoginNamePattern);

    SELECT @HostMode = [PatternMode], @HostPattern = [PatternValue], @HostFlags = [RegexFlags], @HostValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@HostNamePattern);

    SELECT @ProgramMode = [PatternMode], @ProgramPattern = [PatternValue], @ProgramFlags = [RegexFlags], @ProgramValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@ProgramNamePattern);

    SELECT @DatabaseMode = [PatternMode], @DatabasePattern = [PatternValue], @DatabaseFlags = [RegexFlags], @DatabaseValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);

    SELECT @TextMode = [PatternMode], @TextPatternValue = [PatternValue], @TextFlags = [RegexFlags], @TextValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@TextPattern);

    IF @SessionIds IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            WHERE [IsValid] = 0
               OR [NumberValue] NOT BETWEEN 1 AND 32767
        )
        BEGIN
            SET @StatusCode = 'INVALID_PARAMETER';
        END;
        ELSE
        BEGIN
            INSERT [#SessionIdFilter] ([SessionId])
            SELECT CONVERT(smallint, [NumberValue])
            FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            GROUP BY [NumberValue];
        END;
    END;

    IF @StatusCode = 'AVAILABLE'
       AND
       (
              (@LoginNames IS NOT NULL AND @LoginNamePattern IS NOT NULL)
           OR (@HostNames IS NOT NULL AND @HostNamePattern IS NOT NULL)
           OR (@ProgramNames IS NOT NULL AND @ProgramNamePattern IS NOT NULL)
           OR (@DatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL)
           OR @LoginValid = 0
           OR @HostValid = 0
           OR @ProgramValid = 0
           OR @DatabaseValid = 0
           OR @TextValid = 0
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND
       (
              (@LoginNames IS NOT NULL AND EXISTS
               (SELECT 1 FROM [monitor].[TVF_ParseStringList](@LoginNames) WHERE [IsValid] = 0 OR LEN([StringValue]) > 128))
           OR (@HostNames IS NOT NULL AND EXISTS
               (SELECT 1 FROM [monitor].[TVF_ParseStringList](@HostNames) WHERE [IsValid] = 0 OR LEN([StringValue]) > 128))
           OR (@ProgramNames IS NOT NULL AND EXISTS
               (SELECT 1 FROM [monitor].[TVF_ParseStringList](@ProgramNames) WHERE [IsValid] = 0 OR LEN([StringValue]) > 128))
           OR (@DatabaseNames IS NOT NULL AND EXISTS
               (SELECT 1 FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames) WHERE [IsValid] = 0))
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        INSERT [#StringFilter] ([FilterType], [StringValue])
        SELECT 'LOGIN', [StringValue]
        FROM [monitor].[TVF_ParseStringList](@LoginNames)
        WHERE [IsValid] = 1
        GROUP BY [StringValue];

        INSERT [#StringFilter] ([FilterType], [StringValue])
        SELECT 'HOST', [StringValue]
        FROM [monitor].[TVF_ParseStringList](@HostNames)
        WHERE [IsValid] = 1
        GROUP BY [StringValue];

        INSERT [#StringFilter] ([FilterType], [StringValue])
        SELECT 'PROGRAM', [StringValue]
        FROM [monitor].[TVF_ParseStringList](@ProgramNames)
        WHERE [IsValid] = 1
        GROUP BY [StringValue];

        INSERT [#StringFilter] ([FilterType], [StringValue])
        SELECT 'DATABASE', [NameValue]
        FROM [monitor].[TVF_ParseSqlNameList](@DatabaseNames)
        WHERE [IsValid] = 1
        GROUP BY [NameValue];
    END;

    DECLARE @HasRegex bit =
        CASE
            WHEN @LoginMode IN ('REGEX', 'REGEXI')
              OR @HostMode IN ('REGEX', 'REGEXI')
              OR @ProgramMode IN ('REGEX', 'REGEXI')
              OR @DatabaseMode IN ('REGEX', 'REGEXI')
              OR @TextMode IN ('REGEX', 'REGEXI')
                THEN 1
            ELSE 0
        END;

    IF @StatusCode = 'AVAILABLE'
       AND @HasRegex = 1
       AND
       (
           TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) < 17
           OR
           (
               SELECT [compatibility_level]
               FROM [master].[sys].[databases] WITH (NOLOCK)
               WHERE [database_id] = DB_ID()
           ) < 170
       )
    BEGIN
        SET @StatusCode = 'UNAVAILABLE_FEATURE';
        SET @ErrorMessage = N'Regex benötigt SQL Server 2025 und Compatibility Level 170.';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND
       (
              @EigeneSessionsModus NOT IN ('ALLE', 'NUR', 'AUSSCHLIESSEN')
           OR @Sortierung NOT IN ('RELEVANZ', 'CPU', 'READS', 'DAUER', 'SESSION')
           OR @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
           OR @MaxZeilen < 0
           OR @MaxSqlTextZeichen < 0
           OR COALESCE(@MinLaufzeitSekunden, 0) < 0
           OR COALESCE(@MinCpuMs, 0) < 0
           OR COALESCE(@MinLogicalReads, 0) < 0
           OR @MitSqlText IS NULL OR @MitSqlText NOT IN (0, 1)
           OR @GesamtenSqlTextEinbeziehen IS NULL OR @GesamtenSqlTextEinbeziehen NOT IN (0, 1)
           OR @InputBufferEinbeziehen IS NULL OR @InputBufferEinbeziehen NOT IN (0, 1)
           OR @ModulInfoEinbeziehen IS NULL OR @ModulInfoEinbeziehen NOT IN (0, 1)
           OR @JsonErzeugen IS NULL OR @JsonErzeugen NOT IN (0, 1)
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
    END;

    IF @StatusCode = 'INVALID_PARAMETER'
    BEGIN
        SET @ErrorMessage = COALESCE(@ErrorMessage, N'Ungültige Liste, Kombination, Pattern- oder Steuerangabe.');
    END;

    CREATE TABLE [#Result]
    (
          [SessionId] smallint NOT NULL
        , [RequestId] int NOT NULL
        , [RequestStatus] nvarchar(30) NULL
        , [Command] nvarchar(32) NULL
        , [DatabaseId] smallint NULL
        , [DatabaseName] sysname NULL
        , [LoginName] nvarchar(128) NULL
        , [OriginalLoginName] nvarchar(128) NULL
        , [HostName] nvarchar(128) NULL
        , [ProgramName] nvarchar(128) NULL
        , [StartTime] datetime NULL
        , [ElapsedMs] int NULL
        , [CpuMs] int NULL
        , [LogicalReads] bigint NULL
        , [Reads] bigint NULL
        , [Writes] bigint NULL
        , [RowCount] bigint NULL
        , [PercentComplete] real NULL
        , [EstimatedCompletionTimeMs] bigint NULL
        , [BlockingSessionId] smallint NULL
        , [WaitType] nvarchar(120) NULL
        , [WaitTimeMs] int NULL
        , [LastWaitType] nvarchar(120) NULL
        , [WaitResource] nvarchar(256) NULL
        , [WaitingTaskCount] int NULL
        , [MaxTaskWaitMs] bigint NULL
        , [TaskWaitTypes] nvarchar(max) NULL
        , [RequestedMemoryMb] decimal(19,2) NULL
        , [GrantedMemoryMb] decimal(19,2) NULL
        , [UsedMemoryMb] decimal(19,2) NULL
        , [IdealMemoryMb] decimal(19,2) NULL
        , [Dop] smallint NULL
        , [ParallelWorkerCount] int NULL
        , [TransactionIsolationLevel] nvarchar(40) NULL
        , [OpenTransactionCount] int NULL
        , [OpenResultsetCount] int NULL
        , [TransactionId] bigint NULL
        , [ConnectionId] uniqueidentifier NULL
        , [SchedulerId] int NULL
        , [TaskAddress] varbinary(8) NULL
        , [NestLevel] int NULL
        , [WorkloadGroupId] int NULL
        , [WorkloadGroupName] sysname NULL
        , [ResourcePoolId] int NULL
        , [ResourcePoolName] sysname NULL
        , [StatementSqlHandle] varbinary(64) NULL
        , [StatementContextId] bigint NULL
        , [IsResumable] bit NULL
        , [ExecutingManagedCode] bit NULL
        , [ContextInfo] varbinary(128) NULL
        , [ClientNetAddress] varchar(48) NULL
        , [QueryHash] binary(8) NULL
        , [QueryPlanHash] binary(8) NULL
        , [SqlHandle] varbinary(64) NULL
        , [PlanHandle] varbinary(64) NULL
        , [SqlTextDatabaseId] int NULL
        , [SqlTextObjectId] int NULL
        , [SqlTextObjectNumber] smallint NULL
        , [SqlTextIsEncrypted] bit NULL
        , [ExecutionContextType] varchar(20) NULL
        , [ModuleDatabaseName] sysname NULL
        , [ModuleSchemaName] sysname NULL
        , [ModuleObjectName] sysname NULL
        , [ModuleType] char(2) NULL
        , [ModuleTypeDescription] nvarchar(60) NULL
        , [ModuleFullName] nvarchar(776) NULL
        , [HasStatementOffsets] bit NULL
        , [IsStatementOffsetValid] bit NULL
        , [StatementStartOffsetBytes] int NULL
        , [StatementEndOffsetBytes] int NULL
        , [StatementStartCharacter] int NULL
        , [StatementEndCharacter] int NULL
        , [StatementStartLine] int NULL
        , [StatementEndLine] int NULL
        , [CurrentStatementCharacterCount] int NULL
        , [CurrentStatementIsTruncated] bit NULL
        , [BatchTextCharacterCount] int NULL
        , [BatchTextIsTruncated] bit NULL
        , [CurrentStatement] nvarchar(max) NULL
        , [BatchText] nvarchar(max) NULL
        , [InputBufferEventType] nvarchar(256) NULL
        , [InputBufferParameterCount] smallint NULL
        , [InputBufferCharacterCount] int NULL
        , [InputBufferIsTruncated] bit NULL
        , [InputBufferText] nvarchar(max) NULL
        , PRIMARY KEY ([SessionId], [RequestId])
    );

    SET @CandidateMaxZeilen =
        CASE
            WHEN @HasRegex = 1 OR @MaxZeilen IS NULL OR @MaxZeilen = 0
                THEN CONVERT(bigint, 9223372036854775807)
            ELSE CONVERT(bigint, @MaxZeilen) + 1
        END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#Result]
        (
              [SessionId], [RequestId], [RequestStatus], [Command]
            , [DatabaseId], [DatabaseName], [LoginName], [OriginalLoginName]
            , [HostName], [ProgramName], [StartTime], [ElapsedMs], [CpuMs]
            , [LogicalReads], [Reads], [Writes], [RowCount], [PercentComplete]
            , [EstimatedCompletionTimeMs], [BlockingSessionId], [WaitType]
            , [WaitTimeMs], [LastWaitType], [WaitResource], [WaitingTaskCount]
            , [MaxTaskWaitMs], [TaskWaitTypes], [RequestedMemoryMb]
            , [GrantedMemoryMb], [UsedMemoryMb], [IdealMemoryMb], [Dop]
            , [ParallelWorkerCount], [TransactionIsolationLevel]
            , [OpenTransactionCount], [OpenResultsetCount], [TransactionId]
            , [ConnectionId], [SchedulerId], [TaskAddress], [NestLevel]
            , [WorkloadGroupId], [WorkloadGroupName], [ResourcePoolId], [ResourcePoolName]
            , [StatementSqlHandle], [StatementContextId], [IsResumable]
            , [ExecutingManagedCode], [ContextInfo], [ClientNetAddress], [QueryHash]
            , [QueryPlanHash], [SqlHandle], [PlanHandle]
            , [SqlTextDatabaseId], [SqlTextObjectId], [SqlTextObjectNumber]
            , [SqlTextIsEncrypted], [ExecutionContextType]
            , [HasStatementOffsets], [IsStatementOffsetValid]
            , [StatementStartOffsetBytes], [StatementEndOffsetBytes]
            , [StatementStartCharacter], [StatementEndCharacter]
            , [StatementStartLine], [StatementEndLine]
            , [CurrentStatementCharacterCount], [CurrentStatementIsTruncated]
            , [BatchTextCharacterCount], [BatchTextIsTruncated]
            , [CurrentStatement], [BatchText]
            , [InputBufferEventType], [InputBufferParameterCount]
            , [InputBufferCharacterCount], [InputBufferIsTruncated]
            , [InputBufferText]
        )
        SELECT TOP (@CandidateMaxZeilen)
              [r].[session_id]
            , [r].[request_id]
            , [r].[status]
            , [r].[command]
            , [r].[database_id]
            , [d].[name]
            , [s].[login_name]
            , [s].[original_login_name]
            , [s].[host_name]
            , [s].[program_name]
            , [r].[start_time]
            , [r].[total_elapsed_time]
            , [r].[cpu_time]
            , [r].[logical_reads]
            , [r].[reads]
            , [r].[writes]
            , [r].[row_count]
            , [r].[percent_complete]
            , [r].[estimated_completion_time]
            , NULLIF([r].[blocking_session_id], 0)
            , [r].[wait_type]
            , [r].[wait_time]
            , [r].[last_wait_type]
            , [r].[wait_resource]
            , CONVERT(int, [wt].[WaitingTaskCount])
            , [wt].[MaxTaskWaitMs]
            , [wt].[TaskWaitTypes]
            , CONVERT(decimal(19,2), [mg].[requested_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [mg].[granted_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [mg].[used_memory_kb] / 1024.0)
            , CONVERT(decimal(19,2), [mg].[ideal_memory_kb] / 1024.0)
            , [r].[dop]
            , [r].[parallel_worker_count]
            , CASE [r].[transaction_isolation_level]
                  WHEN 0 THEN N'Unspecified'
                  WHEN 1 THEN N'ReadUncommitted'
                  WHEN 2 THEN N'ReadCommitted'
                  WHEN 3 THEN N'RepeatableRead'
                  WHEN 4 THEN N'Serializable'
                  WHEN 5 THEN N'Snapshot'
              END
            , [r].[open_transaction_count]
            , [r].[open_resultset_count]
            , [r].[transaction_id]
            , [c].[connection_id]
            , [r].[scheduler_id]
            , [r].[task_address]
            , [r].[nest_level]
            , [r].[group_id]
            , [wg].[name]
            , [rp].[pool_id]
            , [rp].[name]
            , [r].[statement_sql_handle]
            , [r].[statement_context_id]
            , [r].[is_resumable]
            , [r].[executing_managed_code]
            , [r].[context_info]
            , [c].[client_net_address]
            , [r].[query_hash]
            , [r].[query_plan_hash]
            , [r].[sql_handle]
            , [r].[plan_handle]
            , [txt].[dbid]
            , [txt].[objectid]
            , [txt].[number]
            , [txt].[encrypted]
            , CASE
                  WHEN [txt].[objectid] IS NOT NULL AND [txt].[objectid] > 0 THEN 'MODULE'
                  WHEN [txt].[text] IS NOT NULL THEN 'BATCH'
                  ELSE 'UNAVAILABLE'
              END
            , [st].[HasStatementOffsets]
            , [st].[IsStatementOffsetValid]
            , [st].[StatementStartOffsetBytes]
            , [st].[StatementEndOffsetBytes]
            , [st].[StatementStartCharacter]
            , [st].[StatementEndCharacter]
            , [st].[StatementStartLine]
            , [st].[StatementEndLine]
            , [st].[StatementCharacterCount]
            , CONVERT(bit, 0)
            , [st].[BatchCharacterCount]
            , CONVERT(bit, 0)
            , CASE WHEN @StatementTextErforderlich = 1 THEN [st].[StatementText] END
            , CASE WHEN @BatchTextErforderlich = 1 THEN [txt].[text] END
            , NULL
            , NULL
            , NULL
            , CONVERT(bit, 0)
            , NULL
        FROM [sys].[dm_exec_requests] AS [r]
        JOIN [sys].[dm_exec_sessions] AS [s]
          ON [s].[session_id] = [r].[session_id]
        LEFT JOIN [sys].[dm_exec_connections] AS [c]
          ON [c].[session_id] = [r].[session_id]
        LEFT JOIN [sys].[databases] AS [d] WITH (READUNCOMMITTED)
          ON [d].[database_id] = [r].[database_id]
        OUTER APPLY
        (
            SELECT
                  [WaitingTaskCount] = COUNT_BIG(*)
                , [MaxTaskWaitMs] = MAX(CONVERT(bigint, [w].[wait_duration_ms]))
                , [TaskWaitTypes] = STRING_AGG(CONVERT(nvarchar(max), [w].[wait_type]), N',')
                    WITHIN GROUP (ORDER BY [w].[wait_type])
            FROM [sys].[dm_os_waiting_tasks] AS [w]
            WHERE [w].[session_id] = [r].[session_id]
        ) AS [wt]
        LEFT JOIN [sys].[dm_exec_query_memory_grants] AS [mg]
          ON [mg].[session_id] = [r].[session_id]
         AND [mg].[request_id] = [r].[request_id]
        LEFT JOIN [sys].[dm_resource_governor_workload_groups] AS [wg]
          ON [wg].[group_id] = [r].[group_id]
        LEFT JOIN [sys].[dm_resource_governor_resource_pools] AS [rp]
          ON [rp].[pool_id] = [wg].[pool_id]
        OUTER APPLY [sys].[dm_exec_sql_text]
        (
            CASE WHEN @SqlTextErforderlich = 1 THEN [r].[sql_handle] END
        ) AS [txt]
        OUTER APPLY [monitor].[TVF_StatementText]
        (
              [txt].[text]
            , [r].[statement_start_offset]
            , [r].[statement_end_offset]
        ) AS [st]
        WHERE
              (NOT EXISTS (SELECT 1 FROM [#SessionIdFilter])
               OR EXISTS
                  (SELECT 1 FROM [#SessionIdFilter] AS [f] WHERE [f].[SessionId] = [r].[session_id]))
          AND (@AktuelleSessionEinbeziehen = 1 OR [r].[session_id] <> @@SPID)
          AND (@SystemSessionsEinbeziehen = 1 OR [s].[is_user_process] = 1)
          AND
          (
              @EigeneSessionsModus = 'ALLE'
              OR (@EigeneSessionsModus = 'NUR' AND [s].[original_login_name] = ORIGINAL_LOGIN())
              OR (@EigeneSessionsModus = 'AUSSCHLIESSEN' AND ISNULL([s].[original_login_name], N'') <> ORIGINAL_LOGIN())
          )
          AND (@NurBlockierte = 0 OR [r].[blocking_session_id] <> 0)
          AND (@NurMitWait = 0 OR [r].[wait_type] IS NOT NULL OR [wt].[WaitingTaskCount] > 0)
          AND (@MinLaufzeitSekunden IS NULL OR [r].[total_elapsed_time] >= @MinLaufzeitSekunden * 1000)
          AND (@MinCpuMs IS NULL OR [r].[cpu_time] >= @MinCpuMs)
          AND (@MinLogicalReads IS NULL OR [r].[logical_reads] >= @MinLogicalReads)
          AND
          (
              NOT EXISTS (SELECT 1 FROM [#StringFilter] WHERE [FilterType] = 'LOGIN')
              OR EXISTS
                 (
                     SELECT 1
                     FROM [#StringFilter] AS [f]
                     WHERE [f].[FilterType] = 'LOGIN'
                       AND [f].[StringValue] = [s].[login_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                 )
          )
          AND
          (
              NOT EXISTS (SELECT 1 FROM [#StringFilter] WHERE [FilterType] = 'HOST')
              OR EXISTS
                 (
                     SELECT 1
                     FROM [#StringFilter] AS [f]
                     WHERE [f].[FilterType] = 'HOST'
                       AND [f].[StringValue] = [s].[host_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                 )
          )
          AND
          (
              NOT EXISTS (SELECT 1 FROM [#StringFilter] WHERE [FilterType] = 'PROGRAM')
              OR EXISTS
                 (
                     SELECT 1
                     FROM [#StringFilter] AS [f]
                     WHERE [f].[FilterType] = 'PROGRAM'
                       AND [f].[StringValue] = [s].[program_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                 )
          )
          AND
          (
              NOT EXISTS (SELECT 1 FROM [#StringFilter] WHERE [FilterType] = 'DATABASE')
              OR EXISTS
                 (
                     SELECT 1
                     FROM [#StringFilter] AS [f]
                     WHERE [f].[FilterType] = 'DATABASE'
                       AND [f].[StringValue] = [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
                 )
          )
          AND (@LoginMode <> 'LIKE' OR [s].[login_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @LoginPattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@HostMode <> 'LIKE' OR [s].[host_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @HostPattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@ProgramMode <> 'LIKE' OR [s].[program_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @ProgramPattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND (@DatabaseMode <> 'LIKE' OR [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @DatabasePattern COLLATE SQL_Latin1_General_CP1_CS_AS)
          AND
          (
              @TextMode <> 'LIKE'
              OR [st].[StatementText] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @TextPatternValue COLLATE SQL_Latin1_General_CP1_CS_AS
              OR [txt].[text] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE @TextPatternValue COLLATE SQL_Latin1_General_CP1_CS_AS
          )
        ORDER BY
              CASE
                  WHEN @Sortierung = 'RELEVANZ'
                      THEN CASE
                               WHEN [r].[blocking_session_id] <> 0 THEN 3
                               WHEN [r].[wait_type] IS NOT NULL THEN 2
                               ELSE 1
                           END
              END DESC
            , CASE WHEN @Sortierung = 'CPU' THEN [r].[cpu_time] END DESC
            , CASE WHEN @Sortierung = 'READS' THEN [r].[logical_reads] END DESC
            , CASE WHEN @Sortierung = 'DAUER' THEN [r].[total_elapsed_time] END DESC
            , [r].[session_id]
            , [r].[request_id];

        IF @HasRegex = 1
        BEGIN
            DECLARE @Sql nvarchar(max) = N'';

            IF @LoginMode IN ('REGEX', 'REGEXI')
                SET @Sql += N'DELETE FROM [#Result] WHERE [LoginName] IS NULL OR NOT REGEXP_LIKE([LoginName],@LoginPattern,@LoginFlags);';
            IF @HostMode IN ('REGEX', 'REGEXI')
                SET @Sql += N'DELETE FROM [#Result] WHERE [HostName] IS NULL OR NOT REGEXP_LIKE([HostName],@HostPattern,@HostFlags);';
            IF @ProgramMode IN ('REGEX', 'REGEXI')
                SET @Sql += N'DELETE FROM [#Result] WHERE [ProgramName] IS NULL OR NOT REGEXP_LIKE([ProgramName],@ProgramPattern,@ProgramFlags);';
            IF @DatabaseMode IN ('REGEX', 'REGEXI')
                SET @Sql += N'DELETE FROM [#Result] WHERE [DatabaseName] IS NULL OR NOT REGEXP_LIKE([DatabaseName],@DatabasePattern,@DatabaseFlags);';
            IF @TextMode IN ('REGEX', 'REGEXI')
                SET @Sql += N'DELETE FROM [#Result] WHERE COALESCE([CurrentStatement],[BatchText]) IS NULL OR (NOT REGEXP_LIKE(COALESCE([CurrentStatement],N''''),@TextPattern,@TextFlags) AND NOT REGEXP_LIKE(COALESCE([BatchText],N''''),@TextPattern,@TextFlags));';

            EXEC [sys].[sp_executesql]
                  @Sql
                , N'@LoginPattern nvarchar(4000),@LoginFlags varchar(8),@HostPattern nvarchar(4000),@HostFlags varchar(8),@ProgramPattern nvarchar(4000),@ProgramFlags varchar(8),@DatabasePattern nvarchar(4000),@DatabaseFlags varchar(8),@TextPattern nvarchar(4000),@TextFlags varchar(8)'
                , @LoginPattern
                , @LoginFlags
                , @HostPattern
                , @HostFlags
                , @ProgramPattern
                , @ProgramFlags
                , @DatabasePattern
                , @DatabaseFlags
                , @TextPatternValue
                , @TextFlags;
        END;

        IF @MaxZeilen IS NOT NULL AND @MaxZeilen > 0
        BEGIN
            IF (SELECT COUNT_BIG(*) FROM [#Result]) > @MaxZeilen
            BEGIN
                SET @HasMoreRows = 1;
            END;

            ;WITH [Ranked] AS
            (
                SELECT
                      [RowNumber] = ROW_NUMBER() OVER
                        (
                            ORDER BY
                                  CASE
                                      WHEN @Sortierung = 'RELEVANZ'
                                          THEN CASE
                                                   WHEN [BlockingSessionId] IS NOT NULL THEN 3
                                                   WHEN [WaitType] IS NOT NULL THEN 2
                                                   ELSE 1
                                               END
                                  END DESC
                                , CASE WHEN @Sortierung = 'CPU' THEN [CpuMs] END DESC
                                , CASE WHEN @Sortierung = 'READS' THEN [LogicalReads] END DESC
                                , CASE WHEN @Sortierung = 'DAUER' THEN [ElapsedMs] END DESC
                                , [SessionId]
                                , [RequestId]
                        )
                    , *
                FROM [#Result]
            )
            DELETE FROM [Ranked]
            WHERE [RowNumber] > @MaxZeilen;
        END;


        IF @ModulInfoEinbeziehen = 1
        BEGIN
            CREATE TABLE [#ModuleLookup]
            (
                  [SqlTextDatabaseId] int NOT NULL
                , [SqlTextObjectId] int NOT NULL
                , [ModuleDatabaseName] sysname NULL
                , [ModuleSchemaName] sysname NULL
                , [ModuleObjectName] sysname NULL
                , [ModuleType] char(2) NULL
                , [ModuleTypeDescription] nvarchar(60) NULL
                , [ModuleFullName] nvarchar(776) NULL
                , PRIMARY KEY ([SqlTextDatabaseId], [SqlTextObjectId])
            );

            INSERT [#ModuleLookup] ([SqlTextDatabaseId], [SqlTextObjectId])
            SELECT DISTINCT [SqlTextDatabaseId], [SqlTextObjectId]
            FROM [#Result]
            WHERE [SqlTextDatabaseId] IS NOT NULL
              AND [SqlTextObjectId] IS NOT NULL
              AND [SqlTextObjectId] > 0;

            DECLARE @LookupDatabaseId int;
            DECLARE @LookupDatabaseName sysname;
            DECLARE @LookupSql nvarchar(max);

            DECLARE [ModuleDatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
                SELECT DISTINCT [d].[database_id], [d].[name]
                FROM [#ModuleLookup] AS [m]
                JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
                  ON [d].[database_id] = [m].[SqlTextDatabaseId]
                WHERE [d].[state] = 0
                ORDER BY [d].[database_id];

            OPEN [ModuleDatabaseCursor];
            FETCH NEXT FROM [ModuleDatabaseCursor] INTO @LookupDatabaseId, @LookupDatabaseName;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                BEGIN TRY
                    SET @LookupSql =
                        N'USE ' + QUOTENAME(@LookupDatabaseName) + N';
                          UPDATE [m]
                          SET [ModuleDatabaseName] = @DatabaseName,
                              [ModuleSchemaName] = [s].[name],
                              [ModuleObjectName] = [o].[name],
                              [ModuleType] = [o].[type],
                              [ModuleTypeDescription] = [o].[type_desc],
                              [ModuleFullName] = QUOTENAME(@DatabaseName) + N''.'' + QUOTENAME([s].[name]) + N''.'' + QUOTENAME([o].[name])
                          FROM [#ModuleLookup] AS [m]
                          JOIN [sys].[objects] AS [o] WITH (NOLOCK)
                            ON [o].[object_id] = [m].[SqlTextObjectId]
                          JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
                            ON [s].[schema_id] = [o].[schema_id]
                          WHERE [m].[SqlTextDatabaseId] = @DatabaseId;';

                    EXEC [sys].[sp_executesql]
                          @LookupSql
                        , N'@DatabaseId int, @DatabaseName sysname'
                        , @DatabaseId = @LookupDatabaseId
                        , @DatabaseName = @LookupDatabaseName;
                END TRY
                BEGIN CATCH
                    INSERT [#Warnings]
                    (
                          [DatabaseName], [Code], [Message]
                    )
                    VALUES
                    (
                          @LookupDatabaseName
                        , CASE
                              WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371, 916) THEN 'MODULE_LOOKUP_DENIED'
                              WHEN ERROR_NUMBER() = 1222 THEN 'MODULE_LOOKUP_TIMEOUT'
                              ELSE 'MODULE_LOOKUP_FAILED'
                          END
                        , ERROR_MESSAGE()
                    );

                    SET @IsPartial = 1;
                END CATCH;

                FETCH NEXT FROM [ModuleDatabaseCursor] INTO @LookupDatabaseId, @LookupDatabaseName;
            END;

            CLOSE [ModuleDatabaseCursor];
            DEALLOCATE [ModuleDatabaseCursor];

            UPDATE [r]
            SET
                  [ModuleDatabaseName] = [m].[ModuleDatabaseName]
                , [ModuleSchemaName] = [m].[ModuleSchemaName]
                , [ModuleObjectName] = [m].[ModuleObjectName]
                , [ModuleType] = [m].[ModuleType]
                , [ModuleTypeDescription] = [m].[ModuleTypeDescription]
                , [ModuleFullName] = [m].[ModuleFullName]
            FROM [#Result] AS [r]
            JOIN [#ModuleLookup] AS [m]
              ON [m].[SqlTextDatabaseId] = [r].[SqlTextDatabaseId]
             AND [m].[SqlTextObjectId] = [r].[SqlTextObjectId];
        END;


        IF @InputBufferEinbeziehen = 1
        BEGIN
            UPDATE [r]
            SET
                  [InputBufferEventType] = [ib].[event_type]
                , [InputBufferParameterCount] = [ib].[parameters]
                , [InputBufferCharacterCount] = DATALENGTH([ib].[event_info]) / 2
                , [InputBufferText] = [ib].[event_info]
            FROM [#Result] AS [r]
            OUTER APPLY [sys].[dm_exec_input_buffer]
            (
                  [r].[SessionId]
                , [r].[RequestId]
            ) AS [ib];
        END;

        UPDATE [r]
        SET
              [CurrentStatementIsTruncated] = CONVERT
                (
                    bit,
                    CASE
                        WHEN [r].[CurrentStatement] IS NOT NULL
                         AND @MaxSqlTextZeichen IS NOT NULL
                         AND @MaxSqlTextZeichen > 0
                         AND DATALENGTH([r].[CurrentStatement]) / 2 > @MaxSqlTextZeichen
                            THEN 1
                        ELSE 0
                    END
                )
            , [BatchTextIsTruncated] = CONVERT
                (
                    bit,
                    CASE
                        WHEN [r].[BatchText] IS NOT NULL
                         AND @MaxSqlTextZeichen IS NOT NULL
                         AND @MaxSqlTextZeichen > 0
                         AND DATALENGTH([r].[BatchText]) / 2 > @MaxSqlTextZeichen
                            THEN 1
                        ELSE 0
                    END
                )
            , [InputBufferIsTruncated] = CONVERT
                (
                    bit,
                    CASE
                        WHEN [r].[InputBufferText] IS NOT NULL
                         AND @MaxSqlTextZeichen IS NOT NULL
                         AND @MaxSqlTextZeichen > 0
                         AND DATALENGTH([r].[InputBufferText]) / 2 > @MaxSqlTextZeichen
                            THEN 1
                        ELSE 0
                    END
                )
            , [CurrentStatement] =
                CASE
                    WHEN @MitSqlText = 0 THEN NULL
                    WHEN @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen = 0 THEN [r].[CurrentStatement]
                    ELSE LEFT([r].[CurrentStatement], @MaxSqlTextZeichen)
                END
            , [BatchText] =
                CASE
                    WHEN @GesamtenSqlTextEinbeziehen = 0 THEN NULL
                    WHEN @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen = 0 THEN [r].[BatchText]
                    ELSE LEFT([r].[BatchText], @MaxSqlTextZeichen)
                END
            , [InputBufferText] =
                CASE
                    WHEN @InputBufferEinbeziehen = 0 THEN NULL
                    WHEN @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen = 0 THEN [r].[InputBufferText]
                    ELSE LEFT([r].[InputBufferText], @MaxSqlTextZeichen)
                END
        FROM [#Result] AS [r];

        SELECT @RowCount = COUNT_BIG(*)
        FROM [#Result];

        IF @HasFullView = 0
        BEGIN
            SET @StatusCode = 'AVAILABLE_LIMITED';
            SET @IsPartial = 1;
            SET @Detail = N'Ohne vollständige Server-State-Berechtigung kann die Sicht eingeschränkt sein.';
        END;
        ELSE IF @IsPartial = 1
        BEGIN
            SET @StatusCode = 'PARTIAL_RESULT';
            SET @Detail = N'Requests wurden gelesen; mindestens eine optionale Modulauflösung war nicht vollständig möglich.';
        END;
        ELSE
        BEGIN
            SET @Detail = N'Aktive Requests mit Statement-Offset-, Modul- und SQL-Text-Kontext erfolgreich gelesen.';
        END;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @IsPartial = 1;
        SET @StatusCode =
            CASE
                WHEN @ErrorNumber IN (229, 262, 297, 300, 371, 916) THEN 'DENIED_PERMISSION'
                WHEN @ErrorNumber = 1222 THEN 'TIMEOUT'
                WHEN @ErrorNumber IN (207, 208, 4121) THEN 'UNAVAILABLE_OBJECT'
                ELSE 'ERROR_HANDLED'
            END;
    END CATCH;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @MonitorPrintMessage = FORMATMESSAGE
        (
              N'WARNUNG %s: %s'
            , @StatusCode
            , COALESCE(@ErrorMessage, @Detail, N'eingeschränkte Sicht')
        );
        RAISERROR(N'%s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  @ModuleName AS [resultName]
                , 2 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @MaxZeilen AS [requestedMaxRows]
                , @RowCount AS [returnedRows]
                , @HasMoreRows AS [hasMoreRows]
                , @MitSqlText AS [statementTextIncluded]
                , @GesamtenSqlTextEinbeziehen AS [batchTextIncluded]
                , @InputBufferEinbeziehen AS [inputBufferIncluded]
                , @ModulInfoEinbeziehen AS [moduleInfoIncluded]
                , @MaxSqlTextZeichen AS [maxSqlTextCharacters]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

        DECLARE @RequestsJson nvarchar(max) =
        (
            SELECT
                  [r].[SessionId] AS [sessionId]
                , [r].[RequestId] AS [requestId]
                , [r].[RequestStatus] AS [requestStatus]
                , [r].[Command] AS [command]
                , [r].[DatabaseId] AS [databaseId]
                , [r].[DatabaseName] AS [databaseName]
                , [r].[LoginName] AS [loginName]
                , [r].[HostName] AS [hostName]
                , [r].[ProgramName] AS [programName]
                , [r].[StartTime] AS [startTime]
                , [r].[ElapsedMs] AS [elapsedMs]
                , [r].[CpuMs] AS [cpuMs]
                , [r].[LogicalReads] AS [logicalReads]
                , [r].[Writes] AS [writes]
                , [r].[BlockingSessionId] AS [blockingSessionId]
                , [r].[WaitType] AS [waitType]
                , [wi].[WaitGroup] AS [waitGroup]
                , [wi].[Severity] AS [waitSeverity]
                , [r].[WaitTimeMs] AS [waitTimeMs]
                , [r].[RequestedMemoryMb] AS [requestedMemoryMb]
                , [r].[GrantedMemoryMb] AS [grantedMemoryMb]
                , [r].[UsedMemoryMb] AS [usedMemoryMb]
                , [r].[Dop] AS [dop]
                , [r].[ParallelWorkerCount] AS [parallelWorkerCount]
                , [r].[SchedulerId] AS [schedulerId]
                , [r].[TaskAddress] AS [taskAddress]
                , [r].[NestLevel] AS [nestLevel]
                , [r].[OpenTransactionCount] AS [openTransactionCount]
                , [r].[OpenResultsetCount] AS [openResultsetCount]
                , [r].[TransactionId] AS [transactionId]
                , [r].[ConnectionId] AS [connectionId]
                , [r].[WorkloadGroupId] AS [workloadGroupId]
                , [r].[WorkloadGroupName] AS [workloadGroupName]
                , [r].[ResourcePoolId] AS [resourcePoolId]
                , [r].[ResourcePoolName] AS [resourcePoolName]
                , [r].[StatementSqlHandle] AS [statementSqlHandle]
                , [r].[StatementContextId] AS [statementContextId]
                , [r].[IsResumable] AS [isResumable]
                , [r].[ExecutingManagedCode] AS [executingManagedCode]
                , [r].[ContextInfo] AS [contextInfo]
                , [r].[ModuleFullName] AS [moduleFullName]
                , [r].[ModuleTypeDescription] AS [moduleTypeDescription]
                , [r].[ExecutionContextType] AS [executionContextType]
                , [r].[QueryHash] AS [queryHash]
                , [r].[QueryPlanHash] AS [queryPlanHash]
                , [r].[SqlHandle] AS [sqlHandle]
                , [r].[PlanHandle] AS [planHandle]
            FROM [#Result] AS [r]
            CROSS APPLY [monitor].[TVF_WaitTypeInfo]([r].[WaitType]) AS [wi]
            ORDER BY [r].[SessionId], [r].[RequestId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        DECLARE @StatementsJson nvarchar(max) =
        (
            SELECT
                  [r].[SessionId] AS [sessionId]
                , [r].[RequestId] AS [requestId]
                , [r].[ModuleFullName] AS [moduleFullName]
                , [r].[HasStatementOffsets] AS [hasStatementOffsets]
                , [r].[IsStatementOffsetValid] AS [isStatementOffsetValid]
                , [r].[StatementStartOffsetBytes] AS [startOffsetBytes]
                , [r].[StatementEndOffsetBytes] AS [endOffsetBytes]
                , [r].[StatementStartCharacter] AS [startCharacter]
                , [r].[StatementEndCharacter] AS [endCharacter]
                , [r].[StatementStartLine] AS [startLine]
                , [r].[StatementEndLine] AS [endLine]
                , [r].[CurrentStatementCharacterCount] AS [characterCount]
                , [r].[CurrentStatementIsTruncated] AS [isTruncated]
                , [r].[CurrentStatement] AS [text]
            FROM [#Result] AS [r]
            WHERE [r].[CurrentStatement] IS NOT NULL
            ORDER BY [r].[SessionId], [r].[RequestId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        DECLARE @BatchesJson nvarchar(max) =
        (
            SELECT
                  [r].[SessionId] AS [sessionId]
                , [r].[RequestId] AS [requestId]
                , [r].[ModuleFullName] AS [moduleFullName]
                , [r].[SqlTextDatabaseId] AS [sqlTextDatabaseId]
                , [r].[SqlTextObjectId] AS [sqlTextObjectId]
                , [r].[SqlTextObjectNumber] AS [sqlTextObjectNumber]
                , [r].[SqlTextIsEncrypted] AS [isEncrypted]
                , [r].[BatchTextCharacterCount] AS [characterCount]
                , [r].[BatchTextIsTruncated] AS [isTruncated]
                , [r].[BatchText] AS [text]
            FROM [#Result] AS [r]
            WHERE [r].[BatchText] IS NOT NULL
            ORDER BY [r].[SessionId], [r].[RequestId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        DECLARE @InputBuffersJson nvarchar(max) =
        (
            SELECT
                  [r].[SessionId] AS [sessionId]
                , [r].[RequestId] AS [requestId]
                , [r].[InputBufferEventType] AS [eventType]
                , [r].[InputBufferParameterCount] AS [parameterCount]
                , [r].[InputBufferCharacterCount] AS [characterCount]
                , [r].[InputBufferIsTruncated] AS [isTruncated]
                , [r].[InputBufferText] AS [text]
            FROM [#Result] AS [r]
            WHERE [r].[InputBufferText] IS NOT NULL
            ORDER BY [r].[SessionId], [r].[RequestId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        DECLARE @WarningsJson nvarchar(max) =
        (
            SELECT
                  [w].[SessionId] AS [sessionId]
                , [w].[RequestId] AS [requestId]
                , [w].[DatabaseName] AS [databaseName]
                , [w].[Code] AS [code]
                , [w].[Message] AS [message]
            FROM [#Warnings] AS [w]
            ORDER BY [w].[WarningId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"requests":', COALESCE(@RequestsJson, N'[]')
            , N',"statements":', COALESCE(@StatementsJson, N'[]')
            , N',"batches":', COALESCE(@BatchesJson, N'[]')
            , N',"inputBuffers":', COALESCE(@InputBuffersJson, N'[]')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]')
            , N'}'
        );
    END;

    IF @ResultSetArtNormalisiert = 'RAW'
    BEGIN
        SELECT
              @ModuleName AS [ModuleName]
            , @CollectionTimeUtc AS [CollectionTimeUtc]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @RowCount AS [RowCount]
            , @MaxZeilen AS [RequestedMaxRows]
            , @HasMoreRows AS [HasMoreRows]
            , @RequiredPermission AS [RequiredPermission]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage]
            , @Detail AS [Detail];

        SELECT
              [r].*
            , [wi].[WaitGroup]
            , [wi].[Severity] AS [WaitSeverity]
            , [wi].[IsGenerallyBenign]
            , [wi].[Meaning] AS [WaitMeaning]
            , [wi].[TypicalOccurrence] AS [WaitTypicalOccurrence]
            , [wi].[HighWaitImpact]
            , [wi].[RecommendedChecks]
            , [wi].[HelpUrl] AS [WaitHelpUrl]
            , [wi].[InterpretationScope]
            , [wi].[CatalogMatchType]
            , [lwi].[WaitGroup] AS [LastWaitGroup]
            , [lwi].[Meaning] AS [LastWaitMeaning]
        FROM [#Result] AS [r]
        CROSS APPLY [monitor].[TVF_WaitTypeInfo]([r].[WaitType]) AS [wi]
        CROSS APPLY [monitor].[TVF_WaitTypeInfo]([r].[LastWaitType]) AS [lwi]
        ORDER BY
              CASE WHEN @Sortierung = 'CPU' THEN [r].[CpuMs] END DESC
            , CASE WHEN @Sortierung = 'READS' THEN [r].[LogicalReads] END DESC
            , CASE WHEN @Sortierung = 'DAUER' THEN [r].[ElapsedMs] END DESC
            , CASE
                  WHEN @Sortierung = 'RELEVANZ'
                      THEN CASE
                               WHEN [r].[BlockingSessionId] IS NOT NULL THEN 3
                               WHEN [r].[WaitType] IS NOT NULL THEN 2
                               ELSE 1
                           END
              END DESC
            , [r].[SessionId]
            , [r].[RequestId];

        SELECT
              [w].[WarningId]
            , [w].[SessionId]
            , [w].[RequestId]
            , [w].[DatabaseName]
            , [w].[Code]
            , [w].[Message]
        FROM [#Warnings] AS [w]
        ORDER BY [w].[WarningId];
    END
    ELSE IF @ResultSetArtNormalisiert = 'CONSOLE'
    BEGIN
        SELECT
              N'Modulstatus' AS [Ergebnis]
            , @ModuleName AS [Modul]
            , @StatusCode AS [Status]
            , @RowCount AS [Zeilen]
            , @Detail AS [Hinweis]
            , @ErrorMessage AS [Fehler];

        SELECT
              N'Aktiver Request' AS [Ergebnis]
            , [r].[SessionId] AS [Session]
            , [r].[RequestId] AS [Request]
            , COALESCE([r].[ModuleFullName], N'Ad-hoc/Prepared Batch') AS [Ausfuehrung]
            , [r].[ModuleTypeDescription] AS [Modultyp]
            , [r].[LoginName] AS [Login]
            , [r].[HostName] AS [Host]
            , [r].[ProgramName] AS [Programm]
            , [r].[DatabaseName] AS [Datenbank]
            , [r].[Command] AS [Befehl]
            , [r].[RequestStatus] AS [Status]
            , CONCAT(CONVERT(decimal(19,2), [r].[ElapsedMs] / 1000.0), N' s') AS [Laufzeit]
            , [r].[CpuMs] AS [CPU_ms]
            , [r].[LogicalReads] AS [Logical_Reads]
            , [r].[Writes] AS [Writes]
            , [r].[SessionId] AS [Session_Wait]
            , [r].[WaitType] AS [Wait]
            , [r].[WaitTimeMs] AS [Wait_ms]
            , [r].[BlockingSessionId] AS [Blockiert_durch]
            , [r].[RequestedMemoryMb] AS [Memory_angefordert_MB]
            , [r].[GrantedMemoryMb] AS [Memory_gewaehrt_MB]
            , [r].[UsedMemoryMb] AS [Memory_verwendet_MB]
            , CASE
                  WHEN [r].[StatementStartLine] IS NULL THEN NULL
                  WHEN [r].[StatementEndLine] = [r].[StatementStartLine]
                      THEN CONVERT(varchar(20), [r].[StatementStartLine])
                  ELSE CONCAT([r].[StatementStartLine], N'-', [r].[StatementEndLine])
              END AS [Statement_Zeile]
            , CONCAT
              (
                    COALESCE(CONVERT(varchar(20), [r].[StatementStartOffsetBytes]), N'?')
                  , N'-'
                  , CASE
                        WHEN [r].[StatementEndOffsetBytes] = -1 THEN N'Batch-Ende'
                        ELSE COALESCE(CONVERT(varchar(20), [r].[StatementEndOffsetBytes]), N'?')
                    END
              ) AS [Statement_Offset_Bytes]
            , [r].[CurrentStatementIsTruncated] AS [Statement_gekuerzt]
            , [r].[CurrentStatement] AS [Aktuelles_Statement]
        FROM [#Result] AS [r]
        ORDER BY
              CASE
                  WHEN @Sortierung = 'RELEVANZ'
                      THEN CASE
                               WHEN [r].[BlockingSessionId] IS NOT NULL THEN 3
                               WHEN [r].[WaitType] IS NOT NULL THEN 2
                               ELSE 1
                           END
              END DESC
            , CASE WHEN @Sortierung = 'CPU' THEN [r].[CpuMs] END DESC
            , CASE WHEN @Sortierung = 'READS' THEN [r].[LogicalReads] END DESC
            , CASE WHEN @Sortierung = 'DAUER' THEN [r].[ElapsedMs] END DESC
            , [r].[SessionId]
            , [r].[RequestId];

        SELECT
              N'SQL-Kontext' AS [Ergebnis]
            , [r].[SessionId] AS [Session]
            , [r].[RequestId] AS [Request]
            , [r].[ExecutionContextType] AS [Kontextart]
            , [r].[ModuleFullName] AS [Modul]
            , [r].[ModuleTypeDescription] AS [Modultyp]
            , [r].[NestLevel] AS [Verschachtelungsebene]
            , [r].[ConnectionId] AS [ConnectionId]
            , [r].[TransactionId] AS [TransactionId]
            , [r].[SchedulerId] AS [SchedulerId]
            , [r].[TaskAddress] AS [TaskAddress]
            , [r].[WorkloadGroupId] AS [WorkloadGroupId]
            , [r].[WorkloadGroupName] AS [WorkloadGroup]
            , [r].[ResourcePoolId] AS [ResourcePoolId]
            , [r].[ResourcePoolName] AS [ResourcePool]
            , [r].[StatementSqlHandle] AS [StatementSqlHandle]
            , [r].[StatementContextId] AS [StatementContextId]
            , [r].[IsResumable] AS [Ist_fortsetzbar]
            , [r].[ExecutingManagedCode] AS [Fuehrt_CLR_aus]
            , [r].[ContextInfo] AS [ContextInfo]
            , [r].[SqlTextDatabaseId] AS [SQLText_DatabaseId]
            , [r].[SqlTextObjectId] AS [SQLText_ObjectId]
            , [r].[SqlTextObjectNumber] AS [SQLText_ObjectNumber]
            , [r].[SqlTextIsEncrypted] AS [SQLText_verschluesselt]
            , [r].[HasStatementOffsets] AS [Offsets_vorhanden]
            , [r].[IsStatementOffsetValid] AS [Offsets_gueltig]
            , [r].[StatementStartOffsetBytes] AS [Statement_Start_Byte]
            , [r].[StatementEndOffsetBytes] AS [Statement_Ende_Byte]
            , [r].[StatementStartCharacter] AS [Statement_Start_Zeichen]
            , [r].[StatementEndCharacter] AS [Statement_Ende_Zeichen]
            , [r].[StatementStartLine] AS [Statement_Start_Zeile]
            , [r].[StatementEndLine] AS [Statement_Ende_Zeile]
            , [r].[CurrentStatementCharacterCount] AS [Statement_Zeichen]
            , [r].[BatchTextCharacterCount] AS [Batch_Zeichen]
            , [r].[QueryHash] AS [QueryHash]
            , [r].[QueryPlanHash] AS [QueryPlanHash]
            , [r].[SqlHandle] AS [SqlHandle]
            , [r].[PlanHandle] AS [PlanHandle]
        FROM [#Result] AS [r]
        ORDER BY [r].[SessionId], [r].[RequestId];

        IF @GesamtenSqlTextEinbeziehen = 1
        BEGIN
            SELECT
                  N'Gesamter SQL-Batch/Modultext' AS [Ergebnis]
                , [r].[SessionId] AS [Session]
                , [r].[RequestId] AS [Request]
                , COALESCE([r].[ModuleFullName], N'Ad-hoc/Prepared Batch') AS [Ausfuehrung]
                , [r].[BatchTextCharacterCount] AS [Zeichen_gesamt]
                , [r].[BatchTextIsTruncated] AS [Text_gekuerzt]
                , [r].[BatchText] AS [Gesamter_SQL_Text]
            FROM [#Result] AS [r]
            WHERE [r].[BatchText] IS NOT NULL
            ORDER BY [r].[SessionId], [r].[RequestId];
        END;

        IF @InputBufferEinbeziehen = 1
        BEGIN
            SELECT
                  N'Input Buffer' AS [Ergebnis]
                , [r].[SessionId] AS [Session]
                , [r].[RequestId] AS [Request]
                , [r].[InputBufferEventType] AS [Ereignistyp]
                , [r].[InputBufferParameterCount] AS [Parameteranzahl]
                , [r].[InputBufferCharacterCount] AS [Zeichen_gesamt]
                , [r].[InputBufferIsTruncated] AS [Text_gekuerzt]
                , [r].[InputBufferText] AS [Uebergebener_Befehl]
            FROM [#Result] AS [r]
            WHERE [r].[InputBufferText] IS NOT NULL
            ORDER BY [r].[SessionId], [r].[RequestId];
        END;

        IF EXISTS (SELECT 1 FROM [#Warnings])
        BEGIN
            SELECT
                  N'Warnung' AS [Ergebnis]
                , [w].[SessionId] AS [Session]
                , [w].[RequestId] AS [Request]
                , [w].[DatabaseName] AS [Datenbank]
                , [w].[Code] AS [Code]
                , [w].[Message] AS [Hinweis]
            FROM [#Warnings] AS [w]
            ORDER BY [w].[WarningId];
        END;
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#Result'
            , @ResultTable = @ResultTable
            , @ThrowOnError = 1;
    END;
END;
GO
