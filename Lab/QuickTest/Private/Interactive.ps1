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
            $invalid = @(
                $versions |
                Where-Object { $_ -notin @(2019, 2022, 2025) }
            )
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
