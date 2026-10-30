USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_AnalysisNavigator
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Findet priorisierte Analyse-Procedures nach Symptom, Ziel,
               Fachbegriff, Themenbereich, Scope oder Navigationsrolle.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : monitor.VW_AnalysisCatalog,
               monitor.VW_AnalysisSearchTerm,
               monitor.VW_AnalysisRelation,
               monitor.VW_AnalyseClassCatalog,
               sys.schemas, sys.procedures.
Sicherheit   : Führt keine gefundene Procedure aus. Liest keine produktiven
               DMVs, Benutzerkataloge, Querytexte, Pläne oder Ereignisdaten.
Suche        : Explizit case- und accent-insensitiv; unabhängig von der
               Datenbankcollation. Deutsch- und englischsprachige Begriffe.
Resultsets   : RAW: Modulstatus und navigation. CONSOLE: navigation oder eine
               verständliche Leerzeile. TABLE: navigation. NONE: keine.
JSON         : meta, navigation.
Berechtigung : Nur lesender Zugriff auf Framework- und lokale Systemmetadaten.
Eigenlast    : Gering; ausschließlich konstanter Katalog und lokale
               Installationsprüfung.
Locking      : LOCK_TIMEOUT 0; Systemkatalogzugriffe WITH (NOLOCK).
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_AnalysisNavigator]
      @Suchbegriff       nvarchar(4000) = NULL
    , @Bereich           varchar(40)    = NULL
    , @Scope             varchar(40)    = NULL
    , @Navigationsrolle  varchar(24)    = NULL
    , @NurInstallierte   bit            = 0
    , @MaxZeilen         int            = 12
    , @ResultSetArt      varchar(16)    = 'CONSOLE'
    , @ResultTablesJson  nvarchar(max)  = NULL
    , @JsonErzeugen      bit            = 0
    , @Json              nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen    bit            = 1
    , @Hilfe             bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit =
        CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit =
        CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname = NULL;

    IF @TableResultRequested = 0
       AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson, N''))), N'') IS NOT NULL
        THROW 51011, N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.', 1;

    IF @TableResultRequested = 1
        EXEC [monitor].[InternalPrepareSingleResultTable]
              @ResultTablesJson = @ResultTablesJson
            , @ResultName = N'navigation'
            , @TargetTable = @TableTarget OUTPUT
            , @ThrowOnError = 1;

    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1
        SET @ResultSetArtNormalisiert = 'NONE';

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_AnalysisNavigator';
        PRINT N'Der Navigator zeigt passende Katalogeinträge. Er führt keinen Treffer und keine Analyse aus.';
        PRINT N'Für bit-Parameter gelten 0 und 1 logisch; andere in bit konvertierbare Nicht-NULL-Werte werden durch T-SQL zu 1 konvertiert.';
        PRINT N'@Suchbegriff nvarchar(4000), Default=NULL: freier Unicode-Suchtext; NULL, leer oder nur Rand-Leerzeichen deaktiviert die Textsuche; ohne Bereichs-, Scope- und Rollenfilter erscheint die kuratierte Startliste, mit solchen Filtern die passende Katalogmenge. Getrimmt höchstens 400 Zeichen, sonst INVALID_PARAMETER. Suche case- und accent-insensitiv; technische Namenssuche entfernt [ ] und führendes monitor.; Tokens an Leerzeichen, unter 3 Zeichen/Stoppwörter entfallen, je Token max. 200 Zeichen.';
        PRINT N'Exakte Procedure-/Anzeigenamen und Phrasen wiegen stärker als Tokenüberschneidungen; Treffer werden nach Score, Rolle und Namen geordnet. Rollen geben nur einen kleinen Bonus. Ohne Filter gilt die kuratierte DefaultRank-Liste.';
        PRINT N'@Bereich varchar(40), Default=NULL: NULL/leer deaktiviert den Filter; sonst getrimmt, uppercase und case-/accent-insensitiv gegen PrimaryAreaCode. Nur diese Katalogcodes: NAVIGATION=Einstieg/Orientierung; FRAMEWORK=Framework/Zugriff; LIVE=akute Störung/laufende Requests sowie aktuelle Aktivität, Blocking und Ressourcen; OBJECT=Objekte/Indizes/Statistiken; PLAN=langsame Query/Ausführungsplan; QUERY_STORE=Query Store/Laufzeithistorie und Regressionen; EXTENDED_EVENTS=Extended Events/Forensik; OPERATIONS=Backup/Agent/HA-DR/Betrieb; SERVER=CPU/Memory/Worker, Serverzustand/Ressourcen, Server Health, Konfiguration und Sicherheit; SPECIAL_FEATURE=Konfiguration/Sicherheit/Spezialfeatures; SNAPSHOT=optionales Snapshot-/Baseline-Paket. Andere Werte ergeben INVALID_PARAMETER.';
        PRINT N'@Scope varchar(40), Default=NULL: NULL/leer deaktiviert den Filter; sonst getrimmt, uppercase und case-/accent-insensitiv gegen ScopeCode. Katalogcodes samt Einheit: DATABASE=eine Datenbank; EVENT_HISTORY=persistierte Ereignishistorie; EVENT_SESSION=Ereignissitzung; FRAMEWORK=Frameworkmetadaten; INFRASTRUCTURE=lokale Infrastruktur; MULTI_DATABASE=mehrere Datenbanken; OBJECT=bekanntes Objekt; PLAN_XML=Ausführungsplan-XML; QUERY=Query; SERVER=Instanz; SESSION_REQUEST=Session/Request; SNAPSHOT_TARGET=Snapshotziel. Andere Werte ergeben INVALID_PARAMETER.';
        PRINT N'@Navigationsrolle varchar(24), Default=NULL: NULL/leer deaktiviert den Filter; sonst getrimmt, uppercase und case-/accent-insensitiv. ENTRY=sicherer allgemeiner Einstieg; FOLLOW_UP=Folgepfad zu einem bereits beobachteten Signal; TARGETED=gezielter Pfad mit bekanntem Ziel; SETUP=Setup-/Betriebspfad; SUPPORT=interner Unterstützungs-/Aufrufvertrag. Nur diese fünf Werte; andere ergeben INVALID_PARAMETER.';
        PRINT N'@NurInstallierte bit, Default=0: NULL ist INVALID_PARAMETER; 0 zeigt alle passenden Katalogzeilen einschließlich optional nicht installierter Procedures, 1 beschränkt auf lokal im Schema monitor in sys.procedures vorhandene Procedures. Keine Prüfung von Rechten oder Featurefähigkeit.';
        PRINT N'@MaxZeilen int, Default=12: NULL oder 0 bedeutet kein Ergebnislimit; 1 bis 100 begrenzt Treffer auf diese Zeilenzahl. Negative Werte und Werte über 100 ergeben INVALID_PARAMETER.';
        PRINT N'@ResultSetArt varchar(16), Default=CONSOLE: nach Trim und Uppercase genau CONSOLE, RAW, TABLE oder NONE. CONSOLE rendert navigation; RAW liefert Status dann navigation; TABLE schreibt navigation ins Ziel; NONE unterdrückt Resultsets. NULL, leer und andere Werte ergeben INVALID_PARAMETER, ohne Rückfall auf CONSOLE. Ein ungültiger Ausgabewert liefert Status und navigation.';
        PRINT N'@ResultTablesJson nvarchar(max), Default=NULL: Bei TABLE ist ein JSON-Objekt mit genau einem Schlüssel navigation und einem JSON-String als Wert erforderlich. Der String benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte. NULL, leer oder nur Leerzeichen ist bei TABLE ungültig; außerhalb TABLE darf nur NULL, leerer Text oder ein Text nur aus Leerzeichen stehen. Eine nichtleere Zuordnung außerhalb TABLE löst THROW 51011 aus. Zielprüfung mit Marker-DDL läuft vor Hilfe.';
        PRINT N'@JsonErzeugen bit, Default=0: 1 erzeugt @Json mit meta und navigation aus derselben Materialisierung; 0 oder NULL deaktiviert JSON. Unabhängig von @ResultSetArt.';
        PRINT N'@Json nvarchar(max), Default=NULL OUTPUT: optionale Bindung einer nvarchar(max)-Variablen mit OUTPUT, wenn JSON empfangen werden soll; Default NULL bedeutet keinen Eingabewert. Wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 enthält die Variable meta und navigation; bei @Hilfe=1 bleibt sie NULL.';
        PRINT N'@PrintMeldungen bit, Default=1: nur 1 aktiviert die zusätzliche Severity-10-Fehlermeldung im CATCH; 0 oder NULL unterdrückt sie. Keine Wirkung auf Hilfe, Resultsets oder JSON.';
        PRINT N'@Hilfe bit, Default=0: nur 1 druckt diese Hilfe und beendet vor Suche/Rendering; 0 oder NULL deaktiviert sie. TABLE-Preflight läuft vorher und kann bei ungültigem Ziel abbrechen.';
        PRINT N'CONSOLE liefert navigation, bei leerer Menge mit verständlicher Leerzeile. RAW liefert zuerst Status und dann navigation; TABLE schreibt navigation; NONE unterdrückt Resultsets.';
        PRINT N'Bei leerem RAW/TABLE-Ergebnis gibt es keine künstliche navigation-Zeile. JSON enthält meta und ein leeres navigation-Array; NONE beeinflusst JSON und Meldungen nicht.';
        PRINT N'Beispiel Suche: EXEC [monitor].[USP_AnalysisNavigator] @Suchbegriff=N''Benutzer warten'', @ResultSetArt=''RAW'';';
        PRINT N'Beispiel JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_AnalysisNavigator] @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json;';
        PRINT N'Beispiel TABLE: CREATE TABLE #AnalysisNavigator_HelpExample (Seed bit NULL);';
        PRINT N'DECLARE @Map nvarchar(max)=N''{"navigation":"#AnalysisNavigator_HelpExample"}''; EXEC [monitor].[USP_AnalysisNavigator] @ResultSetArt=''TABLE'', @ResultTablesJson=@Map; DROP TABLE #AnalysisNavigator_HelpExample;';
        RETURN;
    END;

    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;

    DECLARE @SuchbegriffNormalisiert nvarchar(4000) =
        NULLIF(LTRIM(RTRIM(COALESCE(@Suchbegriff, N''))), N'');
    DECLARE @SuchbegriffVergleich nvarchar(4000) = @SuchbegriffNormalisiert;
    DECLARE @BereichNormalisiert varchar(40) =
        NULLIF(UPPER(LTRIM(RTRIM(COALESCE(@Bereich, '')))), '');
    DECLARE @ScopeNormalisiert varchar(40) =
        NULLIF(UPPER(LTRIM(RTRIM(COALESCE(@Scope, '')))), '');
    DECLARE @RolleNormalisiert varchar(24) =
        NULLIF(UPPER(LTRIM(RTRIM(COALESCE(@Navigationsrolle, '')))), '');
    DECLARE @HasSearch bit = CASE WHEN @SuchbegriffNormalisiert IS NULL THEN 0 ELSE 1 END;
    DECLARE @HasFilter bit = CASE
        WHEN @BereichNormalisiert IS NOT NULL
          OR @ScopeNormalisiert IS NOT NULL
          OR @RolleNormalisiert IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @MaxZeilenEffektiv int = CASE
        WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0 THEN 2147483647
        ELSE @MaxZeilen
    END;

    IF @SuchbegriffVergleich IS NOT NULL
    BEGIN
        SET @SuchbegriffVergleich = REPLACE(REPLACE(@SuchbegriffVergleich, N'[', N''), N']', N'');
        IF LEFT(@SuchbegriffVergleich, 8) COLLATE Latin1_General_100_CI_AI = N'monitor.'
            SET @SuchbegriffVergleich = SUBSTRING(@SuchbegriffVergleich, 9, 4000);
    END;

    CREATE TABLE [#AnalysisNavigator_SearchToken]
    (
        [Token] nvarchar(200) COLLATE Latin1_General_100_CI_AI NOT NULL PRIMARY KEY
    );

    CREATE TABLE [#AnalysisNavigator_Navigation]
    (
          [Rank]                              int             NOT NULL
        , [RelevanceScore]                    int             NOT NULL
        , [ProcedureName]                     sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [DisplayName]                       nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [NavigationRole]                    varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PrimaryAreaCode]                   varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PrimaryAreaName]                   nvarchar(160) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ScopeCode]                         varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceType]                      varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CostRangeCode]                     varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RepresentativeAnalysisClass]       varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AnalysisLevel]                     varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RequiresGroupGate]                 bit             NULL
        , [WhyMatched]                        nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Purpose]                           nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [PrerequisiteSummary]               nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RequiresKnownTarget]               bit             NOT NULL
        , [RequiresHighImpactForSafeStart]    bit             NOT NULL
        , [HighImpactPathAvailable]           bit             NOT NULL
        , [PackageCode]                       varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsInstalled]                       bit             NOT NULL
        , [SafeCall]                          nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [NextProcedureName]                 sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RelationType]                      varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [NextStep]                          nvarchar(700) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RunbookPath]                       nvarchar(400) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [DocumentationPath]                 nvarchar(400) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    IF @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @IsPartial = 1
            , @ErrorMessage = N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
    END;
    ELSE IF @MaxZeilen < 0 OR @MaxZeilen > 100
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @IsPartial = 1
            , @ErrorMessage = N'@MaxZeilen muss NULL, 0 oder ein Wert zwischen 1 und 100 sein.';
    END;
    ELSE IF @NurInstallierte IS NULL
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @IsPartial = 1
            , @ErrorMessage = N'@NurInstallierte darf nicht NULL sein.';
    END;
    ELSE IF @SuchbegriffNormalisiert IS NOT NULL AND LEN(@SuchbegriffNormalisiert) > 400
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @IsPartial = 1
            , @ErrorMessage = N'@Suchbegriff darf höchstens 400 Zeichen enthalten.';
    END;
    ELSE IF @BereichNormalisiert IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1
            FROM [monitor].[VW_AnalysisCatalog] AS [c]
            WHERE [c].[PrimaryAreaCode] COLLATE Latin1_General_100_CI_AI =
                  @BereichNormalisiert COLLATE Latin1_General_100_CI_AI
        )
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @IsPartial = 1
            , @ErrorMessage = N'@Bereich ist unbekannt. Gültige Codes stehen in monitor.VW_AnalysisCatalog.PrimaryAreaCode.';
    END;
    ELSE IF @ScopeNormalisiert IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1
            FROM [monitor].[VW_AnalysisCatalog] AS [c]
            WHERE [c].[ScopeCode] COLLATE Latin1_General_100_CI_AI =
                  @ScopeNormalisiert COLLATE Latin1_General_100_CI_AI
        )
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @IsPartial = 1
            , @ErrorMessage = N'@Scope ist unbekannt. Gültige Codes stehen in monitor.VW_AnalysisCatalog.ScopeCode.';
    END;
    ELSE IF @RolleNormalisiert IS NOT NULL
        AND @RolleNormalisiert NOT IN ('ENTRY', 'FOLLOW_UP', 'TARGETED', 'SETUP', 'SUPPORT')
    BEGIN
        SELECT
              @StatusCode = 'INVALID_PARAMETER'
            , @IsPartial = 1
            , @ErrorMessage = N'@Navigationsrolle muss ENTRY, FOLLOW_UP, TARGETED, SETUP oder SUPPORT enthalten.';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE' AND @HasSearch = 1
    BEGIN
        INSERT [#AnalysisNavigator_SearchToken]([Token])
        SELECT DISTINCT
            CONVERT(nvarchar(200), LEFT(LTRIM(RTRIM([s].[value])), 200))
                COLLATE Latin1_General_100_CI_AI
        FROM STRING_SPLIT(@SuchbegriffNormalisiert, N' ') AS [s]
        WHERE LEN(LTRIM(RTRIM([s].[value]))) >= 3
          AND LTRIM(RTRIM([s].[value])) COLLATE Latin1_General_100_CI_AI NOT IN
              (N'der',N'die',N'das',N'den',N'dem',N'des',N'ein',N'eine',N'einer',N'einem',N'und',N'oder',N'mit',N'von',N'ist',N'sind',N'bei',N'für',N'was',N'wie',N'the',N'and',N'for',N'with',N'from',N'use');
    END;

    DECLARE @TokenCount int =
        (SELECT COUNT(*) FROM [#AnalysisNavigator_SearchToken]);

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        ;WITH [Candidate] AS
        (
            SELECT
                  [c].[ProcedureName]
                , [c].[DisplayName]
                , [c].[NavigationRole]
                , [c].[PrimaryAreaCode]
                , [c].[PrimaryAreaName]
                , [c].[ScopeCode]
                , [c].[EvidenceType]
                , [c].[CostRangeCode]
                , [c].[RepresentativeAnalysisClass]
                , [ac].[AnalysisLevel]
                , [ac].[RequiresGroupGate]
                , [c].[Purpose]
                , [c].[PrerequisiteSummary]
                , [c].[RequiresKnownTarget]
                , [c].[RequiresHighImpactForSafeStart]
                , [c].[HighImpactPathAvailable]
                , [c].[PackageCode]
                , CONVERT(bit, CASE WHEN [p].[object_id] IS NULL THEN 0 ELSE 1 END) AS [IsInstalled]
                , [c].[SafeCall]
                , [nr].[ToProcedureName] AS [NextProcedureName]
                , [nr].[RelationType]
                , [nr].[ConditionSummary] AS [NextStep]
                , [c].[RunbookPath]
                , [c].[DocumentationPath]
                , CONVERT(nvarchar(500),
                    CASE
                        WHEN @HasSearch = 0 AND @HasFilter = 0
                            THEN N'Priorisierter, sicherer Einstieg in die Frameworkanalyse.'
                        WHEN @HasSearch = 0
                            THEN CONCAT(N'Passend zu Bereich, Scope oder Navigationsrolle: ', [c].[PrimaryAreaName], N'.')
                        WHEN [c].[ProcedureName] COLLATE Latin1_General_100_CI_AI =
                             @SuchbegriffVergleich COLLATE Latin1_General_100_CI_AI
                            THEN N'Der Suchbegriff entspricht dem technischen Procedurenamen.'
                        WHEN [c].[DisplayName] COLLATE Latin1_General_100_CI_AI =
                             @SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI
                            THEN N'Der Suchbegriff entspricht dem fachlichen Anzeigenamen.'
                        WHEN [tm].[MatchReason] IS NOT NULL THEN [tm].[MatchReason]
                        WHEN [tk].[TokenMatchCount] > 0
                            THEN CONCAT([tk].[TokenMatchCount], N' wesentliche Suchbegriffe passen zu Zweck, Scope oder Synonymen.')
                        ELSE N'Der Suchbegriff passt zu den fachlichen Katalogmetadaten.'
                    END) AS [WhyMatched]
                , CONVERT(int,
                    CASE
                        WHEN @HasSearch = 0 AND @HasFilter = 0
                            THEN 2000 - COALESCE([c].[DefaultRank], 1000)
                        WHEN @HasSearch = 0
                            THEN CASE [c].[NavigationRole]
                                    WHEN 'ENTRY' THEN 800
                                    WHEN 'FOLLOW_UP' THEN 700
                                    WHEN 'TARGETED' THEN 600
                                    WHEN 'SETUP' THEN 500
                                    ELSE 400
                                 END
                        ELSE
                              CASE
                                  WHEN [c].[ProcedureName] COLLATE Latin1_General_100_CI_AI =
                                       @SuchbegriffVergleich COLLATE Latin1_General_100_CI_AI THEN 2400
                                  WHEN [c].[DisplayName] COLLATE Latin1_General_100_CI_AI =
                                       @SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI THEN 2300
                                  WHEN CHARINDEX(@SuchbegriffVergleich COLLATE Latin1_General_100_CI_AI,
                                                 [c].[ProcedureName] COLLATE Latin1_General_100_CI_AI) > 0 THEN 900
                                  WHEN CHARINDEX(@SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI,
                                                 [c].[DisplayName] COLLATE Latin1_General_100_CI_AI) > 0 THEN 850
                                  WHEN CHARINDEX(@SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI,
                                                 [c].[Purpose] COLLATE Latin1_General_100_CI_AI) > 0 THEN 700
                                  WHEN CHARINDEX(@SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI,
                                                 [c].[PrerequisiteSummary] COLLATE Latin1_General_100_CI_AI) > 0 THEN 600
                                  ELSE 0
                              END
                            + COALESCE([tm].[TermMatchScore], 0)
                            + COALESCE([tk].[TokenMatchCount], 0) * 80
                            + CASE WHEN @TokenCount > 0 AND [tk].[TokenMatchCount] = @TokenCount THEN 300 ELSE 0 END
                            + CASE [c].[NavigationRole]
                                  WHEN 'ENTRY' THEN 50
                                  WHEN 'FOLLOW_UP' THEN 35
                                  WHEN 'TARGETED' THEN 20
                                  WHEN 'SETUP' THEN 10
                                  ELSE 0
                              END
                    END) AS [RelevanceScore]
            FROM [monitor].[VW_AnalysisCatalog] AS [c]
            LEFT JOIN [monitor].[VW_AnalyseClassCatalog] AS [ac]
              ON [ac].[AnalysisClass] = [c].[RepresentativeAnalysisClass]
            LEFT JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
              ON [s].[name] = N'monitor'
            LEFT JOIN [sys].[procedures] AS [p] WITH (NOLOCK)
              ON [p].[schema_id] = [s].[schema_id]
             AND [p].[name] = [c].[ProcedureName]
            OUTER APPLY
            (
                SELECT TOP (1)
                      [st].[MatchReason]
                    , CONVERT(int,
                        CASE
                            WHEN [st].[SearchTerm] COLLATE Latin1_General_100_CI_AI =
                                 @SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI
                                THEN 1500 + [st].[SearchWeight]
                            WHEN CHARINDEX(@SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI,
                                           [st].[SearchTerm] COLLATE Latin1_General_100_CI_AI) > 0
                                THEN 1200 + [st].[SearchWeight]
                            WHEN LEN([st].[SearchTerm]) >= 4
                             AND CHARINDEX([st].[SearchTerm] COLLATE Latin1_General_100_CI_AI,
                                           @SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI) > 0
                                THEN 1100 + [st].[SearchWeight]
                            ELSE 0
                        END) AS [TermMatchScore]
                FROM [monitor].[VW_AnalysisSearchTerm] AS [st]
                WHERE @HasSearch = 1
                  AND [st].[ProcedureName] = [c].[ProcedureName]
                  AND
                  (
                      [st].[SearchTerm] COLLATE Latin1_General_100_CI_AI =
                          @SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI
                      OR CHARINDEX(@SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI,
                                   [st].[SearchTerm] COLLATE Latin1_General_100_CI_AI) > 0
                      OR
                      (
                          LEN([st].[SearchTerm]) >= 4
                          AND CHARINDEX([st].[SearchTerm] COLLATE Latin1_General_100_CI_AI,
                                        @SuchbegriffNormalisiert COLLATE Latin1_General_100_CI_AI) > 0
                      )
                  )
                ORDER BY [TermMatchScore] DESC, [st].[SearchWeight] DESC, [st].[SearchTerm]
            ) AS [tm]
            OUTER APPLY
            (
                SELECT CONVERT(int, COUNT(*)) AS [TokenMatchCount]
                FROM [#AnalysisNavigator_SearchToken] AS [t]
                WHERE CHARINDEX([t].[Token], [c].[ProcedureName] COLLATE Latin1_General_100_CI_AI) > 0
                   OR CHARINDEX([t].[Token], [c].[DisplayName] COLLATE Latin1_General_100_CI_AI) > 0
                   OR CHARINDEX([t].[Token], [c].[PrimaryAreaName] COLLATE Latin1_General_100_CI_AI) > 0
                   OR CHARINDEX([t].[Token], [c].[Purpose] COLLATE Latin1_General_100_CI_AI) > 0
                   OR EXISTS
                      (
                          SELECT 1
                          FROM [monitor].[VW_AnalysisSearchTerm] AS [st]
                          WHERE [st].[ProcedureName] = [c].[ProcedureName]
                            AND CHARINDEX([t].[Token], [st].[SearchTerm] COLLATE Latin1_General_100_CI_AI) > 0
                      )
            ) AS [tk]
            OUTER APPLY
            (
                SELECT TOP (1)
                      [r].[ToProcedureName]
                    , [r].[RelationType]
                    , [r].[ConditionSummary]
                FROM [monitor].[VW_AnalysisRelation] AS [r]
                WHERE [r].[FromProcedureName] = [c].[ProcedureName]
                ORDER BY
                      CASE [r].[RelationType]
                          WHEN 'REFINE_WITH' THEN 1
                          WHEN 'CONFIRM_WITH' THEN 2
                          WHEN 'PREPARE_WITH' THEN 3
                          ELSE 4
                      END
                    , [r].[RelationPriority]
                    , [r].[ToProcedureName]
            ) AS [nr]
            WHERE [c].[ProcedureName] <> N'USP_AnalysisNavigator'
              AND (@BereichNormalisiert IS NULL OR
                   [c].[PrimaryAreaCode] COLLATE Latin1_General_100_CI_AI =
                   @BereichNormalisiert COLLATE Latin1_General_100_CI_AI)
              AND (@ScopeNormalisiert IS NULL OR
                   [c].[ScopeCode] COLLATE Latin1_General_100_CI_AI =
                   @ScopeNormalisiert COLLATE Latin1_General_100_CI_AI)
              AND (@RolleNormalisiert IS NULL OR
                   [c].[NavigationRole] COLLATE Latin1_General_100_CI_AI =
                   @RolleNormalisiert COLLATE Latin1_General_100_CI_AI)
              AND (@NurInstallierte = 0 OR [p].[object_id] IS NOT NULL)
              AND (@HasSearch = 1 OR @HasFilter = 1 OR [c].[DefaultRank] IS NOT NULL)
        ),
        [Limited] AS
        (
            SELECT TOP (@MaxZeilenEffektiv) *
            FROM [Candidate]
            WHERE @HasSearch = 0 OR [RelevanceScore] > 0
            ORDER BY
                  [RelevanceScore] DESC
                , CASE [NavigationRole]
                      WHEN 'ENTRY' THEN 1
                      WHEN 'FOLLOW_UP' THEN 2
                      WHEN 'TARGETED' THEN 3
                      WHEN 'SETUP' THEN 4
                      ELSE 5
                  END
                , [DisplayName]
                , [ProcedureName]
        )
        INSERT [#AnalysisNavigator_Navigation]
        (
              [Rank], [RelevanceScore], [ProcedureName], [DisplayName]
            , [NavigationRole], [PrimaryAreaCode], [PrimaryAreaName], [ScopeCode]
            , [EvidenceType], [CostRangeCode], [RepresentativeAnalysisClass]
            , [AnalysisLevel], [RequiresGroupGate], [WhyMatched], [Purpose]
            , [PrerequisiteSummary], [RequiresKnownTarget]
            , [RequiresHighImpactForSafeStart], [HighImpactPathAvailable]
            , [PackageCode], [IsInstalled], [SafeCall], [NextProcedureName]
            , [RelationType], [NextStep], [RunbookPath], [DocumentationPath]
        )
        SELECT
              CONVERT(int, ROW_NUMBER() OVER
              (
                  ORDER BY
                        [RelevanceScore] DESC
                      , CASE [NavigationRole]
                            WHEN 'ENTRY' THEN 1
                            WHEN 'FOLLOW_UP' THEN 2
                            WHEN 'TARGETED' THEN 3
                            WHEN 'SETUP' THEN 4
                            ELSE 5
                        END
                      , [DisplayName]
                      , [ProcedureName]
              )) AS [Rank]
            , [RelevanceScore], [ProcedureName], [DisplayName]
            , [NavigationRole], [PrimaryAreaCode], [PrimaryAreaName], [ScopeCode]
            , [EvidenceType], [CostRangeCode], [RepresentativeAnalysisClass]
            , [AnalysisLevel], [RequiresGroupGate], [WhyMatched], [Purpose]
            , [PrerequisiteSummary], [RequiresKnownTarget]
            , [RequiresHighImpactForSafeStart], [HighImpactPathAvailable]
            , [PackageCode], [IsInstalled], [SafeCall], [NextProcedureName]
            , [RelationType], [NextStep], [RunbookPath], [DocumentationPath]
        FROM [Limited];

        IF NOT EXISTS (SELECT 1 FROM [#AnalysisNavigator_Navigation])
        BEGIN
            SELECT
                  @StatusCode = 'NO_MATCH'
                , @IsPartial = 0
                , @ErrorMessage = N'Für die gewählte Suche und die aktiven Filter wurde kein Katalogtreffer gefunden.';
        END;
    END TRY
    BEGIN CATCH
        SELECT
              @StatusCode = CASE WHEN ERROR_NUMBER() = 1222 THEN 'LOCK_TIMEOUT' ELSE 'ERROR_HANDLED' END
            , @IsPartial = 1
            , @ErrorNumber = ERROR_NUMBER()
            , @ErrorMessage = ERROR_MESSAGE();

        IF @PrintMeldungen = 1
            RAISERROR(N'Der Analysis Navigator konnte den Katalog nicht vollständig auswerten: %s', 10, 1, @ErrorMessage) WITH NOWAIT;
    END CATCH;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              @CollectionTimeUtc AS [CollectionTimeUtc]
            , CAST(N'monitor.USP_AnalysisNavigator' AS nvarchar(256)) AS [ModuleName]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage]
            , @SuchbegriffNormalisiert AS [SearchTerm]
            , @BereichNormalisiert AS [AreaFilter]
            , @ScopeNormalisiert AS [ScopeFilter]
            , @RolleNormalisiert AS [RoleFilter]
            , @NurInstallierte AS [InstalledOnly]
            , @MaxZeilen AS [MaxRows];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT
                  [Rank], [RelevanceScore], [ProcedureName], [DisplayName]
                , [NavigationRole], [PrimaryAreaCode], [PrimaryAreaName], [ScopeCode]
                , [EvidenceType], [CostRangeCode], [RepresentativeAnalysisClass]
                , [AnalysisLevel], [RequiresGroupGate], [WhyMatched], [Purpose]
                , [PrerequisiteSummary], [RequiresKnownTarget]
                , [RequiresHighImpactForSafeStart], [HighImpactPathAvailable]
                , [PackageCode], [IsInstalled], [SafeCall], [NextProcedureName]
                , [RelationType], [NextStep], [RunbookPath], [DocumentationPath]
            FROM [#AnalysisNavigator_Navigation]
            ORDER BY [Rank];
        END;
        ELSE
        BEGIN
            SELECT
                  [Rank], [RelevanceScore], [ProcedureName], [DisplayName]
                , [NavigationRole], [PrimaryAreaCode], [PrimaryAreaName], [ScopeCode]
                , [EvidenceType], [CostRangeCode], [RepresentativeAnalysisClass]
                , [AnalysisLevel], [RequiresGroupGate], [WhyMatched], [Purpose]
                , [PrerequisiteSummary], [RequiresKnownTarget]
                , [RequiresHighImpactForSafeStart], [HighImpactPathAvailable]
                , [PackageCode], [IsInstalled], [SafeCall], [NextProcedureName]
                , [RelationType], [NextStep], [RunbookPath], [DocumentationPath]
            FROM [#AnalysisNavigator_Navigation]
            ORDER BY [Rank];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'AnalysisNavigator' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @IsPartial AS [isPartial]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
                , @SuchbegriffNormalisiert AS [searchTerm]
                , @BereichNormalisiert AS [areaFilter]
                , @ScopeNormalisiert AS [scopeFilter]
                , @RolleNormalisiert AS [roleFilter]
                , @NurInstallierte AS [installedOnly]
                , @MaxZeilen AS [maxRows]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );

        DECLARE @NavigationJson nvarchar(max) =
        (
            SELECT
                  [Rank], [RelevanceScore], [ProcedureName], [DisplayName]
                , [NavigationRole], [PrimaryAreaCode], [PrimaryAreaName], [ScopeCode]
                , [EvidenceType], [CostRangeCode], [RepresentativeAnalysisClass]
                , [AnalysisLevel], [RequiresGroupGate], [WhyMatched], [Purpose]
                , [PrerequisiteSummary], [RequiresKnownTarget]
                , [RequiresHighImpactForSafeStart], [HighImpactPathAvailable]
                , [PackageCode], [IsInstalled], [SafeCall], [NextProcedureName]
                , [RelationType], [NextStep], [RunbookPath], [DocumentationPath]
            FROM [#AnalysisNavigator_Navigation]
            ORDER BY [Rank]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"navigation":', COALESCE(@NavigationJson, N'[]')
            , N'}'
        );
    END;

    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable = N'#AnalysisNavigator_Navigation'
            , @ResultLabel = N'Analysis Navigator'
            , @EmptyMessage = N'Keine passende Analyse gefunden'
            , @StatusCode = @StatusCode
            , @StatusMessage = @ErrorMessage;
    END;

    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#AnalysisNavigator_Navigation'
            , @TargetTable = @TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
