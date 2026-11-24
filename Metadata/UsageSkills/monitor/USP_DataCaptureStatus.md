---
skill_format_version: "1.0.0"
name: "monitor.USP_DataCaptureStatus"
schema_name: "monitor"
object_name: "USP_DataCaptureStatus"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert CDC und Change Tracking für eine bracket-aware Datenbankliste oder alle zulässigen Datenbanken."
source_path: "Code/07_Infrastructure/080_USP_DataCaptureStatus.sql"
---

# monitor.USP_DataCaptureStatus

## Zweck und Einsatz

Inventarisiert CDC und Change Tracking für eine bracket-aware Datenbankliste oder alle zulässigen Datenbanken.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

master.sys.databases, sys.change_tracking_databases, database-lokale sys.tables/sys.schemas/sys.change_tracking_tables/cdc.change_tables sowie msdb.dbo.cdc_jobs, msdb.dbo.sysjobs und msdb.dbo.sysjobhistory. CDC-Jobs werden über registrierte Datenbank- und Job-IDs zugeordnet. Ist diese Quelle bei aktivem CDC nicht lesbar, bleibt der Datenbankstatus erhalten und CDC_JOBS kennzeichnet die Teilausgabe.

Cross-Database wird über CROSS_DATABASE_DEEP geprüft.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MaxZeilen | int | nein | 10000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Default NULL. NULL oder Leer-/Whitespace-Eingabe bedeutet keine Einschränkung und alle zulässigen sichtbaren Online-Datenbanken. Nichtleere Pipe-Liste einteiliger SQL-Namen; | trennt außerhalb eckiger Klammern, ]] maskiert eine schließende Klammer; Elementränder werden getrimmt. Leere Segmente, ungültige Klammerung, Rohsegment über 4000 UTF-16-Codeeinheiten, Multipartname oder Name über 128 Zeichen sind INVALID_PARAMETER; Duplikate ebenfalls. Gültige, aber fehlende/offline/unzugängliche Namen werden Warnungen/Partial. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Default 0. 0 schließt master, tempdb, model und msdb aus; explizite Anforderung erzeugt SYSTEM_DATABASE_EXCLUDED. 1 lässt System-IDs bis 4 zu. NULL oder Werte außer 0/1 sind INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Default NULL. NULL heißt kein Pattern. Eingabe außen getrimmt; optionale Präfixe ohne Groß-/Kleinschreibung: like: (LIKE), regex: (case-sensitive Regex), regexi: (case-insensitive Regex); ohne Präfix gilt LIKE. Präfix wird entfernt, Rest nicht erneut getrimmt; leerer Inhalt ist ungültig. Exakte Liste und Pattern sind exklusiv. LIKE ist case-sensitive. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Der Kandidatenhelfer prüft HA_DR_CURRENT. Diese Klasse verlangt keine High-Impact-Bestätigung. 0 genügt für das Bestätigungsbit. Die aktuelle Zugriffspolicy wird weiterhin geprüft und kann DENIED_GROUP ergeben. Auch bei mehreren Datenbanken erfolgt kein zusätzlicher CROSS_DATABASE_DEEP-Check. NULL ergibt INVALID_PARAMETER. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int; Default: 10000. Default 10000. NULL/0 unbegrenzt; negativ INVALID_PARAMETER, bevor Datenbankauswahl und Facherhebung beginnen (ein TABLE-Preflight kann vorher bereits erfolgt sein). Positive Grenze gilt global getrennt für databases, CDC-Tabellen, Change-Tracking-Tabellen und Jobs, nicht als Gesamtbudget. Auswahl wird nicht vorab begrenzt; lokal höchstens N+1 je Pfad pro Datenbank, danach globale TOP-N. Warnings bleiben ungekürzt. Datenbankausgabe nach DatabaseName sortiert. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Default CONSOLE. Außen getrimmt und großgeschrieben; erlaubt sind CONSOLE, RAW, TABLE, NONE. NULL, Leerwert und andere Werte ungültig. RAW liefert Modulstatus, databases, CDC-Tabellen, CT-Tabellen, Jobs und Warnings. CONSOLE wird intern vor der Ausgabe auf NONE normalisiert; der erreichbare Console-Helper gibt anschließend ausschließlich die databases-Ansicht aus, ohne separaten Modulstatus oder Warnings. TABLE schreibt nur databases; NONE keine normalen Resultsets. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Default NULL. Nur TABLE zulässig; sonst wird nichtleeres JSON mit 51011 abgewiesen. Einziges Resultat databases. Erwartet JSON-Objekt mit Resultnamen und Zielwert: bestehende leere lokale #Temp-Tabelle, keine ##Temp, kein #Monitor-Präfix, höchstens 116 Zeichen, genau eine Seed-Spalte und eindeutiger Name. Fehlende/ungültige Zuordnung wirft. Preflight vor HELP und Datenbankauswahl. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Default 0. 1 erzeugt zusätzlich unabhängig von ResultSetArt JSON mit meta, databases, cdcTables, changeTrackingTables, cdcJobs und warnings; 0 nicht. Warnungen bleiben ungekürzt. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT, Default NULL. Anfangs auf NULL gesetzt; bei JsonErzeugen=1 wird JSON mit Status/Partialität und fünf Arrays an gebundene nvarchar(max)-OUTPUT-Variable zurückgegeben. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Default 1. Bei Status ungleich AVAILABLE zusätzliche Severity-10-Warnung; 0 unterdrückt sie. NULL wirkt nicht wie 1. Status-/Warning-Resultsets bleiben bestehen. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit; Default: 0. Default 0. 1 druckt kurze Eingabe-, Auswahl- und Ausgabehilfe und kehrt zurück; NULL wirkt wie 0. ResultTablesJson-Kombinationsprüfung und TABLE-Preflight laufen vor HELP. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

RAW/CONSOLE/NONE; JSON mit meta, databases, cdcTables, changeTrackingTables, cdcJobs und warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| databases | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StateDesc] nvarchar(60) NULL , [IsCdcEnabled] bit NULL , [IsChangeTrackingEnabled] bit NULL , [RetentionPeriod] bigint NULL , [RetentionPeriodUnitsDesc] nvarchar(60) NULL , [IsAutoCleanupOn] bit NULL , [CurrentCtVersion] bigint NULL , [StatusCode] varchar(40) NOT NULL , [ErrorMessage] nvarchar(2048) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DataCaptureStatus] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_DataCaptureStatus

Beispiel 1: EXEC [monitor].[USP_DataCaptureStatus] @Hilfe=1;

Beispiel 2: EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='RAW';

Beispiel 3: DECLARE @CaptureJson nvarchar(max); EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@CaptureJson OUTPUT; SELECT @CaptureJson AS [Json];

Beispiel 4: CREATE TABLE #DataCaptureStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#DataCaptureStatus_HelpExample"}'; SELECT * FROM #DataCaptureStatus_HelpExample; DROP TABLE #DataCaptureStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #DataCaptureStatus_HelpExample; THROW; END CATCH;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_DataCaptureStatus
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Inventarisiert CDC und Change Tracking für eine bracket-aware
               Datenbankliste oder alle zulässigen Datenbanken.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : master.sys.databases, sys.change_tracking_databases,
               database-lokale sys.tables/sys.schemas/
               sys.change_tracking_tables/cdc.change_tables, msdb CDC-Jobs.
Parameter    : @DatabaseNames, @DatabaseNamePattern,
               @SystemdatenbankenEinbeziehen, @HighImpactConfirmed,
               @MaxZeilen, @ResultSetArt, @ResultTablesJson,
               @JsonErzeugen, @Json OUTPUT, @PrintMeldungen, @Hilfe.
Semantik     : @DatabaseNames=N'[Db1]|[Db2]'; NULL/leer/Whitespace=alle zulässigen
               Datenbanken. Exakte Liste und Pattern sind exklusiv. Die
               Datenbankauswahl wird nicht vorab begrenzt.
Ausgabe      : RAW/CONSOLE/NONE; JSON mit meta, databases, cdcTables,
               changeTrackingTables, cdcJobs und warnings.
Berechtigung : Cross-Database wird über CROSS_DATABASE_DEEP geprüft.
Eigenlast    : Mittel; lokale Kandidaten werden je Datenbank auf N+1 begrenzt,
               anschließend erfolgt ein globales TOP je fachlichem Resultset.
Locking      : LOCK_TIMEOUT 0; Systemkataloge READUNCOMMITTED.
Änderungen   : 2.0.0 - @AlleDatenbanken entfernt; Listen-/Patternvertrag,
                         globale Mengenbegrenzung und Ausgabevertrag ergänzt.
               1.0.0 - Erstfassung Phase 6.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DataCaptureStatus
Beispiel 1: EXEC [monitor].[USP_DataCaptureStatus] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 3: DECLARE @CaptureJson nvarchar(max); EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@CaptureJson OUTPUT; SELECT @CaptureJson AS [Json];
Beispiel 4: CREATE TABLE #DataCaptureStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_DataCaptureStatus] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"databases":"#DataCaptureStatus_HelpExample"}'; SELECT * FROM #DataCaptureStatus_HelpExample; DROP TABLE #DataCaptureStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #DataCaptureStatus_HelpExample; THROW; END CATCH;
```

