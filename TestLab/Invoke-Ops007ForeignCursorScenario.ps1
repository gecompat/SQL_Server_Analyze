[CmdletBinding()]
param([string] $LabRepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'AnalyzeExample.Common.ps1')
$repositoryRoot = Get-AnalyzeRepositoryRoot
$labRoot = Resolve-SqlServerLabRepositoryRoot -LabRepositoryRoot $LabRepositoryRoot
$null = & (Join-Path $labRoot 'Tools/Initialize-SqlServerLabHostTools.ps1') -Name docker
Import-Module (Join-Path $labRoot 'SqlServerLab.psd1') -Force
$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stateRoot = Assert-AnalyzePathUnderRoot `
    -Path (Join-Path $systemTempRoot ('SQL_Server_Analyze/ops007-foreign-' + [guid]::NewGuid().ToString('N'))) `
    -AllowedRoot $systemTempRoot
[IO.Directory]::CreateDirectory($stateRoot) | Out-Null
$saPassword = New-AnalyzeExampleSecret
$credentialPassword = $saPassword.Copy()
$credentialPassword.MakeReadOnly()
$lab = $null; $connection = $null; $cleanupCompleted = $false
try {
    $lab = New-SqlServerLab -Version 2025 -Provider docker -Profile standard `
        -Collation 'Latin1_General_100_CS_AS' -SaPassword $saPassword `
        -StateRoot $stateRoot -LabName 'analyze-ops007-foreign' -NonInteractive
    Start-Sleep -Seconds 60
    $framework = New-AnalyzeFrameworkInstaller -RunDirectory $stateRoot
    foreach ($script in @($framework.Prepare,$framework.Installer)) {
        $null = Invoke-AnalyzeLabScript -ScriptPath $script -RunId $lab.RunId -StateRoot $stateRoot -SaPassword $saPassword
    }
    foreach ($relative in @('Code/Tests/Integration/110_Smoke_Test.sql',
            'Code/Tests/CurrentState/120_OPS007_Current_Cursor_Runtime_Contract.sql')) {
        $rendered = Join-Path $stateRoot ([IO.Path]::GetFileName($relative))
        $content = [IO.File]::ReadAllText((Join-Path $repositoryRoot $relative),[Text.Encoding]::UTF8)
        [IO.File]::WriteAllText($rendered,$content.Replace('[DeineDatenbank]','[LabAnalyze]'),[Text.UTF8Encoding]::new($false))
        $null = Invoke-AnalyzeLabScript -ScriptPath $rendered -RunId $lab.RunId -StateRoot $stateRoot -SaPassword $saPassword
    }
    $endpoint = Get-AnalyzeLabConnection -RunId $lab.RunId -StateRoot $stateRoot
    $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
    $builder['Data Source'] = "tcp:$($endpoint.host),$($endpoint.port)"
    $builder['Initial Catalog'] = 'LabAnalyze'
    $builder['Encrypt'] = $true; $builder['TrustServerCertificate'] = $true
    $builder['Connect Timeout'] = 30
    $credential = [System.Data.SqlClient.SqlCredential]::new('sa',$credentialPassword)
    $connection = [System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString,$credential)
    $connection.Open()
    $command = $connection.CreateCommand(); $command.CommandTimeout = 45
    $command.CommandText = @'
IF OBJECT_ID(N'dbo.ExampleOps007Input') IS NOT NULL
    THROW 54907,N'Die eigene Eingabefixture ist bereits belegt.',1;
EXEC sys.sp_addextendedproperty @name=N'SQLANALYZE.Ops007Disposable',@value=1;
CREATE TABLE dbo.ExampleOps007Input(Id int NOT NULL PRIMARY KEY,Payload char(200) NOT NULL);
INSERT dbo.ExampleOps007Input(Id,Payload)
    SELECT TOP(10000) CONVERT(int,ROW_NUMBER() OVER(ORDER BY a.object_id,b.object_id)),REPLICATE('Synthetic',20)
    FROM sys.all_objects a CROSS JOIN sys.all_objects b;
DECLARE ExampleOps007ForeignCursor CURSOR GLOBAL STATIC FOR
    SELECT Id,Payload FROM dbo.ExampleOps007Input ORDER BY Id;
OPEN ExampleOps007ForeignCursor;
FETCH NEXT FROM ExampleOps007ForeignCursor;
'@
    try { $null = $command.ExecuteNonQuery() } finally { $command.Dispose() }
    $command = $connection.CreateCommand(); $command.CommandTimeout = 30
    $command.CommandText = 'SELECT @@SPID;'
    try { $cursorSessionId = [int]$command.ExecuteScalar() } finally { $command.Dispose() }
    if ($cursorSessionId -le 50) { throw 'Die neue Cursor-Session ist keine Benutzersession.' }
    $fixture = Join-Path $stateRoot 'foreign-cursor.sql'
    $content = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Scenarios/OPS-007/foreign-cursor.sql'),[Text.Encoding]::UTF8)
    $content = $content.Replace('[DeineDatenbank]','[LabAnalyze]').Replace('__OPS007_SESSION_ID__',[string]$cursorSessionId)
    [IO.File]::WriteAllText($fixture,$content,[Text.UTF8Encoding]::new($false))
    $null = Invoke-AnalyzeLabScript -ScriptPath $fixture -RunId $lab.RunId -StateRoot $stateRoot -SaPassword $saPassword
    $command = $connection.CreateCommand(); $command.CommandTimeout = 30
    $command.CommandText = "SELECT CONVERT(nvarchar(32),SERVERPROPERTY('ProductVersion'));"
    try { $productVersion = [string]$command.ExecuteScalar() } finally { $command.Dispose() }
}
finally {
    if ($connection) { $connection.Dispose() }
    $credentialPassword.Dispose()
    if ($lab) {
        try {
            $cleanup = Remove-SqlServerLab -RunId $lab.RunId -StateRoot $stateRoot -Force -Confirm:$false
            $cleanupCompleted = $cleanup.Status -eq 'REMOVED'
        } catch { Write-Warning "OPS-007-Cleanup fehlgeschlagen ($($_.Exception.GetType().Name))." }
        if (-not $cleanupCompleted) {
            Write-Warning "Recovery: Remove-SqlServerLab -RunId '$($lab.RunId)' -StateRoot '$stateRoot' -Force -Confirm:`$false"
        }
    } else { Write-Warning "Eigener Provisionierungs-Recovery-State: '$stateRoot'. Get-SqlServerLab -StateRoot '$stateRoot' prüfen." }
    if ($cleanupCompleted) {
        $verifiedRoot = Assert-AnalyzePathUnderRoot -Path $stateRoot -AllowedRoot $systemTempRoot
        Remove-Item -LiteralPath $verifiedRoot -Recurse -Force
    }
}
if (-not $cleanupCompleted) { throw 'OPS-007-Cleanup nicht vollständig; eigenen Recovery-State erhalten.' }
[PSCustomObject]@{ WorkItem='OPS-007'; Status='PASS'; SqlVersion='2025'; ProductVersion=$productVersion; Cleanup='REMOVED' }
