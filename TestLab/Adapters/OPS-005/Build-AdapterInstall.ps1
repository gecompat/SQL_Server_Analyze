[CmdletBinding()]
param(
    [string] $RepositoryRoot = (
        Resolve-Path (Join-Path $PSScriptRoot '../../..')
    ).Path,

    [string] $InstallOutputPath = (Join-Path $PSScriptRoot 'sql/install.sql'),

    [string] $UpdateOutputPath = (Join-Path $PSScriptRoot 'sql/update.sql')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$standaloneBuilderPath = Join-Path `
    $repositoryPath `
    'Code/Install/Build-StandaloneInstaller.ps1'
$runtimeContractPath = Join-Path `
    $repositoryPath `
    'Code/Tests/ServerHealth/120_OPS005_Linked_Server_Runtime_Contract.sql'
foreach ($requiredPath in @($standaloneBuilderPath, $runtimeContractPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Die kanonische OPS-005-Quelle fehlt: $requiredPath"
    }
}

$temporaryInstallerPath = Join-Path `
    ([IO.Path]::GetTempPath()) `
    ("sql-analyze-ops005-installer-{0}.sql" -f [guid]::NewGuid().ToString('N'))

function Write-Utf8File {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Content
    )

    [IO.Directory]::CreateDirectory((Split-Path ([IO.Path]::GetFullPath($Path)) -Parent)) | Out-Null
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

try {
    & $standaloneBuilderPath `
        -RepositoryRoot $repositoryPath `
        -OutputPath $temporaryInstallerPath

    $standalone = [IO.File]::ReadAllText($temporaryInstallerPath, [Text.Encoding]::UTF8)
    $sourceHeaderMatch = [Text.RegularExpressions.Regex]::Match(
        $standalone,
        '\AUSE \[DeineDatenbank\];\r?\nGO'
    )
    if (-not $sourceHeaderMatch.Success) {
        throw 'Der kanonische Vollinstaller besitzt nicht den erwarteten Datenbankheader.'
    }

    $installHeader = @'
/*
Generated from the canonical full SQL Server Analyze installer.
Do not edit directly; run Build-AdapterInstall.ps1.
*/
USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @FrameworkDatabase sysname = N'DeineDatenbank';
DECLARE @ProjectId nvarchar(128) = N'sql-server-analyze-ops-005-linked-server';
DECLARE @ContractVersion nvarchar(32) = N'0.1';
DECLARE @Created bit = 0;
DECLARE @Sql nvarchar(max);
DECLARE @ExistingProject nvarchar(128);
DECLARE @ExistingContract nvarchar(32);

IF EXISTS
(
    SELECT 1
    FROM [sys].[databases]
    WHERE [database_id] > 4
      AND [name] <> @FrameworkDatabase
)
    THROW 55501, N'ADAPTER_ISOLATION_REQUIRED: Die Instanz enthält eine fremde Benutzerdatenbank.', 1;

IF DB_ID(@FrameworkDatabase) IS NULL
BEGIN
    SET @Sql = N'CREATE DATABASE [DeineDatenbank] COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Created = 1;
END;

IF @Created = 1
BEGIN
    EXEC [DeineDatenbank].[sys].[sp_addextendedproperty]
          @name = N'SQLANALYZE.AdapterProject'
        , @value = @ProjectId;
    EXEC [DeineDatenbank].[sys].[sp_addextendedproperty]
          @name = N'SQLANALYZE.AdapterContractVersion'
        , @value = @ContractVersion;
END;
ELSE
BEGIN
    SELECT
          @ExistingProject = MAX(CASE WHEN [name] = N'SQLANALYZE.AdapterProject' THEN CONVERT(nvarchar(128), [value]) END)
        , @ExistingContract = MAX(CASE WHEN [name] = N'SQLANALYZE.AdapterContractVersion' THEN CONVERT(nvarchar(32), [value]) END)
    FROM [DeineDatenbank].[sys].[extended_properties]
    WHERE [class] = 0 AND [major_id] = 0 AND [minor_id] = 0;

    IF @ExistingProject <> @ProjectId OR @ExistingContract <> @ContractVersion
        THROW 55502, N'ADAPTER_STATE_CONFLICT: Die Frameworkdatenbank besitzt nicht die erwarteten Adaptermarker.', 1;
END;
GO
USE [DeineDatenbank];
GO
'@

    $installer = $installHeader.TrimEnd() + "`n" +
        $standalone.Substring($sourceHeaderMatch.Length).TrimStart("`r", "`n")
    $installer = [Text.RegularExpressions.Regex]::Replace(
        $installer,
        '[\t ]+(?=\r?$)',
        '',
        [Text.RegularExpressions.RegexOptions]::Multiline
    )
    Write-Utf8File -Path $InstallOutputPath -Content $installer

    $runtimeContract = [IO.File]::ReadAllText($runtimeContractPath, [Text.Encoding]::UTF8)
    $runtimeContract = $runtimeContract.Replace(
        'USE [DeineDatenbank];',
        'USE [DeineDatenbank];'
    )
    if (-not $runtimeContract.Contains('[DeineDatenbank]')) {
        throw 'Der OPS-005-Runtimevertrag enthält nicht den erwarteten Datenbankplatzhalter.'
    }
    $updateHeader = @'
/*
Generated from the canonical OPS-005 linked-server runtime contract.
Do not edit directly; run Build-AdapterInstall.ps1.
*/
USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

    IF DB_ID(N'DeineDatenbank') IS NULL
    THROW 55502, N'ADAPTER_STATE_CONFLICT: Die Frameworkdatenbank fehlt.', 1;
GO
'@
$updateFooter = @'

USE [DeineDatenbank];
GO
IF EXISTS
(
    SELECT 1
    FROM [sys].[extended_properties]
    WHERE [class] = 0
      AND [major_id] = 0
      AND [minor_id] = 0
      AND [name] = N'SQLANALYZE.Ops005RuntimeContract'
)
    EXEC [sys].[sp_updateextendedproperty]
          @name = N'SQLANALYZE.Ops005RuntimeContract'
        , @value = N'PASS';
ELSE
    EXEC [sys].[sp_addextendedproperty]
          @name = N'SQLANALYZE.Ops005RuntimeContract'
        , @value = N'PASS';
GO
'@
    Write-Utf8File `
        -Path $UpdateOutputPath `
        -Content ($updateHeader.TrimEnd() + "`n" + $runtimeContract.TrimEnd() + "`n" + $updateFooter.TrimStart())
}
finally {
    Remove-Item -LiteralPath $temporaryInstallerPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Generated $InstallOutputPath and $UpdateOutputPath from canonical OPS-005 sources."
