---
skill_format_version: "1.0.0"
name: "monitor.SqlServerBuildCatalog"
schema_name: "monitor"
object_name: "SqlServerBuildCatalog"
object_type: "TABLE"
database_role: "framework"
is_internal: false
description: "Das Skript legt bei Bedarf den Buildkatalog an und ergänzt die dokumentierten SQL-Server-Builds als offline auswertbaren Metadatensnapshot für SQL Server 2019, 2022 und 2025."
source_path: "Code/09_VersionAdaptive/011_SqlServerBuildCatalog.sql"
---

# monitor.SqlServerBuildCatalog

## Zweck und Einsatz

Das Skript legt bei Bedarf den Buildkatalog an und ergänzt die dokumentierten SQL-Server-Builds als offline auswertbaren Metadatensnapshot für SQL Server 2019, 2022 und 2025.

## Voraussetzungen und Rechte

Im aktuellen Datenbankkontext muss das Schema [monitor] vorhanden sein. Das Skript ist dort mit ausreichenden Rechten für die Katalogabfrage, Tabellenerstellung und Seed-Inserts auszuführen.

Lesender Einsatz erfordert SELECT auf [monitor].[SqlServerBuildCatalog]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:

```sql
(
      [BuildVersion] varchar(32) COLLATE DATABASE_DEFAULT NOT NULL
    , [ProductMajorVersion] int NOT NULL
    , [BuildNumber] int NOT NULL
    , [RevisionNumber] int NOT NULL
    , [ReleaseName] nvarchar(64) COLLATE DATABASE_DEFAULT NOT NULL
    , [ServicingBranch] varchar(16) COLLATE DATABASE_DEFAULT NOT NULL
    , [KnowledgeBaseNumber] varchar(16) COLLATE DATABASE_DEFAULT NULL
    , [ReleaseDate] date NOT NULL
    , [PlatformScope] varchar(32) COLLATE DATABASE_DEFAULT NOT NULL
    , [IsSecurityRelease] bit NOT NULL
    , [IsLatestInBranch] bit NOT NULL
    , [BuildOverviewUrl] nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL
    , [KnowledgeBaseUrl] nvarchar(512) COLLATE DATABASE_DEFAULT NULL
    , [CatalogAsOfDate] date NOT NULL
    , [PrimarySourceUrl] nvarchar(512) COLLATE DATABASE_DEFAULT NOT NULL
    , [SourceRetrievedAtUtc] datetime2(0) NOT NULL
    , CONSTRAINT [PK_SqlServerBuildCatalog] PRIMARY KEY ([BuildVersion])
    , CONSTRAINT [CK_SqlServerBuildCatalog_Branch]
      CHECK ([ServicingBranch] IN (''RTM'',''CU'',''GDR'',''CU_GDR'',''OD''))
)
```


## Beispiel

```sql
SELECT [BuildVersion], [ReleaseName], [ServicingBranch], [ReleaseDate], [IsSecurityRelease], [IsLatestInBranch], [CatalogAsOfDate], [SourceRetrievedAtUtc] FROM [monitor].[SqlServerBuildCatalog] WITH (NOLOCK) WHERE [ProductMajorVersion] = 17;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die Tabelle wird nur angelegt, wenn sie fehlt; vorhandene Tabellen werden nicht migriert oder allgemein repariert. Vorhandene Seed-Schlüssel werden feldweise bytegenau geprüft. Abweichungen lösen Fehler 53931 aus. Übereinstimmende Schlüssel bleiben bestehen, andere vorhandene Zeilen bleiben erhalten und nur fehlende Seed-Schlüssel werden eingefügt. Es gibt kein UPDATE, DELETE oder Ownershipmarker. Die Prüfung ist keine Zusage einer atomaren Gesamtausführung; GO trennt Batches.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.SqlServerBuildCatalog
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Framework-Metadatentabelle und Seed
Zweck        : Das Skript legt bei Bedarf den Buildkatalog an und ergänzt die
               dokumentierten SQL-Server-Builds als offline auswertbaren
               Metadatensnapshot für SQL Server 2019, 2022 und 2025.
Voraussetzung: Im aktuellen Datenbankkontext muss das Schema [monitor]
               vorhanden sein. Das Skript ist dort mit ausreichenden Rechten
               für die Katalogabfrage, Tabellenerstellung und Seed-Inserts
               auszuführen.
Quelle       : Microsoft SQL Server build versions; Abruf 2026-07-21.
Zeitbezug    : [CatalogAsOfDate] und [SourceRetrievedAtUtc] sind feste Werte
               des am 2026-07-21 abgerufenen Seeds. Sie bezeichnen dessen
               dokumentierten Snapshot und Abrufzeit, keine Onlineprüfung.
Grenze       : Enthalten sind ausgewählte Builds, keine vollständige oder
               aktuelle Releasehistorie. [IsLatestInBranch] ist ein fixer
               Seedwert dieses Snapshots, keine Laufzeitermittlung. Der
               Katalog beweist weder installierte Patches noch aktuelle
               Sicherheits-, Support- oder Freigabeberechtigung.
Verhalten    : Die Tabelle wird nur angelegt, wenn sie fehlt; vorhandene
               Tabellen werden nicht migriert oder allgemein repariert.
               Vorhandene Seed-Schlüssel werden feldweise bytegenau geprüft.
               Abweichungen lösen Fehler 53931 aus. Übereinstimmende Schlüssel
               bleiben bestehen, andere vorhandene Zeilen bleiben erhalten
               und nur fehlende Seed-Schlüssel werden eingefügt. Es gibt kein
               UPDATE, DELETE oder Ownershipmarker. Die Prüfung ist keine
               Zusage einer atomaren Gesamtausführung; GO trennt Batches.
Beispiel     : SELECT [BuildVersion], [ReleaseName], [ServicingBranch],
                      [ReleaseDate], [IsSecurityRelease], [IsLatestInBranch],
                      [CatalogAsOfDate], [SourceRetrievedAtUtc]
               FROM [monitor].[SqlServerBuildCatalog] WITH (NOLOCK)
               WHERE [ProductMajorVersion] = 17;
Felder       : Schlüssel und Buildidentität: [BuildVersion] varchar(32) ist
               Primärschlüssel; [ProductMajorVersion] int, [BuildNumber] int
               und [RevisionNumber] int zerlegen die Buildnummer.
               Releasezuordnung: [ReleaseName] nvarchar(64) benennt RTM/CU/
               GDR-Kombinationen; [ServicingBranch] varchar(16) wird durch
               CHECK auf RTM, CU, GDR, CU_GDR oder OD begrenzt;
               [KnowledgeBaseNumber] varchar(16) ist optional; [ReleaseDate]
               date und [PlatformScope] varchar(32) beschreiben Seeddatum
               und Plattformumfang.
               Einordnung und Verweise: [IsSecurityRelease] bit kennzeichnet
               den Seedstatus; [IsLatestInBranch] bit speichert die
               Snapshot-Einordnung; [BuildOverviewUrl] nvarchar(512) verweist
               auf die Buildübersicht; [KnowledgeBaseUrl] nvarchar(512) ist
               optional.
               Provenienz: [CatalogAsOfDate] date hält den Stand des
               Katalogsnapshots fest; [PrimarySourceUrl] nvarchar(512)
               speichert dessen Hauptquelle; [SourceRetrievedAtUtc]
               datetime2(0) speichert die Abrufzeit in UTC. Die Textfelder
               verwenden DATABASE_DEFAULT.
```

