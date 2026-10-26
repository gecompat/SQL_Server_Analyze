USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_UpgradeFeatureUsageAnalysis
Version      : 1.0.0
Stand        : 2026-10-26
Zweck        : Zeigt native Deprecated-Begegnungszähler und eine begrenzte
               Zielversionsregel ohne Upgradefreigabe oder Datenbankattribution.
Grenze       : Begegnungen können Kompilierungen zählen; Null ist kein Nutzungsfrei-Beweis.
Nebenwirkung : Nur SQL-sichtbare Metadaten; keine Konfigurations- oder Hoständerung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_UpgradeFeatureUsageAnalysis]
      @TargetMajorVersion int = NULL
    , @MaxZeilen int = 1000
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Json=NULL,@StatusCodeOut='PARTIAL',@IsPartialOut=1,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_UpgradeFeatureUsageAnalysis';
        PRINT N'Instanzweite native Deprecated-Begegnungszähler; Kompilierungen können zählen. Kein Ausführungs-, Datenbank- oder Upgrade-ready-Urteil.';
        PRINT N'@TargetMajorVersion=NULL wählt keine Zielbewertung. Unterstützte Ziele: 15,16,17 ab tatsächlicher Sourceversion.';
        PRINT N'Eine begrenzte Regel beschreibt lightweight pooling ab Ziel17; weitere deprecated/discontinued/breaking Features bleiben getrennt offen.';
        PRINT N'CONSOLE|RAW|TABLE|NONE; vier Ergebnisse: context, deprecatedUsage, configuration, sources. JSON ist optionaler OUTPUT.';
        PRINT N'@MaxZeilen=1..100000 begrenzt erst die Ausgabe; keine Callertransaktion und IMPLICIT_TRANSACTIONS OFF.';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;
    DECLARE @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
            @Major int,@Build nvarchar(128),@PreviousLock int=@@LOCK_TIMEOUT,
            @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)<>0 THEN 1 ELSE 0 END,
            @RestoreLock nvarchar(100),@TechnicalError int,@TableStatus varchar(40),@TableMessage nvarchar(2048),
            @TableError int,@Status varchar(40),@Error int,@Message nvarchar(2048),
            @Collected datetime2(3),@Start datetime2(3),@End datetime2(3),@Confirmed bit=0,
            @StartLocal datetime,@StartTicks bigint,@AfterLocal datetime,@AfterTicks bigint,
            @Phase smallint=1,@Ordinal smallint,@Observed bigint,@NativeRows bigint,@Returned bigint,@Limited bit;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0 OR @Mode NOT IN('CONSOLE','RAW','TABLE','NONE')
       OR @MaxZeilen IS NULL OR @MaxZeilen NOT BETWEEN 1 AND 100000
       OR (@TargetMajorVersion IS NOT NULL AND @TargetMajorVersion NOT IN(15,16,17))
       OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL OR @Hilfe IS NULL
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
          @ErrorMessageOut=N'Ungültige Ziel-, Ausgabe- oder Limitparameter beziehungsweise unsicherer Callertransaktionszustand.';
        RETURN 51011;
    END;
    SELECT @Major=TRY_CONVERT(int,SERVERPROPERTY('ProductMajorVersion')),@Build=CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion'));
    IF @Major IN(15,16,17) AND @TargetMajorVersion<@Major
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
          @ErrorMessageOut=N'Die Zielmajor darf nicht unter der tatsächlichen unterstützten Sourceversion liegen.';
        RETURN 51011;
    END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLock)+N';';
    BEGIN TRY
        SET XACT_ABORT OFF;
        SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#UpgradeFeatureUsageAnalysis_context]
        ([CollectionTimeUtc] datetime2(3) NOT NULL,[SourceMajorVersion] int NULL,[SourceBuild] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
         [TargetMajorVersion] int NULL,[SqlServerStartTimeLocal] datetime NULL,[SqlServerStartTimeMsTicks] bigint NULL,[EngineContextConfirmed] bit NOT NULL,
         [MeasurementStartUtc] datetime2(3) NULL,[MeasurementEndUtc] datetime2(3) NULL,
         [CounterReadState] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeCounterRows] bigint NULL,[ReturnedCounterRows] bigint NOT NULL,
         [OutputLimited] bit NOT NULL,[AssessmentCoverage] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         [RuleCatalogVersion] int NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL);
        CREATE TABLE [#UpgradeFeatureUsageAnalysis_deprecatedUsage]
        ([ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         [FeatureName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeCounterType] int NOT NULL,[NativeCounterValue] bigint NOT NULL,
         [ObservationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetAssessment] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        CREATE TABLE [#UpgradeFeatureUsageAnalysis_configuration]
        ([ConfigurationName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ConfiguredValue] int NULL,[ValueInUse] int NULL,[IsDynamic] bit NULL,
         [TargetMajorVersion] int NULL,[RuleCode] varchar(96) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RuleCatalogVersion] int NOT NULL,
         [AssessmentStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceReference] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        CREATE TABLE [#UpgradeFeatureUsageAnalysis_sources]
        ([SourceOrdinal] smallint NOT NULL PRIMARY KEY,[SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeReadState] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         [NativeRows] bigint NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
         [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        CREATE TABLE [#UpgradeFeatureUsageAnalysis_Map]
        ([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        CREATE TABLE [#UpgradeFeatureUsageAnalysis_CounterCache]
        ([ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
         [FeatureName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeCounterType] int NOT NULL,[NativeCounterValue] bigint NOT NULL);
        CREATE TABLE [#UpgradeFeatureUsageAnalysis_ConfigCache]
        ([ConfigurationName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ConfiguredRaw] sql_variant NULL,[InUseRaw] sql_variant NULL,[IsDynamic] bit NULL);
        DECLARE @Engine TABLE([Phase] smallint NOT NULL,[StartLocal] datetime NULL,[StartTicks] bigint NULL);
        SET LOCK_TIMEOUT 0;
        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
              @AllowedResultNames=N'context|deprecatedUsage|configuration|sources',@MappingTable=N'#UpgradeFeatureUsageAnalysis_Map',
              @StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SET @TechnicalError=51011;
                RAISERROR(N'%s',16,1,@TableMessage);
            END;
        END;
        INSERT [#UpgradeFeatureUsageAnalysis_sources] VALUES
          (1,N'sys.dm_os_sys_info:before','UNAVAILABLE_OBJECT','NOT_STARTED',NULL,NULL,NULL,N'Lokale native Engine-Startzeit und Startticks vor dem Counterread; kein UTC-Startmarker.'),
          (2,N'sys.dm_os_performance_counters:deprecated','UNAVAILABLE_OBJECT','NOT_STARTED',NULL,NULL,NULL,N'Instanzweite Enginebegegnungen; Kompilierungen können zählen. Keine Datenbank-, Ausführungs-, Dauer- oder Upgradefreigabe.'),
          (3,N'sys.dm_os_sys_info:after','UNAVAILABLE_OBJECT','NOT_STARTED',NULL,NULL,NULL,N'Unabhängige Enginebeobachtung nach dem Counterread; gleiche Werte beweisen keine Resetkontinuität.'),
          (4,N'sys.configurations:lightweight_pooling','UNAVAILABLE_OBJECT','NOT_STARTED',NULL,NULL,NULL,N'Eine beobachtete Option und eine begrenzte Zielversionsregel; keine vollständige deprecated/discontinued/breaking Prüfung.');
        SET @Start=SYSUTCDATETIME();
        IF @Major IS NULL OR @Major NOT IN(15,16,17)
            UPDATE [#UpgradeFeatureUsageAnalysis_sources]
              SET [ErrorMessage]=N'Die tatsächliche Source-Major ist nicht als unterstützter SQL Server 2019/2022/2025 beobachtet.';
        ELSE
        BEGIN
            WHILE @Phase<=2
            BEGIN
                SET @Ordinal=CASE WHEN @Phase=1 THEN 1 ELSE 3 END;
                BEGIN TRY
                    INSERT @Engine([Phase],[StartLocal],[StartTicks])
                    SELECT @Phase,[sqlserver_start_time],[sqlserver_start_time_ms_ticks]
                    FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
                    SELECT @Observed=COUNT_BIG(*) FROM @Engine WHERE [Phase]=@Phase;
                    UPDATE [#UpgradeFeatureUsageAnalysis_sources]
                    SET [NativeReadState]='SUCCEEDED',[NativeRows]=@Observed,
                      [StatusCode]=CASE WHEN @Observed=1 AND NOT EXISTS(SELECT 1 FROM @Engine WHERE [Phase]=@Phase
                         AND ([StartLocal] IS NULL OR [StartTicks] IS NULL OR [StartTicks]<0)) THEN 'AVAILABLE' ELSE 'ERROR_HANDLED' END,
                      [ErrorMessage]=CASE WHEN @Observed<>1 OR EXISTS(SELECT 1 FROM @Engine WHERE [Phase]=@Phase
                         AND ([StartLocal] IS NULL OR [StartTicks] IS NULL OR [StartTicks]<0))
                         THEN N'Der erfolgreiche Engine-Read liefert keine eindeutige vollständige native Startbeobachtung.' END
                    WHERE [SourceOrdinal]=@Ordinal;
                END TRY
                BEGIN CATCH
                    UPDATE [#UpgradeFeatureUsageAnalysis_sources]
                    SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER() IN(207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,
                      [NativeReadState]='FAILED',[NativeRows]=NULL,[ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=CONVERT(nvarchar(2048),ERROR_MESSAGE())
                    WHERE [SourceOrdinal]=@Ordinal;
                END CATCH;
                IF @Phase=1
                BEGIN TRY
                    -- One complete scoped native cache; the output limit is applied afterwards.
                    INSERT [#UpgradeFeatureUsageAnalysis_CounterCache]
                      ([ObjectName],[CounterName],[FeatureName],[NativeCounterType],[NativeCounterValue])
                    SELECT [object_name],[counter_name],[instance_name],[cntr_type],[cntr_value]
                    FROM [sys].[dm_os_performance_counters] WITH (NOLOCK)
                    WHERE [object_name] COLLATE SQL_Latin1_General_CP1_CS_AS LIKE N'%SQL%Deprecated Features%'
                      AND RTRIM([counter_name]) COLLATE Latin1_General_100_BIN2=N'Usage';
                    SELECT @Observed=COUNT_BIG(*) FROM [#UpgradeFeatureUsageAnalysis_CounterCache];
                    UPDATE [#UpgradeFeatureUsageAnalysis_sources]
                    SET [StatusCode]=CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE' END,
                      [NativeReadState]='SUCCEEDED',[NativeRows]=@Observed
                    WHERE [SourceOrdinal]=2;
                END TRY
                BEGIN CATCH
                    UPDATE [#UpgradeFeatureUsageAnalysis_sources]
                    SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER() IN(207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,
                      [NativeReadState]='FAILED',[NativeRows]=NULL,[ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=CONVERT(nvarchar(2048),ERROR_MESSAGE())
                    WHERE [SourceOrdinal]=2;
                END CATCH;
                SET @Phase+=1;
            END;
            BEGIN TRY
                INSERT [#UpgradeFeatureUsageAnalysis_ConfigCache]([ConfigurationName],[ConfiguredRaw],[InUseRaw],[IsDynamic])
                SELECT [name],[value],[value_in_use],[is_dynamic] FROM [sys].[configurations] WITH (NOLOCK)
                WHERE CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),N'lightweight pooling');
                SELECT @Observed=COUNT_BIG(*) FROM [#UpgradeFeatureUsageAnalysis_ConfigCache];
                UPDATE [#UpgradeFeatureUsageAnalysis_sources]
                SET [StatusCode]=CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' WHEN @Observed=1 THEN 'AVAILABLE' ELSE 'ERROR_HANDLED' END,
                  [NativeReadState]='SUCCEEDED',[NativeRows]=@Observed,
                  [ErrorMessage]=CASE WHEN @Observed>1 THEN N'Der erfolgreiche Optionsread liefert keine eindeutige Konfiguration.' END
                WHERE [SourceOrdinal]=4;
            END TRY
            BEGIN CATCH
                UPDATE [#UpgradeFeatureUsageAnalysis_sources]
                SET [StatusCode]=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371,916) THEN 'DENIED_PERMISSION'
                  WHEN ERROR_NUMBER() IN(207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,
                  [NativeReadState]='FAILED',[NativeRows]=NULL,[ErrorNumber]=ERROR_NUMBER(),[ErrorMessage]=CONVERT(nvarchar(2048),ERROR_MESSAGE())
                WHERE [SourceOrdinal]=4;
            END CATCH;
        END;
        SELECT @End=SYSUTCDATETIME(),@Collected=SYSUTCDATETIME();
        IF NOT EXISTS(SELECT 1 FROM [#UpgradeFeatureUsageAnalysis_sources] WHERE [SourceOrdinal] IN(1,3) AND [StatusCode]<>'AVAILABLE')
        BEGIN
            SELECT @StartLocal=[StartLocal],@StartTicks=[StartTicks] FROM @Engine WHERE [Phase]=1;
            SELECT @AfterLocal=[StartLocal],@AfterTicks=[StartTicks] FROM @Engine WHERE [Phase]=2;
            IF @StartLocal=@AfterLocal AND @StartTicks=@AfterTicks AND @Start<=@End SET @Confirmed=1;
        END;
        IF @Confirmed=0
        BEGIN
            SELECT @StartLocal=NULL,@StartTicks=NULL;
            UPDATE [#UpgradeFeatureUsageAnalysis_sources] SET [StatusCode]='ERROR_HANDLED',
              [ErrorMessage]=N'Die vorher/nachher beobachtete Engine- und Zeitbindung bestätigt keinen gemeinsamen Counterstartkontext.'
            WHERE [SourceOrdinal]=3 AND [NativeReadState]='SUCCEEDED' AND [StatusCode]='AVAILABLE' AND [ErrorNumber] IS NULL;
        END;
        IF @Start>@End SELECT @Start=NULL,@End=NULL;
        INSERT [#UpgradeFeatureUsageAnalysis_deprecatedUsage]
          ([ObjectName],[CounterName],[FeatureName],[NativeCounterType],[NativeCounterValue],[ObservationStatus],[TargetAssessment],[EvidenceLimit])
        SELECT TOP(@MaxZeilen) [ObjectName],[CounterName],[FeatureName],[NativeCounterType],[NativeCounterValue],
          CASE WHEN @Confirmed=0 THEN 'ENGINE_CONTEXT_UNBOUND' WHEN [NativeCounterValue]<0 THEN 'INVALID_NATIVE_VALUE'
            WHEN [NativeCounterValue]=0 THEN 'OBSERVED_ZERO' ELSE 'OBSERVED_POSITIVE' END,
          CASE WHEN @TargetMajorVersion IS NULL THEN 'TARGET_NOT_SELECTED' ELSE 'UNMAPPED_SOURCE_FEATURE' END,
          N'Nativer Deprecated-Usage-Rohwert; Begegnungen können Kompilierungen zählen. Kein Ausführungs-, Datenbank-, Raten- oder Upgrade-ready-Urteil; Null beweist keine Nichtverwendung.'
        FROM [#UpgradeFeatureUsageAnalysis_CounterCache]
        ORDER BY [FeatureName] COLLATE Latin1_General_100_BIN2,[ObjectName] COLLATE Latin1_General_100_BIN2,[CounterName] COLLATE Latin1_General_100_BIN2,
          [NativeCounterType],[NativeCounterValue];
        INSERT [#UpgradeFeatureUsageAnalysis_configuration]
          ([ConfigurationName],[ConfiguredValue],[ValueInUse],[IsDynamic],[TargetMajorVersion],[RuleCode],[RuleCatalogVersion],[AssessmentStatus],[SourceReference],[EvidenceLimit])
        SELECT [ConfigurationName],CASE WHEN CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY([ConfiguredRaw],'BaseType'))=N'int' THEN TRY_CONVERT(int,[ConfiguredRaw]) END,
          CASE WHEN CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY([InUseRaw],'BaseType'))=N'int' THEN TRY_CONVERT(int,[InUseRaw]) END,
          [IsDynamic],@TargetMajorVersion,'DEPRECATED_LIGHTWEIGHT_POOLING_17',1,
          CASE WHEN CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY([ConfiguredRaw],'BaseType'))<>N'int'
                 OR CONVERT(nvarchar(128),SQL_VARIANT_PROPERTY([InUseRaw],'BaseType'))<>N'int'
                 OR [ConfiguredRaw] IS NULL OR [InUseRaw] IS NULL OR [IsDynamic] IS NULL
                 OR TRY_CONVERT(int,[ConfiguredRaw]) NOT IN(0,1) OR TRY_CONVERT(int,[InUseRaw]) NOT IN(0,1)
                 OR (SELECT [NativeRows] FROM [#UpgradeFeatureUsageAnalysis_sources] WHERE [SourceOrdinal]=4)<>1 THEN 'INVALID_NATIVE_VALUE'
            WHEN @TargetMajorVersion IS NULL THEN 'TARGET_NOT_SELECTED'
            WHEN @TargetMajorVersion IN(15,16) THEN 'NOT_IN_SELECTED_RULE_SCOPE'
            WHEN TRY_CONVERT(int,[InUseRaw])=1 THEN 'CONFIGURED_DEPRECATED_AT_TARGET'
            WHEN TRY_CONVERT(int,[ConfiguredRaw])=1 THEN 'PENDING_DEPRECATED_CONFIGURATION'
            ELSE 'NOT_CONFIGURED_IN_OBSERVATION' END,
          N'https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/lightweight-pooling-server-configuration-option?view=sql-server-ver17',
          N'Katalogversion1, geprüft2026-10-26: eine ab Zielmajor17 veraltete Option. Konfiguration und wirksamer Wert bleiben getrennt. Keine vollständige Feature- oder Upgradeprüfung.'
        FROM [#UpgradeFeatureUsageAnalysis_ConfigCache];
        IF EXISTS(SELECT 1 FROM [#UpgradeFeatureUsageAnalysis_configuration] WHERE [AssessmentStatus]='INVALID_NATIVE_VALUE')
            UPDATE [#UpgradeFeatureUsageAnalysis_sources] SET [StatusCode]='ERROR_HANDLED',
              [ErrorMessage]=N'Die tatsächlich beobachtete Option besitzt keine eindeutigen nativen booleschen Konfigurationswerte.'
            WHERE [SourceOrdinal]=4 AND [ErrorNumber] IS NULL;
        SELECT @NativeRows=[NativeRows] FROM [#UpgradeFeatureUsageAnalysis_sources] WHERE [SourceOrdinal]=2;
        SELECT @Returned=COUNT_BIG(*) FROM [#UpgradeFeatureUsageAnalysis_deprecatedUsage];
        SET @Limited=CASE WHEN @NativeRows>@Returned THEN 1 ELSE 0 END;
        SET @Status=CASE WHEN @Major IS NULL OR @Major NOT IN(15,16,17) THEN 'UNAVAILABLE_OBJECT'
          WHEN EXISTS(SELECT 1 FROM [#UpgradeFeatureUsageAnalysis_CounterCache]) OR EXISTS(SELECT 1 FROM [#UpgradeFeatureUsageAnalysis_ConfigCache]) THEN 'PARTIAL'
          WHEN EXISTS(SELECT 1 FROM [#UpgradeFeatureUsageAnalysis_sources] WHERE [ErrorNumber] IS NOT NULL)
            THEN CASE WHEN NOT EXISTS(SELECT 1 FROM [#UpgradeFeatureUsageAnalysis_sources] WHERE [ErrorNumber] IS NOT NULL
                             AND [ErrorNumber] NOT IN(229,262,297,300,371,916)) THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END
          WHEN EXISTS(SELECT 1 FROM [#UpgradeFeatureUsageAnalysis_sources] WHERE [StatusCode]='ERROR_HANDLED') THEN 'ERROR_HANDLED'
          ELSE 'EMPTY_UNPROVEN' END;
        SELECT TOP(1) @Error=[ErrorNumber],@Message=[ErrorMessage] FROM [#UpgradeFeatureUsageAnalysis_sources]
          WHERE [ErrorNumber] IS NOT NULL ORDER BY [SourceOrdinal];
        IF @Error IS NULL
            SELECT TOP(1) @Message=[ErrorMessage] FROM [#UpgradeFeatureUsageAnalysis_sources]
              WHERE [ErrorMessage] IS NOT NULL ORDER BY [SourceOrdinal];
        INSERT [#UpgradeFeatureUsageAnalysis_context]
          ([CollectionTimeUtc],[SourceMajorVersion],[SourceBuild],[TargetMajorVersion],[SqlServerStartTimeLocal],[SqlServerStartTimeMsTicks],[EngineContextConfirmed],
           [MeasurementStartUtc],[MeasurementEndUtc],[CounterReadState],[NativeCounterRows],[ReturnedCounterRows],[OutputLimited],[AssessmentCoverage],[RuleCatalogVersion],[StatusCode],[IsPartial])
        SELECT @Collected,@Major,@Build,@TargetMajorVersion,@StartLocal,@StartTicks,@Confirmed,@Start,@End,[NativeReadState],@NativeRows,@Returned,@Limited,
          'LIMITED_OBSERVATION',1,@Status,1 FROM [#UpgradeFeatureUsageAnalysis_sources] WHERE [SourceOrdinal]=2;
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'UpgradeFeatureUsageAnalysis' AS [resultName],1 AS [schemaVersion],@Collected AS [generatedAtUtc],
              @Status AS [statusCode],CONVERT(bit,1) AS [isPartial],@Error AS [errorNumber],@Message AS [errorMessage]
              FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES),
              @ContextJson nvarchar(max)=(SELECT * FROM [#UpgradeFeatureUsageAnalysis_context] FOR JSON PATH,INCLUDE_NULL_VALUES),
              @UsageJson nvarchar(max)=(SELECT * FROM [#UpgradeFeatureUsageAnalysis_deprecatedUsage]
                ORDER BY [FeatureName] COLLATE Latin1_General_100_BIN2,[ObjectName] COLLATE Latin1_General_100_BIN2,[CounterName] COLLATE Latin1_General_100_BIN2,
                  [NativeCounterType],[NativeCounterValue] FOR JSON PATH,INCLUDE_NULL_VALUES),
              @ConfigJson nvarchar(max)=(SELECT * FROM [#UpgradeFeatureUsageAnalysis_configuration] ORDER BY [ConfigurationName] COLLATE Latin1_General_100_BIN2 FOR JSON PATH,INCLUDE_NULL_VALUES),
              @SourcesJson nvarchar(max)=(SELECT * FROM [#UpgradeFeatureUsageAnalysis_sources] ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"context":',COALESCE(@ContextJson,N'[]'),N',"deprecatedUsage":',COALESCE(@UsageJson,N'[]'),
              N',"configuration":',COALESCE(@ConfigJson,N'[]'),N',"sources":',COALESCE(@SourcesJson,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#UpgradeFeatureUsageAnalysis_context];
            SELECT * FROM [#UpgradeFeatureUsageAnalysis_deprecatedUsage]
              ORDER BY [FeatureName] COLLATE Latin1_General_100_BIN2,[ObjectName] COLLATE Latin1_General_100_BIN2,[CounterName] COLLATE Latin1_General_100_BIN2,
                [NativeCounterType],[NativeCounterValue];
            SELECT * FROM [#UpgradeFeatureUsageAnalysis_configuration] ORDER BY [ConfigurationName] COLLATE Latin1_General_100_BIN2;
            SELECT * FROM [#UpgradeFeatureUsageAnalysis_sources] ORDER BY [SourceOrdinal];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [UpgradeFeatureUsageOutput] CURSOR LOCAL FAST_FORWARD FOR
              SELECT [ResultName],[TargetTable] FROM [#UpgradeFeatureUsageAnalysis_Map] ORDER BY [ResultName];
            OPEN [UpgradeFeatureUsageOutput];
            FETCH NEXT FROM [UpgradeFeatureUsageOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#UpgradeFeatureUsageAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                  @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @TechnicalError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [UpgradeFeatureUsageOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [UpgradeFeatureUsageOutput]; DEALLOCATE [UpgradeFeatureUsageOutput];
        END
        ELSE IF @Mode='CONSOLE'
        BEGIN
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#UpgradeFeatureUsageAnalysis_context',
              @ResultLabel=N'Begrenzte Upgradebeobachtung',@EmptyMessage=N'Kein bestätigter Kontext; Quellenstatus beachten.';
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#UpgradeFeatureUsageAnalysis_deprecatedUsage',
              @ResultLabel=N'Native Deprecated-Begegnungszähler',@EmptyMessage=N'Keine beobachteten Usage-Counter; kein Nichtverwendungsnachweis.';
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#UpgradeFeatureUsageAnalysis_configuration',
              @ResultLabel=N'Begrenzte Konfigurationsregel',@EmptyMessage=N'Keine beobachtete Optionszeile; kein Nullwert wird behauptet.';
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#UpgradeFeatureUsageAnalysis_sources',
              @ResultLabel=N'Quellen und Aussagegrenzen',@EmptyMessage=N'Quellenstatus nicht verfügbar.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_UpgradeFeatureUsageAnalysis: mindestens eine Quelle ist nicht vollständig verfügbar; sources und OUTPUT beachten.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        RETURN 0;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN @TechnicalError=51011 THEN 'INVALID_PARAMETER' ELSE 'ERROR_HANDLED' END,
          @IsPartialOut=1,@ErrorNumberOut=COALESCE(@TechnicalError,ERROR_NUMBER()),@ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE()),@Json=NULL;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN @ErrorNumberOut;
    END CATCH;
END;
GO
