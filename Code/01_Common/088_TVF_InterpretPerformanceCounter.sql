USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_InterpretPerformanceCounter
Version      : 1.0.0
Stand        : 2026-07-18
Zweck        : Interpretiert ein übergebenes Performance-Counter-Paar nach
               CounterType und liefert Interpretation, Metrik, Einheit und
               FindingCode als einzelne Tabellenzeile.
Eingaben     : @CounterType int; @BeforeValue, @AfterValue,
               @BaseBeforeValue und @BaseAfterValue bigint; @SampleSeconds
               decimal(19,6). Die Basiswerte gelten für Basiscountertypen.
Zuordnung    : 65792 ist RAW_SNAPSHOT und liefert @AfterValue. 272696320 und
               272696576 sind RATE_PER_SECOND und liefern Delta je
               Samplesekunde. 537003264 ist FRACTION_DELTA_PERCENT und
               liefert 100 * Zählerdelta / Basisdelta; 1073874176 ist
               AVERAGE_DELTA_RATIO und liefert Zählerdelta / Basisdelta.
               Weitere Typen sind RAW_UNINTERPRETED und liefern @AfterValue.
               Beide Basisformeln
               benötigen ebenfalls @SampleSeconds > 0, teilen aber nicht durch
               diese Zeit. Weitere Typen bleiben RAW_UNINTERPRETED.
Berechnung   : Delta-Metriken erfordern @SampleSeconds > 0 und einen nicht
               fallenden Zähler. Basisformeln erfordern zusätzlich einen
               vorhandenen, steigenden Basiszähler. FindingCode folgt dieser
               Reihenfolge: SAMPLE_REQUIRED_FOR_DELTA_METRIC,
               COUNTER_RESET_DURING_SAMPLE, BASE_COUNTER_MISSING,
               BASE_COUNTER_RESET_DURING_SAMPLE, BASE_COUNTER_DELTA_ZERO,
               COUNTER_TYPE_NOT_AUTOMATICALLY_INTERPRETED; sonst
               VALUE_AVAILABLE. Bei unbekanntem oder NULL-CounterType kann
               NOT IN UNKNOWN ergeben; dann greift VALUE_AVAILABLE.
Ausgabe      : [Interpretation] varchar, [MetricValue] decimal(38,6),
               [MetricUnit] varchar und [FindingCode] varchar. NULL-Eingaben
               können NULL-Metriken ergeben, ohne selbst einen FindingCode
               auszulösen. Ein verfügbarer Wert belegt weder eine Diagnose
               noch einen Schwellwertbefund.
Grenzen      : Liest keine DMVs und persistiert nichts. Die Funktion validiert
               keine Eingabekonsistenz und schützt nicht vor Überläufen der
               verwendeten Arithmetik. Roh- und unbekannte Typen liefern
               @AfterValue als Rohmetrikwert; das ist keine automatische
               Interpretation des Counters.
Beispiel     : Synthetische Eingabe (CounterType 537003264, vorher/nachher
               10/16, Basis 100/120, Sample 5) ergibt FRACTION_DELTA_PERCENT,
               30.000000, PERCENT und VALUE_AVAILABLE.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_InterpretPerformanceCounter]
(
      @CounterType      int
    , @BeforeValue      bigint
    , @AfterValue       bigint
    , @BaseBeforeValue  bigint
    , @BaseAfterValue   bigint
    , @SampleSeconds    decimal(19,6)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
          CASE
              WHEN @CounterType = 65792 THEN 'RAW_SNAPSHOT'
              WHEN @CounterType IN (272696320, 272696576) THEN 'RATE_PER_SECOND'
              WHEN @CounterType = 537003264 THEN 'FRACTION_DELTA_PERCENT'
              WHEN @CounterType = 1073874176 THEN 'AVERAGE_DELTA_RATIO'
              ELSE 'RAW_UNINTERPRETED'
          END AS [Interpretation]
        , CONVERT(decimal(38,6),
          CASE
              WHEN @CounterType = 65792
                  THEN CONVERT(decimal(38,6), @AfterValue)
              WHEN @CounterType IN (272696320, 272696576)
               AND @SampleSeconds > 0
               AND @AfterValue >= @BeforeValue
                  THEN (CONVERT(decimal(38,6), @AfterValue)
                       -CONVERT(decimal(38,6), @BeforeValue)) / NULLIF(@SampleSeconds, 0)
              WHEN @CounterType = 537003264
               AND @SampleSeconds > 0
               AND @AfterValue >= @BeforeValue
               AND @BaseAfterValue > @BaseBeforeValue
                  THEN 100.0 * (CONVERT(decimal(38,6), @AfterValue)
                               -CONVERT(decimal(38,6), @BeforeValue))
                       / NULLIF(CONVERT(decimal(38,6), @BaseAfterValue)
                               -CONVERT(decimal(38,6), @BaseBeforeValue), 0)
              WHEN @CounterType = 1073874176
               AND @SampleSeconds > 0
               AND @AfterValue >= @BeforeValue
               AND @BaseAfterValue > @BaseBeforeValue
                  THEN (CONVERT(decimal(38,6), @AfterValue)
                       -CONVERT(decimal(38,6), @BeforeValue))
                       / NULLIF(CONVERT(decimal(38,6), @BaseAfterValue)
                               -CONVERT(decimal(38,6), @BaseBeforeValue), 0)
              WHEN @CounterType IN (272696320, 272696576, 537003264, 1073874176)
                  THEN NULL
              ELSE CONVERT(decimal(38,6), @AfterValue)
          END) AS [MetricValue]
        , CASE
              WHEN @CounterType IN (272696320, 272696576) THEN 'PER_SECOND'
              WHEN @CounterType = 537003264 THEN 'PERCENT'
              WHEN @CounterType = 1073874176 THEN 'AVERAGE'
              WHEN @CounterType = 65792 THEN 'RAW_VALUE'
              ELSE 'RAW_UNINTERPRETED'
          END AS [MetricUnit]
        , CASE
              WHEN @CounterType IN (272696320, 272696576, 537003264, 1073874176)
               AND COALESCE(@SampleSeconds, 0) <= 0 THEN 'SAMPLE_REQUIRED_FOR_DELTA_METRIC'
              WHEN @CounterType IN (272696320, 272696576, 537003264, 1073874176)
               AND @AfterValue < @BeforeValue THEN 'COUNTER_RESET_DURING_SAMPLE'
              WHEN @CounterType IN (537003264, 1073874176)
               AND (@BaseBeforeValue IS NULL OR @BaseAfterValue IS NULL) THEN 'BASE_COUNTER_MISSING'
              WHEN @CounterType IN (537003264, 1073874176)
               AND @BaseAfterValue < @BaseBeforeValue THEN 'BASE_COUNTER_RESET_DURING_SAMPLE'
              WHEN @CounterType IN (537003264, 1073874176)
               AND @BaseAfterValue = @BaseBeforeValue THEN 'BASE_COUNTER_DELTA_ZERO'
              WHEN @CounterType NOT IN
                   (65792, 272696320, 272696576, 537003264, 1073874176)
                  THEN 'COUNTER_TYPE_NOT_AUTOMATICALLY_INTERPRETED'
              ELSE 'VALUE_AVAILABLE'
          END AS [FindingCode]
);
GO
