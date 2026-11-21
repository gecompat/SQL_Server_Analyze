USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_InterpretAgentAlertRoute
Version      : 1.0.0
Stand        : 2026-07-18
Typ          : Inline Table-valued Function
Zweck        : Klassifiziert die Aktion eines Agent-Alerts ohne Seiteneffekte.
Eingaben     : @IsEnabled (bit), @HasJobAction (bit) und
               @NotificationCount (bigint); NULL wird bei Aktion und Anzahl
               wie 0 behandelt.
Ausgabe      : Genau eine Zeile mit FindingCode (varchar(100)) und
               FindingSeverity (varchar(16)). Die erste passende Regel gilt:
               aktiv ohne Aktion und ohne Benachrichtigung ergibt
               ENABLED_ALERT_WITHOUT_ACTION/HIGH; deaktiviert ergibt
               ALERT_DISABLED/INFO; sonst ALERT_ROUTE_PRESENT/INFO.
Grenzen      : Negative Anzahlen werden nicht validiert und erfüllen den
               Nulltest nicht. NULL bei @IsEnabled ist weder aktiv noch
               deaktiviert und ergibt daher ALERT_ROUTE_PRESENT/INFO.
               Die Funktion wertet ausschließlich ihre Eingaben aus und liest
               selbst weder Kataloge noch Alert- oder Verlaufseinträge.
Beispiel     : SELECT FindingCode, FindingSeverity
                 FROM monitor.TVF_InterpretAgentAlertRoute(1, 0, 0);
               Erwartet: ENABLED_ALERT_WITHOUT_ACTION / HIGH.
Datenschutz  : Verarbeitet nur Schalter und aggregierte Anzahl; keine Operator-
               oder Empfängerdaten. Die Klassifikation belegt weder eine
               tatsächlich ausgeführte Aktion noch erfolgreichen Versand.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_InterpretAgentAlertRoute 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_InterpretAgentAlertRoute"
-- schema_name: "monitor"
-- object_name: "TVF_InterpretAgentAlertRoute"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Klassifiziert die Aktion eines Agent-Alerts ohne Seiteneffekte."
-- source_path: "Code/01_Common/092_TVF_InterpretAgentAlertRoute.sql"
-- ---
-- 
-- # monitor.TVF_InterpretAgentAlertRoute
-- 
-- ## Zweck und Einsatz
-- 
-- Klassifiziert die Aktion eines Agent-Alerts ohne Seiteneffekte.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_InterpretAgentAlertRoute]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @IsEnabled | bit | ja | kein Default |
-- | @HasJobAction | bit | ja | kein Default |
-- | @NotificationCount | bigint | ja | kein Default |
-- 
-- **@IsEnabled:** Pflichtwert bit, kein Default. Exakt 1 mit fehlender Jobaktion und ohne Benachrichtigung ergibt ENABLED_ALERT_WITHOUT_ACTION/HIGH; 0 ergibt ALERT_DISABLED/INFO. NULL fällt zur informativen Regel.
-- 
-- **@HasJobAction:** Pflichtwert bit, kein Default. Für den aktiven Alert wird nur 1 als vorhandene Jobaktion gewertet; NULL wird wie 0 behandelt.
-- 
-- **@NotificationCount:** Pflichtwert bigint, kein Default. NULL wird wie 0 behandelt; aktiv ohne Aktion und ohne Benachrichtigung ist HIGH. Negative Anzahlen werden nicht validiert und erfüllen den Nulltest nicht.
-- 
-- ## Resultate und Ausgabe
-- 
-- Genau eine Zeile mit FindingCode (varchar(100)) und FindingSeverity (varchar(16)). Die erste passende Regel gilt: aktiv ohne Aktion und ohne Benachrichtigung ergibt ENABLED_ALERT_WITHOUT_ACTION/HIGH; deaktiviert ergibt ALERT_DISABLED/INFO; sonst ALERT_ROUTE_PRESENT/INFO.
-- 
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT FindingCode, FindingSeverity FROM monitor.TVF_InterpretAgentAlertRoute(1, 0, 0);
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Negative Anzahlen werden nicht validiert und erfüllen den Nulltest nicht. NULL bei @IsEnabled ist weder aktiv noch deaktiviert und ergibt daher ALERT_ROUTE_PRESENT/INFO. Die Funktion wertet ausschließlich ihre Eingaben aus und liest selbst weder Kataloge noch Alert- oder Verlaufseinträge.
-- 
-- USAGE_SKILL_END monitor.TVF_InterpretAgentAlertRoute
CREATE OR ALTER FUNCTION [monitor].[TVF_InterpretAgentAlertRoute]
(
      @IsEnabled          bit
    , @HasJobAction       bit
    , @NotificationCount  bigint
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT
          [FindingCode] = CONVERT(varchar(100),
              CASE WHEN @IsEnabled=1 AND COALESCE(@HasJobAction,0)=0
                         AND COALESCE(@NotificationCount,0)=0 THEN 'ENABLED_ALERT_WITHOUT_ACTION'
                   WHEN @IsEnabled=0 THEN 'ALERT_DISABLED'
                   ELSE 'ALERT_ROUTE_PRESENT' END)
        , [FindingSeverity] = CONVERT(varchar(16),
              CASE WHEN @IsEnabled=1 AND COALESCE(@HasJobAction,0)=0
                         AND COALESCE(@NotificationCount,0)=0 THEN 'HIGH'
                   ELSE 'INFO' END)
);
GO
