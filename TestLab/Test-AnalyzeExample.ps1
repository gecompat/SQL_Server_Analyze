[CmdletBinding()]
param(
    [switch] $RunRuntime,

    [ValidatePattern('^[A-Z][A-Z0-9-]{2,39}$')]
    [string] $Example = 'BLOCKING-001',

    [ValidateSet('2019', '2022', '2025')]
    [string] $Version = '2022',

    [ValidateSet('docker', 'podman')]
    [string] $Provider = 'docker',

    [string] $StateRoot,

    [string] $LabRepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$catalogPath = Join-Path $PSScriptRoot 'Catalog/examples.json'
$schemaPath = Join-Path $PSScriptRoot 'Schemas/analyze-example.schema.json'
$catalogText = Get-Content -LiteralPath $catalogPath -Raw -Encoding utf8
$schemaText = Get-Content -LiteralPath $schemaPath -Raw -Encoding utf8
if (-not (Test-Json -Json $catalogText -Schema $schemaText)) {
    throw 'Der Analyze-Beispielkatalog entspricht nicht dem JSON-Schema.'
}

$catalog = $catalogText | ConvertFrom-Json -Depth 20
$duplicateIds = @($catalog.examples | Group-Object id | Where-Object Count -gt 1)
if ($duplicateIds.Count -gt 0) {
    throw 'Der Analyze-Beispielkatalog enthält doppelte IDs.'
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
foreach ($definition in $catalog.examples) {
    $scenarioRoot = Join-Path `
        $repositoryRoot `
        "Lab/Scenarios/Performance/$($definition.scenarioId)"
    foreach ($name in @('scenario.json', 'runbook.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $scenarioRoot $name) -PathType Leaf)) {
            throw "Kanonischer Szenariovertrag fehlt: $($definition.scenarioId)/$name"
        }
    }
    $runbook = Get-Content `
        -LiteralPath (Join-Path $scenarioRoot 'runbook.json') `
        -Raw `
        -Encoding utf8 | ConvertFrom-Json -Depth 20
    if (
        $runbook.PrimaryAnalyzer -ne $definition.primaryAnalyzer -or
        $runbook.FindingCode -ne $definition.findingCode -or
        [int]$runbook.WorkerCount -ne [int]$definition.workerCount
    ) {
        throw "Katalog und Runbook sind für $($definition.id) inkonsistent."
    }

    $documentationDirectory = if ($definition.id -eq 'BLOCKING-001') {
        Join-Path $PSScriptRoot 'Examples/Blocking'
    }
    else {
        Join-Path $PSScriptRoot "Examples/$($definition.id)"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $documentationDirectory 'README.md') -PathType Leaf)) {
        throw "Bedienseite fehlt für Analyze-Beispiel $($definition.id)."
    }
}

Write-Host "Analyze-Beispielkatalog erfolgreich validiert: $($catalog.examples.Count) Beispiel(e)."

if ($RunRuntime) {
    & (Join-Path $PSScriptRoot 'Start-AnalyzeExample.ps1') `
        -Example $Example `
        -Version $Version `
        -Provider $Provider `
        -Mode Verify `
        -StateRoot $StateRoot `
        -LabRepositoryRoot $LabRepositoryRoot
}
