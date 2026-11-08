USE [DeineDatenbank];
GO

SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @ConnectionStringAttribute nvarchar(64) = N'Connection' + N'String';
DECLARE @ConnectionStringValue nvarchar(64) = N'fixture' + N'-test-value';
DECLARE @ParameterValue nvarchar(64) = N'fixture' + N'-sensitive-value';
DECLARE @ComponentPropertyValue nvarchar(64) = N'fixture' + N'-component-property-value';
DECLARE @ExpressionValue nvarchar(64) = N'fixture' + N'-expression-value';
DECLARE @PackageXml xml = CONVERT(xml,N'<DTS:Executable xmlns:DTS="www.microsoft.com/SqlServer/Dts" DTS:refId="Package" DTS:ObjectName="SSIS-001 Runtime Fixture" DTS:ExecutableType="Microsoft.Package" DTS:CreationName="Microsoft.Package" DTS:ProtectionLevel="0"><DTS:Property DTS:Name="PackageFormatVersion">8</DTS:Property><DTS:PackageParameters><DTS:PackageParameter DTS:ObjectName="Fixture Package Parameter" DTS:CreationName="PackageParameter" DTS:DataType="130" DTS:Sensitive="1"><DTS:Property DTS:Name="Value">' + @ParameterValue + N'</DTS:Property></DTS:PackageParameter></DTS:PackageParameters><DTS:ConnectionManagers><DTS:ConnectionManager DTS:refId="Package.ConnectionManagers[Fixture OLE DB]" DTS:ObjectName="Fixture OLE DB" DTS:CreationName="OLEDB"><DTS:ObjectData><DTS:ConnectionManager DTS:' + @ConnectionStringAttribute + N'="' + @ConnectionStringValue + N'" /></DTS:ObjectData></DTS:ConnectionManager></DTS:ConnectionManagers><DTS:Executables><DTS:Executable DTS:refId="Sequence" DTS:ObjectName="Fixture Sequence" DTS:ExecutableType="STOCK:SEQUENCE" DTS:CreationName="STOCK:SEQUENCE"><DTS:Executables><DTS:Executable DTS:refId="TaskA" DTS:ObjectName="Fixture SQL Task" DTS:ExecutableType="STOCK:SQLTask" DTS:CreationName="Microsoft.ExecuteSQLTask" /><DTS:Executable DTS:refId="TaskB" DTS:ObjectName="Fixture Follow-up Task" DTS:ExecutableType="STOCK:SQLTask" DTS:CreationName="Microsoft.ExecuteSQLTask" /></DTS:Executables><DTS:PrecedenceConstraints><DTS:PrecedenceConstraint DTS:From="TaskA" DTS:To="TaskB" DTS:EvalOp="2" DTS:Value="0" DTS:LogicalAnd="True" DTS:Expression="@[User::UnsafeValue]" /></DTS:PrecedenceConstraints></DTS:Executable></DTS:Executables></DTS:Executable>');
SET @PackageXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; declare namespace V="urn:fixture-vendor"; insert <DTS:Executable DTS:refId="DataFlow" DTS:ObjectName="Fixture Data Flow" DTS:ExecutableType="SSIS.Pipeline.3" DTS:CreationName="SSIS.Pipeline.3"><DTS:ObjectData><pipeline><components><component name="Fixture Source" refId="Source" componentClassID="FixtureComponentClass"><properties><property name="FixtureProperty">{sql:variable("@ComponentPropertyValue")}</property></properties><outputs><output refId="Source.Output" /></outputs></component><component name="Fixture Target" refId="Target" componentClassID="FixtureTargetClass"><inputs><input refId="Target.Input" /></inputs></component><V:component name="Foreign Component" componentClassID="ForeignComponentClass" /></components><paths><path refId="SourceToTarget" startId="Source.Output" endId="Target.Input" /><path refId="PartialPath" startId="Source.Output" endId="Missing.Input" /></paths></pipeline></DTS:ObjectData></DTS:Executable> as first into (/DTS:Executable/DTS:Executables)[1]');
SET @PackageXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; insert <DTS:Executable DTS:refId="SecondDataFlow" DTS:ObjectName="Second Fixture Data Flow" DTS:ExecutableType="SSIS.Pipeline.3" DTS:CreationName="SSIS.Pipeline.3"><DTS:ObjectData><pipeline><components><component name="Second Source" refId="Source" componentClassID="FixtureComponentClass"><outputs><output refId="Source.Output" /></outputs></component><component name="Second Target" refId="Target" componentClassID="FixtureTargetClass"><inputs><input refId="Target.Input" /></inputs></component></components><paths><path refId="SecondSourceToTarget" startId="Source.Output" endId="Target.Input" /></paths></pipeline></DTS:ObjectData></DTS:Executable> as first into (/DTS:Executable/DTS:Executables)[1]');
SET @PackageXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; insert <DTS:PropertyExpression DTS:Name="SqlStatementSource">{sql:variable("@ExpressionValue")}</DTS:PropertyExpression> as first into (/DTS:Executable/DTS:Executables/DTS:Executable[@DTS:refId="Sequence"]/DTS:Executables/DTS:Executable[@DTS:refId="TaskA"])[1]');
DECLARE @VariableValue nvarchar(64)=N'fixture' + N'-variable-value';
DECLARE @VariableExpression nvarchar(64)=N'fixture' + N'-variable-expression';
SET @PackageXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; declare namespace V="urn:fixture-vendor"; insert <DTS:Variables><DTS:Variable DTS:ObjectName="Shared" DTS:Namespace="User" DTS:ReadOnly="True" DTS:Expression="{sql:variable("@VariableExpression")}"><DTS:VariableValue DTS:DataType="130">{sql:variable("@VariableValue")}</DTS:VariableValue></DTS:Variable><V:Variable DTS:ObjectName="Foreign Variable"><DTS:VariableValue DTS:DataType="3">1</DTS:VariableValue></V:Variable></DTS:Variables> as first into (/DTS:Executable)[1]');
SET @PackageXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; insert <DTS:Variables><DTS:Variable DTS:ObjectName="Shared" DTS:Namespace="User"><DTS:VariableValue DTS:DataType="3">7</DTS:VariableValue></DTS:Variable><DTS:Variable DTS:ObjectName="shared Ω" DTS:Namespace="User"><DTS:VariableValue DTS:DataType="20">9</DTS:VariableValue></DTS:Variable></DTS:Variables> as first into (/DTS:Executable/DTS:Executables/DTS:Executable[@DTS:refId="Sequence"])[1]');
SET @PackageXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; insert <DTS:Variables><DTS:Variable DTS:ObjectName="Shared" DTS:Namespace="User" DTS:EvaluateAsExpression="True"><DTS:VariableValue DTS:DataType="3">11</DTS:VariableValue></DTS:Variable></DTS:Variables> as first into (/DTS:Executable/DTS:Executables/DTS:Executable[@DTS:refId="Sequence"]/DTS:Executables/DTS:Executable[@DTS:refId="TaskA"])[1]');
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
CREATE TABLE #ssisVariables([seed] int NULL);

DECLARE @ResultTablesJson nvarchar(max) = N'{"moduleStatus":"#ssisModuleStatus","package":"#ssisPackage","executables":"#ssisExecutables","controlFlowConstraints":"#ssisControlFlowConstraints","dataFlowComponents":"#ssisDataFlowComponents","connections":"#ssisConnections","parameters":"#ssisParameters","expressions":"#ssisExpressions","lineage":"#ssisLineage","findings":"#ssisFindings","sourceStatus":"#ssisSourceStatus","warnings":"#ssisWarnings","variables":"#ssisVariables"}';

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
    OR (SELECT COUNT(*) FROM #ssisExecutables) <> 6
    OR NOT EXISTS (SELECT 1 FROM #ssisExecutables WHERE [ExecutableName] = N'Fixture Sequence' AND [ParentExecutableName] = N'SSIS-001 Runtime Fixture')
    OR NOT EXISTS (SELECT 1 FROM #ssisExecutables WHERE [ExecutableName] = N'Fixture SQL Task' AND [ParentExecutableName] = N'Fixture Sequence')
    OR NOT EXISTS (SELECT 1 FROM #ssisControlFlowConstraints WHERE [ParentExecutableName] = N'Fixture Sequence' AND [FromExecutableName] = N'Fixture SQL Task' AND [ToExecutableName] = N'Fixture Follow-up Task' AND [EvaluationOperation] = 2 AND [OutcomeValue] = 0 AND [LogicalAnd] = 1 AND [HasExpression] = 1 AND [SourceStatus] = 'AVAILABLE')
    OR NOT EXISTS (SELECT 1 FROM #ssisConnections WHERE [ConnectionName] = N'Fixture OLE DB' AND [ConnectionKind] = N'OLEDB' AND [SourceStatus] = 'AVAILABLE')
    OR NOT EXISTS (SELECT 1 FROM #ssisParameters WHERE [ParameterScope] = 'PACKAGE' AND [ParameterName] = N'Fixture Package Parameter' AND [SourceStatus] = 'AVAILABLE')
    OR NOT EXISTS (SELECT 1 FROM #ssisDataFlowComponents WHERE [ComponentName] = N'Fixture Source' AND [ComponentKind] = N'FixtureComponentClass' AND [SourceStatus] = 'AVAILABLE')
    OR EXISTS (SELECT 1 FROM #ssisDataFlowComponents WHERE [ComponentName] = N'Foreign Component')
    OR NOT EXISTS (SELECT 1 FROM #ssisExpressions WHERE [ExpressionScope] = N'Fixture SQL Task' AND [PropertyName] = N'SqlStatementSource' AND [SourceStatus] = 'AVAILABLE')
    OR NOT EXISTS (SELECT 1 FROM #ssisLineage WHERE [SourceComponent] = N'Fixture Source' AND [TargetComponent] = N'Fixture Target' AND [SourceStatus] = 'AVAILABLE')
    OR NOT EXISTS (SELECT 1 FROM #ssisLineage WHERE [SourceComponent] = N'Fixture Source' AND [TargetComponent] IS NULL AND [SourceStatus] = 'PARTIAL_LINEAGE')
    OR NOT EXISTS (SELECT 1 FROM #ssisLineage WHERE [SourceComponent] = N'Second Source' AND [TargetComponent] = N'Second Target' AND [SourceStatus] = 'AVAILABLE')
    OR (SELECT COUNT(*) FROM #ssisSourceStatus WHERE [StatusCode] = 'AVAILABLE_LIMITED') <> 1
    OR (SELECT COUNT(*) FROM #ssisWarnings WHERE [WarningCode] = 'PARSER_SCOPE_LIMITED') <> 1
    THROW 56101, N'SSIS-001 parser TABLE output contract failed.', 1;
IF COALESCE(ISJSON(@Json),0) <> 1
    OR JSON_VALUE(@Json, '$.moduleStatus[0].SchemaVersion') <> '3'
    OR JSON_VALUE(@Json, '$.package[0].PackageFormatVersion') <> '8'
    OR JSON_VALUE(@Json, '$.controlFlowConstraints[0].Expression') IS NOT NULL
    OR JSON_VALUE(@Json, '$.connections[0].ConnectionString') IS NOT NULL
    OR JSON_VALUE(@Json, '$.parameters[0].Value') IS NOT NULL
    OR @Json LIKE N'%' + @ComponentPropertyValue + N'%'
    OR @Json LIKE N'%' + @ExpressionValue + N'%'
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.executables') WITH ([ExecutableName] nvarchar(256) '$.ExecutableName', [ParentExecutableName] nvarchar(256) '$.ParentExecutableName') WHERE [ExecutableName] = N'Fixture SQL Task' AND [ParentExecutableName] = N'Fixture Sequence')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.controlFlowConstraints') WITH ([FromExecutableName] nvarchar(256) '$.FromExecutableName',[ToExecutableName] nvarchar(256) '$.ToExecutableName',[HasExpression] bit '$.HasExpression') WHERE [FromExecutableName] = N'Fixture SQL Task' AND [ToExecutableName] = N'Fixture Follow-up Task' AND [HasExpression] = 1)
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.connections') WITH ([ConnectionName] nvarchar(256) '$.ConnectionName',[ConnectionKind] nvarchar(128) '$.ConnectionKind') WHERE [ConnectionName] = N'Fixture OLE DB' AND [ConnectionKind] = N'OLEDB')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.parameters') WITH ([ParameterScope] varchar(16) '$.ParameterScope',[ParameterName] nvarchar(256) '$.ParameterName') WHERE [ParameterScope] = 'PACKAGE' AND [ParameterName] = N'Fixture Package Parameter')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.dataFlowComponents') WITH ([ComponentName] nvarchar(256) '$.ComponentName',[ComponentKind] nvarchar(128) '$.ComponentKind') WHERE [ComponentName] = N'Fixture Source' AND [ComponentKind] = N'FixtureComponentClass')
    OR EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.dataFlowComponents') WITH ([ComponentName] nvarchar(256) '$.ComponentName') WHERE [ComponentName] = N'Foreign Component')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.expressions') WITH ([ExpressionScope] nvarchar(256) '$.ExpressionScope',[PropertyName] nvarchar(256) '$.PropertyName') WHERE [ExpressionScope] = N'Fixture SQL Task' AND [PropertyName] = N'SqlStatementSource')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json, '$.lineage') WITH ([SourceComponent] nvarchar(256) '$.SourceComponent',[TargetComponent] nvarchar(256) '$.TargetComponent') WHERE [SourceComponent] = N'Fixture Source' AND [TargetComponent] = N'Fixture Target')
    THROW 56102, N'SSIS-001 parser JSON output contract failed.', 1;

IF (SELECT COUNT(*) FROM #ssisVariables)<>4
    OR NOT EXISTS (SELECT 1 FROM #ssisVariables AS [v] JOIN #ssisExecutables AS [e] ON [e].[ExecutableOrdinal]=[v].[ScopeExecutableOrdinal] WHERE [e].[IsPackageRoot]=1 AND [v].[VariableName]=N'Shared' AND [v].[VariableNamespace]=N'User' AND [v].[DataTypeCode]=130 AND [v].[IsReadOnly]=1 AND [v].[EvaluateAsExpression]=0 AND [v].[SourceStatus]='AVAILABLE')
    OR NOT EXISTS (SELECT 1 FROM #ssisVariables AS [v] JOIN #ssisExecutables AS [e] ON [e].[ExecutableOrdinal]=[v].[ScopeExecutableOrdinal] WHERE [e].[ExecutableName]=N'Fixture Sequence' AND [v].[VariableName]=N'Shared' AND [v].[DataTypeCode]=3 AND [v].[IsReadOnly]=0 AND [v].[EvaluateAsExpression]=0)
    OR NOT EXISTS (SELECT 1 FROM #ssisVariables AS [v] JOIN #ssisExecutables AS [e] ON [e].[ExecutableOrdinal]=[v].[ScopeExecutableOrdinal] WHERE [e].[ExecutableName]=N'Fixture SQL Task' AND [v].[VariableName]=N'Shared' AND [v].[EvaluateAsExpression]=1)
    OR NOT EXISTS (SELECT 1 FROM #ssisVariables WHERE [VariableName]=N'shared Ω' AND [DataTypeCode]=20)
    OR @Json LIKE N'%' + @VariableValue + N'%' OR @Json LIKE N'%' + @VariableExpression + N'%'
    THROW 56107,N'SSIS-001 variable identity, metadata or value exclusion failed.',1;

SELECT * INTO #expectedVariables FROM #ssisVariables;
SELECT * INTO #jsonVariables FROM OPENJSON(@Json,'$.variables') WITH
([VariableOrdinal] int,[ScopeExecutableOrdinal] int,[VariableNamespace] nvarchar(256),[VariableName] nvarchar(256),[DataTypeCode] int,[IsReadOnly] bit,[EvaluateAsExpression] bit,[SourceStatus] varchar(40));
IF EXISTS (SELECT * FROM #ssisVariables EXCEPT SELECT * FROM #jsonVariables)
    OR EXISTS (SELECT * FROM #jsonVariables EXCEPT SELECT * FROM #ssisVariables)
    OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.variables'))<>4
    OR (SELECT COUNT(*) FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID('tempdb..#ssisVariables'))<>8
    THROW 56108,N'SSIS-001 variable TABLE/JSON parity or schema failed.',1;

DECLARE @LimitPass int=1,@VariableLimit int;
WHILE @LimitPass<=3
BEGIN
    SET @VariableLimit=CASE @LimitPass WHEN 1 THEN 1 WHEN 2 THEN 0 ELSE NULL END;
    EXEC(N'TRUNCATE TABLE #ssisVariables; ALTER TABLE #ssisVariables ADD [seed] int NULL; ALTER TABLE #ssisVariables DROP COLUMN [VariableOrdinal],[ScopeExecutableOrdinal],[VariableNamespace],[VariableName],[DataTypeCode],[IsReadOnly],[EvaluateAsExpression],[SourceStatus];');
    EXEC [monitor].[USP_SsisPackageAnalysis] @PackageXml=@PackageXml,@MaxZeilen=@VariableLimit,@ResultSetArt='TABLE',
         @ResultTablesJson=N'{"variables":"#ssisVariables"}',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF (SELECT COUNT(*) FROM #ssisVariables)<>CASE WHEN @LimitPass=1 THEN 1 ELSE 4 END
       OR (SELECT COUNT(*) FROM OPENJSON(@Json,'$.variables'))<>(SELECT COUNT(*) FROM #ssisVariables)
       OR EXISTS (SELECT * FROM #ssisVariables EXCEPT SELECT * FROM #expectedVariables WHERE [VariableOrdinal]<=CASE WHEN @LimitPass=1 THEN 1 ELSE 4 END)
       OR EXISTS (SELECT * FROM #expectedVariables WHERE [VariableOrdinal]<=CASE WHEN @LimitPass=1 THEN 1 ELSE 4 END EXCEPT SELECT * FROM #ssisVariables)
       OR (@LimitPass=1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.warnings') WITH ([WarningCode] varchar(64)) WHERE [WarningCode]='VARIABLES_TRUNCATED'))
       OR (@LimitPass>1 AND EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.warnings') WITH ([WarningCode] varchar(64)) WHERE [WarningCode]='VARIABLES_TRUNCATED'))
       OR (@LimitPass=1 AND NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus') WITH ([SourceName] nvarchar(160),[StatusCode] varchar(40),[IsPartial] bit,[ReturnedRowCount] bigint) WHERE [SourceName]=N'DTSX variables' AND [StatusCode]='TRUNCATED' AND [IsPartial]=1 AND [ReturnedRowCount]=1))
       THROW 56109,N'SSIS-001 variable common export limit or selection failed.',1;
    SET @LimitPass+=1;
END;

DECLARE @EventHandlerXml xml=N'<DTS:Executable xmlns:DTS="www.microsoft.com/SqlServer/Dts" DTS:refId="Package" DTS:ObjectName="Fixture Package" DTS:ExecutableType="Microsoft.Package"><DTS:Variables><DTS:Variable DTS:ObjectName="Visible"><DTS:VariableValue DTS:DataType="3">1</DTS:VariableValue></DTS:Variable></DTS:Variables><DTS:EventHandlers><DTS:EventHandler DTS:refId="Handler" DTS:ObjectName="Fixture Handler"><DTS:Variables><DTS:Variable DTS:ObjectName="Excluded Handler"><DTS:VariableValue DTS:DataType="3">2</DTS:VariableValue></DTS:Variable></DTS:Variables><DTS:Executables><DTS:Executable DTS:refId="HandlerTask" DTS:ObjectName="Fixture Handler Task" DTS:ExecutableType="STOCK:SEQUENCE"><DTS:Variables><DTS:Variable DTS:ObjectName="Excluded Handler Task"><DTS:VariableValue DTS:DataType="3">3</DTS:VariableValue></DTS:Variable></DTS:Variables><DTS:Executables><DTS:Executable DTS:refId="NestedHandlerTask" DTS:ObjectName="Fixture Nested Handler Task" DTS:ExecutableType="STOCK:SQLTask"><DTS:Variables><DTS:Variable DTS:ObjectName="Excluded Nested Task"><DTS:VariableValue DTS:DataType="3">4</DTS:VariableValue></DTS:Variable></DTS:Variables></DTS:Executable></DTS:Executables></DTS:Executable></DTS:Executables></DTS:EventHandler></DTS:EventHandlers></DTS:Executable>';
EXEC(N'TRUNCATE TABLE #ssisVariables; ALTER TABLE #ssisVariables ADD [seed] int NULL; ALTER TABLE #ssisVariables DROP COLUMN [VariableOrdinal],[ScopeExecutableOrdinal],[VariableNamespace],[VariableName],[DataTypeCode],[IsReadOnly],[EvaluateAsExpression],[SourceStatus];');
EXEC(N'TRUNCATE TABLE #ssisModuleStatus; ALTER TABLE #ssisModuleStatus ADD [seed] int NULL; ALTER TABLE #ssisModuleStatus DROP COLUMN [ModuleName],[CollectionTimeUtc],[SchemaVersion],[StatusCode],[IsPartial],[PackageCount],[ExecutableCount],[FindingCount],[ErrorNumber],[ErrorMessage];');
EXEC [monitor].[USP_SsisPackageAnalysis] @PackageXml=@EventHandlerXml,@ResultSetArt='TABLE',@ResultTablesJson=N'{"variables":"#ssisVariables","moduleStatus":"#ssisModuleStatus"}',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF (SELECT COUNT(*) FROM #ssisVariables)<>1 OR NOT EXISTS(SELECT 1 FROM #ssisVariables WHERE [VariableName]=N'Visible' AND [VariableNamespace]=N'')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.warnings') WITH ([WarningCode] varchar(64)) WHERE [WarningCode]='VARIABLES_EVENT_HANDLER_SCOPE_NOT_SUPPORTED')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus') WITH ([SourceName] nvarchar(160),[IsPartial] bit) WHERE [SourceName]=N'DTSX variables' AND [IsPartial]=1)
    OR NOT EXISTS (SELECT 1 FROM #ssisModuleStatus WHERE [SchemaVersion]=3)
    THROW 56110,N'SSIS-001 Event-Handler scope boundary or partial TABLE mapping failed.',1;

DECLARE @MalformedVariableXml xml=N'<DTS:Executable xmlns:DTS="www.microsoft.com/SqlServer/Dts" DTS:refId="Package" DTS:ObjectName="Fixture Package" DTS:ExecutableType="Microsoft.Package"><DTS:Variables><DTS:Variable DTS:ReadOnly="unexpected" DTS:EvaluateAsExpression="unexpected"><DTS:VariableValue DTS:DataType="unexpected">fixture</DTS:VariableValue></DTS:Variable></DTS:Variables></DTS:Executable>';
EXEC(N'TRUNCATE TABLE #ssisVariables; ALTER TABLE #ssisVariables ADD [seed] int NULL; ALTER TABLE #ssisVariables DROP COLUMN [VariableOrdinal],[ScopeExecutableOrdinal],[VariableNamespace],[VariableName],[DataTypeCode],[IsReadOnly],[EvaluateAsExpression],[SourceStatus];');
EXEC [monitor].[USP_SsisPackageAnalysis] @PackageXml=@MalformedVariableXml,@ResultSetArt='TABLE',@ResultTablesJson=N'{"variables":"#ssisVariables"}',@JsonErzeugen=1,@Json=@Json OUTPUT;
IF (SELECT COUNT(*) FROM #ssisVariables)<>1 OR NOT EXISTS(SELECT 1 FROM #ssisVariables WHERE [VariableName] IS NULL AND [DataTypeCode] IS NULL AND [IsReadOnly] IS NULL AND [EvaluateAsExpression] IS NULL AND [SourceStatus]='AVAILABLE_LIMITED')
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.variables[0]') WHERE [key]='VariableName' AND [type]=0)
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.variables[0]') WHERE [key]='DataTypeCode' AND [type]=0)
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus') WITH ([SourceName] nvarchar(160),[StatusCode] varchar(40),[IsPartial] bit) WHERE [SourceName]=N'DTSX variables' AND [StatusCode]='AVAILABLE_LIMITED' AND [IsPartial]=1)
    THROW 56111,N'SSIS-001 malformed variable metadata contract failed.',1;

SET @MalformedVariableXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; replace value of (/DTS:Executable/DTS:Variables/DTS:Variable/@DTS:ReadOnly)[1] with ""');
SET @MalformedVariableXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; replace value of (/DTS:Executable/DTS:Variables/DTS:Variable/@DTS:EvaluateAsExpression)[1] with ""');
EXEC(N'TRUNCATE TABLE #ssisVariables; ALTER TABLE #ssisVariables ADD [seed] int NULL; ALTER TABLE #ssisVariables DROP COLUMN [VariableOrdinal],[ScopeExecutableOrdinal],[VariableNamespace],[VariableName],[DataTypeCode],[IsReadOnly],[EvaluateAsExpression],[SourceStatus];');
EXEC [monitor].[USP_SsisPackageAnalysis] @PackageXml=@MalformedVariableXml,@ResultSetArt='TABLE',@ResultTablesJson=N'{"variables":"#ssisVariables"}';
IF NOT EXISTS (SELECT 1 FROM #ssisVariables WHERE [IsReadOnly] IS NULL AND [EvaluateAsExpression] IS NULL AND [SourceStatus]='AVAILABLE_LIMITED')
    THROW 56114,N'SSIS-001 explicit empty booleans must not become False defaults.',1;

DECLARE @MissingScopePass int=1,@MissingScopeXml xml;
WHILE @MissingScopePass<=3
BEGIN
    SET @MissingScopeXml=@PackageXml;
    IF @MissingScopePass=1 SET @MissingScopeXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; delete /DTS:Executable/@DTS:refId');
    IF @MissingScopePass=2 SET @MissingScopeXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; delete /DTS:Executable/DTS:Executables/DTS:Executable[@DTS:refId="Sequence"]/@DTS:refId');
    IF @MissingScopePass=3 SET @MissingScopeXml.modify(N'declare namespace DTS="www.microsoft.com/SqlServer/Dts"; delete /DTS:Executable/DTS:Executables/DTS:Executable[@DTS:refId="Sequence"]/DTS:Executables/DTS:Executable[@DTS:refId="TaskA"]/@DTS:refId');
    EXEC(N'TRUNCATE TABLE #ssisVariables; ALTER TABLE #ssisVariables ADD [seed] int NULL; ALTER TABLE #ssisVariables DROP COLUMN [VariableOrdinal],[ScopeExecutableOrdinal],[VariableNamespace],[VariableName],[DataTypeCode],[IsReadOnly],[EvaluateAsExpression],[SourceStatus];');
    EXEC [monitor].[USP_SsisPackageAnalysis] @PackageXml=@MissingScopeXml,@ResultSetArt='TABLE',@ResultTablesJson=N'{"variables":"#ssisVariables"}',@JsonErzeugen=1,@Json=@Json OUTPUT;
    IF (SELECT COUNT(*) FROM #ssisVariables)>=4
       OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.warnings') WITH ([WarningCode] varchar(64)) WHERE [WarningCode]='VARIABLES_SCOPE_UNRESOLVED')
       OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus') WITH ([SourceName] nvarchar(160),[StatusCode] varchar(40),[IsPartial] bit) WHERE [SourceName]=N'DTSX variables' AND [StatusCode]='AVAILABLE_LIMITED' AND [IsPartial]=1)
       THROW 56115,N'SSIS-001 missing root/container/task reference must remain partial.',1;
    SET @MissingScopePass+=1;
END;

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

IF COALESCE(JSON_QUERY(@Json,'$.variables'),N'')<>N'[]'
    OR NOT EXISTS (SELECT 1 FROM OPENJSON(@Json,'$.sourceStatus') WITH ([SourceName] nvarchar(160),[StatusCode] varchar(40)) WHERE [SourceName]=N'DTSX variables' AND [StatusCode]='AVAILABLE_EMPTY')
    THROW 56112,N'SSIS-001 empty variable inventory contract failed.',1;

EXEC(N'TRUNCATE TABLE #ssisVariables; ALTER TABLE #ssisVariables ADD [seed] int NULL; ALTER TABLE #ssisVariables DROP COLUMN [VariableOrdinal],[ScopeExecutableOrdinal],[VariableNamespace],[VariableName],[DataTypeCode],[IsReadOnly],[EvaluateAsExpression],[SourceStatus];');
EXEC [monitor].[USP_SsisPackageAnalysis] @PackageXml=@PackageXml,@MaxZeilen=-1,@ResultSetArt='TABLE',@ResultTablesJson=N'{"variables":"#ssisVariables"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT;
IF @StatusCode<>'INVALID_PARAMETER' OR EXISTS(SELECT 1 FROM #ssisVariables) OR COALESCE(JSON_QUERY(@Json,'$.variables'),N'')<>N'[]'
    THROW 56113,N'SSIS-001 invalid limit empty export contract failed.',1;

EXEC [monitor].[USP_SsisPackageAnalysis]
      @PackageXml = @PackageXml
    , @ResultSetArt = 'RAW'
    , @StatusCodeOut = @StatusCode OUTPUT
    , @IsPartialOut = @IsPartial OUTPUT
    , @ErrorNumberOut = @ErrorNumber OUTPUT
    , @ErrorMessageOut = @ErrorMessage OUTPUT;

IF @StatusCode <> 'AVAILABLE_LIMITED' OR @IsPartial <> 1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
    THROW 56106, N'SSIS-001 parser RAW output contract failed.', 1;


DECLARE @SavedEntryLockTimeout int=@@LOCK_TIMEOUT;
DECLARE @TestLockTimeout int=CASE WHEN @@LOCK_TIMEOUT<>4321 THEN 4321 ELSE 4322 END;
DECLARE @LockTimeoutTestSql nvarchar(max)=N'DECLARE @StatusCode varchar(40), @IsPartial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @Json nvarchar(max);
CREATE TABLE #DurationPackageNull([seed] int NULL);
CREATE TABLE #DurationPackageZero([seed] int NULL);
CREATE TABLE #DurationPackageNegative([seed] int NULL);
CREATE TABLE #DurationPackageAboveMax([seed] int NULL);
CREATE TABLE #DurationPackageIntMin([seed] int NULL);
CREATE TABLE #DurationPackageIntMax([seed] int NULL);
CREATE TABLE #DurationPackageEmptyText([seed] int NULL);
CREATE TABLE #DurationPackageOne([seed] int NULL);
CREATE TABLE #DurationPackageThirty([seed] int NULL);
CREATE TABLE #DurationPackageSixty([seed] int NULL);
CREATE TABLE #DurationPackageDefault([seed] int NULL);
DECLARE @LockTimeoutValues TABLE ([Pass] int PRIMARY KEY, [Value] int NULL);
INSERT @LockTimeoutValues VALUES (1,NULL),(2,-2),(3,-1),(4,60001),(5,2147483647);
DECLARE @LockTimeoutPass int=1,@RequestedLockTimeout int,@LockTimeoutCaught bit;
SET LOCK_TIMEOUT {{TIMEOUT_SENTINEL}};
WHILE @LockTimeoutPass<=5
BEGIN
    SELECT @RequestedLockTimeout=[Value] FROM @LockTimeoutValues WHERE [Pass]=@LockTimeoutPass;
    SET @StatusCode=''OUTPUT_SENTINEL''; SET @IsPartial=0; SET @ErrorNumber=73117;
    SET @ErrorMessage=N''OUTPUT_SENTINEL''; SET @Json=N''OUTPUT_SENTINEL'';
    SET @LockTimeoutCaught=0;
    BEGIN TRY
        EXEC [monitor].[USP_SsisPackageAnalysis]
             @PackageXml=@PackageXml,@LockTimeoutMs=@RequestedLockTimeout,@ResultSetArt=''NONE'',
             @JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT,
             @IsPartialOut=@IsPartial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
    END TRY
    BEGIN CATCH
        SET @LockTimeoutCaught=1;
    END CATCH;
    IF @LockTimeoutCaught=1
       THROW 56117,N''SSIS-001 invalid LockTimeoutMs raised an unexpected SQL exception.'',1;
    IF COALESCE(@StatusCode,'''')<>''INVALID_PARAMETER'' OR COALESCE(@IsPartial,0)<>1 OR @ErrorNumber IS NOT NULL
       OR NULLIF(@ErrorMessage,N'''') IS NULL OR @ErrorMessage=N''OUTPUT_SENTINEL'' OR @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}}
       THROW 56117,N''SSIS-001 invalid LockTimeoutMs must return a diagnostic without changing caller LOCK_TIMEOUT.'',1;
    SET @LockTimeoutPass+=1;
END;

DECLARE @LockTimeoutControls TABLE ([Pass] int PRIMARY KEY, [Value] int NULL);
INSERT @LockTimeoutControls VALUES (1,0),(2,1),(3,60000);
DECLARE @LockTimeoutControlPass int=1;
WHILE @LockTimeoutControlPass<=3
BEGIN
    SELECT @RequestedLockTimeout=[Value] FROM @LockTimeoutControls WHERE [Pass]=@LockTimeoutControlPass;
    SET @StatusCode=''OUTPUT_SENTINEL''; SET @IsPartial=0; SET @ErrorNumber=73118;
    SET @ErrorMessage=N''OUTPUT_SENTINEL''; SET @Json=N''OUTPUT_SENTINEL'';
    EXEC [monitor].[USP_SsisPackageAnalysis]
         @PackageXml=@PackageXml,@LockTimeoutMs=@RequestedLockTimeout,@ResultSetArt=''NONE'',
         @JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT,
         @IsPartialOut=@IsPartial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
    IF COALESCE(@StatusCode,'''')<>''AVAILABLE_LIMITED'' OR COALESCE(@IsPartial,0)<>1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
       OR @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}} OR COALESCE(JSON_VALUE(@Json,''$.package[0].PackageName''),N'''')<>N''SSIS-001 Runtime Fixture''
       THROW 56118,N''SSIS-001 valid LockTimeoutMs must retain parsed output and caller LOCK_TIMEOUT.'',1;
    SET @LockTimeoutControlPass+=1;
END;
SET @StatusCode=''OUTPUT_SENTINEL''; SET @IsPartial=0; SET @ErrorNumber=73119;
SET @ErrorMessage=N''OUTPUT_SENTINEL''; SET @Json=N''OUTPUT_SENTINEL'';
EXEC [monitor].[USP_SsisPackageAnalysis]
     @PackageXml=@PackageXml,@ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@Json OUTPUT,
     @StatusCodeOut=@StatusCode OUTPUT,@IsPartialOut=@IsPartial OUTPUT,
     @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
IF COALESCE(@StatusCode,'''')<>''AVAILABLE_LIMITED'' OR COALESCE(@IsPartial,0)<>1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
   OR @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}} OR COALESCE(JSON_VALUE(@Json,''$.package[0].PackageName''),N'''')<>N''SSIS-001 Runtime Fixture''
   THROW 56119,N''SSIS-001 default LockTimeoutMs must retain parsed output and caller LOCK_TIMEOUT.'',1;
-- Validate the empty-package oracle with synthetic JSON shapes before procedure calls.
DECLARE @PackageJsonFixtures TABLE ([FixtureId] int PRIMARY KEY,[Payload] nvarchar(max) NULL,[ExpectedEmptyArray] bit NOT NULL);
INSERT @PackageJsonFixtures VALUES
 (1,N''{"package":[]}'',1),(2,N''{"package":[  ]}'',1),(3,NULL,0),(4,N''{}'',0),
 (5,N''{"package":null}'',0),(6,N''{"package":"[]"}'',0),(7,N''{"package":{}}'',0),
 (8,N''{"package":[{}]}'',0),(9,N''{"package":[null]}'',0),(10,N''invalid JSON'',0),
 (11,N''{"package":[],"package":[]}'',0),(12,N''{"Package":[]}'',0);
DECLARE @PackageJsonFixtureId int=1,@PackageJsonFixture nvarchar(max),@ExpectedEmptyArray bit,@ActualEmptyArray bit;
DECLARE @PackageArrayCount int,@PackageArrayType int,@PackageArray nvarchar(max);
WHILE @PackageJsonFixtureId<=12
BEGIN
    SELECT @PackageJsonFixture=[Payload],@ExpectedEmptyArray=[ExpectedEmptyArray]
    FROM @PackageJsonFixtures WHERE [FixtureId]=@PackageJsonFixtureId;
    SELECT @PackageArrayCount=COUNT(*),@PackageArrayType=MAX([type]),@PackageArray=MAX([value])
    FROM OPENJSON(CASE WHEN ISJSON(@PackageJsonFixture)=1 THEN @PackageJsonFixture ELSE N''{}'' END)
    WHERE [key] COLLATE SQL_Latin1_General_CP1_CS_AS=N''package'';
    SET @ActualEmptyArray=CASE WHEN ISJSON(@PackageJsonFixture)=1 AND @PackageArrayCount=1 AND @PackageArrayType=4
        AND NOT EXISTS(SELECT 1 FROM OPENJSON(CASE WHEN @PackageArrayCount=1 AND @PackageArrayType=4 THEN @PackageArray ELSE N''[]'' END))
        THEN 1 ELSE 0 END;
    IF @ActualEmptyArray<>@ExpectedEmptyArray
        THROW 56215,N''SSIS-001 semantic empty-package JSON oracle rejected its synthetic shape contract.'',1;
    SET @PackageJsonFixtureId+=1;
END;

DECLARE @MaxDurationValues TABLE ([Pass] int PRIMARY KEY, [Value] int NULL, [TargetName] sysname NOT NULL);
INSERT @MaxDurationValues VALUES
    (1,NULL,N''#DurationPackageNull''),
    (2,0,N''#DurationPackageZero''),
    (3,-1,N''#DurationPackageNegative''),
    (4,61,N''#DurationPackageAboveMax''),
    (5,-2147483648,N''#DurationPackageIntMin''),
    (6,2147483647,N''#DurationPackageIntMax'');
DECLARE @MaxDurationPass int=1,@RequestedDurationSeconds int,@DurationTarget sysname,@DurationTablesJson nvarchar(400);
WHILE @MaxDurationPass<=6
BEGIN
    SELECT @RequestedDurationSeconds=[Value],@DurationTarget=[TargetName] FROM @MaxDurationValues WHERE [Pass]=@MaxDurationPass;
    SET @DurationTablesJson=N''{"package":"'' + @DurationTarget + N''"}'';
    SET @StatusCode=''OUTPUT_SENTINEL''; SET @IsPartial=0; SET @ErrorNumber=73121;
    SET @ErrorMessage=N''OUTPUT_SENTINEL''; SET @Json=N''OUTPUT_SENTINEL'';
    BEGIN TRY
        EXEC [monitor].[USP_SsisPackageAnalysis]
             @PackageXml=@PackageXml,@MaxDurationSeconds=@RequestedDurationSeconds,
             @ResultSetArt=''TABLE'',@ResultTablesJson=@DurationTablesJson,
             @JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT,
             @IsPartialOut=@IsPartial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH;
    DECLARE @DurationFailureMessage nvarchar(2048);
    IF COALESCE(@StatusCode,'''')<>''INVALID_PARAMETER'' OR COALESCE(@IsPartial,0)<>1
       OR @ErrorNumber IS NOT NULL OR NULLIF(@ErrorMessage,N'''') IS NULL OR @ErrorMessage=N''OUTPUT_SENTINEL''
    BEGIN
        SET @DurationFailureMessage=CONCAT(N''SSIS-001 MaxDurationSeconds diagnostic; Pass='',@MaxDurationPass,N''; Predicate=status_outputs; Target='',@DurationTarget);
        THROW 56211,@DurationFailureMessage,1;
    END;
    IF @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}}
    BEGIN
        SET @DurationFailureMessage=CONCAT(N''SSIS-001 MaxDurationSeconds diagnostic; Pass='',@MaxDurationPass,N''; Predicate=caller_lock_timeout; Target='',@DurationTarget);
        THROW 56212,@DurationFailureMessage,1;
    END;
    IF EXISTS(SELECT 1 FROM #DurationPackageNull UNION ALL SELECT 1 FROM #DurationPackageZero UNION ALL SELECT 1 FROM #DurationPackageNegative UNION ALL SELECT 1 FROM #DurationPackageAboveMax UNION ALL SELECT 1 FROM #DurationPackageIntMin UNION ALL SELECT 1 FROM #DurationPackageIntMax)
    BEGIN
        SET @DurationFailureMessage=CONCAT(N''SSIS-001 MaxDurationSeconds diagnostic; Pass='',@MaxDurationPass,N''; Predicate=package_inventory; Target='',@DurationTarget);
        THROW 56213,@DurationFailureMessage,1;
    END;
    SELECT @PackageArrayCount=COUNT(*),@PackageArrayType=MAX([type]),@PackageArray=MAX([value])
    FROM OPENJSON(CASE WHEN ISJSON(@Json)=1 THEN @Json ELSE N''{}'' END)
    WHERE [key] COLLATE SQL_Latin1_General_CP1_CS_AS=N''package'';
    IF ISNULL(ISJSON(@Json),0)<>1 OR @PackageArrayCount<>1 OR ISNULL(@PackageArrayType,-1)<>4
       OR EXISTS(SELECT 1 FROM OPENJSON(CASE WHEN @PackageArrayCount=1 AND @PackageArrayType=4 THEN @PackageArray ELSE N''[]'' END))
    BEGIN
        SET @DurationFailureMessage=CONCAT(N''SSIS-001 MaxDurationSeconds diagnostic; Pass='',@MaxDurationPass,N''; Predicate=json_package; Target='',@DurationTarget,N''; JsonValid='',ISNULL(ISJSON(@Json),0),N''; PackageKeys='',@PackageArrayCount,N''; PackageType='',ISNULL(@PackageArrayType,-1),N''; ArrayBytes='',CASE WHEN @PackageArrayCount=1 AND @PackageArrayType=4 THEN DATALENGTH(@PackageArray) ELSE NULL END);
        THROW 56214,@DurationFailureMessage,1;
    END;
    IF @MaxDurationPass=1
        PRINT CONCAT(N''SSIS-001 empty package JSON proof; JsonValid='',ISNULL(ISJSON(@Json),0),
            N''; PackageKeys='',@PackageArrayCount,N''; PackageType='',@PackageArrayType,N''; Elements=0'',
            N''; ArrayBytes='',DATALENGTH(@PackageArray),N''; QueryBytes='',DATALENGTH(JSON_QUERY(@Json,''$.package'')),
            N''; QueryIsNull='',CASE WHEN JSON_QUERY(@Json,''$.package'') IS NULL THEN 1 ELSE 0 END,
            N''; LegacyExactMatch='',CASE WHEN COALESCE(JSON_QUERY(@Json,''$.package''),N'''')=N''[]'' THEN 1 ELSE 0 END);
    SET @MaxDurationPass+=1;
END;

SET @DurationTarget=N''#DurationPackageEmptyText'';
SET @DurationTablesJson=N''{"package":"'' + @DurationTarget + N''"}'';
SET @StatusCode=''OUTPUT_SENTINEL''; SET @IsPartial=0; SET @ErrorNumber=73124;
SET @ErrorMessage=N''OUTPUT_SENTINEL''; SET @Json=N''OUTPUT_SENTINEL'';
BEGIN TRY
    EXEC [monitor].[USP_SsisPackageAnalysis]
         @PackageXml=@PackageXml,@MaxDurationSeconds='''',
         @ResultSetArt=''TABLE'',@ResultTablesJson=@DurationTablesJson,
         @JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT,
         @IsPartialOut=@IsPartial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
END TRY
BEGIN CATCH
    THROW;
END CATCH;
SELECT @PackageArrayCount=COUNT(*),@PackageArrayType=MAX([type]),@PackageArray=MAX([value])
    FROM OPENJSON(CASE WHEN ISJSON(@Json)=1 THEN @Json ELSE N''{}'' END)
    WHERE [key] COLLATE SQL_Latin1_General_CP1_CS_AS=N''package'';
IF COALESCE(@StatusCode,'''')<>''INVALID_PARAMETER'' OR COALESCE(@IsPartial,0)<>1 OR @ErrorNumber IS NOT NULL
   OR NULLIF(@ErrorMessage,N'''') IS NULL OR @ErrorMessage=N''OUTPUT_SENTINEL''
   OR @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}} OR EXISTS(SELECT 1 FROM #DurationPackageNull UNION ALL SELECT 1 FROM #DurationPackageZero UNION ALL SELECT 1 FROM #DurationPackageNegative UNION ALL SELECT 1 FROM #DurationPackageAboveMax UNION ALL SELECT 1 FROM #DurationPackageIntMin UNION ALL SELECT 1 FROM #DurationPackageIntMax UNION ALL SELECT 1 FROM #DurationPackageEmptyText)
   OR ISNULL(ISJSON(@Json),0)<>1 OR @PackageArrayCount<>1 OR ISNULL(@PackageArrayType,-1)<>4
       OR EXISTS(SELECT 1 FROM OPENJSON(CASE WHEN @PackageArrayCount=1 AND @PackageArrayType=4 THEN @PackageArray ELSE N''[]'' END))
    THROW 56124,N''SSIS-001 empty MaxDurationSeconds text must convert to invalid zero without package inventory.'',1;

DECLARE @MaxDurationControls TABLE ([Pass] int PRIMARY KEY, [Value] int, [TargetName] sysname NOT NULL);
INSERT @MaxDurationControls VALUES
    (1,1,N''#DurationPackageOne''),
    (2,30,N''#DurationPackageThirty''),
    (3,60,N''#DurationPackageSixty'');
DECLARE @MaxDurationControlPass int=1;
WHILE @MaxDurationControlPass<=3
BEGIN
    SELECT @RequestedDurationSeconds=[Value],@DurationTarget=[TargetName] FROM @MaxDurationControls WHERE [Pass]=@MaxDurationControlPass;
    SET @DurationTablesJson=N''{"package":"'' + @DurationTarget + N''"}'';
    SET @StatusCode=''OUTPUT_SENTINEL''; SET @IsPartial=0; SET @ErrorNumber=73122;
    SET @ErrorMessage=N''OUTPUT_SENTINEL''; SET @Json=N''OUTPUT_SENTINEL'';
    EXEC [monitor].[USP_SsisPackageAnalysis]
         @PackageXml=@PackageXml,@MaxDurationSeconds=@RequestedDurationSeconds,
         @ResultSetArt=''TABLE'',@ResultTablesJson=@DurationTablesJson,
         @JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT,
         @IsPartialOut=@IsPartial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
    IF COALESCE(@StatusCode,'''')<>''AVAILABLE_LIMITED'' OR COALESCE(@IsPartial,0)<>1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
       OR @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}} OR (@MaxDurationControlPass=1 AND (SELECT COUNT(*) FROM #DurationPackageOne)<>1)
       OR (@MaxDurationControlPass=2 AND (SELECT COUNT(*) FROM #DurationPackageThirty)<>1)
       OR (@MaxDurationControlPass=3 AND (SELECT COUNT(*) FROM #DurationPackageSixty)<>1)
       OR COALESCE(JSON_VALUE(@Json,''$.package[0].PackageName''),N'''')<>N''SSIS-001 Runtime Fixture''
       THROW 56122,N''SSIS-001 valid MaxDurationSeconds must retain package inventory and caller LOCK_TIMEOUT.'',1;
    SET @MaxDurationControlPass+=1;
END;
SET @DurationTarget=N''#DurationPackageDefault'';
SET @DurationTablesJson=N''{"package":"'' + @DurationTarget + N''"}'';
SET @StatusCode=''OUTPUT_SENTINEL''; SET @IsPartial=0; SET @ErrorNumber=73123;
SET @ErrorMessage=N''OUTPUT_SENTINEL''; SET @Json=N''OUTPUT_SENTINEL'';
EXEC [monitor].[USP_SsisPackageAnalysis]
     @PackageXml=@PackageXml,@ResultSetArt=''TABLE'',@ResultTablesJson=@DurationTablesJson,
     @JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT,
     @IsPartialOut=@IsPartial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
IF COALESCE(@StatusCode,'''')<>''AVAILABLE_LIMITED'' OR COALESCE(@IsPartial,0)<>1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
   OR @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}} OR (SELECT COUNT(*) FROM #DurationPackageDefault)<>1
   OR COALESCE(JSON_VALUE(@Json,''$.package[0].PackageName''),N'''')<>N''SSIS-001 Runtime Fixture''
    THROW 56123,N''SSIS-001 default MaxDurationSeconds must retain package inventory and caller LOCK_TIMEOUT.'',1;


-- Observe in-work LOCK_TIMEOUT scope in a guarded, source-bound test copy.
-- Public calls above remain the validation, output, and caller-state oracle.
CREATE TABLE #SsisLockTimeoutObservation([Stage] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TimeoutMs] int NOT NULL);
CREATE TABLE #SsisLockTimeoutProbeControl([RaiseAtBeforePreflight] bit NOT NULL);
INSERT #SsisLockTimeoutProbeControl VALUES(0);
CREATE TABLE #SsisLockScopePackageZero([seed] int NULL);
CREATE TABLE #SsisLockScopePackageOne([seed] int NULL);
CREATE TABLE #SsisLockScopePackageMax([seed] int NULL);
CREATE TABLE #SsisLockScopePackageDefault([seed] int NULL);
DECLARE @ScopeDefinition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N''monitor.USP_SsisPackageAnalysis''));
DECLARE @ScopeHeader nvarchar(max)=CASE
    WHEN CHARINDEX(N''CREATE OR ALTER PROCEDURE [monitor].[USP_SsisPackageAnalysis]'',@ScopeDefinition)>0
        THEN N''CREATE OR ALTER PROCEDURE [monitor].[USP_SsisPackageAnalysis]''
    WHEN CHARINDEX(N''CREATE PROCEDURE [monitor].[USP_SsisPackageAnalysis]'',@ScopeDefinition)>0
        THEN N''CREATE PROCEDURE [monitor].[USP_SsisPackageAnalysis]''
    WHEN CHARINDEX(N''ALTER PROCEDURE [monitor].[USP_SsisPackageAnalysis]'',@ScopeDefinition)>0
        THEN N''ALTER PROCEDURE [monitor].[USP_SsisPackageAnalysis]''
    ELSE NULL END;
DECLARE @ScopeSelfCall nvarchar(max)=N''EXEC @ScopedReturnCodeOut = [monitor].[USP_SsisPackageAnalysis]'';
DECLARE @ScopeBeforePreflight nvarchar(max)=N''    CREATE TABLE [#SsisPackageAnalysis_ResultTables]'';
DECLARE @ScopeParser nvarchar(max)=N''    IF @StatusCode = ''''AVAILABLE_LIMITED''''
       AND @PackageXml.exist(''''/*[local-name(.)="Executable" and namespace-uri(.)="www.microsoft.com/SqlServer/Dts"]'''') = 0'';
DECLARE @ScopeTable nvarchar(max)=N''    IF @TableRequested = 1
    BEGIN
        DECLARE @TargetTable sysname;'';
IF @ScopeDefinition IS NULL OR @ScopeHeader IS NULL
   OR (DATALENGTH(@ScopeDefinition)-DATALENGTH(REPLACE(@ScopeDefinition,@ScopeHeader,N'''')))<>DATALENGTH(@ScopeHeader)
   OR (DATALENGTH(@ScopeDefinition)-DATALENGTH(REPLACE(@ScopeDefinition,@ScopeSelfCall,N'''')))<>DATALENGTH(@ScopeSelfCall)
   OR (DATALENGTH(@ScopeDefinition)-DATALENGTH(REPLACE(@ScopeDefinition,@ScopeBeforePreflight,N'''')))<>DATALENGTH(@ScopeBeforePreflight)
   OR (DATALENGTH(@ScopeDefinition)-DATALENGTH(REPLACE(@ScopeDefinition,@ScopeParser,N'''')))<>DATALENGTH(@ScopeParser)
   OR (DATALENGTH(@ScopeDefinition)-DATALENGTH(REPLACE(@ScopeDefinition,@ScopeTable,N'''')))<>DATALENGTH(@ScopeTable)
    THROW 56220,N''SSIS-001 current module does not match the unique lock-scope probe anchors.'',1;
DECLARE @ScopeProbeHeader nvarchar(max)=N''CREATE PROCEDURE [monitor].[InternalSsisPackageLockTimeoutScopeProbe]'';
DECLARE @ScopeProbeSelfCall nvarchar(max)=N''EXEC @ScopedReturnCodeOut = [monitor].[InternalSsisPackageLockTimeoutScopeProbe]'';
DECLARE @ScopeInjectedBeforePreflight nvarchar(max)=N''    INSERT #SsisLockTimeoutObservation([Stage],[TimeoutMs]) VALUES (''''BeforePreflight'''',@@LOCK_TIMEOUT);
    IF EXISTS(SELECT 1 FROM #SsisLockTimeoutProbeControl WHERE [RaiseAtBeforePreflight]=1)
        THROW 56224,N''''SSIS-001 deliberate in-procedure lock-timeout scope failure.'''',1;
    CREATE TABLE [#SsisPackageAnalysis_ResultTables]'';
DECLARE @ScopeInjectedParser nvarchar(max)=N''    INSERT #SsisLockTimeoutObservation([Stage],[TimeoutMs]) VALUES (''''BeforeParser'''',@@LOCK_TIMEOUT);
    IF @StatusCode = ''''AVAILABLE_LIMITED''''
       AND @PackageXml.exist(''''/*[local-name(.)="Executable" and namespace-uri(.)="www.microsoft.com/SqlServer/Dts"]'''') = 0'';
DECLARE @ScopeInjectedTable nvarchar(max)=N''    IF @TableRequested = 1
    BEGIN
        INSERT #SsisLockTimeoutObservation([Stage],[TimeoutMs]) VALUES (''''BeforeTableHelper'''',@@LOCK_TIMEOUT);
        DECLARE @TargetTable sysname;'';
DECLARE @ScopeProbeDefinition nvarchar(max)=REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@ScopeDefinition,@ScopeHeader,@ScopeProbeHeader),@ScopeSelfCall,@ScopeProbeSelfCall),@ScopeBeforePreflight,@ScopeInjectedBeforePreflight),@ScopeParser,@ScopeInjectedParser),@ScopeTable,@ScopeInjectedTable);
DECLARE @ScopeRoundTrip nvarchar(max)=REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@ScopeProbeDefinition,@ScopeProbeHeader,@ScopeHeader),@ScopeProbeSelfCall,@ScopeSelfCall),@ScopeInjectedBeforePreflight,@ScopeBeforePreflight),@ScopeInjectedParser,@ScopeParser),@ScopeInjectedTable,@ScopeTable);
IF DATALENGTH(@ScopeRoundTrip)<>DATALENGTH(@ScopeDefinition)
   OR HASHBYTES(''SHA2_256'',@ScopeRoundTrip)<>HASHBYTES(''SHA2_256'',@ScopeDefinition)
    THROW 56221,N''SSIS-001 instrumented lock-scope copy must preserve all other installed module text.'',1;
IF OBJECT_ID(N''monitor.InternalSsisPackageLockTimeoutScopeProbe'',N''P'') IS NOT NULL
    THROW 56226,N''SSIS-001 lock-scope test fixture already exists; do not replace an existing object.'',1;
DECLARE @ScopeProbeCreated bit=0;
BEGIN TRY
    EXEC [sys].[sp_executesql] @ScopeProbeDefinition;
    SET @ScopeProbeCreated=1;
    DECLARE @ScopeValues TABLE([Pass] int PRIMARY KEY,[Value] int NOT NULL,[Target] sysname NOT NULL);
    INSERT @ScopeValues VALUES(1,0,N''#SsisLockScopePackageZero''),(2,1,N''#SsisLockScopePackageOne''),(3,60000,N''#SsisLockScopePackageMax''),(4,0,N''#SsisLockScopePackageDefault'');
    DECLARE @ScopePass int=1,@ScopeRequested int,@ScopeTarget sysname,@ScopeTablesJson nvarchar(400),@ScopeReturnCode int;
    WHILE @ScopePass<=4
    BEGIN
        SELECT @ScopeRequested=[Value],@ScopeTarget=[Target] FROM @ScopeValues WHERE [Pass]=@ScopePass;
        TRUNCATE TABLE #SsisLockTimeoutObservation;
        SET @ScopeTablesJson=N''{"package":"''+@ScopeTarget+N''"}'';
        SET @StatusCode=''OUTPUT_SENTINEL''; SET @IsPartial=0; SET @ErrorNumber=73130;
        SET @ErrorMessage=N''OUTPUT_SENTINEL''; SET @Json=N''OUTPUT_SENTINEL''; SET @ScopeReturnCode=-73130;
        IF @ScopePass=4
            EXEC @ScopeReturnCode = [monitor].[InternalSsisPackageLockTimeoutScopeProbe] @PackageXml=@PackageXml,@ResultSetArt=''TABLE'',@ResultTablesJson=@ScopeTablesJson,
                @JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT,@IsPartialOut=@IsPartial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
        ELSE
            EXEC @ScopeReturnCode = [monitor].[InternalSsisPackageLockTimeoutScopeProbe] @PackageXml=@PackageXml,@LockTimeoutMs=@ScopeRequested,@ResultSetArt=''TABLE'',@ResultTablesJson=@ScopeTablesJson,
                @JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT,@IsPartialOut=@IsPartial OUTPUT,@ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
        IF (SELECT COUNT(*) FROM #SsisLockTimeoutObservation)<>3
           OR (SELECT COUNT(*) FROM #SsisLockTimeoutObservation WHERE [Stage]=''BeforePreflight'' AND [TimeoutMs]=@ScopeRequested)<>1
           OR (SELECT COUNT(*) FROM #SsisLockTimeoutObservation WHERE [Stage]=''BeforeParser'' AND [TimeoutMs]=@ScopeRequested)<>1
           OR (SELECT COUNT(*) FROM #SsisLockTimeoutObservation WHERE [Stage]=''BeforeTableHelper'' AND [TimeoutMs]=@ScopeRequested)<>1
           OR (@ScopePass=1 AND (SELECT COUNT(*) FROM #SsisLockScopePackageZero)<>1)
           OR (@ScopePass=2 AND (SELECT COUNT(*) FROM #SsisLockScopePackageOne)<>1)
           OR (@ScopePass=3 AND (SELECT COUNT(*) FROM #SsisLockScopePackageMax)<>1)
           OR (@ScopePass=4 AND (SELECT COUNT(*) FROM #SsisLockScopePackageDefault)<>1)
           OR @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}}
           OR @ScopeReturnCode<>0
           OR COALESCE(@StatusCode,'''')<>''AVAILABLE_LIMITED'' OR COALESCE(@IsPartial,0)<>1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
           OR COALESCE(JSON_VALUE(@Json,''$.package[0].PackageName''),N'''')<>N''SSIS-001 Runtime Fixture''
            THROW 56222,N''SSIS-001 requested lock timeout must be observed before preflight setup, parser evaluation, and TABLE-helper calls and preserve caller state, return code, outputs, and package data.'',1;
        SET @ScopePass+=1;
    END;
    UPDATE #SsisLockTimeoutProbeControl SET [RaiseAtBeforePreflight]=1;
    TRUNCATE TABLE #SsisLockTimeoutObservation;
    DECLARE @ScopeFailureNumber int=NULL;
    BEGIN TRY
        EXEC [monitor].[InternalSsisPackageLockTimeoutScopeProbe] @PackageXml=@PackageXml,@LockTimeoutMs=1,@ResultSetArt=''NONE'';
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>56224 OR ERROR_MESSAGE()<>N''SSIS-001 deliberate in-procedure lock-timeout scope failure.'' OR ERROR_STATE()<>1
            THROW;
        SET @ScopeFailureNumber=ERROR_NUMBER();
    END CATCH;
    IF @ScopeFailureNumber IS NULL OR @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}}
       OR (SELECT COUNT(*) FROM #SsisLockTimeoutObservation WHERE [Stage]=''BeforePreflight'' AND [TimeoutMs]=1)<>1
       OR (SELECT COUNT(*) FROM #SsisLockTimeoutObservation)<>1
        THROW 56223,N''SSIS-001 procedure-scoped lock timeout must restore the caller after an in-scope SQL exception.'',1;
    DROP PROCEDURE [monitor].[InternalSsisPackageLockTimeoutScopeProbe];
    SET @ScopeProbeCreated=0;
END TRY
BEGIN CATCH
    IF @ScopeProbeCreated=1
        DROP PROCEDURE IF EXISTS [monitor].[InternalSsisPackageLockTimeoutScopeProbe];
    THROW;
END CATCH;

-- A synthetic principal receives EXECUTE on only a same-owner wrapper.
-- Four recursive wrapper steps exercise a bounded, ordinary nested call.
DECLARE @RestrictedUser sysname=N''SsisLockTimeoutSyntheticPrincipal'';
DECLARE @RestrictedWrapper sysname=N''InternalSsisLockTimeoutNestedCaller'';
IF DATABASE_PRINCIPAL_ID(@RestrictedUser) IS NOT NULL
   OR OBJECT_ID(N''monitor.InternalSsisLockTimeoutNestedCaller'',N''P'') IS NOT NULL
    THROW 56227,N''SSIS-001 restricted-principal fixtures already exist; do not replace them.'',1;
DECLARE @RestrictedUserCreated bit=0,@RestrictedWrapperCreated bit=0,@RestrictedContextEntered bit=0;
DECLARE @RestrictedRevertCookie varbinary(100)=NULL,@RestrictedReturnCode int=-73131;
DECLARE @RestrictedWrapperSql nvarchar(max)=N''CREATE PROCEDURE [monitor].[InternalSsisLockTimeoutNestedCaller]
      @Depth tinyint
    , @PackageXml xml
    , @LockTimeoutMs int
    , @Json nvarchar(max) OUTPUT
    , @StatusCodeOut varchar(40) OUTPUT
    , @IsPartialOut bit OUTPUT
    , @ErrorNumberOut int OUTPUT
    , @ErrorMessageOut nvarchar(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReturnCode int=0;
    DECLARE @NextDepth tinyint=@Depth+1;
    IF @Depth<4
        EXEC @ReturnCode=[monitor].[InternalSsisLockTimeoutNestedCaller]
              @Depth=@NextDepth,@PackageXml=@PackageXml,@LockTimeoutMs=@LockTimeoutMs
            , @Json=@Json OUTPUT,@StatusCodeOut=@StatusCodeOut OUTPUT,@IsPartialOut=@IsPartialOut OUTPUT
            , @ErrorNumberOut=@ErrorNumberOut OUTPUT,@ErrorMessageOut=@ErrorMessageOut OUTPUT;
    ELSE
        EXEC @ReturnCode=[monitor].[USP_SsisPackageAnalysis]
              @PackageXml=@PackageXml,@LockTimeoutMs=@LockTimeoutMs,@ResultSetArt=''''NONE''''
            , @JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@StatusCodeOut OUTPUT,@IsPartialOut=@IsPartialOut OUTPUT
            , @ErrorNumberOut=@ErrorNumberOut OUTPUT,@ErrorMessageOut=@ErrorMessageOut OUTPUT;
    RETURN @ReturnCode;
END;'';
BEGIN TRY
    CREATE USER [SsisLockTimeoutSyntheticPrincipal] WITHOUT LOGIN;
    SET @RestrictedUserCreated=1;
    EXEC [sys].[sp_executesql] @RestrictedWrapperSql;
    SET @RestrictedWrapperCreated=1;
    GRANT EXECUTE ON OBJECT::[monitor].[InternalSsisLockTimeoutNestedCaller] TO [SsisLockTimeoutSyntheticPrincipal];
    DENY EXECUTE ON OBJECT::[monitor].[USP_SsisPackageAnalysis] TO [SsisLockTimeoutSyntheticPrincipal];
    EXECUTE AS USER=N''SsisLockTimeoutSyntheticPrincipal'' WITH COOKIE INTO @RestrictedRevertCookie;
    SET @RestrictedContextEntered=1;
    IF ISNULL(HAS_PERMS_BY_NAME(N''monitor.USP_SsisPackageAnalysis'',N''OBJECT'',N''EXECUTE''),-1)<>0
        THROW 56229,N''SSIS-001 restricted principal must not have effective EXECUTE on the public procedure.'',1;
    SET @StatusCode=''OUTPUT_SENTINEL''; SET @IsPartial=0; SET @ErrorNumber=73131;
    SET @ErrorMessage=N''OUTPUT_SENTINEL''; SET @Json=N''OUTPUT_SENTINEL'';
    EXEC @RestrictedReturnCode=[monitor].[InternalSsisLockTimeoutNestedCaller]
          @Depth=0,@PackageXml=@PackageXml,@LockTimeoutMs=1
        , @Json=@Json OUTPUT,@StatusCodeOut=@StatusCode OUTPUT,@IsPartialOut=@IsPartial OUTPUT
        , @ErrorNumberOut=@ErrorNumber OUTPUT,@ErrorMessageOut=@ErrorMessage OUTPUT;
    REVERT WITH COOKIE=@RestrictedRevertCookie;
    SET @RestrictedContextEntered=0;
    IF @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}} OR @RestrictedReturnCode<>0
       OR COALESCE(@StatusCode,'''')<>''AVAILABLE_LIMITED'' OR COALESCE(@IsPartial,0)<>1
       OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NOT NULL
       OR COALESCE(JSON_VALUE(@Json,''$.package[0].PackageName''),N'''')<>N''SSIS-001 Runtime Fixture''
        THROW 56228,N''SSIS-001 restricted principal wrapper call must preserve package output, return code, and caller timeout.'',1;
    DROP PROCEDURE [monitor].[InternalSsisLockTimeoutNestedCaller];
    SET @RestrictedWrapperCreated=0;
    DROP USER [SsisLockTimeoutSyntheticPrincipal];
    SET @RestrictedUserCreated=0;
END TRY
BEGIN CATCH
    IF @RestrictedContextEntered=1
    BEGIN
        REVERT WITH COOKIE=@RestrictedRevertCookie;
        SET @RestrictedContextEntered=0;
    END;
    IF @RestrictedWrapperCreated=1
        DROP PROCEDURE IF EXISTS [monitor].[InternalSsisLockTimeoutNestedCaller];
    IF @RestrictedUserCreated=1
        DROP USER IF EXISTS [SsisLockTimeoutSyntheticPrincipal];
    THROW;
END CATCH;

IF @@LOCK_TIMEOUT<>{{TIMEOUT_SENTINEL}}
    THROW 56127,N''SSIS-001 scoped lock-timeout suite changed its local caller setting.'',1;';
SET @LockTimeoutTestSql=REPLACE(@LockTimeoutTestSql,N'{{TIMEOUT_SENTINEL}}',CONVERT(nvarchar(12),@TestLockTimeout));
BEGIN TRY
    EXEC [sys].[sp_executesql] @LockTimeoutTestSql,N'@PackageXml xml',@PackageXml=@PackageXml;
END TRY
BEGIN CATCH
    IF @@LOCK_TIMEOUT<>@SavedEntryLockTimeout
        PRINT N'SSIS-001 unexpected runtime assertion failed; outer caller LOCK_TIMEOUT changed before original error rethrow.';
    THROW;
END CATCH;
IF @@LOCK_TIMEOUT<>@SavedEntryLockTimeout
    THROW 56120,N'SSIS-001 scoped lock-timeout suite did not restore the actual caller entry value after success.',1;

DECLARE @FailureProbeSql nvarchar(max)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(12),@TestLockTimeout)+N'; THROW 56125,N''SSIS-001 deliberate scoped cleanup failure.'',1;';
DECLARE @FailureProbeErrorNumber int=NULL;
BEGIN TRY
    EXEC [sys].[sp_executesql] @FailureProbeSql;
END TRY
BEGIN CATCH
    IF @@LOCK_TIMEOUT<>@SavedEntryLockTimeout
        PRINT N'SSIS-001 deliberate failure scope changed the actual caller value before original error handling.';
    IF ERROR_NUMBER()<>56125
       OR ERROR_MESSAGE()<>N'SSIS-001 deliberate scoped cleanup failure.'
       OR ERROR_STATE()<>1
        THROW;
    SET @FailureProbeErrorNumber=ERROR_NUMBER();
END CATCH;
IF @FailureProbeErrorNumber IS NULL OR @FailureProbeErrorNumber<>56125
   OR @@LOCK_TIMEOUT<>@SavedEntryLockTimeout
    THROW 56128,N'SSIS-001 failure scope did not preserve the actual caller entry value.',1;

EXEC [monitor].[USP_SsisPackageAnalysis]
      @PackageXml = N'<root />'
    , @ResultSetArt = 'NONE'
    , @JsonErzeugen = 1
    , @Json = @Json OUTPUT
    , @StatusCodeOut = @StatusCode OUTPUT
    , @IsPartialOut = @IsPartial OUTPUT
    , @ErrorNumberOut = @ErrorNumber OUTPUT
    , @ErrorMessageOut = @ErrorMessage OUTPUT;

IF @StatusCode <> 'UNSUPPORTED_PACKAGE_FORMAT' OR @IsPartial <> 1 OR @ErrorNumber IS NOT NULL OR @ErrorMessage IS NULL
    THROW 56103, N'SSIS-001 unsupported-format contract failed.', 1;
IF COALESCE(JSON_QUERY(@Json,'$.variables'),N'')<>N'[]'
    THROW 56116,N'SSIS-001 unsupported input must retain the empty variables array.',1;
GO
