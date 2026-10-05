USE [DeineDatenbank];
GO

SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM [monitor].[TVF_InterpretContentionCounter](100,110,1,0.996000)
               WHERE [CounterValue]=10 AND [RatePerSecond]=10.0402 AND [CounterResetDetected]=0)
    THROW 55815,N'Der Ratenvertrag für eine positive tatsächliche Dauer unter einer Sekunde ist verletzt.',1;
DECLARE @Sample tinyint=0, @Json nvarchar(max), @Status varchar(40), @Partial bit;
DECLARE @Kind varchar(30), @Seconds decimal(19,6);
WHILE @Sample<=1
BEGIN
    CREATE TABLE [#ExampleLatchExport]([Dummy] int NULL);
    SELECT @Json=NULL, @Status=NULL, @Partial=NULL;
    SET @Kind=CASE WHEN @Sample=0 THEN 'CUMULATIVE_SINCE_START' ELSE 'SAMPLE_DELTA' END;
    EXEC [monitor].[USP_InternalContentionAnalysis]
        @SampleSeconds=@Sample, @MitSpinlocks=1, @MitHotPages=0, @MitPageDetails=0, @MaxZeilen=10,
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"latches":"#ExampleLatchExport"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT;
    IF COALESCE(ISJSON(@Json),0)<>1
       OR COALESCE(@Status,'') NOT IN ('AVAILABLE','AVAILABLE_WITH_FINDING') OR COALESCE(@Partial,1)<>0
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@Status
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
       OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.requestedSampleSeconds')) IS NULL
       OR TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.requestedSampleSeconds'))<>@Sample
       OR LEFT(COALESCE(JSON_QUERY(@Json,N'$.latches'),N''),1)<>N'['
       OR LEFT(COALESCE(JSON_QUERY(@Json,N'$.spinlocks'),N''),1)<>N'['
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.latches'))>10
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.spinlocks'))>10
       OR COALESCE(JSON_QUERY(@Json,N'$.hotPages'),N'')<>N'[]'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.latches'))<>(SELECT COUNT_BIG(*) FROM [#ExampleLatchExport])
        THROW 55810,N'Der begrenzte Contention-JSON- oder TABLE-Vertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleLatchExport') AND [collation_name] IS NOT NULL)<>2
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns]
                  WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleLatchExport') AND [collation_name] IS NOT NULL
                    AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55811,N'Der Latchexport übernimmt eine fremde tempdb-Collation.',1;
    IF @Sample=0 AND (NOT EXISTS(SELECT 1 FROM [#ExampleLatchExport])
                       OR EXISTS(SELECT 1 FROM [#ExampleLatchExport]
                                  WHERE [MeasurementKind]<>@Kind OR [WaitTimeMs] IS NULL OR [WaitTimeMs]<=0
                                    OR [WaitingRequests] IS NULL OR [CounterResetDetected]<>0
                                    OR [WaitsPerSecond] IS NOT NULL OR [WaitMsPerSecond] IS NOT NULL)
                       OR EXISTS(SELECT 1 FROM [#ExampleLatchExport] AS [e]
                                  WHERE NOT EXISTS(SELECT 1 FROM [sys].[dm_os_latch_stats] AS [l]
                                                    WHERE [l].[latch_class] COLLATE SQL_Latin1_General_CP1_CS_AS=[e].[LatchClass])))
        THROW 55812,N'Die positive kumulative Latchmessung oder native Klassenidentität ist verletzt.',1;
    SET @Seconds=TRY_CONVERT(decimal(19,6),JSON_VALUE(@Json,N'$.meta.actualSampleSeconds'));
    IF @Sample=1 AND (@Seconds IS NULL OR @Seconds<=0
                       OR EXISTS(SELECT 1 FROM [#ExampleLatchExport]
                                  WHERE [MeasurementKind]<>@Kind
                                    OR ([CounterResetDetected]=0 AND
                                        ([WaitingRequests] IS NULL OR [WaitTimeMs] IS NULL
                                         OR [WaitsPerSecond] IS NULL OR [WaitMsPerSecond] IS NULL
                                         OR ABS([WaitsPerSecond]-CONVERT(decimal(19,4),1.0*[WaitingRequests]/NULLIF(@Seconds,0)))>0.0001
                                         OR ABS([WaitMsPerSecond]-CONVERT(decimal(19,4),1.0*[WaitTimeMs]/NULLIF(@Seconds,0)))>0.0001))))
        THROW 55813,N'Die Latch-Samplekennzeichnung oder Ratenformel ist verletzt.',1;
    IF EXISTS(SELECT [LatchClass] COLLATE SQL_Latin1_General_CP1_CS_AS,[MeasurementKind] COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitingRequests],[WaitTimeMs] FROM [#ExampleLatchExport]
              EXCEPT SELECT [LatchClass],[MeasurementKind],[WaitingRequests],[WaitTimeMs]
              FROM OPENJSON(@Json,N'$.latches') WITH
              ([LatchClass] nvarchar(120),[MeasurementKind] varchar(30),[WaitingRequests] bigint,[WaitTimeMs] bigint))
       OR EXISTS(SELECT [LatchClass],[MeasurementKind],[WaitingRequests],[WaitTimeMs]
                 FROM OPENJSON(@Json,N'$.latches') WITH
                 ([LatchClass] nvarchar(120),[MeasurementKind] varchar(30),[WaitingRequests] bigint,[WaitTimeMs] bigint)
                 EXCEPT SELECT [LatchClass] COLLATE SQL_Latin1_General_CP1_CS_AS,[MeasurementKind] COLLATE SQL_Latin1_General_CP1_CS_AS,[WaitingRequests],[WaitTimeMs] FROM [#ExampleLatchExport])
        THROW 55814,N'TABLE und JSON enthalten verschiedene Latchmessungen.',1;
    DROP TABLE [#ExampleLatchExport];
    SET @Sample+=1;
END;
GO
