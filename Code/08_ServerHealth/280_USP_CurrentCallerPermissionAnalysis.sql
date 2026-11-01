USE [DeineDatenbank];
GO

/*
Objekt       : monitor.USP_CurrentCallerPermissionAnalysis
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Die Procedure zeigt native SERVER- und DATABASE-Rechte des aktuellen
               Ausfuehrungskontexts mit getrennten Quellen und Kontext-IDs.
Grenzen      : Der Bericht beweist keinen konkreten Objekt- oder Statementzugriff.
Nebenwirkung : Der Bericht liest nur und wechselt keine Identitaet.
Datenschutz  : Der Bericht erfragt keine SID- oder Tokenquellen. Native Namen
               und diagnostische Fehlermeldungen bleiben erhalten.
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_CurrentCallerPermissionAnalysis]
      @DatabaseNames nvarchar(max) = NULL
    , @SystemdatenbankenEinbeziehen bit = 0
    , @DatabaseNamePattern nvarchar(4000) = NULL
    , @ServerrechteEinbeziehen bit = 1
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
        @DatabaseCreatedAt datetime,@CrossDatabaseRequested bit;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_CurrentCallerPermissionAnalysis';
        PRINT N'Liest native SERVER- und DATABASE-Rechte des tatsächlich aktiven Ausführungskontexts über sys.fn_my_permissions und zeigt getrennte Quellenzustände sowie numerische Kontext-IDs. Die Procedure wechselt keine Identität und prüft keinen konkreten Objektzugriff.';
        PRINT N'Ohne wirksame Auswahlfilter werden sichtbare, ONLINE befindliche und für den Aufrufer zugängliche Benutzerdatenbanken untersucht; Systemdatenbanken bleiben standardmäßig ausgeschlossen. Die Serverrechtequelle ist separat abschaltbar.';
        PRINT N'RAW liefert sechs benannte Mengen; JSON enthält dieselben sechs Arrays und meta. TABLE schreibt ausschließlich die per Mapping angeforderte Teilmenge. CONSOLE rendert eine beschriftete fachliche Sicht, NONE unterdrückt Resultsets. Prüfen Sie Status und Fehler-OUTPUTs auch bei RETURN 0.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Nicht angegeben oder NULL, N'''' und ausschließlich äußere U+0020-Leerzeichen bedeuten keine Einschränkung; interne Leerzeichen bleiben Bestandteil der Eingabe. Andernfalls eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], innerhalb ist es Inhalt, ]] maskiert dort ]. Der Parser trimmt Segmentränder, prüft rohe Segmente bis 4000 Zeichen; danach verlangt die Namensprüfung PARSENAME-Teil 1 ≠ NULL, Teil 2 = NULL und LEN(Teil 1) ≤ 128. Teile 3/4 werden nicht separat geprüft. Exakte Namen werden case-sensitive verglichen. Mit aktivem nichtleerem Listenfilter muss @DatabaseNamePattern NULL sein; case-sensitive doppelte Listennamen werden als INVALID_PARAMETER zurückgewiesen. Ungültige Listenelemente werden als INVALID_PARAMETER zurückgewiesen. Syntaktisch gültige, aber nicht verfügbare explizite Namen erscheinen als Auswahlwarnungen; sie beweisen nicht, dass eine Datenbank fehlt. Ohne Filter gilt die Kandidatenauswahl nach sichtbaren, ONLINE- und zugänglichen Nicht-Snapshot-Datenbanken.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 lässt Datenbank-IDs bis 4 aus; 1 erlaubt Systemdatenbanken. NULL wird vor dem regulären Auswahlpfad als INVALID_PARAMETER abgewiesen. Auch mit 1 bleiben Sichtbarkeit, ONLINE-Zustand und HAS_DBACCESS=1 Voraussetzungen; die Auswahl ist kein vollständiger Datenbankkatalog. SQL bindet numerische 0 als 0 und sonstige konvertierbare Nichtnullwerte als 1.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Pattern. Sonst trimmt der Parser äußere Leerzeichen und erkennt case-insensitive die Präfixe LIKE:, REGEX: und REGEXI:; ohne Präfix gilt LIKE. Nach dem Präfix wird nicht erneut getrimmt. Leerer Inhalt oder nur U+0020-Leerzeichen einschließlich leerem Präfixinhalt ist ungültig. Aktive nichtleere @DatabaseNames und ein nicht-NULL-Pattern sind unvereinbar. LIKE wird case-sensitive mit SQL-LIKE-Syntax (% beliebige Folge, _ ein Zeichen, [...] Zeichenklasse; keine eigene ESCAPE-Klausel) ausgewertet. REGEX übergibt das Muster an REGEXP_LIKE mit Flag c, REGEXI mit Flag i; beides verlangt SQL Server 2025 und Compatibility Level 170 in der Installationsdatenbank. Parservalidierung prüft weder Regexsyntax noch Treffer; Ausführungsfehler werden in der jeweiligen Quell-/Auswahlbehandlung sichtbar.';
        PRINT N'@ServerrechteEinbeziehen bit; Default: 1. 1 ruft sys.fn_my_permissions(NULL,N''SERVER'') im tatsächlich aktiven Kontext auf; 0 überspringt nur diese Quelle und trägt für SERVER_CURRENT_PERMISSIONS den Quellstatus SKIPPED ein. NULL wird in der Parameterprüfung als INVALID_PARAMETER zurückgewiesen. Das Abschalten der Serverquelle verhindert nicht die getrennten Datenbankquellen und macht die Gesamtausgabe nicht automatisch zu einer Fehlerausgabe. SQL bindet numerische 0 als 0 und sonstige konvertierbare Nichtnullwerte als 1.';
        PRINT N'@MaxZeilen int; Default: 1000. NULL oder 0 bedeutet unbegrenzt; negative Werte sind INVALID_PARAMETER. Ein positiver Wert begrenzt die Serverrechtemenge global und separat jede Datenbankrechtemenge global über alle gewählten Datenbanken. Gekürzt wird nach EntityName, SubentityName, PermissionName (Datenbankmenge zusätzlich zuerst DatabaseId); für identische Sortierschlüssel ist keine weitere Tie-Break-Reihenfolge zugesichert. Die native Quelle wird zuvor vollständig aufgenommen; das Limit reduziert weder Zielauswahl noch Funktionsaufrufe. ObservedRows bleibt die aufgenommene Menge, ReturnedRows zeigt die Ausgabe, IsLimited markiert eine Kürzung. Kontext-, Status- und Warnungszeilen werden nicht gekappt.';
        PRINT N'@LockTimeoutMs int; Default: 0. Gültig sind 0 bis 60000 Millisekunden einschließlich beider Grenzen; NULL, negative Werte und größere Werte werden als INVALID_PARAMETER abgewiesen. Der Wert wird für die dynamischen fachlichen Quellenbatches als LOCK_TIMEOUT verwendet; 0 bedeutet NOWAIT. Eigene vorbereitende Temp-DDL erhält bei eingehendem Caller-LOCK_TIMEOUT 0 separat bis zu 1000 ms pro Statement. Die Procedure stellt den eingehenden LOCK_TIMEOUT am regulären Ende und im äußeren CATCH wieder her. Dies ist keine Gesamtzeitgrenze und kein atomarer Snapshot.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. NULL und leer normalisieren zu leer und sind ungültig. Nach LTRIM/RTRIM äußerer U+0020-Leerzeichen und UPPER sind ausschließlich CONSOLE (ein fachliches, beschriftetes Ergebnis über Console-Helper), RAW (sechs getrennte Resultsets), TABLE (angeforderte benannte Mengen in lokale Temp-Ziele), NONE (keine fachlichen Resultsets) zulässig. Bei CONSOLE wird keine eigene Modulstatusmenge ergänzt; leere Console-Ansicht erhält die Helper-Zeile. JSON ist davon unabhängig. Außerhalb TABLE muss @ResultTablesJson NULL, leer oder nur U+0020-Leerzeichen sein; sonst INVALID_PARAMETER.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Außerhalb TABLE sind NULL, leer oder nur U+0020-Leerzeichen zulässig; anderer Inhalt wird als INVALID_PARAMETER mit Fehler 51011 abgelehnt. In TABLE muss die gemeinsame Vorprüfung ein JSON-Objekt mit mindestens einer Zuordnung aus den exakten Schlüsseln moduleStatus, callerContexts, serverPermissions, databasePermissions, sourceStatus und warnings erhalten. Schlüssel dürfen nicht doppelt vorkommen; Zielnamen dürfen nicht mehrfach vorkommen (case-insensitive). Werte müssen eindeutige, vorhandene, leere lokale #Temp-Tabellen mit genau einer Seed-Spalte und höchstens 116 Zeichen bezeichnen. ##-Ziele und reservierte #Monitor*-Ziele sind unzulässig. Die Vorprüfung erfolgt vor Quellzugriff; der Helper wird mit ThrowOnError=0 aufgerufen. Bei abgelehntem Ziel löst die Procedure selbst ihren äußeren CATCH aus; dieser setzt ERROR_HANDLED, Partialität und Diagnose-OUTPUTs und liefert für die TABLE-Vorprüfung RETURN 51011. Jede Zuordnung schreibt nur die entsprechende Menge; nicht angeforderte Mengen werden nicht geschrieben. Die Schlüssel bedeuten: moduleStatus Modulstatus, callerContexts aktive Ausführungskontexte, serverPermissions native SERVER-Rechte, databasePermissions native DATABASE-Rechte, sourceStatus Quellenstatus und warnings Warnungen.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erzeugt zusätzlich das JSON-Dokument in @Json, unabhängig von der ResultSetArt; 0 oder NULL erzeugt keines (NULL aktiviert die IF-Bedingung nicht). Bei erfolgreichem regulärem Pfad enthält es meta mit resultName, schemaVersion=1, generatedAtUtc, statusCode, isPartial=1, errorNumber und errorMessage sowie die sechs Arrays moduleStatus, callerContexts, serverPermissions, databasePermissions, sourceStatus und warnings; NULL-Felder bleiben enthalten. Ein äußerer Fehler lässt @Json NULL. Die Dokumenterzeugung vereinigt die getrennten zeitlichen Quellen nicht zu einem Snapshot. Numerische 0 wird beim Binden zu 0, jeder nach bit konvertierbare von 0 verschiedene numerische Wert zu 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger des JSON-Dokuments: zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; Argument kann ausgelassen werden. Die Procedure setzt @Json beim Eintritt auf NULL, setzt es nur bei aktiviertem @JsonErzeugen im regulären Pfad und lässt es bei Hilfe, Validierungsfehler und gefangenem äußerem Fehler NULL. Optionaler Empfänger: Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden, andernfalls das Argument auslassen.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 erlaubt die vorgesehenen Meldungen niedriger Severity: bei @Hilfe werden die Hilfetexte unabhängig von diesem Schalter ausgegeben; bei ungültigen Parametern, Quellenfehlern mit ermitteltem Fehler und äußerem Fehler kann RAISERROR Severity 10 mit NOWAIT folgen. 0 unterdrückt diese Diagnosemeldungen, nicht Resultsets oder OUTPUTs. NULL löst die IF-Bedingung für 1 nicht aus. Numerische 0 wird beim Binden zu 0, jeder nach bit konvertierbare von 0 verschiedene numerische Wert zu 1.';
        PRINT N'@Hilfe bit; Default: 0. 1 druckt die eingebaute Parameterhilfe und Beispiele und setzt @StatusCodeOut=AVAILABLE sowie @IsPartialOut=0; anschließend RETURN 0, ohne reguläre Eingabeprüfung, Kandidatenauswahl oder Quellenlesung. Die beim Eintritt bereits auf NULL gesetzten @Json- und Fehler-OUTPUTs bleiben NULL. Vor diesem Zweig läuft keine TABLE-Vorprüfung: diese erfolgt erst nach Hilfe, während ungültige Nicht-TABLE-Mappings ebenfalls erst danach geprüft werden. 0 oder NULL führt zum normalen Pfad. Numerische 0 wird beim Binden zu 0, jeder nach bit konvertierbare von 0 verschiedene numerische Wert zu 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger varchar(40); binde eine Variable mit OUTPUT. Alle Statuswerte und ihre Priorität: Hilfe setzt AVAILABLE (vor Quellenprüfung). Parameterprüfung setzt INVALID_PARAMETER und RETURN 51011. Fehler der Kandidatenvorbereitung werden als deren Status weitergegeben: INVALID_PARAMETER (ungültige Auswahl), INTERNAL_ERROR (interner Schemafehler), UNAVAILABLE_FEATURE (Regexvoraussetzung fehlt) oder STATUS_UNAVAILABLE als Fallback; äußerer CATCH setzt dazu den passenden Fehlercode. Im regulären Bericht gilt AVAILABLE_LIMITED, sobald mindestens eine native SERVER-/DATABASE-Rechtemenge nichtleer erfolgreich aufgenommen wurde. Andernfalls hat EMPTY_UNPROVEN Vorrang, sobald mindestens eine erfolgreiche native Menge leer ist. Wenn keine erfolgreiche leere Menge existiert, wird der nach DatabaseId und SourceKey erste native Fehlerstatus gewählt: DENIED_PERMISSION (Enginefehler 229, 297, 300, 371 oder 916), TIMEOUT (1222), DATABASE_UNAVAILABLE (konkret erkannte Kontext-/DB-Fehler) oder ERROR_HANDLED (sonstiger abgefangener Quellenfehler). Gibt es auch keinen solchen Fehler, gilt NO_TARGETS (z.B. keine Ziele oder nur übersprungene Quellen). Kandidatenfehler geben den gesetzten Helferstatus weiter. TABLE-Vorprüfungs- oder Schreibfehler setzen dagegen keinen FailureStatus und ergeben im äußeren CATCH ERROR_HANDLED mit vorbereitetem Diagnosecode; Schreibfehler verwenden den Helpercode oder 51010. Andere äußere Fehler ergeben ebenfalls ERROR_HANDLED, sofern kein Kandidaten-FailureStatus gesetzt wurde. Reguläre Fachquellenfehler ändern RETURN 0 nicht; Status, Fehler-OUTPUTs und sourceStatus getrennt prüfen. Beim Eintritt wird ein vorhandener Empfänger zurückgesetzt; Hilfe überschreibt Status/Partial, lässt die übrigen Fehler-OUTPUTs NULL. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger bit; eine Variable mit OUTPUT binden. Bei Eintritt NULL, bei Hilfe 0, bei ungültiger Eingabe, regulärem Bericht und äußerem Fehler 1. Auch AVAILABLE_LIMITED ist immer partiell: leere Quellen beweisen keine Abwesenheit, Sichtbarkeit ist begrenzt, und getrennte Aufnahmen sind nicht atomar. RETURN 0 kann trotz Quellenfehler auftreten. Beim Eintritt wird ein anfänglicher Empfängerwert zurückgesetzt. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionaler int-OUTPUT-Empfänger. Beim Eintritt NULL. Bei Parameterablehnung 51011; im regulären Bericht Nummer der fehlerhaften Quelle mit der ersten Sortierung nach DatabaseId und SourceKey, sonst NULL. Beim äußeren CATCH Fehlercode des vorbereiteten Fehlerpfads, andernfalls ERROR_NUMBER(); erfolgreicher Hilfspfad lässt NULL. Eine reguläre Quellenstörung ändert RETURN 0 nicht. Zum Empfangen Variable mit OUTPUT binden. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler nvarchar(2048)-OUTPUT-Empfänger. Beim Eintritt NULL. Bei Parameterablehnung feste Diagnose; im regulären Bericht Meldung der ersten fehlerhaften Quelle nach DatabaseId und SourceKey, sonst NULL. Beim äußeren CATCH abgefangene Meldung; Quellen-/Enginefehler bleiben diagnostisch erhalten. Eine reguläre Quellenstörung ändert RETURN 0 nicht. Zum Empfangen Variable mit OUTPUT binden. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Anfangswerte, auch NULL, werden durch die Eintrittszuweisung zurückgesetzt.';
        PRINT N'EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_CurrentCallerPermissionAnalysis]
      @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];';
        PRINT N'CREATE TABLE [#CurrentCallerPermissionAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N''{"databasePermissions":"#CurrentCallerPermissionAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@Map;
    SELECT * FROM [#CurrentCallerPermissionAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#CurrentCallerPermissionAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#CurrentCallerPermissionAnalysis_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_CurrentCallerPermissionAnalysis] @Hilfe=1;';




        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN 0;
    END;
    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0 OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR @ServerrechteEinbeziehen IS NULL OR @SystemdatenbankenEinbeziehen IS NULL
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Ungueltiger Ausgabe-, Auswahl-, Limit-, Locktimeout- oder TABLE-Parameter.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;
    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @PreviousLockTimeout=0 SET LOCK_TIMEOUT 1000;
        CREATE TABLE [#CurrentCallerPermissionAnalysis_moduleStatus]
        (
[ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [RowCount] bigint NOT NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#CurrentCallerPermissionAnalysis_callerContexts]
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
        CREATE TABLE [#CurrentCallerPermissionAnalysis_serverPermissions]
        (
[EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#CurrentCallerPermissionAnalysis_databasePermissions]
        (
[DatabaseId] int NOT NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#CurrentCallerPermissionAnalysis_sourceStatus]
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
        CREATE TABLE [#CurrentCallerPermissionAnalysis_warnings]
        (
[DatabaseId] int NULL,
    [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#CurrentCallerPermissionAnalysis_Candidates]
        (

        [DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsReadOnly] bit NULL,
        [CompatibilityLevel] tinyint NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL

        );
        CREATE TABLE [#CurrentCallerPermissionAnalysis_SelectionWarnings]
        (
[RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        );
        CREATE TABLE [#CurrentCallerPermissionAnalysis_Map]
        (
[ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        );
        CREATE TABLE [#CurrentCallerPermissionAnalysis_NativeServer]
        ([EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        CREATE TABLE [#CurrentCallerPermissionAnalysis_NativeDatabase]
        ([DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|callerContexts|serverPermissions|databasePermissions|sourceStatus|warnings',
                @MappingTable=N'#CurrentCallerPermissionAnalysis_Map',@StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN SET @FailureError=51011;RAISERROR(N'%s',16,1,@TableMessage);END;
        END;
        SET @Started=SYSUTCDATETIME();
        EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,
            @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,
            @StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,
            @CandidateTable=N'#CurrentCallerPermissionAnalysis_Candidates',@WarningTable=N'#CurrentCallerPermissionAnalysis_SelectionWarnings';
        IF COALESCE(@TableStatus,'')<>'AVAILABLE'
        BEGIN SELECT @FailureError=51011,@FailureStatus=COALESCE(@TableStatus,'STATUS_UNAVAILABLE');RAISERROR(N'%s',16,1,@TableMessage);END;
        INSERT [#CurrentCallerPermissionAnalysis_sourceStatus] VALUES
            (NULL,NULL,'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),'AVAILABLE','CURRENT_SELECTION',
             (SELECT COUNT_BIG(*) FROM [#CurrentCallerPermissionAnalysis_Candidates]),(SELECT COUNT_BIG(*) FROM [#CurrentCallerPermissionAnalysis_Candidates]),0,NULL,NULL);
        INSERT [#CurrentCallerPermissionAnalysis_sourceStatus]
            SELECT NULL,[RequestedName],'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   COALESCE([StatusCode],'STATUS_UNAVAILABLE'),'UNPROVEN',NULL,NULL,0,NULL,[ErrorMessage]
            FROM [#CurrentCallerPermissionAnalysis_SelectionWarnings];
        INSERT [#CurrentCallerPermissionAnalysis_warnings]
            SELECT NULL,[RequestedName],'TARGET_SELECTION','DATABASE_SELECTION',LEFT(COALESCE([ErrorMessage],N'Kein verfuegbarer Zielkontext.'),1000)
            FROM [#CurrentCallerPermissionAnalysis_SelectionWarnings];
        SET LOCK_TIMEOUT 0;
        SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; ';
        -- TARGET_IDENTITY_GUARD_BEGIN
        SET @IdentityGuard=N'IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [sys].[databases] WITH (NOLOCK)
            WHERE [database_id]=DB_ID() AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS AND [create_date]=@Created)
            THROW 51012,N''Target database identity changed or is not available for this source.'',1; ';
        -- TARGET_IDENTITY_GUARD_END
        SET @Started=SYSUTCDATETIME();
        IF @ServerrechteEinbeziehen=1
        BEGIN
            BEGIN TRY
                SET @Sql=@SetLock+N'DECLARE @ContextDb int=DB_ID(),@ContextServer int=SUSER_ID(),@ContextUser int=DATABASE_PRINCIPAL_ID(),@ContextAt datetime2(3)=SYSUTCDATETIME(); INSERT [#CurrentCallerPermissionAnalysis_NativeServer] SELECT [entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name]) FROM [sys].[fn_my_permissions](NULL,N''SERVER''); SET @Rows=(SELECT COUNT_BIG(*) FROM [#CurrentCallerPermissionAnalysis_NativeServer]); IF EXISTS(SELECT 1 FROM [#CurrentCallerPermissionAnalysis_NativeServer] WHERE ([PermissionName] IS NULL OR LEN(LTRIM(RTRIM([PermissionName])))=0)) THROW 51014,N''Native source returned an unusable permission name.'',1; IF EXISTS(SELECT @ContextDb,@ContextServer,@ContextUser EXCEPT SELECT DB_ID(),SUSER_ID(),DATABASE_PRINCIPAL_ID()) THROW 51013,N''Current execution-context identifiers changed during the source read.'',1; INSERT [#CurrentCallerPermissionAnalysis_serverPermissions] SELECT * FROM [#CurrentCallerPermissionAnalysis_NativeServer]; INSERT [#CurrentCallerPermissionAnalysis_callerContexts] VALUES (N''SERVER_CURRENT_PERMISSIONS'',NULL,NULL,@ContextDb,@ContextServer,@ContextUser,CASE WHEN @ContextServer IS NOT NULL AND @ContextUser IS NOT NULL THEN N''CAPTURED_CURRENT_IDS'' ELSE N''PARTIAL_CURRENT_IDS'' END,@ContextAt);';
                EXEC [sys].[sp_executesql] @Sql,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
                INSERT [#CurrentCallerPermissionAnalysis_sourceStatus] VALUES
                    (NULL,NULL,'SERVER_CURRENT_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END,'CURRENT_CONTEXT_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#CurrentCallerPermissionAnalysis_NativeServer];
                DELETE FROM [#CurrentCallerPermissionAnalysis_serverPermissions];
                DELETE FROM [#CurrentCallerPermissionAnalysis_callerContexts] WHERE [SourceKey]='SERVER_CURRENT_PERMISSIONS';
                INSERT [#CurrentCallerPermissionAnalysis_sourceStatus] VALUES
                    (NULL,NULL,'SERVER_CURRENT_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
        END
        ELSE
            INSERT [#CurrentCallerPermissionAnalysis_sourceStatus] VALUES
                (NULL,NULL,'SERVER_CURRENT_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),'SKIPPED','UNPROVEN',NULL,NULL,0,NULL,NULL);
        DECLARE [CurrentCallerPermissionTargets] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName] FROM [#CurrentCallerPermissionAnalysis_Candidates] ORDER BY [DatabaseId];
        OPEN [CurrentCallerPermissionTargets];FETCH NEXT FROM [CurrentCallerPermissionTargets] INTO @DatabaseId,@DatabaseName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT @QuotedDatabase=QUOTENAME(@DatabaseName),@DatabaseCreatedAt=NULL;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'SELECT @Created=[create_date] FROM [master].[sys].[databases] WITH (NOLOCK)
                    WHERE [database_id]=@Id AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS;';
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime OUTPUT',@Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt OUTPUT;
                IF @DatabaseCreatedAt IS NULL THROW 51012,N'Target database context is not available.',1;
                INSERT [#CurrentCallerPermissionAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',1,1,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                INSERT [#CurrentCallerPermissionAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER()=51012 THEN 'DATABASE_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            IF @DatabaseCreatedAt IS NOT NULL
            BEGIN
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'DECLARE @ContextDb int=DB_ID(),@ContextServer int=SUSER_ID(),@ContextUser int=DATABASE_PRINCIPAL_ID(),@ContextAt datetime2(3)=SYSUTCDATETIME(); INSERT [#CurrentCallerPermissionAnalysis_NativeDatabase] SELECT @Id,@Name,[entity_name],[subentity_name],CONVERT(nvarchar(128),[permission_name]) FROM [sys].[fn_my_permissions](NULL,N''DATABASE''); SET @Rows=(SELECT COUNT_BIG(*) FROM [#CurrentCallerPermissionAnalysis_NativeDatabase] WHERE [DatabaseId]=@Id); IF EXISTS(SELECT 1 FROM [#CurrentCallerPermissionAnalysis_NativeDatabase] WHERE [DatabaseId]=@Id AND ([PermissionName] IS NULL OR LEN(LTRIM(RTRIM([PermissionName])))=0)) THROW 51014,N''Native source returned an unusable permission name.'',1; IF EXISTS(SELECT @ContextDb,@ContextServer,@ContextUser EXCEPT SELECT DB_ID(),SUSER_ID(),DATABASE_PRINCIPAL_ID()) THROW 51013,N''Current execution-context identifiers changed during the source read.'',1; '+@IdentityGuard+N'INSERT [#CurrentCallerPermissionAnalysis_databasePermissions] SELECT * FROM [#CurrentCallerPermissionAnalysis_NativeDatabase] WHERE [DatabaseId]=@Id; INSERT [#CurrentCallerPermissionAnalysis_callerContexts] VALUES (N''DATABASE_CURRENT_PERMISSIONS'',@Id,@Name,@ContextDb,@ContextServer,@ContextUser,CASE WHEN @ContextServer IS NOT NULL AND @ContextUser IS NOT NULL THEN N''CAPTURED_CURRENT_IDS'' ELSE N''PARTIAL_CURRENT_IDS'' END,@ContextAt);';
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',@Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#CurrentCallerPermissionAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CURRENT_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN @Observed=0 THEN 'EMPTY_UNPROVEN' ELSE 'AVAILABLE_LIMITED' END,'CURRENT_CONTEXT_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#CurrentCallerPermissionAnalysis_NativeDatabase] WHERE [DatabaseId]=@DatabaseId;
                DELETE FROM [#CurrentCallerPermissionAnalysis_databasePermissions] WHERE [DatabaseId]=@DatabaseId;
                DELETE FROM [#CurrentCallerPermissionAnalysis_callerContexts] WHERE [SourceKey]='DATABASE_CURRENT_PERMISSIONS' AND [DatabaseId]=@DatabaseId;
                INSERT [#CurrentCallerPermissionAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CURRENT_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION' WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
        END
        ELSE
            INSERT [#CurrentCallerPermissionAnalysis_sourceStatus] VALUES
                (@DatabaseId,@DatabaseName,'DATABASE_CURRENT_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),'SKIPPED','UNPROVEN',NULL,NULL,0,NULL,N'DATABASE_CONTEXT is not available; the permission function was not called.');
            FETCH NEXT FROM [CurrentCallerPermissionTargets] INTO @DatabaseId,@DatabaseName;
        END;
        CLOSE [CurrentCallerPermissionTargets];DEALLOCATE [CurrentCallerPermissionTargets];
        ;WITH [Ranked] AS (SELECT *,ROW_NUMBER() OVER(ORDER BY [EntityName],[SubentityName],[PermissionName]) AS [OutputRank] FROM [#CurrentCallerPermissionAnalysis_serverPermissions]) DELETE FROM [Ranked] WHERE [OutputRank]>@Limit;
        ;WITH [Ranked] AS (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[EntityName],[SubentityName],[PermissionName]) AS [OutputRank] FROM [#CurrentCallerPermissionAnalysis_databasePermissions]) DELETE FROM [Ranked] WHERE [OutputRank]>@Limit;
        UPDATE [s] SET [ReturnedRows]=CASE WHEN [s].[SourceKey]='SERVER_CURRENT_PERMISSIONS' THEN
                (SELECT COUNT_BIG(*) FROM [#CurrentCallerPermissionAnalysis_serverPermissions]) ELSE
                (SELECT COUNT_BIG(*) FROM [#CurrentCallerPermissionAnalysis_databasePermissions] AS [p] WHERE [p].[DatabaseId]=[s].[DatabaseId]) END
        FROM [#CurrentCallerPermissionAnalysis_sourceStatus] AS [s]
        WHERE [s].[SourceKey] IN ('SERVER_CURRENT_PERMISSIONS','DATABASE_CURRENT_PERMISSIONS') AND [s].[ObservedRows] IS NOT NULL;
        UPDATE [#CurrentCallerPermissionAnalysis_sourceStatus] SET [IsLimited]=1 WHERE [ReturnedRows]<[ObservedRows];
        INSERT [#CurrentCallerPermissionAnalysis_warnings] VALUES
            (NULL,NULL,'CURRENT_CONTEXT_BOUNDARY',NULL,N'Die native Bewertung gilt nur fuer den aktuellen Ausfuehrungskontext; erfasste IDs sind kein vollstaendiger Token- oder Daueridentitaetsnachweis.'),
            (NULL,NULL,'SECURABLE_LEVEL_BOUNDARY',NULL,N'SERVER-/DATABASE-Rechte beweisen keinen konkreten Objekt-, Spalten- oder Statementzugriff. Getrennte Quellen sind kein atomarer Snapshot.');
        INSERT [#CurrentCallerPermissionAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'OUTPUT_LIMIT',[SourceKey],N'Die fachliche Rechtemenge wurde global gekuerzt; erfasste Kontext- und Quellenzeilen bleiben erhalten.'
            FROM [#CurrentCallerPermissionAnalysis_sourceStatus] WHERE [IsLimited]=1;
        INSERT [#CurrentCallerPermissionAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'EMPTY_PERMISSION_SOURCE_UNPROVEN',[SourceKey],N'Die native Funktion lieferte keine Zeile; dies beweist keine fehlenden Rechte.'
            FROM [#CurrentCallerPermissionAnalysis_sourceStatus] WHERE [StatusCode]='EMPTY_UNPROVEN';
        INSERT [#CurrentCallerPermissionAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'PARTIAL_CONTEXT_IDENTIFIERS',[SourceKey],N'Mindestens eine native Principal-ID ist NULL. Die IDs beschreiben nicht die gesamte wirksame Sicherheitsidentitaet.'
            FROM [#CurrentCallerPermissionAnalysis_callerContexts] WHERE [ContextStatus]='PARTIAL_CURRENT_IDS';
        INSERT [#CurrentCallerPermissionAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'SOURCE_FAILURE',[SourceKey],LEFT(COALESCE([ErrorMessage],N'Die Quelle ist nicht verfuegbar.'),1000)
            FROM [#CurrentCallerPermissionAnalysis_sourceStatus] WHERE [SourceKind]='NATIVE'
              AND [StatusCode] NOT IN ('AVAILABLE_LIMITED','EMPTY_UNPROVEN','SKIPPED');
        IF NOT EXISTS(SELECT 1 FROM [#CurrentCallerPermissionAnalysis_sourceStatus]
                      WHERE [SourceKey] IN ('SERVER_CURRENT_PERMISSIONS','DATABASE_CURRENT_PERMISSIONS') AND [StatusCode]='AVAILABLE_LIMITED')
        BEGIN
            IF EXISTS(SELECT 1 FROM [#CurrentCallerPermissionAnalysis_sourceStatus] WHERE [StatusCode]='EMPTY_UNPROVEN') SET @Status='EMPTY_UNPROVEN';
            ELSE
            BEGIN
                SET @Status='NO_TARGETS';
                SELECT TOP (1) @Status=[StatusCode] FROM [#CurrentCallerPermissionAnalysis_sourceStatus]
                WHERE [SourceKind]='NATIVE' AND [StatusCode] NOT IN ('AVAILABLE_LIMITED','EMPTY_UNPROVEN','SKIPPED') ORDER BY [DatabaseId],[SourceKey];
            END;
        END;
        SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage]
        FROM [#CurrentCallerPermissionAnalysis_sourceStatus] WHERE [ErrorNumber] IS NOT NULL ORDER BY [DatabaseId],[SourceKey];
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#CurrentCallerPermissionAnalysis_serverPermissions])+
            (SELECT COUNT_BIG(*) FROM [#CurrentCallerPermissionAnalysis_databasePermissions]);
        INSERT [#CurrentCallerPermissionAnalysis_moduleStatus] VALUES
            (N'USP_CurrentCallerPermissionAnalysis',@CapturedAtUtc,@Status,1,@Rows,N'Native SERVER-/DATABASE-Rechte im aktiven Kontext; RowCount summiert die beiden ausgegebenen Rechtemengen. Keine konkrete Objektzugriffs- oder vollstaendige Tokenanalyse.');
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'CurrentCallerPermissionAnalysis' AS [resultName],1 AS [schemaVersion],
                @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],@Error AS [errorNumber],@Message AS [errorMessage]
                FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#CurrentCallerPermissionAnalysis_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_callerContexts nvarchar(max)=(SELECT * FROM [#CurrentCallerPermissionAnalysis_callerContexts] ORDER BY [DatabaseId],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_serverPermissions nvarchar(max)=(SELECT * FROM [#CurrentCallerPermissionAnalysis_serverPermissions] ORDER BY [EntityName],[SubentityName],[PermissionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_databasePermissions nvarchar(max)=(SELECT * FROM [#CurrentCallerPermissionAnalysis_databasePermissions] ORDER BY [DatabaseId],[EntityName],[SubentityName],[PermissionName] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#CurrentCallerPermissionAnalysis_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#CurrentCallerPermissionAnalysis_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"callerContexts":',COALESCE(@Json_callerContexts,N'[]'),N',"serverPermissions":',COALESCE(@Json_serverPermissions,N'[]'),N',"databasePermissions":',COALESCE(@Json_databasePermissions,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#CurrentCallerPermissionAnalysis_moduleStatus];
            SELECT * FROM [#CurrentCallerPermissionAnalysis_callerContexts] ORDER BY [DatabaseId],[SourceKey];
            SELECT * FROM [#CurrentCallerPermissionAnalysis_serverPermissions] ORDER BY [EntityName],[SubentityName],[PermissionName];
            SELECT * FROM [#CurrentCallerPermissionAnalysis_databasePermissions] ORDER BY [DatabaseId],[EntityName],[SubentityName],[PermissionName];
            SELECT * FROM [#CurrentCallerPermissionAnalysis_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey];
            SELECT * FROM [#CurrentCallerPermissionAnalysis_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [CurrentCallerPermissionOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable] FROM [#CurrentCallerPermissionAnalysis_Map] ORDER BY [ResultName];
            OPEN [CurrentCallerPermissionOutput];FETCH NEXT FROM [CurrentCallerPermissionOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#CurrentCallerPermissionAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,@ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN SET @FailureError=COALESCE(@TableError,51010);RAISERROR(N'%s',16,1,@TableMessage);END;
                FETCH NEXT FROM [CurrentCallerPermissionOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [CurrentCallerPermissionOutput];DEALLOCATE [CurrentCallerPermissionOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            CREATE TABLE [#CurrentCallerPermissionAnalysis_Console]
            ([Scope] varchar(8) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[DatabaseId] int NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
             [EntityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[SubentityName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
             [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
             [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
            INSERT [#CurrentCallerPermissionAnalysis_Console]
                SELECT 'SERVER',NULL,NULL,[EntityName],[SubentityName],[PermissionName],@Status,'SERVER_CURRENT_PERMISSIONS',NULL,NULL FROM [#CurrentCallerPermissionAnalysis_serverPermissions]
                UNION ALL SELECT 'DATABASE',[DatabaseId],[DatabaseName],[EntityName],[SubentityName],[PermissionName],@Status,'DATABASE_CURRENT_PERMISSIONS',NULL,NULL FROM [#CurrentCallerPermissionAnalysis_databasePermissions];
            INSERT [#CurrentCallerPermissionAnalysis_Console]
                SELECT 'SOURCE',[DatabaseId],[DatabaseName],NULL,NULL,NULL,[StatusCode],[SourceKey],NULL,
                       COALESCE([ErrorMessage],N'Diese Quellenmenge ist nicht als vollstaendige erfolgreiche Rechtebewertung belegt.')
                FROM [#CurrentCallerPermissionAnalysis_sourceStatus] WHERE [StatusCode] NOT IN ('AVAILABLE','AVAILABLE_LIMITED','SKIPPED');
            INSERT [#CurrentCallerPermissionAnalysis_Console]
                SELECT CASE WHEN [WarningCode] IN ('CURRENT_CONTEXT_BOUNDARY','SECURABLE_LEVEL_BOUNDARY') THEN 'INFO' ELSE 'WARNING' END,
                       [DatabaseId],[DatabaseName],NULL,NULL,NULL,CASE WHEN [WarningCode] IN ('CURRENT_CONTEXT_BOUNDARY','SECURABLE_LEVEL_BOUNDARY') THEN 'INFO' ELSE 'WARNING' END,[SourceKey],[WarningCode],[Detail]
                FROM [#CurrentCallerPermissionAnalysis_warnings] WHERE [WarningCode] NOT IN ('SOURCE_FAILURE','EMPTY_PERMISSION_SOURCE_UNPROVEN','TARGET_SELECTION');
            IF NOT EXISTS(SELECT 1 FROM [#CurrentCallerPermissionAnalysis_serverPermissions]) AND NOT EXISTS(SELECT 1 FROM [#CurrentCallerPermissionAnalysis_databasePermissions])
                INSERT [#CurrentCallerPermissionAnalysis_Console] VALUES ('STATUS',NULL,NULL,NULL,NULL,NULL,@Status,NULL,NULL,N'Keine ausgegebene Rechtezeile; Quellenstatus und Warnungen liefern die Aussagegrenze.');
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#CurrentCallerPermissionAnalysis_Console',
                @ResultLabel=N'Effektive Rechte des aktuellen Ausfuehrungskontexts',
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
        SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
