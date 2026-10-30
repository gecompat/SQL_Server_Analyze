USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_CheckAnalyseAccess
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Prüft die effektive Analyseklassen- und AD-Gruppenpolicy.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optional JSON mit access und policies.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CheckAnalyseAccess]
      @AnalyseKlasse   varchar(64)    = NULL
    , @NurGesperrte    bit            = 0
    , @ResultSetArt    varchar(16)     = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen    bit             = 0
    , @Json             nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen  bit             = 1
    , @Hilfe            bit             = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET @Json = NULL;

    DECLARE @ResultSetArtNormalisiert varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @ResultSetArtNormalisiert = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'access',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @CollectionTimeUtc datetime2(3) = SYSUTCDATETIME();

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_CheckAnalyseAccess prüft den Framework-Gruppengate für Analyseklassen im aktuellen Login- und Execution-Kontext. Die Procedure führt keine Fachanalyse aus und vergibt keine SQL-Rechte.';
        PRINT N'Quellen: Klassenkatalog, VW_AnalyseAccessCurrent, VW_AnalyseAccessPolicy, sys.login_token und IS_MEMBER. Momentaufnahme gegen SYSUTCDATETIME(); kein Live-AD- oder Objektberechtigungsnachweis.';
        PRINT N'Ohne aktive Policy ist der Gate offen. Sobald global mindestens eine aktive Policy existiert, kann eine geschützte Klasse ohne spezifische oder *-Regel gesperrt sein. Token-Match hat Vorrang vor IS_MEMBER; sonst NO_MATCH.';
        PRINT N'@AnalyseKlasse varchar(64)=NULL: alle Klassen; sonst vorhandener Katalogcode, exakt und case-sensitiv. NULL ist kein Fehler. Leerer oder unbekannter Code ergibt INVALID_PARAMETER.';
        PRINT N'@NurGesperrte bit=0: alle Accesszeilen; 1: nur IsAllowed=0. NULL aktiviert den Filter ebenfalls. Dieser Filter betrifft Access, nicht Policies.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE'': CONSOLE (Default), RAW, TABLE oder NONE; NULL/ungültig ergibt INVALID_PARAMETER. Erkennung case-insensitiv, äußere Leerzeichen werden entfernt.';
        PRINT N'CONSOLE rendert Access als Ergebnis und zeigt zusätzlich Policy- und Warning-Resultsets. RAW liefert Meta, Access, Policies und Warnings als vier technische Resultsets.';
        PRINT N'TABLE schreibt ausschließlich das benannte access-Resultset mit 12 Accessfeldern in eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte vom Typ bit NULL.';
        PRINT N'access-Felder: AnalysisClass varchar(64), AnalysisLevel varchar(16), RequiresGroupGate bit, OriginalLoginName sysname NULL, EffectiveLoginName sysname NULL, IsSysadmin bit NULL, ActivePolicyCount bigint NULL, RelevantPolicyCount bigint NULL, IsAllowed bit, AccessReason varchar(20) NULL, MatchedGroupCount bigint NULL, StatusCode varchar(40).';
        PRINT N'TABLE-Preflight kann vor der Hilfe lokale TempDB-Metadaten per DDL ändern und bei ungültiger Zuordnung mit Fehler 51011/Preflightfehler abbrechen. Kein Max-Zeilen-Parameter.';
        PRINT N'NONE liefert keine fachlichen Resultsets. Statusmeldungen und JSON sind davon unabhängig; @PrintMeldungen=0 unterdrückt weder Hilfe noch JSON.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL: keine Zuordnung; bei TABLE JSON-Objekt access auf vorhandene leere lokale #temp-Tabelle abbilden. Sonst nur mit TABLE zulässig, andernfalls THROW 51011.';
        PRINT N'@JsonErzeugen bit=0: kein JSON; 1: @Json wird mit meta-Objekt und access-, policies- und warnings-Arrays erzeugt. NULL aktiviert JSON nicht.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT: Ausgabeparameter; wird zu Beginn auf NULL gesetzt, auch bei Hilfe. JSON enthält die ermittelten Felder samt NULL-Werten.';
        PRINT N'@PrintMeldungen bit=1: nur eine behandelte Fehlermeldung wird zusätzlich als Severity-10-Meldung ausgegeben. 0 unterdrückt diese Meldung, nicht RAW/CONSOLE/WARNING-Ausgaben; NULL aktiviert sie nicht.';
        PRINT N'@Hilfe bit=0: normale Ausführung; 1 gibt diese Hilfe unabhängig von @PrintMeldungen aus und beendet danach. NULL aktiviert Hilfe nicht. TABLE-Preflight liegt davor.';
        PRINT N'Beispiel – Hilfe: EXEC [monitor].[USP_CheckAnalyseAccess] @Hilfe=1;';
        PRINT N'Beispiel – Standard: EXEC [monitor].[USP_CheckAnalyseAccess];';
        PRINT N'Beispiel – Klasse und RAW: EXEC [monitor].[USP_CheckAnalyseAccess] @AnalyseKlasse=''PLAN_CACHE_DEEP'', @ResultSetArt=''RAW'';';
        PRINT N'Beispiel – nur gesperrte Klassen: EXEC [monitor].[USP_CheckAnalyseAccess] @NurGesperrte=1, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel – JSON: DECLARE @j nvarchar(max); EXEC [monitor].[USP_CheckAnalyseAccess] @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;';
        PRINT N'Beispiel – NONE: EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt=''NONE'', @JsonErzeugen=1;';
        PRINT N'Beispiel – TABLE: CREATE TABLE #Access_HelpExample (Seed bit NULL);';
        PRINT N'DECLARE @map nvarchar(max)=N''{"access":"#Access_HelpExample"}''; EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt=''TABLE'', @ResultTablesJson=@map; DROP TABLE #Access_HelpExample;';
        RETURN;
    END;

    CREATE TABLE [#CheckAnalyseAccess_Access]
    (
          [AnalysisClass] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [AnalysisLevel] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [RequiresGroupGate] bit NOT NULL
        , [OriginalLoginName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EffectiveLoginName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSysadmin] bit NULL
        , [ActivePolicyCount] bigint NULL
        , [RelevantPolicyCount] bigint NULL
        , [IsAllowed] bit NOT NULL
        , [AccessReason] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [MatchedGroupCount] bigint NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#CheckAnalyseAccess_Policies]
    (
          [AnalysisClass] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ADGroupName] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [Priority] int NOT NULL
        , [ValidFromUtc] datetime2(3) NULL
        , [ValidToUtc] datetime2(3) NULL
        , [MatchesLoginToken] bit NOT NULL
        , [MatchesIsMember] bit NOT NULL
        , [Comment] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#CheckAnalyseAccess_Warnings]
    (
          [WarningCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [WarningMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    IF @ResultSetArtNormalisiert NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@ResultSetArt muss CONSOLE, RAW, TABLE oder NONE enthalten.';
    END;
    ELSE IF @AnalyseKlasse IS NOT NULL
        AND NOT EXISTS
        (
            SELECT 1
            FROM [monitor].[VW_AnalyseClassCatalog] AS [c]
            WHERE [c].[AnalysisClass] = @AnalyseKlasse
        )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Die Analyseklasse ist nicht in monitor.VW_AnalyseClassCatalog definiert.';
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN TRY
        INSERT [#CheckAnalyseAccess_Access]
        (
              [AnalysisClass], [AnalysisLevel], [RequiresGroupGate]
            , [OriginalLoginName], [EffectiveLoginName], [IsSysadmin]
            , [ActivePolicyCount], [RelevantPolicyCount], [IsAllowed]
            , [AccessReason], [MatchedGroupCount], [StatusCode]
        )
        SELECT
              [a].[AnalysisClass], [a].[AnalysisLevel], [a].[RequiresGroupGate]
            , [a].[OriginalLoginName], [a].[EffectiveLoginName], [a].[IsSysadmin]
            , [a].[ActivePolicyCount], [a].[RelevantPolicyCount], [a].[IsAllowed]
            , [a].[AccessReason], [a].[MatchedGroupCount]
            , CASE WHEN [a].[IsAllowed] = 1 THEN 'AVAILABLE' ELSE 'DENIED_GROUP' END
        FROM [monitor].[VW_AnalyseAccessCurrent] AS [a]
        WHERE (@AnalyseKlasse IS NULL OR [a].[AnalysisClass] = @AnalyseKlasse)
          AND (@NurGesperrte = 0 OR [a].[IsAllowed] = 0);

        ;WITH [ActivePolicy] AS
        (
            SELECT
                  [p].[AnalysisClass], [p].[ADGroupName], [p].[Priority]
                , [p].[ValidFromUtc], [p].[ValidToUtc], [p].[Comment]
            FROM [monitor].[VW_AnalyseAccessPolicy] AS [p]
            WHERE [p].[IsEnabled] = 1
              AND ([p].[ValidFromUtc] IS NULL OR [p].[ValidFromUtc] <= SYSUTCDATETIME())
              AND ([p].[ValidToUtc] IS NULL OR [p].[ValidToUtc] > SYSUTCDATETIME())
              AND (@AnalyseKlasse IS NULL OR [p].[AnalysisClass] IN (@AnalyseKlasse, '*'))
        )
        INSERT [#CheckAnalyseAccess_Policies]
        (
              [AnalysisClass], [ADGroupName], [Priority], [ValidFromUtc]
            , [ValidToUtc], [MatchesLoginToken], [MatchesIsMember], [Comment]
        )
        SELECT
              [p].[AnalysisClass], [p].[ADGroupName], [p].[Priority]
            , [p].[ValidFromUtc], [p].[ValidToUtc]
            , CONVERT(bit, CASE WHEN EXISTS
              (
                  SELECT 1
                  FROM [sys].[login_token] AS [lt] WITH (NOLOCK)
                  WHERE [lt].[type] = N'WINDOWS GROUP'
                    AND UPPER(CONVERT(nvarchar(256), [lt].[name])) COLLATE Latin1_General_100_CI_AS
                      = UPPER([p].[ADGroupName]) COLLATE Latin1_General_100_CI_AS
              ) THEN 1 ELSE 0 END)
            , CONVERT(bit, CASE WHEN IS_MEMBER([p].[ADGroupName]) = 1 THEN 1 ELSE 0 END)
            , [p].[Comment]
        FROM [ActivePolicy] AS [p];

        IF EXISTS (SELECT 1 FROM [#CheckAnalyseAccess_Access] WHERE [IsAllowed] = 0)
        BEGIN
            INSERT [#CheckAnalyseAccess_Warnings] VALUES ('DENIED_GROUP', N'Mindestens eine Analyseklasse ist durch die aktuelle Gruppenpolicy gesperrt.');
            SET @StatusCode = 'AVAILABLE_LIMITED';
        END;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'ERROR_HANDLED';
        SET @ErrorNumber = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
        INSERT [#CheckAnalyseAccess_Warnings] VALUES (@StatusCode, @ErrorMessage);
    END CATCH;

    IF @PrintMeldungen = 1 AND @ErrorMessage IS NOT NULL
    BEGIN
        DECLARE @PrintMessage nvarchar(2048) = FORMATMESSAGE(N'%s: %s', @StatusCode, @ErrorMessage);
        RAISERROR(N'%s', 10, 1, @PrintMessage) WITH NOWAIT;
    END;

    IF @ResultSetArtNormalisiert <> 'NONE'
    BEGIN
        SELECT
              CAST('2.0' AS varchar(16)) AS [ContractVersion]
            , @CollectionTimeUtc AS [CollectionTimeUtc]
            , N'monitor.USP_CheckAnalyseAccess' AS [ModuleName]
            , @StatusCode AS [StatusCode]
            , CONVERT(bit, CASE WHEN @StatusCode = 'AVAILABLE' THEN 0 ELSE 1 END) AS [IsPartial]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @ResultSetArtNormalisiert = 'RAW'
        BEGIN
            SELECT * FROM [#CheckAnalyseAccess_Access] ORDER BY [RequiresGroupGate], [AnalysisLevel], [AnalysisClass];
            SELECT * FROM [#CheckAnalyseAccess_Policies] ORDER BY [Priority], [AnalysisClass], [ADGroupName];
            SELECT * FROM [#CheckAnalyseAccess_Warnings] ORDER BY [WarningCode], [WarningMessage];
        END;
        ELSE
        BEGIN
            SELECT
                  N'Analysezugriff' AS [Ergebnis]
                , [AnalysisClass] AS [Analyseklasse]
                , [AnalysisLevel] AS [Stufe]
                , [IsAllowed] AS [erlaubt]
                , [AccessReason] AS [Begründung]
                , [MatchedGroupCount] AS [passende Gruppen]
                , [StatusCode] AS [Status]
            FROM [#CheckAnalyseAccess_Access]
            ORDER BY [RequiresGroupGate], [AnalysisLevel], [AnalysisClass];

            SELECT
                  N'Aktive Zugriffspolicy' AS [Ergebnis]
                , [AnalysisClass] AS [Analyseklasse]
                , [ADGroupName] AS [AD-Gruppe]
                , [Priority] AS [Priorität]
                , [MatchesLoginToken] AS [im Login-Token]
                , [MatchesIsMember] AS [IS_MEMBER]
                , [Comment] AS [Kommentar]
            FROM [#CheckAnalyseAccess_Policies]
            ORDER BY [Priority], [AnalysisClass], [ADGroupName];

            SELECT N'Warnung' AS [Ergebnis], [WarningCode] AS [Code], [WarningMessage] AS [Meldung]
            FROM [#CheckAnalyseAccess_Warnings]
            ORDER BY [WarningCode], [WarningMessage];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT
                  N'CheckAnalyseAccess' AS [resultName]
                , 1 AS [schemaVersion]
                , @CollectionTimeUtc AS [generatedAtUtc]
                , @StatusCode AS [statusCode]
                , @ErrorNumber AS [errorNumber]
                , @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @AccessJson nvarchar(max) = (SELECT * FROM [#CheckAnalyseAccess_Access] ORDER BY [RequiresGroupGate], [AnalysisLevel], [AnalysisClass] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @PoliciesJson nvarchar(max) = (SELECT * FROM [#CheckAnalyseAccess_Policies] ORDER BY [Priority], [AnalysisClass], [ADGroupName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max) = (SELECT * FROM [#CheckAnalyseAccess_Warnings] ORDER BY [WarningCode], [WarningMessage] FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson, N'{}'), N',"access":', COALESCE(@AccessJson, N'[]'), N',"policies":', COALESCE(@PoliciesJson, N'[]'), N',"warnings":', COALESCE(@WarningsJson, N'[]'), N'}');
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#CheckAnalyseAccess_Access'
            , @ResultLabel=N'CheckAnalyseAccess'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#CheckAnalyseAccess_Access'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO

