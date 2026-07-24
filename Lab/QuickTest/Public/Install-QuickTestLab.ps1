function Install-QuickTestLab {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DOCKER', 'PODMAN')]
        [string] $Runtime,

        [Parameter(Mandatory)]
        [int[]] $SqlVersions,

        [Parameter()]
        [hashtable] $Ports = @{},

        [Parameter(Mandatory)]
        [securestring] $AdminSecret,

        [Parameter()]
        [ValidatePattern('^(sa|[A-Za-z][A-Za-z0-9_]{2,31})$')]
        [string] $AdminLogin = 'ExampleSqlAdmin',

        [Parameter()]
        [ValidateSet('SMALL', 'MEDIUM', 'LARGE')]
        [string] $ResourceProfile = 'SMALL',

        [Parameter()]
        [ValidateSet('PERSISTENT', 'TEMPORARY')]
        [string] $PersistenceMode = 'TEMPORARY',

        [Parameter()]
        [ValidatePattern('^[a-z][a-z0-9-]{2,31}$')]
        [string] $ScopeName = 'sql-analyze-quicktest',

        [Parameter()]
        [switch] $InstallFramework,

        [Parameter()]
        [switch] $PersistGeneratedSecret,

        [Parameter(Mandatory)]
        [switch] $AcceptEula,

        [Parameter()]
        [string] $StateRoot = (Join-Path $script:QuickTestLabRoot '.state/quick-test'),

        [Parameter()]
        [string] $DataRoot = (Join-Path $script:QuickTestLabRoot '.artifacts/quick-test'),

        [Parameter()]
        [string] $SecretRoot = (Join-Path $script:QuickTestLabRoot '.secrets/quick-test'),

        [Parameter()]
        [switch] $SkipImageAvailabilityCheck
    )

    if (-not $AcceptEula) {
        throw 'Explicit SQL Server EULA acceptance is required.'
    }
    if (-not (Test-QuickTestPassword -SecureValue $AdminSecret)) {
        throw 'The SQL Server secret does not satisfy the quick-test complexity contract.'
    }

    $versions = @($SqlVersions | Sort-Object -Unique)
    $scopeStateDirectory = Join-Path $StateRoot $ScopeName
    $statePath = Join-Path $scopeStateDirectory 'state.json'
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        return Get-QuickTestLabStatus -ScopeName $ScopeName -StateRoot $StateRoot
    }

    $scopeDataDirectory = Join-Path $DataRoot $ScopeName
    $scopeSecretDirectory = Join-Path $SecretRoot $ScopeName
    $preflight = Invoke-QuickTestPreflight `
        -Runtime $Runtime `
        -SqlVersions $versions `
        -Ports $Ports `
        -ResourceProfile $ResourceProfile `
        -AdminLogin $AdminLogin `
        -ScopeName $ScopeName `
        -DataRoot $scopeDataDirectory `
        -SkipImageAvailabilityCheck:$SkipImageAvailabilityCheck
    if ($preflight.Status -ne 'READY') {
        return $preflight
    }
    if (-not $PSCmdlet.ShouldProcess(
            "quick-test scope $ScopeName",
            'Install Docker or Podman SQL Server test instances'
        )) {
        return [pscustomobject] @{
            Status = 'WHATIF'
            ScopeName = $ScopeName
            SqlVersions = $versions
        }
    }

    $runtimeInfo = Resolve-QuickTestRuntime -Runtime $Runtime
    $profile = Get-QuickTestResourceProfile -Name $ResourceProfile
    $resolvedPorts = Resolve-QuickTestPorts -SqlVersions $versions -Ports $Ports
    $runId = New-QuickTestRunId
    $projectName = $ScopeName
    $runtimeDirectory = Join-Path $scopeStateDirectory 'runtime'
    [IO.Directory]::CreateDirectory($runtimeDirectory) | Out-Null
    [IO.Directory]::CreateDirectory($scopeDataDirectory) | Out-Null
    foreach ($directory in ($scopeStateDirectory, $scopeDataDirectory)) {
        [IO.File]::WriteAllText(
            (Join-Path $directory '.quicktest-owner'),
            $runId + [Environment]::NewLine,
            [Text.UTF8Encoding]::new($false)
        )
    }

    $secretPath = ''
    if ($PersistGeneratedSecret) {
        $secretPath = Save-QuickTestGeneratedSecret `
            -SecretDirectory $scopeSecretDirectory `
            -SecureValue $AdminSecret `
            -RunId $runId
    }

    $environmentNames = [Collections.Generic.List[string]]::new()
    foreach ($name in @(
            'QTLAB_COMPOSE_PROJECT'
            'QTLAB_SCOPE'
            'QTLAB_RUN_ID'
            'QTLAB_RUNTIME_DIR'
            'QTLAB_SQL_MEMORY_MB'
            'QTLAB_MEMORY_LIMIT'
            'QTLAB_CPU_LIMIT'
            'MSSQL_SA_PASSWORD'
        )) {
        $environmentNames.Add($name)
    }
    foreach ($version in @(2019, 2022, 2025)) {
        foreach ($suffix in @(
                'IMAGE'
                'CONTAINER'
                'PORT'
                'DATA_DIR'
                'LOG_DIR'
                'BACKUP_DIR'
            )) {
            $environmentNames.Add("QTLAB_SQL${version}_$suffix")
        }
    }
    $previousEnvironment = @{}
    foreach ($name in $environmentNames) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable(
            $name,
            [EnvironmentVariableTarget]::Process
        )
    }

    $plainSecret = ConvertFrom-QuickTestSecureString -SecureValue $AdminSecret
    $containers = [Collections.Generic.List[object]]::new()
    $networkId = ''
    try {
        $environment = @{
            QTLAB_COMPOSE_PROJECT = $projectName
            QTLAB_SCOPE = $ScopeName
            QTLAB_RUN_ID = $runId
            QTLAB_RUNTIME_DIR = $runtimeDirectory
            QTLAB_SQL_MEMORY_MB = [string] $profile.SqlMemoryMiB
            QTLAB_MEMORY_LIMIT = $profile.MemoryLimit
            QTLAB_CPU_LIMIT = $profile.CpuLimit
            MSSQL_SA_PASSWORD = $plainSecret
        }
        foreach ($name in $environment.Keys) {
            [Environment]::SetEnvironmentVariable(
                $name,
                [string] $environment[$name],
                [EnvironmentVariableTarget]::Process
            )
        }

        foreach ($version in $versions) {
            $versionRoot = Join-Path $scopeDataDirectory ([string] $version)
            $directories = @{
                DATA_DIR = Join-Path $versionRoot 'data'
                LOG_DIR = Join-Path $versionRoot 'log'
                BACKUP_DIR = Join-Path $versionRoot 'backup'
            }
            foreach ($directory in $directories.Values) {
                [IO.Directory]::CreateDirectory($directory) | Out-Null
                Set-QuickTestDirectoryPermissions -Path $directory
            }
            $values = @{
                IMAGE = Get-QuickTestImageReference -SqlVersion $version
                CONTAINER = "$ScopeName-sql$version"
                PORT = [string] $resolvedPorts[$version]
                DATA_DIR = $directories.DATA_DIR
                LOG_DIR = $directories.LOG_DIR
                BACKUP_DIR = $directories.BACKUP_DIR
            }
            foreach ($suffix in $values.Keys) {
                [Environment]::SetEnvironmentVariable(
                    "QTLAB_SQL${version}_$suffix",
                    [string] $values[$suffix],
                    [EnvironmentVariableTarget]::Process
                )
            }
        }

        Invoke-QuickTestCompose `
            -RuntimeInfo $runtimeInfo `
            -ProjectName $projectName `
            -SqlVersions $versions `
            -Arguments @('pull') |
            Out-Null

        foreach ($version in $versions) {
            $service = Get-QuickTestServiceName -SqlVersion $version
            Invoke-QuickTestCompose `
                -RuntimeInfo $runtimeInfo `
                -ProjectName $projectName `
                -SqlVersions $versions `
                -Arguments @('up', '--detach', $service) |
                Out-Null

            $containerId = Get-QuickTestContainerId `
                -RuntimeInfo $runtimeInfo `
                -ProjectName $projectName `
                -SqlVersions $versions `
                -SqlVersion $version
            $containers.Add([pscustomobject] @{
                    SqlVersion = $version
                    ProductMajorVersion = @{ 2019 = 15; 2022 = 16; 2025 = 17 }[$version]
                    ServiceName = $service
                    ContainerId = $containerId
                    ContainerName = "$ScopeName-sql$version"
                    Port = [int] $resolvedPorts[$version]
                    ImageReference = Get-QuickTestImageReference -SqlVersion $version
                })
            if (-not $networkId) {
                $networkId = Get-QuickTestNetworkId `
                    -RuntimeInfo $runtimeInfo `
                    -RunId $runId
            }

            Wait-QuickTestContainerHealthy `
                -RuntimeInfo $runtimeInfo `
                -ContainerId $containerId
            $major = Invoke-QuickTestSqlQuery `
                -RuntimeInfo $runtimeInfo `
                -ContainerId $containerId `
                -Query "SET NOCOUNT ON; SELECT CONVERT(int, SERVERPROPERTY('ProductMajorVersion'));" |
                Where-Object { $_ -match '^[0-9]+$' } |
                Select-Object -First 1
            if ([int] $major -ne $containers[$containers.Count - 1].ProductMajorVersion) {
                throw "SQL Server $version returned an unexpected major version."
            }
            if ($AdminLogin -ne 'sa') {
                Initialize-QuickTestAdminLogin `
                    -RuntimeInfo $runtimeInfo `
                    -ContainerId $containerId `
                    -AdminLogin $AdminLogin `
                    -RuntimeDirectory $runtimeDirectory `
                    -SecureValue $AdminSecret `
                    -SqlVersion $version
            }
            if ($InstallFramework) {
                $modulePath = Join-Path (
                    $script:QuickTestLabRoot
                ) 'Orchestration/Modules/DiagnosticLab/DiagnosticLab.psd1'
                Import-Module -Name $modulePath -Force -ErrorAction Stop
                Install-LabContainerFramework `
                    -Runtime $Runtime `
                    -RuntimeCommand $runtimeInfo.Command `
                    -ContainerId $containerId `
                    -RunDirectory $scopeStateDirectory |
                    Out-Null
            }
        }

        Write-QuickTestJson -Path $statePath -InputObject ([ordered] @{
                SchemaVersion = '1.0'
                DataClassification = 'LOCAL_RUNTIME_STATE'
                ScopeName = $ScopeName
                RunId = $runId
                Runtime = $Runtime
                ProjectName = $projectName
                SqlVersions = $versions
                ResourceProfile = $ResourceProfile
                PersistenceMode = $PersistenceMode
                InstallFramework = [bool] $InstallFramework
                AdminLogin = $AdminLogin
                FrameworkDatabase = if ($InstallFramework) { 'LabAnalyze' } else { '' }
                StateBaseRoot = [IO.Path]::GetFullPath($StateRoot)
                StateDirectory = [IO.Path]::GetFullPath($scopeStateDirectory)
                DataBaseRoot = [IO.Path]::GetFullPath($DataRoot)
                DataRoot = [IO.Path]::GetFullPath($scopeDataDirectory)
                SecretBaseRoot = [IO.Path]::GetFullPath($SecretRoot)
                SecretDirectory = if ($secretPath) {
                    [IO.Path]::GetFullPath($scopeSecretDirectory)
                }
                else {
                    ''
                }
                GeneratedSecretStored = [bool] $secretPath
                NetworkId = $networkId
                Containers = $containers.ToArray()
            })

        $credentialSegment = 'Pass' + 'word=<prompt>'
        return [pscustomobject] @{
            Status = 'READY'
            ScopeName = $ScopeName
            Runtime = $Runtime
            SqlVersions = $versions
            AdminLogin = $AdminLogin
            FrameworkDatabase = if ($InstallFramework) { 'LabAnalyze' } else { '' }
            GeneratedSecretPath = $secretPath
            Connections = @($containers | ForEach-Object {
                    [pscustomobject] @{
                        SqlVersion = $_.SqlVersion
                        Server = 'localhost'
                        Port = $_.Port
                        Login = $AdminLogin
                        SqlCmd = "sqlcmd -C -S localhost,$($_.Port) -U $AdminLogin"
                        ConnectionStringTemplate = "Server=localhost,$($_.Port);User ID=$AdminLogin;$credentialSegment;TrustServerCertificate=True"
                    }
                })
        }
    }
    catch {
        $originalError = $_
        try {
            $resources = Get-QuickTestResourcesByRunId `
                -RuntimeInfo $runtimeInfo `
                -RunId $runId
            Remove-QuickTestRuntimeResources `
                -RuntimeInfo $runtimeInfo `
                -RunId $runId `
                -ContainerIds $resources.ContainerIds `
                -NetworkIds $resources.NetworkIds
            if (
                $PersistenceMode -eq 'TEMPORARY' -and
                (Test-Path -LiteralPath $scopeDataDirectory) -and
                (Test-QuickTestOwnedDirectory `
                    -Path $scopeDataDirectory `
                    -Root $DataRoot `
                    -RunId $runId)
            ) {
                Remove-Item -LiteralPath $scopeDataDirectory -Recurse -Force
            }
            if (
                $secretPath -and
                (Test-QuickTestOwnedDirectory `
                    -Path $scopeSecretDirectory `
                    -Root $SecretRoot `
                    -RunId $runId)
            ) {
                Remove-Item -LiteralPath $scopeSecretDirectory -Recurse -Force
            }
        }
        catch {
            # Preserve the original failure; remaining resources stay discoverable by run label.
        }
        throw $originalError
    }
    finally {
        foreach ($name in $environmentNames) {
            [Environment]::SetEnvironmentVariable(
                $name,
                $previousEnvironment[$name],
                [EnvironmentVariableTarget]::Process
            )
        }
        $plainSecret = $null
    }
}
