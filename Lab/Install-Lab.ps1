[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateSet('Preflight', 'Install', 'Status', 'Destroy')]
    [string] $Action = 'Install',

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
    [ValidatePattern('^[a-z][a-z0-9-]{2,31}$')]
    [string] $ScopeName = 'sql-analyze-quicktest',

    [Parameter()]
    [switch] $InstallFramework,

    [Parameter()]
    [switch] $AcceptEula,

    [Parameter()]
    [switch] $NonInteractive,

    [Parameter()]
    [switch] $SkipImageAvailabilityCheck,

    [Parameter()]
    [switch] $RemoveData
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'QuickTest/QuickTestLab.psm1'
Import-Module -Name $modulePath -Force -ErrorAction Stop

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
                ForEach-Object { [int] $_.Trim() } |
                Sort-Object -Unique
            )
            if (
                $versions.Count -gt 0 -and
                @($versions | Where-Object { $_ -notin @(2019, 2022, 2025) }).Count -eq 0
            ) {
                return $versions
            }
        }
        catch {
            # A concise warning follows below.
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
            if (
                [int]::TryParse($value, [ref] $port) -and
                $port -ge 1024 -and
                $port -le 65535
            ) {
                $result[$version] = $port
                break
            }
            Write-Warning 'Use an unprivileged TCP port from 1024 through 65535.'
        }
    }
    return $result
}

if ($Action -in @('Status', 'Destroy')) {
    if ($Action -eq 'Status') {
        Get-QuickTestLabStatus -ScopeName $ScopeName
        return
    }
    Remove-QuickTestLab `
        -ScopeName $ScopeName `
        -RemoveData:$RemoveData `
        -Confirm:$false `
        -WhatIf:$WhatIfPreference
    return
}

if (-not $PSBoundParameters.ContainsKey('Runtime')) {
    if ($NonInteractive) {
        throw 'Non-interactive Preflight or Install requires -Runtime.'
    }
    $Runtime = Read-QuickTestChoice `
        -Prompt 'Container runtime' `
        -AllowedValues @('DOCKER', 'PODMAN') `
        -DefaultValue 'DOCKER'
}
if (-not $PSBoundParameters.ContainsKey('SqlVersions')) {
    if ($NonInteractive) {
        throw 'Non-interactive Preflight or Install requires -SqlVersions.'
    }
    $SqlVersions = Read-QuickTestVersions
}
if (-not $PSBoundParameters.ContainsKey('Ports') -or $Ports.Count -eq 0) {
    if ($NonInteractive) {
        $Ports = Get-QuickTestDefaultPorts
    }
    else {
        $Ports = Read-QuickTestPorts -Versions $SqlVersions
    }
}
if (-not $PSBoundParameters.ContainsKey('AdminLogin')) {
    if ($NonInteractive) {
        $AdminLogin = 'ExampleSqlAdmin'
    }
    else {
        $value = Read-Host 'Administrative SQL login [ExampleSqlAdmin]'
        $AdminLogin = if ([string]::IsNullOrWhiteSpace($value)) {
            'ExampleSqlAdmin'
        }
        else {
            $value.Trim()
        }
    }
}

if ($Action -eq 'Preflight') {
    Invoke-QuickTestPreflight `
        -Runtime $Runtime `
        -SqlVersions $SqlVersions `
        -Ports $Ports `
        -ResourceProfile $ResourceProfile `
        -AdminLogin $AdminLogin `
        -SkipImageAvailabilityCheck:$SkipImageAvailabilityCheck
    return
}

if (-not $AcceptEula) {
    if ($NonInteractive) {
        throw 'Non-interactive Install requires -AcceptEula.'
    }
    $confirmation = Read-Host 'Accept the SQL Server container EULA for this test use? [yes/no]'
    if ($confirmation.Trim().ToLowerInvariant() -ne 'yes') {
        throw 'SQL Server EULA acceptance was not provided.'
    }
    $AcceptEula = $true
}

$generated = $false
if ($GenerateSecret) {
    $AdminSecret = New-QuickTestPassword
    $generated = $true
}
elseif ($PSBoundParameters.ContainsKey('AdminSecret')) {
    # The caller supplied a SecureString object.
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
}
elseif (-not $NonInteractive) {
    $AdminSecret = Read-Host 'Administrative SQL secret' -AsSecureString
}
else {
    throw 'Provide -AdminSecret, -GenerateSecret, or a populated secret environment variable.'
}

if (-not (Test-QuickTestPassword -SecureValue $AdminSecret)) {
    throw 'The supplied SQL secret does not satisfy the documented complexity contract.'
}

$result = Install-QuickTestLab `
    -Runtime $Runtime `
    -SqlVersions $SqlVersions `
    -Ports $Ports `
    -AdminSecret $AdminSecret `
    -AdminLogin $AdminLogin `
    -ResourceProfile $ResourceProfile `
    -PersistenceMode $PersistenceMode `
    -ScopeName $ScopeName `
    -InstallFramework:$InstallFramework `
    -PersistGeneratedSecret:$generated `
    -AcceptEula:$AcceptEula `
    -SkipImageAvailabilityCheck:$SkipImageAvailabilityCheck `
    -Confirm:$false `
    -WhatIf:$WhatIfPreference

$result
