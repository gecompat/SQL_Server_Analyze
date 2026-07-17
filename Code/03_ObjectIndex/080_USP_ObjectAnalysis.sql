USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ObjectAnalysis
Version      : 2.1.0
Stand        : 2026-07-17
Typ          : Stored Procedure
Zweck        : Orchestriert die Objekt-, Index-, Statistik-, Partition-,
               Columnstore- und Physical-Stats-Analysen mit einem einheitlichen
               Listen-, Pattern- und Ausgabevertrag.
SQL-Version  : SQL Server 2019 oder neuer.
Parameter    : @DatabaseNames, @DatabaseNamePattern, @SchemaNames,
               @SchemaNamePattern, @ObjectNames, @ObjectNamePattern,
               @FullObjectNames, @IndexNames, @IndexNamePattern,
               @StatisticsNames, @StatisticsNamePattern, Modulschalter,
               @MaxDatenbanken, @MaxZeilen, @ResultSetArt,
               @JsonErzeugen, @Json OUTPUT, @PrintMeldungen, @Hilfe.
Semantik     : Exakte Listen sind bracket-aware Pipe-Listen; Pattern sind
               einzelne LIKE-/Regex-Ausdrücke. Exakte Liste und Pattern
               derselben Eigenschaft sind gegenseitig exklusiv.
Ausgabe      : Aktivierte Teilmodule liefern RAW oder CONSOLE. NONE unterdrückt
               fachliche Resultsets. JSON enthält die Teilmodul-Envelopes unter
               benannten Eigenschaften und einen Orchestratorstatus.
Änderungen   : 2.1.0 - Schema-/Designkorrektheit als opt-in Teilmodul.
               2.0.0 - Mehrfachfilter, getrennte Pattern, Cross-Database-Scope,
                         RAW/CONSOLE/NONE und JSON-Orchestrierung.
               1.3.0 - Vorheriger Stand.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_ObjectAnalysis]
      @DatabaseNames                    nvarchar(max)  = N''
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @SchemaNames                      nvarchar(max)  = NULL
    , @SchemaNamePattern                nvarchar(4000) = NULL
    , @ObjectNames                      nvarchar(max)  = NULL
    , @ObjectNamePattern                nvarchar(4000) = NULL
    , @FullObjectNames                  nvarchar(max)  = NULL
    , @IndexNames                       nvarchar(max)  = NULL
    , @IndexNamePattern                 nvarchar(4000) = NULL
    , @StatisticsNames                  nvarchar(max)  = NULL
    , @StatisticsNamePattern            nvarchar(4000) = NULL
    , @Vollanalyse                      bit            = 0
    , @MitObjectInventory               bit            = 1
    , @MitIndexUsage                    bit            = 1
    , @MitMissingIndexes                bit            = 1
    , @MitOperationalStats              bit            = 0
    , @MitStatistics                    bit            = 0
    , @MitPartitions                    bit            = 0
    , @MitColumnstore                   bit            = 0
    , @MitPhysicalStats                 bit            = 0
    , @MitSchemaDesign                  bit            = 0
    , @MaxDatenbanken                   int            = 16
    , @MaxZeilen                        int            = 2000
    , @LockTimeoutMs                    int            = 0
    , @ResultSetArt                     varchar(16)    = 'CONSOLE'
    , @JsonErzeugen                     bit            = 0
    , @Json                             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen                   bit            = 1
    , @Hilfe                            bit            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @AnalyseModus varchar(16) = CASE WHEN @Vollanalyse = 1 THEN 'VOLL' ELSE 'GEZIELT' END;
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @MonitorPrintMessage nvarchar(2048);

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_ObjectAnalysis';
        PRINT N'@DatabaseNames=N''[Db1]|[Db2]''; NULL=alle; @DatabaseNamePattern separat.';
        PRINT N'@SchemaNames/@ObjectNames/@IndexNames/@StatisticsNames sind bracket-aware Pipe-Listen.';
        PRINT N'@FullObjectNames unterstützt Objekt, Schema.Objekt oder Datenbank.Schema.Objekt.';
        PRINT N'Pattern unterstützen like:, regex:, regexi: und werden nicht an Pipe getrennt.';
        PRINT N'@Vollanalyse=0 nutzt GEZIELT; ressourcenintensive Teilmodule bleiben zusätzlich gruppengeschützt.';
        PRINT N'@ResultSetArt=CONSOLE (Default)|RAW|NONE (case-insensitiv); @JsonErzeugen=1 erzeugt benannte Teilmodule in @Json.';
        RETURN;
    END;

    CREATE TABLE [#ModuleStatus]
    (
          [ModuleName] sysname NOT NULL
        , [StatusCode] varchar(40) NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) NULL
    );

    IF @MaxDatenbanken < 0 OR @MaxZeilen < 0 OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @ResultSetArtNormalisiert NOT IN ('RAW','CONSOLE','NONE')
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültige Mengen-, Lock-Timeout- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND @FullObjectNames IS NOT NULL
       AND (@SchemaNames IS NOT NULL OR @ObjectNames IS NOT NULL OR @SchemaNamePattern IS NOT NULL OR @ObjectNamePattern IS NOT NULL)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@FullObjectNames ist zu separaten Schema-/Objektfiltern gegenseitig exklusiv.';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND ((@SchemaNames IS NOT NULL AND @SchemaNamePattern IS NOT NULL)
         OR (@ObjectNames IS NOT NULL AND @ObjectNamePattern IS NOT NULL)
         OR (@IndexNames IS NOT NULL AND @IndexNamePattern IS NOT NULL)
         OR (@StatisticsNames IS NOT NULL AND @StatisticsNamePattern IS NOT NULL))
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Exakte Liste und Pattern derselben Eigenschaft sind gegenseitig exklusiv.';
    END;

    DECLARE @JsonObjectInventory nvarchar(max) = NULL;
    DECLARE @JsonIndexUsage nvarchar(max) = NULL;
    DECLARE @JsonMissingIndexes nvarchar(max) = NULL;
    DECLARE @JsonOperationalStats nvarchar(max) = NULL;
    DECLARE @JsonStatistics nvarchar(max) = NULL;
    DECLARE @JsonPartitions nvarchar(max) = NULL;
    DECLARE @JsonColumnstore nvarchar(max) = NULL;
    DECLARE @JsonPhysicalStats nvarchar(max) = NULL;
    DECLARE @JsonSchemaDesign nvarchar(max) = NULL;
    DECLARE @SchemaDesignStatus varchar(40) = NULL;
    DECLARE @SchemaDesignPartial bit = NULL;
    DECLARE @SchemaDesignErrorNumber int = NULL;
    DECLARE @SchemaDesignErrorMessage nvarchar(2048) = NULL;

    IF @StatusCode = 'AVAILABLE' AND @MitObjectInventory = 1
    BEGIN TRY
        EXEC [monitor].[USP_ObjectInventory]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @AnalyseModus=@AnalyseModus,@MaxDatenbanken=@MaxDatenbanken,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonObjectInventory OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ModuleStatus] VALUES(N'USP_ObjectInventory',COALESCE(JSON_VALUE(@JsonObjectInventory,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ModuleStatus] VALUES(N'USP_ObjectInventory','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitIndexUsage = 1
    BEGIN TRY
        EXEC [monitor].[USP_IndexUsage]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @AnalyseModus=@AnalyseModus,@MaxDatenbanken=@MaxDatenbanken,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonIndexUsage OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ModuleStatus] VALUES(N'USP_IndexUsage',COALESCE(JSON_VALUE(@JsonIndexUsage,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ModuleStatus] VALUES(N'USP_IndexUsage','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitMissingIndexes = 1
    BEGIN TRY
        EXEC [monitor].[USP_MissingIndexes]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @MaxDatenbanken=@MaxDatenbanken,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonMissingIndexes OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ModuleStatus] VALUES(N'USP_MissingIndexes',COALESCE(JSON_VALUE(@JsonMissingIndexes,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ModuleStatus] VALUES(N'USP_MissingIndexes','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitOperationalStats = 1
    BEGIN TRY
        EXEC [monitor].[USP_IndexOperationalStats]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @IndexNames=@IndexNames,@IndexNamePattern=@IndexNamePattern,@AnalyseModus=@AnalyseModus
            , @MaxDatenbanken=@MaxDatenbanken,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonOperationalStats OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ModuleStatus] VALUES(N'USP_IndexOperationalStats',COALESCE(JSON_VALUE(@JsonOperationalStats,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ModuleStatus] VALUES(N'USP_IndexOperationalStats','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitStatistics = 1
    BEGIN TRY
        EXEC [monitor].[USP_Statistics]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @StatisticsNames=@StatisticsNames,@StatisticsNamePattern=@StatisticsNamePattern,@AnalyseModus=@AnalyseModus
            , @MaxDatenbanken=@MaxDatenbanken,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonStatistics OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ModuleStatus] VALUES(N'USP_Statistics',COALESCE(JSON_VALUE(@JsonStatistics,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ModuleStatus] VALUES(N'USP_Statistics','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitPartitions = 1
    BEGIN TRY
        EXEC [monitor].[USP_Partitions]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @AnalyseModus=@AnalyseModus,@MaxDatenbanken=@MaxDatenbanken,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonPartitions OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ModuleStatus] VALUES(N'USP_Partitions',COALESCE(JSON_VALUE(@JsonPartitions,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ModuleStatus] VALUES(N'USP_Partitions','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitColumnstore = 1
    BEGIN TRY
        EXEC [monitor].[USP_Columnstore]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @AnalyseModus=@AnalyseModus,@MaxDatenbanken=@MaxDatenbanken,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonColumnstore OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ModuleStatus] VALUES(N'USP_Columnstore',COALESCE(JSON_VALUE(@JsonColumnstore,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ModuleStatus] VALUES(N'USP_Columnstore','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitPhysicalStats = 1
    BEGIN TRY
        EXEC [monitor].[USP_IndexPhysicalStats]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern
            , @SchemaNames=@SchemaNames,@SchemaNamePattern=@SchemaNamePattern,@ObjectNames=@ObjectNames,@ObjectNamePattern=@ObjectNamePattern,@FullObjectNames=@FullObjectNames
            , @IndexNames=@IndexNames,@IndexNamePattern=@IndexNamePattern,@AnalyseModus=@AnalyseModus
            , @MaxDatenbanken=@MaxDatenbanken,@MaxZeilen=@MaxZeilen,@LockTimeoutMs=@LockTimeoutMs
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonPhysicalStats OUTPUT,@PrintMeldungen=@PrintMeldungen;
        INSERT [#ModuleStatus] VALUES(N'USP_IndexPhysicalStats',COALESCE(JSON_VALUE(@JsonPhysicalStats,'$.meta.statusCode'),'EXECUTED'),NULL,NULL);
    END TRY BEGIN CATCH INSERT [#ModuleStatus] VALUES(N'USP_IndexPhysicalStats','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF @StatusCode = 'AVAILABLE' AND @MitSchemaDesign = 1
    BEGIN TRY
        EXEC [monitor].[USP_SchemaDesignAnalysis]
              @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern
            , @MaxDatenbanken=@MaxDatenbanken,@MaxZeilen=@MaxZeilen
            , @ResultSetArt=@ResultSetArtNormalisiert,@JsonErzeugen=@JsonErzeugen,@Json=@JsonSchemaDesign OUTPUT,@PrintMeldungen=@PrintMeldungen
            , @StatusCodeOut=@SchemaDesignStatus OUTPUT,@IsPartialOut=@SchemaDesignPartial OUTPUT
            , @ErrorNumberOut=@SchemaDesignErrorNumber OUTPUT,@ErrorMessageOut=@SchemaDesignErrorMessage OUTPUT;
        INSERT [#ModuleStatus] VALUES(N'USP_SchemaDesignAnalysis',COALESCE(@SchemaDesignStatus,'ERROR_HANDLED'),@SchemaDesignErrorNumber,@SchemaDesignErrorMessage);
    END TRY BEGIN CATCH INSERT [#ModuleStatus] VALUES(N'USP_SchemaDesignAnalysis','ERROR_HANDLED',ERROR_NUMBER(),ERROR_MESSAGE()); SET @IsPartial=1; END CATCH;

    IF EXISTS(SELECT 1 FROM [#ModuleStatus]
              WHERE [StatusCode] NOT IN ('EXECUTED','AVAILABLE','AVAILABLE_WITH_FINDING','NOT_APPLICABLE'))
    BEGIN
        SET @StatusCode = 'PARTIAL_RESULT';
        SET @IsPartial = 1;
    END
    ELSE IF EXISTS(SELECT 1 FROM [#ModuleStatus] WHERE [StatusCode] = 'AVAILABLE_WITH_FINDING')
        SET @StatusCode = 'AVAILABLE_WITH_FINDING';

    IF @StatusCode <> 'AVAILABLE' AND @PrintMeldungen = 1
    BEGIN
        SET @MonitorPrintMessage = FORMATMESSAGE(N'WARNUNG USP_ObjectAnalysis %s: %s',@StatusCode,COALESCE(@ErrorMessage,N'Mindestens ein Teilmodul lieferte kein vollständiges Ergebnis.'));
        RAISERROR(N'%s',10,1,@MonitorPrintMessage) WITH NOWAIT;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @JsonMeta nvarchar(max)=(SELECT N'ObjectAnalysis' [resultName],1 [schemaVersion],@CollectionTimeUtc [generatedAtUtc],@StatusCode [statusCode],@IsPartial [isPartial],@ErrorMessage [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        DECLARE @JsonModuleStatus nvarchar(max)=(SELECT * FROM [#ModuleStatus] ORDER BY [ModuleName] FOR JSON PATH,INCLUDE_NULL_VALUES);
        SET @Json=CONCAT
        (
              N'{"meta":',COALESCE(@JsonMeta,N'{}')
            ,N',"moduleStatus":',COALESCE(@JsonModuleStatus,N'[]')
            ,N',"objectInventory":',COALESCE(@JsonObjectInventory,N'null')
            ,N',"indexUsage":',COALESCE(@JsonIndexUsage,N'null')
            ,N',"missingIndexes":',COALESCE(@JsonMissingIndexes,N'null')
            ,N',"indexOperationalStats":',COALESCE(@JsonOperationalStats,N'null')
            ,N',"statistics":',COALESCE(@JsonStatistics,N'null')
            ,N',"partitions":',COALESCE(@JsonPartitions,N'null')
            ,N',"columnstore":',COALESCE(@JsonColumnstore,N'null')
            ,N',"indexPhysicalStats":',COALESCE(@JsonPhysicalStats,N'null')
            ,N',"schemaDesign":',COALESCE(@JsonSchemaDesign,N'null')
            ,N'}'
        );
    END;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        IF @ResultSetArtNormalisiert = 'RAW'
            SELECT @CollectionTimeUtc [CollectionTimeUtc],N'monitor.USP_ObjectAnalysis' [ModuleName],@StatusCode [StatusCode],@IsPartial [IsPartial],@ErrorMessage [ErrorMessage];
        ELSE
            SELECT N'Objekt-/Indexanalyse' [Ergebnis],@CollectionTimeUtc [Stand_UTC],@StatusCode [Status],@IsPartial [Teilergebnis],@ErrorMessage [Hinweis];

        IF @ResultSetArtNormalisiert = 'RAW'
            SELECT * FROM [#ModuleStatus] ORDER BY [ModuleName];
        ELSE
            SELECT N'Teilmodulstatus' [Ergebnis],[ModuleName] [Modul],[StatusCode] [Status],[ErrorNumber] [Fehlernummer],[ErrorMessage] [Fehlermeldung] FROM [#ModuleStatus] ORDER BY [ModuleName];
    END;
END;
GO
