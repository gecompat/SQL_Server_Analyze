---
skill_format_version: "1.0.0"
name: "monitor.WaitTypeCatalogSource"
schema_name: "monitor"
object_name: "WaitTypeCatalogSource"
object_type: "TABLE"
database_role: "framework"
is_internal: false
description: "Das Skript legt den Wait-Type-Katalog und seine typisierten Quellenangaben an und ergänzt ausgewählte fehlende Katalogspalten."
source_path: "Code/01_Common/074_WaitTypeCatalog.sql"
---

# monitor.WaitTypeCatalogSource

## Zweck und Einsatz

Das Skript legt den Wait-Type-Katalog und seine typisierten Quellenangaben an und ergänzt ausgewählte fehlende Katalogspalten.

## Voraussetzungen und Rechte

Lesender Einsatz erfordert SELECT auf [monitor].[WaitTypeCatalogSource]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:

```sql
(
  [WaitType] nvarchar(120) NOT NULL,
  [SourceOrdinal] tinyint NOT NULL,
  [SourceType] varchar(30) NOT NULL,
  [Publisher] nvarchar(120) NOT NULL,
  [SourceTitle] nvarchar(400) NOT NULL,
  [SourceUrl] nvarchar(1000) NOT NULL,
  [SupportsFields] nvarchar(500) NOT NULL,
  [EvidenceLevel] varchar(30) NOT NULL,
  [SourceNotes] nvarchar(1000) NULL,
  [IsFrameworkDefault] bit NOT NULL CONSTRAINT DF_WaitTypeCatalogSource_Default DEFAULT(1),
  [LastVerifiedUtc] datetime2(0) NOT NULL CONSTRAINT DF_WaitTypeCatalogSource_Verified DEFAULT(SYSUTCDATETIME()),
  CONSTRAINT PK_WaitTypeCatalogSource PRIMARY KEY CLUSTERED([WaitType],[SourceOrdinal]),
  CONSTRAINT FK_WaitTypeCatalogSource_WaitType FOREIGN KEY([WaitType]) REFERENCES [monitor].[WaitTypeCatalog]([WaitType]),
  CONSTRAINT CK_WaitTypeCatalogSource_Ordinal CHECK([SourceOrdinal] BETWEEN 1 AND 20)
 )
```


## Beispiel

```sql
SELECT [WaitType],[WaitGroup],[Severity],[AnalysisConfidence]
               FROM [monitor].[WaitTypeCatalog]
               WHERE [IsFrameworkDefault]=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Das zugehörige Installationsskript enthält CREATE TABLE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : [monitor].[WaitTypeCatalog] und [monitor].[WaitTypeCatalogSource]
Version      : 2.2.0
Stand        : 2026-07-20
Zweck        : Das Skript legt den Wait-Type-Katalog und seine typisierten
               Quellenangaben an und ergänzt ausgewählte fehlende Katalogspalten.
Vertrag      : Die Katalogtabelle verwendet [WaitType] als gruppierten Primärschlüssel
               und enthält [WaitType], [WaitGroup], [Severity], [IsGenerallyBenign],
               [Meaning], [TypicalOccurrence], [HighWaitImpact], [RecommendedChecks],
               [DefaultAssessment], [AssessmentBasis], [CommonCauses],
               [PerformanceImpact], [Mitigation], [CounterEvidence],
               [RelatedWaitTypes], [MeasurementGuidance], [AnalysisConfidence],
               [HelpUrl], [MinProductMajorVersion], [DescriptionSource],
               [DescriptionQuality], [SourceReference], [IsFrameworkDefault] und
               [LastUpdatedUtc]. Die Quellentabelle enthält [WaitType],
               [SourceOrdinal], [SourceType], [Publisher], [SourceTitle], [SourceUrl],
               [SupportsFields], [EvidenceLevel], [SourceNotes], [IsFrameworkDefault]
               und [LastVerifiedUtc].
               [Severity] ist auf 0 bis 5 beschränkt; Assessment- und Analysefelder
               erhalten benannte Defaults. Die Quellentabelle verwendet
               ([WaitType],[SourceOrdinal]) als Primärschlüssel, verweist per
               Fremdschlüssel auf den Katalog und beschränkt die Ordinalzahl auf
               1 bis 20. Defaults setzen Severity auf 1, das Benign- und
               Frameworkkennzeichen auf 0 beziehungsweise 1, die Assessmentwerte
               auf CONTEXT_DEPENDENT und FAMILY_INFERENCE sowie die Felder für
               Basis, Ursachen, Wirkung, Gegenbeleg, Gegenmaßnahme und Messhinweis
               auf erläuternde Standardtexte. LastUpdatedUtc und LastVerifiedUtc
               erhalten SYSUTCDATETIME() beim Einfügen. Das DDL setzt die Datenbank
               aus USE und das Schema [monitor] voraus.
Erweiterung  : Bei einer vorhandenen Katalogtabelle ergänzt das Skript nur die
               zwölf ausdrücklich geprüften fehlenden Spalten. Es repariert keine
               anderen Spalten, Schlüssel oder Constraints und migriert keine
               vorhandene Quellentabelle. Tabellen werden nur angelegt, wenn sie
               fehlen; vorhandene Objekte werden nicht strukturell abgeglichen.
Eigentum     : [IsFrameworkDefault]=1 kennzeichnet Frameworkzeilen. Benutzerdefinierte
               Zeilen mit Wert 0 sind davon getrennt; die nachfolgenden Seeds
               aktualisieren vorhandene Zeilen nur, wenn sie als Frameworkzeilen
               markiert sind. Das ist keine allgemeine Erhaltungsgarantie, da
               Seed-Einfügungen und spätere Skripte eigene Effekte haben.
Beispiele    : Die folgenden Abfragen lesen die gespeicherten Katalogfelder und
               die zugeordneten Quellen; sie belegen weder Laufzeitwaits noch
               externe Aktualität einer Quelle.
               SELECT [WaitType],[WaitGroup],[Severity],[AnalysisConfidence]
               FROM [monitor].[WaitTypeCatalog]
               WHERE [IsFrameworkDefault]=1;
               SELECT [WaitType],[SourceOrdinal],[SourceType],[Publisher],[SourceUrl],
                      [EvidenceLevel],[LastVerifiedUtc]
               FROM [monitor].[WaitTypeCatalogSource]
               WHERE [WaitType]=N'WRITELOG';
Hinweis      : Framework-HelpUrls verweisen auf SQLskills. Inhalte werden nicht
               kopiert; ein Link ist keine Übernahme oder unabhängige Verifikation.
```

