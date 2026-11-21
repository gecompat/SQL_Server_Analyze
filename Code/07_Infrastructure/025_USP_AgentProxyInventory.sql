USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_AgentProxyInventory
Version      : 1.0.0
Zweck        : Inventarisiert SQL-Agent-Proxies, ihre Credentialreferenzen und
               ihre zugeordneten Subsysteme aus lesbaren Katalogquellen.
Datenquellen : msdb.dbo.sysproxies, msdb.dbo.sysproxysubsystem,
               msdb.dbo.syssubsystems und sys.credentials.
Grenzen      : Erfordert sysadmin-Sicht auf die Agenttabellen. Eine sichtbare
               Zuordnung belegt keine wirksame Ausführungsberechtigung.
               Credentialidentitäten, Secrets, SIDs, Loginzuordnungen,
               Befehle, Dateipfade und Jobausführung werden nicht gelesen.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_AgentProxyInventory 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_AgentProxyInventory"
-- schema_name: "monitor"
-- object_name: "USP_AgentProxyInventory"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Inventarisiert SQL-Agent-Proxies, ihre Credentialreferenzen und ihre zugeordneten Subsysteme aus lesbaren Katalogquellen."
-- source_path: "Code/07_Infrastructure/025_USP_AgentProxyInventory.sql"
-- ---
-- 
-- # monitor.USP_AgentProxyInventory
-- 
-- ## Zweck und Einsatz
-- 
-- Inventarisiert SQL-Agent-Proxies, ihre Credentialreferenzen und ihre zugeordneten Subsysteme aus lesbaren Katalogquellen.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufruf braucht EXECUTE auf [monitor].[USP_AgentProxyInventory] im vorgesehenen Datenbankkontext. Die Procedure liest `msdb`-Proxy-/Subsystemkataloge und `sys.credentials` als Metadaten unter dem aktuellen Caller; Credential-Secrets und Proxy-/OS-Ausführung werden nicht gelesen oder ausgelöst.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @MaxZeilen | int | nein | 1000 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @Hilfe | bit | nein | 0 |
-- | @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
-- | @IsPartialOut | bit | nein | NULL OUTPUT |
-- | @ErrorNumberOut | int | nein | NULL OUTPUT |
-- | @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |
-- 
-- **@MaxZeilen:** @MaxZeilen int=1000; Default: 1000. Positive ganze Werte von 1 bis 2147483647 begrenzen nach Proxyname und ProxyId die zurückgegebenen Proxies. Nur deren Subsystemzuordnungen erscheinen. NULL oder 0 bedeutet unbegrenzt; negative Werte ergeben INVALID_PARAMETER vor Quellenzugriff. Bei nicht lesbarer Proxyquelle sind Gesamt- und Rückgabemenge NULL; Quellenstatus werden separat ausgewiesen. Die Quellen können für Zählung und Auswahl vollständig gelesen werden; die Begrenzung ist keine Lesekostenobergrenze. Bei ausgelassenem Argument gilt der Default.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Äußere Leerzeichen werden entfernt, Groß-/Kleinschreibung ignoriert. Erlaubt sind CONSOLE (beschriftete Proxyzeilen), RAW (Modulstatus, Proxies, Proxy-Subsysteme), TABLE (nur Proxies in lokales Ziel), NONE (keine fachlichen Resultsets). NULL oder leerer Text ist ungültig und ergibt INVALID_PARAMETER. JSON und Status-OUTPUTs sind unabhängig. Bei ausgelassenem Argument gilt der Default.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur TABLE akzeptiert das JSON-Objekt {"proxies":"#ExampleTarget"} mit genau diesem case-sensitiven Schlüssel und einem lokalen #Temp-Tabellennamen als String. Das Ziel muss vorhanden und leer sein und genau eine Seed-Spalte besitzen; der Framework-Preflight prüft weitere Namens- und Schemagrenzen vor @Hilfe. NULL, leerer Text oder Leerzeichen sind nur außerhalb TABLE zulässig; nichtleerer Text außerhalb TABLE und ungültige TABLE-Ziele lösen Fehler 51011 aus. Bei ausgelassenem Argument gilt der Default.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. Genau 1 erzeugt zusätzlich JSON mit meta, proxies und proxySubsystems. 0 und NULL deaktivieren JSON. SQL Server konvertiert andere Eingaben beim Binden an bit oder weist sie vor Procedure-Eintritt ab. Bei ausgelassenem Argument gilt der Default.
-- 
-- **@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Eine nvarchar(max)-Variable mit OUTPUT binden. Die Procedure setzt den Wert zunächst auf NULL und füllt ihn nur bei @JsonErzeugen=1 nach dem Analysepfad; bei @Hilfe=1 bleibt er NULL. Ohne OUTPUT-Bindung erhält der Aufrufer keinen Rückgabewert. Bei ausgelassenem Argument gilt der Default.
-- 
-- **@Hilfe:** @Hilfe bit=0; Default: 0. Genau 1 gibt diese Hilfe mit PRINT aus und kehrt vor privilegiertem Quellenzugriff zurück. 0 und NULL führen die Analyse aus. SQL Server bindet andere Werte zuerst an bit. TABLE-Preflight und die ResultTables-Kombinationsprüfung liegen vor der Hilfe und können Fehler 51011 auslösen. Status-OUTPUTs bleiben im Hilfezweig unverändert. Bei ausgelassenem Argument gilt der Default.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Empfängt AVAILABLE, AVAILABLE_LIMITED, DENIED_PERMISSION oder INVALID_PARAMETER. AVAILABLE gilt nur nach erfolgreicher Lesung aller vier Quellen; AVAILABLE_LIMITED zeigt einen abgefangenen Quellenfehler; DENIED_PERMISSION zeigt fehlende sysadmin-Sicht oder einen SQL-Berechtigungsfehler; INVALID_PARAMETER zeigt einen ungültigen Zeilen- oder Ausgabewert. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.
-- 
-- **@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. 0 bedeutet vollständige Quellenlesung, 1 fehlende Lesung oder ungültigen Parameter. Ein gewähltes positives Zeilenlimit setzt allein kein Partialflag; meta.isTruncated kennzeichnet dessen tatsächliche Kürzung. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. Enthält bei abgefangenem Quellenfehler dessen erste SQL-Fehlernummer, sonst NULL. Die sysadmin-Vorprüfung und ungültige Parameter erzeugen keinen SQL-Fehlernummernwert. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. Enthält einen generischen Fehler- oder Parameterhinweis ohne Original-SQL-Fehlertext, sonst NULL. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.
-- 
-- ## Resultate und Ausgabe
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | proxies | 1 | 1 | [ProxyId] int NOT NULL, [ProxyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsEnabled] bit NOT NULL, [CredentialId] int NULL, [CredentialReferencePresent] bit NOT NULL, [CredentialName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CredentialCatalogStatus] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_AgentProxyInventory] @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Erfordert sysadmin-Sicht auf die Agenttabellen. Eine sichtbare Zuordnung belegt keine wirksame Ausführungsberechtigung. Credentialidentitäten, Secrets, SIDs, Loginzuordnungen, Befehle, Dateipfade und Jobausführung werden nicht gelesen.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_AgentProxyInventory
-- Version      : 1.0.0
-- Zweck        : Inventarisiert SQL-Agent-Proxies, ihre Credentialreferenzen und
--                ihre zugeordneten Subsysteme aus lesbaren Katalogquellen.
-- Datenquellen : msdb.dbo.sysproxies, msdb.dbo.sysproxysubsystem,
--                msdb.dbo.syssubsystems und sys.credentials.
-- Grenzen      : Erfordert sysadmin-Sicht auf die Agenttabellen. Eine sichtbare
--                Zuordnung belegt keine wirksame Ausführungsberechtigung.
--                Credentialidentitäten, Secrets, SIDs, Loginzuordnungen,
--                Befehle, Dateipfade und Jobausführung werden nicht gelesen.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_AgentProxyInventory
-- Lesende Inventur von SQL-Agent-Proxies und ihren Subsystemzuordnungen. Die Agenttabellen erfordern sysadmin; die Procedure erteilt keine Rechte und startet keine Jobs. Leere Ergebnisse sind nur bei vollständiger Quellenlesung eine leere Inventur. Der Kataloglesepfad verwendet LOCK_TIMEOUT 0 und WITH (NOLOCK); er kann bei Sperren sofort eingeschränkt sein und liefert keinen atomaren Snapshot. Er belegt weder Credentialnutzbarkeit noch effektive Privilegien oder Proxy-Ausführung.
-- CredentialReferencePresent bezeichnet nur eine gespeicherte CredentialId. CredentialCatalogStatus ist VISIBLE bei sichtbarem Namensmatch, NOT_VISIBLE_OR_MISSING ohne sichtbaren Match und NOT_CHECKED, wenn die Credentialquelle nicht gelesen werden konnte. Keine dieser Aussagen beweist die Nutzbarkeit oder Berechtigung des Credentials.
-- Beispiel 1: EXEC [monitor].[USP_AgentProxyInventory] @Hilfe=1;
-- Beispiel 2: EXEC [monitor].[USP_AgentProxyInventory] @MaxZeilen=100, @ResultSetArt='RAW';
-- Beispiel 3: DECLARE @ProxyJson nvarchar(max); EXEC [monitor].[USP_AgentProxyInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ProxyJson OUTPUT; SELECT @ProxyJson AS [Json];
-- Beispiel 4: CREATE TABLE #AgentProxyInventory_Example ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentProxyInventory] @ResultSetArt='TABLE', @ResultTablesJson=N'{"proxies":"#AgentProxyInventory_Example"}'; SELECT * FROM #AgentProxyInventory_Example; DROP TABLE #AgentProxyInventory_Example; END TRY BEGIN CATCH DROP TABLE #AgentProxyInventory_Example; THROW; END CATCH;
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_AgentProxyInventory
CREATE OR ALTER PROCEDURE [monitor].[USP_AgentProxyInventory]
      @MaxZeilen       int            = 1000
    , @ResultSetArt    varchar(16)    = 'CONSOLE'
    , @ResultTablesJson nvarchar(max) = NULL
    , @JsonErzeugen    bit            = 0
    , @Json            nvarchar(max)  = NULL OUTPUT
    , @Hilfe           bit            = 0
    , @StatusCodeOut   varchar(40)    = NULL OUTPUT
    , @IsPartialOut    bit            = NULL OUTPUT
    , @ErrorNumberOut  int            = NULL OUTPUT
    , @ErrorMessageOut nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_AgentProxyInventory';
        PRINT N'Lesende Inventur von SQL-Agent-Proxies und ihren Subsystemzuordnungen. Die Agenttabellen erfordern sysadmin; die Procedure erteilt keine Rechte und startet keine Jobs. Leere Ergebnisse sind nur bei vollständiger Quellenlesung eine leere Inventur. Der Kataloglesepfad verwendet LOCK_TIMEOUT 0 und WITH (NOLOCK); er kann bei Sperren sofort eingeschränkt sein und liefert keinen atomaren Snapshot. Er belegt weder Credentialnutzbarkeit noch effektive Privilegien oder Proxy-Ausführung.';
        PRINT N'@MaxZeilen int=1000; Default: 1000. Positive ganze Werte von 1 bis 2147483647 begrenzen nach Proxyname und ProxyId die zurückgegebenen Proxies. Nur deren Subsystemzuordnungen erscheinen. NULL oder 0 bedeutet unbegrenzt; negative Werte ergeben INVALID_PARAMETER vor Quellenzugriff. Bei nicht lesbarer Proxyquelle sind Gesamt- und Rückgabemenge NULL; Quellenstatus werden separat ausgewiesen. Die Quellen können für Zählung und Auswahl vollständig gelesen werden; die Begrenzung ist keine Lesekostenobergrenze. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Äußere Leerzeichen werden entfernt, Groß-/Kleinschreibung ignoriert. Erlaubt sind CONSOLE (beschriftete Proxyzeilen), RAW (Modulstatus, Proxies, Proxy-Subsysteme), TABLE (nur Proxies in lokales Ziel), NONE (keine fachlichen Resultsets). NULL oder leerer Text ist ungültig und ergibt INVALID_PARAMETER. JSON und Status-OUTPUTs sind unabhängig. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur TABLE akzeptiert das JSON-Objekt {"proxies":"#ExampleTarget"} mit genau diesem case-sensitiven Schlüssel und einem lokalen #Temp-Tabellennamen als String. Das Ziel muss vorhanden und leer sein und genau eine Seed-Spalte besitzen; der Framework-Preflight prüft weitere Namens- und Schemagrenzen vor @Hilfe. NULL, leerer Text oder Leerzeichen sind nur außerhalb TABLE zulässig; nichtleerer Text außerhalb TABLE und ungültige TABLE-Ziele lösen Fehler 51011 aus. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@JsonErzeugen bit=0; Default: 0. Genau 1 erzeugt zusätzlich JSON mit meta, proxies und proxySubsystems. 0 und NULL deaktivieren JSON. SQL Server konvertiert andere Eingaben beim Binden an bit oder weist sie vor Procedure-Eintritt ab. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@Json nvarchar(max)=NULL OUTPUT; Default: NULL. Eine nvarchar(max)-Variable mit OUTPUT binden. Die Procedure setzt den Wert zunächst auf NULL und füllt ihn nur bei @JsonErzeugen=1 nach dem Analysepfad; bei @Hilfe=1 bleibt er NULL. Ohne OUTPUT-Bindung erhält der Aufrufer keinen Rückgabewert. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@Hilfe bit=0; Default: 0. Genau 1 gibt diese Hilfe mit PRINT aus und kehrt vor privilegiertem Quellenzugriff zurück. 0 und NULL führen die Analyse aus. SQL Server bindet andere Werte zuerst an bit. TABLE-Preflight und die ResultTables-Kombinationsprüfung liegen vor der Hilfe und können Fehler 51011 auslösen. Status-OUTPUTs bleiben im Hilfezweig unverändert. Bei ausgelassenem Argument gilt der Default.';
        PRINT N'@StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Empfängt AVAILABLE, AVAILABLE_LIMITED, DENIED_PERMISSION oder INVALID_PARAMETER. AVAILABLE gilt nur nach erfolgreicher Lesung aller vier Quellen; AVAILABLE_LIMITED zeigt einen abgefangenen Quellenfehler; DENIED_PERMISSION zeigt fehlende sysadmin-Sicht oder einen SQL-Berechtigungsfehler; INVALID_PARAMETER zeigt einen ungültigen Zeilen- oder Ausgabewert. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.';
        PRINT N'@IsPartialOut bit=NULL OUTPUT; Default: NULL. 0 bedeutet vollständige Quellenlesung, 1 fehlende Lesung oder ungültigen Parameter. Ein gewähltes positives Zeilenlimit setzt allein kein Partialflag; meta.isTruncated kennzeichnet dessen tatsächliche Kürzung. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.';
        PRINT N'@ErrorNumberOut int=NULL OUTPUT; Default: NULL. Enthält bei abgefangenem Quellenfehler dessen erste SQL-Fehlernummer, sonst NULL. Die sysadmin-Vorprüfung und ungültige Parameter erzeugen keinen SQL-Fehlernummernwert. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.';
        PRINT N'@ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. Enthält einen generischen Fehler- oder Parameterhinweis ohne Original-SQL-Fehlertext, sonst NULL. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.';
        PRINT N'CredentialReferencePresent bezeichnet nur eine gespeicherte CredentialId. CredentialCatalogStatus ist VISIBLE bei sichtbarem Namensmatch, NOT_VISIBLE_OR_MISSING ohne sichtbaren Match und NOT_CHECKED, wenn die Credentialquelle nicht gelesen werden konnte. Keine dieser Aussagen beweist die Nutzbarkeit oder Berechtigung des Credentials.';
        PRINT N'Beispiel 1: EXEC [monitor].[USP_AgentProxyInventory] @Hilfe=1;';
        PRINT N'Beispiel 2: EXEC [monitor].[USP_AgentProxyInventory] @MaxZeilen=100, @ResultSetArt=''RAW'';';
        PRINT N'Beispiel 3: DECLARE @ProxyJson nvarchar(max); EXEC [monitor].[USP_AgentProxyInventory] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ProxyJson OUTPUT; SELECT @ProxyJson AS [Json];';
        PRINT N'Beispiel 4: CREATE TABLE #AgentProxyInventory_Example ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentProxyInventory] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"proxies":"#AgentProxyInventory_Example"}''; SELECT * FROM #AgentProxyInventory_Example; DROP TABLE #AgentProxyInventory_Example; END TRY BEGIN CATCH DROP TABLE #AgentProxyInventory_Example; THROW; END CATCH;';
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_AgentProxyInventory
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_AgentProxyInventory') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_AgentProxyInventory"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_AgentProxyInventory"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Inventarisiert SQL-Agent-Proxies, ihre Credentialreferenzen und ihre zugeordneten Subsysteme aus lesbaren Katalogquellen."'
            + NCHAR(10)
            + N'source_path: "Code/07_Infrastructure/025_USP_AgentProxyInventory.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_AgentProxyInventory'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Inventarisiert SQL-Agent-Proxies, ihre Credentialreferenzen und ihre zugeordneten Subsysteme aus lesbaren Katalogquellen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Aufruf braucht EXECUTE auf [monitor].[USP_AgentProxyInventory] im vorgesehenen Datenbankkontext. Die Procedure liest `msdb`-Proxy-/Subsystemkataloge und `sys.credentials` als Metadaten unter dem aktuellen Caller; Credential-Secrets und Proxy-/OS-Ausführung werden nicht gelesen oder ausgelöst.'
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
            + N'| @ResultSetArt | varchar(16) | nein | ''CONSOLE'' |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JsonErzeugen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Json | nvarchar(max) | nein | NULL OUTPUT |'
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
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int=1000; Default: 1000. Positive ganze Werte von 1 bis 2147483647 begrenzen nach Proxyname und ProxyId die zurückgegebenen Proxies. Nur deren Subsystemzuordnungen erscheinen. NULL oder 0 bedeutet unbegrenzt; negative Werte ergeben INVALID_PARAMETER vor Quellenzugriff. Bei nicht lesbarer Proxyquelle sind Gesamt- und Rückgabemenge NULL; Quellenstatus werden separat ausgewiesen. Die Quellen können für Zählung und Auswahl vollständig gelesen werden; die Begrenzung ist keine Lesekostenobergrenze. Bei ausgelassenem Argument gilt der Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16)=''CONSOLE''; Default: ''CONSOLE''. Äußere Leerzeichen werden entfernt, Groß-/Kleinschreibung ignoriert. Erlaubt sind CONSOLE (beschriftete Proxyzeilen), RAW (Modulstatus, Proxies, Proxy-Subsysteme), TABLE (nur Proxies in lokales Ziel), NONE (keine fachlichen Resultsets). NULL oder leerer Text ist ungültig und ergibt INVALID_PARAMETER. JSON und Status-OUTPUTs sind unabhängig. Bei ausgelassenem Argument gilt der Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur TABLE akzeptiert das JSON-Objekt {"proxies":"#ExampleTarget"} mit genau diesem case-sensitiven Schlüssel und einem lokalen #Temp-Tabellennamen als String. Das Ziel muss vorhanden und leer sein und genau eine Seed-Spalte besitzen; der Framework-Preflight prüft weitere Namens- und Schemagrenzen vor @Hilfe. NULL, leerer Text oder Leerzeichen sind nur außerhalb TABLE zulässig; nichtleerer Text außerhalb TABLE und ungültige TABLE-Ziele lösen Fehler 51011 aus. Bei ausgelassenem Argument gilt der Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. Genau 1 erzeugt zusätzlich JSON mit meta, proxies und proxySubsystems. 0 und NULL deaktivieren JSON. SQL Server konvertiert andere Eingaben beim Binden an bit oder weist sie vor Procedure-Eintritt ab. Bei ausgelassenem Argument gilt der Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Eine nvarchar(max)-Variable mit OUTPUT binden. Die Procedure setzt den Wert zunächst auf NULL und füllt ihn nur bei @JsonErzeugen=1 nach dem Analysepfad; bei @Hilfe=1 bleibt er NULL. Ohne OUTPUT-Bindung erhält der Aufrufer keinen Rückgabewert. Bei ausgelassenem Argument gilt der Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit=0; Default: 0. Genau 1 gibt diese Hilfe mit PRINT aus und kehrt vor privilegiertem Quellenzugriff zurück. 0 und NULL führen die Analyse aus. SQL Server bindet andere Werte zuerst an bit. TABLE-Preflight und die ResultTables-Kombinationsprüfung liegen vor der Hilfe und können Fehler 51011 auslösen. Status-OUTPUTs bleiben im Hilfezweig unverändert. Bei ausgelassenem Argument gilt der Default.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Empfängt AVAILABLE, AVAILABLE_LIMITED, DENIED_PERMISSION oder INVALID_PARAMETER. AVAILABLE gilt nur nach erfolgreicher Lesung aller vier Quellen; AVAILABLE_LIMITED zeigt einen abgefangenen Quellenfehler; DENIED_PERMISSION zeigt fehlende sysadmin-Sicht oder einen SQL-Berechtigungsfehler; INVALID_PARAMETER zeigt einen ungültigen Zeilen- oder Ausgabewert. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. 0 bedeutet vollständige Quellenlesung, 1 fehlende Lesung oder ungültigen Parameter. Ein gewähltes positives Zeilenlimit setzt allein kein Partialflag; meta.isTruncated kennzeichnet dessen tatsächliche Kürzung. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. Enthält bei abgefangenem Quellenfehler dessen erste SQL-Fehlernummer, sonst NULL. Die sysadmin-Vorprüfung und ungültige Parameter erzeugen keinen SQL-Fehlernummernwert. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. Enthält einen generischen Fehler- oder Parameterhinweis ohne Original-SQL-Fehlertext, sonst NULL. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| proxies | 1 | 1 | [ProxyId] int NOT NULL, [ProxyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsEnabled] bit NOT NULL, [CredentialId] int NULL, [CredentialReferencePresent] bit NOT NULL, [CredentialName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CredentialCatalogStatus] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |'
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
            + N'EXEC [monitor].[USP_AgentProxyInventory] @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Erfordert sysadmin-Sicht auf die Agenttabellen. Eine sichtbare Zuordnung belegt keine wirksame Ausführungsberechtigung. Credentialidentitäten, Secrets, SIDs, Loginzuordnungen, Befehle, Dateipfade und Jobausführung werden nicht gelesen.'
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
            + N'Objekt       : monitor.USP_AgentProxyInventory'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Zweck        : Inventarisiert SQL-Agent-Proxies, ihre Credentialreferenzen und'
            + NCHAR(10)
            + N'               ihre zugeordneten Subsysteme aus lesbaren Katalogquellen.'
            + NCHAR(10)
            + N'Datenquellen : msdb.dbo.sysproxies, msdb.dbo.sysproxysubsystem,'
            + NCHAR(10)
            + N'               msdb.dbo.syssubsystems und sys.credentials.'
            + NCHAR(10)
            + N'Grenzen      : Erfordert sysadmin-Sicht auf die Agenttabellen. Eine sichtbare'
            + NCHAR(10)
            + N'               Zuordnung belegt keine wirksame Ausführungsberechtigung.'
            + NCHAR(10)
            + N'               Credentialidentitäten, Secrets, SIDs, Loginzuordnungen,'
            + NCHAR(10)
            + N'               Befehle, Dateipfade und Jobausführung werden nicht gelesen.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_AgentProxyInventory'
            + NCHAR(10)
            + N'Lesende Inventur von SQL-Agent-Proxies und ihren Subsystemzuordnungen. Die Agenttabellen erfordern sysadmin; die Procedure erteilt keine Rechte und startet keine Jobs. Leere Ergebnisse sind nur bei vollständiger Quellenlesung eine leere Inventur. Der Kataloglesepfad verwendet LOCK_TIMEOUT 0 und WITH (NOLOCK); er kann bei Sperren sofort eingeschränkt sein und liefert keinen atomaren Snapshot. Er belegt weder Credentialnutzbarkeit noch effektive Privilegien oder Proxy-Ausführung.'
            + NCHAR(10)
            + N'CredentialReferencePresent bezeichnet nur eine gespeicherte CredentialId. CredentialCatalogStatus ist VISIBLE bei sichtbarem Namensmatch, NOT_VISIBLE_OR_MISSING ohne sichtbaren Match und NOT_CHECKED, wenn die Credentialquelle nicht gelesen werden konnte. Keine dieser Aussagen beweist die Nutzbarkeit oder Berechtigung des Credentials.'
            + NCHAR(10)
            + N'Beispiel 1: EXEC [monitor].[USP_AgentProxyInventory] @Hilfe=1;'
            + NCHAR(10)
            + N'Beispiel 2: EXEC [monitor].[USP_AgentProxyInventory] @MaxZeilen=100, @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'Beispiel 3: DECLARE @ProxyJson nvarchar(max); EXEC [monitor].[USP_AgentProxyInventory] @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@ProxyJson OUTPUT; SELECT @ProxyJson AS [Json];'
            + NCHAR(10)
            + N'Beispiel 4: CREATE TABLE #AgentProxyInventory_Example ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentProxyInventory] @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"proxies":"#AgentProxyInventory_Example"}''; SELECT * FROM #AgentProxyInventory_Example; DROP TABLE #AgentProxyInventory_Example; END TRY BEGIN CATCH DROP TABLE #AgentProxyInventory_Example; THROW; END CATCH;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_AgentProxyInventory
        RETURN;
    END

    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) = UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname = NULL;

    IF @TableResultRequested = 0
       AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson, N''))), N'') IS NOT NULL
        THROW 51011, N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.', 1;

    IF @TableResultRequested = 1
        EXEC [monitor].[InternalPrepareSingleResultTable]
              @ResultTablesJson = @ResultTablesJson
            , @ResultName = N'proxies'
            , @TargetTable = @TableTarget OUTPUT
            , @ThrowOnError = 1;

    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1
        SET @OutputMode = 'NONE';

    ;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @TotalProxyCount bigint = NULL;
    DECLARE @ReturnedProxyCount bigint = NULL;
    DECLARE @IsTruncated bit = 0;
    DECLARE @ProxySourceStatus varchar(16) = 'NOT_READ';
    DECLARE @CredentialSourceStatus varchar(16) = 'NOT_READ';
    DECLARE @SubsystemSourceStatus varchar(16) = 'NOT_READ';
    DECLARE @CollectionXactAbort int = @@OPTIONS & 16384;
    DECLARE @Limit bigint = CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
                                THEN CONVERT(bigint, 9223372036854775807)
                                ELSE CONVERT(bigint, @MaxZeilen) END;

    CREATE TABLE [#AgentProxyInventory_Proxies]
    (
          [ProxyId] int NOT NULL PRIMARY KEY
        , [ProxyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [IsEnabled] bit NOT NULL
        , [CredentialId] int NULL
        , [CredentialReferencePresent] bit NOT NULL
        , [CredentialName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [CredentialCatalogStatus] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );
    CREATE TABLE [#AgentProxyInventory_ProxySubsystems]
    (
          [ProxyId] int NOT NULL
        , [SubsystemId] int NOT NULL
        , [SubsystemName] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , PRIMARY KEY ([ProxyId], [SubsystemId])
    );

    IF @MaxZeilen < 0 OR @OutputMode NOT IN ('RAW', 'NONE')
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER', @IsPartial = 1,
               @ErrorMessage = N'Ungültiger Zeilen- oder Ausgabeparameter.';
    END
    ELSE IF IS_SRVROLEMEMBER(N'sysadmin') IS NULL
         OR IS_SRVROLEMEMBER(N'sysadmin') <> 1
    BEGIN
        SELECT @StatusCode = 'DENIED_PERMISSION', @IsPartial = 1,
               @ErrorMessage = N'Für die SQL-Agent-Proxy-Kataloge ist sysadmin-Sicht erforderlich.';
    END
    ELSE
    BEGIN
        SET LOCK_TIMEOUT 0;
        SET XACT_ABORT OFF;
        BEGIN TRY
            EXEC [sys].[sp_executesql] N'
                SELECT @Observed = COUNT_BIG(*)
                FROM [msdb].[dbo].[sysproxies] WITH (NOLOCK);
                ;WITH [SelectedProxies] AS
                (
                    SELECT TOP (@Bound) [p].[proxy_id], [p].[name], [p].[enabled],
                           [p].[credential_id]
                    FROM [msdb].[dbo].[sysproxies] AS [p] WITH (NOLOCK)
                    ORDER BY [p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS, [p].[proxy_id]
                )
                INSERT [#AgentProxyInventory_Proxies]
                    ([ProxyId], [ProxyName], [IsEnabled], [CredentialId],
                     [CredentialReferencePresent], [CredentialName], [CredentialCatalogStatus])
                SELECT [p].[proxy_id], [p].[name], CONVERT(bit, [p].[enabled]),
                       [p].[credential_id],
                       CASE WHEN [p].[credential_id] IS NULL THEN CONVERT(bit, 0)
                            ELSE CONVERT(bit, 1) END,
                       NULL, ''NOT_CHECKED''
                FROM [SelectedProxies] AS [p];',
                N'@Bound bigint, @Observed bigint OUTPUT',
                @Bound = @Limit, @Observed = @TotalProxyCount OUTPUT;

            SELECT @ReturnedProxyCount = COUNT_BIG(*) FROM [#AgentProxyInventory_Proxies];
            IF @TotalProxyCount > @ReturnedProxyCount SET @IsTruncated = 1;
            SET @ProxySourceStatus = 'AVAILABLE';
        END TRY
        BEGIN CATCH
            SELECT @StatusCode = CASE WHEN ERROR_NUMBER() IN (229, 230, 297, 371)
                                      THEN 'DENIED_PERMISSION' ELSE 'AVAILABLE_LIMITED' END,
                   @IsPartial = 1, @ErrorNumber = ERROR_NUMBER(),
                   @ErrorMessage = N'SQL-Agent-Proxy-Katalog nicht vollständig lesbar.',
                   @TotalProxyCount = NULL, @ReturnedProxyCount = NULL, @IsTruncated = 0,
                   @ProxySourceStatus = 'ERROR';
            DELETE FROM [#AgentProxyInventory_Proxies];
        END CATCH;

        IF @StatusCode = 'AVAILABLE'
        BEGIN
            BEGIN TRY
                EXEC [sys].[sp_executesql] N'
                    UPDATE [p]
                       SET [CredentialName] = [c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS,
                           [CredentialCatalogStatus] =
                               CASE WHEN [c].[credential_id] IS NULL
                                    THEN ''NOT_VISIBLE_OR_MISSING'' ELSE ''VISIBLE'' END
                    FROM [#AgentProxyInventory_Proxies] AS [p]
                    LEFT JOIN [sys].[credentials] AS [c] WITH (NOLOCK)
                      ON [c].[credential_id] = [p].[CredentialId];';
                SET @CredentialSourceStatus = 'AVAILABLE';
            END TRY
            BEGIN CATCH
                SELECT @StatusCode = 'AVAILABLE_LIMITED', @IsPartial = 1,
                       @ErrorNumber = ERROR_NUMBER(),
                       @ErrorMessage = N'Credential-Katalog nicht vollständig lesbar.';
                UPDATE [#AgentProxyInventory_Proxies]
                   SET [CredentialName] = NULL, [CredentialCatalogStatus] = 'NOT_CHECKED';
                SET @CredentialSourceStatus = 'ERROR';
            END CATCH;

            BEGIN TRY
                EXEC [sys].[sp_executesql] N'
                    INSERT [#AgentProxyInventory_ProxySubsystems]
                        ([ProxyId], [SubsystemId], [SubsystemName])
                    SELECT [m].[proxy_id], [m].[subsystem_id],
                           [s].[subsystem] COLLATE SQL_Latin1_General_CP1_CS_AS
                    FROM [msdb].[dbo].[sysproxysubsystem] AS [m] WITH (NOLOCK)
                    JOIN [#AgentProxyInventory_Proxies] AS [p] ON [p].[ProxyId] = [m].[proxy_id]
                    LEFT JOIN [msdb].[dbo].[syssubsystems] AS [s] WITH (NOLOCK)
                      ON [s].[subsystem_id] = [m].[subsystem_id];';
                SET @SubsystemSourceStatus = 'AVAILABLE';
            END TRY
            BEGIN CATCH
                IF @ErrorNumber IS NULL
                    SELECT @ErrorNumber = ERROR_NUMBER(),
                           @ErrorMessage = N'Proxy-Subsystem-Katalog nicht vollständig lesbar.';
                SELECT @StatusCode = 'AVAILABLE_LIMITED', @IsPartial = 1;
                DELETE FROM [#AgentProxyInventory_ProxySubsystems];
                SET @SubsystemSourceStatus = 'ERROR';
            END CATCH;
        END;
        IF @CollectionXactAbort = 0 SET XACT_ABORT OFF; ELSE SET XACT_ABORT ON;
    END;

    SELECT @StatusCodeOut = @StatusCode, @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber, @ErrorMessageOut = @ErrorMessage;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
            (SELECT N'AgentProxyInventory' AS [resultName], 1 AS [schemaVersion],
                    @Now AS [generatedAtUtc], @StatusCode AS [statusCode],
                    @IsPartial AS [isPartial], @ErrorNumber AS [errorNumber],
                    @ErrorMessage AS [errorMessage], @MaxZeilen AS [requestedMaxRows],
                    @TotalProxyCount AS [totalProxyCount],
                    @ReturnedProxyCount AS [returnedProxyCount],
                    @IsTruncated AS [isTruncated],
                    @ProxySourceStatus AS [proxySourceStatus],
                    @CredentialSourceStatus AS [credentialSourceStatus],
                    @SubsystemSourceStatus AS [subsystemSourceStatus]
             FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
        DECLARE @ProxiesJson nvarchar(max) =
            (SELECT [ProxyId], [ProxyName], [IsEnabled], [CredentialId],
                    [CredentialReferencePresent], [CredentialName], [CredentialCatalogStatus]
             FROM [#AgentProxyInventory_Proxies]
             ORDER BY [ProxyName] COLLATE SQL_Latin1_General_CP1_CS_AS, [ProxyId]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @SubsystemsJson nvarchar(max) =
            (SELECT [ProxyId], [SubsystemId], [SubsystemName]
             FROM [#AgentProxyInventory_ProxySubsystems]
             ORDER BY [ProxyId], [SubsystemId]
             FOR JSON PATH, INCLUDE_NULL_VALUES);
        SET @Json = CONCAT(N'{"meta":', COALESCE(@MetaJson, N'{}'),
                           N',"proxies":', COALESCE(@ProxiesJson, N'[]'),
                           N',"proxySubsystems":', COALESCE(@SubsystemsJson, N'[]'), N'}');
    END;

    IF @OutputMode = 'RAW'
    BEGIN
        SELECT N'USP_AgentProxyInventory' AS [ModuleName], @Now AS [CollectionTimeUtc],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage],
               @MaxZeilen AS [RequestedMaxRows], @TotalProxyCount AS [TotalProxyCount],
               @ReturnedProxyCount AS [ReturnedProxyCount], @IsTruncated AS [IsTruncated],
               @ProxySourceStatus AS [ProxySourceStatus],
               @CredentialSourceStatus AS [CredentialSourceStatus],
               @SubsystemSourceStatus AS [SubsystemSourceStatus];
        SELECT [ProxyId], [ProxyName], [IsEnabled], [CredentialId],
               [CredentialReferencePresent], [CredentialName], [CredentialCatalogStatus]
        FROM [#AgentProxyInventory_Proxies]
        ORDER BY [ProxyName] COLLATE SQL_Latin1_General_CP1_CS_AS, [ProxyId];
        SELECT [ProxyId], [SubsystemId], [SubsystemName]
        FROM [#AgentProxyInventory_ProxySubsystems]
        ORDER BY [ProxyId], [SubsystemId];
    END;

    IF @ConsoleResultRequested = 1
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable = N'#AgentProxyInventory_Proxies'
            , @ResultLabel = N'AgentProxyInventory'
            , @EmptyMessage = N'Keine sichtbaren Proxies oder Katalog nicht vollständig lesbar';

    IF @TableResultRequested = 1
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#AgentProxyInventory_Proxies'
            , @TargetTable = @TableTarget
            , @ThrowOnError = 1;
END;
GO
