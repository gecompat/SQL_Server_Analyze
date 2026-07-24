[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^[a-z][a-z0-9-]{2,31}$')]
    [string] $ScopeName = 'sql-analyze-quicktest',

    [Parameter()]
    [string] $StateRoot = (Join-Path $PSScriptRoot '.state/quick-test'),

    [Parameter()]
    [switch] $RemoveData,

    [Parameter()]
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'QuickTest/QuickTestLab.psm1'
Import-Module -Name $modulePath -Force -ErrorAction Stop

$arguments = @{
    ScopeName = $ScopeName
    StateRoot = $StateRoot
    RemoveData = $RemoveData
}
if ($Force) {
    $arguments.Confirm = $false
}
else {
    $arguments.Confirm = $true
}

Remove-QuickTestLab @arguments
