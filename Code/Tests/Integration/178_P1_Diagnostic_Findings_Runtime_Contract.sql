USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 178_P1_Diagnostic_Findings_Runtime_Contract.sql
Zweck        : Prüft Laufzeitverträge für neun P1-Findings-Fälle.
Datenschutz  : Ausschließlich synthetische Principals und technische Statuswerte;
               keine SQL-, Plan-, Mail-, Pfad- oder freien Child-Meldungstexte
               werden als Testevidenz persistiert.
Nebenwirkung : Ein synthetischer Benutzer und ein temporär niedrigeres
               Compatibility Level werden in TRY/CATCH vollständig zurückgesetzt.
===============================================================================
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExecutedCases TABLE([CaseId] varchar(40) NOT NULL PRIMARY KEY);
DECLARE @Json nvarchar(max),@Status varchar(40),@Partial bit,@ErrorNumber int,@ErrorMessage nvarchar(2048);
DECLARE @OriginalCompatibilityLevel int=
    (SELECT [compatibility_level] FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID());
DECLARE @DatabaseName sysname=(SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID());
DECLARE @AlterCompatibilitySql nvarchar(max);
DECLARE @Impersonating bit=0;

/* FIND-CORE, FIND-STANDALONE-FRESH und FIND-OPTOUT: ein Kernmodul wird ohne
   Parent-Ergebnis frisch ausgeführt; optionale teure Module bleiben per Default aus. */
EXEC [monitor].[USP_DiagnosticFindings]
     @DatabaseNames=N'[DeineDatenbank]',
     @MitIntegritaet=0,@MitKapazitaet=0,@MitSpeicher=0,@MitBackupketten=0,
     @MitAvailability=0,@MitAgentMonitoring=1,
     @MaxZeilen=100,@ResultSetArt='NONE',
     @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
     @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT,
     @HighImpactConfirmed=1;

/* Derselbe Prüfblock dient dem echten Aufruf und neun synthetischen Gegenproben.
   Nur feste Statuswerte und Zahlen gelangen in die vorhandene CI-Fehlerausgabe. */
DECLARE @FindCoreCheck nvarchar(max)=N'
SET @Line=NULL;
DECLARE @Valid bit=COALESCE(ISJSON(@Json),0),@SafeJson nvarchar(max),@Count int,
        @BadStatus bit=CASE WHEN @Status NOT IN(''AVAILABLE_WITH_FINDING'',''AVAILABLE_LIMITED'') THEN 1 ELSE 0 END,
        @BadAgent bit=1,@BadKeys bit=1,@ParseError int=NULL,
        @AgentInvoke varchar(40),@AgentEvidence varchar(40),@AgentError int,
        @AggregationInvoke varchar(40),@AggregationError int;
SET @SafeJson=CASE WHEN @Valid=1 THEN @Json ELSE N''{}'' END;
BEGIN TRY
    SET @Count=TRY_CONVERT(int,JSON_VALUE(@SafeJson,N''$.meta.totalFindingCount''));
    SET @BadAgent=CASE WHEN EXISTS
        (SELECT 1 FROM OPENJSON(@SafeJson,N''$.modules'')
         WITH ([ModuleName] sysname N''$.ModuleName'',[InvocationStatus] varchar(40) N''$.InvocationStatus'')
         WHERE [ModuleName]=N''USP_AgentMonitoringAnalysis'' AND [InvocationStatus]=''EXECUTED'') THEN 0 ELSE 1 END;
    SET @BadKeys=CASE WHEN EXISTS
        (SELECT 1 FROM OPENJSON(@SafeJson,N''$.findings'') AS [f] CROSS APPLY OPENJSON([f].[value]) AS [p]
         WHERE [p].[key] NOT IN
         (N''FindingOrdinal'',N''SourceModule'',N''Category'',N''Severity'',N''Confidence'',N''ScopeType'',
          N''ScopeName'',N''FindingCode'',N''EvidenceMetric'',N''Evidence'',N''EvidenceLimit'',N''RecommendedNextCheck'')) THEN 1 ELSE 0 END;
    SELECT @AgentInvoke=MAX(CASE WHEN [ModuleName]=N''USP_AgentMonitoringAnalysis'' THEN [InvocationStatus] END),
           @AgentEvidence=MAX(CASE WHEN [ModuleName]=N''USP_AgentMonitoringAnalysis'' THEN [EvidenceStatus] END),
           @AgentError=MAX(CASE WHEN [ModuleName]=N''USP_AgentMonitoringAnalysis'' THEN TRY_CONVERT(int,[ErrorNumber]) END),
           @AggregationInvoke=MAX(CASE WHEN [ModuleName]=N''JSON_EVIDENCE_AGGREGATION'' THEN [InvocationStatus] END),
           @AggregationError=MAX(CASE WHEN [ModuleName]=N''JSON_EVIDENCE_AGGREGATION'' THEN TRY_CONVERT(int,[ErrorNumber]) END)
    FROM OPENJSON(@SafeJson,N''$.modules'') WITH
        ([ModuleName] sysname N''$.ModuleName'',[InvocationStatus] varchar(40) N''$.InvocationStatus'',
         [EvidenceStatus] varchar(40) N''$.EvidenceStatus'',[ErrorNumber] nvarchar(4000) N''$.ErrorNumber'');
END TRY
BEGIN CATCH
    SET @ParseError=ERROR_NUMBER();
END CATCH;
IF @Valid=0 OR @BadStatus=1 OR COALESCE(@Count,0)<1 OR @BadAgent=1 OR @BadKeys=1 OR @ParseError IS NOT NULL
BEGIN
    SELECT @Status=CASE WHEN @Status IN(''AVAILABLE'',''AVAILABLE_EMPTY'',''AVAILABLE_WITH_FINDING'',''AVAILABLE_LIMITED'',
        ''DENIED_PERMISSION'',''ERROR_HANDLED'',''DATABASE_UNAVAILABLE'',''UNAVAILABLE_FEATURE'',''INVALID_PARAMETER'') THEN @Status
        WHEN @Status IS NULL THEN ''NULL'' ELSE ''UNKNOWN'' END,
        @AgentInvoke=CASE WHEN @AgentInvoke IN(''EXECUTED'',''ERROR_HANDLED'',''REUSED_PARENT_RESULT'',''SKIPPED'') THEN @AgentInvoke
        WHEN @AgentInvoke IS NULL THEN ''NULL'' ELSE ''UNKNOWN'' END,
        @AgentEvidence=CASE WHEN @AgentEvidence IN(''AVAILABLE'',''AVAILABLE_EMPTY'',''AVAILABLE_WITH_FINDING'',''AVAILABLE_LIMITED'',
        ''DENIED_PERMISSION'',''ERROR_HANDLED'',''DATABASE_UNAVAILABLE'',''UNAVAILABLE_FEATURE'') THEN @AgentEvidence
        WHEN @AgentEvidence IS NULL THEN ''NULL'' ELSE ''UNKNOWN'' END,
        @AggregationInvoke=CASE WHEN @AggregationInvoke IN(''EXECUTED'',''ERROR_HANDLED'') THEN @AggregationInvoke
        WHEN @AggregationInvoke IS NULL THEN ''NULL'' ELSE ''UNKNOWN'' END;
    SET @Line=CONCAT(N''Error: FIND_CORE_FAILURE badJson='',1-CONVERT(int,@Valid),N'' badStatus='',@BadStatus,
        N'' badCount='',CASE WHEN COALESCE(@Count,0)<1 THEN 1 ELSE 0 END,N'' badAgent='',@BadAgent,N'' badKeys='',@BadKeys,
        N'' status='',@Status,N'' partial='',COALESCE(CONVERT(varchar(1),@Partial),''NULL''),
        N'' error='',COALESCE(CONVERT(varchar(12),@ErrorNumber),''NULL''),N'' count='',COALESCE(CONVERT(varchar(12),@Count),''NULL''),
        N'' agentInvoke='',@AgentInvoke,N'' agentEvidence='',@AgentEvidence,N'' agentError='',COALESCE(CONVERT(varchar(12),@AgentError),''NULL''),
        N'' aggregationInvoke='',@AggregationInvoke,N'' aggregationError='',COALESCE(CONVERT(varchar(12),@AggregationError),''NULL''),
        N'' parseError='',COALESCE(CONVERT(varchar(12),@ParseError),''NULL''));
END;';
DECLARE @FindCoreParameters nvarchar(400)=N'@Json nvarchar(max),@Status varchar(40),@Partial bit,@ErrorNumber int,@Line nvarchar(1024) OUTPUT';
DECLARE @FindCoreLine nvarchar(1024);
EXEC [sys].[sp_executesql] @FindCoreCheck,@FindCoreParameters,@Json,@Status,@Partial,@ErrorNumber,@FindCoreLine OUTPUT;
IF @FindCoreLine IS NOT NULL
BEGIN
    RAISERROR(N'%s',10,1,@FindCoreLine) WITH NOWAIT;
    THROW 55200,N'P1-Vertrag FIND-CORE fehlgeschlagen.',1;
END;

/* Die Gegenproben verändern keine Procedure, Quelle oder fachliche Fallzählung. */
DECLARE @ProbeBase nvarchar(max)=N'{"meta":{"totalFindingCount":1},"modules":[{"ModuleName":"USP_AgentMonitoringAnalysis","InvocationStatus":"EXECUTED","EvidenceStatus":"AVAILABLE"}],"findings":[{"FindingCode":"SYNTHETIC_FINDING","ScopeName":"SYNTHETIC_PRIVATE_PAYLOAD"}]}',
        @ProbeJson nvarchar(max),@ProbeStatus varchar(40),@ProbePartial bit,@ProbeError int,@ProbeOrdinal int=0,
        @ExpectedToken nvarchar(80),@Caught int,@Character int;
WHILE @ProbeOrdinal<9
BEGIN
    SELECT @ProbeJson=@ProbeBase,@ProbeStatus='AVAILABLE_WITH_FINDING',@ProbePartial=0,@ProbeError=NULL,@Caught=NULL,
           @ExpectedToken=CASE @ProbeOrdinal WHEN 1 THEN N'badJson=1' WHEN 2 THEN N'badJson=1'
           WHEN 3 THEN N'badStatus=1' WHEN 4 THEN N'badCount=1' WHEN 5 THEN N'badAgent=1'
           WHEN 6 THEN N'agentError=1222' WHEN 7 THEN N'badKeys=1' WHEN 8 THEN N'aggregationError=13609' END;
    IF @ProbeOrdinal=1 SET @ProbeJson=NULL;
    IF @ProbeOrdinal=2 SET @ProbeJson=N'SYNTHETIC_PRIVATE_PAYLOAD'+NCHAR(10);
    IF @ProbeOrdinal=3 SET @ProbeStatus='SYNTHETIC_PRIVATE_PAYLOAD'+CHAR(10)+'%';
    IF @ProbeOrdinal=4 SET @ProbeJson=JSON_MODIFY(@ProbeJson,N'$.meta.totalFindingCount',0);
    IF @ProbeOrdinal=5 SET @ProbeJson=JSON_MODIFY(@ProbeJson,N'$.modules',JSON_QUERY(N'[]'));
    IF @ProbeOrdinal=6
    BEGIN
        SET @ProbeJson=JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(@ProbeJson,N'$.modules[0].InvocationStatus','ERROR_HANDLED'),
            N'$.modules[0].EvidenceStatus','DENIED_PERMISSION'),N'$.modules[0].ErrorNumber',1222);
        SELECT @ProbeStatus='AVAILABLE_LIMITED',@ProbePartial=1,@ProbeError=1222;
    END;
    IF @ProbeOrdinal=7 SET @ProbeJson=JSON_MODIFY(@ProbeJson,N'$.findings[0].Unexpected',N'SYNTHETIC_PRIVATE_PAYLOAD');
    IF @ProbeOrdinal=8
        SET @ProbeJson=JSON_MODIFY(JSON_MODIFY(@ProbeJson,N'$.meta.totalFindingCount',0),N'append $.modules',
            JSON_QUERY(N'{"ModuleName":"JSON_EVIDENCE_AGGREGATION","InvocationStatus":"ERROR_HANDLED","ErrorNumber":13609}'));
    BEGIN TRY
        EXEC [sys].[sp_executesql] @FindCoreCheck,@FindCoreParameters,
            @ProbeJson,@ProbeStatus,@ProbePartial,@ProbeError,@FindCoreLine OUTPUT;
        IF @FindCoreLine IS NOT NULL THROW 55200,N'P1-Vertrag FIND-CORE fehlgeschlagen.',1;
    END TRY
    BEGIN CATCH
        SET @Caught=ERROR_NUMBER();
        IF @Caught<>55200 THROW;
    END CATCH;
    IF (@ProbeOrdinal=0 AND (@Caught IS NOT NULL OR @FindCoreLine IS NOT NULL))
       OR (@ProbeOrdinal>0 AND (@Caught IS NULL OR @FindCoreLine IS NULL OR CHARINDEX(@ExpectedToken,@FindCoreLine)=0
           OR LEFT(@FindCoreLine,25)<>N'Error: FIND_CORE_FAILURE ' OR LEN(@FindCoreLine)>1024
           OR CHARINDEX(N'SYNTHETIC_PRIVATE_PAYLOAD',@FindCoreLine)>0))
        THROW 55212,N'FIND-CORE: Die synthetische Diagnosegegenprobe ist fehlgeschlagen.',1;
    SET @Character=1;
    WHILE @Character<=LEN(@FindCoreLine)
    BEGIN
        IF UNICODE(SUBSTRING(@FindCoreLine,@Character,1)) NOT BETWEEN 32 AND 126
            THROW 55212,N'FIND-CORE: Die Diagnose enthält unzulässige Zeichen.',1;
        SET @Character+=1;
    END;
    SET @ProbeOrdinal+=1;
END;
RAISERROR(N'FIND_CORE_DIAGNOSTIC_PROBES passed=9 synthetic=1',10,1) WITH NOWAIT;
INSERT @ExecutedCases VALUES('FIND-CORE');
INSERT @ExecutedCases VALUES('FIND-STANDALONE-FRESH');

IF EXISTS
(
    SELECT 1
    FROM OPENJSON(@Json,N'$.modules')
    WITH ([ModuleName] sysname N'$.ModuleName')
    WHERE [ModuleName] IN
          (N'USP_SchemaDesignAnalysis',N'USP_StatisticsDistributionAnalysis',
           N'USP_IntelligentQueryProcessingAnalysis',N'USP_InternalContentionAnalysis')
)
    THROW 55201,N'P1-Vertrag FIND-OPTOUT fehlgeschlagen.',1;
INSERT @ExecutedCases VALUES('FIND-OPTOUT');

/* FIND-PARENT-REUSE: Der Parent erhebt drei kontextgleiche Ergebnisse einmal;
   der Findings-Child verwendet sie ohne erneuten Aufruf dieser Module. */
SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL; SET @ErrorNumber=NULL; SET @ErrorMessage=NULL;
EXEC [monitor].[USP_DiagnosticFindings]
     @MitIntegritaet=1,@MitKapazitaet=0,@MitSpeicher=0,@MitBackupketten=0,
     @MitAvailability=0,@MitAgentMonitoring=0,
     @ParentIntegrityJson=N'{"meta":{"resultName":"OtherResult","schemaVersion":1}}',
     @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
     @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT,
     @HighImpactConfirmed=1;

IF ISJSON(@Json)<>1 OR @Status<>'INVALID_PARAMETER' OR @Partial<>1
   OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.modules'))<>0
    THROW 55207,N'P1-Vertrag FIND-PARENT-REUSE akzeptiert einen falschen Parent-Vertrag.',1;

SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL; SET @ErrorNumber=NULL; SET @ErrorMessage=NULL;
EXEC [monitor].[USP_ServerHealthAnalysis]
     @MitCpu=0,@MitNuma=0,@MitMemory=0,@MitTempDB=0,
     @MitConfiguration=0,@MitTraceFlags=0,@MitStartup=0,@MitOS=0,@MitSecurity=0,
     @MitIntegritaet=1,@MitKapazitaet=1,@MitPerformanceCounters=0,
     @MitCriticalEvents=0,@MitContention=0,@MitBufferPool=1,@MitFindings=1,
     @DatabaseNames=N'[DeineDatenbank]',@MaxZeilen=100,
     @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
     @HighImpactConfirmed=1;

IF ISJSON(@Json)<>1
   OR
   (
       SELECT COUNT_BIG(*)
       FROM OPENJSON(@Json,N'$.diagnosticFindings.modules')
       WITH
       (
           [ModuleName] sysname N'$.ModuleName',
           [InvocationStatus] varchar(40) N'$.InvocationStatus'
       )
       WHERE [ModuleName] IN
             (N'USP_DatabaseIntegrityAnalysis',N'USP_DatabaseCapacityAnalysis',N'USP_BufferPoolAnalysis')
         AND [InvocationStatus]='REUSED_PARENT_RESULT'
   )<>3
   OR EXISTS
      (
          SELECT 1
          FROM OPENJSON(@Json,N'$.diagnosticFindings.modules')
          WITH
          (
              [ModuleName] sysname N'$.ModuleName',
              [InvocationStatus] varchar(40) N'$.InvocationStatus'
          )
          WHERE [ModuleName] IN
                (N'USP_DatabaseIntegrityAnalysis',N'USP_DatabaseCapacityAnalysis',N'USP_BufferPoolAnalysis')
            AND [InvocationStatus]<>'REUSED_PARENT_RESULT'
      )
    THROW 55206,N'P1-Vertrag FIND-PARENT-REUSE fehlgeschlagen.',1;
INSERT @ExecutedCases VALUES('FIND-PARENT-REUSE');

/* FIND-PARTIAL: eingeschränkter User verliert eine Child-Quelle, andere Child-Status bleiben erhalten. */
IF USER_ID(N'ExampleDiagnosticFindingsRestrictedUser') IS NOT NULL
    THROW 55202,N'Der synthetische Principal für FIND-PARTIAL ist bereits vorhanden.',1;

BEGIN TRY
    CREATE USER [ExampleDiagnosticFindingsRestrictedUser] WITHOUT LOGIN;
    GRANT EXECUTE ON OBJECT::[monitor].[USP_DiagnosticFindings]
        TO [ExampleDiagnosticFindingsRestrictedUser];

    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL; SET @ErrorNumber=NULL; SET @ErrorMessage=NULL;
    EXECUTE AS USER=N'ExampleDiagnosticFindingsRestrictedUser';
    SET @Impersonating=1;
    EXEC [monitor].[USP_DiagnosticFindings]
         @DatabaseNames=N'[DeineDatenbank]',
         @MitIntegritaet=0,@MitKapazitaet=0,@MitSpeicher=0,@MitBackupketten=0,
         @MitAvailability=1,@MitAgentMonitoring=1,
         @MaxZeilen=100,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT,
         @HighImpactConfirmed=1;
    REVERT;
    SET @Impersonating=0;

    IF ISJSON(@Json)<>1 OR @Status<>'AVAILABLE_LIMITED' OR @Partial<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.modules'))<>2
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@Json,N'$.modules')
              WITH ([ModuleName] sysname N'$.ModuleName',[EvidenceStatus] varchar(40) N'$.EvidenceStatus')
              WHERE [ModuleName]=N'USP_AvailabilityDeepAnalysis' AND [EvidenceStatus]='NOT_APPLICABLE'
          )
       OR NOT EXISTS
          (
              SELECT 1
              FROM OPENJSON(@Json,N'$.modules')
              WITH ([ModuleName] sysname N'$.ModuleName',[IsPartial] bit N'$.IsPartial')
              WHERE [ModuleName]=N'USP_AgentMonitoringAnalysis' AND [IsPartial]=1
          )
        THROW 55203,N'P1-Vertrag FIND-PARTIAL fehlgeschlagen.',1;

    DROP USER [ExampleDiagnosticFindingsRestrictedUser];
END TRY
BEGIN CATCH
    IF @Impersonating=1
    BEGIN
        BEGIN TRY
            REVERT;
            SET @Impersonating=0;
        END TRY
        BEGIN CATCH
        END CATCH;
    END;
    BEGIN TRY
        DROP USER IF EXISTS [ExampleDiagnosticFindingsRestrictedUser];
    END TRY
    BEGIN CATCH
    END CATCH;
    THROW;
END CATCH;
INSERT @ExecutedCases VALUES('FIND-PARTIAL');

/* FIND-COMPAT: niedrige Compatibility verhindert OPENJSON-Aggregation ohne Child-Aufrufe. */
BEGIN TRY
    SET @AlterCompatibilitySql=N'ALTER DATABASE '+QUOTENAME(@DatabaseName)+N' SET COMPATIBILITY_LEVEL = 120;';
    EXEC [sys].[sp_executesql] @AlterCompatibilitySql;

    SET @Json=NULL; SET @Status=NULL; SET @Partial=NULL; SET @ErrorNumber=NULL; SET @ErrorMessage=NULL;
    EXEC [monitor].[USP_DiagnosticFindings]
         @DatabaseNames=N'[DeineDatenbank]',
         @MitIntegritaet=0,@MitKapazitaet=0,@MitSpeicher=0,@MitBackupketten=0,
         @MitAvailability=0,@MitAgentMonitoring=1,
         @MaxZeilen=10,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT,
         @HighImpactConfirmed=1;

    SET @AlterCompatibilitySql=N'ALTER DATABASE '+QUOTENAME(@DatabaseName)+N' SET COMPATIBILITY_LEVEL = '
                               +CONVERT(nvarchar(10),@OriginalCompatibilityLevel)+N';';
    EXEC [sys].[sp_executesql] @AlterCompatibilitySql;

    IF ISJSON(@Json)<>1 OR @Status<>'UNAVAILABLE_FEATURE' OR @Partial<>1
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.modules'))<>0
       OR (SELECT COUNT_BIG(*) FROM OPENJSON(@Json,N'$.findings'))<>0
        THROW 55204,N'P1-Vertrag FIND-COMPAT fehlgeschlagen.',1;
END TRY
BEGIN CATCH
    BEGIN TRY
        IF (SELECT [compatibility_level] FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID())<>@OriginalCompatibilityLevel
        BEGIN
            SET @AlterCompatibilitySql=N'ALTER DATABASE '+QUOTENAME(@DatabaseName)+N' SET COMPATIBILITY_LEVEL = '
                                       +CONVERT(nvarchar(10),@OriginalCompatibilityLevel)+N';';
            EXEC [sys].[sp_executesql] @AlterCompatibilitySql;
        END;
    END TRY
    BEGIN CATCH
    END CATCH;
    THROW;
END CATCH;
INSERT @ExecutedCases VALUES('FIND-COMPAT');

/* Die eigene Temp-Anlage läuft auch vor INVALID_PARAMETER. Drei Callerwerte
   und der frühe TABLE-Mappingfehler müssen den Sitzungskontext erhalten. */
DECLARE @CallerEntryLock int=@@LOCK_TIMEOUT,@CallerOptions int=@@OPTIONS,
        @CallerTranCount int=@@TRANCOUNT,@CallerOrdinal int=0,@CallerLock int,
        @CallerSql nvarchar(max);
WHILE @CallerOrdinal<3
BEGIN
    SET @CallerLock=CASE @CallerOrdinal WHEN 0 THEN 0 WHEN 1 THEN 137 ELSE -1 END;
    SET @CallerSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@CallerLock)+N';
DECLARE @Status varchar(40),@Json nvarchar(max),@Options int=@@OPTIONS,@TranCount int=@@TRANCOUNT;
EXEC [monitor].[USP_DiagnosticFindings]
     @MitIntegritaet=0,@MitKapazitaet=0,@MitSpeicher=0,@MitBackupketten=0,
     @MitAvailability=0,@MitAgentMonitoring=0,@ResultSetArt=''NONE'',
     @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT;
IF @Status IS NULL OR @Status<>''INVALID_PARAMETER'' OR ISNULL(ISJSON(@Json),0)<>1
   OR @@LOCK_TIMEOUT<>'+CONVERT(nvarchar(20),@CallerLock)+N'
   OR @@OPTIONS<>@Options OR @@TRANCOUNT<>@TranCount
    THROW 55208,N''FIND-CALLER: Eigene Temp-Anlage verändert den Callerzustand.'',1;
BEGIN TRY
    EXEC [monitor].[USP_DiagnosticFindings] @ResultSetArt=''TABLE'',@ResultTablesJson=N''invalid'';
    THROW 55209,N''FIND-CALLER: Ungültiges TABLE-Mapping wurde akzeptiert.'',1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()<>51011 THROW;
END CATCH;
IF @@LOCK_TIMEOUT<>'+CONVERT(nvarchar(20),@CallerLock)+N'
   OR @@OPTIONS<>@Options OR @@TRANCOUNT<>@TranCount
    THROW 55210,N''FIND-CALLER: Mappingfehler verändert den Callerzustand.'',1;
SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@CallerEntryLock)+N';';
    EXEC [sys].[sp_executesql] @CallerSql;
    INSERT @ExecutedCases VALUES
        (CASE @CallerOrdinal WHEN 0 THEN 'FIND-CALLER-NOWAIT'
                            WHEN 1 THEN 'FIND-CALLER-BOUNDED'
                            ELSE 'FIND-CALLER-UNBOUNDED' END);
    SET @CallerOrdinal+=1;
END;
IF @@LOCK_TIMEOUT<>@CallerEntryLock OR @@OPTIONS<>@CallerOptions OR @@TRANCOUNT<>@CallerTranCount
    THROW 55211,N'FIND-CALLER: Der Prüfblock verändert den Eingangskontext.',1;

IF (SELECT COUNT_BIG(*) FROM @ExecutedCases)<>9
    THROW 55205,N'Der P1-Findings-Vertrag hat nicht alle vorgesehenen Fälle ausgeführt.',1;

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],CAST(0 AS bit) AS [IsPartial],
       COUNT_BIG(*) AS [ExecutedCases],
       N'Neun P1-Findings-Fälle wurden einschließlich Parent-Reuse, Standalone-Frischlesung und vollständig rückgesetzten Kontexten geprüft.' AS [Detail]
FROM @ExecutedCases;
GO
