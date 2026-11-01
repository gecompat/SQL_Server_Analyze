USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_RowLevelSecurityAndMaskingInventory
Version      : 1.0.0
Stand        : 2026-10-26
Zweck        : Die Procedure inventarisiert sichtbare RLS-Policies, Predicate-Metadaten und Masked Columns.
Grenzen      : Getrennte lokale Katalogaufnahmen im Ausführungskontext des Callers; eingeschränkte Metadatensicht, Abdeckung und Richtlinienwirksamkeit bleiben unbewiesen.
Datenschutz  : Keine Predicate-Definitionen, Maskingfunktionen oder Tabellenwerte.
Nebenwirkung : Rein lesend; keine Berechtigungs- oder Policyaenderung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_RowLevelSecurityAndMaskingInventory]
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
    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,
        @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),@SetLock nvarchar(100),@Sql nvarchar(max),@IdentityGuard nvarchar(max),@DatabaseCreatedAt datetime,
        @Status varchar(40)='AVAILABLE_LIMITED',@Error int=NULL,@Message nvarchar(2048)=NULL,
        @FailureError int=NULL,@FailureStatus varchar(40)=NULL,
        @TableStatus varchar(40),@TableError int,@TableMessage nvarchar(2048),
        @Started datetime2(3),@Observed bigint,@DatabaseId int,@DatabaseName sysname,@QuotedDatabase nvarchar(258),
        @ContextAvailable bit,@ContextStatus varchar(40),@StateDescription nvarchar(60),@ContainmentDescription nvarchar(60),@CrossDatabaseRequested bit,@PolicyFieldAvailable bit;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_RowLevelSecurityAndMaskingInventory';
        PRINT N'Sichtbare RLS-Policies, Predicate-Metadaten und Masked Columns aus lokalen Katalogen der ausgewählten Datenbanken im aktuellen Ausführungskontext.';
        PRINT N'Die Aufnahme liest keine Tabellenwerte, Predicate-Definitionen oder Maskingfunktionen und bewertet weder Richtlinienwirksamkeit noch vollständige Metadatensicht.';
        PRINT N'RAW und JSON enthalten moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus und warnings; TABLE schreibt nur die angeforderte gemappte Teilmenge; CONSOLE zeigt Policies, Kontext, Quellenstatus und Warnungen.';
        PRINT N'@Hilfe=1 setzt AVAILABLE und IsPartial=0, lässt Fehler- und JSON-OUTPUTs NULL und endet mit Rückgabecode 0.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. NULL, leerer Text oder nur äußere U+0020-Leerzeichen heben den exakten Filter auf. Eine aktive Pipe-Liste enthält einfache SQL-Namen; Pipes innerhalb bracket-quotierter Elemente bleiben Inhalt, ]] maskiert dort eine schließende Klammer. Der Parser trimmt Elementränder und prüft Struktur. Leere Elemente, ungültige Klammern, Rohsegmente über 4000 UTF-16-Codeeinheiten, ungültige PARSENAME-Teil-1-Werte, vorhandene Teil 2, Namen mit LEN über 128 sowie Duplikate werden abgewiesen. Eine aktive Liste ist mit jedem nicht-NULL-Pattern unzulässig. Kandidaten müssen sichtbar, ONLINE und mit HAS_DBACCESS zugreifbar sein; Snapshots und standardmäßig Systemdatenbanken werden ausgeschlossen. Nicht verfügbare explizite Namen erzeugen Auswahlwarnungen.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 1 nimmt Systemdatenbanken mit database_id bis einschließlich 4 auf; 0 schließt IDs bis 4 aus. NULL wird vom Auswahlhelfer als INVALID_PARAMETER zurückgewiesen. Der Schalter ändert keine Metadatensicht und prüft keine Berechtigungen. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Nur NULL bedeutet kein Pattern. Ein nicht-NULL-Leertext, nur U+0020-Leerzeichen und leere LIKE:/REGEX:/REGEXI:-Inhalte sind INVALID_PARAMETER. Ein nicht-NULL-Pattern ist mit aktiver @DatabaseNames-Liste unzulässig. Der Parser trimmt zuerst außen und entfernt danach höchstens eines der Präfixe regexi:, regex: oder like: ohne erneutes Trimmen. Ohne Präfix gilt LIKE; leerer Rest ist ungültig. LIKE wird case-sensitive angewandt. regex: arbeitet case-sensitiv mit Flag c und regexi: ohne Beachtung der Groß-/Kleinschreibung mit Flag i; der Auswahlhelfer wertet diese Modi mit REGEXP_LIKE aus und verlangt SQL Server 2025 (Major Version 17) sowie Compatibility Level 170 der Installationsdatenbank. Fehlt die Voraussetzung, löscht er Kandidaten und liefert UNAVAILABLE_FEATURE. LIKE-Inhalte verwenden SQL-LIKE-Syntax (% beliebige Folge, _ ein Zeichen, [...] Zeichenklasse; keine eigene ESCAPE-Klausel). Regexinhalte werden unverändert an REGEXP_LIKE übergeben, ohne Syntaxvorprüfung; eine fehlerhafte Regex kann erst bei der Ausführung scheitern.';
        PRINT N'@MaxZeilen int; Default: 1000. NULL und 0 bedeuten unbegrenzt. 1 bis 2147483647 begrenzt jeweils securityPolicies, securityPredicates und maskedColumns separat über alle ausgewählten Datenbanken; negative Werte liefern INVALID_PARAMETER und Fehlernummer 51011. Die Grenze wird nach allen Fachabfragen angewandt und begrenzt keine Quellarbeit. Sortierschlüssel: Policies DatabaseId/PolicyObjectId, Predicates DatabaseId/PolicyObjectId/PredicateId, Masked Columns DatabaseId/ObjectId/ColumnId. sourceStatus weist beobachtete und je Datenbank zurückgegebene Mengen aus; moduleStatus.RowCount summiert zurückgegebene Fachzeilen.';
        PRINT N'@LockTimeoutMs int; Default: 0. Zulässig sind 0 bis einschließlich 60000 Millisekunden. NULL, negative Werte und Werte über 60000 liefern INVALID_PARAMETER mit 51011. Der Wert gilt je dynamischer Kontext- oder Katalogbatch; 0 bedeutet NOWAIT, positive Werte begrenzen eine jeweilige Sperrwartezeit, nicht die Gesamtdauer. Bei eingehendem LOCK_TIMEOUT 0 erhält eigene Temp-DDL vorübergehend 1000 ms; der TABLE-Helfer gewährt eigener Temp-DDL ebenfalls bis zu 1000 ms je Anlage und setzt anschließend 0. Am normalen Ende und im äußeren CATCH stellt der Aufrufer eingehenden LOCK_TIMEOUT und XACT_ABORT wieder her. Caller-Transaktion bleibt Caller-eigen; kein COMMIT oder ROLLBACK.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Der Wert wird mit leerem Fallback, äußerem U+0020-Trimmen und Großschreibung normalisiert. Genau CONSOLE, RAW, TABLE und NONE sind erlaubt; sonst INVALID_PARAMETER/51011. CONSOLE zeigt Policies sowie Kontext, Quellenstatus und Warnungen, jedoch keine Predicate- oder Masked-Column-Fachzeilen. RAW liefert sieben getrennte Mengen in der Reihenfolge moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus, warnings. TABLE schreibt angeforderte Teilmengen in vorbereitete lokale Temp-Tabellen. NONE liefert keine Resultsets. JSON und OUTPUTs sind unabhängig davon.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Außer bei TABLE sind NULL, leerer Text oder nur äußere U+0020-Leerzeichen zulässig; sonst INVALID_PARAMETER/51011. TABLE verlangt ein gültiges JSON-Objekt mit mindestens einer Zuordnung. Zulässige Schlüssel sind exakt moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus und warnings; jeder Wert ist ein nichtleerer String mit vorhandenem lokalen #Temp-Ziel. Schlüssel- oder Zielduplikate und unbekannte Namen werden abgewiesen. ##, Namen über 116 Zeichen und #Monitor-Präfix sind unzulässig. Jedes Ziel muss leer sein und genau eine Seed-Spalte haben. Der Helfer prüft alle Ziele vor fachlichen Systemzugriffen; der spätere Writer ersetzt die Seed-Spalte durch das native Ergebnisschema. Die Schlüssel bedeuten: moduleStatus Modulstatus, databaseContext Datenbankkontext, securityPolicies sichtbare RLS-Policies, securityPredicates Predicate-Metadaten, maskedColumns Metadaten maskierter Spalten, sourceStatus Quellenstatus und warnings Warnungen.';
        PRINT N'@JsonErzeugen bit; Default: 0. Nur 1 erzeugt im normalen Pfad das JSON-Objekt mit meta und allen sieben Arrays: moduleStatus, databaseContext, securityPolicies, securityPredicates, maskedColumns, sourceStatus und warnings. NULL und 0 überspringen die Erzeugung. Die Resultsetart bleibt davon unabhängig; im äußeren Fehlerpfad wird @Json auf NULL gesetzt. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Als OUTPUT-Variable binden, um den JSON-Text zu empfangen. Der eingehende Wert wird am Aufrufanfang auf NULL zurückgesetzt; nur bei @JsonErzeugen=1 wird er im normalen Pfad gesetzt. Ohne Erzeugung, bei frühem Parameterfehler oder im äußeren CATCH bleibt er NULL. Die Hilfe erzeugt kein JSON. Optionaler Empfänger: Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden, andernfalls das Argument auslassen.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 gibt Meldungen an den vorgesehenen Parameterfehler-, Quellenfehler- und äußeren Fehlerstellen mit NOWAIT aus. NULL und 0 unterdrücken sie. Status, OUTPUT-Werte und Rückgabecode werden dadurch nicht geändert. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. 1 beendet nach der Parameterhilfe und den Beispielen vor Validierung und Aufnahme. @StatusCodeOut wird AVAILABLE, @IsPartialOut 0; zuvor zurückgesetzte Fehler- und JSON-OUTPUTs bleiben NULL. Der bare RETURN ergibt Rückgabecode 0. NULL und 0 führen den normalen Pfad aus. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Als OUTPUT-Variable binden. Der Wert wird beim Eintritt zurückgesetzt. Hilfe liefert AVAILABLE; direkte Parameterfehler INVALID_PARAMETER; normale Aufnahmen liefern AVAILABLE_LIMITED, sobald mindestens eine der drei Fachquellen erfolgreich abgefragt wurde. AVAILABLE_LIMITED ist außerdem der Initialwert und bleibt erhalten, wenn ohne Kandidaten und ohne Auswahlwarnungen keine passende Statuszeile für die Fallback-Auswahl existiert; dieser Wert belegt daher keine erfolgreiche Katalogabfrage. Wenn keine Quelle diesen Status erreicht, übernimmt die Procedure den ersten Status ungleich AVAILABLE_LIMITED und SKIPPED nach DatabaseName und SourceKey; zwischen solchen Quellen gibt es keine Vorrangregel. Tatsächlich mögliche Werte: AVAILABLE (Hilfe), AVAILABLE_LIMITED (mindestens eine Fachquelle), DATABASE_UNAVAILABLE (Datenbankkontext/-quelle), SOURCE_UNAVAILABLE (Katalogquelle), SYSTEM_DATABASE_EXCLUDED (Auswahlwarnung), INVALID_PARAMETER (Vorprüfung/Helfer), INTERNAL_ERROR (Kandidaten-Temp-Schema), UNAVAILABLE_FEATURE (Regex-Voraussetzung), STATUS_UNAVAILABLE (fehlender Helferstatus), ERROR_HANDLED (äußerer CATCH ohne FailureStatus). Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Als bit-OUTPUT binden. Startwert wird NULL, bei Hilfe 0, bei direkter Parameterinvalidierung, normalem Ende und äußerem CATCH 1. Normale Erfolge bleiben partiell, weil Caller-Metadatensicht und vollständige RLS-/Maskingabdeckung unbewiesen sind und getrennte Quellen keinen gemeinsamen Snapshot bilden. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Als int-OUTPUT binden. Startwert NULL, auch bei Hilfe. Direkte Parameterfehler liefern 51011. Beim normalen Ende wird die erste nicht-NULL-Fehlernummer nach DatabaseId und SourceKey aus sourceStatus verwendet; ohne Quellenfehler bleibt NULL. Im äußeren CATCH hat FailureError Vorrang, sonst wird die abgefangene SQL-Fehlernummer ausgegeben. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Als OUTPUT-Variable binden. Startwert NULL, auch bei Hilfe. Direkte Parameterfehler liefern eine feste Parameterdiagnose. Normale Quellenfehler übernehmen die Meldung des ersten sourceStatus-Eintrags mit Fehlernummer nach DatabaseId und SourceKey. Im äußeren CATCH wird die vorbereitete Diagnose oder ERROR_MESSAGE() auf 2048 Zeichen begrenzt. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.';
        PRINT N'EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_RowLevelSecurityAndMaskingInventory]
      @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];';
        PRINT N'CREATE TABLE [#RowLevelSecurityAndMaskingInventory_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N''{"securityPolicies":"#RowLevelSecurityAndMaskingInventory_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @ResultSetArt=''TABLE'', @ResultTablesJson=@Map;
    SELECT * FROM [#RowLevelSecurityAndMaskingInventory_HelpExample];
    DROP TABLE IF EXISTS [#RowLevelSecurityAndMaskingInventory_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#RowLevelSecurityAndMaskingInventory_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_RowLevelSecurityAndMaskingInventory] @Hilfe=1;';



        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;
    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungueltiger Ausgabe-, Limit-, Locktimeout- oder TABLE-Parameter.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;
    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @PreviousLockTimeout=0 SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_moduleStatus]([ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CapturedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL,[RowCount] bigint NOT NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_databaseContext]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ContainmentDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PolicyObjectId] int NOT NULL,[PolicyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SchemaId] int NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsEnabled] bit NOT NULL,[IsNotForReplication] bit NOT NULL,[UsesDatabaseCollation] bit NOT NULL,[IsSchemabindingEnabled] bit NULL,[CreateDate] datetime NOT NULL,[ModifyDate] datetime NOT NULL);
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_securityPredicates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[PolicyObjectId] int NOT NULL,[PredicateId] int NOT NULL,[TargetObjectId] int NOT NULL,[PredicateType] int NOT NULL,[PredicateTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Operation] int NULL,[OperationDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObjectId] int NOT NULL,[ColumnId] int NOT NULL,[SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsMasked] bit NOT NULL);
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus]([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StartedAtUtc] datetime2(3) NOT NULL,[CompletedAtUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ObservedRows] bigint NULL,[ReturnedRows] bigint NULL,[IsLimited] bit NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_warnings]([DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_Map]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_Candidates]([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsReadOnly] bit NULL,[CompatibilityLevel] tinyint NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL);
        CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_SelectionWarnings]([RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,@AllowedResultNames=N'moduleStatus|databaseContext|securityPolicies|securityPredicates|maskedColumns|sourceStatus|warnings',@MappingTable=N'#285_USP_RowLevelSecurityAndMaskingInventory_Map',@StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE' BEGIN SET @FailureError=51011; RAISERROR(N'%s',16,1,@TableMessage); END;
        END;
        SET @Started=SYSUTCDATETIME();
        EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,@StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,@CandidateTable=N'#285_USP_RowLevelSecurityAndMaskingInventory_Candidates',@WarningTable=N'#285_USP_RowLevelSecurityAndMaskingInventory_SelectionWarnings';
        IF COALESCE(@TableStatus,'')<>'AVAILABLE' BEGIN SELECT @FailureError=51011,@FailureStatus=COALESCE(@TableStatus,'STATUS_UNAVAILABLE'); RAISERROR(N'%s',16,1,@TableMessage); END;
        INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] SELECT NULL,[RequestedName],'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),COALESCE([StatusCode],'STATUS_UNAVAILABLE'),'UNPROVEN',NULL,NULL,0,NULL,[ErrorMessage] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_SelectionWarnings];
        INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_warnings] SELECT NULL,[RequestedName],CASE WHEN [StatusCode] IN('DATABASE_UNAVAILABLE','DATABASE_NOT_FOUND') THEN 'DATABASE_UNAVAILABLE' ELSE 'SOURCE_UNAVAILABLE' END,'TARGET_SELECTION',LEFT(COALESCE([ErrorMessage],N'Der angeforderte Datenbankkontext ist nicht verfuegbar.'),1000) FROM [#285_USP_RowLevelSecurityAndMaskingInventory_SelectionWarnings];
        SET LOCK_TIMEOUT 0;
        SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; ';
        SET @IdentityGuard=N'IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID() AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS AND [create_date]=@Created) THROW 51012,N''Target database identity changed or is not available for this source.'',1; ';
        DECLARE [RlsMaskTargets] CURSOR LOCAL FAST_FORWARD FOR SELECT [DatabaseId],[DatabaseName] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_Candidates] ORDER BY [DatabaseId];
        OPEN [RlsMaskTargets]; FETCH NEXT FROM [RlsMaskTargets] INTO @DatabaseId,@DatabaseName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT @QuotedDatabase=QUOTENAME(@DatabaseName),@ContextAvailable=0,@ContextStatus='DATABASE_UNAVAILABLE',@DatabaseCreatedAt=NULL,@StateDescription=NULL,@ContainmentDescription=NULL;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'SELECT @State=[state_desc],@Containment=[containment_desc],@Created=[create_date],@Available=1 FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=@Id AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS;';
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@State nvarchar(60) OUTPUT,@Containment nvarchar(60) OUTPUT,@Created datetime OUTPUT,@Available bit OUTPUT',@Id=@DatabaseId,@Name=@DatabaseName,@State=@StateDescription OUTPUT,@Containment=@ContainmentDescription OUTPUT,@Created=@DatabaseCreatedAt OUTPUT,@Available=@ContextAvailable OUTPUT;
                SET @ContextStatus=CASE WHEN @ContextAvailable=1 THEN 'AVAILABLE_LIMITED' ELSE 'DATABASE_UNAVAILABLE' END; INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] VALUES(@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),@ContextStatus,CASE WHEN @ContextAvailable=1 THEN 'VISIBLE_ONLY' ELSE 'UNPROVEN' END,CASE WHEN @ContextAvailable=1 THEN 1 ELSE NULL END,CASE WHEN @ContextAvailable=1 THEN 1 ELSE NULL END,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                SET @ContextStatus=CASE WHEN ERROR_NUMBER() IN(911,924,926,927,942,945,952,978,4060) THEN 'DATABASE_UNAVAILABLE' ELSE 'SOURCE_UNAVAILABLE' END; INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] VALUES(@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),@ContextStatus,'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),CONCAT(N'Katalogquelle nicht verfuegbar; SQL Server Fehlernummer ',ERROR_NUMBER(),N'.'));
            END CATCH;
            INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_databaseContext] VALUES(@DatabaseId,@DatabaseName,@StateDescription,@ContainmentDescription,@ContextStatus);
            SET @Started=SYSUTCDATETIME(); SET @PolicyFieldAvailable=0;
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'SELECT @Available=CASE WHEN EXISTS(SELECT 1 FROM [sys].[all_objects] AS [o] WITH (NOLOCK) INNER JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[o].[schema_id] INNER JOIN [sys].[all_columns] AS [c] WITH (NOLOCK) ON [c].[object_id]=[o].[object_id] WHERE [o].[type] COLLATE SQL_Latin1_General_CP1_CS_AS=N''V'' COLLATE SQL_Latin1_General_CP1_CS_AS AND [o].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''security_policies'' COLLATE SQL_Latin1_General_CP1_CS_AS AND [s].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''sys'' COLLATE SQL_Latin1_General_CP1_CS_AS AND [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS=N''is_schemabinding_enabled'' COLLATE SQL_Latin1_General_CP1_CS_AS) THEN 1 ELSE 0 END; '+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Available bit OUTPUT',@Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Available=@PolicyFieldAvailable OUTPUT;
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies] SELECT @Id,@Name,[p].[object_id],[p].[name],[p].[schema_id],[s].[name],[p].[is_enabled],[p].[is_not_for_replication],[p].[uses_database_collation],'+CASE WHEN @PolicyFieldAvailable=1 THEN N'[p].[is_schemabinding_enabled]' ELSE N'CAST(NULL AS bit)' END+N',[p].[create_date],[p].[modify_date] FROM [sys].[security_policies] AS [p] WITH (NOLOCK) LEFT JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[p].[schema_id]; SET @Rows=@@ROWCOUNT; '+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',@Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] VALUES(@DatabaseId,@DatabaseName,'SECURITY_POLICIES','NATIVE',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
                IF @PolicyFieldAvailable=0 INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_warnings] VALUES(@DatabaseId,@DatabaseName,'SOURCE_UNAVAILABLE','SECURITY_POLICIES',N'Die Katalogansicht stellt IsSchemabindingEnabled nicht bereit; das NULL-faehige Feld bleibt NULL.');
            END TRY
            BEGIN CATCH
                DELETE FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] VALUES(@DatabaseId,@DatabaseName,'SECURITY_POLICIES','NATIVE',@Started,SYSUTCDATETIME(),CASE WHEN ERROR_NUMBER() IN(911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE' ELSE 'SOURCE_UNAVAILABLE' END,'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),CONCAT(N'Katalogquelle nicht verfuegbar; SQL Server Fehlernummer ',ERROR_NUMBER(),N'.'));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_securityPredicates] SELECT @Id,@Name,[p].[object_id],[p].[security_predicate_id],[p].[target_object_id],[p].[predicate_type],[p].[predicate_type_desc],[p].[operation],[p].[operation_desc] FROM [sys].[security_predicates] AS [p] WITH (NOLOCK); SET @Rows=@@ROWCOUNT; '+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',@Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] VALUES(@DatabaseId,@DatabaseName,'SECURITY_PREDICATES','NATIVE',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPredicates] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] VALUES(@DatabaseId,@DatabaseName,'SECURITY_PREDICATES','NATIVE',@Started,SYSUTCDATETIME(),CASE WHEN ERROR_NUMBER() IN(911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE' ELSE 'SOURCE_UNAVAILABLE' END,'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),CONCAT(N'Katalogquelle nicht verfuegbar; SQL Server Fehlernummer ',ERROR_NUMBER(),N'.'));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns] SELECT @Id,@Name,[m].[object_id],[m].[column_id],[s].[name],[t].[name],[m].[name],[m].[is_masked] FROM [sys].[masked_columns] AS [m] WITH (NOLOCK) LEFT JOIN [sys].[tables] AS [t] WITH (NOLOCK) ON [t].[object_id]=[m].[object_id] LEFT JOIN [sys].[schemas] AS [s] WITH (NOLOCK) ON [s].[schema_id]=[t].[schema_id]; SET @Rows=@@ROWCOUNT; '+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',@Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] VALUES(@DatabaseId,@DatabaseName,'MASKED_COLUMNS','NATIVE',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] VALUES(@DatabaseId,@DatabaseName,'MASKED_COLUMNS','NATIVE',@Started,SYSUTCDATETIME(),CASE WHEN ERROR_NUMBER() IN(911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE' ELSE 'SOURCE_UNAVAILABLE' END,'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),CONCAT(N'Katalogquelle nicht verfuegbar; SQL Server Fehlernummer ',ERROR_NUMBER(),N'.'));
            END CATCH;
            FETCH NEXT FROM [RlsMaskTargets] INTO @DatabaseId,@DatabaseName;
        END;
        CLOSE [RlsMaskTargets]; DEALLOCATE [RlsMaskTargets];
        ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[PolicyObjectId]) AS [rn] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies]) DELETE FROM [r] WHERE [rn]>@Limit;
        ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[PolicyObjectId],[PredicateId]) AS [rn] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPredicates]) DELETE FROM [r] WHERE [rn]>@Limit;
        ;WITH [r] AS(SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[ObjectId],[ColumnId]) AS [rn] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns]) DELETE FROM [r] WHERE [rn]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[n],[IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[n] THEN 1 ELSE 0 END FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] AS [s] CROSS APPLY(SELECT COUNT_BIG(*) AS [n] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies] AS [x] WHERE [x].[DatabaseId]=[s].[DatabaseId]) AS [r] WHERE [s].[SourceKey]='SECURITY_POLICIES' AND [s].[ObservedRows] IS NOT NULL;
        UPDATE [s] SET [ReturnedRows]=[r].[n],[IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[n] THEN 1 ELSE 0 END FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] AS [s] CROSS APPLY(SELECT COUNT_BIG(*) AS [n] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPredicates] AS [x] WHERE [x].[DatabaseId]=[s].[DatabaseId]) AS [r] WHERE [s].[SourceKey]='SECURITY_PREDICATES' AND [s].[ObservedRows] IS NOT NULL;
        UPDATE [s] SET [ReturnedRows]=[r].[n],[IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[n] THEN 1 ELSE 0 END FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] AS [s] CROSS APPLY(SELECT COUNT_BIG(*) AS [n] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns] AS [x] WHERE [x].[DatabaseId]=[s].[DatabaseId]) AS [r] WHERE [s].[SourceKey]='MASKED_COLUMNS' AND [s].[ObservedRows] IS NOT NULL;
        INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_warnings] VALUES(NULL,NULL,'METADATA_COMPLETENESS_UNPROVEN',NULL,N'Alle Ergebnisse enthalten ausschliesslich sichtbare Katalogmetadaten. Eingeschraenkte Metadatensicht bleibt unbewiesen; keine Wirksamkeits- oder Vollstaendigkeitsaussage.');
        INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_warnings] SELECT [DatabaseId],[DatabaseName],'OUTPUT_LIMIT',[SourceKey],N'Das globale Limit kuerzt dieses Inventar ueber alle ausgewaehlten Datenbanken.' FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] WHERE [IsLimited]=1;
        INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_warnings] SELECT DISTINCT [DatabaseId],[DatabaseName],'SOURCE_UNAVAILABLE','SECURITY_POLICIES',N'Die Policy-ID bleibt erhalten; der zugehoerige Schemaname war in der Metadatensicht nicht aufloesbar.' FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies] WHERE [SchemaName] IS NULL;
        INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_warnings] SELECT DISTINCT [DatabaseId],[DatabaseName],'SOURCE_UNAVAILABLE','MASKED_COLUMNS',N'Die Masked-Column-ID bleibt erhalten; Schema- oder Tabellenname war in der Metadatensicht nicht aufloesbar.' FROM [#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns] WHERE [SchemaName] IS NULL OR [TableName] IS NULL;
        INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_warnings] SELECT [DatabaseId],[DatabaseName],CASE WHEN [StatusCode]='DATABASE_UNAVAILABLE' THEN 'DATABASE_UNAVAILABLE' ELSE 'SOURCE_UNAVAILABLE' END,[SourceKey],N'Die Katalogquelle ist nicht verfuegbar; fehlende sichtbare Eintraege belegen keine Abwesenheit.' FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] WHERE [VisibilityScope]='UNPROVEN' AND [StatusCode]<>'SKIPPED' AND [SourceKind]<>'SELECTION';
        SELECT TOP(1) @Error=[ErrorNumber],@Message=[ErrorMessage] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] WHERE [ErrorNumber] IS NOT NULL ORDER BY [DatabaseId],[SourceKey];
        IF NOT EXISTS(SELECT 1 FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] WHERE [DatabaseId] IS NOT NULL AND [SourceKey] IN('SECURITY_POLICIES','SECURITY_PREDICATES','MASKED_COLUMNS') AND [StatusCode]='AVAILABLE_LIMITED')
            SELECT TOP(1) @Status=[StatusCode],@Message=COALESCE(@Message,[ErrorMessage]) FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] WHERE [StatusCode] NOT IN('AVAILABLE_LIMITED','SKIPPED') ORDER BY [DatabaseName],[SourceKey];
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies])+(SELECT COUNT_BIG(*) FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPredicates])+(SELECT COUNT_BIG(*) FROM [#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns]);
        INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_moduleStatus] VALUES(N'USP_RowLevelSecurityAndMaskingInventory',@CapturedAtUtc,@Status,1,@Rows,N'Getrennte sichtbare Katalogaufnahmen im Caller-Kontext. Sichtbarkeit belegt weder Vollstaendigkeit noch Richtlinienwirksamkeit.');
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'RowLevelSecurityAndMaskingInventory' AS [resultName],1 AS [schemaVersion],@CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],@Error AS [errorNumber],@Message AS [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_databaseContext nvarchar(max)=(SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_databaseContext] ORDER BY [DatabaseId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_securityPolicies nvarchar(max)=(SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies] ORDER BY [DatabaseId],[PolicyObjectId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_securityPredicates nvarchar(max)=(SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPredicates] ORDER BY [DatabaseId],[PolicyObjectId],[PredicateId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_maskedColumns nvarchar(max)=(SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns] ORDER BY [DatabaseId],[ObjectId],[ColumnId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"databaseContext":',COALESCE(@Json_databaseContext,N'[]'),N',"securityPolicies":',COALESCE(@Json_securityPolicies,N'[]'),N',"securityPredicates":',COALESCE(@Json_securityPredicates,N'[]'),N',"maskedColumns":',COALESCE(@Json_maskedColumns,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_moduleStatus]; SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_databaseContext] ORDER BY [DatabaseId]; SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies] ORDER BY [DatabaseId],[PolicyObjectId]; SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPredicates] ORDER BY [DatabaseId],[PolicyObjectId],[PredicateId]; SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_maskedColumns] ORDER BY [DatabaseId],[ObjectId],[ColumnId]; SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey]; SELECT * FROM [#285_USP_RowLevelSecurityAndMaskingInventory_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [RlsMaskOutput] CURSOR LOCAL FAST_FORWARD FOR SELECT [ResultName],[TargetTable] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_Map] ORDER BY [ResultName];
            OPEN [RlsMaskOutput]; FETCH NEXT FROM [RlsMaskOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0 BEGIN SET @SourceTable=N'#285_USP_RowLevelSecurityAndMaskingInventory_'+@ResultName; EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,@StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0; IF COALESCE(@TableStatus,'')<>'AVAILABLE' BEGIN SET @FailureError=COALESCE(@TableError,51010); RAISERROR(N'%s',16,1,@TableMessage); END; FETCH NEXT FROM [RlsMaskOutput] INTO @ResultName,@TargetTable; END;
            CLOSE [RlsMaskOutput]; DEALLOCATE [RlsMaskOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            CREATE TABLE [#285_USP_RowLevelSecurityAndMaskingInventory_Console]([Bereich] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Objekt] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
            INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_Console] SELECT N'Datenbank',[DatabaseName],CONCAT([StateDescription],N'; ',[ContextStatus]) FROM [#285_USP_RowLevelSecurityAndMaskingInventory_databaseContext];
            INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_Console] SELECT N'Security Policy',[PolicyName],CONCAT(N'DB=',[DatabaseName],N'; Schema=',COALESCE([SchemaName],N'<unaufgeloest>'),N'; aktiviert=',[IsEnabled]) FROM [#285_USP_RowLevelSecurityAndMaskingInventory_securityPolicies];
            INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_Console] SELECT N'Quelle',[SourceKey],CONCAT(N'DB=',[DatabaseName],N'; ',[StatusCode],N'; sichtbar=',[ObservedRows],N'; Ausgabe=',[ReturnedRows]) FROM [#285_USP_RowLevelSecurityAndMaskingInventory_sourceStatus];
            INSERT [#285_USP_RowLevelSecurityAndMaskingInventory_Console] SELECT N'Aussagegrenze',[WarningCode],[Detail] FROM [#285_USP_RowLevelSecurityAndMaskingInventory_warnings];
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#285_USP_RowLevelSecurityAndMaskingInventory_Console',@ResultLabel=N'Sichtbares RLS- und Dynamic-Data-Masking-Inventar',@EmptyMessage=N'Keine sichtbaren Policymetadaten.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL RAISERROR(N'USP_RowLevelSecurityAndMaskingInventory: mindestens eine Quelle ist nicht verfuegbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock; IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@FailureError,ERROR_NUMBER()),@Message=LEFT(ERROR_MESSAGE(),2048),@Json=NULL;
        SELECT @StatusCodeOut=COALESCE(@FailureStatus,'ERROR_HANDLED'),@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock; IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
