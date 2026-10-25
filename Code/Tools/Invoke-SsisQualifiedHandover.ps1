[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ProducerAssemblyPath,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedBuildSha256,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedSourceCommit,
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][System.Data.SqlClient.SqlConnection]$Connection,
    [ValidateRange(1,24)][int]$ValidHours=1,
    [string]$DotnetPath='dotnet'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
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
$bytes=Read-BoundedFile $PackagePath 16777216
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
    foreach($item in @('exec','--runtimeconfig',$runtime,$dll,$inputFile)){[void]$info.ArgumentList.Add($item)}
    foreach($key in @($info.Environment.Keys)){if($key -match '^(DOTNET_|CORECLR_|COR_|COMPlus_)'){[void]$info.Environment.Remove($key)}}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info;$processStarted=$process.Start();if(-not $processStarted){throw 'SSIS_HANDOVER_PROCESS_NOT_STARTED'}
    $output=$process.StandardOutput.ReadToEndAsync();$errorOutput=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(60000)){$process.Kill($true);throw 'SSIS_HANDOVER_PRODUCER_TIMEOUT'}
    $model=$output.GetAwaiter().GetResult();[void]$errorOutput.GetAwaiter().GetResult()
    if($process.ExitCode -ne 0 -or [Text.Encoding]::Unicode.GetByteCount($model) -gt 16777216){throw 'SSIS_HANDOVER_PRODUCER_FAILED'}
    $parsed=$model|ConvertFrom-Json -Depth 32
    if($parsed.producer.buildSha256 -cne $hash -or $parsed.producer.sourceCommit -cne $ExpectedSourceCommit.ToLowerInvariant()) {throw 'SSIS_HANDOVER_PRODUCER_IDENTITY_MISMATCH'}
    $id=[guid]::NewGuid();$name='SSIS_HANDOVER_'+$id.ToString()
    $command=$Connection.CreateCommand();$command.CommandTimeout=90
    $command.CommandText=@'
IF @@TRANCOUNT<>0 THROW 57400,N'SSIS_HANDOVER_CALLER_TRANSACTION_NOT_ALLOWED',1;
DECLARE @Status varchar(40),@Validated nvarchar(max);
EXEC [monitor].[USP_SsisPackageModelAnalysis] @PackageModelJson=@Model,@PackageBytes=@Bytes,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Validated OUTPUT,@StatusCodeOut=@Status OUTPUT;
IF @Status<>'AVAILABLE_LIMITED' THROW 57400,N'SSIS_HANDOVER_MODEL_REJECTED',1;
DECLARE @Issued datetime2(3)=SYSUTCDATETIME(),@Receipt nvarchar(3000);
SET @Receipt=(SELECT 'ssis-local-handover' AS [contract],'1.0.0' AS [version],'QUALIFIED_HOST_SNAPSHOT' AS [method],
    CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Model)),2) AS [modelSha256],
    JSON_VALUE(@Model,'$.source.packageSha256') AS [packageSha256],DATALENGTH(@Bytes) AS [byteLength],
    JSON_VALUE(@Model,'$.producer.buildSha256') AS [buildSha256],JSON_VALUE(@Model,'$.producer.sourceCommit') AS [sourceCommit],
    CONVERT(varchar(24),@Issued,127)+'Z' AS [issuedUtc],CONVERT(varchar(24),DATEADD(hour,@Hours,@Issued),127)+'Z' AS [expiresUtc]
    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
EXEC [sys].[sp_addextendedproperty] @name=@Name,@value=@Receipt,@level0type=N'SCHEMA',@level0name=N'monitor',@level1type=N'PROCEDURE',@level1name=N'USP_SsisPackageModelAnalysis';
'@
    [void]$command.Parameters.Add('@Model',[Data.SqlDbType]::NVarChar,-1);$command.Parameters['@Model'].Value=$model
    [void]$command.Parameters.Add('@Bytes',[Data.SqlDbType]::VarBinary,-1);$command.Parameters['@Bytes'].Value=[byte[]]$bytes
    [void]$command.Parameters.Add('@Name',[Data.SqlDbType]::NVarChar,128);$command.Parameters['@Name'].Value=$name
    [void]$command.Parameters.Add('@Hours',[Data.SqlDbType]::Int);$command.Parameters['@Hours'].Value=$ValidHours
    try {[void]$command.ExecuteNonQuery()} finally {$command.Dispose()}
    [pscustomobject]@{LocalHandoverId=$id;PackageModelJson=$model;PackageBytes=[byte[]]$bytes;ProducerBuildSha256=$hash}
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
