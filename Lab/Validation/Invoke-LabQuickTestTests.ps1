[CmdletBinding()]
param(
    [Parameter()]
    [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,

    [Parameter()]
    [ValidateSet('ALL', 'PARSER', 'HELPERS', 'PREFLIGHT')]
    [string] $Phase = 'ALL',

    [Parameter()]
    [ValidateSet(
        'ALL',
        'ENTRYPOINTS',
        'COMMON',
        'RUNTIME',
        'PREFLIGHT',
        'INSTALL',
        'STATUS',
        'DESTROY',
        'MODULE'
    )]
    [string] $ParserTarget = 'ALL'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Test-QuickTestPowerShellFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath
    )

    $path = Join-Path $RepositoryRoot $RelativePath
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref] $tokens,
        [ref] $errors
    ) | Out-Null
    if (@($errors).Count -gt 0) {
        $errorSummary = @($errors | ForEach-Object { $_.Message }) -join '; '
        throw "PowerShell parser reported an error for $RelativePath: $errorSummary"
    }
}

function Invoke-QuickTestParserPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Target
    )

    $targetPaths = @{
        ENTRYPOINTS = @(
            'Lab/Install-Lab.ps1'
            'Lab/Uninstall-Lab.ps1'
            'Lab/Orchestration/Modules/DiagnosticLab/Public/Install-LabContainerFramework.ps1'
        )
        COMMON = @('Lab/QuickTest/Private/Common.ps1')
        RUNTIME = @('Lab/QuickTest/Private/Runtime.ps1')
        PREFLIGHT = @('Lab/QuickTest/Public/Invoke-QuickTestPreflight.ps1')
        INSTALL = @('Lab/QuickTest/Public/Install-QuickTestLab.ps1')
        STATUS = @('Lab/QuickTest/Public/Get-QuickTestLabStatus.ps1')
        DESTROY = @('Lab/QuickTest/Public/Remove-QuickTestLab.ps1')
        MODULE = @('Lab/QuickTest/QuickTestLab.psm1')
    }

    if ($Target -eq 'ALL') {
        foreach ($key in $targetPaths.Keys) {
            foreach ($relativePath in $targetPaths[$key]) {
                Test-QuickTestPowerShellFile -RelativePath $relativePath
            }
        }
        $modulePath = Join-Path $RepositoryRoot 'Lab/QuickTest/QuickTestLab.psm1'
        Import-Module -Name $modulePath -Force -ErrorAction Stop
    }
    elseif ($Target -eq 'MODULE') {
        Test-QuickTestPowerShellFile `
            -RelativePath 'Lab/QuickTest/QuickTestLab.psm1'
        $modulePath = Join-Path $RepositoryRoot 'Lab/QuickTest/QuickTestLab.psm1'
        Import-Module -Name $modulePath -Force -ErrorAction Stop
    }
    else {
        foreach ($relativePath in $targetPaths[$Target]) {
            Test-QuickTestPowerShellFile -RelativePath $relativePath
        }
    }
    Write-Output "Docker/Podman quick-test parser contract passed: $Target."
}

function Invoke-QuickTestHelperPhase {
    [CmdletBinding()]
    param()

    $modulePath = Join-Path $RepositoryRoot 'Lab/QuickTest/QuickTestLab.psm1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $generatedSecret = New-QuickTestPassword -Length 24
    if (-not (Test-QuickTestPassword -SecureValue $generatedSecret)) {
        throw 'Generated quick-test secret does not satisfy the complexity contract.'
    }

    $ports = Get-QuickTestDefaultPorts
    if (
        $ports[2019] -ne 14331 -or
        $ports[2022] -ne 14332 -or
        $ports[2025] -ne 14335
    ) {
        throw 'Default quick-test ports are not stable.'
    }
    $resolvedPorts = Resolve-QuickTestPorts `
        -SqlVersions @(2019, 2025) `
        -Ports @{ 2019 = 15431; 2025 = 15435 }
    if ($resolvedPorts[2019] -ne 15431 -or $resolvedPorts[2025] -ne 15435) {
        throw 'Explicit quick-test port mapping was not preserved.'
    }

    $small = Get-QuickTestResourceProfile -Name SMALL
    $medium = Get-QuickTestResourceProfile -Name MEDIUM
    $large = Get-QuickTestResourceProfile -Name LARGE
    if (
        $small.ContainerMemoryMiB -ge $medium.ContainerMemoryMiB -or
        $medium.ContainerMemoryMiB -ge $large.ContainerMemoryMiB -or
        $small.SqlMemoryMiB -ge $small.ContainerMemoryMiB
    ) {
        throw 'Quick-test resource profiles are not ordered or bounded.'
    }

    $root = Join-Path ([IO.Path]::GetTempPath()) 'qt-boundary'
    $inside = Join-Path $root 'scope/data'
    $outside = Join-Path ([IO.Path]::GetTempPath()) 'other-scope'
    if (-not (Test-QuickTestPathWithinRoot -Path $inside -Root $root)) {
        throw 'The path-boundary helper rejected an owned child path.'
    }
    if (Test-QuickTestPathWithinRoot -Path $outside -Root $root) {
        throw 'The path-boundary helper accepted an outside path.'
    }
    Write-Output 'Docker/Podman quick-test helper contracts passed.'
}

function Invoke-QuickTestPreflightPhase {
    [CmdletBinding()]
    param()

    $modulePath = Join-Path $RepositoryRoot 'Lab/QuickTest/QuickTestLab.psm1'
    Import-Module -Name $modulePath -Force -ErrorAction Stop

    $previousPath = $env:PATH
    $emptyPath = Join-Path ([IO.Path]::GetTempPath()) 'qt-empty-path'
    [IO.Directory]::CreateDirectory($emptyPath) | Out-Null
    try {
        $env:PATH = $emptyPath
        $preflight = Invoke-QuickTestPreflight `
            -Runtime DOCKER `
            -SqlVersions @(2019, 2022) `
            -Ports @{ 2019 = 15441; 2022 = 15441 } `
            -ResourceProfile SMALL `
            -AdminLogin ExampleSqlAdmin `
            -SkipImageAvailabilityCheck
        if ($preflight.Status -ne 'PREFLIGHT_FAILED') {
            throw 'A missing runtime and duplicate ports did not fail Preflight.'
        }
        if (
            'RUNTIME_UNAVAILABLE' -notin @($preflight.BlockerReasonCodes) -or
            'PORT_CONFLICT' -notin @($preflight.BlockerReasonCodes)
        ) {
            throw 'Preflight did not preserve structured blocker reason codes.'
        }
    }
    finally {
        $env:PATH = $previousPath
        Remove-Item -LiteralPath $emptyPath -Force -ErrorAction SilentlyContinue
    }
    Write-Output 'Docker/Podman quick-test Preflight contracts passed.'
}

if ($Phase -in @('ALL', 'PARSER')) {
    Invoke-QuickTestParserPhase -Target $ParserTarget
}
if ($Phase -in @('ALL', 'HELPERS')) {
    Invoke-QuickTestHelperPhase
}
if ($Phase -in @('ALL', 'PREFLIGHT')) {
    Invoke-QuickTestPreflightPhase
}
