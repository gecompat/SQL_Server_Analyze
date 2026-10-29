USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_InterpretAvailabilityDatabaseState
Version      : 1.0.0
Stand        : 2026-07-18
Typ          : Inline Table-valued Function
Zweck        : Die Funktion klassifiziert den übergebenen Momentzustand einer
               Always On-Verfügbarkeitsdatenbank anhand von Status-, Queue-
               und Lagwerten; sie liest keine DMV und hat keine Seiteneffekte.
Datenschutz  : Verarbeitet ausschließlich übergebene technische Status- und
               Zählerwerte; keine Namen, Texte oder Umgebungswerte.
Eingaben     : Alle acht Parameter sind erforderlich und besitzen keinen
               Defaultwert: @IsSuspended, @SynchronizationHealthDesc,
               @SynchronizationStateDesc, @LogSendQueueSizeKb,
               @RedoQueueSizeKb, @SecondaryLagSeconds, @QueueWarnMb und
               @SecondaryLagWarnSeconds.
Ausgaben     : Eine Zeile mit [FindingCode] (varchar(100)) und
               [FindingSeverity] (varchar(16)).
Auswertung   : Der erste zutreffende Codefall gewinnt in dieser Reihenfolge:
               DATA_MOVEMENT_SUSPENDED bei @IsSuspended = 1,
               DATABASE_NOT_HEALTHY bei NOT_HEALTHY,
               DATABASE_NOT_SYNCHRONIZING bei NOT_SYNCHRONIZING,
               LOG_SEND_QUEUE_THRESHOLD, REDO_QUEUE_THRESHOLD,
               SECONDARY_LAG_THRESHOLD und andernfalls
               DATABASE_STATE_ACCEPTABLE. Die Textvergleiche verwenden die
               für die Eingaben geltende SQL-Collation.
Schwellen    : Beide Queuewerte werden nach COALESCE(NULL, 0) in decimal(38,0)
               mit @QueueWarnMb * 1024 verglichen; der Grenzwert ist
               einschließlich. Der Lagvergleich verwendet
               COALESCE(@SecondaryLagSeconds, 0) >=
               @SecondaryLagWarnSeconds. NULL-Schwellen machen die jeweilige
               Vergleichsbedingung nicht zutreffend. Die Funktion validiert
               weder Schwellen noch negative Werte.
Schweregrad : Die drei Statusfälle für Stillstand, NOT_HEALTHY und
               NOT_SYNCHRONIZING ergeben HIGH. Ein zutreffender Queue- oder
               Lagfall ergibt andernfalls den Schweregrad MEDIUM; alle übrigen
               Fälle ergeben INFO. Ein NULL- oder anderer Bitwert wird nicht als ungültig
               abgelehnt und erfüllt den Stillstandsfall nicht.
Grenzen      : DATABASE_STATE_ACCEPTABLE besagt nur, dass keine der
               implementierten Bedingungen zutraf. Der Wert belegt weder
               vollständige Gesundheit noch Erreichbarkeit einer Replik oder
               eine künftige Catch-up-Zeit. Queue- und Laggrenzen sind
               Sichtungswerte und beweisen weder Ursache noch zukünftige
               Catch-up-Zeit.
Beispiele    : Die folgenden Aufrufe verwenden ausschließlich synthetische
               Konstanten und führen keine Metadatenabfrage oder Änderung aus.

               SELECT *
               FROM [monitor].[TVF_InterpretAvailabilityDatabaseState]
               (
                   0, N'HEALTHY', N'SYNCHRONIZED',
                   0, 0, 0, 10, 30
               );

               SELECT *
               FROM [monitor].[TVF_InterpretAvailabilityDatabaseState]
               (
                   1, NULL, NULL, NULL, NULL, NULL, NULL, NULL
               );
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_InterpretAvailabilityDatabaseState]
(
      @IsSuspended                  bit
    , @SynchronizationHealthDesc    nvarchar(60)
    , @SynchronizationStateDesc     nvarchar(60)
    , @LogSendQueueSizeKb           bigint
    , @RedoQueueSizeKb              bigint
    , @SecondaryLagSeconds          bigint
    , @QueueWarnMb                  bigint
    , @SecondaryLagWarnSeconds      int
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
          [FindingCode] = CONVERT(varchar(100),
              CASE WHEN @IsSuspended = 1 THEN 'DATA_MOVEMENT_SUSPENDED'
                   WHEN @SynchronizationHealthDesc = N'NOT_HEALTHY' THEN 'DATABASE_NOT_HEALTHY'
                   WHEN @SynchronizationStateDesc = N'NOT_SYNCHRONIZING' THEN 'DATABASE_NOT_SYNCHRONIZING'
                   WHEN CONVERT(decimal(38,0),COALESCE(@LogSendQueueSizeKb,0)) >= CONVERT(decimal(38,0),@QueueWarnMb)*1024 THEN 'LOG_SEND_QUEUE_THRESHOLD'
                   WHEN CONVERT(decimal(38,0),COALESCE(@RedoQueueSizeKb,0)) >= CONVERT(decimal(38,0),@QueueWarnMb)*1024 THEN 'REDO_QUEUE_THRESHOLD'
                   WHEN COALESCE(@SecondaryLagSeconds,0) >= @SecondaryLagWarnSeconds THEN 'SECONDARY_LAG_THRESHOLD'
                   ELSE 'DATABASE_STATE_ACCEPTABLE' END)
        , [FindingSeverity] = CONVERT(varchar(16),
              CASE WHEN @IsSuspended = 1
                         OR @SynchronizationHealthDesc = N'NOT_HEALTHY'
                         OR @SynchronizationStateDesc = N'NOT_SYNCHRONIZING' THEN 'HIGH'
                   WHEN CONVERT(decimal(38,0),COALESCE(@LogSendQueueSizeKb,0)) >= CONVERT(decimal(38,0),@QueueWarnMb)*1024
                         OR CONVERT(decimal(38,0),COALESCE(@RedoQueueSizeKb,0)) >= CONVERT(decimal(38,0),@QueueWarnMb)*1024
                         OR COALESCE(@SecondaryLagSeconds,0) >= @SecondaryLagWarnSeconds THEN 'MEDIUM'
                   ELSE 'INFO' END)
);
GO
