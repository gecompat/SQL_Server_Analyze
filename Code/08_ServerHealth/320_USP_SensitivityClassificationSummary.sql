USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_SensitivityClassificationSummary
Version      : 1.0.0
Stand        : 2026-11-13
Zweck        : Die Procedure zählt Klassifikationsmetadaten je caller-sichtbarer Datenbank.
Quellen      : sys.tables, sys.columns, sys.sensitivity_classifications.
Grenzen      : Nur sichtbare Tabellen und Spalten; kein Vollständigkeits-,
               Schutzwirkungs- oder Datenqualitätsurteil.
Datenschutz  : Keine Tabellenwerte, Klassifikationstexte oder Objekt-/Spaltennamen.
Nebenwirkung : Produktpfad read-only im Caller-Kontext.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_SensitivityClassificationSummary]
      @DatabaseNames nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit = 0
    , @DatabaseNamePattern nvarchar(4000) = NULL
    , @MaxZeilen int = 1000
    , @LockTimeoutMs int = 0
    , @ResultSetArt varchar(16) = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen bit = 0
    , @Json nvarchar(max) = NULL OUTPUT
    , @PrintMeldungen bit = 1
    , @Hilfe bit = 0
    , @StatusCodeOut varchar(40) = NULL OUTPUT
    , @IsPartialOut bit = NULL OUTPUT
    , @ErrorNumberOut int = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;

    DECLARE @OriginalLockTimeout int=@@LOCK_TIMEOUT;
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                           THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @LockTimeoutSql nvarchar(100),
        @Started datetime2(3),
        @Observed bigint=NULL,
        @SelectionStatus varchar(40),
        @SelectionMessage nvarchar(2048),
        @SelectionError int=NULL,
        @CrossDatabaseRequested bit,
        @Status varchar(40)='SKIPPED',
        @Error int=NULL,
        @Message nvarchar(2048)=NULL,
        @TableStatus varchar(40),
        @TableMessage nvarchar(2048),
        @TableError int,
        @TableFailureError int=NULL,
        @Sql nvarchar(max);
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @LockTimeoutSql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@OriginalLockTimeout)+N';';

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_SensitivityClassificationSummary';
        PRINT N'Die Procedure zählt sichtbare Tabellen, deren Spalten und klassifizierte sichtbare Tabellenspalten je ausgewählter ONLINE-Datenbank. Es werden keine Tabellenwerte oder Klassifikationstexte gelesen. Eine Nullzählung ist nur nach erfolgreicher Quelle ein sichtbares Nullergebnis und kein Abwesenheits- oder Vollständigkeitsbeweis. Die drei Zählabfragen laufen nacheinander und sind keine atomare Aufnahme.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. NULL, leerer Text oder äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Eine aktive bracket-aware Pipe-Liste enthält einteilige Datenbanknamen; | innerhalb [...] ist Namensinhalt und ]] maskiert ]. Äußere Leerzeichen werden getrimmt; leere oder doppelte Segmente und Namen über 128 Zeichen sind ungültig. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; diese Grenze gilt nicht für die Gesamtliste. Eine aktive Liste und ein nicht-NULL-Pattern sind unzulässig. Standardauswahl: caller-sichtbare, zugreifbare ONLINE-Benutzerdatenbanken ohne Snapshots.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Datenbank-IDs bis 4 aus, 1 lässt sie als Kandidaten zu. NULL ist INVALID_PARAMETER. Numerische 0 wird 0, andere numerische Werte werden 1. Sichtbarkeit und Zugriff bleiben erforderlich.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Pattern; nicht-NULL-Leertext ist ungültig. Optionales like:, regex: oder regexi: vor einem nichtleeren Pattern; ohne Präfix gilt LIKE. LIKE und regex sind case-sensitiv, regexi ist case-insensitiv. LIKE verwendet SQL-LIKE-Syntax mit %, _, Zeichenklassen und ohne eigene ESCAPE-Klausel. Regex-Syntax wird vom Parser nicht vorvalidiert. Regex verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Eine aktive exakte Liste und Pattern sind unzulässig.';
        PRINT N'@MaxZeilen int; Default: 1000. NULL und 0 bedeuten unbegrenzt, negative Werte INVALID_PARAMETER, positive Werte 1 bis 2147483647 begrenzen ausschließlich ausgegebene classificationSummary-Datenbankzeilen nach DatabaseId. Die Kandidatenermittlung und Kataloglesearbeit werden nicht begrenzt. Ein abgeschnittenes Ergebnis erhält OUTPUT_LIMIT.';
        PRINT N'@LockTimeoutMs int; Default: 0. Nur 0 bis 60000 Millisekunden sind zulässig; NULL ist INVALID_PARAMETER. 0 ist NOWAIT. Der Wert gilt je dynamischem Datenbank-Katalogbatch und ist keine Gesamtdauergrenze. Der vorherige Sessionwert wird wiederhergestellt.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach äußerem U+0020-Trimmen und Großschreibung sind ausschließlich CONSOLE, RAW, TABLE und NONE zulässig; NULL/leer ist ungültig. CONSOLE zeigt genau eine formatierte Fachmenge. RAW liefert moduleStatus, classificationSummary, sourceStatus, warnings. TABLE schreibt gemappte Mengen; NONE liefert keine Resultsets. JSON bleibt unabhängig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE nimmt ein JSON-Objekt mit wenigstens einer Zuordnung an. Schlüssel sind exakt moduleStatus, classificationSummary, sourceStatus, warnings; Werte sind unterschiedliche lokale #Temp-Namen. Zielnamen sind maximal 116 Zeichen lang, beginnen mit #, nicht mit ## oder dem reservierten #Monitor-Präfix. Die Ziele müssen vorhanden, leer und mit genau einer Seed-Spalte ausgestattet sein. Doppelte Schlüssel werden binär, doppelte Zielnamen case-insensitiv geprüft; ungültige, doppelte oder unbekannte Schlüssel/Ziele werden vor der fachlichen Quellenlesung abgewiesen. Ein späterer Writer-Fehler kann bereits geschriebene Ziele hinterlassen. Außerhalb TABLE sind nur NULL, leer oder U+0020-Leerzeichen zulässig.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt JSON mit schemaVersion 1, meta und allen vier Arrays; NULL und 0 erzeugen kein JSON. Numerische 0 wird 0, andere numerische Werte werden 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optional an eine nvarchar(max)-Variable mit OUTPUT binden. Eingang wird auf NULL gesetzt; JSON entsteht nur bei JsonErzeugen=1 im normalen Pfad. Hilfe, frühe Parameterfehler und äußerer CATCH lassen NULL.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 gibt zusätzliche niedrige Severity-Meldungen zu Fehlern aus; 0 und NULL unterdrücken sie. Status, Resultsets und OUTPUT-Werte bleiben davon unabhängig. Numerische 0 wird 0, andere numerische Werte werden 1.';
        PRINT N'@Hilfe bit; Default: 0. 1 gibt diese Hilfe vor Auswahl und Katalogzugriff aus, setzt StatusCodeOut=AVAILABLE und IsPartialOut=0 und kehrt mit 0 zurück. NULL und 0 führen den normalen Pfad aus.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. AVAILABLE bedeutet nur Hilfe; AVAILABLE_LIMITED erfolgreiche sichtbare Quelle; SKIPPED keine Kandidatendatenbank und keine Katalogaufnahme; INVALID_PARAMETER direkte Eingabe oder Auswahlvertrag; INTERNAL_ERROR interner Kandidaten-Vorbereitungsfehler; SELECTION_UNAVAILABLE fehlender Helferstatus als Fallback; UNAVAILABLE_FEATURE fehlende Regexvoraussetzung; DATABASE_UNAVAILABLE nicht erreichbare Datenbank; SYSTEM_DATABASE_EXCLUDED ausgeschlossene explizite Systemdatenbank; DENIED_PERMISSION negative effektive Rechteprüfung oder native Berechtigungsfehler; SOURCE_UNAVAILABLE unbekanntes Prüfergebnis oder Quellenfehler; TIMEOUT SQL 1222; ERROR_HANDLED äußerer Fehler. Der erste relevante Quellenfehler bestimmt den globalen Status.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. Hilfe liefert 0, jeder normale Lauf und Fehlerpfad 1, weil Metadatensicht begrenzt sein kann.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. Erfolgreicher Lauf/Hilfe lassen NULL. Direkte Eingabefehler liefern 51011; Preflight-Rechteprüfung ohne nativen Fehler lässt NULL. Gefangene SQL-Fehler liefern die echte Fehlernummer.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optional mit OUTPUT binden; Eingang wird zurückgesetzt. Bei negativer/unklarer Rechteprüfung gibt es einen festen Text; gefangene SQL-Fehler bewahren ERROR_MESSAGE links auf 2048 Zeichen. Hilfe/erfolgreicher Lauf lassen NULL.';
        PRINT N'EXEC [monitor].[USP_SensitivityClassificationSummary] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SensitivityClassificationSummary] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE #SensitivityClassificationSummaryExample ([Seed] int NULL); EXEC [monitor].[USP_SensitivityClassificationSummary] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"classificationSummary":"#SensitivityClassificationSummaryExample"}''; SELECT * FROM #SensitivityClassificationSummaryExample; DROP TABLE #SensitivityClassificationSummaryExample;';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;

    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @MaxZeilen<0
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR @SystemdatenbankenEinbeziehen IS NULL
       OR
       (
           @DatabaseNamePattern IS NOT NULL
           AND NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NOT NULL
       )
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungueltiger Ausgabe-, Datenbankauswahl-, Limit- oder TABLE-Parameter.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;

    BEGIN TRY
        SET XACT_ABORT OFF;
        CREATE TABLE [#SensitivityClassificationSummary_moduleStatus]
        (
            [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CapturedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [RowCount] bigint NOT NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#SensitivityClassificationSummary_classificationSummary]
        (
            [DatabaseId] int NOT NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [VisibleTableCount] bigint NULL,
            [VisibleTableColumnCount] bigint NULL,
            [ClassifiedVisibleTableColumnCount] bigint NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ErrorNumber] int NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#SensitivityClassificationSummary_sourceStatus]
        (
            [DatabaseId] int NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [StartedAtUtc] datetime2(3) NOT NULL,
            [CompletedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ObservedRows] bigint NULL,
            [ReturnedRows] bigint NULL,
            [IsLimited] bit NOT NULL,
            [ErrorNumber] int NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#SensitivityClassificationSummary_warnings]
        (
            [DatabaseId] int NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#SensitivityClassificationSummary_Map]
        (
            [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#SensitivityClassificationSummary_Candidates]
        (
            [DatabaseId] int NOT NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [IsReadOnly] bit NULL,
            [CompatibilityLevel] tinyint NULL,
            [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [IsSystemDatabase] bit NULL,
            [RequestedOrdinal] int NULL
        );
        CREATE TABLE [#SensitivityClassificationSummary_SelectionWarnings]
        (
            [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#SensitivityClassificationSummary_Console]
        (
            [Bereich] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [Objekt] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );

        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables]
                @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|classificationSummary|sourceStatus|warnings',
                @MappingTable=N'#SensitivityClassificationSummary_Map',
                @StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,
                @ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SET @TableFailureError=51011;
                RAISERROR(N'%s',16,1,@TableMessage);
            END;
        END;

        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            EXEC [monitor].[USP_PrepareDatabaseCandidates]
                @DatabaseNames=@DatabaseNames,
                @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,
                @DatabaseNamePattern=@DatabaseNamePattern,
                @StatusCode=@SelectionStatus OUTPUT,
                @ErrorMessage=@SelectionMessage OUTPUT,
                @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,
                @CandidateTable=N'#SensitivityClassificationSummary_Candidates',
                @WarningTable=N'#SensitivityClassificationSummary_SelectionWarnings';
            SELECT @SelectionError=MIN(CASE WHEN [StatusCode] IS NOT NULL THEN 51011 END)
            FROM [#SensitivityClassificationSummary_SelectionWarnings];
            INSERT [#SensitivityClassificationSummary_sourceStatus]
            SELECT NULL,[RequestedName],'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   COALESCE([StatusCode],'AVAILABLE_LIMITED'),
                   CASE WHEN [StatusCode] IS NULL THEN 'VISIBLE_ONLY' ELSE 'UNPROVEN' END,
                   NULL,NULL,0,
                   CASE WHEN [StatusCode] IS NULL THEN NULL ELSE 51011 END,
                   [ErrorMessage]
            FROM [#SensitivityClassificationSummary_SelectionWarnings];
            INSERT [#SensitivityClassificationSummary_warnings]
            SELECT NULL,[RequestedName],'TARGET_SELECTION','DATABASE_SELECTION',
                   LEFT(COALESCE([ErrorMessage],N'Die angeforderte Datenbank ist nicht verfügbar.'),1000)
            FROM [#SensitivityClassificationSummary_SelectionWarnings];
            IF COALESCE(@SelectionStatus,'')<>'AVAILABLE'
            BEGIN
                SET @Error=COALESCE(@SelectionError,51011);
                SET @Message=COALESCE(@SelectionMessage,N'Die Datenbankauswahl konnte nicht erstellt werden.');
                SET @Status=COALESCE(@SelectionStatus,'SELECTION_UNAVAILABLE');
                IF NOT EXISTS(SELECT 1 FROM [#SensitivityClassificationSummary_sourceStatus]
                              WHERE [SourceKey]='DATABASE_SELECTION')
                    INSERT [#SensitivityClassificationSummary_sourceStatus]
                    VALUES(NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                           @Status,'UNPROVEN',NULL,NULL,0,@Error,@Message);
            END
            ELSE
            BEGIN
                SELECT @Observed=COUNT_BIG(*) FROM [#SensitivityClassificationSummary_Candidates];
                INSERT [#SensitivityClassificationSummary_sourceStatus]
                VALUES(NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                       'AVAILABLE_LIMITED','CALLER_VISIBLE',@Observed,@Observed,0,NULL,NULL);
            END;
        END TRY
        BEGIN CATCH
            SET @Error=ERROR_NUMBER();
            SET @Message=LEFT(ERROR_MESSAGE(),2048);
            SET @Status=CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                             WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
            INSERT [#SensitivityClassificationSummary_sourceStatus]
            VALUES(NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   @Status,'UNPROVEN',NULL,NULL,0,@Error,@Message);
            INSERT [#SensitivityClassificationSummary_warnings]
            VALUES(NULL,NULL,'SOURCE_UNAVAILABLE','DATABASE_SELECTION',
                   N'Die Datenbankauswahl ist fehlgeschlagen; es wurde keine SensitivityClassification-Quelle als erfolgreich leer ausgewertet.');
        END CATCH;

        IF @Error IS NULL
        BEGIN
            DECLARE @DatabaseId int,@DatabaseName sysname,@DatabaseCreatedAt datetime,
                    @Permission int,@VisibleTableCount bigint,@VisibleColumnCount bigint,
                    @ClassifiedColumnCount bigint,@DbStatus varchar(40),@DbVisibility varchar(32),
                    @DbError int,@DbMessage nvarchar(2048),@QuotedDatabase nvarchar(258);
            DECLARE [SensitivitySummaryTargets] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [DatabaseId],[DatabaseName]
                FROM [#SensitivityClassificationSummary_Candidates] ORDER BY [DatabaseId];
            OPEN [SensitivitySummaryTargets];
            FETCH NEXT FROM [SensitivitySummaryTargets] INTO @DatabaseId,@DatabaseName;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SELECT @Started=SYSUTCDATETIME(),@Permission=NULL,
                       @VisibleTableCount=NULL,@VisibleColumnCount=NULL,@ClassifiedColumnCount=NULL,
                       @DbStatus='SOURCE_UNAVAILABLE',@DbVisibility='UNPROVEN',
                       @DbError=NULL,@DbMessage=NULL,@DatabaseCreatedAt=NULL,
                       @QuotedDatabase=QUOTENAME(@DatabaseName);
                BEGIN TRY
                    SELECT @DatabaseCreatedAt=[create_date]
                    FROM [master].[sys].[databases] WITH (NOLOCK)
                    WHERE [database_id]=@DatabaseId
                      AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                          =@DatabaseName COLLATE SQL_Latin1_General_CP1_CS_AS;
                    IF @DatabaseCreatedAt IS NULL
                        THROW 51012,N'Target database identity changed or is not available for this source.',1;
                    SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; USE '+@QuotedDatabase+N';
                        IF DB_ID()<>@Id OR NOT EXISTS
                          (SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
                           WHERE [database_id]=@Id
                             AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                                 =@Name COLLATE SQL_Latin1_General_CP1_CS_AS
                             AND [create_date]=@Created)
                            THROW 51012,N''Target database identity changed or is not available for this source.'',1;
                        SELECT @PermissionOut=HAS_PERMS_BY_NAME(NULL,N''DATABASE'',N''VIEW ANY SENSITIVITY CLASSIFICATION'');';
                    EXEC [sys].[sp_executesql] @Sql,
                        N'@Id int,@Name sysname,@Created datetime,@PermissionOut int OUTPUT',
                        @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,
                        @PermissionOut=@Permission OUTPUT;
                    IF @Permission=0
                    BEGIN
                        SET @DbStatus='DENIED_PERMISSION';
                        SET @DbMessage=N'Der Caller hat kein wirksames VIEW ANY SENSITIVITY CLASSIFICATION in dieser Datenbank.';
                    END
                    ELSE IF @Permission IS NULL
                    BEGIN
                        SET @DbStatus='SOURCE_UNAVAILABLE';
                        SET @DbMessage=N'Die wirksame Klassifikationsberechtigung konnte nicht bestimmt werden.';
                    END
                    ELSE
                    BEGIN
                        SET @Sql=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; USE '+@QuotedDatabase+N';
                            IF DB_ID()<>@Id OR NOT EXISTS
                              (SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
                               WHERE [database_id]=@Id
                                 AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                                     =@Name COLLATE SQL_Latin1_General_CP1_CS_AS
                                 AND [create_date]=@Created)
                                THROW 51012,N''Target database identity changed or is not available for this source.'',1;
                            SELECT @Tables=COUNT_BIG(*) FROM [sys].[tables] WITH (NOLOCK);
                            SELECT @Columns=COUNT_BIG(*)
                            FROM [sys].[tables] AS [t] WITH (NOLOCK)
                            INNER JOIN [sys].[columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[t].[object_id];
                            SELECT @Classified=COUNT_BIG(*)
                            FROM [sys].[tables] AS [t] WITH (NOLOCK)
                            INNER JOIN [sys].[columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[t].[object_id]
                            WHERE EXISTS
                              (SELECT 1 FROM [sys].[sensitivity_classifications] AS [sc] WITH (NOLOCK)
                               WHERE [sc].[class]=1 AND [sc].[major_id]=[t].[object_id]
                                 AND [sc].[minor_id]=[c].[column_id]);
                            IF DB_ID()<>@Id OR NOT EXISTS
                              (SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
                               WHERE [database_id]=@Id
                                 AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                                     =@Name COLLATE SQL_Latin1_General_CP1_CS_AS
                                 AND [create_date]=@Created)
                                THROW 51012,N''Target database identity changed or is not available for this source.'',1;';
                        EXEC [sys].[sp_executesql] @Sql,
                            N'@Id int,@Name sysname,@Created datetime,@Tables bigint OUTPUT,@Columns bigint OUTPUT,@Classified bigint OUTPUT',
                            @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,
                            @Tables=@VisibleTableCount OUTPUT,@Columns=@VisibleColumnCount OUTPUT,
                            @Classified=@ClassifiedColumnCount OUTPUT;
                        SET @DbStatus='AVAILABLE_LIMITED';
                        SET @DbVisibility='VISIBLE_ONLY';
                    END;
                END TRY
                BEGIN CATCH
                    SELECT @VisibleTableCount=NULL,@VisibleColumnCount=NULL,@ClassifiedColumnCount=NULL,
                           @DbError=ERROR_NUMBER(),@DbMessage=LEFT(ERROR_MESSAGE(),2048),
                           @DbStatus=CASE WHEN ERROR_NUMBER() IN(229,297,300,371) THEN 'DENIED_PERMISSION'
                                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                                          WHEN ERROR_NUMBER() IN(911,924,926,927,942,945,952,978,4060,51012)
                                               THEN 'DATABASE_UNAVAILABLE'
                                          ELSE 'SOURCE_UNAVAILABLE' END,
                           @DbVisibility='UNPROVEN';
                END CATCH;
                INSERT [#SensitivityClassificationSummary_classificationSummary]
                    ([DatabaseId],[DatabaseName],[VisibleTableCount],[VisibleTableColumnCount],
                     [ClassifiedVisibleTableColumnCount],[StatusCode],[VisibilityScope],
                     [ErrorNumber],[ErrorMessage])
                VALUES(@DatabaseId,@DatabaseName,@VisibleTableCount,@VisibleColumnCount,
                       @ClassifiedColumnCount,@DbStatus,@DbVisibility,@DbError,@DbMessage);
                INSERT [#SensitivityClassificationSummary_sourceStatus]
                VALUES(@DatabaseId,@DatabaseName,'SENSITIVITY_CLASSIFICATION_CATALOG','NATIVE',
                       @Started,SYSUTCDATETIME(),@DbStatus,@DbVisibility,
                       CASE WHEN @DbStatus='AVAILABLE_LIMITED' THEN 1 ELSE NULL END,
                       CASE WHEN @DbStatus='AVAILABLE_LIMITED' THEN 1 ELSE NULL END,
                       0,@DbError,@DbMessage);
                IF @DbStatus<>'AVAILABLE_LIMITED'
                    INSERT [#SensitivityClassificationSummary_warnings]
                    VALUES(@DatabaseId,@DatabaseName,@DbStatus,'SENSITIVITY_CLASSIFICATION_CATALOG',
                           N'Die Klassifikationsquelle wurde nicht erfolgreich gezählt; NULL-Zähler sind kein Nullergebnis.');
                FETCH NEXT FROM [SensitivitySummaryTargets] INTO @DatabaseId,@DatabaseName;
            END;
            CLOSE [SensitivitySummaryTargets]; DEALLOCATE [SensitivitySummaryTargets];
            IF NOT EXISTS(SELECT 1 FROM [#SensitivityClassificationSummary_Candidates])
            BEGIN
                SET @Started=SYSUTCDATETIME();
                INSERT [#SensitivityClassificationSummary_sourceStatus]
                VALUES(NULL,NULL,'SENSITIVITY_CLASSIFICATION_CATALOG','NATIVE',
                       @Started,SYSUTCDATETIME(),'SKIPPED','UNPROVEN',NULL,NULL,0,NULL,NULL);
                INSERT [#SensitivityClassificationSummary_warnings]
                VALUES(NULL,NULL,'NO_TARGET_DATABASE','SENSITIVITY_CLASSIFICATION_CATALOG',
                       N'Keine ausgewählte sichtbare ONLINE-Datenbank; die Klassifikationsquelle wurde nicht gelesen.');
            END;
        END;

        ;WITH [Bounded] AS
        (
            SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId]) AS [OutputOrdinal]
            FROM [#SensitivityClassificationSummary_classificationSummary]
        )
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s]
           SET [ReturnedRows]=CASE WHEN [s].[StatusCode]='AVAILABLE_LIMITED'
                                   THEN CASE WHEN [r].[DatabaseId] IS NULL THEN 0 ELSE 1 END
                                   ELSE NULL END,
               [IsLimited]=CASE WHEN [s].[DatabaseId] IS NOT NULL AND [r].[DatabaseId] IS NULL THEN 1 ELSE 0 END
        FROM [#SensitivityClassificationSummary_sourceStatus] AS [s]
        LEFT JOIN [#SensitivityClassificationSummary_classificationSummary] AS [r]
          ON [r].[DatabaseId]=[s].[DatabaseId]
        WHERE [s].[SourceKey]='SENSITIVITY_CLASSIFICATION_CATALOG';
        INSERT [#SensitivityClassificationSummary_warnings]
        VALUES(NULL,NULL,'CAPTURE_TIME_SKEW','SENSITIVITY_CLASSIFICATION_CATALOG',
               N'Drei Katalogzählungen laufen nacheinander; gleichzeitige Metadatenänderungen können die Zähler gegeneinander verschieben.');
        INSERT [#SensitivityClassificationSummary_warnings]
        VALUES(NULL,NULL,'METADATA_COMPLETENESS_UNPROVEN','SENSITIVITY_CLASSIFICATION_CATALOG',
               N'Nur caller-sichtbare Tabellen und Spalten in ausgewählten Online-Datenbanken; keine globale Vollständigkeit oder Klassifikationsqualität belegt.');
        INSERT [#SensitivityClassificationSummary_warnings]
            SELECT NULL,NULL,'OUTPUT_LIMIT','SENSITIVITY_CLASSIFICATION_CATALOG',
                   N'Das Zeilenlimit begrenzt nur die Ausgabe; vorgelagerte Kataloglesearbeit bleibt unbegrenzt.'
            WHERE EXISTS(SELECT 1 FROM [#SensitivityClassificationSummary_sourceStatus]
                         WHERE [SourceKey]='SENSITIVITY_CLASSIFICATION_CATALOG' AND [IsLimited]=1);

        IF @Error IS NULL
        BEGIN
            SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage],@Status=[StatusCode]
            FROM [#SensitivityClassificationSummary_sourceStatus]
            WHERE [StatusCode] NOT IN('AVAILABLE_LIMITED','SKIPPED')
            ORDER BY [SourceKey],[DatabaseId],[DatabaseName];
            IF @Status='SKIPPED' AND EXISTS
               (SELECT 1 FROM [#SensitivityClassificationSummary_sourceStatus]
                WHERE [SourceKey]='SENSITIVITY_CLASSIFICATION_CATALOG'
                  AND [StatusCode]='AVAILABLE_LIMITED')
                SET @Status='AVAILABLE_LIMITED';
        END;
        DECLARE @BusinessRows bigint=(SELECT COUNT_BIG(*) FROM [#SensitivityClassificationSummary_classificationSummary]);
        INSERT [#SensitivityClassificationSummary_moduleStatus]
        VALUES(N'USP_SensitivityClassificationSummary',@CapturedAtUtc,@Status,1,@BusinessRows,
               N'Caller-sichtbare Katalogzählung ausgewählter Online-Datenbanken; keine Klassifikationsqualität, Schutzwirkung oder globale Vollständigkeit.');

        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=
                (SELECT N'SensitivityClassificationSummary' AS [resultName],1 AS [schemaVersion],
                        @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],
                        CAST(1 AS bit) AS [isPartial],@Error AS [errorNumber],
                        @Message AS [errorMessage]
                 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=
                (SELECT * FROM [#SensitivityClassificationSummary_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_classificationSummary nvarchar(max)=
                (SELECT * FROM [#SensitivityClassificationSummary_classificationSummary] ORDER BY [DatabaseId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=
                (SELECT * FROM [#SensitivityClassificationSummary_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=
                (SELECT * FROM [#SensitivityClassificationSummary_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,
                N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),
                N',"classificationSummary":',COALESCE(@Json_classificationSummary,N'[]'),
                N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),
                N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;

        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#SensitivityClassificationSummary_moduleStatus];
            SELECT * FROM [#SensitivityClassificationSummary_classificationSummary] ORDER BY [DatabaseId];
            SELECT * FROM [#SensitivityClassificationSummary_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey];
            SELECT * FROM [#SensitivityClassificationSummary_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [DatabaseSensitivityClassificationOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable]
                FROM [#SensitivityClassificationSummary_Map] ORDER BY [ResultName];
            OPEN [DatabaseSensitivityClassificationOutput];
            FETCH NEXT FROM [DatabaseSensitivityClassificationOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#SensitivityClassificationSummary_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable]
                    @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @TableFailureError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [DatabaseSensitivityClassificationOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [DatabaseSensitivityClassificationOutput]; DEALLOCATE [DatabaseSensitivityClassificationOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            INSERT [#SensitivityClassificationSummary_Console]
            SELECT N'Klassifikation',[DatabaseName],
                   CONCAT(N'Tabellen=',COALESCE(CONVERT(nvarchar(30),[VisibleTableCount]),N'NULL'),
                          N'; Spalten=',COALESCE(CONVERT(nvarchar(30),[VisibleTableColumnCount]),N'NULL'),
                          N'; klassifiziert=',COALESCE(CONVERT(nvarchar(30),[ClassifiedVisibleTableColumnCount]),N'NULL'),
                          N'; Status=',[StatusCode])
            FROM [#SensitivityClassificationSummary_classificationSummary];
            INSERT [#SensitivityClassificationSummary_Console]
            SELECT N'Quelle',[SourceKey],CONCAT([StatusCode],N'; beobachtet=',
                   COALESCE(CONVERT(nvarchar(30),[ObservedRows]),N'NULL'),
                   N'; ausgegeben=',COALESCE(CONVERT(nvarchar(30),[ReturnedRows]),N'NULL'))
            FROM [#SensitivityClassificationSummary_sourceStatus];
            INSERT [#SensitivityClassificationSummary_Console]
            SELECT N'Aussagegrenze',[WarningCode],[Detail]
            FROM [#SensitivityClassificationSummary_warnings];
            EXEC [monitor].[InternalEmitConsoleResult]
                @SourceTable=N'#SensitivityClassificationSummary_Console',
                @ResultLabel=N'Sichtbare Klassifikationszählung',
                @EmptyMessage=N'Keine ausgewählte sichtbare Datenbankzeile; Quellenstatus und Auswahl prüfen.';
        END;

        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_SensitivityClassificationSummary: mindestens eine Quelle ist nicht verfügbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @LockTimeoutSql;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@TableFailureError,ERROR_NUMBER()),
               @Message=LEFT(ERROR_MESSAGE(),2048),@Json=NULL;
        SELECT @Status='ERROR_HANDLED',@StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @LockTimeoutSql;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
