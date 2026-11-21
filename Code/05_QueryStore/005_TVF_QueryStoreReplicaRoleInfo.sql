USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_QueryStoreReplicaRoleInfo
Version      : 1.0.0
Stand        : 2026-07-27
Typ          : Inline Table-Valued Function
Zweck        : Die Funktion ordnet @RoleType einer Query-Store-Rollenbeschreibung,
               einer Scopeklasse und den zugehörigen Flags zu. Sie referenziert
               keine versionsspezifischen Kataloge.
Eingabe      : @RoleType tinyint; Default: keiner. Das Argument ist als
               Zahl, etwa 1, oder NULL beim Funktionsaufruf anzugeben. Zulässig sind NULL und die tinyint-Werte 0
               bis 255. NULL und 0 ergeben UNKNOWN und UNKNOWN_ROLE. Die Werte
               1, 2, 3, 4 und 5 ergeben der Reihe nach PRIMARY, SECONDARY,
               GEO_PRIMARY, GEO_SECONDARY und NAMED_REPLICA. Werte 6 bis 255
               werden ebenfalls als NAMED_REPLICA und READ_ONLY_ROLE
               klassifiziert. Dieser offene Fallbackbereich folgt der
               Frameworkkonvention und garantiert keine künftigen
               Herstellercodes.
Ausgabe      : Genau eine Zeile mit RoleType tinyint (der Eingabewert, NULL
               bleibt NULL), RoleTypeDesc varchar(40), RoleClass varchar(24),
               IsPrimaryRole, IsSecondaryRole und IsNamedReplica jeweils bit
               sowie EvidenceLimit nvarchar(500). Für NULL und 0 sind alle
               drei Flags 0. Für 1 und 3 ist RoleClass READ_WRITE_ROLE und
               nur IsPrimaryRole 1. Für 2 und 4 ist RoleClass READ_ONLY_ROLE
               und nur IsSecondaryRole 1. Für 5 bis 255 ist RoleClass
               READ_ONLY_ROLE, IsSecondaryRole und IsNamedReplica sind 1,
               IsPrimaryRole ist 0.
Aussagegrenze: EvidenceLimit weist die Rollenabbildung für
               sys.query_store_replicas.role_type aus und stellt klar, dass
               beobachtete Rollen keine aktuelle Erreichbarkeits- oder
               Healthaussage sind. Die Klassifikation des Parameters liest
               keine Live-Daten und belegt weder tatsächliche
               Replikatkonfiguration noch Erreichbarkeit, Gesundheit oder
               aktuelle Schreibberechtigung.
SQL-Version  : SQL Server 2019 oder neuer.
Eigenlast    : Konstante Projektion; keine Katalog- oder DMV-Zugriffe.
Beispiele    : SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](1);
               SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](5);
               SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](0);
               SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](NULL);
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_QueryStoreReplicaRoleInfo 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_QueryStoreReplicaRoleInfo"
-- schema_name: "monitor"
-- object_name: "TVF_QueryStoreReplicaRoleInfo"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Funktion ordnet @RoleType einer Query-Store-Rollenbeschreibung, einer Scopeklasse und den zugehörigen Flags zu."
-- source_path: "Code/05_QueryStore/005_TVF_QueryStoreReplicaRoleInfo.sql"
-- ---
-- 
-- # monitor.TVF_QueryStoreReplicaRoleInfo
-- 
-- ## Zweck und Einsatz
-- 
-- Die Funktion ordnet @RoleType einer Query-Store-Rollenbeschreibung, einer Scopeklasse und den zugehörigen Flags zu. Sie referenziert keine versionsspezifischen Kataloge.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_QueryStoreReplicaRoleInfo]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @RoleType | tinyint | ja | kein Default |
-- 
-- **@RoleType:** Pflichtwert tinyint, kein Default. NULL und 0 ergeben UNKNOWN. 1 bis 5 bilden die definierten Rollen PRIMARY, SECONDARY, GEO_PRIMARY, GEO_SECONDARY und NAMED_REPLICA; 6 bis 255 verwenden den offenen NAMED_REPLICA-Fallback. Die Zuordnung belegt keine tatsächliche Replikatkonfiguration oder Erreichbarkeit.
-- 
-- ## Resultate und Ausgabe
-- 
-- Genau eine Zeile mit RoleType tinyint (der Eingabewert, NULL bleibt NULL), RoleTypeDesc varchar(40), RoleClass varchar(24), IsPrimaryRole, IsSecondaryRole und IsNamedReplica jeweils bit sowie EvidenceLimit nvarchar(500). Für NULL und 0 sind alle drei Flags 0. Für 1 und 3 ist RoleClass READ_WRITE_ROLE und nur IsPrimaryRole 1. Für 2 und 4 ist RoleClass READ_ONLY_ROLE und nur IsSecondaryRole 1. Für 5 bis 255 ist RoleClass READ_ONLY_ROLE, IsSecondaryRole und IsNamedReplica sind 1, IsPrimaryRole ist 0.
-- 
-- 
-- ## Beispiel
-- 
-- ```sql
-- SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](1); SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](5); SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](0); SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](NULL);
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
-- USAGE_SKILL_END monitor.TVF_QueryStoreReplicaRoleInfo
CREATE OR ALTER FUNCTION [monitor].[TVF_QueryStoreReplicaRoleInfo]
(
    @RoleType tinyint
)
RETURNS TABLE
AS
RETURN
(
    SELECT
          @RoleType AS [RoleType]
        , CONVERT(varchar(40),
            CASE @RoleType
                WHEN 1 THEN 'PRIMARY'
                WHEN 2 THEN 'SECONDARY'
                WHEN 3 THEN 'GEO_PRIMARY'
                WHEN 4 THEN 'GEO_SECONDARY'
                WHEN 5 THEN 'NAMED_REPLICA'
                WHEN NULL THEN 'UNKNOWN'
                ELSE CASE WHEN @RoleType > 5 THEN 'NAMED_REPLICA' ELSE 'UNKNOWN' END
            END) AS [RoleTypeDesc]
        , CONVERT(varchar(24),
            CASE
                WHEN @RoleType IN (1,3) THEN 'READ_WRITE_ROLE'
                WHEN @RoleType IN (2,4) OR @RoleType >= 5 THEN 'READ_ONLY_ROLE'
                ELSE 'UNKNOWN_ROLE'
            END) AS [RoleClass]
        , CONVERT(bit,CASE WHEN @RoleType IN (1,3) THEN 1 ELSE 0 END) AS [IsPrimaryRole]
        , CONVERT(bit,CASE WHEN @RoleType IN (2,4) OR @RoleType >= 5 THEN 1 ELSE 0 END) AS [IsSecondaryRole]
        , CONVERT(bit,CASE WHEN @RoleType >= 5 THEN 1 ELSE 0 END) AS [IsNamedReplica]
        , CONVERT(nvarchar(500),
            N'Rollenabbildung für sys.query_store_replicas.role_type; beobachtete Rollen sind keine aktuelle Erreichbarkeits- oder Healthaussage.') AS [EvidenceLimit]
);
GO
