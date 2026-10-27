USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DatabaseMirroringInventory
Version      : 1.0.0
Stand        : 2026-10-27
Zweck        : Gibt caller-sichtbare lokale Database-Mirroring-Katalogwerte je
               ausgewählter Online-Datenbank aus.
Quellen      : master.sys.databases, master.sys.database_mirroring.
Grenzen      : Die Auswahl umfasst sichtbare Online-Datenbanken. Werte belegen
               weder eine vollständige Metadatensicht noch Mirroring-Gesundheit.
Datenschutz  : Partner-, Witness-, GUID- und LSN-Werte werden nicht ausgegeben.
Nebenwirkung : Read-only; keine Konfigurations-, Netzwerk- oder Probeoperation.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_DatabaseMirroringInventory]
      @DatabaseNames nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit = 0
    , @DatabaseNamePattern nvarchar(4000) = NULL
    , @MaxZeilen int = 1000
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

    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0
                           THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,
        @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),
        @Started datetime2(3),
        @Observed bigint=NULL,
        @Returned bigint=NULL,
        @SelectionStatus varchar(40),
        @SelectionMessage nvarchar(2048),
        @SelectionError int=NULL,
        @Status varchar(40)='AVAILABLE_LIMITED',
        @Error int=NULL,
        @Message nvarchar(2048)=NULL,
        @TableStatus varchar(40),
        @TableMessage nvarchar(2048),
        @TableError int,
        @TableFailureError int=NULL,
        @SourceAvailable bit=0,
        @Sql nvarchar(max);
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';

    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_DatabaseMirroringInventory: read-only caller-sichtbare Katalogwerte; keine Konfigurations-, Netzwerk- oder Probeoperation.';
        PRINT N'Quelle: master.sys.databases und master.sys.database_mirroring; ein Datensatz je ausgewaehlter ONLINE-Datenbank.';
        PRINT N'Ohne Filter alle sichtbaren ONLINE-Benutzerdatenbanken; Systemdatenbanken nur mit @SystemdatenbankenEinbeziehen=1.';
        PRINT N'Nicht ONLINE befindliche Datenbanken, einschließlich RESTORING-Mirror-Datenbanken, liegen außerhalb des V1-Selektors.';
        PRINT N'Native mirroring_-NULLs bleiben unverändert und unterscheiden nicht zwischen nicht gespiegelt, offline oder eingeschränkter Sicht.';
        PRINT N'Keine Partner-/Witness-Namen, GUIDs, LSNs, aktuelle Redo-Queue, Gesundheits-, Failover- oder Vollständigkeitsurteile.';
        PRINT N'Berechtigung: sichtbare Datenbankmetadaten; für nicht-master/tempdb Datenbanken Owner oder ALTER ANY DATABASE, VIEW ANY DATABASE oder CREATE DATABASE in master.';
        PRINT N'Für nicht-NULL-Werte einer Mirror-Datenbank ist sysadmin erforderlich; SQL Server 2022+ fordert VIEW SERVER PERFORMANCE STATE; die Quelle spezifiziert keine weitere Serverberechtigung für SQL Server 2019.';
        PRINT N'Linux liefert keine positive Database-Mirroring-Qualifikation; ein leeres Ergebnis belegt keine Windows-Funktion.';
        PRINT N'@DatabaseNames nvarchar(max)=NULL: exakte bracket-aware Pipe-Auswahlliste; getrennt von @DatabaseNamePattern.';
        PRINT N'@SystemdatenbankenEinbeziehen bit=0: 0 schließt Systemdatenbanken aus; 1 schließt sie ein, NULL ist ungültig. @DatabaseNamePattern nvarchar(4000)=NULL: Patternfilter; exakt und Pattern schließen einander aus.';
        PRINT N'Pattern: unpräfixiert und like: verwenden SQL-LIKE; regex: ist case-sensitiv, regexi: case-insensitiv.';
        PRINT N'Regex benötigt SQL Server 2025 und Kompatibilitätsstufe 170 der Frameworkdatenbank; SQL Server 2019/2022 oder niedrigere Kompatibilität liefern UNAVAILABLE_FEATURE.';
        PRINT N'@MaxZeilen int=1000: globales Limit fuer databaseMirroring; NULL/0 unbegrenzt, negativ ungueltig.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE'': CONSOLE, RAW, TABLE oder NONE; JSON-Erzeugung ist davon unabhängig.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL: TABLE-only JSON-Objekt mit den vier Schlüsseln moduleStatus, databaseMirroring, sourceStatus und warnings.';
        PRINT N'Jeder Schlüssel zeigt auf eine unterschiedliche lokale #Temp-Zieltabelle; kein ##, reserviertes #Monitor-Präfix oder Name über 116 Zeichen; leere Ein-Spalten-Seeds sind erlaubt, vorhandenes Schema muss exakt passen.';
        PRINT N'TABLE-Zuordnung: {"moduleStatus":"#DbmiModule","databaseMirroring":"#DbmiRows","sourceStatus":"#DbmiSources","warnings":"#DbmiWarnings"}.';
        PRINT N'@JsonErzeugen bit=0: 1 erzeugt unabhängig von der Ausgabeart schemaVersion=1 mit allen vier Arrays und nativen NULLs.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT: wird anfangs auf NULL gesetzt; Beispiel: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabaseMirroringInventory] @JsonErzeugen=1,@Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'@PrintMeldungen bit=1: erlaubt Meldungen mit niedriger Severity; 0 unterdrückt sie. @Hilfe bit=0: 1 zeigt diese Hilfe vor Auswahl und Quellenlesung.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT: AVAILABLE_LIMITED bei erfolgreicher Teilansicht; Quellenfehler bleiben Fehlerstatus.';
        PRINT N'@IsPartialOut bit=NULL OUTPUT: normale Inventare sind immer 1; Hilfe ist 0. @ErrorNumberOut int=NULL OUTPUT und @ErrorMessageOut nvarchar(2048)=NULL OUTPUT melden Fehler.';
        PRINT N'Beispiel: EXEC [monitor].[USP_DatabaseMirroringInventory] @ResultSetArt=''CONSOLE'';';
        PRINT N'Beispiel Pattern: EXEC [monitor].[USP_DatabaseMirroringInventory] @DatabaseNamePattern=N''like:Prod%'', @ResultSetArt=''CONSOLE'';';
        PRINT N'Beispiel JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabaseMirroringInventory] @DatabaseNames=N''[ExampleDatabase]'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;

    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @MaxZeilen<0
       OR @SystemdatenbankenEinbeziehen IS NULL
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
        CREATE TABLE [#DatabaseMirroringInventory_moduleStatus]
        (
            [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [CapturedAtUtc] datetime2(3) NOT NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [IsPartial] bit NOT NULL,
            [RowCount] bigint NOT NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DatabaseMirroringInventory_databaseMirroring]
        (
            [DatabaseId] int NOT NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [MirroringState] tinyint NULL,
            [MirroringStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [MirroringRole] tinyint NULL,
            [MirroringRoleDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [MirroringSafetyLevel] tinyint NULL,
            [MirroringSafetyLevelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [MirroringWitnessState] tinyint NULL,
            [MirroringWitnessStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ConfiguredRedoQueueLimitMb] int NULL,
            [RedoQueueLimitType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#DatabaseMirroringInventory_sourceStatus]
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
        CREATE TABLE [#DatabaseMirroringInventory_warnings]
        (
            [DatabaseId] int NULL,
            [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DatabaseMirroringInventory_Map]
        (
            [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#DatabaseMirroringInventory_Candidates]
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
        CREATE TABLE [#DatabaseMirroringInventory_SelectionWarnings]
        (
            [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#DatabaseMirroringInventory_Console]
        (
            [Bereich] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
            [Objekt] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
            [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );

        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables]
                @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|databaseMirroring|sourceStatus|warnings',
                @MappingTable=N'#DatabaseMirroringInventory_Map',
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
                @CandidateTable=N'#DatabaseMirroringInventory_Candidates',
                @WarningTable=N'#DatabaseMirroringInventory_SelectionWarnings';
            SELECT @SelectionError=MIN(CASE WHEN [StatusCode] IS NOT NULL THEN 51011 END)
            FROM [#DatabaseMirroringInventory_SelectionWarnings];
            INSERT [#DatabaseMirroringInventory_sourceStatus]
            SELECT NULL,[RequestedName],'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   COALESCE([StatusCode],'AVAILABLE_LIMITED'),
                   CASE WHEN [StatusCode] IS NULL THEN 'VISIBLE_ONLY' ELSE 'UNPROVEN' END,
                   NULL,NULL,0,
                   CASE WHEN [StatusCode] IS NULL THEN NULL ELSE 51011 END,
                   [ErrorMessage]
            FROM [#DatabaseMirroringInventory_SelectionWarnings];
            INSERT [#DatabaseMirroringInventory_warnings]
            SELECT NULL,[RequestedName],'TARGET_SELECTION','DATABASE_SELECTION',
                   LEFT(COALESCE([ErrorMessage],N'Die angeforderte Datenbank ist nicht verfügbar.'),1000)
            FROM [#DatabaseMirroringInventory_SelectionWarnings];
            IF COALESCE(@SelectionStatus,'')<>'AVAILABLE'
            BEGIN
                SET @Error=COALESCE(@SelectionError,51011);
                SET @Message=COALESCE(@SelectionMessage,N'Die Datenbankauswahl konnte nicht erstellt werden.');
                SET @Status=COALESCE(@SelectionStatus,'SELECTION_UNAVAILABLE');
                IF NOT EXISTS(SELECT 1 FROM [#DatabaseMirroringInventory_sourceStatus]
                              WHERE [SourceKey]='DATABASE_SELECTION')
                    INSERT [#DatabaseMirroringInventory_sourceStatus]
                    VALUES(NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                           @Status,'UNPROVEN',NULL,NULL,0,@Error,@Message);
            END
            ELSE
            BEGIN
                SELECT @Observed=COUNT_BIG(*) FROM [#DatabaseMirroringInventory_Candidates];
                INSERT [#DatabaseMirroringInventory_sourceStatus]
                VALUES(NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                       'AVAILABLE_LIMITED','CALLER_VISIBLE',@Observed,@Observed,0,NULL,NULL);
            END;
        END TRY
        BEGIN CATCH
            SET @Error=ERROR_NUMBER();
            SET @Message=LEFT(ERROR_MESSAGE(),2048);
            SET @Status=CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                             WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
            INSERT [#DatabaseMirroringInventory_sourceStatus]
            VALUES(NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   @Status,'UNPROVEN',NULL,NULL,0,@Error,@Message);
            INSERT [#DatabaseMirroringInventory_warnings]
            VALUES(NULL,NULL,'SOURCE_UNAVAILABLE','DATABASE_SELECTION',
                   N'Die Datenbankauswahl ist fehlgeschlagen; es wurde keine Mirroring-Quelle als erfolgreich leer ausgewertet.');
        END CATCH;

        IF @Error IS NULL
        BEGIN
            SET @Started=SYSUTCDATETIME();
            SET LOCK_TIMEOUT 0;
            BEGIN TRY
                INSERT [#DatabaseMirroringInventory_databaseMirroring]
                (
                    [DatabaseId],[DatabaseName],[MirroringState],[MirroringStateDesc],
                    [MirroringRole],[MirroringRoleDesc],[MirroringSafetyLevel],
                    [MirroringSafetyLevelDesc],[MirroringWitnessState],
                    [MirroringWitnessStateDesc],[ConfiguredRedoQueueLimitMb],
                    [RedoQueueLimitType]
                )
                SELECT [c].[DatabaseId],[c].[DatabaseName],
                       [m].[mirroring_state],[m].[mirroring_state_desc],
                       [m].[mirroring_role],[m].[mirroring_role_desc],
                       [m].[mirroring_safety_level],[m].[mirroring_safety_level_desc],
                       [m].[mirroring_witness_state],[m].[mirroring_witness_state_desc],
                       [m].[mirroring_redo_queue],[m].[mirroring_redo_queue_type]
                FROM [#DatabaseMirroringInventory_Candidates] AS [c]
                INNER JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
                    ON [d].[database_id]=[c].[DatabaseId]
                   AND [d].[name] COLLATE SQL_Latin1_General_CP1_CS_AS
                       =[c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                LEFT JOIN [master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)
                    ON [m].[database_id]=[d].[database_id];
                SET @Observed=@@ROWCOUNT;
                SET @SourceAvailable=1;
                SELECT @Returned=COUNT_BIG(*) FROM [#DatabaseMirroringInventory_databaseMirroring];
                INSERT [#DatabaseMirroringInventory_sourceStatus]
                VALUES(NULL,NULL,'DATABASE_MIRRORING_CATALOG','NATIVE',@Started,SYSUTCDATETIME(),
                       'AVAILABLE_LIMITED','CALLER_VISIBLE',@Observed,@Returned,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#DatabaseMirroringInventory_databaseMirroring];
                SET @Error=ERROR_NUMBER();
                SET @Message=LEFT(ERROR_MESSAGE(),2048);
                SET @Status=CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                                 WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END;
                INSERT [#DatabaseMirroringInventory_sourceStatus]
                VALUES(NULL,NULL,'DATABASE_MIRRORING_CATALOG','NATIVE',@Started,SYSUTCDATETIME(),
                       @Status,'UNPROVEN',NULL,NULL,0,@Error,@Message);
                INSERT [#DatabaseMirroringInventory_warnings]
                VALUES(NULL,NULL,'SOURCE_UNAVAILABLE','DATABASE_MIRRORING_CATALOG',
                       N'Die Mirroring-Katalogquelle konnte nicht gelesen werden; leere Ergebniszeilen belegen keine Abwesenheit.');
            END CATCH;
        END;

        IF @SourceAvailable=1
        BEGIN
            ;WITH [Bounded] AS
            (
                SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId]) AS [OutputOrdinal]
                FROM [#DatabaseMirroringInventory_databaseMirroring]
            )
            DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
            SELECT @Returned=COUNT_BIG(*) FROM [#DatabaseMirroringInventory_databaseMirroring];
            UPDATE [#DatabaseMirroringInventory_sourceStatus]
               SET [ReturnedRows]=@Returned,
                   [IsLimited]=CASE WHEN [ObservedRows]>@Returned THEN 1 ELSE 0 END
             WHERE [SourceKey]='DATABASE_MIRRORING_CATALOG';
        END;

        INSERT [#DatabaseMirroringInventory_warnings]
        VALUES(NULL,NULL,'METADATA_COMPLETENESS_UNPROVEN','DATABASE_MIRRORING_CATALOG',
               N'Ausgabe beschränkt sich auf caller-sichtbare Online-Datenbanken; eingeschränkte Metadatensicht beweist keine globale Abwesenheit.');
        INSERT [#DatabaseMirroringInventory_warnings]
        VALUES(NULL,NULL,'MIRRORING_NULLS_UNINTERPRETED','DATABASE_MIRRORING_CATALOG',
               N'Native NULL-Werte bleiben unverändert und unterscheiden nicht zwischen nicht gespiegelten, nicht verfügbaren oder nicht sichtbaren Zuständen.');
        INSERT [#DatabaseMirroringInventory_warnings]
        VALUES(NULL,NULL,'ROLE_VISIBILITY_LIMIT','DATABASE_MIRRORING_CATALOG',
               N'Der ONLINE-Selektor schließt nicht online befindliche Datenbanken aus; ein Mirror-Rollenwert für eine Restoring-Datenbank wird durch diesen Umfang nicht qualifiziert.');
        INSERT [#DatabaseMirroringInventory_warnings]
            SELECT NULL,NULL,'OUTPUT_LIMIT','DATABASE_MIRRORING_CATALOG',
                   N'Das Zeilenlimit begrenzt die Ausgabe; es garantiert keine Begrenzung der vorgelagerten Kataloglesearbeit.'
            WHERE EXISTS(SELECT 1 FROM [#DatabaseMirroringInventory_sourceStatus]
                         WHERE [SourceKey]='DATABASE_MIRRORING_CATALOG' AND [IsLimited]=1);

        IF @Error IS NULL
        BEGIN
            SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage],@Status=[StatusCode]
            FROM [#DatabaseMirroringInventory_sourceStatus]
            WHERE [ErrorNumber] IS NOT NULL
            ORDER BY [SourceKey],[DatabaseId],[DatabaseName];
        END;
        IF @Error IS NULL SET @Status='AVAILABLE_LIMITED';
        DECLARE @BusinessRows bigint=(SELECT COUNT_BIG(*) FROM [#DatabaseMirroringInventory_databaseMirroring]);
        INSERT [#DatabaseMirroringInventory_moduleStatus]
        VALUES(N'USP_DatabaseMirroringInventory',@CapturedAtUtc,@Status,1,@BusinessRows,
               N'Caller-sichtbare Katalogwerte für ausgewählte Online-Datenbanken; keine vollständige Mirroring- oder Gesundheitsqualifikation.');

        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=
                (SELECT N'DatabaseMirroringInventory' AS [resultName],1 AS [schemaVersion],
                        @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],
                        CAST(1 AS bit) AS [isPartial],@Error AS [errorNumber],
                        @Message AS [errorMessage]
                 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=
                (SELECT * FROM [#DatabaseMirroringInventory_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_databaseMirroring nvarchar(max)=
                (SELECT * FROM [#DatabaseMirroringInventory_databaseMirroring] ORDER BY [DatabaseId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=
                (SELECT * FROM [#DatabaseMirroringInventory_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=
                (SELECT * FROM [#DatabaseMirroringInventory_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,
                N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),
                N',"databaseMirroring":',COALESCE(@Json_databaseMirroring,N'[]'),
                N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),
                N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;

        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#DatabaseMirroringInventory_moduleStatus];
            SELECT * FROM [#DatabaseMirroringInventory_databaseMirroring] ORDER BY [DatabaseId];
            SELECT * FROM [#DatabaseMirroringInventory_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey];
            SELECT * FROM [#DatabaseMirroringInventory_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [DatabaseMirroringOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable]
                FROM [#DatabaseMirroringInventory_Map] ORDER BY [ResultName];
            OPEN [DatabaseMirroringOutput];
            FETCH NEXT FROM [DatabaseMirroringOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#DatabaseMirroringInventory_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable]
                    @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @TableFailureError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [DatabaseMirroringOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [DatabaseMirroringOutput]; DEALLOCATE [DatabaseMirroringOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            INSERT [#DatabaseMirroringInventory_Console]
            SELECT N'Database Mirroring',[DatabaseName],
                   CONCAT(N'State=',COALESCE([MirroringStateDesc],N'NULL'),
                          N'; role=',COALESCE([MirroringRoleDesc],N'NULL'),
                          N'; safety=',COALESCE([MirroringSafetyLevelDesc],N'NULL'),
                          N'; witness=',COALESCE([MirroringWitnessStateDesc],N'NULL'),
                          N'; configured redo cap MB=',COALESCE(CONVERT(nvarchar(30),[ConfiguredRedoQueueLimitMb]),N'NULL'),
                          N'; cap type=',COALESCE([RedoQueueLimitType],N'NULL'))
            FROM [#DatabaseMirroringInventory_databaseMirroring];
            INSERT [#DatabaseMirroringInventory_Console]
            SELECT N'Quelle',[SourceKey],CONCAT([StatusCode],N'; sichtbar=',COALESCE([ObservedRows],0),
                    N'; ausgegeben=',COALESCE([ReturnedRows],0))
            FROM [#DatabaseMirroringInventory_sourceStatus];
            INSERT [#DatabaseMirroringInventory_Console]
            SELECT N'Aussagegrenze',[WarningCode],[Detail]
            FROM [#DatabaseMirroringInventory_warnings];
            EXEC [monitor].[InternalEmitConsoleResult]
                @SourceTable=N'#DatabaseMirroringInventory_Console',
                @ResultLabel=N'Sichtbare Database-Mirroring-Katalogwerte',
                @EmptyMessage=N'Keine caller-sichtbaren Katalogwerte; Quellenstatus und Aussagegrenzen beachten.';
        END;

        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_DatabaseMirroringInventory: mindestens eine Quelle ist nicht verfügbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@TableFailureError,ERROR_NUMBER()),
               @Message=LEFT(ERROR_MESSAGE(),2048),@Json=NULL;
        SELECT @Status='ERROR_HANDLED',@StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
