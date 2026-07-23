@{
    RootModule = 'DiagnosticLab.psm1'
    ModuleVersion = '0.1.0'
    Author = 'SQL Server Analyze contributors'
    CompanyName = 'Community'
    Copyright = 'See repository license.'
    Description = 'LAB-001 read-only Preflight and bounded orchestration core.'
    PowerShellVersion = '7.2'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @(
        'Get-LabStatus'
        'Invoke-LabCleanup'
        'Invoke-LabPreflight'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('SQLServer', 'Diagnostics', 'Lab', 'Preflight')
            ProjectUri = 'https://github.com/gecompat/SQL_Server_Analyze'
        }
    }
}
