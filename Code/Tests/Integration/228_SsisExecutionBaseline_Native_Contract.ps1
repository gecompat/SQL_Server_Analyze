[CmdletBinding()]
param(
 [Parameter(Mandatory)][guid]$RunId,[string]$InstanceId='primary',
 [Parameter(Mandatory)][string]$LabModulePath,[Parameter(Mandatory)][string]$FixtureBuilderPath,
 [Parameter(Mandatory)][string]$ProducerAssemblyPath,[Parameter(Mandatory)][string]$ExpectedSourceCommit,
 [Parameter(Mandatory)][string]$ExpectedBuildSha256,[Parameter(Mandatory)][string]$NativeBudgetPath,
 [ValidateSet('Full','ContextRecovery')][string]$AcceptanceScope='Full'
)
# Dieselbe SDK-Fixture und derselbe nachgewiesene Cleanup wie beim Paarvergleich.
# Die fünf Basisausführungen und sechs Kandidaten zählen einzeln im Callerbudget.
$forward=@{};foreach($key in $PSBoundParameters.Keys){if($key -cne 'AcceptanceScope'){$forward[$key]=$PSBoundParameters[$key]}}
$scenarios=if($AcceptanceScope -ceq 'ContextRecovery'){@('Baseline','Baseline2','Baseline3','Baseline4','Baseline5','Logging','Error','Abort')}else{@('Baseline','Baseline2','Baseline3','Baseline4','Baseline5','Equal','Delay','Volume','Logging','Error','Abort')}
& (Join-Path $PSScriptRoot '226_SsisExecutionComparison_Native_Contract.ps1') @forward -IncludeBaselineContract -Scenarios $scenarios
