USE [DeineDatenbank];
GO

/*
===============================================================================
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
*/
IF NOT EXISTS
(
    SELECT 1
    FROM [sys].[tables] AS [t] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id]=[t].[schema_id]
    WHERE [s].[name]=N'monitor'
      AND [t].[name]=N'PlanAnalysisRuleThreshold'
)
BEGIN
    CREATE TABLE [monitor].[PlanAnalysisRuleThreshold]
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
    );
END;
GO

DECLARE @SeedVersion int=1;
DECLARE @Defaults TABLE
(
      [RuleCode] varchar(100) NOT NULL
    , [ProfileCode] varchar(32) NOT NULL
    , [Severity] varchar(16) NOT NULL
    , [MinRatio] decimal(19,6) NULL
    , [MaxRatio] decimal(19,6) NULL
    , [MinAbsoluteRows] bigint NULL
    , [MinRowsRead] bigint NULL
    , [MinRowsNotReturned] bigint NULL
    , [MinRowsNotReturnedPercent] decimal(9,4) NULL
    , [MinExecutionCount] bigint NULL
    , [MinLogicalReadsPerExecution] bigint NULL
    , [MinTotalLogicalReads] bigint NULL
    , [MinElapsedMs] bigint NULL
    , [MinCpuMs] bigint NULL
    , [MinSpilledPages] bigint NULL
    , [MinMemoryKb] bigint NULL
    , [RequiredEvidenceLevel] varchar(32) NULL
    , [AdditionalConfigurationJson] nvarchar(max) NULL
    , PRIMARY KEY ([RuleCode],[ProfileCode],[Severity])
);

INSERT @Defaults
(
      [RuleCode],[ProfileCode],[Severity],[MinRatio],[MaxRatio]
    , [MinAbsoluteRows],[MinRowsRead],[MinRowsNotReturned]
    , [MinRowsNotReturnedPercent],[MinExecutionCount]
    , [MinLogicalReadsPerExecution],[MinTotalLogicalReads]
    , [MinElapsedMs],[MinCpuMs],[MinSpilledPages],[MinMemoryKb]
    , [RequiredEvidenceLevel],[AdditionalConfigurationJson]
)
VALUES
  ('CARDINALITY_UNDERESTIMATE','LATENCY_SENSITIVE','MEDIUM',3,NULL,100,NULL,NULL,NULL,100,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','LATENCY_SENSITIVE','HIGH',10,NULL,1000,NULL,NULL,NULL,1000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','BALANCED','MEDIUM',10,NULL,1000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','BALANCED','HIGH',100,NULL,10000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','THROUGHPUT','MEDIUM',5,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','THROUGHPUT','HIGH',20,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','MAINTENANCE','MEDIUM',20,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','MAINTENANCE','HIGH',100,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','UNKNOWN','MEDIUM',20,NULL,10000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_UNDERESTIMATE','UNKNOWN','HIGH',200,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','LATENCY_SENSITIVE','MEDIUM',NULL,0.333333,100,NULL,NULL,NULL,100,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','LATENCY_SENSITIVE','HIGH',NULL,0.100000,1000,NULL,NULL,NULL,1000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','BALANCED','MEDIUM',NULL,0.100000,1000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','BALANCED','HIGH',NULL,0.010000,10000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','THROUGHPUT','MEDIUM',NULL,0.200000,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','THROUGHPUT','HIGH',NULL,0.050000,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','MAINTENANCE','MEDIUM',NULL,0.050000,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','MAINTENANCE','HIGH',NULL,0.010000,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','UNKNOWN','MEDIUM',NULL,0.050000,10000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('CARDINALITY_OVERESTIMATE','UNKNOWN','HIGH',NULL,0.005000,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','LATENCY_SENSITIVE','MEDIUM',NULL,NULL,NULL,10000,5000,50,100,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','LATENCY_SENSITIVE','HIGH',NULL,NULL,NULL,100000,50000,90,1000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','BALANCED','MEDIUM',NULL,NULL,NULL,100000,50000,50,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','BALANCED','HIGH',NULL,NULL,NULL,1000000,900000,90,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','THROUGHPUT','MEDIUM',NULL,NULL,NULL,1000000,500000,50,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','THROUGHPUT','HIGH',NULL,NULL,NULL,10000000,9000000,90,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','MAINTENANCE','MEDIUM',NULL,NULL,NULL,10000000,9000000,90,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','MAINTENANCE','HIGH',NULL,NULL,NULL,100000000,95000000,95,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','UNKNOWN','MEDIUM',NULL,NULL,NULL,1000000,900000,90,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('ROWS_READ_NOT_RETURNED','UNKNOWN','HIGH',NULL,NULL,NULL,10000000,9500000,95,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','LATENCY_SENSITIVE','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,1000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','LATENCY_SENSITIVE','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,10000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','BALANCED','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,10000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','BALANCED','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','THROUGHPUT','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','THROUGHPUT','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','MAINTENANCE','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','MAINTENANCE','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','UNKNOWN','MEDIUM',NULL,NULL,NULL,NULL,NULL,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LOOKUP_HIGH_EXECUTIONS','UNKNOWN','HIGH',NULL,NULL,NULL,NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','LATENCY_SENSITIVE','MEDIUM',NULL,NULL,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','LATENCY_SENSITIVE','HIGH',NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','BALANCED','MEDIUM',NULL,NULL,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','BALANCED','HIGH',NULL,NULL,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','THROUGHPUT','MEDIUM',NULL,NULL,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','THROUGHPUT','HIGH',NULL,NULL,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','MAINTENANCE','MEDIUM',NULL,NULL,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','MAINTENANCE','HIGH',NULL,NULL,NULL,1000000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','UNKNOWN','MEDIUM',NULL,NULL,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('LARGE_SCAN','UNKNOWN','HIGH',NULL,NULL,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','LATENCY_SENSITIVE','MEDIUM',4,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,10240,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','BALANCED','MEDIUM',4,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,10240,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','THROUGHPUT','MEDIUM',8,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,102400,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','MAINTENANCE','MEDIUM',16,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,1048576,'RUNTIME_MEASURED',NULL),
  ('MEMORY_GRANT_OVER','UNKNOWN','MEDIUM',8,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,102400,'RUNTIME_MEASURED',NULL),
  ('PARALLEL_THREAD_SKEW','LATENCY_SENSITIVE','MEDIUM',2,NULL,100000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','LATENCY_SENSITIVE','HIGH',4,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','BALANCED','MEDIUM',3,NULL,1000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','BALANCED','HIGH',8,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','THROUGHPUT','MEDIUM',4,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','THROUGHPUT','HIGH',10,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','MAINTENANCE','MEDIUM',8,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','MAINTENANCE','HIGH',20,NULL,1000000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','UNKNOWN','MEDIUM',5,NULL,10000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}'),
  ('PARALLEL_THREAD_SKEW','UNKNOWN','HIGH',12,NULL,100000000,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'RUNTIME_MEASURED',N'{"minimumThreads":4}');

UPDATE [r]
SET
      [r].[MinRatio]=[d].[MinRatio]
    , [r].[MaxRatio]=[d].[MaxRatio]
    , [r].[MinAbsoluteRows]=[d].[MinAbsoluteRows]
    , [r].[MinRowsRead]=[d].[MinRowsRead]
    , [r].[MinRowsNotReturned]=[d].[MinRowsNotReturned]
    , [r].[MinRowsNotReturnedPercent]=[d].[MinRowsNotReturnedPercent]
    , [r].[MinExecutionCount]=[d].[MinExecutionCount]
    , [r].[MinLogicalReadsPerExecution]=[d].[MinLogicalReadsPerExecution]
    , [r].[MinTotalLogicalReads]=[d].[MinTotalLogicalReads]
    , [r].[MinElapsedMs]=[d].[MinElapsedMs]
    , [r].[MinCpuMs]=[d].[MinCpuMs]
    , [r].[MinSpilledPages]=[d].[MinSpilledPages]
    , [r].[MinMemoryKb]=[d].[MinMemoryKb]
    , [r].[RequiredEvidenceLevel]=[d].[RequiredEvidenceLevel]
    , [r].[AdditionalConfigurationJson]=[d].[AdditionalConfigurationJson]
    , [r].[SeedVersion]=@SeedVersion
    , [r].[LastUpdatedUtc]=SYSUTCDATETIME()
FROM [monitor].[PlanAnalysisRuleThreshold] AS [r]
JOIN @Defaults AS [d]
  ON [d].[RuleCode]=[r].[RuleCode]
 AND [d].[ProfileCode]=[r].[ProfileCode]
 AND [d].[Severity]=[r].[Severity]
WHERE [r].[IsFrameworkDefault]=1
  AND [r].[SeedVersion]<@SeedVersion;

INSERT [monitor].[PlanAnalysisRuleThreshold]
(
      [RuleCode],[ProfileCode],[Severity],[IsEnabled]
    , [MinRatio],[MaxRatio],[MinAbsoluteRows],[MinRowsRead]
    , [MinRowsNotReturned],[MinRowsNotReturnedPercent],[MinExecutionCount]
    , [MinLogicalReadsPerExecution],[MinTotalLogicalReads]
    , [MinElapsedMs],[MinCpuMs],[MinSpilledPages],[MinMemoryKb]
    , [RequiredEvidenceLevel],[AdditionalConfigurationJson]
    , [IsFrameworkDefault],[SeedVersion]
)
SELECT
      [d].[RuleCode],[d].[ProfileCode],[d].[Severity],1
    , [d].[MinRatio],[d].[MaxRatio],[d].[MinAbsoluteRows],[d].[MinRowsRead]
    , [d].[MinRowsNotReturned],[d].[MinRowsNotReturnedPercent],[d].[MinExecutionCount]
    , [d].[MinLogicalReadsPerExecution],[d].[MinTotalLogicalReads]
    , [d].[MinElapsedMs],[d].[MinCpuMs],[d].[MinSpilledPages],[d].[MinMemoryKb]
    , [d].[RequiredEvidenceLevel],[d].[AdditionalConfigurationJson]
    , 1,@SeedVersion
FROM @Defaults AS [d]
WHERE NOT EXISTS
(
    SELECT 1
    FROM [monitor].[PlanAnalysisRuleThreshold] AS [r]
    WHERE [r].[RuleCode]=[d].[RuleCode]
      AND [r].[ProfileCode]=[d].[ProfileCode]
      AND [r].[Severity]=[d].[Severity]
);
GO
