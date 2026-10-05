USE [DeineDatenbank];
GO
SET NOCOUNT ON;
DECLARE @Marker nvarchar(100)=N'ExampleErrorLogCollation_'+CONVERT(nvarchar(36),NEWID()),
        @FirstMessage nvarchar(200),@SecondMessage nvarchar(200),@Since datetime2(3)=DATEADD(SECOND,-1,CONVERT(datetime2(3),SYSDATETIME())),
        @FirstCaught bit=0,@SecondCaught bit=0,@Case tinyint=0,@Details bit,@Limit int,@SourceLimit int,@TextLimit int,
        @ExpectedRows bigint,@ExpectedAccepted bigint,@ExpectedWarnings int,@ExpectedStatus varchar(40),@ExpectedPartial bit,
        @Json nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048);
SELECT @FirstMessage=@Marker+N' Example first Ä.',@SecondMessage=@Marker+N' Example second Ü.';
BEGIN TRY RAISERROR(@FirstMessage,16,1) WITH LOG; END TRY
BEGIN CATCH IF ERROR_NUMBER()=50000 AND ERROR_SEVERITY()=16 SET @FirstCaught=1; ELSE THROW; END CATCH;
WAITFOR DELAY '00:00:00.250';
BEGIN TRY RAISERROR(@SecondMessage,16,1) WITH LOG; END TRY
BEGIN CATCH IF ERROR_NUMBER()=50000 AND ERROR_SEVERITY()=16 SET @SecondCaught=1; ELSE THROW; END CATCH;
WAITFOR DELAY '00:00:02';
CREATE TABLE [#ExampleErrorLogNative]
(
 [LogDate] datetime NULL,[ProcessInfo] nvarchar(50) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
 [MessageText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
);
INSERT [#ExampleErrorLogNative] EXEC [master].[sys].[sp_readerrorlog] 0,1,@Marker;
IF @FirstCaught<>1 OR @SecondCaught<>1 OR (SELECT COUNT_BIG(*) FROM [#ExampleErrorLogNative])<>2
   OR (SELECT COUNT(DISTINCT [LogDate]) FROM [#ExampleErrorLogNative])<>2
   OR EXISTS(SELECT 1 FROM [#ExampleErrorLogNative] WHERE [LogDate] IS NULL OR [LogDate]<@Since OR [MessageText] IS NULL)
   OR NOT EXISTS(SELECT 1 FROM [#ExampleErrorLogNative] WHERE [MessageText] LIKE N'%Ä%')
   OR NOT EXISTS(SELECT 1 FROM [#ExampleErrorLogNative] WHERE [MessageText] LIKE N'%Ü%')
    THROW 55910,N'Die zwei eigenen synthetischen Errorlogeinträge sind nicht nativ bestätigt.',1;
DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
WHILE @Case<5
BEGIN
    SELECT @Details=CASE WHEN @Case=0 THEN 0 ELSE 1 END,
           @Limit=CASE WHEN @Case=2 THEN 1 WHEN @Case=3 THEN NULL ELSE 0 END,
           @SourceLimit=CASE WHEN @Case=4 THEN 1 ELSE 0 END,@TextLimit=CASE WHEN @Case=3 THEN 12 ELSE 0 END,
           @ExpectedRows=CASE WHEN @Case=0 THEN 0 WHEN @Case IN(2,4) THEN 1 ELSE 2 END,
           @ExpectedAccepted=CASE WHEN @Case=4 THEN 1 ELSE 2 END,
           @ExpectedStatus=CASE WHEN @Case=4 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END,
           @ExpectedPartial=CASE WHEN @Case=4 THEN 1 ELSE 0 END,@ExpectedWarnings=CASE WHEN @Case=4 THEN 2 ELSE 0 END;
    CREATE TABLE [#ExampleErrorLogModule]([Dummy] int NULL);
    CREATE TABLE [#ExampleErrorLogSummary]([Dummy] int NULL);
    CREATE TABLE [#ExampleErrorLogDetails]([Dummy] int NULL);
    CREATE TABLE [#ExampleErrorLogSources]([Dummy] int NULL);
    CREATE TABLE [#ExampleErrorLogWarnings]([Dummy] int NULL);
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    EXEC [monitor].[USP_ErrorLogAnalysis] @SeitServerlokalzeit=@Since,@Suchtext1=@Marker,@MeldungstextEinbeziehen=@Details,
      @MaxMeldungszeichen=@TextLimit,@MaxQuellzeilen=@SourceLimit,@MaxZeilen=@Limit,@ResultSetArt='TABLE',
      @ResultTablesJson=N'{"moduleStatus":"#ExampleErrorLogModule","summary":"#ExampleErrorLogSummary","details":"#ExampleErrorLogDetails","sourceStatus":"#ExampleErrorLogSources","warnings":"#ExampleErrorLogWarnings"}',
      @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
      @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id] IN(OBJECT_ID(N'tempdb..#ExampleErrorLogModule'),OBJECT_ID(N'tempdb..#ExampleErrorLogSummary'),
          OBJECT_ID(N'tempdb..#ExampleErrorLogDetails'),OBJECT_ID(N'tempdb..#ExampleErrorLogSources'),OBJECT_ID(N'tempdb..#ExampleErrorLogWarnings'))
          AND [collation_name] IS NOT NULL)<>22
       OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
        WHERE [object_id] IN(OBJECT_ID(N'tempdb..#ExampleErrorLogModule'),OBJECT_ID(N'tempdb..#ExampleErrorLogSummary'),
          OBJECT_ID(N'tempdb..#ExampleErrorLogDetails'),OBJECT_ID(N'tempdb..#ExampleErrorLogSources'),OBJECT_ID(N'tempdb..#ExampleErrorLogWarnings'))
          AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55911,N'Die Errorlogexporte übernehmen eine fremde tempdb-Collation.',1;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>@ExpectedStatus OR @Partial IS NULL OR @Partial<>@ExpectedPartial
       OR @Error IS NOT NULL OR (@Case<>4 AND @Message IS NOT NULL)
       OR (@Case=4 AND COALESCE(@Message,N'')<>N'Quelle oder Teilquelle nicht vollständig gelesen.')
       OR (SELECT COUNT_BIG(*) FROM [#ExampleErrorLogModule])<>1 OR (SELECT COUNT_BIG(*) FROM [#ExampleErrorLogSummary])<>1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleErrorLogDetails])<>@ExpectedRows OR (SELECT COUNT_BIG(*) FROM [#ExampleErrorLogSources])<>1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleErrorLogWarnings])<>@ExpectedWarnings
       OR NOT EXISTS(SELECT 1 FROM [#ExampleErrorLogModule] WHERE [ModuleName]=N'USP_ErrorLogAnalysis' AND [StatusCode]=@ExpectedStatus
          AND [IsPartial]=@ExpectedPartial AND [AgentRequested]=0 AND [HighestArchiveRequested]=0 AND [SourceRowLimit]=@SourceLimit
          AND [AcceptedSourceRows]=@ExpectedAccepted AND [SummaryRowCount]=1 AND [DetailRowCount]=@ExpectedRows
          AND [HasMoreSourceRows]=@ExpectedPartial AND [HasMoreDetailRows]=CASE WHEN @Case=2 THEN 1 ELSE 0 END
          AND [ErrorNumber] IS NULL AND ([ErrorMessage]=@Message OR ([ErrorMessage] IS NULL AND @Message IS NULL)))
       OR NOT EXISTS(SELECT 1 FROM [#ExampleErrorLogSources] WHERE [SourceOrdinal]=1 AND [ProductName]='SQL_SERVER' AND [ArchiveNumber]=0
          AND [RuleCategory]='CUSTOM_FILTER' AND [SourceObject]=N'master.sys.sp_readerrorlog' AND [StatusCode]=@ExpectedStatus
          AND [IsPartial]=@ExpectedPartial AND [ReadRowCount]=2 AND [AcceptedRowCount]=@ExpectedAccepted
          AND [ErrorNumber] IS NULL AND [ErrorMessage] IS NULL)
        THROW 55912,N'Der Errorlogstatus-, Quellenzähler- oder Detailauswahlvertrag ist verletzt.',1;
    DELETE @Parity;
    INSERT @Parity VALUES
      ((SELECT * FROM [#ExampleErrorLogSummary] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.summary')),
      ((SELECT * FROM [#ExampleErrorLogDetails] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.details')),
      ((SELECT * FROM [#ExampleErrorLogSources] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.sourceStatus')),
      ((SELECT * FROM [#ExampleErrorLogWarnings] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.warnings')),
      ((SELECT 'SQL_SERVER' AS [ProductName],'CUSTOM_FILTER' AS [Category],COUNT_BIG(*) AS [EventCount],
           MIN([LogDate]) AS [FirstOccurrenceServerLocal],MAX([LogDate]) AS [LastOccurrenceServerLocal],1 AS [ArchiveCount],0 AS [HighestArchiveNumber],
           'SERVER_LOCAL_TIME_FROM_ERRORLOG' AS [TimeSemantics],'EVENT_CATEGORY_REVIEW' AS [FindingCode],
           N'Keywordgefilterte Errorlog-Evidenz. Häufigkeit und Zeitnähe erhöhen Relevanz, beweisen aber ohne korrelierte Engine-, OS-, Storage- oder Workloaddaten keine Ursache.' AS [EvidenceLimit]
         FROM (SELECT TOP(CASE WHEN @Case=4 THEN 1 ELSE 2 END) * FROM [#ExampleErrorLogNative] ORDER BY [LogDate] DESC) AS [n]
         FOR JSON PATH,INCLUDE_NULL_VALUES),(SELECT * FROM [#ExampleErrorLogSummary] FOR JSON PATH,INCLUDE_NULL_VALUES)),
      ((SELECT TOP(@ExpectedRows) 'SQL_SERVER' AS [ProductName],0 AS [ArchiveNumber],'CUSTOM_FILTER' AS [Category],
          [LogDate] AS [LogDateServerLocal],'SERVER_LOCAL_TIME_FROM_ERRORLOG' AS [TimeSemantics],[ProcessInfo],
          CONVERT(bigint,LEN([MessageText]+NCHAR(1))-1) AS [MessageCharacters],CONVERT(bigint,DATALENGTH([MessageText])) AS [MessageBytes],
          CONVERT(bit,CASE WHEN @Case=3 THEN 1 ELSE 0 END) AS [MessageIsTruncated],
          CASE WHEN @Case=3 THEN LEFT([MessageText],12) ELSE [MessageText] END AS [MessageText]
         FROM [#ExampleErrorLogNative] ORDER BY [LogDate] DESC FOR JSON PATH,INCLUDE_NULL_VALUES),
       COALESCE((SELECT * FROM [#ExampleErrorLogDetails] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]'));
    IF EXISTS(SELECT 1 FROM @Parity AS [p]
       WHERE LEFT(COALESCE([p].[ModuleJson],N''),1)<>N'['
         OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[TableJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]))
         OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[TableJson]) AS [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]) AS [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
         OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]) AS [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
            EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*) FROM OPENJSON([p].[TableJson]) AS [r]
            CROSS APPLY(SELECT [key],[type],[value] FROM OPENJSON([r].[value]) ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
            GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
        THROW 55913,N'Der native Errorlog- oder TABLE-/JSON-Multimengenvertrag ist verletzt.',1;
    IF @Case=4 AND
       (NOT EXISTS(SELECT 1 FROM [#ExampleErrorLogWarnings] WHERE [WarningOrdinal]=1 AND [SourceName]=N'sp_readerrorlog'
          AND [StatusCode]='AVAILABLE_LIMITED' AND [ErrorNumber] IS NULL AND [Message]=N'Quelle oder Teilquelle nicht vollständig gelesen.')
        OR NOT EXISTS(SELECT 1 FROM [#ExampleErrorLogWarnings] WHERE [WarningOrdinal]=2 AND [SourceName]=N'sp_readerrorlog'
          AND [StatusCode]='SOURCE_ROW_LIMIT' AND [ErrorNumber] IS NULL
          AND [Message]=N'@MaxQuellzeilen begrenzt die materialisierte Errorlog-Evidenz; Summary und Details sind partiell.'))
        THROW 55914,N'Die zwei Errorlog-Quelllimitwarnungen fehlen.',1;
    DROP TABLE [#ExampleErrorLogModule]; DROP TABLE [#ExampleErrorLogSummary]; DROP TABLE [#ExampleErrorLogDetails];
    DROP TABLE [#ExampleErrorLogSources]; DROP TABLE [#ExampleErrorLogWarnings];
    SET @Case+=1;
END;
DROP TABLE [#ExampleErrorLogNative];
GO
