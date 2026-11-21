USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_InterpretAvailabilitySeedingState
Version      : 1.0.0
Stand        : 2026-07-18
Typ          : Inline Table-valued Function
Zweck        : Die Funktion berechnet Fortschritt und Restbytes und klassifiziert
               den übergebenen Momentzustand eines physischen Seedings.
               Sie wertet ausschließlich Parameter aus und hat keine
               Seiteneffekte.
Datenschutz  : Verarbeitet ausschließlich übergebene technische Zahlen- und
               Zeitwerte; freie Fehlermeldungen werden nicht benötigt.
Eingaben     : Alle fünf Parameter sind erforderlich und besitzen keinen
               Defaultwert: @FailureCode, @TransferredSizeBytes,
               @DatabaseSizeBytes, @TransferRateBytesPerSecond und
               @EndTimeUtc.
Ausgaben     : Eine Zeile mit [ProgressPercent] (decimal(9,4)),
               [RemainingBytes] (bigint), [FindingCode] (varchar(100)) und
               [FindingSeverity] (varchar(16)).
Fortschritt : Bei COALESCE(@DatabaseSizeBytes, 0) <= 0 ist der Fortschritt
               NULL. Bei positiver Datenbankgröße und
               COALESCE(@TransferredSizeBytes, 0) <= 0 ist er 0; bei
               übertragenen Bytes mindestens in Höhe der Größe ist er 100.
               Dazwischen berechnet die Funktion den Bytequotienten mal 100.
Restbytes   : Ist COALESCE(@DatabaseSizeBytes, 0) <=
               COALESCE(@TransferredSizeBytes, 0), liefert die Funktion 0;
               andernfalls wird @DatabaseSizeBytes -
               COALESCE(@TransferredSizeBytes, 0) konvertiert. NULL- und
               negative Eingaben können dadurch unerwartete Werte oder
               Konvertierungs-/Rechenfehler ergeben. Eine allgemeine
               Überlaufgarantie besteht nicht.
Codefolge   : Der erste zutreffende Fall gewinnt: Ein von 0 verschiedener
               COALESCE(@FailureCode, 0) ergibt SEEDING_FAILED. Danach ergibt
               ein nicht NULLes @EndTimeUtc zusammen mit
               COALESCE(@TransferredSizeBytes, 0) >=
               COALESCE(@DatabaseSizeBytes, 0) SEEDING_COMPLETED. Bei NULLem
               @EndTimeUtc, noch offenen Bytes und einer zu 0 normalisierten
               Rate folgt SEEDING_NO_CURRENT_THROUGHPUT. Sonst ergibt NULL
               bei @EndTimeUtc SEEDING_IN_PROGRESS; verbleibende Fälle
               ergeben SEEDING_STATE_REVIEW.
Schweregrad : Der Schweregrad wird separat berechnet: Fehlercode ergibt HIGH.
               Kein aktueller Durchsatz bei offenen Bytes sowie ein gesetztes
               Enddatum mit übertragenen Bytes unter der normalisierten Größe
               ergeben MEDIUM. Alle übrigen Fälle ergeben INFO.
Zeitgrenze  : @EndTimeUtc wird ausschließlich auf NULL geprüft. Die Funktion
               vergleicht keine Zeitpunkte und rechnet keine Zeitzone um.
Grenzen     : COALESCE(NULL, 0) kann bei fehlenden Zählern den Code
               SEEDING_COMPLETED ermöglichen, wenn auch die normalisierte
               Größe 0 ist. Die Kennzahlen belegen weder eine ETA noch
               vollständige Gesundheit oder erfolgreichen Empfang auf einer
               Zielreplik. Die Rate ist ein übergebener Momentwert.
Beispiele   : Die Aufrufe verwenden ausschließlich synthetische Konstanten;
               sie fragen keine Metadaten ab und ändern keine Daten.

               SELECT *
               FROM [monitor].[TVF_InterpretAvailabilitySeedingState]
               (
                   0, NULL, NULL, NULL, '2026-01-01T00:00:00'
               );

               SELECT *
               FROM [monitor].[TVF_InterpretAvailabilitySeedingState]
               (
                   0, 0, 0, 0, '2026-01-01T00:00:00'
               );

               SELECT *
               FROM [monitor].[TVF_InterpretAvailabilitySeedingState]
               (
                   0, 0, 100, 0, NULL
               );
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_InterpretAvailabilitySeedingState 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_InterpretAvailabilitySeedingState"
-- schema_name: "monitor"
-- object_name: "TVF_InterpretAvailabilitySeedingState"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Funktion berechnet Fortschritt und Restbytes und klassifiziert den übergebenen Momentzustand eines physischen Seedings."
-- source_path: "Code/01_Common/091_TVF_InterpretAvailabilitySeedingState.sql"
-- ---
-- 
-- # monitor.TVF_InterpretAvailabilitySeedingState
-- 
-- ## Zweck und Einsatz
-- 
-- Die Funktion berechnet Fortschritt und Restbytes und klassifiziert den übergebenen Momentzustand eines physischen Seedings. Sie wertet ausschließlich Parameter aus und hat keine Seiteneffekte.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_InterpretAvailabilitySeedingState]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @FailureCode | int | ja | kein Default |
-- | @TransferredSizeBytes | bigint | ja | kein Default |
-- | @DatabaseSizeBytes | bigint | ja | kein Default |
-- | @TransferRateBytesPerSecond | bigint | ja | kein Default |
-- | @EndTimeUtc | datetime | ja | kein Default |
-- 
-- **@FailureCode:** Pflichtwert int, kein Default. Ein von 0 verschiedener COALESCE(FailureCode,0) löst vorrangig SEEDING_FAILED/HIGH aus; NULL wirkt in diesem Test wie 0.
-- 
-- **@TransferredSizeBytes:** Pflichtwert bigint, kein Default. Übertragene Bytes bestimmen Fortschritt und Restbytes; COALESCE(NULL,0) wird verwendet. Negative/fehlende Werte können unerwartete Werte oder Rechenfehler ergeben.
-- 
-- **@DatabaseSizeBytes:** Pflichtwert bigint, kein Default. Nenner für Fortschritt; COALESCE(NULL,0)<=0 liefert NULL-Fortschritt. Restbytes und Statusfolge verwenden den normalisierten Wert; fehlende Größe kann SEEDING_COMPLETED ermöglichen.
-- 
-- **@TransferRateBytesPerSecond:** Pflichtwert bigint, kein Default. Übergebener Momentwert; bei offenem Rest, NULL-Endzeit und zu 0 normalisierter Rate folgt SEEDING_NO_CURRENT_THROUGHPUT. Keine ETA-Berechnung.
-- 
-- **@EndTimeUtc:** Pflichtwert datetime, kein Default. Wird nur auf NULL geprüft; keine Zeitdifferenz oder Zeitzonenumrechnung. Ein gesetzter Wert kann zusammen mit ausreichenden Bytes SEEDING_COMPLETED ergeben.
-- 
-- ## Resultate und Ausgabe
-- 
-- Eine Zeile mit [ProgressPercent] (decimal(9,4)), [RemainingBytes] (bigint), [FindingCode] (varchar(100)) und [FindingSeverity] (varchar(16)).
-- 
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT *
--                FROM [monitor].[TVF_InterpretAvailabilitySeedingState]
--                (
--                    0, NULL, NULL, NULL, '2026-01-01T00:00:00'
--                );
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- COALESCE(NULL, 0) kann bei fehlenden Zählern den Code SEEDING_COMPLETED ermöglichen, wenn auch die normalisierte Größe 0 ist. Die Kennzahlen belegen weder eine ETA noch vollständige Gesundheit oder erfolgreichen Empfang auf einer Zielreplik. Die Rate ist ein übergebener Momentwert.
-- 
-- USAGE_SKILL_END monitor.TVF_InterpretAvailabilitySeedingState
CREATE OR ALTER FUNCTION [monitor].[TVF_InterpretAvailabilitySeedingState]
(
      @FailureCode                   int
    , @TransferredSizeBytes          bigint
    , @DatabaseSizeBytes             bigint
    , @TransferRateBytesPerSecond    bigint
    , @EndTimeUtc                    datetime
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
          [ProgressPercent] = CONVERT(decimal(9,4),
              CASE WHEN COALESCE(@DatabaseSizeBytes,0) <= 0 THEN NULL
                   WHEN COALESCE(@TransferredSizeBytes,0) <= 0 THEN 0
                   WHEN @TransferredSizeBytes >= @DatabaseSizeBytes THEN 100
                   ELSE CONVERT(decimal(38,6),@TransferredSizeBytes)*100.0
                        /NULLIF(CONVERT(decimal(38,6),@DatabaseSizeBytes),0) END)
        , [RemainingBytes] = CONVERT(bigint,
              CASE WHEN COALESCE(@DatabaseSizeBytes,0) <= COALESCE(@TransferredSizeBytes,0) THEN 0
                   ELSE @DatabaseSizeBytes-COALESCE(@TransferredSizeBytes,0) END)
        , [FindingCode] = CONVERT(varchar(100),
              CASE WHEN COALESCE(@FailureCode,0) <> 0 THEN 'SEEDING_FAILED'
                   WHEN @EndTimeUtc IS NOT NULL
                        AND COALESCE(@TransferredSizeBytes,0) >= COALESCE(@DatabaseSizeBytes,0) THEN 'SEEDING_COMPLETED'
                   WHEN @EndTimeUtc IS NULL
                        AND COALESCE(@DatabaseSizeBytes,0) > COALESCE(@TransferredSizeBytes,0)
                        AND COALESCE(@TransferRateBytesPerSecond,0) = 0 THEN 'SEEDING_NO_CURRENT_THROUGHPUT'
                   WHEN @EndTimeUtc IS NULL THEN 'SEEDING_IN_PROGRESS'
                   ELSE 'SEEDING_STATE_REVIEW' END)
        , [FindingSeverity] = CONVERT(varchar(16),
              CASE WHEN COALESCE(@FailureCode,0) <> 0 THEN 'HIGH'
                   WHEN @EndTimeUtc IS NULL
                        AND COALESCE(@DatabaseSizeBytes,0) > COALESCE(@TransferredSizeBytes,0)
                        AND COALESCE(@TransferRateBytesPerSecond,0) = 0 THEN 'MEDIUM'
                   WHEN @EndTimeUtc IS NOT NULL
                        AND COALESCE(@TransferredSizeBytes,0) < COALESCE(@DatabaseSizeBytes,0) THEN 'MEDIUM'
                   ELSE 'INFO' END)
);
GO
