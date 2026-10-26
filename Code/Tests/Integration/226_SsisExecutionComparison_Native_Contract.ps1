[CmdletBinding()]
param(
    [Parameter(Mandatory)][guid]$RunId,
    [string]$InstanceId='primary',
    [Parameter(Mandatory)][string]$LabModulePath,
    [Parameter(Mandatory)][string]$FixtureBuilderPath,
    [Parameter(Mandatory)][string]$ProducerAssemblyPath,
    [Parameter(Mandatory)][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][string]$ExpectedBuildSha256,
    [Parameter(Mandatory)][string]$NativeBudgetPath,
    [switch]$IncludeBaselineContract,
    [ValidateSet('Baseline','Baseline2','Baseline3','Baseline4','Baseline5','Equal','Delay','Volume','Logging','Error','Abort','Redeploy')][string[]]$Scenarios=@('Baseline','Equal','Delay','Volume','Logging','Error','Abort','Redeploy')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Scenarios.Count -lt 2 -or $Scenarios[0] -cne 'Baseline' -or @($Scenarios|Select-Object -Unique).Count -ne $Scenarios.Count){throw 'SSIS_COMPARISON_SCENARIO_ORDER_INVALID'}
if(-not $IncludeBaselineContract -and @($Scenarios|Where-Object {$_ -cmatch '^Baseline[2-5]$'}).Count -gt 0){throw 'SSIS_BASELINE_OPT_IN_REQUIRED'}
if($IncludeBaselineContract -and (($Scenarios[0..4] -join ',') -cne 'Baseline,Baseline2,Baseline3,Baseline4,Baseline5')){throw 'SSIS_BASELINE_FIVE_RUNS_REQUIRED'}
# Manueller Windows-Vertrag auf einem ausdrücklich gebundenen vorhandenen Lab-Run.
# Lab stellt SSISDB bereit. Dieser Consumer besitzt nur seine eigenen Objekte;
# der Aufrufer bestimmt unabhängig die Aufbewahrung des Lab-Runs.
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Import-Module $LabModulePath -Force
$capability=Get-SqlServerLabSsisCatalogCapability -RunId $RunId -InstanceId $InstanceId
if($capability.Status -cne 'READY_FOR_FIXTURE_IMPLEMENTATION' -or $capability.Target.BindingStatus -cne 'BOUND'){throw 'SSIS_NATIVE_SOURCE_NOT_READY'}
$access=Get-SqlServerLabGeneratedSqlAccess -RunId $RunId
$builder=[Data.SqlClient.SqlConnectionStringBuilder]::new($access.ConnectionString)
if(-not $builder['Encrypt']){throw 'SSIS_NATIVE_ENCRYPT_REQUIRED'}
$builder['Initial Catalog']='master'
$connection=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$directory=Join-Path ([IO.Path]::GetTempPath()) ('ssis-native-correlation-'+[guid]::NewGuid().ToString('N'))
$security=[Security.AccessControl.DirectorySecurity]::new();$security.SetAccessRuleProtection($true,$false)
$identity=[Security.Principal.WindowsIdentity]::GetCurrent().User
$security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($identity,[Security.AccessControl.FileSystemRights]::FullControl,[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow))
[IO.FileSystemAclExtensions]::Create([IO.DirectoryInfo]::new($directory),$security)
$scriptFile=Join-Path $directory 'own.sql';$receipt=Join-Path $directory 'ownership.private.json'
$record=[ordered]@{RequestedScenarios=$Scenarios;CompletedScenarios=@();Executions=@();Captures=@();Comparisons=@();RunId=$RunId.ToString();InstanceId=$InstanceId;OperationId=[guid]::NewGuid().ToString();FolderName='SyntheticCorrelation_'+[guid]::NewGuid().ToString('N');FolderId=0L;ProjectName='SyntheticProject_'+[guid]::NewGuid().ToString('N');ProjectId=0L;ProjectLsn=0L;ExecutionId=0L;DatabaseAttempted=$false;FolderAttempted=$false;ProjectAttempted=$false;Phase='PLANNED';Cleanup='PENDING';Operations=@()}
$entryName='SyntheticRoot.dtsx'
$record.BaselineResults=@()
$record.SourceBindings=[ordered]@{ProducerCommit=$ExpectedSourceCommit;ProducerSha256=$ExpectedBuildSha256;FixtureBuilderSha256=(Get-FileHash -LiteralPath $FixtureBuilderPath -Algorithm SHA256).Hash}
foreach($relative in @('Code/10_SSIS/045_InternalSsisExecutionMetrics.sql','Code/10_SSIS/050_USP_SsisExecutionComparison.sql','Code/10_SSIS/060_USP_SsisExecutionBaseline.sql','Code/Tools/Invoke-SsisCatalogHandover.ps1','Code/Tools/Invoke-SsisProjectScopeHandover.ps1','Code/Tests/Integration/226_SsisExecutionComparison_Native_Contract.ps1','Code/Tests/Integration/228_SsisExecutionBaseline_Native_Contract.ps1','Code/Tests/Fixtures/SSIS_Execution_Correlation/CreatePipelineProject.cs')){$record.SourceBindings[$relative]=(Get-FileHash -LiteralPath (Join-Path $root $relative) -Algorithm SHA256).Hash}
$database='SyntheticSsisNative_'+[guid]::NewGuid().ToString('N');$databaseCreated=$false;$counter=[pscustomobject]@{Value=0}
$target=@{RunId=$RunId;InstanceId=$InstanceId;WindowsAuthentication=$true;Database='SSISDB';KeepConnection=$true;TimeoutSeconds=60}
function Save-Record {[IO.File]::WriteAllText($receipt,($record|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))}
function Assert([bool]$Condition,[string]$Label){if(-not $Condition){throw ('SSIS_NATIVE_ASSERT_'+$Label)};$counter.Value++}
function Windows-Query([string]$Sql,[hashtable]$Parameters) {
    Save-Record;[IO.File]::WriteAllText($scriptFile,$Sql,[Text.UTF8Encoding]::new($false))
    $response=Invoke-SqlServerLabScript @target -ScriptPath $scriptFile -Parameters $Parameters
    $record.Operations+=@([ordered]@{Phase=$record.Phase;OperationId=$response.OperationId;Outcome=$response.Outcome;ErrorCode=$response.ErrorCode;SqlErrorNumber=$response.SqlErrorNumber});Save-Record
    if(-not $response.Success -or $response.Outcome -cne 'SUCCEEDED' -or $response.Authentication -cne 'Windows' -or $response.AuthScheme -notin @('NTLM','KERBEROS')){throw ('SSIS_NATIVE_WINDOWS_OPERATION_UNCONFIRMED_'+$record.Phase+'_'+$response.SqlErrorNumber)}
    return $response
}
function Query([string]$Sql,[hashtable]$Parameters=@{}) {
    $command=$connection.CreateCommand();$command.CommandText=$Sql;$command.CommandTimeout=90
    foreach($key in $Parameters.Keys){[void]$command.Parameters.AddWithValue('@'+$key,$Parameters[$key])}
    try {$data=[Data.DataSet]::new();$adapter=[Data.SqlClient.SqlDataAdapter]::new($command);[void]$adapter.Fill($data);return ,$data} finally {$command.Dispose()}
}
function Convert-SourceTable($Set) {
    $table=[Data.DataTable]::new();foreach($column in $Set.Columns){[void]$table.Columns.Add([string]$column,[object])}
    foreach($row in $Set.Rows){$values=[object[]]::new($Set.Columns.Count);for($i=0;$i -lt $values.Length;$i++){$values[$i]=if($null -eq $row[$i]){[DBNull]::Value}else{$row[$i]}};[void]$table.Rows.Add($values)}
    return ,$table
}

$groups=@('comparisonBinding','objectComparison','comparisonFindings','comparisonCoverage')
$orders=@('BaselineExecutionId','ComparisonKeySha256','RuleId,ComparisonKeySha256','Scope,SourceName')
function Reserve-NativeAttempt {
 $prior=[IO.File]::ReadAllText($NativeBudgetPath);$budget=$prior|ConvertFrom-Json
 if($budget.State -notin @('IMPLEMENTING','NATIVE_ACCEPTANCE') -or $budget.NativeRootExecutions -ge $budget.NativeRootExecutionCeiling){throw 'SSIS_COMPARISON_NATIVE_BUDGET_EXHAUSTED'}
 $budget.NativeRootExecutions++;$budget.State='NATIVE_ACCEPTANCE'
 $temp=$NativeBudgetPath+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
 [IO.File]::WriteAllText($temp,($budget|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
 if([IO.File]::ReadAllText($NativeBudgetPath) -cne $prior){[IO.File]::Delete($temp);throw 'SSIS_COMPARISON_BUDGET_CHANGED'}
 [IO.File]::Replace($temp,$NativeBudgetPath,$temp+'.previous');[IO.File]::Delete($temp+'.previous');$record.AttemptOrdinal=$budget.NativeRootExecutions;Save-Record
}
function Read-Comparison($Baseline,$Candidate,[string]$Mode='NONE',[switch]$Detailed) {
 $prefix='';$suffix='';$mapping=[ordered]@{}
 if($Mode -ceq 'TABLE'){for($i=0;$i -lt 4;$i++){$table='#SyntheticComparison'+$i;$mapping[$groups[$i]]=$table;$prefix+="CREATE TABLE $table ([Seed] int);";$suffix+="SELECT * FROM $table ORDER BY $($orders[$i]);DROP TABLE $table;"}}
 $data=Query ($prefix+"DECLARE @j nvarchar(max);EXEC monitor.USP_SsisExecutionComparison @BaselineProjectModelsJson=@BM,@BaselineScopeSnapshotJson=@BC,@BaselineScopeHandoverId=@BI,@BaselineExecutionId=@BE,@CandidateProjectModelsJson=@CM,@CandidateScopeSnapshotJson=@CC,@CandidateScopeHandoverId=@CI,@CandidateExecutionId=@CE,@MinDurationDeltaMs=500,@MinDurationDeltaPercent=10,@MaxZeilen=0,@MaxDurationSeconds=60,@ResultSetArt=@Mode,@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@j OUTPUT;"+$suffix+'SELECT @j;') @{BM=$Baseline.ProjectModelsJson;BC=$Baseline.ScopeSnapshotJson;BI=$Baseline.ScopeHandoverId;BE=$Baseline.NativeExecutionId;CM=$Candidate.ProjectModelsJson;CC=$Candidate.ScopeSnapshotJson;CI=$Candidate.ScopeHandoverId;CE=$Candidate.NativeExecutionId;Mode=$Mode;Mapping=$(if($Mode -ceq 'TABLE'){$mapping|ConvertTo-Json -Compress}else{[DBNull]::Value})}
 $json=$data.Tables[$data.Tables.Count-1].Rows[0][0]|ConvertFrom-Json -Depth 40
 if($Detailed){return [pscustomobject]@{Data=$data;Json=$json}};return $json
}
function Native-DurationValue($Capture,$Metric,[string]$Side) {
 $sourceId=$Metric.($Side+'SourceId')
 if($Metric.ObjectKind -ceq 'FLOW'){
  $evidence=@($Capture.observations|Where-Object {[long]$_.statisticsId -eq [long]$sourceId})
  Assert ($evidence.Count -eq 1) 'FLOW_NATIVE_DURATION_EVIDENCE';return [decimal]$evidence[0].durationMs
 }
 $seed=@($Capture.componentPhases|Where-Object {[long]$_.phaseStatsId -eq [long]$sourceId})
 Assert ($seed.Count -eq 1) 'PHASE_NATIVE_DURATION_EVIDENCE'
 $intervals=@($Capture.componentPhases|Where-Object {$_.executionPath -ceq $seed[0].executionPath -and $_.packageName -ceq $seed[0].packageName -and $_.taskName -ceq $seed[0].taskName -and $_.componentName -ceq $seed[0].componentName -and $_.phaseName -ceq $seed[0].phaseName}|ForEach-Object {
  if($null -ne $_.startTime -and $null -ne $_.endTime){
   $start=[decimal]::Truncate([decimal]([datetimeoffset]$_.startTime).UtcTicks/10000);$end=[decimal]::Truncate([decimal]([datetimeoffset]$_.endTime).UtcTicks/10000)
   if($end -ge $start){[pscustomobject]@{Start=$start;End=$end;Duration=$end-$start}}
  }
 })
 Assert ($intervals.Count -gt 0) 'VALID_NATIVE_PHASE_INTERVALS'
 switch($Metric.MetricName){
  'PHASE_INTERVAL_SUM_MS'{return [decimal]($intervals|Measure-Object Duration -Sum).Sum}
  'PHASE_LONGEST_MS'{return [decimal]($intervals|Measure-Object Duration -Maximum).Maximum}
  'PHASE_SPAN_MS'{return [decimal]($intervals|Measure-Object End -Maximum).Maximum-[decimal]($intervals|Measure-Object Start -Minimum).Minimum}
  default{throw 'UNEXPECTED_DURATION_METRIC'}
 }
}
function Test-DurationOracle($Baseline,$Candidate,$Comparison) {
 $b=$Baseline.ScopeSnapshotJson|ConvertFrom-Json -Depth 40;$c=$Candidate.ScopeSnapshotJson|ConvertFrom-Json -Depth 40
 foreach($metric in $Comparison.objectComparison|Where-Object {$_.Unit -ceq 'MS' -and $null -ne $_.DeltaValue}){
  $bv=Native-DurationValue $b $metric Baseline;$cv=Native-DurationValue $c $metric Candidate
  Assert ($metric.BaselineValue -eq $bv -and $metric.CandidateValue -eq $cv -and $metric.DeltaValue -eq $cv-$bv) 'INDEPENDENT_NATIVE_DURATION_AND_DELTA'
  if($bv -eq 0){Assert ($null -eq $metric.DeltaPercent) 'ZERO_NATIVE_BASELINE_PERCENT'}
  else{Assert ([decimal]$metric.DeltaPercent -eq [decimal]::Round(100*($cv-$bv)/$bv,6,[MidpointRounding]::AwayFromZero)) 'INDEPENDENT_NATIVE_DURATION_PERCENT'}
 }
}
function Test-OutputParity($Baseline,$Candidate) {
 $raw=Read-Comparison $Baseline $Candidate RAW -Detailed;$tableResult=Read-Comparison $Baseline $Candidate TABLE -Detailed
 Assert ($raw.Data.Tables.Count -eq 5 -and $tableResult.Data.Tables.Count -eq 5) 'RAW_TABLE_FOUR_GROUPS'
 for($i=0;$i -lt 4;$i++){
  $left=$raw.Data.Tables[$i];$right=$tableResult.Data.Tables[$i];$jsonRows=@($raw.Json.($groups[$i]))
  Assert ($left.Columns.Count -eq $right.Columns.Count -and $left.Rows.Count -eq $right.Rows.Count -and $left.Rows.Count -eq $jsonRows.Count) 'OUTPUT_SHAPE_PARITY'
  for($column=0;$column -lt $left.Columns.Count;$column++){
   $definition=$left.Columns[$column];Assert ($definition.ColumnName -ceq $right.Columns[$column].ColumnName -and $definition.DataType -eq $right.Columns[$column].DataType) 'OUTPUT_NATIVE_SCHEMA_PARITY'
   for($row=0;$row -lt $left.Rows.Count;$row++){
    $value=$left.Rows[$row][$column];$other=$right.Rows[$row][$column];$jsonValue=$jsonRows[$row].($definition.ColumnName)
    if($value -is [DBNull]){Assert ($other -is [DBNull] -and $null -eq $jsonValue) 'OUTPUT_NULL_PARITY';continue}
    if($value -is [byte[]]){Assert ([Convert]::ToBase64String($value) -ceq [Convert]::ToBase64String($other) -and [Convert]::ToBase64String($value) -ceq $jsonValue) 'OUTPUT_BINARY_PARITY'}
    elseif($value -is [string]){Assert ($value -ceq $other -and $value -ceq [string]$jsonValue) 'OUTPUT_ORDINAL_PARITY'}
    else{Assert ($value.Equals($other) -and $value -eq $jsonValue) 'OUTPUT_TYPED_PARITY'}
   }
  }
 }
 Assert ((Read-Comparison $Baseline $Candidate CONSOLE -Detailed).Data.Tables.Count -eq 2 -and (Read-Comparison $Baseline $Candidate NONE -Detailed).Data.Tables.Count -eq 1) 'CONSOLE_NONE_CONTRACT'
}

$baselineGroups=@('baselineBinding','executionCohort','metricBaseline','baselineFindings','baselineCoverage')
$baselineOrders=@('CandidateExecutionId','RunOrdinal','ComparisonKeySha256','RuleId,ComparisonKeySha256','RunOrdinal,SourceName,ComparisonKeySha256')
function Read-Baseline($Baselines,$Candidate,[string]$Mode='NONE',[switch]$Detailed) {
 $entries=@($Baselines|ForEach-Object {[ordered]@{projectModelsJson=$_.ProjectModelsJson;scopeSnapshotJson=$_.ScopeSnapshotJson;scopeHandoverId=$_.ScopeHandoverId.ToString();executionId=$_.NativeExecutionId.ToString()}})
 $prefix='';$suffix='';$mapping=[ordered]@{}
 if($Mode -ceq 'TABLE'){for($i=0;$i -lt 5;$i++){$table='#SyntheticBaseline'+$i;$mapping[$baselineGroups[$i]]=$table;$prefix+="CREATE TABLE $table ([Seed] int);";$suffix+="SELECT * FROM $table ORDER BY $($baselineOrders[$i]);DROP TABLE $table;"}}
 $data=Query ($prefix+"DECLARE @j nvarchar(max);EXEC monitor.USP_SsisExecutionBaseline @BaselineExecutionsJson=@B,@CandidateProjectModelsJson=@CM,@CandidateScopeSnapshotJson=@CC,@CandidateScopeHandoverId=@CI,@CandidateExecutionId=@CE,@MinDurationDeltaMs=500,@MinDurationDeltaPercent=10,@MaxZeilen=0,@MaxDurationSeconds=60,@ResultSetArt=@Mode,@ResultTablesJson=@Mapping,@JsonErzeugen=1,@Json=@j OUTPUT;"+$suffix+'SELECT @j;') @{B=(ConvertTo-Json -InputObject $entries -Depth 8 -Compress);CM=$Candidate.ProjectModelsJson;CC=$Candidate.ScopeSnapshotJson;CI=$Candidate.ScopeHandoverId;CE=$Candidate.NativeExecutionId;Mode=$Mode;Mapping=$(if($Mode -ceq 'TABLE'){$mapping|ConvertTo-Json -Compress}else{[DBNull]::Value})}
 $json=$data.Tables[$data.Tables.Count-1].Rows[0][0]|ConvertFrom-Json -Depth 40
 if($Detailed){return [pscustomobject]@{Data=$data;Json=$json}};return $json
}
function Native-BaselineValue($Capture,$Metric,$Evidence) {
 if($Metric.Unit -ceq 'MS'){
  $proxy=[pscustomobject]@{BaselineSourceId=$Evidence.SourceId;ObjectKind=$Metric.ObjectKind;MetricName=$Metric.MetricName}
  return Native-DurationValue $Capture $proxy Baseline
 }
 if($Metric.ObjectKind -ceq 'PHASE'){
  $seed=@($Capture.componentPhases|Where-Object {[long]$_.phaseStatsId -eq [long]$Evidence.SourceId});Assert ($seed.Count -eq 1) 'BASELINE_PHASE_SOURCE'
  return [decimal]@($Capture.componentPhases|Where-Object {$_.executionPath -ceq $seed[0].executionPath -and $_.packageName -ceq $seed[0].packageName -and $_.taskName -ceq $seed[0].taskName -and $_.componentName -ceq $seed[0].componentName -and $_.phaseName -ceq $seed[0].phaseName}).Count
 }
 $seed=@($Capture.pathTransfers|Where-Object {[long]$_.dataStatsId -eq [long]$Evidence.SourceId});Assert ($seed.Count -eq 1) 'BASELINE_PATH_SOURCE'
 $transfers=@($Capture.pathTransfers|Where-Object {$_.executionPath -ceq $seed[0].executionPath -and $_.packageName -ceq $seed[0].packageName -and $_.taskName -ceq $seed[0].taskName -and $_.pathIdentificationString -ceq $seed[0].pathIdentificationString -and $_.pathName -ceq $seed[0].pathName -and $_.sourceComponentName -ceq $seed[0].sourceComponentName -and $_.destinationComponentName -ceq $seed[0].destinationComponentName})
 if($Metric.MetricName -ceq 'PATH_TRANSFER_COUNT'){return [decimal]$transfers.Count}
 $sum=[decimal]0;foreach($transfer in $transfers){$sum+=[decimal]$transfer.rowsSent};return $sum
}
function Test-BaselineOutputParity($Baselines,$Candidate) {
 $raw=Read-Baseline $Baselines $Candidate RAW -Detailed;$tableResult=Read-Baseline $Baselines $Candidate TABLE -Detailed
 Assert ($raw.Data.Tables.Count -eq 6 -and $tableResult.Data.Tables.Count -eq 6) 'BASELINE_RAW_TABLE_FIVE_GROUPS'
 for($i=0;$i -lt 5;$i++){
  $left=$raw.Data.Tables[$i];$right=$tableResult.Data.Tables[$i];$jsonRows=@($raw.Json.($baselineGroups[$i]))
  Assert ($left.Columns.Count -eq $right.Columns.Count -and $left.Rows.Count -eq $right.Rows.Count -and $left.Rows.Count -eq $jsonRows.Count) 'BASELINE_OUTPUT_SHAPE'
  for($column=0;$column -lt $left.Columns.Count;$column++){
   $definition=$left.Columns[$column];Assert ($definition.ColumnName -ceq $right.Columns[$column].ColumnName -and $definition.DataType -eq $right.Columns[$column].DataType) 'BASELINE_NATIVE_SCHEMA'
   for($row=0;$row -lt $left.Rows.Count;$row++){
    $value=$left.Rows[$row][$column];$other=$right.Rows[$row][$column];$jv=$jsonRows[$row].($definition.ColumnName)
    if($value -is [DBNull]){Assert ($other -is [DBNull] -and $null -eq $jv) 'BASELINE_OUTPUT_NULL';continue}
    if($value -is [byte[]]){Assert ([Convert]::ToBase64String($value) -ceq [Convert]::ToBase64String($other) -and [Convert]::ToBase64String($value) -ceq $jv) 'BASELINE_OUTPUT_BINARY'}
    elseif($value -is [string]){Assert ($value -ceq $other -and $value -ceq [string]$jv) 'BASELINE_OUTPUT_TEXT'}
    else{Assert ($value.Equals($other) -and $value -eq $jv) 'BASELINE_OUTPUT_TYPED'}
   }
  }
 }
 Assert ((Read-Baseline $Baselines $Candidate CONSOLE -Detailed).Data.Tables.Count -eq 2 -and (Read-Baseline $Baselines $Candidate NONE -Detailed).Data.Tables.Count -eq 1) 'BASELINE_CONSOLE_NONE'
}
function Test-BaselineContract($Baselines,$Candidate,[string]$Scenario) {
 Assert ($Baselines.Count -eq 5) 'FIVE_NATIVE_BASELINES'
 $result=Read-Baseline $Baselines $Candidate
 $record.BaselineResults+=@([ordered]@{Scenario=$Scenario;Result=$result});Save-Record
 Assert ($result.baselineBinding[0].StatusCode -ceq 'BASELINE_CAPTURE_BOUND' -and $result.baselineBinding[0].AnalyzedExecutionCount -eq 6 -and $result.executionCohort.Count -eq 6) 'BASELINE_NATIVE_BOUND_ONCE'
 Assert ($result.baselineBinding[0].WorkloadEquivalence -ceq 'UNPROVEN' -and $result.baselineBinding[0].IsPartial -and @($result.baselineFindings|Where-Object Severity -CNE 'INFO').Count -eq 0) 'BASELINE_EVIDENCE_LIMITS'
 if($Scenario -cin @('Equal','Delay','Volume')){
  foreach($metric in $result.metricBaseline){
   $evidence=@($result.baselineCoverage|Where-Object {$_.SourceName -ceq 'metrics' -and $_.ComparisonKeySha256 -ceq $metric.ComparisonKeySha256 -and $_.RunOrdinal -gt 0 -and $_.StatusCode -ceq 'INCLUDED'})
   Assert ($metric.ValidBaselineCount -eq $evidence.Count -and $metric.ExcludedBaselineCount -eq 5-$evidence.Count) 'BASELINE_PER_METRIC_N'
   $values=@(@(foreach($item in $evidence){$capture=$Baselines[[int]$item.RunOrdinal-1].ScopeSnapshotJson|ConvertFrom-Json -Depth 40;$value=Native-BaselineValue $capture $metric $item;Assert ($value -eq [decimal]$item.ObservedValue) 'BASELINE_INDEPENDENT_SOURCE_VALUE';$value})|Sort-Object)
   if($values.Count -gt 0){
    $median=if($values.Count%2 -eq 1){[decimal]$values[[int][math]::Floor($values.Count/2)]}else{([decimal]$values[$values.Count/2-1]+[decimal]$values[$values.Count/2])/2}
    Assert ($metric.MedianValue -eq $median -and $metric.MinValue -eq $values[0] -and $metric.MaxValue -eq $values[-1] -and $metric.SpreadValue -eq [decimal]$values[-1]-[decimal]$values[0]) 'BASELINE_INDEPENDENT_EXACT_STATISTICS'
    if($null -ne $metric.DeltaValue){Assert ([decimal]$metric.DeltaValue -eq [decimal]$metric.CandidateValue-$median) 'BASELINE_INDEPENDENT_DELTA';if($median -eq 0){Assert ($null -eq $metric.DeltaPercent) 'BASELINE_ZERO_MEDIAN'}else{Assert ([decimal]$metric.DeltaPercent -eq [decimal]::Round(100*([decimal]$metric.CandidateValue-$median)/$median,6,[MidpointRounding]::AwayFromZero)) 'BASELINE_INDEPENDENT_PERCENT'}}
   }
  }
  if($Scenario -ceq 'Equal'){Assert (@($result.metricBaseline|Where-Object {$_.MetricName -ceq 'PATH_ROWS_SENT' -and $_.DeltaValue -ne 0}).Count -eq 0) 'BASELINE_EQUAL_ROWS';Test-BaselineOutputParity $Baselines $Candidate}
  if($Scenario -ceq 'Delay'){Assert (@($result.baselineFindings|Where-Object RuleId -CEQ 'SSIS_BASELINE_DURATION_THRESHOLD_EXCEEDED').Count -gt 0) 'BASELINE_DELAY_FINDING'}
  if($Scenario -ceq 'Volume'){Assert (@($result.baselineFindings|Where-Object RuleId -CEQ 'SSIS_BASELINE_OBSERVED_ROWS_CHANGED').Count -gt 0 -and @($result.baselineFindings|Where-Object RuleId -CEQ 'SSIS_BASELINE_DURATION_THRESHOLD_EXCEEDED').Count -eq 0) 'BASELINE_VOLUME_GUARD'}
 }else{
  Assert (@($result.metricBaseline|Where-Object {$null -ne $_.DeltaValue}).Count -eq 0 -and @($result.baselineFindings|Where-Object RuleId -CEQ 'SSIS_BASELINE_DURATION_THRESHOLD_EXCEEDED').Count -eq 0) 'BASELINE_CONTEXT_GUARD'
  Assert (@($result.executionCohort|Where-Object {$_.ContextStatus -ceq $(if($Scenario -ceq 'Logging'){'LOGGING_LEVEL_DIFFERENT'}else{'NOT_BOTH_SUCCEEDED'})}).Count -ge 5) 'BASELINE_EXPLICIT_RUN_EXCLUSION'
 }
}

try {
    Save-Record;$connection.Open()
    $record.DatabaseAttempted=$true;Save-Record
    [void](Query "CREATE DATABASE [$database] COLLATE SQL_Latin1_General_CP1_CS_AS;");$databaseCreated=$true
    $dbIdentity=(Query 'SELECT database_id,create_date,service_broker_guid FROM sys.databases WHERE name=@name;' @{name=$database}).Tables[0].Rows[0]
    $record.DatabaseIdentity=[ordered]@{Name=$database;Id=[int]$dbIdentity.database_id;Created=[datetime]$dbIdentity.create_date;BrokerGuid=[guid]$dbIdentity.service_broker_guid};Save-Record
    $connection.ChangeDatabase($database);[void](Query 'CREATE SCHEMA monitor AUTHORIZATION dbo;')
    foreach($relative in @('Code/01_Common/095_USP_InternalWriteResultTable.sql','Code/01_Common/096_USP_InternalPrepareResultTables.sql','Code/01_Common/098_USP_InternalEmitConsoleResult.sql','Code/10_SSIS/034_InternalSsisScopePathMatch.sql','Code/10_SSIS/036_InternalSsisPipelineCorrelation.sql','Code/10_SSIS/037_InternalSsisPipelineDiagnostics.sql','Code/10_SSIS/035_InternalSsisExecutionScopes.sql','Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql','Code/10_SSIS/045_InternalSsisExecutionMetrics.sql','Code/10_SSIS/050_USP_SsisExecutionComparison.sql','Code/10_SSIS/060_USP_SsisExecutionBaseline.sql')) {
        $sql=[IO.File]::ReadAllText((Join-Path $root $relative)).Replace('USE [DeineDatenbank];',"USE [$database];")
        foreach($batch in [regex]::Split($sql,'(?im)^\s*GO\s*$')){if($batch.Trim()){[void](Query $batch)}}
    }
    [void](Query 'CREATE TABLE dbo.SyntheticControl(RowsCount int NOT NULL,DelaySeconds int NOT NULL,Fail bit NOT NULL);INSERT dbo.SyntheticControl VALUES(5,0,0);')
    [void](Query @'
CREATE PROCEDURE dbo.SyntheticRead AS
BEGIN
 SET NOCOUNT ON;SET LANGUAGE us_english;
 DECLARE @n int,@seconds int,@fail bit,@delay varchar(8);
 SELECT @n=RowsCount,@seconds=DelaySeconds,@fail=Fail FROM dbo.SyntheticControl;
 IF @seconds NOT BETWEEN 0 AND 20 OR @n NOT BETWEEN 1 AND 8 THROW 57932,'SYNTHETIC_CONTROL_OUT_OF_RANGE',1;
 IF @seconds>0 BEGIN SET @delay='00:00:'+RIGHT('0'+CONVERT(varchar(2),@seconds),2);WAITFOR DELAY @delay;END;
 IF @fail=1 BEGIN SELECT CONVERT(int,N'SyntheticInvalid') AS SyntheticValue;RETURN;END;
 SELECT TOP(@n) CONVERT(int,v.n) AS SyntheticValue FROM (VALUES(1),(2),(3),(4),(5),(6),(7),(8)) AS v(n) ORDER BY v.n;
END;
'@)
    # Die SQL-Steuerung wird vor nativen Root-Starts unabhängig geprüft.
    [void](Query 'UPDATE dbo.SyntheticControl SET RowsCount=8,DelaySeconds=2,Fail=0;')
    $probeStarted=[datetime]::UtcNow;$probe=Query 'EXEC dbo.SyntheticRead WITH RESULT SETS ((SyntheticValue int));'
    Assert ($probe.Tables.Count -eq 1 -and $probe.Tables[0].Rows.Count -eq 8 -and ([datetime]::UtcNow-$probeStarted).TotalMilliseconds -ge 1800) 'SQL_VOLUME_DELAY_PREFLIGHT'
    [void](Query 'UPDATE dbo.SyntheticControl SET DelaySeconds=0,Fail=1;');$ownError=$false
    try{[void](Query 'EXEC dbo.SyntheticRead WITH RESULT SETS ((SyntheticValue int));')}catch{$ownError=$_.Exception.ToString().Contains('SyntheticInvalid') -and $_.Exception.ToString().Contains('Conversion failed')}
    Assert $ownError 'SQL_ERROR_PREFLIGHT'
    [void](Query 'UPDATE dbo.SyntheticControl SET RowsCount=5,DelaySeconds=0,Fail=0;')
    $instance=Windows-Query "SELECT CONVERT(nvarchar(128),SERVERPROPERTY(N'InstanceName'));" @{}
    $runtimeTarget='localhost';if($null -ne $instance.ResultSets[0].Rows[0][0]){$runtimeTarget+='\'+[string]$instance.ResultSets[0].Rows[0][0]}
    $authorArguments=@($record.ProjectName,'SQLServer2025',$runtimeTarget,'--comparison',$database)
    $oracle=& $FixtureBuilderPath @authorArguments|ConvertFrom-Json
    if($LASTEXITCODE -ne 0){throw 'SSIS_NATIVE_SDK_AUTHOR_FAILED'}
    $record.FixtureEvidence=$oracle;Save-Record
    $ispac=[Convert]::FromBase64String($oracle.ispacBase64)
    $stream=[IO.MemoryStream]::new($ispac,$false);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read,$false)
    try {$entry=$zip.GetEntry($entryName);$input=$entry.Open();$memory=[IO.MemoryStream]::new();try {$input.CopyTo($memory);$expectedBytes=$memory.ToArray()} finally {$input.Dispose();$memory.Dispose()}} finally {$zip.Dispose();$stream.Dispose()}
    $expectedDigest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($expectedBytes)).ToLowerInvariant()
    $record.Phase='CREATE_OWN_FOLDER';$record.FolderAttempted=$true;Save-Record
    $created=Windows-Query "IF EXISTS(SELECT 1 FROM catalog.folders WHERE name=@folder) THROW 57500,'SYNTHETIC_FOLDER_COLLISION',1;DECLARE @id bigint;EXEC catalog.create_folder @folder_name=@folder,@folder_id=@id OUTPUT;SELECT @id;" @{folder=$record.FolderName}
    $record.FolderId=[long]$created.ResultSets[0].Rows[0][0];Save-Record
    $record.Phase='DEPLOY_OWN_PROJECT';$record.ProjectAttempted=$true;Save-Record
    $deployed=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.folders WHERE folder_id=@folderId AND name=@folder) THROW 57500,'SYNTHETIC_FOLDER_CHANGED',1;IF EXISTS(SELECT 1 FROM catalog.projects WHERE folder_id=@folderId AND name=@project) THROW 57500,'SYNTHETIC_PROJECT_COLLISION',1;DECLARE @op bigint;EXEC catalog.deploy_project @folder_name=@folder,@project_name=@project,@project_stream=@bytes,@operation_id=@op OUTPUT;SELECT project_id,object_version_lsn FROM catalog.projects WHERE folder_id=@folderId AND name=@project;" @{folder=$record.FolderName;folderId=$record.FolderId;project=$record.ProjectName;bytes=[byte[]]$ispac}
    $record.ProjectId=[long]$deployed.ResultSets[0].Rows[0][0];$record.ProjectLsn=[long]$deployed.ResultSets[0].Rows[0][1];Save-Record
    $roundtrip=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND folder_id=@folderId AND object_version_lsn=@version) THROW 57500,'SYNTHETIC_PROJECT_CHANGED',1;CREATE TABLE #SyntheticArchive([ProjectStream] varbinary(max));INSERT #SyntheticArchive EXEC catalog.get_project @folder_name=@folder,@project_name=@project;SELECT (SELECT ProjectStream AS [*] FOR XML PATH(''),BINARY BASE64) FROM #SyntheticArchive;" @{projectId=$record.ProjectId;folderId=$record.FolderId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName}
    $returnedArchive=[Convert]::FromBase64String([string]$roundtrip.ResultSets[0].Rows[0][0]);$archiveDigest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($ispac));$returnedDigest=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($returnedArchive))
    $record.ArchiveRoundtrip=[ordered]@{OriginalSha256=$archiveDigest;ReturnedSha256=$returnedDigest};Save-Record
    Assert ($archiveDigest -ceq $returnedDigest) 'CATALOG_ARCHIVE_ROUNDTRIP'
    $readerAdapter={param($Sql,$Parameters)
        $record.Phase='CAPTURE_FIXED_SOURCE_BATCH';$Parameters.ArchiveAsBase64=$true
        $response=Windows-Query $Sql $Parameters
        if($response.ResultSets.Count -eq 1){return [pscustomobject]@{Before=(Convert-SourceTable $response.ResultSets[0]);Archive=[byte[]]@();Observations=$null;After=$null}}
        if($response.ResultSets.Count -ne 7){throw 'SSIS_NATIVE_CAPTURE_RESULT_SHAPE'}
        [pscustomobject]@{Before=(Convert-SourceTable $response.ResultSets[0]);Archive=[Convert]::FromBase64String([string]$response.ResultSets[1].Rows[0][0]);Observations=(Convert-SourceTable $response.ResultSets[2]);Events=(Convert-SourceTable $response.ResultSets[3]);ComponentPhases=(Convert-SourceTable $response.ResultSets[4]);PathTransfers=(Convert-SourceTable $response.ResultSets[5]);After=(Convert-SourceTable $response.ResultSets[6])}
    }

    $baseline=$null;$baselineCohort=[Collections.Generic.List[object]]::new()
    foreach($scenario in $Scenarios){
        $record.Phase='SCENARIO_'+$scenario;Save-Record
        if($scenario -ceq 'Redeploy'){
            $oldLsn=$record.ProjectLsn
            $redeployed=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND folder_id=@folderId AND object_version_lsn=@version) THROW 57932,'SYNTHETIC_PROJECT_CHANGED',1;DECLARE @op bigint;EXEC catalog.deploy_project @folder_name=@folder,@project_name=@project,@project_stream=@bytes,@operation_id=@op OUTPUT;SELECT object_version_lsn FROM catalog.projects WHERE project_id=@projectId;" @{projectId=$record.ProjectId;folderId=$record.FolderId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName;bytes=[byte[]]$ispac}
            $record.ProjectLsn=[long]$redeployed.ResultSets[0].Rows[0][0];Save-Record
            Assert ($record.ProjectLsn -ne $oldLsn) 'NATIVE_LSN_CHANGED'
            $historical=& (Join-Path $root 'Code/Tools/Invoke-SsisCatalogHandover.ps1') @captureArguments
            Assert ($historical.Status -ceq 'RUNTIME_BINDING_UNPROVEN' -and $historical.ReasonCode -ceq 'EXECUTION_PROJECT_VERSION_UNAVAILABLE') 'HISTORICAL_CURRENT_EXPORT_REFUSED'
        }
        $rows=if($scenario -ceq 'Volume'){8}else{5};$seconds=switch($scenario){'Delay'{2};'Abort'{20};default{0}};$fail=$scenario -ceq 'Error';$logging=if($scenario -ceq 'Logging'){2}else{3}
        [void](Query 'UPDATE dbo.SyntheticControl SET RowsCount=@rows,DelaySeconds=@seconds,Fail=@fail;' @{rows=$rows;seconds=$seconds;fail=$fail})
        Reserve-NativeAttempt
        $execution=Windows-Query "IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND object_version_lsn=@version) THROW 57932,'SYNTHETIC_PROJECT_CHANGED',1;DECLARE @id bigint;EXEC catalog.create_execution @folder_name=@folder,@project_name=@project,@package_name=@entry,@execution_id=@id OUTPUT;SELECT @id;" @{projectId=$record.ProjectId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName;entry=$entryName}
        $record.ExecutionId=[long]$execution.ResultSets[0].Rows[0][0];$record.Executions+=@([ordered]@{Scenario=$scenario;ExecutionId=$record.ExecutionId;ProjectLsn=$record.ProjectLsn;AttemptOrdinal=$record.AttemptOrdinal});Save-Record
        $abortBatch=if($scenario -ceq 'Abort'){"WAITFOR DELAY '00:00:03';IF NOT EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND folder_name=@folder AND project_name=@project AND status=2) THROW 57932,'SYNTHETIC_ABORT_CHANGED',1;EXEC catalog.stop_operation @operation_id=@id;"}else{''}
        $startBatch="IF NOT EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND folder_name=@folder AND project_name=@project AND status=1) THROW 57932,'SYNTHETIC_EXECUTION_CHANGED',1;DECLARE @level smallint=@logging;EXEC catalog.set_execution_parameter_value @execution_id=@id,@object_type=50,@parameter_name=N'LOGGING_LEVEL',@parameter_value=@level;EXEC catalog.start_execution @execution_id=@id;"+$abortBatch+"DECLARE @until datetime2=DATEADD(second,45,SYSUTCDATETIME());WHILE EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND status IN(1,2,5,8)) AND SYSUTCDATETIME()<@until BEGIN WAITFOR DELAY '00:00:00.250';END;IF NOT EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND status IN(3,4,6,7,9)) THROW 57932,'SYNTHETIC_TERMINAL_UNCONFIRMED',1;"
        [void](Windows-Query $startBatch @{id=$record.ExecutionId;version=$record.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName;logging=$logging})
        $status=[int](Query 'SELECT status FROM SSISDB.catalog.executions WHERE execution_id=@id AND project_lsn=@version;' @{id=$record.ExecutionId;version=$record.ProjectLsn}).Tables[0].Rows[0][0]
        $record.Executions[-1].Status=$status;Save-Record
        Assert ($status -eq $(switch($scenario){'Error'{4};'Abort'{3};default{7}})) 'NATIVE_TERMINAL_STATUS'
        if($scenario -ceq 'Error'){
            $messages=Query 'SELECT message FROM SSISDB.catalog.event_messages WHERE operation_id=@id AND message_type=120;' @{id=$record.ExecutionId}
            Assert (@($messages.Tables[0].Rows|Where-Object {([string]$_.message).Contains('SyntheticInvalid') -and ([string]$_.message).Contains('Conversion failed')}).Count -gt 0) 'OWN_SQL_FAILURE_PROVEN'
        }
        $captureArguments=@{ExecutionId=$record.ExecutionId;Connection=$connection;SourceReader=$readerAdapter;SourceBindingId=('LAB:'+$RunId.ToString()+':'+$InstanceId);ProducerAssemblyPath=$ProducerAssemblyPath;ExpectedBuildSha256=$ExpectedBuildSha256;ExpectedSourceCommit=$ExpectedSourceCommit;IncludeExecutionScopes=$true;IncludePipelineCorrelation=$true;IncludeComparisonContext=$true}
        $handover=& (Join-Path $root 'Code/Tools/Invoke-SsisCatalogHandover.ps1') @captureArguments
        Assert ($handover.Status -ceq 'CAPTURED') 'INDEPENDENT_HANDOVER_CAPTURED'
        $handover|Add-Member -NotePropertyName NativeExecutionId -NotePropertyValue $record.ExecutionId
        $record.Captures+=@([ordered]@{Scenario=$scenario;Models=$handover.ProjectModelsJson;Capture=$handover.ScopeSnapshotJson;HandoverId=$handover.ScopeHandoverId});Save-Record
        if($scenario -cmatch '^Baseline[2-5]?$'){if($scenario -ceq 'Baseline'){$baseline=$handover};$baselineCohort.Add($handover);$record.CompletedScenarios+=@($scenario);Save-Record;continue}
        if($IncludeBaselineContract){Test-BaselineContract $baselineCohort $handover $scenario}
        $comparison=Read-Comparison $baseline $handover
        $record.Comparisons+=@([ordered]@{Scenario=$scenario;Result=$comparison});Save-Record
        if($scenario -ceq 'Redeploy'){
            Assert ($comparison.comparisonBinding[0].StatusCode -ceq 'COMPARISON_BINDING_UNPROVEN' -and $comparison.comparisonBinding[0].ReasonCode -ceq 'COMPARISON_SOURCE_VERSION_DIFFERENT' -and @($comparison.objectComparison).Count -eq 0) 'CROSS_VERSION_PAIR_REFUSED';$record.CompletedScenarios+=@($scenario);Save-Record;continue
        }
        Assert ($comparison.comparisonBinding[0].StatusCode -ceq 'COMPARISON_CAPTURE_BOUND' -and $comparison.comparisonBinding[0].ModelExportMatch) 'SAME_EXPORT_CAPTURE_PAIR_BOUND'
        Assert ($comparison.comparisonBinding[0].WorkloadEquivalence -ceq 'UNPROVEN' -and $comparison.comparisonBinding[0].IsPartial) 'WORKLOAD_AND_COMPLETENESS_UNPROVEN'
        Assert (@($comparison.comparisonFindings|Where-Object Severity -CNE 'INFO').Count -eq 0) 'INFORMATIONAL_ONLY'
        if($scenario -cin @('Equal','Delay','Volume')){
            Assert ($comparison.comparisonBinding[0].ContextStatus -ceq 'MATCHED_OBSERVATION_CONTEXT') 'RUNTIME_CONTEXT_MATCHED'
            Test-DurationOracle $baseline $handover $comparison
            $flows=@($comparison.objectComparison|Where-Object MetricName -CEQ 'FLOW_DURATION_MS')
            Assert ($flows.Count -eq 7 -and @($flows|Where-Object {$_.BaselineMatchCount -ne 1 -or $_.CandidateMatchCount -ne 1}).Count -eq 0) 'SEVEN_LOOP_CHILD_FLOW_PAIRS'
            $paths=@($comparison.objectComparison|Where-Object MetricName -CEQ 'PATH_ROWS_SENT')
            Assert ($paths.Count -ge 9 -and @($paths|Where-Object {$_.BaselineSourceId -eq $_.CandidateSourceId}).Count -eq 0) 'PAIRING_INDEPENDENT_OF_NATIVE_IDS'
            $capture=$handover.ScopeSnapshotJson|ConvertFrom-Json -Depth 40
            foreach($path in $paths){
                $native=@($capture.pathTransfers|Where-Object {[long]$_.dataStatsId -eq [long]$path.CandidateSourceId})
                Assert ($native.Count -eq 1) 'NATIVE_PATH_EVIDENCE'
                $expected=if($path.PortRole -ceq 'ERROR'){0}elseif($path.PortRole -ceq 'NO_MATCH'){$rows-2}elseif($native[0].pathName -ceq 'SyntheticRoutingTransfer0'){2}else{$rows}
                Assert ($path.CandidateValue -eq $expected) 'CONTROLLED_PATH_VOLUME_ORACLE'
            }
            if($scenario -ceq 'Delay'){Assert (@($comparison.comparisonFindings|Where-Object RuleId -CEQ 'SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED').Count -gt 0) 'CONTROLLED_DELAY_FINDING'}
            if($scenario -ceq 'Volume'){Assert (@($comparison.comparisonFindings|Where-Object RuleId -CEQ 'SSIS_COMPARISON_OBSERVED_ROWS_CHANGED').Count -gt 0 -and @($comparison.comparisonFindings|Where-Object RuleId -CEQ 'SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED').Count -eq 0) 'VOLUME_CHANGE_SUPPRESSES_DURATION_FINDINGS'}
            if($scenario -ceq 'Equal'){Assert (@($paths|Where-Object DeltaValue -NE 0).Count -eq 0) 'EQUAL_OBSERVED_PATH_COUNTS';Test-OutputParity $baseline $handover}
        }else{
            Assert ($comparison.comparisonBinding[0].ContextStatus -ceq $(if($scenario -ceq 'Logging'){'LOGGING_LEVEL_DIFFERENT'}else{'NOT_BOTH_SUCCEEDED'})) 'INCOMPARABLE_RUNTIME_CONTEXT'
            Assert (@($comparison.objectComparison|Where-Object {$null -ne $_.DeltaValue}).Count -eq 0 -and @($comparison.comparisonFindings|Where-Object RuleId -CEQ 'SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED').Count -eq 0) 'NO_UNPROVEN_NUMERIC_COMPARISON'
            if($scenario -ceq 'Logging'){Assert (@($comparison.objectComparison|Where-Object {$_.ObjectKind -ceq 'PATH' -and $_.ComparisonStatus -ceq 'BASELINE_ONLY' -and $null -eq $_.CandidateValue}).Count -gt 0) 'LOGGING_ABSENCE_NOT_ZERO'}
            else{Assert (@($comparison.comparisonFindings|Where-Object RuleId -CEQ 'SSIS_COMPARISON_STATUS_CHANGED').Count -gt 0) 'TERMINAL_STATUS_CHANGED'}
        }
        $record.CompletedScenarios+=@($scenario);$record.Cases=$counter.Value;Save-Record
    }
    $record.Phase='PASSED';$record.Cases=$counter.Value;Save-Record
} catch {
    $record.PrimaryFailure=[ordered]@{Phase=$record.Phase;Type=$_.Exception.GetType().Name;Message=$_.Exception.Message};Save-Record
    throw
} finally {
    $primaryPhase=$record.Phase;$record.Phase='CLEANUP_OWN_OBJECTS';Save-Record
    $cleanupErrors=[Collections.Generic.List[string]]::new()
    try {
        foreach($owned in $record.Executions){
            try{[void](Windows-Query "IF EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND project_lsn=@version AND folder_name=@folder AND project_name=@project AND status IN(2,5,8)) BEGIN EXEC catalog.stop_operation @operation_id=@id;DECLARE @until datetime2=DATEADD(second,30,SYSUTCDATETIME());WHILE EXISTS(SELECT 1 FROM catalog.executions WHERE execution_id=@id AND status IN(2,5,8)) AND SYSUTCDATETIME()<@until WAITFOR DELAY '00:00:00.250';END;" @{id=$owned.ExecutionId;version=$owned.ProjectLsn;folder=$record.FolderName;project=$record.ProjectName})}catch{$cleanupErrors.Add('OWN_EXECUTION_STOP_UNCONFIRMED')}
        }
        if($record.FolderAttempted){
            if($record.FolderId -lt 1 -or $record.ProjectAttempted -and $record.ProjectId -lt 1){$cleanupErrors.Add('CATALOG_MUTATION_OWNERSHIP_UNCONFIRMED')}
            else {
                try {
                    [void](Windows-Query "SET XACT_ABORT ON;SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;BEGIN TRANSACTION;IF NOT EXISTS(SELECT 1 FROM catalog.folders WHERE folder_id=@folderId AND name=@folder) THROW 57500,'SYNTHETIC_FOLDER_CHANGED',1;IF EXISTS(SELECT 1 FROM catalog.environments WHERE folder_id=@folderId) OR EXISTS(SELECT 1 FROM catalog.projects WHERE folder_id=@folderId AND project_id<>@projectId) THROW 57500,'SYNTHETIC_FOREIGN_OBJECT_RETAINED',1;IF @projectId>0 BEGIN IF NOT EXISTS(SELECT 1 FROM catalog.projects WHERE project_id=@projectId AND folder_id=@folderId AND name=@project AND object_version_lsn=@version) THROW 57500,'SYNTHETIC_PROJECT_CHANGED',1;IF EXISTS(SELECT 1 FROM catalog.executions WHERE folder_name=@folder AND project_name=@project AND status IN(2,5,8)) THROW 57500,'SYNTHETIC_ACTIVE_EXECUTION_RETAINED',1;EXEC catalog.delete_project @folder_name=@folder,@project_name=@project;END;EXEC catalog.delete_folder @folder_name=@folder;COMMIT;IF EXISTS(SELECT 1 FROM catalog.folders WHERE folder_id=@folderId OR name=@folder) THROW 57500,'SYNTHETIC_FOLDER_REMOVAL_UNCONFIRMED',1;" @{folderId=$record.FolderId;folder=$record.FolderName;projectId=$record.ProjectId;project=$record.ProjectName;version=$record.ProjectLsn})
                } catch {$record.CatalogCleanupError=$_.Exception.ToString();Save-Record;$cleanupErrors.Add('CATALOG_CLEANUP_UNCONFIRMED')}
            }
        }
        # Die DB-Bereinigung bleibt unabhängig von einer Quellbereinigung.
        if($record.DatabaseAttempted){
            if(-not $databaseCreated -or $connection.State -ne 'Open'){$cleanupErrors.Add('DATABASE_MUTATION_OR_CHANNEL_UNCONFIRMED')}
            else {
                try {
                    [void](Query 'IF @@TRANCOUNT>0 ROLLBACK;');$connection.ChangeDatabase('master')
                    [void](Query "IF NOT EXISTS(SELECT 1 FROM sys.databases WHERE name=@name AND database_id=@id AND create_date=@created AND service_broker_guid=@broker) THROW 57932,'SYNTHETIC_DATABASE_IDENTITY_CHANGED',1;ALTER DATABASE [$database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE [$database];" @{name=$record.DatabaseIdentity.Name;id=$record.DatabaseIdentity.Id;created=$record.DatabaseIdentity.Created;broker=$record.DatabaseIdentity.BrokerGuid})
                    if((Query 'SELECT DB_ID(@DatabaseName);' @{DatabaseName=$database}).Tables[0].Rows[0][0] -isnot [DBNull]){throw 'SSIS_NATIVE_DATABASE_REMOVAL_UNCONFIRMED'}
                    $databaseCreated=$false
                } catch {$cleanupErrors.Add('DATABASE_CLEANUP_UNCONFIRMED')}
            }
        }
        $record.Cleanup=if($cleanupErrors.Count -eq 0){'CONFIRMED_OWN_OBJECTS_REMOVED'}else{'UNCONFIRMED_RECOVERY_REQUIRED'}
        $record.CleanupErrors=@($cleanupErrors);$record.Phase=$primaryPhase;Save-Record
    } finally {$connection.Dispose();$builder.Clear()}
    if($cleanupErrors.Count -gt 0){throw 'SSIS_NATIVE_CLEANUP_UNCONFIRMED_OWN_OBJECT_RECOVERY_REQUIRED'}
}
Write-Output "SSIS_COMPARISON_NATIVE_PASS cases=$($counter.Value); scenarios=$($record.CompletedScenarios -join ','); fixed SDK archive and own cleanup confirmed; existing SSISDB retained. Private receipt: $receipt"
