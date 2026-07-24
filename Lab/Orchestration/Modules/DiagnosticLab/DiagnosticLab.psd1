@{
    RootModule = 'DiagnosticLab.psm1'
    ModuleVersion = '0.3.0'
    Author = 'SQL Server Analyze contributors'
    CompanyName = 'Community'
    Copyright = 'See repository license.'
    Description = 'LAB-001 preflight, bounded orchestration, SQL Server container baselines, core performance scenarios, and sequential version lanes.'
    PowerShellVersion = '7.2'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @(
        'Get-LabStatus'
        'Invoke-LabCleanup'
        'Invoke-LabPreflight'
        'Invoke-LabScenario'
        'Invoke-LabUp'
        'Invoke-LabVersionMatrix'
        'Test-LabScenario'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @(
                'SQLServer'
                'Diagnostics'
                'Lab'
                'Preflight'
                'Docker'
            )
            ProjectUri = 'https://github.com/gecompat/SQL_Server_Analyze'
        }
    }
}
