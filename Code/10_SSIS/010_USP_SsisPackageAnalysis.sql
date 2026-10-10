USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_SsisPackageAnalysis
Version      : 1.0.1
Stand        : 2026-10-10
Typ          : Stored Procedure
Zweck        : Inventarisiert ein direkt übergebenes DTSX-v2-Paket statisch.
Datenquelle  : Ausschließlich @PackageXml; keine Datei-, ISPAC-, SSISDB-,
               Datenbank- oder externe Verbindungsquelle wird geöffnet.
Datenschutz  : Keine Connection Strings, Secret-, Binary-, Host-, Login- oder
               vollständigen Pfadwerte werden gelesen oder ausgegeben.
Abgrenzung   : Dieser erste Slice stabilisiert Paket-, Executable- und direkte
               Parent-Container-Inventare.
               Data-Flow, Parameter, Expressions, Lineage und Regeln bleiben
               als leere, ausdrücklich begrenzte Resultsets sichtbar.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_SsisPackageAnalysis]
      @PackageXml             xml            = NULL
    , @PackageParametersJson  nvarchar(max)  = NULL
    , @AnalysisDepth          varchar(16)    = 'STANDARD'
    , @ResolveSqlMetadata     bit            = 0
    , @CheckLookupData        bit            = 0
    , @HighImpactConfirmed    bit            = 0
    , @MaxZeilen              int            = 1000
    , @MaxDurationSeconds     int            = 30
    , @LockTimeoutMs          int            = 0
    , @ResultSetArt           varchar(16)    = 'CONSOLE'
    , @ResultTablesJson       nvarchar(max)  = NULL
    , @JsonErzeugen           bit            = 0
    , @Json                   nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen         bit            = 1
    , @Hilfe                  bit            = 0
    , @StatusCodeOut          varchar(40)    = NULL OUTPUT
    , @IsPartialOut           bit            = NULL OUTPUT
    , @ErrorNumberOut         int            = NULL OUTPUT
    , @ErrorMessageOut        nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @Json = NULL;

    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @LockTimeoutSql nvarchar(64);
    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,''))));
    DECLARE @TableRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN 9223372036854775807 ELSE @MaxZeilen END;
    DECLARE @StatusCode varchar(40) = 'AVAILABLE_LIMITED';
    DECLARE @IsPartial bit = 1;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @PackageFormatVersion int = NULL;
    DECLARE @PackageName nvarchar(256) = NULL;
    DECLARE @PackageType nvarchar(256) = NULL;
    DECLARE @ProtectionLevel nvarchar(64) = NULL;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_SsisPackageAnalysis';
        PRINT N'Analysiert ausschließlich direkt übergebenes DTSX-v2-XML. Der Aufruf öffnet weder Dateien noch SSISDB, führt keine Pakete und kein Paket-SQL aus.';
        PRINT N'Der erste Parser-Slice inventarisiert Paket, Executables und direkte Parent-Container. Data Flow, Constraints, Parameter, Expressions, Lineage und Regelengine werden als begrenzte Resultsets ausgegeben.';
        PRINT N'@ResultSetArt=CONSOLE|RAW|TABLE|NONE; TABLE verwendet eine benannte Zuordnung für jedes Resultset.';
        RETURN;
    END;

    CREATE TABLE [#SsisPackageAnalysis_ResultTables]
    (
          [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    IF @TableRequested = 1
        EXEC [monitor].[InternalPrepareResultTables]
              @ResultTablesJson = @ResultTablesJson
            , @AllowedResultNames = N'moduleStatus|package|executables|dataFlowComponents|connections|parameters|expressions|lineage|findings|sourceStatus|warnings'
            , @MappingTable = N'#SsisPackageAnalysis_ResultTables'
            , @ThrowOnError = 1;

    CREATE TABLE [#SsisPackageAnalysis_ModuleStatus]
    (
          [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CollectionTimeUtc] datetime2(3) NOT NULL
        , [SchemaVersion] int NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [PackageCount] int NOT NULL
        , [ExecutableCount] int NOT NULL
        , [FindingCount] int NOT NULL
        , [ErrorNumber] int NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_Package]
    (
          [PackageName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PackageFormatVersion] int NULL
        , [RootExecutableType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ProtectionLevel] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecutableCount] int NOT NULL
        , [AnalysisStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_Executables]
    (
          [ExecutableOrdinal] int NOT NULL
        , [ParentExecutableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecutableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecutableType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CreationName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsPackageRoot] bit NOT NULL
        , [IsDisabled] bit NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([ExecutableOrdinal])
    );
    CREATE TABLE [#SsisPackageAnalysis_DataFlowComponents]
    (
          [ComponentOrdinal] int NOT NULL
        , [ComponentName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ComponentKind] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_Connections]
    (
          [ConnectionOrdinal] int NOT NULL
        , [ConnectionName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ConnectionKind] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_Parameters]
    (
          [ParameterOrdinal] int NOT NULL
        , [ParameterScope] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ParameterName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_Expressions]
    (
          [ExpressionOrdinal] int NOT NULL
        , [ExpressionScope] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PropertyName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_Lineage]
    (
          [LineageOrdinal] int NOT NULL
        , [SourceComponent] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [TargetComponent] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_Findings]
    (
          [RuleId] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Severity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLevel] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Finding] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_SourceStatus]
    (
          [SourceName] nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsPartial] bit NOT NULL
        , [ReturnedRowCount] bigint NULL
        , [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_Warnings]
    (
          [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [WarningSeverity] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    IF @PackageXml IS NULL
       OR @AnalysisDepth IS NULL OR UPPER(LTRIM(RTRIM(@AnalysisDepth))) <> 'STANDARD'
       OR @ResolveSqlMetadata IS NULL OR @ResolveSqlMetadata <> 0
       OR @CheckLookupData IS NULL OR @CheckLookupData <> 0
       OR @HighImpactConfirmed IS NULL
       OR @JsonErzeugen IS NULL OR @PrintMeldungen IS NULL
       OR @MaxZeilen IS NOT NULL AND @MaxZeilen < 0
       OR @MaxDurationSeconds NOT BETWEEN 1 AND 60
       OR @LockTimeoutMs NOT BETWEEN 0 AND 60000
       OR @OutputMode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR (@TableRequested = 0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER', @IsPartial = 1,
               @ErrorMessage = N'Ungültiger Paket-, Analyse-, Limit-, Lock-Timeout- oder Ausgabeparameter. SQL-Metadaten- und Lookupprüfungen gehören nicht zu diesem Parser-Slice.';
    END;

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;

    IF @StatusCode = 'AVAILABLE_LIMITED'
       AND @PackageXml.exist('/*[local-name(.)="Executable" and namespace-uri(.)="www.microsoft.com/SqlServer/Dts"]') = 0
    BEGIN
        SELECT @StatusCode = 'UNSUPPORTED_PACKAGE_FORMAT', @IsPartial = 1,
               @ErrorMessage = N'Das Dokument besitzt kein unterstütztes DTSX-v2-Executable-Wurzelelement.';
    END;

    IF @StatusCode = 'AVAILABLE_LIMITED'
    BEGIN
        SELECT
              @PackageName = @PackageXml.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((/DTS:Executable/@DTS:ObjectName)[1])','nvarchar(256)')
            , @PackageType = @PackageXml.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((/DTS:Executable/@DTS:ExecutableType)[1])','nvarchar(256)')
            , @ProtectionLevel = @PackageXml.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((/DTS:Executable/@DTS:ProtectionLevel)[1])','nvarchar(64)')
            , @PackageFormatVersion = TRY_CONVERT(int,@PackageXml.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((/DTS:Executable/DTS:Property[@DTS:Name="PackageFormatVersion"])[1])','nvarchar(32)'));

        IF NULLIF(@PackageType,N'') IS NULL OR @PackageType NOT LIKE N'%Package%'
        BEGIN
            SELECT @StatusCode = 'UNSUPPORTED_PACKAGE_FORMAT', @IsPartial = 1,
                   @ErrorMessage = N'Das DTSX-Wurzelelement ist nicht als Paket-Executable erkennbar.';
        END;
    END;

    IF @StatusCode = 'AVAILABLE_LIMITED'
    BEGIN
        INSERT [#SsisPackageAnalysis_Executables]
        ([ExecutableOrdinal],[ParentExecutableName],[ExecutableName],[ExecutableType],[CreationName],[IsPackageRoot],[IsDisabled],[SourceStatus])
        SELECT 1,NULL,@PackageName,@PackageType,
               @PackageXml.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((/DTS:Executable/@DTS:CreationName)[1])','nvarchar(256)'),
               1,TRY_CONVERT(bit,@PackageXml.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((/DTS:Executable/@DTS:Disabled)[1])','nvarchar(8)')),'AVAILABLE_LIMITED';

        INSERT [#SsisPackageAnalysis_Executables]
        ([ExecutableOrdinal],[ParentExecutableName],[ExecutableName],[ExecutableType],[CreationName],[IsPackageRoot],[IsDisabled],[SourceStatus])
        SELECT CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT 1))) + 1,
               [n].[value]('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((../../@DTS:ObjectName)[1])','nvarchar(256)'),
               [n].[value]('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:ObjectName)[1])','nvarchar(256)'),
               [n].[value]('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:ExecutableType)[1])','nvarchar(256)'),
               [n].[value]('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:CreationName)[1])','nvarchar(256)'),
               0,TRY_CONVERT(bit,[n].[value]('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:Disabled)[1])','nvarchar(8)')),'AVAILABLE_LIMITED'
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:Executable') AS [x]([n]);

        INSERT [#SsisPackageAnalysis_Package]
        ([PackageName],[PackageFormatVersion],[RootExecutableType],[ProtectionLevel],[ExecutableCount],[AnalysisStatus],[EvidenceLimit])
        SELECT @PackageName,@PackageFormatVersion,@PackageType,NULLIF(@ProtectionLevel,N''),COUNT(*),'AVAILABLE_LIMITED',
               N'Der erste Parser-Slice inventarisiert Paket, Executables und direkte Parent-Container; er liest keine Verbindungszeichenfolgen oder sensiblen Paketwerte.'
        FROM [#SsisPackageAnalysis_Executables];

        INSERT [#SsisPackageAnalysis_Warnings]([WarningCode],[WarningSeverity],[Detail])
        VALUES ('PARSER_SCOPE_LIMITED','INFO',N'Data-Flow-Komponenten, Precedence Constraints, Connections, Parameter, Expressions, Lineage und Regelengine folgen in getrennten Parser-Slices.');
    END;

    INSERT [#SsisPackageAnalysis_SourceStatus]([SourceName],[StatusCode],[IsPartial],[ReturnedRowCount],[Detail])
    SELECT N'Direkt übergebenes DTSX-XML',@StatusCode,@IsPartial,COUNT(*),
           CASE WHEN @StatusCode = 'AVAILABLE_LIMITED' THEN N'Paket-, Executable- und Parent-Container-Inventar aus direkt übergebenem XML; keine externe Quelle wurde geöffnet.'
                ELSE COALESCE(@ErrorMessage,N'Die Quelle konnte nicht im unterstützten Format analysiert werden.') END
    FROM [#SsisPackageAnalysis_Executables];

    INSERT [#SsisPackageAnalysis_ModuleStatus]
    ([ModuleName],[CollectionTimeUtc],[SchemaVersion],[StatusCode],[IsPartial],[PackageCount],[ExecutableCount],[FindingCount],[ErrorNumber],[ErrorMessage])
    SELECT N'USP_SsisPackageAnalysis',@Now,1,@StatusCode,@IsPartial,
           (SELECT COUNT(*) FROM [#SsisPackageAnalysis_Package]),
           (SELECT COUNT(*) FROM [#SsisPackageAnalysis_Executables]),0,@ErrorNumber,@ErrorMessage;

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;

    IF @JsonErzeugen = 1
        SELECT @Json = (SELECT
              JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_ModuleStatus] FOR JSON PATH)) AS [moduleStatus]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Package] FOR JSON PATH)) AS [package]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Executables] FOR JSON PATH)) AS [executables]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_SourceStatus] FOR JSON PATH)) AS [sourceStatus]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Warnings] FOR JSON PATH)) AS [warnings]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    IF @TableRequested = 1
    BEGIN
        DECLARE @TargetTable sysname;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'moduleStatus'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_ModuleStatus',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'package'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Package',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'executables'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Executables',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'dataFlowComponents'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_DataFlowComponents',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'connections'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Connections',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'parameters'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Parameters',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'expressions'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Expressions',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'lineage'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Lineage',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'findings'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Findings',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'sourceStatus'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_SourceStatus',@TargetTable,@ThrowOnError=1;
        SELECT @TargetTable=[TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'warnings'; IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Warnings',@TargetTable,@ThrowOnError=1;
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT * FROM [#SsisPackageAnalysis_ModuleStatus];
        SELECT * FROM [#SsisPackageAnalysis_Package];
        SELECT * FROM [#SsisPackageAnalysis_Executables] WHERE [ExecutableOrdinal] <= @Limit ORDER BY [ExecutableOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_DataFlowComponents] WHERE [ComponentOrdinal] <= @Limit ORDER BY [ComponentOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Connections] WHERE [ConnectionOrdinal] <= @Limit ORDER BY [ConnectionOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Parameters] WHERE [ParameterOrdinal] <= @Limit ORDER BY [ParameterOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Expressions] WHERE [ExpressionOrdinal] <= @Limit ORDER BY [ExpressionOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Lineage] WHERE [LineageOrdinal] <= @Limit ORDER BY [LineageOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Findings];
        SELECT * FROM [#SsisPackageAnalysis_SourceStatus];
        SELECT * FROM [#SsisPackageAnalysis_Warnings];
    END;

    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#SsisPackageAnalysis_ModuleStatus'
            , @ResultLabel=N'SsisPackageAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;

    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';
    EXEC [sys].[sp_executesql] @LockTimeoutSql;
END;
GO
