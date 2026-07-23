[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Preflight', 'Status', 'Down', 'RecoveryCleanup')]
    [string] $Action,

    [Parameter()]
    [ValidatePattern('^LAB-[0-9]{8}T[0-9]{6}Z-[0-9A-F]{8}$')]
    [string] $LabRunId,

    [Parameter()]
    [ValidateSet('AUTO', 'WINDOWS_SINGLE_HOST', 'LINUX_NATIVE', 'DISTRIBUTED')]
    [string] $ExecutionMode,

    [Parameter()]
    [string] $ConfigPath,

    [Parameter()]
    [switch] $AllowRemoteExecution
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'Modules/DiagnosticLab/DiagnosticLab.psd1'
Import-Module -Name $modulePath -Force -ErrorAction Stop

switch ($Action) {
    'Preflight' {
        $arguments = @{
            AllowRemoteExecution = $AllowRemoteExecution
        }
        if ($PSBoundParameters.ContainsKey('LabRunId')) {
            $arguments.LabRunId = $LabRunId
        }
        if ($PSBoundParameters.ContainsKey('ExecutionMode')) {
            $arguments.ExecutionMode = $ExecutionMode
        }
        if ($PSBoundParameters.ContainsKey('ConfigPath')) {
            $arguments.ConfigPath = $ConfigPath
        }

        if ($WhatIfPreference) {
            [pscustomobject] @{
                Action = 'Preflight'
                Status = 'WHATIF'
                MutationBoundary = 'LOCAL_IGNORED_STATE_ONLY'
            }
        }
        else {
            Invoke-LabPreflight @arguments
        }
        break
    }

    'Status' {
        if (-not $PSBoundParameters.ContainsKey('LabRunId')) {
            throw 'Status requires -LabRunId.'
        }
        Get-LabStatus -LabRunId $LabRunId
        break
    }

    { $_ -in @('Down', 'RecoveryCleanup') } {
        if (-not $PSBoundParameters.ContainsKey('LabRunId')) {
            throw "$Action requires -LabRunId."
        }

        if ($PSCmdlet.ShouldProcess(
                "registered resources owned by $LabRunId",
                $Action
            )) {
            Invoke-LabCleanup `
                -LabRunId $LabRunId `
                -Recovery:($Action -eq 'RecoveryCleanup') `
                -Confirm:$false
        }
        break
    }
}
