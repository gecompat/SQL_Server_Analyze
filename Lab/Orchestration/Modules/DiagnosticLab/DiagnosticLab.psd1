@{
    RootModule = 'DiagnosticLab.psm1'
    ModuleVersion = '0.5.0'
    Author = 'SQL Server Analyze contributors'
    CompanyName = 'Community'
    Copyright = 'See repository license.'
    Description = 'LAB-001 preflight, bounded orchestration, SQL Server single and multi-container runtimes, core performance scenarios, sequential version lanes, and generic container framework installation.'
    PowerShellVersion = '7.2'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @(
        'Get-LabStatus'
        'Install-LabContainerFramework'
        'Invoke-LabCleanup'
        'Invoke-LabMultiContainerUp'
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
                'Podman'
                'MultiContainer'
            )
            ProjectUri = 'https://github.com/gecompat/SQL_Server_Analyze'
        }
    }
}
