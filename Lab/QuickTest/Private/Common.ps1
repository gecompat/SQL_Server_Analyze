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
    $combined = $sets -join ''
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
    $result = @{}
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
        $result[$version] = $port
    }
    return $result
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

function Test-QuickTestOwnedDirectory {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Root,

        [Parameter(Mandatory)]
        [string] $RunId
    )

    $marker = Join-Path $Path '.quicktest-owner'
    return (
        (Test-QuickTestPathWithinRoot -Path $Path -Root $Root) -and
        (Test-Path -LiteralPath $marker -PathType Leaf) -and
        ((Get-Content -LiteralPath $marker -Raw -Encoding utf8).Trim() -eq $RunId)
    )
}
