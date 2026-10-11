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
