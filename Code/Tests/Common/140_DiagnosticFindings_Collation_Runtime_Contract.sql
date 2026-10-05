USE [DeineDatenbank];
GO
SET NOCOUNT ON;
DECLARE @Integrity nvarchar(max)=N'{"meta":{"resultName":"DatabaseIntegrityAnalysis","schemaVersion":1,"statusCode":"AVAILABLE_WITH_FINDING","isPartial":false,"errorNumber":null,"errorMessage":null},"integrity":[{"DatabaseName":"ExampleDbÄ","FindingCode":"SUSPECT_PAGES_PRESENT","SuspectPageCount":3,"DamagedBackupCount":0,"CheckdbAgeHours":null,"EvidenceLimit":"Example integrity evidence limit."},{"DatabaseName":"ExampleDbÜ","FindingCode":"CHECKDB_EVIDENCE_UNAVAILABLE","SuspectPageCount":0,"DamagedBackupCount":0,"CheckdbAgeHours":null,"EvidenceLimit":"Example integrity evidence limit."}]}',
        @Capacity nvarchar(max)=N'{"meta":{"resultName":"DatabaseCapacityAnalysis","schemaVersion":1,"statusCode":"AVAILABLE_WITH_FINDING","isPartial":false,"errorNumber":null,"errorMessage":null},"capacity":[{"DatabaseName":"ExampleDbÄ","LogicalFileName":"ExampleFile","FreeInFileMb":100,"VolumeAvailableMb":300,"VolumeFreePercent":25,"NextGrowthMb":null,"FindingCode":"GROWTH_DISABLED","EvidenceLimit":"Example capacity evidence limit."}]}',
        @Memory nvarchar(max)=N'{"meta":{"resultName":"BufferPoolAnalysis","schemaVersion":1,"statusCode":"AVAILABLE_WITH_FINDING","isPartial":false,"errorNumber":null,"errorMessage":null},"memory":[{"FindingCode":"EXAMPLE_MEMORY_REVIEW","FindingSeverity":"LOW","AvailablePhysicalMemoryPercent":12.5,"ProcessPhysicalMemoryLow":false,"ProcessVirtualMemoryLow":false,"EvidenceLimit":"Example memory evidence limit."}],"resourceSemaphores":[]}',
        @CurrentMemory nvarchar(max),@Json nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),
        @Case tinyint=0,@Limit int,@Minimum varchar(16),@Expected bigint,@Eligible bigint,@ExpectedStatus varchar(40),@ExpectedPartial bit,
        @Database sysname=DB_NAME();
DECLARE @Parity TABLE([TableJson] nvarchar(max),[ModuleJson] nvarchar(max));
CREATE TABLE [#ExampleFindingsExpected]
(
    [FindingOrdinal] bigint NOT NULL,[SourceModule] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Category] varchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Confidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ScopeType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ScopeName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[FindingCode] varchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EvidenceMetric] decimal(38,4) NULL,[Evidence] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RecommendedNextCheck] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
);
INSERT [#ExampleFindingsExpected] VALUES
(1,N'USP_DatabaseIntegrityAnalysis','INTEGRITY','HIGH','HIGH',N'DATABASE',N'ExampleDbÄ','SUSPECT_PAGES_PRESENT',3,
 N'Suspect pages=3; damaged backups=0; CHECKDB age hours=NULL.',N'Example integrity evidence limit.',N'CHECKDB-/Backup-/Seitenreparaturevidenz kontrolliert verifizieren.'),
(2,N'USP_DatabaseIntegrityAnalysis','INTEGRITY','LOW','HIGH',N'DATABASE',N'ExampleDbÜ','CHECKDB_EVIDENCE_UNAVAILABLE',NULL,
 N'Suspect pages=0; damaged backups=0; CHECKDB age hours=NULL.',N'Example integrity evidence limit.',N'CHECKDB-/Backup-/Seitenreparaturevidenz kontrolliert verifizieren.'),
(3,N'USP_DatabaseCapacityAnalysis','CAPACITY','MEDIUM','HIGH',N'DATABASE_FILE',N'ExampleDbÄ/ExampleFile','GROWTH_DISABLED',25,
 N'file free MB=100.00; volume free MB=300.00; next growth MB=NULL.',N'Example capacity evidence limit.',
 N'Datei-, Volume- und Growth-Konfiguration gemeinsam prüfen; ohne Historie keine Zeit-bis-voll-Prognose.'),
(4,N'USP_BufferPoolAnalysis','MEMORY','LOW','HIGH',N'INSTANCE',NULL,'EXAMPLE_MEMORY_REVIEW',12.5,
 N'OS available percent=12.50; process physical low=0; process virtual low=0.',N'Example memory evidence limit.',
 N'Mit Verlauf, Resource Semaphores, anderen Prozessen und OS-Grenzen korrelieren.');
WHILE @Case<5
BEGIN
    SELECT @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case>=3 THEN NULL ELSE 0 END,
           @Minimum=CASE WHEN @Case=2 THEN 'MEDIUM' WHEN @Case=3 THEN 'HIGH' ELSE 'INFO' END,
           @Eligible=CASE WHEN @Case=2 THEN 2 WHEN @Case=3 THEN 1 ELSE 4 END,
           @Expected=CASE WHEN @Case IN(1,3) THEN 1 WHEN @Case=2 THEN 2 ELSE 4 END,
           @ExpectedStatus=CASE WHEN @Case=4 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE_WITH_FINDING' END,
           @ExpectedPartial=CASE WHEN @Case=4 THEN 1 ELSE 0 END,
           @CurrentMemory=CASE WHEN @Case=4
                               THEN JSON_MODIFY(JSON_MODIFY(@Memory,'$.meta.isPartial',CONVERT(bit,1)),'$.meta.statusCode','AVAILABLE_LIMITED')
                               ELSE @Memory END;
    CREATE TABLE [#ExampleFindingsExport]([Dummy] int NULL);
    SELECT @Json=NULL,@Status=NULL,@Partial=NULL,@Error=NULL,@Message=NULL;
    EXEC [monitor].[USP_DiagnosticFindings] @MitIntegritaet=1,@MitKapazitaet=1,@MitSpeicher=1,
        @MitBackupketten=0,@MitAvailability=0,@MitAgentMonitoring=0,
        @ParentIntegrityJson=@Integrity,@ParentCapacityJson=@Capacity,@ParentBufferPoolJson=@CurrentMemory,
        @NurAbPrioritaet=@Minimum,@MaxZeilen=@Limit,@ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#ExampleFindingsExport"}',
        @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
        @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
    IF (SELECT COUNT_BIG(*) FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleFindingsExport')
          AND [collation_name] IS NOT NULL)<>10
       OR EXISTS(SELECT 1 FROM [tempdb].[sys].[columns] WHERE [object_id]=OBJECT_ID(N'tempdb..#ExampleFindingsExport')
                   AND [collation_name] IS NOT NULL AND [collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS<>N'SQL_Latin1_General_CP1_CS_AS')
        THROW 55891,N'Der DiagnosticFindings-Export übernimmt eine fremde tempdb-Collation.',1;
    IF COALESCE(ISJSON(@Json),0)<>1 OR COALESCE(@Status,'')<>@ExpectedStatus OR @Partial IS NULL OR @Partial<>@ExpectedPartial
       OR @Error IS NOT NULL OR @Message IS NOT NULL
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.statusCode'),N'')<>@ExpectedStatus
       OR COALESCE(JSON_VALUE(@Json,N'$.meta.isPartial'),N'')<>CASE WHEN @ExpectedPartial=1 THEN N'true' ELSE N'false' END
       OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.totalFindingCount')),-1)<>4
       OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@Json,N'$.meta.returnedFindingCount')),-1)<>@Eligible
       OR (SELECT COUNT_BIG(*) FROM [#ExampleFindingsExport])<>@Expected
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.modules'))<>3
       OR (SELECT COUNT(DISTINCT [ExecutionOrdinal]) FROM OPENJSON(@Json,N'$.modules') WITH([ExecutionOrdinal] int))<>3
       OR EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.modules')
                 WITH([ExecutionOrdinal] int,[ModuleName] sysname,[InvocationStatus] varchar(40),[EvidenceStatus] varchar(40),
                      [IsPartial] bit,[ErrorNumber] int,[ErrorMessage] nvarchar(2048))
                 WHERE [ExecutionOrdinal] IS NULL OR [ExecutionOrdinal] NOT IN(1,2,3) OR [ModuleName] IS NULL
                    OR [ModuleName]<>CASE [ExecutionOrdinal] WHEN 1 THEN N'USP_DatabaseIntegrityAnalysis'
                                                         WHEN 2 THEN N'USP_DatabaseCapacityAnalysis' ELSE N'USP_BufferPoolAnalysis' END
                    OR COALESCE([InvocationStatus],'')<>'REUSED_PARENT_RESULT'
                    OR COALESCE([EvidenceStatus],'')<>CASE WHEN @Case=4 AND [ExecutionOrdinal]=3 THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE_WITH_FINDING' END
                    OR [IsPartial] IS NULL OR [IsPartial]<>CASE WHEN @Case=4 AND [ExecutionOrdinal]=3 THEN 1 ELSE 0 END
                    OR [ErrorNumber] IS NOT NULL OR [ErrorMessage] IS NOT NULL)
        THROW 55890,N'Der DiagnosticFindings-Status-, Zähler- oder Auswahlvertrag ist verletzt.',1;
    DELETE @Parity;
    INSERT @Parity VALUES
    (
        (SELECT TOP(CASE WHEN @Case=1 THEN 1 ELSE 4 END) * FROM [#ExampleFindingsExpected]
         WHERE CASE [Severity] WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 ELSE 2 END
               >= CASE @Minimum WHEN 'HIGH' THEN 4 WHEN 'MEDIUM' THEN 3 ELSE 1 END
         ORDER BY CASE [Severity] WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END,[FindingOrdinal]
         FOR JSON PATH,INCLUDE_NULL_VALUES),
        (SELECT * FROM [#ExampleFindingsExport] FOR JSON PATH,INCLUDE_NULL_VALUES)
    ),
    (
        (SELECT * FROM [#ExampleFindingsExport] FOR JSON PATH,INCLUDE_NULL_VALUES),JSON_QUERY(@Json,N'$.findings')
    );
    IF EXISTS(SELECT 1 FROM @Parity AS [p]
               WHERE LEFT(COALESCE([p].[ModuleJson],N''),1)<>N'['
                 OR (SELECT COUNT_BIG(*) FROM OPENJSON([p].[TableJson]))<>(SELECT COUNT_BIG(*) FROM OPENJSON([p].[ModuleJson]))
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS)
                 OR EXISTS(SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[ModuleJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS
                           EXCEPT SELECT [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS,COUNT_BIG(*)
                           FROM OPENJSON([p].[TableJson]) AS [r] CROSS APPLY
                           (SELECT [key],[type],[value] FROM OPENJSON([r].[value])
                            ORDER BY [key] COLLATE SQL_Latin1_General_CP1_CS_AS
                            FOR JSON PATH,INCLUDE_NULL_VALUES) AS [n]([RowJson])
                           GROUP BY [n].[RowJson] COLLATE SQL_Latin1_General_CP1_CS_AS))
        THROW 55893,N'TABLE und JSON enthalten verschiedene DiagnosticFindings-Ergebnisse.',1;



    DROP TABLE [#ExampleFindingsExport];
    SET @Case+=1;
END;
CREATE TABLE [#ExampleFindingsFresh]([Dummy] int NULL);
SELECT @Json=NULL,@Status=NULL,@Partial=NULL;
EXEC [monitor].[USP_DiagnosticFindings] @DatabaseNames=@Database,@MitIntegritaet=1,@MitKapazitaet=0,@MitSpeicher=0,
    @MitBackupketten=0,@MitAvailability=0,@MitAgentMonitoring=0,@MaxZeilen=0,
    @ResultSetArt='TABLE',@ResultTablesJson=N'{"findings":"#ExampleFindingsFresh"}',
    @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT;
IF COALESCE(@Status,'')<>'AVAILABLE_WITH_FINDING' OR COALESCE(@Partial,1)<>0
   OR (SELECT COUNT_BIG(*) FROM [#ExampleFindingsFresh])<>1
   OR NOT EXISTS(SELECT 1 FROM [#ExampleFindingsFresh]
                  WHERE [SourceModule]=N'USP_DatabaseIntegrityAnalysis' AND [Category]='INTEGRITY' AND [Severity]='LOW'
                    AND [ScopeType]=N'DATABASE' AND [ScopeName]=@Database AND [FindingCode]='CHECKDB_EVIDENCE_UNAVAILABLE'
                    AND [EvidenceMetric] IS NULL)
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.modules'))<>1
   OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json,N'$.modules')
                 WITH([ModuleName] sysname,[InvocationStatus] varchar(40),[EvidenceStatus] varchar(40),[IsPartial] bit)
                 WHERE [ModuleName]=N'USP_DatabaseIntegrityAnalysis' AND [InvocationStatus]='EXECUTED'
                   AND [EvidenceStatus]='AVAILABLE_WITH_FINDING' AND [IsPartial]=0)
    THROW 55894,N'Der frische DiagnosticFindings-Child-Aufruf ist nicht nativ bestätigt.',1;
DROP TABLE [#ExampleFindingsFresh];
DROP TABLE [#ExampleFindingsExpected];
GO
