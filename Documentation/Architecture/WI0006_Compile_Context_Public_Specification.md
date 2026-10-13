# WI-0006: Compile-Kontext – freigegebener öffentlicher Vertrag

**Status:** APPROVED; vom Benutzer am 13. Oktober 2026 unmittelbar wie vorgeschlagen freigegeben. Die Implementierung und ihre erforderliche Abnahme sind noch offen.
**Basis:** Aktueller Codeabgleich vom 13. Oktober 2026.

## Bestehende Funktion und verbleibende Lücke

`USP_DatabaseConfigurationAnalysis` liest bereits die sichtbaren
`sys.database_scoped_configurations` ohne feste Optionsliste. Damit ist eine
vorhandene OPTIMIZED_SP_EXECUTESQL-Zeile grundsätzlich ausgabefähig.
`USP_PerformanceCounters` besitzt bereits typisierte Counter und begrenztes
Sampling. WI-0006 ergänzt eine gemeinsame, explizit eingegrenzte Capability-
und Compile-Kontextauswertung. Vorhandene Ausgabeschemas werden nicht verändert.

## Öffentliche Procedure und Parameter

Vorgeschlagen wird die neue rein lesende `monitor.USP_CompileContextAnalysis`.
Eine neue Procedure vermeidet eine Änderung der Defaultausgaben vorhandener
Analyseverfahren und trennt Datenbankkonfiguration von serverweiter Aktivität.

| Parameter | SQL-Typ und Default | Vertrag |
|---|---|---|
| `@DatabaseNames` | `nvarchar(max) = NULL` | Bestehende bracket-aware Namensliste. |
| `@SystemdatenbankenEinbeziehen` | `bit = 0` | Systemdatenbanken sind opt-in. |
| `@DatabaseNamePattern` | `nvarchar(4000) = NULL` | Bestehender LIKE-/Regex-Vertrag, exklusiv zur Namensliste. |
| `@SampleSeconds` | `tinyint = 0` | 0 liest Momentaufnahmen ohne WAITFOR; 1 bis 60 aktiviert genau ein begrenztes gemeinsames Sample. Werte über 60 und NULL sind ungültig. |
| `@MaxZeilen` | `int = 2000` | Positiv begrenzt jede fachliche Ausgabemenge; 0/NULL bedeutet unbegrenzt, negativ ist ungültig. Kein MaxDatenbanken- oder Current-Scope. |
| `@ResultSetArt` | `varchar(16) = 'CONSOLE'` | Bestehende CONSOLE-/RAW-/TABLE-/NONE-Steuerung. |
| `@ResultTablesJson` | `nvarchar(max) = NULL` | Ausschließlich TABLE; benannte vorhandene lokale Seed-Temp-Tabellen. |
| `@JsonErzeugen` | `bit = 0` | Optionales JSON mit Schema 1. |
| `@Json` | `nvarchar(max) = NULL OUTPUT` | Enthält Metadaten und die benannten Arrays. |
| `@PrintMeldungen` | `bit = 1` | Bestehende optionale Hinweise. |
| `@Hilfe` | `bit = 0` | Hilfe ohne fachliche Quellenabfragen. |
| `@StatusCodeOut` | `varchar(40) = NULL OUTPUT` | Modulstatus nach bestehendem Frameworkmodell. |
| `@IsPartialOut` | `bit = NULL OUTPUT` | Unabhängige Teilquellenpartialität. |
| `@ErrorNumberOut` | `int = NULL OUTPUT` | Tatsächlich beobachteter erster Quellenfehler. |
| `@ErrorMessageOut` | `nvarchar(2048) = NULL OUTPUT` | Tatsächliche Quellenfehlermeldung. |

## Benannte native Resultsets

RAW liefert in dieser Reihenfolge `moduleStatus`, `configurations`, `counters`,
`waits`, `cache`, `sourceStatus`, `warnings`. TABLE unterstützt dieselben Namen.
JSON enthält `meta` sowie diese Arrays. CONSOLE liefert genau eine Übersicht
mit gekennzeichneten Datenbank- beziehungsweise Serverscopes; NONE liefert
keine fachlichen Resultsets. Alle Textspalten und Vergleiche erhalten die
explizite Frameworkcollation SQL_Latin1_General_CP1_CS_AS.

`moduleStatus` verwendet den bestehenden Vertrag: `ModuleName sysname NOT NULL`,
`CapturedAtUtc datetime2(3) NOT NULL`, `StatusCode varchar(40) NOT NULL`,
`IsPartial bit NOT NULL`, `RowCount bigint NOT NULL`,
`RequiredPermission nvarchar(128) NULL`, `ErrorNumber int NULL`,
`ErrorMessage nvarchar(2048) NULL`, `Detail nvarchar(1000) NOT NULL`.

`configurations` enthält eine Zeile je ausgewählter sichtbarer Datenbank:
`DatabaseId int NOT NULL`, `DatabaseName sysname NOT NULL`,
`CompatibilityLevel tinyint NULL`, `ConfigurationName sysname NOT NULL`,
`CapabilityStatus varchar(40) NOT NULL`, `Enabled bit NULL`,
`ValueForSecondary int NULL`, `IsValueDefault bit NULL`,
`SourceStatus varchar(40) NOT NULL`, `CapturedAtUtc datetime2(3) NOT NULL`,
`EvidenceLimit nvarchar(1000) NOT NULL`.
ConfigurationName ist ausschließlich OPTIMIZED_SP_EXECUTESQL. Auf Engine 2019
und 2022 ist CapabilityStatus UNAVAILABLE_VERSION; Werte bleiben NULL.
Auf Engine 2025 wird die tatsächliche lokale Katalogzeile geprüft. Version
allein ist kein Nachweis eines lesbaren oder aktivierten Werts.

`counters` enthält ausschließlich die serverweiten Counter Batch Requests/sec,
SQL Compilations/sec und SQL Re-Compilations/sec aus dem SQL-Statistics-Objekt:
`ObjectName nvarchar(128) NOT NULL`, `CounterName nvarchar(128) NOT NULL`,
`InstanceName nvarchar(128) NOT NULL`, `CounterType int NOT NULL`,
`BeforeValue bigint NULL`, `AfterValue bigint NOT NULL`, `DeltaValue bigint NULL`,
`RatePerSecond decimal(38,6) NULL`, `Interpretation varchar(40) NOT NULL`,
`SampleStartUtc datetime2(7) NULL`, `SampleEndUtc datetime2(7) NOT NULL`,
`ElapsedSeconds decimal(19,6) NULL`, `ResetDetected bit NOT NULL`,
`SqlServerStartTime datetime2(3) NULL`, `SourceStatus varchar(40) NOT NULL`,
`EvidenceLimit nvarchar(1000) NOT NULL`.
Sample 0 liefert keine berechnete Rate. Nicht unterstützte Countertypen,
fehlende Vorher-/Nachherbindung oder beobachteter Reset liefern NULL statt Rate.
Die vorhandene TVF_InterpretPerformanceCounter wird für die Typsemantik verwendet.

`waits` enthält ausschließlich RESOURCE_SEMAPHORE_QUERY_COMPILE:
`WaitType nvarchar(120) NOT NULL`, `BeforeWaitingTasksCount bigint NULL`,
`AfterWaitingTasksCount bigint NOT NULL`, `DeltaWaitingTasksCount bigint NULL`,
`BeforeWaitTimeMs bigint NULL`, `AfterWaitTimeMs bigint NOT NULL`,
`DeltaWaitTimeMs bigint NULL`, `BeforeSignalWaitTimeMs bigint NULL`,
`AfterSignalWaitTimeMs bigint NOT NULL`, `DeltaSignalWaitTimeMs bigint NULL`,
`SampleStartUtc datetime2(7) NULL`, `SampleEndUtc datetime2(7) NOT NULL`,
`ElapsedSeconds decimal(19,6) NULL`, `ResetDetected bit NOT NULL`,
`SourceStatus varchar(40) NOT NULL`, `EvidenceLimit nvarchar(1000) NOT NULL`.
Ein Wait-Statistikreset bleibt unabhängig vom Counterreset. Kumulative Werte
oder Sampledeltas belegen keine konkrete Query, Datenbank oder Compileursache.

`cache` aggregiert lediglich CACHESTORE_SQLCP und CACHESTORE_OBJCP aus
`sys.dm_os_memory_cache_counters`:
`CacheType nvarchar(60) NOT NULL`, `EntriesCount bigint NULL`,
`PagesKb bigint NULL`, `CapturedAtUtc datetime2(3) NOT NULL`,
`SourceStatus varchar(40) NOT NULL`, `EvidenceLimit nvarchar(1000) NOT NULL`.
Cacheeinträge werden nicht als Anzahl ausgeführter Queries oder Single-use-Pläne
umgedeutet. Es gibt kein Lesen von Cached-Plan-Handles, SQL-Texten oder Plan-XML.

`sourceStatus` führt jede aktivierte Quelle unabhängig:
`SourceKey varchar(64) NOT NULL`, `DatabaseId int NULL`, `DatabaseName sysname NULL`,
`SourceObject nvarchar(256) NOT NULL`, `CapturedAtUtc datetime2(3) NOT NULL`,
`StatusCode varchar(40) NOT NULL`, `IsPartial bit NOT NULL`, `RowCount bigint NOT NULL`,
`ErrorNumber int NULL`, `ErrorMessage nvarchar(2048) NULL`,
`EvidenceLimit nvarchar(1000) NOT NULL`.

`warnings` enthält `WarningCode varchar(80) NOT NULL`, `DatabaseId int NULL`,
`DatabaseName sysname NULL`, `Detail nvarchar(1000) NOT NULL`.
Es enthält Scope-, Sample-, Reset- und Quellenhinweise, keine automatische
Compile-Storm-, Fehlkonfigurations- oder Reparaturbewertung.

## Grenzen, Quellenisolation und Kosten

Die Configurations werden datenbanklokal gelesen; Counter, Waits und Cache
bleiben serverweit. Sie dürfen nicht auf einzelne ausgewählte Datenbanken
verteilt werden. Quellenaufnahmen erfolgen nacheinander und sind nicht atomar.
Ein aktiviertes Sample hat eine gemeinsame dokumentierte Zeitklammer; die
genaue tatsächliche Dauer und die Reihenfolge der Quellen werden erhalten.
Eigenaktivität des Frameworks ist Teil serverweiter Aktivität.

Die SampleStartUtc-/SampleEndUtc-Werte jeder Menge bezeichnen ihr eigenes
Quellenintervall. Bei Counters wird der Anfang unmittelbar an die erste
Counteraufnahme und das Ende an die zweite Aufnahme gebunden; RatePerSecond
und ElapsedSeconds verwenden ausschließlich diese Counterklammer. Die
Wait-Aufnahmen besitzen eine getrennte dokumentierte Waitklammer. Eine
äußere Aufrufklammer wird nicht als identischer Messzeitpunkt oder identisches
Intervall der Quellen ausgegeben. Cache bleibt eine einzelne Momentaufnahme.

Vor und nach einem Sample wird die native SQL-Server-Startzeit geprüft.
Fehlende oder geänderte Startzeit, fehlende Gegenzeile oder veränderte
Schlüssel-/Typbindung machen das Sample unvergleichbar; Deltas und Raten
bleiben NULL. Counter werden anhand ObjectName, CounterName, InstanceName
und CounterType gebunden; Waits anhand WaitType. Rückläufige native
Zählerwerte oder eine geänderte Serverstartzeit setzen ResetDetected=1.
Der gemeinsame Statusvergleich prüft jeden verwendeten kumulativen Wert.
Bei Reset oder unzureichender Bindung bleibt auch eine daraus abgeleitete
Deltaangabe NULL. Ein unbekannter Countertyp wird als nicht interpretierbar
erhalten, ohne aus seinem Namen eine Rate abzuleiten.

ResetDetected=0 bedeutet ausschließlich, dass kein Reset beobachtet wurde.
Ein zwischenzeitlicher Wait-Reset mit anschließendem Anwachsen über den
alten Wert kann bei zwei Aufnahmen unentdeckt bleiben. Die Ausgabe enthält
diese Grenze in EvidenceLimit und behauptet keine resetfreie Zwischenzeit.

Fehlende Berechtigung oder Quelle wird je Quelle erhalten und verhindert keine
anderen Quellen. Native 1222 wird mit tatsächlicher Fehlernummer behandelt.
Ein unbekannter Clienttimeout liefert keinen qualifizierten SQL-Status.
Erwarteter Versionsfallback setzt allein keine Partialität; tatsächliche
Quellenfehler oder unerwartet fehlende erwartete Werte tun dies. Die erste
tatsächliche Fehlermeldung folgt Configurations in Auswahlreihenfolge,
danach Counters, Waits, Cache. Frühere vorhandene Fehler werden nicht ersetzt.

Die Procedure ändert keine Datenbankoptionen, leert keine Caches oder Waits,
erstellt keine XE-Sessions und erzeugt keine Abfragelast als Produktfunktion.
Kosten entstehen durch die bereits begrenzte Datenbankauswahl, kleine
DMV-Projektionen, Ausgabe und optional höchstens 60 Sekunden WAITFOR. Es
gibt keinen Full-Plan-Cache-Scan und kein High-Impact- oder Remoteverfahren.

## Erforderliche Abnahme

Primär SQL Server 2025/CL170: vorhandene eigene ON-/OFF-Konfiguration,
fehlende Katalogzeile als ausdrücklich künstliche Gegenprobe, echte Rechte-
und Leerpfade, native Countertypen/Werte, Sample0/positives begrenztes Sample,
unabhängige Resets/Fehler, Scope- und Paritätsnachweise sowie eigenes Cleanup.
Ein kurzer synthetischer sp_executesql-Aufruf darf ausschließlich im Test
erzeugt werden und ist keine Qualifikation einer allgemeinen Compile-Storm-
Kausalität. Version 2019/2022 prüfen nur den konkret neuen Konfigurationsfallback.
Unveränderte vorhandene Tests werden nach tatsächlichem Impact ausgewählt.
Native Versuchsgrenzen und Ressourcen werden vor Ausführung festgelegt.

## Primärquellen

- https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-database-scoped-configuration-transact-sql?view=sql-server-ver17
- https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-performance-counters-transact-sql?view=sql-server-ver17
- https://learn.microsoft.com/en-us/sql/relational-databases/performance-monitor/sql-server-sql-statistics-object?view=sql-server-ver17
- https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17
- https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-memory-cache-counters-transact-sql?view=sql-server-ver17
