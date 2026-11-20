---
skill_format_version: "1.0.0"
name: "monitor.USP_ReplicationStatus"
schema_name: "monitor"
object_name: "USP_ReplicationStatus"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler."
source_path: "Code/07_Infrastructure/070_USP_ReplicationStatus.sql"
---

# monitor.USP_ReplicationStatus

## Zweck und Einsatz

Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.databases, distribution.dbo.MSpublications/MSsubscriptions/MSdistribution_agents/MSrepl_errors, msdb Agent-Metadaten

Nur lesender Zugriff auf die genannten Systemobjekte. Das Framework vergibt keine Rechte und ändert keine Konfiguration.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MitDistributionDetails | bit | nein | 0 |
| @MaxZeilen | int | nein | 5000 |
| @HighImpactConfirmed | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@MitDistributionDetails:** @MitDistributionDetails bit; Default: 0. Default 0. 0 liest nur sichtbare Replikationsrollen; 1 aktiviert Details aus der online erkannten lokalen Distribution-Datenbank (Publikationen, Subscriptions samt letzter Agent-Historyzeile, Fehler). Fehlt sie, entsteht ein Partialstatus bzw. ohne Basiszeilen UNAVAILABLE_FEATURE. NULL wird nicht geprüft und aktiviert den Pfad nicht. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int; Default: 5000. Default 5000 je Datenbank-, Publikations-, Subscription- und Fehlerresultset getrennt, ohne gemeinsames Gesamtbudget. Positive Werte begrenzen je Menge; 0 oder NULL bedeutet unbegrenzt. Negative Werte setzen INVALID_PARAMETER/Partial und verhindern die Facherhebung, sofern kein früherer Gate-Status den Status bereits geändert hat. Bei @Hilfe=1 wird der Wert nicht validiert, weil die Hilfe vorher zurückkehrt. Die Grenze verhindert nicht die Latest-History-Auflösung je Subscription. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Nur bei MitDistributionDetails=1 prüft die Procedure die Klasse ENTERPRISE_TOPOLOGY_DEEP. Der gebundene Wert 0 ergibt HIGH_IMPACT_CONFIRMATION_REQUIRED. Nach Bestätigung mit 1 kann die aktuelle Zugriffspolicy DENIED_GROUP ergeben. Der Detailpfad setzt Bestätigung und aktuelle Berechtigung voraus. NULL ergibt bei aktiviertem Detailpfad INVALID_PARAMETER. Bei deaktiviertem Detailpfad wird der Wert nicht geprüft. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Default CONSOLE. Außen getrimmt und großgeschrieben; erlaubt sind CONSOLE (nur Datenbankrollenansicht über Console-Helper), RAW (Modulstatus plus vier Fachergebnissets), TABLE (nur databases in Zieltemp-Tabelle) und NONE (keine Resultsets). NULL/Leerwert/anderer Wert ergibt INVALID_PARAMETER. CONSOLE und TABLE unterdrücken den normalen Status-/RAW-Pfad. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Default NULL. Nur mit TABLE zulässig; sonst wird nichtleeres JSON mit Fehler 51011 abgewiesen. Erwartet ein Objekt mit einzigem Resultnamen databases und Ziel als Wert: bestehende leere lokale #Temp-Tabelle, keine ##Temp, kein #Monitor-Präfix, maximal 116 Zeichen und genau eine Seed-Spalte. NULL/leeres JSON ist ungültig. Der Preflight läuft vor HELP und Fachdatenzugriff. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Default 0. 1 erzeugt zusätzlich JSON in Json mit meta, databases, publications, subscriptions und errors; 0 nicht. JSON-Erzeugung ist unabhängig von ResultSetArt. NULL aktiviert den IF-Zweig nicht. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT, Default NULL. Wird am Anfang auf NULL gesetzt und bei JsonErzeugen=1 mit dem JSON-Objekt aus meta und vier Ergebnisarrays gebunden. Andernfalls bleibt NULL. Der Aufrufer bindet eine nvarchar(max)-OUTPUT-Variable. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Default 1. Bei 1 wird eine behandelte Catch-Fehlermeldung mit Severity 10 ausgegeben; 0 unterdrückt sie. NULL wirkt nicht wie 1. Steuert keine Resultsets. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit; Default: 0. Default 0. 1 druckt kurze Hilfe und kehrt zurück, 0 fährt fort; NULL wirkt wie 0. TABLE-Kombinationsprüfung und Preflight laufen vor der Hilfeprüfung. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

1. Modulstatus. 2. Server-/Datenbankrollen. 3. Publikationen. 4. Subscriptions. 5. Agentfehler.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| databases | 1 | 1 | [DatabaseName] sysname,[IsPublished] bit,[IsSubscribed] bit,[IsMergePublished] bit,[IsDistributor] bit |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_ReplicationStatus

Beispiel 1: EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;

Beispiel 2: EXEC [monitor].[USP_ReplicationStatus] @MitDistributionDetails=0, @MaxZeilen=100, @ResultSetArt='RAW';

Beispiel 3: DECLARE @ReplicationJson nvarchar(max); EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ReplicationJson OUTPUT; SELECT @ReplicationJson AS [Json];

Beispiel 4: CREATE TABLE #ReplicationStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#ReplicationStatus_HelpExample"}'; SELECT * FROM #ReplicationStatus_HelpExample; DROP TABLE #ReplicationStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #ReplicationStatus_HelpExample; THROW; END CATCH;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ReplicationStatus
Version      : 1.1.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Inventarisiert sichtbare Replication-Rollen, Publikationen, Subscriptions und Agentfehler.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.databases, distribution.dbo.MSpublications/MSsubscriptions/MSdistribution_agents/MSrepl_errors, msdb Agent-Metadaten
Parameter    : @MitDistributionDetails, @MaxZeilen, @HighImpactConfirmed,
               @ResultSetArt, @ResultTablesJson, @JsonErzeugen, @Json OUTPUT,
               @PrintMeldungen, @Hilfe
Resultsets   : 1. Modulstatus. 2. Server-/Datenbankrollen. 3. Publikationen. 4. Subscriptions. 5. Agentfehler.
Berechtigung : Nur lesender Zugriff auf die genannten Systemobjekte. Das
               Framework vergibt keine Rechte und ändert keine Konfiguration.
Eigenlast    : Mittel; optionale Distribution-DB-Auswertung.
Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
Partial      : Fehlende Features, Objekte oder Rechte werden strukturiert als
               Partial Result behandelt; andere Module bleiben ausführbar.
Änderungen   : 1.1.0 - Negative @MaxZeilen-Werte werden vor Rechte- und
               Datenzugriffen strukturiert abgewiesen.
               1.0.0 - Erstfassung Phase 6.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ReplicationStatus
Beispiel 1: EXEC [monitor].[USP_ReplicationStatus] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_ReplicationStatus] @MitDistributionDetails=0, @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 3: DECLARE @ReplicationJson nvarchar(max); EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ReplicationJson OUTPUT; SELECT @ReplicationJson AS [Json];
Beispiel 4: CREATE TABLE #ReplicationStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ReplicationStatus] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#ReplicationStatus_HelpExample"}'; SELECT * FROM #ReplicationStatus_HelpExample; DROP TABLE #ReplicationStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #ReplicationStatus_HelpExample; THROW; END CATCH;
```

