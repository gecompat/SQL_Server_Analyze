USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CurrentTransactions
Version      : 2.0.1
Stand        : 2026-07-16
Zweck        : Zeigt aktive Transaktionen einschließlich Session-, Request- und
               Logverbrauchsinformationen. Unterstützt Sessionlisten sowie
               RAW-, CONSOLE- und JSON-Ausgabe.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentTransactions]
      @SessionIds                 nvarchar(max) = NULL
    , @MinAlterSekunden           int           = 0
    , @NurSleeping                bit           = 0
    , @SystemSessionsEinbeziehen  bit           = 0
    , @MitSqlText                 bit           = 1
    , @MaxSqlTextZeichen          int           = 3000
    , @MaxZeilen                  int           = 1000
    , @ResultSetArt               varchar(16)    = 'CONSOLE'
    , @JsonErzeugen               bit            = 0
    , @Json                       nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen             bit            = 1
    , @Hilfe                      bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint, 9223372036854775807)
                                 WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen) ELSE 0 END;
    DECLARE @Candidates bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN CONVERT(bigint, 9223372036854775807)
                                      WHEN @MaxZeilen < 2147483647 THEN CONVERT(bigint, @MaxZeilen) + 1 ELSE CONVERT(bigint, @MaxZeilen) END;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CurrentTransactions';
        PRINT N'@SessionIds = N''57|61''; NULL = keine Einschränkung.';
        PRINT N'@MaxZeilen positiv = begrenzt, NULL/0 = unbegrenzt.';
        PRINT N'@ResultSetArt = CONSOLE (Default)|RAW|NONE; Steuerwert case-insensitiv.';
        PRINT N'@JsonErzeugen=1 liefert transactions und warnings in @Json OUTPUT.';
        RETURN;
    END;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @RowCount bigint = 0;
    DECLARE @HasMoreRows bit = 0;
    DECLARE @Message nvarchar(2048);

    CREATE TABLE [#SessionFilter]([SessionId] smallint NOT NULL PRIMARY KEY);
    CREATE TABLE [#Result]
    (
          [SessionId]                smallint       NOT NULL
        , [TransactionId]            bigint         NOT NULL
        , [TransactionBeginTimeUtc]  datetime       NULL
        , [TransactionAgeSeconds]    bigint         NULL
        , [TransactionType]          int            NULL
        , [TransactionState]         int            NULL
        , [OpenTransactionCount]     int            NULL
        , [LoginName]                nvarchar(128)  NULL
        , [HostName]                 nvarchar(128)  NULL
        , [ProgramName]              nvarchar(128)  NULL
        , [SessionStatus]            nvarchar(30)   NULL
        , [RequestStatus]            nvarchar(30)   NULL
        , [DatabaseId]               int            NULL
        , [DatabaseName]             sysname        NULL
        , [LogBytesUsed]             bigint         NULL
        , [LogBytesReserved]         bigint         NULL
        , [StatementText]            nvarchar(max)  NULL
    );
    CREATE TABLE [#Warnings]
    (
          [StatusCode] varchar(40) NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    IF @SessionIds IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1 FROM [monitor].[TVF_ParseBigintList](@SessionIds)
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
            SET @ErrorMessage = N'@SessionIds ist ungültig oder enthält Duplikate.';
        END
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
           COALESCE(@MinAlterSekunden, -1) < 0
           OR @MaxZeilen < 0
           OR @MaxSqlTextZeichen < 0
           OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
           OR @JsonErzeugen IS NULL
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Mindestens ein Parameter besitzt einen ungültigen Wert.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#Result]
        (
              [SessionId], [TransactionId], [TransactionBeginTimeUtc]
            , [TransactionAgeSeconds], [TransactionType], [TransactionState]
            , [OpenTransactionCount], [LoginName], [HostName], [ProgramName]
            , [SessionStatus], [RequestStatus], [DatabaseId], [DatabaseName]
            , [LogBytesUsed], [LogBytesReserved], [StatementText]
        )
        SELECT TOP (@Candidates)
              [st].[session_id]
            , [at].[transaction_id]
            , [at].[transaction_begin_time]
            , DATEDIFF_BIG(SECOND, [at].[transaction_begin_time], GETDATE())
            , [at].[transaction_type]
            , [at].[transaction_state]
            , [s].[open_transaction_count]
            , [s].[login_name]
            , [s].[host_name]
            , [s].[program_name]
            , [s].[status]
            , [r].[status]
            , COALESCE([r].[database_id], [dt].[database_id])
            , [d].[name]
            , [dt].[database_transaction_log_bytes_used]
            , [dt].[database_transaction_log_bytes_reserved]
            , CASE WHEN @MitSqlText = 1 THEN CASE WHEN @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen = 0 THEN [statementText].[StatementText] ELSE LEFT([statementText].[StatementText], @MaxSqlTextZeichen) END END
        FROM [sys].[dm_tran_session_transactions] AS [st]
        INNER JOIN [sys].[dm_tran_active_transactions] AS [at]
          ON [at].[transaction_id] = [st].[transaction_id]
        INNER JOIN [sys].[dm_exec_sessions] AS [s]
          ON [s].[session_id] = [st].[session_id]
        LEFT JOIN [sys].[dm_exec_requests] AS [r]
          ON [r].[session_id] = [st].[session_id]
        LEFT JOIN [sys].[dm_tran_database_transactions] AS [dt]
          ON [dt].[transaction_id] = [st].[transaction_id]
        LEFT JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
          ON [d].[database_id] = COALESCE([r].[database_id], [dt].[database_id])
        OUTER APPLY [sys].[dm_exec_sql_text](CASE WHEN @MitSqlText = 1 THEN [r].[sql_handle] END) AS [sqlText]
        OUTER APPLY [monitor].[TVF_StatementText]
        (
              [sqlText].[text]
            , [r].[statement_start_offset]
            , [r].[statement_end_offset]
        ) AS [statementText]
        WHERE (@SystemSessionsEinbeziehen = 1 OR [s].[is_user_process] = 1)
          AND (@NurSleeping = 0 OR [s].[status] = N'sleeping')
          AND DATEDIFF_BIG(SECOND, [at].[transaction_begin_time], GETDATE()) >= @MinAlterSekunden
          AND
          (
              @SessionIds IS NULL
              OR EXISTS
                 (
                     SELECT 1 FROM [#SessionFilter] AS [f]
                     WHERE [f].[SessionId] = [st].[session_id]
                 )
          )
        ORDER BY
              DATEDIFF_BIG(SECOND, [at].[transaction_begin_time], GETDATE()) DESC
            , [st].[session_id]
            , [at].[transaction_id];

        SELECT @RowCount = COUNT_BIG(*) FROM [#Result];
        SET @HasMoreRows = CONVERT(bit, CASE WHEN @Limit < 9223372036854775807 AND @RowCount > @Limit THEN 1 ELSE 0 END);
    END TRY
    BEGIN CATCH
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        SET @StatusCode = CASE WHEN @ErrorNumber IN (229, 262, 297, 300, 916) THEN 'DENIED_PERMISSION'
                               WHEN @ErrorNumber = 1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
        INSERT [#Warnings] VALUES (@StatusCode, @ErrorNumber, @ErrorMessage);
    END CATCH;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @Message = FORMATMESSAGE(N'WARNUNG USP_CurrentTransactions [%s]: %s', @StatusCode, COALESCE(@ErrorMessage, N'Unbekannter Fehler.'));
        RAISERROR(N'%s', 10, 1, @Message) WITH NOWAIT;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              N'USP_CurrentTransactions' AS [ModuleName]
            , @Now AS [CollectionTimeUtc]
            , @StatusCode AS [StatusCode]
            , CONVERT(bit, CASE WHEN @StatusCode = 'AVAILABLE' THEN 0 ELSE 1 END) AS [IsPartial]
            , CASE WHEN @RowCount > @Limit THEN @Limit ELSE @RowCount END AS [ReturnedRowCount]
            , @HasMoreRows AS [HasMoreRows]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT TOP (@Limit) *
            FROM [#Result]
            ORDER BY [TransactionAgeSeconds] DESC, [SessionId], [TransactionId];
        END
        ELSE
        BEGIN
            SELECT TOP (@Limit)
                  N'Aktive Transaktion' AS [Ergebnis]
                , [SessionId] AS [Session]
                , [TransactionId] AS [Transaktion]
                , [DatabaseName] AS [Datenbank]
                , [LoginName] AS [Login]
                , [HostName] AS [Host]
                , [ProgramName] AS [Programm]
                , [SessionStatus] AS [Session-Status]
                , [RequestStatus] AS [Request-Status]
                , CONCAT(CONVERT(varchar(30), [TransactionAgeSeconds]), N' s') AS [Alter]
                , CONVERT(decimal(19, 2), [LogBytesUsed] / 1048576.0) AS [Log verwendet MB]
                , CONVERT(decimal(19, 2), [LogBytesReserved] / 1048576.0) AS [Log reserviert MB]
                , [SessionId] AS [Session_SQL]
                , [StatementText] AS [SQL-Text]
            FROM [#Result]
            ORDER BY [TransactionAgeSeconds] DESC, [SessionId], [TransactionId];
        END;

        SELECT * FROM [#Warnings] ORDER BY [StatusCode];
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @Meta nvarchar(max) =
        (
            SELECT
                  N'CurrentTransactions' AS [resultName]
                , 1 AS [schemaVersion]
                , @Now AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @MaxZeilen AS [requestedMaxRows]
                , CASE WHEN @RowCount > @Limit THEN @Limit ELSE @RowCount END AS [returnedRows]
                , @HasMoreRows AS [hasMoreRows]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @Data nvarchar(max) =
        (
            SELECT TOP (@Limit) *
            FROM [#Result]
            ORDER BY [TransactionAgeSeconds] DESC, [SessionId], [TransactionId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        DECLARE @Warnings nvarchar(max) =
        (
            SELECT * FROM [#Warnings] ORDER BY [StatusCode]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        SET @Json = CONCAT(N'{"meta":', COALESCE(@Meta, N'{}'), N',"transactions":', COALESCE(@Data, N'[]'), N',"warnings":', COALESCE(@Warnings, N'[]'), N'}');
    END;
END;
GO
