function Invoke-QuickTestEntryPoint {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
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

    if ($Action -eq 'Status') {
        return Get-QuickTestLabStatus -ScopeName $ScopeName
    }

    if ($Action -eq 'Destroy') {
        return Remove-QuickTestLab `
            -ScopeName $ScopeName `
            -RemoveData:$RemoveData `
            -WhatIf:$WhatIfPreference `
            -Confirm:$ConfirmPreference
    }

    if ([string]::IsNullOrWhiteSpace($Runtime)) {
        if ($NonInteractive) {
            throw 'Non-interactive Preflight or Install requires -Runtime.'
        }
        $Runtime = Read-QuickTestChoice `
            -Prompt 'Container runtime' `
            -AllowedValues @('DOCKER', 'PODMAN') `
            -DefaultValue 'DOCKER'
    }

    if ($null -eq $SqlVersions -or $SqlVersions.Count -eq 0) {
        if ($NonInteractive) {
            throw 'Non-interactive Preflight or Install requires -SqlVersions.'
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
            $value = Read-Host 'Administrative SQL login [ExampleSqlAdmin]'
            if ([string]::IsNullOrWhiteSpace($value)) {
                $AdminLogin = 'ExampleSqlAdmin'
            }
            else {
                $AdminLogin = $value.Trim()
            }
        }
    }

    if ($Action -eq 'Preflight') {
        return Invoke-QuickTestPreflight `
            -Runtime $Runtime `
            -SqlVersions $SqlVersions `
            -Ports $Ports `
            -ResourceProfile $ResourceProfile `
            -AdminLogin $AdminLogin `
            -ScopeName $ScopeName `
            -SkipImageAvailabilityCheck:$SkipImageAvailabilityCheck
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
    elseif ($null -ne $AdminSecret) {
        # SecureString supplied by the caller.
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

    return Install-QuickTestLab `
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
        -WhatIf:$WhatIfPreference `
        -Confirm:$ConfirmPreference
}
