USE [DeineDatenbank];
GO

/*
Objekt       : monitor.USP_CurrentObjectPermissionAnalysis
Version      : 1.0.0
Stand        : 2026-11-16
Zweck        : Die Procedure zeigt native OBJECT-Rechte eines ausdruecklich
               benannten Schema-/Objektpaars je ausgewaehlter Datenbank im
               aktuellen Ausfuehrungskontext.
Grenzen      : Leere oder fehlerhafte Quellen beweisen keine Objektabwesenheit;
               der Bericht beweist keinen konkreten Statementzugriff.
Nebenwirkung : Keine persistenten Datenbank- oder Objektänderungen; lokale
               Temp-DDL dient der Aufbereitung. Keine Identitaetsaenderung.
Datenschutz  : Der Bericht erfragt keine SID- oder Tokenquellen. Native Namen
               und diagnostische Fehlermeldungen bleiben erhalten.
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentObjectPermissionAnalysis]
      @DatabaseNames nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit = 0
    , @DatabaseNamePattern nvarchar(4000) = NULL
    , @SchemaName nvarchar(max) = NULL
    , @ObjectName nvarchar(max) = NULL
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
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,@PreviousXactAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),@SetLock nvarchar(100),@Sql nvarchar(max),@IdentityGuard nvarchar(max),
        @Status varchar(40)='AVAILABLE_LIMITED',@Error int=NULL,@Message nvarchar(2048)=NULL,
        @FailureError int=NULL,@FailureStatus varchar(40)=NULL,@TableStatus varchar(40),@TableError int,@TableMessage nvarchar(2048),
        @Started datetime2(3),@Observed bigint,@DatabaseId int,@DatabaseName sysname,@QuotedDatabase nvarchar(258),
        @DatabaseCreatedAt datetime,@CrossDatabaseRequested bit,@QualifiedObject sysname,@QuotedSchema nvarchar(258),@QuotedObject nvarchar(258);
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_CurrentObjectPermissionAnalysis';
        PRINT N'Die Procedure liest native OBJECT-Rechte des aktuellen Aufrufers fuer ein ausdruecklich benanntes Schema-/Objektpaar je ausgewaehlter Datenbank. Sie wechselt keine Identitaet und liest keine Datenzeilen des Zielobjekts.';
        PRINT N'Ohne Datenbankfilter gelten sichtbare, ONLINE befindliche, zugaengliche Benutzerdatenbanken ohne Snapshots. Systemdatenbanken sind nur mit Opt-in enthalten. Leere oder fehlerhafte Objektquellen beweisen weder Objektabwesenheit noch fehlende Rechte.';
        PRINT N'RAW liefert fuenf benannte Mengen; TABLE schreibt die angeforderte Teilmenge, CONSOLE eine Ansicht und NONE keine Resultsets. JSON enthaelt meta und dieselben fuenf Arrays. Quellen sind getrennt und nicht atomar.';
        PRINT N'@DatabaseNames nvarchar(max); Default NULL. NULL, leer oder nur aeussere U+0020-Leerzeichen bedeuten keinen Listenfilter. Sonst bracket-aware Pipe-Liste einteiliger Datenbanknamen; exakte case-sensitive Namen, doppelte Namen ungueltig. Mit aktiver Liste muss @DatabaseNamePattern NULL sein. Nicht verfuegbare gueltige Namen erzeugen Auswahlwarnungen, keinen Abwesenheitsbeweis.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default 0. 0 schliesst Datenbank-IDs bis 4 aus, 1 erlaubt sie unter Sichtbarkeits-, ONLINE- und HAS_DBACCESS-Grenzen; NULL ist INVALID_PARAMETER. SQL konvertiert numerische 0 zu 0 und sonstige konvertierbare Nichtnullwerte zu 1.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default NULL. NULL bedeutet kein Pattern. LIKE, REGEX, REGEXI verwenden die gemeinsame Datenbankauswahl; leeres Pattern ist ungueltig, aktive nichtleere Namensliste und Pattern sind unvereinbar. REGEX und REGEXI verlangen SQL Server 2025/Compatibility Level 170 in der Installationsdatenbank. Regexsyntaxfehler werden im Auswahlpfad sichtbar.';
        PRINT N'@SchemaName nvarchar(max); Default NULL. Im regulären Pfad ist genau ein nichtleerer, nicht nur aus U+0020 bestehender Schemaname erforderlich; keine Liste oder Wildcard. SQL bindet Text ohne numerische Sonderdeutung. Der Rohwert wird nicht still gekuerzt oder getrimmt; maximal 128 UTF-16-Codeeinheiten vor QUOTENAME.';
        PRINT N'@ObjectName nvarchar(max); Default NULL. Im regulären Pfad ist genau ein nichtleerer, nicht nur aus U+0020 bestehender Objektname erforderlich; keine Liste oder Wildcard. Der Rohwert wird nicht still gekuerzt oder getrimmt; maximal 128 UTF-16-Codeeinheiten vor QUOTENAME. Der qualifizierte Name muss insgesamt in sysname passen, sonst INVALID_PARAMETER.';
        PRINT N'@MaxZeilen int; Default 1000. NULL oder 0 ist unbegrenzt, negative Werte sind INVALID_PARAMETER. Positiv begrenzt OBJECT-Rechte global nach DatabaseId, EntityName, SubentityName und PermissionName erst nach allen Quellenlesungen. ObservedRows und ReturnedRows bleiben getrennt; Kontext, Status und Warnungen werden nicht gekappt.';
        PRINT N'@LockTimeoutMs int; Default 0. 0 bis 60000 Millisekunden, NULL und andere Werte INVALID_PARAMETER. Dynamische Quellen verwenden diesen Wert; 0 ist NOWAIT. Vorbereitende Temp-DDL erhaelt bei eingehendem LOCK_TIMEOUT 0 bis zu 1000 ms. Der Callerwert wird auf allen Pfaden wiederhergestellt, ohne Gesamtzeitgarantie.';
        PRINT N'@ResultSetArt varchar(16); Default CONSOLE. Nach aeusserem U+0020-Trim/UPPER sind nur CONSOLE, RAW, TABLE und NONE gueltig; NULL/leer sind ungueltig. CONSOLE zeigt eine beschriftete Sicht, RAW fuenf Mengen, TABLE angeforderte lokale Ziele, NONE keine fachliche Menge. JSON ist unabhaengig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default NULL. Ausserhalb TABLE sind nur NULL/leer/U+0020 erlaubt. Bei TABLE erwartet der gemeinsame Helper mindestens eine eindeutige Zuordnung aus moduleStatus, callerContexts, objectPermissions, sourceStatus und warnings zu vorhandenen leeren lokalen #Temp-Zielen mit genau einer Seed-Spalte; keine Duplikate, keine ##- oder #Monitor*-Ziele, Namen hoechstens 116 Zeichen. Ablehnung vor Quellenzugriff ergibt ERROR_HANDLED/51011 und JSON NULL.';
        PRINT N'@JsonErzeugen bit; Default 0. Nur 1 erzeugt JSON in @Json, unabhaengig vom Resultmodus; 0 oder NULL erzeugt keines. meta und fuenf Arrays behalten NULL-Felder. SQL konvertiert numerische 0 zu 0 und sonstige konvertierbare Nichtnullwerte zu 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default NULL. Optionaler OUTPUT-Empfaenger, mit OUTPUT binden. Beim Eintritt, bei Hilfe, Validierungsfehler und aeusserem Fehler NULL; nur bei regulärem Pfad und @JsonErzeugen=1 gesetzt.';
        PRINT N'@PrintMeldungen bit; Default 1. 1 erlaubt niedrige NOWAIT-Diagnosemeldungen, 0 unterdrueckt sie; NULL aktiviert sie nicht. Hilfe druckt unabhaengig. SQL konvertiert numerische 0 zu 0 und sonstige konvertierbare Nichtnullwerte zu 1.';
        PRINT N'@Hilfe bit; Default 0. 1 druckt diese Hilfe und liefert AVAILABLE/IsPartial=0/RETURN 0 vor TABLE- oder Quellenpruefung; JSON und Fehlerausgaben bleiben NULL. 0 oder NULL setzt den Normalpfad fort.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default NULL. Optionaler Empfaenger mit OUTPUT. Hilfe AVAILABLE, Parameter INVALID_PARAMETER, Auswahlfehler deren Status. Normal AVAILABLE_LIMITED bei mindestens einer nichtleeren OBJECT-Quelle, sonst EMPTY_UNPROVEN bei erfolgreicher leerer Quelle, sonst erster nativer Fehler nach DatabaseId, sonst NO_TARGETS. Quellenfehler aendern RETURN 0 nicht; pruefen Sie sourceStatus.';
        PRINT N'@IsPartialOut bit OUTPUT; Default NULL. Optionaler Empfaenger mit OUTPUT. Hilfe 0; Validierung, regulärer Bericht und aeusserer Fehler 1. Caller-Sicht, leere Quellen, Outputlimit und getrennte Zeitpunkte begrenzen die Aussage.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default NULL. Optionaler Empfaenger mit OUTPUT. Hilfe NULL, Validierung 51011, sonst erste native Fehlernummer nach DatabaseId/SourceKey oder NULL; aeusserer Fehler gibt den vorbereiteten oder abgefangenen Code.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default NULL. Optionaler Empfaenger mit OUTPUT. Hilfe NULL, Validierung feste Diagnose, sonst erste native Fehlermeldung nach DatabaseId/SourceKey oder NULL; aeussere Fehler bleiben diagnostisch erhalten.';
        PRINT N'EXEC [monitor].[USP_CurrentObjectPermissionAnalysis] @SchemaName=N''dbo'',@ObjectName=N''Probe'',@ResultSetArt=''RAW'';';
        PRINT N'EXEC [monitor].[USP_CurrentObjectPermissionAnalysis] @Hilfe=1;';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN 0;
    END;
    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0 OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR @SystemdatenbankenEinbeziehen IS NULL OR @SchemaName IS NULL OR @ObjectName IS NULL
       OR DATALENGTH(@SchemaName)=0 OR DATALENGTH(@ObjectName)=0
       OR DATALENGTH(@SchemaName)>256 OR DATALENGTH(@ObjectName)>256
       OR NULLIF(LTRIM(RTRIM(@SchemaName)),N'') IS NULL OR NULLIF(LTRIM(RTRIM(@ObjectName)),N'') IS NULL
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungueltiger Ausgabe-, Auswahl-, Limit-, Locktimeout- oder TABLE-Parameter.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;
    SELECT @QuotedSchema=QUOTENAME(CONVERT(sysname,@SchemaName)),@QuotedObject=QUOTENAME(CONVERT(sysname,@ObjectName));
    IF @QuotedSchema IS NULL OR @QuotedObject IS NULL OR DATALENGTH(@QuotedSchema+N'.'+@QuotedObject)>256
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der qualifizierte Objektname ueberschreitet die native sysname-Grenze.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;
    SET @QualifiedObject=CONVERT(sysname,@QuotedSchema+N'.'+@QuotedObject);
    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @PreviousLockTimeout=0 SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#CurrentObjectPermissionAnalysis_moduleStatus]
        (
[ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [RequestedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [RequestedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [RowCount] bigint NOT NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#CurrentObjectPermissionAnalysis_callerContexts]
        (
[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [ContextDatabaseId] int NOT NULL,
    [ServerPrincipalId] int NULL,
    [DatabasePrincipalId] int NULL,
    [ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL
        );
        CREATE TABLE [#CurrentObjectPermissionAnalysis_objectPermissions]
        (
[DatabaseId] int NOT NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [RequestedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [RequestedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#CurrentObjectPermissionAnalysis_sourceStatus]
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
        CREATE TABLE [#CurrentObjectPermissionAnalysis_warnings]
        (
[DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#CurrentObjectPermissionAnalysis_Candidates]
        (

        [DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsReadOnly] bit NULL,
        [CompatibilityLevel] tinyint NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL

        );
        CREATE TABLE [#CurrentObjectPermissionAnalysis_SelectionWarnings]
        (
[RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#CurrentObjectPermissionAnalysis_Map]
        (
[ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#CurrentObjectPermissionAnalysis_NativeObject]
        ([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RequestedSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RequestedObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|callerContexts|objectPermissions|sourceStatus|warnings',
                @MappingTable=N'#CurrentObjectPermissionAnalysis_Map',@StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN SET @FailureError=51011;RAISERROR(N'%s',16,1,@TableMessage);END;
        END;
        SET @Started=SYSUTCDATETIME();
        EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,
            @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,
            @StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,
            @CandidateTable=N'#CurrentObjectPermissionAnalysis_Candidates',@WarningTable=N'#CurrentObjectPermissionAnalysis_SelectionWarnings';
        IF COALESCE(@TableStatus,'')<>'AVAILABLE'
        BEGIN SELECT @FailureError=51011,@FailureStatus=COALESCE(@TableStatus,'STATUS_UNAVAILABLE');RAISERROR(N'%s',16,1,@TableMessage);END;
        INSERT [#CurrentObjectPermissionAnalysis_sourceStatus] VALUES
            (NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),'AVAILABLE','CURRENT_SELECTION',
             (SELECT COUNT_BIG(*) FROM [#CurrentObjectPermissionAnalysis_Candidates]),(SELECT COUNT_BIG(*) FROM [#CurrentObjectPermissionAnalysis_Candidates]),0,NULL,NULL);
        INSERT [#CurrentObjectPermissionAnalysis_sourceStatus]
            SELECT NULL,[RequestedName],'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   COALESCE([StatusCode],'STATUS_UNAVAILABLE'),'UNPROVEN',NULL,NULL,0,NULL,[ErrorMessage]
            FROM [#CurrentObjectPermissionAnalysis_SelectionWarnings];
        INSERT [#CurrentObjectPermissionAnalysis_warnings]
            SELECT NULL,[RequestedName],'TARGET_SELECTION','DATABASE_SELECTION',LEFT(COALESCE([ErrorMessage],N'Kein verfuegbarer Zielkontext.'),1000)
            FROM [#CurrentObjectPermissionAnalysis_SelectionWarnings];
        SET LOCK_TIMEOUT 0;
        SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; ';
        -- TARGET_IDENTITY_GUARD_BEGIN
        SET @IdentityGuard=N'IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [sys].[databases] WITH (NOLOCK)
            WHERE [database_id]=DB_ID() AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS AND [create_date]=@Created)
            THROW 51012,N''Target database identity changed or is not available for this source.'',1; ';
        -- TARGET_IDENTITY_GUARD_END
        DECLARE [CurrentObjectPermissionTargets] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName] FROM [#CurrentObjectPermissionAnalysis_Candidates] ORDER BY [DatabaseId];
        OPEN [CurrentObjectPermissionTargets];FETCH NEXT FROM [CurrentObjectPermissionTargets] INTO @DatabaseId,@DatabaseName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT @QuotedDatabase=QUOTENAME(@DatabaseName),@DatabaseCreatedAt=NULL;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'SELECT @Created=[create_date] FROM [master].[sys].[databases] WITH (NOLOCK)
                    WHERE [database_id]=@Id AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS;';
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime OUTPUT',@Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt OUTPUT;
                IF @DatabaseCreatedAt IS NULL THROW 51012,N'Target database context is not available.',1;
                INSERT [#CurrentObjectPermissionAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',1,1,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                INSERT [#CurrentObjectPermissionAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER()=51012 THEN 'DATABASE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            IF @DatabaseCreatedAt IS NOT NULL
            BEGIN
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'DECLARE @ContextDb int=DB_ID(),@ContextServer int=SUSER_ID(),@ContextUser int=DATABASE_PRINCIPAL_ID(),@ContextAt datetime2(3)=SYSUTCDATETIME(); INSERT [#CurrentObjectPermissionAnalysis_NativeObject] SELECT @Id,@Name,@SchemaParam,@ObjectParam,[entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name]) FROM [sys].[fn_my_permissions](@TargetObject,N''OBJECT''); SET @Rows=(SELECT COUNT_BIG(*) FROM [#CurrentObjectPermissionAnalysis_NativeObject] WHERE [DatabaseId]=@Id); IF EXISTS(SELECT 1 FROM [#CurrentObjectPermissionAnalysis_NativeObject] WHERE [DatabaseId]=@Id AND ([PermissionName] IS NULL OR LEN(LTRIM(RTRIM([PermissionName])))=0)) THROW 51014,N''Native source returned an unusable permission name.'',1; IF EXISTS(SELECT @ContextDb,@ContextServer,@ContextUser EXCEPT SELECT DB_ID(),SUSER_ID(),DATABASE_PRINCIPAL_ID()) THROW 51013,N''Current execution-context identifiers changed during the source read.'',1; '+@IdentityGuard+N'INSERT [#CurrentObjectPermissionAnalysis_objectPermissions] SELECT * FROM [#CurrentObjectPermissionAnalysis_NativeObject] WHERE [DatabaseId]=@Id; INSERT [#CurrentObjectPermissionAnalysis_callerContexts] VALUES (N''OBJECT_CURRENT_PERMISSIONS'',@Id,@Name,@ContextDb,@ContextServer,@ContextUser,CASE WHEN @ContextServer IS NOT NULL AND @ContextUser IS NOT NULL THEN N''CAPTURED_CURRENT_IDS'' ELSE N''PARTIAL_CURRENT_IDS'' END,@ContextAt);';
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@SchemaParam sysname,@ObjectParam sysname,@TargetObject sysname,@Rows bigint OUTPUT',@Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@SchemaParam=@SchemaName,@ObjectParam=@ObjectName,@TargetObject=@QualifiedObject,@Rows=@Observed OUTPUT;
                INSERT [#CurrentObjectPermissionAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'OBJECT_CURRENT_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END,'CURRENT_CONTEXT_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#CurrentObjectPermissionAnalysis_NativeObject] WHERE [DatabaseId]=@DatabaseId;
                DELETE FROM [#CurrentObjectPermissionAnalysis_objectPermissions] WHERE [DatabaseId]=@DatabaseId;
                DELETE FROM [#CurrentObjectPermissionAnalysis_callerContexts] WHERE [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [DatabaseId]=@DatabaseId;
                INSERT [#CurrentObjectPermissionAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'OBJECT_CURRENT_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
        END
        ELSE
            INSERT [#CurrentObjectPermissionAnalysis_sourceStatus] VALUES
                (@DatabaseId,@DatabaseName,'OBJECT_CURRENT_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),'SKIPPED','UNPROVEN',NULL,NULL,0,NULL,N'DATABASE_CONTEXT is not available; the permission function was not called.');
            FETCH NEXT FROM [CurrentObjectPermissionTargets] INTO @DatabaseId,@DatabaseName;
        END;
        CLOSE [CurrentObjectPermissionTargets];DEALLOCATE [CurrentObjectPermissionTargets];
        ;WITH [Ranked] AS (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[EntityName],[SubentityName],[PermissionName]) AS [OutputRank] FROM [#CurrentObjectPermissionAnalysis_objectPermissions]) DELETE FROM [Ranked] WHERE [OutputRank]>@Limit;
        UPDATE [s] SET [ReturnedRows]=(SELECT COUNT_BIG(*) FROM [#CurrentObjectPermissionAnalysis_objectPermissions] AS [p] WHERE [p].[DatabaseId]=[s].[DatabaseId])
        FROM [#CurrentObjectPermissionAnalysis_sourceStatus] AS [s]
        WHERE [s].[SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [s].[ObservedRows] IS NOT NULL;
        UPDATE [#CurrentObjectPermissionAnalysis_sourceStatus] SET [IsLimited]=1 WHERE [ReturnedRows]<[ObservedRows];
        INSERT [#CurrentObjectPermissionAnalysis_warnings] VALUES
            (NULL,NULL,'CURRENT_CONTEXT_BOUNDARY',NULL,N'Die native Bewertung gilt nur fuer den aktuellen Ausfuehrungskontext; erfasste IDs sind kein vollstaendiger Token- oder Daueridentitaetsnachweis.'),
            (NULL,NULL,'SECURABLE_LEVEL_BOUNDARY',NULL,N'OBJECT-Rechte und native Spaltenbezeichnungen beweisen keinen konkreten Statementzugriff oder vollstaendige Spaltenrechte. Getrennte Quellen sind kein atomarer Snapshot.');
        INSERT [#CurrentObjectPermissionAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'OUTPUT_LIMIT',[SourceKey],N'Die fachliche Rechtemenge wurde global gekuerzt; erfasste Kontext- und Quellenzeilen bleiben erhalten.'
            FROM [#CurrentObjectPermissionAnalysis_sourceStatus] WHERE [IsLimited]=1;
        INSERT [#CurrentObjectPermissionAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'EMPTY_PERMISSION_SOURCE_UNPROVEN',[SourceKey],N'Die native Funktion lieferte keine Zeile; dies beweist keine fehlenden Rechte.'
            FROM [#CurrentObjectPermissionAnalysis_sourceStatus] WHERE [StatusCode]='EMPTY_UNPROVEN';
        INSERT [#CurrentObjectPermissionAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'PARTIAL_CONTEXT_IDENTIFIERS',[SourceKey],N'Mindestens eine native Principal-ID ist NULL. Die IDs beschreiben nicht die gesamte wirksame Sicherheitsidentitaet.'
            FROM [#CurrentObjectPermissionAnalysis_callerContexts] WHERE [ContextStatus]='PARTIAL_CURRENT_IDS';
        INSERT [#CurrentObjectPermissionAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'SOURCE_FAILURE',[SourceKey],LEFT(COALESCE([ErrorMessage],N'Die Quelle ist nicht verfuegbar.'),1000)
            FROM [#CurrentObjectPermissionAnalysis_sourceStatus] WHERE [SourceKind]='NATIVE'
              AND [StatusCode] NOT IN ('AVAILABLE_LIMITED','EMPTY_UNPROVEN','SKIPPED');
        IF NOT EXISTS(SELECT 1 FROM [#CurrentObjectPermissionAnalysis_sourceStatus]
                      WHERE [SourceKey]='OBJECT_CURRENT_PERMISSIONS' AND [StatusCode]='AVAILABLE_LIMITED')
        BEGIN
            IF EXISTS(SELECT 1 FROM [#CurrentObjectPermissionAnalysis_sourceStatus] WHERE [StatusCode]='EMPTY_UNPROVEN') SET @Status='EMPTY_UNPROVEN';
            ELSE
            BEGIN
                SET @Status='NO_TARGETS';
                SELECT TOP (1) @Status=[StatusCode] FROM [#CurrentObjectPermissionAnalysis_sourceStatus]
                WHERE [SourceKind]='NATIVE' AND [StatusCode] NOT IN ('AVAILABLE_LIMITED','EMPTY_UNPROVEN','SKIPPED') ORDER BY [DatabaseId],[SourceKey];
            END;
        END;
        SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage]
        FROM [#CurrentObjectPermissionAnalysis_sourceStatus] WHERE [ErrorNumber] IS NOT NULL ORDER BY [DatabaseId],[SourceKey];
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#CurrentObjectPermissionAnalysis_objectPermissions]);
        INSERT [#CurrentObjectPermissionAnalysis_moduleStatus] VALUES
            (N'USP_CurrentObjectPermissionAnalysis',@SchemaName,@ObjectName,@CapturedAtUtc,@Status,1,@Rows,N'Native OBJECT-Rechte fuer ein ausdruecklich benanntes Paar je ausgewaehlter Datenbank im aktiven Caller-Kontext. Keine Statement- oder vollstaendige Spaltenanalyse.');
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'CurrentObjectPermissionAnalysis' AS [resultName],1 AS [schemaVersion],
                @CapturedAtUtc AS [generatedAtUtc],@SchemaName AS [requestedSchemaName],@ObjectName AS [requestedObjectName],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],@Error AS [errorNumber],@Message AS [errorMessage]
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#CurrentObjectPermissionAnalysis_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_callerContexts nvarchar(max)=(SELECT * FROM [#CurrentObjectPermissionAnalysis_callerContexts] ORDER BY [DatabaseId],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_objectPermissions nvarchar(max)=(SELECT * FROM [#CurrentObjectPermissionAnalysis_objectPermissions] ORDER BY [DatabaseId],[EntityName],[SubentityName],[PermissionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#CurrentObjectPermissionAnalysis_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#CurrentObjectPermissionAnalysis_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"callerContexts":',COALESCE(@Json_callerContexts,N'[]'),N',"objectPermissions":',COALESCE(@Json_objectPermissions,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#CurrentObjectPermissionAnalysis_moduleStatus];
            SELECT * FROM [#CurrentObjectPermissionAnalysis_callerContexts] ORDER BY [DatabaseId],[SourceKey];
            SELECT * FROM [#CurrentObjectPermissionAnalysis_objectPermissions] ORDER BY [DatabaseId],[EntityName],[SubentityName],[PermissionName];
            SELECT * FROM [#CurrentObjectPermissionAnalysis_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey];
            SELECT * FROM [#CurrentObjectPermissionAnalysis_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [CurrentObjectPermissionOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable] FROM [#CurrentObjectPermissionAnalysis_Map] ORDER BY [ResultName];
            OPEN [CurrentObjectPermissionOutput];FETCH NEXT FROM [CurrentObjectPermissionOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#CurrentObjectPermissionAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN SET @FailureError=COALESCE(@TableError,51010);RAISERROR(N'%s',16,1,@TableMessage);END;
                FETCH NEXT FROM [CurrentObjectPermissionOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [CurrentObjectPermissionOutput];DEALLOCATE [CurrentObjectPermissionOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            CREATE TABLE [#CurrentObjectPermissionAnalysis_Console]
            ([Scope] varchar(8) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
             [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
             [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
             [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
            INSERT [#CurrentObjectPermissionAnalysis_Console]
                SELECT 'OBJECT',[DatabaseId],[DatabaseName],[EntityName],[SubentityName],[PermissionName],@Status,'OBJECT_CURRENT_PERMISSIONS',NULL,NULL FROM [#CurrentObjectPermissionAnalysis_objectPermissions];
            INSERT [#CurrentObjectPermissionAnalysis_Console]
                SELECT 'SOURCE',[DatabaseId],[DatabaseName],NULL,NULL,NULL,[StatusCode],[SourceKey],NULL,
                       COALESCE([ErrorMessage],N'Diese Quellenmenge ist nicht als vollstaendige erfolgreiche Rechtebewertung belegt.')
                FROM [#CurrentObjectPermissionAnalysis_sourceStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED');
            INSERT [#CurrentObjectPermissionAnalysis_Console]
                SELECT CASE WHEN [WarningCode] IN ('CURRENT_CONTEXT_BOUNDARY','SECURABLE_LEVEL_BOUNDARY') THEN 'INFO' ELSE 'WARNING' END,
                       [DatabaseId],[DatabaseName],NULL,NULL,NULL,CASE WHEN [WarningCode] IN ('CURRENT_CONTEXT_BOUNDARY','SECURABLE_LEVEL_BOUNDARY') THEN 'INFO' ELSE 'WARNING' END,[SourceKey],[WarningCode],[Detail]
                FROM [#CurrentObjectPermissionAnalysis_warnings] WHERE [WarningCode] NOT IN ('SOURCE_FAILURE','EMPTY_PERMISSION_SOURCE_UNPROVEN','TARGET_SELECTION');
            IF NOT EXISTS(SELECT 1 FROM [#CurrentObjectPermissionAnalysis_objectPermissions])
                INSERT [#CurrentObjectPermissionAnalysis_Console] VALUES ('STATUS',NULL,NULL,NULL,NULL,NULL,@Status,NULL,NULL,N'Keine ausgegebene Rechtezeile; Quellenstatus und Warnungen liefern die Aussagegrenze.');
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#CurrentObjectPermissionAnalysis_Console',
                @ResultLabel=N'Native OBJECT-Rechte des aktuellen Ausfuehrungskontexts',
                @EmptyMessage=N'Keine ausgegebene Rechtezeile; Quellenstatus und Warnungen beachten.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        RETURN 0;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@FailureError,ERROR_NUMBER()),@Message=ERROR_MESSAGE(),@Status=COALESCE(@FailureStatus,'ERROR_HANDLED'),@Json=NULL;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
