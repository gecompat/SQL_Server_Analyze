USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.FrameworkVersion
Version      : 1.1.0
Stand        : 2026-10-22
Zweck        : Liefert eine kompakte Versionsinformation für das installierte
               Ad-hoc-Analysepaket. Die Tabelle bildet weder eine
               Installationshistorie noch ein Deployment-Framework ab.
Seiteneffekte: Eine Zeile wird bei Installation oder Upgrade aktualisiert.
===============================================================================
*/
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor' AND [t].[name]=N'FrameworkVersion'
)
BEGIN
    CREATE TABLE [monitor].[FrameworkVersion]
    (
        [FrameworkName] sysname NOT NULL CONSTRAINT PK_FrameworkVersion PRIMARY KEY,
        [FrameworkVersion] varchar(32) NOT NULL,
        [ReleaseDate] date NOT NULL,
        [MinimumProductMajorVersion] int NOT NULL,
        [ContractVersion] varchar(16) NOT NULL,
        [LastInstalledUtc] datetime2(0) NOT NULL,
        [ReleaseNotes] nvarchar(2000) NULL
    );
END;
GO

UPDATE [monitor].[FrameworkVersion]
SET [FrameworkVersion]='1.1.0',
    [ReleaseDate]='20261022',
    [MinimumProductMajorVersion]=15,
    [ContractVersion]='1.24',
    [LastInstalledUtc]=SYSUTCDATETIME(),
    [ReleaseNotes]=N'Release 1.1.0 konsolidiert den Diagnosekern, SSIS-Legacy- und Lookup-/Cacheanalysen sowie die vorhandenen Installationswege. API 1.24 einschließlich SQL25-005 bleibt erhalten.'
WHERE [FrameworkName]=N'SQLServerMonitoringFramework';

IF @@ROWCOUNT=0
BEGIN
    INSERT [monitor].[FrameworkVersion]
    (
        [FrameworkName],[FrameworkVersion],[ReleaseDate],[MinimumProductMajorVersion],
        [ContractVersion],[LastInstalledUtc],[ReleaseNotes]
    )
    VALUES
    (
        N'SQLServerMonitoringFramework','1.1.0','20261022',15,
        '1.24',SYSUTCDATETIME(),
        N'Release 1.1.0 konsolidiert den Diagnosekern, SSIS-Legacy- und Lookup-/Cacheanalysen sowie die vorhandenen Installationswege. API 1.24 einschließlich SQL25-005 bleibt erhalten.'
    );
END;
GO
