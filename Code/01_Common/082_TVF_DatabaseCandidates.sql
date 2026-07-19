USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_DatabaseCandidates
Version      : 2.1.1
Stand        : 2026-07-16
Typ          : Inline Table-valued Function
Zweck        : Liefert sichtbare, online befindliche Datenbankkandidaten für
               fehlertolerante Cross-Database-Analysen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : master.sys.databases, monitor.TVF_ParsePipeList,
               monitor.TVF_ParsePattern.
Parameter    : @DatabaseNames, @SystemdatenbankenEinbeziehen,
               @DatabaseNamePattern, @MaxDatenbanken.
Semantik     : @DatabaseNames enthält einen oder mehrere exakte Namen als
               bracket-aware Pipe-Liste. NULL bedeutet alle zulässigen
               Datenbanken. N'' beziehungsweise nur Leerzeichen bedeutet die
               aktuelle Datenbank. Eine explizite Liste wird niemals stillschweigend
               durch @MaxDatenbanken gekürzt. @DatabaseNamePattern ist ein
               einzelnes LIKE-/REGEX-Pattern; REGEX wird vom Aufrufer nach der
               Kandidatenermittlung versionsadaptiv angewendet.
Resultset    : DatabaseId, DatabaseName, StateDesc, UserAccessDesc,
               IsReadOnly, CompatibilityLevel, CollationName,
               RecoveryModelDesc, IsSystemDatabase, RequestedOrdinal.
Berechtigung : Nur sichtbare Datenbanken werden geliefert. VIEW ANY DATABASE
               kann die Sicht erweitern; das Framework vergibt keine Rechte.
Eigenlast    : Sehr gering; Filter auf master.sys.databases.
Locking      : READUNCOMMITTED auf Systemkatalog; keine Benutzerobjekte.
Aufruf       : SELECT * FROM monitor.TVF_DatabaseCandidates(
                   N'[DeineDatenbank]|[BeispielDatenbankB]',0,NULL,16);
               SELECT * FROM monitor.TVF_DatabaseCandidates(
                   NULL,0,N'like:Database_%',16);
Änderungen   : 2.1.1 - TOP-Ausdruck verwendet ausschließlich Parameter und keine gleichrangige CTE-Spalte.
               2.1.0 - Explizit angeforderte Systemdatenbanken werden nicht durch den automatischen Systemdatenbankfilter verworfen.
               2.0.0 - @AlleDatenbanken entfernt; exakte bracket-aware Listen,
                         NULL=alle und separater Patternvertrag eingeführt.
               1.0.0 - Erstfassung Phase 2.
===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_DatabaseCandidates]
(
      @DatabaseNames                    nvarchar(max)  = N''
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @MaxDatenbanken                   int            = 16
)
RETURNS TABLE
AS
RETURN
(
    WITH [Parameters] AS
    (
        SELECT [EffectiveDatabaseNames] = CONVERT
        (
            nvarchar(max),
            CASE WHEN @DatabaseNames IS NOT NULL
                       AND NULLIF(LTRIM(RTRIM(@DatabaseNames)), N'') IS NULL
                 THEN QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()))
                 ELSE @DatabaseNames
            END
        )
    ),
    [ExactNames] AS
    (
        SELECT
              [l].[ItemOrdinal]
            , [DatabaseName] = CONVERT(sysname, PARSENAME([l].[ItemText], 1))
        FROM [Parameters] AS [pa]
        CROSS APPLY [monitor].[TVF_ParsePipeList]([pa].[EffectiveDatabaseNames]) AS [l]
        WHERE [l].[IsValid] = 1
          AND PARSENAME([l].[ItemText], 1) IS NOT NULL
          AND PARSENAME([l].[ItemText], 2) IS NULL
          AND LEN(PARSENAME([l].[ItemText], 1)) <= 128
    ),
    [Pattern] AS
    (
        SELECT [PatternMode], [PatternValue], [IsValid]
        FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern)
    )
    SELECT TOP
    (
        CASE
            WHEN @DatabaseNames IS NOT NULL
                THEN CONVERT(bigint, 9223372036854775807)
            WHEN @MaxDatenbanken IS NULL OR @MaxDatenbanken = 0
                THEN CONVERT(bigint, 9223372036854775807)
            WHEN @MaxDatenbanken > 0
                THEN CONVERT(bigint, @MaxDatenbanken)
            ELSE CONVERT(bigint, 0)
        END
    )
          [d].[database_id]                        AS [DatabaseId]
        , [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [DatabaseName]
        , [d].[state_desc]                         AS [StateDesc]
        , [d].[user_access_desc]                   AS [UserAccessDesc]
        , [d].[is_read_only]                       AS [IsReadOnly]
        , [d].[compatibility_level]                AS [CompatibilityLevel]
        , [d].[collation_name]                     AS [CollationName]
        , [d].[recovery_model_desc]                AS [RecoveryModelDesc]
        , CONVERT(bit, CASE WHEN [d].[database_id] <= 4 THEN 1 ELSE 0 END) AS [IsSystemDatabase]
        , [e].[ItemOrdinal]                        AS [RequestedOrdinal]
    FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
    CROSS JOIN [Parameters] AS [pa]
    CROSS JOIN [Pattern] AS [p]
    LEFT JOIN [ExactNames] AS [e]
      ON [e].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
       = [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
    WHERE [p].[IsValid] = 1
      AND [d].[source_database_id] IS NULL
      AND [d].[state] = 0
      AND HAS_DBACCESS([d].[name]) = 1
      AND ([pa].[EffectiveDatabaseNames] IS NOT NULL OR @SystemdatenbankenEinbeziehen = 1 OR [d].[database_id] > 4)
      AND
      (
          [pa].[EffectiveDatabaseNames] IS NULL
          OR [e].[DatabaseName] IS NOT NULL
      )
      AND
      (
          [p].[PatternMode] IN ('NONE', 'REGEX', 'REGEXI')
          OR [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
             LIKE [p].[PatternValue] COLLATE SQL_Latin1_General_CP1_CS_AS
      )
    ORDER BY
          CASE WHEN [pa].[EffectiveDatabaseNames] IS NOT NULL THEN COALESCE([e].[ItemOrdinal], 2147483647)
               ELSE [d].[database_id] END
        , [d].[database_id]
);
GO
