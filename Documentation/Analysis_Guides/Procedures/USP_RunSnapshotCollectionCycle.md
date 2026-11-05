# [monitor].[USP_RunSnapshotCollectionCycle]

**Bereich:** Optionales Snapshot-/Baseline-Paket SC-023
**Zweck:** Führt denselben begrenzten Collection Cycle für MANUAL, EXTERNAL und SQL_AGENT aus.
**Beobachtungsart:** persistierender, restartbezogener Messzyklus
**Kostenklasse:** MEDIUM bis HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure wird eingesetzt, wenn die konfigurierte Snapshot-Datenbank einen neuen Performance-Counter-Messpunkt oder einen ausdrücklich gewählten Wait- oder Datei-I/O-Capture erhalten soll. Alle Schedulerarten verwenden denselben Procedurevertrag. Der Scheduler bestimmt nur den Aufrufzeitpunkt; Due-, Parallelitäts-, Budget- und Collectionentscheidungen bleiben innerhalb des Frameworkvertrags.

## Nicht beantwortete Fragen

Ein einzelner Messpunkt ist kein Trend und liefert keine automatische Kapazitäts- oder Konfigurationsempfehlung. Der Default sammelt Performance Counter; `@CollectorCode='WAIT_STATS'` liest den gesamten nativen Waitcache. Ein unveränderter Enginekontext beweist keinen ausgebliebenen Waitreset. Er beweist weder kontinuierliche Schedulerverfügbarkeit noch Vollständigkeit externer Monitoringdaten. Reset-Epochen, Countertypen und Basiseinheiten müssen vor jeder Delta- oder Ratenbildung kompatibel sein.

## Sicherer Einstieg

Der unveränderte Default verwendet `monitor.USP_PerformanceCounters` mit `@SampleSeconds=0`. Der angehängte Parameter `@CollectorCode` wählt alternativ `WAIT_STATS` oder `FILE_IO`; die Collectorpolicies bleiben getrennt. `Install_All.sql` installiert diese Persistenzfunktion bewusst nicht.

```sql
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @SchedulerType = 'MANUAL',
     @RunEvenIfNotDue = 0,
     @ResultSetArt = 'CONSOLE';
```

## Parameter und Eingabeformen

Die folgenden Verträge unterscheiden PERFORMANCE_COUNTERS, WAIT_STATS und FILE_IO. Alle OUTPUTs werden vor der Hilfe initialisiert; AVAILABLE/0 bei Hilfe ist kein Lauf- oder Targetnachweis. Der frühe Hilfezweig für einen normalisierten Collectorcode ungleich PERFORMANCE_COUNTERS liegt vor Filter- und Collectorvalidierung und vor dem Transaktionsgate. Beim Legacy-Collector kann das Datenbankfiltergate die Hilfe noch vorher mit 51011 beenden; der zweite Hilfezweig folgt nach Temp-Tabellenanlage. Der Code setzt dort LOCK_TIMEOUT 0. Beide Zweige kehren vor Scheduler- und Ausgabevalidierung zurück. Normale WAIT_STATS-/FILE_IO-Aufrufe verlangen keine offene Callertransaktion und IMPLICIT_TRANSACTIONS OFF; dieser vorgeschaltete Schutz gilt nicht allgemein für den Legacy-Collector. Für persistierende Aufrufe wird deshalb ein separater Aufruf ohne Callertransaktion empfohlen.

Ausgelassene Argumente verwenden den jeweils bezeichneten Default. Die Beschreibung nennt die tatsächliche Behandlung von NULL; leere Zeichenfolgen sind für Zahlen und bit keine eigene Eingabesyntax und können bereits bei SQL-Typkonvertierung verändert werden. OUTPUT-Werte werden nur bei Bindung einer passenden Variable mit OUTPUT am Aufruf empfangen.

### @SchedulerType

**Datentyp:** `varchar(16)`. MANUAL kennzeichnet einen manuellen Aufruf, EXTERNAL einen extern geplanten Aufruf und SQL_AGENT einen Aufruf durch SQL Server Agent; alle drei nutzen denselben schedulerneutralen Einstieg ohne Sammellogik im Scheduler. Zulässige Werte ausschließlich MANUAL, EXTERNAL, SQL_AGENT. Außen getrimmt und in Großbuchstaben umgewandelt. NULL/leer wird im normalen Pfad ungültig. Default: 'EXTERNAL'. Der frühe Nicht-Performance-Hilfezweig kehrt vor dieser Validierung zurück.

### @RunEvenIfNotDue

**Datentyp:** `bit`. 0 verlangt Fälligkeit; 1 umgeht nur das Collectorintervall, nicht Concurrency, Retention oder Größenbudget. NULL ist im normalen Pfad ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @ResultSetArt

**Datentyp:** `varchar(16)`. CONSOLE zeigt die priorisierte Lauf-/Modulstatusausgabe; RAW liefert zwei Resultsets (run, modules); TABLE schreibt beide Ergebnisse in zugeordnete lokale Temp-Tabellen; JSON stellt den JSON-Vertrag im @Json-OUTPUT bereit; NONE unterdrückt reguläre Resultsets. Äußere Leerzeichen werden entfernt, Groß-/Kleinschreibung ignoriert; NULL/leer ungültig. PERFORMANCE_COUNTERS unterstützt alle fünf Werte. WAIT_STATS und FILE_IO unterstützen CONSOLE, RAW, TABLE und NONE; JSON als Ausgabeart wird mit 51011 abgewiesen, JSON bleibt dort über @JsonErzeugen optional. Default: 'CONSOLE'.

### @ResultTablesJson

**Datentyp:** `nvarchar(max)`. Nur bei TABLE: JSON-Objekt mit Textwerten als lokale Temp-Tabellennamen, zulässige Resultnamen run und modules, zum Beispiel N'{"run":"#MyRun","modules":"#MyModules"}'. InternalPrepareResultTables erlaubt das Mapping einer Teilmenge und prüft nicht, dass beide Namen vorkommen; fehlt später ein Ziel, erhält InternalWriteResultTable NULL und der TABLE-Aufruf schlägt mit Fehler 51010 fehl. Daher sind beide Zuordnungen für eine erfolgreiche Run-TABLE-Ausgabe erforderlich. Ziele müssen in derselben Sitzung vorhanden und lokale #Temp-Tabellen sein. Preflight verlangt eine leere lokale Zieltabelle mit genau einer Seed-Spalte; ##, mehr als 116 Zeichen, Präfix #Monitor, unbekannte/duplizierte Resultnamen, doppelte Ziele und Nicht-Textwerte sind unzulässig. Resultnamen sind case-sensitive; doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft. Ein fehlendes Ziel wird erst bei der Ausgabe erkannt: Ein Capture kann bereits gespeichert und das erste Ziel bereits beschrieben sein; eine atomare Rücknahme beider Ausgaben ist nicht zugesagt. Bei TABLE ist NULL/leer ungültig; außerhalb TABLE sind NULL/leer/Leerzeichen zulässig, nichtleer ungültig. Default: NULL.

### @JsonErzeugen

**Datentyp:** `bit`. 0 erzeugt JSON nur bei ResultSetArt JSON; 1 befüllt den JSON-OUTPUT zusätzlich zu anderer Ausgabeart. NULL ist im normalen Pfad ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Json

**Datentyp:** `nvarchar(max) OUTPUT`. Mit nvarchar(max)-Variablen und OUTPUT zu binden; wird am Eintritt NULL. Bei JsonErzeugen=1 oder ResultSetArt JSON: Objekt mit meta (contractVersion 1, resultName SnapshotCollectionCycle), run als Objekt und modules als Array; NULL-Werte enthalten. Bei frühem RETURN einschließlich Hilfe bleibt NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @PrintMeldungen

**Datentyp:** `bit`. 1 gibt am Ende für Statuswerte außer AVAILABLE, PARTIAL und SKIPPED_NOT_DUE eine RAISERROR-Meldung severity 10 mit NOWAIT aus; 0 unterdrückt sie. NULL wird nicht validiert und löst die IF-Ausgabe nicht aus. Default: 1. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Hilfe

**Datentyp:** `bit`. 1 druckt Hilfe und kehrt mit RETURN zurück; 0 normaler Ablauf. NULL wird nicht als 1 behandelt. OUTPUTs sind zuvor initialisiert. Für jeden normalisierten Collectorwert ungleich PERFORMANCE_COUNTERS liegt der frühe Hilfezweig direkt nach der Initialisierung und vor Filter-/Collector-, Transaktions-, Scheduler- und Ausgabemodusvalidierung. PERFORMANCE_COUNTERS erreicht den späteren Hilfezweig erst nach dem Datenbankfiltergate und der Temp-Tabellenanlage, aber vor Scheduler-/Ausgabemodusvalidierung. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @CaptureRunIdOut

**Datentyp:** `bigint OUTPUT`. bigint-Variable mit OUTPUT; initial NULL, enthält erzeugte CaptureRun-ID, sonst NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @StatusCodeOut

**Datentyp:** `varchar(40) OUTPUT`. varchar(40)-Variable mit OUTPUT; initial AVAILABLE, später tatsächlicher Status. Hilfe liefert AVAILABLE, sofern kein früher Filterfehler eintritt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @IsPartialOut

**Datentyp:** `bit OUTPUT`. bit-Variable mit OUTPUT; initial 0, später gemäß Ablaufstatus. Hilfe liefert 0, sofern kein früher Filterfehler eintritt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @ErrorNumberOut

**Datentyp:** `int OUTPUT`. int-Variable mit OUTPUT; initial NULL, Fehlernummer wenn gesetzt. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @ErrorMessageOut

**Datentyp:** `nvarchar(2048) OUTPUT`. OUTPUT-Parameter nvarchar(2048), mit einer nvarchar(2048)-Variablen und OUTPUT zu binden; Kapazität entspricht 2048 UTF-16-Codeeinheiten. Initial NULL; enthält gegebenenfalls die Fehlermeldung. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @CollectorCode

**Datentyp:** `varchar(64)`. Ein einzelner Code: PERFORMANCE_COUNTERS erfasst Performance Counter über USP_PerformanceCounters mit SampleSeconds=0; WAIT_STATS liest den vollständigen nativen Waitcache; FILE_IO liest den vollständigen nativen Datei-I/O-Cache und verwendet die drei Datenbankfilter. Außen getrimmt und in Großbuchstaben umgewandelt. NULL/leer ist im normalen Ablauf ungültig. WAIT_STATS und FILE_IO verlangen @@TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF; der Legacy-Pfad PERFORMANCE_COUNTERS hat dieses vorgeschaltete Caller-Gate nicht. Default: 'PERFORMANCE_COUNTERS'.

### @DatabaseNames

**Datentyp:** `nvarchar(max)`. Nur FILE_IO, sonst werden wirksame Filterwerte mit 51011 abgewiesen. NULL/leer/nur Leerzeichen bedeutet keine exakte Liste. Sonst bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], ]] maskiert ] innerhalb geklammerter Namen. Elementränder getrimmt; leere/fehlerhaft geklammerte Namen, Rohsegmente über 4000 UTF-16-Codeeinheiten oder PARSENAME-Name über 128 Zeichen ungültig. Namen schränken Auswahl ein; Duplikate werden case-sensitive erkannt. Eine wirksame Liste ist nicht mit nicht-NULL Pattern kombinierbar. Default: NULL. Die FILE_IO-Auswahlprüfung wird erst nach erfolgreicher Enabled-, Target- und Policyprüfung erreicht; ein voriger Abbruch bestätigt die Filtersyntax nicht.

### @SystemdatenbankenEinbeziehen

**Datentyp:** `bit`. Nur FILE_IO: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. Für PERFORMANCE_COUNTERS und WAIT_STATS ist nur 0 zulässig. NULL ist für alle Collectorwerte ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Ein früher Nicht-Performance-Hilfeaufruf kehrt vor dieser Prüfung zurück.

### @DatabaseNamePattern

**Datentyp:** `nvarchar(4000)`. Nur FILE_IO; sonst werden wirksame Werte mit 51011 abgewiesen. NULL bedeutet kein Pattern; nicht-NULL wird außen getrimmt, leer oder nach Präfixentfernung ohne Inhalt (like:, regex:, regexi:) ungültig. Zulässig sind LIKE-Muster mit %, _ und [...] sowie Präfixe like:, regex:, regexi:; Präfixerkennung ohne Beachtung der Großschreibung, kein erneutes Trimmen nach Präfixentfernung. LIKE nutzt SQL_Latin1_General_CP1_CS_AS. regex: hat Flag c, regexi: Flag i; Regexsyntax wird nicht vorab geprüft und benötigt SQL Server 2025 plus Compatibility Level mindestens 170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. Nicht-NULL Pattern ist nicht mit wirksamer Namensliste kombinierbar. Default: NULL. Die FILE_IO-Auswahlprüfung folgt erst auf Enabled-, Target- und Policyprüfung.

## Hilfe ohne fachliche Writes

Die vier folgenden Aufrufe enden im Hilfezweig. Sie starten keine Collection und keinen Purge; die Hilfepfade können lokale Temp-Tabellen anlegen.

```sql
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1;
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1, @CollectorCode='PERFORMANCE_COUNTERS';
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1, @CollectorCode='WAIT_STATS';
EXEC [monitor].[USP_RunSnapshotCollectionCycle] @Hilfe=1, @CollectorCode='FILE_IO';
```

## Resultsets und Leserichtung

CONSOLE zeigt den priorisierten Laufstatus. RAW, TABLE und optionaler JSON-OUTPUT trennen `run` und `modules`; persistierte Metrics werden nicht als zusätzliches Defaultresultset kopiert. Lesen Sie zuerst Status, Start, Ende, Schedulerart und `ResetEpochId`. Ordnen Sie danach den Modulstatus und dessen Partialität ein. `SKIPPED_NOT_DUE` und ein No-wait-Concurrency-Skip sind kontrollierte Zustände, keine erfolgreichen Messpunkte.

Die elf lokalen Textspalten einschließlich der TABLE-Zuordnung verwenden
`SQL_Latin1_General_CP1_CS_AS`. Die fünf Textspalten von `run` und vier
Textspalten von `modules` behalten die Frameworkcollation auch bei
abweichender `tempdb`-Collation. Der interne Counterabschluss verwendet
dieselbe Collation für seine sechs transienten Textspalten. Bestehende
persistente Zieltabellen und deren Collation werden dabei nicht geändert.

## Waitaufruf und Ausgabegrenze

```sql
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @CollectorCode = 'WAIT_STATS',
     @SchedulerType = 'MANUAL',
     @RunEvenIfNotDue = 0,
     @ResultSetArt = 'CONSOLE';
```

Die Aufnahmeprüfung kennt die Targetkennungen `1.2.1` / Schema 2 sowie `1.3.0` und `1.3.1` / Schema 3 mit jeweils gebundenem Retentionsvertrag. Die aktuelle Kombination aus Targetkennung `1.3.0` / Schema 3 und dem aktuellen Purgehelfer wird wegen abweichender Retentionsvertragsversion abgewiesen; eine unbekannte historische Paketkombination ist damit nicht qualifiziert. Die [Zielkonfiguration](USP_ConfigureSnapshotTarget.md) erläutert diese Versionsbindung. Waits benötigen außerdem eine aktivierte Framework-
und Waitpolicy, keine Callertransaktion sowie `IMPLICIT_TRANSACTIONS OFF`.
Unsichere Callerzustände werden vor Temp-DDL ausschließlich über OUTPUT als
`INVALID_PARAMETER` mit Fehler `51011` zurückgegeben. Für Waits sind `CONSOLE`,
`RAW`, `TABLE` und `NONE` zulässig. `@JsonErzeugen=1` aktiviert den optionalen
JSON-OUTPUT; die Ausgabeart `JSON` bleibt auf dem Legacy-Collector beschränkt.

Disabled und NotDue beenden Waits vor Capture- und Purgewrites. Force umgeht
nur das Collectorintervall. Ein noch nicht fälliger Purge verhindert einen
fälligen oder erzwungenen Capture nicht. Ein überschrittenes Größenbudget
bleibt auch mit Force wirksam. Derselbe Sessionlock serialisiert beide
Collectors und den öffentlichen Purge.

Scheitert das Lesen der Ausgabe nach einem bereits bestätigten Abschluss,
bleibt der gespeicherte Capture erhalten. Capture-ID und Fehlerstatus bleiben
sichtbar; ohne bestätigte Runprojektion liefern RAW/TABLE keine erfundene
Runzeile mit Nullmengen, JSON enthält `run: {}`. Eine verschwundene Zielidentität
nach Vorbereitung kann einen ehrlichen unfinalisierten Run zurücklassen.

## Datei-I/O und seine Auswahlgrenze

```sql
EXEC [monitor].[USP_RunSnapshotCollectionCycle]
     @CollectorCode = 'FILE_IO',
     @DatabaseNames = N'[ExampleDatabase]',
     @SchedulerType = 'MANUAL',
     @ResultSetArt = 'CONSOLE';
```

Datei-I/O verlangt das vollständige Target 1.3.1 / Schema 3, eine ausdrücklich
aktivierte FILE_IO-Policy und denselben sicheren Callerzustand wie Waits.
Die drei am Ende angehängten Parameter entsprechen CurrentIO: @DatabaseNames,
@SystemdatenbankenEinbeziehen mit Default 0 und @DatabaseNamePattern. Sie erhalten
alle bisherigen Parameterpositionen. Wirksame Datei-I/O-Filter bei anderen
Collectors werden mit 51011 abgewiesen.

Die Quelle liest genau einen vollständigen nativen Dateicache. Engine- und
Dateikatalogbeobachtungen vor/nach dem Read begrenzen seine Zuordnung.
MaxRows begrenzt ausschließlich sortierte geeignete Datei-Metrics. Fehlende
Metadaten bleiben Issues; ein unbekannter Wert wird kein Nullsample. Sechs
Counter und der Größen-Gauge bleiben von den unbewiesenen Kandidaten getrennt.

Prüfen Sie FINALIZATION_UNCONFIRMED und EndedAtUtc=NULL vor jeder Auswertung.
Eine solche Capture-ID bleibt die unmittelbare Vergleichsgrenze; es wird kein
älterer Erfolg übersprungen. Ein zusätzlicher Readbackfehler erzeugt einen leeren
Runbericht. Lokale Diagnosen mit ModuleStatusId=NULL behaupten keine gespeicherte
Zeile. Der [Datei-I/O-Vertrag](../../Architecture/Snapshot_Baseline_Package_Contract.md#öffentliche-datei-io-aufnahme)
führt Mengen-, Fehler- und Retentionsbindungen.

## Beispiele und Gegenbeispiele

Ein passender Example-Lauf verwendet `MANUAL`, eine aktivierte synthetische Zielkonfiguration und ein kleines `MaxRows`-Budget. Zwei aufeinanderfolgende Läufe innerhalb derselben Reset-Epoche können später verglichen werden. Ein Gegenbeispiel ist die Berechnung einer Rate über einen SQL-Server-Neustart oder die Deutung eines partiellen Moduls als vollständigen Snapshot.

## Leere oder partielle Ausgabe

Eine deaktivierte Konfiguration, ein nicht fälliger Lauf oder eine bereits gehaltene Applock-Ressource kann den Cycle ohne Metrics beenden. Ein Quellfehler bleibt im Modulstatus sichtbar und darf bereits geschriebene Statuszeilen nicht in einen erfolgreichen Vollcapture umdeuten. Payload kann bewusst deaktiviert sein, ohne dass typisierte Metrics fehlen.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `MEDIUM` bis `HIGH_OPT_IN` |
| Standardpfad | Due-Prüfung und ein begrenzter Performance-Counter-Snapshot |
| Teuerster Pfad | Purge plus Collection und optionale komprimierte Payloadpersistenz |
| Haupttreiber | Counterzahl, Retentionrückstand, Zeilenbudget und Ziel-I/O |
| Skalierung | Ein Cycle je lokaler Zielbeziehung; parallele Ausführung wird übersprungen |
| Ressourcen | DMV-Lesezugriff, JSON-Verarbeitung und typisierte Zielwrites |
| Begrenzungswirkung | Policy, `MaxRows`, Intervall, Budget und No-wait-Applock |
| Locking und Nebenwirkungen | Persistierende Inserts und begrenzter Purge im Ziel |
| Schutzmechanismus | Konfigurationsgate, Due-Check, Reset-Epoche und Abschlussstatus |
| Sicherer Einsatz | Manueller Einzelcycle mit kleinem Budget vor Scheduleraktivierung |
| Aussagegrenze | Ein erfolgreicher Cycle ist kein Trend- oder Schedulernachweis |

## Eine Zeile bedeutet

`run` entspricht einem begonnenen, übersprungenen oder abgeschlossenen Collection Cycle. `modules` entspricht dem Status des einen Collector-Moduls. Metric-Samples sind in der Snapshot-Datenbank normalisiert und werden nicht als zusätzliches Defaultresultset dupliziert.

## So lesen

Berücksichtigen Sie zuerst `StatusCode`, `IsPartial`, Start/Ende und `ResetEpochId`. Prüfen Sie danach `modules` auf fehlende Rechte oder Evidenzgrenzen. `SKIPPED_NOT_DUE`, `SKIPPED_CONCURRENT`, `DISABLED` und `STOPPED_SIZE_BUDGET` bedeuten ausdrücklich, dass kein Quellread stattfand.

## Warum kann das problematisch sein?

Snapshots erzeugen dauerhafte Daten-, Log- und Backupmenge. Parallel gestartete Sammler würden außerdem zeitlich unterschiedliche Quellenstände und doppelte Last erzeugen. Eine Applock mit Wartezeit null serialisiert deshalb Cycle und Purge.

## Wann ist es kein Problem?

Ein übersprungener Lauf ist kein Fehler, wenn Intervall, Parallelität oder Deaktivierung ihn erklären. Ein kumulativer Raw Counter ist nicht allein auffällig; erst mehrere Samples innerhalb derselben Reset-Epoche erlauben eine belastbare Veränderungsbetrachtung.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wurde ein vollständiger, zeitlich und restartbezogen interpretierbarer Messpunkt persistiert?

### Technischer Hintergrund

Der Quell-JSON-Vertrag ist nur während des autorisierten Aufrufs transient. Roh- und interpretierte Werte werden getrennt typisiert; konkrete Counteridentitäten bilden einen gehashten Scope, dessen JSON nur im lokalen Ziel liegt. Optionales Rohpayload wird verlustfrei GZIP-komprimiert und mit SHA-256 gebunden.

### Datenkette

Konfiguration → No-wait-Applock → collectorspezifische Aufnahmeprüfung → begrenzter Purge → Budgetprüfung → Quelle → Scope/MetricSample/Payload → CaptureRun/ModuleStatus. Waits prüfen Enabled und Due vor dem Purge; ihre Quelle wird genau einmal ohne Leselimit materialisiert.

### Source Select

Vor jeder Sammlung werden Singleton-Konfiguration und Zielzustand geprüft:

```sql
SELECT
      [c].[TargetDatabaseName]
    , [c].[IsEnabled]
    , [c].[DefaultSchedulerType]
    , [d].[state_desc]
    , [d].[is_read_only]
FROM [monitor].[SnapshotTargetConfiguration] AS [c] WITH (NOLOCK)
LEFT JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[name] = [c].[TargetDatabaseName]
WHERE [c].[ConfigurationId] = 1
  AND [c].[IsEnabled] = 1;
```

**Wichtig für die Eigenlast:** Danach ist der Pfad schreibend: No-wait-Applock, Due-/Budgetprüfung, genau ein Collector-Aufruf und typisierte Inserts in `snapshot.CaptureRun`, `ModuleStatus`, `MetricSample` und optional Payload. Für Waits begrenzt `MaxRows` nur die ausgewählten Schreibtypen; der gesamte Cache wird davor gelesen. Collectorpolicy und Zeitintervall begrenzen die Erfassung; Parallelität wird übersprungen statt blockiert.

### Zeit- und Scope-Modell

Capturezeiten sind UTC. Der Wait-Engine-Start wird dagegen als nativer lokaler Wert im versionierten Kontext gespeichert; `CaptureRun.SqlServerStartTimeUtc` bleibt für Waits NULL. Vorher-/Nachher-Engineidentität begrenzt die Zuordnung, beweist aber weder eine atomare DMV-Sicht noch Resetkontinuität. Die drei monotonen Differenzkandidaten bleiben `MONOTONIC_CONTINUITY_UNPROVEN`; maximale Waitzeit erhält keinen additiven Kandidaten. Erfolgreiche Waitcaptures bleiben deshalb `PARTIAL`.

### Bewertung und Gegenprobe

Vergleichen Sie mehrere zeitlich getrennte Läufe mit identischer Epoche. Prüfen Sie auffällige Counter anhand von Current-State-, Wait-, I/O- oder OS-Evidenz gegen.

### Typische Fehlinterpretation

Fehlendes Sample ist weder Nullwert noch gesunder Zustand. `PARTIAL` darf nicht in eine scheinbar vollständige Trendlinie umgedeutet werden.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_PerformanceCounters`, `USP_PurgeSnapshotData` sowie passende Current-State- und Server-Health-Module.

## Primärquellen

- [sys.dm_os_performance_counters](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-performance-counters-transact-sql?view=sql-server-ver17)
- [sys.dm_io_virtual_file_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-io-virtual-file-stats-transact-sql?view=sql-server-ver17)
- [sys.database_files](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-database-files-transact-sql?view=sql-server-ver17)
- [sys.dm_os_wait_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17)
- [sys.dm_os_sys_info](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-sys-info-transact-sql?view=sql-server-ver17)
- [sp_getapplock](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-getapplock-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../../Operations/Snapshot_Baseline_Operations.md)
