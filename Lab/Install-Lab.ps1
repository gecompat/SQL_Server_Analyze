[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('DOCKER', 'PODMAN')]
    [string] $Runtime,

    [Parameter()]
    [int[]] $SqlVersions,

    [Parameter()]
    [hashtable] $Ports = @{},

    [Parameter()]
    [ValidatePattern('^(sa|[A-Za-z][A-Za-z0-9_]{2,31})$')]
    [string] $AdminLogin,

    [Parameter()]
    [securestring] $AdminSecret,

    [Parameter()]
    [string] $SecretEnvironmentVariable = 'QTLAB_SQL_SECRET',

    [Parameter()]
    [switch] $GenerateSecret,

    [Parameter()]
    [ValidateSet('SMALL', 'MEDIUM', 'LARGE')]
    [string] $ResourceProfile = 'SMALL',

    [Parameter()]
    [ValidateSet('PERSISTENT', 'TEMPORARY')]
    [string] $PersistenceMode = 'TEMPORARY',

    [Parameter()]
    [switch] $InstallFramework,

    [Parameter()]
    [switch] $AcceptEula,

    [Parameter()]
    [switch] $NonInteractive,

    [Parameter()]
    [string] $DataRoot = (Join-Path $PSScriptRoot '.artifacts/quick-test'),

    [Parameter()]
    [switch] $SkipImageAvailabilityCheck
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'QuickTest/QuickTestPreflight.psm1'
Import-Module -Name $modulePath -Force -ErrorAction Stop

Invoke-QuickTestPreflightEntry @PSBoundParameters
