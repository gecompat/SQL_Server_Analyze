USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.SnapshotTargetConfiguration
Version      : 1.0.0
Stand        : 2026-07-21
Zweck        : Die Tabelle konfiguriert das Ziel des optionalen SC-023-Pakets
               im Frameworksystem. Sie beschreibt es mit TargetDatabaseName;
               das Frameworksystem enthält die Konfiguration.
Felder       : ConfigurationId ist der Schlüssel und auf 1 begrenzt.
               TargetDatabaseName ist der generische Name der Zieldatenbank.
               IsEnabled schaltet die Konfiguration.
               DefaultSchedulerType erlaubt MANUAL, EXTERNAL oder SQL_AGENT.
               PackageContractVersion muss mindestens 1 sein.
               SeedVersion kennzeichnet den Seed; sein Default ist 0, der
               Repository-Seed setzt 1.
               LastUpdatedUtc erhält beim Einfügen standardmäßig die UTC-Zeit;
               spätere Änderungen aktualisieren den Wert nicht automatisch.
               RowVersion ist ein von SQL Server erzeugter Versionswert und
               keine Uhrzeit oder Seed-Version.
Voraussetzung : Die Tabelle hat einen Primärschlüssel auf ConfigurationId und
               eine Singleton-Prüfung auf den Wert 1. Dadurch ist höchstens
               eine Zeile zulässig; eine Zeile ist nicht garantiert. Die Tabelle
               bleibt bis zum Einfügen des Seeds leer.
Verhalten    : Das Skript legt die Tabelle nur an, wenn sie fehlt. Es migriert
               oder repariert keine vorhandene Tabelle. Der Seed fügt nur die
               fehlende Zeile mit ConfigurationId=1 ein; eine vorhandene Zeile
               bleibt unverändert. Der Seed verwendet den generischen Namen
               SQL_Server_Analyze_History, IsEnabled=0, EXTERNAL,
               PackageContractVersion=1 und SeedVersion=1. Das Repository
               speichert keine tatsächlichen privaten Zielnamen.
Grenzen      : TargetDatabaseName ist NOT NULL; das Skript prüft nicht, ob die
               benannte Datenbank existiert. IsEnabled belegt keine Ausführung.
               Das Skript erstellt weder Zieldatenbank noch Zeitpläne, Jobs,
               Collector oder Berechtigungen. Sie prüft auch keine
               Ausführungscapability.
               Die GO-Batches enthalten keine eigene Transaktionsgarantie.
Lesehinweis  : Die vorhandene Konfiguration kann mit folgendem Beispiel gelesen
               werden:
               SELECT [ConfigurationId], [TargetDatabaseName], [IsEnabled],
                      [DefaultSchedulerType], [PackageContractVersion],
                      [SeedVersion], [LastUpdatedUtc], [RowVersion]
               FROM [monitor].[SnapshotTargetConfiguration] WITH (NOLOCK);
===============================================================================
*/
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor'
      AND [t].[name]=N'SnapshotTargetConfiguration'
)
BEGIN
    CREATE TABLE [monitor].[SnapshotTargetConfiguration]
    (
          [ConfigurationId] tinyint NOT NULL
        , [TargetDatabaseName] sysname NOT NULL
        , [IsEnabled] bit NOT NULL
            CONSTRAINT [DF_SnapshotTargetConfiguration_IsEnabled] DEFAULT (0)
        , [DefaultSchedulerType] varchar(16) NOT NULL
            CONSTRAINT [DF_SnapshotTargetConfiguration_DefaultSchedulerType] DEFAULT ('EXTERNAL')
        , [PackageContractVersion] int NOT NULL
            CONSTRAINT [DF_SnapshotTargetConfiguration_PackageContractVersion] DEFAULT (1)
        , [SeedVersion] int NOT NULL
            CONSTRAINT [DF_SnapshotTargetConfiguration_SeedVersion] DEFAULT (0)
        , [LastUpdatedUtc] datetime2(3) NOT NULL
            CONSTRAINT [DF_SnapshotTargetConfiguration_LastUpdatedUtc] DEFAULT (SYSUTCDATETIME())
        , [RowVersion] rowversion NOT NULL
        , CONSTRAINT [PK_SnapshotTargetConfiguration]
            PRIMARY KEY CLUSTERED ([ConfigurationId])
        , CONSTRAINT [CK_SnapshotTargetConfiguration_Singleton]
            CHECK ([ConfigurationId]=1)
        , CONSTRAINT [CK_SnapshotTargetConfiguration_Scheduler]
            CHECK ([DefaultSchedulerType] IN ('MANUAL','EXTERNAL','SQL_AGENT'))
        , CONSTRAINT [CK_SnapshotTargetConfiguration_Contract]
            CHECK ([PackageContractVersion]>=1)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM [monitor].[SnapshotTargetConfiguration]
    WHERE [ConfigurationId]=1
)
BEGIN
    INSERT [monitor].[SnapshotTargetConfiguration]
    (
          [ConfigurationId]
        , [TargetDatabaseName]
        , [IsEnabled]
        , [DefaultSchedulerType]
        , [PackageContractVersion]
        , [SeedVersion]
    )
    VALUES
    (1,N'SQL_Server_Analyze_History',0,'EXTERNAL',1,1);
END;
GO
