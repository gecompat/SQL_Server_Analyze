[CmdletBinding()]
param([string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
}

$frameworkInstaller = Join-Path $RepositoryRoot 'Code/Install/Install_SnapshotBaseline_Framework.sql'
$targetInstaller = Join-Path $RepositoryRoot 'Code/Install/Install_SnapshotBaseline_Target.sql'
$installAll = Join-Path $RepositoryRoot 'Code/Install/Install_All.sql'
$snapshotSourceRoot = Join-Path $RepositoryRoot 'Code/10_SnapshotBaseline'

foreach ($path in @($frameworkInstaller, $targetInstaller, $installAll)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "SC023_INSTALLER_FILE_MISSING: $([IO.Path]::GetFileName($path))"
    }
}

if (-not (Test-Path -LiteralPath $snapshotSourceRoot -PathType Container)) {
    throw 'SC023_SOURCE_DIRECTORY_MISSING: Code/10_SnapshotBaseline'
}

function Get-SqlIncludes {
    param([Parameter(Mandatory)][string]$InstallerPath)

    $installerText = Get-Content -LiteralPath $InstallerPath -Raw -Encoding UTF8
    $matches = [Text.RegularExpressions.Regex]::Matches(
        $installerText,
        '(?m)^\s*:r\s+(.+?)\s*$'
    )

    if ($matches.Count -eq 0) {
        throw "SC023_INSTALLER_HAS_NO_INCLUDES: $([IO.Path]::GetFileName($InstallerPath))"
    }

    $resolved = foreach ($match in $matches) {
        $relativePath = $match.Groups[1].Value.Trim().Trim('"')
        $candidate = Join-Path ([IO.Path]::GetDirectoryName($InstallerPath)) $relativePath
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            throw "SC023_INCLUDE_MISSING: $([IO.Path]::GetFileName($InstallerPath))"
        }

        $item = Get-Item -LiteralPath $candidate
        if ($item.Extension -ne '.sql') {
            throw "SC023_INCLUDE_NOT_SQL: $([IO.Path]::GetFileName($InstallerPath))"
        }
        if (-not ($item.FullName.StartsWith($RepositoryRoot, [StringComparison]::OrdinalIgnoreCase))) {
            throw "SC023_INCLUDE_OUTSIDE_REPOSITORY: $([IO.Path]::GetFileName($InstallerPath))"
        }
        $item
    }

    $duplicates = @($resolved | Group-Object FullName | Where-Object Count -gt 1)
    if ($duplicates.Count -gt 0) {
        throw "SC023_DUPLICATE_INCLUDE: $([IO.Path]::GetFileName($InstallerPath))"
    }

    return @($resolved)
}

function Get-CombinedSqlText {
    param(
        [Parameter(Mandatory)][string]$InstallerPath,
        [Parameter(Mandatory)][object[]]$Includes
    )

    $parts = [Collections.Generic.List[string]]::new()
    $parts.Add((Get-Content -LiteralPath $InstallerPath -Raw -Encoding UTF8))
    foreach ($include in $Includes) {
        $parts.Add((Get-Content -LiteralPath $include.FullName -Raw -Encoding UTF8))
    }
    return [string]::Join("`n", $parts)
}

function Assert-NoMutationOfSecurityOrAgent {
    param(
        [Parameter(Mandatory)][string]$SqlText,
        [Parameter(Mandatory)][string]$ContractPart
    )

    $forbidden = [ordered]@{
        'RIGHTS_DDL'       = '(?im)^\s*(?:GRANT|DENY|REVOKE)\s+'
        'PRINCIPAL_DDL'    = '(?im)^\s*CREATE\s+(?:LOGIN|USER|ROLE)\b'
        'ROLE_MEMBERSHIP'  = '(?im)^\s*ALTER\s+ROLE\b.*\b(?:ADD|DROP)\s+MEMBER\b'
        'AGENT_JOB_DDL'    = '(?i)\bsp_(?:add|update|delete)_job(?:step|server)?\b'
        'AGENT_SCHEDULE'   = '(?i)\bsp_(?:add|update|delete)_schedule\b'
    }

    foreach ($entry in $forbidden.GetEnumerator()) {
        if ([Text.RegularExpressions.Regex]::IsMatch($SqlText, $entry.Value)) {
            throw "SC023_FORBIDDEN_$($entry.Key): $ContractPart"
        }
    }
}

$frameworkIncludes = @(Get-SqlIncludes -InstallerPath $frameworkInstaller)
$targetIncludes = @(Get-SqlIncludes -InstallerPath $targetInstaller)
$frameworkText = Get-CombinedSqlText -InstallerPath $frameworkInstaller -Includes $frameworkIncludes
$targetText = Get-CombinedSqlText -InstallerPath $targetInstaller -Includes $targetIncludes
$installAllText = Get-Content -LiteralPath $installAll -Raw -Encoding UTF8

$expectedFrameworkIncludes = @(
    'Code/00_Setup/000_Preflight_und_Schema.sql',
    'Code/10_SnapshotBaseline/010_SnapshotTargetConfiguration.sql',
    'Code/10_SnapshotBaseline/080_USP_ConfigureSnapshotTarget.sql',
    'Code/10_SnapshotBaseline/090_USP_RunSnapshotCollectionCycle.sql',
    'Code/10_SnapshotBaseline/100_USP_PurgeSnapshotData.sql'
)
$expectedTargetIncludes = @(
    'Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql',
    'Code/10_SnapshotBaseline/020_InternalConfigureSnapshotPolicy.sql',
    'Code/10_SnapshotBaseline/040_InternalPrepareCollectionCycle.sql',
    'Code/10_SnapshotBaseline/050_InternalCompletePerformanceCounterCycle.sql',
    'Code/10_SnapshotBaseline/060_InternalFinalizeCollectionCycle.sql',
    'Code/10_SnapshotBaseline/070_InternalPurgeExpiredData.sql'
)
$observedFrameworkIncludes = @(
    $frameworkIncludes | ForEach-Object {
        [IO.Path]::GetRelativePath($RepositoryRoot, $_.FullName).Replace('\','/')
    }
)
$observedTargetIncludes = @(
    $targetIncludes | ForEach-Object {
        [IO.Path]::GetRelativePath($RepositoryRoot, $_.FullName).Replace('\','/')
    }
)
if ([string]::Join('|', $observedFrameworkIncludes) -ne [string]::Join('|', $expectedFrameworkIncludes)) {
    throw 'SC023_FRAMEWORK_INSTALLER_CLOSURE_OR_ORDER'
}
if ([string]::Join('|', $observedTargetIncludes) -ne [string]::Join('|', $expectedTargetIncludes)) {
    throw 'SC023_TARGET_INSTALLER_CLOSURE_OR_ORDER'
}

$overlap = @(
    $frameworkIncludes.FullName |
        Where-Object { $targetIncludes.FullName -contains $_ }
)
if ($overlap.Count -gt 0) {
    throw 'SC023_INSTALLER_CLOSURES_OVERLAP'
}

$allSnapshotSources = @(
    Get-ChildItem -LiteralPath $snapshotSourceRoot -File -Filter '*.sql' -Recurse |
        Sort-Object FullName
)
$includedSnapshotSources = @(
    @($frameworkIncludes + $targetIncludes) |
        Where-Object { $_.FullName.StartsWith($snapshotSourceRoot, [StringComparison]::OrdinalIgnoreCase) }
)

$missingFromClosure = @(
    $allSnapshotSources |
        Where-Object { $includedSnapshotSources.FullName -notcontains $_.FullName }
)
if ($missingFromClosure.Count -gt 0) {
    throw 'SC023_SOURCE_NOT_IN_INSTALLER_CLOSURE'
}

$unexpectedOutsideClosure = @(
    $includedSnapshotSources |
        Where-Object { $allSnapshotSources.FullName -notcontains $_.FullName }
)
if ($unexpectedOutsideClosure.Count -gt 0) {
    throw 'SC023_INSTALLER_CLOSURE_CONTAINS_UNKNOWN_SOURCE'
}

$publicApis = @(
    'USP_ConfigureSnapshotTarget',
    'USP_RunSnapshotCollectionCycle',
    'USP_PurgeSnapshotData'
)

foreach ($api in $publicApis) {
    $frameworkDefinition = "(?is)CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[monitor\]\.\[$([regex]::Escape($api))\]"
    if (-not [Text.RegularExpressions.Regex]::IsMatch($frameworkText, $frameworkDefinition)) {
        throw "SC023_PUBLIC_API_MISSING_FROM_FRAMEWORK_INSTALLER: $api"
    }
    if ([Text.RegularExpressions.Regex]::IsMatch($targetText, "(?i)\[$([regex]::Escape($api))\]")) {
        throw "SC023_PUBLIC_API_PRESENT_IN_TARGET_INSTALLER: $api"
    }
    if ([Text.RegularExpressions.Regex]::IsMatch($installAllText, "(?i)$([regex]::Escape($api))")) {
        throw "SC023_PUBLIC_API_PRESENT_IN_INSTALL_ALL: $api"
    }
}

if (-not [Text.RegularExpressions.Regex]::IsMatch($frameworkText, '(?i)\[monitor\]\.\[SnapshotTargetConfiguration\]')) {
    throw 'SC023_FRAMEWORK_CONFIGURATION_OBJECT_MISSING'
}
if ([Text.RegularExpressions.Regex]::IsMatch($targetText, '(?i)\[monitor\]\.\[SnapshotTargetConfiguration\]')) {
    throw 'SC023_FRAMEWORK_CONFIGURATION_OBJECT_IN_TARGET_INSTALLER'
}

$requiredTargetTables = @(
    'PackageVersion',
    'RetentionPolicy',
    'CollectorPolicy',
    'CaptureRun',
    'ModuleStatus',
    'Scope',
    'MetricDefinition',
    'MetricSample',
    'PayloadSnapshot',
    'PurgeRun'
)

foreach ($tableName in $requiredTargetTables) {
    if (-not [Text.RegularExpressions.Regex]::IsMatch($targetText, "(?i)\[snapshot\]\.\[$([regex]::Escape($tableName))\]")) {
        throw "SC023_TARGET_OBJECT_MISSING: $tableName"
    }
    if ([Text.RegularExpressions.Regex]::IsMatch($frameworkText, "(?is)CREATE\s+TABLE\s+\[snapshot\]\.\[$([regex]::Escape($tableName))\]")) {
        throw "SC023_TARGET_TABLE_CREATED_BY_FRAMEWORK_INSTALLER: $tableName"
    }
}

$targetProcedureMatches = [Text.RegularExpressions.Regex]::Matches(
    $targetText,
    '(?is)CREATE\s+OR\s+ALTER\s+PROCEDURE\s+\[snapshot\]\.\[(?<name>[^\]]+)\]'
)
if ($targetProcedureMatches.Count -eq 0) {
    throw 'SC023_TARGET_INTERNAL_PROCEDURE_MISSING'
}
$expectedTargetProcedures = @(
    'InternalConfigureSnapshotPolicy',
    'InternalPrepareCollectionCycle',
    'InternalCompletePerformanceCounterCycle',
    'InternalFinalizeCollectionCycle',
    'InternalPurgeExpiredData'
)
$observedTargetProcedures = @(
    $targetProcedureMatches | ForEach-Object { $_.Groups['name'].Value }
)
if ([string]::Join('|', $observedTargetProcedures) -ne [string]::Join('|', $expectedTargetProcedures)) {
    throw 'SC023_TARGET_INTERNAL_PROCEDURE_CLOSURE_OR_ORDER'
}
foreach ($match in $targetProcedureMatches) {
    if (-not ($match.Groups['name'].Value.StartsWith('Internal', [StringComparison]::Ordinal))) {
        throw 'SC023_TARGET_PUBLIC_PROCEDURE_FORBIDDEN'
    }
}

if ([Text.RegularExpressions.Regex]::IsMatch($installAllText, '(?i)SnapshotBaseline|SnapshotTargetConfiguration|\[snapshot\]\.')) {
    throw 'SC023_OPTIONAL_PACKAGE_PRESENT_IN_INSTALL_ALL'
}

Assert-NoMutationOfSecurityOrAgent -SqlText $frameworkText -ContractPart 'FRAMEWORK'
Assert-NoMutationOfSecurityOrAgent -SqlText $targetText -ContractPart 'TARGET'

$allowedUseContexts = @(
    'DeineDatenbank',
    'DeineSnapshotDatenbank',
    'master',
    'model',
    'msdb',
    'tempdb'
)
foreach ($part in @(
    @{ Name = 'FRAMEWORK'; Text = $frameworkText },
    @{ Name = 'TARGET'; Text = $targetText }
)) {
    foreach ($match in [Text.RegularExpressions.Regex]::Matches($part.Text, '(?im)^\s*USE\s+\[([^\]\r\n]+)\]')) {
        if ($allowedUseContexts -notcontains $match.Groups[1].Value) {
            throw "SC023_NON_SYNTHETIC_DATABASE_CONTEXT: $($part.Name)"
        }
    }
}

Write-Host (
    'Snapshot Baseline installer contract passed: ' +
    "$($frameworkIncludes.Count) framework includes, " +
    "$($targetIncludes.Count) target includes, " +
    "$($allSnapshotSources.Count) snapshot sources."
)
