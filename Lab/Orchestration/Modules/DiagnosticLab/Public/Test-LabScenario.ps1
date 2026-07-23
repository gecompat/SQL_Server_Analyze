function Test-LabScenario {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $LabRunId,

        [Parameter(Mandatory)]
        [ValidateSet('LAB-BASE-001', 'LAB-BASE-002')]
        [string] $ScenarioId,

        [Parameter()]
        [string] $StateRoot = (Get-LabDefaultStateRoot)
    )

    $runDirectory = Get-LabRunDirectory -LabRunId $LabRunId -StateRoot $StateRoot
    $statePath = Join-Path $runDirectory 'run-state.json'
    $resultPath = Join-Path $runDirectory "scenario-$ScenarioId.json"
    $result = Read-LabJsonFile -Path $resultPath
    $expectedCode = if ($ScenarioId -eq 'LAB-BASE-001') {
        'BASELINE_OUTPUT_VALID'
    }
    else {
        'PERMISSION_BOUNDARY_OBSERVED'
    }
    $validationStatus = if (
        $result.ScenarioId -eq $ScenarioId -and
        $result.Status -eq 'PASS' -and
        $result.AnalyzerStatus -in @('AVAILABLE', 'AVAILABLE_LIMITED') -and
        $expectedCode -in @($result.FindingCodes)
    ) {
        'PASS'
    }
    else {
        'FAIL'
    }
    if ($validationStatus -ne 'PASS') {
        throw 'Scenario result does not satisfy its finding expectation.'
    }
    Set-LabRunState -StatePath $statePath -Changes @{
        LifecycleStatus = 'SCENARIO_VALIDATED'
        ScenarioId = $ScenarioId
        ValidationStatus = $validationStatus
    }
    return [pscustomobject] @{
        LabRunId = $LabRunId
        ScenarioId = $ScenarioId
        ValidationStatus = $validationStatus
        FindingCodes = @($result.FindingCodes)
    }
}
