USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PlanGuideInventory
Version      : 1.0.0
Stand        : 2026-11-13
Zweck        : Inventarisiert caller-sichtbare Plan-Guide-Katalogmetadaten je
               ausgewählter Online-Datenbank.
Quellen      : sys.plan_guides.
Grenzen      : Keine Validierung, Wirksamkeits- oder Vollständigkeitsprüfung.
Datenschutz  : Keine SQL-, Batch-, Parameter- oder Hint-Definitionen.
Nebenwirkung : Read-only im Caller-Kontext; keine Plan-Guide-Aktion oder Compile.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_PlanGuideInventory]
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
        PRINT N'monitor.USP_PlanGuideInventory';
        PRINT N'Die Procedure liest pro ausgewählter ONLINE-Datenbank nur caller-sichtbare Zeilen aus sys.plan_guides. ScopeType 1 bedeutet OBJECT, 2 SQL, 3 TEMPLATE; unbekannte native Werte bleiben unverändert. IsDisabled ist ein Konfigurationswert, kein Wirksamkeitsbeleg. ValidationStatus ist stets UNASSESSED; es wird keine Validierung oder Kompilierung ausgeführt. Leere Fachzeilen belegen nur eine leere sichtbare Menge.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. NULL, leerer Text oder äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Eine aktive bracket-aware Pipe-Liste enthält einteilige Datenbanknamen; | innerhalb [...] ist Namensinhalt und ]] maskiert ]. Äußere Leerzeichen werden getrimmt; leere oder doppelte Segmente und Namen über 128 Zeichen sind ungültig. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten enthalten, die Gesamtliste ist offen. Eine aktive Liste und ein nicht-NULL-Pattern sind unzulässig. Standard sind caller-sichtbare zugreifbare ONLINE-Benutzerdatenbanken ohne Snapshots.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Datenbank-IDs bis 4 aus; 1 lässt sie als Kandidaten zu. NULL ist INVALID_PARAMETER. Numerische 0 wird 0, andere numerische Werte werden 1; Sichtbarkeit und Zugriff bleiben erforderlich.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Pattern; nicht-NULL-Leertext ist ungültig. like:, regex: und regexi: sind zulässige Präfixe, ohne Präfix gilt LIKE. LIKE und regex sind case-sensitiv, regexi ist case-insensitiv. LIKE verwendet SQL-LIKE-Syntax mit %, _, Zeichenklassen und ohne eigene ESCAPE-Klausel. Regex verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Eine aktive exakte Liste und Pattern sind unzulässig.';
        PRINT N'@MaxZeilen int; Default: 1000. NULL oder 0 bedeuten unbegrenzt; negative Werte sind INVALID_PARAMETER. Positive Werte 1 bis 2147483647 begrenzen ausschließlich ausgegebene planGuides-Zeilen in der Reihenfolge DatabaseId, PlanGuideId. Auswahl und Kataloglesearbeit bleiben unbegrenzt; echte Kürzung erhält OUTPUT_LIMIT.';
        PRINT N'@LockTimeoutMs int; Default: 0. Nur 0 bis 60000 Millisekunden sind zulässig; NULL ist INVALID_PARAMETER. 0 ist NOWAIT. Der Wert gilt je dynamischem Datenbank-Katalogbatch und ist keine Gesamtdauergrenze. Der vorherige Sessionwert wird wiederhergestellt.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach äußerem U+0020-Trimmen und Großschreibung sind CONSOLE, RAW, TABLE und NONE zulässig. NULL oder leer ist INVALID_PARAMETER. CONSOLE liefert eine formatierte Fachmenge, RAW moduleStatus, planGuides, sourceStatus und warnings in dieser Reihenfolge, TABLE schreibt benannte Mengen, NONE liefert keine Fachresultsets. JSON ist unabhängig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE akzeptiert ein JSON-Objekt mit wenigstens einer Zuordnung der exakt case-sensitiven Schlüssel moduleStatus, planGuides, sourceStatus, warnings zu verschiedenen lokalen #Temp-Zielen. Ziele müssen existieren, leer sein und genau eine Seed-Spalte haben; Namen höchstens 116 Zeichen, nicht ## oder #Monitor. Doppelte und unbekannte Schlüssel, doppelte oder ungültige Ziele werden vor Quellenzugriff abgewiesen. Ein späterer Writer-Fehler kann frühere Zielschreibungen belassen. Außerhalb TABLE sind nur NULL, leer oder U+0020-Leerzeichen zulässig.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt JSON mit schemaVersion 1, meta und allen vier Arrays; NULL und 0 erzeugen keines. Numerische 0 wird 0, andere numerische Werte werden 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optional an eine nvarchar(max)-Variable mit OUTPUT binden; Eingang wird auf NULL gesetzt. Bei JsonErzeugen=1 entsteht JSON im normalen Pfad. Hilfe, direkte Parameterfehler und äußerer CATCH lassen NULL.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 gibt zusätzliche niedrige Severity-Meldungen zu Fehlern aus; 0 und NULL unterdrücken sie. Andere Ergebnisse bleiben gleich. Numerische 0 wird 0, andere numerische Werte werden 1.';
        PRINT N'@Hilfe bit; Default: 0. 1 gibt diese Hilfe vor Auswahl und Katalogzugriff aus, setzt StatusCodeOut=AVAILABLE und IsPartialOut=0 und kehrt mit 0 zurück. NULL und 0 führen den normalen Pfad aus.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optional an varchar(40) mit OUTPUT binden; Eingang wird zurückgesetzt. AVAILABLE bedeutet nur Hilfe; AVAILABLE_LIMITED erfolgreiche sichtbare Quelle, auch leer; SKIPPED keine Kandidatendatenbank; INVALID_PARAMETER ungültige Eingabe oder Auswahl; INTERNAL_ERROR Auswahlhelferfehler; SELECTION_UNAVAILABLE fehlender Auswahlstatus; UNAVAILABLE_FEATURE fehlende Regexvoraussetzung; DATABASE_UNAVAILABLE fehlende, nicht online befindliche oder nicht zugreifbare Datenbank; SYSTEM_DATABASE_EXCLUDED explizit ausgeschlossene Systemdatenbank; DENIED_PERMISSION native Berechtigungsfehler; SOURCE_UNAVAILABLE unbekanntes Prüfergebnis oder Quellenfehler; TIMEOUT SQL 1222; ERROR_HANDLED äußerer Fehler. Der erste relevante Quellenfehler bestimmt den globalen Status.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optional an bit mit OUTPUT binden; Eingang wird zurückgesetzt. Hilfe liefert 0; jeder normale Lauf und Fehlerpfad 1. Numerische 0/1-Ausgabe kennzeichnet begrenzte Metadatensicht, nicht eine Fehlerursache.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optional an int mit OUTPUT binden; Eingang wird zurückgesetzt. Erfolg und Hilfe lassen NULL; direkte Parameterfehler liefern 51011; gefangene SQL-Fehler ihre native oder Writer-Fehlernummer.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optional an nvarchar(2048) mit OUTPUT binden; Eingang wird zurückgesetzt. Erfolg und Hilfe lassen NULL; gefangene SQL-Fehler liefern die links auf 2048 Zeichen gekürzte Meldung.';
        PRINT N'EXEC [monitor].[USP_PlanGuideInventory] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'DECLARE @Json nvarchar(max); EXEC [monitor].[USP_PlanGuideInventory] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'CREATE TABLE #PlanGuideInventoryExample ([Seed] int NULL); EXEC [monitor].[USP_PlanGuideInventory] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"planGuides":"#PlanGuideInventoryExample"}''; SELECT * FROM #PlanGuideInventoryExample; DROP TABLE #PlanGuideInventoryExample;';
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
        CREATE TABLE [#PlanGuideInventory_moduleStatus]
        (
            [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CapturedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [RowCount] bigint NOT NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#PlanGuideInventory_planGuides]
        (
            [DatabaseId] int NOT NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [PlanGuideId] int NOT NULL,
            [PlanGuideName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [ScopeType] tinyint NOT NULL,
            [ScopeTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsDisabled] bit NOT NULL,
            [ScopeObjectId] int NULL,
            [CreateDate] datetime NOT NULL,
            [ModifyDate] datetime NOT NULL,
            [ValidationStatus] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#PlanGuideInventory_sourceStatus]
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
        CREATE TABLE [#PlanGuideInventory_warnings]
        (
            [DatabaseId] int NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#PlanGuideInventory_Map]
        (
            [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#PlanGuideInventory_Candidates]
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
        CREATE TABLE [#PlanGuideInventory_SelectionWarnings]
        (
            [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#PlanGuideInventory_Console]
        (
            [Bereich] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [Objekt] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );

        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables]
                @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|planGuides|sourceStatus|warnings',
                @MappingTable=N'#PlanGuideInventory_Map',
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
                @CandidateTable=N'#PlanGuideInventory_Candidates',
                @WarningTable=N'#PlanGuideInventory_SelectionWarnings';
            SELECT @SelectionError=MIN(CASE WHEN [StatusCode] IS NOT NULL THEN 51011 END)
            FROM [#PlanGuideInventory_SelectionWarnings];
            INSERT [#PlanGuideInventory_sourceStatus]
            SELECT NULL,[RequestedName],'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   COALESCE([StatusCode],'AVAILABLE_LIMITED'),
                   CASE WHEN [StatusCode] IS NULL THEN 'VISIBLE_ONLY' ELSE 'UNPROVEN' END,
                   NULL,NULL,0,
                   CASE WHEN [StatusCode] IS NULL THEN NULL ELSE 51011 END,
                   [ErrorMessage]
            FROM [#PlanGuideInventory_SelectionWarnings];
            INSERT [#PlanGuideInventory_warnings]
            SELECT NULL,[RequestedName],'TARGET_SELECTION','DATABASE_SELECTION',
                   LEFT(COALESCE([ErrorMessage],N'Die angeforderte Datenbank ist nicht verfügbar.'),1000)
            FROM [#PlanGuideInventory_SelectionWarnings];
            IF COALESCE(@SelectionStatus,'')<>'AVAILABLE'
            BEGIN
                SET @Error=COALESCE(@SelectionError,51011);
                SET @Message=COALESCE(@SelectionMessage,N'Die Datenbankauswahl konnte nicht erstellt werden.');
                SET @Status=COALESCE(@SelectionStatus,'SELECTION_UNAVAILABLE');
                IF NOT EXISTS(SELECT 1 FROM [#PlanGuideInventory_sourceStatus]
                              WHERE [SourceKey]='DATABASE_SELECTION')
                    INSERT [#PlanGuideInventory_sourceStatus]
                    VALUES(NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                           @Status,'UNPROVEN',NULL,NULL,0,@Error,@Message);
            END
            ELSE
            BEGIN
                SELECT @Observed=COUNT_BIG(*) FROM [#PlanGuideInventory_Candidates];
                INSERT [#PlanGuideInventory_sourceStatus]
                VALUES(NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                       'AVAILABLE_LIMITED','CALLER_VISIBLE',@Observed,@Observed,0,NULL,NULL);
            END;
        END TRY
        BEGIN CATCH
            SET @Error=ERROR_NUMBER();
            SET @Message=LEFT(ERROR_MESSAGE(),2048);
            SET @Status=CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                             WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
            INSERT [#PlanGuideInventory_sourceStatus]
            VALUES(NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   @Status,'UNPROVEN',NULL,NULL,0,@Error,@Message);
            INSERT [#PlanGuideInventory_warnings]
            VALUES(NULL,NULL,'SOURCE_UNAVAILABLE','DATABASE_SELECTION',
                   N'Die Datenbankauswahl ist fehlgeschlagen; es wurde keine Plan-Guide-Quelle als erfolgreich leer ausgewertet.');
        END CATCH;

        IF @Error IS NULL
        BEGIN
            DECLARE @DatabaseId int,@DatabaseName sysname,@DatabaseCreatedAt datetime,
                    @DbStatus varchar(40),@DbVisibility varchar(32),
                    @DbError int,@DbMessage nvarchar(2048),@QuotedDatabase nvarchar(258),
                    @DbObserved bigint;
            DECLARE [PlanGuideTargets] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [DatabaseId],[DatabaseName]
                FROM [#PlanGuideInventory_Candidates] ORDER BY [DatabaseId];
            OPEN [PlanGuideTargets];
            FETCH NEXT FROM [PlanGuideTargets] INTO @DatabaseId,@DatabaseName;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SELECT @Started=SYSUTCDATETIME(),@DbStatus='SOURCE_UNAVAILABLE',
                       @DbVisibility='UNPROVEN',@DbError=NULL,@DbMessage=NULL,
                       @DatabaseCreatedAt=NULL,@DbObserved=NULL,
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
                        INSERT [#PlanGuideInventory_planGuides]
                            ([DatabaseId],[DatabaseName],[PlanGuideId],[PlanGuideName],
                             [ScopeType],[ScopeTypeDesc],[IsDisabled],[ScopeObjectId],
                             [CreateDate],[ModifyDate],[ValidationStatus])
                        SELECT @Id,@Name,[plan_guide_id],[name],[scope_type],
                               [scope_type_desc],[is_disabled],[scope_object_id],
                               [create_date],[modify_date],''UNASSESSED''
                        FROM [sys].[plan_guides] WITH (NOLOCK);
                        SET @Rows=@@ROWCOUNT;
                        IF DB_ID()<>@Id OR NOT EXISTS
                          (SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
                           WHERE [database_id]=@Id
                             AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS
                                 =@Name COLLATE SQL_Latin1_General_CP1_CS_AS
                             AND [create_date]=@Created)
                            THROW 51012,N''Target database identity changed or is not available for this source.'',1;';
                    EXEC [sys].[sp_executesql] @Sql,
                        N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',
                        @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,
                        @Rows=@DbObserved OUTPUT;
                    SET @DbStatus='AVAILABLE_LIMITED';
                    SET @DbVisibility='VISIBLE_ONLY';
                END TRY
                BEGIN CATCH
                    DELETE FROM [#PlanGuideInventory_planGuides] WHERE [DatabaseId]=@DatabaseId;
                    SELECT @DbObserved=NULL,@DbError=ERROR_NUMBER(),
                           @DbMessage=LEFT(ERROR_MESSAGE(),2048),
                           @DbStatus=CASE WHEN ERROR_NUMBER() IN(229,297,300,371) THEN 'DENIED_PERMISSION'
                                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                                          WHEN ERROR_NUMBER() IN(911,924,926,927,942,945,952,978,4060,51012)
                                               THEN 'DATABASE_UNAVAILABLE'
                                          ELSE 'SOURCE_UNAVAILABLE' END,
                           @DbVisibility='UNPROVEN';
                END CATCH;
                INSERT [#PlanGuideInventory_sourceStatus]
                VALUES(@DatabaseId,@DatabaseName,'PLAN_GUIDES_CATALOG','NATIVE',
                       @Started,SYSUTCDATETIME(),@DbStatus,@DbVisibility,
                       @DbObserved,CASE WHEN @DbStatus='AVAILABLE_LIMITED' THEN @DbObserved ELSE NULL END,
                       0,@DbError,@DbMessage);
                IF @DbStatus<>'AVAILABLE_LIMITED'
                    INSERT [#PlanGuideInventory_warnings]
                    VALUES(@DatabaseId,@DatabaseName,@DbStatus,'PLAN_GUIDES_CATALOG',
                           N'Die Plan-Guide-Quelle wurde nicht erfolgreich gelesen; leere Fachzeilen sind kein Nullergebnis.');
                FETCH NEXT FROM [PlanGuideTargets] INTO @DatabaseId,@DatabaseName;
            END;
            CLOSE [PlanGuideTargets]; DEALLOCATE [PlanGuideTargets];
            IF NOT EXISTS(SELECT 1 FROM [#PlanGuideInventory_Candidates])
            BEGIN
                SET @Started=SYSUTCDATETIME();
                INSERT [#PlanGuideInventory_sourceStatus]
                VALUES(NULL,NULL,'PLAN_GUIDES_CATALOG','NATIVE',
                       @Started,SYSUTCDATETIME(),'SKIPPED','UNPROVEN',NULL,NULL,0,NULL,NULL);
                INSERT [#PlanGuideInventory_warnings]
                VALUES(NULL,NULL,'NO_TARGET_DATABASE','PLAN_GUIDES_CATALOG',
                       N'Keine ausgewählte sichtbare ONLINE-Datenbank; die Plan-Guide-Quelle wurde nicht gelesen.');
            END;
        END;

        ;WITH [Bounded] AS
        (
            SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[PlanGuideId]) AS [OutputOrdinal]
            FROM [#PlanGuideInventory_planGuides]
        )
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s]
           SET [ReturnedRows]=CASE WHEN [s].[StatusCode]='AVAILABLE_LIMITED'
                                   THEN COALESCE([r].[ReturnedRows],0) ELSE NULL END,
               [IsLimited]=CASE WHEN [s].[StatusCode]='AVAILABLE_LIMITED'
                                    AND [s].[ObservedRows]>COALESCE([r].[ReturnedRows],0)
                                THEN 1 ELSE 0 END
        FROM [#PlanGuideInventory_sourceStatus] AS [s]
        LEFT JOIN
        (
            SELECT [DatabaseId],COUNT_BIG(*) AS [ReturnedRows]
            FROM [#PlanGuideInventory_planGuides]
            GROUP BY [DatabaseId]
        ) AS [r] ON [r].[DatabaseId]=[s].[DatabaseId]
        WHERE [s].[SourceKey]='PLAN_GUIDES_CATALOG';
        INSERT [#PlanGuideInventory_warnings]
        VALUES(NULL,NULL,'VALIDATION_UNASSESSED','PLAN_GUIDES_CATALOG',
               N'Es wurden keine Validierungsfunktionen, Compile- oder Wirksamkeitsprüfungen ausgeführt; IsDisabled beschreibt nur den Katalogschalter.');
        INSERT [#PlanGuideInventory_warnings]
        VALUES(NULL,NULL,'METADATA_COMPLETENESS_UNPROVEN','PLAN_GUIDES_CATALOG',
               N'Nur caller-sichtbare Katalogzeilen ausgewählter Online-Datenbanken; keine globale Vollständigkeit oder Abwesenheit belegt.');
        INSERT [#PlanGuideInventory_warnings]
            SELECT NULL,NULL,'OUTPUT_LIMIT','PLAN_GUIDES_CATALOG',
                   N'Das Zeilenlimit begrenzt nur die Ausgabe; Auswahl und Kataloglesearbeit bleiben unbegrenzt.'
            WHERE EXISTS(SELECT 1 FROM [#PlanGuideInventory_sourceStatus]
                         WHERE [SourceKey]='PLAN_GUIDES_CATALOG' AND [IsLimited]=1);

        IF @Error IS NULL
        BEGIN
            SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage],@Status=[StatusCode]
            FROM [#PlanGuideInventory_sourceStatus]
            WHERE [StatusCode] NOT IN('AVAILABLE_LIMITED','SKIPPED')
            ORDER BY [SourceKey],[DatabaseId],[DatabaseName];
            IF @Error IS NULL
                SET @Status=CASE WHEN EXISTS
                    (SELECT 1 FROM [#PlanGuideInventory_sourceStatus]
                     WHERE [SourceKey]='PLAN_GUIDES_CATALOG'
                       AND [StatusCode]='AVAILABLE_LIMITED')
                    THEN 'AVAILABLE_LIMITED' ELSE 'SKIPPED' END;
        END;
        DECLARE @BusinessRows bigint=(SELECT COUNT_BIG(*) FROM [#PlanGuideInventory_planGuides]);
        INSERT [#PlanGuideInventory_moduleStatus]
        VALUES(N'USP_PlanGuideInventory',@CapturedAtUtc,@Status,1,@BusinessRows,
               N'Caller-sichtbare Plan-Guide-Katalogmetadaten; Validierung und Wirksamkeit UNASSESSED, Vollständigkeit unbewiesen.');

        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=
                (SELECT N'PlanGuideInventory' AS [resultName],1 AS [schemaVersion],
                        @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],
                        CAST(1 AS bit) AS [isPartial],@Error AS [errorNumber],
                        @Message AS [errorMessage]
                 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=
                (SELECT * FROM [#PlanGuideInventory_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_planGuides nvarchar(max)=
                (SELECT * FROM [#PlanGuideInventory_planGuides] ORDER BY [DatabaseId],[PlanGuideId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=
                (SELECT * FROM [#PlanGuideInventory_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=
                (SELECT * FROM [#PlanGuideInventory_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,
                N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),
                N',"planGuides":',COALESCE(@Json_planGuides,N'[]'),
                N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),
                N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;

        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#PlanGuideInventory_moduleStatus];
            SELECT * FROM [#PlanGuideInventory_planGuides] ORDER BY [DatabaseId],[PlanGuideId];
            SELECT * FROM [#PlanGuideInventory_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey];
            SELECT * FROM [#PlanGuideInventory_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [PlanGuideInventoryOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable]
                FROM [#PlanGuideInventory_Map] ORDER BY [ResultName];
            OPEN [PlanGuideInventoryOutput];
            FETCH NEXT FROM [PlanGuideInventoryOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#PlanGuideInventory_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable]
                    @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @TableFailureError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [PlanGuideInventoryOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [PlanGuideInventoryOutput]; DEALLOCATE [PlanGuideInventoryOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            INSERT [#PlanGuideInventory_Console]
            SELECT N'Plan Guide',[PlanGuideName],
                   CONCAT(N'Datenbank=',[DatabaseName],N'; ID=',[PlanGuideId],
                          N'; Scope=',[ScopeTypeDesc],N'; deaktiviert=',[IsDisabled],
                          N'; Validierung=',[ValidationStatus])
            FROM [#PlanGuideInventory_planGuides] ORDER BY [DatabaseId],[PlanGuideId];
            INSERT [#PlanGuideInventory_Console]
            SELECT N'Quelle',[SourceKey],CONCAT([StatusCode],N'; beobachtet=',
                   COALESCE(CONVERT(nvarchar(30),[ObservedRows]),N'NULL'),
                   N'; ausgegeben=',COALESCE(CONVERT(nvarchar(30),[ReturnedRows]),N'NULL'))
            FROM [#PlanGuideInventory_sourceStatus];
            INSERT [#PlanGuideInventory_Console]
            SELECT N'Aussagegrenze',[WarningCode],[Detail]
            FROM [#PlanGuideInventory_warnings];
            EXEC [monitor].[InternalEmitConsoleResult]
                @SourceTable=N'#PlanGuideInventory_Console',
                @ResultLabel=N'Sichtbare Plan-Guide-Katalogmetadaten',
                @EmptyMessage=N'Keine caller-sichtbare Plan-Guide-Zeile; Quellenstatus und Auswahl prüfen.';
        END;

        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_PlanGuideInventory: mindestens eine Quelle ist nicht verfügbar; siehe sourceStatus.',10,1) WITH NOWAIT;
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
