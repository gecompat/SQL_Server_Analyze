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

Remove-QuickTestLab `
    -ScopeName $ScopeName `
    -RemoveData:$RemoveData `
    -Confirm:$false `
    -WhatIf:$WhatIfPreference
