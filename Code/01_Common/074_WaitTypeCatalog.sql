USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : [monitor].[WaitTypeCatalog]
Version      : 2.1.0
Stand        : 2026-07-18
Zweck        : Persistenter, erweiterbarer Wait-Katalog mit gegen die Microsoft-Primärreferenz
               geprüftem Framework-Seed.
Hinweis      : FRAMEWORK_CURATED kennzeichnet die belegte Namens- und Textprüfung.
               SQLskills-Inhalte werden nicht kopiert, sondern ausschließlich als
               optionale HelpUrl verlinkt.
===============================================================================
*/
IF NOT EXISTS
(
 SELECT 1
 FROM [sys].[tables] AS [t] WITH (NOLOCK)
 JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id]
 WHERE [s].[name]=N'monitor' AND [t].[name]=N'WaitTypeCatalog'
)
BEGIN
 CREATE TABLE [monitor].[WaitTypeCatalog]
 (
  [WaitType] nvarchar(120) NOT NULL CONSTRAINT PK_WaitTypeCatalog PRIMARY KEY CLUSTERED,
  [WaitGroup] nvarchar(64) NOT NULL,[Severity] tinyint NOT NULL CONSTRAINT DF_WaitTypeCatalog_Severity DEFAULT(1),
  [IsGenerallyBenign] bit NOT NULL CONSTRAINT DF_WaitTypeCatalog_Benign DEFAULT(0),[Meaning] nvarchar(1000) NOT NULL,
  [TypicalOccurrence] nvarchar(1200) NOT NULL,[HighWaitImpact] nvarchar(1200) NOT NULL,[RecommendedChecks] nvarchar(1500) NOT NULL,
  [HelpUrl] nvarchar(500) NULL,[MinProductMajorVersion] int NULL,[DescriptionSource] varchar(40) NULL,
  [DescriptionQuality] varchar(40) NULL,[SourceReference] nvarchar(500) NULL,
  [IsFrameworkDefault] bit NOT NULL CONSTRAINT DF_WaitTypeCatalog_Default DEFAULT(1),
  [LastUpdatedUtc] datetime2(0) NOT NULL CONSTRAINT DF_WaitTypeCatalog_Updated DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT CK_WaitTypeCatalog_Severity CHECK([Severity] BETWEEN 0 AND 5)
 );
END;
GO
IF NOT EXISTS(SELECT 1 FROM [sys].[columns] AS [c] WITH (NOLOCK) JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id]=[c].[object_id] JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id] WHERE [s].[name]=N'monitor' AND [t].[name]=N'WaitTypeCatalog' AND [c].[name]=N'DescriptionSource') ALTER TABLE [monitor].[WaitTypeCatalog] ADD [DescriptionSource] varchar(40) NULL;
IF NOT EXISTS(SELECT 1 FROM [sys].[columns] AS [c] WITH (NOLOCK) JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id]=[c].[object_id] JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id] WHERE [s].[name]=N'monitor' AND [t].[name]=N'WaitTypeCatalog' AND [c].[name]=N'DescriptionQuality') ALTER TABLE [monitor].[WaitTypeCatalog] ADD [DescriptionQuality] varchar(40) NULL;
IF NOT EXISTS(SELECT 1 FROM [sys].[columns] AS [c] WITH (NOLOCK) JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id]=[c].[object_id] JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id] WHERE [s].[name]=N'monitor' AND [t].[name]=N'WaitTypeCatalog' AND [c].[name]=N'SourceReference') ALTER TABLE [monitor].[WaitTypeCatalog] ADD [SourceReference] nvarchar(500) NULL;
GO
GO
