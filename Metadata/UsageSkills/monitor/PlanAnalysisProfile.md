---
skill_format_version: "1.0.0"
name: "monitor.PlanAnalysisProfile"
schema_name: "monitor"
object_name: "PlanAnalysisProfile"
object_type: "TABLE"
database_role: "framework"
is_internal: false
description: "Das Skript legt generische Workloadprofile für die Execution-Plan-Analyse an und pflegt die ausgelieferten Frameworkprofile."
source_path: "Code/04_PlanCache/041_PlanAnalysisProfile.sql"
---

# monitor.PlanAnalysisProfile

## Zweck und Einsatz

Das Skript legt generische Workloadprofile für die Execution-Plan-Analyse an und pflegt die ausgelieferten Frameworkprofile.

## Voraussetzungen und Rechte

Das Schema [monitor] und die Zieltabelle müssen in der durch USE gewählten Datenbank angelegt werden können.

Lesender Einsatz erfordert SELECT auf [monitor].[PlanAnalysisProfile]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:

```sql
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
    )
```


## Beispiel

```sql
SELECT [ProfileCode],[IsEnabled],[Priority]
FROM [monitor].[PlanAnalysisProfile] WITH (NOLOCK);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

