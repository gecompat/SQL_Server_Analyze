/*
===============================================================================
Objekt       : snapshot.InternalCompleteWaitStatsCycle
Version      : 1.0.1
Stand        : 2026-10-25
Zweck        : Die Procedure bindet einen vollständigen Waitread an seinen Run
               und speichert Rohwerte und Differenzkandidaten atomar.
Grenze       : Monotonie beweist keine ununterbrochene Resetkontinuität.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalCompleteWaitStatsCycle]
      @CaptureRunId bigint
    , @CollectorJson nvarchar(max)
    , @ExpectedTargetDatabaseId int
    , @ExpectedTargetDatabaseName sysname
    , @ExpectedTargetCreateDate datetime
    , @StatusCodeOut varchar(40) OUTPUT
    , @IsPartialOut bit OUTPUT
    , @ErrorNumberOut int OUTPUT
    , @ErrorMessageOut nvarchar(2048) OUTPUT
AS
BEGIN
    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0 OR @CaptureRunId IS NULL OR @CaptureRunId<=0
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der Waitabschluss benötigt einen gültigen Lauf ohne Callertransaktion oder implizite Transaktionen.';
        RETURN 51011;
    END;
    IF @ExpectedTargetDatabaseId IS NULL OR @ExpectedTargetDatabaseName IS NULL
       OR @ExpectedTargetCreateDate IS NULL OR @ExpectedTargetDatabaseId<=4
       OR DB_ID()<>@ExpectedTargetDatabaseId
       OR NOT EXISTS
       (
           SELECT 1 FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
           WHERE [d].[database_id]=@ExpectedTargetDatabaseId
             AND CONVERT(varbinary(max),[d].[name])=CONVERT(varbinary(max),@ExpectedTargetDatabaseName)
             AND [d].[create_date]=@ExpectedTargetCreateDate
             AND [d].[state]=0 AND [d].[is_read_only]=0
       )
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53764,
               @ErrorMessageOut=N'Die erwartete Snapshot-Zielidentität stimmt nicht mehr überein.';
        RETURN;
    END;

    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET XACT_ABORT ON;

    DECLARE @OwnRun bit=0,@StartedAtUtc datetime2(3),@MaxRows int,@PayloadEnabled bit,
            @PolicyEnabled bit,@SourceStatus varchar(40),@SourcePartial bit,@SourceComplete bit,
            @SourceError int,@SourceMessage nvarchar(2048),@NativeRows bigint,
            @MeasurementStart datetime2(3),@MeasurementEnd datetime2(3),
            @EngineName nvarchar(128),@EngineStartLocal datetime,@EngineTicks bigint,
            @MetaJson nvarchar(max),@EngineJson nvarchar(max),@Epoch uniqueidentifier,
            @ServerScopeId bigint,@PreviousRunId bigint,@PreviousContext nvarchar(max),
            @PreviousContextVersion int,@ComparisonStatus varchar(40),@EpochDecision varchar(40),
            @RawJson nvarchar(max),@ContextJson nvarchar(max),@RawHash varbinary(32),
            @WrittenTypes bigint=0,@ActiveTypes bigint=0,@EligibleTypes bigint=0,
            @ComparableTypes bigint=0,@CandidateSamples bigint=0,@WriteLimited bit=0;

    DECLARE @SourceRoot TABLE([Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
    DECLARE @SourceMeta TABLE([Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
    DECLARE @SourceEngine TABLE([Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
    DECLARE @SourceRows TABLE([Ordinal] bigint,[Json] nvarchar(max),[JsonType] int);
    DECLARE @SourceRowFields TABLE([Ordinal] bigint,[Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
    DECLARE @Waits TABLE
    (
        [WaitType] nvarchar(60) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [WaitingTasksCount] bigint NOT NULL,[WaitTimeMs] bigint NOT NULL,
        [MaxWaitTimeMs] bigint NOT NULL,[SignalWaitTimeMs] bigint NOT NULL,
        [ScopeIdentityJson] nvarchar(max) NOT NULL,[ScopeKeyHash] binary(32) NOT NULL,
        [IsEligible] bit NOT NULL DEFAULT(0),[IsSelected] bit NOT NULL DEFAULT(0),
        [ScopeId] bigint NULL,[IsComparable] bit NOT NULL DEFAULT(0),
        [DeltaStatus] varchar(40) NULL
    );

    BEGIN TRY
        IF (SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1 OR NOT EXISTS
           (SELECT 1 FROM [snapshot].[PackageVersion]
            WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')
              AND CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.2.1')
              AND [SchemaVersion]=2)
        BEGIN
            SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53761,
                   @ErrorMessageOut=N'Das vollständig installierte Wait-Target 1.2.1 fehlt.';
            RETURN;
        END;
        DECLARE @ProbeRun bigint,@ProbeStatus varchar(40),@ProbeBudget bit,@ProbeError int,
                @ProbeMessage nvarchar(2048),@RetentionContract int;
        EXEC [snapshot].[InternalPurgeExpiredData]
             @MaxBatches=1,@Force=0,@PurgeRunIdOut=@ProbeRun OUTPUT,@StatusCodeOut=@ProbeStatus OUTPUT,
             @BudgetExceededOut=@ProbeBudget OUTPUT,@ErrorNumberOut=@ProbeError OUTPUT,
             @ErrorMessageOut=@ProbeMessage OUTPUT,@ContractOnly=1,
             @RetentionContractVersionOut=@RetentionContract OUTPUT,
             @ExpectedTargetDatabaseId=@ExpectedTargetDatabaseId,
             @ExpectedTargetDatabaseName=@ExpectedTargetDatabaseName,
             @ExpectedTargetCreateDate=@ExpectedTargetCreateDate;
        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR COALESCE(@RetentionContract,0)<>1
           OR @ProbeRun IS NOT NULL OR @ProbeError IS NOT NULL
            THROW 53762,N'Der benötigte read-only Retentionsvertrag fehlt.',1;

        BEGIN TRANSACTION;
        SELECT @StartedAtUtc=[StartedAtUtc]
        FROM [snapshot].[CaptureRun] WITH (UPDLOCK,HOLDLOCK)
        WHERE [CaptureRunId]=@CaptureRunId
          AND CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),'WAIT_STATS')
          AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING'
          AND [ResetEpochId] IS NULL AND [MetricSampleCount]=0 AND [PayloadCount]=0;
        IF @StartedAtUtc IS NULL
           OR EXISTS(SELECT 1 FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)
           OR EXISTS(SELECT 1 FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
           OR EXISTS(SELECT 1 FROM [snapshot].[ModuleStatus] WHERE [CaptureRunId]=@CaptureRunId)
            THROW 53763,N'Der Waitabschluss benötigt genau einen unbeschriebenen eigenen laufenden Wait-Run.',1;
        SET @OwnRun=1;
        SELECT @MaxRows=[MaxRows],@PayloadEnabled=[PayloadEnabled],@PolicyEnabled=[IsEnabled]
        FROM [snapshot].[CollectorPolicy]
        WHERE [CollectorCode]='WAIT_STATS';
        IF COALESCE(@PolicyEnabled,0)<>1 OR @MaxRows IS NULL OR @MaxRows NOT BETWEEN 1 AND 100000
            THROW 53763,N'Die aktive gültige Wait-Policy fehlt.',1;

        IF COALESCE(ISJSON(@CollectorJson),0)<>1
            THROW 53763,N'Der transiente Wait-Sourcevertrag ist kein gültiges JSON-Objekt.',1;
        INSERT @SourceRoot SELECT [key],[value],[type] FROM OPENJSON(@CollectorJson);
        IF (SELECT COUNT_BIG(*) FROM @SourceRoot)<>2
           OR (SELECT COUNT_BIG(*) FROM @SourceRoot WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'meta') AND [JsonType]=5)<>1
           OR (SELECT COUNT_BIG(*) FROM @SourceRoot WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'waits') AND [JsonType]=4)<>1
            THROW 53763,N'Der transiente Wait-Rootvertrag ist ungültig.',1;
        SELECT @MetaJson=[Value] FROM @SourceRoot WHERE [Name]=N'meta';
        INSERT @SourceMeta SELECT [key],[value],[type] FROM OPENJSON(@MetaJson);
        DECLARE @ExpectedMeta TABLE([Name] nvarchar(60),[Type1] int,[Type2] int);
        INSERT @ExpectedMeta VALUES
          (N'schemaVersion',2,2),(N'resultName',1,1),(N'measurementStartUtc',1,0),
          (N'measurementEndUtc',1,0),(N'statusCode',1,1),(N'isPartial',3,3),
          (N'errorNumber',2,0),(N'errorMessage',1,0),(N'nativeRows',1,0),
          (N'sourceComplete',3,3),(N'engineContext',5,0);
        IF (SELECT COUNT_BIG(*) FROM @SourceMeta)<>11
           OR EXISTS
           (SELECT 1 FROM @ExpectedMeta AS [e]
            WHERE (SELECT COUNT_BIG(*) FROM @SourceMeta AS [m]
                   WHERE CONVERT(varbinary(max),[m].[Name])=CONVERT(varbinary(max),[e].[Name])
                     AND [m].[JsonType] IN([e].[Type1],[e].[Type2]))<>1)
           OR NOT EXISTS(SELECT 1 FROM @SourceMeta WHERE [Name]=N'schemaVersion' AND CONVERT(varbinary(max),[Value])=CONVERT(varbinary(max),N'1'))
           OR NOT EXISTS(SELECT 1 FROM @SourceMeta WHERE [Name]=N'resultName' AND CONVERT(varbinary(max),[Value])=CONVERT(varbinary(max),N'SnapshotWaitStats'))
            THROW 53763,N'Der transiente Wait-Metavertrag ist ungültig.',1;
        IF NOT EXISTS
           (SELECT 1 FROM @SourceMeta AS [m]
            CROSS JOIN (VALUES(N'AVAILABLE'),(N'EMPTY_UNPROVEN'),(N'DENIED_PERMISSION'),
                              (N'UNAVAILABLE_OBJECT'),(N'ERROR_HANDLED')) AS [v]([Status])
            WHERE [m].[Name]=N'statusCode'
              AND CONVERT(varbinary(max),[m].[Value])=CONVERT(varbinary(max),[v].[Status]))
            THROW 53763,N'Der transiente Source-Status ist unbekannt.',1;
        SELECT @SourceStatus=CONVERT(varchar(40),[Value]) FROM @SourceMeta WHERE [Name]=N'statusCode';
        SELECT @SourceComplete=CASE WHEN [Value]=N'true' THEN 1 ELSE 0 END FROM @SourceMeta WHERE [Name]=N'sourceComplete';
        SELECT @SourcePartial=CASE WHEN [Value]=N'true' THEN 1 ELSE 0 END FROM @SourceMeta WHERE [Name]=N'isPartial';
        SELECT @EngineJson=[Value] FROM @SourceMeta WHERE [Name]=N'engineContext';
        SELECT @SourceMessage=[Value] FROM @SourceMeta WHERE [Name]=N'errorMessage';
        IF EXISTS(SELECT 1 FROM @SourceMeta WHERE [Name]=N'errorMessage' AND DATALENGTH([Value])>4096)
           OR EXISTS
           (SELECT 1 FROM @SourceMeta WHERE [Name]=N'errorNumber' AND [JsonType]<>0
            AND (TRY_CONVERT(int,[Value]) IS NULL OR TRY_CONVERT(int,[Value])<=0
                 OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(11),TRY_CONVERT(int,[Value])))))
            THROW 53763,N'Der transiente Fehlervertrag ist ungültig.',1;
        SELECT @SourceError=TRY_CONVERT(int,[Value]) FROM @SourceMeta WHERE [Name]=N'errorNumber';

        IF EXISTS
           (SELECT 1 FROM @SourceMeta WHERE [Name] IN(N'measurementStartUtc',N'measurementEndUtc') AND [JsonType]<>0
            AND (DATALENGTH([Value])<>48 OR RIGHT([Value],1)<>N'Z'
                 OR TRY_CONVERT(datetime2(3),LEFT([Value],23),126) IS NULL
                 OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime2(3),LEFT([Value],23),126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,TRY_CONVERT(datetime2(3),LEFT([Value],23),126))),3)+N'Z')))
            THROW 53763,N'Das transiente UTC-Messfenster ist ungültig.',1;
        SELECT @MeasurementStart=TRY_CONVERT(datetime2(3),LEFT([Value],23),126) FROM @SourceMeta WHERE [Name]=N'measurementStartUtc';
        SELECT @MeasurementEnd=TRY_CONVERT(datetime2(3),LEFT([Value],23),126) FROM @SourceMeta WHERE [Name]=N'measurementEndUtc';
        IF (@MeasurementStart IS NULL AND @MeasurementEnd IS NOT NULL)
           OR (@MeasurementStart IS NOT NULL AND @MeasurementEnd IS NULL)
           OR @MeasurementStart>@MeasurementEnd
            THROW 53763,N'Das transiente Messfenster ist unvollständig oder rückläufig.',1;

        IF @EngineJson IS NOT NULL
        BEGIN
            INSERT @SourceEngine SELECT [key],[value],[type] FROM OPENJSON(@EngineJson);
            IF (SELECT COUNT_BIG(*) FROM @SourceEngine)<>3
               OR (SELECT COUNT_BIG(*) FROM @SourceEngine WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'serverName') AND [JsonType]=1 AND DATALENGTH([Value]) BETWEEN 2 AND 256)<>1
               OR (SELECT COUNT_BIG(*) FROM @SourceEngine WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'sqlServerStartTimeLocal') AND [JsonType]=1)<>1
               OR (SELECT COUNT_BIG(*) FROM @SourceEngine WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'sqlServerStartTimeMsTicks') AND [JsonType]=1)<>1
                THROW 53763,N'Der native Enginekontext ist unvollständig.',1;
            SELECT @EngineName=[Value] FROM @SourceEngine WHERE [Name]=N'serverName';
            IF EXISTS
               (SELECT 1 FROM @SourceEngine WHERE [Name]=N'sqlServerStartTimeLocal'
                AND (DATALENGTH([Value])<>46 OR TRY_CONVERT(datetime,[Value],126) IS NULL
                     OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime,[Value],126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,TRY_CONVERT(datetime,[Value],126))),3))))
               OR EXISTS
               (SELECT 1 FROM @SourceEngine WHERE [Name]=N'sqlServerStartTimeMsTicks'
                AND (TRY_CONVERT(bigint,[Value]) IS NULL OR TRY_CONVERT(bigint,[Value])<0
                     OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[Value])))))
                THROW 53763,N'Die native Startidentität ist ungültig.',1;
            SELECT @EngineStartLocal=TRY_CONVERT(datetime,[Value],126) FROM @SourceEngine WHERE [Name]=N'sqlServerStartTimeLocal';
            SELECT @EngineTicks=TRY_CONVERT(bigint,[Value]) FROM @SourceEngine WHERE [Name]=N'sqlServerStartTimeMsTicks';
        END;

        INSERT @SourceRows SELECT TRY_CONVERT(bigint,[key]),[value],[type] FROM OPENJSON(@CollectorJson,N'$.waits');
        IF EXISTS(SELECT 1 FROM @SourceRows WHERE [JsonType]<>5)
            THROW 53763,N'Eine transiente Waitzeile ist kein Objekt.',1;
        INSERT @SourceRowFields
        SELECT [r].[Ordinal],[j].[key],[j].[value],[j].[type]
        FROM @SourceRows AS [r] CROSS APPLY OPENJSON([r].[Json]) AS [j];
        DECLARE @ExpectedWaitFields TABLE([Name] nvarchar(60),[JsonType] int);
        INSERT @ExpectedWaitFields VALUES(N'WaitType',1),(N'WaitingTasksCount',2),
                                          (N'WaitTimeMs',2),(N'MaxWaitTimeMs',2),(N'SignalWaitTimeMs',2);
        IF EXISTS
           (SELECT 1 FROM @SourceRows AS [r]
            WHERE (SELECT COUNT_BIG(*) FROM @SourceRowFields AS [f] WHERE [f].[Ordinal]=[r].[Ordinal])<>5
               OR EXISTS(SELECT 1 FROM @ExpectedWaitFields AS [e]
                         WHERE (SELECT COUNT_BIG(*) FROM @SourceRowFields AS [f]
                                WHERE [f].[Ordinal]=[r].[Ordinal] AND [f].[JsonType]=[e].[JsonType]
                                  AND CONVERT(varbinary(max),[f].[Name])=CONVERT(varbinary(max),[e].[Name]))<>1))
           OR EXISTS(SELECT 1 FROM @SourceRowFields WHERE [Name]=N'WaitType' AND DATALENGTH([Value]) NOT BETWEEN 2 AND 120)
           OR EXISTS
           (SELECT 1 FROM @SourceRowFields WHERE [JsonType]=2
            AND (TRY_CONVERT(bigint,[Value]) IS NULL OR TRY_CONVERT(bigint,[Value])<0
                 OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[Value])))))
            THROW 53763,N'Der transiente Waitrow-Vertrag ist ungültig.',1;
        INSERT @Waits
        ([WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs],[ScopeIdentityJson],[ScopeKeyHash])
        SELECT [v].[WaitType],[v].[WaitingTasksCount],[v].[WaitTimeMs],[v].[MaxWaitTimeMs],[v].[SignalWaitTimeMs],
               [j].[IdentityJson],HASHBYTES('SHA2_256',CONVERT(varbinary(max),[j].[IdentityJson]))
        FROM @SourceRows AS [r]
        CROSS APPLY OPENJSON([r].[Json]) WITH
         ([WaitType] nvarchar(60) N'$.WaitType',[WaitingTasksCount] bigint N'$.WaitingTasksCount',
          [WaitTimeMs] bigint N'$.WaitTimeMs',[MaxWaitTimeMs] bigint N'$.MaxWaitTimeMs',
          [SignalWaitTimeMs] bigint N'$.SignalWaitTimeMs') AS [v]
        CROSS APPLY(SELECT [v].[WaitType] AS [waitType] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS [j]([IdentityJson]);
        IF EXISTS(SELECT [ScopeKeyHash] FROM @Waits GROUP BY [ScopeKeyHash] HAVING COUNT_BIG(*)>1)
            THROW 53763,N'Der native Waitcache enthält doppelte Typen oder widersprüchliche Identitäten.',1;

        IF @SourceComplete=1
        BEGIN
            IF @SourceStatus NOT IN('AVAILABLE','EMPTY_UNPROVEN') OR @EngineName IS NULL
               OR @MeasurementStart IS NULL OR @MeasurementEnd IS NULL
               OR @MeasurementStart<@StartedAtUtc OR @MeasurementEnd>CONVERT(datetime2(3),SYSUTCDATETIME())
               OR @SourceError IS NOT NULL OR @SourceMessage IS NOT NULL
               OR EXISTS
               (SELECT 1 FROM @SourceMeta WHERE [Name]=N'nativeRows'
                AND ([JsonType]<>1 OR TRY_CONVERT(bigint,[Value]) IS NULL OR TRY_CONVERT(bigint,[Value])<0
                     OR CONVERT(varbinary(max),[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[Value])))))
                THROW 53763,N'Die behauptete vollständige Sourceaufnahme ist widersprüchlich.',1;
            SELECT @NativeRows=TRY_CONVERT(bigint,[Value]) FROM @SourceMeta WHERE [Name]=N'nativeRows';
            IF @NativeRows<>(SELECT COUNT_BIG(*) FROM @Waits)
               OR (@SourceStatus='AVAILABLE' AND (@NativeRows=0 OR @SourcePartial<>0))
               OR (@SourceStatus='EMPTY_UNPROVEN' AND (@NativeRows<>0 OR @SourcePartial<>1))
                THROW 53763,N'Sourcestatus und tatsächliche Waitmenge widersprechen sich.',1;
        END
        ELSE
        BEGIN
            IF @SourceStatus NOT IN('DENIED_PERMISSION','UNAVAILABLE_OBJECT','ERROR_HANDLED')
               OR @SourcePartial<>1 OR EXISTS(SELECT 1 FROM @Waits)
               OR EXISTS(SELECT 1 FROM @SourceMeta WHERE [Name]=N'nativeRows' AND [JsonType]<>0)
                THROW 53763,N'Der fehlgeschlagene Sourcevertrag behauptet eine vollständige Aufnahme.',1;
            SELECT @StatusCodeOut=@SourceStatus,@IsPartialOut=1,@ErrorNumberOut=@SourceError,
                   @ErrorMessageOut=@SourceMessage;
            GOTO FinalizeWithoutMetrics;
        END;

        DECLARE @Metrics TABLE
        ([Code] varchar(96) COLLATE DATABASE_DEFAULT,[ValueType] varchar(24) COLLATE DATABASE_DEFAULT,
         [Unit] varchar(40) COLLATE DATABASE_DEFAULT,[Id] bigint NULL);
        INSERT @Metrics ([Code],[ValueType],[Unit]) VALUES
          ('WAIT_TASK_COUNT','BIGINT','count'),('WAIT_TIME_MS','BIGINT','ms'),
          ('WAIT_SIGNAL_TIME_MS','BIGINT','ms'),('WAIT_MAX_TIME_MS','BIGINT','ms'),
          ('WAIT_TASK_COUNT_DELTA_CANDIDATE','BIGINT','count'),('WAIT_TIME_MS_DELTA_CANDIDATE','BIGINT','ms'),
          ('WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE','BIGINT','ms'),
          ('WAIT_DELTA_STATUS','STRING','status'),('WAIT_CAPTURE_CONTEXT','STRING','json');
        UPDATE [e] SET [Id]=[d].[MetricDefinitionId]
        FROM @Metrics AS [e] JOIN [snapshot].[MetricDefinition] AS [d] ON [d].[MetricCode]=[e].[Code]
        WHERE CONVERT(varbinary(max),[d].[MetricCode])=CONVERT(varbinary(max),[e].[Code])
          AND CONVERT(varbinary(max),[d].[ValueType])=CONVERT(varbinary(max),[e].[ValueType])
          AND CONVERT(varbinary(max),[d].[Unit])=CONVERT(varbinary(max),[e].[Unit])
          AND [d].[ContractVersion]=1;
        IF EXISTS(SELECT 1 FROM @Metrics WHERE [Id] IS NULL)
            THROW 53760,N'Der vollständige typisierte Waitmetrikvertrag fehlt.',1;
        DECLARE @ContextMetric bigint=(SELECT [Id] FROM @Metrics WHERE [Code]='WAIT_CAPTURE_CONTEXT'),
                @DeltaStatusMetric bigint=(SELECT [Id] FROM @Metrics WHERE [Code]='WAIT_DELTA_STATUS'),
                @ServerIdentity nvarchar(100)=N'{"scope":"SERVER"}',@ServerHash varbinary(32);
        SET @ServerHash=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ServerIdentity));
        IF EXISTS
           (SELECT 1 FROM [snapshot].[Scope] WHERE [ScopeType]='SERVER' AND [ScopeKeyHash]=@ServerHash
            AND ([ScopeId]<=0 OR CONVERT(varbinary(max),[ScopeType])<>CONVERT(varbinary(max),'SERVER')
                 OR [ParentScopeId] IS NOT NULL OR CONVERT(varbinary(max),[ScopeIdentityJson])<>CONVERT(varbinary(max),@ServerIdentity)))
            THROW 53766,N'Der vorhandene SERVER-Scope widerspricht seiner Identität.',1;
        SELECT @ServerScopeId=[ScopeId] FROM [snapshot].[Scope]
        WHERE [ScopeType]='SERVER' AND [ParentScopeId] IS NULL AND [ScopeKeyHash]=@ServerHash;

        DECLARE @PreviousStatus varchar(40),@PreviousError int,@PreviousEpoch uniqueidentifier,
                @PreviousStarted datetime2(3),@PreviousEnded datetime2(3),@PreviousSampleCount bigint,
                @PreviousContextEpoch uniqueidentifier,@PreviousMeasurementStart datetime2(3),
                @PreviousMeasurementEnd datetime2(3),@PreviousEngineName nvarchar(128),
                @PreviousEngineStart datetime,@PreviousEngineTicks bigint,
                @ContextValid bit=0,@RawValid bit=0,@PreviousTechnicalPartial bit=0,
                @EngineChanged bit=0,@CounterDecrease bit=0,@WaitTypeMissing bit=0,
                @IntervalInvalid bit=0,@PreviousWritten bigint,@PreviousActive bigint,
                @PreviousEligible bigint,@PreviousNative bigint,@PreviousRawCount bigint,
                @PreviousComparable bigint,@PreviousCandidateCount bigint,@PreviousLimited bit,
                @PreviousRawHash varchar(64),@PreviousContextStatus varchar(40),
                @PreviousContextDecision varchar(40),@PreviousContextParent bigint;
        SELECT TOP(1) @PreviousRunId=[CaptureRunId],@PreviousStatus=[StatusCode],@PreviousError=[ErrorNumber],
               @PreviousEpoch=[ResetEpochId],@PreviousStarted=[StartedAtUtc],@PreviousEnded=[EndedAtUtc],
               @PreviousSampleCount=[MetricSampleCount]
        FROM [snapshot].[CaptureRun]
        WHERE CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),'WAIT_STATS')
          AND [EndedAtUtc] IS NOT NULL AND [CaptureRunId]<@CaptureRunId
        ORDER BY [CaptureRunId] DESC;
        IF @PreviousRunId IS NOT NULL AND (@PreviousStatus NOT IN('AVAILABLE','PARTIAL') OR @PreviousError IS NOT NULL)
            SET @PreviousTechnicalPartial=1;
        IF @PreviousRunId IS NOT NULL
        BEGIN
            IF (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample]
                WHERE [CaptureRunId]=@PreviousRunId AND [MetricDefinitionId]=@ContextMetric) = 1
                SELECT @PreviousContext=[StringValue]
                FROM [snapshot].[MetricSample]
                WHERE [CaptureRunId]=@PreviousRunId AND [MetricDefinitionId]=@ContextMetric;
        END;

        DECLARE @ContextRoot TABLE([Name] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
        DECLARE @ContextFields TABLE([Path] nvarchar(4000),[Value] nvarchar(max),[JsonType] int);
        DECLARE @ContextSpec TABLE([Path] nvarchar(128),[JsonType] int,[Nullable] bit,[Kind] varchar(24));
        INSERT @ContextSpec VALUES
          (N'schemaVersion',2,0,'ONE'),(N'collectorCode',1,0,'WAIT_STATS'),(N'metricContractVersion',2,0,'ONE'),
          (N'captureRunId',1,0,'POSITIVE_ID'),(N'serverScopeId',1,0,'POSITIVE_ID'),(N'resetEpochId',1,0,'GUID'),
          (N'engine.serverName',1,0,'ENGINE_NAME'),(N'engine.sqlServerStartTimeLocal',1,0,'LOCAL_MS'),
          (N'engine.sqlServerStartTimeMsTicks',1,0,'DECIMAL'),
          (N'window.measurementStartUtc',1,0,'UTC_MS'),(N'window.measurementEndUtc',1,0,'UTC_MS'),
          (N'capture.sourceComplete',3,0,'TRUE'),(N'capture.nativeWaitTypeCount',1,0,'DECIMAL'),
          (N'capture.activeTypeCount',1,0,'DECIMAL'),(N'capture.eligibleTypeCount',1,0,'DECIMAL'),
          (N'capture.writtenTypeCount',1,0,'DECIMAL'),(N'capture.writeLimited',3,0,'BOOLEAN'),
          (N'capture.rawMetricSampleCount',1,0,'DECIMAL'),(N'capture.rawProjectionSha256',1,0,'SHA256'),
          (N'comparison.previousCaptureRunId',1,1,'POSITIVE_ID'),(N'comparison.previousContextVersion',2,1,'POSITIVE_VERSION'),
          (N'comparison.status',1,0,'GLOBAL_STATUS'),(N'comparison.comparableTypeCount',1,0,'DECIMAL'),
          (N'comparison.candidateSampleCount',1,0,'DECIMAL'),(N'epochDecision',1,0,'EPOCH_DECISION');
        IF @PreviousContext IS NOT NULL AND DATALENGTH(@PreviousContext)<=8000 AND ISJSON(@PreviousContext)=1
        BEGIN
            INSERT @ContextRoot SELECT [key],[value],[type] FROM OPENJSON(@PreviousContext);
            IF (SELECT COUNT_BIG(*) FROM @ContextRoot WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'schemaVersion'))=1
                SELECT @PreviousContextVersion=TRY_CONVERT(int,[Value])
                FROM @ContextRoot WHERE CONVERT(varbinary(max),[Name])=CONVERT(varbinary(max),N'schemaVersion')
                  AND [JsonType]=2 AND TRY_CONVERT(int,[Value])>0
                  AND CONVERT(varbinary(max),[Value])=CONVERT(varbinary(max),CONVERT(nvarchar(11),TRY_CONVERT(int,[Value])));
            INSERT @ContextFields
            SELECT [Name],[Value],[JsonType] FROM @ContextRoot WHERE [JsonType]<>5;
            INSERT @ContextFields
            SELECT CONCAT([r].[Name],N'.',[j].[key]),[j].[value],[j].[type]
            FROM @ContextRoot AS [r] CROSS APPLY OPENJSON([r].[Value]) AS [j] WHERE [r].[JsonType]=5;
            IF (SELECT COUNT_BIG(*) FROM @ContextRoot)=11
               AND (SELECT COUNT_BIG(*) FROM @ContextRoot WHERE [JsonType]=5)=4
               AND NOT EXISTS
               (SELECT 1 FROM (VALUES(N'engine'),(N'window'),(N'capture'),(N'comparison')) AS [e]([Name])
                WHERE (SELECT COUNT_BIG(*) FROM @ContextRoot AS [r]
                       WHERE CONVERT(varbinary(max),[r].[Name])=CONVERT(varbinary(max),[e].[Name]) AND [r].[JsonType]=5)<>1)
               AND (SELECT COUNT_BIG(*) FROM @ContextFields)=25
               AND NOT EXISTS
               (SELECT 1 FROM @ContextSpec AS [e]
                WHERE (SELECT COUNT_BIG(*) FROM @ContextFields AS [f]
                       WHERE CONVERT(varbinary(max),[f].[Path])=CONVERT(varbinary(max),[e].[Path])
                         AND ([f].[JsonType]=[e].[JsonType] OR ([e].[Nullable]=1 AND [f].[JsonType]=0)))<>1)
               AND NOT EXISTS
               (
                   SELECT 1 FROM @ContextFields AS [f] JOIN @ContextSpec AS [e]
                     ON CONVERT(varbinary(max),[f].[Path])=CONVERT(varbinary(max),[e].[Path])
                   WHERE [f].[JsonType]<>0 AND
                   (
                       ([e].[Kind]='ONE' AND CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),N'1'))
                       OR ([e].[Kind]='WAIT_STATS' AND CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),N'WAIT_STATS'))
                       OR ([e].[Kind] IN('DECIMAL','POSITIVE_ID') AND
                           (TRY_CONVERT(bigint,[f].[Value]) IS NULL OR TRY_CONVERT(bigint,[f].[Value])<CASE WHEN [e].[Kind]='POSITIVE_ID' THEN 1 ELSE 0 END
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[f].[Value])))))
                       OR ([e].[Kind]='POSITIVE_VERSION' AND
                           (TRY_CONVERT(int,[f].[Value]) IS NULL OR TRY_CONVERT(int,[f].[Value])<1
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(11),TRY_CONVERT(int,[f].[Value])))))
                       OR ([e].[Kind]='ENGINE_NAME' AND DATALENGTH([f].[Value]) NOT BETWEEN 2 AND 256)
                       OR ([e].[Kind]='GUID' AND
                           (DATALENGTH([f].[Value])<>72 OR TRY_CONVERT(uniqueidentifier,[f].[Value]) IS NULL
                            OR TRY_CONVERT(uniqueidentifier,[f].[Value])='00000000-0000-0000-0000-000000000000'
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),LOWER(CONVERT(nvarchar(36),TRY_CONVERT(uniqueidentifier,[f].[Value]))))))
                       OR ([e].[Kind]='LOCAL_MS' AND
                           (DATALENGTH([f].[Value])<>46 OR TRY_CONVERT(datetime,[f].[Value],126) IS NULL
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime,[f].[Value],126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,TRY_CONVERT(datetime,[f].[Value],126))),3))))
                       OR ([e].[Kind]='UTC_MS' AND
                           (DATALENGTH([f].[Value])<>48 OR RIGHT([f].[Value],1)<>N'Z'
                            OR TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126) IS NULL
                            OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126))),3)+N'Z')))
                       OR ([e].[Kind]='TRUE' AND CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),N'true'))
                       OR ([e].[Kind]='SHA256' AND
                           (DATALENGTH([f].[Value])<>128 OR [f].[Value] COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%'))
                   )
               )
                SET @ContextValid=1;
        END;

        DECLARE @GlobalStatuses TABLE([Value] nvarchar(40));
        INSERT @GlobalStatuses VALUES(N'SOURCE_EMPTY_UNPROVEN'),(N'WRITE_LIMITED'),(N'FIRST_OBSERVATION'),
          (N'PREVIOUS_CAPTURE_PARTIAL'),(N'PREVIOUS_CONTEXT_INVALID'),(N'PREVIOUS_RAW_INCOMPLETE'),
          (N'ENGINE_CONTEXT_CHANGED'),(N'INTERVAL_NOT_POSITIVE'),(N'WAIT_TYPE_MISSING'),
          (N'COUNTER_DECREASE'),(N'NO_COMPARABLE_TYPES'),(N'MONOTONIC_CONTINUITY_UNPROVEN');
        IF @ContextValid=1
        BEGIN
            IF NOT EXISTS
               (SELECT 1 FROM @ContextFields AS [f] CROSS JOIN @GlobalStatuses AS [s]
                WHERE [f].[Path]=N'comparison.status'
                  AND CONVERT(varbinary(max),[f].[Value])=CONVERT(varbinary(max),[s].[Value]))
               OR NOT EXISTS
               (SELECT 1 FROM @ContextFields AS [f]
                CROSS JOIN (VALUES(N'NEW_FIRST'),(N'NEW_ENGINE_CONTEXT'),(N'NEW_COUNTER_DECREASE'),
                                  (N'NEW_COMPARISON_BREAK'),(N'RETAIN_CONTEXT')) AS [e]([Value])
                WHERE [f].[Path]=N'epochDecision'
                  AND CONVERT(varbinary(max),[f].[Value])=CONVERT(varbinary(max),[e].[Value]))
                SET @ContextValid=0;
        END;
        IF @ContextValid=1
        BEGIN
            SELECT @PreviousContextEpoch=TRY_CONVERT(uniqueidentifier,[Value]) FROM @ContextFields WHERE [Path]=N'resetEpochId';
            SELECT @PreviousMeasurementStart=TRY_CONVERT(datetime2(3),LEFT([Value],23),126) FROM @ContextFields WHERE [Path]=N'window.measurementStartUtc';
            SELECT @PreviousMeasurementEnd=TRY_CONVERT(datetime2(3),LEFT([Value],23),126) FROM @ContextFields WHERE [Path]=N'window.measurementEndUtc';
            SELECT @PreviousEngineName=[Value] FROM @ContextFields WHERE [Path]=N'engine.serverName';
            SELECT @PreviousEngineStart=TRY_CONVERT(datetime,[Value],126) FROM @ContextFields WHERE [Path]=N'engine.sqlServerStartTimeLocal';
            SELECT @PreviousEngineTicks=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'engine.sqlServerStartTimeMsTicks';
            SELECT @PreviousWritten=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.writtenTypeCount';
            SELECT @PreviousActive=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.activeTypeCount';
            SELECT @PreviousEligible=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.eligibleTypeCount';
            SELECT @PreviousNative=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.nativeWaitTypeCount';
            SELECT @PreviousRawCount=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'capture.rawMetricSampleCount';
            SELECT @PreviousLimited=CASE WHEN [Value]=N'true' THEN 1 ELSE 0 END FROM @ContextFields WHERE [Path]=N'capture.writeLimited';
            SELECT @PreviousRawHash=CONVERT(varchar(64),[Value]) FROM @ContextFields WHERE [Path]=N'capture.rawProjectionSha256';
            SELECT @PreviousComparable=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'comparison.comparableTypeCount';
            SELECT @PreviousCandidateCount=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'comparison.candidateSampleCount';
            SELECT @PreviousContextStatus=CONVERT(varchar(40),[Value]) FROM @ContextFields WHERE [Path]=N'comparison.status';
            SELECT @PreviousContextDecision=CONVERT(varchar(40),[Value]) FROM @ContextFields WHERE [Path]=N'epochDecision';
            SELECT @PreviousContextParent=TRY_CONVERT(bigint,[Value]) FROM @ContextFields WHERE [Path]=N'comparison.previousCaptureRunId';
            IF @ServerScopeId IS NULL OR @PreviousEpoch IS NULL OR @PreviousContextEpoch<>@PreviousEpoch
               OR EXISTS(SELECT 1 FROM @ContextFields WHERE [Path]=N'captureRunId' AND TRY_CONVERT(bigint,[Value])<>@PreviousRunId)
               OR EXISTS(SELECT 1 FROM @ContextFields WHERE [Path]=N'serverScopeId' AND TRY_CONVERT(bigint,[Value])<>@ServerScopeId)
               OR @PreviousStarted>@PreviousMeasurementStart OR @PreviousMeasurementStart>@PreviousMeasurementEnd
               OR @PreviousMeasurementEnd>@PreviousEnded
               OR (@PreviousContextParent IS NOT NULL AND @PreviousContextParent>=@PreviousRunId)
               OR (@PreviousContextParent IS NULL AND EXISTS(SELECT 1 FROM @ContextFields WHERE [Path]=N'comparison.previousContextVersion' AND [JsonType]<>0))
               OR (@PreviousContextParent IS NULL AND @PreviousContextDecision<>'NEW_FIRST')
               OR (@PreviousContextParent IS NOT NULL AND @PreviousContextDecision='NEW_FIRST')
               OR NOT EXISTS
               (SELECT 1 FROM [snapshot].[MetricSample]
                WHERE [CaptureRunId]=@PreviousRunId AND [MetricDefinitionId]=@ContextMetric
                  AND [ScopeId]=@ServerScopeId AND [ResetEpochId]=@PreviousEpoch
                  AND [CollectedAtUtc]=@PreviousMeasurementEnd
                  AND CONVERT(varbinary(max),[QualityCode])=CONVERT(varbinary(max),'CAPTURE_CONTEXT_V1')
                  AND [IsPartial]=0 AND [StringValue] IS NOT NULL)
                SET @ContextValid=0;
            -- Bound multiplicands before doing any arithmetic on stored counts.
            IF @PreviousWritten>100000 OR @PreviousComparable>100000 OR @PreviousCandidateCount>300000
               OR @PreviousRawCount>400000 OR @PreviousComparable>@PreviousWritten
               OR @PreviousWritten>@PreviousEligible OR @PreviousEligible>@PreviousNative
               OR @PreviousActive>@PreviousEligible
               OR (@PreviousEligible>0 AND @PreviousWritten=0)
                SET @ContextValid=0;
            IF @ContextValid=1 AND
               (@PreviousRawCount<>4*@PreviousWritten OR @PreviousCandidateCount<>3*@PreviousComparable
                OR @PreviousLimited<>CASE WHEN @PreviousWritten<@PreviousEligible THEN 1 ELSE 0 END
                OR @PreviousSampleCount<>5*@PreviousWritten+@PreviousCandidateCount+1
                OR (@PreviousNative=0 AND @PreviousContextStatus<>'SOURCE_EMPTY_UNPROVEN')
                OR (@PreviousNative>0 AND @PreviousContextStatus='SOURCE_EMPTY_UNPROVEN')
                OR (@PreviousLimited=1 AND @PreviousContextStatus<>'WRITE_LIMITED')
                OR (@PreviousLimited=0 AND @PreviousContextStatus='WRITE_LIMITED')
                OR (@PreviousContextStatus='MONOTONIC_CONTINUITY_UNPROVEN' AND @PreviousComparable=0)
                OR (@PreviousContextStatus<>'MONOTONIC_CONTINUITY_UNPROVEN' AND @PreviousComparable<>0)
                OR (@PreviousContextStatus='FIRST_OBSERVATION' AND @PreviousContextParent IS NOT NULL)
                OR (@PreviousContextParent IS NULL AND @PreviousContextStatus NOT IN('SOURCE_EMPTY_UNPROVEN','WRITE_LIMITED','FIRST_OBSERVATION'))
                OR (@PreviousContextDecision='RETAIN_CONTEXT' AND @PreviousContextStatus NOT IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN'))
                OR (@PreviousContextStatus IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN') AND @PreviousContextDecision<>'RETAIN_CONTEXT')
                OR (@PreviousContextDecision IN('RETAIN_CONTEXT','NEW_ENGINE_CONTEXT','NEW_COUNTER_DECREASE')
                    AND NOT EXISTS(SELECT 1 FROM @ContextFields WHERE [Path]=N'comparison.previousContextVersion'
                                   AND [JsonType]=2 AND CONVERT(varbinary(max),[Value])=CONVERT(varbinary(max),N'1')))
                OR (@PreviousNative=0 AND @PreviousContextDecision='NEW_COUNTER_DECREASE')
                OR (@PreviousContextStatus='ENGINE_CONTEXT_CHANGED' AND @PreviousContextDecision<>'NEW_ENGINE_CONTEXT')
                OR (@PreviousContextStatus='COUNTER_DECREASE' AND @PreviousContextDecision<>'NEW_COUNTER_DECREASE'))
                SET @ContextValid=0;
        END;

        DECLARE @PreviousRows TABLE
        (
            [ScopeId] bigint,[WaitType] nvarchar(60) COLLATE Latin1_General_100_BIN2,
            [IdentityJson] nvarchar(max),[ScopeKeyHash] binary(32),
            [WaitingTasksCount] bigint,[WaitTimeMs] bigint,[MaxWaitTimeMs] bigint,[SignalWaitTimeMs] bigint,
            [DeltaStatus] nvarchar(4000),[RawCount] bigint,[StatusCount] bigint,[CandidateCount] bigint
        );
        IF @ContextValid=1
        BEGIN
            SET @RawValid=1;
            IF @PreviousLimited=1 OR @PreviousNative=0 SET @PreviousTechnicalPartial=1;
            IF CONVERT(varbinary(max),@EngineName)<>CONVERT(varbinary(max),@PreviousEngineName)
               OR @EngineStartLocal<>@PreviousEngineStart OR @EngineTicks<>@PreviousEngineTicks
                SET @EngineChanged=1;
            IF @MeasurementStart<@PreviousMeasurementEnd OR @MeasurementEnd<=@PreviousMeasurementEnd
                SET @IntervalInvalid=1;
            IF (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@PreviousRunId)<>@PreviousSampleCount
               OR EXISTS
               (
                   SELECT 1 FROM [snapshot].[MetricSample] AS [s]
                   LEFT JOIN @Metrics AS [m] ON [m].[Id]=[s].[MetricDefinitionId]
                   LEFT JOIN [snapshot].[Scope] AS [p] ON [p].[ScopeId]=[s].[ScopeId]
                   WHERE [s].[CaptureRunId]=@PreviousRunId AND
                   ([m].[Id] IS NULL OR [s].[ResetEpochId] IS NULL OR [s].[ResetEpochId]<>@PreviousEpoch
                    OR [s].[CollectedAtUtc]<>@PreviousMeasurementEnd
                    OR ([s].[MetricDefinitionId]<>@ContextMetric AND
                        ([p].[ScopeType]<>'WAIT_TYPE' OR [p].[ParentScopeId]<>@ServerScopeId OR [p].[ParentScopeId] IS NULL))
                    OR ([m].[ValueType]='BIGINT' AND ([s].[BigintValue] IS NULL OR [s].[BigintValue]<0))
                    OR ([m].[ValueType]='STRING' AND [s].[StringValue] IS NULL)
                    OR ([m].[Code] IN('WAIT_TASK_COUNT','WAIT_TIME_MS','WAIT_MAX_TIME_MS','WAIT_SIGNAL_TIME_MS')
                        AND (CONVERT(varbinary(max),[s].[QualityCode])<>CONVERT(varbinary(max),'MEASURED_CUMULATIVE') OR [s].[IsPartial]<>0))
                    OR ([m].[Code] LIKE '%_DELTA_CANDIDATE'
                        AND (CONVERT(varbinary(max),[s].[QualityCode])<>CONVERT(varbinary(max),'MONOTONIC_CONTINUITY_UNPROVEN') OR [s].[IsPartial]<>1))
                    OR ([m].[Code]='WAIT_DELTA_STATUS'
                        AND (CONVERT(varbinary(max),[s].[QualityCode])<>CONVERT(varbinary(max),'COMPARISON_STATUS') OR [s].[IsPartial]<>1)))
               )
                SET @RawValid=0;
            INSERT @PreviousRows
            SELECT [p].[ScopeId],
                   CASE WHEN DATALENGTH(JSON_VALUE([p].[ScopeIdentityJson],N'$.waitType')) BETWEEN 2 AND 120
                        THEN CONVERT(nvarchar(60),JSON_VALUE([p].[ScopeIdentityJson],N'$.waitType')) END,
                   [p].[ScopeIdentityJson],[p].[ScopeKeyHash],
                   MAX(CASE WHEN [m].[Code]='WAIT_TASK_COUNT' THEN [s].[BigintValue] END),
                   MAX(CASE WHEN [m].[Code]='WAIT_TIME_MS' THEN [s].[BigintValue] END),
                   MAX(CASE WHEN [m].[Code]='WAIT_MAX_TIME_MS' THEN [s].[BigintValue] END),
                   MAX(CASE WHEN [m].[Code]='WAIT_SIGNAL_TIME_MS' THEN [s].[BigintValue] END),
                   MAX(CASE WHEN [m].[Code]='WAIT_DELTA_STATUS' THEN [s].[StringValue] END),
                   SUM(CONVERT(bigint,CASE WHEN [m].[Code] IN('WAIT_TASK_COUNT','WAIT_TIME_MS','WAIT_MAX_TIME_MS','WAIT_SIGNAL_TIME_MS') THEN 1 ELSE 0 END)),
                   SUM(CONVERT(bigint,CASE WHEN [m].[Code]='WAIT_DELTA_STATUS' THEN 1 ELSE 0 END)),
                   SUM(CONVERT(bigint,CASE WHEN [m].[Code] LIKE '%_DELTA_CANDIDATE' THEN 1 ELSE 0 END))
            FROM [snapshot].[MetricSample] AS [s]
            JOIN @Metrics AS [m] ON [m].[Id]=[s].[MetricDefinitionId]
            JOIN [snapshot].[Scope] AS [p] ON [p].[ScopeId]=[s].[ScopeId]
            WHERE [s].[CaptureRunId]=@PreviousRunId AND [s].[MetricDefinitionId]<>@ContextMetric
            GROUP BY [p].[ScopeId],[p].[ScopeIdentityJson],[p].[ScopeKeyHash];
            IF (SELECT COUNT_BIG(*) FROM @PreviousRows)<>@PreviousWritten
               OR EXISTS
               (
                   SELECT 1 FROM @PreviousRows AS [p]
                   CROSS APPLY(SELECT [p].[WaitType] AS [waitType] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS [j]([IdentityJson])
                   WHERE [p].[WaitType] IS NULL OR [p].[RawCount]<>4 OR [p].[StatusCount]<>1
                      OR [p].[WaitingTasksCount] IS NULL OR [p].[WaitTimeMs] IS NULL
                      OR [p].[MaxWaitTimeMs] IS NULL OR [p].[SignalWaitTimeMs] IS NULL
                      OR [p].[DeltaStatus] IS NULL
                      OR CONVERT(varbinary(max),[p].[IdentityJson])<>CONVERT(varbinary(max),[j].[IdentityJson])
                      OR [p].[ScopeKeyHash]<>HASHBYTES('SHA2_256',CONVERT(varbinary(max),[j].[IdentityJson]))
                      OR ([p].[CandidateCount]<>0 AND [p].[CandidateCount]<>3)
                      OR NOT EXISTS(SELECT 1 FROM @GlobalStatuses AS [v]
                                    WHERE CONVERT(varbinary(max),[v].[Value])=CONVERT(varbinary(max),[p].[DeltaStatus]))
                      OR ([p].[CandidateCount]=3 AND CONVERT(varbinary(max),[p].[DeltaStatus])<>CONVERT(varbinary(max),N'MONOTONIC_CONTINUITY_UNPROVEN'))
                      OR ([p].[CandidateCount]=0 AND CONVERT(varbinary(max),[p].[DeltaStatus])=CONVERT(varbinary(max),N'MONOTONIC_CONTINUITY_UNPROVEN'))
                      OR (@PreviousContextStatus IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN')
                          AND [p].[DeltaStatus] NOT IN(N'FIRST_OBSERVATION',N'MONOTONIC_CONTINUITY_UNPROVEN'))
                      OR (@PreviousContextStatus NOT IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN')
                          AND CONVERT(varbinary(max),[p].[DeltaStatus])<>CONVERT(varbinary(max),CONVERT(nvarchar(40),@PreviousContextStatus)))
               )
               OR (SELECT COUNT_BIG(*) FROM @PreviousRows WHERE [CandidateCount]=3)<>@PreviousComparable
               OR (SELECT COUNT_BIG(*) FROM @PreviousRows WHERE [WaitingTasksCount]>0 OR [WaitTimeMs]>0 OR [MaxWaitTimeMs]>0 OR [SignalWaitTimeMs]>0)>@PreviousActive
               OR (@PreviousLimited=0 AND (SELECT COUNT_BIG(*) FROM @PreviousRows WHERE [WaitingTasksCount]>0 OR [WaitTimeMs]>0 OR [MaxWaitTimeMs]>0 OR [SignalWaitTimeMs]>0)<>@PreviousActive)
                SET @RawValid=0;
            DECLARE @PreviousRawJson nvarchar(max)=
             (SELECT [WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs]
              FROM @PreviousRows ORDER BY [WaitType] COLLATE Latin1_General_100_BIN2,DATALENGTH([WaitType]),[ScopeKeyHash] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @PreviousRawJson=COALESCE(@PreviousRawJson,N'[]');
            IF CONVERT(varbinary(max),LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PreviousRawJson)),2)))
                <>CONVERT(varbinary(max),@PreviousRawHash)
                SET @RawValid=0;
        END;

        IF @ContextValid=1 AND (@PreviousStatus NOT IN('AVAILABLE','PARTIAL') OR @PreviousError IS NOT NULL)
        BEGIN
            SET @ContextValid=0;
            SET @RawValid=0;
            SET @EngineChanged=0;
        END;
        IF @ContextValid=1 AND @RawValid=1
        BEGIN
            IF EXISTS(SELECT 1 FROM @PreviousRows AS [p]
                      WHERE NOT EXISTS(SELECT 1 FROM @Waits AS [c] WHERE [c].[ScopeKeyHash]=[p].[ScopeKeyHash]))
                SET @WaitTypeMissing=1;
            IF @EngineChanged=0 AND EXISTS
               (SELECT 1 FROM @PreviousRows AS [p] JOIN @Waits AS [c] ON [c].[ScopeKeyHash]=[p].[ScopeKeyHash]
                WHERE [c].[WaitingTasksCount]<[p].[WaitingTasksCount] OR [c].[WaitTimeMs]<[p].[WaitTimeMs]
                   OR [c].[MaxWaitTimeMs]<[p].[MaxWaitTimeMs] OR [c].[SignalWaitTimeMs]<[p].[SignalWaitTimeMs])
                SET @CounterDecrease=1;
        END;

        -- Hints preserve actually observed current zeros even when the old context
        -- or some old samples are missing. Hints never qualify numeric candidates.
        DECLARE @PreviousTypeHints TABLE([ScopeKeyHash] binary(32) PRIMARY KEY);
        IF @PreviousRunId IS NOT NULL AND @ServerScopeId IS NOT NULL
            INSERT @PreviousTypeHints
            SELECT DISTINCT [p].[ScopeKeyHash]
            FROM [snapshot].[Scope] AS [p]
            CROSS APPLY(SELECT JSON_VALUE([p].[ScopeIdentityJson],N'$.waitType') AS [WaitType]) AS [n]
            CROSS APPLY(SELECT [n].[WaitType] AS [waitType] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS [j]([IdentityJson])
            WHERE CONVERT(varbinary(max),[p].[ScopeType])=CONVERT(varbinary(max),'WAIT_TYPE')
              AND [p].[ParentScopeId]=@ServerScopeId AND DATALENGTH([n].[WaitType]) BETWEEN 2 AND 120
              AND CONVERT(varbinary(max),[p].[ScopeIdentityJson])=CONVERT(varbinary(max),[j].[IdentityJson])
              AND [p].[ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[j].[IdentityJson]))
              AND EXISTS(SELECT 1 FROM [snapshot].[MetricSample] AS [s] JOIN @Metrics AS [m] ON [m].[Id]=[s].[MetricDefinitionId]
                         WHERE [s].[CaptureRunId]=@PreviousRunId AND [s].[ScopeId]=[p].[ScopeId]
                           AND [s].[MetricDefinitionId]<>@ContextMetric);
        SELECT @ActiveTypes=COUNT_BIG(*) FROM @Waits
        WHERE [WaitingTasksCount]>0 OR [WaitTimeMs]>0 OR [MaxWaitTimeMs]>0 OR [SignalWaitTimeMs]>0;
        UPDATE [c] SET [IsEligible]=1 FROM @Waits AS [c]
        WHERE [c].[WaitingTasksCount]>0 OR [c].[WaitTimeMs]>0 OR [c].[MaxWaitTimeMs]>0 OR [c].[SignalWaitTimeMs]>0
           OR EXISTS(SELECT 1 FROM @PreviousTypeHints AS [p] WHERE [p].[ScopeKeyHash]=[c].[ScopeKeyHash]);
        SELECT @EligibleTypes=COUNT_BIG(*) FROM @Waits WHERE [IsEligible]=1;
        ;WITH [Chosen] AS
        (
            SELECT [ScopeKeyHash],ROW_NUMBER() OVER
             (ORDER BY [WaitType] COLLATE Latin1_General_100_BIN2,DATALENGTH([WaitType]),[ScopeKeyHash]) AS [Ordinal]
            FROM @Waits WHERE [IsEligible]=1
        )
        UPDATE [c] SET [IsSelected]=1 FROM @Waits AS [c]
        JOIN [Chosen] AS [s] ON [s].[ScopeKeyHash]=[c].[ScopeKeyHash] WHERE [s].[Ordinal]<=@MaxRows;
        SELECT @WrittenTypes=COUNT_BIG(*) FROM @Waits WHERE [IsSelected]=1;
        SET @WriteLimited=CASE WHEN @WrittenTypes<@EligibleTypes THEN 1 ELSE 0 END;

        IF @NativeRows=0 SET @ComparisonStatus='SOURCE_EMPTY_UNPROVEN';
        ELSE IF @WriteLimited=1 SET @ComparisonStatus='WRITE_LIMITED';
        ELSE IF @PreviousRunId IS NULL SET @ComparisonStatus='FIRST_OBSERVATION';
        ELSE IF @PreviousTechnicalPartial=1 SET @ComparisonStatus='PREVIOUS_CAPTURE_PARTIAL';
        ELSE IF @ContextValid=0 SET @ComparisonStatus='PREVIOUS_CONTEXT_INVALID';
        ELSE IF @RawValid=0 SET @ComparisonStatus='PREVIOUS_RAW_INCOMPLETE';
        ELSE IF @EngineChanged=1 SET @ComparisonStatus='ENGINE_CONTEXT_CHANGED';
        ELSE IF @IntervalInvalid=1 SET @ComparisonStatus='INTERVAL_NOT_POSITIVE';
        ELSE IF @WaitTypeMissing=1 SET @ComparisonStatus='WAIT_TYPE_MISSING';
        ELSE IF @CounterDecrease=1 SET @ComparisonStatus='COUNTER_DECREASE';
        ELSE
        BEGIN
            UPDATE [c] SET [IsComparable]=1 FROM @Waits AS [c]
            WHERE [c].[IsSelected]=1 AND EXISTS(SELECT 1 FROM @PreviousRows AS [p] WHERE [p].[ScopeKeyHash]=[c].[ScopeKeyHash]);
            SELECT @ComparableTypes=COUNT_BIG(*) FROM @Waits WHERE [IsComparable]=1;
            SET @ComparisonStatus=CASE WHEN @ComparableTypes=0 THEN 'NO_COMPARABLE_TYPES' ELSE 'MONOTONIC_CONTINUITY_UNPROVEN' END;
        END;
        SET @CandidateSamples=3*@ComparableTypes;
        IF @PreviousRunId IS NULL SET @EpochDecision='NEW_FIRST';
        ELSE IF @ContextValid=1 AND @EngineChanged=1 SET @EpochDecision='NEW_ENGINE_CONTEXT';
        ELSE IF @ContextValid=1 AND @RawValid=1 AND @CounterDecrease=1 SET @EpochDecision='NEW_COUNTER_DECREASE';
        ELSE IF @ComparisonStatus IN('SOURCE_EMPTY_UNPROVEN','WRITE_LIMITED','PREVIOUS_CAPTURE_PARTIAL',
                 'PREVIOUS_CONTEXT_INVALID','PREVIOUS_RAW_INCOMPLETE','INTERVAL_NOT_POSITIVE','WAIT_TYPE_MISSING')
            SET @EpochDecision='NEW_COMPARISON_BREAK';
        ELSE SET @EpochDecision='RETAIN_CONTEXT';
        SET @Epoch=CASE WHEN @EpochDecision='RETAIN_CONTEXT' THEN @PreviousEpoch ELSE NEWID() END;
        IF @Epoch IS NULL OR @Epoch='00000000-0000-0000-0000-000000000000'
           OR (@EpochDecision<>'RETAIN_CONTEXT' AND @PreviousEpoch IS NOT NULL AND @Epoch=@PreviousEpoch)
            THROW 53766,N'Eine neue Vergleichsepoche konnte nicht eindeutig gebildet werden.',1;
        UPDATE @Waits SET [DeltaStatus]=CASE WHEN @ComparisonStatus IN('NO_COMPARABLE_TYPES','MONOTONIC_CONTINUITY_UNPROVEN')
                       THEN CASE WHEN [IsComparable]=1 THEN 'MONOTONIC_CONTINUITY_UNPROVEN' ELSE 'FIRST_OBSERVATION' END
                       ELSE @ComparisonStatus END WHERE [IsSelected]=1;

        IF @ServerScopeId IS NULL
        BEGIN
            INSERT [snapshot].[Scope] ([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
            VALUES('SERVER',NULL,@ServerHash,@ServerIdentity,SYSUTCDATETIME());
            SET @ServerScopeId=CONVERT(bigint,SCOPE_IDENTITY());
        END;
        IF @ServerScopeId<=0 THROW 53766,N'Der SERVER-Scope benötigt eine positive Kennung.',1;
        IF EXISTS
           (SELECT 1 FROM @Waits AS [c] JOIN [snapshot].[Scope] AS [s]
             ON [s].[ScopeType]='WAIT_TYPE' AND [s].[ParentScopeId]=@ServerScopeId AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
            WHERE [c].[IsSelected]=1 AND ([s].[ScopeId]<=0
              OR CONVERT(varbinary(max),[s].[ScopeType])<>CONVERT(varbinary(max),'WAIT_TYPE')
              OR CONVERT(varbinary(max),[s].[ScopeIdentityJson])<>CONVERT(varbinary(max),[c].[ScopeIdentityJson])))
            THROW 53766,N'Ein vorhandener Wait-Scope widerspricht seiner Identität.',1;
        INSERT [snapshot].[Scope] ([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
        SELECT 'WAIT_TYPE',@ServerScopeId,[c].[ScopeKeyHash],[c].[ScopeIdentityJson],SYSUTCDATETIME()
        FROM @Waits AS [c] WHERE [c].[IsSelected]=1 AND NOT EXISTS
         (SELECT 1 FROM [snapshot].[Scope] AS [s]
          WHERE [s].[ScopeType]='WAIT_TYPE' AND [s].[ParentScopeId]=@ServerScopeId AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]);
        UPDATE [c] SET [ScopeId]=[s].[ScopeId] FROM @Waits AS [c]
        JOIN [snapshot].[Scope] AS [s] ON [s].[ScopeType]='WAIT_TYPE'
          AND [s].[ParentScopeId]=@ServerScopeId AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
        WHERE [c].[IsSelected]=1;

        INSERT [snapshot].[MetricSample]
        ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[BigintValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[c].[ScopeId],[m].[Id],@MeasurementEnd,@Epoch,[v].[Value],'MEASURED_CUMULATIVE',0
        FROM @Waits AS [c]
        CROSS APPLY(VALUES('WAIT_TASK_COUNT',[c].[WaitingTasksCount]),('WAIT_TIME_MS',[c].[WaitTimeMs]),
                          ('WAIT_MAX_TIME_MS',[c].[MaxWaitTimeMs]),('WAIT_SIGNAL_TIME_MS',[c].[SignalWaitTimeMs])) AS [v]([Code],[Value])
        JOIN @Metrics AS [m] ON [m].[Code]=[v].[Code] WHERE [c].[IsSelected]=1;
        INSERT [snapshot].[MetricSample]
        ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[BigintValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[c].[ScopeId],[m].[Id],@MeasurementEnd,@Epoch,[v].[Value],'MONOTONIC_CONTINUITY_UNPROVEN',1
        FROM @Waits AS [c] JOIN @PreviousRows AS [p] ON [p].[ScopeKeyHash]=[c].[ScopeKeyHash]
        CROSS APPLY(VALUES('WAIT_TASK_COUNT_DELTA_CANDIDATE',[c].[WaitingTasksCount]-[p].[WaitingTasksCount]),
                          ('WAIT_TIME_MS_DELTA_CANDIDATE',[c].[WaitTimeMs]-[p].[WaitTimeMs]),
                          ('WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE',[c].[SignalWaitTimeMs]-[p].[SignalWaitTimeMs])) AS [v]([Code],[Value])
        JOIN @Metrics AS [m] ON [m].[Code]=[v].[Code] WHERE [c].[IsComparable]=1;
        INSERT [snapshot].[MetricSample]
        ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[StringValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[ScopeId],@DeltaStatusMetric,@MeasurementEnd,@Epoch,[DeltaStatus],'COMPARISON_STATUS',1
        FROM @Waits WHERE [IsSelected]=1;

        DECLARE @StoredRaw TABLE
        ([ScopeId] bigint,[WaitType] nvarchar(60) COLLATE Latin1_General_100_BIN2,[ScopeKeyHash] binary(32),
         [WaitingTasksCount] bigint,[WaitTimeMs] bigint,[MaxWaitTimeMs] bigint,[SignalWaitTimeMs] bigint,[RawCount] bigint);
        INSERT @StoredRaw
        SELECT [c].[ScopeId],[c].[WaitType],[c].[ScopeKeyHash],
               MAX(CASE WHEN [m].[Code]='WAIT_TASK_COUNT' THEN [s].[BigintValue] END),
               MAX(CASE WHEN [m].[Code]='WAIT_TIME_MS' THEN [s].[BigintValue] END),
               MAX(CASE WHEN [m].[Code]='WAIT_MAX_TIME_MS' THEN [s].[BigintValue] END),
               MAX(CASE WHEN [m].[Code]='WAIT_SIGNAL_TIME_MS' THEN [s].[BigintValue] END),COUNT_BIG(*)
        FROM @Waits AS [c] JOIN [snapshot].[MetricSample] AS [s] ON [s].[ScopeId]=[c].[ScopeId] AND [s].[CaptureRunId]=@CaptureRunId
        JOIN @Metrics AS [m] ON [m].[Id]=[s].[MetricDefinitionId]
        WHERE [c].[IsSelected]=1 AND [m].[Code] IN('WAIT_TASK_COUNT','WAIT_TIME_MS','WAIT_MAX_TIME_MS','WAIT_SIGNAL_TIME_MS')
        GROUP BY [c].[ScopeId],[c].[WaitType],[c].[ScopeKeyHash];
        IF (SELECT COUNT_BIG(*) FROM @StoredRaw)<>@WrittenTypes
           OR EXISTS(SELECT 1 FROM @StoredRaw AS [s] JOIN @Waits AS [c] ON [c].[ScopeId]=[s].[ScopeId]
                     WHERE [s].[RawCount]<>4 OR [s].[WaitingTasksCount]<>[c].[WaitingTasksCount]
                        OR [s].[WaitTimeMs]<>[c].[WaitTimeMs] OR [s].[MaxWaitTimeMs]<>[c].[MaxWaitTimeMs]
                        OR [s].[SignalWaitTimeMs]<>[c].[SignalWaitTimeMs])
            THROW 53766,N'Die tatsächliche Rohprojektion weicht von der ausgewählten Aufnahme ab.',1;
        SELECT @RawJson=(SELECT [WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs]
                         FROM @StoredRaw ORDER BY [WaitType] COLLATE Latin1_General_100_BIN2,DATALENGTH([WaitType]),[ScopeKeyHash]
                         FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @RawJson=COALESCE(@RawJson,N'[]');
        SET @RawHash=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@RawJson));

        SELECT @ContextJson=
        (
            SELECT 1 AS [schemaVersion],'WAIT_STATS' AS [collectorCode],1 AS [metricContractVersion],
                   CONVERT(varchar(20),@CaptureRunId) AS [captureRunId],
                   CONVERT(varchar(20),@ServerScopeId) AS [serverScopeId],
                   LOWER(CONVERT(varchar(36),@Epoch)) AS [resetEpochId],
                   JSON_QUERY((SELECT @EngineName AS [serverName],
                     CONVERT(nvarchar(19),@EngineStartLocal,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@EngineStartLocal)),3) AS [sqlServerStartTimeLocal],
                     CONVERT(varchar(20),@EngineTicks) AS [sqlServerStartTimeMsTicks]
                     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [engine],
                   JSON_QUERY((SELECT
                     CONVERT(nvarchar(19),@MeasurementStart,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@MeasurementStart)),3)+N'Z' AS [measurementStartUtc],
                     CONVERT(nvarchar(19),@MeasurementEnd,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@MeasurementEnd)),3)+N'Z' AS [measurementEndUtc]
                     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [window],
                   JSON_QUERY((SELECT CONVERT(bit,1) AS [sourceComplete],
                     CONVERT(varchar(20),@NativeRows) AS [nativeWaitTypeCount],
                     CONVERT(varchar(20),@ActiveTypes) AS [activeTypeCount],
                     CONVERT(varchar(20),@EligibleTypes) AS [eligibleTypeCount],
                     CONVERT(varchar(20),@WrittenTypes) AS [writtenTypeCount],@WriteLimited AS [writeLimited],
                     CONVERT(varchar(20),4*@WrittenTypes) AS [rawMetricSampleCount],
                     LOWER(CONVERT(varchar(64),@RawHash,2)) AS [rawProjectionSha256]
                     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [capture],
                   JSON_QUERY((SELECT CONVERT(varchar(20),@PreviousRunId) AS [previousCaptureRunId],
                     @PreviousContextVersion AS [previousContextVersion],@ComparisonStatus AS [status],
                     CONVERT(varchar(20),@ComparableTypes) AS [comparableTypeCount],
                     CONVERT(varchar(20),@CandidateSamples) AS [candidateSampleCount]
                     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [comparison],
                   @EpochDecision AS [epochDecision]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
        );
        IF DATALENGTH(@ContextJson)>8000 OR COALESCE(ISJSON(@ContextJson),0)<>1
            THROW 53766,N'Der Aufnahme-/Vergleichskontext überschreitet seinen Stringvertrag.',1;
        INSERT [snapshot].[MetricSample]
        ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[StringValue],[QualityCode],[IsPartial])
        VALUES(@CaptureRunId,@ServerScopeId,@ContextMetric,@MeasurementEnd,@Epoch,@ContextJson,'CAPTURE_CONTEXT_V1',0);
        IF (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)
              <>5*@WrittenTypes+@CandidateSamples+1
           OR 5*@WrittenTypes+@CandidateSamples+1>8*CONVERT(bigint,@MaxRows)+1
            THROW 53766,N'Die tatsächlich gespeicherte Waitmenge widerspricht dem Mengenvertrag.',1;
        IF @PayloadEnabled=1
            INSERT [snapshot].[PayloadSnapshot]
            ([CaptureRunId],[ModuleName],[CapturedAtUtc],[PayloadFormat],[PayloadContractVersion],
             [CompressionType],[PayloadHash],[Payload],[UncompressedCharacterCount])
            VALUES(@CaptureRunId,N'sys.dm_os_wait_stats',@MeasurementEnd,'JSON',1,'GZIP',
                   HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CollectorJson)),COMPRESS(@CollectorJson),DATALENGTH(@CollectorJson)/2);
        INSERT [snapshot].[ModuleStatus]
        ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
        VALUES(@CaptureRunId,N'sys.dm_os_wait_stats',@MeasurementEnd,@SourceStatus,@SourcePartial,NULL,NULL,
               N'Ein vollständiger nativer Cache mit Enginekontext vor und nach dem Read; keine behauptete atomare DMV-Sicht.'),
              (@CaptureRunId,N'snapshot.InternalCompleteWaitStatsCycle',@MeasurementEnd,'PARTIAL',1,NULL,
               CONVERT(nvarchar(40),@ComparisonStatus),N'Monotone Differenzkandidaten beweisen keine ununterbrochene Resetkontinuität.');
        DECLARE @FinishedAt datetime2(3)=SYSUTCDATETIME();
        IF @FinishedAt<@MeasurementEnd OR @FinishedAt<@StartedAtUtc
            THROW 53766,N'Die tatsächliche Finalisierungszeit liegt vor der Aufnahme.',1;
        UPDATE [snapshot].[CaptureRun]
        SET [EndedAtUtc]=@FinishedAt,[SqlServerStartTimeUtc]=NULL,[ResetEpochId]=@Epoch,
            [StatusCode]='PARTIAL',[IsPartial]=1,[ErrorNumber]=NULL,[ErrorMessage]=CONVERT(nvarchar(40),@ComparisonStatus),
            [MetricSampleCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId),
            [PayloadCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
        WHERE [CaptureRunId]=@CaptureRunId AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING';
        IF @@ROWCOUNT<>1 THROW 53766,N'Der eigene Wait-Run konnte nicht finalisiert werden.',1;
        COMMIT TRANSACTION;
        SELECT @StatusCodeOut='PARTIAL',@IsPartialOut=1,@ErrorNumberOut=NULL,
               @ErrorMessageOut=CONVERT(nvarchar(40),@ComparisonStatus);
        RETURN;

FinalizeWithoutMetrics:
        IF @PayloadEnabled=1
            INSERT [snapshot].[PayloadSnapshot]
            ([CaptureRunId],[ModuleName],[CapturedAtUtc],[PayloadFormat],[PayloadContractVersion],
             [CompressionType],[PayloadHash],[Payload],[UncompressedCharacterCount])
            VALUES(@CaptureRunId,N'sys.dm_os_wait_stats',SYSUTCDATETIME(),'JSON',1,'GZIP',
                   HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CollectorJson)),COMPRESS(@CollectorJson),DATALENGTH(@CollectorJson)/2);
        INSERT [snapshot].[ModuleStatus]
        ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
        VALUES(@CaptureRunId,N'sys.dm_os_wait_stats',SYSUTCDATETIME(),@StatusCodeOut,1,@ErrorNumberOut,@ErrorMessageOut,
               N'Kein vollständiger Counterread; keine Rohsamples, kein Kontextsample und keine erfundene Epoche.');
        UPDATE [snapshot].[CaptureRun]
        SET [EndedAtUtc]=SYSUTCDATETIME(),[SqlServerStartTimeUtc]=NULL,[ResetEpochId]=NULL,
            [StatusCode]=@StatusCodeOut,[IsPartial]=1,[ErrorNumber]=@ErrorNumberOut,[ErrorMessage]=@ErrorMessageOut,
            [MetricSampleCount]=0,[PayloadCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
        WHERE [CaptureRunId]=@CaptureRunId AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING';
        IF @@ROWCOUNT<>1 THROW 53766,N'Der fehlgeschlagene eigene Wait-Run konnte nicht finalisiert werden.',1;
        COMMIT TRANSACTION;
        RETURN;
    END TRY
    BEGIN CATCH
        DECLARE @Failure int=ERROR_NUMBER(),@FailureMessage nvarchar(2048)=ERROR_MESSAGE();
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN @Failure IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                  WHEN @Failure IN(53761,53762,53764,2812,8144,8145) THEN 'TARGET_UNAVAILABLE'
                                  WHEN @OwnRun=0 AND @Failure=53763 THEN 'INVALID_PARAMETER'
                                  ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=CASE WHEN @OwnRun=0 AND @Failure=53763 THEN 51011 ELSE @Failure END,
               @ErrorMessageOut=@FailureMessage;
        IF @OwnRun=1 AND DB_ID()=@ExpectedTargetDatabaseId
           AND EXISTS(SELECT 1 FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
                      WHERE [d].[database_id]=@ExpectedTargetDatabaseId AND [d].[create_date]=@ExpectedTargetCreateDate
                        AND CONVERT(varbinary(max),[d].[name])=CONVERT(varbinary(max),@ExpectedTargetDatabaseName)
                        AND [d].[state]=0 AND [d].[is_read_only]=0)
        BEGIN TRY
            BEGIN TRANSACTION;
            IF EXISTS(SELECT 1 FROM [snapshot].[CaptureRun] WITH (UPDLOCK,HOLDLOCK)
                      WHERE [CaptureRunId]=@CaptureRunId AND [CollectorCode]='WAIT_STATS'
                        AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING')
               AND NOT EXISTS(SELECT 1 FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)
               AND NOT EXISTS(SELECT 1 FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
               AND NOT EXISTS(SELECT 1 FROM [snapshot].[ModuleStatus] WHERE [CaptureRunId]=@CaptureRunId)
            BEGIN
                INSERT [snapshot].[ModuleStatus]
                ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                VALUES(@CaptureRunId,N'snapshot.InternalCompleteWaitStatsCycle',SYSUTCDATETIME(),@StatusCodeOut,1,
                       @ErrorNumberOut,@ErrorMessageOut,N'Die eigene Aufnahme wurde zurückgerollt; keine erfolgreiche Finalisierung wird behauptet.');
                UPDATE [snapshot].[CaptureRun]
                SET [EndedAtUtc]=SYSUTCDATETIME(),[SqlServerStartTimeUtc]=NULL,[ResetEpochId]=NULL,
                    [StatusCode]=@StatusCodeOut,[IsPartial]=1,[ErrorNumber]=@ErrorNumberOut,[ErrorMessage]=@ErrorMessageOut,
                    [MetricSampleCount]=0,[PayloadCount]=0
                WHERE [CaptureRunId]=@CaptureRunId AND [EndedAtUtc] IS NULL AND [StatusCode]='RUNNING';
            END;
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
            SET @ErrorMessageOut=LEFT(CONCAT(@FailureMessage,N' Fehlerfinalisierung nicht bestätigt: ',ERROR_MESSAGE()),2048);
        END CATCH;
        IF @OwnRun=0 AND @Failure=53763 RETURN 51011;
    END CATCH;
END;
GO
