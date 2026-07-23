function Get-LabScenarioDefinitionPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('LAB-BASE-001', 'LAB-BASE-002')]
        [string] $ScenarioId
    )

    return Join-Path (
        $script:DiagnosticLabRoot
    ) "Scenarios/Core/$ScenarioId/scenario.json"
}

function Get-LabScenarioSqlPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('LAB-BASE-001', 'LAB-BASE-002')]
        [string] $ScenarioId
    )

    return Join-Path (
        $script:DiagnosticLabRoot
    ) "Scenarios/Core/$ScenarioId/scenario.sql"
}

function Write-LabScenarioResult {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $RunDirectory,

        [Parameter(Mandatory)]
        [ValidateSet('LAB-BASE-001', 'LAB-BASE-002')]
        [string] $ScenarioId,

        [Parameter(Mandatory)]
        [string[]] $CommandOutput
    )

    $prefix = 'LAB_ASSERTION_JSON='
    $line = $CommandOutput |
        Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) } |
        Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw 'Scenario output did not contain its assertion envelope.'
    }
    $result = $line.Substring($prefix.Length) | ConvertFrom-Json -Depth 20
    if ($result.ScenarioId -ne $ScenarioId -or $result.Status -ne 'PASS') {
        throw 'Scenario assertion envelope is invalid.'
    }
    $resultPath = Join-Path $RunDirectory "scenario-$ScenarioId.json"
    Write-LabJsonFile -Path $resultPath -InputObject ([ordered] @{
            SchemaVersion = '1.0'
            DataClassification = 'LOCAL_RUNTIME_STATE'
            ScenarioId = $result.ScenarioId
            Status = $result.Status
            AnalyzerStatus = $result.AnalyzerStatus
            FindingCodes = @($result.FindingCodes)
            CompletedAtUtc = [DateTime]::UtcNow.ToString('o')
        })
    return Read-LabJsonFile -Path $resultPath
}
