USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_SsisLegacyLogAnalysis
Version      : 1.0.0
Stand        : 2026-10-16
Typ          : Stored Procedure
Zweck        : Liest eine explizite Legacy-Loggingquelle für genau eine GUID.
Grenze       : Keine Quellaktionen; Meldungstexte bleiben Laufzeitausgaben.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_SsisLegacyLogAnalysis]
      @LoggingDatabase sysname = NULL
    , @LoggingSchema sysname = N'dbo'
    , @LoggingTable sysname = N'sysssislog'
    , @ExecutionId uniqueidentifier = NULL
    , @IncludeTimeline bit = 1
    , @IncludeMessages bit = 1
    , @HighImpactConfirmed bit = 0
    , @MaxZeilen int = 1000
    , @MaxDurationSeconds int = 30
    , @LockTimeoutMs int = 0
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(4000) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF COALESCE(@Hilfe,0)=1
    BEGIN
        PRINT N'monitor.USP_SsisLegacyLogAnalysis: explizite @LoggingDatabase und @ExecutionId; Default dbo.sysssislog.';
        PRINT N'Alle gespeicherten Meldungen sind standardmäßig eingeschlossen. Keine zusätzlichen Indizes oder Quelländerungen.';
        PRINT N'RAW9, CONSOLE1, TABLE mit @ResultTablesJson, NONE0; optional JSON derselben Mengen.';
        PRINT N'@MaxZeilen NULL/0 und eingeschlossenes nvarchar(max) benötigen @HighImpactConfirmed=1. Zeitbudget ist kooperativ.';
        RETURN;
    END;
    SELECT @IncludeTimeline=COALESCE(@IncludeTimeline,1),@IncludeMessages=COALESCE(@IncludeMessages,1),@HighImpactConfirmed=COALESCE(@HighImpactConfirmed,0);
    DECLARE @OutputMode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))) COLLATE SQL_Latin1_General_CP1_CS_AS;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @OutputMode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @Now datetime2(3)=SYSUTCDATETIME(),@Deadline datetime2(3),@Status varchar(40)='AVAILABLE',@Partial bit=0;
    DECLARE @Error int=NULL,@Message nvarchar(4000)=NULL,@Step int=1,@Continue bit=1,@ValidBuffer bit=0,@Truncated bit=0;
    DECLARE @Limit bigint=CASE WHEN COALESCE(@MaxZeilen,0)=0 THEN 9223372036854775807 ELSE CONVERT(bigint,@MaxZeilen) END;
    DECLARE @Take bigint=CASE WHEN COALESCE(@MaxZeilen,0)=0 THEN 9223372036854775807 ELSE CONVERT(bigint,@MaxZeilen)+1 END;
    DECLARE @PreviousLock int=@@LOCK_TIMEOUT,@PreviousAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END;
    DECLARE @RestoreLock nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@@LOCK_TIMEOUT)+N';';
    DECLARE @LockSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),COALESCE(@LockTimeoutMs,0))+N';';
    CREATE TABLE [#SsisLegacyLogAnalysis_ResultTables]
    ([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    IF @OutputMode='TABLE'
        EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
            @AllowedResultNames=N'moduleStatus|execution|timeline|errorChain|iterations|loggingQuality|findings|sourceStatus|warnings',
            @MappingTable=N'#SsisLegacyLogAnalysis_ResultTables',@ThrowOnError=1;
    CREATE TABLE [#SsisLegacyLogAnalysis_ModuleStatus]
    (
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SchemaVersion] int NOT NULL,
        [LoggingDatabase] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [LoggingSchema] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [LoggingTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [ExecutionId] uniqueidentifier NULL,
        [MessagesIncluded] bit NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [CollectionTimeUtc] datetime2(3) NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Execution]
    (
        [ExecutionId] uniqueidentifier NOT NULL,
        [AnalyzedEventCount] bigint NOT NULL,
        [SourceCount] bigint NOT NULL,
        [FirstObservedTime] datetime NULL,
        [LastObservedTime] datetime NULL,
        [ErrorEventCount] bigint NOT NULL,
        [WarningEventCount] bigint NOT NULL,
        [TaskFailedEventCount] bigint NOT NULL,
        [CancelRequestCount] bigint NOT NULL,
        [BoundaryStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PackageStartLogId] int NULL,
        [PackageEndLogId] int NULL,
        [PackageDurationMs] bigint NULL,
        [ObservedOutcome] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [FirstErrorLogId] int NULL,
        [FirstErrorMessage] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsCompleteSlice] bit NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Timeline]
    (
        [TimelineOrdinal] bigint NOT NULL,
        [LogId] int NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceId] uniqueidentifier NULL,
        [EventTime] datetime NULL,
        [RawEndTime] datetime NULL,
        [DataCode] int NULL,
        [PreviousLogId] int NULL,
        [DeltaFromPreviousMs] bigint NULL,
        [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_ErrorChain]
    (
        [ErrorOrdinal] bigint NOT NULL,
        [LogId] int NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [SourceId] uniqueidentifier NULL,
        [EventTime] datetime NULL,
        [DataCode] int NULL,
        [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PreviousRelevantLogId] int NULL,
        [RelationKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Iterations]
    (
        [IterationOrdinal] bigint NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [SourceId] uniqueidentifier NULL,
        [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PairKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StartLogId] int NULL,
        [EndLogId] int NULL,
        [StartTime] datetime NULL,
        [EndTime] datetime NULL,
        [DurationMs] bigint NULL,
        [PairStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SampleIsPartial] bit NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_LoggingQuality]
    (
        [QualityOrdinal] int NOT NULL,
        [QualityCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [AffectedRowCount] bigint NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Findings]
    (
        [FindingOrdinal] int NOT NULL,
        [FindingCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [ExecutionId] uniqueidentifier NOT NULL,
        [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [LogId] int NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_SourceStatus]
    (
        [SourceOrdinal] int NOT NULL,
        [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [ObservedRowCount] bigint NULL,
        [ReturnedRowCount] bigint NULL,
        [IsTruncated] bit NOT NULL,
        [ErrorNumber] int NULL,
        [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CollectionTimeUtc] datetime2(3) NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Warnings]
    (
        [WarningOrdinal] int NOT NULL,
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisLegacyLogAnalysis_Buffer]
    ([LogId] int NOT NULL,[EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceId] uniqueidentifier NULL,
     [ExecutionId] uniqueidentifier NOT NULL,[EventTime] datetime NULL,[RawEndTime] datetime NULL,[DataCode] int NULL,
     [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#SsisLegacyLogAnalysis_Columns]
    ([ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TypeId] int NOT NULL,[MaxLength] smallint NOT NULL,[IsNullable] bit NOT NULL,[IsComputed] bit NOT NULL);
    CREATE TABLE [#SsisLegacyLogAnalysis_Indexes] ([IndexId] int NOT NULL,[Supporting] bit NOT NULL);
    CREATE TABLE [#SsisLegacyLogAnalysis_Pairs]
    ([LogId] int NOT NULL,[SourceId] uniqueidentifier NULL,[SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     [PairKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsStart] bit NOT NULL,[EventTime] datetime NULL,
     [Seq] bigint NOT NULL,[PreviousStart] bit NULL,[NextStart] bit NULL,[NextLogId] int NULL,[NextTime] datetime NULL);
    INSERT [#SsisLegacyLogAnalysis_SourceStatus]
        ([SourceOrdinal],[SourceName],[StatusCode],[IsPartial],[IsTruncated],[Detail],[CollectionTimeUtc])
    VALUES (1,N'sourceMetadata','NOT_READ',0,0,N'NOT_READ',@Now),(2,N'sourceIndexes','NOT_READ',0,0,N'NOT_READ',@Now),
           (3,N'sourceEvents','NOT_READ',0,0,N'NOT_READ',@Now),(4,N'eventDerivation','NOT_READ',0,0,N'NOT_READ',@Now);
    IF @IncludeTimeline=0 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'TIMELINE_NOT_REQUESTED',NULL,N'Der Timelineexport wurde abgeschaltet.');
    IF @IncludeMessages=0 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'MESSAGES_NOT_REQUESTED',NULL,N'Der fachliche Meldungstextzugriff wurde abgeschaltet.');
    IF @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR (@OutputMode<>'TABLE' AND NULLIF(LTRIM(RTRIM(@ResultTablesJson)),N'') IS NOT NULL)
       OR NULLIF(LTRIM(RTRIM(@LoggingDatabase)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@LoggingSchema)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@LoggingTable)),N'') IS NULL
       OR @ExecutionId IS NULL OR @ExecutionId='00000000-0000-0000-0000-000000000000'
       OR @MaxZeilen<0 OR @MaxDurationSeconds IS NULL OR @MaxDurationSeconds NOT BETWEEN 1 AND 60
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
    BEGIN
        SELECT @Status='INVALID_PARAMETER',@Partial=1,@Continue=0;
    END;
    IF @Continue=1 AND COALESCE(@MaxZeilen,0)=0 AND @HighImpactConfirmed=0
    BEGIN
        SELECT @Status='INVALID_PARAMETER',@Partial=1,@Continue=0;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'HIGH_IMPACT_CONFIRMATION_REQUIRED',NULL,N'Unbegrenzte Sammlung benötigt die ausdrückliche Bestätigung.');
    END;
    SET @Deadline=DATEADD(second,CASE WHEN @MaxDurationSeconds BETWEEN 1 AND 60 THEN @MaxDurationSeconds ELSE 30 END,@Now);
    DECLARE @DatabaseId int=NULL,@ObjectId int=NULL,@Created datetime=NULL,@CurrentDb int=NULL,@CurrentObject int=NULL,@CurrentCreated datetime=NULL;
    DECLARE @Sql nvarchar(max),@Source nvarchar(780)=QUOTENAME(@LoggingDatabase)+N'.'+QUOTENAME(@LoggingSchema)+N'.'+QUOTENAME(@LoggingTable);
    DECLARE @UseDb nvarchar(300)=N'USE '+QUOTENAME(@LoggingDatabase)+N'; ';
    BEGIN TRY
        IF @Continue=1
        BEGIN
            SET XACT_ABORT OFF;
            SET LOCK_TIMEOUT 0;
        END;
        WHILE @Step<=4 AND @Continue=1
        BEGIN
            IF SYSUTCDATETIME()>=@Deadline
            BEGIN
                SELECT @Status='AVAILABLE_LIMITED',@Partial=1,@Continue=0;
                INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'TIME_BUDGET_EXHAUSTED',
                    CASE @Step WHEN 1 THEN N'sourceMetadata' WHEN 2 THEN N'sourceIndexes' WHEN 3 THEN N'sourceEvents' ELSE N'eventDerivation' END,N'Das kooperative Budget ist vor diesem Schritt ausgeschöpft.');
                BREAK;
            END;
            BEGIN TRY
                IF @Step=1
                BEGIN
                    SET @Sql=@UseDb+@LockSql+N'
                        SELECT @Db=DB_ID(),@Obj=o.object_id,@Created=o.create_date
                        FROM sys.all_objects AS o WITH (NOLOCK) INNER JOIN sys.schemas AS s WITH (NOLOCK) ON s.schema_id=o.schema_id
                        WHERE s.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Sch AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Tab
                          AND o.type IN (''U'',''S'') AND NOT EXISTS (SELECT 1 FROM sys.external_tables AS e WITH (NOLOCK) WHERE e.object_id=o.object_id);
                        INSERT [#SsisLegacyLogAnalysis_Columns]
                        SELECT name,system_type_id,max_length,is_nullable,is_computed FROM sys.all_columns WITH (NOLOCK) WHERE object_id=@Obj;';
                    EXEC sys.sp_executesql @Sql,N'@Sch sysname,@Tab sysname,@Db int OUTPUT,@Obj int OUTPUT,@Created datetime OUTPUT',
                        @Sch=@LoggingSchema,@Tab=@LoggingTable,@Db=@DatabaseId OUTPUT,@Obj=@ObjectId OUTPUT,@Created=@Created OUTPUT;
                    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Columns]),
                        [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Columns]),[StatusCode]='AVAILABLE',[Detail]=N'VISIBLE_OBJECT_METADATA' WHERE [SourceOrdinal]=1;
                    IF @ObjectId IS NULL
                    BEGIN
                        SELECT @Status='SOURCE_UNAVAILABLE',@Partial=1,@Continue=0;
                        UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=@Status,[IsPartial]=1,[Detail]=N'OBJECT_NOT_VISIBLE_OR_ABSENT' WHERE [SourceOrdinal]=1;
                    END
                    ELSE IF EXISTS
                    (
                        SELECT 1 FROM (VALUES (N'id',56,4,4),(N'event',231,2,256),(N'source',231,2,8000),
                            (N'sourceid',36,16,16),(N'executionid',36,16,16),(N'starttime',61,8,8),(N'endtime',61,8,8),(N'datacode',56,4,4)) AS e(n,t,lo,hi)
                        LEFT JOIN [#SsisLegacyLogAnalysis_Columns] AS c ON c.ColumnName=e.n COLLATE SQL_Latin1_General_CP1_CS_AS
                        WHERE c.ColumnName IS NULL OR c.TypeId<>e.t OR c.MaxLength NOT BETWEEN e.lo AND e.hi OR c.IsComputed=1 OR (e.n=N'id' AND c.IsNullable=1)
                    ) OR (@IncludeMessages=1 AND NOT EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Columns] WHERE ColumnName=N'message' AND TypeId=231 AND (MaxLength=-1 OR MaxLength BETWEEN 2 AND 8000) AND IsComputed=0))
                    BEGIN
                        SELECT @Status='SOURCE_UNAVAILABLE',@Partial=1,@Continue=0;
                        UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=@Status,[IsPartial]=1,[Detail]=N'SOURCE_SCHEMA_UNSUPPORTED' WHERE [SourceOrdinal]=1;
                        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SOURCE_SCHEMA_UNSUPPORTED',N'sourceMetadata',N'Die eingeschlossene Projektion besitzt kein unterstütztes gespeichertes Schema.');
                    END;
                END;
                IF @Step=2
                BEGIN
                    SET @Sql=@UseDb+@LockSql+N'INSERT [#SsisLegacyLogAnalysis_Indexes]
                        SELECT i.index_id,CONVERT(bit,CASE WHEN i.type IN (1,2) AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0 AND EXISTS
                         (SELECT 1 FROM sys.index_columns AS ic WITH (NOLOCK) INNER JOIN sys.all_columns AS c WITH (NOLOCK) ON c.object_id=ic.object_id AND c.column_id=ic.column_id
                          WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND c.name COLLATE SQL_Latin1_General_CP1_CS_AS=N''executionid'') THEN 1 ELSE 0 END)
                        FROM sys.indexes AS i WITH (NOLOCK) WHERE i.object_id=@Obj;';
                    EXEC sys.sp_executesql @Sql,N'@Obj int',@Obj=@ObjectId;
                    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]='AVAILABLE',[ObservedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Indexes]),
                        [ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Indexes]),[Detail]=N'ADVISORY_INDEX_METADATA_ONLY' WHERE [SourceOrdinal]=2;
                    IF NOT EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Indexes] WHERE Supporting=1)
                        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SUPPORTING_INDEX_NOT_OBSERVED',N'sourceIndexes',N'Kein führender executionid-Index beobachtet; ein Scan ist möglich. Keine Indexpflicht oder Plangarantie.');
                END;
                IF @Step=3
                BEGIN
                    IF @IncludeMessages=1 AND @HighImpactConfirmed=0 AND EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Columns] WHERE ColumnName=N'message' AND MaxLength=-1)
                    BEGIN
                        SELECT @Status='INVALID_PARAMETER',@Partial=1,@Continue=0;
                        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'HIGH_IMPACT_CONFIRMATION_REQUIRED',N'sourceEvents',N'Die eingeschlossene MAX-Textquelle benötigt die ausdrückliche Bestätigung.');
                    END
                    ELSE
                    BEGIN
                        -- Only bounded identifiers are concatenated. Message opt-out has no source expression.
                        SET @Sql=@UseDb+@LockSql+N'
                          SELECT @Db=DB_ID(),@Obj=o.object_id,@Created=o.create_date FROM sys.all_objects AS o WITH (NOLOCK)
                          INNER JOIN sys.schemas AS s WITH (NOLOCK) ON s.schema_id=o.schema_id
                          WHERE s.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Sch AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Tab;
                          IF @Db=@ExpectedDb AND @Obj=@ExpectedObj AND @Created=@ExpectedCreated
                          BEGIN
                            INSERT [#SsisLegacyLogAnalysis_Buffer]
                            SELECT TOP (@Take) [id],[event],[source],[sourceid],[executionid],[starttime],[endtime],[datacode],'+
                            CASE WHEN @IncludeMessages=1 THEN N'[message]' ELSE N'CONVERT(nvarchar(max),NULL)' END+N'
                            FROM '+@Source+N' WITH (NOLOCK) WHERE [executionid]=@Id ORDER BY [id];
                            SELECT @Db=DB_ID(),@Obj=NULL,@Created=NULL;
                            SELECT @Obj=o.object_id,@Created=o.create_date FROM sys.all_objects AS o WITH (NOLOCK)
                            INNER JOIN sys.schemas AS s WITH (NOLOCK) ON s.schema_id=o.schema_id
                            WHERE s.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Sch AND o.name COLLATE SQL_Latin1_General_CP1_CS_AS=@Tab;
                          END;';
                        EXEC sys.sp_executesql @Sql,N'@Sch sysname,@Tab sysname,@Id uniqueidentifier,@Take bigint,@ExpectedDb int,@ExpectedObj int,@ExpectedCreated datetime,@Db int OUTPUT,@Obj int OUTPUT,@Created datetime OUTPUT',
                            @Sch=@LoggingSchema,@Tab=@LoggingTable,@Id=@ExecutionId,@Take=@Take,@ExpectedDb=@DatabaseId,@ExpectedObj=@ObjectId,@ExpectedCreated=@Created,
                            @Db=@CurrentDb OUTPUT,@Obj=@CurrentObject OUTPUT,@Created=@CurrentCreated OUTPUT;
                        IF @CurrentDb<>@DatabaseId OR @CurrentObject IS NULL OR @CurrentObject<>@ObjectId OR @CurrentCreated IS NULL OR @CurrentCreated<>@Created
                        BEGIN
                            SELECT @Status='ERROR_HANDLED',@Partial=1,@Continue=0;
                            INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SOURCE_IDENTITY_CHANGED',N'sourceEvents',N'Die Quellenidentität wurde zwischen den Zugriffen verändert. Der Puffer wurde verworfen.');
                        END
                        ELSE IF EXISTS(SELECT LogId FROM [#SsisLegacyLogAnalysis_Buffer] GROUP BY LogId HAVING COUNT_BIG(*)>1)
                        BEGIN
                            SELECT @Status='ERROR_HANDLED',@Partial=1,@Continue=0;
                            INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'DUPLICATE_LOG_ID_OBSERVED',N'sourceEvents',N'Doppelte IDs im vollständigen N+1-Puffer; keine Deduplizierung oder erneute Abfrage.');
                        END;
                        IF @Continue=0
                        BEGIN
                            DELETE FROM [#SsisLegacyLogAnalysis_Buffer];
                            UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=@Status,[IsPartial]=1,[Detail]=N'BUFFER_INTEGRITY_REJECTED' WHERE SourceOrdinal=3;
                        END
                        ELSE
                        BEGIN
                            DECLARE @Observed bigint=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer]);
                            IF @Observed>@Limit
                            BEGIN
                                SET @Truncated=1;
                                DELETE FROM [#SsisLegacyLogAnalysis_Buffer] WHERE LogId NOT IN(SELECT TOP (@Limit) LogId FROM [#SsisLegacyLogAnalysis_Buffer] ORDER BY LogId);
                                INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SOURCE_EVENTS_TRUNCATED',N'sourceEvents',N'N+1 ist eine Untergrenze; nur die ersten N Ereignisse werden abgeleitet.');
                            END;
                            SET @ValidBuffer=1;
                            UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=CASE WHEN @Truncated=1 THEN 'AVAILABLE_LIMITED' WHEN @Observed=0 THEN 'AVAILABLE_EMPTY' ELSE 'AVAILABLE' END,
                                [IsPartial]=@Truncated,[IsTruncated]=@Truncated,[ObservedRowCount]=@Observed,[ReturnedRowCount]=(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer]),[Detail]=N'BOUNDED_EVENT_BUFFER' WHERE SourceOrdinal=3;
                            IF @Observed=0 INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'EXECUTION_NOT_VISIBLE_OR_ABSENT',N'sourceEvents',N'Keine sichtbaren Ereignisse für diese ID; Abwesenheit der Ausführung ist nicht bewiesen.');
                        END;
                    END;
                END;
                IF @Step=4 AND @ValidBuffer=1
                BEGIN
                    INSERT [#SsisLegacyLogAnalysis_Timeline]
                    SELECT ROW_NUMBER() OVER(ORDER BY LogId),LogId,ExecutionId,EventName,SourceName,SourceId,EventTime,RawEndTime,DataCode,
                        LAG(LogId) OVER(ORDER BY LogId),
                        CASE WHEN EventTime>=LAG(EventTime) OVER(ORDER BY LogId) THEN DATEDIFF_BIG(millisecond,LAG(EventTime) OVER(ORDER BY LogId),EventTime) END,
                        CASE EventName WHEN N'OnError' THEN 'ERROR' WHEN N'OnTaskFailed' THEN 'WARNING' WHEN N'OnWarning' THEN 'WARNING'
                             WHEN NULL THEN 'UNKNOWN' ELSE CASE WHEN EventName IS NULL THEN 'UNKNOWN' ELSE 'INFO' END END,MessageText
                    FROM [#SsisLegacyLogAnalysis_Buffer];
                    INSERT [#SsisLegacyLogAnalysis_ErrorChain]
                    SELECT ROW_NUMBER() OVER(ORDER BY LogId),LogId,ExecutionId,EventName,SourceName,SourceId,EventTime,DataCode,Severity,
                        LAG(LogId) OVER(ORDER BY LogId),'TEMPORAL_ONLY',MessageText
                    FROM [#SsisLegacyLogAnalysis_Timeline] WHERE EventName IN(N'OnError',N'OnTaskFailed',N'OnWarning',N'OnQueryCancel');

                    ;WITH e AS
                    (
                        SELECT LogId,SourceId,SourceName,EventTime,
                            CONVERT(varchar(16),CASE WHEN EventName IN(N'OnPreValidate',N'OnPostValidate') THEN 'VALIDATE'
                                 WHEN EventName IN(N'OnPreExecute',N'OnPostExecute') THEN 'EXECUTE' ELSE 'PACKAGE' END) COLLATE SQL_Latin1_General_CP1_CS_AS AS PairKind,
                            CONVERT(bit,CASE WHEN EventName IN(N'OnPreValidate',N'OnPreExecute',N'PackageStart') THEN 1 ELSE 0 END) AS IsStart
                        FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IN(N'OnPreValidate',N'OnPostValidate',N'OnPreExecute',N'OnPostExecute',N'PackageStart',N'PackageEnd')
                    )
                    INSERT [#SsisLegacyLogAnalysis_Pairs]
                    SELECT LogId,SourceId,SourceName,PairKind,IsStart,EventTime,
                        ROW_NUMBER() OVER(PARTITION BY SourceId,PairKind ORDER BY LogId),
                        LAG(IsStart) OVER(PARTITION BY SourceId,PairKind ORDER BY LogId),LEAD(IsStart) OVER(PARTITION BY SourceId,PairKind ORDER BY LogId),
                        LEAD(LogId) OVER(PARTITION BY SourceId,PairKind ORDER BY LogId),LEAD(EventTime) OVER(PARTITION BY SourceId,PairKind ORDER BY LogId)
                    FROM e;
                    ;WITH p AS
                    (
                        SELECT *,MAX(CASE WHEN IsStart=PreviousStart THEN 1 ELSE 0 END) OVER(PARTITION BY SourceId,PairKind) AS Ambiguous
                        FROM [#SsisLegacyLogAnalysis_Pairs]
                    ), r AS
                    (
                        SELECT SourceId,SourceName,PairKind,LogId,EventTime,IsStart,NextLogId,NextTime,
                            CONVERT(varchar(40),CASE WHEN SourceId IS NULL THEN 'UNRESOLVED_SOURCE' WHEN Ambiguous=1 THEN 'AMBIGUOUS'
                                WHEN IsStart=0 THEN 'END_ONLY' WHEN NextStart IS NULL THEN 'START_ONLY'
                                WHEN EventTime IS NULL OR NextTime IS NULL THEN 'PAIRED_TIME_UNKNOWN'
                                WHEN NextTime<EventTime THEN 'NON_MONOTONIC_TIME' ELSE 'PAIRED' END) COLLATE SQL_Latin1_General_CP1_CS_AS AS PairStatus
                        FROM p WHERE SourceId IS NULL OR Ambiguous=1 OR IsStart=1 OR PreviousStart IS NULL
                    )
                    INSERT [#SsisLegacyLogAnalysis_Iterations]
                    SELECT ROW_NUMBER() OVER(ORDER BY SourceId,PairKind,LogId),@ExecutionId,SourceId,SourceName,PairKind,
                        CASE WHEN IsStart=1 THEN LogId END,
                        CASE WHEN IsStart=0 THEN LogId WHEN PairStatus IN('PAIRED','PAIRED_TIME_UNKNOWN','NON_MONOTONIC_TIME') THEN NextLogId END,
                        CASE WHEN IsStart=1 THEN EventTime END,
                        CASE WHEN IsStart=0 THEN EventTime WHEN PairStatus IN('PAIRED','PAIRED_TIME_UNKNOWN','NON_MONOTONIC_TIME') THEN NextTime END,
                        CASE WHEN PairStatus='PAIRED' THEN DATEDIFF_BIG(millisecond,EventTime,NextTime) END,PairStatus,@Truncated
                    FROM r;

                    IF EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer])
                    BEGIN
                        DECLARE @Boundary varchar(40)='AMBIGUOUS',@PackageStart int=NULL,@PackageEnd int=NULL,@PackageMs bigint=NULL;
                        IF NOT EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairKind='PACKAGE') SET @Boundary='ABSENT';
                        ELSE IF (SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairKind='PACKAGE')=1
                        BEGIN
                            SELECT @Boundary=CASE WHEN PairStatus IN('PAIRED','START_ONLY','END_ONLY') THEN PairStatus ELSE 'AMBIGUOUS' END,
                                @PackageStart=StartLogId,@PackageEnd=EndLogId,@PackageMs=DurationMs
                            FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairKind='PACKAGE';
                        END;
                        INSERT [#SsisLegacyLogAnalysis_Execution]
                        SELECT @ExecutionId,COUNT_BIG(*),COUNT_BIG(DISTINCT SourceId),MIN(EventTime),MAX(EventTime),
                            SUM(CONVERT(bigint,CASE WHEN EventName=N'OnError' THEN 1 ELSE 0 END)),
                            SUM(CONVERT(bigint,CASE WHEN EventName=N'OnWarning' THEN 1 ELSE 0 END)),
                            SUM(CONVERT(bigint,CASE WHEN EventName=N'OnTaskFailed' THEN 1 ELSE 0 END)),
                            SUM(CONVERT(bigint,CASE WHEN EventName=N'OnQueryCancel' THEN 1 ELSE 0 END)),
                            @Boundary,@PackageStart,@PackageEnd,CASE WHEN @Boundary='PAIRED' THEN @PackageMs END,
                            CASE WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName=N'OnError') THEN 'ERROR_EVENT_OBSERVED'
                                 WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName=N'OnTaskFailed') THEN 'TASK_FAILURE_OBSERVED'
                                 WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName=N'OnQueryCancel') THEN 'CANCEL_REQUEST_OBSERVED'
                                 WHEN @Boundary='PAIRED' THEN 'COMPLETION_EVENT_PAIR_OBSERVED' ELSE 'INCOMPLETE_OR_UNRESOLVED' END,
                            NULL,NULL,CONVERT(bit,1-@Truncated)
                        FROM [#SsisLegacyLogAnalysis_Buffer];
                        UPDATE e SET FirstErrorLogId=b.LogId,FirstErrorMessage=b.MessageText
                        FROM [#SsisLegacyLogAnalysis_Execution] AS e CROSS APPLY
                          (SELECT TOP (1) LogId,MessageText FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IN(N'OnError',N'OnTaskFailed')
                           ORDER BY CASE WHEN EventName=N'OnError' THEN 0 ELSE 1 END,LogId) AS b;

                        INSERT [#SsisLegacyLogAnalysis_LoggingQuality]
                        SELECT 0,v.Code,v.Severity,v.Affected,v.Detail
                        FROM (VALUES
                          ('EVENT_BUFFER_TRUNCATED','WARNING',CONVERT(bigint,NULL),N'Der N+1-Puffer ist ein begrenzter Ausschnitt.',CONVERT(int,@Truncated)),
                          ('PACKAGE_BOUNDARY_ABSENT','INFO',CONVERT(bigint,NULL),N'Kein PackageStart-/PackageEnd-Ereignis beobachtet.',CASE WHEN @Boundary='ABSENT' THEN 1 ELSE 0 END),
                          ('PACKAGE_BOUNDARY_UNRESOLVED','WARNING',CONVERT(bigint,NULL),N'Keine eindeutige zeitlich gültige Paketgrenze.',CASE WHEN @Boundary NOT IN('PAIRED','ABSENT') THEN 1 ELSE 0 END),
                          ('PAIRING_AMBIGUOUS','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairStatus='AMBIGUOUS'),N'Mehrdeutige Ereignisfolgen werden nicht willkürlich gepaart.',1),
                          ('PAIRING_INCOMPLETE','WARNING',(SELECT COUNT_BIG(DISTINCT COALESCE(StartLogId,EndLogId)) FROM [#SsisLegacyLogAnalysis_Iterations] WHERE PairStatus IN('START_ONLY','END_ONLY')),N'Ungepaarte beobachtete Start- oder Endereignisse; kein Nachweis eines nicht beendeten Tasks.',1),
                          ('SOURCE_ID_MISSING','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE SourceId IS NULL),N'Ereignisse ohne Source-ID erlauben keine sichere Paarzuordnung.',1),
                          ('EVENT_NAME_MISSING','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IS NULL),N'Ein Ereignisname fehlt.',1),
                          ('EVENT_TIME_MISSING','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventTime IS NULL),N'Ein Ereigniszeitpunkt fehlt.',1),
                          ('NON_MONOTONIC_TIME','WARNING',(SELECT COUNT_BIG(*) FROM (SELECT EventTime,LAG(EventTime) OVER(ORDER BY LogId) AS PreviousTime FROM [#SsisLegacyLogAnalysis_Buffer]) AS b WHERE EventTime<PreviousTime),N'Zeitwerte sind gegenüber der protokollierten ID-Reihenfolge rückläufig.',1),
                          ('UNKNOWN_EVENT_NAME','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName NOT IN(N'OnError',N'OnTaskFailed',N'OnWarning',N'OnQueryCancel',N'OnPreValidate',N'OnPostValidate',N'OnPreExecute',N'OnPostExecute',N'PackageStart',N'PackageEnd')),N'Der gespeicherte Ereignisname besitzt hier keine eigene Interpretation.',1),
                          ('NO_ERROR_EVENTS_OBSERVED','INFO',CONVERT(bigint,NULL),N'Kein OnError beobachtet; kein Nachweis von Fehlerfreiheit.',CASE WHEN NOT EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName=N'OnError') THEN 1 ELSE 0 END),
                          ('ERROR_MESSAGE_MISSING','WARNING',(SELECT COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IN(N'OnError',N'OnTaskFailed') AND (MessageText IS NULL OR DATALENGTH(MessageText)=0)),N'Ein eingeschlossener Fehlertext fehlt oder ist leer; die Ursache bleibt unbekannt.',CONVERT(int,@IncludeMessages))
                        ) AS v(Code,Severity,Affected,Detail,Enabled) WHERE v.Enabled=1 AND (v.Affected IS NULL OR v.Affected>0);
                    END;
                    INSERT [#SsisLegacyLogAnalysis_LoggingQuality] VALUES(0,'CONSISTENT_SNAPSHOT_NOT_GUARANTEED','INFO',NULL,N'NOLOCK liefert keine transaktionskonsistente Momentaufnahme.');
                    ;WITH q AS(SELECT *,ROW_NUMBER() OVER(ORDER BY QualityCode) AS n FROM [#SsisLegacyLogAnalysis_LoggingQuality]) UPDATE q SET QualityOrdinal=CONVERT(int,n);
                    INSERT [#SsisLegacyLogAnalysis_Findings]
                    SELECT 0,CASE EventName WHEN N'OnError' THEN 'LEGACY_ERROR_EVENT' WHEN N'OnTaskFailed' THEN 'LEGACY_TASK_FAILED_EVENT' ELSE 'LEGACY_CANCEL_REQUEST' END,
                        CASE EventName WHEN N'OnError' THEN 'ERROR' WHEN N'OnTaskFailed' THEN 'WARNING' ELSE 'INFO' END,@ExecutionId,'RUNTIME_OBSERVED',N'Legacy event buffer',LogId,
                        N'Das Ereignis ist im begrenzten Logpuffer beobachtet; Meldungstext und zeitliche Folge belegen keine technische Root Cause.'
                    FROM [#SsisLegacyLogAnalysis_Buffer] WHERE EventName IN(N'OnError',N'OnTaskFailed',N'OnQueryCancel');
                    INSERT [#SsisLegacyLogAnalysis_Findings]
                    SELECT 0,QualityCode,Severity,@ExecutionId,'DERIVED',N'Legacy event buffer',NULL,Detail FROM [#SsisLegacyLogAnalysis_LoggingQuality] WHERE Severity='WARNING';
                    ;WITH f AS(SELECT *,ROW_NUMBER() OVER(ORDER BY CASE WHEN LogId IS NULL THEN 1 ELSE 0 END,LogId,FindingCode) AS n FROM [#SsisLegacyLogAnalysis_Findings]) UPDATE f SET FindingOrdinal=CONVERT(int,n);
                    DECLARE @DerivedPartial bit=CASE WHEN @Truncated=1 OR EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_LoggingQuality] WHERE Severity='WARNING') THEN 1 ELSE 0 END;
                    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=CASE WHEN @DerivedPartial=1 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,
                        [IsPartial]=@DerivedPartial,[Detail]=N'DERIVATION_COMPLETE' WHERE SourceOrdinal=4;
                END;
            END TRY
            BEGIN CATCH
                DECLARE @NativeError int=ERROR_NUMBER(),@NativeMessage nvarchar(4000)=ERROR_MESSAGE();
                DECLARE @NativeStatus varchar(40)=CASE WHEN @NativeError IN(229,262,297,300,371) THEN 'DENIED'
                    WHEN @NativeError IN(207,208,911,916,942) THEN 'SOURCE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END;
                UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET [StatusCode]=@NativeStatus,[IsPartial]=1,[ErrorNumber]=@NativeError,[ErrorMessage]=@NativeMessage,
                    [ObservedRowCount]=NULL,[ReturnedRowCount]=NULL,[IsTruncated]=0,[Detail]=N'NATIVE_SOURCE_ERROR' WHERE SourceOrdinal=@Step;
                IF @Error IS NULL SELECT @Error=@NativeError,@Message=@NativeMessage;
                SET @Partial=1;
                IF @Step=2
                    INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'SOURCE_INDEX_METADATA_UNAVAILABLE',N'sourceIndexes',N'Die beratende Indexdiagnose ist fehlgeschlagen; die erforderliche Ereignissammlung wird fortgesetzt.');
                ELSE SELECT @Status=@NativeStatus,@Continue=0;
                IF @Step=3 DELETE FROM [#SsisLegacyLogAnalysis_Buffer];
                IF @Step=4
                BEGIN
                    DELETE FROM [#SsisLegacyLogAnalysis_Execution];
                    DELETE FROM [#SsisLegacyLogAnalysis_Timeline];
                    DELETE FROM [#SsisLegacyLogAnalysis_ErrorChain];
                    DELETE FROM [#SsisLegacyLogAnalysis_Iterations];
                    DELETE FROM [#SsisLegacyLogAnalysis_LoggingQuality];
                    DELETE FROM [#SsisLegacyLogAnalysis_Findings];
                END;
            END CATCH;
            UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET CollectionTimeUtc=SYSUTCDATETIME() WHERE SourceOrdinal=@Step;
            SET @Step+=1;
        END;
        EXEC sys.sp_executesql @RestoreLock;
        IF @PreviousAbort=1 SET XACT_ABORT ON;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_executesql @RestoreLock;
        IF @PreviousAbort=1 SET XACT_ABORT ON;
        THROW;
    END CATCH;

    IF @IncludeTimeline=0 DELETE FROM [#SsisLegacyLogAnalysis_Timeline];
    DECLARE @Detail nvarchar(2000)=N'',@Before bigint,@After bigint,@TotalBefore bigint=0,@TotalAfter bigint=0,@AnyTruncation bit=0;
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Timeline];
    DELETE FROM [#SsisLegacyLogAnalysis_Timeline] WHERE [TimelineOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Timeline];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'timeline',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'timeline:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_ErrorChain];
    DELETE FROM [#SsisLegacyLogAnalysis_ErrorChain] WHERE [ErrorOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_ErrorChain];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'errorChain',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'errorChain:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Iterations];
    DELETE FROM [#SsisLegacyLogAnalysis_Iterations] WHERE [IterationOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Iterations];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'iterations',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'iterations:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_LoggingQuality];
    DELETE FROM [#SsisLegacyLogAnalysis_LoggingQuality] WHERE [QualityOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_LoggingQuality];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'loggingQuality',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'loggingQuality:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    SELECT @Before=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Findings];
    DELETE FROM [#SsisLegacyLogAnalysis_Findings] WHERE [FindingOrdinal]>@Limit;
    SELECT @After=COUNT_BIG(*) FROM [#SsisLegacyLogAnalysis_Findings];
    IF @Before>@After
    BEGIN
        SET @AnyTruncation=1;
        INSERT [#SsisLegacyLogAnalysis_Warnings] VALUES(0,'RESULT_TRUNCATED',N'findings',N'Die Fachdetailmenge ist auf die angeforderte Zeilenzahl begrenzt.');
    END;
    SELECT @TotalBefore+=@Before,@TotalAfter+=@After,
        @Detail+=N'findings:Observed='+CONVERT(nvarchar(20),@Before)+N';Returned='+CONVERT(nvarchar(20),@After)+N';Truncated='+CASE WHEN @Before>@After THEN N'1' ELSE N'0' END+N' ';
    UPDATE [#SsisLegacyLogAnalysis_SourceStatus] SET ObservedRowCount=@TotalBefore,ReturnedRowCount=@TotalAfter,
        IsTruncated=@AnyTruncation,IsPartial=CASE WHEN @AnyTruncation=1 THEN 1 ELSE IsPartial END,
        StatusCode=CASE WHEN @AnyTruncation=1 THEN 'AVAILABLE_LIMITED' ELSE StatusCode END,Detail=RTRIM(@Detail)
    WHERE SourceOrdinal=4 AND StatusCode IN('AVAILABLE','AVAILABLE_LIMITED');
    IF @Continue=1
    BEGIN
        SELECT @Partial=CASE WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_SourceStatus] WHERE IsPartial=1) THEN 1 ELSE 0 END;
        SELECT @Status=CASE WHEN @Partial=1 THEN 'AVAILABLE_LIMITED'
            WHEN EXISTS(SELECT 1 FROM [#SsisLegacyLogAnalysis_Execution]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END;
    END;
    ;WITH w AS(SELECT *,ROW_NUMBER() OVER(ORDER BY WarningCode,SourceName) AS n FROM [#SsisLegacyLogAnalysis_Warnings]) UPDATE w SET WarningOrdinal=CONVERT(int,n);
    INSERT [#SsisLegacyLogAnalysis_ModuleStatus]
    VALUES(N'USP_SsisLegacyLogAnalysis',1,@LoggingDatabase,@LoggingSchema,@LoggingTable,@ExecutionId,@IncludeMessages,@Status,@Partial,@Error,@Message,@Now);
    SELECT @StatusCodeOut=@Status,@IsPartialOut=@Partial,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
    IF COALESCE(@JsonErzeugen,0)=1
        SELECT @Json=(SELECT
            JSON_QUERY((SELECT N'USP_SsisLegacyLogAnalysis' AS ModuleName,1 AS SchemaVersion,@Now AS CollectionTimeUtc,@Status AS StatusCode,@Partial AS IsPartial FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER)) AS [meta]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_ModuleStatus] ORDER BY [ModuleName] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [moduleStatus]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Execution] ORDER BY [ExecutionId] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [execution]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Timeline] ORDER BY [TimelineOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [timeline]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_ErrorChain] ORDER BY [ErrorOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [errorChain]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Iterations] ORDER BY [IterationOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [iterations]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_LoggingQuality] ORDER BY [QualityOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [loggingQuality]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Findings] ORDER BY [FindingOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [findings]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_SourceStatus] ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [sourceStatus]
          , JSON_QUERY(COALESCE((SELECT * FROM [#SsisLegacyLogAnalysis_Warnings] ORDER BY [WarningOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS [warnings]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    IF @OutputMode='TABLE'
    BEGIN
        DECLARE @TargetTable sysname;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'moduleStatus'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_ModuleStatus',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'execution'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Execution',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'timeline'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Timeline',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'errorChain'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_ErrorChain',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'iterations'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Iterations',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'loggingQuality'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_LoggingQuality',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'findings'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Findings',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'sourceStatus'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_SourceStatus',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT TargetTable FROM [#SsisLegacyLogAnalysis_ResultTables] WHERE ResultName=N'warnings'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisLegacyLogAnalysis_Warnings',@TargetTable,@ThrowOnError=1;
    END;
    IF @OutputMode='RAW'
    BEGIN
        SELECT * FROM [#SsisLegacyLogAnalysis_ModuleStatus] ORDER BY [ModuleName];
        SELECT * FROM [#SsisLegacyLogAnalysis_Execution] ORDER BY [ExecutionId];
        SELECT * FROM [#SsisLegacyLogAnalysis_Timeline] ORDER BY [TimelineOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_ErrorChain] ORDER BY [ErrorOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_Iterations] ORDER BY [IterationOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_LoggingQuality] ORDER BY [QualityOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_Findings] ORDER BY [FindingOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_SourceStatus] ORDER BY [SourceOrdinal];
        SELECT * FROM [#SsisLegacyLogAnalysis_Warnings] ORDER BY [WarningOrdinal];
    END;
    IF @ConsoleResultRequested=1
    BEGIN
        CREATE TABLE [#SsisLegacyLogAnalysis_Console]
        ([Status] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Unvollständig] bit NOT NULL,[ExecutionId] uniqueidentifier NULL,
         [AnalysierteEreignisse] bigint NULL,[BeobachteterAusgang] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErsteFehlerLogId] int NULL,
         [ErsterFehlertext] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErsterZeitpunkt] datetime NULL,[LetzterZeitpunkt] datetime NULL,
         [Hinweis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        INSERT [#SsisLegacyLogAnalysis_Console]
        SELECT m.StatusCode,m.IsPartial,m.ExecutionId,e.AnalyzedEventCount,e.ObservedOutcome,e.FirstErrorLogId,e.FirstErrorMessage,e.FirstObservedTime,e.LastObservedTime,
            N'Beobachteter Logausschnitt; Quellenstatus und Grenzen beachten. Kein Nachweis einer technischen Root Cause.'
        FROM [#SsisLegacyLogAnalysis_ModuleStatus] AS m LEFT JOIN [#SsisLegacyLogAnalysis_Execution] AS e ON e.ExecutionId=m.ExecutionId;
        EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#SsisLegacyLogAnalysis_Console',@ResultLabel=N'SSIS-Legacy-Ausführung',@EmptyMessage=N'Keine sichtbare Legacy-Ausführung';
    END;
END;
GO
