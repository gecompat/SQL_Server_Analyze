USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentBlocking
Version      : 2.0.1
Stand        : 2026-07-16
Typ          : Stored Procedure
Zweck        : Ermittelt aktuelle Blocking-Ketten sowie optional die zugehörigen
               Locks. Sessionfilter unterstützen bracket-aware Pipe-Listen.
SQL-Version  : SQL Server 2019 oder neuer.
Parameter    : @SessionIds = NULL oder z. B. N'57|61'; @MaxZeilen > 0
               begrenzt, NULL/0 ist unbegrenzt. @ResultSetArt akzeptiert
               RAW, CONSOLE, TABLE oder NONE case-insensitiv. JSON wird als Envelope
               mit blockingChains, locks und warnings geliefert.
Berechtigung : VIEW SERVER STATE bis SQL Server 2019 beziehungsweise
               VIEW SERVER PERFORMANCE STATE ab SQL Server 2022. Lockdetails
               benötigen zusätzlich die freigegebene Analyseklasse LOCKS_DEEP.
Eigenlast    : Standard gering. sys.dm_tran_locks wird nur bei expliziter
               Anforderung und nur für beteiligte Sessions gelesen.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentBlocking]
      @SessionIds                 nvarchar(max)  = NULL
    , @MinWaitMs                  bigint         = 0
    , @SystemSessionsEinbeziehen  bit            = 0
    , @MitSqlText                 bit            = 1
    , @MaxSqlTextZeichen          int            = 3000
    , @MitLockDetails             bit            = 0
    , @MaxZeilen                  int            = 1000
    , @ResultSetArt               varchar(16)     = 'CONSOLE'
    , @ResultTable                     sysname        = NULL
    , @JsonErzeugen               bit             = 0
    , @Json                       nvarchar(max)   = NULL OUTPUT
    , @PrintMeldungen             bit             = 1
    , @Hilfe                      bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    IF @TableResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @EffectiveMaxZeilen bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint, 9223372036854775807)
             WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen)
             ELSE CONVERT(bigint, 0) END;
    DECLARE @CandidateRows bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint, 9223372036854775807)
             WHEN @MaxZeilen < 2147483647 THEN CONVERT(bigint, @MaxZeilen) + 1
             ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentBlocking';
        PRINT N'@SessionIds: exakte Session-IDs als Pipe-Liste, z. B. N''57|61''; NULL = keine Einschränkung.';
        PRINT N'@MitLockDetails=1 aktiviert die gruppengeschützte LOCKS_DEEP-Auswertung.';
        PRINT N'@MaxZeilen: positive Werte begrenzen; NULL/0 = unbegrenzt; negative Werte sind ungültig.';
        PRINT N'@ResultSetArt: CONSOLE (Default), RAW, TABLE oder NONE; Groß-/Kleinschreibung wird ignoriert.';
        PRINT N'@JsonErzeugen=1 liefert blockingChains, locks und warnings in @Json OUTPUT.';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @RequiredPermission nvarchar(256) =
        CASE WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16
             THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END;
    DECLARE @LockStatusCode varchar(40) = 'SKIPPED';
    DECLARE @MainCandidateCount bigint = 0;
    DECLARE @LockCandidateCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @Message nvarchar(2048);

    CREATE TABLE [#SessionFilter]
    (
        [SessionId] smallint NOT NULL PRIMARY KEY
    );

    CREATE TABLE [#Edges]
    (
          [BlockedSessionId]  smallint      NOT NULL
        , [BlockingSessionId] smallint      NOT NULL
        , [WaitType]          nvarchar(120) NULL
        , [WaitTimeMs]        bigint        NULL
        , [WaitResource]      nvarchar(3072) NULL
        , [SourceCode]        varchar(24)   NOT NULL
        , PRIMARY KEY ([BlockedSessionId], [BlockingSessionId])
    );

    CREATE TABLE [#BlockingChains]
    (
          [LeafSessionId]         smallint       NOT NULL
        , [BlockedSessionId]      smallint       NOT NULL
        , [BlockingSessionId]     smallint       NOT NULL
        , [RootBlockingSessionId] smallint       NULL
        , [ChainDepth]            int            NOT NULL
        , [IsCycle]               bit            NOT NULL
        , [WaitType]              nvarchar(120)  NULL
        , [WaitTimeMs]            bigint         NULL
        , [WaitResource]          nvarchar(3072) NULL
        , [BlockedLoginName]      nvarchar(128)  NULL
        , [BlockedHostName]       nvarchar(128)  NULL
        , [BlockedProgramName]    nvarchar(128)  NULL
        , [BlockerLoginName]      nvarchar(128)  NULL
        , [BlockerHostName]       nvarchar(128)  NULL
        , [BlockerProgramName]    nvarchar(128)  NULL
        , [BlockedStatement]      nvarchar(max)  NULL
        , [BlockerStatement]      nvarchar(max)  NULL
    );

    CREATE TABLE [#Locks]
    (
          [SessionId]             smallint       NULL
        , [ResourceType]          nvarchar(60)   NULL
        , [ResourceDatabaseId]    int            NULL
        , [ResourceDatabaseName]  sysname        NULL
        , [ResourceDescription]   nvarchar(256)  NULL
        , [RequestMode]           nvarchar(60)   NULL
        , [RequestStatus]         nvarchar(60)   NULL
        , [RequestOwnerType]      nvarchar(60)   NULL
        , [RequestReferenceCount] smallint       NULL
        , [LockOwnerAddress]      varbinary(8)   NULL
    );

    CREATE TABLE [#Warnings]
    (
          [ScopeName]    nvarchar(128)  NULL
        , [StatusCode]   varchar(40)    NOT NULL
        , [ErrorNumber]  int            NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    IF @SessionIds IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            WHERE [IsValid] = 0 OR [NumberValue] NOT BETWEEN 0 AND 32767
        )
        OR EXISTS
        (
            SELECT [NumberValue]
            FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            WHERE [IsValid] = 1
            GROUP BY [NumberValue]
            HAVING COUNT(*) > 1
        )
        BEGIN
            SET @StatusCode = 'INVALID_PARAMETER';
            SET @ErrorMessage = N'@SessionIds enthält ungültige, doppelte oder außerhalb des smallint-Bereichs liegende Werte.';
        END;
        ELSE
        BEGIN
            INSERT [#SessionFilter]([SessionId])
            SELECT CONVERT(smallint, [NumberValue])
            FROM [monitor].[TVF_ParseBigintList](@SessionIds)
            WHERE [IsValid] = 1;
        END;
    END;

    IF @StatusCode = 'AVAILABLE'
       AND
       (
           COALESCE(@MinWaitMs, -1) < 0
           OR @MaxZeilen < 0
           OR @MaxSqlTextZeichen < 0
           OR @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
           OR @JsonErzeugen IS NULL
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens ein Parameter besitzt einen ungültigen Wert.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#Edges]
        (
              [BlockedSessionId], [BlockingSessionId], [WaitType]
            , [WaitTimeMs], [WaitResource], [SourceCode]
        )
        SELECT
              [r].[session_id]
            , [r].[blocking_session_id]
            , MAX([r].[wait_type])
            , MAX(CONVERT(bigint, [r].[wait_time]))
            , MAX(CONVERT(nvarchar(3072), [r].[wait_resource]))
            , 'REQUEST'
        FROM [sys].[dm_exec_requests] AS [r]
        INNER JOIN [sys].[dm_exec_sessions] AS [s]
          ON [s].[session_id] = [r].[session_id]
        WHERE [r].[blocking_session_id] > 0
          AND [r].[blocking_session_id] <> [r].[session_id]
          AND (@SystemSessionsEinbeziehen = 1 OR [s].[is_user_process] = 1)
          AND COALESCE([r].[wait_time], 0) >= @MinWaitMs
          AND
          (
              @SessionIds IS NULL
              OR EXISTS
                 (
                     SELECT 1
                     FROM [#SessionFilter] AS [f]
                     WHERE [f].[SessionId] IN ([r].[session_id], [r].[blocking_session_id])
                 )
          )
        GROUP BY [r].[session_id], [r].[blocking_session_id];

        INSERT [#Edges]
        (
              [BlockedSessionId], [BlockingSessionId], [WaitType]
            , [WaitTimeMs], [WaitResource], [SourceCode]
        )
        SELECT
              [w].[session_id]
            , [w].[blocking_session_id]
            , MAX([w].[wait_type])
            , MAX(CONVERT(bigint, [w].[wait_duration_ms]))
            , MAX(CONVERT(nvarchar(3072), [w].[resource_description]))
            , 'WAITING_TASK'
        FROM [sys].[dm_os_waiting_tasks] AS [w]
        LEFT JOIN [sys].[dm_exec_sessions] AS [s]
          ON [s].[session_id] = [w].[session_id]
        WHERE [w].[blocking_session_id] > 0
          AND [w].[blocking_session_id] <> [w].[session_id]
          AND COALESCE([w].[wait_duration_ms], 0) >= @MinWaitMs
          AND (@SystemSessionsEinbeziehen = 1 OR COALESCE([s].[is_user_process], 1) = 1)
          AND
          (
              @SessionIds IS NULL
              OR EXISTS
                 (
                     SELECT 1
                     FROM [#SessionFilter] AS [f]
                     WHERE [f].[SessionId] IN ([w].[session_id], [w].[blocking_session_id])
                 )
          )
          AND NOT EXISTS
              (
                  SELECT 1
                  FROM [#Edges] AS [e]
                  WHERE [e].[BlockedSessionId] = [w].[session_id]
                    AND [e].[BlockingSessionId] = [w].[blocking_session_id]
              )
        GROUP BY [w].[session_id], [w].[blocking_session_id];

        ;WITH [Chain] AS
        (
            SELECT
                  [e].[BlockedSessionId] AS [LeafSessionId]
                , [e].[BlockedSessionId]
                , [e].[BlockingSessionId]
                , 1 AS [ChainDepth]
                , CONVERT(varchar(4000), CONCAT('|', [e].[BlockedSessionId], '|', [e].[BlockingSessionId], '|')) AS [Path]
                , CONVERT(bit, 0) AS [IsCycle]
            FROM [#Edges] AS [e]

            UNION ALL

            SELECT
                  [c].[LeafSessionId]
                , [e].[BlockedSessionId]
                , [e].[BlockingSessionId]
                , [c].[ChainDepth] + 1
                , CONVERT(varchar(4000), CONCAT([c].[Path], [e].[BlockingSessionId], '|'))
                , CONVERT
                  (
                      bit,
                      CASE WHEN [c].[Path] LIKE CONCAT('%|', [e].[BlockingSessionId], '|%')
                           THEN 1 ELSE 0 END
                  )
            FROM [Chain] AS [c]
            INNER JOIN [#Edges] AS [e]
              ON [e].[BlockedSessionId] = [c].[BlockingSessionId]
            WHERE [c].[ChainDepth] < 32
              AND [c].[IsCycle] = 0
        ),
        [Root] AS
        (
            SELECT
                  [c].*
                , ROW_NUMBER() OVER
                  (
                      PARTITION BY [c].[LeafSessionId]
                      ORDER BY [c].[ChainDepth] DESC
                  ) AS [RowNumber]
            FROM [Chain] AS [c]
        )
        INSERT [#BlockingChains]
        (
              [LeafSessionId], [BlockedSessionId], [BlockingSessionId]
            , [RootBlockingSessionId], [ChainDepth], [IsCycle]
            , [WaitType], [WaitTimeMs], [WaitResource]
            , [BlockedLoginName], [BlockedHostName], [BlockedProgramName]
            , [BlockerLoginName], [BlockerHostName], [BlockerProgramName]
            , [BlockedStatement], [BlockerStatement]
        )
        SELECT TOP (@CandidateRows)
              [r].[LeafSessionId]
            , [e].[BlockedSessionId]
            , [e].[BlockingSessionId]
            , [r].[BlockingSessionId]
            , [r].[ChainDepth]
            , [r].[IsCycle]
            , [e].[WaitType]
            , [e].[WaitTimeMs]
            , [e].[WaitResource]
            , [blockedSession].[login_name]
            , [blockedSession].[host_name]
            , [blockedSession].[program_name]
            , [blockerSession].[login_name]
            , [blockerSession].[host_name]
            , [blockerSession].[program_name]
            , CASE WHEN @MitSqlText = 1 THEN CASE WHEN @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen = 0 THEN [blockedStatement].[StatementText] ELSE LEFT([blockedStatement].[StatementText], @MaxSqlTextZeichen) END END
            , CASE WHEN @MitSqlText = 1 THEN CASE WHEN @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen = 0 THEN [blockerStatement].[StatementText] ELSE LEFT([blockerStatement].[StatementText], @MaxSqlTextZeichen) END END
        FROM [Root] AS [r]
        INNER JOIN [#Edges] AS [e]
          ON [e].[BlockedSessionId] = [r].[LeafSessionId]
        LEFT JOIN [sys].[dm_exec_sessions] AS [blockedSession]
          ON [blockedSession].[session_id] = [e].[BlockedSessionId]
        LEFT JOIN [sys].[dm_exec_sessions] AS [blockerSession]
          ON [blockerSession].[session_id] = [e].[BlockingSessionId]
        LEFT JOIN [sys].[dm_exec_requests] AS [blockedRequest]
          ON [blockedRequest].[session_id] = [e].[BlockedSessionId]
        LEFT JOIN [sys].[dm_exec_requests] AS [blockerRequest]
          ON [blockerRequest].[session_id] = [e].[BlockingSessionId]
        OUTER APPLY [sys].[dm_exec_sql_text]
        (
            CASE WHEN @MitSqlText = 1 THEN [blockedRequest].[sql_handle] END
        ) AS [blockedText]
        OUTER APPLY [monitor].[TVF_StatementText]
        (
              [blockedText].[text]
            , [blockedRequest].[statement_start_offset]
            , [blockedRequest].[statement_end_offset]
        ) AS [blockedStatement]
        OUTER APPLY [sys].[dm_exec_sql_text]
        (
            CASE WHEN @MitSqlText = 1 THEN [blockerRequest].[sql_handle] END
        ) AS [blockerText]
        OUTER APPLY [monitor].[TVF_StatementText]
        (
              [blockerText].[text]
            , [blockerRequest].[statement_start_offset]
            , [blockerRequest].[statement_end_offset]
        ) AS [blockerStatement]
        WHERE [r].[RowNumber] = 1
        ORDER BY [e].[WaitTimeMs] DESC, [e].[BlockedSessionId]
        OPTION (MAXRECURSION 32);

        SELECT @MainCandidateCount = COUNT_BIG(*) FROM [#BlockingChains];
        SET @HasMoreRows = CONVERT
        (
            bit,
            CASE WHEN @EffectiveMaxZeilen < 9223372036854775807
                       AND @MainCandidateCount > @EffectiveMaxZeilen
                 THEN 1 ELSE 0 END
        );

        IF @MitLockDetails = 1
        BEGIN
            DECLARE @LockAllowed bit = 0;
            SELECT @LockAllowed = COALESCE(MAX(CONVERT(tinyint, [IsAllowed])), 0)
            FROM [monitor].[VW_AnalyseAccessCurrent]
            WHERE [AnalysisClass] = 'LOCKS_DEEP';

            IF @LockAllowed = 0
            BEGIN
                SET @LockStatusCode = 'DENIED_GROUP';
                SET @IsPartial = 1;
                INSERT [#Warnings]([ScopeName], [StatusCode], [ErrorMessage])
                VALUES (N'Locks', 'DENIED_GROUP', N'Die Analyseklasse LOCKS_DEEP ist nicht freigegeben.');
            END;
            ELSE
            BEGIN TRY
                INSERT [#Locks]
                (
                      [SessionId], [ResourceType], [ResourceDatabaseId]
                    , [ResourceDatabaseName], [ResourceDescription]
                    , [RequestMode], [RequestStatus], [RequestOwnerType]
                    , [RequestReferenceCount], [LockOwnerAddress]
                )
                SELECT TOP (@CandidateRows)
                      CONVERT(smallint, [l].[request_session_id])
                    , [l].[resource_type]
                    , [l].[resource_database_id]
                    , [d].[name]
                    , [l].[resource_description]
                    , [l].[request_mode]
                    , [l].[request_status]
                    , [l].[request_owner_type]
                    , [l].[request_reference_count]
                    , [l].[lock_owner_address]
                FROM [sys].[dm_tran_locks] AS [l]
                LEFT JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
                  ON [d].[database_id] = [l].[resource_database_id]
                WHERE EXISTS
                      (
                          SELECT 1
                          FROM [#Edges] AS [e]
                          WHERE [e].[BlockedSessionId] = [l].[request_session_id]
                             OR [e].[BlockingSessionId] = [l].[request_session_id]
                      )
                ORDER BY
                      [l].[request_session_id]
                    , [l].[resource_database_id]
                    , [l].[resource_type]
                    , [l].[request_mode];

                SELECT @LockCandidateCount = COUNT_BIG(*) FROM [#Locks];
                SET @LockStatusCode = 'AVAILABLE';
            END TRY
            BEGIN CATCH
                SET @LockStatusCode = CASE WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371, 916)
                                           THEN 'DENIED_PERMISSION'
                                           WHEN ERROR_NUMBER() = 1222 THEN 'TIMEOUT'
                                           ELSE 'ERROR_HANDLED' END;
                SET @IsPartial = 1;
                INSERT [#Warnings]([ScopeName], [StatusCode], [ErrorNumber], [ErrorMessage])
                VALUES (N'Locks', @LockStatusCode, ERROR_NUMBER(), ERROR_MESSAGE());
            END CATCH;
        END;
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @IsPartial = 1;
        SET @StatusCode = CASE WHEN @ErrorNumber IN (229, 262, 297, 300, 371, 916)
                               THEN 'DENIED_PERMISSION'
                               WHEN @ErrorNumber = 1222 THEN 'TIMEOUT'
                               ELSE 'ERROR_HANDLED' END;
    END CATCH;

    IF @IsPartial = 1 AND @StatusCode = 'AVAILABLE'
        SET @StatusCode = 'AVAILABLE_LIMITED';

    IF @PrintMeldungen = 1 AND @StatusCode NOT IN ('AVAILABLE', 'AVAILABLE_LIMITED')
    BEGIN
        SET @Message = FORMATMESSAGE(N'WARNUNG USP_CurrentBlocking [%s]: %s', @StatusCode, COALESCE(@ErrorMessage, N'Unbekannter Fehler.'));
        RAISERROR(N'%s', 10, 1, @Message) WITH NOWAIT;
    END;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              N'USP_CurrentBlocking' AS [ModuleName]
            , @CollectionTimeUtc AS [CollectionTimeUtc]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , CASE WHEN @MainCandidateCount > @EffectiveMaxZeilen
                   THEN @EffectiveMaxZeilen ELSE @MainCandidateCount END AS [ReturnedRowCount]
            , @HasMoreRows AS [HasMoreRows]
            , @LockStatusCode AS [LockStatusCode]
            , @RequiredPermission AS [RequiredPermission]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT TOP (@EffectiveMaxZeilen)
                  [LeafSessionId], [BlockedSessionId], [BlockingSessionId]
                , [RootBlockingSessionId], [ChainDepth], [IsCycle]
                , [WaitType], [WaitTimeMs], [WaitResource]
                , [BlockedLoginName], [BlockedHostName], [BlockedProgramName]
                , [BlockerLoginName], [BlockerHostName], [BlockerProgramName]
                , [BlockedStatement], [BlockerStatement]
            FROM [#BlockingChains]
            ORDER BY [WaitTimeMs] DESC, [BlockedSessionId];

            IF @MitLockDetails = 1
            BEGIN
                SELECT TOP (@EffectiveMaxZeilen)
                      [SessionId], [ResourceType], [ResourceDatabaseId]
                    , [ResourceDatabaseName], [ResourceDescription]
                    , [RequestMode], [RequestStatus], [RequestOwnerType]
                    , [RequestReferenceCount], [LockOwnerAddress]
                FROM [#Locks]
                ORDER BY [SessionId], [ResourceDatabaseId], [ResourceType], [RequestMode];
            END;
        END
        ELSE
        BEGIN
            SELECT TOP (@EffectiveMaxZeilen)
                  N'Blocking-Kette' AS [Ergebnis]
                , [BlockedSessionId] AS [Blockierte Session]
                , [BlockingSessionId] AS [Blockierende Session]
                , [RootBlockingSessionId] AS [Root Blocker]
                , [ChainDepth] AS [Kettentiefe]
                , CASE WHEN [IsCycle] = 1 THEN N'Ja' ELSE N'Nein' END AS [Zyklus]
                , [WaitType] AS [Wait]
                , CONCAT(CONVERT(varchar(30), [WaitTimeMs]), N' ms') AS [Wartezeit]
                , [WaitResource] AS [Wait-Ressource]
                , [BlockedLoginName] AS [Blockierter Login]
                , [BlockedHostName] AS [Blockierter Host]
                , [BlockedProgramName] AS [Blockiertes Programm]
                , [BlockerLoginName] AS [Blocker Login]
                , [BlockerHostName] AS [Blocker Host]
                , [BlockerProgramName] AS [Blocker Programm]
                , [BlockedSessionId] AS [Session_SQL]
                , [BlockedStatement] AS [Blockiertes Statement]
                , [BlockerStatement] AS [Blocker Statement]
            FROM [#BlockingChains]
            ORDER BY [WaitTimeMs] DESC, [BlockedSessionId];

            IF @MitLockDetails = 1
            BEGIN
                SELECT TOP (@EffectiveMaxZeilen)
                      N'Lock der Blocking-Kette' AS [Ergebnis]
                    , [SessionId] AS [Session]
                    , [ResourceDatabaseName] AS [Datenbank]
                    , [ResourceType] AS [Ressourcentyp]
                    , [ResourceDescription] AS [Ressource]
                    , [RequestMode] AS [Lock-Modus]
                    , [RequestStatus] AS [Status]
                    , [RequestOwnerType] AS [Owner]
                    , [RequestReferenceCount] AS [Referenzen]
                FROM [#Locks]
                ORDER BY [SessionId], [ResourceDatabaseId], [ResourceType], [RequestMode];
            END;
        END;

        SELECT [ScopeName], [StatusCode], [ErrorNumber], [ErrorMessage]
        FROM [#Warnings]
        ORDER BY [ScopeName], [StatusCode];
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'CurrentBlocking' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @MaxZeilen AS [requestedMaxRows]
                , CASE WHEN @MainCandidateCount > @EffectiveMaxZeilen
                       THEN @EffectiveMaxZeilen ELSE @MainCandidateCount END AS [returnedRows]
                , @HasMoreRows AS [hasMoreRows]
                , @LockStatusCode AS [lockStatusCode]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @ChainsJson nvarchar(max) =
        (
            SELECT TOP (@EffectiveMaxZeilen) *
            FROM [#BlockingChains]
            ORDER BY [WaitTimeMs] DESC, [BlockedSessionId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        DECLARE @LocksJson nvarchar(max) =
        (
            SELECT TOP (@EffectiveMaxZeilen) *
            FROM [#Locks]
            ORDER BY [SessionId], [ResourceDatabaseId], [ResourceType], [RequestMode]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        DECLARE @WarningsJson nvarchar(max) =
        (
            SELECT *
            FROM [#Warnings]
            ORDER BY [ScopeName], [StatusCode]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"blockingChains":', COALESCE(@ChainsJson, N'[]')
            , N',"locks":', COALESCE(@LocksJson, N'[]')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]')
            , N'}'
        );
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#BlockingChains'
            , @ResultTable = @ResultTable
            , @ThrowOnError = 1;
    END;
END;
GO
