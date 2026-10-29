USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_InterpretContentionCounter
Zweck        : Berechnet aus übergebenen Latch-/Spinlock-Zählerständen eine
               Differenz, bei angeforderter Messung eine Rate und eine
               Reset-Markierung. Die Funktion liest keine Quelle und hat keine
               Seiteneffekte.
Eingaben     : @BeforeValue und @AfterValue bigint,
               @RequestedSampleSeconds tinyint sowie
               @ActualSampleSeconds decimal(19,6). Die Rate verwendet die
               tatsächliche Sampledauer, nicht den angeforderten Wert.
Berechnung   : Bei @RequestedSampleSeconds = 0 ist [CounterValue] der rohe
               @AfterValue-Wert; [RatePerSecond] bleibt NULL und ein Reset
               wird nicht markiert. Bei positivem angefordertem Wert liefert
               ein nicht fallender Zähler die Differenz. Die Rate ist diese
               Differenz geteilt durch NULLIF(@ActualSampleSeconds, 0), wenn
               die tatsächliche Dauer nicht NULL oder 0 ist. Ein fallender
               Zähler liefert bei positiver Anforderung NULL für Differenz
               und Rate sowie 1 für [CounterResetDetected].
NULL-Fälle    : Ist @RequestedSampleSeconds NULL, kann die Differenz bei
               nicht fallendem Zähler dennoch berechnet werden; Rate bleibt
               NULL und Reset-Markierung ist 0. Ein NULL-Zählerstand kann
               ebenfalls NULL-Ergebnisse bewirken, ohne Reset-Markierung.
Ausgabe      : [CounterValue] bigint, [RatePerSecond] decimal(19,4) und
               [CounterResetDetected] bit. Die Funktion validiert keine
               Eingabekombinationen. Eine negative tatsächliche Dauer wird
               nicht verworfen und kann eine negative Rate ergeben. Die
               bigint-Subtraktion kann überlaufen; eine solche Eingabe kann
               deshalb einen Laufzeitfehler verursachen.
Datenschutz  : Verarbeitet ausschließlich die übergebenen technischen
               Zahlenwerte.
Beispiel     : Synthetische Eingabe (Zähler 100 auf 130, angeforderte Dauer 5
               Sekunden, tatsächliche Dauer 2.5 Sekunden) ergibt die
               Differenz 30, Rate 12.0000 je Sekunde und Reset-Markierung 0.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_InterpretContentionCounter]
(
      @BeforeValue            bigint
    , @AfterValue             bigint
    , @RequestedSampleSeconds tinyint
    , @ActualSampleSeconds    decimal(19,6)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
          CASE
              WHEN @RequestedSampleSeconds=0 THEN @AfterValue
              WHEN @AfterValue>=@BeforeValue THEN @AfterValue-@BeforeValue
          END AS [CounterValue]
        , CASE
              WHEN @RequestedSampleSeconds>0 AND @AfterValue>=@BeforeValue
              THEN CONVERT(decimal(19,4),
                   1.0*(@AfterValue-@BeforeValue)/NULLIF(@ActualSampleSeconds,0))
          END AS [RatePerSecond]
        , CONVERT(bit,CASE
              WHEN @RequestedSampleSeconds>0 AND @AfterValue<@BeforeValue THEN 1
              ELSE 0
          END) AS [CounterResetDetected]
);
GO
