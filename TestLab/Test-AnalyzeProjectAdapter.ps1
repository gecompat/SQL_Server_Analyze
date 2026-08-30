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
$adapterRoot = Join-Path `
    $repositoryPath `
    'TestLab/Adapters/EXECUTION-PLAN-001'
$adapterPath = Join-Path $adapterRoot 'adapter.json'
$builderPath = Join-Path $adapterRoot 'Build-AdapterInstall.ps1'
$runnerPath = Join-Path `
    $repositoryPath `
    'TestLab/Invoke-AnalyzeAdapterQuickScenario.ps1'
$generatedInstallPath = Join-Path $adapterRoot 'sql/install.sql'

foreach ($path in @($adapterPath, $builderPath, $runnerPath, $generatedInstallPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Erforderliche ADP-004-Datei fehlt: $path"
    }
}

$adapter = Get-Content -LiteralPath $adapterPath -Raw -Encoding utf8 |
    ConvertFrom-Json -Depth 20
if ($adapter.adapterContractVersion -ne '0.1' -or
    $adapter.projectId -ne 'sql-server-analyze-execution-plan-001') {
    throw 'Der ADP-004-Adapter besitzt nicht die erwartete stabile Identität.'
}
if (@($adapter.supportedSqlVersions) -join ',' -ne '2019,2022,2025') {
    throw 'Der ADP-004-Adapter deklariert nicht die erwarteten SQL-Versionen.'
}

foreach ($property in @('preflight', 'install', 'update', 'validate', 'cleanup')) {
    $relativePath = [string]$adapter.entrypoints.$property
    if ([string]::IsNullOrWhiteSpace($relativePath) -or
        [IO.Path]::IsPathRooted($relativePath) -or
        ($relativePath -split '[\\/]') -contains '..') {
        throw "Adapter-Entrypoint '$property' verletzt die Pfadgrenze."
    }
    $entrypointPath = [IO.Path]::GetFullPath((Join-Path $adapterRoot $relativePath))
    if (-not $entrypointPath.StartsWith(
        [IO.Path]::GetFullPath($adapterRoot),
        [StringComparison]::OrdinalIgnoreCase
    ) -or -not (Test-Path -LiteralPath $entrypointPath -PathType Leaf)) {
        throw "Adapter-Entrypoint '$property' fehlt oder liegt außerhalb des Adapter-Roots."
    }
}

$parseErrors = @()
foreach ($path in @($builderPath, $runnerPath, $PSCommandPath)) {
    $null = [Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref]$null,
        [ref]$parseErrors
    )
}
if ($parseErrors.Count -gt 0) {
    throw "PowerShell-Parserfehler im ADP-004-Vertrag: $($parseErrors.Message -join '; ')"
}

$comparisonPath = Join-Path `
    ([IO.Path]::GetTempPath()) `
    ("sql-analyze-adapter-compare-{0}.sql" -f [guid]::NewGuid().ToString('N'))
try {
    & $builderPath `
        -RepositoryRoot $repositoryPath `
        -OutputPath $comparisonPath
    $committedHash = (Get-FileHash -LiteralPath $generatedInstallPath -Algorithm SHA256).Hash
    $expectedHash = (Get-FileHash -LiteralPath $comparisonPath -Algorithm SHA256).Hash
    if ($committedHash -ne $expectedHash) {
        throw 'Der versionierte Adapterinstaller weicht vom kanonisch erzeugten Inhalt ab.'
    }
}
finally {
    Remove-Item -LiteralPath $comparisonPath -Force -ErrorAction SilentlyContinue
}

$installText = [IO.File]::ReadAllText(
    $generatedInstallPath,
    [Text.Encoding]::UTF8
)
foreach ($fragment in @(
    'SQLANALYZE.AdapterProject',
    'CREATE DATABASE [LabAnalyze]',
    'monitor].[USP_ExecutionPlanAnalysis',
    'monitor].[USP_CreateExecutionEvidenceJson'
)) {
    if (-not $installText.Contains($fragment)) {
        throw "Der Adapterinstaller enthält den erforderlichen Vertrag nicht: $fragment"
    }
}
if ($installText.Contains('USE [DeineDatenbank]')) {
    throw 'Der ausführbare Adapterinstaller enthält noch den Installationsplatzhalter.'
}

if (-not [string]::IsNullOrWhiteSpace($LabRepositoryRoot)) {
    $labManifest = Join-Path $LabRepositoryRoot 'SqlServerLab.psd1'
    Import-Module $labManifest -Force
    $labValidation = Test-SqlServerLabAdapter -Path $adapterRoot
    if (-not $labValidation.IsReady) {
        throw "SQL_Server_Lab lehnt den Adapter ab: $($labValidation.Errors -join '; ')"
    }
}

[PSCustomObject]@{
    Status = 'PASS'
    WorkItem = 'ADP-004'
    AdapterProjectId = $adapter.projectId
    ContractVersion = $adapter.adapterContractVersion
    Entrypoints = 5
    GeneratedInstallBytes = (Get-Item -LiteralPath $generatedInstallPath).Length
}
