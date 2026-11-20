---
skill_format_version: "1.0.0"
name: "monitor.USP_AgentStatus"
schema_name: "monitor"
object_name: "USP_AgentStatus"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar."
source_path: "Code/07_Infrastructure/010_USP_AgentStatus.sql"
---

# monitor.USP_AgentStatus

## Zweck und Einsatz

Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.dm_server_services, msdb.dbo.syssessions, msdb.dbo.sysjobs

Nur lesender Zugriff. Das Framework vergibt keine Rechte.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. NULL wird zu leerem Text; äußere Leerzeichen werden entfernt und der Vergleich erfolgt ohne Beachtung der Groß-/Kleinschreibung. CONSOLE liefert eine beschriftete Console-Ausgabe, RAW den Modulstatus und die Rohzeile, TABLE exportiert agentStatus in das zugeordnete Ziel, NONE unterdrückt Resultsets. CONSOLE und TABLE unterdrücken zuerst direkte Resultsets und rufen anschließend ihren Ausgabeadapter auf. Andere Werte werden nach dem Hilferücksprung als INVALID_PARAMETER gemeldet. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL, leerer Text und nur aus Leerzeichen bestehender Text werden außerhalb von TABLE ignoriert. Ein nichtleerer Wert ist nur mit ResultSetArt=TABLE zulässig; andernfalls wird im normalen Pfad Fehler 51011 ausgelöst; Hilfe kehrt vorher zurück. TABLE erwartet die JSON-Objektform {"agentStatus":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel, ein String mit dem lokalen Zielnamen als Wert und keine weiteren Eigenschaften. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##-Tabellen, #Monitor-Namen und Namen über 116 Zeichen sind unzulässig. Eine fehlende oder fehlerhafte Zuordnung sowie ein ungeeignetes Ziel lösen beim Preflight des normalen Pfads Fehler 51011 aus; Hilfe kehrt vorher zurück. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 0 oder NULL deaktiviert JSON; bei 1 wird @Json OUTPUT mit meta und agentStatus einschließlich NULL-Werten und einem leeren Array befüllt. SQL Server konvertiert das Argument vor Eintritt in den Prozedurcode zu bit: 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Die Procedure setzt sie zu Beginn auf NULL und befüllt sie nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Bei 1 wird nach einem abgefangenen Lesefehler eine Meldung mit Severity 10 und NOWAIT ausgegeben; 0 und NULL unterdrücken sie. SQL Server konvertiert das Argument vor Eintritt zu bit; Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. 0 führt die normale Analyse aus. Bei 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt vor der Agentdatensammlung zurück; sie startet, stoppt oder konfiguriert den Dienst nicht. NULL wirkt wie 0. SQL Server konvertiert das Argument vor Eintritt zu bit. Die Prüfung der ResultTables-Kombination und der TABLE-Zieltabellen-Preflight laufen nur im normalen Pfad nach dem Hilfezweig und können dort Fehler 51011 auslösen. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

RAW: Modulstatus und Agentstatus. CONSOLE/TABLE: Agentstatus.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| agentStatus | 1 | 1 | [ServiceName] nvarchar(256) NULL , [StartupTypeDesc] nvarchar(60) NULL , [StatusDesc] nvarchar(60) NULL , [ProcessId] int NULL , [LastStartupTime] datetime2(3) NULL , [AgentSessionId] int NULL , [JobCount] int NULL , [EnabledJobCount] int NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_AgentStatus] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_AgentStatus

Ermittelt den sichtbaren Agentdienstsnapshot, den letzten in msdb sichtbaren Agentstart und aggregierte Jobzahlen.

Die Hilfe wird mit PRINT ausgegeben. Prüfung der ResultTables-Kombination und TABLE-Zielpreflight laufen nur im normalen Pfad danach; der Hilferücksprung erfolgt vor dem Zugriff auf Agentdaten.

Beispiel 1: EXEC [monitor].[USP_AgentStatus] @Hilfe=1;

Beispiel 2: EXEC [monitor].[USP_AgentStatus] @ResultSetArt='RAW', @PrintMeldungen=0;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_AgentStatus
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Die Procedure ermittelt SQL-Server-Agent-Dienststatus, Agent-Startzeit und Basisinventar.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_server_services, msdb.dbo.syssessions, msdb.dbo.sysjobs
Parameter    : @ResultSetArt, @ResultTablesJson, @JsonErzeugen, @Json OUTPUT,
               @PrintMeldungen, @Hilfe
Resultsets   : RAW: Modulstatus und Agentstatus. CONSOLE/TABLE: Agentstatus.
               NONE: keine Resultsets.
JSON         : meta, agentStatus.
Berechtigung : Nur lesender Zugriff. Das Framework vergibt keine Rechte.
Eigenlast    : Gering.
Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
Änderungen   : 2.0.0 - Einheitlicher RAW/CONSOLE/NONE- und JSON-Vertrag.
               1.0.0 - Erstfassung Phase 6.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_AgentStatus
Ermittelt den sichtbaren Agentdienstsnapshot, den letzten in msdb sichtbaren Agentstart und aggregierte Jobzahlen.
Die Hilfe wird mit PRINT ausgegeben. Prüfung der ResultTables-Kombination und TABLE-Zielpreflight laufen nur im normalen Pfad danach; der Hilferücksprung erfolgt vor dem Zugriff auf Agentdaten.
Beispiel 1: EXEC [monitor].[USP_AgentStatus] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_AgentStatus] @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 3: DECLARE @AgentStatusJson nvarchar(max); EXEC [monitor].[USP_AgentStatus] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgentStatusJson OUTPUT, @PrintMeldungen=0; SELECT @AgentStatusJson AS [Json];
Beispiel 4: CREATE TABLE #AgentStatus_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentStatus] @ResultSetArt='TABLE', @ResultTablesJson=N'{"agentStatus":"#AgentStatus_HelpExample"}', @PrintMeldungen=0; SELECT * FROM #AgentStatus_HelpExample; DROP TABLE #AgentStatus_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentStatus_HelpExample; THROW; END CATCH;
```

