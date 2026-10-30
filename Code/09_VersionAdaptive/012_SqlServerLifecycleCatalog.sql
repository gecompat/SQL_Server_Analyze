USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.SqlServerLifecycleCatalog
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Framework-Metadatentabelle und Seed
Zweck        : Das Skript legt bei Bedarf den Lifecyclekatalog an und ergänzt
               die dokumentierten SQL-Server-Produktlebenszyklen als offline
               auswertbaren Metadatensnapshot.
Voraussetzung: Im aktuellen Datenbankkontext muss das Schema [monitor]
               vorhanden sein. Das Skript ist dort mit ausreichenden Rechten
               für die Katalogabfrage, Tabellenerstellung und Seed-Inserts
               auszuführen.
Quelle       : Microsoft Lifecycle, Abruf 2026-07-21.
Zeitbezug    : [CatalogAsOfDate] und [SourceRetrievedAtUtc] sind feste Werte
               des am 2026-07-21 abgerufenen Seeds. Sie bezeichnen dessen
               dokumentierten Snapshot und Abrufzeit, keine Onlineprüfung.
Grenze       : Die enthaltenen Produkte sind ausgewählte Seedzeilen; der
               Katalog beweist weder aktuelle Lifecycle-Daten noch Support,
               Sicherheitsstatus oder eine individuelle Berechtigung.
Verhalten    : Die Tabelle wird nur angelegt, wenn sie fehlt; vorhandene
               Tabellen werden nicht migriert oder allgemein repariert.
               Vorhandene Seed-Schlüssel werden feldweise bytegenau geprüft.
               Abweichungen lösen Fehler 53932 aus. Übereinstimmende Schlüssel
               bleiben bestehen, andere vorhandene Zeilen bleiben erhalten
               und nur fehlende Seed-Schlüssel werden eingefügt. Es gibt kein
               UPDATE, DELETE oder Ownershipmarker. Die Prüfung ist keine
               Zusage einer atomaren Gesamtausführung; GO trennt Batches.
Beispiel     : SELECT [ProductMajorVersion], [ProductName], [StartDate],
                      [MainstreamEndDate], [ExtendedEndDate],
                      [LifecyclePolicy], [CatalogAsOfDate],
                      [SourceRetrievedAtUtc]
               FROM [monitor].[SqlServerLifecycleCatalog] WITH (NOLOCK)
               WHERE [ProductMajorVersion] = 17;
Felder       : Schlüssel und Produkt: [ProductMajorVersion] int ist
               Primärschlüssel; [ProductName] nvarchar(64) enthält den
               Produktnamen.
               Lifecycletermine und Regel: [StartDate] date bezeichnet den
               Beginn; [MainstreamEndDate] date und [ExtendedEndDate] date
               speichern die beiden Endtermine; [LifecyclePolicy] varchar(32)
               benennt die im Seed erfasste Policy.
               Verweis und Provenienz: [LifecycleUrl] nvarchar(512) verweist
               auf die Produkt-Lifecyclequelle; [CatalogAsOfDate] date hält
               den Stand des Snapshots fest; [SourceRetrievedAtUtc]
               datetime2(0) speichert die Abrufzeit in UTC. Textfelder
               verwenden DATABASE_DEFAULT.
===============================================================================
*/
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor' AND [t].[name]=N'SqlServerLifecycleCatalog'
)
BEGIN
    EXEC(N'
CREATE TABLE [monitor].[SqlServerLifecycleCatalog]
(
      [ProductMajorVersion] int NOT NULL
    , [ProductName] nvarchar(64) COLLATE DATABASE_DEFAULT NOT NULL
    , [StartDate] date NOT NULL
    , [MainstreamEndDate] date NOT NULL
    , [ExtendedEndDate] date NOT NULL
    , [LifecyclePolicy] varchar(32) COLLATE DATABASE_DEFAULT NOT NULL
    , [LifecycleUrl] nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL
    , [CatalogAsOfDate] date NOT NULL
    , [SourceRetrievedAtUtc] datetime2(0) NOT NULL
    , CONSTRAINT [PK_SqlServerLifecycleCatalog] PRIMARY KEY ([ProductMajorVersion])
);');
END;
GO

-- DEPLOYMENT_PREFLIGHT_BEGIN
CREATE TABLE #SqlServerLifecycleCatalog_Seed
(
      [ProductMajorVersion] int NOT NULL PRIMARY KEY
    , [ProductName] nvarchar(64) COLLATE DATABASE_DEFAULT NOT NULL
    , [StartDate] date NOT NULL
    , [MainstreamEndDate] date NOT NULL
    , [ExtendedEndDate] date NOT NULL
    , [LifecyclePolicy] varchar(32) COLLATE DATABASE_DEFAULT NOT NULL
    , [LifecycleUrl] nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL
    , [CatalogAsOfDate] date NOT NULL
    , [SourceRetrievedAtUtc] datetime2(0) NOT NULL
);

INSERT #SqlServerLifecycleCatalog_Seed VALUES
 (15,N'SQL Server 2019','2019-11-04','2025-02-28','2030-01-08','FIXED',N'https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2019','2026-07-21','2026-07-21T06:30:00')
,(16,N'SQL Server 2022','2022-11-16','2028-01-11','2033-01-11','FIXED',N'https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2022','2026-07-21','2026-07-21T06:30:00')
,(17,N'SQL Server 2025','2025-11-18','2031-01-06','2036-01-06','FIXED',N'https://learn.microsoft.com/en-us/lifecycle/products/sql-server-2025','2026-07-21','2026-07-21T06:30:00');

/* Markerlose Abweichungen werden vor einer Änderung kontrolliert abgewiesen. */
IF EXISTS
(
    SELECT 1 FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor' AND [t].[name]=N'SqlServerLifecycleCatalog'
)
BEGIN
 EXEC [sys].[sp_executesql] N'
IF EXISTS
(
 SELECT 1
 FROM [monitor].[SqlServerLifecycleCatalog] AS [target]
 JOIN #SqlServerLifecycleCatalog_Seed AS [source] ON [source].[ProductMajorVersion]=[target].[ProductMajorVersion]
 WHERE EXISTS
 (
  SELECT CONVERT(varbinary(max),[target].[ProductMajorVersion]),CONVERT(varbinary(max),[target].[ProductName]),
         CONVERT(varbinary(max),[target].[StartDate]),CONVERT(varbinary(max),[target].[MainstreamEndDate]),
         CONVERT(varbinary(max),[target].[ExtendedEndDate]),CONVERT(varbinary(max),[target].[LifecyclePolicy]),
         CONVERT(varbinary(max),[target].[LifecycleUrl]),CONVERT(varbinary(max),[target].[CatalogAsOfDate]),
         CONVERT(varbinary(max),[target].[SourceRetrievedAtUtc])
  EXCEPT
  SELECT CONVERT(varbinary(max),[source].[ProductMajorVersion]),CONVERT(varbinary(max),[source].[ProductName]),
         CONVERT(varbinary(max),[source].[StartDate]),CONVERT(varbinary(max),[source].[MainstreamEndDate]),
         CONVERT(varbinary(max),[source].[ExtendedEndDate]),CONVERT(varbinary(max),[source].[LifecyclePolicy]),
         CONVERT(varbinary(max),[source].[LifecycleUrl]),CONVERT(varbinary(max),[source].[CatalogAsOfDate]),
         CONVERT(varbinary(max),[source].[SourceRetrievedAtUtc])
 )
)
 THROW 53932,N''Markerless lifecycle catalog conflict.'',1;';
END;
-- DEPLOYMENT_PREFLIGHT_END

INSERT [monitor].[SqlServerLifecycleCatalog]
([ProductMajorVersion],[ProductName],[StartDate],[MainstreamEndDate],[ExtendedEndDate],
 [LifecyclePolicy],[LifecycleUrl],[CatalogAsOfDate],[SourceRetrievedAtUtc])
SELECT [source].*
FROM #SqlServerLifecycleCatalog_Seed AS [source]
WHERE NOT EXISTS
(
    SELECT 1 FROM [monitor].[SqlServerLifecycleCatalog] AS [target]
    WHERE [target].[ProductMajorVersion]=[source].[ProductMajorVersion]
);
DROP TABLE #SqlServerLifecycleCatalog_Seed;
GO
