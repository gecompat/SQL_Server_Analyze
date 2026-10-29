USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_InterpretAgentJobState
Version      : 1.0.0
Stand        : 2026-07-18
Typ          : Inline Table-valued Function
Zweck        : Klassifiziert den letzten Jobstatus und die zugehörigen
               Zeitpläne ohne Seiteneffekte.
Eingaben     : @IsEnabled (tinyint) und @LatestRunStatus (int) bezeichnen
               Aktivierung und letzten Laufstatus. @LatestRunDateTime und
               @CutoffLocal (je datetime) bilden den Fenstervergleich;
               @ScheduleCount und @EnabledScheduleCount (je bigint) zählen
               zugeordnete beziehungsweise aktivierte Zeitpläne.
               NULL-Anzahlen gelten als 0; ein NULL-Zeitpunkt oder Cutoff
               erfüllt den Fenstervergleich nicht.
Ausgabe      : Genau eine Zeile mit FindingCode (varchar(100)) und
               FindingSeverity (varchar(16)). In CASE-Reihenfolge: aktiver
               Job mit Status 0 und Zeitpunkt >= Cutoff ergibt
               LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH; aktive Jobs mit
               Zeitplänen, aber ohne aktivierten Zeitplan ergeben
               ALL_ATTACHED_SCHEDULES_DISABLED/MEDIUM; ohne Zeitplan
               ENABLED_JOB_WITHOUT_SCHEDULE/INFO; sonst
               JOB_STATE_INFORMATIONAL/INFO. @IsEnabled qualifiziert nur bei
               exakt 1; andere Werte einschließlich NULL fallen weiter.
Grenzen      : Nur der übergebene Zeitpunkt wird inklusiv mit dem Cutoff
               verglichen. Es gibt keine implizite aktuelle Zeit, Zeitzonen-
               umrechnung oder Verlaufsabfrage. Negative Anzahlen werden
               nicht validiert. Die Funktion liest selbst keine Kataloge.
Beispiel     : SELECT FindingCode, FindingSeverity
                 FROM monitor.TVF_InterpretAgentJobState
                      (1, 0, '2026-07-18T10:00:00',
                       '2026-07-18T09:00:00', 0, 0);
               Erwartet: LATEST_JOB_RUN_FAILED_IN_WINDOW / HIGH.
Datenschutz  : Verarbeitet nur technische Status-, Zeit- und Anzahlwerte; keine
               Jobschritte, Befehle oder Meldungstexte. Die Klassifikation
               belegt weder eine tatsächliche Ausführung noch deren Erfolg.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_InterpretAgentJobState]
(
      @IsEnabled             tinyint
    , @LatestRunStatus       int
    , @LatestRunDateTime     datetime
    , @CutoffLocal           datetime
    , @ScheduleCount         bigint
    , @EnabledScheduleCount  bigint
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
          [FindingCode] = CONVERT(varchar(100),
              CASE WHEN @IsEnabled=1 AND @LatestRunStatus=0
                         AND @LatestRunDateTime>=@CutoffLocal THEN 'LATEST_JOB_RUN_FAILED_IN_WINDOW'
                   WHEN @IsEnabled=1 AND COALESCE(@ScheduleCount,0)>0
                         AND COALESCE(@EnabledScheduleCount,0)=0 THEN 'ALL_ATTACHED_SCHEDULES_DISABLED'
                   WHEN @IsEnabled=1 AND COALESCE(@ScheduleCount,0)=0 THEN 'ENABLED_JOB_WITHOUT_SCHEDULE'
                   ELSE 'JOB_STATE_INFORMATIONAL' END)
        , [FindingSeverity] = CONVERT(varchar(16),
              CASE WHEN @IsEnabled=1 AND @LatestRunStatus=0
                         AND @LatestRunDateTime>=@CutoffLocal THEN 'HIGH'
                   WHEN @IsEnabled=1 AND COALESCE(@ScheduleCount,0)>0
                         AND COALESCE(@EnabledScheduleCount,0)=0 THEN 'MEDIUM'
                   ELSE 'INFO' END)
);
GO
