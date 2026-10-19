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

function Read-CanonicalSqlText {
    param([Parameter(Mandatory)][string] $Path)

    # Nur die Git-Textdarstellung CRLF/LF ist gleichwertig; andere Bytes bleiben relevant.
    $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
    return $strictUtf8.GetString([IO.File]::ReadAllBytes($Path)).Replace("`r`n", "`n")
}

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
$comparisonDirectory = [IO.Path]::GetFullPath($comparisonDirectory)
$comparisonParent = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath([IO.Path]::GetTempPath()))
if (-not [string]::Equals([IO.Path]::GetDirectoryName($comparisonDirectory), $comparisonParent, [StringComparison]::Ordinal)) {
    throw 'Das OPS-005-Vergleichsverzeichnis muss direkt im temporaeren Verzeichnis liegen.'
}
try {
    $comparisonInstall = Join-Path $comparisonDirectory 'install.sql'
    $comparisonUpdate = Join-Path $comparisonDirectory 'update.sql'
    & $builderPath -RepositoryRoot $repositoryPath -InstallOutputPath $comparisonInstall -UpdateOutputPath $comparisonUpdate

    $syntheticSql = "USE [ExampleDatabase];`nGO`nSELECT N'Example';`n"
    $representationCases = @(
        @{ Name = 'LF'; Content = $syntheticSql; Equal = $true },
        @{ Name = 'CRLF'; Content = $syntheticSql.Replace("`n", "`r`n"); Equal = $true },
        @{ Name = 'Content'; Content = $syntheticSql.Replace("N'Example'", "N'Changed'"); Equal = $false },
        @{ Name = 'Case'; Content = $syntheticSql.Replace("N'Example'", "N'EXAMPLE'"); Equal = $false },
        @{ Name = 'LoneCR'; Content = $syntheticSql.Replace("`n", "`r"); Equal = $false },
        @{ Name = 'FinalNewline'; Content = $syntheticSql.TrimEnd("`n"); Equal = $false },
        @{ Name = 'BOM'; Content = ([string][char]0xfeff) + $syntheticSql; Equal = $false }
    )
    $representationPath = Join-Path $comparisonDirectory 'representation.sql'
    foreach ($case in $representationCases) {
        [IO.File]::WriteAllText($representationPath, $case.Content, [Text.UTF8Encoding]::new($false))
        $equal = [string]::Equals((Read-CanonicalSqlText -Path $representationPath), $syntheticSql, [StringComparison]::Ordinal)
        if ($equal -ne $case.Equal) {
            throw "Der OPS-005-Textvergleich verletzt den synthetischen Vertrag '$($case.Name)'."
        }
    }
    [IO.File]::WriteAllBytes($representationPath, [byte[]]@(0xff))
    $invalidUtf8Rejected = $false
    try { $null = Read-CanonicalSqlText -Path $representationPath }
    catch [Text.DecoderFallbackException] { $invalidUtf8Rejected = $true }
    if (-not $invalidUtf8Rejected) {
        throw 'Der OPS-005-Textvergleich muss ungültiges UTF-8 ablehnen.'
    }

    foreach ($comparison in @(
            @{ Committed = $generatedInstallPath; Expected = $comparisonInstall; Name = 'Installer' },
            @{ Committed = $generatedUpdatePath; Expected = $comparisonUpdate; Name = 'Runtimevertrag' }
        )) {
        $committedText = Read-CanonicalSqlText -Path $comparison.Committed
        $expectedText = Read-CanonicalSqlText -Path $comparison.Expected
        if (-not [string]::Equals($committedText, $expectedText, [StringComparison]::Ordinal)) {
            throw "Der versionierte OPS-005-$($comparison.Name) weicht vom kanonisch erzeugten Inhalt ab."
        }
    }
}
finally {
    Remove-Item -LiteralPath $comparisonDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
if (Test-Path -LiteralPath $comparisonDirectory) {
    throw 'Das eigene OPS-005-Vergleichsverzeichnis wurde nicht entfernt.'
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
    RepresentationCases = $representationCases.Count + 1
    GeneratedInstallBytes = (Get-Item -LiteralPath $generatedInstallPath).Length
}
