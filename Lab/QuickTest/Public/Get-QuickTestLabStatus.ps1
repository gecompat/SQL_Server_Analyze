Set-StrictMode -Version Latest

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

    $scopeStateDirectory = [IO.Path]::GetFullPath(
        (Join-Path $StateRoot $ScopeName)
    )
    $statePath = Join-Path $scopeStateDirectory 'state.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        return [pscustomobject] @{
            Status = 'NOT_INSTALLED'
            ScopeName = $ScopeName
            Instances = @()
        }
    }

    $state = Read-QuickTestJson -Path $statePath
    if (-not (Test-QuickTestOwnedDirectory `
            -Path $state.StateDirectory `
            -Root $state.StateBaseRoot `
            -RunId $state.RunId)) {
        throw 'Status refused an unowned or out-of-bound state directory.'
    }

    $runtimeInfo = Resolve-QuickTestRuntime -Runtime $state.Runtime
    if (-not $runtimeInfo.IsAvailable) {
        return [pscustomobject] @{
            Status = 'RUNTIME_UNAVAILABLE'
            ScopeName = $ScopeName
            Runtime = $state.Runtime
            LifecycleStatus = $state.LifecycleStatus
            Instances = @()
        }
    }

    $instances = [Collections.Generic.List[object]]::new()
    foreach ($container in $state.Containers) {
        $runtimeState = 'missing|missing'
        $ownerValid = $false
        try {
            $runtimeState = [string] (
                Invoke-QuickTestExternalCommand `
                    -FilePath $runtimeInfo.Command `
                    -Arguments @(
                        'container'
                        'inspect'
                        '--format'
                        '{{.State.Status}}|{{.State.Health.Status}}'
                        [string] $container.ContainerId
                    ) |
                    Select-Object -First 1
            )
            $ownerValid = (
                Get-QuickTestObjectLabel `
                    -RuntimeInfo $runtimeInfo `
                    -ResourceType CONTAINER `
                    -ExactLocator ([string] $container.ContainerId) `
                    -LabelName 'qt-lab.run-id'
            ) -eq $state.RunId
        }
        catch {
            $runtimeState = 'missing|missing'
        }
        $parts = $runtimeState.Split('|')
        $runtimeStatus = $parts[0]
        $healthStatus = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        $instances.Add([pscustomobject] @{
                SqlVersion = [int] $container.SqlVersion
                ContainerId = [string] $container.ContainerId
                ContainerName = [string] $container.ContainerName
                Port = [int] $container.Port
                RuntimeStatus = $runtimeStatus
                HealthStatus = $healthStatus
                OwnershipValid = $ownerValid
                Ready = (
                    $runtimeStatus -eq 'running' -and
                    $healthStatus -eq 'healthy' -and
                    $ownerValid
                )
            })
    }

    $readyCount = @($instances | Where-Object { $_.Ready }).Count
    $overallStatus = if (
        $state.LifecycleStatus -eq 'READY' -and
        $instances.Count -gt 0 -and
        $readyCount -eq $instances.Count
    ) {
        'READY'
    }
    else {
        'PARTIAL_SUCCESS'
    }

    return [pscustomobject] @{
        Status = $overallStatus
        ScopeName = $ScopeName
        Runtime = $state.Runtime
        LifecycleStatus = $state.LifecycleStatus
        AdminLogin = $state.AdminLogin
        FrameworkDatabase = $state.FrameworkDatabase
        PersistenceMode = $state.PersistenceMode
        Instances = $instances.ToArray()
    }
}
