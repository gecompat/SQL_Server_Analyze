[CmdletBinding()]
param(
    [string]$EnvironmentFile=$env:SQL_SERVER_LAB_TEST_ENV_FILE,
    [string]$SchemaFile=$env:SQL_SERVER_LAB_TEST_ENV_SCHEMA_FILE,
    [Parameter(Mandatory)][string]$ModelJsonPath,
    [Parameter(Mandatory)][string]$PackagePath,
    [string]$ExpectedPath=(Join-Path $PSScriptRoot '../Fixtures/SSIS_Exchange/direct-8.expected.json'),
    [ValidateSet('linux','windows')][string]$Platform='linux',
    [ValidateSet('2019','2022','2025')][string]$Version='2025',
    [string]$Patch='latest',
    [string]$ProducerAssemblyPath=''
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repositoryRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if (-not $EnvironmentFile -or -not $SchemaFile) { throw 'SSIS_MODEL_LAB_CONTRACT_MISSING' }
$contractText=Get-Content -LiteralPath $EnvironmentFile -Raw
if (-not ($contractText | Test-Json -SchemaFile $SchemaFile)) { throw 'SSIS_MODEL_LAB_SCHEMA_INVALID' }
$contract=$contractText | ConvertFrom-Json
if ($contract.groupStatus -cne 'READY') { throw 'SSIS_MODEL_LAB_GROUP_NOT_READY' }
$targets=@($contract.environments | Where-Object {$_.platform -ceq $Platform -and [string]$_.sqlVersion -ceq $Version -and $_.patch -ceq $Patch -and $_.status -ceq 'READY' -and $_.runtimeStatus -ceq 'READY'})
if ($targets.Count -ne 1) { throw 'SSIS_MODEL_EXACT_READY_TARGET_REQUIRED' }
$builder=[System.Data.SqlClient.SqlConnectionStringBuilder]::new($targets[0].connectionString)
if (-not $builder['Encrypt']) { throw 'SSIS_MODEL_ENCRYPT_REQUIRED' }
$builder['Initial Catalog']='master'
$connection=[System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$database='SyntheticSsisModel_'+[guid]::NewGuid().ToString('N')
$created=$false; $cases=0
$model=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $ModelJsonPath),[Text.Encoding]::UTF8)
$package=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $PackagePath))
$expected=Get-Content -LiteralPath $ExpectedPath -Raw | ConvertFrom-Json -Depth 32
function Query([string]$Sql) {
    $command=$connection.CreateCommand(); $command.CommandText=$Sql; $command.CommandTimeout=90
    try { $data=[Data.DataSet]::new(); $adapter=[Data.SqlClient.SqlDataAdapter]::new($command); [void]$adapter.Fill($data); return ,$data }
    finally { $command.Dispose() }
}
function Invoke-Model([string]$Payload,[string]$Mode='NONE',[int]$Limit=1000,[bool]$IncludeBytes=$false,[string]$PrefixSql='', [string]$Mapping=$null,[string]$SuffixSql='', [bool]$Views=$false,[bool]$Rules=$false) {
    $command=$connection.CreateCommand(); $command.CommandTimeout=90
    $command.CommandText=$PrefixSql+"`nEXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Payload,@PackageBytes=@Bytes,@ResultSetArt=@Mode,@MaxZeilen=@Limit,@IncludePackageViews=@Views,@IncludeObjectRules=@Rules,@JsonErzeugen=1,@Json=@Json OUTPUT,@StatusCodeOut=@Status OUTPUT;`n"+$SuffixSql
    [void]$command.Parameters.Add('@Rules',[Data.SqlDbType]::Bit);$command.Parameters['@Rules'].Value=$Rules
    [void]$command.Parameters.Add('@Views',[Data.SqlDbType]::Bit);$command.Parameters['@Views'].Value=$Views
    [void]$command.Parameters.Add('@Payload',[Data.SqlDbType]::NVarChar,-1); $command.Parameters['@Payload'].Value=$Payload
    [void]$command.Parameters.Add('@Bytes',[Data.SqlDbType]::VarBinary,-1)
    if($IncludeBytes){$command.Parameters['@Bytes'].Value=[byte[]]$package}else{$command.Parameters['@Bytes'].Value=[DBNull]::Value}
    [void]$command.Parameters.Add('@Mode',[Data.SqlDbType]::VarChar,16); $command.Parameters['@Mode'].Value=$Mode
    [void]$command.Parameters.Add('@Limit',[Data.SqlDbType]::Int); $command.Parameters['@Limit'].Value=$Limit
    [void]$command.Parameters.Add('@Json',[Data.SqlDbType]::NVarChar,-1); $command.Parameters['@Json'].Direction=[Data.ParameterDirection]::Output
    [void]$command.Parameters.Add('@Status',[Data.SqlDbType]::VarChar,40); $command.Parameters['@Status'].Direction=[Data.ParameterDirection]::Output
    if(-not [string]::IsNullOrEmpty($Mapping)) {
        $command.CommandText=$command.CommandText.Replace('@JsonErzeugen=1,','@ResultTablesJson=@Mapping,@JsonErzeugen=1,')
        [void]$command.Parameters.Add('@Mapping',[Data.SqlDbType]::NVarChar,-1); $command.Parameters['@Mapping'].Value=$Mapping
    }
    try {
        $data=[Data.DataSet]::new(); $adapter=[Data.SqlClient.SqlDataAdapter]::new($command); [void]$adapter.Fill($data)
        return [pscustomobject]@{Status=[string]$command.Parameters['@Status'].Value;Json=([string]$command.Parameters['@Json'].Value | ConvertFrom-Json -Depth 32);Data=$data;JsonLength=([string]$command.Parameters['@Json'].Value).Length}
    } finally {$command.Dispose()}
}
function Assert([bool]$Condition,[string]$Label) { if(-not $Condition){throw ('SSIS_MODEL_ASSERT_'+$Label)}; $script:cases++ }
function Reject([string]$Payload,[string]$Expected='EXCHANGE_INVALID') {
    $r=Invoke-Model $Payload
    Assert ($r.Status -ceq $Expected -and @($r.Json.nodes).Count -eq 0 -and @($r.Json.edges).Count -eq 0 -and @($r.Json.sourceBinding).Count -eq 0) ('REJECT_'+$Expected)
}
try {
    $connection.Open()
    $preflight=Query 'SELECT @@VERSION AS EngineVersion; SELECT name,state_desc FROM sys.databases ORDER BY database_id;'
    Assert ($preflight.Tables.Count -eq 2) 'PREFLIGHT'
    [void](Query "CREATE DATABASE [$database] COLLATE SQL_Latin1_General_CP1_CS_AS;"); $created=$true
    $connection.ChangeDatabase($database); [void](Query 'CREATE SCHEMA [monitor] AUTHORIZATION [dbo];')
    foreach($relative in @('Code/01_Common/095_USP_InternalWriteResultTable.sql','Code/01_Common/096_USP_InternalPrepareResultTables.sql','Code/01_Common/098_USP_InternalEmitConsoleResult.sql','Code/10_SSIS/010_USP_SsisPackageAnalysis.sql','Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql')) {
        $source=[IO.File]::ReadAllText((Join-Path $repositoryRoot $relative)) -replace 'USE \[DeineDatenbank\];',"USE [$database];"
        foreach($batch in [regex]::Split($source,'(?im)^\s*GO\s*$')) {if($batch.Trim()){[void](Query $batch)}}
    }
    $baseline=Invoke-Model $model 'RAW' 1000 $true
    if($baseline.Status -cne 'AVAILABLE_LIMITED'){Write-Output ('BASELINE_STATUS='+$baseline.Status+' '+$baseline.Json.moduleStatus[0].ErrorMessage)}
    Assert ($baseline.Status -ceq 'AVAILABLE_LIMITED') 'VALID_IMPORT'
    Assert ($baseline.Data.Tables.Count -eq 8) 'RAW8'
    Assert ($baseline.Json.sourceBinding[0].BindingStatus -ceq 'PACKAGE_BYTES_MATCH' -and $baseline.Json.sourceBinding[0].ProducerTrust -ceq 'UNVERIFIED') 'BINDING_TRUST'
    Assert (@($baseline.Json.nodes).Count -eq $expected.nodeSignatures.Count -and @($baseline.Json.edges).Count -eq $expected.edgeSignatures.Count) 'DIRECT_GRAPH'
    for($i=0;$i -lt $expected.nodeSignatures.Count;$i++) {
        $node=$baseline.Json.nodes[$i];$oracle=$expected.nodeSignatures[$i]
        Assert ($node.NodeId -ceq $oracle[0] -and $node.NodeKind -ceq $oracle[1] -and $node.ParentNodeId -ceq $oracle[2]) ('SHARED_NODE_ORACLE_'+$i)
    }
    for($i=0;$i -lt $expected.edgeSignatures.Count;$i++) {
        $edge=$baseline.Json.edges[$i];$oracle=$expected.edgeSignatures[$i]
        Assert ($edge.EdgeKind -ceq $oracle[0] -and $edge.FromNodeId -ceq $oracle[1] -and $edge.ToNodeId -ceq $oracle[2] -and $edge.RuleId -ceq $oracle[3]) ('SHARED_EDGE_ORACLE_'+$i)
    }
    Assert (@($baseline.Json.edges | Where-Object RuleId -ceq 'MAPPED_VALUE_INPUT').Count -eq 1) 'CANONICAL_LINEAGE'
    $none=Invoke-Model $model
    Assert ($none.Data.Tables.Count -eq 0 -and $none.Json.sourceBinding[0].BindingStatus -ceq 'DECLARED_ONLY') 'NONE_AND_DECLARED'
    $console=Invoke-Model $model 'CONSOLE'
    Assert ($console.Data.Tables.Count -eq 1 -and $console.Status -ceq $baseline.Status) 'CONSOLE1'
    $limited=Invoke-Model $model 'RAW' 1
    Assert ($limited.Json.moduleStatus[0].NodeCount -eq $expected.nodeSignatures.Count -and @($limited.Json.nodes).Count -eq 1 -and @($limited.Json.edges).Count -eq 1 -and @($limited.Json.warnings).Count -eq 1) 'OUTPUT_LIMIT_ONLY'
    $groups=@('moduleStatus','sourceBinding','nodes','edges','coverage','findings','sourceStatus','warnings'); $mapping=[ordered]@{}; $prefix='';$suffix=''
    for($i=0;$i -lt $groups.Count;$i++){ $table='#SyntheticModel'+$i; $mapping[$groups[$i]]=$table; $prefix+="CREATE TABLE $table ([seed] int NULL);`n"; $suffix+="SELECT * FROM $table; DROP TABLE $table;`n" }
    $table=Invoke-Model $model 'TABLE' 1000 $true $prefix ($mapping|ConvertTo-Json -Compress) $suffix
    Assert ($table.Data.Tables.Count -eq 8) 'TABLE8'
    for($i=0;$i -lt 8;$i++) {Assert ($table.Data.Tables[$i].Columns.Count -eq $baseline.Data.Tables[$i].Columns.Count -and $table.Data.Tables[$i].Rows.Count -eq $baseline.Data.Tables[$i].Rows.Count) ('TABLE_PARITY_'+$i)}
    $j=$model|ConvertFrom-Json -Depth 32; $j.source.packageSha256='0'*64
    $mismatch=Invoke-Model ($j|ConvertTo-Json -Compress -Depth 32) 'NONE' 1000 $true
    Assert ($mismatch.Status -ceq 'EXCHANGE_SOURCE_MISMATCH' -and @($mismatch.Json.nodes).Count -eq 0) 'MISMATCH_ATOMIC'
    Reject ($model.Replace('"contract":','"contract":"ssis-package-model","contract":'))
    Reject ($model.Replace('"attributes":{','"attributes":{"unknown":1,'))
    Reject ($model.Replace('"isReadOnly":','"isReadOnly ":'))
    Reject ($model.Replace('"kind":"PACKAGE"','"kind":"PACKAGE "'))
    Reject ($model.Replace('"contract":"ssis-package-model"','"contract ":"ssis-package-model"')) 'EXCHANGE_VERSION_UNSUPPORTED'
    Reject ($model.Replace('"diagnostics":[]','"diagnostics":[null]'))
    Reject ($model.Replace('"diagnostics":[]','"diagnostics":[[]]'))
    $j=$model|ConvertFrom-Json -Depth 32; $j.nodes[4].attributes.direction=$null
    Reject ($j|ConvertTo-Json -Compress -Depth 32) 'EXCHANGE_REFERENCE_INVALID'
    foreach($number in @('1.5','1.0000000000000000001','1e9999999999999999','0','16777217')) {
        Reject ([regex]::Replace($model,'"byteLength":\d+','"byteLength":'+$number))
    }
    foreach($number in @('1.0','1e0','1000000000000000000e-18')) {
        $normalized=Invoke-Model ([regex]::Replace($model,'"byteLength":\d+','"byteLength":'+$number))
        Assert ($normalized.Status -ceq 'AVAILABLE_LIMITED' -and $normalized.Json.sourceBinding[0].ByteLength -eq 1) 'EXACT_INTEGER_LEXEME'
    }
    Reject ($model.Replace('"version":"1.0.0"','"version":"2.0.0"')) 'EXCHANGE_VERSION_UNSUPPORTED'
    $j=$model|ConvertFrom-Json -Depth 32; $j.nodes[1].parentId=$j.nodes[1].id
    Reject ($j|ConvertTo-Json -Compress -Depth 32) 'EXCHANGE_REFERENCE_INVALID'
    $j=$model|ConvertFrom-Json -Depth 32; $j.edges[0].fromId='col999'
    Reject ($j|ConvertTo-Json -Compress -Depth 32) 'EXCHANGE_REFERENCE_INVALID'
    $j=$model|ConvertFrom-Json -Depth 32; $j.edges[0].scopeId='pkg1'
    Reject ($j|ConvertTo-Json -Compress -Depth 32) 'EXCHANGE_REFERENCE_INVALID'
    $j=$model|ConvertFrom-Json -Depth 32; $j.nodes[2].id=$j.nodes[0].id
    Reject ($j|ConvertTo-Json -Compress -Depth 32)
    $j=$model|ConvertFrom-Json -Depth 32; $j.coverage[0].reasonCode='PROFILE_LIMIT'
    Reject ($j|ConvertTo-Json -Compress -Depth 32)
    $j=$model|ConvertFrom-Json -Depth 32; $j.coverage[1].feature=$j.coverage[0].feature
    Reject ($j|ConvertTo-Json -Compress -Depth 32)
    $j=$model|ConvertFrom-Json -Depth 32; $j.nodes[1].attributes.typeCode='bad'
    # VARIABLE ist im gemeinsamen Sollfall der zweite Knoten. Falscher Datentyp statt heuristischer Wertauswertung.
    $j.nodes[1].attributes.isReadOnly='false'
    Reject ($j|ConvertTo-Json -Compress -Depth 32)
    $j=$model|ConvertFrom-Json -Depth 32; $j.edges[2].ruleId='FUTURE_RULE'
    $unknown=Invoke-Model ($j|ConvertTo-Json -Compress -Depth 32)
    Assert (-not $unknown.Json.edges[2].IsInterpretable -and @($unknown.Json.warnings).Count -eq 1) 'UNKNOWN_RULE_NOT_INTERPRETED'
    $nativeXml=[Data.SqlTypes.SqlXml]::new([IO.MemoryStream]::new([byte[]]$package))
    $xmlCommand=$connection.CreateCommand(); $xmlCommand.CommandText="EXEC [monitor].[USP_SsisPackageAnalysis] @PackageXml=@Xml,@ResultSetArt='RAW';"
    [void]$xmlCommand.Parameters.Add('@Xml',[Data.SqlDbType]::Xml); $xmlCommand.Parameters['@Xml'].Value=$nativeXml
    try{$data=[Data.DataSet]::new();[void]([Data.SqlClient.SqlDataAdapter]::new($xmlCommand).Fill($data));Assert ($data.Tables.Count -eq 13) 'STANDALONE_RAW13'}finally{$xmlCommand.Dispose()}
    $state=Query "SELECT @@TRANCOUNT AS T,@@LOCK_TIMEOUT AS L; BEGIN TRAN; SET LOCK_TIMEOUT 1234;"
    $transaction=Invoke-Model $model
    $after=Query 'SELECT @@TRANCOUNT AS T,@@LOCK_TIMEOUT AS L; ROLLBACK; SET LOCK_TIMEOUT -1;'
    Assert ($after.Tables[0].Rows[0].T -eq 1 -and $after.Tables[0].Rows[0].L -eq 1234) 'CALLER_TRANSACTION_AND_LOCK'
    $dependencies=Query "SELECT COUNT(*) AS C FROM sys.assembly_modules WHERE object_id IN (OBJECT_ID(N'[monitor].[USP_SsisPackageModelAnalysis]'),OBJECT_ID(N'[monitor].[USP_SsisPackageAnalysis]'));"
    Assert ($dependencies.Tables[0].Rows[0].C -eq 0) 'NO_CLR_MODULE_DEPENDENCY'
    $views=Invoke-Model $model 'RAW' 1000 $true '' $null '' $true
    Assert ($views.Data.Tables.Count -eq 13 -and $views.Json.components.Count -eq 2 -and $views.Json.columnRelations.Count -eq 2) 'VIEWS_RAW13'
    Assert ($views.Json.packageOverview[0].SourceNodeCount -eq 9 -and $views.Json.packageOverview[0].ProducerTrust -ceq 'UNVERIFIED') 'VIEWS_SOURCE_AND_TRUST'
    $valueModel=$model|ConvertFrom-Json -Depth 32
    $valueModel.edges[2].fromId='var1';$valueModel.edges[2].ruleId='BOUND_EXPRESSION_INPUT'
    $valueViews=Invoke-Model ($valueModel|ConvertTo-Json -Compress -Depth 32) 'NONE' 1000 $false '' $null '' $true
    $variableRelation=@($valueViews.Json.columnRelations|Where-Object FromNodeId -ceq 'var1')
    Assert ($valueViews.Status -ceq 'AVAILABLE_LIMITED' -and $variableRelation.Count -eq 1 -and $variableRelation[0].FromNodeKind -ceq 'VARIABLE' -and $null -eq $variableRelation[0].FromColumnNodeId -and $null -eq $variableRelation[0].FromComponentNodeId) 'VIEWS_VARIABLE_IS_NOT_COLUMN'
    $valueModel.nodes+=([pscustomobject]@{id='par1';kind='PARAMETER';parentId='pkg1';name='SyntheticParameter';attributes=([pscustomobject]@{typeCode='3'})})
    $valueModel.edges[2].fromId='par1'
    $valueViews=Invoke-Model ($valueModel|ConvertTo-Json -Compress -Depth 32) 'NONE' 1000 $false '' $null '' $true
    $parameterRelation=@($valueViews.Json.columnRelations|Where-Object FromNodeId -ceq 'par1')
    Assert ($valueViews.Status -ceq 'AVAILABLE_LIMITED' -and $parameterRelation.Count -eq 1 -and $parameterRelation[0].FromNodeKind -ceq 'PARAMETER' -and $null -eq $parameterRelation[0].FromColumnName -and $null -eq $parameterRelation[0].FromTypeCode -and $null -eq $parameterRelation[0].FromComponentNodeId) 'VIEWS_PARAMETER_IS_NOT_COLUMN'
    $groups=@('moduleStatus','sourceBinding','nodes','edges','coverage','findings','sourceStatus','warnings','packageOverview','executables','dataFlows','components','columnRelations')
    $mapping=[ordered]@{};$prefix='';$suffix=''
    for($i=0;$i -lt $groups.Count;$i++){ $name='#SyntheticViews'+$i;$mapping[$groups[$i]]=$name;$prefix+="CREATE TABLE $name([seed] int NULL);`n";$suffix+="SELECT * FROM $name;DROP TABLE $name;`n" }
    $viewTables=Invoke-Model $model 'TABLE' 1000 $true $prefix ($mapping|ConvertTo-Json -Compress) $suffix $true
    Assert ($viewTables.Data.Tables.Count -eq 13) 'VIEWS_TABLE13'
    for($i=0;$i -lt 13;$i++){Assert ($viewTables.Data.Tables[$i].Rows.Count -eq $views.Data.Tables[$i].Rows.Count -and $viewTables.Data.Tables[$i].Columns.Count -eq $views.Data.Tables[$i].Columns.Count) ('VIEWS_TABLE_PARITY_'+$i)}
    $ruleModel=$model|ConvertFrom-Json -Depth 32;$ruleExe=@($ruleModel.nodes|Where-Object kind -ceq 'EXECUTABLE')[0];$ruleExe.attributes|Add-Member -NotePropertyName isDisabled -NotePropertyValue $true -Force
    $rulePayload=$ruleModel|ConvertTo-Json -Compress -Depth 32
    $rules=Invoke-Model $rulePayload 'RAW' 1000 $false '' $null '' $false $true
    Assert ($rules.Data.Tables.Count -eq 9 -and $rules.Json.objectFindings[0].NodeId -ceq $ruleExe.id) 'RULES_RAW9'
    $both=Invoke-Model $rulePayload 'RAW' 1000 $false '' $null '' $true $true
    Assert ($both.Data.Tables.Count -eq 14) 'RULES_VIEWS_RAW14'
    $ruleTable=Invoke-Model $rulePayload 'TABLE' 1000 $false 'CREATE TABLE #SyntheticRules([seed] int NULL);' '{"objectFindings":"#SyntheticRules"}' 'SELECT * FROM #SyntheticRules; DROP TABLE #SyntheticRules;' $false $true
    Assert ($ruleTable.Data.Tables.Count -eq 1 -and $ruleTable.Data.Tables[0].Rows.Count -eq $rules.Data.Tables[8].Rows.Count -and $ruleTable.Data.Tables[0].Columns.Count -eq $rules.Data.Tables[8].Columns.Count) 'RULES_TABLE_PARITY'
    $ruleProbe=[IO.File]::ReadAllText((Join-Path $repositoryRoot 'Code/Tests/Integration/214_SsisObjectRules_Runtime_Contract.sql')) -replace 'USE \[DeineDatenbank\];',"USE [$database];"
    foreach($batch in [regex]::Split($ruleProbe,'(?im)^\s*GO\s*$')) {if($batch.Trim()){[void](Query $batch)}}
    Assert $true 'OBJECT_RULES_SQL_PROBE'
    $handoverProbe=[IO.File]::ReadAllText((Join-Path $repositoryRoot 'Code/Tests/Integration/215_SsisLocalHandover_Runtime_Contract.sql')) -replace 'USE \[DeineDatenbank\];',"USE [$database];"
    [void](Query 'CREATE USER [SyntheticSsisHandoverReader] WITHOUT LOGIN;')
    $collisionRejected=$false
    try {foreach($batch in [regex]::Split($handoverProbe,'(?im)^\s*GO\s*$')) {if($batch.Trim()){[void](Query $batch)}}}
    catch {$collisionError=$_.Exception;while($collisionError.InnerException){$collisionError=$collisionError.InnerException};$collisionRejected=$collisionError -is [Data.SqlClient.SqlException] -and $collisionError.Number -eq 57406}
    $retained=Query "SELECT COUNT(*) AS C FROM sys.database_principals WHERE name=N'SyntheticSsisHandoverReader';"
    Assert ($collisionRejected -and $retained.Tables[0].Rows[0].C -eq 1) 'HANDOVER_COLLISION_PRESERVES_FOREIGN_USER'
    [void](Query 'DROP USER [SyntheticSsisHandoverReader];')
    foreach($batch in [regex]::Split($handoverProbe,'(?im)^\s*GO\s*$')) {if($batch.Trim()){[void](Query $batch)}}
    Assert $true 'LOCAL_HANDOVER_SQL_PROBE'
    if($ProducerAssemblyPath) {
        $hostHash=(Get-FileHash -LiteralPath $ProducerAssemblyPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $hostCommit=($model|ConvertFrom-Json -Depth 32).producer.sourceCommit
        $beforeSnapshots=@(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'ssis-qualified-handover-*' | ForEach-Object FullName)
        $failedStart=$false
        try {& (Join-Path $repositoryRoot 'Code/Tools/Invoke-SsisQualifiedHandover.ps1') -ProducerAssemblyPath $ProducerAssemblyPath -ExpectedBuildSha256 $hostHash -ExpectedSourceCommit $hostCommit -PackagePath $PackagePath -Connection $connection -DotnetPath 'synthetic-unavailable-dotnet-runtime' | Out-Null}
        catch {$failedStart=$true}
        $afterSnapshots=@(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'ssis-qualified-handover-*' | ForEach-Object FullName)
        Assert ($failedStart -and @($afterSnapshots | Where-Object {$_ -notin $beforeSnapshots}).Count -eq 0) 'HANDOVER_FAILED_START_CLEANUP'
        $handover=& (Join-Path $repositoryRoot 'Code/Tools/Invoke-SsisQualifiedHandover.ps1') -ProducerAssemblyPath $ProducerAssemblyPath -ExpectedBuildSha256 $hostHash -ExpectedSourceCommit $hostCommit -PackagePath $PackagePath -Connection $connection
        $reinstall=[IO.File]::ReadAllText((Join-Path $repositoryRoot 'Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql')) -replace 'USE \[DeineDatenbank\];',"USE [$database];"
        foreach($batch in [regex]::Split($reinstall,'(?im)^\s*GO\s*$')) {if($batch.Trim()){[void](Query $batch)}}
        $handoverCommand=$connection.CreateCommand()
        $handoverCommand.CommandText="DECLARE @Json nvarchar(max);EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT;SELECT @Json;"
        [void]$handoverCommand.Parameters.Add('@Model',[Data.SqlDbType]::NVarChar,-1);$handoverCommand.Parameters['@Model'].Value=$handover.PackageModelJson
        [void]$handoverCommand.Parameters.Add('@Bytes',[Data.SqlDbType]::VarBinary,-1);$handoverCommand.Parameters['@Bytes'].Value=[byte[]]$handover.PackageBytes
        [void]$handoverCommand.Parameters.Add('@Id',[Data.SqlDbType]::UniqueIdentifier);$handoverCommand.Parameters['@Id'].Value=$handover.LocalHandoverId
        try {$verified=$handoverCommand.ExecuteScalar()|ConvertFrom-Json -Depth 32;if($verified.meta.statusCode -cne 'AVAILABLE_LIMITED'){Write-Output ('HANDOVER_STATUS='+$verified.meta.statusCode+' '+$verified.moduleStatus[0].ErrorMessage)};Assert ($verified.sourceBinding.Count -eq 1 -and $verified.sourceBinding[0].ProducerTrust -ceq 'VERIFIED_LOCAL') 'QUALIFIED_HOST_HANDOVER_AFTER_CREATE_OR_ALTER'} finally {$handoverCommand.Dispose()}
    } else {Write-Output 'SSIS_QUALIFIED_HOST_HANDOVER_NOT_EXECUTED: ProducerAssemblyPath not supplied.'}
    $captureProbe=[IO.File]::ReadAllText((Join-Path $repositoryRoot 'Code/Tests/Integration/216_SsisExecutionCorrelation_Runtime_Contract.sql')) -replace 'USE \[DeineDatenbank\];',"USE [$database];"
    foreach($batch in [regex]::Split($captureProbe,'(?im)^\s*GO\s*$')) {if($batch.Trim()){[void](Query $batch)}}
    Assert $true 'EXECUTION_CAPTURE_RECEIVER_SQL_PROBE'
    $probe=[IO.File]::ReadAllText((Join-Path $repositoryRoot 'Code/Tests/Integration/213_SsisPackageViews_Runtime_Contract.sql')) -replace 'USE \[DeineDatenbank\];',"USE [$database];"
    foreach($batch in [regex]::Split($probe,'(?im)^\s*GO\s*$')) {if($batch.Trim()){[void](Query $batch)}}
    Assert $true 'PACKAGE_VIEWS_SQL_PROBE'
    $ciProbe=[IO.File]::ReadAllText((Join-Path $repositoryRoot 'Code/Tests/Integration/212_SsisPackageModelAnalysis_Runtime_Contract.sql')) -replace 'USE \[DeineDatenbank\];',"USE [$database];"
    foreach($batch in [regex]::Split($ciProbe,'(?im)^\s*GO\s*$')) {if($batch.Trim()){[void](Query $batch)}}
    Assert $true 'CANONICAL_CI_SQL_PROBE'
    Write-Output "SSIS_MODEL_RUNTIME_PASS cases=$cases platform=$Platform version=$Version; Functional TLS; default producer UNVERIFIED; optional qualification separately asserted."
} catch {
    Write-Output ('HARNESS_FAILURE Type='+$_.Exception.GetType().FullName+' Stack='+$_.ScriptStackTrace)
    $exception=$_.Exception
    while($exception.InnerException){$exception=$exception.InnerException}
    if($exception -is [Data.SqlClient.SqlException]){
        foreach($item in $exception.Errors){Write-Output ('SQL_FAILURE Number='+$item.Number+' Line='+$item.LineNumber)}
    }
    if($_.Exception.Message -like 'SSIS_MODEL_ASSERT_*'){Write-Output $_.Exception.Message}
    throw 'SSIS_MODEL_RUNTIME_FAILED'
} finally {
    if($connection.State -eq 'Open') {
        try {
            if($created){[void](Query 'IF @@TRANCOUNT>0 ROLLBACK;');$connection.ChangeDatabase('master');[void](Query "ALTER DATABASE [$database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$database];");$created=$false}
        } finally {$connection.Dispose()}
    }
    if($created){throw 'SSIS_MODEL_OWN_DATABASE_CLEANUP_NOT_CONFIRMED'}
}
