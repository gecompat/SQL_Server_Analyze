USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_ServerPrincipalAnalysis
Version      : 1.0.1
Stand        : 2026-10-25
Zweck        : Die Procedure zeigt sichtbare Serverprincipals, direkte
               Rollenmitgliedschaften, explizite Berechtigungen und konfigurierte
               SQL-Login-Policies.
Quellen      : sys.server_principals, sys.server_role_members,
               sys.server_permissions und sys.sql_logins.
Grenzen      : Sichtbare Metadaten sind kein Vollständigkeitsnachweis. Implizite
               Rollenrechte und externe Gruppen werden nicht aufgelöst.
Datenschutz  : Liest keine Passwort-Hashes, Credentials oder Schlüssel.
Nebenwirkung : Verändert weder Principals noch Berechtigungen oder Nutzdaten.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_ServerPrincipalAnalysis 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_ServerPrincipalAnalysis"
-- schema_name: "monitor"
-- object_name: "USP_ServerPrincipalAnalysis"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Procedure zeigt sichtbare Serverprincipals, direkte Rollenmitgliedschaften, explizite Berechtigungen und konfigurierte SQL-Login-Policies."
-- source_path: "Code/08_ServerHealth/260_USP_ServerPrincipalAnalysis.sql"
-- ---
-- 
-- # monitor.USP_ServerPrincipalAnalysis
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure zeigt sichtbare Serverprincipals, direkte Rollenmitgliedschaften, explizite Berechtigungen und konfigurierte SQL-Login-Policies.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_ServerPrincipalAnalysis]. Die Quelle nennt insbesondere `sys.server_principals`, `sys.server_role_members`, `sys.server_permissions`, `[monitor].[InternalPrepareResultTables]`, `[sys].[server_principals]`, `[sys].[sp_executesql]`, `[sys].[server_role_members]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @MaxZeilen | int | nein | 1000 |
-- | @LockTimeoutMs | int | nein | 0 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- | @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
-- | @IsPartialOut | bit | nein | NULL OUTPUT |
-- | @ErrorNumberOut | int | nein | NULL OUTPUT |
-- | @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |
-- | @PermissionGranteeName | nvarchar(max) | nein | NULL |
-- 
-- **@MaxZeilen:** @MaxZeilen begrenzt jedes der vier Fachresultsets; 0 oder NULL bedeutet unbegrenzt. @LockTimeoutMs erlaubt 0 bis 60000.
-- 
-- **@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Millisekunden 0–60000; NULL und Werte außerhalb sind ungültig. 0 setzt NOWAIT für jede Quellenabfrage; sonst gilt der Wert je Quellbatch. Bei eingehendem @@LOCK_TIMEOUT=0 erhalten eigene Temp-DDL zunächst 1000 ms. Erfolg und gefangener äußerer Fehler stellen den Eingangswert wieder her.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Trimmen und Großschreibung normalisieren den einzelnen Modus: CONSOLE eine Übersicht; RAW sieben Sets in der Reihenfolge moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings; TABLE angeforderte Sets in lokale Seed-Temp-Tabellen; NONE keine Resultsets. NULL/Leertext und andere Werte sind ungültig.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE erlaubt eine nichtleere Zuordnung; sonst nur NULL/U+0020-Leerzeichen. TABLE verlangt ein gültiges, nichtleeres JSON-Objekt. Exakte Schlüssel: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings. Jeder Wert muss eine vorhandene, leere lokale #Temp-Tabelle (max. 116 Zeichen) mit einer Seed-Spalte benennen. Unzulässig: ##-/permanente/#Monitor*-Ziele, doppelte Schlüssel/Ziele, unbekannte Schlüssel, leere oder nicht-stringförmige Werte und nicht prüfbare Ziele. Helper-Preflight erfolgt vor Fachquellenzugriff; Writer ersetzt das Seed-Schema. Die Schlüssel bedeuten: moduleStatus Modulstatus, principals sichtbare Serverprincipals, roleMemberships direkte Rollenmitgliedschaften, permissions explizite Serverrechte, loginPolicies SQL-Login-Policykennzeichen, sourceStatus Quellenstatus und warnings Warnungen.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit: 1 erzeugt JSON unabhängig vom Ausgabemodus; 0/NULL nicht. Hilfe und Validierungsfehler erzeugen keines. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT, bei Eintritt NULL. Mit @JsonErzeugen=1 enthält es meta und sieben benannte Arrays. Hilfe, Validierungs- und gefangener äußerer Fehler lassen es NULL. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; der Empfänger darf ausgelassen werden.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit: 1 sendet bei Validierungs-, Quellen- oder äußerem Fehler eine Zusatzmeldung mit Severity 10; 0/NULL unterdrückt sie. OUTPUT und RETURN sind weiter zu prüfen. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. Bit: 1 druckt die eingebaute Parameterhilfe und Beispiele, setzt AVAILABLE/IsPartialOut=0 und kehrt vor Validierung und Quellenzugriff ohne Resultset zurück. JSON-/Fehler-OUTPUTs bleiben NULL. 0/NULL analysiert. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Hilfe liefert AVAILABLE und IsPartialOut=0. Eingabevalidierung liefert INVALID_PARAMETER mit RETURN 51011. Regulär lautet der Status AVAILABLE_LIMITED, sobald mindestens eine der vier Quellen ohne ErrorNumber vorliegt. Schlagen alle vier Quellen fehl, gilt aus der alphabetisch ersten SourceKey-Zeile DENIED_PERMISSION bei verweigerter Quelle (Fehler 229, 297, 300, 371), TIMEOUT bei Sperrtimeout 1222 oder ERROR_HANDLED bei anderem abgefangenen Quellenfehler. Der äußere CATCH liefert ERROR_HANDLED. Reguläre Quellenfehler ändern RETURN 0 nicht; Diagnose-OUTPUTs sind getrennt zu prüfen. Optionaler OUTPUT-Empfänger vom Typ varchar(40); zum Empfangen eine Variable mit OUTPUT binden, andernfalls auslassen. Der Eintritt setzt auch einen anfänglichen NULL- oder anderen Wert zunächst auf NULL.
-- 
-- **@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Hilfe 0; Analyse, Validierung und äußerer Fehler 1. Jede Analyse bleibt partiell, auch wenn alle Quellen lesbar sind. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Validierung 51011; regulär Fehlernummer der alphabetisch ersten fehlerhaften SourceKey-Quelle, sonst NULL. Äußerer Fehler: TABLE-Fehlercode, sonst ERROR_NUMBER(). Quellenfehler allein ändern RETURN nicht. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Validierung: feste Meldung; regulär: Meldung der alphabetisch ersten fehlerhaften Quelle, sonst NULL; äußerer Fehler: ERROR_MESSAGE(). Hilfe lässt NULL. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.
-- 
-- **@PermissionGranteeName:** @PermissionGranteeName nvarchar(max). Der Default ist NULL und lässt alle sichtbaren expliziten Serverrechte in permissions zu. Ein gesetzter Wert enthält genau einen unveränderten Serverprincipalnamen mit höchstens 128 UTF-16-Codeeinheiten. Leertext und ausschließlich U+0020-Leerzeichen sind ungültig. Der Vergleich ist bytegenau einschließlich Großschreibung und Leerzeichen. Der Filter wirkt nur auf permissions vor @MaxZeilen. Er verwendet sichtbare Empfängernamen und löst keine Rollenrechte auf.
-- 
-- ## Resultate und Ausgabe
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | moduleStatus | 1 | 1 | [ModuleName] sysname NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) NOT NULL |
-- | principals | 1 | 1 | [PrincipalId] int NOT NULL, [PrincipalName] sysname NULL, [PrincipalType] char(1) NOT NULL, [PrincipalTypeDescription] nvarchar(60) NULL, [IsDisabled] bit NULL, [CreatedAt] datetime NULL, [ModifiedAt] datetime NULL, [IsFixedRole] bit NULL, [OwningPrincipalId] int NULL |
-- | roleMemberships | 1 | 1 | [RolePrincipalId] int NOT NULL, [RoleName] sysname NULL, [MemberPrincipalId] int NOT NULL, [MemberName] sysname NULL |
-- | permissions | 1 | 1 | [GranteePrincipalId] int NOT NULL, [GranteeName] sysname NULL, [GrantorPrincipalId] int NOT NULL, [GrantorName] sysname NULL, [Class] tinyint NOT NULL, [ClassDescription] nvarchar(60) NULL, [MajorId] int NOT NULL, [PermissionName] nvarchar(128) NULL, [PermissionState] char(1) NOT NULL, [PermissionStateDescription] nvarchar(60) NULL |
-- | loginPolicies | 1 | 1 | [PrincipalId] int NOT NULL, [PrincipalName] sysname NULL, [IsPolicyChecked] bit NULL, [IsExpirationChecked] bit NULL |
-- | sourceStatus | 1 | 1 | [SourceKey] varchar(64) NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) NOT NULL, [VisibilityScope] varchar(32) NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) NULL |
-- | warnings | 1 | 1 | [WarningCode] varchar(64) NOT NULL, [SourceKey] varchar(64) NULL, [Detail] nvarchar(1000) NOT NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
-- ```
-- 
-- ```sql
-- EXEC [monitor].[USP_ServerPrincipalAnalysis] @PermissionGranteeName=N'ExampleLogin', @ResultSetArt='RAW';
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Sichtbare Metadaten sind kein Vollständigkeitsnachweis. Implizite Rollenrechte und externe Gruppen werden nicht aufgelöst.
-- 
-- Verändert weder Principals noch Berechtigungen oder Nutzdaten.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_ServerPrincipalAnalysis
-- Version      : 1.0.1
-- Stand        : 2026-10-25
-- Zweck        : Die Procedure zeigt sichtbare Serverprincipals, direkte
--                Rollenmitgliedschaften, explizite Berechtigungen und konfigurierte
--                SQL-Login-Policies.
-- Quellen      : sys.server_principals, sys.server_role_members,
--                sys.server_permissions und sys.sql_logins.
-- Grenzen      : Sichtbare Metadaten sind kein Vollständigkeitsnachweis. Implizite
--                Rollenrechte und externe Gruppen werden nicht aufgelöst.
-- Datenschutz  : Liest keine Passwort-Hashes, Credentials oder Schlüssel.
-- Nebenwirkung : Verändert weder Principals noch Berechtigungen oder Nutzdaten.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_ServerPrincipalAnalysis
-- Liest sichtbare Principals, direkte Rollen, explizite Serverrechte und SQL-Login-Policyflags. Keine effektive Rechteberechnung.
-- RAW/TABLE/JSON: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings.
-- Parameter- und gefangene Ausgabefehler liefern Status, Diagnose-OUTPUT und einen Rückgabecode; optionale Meldungen haben Schweregrad 10.
-- DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
-- EXEC @ReturnCode=[monitor].[USP_ServerPrincipalAnalysis]
--       @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT
--     , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
--     , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
-- SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
-- CREATE TABLE [#ServerPrincipalAnalysis_HelpExample] ([Seed] int NULL);
-- DECLARE @Map nvarchar(max)=N'{"principals":"#ServerPrincipalAnalysis_HelpExample"}';
-- BEGIN TRY
--     EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
--     SELECT * FROM [#ServerPrincipalAnalysis_HelpExample];
--     DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];
-- END TRY
-- BEGIN CATCH
--     DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];
--     THROW;
-- END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_ServerPrincipalAnalysis
CREATE OR ALTER PROCEDURE [monitor].[USP_ServerPrincipalAnalysis]
      @MaxZeilen int = 1000
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
    , @PermissionGranteeName nvarchar(max) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @Hilfe=1
    BEGIN
        SET @Json=NULL;
        SET @StatusCodeOut=NULL;
        SET @IsPartialOut=NULL;
        SET @ErrorNumberOut=NULL;
        SET @ErrorMessageOut=NULL;
        PRINT N'monitor.USP_ServerPrincipalAnalysis';
        PRINT N'Liest sichtbare Principals, direkte Rollen, explizite Serverrechte und SQL-Login-Policyflags. Keine effektive Rechteberechnung.';
        PRINT N'RAW/TABLE/JSON: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings.';
        PRINT N'@MaxZeilen begrenzt jedes der vier Fachresultsets; 0 oder NULL bedeutet unbegrenzt. @LockTimeoutMs erlaubt 0 bis 60000.';
        PRINT N'Parameter- und gefangene Ausgabefehler liefern Status, Diagnose-OUTPUT und einen Rückgabecode; optionale Meldungen haben Schweregrad 10.';
        PRINT N'@MaxZeilen int; Default: 1000. Begrenzt jede der vier Fachmengen einzeln. NULL oder 0 bedeutet unbegrenzt; positive Werte sind je Menge die Höchstzahl. Negative Werte sind INVALID_PARAMETER. Das Limit greift nach vollständiger sichtbarer Katalogmaterialisierung und beschränkt nicht die Namensbasis oder Kataloglesearbeit.';
        PRINT N'@LockTimeoutMs int; Default: 0. Millisekunden 0–60000; NULL und Werte außerhalb sind ungültig. 0 setzt NOWAIT für jede Quellenabfrage; sonst gilt der Wert je Quellbatch. Bei eingehendem @@LOCK_TIMEOUT=0 erhalten eigene Temp-DDL zunächst 1000 ms. Erfolg und gefangener äußerer Fehler stellen den Eingangswert wieder her.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Trimmen und Großschreibung normalisieren den einzelnen Modus: CONSOLE eine Übersicht; RAW sieben Sets in der Reihenfolge moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings; TABLE angeforderte Sets in lokale Seed-Temp-Tabellen; NONE keine Resultsets. NULL/Leertext und andere Werte sind ungültig.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE erlaubt eine nichtleere Zuordnung; sonst nur NULL/U+0020-Leerzeichen. TABLE verlangt ein gültiges, nichtleeres JSON-Objekt. Exakte Schlüssel: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings. Jeder Wert muss eine vorhandene, leere lokale #Temp-Tabelle (max. 116 Zeichen) mit einer Seed-Spalte benennen. Unzulässig: ##-/permanente/#Monitor*-Ziele, doppelte Schlüssel/Ziele, unbekannte Schlüssel, leere oder nicht-stringförmige Werte und nicht prüfbare Ziele. Helper-Preflight erfolgt vor Fachquellenzugriff; Writer ersetzt das Seed-Schema. Die Schlüssel bedeuten: moduleStatus Modulstatus, principals sichtbare Serverprincipals, roleMemberships direkte Rollenmitgliedschaften, permissions explizite Serverrechte, loginPolicies SQL-Login-Policykennzeichen, sourceStatus Quellenstatus und warnings Warnungen.';
        PRINT N'@JsonErzeugen bit; Default: 0. Bit: 1 erzeugt JSON unabhängig vom Ausgabemodus; 0/NULL nicht. Hilfe und Validierungsfehler erzeugen keines. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT, bei Eintritt NULL. Mit @JsonErzeugen=1 enthält es meta und sieben benannte Arrays. Hilfe, Validierungs- und gefangener äußerer Fehler lassen es NULL. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; der Empfänger darf ausgelassen werden.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bit: 1 sendet bei Validierungs-, Quellen- oder äußerem Fehler eine Zusatzmeldung mit Severity 10; 0/NULL unterdrückt sie. OUTPUT und RETURN sind weiter zu prüfen. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@Hilfe bit; Default: 0. Bit: 1 druckt die eingebaute Parameterhilfe und Beispiele, setzt AVAILABLE/IsPartialOut=0 und kehrt vor Validierung und Quellenzugriff ohne Resultset zurück. JSON-/Fehler-OUTPUTs bleiben NULL. 0/NULL analysiert. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Hilfe liefert AVAILABLE und IsPartialOut=0. Eingabevalidierung liefert INVALID_PARAMETER mit RETURN 51011. Regulär lautet der Status AVAILABLE_LIMITED, sobald mindestens eine der vier Quellen ohne ErrorNumber vorliegt. Schlagen alle vier Quellen fehl, gilt aus der alphabetisch ersten SourceKey-Zeile DENIED_PERMISSION bei verweigerter Quelle (Fehler 229, 297, 300, 371), TIMEOUT bei Sperrtimeout 1222 oder ERROR_HANDLED bei anderem abgefangenen Quellenfehler. Der äußere CATCH liefert ERROR_HANDLED. Reguläre Quellenfehler ändern RETURN 0 nicht; Diagnose-OUTPUTs sind getrennt zu prüfen. Optionaler OUTPUT-Empfänger vom Typ varchar(40); zum Empfangen eine Variable mit OUTPUT binden, andernfalls auslassen. Der Eintritt setzt auch einen anfänglichen NULL- oder anderen Wert zunächst auf NULL.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Hilfe 0; Analyse, Validierung und äußerer Fehler 1. Jede Analyse bleibt partiell, auch wenn alle Quellen lesbar sind. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Validierung 51011; regulär Fehlernummer der alphabetisch ersten fehlerhaften SourceKey-Quelle, sonst NULL. Äußerer Fehler: TABLE-Fehlercode, sonst ERROR_NUMBER(). Quellenfehler allein ändern RETURN nicht. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Validierung: feste Meldung; regulär: Meldung der alphabetisch ersten fehlerhaften Quelle, sonst NULL; äußerer Fehler: ERROR_MESSAGE(). Hilfe lässt NULL. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.';
        PRINT N'@PermissionGranteeName nvarchar(max). Der Default ist NULL und lässt alle sichtbaren expliziten Serverrechte in permissions zu. Ein gesetzter Wert enthält genau einen unveränderten Serverprincipalnamen mit höchstens 128 UTF-16-Codeeinheiten. Leertext und ausschließlich U+0020-Leerzeichen sind ungültig. Der Vergleich ist bytegenau einschließlich Großschreibung und Leerzeichen. Der Filter wirkt nur auf permissions vor @MaxZeilen. Er verwendet sichtbare Empfängernamen und löst keine Rollenrechte auf.';
        PRINT N'EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;';
        PRINT N'EXEC [monitor].[USP_ServerPrincipalAnalysis] @PermissionGranteeName=N''ExampleLogin'', @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_ServerPrincipalAnalysis]
      @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];';
        PRINT N'CREATE TABLE [#ServerPrincipalAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N''{"principals":"#ServerPrincipalAnalysis_HelpExample"}'';
BEGIN TRY
    EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@Map;
    SELECT * FROM [#ServerPrincipalAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];
    THROW;
END CATCH;';
        PRINT N'EXEC [monitor].[USP_ServerPrincipalAnalysis] @Hilfe=1;';




        SELECT @StatusCodeOut='AVAILABLE',@IsPartialOut=0;
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_ServerPrincipalAnalysis
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_ServerPrincipalAnalysis') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_ServerPrincipalAnalysis"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_ServerPrincipalAnalysis"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Die Procedure zeigt sichtbare Serverprincipals, direkte Rollenmitgliedschaften, explizite Berechtigungen und konfigurierte SQL-Login-Policies."'
            + NCHAR(10)
            + N'source_path: "Code/08_ServerHealth/260_USP_ServerPrincipalAnalysis.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_ServerPrincipalAnalysis'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure zeigt sichtbare Serverprincipals, direkte Rollenmitgliedschaften, explizite Berechtigungen und konfigurierte SQL-Login-Policies.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_ServerPrincipalAnalysis]. Die Quelle nennt insbesondere `sys.server_principals`, `sys.server_role_members`, `sys.server_permissions`, `[monitor].[InternalPrepareResultTables]`, `[sys].[server_principals]`, `[sys].[sp_executesql]`, `[sys].[server_role_members]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @MaxZeilen | int | nein | 1000 |'
            + NCHAR(10)
            + N'| @LockTimeoutMs | int | nein | 0 |'
            + NCHAR(10)
            + N'| @ResultSetArt | varchar(16) | nein | ''CONSOLE'' |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JsonErzeugen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Json | nvarchar(max) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @PrintMeldungen | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @PermissionGranteeName | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen begrenzt jedes der vier Fachresultsets; 0 oder NULL bedeutet unbegrenzt. @LockTimeoutMs erlaubt 0 bis 60000.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Millisekunden 0–60000; NULL und Werte außerhalb sind ungültig. 0 setzt NOWAIT für jede Quellenabfrage; sonst gilt der Wert je Quellbatch. Bei eingehendem @@LOCK_TIMEOUT=0 erhalten eigene Temp-DDL zunächst 1000 ms. Erfolg und gefangener äußerer Fehler stellen den Eingangswert wieder her.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Trimmen und Großschreibung normalisieren den einzelnen Modus: CONSOLE eine Übersicht; RAW sieben Sets in der Reihenfolge moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings; TABLE angeforderte Sets in lokale Seed-Temp-Tabellen; NONE keine Resultsets. NULL/Leertext und andere Werte sind ungültig.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE erlaubt eine nichtleere Zuordnung; sonst nur NULL/U+0020-Leerzeichen. TABLE verlangt ein gültiges, nichtleeres JSON-Objekt. Exakte Schlüssel: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings. Jeder Wert muss eine vorhandene, leere lokale #Temp-Tabelle (max. 116 Zeichen) mit einer Seed-Spalte benennen. Unzulässig: ##-/permanente/#Monitor*-Ziele, doppelte Schlüssel/Ziele, unbekannte Schlüssel, leere oder nicht-stringförmige Werte und nicht prüfbare Ziele. Helper-Preflight erfolgt vor Fachquellenzugriff; Writer ersetzt das Seed-Schema. Die Schlüssel bedeuten: moduleStatus Modulstatus, principals sichtbare Serverprincipals, roleMemberships direkte Rollenmitgliedschaften, permissions explizite Serverrechte, loginPolicies SQL-Login-Policykennzeichen, sourceStatus Quellenstatus und warnings Warnungen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit: 1 erzeugt JSON unabhängig vom Ausgabemodus; 0/NULL nicht. Hilfe und Validierungsfehler erzeugen keines. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT, bei Eintritt NULL. Mit @JsonErzeugen=1 enthält es meta und sieben benannte Arrays. Hilfe, Validierungs- und gefangener äußerer Fehler lassen es NULL. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; der Empfänger darf ausgelassen werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit: 1 sendet bei Validierungs-, Quellen- oder äußerem Fehler eine Zusatzmeldung mit Severity 10; 0/NULL unterdrückt sie. OUTPUT und RETURN sind weiter zu prüfen. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit; Default: 0. Bit: 1 druckt die eingebaute Parameterhilfe und Beispiele, setzt AVAILABLE/IsPartialOut=0 und kehrt vor Validierung und Quellenzugriff ohne Resultset zurück. JSON-/Fehler-OUTPUTs bleiben NULL. 0/NULL analysiert. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Hilfe liefert AVAILABLE und IsPartialOut=0. Eingabevalidierung liefert INVALID_PARAMETER mit RETURN 51011. Regulär lautet der Status AVAILABLE_LIMITED, sobald mindestens eine der vier Quellen ohne ErrorNumber vorliegt. Schlagen alle vier Quellen fehl, gilt aus der alphabetisch ersten SourceKey-Zeile DENIED_PERMISSION bei verweigerter Quelle (Fehler 229, 297, 300, 371), TIMEOUT bei Sperrtimeout 1222 oder ERROR_HANDLED bei anderem abgefangenen Quellenfehler. Der äußere CATCH liefert ERROR_HANDLED. Reguläre Quellenfehler ändern RETURN 0 nicht; Diagnose-OUTPUTs sind getrennt zu prüfen. Optionaler OUTPUT-Empfänger vom Typ varchar(40); zum Empfangen eine Variable mit OUTPUT binden, andernfalls auslassen. Der Eintritt setzt auch einen anfänglichen NULL- oder anderen Wert zunächst auf NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Hilfe 0; Analyse, Validierung und äußerer Fehler 1. Jede Analyse bleibt partiell, auch wenn alle Quellen lesbar sind. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Validierung 51011; regulär Fehlernummer der alphabetisch ersten fehlerhaften SourceKey-Quelle, sonst NULL. Äußerer Fehler: TABLE-Fehlercode, sonst ERROR_NUMBER(). Quellenfehler allein ändern RETURN nicht. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Validierung: feste Meldung; regulär: Meldung der alphabetisch ersten fehlerhaften Quelle, sonst NULL; äußerer Fehler: ERROR_MESSAGE(). Hilfe lässt NULL. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PermissionGranteeName:** @PermissionGranteeName nvarchar(max). Der Default ist NULL und lässt alle sichtbaren expliziten Serverrechte in permissions zu. Ein gesetzter Wert enthält genau einen unveränderten Serverprincipalnamen mit höchstens 128 UTF-16-Codeeinheiten. Leertext und ausschließlich U+0020-Leerzeichen sind ungültig. Der Vergleich ist bytegenau einschließlich Großschreibung und Leerzeichen. Der Filter wirkt nur auf permissions vor @MaxZeilen. Er verwendet sichtbare Empfängernamen und löst keine Rollenrechte auf.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| moduleStatus | 1 | 1 | [ModuleName] sysname NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) NOT NULL |'
            + NCHAR(10)
            + N'| principals | 1 | 1 | [PrincipalId] int NOT NULL, [PrincipalName] sysname NULL, [PrincipalType] char(1) NOT NULL, [PrincipalTypeDescription] nvarchar(60) NULL, [IsDisabled] bit NULL, [CreatedAt] datetime NULL, [ModifiedAt] datetime NULL, [IsFixedRole] bit NULL, [OwningPrincipalId] int NULL |'
            + NCHAR(10)
            + N'| roleMemberships | 1 | 1 | [RolePrincipalId] int NOT NULL, [RoleName] sysname NULL, [MemberPrincipalId] int NOT NULL, [MemberName] sysname NULL |'
            + NCHAR(10)
            + N'| permissions | 1 | 1 | [GranteePrincipalId] int NOT NULL, [GranteeName] sysname NULL, [GrantorPrincipalId] int NOT NULL, [GrantorName] sysname NULL, [Class] tinyint NOT NULL, [ClassDescription] nvarchar(60) NULL, [MajorId] int NOT NULL, [PermissionName] nvarchar(128) NULL, [PermissionState] char(1) NOT NULL, [PermissionStateDescription] nvarchar(60) NULL |'
            + NCHAR(10)
            + N'| loginPolicies | 1 | 1 | [PrincipalId] int NOT NULL, [PrincipalName] sysname NULL, [IsPolicyChecked] bit NULL, [IsExpirationChecked] bit NULL |'
            + NCHAR(10)
            + N'| sourceStatus | 1 | 1 | [SourceKey] varchar(64) NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) NOT NULL, [VisibilityScope] varchar(32) NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) NULL |'
            + NCHAR(10)
            + N'| warnings | 1 | 1 | [WarningCode] varchar(64) NOT NULL, [SourceKey] varchar(64) NULL, [Detail] nvarchar(1000) NOT NULL |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt=''RAW'', @MaxZeilen=100;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_ServerPrincipalAnalysis] @PermissionGranteeName=N''ExampleLogin'', @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Sichtbare Metadaten sind kein Vollständigkeitsnachweis. Implizite Rollenrechte und externe Gruppen werden nicht aufgelöst.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Verändert weder Principals noch Berechtigungen oder Nutzdaten.'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : monitor.USP_ServerPrincipalAnalysis'
            + NCHAR(10)
            + N'Version      : 1.0.1'
            + NCHAR(10)
            + N'Stand        : 2026-10-25'
            + NCHAR(10)
            + N'Zweck        : Die Procedure zeigt sichtbare Serverprincipals, direkte'
            + NCHAR(10)
            + N'               Rollenmitgliedschaften, explizite Berechtigungen und konfigurierte'
            + NCHAR(10)
            + N'               SQL-Login-Policies.'
            + NCHAR(10)
            + N'Quellen      : sys.server_principals, sys.server_role_members,'
            + NCHAR(10)
            + N'               sys.server_permissions und sys.sql_logins.'
            + NCHAR(10)
            + N'Grenzen      : Sichtbare Metadaten sind kein Vollständigkeitsnachweis. Implizite'
            + NCHAR(10)
            + N'               Rollenrechte und externe Gruppen werden nicht aufgelöst.'
            + NCHAR(10)
            + N'Datenschutz  : Liest keine Passwort-Hashes, Credentials oder Schlüssel.'
            + NCHAR(10)
            + N'Nebenwirkung : Verändert weder Principals noch Berechtigungen oder Nutzdaten.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_ServerPrincipalAnalysis'
            + NCHAR(10)
            + N'Liest sichtbare Principals, direkte Rollen, explizite Serverrechte und SQL-Login-Policyflags. Keine effektive Rechteberechnung.'
            + NCHAR(10)
            + N'RAW/TABLE/JSON: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings.'
            + NCHAR(10)
            + N'Parameter- und gefangene Ausgabefehler liefern Status, Diagnose-OUTPUT und einen Rückgabecode; optionale Meldungen haben Schweregrad 10.'
            + NCHAR(10)
            + N'DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;'
            + NCHAR(10)
            + N'EXEC @ReturnCode=[monitor].[USP_ServerPrincipalAnalysis]'
            + NCHAR(10)
            + N'      @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@Json OUTPUT'
            + NCHAR(10)
            + N'    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT'
            + NCHAR(10)
            + N'    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;'
            + NCHAR(10)
            + N'SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#ServerPrincipalAnalysis_HelpExample] ([Seed] int NULL);'
            + NCHAR(10)
            + N'DECLARE @Map nvarchar(max)=N''{"principals":"#ServerPrincipalAnalysis_HelpExample"}'';'
            + NCHAR(10)
            + N'BEGIN TRY'
            + NCHAR(10)
            + N'    EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt=''TABLE'', @ResultTablesJson=@Map;'
            + NCHAR(10)
            + N'    SELECT * FROM [#ServerPrincipalAnalysis_HelpExample];'
            + NCHAR(10)
            + N'    DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];'
            + NCHAR(10)
            + N'END TRY'
            + NCHAR(10)
            + N'BEGIN CATCH'
            + NCHAR(10)
            + N'    DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];'
            + NCHAR(10)
            + N'    THROW;'
            + NCHAR(10)
            + N'END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_ServerPrincipalAnalysis
        RETURN;
    END

    SELECT @Json=NULL,@StatusCodeOut=NULL,@IsPartialOut=NULL,
           @ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    DECLARE @CapturedAtUtc datetime2(3)=SYSUTCDATETIME(),
        @Mode varchar(16)=UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt,'')))),
        @Limit bigint=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE @MaxZeilen END,
        @PreviousLockTimeout int=@@LOCK_TIMEOUT,
        @PreviousXactAbort bit=CASE WHEN (@@OPTIONS & 16384)=16384 THEN 1 ELSE 0 END,
        @RestoreLock nvarchar(100),@SetLock nvarchar(100),@SetLockSource nvarchar(max),
        @Started datetime2(3),@Observed bigint,@Returned bigint,
        @Status varchar(40)='AVAILABLE_LIMITED',@Error int=NULL,@Message nvarchar(2048)=NULL;
    DECLARE @ConsoleResultRequested bit=CASE WHEN @Mode='CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableStatus varchar(40),@TableMessage nvarchar(2048),
        @TableError int,@TableFailureError int=NULL;
    SET @RestoreLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@PreviousLockTimeout)+N';';
    ;
    IF @Mode NOT IN ('CONSOLE','RAW','TABLE','NONE') OR @MaxZeilen<0
       OR @LockTimeoutMs IS NULL OR @LockTimeoutMs<0 OR @LockTimeoutMs>60000
       OR (@PermissionGranteeName IS NOT NULL
           AND (DATALENGTH(@PermissionGranteeName)>256 OR DATALENGTH(LTRIM(RTRIM(@PermissionGranteeName)))=0))
       OR (@Mode<>'TABLE' AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL)
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,
               @ErrorNumberOut=51011,@ErrorMessageOut=N'Ungültiger Ausgabe-, Limit-, Locktimeout-, TABLE- oder Grantee-Parameter.';
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@ErrorMessageOut) WITH NOWAIT;
        RETURN 51011;
    END;

    BEGIN TRY
        SET XACT_ABORT OFF;
        IF @PreviousLockTimeout=0 SET LOCK_TIMEOUT 1000;
    CREATE TABLE [#ServerPrincipalAnalysis_moduleStatus]
    (
        [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [CapturedAtUtc] datetime2(3) NOT NULL,
        [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [IsPartial] bit NOT NULL,
        [RowCount] bigint NOT NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_principals]
    (
        [PrincipalId] int NOT NULL,
        [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PrincipalTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsDisabled] bit NULL,
        [CreatedAt] datetime NULL,
        [ModifiedAt] datetime NULL,
        [IsFixedRole] bit NULL,
        [OwningPrincipalId] int NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_roleMemberships]
    (
        [RolePrincipalId] int NOT NULL,
        [RoleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [MemberPrincipalId] int NOT NULL,
        [MemberName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_permissions]
    (
        [GranteePrincipalId] int NOT NULL,
        [GranteeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [GrantorPrincipalId] int NOT NULL,
        [GrantorName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Class] tinyint NOT NULL,
        [ClassDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [MajorId] int NOT NULL,
        [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [PermissionState] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [PermissionStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_loginPolicies]
    (
        [PrincipalId] int NOT NULL,
        [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [IsPolicyChecked] bit NULL,
        [IsExpirationChecked] bit NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_sourceStatus]
    (
        [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
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
    CREATE TABLE [#ServerPrincipalAnalysis_warnings]
    (
        [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
        [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#ServerPrincipalAnalysis_Map]
    (
        [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
        [TargetTable] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
        IF @Mode='TABLE'
        BEGIN
            EXEC [monitor].[InternalPrepareResultTables] @ResultTablesJson=@ResultTablesJson,
                @AllowedResultNames=N'moduleStatus|principals|roleMemberships|permissions|loginPolicies|sourceStatus|warnings',
                @MappingTable=N'#ServerPrincipalAnalysis_Map',@StatusCode=@TableStatus OUTPUT,
                @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
            IF COALESCE(@TableStatus,'')<>'AVAILABLE'
            BEGIN
                SET @TableFailureError=51011;
                RAISERROR(N'%s',16,1,@TableMessage);
            END;
        END;
        SET LOCK_TIMEOUT 0;
        SET @SetLock=N'SET LOCK_TIMEOUT '+CONVERT(nvarchar(20),@LockTimeoutMs)+N'; ';
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @SetLockSource=@SetLock+N'INSERT [#ServerPrincipalAnalysis_principals]
            SELECT [p].[principal_id],[p].[name],[p].[type],[p].[type_desc],CONVERT(bit,[p].[is_disabled]),[p].[create_date],[p].[modify_date],[p].[is_fixed_role],[p].[owning_principal_id]
            FROM [sys].[server_principals] AS [p] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_PRINCIPALS',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#ServerPrincipalAnalysis_principals];
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_PRINCIPALS',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @SetLockSource=@SetLock+N'INSERT [#ServerPrincipalAnalysis_roleMemberships]
            SELECT [m].[role_principal_id],[r].[PrincipalName],[m].[member_principal_id],[p].[PrincipalName]
            FROM [sys].[server_role_members] AS [m] WITH (NOLOCK)
            LEFT JOIN [#ServerPrincipalAnalysis_principals] AS [r] ON [r].[PrincipalId]=[m].[role_principal_id]
            LEFT JOIN [#ServerPrincipalAnalysis_principals] AS [p] ON [p].[PrincipalId]=[m].[member_principal_id]; SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_ROLE_MEMBERS',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#ServerPrincipalAnalysis_roleMemberships];
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_ROLE_MEMBERS',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @SetLockSource=@SetLock+N'INSERT [#ServerPrincipalAnalysis_permissions]
            SELECT [e].[grantee_principal_id],[p].[PrincipalName],[e].[grantor_principal_id],[g].[PrincipalName],[e].[class],[e].[class_desc],[e].[major_id],[e].[permission_name],[e].[state],[e].[state_desc]
            FROM [sys].[server_permissions] AS [e] WITH (NOLOCK)
            LEFT JOIN [#ServerPrincipalAnalysis_principals] AS [p] ON [p].[PrincipalId]=[e].[grantee_principal_id]
            LEFT JOIN [#ServerPrincipalAnalysis_principals] AS [g] ON [g].[PrincipalId]=[e].[grantor_principal_id]
            WHERE @GranteeName IS NULL
               OR (DATALENGTH([p].[PrincipalName])=DATALENGTH(@GranteeName)
                  AND CONVERT(varbinary(256),[p].[PrincipalName])=CONVERT(varbinary(256),@GranteeName)); SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,N'@GranteeName nvarchar(max),@Rows bigint OUTPUT',
                @GranteeName=@PermissionGranteeName,@Rows=@Observed OUTPUT;
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_PERMISSIONS',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#ServerPrincipalAnalysis_permissions];
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SERVER_PERMISSIONS',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SET @Started=SYSUTCDATETIME();
        BEGIN TRY
            SET @SetLockSource=@SetLock+N'INSERT [#ServerPrincipalAnalysis_loginPolicies]
            SELECT [p].[principal_id],[p].[name],[p].[is_policy_checked],[p].[is_expiration_checked]
            FROM [sys].[sql_logins] AS [p] WITH (NOLOCK); SET @Rows=@@ROWCOUNT;';
            EXEC [sys].[sp_executesql] @SetLockSource,N'@Rows bigint OUTPUT',@Rows=@Observed OUTPUT;
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SQL_LOGIN_POLICIES',@Started,SYSUTCDATETIME(),'AVAILABLE_LIMITED','VISIBLE_ONLY',@Observed,@Observed,0,NULL,NULL);
        END TRY
        BEGIN CATCH
            DELETE FROM [#ServerPrincipalAnalysis_loginPolicies];
            INSERT [#ServerPrincipalAnalysis_sourceStatus] VALUES
                ('SQL_LOGIN_POLICIES',@Started,SYSUTCDATETIME(),
                 CASE WHEN ERROR_NUMBER() IN (229,297,300,371) THEN 'DENIED_PERMISSION'
                      WHEN ERROR_NUMBER()=1222 THEN 'TIMEOUT' ELSE 'ERROR_HANDLED' END,
                 'UNPROVEN',NULL,NULL,0,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [PrincipalId]) AS [OutputOrdinal] FROM [#ServerPrincipalAnalysis_principals])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_principals];
        UPDATE [#ServerPrincipalAnalysis_sourceStatus] SET [ReturnedRows]=@Returned,
            [IsLimited]=CASE WHEN [ObservedRows]>@Returned THEN 1 ELSE 0 END
        WHERE [SourceKey]='SERVER_PRINCIPALS';
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [RolePrincipalId],[MemberPrincipalId]) AS [OutputOrdinal] FROM [#ServerPrincipalAnalysis_roleMemberships])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_roleMemberships];
        UPDATE [#ServerPrincipalAnalysis_sourceStatus] SET [ReturnedRows]=@Returned,
            [IsLimited]=CASE WHEN [ObservedRows]>@Returned THEN 1 ELSE 0 END
        WHERE [SourceKey]='SERVER_ROLE_MEMBERS';
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [GranteePrincipalId],[Class],[MajorId],[PermissionName],[PermissionState],[GrantorPrincipalId]) AS [OutputOrdinal] FROM [#ServerPrincipalAnalysis_permissions])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_permissions];
        UPDATE [#ServerPrincipalAnalysis_sourceStatus] SET [ReturnedRows]=@Returned,
            [IsLimited]=CASE WHEN [ObservedRows]>@Returned THEN 1 ELSE 0 END
        WHERE [SourceKey]='SERVER_PERMISSIONS';
        ;WITH [Bounded] AS
        (SELECT *,ROW_NUMBER() OVER(ORDER BY [PrincipalId]) AS [OutputOrdinal] FROM [#ServerPrincipalAnalysis_loginPolicies])
        DELETE FROM [Bounded] WHERE [OutputOrdinal]>@Limit;
        SELECT @Returned=COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_loginPolicies];
        UPDATE [#ServerPrincipalAnalysis_sourceStatus] SET [ReturnedRows]=@Returned,
            [IsLimited]=CASE WHEN [ObservedRows]>@Returned THEN 1 ELSE 0 END
        WHERE [SourceKey]='SQL_LOGIN_POLICIES';
        INSERT [#ServerPrincipalAnalysis_warnings] VALUES
            ('METADATA_COMPLETENESS_UNPROVEN',NULL,N'Alle Mengen beschreiben ausschließlich sichtbare lokale Metadaten. Implizite Rollenrechte, externe Gruppen und effektive Berechtigungen sind nicht ausgewertet.');
        INSERT [#ServerPrincipalAnalysis_warnings]
            SELECT 'OUTPUT_LIMIT', [SourceKey],N'Das Fachresultset ist gekappt. Die Namensauflösung verwendet die davor materialisierte Principalsicht; ein Ausgabelimit begrenzt nicht die Kataloglesearbeit.'
            FROM [#ServerPrincipalAnalysis_sourceStatus] WHERE [IsLimited]=1;
        INSERT [#ServerPrincipalAnalysis_warnings]
            SELECT 'SOURCE_UNAVAILABLE',[SourceKey],N'Die Quelle konnte nicht gelesen werden; andere sichtbare Mengen bleiben eigenständig auswertbar.'
            FROM [#ServerPrincipalAnalysis_sourceStatus] WHERE [ErrorNumber] IS NOT NULL;
        SELECT TOP (1) @Error=[ErrorNumber],@Message=[ErrorMessage]
            FROM [#ServerPrincipalAnalysis_sourceStatus] WHERE [ErrorNumber] IS NOT NULL
            ORDER BY [SourceKey];
        IF NOT EXISTS(SELECT 1 FROM [#ServerPrincipalAnalysis_sourceStatus] WHERE [ErrorNumber] IS NULL)
            SELECT TOP (1) @Status=[StatusCode] FROM [#ServerPrincipalAnalysis_sourceStatus] ORDER BY [SourceKey];
        DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_principals])+
            (SELECT COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_roleMemberships])+
            (SELECT COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_permissions])+
            (SELECT COUNT_BIG(*) FROM [#ServerPrincipalAnalysis_loginPolicies]);
        INSERT [#ServerPrincipalAnalysis_moduleStatus] VALUES
            (N'USP_ServerPrincipalAnalysis',@CapturedAtUtc,@Status,1,@Rows,
             N'Getrennte Katalogmomentaufnahmen im Caller-Kontext; sichtbare direkte Zuordnungen und Policyflags, keine vollständige effektive Berechtigungsanalyse.');
        IF @JsonErzeugen=1
        BEGIN
            DECLARE @Meta nvarchar(max)=(SELECT N'ServerPrincipalAnalysis' AS [resultName],1 AS [schemaVersion],
                @CapturedAtUtc AS [generatedAtUtc],@Status AS [statusCode],CAST(1 AS bit) AS [isPartial],
                @Error AS [errorNumber],@Message AS [errorMessage] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            DECLARE @Json_moduleStatus nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_principals nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_principals] ORDER BY [PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_roleMemberships nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_roleMemberships] ORDER BY [RolePrincipalId],[MemberPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_permissions nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_permissions] ORDER BY [GranteePrincipalId],[Class],[MajorId],[PermissionName],[PermissionState],[GrantorPrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_loginPolicies nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_loginPolicies] ORDER BY [PrincipalId] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_sourceStatus nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_sourceStatus] ORDER BY [SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            DECLARE @Json_warnings nvarchar(max)=(SELECT * FROM [#ServerPrincipalAnalysis_warnings] ORDER BY [WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @Json=CONCAT(N'{"meta":',@Meta,N',"moduleStatus":',COALESCE(@Json_moduleStatus,N'[]'),N',"principals":',COALESCE(@Json_principals,N'[]'),N',"roleMemberships":',COALESCE(@Json_roleMemberships,N'[]'),N',"permissions":',COALESCE(@Json_permissions,N'[]'),N',"loginPolicies":',COALESCE(@Json_loginPolicies,N'[]'),N',"sourceStatus":',COALESCE(@Json_sourceStatus,N'[]'),N',"warnings":',COALESCE(@Json_warnings,N'[]'),N'}');
        END;
        IF @Mode='RAW'
        BEGIN
            SELECT * FROM [#ServerPrincipalAnalysis_moduleStatus];
            SELECT * FROM [#ServerPrincipalAnalysis_principals] ORDER BY [PrincipalId];
            SELECT * FROM [#ServerPrincipalAnalysis_roleMemberships] ORDER BY [RolePrincipalId],[MemberPrincipalId];
            SELECT * FROM [#ServerPrincipalAnalysis_permissions] ORDER BY [GranteePrincipalId],[Class],[MajorId],[PermissionName],[PermissionState],[GrantorPrincipalId];
            SELECT * FROM [#ServerPrincipalAnalysis_loginPolicies] ORDER BY [PrincipalId];
            SELECT * FROM [#ServerPrincipalAnalysis_sourceStatus] ORDER BY [SourceKey];
            SELECT * FROM [#ServerPrincipalAnalysis_warnings] ORDER BY [WarningCode],[SourceKey];
        END
        ELSE IF @Mode='TABLE'
        BEGIN
            DECLARE @ResultName sysname,@TargetTable sysname,@SourceTable sysname;
            DECLARE [ServerPrincipalOutput] CURSOR LOCAL FAST_FORWARD FOR
                SELECT [ResultName],[TargetTable] FROM [#ServerPrincipalAnalysis_Map] ORDER BY [ResultName];
            OPEN [ServerPrincipalOutput];
            FETCH NEXT FROM [ServerPrincipalOutput] INTO @ResultName,@TargetTable;
            WHILE @@FETCH_STATUS=0
            BEGIN
                SET @SourceTable=N'#ServerPrincipalAnalysis_'+@ResultName;
                EXEC [monitor].[InternalWriteResultTable] @SourceTable=@SourceTable,@TargetTable=@TargetTable,
                    @StatusCode=@TableStatus OUTPUT,@ErrorNumber=@TableError OUTPUT,
                    @ErrorMessage=@TableMessage OUTPUT,@ThrowOnError=0;
                IF COALESCE(@TableStatus,'')<>'AVAILABLE'
                BEGIN
                    SET @TableFailureError=COALESCE(@TableError,51010);
                    RAISERROR(N'%s',16,1,@TableMessage);
                END;
                FETCH NEXT FROM [ServerPrincipalOutput] INTO @ResultName,@TargetTable;
            END;
            CLOSE [ServerPrincipalOutput]; DEALLOCATE [ServerPrincipalOutput];
        END
        ELSE IF @ConsoleResultRequested=1
        BEGIN
            CREATE TABLE [#ServerPrincipalAnalysis_Console]
            (
                [Bereich] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
                [Objekt] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
                [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
            );
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Principal',[PrincipalName],CONCAT([PrincipalTypeDescription],N'; deaktiviert=',[IsDisabled],N'; feste Rolle=',[IsFixedRole])
                FROM [#ServerPrincipalAnalysis_principals];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Direkte Rolle',COALESCE([MemberName],CONVERT(nvarchar(20),[MemberPrincipalId])),
                       CONCAT(N'Rolle=',COALESCE([RoleName],CONVERT(nvarchar(20),[RolePrincipalId])))
                FROM [#ServerPrincipalAnalysis_roleMemberships];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Explizites Recht',COALESCE([GranteeName],CONVERT(nvarchar(20),[GranteePrincipalId])),
                       CONCAT([PermissionStateDescription],N' ',[PermissionName],N'; Klasse=',[ClassDescription],N'; MajorId=',[MajorId])
                FROM [#ServerPrincipalAnalysis_permissions];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Login-Policy',[PrincipalName],CONCAT(N'Policy=',[IsPolicyChecked],N'; Ablauf=',[IsExpirationChecked])
                FROM [#ServerPrincipalAnalysis_loginPolicies];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Quelle',[SourceKey],CONCAT([StatusCode],N'; sichtbar=',[ObservedRows],N'; Ausgabe=',[ReturnedRows])
                FROM [#ServerPrincipalAnalysis_sourceStatus];
            INSERT [#ServerPrincipalAnalysis_Console]
                SELECT N'Aussagegrenze',[WarningCode],[Detail] FROM [#ServerPrincipalAnalysis_warnings];
            EXEC [monitor].[InternalEmitConsoleResult] @SourceTable=N'#ServerPrincipalAnalysis_Console',
                @ResultLabel=N'Sichtbare Serverprincipals und direkte Berechtigungsevidenz',
                @EmptyMessage=N'Keine sichtbaren Serverprincipal-Metadaten.';
        END;
        SELECT @StatusCodeOut=@Status,@IsPartialOut=1,@ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        IF @PrintMeldungen=1 AND @Error IS NOT NULL
            RAISERROR(N'USP_ServerPrincipalAnalysis: mindestens eine Quelle ist nicht verfügbar; siehe sourceStatus.',10,1) WITH NOWAIT;
        EXEC [sys].[sp_executesql] @RestoreLock;
        IF @PreviousXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    END TRY
    BEGIN CATCH
        SELECT @Error=COALESCE(@TableFailureError,ERROR_NUMBER()),@Message=ERROR_MESSAGE(),@Json=NULL;
        SELECT @StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,
               @ErrorNumberOut=@Error,@ErrorMessageOut=@Message;
        EXEC [sys].[sp_executesql] @RestoreLock;
        SET XACT_ABORT OFF;
        IF @PrintMeldungen=1 RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
        RETURN @Error;
    END CATCH;
END;
GO
