---
skill_format_version: "1.0.0"
name: "monitor.SqlServerLifecycleCatalog"
schema_name: "monitor"
object_name: "SqlServerLifecycleCatalog"
object_type: "TABLE"
database_role: "framework"
is_internal: false
description: "Das Skript legt bei Bedarf den Lifecyclekatalog an und ergänzt die dokumentierten SQL-Server-Produktlebenszyklen als offline auswertbaren Metadatensnapshot."
source_path: "Code/09_VersionAdaptive/012_SqlServerLifecycleCatalog.sql"
---

# monitor.SqlServerLifecycleCatalog

## Zweck und Einsatz

Das Skript legt bei Bedarf den Lifecyclekatalog an und ergänzt die dokumentierten SQL-Server-Produktlebenszyklen als offline auswertbaren Metadatensnapshot.

## Voraussetzungen und Rechte

Im aktuellen Datenbankkontext muss das Schema [monitor] vorhanden sein. Das Skript ist dort mit ausreichenden Rechten für die Katalogabfrage, Tabellenerstellung und Seed-Inserts auszuführen.

Lesender Einsatz erfordert SELECT auf [monitor].[SqlServerLifecycleCatalog]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:

```sql
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
)
```


## Beispiel

```sql
SELECT [ProductMajorVersion], [ProductName], [StartDate], [MainstreamEndDate], [ExtendedEndDate], [LifecyclePolicy], [CatalogAsOfDate], [SourceRetrievedAtUtc] FROM [monitor].[SqlServerLifecycleCatalog] WITH (NOLOCK) WHERE [ProductMajorVersion] = 17;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die Tabelle wird nur angelegt, wenn sie fehlt; vorhandene Tabellen werden nicht migriert oder allgemein repariert. Vorhandene Seed-Schlüssel werden feldweise bytegenau geprüft. Abweichungen lösen Fehler 53932 aus. Übereinstimmende Schlüssel bleiben bestehen, andere vorhandene Zeilen bleiben erhalten und nur fehlende Seed-Schlüssel werden eingefügt. Es gibt kein UPDATE, DELETE oder Ownershipmarker. Die Prüfung ist keine Zusage einer atomaren Gesamtausführung; GO trennt Batches.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

