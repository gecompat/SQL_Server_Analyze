USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_QueryStoreReplicaRoleInfo
Version      : 1.0.0
Stand        : 2026-07-27
Typ          : Inline Table-Valued Function
Zweck        : Die Funktion ordnet den Parameter @RoleType den stabilen Rollen-
               und Scopeklassen des Query Store zu, ohne versionsspezifische
               Kataloge zu referenzieren.
Eingabe      : @RoleType tinyint nimmt NULL, 0 oder die Werte 1 bis 5 an.
               NULL und 0 ergeben UNKNOWN und UNKNOWN_ROLE. Die Werte 1 bis 5
               werden PRIMARY, SECONDARY, GEO_PRIMARY, GEO_SECONDARY und
               NAMED_REPLICA zugeordnet. Werte größer als 5 werden ebenfalls
               als NAMED_REPLICA und READ_ONLY_ROLE klassifiziert; dies folgt
               der Frameworkkonvention und garantiert keine künftigen
               Herstellercodes.
Ausgabe      : Die Funktion liefert stets genau eine Zeile mit RoleType tinyint,
               RoleTypeDesc varchar(40), RoleClass varchar(24), den Flags
               IsPrimaryRole, IsSecondaryRole und IsNamedReplica vom Typ bit
               sowie EvidenceLimit nvarchar(500).
Aussagegrenze: Die Rollenabbildung beschreibt die Klassifikation des Parameters.
               Sie liest keine Live-Daten und belegt weder tatsächliche
               Replikatkonfiguration noch Erreichbarkeit, Gesundheit oder eine
               aktuelle Schreibberechtigung.
SQL-Version  : SQL Server 2019 oder neuer.
Eigenlast    : Konstante Projektion; keine Katalog- oder DMV-Zugriffe.
Beispiele    : SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](1);
               SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](5);
               SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](0);
               SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](NULL);
===============================================================================
*/
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
