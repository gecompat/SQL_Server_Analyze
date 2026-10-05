USE [DeineDatenbank];
GO

SET NOCOUNT ON;
DECLARE @ObjectName nvarchar(128), @CounterName nvarchar(128)=N'User Connections';
SELECT TOP (1) @ObjectName=RTRIM([object_name])
FROM [sys].[dm_os_performance_counters]
WHERE [counter_name] COLLATE SQL_Latin1_General_CP1_CS_AS=@CounterName
  AND [cntr_type]=65792 AND RTRIM([instance_name])=N''
ORDER BY [object_name];
IF @ObjectName IS NULL
    THROW 55790,N'Der erforderliche native Snapshotcounter ist nicht verfügbar.',1;

DECLARE @Sample tinyint=0, @Json nvarchar(max), @Status varchar(40), @Partial bit;
WHILE @Sample<=1
BEGIN
    CREATE TABLE [#ExampleCounterExport]([Dummy] int NULL);
    SELECT @Json=NULL, @Status=NULL, @Partial=NULL;
    EXEC [monitor].[USP_PerformanceCounters]
        @ObjectNames=@ObjectName, @CounterNames=@CounterName,
        @SampleSeconds=@Sample, @MaxZeilen=1,
        @ResultSetArt='TABLE', @ResultTablesJson=N'{"counters":"#ExampleCounterExport"}',
        @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0,
        @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>'AVAILABLE'
       OR COALESCE(@Partial,1)<>0
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'false'
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.counters'))<>1
       OR (SELECT COUNT_BIG(*) FROM [#ExampleCounterExport])<>1
        THROW 55791,N'Der positive Snapshot- oder Samplingvertrag ist verletzt.',1;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCounterExport') AND [collation_name] IS NOT NULL)<>6
       OR EXISTS (SELECT 1 FROM [tempdb].[sys].[columns]
                  WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleCounterExport') AND [collation_name] IS NOT NULL
                    AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55792,N'Der Counterexport übernimmt eine fremde tempdb-Collation.',1;
    IF NOT EXISTS (SELECT 1 FROM [#ExampleCounterExport] AS [e]
                   JOIN [sys].[dm_os_performance_counters] AS [p]
                     ON [e].[ObjectName]=RTRIM([p].[object_name]) COLLATE SQL_Latin1_General_CP1_CS_AS
                    AND [e].[CounterName]=RTRIM([p].[counter_name]) COLLATE SQL_Latin1_General_CP1_CS_AS
                    AND [e].[InstanceName]=RTRIM([p].[instance_name]) COLLATE SQL_Latin1_General_CP1_CS_AS
                    AND [e].[CounterType]=[p].[cntr_type]
                   WHERE [e].[ObjectName]=@ObjectName AND [e].[CounterName]=@CounterName
                     AND [e].[Interpretation]='RAW_SNAPSHOT' AND [e].[MetricUnit]='RAW_VALUE'
                     AND [e].[FindingCode]='VALUE_AVAILABLE' AND [e].[BeforeValue] IS NOT NULL
                     AND [e].[AfterValue]>=1 AND [e].[MetricValue]=[e].[AfterValue]
                     AND [e].[SqlServerStartTime] IS NOT NULL
                     AND (@Sample=0 OR [e].[SampleSeconds]>=1))
       OR COALESCE(JSON_VALUE(@Json,N'$.counters[0].ObjectName'),N'')<>@ObjectName
       OR COALESCE(JSON_VALUE(@Json,N'$.counters[0].CounterName'),N'')<>@CounterName
       OR TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.counters[0].AfterValue')) IS NULL
       OR TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.counters[0].AfterValue'))
           <>(SELECT [AfterValue] FROM [#ExampleCounterExport])
        THROW 55793,N'Counteridentität oder typisierte Snapshotinterpretation ist verletzt.',1;
    DROP TABLE [#ExampleCounterExport];
    SET @Sample+=1;
END;

SET @Json=NULL;
EXEC [monitor].[USP_PerformanceCounters]
    @ObjectNames=@ObjectName, @CounterNames=N'user Connections',
    @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @PrintMeldungen=0;
IF COALESCE(ISJSON(@Json),0)<>1
   OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'UNAVAILABLE_OBJECT'
   OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>N'true'
   OR COALESCE(JSON_QUERY(@Json,N'$.counters'),N'')<>N'[]'
    THROW 55794,N'Der exakte Counterfilter ignoriert Groß- und Kleinschreibung.',1;
GO
