[CmdletBinding()]
param(
    [string]$EnvironmentFile=$env:SQL_SERVER_LAB_TEST_ENV_FILE,
    [string]$SchemaFile=$env:SQL_SERVER_LAB_TEST_ENV_SCHEMA_FILE,
    [Parameter(Mandatory)][string]$ProducerAssemblyPath,
    [Parameter(Mandatory)][string]$ExpectedSourceCommit
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Synthetischer Transportvertrag auf SQL2025/Linux. Die Testquelle bildet nur
# die benötigten Katalogspalten ab; sie qualifiziert keine echte SSISDB.
$root=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$text=Get-Content -LiteralPath $EnvironmentFile -Raw
if(-not ($text|Test-Json -SchemaFile $SchemaFile)){throw 'SSIS_CAPTURE_TEST_ENVIRONMENT_INVALID'}
$contract=$text|ConvertFrom-Json
$targets=@($contract.environments|Where-Object {$_.platform -ceq 'linux' -and [string]$_.sqlVersion -ceq '2025' -and $_.patch -ceq 'latest' -and $_.status -ceq 'READY' -and $_.runtimeStatus -ceq 'READY'})
if($contract.groupStatus -cne 'READY' -or $targets.Count -ne 1){throw 'SSIS_CAPTURE_TEST_EXACT_TARGET_REQUIRED'}
$builder=[Data.SqlClient.SqlConnectionStringBuilder]::new($targets[0].connectionString)
if(-not $builder.Encrypt){throw 'SSIS_CAPTURE_TEST_ENCRYPT_REQUIRED'}
$builder['Initial Catalog']='master'
$connection=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$source=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$contender=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$database='SyntheticSsisCapture_'+[guid]::NewGuid().ToString('N');$created=$false;$caseCount=[pscustomobject]@{Value=0}
$owned=[Collections.Generic.List[guid]]::new()
function Query([string]$Sql) {
    $command=$connection.CreateCommand();$command.CommandText=$Sql;$command.CommandTimeout=30
    try {$data=[Data.DataSet]::new();$adapter=[Data.SqlClient.SqlDataAdapter]::new($command);[void]$adapter.Fill($data);return ,$data} finally {$command.Dispose()}
}
function Assert([bool]$Condition,[string]$Label){if(-not $Condition){throw ('SSIS_CAPTURE_ASSERT_'+$Label)};$caseCount.Value++}
function Read-Table([Data.SqlClient.SqlDataReader]$Reader) {
    $table=[Data.DataTable]::new();for($i=0;$i -lt $Reader.FieldCount;$i++){[void]$table.Columns.Add($Reader.GetName($i),$Reader.GetFieldType($i))}
    while($Reader.Read()){$values=[object[]]::new($Reader.FieldCount);[void]$Reader.GetValues($values);[void]$table.Rows.Add($values)}
    return ,$table
}
try {
    $connection.Open();$source.Open();$contender.Open()
    [void](Query "CREATE DATABASE [$database] COLLATE SQL_Latin1_General_CP1_CS_AS;");$created=$true
    $connection.ChangeDatabase($database);$source.ChangeDatabase($database);$contender.ChangeDatabase($database)
    [void](Query 'CREATE SCHEMA [monitor] AUTHORIZATION [dbo];');[void](Query 'CREATE SCHEMA [catalog] AUTHORIZATION [dbo];')
    foreach($relative in @('Code/01_Common/095_USP_InternalWriteResultTable.sql','Code/01_Common/096_USP_InternalPrepareResultTables.sql','Code/01_Common/098_USP_InternalEmitConsoleResult.sql','Code/10_SSIS/040_USP_SsisPackageModelAnalysis.sql')) {
        $sql=[IO.File]::ReadAllText((Join-Path $root $relative)).Replace('USE [DeineDatenbank];',"USE [$database];")
        foreach($batch in [regex]::Split($sql,'(?im)^\s*GO\s*$')){if($batch.Trim()){[void](Query $batch)}}
    }
    [void](Query @'
CREATE TABLE catalog.folders(folder_id bigint PRIMARY KEY,name nvarchar(128));
CREATE TABLE catalog.projects(project_id bigint PRIMARY KEY,folder_id bigint,name nvarchar(128),object_version_lsn bigint);
CREATE TABLE catalog.executions(execution_id bigint,folder_name nvarchar(128),project_name nvarchar(128),package_name nvarchar(260),project_lsn bigint,object_type int,object_id bigint,created_time datetimeoffset(7),status int,start_time datetimeoffset(7),end_time datetimeoffset(7));
CREATE TABLE catalog.executables(execution_id bigint,executable_id bigint,executable_guid uniqueidentifier,package_name nvarchar(260),package_path nvarchar(max));
CREATE TABLE catalog.executable_statistics(statistics_id bigint,execution_id bigint,executable_id bigint,execution_path nvarchar(max),start_time datetimeoffset(7),end_time datetimeoffset(7),execution_duration int,execution_result int);
CREATE TABLE catalog.SyntheticArchive(payload varbinary(max));
INSERT catalog.folders VALUES(1,N'SyntheticFolder');INSERT catalog.projects VALUES(17,1,N'SyntheticProject',91);
INSERT catalog.executions VALUES(9007199254740993,N'SyntheticFolder',N'SyntheticProject',N'SyntheticRoot.dtsx',91,20,17,'2026-01-01T00:00:00+00:00',7,'2026-01-01T00:00:00+00:00','2026-01-01T00:00:01+00:00');
INSERT catalog.executables VALUES(9007199254740993,51,'11111111-1111-1111-1111-111111111111',N'SyntheticLabel',N'\Package'),(9007199254740993,52,'22222222-2222-2222-2222-222222222222',N'SyntheticLabel',N'\Package\SyntheticFlow');
INSERT catalog.executable_statistics VALUES(1,9007199254740993,51,N'\Package','2026-01-01T00:00:00+00:00','2026-01-01T00:00:01+00:00',1000,0),(2,9007199254740993,52,N'\Package\SyntheticFlow','2026-01-01T00:00:00+00:00','2026-01-01T00:00:01+00:00',1000,0);
'@)
    [void](Query "CREATE PROCEDURE catalog.get_project @folder_name nvarchar(128),@project_name nvarchar(128) AS BEGIN EXEC sys.sp_getapplock @Resource=N'SyntheticCaptureBarrier',@LockOwner=N'Transaction',@LockMode=N'Exclusive',@LockTimeout=0; WAITFOR DELAY '00:00:03'; SELECT payload FROM catalog.SyntheticArchive; END;")
    # Die beiden nativen IDs und refId-Pfade werden ausdrücklich vom Testautor
    # vorgegeben; der Test enthält keinen DTSX-Parser und keine Lineageableitung.
    $fixture=[IO.File]::ReadAllText((Join-Path $root 'Code/Tests/Fixtures/SSIS_Exchange/direct-8.dtsx'))
    $fixture=$fixture.Replace('DTS:refId="Package"','DTS:refId="Package" DTS:DTSID="{11111111-1111-1111-1111-111111111111}"').Replace('DTS:refId="Flow"','DTS:refId="Package\SyntheticFlow" DTS:DTSID="{22222222-2222-2222-2222-222222222222}"')
    $memory=[IO.MemoryStream]::new();$zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Create,$true)
    try {$entry=$zip.CreateEntry('SyntheticRoot.dtsx');$stream=$entry.Open();try {$bytes=[Text.UTF8Encoding]::new($false).GetBytes($fixture);$stream.Write($bytes)} finally {$stream.Dispose()}} finally {$zip.Dispose()}
    $insert=$connection.CreateCommand();$insert.CommandText='INSERT catalog.SyntheticArchive VALUES(@Bytes);';[void]$insert.Parameters.Add('@Bytes',[Data.SqlDbType]::VarBinary,-1);$insert.Parameters['@Bytes'].Value=$memory.ToArray()
    try {[void]$insert.ExecuteNonQuery()} finally {$insert.Dispose();$memory.Dispose()}
    $readerAdapter={param($Sql,$Parameters)
        # Ausschließlich diese synthetische Quelle ersetzt den festen DB-Namen.
        $command=$source.CreateCommand();$command.CommandTimeout=20
        $command.CommandText=$Sql.Replace('[SSISDB]',"[$database]").Replace("N''SSISDB''","N''$database''")
        [void]$command.Parameters.Add('@ExecutionId',[Data.SqlDbType]::BigInt);$command.Parameters['@ExecutionId'].Value=$Parameters.ExecutionId
        [void]$command.Parameters.Add('@ArchiveAsBase64',[Data.SqlDbType]::Bit);$command.Parameters['@ArchiveAsBase64'].Value=$true
        $reader=$null
        try {
            $expectedCurrent=(Query 'SELECT COUNT(*) FROM catalog.projects WHERE object_version_lsn=91;').Tables[0].Rows[0][0] -eq 1
            $pending=$command.ExecuteReaderAsync()
            if($expectedCurrent) {
                $barrier=$contender.CreateCommand();$barrier.CommandText="DECLARE @r int;EXEC @r=sys.sp_getapplock @Resource=N'SyntheticCaptureBarrier',@LockOwner=N'Session',@LockMode=N'Shared',@LockTimeout=100;IF @r>=0 EXEC sys.sp_releaseapplock @Resource=N'SyntheticCaptureBarrier',@LockOwner=N'Session';SELECT @r;"
                try {$held=$false;for($attempt=0;$attempt -lt 20;$attempt++){if([int]$barrier.ExecuteScalar() -eq -1){$held=$true;break};Start-Sleep -Milliseconds 50};Assert $held 'CAPTURE_BARRIER_OBSERVED'} finally {$barrier.Dispose()}
                $update=$contender.CreateCommand();$update.CommandText='SET LOCK_TIMEOUT 100;UPDATE catalog.projects SET object_version_lsn=92 WHERE project_id=17;';$blocked=$false
                try {[void]$update.ExecuteNonQuery()} catch {$lockError=$_.Exception;while($lockError.InnerException){$lockError=$lockError.InnerException};$blocked=$lockError -is [Data.SqlClient.SqlException] -and $lockError.Number -eq 1222} finally {$update.Dispose()}
                Assert $blocked 'PROJECT_VERSION_LOCK_HELD'
            }
            $reader=$pending.GetAwaiter().GetResult();$before=Read-Table $reader
            if($before.Rows.Count -eq 1 -and [string]$before.Rows[0].ProjectLsn -ceq [string]$before.Rows[0].CurrentProjectLsn) {
                if(-not $reader.NextResult() -or -not $reader.Read()){throw 'SSIS_CAPTURE_TEST_ARCHIVE_MISSING'}
                $archive=[Convert]::FromBase64String($reader.GetString(0));[void]$reader.NextResult();$observations=Read-Table $reader;[void]$reader.NextResult();$after=Read-Table $reader
                Assert (-not $reader.NextResult()) 'EXACT_RESULT_SHAPE'
                return [pscustomobject]@{Before=$before;Archive=[byte[]]$archive;Observations=$observations;After=$after}
            }
            return [pscustomobject]@{Before=$before;Archive=[byte[]]@();Observations=$null;After=$null}
        } finally {if($null -ne $reader){$reader.Dispose()};$command.Dispose()}
    }
    $arguments=@{ExecutionId=9007199254740993L;Connection=$connection;SourceReader=$readerAdapter;SourceBindingId='SYNTHETIC_REGISTERED_SOURCE';ProducerAssemblyPath=$ProducerAssemblyPath;ExpectedBuildSha256=(Get-FileHash -LiteralPath $ProducerAssemblyPath -Algorithm SHA256).Hash;ExpectedSourceCommit=$ExpectedSourceCommit}
    $handover=& (Join-Path $root 'Code/Tools/Invoke-SsisCatalogHandover.ps1') @arguments
    if($handover.LocalHandoverId){$owned.Add($handover.LocalHandoverId)};if($handover.RuntimeHandoverId){$owned.Add($handover.RuntimeHandoverId)}
    Assert ($handover.Status -ceq 'CAPTURED') 'CAPTURE_CREATED'
    $command=$connection.CreateCommand();$command.CommandTimeout=90
    $command.CommandText="DECLARE @Json nvarchar(max);EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@Model,@PackageBytes=@Bytes,@LocalHandoverId=@Id,@IncludeExecutionCorrelation=1,@ExecutionId=9007199254740993,@ExecutionSnapshotJson=@Snapshot,@RuntimeHandoverId=@Run,@ResultSetArt=@Mode,@IncludePackageViews=@Views,@IncludeObjectRules=@Views,@JsonErzeugen=1,@Json=@Json OUTPUT; SELECT @Json AS [ResultJson];"
    foreach($item in @(@('@Model',[Data.SqlDbType]::NVarChar,$handover.PackageModelJson),@('@Bytes',[Data.SqlDbType]::VarBinary,[byte[]]$handover.PackageBytes),@('@Snapshot',[Data.SqlDbType]::NVarChar,$handover.ExecutionSnapshotJson))){[void]$command.Parameters.Add($item[0],$item[1],-1);$command.Parameters[$item[0]].Value=$item[2]}
    foreach($item in @(@('@Id',$handover.LocalHandoverId),@('@Run',$handover.RuntimeHandoverId))){[void]$command.Parameters.Add($item[0],[Data.SqlDbType]::UniqueIdentifier);$command.Parameters[$item[0]].Value=$item[1]}
    [void]$command.Parameters.Add('@Mode',[Data.SqlDbType]::VarChar,16);[void]$command.Parameters.Add('@Views',[Data.SqlDbType]::Bit)
    try {
        foreach($views in @($false,$true)) {
            $command.Parameters['@Mode'].Value='RAW';$command.Parameters['@Views'].Value=$views;$data=[Data.DataSet]::new();$adapter=[Data.SqlClient.SqlDataAdapter]::new($command);[void]$adapter.Fill($data)
            $count=if($views){16}else{10};$result=$data.Tables[$count].Rows[0].ResultJson|ConvertFrom-Json -Depth 32
            Assert ($data.Tables.Count -eq $count+1 -and $result.runtimeBinding[0].MappedRowCount -eq 2) ('RAW_GROUPS_'+$count)
            Assert ($result.executionCorrelation[1].ModelNodeId -ceq 'exe1' -and $result.sourceBinding[0].ProducerTrust -ceq 'VERIFIED_LOCAL') 'PRODUCER_TO_RECEIVER_BINDING'
            $table=$data.Tables[$count-1];$json=$result.executionCorrelation
            Assert ($table.Columns.Count -eq @($json[0].PSObject.Properties).Count -and $table.Rows.Count -eq $json.Count) 'RAW_JSON_SCHEMA_PARITY'
        }
    } finally {$command.Dispose()}
    Import-Module (Join-Path $root 'Code/Tools/SsisHandoverSupport.psm1') -Force -Scope Local
    $receiptCount=(Query "SELECT COUNT(*) FROM sys.extended_properties WITH(READCOMMITTEDLOCK) WHERE major_id=OBJECT_ID(N'monitor.USP_SsisPackageModelAnalysis');").Tables[0].Rows[0][0]
    [void](Query 'BEGIN TRANSACTION;')
    try {
        $rejected=$false
        try {Register-SsisHandover -Connection $connection -ModelJson $handover.PackageModelJson -PackageBytes $handover.PackageBytes|Out-Null} catch {$rejected=$_.Exception.Message -ceq 'SSIS_HANDOVER_CALLER_TRANSACTION_NOT_ALLOWED'}
        Assert ($rejected -and (Query 'SELECT @@TRANCOUNT;').Tables[0].Rows[0][0] -eq 1) 'FOREIGN_CALLER_TRANSACTION_RETAINED'
    } finally {[void](Query 'IF @@TRANCOUNT>0 ROLLBACK;')}
    [void](Query "CREATE TRIGGER SyntheticSsisRegistrationDelay ON DATABASE FOR CREATE_EXTENDED_PROPERTY AS BEGIN WAITFOR DELAY '00:00:04';END;")
    try {
        $timedOut=$false
        try {Register-SsisHandover -Connection $connection -ModelJson $handover.PackageModelJson -PackageBytes $handover.PackageBytes -ExecutionSnapshotJson $handover.ExecutionSnapshotJson -CommandTimeoutSeconds 1|Out-Null}
        catch {$failure=$_.Exception;while($failure -isnot [Data.SqlClient.SqlException] -and $failure.InnerException){$failure=$failure.InnerException};$timedOut=$failure -is [Data.SqlClient.SqlException] -and $failure.Number -eq -2}
        Assert ($timedOut -and $connection.State -eq 'Open' -and (Query 'SELECT @@TRANCOUNT;').Tables[0].Rows[0][0] -eq 0) 'REGISTRATION_ATTENTION_ROLLBACK'
        Assert ((Query "SELECT COUNT(*) FROM sys.extended_properties WITH(READCOMMITTEDLOCK) WHERE major_id=OBJECT_ID(N'monitor.USP_SsisPackageModelAnalysis');").Tables[0].Rows[0][0] -eq $receiptCount) 'NO_PARTIAL_REGISTRATION'
    } finally {[void](Query 'DROP TRIGGER SyntheticSsisRegistrationDelay ON DATABASE;')}
    [void](Query 'UPDATE catalog.projects SET object_version_lsn=92;')
    $unbound=& (Join-Path $root 'Code/Tools/Invoke-SsisCatalogHandover.ps1') @arguments
    Assert ($unbound.Status -ceq 'RUNTIME_BINDING_UNPROVEN' -and $unbound.ReasonCode -ceq 'EXECUTION_PROJECT_VERSION_UNAVAILABLE') 'HISTORICAL_PROJECT_NOT_SUBSTITUTED'
    Assert ((Query 'SELECT @@TRANCOUNT;').Tables[0].Rows[0][0] -eq 0) 'TARGET_TRANSACTION_PRESERVED'
    Write-Output "SSIS_CAPTURE_SYNTHETIC_TRANSPORT_PASS cases=$($caseCount.Value); live SSISDB qualification NOT_EXECUTED."
} finally {
    $source.Dispose();$contender.Dispose()
    if($connection.State -eq 'Open' -and $created){
        [void](Query 'IF @@TRANCOUNT>0 ROLLBACK;');$connection.ChangeDatabase('master');[void](Query "ALTER DATABASE [$database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;DROP DATABASE [$database];");$created=$false
    }
    $connection.Dispose();if($created){throw 'SSIS_CAPTURE_TEST_CLEANUP_UNCONFIRMED'}
}
