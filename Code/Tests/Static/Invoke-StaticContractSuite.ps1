[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')),
    [switch]$IncludeNetwork
)

$ErrorActionPreference = 'Stop'
$repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$pythonCommand = if ($IsWindows -and (Get-Command python -ErrorAction SilentlyContinue)) {
    'python'
}
elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    'python3'
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    'python'
}
else {
    throw 'Python 3 wurde nicht gefunden.'
}

$selfTestValidators = @(
    '905_Validate_Analysis_Navigator.py'
    '910_Validate_Repository_Privacy.py'
    '915_Validate_Documentation_Style.py'
    '920_Validate_SQL_Server_2025_Regex.py'
    '925_Select_CI_Impact.py'
    '940_Validate_Wait_Type_Catalog.py'
    '975_Validate_Roadmap_Status.py'
    '976_Validate_Maturity_Closeout_Contracts.py'
    '977_Validate_Diagnostic_Coverage_Landscape.py'
    '989_Validate_SQL25_Readable_Secondary_Statistics_Contract.py'
    '991_Validate_SQL25_TempDB_Resource_Governance_Contract.py'
    '992_Validate_SQL25_JSON_Index_Contract.py'
    '993_Validate_Partial_Implementation_Status_and_CurrentState_Snapshot.py'
    '994_Validate_SQL25_Vector_Index_Contract.py'
    '995_Validate_Wave1_Contracts.py'
    '996_Validate_Wave2_Contracts.py'
    '997_Validate_ExecutionPlanAnalysis_Public_Contract.py'
    '998_Validate_SnapshotBaseline_Public_Contract.py'
    '999_Validate_Runtime001_Contracts.py'
    '1000_Validate_Audit_Configuration_Contract.py'
    '1001_Validate_ExtendedEvents_BlockedProcess_Collation.py'
    '1002_Validate_ExtendedEvents_Deadlocks_Collation.py'
    '1003_Validate_DatabaseCandidates_Dynamic_Parameters.py'
    '1004_Validate_ResultTable_Json_Collation.py'
    '1005_Validate_QueryStoreHints_Tempdb_Collation.py'
    '1006_Validate_LogShipping_Tempdb_Collation.py'
    '1007_Validate_Replication_Tempdb_Collation.py'
    '1008_Validate_ServerConfiguration_Tempdb_Collation.py'
    '1009_Validate_AvailabilityGroups_Tempdb_Collation.py'
    '1010_Validate_ServerCpuTopology_Tempdb_Collation.py'
    '1011_Validate_ServerNuma_Tempdb_Collation.py'
    '1012_Validate_ServerMemory_Tempdb_Collation.py'
    '1013_Validate_TempDBConfiguration_Tempdb_Collation.py'
    '1014_Validate_StartupParameters_Tempdb_Collation.py'
    '1015_Validate_CurrentTransactions_Tempdb_Collation.py'
    '1016_Validate_OSInformation_Tempdb_Collation.py'
    '1017_Validate_PlanCacheHealth_Tempdb_Collation.py'
    '1018_Validate_CurrentWaits_Tempdb_Collation.py'
    '1019_Validate_QueryStoreWaitStats_Tempdb_Collation.py'
    '1020_Validate_QueryStorePlanChanges_Tempdb_Collation.py'
    '1021_Validate_QueryStoreRegressions_Tempdb_Collation.py'
    '1022_Validate_QueryStoreForcedPlans_Tempdb_Collation.py'
    '1023_Validate_QueryStoreRuntimeStats_Tempdb_Collation.py'
    '1024_Validate_QueryStoreStatus_Tempdb_Collation.py'
  )
$repositoryOnlyValidators = @(
    '950_Validate_Nonblocking_Metadata.py'
    '960_Validate_Complete_P1_Evidence.py'
    '970_Validate_Complete_P2_Evidence.py'
    '990_Validate_Release_Evidence.py'
)

$failures = [Collections.Generic.List[string]]::new()
Push-Location -LiteralPath $repositoryPath
try {
    foreach ($validator in $selfTestValidators) {
        $path = Join-Path 'Code/Tests/Static' $validator
        & $pythonCommand $path --repository-root . --self-test
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("$validator self-test")
            continue
        }
        if ($validator -eq '925_Select_CI_Impact.py') {
            continue
        }
        & $pythonCommand $path --repository-root .
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("$validator repository")
        }
    }

    foreach ($validator in $repositoryOnlyValidators) {
        $path = Join-Path 'Code/Tests/Static' $validator
        & $pythonCommand $path --repository-root .
        if ($LASTEXITCODE -ne 0) {
            $failures.Add("$validator repository")
        }
    }

    & pwsh -NoLogo -NoProfile -File ./Code/Tests/Static/900_Validate_Analysis_Documentation.ps1
    if ($LASTEXITCODE -ne 0) {
        $failures.Add('900_Validate_Analysis_Documentation.ps1 repository')
    }

    & pwsh -NoLogo -NoProfile -File ./TestLab/Test-AnalyzeExample.ps1
    if ($LASTEXITCODE -ne 0) {
        $failures.Add('Test-AnalyzeExample.ps1 catalog')
    }

    & pwsh -NoLogo -NoProfile -File ./TestLab/Test-AnalyzeProjectAdapter.ps1
    if ($LASTEXITCODE -ne 0) {
        $failures.Add('Test-AnalyzeProjectAdapter.ps1 project adapter')
    }

    & pwsh -NoLogo -NoProfile -File ./TestLab/Test-AnalyzeOps005LinkedServerAdapter.ps1
    if ($LASTEXITCODE -ne 0) {
        $failures.Add('Test-AnalyzeOps005LinkedServerAdapter.ps1 OPS-005 adapter')
    }

    if ($IncludeNetwork) {
        & $pythonCommand ./Code/Tests/Static/980_Validate_External_Documentation_Links.py `
            --repository-root . --self-test --check-network
        if ($LASTEXITCODE -ne 0) {
            $failures.Add('980_Validate_External_Documentation_Links.py network')
        }
    }
}
finally {
    Pop-Location
}

if ($failures.Count -gt 0) {
    throw "Statische Vertragssuite fehlgeschlagen: $($failures -join '; ')"
}

Write-Host "Statische Vertragssuite erfolgreich: $($selfTestValidators.Count + $repositoryOnlyValidators.Count + 3) Prüfungen."
