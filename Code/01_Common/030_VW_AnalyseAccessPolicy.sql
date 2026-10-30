USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.VW_AnalyseAccessPolicy
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : View
Zweck        : Stellt die rein lesende Policyquelle für Analyseklassen und
               zugeordnete Windows-Gruppen bereit. Die ausgelieferte View gibt
               wegen WHERE 1 = 0 keine Zeilen zurück; ihre sieben Ausgabespalten
               behalten dabei die unten angegebenen Typen.
Parameter    : Keine.
Ausgabe      : AnalysisClass (varchar(64)), ADGroupName (nvarchar(256)),
               IsEnabled (bit), ValidFromUtc und ValidToUtc (datetime2(0)),
               Priority (smallint) sowie Comment (nvarchar(1000)).
Verwendung   : Eine spätere, manuell gepflegte Policy-View kann diese Spalten
               mit Gruppenregeln befüllen. Die kommentierte VALUES-Vorlage am
               Dateiende wird nicht ausgeführt und ändert die ausgelieferte
               leere View nicht. Priority wird vom Verbraucher mitgeführt,
               steuert derzeit aber weder Auswahlreihenfolge noch Freigabe.
Wirkung      : VW_AnalyseAccessCurrent wertet aktive Policyzeilen aus. Sind
               keine aktiven Zeilen vorhanden, ist die Gruppenprüfung offen;
               sind welche vorhanden, können geschützte Klassen ohne passende
               spezifische oder globale Regel gesperrt sein. Eine Regel mit
               AnalysisClass='*' gilt für alle geschützten Klassen. Diese
               Policyquelle vergibt selbst keine SQL-Berechtigungen.
Grenzen      : Die View prüft keine Gruppenmitgliedschaft und führt keine
               Analyse aus. Das Framework nimmt hier keine GRANT-, DENY- oder
               REVOKE-Änderung vor.
Beispiel     : SELECT [AnalysisClass], [ADGroupName], [IsEnabled],
                      [ValidFromUtc], [ValidToUtc], [Priority], [Comment]
               FROM [monitor].[VW_AnalyseAccessPolicy] WITH (NOLOCK)
               ORDER BY [AnalysisClass], [Priority], [ADGroupName];
Änderungen   : 1.0.0 - Erstfassung Phase 1A.
===============================================================================
*/
CREATE OR ALTER VIEW [monitor].[VW_AnalyseAccessPolicy]
AS
    SELECT
        [p].[AnalysisClass],
        [p].[ADGroupName],
        [p].[IsEnabled],
        [p].[ValidFromUtc],
        [p].[ValidToUtc],
        [p].[Priority],
        [p].[Comment]
    FROM
    (
        VALUES
        (
            CAST(NULL AS varchar(64)),
            CAST(NULL AS nvarchar(256)),
            CAST(NULL AS bit),
            CAST(NULL AS datetime2(0)),
            CAST(NULL AS datetime2(0)),
            CAST(NULL AS smallint),
            CAST(NULL AS nvarchar(1000))
        )
    ) AS [p]
    (
        [AnalysisClass],
        [ADGroupName],
        [IsEnabled],
        [ValidFromUtc],
        [ValidToUtc],
        [Priority],
        [Comment]
    )
    WHERE 1 = 0;
GO

/*
Beispiel für eine spätere, bewusst manuell gepflegte Policy-View:

CREATE OR ALTER VIEW monitor.VW_AnalyseAccessPolicy
AS
    SELECT
        p.AnalysisClass,
        p.ADGroupName,
        p.IsEnabled,
        p.ValidFromUtc,
        p.ValidToUtc,
        p.Priority,
        p.Comment
    FROM
    (
        VALUES
          (CAST('PLAN_CACHE_DEEP' AS varchar(64)), CAST(N'CONTOSO\\SQL_Monitor_Deep' AS nvarchar(256)), CAST(1 AS bit), CAST(NULL AS datetime2(0)), CAST(NULL AS datetime2(0)), CAST(100 AS smallint), CAST(N'Plan-Cache Deep Analysis' AS nvarchar(1000))),
          (CAST('SHOWPLAN_XML_DEEP' AS varchar(64)), CAST(N'CONTOSO\\SQL_Monitor_Deep' AS nvarchar(256)), CAST(1 AS bit), CAST(NULL AS datetime2(0)), CAST(NULL AS datetime2(0)), CAST(100 AS smallint), CAST(N'Showplan XML Deep Analysis' AS nvarchar(1000))),
          (CAST('*' AS varchar(64)), CAST(N'CONTOSO\\SQL_Server_Admins' AS nvarchar(256)), CAST(1 AS bit), CAST(NULL AS datetime2(0)), CAST(NULL AS datetime2(0)), CAST(10 AS smallint), CAST(N'Alle geschützten Analyseklassen' AS nvarchar(1000)))
    ) AS [p]
    (
        [AnalysisClass],
        [ADGroupName],
        [IsEnabled],
        [ValidFromUtc],
        [ValidToUtc],
        [Priority],
        [Comment]
    );
GO
*/
