function Get-QuickTestLabStatus {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidatePattern('^[a-z][a-z0-9-]{2,31}$')]
        [string] $ScopeName = 'sql-analyze-quicktest',

        [Parameter()]
        [string] $StateRoot = (Join-Path $script:QuickTestLabRoot '.state/quick-test')
    )

    $statePath = Join-Path (Join-Path $StateRoot $ScopeName) 'state.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        return [pscustomobject] @{
            Status = 'NOT_INSTALLED'
            ScopeName = $ScopeName
            Instances = @()
        }
    }
    $state = Read-QuickTestJson -Path $statePath
    $runtimeInfo = Resolve-QuickTestRuntime -Runtime $state.Runtime
    if (-not $runtimeInfo.IsAvailable) {
        return [pscustomobject] @{
            Status = 'RUNTIME_UNAVAILABLE'
            ScopeName = $ScopeName
            Runtime = $state.Runtime
            Instances = @()
        }
    }

    $instances = [Collections.Generic.List[object]]::new()
    foreach ($container in $state.Containers) {
        $runtimeState = 'missing|missing'
        $ownerValid = $false
        try {
            $runtimeState = [string] (
                Invoke-QuickTestCommand `
                    -FilePath $runtimeInfo.Command `
                    -Arguments @(
                        'container'
                        'inspect'
                        '--format'
                        '{{.State.Status}}|{{.State.Health.Status}}'
                        $container.ContainerId
                    ) |
                    Select-Object -First 1
            )
            $ownerValid = (
                Get-QuickTestObjectLabel `
                    -RuntimeInfo $runtimeInfo `
                    -ResourceType CONTAINER `
                    -ExactLocator $container.ContainerId `
                    -LabelName 'qt-lab.run-id'
            ) -eq $state.RunId
        }
        catch {
            $runtimeState = 'missing|missing'
        }
        $parts = $runtimeState.Split('|')
        $instances.Add([pscustomobject] @{
                SqlVersion = [int] $container.SqlVersion
                ContainerId = [string] $container.ContainerId
                ContainerName = [string] $container.ContainerName
                Port = [int] $container.Port
                RuntimeStatus = $parts[0]
                HealthStatus = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                OwnershipValid = $ownerValid
                Ready = (
                    $parts[0] -eq 'running' -and
                    $parts.Count -gt 1 -and
                    $parts[1] -eq 'healthy' -and
                    $ownerValid
                )
            })
    }
    $readyCount = @($instances | Where-Object { $_.Ready }).Count
    return [pscustomobject] @{
        Status = if ($readyCount -eq $instances.Count) { 'READY' } else { 'PARTIAL_SUCCESS' }
        ScopeName = $ScopeName
        Runtime = $state.Runtime
        AdminLogin = $state.AdminLogin
        FrameworkDatabase = $state.FrameworkDatabase
        Instances = $instances.ToArray()
    }
}
