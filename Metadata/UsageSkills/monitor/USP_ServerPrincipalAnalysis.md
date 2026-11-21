---
skill_format_version: "1.0.0"
name: "monitor.USP_ServerPrincipalAnalysis"
schema_name: "monitor"
object_name: "USP_ServerPrincipalAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure zeigt sichtbare Serverprincipals, direkte Rollenmitgliedschaften, explizite Berechtigungen und konfigurierte SQL-Login-Policies."
source_path: "Code/08_ServerHealth/260_USP_ServerPrincipalAnalysis.sql"
---

# monitor.USP_ServerPrincipalAnalysis

## Zweck und Einsatz

Die Procedure zeigt sichtbare Serverprincipals, direkte Rollenmitgliedschaften, explizite Berechtigungen und konfigurierte SQL-Login-Policies.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_ServerPrincipalAnalysis]. Die Quelle nennt insbesondere `sys.server_principals`, `sys.server_role_members`, `sys.server_permissions`, `[monitor].[InternalPrepareResultTables]`, `[sys].[server_principals]`, `[sys].[sp_executesql]`, `[sys].[server_role_members]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MaxZeilen | int | nein | 1000 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@MaxZeilen:** @MaxZeilen begrenzt jedes der vier Fachresultsets; 0 oder NULL bedeutet unbegrenzt. @LockTimeoutMs erlaubt 0 bis 60000.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Millisekunden 0–60000; NULL und Werte außerhalb sind ungültig. 0 setzt NOWAIT für jede Quellenabfrage; sonst gilt der Wert je Quellbatch. Bei eingehendem @@LOCK_TIMEOUT=0 erhalten eigene Temp-DDL zunächst 1000 ms. Erfolg und gefangener äußerer Fehler stellen den Eingangswert wieder her.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Trimmen und Großschreibung normalisieren den einzelnen Modus: CONSOLE eine Übersicht; RAW sieben Sets in der Reihenfolge moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings; TABLE angeforderte Sets in lokale Seed-Temp-Tabellen; NONE keine Resultsets. NULL/Leertext und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur TABLE erlaubt eine nichtleere Zuordnung; sonst nur NULL/U+0020-Leerzeichen. TABLE verlangt ein gültiges, nichtleeres JSON-Objekt. Exakte Schlüssel: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings. Jeder Wert muss eine vorhandene, leere lokale #Temp-Tabelle (max. 116 Zeichen) mit einer Seed-Spalte benennen. Unzulässig: ##-/permanente/#Monitor*-Ziele, doppelte Schlüssel/Ziele, unbekannte Schlüssel, leere oder nicht-stringförmige Werte und nicht prüfbare Ziele. Helper-Preflight erfolgt vor Fachquellenzugriff; Writer ersetzt das Seed-Schema. Die Schlüssel bedeuten: moduleStatus Modulstatus, principals sichtbare Serverprincipals, roleMemberships direkte Rollenmitgliedschaften, permissions explizite Serverrechte, loginPolicies SQL-Login-Policykennzeichen, sourceStatus Quellenstatus und warnings Warnungen.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit: 1 erzeugt JSON unabhängig vom Ausgabemodus; 0/NULL nicht. Hilfe und Validierungsfehler erzeugen keines. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT, bei Eintritt NULL. Mit @JsonErzeugen=1 enthält es meta und sieben benannte Arrays. Hilfe, Validierungs- und gefangener äußerer Fehler lassen es NULL. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; der Empfänger darf ausgelassen werden.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit: 1 sendet bei Validierungs-, Quellen- oder äußerem Fehler eine Zusatzmeldung mit Severity 10; 0/NULL unterdrückt sie. OUTPUT und RETURN sind weiter zu prüfen. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. Bit: 1 druckt die eingebaute Parameterhilfe und Beispiele, setzt AVAILABLE/IsPartialOut=0 und kehrt vor Validierung und Quellenzugriff ohne Resultset zurück. JSON-/Fehler-OUTPUTs bleiben NULL. 0/NULL analysiert. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Hilfe liefert AVAILABLE und IsPartialOut=0. Eingabevalidierung liefert INVALID_PARAMETER mit RETURN 51011. Regulär lautet der Status AVAILABLE_LIMITED, sobald mindestens eine der vier Quellen ohne ErrorNumber vorliegt. Schlagen alle vier Quellen fehl, gilt aus der alphabetisch ersten SourceKey-Zeile DENIED_PERMISSION bei verweigerter Quelle (Fehler 229, 297, 300, 371), TIMEOUT bei Sperrtimeout 1222 oder ERROR_HANDLED bei anderem abgefangenen Quellenfehler. Der äußere CATCH liefert ERROR_HANDLED. Reguläre Quellenfehler ändern RETURN 0 nicht; Diagnose-OUTPUTs sind getrennt zu prüfen. Optionaler OUTPUT-Empfänger vom Typ varchar(40); zum Empfangen eine Variable mit OUTPUT binden, andernfalls auslassen. Der Eintritt setzt auch einen anfänglichen NULL- oder anderen Wert zunächst auf NULL.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Hilfe 0; Analyse, Validierung und äußerer Fehler 1. Jede Analyse bleibt partiell, auch wenn alle Quellen lesbar sind. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Validierung 51011; regulär Fehlernummer der alphabetisch ersten fehlerhaften SourceKey-Quelle, sonst NULL. Äußerer Fehler: TABLE-Fehlercode, sonst ERROR_NUMBER(). Quellenfehler allein ändern RETURN nicht. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT; Eintritt NULL. Validierung: feste Meldung; regulär: Meldung der alphabetisch ersten fehlerhaften Quelle, sonst NULL; äußerer Fehler: ERROR_MESSAGE(). Hilfe lässt NULL. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) NOT NULL |
| principals | 1 | 1 | [PrincipalId] int NOT NULL, [PrincipalName] sysname NULL, [PrincipalType] char(1) NOT NULL, [PrincipalTypeDescription] nvarchar(60) NULL, [IsDisabled] bit NULL, [CreatedAt] datetime NULL, [ModifiedAt] datetime NULL, [IsFixedRole] bit NULL, [OwningPrincipalId] int NULL |
| roleMemberships | 1 | 1 | [RolePrincipalId] int NOT NULL, [RoleName] sysname NULL, [MemberPrincipalId] int NOT NULL, [MemberName] sysname NULL |
| permissions | 1 | 1 | [GranteePrincipalId] int NOT NULL, [GranteeName] sysname NULL, [GrantorPrincipalId] int NOT NULL, [GrantorName] sysname NULL, [Class] tinyint NOT NULL, [ClassDescription] nvarchar(60) NULL, [MajorId] int NOT NULL, [PermissionName] nvarchar(128) NULL, [PermissionState] char(1) NOT NULL, [PermissionStateDescription] nvarchar(60) NULL |
| loginPolicies | 1 | 1 | [PrincipalId] int NOT NULL, [PrincipalName] sysname NULL, [IsPolicyChecked] bit NULL, [IsExpirationChecked] bit NULL |
| sourceStatus | 1 | 1 | [SourceKey] varchar(64) NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) NOT NULL, [VisibilityScope] varchar(32) NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) NULL |
| warnings | 1 | 1 | [WarningCode] varchar(64) NOT NULL, [SourceKey] varchar(64) NULL, [Detail] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Sichtbare Metadaten sind kein Vollständigkeitsnachweis. Implizite Rollenrechte und externe Gruppen werden nicht aufgelöst.

Verändert weder Principals noch Berechtigungen oder Nutzdaten.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ServerPrincipalAnalysis
Liest sichtbare Principals, direkte Rollen, explizite Serverrechte und SQL-Login-Policyflags. Keine effektive Rechteberechnung.
RAW/TABLE/JSON: moduleStatus, principals, roleMemberships, permissions, loginPolicies, sourceStatus, warnings.
Parameter- und gefangene Ausgabefehler liefern Status, Diagnose-OUTPUT und einen Rückgabecode; optionale Meldungen haben Schweregrad 10.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_ServerPrincipalAnalysis]
      @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
CREATE TABLE [#ServerPrincipalAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"principals":"#ServerPrincipalAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_ServerPrincipalAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#ServerPrincipalAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#ServerPrincipalAnalysis_HelpExample];
    THROW;
END CATCH;
```

