---
skill_format_version: "1.0.0"
name: "monitor.USP_AgentJobs"
schema_name: "monitor"
object_name: "USP_AgentJobs"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler, Schedules und Owner."
source_path: "Code/07_Infrastructure/020_USP_AgentJobs.sql"
---

# monitor.USP_AgentJobs

## Zweck und Einsatz

Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler, Schedules und Owner.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_AgentJobs] im vorgesehenen Datenbankkontext. Die Procedure liest Job-, Step-, Schedule- und Historienkataloge in `msdb` unter der SQL-Agent-Sicht des aktuellen Callers; sie startet weder Job noch Dienst. Eingeschränkte msdb-Sicht ist keine vollständige Jobinventur.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @JobNames | nvarchar(max) | nein | NULL |
| @JobNamePattern | nvarchar(4000) | nein | NULL |
| @NurProblematisch | bit | nein | 0 |
| @LongRunningMinutes | int | nein | 60 |
| @MaxZeilen | int | nein | 2000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@JobNames:** @JobNames nvarchar(max)=NULL; Default: NULL. NULL deaktiviert den exakten Namensfilter. Andernfalls wird eine bracket-aware Pipe-Liste einteiliger SQL-Namen erwartet: | trennt außerhalb von eckigen Klammern; innerhalb gehört das Pipe-Zeichen zum Namen und ]] maskiert eine schließende Klammer. Äußere Segmentleerzeichen werden entfernt. Gültige Duplikate werden nach SQL_Latin1_General_CP1_CS_AS zusammengeführt; Namen mit abweichender Groß-/Kleinschreibung bleiben getrennt. Jedes Element muss als einteiliger SQL-Name mit höchstens 128 Zeichen auswertbar sein. Leere oder ungültige Elemente und rohe Segmente über 4000 UTF-16-Codeeinheiten sind ungültig; die Existenz im Katalog wird nicht geprüft. Eine leere Liste ist ungültig. @JobNames und ein nicht-NULL @JobNamePattern dürfen nicht zusammen verwendet werden. Ungültige Listen werden nach der Hilfe als INVALID_PARAMETER gemeldet, ohne Parser-THROW. Bei ausgelassenem Argument gilt der angegebene Default.

**@JobNamePattern:** @JobNamePattern nvarchar(4000)=NULL; Default: NULL. NULL deaktiviert den Patternfilter; leerer oder nur aus Leerzeichen bestehender Wert ist ungültig. Äußere Leerzeichen werden entfernt. Ohne Präfix gilt LIKE. Case-insensitive Präfixe: like: verwendet SQL-LIKE, regex: reguläre Ausdrücke mit Flag c, regexi: reguläre Ausdrücke mit Flag i. Der verbleibende Inhalt wird nicht erneut getrimmt; ein Präfix ohne Inhalt ist ungültig. Regex erfordert SQL Server 2025/ProductMajorVersion 17 oder neuer und Compatibility Level 170 der Installationsdatenbank; sonst wird UNAVAILABLE_FEATURE gemeldet. Die Regexsyntax wird nicht vorab geprüft; Fehler bei REGEXP_LIKE werden abgefangen. @JobNames und Pattern sind gegenseitig exklusiv. Das Parsing erfolgt vor der Hilfe, die übrige Validierung danach. Bei ausgelassenem Argument gilt der angegebene Default.

**@NurProblematisch:** @NurProblematisch bit=0; Default: 0. Bei 0 werden alle passenden Jobs ausgewählt; bei 1 werden deaktivierte, zuletzt fehlgeschlagene Jobs, Jobs ohne Schedule, ohne aktivierten Schedule sowie laufende Jobs ab dem LongRunningMinutes-Grenzwert berücksichtigt. Steps erscheinen bei 1 nur mit letztem Status FAILED, RETRY oder CANCELED. NULL ist nicht gleich 0: SQL UNKNOWN bewirkt, dass Jobs nur bei einem zutreffenden Problemprädikat erhalten bleiben; Steps nur bei einem der drei genannten Statuswerte. SQL Server konvertiert das Argument vor Eintritt zu bit; 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Bei ausgelassenem Argument gilt der angegebene Default.

**@LongRunningMinutes:** @LongRunningMinutes int=60; Default: 60. Die Laufzeitschwelle wird als ganze Zahl in Minuten übergeben; erlaubt sind 1 bis 2147483647. Werte kleiner als 1 setzen INVALID_PARAMETER. NULL passiert die Bereichsprüfung, ergibt beim Laufzeitvergleich aber UNKNOWN und erzeugt deshalb keinen LONG_RUNNING-Befund. Die aktuelle Laufzeit wird mit DATEDIFF(MINUTE, Startzeit, GETDATE()) verglichen. Bei @NurProblematisch=1 dient dieser Grenzwert auch als Filter. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=2000; Default: 2000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte setzen INVALID_PARAMETER. Positive Werte begrenzen Job- und Stepzeilen; NULL oder 0 bedeutet unbegrenzt. Bei Nicht-Regexfiltern begrenzt bereits das erste TOP der Jobabfrage auf @EffectiveMaxZeilen und sortiert laufende Jobs zuerst, danach nach JobName. Zeilen außerhalb dieses ersten Ausschnitts können durch die spätere Problemsortierung nicht wieder aufgenommen werden; diese Sortierung bevorzugt ProblemCode-Zeilen nur unter den bereits materialisierten Jobs. Im Regexmodus wird zuerst ohne diese Grenze materialisiert, dann das Regex angewendet und anschließend die Problem-/Jobnamenpriorisierung begrenzt. Steps verwenden unabhängig davon TOP(@EffectiveMaxZeilen), geordnet nach JobName und StepId. Es gibt keine explizite Kürzungskennzeichnung oder zusätzliche Kürzungsanzahl. JSON requestedMaxRows enthält den übergebenen Wert. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. NULL wird zu leerem Text; äußere Leerzeichen werden entfernt, der Vergleich erfolgt ohne Beachtung der Groß-/Kleinschreibung. CONSOLE liefert ausschließlich beschriftete Jobs, RAW den Modulstatus sowie Jobs und Steps, TABLE nur Jobs, NONE keine fachlichen Resultsets. CONSOLE und TABLE unterdrücken direkte Resultsets und verwenden anschließend ihre Ausgabeadapter. Andere Werte werden nach der Hilfe als INVALID_PARAMETER gemeldet. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. NULL, leerer Text und nur aus Leerzeichen bestehender Text werden außerhalb von TABLE ignoriert. Ein nichtleerer Wert ist nur mit ResultSetArt=TABLE zulässig; andernfalls wird vor der Hilfe Fehler 51011 ausgelöst. TABLE erwartet die JSON-Objektform {"jobs":"#ExampleTarget"}: genau dieser case-sensitive Schlüssel, ein String mit dem lokalen Zielnamen als Wert und keine weiteren Eigenschaften. Das Ziel muss eine vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte sein; globale ##-Tabellen, #Monitor-Namen und Namen über 116 Zeichen sind unzulässig. Eine fehlende oder fehlerhafte Zuordnung sowie ein ungeeignetes Ziel lösen beim Preflight vor der Hilfe Fehler 51011 aus. Exportiert werden nur Jobs, keine Steps. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 0 oder NULL deaktiviert JSON; bei 1 wird @Json OUTPUT mit meta, jobs und steps, Mengenangaben und Arrays befüllt. SQL Server konvertiert das Argument vor Eintritt zu bit; 0 ergibt 0, ein konvertierbarer Wert ungleich 0 ergibt 1. Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Die Procedure setzt sie zu Beginn auf NULL und befüllt sie nur bei @JsonErzeugen=1. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Bei 1 wird nach einem abgefangenen Sammlungsfehler eine Meldung mit Severity 10 und NOWAIT ausgegeben; 0 und NULL unterdrücken sie. SQL Server konvertiert das Argument vor Eintritt zu bit; Konvertierungsfehler treten vor der Prozedurausführung auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. 0 führt die normale Analyse aus. Bei 1 gibt die Procedure ihre Hilfe mit PRINT aus und kehrt ohne Jobdatensammlung zurück. NULL wirkt wie 0. SQL Server konvertiert das Argument vor Eintritt zu bit. Ausgabe-/TABLE-Preflight und Patternparsing erfolgen vor der Hilfe; Joblistenvalidierung, Parameter- und Regexfeatureprüfung sowie Datensammlung danach. Ein Preflightfehler kann daher auch mit @Hilfe=1 auftreten. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

RAW: Modulstatus, Jobs, Jobsteps. CONSOLE/TABLE: Jobs.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| jobs | 1 | 1 | [JobId] uniqueidentifier , [JobName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS , [Enabled] bit , [OwnerName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS , [CategoryName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS , [IsRunning] bit , [RunStart] datetime , [RunningMinutes] int , [LastRunDateTime] datetime , [LastRunStatus] int , [LastRunStatusDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS , [LastRunDurationSeconds] int , [LastMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS , [ScheduleCount] int , [EnabledScheduleCount] int , [StepCount] int , [ProblemCode] varchar(100) COLLATE SQL_Latin1_General_CP1_CS_AS |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_AgentJobs] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_AgentJobs

Analysiert sichtbare Agentjobs, letzte Gesamt- und Stepausführungen, laufende Aktivität sowie Schedule- und Owner-Metadaten.

Die Hilfe wird mit PRINT ausgegeben. Ausgabe-/TABLE-Preflight und Patternparsing liegen davor; Joblistenvalidierung, Regexfeatureprüfung und Sammlung folgen danach.

Beispiel 1: EXEC [monitor].[USP_AgentJobs] @Hilfe=1;

Beispiel 2: EXEC [monitor].[USP_AgentJobs] @JobNames=N'[ExampleJobA]|[ExampleJobB]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_AgentJobs
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Die Procedure analysiert Agent-Jobs, Laufzeitstatus, letzte Ausführung, Fehler,
               Schedules und Owner.
SQL-Version  : SQL Server 2019 oder neuer.
Filter       : @JobNames als bracket-aware Pipe-Liste oder alternativ
               @JobNamePattern mit LIKE/regex/regexi.
Resultsets   : RAW: Modulstatus, Jobs, Jobsteps. CONSOLE/TABLE: Jobs.
               NONE: keine fachlichen Resultsets.
JSON         : meta, jobs, steps.
Änderungen   : 2.0.0 - Mehrfachfilter, Patternvertrag und Ausgabeadapter.
               1.0.0 - Erstfassung Phase 6.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_AgentJobs
Analysiert sichtbare Agentjobs, letzte Gesamt- und Stepausführungen, laufende Aktivität sowie Schedule- und Owner-Metadaten.
Die Hilfe wird mit PRINT ausgegeben. Ausgabe-/TABLE-Preflight und Patternparsing liegen davor; Joblistenvalidierung, Regexfeatureprüfung und Sammlung folgen danach.
Beispiel 1: EXEC [monitor].[USP_AgentJobs] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_AgentJobs] @JobNames=N'[ExampleJobA]|[ExampleJobB]', @MaxZeilen=100, @ResultSetArt='RAW', @PrintMeldungen=0;
Beispiel 3: DECLARE @AgentJobsJson nvarchar(max); EXEC [monitor].[USP_AgentJobs] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgentJobsJson OUTPUT, @PrintMeldungen=0; SELECT @AgentJobsJson AS [Json];
Beispiel 4: CREATE TABLE #AgentJobs_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AgentJobs] @ResultSetArt='TABLE', @ResultTablesJson=N'{"jobs":"#AgentJobs_HelpExample"}', @PrintMeldungen=0; SELECT * FROM #AgentJobs_HelpExample; DROP TABLE #AgentJobs_HelpExample; END TRY BEGIN CATCH DROP TABLE #AgentJobs_HelpExample; THROW; END CATCH;
Beispiel 5: EXEC [monitor].[USP_AgentJobs] @JobNamePattern=N'like:ExampleJob%', @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 6: EXEC [monitor].[USP_AgentJobs] @NurProblematisch=1, @LongRunningMinutes=60, @MaxZeilen=100, @ResultSetArt='RAW';
```

