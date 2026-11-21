---
skill_format_version: "1.0.0"
name: "monitor.USP_DatabasePrincipalAnalysis"
schema_name: "monitor"
object_name: "USP_DatabasePrincipalAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure zeigt sichtbare Datenbankprincipals, direkte Rollenmitgliedschaften, explizite Rechte, Schemaownership und begrenzte Bindungen zu sichtbaren Serverprincipals."
source_path: "Code/08_ServerHealth/270_USP_DatabasePrincipalAnalysis.sql"
---

# monitor.USP_DatabasePrincipalAnalysis

## Zweck und Einsatz

Die Procedure zeigt sichtbare Datenbankprincipals, direkte Rollenmitgliedschaften, explizite Rechte, Schemaownership und begrenzte Bindungen zu sichtbaren Serverprincipals.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabasePrincipalAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[sys].[databases]`, `[sys].[server_principals]`, `[sys].[sp_executesql]`, `[master].[sys].[databases]`, `[sys].[database_principals]`, `[sys].[database_role_members]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. NULL, N'' oder eine nur aus äußeren U+0020-Leerzeichen bestehende Eingabe schränken die Datenbankauswahl nicht ein. Andernfalls wird eine bracket-aware Pipe-Liste aus einzelnen Datenbanknamen erwartet; ein Pipe innerhalb eines geklammerten Namens ist Inhalt, und ]] maskiert dort eine schließende Klammer. Ungültige Elemente und doppelte gültige Namen führen zur Zurückweisung; Vorgesehen sind einteilige Namen. Der Parser übernimmt den letzten PARSENAME-Bestandteil, verlangt einen nichtleeren Wert bis 128 Zeichen und NULL für den zweiten Bestandteil; dritte und vierte Bestandteile werden nicht separat validiert. Ein rohes Listenelement ist auf 4.000 Zeichen begrenzt. Die exakten Namen werden case-sensitive verglichen. Nur eine aktive nichtleere Liste ist mit einem nicht-NULL-Pattern unvereinbar. Ohne beide Filter wählt die gemeinsame Kandidatenvorbereitung alle für den Caller sichtbaren, zugreifbaren Online-Datenbanken ohne Datenbanksnapshots; Systemdatenbanken hängen zusätzlich von @SystemdatenbankenEinbeziehen ab. Nicht verfügbare explizit angeforderte Namen erscheinen als Auswahlwarnungen; daraus wird Abwesenheit nicht sicher abgeleitet.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Systemdatenbanken mit Datenbank-IDs bis einschließlich 4 aus; 1 erlaubt ihre Aufnahme. NULL wird vom Auswahlhelfer als ungültiger Parameter zurückgewiesen. Systemdatenbanken müssen mit 1 ausdrücklich einbezogen werden. Die Auswahl bleibt auf sichtbare, online befindliche und für den aktuellen Login zugreifbare Datenbanken begrenzt.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. NULL bedeutet kein Patternfilter. Sonst werden äußere Leerzeichen entfernt und ein Präfix LIKE:, REGEX: oder REGEXI: ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der Inhalt nach einem Präfix wird nicht erneut getrimmt. Ein leerer oder nur aus Leerzeichen bestehender Wert sowie ein leeres Präfix-Ergebnis sind ungültig. Eine aktive nichtleere exakte Namensliste und ein nicht-NULL-Pattern sind unvereinbar. LIKE vergleicht case-sensitive. REGEX ist case-sensitive, REGEXI case-insensitive; Regexausführung verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Der Parser prüft keine Regexsyntax; ein ungültiges Regexmuster kann daher erst bei der Ausführung fehlschlagen. Der LIKE-Inhalt ist ein SQL-Server-LIKE-Muster: % steht für beliebig viele Zeichen, _ für ein Zeichen, [...] für Zeichenklassen. Die Abfrage definiert keine eigene ESCAPE-Klausel. REGEX/REGEXI-Inhalt wird unverändert an REGEXP_LIKE mit Flag c beziehungsweise i übergeben; Parservalidierung ersetzt keine Regexsyntaxprüfung.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. NULL oder 0 bedeutet kein Ausgabelimit; ein negativer Wert ist ungültig. Ein positiver Wert begrenzt jeweils separat die fünf Fachmengen principals, roleMemberships, permissions, schemaOwners und loginBindings global über alle gewählten Datenbanken. Die Kürzung erfolgt nach der jeweiligen dokumentierten Sortierung; bei identischen Sortierschlüsseln ist keine zusätzliche Tie-Break-Garantie festgelegt. databaseContext, moduleStatus, sourceStatus und warnings werden nicht gekappt. Die vollständigen sichtbaren Quellmengen werden vor der Kürzung materialisiert; das Limit reduziert daher nicht die Kataloglesearbeit oder die zuvor gebildeten Namens- und SID-Zuordnungen. ObservedRows und ReturnedRows sowie IsLimited halten Quellmenge und Ausgabe auseinander.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. NULL, negative Werte und Werte über 60000 sind ungültig; 0 bis 60000 sind Millisekunden und der Vorgabewert 0 setzt NOWAIT für die dynamischen fachlichen Quellbatches. Ein positiver Wert erlaubt diesen Batches entsprechend viele Millisekunden auf eine Sperre zu warten. Bei eingehendem Caller-LOCK_TIMEOUT 0 verwendet die Procedure für eigene Temp-DDL-Statements bis zu 1000 ms je Statement; dies ist kein zusätzliches Quellzeitbudget. Am Ende wird der eingehende LOCK_TIMEOUT-Wert wiederhergestellt. Der Parameter ist keine Gesamtzeitgrenze für den Aufruf und begründet keine atomare Aufnahme.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. NULL oder ein anderer als die vier folgenden Werte ist ungültig. Groß-/Kleinschreibung und äußere Leerzeichen werden normalisiert. CONSOLE erzeugt eine formatierte Ergebnisübersicht; RAW liefert neun native Resultsets; TABLE schreibt die angeforderten Mengen in lokale Temp-Tabellen; NONE unterdrückt fachliche Resultsets. JSON kann unabhängig von dieser Auswahl zusätzlich über @Json ausgegeben werden. Bei jeder Auswahl außer TABLE muss @ResultTablesJson NULL, leer oder nur aus äußeren U+0020-Leerzeichen bestehen.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Außer bei ResultSetArt=TABLE muss der Wert NULL, leer oder nur aus äußeren U+0020-Leerzeichen sein; ein anderer Inhalt ist INVALID_PARAMETER. Im TABLE-Modus ist ein nichtleeres gültiges JSON-Objekt erforderlich, das mindestens eine Zuordnung von einem Resultsetnamen zu einem lokalen Temp-Tabellennamen enthält. Erlaubte Namen sind exakt moduleStatus, databaseContext, principals, roleMemberships, permissions, schemaOwners, loginBindings, sourceStatus und warnings; jeder Name darf nur einmal, jedes Ziel nur einmal (case-insensitive) vorkommen. Jeder Wert muss eine nichtleere Zeichenfolge sein. Ziele müssen vorhandene, leere lokale #Temp-Tabellen mit höchstens 116 Zeichen und genau einer Seed-Spalte bezeichnen; ##-, #Monitor*- und permanente Ziele sind unzulässig. Die Vorprüfung erfolgt vor fachlichen Katalogzugriffen. Der Schreiber passt die Seed-Struktur beim Schreiben an die native Quellstruktur an. Die Schlüssel bedeuten: moduleStatus Modulstatus, databaseContext Datenbankkontext und Identitätsbindung, principals Datenbankprincipals, roleMemberships direkte Rollenmitgliedschaften, permissions explizite Datenbankrechte, schemaOwners Schemaownership, loginBindings sichtbare Loginbindungen, sourceStatus Quellenstatus und warnings Warnungen.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt zusätzlich das JSON-Dokument in @Json, unabhängig von ResultSetArt; 0 erzeugt es nicht. NULL wird nicht gesondert zurückgewiesen und verhält sich im IF-Test wie nicht aktiviert. Die neun Arrays entsprechen den neun fachlichen Mengen, ergänzt um meta; Zeilen enthalten NULL-Felder. Bei einem gefangenen äußeren Fehler bleibt @Json NULL. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Als OUTPUT-Parameter muss die Variable des Aufrufers mit OUTPUT gebunden werden, damit das Ergebnis zurückgegeben wird. Zu Aufrufbeginn setzt die Procedure den Parameter auf NULL; bei @JsonErzeugen=1 enthält er nach erfolgreicher Verarbeitung meta und die neun geordneten JSON-Arrays mit INCLUDE_NULL_VALUES. Ohne Aktivierung und nach einem gefangenen äußeren Fehler bleibt der Wert NULL. Die JSON-Erzeugungszeit macht die getrennten Quellaufnahmen nicht atomar. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; der Empfänger darf ausgelassen werden.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 (auch Vorgabewert) erlaubt die vorgesehenen PRINT- beziehungsweise RAISERROR-Meldungen mit Schweregrad 10 und NOWAIT: Die Hilfezeilen erscheinen bei @Hilfe=1 unabhängig von diesem Schalter; bei ungültigen Parametern, gefangenen äußeren Fehlern und Quellenfehlern mit ermitteltem ErrorNumber werden Diagnosemeldungen gesendet. 0 unterdrückt diese Meldungen. NULL wird nicht validiert und erfüllt die IF-Bedingung für 1 nicht. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. 1 gibt die eingebaute Parameterhilfe und Beispiele aus und beendet die Procedure vor Parameterprüfung oder Katalogzugriff. Dabei werden @StatusCodeOut auf AVAILABLE und @IsPartialOut auf 0 gesetzt; @Json sowie die Fehler-OUTPUTs sind zuvor beim Eintritt auf NULL zurückgesetzt. 0 führt den normalen Aufruf aus. NULL wird nicht zurückgewiesen und wirkt wie nicht aktiviert. Der Hilfestatus bestätigt weder Vollständigkeit noch vollständige Rechte. SQL-Konvertierung nach bit: numerische 0 ergibt 0; von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Hilfe liefert AVAILABLE; Eingabevalidierung INVALID_PARAMETER. Kandidatenhelferfehler liefern INVALID_PARAMETER für ungültige Auswahl, INTERNAL_ERROR für ein internes Kandidatenschema oder UNAVAILABLE_FEATURE für nicht verfügbare Regex-Voraussetzungen, jeweils mit RETURN 51011. Regulär gilt AVAILABLE_LIMITED, sobald eine native DB-Quelle diesen erfolgreichen, aber unbewiesenen Metadatenstatus besitzt. Andernfalls wird der erste Status ungleich AVAILABLE_LIMITED/SKIPPED nach DatabaseName, SourceKey gewählt: DENIED_PERMISSION für verweigerte Quelle, TIMEOUT für Sperrtimeout, DATABASE_UNAVAILABLE für nicht verfügbaren Datenbankkontext, ERROR_HANDLED für andere behandelte Quellenfehler, STATUS_UNAVAILABLE als fehlende Statuskennung oder SYSTEM_DATABASE_EXCLUDED für einen ausgeschlossenen expliziten Systemnamen. DATABASE_UNAVAILABLE kann ebenso aus der Auswahl stammen. Sonstige äußere Fehler liefern ERROR_HANDLED. Fehlernummer/-meldung werden davon getrennt nach DatabaseId, SourceKey priorisiert. Reguläre Verarbeitung und Hilfe liefern RETURN 0; ein äußerer Fehler liefert seinen Diagnosecode. Optionaler OUTPUT-Empfänger vom Typ varchar(40); zum Empfangen eine Variable mit OUTPUT binden, andernfalls auslassen. Der Eintritt setzt auch einen anfänglichen NULL- oder anderen Wert zunächst auf NULL.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Bei Eintritt wird der Empfänger auf NULL gesetzt. Die Hilfe setzt 0. Ungültige Eingaben, reguläre Fachverarbeitung und gefangene äußere Fehler setzen 1; auch AVAILABLE_LIMITED mit vollständig lesbaren angeforderten Quellen bleibt wegen des begrenzten Aussageumfangs partiell. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Bei Eintritt wird der Empfänger auf NULL gesetzt. Sie bleibt NULL, wenn kein Fehlercode ermittelt wurde. Ungültige Parameter liefern 51011; bei Quellenfehlern wird der erste vorhandene native ErrorNumber-Wert nach Datenbank-ID und SourceKey ausgewählt. Der äußere CATCH liefert den für den Fehlerpfad gesetzten Code oder den abgefangenen SQL-Fehlercode; TABLE-Fehler können dabei aus dem Vorbereitungs- oder Schreibhelfer stammen. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei Eintritt wird der Empfänger auf NULL gesetzt. Sie bleibt NULL, wenn kein Fehlertext ermittelt wurde. Bei ungültigen Parametern enthält sie die Validierungsdiagnose; bei regulärer Verarbeitung mit Quellenfehlern stammt sie aus dem ersten Fehler nach Datenbank-ID und SourceKey. Der äußere CATCH gibt die abgefangene Meldung auf höchstens 2048 Zeichen begrenzt zurück. Die OUTPUT-Diagnose ersetzt weder Statusprüfung noch RETURN-Code. Optionaler Empfänger: Zum Empfangen eine Variable des deklarierten Typs mit OUTPUT binden; andernfalls das Argument auslassen. Ein anfänglicher NULL- oder anderer Wert wird am Eintritt zurückgesetzt.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [CapturedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsPartial] bit NOT NULL, [RowCount] bigint NOT NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| databaseContext | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ContainmentDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerPrincipalId] int NULL, [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerPrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwnerBindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| principals | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PrincipalType] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [AuthenticationType] int NULL, [AuthenticationTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [DefaultSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CreatedAt] datetime NULL, [ModifiedAt] datetime NULL, [IsFixedRole] bit NULL, [OwningPrincipalId] int NULL |
| roleMemberships | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RolePrincipalId] int NOT NULL, [RoleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MemberPrincipalId] int NOT NULL, [MemberName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| permissions | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [GranteePrincipalId] int NOT NULL, [GranteeName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [GrantorPrincipalId] int NOT NULL, [GrantorName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Class] tinyint NOT NULL, [ClassDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [MajorId] int NOT NULL, [MinorId] int NOT NULL, [PermissionName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PermissionState] char(1) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PermissionStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| schemaOwners | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SchemaId] int NOT NULL, [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OwningPrincipalId] int NOT NULL, [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| loginBindings | 1 | 1 | [DatabaseId] int NOT NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [PrincipalId] int NOT NULL, [PrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [BindingStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ServerPrincipalId] int NULL, [ServerPrincipalName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| sourceStatus | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StartedAtUtc] datetime2(3) NOT NULL, [CompletedAtUtc] datetime2(3) NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [ObservedRows] bigint NULL, [ReturnedRows] bigint NULL, [IsLimited] bit NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| warnings | 1 | 1 | [DatabaseId] int NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DatabasePrincipalAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Keine effektiven Rechte oder externe Gruppenauflosung. Fehlende sichtbare SID-Treffer beweisen keine verwaisten Identitaeten.

Rein lesend; keine Berechtigungs- oder Ownershipaenderung.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DatabasePrincipalAnalysis
Ohne Filter: alle sichtbaren Online-Benutzerdatenbanken; Systemdatenbanken sind opt-in. DatabaseNames und DatabaseNamePattern sind getrennt.
Neun Mengen: moduleStatus, databaseContext, principals, roleMemberships, permissions, schemaOwners, loginBindings, sourceStatus, warnings.
Keine effektiven Rechte oder sicheren Orphan-Negativschluesse. Fehler sind ueber Status, Diagnose-OUTPUT und RETURN zu pruefen.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ErrorNumber int, @ErrorMessage nvarchar(2048), @ReturnCode int;
EXEC @ReturnCode=[monitor].[USP_DatabasePrincipalAnalysis]
      @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT
    , @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT
    , @ErrorNumberOut=@ErrorNumber OUTPUT, @ErrorMessageOut=@ErrorMessage OUTPUT;
SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage], @Json AS [Json];
CREATE TABLE [#DatabasePrincipalAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @Map nvarchar(max)=N'{"principals":"#DatabasePrincipalAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_DatabasePrincipalAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@Map;
    SELECT * FROM [#DatabasePrincipalAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#DatabasePrincipalAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#DatabasePrincipalAnalysis_HelpExample];
    THROW;
END CATCH;
```

