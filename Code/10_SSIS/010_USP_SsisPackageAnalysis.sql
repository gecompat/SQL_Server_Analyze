USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_SsisPackageAnalysis
Version      : 1.2.0
Stand        : 2026-10-11
Typ          : Stored Procedure
Zweck        : Inventarisiert ein direkt übergebenes DTSX-v2-Paket statisch.
Datenquelle  : Ausschließlich @PackageXml; keine Datei-, ISPAC-, SSISDB-,
               Datenbank- oder externe Verbindungsquelle wird geöffnet.
Datenschutz  : Keine Connection Strings, Secret-, Binary-, Host-, Login- oder
               vollständigen Pfadwerte werden gelesen oder ausgegeben.
Abgrenzung   : Dieser erste Slice stabilisiert Paket-, Executable- und direkte
               Parent-Container-Inventare.
               Lineage und Regeln bleiben als leere, ausdrücklich begrenzte
               Resultsets sichtbar. Direkte
               Precedence Constraints, Connection Manager und
               Property-Expressions werden ohne Ausdrucks- oder
               Connection-String-Werte inventarisiert.
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
    DECLARE @VariableScopeIncomplete bit = 0;
    DECLARE @PackageFormatVersion int = NULL;
    DECLARE @PackageName nvarchar(256) = NULL;
    DECLARE @PackageType nvarchar(256) = NULL;
    DECLARE @ProtectionLevel nvarchar(64) = NULL;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_SsisPackageAnalysis';
        PRINT N'Analysiert ausschließlich direkt übergebenes DTSX-v2-XML. Der Aufruf öffnet weder Dateien noch SSISDB, führt keine Pakete und kein Paket-SQL aus.';
        PRINT N'Der erste Parser-Slice inventarisiert Paket, Executables, direkte Parent-Container, Precedence Constraints, Connection Manager, Paketparameter, Variablendefinitionen, Pipeline-Komponenten und Property-Expressions ohne Wertausgabe. Lineage und Regelengine werden als begrenzte Resultsets ausgegeben.';
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
            , @AllowedResultNames = N'moduleStatus|package|executables|controlFlowConstraints|dataFlowComponents|connections|parameters|expressions|lineage|findings|sourceStatus|warnings|variables'
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
    CREATE TABLE [#SsisPackageAnalysis_ControlFlowConstraints]
    (
          [ConstraintOrdinal] int NOT NULL
        , [ParentExecutableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FromExecutableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ToExecutableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvaluationOperation] tinyint NULL
        , [OutcomeValue] tinyint NULL
        , [LogicalAnd] bit NULL
        , [HasExpression] bit NOT NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , PRIMARY KEY ([ConstraintOrdinal])
    );
    CREATE TABLE [#SsisPackageAnalysis_ExecutableReferences]
    (
          [ExecutableOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY
        , [ReferenceId] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ParentReferenceId] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ParentExecutableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecutableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ExecutableType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CreationName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsPackageRoot] bit NOT NULL
        , [IsDisabled] bit NULL
        , [IsDirectExecutableParent] bit NOT NULL
        , [VariableScopeSupported] bit NOT NULL DEFAULT (0)
    );
    CREATE UNIQUE INDEX [IX_SsisPackageAnalysis_ReferenceId]
        ON [#SsisPackageAnalysis_ExecutableReferences]([ReferenceId]) WHERE [ReferenceId] IS NOT NULL;
    CREATE TABLE [#SsisPackageAnalysis_Variables]
    (
          [VariableOrdinal] int NOT NULL PRIMARY KEY
        , [ScopeExecutableOrdinal] int NOT NULL
        , [VariableNamespace] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [VariableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DataTypeCode] int NULL
        , [IsReadOnly] bit NULL
        , [EvaluateAsExpression] bit NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#SsisPackageAnalysis_VariablesExport]
    (
          [VariableOrdinal] int NOT NULL PRIMARY KEY
        , [ScopeExecutableOrdinal] int NOT NULL
        , [VariableNamespace] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [VariableName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DataTypeCode] int NULL
        , [IsReadOnly] bit NULL
        , [EvaluateAsExpression] bit NULL
        , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
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
    CREATE TABLE [#SsisPackageAnalysis_PipelineEndpoints]
    (
          [PipelineId] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EndpointId] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ComponentName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
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
        INSERT [#SsisPackageAnalysis_ExecutableReferences]
        ([ReferenceId],[ParentReferenceId],[ParentExecutableName],[ExecutableName],[ExecutableType],[CreationName],[IsPackageRoot],[IsDisabled],[IsDirectExecutableParent],[VariableScopeSupported])
        SELECT NULLIF(@PackageXml.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((/DTS:Executable/@DTS:refId)[1])','nvarchar(4000)'),N''),
               NULL,NULL,@PackageName,@PackageType,
               @PackageXml.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((/DTS:Executable/@DTS:CreationName)[1])','nvarchar(256)'),
               1,TRY_CONVERT(bit,@PackageXml.value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((/DTS:Executable/@DTS:Disabled)[1])','nvarchar(8)')),0,1;

        INSERT [#SsisPackageAnalysis_ExecutableReferences]
        ([ReferenceId],[ParentReferenceId],[ParentExecutableName],[ExecutableName],[ExecutableType],[CreationName],[IsPackageRoot],[IsDisabled],[IsDirectExecutableParent])
        SELECT NULLIF([n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:refId)[1])','nvarchar(4000)'),N''),
               NULLIF([n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((../../@DTS:refId)[1])','nvarchar(4000)'),N''),
               [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((../../@DTS:ObjectName)[1])','nvarchar(256)'),
               [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:ObjectName)[1])','nvarchar(256)'),
               [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:ExecutableType)[1])','nvarchar(256)'),
               [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:CreationName)[1])','nvarchar(256)'),
               0,TRY_CONVERT(bit,[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:Disabled)[1])','nvarchar(8)')),
               [n].exist('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; ../../self::DTS:Executable')
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:Executable') AS [x]([n]);

        ;WITH [SupportedScopes] AS
        (
            SELECT [ExecutableOrdinal],[ReferenceId]
            FROM [#SsisPackageAnalysis_ExecutableReferences] WHERE [IsPackageRoot]=1
            UNION ALL
            SELECT [c].[ExecutableOrdinal],[c].[ReferenceId]
            FROM [#SsisPackageAnalysis_ExecutableReferences] AS [c]
            INNER JOIN [SupportedScopes] AS [p] ON [c].[ParentReferenceId]=[p].[ReferenceId]
            WHERE [c].[IsDirectExecutableParent]=1
        )
        UPDATE [r] SET [VariableScopeSupported]=1
        FROM [#SsisPackageAnalysis_ExecutableReferences] AS [r]
        INNER JOIN [SupportedScopes] AS [s] ON [s].[ExecutableOrdinal]=[r].[ExecutableOrdinal]
        OPTION (MAXRECURSION 0);

        INSERT [#SsisPackageAnalysis_Executables]
        ([ExecutableOrdinal],[ParentExecutableName],[ExecutableName],[ExecutableType],[CreationName],[IsPackageRoot],[IsDisabled],[SourceStatus])
        SELECT [ExecutableOrdinal],[ParentExecutableName],[ExecutableName],[ExecutableType],[CreationName],[IsPackageRoot],[IsDisabled],'AVAILABLE_LIMITED'
        FROM [#SsisPackageAnalysis_ExecutableReferences];

        IF EXISTS (SELECT 1 FROM [#SsisPackageAnalysis_ExecutableReferences] WHERE [ReferenceId] IS NULL)
        BEGIN
            SET @VariableScopeIncomplete=1;
            INSERT [#SsisPackageAnalysis_Warnings]([WarningCode],[WarningSeverity],[Detail])
            VALUES ('VARIABLES_SCOPE_UNRESOLVED','INFO',N'Eine fehlende Executable-Kennung verhindert die eindeutige Zuordnung von Variablenscope. Nicht zuordenbare Definitionen werden nicht ausgegeben; ein leeres Inventar belegt daher keine Abwesenheit.');
        END;

        INSERT [#SsisPackageAnalysis_Variables]
        ([VariableOrdinal],[ScopeExecutableOrdinal],[VariableNamespace],[VariableName],[DataTypeCode],[IsReadOnly],[EvaluateAsExpression],[SourceStatus])
        SELECT CONVERT(int,ROW_NUMBER() OVER (ORDER BY [r].[ExecutableOrdinal],[v].[VariableNamespace],[v].[VariableName])),
               [r].[ExecutableOrdinal],[v].[VariableNamespace],[v].[VariableName],[v].[DataTypeCode],[v].[IsReadOnly],[v].[EvaluateAsExpression],
               CASE WHEN [v].[VariableName] IS NULL OR [v].[DataTypeCode] IS NULL OR [v].[IsReadOnly] IS NULL OR [v].[EvaluateAsExpression] IS NULL
                    THEN 'AVAILABLE_LIMITED' ELSE 'AVAILABLE' END
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:Variable') AS [x]([n])
        INNER JOIN [#SsisPackageAnalysis_ExecutableReferences] AS [r]
            ON [r].[ReferenceId]=NULLIF([n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((../../@DTS:refId)[1])','nvarchar(4000)'),N'')
            AND [r].[VariableScopeSupported]=1
        CROSS APPLY
        (
            SELECT [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:Namespace)[1])','nvarchar(256)') AS [VariableNamespace],
                   NULLIF([n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:ObjectName)[1])','nvarchar(256)'),N'') AS [VariableName],
                   TRY_CONVERT(int,NULLIF([n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((DTS:VariableValue/@DTS:DataType)[1])','nvarchar(32)'),N'')) AS [DataTypeCode],
                   CASE WHEN [n].exist('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; @DTS:ReadOnly')=0 THEN 0
                        ELSE CASE LOWER([n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:ReadOnly)[1])','nvarchar(16)') COLLATE SQL_Latin1_General_CP1_CS_AS)
                             WHEN N'false' THEN 0 WHEN N'true' THEN 1 ELSE NULL END END AS [IsReadOnly],
                   CASE WHEN [n].exist('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; @DTS:EvaluateAsExpression')=0 THEN 0
                        ELSE CASE LOWER([n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:EvaluateAsExpression)[1])','nvarchar(16)') COLLATE SQL_Latin1_General_CP1_CS_AS)
                             WHEN N'false' THEN 0 WHEN N'true' THEN 1 ELSE NULL END END AS [EvaluateAsExpression]
        ) AS [v]
        WHERE [n].exist('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; ../self::DTS:Variables')=1
          AND [n].exist('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; ../../self::DTS:Executable')=1;

        IF @PackageXml.exist('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:EventHandler')=1
            INSERT [#SsisPackageAnalysis_Warnings]([WarningCode],[WarningSeverity],[Detail])
            VALUES ('VARIABLES_EVENT_HANDLER_SCOPE_NOT_SUPPORTED','INFO',N'Variablen von Event Handlern und deren untergeordneten Executables werden noch nicht inventarisiert.');

        INSERT [#SsisPackageAnalysis_ControlFlowConstraints]
        ([ConstraintOrdinal],[ParentExecutableName],[FromExecutableName],[ToExecutableName],[EvaluationOperation],[OutcomeValue],[LogicalAnd],[HasExpression],[SourceStatus])
        SELECT CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT 1))),
               [c].[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((../../@DTS:ObjectName)[1])','nvarchar(256)'),
               [f].[ExecutableName],[t].[ExecutableName],
               TRY_CONVERT(tinyint,[c].[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:EvalOp)[1])','nvarchar(16)')),
               TRY_CONVERT(tinyint,[c].[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:Value)[1])','nvarchar(16)')),
               CASE LOWER([c].[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:LogicalAnd)[1])','nvarchar(16)')) WHEN N'true' THEN 1 WHEN N'1' THEN 1 WHEN N'-1' THEN 1 WHEN N'false' THEN 0 WHEN N'0' THEN 0 ELSE NULL END,
               CASE WHEN [c].[n].exist('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; @DTS:Expression') = 1 THEN 1 ELSE 0 END,
               CASE WHEN [f].[ExecutableName] IS NULL OR [t].[ExecutableName] IS NULL THEN 'PARTIAL_LINEAGE' ELSE 'AVAILABLE' END
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:PrecedenceConstraint') AS [c]([n])
        OUTER APPLY
        (
            SELECT [ExecutableName]
            FROM [#SsisPackageAnalysis_ExecutableReferences]
            WHERE [ReferenceId]=NULLIF([c].[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:From)[1])','nvarchar(4000)'),N'')
        ) AS [f]
        OUTER APPLY
        (
            SELECT [ExecutableName]
            FROM [#SsisPackageAnalysis_ExecutableReferences]
            WHERE [ReferenceId]=NULLIF([c].[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:To)[1])','nvarchar(4000)'),N'')
        ) AS [t];

        INSERT [#SsisPackageAnalysis_Connections]
        ([ConnectionOrdinal],[ConnectionName],[ConnectionKind],[SourceStatus])
        SELECT CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT 1))),
               [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:ObjectName)[1])','nvarchar(256)'),
               [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:CreationName)[1])','nvarchar(128)'),
               'AVAILABLE'
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable/DTS:ConnectionManagers/DTS:ConnectionManager') AS [x]([n]);

        INSERT [#SsisPackageAnalysis_Parameters]
        ([ParameterOrdinal],[ParameterScope],[ParameterName],[SourceStatus])
        SELECT CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT 1))),
               'PACKAGE',
               [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:ObjectName)[1])','nvarchar(256)'),
               'AVAILABLE'
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable/DTS:PackageParameters/DTS:PackageParameter') AS [x]([n]);

        INSERT [#SsisPackageAnalysis_DataFlowComponents]
        ([ComponentOrdinal],[ComponentName],[ComponentKind],[SourceStatus])
        SELECT CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT 1))),
               [n].value('string((@name)[1])','nvarchar(256)'),
               [n].value('string((@componentClassID)[1])','nvarchar(128)'),
               'AVAILABLE'
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:Executable/DTS:ObjectData/*[local-name(.)="pipeline" and namespace-uri(.)=""]/*[local-name(.)="components" and namespace-uri(.)=""]/*[local-name(.)="component" and namespace-uri(.)=""]') AS [x]([n]);

        INSERT [#SsisPackageAnalysis_PipelineEndpoints]([PipelineId],[EndpointId],[ComponentName])
        SELECT [c].[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((../../../../@DTS:refId)[1])','nvarchar(4000)'),
               [e].[n].value('string((@refId)[1])','nvarchar(4000)'),
               [c].[n].value('string((@name)[1])','nvarchar(256)')
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:Executable/DTS:ObjectData/*[local-name(.)="pipeline" and namespace-uri(.)=""]/*[local-name(.)="components" and namespace-uri(.)=""]/*[local-name(.)="component" and namespace-uri(.)=""]') AS [c]([n])
        CROSS APPLY [c].[n].nodes('*[namespace-uri(.)="" and (local-name(.)="inputs" or local-name(.)="outputs")]/*[namespace-uri(.)="" and (local-name(.)="input" or local-name(.)="output")]') AS [e]([n]);

        INSERT [#SsisPackageAnalysis_Lineage]
        ([LineageOrdinal],[SourceComponent],[TargetComponent],[SourceStatus])
        SELECT CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT 1))),
               [s].[ComponentName],[t].[ComponentName],
               CASE WHEN [s].[ComponentName] IS NULL OR [t].[ComponentName] IS NULL THEN 'PARTIAL_LINEAGE' ELSE 'AVAILABLE' END
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:Executable/DTS:ObjectData/*[local-name(.)="pipeline" and namespace-uri(.)=""]/*[local-name(.)="paths" and namespace-uri(.)=""]/*[local-name(.)="path" and namespace-uri(.)=""]') AS [p]([n])
        OUTER APPLY (SELECT TOP (1) [ComponentName] FROM [#SsisPackageAnalysis_PipelineEndpoints] WHERE [PipelineId] = [p].[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((../../../../@DTS:refId)[1])','nvarchar(4000)') AND [EndpointId] = [p].[n].value('string((@startId)[1])','nvarchar(4000)')) AS [s]
        OUTER APPLY (SELECT TOP (1) [ComponentName] FROM [#SsisPackageAnalysis_PipelineEndpoints] WHERE [PipelineId] = [p].[n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((../../../../@DTS:refId)[1])','nvarchar(4000)') AND [EndpointId] = [p].[n].value('string((@endId)[1])','nvarchar(4000)')) AS [t];

        INSERT [#SsisPackageAnalysis_Expressions]
        ([ExpressionOrdinal],[ExpressionScope],[PropertyName],[SourceStatus])
        SELECT CONVERT(int,ROW_NUMBER() OVER (ORDER BY (SELECT 1))),
               [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((../@DTS:ObjectName)[1])','nvarchar(256)'),
               [n].value('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; string((@DTS:Name)[1])','nvarchar(256)'),
               'AVAILABLE'
        FROM @PackageXml.nodes('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:PropertyExpression') AS [x]([n]);

        INSERT [#SsisPackageAnalysis_Package]
        ([PackageName],[PackageFormatVersion],[RootExecutableType],[ProtectionLevel],[ExecutableCount],[AnalysisStatus],[EvidenceLimit])
        SELECT @PackageName,@PackageFormatVersion,@PackageType,NULLIF(@ProtectionLevel,N''),COUNT(*),'AVAILABLE_LIMITED',
               N'Der erste Parser-Slice inventarisiert Paket, Executables, direkte Parent-Container, Precedence Constraints, Connection Manager, Paketparameter, Variablendefinitionen, Pipeline-Komponenten, Property-Expressions und Pipeline-Komponentenlinien ohne Ausdrucks-, Connection-String-, Parameter-, Komponenteneigenschafts- oder Expressionwerte.'
        FROM [#SsisPackageAnalysis_Executables];

        INSERT [#SsisPackageAnalysis_Warnings]([WarningCode],[WarningSeverity],[Detail])
        VALUES ('PARSER_SCOPE_LIMITED','INFO',N'Weitergehende Lineage und Regelengine folgen in getrennten Parser-Slices.');
    END;

    INSERT [#SsisPackageAnalysis_VariablesExport]
    SELECT * FROM [#SsisPackageAnalysis_Variables] WHERE [VariableOrdinal]<=@Limit;

    IF (SELECT COUNT_BIG(*) FROM [#SsisPackageAnalysis_Variables])>@Limit
        INSERT [#SsisPackageAnalysis_Warnings]([WarningCode],[WarningSeverity],[Detail])
        VALUES ('VARIABLES_TRUNCATED','INFO',N'Das Variableninventar wurde für RAW, TABLE und JSON durch @MaxZeilen begrenzt. ScopeExecutableOrdinal verweist auf das vollständige Executable-Inventar.');

    INSERT [#SsisPackageAnalysis_SourceStatus]([SourceName],[StatusCode],[IsPartial],[ReturnedRowCount],[Detail])
    SELECT N'DTSX variables',
           CASE WHEN @StatusCode<>'AVAILABLE_LIMITED' THEN @StatusCode
                WHEN (SELECT COUNT_BIG(*) FROM [#SsisPackageAnalysis_Variables])>@Limit THEN 'TRUNCATED'
                WHEN @VariableScopeIncomplete=1 OR EXISTS (SELECT 1 FROM [#SsisPackageAnalysis_Variables] WHERE [SourceStatus]='AVAILABLE_LIMITED') THEN 'AVAILABLE_LIMITED'
                WHEN EXISTS (SELECT 1 FROM [#SsisPackageAnalysis_Variables]) THEN 'AVAILABLE' ELSE 'AVAILABLE_EMPTY' END,
           CASE WHEN @StatusCode<>'AVAILABLE_LIMITED' OR @VariableScopeIncomplete=1 OR (SELECT COUNT_BIG(*) FROM [#SsisPackageAnalysis_Variables])>@Limit
                     OR EXISTS (SELECT 1 FROM [#SsisPackageAnalysis_Variables] WHERE [SourceStatus]='AVAILABLE_LIMITED')
                     OR @PackageXml.exist('declare namespace DTS="www.microsoft.com/SqlServer/Dts"; /DTS:Executable//DTS:EventHandler')=1 THEN 1 ELSE 0 END,
           COUNT_BIG(*),N'Direkte Variablendefinitionen aus Paket-, Container- und Taskscope; keine Werte, Ausdruckstexte oder Event-Handler-Scope. Fehlende oder nicht konvertierbare Metadaten bleiben NULL.'
    FROM [#SsisPackageAnalysis_VariablesExport];

    INSERT [#SsisPackageAnalysis_SourceStatus]([SourceName],[StatusCode],[IsPartial],[ReturnedRowCount],[Detail])
    SELECT N'Direkt übergebenes DTSX-XML',@StatusCode,@IsPartial,COUNT(*),
           CASE WHEN @StatusCode = 'AVAILABLE_LIMITED' THEN N'Paket-, Executable-, Parent-Container-, Precedence-Constraint-, Connection-Manager-, Paketparameter-, Pipeline-Komponenten-, Property-Expression- und Pipeline-Linien-Inventar aus direkt übergebenem XML; keine externe Quelle wurde geöffnet.'
                ELSE COALESCE(@ErrorMessage,N'Die Quelle konnte nicht im unterstützten Format analysiert werden.') END
    FROM [#SsisPackageAnalysis_Executables];

    INSERT [#SsisPackageAnalysis_ModuleStatus]
    ([ModuleName],[CollectionTimeUtc],[SchemaVersion],[StatusCode],[IsPartial],[PackageCount],[ExecutableCount],[FindingCount],[ErrorNumber],[ErrorMessage])
    SELECT N'USP_SsisPackageAnalysis',@Now,3,@StatusCode,@IsPartial,
           (SELECT COUNT(*) FROM [#SsisPackageAnalysis_Package]),
           (SELECT COUNT(*) FROM [#SsisPackageAnalysis_Executables]),0,@ErrorNumber,@ErrorMessage;

    SELECT @StatusCodeOut=@StatusCode,@IsPartialOut=@IsPartial,@ErrorNumberOut=@ErrorNumber,@ErrorMessageOut=@ErrorMessage;

    IF @JsonErzeugen = 1
        SELECT @Json = (SELECT
              JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_ModuleStatus] FOR JSON PATH)) AS [moduleStatus]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Package] FOR JSON PATH)) AS [package]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Executables] FOR JSON PATH)) AS [executables]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_ControlFlowConstraints] FOR JSON PATH)) AS [controlFlowConstraints]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_DataFlowComponents] FOR JSON PATH)) AS [dataFlowComponents]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Connections] FOR JSON PATH)) AS [connections]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Parameters] FOR JSON PATH)) AS [parameters]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Expressions] FOR JSON PATH)) AS [expressions]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Lineage] FOR JSON PATH)) AS [lineage]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Findings] FOR JSON PATH)) AS [findings]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_SourceStatus] FOR JSON PATH)) AS [sourceStatus]
            , JSON_QUERY((SELECT * FROM [#SsisPackageAnalysis_Warnings] FOR JSON PATH)) AS [warnings]
            , JSON_QUERY(COALESCE((SELECT * FROM [#SsisPackageAnalysis_VariablesExport] ORDER BY [VariableOrdinal] FOR JSON PATH, INCLUDE_NULL_VALUES),N'[]')) AS [variables]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

    IF @TableRequested = 1
    BEGIN
        DECLARE @TargetTable sysname;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'moduleStatus'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_ModuleStatus',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'package'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Package',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'executables'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Executables',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'controlFlowConstraints'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_ControlFlowConstraints',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'dataFlowComponents'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_DataFlowComponents',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'connections'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Connections',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'parameters'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Parameters',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'expressions'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Expressions',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'lineage'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Lineage',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'findings'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Findings',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'sourceStatus'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_SourceStatus',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'warnings'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_Warnings',@TargetTable,@ThrowOnError=1;
        SET @TargetTable=(SELECT [TargetTable] FROM [#SsisPackageAnalysis_ResultTables] WHERE [ResultName]=N'variables'); IF @TargetTable IS NOT NULL EXEC [monitor].[InternalWriteResultTable] N'#SsisPackageAnalysis_VariablesExport',@TargetTable,@ThrowOnError=1;
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT * FROM [#SsisPackageAnalysis_ModuleStatus];
        SELECT * FROM [#SsisPackageAnalysis_Package];
        SELECT * FROM [#SsisPackageAnalysis_Executables] WHERE [ExecutableOrdinal] <= @Limit ORDER BY [ExecutableOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_ControlFlowConstraints] WHERE [ConstraintOrdinal] <= @Limit ORDER BY [ConstraintOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_DataFlowComponents] WHERE [ComponentOrdinal] <= @Limit ORDER BY [ComponentOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Connections] WHERE [ConnectionOrdinal] <= @Limit ORDER BY [ConnectionOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Parameters] WHERE [ParameterOrdinal] <= @Limit ORDER BY [ParameterOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Expressions] WHERE [ExpressionOrdinal] <= @Limit ORDER BY [ExpressionOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Lineage] WHERE [LineageOrdinal] <= @Limit ORDER BY [LineageOrdinal];
        SELECT * FROM [#SsisPackageAnalysis_Findings];
        SELECT * FROM [#SsisPackageAnalysis_SourceStatus];
        SELECT * FROM [#SsisPackageAnalysis_Warnings];
        SELECT * FROM [#SsisPackageAnalysis_VariablesExport] ORDER BY [VariableOrdinal];
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
