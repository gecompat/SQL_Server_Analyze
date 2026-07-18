USE [DeineDatenbank];
GO

/*
===============================================================================
Datei        : 178_P1_Diagnostic_Findings_Runtime_Contract.sql
Zweck        : Laufzeitverträge für vier P1-Findings-Fälle.
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
    (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID());
DECLARE @DatabaseName sysname=DB_NAME();
DECLARE @AlterCompatibilitySql nvarchar(max);
DECLARE @Impersonating bit=0;

/* FIND-CORE und FIND-OPTOUT: ein Kernmodul, optionale teure Module bleiben per Default aus. */
EXEC [monitor].[USP_DiagnosticFindings]
     @DatabaseNames=N'[DeineDatenbank]',
     @MitIntegritaet=0,@MitKapazitaet=0,@MitSpeicher=0,@MitBackupketten=0,
     @MitAvailability=0,@MitAgentMonitoring=1,
     @MaxDatenbanken=1,@MaxZeilen=100,@ResultSetArt='NONE',
     @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
     @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
     @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;

IF ISJSON(@Json)<>1 OR @Status NOT IN('AVAILABLE_WITH_FINDING','AVAILABLE_LIMITED')
   OR COALESCE(TRY_CONVERT(int,JSON_VALUE(@Json,N'$.meta.totalFindingCount')),0)<1
   OR NOT EXISTS
      (
          SELECT 1
          FROM OPENJSON(@Json,N'$.modules')
          WITH ([ModuleName] sysname N'$.ModuleName',[InvocationStatus] varchar(40) N'$.InvocationStatus')
          WHERE [ModuleName]=N'USP_AgentMonitoringAnalysis' AND [InvocationStatus]='EXECUTED'
      )
   OR EXISTS
      (
          SELECT 1
          FROM OPENJSON(@Json,N'$.findings') AS [f]
          CROSS APPLY OPENJSON([f].[value]) AS [p]
          WHERE [p].[key] NOT IN
          (
              N'FindingOrdinal',N'SourceModule',N'Category',N'Severity',N'Confidence',N'ScopeType',
              N'ScopeName',N'FindingCode',N'EvidenceMetric',N'Evidence',N'EvidenceLimit',N'RecommendedNextCheck'
          )
      )
    THROW 55200,N'P1-Vertrag FIND-CORE fehlgeschlagen.',1;
INSERT @ExecutedCases VALUES('FIND-CORE');

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

/* FIND-PARTIAL: eingeschränkter User verliert eine Child-Quelle, andere Child-Status bleiben erhalten. */
IF USER_ID(N'ExampleDiagnosticFindingsRestrictedUser') IS NOT NULL
    THROW 55202,N'Der synthetische Principal für FIND-PARTIAL ist bereits vorhanden.',1;

BEGIN TRANSACTION;
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
         @MaxDatenbanken=1,@MaxZeilen=100,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
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

    ROLLBACK TRANSACTION;
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
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
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
         @MaxDatenbanken=1,@MaxZeilen=10,@ResultSetArt='NONE',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,
         @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,
         @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;

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
        IF (SELECT [compatibility_level] FROM [sys].[databases] WHERE [database_id]=DB_ID())<>@OriginalCompatibilityLevel
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

IF (SELECT COUNT_BIG(*) FROM @ExecutedCases)<>4
    THROW 55205,N'Der P1-Findings-Vertrag hat nicht alle vorgesehenen Fälle ausgeführt.',1;

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],CAST(0 AS bit) AS [IsPartial],
       COUNT_BIG(*) AS [ExecutedCases],
       N'Vier P1-Findings-Fälle wurden mit Feld-Whitelist und vollständig rückgesetzten Kontexten geprüft.' AS [Detail]
FROM @ExecutedCases;
GO
