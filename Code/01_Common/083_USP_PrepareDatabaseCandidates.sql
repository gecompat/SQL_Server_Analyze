USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PrepareDatabaseCandidates
Version      : 2.0.2
Stand        : 2026-10-14
Typ          : Öffentlicher Vorbereitungshelfer
Zweck        : Validiert die frameworkweite Datenbankauswahl, prüft den
               tatsächlich aktivierten Analysepfad und befüllt lokale
               Kandidaten- und Warning-Temp-Tabellen des Aufrufers.
Semantik     : Ohne explizite Einschränkung alle sichtbaren, online befindlichen
               Benutzerdatenbanken. Kein CURRENT-Scope und keine Vorabbegrenzung.
High Impact  : Nur eine tatsächlich aktivierte Analyseklasse mit
               RequiresGroupGate=1 verlangt @HighImpactConfirmed=1.
Vertrag      : Die Procedure kennt keine Datenbank-Mengenbegrenzung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_PrepareDatabaseCandidates]
      @DatabaseNames                    nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @AnalysisClass                    varchar(64)    = NULL
    , @HighImpactConfirmed              bit            = 0
    , @StatusCode                       varchar(40)    OUTPUT
    , @ErrorMessage                     nvarchar(2048) OUTPUT
    , @CrossDatabaseRequested           bit            OUTPUT
    , @CandidateTable                   sysname        = N'#PrepareDatabaseCandidates_Result'
    , @WarningTable                     sysname        = NULL
    , @Hilfe                            bit            = 0
AS
BEGIN
    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_PrepareDatabaseCandidates befüllt lokale Kandidaten- und optionale Warnungstabellen des Aufrufers. Sie liefert keine Analyse-Resultsets und ergänzt vorhandene Zeilen.';
        PRINT N'@DatabaseNames nvarchar(max)=NULL: bracket-aware Pipe-Liste einteiliger Namen. NULL, leer oder Leerzeichen bedeutet keine Einschränkung; zusammen mit @DatabaseNamePattern ungültig. Doppelte gültige Namen sind ungültig.';
        PRINT N'@SystemdatenbankenEinbeziehen bit=0: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. Ein numerischer Wert ungleich 0 wird bei der bit-Konvertierung zu 1; NULL ist INVALID_PARAMETER.';
        PRINT N'@DatabaseNamePattern nvarchar(4000)=NULL: SQL LIKE mit %, _ und Zeichenklassen in eckigen Klammern oder regex:/regexi:. LIKE ist case-sensitive unter SQL_Latin1_General_CP1_CS_AS. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Präfixe werden case-insensitive erkannt; nur äußere Eingabeleerzeichen werden entfernt. Patterninhalt bleibt sonst erhalten. Leeres Pattern ist ungültig; Liste und Pattern sind exklusiv.';
        PRINT N'@AnalysisClass varchar(64)=NULL: NULL oder leer überspringt die Pfadprüfung. Eine unbekannte Klasse liefert INVALID_PARAMETER; ein nicht verfügbarer Pfad beendet die Vorbereitung mit dem delegierten Status.';
        PRINT N'@HighImpactConfirmed bit=0: 1 bestätigt nur dann ein High-Impact-Gate, wenn die angegebene, tatsächlich aktivierte Klasse es verlangt. Numerische Werte ungleich 0 werden bei der bit-Konvertierung zu 1; NULL ist INVALID_PARAMETER, auch ohne Analyseklasse.';
        PRINT N'@StatusCode varchar(40) OUTPUT und @ErrorMessage nvarchar(2048) OUTPUT: beide erforderlich. @ErrorMessage ist bei erfolgreicher Vorbereitung NULL. Eigene Statuswerte: AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR, UNAVAILABLE_FEATURE. Delegiert können INVALID_PARAMETER, HIGH_IMPACT_CONFIRMATION_REQUIRED oder DENIED_GROUP zurückkommen. AVAILABLE belegt nicht die Auswahl jedes angeforderten Namens.';
        PRINT N'@CrossDatabaseRequested bit OUTPUT: erforderlich. 1 bei fehlender exakter Liste oder mehr als einem gültigen Listenelement, sonst 0. Der Wert beschreibt die Anfrage, nicht die Verfügbarkeit aller Namen.';
        PRINT N'@CandidateTable sysname=N''#PrepareDatabaseCandidates_Result'': vorhandene lokale Tabelle mit DatabaseId int, DatabaseName sysname, StateDesc nvarchar(60), UserAccessDesc nvarchar(60), IsReadOnly bit, CompatibilityLevel tinyint, CollationName sysname, RecoveryModelDesc nvarchar(60), IsSystemDatabase bit, RequestedOrdinal int. Es werden nur zwei Spalten per TOP (0) geprüft; Fehler späterer Inserts können entkommen. Name höchstens 116 Zeichen; kein globales ##.';
        PRINT N'@WarningTable sysname=NULL: optionale vorhandene lokale Tabelle mit RequestedName sysname, StatusCode varchar(40), ErrorMessage nvarchar(2048). Fehlende explizite Namen erhalten DATABASE_UNAVAILABLE oder SYSTEM_DATABASE_EXCLUDED, wenn die Tabelle passt. Scheitert der TOP (0)-Probe, gilt die Warnungstabelle still als nicht verfügbar. Ein späterer Warnungsinsert kann weiterhin einen Fehler auslösen. Erfolgreiche Warnungen werden angehängt. Der Name darf höchstens 116 Zeichen haben; globale ##-Namen sind unzulässig. Bereits vorhandene Kandidatenzeilen beeinflussen die Ermittlung fehlender Namen.';
        PRINT N'Beide Tabellen müssen vom Aufrufer angelegt werden. Die Procedure löscht sie im regulären Pfad nicht; wiederverwendete Ziele behalten alte Zeilen. Es gibt keine allgemeine atomare Rücknahme bei späteren Fehlern. Der Regexfilter verarbeitet alle Zeilen der Kandidatentabelle, einschließlich bereits vorhandener Zeilen. Fehlt SQL-Server-Version oder Compatibility Level für Regex, löscht die Procedure vor UNAVAILABLE_FEATURE sämtliche Zeilen aus diesem Ziel.';
        PRINT N'@Hilfe bit=0: 0 verarbeitet; 1 druckt diese Hilfe und kehrt vor Initialisierung der OUTPUT-Werte zurück; NULL folgt dem normalen Pfad. Bei Hilfe müssen alle OUTPUT-Parameter gebunden sein, ihre Werte bleiben unverändert.';
        PRINT N'Beispiel: ausführbarer Aufruf mit frischen, korrekt typisierten lokalen Tabellen und synthetischem Datenbanknamen:';
        PRINT N'CREATE TABLE #PrepareDatabaseCandidates_HelpExample (DatabaseId int NOT NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, StateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, UserAccessDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsReadOnly bit NULL, CompatibilityLevel tinyint NULL, CollationName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, RecoveryModelDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsSystemDatabase bit NULL, RequestedOrdinal int NULL);';
        PRINT N'CREATE TABLE #PrepareDatabaseCandidates_WarningExample (RequestedName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);';
        PRINT N'DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048), @CrossDatabaseRequested bit;';
        PRINT N'EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=N''[ExampleDatabase]'', @CandidateTable=N''#PrepareDatabaseCandidates_HelpExample'', @WarningTable=N''#PrepareDatabaseCandidates_WarningExample'', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT;';
        PRINT N'SELECT @StatusCode AS StatusCode, @ErrorMessage AS ErrorMessage, @CrossDatabaseRequested AS CrossDatabaseRequested;';
        PRINT N'SELECT * FROM #PrepareDatabaseCandidates_HelpExample ORDER BY RequestedOrdinal, DatabaseName;';
        PRINT N'SELECT * FROM #PrepareDatabaseCandidates_WarningExample ORDER BY RequestedName;';
        PRINT N'DROP TABLE #PrepareDatabaseCandidates_WarningExample; DROP TABLE #PrepareDatabaseCandidates_HelpExample;';
        PRINT N'Parsergrenzen: PARSENAME-basierte Strukturprüfungen sind keine vollständige SQL-Bezeichnergrammatik und prüfen weder Existenz noch Berechtigungen.';
        RETURN;
    END;

    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SELECT
          @StatusCode = 'AVAILABLE'
        , @ErrorMessage = NULL
        , @CrossDatabaseRequested = 0;

    DECLARE @EffectiveDatabaseNames nvarchar(max) =
        CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames, N''))), N'') IS NULL
             THEN NULL ELSE @DatabaseNames END;
    DECLARE @PatternMode varchar(8);
    DECLARE @PatternValue nvarchar(4000);
    DECLARE @RegexFlags varchar(8);
    DECLARE @PatternIsValid bit;
    DECLARE @DatabaseListCount int = 0;
    DECLARE @Sql nvarchar(max);
    DECLARE @CandidateTableQuoted nvarchar(258);
    DECLARE @WarningTableQuoted nvarchar(258);

    IF @SystemdatenbankenEinbeziehen IS NULL
       OR @SystemdatenbankenEinbeziehen NOT IN (0,1)
       OR @HighImpactConfirmed IS NULL
       OR @HighImpactConfirmed NOT IN (0,1)
       OR @CandidateTable IS NULL
       OR LEFT(@CandidateTable,1) <> N'#'
       OR LEFT(@CandidateTable,2) = N'##'
       OR LEN(@CandidateTable) > 116
       OR
       (
           @WarningTable IS NOT NULL
           AND
           (
               LEFT(@WarningTable,1) <> N'#'
               OR LEFT(@WarningTable,2) = N'##'
               OR LEN(@WarningTable) > 116
           )
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültige Auswahl-, Bestätigungs- oder interne Temp-Tabellenparameter.';
        RETURN;
    END;

    SELECT
          @CandidateTableQuoted = QUOTENAME(@CandidateTable)
        , @WarningTableQuoted = QUOTENAME(@WarningTable);

    -- Ausschließlich eigene Temp-Anlagen dürfen je Statement bis zu 100 ms
    -- auf eine Sperre warten. Fachliche Zugriffe bleiben anschließend NOWAIT.
    BEGIN TRY
    SET LOCK_TIMEOUT 100;
    CREATE TABLE [#PrepareDatabaseCandidates_Work]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
    );

    CREATE TABLE [#PrepareDatabaseCandidates_RequestedNames]
    (
          [NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsValid] bit NOT NULL
    );
    SET LOCK_TIMEOUT 0;
    END TRY
    BEGIN CATCH
        SET LOCK_TIMEOUT 0;
        THROW;
    END CATCH;

    IF @EffectiveDatabaseNames IS NOT NULL
        INSERT [#PrepareDatabaseCandidates_RequestedNames]([NameValue],[IsValid])
        SELECT [NameValue],[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@EffectiveDatabaseNames);

    BEGIN TRY
        SET @Sql = N'DECLARE @DatabaseId int,@DatabaseName sysname;
SELECT TOP (0) @DatabaseId=[DatabaseId],@DatabaseName=[DatabaseName]
FROM ' + @CandidateTableQuoted + N';';
        EXEC [sys].[sp_executesql] @Sql;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INTERNAL_ERROR';
        SET @ErrorMessage = N'Die Kandidaten-Temp-Tabelle wurde nicht mit dem erwarteten Schema angelegt.';
        RETURN;
    END CATCH;

    SELECT
          @PatternMode = [PatternMode]
        , @PatternValue = [PatternValue]
        , @RegexFlags = [RegexFlags]
        , @PatternIsValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);

    IF @EffectiveDatabaseNames IS NOT NULL
        SELECT @DatabaseListCount = COUNT(*)
        FROM [#PrepareDatabaseCandidates_RequestedNames]
        WHERE [IsValid] = 1;

    SET @CrossDatabaseRequested = CONVERT
    (
        bit,
        CASE WHEN @EffectiveDatabaseNames IS NULL OR @DatabaseListCount > 1
             THEN 1 ELSE 0 END
    );

    IF @PatternIsValid = 0
       OR
       (
           @EffectiveDatabaseNames IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM [#PrepareDatabaseCandidates_RequestedNames]
               WHERE [IsValid] = 0
           )
       )
       OR (@EffectiveDatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL)
       OR
       (
           @EffectiveDatabaseNames IS NOT NULL
           AND EXISTS
           (
               SELECT [NameValue]
               FROM [#PrepareDatabaseCandidates_RequestedNames]
               WHERE [IsValid] = 1
               GROUP BY [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
               HAVING COUNT(*) > 1
           )
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültige oder doppelte Datenbankliste beziehungsweise ungültiges Pattern. Exakte Liste und Pattern sind gegenseitig exklusiv.';
        RETURN;
    END;

    IF NULLIF(@AnalysisClass, '') IS NOT NULL
    BEGIN
        EXEC [monitor].[InternalCheckAnalysisPath]
              @AnalysisClass=@AnalysisClass
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT;

        IF @StatusCode<>'AVAILABLE'
            RETURN;
    END;

    INSERT [#PrepareDatabaseCandidates_Work]
    (
          [DatabaseId],[DatabaseName],[StateDesc],[UserAccessDesc],[IsReadOnly]
        , [CompatibilityLevel],[CollationName],[RecoveryModelDesc]
        , [IsSystemDatabase],[RequestedOrdinal]
    )
    SELECT
          [DatabaseId],[DatabaseName],[StateDesc],[UserAccessDesc],[IsReadOnly]
        , [CompatibilityLevel],[CollationName],[RecoveryModelDesc]
        , [IsSystemDatabase],[RequestedOrdinal]
    FROM [monitor].[TVF_DatabaseCandidates]
    (
          @EffectiveDatabaseNames
        , @SystemdatenbankenEinbeziehen
        , @DatabaseNamePattern
    );

    SET @Sql = N'INSERT ' + @CandidateTableQuoted + N'
(
      [DatabaseId],[DatabaseName],[StateDesc],[UserAccessDesc],[IsReadOnly]
    , [CompatibilityLevel],[CollationName],[RecoveryModelDesc]
    , [IsSystemDatabase],[RequestedOrdinal]
)
SELECT
      [DatabaseId],[DatabaseName],[StateDesc],[UserAccessDesc],[IsReadOnly]
    , [CompatibilityLevel],[CollationName],[RecoveryModelDesc]
    , [IsSystemDatabase],[RequestedOrdinal]
FROM [#PrepareDatabaseCandidates_Work];';
    EXEC [sys].[sp_executesql] @Sql;

    DECLARE @WarningTableAvailable bit = 0;
    IF @WarningTable IS NOT NULL
    BEGIN
        BEGIN TRY
            SET @Sql = N'DECLARE @RequestedName sysname,@WarningStatus varchar(40),@WarningError nvarchar(2048);
SELECT TOP (0) @RequestedName=[RequestedName],@WarningStatus=[StatusCode],@WarningError=[ErrorMessage]
FROM ' + @WarningTableQuoted + N';';
            EXEC [sys].[sp_executesql] @Sql;
            SET @WarningTableAvailable = 1;
        END TRY
        BEGIN CATCH
            SET @WarningTableAvailable = 0;
        END CATCH;
    END;

    IF @WarningTableAvailable = 1 AND @EffectiveDatabaseNames IS NOT NULL
    BEGIN
        SET @Sql = N'INSERT ' + @WarningTableQuoted + N' ([RequestedName],[StatusCode],[ErrorMessage])
SELECT
      [n].[NameValue]
    , CASE
          WHEN @IncludeSystem = 0
           AND [n].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
               IN (N''master'',N''tempdb'',N''model'',N''msdb'')
              THEN ''SYSTEM_DATABASE_EXCLUDED''
          ELSE ''DATABASE_UNAVAILABLE''
      END
    , CASE
          WHEN @IncludeSystem = 0
           AND [n].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
               IN (N''master'',N''tempdb'',N''model'',N''msdb'')
              THEN N''Die explizit angeforderte Systemdatenbank ist ohne Opt-in ausgeschlossen.''
          ELSE N''Die explizit angeforderte Datenbank ist nicht vorhanden, nicht online oder für den aktuellen Login nicht zugreifbar.''
      END
FROM [#PrepareDatabaseCandidates_RequestedNames] AS [n]
WHERE [n].[IsValid] = 1
  AND NOT EXISTS
      (
          SELECT 1
          FROM ' + @CandidateTableQuoted + N' AS [c]
          WHERE [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
              = [n].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
      );';

        EXEC [sys].[sp_executesql]
              @Sql
            , N'@IncludeSystem bit'
            , @IncludeSystem = @SystemdatenbankenEinbeziehen;
    END;

    IF @PatternMode IN ('REGEX', 'REGEXI')
    BEGIN
        IF TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) < 17
           OR NOT EXISTS
              (
                  SELECT 1
                  FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
                  WHERE [d].[database_id] = DB_ID()
                    AND [d].[compatibility_level] >= 170
              )
        BEGIN
            SET @Sql = N'DELETE FROM ' + @CandidateTableQuoted + N';';
            EXEC [sys].[sp_executesql] @Sql;
            SET @StatusCode = 'UNAVAILABLE_FEATURE';
            SET @ErrorMessage = N'Regex benötigt SQL Server 2025 und Compatibility Level 170 für die Installationsdatenbank.';
            RETURN;
        END;

        SET @Sql = N'DELETE [c]
FROM ' + @CandidateTableQuoted + N' AS [c]
WHERE NOT REGEXP_LIKE([c].[DatabaseName], @Pattern, @Flags);';

        EXEC [sys].[sp_executesql]
              @Sql
            , N'@Pattern nvarchar(4000), @Flags varchar(8)'
            , @Pattern = @PatternValue
            , @Flags = @RegexFlags;
    END;
END;
GO
