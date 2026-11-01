USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DatabasePrincipalAnalysis
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Die Procedure zeigt sichtbare Datenbankprincipals, direkte
               Rollenmitgliedschaften, explizite Rechte, Schemaownership und
               begrenzte Bindungen zu sichtbaren Serverprincipals.
Grenzen      : Keine effektiven Rechte oder externe Gruppenauflosung. Fehlende
               sichtbare SID-Treffer beweisen keine verwaisten Identitaeten.
Datenschutz  : SID-Vergleiche sind intern; keine SID-Ausgabe und kein Zugriff
               auf Passwort-Hashes, Credentials, Schluessel oder Nutzdaten.
Nebenwirkung : Rein lesend; keine Berechtigungs- oder Ownershipaenderung.
===============================================================================
*/
CREATE OR ALTER PROCEDURE [monitor].[USP_DatabasePrincipalAnalysis]
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
        @ServerSourceAvailable bit=0,@ContextAvailable bit,@PrincipalSourceAvailable bit,
        @OwnerSid varbinary(85),@OwnerCount bigint,@OwnerId int,@OwnerName sysname,@OwnerType char(1),
        @OwnerBindingStatus varchar(40),@StateDescription nvarchar(60),@ContainmentDescription nvarchar(60),
        @CrossDatabaseRequested bit;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    IF @Hilfe=1
    BEGIN
        PRINT N'monitor.USP_DatabasePrincipalAnalysis';
        PRINT N'Ohne Filter: alle sichtbaren Online-Benutzerdatenbanken; Systemdatenbanken sind opt-in. DatabaseNames und DatabaseNamePattern sind getrennt.';
        PRINT N'Neun Mengen: moduleStatus, databaseContext, principals, roleMemberships, permissions, schemaOwners, loginBindings, sourceStatus, warnings.';
        PRINT N'Keine effektiven Rechte oder sicheren Orphan-Negativschluesse. Fehler sind ueber Status, Diagnose-OUTPUT und RETURN zu pruefen.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. NULL, N'''' oder eine nur aus äußeren U+0020-Leerzeichen bestehende Eingabe schränken die Datenbankauswahl nicht ein. Andernfalls wird eine bracket-aware Pipe-Liste aus einzelnen Datenbanknamen erwartet; ein Pipe innerhalb eines geklammerten Namens ist Inhalt, und ]] maskiert dort eine schließende Klammer. Ungültige Elemente und doppelte gültige Namen führen zur Zurückweisung; Vorgesehen sind einteilige Namen. Der Parser übernimmt den letzten PARSENAME-Bestandteil, verlangt einen nichtleeren Wert bis 128 Zeichen und NULL für den zweiten Bestandteil; dritte und vierte Bestandteile werden nicht separat validiert. Ein rohes Listenelement ist auf 4.000 Zeichen begrenzt. Die exakten Namen werden case-sensitive verglichen. Nur eine aktive nichtleere Liste ist mit einem nicht-NULL-Pattern unvereinbar. Ohne beide Filter wählt die gemeinsame Kandidatenvorbereitung alle für den Caller sichtbaren, zugreifbaren Online-Datenbanken ohne Datenbanksnapshots; Systemdatenbanken hängen zusätzlich von @SystemdatenbankenEinbeziehen ab. Nicht verfügbare explizit angeforderte Namen erscheinen als Auswahlwarnungen; daraus wird Abwesenheit nicht sicher abgeleitet.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Systemdatenbanken mit Datenbank-IDs bis einschließlich 4 aus; 1 erlaubt ihre Aufnahme. NULL wird vom Auswahlhelfer als ungültiger Parameter zurückgewiesen. Systemdatenbanken müssen mit 1 ausdrücklich einbezogen werden. Die Auswahl bleibt auf sichtbare, online befindliche und für den aktuellen Login zugreifbare Datenbanken begrenzt.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Patternfilter. Sonst werden äußere Leerzeichen entfernt und ein Präfix LIKE:, REGEX: oder REGEXI: ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der Inhalt nach einem Präfix wird nicht erneut getrimmt. Ein leerer oder nur aus Leerzeichen bestehender Wert sowie ein leeres Präfix-Ergebnis sind ungültig. Eine aktive nichtleere exakte Namensliste und ein nicht-NULL-Pattern sind unvereinbar. LIKE vergleicht case-sensitive. REGEX ist case-sensitive, REGEXI case-insensitive; Regexausführung verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Der Parser prüft keine Regexsyntax; ein ungültiges Regexmuster kann daher erst bei der Ausführung fehlschlagen. Der LIKE-Inhalt ist ein SQL-Server-LIKE-Muster: % steht für beliebig viele Zeichen, _ für ein Zeichen, [...] für Zeichenklassen. Die Abfrage definiert keine eigene ESCAPE-Klausel. REGEX/REGEXI-Inhalt wird unverändert an REGEXP_LIKE mit Flag c beziehungsweise i übergeben; Parservalidierung ersetzt keine Regexsyntaxprüfung.';
        PRINT N'@MaxZeilen int; Default: 1000. NULL oder 0 bedeutet kein Ausgabelimit; ein negativer Wert ist ungültig. Ein positiver Wert begrenzt jeweils separat die fünf Fachmengen principals, roleMemberships, permissions, schemaOwners und loginBindings global über alle gewählten Datenbanken. Die Kürzung erfolgt nach der jeweiligen dokumentierten Sortierung; bei identischen Sortierschlüsseln ist keine zusätzliche Tie-Break-Garantie festgelegt. databaseContext, moduleStatus, sourceStatus und warnings werden nicht gekappt. Die vollständigen sichtbaren Quellmengen werden vor der Kürzung materialisiert; das Limit reduziert daher nicht die Kataloglesearbeit oder die zuvor gebildeten Namens- und SID-Zuordnungen. ObservedRows und ReturnedRows sowie IsLimited halten Quellmenge und Ausgabe auseinander.';
        PRINT N'@LockTimeoutMs int; Default: 0. NULL, negative Werte und Werte über 60000 sind ungültig; 0 bis 60000 sind Millisekunden und der Vorgabewert 0 setzt NOWAIT für die dynamischen fachlichen Quellbatches. Ein positiver Wert erlaubt diesen Batches entsprechend viele Millisekunden auf eine Sperre zu warten. Bei eingehendem Caller-LOCK_TIMEOUT 0 verwendet die Procedure für eigene Temp-DDL-Statements bis zu 1000 ms je Statement; dies ist kein zusätzliches Quellzeitbudget. Am Ende wird der eingehende LOCK_TIMEOUT-Wert wiederhergestellt. Der Parameter ist keine Gesamtzeitgrenze für den Aufruf und begründet keine atomare Aufnahme.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. NULL oder ein anderer als die vier folgenden Werte ist ungültig. Groß-/Kleinschreibung und äußere Leerzeichen werden normalisiert. CONSOLE erzeugt eine formatierte Ergebnisübersicht; RAW liefert neun native Resultsets; TABLE schreibt die angeforderten Mengen in lokale Temp-Tabellen; NONE unterdrückt fachliche Resultsets. JSON kann unabhängig von dieser Auswahl zusätzlich über @Json ausgegeben werden. Bei jeder Auswahl außer TABLE muss @ResultTablesJson NULL, leer oder nur aus äußeren U+0020-Leerzeichen bestehen.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Außer bei ResultSetArt=TABLE muss der Wert NULL, leer oder nur aus äußeren U+0020-Leerzeichen sein; ein anderer Inhalt ist INVALID_PARAMETER. Im TABLE-Modus ist ein nichtleeres gültiges JSON-Objekt erforderlich, das mindestens eine Zuordnung von einem Resultsetnamen zu einem lokalen Temp-Tabellennamen enthält. Erlaubte Namen sind exakt moduleStatus, databaseContext, principals, roleMemberships, permissions, schemaOwners, loginBindings, sourceStatus und warnings; jeder Name darf nur einmal, jedes Ziel nur einmal (case-insensitive) vorkommen. Jeder Wert muss eine nichtleere Zeichenfolge sein. Ziele müssen vorhandene, leere lokale #Temp-Tabellen mit höchstens 116 Zeichen und genau einer Seed-Spalte bezeichnen; ##-, #Monitor*- und permanente Ziele sind unzulässig. Die Vorprüfung erfolgt vor fachlichen Katalogzugriffen. Der Schreiber passt die Seed-Struktur beim Schreiben an die native Quellstruktur an. Die Schlüssel bedeuten: moduleStatus Modulstatus, databaseContext Datenbankkontext und Identitätsbindung, principals Datenbankprincipals, roleMemberships direkte Rollenmitgliedschaften, permissions explizite Datenbankrechte, schemaOwners Schemaownership, loginBindings sichtbare Loginbindungen, sourceStatus Quellenstatus und warnings Warnungen.';
        PRINT N'@JsonErzeugen bit; Default: 0. 1 erzeugt zusätzlich das JSON-Dokument in @Json, unabhängig von ResultSetArt; 0 erzeugt es nicht. NULL wird nicht gesondert zurückgewiesen und verhält sich im IF-Test wie nicht aktiviert. Die neun Arrays entsprechen den neun fachlichen Mengen, ergänzt um meta; Zeilen enthalten NULL-Felder. Bei einem gefangenen äußeren Fehler bleibt @Json NULL. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Als OUTPUT-Parameter muss die Variable des Aufrufers mit OUTPUT gebunden werden, damit das Ergebnis zurückgegeben wird. Zu Aufrufbeginn setzt die Procedure den Parameter auf NULL; bei @JsonErzeugen=1 enthält er nach erfolgreicher Verarbeitung meta und die neun geordneten JSON-Arrays mit INCLUDE_NULL_VALUES. Ohne Aktivierung und nach einem gefangenen äußeren Fehler bleibt der Wert NULL. Die JSON-Erzeugungszeit macht die getrennten Quellaufnahmen nicht atomar. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; der Empfänger darf ausgelassen werden.';
        PRINT N'@PrintMeldungen bit; Default: 1. 1 (auch Vorgabewert) erlaubt die vorgesehenen PRINT- beziehungsweise RAISERROR-Meldungen mit Schweregrad 10 und NOWAIT: Die Hilfezeilen erscheinen bei @Hilfe=1 unabhängig von diesem Schalter; bei ungültigen Parametern, gefangenen äußeren Fehlern und Quellenfehlern mit ermitteltem ErrorNumber werden Diagnosemeldungen gesendet. 0 unterdrückt diese Meldungen. NULL wird nicht validiert und erfüllt die IF-Bedingung für 1 nicht. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. 1 gibt die eingebaute Parameterhilfe und Beispiele aus und beendet die Procedure vor Parameterprüfung oder Katalogzugriff. Dabei werden @StatusCodeOut auf AVAILABLE und @IsPartialOut auf 0 gesetzt; @Json sowie die Fehler-OUTPUTs sind zuvor beim Eintritt auf NULL zurückgesetzt. 0 führt den normalen Aufruf aus. NULL wird nicht zurückgewiesen und wirkt wie nicht aktiviert. Der Hilfestatus bestätigt weder Vollständigkeit noch vollständige Rechte. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Hilfe liefert AVAILABLE; Eingabevalidierung INVALID_PARAMETER. Kandidatenhelferfehler liefern INVALID_PARAMETER für ungültige Auswahl, INTERNAL_ERROR für ein internes Kandidatenschema oder UNAVAILABLE_FEATURE für nicht verfügbare Regex-Voraussetzungen, jeweils mit RETURN 51011. Regulär gilt AVAILABLE_LIMITED, sobald eine native DB-Quelle diesen erfolgreichen, aber unbewiesenen Metadatenstatus besitzt. Andernfalls wird der erste Status ungleich AVAILABLE_LIMITED/SKIPPED nach DatabaseName, SourceKey gewählt: DENIED_PERMISSION für verweigerte Quelle, TIMEOUT für Sperrtimeout, DATABASE_UNAVAILABLE für nicht verfügbaren Datenbankkontext, ERROR_HANDLED für andere behandelte Quellenfehler, STATUS_UNAVAILABLE als fehlende Statuskennung oder SYSTEM_DATABASE_EXCLUDED für einen ausgeschlossenen expliziten Systemnamen. DATABASE_UNAVAILABLE kann ebenso aus der Auswahl stammen. Sonstige äußere Fehler liefern ERROR_HANDLED. Fehlernummer/-meldung werden davon getrennt nach DatabaseId, SourceKey priorisiert. Reguläre Verarbeitung und Hilfe liefern RETURN 0; ein äußerer Fehler liefert seinen Diagnosecode. Optionaler OUTPUT-Empfänger vom Typ varchar(40); zum Empfangen eine Variable mit OUTPUT binden, andernfalls auslassen. Der Eintritt setzt auch einen anfänglichen NULL- oder anderen Wert zunächst auf NULL.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Bei Eintritt wird der Empfänger auf NULL gesetzt. Die Hilfe setzt 0. Ungültige Eingaben, reguläre Fachverarbeitung und gefangene äußere Fehler setzen 1; auch AVAILABLE_LIMITED mit vollständig lesbaren angeforderten Quellen bleibt wegen des begrenzten Aussageumfangs partiell. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Bei Eintritt wird der Empfänger auf NULL gesetzt. Sie bleibt NULL, wenn kein Fehlercode ermittelt wurde. Ungültige Parameter liefern 51011; bei Quellenfehlern wird der erste vorhandene native ErrorNumber-Wert nach Datenbank-ID und SourceKey ausgewählt. Der äußere CATCH liefert den für den Fehlerpfad gesetzten Code oder den abgefangenen SQL-Fehlercode; TABLE-Fehler können dabei aus dem Vorbereitungs- oder Schreibhelfer stammen. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei Eintritt wird der Empfänger auf NULL gesetzt. Sie bleibt NULL, wenn kein Fehlertext ermittelt wurde. Bei ungültigen Parametern enthält sie die Validierungsdiagnose; bei regulärer Verarbeitung mit Quellenfehlern stammt sie aus dem ersten Fehler nach Datenbank-ID und SourceKey. Der äußere CATCH gibt die abgefangene Meldung auf höchstens 2048 Zeichen begrenzt zurück. Die OUTPUT-Diagnose ersetzt weder Statusprüfung noch RETURN-Code. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.';
        PRINT N'EXEC [monitor].[USP_DatabasePrincipalAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_DatabasePrincipalAnalysis]
      @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];';
        PRINT N'CREATE TABLE [#DatabasePrincipalAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N''{"principals":"#DatabasePrincipalAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@Map;
    SELECT * FROM [#DatabasePrincipalAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#DatabasePrincipalAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#DatabasePrincipalAnalysis_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_DatabasePrincipalAnalysis] @Hilfe=1;';



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
    CREATE TABLE [#DatabasePrincipalAnalysis_moduleStatus]
    (
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_databaseContext]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContainmentDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerPrincipalId] int NULL, [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerPrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerBindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_principals]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [AuthenticationType] int NULL, [AuthenticationTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [DefaultSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CreatedAt] datetime NULL, [ModifiedAt] datetime NULL, [IsFixedRole] bit NULL, [OwningPrincipalId] int NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_roleMemberships]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RolePrincipalId] int NOT NULL, [RoleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MemberPrincipalId] int NOT NULL, [MemberName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_permissions]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [GranteePrincipalId] int NOT NULL, [GranteeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [GrantorPrincipalId] int NOT NULL, [GrantorName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Class] tinyint NOT NULL, [ClassDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MajorId] int NOT NULL, [MinorId] int NOT NULL, [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PermissionState] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PermissionStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_schemaOwners]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SchemaId] int NOT NULL, [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwningPrincipalId] int NOT NULL, [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_loginBindings]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [BindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ServerPrincipalId] int NULL, [ServerPrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_sourceStatus]
    (
        [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_warnings]
    (
        [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#DatabasePrincipalAnalysis_Map]
    ([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
    CREATE TABLE [#DatabasePrincipalAnalysis_Candidates]
    (
        [DatabaseId] int NOT NULL,[DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[IsReadOnly] bit NULL,
        [CompatibilityLevel] tinyint NULL,[CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsSystemDatabase] bit NULL,[RequestedOrdinal] int NULL
    );
    CREATE TABLE [#DatabasePrincipalAnalysis_SelectionWarnings]
    ([RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
    CREATE TABLE [#DatabasePrincipalAnalysis_ServerCache]
    ([PrincipalId] int NOT NULL,[PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Sid] varbinary(85) NULL);
    CREATE TABLE [#DatabasePrincipalAnalysis_PrincipalCache]
    (
        [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [AuthenticationType] int NULL, [AuthenticationTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [DefaultSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CreatedAt] datetime NULL, [ModifiedAt] datetime NULL, [IsFixedRole] bit NULL, [OwningPrincipalId] int NULL, [Sid] varbinary(85) NULL
    );

        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|databaseContext|principals|roleMemberships|permissions|schemaOwners|loginBindings|sourceStatus|warnings',
                @MappingTable=N'#DatabasePrincipalAnalysis_Map',@StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SET @FailureError=51011;
                RAISERROR(N'%s',16,1,@TableMessage);
            END;
        END;
        SET @Started=SYSUTCDATETIME();
        EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames,
            @SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen,@DatabaseNamePattern=@DatabaseNamePattern,
            @StatusCode=@TableStatus OUTPUT,@ErrorMessage=@TableMessage OUTPUT,
            @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,
            @CandidateTable=N'#DatabasePrincipalAnalysis_Candidates',@WarningTable=N'#DatabasePrincipalAnalysis_SelectionWarnings';
        IF COALESCE(@TableStatus,'')<>'AVAILABLE'
        BEGIN
            SELECT @FailureError=51011,@FailureStatus=COALESCE(@TableStatus,'STATUS_UNAVAILABLE');
            RAISERROR(N'%s',16,1,@TableMessage);
        END;
        INSERT [#DatabasePrincipalAnalysis_sourceStatus]
            SELECT NULL,[RequestedName],'DATABASE_SELECTION','SELECTION',@Started,SYSUTCDATETIME(),
                   COALESCE([StatusCode],'STATUS_UNAVAILABLE'),'UNPROVEN',NULL,NULL,0,NULL,[ErrorMessage]
            FROM [#DatabasePrincipalAnalysis_SelectionWarnings];
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT NULL,[RequestedName],'TARGET_SELECTION','DATABASE_SELECTION',
                   LEFT(COALESCE([ErrorMessage],N'Der angeforderte Datenbankkontext ist nicht verfuegbar.'),1000)
            FROM [#DatabasePrincipalAnalysis_SelectionWarnings];
        SET LOCK_TIMEOUT 0;
        SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; ';
        -- TARGET_IDENTITY_GUARD_BEGIN
        SET @IdentityGuard=N'IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [sys].[databases] WITH (NOLOCK)
            WHERE [database_id]=DB_ID() AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS AND [create_date]=@Created)
            THROW 51012,N''Target database identity changed or is not available for this source.'',1; ';
        -- TARGET_IDENTITY_GUARD_END
        SET @Started=SYSUTCDATETIME();
        IF EXISTS(SELECT 1 FROM [#DatabasePrincipalAnalysis_Candidates])
        BEGIN
        BEGIN TRY
            SET @Sql=@SetLock+N'INSERT [#DatabasePrincipalAnalysis_ServerCache]
                SELECT [principal_id],[name],[type],[sid] FROM [sys].[server_principals] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @Sql,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
            SET @ServerSourceAvailable=1;
            INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                (NULL,NULL,'SERVER_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                 'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,NULL,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#DatabasePrincipalAnalysis_ServerCache];
            INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                (NULL,NULL,'SERVER_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
        END CATCH;
        END
        ELSE
            INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                (NULL,NULL,'SERVER_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                 'SKIPPED','UNPROVEN',NULL,NULL,0,NULL,NULL);

        DECLARE [DatabasePrincipalTargets] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId],[DatabaseName] FROM [#DatabasePrincipalAnalysis_Candidates] ORDER BY [DatabaseId];
        OPEN [DatabasePrincipalTargets];
        FETCH NEXT FROM [DatabasePrincipalTargets] INTO @DatabaseId,@DatabaseName;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SELECT @QuotedDatabase=QUOTENAME(@DatabaseName),@ContextAvailable=0,@PrincipalSourceAvailable=0,
                   @OwnerSid=NULL,@DatabaseCreatedAt=NULL,@OwnerCount=0,@OwnerId=NULL,@OwnerName=NULL,@OwnerType=NULL,
                   @StateDescription=NULL,@ContainmentDescription=NULL,@OwnerBindingStatus='SOURCE_UNAVAILABLE';
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'SELECT @Sid=[owner_sid],@State=[state_desc],@Containment=[containment_desc],@Created=[create_date],
                       @Available=1
                FROM [master].[sys].[databases] WITH (NOLOCK)
                WHERE [database_id]=@Id
                  AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Name COLLATE SQL_Latin1_General_CP1_CS_AS;';
                EXEC [sys].[sp_executesql] @Sql,
                    N'@Id int,@Name sysname,@Sid varbinary(85) OUTPUT,@State nvarchar(60) OUTPUT,@Containment nvarchar(60) OUTPUT,@Created datetime OUTPUT,@Available bit OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Sid=@OwnerSid OUTPUT,@State=@StateDescription OUTPUT,
                    @Containment=@ContainmentDescription OUTPUT,@Created=@DatabaseCreatedAt OUTPUT,@Available=@ContextAvailable OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN @ContextAvailable=1 THEN 'AVAILABLE_LIMITED' ELSE 'DATABASE_UNAVAILABLE' END,
                     CASE WHEN @ContextAvailable=1 THEN 'VISIBLE_ONLY' ELSE 'UNPROVEN' END,
                     CASE WHEN @ContextAvailable=1 THEN CONVERT(bigint,1) ELSE NULL END,
                     CASE WHEN @ContextAvailable=1 THEN CONVERT(bigint,1) ELSE NULL END,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_CONTEXT','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            IF @ContextAvailable=1 AND @ServerSourceAvailable=1
            BEGIN
                SELECT @OwnerCount=COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_ServerCache] WHERE [Sid]=@OwnerSid;
                IF @OwnerCount=1
                    SELECT @OwnerId=[PrincipalId],@OwnerName=[PrincipalName],@OwnerType=[PrincipalType]
                    FROM [#DatabasePrincipalAnalysis_ServerCache] WHERE [Sid]=@OwnerSid;
                SET @OwnerBindingStatus=CASE
                    WHEN @OwnerSid IS NULL OR DATALENGTH(@OwnerSid)=0 THEN 'OWNER_SID_UNAVAILABLE'
                    WHEN @OwnerCount>1 THEN 'AMBIGUOUS_VISIBLE_OWNER_MATCH'
                    WHEN @OwnerCount=1 AND @OwnerType IN ('S','U') THEN 'MATCHED_VISIBLE_OWNER'
                    WHEN @OwnerCount=1 THEN 'UNSUPPORTED_PRINCIPAL_TYPE'
                    ELSE 'NO_VISIBLE_OWNER_MATCH' END;
            END;
            INSERT [#DatabasePrincipalAnalysis_databaseContext] VALUES
                (@DatabaseId,@DatabaseName,@StateDescription,@ContainmentDescription,@OwnerId,@OwnerName,@OwnerType,@OwnerBindingStatus);

            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#DatabasePrincipalAnalysis_PrincipalCache] SELECT @Id,@Name,[p].[principal_id],[p].[name],[p].[type],[p].[type_desc],[p].[authentication_type],[p].[authentication_type_desc],[p].[default_schema_name],[p].[create_date],[p].[modify_date],[p].[is_fixed_role],[p].[owning_principal_id],[p].[sid] FROM [sys].[database_principals] AS [p] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;'+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_principals]([DatabaseId],[DatabaseName],[PrincipalId],[PrincipalName],[PrincipalType],[PrincipalTypeDescription],[AuthenticationType],[AuthenticationTypeDescription],[DefaultSchemaName],[CreatedAt],[ModifiedAt],[IsFixedRole],[OwningPrincipalId])
                    SELECT [DatabaseId],[DatabaseName],[PrincipalId],[PrincipalName],[PrincipalType],[PrincipalTypeDescription],[AuthenticationType],[AuthenticationTypeDescription],[DefaultSchemaName],[CreatedAt],[ModifiedAt],[IsFixedRole],[OwningPrincipalId] FROM [#DatabasePrincipalAnalysis_PrincipalCache] WHERE [DatabaseId]=@DatabaseId;
                SET @PrincipalSourceAvailable=1;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                     'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#DatabasePrincipalAnalysis_PrincipalCache] WHERE [DatabaseId]=@DatabaseId;
                DELETE FROM [#DatabasePrincipalAnalysis_principals] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_PRINCIPALS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#DatabasePrincipalAnalysis_roleMemberships] SELECT @Id,@Name,[m].[role_principal_id],[r].[PrincipalName],[m].[member_principal_id],[u].[PrincipalName] FROM [sys].[database_role_members] AS [m] WITH (NOLOCK) LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [r] ON [r].[DatabaseId]=@Id AND [r].[PrincipalId]=[m].[role_principal_id] LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [u] ON [u].[DatabaseId]=@Id AND [u].[PrincipalId]=[m].[member_principal_id]; SET @Rows=@@ROWCOUNT;'+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_ROLE_MEMBERS','NATIVE',@Started,SYSUTCDATETIME(),
                     'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#DatabasePrincipalAnalysis_roleMemberships] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_ROLE_MEMBERS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#DatabasePrincipalAnalysis_permissions] SELECT @Id,@Name,[p].[grantee_principal_id],[u].[PrincipalName],[p].[grantor_principal_id],[g].[PrincipalName],[p].[class],[p].[class_desc],[p].[major_id],[p].[minor_id],[p].[permission_name],[p].[state],[p].[state_desc] FROM [sys].[database_permissions] AS [p] WITH (NOLOCK) LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [u] ON [u].[DatabaseId]=@Id AND [u].[PrincipalId]=[p].[grantee_principal_id] LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [g] ON [g].[DatabaseId]=@Id AND [g].[PrincipalId]=[p].[grantor_principal_id]; SET @Rows=@@ROWCOUNT;'+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#DatabasePrincipalAnalysis_permissions] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_PERMISSIONS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            BEGIN TRY
                SET @Sql=@SetLock+N'USE '+@QuotedDatabase+N'; '+@IdentityGuard+N'INSERT [#DatabasePrincipalAnalysis_schemaOwners] SELECT @Id,@Name,[s].[schema_id],[s].[name],[s].[principal_id],[p].[PrincipalName] FROM [sys].[schemas] AS [s] WITH (NOLOCK) LEFT JOIN [#DatabasePrincipalAnalysis_PrincipalCache] AS [p] ON [p].[DatabaseId]=@Id AND [p].[PrincipalId]=[s].[principal_id]; SET @Rows=@@ROWCOUNT;'+@IdentityGuard;
                EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Rows bigint OUTPUT',
                    @Id=@DatabaseId,@Name=@DatabaseName,@Created=@DatabaseCreatedAt,@Rows=@Observed OUTPUT;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_SCHEMAS','NATIVE',@Started,SYSUTCDATETIME(),
                     'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
            END TRY
            BEGIN CATCH
                DELETE FROM [#DatabasePrincipalAnalysis_schemaOwners] WHERE [DatabaseId]=@DatabaseId;
                INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                    (@DatabaseId,@DatabaseName,'DATABASE_SCHEMAS','NATIVE',@Started,SYSUTCDATETIME(),
                     CASE WHEN ERROR_NUMBER() IN (229,297,300,371,916) THEN 'DENIED_PERMISSION'
                          WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT'
                          WHEN ERROR_NUMBER() IN (911,924,926,927,942,945,952,978,4060,51012) THEN 'DATABASE_UNAVAILABLE'
                          ELSE 'ERROR_HANDLED' END,
                     'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),LEFT(ERROR_MESSAGE(),2048));
            END CATCH;
            SET @Started=SYSUTCDATETIME();
            INSERT [#DatabasePrincipalAnalysis_loginBindings]
                SELECT [p].[DatabaseId],[p].[DatabaseName],[p].[PrincipalId],[p].[PrincipalName],
                       CASE WHEN [p].[PrincipalName] IN (N'dbo',N'guest',N'sys',N'INFORMATION_SCHEMA') THEN 'NOT_APPLICABLE'
                            WHEN [p].[AuthenticationType]=2 THEN 'DATABASE_AUTHENTICATED'
                            WHEN COALESCE([p].[AuthenticationType],0)<>1 OR [p].[PrincipalType]<>'S' THEN 'NOT_APPLICABLE'
                            WHEN @ServerSourceAvailable=0 THEN 'SOURCE_UNAVAILABLE'
                            WHEN [s].[PrincipalId] IS NOT NULL THEN 'MATCHED_VISIBLE_LOGIN'
                            ELSE 'NO_VISIBLE_LOGIN_MATCH' END,
                       CASE WHEN [p].[AuthenticationType]=1 AND [p].[PrincipalType]='S'
                                 AND [p].[PrincipalName] NOT IN (N'dbo',N'guest',N'sys',N'INFORMATION_SCHEMA') THEN [s].[PrincipalId] ELSE NULL END,
                       CASE WHEN [p].[AuthenticationType]=1 AND [p].[PrincipalType]='S'
                                 AND [p].[PrincipalName] NOT IN (N'dbo',N'guest',N'sys',N'INFORMATION_SCHEMA') THEN [s].[PrincipalName] ELSE NULL END
                FROM [#DatabasePrincipalAnalysis_PrincipalCache] AS [p]
                OUTER APPLY
                (SELECT TOP (1) [l].[PrincipalId],[l].[PrincipalName]
                 FROM [#DatabasePrincipalAnalysis_ServerCache] AS [l]
                 WHERE [l].[PrincipalType]='S' AND [l].[Sid]=[p].[Sid] ORDER BY [l].[PrincipalId]) AS [s]
                WHERE [p].[DatabaseId]=@DatabaseId;
            SET @Observed=@@ROWCOUNT;
            INSERT [#DatabasePrincipalAnalysis_sourceStatus] VALUES
                (@DatabaseId,@DatabaseName,'LOGIN_BINDINGS','DERIVED',@Started,SYSUTCDATETIME(),
                 CASE WHEN @PrincipalSourceAvailable=1 AND @ServerSourceAvailable=1 THEN 'AVAILABLE_LIMITED' ELSE 'STATUS_UNAVAILABLE' END,
                 CASE WHEN @PrincipalSourceAvailable=1 AND @ServerSourceAvailable=1 THEN 'VISIBLE_ONLY' ELSE 'UNPROVEN' END,
                 CASE WHEN @PrincipalSourceAvailable=1 THEN @Observed ELSE NULL END,
                 CASE WHEN @PrincipalSourceAvailable=1 THEN @Observed ELSE NULL END,0,NULL,NULL);

            FETCH NEXT FROM [DatabasePrincipalTargets] INTO @DatabaseId,@DatabaseName;
        END;
        CLOSE [DatabasePrincipalTargets]; DEALLOCATE [DatabasePrincipalTargets];

        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[PrincipalId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_principals])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_principals] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='DATABASE_PRINCIPALS' AND [s].[ObservedRows] IS NOT NULL;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[RolePrincipalId],[MemberPrincipalId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_roleMemberships])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_roleMemberships] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='DATABASE_ROLE_MEMBERS' AND [s].[ObservedRows] IS NOT NULL;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[GranteePrincipalId],[Class],[MajorId],[MinorId],[PermissionName],[PermissionState],[GrantorPrincipalId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_permissions])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_permissions] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='DATABASE_PERMISSIONS' AND [s].[ObservedRows] IS NOT NULL;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[SchemaId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_schemaOwners])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_schemaOwners] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='DATABASE_SCHEMAS' AND [s].[ObservedRows] IS NOT NULL;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [DatabaseId],[PrincipalId]) AS [OutputOrdinal] FROM [#DatabasePrincipalAnalysis_loginBindings])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        UPDATE [s] SET [ReturnedRows]=[r].[RowCount],
            [IsLimited]=CASE WHEN [s].[ObservedRows]>[r].[RowCount] THEN 1 ELSE 0 END
        FROM [#DatabasePrincipalAnalysis_sourceStatus] AS [s]
        CROSS APPLY(SELECT COUNT_BIG(*) AS [RowCount] FROM [#DatabasePrincipalAnalysis_loginBindings] AS [v]
                    WHERE [v].[DatabaseId]=[s].[DatabaseId]) AS [r]
        WHERE [s].[SourceKey]='LOGIN_BINDINGS' AND [s].[ObservedRows] IS NOT NULL;
        INSERT [#DatabasePrincipalAnalysis_warnings] VALUES
            (NULL,NULL,'METADATA_COMPLETENESS_UNPROVEN',NULL,
             N'Alle Mengen beschreiben sichtbare lokale Katalogmetadaten. Implizite Rollenrechte, externe Gruppen und effektive Berechtigungen sind nicht ausgewertet.');
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'OUTPUT_LIMIT',[SourceKey],
                   N'Das globale Fachlimit kappt die Ausgabe. Namens- und SID-Bindungen verwenden die zuvor materialisierte ungekappte Sicht; das Limit begrenzt nicht die Kataloglesearbeit.'
            FROM [#DatabasePrincipalAnalysis_sourceStatus] WHERE [IsLimited]=1;
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'SOURCE_UNAVAILABLE',[SourceKey],
                   N'Die Quelle oder eine benoetigte Zuordnung ist nicht verfuegbar. Fehlende sichtbare Werte beweisen keine Abwesenheit.'
            FROM [#DatabasePrincipalAnalysis_sourceStatus]
            WHERE [VisibilityScope]='UNPROVEN' AND [StatusCode]<>'SKIPPED' AND [SourceKind]<>'SELECTION';
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT [DatabaseId],[DatabaseName],'OWNER_BINDING_LIMITED','DATABASE_CONTEXT',
                   CONCAT(N'Ownerbindung=',[OwnerBindingStatus],N'; keine Directoryaufloesung oder Ownereignungspruefung.')
            FROM [#DatabasePrincipalAnalysis_databaseContext] WHERE [OwnerBindingStatus]<>'MATCHED_VISIBLE_OWNER';
        INSERT [#DatabasePrincipalAnalysis_warnings]
            SELECT DISTINCT [DatabaseId],[DatabaseName],'NO_VISIBLE_LOGIN_MATCH','LOGIN_BINDINGS',
                   N'Mindestens ein sichtbarer instanzgebundener SQL-Benutzer besitzt keinen sichtbaren SQL-Login-Treffer. Eingeschraenkte Serversicht bleibt eine moegliche Ursache; kein Orphan-Nachweis.'
            FROM [#DatabasePrincipalAnalysis_loginBindings] WHERE [BindingStatus]='NO_VISIBLE_LOGIN_MATCH';
        SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage]
            FROM [#DatabasePrincipalAnalysis_sourceStatus] WHERE [ErrorNumber] IS NOT NULL
            ORDER BY [DatabaseId],[SourceKey];
        IF NOT EXISTS(SELECT 1 FROM [#DatabasePrincipalAnalysis_sourceStatus]
                      WHERE [DatabaseId] IS NOT NULL AND [SourceKind]='NATIVE' AND [StatusCode]='AVAILABLE_LIMITED')
            SELECT TOP (1) @Status=[StatusCode],@Message=COALESCE(@Message,[ErrorMessage])
            FROM [#DatabasePrincipalAnalysis_sourceStatus] WHERE [StatusCode] NOT IN ('AVAILABLE_LIMITED','SKIPPED')
            ORDER BY [DatabaseName],[SourceKey];
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_principals])+
            (SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_roleMemberships])+
            (SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_permissions])+
            (SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_schemaOwners])+
            (SELECT COUNT_BIG(*) FROM [#DatabasePrincipalAnalysis_loginBindings]);
        INSERT [#DatabasePrincipalAnalysis_moduleStatus] VALUES
            (N'USP_DatabasePrincipalAnalysis',@CapturedAtUtc,@Status,1,@Rows,
             N'Getrennte Katalogmomentaufnahmen im Caller-Kontext; RowCount summiert die fuenf begrenzbaren Fachmengen. Sichtbare Bindungen sind keine vollstaendige effektive Berechtigungsanalyse.');
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'DatabasePrincipalAnalysis' AS [resultName],1 AS [schemaVersion],
                @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],
                @Error AS [errorNumber],@Message AS [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_databaseContext nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_databaseContext] ORDER BY [DatabaseId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_principals nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_principals] ORDER BY [DatabaseId],[PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_roleMemberships nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_roleMemberships] ORDER BY [DatabaseId],[RolePrincipalId],[MemberPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_permissions nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_permissions] ORDER BY [DatabaseId],[GranteePrincipalId],[Class],[MajorId],[MinorId],[PermissionName],[PermissionState],[GrantorPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_schemaOwners nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_schemaOwners] ORDER BY [DatabaseId],[SchemaId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_loginBindings nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_loginBindings] ORDER BY [DatabaseId],[PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#DatabasePrincipalAnalysis_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"databaseContext":',COALESCE(@Json_databaseContext,N'[]'),N',"principals":',COALESCE(@Json_principals,N'[]'),N',"roleMemberships":',COALESCE(@Json_roleMemberships,N'[]'),N',"permissions":',COALESCE(@Json_permissions,N'[]'),N',"schemaOwners":',COALESCE(@Json_schemaOwners,N'[]'),N',"loginBindings":',COALESCE(@Json_loginBindings,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#DatabasePrincipalAnalysis_moduleStatus];
            SELECT * FROM [#DatabasePrincipalAnalysis_databaseContext] ORDER BY [DatabaseId];
            SELECT * FROM [#DatabasePrincipalAnalysis_principals] ORDER BY [DatabaseId],[PrincipalId];
            SELECT * FROM [#DatabasePrincipalAnalysis_roleMemberships] ORDER BY [DatabaseId],[RolePrincipalId],[MemberPrincipalId];
            SELECT * FROM [#DatabasePrincipalAnalysis_permissions] ORDER BY [DatabaseId],[GranteePrincipalId],[Class],[MajorId],[MinorId],[PermissionName],[PermissionState],[GrantorPrincipalId];
            SELECT * FROM [#DatabasePrincipalAnalysis_schemaOwners] ORDER BY [DatabaseId],[SchemaId];
            SELECT * FROM [#DatabasePrincipalAnalysis_loginBindings] ORDER BY [DatabaseId],[PrincipalId];
            SELECT * FROM [#DatabasePrincipalAnalysis_sourceStatus] ORDER BY [DatabaseId],[DatabaseName],[SourceKey];
            SELECT * FROM [#DatabasePrincipalAnalysis_warnings] ORDER BY [DatabaseId],[DatabaseName],[WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [DatabasePrincipalOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable] FROM [#DatabasePrincipalAnalysis_Map] ORDER BY [ResultName];
            OPEN [DatabasePrincipalOutput];
            FETCH NEXT FROM [DatabasePrincipalOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#DatabasePrincipalAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @FailureError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [DatabasePrincipalOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [DatabasePrincipalOutput]; DEALLOCATE [DatabasePrincipalOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            CREATE TABLE [#DatabasePrincipalAnalysis_Console]
            ([Bereich] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
             [Objekt] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
             [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Datenbank',[DatabaseName],CONCAT([StateDescription],N'; Containment=',[ContainmentDescription],
                    N'; Ownerbindung=',[OwnerBindingStatus],N'; sichtbarer Owner=',[OwnerName])
                FROM [#DatabasePrincipalAnalysis_databaseContext];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Principal',[PrincipalName],CONCAT(N'DB=',[DatabaseName],N'; ',[PrincipalTypeDescription],
                    N'; Authentifizierung=',[AuthenticationTypeDescription],N'; feste Rolle=',[IsFixedRole])
                FROM [#DatabasePrincipalAnalysis_principals];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Direkte Rolle',COALESCE([MemberName],CONVERT(nvarchar(20),[MemberPrincipalId])),
                    CONCAT(N'DB=',[DatabaseName],N'; Rolle=',COALESCE([RoleName],CONVERT(nvarchar(20),[RolePrincipalId])))
                FROM [#DatabasePrincipalAnalysis_roleMemberships];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Explizites Recht',COALESCE([GranteeName],CONVERT(nvarchar(20),[GranteePrincipalId])),
                    CONCAT(N'DB=',[DatabaseName],N'; ',[PermissionStateDescription],N' ',[PermissionName],
                           N'; Klasse=',[ClassDescription],N'; MajorId=',[MajorId],N'; MinorId=',[MinorId])
                FROM [#DatabasePrincipalAnalysis_permissions];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Schemaowner',[SchemaName],CONCAT(N'DB=',[DatabaseName],N'; Owner=',
                    COALESCE([OwnerName],CONVERT(nvarchar(20),[OwningPrincipalId])))
                FROM [#DatabasePrincipalAnalysis_schemaOwners];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Loginbindung',[PrincipalName],CONCAT(N'DB=',[DatabaseName],N'; ',[BindingStatus],
                    N'; sichtbarer Login=',[ServerPrincipalName]) FROM [#DatabasePrincipalAnalysis_loginBindings];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Quelle',[SourceKey],CONCAT(N'DB=',[DatabaseName],N'; ',[SourceKind],N'; ',[StatusCode],
                    N'; sichtbar=',[ObservedRows],N'; Ausgabe=',[ReturnedRows]) FROM [#DatabasePrincipalAnalysis_sourceStatus];
            INSERT [#DatabasePrincipalAnalysis_Console]
                SELECT N'Aussagegrenze',[WarningCode],[Detail] FROM [#DatabasePrincipalAnalysis_warnings];
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#DatabasePrincipalAnalysis_Console',
                @ResultLabel=N'Sichtbare Datenbankprincipals und direkte Berechtigungsevidenz',
                @EmptyMessage=N'Keine sichtbaren Datenbankprincipal-Metadaten.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_DatabasePrincipalAnalysis: mindestens eine Quelle ist nicht verfuegbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;

    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@FailureError,ERROR_NUMBER()),@Message=LEFT(ERROR_MESSAGE(),2048),@Json=NULL;
        SELECT @StatusCodeOut=COALESCE(@FailureStatus,'ERROR_HANDLED'),@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
