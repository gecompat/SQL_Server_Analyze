USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.FrameworkVersion
Version      : 1.1.2
Stand        : 2026-10-23
Zweck        : Speichert kompakte Versionsdeklarationen des Analysepakets in
               [monitor].[FrameworkVersion]. Voraussetzung ist das zuvor durch
               000_Preflight_und_Schema.sql bereitgestellte Schema monitor.
               FrameworkName ist der Primärschlüssel; er begrenzt Schlüsselwerte,
               erzwingt aber keine globale Beschränkung auf eine Tabellenzeile.
Tabellenform : FrameworkName sysname NOT NULL ist der Primärschlüssel.
               FrameworkVersion varchar(32) NOT NULL enthält die deklarierte
               Paketversion; ReleaseDate date NOT NULL das deklarierte Datum;
               MinimumProductMajorVersion int NOT NULL die deklarierte Mindest-
               Majorversion; ContractVersion varchar(16) NOT NULL die deklarierte
               Vertragsversion; LastInstalledUtc datetime2(0) NOT NULL den UTC-
               Zeitstempel dieses Skript-UPDATE oder -INSERT; ReleaseNotes
               nvarchar(2000) NULL enthält optionale Versionshinweise.
Seiteneffekte: Die Tabelle wird nur angelegt, wenn sie fehlt. Eine vorhandene
               Tabelle oder ein vorhandenes Schema wird nicht migriert oder auf
               Struktur, Ownership und Berechtigungen validiert. Das UPDATE setzt
               ausschließlich SQLServerMonitoringFramework; falls keine Zeile
               getroffen wurde, fügt das Skript diesen Namen ein. Andere Namen
               bleiben erhalten. Release-, Vertrags- und Mindestversionswerte sind
               fest deklarierte Paketangaben und keine Prüfung der Engineversion.
               LastInstalledUtc wird bei jedem erneuten UPDATE/INSERT neu gesetzt.
               Der Wert belegt weder den Abschluss des Gesamtpakets noch Rollback,
               Installationshistorie oder eine vertrauenswürdige Attestierung.
Beispiel     : Die folgende lesende Abfrage zeigt die tatsächlichen gespeicherten
               Werte des kanonischen Framework-Eintrags; sie setzt voraus, dass
               Schema und Tabelle vorhanden und für den Aufrufer sichtbar sind:
               SELECT [FrameworkName], [FrameworkVersion], [ReleaseDate],
                      [MinimumProductMajorVersion], [ContractVersion],
                      [LastInstalledUtc], [ReleaseNotes]
               FROM [monitor].[FrameworkVersion] WITH (NOLOCK)
               WHERE [FrameworkName] = N'SQLServerMonitoringFramework';
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
SET [FrameworkVersion]='1.1.2',
    [ReleaseDate]='20261023',
    [MinimumProductMajorVersion]=15,
    [ContractVersion]='1.24',
    [LastInstalledUtc]=SYSUTCDATETIME(),
    [ReleaseNotes]=N'Release 1.1.2 ergänzt bei abgefangenen TABLE-Export-Lock-Timeouts die Zieltabelle und den SQL-Teilschritt. API 1.24 einschließlich SQL25-005 bleibt erhalten.'
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
        N'SQLServerMonitoringFramework','1.1.2','20261023',15,
        '1.24',SYSUTCDATETIME(),
        N'Release 1.1.2 ergänzt bei abgefangenen TABLE-Export-Lock-Timeouts die Zieltabelle und den SQL-Teilschritt. API 1.24 einschließlich SQL25-005 bleibt erhalten.'
    );
END;
GO
