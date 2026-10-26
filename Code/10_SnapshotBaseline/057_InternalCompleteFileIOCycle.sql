/*
===============================================================================
Objekt       : snapshot.InternalCompleteFileIOCycle
Version      : 1.1.0
Stand        : 2026-10-26
Zweck        : Die Procedure bindet Datei-I/O-Rohwerte und Vergleichskontexte
               atomar an einen vorbereiteten eigenen Lauf.
Grenze       : Monotone Kandidaten beweisen keine Resetkontinuität.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [snapshot].[InternalCompleteFileIOCycle]
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
    SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0 OR COALESCE(@CaptureRunId,0)<=0
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der Dateiabschluss benötigt einen gültigen Lauf ohne Callertransaktion oder implizite Transaktionen.';
        RETURN 51011;
    END;
    IF @ExpectedTargetDatabaseId IS NULL OR @ExpectedTargetDatabaseName IS NULL
       OR @ExpectedTargetCreateDate IS NULL OR @ExpectedTargetDatabaseId<=4 OR DB_ID()<>@ExpectedTargetDatabaseId
       OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
          WHERE [database_id]=@ExpectedTargetDatabaseId AND [create_date]=@ExpectedTargetCreateDate
          AND CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@ExpectedTargetDatabaseName)
          AND [state]=0 AND [is_read_only]=0)
    BEGIN
        SELECT @StatusCodeOut='TARGET_UNAVAILABLE',@IsPartialOut=1,@ErrorNumberOut=53764,
               @ErrorMessageOut=N'Die erwartete Snapshot-Zielidentität stimmt nicht mehr überein.';
        RETURN;
    END;
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET XACT_ABORT ON;
    DECLARE @OwnRun bit=0,@SourceValidated bit=0,@ValidatedIssuesJson nvarchar(max),
            @SourceErrorNumber int,@SourceErrorMessage nvarchar(2048),@Started datetime2(3),@SourceName sysname,@MaxRows int,@Payload bit,
            @Now datetime2(3),@Meta nvarchar(max),@Engine nvarchar(max),@Framework nvarchar(max),@Selection nvarchar(max),
            @Start datetime2(3),@End datetime2(3),@ReadStart datetime2(3),@ReadEnd datetime2(3),
            @SourceStatus varchar(40),@Complete bit,@Fatal bit,@Native bigint,@Eligible bigint,@Excluded bigint,@Unbound bigint,
            @Written bigint,@Comparable bigint=0,@Limited bit,@ServerScope bigint,@ServerIdentity nvarchar(max),
            @Previous bigint,@PreviousStatus varchar(40),@PreviousEnded datetime2(3),@PreviousContext nvarchar(max),@PreviousValid bit=0,
            @SelectionHash varchar(64),@EngineHash varchar(64),@FrameworkHash varchar(64),
            @Context nvarchar(max),@ContextEpoch uniqueidentifier=NEWID(),@Manifest nvarchar(max),@ManifestHash varchar(64);
    DECLARE @Objects TABLE([Id] int IDENTITY PRIMARY KEY,[Kind] varchar(8),[Ordinal] int,[Json] nvarchar(max));
    DECLARE @Fields TABLE([ObjectId] int,[Name] nvarchar(4000) COLLATE Latin1_General_100_BIN2,[Value] nvarchar(max),[Type] int);
    DECLARE @Spec TABLE([Kind] varchar(8),[Name] nvarchar(80) COLLATE Latin1_General_100_BIN2,[Type] int,[Nullable] bit,[Format] varchar(12),[Limit] int);
    DECLARE @Issues TABLE([Ordinal] int PRIMARY KEY,[ScopeType] varchar(16) COLLATE Latin1_General_100_BIN2,[SourceName] nvarchar(128) COLLATE Latin1_General_100_BIN2,
        [DatabaseId] int,[FileId] int,[DatabaseName] nvarchar(128) NULL,[StatusCode] varchar(40) COLLATE Latin1_General_100_BIN2,[ErrorNumber] int,
        [ErrorMessage] nvarchar(2048),[EvidenceLimit] nvarchar(1000));
    DECLARE @Databases TABLE([Id] int PRIMARY KEY,[Name] sysname,[Created] datetime,[Status] varchar(40) COLLATE Latin1_General_100_BIN2);
    DECLARE @Files TABLE([Ordinal] int PRIMARY KEY,[DatabaseId] int,[FileId] int,[SampleMs] bigint,
        [Reads] bigint,[ReadBytes] bigint,[ReadStallMs] bigint,[Writes] bigint,[WriteBytes] bigint,[WriteStallMs] bigint,[Size] bigint,
        [Handle] varchar(18),[Before] nvarchar(max),[After] nvarchar(max),[Partition] varchar(8),[Complete] bit DEFAULT(0),
        [Selected] bit DEFAULT(0),[Identity] nvarchar(max),[WithoutHandle] nvarchar(max),[ScopeId] bigint,[Epoch] uniqueidentifier,
        [Comparison] varchar(40),[Decision] varchar(40),[PreviousVersion] int,[RawHash] varchar(64),[Context] nvarchar(max),
        [PreviousReads] bigint,[PreviousReadBytes] bigint,[PreviousReadStallMs] bigint,
        [PreviousWrites] bigint,[PreviousWriteBytes] bigint,[PreviousWriteStallMs] bigint);
    DECLARE @Metrics TABLE([Code] varchar(96) COLLATE Latin1_General_100_BIN2 PRIMARY KEY,[Id] bigint,[Type] varchar(24),[Unit] varchar(40));
    BEGIN TRY
        IF (SELECT COUNT_BIG(*) FROM [snapshot].[PackageVersion])<>1 OR NOT EXISTS
           (SELECT 1 FROM [snapshot].[PackageVersion] WHERE CONVERT(varbinary(max),[PackageCode])=CONVERT(varbinary(max),'SC-023')
            AND CONVERT(varbinary(max),[PackageVersion])=CONVERT(varbinary(max),'1.3.1') AND [SchemaVersion]=3)
            THROW 53781,N'Der Dateiabschluss benötigt das vollständige Schema-3-Target.',1;
        DECLARE @Probe bigint,@ProbeStatus varchar(40),@ProbeBudget bit,@ProbeError int,@ProbeMessage nvarchar(2048),@Retention int;
        EXEC [snapshot].[InternalPurgeExpiredData] @MaxBatches=1,@Force=0,@PurgeRunIdOut=@Probe OUTPUT,
             @StatusCodeOut=@ProbeStatus OUTPUT,@BudgetExceededOut=@ProbeBudget OUTPUT,@ErrorNumberOut=@ProbeError OUTPUT,
             @ErrorMessageOut=@ProbeMessage OUTPUT,@ContractOnly=1,@RetentionContractVersionOut=@Retention OUTPUT,
             @ExpectedTargetDatabaseId=@ExpectedTargetDatabaseId,@ExpectedTargetDatabaseName=@ExpectedTargetDatabaseName,
             @ExpectedTargetCreateDate=@ExpectedTargetCreateDate;
        IF COALESCE(@ProbeStatus,'')<>'AVAILABLE' OR COALESCE(@ProbeBudget,1)<>0 OR COALESCE(@Retention,0)<>3
           OR @Probe IS NOT NULL OR @ProbeError IS NOT NULL
            THROW 53781,N'Der tatsächlich ausgeführte schreibfreie Retentionsvertrag 3 fehlt.',1;
        BEGIN TRANSACTION;
        SELECT @Started=[StartedAtUtc],@SourceName=[SourceDatabaseName] FROM [snapshot].[CaptureRun] WITH (UPDLOCK,HOLDLOCK)
        WHERE [CaptureRunId]=@CaptureRunId AND CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),'FILE_IO')
          AND [StatusCode]='RUNNING' AND [EndedAtUtc] IS NULL AND [ResetEpochId] IS NULL
          AND [SqlServerStartTimeUtc] IS NULL AND [MetricSampleCount]=0 AND [PayloadCount]=0;
        IF @Started IS NULL OR EXISTS(SELECT 1 FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)
           OR EXISTS(SELECT 1 FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
           OR EXISTS(SELECT 1 FROM [snapshot].[ModuleStatus] WHERE [CaptureRunId]=@CaptureRunId)
            THROW 53783,N'Der Dateiabschluss benötigt einen unbeschriebenen eigenen RUNNING-Lauf.',1;
        SET @OwnRun=1;
        SELECT @MaxRows=[MaxRows],@Payload=[PayloadEnabled] FROM [snapshot].[CollectorPolicy]
        WHERE [CollectorCode]='FILE_IO' AND [IsEnabled]=1;
        IF @MaxRows IS NULL OR @MaxRows NOT BETWEEN 1 AND 100000 OR @Payload IS NULL
            THROW 53783,N'Die aktive gültige Datei-I/O-Policy fehlt.',1;
        INSERT @Spec VALUES
          ('ROOT',N'meta',5,0,'',0),
          ('ROOT',N'databases',4,0,'',0),
          ('ROOT',N'files',4,0,'',0),
          ('ROOT',N'issues',4,0,'',0),
          ('META',N'schemaVersion',2,0,'ONE',0),
          ('META',N'resultName',1,0,'',40),
          ('META',N'statusCode',1,0,'',40),
          ('META',N'nativeReadState',1,0,'',40),
          ('META',N'isPartial',3,0,'',0),
          ('META',N'sourceComplete',3,0,'',0),
          ('META',N'errorNumber',2,1,'INT',0),
          ('META',N'errorMessage',1,1,'',2048),
          ('META',N'measurementStartUtc',1,1,'UTC',0),
          ('META',N'measurementEndUtc',1,1,'UTC',0),
          ('META',N'nativeReadStartUtc',1,1,'UTC',0),
          ('META',N'nativeReadEndUtc',1,1,'UTC',0),
          ('META',N'selectedNativeRows',1,1,'DEC',0),
          ('META',N'framework',5,0,'',0),
          ('META',N'selection',5,0,'',0),
          ('META',N'engine',5,1,'',0),
          ('FW',N'databaseId',2,0,'ID',0),
          ('FW',N'databaseName',1,0,'',128),
          ('FW',N'databaseCreateDateNative',1,0,'NATIVE',0),
          ('DB',N'DatabaseId',2,0,'ID',0),
          ('DB',N'DatabaseName',1,0,'',128),
          ('DB',N'DatabaseCreateDateNative',1,0,'NATIVE',0),
          ('DB',N'MetadataStatusCode',1,0,'',40),
          ('ENGINE',N'serverName',1,0,'',128),
          ('ENGINE',N'sqlServerStartTimeLocal',1,0,'NATIVE',0),
          ('ENGINE',N'sqlServerStartTimeMsTicks',1,0,'DEC',0),
          ('SEL',N'requestedDatabaseNames',1,1,'',0),
          ('SEL',N'requestedDatabaseNamePattern',1,1,'',4000),
          ('SEL',N'systemDatabasesIncluded',3,0,'',0),
          ('SEL',N'selectedDatabaseCount',1,0,'DEC',0),
          ('SEL',N'selectionSha256',1,0,'SHA',0),
          ('FILE',N'DatabaseId',2,0,'ID',0),
          ('FILE',N'FileId',2,0,'ID',0),
          ('FILE',N'SampleMs',2,0,'DEC',0),
          ('FILE',N'Reads',2,0,'DEC',0),
          ('FILE',N'ReadBytes',2,0,'DEC',0),
          ('FILE',N'ReadStallMs',2,0,'DEC',0),
          ('FILE',N'Writes',2,0,'DEC',0),
          ('FILE',N'WriteBytes',2,0,'DEC',0),
          ('FILE',N'WriteStallMs',2,0,'DEC',0),
          ('FILE',N'SizeOnDiskBytes',2,0,'DEC',0),
          ('FILE',N'FileHandle',1,1,'HANDLE',0),
          ('FILE',N'MetadataBefore',5,1,'',0),
          ('FILE',N'MetadataAfter',5,1,'',0),
          ('MB',N'DatabaseId',2,0,'ID',0),
          ('MB',N'FileId',2,0,'ID',0),
          ('MB',N'FileGuid',1,1,'GUID',0),
          ('MB',N'CreateLsn',1,1,'LSN',0),
          ('MB',N'FileType',2,0,'TINY',0),
          ('MB',N'FileState',2,0,'TINY',0),
          ('MB',N'LogicalName',1,0,'',128),
          ('MA',N'DatabaseId',2,0,'ID',0),
          ('MA',N'FileId',2,0,'ID',0),
          ('MA',N'FileGuid',1,1,'GUID',0),
          ('MA',N'CreateLsn',1,1,'LSN',0),
          ('MA',N'FileType',2,0,'TINY',0),
          ('MA',N'FileState',2,0,'TINY',0),
          ('MA',N'LogicalName',1,0,'',128),
          ('ISSUE',N'ScopeType',1,0,'',16),
          ('ISSUE',N'SourceName',1,0,'',128),
          ('ISSUE',N'DatabaseName',1,1,'',128),
          ('ISSUE',N'StatusCode',1,0,'',40),
          ('ISSUE',N'ErrorMessage',1,1,'',2048),
          ('ISSUE',N'EvidenceLimit',1,1,'',1000),
          ('ISSUE',N'DatabaseId',2,1,'ID',0),
          ('ISSUE',N'FileId',2,1,'ID',0),
          ('ISSUE',N'ErrorNumber',2,1,'INT',0);
        IF COALESCE(ISJSON(@CollectorJson),0)<>1
            THROW 53782,N'Der Datei-I/O-Sourcevertrag ist kein JSON-Objekt.',1;
        INSERT @Objects([Kind],[Ordinal],[Json]) VALUES('ROOT',0,@CollectorJson);
        INSERT @Fields SELECT [o].[Id],[j].[key],[j].[value],[j].[type] FROM @Objects [o] CROSS APPLY OPENJSON([o].[Json]) [j];
        IF (SELECT COUNT_BIG(*) FROM @Fields)<>4 OR EXISTS
           (SELECT 1 FROM @Spec [s] WHERE [Kind]='ROOT' AND
             (SELECT COUNT_BIG(*) FROM @Fields [f] WHERE [f].[Name]=[s].[Name] AND DATALENGTH([f].[Name])=DATALENGTH([s].[Name]) AND [f].[Type]=[s].[Type])<>1)
            THROW 53782,N'Der Datei-I/O-Rootvertrag ist ungültig.',1;
        SELECT @Meta=[Value] FROM @Fields WHERE [Name]=N'meta';
        INSERT @Objects([Kind],[Ordinal],[Json]) VALUES('META',0,@Meta);
        IF EXISTS(SELECT 1 FROM @Fields [f] CROSS APPLY OPENJSON([f].[Value]) [j]
                  WHERE [f].[Name] IN(N'databases',N'files',N'issues') AND [j].[type]<>5)
            THROW 53782,N'Eine Sourcezeile ist kein Objekt.',1;
        INSERT @Objects([Kind],[Ordinal],[Json])
        SELECT CASE [f].[Name] WHEN N'databases' THEN 'DB' WHEN N'files' THEN 'FILE' ELSE 'ISSUE' END,
               CONVERT(int,[j].[key]),[j].[value] FROM @Fields [f] CROSS APPLY OPENJSON([f].[Value]) [j]
        WHERE [f].[Name] IN(N'databases',N'files',N'issues');
        INSERT @Fields SELECT [o].[Id],[j].[key],[j].[value],[j].[type] FROM @Objects [o] CROSS APPLY OPENJSON([o].[Json]) [j] WHERE [o].[Kind]<>'ROOT';
        INSERT @Objects([Kind],[Ordinal],[Json])
        SELECT CASE [f].[Name] WHEN N'framework' THEN 'FW' WHEN N'engine' THEN 'ENGINE' WHEN N'selection' THEN 'SEL'
                 WHEN N'MetadataBefore' THEN 'MB' ELSE 'MA' END,[o].[Ordinal],[f].[Value]
        FROM @Fields [f] JOIN @Objects [o] ON [o].[Id]=[f].[ObjectId]
        WHERE ([o].[Kind]='META' AND [f].[Name] IN(N'framework',N'engine',N'selection')
               OR [o].[Kind]='FILE' AND [f].[Name] IN(N'MetadataBefore',N'MetadataAfter')) AND [f].[Type]=5;
        INSERT @Fields SELECT [o].[Id],[j].[key],[j].[value],[j].[type] FROM @Objects [o] CROSS APPLY OPENJSON([o].[Json]) [j]
        WHERE [o].[Kind] IN('FW','ENGINE','SEL','MB','MA');
        IF EXISTS(SELECT 1 FROM @Objects [o] WHERE
             (SELECT COUNT_BIG(*) FROM @Fields WHERE [ObjectId]=[o].[Id])<>(SELECT COUNT_BIG(*) FROM @Spec WHERE [Kind]=[o].[Kind]))
           OR EXISTS(SELECT 1 FROM @Objects [o] JOIN @Spec [s] ON [s].[Kind]=[o].[Kind] WHERE
             (SELECT COUNT_BIG(*) FROM @Fields [f] WHERE [f].[ObjectId]=[o].[Id] AND [f].[Name]=[s].[Name]
                AND DATALENGTH([f].[Name])=DATALENGTH([s].[Name]) AND ([f].[Type]=[s].[Type] OR [s].[Nullable]=1 AND [f].[Type]=0))<>1)
            THROW 53782,N'Ein Sourceobjekt enthält fehlende, doppelte, unbekannte oder falsch typisierte Member.',1;
        IF EXISTS(SELECT 1 FROM @Fields [f] JOIN @Objects [o] ON [o].[Id]=[f].[ObjectId]
           JOIN @Spec [s] ON [s].[Kind]=[o].[Kind] AND [s].[Name]=[f].[Name] WHERE [f].[Type]<>0 AND
           (([s].[Limit]>0 AND DATALENGTH([f].[Value])>2*[s].[Limit])
            OR [s].[Format]='ONE' AND [f].[Value]<>N'1'
            OR [s].[Format] IN('DEC','ID','INT','TINY') AND
              (TRY_CONVERT(bigint,[f].[Value]) IS NULL
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[f].[Value])))
               OR [s].[Format]='DEC' AND TRY_CONVERT(bigint,[f].[Value])<0
               OR [s].[Format]='ID' AND (TRY_CONVERT(bigint,[f].[Value])<1 OR TRY_CONVERT(bigint,[f].[Value])>2147483647)
               OR [s].[Format]='INT' AND TRY_CONVERT(int,[f].[Value]) IS NULL
               OR [s].[Format]='TINY' AND TRY_CONVERT(tinyint,[f].[Value]) IS NULL)
            OR [s].[Format]='LSN' AND
              (TRY_CONVERT(decimal(25,0),[f].[Value]) IS NULL OR TRY_CONVERT(decimal(25,0),[f].[Value])<0
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(25),TRY_CONVERT(decimal(25,0),[f].[Value]))))
            OR [s].[Format]='GUID' AND
              (TRY_CONVERT(uniqueidentifier,[f].[Value]) IS NULL OR DATALENGTH([f].[Value])<>72
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),LOWER(CONVERT(nvarchar(36),TRY_CONVERT(uniqueidentifier,[f].[Value])))))
            OR [s].[Format] IN('SHA','HANDLE') AND
              (DATALENGTH([f].[Value])<>CASE WHEN [s].[Format]='SHA' THEN 128 ELSE 36 END
               OR [s].[Format]='HANDLE' AND LEFT([f].[Value],2) COLLATE Latin1_General_100_BIN2<>N'0x'
               OR SUBSTRING([f].[Value],CASE WHEN [s].[Format]='SHA' THEN 1 ELSE 3 END,64) COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%')
            OR [s].[Format]='UTC' AND
              (DATALENGTH([f].[Value])<>48 OR RIGHT([f].[Value],1) COLLATE Latin1_General_100_BIN2<>N'Z'
               OR TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126) IS NULL
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126))),3)+N'Z'))
            OR [s].[Format]='NATIVE' AND
              (DATALENGTH([f].[Value])<>46 OR TRY_CONVERT(datetime,[f].[Value],126) IS NULL
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime,[f].[Value],126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,TRY_CONVERT(datetime,[f].[Value],126))),3)))))
            THROW 53782,N'Ein Sourcewert verletzt sein kanonisches Format oder seinen nativen Wertebereich.',1;
        SELECT @Engine=[Json] FROM @Objects WHERE [Kind]='ENGINE';
        SELECT @Framework=[Json] FROM @Objects WHERE [Kind]='FW';
        SELECT @Selection=[Json] FROM @Objects WHERE [Kind]='SEL';
        SELECT @SourceStatus=JSON_VALUE(@Meta,'$.statusCode'),@Complete=CONVERT(bit,CASE JSON_VALUE(@Meta,'$.sourceComplete') WHEN 'true' THEN 1 ELSE 0 END),
               @Native=TRY_CONVERT(bigint,JSON_VALUE(@Meta,'$.selectedNativeRows')),
               @Start=TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@Meta,'$.measurementStartUtc'),23),126),
               @End=TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@Meta,'$.measurementEndUtc'),23),126),
               @ReadStart=TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@Meta,'$.nativeReadStartUtc'),23),126),
               @ReadEnd=TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@Meta,'$.nativeReadEndUtc'),23),126),
               @Fatal=CASE WHEN JSON_VALUE(@Meta,'$.statusCode') IN('DENIED_PERMISSION','UNAVAILABLE_OBJECT','ERROR_HANDLED') THEN 1 ELSE 0 END;
        IF JSON_VALUE(@Meta,'$.schemaVersion')<>'1' OR JSON_VALUE(@Meta,'$.resultName') COLLATE Latin1_General_100_BIN2<>N'SnapshotFileIO'
           OR @SourceStatus COLLATE Latin1_General_100_BIN2 NOT IN('AVAILABLE','EMPTY_UNPROVEN','PARTIAL','DENIED_PERMISSION','UNAVAILABLE_OBJECT','ERROR_HANDLED')
           OR JSON_VALUE(@Meta,'$.isPartial')<>CASE WHEN @SourceStatus='AVAILABLE' THEN 'false' ELSE 'true' END
           OR @Complete<>CASE WHEN @SourceStatus IN('AVAILABLE','EMPTY_UNPROVEN') THEN 1 ELSE 0 END
           OR (@Start IS NULL AND @End IS NOT NULL) OR (@Start IS NOT NULL AND @End IS NULL)
           OR (@ReadStart IS NULL AND @ReadEnd IS NOT NULL) OR (@ReadStart IS NOT NULL AND @ReadEnd IS NULL)
           OR @Start>@End OR @ReadStart>@ReadEnd
           OR @Fatal=0 AND (@ReadStart<@Start OR @ReadEnd>@End OR @Start<@Started)
           OR @Fatal=0 AND (@Engine IS NULL OR @Start IS NULL OR @End IS NULL)
           OR @Fatal=1 AND @Engine IS NOT NULL
           OR JSON_VALUE(@Meta,'$.nativeReadState') COLLATE Latin1_General_100_BIN2 NOT IN('NOT_STARTED','SUCCEEDED','FAILED')
           OR JSON_VALUE(@Meta,'$.nativeReadState')='SUCCEEDED' AND (@Native IS NULL OR @Fatal=0 AND @ReadStart IS NULL)
           OR JSON_VALUE(@Meta,'$.nativeReadState')<>'SUCCEEDED' AND (@ReadStart IS NOT NULL OR @ReadEnd IS NOT NULL)
           OR JSON_VALUE(@Meta,'$.nativeReadState')='FAILED' AND (@Native IS NOT NULL OR @Fatal=0)
           OR CONVERT(varbinary(max),JSON_VALUE(@Framework,'$.databaseName'))<>CONVERT(varbinary(max),@SourceName)
           OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
             WHERE [database_id]=TRY_CONVERT(int,JSON_VALUE(@Framework,'$.databaseId'))
               AND CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@SourceName)
               AND [create_date]=TRY_CONVERT(datetime,JSON_VALUE(@Framework,'$.databaseCreateDateNative'),126))
            THROW 53782,N'Der Sourcezustand, sein Zeitfenster oder seine Frameworkbindung ist widersprüchlich.',1;
        IF EXISTS(SELECT 1 FROM @Objects WHERE [Kind]='DB' GROUP BY TRY_CONVERT(int,JSON_VALUE([Json],'$.DatabaseId')) HAVING COUNT_BIG(*)<>1)
            THROW 53782,N'Die Sourceauswahl enthält doppelte Datenbankkennungen.',1;
        INSERT @Databases
        SELECT CONVERT(int,JSON_VALUE([Json],'$.DatabaseId')),JSON_VALUE([Json],'$.DatabaseName'),
               CONVERT(datetime,JSON_VALUE([Json],'$.DatabaseCreateDateNative'),126),JSON_VALUE([Json],'$.MetadataStatusCode')
        FROM @Objects WHERE [Kind]='DB';
        IF EXISTS(SELECT 1 FROM @Databases WHERE [Status] NOT IN('AVAILABLE','DENIED_PERMISSION','UNAVAILABLE_OBJECT','ERROR_HANDLED','TARGET_CHANGED'))
           OR EXISTS(SELECT 1 FROM @Databases GROUP BY CONVERT(varbinary(256),[Name]) HAVING COUNT_BIG(*)<>1)
           OR (SELECT COUNT_BIG(*) FROM @Databases)<>TRY_CONVERT(bigint,JSON_VALUE(@Selection,'$.selectedDatabaseCount'))
           OR JSON_VALUE(@Meta,'$.nativeReadState')='NOT_STARTED' AND
               ((NOT EXISTS(SELECT 1 FROM @Databases) AND COALESCE(@Native,-1)<>0)
                OR EXISTS(SELECT 1 FROM @Databases) AND (@Fatal=0 OR @Native IS NOT NULL))
            THROW 53782,N'Die tatsächliche Datenbankauswahl ist widersprüchlich.',1;
        DECLARE @CanonicalDatabases nvarchar(max)=(SELECT [Id] AS [DatabaseId],[Name] AS [DatabaseName],
            CONVERT(nvarchar(19),[Created],126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,[Created])),3) AS [DatabaseCreateDateNative]
            FROM @Databases ORDER BY [Id] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @CanonicalDatabases=COALESCE(@CanonicalDatabases,N'[]');
        SET @SelectionHash=LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CanonicalDatabases)),2));
        IF CONVERT(varbinary(max),@SelectionHash)<>CONVERT(varbinary(max),CONVERT(varchar(64),JSON_VALUE(@Selection,'$.selectionSha256')))
            THROW 53782,N'Der Auswahlhash bindet nicht die tatsächliche geordnete Datenbankmenge.',1;
        SELECT @Framework=(SELECT CONVERT(int,JSON_VALUE(@Framework,'$.databaseId')) AS [databaseId],
            JSON_VALUE(@Framework,'$.databaseName') AS [databaseName],JSON_VALUE(@Framework,'$.databaseCreateDateNative') AS [databaseCreateDateNative]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        SET @FrameworkHash=LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Framework)),2));
        IF @Engine IS NOT NULL
        BEGIN
            SELECT @Engine=(SELECT JSON_VALUE(@Engine,'$.serverName') AS [serverName],
                JSON_VALUE(@Engine,'$.sqlServerStartTimeLocal') AS [sqlServerStartTimeLocal],
                JSON_VALUE(@Engine,'$.sqlServerStartTimeMsTicks') AS [sqlServerStartTimeMsTicks]
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            SET @EngineHash=LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Engine)),2));
        END;
        INSERT @Issues
        SELECT [Ordinal],JSON_VALUE([Json],'$.ScopeType'),JSON_VALUE([Json],'$.SourceName'),
            TRY_CONVERT(int,JSON_VALUE([Json],'$.DatabaseId')),TRY_CONVERT(int,JSON_VALUE([Json],'$.FileId')),
            JSON_VALUE([Json],'$.DatabaseName'),JSON_VALUE([Json],'$.StatusCode'),TRY_CONVERT(int,JSON_VALUE([Json],'$.ErrorNumber')),
            JSON_VALUE([Json],'$.ErrorMessage'),JSON_VALUE([Json],'$.EvidenceLimit') FROM @Objects WHERE [Kind]='ISSUE';
        IF EXISTS(SELECT 1 FROM @Issues WHERE [ScopeType] NOT IN('SELECTION','DATABASE','FILE','SOURCE')
            OR [SourceName] NOT IN(N'DATABASE_SELECTION',N'sys.databases',N'sys.database_files',N'sys.dm_os_sys_info',N'sys.dm_io_virtual_file_stats',N'SOURCE_CONTRACT')
            OR [StatusCode] NOT IN('SELECTION_UNRESOLVED','DATABASE_CONTEXT_CHANGED','DENIED_PERMISSION','UNAVAILABLE_OBJECT','ERROR_HANDLED',
                'FILE_METADATA_UNAVAILABLE','NATIVE_FILE_UNAVAILABLE','FILE_STATE_CHANGED','FILE_TYPE_CHANGED','UNSUPPORTED_FILE_TYPE','FILE_NOT_ONLINE',
                'IDENTITY_OBSERVATION_CHANGED','IDENTITY_FIELD_UNKNOWN'))
            THROW 53782,N'Ein Issue enthält keinen geschlossenen Source- oder Statuscode.',1;
        SELECT TOP(1) @ErrorNumberOut=[ErrorNumber],@ErrorMessageOut=[ErrorMessage] FROM @Issues
        ORDER BY CASE WHEN [ErrorNumber] IS NULL THEN 1 ELSE 0 END,[Ordinal];
        IF EXISTS(SELECT TRY_CONVERT(int,JSON_VALUE(@Meta,'$.errorNumber')),CONVERT(varbinary(max),JSON_VALUE(@Meta,'$.errorMessage'))
          EXCEPT SELECT @ErrorNumberOut,CONVERT(varbinary(max),@ErrorMessageOut))
            THROW 53782,N'Die Sourcefehlerprojektion bindet nicht den ersten tatsächlichen Issuefehler.',1;
        INSERT @Files([Ordinal],[DatabaseId],[FileId],[SampleMs],[Reads],[ReadBytes],[ReadStallMs],[Writes],[WriteBytes],[WriteStallMs],[Size],[Handle],[Before],[After])
        SELECT [Ordinal],CONVERT(int,JSON_VALUE([Json],'$.DatabaseId')),CONVERT(int,JSON_VALUE([Json],'$.FileId')),
            CONVERT(bigint,JSON_VALUE([Json],'$.SampleMs')),CONVERT(bigint,JSON_VALUE([Json],'$.Reads')),CONVERT(bigint,JSON_VALUE([Json],'$.ReadBytes')),
            CONVERT(bigint,JSON_VALUE([Json],'$.ReadStallMs')),CONVERT(bigint,JSON_VALUE([Json],'$.Writes')),CONVERT(bigint,JSON_VALUE([Json],'$.WriteBytes')),
            CONVERT(bigint,JSON_VALUE([Json],'$.WriteStallMs')),CONVERT(bigint,JSON_VALUE([Json],'$.SizeOnDiskBytes')),JSON_VALUE([Json],'$.FileHandle'),
            JSON_QUERY([Json],'$.MetadataBefore'),JSON_QUERY([Json],'$.MetadataAfter') FROM @Objects WHERE [Kind]='FILE';
        IF EXISTS(SELECT 1 FROM @Files GROUP BY [DatabaseId],[FileId] HAVING COUNT_BIG(*)<>1)
           OR EXISTS(SELECT 1 FROM @Files [f] WHERE NOT EXISTS(SELECT 1 FROM @Databases [d] WHERE [d].[Id]=[f].[DatabaseId]))
           OR @Fatal=0 AND JSON_VALUE(@Meta,'$.nativeReadState')='SUCCEEDED' AND (SELECT COUNT_BIG(*) FROM @Files)<>@Native
           OR (JSON_VALUE(@Meta,'$.nativeReadState')<>'SUCCEEDED' OR @Fatal=1) AND EXISTS(SELECT 1 FROM @Files)
            THROW 53782,N'Die native Dateimenge verletzt ihre Auswahl- oder Mengenbindung.',1;
        UPDATE [f] SET [Partition]=CASE
          WHEN [d].[Status]<>'AVAILABLE' OR [Before] IS NULL OR [After] IS NULL
            OR TRY_CONVERT(int,JSON_VALUE([Before],'$.DatabaseId'))<>[DatabaseId] OR TRY_CONVERT(int,JSON_VALUE([After],'$.DatabaseId'))<>[DatabaseId]
            OR TRY_CONVERT(int,JSON_VALUE([Before],'$.FileId'))<>[FileId] OR TRY_CONVERT(int,JSON_VALUE([After],'$.FileId'))<>[FileId]
            OR JSON_VALUE([Before],'$.FileType')<>JSON_VALUE([After],'$.FileType')
            OR JSON_VALUE([Before],'$.FileState')<>JSON_VALUE([After],'$.FileState') THEN 'UNBOUND'
          WHEN JSON_VALUE([Before],'$.FileType') NOT IN('0','1') OR JSON_VALUE([Before],'$.FileState')<>'0' THEN 'EXCLUDED'
          ELSE 'ELIGIBLE' END
        FROM @Files [f] JOIN @Databases [d] ON [d].[Id]=[f].[DatabaseId];
        UPDATE @Files SET [Complete]=CASE WHEN [Partition]='ELIGIBLE' AND [Handle] IS NOT NULL
            AND JSON_VALUE([Before],'$.FileGuid') IS NOT NULL AND JSON_VALUE([After],'$.FileGuid')=JSON_VALUE([Before],'$.FileGuid')
            AND JSON_VALUE([Before],'$.CreateLsn') IS NOT NULL AND JSON_VALUE([After],'$.CreateLsn')=JSON_VALUE([Before],'$.CreateLsn') THEN 1 ELSE 0 END;
        SELECT @Eligible=COUNT_BIG(*) FROM @Files WHERE [Partition]='ELIGIBLE';
        SELECT @Excluded=COUNT_BIG(*) FROM @Files WHERE [Partition]='EXCLUDED';
        SELECT @Unbound=COUNT_BIG(*) FROM @Files WHERE [Partition]='UNBOUND';
        IF @Complete=1 AND (@Unbound<>0 OR EXISTS(SELECT 1 FROM @Databases WHERE [Status]<>'AVAILABLE')
           OR EXISTS(SELECT 1 FROM @Issues WHERE [StatusCode] NOT IN('UNSUPPORTED_FILE_TYPE','FILE_NOT_ONLINE','IDENTITY_OBSERVATION_CHANGED','IDENTITY_FIELD_UNKNOWN')))
           OR @SourceStatus='AVAILABLE' AND @Eligible=0 OR @SourceStatus='EMPTY_UNPROVEN' AND @Eligible<>0
            THROW 53782,N'Der behauptete vollständige Sourcezustand widerspricht den beobachteten Abdeckungsgrenzen.',1;
        UPDATE @Files SET [Selected]=1 WHERE [Ordinal] IN
          (SELECT TOP(@MaxRows) [Ordinal] FROM @Files WHERE [Partition]='ELIGIBLE' ORDER BY [DatabaseId],[FileId]);
        SELECT @Written=COUNT_BIG(*) FROM @Files WHERE [Selected]=1;
        SET @Limited=CASE WHEN @Written<@Eligible THEN 1 ELSE 0 END;
        SELECT @ValidatedIssuesJson=COALESCE((SELECT * FROM @Issues ORDER BY [Ordinal] FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]');
        SELECT @SourceValidated=1,@SourceErrorNumber=@ErrorNumberOut,@SourceErrorMessage=@ErrorMessageOut;
        SET @Now=SYSUTCDATETIME();
        IF @Fatal=1 AND (@Start<@Started OR @End>@Now)
            SELECT @Start=NULL,@End=NULL,@ReadStart=NULL,@ReadEnd=NULL;
        IF @Fatal=1 AND (@ReadStart<@Start OR @ReadEnd>@End OR @Start IS NULL)
            SELECT @ReadStart=NULL,@ReadEnd=NULL;
        IF @Started>@Now OR @Fatal=0 AND @End>@Now
            THROW 53784,N'Die tatsächliche Targetzeit bestätigt keine zeitliche Abschlussbindung.',1;
        IF @Fatal=1
        BEGIN
            SET @StatusCodeOut=@SourceStatus;
            GOTO PersistIssues;
        END;
        INSERT @Metrics([Code],[Type],[Unit]) VALUES
          ('IO_READ_COUNT','BIGINT','count'),
          ('IO_READ_BYTES','BIGINT','bytes'),
          ('IO_READ_STALL_MS','BIGINT','ms'),
          ('IO_WRITE_COUNT','BIGINT','count'),
          ('IO_WRITE_BYTES','BIGINT','bytes'),
          ('IO_WRITE_STALL_MS','BIGINT','ms'),
          ('IO_SIZE_ON_DISK_BYTES','BIGINT','bytes'),
          ('IO_READ_COUNT_DELTA_CANDIDATE','BIGINT','count'),
          ('IO_READ_BYTES_DELTA_CANDIDATE','BIGINT','bytes'),
          ('IO_READ_STALL_MS_DELTA_CANDIDATE','BIGINT','ms'),
          ('IO_WRITE_COUNT_DELTA_CANDIDATE','BIGINT','count'),
          ('IO_WRITE_BYTES_DELTA_CANDIDATE','BIGINT','bytes'),
          ('IO_WRITE_STALL_MS_DELTA_CANDIDATE','BIGINT','ms'),
          ('IO_DELTA_STATUS','STRING','status'),
          ('IO_FILE_CONTEXT','STRING','json'),
          ('IO_CAPTURE_CONTEXT','STRING','json');
        UPDATE [e] SET [Id]=[d].[MetricDefinitionId] FROM @Metrics [e] JOIN [snapshot].[MetricDefinition] [d]
          ON CONVERT(varbinary(max),[e].[Code])=CONVERT(varbinary(max),[d].[MetricCode])
          AND CONVERT(varbinary(max),[e].[Type])=CONVERT(varbinary(max),[d].[ValueType])
          AND CONVERT(varbinary(max),[e].[Unit])=CONVERT(varbinary(max),[d].[Unit]) AND [d].[ContractVersion]=1;
        IF EXISTS(SELECT 1 FROM @Metrics WHERE [Id] IS NULL) THROW 53781,N'Die tatsächlichen Datei-I/O-Metrikverträge fehlen.',1;
        SELECT @ServerIdentity=(SELECT 1 AS [scopeVersion],'FILE_IO' AS [collectorCode],JSON_QUERY(@Engine) AS [engine]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @ServerHash binary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@ServerIdentity));
        IF EXISTS(SELECT 1 FROM [snapshot].[Scope] WHERE [ScopeType]='SERVER' AND [ScopeKeyHash]=@ServerHash
          AND ([ParentScopeId] IS NOT NULL OR CONVERT(varbinary(max),[ScopeIdentityJson])<>CONVERT(varbinary(max),@ServerIdentity)))
            THROW 53784,N'Der vorhandene Serverscope widerspricht seiner tatsächlichen Identität.',1;
        SELECT @ServerScope=[ScopeId] FROM [snapshot].[Scope] WHERE [ScopeType]='SERVER' AND [ScopeKeyHash]=@ServerHash;
        IF @ServerScope IS NULL
        BEGIN
            INSERT [snapshot].[Scope]([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
            VALUES('SERVER',NULL,@ServerHash,@ServerIdentity,SYSUTCDATETIME());
            SET @ServerScope=CONVERT(bigint,SCOPE_IDENTITY());
        END;
        UPDATE [f] SET [Identity]=[x].[Identity],
          [WithoutHandle]=JSON_MODIFY([x].[Identity],'$.file.FileHandle',NULL)
        FROM @Files [f] JOIN @Databases [d] ON [d].[Id]=[f].[DatabaseId]
        CROSS APPLY(SELECT (SELECT 1 AS [scopeVersion],'FILE_IO' AS [collectorCode],JSON_QUERY(@Engine) AS [engine],
          JSON_QUERY((SELECT [d].[Id] AS [DatabaseId],[d].[Name] AS [DatabaseName],
            CONVERT(nvarchar(19),[d].[Created],126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,[d].[Created])),3) AS [DatabaseCreateDateNative]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [database],
          JSON_QUERY((SELECT [f].[FileId] AS [FileId],[f].[Handle] AS [FileHandle],
            JSON_QUERY((SELECT CONVERT(int,JSON_VALUE([f].[Before],'$.DatabaseId')) AS [DatabaseId],CONVERT(int,JSON_VALUE([f].[Before],'$.FileId')) AS [FileId],
              JSON_VALUE([f].[Before],'$.FileGuid') AS [FileGuid],JSON_VALUE([f].[Before],'$.CreateLsn') AS [CreateLsn],
              CONVERT(tinyint,JSON_VALUE([f].[Before],'$.FileType')) AS [FileType],CONVERT(tinyint,JSON_VALUE([f].[Before],'$.FileState')) AS [FileState]
              FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [MetadataBefore],
            JSON_QUERY((SELECT CONVERT(int,JSON_VALUE([f].[After],'$.DatabaseId')) AS [DatabaseId],CONVERT(int,JSON_VALUE([f].[After],'$.FileId')) AS [FileId],
              JSON_VALUE([f].[After],'$.FileGuid') AS [FileGuid],JSON_VALUE([f].[After],'$.CreateLsn') AS [CreateLsn],
              CONVERT(tinyint,JSON_VALUE([f].[After],'$.FileType')) AS [FileType],CONVERT(tinyint,JSON_VALUE([f].[After],'$.FileState')) AS [FileState]
              FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [MetadataAfter]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [file],
          CASE WHEN [f].[Complete]=1 THEN NULL ELSE CONVERT(varchar(20),@CaptureRunId) END AS [observationCaptureRunId],
          [f].[Complete] AS [identityComplete] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES) AS [Identity]) [x]
        WHERE [f].[Selected]=1;
        IF EXISTS(SELECT 1 FROM @Files [f] JOIN [snapshot].[Scope] [s]
          ON [s].[ScopeType]='FILE_IO_FILE' AND [s].[ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[f].[Identity]))
          WHERE [f].[Selected]=1 AND ([s].[ParentScopeId]<>@ServerScope OR [s].[ParentScopeId] IS NULL
            OR CONVERT(varbinary(max),[s].[ScopeIdentityJson])<>CONVERT(varbinary(max),[f].[Identity])))
            THROW 53784,N'Ein vorhandener Dateiscope widerspricht seiner tatsächlichen Identität.',1;
        INSERT [snapshot].[Scope]([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
        SELECT 'FILE_IO_FILE',@ServerScope,HASHBYTES('SHA2_256',CONVERT(varbinary(max),[f].[Identity])),[f].[Identity],SYSUTCDATETIME()
        FROM @Files [f] WHERE [Selected]=1 AND NOT EXISTS(SELECT 1 FROM [snapshot].[Scope] [s]
          WHERE [ScopeType]='FILE_IO_FILE' AND [ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[f].[Identity])));
        UPDATE [f] SET [ScopeId]=[s].[ScopeId] FROM @Files [f] JOIN [snapshot].[Scope] [s]
          ON [s].[ScopeType]='FILE_IO_FILE' AND [s].[ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[f].[Identity])) WHERE [Selected]=1;

        SELECT TOP(1) @Previous=[CaptureRunId],@PreviousStatus=[StatusCode],@PreviousEnded=[EndedAtUtc] FROM [snapshot].[CaptureRun]
          WHERE [CollectorCode]='FILE_IO' AND [CaptureRunId]<@CaptureRunId ORDER BY [CaptureRunId] DESC;
        DECLARE @PreviousFiles TABLE([ScopeId] bigint PRIMARY KEY,[Json] nvarchar(max),[Identity] nvarchar(max),[Hash] binary(32),
          [Epoch] uniqueidentifier,[DatabaseId] int,[FileId] int,[RawJson] nvarchar(max),[RawCount] bigint,
          [ContextValid] bit DEFAULT(0),[RawValid] bit DEFAULT(0));
        IF @Previous IS NOT NULL AND @PreviousEnded IS NOT NULL AND @PreviousStatus='PARTIAL'
        BEGIN
            SELECT @PreviousContext=[s].[StringValue] FROM [snapshot].[MetricSample] [s] JOIN @Metrics [m] ON [m].[Id]=[s].[MetricDefinitionId]
              WHERE [s].[CaptureRunId]=@Previous AND [m].[Code]='IO_CAPTURE_CONTEXT';
            SET @PreviousValid=CASE WHEN (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] [s] JOIN @Metrics [m]
              ON [m].[Id]=[s].[MetricDefinitionId] WHERE [s].[CaptureRunId]=@Previous AND [m].[Code]='IO_CAPTURE_CONTEXT')=1
              AND ISJSON(@PreviousContext)=1 THEN 1 ELSE 0 END;
            IF @PreviousValid=0 SET @PreviousContext=N'{}';
            DELETE @Fields; DELETE @Objects;
            INSERT @Spec VALUES
          ('PC',N'schemaVersion',2,0,'ONE',0),
          ('PC',N'collectorCode',1,0,'',7),
          ('PC',N'captureRunId',1,0,'DEC',0),
          ('PC',N'serverScopeId',1,0,'DEC',0),
          ('PC',N'contextEpochId',1,0,'GUID',0),
          ('PC',N'framework',5,0,'',0),
          ('PC',N'engine',5,0,'',0),
          ('PC',N'window',5,0,'',0),
          ('PC',N'selection',5,0,'',0),
          ('PC',N'capture',5,0,'',0),
          ('PC',N'samples',5,0,'',0),
          ('PC',N'previousCaptureRunId',1,1,'DEC',0),
          ('PC',N'fileRawContextManifestSha256',1,0,'SHA',0),
          ('PFW',N'databaseId',1,0,'DEC',0),
          ('PFW',N'databaseCreateDateNative',1,0,'NATIVE',0),
          ('PFW',N'tupleSha256',1,0,'SHA',0),
          ('PENG',N'sqlServerStartTimeLocal',1,0,'NATIVE',0),
          ('PENG',N'sqlServerStartTimeMsTicks',1,0,'DEC',0),
          ('PENG',N'tupleSha256',1,0,'SHA',0),
          ('PWIN',N'measurementStartUtc',1,1,'UTC',0),
          ('PWIN',N'measurementEndUtc',1,1,'UTC',0),
          ('PWIN',N'nativeReadStartUtc',1,1,'UTC',0),
          ('PWIN',N'nativeReadEndUtc',1,1,'UTC',0),
          ('PSEL',N'databaseCount',1,0,'DEC',0),
          ('PSEL',N'selectionSha256',1,0,'SHA',0),
          ('PSEL',N'scopeContractVersion',2,0,'ONE',0),
          ('PCAP',N'nativeReadState',1,0,'',16),
          ('PCAP',N'sourceComplete',3,0,'',0),
          ('PCAP',N'selectedNativeFileCount',1,0,'DEC',0),
          ('PCAP',N'eligibleFileCount',1,0,'DEC',0),
          ('PCAP',N'writtenFileCount',1,0,'DEC',0),
          ('PCAP',N'excludedFileCount',1,0,'DEC',0),
          ('PCAP',N'unboundFileCount',1,0,'DEC',0),
          ('PCAP',N'effectiveMaxRows',1,0,'DEC',0),
          ('PCAP',N'writeLimited',3,0,'',0),
          ('PSAMP',N'rawSampleCount',1,0,'DEC',0),
          ('PSAMP',N'candidateSampleCount',1,0,'DEC',0),
          ('PSAMP',N'fileContextSampleCount',1,0,'DEC',0),
          ('PSAMP',N'statusSampleCount',1,0,'DEC',0),
          ('FC',N'schemaVersion',2,0,'ONE',0),
          ('FC',N'collectorCode',1,0,'',7),
          ('FC',N'captureRunId',1,0,'DEC',0),
          ('FC',N'scopeId',1,0,'DEC',0),
          ('FC',N'sampleMs',1,0,'DEC',0),
          ('FC',N'rawSampleCount',1,0,'DEC',0),
          ('FC',N'scopeIdentitySha256',1,0,'SHA',0),
          ('FC',N'resetEpochId',1,0,'GUID',0),
          ('FC',N'logicalNameBefore',1,1,'',128),
          ('FC',N'logicalNameAfter',1,1,'',128),
          ('FC',N'measurementStartUtc',1,0,'UTC',0),
          ('FC',N'measurementEndUtc',1,0,'UTC',0),
          ('FC',N'sourceComplete',3,0,'',0),
          ('FC',N'rawProjectionSha256',1,0,'SHA',0),
          ('FC',N'previousCaptureRunId',1,1,'DEC',0),
          ('FC',N'previousContextVersion',2,1,'ONE',0),
          ('FC',N'comparisonStatus',1,0,'',40),
          ('FC',N'epochDecision',1,0,'',40);
            INSERT @Objects([Kind],[Ordinal],[Json]) VALUES('PC',0,@PreviousContext);
            INSERT @Objects([Kind],[Ordinal],[Json]) SELECT CASE [key] WHEN 'framework' THEN 'PFW' WHEN 'engine' THEN 'PENG'
              WHEN 'window' THEN 'PWIN' WHEN 'selection' THEN 'PSEL' WHEN 'capture' THEN 'PCAP' ELSE 'PSAMP' END,0,[value]
              FROM OPENJSON(@PreviousContext) WHERE [type]=5 AND [key] IN('framework','engine','window','selection','capture','samples');
            INSERT @PreviousFiles([ScopeId],[Json],[Identity],[Hash],[Epoch],[DatabaseId],[FileId])
            SELECT [s].[ScopeId],CASE WHEN ISJSON([s].[StringValue])=1 THEN [s].[StringValue] ELSE N'{}' END,
              CASE WHEN ISJSON([sc].[ScopeIdentityJson])=1 THEN [sc].[ScopeIdentityJson] ELSE N'{}' END,[sc].[ScopeKeyHash],
              [s].[ResetEpochId],TRY_CONVERT(int,JSON_VALUE(CASE WHEN ISJSON([sc].[ScopeIdentityJson])=1 THEN [sc].[ScopeIdentityJson] ELSE N'{}' END,'$.database.DatabaseId')),
              TRY_CONVERT(int,JSON_VALUE(CASE WHEN ISJSON([sc].[ScopeIdentityJson])=1 THEN [sc].[ScopeIdentityJson] ELSE N'{}' END,'$.file.FileId'))
            FROM [snapshot].[MetricSample] [s] JOIN @Metrics [m] ON [m].[Id]=[s].[MetricDefinitionId]
            JOIN [snapshot].[Scope] [sc] ON [sc].[ScopeId]=[s].[ScopeId]
            WHERE [s].[CaptureRunId]=@Previous AND [m].[Code]='IO_FILE_CONTEXT';
            INSERT @Objects([Kind],[Ordinal],[Json]) SELECT 'FC',0,[Json] FROM @PreviousFiles;
            INSERT @Fields SELECT [o].[Id],[j].[key],[j].[value],[j].[type] FROM @Objects [o] CROSS APPLY OPENJSON([o].[Json]) [j];
            IF EXISTS(SELECT 1 FROM @Objects [o] WHERE
              (SELECT COUNT_BIG(*) FROM @Fields WHERE [ObjectId]=[o].[Id])<>(SELECT COUNT_BIG(*) FROM @Spec WHERE [Kind]=[o].[Kind]))
              OR EXISTS(SELECT 1 FROM @Objects [o] JOIN @Spec [s] ON [s].[Kind]=[o].[Kind] WHERE
              (SELECT COUNT_BIG(*) FROM @Fields [f] WHERE [f].[ObjectId]=[o].[Id] AND [f].[Name]=[s].[Name]
               AND DATALENGTH([f].[Name])=DATALENGTH([s].[Name]) AND ([f].[Type]=[s].[Type] OR [s].[Nullable]=1 AND [f].[Type]=0))<>1)
                SET @PreviousValid=0;
            IF EXISTS(SELECT 1 FROM @Fields [f] JOIN @Objects [o] ON [o].[Id]=[f].[ObjectId]
           JOIN @Spec [s] ON [s].[Kind]=[o].[Kind] AND [s].[Name]=[f].[Name] WHERE [f].[Type]<>0 AND
           (([s].[Limit]>0 AND DATALENGTH([f].[Value])>2*[s].[Limit])
            OR [s].[Format]='ONE' AND [f].[Value]<>N'1'
            OR [s].[Format] IN('DEC','ID','INT','TINY') AND
              (TRY_CONVERT(bigint,[f].[Value]) IS NULL
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(20),TRY_CONVERT(bigint,[f].[Value])))
               OR [s].[Format]='DEC' AND TRY_CONVERT(bigint,[f].[Value])<0
               OR [s].[Format]='ID' AND (TRY_CONVERT(bigint,[f].[Value])<1 OR TRY_CONVERT(bigint,[f].[Value])>2147483647)
               OR [s].[Format]='INT' AND TRY_CONVERT(int,[f].[Value]) IS NULL
               OR [s].[Format]='TINY' AND TRY_CONVERT(tinyint,[f].[Value]) IS NULL)
            OR [s].[Format]='LSN' AND
              (TRY_CONVERT(decimal(25,0),[f].[Value]) IS NULL OR TRY_CONVERT(decimal(25,0),[f].[Value])<0
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(25),TRY_CONVERT(decimal(25,0),[f].[Value]))))
            OR [s].[Format]='GUID' AND
              (TRY_CONVERT(uniqueidentifier,[f].[Value]) IS NULL OR DATALENGTH([f].[Value])<>72
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),LOWER(CONVERT(nvarchar(36),TRY_CONVERT(uniqueidentifier,[f].[Value])))))
            OR [s].[Format] IN('SHA','HANDLE') AND
              (DATALENGTH([f].[Value])<>CASE WHEN [s].[Format]='SHA' THEN 128 ELSE 36 END
               OR [s].[Format]='HANDLE' AND LEFT([f].[Value],2) COLLATE Latin1_General_100_BIN2<>N'0x'
               OR SUBSTRING([f].[Value],CASE WHEN [s].[Format]='SHA' THEN 1 ELSE 3 END,64) COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%')
            OR [s].[Format]='UTC' AND
              (DATALENGTH([f].[Value])<>48 OR RIGHT([f].[Value],1) COLLATE Latin1_General_100_BIN2<>N'Z'
               OR TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126) IS NULL
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,TRY_CONVERT(datetime2(3),LEFT([f].[Value],23),126))),3)+N'Z'))
            OR [s].[Format]='NATIVE' AND
              (DATALENGTH([f].[Value])<>46 OR TRY_CONVERT(datetime,[f].[Value],126) IS NULL
               OR CONVERT(varbinary(max),[f].[Value])<>CONVERT(varbinary(max),CONVERT(nvarchar(19),TRY_CONVERT(datetime,[f].[Value],126),126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,TRY_CONVERT(datetime,[f].[Value],126))),3)))))
            SET @PreviousValid=0;
            DECLARE @PN bigint=(SELECT COUNT_BIG(*) FROM @PreviousFiles),@PManifest nvarchar(max),@PManifestHash varchar(64),@PCandidates bigint,
              @PServer bigint=TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.serverScopeId')),
              @PServerJson nvarchar(max),@PEngine nvarchar(max),@PFramework nvarchar(max),@PSourceName sysname;
            SELECT @PServerJson=CASE WHEN ISJSON([ScopeIdentityJson])=1 THEN [ScopeIdentityJson] ELSE N'{}' END
              FROM [snapshot].[Scope] WHERE [ScopeId]=@PServer AND [ScopeType]='SERVER' AND [ParentScopeId] IS NULL
              AND [ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[ScopeIdentityJson]));
            SET @PEngine=JSON_QUERY(COALESCE(@PServerJson,N'{}'),'$.engine');
            SELECT @PSourceName=[SourceDatabaseName] FROM [snapshot].[CaptureRun] WHERE [CaptureRunId]=@Previous;
            SELECT @PFramework=(SELECT TRY_CONVERT(int,JSON_VALUE(@PreviousContext,'$.framework.databaseId')) AS [databaseId],
              @PSourceName AS [databaseName],JSON_VALUE(@PreviousContext,'$.framework.databaseCreateDateNative') AS [databaseCreateDateNative]
              FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            SELECT @PCandidates=COUNT_BIG(*) FROM [snapshot].[MetricSample] [s] JOIN @Metrics [m] ON [m].[Id]=[s].[MetricDefinitionId]
              WHERE [s].[CaptureRunId]=@Previous AND [m].[Code] LIKE 'IO[_]%[_]DELTA[_]CANDIDATE';
            SELECT @PManifest=(SELECT CONVERT(varchar(20),[ScopeId]) AS [ScopeId],LOWER(CONVERT(varchar(36),[Epoch])) AS [ResetEpochId],
              JSON_VALUE([Json],'$.rawProjectionSha256') AS [RawProjectionSha256],
              LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),[Json])),2)) AS [FileContextSha256]
              FROM @PreviousFiles ORDER BY [ScopeId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @PManifest=COALESCE(@PManifest,N'[]');
            SET @PManifestHash=LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PManifest)),2));
            IF JSON_VALUE(@PreviousContext,'$.collectorCode') COLLATE Latin1_General_100_BIN2<>'FILE_IO'
              OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.captureRunId')),-1)<>@Previous
              OR JSON_VALUE(@PreviousContext,'$.fileRawContextManifestSha256') COLLATE Latin1_General_100_BIN2<>@PManifestHash
              OR @PServerJson IS NULL OR @PEngine IS NULL OR JSON_VALUE(@PServerJson,'$.collectorCode') COLLATE Latin1_General_100_BIN2<>'FILE_IO'
              OR JSON_VALUE(@PreviousContext,'$.engine.tupleSha256') COLLATE Latin1_General_100_BIN2<>
                LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PEngine)),2))
              OR JSON_VALUE(@PreviousContext,'$.framework.tupleSha256') COLLATE Latin1_General_100_BIN2<>
                LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PFramework)),2))
              OR CONVERT(varbinary(max),JSON_VALUE(@PreviousContext,'$.engine.sqlServerStartTimeLocal'))<>CONVERT(varbinary(max),JSON_VALUE(@PEngine,'$.sqlServerStartTimeLocal'))
              OR JSON_VALUE(@PreviousContext,'$.engine.sqlServerStartTimeMsTicks')<>JSON_VALUE(@PEngine,'$.sqlServerStartTimeMsTicks')
              OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.capture.writtenFileCount')),-1)<>@PN
              OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.samples.rawSampleCount')),-1)<>7*@PN
              OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.samples.fileContextSampleCount')),-1)<>@PN
              OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.samples.statusSampleCount')),-1)<>@PN
              OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.samples.candidateSampleCount')),-1)<>@PCandidates OR @PCandidates%6<>0 OR @PCandidates>6*@PN
              OR JSON_VALUE(@PreviousContext,'$.capture.nativeReadState') NOT IN('NOT_STARTED','SUCCEEDED')
              OR COALESCE(TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.capture.effectiveMaxRows')),0) NOT BETWEEN 1 AND 100000
              OR COALESCE(TRY_CONVERT(decimal(38,0),JSON_VALUE(@PreviousContext,'$.capture.selectedNativeFileCount')),-1)<>
                 COALESCE(TRY_CONVERT(decimal(38,0),JSON_VALUE(@PreviousContext,'$.capture.eligibleFileCount')),-1)
                 +COALESCE(TRY_CONVERT(decimal(38,0),JSON_VALUE(@PreviousContext,'$.capture.excludedFileCount')),-1)
                 +COALESCE(TRY_CONVERT(decimal(38,0),JSON_VALUE(@PreviousContext,'$.capture.unboundFileCount')),-1)
              OR @PN<>CASE WHEN TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.capture.eligibleFileCount'))<TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.capture.effectiveMaxRows'))
                THEN TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.capture.eligibleFileCount')) ELSE TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.capture.effectiveMaxRows')) END
              OR JSON_VALUE(@PreviousContext,'$.capture.writeLimited')<>CASE WHEN @PN<TRY_CONVERT(bigint,JSON_VALUE(@PreviousContext,'$.capture.eligibleFileCount')) THEN 'true' ELSE 'false' END
              OR JSON_VALUE(@PreviousContext,'$.capture.nativeReadState')='NOT_STARTED' AND
                (JSON_VALUE(@PreviousContext,'$.selection.databaseCount')<>'0' OR JSON_VALUE(@PreviousContext,'$.capture.selectedNativeFileCount')<>'0')
              OR JSON_VALUE(@PreviousContext,'$.window.measurementStartUtc') IS NULL OR JSON_VALUE(@PreviousContext,'$.window.measurementEndUtc') IS NULL
              OR JSON_VALUE(@PreviousContext,'$.capture.nativeReadState')='SUCCEEDED' AND
                (JSON_VALUE(@PreviousContext,'$.window.nativeReadStartUtc') IS NULL OR JSON_VALUE(@PreviousContext,'$.window.nativeReadEndUtc') IS NULL)
              OR JSON_VALUE(@PreviousContext,'$.capture.nativeReadState')='NOT_STARTED' AND
                (JSON_VALUE(@PreviousContext,'$.window.nativeReadStartUtc') IS NOT NULL OR JSON_VALUE(@PreviousContext,'$.window.nativeReadEndUtc') IS NOT NULL)
              OR TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.measurementStartUtc'),23),126)>
                 TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.measurementEndUtc'),23),126)
              OR TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.nativeReadStartUtc'),23),126)<
                 TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.measurementStartUtc'),23),126)
              OR TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.nativeReadEndUtc'),23),126)>
                 TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.measurementEndUtc'),23),126)
              OR TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.nativeReadStartUtc'),23),126)>
                 TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.nativeReadEndUtc'),23),126)
              OR (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@Previous)<>9*@PN+@PCandidates+1
              OR EXISTS(SELECT 1 FROM [snapshot].[CaptureRun] WHERE [CaptureRunId]=@Previous AND
                ([ResetEpochId] IS NOT NULL OR [SqlServerStartTimeUtc] IS NOT NULL OR [IsPartial]<>1 OR [MetricSampleCount]<>9*@PN+@PCandidates+1))
              OR EXISTS(SELECT 1 FROM [snapshot].[MetricSample] [s] JOIN @Metrics [m] ON [m].[Id]=[s].[MetricDefinitionId]
                WHERE [s].[CaptureRunId]=@Previous AND [m].[Code]='IO_CAPTURE_CONTEXT' AND
                ([s].[ScopeId]<>@PServer OR [s].[ResetEpochId]<>TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PreviousContext,'$.contextEpochId'))
                 OR [s].[QualityCode]<>'CAPTURE_CONTEXT' OR [s].[IsPartial]<>1 OR [s].[NumericValue] IS NOT NULL OR [s].[BigintValue] IS NOT NULL
                 OR [s].[CollectedAtUtc]<>COALESCE(TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.nativeReadEndUtc'),23),126),
                   TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.measurementEndUtc'),23),126))))
                SET @PreviousValid=0;
            UPDATE [p] SET [ContextValid]=CASE WHEN
              JSON_VALUE([p].[Json],'$.collectorCode') COLLATE Latin1_General_100_BIN2='FILE_IO'
              AND TRY_CONVERT(bigint,JSON_VALUE([p].[Json],'$.captureRunId'))=@Previous
              AND TRY_CONVERT(bigint,JSON_VALUE([p].[Json],'$.scopeId'))=[p].[ScopeId]
              AND TRY_CONVERT(uniqueidentifier,JSON_VALUE([p].[Json],'$.resetEpochId'))=[p].[Epoch]
              AND JSON_VALUE([p].[Json],'$.scopeIdentitySha256') COLLATE Latin1_General_100_BIN2=LOWER(CONVERT(varchar(64),[p].[Hash],2))
              AND [p].[Hash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[p].[Identity]))
              AND [p].[DatabaseId]>0 AND [p].[FileId]>0 AND JSON_VALUE([p].[Identity],'$.identityComplete')='true'
              AND JSON_VALUE([p].[Identity],'$.collectorCode') COLLATE Latin1_General_100_BIN2='FILE_IO'
              AND JSON_QUERY([p].[Identity],'$.engine') COLLATE Latin1_General_100_BIN2=@PEngine COLLATE Latin1_General_100_BIN2
              AND JSON_VALUE([p].[Json],'$.rawSampleCount')='7'
              AND JSON_VALUE([p].[Json],'$.measurementStartUtc')=JSON_VALUE(@PreviousContext,'$.window.measurementStartUtc')
              AND JSON_VALUE([p].[Json],'$.measurementEndUtc')=JSON_VALUE(@PreviousContext,'$.window.measurementEndUtc')
              AND JSON_VALUE([p].[Json],'$.sourceComplete')=JSON_VALUE(@PreviousContext,'$.capture.sourceComplete')
              AND EXISTS(SELECT 1 FROM [snapshot].[Scope] [sc] WHERE [sc].[ScopeId]=[p].[ScopeId]
                AND [sc].[ScopeType]='FILE_IO_FILE' AND [sc].[ParentScopeId]=@PServer)
              AND NOT EXISTS(SELECT 1 FROM [snapshot].[MetricSample] [ss] WHERE [ss].[CaptureRunId]=@Previous
                AND [ss].[ScopeId]=[p].[ScopeId] AND [ss].[ResetEpochId]<>[p].[Epoch])
              AND EXISTS(SELECT 1 FROM [snapshot].[MetricSample] [ss] JOIN @Metrics [m] ON [m].[Id]=[ss].[MetricDefinitionId]
                WHERE [ss].[CaptureRunId]=@Previous AND [ss].[ScopeId]=[p].[ScopeId] AND [m].[Code]='IO_DELTA_STATUS'
                  AND CONVERT(varbinary(max),[ss].[StringValue])=CONVERT(varbinary(max),JSON_VALUE([p].[Json],'$.comparisonStatus'))
                  AND [ss].[BigintValue] IS NULL AND [ss].[NumericValue] IS NULL AND [ss].[QualityCode]='COMPARISON_STATUS' AND [ss].[IsPartial]=1
                  AND [ss].[CollectedAtUtc]=TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.nativeReadEndUtc'),23),126))
              AND EXISTS(SELECT 1 FROM [snapshot].[MetricSample] [ss] JOIN @Metrics [m] ON [m].[Id]=[ss].[MetricDefinitionId]
                WHERE [ss].[CaptureRunId]=@Previous AND [ss].[ScopeId]=[p].[ScopeId] AND [m].[Code]='IO_FILE_CONTEXT'
                  AND [ss].[BigintValue] IS NULL AND [ss].[NumericValue] IS NULL AND [ss].[QualityCode]='FILE_IO_CONTEXT' AND [ss].[IsPartial]=1
                  AND [ss].[CollectedAtUtc]=TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.nativeReadEndUtc'),23),126))
              THEN 1 ELSE 0 END FROM @PreviousFiles [p];
            UPDATE [p] SET [RawJson]=[x].[RawJson],[RawCount]=[x].[RawCount] FROM @PreviousFiles [p]
            CROSS APPLY(SELECT (SELECT [m].[Code] AS [MetricCode],CONVERT(varchar(20),[ss].[MetricDefinitionId]) AS [MetricDefinitionId],
                CONVERT(varchar(20),[ss].[ScopeId]) AS [ScopeId],LOWER(CONVERT(varchar(36),[ss].[ResetEpochId])) AS [ResetEpochId],
                CONVERT(varchar(20),[ss].[BigintValue]) AS [BigintValue]
                FROM [snapshot].[MetricSample] [ss] JOIN @Metrics [m] ON [m].[Id]=[ss].[MetricDefinitionId]
                WHERE [ss].[CaptureRunId]=@Previous AND [ss].[ScopeId]=[p].[ScopeId] AND [m].[Code] IN
                  ('IO_READ_COUNT','IO_READ_BYTES','IO_READ_STALL_MS','IO_WRITE_COUNT','IO_WRITE_BYTES','IO_WRITE_STALL_MS','IO_SIZE_ON_DISK_BYTES')
                ORDER BY [m].[Code] COLLATE Latin1_General_100_BIN2 FOR JSON PATH,INCLUDE_NULL_VALUES) AS [RawJson],
              (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] [ss] JOIN @Metrics [m] ON [m].[Id]=[ss].[MetricDefinitionId]
                WHERE [ss].[CaptureRunId]=@Previous AND [ss].[ScopeId]=[p].[ScopeId] AND [m].[Code] IN
                  ('IO_READ_COUNT','IO_READ_BYTES','IO_READ_STALL_MS','IO_WRITE_COUNT','IO_WRITE_BYTES','IO_WRITE_STALL_MS','IO_SIZE_ON_DISK_BYTES')) AS [RawCount]) [x];
            UPDATE [p] SET [RawValid]=CASE WHEN [RawCount]=7
              AND JSON_VALUE([p].[Json],'$.rawProjectionSha256') COLLATE Latin1_General_100_BIN2=
                LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),[p].[RawJson])),2))
              AND NOT EXISTS(SELECT 1 FROM [snapshot].[MetricSample] [ss] JOIN @Metrics [m] ON [m].[Id]=[ss].[MetricDefinitionId]
                WHERE [ss].[CaptureRunId]=@Previous AND [ss].[ScopeId]=[p].[ScopeId] AND [m].[Code] IN
                  ('IO_READ_COUNT','IO_READ_BYTES','IO_READ_STALL_MS','IO_WRITE_COUNT','IO_WRITE_BYTES','IO_WRITE_STALL_MS','IO_SIZE_ON_DISK_BYTES')
                AND ([ss].[BigintValue] IS NULL OR [ss].[BigintValue]<0 OR [ss].[NumericValue] IS NOT NULL OR [ss].[StringValue] IS NOT NULL
                  OR [ss].[QualityCode]<>CASE WHEN [m].[Code]='IO_SIZE_ON_DISK_BYTES' THEN 'NATIVE_GAUGE' ELSE 'NATIVE_CUMULATIVE' END
                  OR [ss].[IsPartial]<>0 OR [ss].[ResetEpochId]<>[p].[Epoch]
                  OR [ss].[CollectedAtUtc]<>TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PreviousContext,'$.window.nativeReadEndUtc'),23),126)))
              THEN 1 ELSE 0 END FROM @PreviousFiles [p];
        END;
        DECLARE @Ordinal int,@DB int,@File int,@Identity nvarchar(max),@Handle varchar(18),@IdentityComplete bit,
          @PJson nvarchar(max),@PIdentity nvarchar(max),@PEpoch uniqueidentifier,@PContextValid bit,@PRawValid bit,@Matches bigint,
          @Comparison varchar(40),@Decision varchar(40),@PVersion int,@Epoch uniqueidentifier,@SampleMs bigint,
          @PR bigint,@PRB bigint,@PRS bigint,@PW bigint,@PWB bigint,@PWS bigint;
        DECLARE [FileComparisons] CURSOR LOCAL FAST_FORWARD FOR
          SELECT [Ordinal],[DatabaseId],[FileId],[Identity],[Handle],[Complete],[SampleMs] FROM @Files WHERE [Selected]=1 ORDER BY [DatabaseId],[FileId];
        OPEN [FileComparisons];
        FETCH NEXT FROM [FileComparisons] INTO @Ordinal,@DB,@File,@Identity,@Handle,@IdentityComplete,@SampleMs;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT @PJson=NULL,@PIdentity=NULL,@PEpoch=NULL,@PContextValid=0,@PRawValid=0,@PVersion=NULL,
                   @PR=NULL,@PRB=NULL,@PRS=NULL,@PW=NULL,@PWB=NULL,@PWS=NULL;
            SELECT @Matches=COUNT_BIG(*) FROM @PreviousFiles WHERE [DatabaseId]=@DB AND [FileId]=@File;
            IF @Matches=1
            BEGIN
                SELECT @PJson=[Json],@PIdentity=[Identity],@PEpoch=[Epoch],@PContextValid=[ContextValid],@PRawValid=[RawValid]
                FROM @PreviousFiles WHERE [DatabaseId]=@DB AND [FileId]=@File;
                SELECT @PR=MAX(CASE WHEN [m].[Code]='IO_READ_COUNT' THEN [ss].[BigintValue] END),
                  @PRB=MAX(CASE WHEN [m].[Code]='IO_READ_BYTES' THEN [ss].[BigintValue] END),
                  @PRS=MAX(CASE WHEN [m].[Code]='IO_READ_STALL_MS' THEN [ss].[BigintValue] END),
                  @PW=MAX(CASE WHEN [m].[Code]='IO_WRITE_COUNT' THEN [ss].[BigintValue] END),
                  @PWB=MAX(CASE WHEN [m].[Code]='IO_WRITE_BYTES' THEN [ss].[BigintValue] END),
                  @PWS=MAX(CASE WHEN [m].[Code]='IO_WRITE_STALL_MS' THEN [ss].[BigintValue] END)
                FROM [snapshot].[MetricSample] [ss] JOIN @Metrics [m] ON [m].[Id]=[ss].[MetricDefinitionId]
                WHERE [ss].[CaptureRunId]=@Previous AND [ss].[ScopeId]=TRY_CONVERT(bigint,JSON_VALUE(@PJson,'$.scopeId'));
                IF @PContextValid=1 AND @PRawValid=1 SET @PVersion=1;
            END;
            SET @Comparison=CASE WHEN @Complete=0 THEN 'SOURCE_PARTIAL'
              WHEN @IdentityComplete=0 THEN 'CURRENT_IDENTITY_INCOMPLETE'
              WHEN @Previous IS NULL THEN 'NO_PREVIOUS_CAPTURE'
              WHEN @PreviousEnded IS NULL THEN 'PREVIOUS_CAPTURE_UNCONFIRMED'
              WHEN @PreviousStatus<>'PARTIAL' THEN 'PREVIOUS_CAPTURE_FAILED'
              WHEN @PreviousValid=0 THEN 'PREVIOUS_CAPTURE_CONTEXT_INVALID'
              WHEN JSON_VALUE(@PreviousContext,'$.capture.sourceComplete')<>'true' THEN 'PREVIOUS_SOURCE_PARTIAL'
              WHEN JSON_VALUE(@PreviousContext,'$.selection.selectionSha256') COLLATE Latin1_General_100_BIN2<>@SelectionHash THEN 'SELECTION_CHANGED'
              WHEN @Matches=0 THEN 'PREVIOUS_FILE_UNAVAILABLE'
              WHEN @Matches<>1 OR @PContextValid<>1 THEN 'PREVIOUS_FILE_CONTEXT_INVALID'
              WHEN @PRawValid<>1 THEN 'PREVIOUS_RAW_INCOMPLETE'
              WHEN JSON_VALUE(@PreviousContext,'$.framework.tupleSha256') COLLATE Latin1_General_100_BIN2<>@FrameworkHash
                OR CONVERT(varbinary(max),JSON_MODIFY(@Identity,'$.file.FileHandle',NULL))<>
                   CONVERT(varbinary(max),JSON_MODIFY(@PIdentity,'$.file.FileHandle',NULL)) THEN 'OBSERVED_IDENTITY_CHANGED'
              WHEN CONVERT(varbinary(max),CONVERT(nvarchar(18),@Handle))<>CONVERT(varbinary(max),JSON_VALUE(@PIdentity,'$.file.FileHandle')) THEN 'FILE_HANDLE_CHANGED'
              WHEN @SampleMs<TRY_CONVERT(bigint,JSON_VALUE(@PJson,'$.sampleMs')) THEN 'UPTIME_DECREASED'
              WHEN @Start<=TRY_CONVERT(datetime2(3),LEFT(JSON_VALUE(@PJson,'$.measurementEndUtc'),23),126) THEN 'NONPOSITIVE_INTERVAL'
              WHEN EXISTS(SELECT 1 FROM @Files WHERE [Ordinal]=@Ordinal AND
                ([Reads]<@PR OR [ReadBytes]<@PRB OR [ReadStallMs]<@PRS OR [Writes]<@PW OR [WriteBytes]<@PWB OR [WriteStallMs]<@PWS)) THEN 'COUNTER_DECREASED'
              ELSE 'MONOTONIC_CONTINUITY_UNPROVEN' END;
            SET @Decision=CASE WHEN @IdentityComplete=0 THEN 'NEW_UNBOUND_OBSERVATION'
              WHEN @Comparison='MONOTONIC_CONTINUITY_UNPROVEN' THEN 'RETAIN_OBSERVED_EPOCH'
              WHEN @Previous IS NULL AND @Complete=1 THEN 'NEW_BASELINE' ELSE 'NEW_COMPARISON_BREAK' END;
            SET @Epoch=CASE WHEN @Decision='RETAIN_OBSERVED_EPOCH' THEN @PEpoch ELSE NEWID() END;
            IF @Epoch IS NULL THROW 53784,N'Die Dateiepoche konnte nicht gebunden werden.',1;
            UPDATE @Files SET [Epoch]=@Epoch,[Comparison]=@Comparison,[Decision]=@Decision,[PreviousVersion]=@PVersion,
              [PreviousReads]=@PR,[PreviousReadBytes]=@PRB,[PreviousReadStallMs]=@PRS,[PreviousWrites]=@PW,[PreviousWriteBytes]=@PWB,[PreviousWriteStallMs]=@PWS
              WHERE [Ordinal]=@Ordinal;
            FETCH NEXT FROM [FileComparisons] INTO @Ordinal,@DB,@File,@Identity,@Handle,@IdentityComplete,@SampleMs;
        END;
        CLOSE [FileComparisons]; DEALLOCATE [FileComparisons];
        SELECT @Comparable=COUNT_BIG(*) FROM @Files WHERE [Selected]=1 AND [Comparison]='MONOTONIC_CONTINUITY_UNPROVEN';
        INSERT [snapshot].[MetricSample]
          ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[BigintValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[f].[ScopeId],[m].[Id],@ReadEnd,[f].[Epoch],[v].[Value],
          CASE WHEN [v].[Code]='IO_SIZE_ON_DISK_BYTES' THEN 'NATIVE_GAUGE' ELSE 'NATIVE_CUMULATIVE' END,
          CONVERT(bit,CASE WHEN [f].[Complete]=1 THEN 0 ELSE 1 END)
        FROM @Files [f] CROSS APPLY(VALUES('IO_READ_COUNT',[Reads]),('IO_READ_BYTES',[ReadBytes]),('IO_READ_STALL_MS',[ReadStallMs]),
          ('IO_WRITE_COUNT',[Writes]),('IO_WRITE_BYTES',[WriteBytes]),('IO_WRITE_STALL_MS',[WriteStallMs]),('IO_SIZE_ON_DISK_BYTES',[Size])) [v]([Code],[Value])
        JOIN @Metrics [m] ON [m].[Code]=[v].[Code] WHERE [f].[Selected]=1;
        INSERT [snapshot].[MetricSample]
          ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[BigintValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[f].[ScopeId],[m].[Id],@ReadEnd,[f].[Epoch],[v].[Value],'MONOTONIC_CONTINUITY_UNPROVEN',1
        FROM @Files [f] CROSS APPLY(VALUES('IO_READ_COUNT_DELTA_CANDIDATE',[Reads]-[PreviousReads]),
          ('IO_READ_BYTES_DELTA_CANDIDATE',[ReadBytes]-[PreviousReadBytes]),('IO_READ_STALL_MS_DELTA_CANDIDATE',[ReadStallMs]-[PreviousReadStallMs]),
          ('IO_WRITE_COUNT_DELTA_CANDIDATE',[Writes]-[PreviousWrites]),('IO_WRITE_BYTES_DELTA_CANDIDATE',[WriteBytes]-[PreviousWriteBytes]),
          ('IO_WRITE_STALL_MS_DELTA_CANDIDATE',[WriteStallMs]-[PreviousWriteStallMs])) [v]([Code],[Value])
        JOIN @Metrics [m] ON [m].[Code]=[v].[Code] WHERE [f].[Selected]=1 AND [f].[Comparison]='MONOTONIC_CONTINUITY_UNPROVEN';
        INSERT [snapshot].[MetricSample]
          ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[StringValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[f].[ScopeId],[m].[Id],@ReadEnd,[f].[Epoch],[f].[Comparison],'COMPARISON_STATUS',1
        FROM @Files [f] JOIN @Metrics [m] ON [m].[Code]='IO_DELTA_STATUS' WHERE [f].[Selected]=1;
        IF EXISTS(SELECT 1 FROM @Files [f] WHERE [f].[Selected]=1 AND
          (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] [ss] JOIN @Metrics [m] ON [m].[Id]=[ss].[MetricDefinitionId]
           JOIN (VALUES('IO_READ_COUNT',[f].[Reads]),('IO_READ_BYTES',[f].[ReadBytes]),('IO_READ_STALL_MS',[f].[ReadStallMs]),
             ('IO_WRITE_COUNT',[f].[Writes]),('IO_WRITE_BYTES',[f].[WriteBytes]),('IO_WRITE_STALL_MS',[f].[WriteStallMs]),('IO_SIZE_ON_DISK_BYTES',[f].[Size])) [v]([Code],[Value])
             ON [v].[Code]=[m].[Code]
           WHERE [ss].[CaptureRunId]=@CaptureRunId AND [ss].[ScopeId]=[f].[ScopeId] AND [ss].[ResetEpochId]=[f].[Epoch]
             AND [ss].[BigintValue]=[v].[Value] AND [ss].[NumericValue] IS NULL AND [ss].[StringValue] IS NULL AND [ss].[CollectedAtUtc]=@ReadEnd
             AND [ss].[QualityCode]=CASE WHEN [m].[Code]='IO_SIZE_ON_DISK_BYTES' THEN 'NATIVE_GAUGE' ELSE 'NATIVE_CUMULATIVE' END
             AND [ss].[IsPartial]=CASE WHEN [f].[Complete]=1 THEN 0 ELSE 1 END)<>7)
            THROW 53784,N'Die tatsächlich gespeicherte Rohprojektion weicht von der ausgewählten Datei ab.',1;
        UPDATE [f] SET [RawHash]=LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),[x].[RawJson])),2))
        FROM @Files [f] CROSS APPLY(SELECT (SELECT [m].[Code] AS [MetricCode],CONVERT(varchar(20),[ss].[MetricDefinitionId]) AS [MetricDefinitionId],
          CONVERT(varchar(20),[ss].[ScopeId]) AS [ScopeId],LOWER(CONVERT(varchar(36),[ss].[ResetEpochId])) AS [ResetEpochId],
          CONVERT(varchar(20),[ss].[BigintValue]) AS [BigintValue]
          FROM [snapshot].[MetricSample] [ss] JOIN @Metrics [m] ON [m].[Id]=[ss].[MetricDefinitionId]
          WHERE [ss].[CaptureRunId]=@CaptureRunId AND [ss].[ScopeId]=[f].[ScopeId] AND [m].[Code] IN
            ('IO_READ_COUNT','IO_READ_BYTES','IO_READ_STALL_MS','IO_WRITE_COUNT','IO_WRITE_BYTES','IO_WRITE_STALL_MS','IO_SIZE_ON_DISK_BYTES')
          ORDER BY [m].[Code] COLLATE Latin1_General_100_BIN2 FOR JSON PATH,INCLUDE_NULL_VALUES) AS [RawJson]) [x] WHERE [f].[Selected]=1;
        UPDATE [f] SET [Context]=[x].[Context] FROM @Files [f]
        CROSS APPLY(SELECT (SELECT 1 AS [schemaVersion],'FILE_IO' AS [collectorCode],CONVERT(varchar(20),@CaptureRunId) AS [captureRunId],
          CONVERT(varchar(20),[f].[ScopeId]) AS [scopeId],LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),[f].[Identity])),2)) AS [scopeIdentitySha256],
          LOWER(CONVERT(varchar(36),[f].[Epoch])) AS [resetEpochId],CONVERT(varchar(20),[f].[SampleMs]) AS [sampleMs],
          JSON_VALUE([f].[Before],'$.LogicalName') AS [logicalNameBefore],JSON_VALUE([f].[After],'$.LogicalName') AS [logicalNameAfter],
          JSON_VALUE(@Meta,'$.measurementStartUtc') AS [measurementStartUtc],JSON_VALUE(@Meta,'$.measurementEndUtc') AS [measurementEndUtc],
          @Complete AS [sourceComplete],'7' AS [rawSampleCount],[f].[RawHash] AS [rawProjectionSha256],
          CONVERT(varchar(20),@Previous) AS [previousCaptureRunId],[f].[PreviousVersion] AS [previousContextVersion],
          [f].[Comparison] AS [comparisonStatus],[f].[Decision] AS [epochDecision]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES) AS [Context]) [x] WHERE [f].[Selected]=1;
        IF EXISTS(SELECT 1 FROM @Files WHERE [Selected]=1 AND (DATALENGTH([Context])>8000 OR COALESCE(ISJSON([Context]),0)<>1))
            THROW 53784,N'Ein Dateikontext überschreitet seinen Stringvertrag.',1;
        INSERT [snapshot].[MetricSample]
          ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[StringValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,[f].[ScopeId],[m].[Id],@ReadEnd,[f].[Epoch],[f].[Context],'FILE_IO_CONTEXT',1
        FROM @Files [f] JOIN @Metrics [m] ON [m].[Code]='IO_FILE_CONTEXT' WHERE [f].[Selected]=1;
        SELECT @Manifest=(SELECT CONVERT(varchar(20),[ss].[ScopeId]) AS [ScopeId],LOWER(CONVERT(varchar(36),[ss].[ResetEpochId])) AS [ResetEpochId],
          [f].[RawHash] AS [RawProjectionSha256],LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),[ss].[StringValue])),2)) AS [FileContextSha256]
          FROM [snapshot].[MetricSample] [ss] JOIN @Metrics [m] ON [m].[Id]=[ss].[MetricDefinitionId]
          JOIN @Files [f] ON [f].[ScopeId]=[ss].[ScopeId] AND [f].[Selected]=1
          WHERE [ss].[CaptureRunId]=@CaptureRunId AND [m].[Code]='IO_FILE_CONTEXT'
          ORDER BY [ss].[ScopeId] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Manifest=COALESCE(@Manifest,N'[]');
        SET @ManifestHash=LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Manifest)),2));
        SELECT @Context=(SELECT 1 AS [schemaVersion],'FILE_IO' AS [collectorCode],CONVERT(varchar(20),@CaptureRunId) AS [captureRunId],
          CONVERT(varchar(20),@ServerScope) AS [serverScopeId],LOWER(CONVERT(varchar(36),@ContextEpoch)) AS [contextEpochId],
          JSON_QUERY((SELECT JSON_VALUE(@Framework,'$.databaseId') AS [databaseId],JSON_VALUE(@Framework,'$.databaseCreateDateNative') AS [databaseCreateDateNative],
            @FrameworkHash AS [tupleSha256] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [framework],
          JSON_QUERY((SELECT JSON_VALUE(@Engine,'$.sqlServerStartTimeLocal') AS [sqlServerStartTimeLocal],
            JSON_VALUE(@Engine,'$.sqlServerStartTimeMsTicks') AS [sqlServerStartTimeMsTicks],@EngineHash AS [tupleSha256]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [engine],
          JSON_QUERY((SELECT JSON_VALUE(@Meta,'$.measurementStartUtc') AS [measurementStartUtc],JSON_VALUE(@Meta,'$.measurementEndUtc') AS [measurementEndUtc],
            JSON_VALUE(@Meta,'$.nativeReadStartUtc') AS [nativeReadStartUtc],JSON_VALUE(@Meta,'$.nativeReadEndUtc') AS [nativeReadEndUtc]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [window],
          JSON_QUERY((SELECT JSON_VALUE(@Selection,'$.selectedDatabaseCount') AS [databaseCount],@SelectionHash AS [selectionSha256],1 AS [scopeContractVersion]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [selection],
          JSON_QUERY((SELECT JSON_VALUE(@Meta,'$.nativeReadState') AS [nativeReadState],@Complete AS [sourceComplete],
            CONVERT(varchar(20),@Native) AS [selectedNativeFileCount],CONVERT(varchar(20),@Eligible) AS [eligibleFileCount],
            CONVERT(varchar(20),@Written) AS [writtenFileCount],CONVERT(varchar(20),@Excluded) AS [excludedFileCount],
            CONVERT(varchar(20),@Unbound) AS [unboundFileCount],CONVERT(varchar(20),@MaxRows) AS [effectiveMaxRows],@Limited AS [writeLimited]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [capture],
          JSON_QUERY((SELECT CONVERT(varchar(20),7*@Written) AS [rawSampleCount],CONVERT(varchar(20),6*@Comparable) AS [candidateSampleCount],
            CONVERT(varchar(20),@Written) AS [fileContextSampleCount],CONVERT(varchar(20),@Written) AS [statusSampleCount]
            FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [samples],
          CONVERT(varchar(20),@Previous) AS [previousCaptureRunId],@ManifestHash AS [fileRawContextManifestSha256]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        IF DATALENGTH(@Context)>8000 OR COALESCE(ISJSON(@Context),0)<>1
            THROW 53784,N'Der Capturekontext überschreitet seinen Stringvertrag.',1;
        INSERT [snapshot].[MetricSample]
          ([CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc],[ResetEpochId],[StringValue],[QualityCode],[IsPartial])
        SELECT @CaptureRunId,@ServerScope,[Id],COALESCE(@ReadEnd,@End),@ContextEpoch,@Context,'CAPTURE_CONTEXT',1 FROM @Metrics WHERE [Code]='IO_CAPTURE_CONTEXT';
        IF (SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)<>9*@Written+6*@Comparable+1
            THROW 53784,N'Die tatsächliche Metrikmenge verletzt den Datei-I/O-Mengenvertrag.',1;
        SET @StatusCodeOut='PARTIAL';

PersistIssues:
        SET @IsPartialOut=1;
        IF @Payload=1
            INSERT [snapshot].[PayloadSnapshot]
              ([CaptureRunId],[ModuleName],[CapturedAtUtc],[PayloadFormat],[PayloadContractVersion],[CompressionType],[PayloadHash],[Payload],[UncompressedCharacterCount])
            VALUES(@CaptureRunId,N'SnapshotFileIO',COALESCE(@End,SYSUTCDATETIME()),'JSON',1,'GZIP',
              HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CollectorJson)),COMPRESS(@CollectorJson),DATALENGTH(@CollectorJson)/2);
        DECLARE @IssueOrdinal int,@SourceModule sysname,@IssueStatus varchar(40),@IssueError int,@IssueMessage nvarchar(2048),
          @PersistSourceModule sysname,@PersistContextModule sysname,
          @Evidence nvarchar(1000),@ScopeType varchar(16),@IssueDB int,@IssueFile int,@IssueName sysname,@ModuleId bigint,@IssueContext nvarchar(max);
        DECLARE [SourceIssues] CURSOR LOCAL FAST_FORWARD FOR SELECT [Ordinal],[SourceName],[StatusCode],[ErrorNumber],[ErrorMessage],
          [EvidenceLimit],[ScopeType],[DatabaseId],[FileId],[DatabaseName] FROM @Issues ORDER BY [Ordinal];
        OPEN [SourceIssues];
        FETCH NEXT FROM [SourceIssues] INTO @IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT @PersistSourceModule=CASE WHEN EXISTS(SELECT 1 FROM @Issues WHERE [SourceName]=@SourceModule AND [Ordinal]<@IssueOrdinal)
              THEN CONVERT(sysname,CONCAT(@SourceModule,N'#',@IssueOrdinal)) ELSE @SourceModule END,
              @PersistContextModule=CASE WHEN @IssueOrdinal=0 THEN N'FileIOSourceIssueContext' ELSE CONVERT(sysname,CONCAT(N'FileIOSourceIssueContext#',@IssueOrdinal)) END;
            INSERT [snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
            VALUES(@CaptureRunId,@PersistSourceModule,COALESCE(@End,SYSUTCDATETIME()),@IssueStatus,1,@IssueError,@IssueMessage,@Evidence);
            SET @ModuleId=CONVERT(bigint,SCOPE_IDENTITY());
            SELECT @IssueContext=(SELECT CONVERT(varchar(20),@ModuleId) AS [sourceModuleStatusId],@ScopeType AS [ScopeType],@IssueDB AS [DatabaseId],
              @IssueFile AS [FileId],@IssueName AS [DatabaseName],@IssueStatus AS [StatusCode] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            IF DATALENGTH(@IssueContext)>4096 THROW 53784,N'Der gebundene Issuekontext überschreitet sein Meldungslimit.',1;
            INSERT [snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
            VALUES(@CaptureRunId,@PersistContextModule,COALESCE(@End,SYSUTCDATETIME()),@IssueStatus,1,NULL,@IssueContext,NULL);
            FETCH NEXT FROM [SourceIssues] INTO @IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;
        END;
        CLOSE [SourceIssues]; DEALLOCATE [SourceIssues];
        INSERT [snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
        VALUES(@CaptureRunId,N'FileIOCollector',COALESCE(@End,SYSUTCDATETIME()),@StatusCodeOut,1,NULL,@ErrorMessageOut,
          N'Dateiepochen und vollständige Rohbindungen begrenzen Differenzkandidaten; monotone Werte beweisen keine Resetkontinuität.');
        SET @Now=SYSUTCDATETIME();
        IF @Now<@Started OR @Now<@End THROW 53784,N'Die tatsächliche Finalisierungszeit liegt vor dem Messfenster.',1;
        UPDATE [snapshot].[CaptureRun] SET [EndedAtUtc]=@Now,[ResetEpochId]=NULL,[SqlServerStartTimeUtc]=NULL,
          [StatusCode]=@StatusCodeOut,[IsPartial]=1,[ErrorNumber]=@ErrorNumberOut,[ErrorMessage]=@ErrorMessageOut,
          [MetricSampleCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId),
          [PayloadCount]=(SELECT COUNT_BIG(*) FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
        WHERE [CaptureRunId]=@CaptureRunId AND [StatusCode]='RUNNING' AND [EndedAtUtc] IS NULL;
        IF @@ROWCOUNT<>1 THROW 53784,N'Der eigene Datei-I/O-Lauf konnte nicht finalisiert werden.',1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        DECLARE @Failure int=ERROR_NUMBER(),@FailureMessage nvarchar(2048)=ERROR_MESSAGE(),
                @FailureModuleId bigint,@Recorded datetime2(3),@Confirmed bit,@Boundary nvarchar(max);
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN @Failure IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
          WHEN @Failure IN(53781,53764,2812,8144,8145) THEN 'TARGET_UNAVAILABLE'
          WHEN @OwnRun=0 AND @Failure=53783 THEN 'INVALID_PARAMETER' ELSE 'ERROR_HANDLED' END,
          @IsPartialOut=1,@ErrorNumberOut=CASE WHEN @OwnRun=0 AND @Failure=53783 THEN 51011 ELSE @Failure END,
          @ErrorMessageOut=@FailureMessage;
        IF @OwnRun=1
        BEGIN TRY
            IF DB_ID()<>@ExpectedTargetDatabaseId OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
              WHERE [database_id]=@ExpectedTargetDatabaseId AND [create_date]=@ExpectedTargetCreateDate
                AND CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@ExpectedTargetDatabaseName) AND [state]=0 AND [is_read_only]=0)
                THROW 53764,N'Die Fehlerfinalisierung kann die gebundene Targetidentität nicht bestätigen.',1;
            BEGIN TRANSACTION;
            IF NOT EXISTS(SELECT 1 FROM [snapshot].[CaptureRun] WITH (UPDLOCK,HOLDLOCK) WHERE [CaptureRunId]=@CaptureRunId
              AND [CollectorCode]='FILE_IO' AND [StatusCode]='RUNNING' AND [EndedAtUtc] IS NULL
              AND [StartedAtUtc]=@Started AND CONVERT(varbinary(max),[SourceDatabaseName])=CONVERT(varbinary(max),@SourceName))
              OR EXISTS(SELECT 1 FROM [snapshot].[MetricSample] WHERE [CaptureRunId]=@CaptureRunId)
              OR EXISTS(SELECT 1 FROM [snapshot].[ModuleStatus] WHERE [CaptureRunId]=@CaptureRunId)
              OR EXISTS(SELECT 1 FROM [snapshot].[PayloadSnapshot] WHERE [CaptureRunId]=@CaptureRunId)
                THROW 53784,N'Die Fehlerfinalisierung bestätigt keinen unveränderten eigenen Lauf.',1;
            SELECT @Recorded=SYSUTCDATETIME();
            SET @Confirmed=CASE WHEN @Recorded>=@Started THEN 1 ELSE 0 END;
            INSERT [snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
            VALUES(@CaptureRunId,CASE WHEN @SourceValidated=0 AND @Failure=53782 THEN N'SOURCE_CONTRACT'
                   ELSE N'snapshot.InternalCompleteFileIOCycle' END,@Recorded,'ERROR_HANDLED',1,@Failure,@FailureMessage,
              N'Die Fachwrites wurden zurückgerollt; keine numerische Aufnahme wird behauptet.');
            SET @FailureModuleId=CONVERT(bigint,SCOPE_IDENTITY());
            IF @SourceValidated=1
            BEGIN
                DELETE @Issues;
                INSERT @Issues([Ordinal],[ScopeType],[SourceName],[DatabaseId],[FileId],[DatabaseName],[StatusCode],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                SELECT [Ordinal],[ScopeType],[SourceName],[DatabaseId],[FileId],[DatabaseName],[StatusCode],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
                FROM OPENJSON(@ValidatedIssuesJson) WITH
                 ([Ordinal] int,[ScopeType] varchar(16),[SourceName] nvarchar(128),[DatabaseId] int,[FileId] int,[DatabaseName] nvarchar(128),
                  [StatusCode] varchar(40),[ErrorNumber] int,[ErrorMessage] nvarchar(2048),[EvidenceLimit] nvarchar(1000));
                DECLARE [FailureSourceIssues] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [Ordinal],[SourceName],[StatusCode],[ErrorNumber],[ErrorMessage],[EvidenceLimit],[ScopeType],[DatabaseId],[FileId],[DatabaseName]
                FROM @Issues ORDER BY [Ordinal];
                OPEN [FailureSourceIssues];
                FETCH NEXT FROM [FailureSourceIssues] INTO @IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;
                WHILE @@FETCH_STATUS=0
                BEGIN
                    SELECT @PersistSourceModule=CASE WHEN EXISTS(SELECT 1 FROM @Issues WHERE [SourceName]=@SourceModule AND [Ordinal]<@IssueOrdinal)
                      THEN CONVERT(sysname,CONCAT(@SourceModule,N'#',@IssueOrdinal)) ELSE @SourceModule END,
                      @PersistContextModule=CASE WHEN @IssueOrdinal=0 THEN N'FileIOSourceIssueContext' ELSE CONVERT(sysname,CONCAT(N'FileIOSourceIssueContext#',@IssueOrdinal)) END;
                    INSERT [snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                    VALUES(@CaptureRunId,@PersistSourceModule,@Recorded,@IssueStatus,1,@IssueError,@IssueMessage,@Evidence);
                    SET @ModuleId=CONVERT(bigint,SCOPE_IDENTITY());
                    SELECT @IssueContext=(SELECT CONVERT(varchar(20),@ModuleId) AS [sourceModuleStatusId],@ScopeType AS [ScopeType],@IssueDB AS [DatabaseId],
                      @IssueFile AS [FileId],@IssueName AS [DatabaseName],@IssueStatus AS [StatusCode] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
                    INSERT [snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
                    VALUES(@CaptureRunId,@PersistContextModule,@Recorded,@IssueStatus,1,NULL,@IssueContext,NULL);
                    FETCH NEXT FROM [FailureSourceIssues] INTO @IssueOrdinal,@SourceModule,@IssueStatus,@IssueError,@IssueMessage,@Evidence,@ScopeType,@IssueDB,@IssueFile,@IssueName;
                END;
                CLOSE [FailureSourceIssues]; DEALLOCATE [FailureSourceIssues];
            END
            ELSE IF @Failure=53782
            BEGIN
                SELECT @IssueContext=(SELECT CONVERT(varchar(20),@FailureModuleId) AS [sourceModuleStatusId],'SOURCE' AS [ScopeType],
                  CONVERT(int,NULL) AS [DatabaseId],CONVERT(int,NULL) AS [FileId],CONVERT(nvarchar(128),NULL) AS [DatabaseName],
                  'ERROR_HANDLED' AS [StatusCode] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
                INSERT [snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorMessage])
                VALUES(@CaptureRunId,N'FileIOSourceIssueContext',@Recorded,'ERROR_HANDLED',1,@IssueContext);
            END;
            INSERT [snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
            VALUES(@CaptureRunId,N'FileIOCollector',@Recorded,'ERROR_HANDLED',1,NULL,
              CASE WHEN @SourceValidated=1 THEN @SourceErrorMessage ELSE @FailureMessage END,
              N'Der Targetabschluss enthält keine numerischen Samples; die Quelldiagnose bleibt getrennt erhalten.');
            IF @Confirmed=0
            BEGIN
                SELECT @Boundary=(SELECT 1 AS [schemaVersion],CONVERT(varchar(20),@CaptureRunId) AS [captureRunId],
                  CONVERT(varchar(20),@FailureModuleId) AS [failureModuleStatusId],'FINALIZATION_UNCONFIRMED' AS [statusCode],
                  CONVERT(nvarchar(19),@Started,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@Started)),3)+N'Z' AS [startedAtUtc],
                  CONVERT(nvarchar(19),@Recorded,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(millisecond,@Recorded)),3)+N'Z' AS [recordedAtUtc],
                  @SourceValidated AS [sourceIssuesPreserved],CONVERT(bit,0) AS [finalizationConfirmed]
                  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
                INSERT [snapshot].[ModuleStatus]([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage])
                VALUES(@CaptureRunId,N'FileIOFinalizationBoundary',@Recorded,'FINALIZATION_UNCONFIRMED',1,NULL,@Boundary);
            END;
            UPDATE [snapshot].[CaptureRun] SET [EndedAtUtc]=CASE WHEN @Confirmed=1 THEN @Recorded END,
              [ResetEpochId]=NULL,[SqlServerStartTimeUtc]=NULL,[StatusCode]='ERROR_HANDLED',[IsPartial]=1,
              [ErrorNumber]=CASE WHEN @SourceValidated=1 THEN @SourceErrorNumber ELSE @Failure END,
              [ErrorMessage]=CASE WHEN @SourceValidated=1 THEN @SourceErrorMessage ELSE @FailureMessage END,[MetricSampleCount]=0,[PayloadCount]=0
            WHERE [CaptureRunId]=@CaptureRunId AND [StatusCode]='RUNNING' AND [EndedAtUtc] IS NULL;
            IF @@ROWCOUNT<>1 THROW 53784,N'Der eigene Fehlerabschluss wurde nicht bestätigt.',1;
            COMMIT TRANSACTION;
            SELECT @StatusCodeOut=CASE WHEN @Confirmed=1 THEN 'ERROR_HANDLED' ELSE 'FINALIZATION_UNCONFIRMED' END,
              @ErrorNumberOut=CASE WHEN @SourceValidated=1 THEN @SourceErrorNumber ELSE @Failure END,
              @ErrorMessageOut=CASE WHEN @SourceValidated=1 THEN @SourceErrorMessage ELSE @FailureMessage END;
        END TRY
        BEGIN CATCH
            SELECT @StatusCodeOut='FINALIZATION_UNCONFIRMED',@IsPartialOut=1,
              @ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE());
            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        END CATCH;
        IF @OwnRun=0 AND @Failure=53783 RETURN 51011;
    END CATCH;
END;
GO
