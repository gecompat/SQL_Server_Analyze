USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.VW_AnalyseAccessCurrent
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : View
Zweck        : Zeigt für jede Katalogklasse den aus den aktuellen Login- und
               Policyinformationen abgeleiteten IsAllowed-Wert und den Grund.
Parameter    : Keine. Die Login- und Tokenwerte beziehen sich auf den Aufruf.
Ausgabe      : AnalysisClass (varchar(64)), AnalysisLevel (varchar(16)),
               RequiresGroupGate (bit), OriginalLoginName und EffectiveLoginName
               (nvarchar(128)), IsSysadmin (bit), ActivePolicyCount,
               RelevantPolicyCount und MatchedGroupCount (bigint), IsAllowed
               (bit) sowie AccessReason (varchar(20)).
Policy       : Aktiv sind Zeilen mit IsEnabled=1, ValidFromUtc NULL oder nicht
               später als SYSUTCDATETIME(), ValidToUtc NULL oder später als
               SYSUTCDATETIME() sowie nichtleeren, getrimmten Klassen- und
               Gruppennamen. Gespeicherte Zeichenfolgen werden dadurch nicht
               getrimmt. Sobald mindestens eine solche Zeile global aktiv ist,
               kann eine geschützte Klasse ohne relevante Regel gesperrt sein.
               Eine Regel für '*' gilt zusätzlich für jede geschützte Klasse.
Abgleich     : Windows-Gruppen aus sys.login_token werden nach Typfilter und
               case-insensitivem Vergleich unter Latin1_General_100_CI_AS
               abgeglichen. Login-Token-Paare werden je Klasse und Gruppe
               dedupliziert; IS_MEMBER zählt nur bei Rückgabewert 1, NULL gilt
               nicht als Treffer. Der Gruppenabgleich ist keine Live-Abfrage
               beim Active Directory und belegt keine SQL-Berechtigung.
Reihenfolge  : Die fachliche Fallauswahl lautet: ungeschützte Klasse,
               sysadmin, keine aktive Policy, Treffer über Login-Token,
               IS_MEMBER-Treffer, sonst NO_MATCH. AccessReason liefert dazu
               NOT_REQUIRED, SYSADMIN, OPEN_POLICY, LOGIN_TOKEN, IS_MEMBER oder
               NO_MATCH. Priority wird zwar aus der Policy mitgeführt, sortiert
               oder priorisiert die Freigabe derzeit aber nicht. Die logische
               Fallreihenfolge garantiert keine physische Kurzschlussauswertung
               durch den SQL-Server.
Zählung      : MatchedGroupCount summiert Treffer je Analyseklasse über die
               spezifische und die '*' Regel. Deshalb kann dieselbe Gruppe bei
               einer passenden spezifischen und globalen Regel mehrfach in der
               Summe erscheinen; die Zahl bezeichnet keine eindeutigen Personen
               oder Active-Directory-Mitglieder.
Berechtigung : Für den Aufruf sind Leserechte auf die verwendeten Framework-
               Views und verfügbare Tokeninformationen erforderlich. Die View
               vergibt oder beweist keine SQL-Rechte. sys.login_token wird mit
               NOLOCK gelesen; daraus folgt weder ein Live-AD-Nachweis noch ein
               Nachweis für GRANT-, DENY- oder Objektberechtigungen.
Beispiel     : SELECT [AnalysisClass], [AnalysisLevel], [RequiresGroupGate],
                      [OriginalLoginName], [EffectiveLoginName], [IsSysadmin],
                      [ActivePolicyCount], [RelevantPolicyCount], [IsAllowed],
                      [AccessReason], [MatchedGroupCount]
               FROM [monitor].[VW_AnalyseAccessCurrent] WITH (NOLOCK)
               ORDER BY [AnalysisLevel], [AnalysisClass];
Änderungen   : 1.0.0 - Erstfassung Phase 1A.
===============================================================================
*/
CREATE OR ALTER VIEW [monitor].[VW_AnalyseAccessCurrent]
AS
    WITH ActivePolicy AS
    (
        SELECT
            [p].[AnalysisClass],
            [p].[ADGroupName],
            [p].[Priority]
        FROM [monitor].[VW_AnalyseAccessPolicy] AS [p]
        WHERE [p].[IsEnabled] = 1
          AND ([p].[ValidFromUtc] IS NULL OR [p].[ValidFromUtc] <= SYSUTCDATETIME())
          AND ([p].[ValidToUtc]   IS NULL OR [p].[ValidToUtc]   >  SYSUTCDATETIME())
          AND NULLIF(LTRIM(RTRIM([p].[AnalysisClass])), '') IS NOT NULL
          AND NULLIF(LTRIM(RTRIM([p].[ADGroupName])), '') IS NOT NULL
    ),
    PolicyState AS
    (
        SELECT COUNT_BIG(*) AS [ActivePolicyCount]
        FROM [ActivePolicy]
    ),
    LoginTokenMatches AS
    (
        SELECT DISTINCT
            [p].[AnalysisClass],
            [p].[ADGroupName]
        FROM [ActivePolicy] AS [p]
        INNER JOIN [sys].[login_token] AS [lt] WITH (NOLOCK)
            ON UPPER(CONVERT(nvarchar(256), [lt].[name])) COLLATE Latin1_General_100_CI_AS
             = UPPER([p].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
        WHERE [lt].[type] = N'WINDOWS GROUP'
    ),
    IsMemberMatches AS
    (
        SELECT DISTINCT
            [p].[AnalysisClass],
            [p].[ADGroupName]
        FROM [ActivePolicy] AS [p]
        WHERE IS_MEMBER([p].[ADGroupName]) = 1
    ),
    MatchRollup AS
    (
        SELECT
            [m].[AnalysisClass],
            COUNT_BIG(*) AS [MatchCount],
            MAX(CASE WHEN [m].[MatchSource] = 'LOGIN_TOKEN' THEN 1 ELSE 0 END) AS [HasLoginTokenMatch],
            MAX(CASE WHEN [m].[MatchSource] = 'IS_MEMBER'   THEN 1 ELSE 0 END) AS [HasIsMemberMatch]
        FROM
        (
            SELECT [ltm].[AnalysisClass], [ltm].[ADGroupName], CAST('LOGIN_TOKEN' AS varchar(20)) AS [MatchSource]
            FROM [LoginTokenMatches] AS [ltm]
            UNION ALL
            SELECT [imm].[AnalysisClass], [imm].[ADGroupName], CAST('IS_MEMBER' AS varchar(20)) AS [MatchSource]
            FROM [IsMemberMatches] AS [imm]
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [LoginTokenMatches] AS [ltm]
                WHERE [ltm].[AnalysisClass] = [imm].[AnalysisClass]
                  AND UPPER([ltm].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
                    = UPPER([imm].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
            )
        ) AS [m]
        GROUP BY [m].[AnalysisClass]
    )
    SELECT
        [c].[AnalysisClass],
        [c].[AnalysisLevel],
        [c].[RequiresGroupGate],
        ORIGINAL_LOGIN() AS [OriginalLoginName],
        SUSER_SNAME() AS [EffectiveLoginName],
        CAST(CASE WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1 ELSE 0 END AS bit) AS [IsSysadmin],
        [ps].[ActivePolicyCount],
        CAST
        (
            (
                SELECT COUNT_BIG(*)
                FROM [ActivePolicy] AS [p]
                WHERE [p].[AnalysisClass] IN ([c].[AnalysisClass], '*')
            ) AS bigint
        ) AS [RelevantPolicyCount],
        CAST
        (
            CASE
                WHEN [c].[RequiresGroupGate] = 0 THEN 1
                WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1
                WHEN [ps].[ActivePolicyCount] = 0 THEN 1
                WHEN EXISTS
                (
                    SELECT 1
                    FROM [MatchRollup] AS [mr]
                    WHERE [mr].[AnalysisClass] IN ([c].[AnalysisClass], '*')
                      AND [mr].[MatchCount] > 0
                ) THEN 1
                ELSE 0
            END
            AS bit
        ) AS [IsAllowed],
        CAST
        (
            CASE
                WHEN [c].[RequiresGroupGate] = 0 THEN 'NOT_REQUIRED'
                WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 'SYSADMIN'
                WHEN [ps].[ActivePolicyCount] = 0 THEN 'OPEN_POLICY'
                WHEN EXISTS
                (
                    SELECT 1
                    FROM [MatchRollup] AS [mr]
                    WHERE [mr].[AnalysisClass] IN ([c].[AnalysisClass], '*')
                      AND [mr].[HasLoginTokenMatch] = 1
                ) THEN 'LOGIN_TOKEN'
                WHEN EXISTS
                (
                    SELECT 1
                    FROM [MatchRollup] AS [mr]
                    WHERE [mr].[AnalysisClass] IN ([c].[AnalysisClass], '*')
                      AND [mr].[HasIsMemberMatch] = 1
                ) THEN 'IS_MEMBER'
                ELSE 'NO_MATCH'
            END
            AS varchar(20)
        ) AS [AccessReason],
        CAST
        (
            COALESCE
            (
                (
                    SELECT SUM([mr].[MatchCount])
                    FROM [MatchRollup] AS [mr]
                    WHERE [mr].[AnalysisClass] IN ([c].[AnalysisClass], '*')
                ),
                0
            ) AS bigint
        ) AS [MatchedGroupCount]
    FROM [monitor].[VW_AnalyseClassCatalog] AS [c]
    CROSS JOIN [PolicyState] AS [ps];
GO
