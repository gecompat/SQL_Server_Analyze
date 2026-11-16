# [monitor].[USP_AgentProxyInventory]

`monitor.USP_AgentProxyInventory` liest SQL-Server-Agent-Proxies, ihre Credentialreferenzen und die zugeordneten Subsysteme. Die Procedure führt keine Agentaktion aus, erteilt keine Rechte und ändert keine Konfiguration. Sie benötigt `sysadmin`-Sicht für die Agenttabellen in `msdb`. Ein fehlendes Leserecht erzeugt `DENIED_PERMISSION`; eine leere Proxyliste wird nur bei erfolgreicher vollständiger Quellenlesung als leer bewertet.

## Eine Zeile bedeutet

Eine Zeile in `proxies` beschreibt genau einen beim Aufruf gelesenen SQL-Agent-Proxy. Eine Zeile in `proxySubsystems` beschreibt eine gespeicherte Zuordnung dieses Proxies zu einem Subsystem. `ProxyId` verbindet beide Mengen; ein Proxy kann mehrere Zuordnungen und auch keine besitzen.

## So lesen

Lesen Sie Status und Quellenstatus vor den Datenzeilen. Vergleichen Sie danach `totalProxyCount`, `returnedProxyCount` und `isTruncated`; erst dann lassen sich Proxy- und Subsystemzeilen sinnvoll interpretieren. Der Credentialstatus beschreibt nur die Sicht auf einen Namen.

## Warum kann das problematisch sein?

Eine deaktivierte Proxyzeile kann einen erwarteten Agentpfad beeinträchtigen. Eine gespeicherte Credentialreferenz ohne sichtbaren Namensmatch benötigt Prüfung durch einen berechtigten Administrator. Beide Beobachtungen sind Prüfhinweise und keine Diagnose eines fehlgeschlagenen Jobsteps.

## Wann ist es kein Problem?

Eine Instanz ohne konfigurierte Proxies kann ausschließlich Transact-SQL-Jobsteps oder andere Betriebswege nutzen. Ein deaktivierter Proxy kann absichtlich stillgelegt sein. Ohne erwarteten Job- und Sicherheitskontext entsteht aus diesen Katalogwerten kein Fehlerurteil.

## Technische Vertiefung

### Leitfrage

Welche SQL-Agent-Proxies, Credentialreferenzen und Subsystemzuordnungen sind im privilegierten Katalogsnapshot sichtbar?

### Technischer Hintergrund

Die Agenttabellen in `msdb` erfordern `sysadmin`. Die Procedure prüft diese Voraussetzung vor dem Katalogzugriff und erteilt keine Rechte. Die Credentialquelle liefert nur `credential_id` und `name`; `credential_identity` und Secrets werden nicht abgefragt.

### Datenkette

`msdb.dbo.sysproxies` liefert die ausgewählten Proxyzeilen und gespeicherte Credential-IDs. `sys.credentials` wird ausschließlich über diese IDs nach Namen verknüpft. `msdb.dbo.sysproxysubsystem` liefert Zuordnungsschlüssel; `msdb.dbo.syssubsystems` ergänzt den Subsystemnamen. Die zweite Menge enthält nur Zuordnungen der ausgewählten Proxies.

### Source Select

```sql
SELECT [p].[proxy_id], [p].[name], [p].[enabled], [p].[credential_id]
FROM [msdb].[dbo].[sysproxies] AS [p] WITH (NOLOCK)
ORDER BY [p].[name] COLLATE SQL_Latin1_General_CP1_CS_AS, [p].[proxy_id];
```

**Wichtig für die Eigenlast:** Die Proxyzählung und Auswahl lesen die Katalogquelle unabhängig von der ausgegebenen Zeilengrenze. `@MaxZeilen` begrenzt Proxy- und Subsystemergebnisse, keine garantierte Gesamtlaufzeit oder Quelllesemenge. `LOCK_TIMEOUT 0` lässt Sperrkonflikte unmittelbar als Quellenfehler sichtbar werden.

### Zeit- und Scope-Modell

Die Quelle ist ein aktueller, nicht atomarer Katalogsnapshot ohne Historienfenster. Zwischen Zählung und Auswahl sowie zwischen Agent- und Credentialquelle können Änderungen auftreten. `WITH (NOLOCK)` erlaubt inkonsistente Beobachtungen; ein Ergebnis ist kein transaktionskonsistenter Sicherheitsnachweis.

### Bewertung und Gegenprobe

`AVAILABLE` bezeichnet vollständig gelesene Quellen, `AVAILABLE_LIMITED` eine unvollständige Lesung und `DENIED_PERMISSION` fehlende Agent-Katalogsicht. Lesen Sie `USP_AgentJobs` für Jobstatus und History separat. Ob ein Proxy tatsächlich läuft, benötigt einen geeigneten betrieblichen Nachweis außerhalb dieser Inventur.

### Typische Fehlinterpretation

`CredentialReferencePresent=1` belegt nur eine gespeicherte ID, nicht die Verwendbarkeit des Credentials. Eine leere Datenmenge bei `IsPartial=1` ist kein Abwesenheitsnachweis.

### Folgeanalyse

Der [Infrastrukturleitfaden](../07_Infrastructure.md) ordnet die Inventur in den Agentpfad ein. Die [Technische Detailbeschreibung](../07_Infrastructure.md) behandelt die Leserichtung; das [Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) erklärt Status und Aussagegrenzen im Framework.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentProxyInventory]
    @MaxZeilen = 100,
    @ResultSetArt = 'RAW';
```

Die Ausgabe ist ein nicht atomarer Katalogsnapshot. `ProxyId` und `ProxyName` identifizieren den sichtbaren Proxy, `IsEnabled` ist der gespeicherte Aktivierungswert. `CredentialId` und `CredentialReferencePresent` zeigen nur die gespeicherte Referenz. `CredentialName` wird ausschließlich aus `sys.credentials.name` gelesen. `CredentialCatalogStatus` ist `VISIBLE` bei sichtbarem Namensmatch, `NOT_VISIBLE_OR_MISSING` ohne sichtbaren Match oder `NOT_CHECKED` bei nicht gelesener Credentialquelle. Diese Werte belegen weder einen nutzbaren Credential noch wirksame Betriebssystemrechte.

`proxySubsystems` ordnet `ProxyId` und `SubsystemId` einander zu. `SubsystemName` kann NULL sein, wenn zum gespeicherten Subsystemschlüssel keine lesbare Zeile gefunden wurde. Die Zuordnung beschreibt den Katalog und beweist keine erfolgreiche Jobstepausführung. Die Procedure liest weder Credentialidentität oder Secrets noch SIDs, Loginzuordnungen, Befehle, Dateipfade, Jobverlauf oder effektive Privilegien.

## Parameter

| Parameter | Typ, Eingabe und Default | Verhalten |
|---|---|---|
| `@MaxZeilen` | `int`; Default: `1000`. Ganze Werte von 1 bis 2147483647, `0` oder `NULL`. | Positive Werte begrenzen Proxies nach Name und ID; Subsystemzeilen gehören nur zu diesen Proxies. `0` und `NULL` sind unbegrenzt. Negative Werte ergeben `INVALID_PARAMETER`. Das Limit begrenzt die Ausgabe, nicht die gesamte Kataloglesearbeit. |
| `@ResultSetArt` | `varchar(16)`; Default: `'CONSOLE'`. Werte `CONSOLE`, `RAW`, `TABLE`, `NONE`; äußere Leerzeichen und Schreibweise werden normalisiert. | `CONSOLE` liefert beschriftete Proxyzeilen; `RAW` liefert Modulstatus, Proxies und Proxy-Subsysteme; `TABLE` schreibt nur Proxies in ein lokales Ziel; `NONE` liefert keine fachlichen Resultsets. `NULL`, leerer Text und andere Werte ergeben `INVALID_PARAMETER`. |
| `@ResultTablesJson` | `nvarchar(max)`; Default: `NULL`. Für `TABLE` exakt `{"proxies":"#ExampleTarget"}`. | Der Schlüssel ist case-sensitiv; der Wert ist ein lokaler #Temp-Tabellenname. Die Tabelle muss vorhanden, leer und mit einer Seed-Spalte vorbereitet sein. Der Framework-Preflight prüft weitere Namen- und Schemagrenzen. Außerhalb `TABLE` sind `NULL`, leerer Text oder Leerzeichen erlaubt; sonst Fehler 51011. Ein fehlendes oder ungültiges `TABLE`-Mapping erzeugt ebenfalls 51011, auch bei `@Hilfe=1`. |
| `@JsonErzeugen` | `bit`; Default: `0`. | Genau `1` erzeugt zusätzlich JSON; `0` und `NULL` deaktivieren es. Andere Eingaben werden beim SQL-Binding zu `bit` konvertiert oder vor Prozedurstart abgewiesen. |
| `@Json` | `nvarchar(max) OUTPUT`; Default: `NULL`. | Eine `nvarchar(max)`-Variable mit `OUTPUT` binden. Der Wert wird zunächst auf NULL gesetzt und bei aktivierter JSON-Ausgabe nach dem Analysepfad gefüllt. Bei Hilfe bleibt er NULL; ohne OUTPUT-Bindung wird nichts zurückgegeben. |
| `@Hilfe` | `bit`; Default: `0`. | Genau `1` druckt Hilfe und kehrt vor privilegiertem Quellenzugriff zurück; `0` und `NULL` analysieren. Andere Eingaben durchlaufen zuerst das SQL-`bit`-Binding. Frühe TABLE-Preflightfehler bleiben möglich. |
| `@StatusCodeOut` | `varchar(40) OUTPUT`; Default: `NULL`. | Liefert `AVAILABLE`, `AVAILABLE_LIMITED`, `DENIED_PERMISSION` oder `INVALID_PARAMETER`. `AVAILABLE` gilt nur nach vollständiger Quellenlesung. Mit `OUTPUT` binden; bei Hilfe oder frühem Fehler bleibt die Eingangsvariable unverändert. |
| `@IsPartialOut` | `bit OUTPUT`; Default: `NULL`. | `0` für vollständig gelesene Quellen, `1` bei nicht vollständiger Lesung oder ungültigem Parameter. Ein positives Zeilenlimit allein setzt das Flag nicht; `isTruncated` beschreibt die tatsächliche Kürzung. Mit `OUTPUT` binden; bei Hilfe oder frühem Fehler bleibt die Eingangsvariable unverändert. |
| `@ErrorNumberOut` | `int OUTPUT`; Default: `NULL`. | Erste abgefangene SQL-Fehlernummer oder NULL. Die Rollen-Vorprüfung und ungültige Parameter erzeugen keine SQL-Fehlernummer. Mit `OUTPUT` binden; bei Hilfe oder frühem Fehler bleibt die Eingangsvariable unverändert. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT`; Default: `NULL`. | Generischer Quellen- oder Parameterhinweis ohne ursprünglichen SQL-Fehlertext, sonst NULL. Mit `OUTPUT` binden; bei Hilfe oder frühem Fehler bleibt die Eingangsvariable unverändert. |

`RAW` liefert drei Resultsets in dieser Reihenfolge: Modulstatus, `proxies`, `proxySubsystems`. `CONSOLE` und `TABLE` liefern nur `proxies`; der Modulstatus bleibt über die OUTPUT-Parameter zugänglich. `NONE` unterdrückt fachliche Resultsets. Optionales JSON enthält `meta`, `proxies` und `proxySubsystems`. `meta` enthält Quellenstatus je Gruppe, angeforderte Zeilengrenze, Proxyzählwerte und `isTruncated`. Wenn die Proxyquelle fehlschlägt, sind beide Proxyzählwerte NULL. Leere Arrays mit einem Fehlerstatus sind kein Nachweis, dass keine Proxies existieren. `AVAILABLE_LIMITED` und `isPartial=1` begrenzen alle Vollständigkeitsbehauptungen.

```sql
DECLARE @ProxyJson nvarchar(max);
EXEC [monitor].[USP_AgentProxyInventory]
    @ResultSetArt = 'NONE',
    @JsonErzeugen = 1,
    @Json = @ProxyJson OUTPUT;
SELECT @ProxyJson AS [Json];
```

Für `TABLE` wird nur das Proxyschema exportiert:

```sql
CREATE TABLE #ProxyExample ([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_AgentProxyInventory]
        @ResultSetArt = 'TABLE',
        @ResultTablesJson = N'{"proxies":"#ProxyExample"}';
    SELECT * FROM #ProxyExample;
    DROP TABLE #ProxyExample;
END TRY
BEGIN CATCH
    DROP TABLE #ProxyExample;
    THROW;
END CATCH;
```

## Aussagegrenze und Gegenprobe

`msdb.dbo.sysproxies`, `msdb.dbo.sysproxysubsystem` und `msdb.dbo.syssubsystems` erfordern laut Microsoft eine `sysadmin`-Mitgliedschaft; `sys.credentials` erfordert ausreichende Metadatensicht. Die Quelle kann sich zwischen Zählung und Auswahl ändern. Der Katalogpfad verwendet `LOCK_TIMEOUT 0` und `WITH (NOLOCK)`; eine sofortige Sperrabweichung wird als Quellenfehler gemeldet. Die Abfrage kann inkonsistente Momentaufnahmen liefern. Die resultierende Menge darf deshalb nicht als transaktionskonsistenter Sicherheitsnachweis verwendet werden. Für tatsächliche Jobstepnutzung und Betriebszustand sind die Agent- und Jobprozeduren separat zu lesen. Eine Ausführung eines Proxies auf Windows oder Linux wird durch dieses Inventar nicht geprüft.

Die Katalogspalten und Berechtigungen sind in der [Microsoft-Referenz zu sysproxies](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysproxies-transact-sql?view=sql-server-ver17), [sysproxysubsystem](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysproxysubsystem-transact-sql?view=sql-server-ver17), [syssubsystems](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-syssubsystems-transact-sql) und [sys.credentials](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-credentials-transact-sql?view=sql-server-ver17) beschrieben.
