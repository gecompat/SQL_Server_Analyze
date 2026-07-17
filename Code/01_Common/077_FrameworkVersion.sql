USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.FrameworkVersion
Version      : 1.1.0-special.5
Stand        : 2026-07-17
Zweck        : Leichte Versionsinformation für das installierte Ad-hoc-
               Analysepaket. Keine Installationshistorie und kein Deployment-
               Framework.
Seiteneffekte: Eine Zeile wird bei Installation oder Upgrade aktualisiert.
===============================================================================
*/
IF OBJECT_ID(N'monitor.FrameworkVersion',N'U') IS NULL
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
SET [FrameworkVersion]='1.1.0-special.5',
    [ReleaseDate]='20260717',
    [MinimumProductMajorVersion]=15,
    [ContractVersion]='1.10',
    [LastInstalledUtc]=SYSUTCDATETIME(),
    [ReleaseNotes]=N'API 1.10: read-only Temporal-Tables-Tiefenanalyse für Zuordnung, Retention, approximative Kapazität und History-Indexbaseline ohne Nutzdaten-, DBCC- oder DDL-Zugriff; Spezialfallwellen bleiben laufzeitzutesten.'
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
        N'SQLServerMonitoringFramework','1.1.0-special.5','20260717',15,
        '1.10',SYSUTCDATETIME(),
        N'API 1.10: read-only Temporal-Tables-Tiefenanalyse für Zuordnung, Retention, approximative Kapazität und History-Indexbaseline ohne Nutzdaten-, DBCC- oder DDL-Zugriff; Spezialfallwellen bleiben laufzeitzutesten.'
    );
END;
GO
