function Invoke-LabScenario {
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
    $registryPath = Join-Path $runDirectory 'resource-registry.json'
    $state = Read-LabJsonFile -Path $statePath
    if ($state.LifecycleStatus -notin @(
            'TOPOLOGY_READY',
            'SCENARIO_COMPLETED',
            'SCENARIO_VALIDATED'
        )) {
        throw 'Scenario execution requires a ready CTR-SINGLE topology.'
    }

    $registry = Read-LabJsonFile -Path $registryPath
    $container = @($registry.Resources) |
        Where-Object {
            $_.Provider -eq 'DOCKER' -and
            $_.ResourceType -eq 'CONTAINER' -and
            $_.ResourceId -eq 'SQL_CONTAINER'
        } |
        Select-Object -First 1
    if ($null -eq $container) {
        throw 'The registered SQL container is missing.'
    }

    $scenarioDefinition = Get-Content `
        -LiteralPath (Get-LabScenarioDefinitionPath -ScenarioId $ScenarioId) `
        -Raw `
        -Encoding utf8 |
        ConvertFrom-Json -Depth 100
    if (
        $scenarioDefinition.TopologyId -ne 'CTR-SINGLE' -or
        $scenarioDefinition.ResourceProfile -ne 'Compact' -or
        2025 -notin @($scenarioDefinition.SqlVersions)
    ) {
        throw 'Scenario definition is outside the Welle 2 runtime boundary.'
    }

    $runtimeScenarioDirectory = Join-Path $runDirectory 'runtime/scenarios'
    [IO.Directory]::CreateDirectory($runtimeScenarioDirectory) | Out-Null
    $runtimeSqlPath = Join-Path $runtimeScenarioDirectory "$ScenarioId.sql"
    [IO.File]::Copy(
        (Get-LabScenarioSqlPath -ScenarioId $ScenarioId),
        $runtimeSqlPath,
        $true
    )
    $output = Invoke-LabSqlFile `
        -DockerCommand (Get-LabDockerCommand) `
        -ContainerId $container.ExactLocator `
        -ContainerSqlPath "/lab/runtime/scenarios/$ScenarioId.sql"
    $result = Write-LabScenarioResult `
        -RunDirectory $runDirectory `
        -ScenarioId $ScenarioId `
        -CommandOutput $output
    Set-LabRunState -StatePath $statePath -Changes @{
        LifecycleStatus = 'SCENARIO_COMPLETED'
        ScenarioId = $ScenarioId
        ScenarioStatus = $result.Status
    }
    return $result
}
