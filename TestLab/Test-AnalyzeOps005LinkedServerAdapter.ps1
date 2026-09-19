[CmdletBinding()]
param(
    [string] $RepositoryRoot = (
        Resolve-Path (Join-Path $PSScriptRoot '..')
    ).Path,

    [string] $LabRepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$adapterRoot = Join-Path $repositoryPath 'TestLab/Adapters/OPS-005'
$adapterPath = Join-Path $adapterRoot 'adapter.json'
$builderPath = Join-Path $adapterRoot 'Build-AdapterInstall.ps1'
$runnerPath = Join-Path $repositoryPath 'TestLab/Invoke-AnalyzeOps005LinkedServerMatrix.ps1'
$generatedInstallPath = Join-Path $adapterRoot 'sql/install.sql'
$generatedUpdatePath = Join-Path $adapterRoot 'sql/update.sql'

foreach ($path in @($adapterPath, $builderPath, $runnerPath, $generatedInstallPath, $generatedUpdatePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Erforderliche OPS-005-Adapterdatei fehlt: $path"
    }
}

$adapter = Get-Content -LiteralPath $adapterPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 20
if ($adapter.adapterContractVersion -ne '0.1' -or
    $adapter.projectId -ne 'sql-server-analyze-ops-005-linked-server') {
    throw 'Der OPS-005-Adapter besitzt nicht die erwartete stabile Identität.'
}
if (@($adapter.supportedSqlVersions) -join ',' -ne '2019,2022,2025') {
    throw 'Der OPS-005-Adapter deklariert nicht die erwartete native Versionsmatrix.'
}
if (@($adapter.secretInputs).Count -ne 0 -or $adapter.privacyExportPolicy -ne 'SANITIZED_SUMMARY_ONLY') {
    throw 'Der OPS-005-Adapter darf keine Secret-Eingaben oder unbereinigte Exporte deklarieren.'
}

foreach ($property in @('preflight', 'install', 'update', 'validate', 'cleanup')) {
    $relativePath = [string]$adapter.entrypoints.$property
    if ([string]::IsNullOrWhiteSpace($relativePath) -or
        [IO.Path]::IsPathRooted($relativePath) -or
        ($relativePath -split '[\\/]') -contains '..') {
        throw "Adapter-Entrypoint '$property' verletzt die Pfadgrenze."
    }
    $entrypointPath = [IO.Path]::GetFullPath((Join-Path $adapterRoot $relativePath))
    if (-not $entrypointPath.StartsWith([IO.Path]::GetFullPath($adapterRoot), [StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $entrypointPath -PathType Leaf)) {
        throw "Adapter-Entrypoint '$property' fehlt oder liegt außerhalb des Adapter-Roots."
    }
}

$parseErrors = @()
foreach ($path in @($builderPath, $runnerPath, $PSCommandPath)) {
    $null = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$parseErrors)
}
if ($parseErrors.Count -gt 0) {
    throw "PowerShell-Parserfehler im OPS-005-Adapter: $($parseErrors.Message -join '; ')"
}

$comparisonDirectory = Join-Path ([IO.Path]::GetTempPath()) ("sql-analyze-ops005-{0}" -f [guid]::NewGuid().ToString('N'))
try {
    $comparisonInstall = Join-Path $comparisonDirectory 'install.sql'
    $comparisonUpdate = Join-Path $comparisonDirectory 'update.sql'
    & $builderPath -RepositoryRoot $repositoryPath -InstallOutputPath $comparisonInstall -UpdateOutputPath $comparisonUpdate
    foreach ($comparison in @(
            @{ Committed = $generatedInstallPath; Expected = $comparisonInstall; Name = 'Installer' },
            @{ Committed = $generatedUpdatePath; Expected = $comparisonUpdate; Name = 'Runtimevertrag' }
        )) {
        if ((Get-FileHash -LiteralPath $comparison.Committed -Algorithm SHA256).Hash -ne
            (Get-FileHash -LiteralPath $comparison.Expected -Algorithm SHA256).Hash) {
            throw "Der versionierte OPS-005-$($comparison.Name) weicht vom kanonisch erzeugten Inhalt ab."
        }
    }
}
finally {
    Remove-Item -LiteralPath $comparisonDirectory -Recurse -Force -ErrorAction SilentlyContinue
}

$installText = [IO.File]::ReadAllText($generatedInstallPath, [Text.Encoding]::UTF8)
$updateText = [IO.File]::ReadAllText($generatedUpdatePath, [Text.Encoding]::UTF8)
$validateText = [IO.File]::ReadAllText((Join-Path $adapterRoot 'sql/validate.sql'), [Text.Encoding]::UTF8)
$cleanupText = [IO.File]::ReadAllText((Join-Path $adapterRoot 'sql/cleanup.sql'), [Text.Encoding]::UTF8)
foreach ($fragment in @(
        'DeineDatenbank',
        'monitor].[USP_LinkedServerAnalysis',
        'SQLANALYZE.AdapterProject',
        'ADAPTER_ISOLATION_REQUIRED'
    )) {
    if (-not $installText.Contains($fragment)) {
        throw "Der OPS-005-Installer enthält den erforderlichen Vertrag nicht: $fragment"
    }
}
foreach ($fragment in @(
        '120_OPS005_Linked_Server_Runtime_Contract.sql',
        'ExampleOps005TimeoutLinked',
        'ExampleOps005RestrictedLogin',
        'SQLANALYZE.Ops005RuntimeContract'
    )) {
    if (-not $updateText.Contains($fragment)) {
        throw "Der OPS-005-Runtimevertrag enthält den erforderlichen Nachweis nicht: $fragment"
    }
}
if (-not $updateText.Contains('[DeineDatenbank]') -or
    $validateText.Contains('ExampleOps005Linked') -and -not $validateText.Contains('PROJECT_ASSERTION_FAILED') -or
    -not $cleanupText.Contains('PROJECT_CLEANUP_FAILED')) {
    throw 'Der OPS-005-Adapter verletzt den Datenbankplatzhalter- oder Cleanupvertrag.'
}

if (-not [string]::IsNullOrWhiteSpace($LabRepositoryRoot)) {
    $labManifest = Join-Path $LabRepositoryRoot 'SqlServerLab.psd1'
    Import-Module $labManifest -Force
    $labValidation = Test-SqlServerLabAdapter -Path $adapterRoot
    if (-not $labValidation.IsReady) {
        throw "SQL_Server_Lab lehnt den OPS-005-Adapter ab: $($labValidation.Errors -join '; ')"
    }
}

[PSCustomObject]@{
    Status = 'PASS'
    WorkItem = 'OPS-005'
    AdapterProjectId = $adapter.projectId
    ContractVersion = $adapter.adapterContractVersion
    Entrypoints = 5
    GeneratedInstallBytes = (Get-Item -LiteralPath $generatedInstallPath).Length
}
