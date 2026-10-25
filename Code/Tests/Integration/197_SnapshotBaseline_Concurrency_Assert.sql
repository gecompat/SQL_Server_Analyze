USE [SQLServerAnalyzeTest];
GO
SET NOCOUNT ON;
UPDATE [monitor].[SnapshotTargetConfiguration] SET [IsEnabled]=1 WHERE [ConfigurationId]=1;
DECLARE @Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@RunId bigint;
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType='EXTERNAL',@RunEvenIfNotDue=1,@ResultSetArt='NONE',@PrintMeldungen=0,
     @CaptureRunIdOut=@RunId OUTPUT,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
IF @Status<>'SKIPPED_CONCURRENT' OR @RunId IS NOT NULL
    THROW 53741,N'SC023_CONCURRENCY_ASSERT_FAILED',1;
DECLARE @PurgeId bigint,@BeforeRuns bigint=(SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun]),
 @BeforePurges bigint=(SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PurgeRun]);
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @CollectorCode='WAIT_STATS',
 @SchedulerType='EXTERNAL',@RunEvenIfNotDue=1,@ResultSetArt='NONE',@PrintMeldungen=0,
 @CaptureRunIdOut=@RunId OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'')<>'SKIPPED_CONCURRENT' OR @RunId IS NOT NULL
 THROW 53741,N'SC023_WAIT_CONCURRENCY_ASSERT_FAILED',1;
EXEC [monitor].[USP_PurgeSnapshotData] @Force=1,@ResultSetArt='NONE',@PrintMeldungen=0,
 @PurgeRunIdOut=@PurgeId OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF COALESCE(@Status,'')<>'SKIPPED_CONCURRENT' OR @PurgeId IS NOT NULL
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[CaptureRun])<>@BeforeRuns
 OR (SELECT COUNT_BIG(*) FROM [SQLServerAnalyzeSnapshotTest].[snapshot].[PurgeRun])<>@BeforePurges
 THROW 53741,N'SC023_CROSS_COLLECTOR_PURGE_CONCURRENCY_ASSERT_FAILED',1;
PRINT N'SC023_CONCURRENCY_CONTRACT PASS';
GO
