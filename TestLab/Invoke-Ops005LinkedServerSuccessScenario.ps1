[CmdletBinding()]
param([string] $LabRepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')
$repositoryRoot = Get-AnalyzeRepositoryRoot
$labRoot = Resolve-SqlServerLabRepositoryRoot -LabRepositoryRoot $LabRepositoryRoot
$null = & (Join-Path $labRoot 'Tools/Initialize-SqlServerLabHostTools.ps1') -Name docker
Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force

function Open-Ops005Connection {
    param($Lab, [string] $StateRoot, [SecureString] $Secret)
    $endpoint = Get-AnalyzeLabConnection -RunId $Lab.RunId -StateRoot $StateRoot
    if ($endpoint.host -notin @('127.0.0.1', 'localhost')) {
        throw 'OPS-005 akzeptiert ausschließlich den lokalen Endpunkt seines neuen Lab-Runs.'
    }
    $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
    $builder['Data Source'] = "tcp:$($endpoint.host),$($endpoint.port)"
    $builder['Initial Catalog'] = 'master'
    $builder['User ID'] = 'sa'
    $builder['Encrypt'] = $true
    $builder['TrustServerCertificate'] = $true
    $builder['Connect Timeout'] = 30
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
    try {
        $builder['Password'] = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $connection = [System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
        $connection.Open()
        return $connection
    }
    finally {
        $builder.Clear()
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stateRoot = Assert-AnalyzePathUnderRoot `
    -Path (Join-Path $systemTempRoot ("SQL_Server_Analyze/ops005-success-{0}" -f [guid]::NewGuid().ToString('N'))) `
    -AllowedRoot $systemTempRoot
[IO.Directory]::CreateDirectory($stateRoot) | Out-Null
$labs = [Collections.Generic.List[object]]::new()
$sourceSecret = New-AnalyzeExampleSecret
$targetSecret = New-AnalyzeExampleSecret
$remoteSecret = New-AnalyzeExampleSecret
$sourceConnection = $null
$targetConnection = $null
$cleanupSucceeded = $false
try {
    $source = New-SqlServerLab -Version 2025 -Provider docker -Profile standard `
        -Collation 'Latin1_General_100_CS_AS' -SaPassword $sourceSecret `
        -StateRoot $stateRoot -LabName 'analyze-ops005-source' -NonInteractive
    $labs.Add($source)
    $target = New-SqlServerLab -Version 2025 -Provider docker -Profile standard `
        -Collation 'Latin1_General_100_CS_AS' -SaPassword $targetSecret `
        -StateRoot $stateRoot -LabName 'analyze-ops005-target' -NonInteractive
    $labs.Add($target)
    Start-Sleep -Seconds 60
    $runDirectory = Join-Path $stateRoot 'scripts'
    [IO.Directory]::CreateDirectory($runDirectory) | Out-Null
    $framework = New-AnalyzeFrameworkInstaller -RunDirectory $runDirectory
    foreach ($script in @($framework.Prepare, $framework.Installer)) {
        $null = Invoke-AnalyzeLabScript -ScriptPath $script -RunId $source.RunId -StateRoot $stateRoot -SaPassword $sourceSecret
    }
    foreach ($relativePath in @('Code/Tests/Integration/110_Smoke_Test.sql',
            'Code/Tests/ServerHealth/120_OPS005_Linked_Server_Runtime_Contract.sql',
            'Code/Tests/ServerHealth/121_OPS006_Database_Portability_Runtime_Contract.sql')) {
        $script = Join-Path $runDirectory ([IO.Path]::GetFileName($relativePath))
        $content = [IO.File]::ReadAllText((Join-Path $repositoryRoot $relativePath), [Text.Encoding]::UTF8)
        [IO.File]::WriteAllText($script, $content.Replace('[DeineDatenbank]', '[LabAnalyze]'), [Text.UTF8Encoding]::new($false))
        $null = Invoke-AnalyzeLabScript -ScriptPath $script -RunId $source.RunId -StateRoot $stateRoot -SaPassword $sourceSecret
    }
    $sourceConnection = Open-Ops005Connection -Lab $source -StateRoot $stateRoot -Secret $sourceSecret
    $targetConnection = Open-Ops005Connection -Lab $target -StateRoot $stateRoot -Secret $targetSecret
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($remoteSecret)
    try {
        $targetCommand = $targetConnection.CreateCommand()
        $targetCommand.CommandTimeout = 45
        $targetCommand.CommandText = @'
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name=N'ExampleOps005RemoteLogin')
    THROW 54875,N'Der Remote-Fixture-Login ist bereits belegt.',1;
DECLARE @Sql nvarchar(max)=N'CREATE LOGIN [ExampleOps005RemoteLogin] WITH PASSWORD=N'''+REPLACE(@Secret,N'''',N'''''')+N''';';
EXEC sys.sp_executesql @Sql;
'@
        $null = $targetCommand.Parameters.Add('@Secret', [System.Data.SqlDbType]::NVarChar, 128)
        $targetCommand.Parameters['@Secret'].Value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        try { $null = $targetCommand.ExecuteNonQuery() } finally { $targetCommand.Dispose() }
        $targetEndpoint = Get-AnalyzeLabConnection -RunId $target.RunId -StateRoot $stateRoot
        # Docker Desktop leitet ausschließlich auf den gebundenen Port des neuen Ziel-Runs.
        $remoteEndpoint = 'host.docker.internal,' + [int]$targetEndpoint.port
        $command = $sourceConnection.CreateCommand()
        $command.CommandTimeout = 45
        $command.CommandText = @'
IF EXISTS (SELECT 1 FROM sys.servers WHERE is_linked=1)
    THROW 54876,N'Der Quell-Run enthält unerwartete Linked Server.',1;
EXEC master.dbo.sp_addlinkedserver @server=N'ExampleOps005Success',@srvproduct=N'',
    @provider=N'MSOLEDBSQL',@datasrc=@Endpoint,@provstr=N'encrypt=mandatory;trustservercertificate=yes';
EXEC master.dbo.sp_droplinkedsrvlogin @rmtsrvname=N'ExampleOps005Success',@locallogin=NULL;
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'ExampleOps005Success',@useself=N'false',
    @locallogin=N'sa',@rmtuser=N'ExampleOps005RemoteLogin',@rmtpassword=@Secret;
EXEC master.dbo.sp_serveroption @server=N'ExampleOps005Success',@optname=N'connect timeout',@optvalue=N'5';
'@
        $null = $command.Parameters.Add('@Endpoint', [System.Data.SqlDbType]::NVarChar, 256)
        $command.Parameters['@Endpoint'].Value = $remoteEndpoint
        $null = $command.Parameters.Add('@Secret', [System.Data.SqlDbType]::NVarChar, 128)
        $command.Parameters['@Secret'].Value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        try { $null = $command.ExecuteNonQuery() } finally { $command.Dispose() }
    }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
    $successScript = Join-Path $runDirectory 'connectivity-success.sql'
    $content = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Adapters/OPS-005/sql/connectivity-success.sql'), [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($successScript, $content.Replace('[DeineDatenbank]', '[LabAnalyze]'), [Text.UTF8Encoding]::new($false))
    $null = Invoke-AnalyzeLabScript -ScriptPath $successScript -RunId $source.RunId -StateRoot $stateRoot -SaPassword $sourceSecret
    $command = $sourceConnection.CreateCommand()
    $command.CommandTimeout = 30
    $command.CommandText = "SELECT CONVERT(nvarchar(32),SERVERPROPERTY('ProductVersion'));"
    try { $productVersion = [string]$command.ExecuteScalar() } finally { $command.Dispose() }
}
finally {
    if ($sourceConnection) { $sourceConnection.Dispose() }
    if ($targetConnection) { $targetConnection.Dispose() }
    $cleanupSucceeded = $labs.Count -eq 2
    if ($labs.Count -ne 2) {
        Write-Warning "OPS-005-Provisionierung unvollständig. Eigener Recovery-State: '$stateRoot'. Verbliebene Runs mit Get-SqlServerLab -StateRoot '$stateRoot' prüfen und gezielt mit Remove-SqlServerLab entfernen."
    }
    for ($index = $labs.Count - 1; $index -ge 0; $index--) {
        try {
            $cleanup = Remove-SqlServerLab -RunId $labs[$index].RunId -StateRoot $stateRoot -Force -Confirm:$false
            if ($cleanup.Status -ne 'REMOVED') {
                $cleanupSucceeded = $false
                Write-Warning "OPS-005-Cleanup nicht abgeschlossen (Status: $($cleanup.Status)). Recovery: Remove-SqlServerLab -RunId '$($labs[$index].RunId)' -StateRoot '$stateRoot' -Force -Confirm:`$false"
            }
        }
        catch {
            $cleanupSucceeded = $false
            # Fehlertexte können Verbindungsdaten enthalten; nur den Fehlertyp ausgeben.
            Write-Warning "OPS-005-Cleanup fehlgeschlagen ($($_.Exception.GetType().Name)). Recovery: Remove-SqlServerLab -RunId '$($labs[$index].RunId)' -StateRoot '$stateRoot' -Force -Confirm:`$false"
        }
    }
    if ($cleanupSucceeded) {
        $verifiedRoot = Assert-AnalyzePathUnderRoot -Path $stateRoot -AllowedRoot $systemTempRoot
        Remove-Item -LiteralPath $verifiedRoot -Recurse -Force -ErrorAction Stop
    }
}
if (-not $cleanupSucceeded) { throw 'OPS-005-Cleanup nicht vollständig; temporären Recovery-State erhalten.' }
[PSCustomObject]@{
    WorkItem = 'OPS-005'; Status = 'PASS'; SqlVersion = '2025'; ProductVersion = $productVersion
    Provider = 'docker'; LinkedServerProvider = 'MSOLEDBSQL'; Cleanup = 'REMOVED'
}
