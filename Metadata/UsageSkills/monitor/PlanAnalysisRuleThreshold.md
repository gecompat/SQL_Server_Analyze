---
skill_format_version: "1.0.0"
name: "monitor.PlanAnalysisRuleThreshold"
schema_name: "monitor"
object_name: "PlanAnalysisRuleThreshold"
object_type: "TABLE"
database_role: "framework"
is_internal: false
description: "Das Skript legt Datenwerte für plananalytische Schwellen an und pflegt die ausgelieferten Frameworkwerte."
source_path: "Code/04_PlanCache/042_PlanAnalysisRuleThreshold.sql"
---

# monitor.PlanAnalysisRuleThreshold

## Zweck und Einsatz

Das Skript legt Datenwerte für plananalytische Schwellen an und pflegt die ausgelieferten Frameworkwerte. Die ausführbare Regellogik verbleibt im geprüften T-SQL-Code.

## Voraussetzungen und Rechte

Das Schema [monitor] sowie [monitor].[PlanAnalysisProfile] müssen in der durch USE gewählten Datenbank verfügbar sein.

Lesender Einsatz erfordert SELECT auf [monitor].[PlanAnalysisRuleThreshold]; Installation und Aktualisierung benötigen die im Quellskript gezeigten DDL- und DML-Rechte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

Tabellenspalten und Constraints aus der eigenen CREATE-TABLE-Definition:

```sql
(
          [RuleCode]                    varchar(100)  NOT NULL
        , [ProfileCode]                 varchar(32)   NOT NULL
        , [Severity]                    varchar(16)   NOT NULL
        , [IsEnabled]                   bit           NOT NULL
            CONSTRAINT [DF_PlanAnalysisRuleThreshold_IsEnabled] DEFAULT (1)
        , [MinRatio]                    decimal(19,6) NULL
        , [MaxRatio]                    decimal(19,6) NULL
        , [MinAbsoluteRows]             bigint        NULL
        , [MinRowsRead]                 bigint        NULL
        , [MinRowsNotReturned]          bigint        NULL
        , [MinRowsNotReturnedPercent]   decimal(9,4)  NULL
        , [MinExecutionCount]           bigint        NULL
        , [MinLogicalReadsPerExecution] bigint        NULL
        , [MinTotalLogicalReads]        bigint        NULL
        , [MinElapsedMs]                bigint        NULL
        , [MinCpuMs]                    bigint        NULL
        , [MinSpilledPages]             bigint        NULL
        , [MinMemoryKb]                 bigint        NULL
        , [MinServerMajorVersion]       tinyint       NULL
        , [MinCompatibilityLevel]       smallint      NULL
        , [RequiredEvidenceLevel]       varchar(32)   NULL
        , [AdditionalConfigurationJson] nvarchar(max) NULL
        , [IsFrameworkDefault]          bit           NOT NULL
            CONSTRAINT [DF_PlanAnalysisRuleThreshold_IsFrameworkDefault] DEFAULT (0)
        , [SeedVersion]                 int            NOT NULL
            CONSTRAINT [DF_PlanAnalysisRuleThreshold_SeedVersion] DEFAULT (0)
        , [LastUpdatedUtc]              datetime2(0)   NOT NULL
            CONSTRAINT [DF_PlanAnalysisRuleThreshold_LastUpdatedUtc] DEFAULT (SYSUTCDATETIME())
        , CONSTRAINT [PK_PlanAnalysisRuleThreshold]
            PRIMARY KEY CLUSTERED ([RuleCode],[ProfileCode],[Severity])
        , CONSTRAINT [FK_PlanAnalysisRuleThreshold_Profile]
            FOREIGN KEY ([ProfileCode])
            REFERENCES [monitor].[PlanAnalysisProfile]([ProfileCode])
        , CONSTRAINT [CK_PlanAnalysisRuleThreshold_Severity]
            CHECK ([Severity] IN ('INFO','LOW','MEDIUM','HIGH','CRITICAL'))
        , CONSTRAINT [CK_PlanAnalysisRuleThreshold_Json]
            CHECK ([AdditionalConfigurationJson] IS NULL OR ISJSON([AdditionalConfigurationJson])=1)
    )
```


## Beispiel

```sql
SELECT [RuleCode],[ProfileCode],[Severity],[IsEnabled],[MinRatio],[MaxRatio]
FROM [monitor].[PlanAnalysisRuleThreshold] WITH (NOLOCK);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Das zugehörige Installationsskript enthält CREATE TABLE, INSERT, UPDATE; ein lesendes SELECT führt diese Installationsschritte nicht aus. Constraints und NULL-Grenzen stehen in der Tabellendefinition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.PlanAnalysisRuleThreshold
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Steuertabelle
Zweck        : Das Skript legt Datenwerte für plananalytische Schwellen an und
               pflegt die ausgelieferten Frameworkwerte. Die ausführbare
               Regellogik verbleibt im geprüften T-SQL-Code.
Voraussetzung: Das Schema [monitor] sowie [monitor].[PlanAnalysisProfile]
               müssen in der durch USE gewählten Datenbank verfügbar sein.
Spalten      : RuleCode identifiziert eine Regel als varchar(100), ProfileCode
               verweist als varchar(32) auf ein Profil, und Severity bezeichnet
               die Stufe als varchar(16). IsEnabled schaltet den Datensatz mit
               bit ein oder aus. MinRatio und MaxRatio sind optionale
               decimal(19,6)-Grenzen. MinAbsoluteRows, MinRowsRead,
               MinRowsNotReturned, MinExecutionCount, MinLogicalReadsPerExecution,
               MinTotalLogicalReads, MinElapsedMs, MinCpuMs, MinSpilledPages und
               MinMemoryKb sind optionale bigint-Schwellen.
               MinRowsNotReturnedPercent ist optionales decimal(9,4).
               MinServerMajorVersion ist tinyint und MinCompatibilityLevel
               smallint; beide sind optionale Mindestwerte. RequiredEvidenceLevel
               ist ein optionaler varchar(32)-Wert. AdditionalConfigurationJson
               enthält optionalen nvarchar(max)-JSON-Text. IsFrameworkDefault
               kennzeichnet Frameworkbesitz mit bit, SeedVersion speichert die
               int-Version und LastUpdatedUtc speichert datetime2(0) in UTC.
Schlüssel    : Der gruppierte Primärschlüssel besteht aus RuleCode, ProfileCode
               und Severity. ProfileCode besitzt einen Fremdschlüssel auf
               [monitor].[PlanAnalysisProfile]([ProfileCode]). Severity ist auf
               INFO, LOW, MEDIUM, HIGH oder CRITICAL beschränkt. JSON darf NULL
               sein; andernfalls muss ISJSON den Wert als JSON erkennen. Es ist
               kein weiterer Index definiert. Defaults setzen IsEnabled auf 1,
               IsFrameworkDefault und SeedVersion auf 0 sowie LastUpdatedUtc
               auf SYSUTCDATETIME().
Schwellen    : NULL bedeutet zunächst nur, dass im gespeicherten Feld kein Wert
               steht. Ob eine Regel ein NULL-Feld ignoriert, durch 0 ersetzt
               oder anders behandelt, ergibt sich ausschließlich aus dem
               jeweiligen Verbraucher im T-SQL-Code. Die Regelinterpretation
               und die Bedeutung von JSON-Eigenschaften sind regelbezogen;
               JSON-Daten führen keinen Code aus und sind keine
               Ausführungs- oder Sicherheitsfreigabe. Die ausgelieferten Werte
               sind Triageheuristiken, keine Microsoft-Grenzwerte und keine
               automatische Tuninganweisung.
Seed         : Fehlende Frameworkschwellen werden mit IsEnabled=1,
               IsFrameworkDefault=1 und SeedVersion=1 eingefügt. Das Seed
               aktualisiert bei Frameworkzeilen mit älterer SeedVersion die
               Schwellenfelder MinRatio, MaxRatio, MinAbsoluteRows, MinRowsRead,
               MinRowsNotReturned, MinRowsNotReturnedPercent,
               MinExecutionCount, MinLogicalReadsPerExecution,
               MinTotalLogicalReads, MinElapsedMs, MinCpuMs, MinSpilledPages,
               MinMemoryKb, RequiredEvidenceLevel und
               AdditionalConfigurationJson sowie SeedVersion und
               LastUpdatedUtc. Schlüssel, Severity, IsEnabled,
               MinServerMajorVersion, MinCompatibilityLevel und
               IsFrameworkDefault werden nicht aktualisiert. Lokale Zeilen
               bleiben unverändert; ein vorhandener Schlüssel ohne
               Frameworkbesitz wird nicht aktualisiert und verhindert das
               Einfügen desselben Schlüssels. LastUpdatedUtc erhält beim
               Einfügen seinen Default und wird bei einem solchen Seedupdate
               neu gesetzt; sonstige Änderungen lösen keine automatische
               Zeitstempelpflege aus.
Beispiel     : Die Abfrage zeigt Regel, Profil, Stufe, Aktivierung und einige
               Schwellenwerte. Sie führt keine Regel aus.
===============================================================================
SELECT [RuleCode],[ProfileCode],[Severity],[IsEnabled],[MinRatio],[MaxRatio]
FROM [monitor].[PlanAnalysisRuleThreshold] WITH (NOLOCK);
```

