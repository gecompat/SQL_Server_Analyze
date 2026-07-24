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
        [ValidatePattern('^[a-z][a-z0-9-]{2,31}$')]
        [string] $ScopeName = 'sql-analyze-quicktest',

        [Parameter()]
        [string] $DataRoot = (Join-Path $script:QuickTestLabRoot '.artifacts/quick-test'),

        [Parameter()]
        [switch] $SkipImageAvailabilityCheck
    )

    $blockers = [Collections.Generic.List[string]]::new()
    $checks = [Collections.Generic.List[object]]::new()
    $versions = @($SqlVersions | Sort-Object -Unique)
    if (
        $versions.Count -eq 0 -or
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

    if ($runtimeInfo.IsAvailable) {
        $existing = @(
            Invoke-QuickTestCommand `
                -FilePath $runtimeInfo.Command `
                -Arguments @(
                    'container'
                    'ls'
                    '--all'
                    '--filter'
                    "label=qt-lab.scope=$ScopeName"
                    '--format'
                    '{{.ID}}'
                )
        )
        $scopeReady = $existing.Count -eq 0
        $checks.Add([pscustomobject] @{
                Check = 'SCOPE_COLLISION'
                Status = if ($scopeReady) { 'PASS' } else { 'FAIL' }
                ReasonCode = if ($scopeReady) { '' } else { 'SCOPE_ALREADY_EXISTS' }
            })
        if (-not $scopeReady) {
            $blockers.Add('SCOPE_ALREADY_EXISTS')
        }
    }

    if ($runtimeInfo.IsAvailable -and -not $SkipImageAvailabilityCheck) {
        foreach ($version in $versions) {
            $imageReady = $true
            try {
                Invoke-QuickTestCommand `
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
