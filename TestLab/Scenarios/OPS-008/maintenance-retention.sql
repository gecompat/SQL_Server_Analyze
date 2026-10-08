USE [DeineDatenbank];
GO

/* Die injizierte Maintenancehistorie prüft native Retention ohne Maintenance- oder Jobausführung. */
SET NOCOUNT ON;
IF @@TRANCOUNT <> 0 OR NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable' AND CONVERT(int, [value]) = 1
)
    THROW 55201, N'Die eigene Wegwerf-Lab-Bindung oder Transaktionsbasis fehlt.', 1;
IF @@LOCK_TIMEOUT <> -1
    THROW 55223, N'Die eigene Fixture erfordert den ursprünglichen Standardlocktimeout.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_logdetail])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_plans])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_subplans])
    THROW 55202, N'Die leeren eigenen Maintenancequellen fehlen.', 1;
IF OBJECT_ID(N'msdb.dbo.sp_maintplan_delete_log', N'P') IS NULL OR EXISTS
(
    SELECT [Name], [TypeId], [ByteLength] FROM
        (VALUES (N'@plan_id', 36, 16), (N'@subplan_id', 36, 16), (N'@oldest_time', 61, 8))
        [e]([Name], [TypeId], [ByteLength])
    EXCEPT
    SELECT [name] COLLATE SQL_Latin1_General_CP1_CS_AS, [system_type_id], [max_length]
        FROM [msdb].[sys].[parameters]
        WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sp_maintplan_delete_log', N'P')
)
    THROW 55200, N'Der native Maintenance-Purgevertrag fehlt.', 1;
DECLARE @Stage int = 1, @Phase int = 1, @Consumer int, @Calls int = 0, @KeepTask uniqueidentifier, @Task uniqueidentifier;
DECLARE @Date datetime, @Cutoff datetime, @ExpectedCount bigint, @Low datetime2(3), @High datetime2(3);
DECLARE @Before nvarchar(max), @After nvarchar(max), @Retained nvarchar(max), @AfterPurge nvarchar(max);
DECLARE @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048);
DECLARE @Mode varchar(16), @Mapping nvarchar(max), @ReturnCode int;
DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT;
DECLARE @PreviousXactAbort bit = CASE WHEN (@@OPTIONS & 16384) = 16384 THEN 1 ELSE 0 END;
CREATE TABLE [#Ops008Console]
(
    [Ergebnis] nvarchar(200), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
BEGIN TRY
    BEGIN TRANSACTION;
    SET XACT_ABORT ON;
    SET LOCK_TIMEOUT 137;
    WHILE @Stage <= 3
    BEGIN
        SET @Date = CONVERT(datetime, CASE @Stage WHEN 1 THEN '2025-01-01T12:00:00'
            WHEN 2 THEN '2025-01-02T12:00:00' ELSE '2000-01-01T12:00:00' END, 126);
        SET @Task = NEWID();
        INSERT [msdb].[dbo].[sysmaintplan_log]
            ([task_detail_id], [start_time], [end_time], [succeeded], [plan_name], [subplan_name])
        VALUES (@Task, @Date, DATEADD(second, 5, @Date), 1, N'ExamplePlan', N'ExampleSubplan');
        IF @Stage = 2 SET @KeepTask = @Task;
        SET @Stage += 1;
    END;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmaintplan_log]) <> 3
        THROW 55203, N'Die drei injizierten eigenen Maintenancezeilen fehlen.', 1;
    SELECT @Retained = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
        WHERE [task_detail_id] = @KeepTask ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    WHILE @Phase <= 3
    BEGIN
        SET @ExpectedCount = CASE @Phase WHEN 1 THEN 3 WHEN 2 THEN 1 ELSE 0 END;
        SET @Low = CASE @Phase WHEN 1 THEN CONVERT(datetime2(3), '2000-01-01T12:00:00', 126)
            WHEN 2 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00', 126) ELSE NULL END;
        SET @High = CASE WHEN @Phase < 3 THEN CONVERT(datetime2(3), '2025-01-02T12:00:00', 126) ELSE NULL END;
        IF @Phase > 1
        BEGIN
            SET @Cutoff = CONVERT(datetime, CASE @Phase WHEN 2 THEN '2025-01-02T00:00:00'
                ELSE '2025-01-03T00:00:00' END, 126);
            EXEC @ReturnCode = [msdb].[dbo].[sp_maintplan_delete_log]
                @plan_id = NULL, @subplan_id = NULL, @oldest_time = @Cutoff;
            IF @ReturnCode <> 0 THROW 55204, N'Die native eigene Maintenancebereinigung ist fehlgeschlagen.', 1;
            SELECT @AfterPurge = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
                ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF @Phase = 2 AND EXISTS (SELECT @Retained COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @AfterPurge COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55205, N'Die vollständigen jüngeren Maintenancewerte sind nach Retention verändert.', 1;
        END;
        IF EXISTS
        (
            SELECT COUNT_BIG(*), CONVERT(datetime2(3), MIN([start_time])),
                CONVERT(datetime2(3), MAX([start_time])) FROM [msdb].[dbo].[sysmaintplan_log]
            EXCEPT SELECT @ExpectedCount, @Low, @High
        ) OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
            THROW 55206, N'Die unabhängigen Retentioncounts, Zeitgrenzen oder Callerbasis sind verletzt.', 1;
        SET @Consumer = 1;
        WHILE @Consumer <= 3
        BEGIN
            SELECT @Before = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
                ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SET @Mode = CASE @Consumer WHEN 1 THEN 'NONE' WHEN 2 THEN 'TABLE' ELSE 'CONSOLE' END;
            SET @Mapping = CASE WHEN @Consumer = 2 THEN N'{"msdbHealth":"#Ops008Table"}' ELSE NULL END;
            SELECT @Json = NULL, @Status = NULL, @Partial = NULL, @Error = -1, @Message = N'Example sentinel';
            IF @Consumer = 2 CREATE TABLE [#Ops008Table] ([Dummy] int);
            IF @Consumer = 3
            BEGIN
                TRUNCATE TABLE [#Ops008Console];
                INSERT [#Ops008Console]
                EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0,
                    @ResultSetArt = @Mode, @JsonErzeugen = 1, @Json = @Json OUTPUT,
                    @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                    @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT,
                    @ErrorMessageOut = @Message OUTPUT;
            END
            ELSE
                EXEC [monitor].[USP_MsdbHealthAnalysis] @MaxZeilen = 0,
                    @ResultSetArt = @Mode, @ResultTablesJson = @Mapping,
                    @JsonErzeugen = 1, @Json = @Json OUTPUT,
                    @PrintMeldungen = 0, @StatusCodeOut = @Status OUTPUT,
                    @IsPartialOut = @Partial OUTPUT, @ErrorNumberOut = @Error OUTPUT,
                    @ErrorMessageOut = @Message OUTPUT;
            IF COALESCE(ISJSON(@Json), 0) <> 1 OR COALESCE(@Status, '') <> 'AVAILABLE'
               OR COALESCE(@Partial, 1) <> 0 OR @Error IS NOT NULL OR @Message IS NOT NULL
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)) <> 6
               OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json)
                   WITH ([Area] varchar(40)) WHERE [Area] = 'MAINTENANCE_PLAN') <> 1
                THROW 55207, N'Der Modulstatus oder die vollständigen Quellenzeilen sind verletzt.', 1;
            IF EXISTS
            (
                SELECT 'MAINTENANCE_PLAN' [Area], N'msdb.dbo.sysmaintplan_log' [SourceObject],
                    COUNT_BIG(*) [RowCount], CONVERT(datetime2(3), MIN([start_time])) [OldestUtc],
                    CONVERT(datetime2(3), MAX([start_time])) [NewestUtc],
                    CONVERT(decimal(19,2), NULL) [SizeMb], CONVERT(varchar(40), 'AVAILABLE') [StatusCode]
                FROM [msdb].[dbo].[sysmaintplan_log]
                EXCEPT
                SELECT [Area], [SourceObject], [RowCount], [OldestUtc], [NewestUtc], [SizeMb], [StatusCode]
                FROM OPENJSON(@Json)
                WITH ([Area] varchar(40), [SourceObject] nvarchar(256), [RowCount] bigint,
                    [OldestUtc] datetime2(3), [NewestUtc] datetime2(3), [SizeMb] decimal(19,2), [StatusCode] varchar(40))
            ) OR EXISTS (SELECT 1 FROM OPENJSON(@Json)
                WITH ([Area] varchar(40), [EvidenceLimit] nvarchar(1000))
                WHERE [Area] = 'MAINTENANCE_PLAN' AND NULLIF([EvidenceLimit], N'') IS NULL)
                THROW 55208, N'Die nativen Maintenanceaggregate oder Evidenzgrenzen sind verletzt.', 1;
            IF @Consumer = 2
            BEGIN
                EXEC [sys].[sp_executesql]
                    N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                    N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
                IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                    THROW 55209, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
                DROP TABLE [#Ops008Table];
            END;
            IF @Consumer = 3
            BEGIN
                SELECT @ConsoleJson = (SELECT [Area], [SourceObject], [RowCount], [OldestUtc],
                    [NewestUtc], [SizeMb], [StatusCode], [EvidenceLimit]
                    FROM [#Ops008Console] ORDER BY [Area] FOR JSON PATH);
                IF EXISTS (SELECT @ConsoleJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                   OR EXISTS (SELECT 1 FROM [#Ops008Console] WHERE [Ergebnis] IS NULL OR [Ergebnis] <> N'msdbHealth')
                    THROW 55210, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
            END;
            SELECT @After = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
                ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137 OR (@@OPTIONS & 16384) <> 16384
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_logdetail])
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_plans])
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_subplans])

                THROW 55211, N'Der Analyzer hat Maintenancequellen oder den Callerzustand verändert.', 1;
            SET @Calls += 1;
            SET @Consumer += 1;
        END;
        SET @Phase += 1;
    END;
    ROLLBACK TRANSACTION;
    IF @@TRANCOUNT <> 0 OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_logdetail])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_plans])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_subplans])
        THROW 55212, N'Die eigene injizierte Maintenancefixture wurde nicht vollständig zurückgerollt.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SET LOCK_TIMEOUT -1;
    IF @PreviousXactAbort = 1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    THROW;
END CATCH;
SET LOCK_TIMEOUT -1;
IF @PreviousXactAbort = 1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
IF @Calls <> 9 OR @@LOCK_TIMEOUT <> @PreviousLockTimeout
   OR CASE WHEN (@@OPTIONS & 16384) = 16384 THEN 1 ELSE 0 END <> @PreviousXactAbort
    THROW 55224, N'Die neun Consumeraufrufe oder ursprünglichen Locktimeout- und XACT_ABORT-Werte sind verletzt.', 1;
DROP TABLE [#Ops008Console];
SELECT N'OPS008_MAINTENANCE_RETENTION' AS [ContractName], 3 AS [InitialRows], 1 AS [RetainedRows],
    0 AS [FinalRows], @Calls AS [ConsumerCalls], N'PASS' AS [Status], N'ROLLED_BACK' AS [FixtureCleanup];
GO
