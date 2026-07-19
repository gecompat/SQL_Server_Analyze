USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PrepareDatabaseCandidates
Version      : 1.1.0
Stand        : 2026-07-15
Typ          : Stored Procedure, gemeinsamer interner Auswahlvertrag
Zweck        : Validiert Datenbanklisten und Patterns und befüllt eine vom
               Aufrufer benannte lokale Temp-Tabelle.
Voraussetzung: @CandidateTable besitzt die Spalten DatabaseId,
               DatabaseName, StateDesc, UserAccessDesc, IsReadOnly,
               CompatibilityLevel, CollationName, RecoveryModelDesc,
               IsSystemDatabase und RequestedOrdinal.
Semantik     : @DatabaseNames bracket-aware Pipe-Liste; NULL = alle;
               N'' beziehungsweise nur Leerzeichen = aktuelle Datenbank. Explizite Listen werden nicht durch
               @MaxDatenbanken gekürzt. Pattern: LIKE/regex/regexi.
Regex        : SQL Server 2025 und Compatibility Level 170 für DeineDatenbank;
               Ausführung ausschließlich dynamisch für 2019/2022-Kompilierung.
Resultsets   : keine. Optional befüllt die Procedure die vom Aufrufer angelegte
               @WarningTable(RequestedName,StatusCode,ErrorMessage).
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_PrepareDatabaseCandidates]
      @DatabaseNames                    nvarchar(max)  = N''
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @MaxDatenbanken                   int            = 16
    , @AnalysisClass                    varchar(64)    = 'CROSS_DATABASE_DEEP'
    , @StatusCode                       varchar(40)    OUTPUT
    , @ErrorMessage                     nvarchar(2048) OUTPUT
    , @CrossDatabaseRequested           bit            OUTPUT
    , @CandidateTable                   sysname        = N'#PrepareDatabaseCandidates_Result'
    , @WarningTable                     sysname        = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;

    SET @StatusCode = 'AVAILABLE';
    SET @ErrorMessage = NULL;
    SET @CrossDatabaseRequested = 0;

    DECLARE @EffectiveDatabaseNames nvarchar(max) = @DatabaseNames;
    -- NULL ist der explizite Cross-Database-Modus. Nur ein nicht-NULLer,
    -- leerer Wert bedeutet die aktuelle Datenbank als sicheren Standard.
    IF @EffectiveDatabaseNames IS NOT NULL
       AND NULLIF(LTRIM(RTRIM(@EffectiveDatabaseNames)), N'') IS NULL
    BEGIN
        IF @DatabaseNamePattern IS NOT NULL
            SET @EffectiveDatabaseNames = NULL;
        ELSE
            SET @EffectiveDatabaseNames = QUOTENAME((SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()));
    END;

    DECLARE @PatternMode varchar(8);
    DECLARE @PatternValue nvarchar(4000);
    DECLARE @RegexFlags varchar(8);
    DECLARE @PatternIsValid bit;
    DECLARE @DatabaseListCount int = 0;
    DECLARE @Allowed bit = 1;
    DECLARE @Sql nvarchar(max);
    DECLARE @CandidateTableQuoted nvarchar(258);
    DECLARE @WarningTableQuoted nvarchar(258);

    IF @CandidateTable IS NULL
       OR LEFT(@CandidateTable,1)<>N'#'
       OR LEFT(@CandidateTable,2)=N'##'
       OR LEN(@CandidateTable)>116
       OR (@WarningTable IS NOT NULL AND
          (LEFT(@WarningTable,1)<>N'#' OR LEFT(@WarningTable,2)=N'##' OR LEN(@WarningTable)>116))
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@CandidateTable und @WarningTable müssen gültige lokale #Temp-Tabellennamen enthalten.';
        RETURN;
    END;

    SELECT
          @CandidateTableQuoted = QUOTENAME(@CandidateTable)
        , @WarningTableQuoted = QUOTENAME(@WarningTable);

    BEGIN TRY
        SET @Sql = N'SELECT TOP (0) [DatabaseId],[DatabaseName] FROM ' + @CandidateTableQuoted + N';';
        EXEC [sys].[sp_executesql] @Sql;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INTERNAL_ERROR';
        SET @ErrorMessage = N'Die über @CandidateTable benannte Temp-Tabelle wurde vom Aufrufer nicht angelegt.';
        RETURN;
    END CATCH;

    SELECT
          @PatternMode = [PatternMode]
        , @PatternValue = [PatternValue]
        , @RegexFlags = [RegexFlags]
        , @PatternIsValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);

    IF @EffectiveDatabaseNames IS NOT NULL
    BEGIN
        SELECT @DatabaseListCount = COUNT(*)
        FROM [monitor].[TVF_ParseSqlNameList](@EffectiveDatabaseNames)
        WHERE [IsValid] = 1;
    END;

    SET @CrossDatabaseRequested = CONVERT
    (
        bit,
        CASE WHEN @EffectiveDatabaseNames IS NULL OR @DatabaseListCount > 1
             THEN 1 ELSE 0 END
    );

    IF @MaxDatenbanken < 0
       OR @PatternIsValid = 0
       OR (@EffectiveDatabaseNames IS NOT NULL AND EXISTS
          (
              SELECT 1
              FROM [monitor].[TVF_ParseSqlNameList](@EffectiveDatabaseNames)
              WHERE [IsValid] = 0
          ))
       OR (@EffectiveDatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL)
       OR (@EffectiveDatabaseNames IS NOT NULL AND EXISTS
          (
              SELECT [NameValue]
              FROM [monitor].[TVF_ParseSqlNameList](@EffectiveDatabaseNames)
              WHERE [IsValid] = 1
              GROUP BY [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
              HAVING COUNT(*) > 1
          ))
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültige oder doppelte Datenbankliste beziehungsweise ungültiges Pattern. Exakte Liste und Pattern sind gegenseitig exklusiv.';
        RETURN;
    END;

    IF @CrossDatabaseRequested = 1
       AND NULLIF(@AnalysisClass, '') IS NOT NULL
    BEGIN
        SELECT @Allowed = COALESCE(MAX(CONVERT(tinyint, [IsAllowed])), 0)
        FROM [monitor].[VW_AnalyseAccessCurrent]
        WHERE [AnalysisClass] = @AnalysisClass;

        IF @Allowed = 0
        BEGIN
            SET @StatusCode = 'DENIED_GROUP';
            SET @ErrorMessage = CONCAT(@AnalysisClass, N' ist nicht freigegeben.');
            RETURN;
        END;
    END;

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
FROM [monitor].[TVF_DatabaseCandidates]
(
      @pDatabaseNames,@pSystemDatabases,@pDatabasePattern,@pMaxDatabases
);';

    EXEC [sys].[sp_executesql]
          @Sql
        , N'@pDatabaseNames nvarchar(max),@pSystemDatabases bit,@pDatabasePattern nvarchar(4000),@pMaxDatabases int'
        , @pDatabaseNames=@EffectiveDatabaseNames
        , @pSystemDatabases=@SystemdatenbankenEinbeziehen
        , @pDatabasePattern=@DatabaseNamePattern
        , @pMaxDatabases=@MaxDatenbanken;

    DECLARE @WarningTableAvailable bit = 0;
    IF @WarningTable IS NOT NULL
    BEGIN
        BEGIN TRY
            SET @Sql = N'SELECT TOP (0) [RequestedName],[StatusCode],[ErrorMessage] FROM ' + @WarningTableQuoted + N';';
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
SELECT [n].[NameValue],''DATABASE_UNAVAILABLE'',
       N''Die explizit angeforderte Datenbank ist nicht vorhanden, nicht online oder für den aktuellen Login nicht zugreifbar.''
FROM [monitor].[TVF_ParseSqlNameList](@pDatabaseNames) AS [n]
WHERE [n].[IsValid]=1
  AND NOT EXISTS
      (
          SELECT 1 FROM ' + @CandidateTableQuoted + N' AS [c]
          WHERE [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
              = [n].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
      );';

        EXEC [sys].[sp_executesql]
              @Sql
            , N'@pDatabaseNames nvarchar(max)'
            , @pDatabaseNames=@EffectiveDatabaseNames;
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
