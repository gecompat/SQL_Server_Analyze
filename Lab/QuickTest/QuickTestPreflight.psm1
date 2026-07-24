Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:QuickTestLabRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

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

function Test-QuickTestSqlSecret {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [securestring] $SecureValue
    )

    $plainValue = ConvertFrom-QuickTestSecureString -SecureValue $SecureValue
    try {
        return (
            $plainValue.Length -ge 12 -and
            $plainValue -cmatch '[A-Z]' -and
            $plainValue -cmatch '[a-z]' -and
            $plainValue -match '[0-9]' -and
            $plainValue -match '[^A-Za-z0-9]'
        )
    }
    finally {
        $plainValue = $null
    }
}

function New-QuickTestSqlSecret {
    [CmdletBinding()]
    [OutputType([securestring])]
    param(
        [Parameter()]
        [ValidateRange(16, 128)]
        [int] $Length = 24
    )

    $characterSets = @(
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnopqrstuvwxyz'
        '23456789'
        '!#$%&*+-=?@_'
    )
    $characters = [Collections.Generic.List[char]]::new()
    foreach ($set in $characterSets) {
        $characters.Add(
            $set[[Security.Cryptography.RandomNumberGenerator]::GetInt32(
                $set.Length
            )]
        )
    }
    $allCharacters = $characterSets -join ''
    while ($characters.Count -lt $Length) {
        $characters.Add(
            $allCharacters[
                [Security.Cryptography.RandomNumberGenerator]::GetInt32(
                    $allCharacters.Length
                )
            ]
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

    return @{ 2019 = 14331; 2022 = 14332; 2025 = 14335 }
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
        $port = 0
        if ($Ports.ContainsKey($version)) {
            $port = [int] $Ports[$version]
        }
        elseif ($Ports.ContainsKey([string] $version)) {
            $port = [int] $Ports[[string] $version]
        }
        else {
            $port = [int] $defaults[$version]
        }
        if ($port -lt 1024 -or $port -gt 65535) {
            throw "The host port for SQL Server $version is outside 1024 through 65535."
        }
        $resolved[$version] = $port
    }
    return $resolved
}

function Get-QuickTestResourceProfile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('SMALL', 'MEDIUM', 'LARGE')]
        [string] $Name
    )

    switch ($Name) {
        'SMALL' {
            return [pscustomobject] @{
                Name = 'SMALL'
                CpuLimit = 2
                ContainerMemoryMiB = 3072
                SqlMemoryMiB = 2048
            }
        }
        'MEDIUM' {
            return [pscustomobject] @{
                Name = 'MEDIUM'
                CpuLimit = 3
                ContainerMemoryMiB = 5120
                SqlMemoryMiB = 4096
            }
        }
        'LARGE' {
            return [pscustomobject] @{
                Name = 'LARGE'
                CpuLimit = 4
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

function Invoke-QuickTestReadOnlyCommand {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string] $FilePath,

        [Parameter(Mandatory)]
        [string[]] $Arguments
    )

    $output = @(& $FilePath @Arguments 2>&1 | ForEach-Object { [string] $_ })
    if ($LASTEXITCODE -ne 0) {
        throw "Read-only runtime probe failed with exit code $LASTEXITCODE."
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
        Invoke-QuickTestReadOnlyCommand `
            -FilePath $command.Source `
            -Arguments @('version') |
            Out-Null
        Invoke-QuickTestReadOnlyCommand `
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

function Test-QuickTestDataRoot {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $DataRoot
    )

    $candidate = [IO.Path]::GetFullPath($DataRoot)
    while (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        $parent = Split-Path -Parent $candidate
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $candidate) {
            return $false
        }
        $candidate = $parent
    }
    return $true
}

function Invoke-QuickTestPreflight {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DOCKER', 'PODMAN')]
        [string] $Runtime,

        [Parameter(Mandatory)]
        [int[]] $SqlVersions,

        [Parameter()]
        [hashtable] $Ports = @{},

        [Parameter()]
        [ValidateSet('SMALL', 'MEDIUM', 'LARGE')]
        [string] $ResourceProfile = 'SMALL',

        [Parameter()]
        [ValidateSet('PERSISTENT', 'TEMPORARY')]
        [string] $PersistenceMode = 'TEMPORARY',

        [Parameter()]
        [ValidatePattern('^(sa|[A-Za-z][A-Za-z0-9_]{2,31})$')]
        [string] $AdminLogin = 'ExampleSqlAdmin',

        [Parameter(Mandatory)]
        [securestring] $AdminSecret,

        [Parameter()]
        [ValidateSet('SECURESTRING', 'ENVIRONMENT', 'GENERATED_EPHEMERAL', 'INTERACTIVE')]
        [string] $SecretSource = 'SECURESTRING',

        [Parameter()]
        [switch] $InstallFramework,

        [Parameter()]
        [switch] $AcceptEula,

        [Parameter()]
        [string] $DataRoot = (Join-Path $script:QuickTestLabRoot '.artifacts/quick-test'),

        [Parameter()]
        [switch] $SkipImageAvailabilityCheck
    )

    $blockers = [Collections.Generic.List[string]]::new()
    $checks = [Collections.Generic.List[object]]::new()
    $versions = @($SqlVersions | Sort-Object -Unique)
    $invalidVersions = @($versions | Where-Object { $_ -notin @(2019, 2022, 2025) })
    if (
        $versions.Count -eq 0 -or
        $versions.Count -ne $SqlVersions.Count -or
        $invalidVersions.Count -gt 0
    ) {
        $blockers.Add('SQL_VERSION_SELECTION_INVALID')
    }

    $resolvedPorts = Resolve-QuickTestPorts -SqlVersions $versions -Ports $Ports
    $uniquePorts = @($resolvedPorts.Values | Select-Object -Unique)
    if ($uniquePorts.Count -ne $resolvedPorts.Count) {
        $blockers.Add('PORT_CONFLICT')
    }

    $platformReady = (
        $IsLinux -and
        [Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq
        [Runtime.InteropServices.Architecture]::X64
    )
    $platformStatus = 'FAIL'
    $platformReason = 'UNSUPPORTED_PLATFORM'
    if ($platformReady) {
        $platformStatus = 'PASS'
        $platformReason = ''
    }
    $checks.Add([pscustomobject] @{
            Check = 'PLATFORM'
            Status = $platformStatus
            ReasonCode = $platformReason
        })
    if (-not $platformReady) {
        $blockers.Add('UNSUPPORTED_PLATFORM')
    }

    $runtimeInfo = Resolve-QuickTestRuntime -Runtime $Runtime
    $runtimeStatus = 'FAIL'
    if ($runtimeInfo.IsAvailable) {
        $runtimeStatus = 'PASS'
    }
    $checks.Add([pscustomobject] @{
            Check = 'RUNTIME_AND_COMPOSE'
            Status = $runtimeStatus
            ReasonCode = $runtimeInfo.ReasonCode
        })
    if (-not $runtimeInfo.IsAvailable) {
        $blockers.Add($runtimeInfo.ReasonCode)
    }

    foreach ($version in $versions) {
        $port = [int] $resolvedPorts[$version]
        $portAvailable = Test-QuickTestPortAvailable -Port $port
        $portStatus = 'FAIL'
        $portReason = 'PORT_CONFLICT'
        if ($portAvailable) {
            $portStatus = 'PASS'
            $portReason = ''
        }
        $checks.Add([pscustomobject] @{
                Check = "PORT_$version"
                Status = $portStatus
                ReasonCode = $portReason
                Port = $port
            })
        if (-not $portAvailable) {
            $blockers.Add('PORT_CONFLICT')
        }
    }

    $profile = Get-QuickTestResourceProfile -Name $ResourceProfile
    $availableMemory = Get-QuickTestAvailableMemoryMiB
    $requiredMemory = ([int64] $profile.ContainerMemoryMiB * $versions.Count) + 2048
    $memoryReady = $availableMemory -eq 0 -or $availableMemory -ge $requiredMemory
    $memoryStatus = 'FAIL'
    $memoryReason = 'RESOURCE_LIMIT_EXCEEDED'
    if ($memoryReady) {
        $memoryStatus = 'PASS'
        $memoryReason = ''
    }
    $checks.Add([pscustomobject] @{
            Check = 'MEMORY_RESERVE'
            Status = $memoryStatus
            ReasonCode = $memoryReason
            RequiredMemoryMiB = $requiredMemory
            AvailableMemoryMiB = $availableMemory
        })
    if (-not $memoryReady) {
        $blockers.Add('RESOURCE_LIMIT_EXCEEDED')
    }

    $pathReady = Test-QuickTestDataRoot -DataRoot $DataRoot
    $pathStatus = 'FAIL'
    $pathReason = 'DATA_ROOT_UNAVAILABLE'
    if ($pathReady) {
        $pathStatus = 'PASS'
        $pathReason = ''
    }
    $checks.Add([pscustomobject] @{
            Check = 'DATA_ROOT'
            Status = $pathStatus
            ReasonCode = $pathReason
        })
    if (-not $pathReady) {
        $blockers.Add('DATA_ROOT_UNAVAILABLE')
    }

    $credentialReady = Test-QuickTestSqlSecret -SecureValue $AdminSecret
    $credentialStatus = 'FAIL'
    $credentialReason = 'CREDENTIAL_POLICY_FAILED'
    if ($credentialReady) {
        $credentialStatus = 'PASS'
        $credentialReason = ''
    }
    $checks.Add([pscustomobject] @{
            Check = 'CREDENTIAL_POLICY'
            Status = $credentialStatus
            ReasonCode = $credentialReason
            SecretSource = $SecretSource
        })
    if (-not $credentialReady) {
        $blockers.Add('CREDENTIAL_POLICY_FAILED')
    }

    $eulaStatus = 'FAIL'
    $eulaReason = 'EULA_NOT_ACCEPTED'
    if ($AcceptEula) {
        $eulaStatus = 'PASS'
        $eulaReason = ''
    }
    $checks.Add([pscustomobject] @{
            Check = 'EULA_ACCEPTANCE'
            Status = $eulaStatus
            ReasonCode = $eulaReason
        })
    if (-not $AcceptEula) {
        $blockers.Add('EULA_NOT_ACCEPTED')
    }

    if ($runtimeInfo.IsAvailable -and -not $SkipImageAvailabilityCheck) {
        foreach ($version in $versions) {
            $imageReady = $true
            try {
                Invoke-QuickTestReadOnlyCommand `
                    -FilePath $runtimeInfo.Command `
                    -Arguments @(
                        'manifest'
                        'inspect'
                        (Get-QuickTestImageReference -SqlVersion $version)
                    ) |
                    Out-Null
            }
            catch {
                $imageReady = $false
            }
            $imageStatus = 'FAIL'
            $imageReason = 'IMAGE_UNAVAILABLE'
            if ($imageReady) {
                $imageStatus = 'PASS'
                $imageReason = ''
            }
            $checks.Add([pscustomobject] @{
                    Check = "IMAGE_$version"
                    Status = $imageStatus
                    ReasonCode = $imageReason
                })
            if (-not $imageReady) {
                $blockers.Add('IMAGE_UNAVAILABLE')
            }
        }
    }

    $resultStatus = 'PREFLIGHT_FAILED'
    if ($blockers.Count -eq 0) {
        $resultStatus = 'READY'
    }
    return [pscustomobject] @{
        Status = $resultStatus
        Runtime = $Runtime
        RuntimeCommand = $runtimeInfo.Command
        SqlVersions = $versions
        Ports = $resolvedPorts
        AdminLogin = $AdminLogin
        SecretSource = $SecretSource
        ResourceProfile = $ResourceProfile
        PersistenceMode = $PersistenceMode
        InstallFramework = [bool] $InstallFramework
        AcceptEula = [bool] $AcceptEula
        DataRoot = [IO.Path]::GetFullPath($DataRoot)
        Checks = $checks.ToArray()
        BlockerReasonCodes = @($blockers | Sort-Object -Unique)
        MutationPerformed = $false
        NextAction = 'INSTALL_LIFECYCLE_NOT_IMPLEMENTED'
    }
}

function Read-QuickTestChoice {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string] $Prompt,

        [Parameter(Mandatory)]
        [string[]] $AllowedValues,

        [Parameter(Mandatory)]
        [string] $DefaultValue
    )

    while ($true) {
        $value = Read-Host "$Prompt [$($AllowedValues -join '/')], default $DefaultValue"
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $DefaultValue
        }
        $normalized = $value.Trim().ToUpperInvariant()
        if ($normalized -in $AllowedValues) {
            return $normalized
        }
        Write-Warning 'The selected value is not supported.'
    }
}

function Read-QuickTestVersions {
    [CmdletBinding()]
    [OutputType([int[]])]
    param()

    while ($true) {
        $value = Read-Host 'SQL Server versions, comma separated [2019,2022,2025]'
        if ([string]::IsNullOrWhiteSpace($value)) {
            return @(2019, 2022, 2025)
        }
        try {
            $versions = @(
                $value.Split(',') |
                ForEach-Object { [int]::Parse($_.Trim()) } |
                Sort-Object -Unique
            )
            $invalid = @($versions | Where-Object { $_ -notin @(2019, 2022, 2025) })
            if ($versions.Count -gt 0 -and $invalid.Count -eq 0) {
                return $versions
            }
        }
        catch {
            # The warning below is the stable user-facing result.
        }
        Write-Warning 'Choose one or more values from 2019, 2022, and 2025.'
    }
}

function Read-QuickTestPorts {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [int[]] $Versions
    )

    $defaults = Get-QuickTestDefaultPorts
    $result = @{}
    foreach ($version in $Versions) {
        while ($true) {
            $value = Read-Host "Host port for SQL Server $version [$($defaults[$version])]"
            if ([string]::IsNullOrWhiteSpace($value)) {
                $result[$version] = [int] $defaults[$version]
                break
            }
            $port = 0
            $parsed = [int]::TryParse($value, [ref] $port)
            if ($parsed -and $port -ge 1024 -and $port -le 65535) {
                $result[$version] = $port
                break
            }
            Write-Warning 'Use an unprivileged TCP port from 1024 through 65535.'
        }
    }
    return $result
}

function Invoke-QuickTestPreflightEntry {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateSet('DOCKER', 'PODMAN')]
        [string] $Runtime,

        [Parameter()]
        [int[]] $SqlVersions,

        [Parameter()]
        [hashtable] $Ports = @{},

        [Parameter()]
        [ValidatePattern('^(sa|[A-Za-z][A-Za-z0-9_]{2,31})$')]
        [string] $AdminLogin,

        [Parameter()]
        [securestring] $AdminSecret,

        [Parameter()]
        [string] $SecretEnvironmentVariable = 'QTLAB_SQL_SECRET',

        [Parameter()]
        [switch] $GenerateSecret,

        [Parameter()]
        [ValidateSet('SMALL', 'MEDIUM', 'LARGE')]
        [string] $ResourceProfile = 'SMALL',

        [Parameter()]
        [ValidateSet('PERSISTENT', 'TEMPORARY')]
        [string] $PersistenceMode = 'TEMPORARY',

        [Parameter()]
        [switch] $InstallFramework,

        [Parameter()]
        [switch] $AcceptEula,

        [Parameter()]
        [switch] $NonInteractive,

        [Parameter()]
        [string] $DataRoot = (Join-Path $script:QuickTestLabRoot '.artifacts/quick-test'),

        [Parameter()]
        [switch] $SkipImageAvailabilityCheck
    )

    if ([string]::IsNullOrWhiteSpace($Runtime)) {
        if ($NonInteractive) {
            throw 'Non-interactive Preflight requires -Runtime.'
        }
        $Runtime = Read-QuickTestChoice `
            -Prompt 'Container runtime' `
            -AllowedValues @('DOCKER', 'PODMAN') `
            -DefaultValue 'DOCKER'
    }
    if ($null -eq $SqlVersions -or $SqlVersions.Count -eq 0) {
        if ($NonInteractive) {
            throw 'Non-interactive Preflight requires -SqlVersions.'
        }
        $SqlVersions = Read-QuickTestVersions
    }
    if ($Ports.Count -eq 0) {
        if ($NonInteractive) {
            $defaults = Get-QuickTestDefaultPorts
            foreach ($version in $SqlVersions) {
                $Ports[$version] = $defaults[$version]
            }
        }
        else {
            $Ports = Read-QuickTestPorts -Versions $SqlVersions
        }
    }
    if ([string]::IsNullOrWhiteSpace($AdminLogin)) {
        if ($NonInteractive) {
            $AdminLogin = 'ExampleSqlAdmin'
        }
        else {
            $loginInput = Read-Host 'Administrative SQL login [ExampleSqlAdmin]'
            if ([string]::IsNullOrWhiteSpace($loginInput)) {
                $AdminLogin = 'ExampleSqlAdmin'
            }
            else {
                $AdminLogin = $loginInput.Trim()
            }
        }
    }

    $secretSource = 'SECURESTRING'
    if ($GenerateSecret) {
        $AdminSecret = New-QuickTestSqlSecret
        $secretSource = 'GENERATED_EPHEMERAL'
    }
    elseif ($null -ne $AdminSecret) {
        $secretSource = 'SECURESTRING'
    }
    elseif (
        -not [string]::IsNullOrWhiteSpace($SecretEnvironmentVariable) -and
        -not [string]::IsNullOrWhiteSpace(
            [Environment]::GetEnvironmentVariable($SecretEnvironmentVariable)
        )
    ) {
        $AdminSecret = ConvertTo-SecureString `
            -String ([Environment]::GetEnvironmentVariable($SecretEnvironmentVariable)) `
            -AsPlainText `
            -Force
        $secretSource = 'ENVIRONMENT'
    }
    elseif (-not $NonInteractive) {
        $AdminSecret = Read-Host 'Administrative SQL secret' -AsSecureString
        $secretSource = 'INTERACTIVE'
    }
    else {
        throw 'Provide -AdminSecret, -GenerateSecret, or a populated secret environment variable.'
    }

    if (-not $AcceptEula -and -not $NonInteractive) {
        $confirmation = Read-Host 'Accept the SQL Server container EULA for the planned test use? [yes/no]'
        if ($confirmation.Trim().ToLowerInvariant() -eq 'yes') {
            $AcceptEula = $true
        }
    }

    return Invoke-QuickTestPreflight `
        -Runtime $Runtime `
        -SqlVersions $SqlVersions `
        -Ports $Ports `
        -ResourceProfile $ResourceProfile `
        -PersistenceMode $PersistenceMode `
        -AdminLogin $AdminLogin `
        -AdminSecret $AdminSecret `
        -SecretSource $secretSource `
        -InstallFramework:$InstallFramework `
        -AcceptEula:$AcceptEula `
        -DataRoot $DataRoot `
        -SkipImageAvailabilityCheck:$SkipImageAvailabilityCheck
}

Export-ModuleMember -Function @(
    'Get-QuickTestDefaultPorts'
    'Get-QuickTestResourceProfile'
    'Invoke-QuickTestPreflight'
    'Invoke-QuickTestPreflightEntry'
    'New-QuickTestSqlSecret'
    'Resolve-QuickTestPorts'
    'Test-QuickTestSqlSecret'
)
