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
-- USAGE_SKILL_BEGIN monitor.TVF_InterpretContentionCounter 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_InterpretContentionCounter"
-- schema_name: "monitor"
-- object_name: "TVF_InterpretContentionCounter"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Berechnet aus übergebenen Latch-/Spinlock-Zählerständen eine Differenz, bei angeforderter Messung eine Rate und eine Reset-Markierung."
-- source_path: "Code/01_Common/089_TVF_InterpretContentionCounter.sql"
-- ---
-- 
-- # monitor.TVF_InterpretContentionCounter
-- 
-- ## Zweck und Einsatz
-- 
-- Berechnet aus übergebenen Latch-/Spinlock-Zählerständen eine Differenz, bei angeforderter Messung eine Rate und eine Reset-Markierung. Die Funktion liest keine Quelle und hat keine Seiteneffekte.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_InterpretContentionCounter]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @BeforeValue | bigint | ja | kein Default |
-- | @AfterValue | bigint | ja | kein Default |
-- | @RequestedSampleSeconds | tinyint | ja | kein Default |
-- | @ActualSampleSeconds | decimal(19,6) | ja | kein Default |
-- 
-- **@BeforeValue:** Pflichtwert bigint, kein Default. Vorheriger Latch-/Spinlock-Zähler; bei angeforderter Messung bildet die Funktion zusammen mit AfterValue eine Differenz, bei fallendem Zähler einen Reset. NULL kann NULL-Ergebnisse ohne Reset-Markierung liefern.
-- 
-- **@AfterValue:** Pflichtwert bigint, kein Default. Bei RequestedSampleSeconds=0 ist dieser Rohwert CounterValue; bei positiver Anforderung wird die Differenz zu BeforeValue gebildet. bigint-Subtraktion kann überlaufen.
-- 
-- **@RequestedSampleSeconds:** Pflichtwert tinyint, kein Default. 0 wählt Rohwert ohne Rate/Reset; positiv wählt Differenz und gegebenenfalls Rate. NULL kann eine Differenz liefern, unterdrückt aber Rate und Reset-Markierung.
-- 
-- **@ActualSampleSeconds:** Pflichtwert decimal(19,6), kein Default. Die Rate teilt die Differenz durch NULLIF(dieser tatsächlichen Dauer,0); NULL/0 liefert keine Rate. Eine negative Dauer wird nicht verworfen und kann eine negative Rate ergeben.
-- 
-- ## Resultate und Ausgabe
-- 
-- [CounterValue] bigint, [RatePerSecond] decimal(19,4) und [CounterResetDetected] bit. Die Funktion validiert keine Eingabekombinationen. Eine negative tatsächliche Dauer wird nicht verworfen und kann eine negative Rate ergeben. Die bigint-Subtraktion kann überlaufen; eine solche Eingabe kann deshalb einen Laufzeitfehler verursachen.
-- 
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT * FROM [monitor].[TVF_InterpretContentionCounter](100, 130, 5, 2.5);
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
-- USAGE_SKILL_END monitor.TVF_InterpretContentionCounter
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
