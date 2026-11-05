USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalPrepareResultTables
Version      : 1.0.0
Stand        : 2026-07-20
Typ          : Interne Stored Procedure
Zweck        : Prüft ein JSON-Objekt mit TABLE-Zuordnungen gegen die vom
               Aufrufer übergebene Namensliste, validiert vorhandene lokale
               Ergebnistabellen und hängt Zuordnungen an die Mapping-Tabelle
               des Aufrufers an.
Parameter:
@ResultTablesJson nvarchar(max), Default: kein Default (Pflichtparameter). Erwartet ein JSON-Objekt, keine Liste; NULL, leerer Text, {} und Objekte ohne Zuordnung sind ungültig. Jedes Schlüssel-Wert-Paar muss Zeichenketten enthalten. Schlüssel und Zielwerte werden vor den Guards nach sysname konvertiert. Schlüssel werden nach der Konvertierung binär exakt mit @AllowedResultNames verglichen; es gibt keine Vorab-Trim-Regel. Doppelte Schlüssel werden binär erkannt. Werte müssen unqualifizierte, rohe lokale #Temp-Namen sein: kein ## und kein #Monitor-Präfix (CI), LEN höchstens 116 nach sysname-Konvertierung. Werte werden nicht getrimmt; doppelte Ziele werden CI erkannt. Klammer- oder Schemanamen sind nicht zulässig.
@AllowedResultNames nvarchar(max), Default: kein Default (Pflichtparameter). Vom Aufrufer gelieferte Pipe-Liste; NULL, leer oder nur leere Einträge ergibt keine zulässigen Namen. | hat keine Escape-Syntax. Nur U+0020 an den Rändern jedes Tokens wird entfernt; leere Tokens werden ignoriert. Tokens werden nach sysname konvertiert und binär verglichen. Doppelte Tokens nach Konvertierung können im nicht abgefangenen INSERT einen nativen Fehler auslösen. Die Wertemenge bleibt der offene Aufrufervertrag.
@MappingTable sysname, Default: kein Default (Pflichtparameter). NULL oder leer ist ungültig; kein Trimmen. Name einer vom Aufrufer erstellten lokalen #Temp-Tabelle, kein ##, höchstens 116 Zeichen nach sysname-Konvertierung. Erwartet werden ResultName und TargetTable als sysname. TOP (0) mit Variablen beweist die Auflösung/Konvertierung dieser Spalten, nicht das exakte physische Tabellenschema. Zuordnungen werden angehängt; bestehende Zeilen werden nicht gelöscht.
@StatusCode varchar(40), Default: NULL OUTPUT. OUTPUT-Bindung vom Typ varchar(40); nach eigener Temp-DDL auf AVAILABLE initialisiert; eingehende NULL-, Leertext- oder andere Werte werden dabei überschrieben. AVAILABLE bedeutet Preflight erfolgreich; INVALID_PARAMETER bedeutet ungültiger @ThrowOnError oder @MappingTable; INVALID_RESULT_TABLE_MAPPING bedeutet ungültige JSON-Form oder unzulässige, doppelte bzw. nicht erlaubte Zuordnung; INVALID_RESULT_TABLE_TARGET bedeutet Ziel fehlt, ist nicht leer, besteht nicht aus genau einer Seed-Spalte oder kann nicht sicher geprüft werden; INTERNAL_ERROR bedeutet, dass Mapping-Spalten nicht wie erwartet auflösbar/konvertierbar sind. Bei Auslassen gilt Default NULL; Aufrufer bindet eine Variable mit OUTPUT. NULL/leer als Eingabeform ist für einen Status-OUTPUT nicht anwendbar.
@ErrorMessage nvarchar(2048), Default: NULL OUTPUT. OUTPUT-Bindung vom Typ nvarchar(2048); nach eigener Temp-DDL auf NULL initialisiert, bei erkanntem Fehler mit Meldung befüllt; eingehende NULL-, Leertext- oder andere Werte werden dabei überschrieben. Bei Auslassen gilt Default NULL; zum Empfang ist eine Aufrufervariable mit OUTPUT nötig. NULL/leer als Eingabeform ist für einen Status-OUTPUT nicht anwendbar.
@ThrowOnError bit, Default: 0. Kann ausgelassen werden. 0 unterdrückt nur behandelte Preflightfehler und gibt Status/Meldung zurück; 1 wirft für behandelte Fehler 51011. NULL ist ungültig, ergibt INVALID_PARAMETER und löst wegen der NULL-Prüfung auf 1 keinen Fehler 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe.
Fehler- und Seiteneffektgrenzen: Eigene Prüftabellen-DDL liegt vor der Initialisierung von @StatusCode und @ErrorMessage; DDL-Fehler werden nach Wiederherstellung des vorherigen Lock-Timeouts erneut ausgelöst. Die Allowed-Liste wird außerhalb TRY/CATCH eingefügt, ebenso das finale Mapping-INSERT; native Fehler dort können entweichen. Ziele werden mit temporärer Marker-Spalte geprüft; ADD/DROP sind reale temporäre Schemaänderungen, Bereinigung im Fehlerpfad ist best effort. Es gibt keine atomare Rücknahmezusage. Es erfolgt keine Erstellung oder dauerhafte Anpassung der Ergebnisspaltenstruktur. Eingehender LOCK_TIMEOUT 0 erhält pro eigener Temp-DDL-Anlage 1000 ms; andere Werte bleiben während dieser Anlage bestehen. Nach erfolgreicher Anlage wird LOCK_TIMEOUT 0 gesetzt; Zieloperationen verwenden NOWAIT.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[InternalPrepareResultTables]
      @ResultTablesJson    nvarchar(max)
    , @AllowedResultNames  nvarchar(max)
    , @MappingTable        sysname
    , @StatusCode          varchar(40)    = NULL OUTPUT
    , @ErrorMessage        nvarchar(2048) = NULL OUTPUT
    , @ThrowOnError        bit            = 0
AS
BEGIN
    SET NOCOUNT ON;

    -- Eigene Temp-DDL erhält bei geerbtem NOWAIT ein Zeitbudget von
    -- 1000 ms je Anlage. Fremde Zieltabellen bleiben anschließend NOWAIT.
    DECLARE @OwnDdlOriginalLockTimeout int=@@LOCK_TIMEOUT;
    BEGIN TRY
        IF @OwnDdlOriginalLockTimeout=0 SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#InternalPrepareResultTables_Allowed]
        (
              [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [ResultNameBinary] varbinary(256) NOT NULL PRIMARY KEY
        );

        CREATE TABLE [#InternalPrepareResultTables_Parsed]
        (
              [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            , [JsonType] int NOT NULL
        );
    END TRY
    BEGIN CATCH
        DECLARE @OwnDdlRestoreSql nvarchar(64)=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OwnDdlOriginalLockTimeout)+N';';
        EXEC [sys].[sp_executesql] @OwnDdlRestoreSql;
        THROW;
    END CATCH;

    SET LOCK_TIMEOUT 0;

    SELECT
          @StatusCode = 'AVAILABLE'
        , @ErrorMessage = NULL;

    IF @ThrowOnError IS NULL OR @ThrowOnError NOT IN (0,1)
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@ThrowOnError muss 0 oder 1 enthalten.';
        GOTO PreflightFailed;
    END;

    IF @MappingTable IS NULL
       OR LEFT(@MappingTable,1) <> N'#'
       OR LEFT(@MappingTable,2) = N'##'
       OR LEN(@MappingTable) > 116
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'@MappingTable muss eine gültige lokale #Temp-Tabelle bezeichnen.';
        GOTO PreflightFailed;
    END;

    IF @ResultTablesJson IS NULL
       OR ISJSON(@ResultTablesJson) <> 1
       OR LEFT(LTRIM(@ResultTablesJson),1) <> N'{'
       OR RIGHT(RTRIM(@ResultTablesJson),1) <> N'}'
    BEGIN
        SET @StatusCode = 'INVALID_RESULT_TABLE_MAPPING';
        SET @ErrorMessage = N'@ResultTablesJson muss ein gültiges JSON-Objekt enthalten.';
        GOTO PreflightFailed;
    END;

    INSERT [#InternalPrepareResultTables_Allowed]([ResultName],[ResultNameBinary])
    SELECT
          CONVERT(sysname, LTRIM(RTRIM([value])))
        , CONVERT(varbinary(256), CONVERT(sysname, LTRIM(RTRIM([value]))))
    FROM STRING_SPLIT(COALESCE(@AllowedResultNames,N''),N'|')
    WHERE NULLIF(LTRIM(RTRIM([value])),N'') IS NOT NULL;

    BEGIN TRY
        INSERT [#InternalPrepareResultTables_Parsed]([ResultName],[TargetTable],[JsonType])
        SELECT
              CONVERT(sysname,[key])
            , CONVERT(sysname,[value])
            , [type]
        FROM OPENJSON(@ResultTablesJson);
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INVALID_RESULT_TABLE_MAPPING';
        SET @ErrorMessage = N'@ResultTablesJson enthält einen nicht unterstützten Namen oder Zielwert.';
        GOTO PreflightFailed;
    END CATCH;

    IF NOT EXISTS (SELECT 1 FROM [#InternalPrepareResultTables_Parsed])
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed]
              WHERE [JsonType] <> 1
                 OR NULLIF(LTRIM(RTRIM([ResultName])),N'') IS NULL
                 OR NULLIF(LTRIM(RTRIM([TargetTable])),N'') IS NULL
          )
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed]
              GROUP BY CONVERT(varbinary(256),[ResultName])
              HAVING COUNT(*) > 1
          )
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed]
              GROUP BY [TargetTable] COLLATE Latin1_General_100_CI_AS
              HAVING COUNT(*) > 1
          )
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed] AS [p]
              WHERE NOT EXISTS
                    (
                        SELECT 1
                        FROM [#InternalPrepareResultTables_Allowed] AS [a]
                        WHERE [a].[ResultNameBinary] = CONVERT(varbinary(256),[p].[ResultName])
                    )
          )
       OR EXISTS
          (
              SELECT 1
              FROM [#InternalPrepareResultTables_Parsed]
              WHERE LEFT([TargetTable],1) <> N'#'
                 OR LEFT([TargetTable],2) = N'##'
                 OR LEN([TargetTable]) > 116
                 OR [TargetTable] LIKE N'#Monitor%' COLLATE Latin1_General_100_CI_AS
          )
    BEGIN
        SET @StatusCode = 'INVALID_RESULT_TABLE_MAPPING';
        SET @ErrorMessage = N'Die TABLE-Zuordnung enthält unbekannte oder doppelte Resultsetnamen, doppelte Ziele oder unzulässige Temp-Tabellennamen.';
        GOTO PreflightFailed;
    END;

    DECLARE @MappingTableQuoted nvarchar(258) = QUOTENAME(@MappingTable);
    DECLARE @Sql nvarchar(max);

    BEGIN TRY
        SET @Sql = N'DECLARE @ResultName sysname,@TargetTable sysname;
SELECT TOP (0) @ResultName=[ResultName],@TargetTable=[TargetTable]
FROM ' + @MappingTableQuoted + N';';
        EXEC [sys].[sp_executesql] @Sql;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INTERNAL_ERROR';
        SET @ErrorMessage = N'Die Mapping-Temp-Tabelle wurde nicht mit dem erwarteten Schema angelegt.';
        GOTO PreflightFailed;
    END CATCH;

    DECLARE @TargetTable sysname;
    DECLARE @TargetTableQuoted nvarchar(258);
    DECLARE @HasRows bit;
    DECLARE @Marker sysname;
    DECLARE @MarkerAdded bit;
    DECLARE @ColumnCount int;

    DECLARE [TargetCursor] CURSOR LOCAL FAST_FORWARD FOR
        SELECT [TargetTable]
        FROM [#InternalPrepareResultTables_Parsed]
        ORDER BY [ResultName];

    OPEN [TargetCursor];
    FETCH NEXT FROM [TargetCursor] INTO @TargetTable;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
              @TargetTableQuoted = QUOTENAME(@TargetTable)
            , @HasRows = NULL
            , @Marker = N'__MonitorPreflight_' + REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N'')
            , @MarkerAdded = 0
            , @ColumnCount = NULL;

        BEGIN TRY
            SET @Sql = N'SELECT @HasRows = CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM '
                     + @TargetTableQuoted + N') THEN 1 ELSE 0 END);';
            EXEC [sys].[sp_executesql] @Sql,N'@HasRows bit OUTPUT',@HasRows=@HasRows OUTPUT;

            IF @HasRows = 1
            BEGIN
                SET @StatusCode = 'INVALID_RESULT_TABLE_TARGET';
                SET @ErrorMessage = N'Alle TABLE-Ziele müssen vor dem Aufruf leer sein.';
                CLOSE [TargetCursor];
                DEALLOCATE [TargetCursor];
                GOTO PreflightFailed;
            END;

            SET @Sql = N'ALTER TABLE ' + @TargetTableQuoted
                     + N' ADD ' + QUOTENAME(@Marker) + N' bit NULL;';
            EXEC [sys].[sp_executesql] @Sql;
            SET @MarkerAdded = 1;

            SELECT @ColumnCount = COUNT(*)
            FROM [tempdb].[sys].[columns] AS [c] WITH (NOLOCK)
            INNER JOIN [tempdb].[sys].[tables] AS [t] WITH (NOLOCK)
              ON [t].[object_id] = [c].[object_id]
            WHERE EXISTS
                  (
                      SELECT 1
                      FROM [tempdb].[sys].[columns] AS [m] WITH (NOLOCK)
                      WHERE [m].[object_id] = [t].[object_id]
                        AND [m].[name] = @Marker
                  );

            SET @Sql = N'ALTER TABLE ' + @TargetTableQuoted
                     + N' DROP COLUMN ' + QUOTENAME(@Marker) + N';';
            EXEC [sys].[sp_executesql] @Sql;
            SET @MarkerAdded = 0;

            IF @ColumnCount <> 2
            BEGIN
                SET @StatusCode = 'INVALID_RESULT_TABLE_TARGET';
                SET @ErrorMessage = N'Jedes neue TABLE-Ziel muss genau eine Seed-Spalte besitzen.';
                CLOSE [TargetCursor];
                DEALLOCATE [TargetCursor];
                GOTO PreflightFailed;
            END;
        END TRY
        BEGIN CATCH
            IF @MarkerAdded = 1
            BEGIN TRY
                SET @Sql = N'ALTER TABLE ' + @TargetTableQuoted
                         + N' DROP COLUMN ' + QUOTENAME(@Marker) + N';';
                EXEC [sys].[sp_executesql] @Sql;
            END TRY
            BEGIN CATCH
            END CATCH;

            SET @StatusCode = 'INVALID_RESULT_TABLE_TARGET';
            SET @ErrorMessage = N'Mindestens eine angeforderte lokale Ziel-Temp-Tabelle ist nicht vorhanden oder nicht sicher validierbar.';
            CLOSE [TargetCursor];
            DEALLOCATE [TargetCursor];
            GOTO PreflightFailed;
        END CATCH;

        FETCH NEXT FROM [TargetCursor] INTO @TargetTable;
    END;
    CLOSE [TargetCursor];
    DEALLOCATE [TargetCursor];

    SET @Sql = N'INSERT ' + @MappingTableQuoted + N'([ResultName],[TargetTable])
SELECT [ResultName],[TargetTable]
FROM [#InternalPrepareResultTables_Parsed];';
    EXEC [sys].[sp_executesql] @Sql;
    RETURN;

PreflightFailed:
    IF @ThrowOnError = 1
        THROW 51011, @ErrorMessage, 1;
END;
GO
