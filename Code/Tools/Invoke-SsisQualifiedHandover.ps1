[CmdletBinding(DefaultParameterSetName='Path')]
param(
    [Parameter(Mandatory)][string]$ProducerAssemblyPath,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedBuildSha256,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory,ParameterSetName='Path')][string]$PackagePath,
    [Parameter(Mandatory,ParameterSetName='Bytes')][byte[]]$PackageBytes,
    [Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Connection,
    [ValidateRange(1,24)][int]$ValidHours=1,
    [string]$DotnetPath='dotnet',
    [ValidateRange(1,60)][int]$ProducerTimeoutSeconds=60,
    [switch]$IncludeObjectIdentities,
    [switch]$IncludeIterationCorrelation,
    [switch]$IncludeExecutionScopes,
    [switch]$IncludePipelineCorrelation,
    [switch]$PrepareOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($IncludePipelineCorrelation -and -not $IncludeExecutionScopes){throw 'SSIS_PIPELINE_SCOPES_REQUIRED'}
if(($IncludeIterationCorrelation -or $IncludeExecutionScopes) -and -not $IncludeObjectIdentities){throw 'SSIS_ITERATION_IDENTITIES_REQUIRED'}
# Vertrauenswurzel: qualifizierter Build, Runtime, lokaler Account und ALTER-Recht
# auf der Zielprocedure. Der Adapter liest keine Paket-Connection-Strings.
if($Connection.State -ne 'Open' -or $Connection.Database -eq 'master' -or $Connection.Database -eq 'tempdb') {throw 'SSIS_HANDOVER_EXPLICIT_OPEN_DATABASE_REQUIRED'}
$command=$Connection.CreateCommand()
$command.CommandText="SELECT HAS_PERMS_BY_NAME(N'monitor.USP_SsisPackageModelAnalysis',N'OBJECT',N'ALTER');"
try {if($command.ExecuteScalar() -ne 1){throw 'SSIS_HANDOVER_ALTER_AUTHORITY_REQUIRED'}} finally {$command.Dispose()}
function Read-BoundedFile([string]$Path,[int]$MaxBytes) {
    $stream=[IO.FileStream]::new((Resolve-Path -LiteralPath $Path),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try {
        if($stream.Length -le 0 -or $stream.Length -gt $MaxBytes){throw 'SSIS_HANDOVER_FILE_LIMIT'}
        $memory=[IO.MemoryStream]::new()
        try {
            $buffer=[byte[]]::new(65536)
            while(($read=$stream.Read($buffer,0,$buffer.Length)) -gt 0) {
                if($memory.Length+$read -gt $MaxBytes){throw 'SSIS_HANDOVER_FILE_LIMIT'}
                $memory.Write($buffer,0,$read)
            }
            return ,$memory.ToArray()
        } finally {$memory.Dispose()}
    } finally {$stream.Dispose()}
}
$assembly=Read-BoundedFile $ProducerAssemblyPath 16777216
$bytes=if($PSCmdlet.ParameterSetName -eq 'Bytes') {
    if($PackageBytes.Length -eq 0 -or $PackageBytes.Length -gt 16777216){throw 'SSIS_HANDOVER_FILE_LIMIT'}
    [byte[]]$PackageBytes.Clone()
} else {Read-BoundedFile $PackagePath 16777216}
$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($assembly)).ToLowerInvariant()
if($hash -cne $ExpectedBuildSha256.ToLowerInvariant()){throw 'SSIS_HANDOVER_BUILD_MISMATCH'}
$directory=Join-Path ([IO.Path]::GetTempPath()) ('ssis-qualified-handover-'+[guid]::NewGuid().ToString('N'))
if(Test-Path -LiteralPath $directory){throw 'SSIS_HANDOVER_TEMP_COLLISION'}
if($IsWindows) {
    $security=[Security.AccessControl.DirectorySecurity]::new()
    $security.SetAccessRuleProtection($true,$false)
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule=[Security.AccessControl.FileSystemAccessRule]::new($identity,[Security.AccessControl.FileSystemRights]::FullControl,[Security.AccessControl.InheritanceFlags]'ContainerInherit,ObjectInherit',[Security.AccessControl.PropagationFlags]::None,[Security.AccessControl.AccessControlType]::Allow)
    $security.AddAccessRule($rule)
    [IO.FileSystemAclExtensions]::Create([IO.DirectoryInfo]::new($directory),$security)
} else {
    [void][IO.Directory]::CreateDirectory($directory,[IO.UnixFileMode]'UserRead,UserWrite,UserExecute')
    if([IO.File]::GetUnixFileMode($directory) -ne [IO.UnixFileMode]'UserRead,UserWrite,UserExecute'){throw 'SSIS_HANDOVER_PRIVATE_TEMP_REQUIRED'}
}
$process=$null;$processStarted=$false
try {
    $dll=Join-Path $directory 'Toolbelt.Ssis.Export.dll';$inputFile=Join-Path $directory 'package.dtsx';$runtime=Join-Path $directory 'runtimeconfig.json'
    [IO.File]::WriteAllBytes($dll,$assembly);[IO.File]::WriteAllBytes($inputFile,$bytes)
    [IO.File]::WriteAllText($runtime,'{"runtimeOptions":{"tfm":"net10.0","framework":{"name":"Microsoft.NETCore.App","version":"10.0.0"},"rollForward":"LatestPatch"}}',[Text.UTF8Encoding]::new($false))
    $info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=$DotnetPath;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;$info.StandardOutputEncoding=[Text.UTF8Encoding]::new($false,$true)
    foreach($item in @('exec','--runtimeconfig',$runtime,$dll)){[void]$info.ArgumentList.Add($item)}
    if($IncludeObjectIdentities){[void]$info.ArgumentList.Add($(if($IncludePipelineCorrelation){'--pipeline-bundle'}elseif($IncludeExecutionScopes){'--scope-bundle'}elseif($IncludeIterationCorrelation){'--iteration-bundle'}else{'--bundle'}))}
    [void]$info.ArgumentList.Add($inputFile)
    foreach($key in @($info.Environment.Keys)){if($key -match '^(DOTNET_|CORECLR_|COR_|COMPlus_)'){[void]$info.Environment.Remove($key)}}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info;$processStarted=$process.Start();if(-not $processStarted){throw 'SSIS_HANDOVER_PROCESS_NOT_STARTED'}
    $output=$process.StandardOutput.ReadToEndAsync();$errorOutput=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit($ProducerTimeoutSeconds*1000)){$process.Kill($true);throw 'SSIS_HANDOVER_PRODUCER_TIMEOUT'}
    $model=$output.GetAwaiter().GetResult();[void]$errorOutput.GetAwaiter().GetResult()
    if($process.ExitCode -ne 0 -or [Text.Encoding]::Unicode.GetByteCount($model) -gt 16777216){throw 'SSIS_HANDOVER_PRODUCER_FAILED'}
    $identities=$null;$pipelineIdentities=$null
    if($IncludeObjectIdentities) {
        $bundle=[Text.Json.JsonDocument]::Parse($model)
        try {
            if($bundle.RootElement.GetProperty('contract').GetString() -cne 'ssis-export-bundle' -or $bundle.RootElement.GetProperty('version').GetString() -cne '1.0.0'){throw 'SSIS_HANDOVER_BUNDLE_UNSUPPORTED'}
            $model=$bundle.RootElement.GetProperty('model').GetRawText()
            $identities=$bundle.RootElement.GetProperty('identities').GetRawText()
            if($IncludePipelineCorrelation){$pipelineIdentities=$bundle.RootElement.GetProperty('pipelineIdentities').GetRawText()}
        } finally {$bundle.Dispose()}
    }
    $parsed=$model|ConvertFrom-Json -Depth 32
    if($parsed.producer.buildSha256 -cne $hash -or $parsed.producer.sourceCommit -cne $ExpectedSourceCommit.ToLowerInvariant()) {throw 'SSIS_HANDOVER_PRODUCER_IDENTITY_MISMATCH'}
    $id=$null
    if(-not $PrepareOnly) {
        Import-Module (Join-Path $PSScriptRoot 'SsisHandoverSupport.psm1') -Scope Local
        $registration=Register-SsisHandover -Connection $Connection -ModelJson $model -PackageBytes $bytes -ValidHours $ValidHours
        $id=$registration.LocalHandoverId
    }
    $result=[pscustomobject]@{LocalHandoverId=$id;PackageModelJson=$model;PackageBytes=[byte[]]$bytes;ProducerBuildSha256=$hash;ObjectIdentitiesJson=$identities}
    if($IncludePipelineCorrelation){$result|Add-Member -NotePropertyName PipelineIdentitiesJson -NotePropertyValue $pipelineIdentities}
    $result
} finally {
    try {
        if($null -ne $process){try {if($processStarted -and -not $process.HasExited){$process.Kill($true)}} finally {$process.Dispose()}}
    } finally {
        # Ausschließlich der oben erzeugte absolute Tempordner wird entfernt.
        $resolved=[IO.Path]::GetFullPath($directory)
        if([IO.Path]::GetDirectoryName($resolved) -ne [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)){throw 'SSIS_HANDOVER_CLEANUP_SCOPE_INVALID'}
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
