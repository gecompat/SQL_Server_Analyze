USE [DeineDatenbank];
GO

/* Injizierte subplanbezogene Maintenancehistorie prüft selektive native Retention mit deaktiviertem eigenem Job. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1 OR NOT EXISTS
(
    SELECT 1 FROM [sys].[extended_properties]
    WHERE [class] = 0 AND [name] = N'SQLANALYZE.Ops008Disposable' AND CONVERT(int, [value]) = 1
)
    THROW 55801, N'Die eigene Wegwerf-Lab-Bindung oder Transaktionsbasis fehlt.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_logdetail])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_plans])
   OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_subplans])
    THROW 55802, N'Die leeren eigenen Maintenancequellen fehlen.', 1;
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
    THROW 55800, N'Der native Maintenance-Purgevertrag fehlt.', 1;
IF (SELECT COUNT_BIG(*) FROM [msdb].[sys].[columns]
    WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_logdetail')) <> 13 OR EXISTS
(
    SELECT [Name], [TypeId] FROM (VALUES
        (N'task_detail_id', 36), (N'line1', 231), (N'line2', 231), (N'line3', 231),
        (N'line4', 231), (N'line5', 231), (N'server_name', 231), (N'start_time', 61),
        (N'end_time', 61), (N'error_number', 56), (N'error_message', 231),
        (N'command', 231), (N'succeeded', 104)) [e]([Name], [TypeId])
    EXCEPT SELECT [name] COLLATE SQL_Latin1_General_CP1_CS_AS, [system_type_id]
        FROM [msdb].[sys].[columns]
        WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_logdetail')
) OR EXISTS (SELECT 1 FROM [msdb].[sys].[columns]
    WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_logdetail')
      AND ([is_identity] <> 0 OR [is_computed] <> 0 OR
        ([system_type_id] = 231 AND [max_length] <> -1 AND [max_length] < 64)))
   OR NOT EXISTS (SELECT 1 FROM [msdb].[sys].[foreign_key_columns] [f]
    JOIN [msdb].[sys].[columns] [p] ON [p].[object_id] = [f].[parent_object_id]
        AND [p].[column_id] = [f].[parent_column_id]
    JOIN [msdb].[sys].[columns] [r] ON [r].[object_id] = [f].[referenced_object_id]
        AND [r].[column_id] = [f].[referenced_column_id]
    WHERE [f].[parent_object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_logdetail')
      AND [f].[referenced_object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_log')
      AND [p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'task_detail_id'
      AND [r].[name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'task_detail_id')
    THROW 55813, N'Der native Maintenance-Detailvertrag oder die Elternbindung fehlt.', 1;
IF EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs]) OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
    THROW 55818, N'Die leeren eigenen Jobquellen fehlen.', 1;
IF (SELECT COUNT_BIG(*) FROM [msdb].[sys].[columns]
    WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_subplans')) <> 8 OR EXISTS
(
    SELECT [Name], [TypeId] FROM (VALUES (N'subplan_id', 36), (N'subplan_name', 231),
        (N'subplan_description', 231), (N'plan_id', 36), (N'job_id', 36),
        (N'msx_job_id', 36), (N'schedule_id', 56), (N'msx_plan', 104)) [e]([Name], [TypeId])
    EXCEPT SELECT [name] COLLATE SQL_Latin1_General_CP1_CS_AS, [system_type_id]
        FROM [msdb].[sys].[columns]
        WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_subplans')
) OR EXISTS (SELECT 1 FROM [msdb].[sys].[columns]
    WHERE [object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_subplans')
      AND ([is_identity] <> 0 OR [is_computed] <> 0 OR
        ([system_type_id] = 231 AND [max_length] <> -1 AND [max_length] < 64)))
   OR NOT EXISTS (SELECT 1 FROM [msdb].[sys].[foreign_key_columns] [f]
    JOIN [msdb].[sys].[columns] [p] ON [p].[object_id] = [f].[parent_object_id]
        AND [p].[column_id] = [f].[parent_column_id]
    JOIN [msdb].[sys].[columns] [r] ON [r].[object_id] = [f].[referenced_object_id]
        AND [r].[column_id] = [f].[referenced_column_id]
    WHERE [f].[parent_object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_log')
      AND [f].[referenced_object_id] = OBJECT_ID(N'msdb.dbo.sysmaintplan_subplans')
      AND [p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'subplan_id'
      AND [r].[name] COLLATE SQL_Latin1_General_CP1_CS_AS = N'subplan_id')
    THROW 55819, N'Der native Subplanvertrag oder die Historienbindung fehlt.', 1;
DECLARE @Stage int = 1, @Phase int = 1, @Consumer int, @Calls int = 0, @KeepTask uniqueidentifier, @Task uniqueidentifier;
DECLARE @DetailNo int, @ExpectedDetails bigint, @ExpectedTarget bigint;
DECLARE @TargetPlan uniqueidentifier = NEWID(), @OtherPlan uniqueidentifier = NEWID();
DECLARE @TargetSubplan uniqueidentifier = NEWID(), @SamePlanSubplan uniqueidentifier = NEWID();
DECLARE @OtherSubplan uniqueidentifier = NEWID(), @NoMatchSubplan uniqueidentifier = NEWID();
DECLARE @Plan uniqueidentifier, @Subplan uniqueidentifier, @JobId uniqueidentifier;
DECLARE @ProtectedParents nvarchar(max), @ProtectedDetails nvarchar(max);
DECLARE @SubplansBefore nvarchar(max), @SubplansAfter nvarchar(max), @JobBefore nvarchar(max), @JobAfter nvarchar(max);
DECLARE @DetailBefore nvarchar(max), @DetailAfter nvarchar(max), @RetainedDetail nvarchar(max), @DetailAfterPurge nvarchar(max);
DECLARE @Date datetime, @Cutoff datetime, @ExpectedCount bigint, @Low datetime2(3), @High datetime2(3);
DECLARE @Before nvarchar(max), @After nvarchar(max), @Retained nvarchar(max), @AfterPurge nvarchar(max);
DECLARE @Json nvarchar(max), @TableJson nvarchar(max), @ConsoleJson nvarchar(max);
DECLARE @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048);
DECLARE @Mode varchar(16), @Mapping nvarchar(max), @ReturnCode int;
DECLARE @PreviousLockTimeout int = @@LOCK_TIMEOUT, @RestoreLockTimeoutSql nvarchar(100);
CREATE TABLE [#Ops008Console]
(
    [Ergebnis] nvarchar(200), [Area] varchar(40), [SourceObject] nvarchar(256),
    [RowCount] bigint, [OldestUtc] datetime2(3), [NewestUtc] datetime2(3),
    [SizeMb] decimal(19,2), [StatusCode] varchar(40), [EvidenceLimit] nvarchar(1000)
);
BEGIN TRY
    BEGIN TRANSACTION;
    SET LOCK_TIMEOUT 137;
    EXEC @ReturnCode = [msdb].[dbo].[sp_add_job] @job_name = N'ExampleOps008SubplanJob',
        @enabled = 0, @description = N'Synthetic subplan metadata binding.',
        @notify_level_eventlog = 0, @notify_level_email = 0,
        @notify_level_netsend = 0, @notify_level_page = 0,
        @delete_level = 0, @job_id = @JobId OUTPUT;
    IF @ReturnCode <> 0 OR @JobId IS NULL OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysjobs]) <> 1 OR NOT EXISTS
        (SELECT 1 FROM [msdb].[dbo].[sysjobs] WHERE [job_id] = @JobId AND [enabled] = 0
            AND [notify_level_eventlog] = 0 AND [notify_level_email] = 0
            AND [notify_level_netsend] = 0 AND [notify_level_page] = 0 AND [delete_level] = 0)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
        THROW 55820, N'Die deaktivierte eigene Jobbindung ohne Steps und Server fehlt.', 1;
    INSERT [msdb].[dbo].[sysmaintplan_subplans]
        ([subplan_id], [subplan_name], [subplan_description], [plan_id], [job_id], [msx_job_id], [schedule_id], [msx_plan])
    VALUES (@TargetSubplan, N'ExampleTargetSubplan', NULL, @TargetPlan, @JobId, NULL, NULL, 0),
        (@SamePlanSubplan, N'ExampleSamePlanSubplan', NULL, @TargetPlan, @JobId, NULL, NULL, 0),
        (@OtherSubplan, N'ExampleOtherSubplan', NULL, @OtherPlan, @JobId, NULL, NULL, 0);
    SELECT @SubplansBefore = (SELECT * FROM [msdb].[dbo].[sysmaintplan_subplans]
        ORDER BY [subplan_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SELECT @JobBefore = (SELECT * FROM [msdb].[dbo].[sysjobs]
        ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    WHILE @Stage <= 6
    BEGIN
        SET @Date = CONVERT(datetime, CASE @Stage WHEN 1 THEN '2025-01-01T12:00:00'
            WHEN 2 THEN '2025-01-02T12:00:00' ELSE '2000-01-01T12:00:00' END, 126);
        SET @Task = NEWID();
        SET @Plan = CASE WHEN @Stage <= 4 THEN @TargetPlan WHEN @Stage = 5 THEN @OtherPlan ELSE NULL END;
        SET @Subplan = CASE WHEN @Stage <= 3 THEN @TargetSubplan WHEN @Stage = 4 THEN @SamePlanSubplan
            WHEN @Stage = 5 THEN @OtherSubplan ELSE NULL END;
        INSERT [msdb].[dbo].[sysmaintplan_log]
            ([task_detail_id], [plan_id], [subplan_id], [start_time], [end_time], [succeeded], [plan_name], [subplan_name])
        VALUES (@Task, @Plan, @Subplan, @Date, DATEADD(second, 5, @Date), 1, N'ExamplePlan', N'ExampleSubplan');
        SET @DetailNo = 1;
        WHILE @DetailNo <= 2
        BEGIN
            INSERT [msdb].[dbo].[sysmaintplan_logdetail]
                ([task_detail_id], [line1], [line2], [line3], [line4], [line5], [server_name],
                 [start_time], [end_time], [error_number], [error_message], [command], [succeeded])
            VALUES (@Task, N'ExampleDetail' + CONVERT(nvarchar(1), @Stage) + N'-' + CONVERT(nvarchar(1), @DetailNo),
                N'Example line', NULL, N'', N'Example final line', N'ExampleServer',
                @Date, DATEADD(second, 5, @Date), 0, NULL, N'SELECT 1;', 1);
            SET @DetailNo += 1;
        END;
        IF @Stage = 2 SET @KeepTask = @Task;
        SET @Stage += 1;
    END;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmaintplan_log]) <> 6
        THROW 55803, N'Die sechs injizierten eigenen Maintenancezeilen fehlen.', 1;
    IF (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmaintplan_logdetail]) <> 12
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log] [p]
           WHERE (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmaintplan_logdetail] [d]
               WHERE [d].[task_detail_id] = [p].[task_detail_id]) <> 2)
        THROW 55814, N'Die zwölf eigenen Detailzeilen oder Elternbindungen fehlen.', 1;
    SELECT @RetainedDetail = (SELECT * FROM [msdb].[dbo].[sysmaintplan_logdetail]
        WHERE [task_detail_id] = @KeepTask ORDER BY [task_detail_id], [line1] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SELECT @Retained = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
        WHERE [task_detail_id] = @KeepTask ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SELECT @ProtectedParents = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
        WHERE [subplan_id] IS NULL OR [subplan_id] <> @TargetSubplan
        ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SELECT @ProtectedDetails = (SELECT [d].* FROM [msdb].[dbo].[sysmaintplan_logdetail] [d]
        JOIN [msdb].[dbo].[sysmaintplan_log] [p] ON [p].[task_detail_id] = [d].[task_detail_id]
        WHERE [p].[subplan_id] IS NULL OR [p].[subplan_id] <> @TargetSubplan
        ORDER BY [d].[task_detail_id], [d].[line1] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SELECT @Before = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
        ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SELECT @DetailBefore = (SELECT * FROM [msdb].[dbo].[sysmaintplan_logdetail]
        ORDER BY [task_detail_id], [line1] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SET @Cutoff = CONVERT(datetime, '2025-01-03T00:00:00', 126);
    EXEC @ReturnCode = [msdb].[dbo].[sp_maintplan_delete_log]
        @plan_id = NULL, @subplan_id = @NoMatchSubplan, @oldest_time = @Cutoff;
    SELECT @After = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
        ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
    SELECT @DetailAfter = (SELECT * FROM [msdb].[dbo].[sysmaintplan_logdetail]
        ORDER BY [task_detail_id], [line1] FOR JSON PATH, INCLUDE_NULL_VALUES);
    IF @ReturnCode <> 0 OR EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
        EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
       OR EXISTS (SELECT @DetailBefore COLLATE SQL_Latin1_General_CP1_CS_AS
        EXCEPT SELECT @DetailAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
       OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137
        THROW 55816, N'Der nicht passende Subplanfilter hat Quellwerte oder Callerzustand verändert.', 1;
    WHILE @Phase <= 3
    BEGIN
        SET @ExpectedTarget = CASE @Phase WHEN 1 THEN 3 WHEN 2 THEN 1 ELSE 0 END;
        SET @ExpectedCount = @ExpectedTarget + 3;
        SET @ExpectedDetails = @ExpectedCount * 2;
        SET @Low = CONVERT(datetime2(3), '2000-01-01T12:00:00', 126);
        SET @High = CONVERT(datetime2(3), CASE WHEN @Phase < 3 THEN '2025-01-02T12:00:00' ELSE '2000-01-01T12:00:00' END, 126);
        IF @Phase > 1
        BEGIN
            SET @Cutoff = CONVERT(datetime, CASE @Phase WHEN 2 THEN '2025-01-02T00:00:00'
                ELSE '2025-01-03T00:00:00' END, 126);
            EXEC @ReturnCode = [msdb].[dbo].[sp_maintplan_delete_log]
                @plan_id = NULL, @subplan_id = @TargetSubplan, @oldest_time = @Cutoff;
            IF @ReturnCode <> 0 THROW 55804, N'Die native eigene Maintenancebereinigung ist fehlgeschlagen.', 1;
            SELECT @AfterPurge = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
                WHERE [subplan_id] = @TargetSubplan ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF @Phase = 2 AND EXISTS (SELECT @Retained COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @AfterPurge COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55805, N'Die vollständigen jüngeren Maintenancewerte sind nach Retention verändert.', 1;
            SELECT @DetailAfterPurge = (SELECT [d].* FROM [msdb].[dbo].[sysmaintplan_logdetail] [d]
                JOIN [msdb].[dbo].[sysmaintplan_log] [p] ON [p].[task_detail_id] = [d].[task_detail_id]
                WHERE [p].[subplan_id] = @TargetSubplan ORDER BY [d].[task_detail_id], [d].[line1]
                FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF @Phase = 2 AND EXISTS (SELECT @RetainedDetail COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @DetailAfterPurge COLLATE SQL_Latin1_General_CP1_CS_AS)
                THROW 55815, N'Die vollständigen jüngeren Detailwerte sind nach Retention verändert.', 1;
        END;
        SELECT @AfterPurge = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
            WHERE [subplan_id] IS NULL OR [subplan_id] <> @TargetSubplan
            ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SELECT @DetailAfterPurge = (SELECT [d].* FROM [msdb].[dbo].[sysmaintplan_logdetail] [d]
            JOIN [msdb].[dbo].[sysmaintplan_log] [p] ON [p].[task_detail_id] = [d].[task_detail_id]
            WHERE [p].[subplan_id] IS NULL OR [p].[subplan_id] <> @TargetSubplan
            ORDER BY [d].[task_detail_id], [d].[line1] FOR JSON PATH, INCLUDE_NULL_VALUES);
        IF EXISTS (SELECT @ProtectedParents COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT @AfterPurge COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS (SELECT @ProtectedDetails COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT @DetailAfterPurge COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmaintplan_log]
                WHERE [subplan_id] = @TargetSubplan) <> @ExpectedTarget
            THROW 55817, N'Die Zielcounts oder älteren Gegenproben anderer und NULL-Subpläne sind verletzt.', 1;
        SELECT @SubplansAfter = (SELECT * FROM [msdb].[dbo].[sysmaintplan_subplans]
            ORDER BY [subplan_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SELECT @JobAfter = (SELECT * FROM [msdb].[dbo].[sysjobs]
            ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
        IF EXISTS (SELECT @SubplansBefore COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT @SubplansAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS (SELECT @JobBefore COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT @JobAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
           OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId)
           OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
           OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
            THROW 55821, N'Die eigenen Subplan- oder Jobmetadaten wurden verändert.', 1;
        IF EXISTS
        (
            SELECT COUNT_BIG(*), CONVERT(datetime2(3), MIN([start_time])),
                CONVERT(datetime2(3), MAX([start_time])) FROM [msdb].[dbo].[sysmaintplan_log]
            EXCEPT SELECT @ExpectedCount, @Low, @High
        ) OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmaintplan_logdetail]) <> @ExpectedDetails
          OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_logdetail] [d] WHERE NOT EXISTS
              (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log] [p] WHERE [p].[task_detail_id] = [d].[task_detail_id]))
          OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log] [p] WHERE
              (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmaintplan_logdetail] [d]
                  WHERE [d].[task_detail_id] = [p].[task_detail_id]) <> 2)
          OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137
            THROW 55806, N'Die unabhängigen Retentioncounts, Zeitgrenzen oder Callerbasis sind verletzt.', 1;
        SET @Consumer = 1;
        WHILE @Consumer <= 3
        BEGIN
            SELECT @Before = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
                ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SELECT @DetailBefore = (SELECT * FROM [msdb].[dbo].[sysmaintplan_logdetail]
                ORDER BY [task_detail_id], [line1] FOR JSON PATH, INCLUDE_NULL_VALUES);
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
                THROW 55807, N'Der Modulstatus oder die vollständigen Quellenzeilen sind verletzt.', 1;
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
                THROW 55808, N'Die nativen Maintenanceaggregate oder Evidenzgrenzen sind verletzt.', 1;
            IF @Consumer = 2
            BEGIN
                EXEC [sys].[sp_executesql]
                    N'SELECT @RowsJson = (SELECT * FROM [#Ops008Table] ORDER BY [Area] FOR JSON PATH);',
                    N'@RowsJson nvarchar(max) OUTPUT', @RowsJson = @TableJson OUTPUT;
                IF EXISTS (SELECT @TableJson COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @Json COLLATE SQL_Latin1_General_CP1_CS_AS)
                    THROW 55809, N'Die vollständige TABLE-/JSON-Parität ist verletzt.', 1;
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
                    THROW 55810, N'Die vollständige CONSOLE-/JSON-Parität ist verletzt.', 1;
            END;
            SELECT @SubplansAfter = (SELECT * FROM [msdb].[dbo].[sysmaintplan_subplans]
                ORDER BY [subplan_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SELECT @JobAfter = (SELECT * FROM [msdb].[dbo].[sysjobs]
                ORDER BY [job_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SELECT @After = (SELECT * FROM [msdb].[dbo].[sysmaintplan_log]
                ORDER BY [task_detail_id] FOR JSON PATH, INCLUDE_NULL_VALUES);
            SELECT @DetailAfter = (SELECT * FROM [msdb].[dbo].[sysmaintplan_logdetail]
                ORDER BY [task_detail_id], [line1] FOR JSON PATH, INCLUDE_NULL_VALUES);
            IF EXISTS (SELECT @Before COLLATE SQL_Latin1_General_CP1_CS_AS
                EXCEPT SELECT @After COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR XACT_STATE() <> 1 OR @@TRANCOUNT <> 1 OR @@LOCK_TIMEOUT <> 137
               OR EXISTS (SELECT @DetailBefore COLLATE SQL_Latin1_General_CP1_CS_AS
                   EXCEPT SELECT @DetailAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmaintplan_logdetail]) <> @ExpectedDetails
          OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_logdetail] [d] WHERE NOT EXISTS
              (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log] [p] WHERE [p].[task_detail_id] = [d].[task_detail_id]))
          OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_log] [p] WHERE
              (SELECT COUNT_BIG(*) FROM [msdb].[dbo].[sysmaintplan_logdetail] [d]
                  WHERE [d].[task_detail_id] = [p].[task_detail_id]) <> 2)
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysmaintplan_plans])
               OR EXISTS (SELECT @SubplansBefore COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @SubplansAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR EXISTS (SELECT @JobBefore COLLATE SQL_Latin1_General_CP1_CS_AS
                    EXCEPT SELECT @JobAfter COLLATE SQL_Latin1_General_CP1_CS_AS)
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId)
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
               OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
                THROW 55811, N'Der Analyzer hat Maintenancequellen oder den Callerzustand verändert.', 1;
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
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobs])
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobsteps] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobservers] WHERE [job_id] = @JobId)
       OR EXISTS (SELECT 1 FROM [msdb].[dbo].[sysjobhistory])
        THROW 55812, N'Die eigene injizierte Maintenancefixture wurde nicht vollständig zurückgerollt.', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SET @RestoreLockTimeoutSql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(20), @PreviousLockTimeout) + N';';
    EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
    THROW;
END CATCH;
SET @RestoreLockTimeoutSql = N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(20), @PreviousLockTimeout) + N';';
EXEC [sys].[sp_executesql] @RestoreLockTimeoutSql;
DROP TABLE [#Ops008Console];
SELECT N'OPS008_MAINTENANCE_SUBPLAN_RETENTION' AS [ContractName], 3 AS [InitialTargetRows], 1 AS [RetainedTargetRows],
    0 AS [FinalTargetRows], 6 AS [InitialRows], 4 AS [RetainedRows], 3 AS [FinalRows],
    12 AS [InitialDetails], 8 AS [RetainedDetails], 6 AS [FinalDetails], 3 AS [NativePurgeCalls],
    @Calls AS [ConsumerCalls], N'PASS' AS [Status], N'ROLLED_BACK' AS [FixtureCleanup];
GO
