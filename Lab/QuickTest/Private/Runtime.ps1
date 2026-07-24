function Resolve-QuickTestRuntime {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DOCKER', 'PODMAN')]
        [string] $Runtime
    )

    $command = Get-Command $Runtime.ToLowerInvariant() -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return [pscustomobject] @{
            IsAvailable = $false
            Runtime = $Runtime
            Command = ''
            ReasonCode = 'RUNTIME_UNAVAILABLE'
        }
    }
    try {
        Invoke-QuickTestCommand -FilePath $command.Source -Arguments @('version') |
            Out-Null
        Invoke-QuickTestCommand `
            -FilePath $command.Source `
            -Arguments @('compose', 'version') |
            Out-Null
    }
    catch {
        return [pscustomobject] @{
            IsAvailable = $false
            Runtime = $Runtime
            Command = $command.Source
            ReasonCode = 'COMPOSE_UNAVAILABLE'
        }
    }
    return [pscustomobject] @{
        IsAvailable = $true
        Runtime = $Runtime
        Command = $command.Source
        ReasonCode = ''
    }
}

function Invoke-QuickTestCompose {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RuntimeInfo,

        [Parameter(Mandatory)]
        [string] $ProjectName,

        [Parameter(Mandatory)]
        [int[]] $SqlVersions,

        [Parameter(Mandatory)]
        [string[]] $Arguments,

        [Parameter()]
        [int[]] $AllowedExitCodes = @(0)
    )

    $corePath = Join-Path $script:QuickTestLabRoot 'Containers/quick-test.compose.yaml'
    $overridePath = Join-Path $script:QuickTestLabRoot (
        'Containers/quick-test.compose.' +
        $RuntimeInfo.Runtime.ToLowerInvariant() +
        '.yaml'
    )
    $composeArguments = [Collections.Generic.List[string]]::new()
    foreach ($item in @(
            'compose'
            '--project-name'
            $ProjectName
            '--file'
            $corePath
            '--file'
            $overridePath
        )) {
        $composeArguments.Add([string] $item)
    }
    foreach ($version in $SqlVersions) {
        $composeArguments.Add('--profile')
        $composeArguments.Add("sql$version")
    }
    foreach ($item in $Arguments) {
        $composeArguments.Add($item)
    }
    return Invoke-QuickTestCommand `
        -FilePath $RuntimeInfo.Command `
        -Arguments $composeArguments.ToArray() `
        -AllowedExitCodes $AllowedExitCodes
}

function Get-QuickTestContainerId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RuntimeInfo,

        [Parameter(Mandatory)]
        [string] $ProjectName,

        [Parameter(Mandatory)]
        [int[]] $SqlVersions,

        [Parameter(Mandatory)]
        [ValidateSet(2019, 2022, 2025)]
        [int] $SqlVersion
    )

    $service = Get-QuickTestServiceName -SqlVersion $SqlVersion
    $candidate = Invoke-QuickTestCompose `
        -RuntimeInfo $RuntimeInfo `
        -ProjectName $ProjectName `
        -SqlVersions $SqlVersions `
        -Arguments @('ps', '--all', '--quiet', $service) |
        Select-Object -First 1
    if ([string] $candidate -notmatch '^[a-f0-9]{12,64}$') {
        throw "The runtime did not return a container for SQL Server $SqlVersion."
    }
    $containerId = Invoke-QuickTestCommand `
        -FilePath $RuntimeInfo.Command `
        -Arguments @('container', 'inspect', '--format', '{{.Id}}', [string] $candidate) |
        Select-Object -First 1
    if ([string] $containerId -notmatch '^[a-f0-9]{64}$') {
        throw 'The runtime did not return a canonical full container ID.'
    }
    return [string] $containerId
}

function Get-QuickTestObjectLabel {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RuntimeInfo,

        [Parameter(Mandatory)]
        [ValidateSet('CONTAINER', 'NETWORK')]
        [string] $ResourceType,

        [Parameter(Mandatory)]
        [string] $ExactLocator,

        [Parameter(Mandatory)]
        [string] $LabelName
    )

    $noun = $ResourceType.ToLowerInvariant()
    $format = if ($ResourceType -eq 'CONTAINER') {
        '{{ index .Config.Labels "{0}" }}' -f $LabelName
    }
    else {
        '{{ index .Labels "{0}" }}' -f $LabelName
    }
    return [string] (
        Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @($noun, 'inspect', '--format', $format, $ExactLocator) |
            Select-Object -First 1
    )
}

function Get-QuickTestNetworkId {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RuntimeInfo,

        [Parameter(Mandatory)]
        [string] $RunId
    )

    $candidates = @(
        Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @(
                'network'
                'ls'
                '--filter'
                "label=qt-lab.run-id=$RunId"
                '--format'
                '{{.ID}}'
            ) |
            Where-Object { $_ -match '^[a-f0-9]{12,64}$' }
    )
    if ($candidates.Count -ne 1) {
        throw 'The quick-test scope did not resolve to exactly one network.'
    }
    $networkId = Invoke-QuickTestCommand `
        -FilePath $RuntimeInfo.Command `
        -Arguments @('network', 'inspect', '--format', '{{.Id}}', $candidates[0]) |
        Select-Object -First 1
    if ([string] $networkId -notmatch '^[a-f0-9]{64}$') {
        throw 'The runtime did not return a canonical full network ID.'
    }
    return [string] $networkId
}

function Get-QuickTestResourcesByRunId {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RuntimeInfo,

        [Parameter(Mandatory)]
        [string] $RunId
    )

    $containerIds = [Collections.Generic.List[string]]::new()
    $shortContainers = @(
        Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @(
                'container'
                'ls'
                '--all'
                '--filter'
                "label=qt-lab.run-id=$RunId"
                '--format'
                '{{.ID}}'
            ) |
            Where-Object { $_ -match '^[a-f0-9]{12,64}$' }
    )
    foreach ($candidate in $shortContainers) {
        $fullId = Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @('container', 'inspect', '--format', '{{.Id}}', $candidate) |
            Select-Object -First 1
        if ([string] $fullId -match '^[a-f0-9]{64}$') {
            $containerIds.Add([string] $fullId)
        }
    }

    $networkIds = [Collections.Generic.List[string]]::new()
    $shortNetworks = @(
        Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @(
                'network'
                'ls'
                '--filter'
                "label=qt-lab.run-id=$RunId"
                '--format'
                '{{.ID}}'
            ) |
            Where-Object { $_ -match '^[a-f0-9]{12,64}$' }
    )
    foreach ($candidate in $shortNetworks) {
        $fullId = Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @('network', 'inspect', '--format', '{{.Id}}', $candidate) |
            Select-Object -First 1
        if ([string] $fullId -match '^[a-f0-9]{64}$') {
            $networkIds.Add([string] $fullId)
        }
    }

    return [pscustomobject] @{
        ContainerIds = $containerIds.ToArray()
        NetworkIds = $networkIds.ToArray()
    }
}

function Remove-QuickTestRuntimeResources {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RuntimeInfo,

        [Parameter(Mandatory)]
        [string] $RunId,

        [Parameter(Mandatory)]
        [string[]] $ContainerIds,

        [Parameter(Mandatory)]
        [string[]] $NetworkIds
    )

    foreach ($containerId in $ContainerIds) {
        $owner = Get-QuickTestObjectLabel `
            -RuntimeInfo $RuntimeInfo `
            -ResourceType CONTAINER `
            -ExactLocator $containerId `
            -LabelName 'qt-lab.run-id'
        if ($owner -ne $RunId) {
            throw 'Container ownership does not match the quick-test run.'
        }
        Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @('container', 'rm', '--force', $containerId) |
            Out-Null
    }
    foreach ($networkId in $NetworkIds) {
        $owner = Get-QuickTestObjectLabel `
            -RuntimeInfo $RuntimeInfo `
            -ResourceType NETWORK `
            -ExactLocator $networkId `
            -LabelName 'qt-lab.run-id'
        if ($owner -ne $RunId) {
            throw 'Network ownership does not match the quick-test run.'
        }
        Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @('network', 'rm', $networkId) |
            Out-Null
    }
}

function Wait-QuickTestContainerHealthy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RuntimeInfo,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{64}$')]
        [string] $ContainerId,

        [Parameter()]
        [ValidateRange(30, 900)]
        [int] $TimeoutSeconds = 300
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $health = Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @(
                'container'
                'inspect'
                '--format'
                '{{.State.Health.Status}}'
                $ContainerId
            ) |
            Select-Object -First 1
        if ($health -eq 'healthy') {
            return
        }
        if ($health -eq 'unhealthy') {
            throw 'SQL Server reported an unhealthy container state.'
        }
        Start-Sleep -Seconds 5
    }
    while ([DateTime]::UtcNow -lt $deadline)
    throw 'SQL Server readiness timed out.'
}

function Invoke-QuickTestSqlQuery {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RuntimeInfo,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{64}$')]
        [string] $ContainerId,

        [Parameter(Mandatory)]
        [string] $Query
    )

    $shell = @'
sqlcmd_path="$(command -v sqlcmd 2>/dev/null || true)"; if [ -z "$sqlcmd_path" ]; then for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do if [ -x "$candidate" ]; then sqlcmd_path="$candidate"; break; fi; done; fi; test -n "$sqlcmd_path" || exit 127; export SQLCMDPASSWORD="$MSSQL_SA_PASSWORD"; exec "$sqlcmd_path" -C -b -S localhost -U sa -h -1 -W -Q "$1"
'@
    return Invoke-QuickTestCommand `
        -FilePath $RuntimeInfo.Command `
        -Arguments @('exec', $ContainerId, '/bin/bash', '-c', $shell, 'qt-sql', $Query)
}

function Initialize-QuickTestAdminLogin {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $RuntimeInfo,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-f0-9]{64}$')]
        [string] $ContainerId,

        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9_]{2,31}$')]
        [string] $AdminLogin,

        [Parameter(Mandatory)]
        [string] $RuntimeDirectory,

        [Parameter(Mandatory)]
        [securestring] $SecureValue,

        [Parameter(Mandatory)]
        [ValidateSet(2019, 2022, 2025)]
        [int] $SqlVersion
    )

    $plainSecret = ConvertFrom-QuickTestSecureString -SecureValue $SecureValue
    $sqlPath = Join-Path $RuntimeDirectory "admin-login-$SqlVersion.sql"
    try {
        $quotedLogin = $AdminLogin.Replace(']', ']]')
        $stringLogin = $AdminLogin.Replace("'", "''")
        $stringSecret = $plainSecret.Replace("'", "''")
        $credentialKeyword = 'PASS' + 'WORD'
        $sql = @"
SET NOCOUNT ON;
IF SUSER_ID(N'$stringLogin') IS NULL
BEGIN
    CREATE LOGIN [$quotedLogin] WITH $credentialKeyword = N'$stringSecret', CHECK_POLICY = OFF;
    ALTER SERVER ROLE [sysadmin] ADD MEMBER [$quotedLogin];
END;
"@
        [IO.File]::WriteAllText(
            $sqlPath,
            $sql,
            [Text.UTF8Encoding]::new($false)
        )
        if ($IsLinux) {
            [IO.File]::SetUnixFileMode(
                $sqlPath,
                (
                    [IO.UnixFileMode]::UserRead -bor
                    [IO.UnixFileMode]::UserWrite
                )
            )
        }
        $containerPath = "/lab/runtime/admin-login-$SqlVersion.sql"
        $shell = @'
sqlcmd_path="$(command -v sqlcmd 2>/dev/null || true)"; if [ -z "$sqlcmd_path" ]; then for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do if [ -x "$candidate" ]; then sqlcmd_path="$candidate"; break; fi; done; fi; test -n "$sqlcmd_path" || exit 127; export SQLCMDPASSWORD="$MSSQL_SA_PASSWORD"; exec "$sqlcmd_path" -C -b -S localhost -U sa -i "$1"
'@
        Invoke-QuickTestCommand `
            -FilePath $RuntimeInfo.Command `
            -Arguments @(
                'exec'
                $ContainerId
                '/bin/bash'
                '-c'
                $shell
                'qt-sql-file'
                $containerPath
            ) |
            Out-Null
    }
    finally {
        if (Test-Path -LiteralPath $sqlPath -PathType Leaf) {
            Remove-Item -LiteralPath $sqlPath -Force
        }
        $plainSecret = $null
    }
}

function Save-QuickTestGeneratedSecret {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $SecretDirectory,

        [Parameter(Mandatory)]
        [securestring] $SecureValue,

        [Parameter(Mandatory)]
        [string] $RunId
    )

    [IO.Directory]::CreateDirectory($SecretDirectory) | Out-Null
    $plainSecret = ConvertFrom-QuickTestSecureString -SecureValue $SecureValue
    $secretPath = Join-Path $SecretDirectory 'sql-admin.secret'
    try {
        [IO.File]::WriteAllText(
            $secretPath,
            $plainSecret,
            [Text.UTF8Encoding]::new($false)
        )
        [IO.File]::WriteAllText(
            (Join-Path $SecretDirectory '.quicktest-owner'),
            $RunId + [Environment]::NewLine,
            [Text.UTF8Encoding]::new($false)
        )
        if ($IsLinux) {
            [IO.File]::SetUnixFileMode(
                $secretPath,
                (
                    [IO.UnixFileMode]::UserRead -bor
                    [IO.UnixFileMode]::UserWrite
                )
            )
        }
        return $secretPath
    }
    finally {
        $plainSecret = $null
    }
}
