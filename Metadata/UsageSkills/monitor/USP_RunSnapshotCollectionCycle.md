---
skill_format_version: "1.0.0"
name: "monitor.USP_RunSnapshotCollectionCycle"
schema_name: "monitor"
object_name: "USP_RunSnapshotCollectionCycle"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Stellt den schedulerneutralen SC-023-Einstieg für genau einen ausdrücklich ausgewählten Performance-Counter-, WAIT_STATS- oder FILE_IO-Collector und dessen persistente Evidenz bereit."
source_path: "Code/10_SnapshotBaseline/090_USP_RunSnapshotCollectionCycle.sql"
---

# monitor.USP_RunSnapshotCollectionCycle

## Zweck und Einsatz

Stellt den schedulerneutralen SC-023-Einstieg für genau einen ausdrücklich ausgewählten Performance-Counter-, WAIT_STATS- oder FILE_IO-Collector und dessen persistente Evidenz bereit.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_RunSnapshotCollectionCycle]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[monitor].[InternalRunSnapshotFileIOCycle]`, `[monitor].[InternalRunSnapshotWaitStatsCycle]`, `[monitor].[SnapshotTargetConfiguration]`, `[master].[sys].[databases]`, `[sys].[sp_getapplock]`, `[snapshot].[InternalPurgeExpiredData]`, `[sys].[sp_executesql]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SchedulerType | varchar(16) | nein | 'EXTERNAL' |
| @RunEvenIfNotDue | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @CaptureRunIdOut | bigint | nein | NULL OUTPUT |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |
| @CollectorCode | varchar(64) | nein | 'PERFORMANCE_COUNTERS' |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |

**@SchedulerType:** @SchedulerType: Datentyp varchar(16). MANUAL kennzeichnet einen manuellen Aufruf, EXTERNAL einen extern geplanten Aufruf und SQL_AGENT einen Aufruf durch SQL Server Agent; alle drei nutzen denselben schedulerneutralen Einstieg ohne Sammellogik im Scheduler. Zulässige Werte ausschließlich MANUAL, EXTERNAL, SQL_AGENT. Außen getrimmt und in Großbuchstaben umgewandelt. NULL/leer wird im normalen Pfad ungültig. Default: 'EXTERNAL'. Der frühe Nicht-Performance-Hilfezweig kehrt vor dieser Validierung zurück.

**@RunEvenIfNotDue:** @RunEvenIfNotDue: Datentyp bit. 0 verlangt Fälligkeit; 1 umgeht nur das Collectorintervall, nicht Concurrency, Retention oder Größenbudget. NULL ist im normalen Pfad ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@ResultSetArt:** @ResultSetArt: Datentyp varchar(16). CONSOLE zeigt die priorisierte Lauf-/Modulstatusausgabe; RAW liefert zwei Resultsets (run, modules); TABLE schreibt beide Ergebnisse in zugeordnete lokale Temp-Tabellen; JSON stellt den JSON-Vertrag im @Json-OUTPUT bereit; NONE unterdrückt reguläre Resultsets. Äußere Leerzeichen werden entfernt, Groß-/Kleinschreibung ignoriert; NULL/leer ungültig. PERFORMANCE_COUNTERS unterstützt alle fünf Werte. WAIT_STATS und FILE_IO unterstützen CONSOLE, RAW, TABLE und NONE; JSON als Ausgabeart wird mit 51011 abgewiesen, JSON bleibt dort über @JsonErzeugen optional. Default: 'CONSOLE'.

**@ResultTablesJson:** @ResultTablesJson: Datentyp nvarchar(max). Nur bei TABLE: JSON-Objekt mit Textwerten als lokale Temp-Tabellennamen, zulässige Resultnamen run und modules, zum Beispiel N'{"run":"#MyRun","modules":"#MyModules"}'. InternalPrepareResultTables erlaubt das Mapping einer Teilmenge und prüft nicht, dass beide Namen vorkommen; fehlt später ein Ziel, erhält InternalWriteResultTable NULL und der TABLE-Aufruf schlägt mit Fehler 51010 fehl. Daher sind beide Zuordnungen für eine erfolgreiche Run-TABLE-Ausgabe erforderlich. Ziele müssen in derselben Sitzung vorhanden und lokale #Temp-Tabellen sein. Preflight verlangt eine leere lokale Zieltabelle mit genau einer Seed-Spalte; ##, mehr als 116 Zeichen, Präfix #Monitor, unbekannte/duplizierte Resultnamen, doppelte Ziele und Nicht-Textwerte sind unzulässig. Resultnamen sind case-sensitive; doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft. Ein fehlendes Ziel wird erst bei der Ausgabe erkannt: Ein Capture kann bereits gespeichert und das erste Ziel bereits beschrieben sein; eine atomare Rücknahme beider Ausgaben ist nicht zugesagt. Bei TABLE ist NULL/leer ungültig; außerhalb TABLE sind NULL/leer/Leerzeichen zulässig, nichtleer ungültig. Default: NULL.

**@JsonErzeugen:** @JsonErzeugen: Datentyp bit. 0 erzeugt JSON nur bei ResultSetArt JSON; 1 befüllt den JSON-OUTPUT zusätzlich zu anderer Ausgabeart. NULL ist im normalen Pfad ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Json:** @Json: Datentyp nvarchar(max) OUTPUT. Mit nvarchar(max)-Variablen und OUTPUT zu binden; wird am Eintritt NULL. Bei JsonErzeugen=1 oder ResultSetArt JSON: Objekt mit meta (contractVersion 1, resultName SnapshotCollectionCycle), run als Objekt und modules als Array; NULL-Werte enthalten. Bei frühem RETURN einschließlich Hilfe bleibt NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@PrintMeldungen:** @PrintMeldungen: Datentyp bit. 1 gibt am Ende für Statuswerte außer AVAILABLE, PARTIAL und SKIPPED_NOT_DUE eine RAISERROR-Meldung severity 10 mit NOWAIT aus; 0 unterdrückt sie. NULL wird nicht validiert und löst die IF-Ausgabe nicht aus. Default: 1. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Hilfe:** @Hilfe: Datentyp bit. 1 druckt Hilfe und kehrt mit RETURN zurück; 0 normaler Ablauf. NULL wird nicht als 1 behandelt. OUTPUTs sind zuvor initialisiert. Für jeden normalisierten Collectorwert ungleich PERFORMANCE_COUNTERS liegt der frühe Hilfezweig direkt nach der Initialisierung und vor Filter-/Collector-, Transaktions-, Scheduler- und Ausgabemodusvalidierung. PERFORMANCE_COUNTERS erreicht den späteren Hilfezweig erst nach dem Datenbankfiltergate und der Temp-Tabellenanlage, aber vor Scheduler-/Ausgabemodusvalidierung. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@CaptureRunIdOut:** @CaptureRunIdOut: Datentyp bigint OUTPUT. bigint-Variable mit OUTPUT; initial NULL, enthält erzeugte CaptureRun-ID, sonst NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@StatusCodeOut:** @StatusCodeOut: Datentyp varchar(40) OUTPUT. varchar(40)-Variable mit OUTPUT; initial AVAILABLE, später tatsächlicher Status. Hilfe liefert AVAILABLE, sofern kein früher Filterfehler eintritt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@IsPartialOut:** @IsPartialOut: Datentyp bit OUTPUT. bit-Variable mit OUTPUT; initial 0, später gemäß Ablaufstatus. Hilfe liefert 0, sofern kein früher Filterfehler eintritt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@ErrorNumberOut:** @ErrorNumberOut: Datentyp int OUTPUT. int-Variable mit OUTPUT; initial NULL, Fehlernummer wenn gesetzt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@ErrorMessageOut:** @ErrorMessageOut: Datentyp nvarchar(2048) OUTPUT. OUTPUT-Parameter nvarchar(2048), mit einer nvarchar(2048)-Variablen und OUTPUT zu binden; Kapazität entspricht 2048 UTF-16-Codeeinheiten. Initial NULL; enthält gegebenenfalls die Fehlermeldung. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

**@CollectorCode:** @CollectorCode: Datentyp varchar(64). Ein einzelner Code: PERFORMANCE_COUNTERS erfasst Performance Counter über USP_PerformanceCounters mit SampleSeconds=0; WAIT_STATS liest den vollständigen nativen Waitcache; FILE_IO liest den vollständigen nativen Datei-I/O-Cache und verwendet die drei Datenbankfilter. Außen getrimmt und in Großbuchstaben umgewandelt. NULL/leer ist im normalen Ablauf ungültig. WAIT_STATS und FILE_IO verlangen @@TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF; der Legacy-Pfad PERFORMANCE_COUNTERS hat dieses vorgeschaltete Caller-Gate nicht. Default: 'PERFORMANCE_COUNTERS'.

**@DatabaseNames:** @DatabaseNames: Datentyp nvarchar(max). Nur FILE_IO, sonst werden wirksame Filterwerte mit 51011 abgewiesen. NULL/leer/nur Leerzeichen bedeutet keine exakte Liste. Sonst bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], ]] maskiert ] innerhalb geklammerter Namen. Elementränder getrimmt; leere/fehlerhaft geklammerte Namen, Rohsegmente über 4000 UTF-16-Codeeinheiten oder PARSENAME-Name über 128 Zeichen ungültig. Namen schränken Auswahl ein; Duplikate werden case-sensitive erkannt. Eine wirksame Liste ist nicht mit nicht-NULL Pattern kombinierbar. Default: NULL. Die FILE_IO-Auswahlprüfung wird erst nach erfolgreicher Enabled-, Target- und Policyprüfung erreicht; ein voriger Abbruch bestätigt die Filtersyntax nicht.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen: Datentyp bit. Nur FILE_IO: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. Für PERFORMANCE_COUNTERS und WAIT_STATS ist nur 0 zulässig. NULL ist für alle Collectorwerte ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Ein früher Nicht-Performance-Hilfeaufruf kehrt vor dieser Prüfung zurück.

**@DatabaseNamePattern:** @DatabaseNamePattern: Datentyp nvarchar(4000). Nur FILE_IO; sonst werden wirksame Werte mit 51011 abgewiesen. NULL bedeutet kein Pattern; nicht-NULL wird außen getrimmt, leer oder nach Präfixentfernung ohne Inhalt (like:, regex:, regexi:) ungültig. Zulässig sind LIKE-Muster mit %, _ und [...] sowie Präfixe like:, regex:, regexi:; Präfixerkennung ohne Beachtung der Großschreibung, kein erneutes Trimmen nach Präfixentfernung. LIKE nutzt SQL_Latin1_General_CP1_CS_AS. regex: hat Flag c, regexi: Flag i; Regexsyntax wird nicht vorab geprüft und benötigt SQL Server 2025 plus Compatibility Level mindestens 170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. Nicht-NULL Pattern ist nicht mit wirksamer Namensliste kombinierbar. Default: NULL. Die FILE_IO-Auswahlprüfung folgt erst auf Enabled-, Target- und Policyprüfung.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| run | 1 | 1 | [CaptureRunId] bigint NULL,[TargetDatabaseName] sysname NULL,[CollectorCode] varchar(64) NULL,[SchedulerType] varchar(16) NULL,[StartedAtUtc] datetime2(3) NULL,[EndedAtUtc] datetime2(3) NULL,[SqlServerStartTimeUtc] datetime2(3) NULL,[ResetEpochId] uniqueidentifier NULL,[StatusCode] varchar(40) NOT NULL,[IsPartial] bit NOT NULL,[MetricSampleCount] bigint NOT NULL,[PayloadCount] bigint NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL |
| modules | 1 | 1 | [ModuleStatusId] bigint NULL,[CaptureRunId] bigint NULL,[ModuleName] sysname NOT NULL,[CollectionTimeUtc] datetime2(3) NOT NULL,[StatusCode] varchar(40) NOT NULL,[IsPartial] bit NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL,[EvidenceLimit] nvarchar(1000) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_RunSnapshotCollectionCycle erläutert alle Parameter; Hilfe bestätigt weder Target noch erfolgreichen Lauf.

Ausgelassene Argumente verwenden den jeweiligen Signaturdefault. Zeichenfolgen werden als T-SQL-Literale, Unicodewerte mit N-Präfix übergeben; Zahlen und bit-Werte als skalare Werte. Typkonvertierungen erfolgen vor der Procedure. Der normale Aufruf kann im optionalen Snapshotziel schreiben; @Hilfe=1 beendet vor diesen fachlichen Writes.

Sichere Hilfeaufrufe ohne Collection beziehungsweise Purge:

monitor.USP_RunSnapshotCollectionCycle erläutert alle Parameter; Hilfe bestätigt weder Target noch erfolgreichen Lauf.

Ausgelassene Argumente verwenden den jeweiligen Signaturdefault. Zeichenfolgen werden als T-SQL-Literale, Unicodewerte mit N-Präfix übergeben; Zahlen und bit-Werte als skalare Werte. Typkonvertierungen erfolgen vor der Procedure. Der normale Aufruf kann im optionalen Snapshotziel schreiben; @Hilfe=1 beendet vor diesen fachlichen Writes.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_RunSnapshotCollectionCycle
Version      : 1.2.0
Stand        : 2026-10-26
Zweck        : Stellt den schedulerneutralen SC-023-Einstieg für genau einen
               ausdrücklich ausgewählten Performance-Counter-, WAIT_STATS-
               oder FILE_IO-Collector und dessen persistente Evidenz bereit.
Concurrency  : Benannte Session-Applock, Wartezeit 0; Parallelaufrufe lesen
               keine Quelle und enden als SKIPPED_CONCURRENT.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_RunSnapshotCollectionCycle erläutert alle Parameter; Hilfe bestätigt weder Target noch erfolgreichen Lauf.
Ausgelassene Argumente verwenden den jeweiligen Signaturdefault. Zeichenfolgen werden als T-SQL-Literale, Unicodewerte mit N-Präfix übergeben; Zahlen und bit-Werte als skalare Werte. Typkonvertierungen erfolgen vor der Procedure. Der normale Aufruf kann im optionalen Snapshotziel schreiben; @Hilfe=1 beendet vor diesen fachlichen Writes.
Sichere Hilfeaufrufe ohne Collection beziehungsweise Purge:
monitor.USP_RunSnapshotCollectionCycle erläutert alle Parameter; Hilfe bestätigt weder Target noch erfolgreichen Lauf.
Ausgelassene Argumente verwenden den jeweiligen Signaturdefault. Zeichenfolgen werden als T-SQL-Literale, Unicodewerte mit N-Präfix übergeben; Zahlen und bit-Werte als skalare Werte. Typkonvertierungen erfolgen vor der Procedure. Der normale Aufruf kann im optionalen Snapshotziel schreiben; @Hilfe=1 beendet vor diesen fachlichen Writes.
Sichere Hilfeaufrufe ohne Collection beziehungsweise Purge:
```

