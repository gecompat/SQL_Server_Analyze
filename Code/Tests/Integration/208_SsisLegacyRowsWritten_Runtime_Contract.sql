USE [DeineDatenbank];
GO
-- Synthetic RowsWritten contract; no SSIS package or provider execution.
DECLARE @OuterOptions int=@@OPTIONS,@OuterLock int=@@LOCK_TIMEOUT,@OuterTran int=@@TRANCOUNT;
DECLARE @TableId int=NULL,@UserId int=NULL,@Impersonated bit=0,@Db sysname=DB_NAME();
IF OBJECT_ID(N'dbo.ExampleRowsWrittenLogSource') IS NOT NULL OR DATABASE_PRINCIPAL_ID(N'ExampleRowsWrittenReader') IS NOT NULL
    THROW 56890,N'W_FIXTURE_COLLISION',1;
BEGIN TRY
    CREATE TABLE dbo.ExampleRowsWrittenLogSource
    (id int NOT NULL,event nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
     source nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,sourceid uniqueidentifier NULL,
     executionid uniqueidentifier NOT NULL,starttime datetime NULL,endtime datetime NULL,datacode int NULL,
     message nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    SET @TableId=OBJECT_ID(N'dbo.ExampleRowsWrittenLogSource');
    DECLARE @Id uniqueidentifier=NEWID(),@Source uniqueidentifier=NEWID(),@ChosenSource uniqueidentifier,
        @T datetime='20000101',@EventTime datetime,@J nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(4000),
        @F int=0,@Task bit,@Row bit,@Phase bit,@Life bit,@Lookup bit,@Written bit,@ExpectedVersion int;
    WHILE @F<64
    BEGIN
        SELECT @Task=CONVERT(bit,@F&1),@Row=CONVERT(bit,@F&2),@Phase=CONVERT(bit,@F&4),
            @Life=CONVERT(bit,@F&8),@Lookup=CONVERT(bit,@F&16),@Written=CONVERT(bit,@F&32);
        EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N'ExampleRowsWrittenLogSource',@ExecutionId=@Id,@HighImpactConfirmed=1,
            @IncludeTaskAnalysis=@Task,@IncludeRowFlowAnalysis=@Row,@IncludeComponentPhaseAnalysis=@Phase,
            @IncludeComponentLifecyclePhases=@Life,@IncludeLookupCacheAnalysis=@Lookup,@IncludeRowsWrittenAnalysis=@Written,
            @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
        SET @ExpectedVersion=CASE WHEN @Written=1 THEN 7 WHEN @Lookup=1 THEN 6 WHEN @Phase=1 THEN CASE WHEN @Life=1 THEN 5 ELSE 4 END WHEN @Row=1 THEN 3 WHEN @Task=1 THEN 2 ELSE 1 END;
        IF TRY_CONVERT(int,JSON_VALUE(@J,'$.meta.SchemaVersion'))<>@ExpectedVersion THROW 56801,N'W_FLAG_VERSION',1;
        IF (@Life=1 AND @Phase=0 AND @Status<>'INVALID_PARAMETER') OR (@Life=0 AND @Status='INVALID_PARAMETER') THROW 56802,N'W_FLAG_DEPENDENCY',1;
        IF (@Written=1 AND (ISNULL(JSON_QUERY(@J,'$.rowsWrittenEvents'),N'MISSING')<>N'[]' OR ISNULL(JSON_VALUE(@J,'$.meta.RowsWrittenCatalogVersion'),N'MISSING')<>N'1'))
           OR (@Written=0 AND (JSON_QUERY(@J,'$.rowsWrittenEvents') IS NOT NULL OR JSON_VALUE(@J,'$.meta.RowsWrittenCatalogVersion') IS NOT NULL)) THROW 56803,N'W_FLAG_ARRAY',1;
        SET @F+=1;
    END;
    CREATE TABLE #ExampleWriteCases(CaseId int,Label varchar(40),Payload nvarchar(max),EventName nvarchar(128),Code int,Parser varchar(32),ParseStatus varchar(40),ComponentName nvarchar(4000),RowsReported bigint,ContextStatus varchar(40),SourceKind varchar(16),TimeKind varchar(16),HasEnd bit);
    INSERT #ExampleWriteCases VALUES
(1,N'normal',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'ExampleSink',3,N'ASSIGNED',N'NORMAL',N'NORMAL',1),
(2,N'zero',N'"ExampleSink" wrote 0 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'ExampleSink',0,N'ASSIGNED',N'NORMAL',N'NORMAL',1),
(3,N'bigint-end',N'"ExampleSink" wrote 9223372036854775807 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'ExampleSink',9223372036854775807,N'ASSIGNED',N'NORMAL',N'NORMAL',1),
(4,N'overflow',N'"ExampleSink" wrote 9223372036854775808 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'NUMERIC_OUT_OF_RANGE',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(5,N'negative',N'"ExampleSink" wrote -1 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(6,N'plus',N'"ExampleSink" wrote +3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(7,N'leading-zero',N'"ExampleSink" wrote 03 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(8,N'decimal',N'"ExampleSink" wrote 3.0 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(9,N'group',N'"ExampleSink" wrote 3,000 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(10,N'empty',N'"ExampleSink" wrote  rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(11,N'space',N'"ExampleSink" wrote  3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(12,N'case',N'"ExampleSink" Wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(13,N'lf',N'"ExampleSink" wrote 3 rows.'+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(14,N'no-end',N'"ExampleSink" wrote 3 rows.',N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(15,N'tail',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10)+N'x',N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(16,N'no-quotes',N'ExampleSink wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(17,N'empty-name',N'"" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(18,N'quoted-name',N'"Example"Sink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(19,N'nul-name',N'"Example'+NCHAR(0)+N'Sink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(20,N'c1-name',N'"Example'+NCHAR(128)+N'Sink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(21,N'unicode-brackets',N'"Example Ziel [ä]" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'Example Ziel [ä]',3,N'ASSIGNED',N'NORMAL',N'NORMAL',1),
(22,N'name-space',N'"ExampleSink " wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'ExampleSink ',3,N'ASSIGNED',N'NORMAL',N'NORMAL',1),
(23,N'surrogate',N'"Example 😀" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'Example 😀',3,N'ASSIGNED',N'NORMAL',N'NORMAL',1),
(24,N'nul-number',N'"ExampleSink" wrote 3'+NCHAR(0)+N' rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'MALFORMED_PAYLOAD',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(25,N'null-message',NULL,N'OnInformation',1074016267,NULL,N'MESSAGE_MISSING',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(26,N'capacity',REPLICATE(CONVERT(nvarchar(max),N'x'),2048),N'OnInformation',1074016267,NULL,N'POTENTIALLY_TRUNCATED',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(27,N'wrong-event',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnWarning',1074016267,NULL,N'CODE_EVENT_MISMATCH',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(28,N'null-event',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),NULL,1074016267,NULL,N'CODE_EVENT_MISMATCH',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(29,N'wrong-code',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016268,NULL,N'EXCLUDED',NULL,NULL,N'NOT_PARSED',N'NORMAL',N'NORMAL',1),
(30,N'null-source',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'ExampleSink',3,N'SOURCE_ID_MISSING',N'NULL',N'NORMAL',1),
(31,N'zero-source',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'ExampleSink',3,N'SOURCE_ID_MISSING',N'ZERO',N'NORMAL',1),
(32,N'null-time',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'ExampleSink',3,N'EVENT_TIME_MISSING',N'NORMAL',N'NULL',1),
(33,N'time-outside',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'ExampleSink',3,N'TIME_OUTSIDE_PAIR',N'NORMAL',N'OUTSIDE',1),
(34,N'no-pair',N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10),N'OnInformation',1074016267,N'ROWS_WRITTEN_EN_1',N'PARSED',N'ExampleSink',3,N'NO_OBSERVED_PAIR',N'NORMAL',N'NORMAL',0);
    CREATE TABLE #ExampleWriteExpected
    ([RowsWrittenEventOrdinal] bigint NOT NULL,
    [LogId] int NOT NULL,
    [ExecutionId] uniqueidentifier NOT NULL,
    [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SourceId] uniqueidentifier NULL,
    [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EventTime] datetime NULL,
    [DataCode] int NULL,
    [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ObservationKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ReportedRows] bigint NULL,
    [DiagnosticCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ContextStartLogId] int NULL,
    [ContextEndLogId] int NULL,
    [InputIsTruncated] bit NOT NULL,
    [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE #ExampleWriteActual
    ([RowsWrittenEventOrdinal] bigint NOT NULL,
    [LogId] int NOT NULL,
    [ExecutionId] uniqueidentifier NOT NULL,
    [EventName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SourceId] uniqueidentifier NULL,
    [SourceName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EventTime] datetime NULL,
    [DataCode] int NULL,
    [ParserId] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ParseStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ObservationKind] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ComponentName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ReportedRows] bigint NULL,
    [DiagnosticCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ContextStartLogId] int NULL,
    [ContextEndLogId] int NULL,
    [InputIsTruncated] bit NOT NULL,
    [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EvidenceSource] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    DECLARE @Case int=1,@Label varchar(40),@Payload nvarchar(max),@EventName nvarchar(128),@Code int,
        @Parser varchar(32),@Parse varchar(40),@Name nvarchar(4000),@Rows bigint,@Context varchar(40),@SourceKind varchar(16),@TimeKind varchar(16),@HasEnd bit;
    WHILE @Case<=34
    BEGIN
        SELECT @Label=Label,@Payload=Payload,@EventName=EventName,@Code=Code,@Parser=Parser,@Parse=ParseStatus,
            @Name=ComponentName,@Rows=RowsReported,@Context=ContextStatus,@SourceKind=SourceKind,@TimeKind=TimeKind,@HasEnd=HasEnd FROM #ExampleWriteCases WHERE CaseId=@Case;
        SELECT @ChosenSource=CASE @SourceKind WHEN 'NULL' THEN NULL WHEN 'ZERO' THEN '00000000-0000-0000-0000-000000000000' ELSE @Source END,
            @EventTime=CASE @TimeKind WHEN 'NULL' THEN NULL WHEN 'OUTSIDE' THEN DATEADD(second,4,@T) ELSE DATEADD(second,1,@T) END;
        DELETE dbo.ExampleRowsWrittenLogSource;
        INSERT dbo.ExampleRowsWrittenLogSource VALUES(10,N'OnPreExecute',N'ExampleDataFlow',@Source,@Id,@T,@T,0,N''),
            (20,@EventName,N'ExampleDataFlow',@ChosenSource,@Id,@EventTime,@EventTime,@Code,@Payload);
        IF @HasEnd=1 INSERT dbo.ExampleRowsWrittenLogSource VALUES(30,N'OnPostExecute',N'ExampleDataFlow',@Source,@Id,DATEADD(second,2,@T),DATEADD(second,2,@T),0,N'');
        EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N'ExampleRowsWrittenLogSource',@ExecutionId=@Id,@HighImpactConfirmed=1,@IncludeRowsWrittenAnalysis=1,
            @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0;
        DELETE #ExampleWriteExpected;DELETE #ExampleWriteActual;
        IF @Parse<>'EXCLUDED'
            INSERT #ExampleWriteExpected VALUES(1,20,@Id,@EventName,@ChosenSource,N'ExampleDataFlow',@EventTime,@Code,@Parser,@Parse,
                CASE WHEN @Parse='PARSED' THEN 'ROWS_WRITTEN' END,@Name,@Rows,CASE WHEN @Parse='PARSED' THEN 'DTS_I_ROWS_WRITTEN' END,
                @Context,CASE WHEN @Context='ASSIGNED' THEN 10 END,CASE WHEN @Context='ASSIGNED' THEN 30 END,0,
                CASE WHEN @Parse='PARSED' THEN 'RUNTIME_OBSERVED' ELSE 'UNINTERPRETED' END,N'Legacy event buffer',@Payload);
        INSERT #ExampleWriteActual SELECT [RowsWrittenEventOrdinal], [LogId], [ExecutionId], [EventName], [SourceId], [SourceName], [EventTime], [DataCode], [ParserId], [ParseStatus], [ObservationKind], [ComponentName], [ReportedRows], [DiagnosticCode], [ContextStatus], [ContextStartLogId], [ContextEndLogId], [InputIsTruncated], [EvidenceLevel], [EvidenceSource], [MessageText] FROM OPENJSON(@J,'$.rowsWrittenEvents') WITH([RowsWrittenEventOrdinal] bigint '$.RowsWrittenEventOrdinal', [LogId] int '$.LogId', [ExecutionId] uniqueidentifier '$.ExecutionId', [EventName] nvarchar(128) '$.EventName', [SourceId] uniqueidentifier '$.SourceId', [SourceName] nvarchar(4000) '$.SourceName', [EventTime] datetime '$.EventTime', [DataCode] int '$.DataCode', [ParserId] varchar(32) '$.ParserId', [ParseStatus] varchar(40) '$.ParseStatus', [ObservationKind] varchar(40) '$.ObservationKind', [ComponentName] nvarchar(4000) '$.ComponentName', [ReportedRows] bigint '$.ReportedRows', [DiagnosticCode] varchar(64) '$.DiagnosticCode', [ContextStatus] varchar(40) '$.ContextStatus', [ContextStartLogId] int '$.ContextStartLogId', [ContextEndLogId] int '$.ContextEndLogId', [InputIsTruncated] bit '$.InputIsTruncated', [EvidenceLevel] varchar(32) '$.EvidenceLevel', [EvidenceSource] nvarchar(160) '$.EvidenceSource', [MessageText] nvarchar(max) '$.MessageText');
        IF EXISTS(SELECT [RowsWrittenEventOrdinal] AS [RowsWrittenEventOrdinal], [LogId] AS [LogId], [ExecutionId] AS [ExecutionId], CONVERT(varbinary(max),[EventName]) AS [EventName], [SourceId] AS [SourceId], CONVERT(varbinary(max),[SourceName]) AS [SourceName], [EventTime] AS [EventTime], [DataCode] AS [DataCode], CONVERT(varbinary(max),[ParserId]) AS [ParserId], CONVERT(varbinary(max),[ParseStatus]) AS [ParseStatus], CONVERT(varbinary(max),[ObservationKind]) AS [ObservationKind], CONVERT(varbinary(max),[ComponentName]) AS [ComponentName], [ReportedRows] AS [ReportedRows], CONVERT(varbinary(max),[DiagnosticCode]) AS [DiagnosticCode], CONVERT(varbinary(max),[ContextStatus]) AS [ContextStatus], [ContextStartLogId] AS [ContextStartLogId], [ContextEndLogId] AS [ContextEndLogId], [InputIsTruncated] AS [InputIsTruncated], CONVERT(varbinary(max),[EvidenceLevel]) AS [EvidenceLevel], CONVERT(varbinary(max),[EvidenceSource]) AS [EvidenceSource], CONVERT(varbinary(max),[MessageText]) AS [MessageText] FROM #ExampleWriteExpected EXCEPT SELECT [RowsWrittenEventOrdinal] AS [RowsWrittenEventOrdinal], [LogId] AS [LogId], [ExecutionId] AS [ExecutionId], CONVERT(varbinary(max),[EventName]) AS [EventName], [SourceId] AS [SourceId], CONVERT(varbinary(max),[SourceName]) AS [SourceName], [EventTime] AS [EventTime], [DataCode] AS [DataCode], CONVERT(varbinary(max),[ParserId]) AS [ParserId], CONVERT(varbinary(max),[ParseStatus]) AS [ParseStatus], CONVERT(varbinary(max),[ObservationKind]) AS [ObservationKind], CONVERT(varbinary(max),[ComponentName]) AS [ComponentName], [ReportedRows] AS [ReportedRows], CONVERT(varbinary(max),[DiagnosticCode]) AS [DiagnosticCode], CONVERT(varbinary(max),[ContextStatus]) AS [ContextStatus], [ContextStartLogId] AS [ContextStartLogId], [ContextEndLogId] AS [ContextEndLogId], [InputIsTruncated] AS [InputIsTruncated], CONVERT(varbinary(max),[EvidenceLevel]) AS [EvidenceLevel], CONVERT(varbinary(max),[EvidenceSource]) AS [EvidenceSource], CONVERT(varbinary(max),[MessageText]) AS [MessageText] FROM #ExampleWriteActual)
           OR EXISTS(SELECT [RowsWrittenEventOrdinal] AS [RowsWrittenEventOrdinal], [LogId] AS [LogId], [ExecutionId] AS [ExecutionId], CONVERT(varbinary(max),[EventName]) AS [EventName], [SourceId] AS [SourceId], CONVERT(varbinary(max),[SourceName]) AS [SourceName], [EventTime] AS [EventTime], [DataCode] AS [DataCode], CONVERT(varbinary(max),[ParserId]) AS [ParserId], CONVERT(varbinary(max),[ParseStatus]) AS [ParseStatus], CONVERT(varbinary(max),[ObservationKind]) AS [ObservationKind], CONVERT(varbinary(max),[ComponentName]) AS [ComponentName], [ReportedRows] AS [ReportedRows], CONVERT(varbinary(max),[DiagnosticCode]) AS [DiagnosticCode], CONVERT(varbinary(max),[ContextStatus]) AS [ContextStatus], [ContextStartLogId] AS [ContextStartLogId], [ContextEndLogId] AS [ContextEndLogId], [InputIsTruncated] AS [InputIsTruncated], CONVERT(varbinary(max),[EvidenceLevel]) AS [EvidenceLevel], CONVERT(varbinary(max),[EvidenceSource]) AS [EvidenceSource], CONVERT(varbinary(max),[MessageText]) AS [MessageText] FROM #ExampleWriteActual EXCEPT SELECT [RowsWrittenEventOrdinal] AS [RowsWrittenEventOrdinal], [LogId] AS [LogId], [ExecutionId] AS [ExecutionId], CONVERT(varbinary(max),[EventName]) AS [EventName], [SourceId] AS [SourceId], CONVERT(varbinary(max),[SourceName]) AS [SourceName], [EventTime] AS [EventTime], [DataCode] AS [DataCode], CONVERT(varbinary(max),[ParserId]) AS [ParserId], CONVERT(varbinary(max),[ParseStatus]) AS [ParseStatus], CONVERT(varbinary(max),[ObservationKind]) AS [ObservationKind], CONVERT(varbinary(max),[ComponentName]) AS [ComponentName], [ReportedRows] AS [ReportedRows], CONVERT(varbinary(max),[DiagnosticCode]) AS [DiagnosticCode], CONVERT(varbinary(max),[ContextStatus]) AS [ContextStatus], [ContextStartLogId] AS [ContextStartLogId], [ContextEndLogId] AS [ContextEndLogId], [InputIsTruncated] AS [InputIsTruncated], CONVERT(varbinary(max),[EvidenceLevel]) AS [EvidenceLevel], CONVERT(varbinary(max),[EvidenceSource]) AS [EvidenceSource], CONVERT(varbinary(max),[MessageText]) AS [MessageText] FROM #ExampleWriteExpected)
           OR (SELECT COUNT(*) FROM #ExampleWriteActual)<>(SELECT COUNT(*) FROM #ExampleWriteExpected)
        BEGIN
            SELECT @Case AS FailedCase,@Label AS FailedLabel,@J AS FailedJson;
            THROW 56804,N'W_INDEPENDENT_ALL21',1;
        END;
        IF NOT EXISTS(SELECT 1 FROM OPENJSON(@J,'$.sourceStatus') WHERE JSON_VALUE(value,'$.SourceName')=N'rowsWrittenAnalysis'
            AND TRY_CONVERT(int,JSON_VALUE(value,'$.ObservedRowCount'))=CASE WHEN @Parse='EXCLUDED' THEN 0 ELSE 1 END
            AND JSON_VALUE(value,'$.StatusCode')=CASE WHEN @Parse='EXCLUDED' THEN 'AVAILABLE_EMPTY' WHEN @Context='ASSIGNED' THEN 'AVAILABLE' ELSE 'AVAILABLE_LIMITED' END)
            THROW 56805,N'W_SPARSE_SOURCE_STATUS',1;
        SET @Case+=1;
    END;
    DELETE dbo.ExampleRowsWrittenLogSource;
    INSERT dbo.ExampleRowsWrittenLogSource VALUES(10,N'OnPreExecute',N'ExampleDataFlow',@Source,@Id,@T,@T,0,N''),
        (20,N'OnInformation',N'ExampleDataFlow',@Source,@Id,DATEADD(second,1,@T),DATEADD(second,1,@T),1074016267,N'"ExampleSink" wrote 3 rows.'+NCHAR(13)+NCHAR(10)),
        (30,N'OnPostExecute',N'ExampleDataFlow',@Source,@Id,DATEADD(second,2,@T),DATEADD(second,2,@T),0,N'');
    CREATE TABLE #ExampleWriteExport(Seed int NULL);
    EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N'ExampleRowsWrittenLogSource',@ExecutionId=@Id,@HighImpactConfirmed=1,@IncludeRowsWrittenAnalysis=1,
        @ResultSetArt='TABLE',@ResultTablesJson=N'{"rowsWrittenEvents":"#ExampleWriteExport"}',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0;
    DECLARE @ExportCount int;
    EXEC sys.sp_executesql N'SELECT @N=COUNT(*) FROM #ExampleWriteExport WHERE ReportedRows=3 AND ContextStartLogId=10 AND ContextEndLogId=30;',N'@N int OUTPUT',@N=@ExportCount OUTPUT;
    IF @ExportCount<>1 THROW 56806,N'W_TABLE_VALUES',1;
    CREATE TABLE #ExampleWriteSchema(Ordinal int,Name sysname,TypeName sysname,MaxLength smallint,Prec tinyint,Scale tinyint,Nullable bit,CollationName sysname NULL);
    INSERT #ExampleWriteSchema VALUES
(1,N'RowsWrittenEventOrdinal',N'bigint',8,19,0,0,NULL),
(2,N'LogId',N'int',4,10,0,0,NULL),
(3,N'ExecutionId',N'uniqueidentifier',16,0,0,0,NULL),
(4,N'EventName',N'nvarchar',256,0,0,1,N'SQL_Latin1_General_CP1_CS_AS'),
(5,N'SourceId',N'uniqueidentifier',16,0,0,1,NULL),
(6,N'SourceName',N'nvarchar',8000,0,0,1,N'SQL_Latin1_General_CP1_CS_AS'),
(7,N'EventTime',N'datetime',8,23,3,1,NULL),
(8,N'DataCode',N'int',4,10,0,1,NULL),
(9,N'ParserId',N'varchar',32,0,0,1,N'SQL_Latin1_General_CP1_CS_AS'),
(10,N'ParseStatus',N'varchar',40,0,0,0,N'SQL_Latin1_General_CP1_CS_AS'),
(11,N'ObservationKind',N'varchar',40,0,0,1,N'SQL_Latin1_General_CP1_CS_AS'),
(12,N'ComponentName',N'nvarchar',8000,0,0,1,N'SQL_Latin1_General_CP1_CS_AS'),
(13,N'ReportedRows',N'bigint',8,19,0,1,NULL),
(14,N'DiagnosticCode',N'varchar',64,0,0,1,N'SQL_Latin1_General_CP1_CS_AS'),
(15,N'ContextStatus',N'varchar',40,0,0,0,N'SQL_Latin1_General_CP1_CS_AS'),
(16,N'ContextStartLogId',N'int',4,10,0,1,NULL),
(17,N'ContextEndLogId',N'int',4,10,0,1,NULL),
(18,N'InputIsTruncated',N'bit',1,1,0,0,NULL),
(19,N'EvidenceLevel',N'varchar',32,0,0,0,N'SQL_Latin1_General_CP1_CS_AS'),
(20,N'EvidenceSource',N'nvarchar',320,0,0,0,N'SQL_Latin1_General_CP1_CS_AS'),
(21,N'MessageText',N'nvarchar',-1,0,0,1,N'SQL_Latin1_General_CP1_CS_AS');
    IF EXISTS(SELECT * FROM #ExampleWriteSchema EXCEPT SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY c.column_id)),c.name,t.name,c.max_length,c.precision,c.scale,c.is_nullable,c.collation_name FROM tempdb.sys.columns c JOIN tempdb.sys.types t ON t.user_type_id=c.user_type_id WHERE c.object_id=OBJECT_ID(N'tempdb..#ExampleWriteExport'))
       OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleWriteExport'))<>21
       OR EXISTS(SELECT 1 FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExampleWriteExport') AND (is_identity=1 OR is_computed=1)) THROW 56807,N'W_TABLE_NATIVE_SCHEMA',1;
    DECLARE @MapCase int=1,@Map nvarchar(max),@Caught int;
    WHILE @MapCase<=6
    BEGIN
        SET @Map=CASE @MapCase WHEN 1 THEN N'{"unknownWriteSet":"#ExampleWriteExport"}' WHEN 2 THEN N'{"rowsWrittenEvents":"#ExampleWriteExport"}'
            WHEN 3 THEN N'{"rowsWrittenEvents":"#ExampleWriteExport","rowsWrittenEvents":"#ExampleWriteExport"}'
            WHEN 4 THEN N'{"rowsWrittenEvents":"#ExampleWriteExport","execution":"#ExampleWriteExport"}'
            WHEN 5 THEN N'{"rowsWrittenEvents":"dbo.ExampleWriteExport"}' ELSE N'broken-json' END;
        SET @Written=CASE WHEN @MapCase=2 THEN 0 ELSE 1 END;SET @Caught=NULL;
        BEGIN TRY
            EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@ExecutionId=@Id,@HighImpactConfirmed=1,@IncludeRowsWrittenAnalysis=@Written,@ResultSetArt='TABLE',@ResultTablesJson=@Map,@PrintMeldungen=0;
        END TRY BEGIN CATCH SET @Caught=ERROR_NUMBER();END CATCH;
        IF ISNULL(@Caught,0)<>51011 THROW 56808,N'W_MAPPING_REJECTION',1;
        SET @MapCase+=1;
    END;
    EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N'ExampleRowsWrittenLogSource',@ExecutionId=@Id,@HighImpactConfirmed=0,@IncludeRowsWrittenAnalysis=1,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
    IF @Status<>'INVALID_PARAMETER' OR ISNULL(JSON_QUERY(@J,'$.rowsWrittenEvents'),N'MISSING')<>N'[]' THROW 56814,N'W_HIGH_IMPACT_GATE',1;
    EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N'ExampleRowsWrittenLogSource',@ExecutionId=@Id,@HighImpactConfirmed=1,@IncludeRowsWrittenAnalysis=1,@IncludeMessages=0,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0;
    IF ISNULL(JSON_QUERY(@J,'$.rowsWrittenEvents'),N'MISSING')<>N'[]' OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J,'$.sourceStatus') WHERE JSON_VALUE(value,'$.SourceName')=N'rowsWrittenAnalysis' AND JSON_VALUE(value,'$.Detail')=N'MESSAGES_DISABLED' AND JSON_VALUE(value,'$.ObservedRowCount') IS NULL) THROW 56809,N'W_MESSAGES_DISABLED',1;
    EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N'ExampleRowsWrittenMissing',@ExecutionId=@Id,@HighImpactConfirmed=1,@IncludeRowsWrittenAnalysis=1,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0;
    IF ISNULL(JSON_QUERY(@J,'$.rowsWrittenEvents'),N'MISSING')<>N'[]' OR NOT EXISTS(SELECT 1 FROM OPENJSON(@J,'$.sourceStatus') WHERE JSON_VALUE(value,'$.SourceName')=N'rowsWrittenAnalysis' AND JSON_VALUE(value,'$.Detail')=N'NO_VALID_EVENT_BUFFER') THROW 56810,N'W_MISSING_SOURCE',1;
    ALTER TABLE dbo.ExampleRowsWrittenLogSource DROP COLUMN event;
    EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N'ExampleRowsWrittenLogSource',@ExecutionId=@Id,@HighImpactConfirmed=1,@IncludeRowsWrittenAnalysis=1,
        @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0;
    IF ISNULL(JSON_QUERY(@J,'$.rowsWrittenEvents'),N'MISSING')<>N'[]' THROW 56811,N'W_REQUIRED_COLUMN',1;
    ALTER TABLE dbo.ExampleRowsWrittenLogSource ADD event nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL;
    UPDATE dbo.ExampleRowsWrittenLogSource SET event=CASE id WHEN 10 THEN N'OnPreExecute' WHEN 20 THEN N'OnInformation' ELSE N'OnPostExecute' END;
    CREATE USER ExampleRowsWrittenReader WITHOUT LOGIN;
    SET @UserId=DATABASE_PRINCIPAL_ID(N'ExampleRowsWrittenReader');
    GRANT EXECUTE ON SCHEMA::monitor TO ExampleRowsWrittenReader;
    GRANT VIEW DEFINITION ON dbo.ExampleRowsWrittenLogSource TO ExampleRowsWrittenReader;
    DENY SELECT ON dbo.ExampleRowsWrittenLogSource TO ExampleRowsWrittenReader;
    DECLARE @DirectError int,@DirectMessage nvarchar(4000);
    BEGIN TRY
        EXECUTE AS USER='ExampleRowsWrittenReader';SET @Impersonated=1;
        BEGIN TRY EXEC sys.sp_executesql N'SELECT id FROM dbo.ExampleRowsWrittenLogSource;';END TRY BEGIN CATCH SELECT @DirectError=ERROR_NUMBER(),@DirectMessage=ERROR_MESSAGE();END CATCH;
        EXEC [monitor].[USP_SsisLegacyLogAnalysis] @LoggingDatabase=@Db,@LoggingTable=N'ExampleRowsWrittenLogSource',@ExecutionId=@Id,@HighImpactConfirmed=1,@IncludeRowsWrittenAnalysis=1,
            @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
        REVERT;SET @Impersonated=0;
    END TRY BEGIN CATCH IF @Impersonated=1 BEGIN REVERT;SET @Impersonated=0;END;THROW;END CATCH;
    IF ISNULL(@DirectError,0)<>229 OR ISNULL(@Error,0)<>229 OR @Message IS NULL OR @DirectMessage IS NULL
        OR CONVERT(varbinary(max),@Message)<>CONVERT(varbinary(max),@DirectMessage) OR ISNULL(JSON_QUERY(@J,'$.rowsWrittenEvents'),N'MISSING')<>N'[]' THROW 56812,N'W_NATIVE_DENIAL',1;
    IF DATABASE_PRINCIPAL_ID(N'ExampleRowsWrittenReader')<>@UserId THROW 56891,N'W_USER_ID_CHANGED',1;
    DROP USER ExampleRowsWrittenReader;SET @UserId=NULL;
    IF OBJECT_ID(N'dbo.ExampleRowsWrittenLogSource')<>@TableId THROW 56892,N'W_TABLE_ID_CHANGED',1;
    DROP TABLE dbo.ExampleRowsWrittenLogSource;SET @TableId=NULL;
    IF @@OPTIONS<>@OuterOptions OR @@LOCK_TIMEOUT<>@OuterLock OR @@TRANCOUNT<>@OuterTran THROW 56813,N'W_CALLER_CHANGED',1;
    SELECT N'PASS' AS RowsWrittenSyntheticStatus,34 AS PayloadAndContextCases,64 AS FlagCases,6 AS MappingCases,5 AS SourceCases,21 AS IndependentFields;
END TRY
BEGIN CATCH
    IF @Impersonated=1 REVERT;
    IF @UserId IS NOT NULL AND DATABASE_PRINCIPAL_ID(N'ExampleRowsWrittenReader')=@UserId DROP USER ExampleRowsWrittenReader;
    IF @TableId IS NOT NULL AND OBJECT_ID(N'dbo.ExampleRowsWrittenLogSource')=@TableId DROP TABLE dbo.ExampleRowsWrittenLogSource;
    THROW;
END CATCH;
GO
