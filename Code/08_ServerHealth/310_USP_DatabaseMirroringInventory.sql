USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DatabaseMirroringInventory
Version      : 1.0.0
Stand        : 2026-10-27
Zweck        : Die Procedure gibt caller-sichtbare lokale Database-Mirroring-Katalogwerte je
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
        @CrossDatabaseRequested bit,
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
        PRINT N'monitor.USP_DatabaseMirroringInventory';
        PRINT N'Zweck: read-only lokale, caller-sichtbare Mirroring-Katalogwerte zu ausgewählten ONLINE-Datenbanken; keine Konfigurations-, Netzwerk- oder Probeoperation und keine Gesundheitsqualifikation.';
        PRINT N'Umfang: sichtbare ONLINE-Datenbanken; Systemdatenbanken nur opt-in; nicht ONLINE befindliche Datenbanken einschließlich RESTORING-Mirror-Datenbanken sind ausgeschlossen.';
        PRINT N'Hilfe: @Hilfe=1 druckt die Hinweise und kehrt vor Datenbankauswahl und Quellenlesung zurück; ein AVAILABLE-Hilfestatus ist keine Laufzeitqualifikation.';
        PRINT N'@DatabaseNames nvarchar(max)=NULL; Default: NULL. Die Liste schränkt die Auswahl auf angeforderte, gültige einteilige Datenbanknamen ein; NULL, eine exakt leere Eingabe oder ausschließlich äußere U+0020-Leerzeichen werden vom Auswahlhelfer zu keiner Einschränkung normalisiert. Eine aktive Liste muss bracket-aware mit | getrennt sein: | innerhalb [..] gehört zum Namen, ]] maskiert dort eine schließende Klammer. Segmente werden außen getrimmt; doppelte Namen und ungültige Elemente machen die Auswahl ungültig. Die Prüfung nutzt TVF_ParseSqlNameList/PARSENAME: Teil 1 muss vorhanden, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; das ist keine vollständige SQL-Namens-, Existenz- oder Berechtigungsprüfung. Aktive Liste und nicht-NULL @DatabaseNamePattern sind unzulässig zusammen. Auswahl umfasst nur sichtbare, ONLINE befindliche, zugreifbare, nicht als Snapshot markierte Datenbanken. Jedes rohe Listensegment darf höchstens 4000 UTF-16-Codeeinheiten enthalten; längere Segmente sind INVALID_PARAMETER. Diese Grenze gilt je Segment, nicht für die Gesamtlänge der nvarchar(max)-Liste. Doppelte Namen werden case-sensitiv geprüft. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@SystemdatenbankenEinbeziehen bit=0; Default: 0. Steuert den Datenbank-ID-Filter: 0 schließt Systemdatenbanken mit IDs bis 4 aus, 1 nimmt sie in die Kandidatenmenge auf; andere numerische Bit-Eingaben werden durch den Bit-Parametertyp als 0 oder 1 abgebildet. NULL ist ausdrücklich ungültig und liefert INVALID_PARAMETER vor Quellenlesung. Der Schalter garantiert weder Sichtbarkeit noch Online-Status oder HAS_DBACCESS. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern. Optionaler zusätzlicher Namensfilter; nicht-NULL ist mit einer aktiven exakten @DatabaseNames-Liste unzulässig. Der Parser trimmt zuerst äußere Leerzeichen, entfernt danach ohne Beachtung der Groß-/Kleinschreibung höchstens das Präfix regexi:, regex: oder like:; der Rest wird nicht erneut getrimmt. Ohne Präfix gilt LIKE. LIKE verwendet SQL-LIKE-Syntax und wird case-sensitive ausgewertet. regex: führt case-sensitives Regex mit Flag c, regexi: case-insensitives Regex mit Flag i aus; Regex-Syntax wird vom Parser nicht validiert. Ein leerer Eingang oder leeres Präfix-Ergebnis ist ungültig. Regex setzt SQL Server 2025 (Major Version mindestens 17) und Compatibility Level 170 der Installationsdatenbank voraus; bei Nichterfüllung löscht der Helper Kandidaten und gibt UNAVAILABLE_FEATURE zurück. Der gemeinsame Kandidatenhelfer führt den Regexabgleich dynamisch aus; Fehler dabei werden vom Auswahl-CATCH als DENIED_PERMISSION, TIMEOUT oder ERROR_HANDLED eingeordnet. SQL-LIKE unterstützt Prozentzeichen für beliebig viele Zeichen, Unterstrich für ein Zeichen und Zeichenklassen in [...]; der Aufruf definiert keine eigene ESCAPE-Klausel. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@MaxZeilen int=1000; Default: 1000. Globales Ausgabelimit für databaseMirroring nach der vollständigen Kandidaten- und Katalogermittlung, sortiert nach DatabaseId; es begrenzt weder Kandidatenermittlung noch vorgelagerte Kataloglesearbeit. NULL oder 0 setzt das Limit auf bigint-Maximum und wirkt damit unbegrenzt; negative Werte sind INVALID_PARAMETER. sourceStatus unterscheidet beobachtete Auswahl-/Quellzeilen und tatsächlich ausgegebene Mirroringzeilen; OUTPUT_LIMIT wird nur bei tatsächlich abgeschnittenen Fachzeilen angelegt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Wählt die Resultset-Ausgabe. Nach LTRIM/RTRIM und UPPER sind genau CONSOLE, RAW, TABLE und NONE zulässig; NULL oder Leertext wird zu leer und ist INVALID_PARAMETER. CONSOLE erzeugt eine formatierte Einzelansicht über InternalEmitConsoleResult. RAW liefert die vier Resultsets moduleStatus, databaseMirroring, sourceStatus und warnings in dieser Reihenfolge. TABLE schreibt die angeforderten benannten Resultsets in Caller-Temp-Tabellen; die Zuordnung ist Pflicht. NONE unterdrückt Resultsets. Json-Erzeugen ist unabhängig von dieser Auswahl. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. Wird nur mit ResultSetArt TABLE verarbeitet; außerhalb TABLE ist ein nicht-NULL, nach Trim nicht-leerer Wert INVALID_PARAMETER. In TABLE ist ein gültiges JSON-Objekt mit mindestens einem Schlüssel und Textwerten erforderlich. Erlaubte, exakt groß-/kleinschreibungssensitive Schlüssel sind moduleStatus, databaseMirroring, sourceStatus und warnings; jeder benennt eine jeweils unterschiedliche lokale #Temp-Zieltabelle. Doppelte Resultset-Schlüssel werden binär verglichen, Zielnamen dagegen case-insensitive; unbekannte Schlüssel, doppelte Ziele, Nicht-Textwerte und ungültige Ziele werden vor fachlichem Quellenzugriff abgelehnt. Zielname maximal 116 Zeichen, lokal mit #, nicht ## und nicht mit reserviertem #Monitor-Präfix. Jedes Ziel muss vorher vorhanden, leer und mit genau einer Seed-Spalte versehen sein. Die Vorprüfung validiert die Zuordnung und Seed-Ziele; der Writer passt die einzelne Dummy-Spalte an das Quellschema an; öffentlich sind gefüllte Ziele wegen der Vorprüfung unzulässig. Ein späterer Writer-Fehler kann nach früheren erfolgreichen Zielen auftreten; der Aufruf kann daher teilweise geschriebene Ziele hinterlassen. Die vier Schlüssel bedeuten einzeln: moduleStatus liefert Modulstatus, Partialität und Zeilenzahl; databaseMirroring caller-sichtbare Mirroring-Katalogwerte je ausgewählter Online-Datenbank; sourceStatus Auswahl- und Katalogquellenstatus mit beobachteten und ausgegebenen Zeilen sowie Fehlern; warnings Warnungen und Aussagegrenzen. NULL und leere Werte sind im TABLE-Modus ungültig; außerhalb TABLE sind NULL, Leerstring und reine U+0020-Leerzeichen erlaubt. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. Schaltet die JSON-Ausgabe unabhängig von ResultSetArt ein: Wert 1 erzeugt die schemaVersion-1-Metahülle mit moduleStatus, databaseMirroring, sourceStatus und warnings; NULL oder 0 erzeugt kein JSON und @Json bleibt NULL. Numerische Bit-Eingaben werden vom Parametertyp auf 0/1 abgebildet. Der Schalter ist nicht als ungültig validiert. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT nvarchar(max); der Aufrufer bindet eine nvarchar(max)-Variable mit OUTPUT. Die Variable wird beim Eintritt auf NULL gesetzt. Bei @JsonErzeugen=1 wird JSON auch dann erzeugt, wenn Auswahlstatus, Quellfehler oder Auswahlwarnungen als innerer Fehlerstatus erfasst wurden; diese Fälle laufen bis zur JSON-Erzeugung weiter und erscheinen in meta sowie den Arrays. Bei Hilfe, ohne JSON-Anforderung und bei jedem äußeren CATCH bleibt @Json NULL; ein äußerer Fehler nach der JSON-Erzeugung, etwa ein TABLE-Schreibfehler, setzt es erneut auf NULL. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@PrintMeldungen bit=1; Default: 1. Steuert zusätzliche Meldungen mit niedriger Severity: 1 gibt sie an den Client aus, 0 unterdrückt sie; NULL verhält sich wegen der IF-Prüfungen wie unterdrückt. Numerische Bit-Eingaben werden als 0/1 übernommen. Die Auswahl-/Katalogstatus und OUTPUT-Fehlerdaten werden unabhängig davon gesetzt; dieser Schalter ändert keine Resultsets. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@Hilfe bit=0; Default: 0. Bei 1 gibt die Procedure die eingebaute Hilfe per PRINT aus, setzt StatusCodeOut auf AVAILABLE und IsPartialOut auf 0 und kehrt vor Auswahl, Temp-Tabellen und Katalogzugriff mit RETURN zurück. NULL oder 0 führen den normalen Ablauf aus. Die Hilfe-Ausgabe ist keine Quellen- oder Plattformqualifikation; numerische Bit-Eingaben werden vom Parametertyp auf 0/1 abgebildet. Bei der bit-Konvertierung wird die numerische 0 zu 0 und jeder numerische Wert ungleich 0 zu 1. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine varchar(40)-Variable; der Eingangswert wird auf NULL gesetzt. Sämtliche Statuswerte und Bedeutungen: AVAILABLE kennzeichnet die Hilfe ohne Quellenanalyse; AVAILABLE_LIMITED eine erfolgreiche, stets partielle normale Katalogsicht, auch ohne Fachzeilen; INVALID_PARAMETER ungültige direkte Eingaben oder einen ungültigen Auswahlvertrag; INTERNAL_ERROR einen internen Vorbereitungsfehler des Auswahlhelfers; UNAVAILABLE_FEATURE einen hier nicht verfügbaren Regexfilter; SELECTION_UNAVAILABLE den Fallback bei NULL als Auswahlstatus; DENIED_PERMISSION einen abgefangenen Berechtigungsfehler 229, 297, 300 oder 371; TIMEOUT einen Sperrtimeout 1222; ERROR_HANDLED einen sonstigen abgefangenen Auswahl-/Katalogfehler oder jeden äußeren Fehler; DATABASE_UNAVAILABLE einen explizit angeforderten fehlenden, nicht online befindlichen oder nicht zugreifbaren Namen; SYSTEM_DATABASE_EXCLUDED eine explizit angeforderte Systemdatenbank ohne Opt-in. Die normale Auswahl übernimmt einen nicht-AVAILABLE-Helferstatus oder den NULL-Fallback; Auswahl- und Katalog-CATCH setzen ihren Fehler sofort. Nur solange kein Fehler gesetzt ist, übernimmt die spätere Fehlerauswahl die erste sourceStatus-Zeile mit ErrorNumber nach SourceKey, DatabaseId und DatabaseName: DATABASE_MIRRORING_CATALOG vor DATABASE_SELECTION. Auswahlwarnungen tragen 51011 und können so den globalen Status setzen, obwohl der Katalog gelesen wurde. Ein äußerer CATCH, auch nach TABLE-Vorprüfung oder -Schreiben, überschreibt den Status mit ERROR_HANDLED. Hilfe und normale innere Fehlerpfade liefern RETURN 0; direkte Validierung RETURN 51011. Der äußere CATCH liefert den gespeicherten TABLE-Fehlercode (Vorprüfung 51011, Writercode oder 51010), sonst die native Fehlernummer. Ein Status beweist weder Gesundheit noch vollständige Sicht. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@IsPartialOut bit=NULL OUTPUT; Default: NULL. OUTPUT-Bit; wird beim Eintritt auf NULL zurückgesetzt. Hilfe setzt 0. Jeder normale Lauf sowie INVALID_PARAMETER und der äußere Fehler-CATCH setzen 1, auch wenn die Fachmenge leer ist. Numerische Bit-Ausgabe; kennzeichnet keine bestimmte Fehlerursache. Die Bindung ist optional: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ErrorNumberOut int=NULL OUTPUT; Default: NULL. Optionales OUTPUT int; wird am Eintritt auf NULL gesetzt. Hilfe und fehlerfreier normaler Lauf lassen NULL. Direkte ungültige Eingaben liefern 51011. Ein nicht-AVAILABLE-Auswahlstatus liefert 51011 aus den Auswahlwarnungen oder als Fallback; Auswahl-/Katalog-CATCH liefert die SQL-Fehlernummer. Fehlende, ausgeschlossene oder nicht zugreifbare explizite Datenbanknamen werden als sourceStatus-Warnungen mit 51011 eingetragen und können bei der globalen Fehlerauswahl übernommen werden. Ohne vorher gesetzten Fehler werden Nummer und Meldung aus der ersten Zeile mit ErrorNumber nach SourceKey, DatabaseId und DatabaseName übernommen. Der äußere CATCH priorisiert TableFailureError: 51011 bei TABLE-Preflight, sonst Writer-Fehlernummer oder 51010; andernfalls native SQL-Fehlernummer. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'@ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. Optionales OUTPUT nvarchar(2048); wird beim Eintritt auf NULL gesetzt. Hilfe und fehlerfreier normaler Lauf lassen NULL. Direkte ungültige Eingaben liefern den Validierungstext. Bei Auswahlstatusfehlern kommt der Auswahlhelper-Text oder der Fallbacktext; Auswahl-/Katalog-CATCH liefert den abgefangenen SQL-Text, auf 2048 Zeichen begrenzt. Auswahlwarnungen für nicht verfügbare, ausgeschlossene oder nicht zugreifbare explizite Namen werden mit ihrer Warnmeldung in sourceStatus aufgenommen und können über die sortierte Fehlerauswahl ausgegeben werden. Bei mehreren Fehlern gehört die Meldung zur ersten sourceStatus-Zeile nach SourceKey, DatabaseId und DatabaseName. Im äußeren CATCH ist @ErrorMessageOut der abgefangene SQL-Fehlertext, links auf 2048 Zeichen begrenzt; bei TABLE-Fehlern stammt er aus dem ausgelösten Fehlertext, die TableFailureError-Priorität beeinflusst nur @ErrorNumberOut und den RETURN-Wert. Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT übergeben; andernfalls auslassen. Bei ausgelassenem Argument gilt der angegebene Default.';
        PRINT N'EXEC [monitor].[USP_DatabaseMirroringInventory] @MaxZeilen=200, @ResultSetArt=''RAW'', @PrintMeldungen=0;';
        PRINT N'DECLARE @DiagnosticJson nvarchar(max), @Status varchar(40), @Partial bit, @Error int, @Message nvarchar(2048), @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_DatabaseMirroringInventory] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@DiagnosticJson OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @ErrorNumberOut=@Error OUTPUT, @ErrorMessageOut=@Message OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Error AS [ErrorNumber], @Message AS [ErrorMessage], @DiagnosticJson AS [DiagnosticJson];';
        PRINT N'CREATE TABLE [#DatabaseMirroringInventory_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseMirroringInventory] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"databaseMirroring":"#DatabaseMirroringInventory_HelpExample"}'', @PrintMeldungen=0; SELECT * FROM [#DatabaseMirroringInventory_HelpExample]; DROP TABLE IF EXISTS [#DatabaseMirroringInventory_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#DatabaseMirroringInventory_HelpExample]; THROW; END CATCH;';
        PRINT N'EXEC [monitor].[USP_DatabaseMirroringInventory] @Hilfe=1;';
        PRINT N'Für nicht-NULL-Werte einer Mirror-Datenbank ist sysadmin erforderlich; SQL Server 2022+ fordert VIEW SERVER PERFORMANCE STATE; die Quelle spezifiziert keine weitere Serverberechtigung für SQL Server 2019.';
        PRINT N'TABLE-Zuordnung: {"moduleStatus":"#DbmiModule","databaseMirroring":"#DbmiRows","sourceStatus":"#DbmiSources","warnings":"#DbmiWarnings"}.';
        PRINT N'Beispiel Pattern: EXEC [monitor].[USP_DatabaseMirroringInventory] @DatabaseNamePattern=N''like:Prod%'', @ResultSetArt=''CONSOLE'';';
        PRINT N'Beispiel JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabaseMirroringInventory] @DatabaseNames=N''[ExampleDatabase]'', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];';
        PRINT N'JSON: schemaVersion=1; meta sowie moduleStatus, databaseMirroring, sourceStatus und warnings.';
        PRINT N'@SystemdatenbankenEinbeziehen: 0 schließt Systemdatenbanken aus; 1 schließt sie ein, NULL ist ungültig. Aktive exakte Liste und Pattern sind getrennt; exakt und Pattern schließen einander aus.';
        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        RETURN;
    END;

    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE')
       OR @MaxZeilen<0
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
                @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,
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
