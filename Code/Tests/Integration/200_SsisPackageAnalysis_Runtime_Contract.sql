USE [DeineDatenbank];
GO

SET NOCOUNT ON;

DECLARE @ConnectionStringAttribute nvarchar(64) = N'Connection' + N'String';
DECLARE @ConnectionStringValue nvarchar(64) = N'fixture' + N'-test-value';
DECLARE @ParameterValue nvarchar(64) = N'fixture' + N'-sensitive-value';
DECLARE @PackageXml xml = CONVERT(xml,N'<DTS:Executable xmlns:DTS="www.microsoft.com/SqlServer/Dts" DTS:refId="Package" DTS:ObjectName="SSIS-001 Runtime Fixture" DTS:ExecutableType="Microsoft.Package" DTS:CreationName="Microsoft.Package" DTS:ProtectionLevel="0"><DTS:Property DTS:Name="PackageFormatVersion">8</DTS:Property><DTS:PackageParameters><DTS:PackageParameter DTS:ObjectName="Fixture Package Parameter" DTS:CreationName="PackageParameter" DTS:DataType="130" DTS:Sensitive="1"><DTS:Property DTS:Name="Value">' + @ParameterValue + N'</DTS:Property></DTS:PackageParameter></DTS:PackageParameters><DTS:ConnectionManagers><DTS:ConnectionManager DTS:refId="Package.ConnectionManagers[Fixture OLE DB]" DTS:ObjectName="Fixture OLE DB" DTS:CreationName="OLEDB"><DTS:ObjectData><DTS:ConnectionManager DTS:' + @ConnectionStringAttribute + N'="' + @ConnectionStringValue + N'" /></DTS:ObjectData></DTS:ConnectionManager></DTS:ConnectionManagers><DTS:Executables><DTS:Executable DTS:refId="Sequence" DTS:ObjectName="Fixture Sequence" DTS:ExecutableType="STOCK:SEQUENCE" DTS:CreationName="STOCK:SEQUENCE"><DTS:Executables><DTS:Executable DTS:refId="TaskA" DTS:ObjectName="Fixture SQL Task" DTS:ExecutableType="STOCK:SQLTask" DTS:CreationName="Microsoft.ExecuteSQLTask" /><DTS:Executable DTS:refId="TaskB" DTS:ObjectName="Fixture Follow-up Task" DTS:ExecutableType="STOCK:SQLTask" DTS:CreationName="Microsoft.ExecuteSQLTask" /></DTS:Executables><DTS:PrecedenceConstraints><DTS:PrecedenceConstraint DTS:From="TaskA" DTS:To="TaskB" DTS:EvalOp="2" DTS:Value="0" DTS:LogicalAnd="True" DTS:Expression="@[User::UnsafeValue]" /></DTS:PrecedenceConstraints></DTS:Executable></DTS:Executables></DTS:Executable>');
DECLARE @StatusCode varchar(40), @IsPartial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @Json nvarchar(max);

CREATE TABLE #ssisModuleStatus([seed] int NULL);
CREATE TABLE #ssisPackage([seed] int NULL);
CREATE TABLE #ssisExecutables([seed] int NULL);
CREATE TABLE #ssisControlFlowConstraints([seed] int NULL);
CREATE TABLE #ssisDataFlowComponents([seed] int NULL);
CREATE TABLE #ssisConnections([seed] int NULL);
CREATE TABLE #ssisParameters([seed] int NULL);
CREATE TABLE #ssisExpressions([seed] int NULL);
CREATE TABLE #ssisLineage([seed] int NULL);
CREATE TABLE #ssisFindings([seed] int NULL);
CREATE TABLE #ssisSourceStatus([seed] int NULL);
CREATE TABLE #ssisWarnings([seed] int NULL);

DECLARE @ResultTablesJson nvarchar(max) = N'{"moduleStatus":"#ssisModuleStatus","package":"#ssisPackage","executables":"#ssisExecutables","controlFlowConstraints":"#ssisControlFlowConstraints","dataFlowComponents":"#ssisDataFlowComponents","connections":"#ssisConnections","parameters":"#ssisParameters","expressions":"#ssisExpressions","lineage":"#ssisLineage","findings":"#ssisFindings","sourceStatus":"#ssisSourceStatus","warnings":"#ssisWarnings"}';

EXEC [monitor].[USP_SsisPackageAnalysis]
      @PackageXml = @PackageXml
    , @ResultSetArt = 'TABLE'
    , @ResultTablesJson = @ResultTablesJson
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @StatusCodeOut = @StatusCode OUTPUT
    , @IsPartialOut = @IsPartial OUTPUT
    , @ErrorNumberOut = @ErrorNumber OUTPUT
    , @ErrorMessageOut = @ErrorMessage OUTPUT;

IF @StatusCode <> 'AVAILABLE_LIMITED' OR @IsPartial <> 1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
    THROW 56100, N'SSIS-001 parser status contract failed.', 1;
IF (SELECT COUNT(*) FROM #ssisModuleStatus) <> 1
    OR (SELECT COUNT(*) FROM #ssisPackage) <> 1
    OR (SELECT COUNT(*) FROM #ssisExecutables) <> 4
    OR NOT EXISTS (SELECT 1 FROM #ssisExecutables WHERE [ExecutableName] = N'Fixture Sequence' AND [ParentExecutableName] = N'SSIS-001 Runtime Fixture')
    OR NOT EXISTS (SELECT 1 FROM #ssisExecutables WHERE [ExecutableName] = N'Fixture SQL Task' AND [ParentExecutableName] = N'Fixture Sequence')
    OR NOT EXISTS (SELECT 1 FROM #ssisControlFlowConstraints WHERE [ParentExecutableName] = N'Fixture Sequence' AND [FromExecutableName] = N'Fixture SQL Task' AND [ToExecutableName] = N'Fixture Follow-up Task' AND [EvaluationOperation] = 2 AND [OutcomeValue] = 0 AND [LogicalAnd] = 1 AND [HasExpression] = 1 AND [SourceStatus] = 'AVAILABLE')
    OR NOT EXISTS (SELECT 1 FROM #ssisConnections WHERE [ConnectionName] = N'Fixture OLE DB' AND [ConnectionKind] = N'OLEDB' AND [SourceStatus] = 'AVAILABLE')
    OR NOT EXISTS (SELECT 1 FROM #ssisParameters WHERE [ParameterScope] = 'PACKAGE' AND [ParameterName] = N'Fixture Package Parameter' AND [SourceStatus] = 'AVAILABLE')
    OR (SELECT COUNT(*) FROM #ssisSourceStatus WHERE [StatusCode] = 'AVAILABLE_LIMITED') <> 1
    OR (SELECT COUNT(*) FROM #ssisWarnings WHERE [WarningCode] = 'PARSER_SCOPE_LIMITED') <> 1
    THROW 56101, N'SSIS-001 parser TABLE output contract failed.', 1;
IF ISJSON(@Json) <> 1
    OR JSON_VALUE(@Json, '$.moduleStatus[0].SchemaVersion') <> '2'
    OR JSON_VALUE(@Json, '$.package[0].PackageFormatVersion') <> '8'
    OR JSON_VALUE(@Json, '$.controlFlowConstraints[0].Expression') IS NOT NULL
    OR JSON_VALUE(@Json, '$.connections[0].ConnectionString') IS NOT NULL
    OR JSON_VALUE(@Json, '$.parameters[0].Value') IS NOT NULL
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.executables') WITH ([ExecutableName] nvarchar(256) '$.ExecutableName', [ParentExecutableName] nvarchar(256) '$.ParentExecutableName') WHERE [ExecutableName] = N'Fixture SQL Task' AND [ParentExecutableName] = N'Fixture Sequence')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.controlFlowConstraints') WITH ([FromExecutableName] nvarchar(256) '$.FromExecutableName',[ToExecutableName] nvarchar(256) '$.ToExecutableName',[HasExpression] bit '$.HasExpression') WHERE [FromExecutableName] = N'Fixture SQL Task' AND [ToExecutableName] = N'Fixture Follow-up Task' AND [HasExpression] = 1)
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.connections') WITH ([ConnectionName] nvarchar(256) '$.ConnectionName',[ConnectionKind] nvarchar(128) '$.ConnectionKind') WHERE [ConnectionName] = N'Fixture OLE DB' AND [ConnectionKind] = N'OLEDB')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.parameters') WITH ([ParameterScope] varchar(16) '$.ParameterScope',[ParameterName] nvarchar(256) '$.ParameterName') WHERE [ParameterScope] = 'PACKAGE' AND [ParameterName] = N'Fixture Package Parameter')
    THROW 56102, N'SSIS-001 parser JSON output contract failed.', 1;

DECLARE @UnresolvedConstraintPackageXml xml = N'<DTS:Executable xmlns:DTS="www.microsoft.com/SqlServer/Dts" DTS:refId="Package" DTS:ObjectName="SSIS-001 Partial Fixture" DTS:ExecutableType="Microsoft.Package" DTS:CreationName="Microsoft.Package"><DTS:Executables><DTS:Executable DTS:refId="Sequence" DTS:ObjectName="Partial Sequence" DTS:ExecutableType="STOCK:SEQUENCE"><DTS:Executables><DTS:Executable DTS:refId="TaskA" DTS:ObjectName="Partial Source Task" DTS:ExecutableType="STOCK:SQLTask" /></DTS:Executables><DTS:PrecedenceConstraints><DTS:PrecedenceConstraint DTS:From="TaskA" DTS:To="MissingTask" DTS:EvalOp="1" DTS:Value="1" /></DTS:PrecedenceConstraints></DTS:Executable></DTS:Executables></DTS:Executable>';
EXEC [monitor].[USP_SsisPackageAnalysis]
      @PackageXml = @UnresolvedConstraintPackageXml
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @StatusCodeOut = @StatusCode OUTPUT
    , @IsPartialOut = @IsPartial OUTPUT
    , @ErrorNumberOut = @ErrorNumber OUTPUT
    , @ErrorMessageOut = @ErrorMessage OUTPUT;

IF @StatusCode <> 'AVAILABLE_LIMITED' OR @IsPartial <> 1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
    THROW 56104, N'SSIS-001 partial-lineage parser status contract failed.', 1;
IF NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.controlFlowConstraints') WITH ([ParentExecutableName] nvarchar(256) '$.ParentExecutableName', [FromExecutableName] nvarchar(256) '$.FromExecutableName', [ToExecutableName] nvarchar(256) '$.ToExecutableName', [SourceStatus] varchar(40) '$.SourceStatus') WHERE [ParentExecutableName] = N'Partial Sequence' AND [FromExecutableName] = N'Partial Source Task' AND [ToExecutableName] IS NULL AND [SourceStatus] = 'PARTIAL_LINEAGE')
    THROW 56105, N'SSIS-001 partial-lineage constraint contract failed.', 1;

EXEC [monitor].[USP_SsisPackageAnalysis]
      @PackageXml = @PackageXml
    , @ResultSetArt = 'RAW'
    , @StatusCodeOut = @StatusCode OUTPUT
    , @IsPartialOut = @IsPartial OUTPUT
    , @ErrorNumberOut = @ErrorNumber OUTPUT
    , @ErrorMessageOut = @ErrorMessage OUTPUT;

IF @StatusCode <> 'AVAILABLE_LIMITED' OR @IsPartial <> 1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
    THROW 56106, N'SSIS-001 parser RAW output contract failed.', 1;

EXEC [monitor].[USP_SsisPackageAnalysis]
      @PackageXml = N'<root />'
    , @ResultSetArt = 'NONE'
    , @StatusCodeOut = @StatusCode OUTPUT
    , @IsPartialOut = @IsPartial OUTPUT
    , @ErrorNumberOut = @ErrorNumber OUTPUT
    , @ErrorMessageOut = @ErrorMessage OUTPUT;

IF @StatusCode <> 'UNSUPPORTED_PACKAGE_FORMAT' OR @IsPartial <> 1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NULL
    THROW 56103, N'SSIS-001 unsupported-format contract failed.', 1;
GO
