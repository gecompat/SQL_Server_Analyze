USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.PlanAnalysisProfile
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Steuertabelle
Zweck        : Das Skript legt generische Workloadprofile für die
               Execution-Plan-Analyse an und pflegt die ausgelieferten
               Frameworkprofile.
Voraussetzung: Das Schema [monitor] und die Zieltabelle müssen in der durch
               USE gewählten Datenbank angelegt werden können.
Spalten      : ProfileCode identifiziert ein Profil als varchar(32). Description
               beschreibt es als nvarchar(1000). Priority legt als smallint
               eine Rangzahl zwischen 1 und 32767 fest. IsEnabled schaltet die
               Profilzeile mit bit ein oder aus. IsFrameworkDefault kennzeichnet
               Frameworkbesitz mit bit. SeedVersion speichert die int-Version
               der Frameworkwerte. LastUpdatedUtc speichert datetime2(0) in UTC.
Schlüssel    : ProfileCode ist der gruppierte Primärschlüssel. Die
               Priority-Prüfung begrenzt den Wert auf 1 bis 32767. Defaults
               setzen IsEnabled auf 1, IsFrameworkDefault und SeedVersion auf
               0 sowie LastUpdatedUtc auf SYSUTCDATETIME().
Seed         : Fehlende Frameworkprofile werden mit IsEnabled=1,
               IsFrameworkDefault=1 und SeedVersion=1 eingefügt. Ein Update
               ändert nur Description, Priority, SeedVersion und
               LastUpdatedUtc, wenn der Schlüssel einem Frameworkdefault
               gehört und dessen SeedVersion kleiner als die ausgelieferte
               Version ist. IsEnabled und lokale Zeilen bleiben unverändert;
               ein vorhandener Schlüssel ohne Frameworkbesitz wird nicht
               aktualisiert und verhindert das Einfügen desselben Schlüssels.
Beispiel     : Die folgende Abfrage zeigt Profilcode, Status und Rang.
               Sie liest keine realen Zuordnungen oder Workloaddaten.
===============================================================================
SELECT [ProfileCode],[IsEnabled],[Priority]
FROM [monitor].[PlanAnalysisProfile] WITH (NOLOCK);
*/
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor'
      AND [t].[name]=N'PlanAnalysisProfile'
)
BEGIN
    CREATE TABLE [monitor].[PlanAnalysisProfile]
    (
          [ProfileCode]        varchar(32)    NOT NULL
        , [Description]        nvarchar(1000) NOT NULL
        , [Priority]           smallint       NOT NULL
        , [IsEnabled]          bit            NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfile_IsEnabled] DEFAULT (1)
        , [IsFrameworkDefault] bit            NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfile_IsFrameworkDefault] DEFAULT (0)
        , [SeedVersion]        int            NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfile_SeedVersion] DEFAULT (0)
        , [LastUpdatedUtc]     datetime2(0)   NOT NULL
            CONSTRAINT [DF_PlanAnalysisProfile_LastUpdatedUtc] DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_PlanAnalysisProfile]
            PRIMARY KEY CLUSTERED ([ProfileCode])
        , CONSTRAINT [CK_PlanAnalysisProfile_Priority]
            CHECK ([Priority] BETWEEN 1 AND 32767)
    );
END;
GO

DECLARE @SeedVersion int=1;
DECLARE @Defaults TABLE
(
      [ProfileCode] varchar(32) NOT NULL PRIMARY KEY
    , [Description] nvarchar(1000) NOT NULL
    , [Priority] smallint NOT NULL
);

INSERT @Defaults([ProfileCode],[Description],[Priority])
VALUES
  ('LATENCY_SENSITIVE',N'Interaktive oder hochfrequente Zugriffe; je Ausführung und Wiederholungsrate werden stärker gewichtet.',100),
  ('BALANCED',N'Neutraler Frameworkstandard für gemischte Workloads ohne belastbare explizite Zuordnung.',200),
  ('THROUGHPUT',N'Mengen- und Durchsatzverarbeitung; absolute CPU-, I/O-, TempDB- und Datenmengen werden stärker gewichtet.',300),
  ('MAINTENANCE',N'Wartungs- und strukturverändernde Verarbeitung; große Scans und Sorts können fachlich erwartet sein.',400),
  ('UNKNOWN',N'Workloadprofil nicht belastbar bestimmbar; Findings bleiben konservativ und weisen die geringe Zuordnungssicherheit aus.',500);

UPDATE [p]
SET
      [p].[Description]=[d].[Description]
    , [p].[Priority]=[d].[Priority]
    , [p].[SeedVersion]=@SeedVersion
    , [p].[LastUpdatedUtc]=SYSUTCDATETIME()
FROM [monitor].[PlanAnalysisProfile] AS [p]
JOIN @Defaults AS [d]
  ON [d].[ProfileCode]=[p].[ProfileCode]
WHERE [p].[IsFrameworkDefault]=1
  AND [p].[SeedVersion]<@SeedVersion;

INSERT [monitor].[PlanAnalysisProfile]
(
      [ProfileCode],[Description],[Priority],[IsEnabled]
    , [IsFrameworkDefault],[SeedVersion]
)
SELECT [d].[ProfileCode],[d].[Description],[d].[Priority],1,1,@SeedVersion
FROM @Defaults AS [d]
WHERE NOT EXISTS
(
    SELECT 1
    FROM [monitor].[PlanAnalysisProfile] AS [p]
    WHERE [p].[ProfileCode]=[d].[ProfileCode]
);
GO
