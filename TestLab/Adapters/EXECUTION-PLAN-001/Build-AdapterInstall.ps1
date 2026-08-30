[CmdletBinding()]
param(
    [string] $RepositoryRoot = (
        Resolve-Path (Join-Path $PSScriptRoot '../../..')
    ).Path,

    [string] $OutputPath = (Join-Path $PSScriptRoot 'sql/install.sql')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryPath = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$builderPath = Join-Path `
    $repositoryPath `
    'Code/Install/Build-ExecutionPlanAnalysisInstaller.ps1'
if (-not (Test-Path -LiteralPath $builderPath -PathType Leaf)) {
    throw "Der kanonische Execution-Plan-Installer-Builder fehlt: $builderPath"
}

$temporaryPath = Join-Path `
    ([IO.Path]::GetTempPath()) `
    ("sql-analyze-adapter-{0}.sql" -f [guid]::NewGuid().ToString('N'))

try {
    & $builderPath `
        -RepositoryRoot $repositoryPath `
        -OutputPath $temporaryPath

    $standalone = [IO.File]::ReadAllText(
        $temporaryPath,
        [Text.Encoding]::UTF8
    )
    $sourceHeaderMatch = [Text.RegularExpressions.Regex]::Match(
        $standalone,
        '\AUSE \[DeineDatenbank\];\r?\nGO'
    )
    if (-not $sourceHeaderMatch.Success) {
        throw 'Der kanonische Standalone-Installer besitzt nicht den erwarteten Datenbankheader.'
    }

    $adapterHeader = @'
/*
Generated from the canonical standalone Execution Plan Analysis installer.
Do not edit directly; run Build-AdapterInstall.ps1.
*/
USE [master];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @FrameworkDatabase sysname = N'LabAnalyze';
DECLARE @ProjectId nvarchar(128) = N'sql-server-analyze-execution-plan-001';
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
      AND [name] NOT IN (N'LabAnalyze', N'AnalyzeAdapterPlan')
)
    THROW 55401, N'ADAPTER_ISOLATION_REQUIRED: Die Instanz enthält eine fremde Benutzerdatenbank.', 1;

IF DB_ID(@FrameworkDatabase) IS NULL
BEGIN
    SET @Sql = N'CREATE DATABASE [LabAnalyze] COLLATE SQL_Latin1_General_CP1_CS_AS;';
    EXEC [sys].[sp_executesql] @Sql;
    SET @Created = 1;
END;

IF @Created = 1
BEGIN
    EXEC [LabAnalyze].[sys].[sp_addextendedproperty]
          @name = N'SQLANALYZE.AdapterProject'
        , @value = @ProjectId;
    EXEC [LabAnalyze].[sys].[sp_addextendedproperty]
          @name = N'SQLANALYZE.AdapterContractVersion'
        , @value = @ContractVersion;
END;
ELSE
BEGIN
    SELECT
          @ExistingProject = MAX
          (
              CASE WHEN [name] = N'SQLANALYZE.AdapterProject'
                   THEN CONVERT(nvarchar(128), [value]) END
          )
        , @ExistingContract = MAX
          (
              CASE WHEN [name] = N'SQLANALYZE.AdapterContractVersion'
                   THEN CONVERT(nvarchar(32), [value]) END
          )
    FROM [LabAnalyze].[sys].[extended_properties]
    WHERE [class] = 0
      AND [major_id] = 0
      AND [minor_id] = 0;

    IF @ExistingProject <> @ProjectId
       OR @ExistingContract <> @ContractVersion
        THROW 55402, N'ADAPTER_STATE_CONFLICT: LabAnalyze besitzt nicht die erwarteten Adaptermarker.', 1;
END;
GO
USE [LabAnalyze];
GO
'@

    $generated = $adapterHeader.TrimEnd() + "`n" +
        $standalone.Substring($sourceHeaderMatch.Length).TrimStart("`r", "`n")
    $generated = [Text.RegularExpressions.Regex]::Replace(
        $generated,
        '[\t ]+(?=\r?$)',
        '',
        [Text.RegularExpressions.RegexOptions]::Multiline
    )
    $outputDirectory = Split-Path ([IO.Path]::GetFullPath($OutputPath)) -Parent
    [IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    [IO.File]::WriteAllText(
        $OutputPath,
        $generated,
        [Text.UTF8Encoding]::new($false)
    )
}
finally {
    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Generated $OutputPath from the canonical standalone Execution Plan Analysis installer."
