[CmdletBinding()]
param(
    [Parameter()]
    [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$paths = @(
    'Lab/Install-Lab.ps1'
    'Lab/Uninstall-Lab.ps1'
    'Lab/QuickTest/QuickTestLab.psm1'
    'Lab/Orchestration/Modules/DiagnosticLab/Public/Install-LabContainerFramework.ps1'
)
foreach ($relativePath in $paths) {
    $path = Join-Path $RepositoryRoot $relativePath
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref] $tokens,
        [ref] $errors
    ) | Out-Null
    if (@($errors).Count -gt 0) {
        throw "PowerShell parser reported an error for $relativePath."
    }
}

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

Write-Output 'Docker/Podman quick-test PowerShell contracts passed.'
