[CmdletBinding()]
param(
    [Parameter()]
    [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$schemaTests = @(
    @{
        Instance = 'Lab/Validation/Fixtures/Valid/lab-config.example.json'
        Schema = 'Lab/Contracts/lab-config.schema.json'
    }
    @{
        Instance = 'Lab/Config/host-capabilities.example.json'
        Schema = 'Lab/Contracts/host-capability.schema.json'
    }
    @{
        Instance = 'Lab/Validation/Fixtures/Valid/topology.example.json'
        Schema = 'Lab/Contracts/topology.schema.json'
    }
    @{
        Instance = 'Lab/Validation/Fixtures/Valid/scenario.example.json'
        Schema = 'Lab/Contracts/scenario.schema.json'
    }
    @{
        Instance = 'Lab/Validation/Fixtures/Valid/evidence.example.json'
        Schema = 'Lab/Contracts/evidence.schema.json'
    }
    @{
        Instance = 'Lab/Validation/Fixtures/Valid/finding-expectation.example.json'
        Schema = 'Lab/Contracts/finding-expectation.schema.json'
    }
)

foreach ($test in $schemaTests) {
    $instancePath = Join-Path $RepositoryRoot $test.Instance
    $schemaPath = Join-Path $RepositoryRoot $test.Schema
    $json = Get-Content -LiteralPath $instancePath -Raw -Encoding utf8
    $valid = Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction Stop
    if (-not $valid) {
        throw "LAB-001 JSON schema validation failed for $($test.Instance)."
    }
}

$topologySchemaPath = Join-Path $RepositoryRoot 'Lab/Contracts/topology.schema.json'
$topologyCatalogPath = Join-Path $RepositoryRoot 'Lab/Scenarios/Catalog/topologies.json'
$topologyCatalog = Get-Content -LiteralPath $topologyCatalogPath -Raw -Encoding utf8 |
    ConvertFrom-Json -Depth 100

foreach ($topology in $topologyCatalog.Topologies) {
    $topologyJson = $topology | ConvertTo-Json -Depth 100
    $valid = Test-Json -Json $topologyJson -SchemaFile $topologySchemaPath -ErrorAction Stop
    if (-not $valid) {
        throw 'LAB-001 topology catalog contains an invalid topology contract.'
    }
}

$pythonCommand = Get-Command python3 -ErrorAction SilentlyContinue
if ($null -eq $pythonCommand) {
    $pythonCommand = Get-Command python -ErrorAction Stop
}

$validatorPath = Join-Path $RepositoryRoot 'Code/Tests/Static/988_Validate_LAB001_Wave0_Contracts.py'
& $pythonCommand.Source $validatorPath --repository-root $RepositoryRoot
if ($LASTEXITCODE -ne 0) {
    throw "LAB-001 static contract validation failed with exit code $LASTEXITCODE."
}

$waveOneValidatorPath = Join-Path $RepositoryRoot (
    'Code/Tests/Static/989_Validate_LAB001_Wave1_Orchestrator.py'
)
& $pythonCommand.Source $waveOneValidatorPath --repository-root $RepositoryRoot
if ($LASTEXITCODE -ne 0) {
    throw "LAB-001 Welle 1 validation failed with exit code $LASTEXITCODE."
}

Write-Output 'LAB-001 PowerShell JSON-schema and static validation passed.'
