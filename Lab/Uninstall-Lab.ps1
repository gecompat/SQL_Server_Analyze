[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidatePattern('^[a-z][a-z0-9-]{2,31}$')]
    [string] $ScopeName = 'sql-analyze-quicktest',

    [Parameter()]
    [switch] $RemoveData
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'QuickTest/QuickTestLab.psm1'
Import-Module -Name $modulePath -Force -ErrorAction Stop

if (-not $PSCmdlet.ShouldProcess(
        "quick-test scope $ScopeName",
        'Destroy exact registered containers, network, and approved local scope'
    )) {
    [pscustomobject] @{
        Status = if ($WhatIfPreference) {
            'WHATIF'
        }
        else {
            'DESTROY_CONFIRMATION_REQUIRED'
        }
        ScopeName = $ScopeName
    }
    return
}

Remove-QuickTestLab `
    -ScopeName $ScopeName `
    -RemoveData:$RemoveData `
    -Confirm:$false
