function Remove-QuickTestLab {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidatePattern('^[a-z][a-z0-9-]{2,31}$')]
        [string] $ScopeName = 'sql-analyze-quicktest',

        [Parameter()]
        [string] $StateRoot = (Join-Path $script:QuickTestLabRoot '.state/quick-test'),

        [Parameter()]
        [switch] $RemoveData
    )

    $scopeStateDirectory = Join-Path $StateRoot $ScopeName
    $statePath = Join-Path $scopeStateDirectory 'state.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
        return [pscustomobject] @{
            Status = 'NOT_INSTALLED'
            ScopeName = $ScopeName
        }
    }
    $state = Read-QuickTestJson -Path $statePath
    if (-not $PSCmdlet.ShouldProcess(
            "quick-test scope $ScopeName",
            'Destroy exact registered containers, network, state, and approved data'
        )) {
        return [pscustomobject] @{
            Status = 'DESTROY_CONFIRMATION_REQUIRED'
            ScopeName = $ScopeName
        }
    }
    if (-not (Test-QuickTestOwnedDirectory `
            -Path $state.StateDirectory `
            -Root $state.StateBaseRoot `
            -RunId $state.RunId)) {
        throw 'State cleanup refused an unowned or out-of-bound directory.'
    }

    $runtimeInfo = Resolve-QuickTestRuntime -Runtime $state.Runtime
    if (-not $runtimeInfo.IsAvailable) {
        return [pscustomobject] @{
            Status = 'RUNTIME_UNAVAILABLE'
            ScopeName = $ScopeName
        }
    }

    $existingContainers = [Collections.Generic.List[string]]::new()
    foreach ($container in $state.Containers) {
        try {
            $owner = Get-QuickTestObjectLabel `
                -RuntimeInfo $runtimeInfo `
                -ResourceType CONTAINER `
                -ExactLocator $container.ContainerId `
                -LabelName 'qt-lab.run-id'
            if ($owner -ne $state.RunId) {
                throw 'Container ownership does not match the saved quick-test state.'
            }
            $existingContainers.Add([string] $container.ContainerId)
        }
        catch {
            if ($_.Exception.Message -match 'ownership') {
                throw
            }
        }
    }

    $existingNetworks = [Collections.Generic.List[string]]::new()
    if ($state.NetworkId) {
        try {
            $owner = Get-QuickTestObjectLabel `
                -RuntimeInfo $runtimeInfo `
                -ResourceType NETWORK `
                -ExactLocator $state.NetworkId `
                -LabelName 'qt-lab.run-id'
            if ($owner -ne $state.RunId) {
                throw 'Network ownership does not match the saved quick-test state.'
            }
            $existingNetworks.Add([string] $state.NetworkId)
        }
        catch {
            if ($_.Exception.Message -match 'ownership') {
                throw
            }
        }
    }

    Remove-QuickTestRuntimeResources `
        -RuntimeInfo $runtimeInfo `
        -RunId $state.RunId `
        -ContainerIds $existingContainers.ToArray() `
        -NetworkIds $existingNetworks.ToArray()

    $removeDataEffective = $RemoveData -or $state.PersistenceMode -eq 'TEMPORARY'
    if ($removeDataEffective -and (Test-Path -LiteralPath $state.DataRoot)) {
        if (-not (Test-QuickTestOwnedDirectory `
                -Path $state.DataRoot `
                -Root $state.DataBaseRoot `
                -RunId $state.RunId)) {
            throw 'Data cleanup refused an unowned or out-of-bound directory.'
        }
        Remove-Item -LiteralPath $state.DataRoot -Recurse -Force
    }
    if ($state.SecretDirectory -and (Test-Path -LiteralPath $state.SecretDirectory)) {
        if (-not (Test-QuickTestOwnedDirectory `
                -Path $state.SecretDirectory `
                -Root $state.SecretBaseRoot `
                -RunId $state.RunId)) {
            throw 'Secret cleanup refused an unowned or out-of-bound directory.'
        }
        Remove-Item -LiteralPath $state.SecretDirectory -Recurse -Force
    }
    Remove-Item -LiteralPath $state.StateDirectory -Recurse -Force

    return [pscustomobject] @{
        Status = 'DESTROYED'
        ScopeName = $ScopeName
        DataRemoved = $removeDataEffective
    }
}
