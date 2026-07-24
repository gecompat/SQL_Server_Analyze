Set-StrictMode -Version Latest

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

    $scopeStateDirectory = [IO.Path]::GetFullPath(
        (Join-Path $StateRoot $ScopeName)
    )
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
            'Destroy exact owned containers, network, state, and approved local data'
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
        throw 'Destroy refused an unowned or out-of-bound state directory.'
    }

    $runtimeInfo = Resolve-QuickTestRuntime -Runtime $state.Runtime
    if (-not $runtimeInfo.IsAvailable) {
        return [pscustomobject] @{
            Status = 'RUNTIME_UNAVAILABLE'
            ScopeName = $ScopeName
            Runtime = $state.Runtime
        }
    }

    $resources = Get-QuickTestResourcesByRunId `
        -RuntimeInfo $runtimeInfo `
        -RunId $state.RunId
    Remove-QuickTestRuntimeResources `
        -RuntimeInfo $runtimeInfo `
        -RunId $state.RunId `
        -ContainerIds $resources.ContainerIds `
        -NetworkIds $resources.NetworkIds

    $removeDataEffective = (
        $RemoveData -or
        $state.PersistenceMode -eq 'TEMPORARY'
    )
    if ($removeDataEffective -and (Test-Path -LiteralPath $state.DataRoot)) {
        if (-not (Test-QuickTestOwnedDirectory `
                -Path $state.DataRoot `
                -Root $state.DataBaseRoot `
                -RunId $state.RunId)) {
            throw 'Data cleanup refused an unowned or out-of-bound directory.'
        }
        Remove-Item -LiteralPath $state.DataRoot -Recurse -Force
    }

    if (
        $state.CredentialDirectory -and
        (Test-Path -LiteralPath $state.CredentialDirectory)
    ) {
        if (-not (Test-QuickTestOwnedDirectory `
                -Path $state.CredentialDirectory `
                -Root $state.CredentialBaseRoot `
                -RunId $state.RunId)) {
            throw 'Credential cleanup refused an unowned or out-of-bound directory.'
        }
        Remove-Item `
            -LiteralPath $state.CredentialDirectory `
            -Recurse `
            -Force
    }

    Remove-Item -LiteralPath $state.StateDirectory -Recurse -Force

    return [pscustomobject] @{
        Status = 'DESTROYED'
        ScopeName = $ScopeName
        DataRemoved = $removeDataEffective
        ContainersRemoved = $resources.ContainerIds.Count
        NetworksRemoved = $resources.NetworkIds.Count
    }
}
