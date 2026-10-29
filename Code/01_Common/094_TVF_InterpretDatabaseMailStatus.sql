USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_InterpretDatabaseMailStatus
Version      : 1.0.0
Stand        : 2026-07-18
Typ          : Inline Table-valued Function
Zweck        : Klassifiziert aggregierte Database-Mail-Status ohne
               Seiteneffekte.
Eingaben     : @SentStatus (varchar(8)); NULL und alle Werte außerhalb
               'failed', 'unsent' und 'retrying' fallen in die informative
               Regel. Der Textvergleich folgt der Datenbankkollation und
               garantiert keine Unterscheidung von Groß-/Kleinschreibung.
Ausgabe      : Genau eine Zeile mit FindingCode (varchar(100)) und
               FindingSeverity (varchar(16)). 'failed' ergibt
               DATABASE_MAIL_FAILED_IN_WINDOW/HIGH; 'unsent' und 'retrying'
               ergeben DATABASE_MAIL_PENDING_IN_WINDOW/MEDIUM; sonst
               DATABASE_MAIL_STATUS_INFORMATIONAL/INFO.
Beispiel     : SELECT FindingCode, FindingSeverity
                 FROM monitor.TVF_InterpretDatabaseMailStatus('failed');
               Erwartet: DATABASE_MAIL_FAILED_IN_WINDOW / HIGH.
Grenzen      : Die Funktion klassifiziert nur den übergebenen Status; sie
               liest weder Mail-Verlauf noch Kataloge und führt keinen Versand
               aus. Das Ergebnis beweist weder Zustellung noch Fehlerursache.
Datenschutz  : Verarbeitet ausschließlich den technischen Versandstatus; keine
               Adresse, Empfänger, Betreffzeile oder Nachricht.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_InterpretDatabaseMailStatus]
(
    @SentStatus varchar(8)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
          [FindingCode] = CONVERT(varchar(100),
              CASE WHEN @SentStatus='failed' THEN 'DATABASE_MAIL_FAILED_IN_WINDOW'
                   WHEN @SentStatus IN ('unsent','retrying') THEN 'DATABASE_MAIL_PENDING_IN_WINDOW'
                   ELSE 'DATABASE_MAIL_STATUS_INFORMATIONAL' END)
        , [FindingSeverity] = CONVERT(varchar(16),
              CASE WHEN @SentStatus='failed' THEN 'HIGH'
                   WHEN @SentStatus IN ('unsent','retrying') THEN 'MEDIUM'
                   ELSE 'INFO' END)
);
GO
