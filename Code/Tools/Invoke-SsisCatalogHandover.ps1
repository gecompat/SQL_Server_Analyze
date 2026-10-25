[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(1,[long]::MaxValue)][long]$ExecutionId,
    [Parameter(Mandatory)][Data.SqlClient.SqlConnection]$Connection,
    [Data.SqlClient.SqlConnection]$SourceConnection,
    [scriptblock]$SourceReader,
    [ValidateLength(1,256)][string]$SourceBindingId,
    [Parameter(Mandatory)][string]$ProducerAssemblyPath,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedBuildSha256,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
    [ValidateRange(1,24)][int]$ValidHours=1,
    [string]$DotnetPath='dotnet'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Der explizite SourceReader ist ein qualifizierter Transportadapter, kein
# fremdes Snapshotdokument. Er führt den vollständigen festen Capturebatch
# einmal in einem gebundenen Kanal aus. Der Standard verwendet SqlClient direkt.
if($Connection.State -ne 'Open'){throw 'SSIS_CATALOG_TARGET_CONNECTION_REQUIRED'}
if($null -eq $SourceConnection){$SourceConnection=$Connection}
if($null -eq $SourceReader -and $SourceConnection.State -ne 'Open'){throw 'SSIS_CATALOG_SOURCE_CONNECTION_REQUIRED'}
if($null -ne $SourceReader -and -not $SourceBindingId){throw 'SSIS_CATALOG_QUALIFIED_READER_BINDING_REQUIRED'}
$sourceChannel=if($null -eq $SourceReader){$SourceConnection.ClientConnectionId}else{$null}
if($null -eq $SourceReader){$SourceBindingId='SQLCLIENT:'+([guid]$sourceChannel).ToString('D')}
$sourceBindingSha=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($SourceBindingId))).ToLowerInvariant()
$check=$Connection.CreateCommand();$check.CommandText='SELECT @@TRANCOUNT;'
try {if($check.ExecuteScalar() -ne 0){throw 'SSIS_CATALOG_CALLER_TRANSACTION_NOT_ALLOWED'}} finally {$check.Dispose()}
# Alle Quellreads laufen in einer einzigen gebundenen Lesetransaktion.
# HOLDLOCK auf Projekt und Ordner verhindert einen Projektwechsel während
# get_project; reine Vorher-/Nachher-Hashes würden einen ABA-Wechsel übersehen.
$metadataSql=@'
SELECT CONVERT(varchar(20),[e].[execution_id]) AS [ExecutionId],[e].[folder_name] AS [FolderName],[e].[project_name] AS [ProjectName],[e].[package_name] AS [PackageFileName],
 CONVERT(varchar(20),[e].[project_lsn]) AS [ProjectLsn],CONVERT(varchar(20),[p].[project_id]) AS [ProjectId],CASE WHEN [f].[folder_id] IS NOT NULL THEN CONVERT(varchar(20),[p].[object_version_lsn]) END AS [CurrentProjectLsn],
 CONVERT(varchar(36),[d].[service_broker_guid]) AS [CatalogDatabaseGuid],CONVERT(varchar(40),SWITCHOFFSET([e].[created_time],'+00:00'),127) AS [ExecutionCreatedUtc],
 [e].[status] AS [ExecutionStatus],CONVERT(varchar(40),[e].[start_time],127) AS [StartTime],CONVERT(varchar(40),[e].[end_time],127) AS [EndTime],
 CONVERT(varchar(40),SYSUTCDATETIME(),127)+'Z' AS [ReadTimeUtc]
FROM [SSISDB].[catalog].[executions] AS [e] WITH (READCOMMITTEDLOCK)
LEFT JOIN [SSISDB].[catalog].[projects] AS [p] WITH (HOLDLOCK) ON [e].[object_type]=20 AND [p].[project_id]=[e].[object_id] AND [p].[name] COLLATE Latin1_General_100_BIN2=[e].[project_name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([p].[name])=DATALENGTH([e].[project_name])
LEFT JOIN [SSISDB].[catalog].[folders] AS [f] WITH (HOLDLOCK) ON [f].[folder_id]=[p].[folder_id] AND [f].[name] COLLATE Latin1_General_100_BIN2=[e].[folder_name] COLLATE Latin1_General_100_BIN2 AND DATALENGTH([f].[name])=DATALENGTH([e].[folder_name])
JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK) ON [d].[name]=N'SSISDB' AND [d].[state]=0
WHERE [e].[execution_id]=@ExecutionId;
'@
$observationsSql=@'
SELECT TOP (50001) CONVERT(varchar(20),[s].[statistics_id]) AS [StatisticsId],CONVERT(varchar(20),[s].[execution_id]) AS [ExecutionId],CONVERT(varchar(20),[s].[executable_id]) AS [ExecutableId],
 [e].[executable_guid] AS [ExecutableGuid],[e].[package_name] AS [PackageName],CASE WHEN DATALENGTH([e].[package_path])<=8000 THEN [e].[package_path] END AS [PackagePath],CASE WHEN DATALENGTH([s].[execution_path])<=8000 THEN [s].[execution_path] END AS [ExecutionPath],
 CONVERT(varchar(40),[s].[start_time],127) AS [StartTime],CONVERT(varchar(40),[s].[end_time],127) AS [EndTime],[s].[execution_duration] AS [DurationMs],[s].[execution_result] AS [ExecutionResult]
FROM [SSISDB].[catalog].[executable_statistics] AS [s] WITH (READCOMMITTEDLOCK)
JOIN [SSISDB].[catalog].[executables] AS [e] WITH (READCOMMITTEDLOCK) ON [e].[execution_id]=[s].[execution_id] AND [e].[executable_id]=[s].[executable_id]
WHERE [s].[execution_id]=@ExecutionId ORDER BY [s].[statistics_id];
'@
$nonce=[guid]::NewGuid().ToString('N')
$beforeTable='#SsisCatalogHandover_Before_'+$nonce;$archiveTable='#SsisCatalogHandover_Archive_'+$nonce
$beforeSql=$metadataSql.Replace('FROM [SSISDB].[catalog].[executions]','INTO '+$beforeTable+' FROM [SSISDB].[catalog].[executions]')
$inner=@"
IF @@TRANCOUNT<>0 THROW 57500,N'SSIS_CATALOG_SOURCE_TRANSACTION_NOT_ALLOWED',1;
BEGIN TRY
 BEGIN TRANSACTION;
 $beforeSql
 SELECT * FROM $beforeTable;
 IF (SELECT COUNT(*) FROM $beforeTable)<>1 OR EXISTS(SELECT 1 FROM $beforeTable WHERE [ProjectId] IS NULL OR [CurrentProjectLsn] IS NULL OR [ProjectLsn]<>[CurrentProjectLsn])
 BEGIN COMMIT TRANSACTION;RETURN;END;
 DECLARE @Folder nvarchar(128),@Project nvarchar(128);
 SELECT @Folder=[FolderName],@Project=[ProjectName] FROM $beforeTable;
 IF @ArchiveAsBase64=1
 BEGIN
  CREATE TABLE $archiveTable([ProjectStream] varbinary(max));
  INSERT $archiveTable EXEC [SSISDB].[catalog].[get_project] @folder_name=@Folder,@project_name=@Project;
  IF (SELECT COUNT(*) FROM $archiveTable)<>1 OR EXISTS(SELECT 1 FROM $archiveTable WHERE DATALENGTH([ProjectStream]) NOT BETWEEN 1 AND 67108864) THROW 57500,N'SSIS_CATALOG_ARCHIVE_LIMIT',1;
  SELECT (SELECT [ProjectStream] AS [*] FOR XML PATH(''),BINARY BASE64) AS [ProjectStreamBase64] FROM $archiveTable;
 END
 ELSE EXEC [SSISDB].[catalog].[get_project] @folder_name=@Folder,@project_name=@Project;
 $observationsSql
 $metadataSql
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
"@
# Der dynamische Batch begrenzt die Temp- und SET-Sichtbarkeit; sämtliche
# variablen Daten bleiben Parameter. Der Transport darf nur die Binärdarstellung wählen.
$captureSql="EXEC [sys].[sp_executesql] N'"+$inner.Replace("'","''")+"',N'@ExecutionId bigint,@ArchiveAsBase64 bit',@ExecutionId=@ExecutionId,@ArchiveAsBase64=@ArchiveAsBase64;"
function Read-CurrentTable([Data.SqlClient.SqlDataReader]$Reader) {
    $table=[Data.DataTable]::new();for($i=0;$i -lt $Reader.FieldCount;$i++){[void]$table.Columns.Add($Reader.GetName($i),$Reader.GetFieldType($i))}
    $size=0L
    while($Reader.Read()) {
        $values=[object[]]::new($Reader.FieldCount);[void]$Reader.GetValues($values)
        foreach($value in $values){$size+=if($value -is [string]){[Text.Encoding]::Unicode.GetByteCount($value)}else{32}}
        if($size -gt 16777216 -or $table.Rows.Count -ge 50001){throw 'SSIS_CATALOG_OBSERVATION_LIMIT'}
        [void]$table.Rows.Add($values)
    }
    return ,$table
}
if($null -ne $SourceReader) {
    # Rückgabe: Before/After/Observations als DataTable, Archive als byte[].
    # Ein qualifizierter Adapter führt genau diesen Batch in einem Kanal aus,
    # prüft seine Quellenbindung und darf keinen fertigen fremden Capture einlesen.
    $capture=& $SourceReader $captureSql @{ExecutionId=$ExecutionId;ArchiveAsBase64=$false}
    $before=$capture.Before;$after=$capture.After;$observed=$capture.Observations;$archive=[byte[]]$capture.Archive
} else {
    $sourceCheck=$SourceConnection.CreateCommand();$sourceCheck.CommandText='SELECT @@TRANCOUNT;';$sourceCheck.CommandTimeout=10
    try {if($sourceCheck.ExecuteScalar() -ne 0){throw 'SSIS_CATALOG_SOURCE_TRANSACTION_NOT_ALLOWED'}} finally {$sourceCheck.Dispose()}
    $command=$SourceConnection.CreateCommand();$command.CommandText=$captureSql;$command.CommandTimeout=30
    [void]$command.Parameters.Add('@ExecutionId',[Data.SqlDbType]::BigInt);$command.Parameters['@ExecutionId'].Value=$ExecutionId
    [void]$command.Parameters.Add('@ArchiveAsBase64',[Data.SqlDbType]::Bit);$command.Parameters['@ArchiveAsBase64'].Value=$false
    $reader=$null
    try {
        $reader=$command.ExecuteReader([Data.CommandBehavior]::SequentialAccess)
        $before=Read-CurrentTable $reader;$after=$null;$observed=$null;$archive=$null
        if($before.Rows.Count -eq 1 -and -not $before.Rows[0].IsNull('ProjectId') -and -not $before.Rows[0].IsNull('CurrentProjectLsn') -and [string]::Equals([string]$before.Rows[0].ProjectLsn,[string]$before.Rows[0].CurrentProjectLsn,[StringComparison]::Ordinal)) {
            if(-not $reader.NextResult() -or -not $reader.Read()){throw 'SSIS_CATALOG_ARCHIVE_UNAVAILABLE'}
            $stream=$reader.GetStream(0);$buffer=[byte[]]::new(65536);$blob=[IO.MemoryStream]::new()
            try {while(($read=$stream.Read($buffer,0,$buffer.Length)) -gt 0){if($blob.Length+$read -gt 67108864){throw 'SSIS_CATALOG_ARCHIVE_LIMIT'};$blob.Write($buffer,0,$read)};$archive=$blob.ToArray()} finally {$blob.Dispose();$stream.Dispose()}
            if($reader.Read() -or -not $reader.NextResult()){throw 'SSIS_CATALOG_ARCHIVE_AMBIGUOUS'}
            $observed=Read-CurrentTable $reader
            if(-not $reader.NextResult()){throw 'SSIS_CATALOG_READER_SHAPE_INVALID'}
            $after=Read-CurrentTable $reader
            if($reader.NextResult()){throw 'SSIS_CATALOG_READER_SHAPE_INVALID'}
        }
    } finally {
        if($null -ne $reader){$reader.Dispose()};$command.Dispose()
        # Ein Attention-/Transportfehler darf die eigene Lesetransaktion nicht halten.
        if($SourceConnection.State -eq 'Open') {
            $rollback=$SourceConnection.CreateCommand();$rollback.CommandText='IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;';$rollback.CommandTimeout=10
            try {[void]$rollback.ExecuteNonQuery()} catch {$SourceConnection.Close();throw 'SSIS_CATALOG_SOURCE_ROLLBACK_UNCONFIRMED'} finally {$rollback.Dispose()}
        }
    }
}
if($before -isnot [Data.DataTable] -or $before.Rows.Count -ne 1){throw 'SSIS_CATALOG_EXECUTION_UNAVAILABLE'}
$source=$before.Rows[0]
if($source.IsNull('ProjectId') -or $source.IsNull('CurrentProjectLsn') -or -not [string]::Equals([string]$source.ProjectLsn,[string]$source.CurrentProjectLsn,[StringComparison]::Ordinal)) {
    return [pscustomobject]@{Status='RUNTIME_BINDING_UNPROVEN';ReasonCode='EXECUTION_PROJECT_VERSION_UNAVAILABLE';ExecutionId=$ExecutionId}
}
if($after -isnot [Data.DataTable] -or $observed -isnot [Data.DataTable] -or $after.Rows.Count -ne 1){throw 'SSIS_CATALOG_READER_SHAPE_INVALID'}
if($observed.Rows.Count -gt 50000){throw 'SSIS_CATALOG_OBSERVATION_LIMIT'}
if($archive.Length -eq 0 -or $archive.Length -gt 67108864){throw 'SSIS_CATALOG_ARCHIVE_LIMIT'}
foreach($field in @('ExecutionId','FolderName','ProjectName','PackageFileName','ProjectLsn','ProjectId','CurrentProjectLsn','CatalogDatabaseGuid','ExecutionCreatedUtc')) {
    if(-not [string]::Equals([string]$before.Rows[0][$field],[string]$after.Rows[0][$field],[StringComparison]::Ordinal)){throw 'SSIS_CATALOG_SOURCE_CHANGED'}
}
if($null -eq $SourceReader -and $SourceConnection.ClientConnectionId -ne $sourceChannel){throw 'SSIS_CATALOG_SOURCE_CHANNEL_CHANGED'}
$memory=[IO.MemoryStream]::new($archive,$false);$zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Read,$false)
try {
    if($zip.Entries.Count -gt 10000){throw 'SSIS_CATALOG_ARCHIVE_LIMIT'}
    $entries=@($zip.Entries|Where-Object {[string]::Equals($_.FullName,[string]$source.PackageFileName,[StringComparison]::Ordinal)})
    if($entries.Count -ne 1 -or $entries[0].Length -le 0 -or $entries[0].Length -gt 16777216){throw 'SSIS_CATALOG_PACKAGE_ENTRY_UNAVAILABLE'}
    $stream=$entries[0].Open();$package=[IO.MemoryStream]::new()
    try {
        $buffer=[byte[]]::new(65536)
        while(($read=$stream.Read($buffer,0,$buffer.Length)) -gt 0){if($package.Length+$read -gt 16777216){throw 'SSIS_CATALOG_PACKAGE_LIMIT'};$package.Write($buffer,0,$read)}
        $bytes=$package.ToArray()
    } finally {$package.Dispose();$stream.Dispose()}
} finally {$zip.Dispose();$memory.Dispose()}
$handover=& (Join-Path $PSScriptRoot 'Invoke-SsisQualifiedHandover.ps1') -ProducerAssemblyPath $ProducerAssemblyPath -ExpectedBuildSha256 $ExpectedBuildSha256 -ExpectedSourceCommit $ExpectedSourceCommit -PackageBytes $bytes -Connection $Connection -ValidHours $ValidHours -DotnetPath $DotnetPath -IncludeObjectIdentities -PrepareOnly
$rows=@(foreach($row in $observed.Rows) {
    $nativeGuid=[guid]::Empty;$guidValue=if(-not $row.IsNull('ExecutableGuid') -and [guid]::TryParse([string]$row.ExecutableGuid,[ref]$nativeGuid)){$nativeGuid.ToString('D').ToLowerInvariant()}else{$null}
    [ordered]@{statisticsId=[string]$row.StatisticsId;executionId=[string]$row.ExecutionId;executableId=[string]$row.ExecutableId;executableGuid=$guidValue;
        packageName=$(if($row.IsNull('PackageName')){$null}else{[string]$row.PackageName});packagePath=$(if($row.IsNull('PackagePath')){$null}else{[string]$row.PackagePath});executionPath=$(if($row.IsNull('ExecutionPath')){$null}else{[string]$row.ExecutionPath});
        startTime=$(if($row.IsNull('StartTime')){$null}else{[string]$row.StartTime});endTime=$(if($row.IsNull('EndTime')){$null}else{[string]$row.EndTime});
        durationMs=$(if($row.IsNull('DurationMs')){$null}else{[int]$row.DurationMs});executionResult=$(if($row.IsNull('ExecutionResult')){$null}else{[int]$row.ExecutionResult})}
})
$model=$handover.PackageModelJson|ConvertFrom-Json -Depth 32
$snapshot=[ordered]@{contract='ssis-execution-snapshot';version='1.0.0';method='SSISDB_CURRENT_PROJECT_DIRECT_PATH_V1';
    modelSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::Unicode.GetBytes($handover.PackageModelJson))).ToLowerInvariant();
    packageSha256=$model.source.packageSha256;identityProfile='document-order-v1';
    execution=[ordered]@{sourceBindingSha256=$sourceBindingSha;executionId=[string]$source.ExecutionId;projectId=[string]$source.ProjectId;projectLsn=[string]$source.ProjectLsn;catalogDatabaseGuid=[string]$source.CatalogDatabaseGuid;packageFileName=[string]$source.PackageFileName;executionCreatedUtc=[string]$source.ExecutionCreatedUtc;
        executionStatus=[int]$after.Rows[0].ExecutionStatus;startTime=$(if($after.Rows[0].IsNull('StartTime')){$null}else{[string]$after.Rows[0].StartTime});endTime=$(if($after.Rows[0].IsNull('EndTime')){$null}else{[string]$after.Rows[0].EndTime});
        snapshotStartedUtc=[string]$source.ReadTimeUtc;snapshotCompletedUtc=[string]$after.Rows[0].ReadTimeUtc};identities=($handover.ObjectIdentitiesJson|ConvertFrom-Json -Depth 32);observations=$rows}
$snapshotJson=$snapshot|ConvertTo-Json -Depth 32 -Compress
if([Text.Encoding]::Unicode.GetByteCount($snapshotJson) -gt 16777216){throw 'SSIS_CATALOG_SNAPSHOT_LIMIT'}
Import-Module (Join-Path $PSScriptRoot 'SsisHandoverSupport.psm1') -Scope Local
$registered=Register-SsisHandover -Connection $Connection -ModelJson $handover.PackageModelJson -PackageBytes $handover.PackageBytes -ExecutionSnapshotJson $snapshotJson -ValidHours $ValidHours
[pscustomobject]@{Status='CAPTURED';ExecutionId=$ExecutionId;RuntimeHandoverId=$registered.RuntimeHandoverId;ExecutionSnapshotJson=$snapshotJson;LocalHandoverId=$registered.LocalHandoverId;PackageModelJson=$handover.PackageModelJson;PackageBytes=[byte[]]$handover.PackageBytes}
