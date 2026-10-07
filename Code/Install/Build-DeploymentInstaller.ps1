[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    [string]$OutputPath,
    [switch]$IncludeSnapshotBaseline,
    [string]$PythonExecutable = 'python'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Join-Path $PSScriptRoot '../..'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $PSScriptRoot 'generated/Deploy_All.generated.sql'
}
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$generator = Join-Path $PSScriptRoot 'deployment_generator.py'
$arguments = @($generator, '--repository-root', $RepositoryRoot, '--output', $OutputPath)
if ($IncludeSnapshotBaseline) { $arguments += '--include-snapshot-baseline' }
& $PythonExecutable @arguments
if ($LASTEXITCODE -ne 0) { throw 'DEPLOYMENT_BUILD_FAILED: See the generator diagnostic.' }
