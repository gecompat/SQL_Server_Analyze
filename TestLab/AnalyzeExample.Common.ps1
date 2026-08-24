Set-StrictMode -Version Latest

function Get-AnalyzeRepositoryRoot {
    [CmdletBinding()]
    param()

    return [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

function Assert-AnalyzePathUnderRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $AllowedRoot
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($AllowedRoot).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ) + [IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($fullRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Pfad liegt außerhalb des erlaubten Stammverzeichnisses: $fullPath"
    }
    return $fullPath
}

function Get-AnalyzeExampleCatalog {
    [CmdletBinding()]
    param()

    $catalogPath = Join-Path $PSScriptRoot 'Catalog/examples.json'
    return Get-Content -LiteralPath $catalogPath -Raw -Encoding utf8 |
        ConvertFrom-Json -Depth 20
}

function Resolve-AnalyzeExample {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Example,

        [Parameter(Mandatory)]
        [string] $Version,

        [Parameter(Mandatory)]
        [string] $Provider
    )

    $catalog = Get-AnalyzeExampleCatalog
    $matches = @($catalog.examples | Where-Object { $_.id -eq $Example })
    if ($matches.Count -ne 1) {
        throw "Unbekanntes oder mehrdeutiges Analyze-Beispiel: $Example"
    }
    $definition = $matches[0]
    if ($Version -notin @($definition.sqlVersions)) {
        throw "Beispiel $Example unterstützt SQL Server $Version nicht."
    }
    if ($Provider -notin @($definition.providers)) {
        throw "Beispiel $Example unterstützt Provider $Provider nicht."
    }
    return $definition
}

function Resolve-SqlServerLabRepositoryRoot {
    [CmdletBinding()]
    param(
        [string] $LabRepositoryRoot
    )

    if ([string]::IsNullOrWhiteSpace($LabRepositoryRoot)) {
        $analyzeRoot = Get-AnalyzeRepositoryRoot
        $LabRepositoryRoot = Join-Path (Split-Path $analyzeRoot -Parent) 'SQL_Server_Lab'
    }
    $resolved = Assert-AnalyzePathUnderRoot `
        -Path $LabRepositoryRoot `
        -AllowedRoot 'C:\rep\pu'
    $manifest = Join-Path $resolved 'SqlServerLab.psd1'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "SQL_Server_Lab-Modul nicht gefunden: $manifest"
    }
    return $resolved
}

function New-AnalyzeExampleSecret {
    [CmdletBinding()]
    param()

    $random = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(30))
    return ConvertTo-SecureString "A1!a$random" -AsPlainText -Force
}

function ConvertTo-AnalyzeSqlLiteralValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Value
    )

    if ($Value -notmatch '^[A-Za-z0-9_.-]{1,128}$') {
        throw 'SQLCMD-Ersatzwert liegt außerhalb des begrenzten Beispielvertrags.'
    }
    return $Value
}

function New-RenderedAnalyzeScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $SourcePath,

        [Parameter(Mandatory)]
        [string] $DestinationPath,

        [Parameter(Mandatory)]
        [hashtable] $Variables
    )

    $content = [IO.File]::ReadAllText($SourcePath, [Text.Encoding]::UTF8)
    $content = [Text.RegularExpressions.Regex]::Replace(
        $content,
        '(?m)^\s*:setvar\s+[A-Za-z][A-Za-z0-9_]*\s+"[^"]*"\s*\r?\n',
        ''
    )
    foreach ($name in $Variables.Keys) {
        if ([string]$name -notmatch '^[A-Za-z][A-Za-z0-9_]{0,63}$') {
            throw 'Ungültiger SQLCMD-Variablenname im Beispielvertrag.'
        }
        $safeValue = ConvertTo-AnalyzeSqlLiteralValue -Value ([string]$Variables[$name])
        $content = $content.Replace('$(' + $name + ')', $safeValue)
    }
    if ($content -match '\$\([A-Za-z][A-Za-z0-9_]*\)') {
        throw "Nicht aufgelöste SQLCMD-Variable in $SourcePath"
    }
    [IO.Directory]::CreateDirectory((Split-Path $DestinationPath -Parent)) | Out-Null
    [IO.File]::WriteAllText(
        $DestinationPath,
        $content,
        [Text.UTF8Encoding]::new($false)
    )
    return $DestinationPath
}

function New-AnalyzeExampleRuntimeScripts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Definition,

        [Parameter(Mandatory)]
        [string] $RunDirectory,

        [Parameter(Mandatory)]
        [string] $LabRunId
    )

    $repositoryRoot = Get-AnalyzeRepositoryRoot
    $sharedRoot = Join-Path $repositoryRoot 'Lab/Scenarios/Performance/_Shared'
    $common = @{
        ScenarioId = [string]$Definition.scenarioId
        LabRunId = $LabRunId
    }
    $setup = New-RenderedAnalyzeScript `
        -SourcePath (Join-Path $sharedRoot 'Setup.sql') `
        -DestinationPath (Join-Path $RunDirectory 'Setup.sql') `
        -Variables $common
    $cleanup = New-RenderedAnalyzeScript `
        -SourcePath (Join-Path $sharedRoot 'Cleanup.sql') `
        -DestinationPath (Join-Path $RunDirectory 'Cleanup.sql') `
        -Variables $common
    $observeVariables = @{
        ScenarioId = [string]$Definition.scenarioId
        LabRunId = $LabRunId
        PrimaryAnalyzer = [string]$Definition.primaryAnalyzer
        FindingCode = [string]$Definition.findingCode
    }
    $observe = New-RenderedAnalyzeScript `
        -SourcePath (Join-Path $sharedRoot 'Observe.sql') `
        -DestinationPath (Join-Path $RunDirectory 'Analyze-And-Validate.sql') `
        -Variables $observeVariables
    $probe = $null
    if ($Definition.id -eq 'BLOCKING-001') {
        $probe = New-RenderedAnalyzeScript `
            -SourcePath (Join-Path $repositoryRoot 'TestLab/Examples/Blocking/Probe.sql') `
            -DestinationPath (Join-Path $RunDirectory 'Probe.sql') `
            -Variables $common
    }

    $workerSources = @()
    if ($Definition.PSObject.Properties.Name -contains 'workerScripts') {
        $workerSources = @($Definition.workerScripts | ForEach-Object {
            Assert-AnalyzePathUnderRoot `
                -Path (Join-Path $repositoryRoot ([string]$_)) `
                -AllowedRoot (Join-Path $repositoryRoot 'TestLab/Examples')
        })
    }
    else {
        if ([int]$Definition.workerCount -gt 0) {
            $workerSources = @(
                1..([int]$Definition.workerCount) | ForEach-Object {
                    Join-Path $sharedRoot 'Worker.sql'
                }
            )
        }
    }
    if ($workerSources.Count -ne [int]$Definition.workerCount) {
        throw "Workeranzahl und Workerdateien sind für $($Definition.id) inkonsistent."
    }

    $workers = @()
    for ($workerId = 1; $workerId -le $workerSources.Count; $workerId++) {
        $workerVariables = @{
            ScenarioId = [string]$Definition.scenarioId
            LabRunId = $LabRunId
            WorkerId = [string]$workerId
        }
        $workers += New-RenderedAnalyzeScript `
            -SourcePath $workerSources[$workerId - 1] `
            -DestinationPath (Join-Path $RunDirectory "Session-$workerId.sql") `
            -Variables $workerVariables
    }

    return [PSCustomObject]@{
        Setup = $setup
        Workers = $workers
        Probe = $probe
        Analyze = $observe
        Cleanup = $cleanup
    }
}

function New-AnalyzeFrameworkInstaller {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RunDirectory
    )

    $repositoryRoot = Get-AnalyzeRepositoryRoot
    $preparePath = Join-Path $RunDirectory 'Prepare-Framework.sql'
    $prepareSql = @'
SET NOCOUNT ON;
IF DB_ID(N'LabAnalyze') IS NULL
BEGIN
    CREATE DATABASE [LabAnalyze]
    COLLATE SQL_Latin1_General_CP1_CS_AS;
END;
'@
    [IO.File]::WriteAllText(
        $preparePath,
        $prepareSql,
        [Text.UTF8Encoding]::new($false)
    )

    $installerPath = Join-Path $RunDirectory 'Install-All.generated.sql'
    & (Join-Path $repositoryRoot 'Code/Install/Build-StandaloneInstaller.ps1') `
        -RepositoryRoot $repositoryRoot `
        -OutputPath $installerPath
    $content = [IO.File]::ReadAllText($installerPath, [Text.Encoding]::UTF8)
    $content = $content.Replace('[DeineDatenbank]', '[LabAnalyze]')
    [IO.File]::WriteAllText(
        $installerPath,
        $content,
        [Text.UTF8Encoding]::new($false)
    )
    return [PSCustomObject]@{
        Prepare = $preparePath
        Installer = $installerPath
    }
}

function Invoke-AnalyzeLabScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $RunId,

        [Parameter(Mandatory)]
        [string] $StateRoot,

        [Parameter(Mandatory)]
        [SecureString] $SaPassword,

        [string] $Database = 'master'
    )

    $parameters = @{
        ScriptPath = $ScriptPath
        RunId = $RunId
        StateRoot = $StateRoot
        InstanceId = 'primary'
        SaPassword = $SaPassword
        Database = $Database
    }
    $parameters.KeepConnection = $true
    $result = Invoke-SqlServerLabScript @parameters
    if (-not $result.Success) {
        throw "Lab-Skript fehlgeschlagen: $([IO.Path]::GetFileName($ScriptPath))"
    }
    return $result
}

function Get-AnalyzeLabConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RunId,

        [Parameter(Mandatory)]
        [string] $StateRoot
    )

    $connectionPath = Join-Path $StateRoot "runs/$RunId/connection-info.json"
    if (-not (Test-Path -LiteralPath $connectionPath -PathType Leaf)) {
        throw "Lab-Verbindungsvertrag fehlt für Run $RunId."
    }
    $connection = Get-Content -LiteralPath $connectionPath -Raw -Encoding utf8 |
        ConvertFrom-Json -Depth 20
    $instance = @($connection.instances | Where-Object id -eq 'primary')
    if ($instance.Count -ne 1) {
        throw "Primary-Verbindung ist für Run $RunId nicht eindeutig."
    }
    return $instance[0]
}

function Start-AnalyzeSqlWorkerTask {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [Parameter(Mandatory)]
        [string] $HostName,

        [Parameter(Mandatory)]
        [int] $Port,

        [Parameter(Mandatory)]
        [SecureString] $SaPassword,

        [Parameter(Mandatory)]
        [string] $ScenarioId,

        [Parameter(Mandatory)]
        [string] $LabRunId
    )

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SaPassword)
    try {
        $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        $builder = [System.Data.SqlClient.SqlConnectionStringBuilder]::new()
        $builder['Data Source'] = "$HostName,$Port"
        $builder['Initial Catalog'] = 'master'
        $builder['User ID'] = 'sa'
        $builder['Password'] = $plainPassword
        $builder['Encrypt'] = $true
        $builder['TrustServerCertificate'] = $true
        $builder['Connect Timeout'] = 30
        $builder['Application Name'] = 'SQL_Server_Analyze TestLab Worker'
        $connection = [System.Data.SqlClient.SqlConnection]::new(
            $builder.ConnectionString
        )
        $connection.Open()
        $contextCommand = $connection.CreateCommand()
        $contextCommand.CommandText = @'
DECLARE @ContextToken binary(128) = CONVERT
(
      binary(128)
    , HASHBYTES('SHA2_256', CONCAT(@LabRunId, '|', @ScenarioId))
);
SET CONTEXT_INFO @ContextToken;
'@
        $null = $contextCommand.Parameters.Add(
            '@LabRunId',
            [System.Data.SqlDbType]::VarChar,
            40
        )
        $null = $contextCommand.Parameters.Add(
            '@ScenarioId',
            [System.Data.SqlDbType]::VarChar,
            40
        )
        $contextCommand.Parameters['@LabRunId'].Value = $LabRunId
        $contextCommand.Parameters['@ScenarioId'].Value = $ScenarioId
        $null = $contextCommand.ExecuteNonQuery()
        $contextCommand.Dispose()
        $command = $connection.CreateCommand()
        $command.CommandText = [IO.File]::ReadAllText(
            $ScriptPath,
            [Text.Encoding]::UTF8
        )
        $command.CommandTimeout = 90
        $task = $command.ExecuteNonQueryAsync()
        return [PSCustomObject]@{
            Connection = $connection
            Command = $command
            Task = $task
            ScriptPath = $ScriptPath
        }
    }
    finally {
        $plainPassword = $null
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}
