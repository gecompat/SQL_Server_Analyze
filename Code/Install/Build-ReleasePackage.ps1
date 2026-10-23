[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Join-Path $PSScriptRoot '../..'),
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$Revision = 'HEAD',
    [string]$Version = '1.1.2',
    [string]$PythonExecutable = 'python'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'RELEASE_VERSION_INVALID' }
$RepositoryRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$commit = (& git -C $RepositoryRoot rev-parse --verify "$Revision^{commit}").Trim()
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[0-9a-f]{40}$') { throw 'RELEASE_COMMIT_INVALID' }
$tree = (& git -C $RepositoryRoot rev-parse "$commit^{tree}").Trim()
if ($LASTEXITCODE -ne 0 -or $tree -notmatch '^[0-9a-f]{40}$') { throw 'RELEASE_TREE_INVALID' }
[IO.Directory]::CreateDirectory($OutputDirectory) | Out-Null
$archivePath = Join-Path $OutputDirectory "SQL_Server_Analyze-$Version.zip"
$checksumPath = "$archivePath.sha256"
if ((Test-Path -LiteralPath $archivePath) -or (Test-Path -LiteralPath $checksumPath)) {
    throw 'RELEASE_OUTPUT_EXISTS'
}
$stage = Join-Path $OutputDirectory ('.release-stage-' + [guid]::NewGuid().ToString('N'))
$outputPrefix = $OutputDirectory.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not ([IO.Path]::GetFullPath($stage).StartsWith($outputPrefix, [StringComparison]::OrdinalIgnoreCase))) {
    throw 'RELEASE_STAGE_OUTSIDE_OUTPUT'
}
[IO.Directory]::CreateDirectory($stage) | Out-Null
$rootName = "SQL_Server_Analyze-$Version"
$sourceRoot = Join-Path $stage $rootName
$oldBytecode = $env:PYTHONDONTWRITEBYTECODE
$env:PYTHONDONTWRITEBYTECODE = '1'
$completed = $false
try {
    $sourceArchive = Join-Path $stage 'source.zip'
    & git -C $RepositoryRoot archive --format=zip "--output=$sourceArchive" $commit
    if ($LASTEXITCODE -ne 0) { throw 'RELEASE_SOURCE_EXPORT_FAILED' }
    [IO.Compression.ZipFile]::ExtractToDirectory($sourceArchive, $sourceRoot)
    $versionSource = [IO.File]::ReadAllText((Join-Path $sourceRoot 'Code/01_Common/077_FrameworkVersion.sql'))
    if (-not $versionSource.Contains("[FrameworkVersion]='$Version'")) { throw 'RELEASE_VERSION_MISMATCH' }
    $install = Join-Path $sourceRoot 'Code/Install'
    $generated = Join-Path $install 'generated'
    & (Join-Path $install 'Build-StandaloneInstaller.ps1') -RepositoryRoot $sourceRoot
    & (Join-Path $install 'Build-ExecutionPlanAnalysisInstaller.ps1') -RepositoryRoot $sourceRoot
    & (Join-Path $install 'Build-SnapshotBaselineInstallers.ps1') -RepositoryRoot $sourceRoot
    & (Join-Path $install 'Build-DeploymentInstaller.ps1') -RepositoryRoot $sourceRoot -PythonExecutable $PythonExecutable
    & (Join-Path $install 'Build-DeploymentInstaller.ps1') -RepositoryRoot $sourceRoot `
        -OutputPath (Join-Path $generated 'Deploy_All_WithSnapshotBaseline.generated.sql') `
        -IncludeSnapshotBaseline -PythonExecutable $PythonExecutable
    $inventory = @(Import-Csv -LiteralPath (Join-Path $sourceRoot 'Metadata/Inventory/Objects.csv'))
    foreach ($row in $inventory) {
        if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $row.SourcePath) -PathType Leaf)) {
            throw 'RELEASE_INVENTORY_SOURCE_MISSING'
        }
    }
    $snapshotCount = @($inventory | Where-Object { $_.SourcePath.StartsWith('Code/10_SnapshotBaseline/') }).Count
    $metadata = [ordered]@{
        schema_version = 1
        framework_version = $Version
        contract_version = '1.24'
        source_commit = $commit
        source_tree = $tree
        minimum_product_major_version = 15
        supported_product_major_versions = @(15, 16, 17)
        build_number_restriction = $false
        object_count = $inventory.Count
        core_object_count = $inventory.Count - $snapshotCount
        snapshot_object_count = $snapshotCount
        generated_installers = @(
            'Install_All.generated.sql', 'Deploy_All.generated.sql',
            'Install_ExecutionPlanAnalysis.generated.sql',
            'Install_SnapshotBaseline_Target.generated.sql',
            'Install_SnapshotBaseline_Framework.generated.sql',
            'Deploy_All_WithSnapshotBaseline.generated.sql'
        )
    }
    foreach ($name in $metadata.generated_installers) {
        $installerPath = Join-Path $generated $name
        if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
            throw 'RELEASE_INSTALLER_MISSING'
        }
        $installerText = [IO.File]::ReadAllText($installerPath, [Text.UTF8Encoding]::new($false, $true)).Replace("`r`n", "`n")
        [IO.File]::WriteAllText($installerPath, $installerText, [Text.UTF8Encoding]::new($false))
    }
    [IO.File]::WriteAllText((Join-Path $sourceRoot 'RELEASE.json'),
        (($metadata | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
    $zip = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in (Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force -File | Sort-Object FullName)) {
            $relative = [IO.Path]::GetRelativePath($sourceRoot, $file.FullName).Replace('\', '/')
            $entry = $zip.CreateEntry("$rootName/$relative", [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $entryStream = $entry.Open()
            try {
                $sourceStream = [IO.File]::OpenRead($file.FullName)
                try { $sourceStream.CopyTo($entryStream) }
                finally { $sourceStream.Dispose() }
            }
            finally { $entryStream.Dispose() }
        }
    }
    finally { $zip.Dispose() }
    $digest = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($checksumPath, "$digest  $([IO.Path]::GetFileName($archivePath))`n", [Text.UTF8Encoding]::new($false))
    $completed = $true
    Write-Host "Release package built: version=$Version commit=$commit objects=$($inventory.Count)"
}
finally {
    $env:PYTHONDONTWRITEBYTECODE = $oldBytecode
    if (([IO.Path]::GetFullPath($stage).StartsWith($outputPrefix, [StringComparison]::OrdinalIgnoreCase)) -and
        (Test-Path -LiteralPath $stage)) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
    if (-not $completed) {
        foreach ($path in @($archivePath, $checksumPath)) {
            if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
        }
    }
}
