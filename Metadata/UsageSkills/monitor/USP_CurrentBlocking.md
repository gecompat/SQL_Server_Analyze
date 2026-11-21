---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentBlocking"
schema_name: "monitor"
object_name: "USP_CurrentBlocking"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Ermittelt aktuelle Blocking-Ketten, löst deren Ressourcen begrenzt auf Datenbank-, Objekt-, Index-, Partitions- und Seitenkontext auf und liefert optional die zugehörigen Locks."
source_path: "Code/02_CurrentState/030_USP_CurrentBlocking.sql"
---

# monitor.USP_CurrentBlocking

## Zweck und Einsatz

Ermittelt aktuelle Blocking-Ketten, löst deren Ressourcen begrenzt auf Datenbank-, Objekt-, Index-, Partitions- und Seitenkontext auf und liefert optional die zugehörigen Locks.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

VIEW SERVER STATE bis SQL Server 2019 beziehungsweise VIEW SERVER PERFORMANCE STATE ab SQL Server 2022. Lockdetails benötigen zusätzlich die freigegebene Analyseklasse LOCKS_DEEP.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SessionIds | nvarchar(max) | nein | NULL |
| @MinWaitMs | bigint | nein | 0 |
| @SystemSessionsEinbeziehen | bit | nein | 0 |
| @ToolHintergrundabfragenEinbeziehen | bit | nein | 0 |
| @MitSqlText | bit | nein | 1 |
| @MaxSqlTextZeichen | int | nein | 3000 |
| @BlockingObjektTiefe | varchar(16) | nein | 'STANDARD' |
| @MaxObjektAufloesungen | int | nein | 100 |
| @MitLockDetails | bit | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ParentCurrentStateSnapshotId | uniqueidentifier | nein | NULL |

**@SessionIds:** @SessionIds: nvarchar(max), Default=NULL; Eingabeform: Liste ganzer Zahlen, getrennt durch Pipe (|), Komma oder Semikolon; Trennzeichen dürfen gemischt werden. Kommas/Semikolons werden vor der Pipe-Zerlegung überall umgewandelt, auch innerhalb eckiger Klammern; Pipe trennt nur außerhalb von [...], ]] maskiert eine schließende Klammer. Elementränder werden getrimmt, Elemente nicht entquotet. Ausgelassen/NULL deaktiviert den Filter und umfasst alle sichtbaren Sessions. N'' ergibt EMPTY_LIST; nur Leerzeichen bzw. leere Elemente ergeben EMPTY_ITEM. Jedes Element muss eine bigint-Zahl im Bereich 0..32767 sein; negative, ungültige, doppelte oder außerhalb liegende Werte setzen INVALID_PARAMETER. Gültige IDs werden als smallint-Filter verwendet.

**@MinWaitMs:** @MinWaitMs: bigint, Default=0 ms; Eingabeform: nichtnegative Ganzzahl im bigint-Bereich. Filtert Request- und ergänzende Waiting-Task-Kanten auf wait_time/wait_duration_ms >= Grenzwert, jeweils mit COALESCE(Quellwert,0). Ausgelassen ergibt 0; NULL oder negativ ist INVALID_PARAMETER. Es gibt keine zusätzliche obere fachliche Grenze außerhalb des bigint-Typs.

**@SystemSessionsEinbeziehen:** @SystemSessionsEinbeziehen: bit, Default=0; Schalter: 0 schließt Nicht-User-/System-Sessions aus; 1 lässt sie in Request- und Waiting-Task-Kanten zu. Ausgelassen ergibt 0; NULL ist im Normalpfad INVALID_PARAMETER. Die SQL-bit-Konvertierung erfolgt vor Procedure-Eintritt; numerischer Nullwert wird 0, numerische Nichtnullwerte werden 1.

**@ToolHintergrundabfragenEinbeziehen:** @ToolHintergrundabfragenEinbeziehen: bit, Default=0; Schalter: 0 unterdrückt erkannte Tool-Hintergrundabfragen, wenn sie blockierte Blätter sind; 1 lässt diese Blätter samt Ketten erscheinen. Ein Tool als Zwischen- oder Root-Blocker einer normalen Abfrage bleibt in beiden Fällen sichtbar; die normale Kette wird nicht abgeschnitten. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER. Vor Eintritt erfolgt SQL-bit-Konvertierung (0→0, numerischer Nichtnullwert→1).

**@MitSqlText:** @MitSqlText: bit, Default=1; Schalter: 1 ergänzt Statementtext für blockierte Session, direkten Blocker und Root Blocker; beim schlafenden Root kann der Text aus dem zuletzt bekannten Verbindungsbatch stammen. 0 unterdrückt Text und kennzeichnet die Quelle als NOT_REQUESTED. Ausgelassen ergibt 1; NULL ist INVALID_PARAMETER; SQL konvertiert numerische Eingaben vor Eintritt zu bit (0→0, Nichtnull→1). Aktivierung kann Textzugriffe und deren CPU-/Speicher-/Transferkosten verursachen; es ist keine Anonymisierung.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen: int, Default=3000 Zeichen; nichtnegative Ganzzahl 0..2147483647. Begrenzt Unicode-Textausgabe für BlockedStatement, BlockerStatement und RootBlockerStatement; positive Werte kürzen bei Überschreitung (Surrogatpaare bleiben intakt), 0 lässt Text unbegrenzt. Ausgelassen ergibt 3000; NULL wird als unbegrenzt an den Projektor weitergegeben; negativ ist INVALID_PARAMETER. Erhebung des SQL-Texts wird durch das Zeichenlimit nicht verhindert.

**@BlockingObjektTiefe:** @BlockingObjektTiefe: varchar(16), Default='STANDARD'; Eingabeform: nach LTRIM/RTRIM und UPPER genau NONE, STANDARD oder DEEP (vollständige geschlossene Wertemenge). NONE überspringt Ressourcenauflösung; STANDARD löst deduplizierte Wait-Ressourcen kandidatenbegrenzt auf; DEEP tut dies ebenfalls und setzt intern @MitLockDetails=1, wodurch Locks angefordert werden. Ausgelassen ergibt STANDARD; NULL, leer/nur Leerzeichen und jeder andere Wert sind INVALID_PARAMETER. Jeder tatsächlich aktivierte Lockpfad (DEEP oder @MitLockDetails=1) ruft InternalCheckAnalysisPath für LOCKS_DEEP auf. Die Helperpolicy entscheidet, ob Gruppenzugriff und/oder @HighImpactConfirmed=1 erforderlich sind; eine Bestätigung gewährt keine Gruppenfreigabe.

**@MaxObjektAufloesungen:** @MaxObjektAufloesungen: int, Default=100 Kandidaten; Eingabeform: ganze Zahl 1..1000 einschließlich. Begrenzt die deduplizierten Ressourcen-Kandidaten, die aufgelöst werden; je Kandidat erfolgt der Auflösungsbatch mit LOCK_TIMEOUT 0. Ausgelassen ergibt 100; NULL und Werte außerhalb des Bereichs sind INVALID_PARAMETER. Es begrenzt weder die Kettenausgabe noch alle DMV-Lese-/Sortierarbeiten.

**@MitLockDetails:** @MitLockDetails: bit, Default=0; Schalter: 0 überspringt sys.dm_tran_locks, sofern nicht @BlockingObjektTiefe=DEEP den Wert intern auf 1 setzt; 1 fordert Locks für Sessions der bereits rekonstruierten Blockingketten an, auch bei @BlockingObjektTiefe=NONE. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER; SQL-bit-Konvertierung erfolgt vor Eintritt. Jeder tatsächlich aktivierte Lockpfad ruft InternalCheckAnalysisPath für LOCKS_DEEP auf. Ob die aktive LOCKS_DEEP-Policy Gruppenzugriff und/oder @HighImpactConfirmed=1 erfordert, bestimmt die Helperpolicy; Bestätigung erteilt keine Freigabe.

**@HighImpactConfirmed:** @HighImpactConfirmed: bit, Default=0; Schalter: 0 bestätigt den High-Impact-Pfad nicht; 1 bestätigt die Anforderung, gewährt aber keine Analyseklassen-Freigabe. Ausgelassen ergibt 0; NULL ist im Normalpfad INVALID_PARAMETER. SQL konvertiert numerische Aufrufwerte vor Eintritt zu bit (0→0, Nichtnull→1). Die Bestätigung wird nur wirksam, wenn @MitLockDetails=1 oder @BlockingObjektTiefe=DEEP tatsächlich den LOCKS_DEEP-Pfad aktiviert; sonst wird keine Lockfreigabe angefordert.

**@MaxZeilen:** @MaxZeilen: int, Default=1000 Zeilen; Eingabeform: ganze Zahl 0..2147483647. Für 0 < N < 2147483647 begrenzt die frühe Auswahl Blockingketten- und Lockkandidaten jeweils auf N+1. Bei N=2147483647 werden höchstens N Kandidaten ohne zusätzliche Probe ausgewählt; die Kettenkandidaten werden für Ressourcenanreicherung, Unicodeprojektion und Fehlerbehandlung weiterverarbeitet. Danach entfernt der gemeinsame späte Kettencap alle Ketten hinter N nach WaitTimeMs DESC, BlockedSessionId; RAW/JSON/CONSOLE/TABLE geben diese begrenzte Kettenmenge aus. Locks werden beim jeweiligen Ausgabeweg auf N begrenzt. 0 oder NULL bedeutet unbegrenzt; ausgelassen ergibt 1000; negativ ist INVALID_PARAMETER. Kandidatenauswahl und später Ausgabecap begrenzen nicht die vorgelagerte DMV-Erhebung und dürfen nicht als vollständige Arbeitsbegrenzung verstanden werden.

**@ResultSetArt:** @ResultSetArt: varchar(16), Default='CONSOLE'; Eingabeform: nach äußerem Trimmen und UPPER einer der Werte CONSOLE, RAW, TABLE oder NONE (vollständige geschlossene Wertemenge). CONSOLE gibt das interaktive Kettengrid, optional Locks und Warnungen aus; RAW gibt Meta/Status, typisierte BlockingChains, bei aktiviertem Lockpfad Locks sowie Warnungen aus; TABLE schreibt nur blockingChains in das benannte Ziel; NONE unterdrückt fachliche Resultsets. JSON wird davon unabhängig über @JsonErzeugen gesteuert. Ausgelassen ergibt CONSOLE; NULL/leer/nur Leerzeichen wird zu leerem Token und ist INVALID_PARAMETER. Andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson: nvarchar(max), Default=NULL; Eingabeform für TABLE: gültiges, nichtleeres JSON-Objekt mit exakt dem case-sensitiven Key blockingChains; der Wert muss ein JSON-String mit nichtleerem Zielnamen sein. Das Ziel muss eine vorhandene lokale #Temp-Tabelle sein, darf keine globale ##-Tabelle sein, muss höchstens 116 Zeichen nach SQL Server LEN-Regel umfassen und darf nicht mit #Monitor beginnen (Prüfung case-insensitiv); der Name muss als gequoteter Tabellenbezeichner auflösbar sein. Das Ziel muss leer sein und genau eine Seed-Spalte besitzen. Der Preflight weist ungültige JSON-Form, unbekannte/falsch geschriebene Keys, leere/nicht-string Werte, unzulässige oder doppelte Ziele sowie fehlende/nicht leere/falsch strukturierte Tabellen mit Fehler 51011 zurück. LTRIM/RTRIM trimmt hier nur U+0020 (gewöhnliches Leerzeichen); eine allein daraus bestehende Eingabe gilt als leer. Nur mit @ResultSetArt=TABLE zulässig; der Nicht-TABLE-Guard akzeptiert NULL oder nach LTRIM/RTRIM leeren Text, sonst wirft er Fehler 51011. Ausgelassen/NULL/leer ist daher nur außerhalb TABLE zulässig; TABLE benötigt das Mapping. TABLE-Preflight und Nicht-TABLE-Guard laufen vor @Hilfe.

**@JsonErzeugen:** @JsonErzeugen: bit, Default=0; Schalter: 0 erzeugt kein JSON, 1 füllt @Json unabhängig von @ResultSetArt mit Envelope-Schlüsseln meta, blockingChains, locks und warnings; bei deaktivierten Locks ist locks eine leere Menge. Ausgelassen ergibt 0; NULL ist im Normalpfad INVALID_PARAMETER. SQL konvertiert numerische Aufrufwerte vor Eintritt zu bit (0→0, Nichtnull→1).

**@Json:** @Json: nvarchar(max) OUTPUT, Default=NULL; optionale Empfangsvariable vom Typ nvarchar(max), beim EXEC mit OUTPUT zu binden. Die Procedure setzt die Ausgabe sofort auf NULL; mit @JsonErzeugen=1 enthält sie das JSON-Envelope (meta, blockingChains, locks, warnings), andernfalls bleibt sie NULL. Ausgelassen ist zulässig, wenn der JSON-Wert nicht empfangen werden muss. Ein INPUT-Wert wird nicht ausgewertet.

**@PrintMeldungen:** @PrintMeldungen: bit, Default=1; Schalter: 1 erlaubt am Ende eine Severity-10-Meldung, wenn Status nicht AVAILABLE oder AVAILABLE_LIMITED ist; 0 unterdrückt diese Zusatzmeldung. Statusresultsets, Blockingdaten, Warnungen und JSON bleiben davon unberührt. Ausgelassen ergibt 1; NULL ist im Normalpfad INVALID_PARAMETER. SQL konvertiert numerische Aufrufwerte vor Eintritt zu bit (0→0, Nichtnull→1).

**@Hilfe:** @Hilfe: bit, Default=0; Schalter: 0 fährt mit Analyse fort, 1 druckt die eingebaute Hilfe und kehrt zurück, vor einer angeforderten TABLE-Zielprüfung. Zu diesem Hilfepfad gehören keine fachlichen Quellenzugriffe; @Json ist durch die Eintrittsinitialisierung NULL. Ausgelassen ergibt 0. NULL wird nicht als Hilfe erkannt und löst keine eigene Parameterablehnung aus, sondern läuft in den normalen Pfad; SQL konvertiert numerische Werte vor Eintritt zu bit.

**@ParentCurrentStateSnapshotId:** @ParentCurrentStateSnapshotId: uniqueidentifier, Default=NULL; Eingabeform: GUID einer im aktuellen USP_CurrentOverview-Aufruf angelegten Parent-Snapshot-Menge derselben SQL-Session. NULL/ausgelassen liest die Quellen frisch und erzeugt eine eigene EvidenceSnapshotId. Eine nicht-NULL-ID muss in den benötigten Parent-Temp-Tabellen vorliegen und zu OwnerSessionId=@@SPID sowie ContractVersion=2 gehören; andernfalls wird ein als INVALID_PARENT_SNAPSHOT im Modulstatus erfasst. Bei gültiger ID übernimmt Blocking Sessions, Requests, Waiting Tasks, Connections, optional SQL-Text sowie Startzeit/Partialität aus den Parentdaten. Das macht die nacheinander gelesenen Quellen nicht atomar; Lock-/Ressourcenanreicherung bleibt kandidatenbezogen.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| blockingChains | 1 | 1 | [LeafSessionId] smallint NOT NULL , [BlockedSessionId] smallint NOT NULL , [BlockingSessionId] smallint NOT NULL , [RootBlockingSessionId] smallint NULL , [BlockingOwnerType] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingOwnerDescription] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingChain] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ChainDepth] int NOT NULL , [IsCycle] bit NOT NULL , [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [WaitTimeMs] bigint NULL , [WaitResource] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourceType] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourceDatabaseId] int NULL , [BlockingResourceDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourceSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourceObjectId] int NULL , [BlockingResourceObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourceIndexId] int NULL , [BlockingResourceIndexName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourcePartitionId] bigint NULL , [BlockingResourcePartitionNumber] int NULL , [BlockingResourceFileId] int NULL , [BlockingResourcePageId] bigint NULL , [BlockingResourceRowId] int NULL , [BlockingResourceMetadataSubtype] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourceMetadataName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourcePageTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourceName] nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockingResourceResolutionStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockedLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockedHostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockedProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockedIsToolBackgroundQuery] bit NOT NULL , [BlockedToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockedToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockedToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockedToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockerLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockerHostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockerProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootBlockerLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootBlockerHostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootBlockerProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootBlockerSessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootBlockerRequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootBlockerOpenTransactionCount] int NULL , [RootBlockerLastRequestStartTime] datetime NULL , [RootBlockerLastRequestEndTime] datetime NULL , [RootIsToolBackgroundQuery] bit NOT NULL , [RootToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockedStatementCharacters] bigint NULL , [BlockedStatementBytes] bigint NULL , [BlockedStatementIsTruncated] bit NOT NULL DEFAULT(0) , [BlockedStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BlockerStatementCharacters] bigint NULL , [BlockerStatementBytes] bigint NULL , [BlockerStatementIsTruncated] bit NOT NULL DEFAULT(0) , [BlockerStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootBlockerStatementSource] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RootBlockerStatementCharacters] bigint NULL , [RootBlockerStatementBytes] bigint NULL , [RootBlockerStatementIsTruncated] bit NOT NULL DEFAULT(0) , [RootBlockerStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentBlocking] @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentBlocking; Snapshotdiagnostik, keine Historie.

Daten: sys.dm_exec_requests, sys.dm_exec_sessions, begrenzte Ressourcenauflösung.

Berechtigung: VIEW SERVER STATE bis 2019, VIEW SERVER PERFORMANCE STATE ab 2022.

RAW/JSON enthalten Status und Warnungen; ungültige Parameter ergeben INVALID_PARAMETER. JSON enthält meta, blockingChains, locks und warnings. TABLE-Preflight läuft nur im normalen Pfad nach dem Hilfezweig und kann bei ungültigem Mapping werfen.

CONSOLE:


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentBlocking
Version      : 3.0.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Ermittelt aktuelle Blocking-Ketten, löst deren Ressourcen
               begrenzt auf Datenbank-, Objekt-, Index-, Partitions- und
               Seitenkontext auf und liefert optional die zugehörigen Locks.
SQL-Version  : SQL Server 2019 oder neuer.
Parameter    : @SessionIds = NULL oder z. B. N'57|61'; @MaxZeilen > 0
               begrenzt, NULL/0 ist unbegrenzt. @ResultSetArt akzeptiert
               RAW, CONSOLE, TABLE oder NONE case-insensitiv. JSON wird als Envelope
               mit blockingChains, locks und warnings geliefert.
Berechtigung : VIEW SERVER STATE bis SQL Server 2019 beziehungsweise
               VIEW SERVER PERFORMANCE STATE ab SQL Server 2022. Lockdetails
               benötigen zusätzlich die freigegebene Analyseklasse LOCKS_DEEP.
Eigenlast    : Standard gering. Ressourcen werden dedupliziert und nur bis
               @MaxObjektAufloesungen einzeln mit LOCK_TIMEOUT 0 aufgelöst.
               sys.dm_tran_locks wird nur bei expliziter Anforderung und nur
               für beteiligte Sessions gelesen.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentBlocking; Snapshotdiagnostik, keine Historie.
Daten: sys.dm_exec_requests, sys.dm_exec_sessions, begrenzte Ressourcenauflösung.
Berechtigung: VIEW SERVER STATE bis 2019, VIEW SERVER PERFORMANCE STATE ab 2022.
RAW/JSON enthalten Status und Warnungen; ungültige Parameter ergeben INVALID_PARAMETER. JSON enthält meta, blockingChains, locks und warnings. TABLE-Preflight läuft nur im normalen Pfad nach dem Hilfezweig und kann bei ungültigem Mapping werfen.
CONSOLE:
TABLE-Mapping separat deklarieren; lokale Ziele müssen leere Einspalten-#Temp-Tabellen sein:
DECLARE @Tables nvarchar(max);
CREATE TABLE #CurrentBlocking_HelpExample (Seed int NULL);
DROP TABLE #CurrentBlocking_HelpExample;
JSON:
DECLARE @Json nvarchar(max);
```

