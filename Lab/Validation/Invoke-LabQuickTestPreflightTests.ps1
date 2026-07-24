[CmdletBinding()]
param(
    [Parameter()]
    [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

foreach ($relativePath in @(
        'Lab/Install-Lab.ps1'
        'Lab/QuickTest/QuickTestPreflight.psm1'
    )) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $RepositoryRoot $relativePath),
        [ref] $tokens,
        [ref] $errors
    ) | Out-Null
    if (@($errors).Count -gt 0) {
        $summary = @($errors | ForEach-Object { $_.Message }) -join '; '
        throw "PowerShell parser reported an error for ${relativePath}: $summary"
    }
}

$modulePath = Join-Path $RepositoryRoot 'Lab/QuickTest/QuickTestPreflight.psm1'
Import-Module -Name $modulePath -Force -ErrorAction Stop

$secret = New-QuickTestSqlSecret -Length 24
if (-not (Test-QuickTestSqlSecret -SecureValue $secret)) {
    throw 'Generated quick-test secret does not satisfy the policy.'
}

$ports = Get-QuickTestDefaultPorts
if (
    $ports[2019] -ne 14331 -or
    $ports[2022] -ne 14332 -or
    $ports[2025] -ne 14335
) {
    throw 'Quick-test default ports are not stable.'
}

$resolved = Resolve-QuickTestPorts `
    -SqlVersions @(2019, 2025) `
    -Ports @{ 2019 = 15431; 2025 = 15435 }
if ($resolved[2019] -ne 15431 -or $resolved[2025] -ne 15435) {
    throw 'Explicit quick-test ports were not preserved.'
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

$previousPath = $env:PATH
$emptyPath = Join-Path ([IO.Path]::GetTempPath()) 'qt-preflight-empty-path'
[IO.Directory]::CreateDirectory($emptyPath) | Out-Null
try {
    $env:PATH = $emptyPath
    $result = Invoke-QuickTestPreflight `
        -Runtime DOCKER `
        -SqlVersions @(2019, 2022) `
        -Ports @{ 2019 = 15441; 2022 = 15441 } `
        -ResourceProfile SMALL `
        -PersistenceMode TEMPORARY `
        -AdminLogin ExampleSqlAdmin `
        -AdminSecret $secret `
        -SecretSource GENERATED_EPHEMERAL `
        -AcceptEula `
        -SkipImageAvailabilityCheck

    if ($result.Status -ne 'PREFLIGHT_FAILED') {
        throw 'Missing runtime and duplicate ports did not fail Preflight.'
    }
    if (
        'RUNTIME_UNAVAILABLE' -notin @($result.BlockerReasonCodes) -or
        'PORT_CONFLICT' -notin @($result.BlockerReasonCodes)
    ) {
        throw 'Preflight did not preserve structured blocker reason codes.'
    }
    if ($result.MutationPerformed -ne $false) {
        throw 'Preflight reported a mutation.'
    }
    if ($result.SecretSource -ne 'GENERATED_EPHEMERAL') {
        throw 'Preflight did not preserve the secret source classification.'
    }
    if ($result.NextAction -ne 'INSTALL_LIFECYCLE_NOT_IMPLEMENTED') {
        throw 'Preflight does not expose the delivery boundary.'
    }
}
finally {
    $env:PATH = $previousPath
    Remove-Item -LiteralPath $emptyPath -Force -ErrorAction SilentlyContinue
}

Write-Output 'Docker/Podman quick-test Preflight contracts passed.'
