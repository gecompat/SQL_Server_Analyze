Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:QuickTestLabRoot = [IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..')
)
$script:QuickTestRepositoryRoot = [IO.Path]::GetFullPath(
    (Join-Path $script:QuickTestLabRoot '..')
)

function ConvertFrom-QuickTestSecureString {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [securestring] $SecureValue
    )

    $pointer = [IntPtr]::Zero
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
            $SecureValue
        )
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        if ($pointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
    }
}

function Test-QuickTestPassword {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [securestring] $SecureValue
    )

    $plainSecret = ConvertFrom-QuickTestSecureString -SecureValue $SecureValue
    try {
        return (
            $plainSecret.Length -ge 12 -and
            $plainSecret -cmatch '[A-Z]' -and
            $plainSecret -cmatch '[a-z]' -and
            $plainSecret -match '[0-9]' -and
            $plainSecret -match '[^A-Za-z0-9]'
        )
    }
    finally {
        $plainSecret = $null
    }
}

function New-QuickTestPassword {
    [CmdletBinding()]
    [OutputType([securestring])]
    param(
        [Parameter()]
        [ValidateRange(16, 128)]
        [int] $Length = 24
    )

    $sets = @(
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnopqrstuvwxyz'
        '23456789'
        '!#$%&*+-=?@_'
    )
    $characters = [Collections.Generic.List[char]]::new()
    foreach ($set in $sets) {
        $characters.Add(
            $set[[Security.Cryptography.RandomNumberGenerator]::GetInt32(
                $set.Length
            )]
        )
    }
    $combined = ($sets -join '')
    while ($characters.Count -lt $Length) {
        $characters.Add(
            $combined[[Security.Cryptography.RandomNumberGenerator]::GetInt32(
                $combined.Length
            )]
        )
    }
    for ($index = $characters.Count - 1; $index -gt 0; $index--) {
        $swapIndex = [Security.Cryptography.RandomNumberGenerator]::GetInt32(
            $index + 1
        )
        $temporary = $characters[$index]
        $characters[$index] = $characters[$swapIndex]
        $characters[$swapIndex] = $temporary
    }

    return ConvertTo-SecureString -String (-join $characters) -AsPlainText -Force
}

function Get-QuickTestDefaultPorts {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        2019 = 14331
        2022 = 14332
        2025 = 14335
    }
}

function Get-QuickTestResourceProfile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('SMALL', 'MEDIUM', 'LARGE')]
        [string] $Name
    )

    return switch ($Name) {
        'SMALL' {
            [pscustomobject] @{
                Name = 'SMALL'
                CpuLimit = '2.0'
                MemoryLimit = '3g'
                ContainerMemoryMiB = 3072
                SqlMemoryMiB = 2048
            }
        }
        'MEDIUM' {
            [pscustomobject] @{
                Name = 'MEDIUM'
                CpuLimit = '3.0'
                MemoryLimit = '5g'
                ContainerMemoryMiB = 5120
                SqlMemoryMiB = 4096
            }
        }
        'LARGE' {
            [pscustomobject] @{
                Name = 'LARGE'
                CpuLimit = '4.0'
                MemoryLimit = '8g'
                ContainerMemoryMiB = 8192
                SqlMemoryMiB = 6144
            }
        }
    }
}

function Get-QuickTestImageReference {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(2019, 2022, 2025)]
        [int] $SqlVersion
    )

    return "mcr.microsoft.com/mssql/server:$SqlVersion-latest"
}

function Get-QuickTestServiceName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(2019, 2022, 2025)]
        [int] $SqlVersion
    )

    return "sql$SqlVersion"
}

function New-QuickTestRunId {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $suffix = [Convert]::ToHexString(
        [Security.Cryptography.RandomNumberGenerator]::GetBytes(4)
    )
    return 'QTLAB-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + $suffix
}

function Test-QuickTestPathWithinRoot {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Root
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    return (
        $fullPath -eq $fullRoot -or
        $fullPath.StartsWith(
            $fullRoot + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::Ordinal
        )
    )
}

function Write-QuickTestJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [object] $InputObject
    )

    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [IO.File]::WriteAllText(
        $Path,
        ($InputObject | ConvertTo-Json -Depth 100),
        [Text.UTF8Encoding]::new($false)
    )
}

function Read-QuickTestJson {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    return Get-Content -LiteralPath $Path -Raw -Encoding utf8 |
        ConvertFrom-Json -Depth 100
}

function Invoke-QuickTestCommand {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [string[]] $Arguments,

        [Parameter()]
        [int[]] $AllowedExitCodes = @(0)
    )

    $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string] $_ })
    $exitCode = $LASTEXITCODE
    if ($exitCode -notin $AllowedExitCodes) {
        throw "Quick-test runtime command failed with exit code $exitCode."
    }
    return $output
}

function Resolve-QuickTestRuntime {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DOCKER', 'PODMAN')]
        [string] $Runtime
    )

    $commandName = $Runtime.ToLowerInvariant()
    $command = Get-Command $commandName -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return [pscustomobject] @{
            IsAvailable = $false
            Runtime = $Runtime
            Command = ''
            ReasonCode = 'RUNTIME_UNAVAILABLE'
        }
    }

    try {
        Invoke-QuickTestCommand `
            -FilePath $command.Source `
            -Arguments @('version') |
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

function Test-QuickTestPortAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1024, 65535)]
        [int] $Port
    )

    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, $Port)
    try {
        $listener.Start()
        return $true
    }
    catch {
        return $false
    }
    finally {
        $listener.Stop()
    }
}

function Get-QuickTestAvailableMemoryMiB {
    [CmdletBinding()]
    [OutputType([int64])]
    param()

    if (-not $IsLinux -or -not (Test-Path -LiteralPath '/proc/meminfo')) {
        return 0
    }
    $line = Get-Content -LiteralPath '/proc/meminfo' -Encoding utf8 |
        Where-Object { $_ -match '^MemAvailable:\s+([0-9]+)\s+kB$' } |
        Select-Object -First 1
    if ($line -match '^MemAvailable:\s+([0-9]+)\s+kB$') {
        return [int64] [Math]::Floor(([int64] $Matches[1]) / 1024)
    }
    return 0
}

function Resolve-QuickTestPorts {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [int[]] $SqlVersions,

        [Parameter()]
        [hashtable] $Ports = @{}
    )

    $defaults = Get-QuickTestDefaultPorts
    $resolved = @{}
    foreach ($version in $SqlVersions) {
        $port = if ($Ports.ContainsKey($version)) {
            [int] $Ports[$version]
        }
        elseif ($Ports.ContainsKey([string] $version)) {
            [int] $Ports[[string] $version]
        }
        else {
            [int] $defaults[$version]
        }
        if ($port -lt 1024 -or $port -gt 65535) {
            throw "The host port for SQL Server $version is outside the allowed range."
        }
        $resolved[$version] = $port
    }
    return $resolved
}

function Invoke-QuickTestPreflight {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DOCKER', 'PODMAN')]
        [string] $Runtime,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int[]] $SqlVersions,

        [Parameter()]
        [hashtable] $Ports = @{},

        [Parameter()]
        [ValidateSet('SMALL', 'MEDIUM', 'LARGE')]
        [string] $ResourceProfile = 'SMALL',

        [Parameter()]
        [ValidatePattern('^(sa|[A-Za-z][A-Za-z0-9_]{2,31})$')]
        [string] $AdminLogin = 'ExampleSqlAdmin',

        [Parameter()]
        [string] $DataRoot = (Join-Path $script:QuickTestLabRoot '.artifacts/quick-test'),

        [Parameter()]
        [switch] $SkipImageAvailabilityCheck
    )

    $blockers = [Collections.Generic.List[string]]::new()
    $checks = [Collections.Generic.List[object]]::new()
    $versions = @($SqlVersions | Sort-Object -Unique)
    if (
        $versions.Count -ne $SqlVersions.Count -or
        @($versions | Where-Object { $_ -notin @(2019, 2022, 2025) }).Count -gt 0
    ) {
        $blockers.Add('SQL_VERSION_SELECTION_INVALID')
    }
    $resolvedPorts = Resolve-QuickTestPorts -SqlVersions $versions -Ports $Ports
    if (@($resolvedPorts.Values | Select-Object -Unique).Count -ne $resolvedPorts.Count) {
        $blockers.Add('PORT_CONFLICT')
    }

    $platformReady = (
        $IsLinux -and
        [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq
        [Runtime.InteropServices.Architecture]::X64
    )
    $checks.Add([pscustomobject] @{
            Check = 'PLATFORM'
            Status = if ($platformReady) { 'PASS' } else { 'FAIL' }
            ReasonCode = if ($platformReady) { '' } else { 'UNSUPPORTED_PLATFORM' }
        })
    if (-not $platformReady) {
        $blockers.Add('UNSUPPORTED_PLATFORM')
    }

    $runtimeInfo = Resolve-QuickTestRuntime -Runtime $Runtime
    $checks.Add([pscustomobject] @{
            Check = 'RUNTIME'
            Status = if ($runtimeInfo.IsAvailable) { 'PASS' } else { 'FAIL' }
            ReasonCode = $runtimeInfo.ReasonCode
        })
    if (-not $runtimeInfo.IsAvailable) {
        $blockers.Add($runtimeInfo.ReasonCode)
    }

    foreach ($version in $versions) {
        $port = [int] $resolvedPorts[$version]
        $available = Test-QuickTestPortAvailable -Port $port
        $checks.Add([pscustomobject] @{
                Check = "PORT_$version"
                Status = if ($available) { 'PASS' } else { 'FAIL' }
                ReasonCode = if ($available) { '' } else { 'PORT_CONFLICT' }
            })
        if (-not $available) {
            $blockers.Add('PORT_CONFLICT')
        }
    }

    $profile = Get-QuickTestResourceProfile -Name $ResourceProfile
    $availableMemory = Get-QuickTestAvailableMemoryMiB
    $requiredMemory = ([int64] $profile.ContainerMemoryMiB * $versions.Count) + 2048
    $resourceReady = $availableMemory -eq 0 -or $availableMemory -ge $requiredMemory
    $checks.Add([pscustomobject] @{
            Check = 'MEMORY_RESERVE'
            Status = if ($resourceReady) { 'PASS' } else { 'FAIL' }
            ReasonCode = if ($resourceReady) { '' } else { 'RESOURCE_LIMIT_EXCEEDED' }
            RequiredMemoryMiB = $requiredMemory
            AvailableMemoryMiB = $availableMemory
        })
    if (-not $resourceReady) {
        $blockers.Add('RESOURCE_LIMIT_EXCEEDED')
    }

    $fullDataRoot = [IO.Path]::GetFullPath($DataRoot)
    $ancestor = $fullDataRoot
    while (-not (Test-Path -LiteralPath $ancestor -PathType Container)) {
        $parent = Split-Path -Parent $ancestor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $ancestor) {
            break
        }
        $ancestor = $parent
    }
    $pathReady = Test-Path -LiteralPath $ancestor -PathType Container
    $checks.Add([pscustomobject] @{
            Check = 'DATA_ROOT'
            Status = if ($pathReady) { 'PASS' } else { 'FAIL' }
            ReasonCode = if ($pathReady) { '' } else { 'DATA_ROOT_UNAVAILABLE' }
        })
    if (-not $pathReady) {
        $blockers.Add('DATA_ROOT_UNAVAILABLE')
    }

    if ($runtimeInfo.IsAvailable -and -not $SkipImageAvailabilityCheck) {
        foreach ($version in $versions) {
            $image = Get-QuickTestImageReference -SqlVersion $version
            $imageReady = $true
            try {
                Invoke-QuickTestCommand `
                    -FilePath $runtimeInfo.Command `
                    -Arguments @('manifest', 'inspect', $image) |
                    Out-Null
            }
            catch {
                $imageReady = $false
            }
            $checks.Add([pscustomobject] @{
                    Check = "IMAGE_$version"
                    Status = if ($imageReady) { 'PASS' } else { 'FAIL' }
                    ReasonCode = if ($imageReady) { '' } else { 'IMAGE_UNAVAILABLE' }
                })
            if (-not $imageReady) {
                $blockers.Add('IMAGE_UNAVAILABLE')
            }
        }
    }

    return [pscustomobject] @{
        Status = if ($blockers.Count -eq 0) { 'READY' } else { 'PREFLIGHT_FAILED' }
        Runtime = $Runtime
        RuntimeCommand = $runtimeInfo.Command
        SqlVersions = $versions
        Ports = $resolvedPorts
        AdminLogin = $AdminLogin
        ResourceProfile = $ResourceProfile
        DataRoot = $fullDataRoot
        Checks = $checks.ToArray()
        BlockerReasonCodes = @($blockers | Sort-Object -Unique)
    }
}

function Set-QuickTestDirectoryPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not $IsLinux) {
        return
    }
    [IO.File]::SetUnixFileMode(
        $Path,
        (
            [IO.UnixFileMode]::UserRead -bor
            [IO.UnixFileMode]::UserWrite -bor
            [IO.UnixFileMode]::UserExecute -bor
            [IO.UnixFileMode]::GroupRead -bor
            [IO.UnixFileMode]::GroupWrite -bor
            [IO.UnixFileMode]::GroupExecute -bor
            [IO.UnixFileMode]::OtherRead -bor
            [IO.UnixFileMode]::OtherWrite -bor
            [IO.UnixFileMode]::OtherExecute
        )
    )
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
        "{{ index .Config.Labels \"$LabelName\" }}"
    }
    else {
        "{{ index .Labels \"$LabelName\" }}"
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
        $sql = @"
SET NOCOUNT ON;
IF SUSER_ID(N'$stringLogin') IS NULL
BEGIN
    CREATE LOGIN [$quotedLogin] WITH PASSWORD = N'$stringSecret', CHECK_POLICY = OFF;
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
    [IO.File]::WriteAllText(
        (Join-Path $scopeDataDirectory '.quicktest-owner'),
        $runId + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false)
    )
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
        [Environment]::SetEnvironmentVariable(
            'QTLAB_COMPOSE_PROJECT', $projectName,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            'QTLAB_SCOPE', $ScopeName,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            'QTLAB_RUN_ID', $runId,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            'QTLAB_RUNTIME_DIR', $runtimeDirectory,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            'QTLAB_SQL_MEMORY_MB', [string] $profile.SqlMemoryMiB,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            'QTLAB_MEMORY_LIMIT', $profile.MemoryLimit,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            'QTLAB_CPU_LIMIT', $profile.CpuLimit,
            [EnvironmentVariableTarget]::Process
        )
        [Environment]::SetEnvironmentVariable(
            'MSSQL_SA_PASSWORD', $plainSecret,
            [EnvironmentVariableTarget]::Process
        )

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
        Invoke-QuickTestCompose `
            -RuntimeInfo $runtimeInfo `
            -ProjectName $projectName `
            -SqlVersions $versions `
            -Arguments @('up', '--detach') |
            Out-Null

        foreach ($version in $versions) {
            $containerId = Get-QuickTestContainerId `
                -RuntimeInfo $runtimeInfo `
                -ProjectName $projectName `
                -SqlVersions $versions `
                -SqlVersion $version
            Wait-QuickTestContainerHealthy `
                -RuntimeInfo $runtimeInfo `
                -ContainerId $containerId
            $major = Invoke-QuickTestSqlQuery `
                -RuntimeInfo $runtimeInfo `
                -ContainerId $containerId `
                -Query "SET NOCOUNT ON; SELECT CONVERT(int, SERVERPROPERTY('ProductMajorVersion'));" |
                Where-Object { $_ -match '^[0-9]+$' } |
                Select-Object -First 1
            $expectedMajor = @{ 2019 = 15; 2022 = 16; 2025 = 17 }[$version]
            if ([int] $major -ne $expectedMajor) {
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
            $containers.Add([pscustomobject] @{
                    SqlVersion = $version
                    ProductMajorVersion = $expectedMajor
                    ServiceName = Get-QuickTestServiceName -SqlVersion $version
                    ContainerId = $containerId
                    ContainerName = "$ScopeName-sql$version"
                    Port = [int] $resolvedPorts[$version]
                    ImageReference = Get-QuickTestImageReference -SqlVersion $version
                })
        }
        $networkId = Get-QuickTestNetworkId `
            -RuntimeInfo $runtimeInfo `
            -RunId $runId

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
                StateRoot = [IO.Path]::GetFullPath($StateRoot)
                DataBaseRoot = [IO.Path]::GetFullPath($DataRoot)
                DataRoot = [IO.Path]::GetFullPath($scopeDataDirectory)
                SecretBaseRoot = [IO.Path]::GetFullPath($SecretRoot)
                SecretDirectory = if ($secretPath) { [IO.Path]::GetFullPath($scopeSecretDirectory) } else { '' }
                GeneratedSecretStored = [bool] $secretPath
                NetworkId = $networkId
                Containers = $containers.ToArray()
            })

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
                        ConnectionStringTemplate = "Server=localhost,$($_.Port);User ID=$AdminLogin;Password=<prompt>;TrustServerCertificate=True"
                    }
                })
        }
    }
    catch {
        $originalError = $_
        try {
            foreach ($container in $containers) {
                $owner = Get-QuickTestObjectLabel `
                    -RuntimeInfo $runtimeInfo `
                    -ResourceType CONTAINER `
                    -ExactLocator $container.ContainerId `
                    -LabelName 'qt-lab.run-id'
                if ($owner -eq $runId) {
                    Invoke-QuickTestCommand `
                        -FilePath $runtimeInfo.Command `
                        -Arguments @('container', 'rm', '--force', $container.ContainerId) |
                        Out-Null
                }
            }
            if ($networkId) {
                $owner = Get-QuickTestObjectLabel `
                    -RuntimeInfo $runtimeInfo `
                    -ResourceType NETWORK `
                    -ExactLocator $networkId `
                    -LabelName 'qt-lab.run-id'
                if ($owner -eq $runId) {
                    Invoke-QuickTestCommand `
                        -FilePath $runtimeInfo.Command `
                        -Arguments @('network', 'rm', $networkId) |
                        Out-Null
                }
            }
        }
        catch {
            # Preserve the original failure. Any unresolved scope remains visible by label.
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

function Get-QuickTestLabStatus {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidatePattern('^[a-z][a-z0-9-]{2,31}$')]
        [string] $ScopeName = 'sql-analyze-quicktest',

        [Parameter()]
        [string] $StateRoot = (Join-Path $script:QuickTestLabRoot '.state/quick-test')
    )

    $statePath = Join-Path (Join-Path $StateRoot $ScopeName) 'state.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        return [pscustomobject] @{
            Status = 'NOT_INSTALLED'
            ScopeName = $ScopeName
            Instances = @()
        }
    }
    $state = Read-QuickTestJson -Path $statePath
    $runtimeInfo = Resolve-QuickTestRuntime -Runtime $state.Runtime
    if (-not $runtimeInfo.IsAvailable) {
        return [pscustomobject] @{
            Status = 'RUNTIME_UNAVAILABLE'
            ScopeName = $ScopeName
            Runtime = $state.Runtime
            Instances = @()
        }
    }

    $instances = [Collections.Generic.List[object]]::new()
    foreach ($container in $state.Containers) {
        $exists = $true
        $inspect = @()
        try {
            $inspect = Invoke-QuickTestCommand `
                -FilePath $runtimeInfo.Command `
                -Arguments @(
                    'container'
                    'inspect'
                    '--format'
                    '{{.State.Status}}|{{.State.Health.Status}}'
                    $container.ContainerId
                )
        }
        catch {
            $exists = $false
        }
        $runtimeState = if ($exists) {
            [string] ($inspect | Select-Object -First 1)
        }
        else {
            'missing|missing'
        }
        $parts = $runtimeState.Split('|')
        $ownerValid = $false
        if ($exists) {
            $ownerValid = (
                Get-QuickTestObjectLabel `
                    -RuntimeInfo $runtimeInfo `
                    -ResourceType CONTAINER `
                    -ExactLocator $container.ContainerId `
                    -LabelName 'qt-lab.run-id'
            ) -eq $state.RunId
        }
        $instances.Add([pscustomobject] @{
                SqlVersion = [int] $container.SqlVersion
                ContainerId = [string] $container.ContainerId
                ContainerName = [string] $container.ContainerName
                Port = [int] $container.Port
                RuntimeStatus = $parts[0]
                HealthStatus = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                OwnershipValid = $ownerValid
                Ready = (
                    $exists -and
                    $parts[0] -eq 'running' -and
                    $parts[1] -eq 'healthy' -and
                    $ownerValid
                )
            })
    }
    $ready = @($instances | Where-Object { $_.Ready }).Count
    return [pscustomobject] @{
        Status = if ($ready -eq $instances.Count) { 'READY' } else { 'PARTIAL_SUCCESS' }
        ScopeName = $ScopeName
        Runtime = $state.Runtime
        AdminLogin = $state.AdminLogin
        FrameworkDatabase = $state.FrameworkDatabase
        Instances = $instances.ToArray()
    }
}

function Remove-QuickTestLab {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidatePattern('^[a-z][a-z0-9-]{2,31}$')]
        [string] $ScopeName = 'sql-analyze-quicktest',

        [Parameter()]
        [string] $StateRoot = (Join-Path $script:QuickTestLabRoot '.state/quick-test'),

        [Parameter()]
        [switch] $RemoveData
    )

    $scopeStateDirectory = Join-Path $StateRoot $ScopeName
    $statePath = Join-Path $scopeStateDirectory 'state.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        return [pscustomobject] @{
            Status = 'NOT_INSTALLED'
            ScopeName = $ScopeName
        }
    }
    $state = Read-QuickTestJson -Path $statePath
    if (-not $PSCmdlet.ShouldProcess(
            "quick-test scope $ScopeName",
            'Destroy exact registered containers, network, state, and approved data'
        )) {
        return [pscustomobject] @{
            Status = 'DESTROY_CONFIRMATION_REQUIRED'
            ScopeName = $ScopeName
        }
    }
    $runtimeInfo = Resolve-QuickTestRuntime -Runtime $state.Runtime
    if (-not $runtimeInfo.IsAvailable) {
        return [pscustomobject] @{
            Status = 'RUNTIME_UNAVAILABLE'
            ScopeName = $ScopeName
        }
    }

    foreach ($container in @($state.Containers | Sort-Object SqlVersion -Descending)) {
        $owner = Get-QuickTestObjectLabel `
            -RuntimeInfo $runtimeInfo `
            -ResourceType CONTAINER `
            -ExactLocator $container.ContainerId `
            -LabelName 'qt-lab.run-id'
        if ($owner -ne $state.RunId) {
            throw 'Container ownership does not match the saved quick-test state.'
        }
        Invoke-QuickTestCommand `
            -FilePath $runtimeInfo.Command `
            -Arguments @('container', 'rm', '--force', $container.ContainerId) |
            Out-Null
    }
    if ($state.NetworkId) {
        $owner = Get-QuickTestObjectLabel `
            -RuntimeInfo $runtimeInfo `
            -ResourceType NETWORK `
            -ExactLocator $state.NetworkId `
            -LabelName 'qt-lab.run-id'
        if ($owner -ne $state.RunId) {
            throw 'Network ownership does not match the saved quick-test state.'
        }
        Invoke-QuickTestCommand `
            -FilePath $runtimeInfo.Command `
            -Arguments @('network', 'rm', $state.NetworkId) |
            Out-Null
    }

    $removeDataEffective = $RemoveData -or $state.PersistenceMode -eq 'TEMPORARY'
    if ($removeDataEffective -and (Test-Path -LiteralPath $state.DataRoot)) {
        if (
            -not (Test-QuickTestPathWithinRoot `
                    -Path $state.DataRoot `
                    -Root $state.DataBaseRoot) -or
            -not (Test-Path `
                    -LiteralPath (Join-Path $state.DataRoot '.quicktest-owner') `
                    -PathType Leaf) -or
            (Get-Content `
                -LiteralPath (Join-Path $state.DataRoot '.quicktest-owner') `
                -Raw `
                -Encoding utf8).Trim() -ne $state.RunId
        ) {
            throw 'Data cleanup refused an unowned or out-of-bound directory.'
        }
        Remove-Item -LiteralPath $state.DataRoot -Recurse -Force
    }
    if ($state.SecretDirectory -and (Test-Path -LiteralPath $state.SecretDirectory)) {
        if (
            -not (Test-QuickTestPathWithinRoot `
                    -Path $state.SecretDirectory `
                    -Root $state.SecretBaseRoot) -or
            -not (Test-Path `
                    -LiteralPath (Join-Path $state.SecretDirectory '.quicktest-owner') `
                    -PathType Leaf)
        ) {
            throw 'Secret cleanup refused an unowned or out-of-bound directory.'
        }
        Remove-Item -LiteralPath $state.SecretDirectory -Recurse -Force
    }
    Remove-Item -LiteralPath $scopeStateDirectory -Recurse -Force

    return [pscustomobject] @{
        Status = 'DESTROYED'
        ScopeName = $ScopeName
        DataRemoved = $removeDataEffective
    }
}

Export-ModuleMember -Function @(
    'Get-QuickTestDefaultPorts'
    'Get-QuickTestLabStatus'
    'Get-QuickTestResourceProfile'
    'Install-QuickTestLab'
    'Invoke-QuickTestPreflight'
    'New-QuickTestPassword'
    'Remove-QuickTestLab'
    'Resolve-QuickTestPorts'
    'Test-QuickTestPassword'
    'Test-QuickTestPathWithinRoot'
)
