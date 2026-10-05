USE [DeineDatenbank];
GO

SET NOCOUNT ON;
DECLARE @Json nvarchar(max), @Extended bit=0;
DECLARE @Expected TABLE([Ordinal] tinyint PRIMARY KEY,[ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS);
DECLARE @Inactive TABLE([JsonKey] sysname COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY);
WHILE @Extended<=1
BEGIN
    DELETE @Expected;
    DELETE @Inactive;
    INSERT @Inactive VALUES(N'cpuTopology'),(N'numa'),(N'memory'),(N'tempdb'),
        (N'configuration'),(N'traceFlags'),(N'startupParameters'),(N'operatingSystem'),
        (N'databaseIntegrity'),(N'databaseCapacity'),(N'criticalEngineEvents'),(N'diagnosticFindings');
    IF @Extended=0 INSERT @Inactive VALUES(N'performanceCounters'),(N'internalContention'),(N'bufferPool');
    INSERT @Expected VALUES(9,N'USP_ServerSecurityConfiguration');
    IF @Extended=1 INSERT @Expected VALUES(12,N'USP_PerformanceCounters'),(14,N'USP_InternalContentionAnalysis'),(15,N'USP_BufferPoolAnalysis');
    CREATE TABLE [#ExampleHealthExport]([Dummy] int NULL);
    SET @Json=NULL;
    EXEC [monitor].[USP_ServerHealthAnalysis]
        @MitCpu=0,@MitNuma=0,@MitMemory=0,@MitTempDB=0,@MitConfiguration=0,
        @MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=1,
        @MitPerformanceCounters=@Extended,@MitContention=@Extended,@MitBufferPool=@Extended,
        @MaxZeilen=10,@ResultSetArt='TABLE',@ResultTablesJson=N'{"moduleStatus":"#ExampleHealthExport"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns]
        WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleHealthExport') AND [collation_name] IS NOT NULL)<>3
       OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns]
                 WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleHealthExport') AND [collation_name] IS NOT NULL
                   AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55831,N'Der ServerHealth-Modulstatus übernimmt eine fremde tempdb-Collation.',1;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>N'AVAILABLE'
       OR COALESCE(JSON_QUERY(@Json,N'$.warnings'),N'')<>N'[]'
       OR (SELECT COUNT_BIG(*) FROM [#ExampleHealthExport])<>(SELECT COUNT_BIG(*) FROM @Expected)
       OR EXISTS(SELECT [Ordinal],[ModuleName] COLLATE SQL_Latin1_General_CP1_CS_AS FROM [#ExampleHealthExport]
                 EXCEPT SELECT [Ordinal],[ModuleName] FROM @Expected)
       OR EXISTS(SELECT [Ordinal],[ModuleName] FROM @Expected
                 EXCEPT SELECT [Ordinal],[ModuleName] COLLATE SQL_Latin1_General_CP1_CS_AS FROM [#ExampleHealthExport])
       OR EXISTS(SELECT 1 FROM [#ExampleHealthExport]
                 WHERE COALESCE([StatusCode],'') NOT IN ('AVAILABLE','AVAILABLE_WITH_FINDING')
                   OR COALESCE([IsPartial],1)<>0 OR [ErrorNumber] IS NOT NULL OR [ErrorMessage] IS NOT NULL)
        THROW 55830,N'Der positive ServerHealth-Modulstatusvertrag ist verletzt.',1;
    IF COALESCE(JSON_VALUE(@Json,N'$.security.meta.statusCode'),N'')<>N'AVAILABLE'
       OR COALESCE(JSON_VALUE(@Json,N'$.security.meta.isPartial'),N'')<>N'false'
       OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.security.configuration')
                     WITH ([ConfigurationName] nvarchar(128)) WHERE [ConfigurationName]=N'xp_cmdshell')
        THROW 55832,N'Die ServerHealth-Child-JSON-Auswahl ist verletzt.',1;
    IF EXISTS(SELECT 1 FROM @Inactive AS [i] LEFT JOIN OPENJSON(@Json) AS [j]
               ON [j].[key] COLLATE SQL_Latin1_General_CP1_CS_AS=[i].[JsonKey]
               WHERE COALESCE([j].[type],-1)<>0)
        THROW 55833,N'Nicht aktivierte ServerHealth-Module fehlen oder liefern Child-JSON statt JSON-null.',1;
    IF @Extended=1 AND
       (NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.performanceCounters.counters'))
        OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.performanceCounters.counters'))>10
        OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.bufferPool.memory'))<>1
        OR COALESCE(JSON_QUERY(@Json,N'$.bufferPool.bufferPool'),N'')<>N'[]'
        OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.internalContention.meta')
                      WITH ([Requested] int N'$.requestedSampleSeconds',[Actual] decimal(19,6) N'$.actualSampleSeconds')
                      WHERE [Requested]=5 AND [Actual]>0)
        OR LEFT(COALESCE(JSON_QUERY(@Json,N'$.internalContention.latches'),N''),1)<>N'['
        OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.internalContention.latches'))>10)
        THROW 55834,N'Der begrenzte erweiterte ServerHealth-Child-JSON-Vertrag ist verletzt.',1;
    DROP TABLE [#ExampleHealthExport];
    IF @Extended=1 BREAK;
    SET @Extended=1;
END;
GO
