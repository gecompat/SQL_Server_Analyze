---
skill_format_version: "1.0.0"
name: "monitor.USP_AgentProxyInventory"
schema_name: "monitor"
object_name: "USP_AgentProxyInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert SQL-Agent-Proxies, ihre Credentialreferenzen und ihre zugeordneten Subsysteme aus lesbaren Katalogquellen."
source_path: "Code/07_Infrastructure/025_USP_AgentProxyInventory.sql"
---

# monitor.USP_AgentProxyInventory

## Zweck und Einsatz

Inventarisiert SQL-Agent-Proxies, ihre Credentialreferenzen und ihre zugeordneten Subsysteme aus lesbaren Katalogquellen.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_AgentProxyInventory] im vorgesehenen Datenbankkontext. Die Procedure liest `msdb`-Proxy-/Subsystemkataloge und `sys.credentials` als Metadaten unter dem aktuellen Caller; Credential-Secrets und Proxy-/OS-Ausführung werden nicht gelesen oder ausgelöst.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@MaxZeilen:** @MaxZeilen int=1000; Default: 1000. Positive ganze Werte von 1 bis 2147483647 begrenzen nach Proxyname und ProxyId die zurückgegebenen Proxies. Nur deren Subsystemzuordnungen erscheinen. NULL oder 0 bedeutet unbegrenzt; negative Werte ergeben INVALID_PARAMETER vor Quellenzugriff. Bei nicht lesbarer Proxyquelle sind Gesamt- und Rückgabemenge NULL; Quellenstatus werden separat ausgewiesen. Die Quellen können für Zählung und Auswahl vollständig gelesen werden; die Begrenzung ist keine Lesekostenobergrenze. Bei ausgelassenem Argument gilt der Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Äußere Leerzeichen werden entfernt, Groß-/Kleinschreibung ignoriert. Erlaubt sind CONSOLE (beschriftete Proxyzeilen), RAW (Modulstatus, Proxies, Proxy-Subsysteme), TABLE (nur Proxies in lokales Ziel), NONE (keine fachlichen Resultsets). NULL oder leerer Text ist ungültig und ergibt INVALID_PARAMETER. JSON und Status-OUTPUTs sind unabhängig. Bei ausgelassenem Argument gilt der Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur TABLE akzeptiert das JSON-Objekt {"proxies":"#ExampleTarget"} mit genau diesem case-sensitiven Schlüssel und einem lokalen #Temp-Tabellennamen als String. Das Ziel muss vorhanden und leer sein und genau eine Seed-Spalte besitzen; der Framework-Preflight prüft weitere Namens- und Schemagrenzen vor @Hilfe. NULL, leerer Text oder Leerzeichen sind nur außerhalb TABLE zulässig; nichtleerer Text außerhalb TABLE und ungültige TABLE-Ziele lösen Fehler 51011 aus. Bei ausgelassenem Argument gilt der Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. Genau 1 erzeugt zusätzlich JSON mit meta, proxies und proxySubsystems. 0 und NULL deaktivieren JSON. SQL Server konvertiert andere Eingaben beim Binden an bit oder weist sie vor Procedure-Eintritt ab. Bei ausgelassenem Argument gilt der Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Eine nvarchar(max)-Variable mit OUTPUT binden. Die Procedure setzt den Wert zunächst auf NULL und füllt ihn nur bei @JsonErzeugen=1 nach dem Analysepfad; bei @Hilfe=1 bleibt er NULL. Ohne OUTPUT-Bindung erhält der Aufrufer keinen Rückgabewert. Bei ausgelassenem Argument gilt der Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. Genau 1 gibt diese Hilfe mit PRINT aus und kehrt vor privilegiertem Quellenzugriff zurück. 0 und NULL führen die Analyse aus. SQL Server bindet andere Werte zuerst an bit. TABLE-Preflight und die ResultTables-Kombinationsprüfung liegen vor der Hilfe und können Fehler 51011 auslösen. Status-OUTPUTs bleiben im Hilfezweig unverändert. Bei ausgelassenem Argument gilt der Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Empfängt AVAILABLE, AVAILABLE_LIMITED, DENIED_PERMISSION oder INVALID_PARAMETER. AVAILABLE gilt nur nach erfolgreicher Lesung aller vier Quellen; AVAILABLE_LIMITED zeigt einen abgefangenen Quellenfehler; DENIED_PERMISSION zeigt fehlende sysadmin-Sicht oder einen SQL-Berechtigungsfehler; INVALID_PARAMETER zeigt einen ungültigen Zeilen- oder Ausgabewert. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. 0 bedeutet vollständige Quellenlesung, 1 fehlende Lesung oder ungültigen Parameter. Ein gewähltes positives Zeilenlimit setzt allein kein Partialflag; meta.isTruncated kennzeichnet dessen tatsächliche Kürzung. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. Enthält bei abgefangenem Quellenfehler dessen erste SQL-Fehlernummer, sonst NULL. Die sysadmin-Vorprüfung und ungültige Parameter erzeugen keinen SQL-Fehlernummernwert. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. Enthält einen generischen Fehler- oder Parameterhinweis ohne Original-SQL-Fehlertext, sonst NULL. Mit OUTPUT binden; ohne Bindung kein Rückgabewert. Bei @Hilfe=1 oder frühem Fehler bleibt die Bindungsvariable unverändert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| proxies | 1 | 1 | [ProxyId] int NOT NULL, [ProxyName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [IsEnabled] bit NOT NULL, [CredentialId] int NULL, [CredentialReferencePresent] bit NOT NULL, [CredentialName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [CredentialCatalogStatus] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_AgentProxyInventory] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Erfordert sysadmin-Sicht auf die Agenttabellen. Eine sichtbare Zuordnung belegt keine wirksame Ausführungsberechtigung. Credentialidentitäten, Secrets, SIDs, Loginzuordnungen, Befehle, Dateipfade und Jobausführung werden nicht gelesen.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_AgentProxyInventory
Lesende Inventur von SQL-Agent-Proxies und ihren Subsystemzuordnungen. Die Agenttabellen erfordern sysadmin; die Procedure erteilt keine Rechte und startet keine Jobs. Leere Ergebnisse sind nur bei vollständiger Quellenlesung eine leere Inventur. Der Kataloglesepfad verwendet LOCK_TIMEOUT 0 und WITH (NOLOCK); er kann bei Sperren sofort eingeschränkt sein und liefert keinen atomaren Snapshot. Er belegt weder Credentialnutzbarkeit noch effektive Privilegien oder Proxy-Ausführung.
CredentialReferencePresent bezeichnet nur eine gespeicherte CredentialId. CredentialCatalogStatus ist VISIBLE bei sichtbarem Namensmatch, NOT_VISIBLE_OR_MISSING ohne sichtbaren Match und NOT_CHECKED, wenn die Credentialquelle nicht gelesen werden konnte. Keine dieser Aussagen beweist die Nutzbarkeit oder Berechtigung des Credentials.
Beispiel 1: EXEC [monitor].[USP_AgentProxyInventory] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_AgentProxyInventory] @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 3: DECLARE @ProxyJson nvarchar(max); EXEC [monitor].[USP_AgentProxyInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ProxyJson OUTPUT; SELECT @ProxyJson AS [Json];
Beispiel 4: CREATE TABLE #AgentProxyInventory_Example ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentProxyInventory] @ResultSetArt='TABLE', @ResultTablesJson=N'{"proxies":"#AgentProxyInventory_Example"}'; SELECT * FROM #AgentProxyInventory_Example; DROP TABLE #AgentProxyInventory_Example; END TRY BEGIN CATCH DROP TABLE #AgentProxyInventory_Example; THROW; END CATCH;
```

