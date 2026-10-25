[CmdletBinding()]
param(
    [Parameter(Mandatory)][byte[]]$Archive,
    [Parameter(Mandatory)][Data.DataTable]$Before,
    [Parameter(Mandatory)][Data.DataTable]$After,
    [Parameter(Mandatory)][Data.DataTable]$Observations,
    [Parameter(Mandatory)][Data.DataTable]$Events,
    [Parameter(Mandatory)][Data.SqlClient.SqlConnection]$Connection,
    [Parameter(Mandatory)][string]$SourceBindingSha256,
    [Parameter(Mandatory)][string]$ProducerAssemblyPath,
    [Parameter(Mandatory)][string]$ExpectedBuildSha256,
    [Parameter(Mandatory)][string]$ExpectedSourceCommit,
    [ValidateRange(1,24)][int]$ValidHours=1,
    [string]$DotnetPath='dotnet',
    [switch]$IncludePipelineCorrelation,
    [Data.DataTable]$ComponentPhases,
    [Data.DataTable]$PathTransfers
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Interner Consumer des festen gebundenen Katalogbatches. Kein Import fremder
# Archive als qualifizierte Quelle; die öffentliche Katalogübergabe prüft Kanal,
# aktuelle Projekt-LSN und unveränderte Vorher-/Nachherbindung vor diesem Aufruf.
$source=$Before.Rows[0];$last=$After.Rows[0]
$packages=[Collections.Generic.List[object]]::new();$bytesByKey=@{}
$pending=[Collections.Generic.Queue[string]]::new();$pending.Enqueue([string]$source.PackageFileName)
$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$stream=[IO.MemoryStream]::new($Archive,$false);$zip=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read,$false)
$expanded=0L;$deadline=[datetime]::UtcNow.AddSeconds(60)
function Remaining-Seconds {
    $remaining=[int][math]::Floor(($deadline-[datetime]::UtcNow).TotalSeconds)
    if($remaining -lt 1){throw 'SSIS_SCOPE_EXPORT_TIME_LIMIT'}
    return $remaining
}
try {
    if($zip.Entries.Count -gt 10000){throw 'SSIS_SCOPE_ARCHIVE_LIMIT'}
    while($pending.Count -gt 0) {
        if([datetime]::UtcNow -gt $deadline){throw 'SSIS_SCOPE_EXPORT_TIME_LIMIT'}
        $entryName=$pending.Dequeue();if(-not $seen.Add($entryName)){continue}
        if($packages.Count -ge 16){throw 'SSIS_SCOPE_PACKAGE_LIMIT'}
        $entries=@($zip.Entries|Where-Object {[string]::Equals($_.FullName,$entryName,[StringComparison]::OrdinalIgnoreCase)})
        if($entries.Count -ne 1 -or -not [string]::Equals($entries[0].FullName,$entryName,[StringComparison]::Ordinal) -or $entries[0].Length -lt 1 -or $entries[0].Length -gt 16777216){throw 'SSIS_SCOPE_PACKAGE_ENTRY_UNPROVEN'}
        $expanded+=$entries[0].Length;if($expanded -gt 67108864){throw 'SSIS_SCOPE_EXPANDED_ARCHIVE_LIMIT'}
        $input=$entries[0].Open();$memory=[IO.MemoryStream]::new()
        try {$buffer=[byte[]]::new(65536);while(($read=$input.Read($buffer,0,$buffer.Length)) -gt 0){if($memory.Length+$read -gt 16777216){throw 'SSIS_SCOPE_PACKAGE_ENTRY_UNPROVEN'};$memory.Write($buffer,0,$read)};$bytes=$memory.ToArray()}finally{$input.Dispose();$memory.Dispose()}
        $handover=& (Join-Path $PSScriptRoot 'Invoke-SsisQualifiedHandover.ps1') -ProducerAssemblyPath $ProducerAssemblyPath -ExpectedBuildSha256 $ExpectedBuildSha256 -ExpectedSourceCommit $ExpectedSourceCommit -PackageBytes $bytes -Connection $Connection -ValidHours $ValidHours -DotnetPath $DotnetPath -ProducerTimeoutSeconds (Remaining-Seconds) -IncludeObjectIdentities -IncludeExecutionScopes -IncludePipelineCorrelation:$IncludePipelineCorrelation -PrepareOnly
        $key='p'+($packages.Count+1)
        $identities=$handover.ObjectIdentitiesJson|ConvertFrom-Json -Depth 32
        if($identities.version -cne '1.2.0'){throw 'SSIS_SCOPE_IDENTITY_PROFILE_UNSUPPORTED'}
        $packages.Add([ordered]@{packageKey=$key;entryName=$entryName;model=($handover.PackageModelJson|ConvertFrom-Json -Depth 32);identities=$identities})
        if($IncludePipelineCorrelation){$packages[$packages.Count-1]['pipelineIdentities']=($handover.PipelineIdentitiesJson|ConvertFrom-Json -Depth 32)}
        $bytesByKey[$key]=$bytes
        foreach($item in $identities.objects){if($null -ne $item.callTarget){$pending.Enqueue([string]$item.callTarget)}}
    }
}finally{$zip.Dispose();$stream.Dispose()}
$modelSet=[ordered]@{contract='ssis-project-model-set';version='1.0.0';rootPackageKey='p1';packages=@($packages)}
$modelJson=$modelSet|ConvertTo-Json -Depth 40 -Compress
function Cell($Row,[string]$Name){if($Row.IsNull($Name)){return $null};return $Row[$Name]}
$rows=@(foreach($row in $Observations.Rows){[ordered]@{statisticsId=[string]$row.StatisticsId;executionId=[string]$row.ExecutionId;executableId=[string]$row.ExecutableId;executableGuid=(Cell $row 'ExecutableGuid');packageName=(Cell $row 'PackageName');packagePath=(Cell $row 'PackagePath');executionPath=(Cell $row 'ExecutionPath');startTime=(Cell $row 'StartTime');endTime=(Cell $row 'EndTime');durationMs=(Cell $row 'DurationMs');executionResult=(Cell $row 'ExecutionResult')}})
$messages=@(foreach($row in $Events.Rows){[ordered]@{eventMessageId=[string]$row.EventMessageId;eventName=(Cell $row 'EventName');executableGuid=(Cell $row 'ExecutableGuid');packageName=(Cell $row 'PackageName');packagePath=(Cell $row 'PackagePath');executionPath=(Cell $row 'ExecutionPath');messageTime=(Cell $row 'MessageTime');messageCode=(Cell $row 'MessageCode')}})
$capture=[ordered]@{contract='ssis-execution-scopes';version='1.0.0';method='SSISDB_CURRENT_PROJECT_SCOPES_V1';modelSetSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::Unicode.GetBytes($modelJson))).ToLowerInvariant();archiveSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Archive)).ToLowerInvariant();
    execution=[ordered]@{executionId=[string]$source.ExecutionId;projectId=[string]$source.ProjectId;projectLsn=[string]$source.ProjectLsn;catalogDatabaseGuid=[string]$source.CatalogDatabaseGuid;sourceBindingSha256=$SourceBindingSha256;packageFileName=[string]$source.PackageFileName;loggingLevel=(Cell $last 'LoggingLevel');executionStatus=[int]$last.ExecutionStatus;snapshotStartedUtc=[string]$source.ReadTimeUtc;snapshotCompletedUtc=[string]$last.ReadTimeUtc};observations=$rows;events=$messages}
if($IncludePipelineCorrelation) {
    $capture.version='1.1.0';$capture.method='SSISDB_CURRENT_PROJECT_PIPELINES_V1'
    $sources=[Collections.Generic.List[object]]::new()
    foreach($description in @(@{Name='componentPhases';Table=$ComponentPhases;Fields=@('PhaseStatsId','PackageName','TaskName','ComponentName','PhaseName','StartTime','EndTime','ExecutionPath')},@{Name='pathTransfers';Table=$PathTransfers;Fields=@('DataStatsId','PackageName','TaskName','PathIdentificationString','PathName','SourceComponentName','DestinationComponentName','RowsSent','CreatedTime','ExecutionPath')})) {
        $table=$description.Table;if($table -isnot [Data.DataTable] -or -not $table.Columns.Contains('SourceErrorNumber')){throw 'SSIS_PIPELINE_SOURCE_SHAPE'}
        $sourceErrorNumbers=@($table.Rows|Where-Object {-not $_.IsNull('SourceErrorNumber')})
        if($sourceErrorNumbers.Count -gt 0){if($table.Rows.Count -ne 1){throw 'SSIS_PIPELINE_SOURCE_SHAPE'};foreach($column in $table.Columns){if($column.ColumnName -cne 'SourceErrorNumber' -and -not $table.Rows[0].IsNull($column.ColumnName)){throw 'SSIS_PIPELINE_SOURCE_SHAPE'}};$sourceErrorNumber=0;if(-not [int]::TryParse([string]$sourceErrorNumbers[0].SourceErrorNumber,[Globalization.NumberStyles]::None,[Globalization.CultureInfo]::InvariantCulture,[ref]$sourceErrorNumber) -or $sourceErrorNumber -lt 1){throw 'SSIS_PIPELINE_SOURCE_SHAPE'};$state=if($sourceErrorNumber -in 229,262,297,300,371){'DENIED_PERMISSION'}else{'UNAVAILABLE'};$capture[$description.Name]=@()}
        else {
            $sourceErrorNumber=$null;$state=if($table.Rows.Count -eq 0){'AVAILABLE_EMPTY'}else{'AVAILABLE'}
            foreach($field in $description.Fields){if(-not $table.Columns.Contains($field)){throw 'SSIS_PIPELINE_SOURCE_SHAPE'}}
            $capture[$description.Name]=@(foreach($row in $table.Rows){$item=[ordered]@{};foreach($field in $description.Fields){$key=$field.Substring(0,1).ToLowerInvariant()+$field.Substring(1);$item[$key]=Cell $row $field};$item})
        }
        $sources.Add([ordered]@{source=$description.Name;status=$state;errorNumber=$sourceErrorNumber})
    }
    $capture.pipelineSources=@($sources)
}
$captureJson=$capture|ConvertTo-Json -Depth 32 -Compress
if([Text.Encoding]::Unicode.GetByteCount($modelJson) -gt 16777216 -or [Text.Encoding]::Unicode.GetByteCount($captureJson) -gt 16777216){throw 'SSIS_SCOPE_TRANSPORT_LIMIT'}
# Validierung derselben kanonischen Einzelmodelle einschließlich Originalbytes.
foreach($package in $packages) {
    $remaining=Remaining-Seconds
    $command=$Connection.CreateCommand();$command.CommandText="DECLARE @s varchar(40);EXEC monitor.USP_SsisPackageModelAnalysis @PackageModelJson=@model,@PackageBytes=@bytes,@MaxDurationSeconds=@seconds,@ResultSetArt='NONE',@StatusCodeOut=@s OUTPUT;IF @s<>'AVAILABLE_LIMITED' THROW 57410,'SSIS_SCOPE_MODEL_REJECTED',1;";$command.CommandTimeout=$remaining
    [void]$command.Parameters.AddWithValue('@seconds',$remaining)
    [void]$command.Parameters.AddWithValue('@model',($package.model|ConvertTo-Json -Depth 32 -Compress));[void]$command.Parameters.AddWithValue('@bytes',[byte[]]$bytesByKey[$package.packageKey])
    try{[void]$command.ExecuteNonQuery()}finally{$command.Dispose()}
}
$id=[guid]::NewGuid();$remaining=Remaining-Seconds;$command=$Connection.CreateCommand();$command.CommandTimeout=$remaining
$command.CommandText=@'
IF @@TRANCOUNT<>0 OR HAS_PERMS_BY_NAME(N'monitor.USP_SsisPackageModelAnalysis',N'OBJECT',N'ALTER')<>1 THROW 57410,N'SSIS_SCOPE_REGISTRATION_AUTHORITY_REQUIRED',1;
DECLARE @now datetime2(3)=SYSUTCDATETIME(),@receipt nvarchar(3000);
SET @receipt=(SELECT 'ssis-local-scope-handover' AS contract,'1.0.0' AS version,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@models)),2) AS modelSetSha256,CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@capture)),2) AS captureSha256,CONVERT(varchar(24),@now,127)+'Z' AS issuedUtc,CONVERT(varchar(24),DATEADD(hour,@hours,@now),127)+'Z' AS expiresUtc FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
EXEC sys.sp_addextendedproperty @name=@name,@value=@receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
'@
foreach($pair in @(@{Name='@models';Value=$modelJson},@{Name='@capture';Value=$captureJson},@{Name='@name';Value=('SSIS_SCOPE_'+$id.ToString('D').ToLowerInvariant())},@{Name='@hours';Value=$ValidHours})){[void]$command.Parameters.AddWithValue($pair.Name,$pair.Value)}
try{[void]$command.ExecuteNonQuery()}finally{$command.Dispose()}
[pscustomobject]@{Status='CAPTURED';ExecutionId=[long]$source.ExecutionId;ProjectModelsJson=$modelJson;ScopeSnapshotJson=$captureJson;ScopeHandoverId=$id}
