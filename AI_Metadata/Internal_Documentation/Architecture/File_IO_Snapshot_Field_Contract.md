# Datei-I/O-Snapshots: geplanter Feld- und Migrationsvertrag

**Stand:** 26. Oktober 2026.
**Status:** unabhängig geprüfter Sollvertrag vor Implementierung; keine hier geplante API oder Targetversion ist ausgeliefert.
**Artefakt-UID:** `urn:uuid:01a17587-45e0-7332-a8bd-2015f82e2bad`.
**Registrierung:** `DEFERRED`; keine finale lesbare Kennung vergeben.
**Zuordnung:** SC-023-EXPANSION; dieser Vertrag konkretisiert den
[Quell-/Identitätsvorvertrag](File_IO_Snapshot_Dossier.md).

## Geltung und geplante Lieferfolge

Der Vertrag erweitert ausschließlich das optionale Snapshotpaket. Die
vorhandenen Performance-Counter- und Waitpfade bleiben erhalten. Zuerst folgen
bekannte Migration, internes Datei-I/O-Target und notwendige Waitkompatibilität
im Framework. Die öffentliche native Datei-I/O-Aufnahme folgt getrennt.
Produktcode beginnt erst nach unabhängigem Review dieses Vertrags.

Als neuer vollständiger Targetstand ist `1.3.0` mit `SchemaVersion=3`
vorgesehen. Das ausdrücklich unvollständige Installationsstadium lautet
`1.2.2` mit Schema 3. Die Frameworkversion und der öffentliche
JSON-Ausgabevertrag werden dadurch nicht automatisch geändert. Der heute
gelieferte Targetstand bleibt bis zur Implementierung `1.2.1` / Schema 2.

## Öffentliche Auswahl und Reihenfolge

`USP_ConfigureSnapshotTarget` soll `FILE_IO` über den bestehenden angehängten
`@CollectorCode` akzeptieren. Seine Parameterreihenfolge bleibt unverändert.
`@CollectorEnabled` steuert nur diese Policy. `@UpdateSharedPolicy=NULL`
bedeutet weiterhin `1` für PERFORMANCE_COUNTERS und `0` für andere bekannte
Collector. Shared0 erhält Frameworkzeile, gemeinsame Retention, andere
Collectorpolicies und eigene Retentionszuordnungen. Shared1 verwendet die
bereits eingeführte öffentliche Besitzertransaktion über beide Datenbanken.

Nach den heutigen 14 Parametern von `USP_RunSnapshotCollectionCycle` werden
ausschließlich die bekannten Auswahlparameter angehängt:

| Position | Parameter | Typ und Default |
|---|---|---|
| 15 | `@DatabaseNames` | `nvarchar(max)=NULL` |
| 16 | `@SystemdatenbankenEinbeziehen` | `bit=0` |
| 17 | `@DatabaseNamePattern` | `nvarchar(4000)=NULL` |

Die Namen, Typen und Bedeutung entsprechen `USP_CurrentIO`. Nicht leere
neue Filter beziehungsweise System-opt-in bei einem anderen Collector sind
ungültige neue Eingaben. Alte positionale Aufrufe und Defaults bleiben
unverändert. FILE_IO verwendet CONSOLE, RAW, TABLE oder NONE und optionalen
JSON-OUTPUT; die Ausgabeart JSON bleibt beim Legacy-Collector. Die bisherigen
Schemas `run` und `modules` bleiben unverändert.

Neue Eingaben werden ohne Callertransaktion und mit IMPLICIT_TRANSACTIONS OFF
verarbeitet. Unsichere Callerzustände enden vor Temp-DDL über OUTPUT. Enabled
und Due werden unter demselben Framework-Sessionlock vor mutierendem Purge
oder Capture geprüft. Force umgeht nur das Collectorintervall. Der normale
Purge-Skip ohne Fehler verhindert keinen Capture; ein überschrittenes
Softbudget bleibt wirksam. Erst danach beginnt der eigentliche Sourcepfad.

Der geplante interne Abschlusshelper InternalCompleteFileIOCycle erhält in
dieser Reihenfolge CaptureRunId bigint, CollectorJson nvarchar(max),
ExpectedTargetDatabaseId int, ExpectedTargetDatabaseName sysname,
ExpectedTargetCreateDate datetime, StatusCodeOut varchar(40) OUTPUT,
IsPartialOut bit OUTPUT, ErrorNumberOut int OUTPUT und
ErrorMessageOut nvarchar(2048) OUTPUT. Er nimmt keine Callertransaktion an.
Er verlangt tatsächliches vollständiges Target 1.3.0, die gebundene
Zielidentität und einen unbeschriebenen eigenen RUNNING-FILE_IO-Run mit
passendem Frameworknamen. Er speichert Rohwerte, Status, Kontexte, optionale
Payload und Abschluss atomar in seiner kurzen eigenen Transaktion.
Der Sourcepfad wird nicht in diese Transaktion eingeschlossen. Fehler
rollen die Fachwrites zurück und finalisieren die ehrliche Fehlergrenze
separat; bereits bestätigte Captures bleiben bei späterem Ausgabefehler erhalten.


## Einmalige native Materialisierung

Eine eigenständige INSERT/SELECT-Aufnahme materialisiert
`sys.dm_io_virtual_file_stats(NULL,NULL)` einmal in einen lokalen Cache.
Diese Aufnahme enthält keinen TOP-, WHERE-, JOIN- oder APPLY-Lesecap. Erst
der materialisierte Cache wird mit der ausgewählten Datenbankmenge verbunden.
Metadatenreads und Source-/Payloadprojektion bleiben auf diese Auswahl begrenzt.
Bei leerer Auswahl kann der native Aufruf entfallen; dieser Zustand wird
ausdrücklich als NOT_STARTED dargestellt.

Dateikatalog und gebundener Mastereintrag werden davor und danach gelesen.
Der native Handle stammt dagegen nur aus diesem einen I/O-Read. Es gibt
keinen erfundenen Vorher-/Nachher-Handle und keinen zweiten I/O-Read zu seiner
Prüfung. Ein Handlewechsel kann gegenüber dem vorherigen Capture beobachtet
werden. Eine gleiche Beobachtung beweist keinen ausbleibenden Reset.

Der Default umfasst auch zugängliche Framework- und Targetdatenbanken.
Deren Werte enthalten Eigenlast des Collectors; sie werden nicht stillschweigend
ausgeschlossen. Explizite physische Pfadspalten und Pending-I/O werden nicht
gelesen. Native Fehlermeldungen bleiben im bestehenden vollständigen
Fehlervertrag erhalten und werden nicht wegen möglicherweise enthaltener
Laufzeitwerte anonymisiert.

## Transienter Source-v1-Rahmen

Der JSON-Root besitzt genau `meta`, `databases`, `files` und `issues`.
Unbekannte oder doppelte Member, falsche Schreibweise und widersprüchliche
Mengen werden abgelehnt. Jeder aufgeführte Member ist vorhanden; unbekannte
zulässige Werte sind JSON-null. Text wird nicht implizit in Zahlen oder Bits
umgedeutet. JSON-Bigints verwenden ganzzahlige Dezimallexeme ohne Exponent,
Dezimalpunkt oder Vorzeichen; zulässige Werte liegen zwischen 0 und
9223372036854775807. IDs bleiben positive ganzzahlige JSON-Zahlen im
jeweiligen nativen Wertebereich.

UTC bedeutet exakt `YYYY-MM-DDTHH:mm:ss.sssZ`. Native DATETIME-Werte verwenden
dieselbe Millisekundenpräzision ohne Z oder implizite Zeitzonenumrechnung.
GUIDs sind kanonische kleine 36-Zeichen-Werte; ihre UUID-Version wird nicht
mit der Artefakt-UID-Regel verwechselt. Ein Handle ist null oder `0x` mit
16 kleinen Hexziffern. Ein gemessener Nullwert ist nicht automatisch ein
fehlender Wert: insbesondere bleibt Create-LSN `0` eine gültige Beobachtung.
NULL bezeichnet unbekannte GUIDs, LSNs oder Handles. Eine zusätzliche
semantische Bedeutung eines gemessenen Null- beziehungsweise Zero-Handles
wird nicht erfunden.

### meta: genau 16 Member

| Member | JSON-Typ und Bedeutung |
|---|---|
| `schemaVersion` | Zahl, exakt 1. |
| `resultName` | String, exakt `SnapshotFileIO`. |
| `statusCode` | String: AVAILABLE, EMPTY_UNPROVEN, PARTIAL, DENIED_PERMISSION, UNAVAILABLE_OBJECT oder ERROR_HANDLED. |
| `isPartial` | Boolean; nur AVAILABLE ist false. |
| `sourceComplete` | Boolean für vollständige Enumeration und erforderliche Metadatenabdeckung im ausgewählten Scope. |
| `errorNumber` | Native int-Zahl oder null. |
| `errorMessage` | String bis 2048 UTF-16-Codeeinheiten oder null. |
| `measurementStartUtc` | UTC-String oder null bei nicht mehr bestätigbarer Zeitbindung. |
| `measurementEndUtc` | UTC-String oder gemeinsam mit dem Start null. |
| `nativeReadStartUtc` | UTC-String oder null, falls keine bestätigte native Aufnahme vorliegt. |
| `nativeReadEndUtc` | UTC-String oder gemeinsam mit dem nativen Start null. |
| `nativeReadState` | String: NOT_STARTED, SUCCEEDED oder FAILED. |
| `selectedNativeRows` | Kanonischer Dezimalstring oder null, wenn die Aufnahme fehlgeschlagen ist. |
| `framework` | Objekt mit genau `databaseId`, `databaseName`, `databaseCreateDateNative`. |
| `engine` | Objekt mit genau `serverName`, `sqlServerStartTimeLocal`, `sqlServerStartTimeMsTicks`; bei fatalem Sourcefehler null. |
| `selection` | Objekt mit genau `requestedDatabaseNames`, `requestedDatabaseNamePattern`, `systemDatabasesIncluded`, `selectedDatabaseCount`, `selectionSha256`. |

Framework-ID, Name und native Erstellungszeit binden den vorbereiteten
Sourcekontext. Enginefelder entsprechen den tatsächlich vorher/nachher
gleichen Beobachtungen; Startticks sind ein nichtnegativer Dezimalstring.
Requested-Namen und Pattern sind String/null, System-opt-in ist Boolean,
Anzahl ist ein Dezimalstring und SHA-256 ist ein kleiner 64-Hex-String.
Der Auswahlhash bindet die tatsächliche geordnete Menge aus Datenbank-ID,
binär exaktem Namen und nativer Erstellungszeit. Unterschiedliche Eingabetexte
mit derselben tatsächlichen Menge erzeugen keine erfundene Scopeänderung.

Das gesamte Messfenster umfasst Engine- und Katalogbeobachtungen. Ein
bestätigtes natives Fenster liegt darin. Capturestart, Messfenster und
Abschlussprüfung müssen geordnet sein; bei einem Clock-Rücksprung werden
keine passenden UTC-Werte erfunden. EMPTY_UNPROVEN kann sourceComplete=true
tragen; PARTIAL und fatale Zustände tragen false. Ein fehlgeschlagener nativer
Read liefert files=[] und selectedNativeRows=null, nicht eine erfundene Nullmenge.

### databases, files und issues

Jeder ausgewählte Datenbankeintrag besitzt genau `DatabaseId`, `DatabaseName`,
`DatabaseCreateDateNative` und `MetadataStatusCode`. Namen sind Strings mit
nativer Maximallänge 128. ID/Name/Erstellungszeit sind eindeutig und müssen
der tatsächlich ausgewählten Menge entsprechen. MetadataStatusCode ist
AVAILABLE, DENIED_PERMISSION, UNAVAILABLE_OBJECT, ERROR_HANDLED oder
TARGET_CHANGED; AVAILABLE verlangt beide erfolgreichen stabilen Kontextreads.

Jeder native Dateieintrag besitzt genau die folgenden 13 Member:

| Member | JSON-Typ |
|---|---|
| `DatabaseId`, `FileId` | Je eine native positive ganzzahlige Zahl. |
| `SampleMs` | Nichtnegative Bigint-Zahl; Hostuptime, keine UTC. |
| `Reads`, `ReadBytes`, `ReadStallMs` | Je eine nichtnegative Bigint-Zahl. |
| `Writes`, `WriteBytes`, `WriteStallMs` | Je eine nichtnegative Bigint-Zahl. |
| `SizeOnDiskBytes` | Nichtnegative Bigint-Zahl als Gauge. |
| `FileHandle` | Nativer Hexstring oder null. |
| `MetadataBefore`, `MetadataAfter` | Je ein Metadatenobjekt oder null. |

Jedes Metadatenobjekt enthält genau `DatabaseId`, `FileId`, `FileGuid`,
`CreateLsn`, `FileType`, `FileState`, `LogicalName`. Die beiden IDs sind Zahlen und
entsprechen der zugeordneten Beobachtung; GUID ist String/null, LSN ein
kanonischer Dezimalstring mit höchstens 25 Ziffern oder null, Typ eine native
tinyint-Zahl, FileState eine native tinyint-Zahl und Name ein String bis 128 Codeeinheiten. Der Name ist eine
Katalogbeobachtung und kein vom VFS gemessener Identitätswert.

Ein Issue besitzt genau `ScopeType`, `SourceName`, `DatabaseId`, `FileId`,
`DatabaseName`, `StatusCode`, `ErrorNumber`, `ErrorMessage`, `EvidenceLimit`. ScopeType ist
SELECTION, DATABASE, FILE oder SOURCE. SourceName ist einer der Strings
DATABASE_SELECTION, sys.databases, sys.database_files, sys.dm_os_sys_info,
sys.dm_io_virtual_file_stats oder SOURCE_CONTRACT. Nicht bekannte IDs/Namen und Fehler
sind null; Meldung und Evidenzgrenze haben die vorhandenen Limits 2048/1000.
Fehlende native Zeilen zu bekannten online ROWS-/LOG-Dateien beziehungsweise
nicht zuordenbare native Zeilen werden ausdrücklich als Abdeckungslücke
erhalten. Ein nicht beobachteter Wert ist kein Nullsample.

| Issue-StatusCode | Wirkung auf SourceComplete |
|---|---|
| SELECTION_UNRESOLVED, DATABASE_CONTEXT_CHANGED | false |
| DENIED_PERMISSION, UNAVAILABLE_OBJECT, ERROR_HANDLED | false |
| FILE_METADATA_UNAVAILABLE, NATIVE_FILE_UNAVAILABLE, FILE_STATE_CHANGED, FILE_TYPE_CHANGED | false |
| UNSUPPORTED_FILE_TYPE, FILE_NOT_ONLINE | Keine Unvollständigkeit innerhalb des abgegrenzten Typs-/Onlinescope. |
| IDENTITY_OBSERVATION_CHANGED, IDENTITY_FIELD_UNKNOWN | Keine Enumerationslücke; individuelle Vergleichsgrenze. |

Das sind die abschließenden Issuecodes. Metadatenstatus TARGET_CHANGED wird
bei Datenbankdrift auf DATABASE_CONTEXT_CHANGED abgebildet. Andere nicht
AVAILABLE-Metadatenstatus behalten ihren entsprechenden Issuecode.
AVAILABLE mit sourceComplete=true verlangt mindestens eine geeignete Datei;
ohne geeignete Datei gilt bei vollständiger Enumeration EMPTY_UNPROVEN.
Bei vorhandenen Abdeckungslücken gilt PARTIAL. NOT_STARTED ist ausschließlich
bei leerer tatsächlich ausgewählter Datenbankmenge zulässig; die bekannte
ausgewählte native Menge ist dann 0, auch wenn ein Auswahl-Issue vorliegt.

## Metrikdefinitionen: genau 16 mit ContractVersion 1

| MetricCode | ValueType | Unit |
|---|---|---|
| `IO_READ_COUNT` | BIGINT | count |
| `IO_READ_BYTES` | BIGINT | bytes |
| `IO_READ_STALL_MS` | BIGINT | ms |
| `IO_WRITE_COUNT` | BIGINT | count |
| `IO_WRITE_BYTES` | BIGINT | bytes |
| `IO_WRITE_STALL_MS` | BIGINT | ms |
| `IO_SIZE_ON_DISK_BYTES` | BIGINT | bytes |
| `IO_READ_COUNT_DELTA_CANDIDATE` | BIGINT | count |
| `IO_READ_BYTES_DELTA_CANDIDATE` | BIGINT | bytes |
| `IO_READ_STALL_MS_DELTA_CANDIDATE` | BIGINT | ms |
| `IO_WRITE_COUNT_DELTA_CANDIDATE` | BIGINT | count |
| `IO_WRITE_BYTES_DELTA_CANDIDATE` | BIGINT | bytes |
| `IO_WRITE_STALL_MS_DELTA_CANDIDATE` | BIGINT | ms |
| `IO_DELTA_STATUS` | STRING | status |
| `IO_FILE_CONTEXT` | STRING | json |
| `IO_CAPTURE_CONTEXT` | STRING | json |

Eine neue FILE_IO-Policy wird deaktiviert mit Intervall 30, MaxRows 1000,
PayloadEnabled=0 und Retention DEFAULT angelegt. Passende vorhandene eigene
Zeilen bleiben einschließlich Beschreibung, Aktivierung, Seedflags und
Retentionszuordnung erhalten. Falsche Werttypen, Einheiten oder Vertragsversionen
sind Konflikte vor Produktwrites.

## Scope-, Epochen- und Hashbindung

Der globale Scope hat Typ SERVER; Dateisamples erhalten FILE_IO_FILE. Jeder
Dateiscope bindet die beobachtete Engine, Datenbank-ID/-Name/-Erstellungszeit,
Datei-ID/GUID/Create-LSN/Typ, den einmal beobachteten Handle und die
Identitätsvollständigkeit. Bei unvollständiger Zuordnung gehört zusätzlich
die aktuelle Capture-ID zur Beobachtung; diese wird nicht als dauerhafte
Dateigeneration wiederverwendet. Widersprüchliche Vorher-/Nachher-Metadaten
werden nicht zu einer erfundenen gemessenen GUID oder einem Namen vereinigt.

ScopeKeyHash ist SHA-256 über die gespeicherte kanonische UTF-16LE-
ScopeIdentityJson. Eine gleiche Scope-ID ersetzt keine Hashprüfung. Der
SERVER-Root besitzt in dieser Reihenfolge scopeVersion=1, collectorCode=FILE_IO
und engine mit den drei Source-Enginefeldern. Sein ParentScopeId ist null.
Der Dateiroot besitzt in dieser Reihenfolge scopeVersion, collectorCode,
engine, database, file, observationCaptureRunId und identityComplete.
Engine und database verwenden die Source-Engine- beziehungsweise die drei
Auswahlidentitätsfelder; Status gehört nicht zur Identität. file besitzt
FileId, FileHandle, MetadataBefore, MetadataAfter in dieser Reihenfolge.
Die beiden Metadatenobjekte enthalten die sechs Sourcefelder ohne LogicalName.
LogicalName bleibt eine gesonderte Beobachtung im Dateikontext und verändert
keine Dateiepochenentscheidung. Der Dateiparent ist der tatsächliche SERVER-Scope.
ObservationCaptureRunId ist bei vollständiger Identität null und sonst die
aktuelle kanonische Capture-ID. Keine freie Quellenformatierung wird als
kanonischer Hashinput akzeptiert; INCLUDE_NULL_VALUES ist durchgehend erforderlich.

IdentityComplete verlangt eine stabile Engine-/Datenbankbindung, passende
Metadaten-IDs, gleiche nicht NULL GUIDs und Create-LSNs, denselben ROWS-/LOG-Typ,
FileState=0 vor/nach der Aufnahme und einen nicht NULL nativen Handle. Create-LSN 0 bleibt dabei zulässig.
LogicalName wird nicht auf Identitätsgleichheit geprüft. Vorher-/Nachher-
GUID- oder LSN-Unterschiede erlauben nur eine ausdrücklich ungebundene
Rohbeobachtung, wenn Datenbank und Dateityp weiterhin zuordenbar sind.

Jede geschriebene Datei erhält sieben Rohsamples, IO_DELTA_STATUS und
IO_FILE_CONTEXT. Bei erfolgreichem Vergleich kommen genau sechs Kandidaten
hinzu. Ein globales IO_CAPTURE_CONTEXT-Sample beschreibt Auswahl und Mengen.
Für N geschriebene und C vergleichbare Dateien gilt somit:
MetricSampleCount = 9*N + 6*C + 1. Ein fataler Sourcefehler schreibt keine
Metrics. Ein gültiger leerer Capture besitzt ausschließlich globalen Kontext.

CaptureRun.ResetEpochId und CaptureRun.SqlServerStartTimeUtc bleiben für
FILE_IO null. Die Dateiepochen werden je Datei an ihre Roh-, Status-, Kontext-
und Kandidatensamples gebunden. Das globale Kontextsample erhält eine eigene technische ContextEpochId,
neu je Capture und gleich seiner tatsächlichen MetricSample.ResetEpochId.
Sie ist ausdrücklich keine Datei-/Counterepoche. Die bestehende NOT-NULL-
Bedingung von MetricSample.ResetEpochId bleibt erhalten; keine zusätzliche
Nullablemigration wird implizit eingeführt. Eine neue oder gebrochene Vergleichsbasis erzeugt eine neue
Dateiepoche; nur ein gültiger monotoner Vergleich übernimmt die vorherige.
Ein Gauge-Rückgang allein ist kein kumulativer Counterreset.

Der Rohhash bindet sieben tatsächlich gespeicherte Zeilen als JSON-Array,
geordnet nach MetricCode mit BIN2. Jede Zeile enthält genau MetricCode,
MetricDefinitionId, ScopeId, ResetEpochId und BigintValue als kanonische
Strings. Der Hash verwendet die tatsächliche UTF-16LE-Serialisierung.
Ein globaler geordneter Manifesthash bindet die geschriebenen Scope-IDs,
Dateiepochen, Rohhashes und Hashes der tatsächlich gespeicherten Dateikontexte.
Er behauptet keine allgemeine administrative Unveränderlichkeit.

## Persistierter Dateikontext v1: genau 18 Rootmember

Alle nachfolgend genannten IDs, Mengen und Bigint-Beobachtungen sind
kanonische Dezimalstrings. Nur Schema-/Kontextversionen sind JSON-Zahlen.
GUIDs, Hexhashes, UTC- und Native-Zeitstrings folgen den Sourceformaten.
Unbekannte zulässige Werte bleiben JSON-null; kein Member wird ausgelassen.

| Member | Typ und Bindung |
|---|---|
| schemaVersion | Zahl 1. |
| collectorCode | String FILE_IO. |
| captureRunId, scopeId | Je ein String der tatsächlichen positiven ID. |
| scopeIdentitySha256 | String, tatsächlicher ScopeKeyHash und Hash über gespeicherte ScopeIdentityJson. |
| resetEpochId | String der tatsächlichen Dateiepoche. |
| sampleMs | String der einmal beobachteten nativen Uptime. |
| logicalNameBefore, logicalNameAfter | Je der Katalogstring bis 128 Codeeinheiten oder null. |
| measurementStartUtc, measurementEndUtc | Je der tatsächliche UTC-Messfensterstring. |
| sourceComplete | Boolean des globalen Sourcezustands dieses Captures. |
| rawSampleCount | String 7. |
| rawProjectionSha256 | String des tatsächlichen Sieben-Zeilen-Rohhashs. |
| previousCaptureRunId | String der unmittelbar vorherigen finalisierten FILE_IO-ID oder null. |
| previousContextVersion | Zahl 1 nur bei tatsächlich validiertem vorherigem Dateikontext, sonst null. |
| comparisonStatus | Einer der nachfolgend festgelegten Statusstrings. |
| epochDecision | NEW_BASELINE, NEW_UNBOUND_OBSERVATION, NEW_COMPARISON_BREAK oder RETAIN_OBSERVED_EPOCH. |

Die beiden Namensbeobachtungen dienen ausschließlich der Diagnose. Ein bloßer
Namenswechsel bei gleicher sonstiger Bindung ist kein bewiesener Dateiaustausch.
Rohsampler tragen die native Read-Endzeit als CollectedAtUtc; dies ist eine
Fenstergrenze und keine Behauptung simultaner Zeilenmessung. Vollständige
Rohsamples verwenden NATIVE_CUMULATIVE beziehungsweise NATIVE_GAUGE und
IsPartial=0, soweit ihre einzelne Dateizuordnung vollständig ist. Unvollständige
Zuordnung markiert diese Rohsamples partiell. Status, Kontext und sämtliche
Kandidaten bleiben IsPartial=1. Globale Sourcepartialität wird zusätzlich im
Kontext und Run erhalten; einzelne vollständige Rohwerte beweisen keine
vollständige Datenbankmenge.

## Persistierter Capturekontext v1: genau 13 Rootmember

Die Reihenfolge der folgenden Member ist kanonisch. Auch die Reihenfolge
der angegebenen Unterobjektmember ist fest; die Typkonvention entspricht
dem Dateikontext. Es gibt keine unbegrenzte Namens-/Dateiliste im Kontext.

| Member | Typ und exakte Untergliederung |
|---|---|
| schemaVersion | Zahl 1. |
| collectorCode | String FILE_IO. |
| captureRunId, serverScopeId | Je ein tatsächlicher positiver ID-String. |
| contextEpochId | GUID-String der tatsächlichen technischen Epoche ausschließlich dieses globalen Kontextsamples. |
| framework | databaseId als String, databaseCreateDateNative als String, tupleSha256 als Hashstring. |
| engine | sqlServerStartTimeLocal als String, sqlServerStartTimeMsTicks als String, tupleSha256 als Hashstring. |
| window | measurementStartUtc, measurementEndUtc, nativeReadStartUtc, nativeReadEndUtc; je Zeitstring oder zulässiges null. |
| selection | databaseCount als String, selectionSha256 als Hashstring, scopeContractVersion als Zahl 1. |
| capture | nativeReadState als String, sourceComplete als Boolean, selectedNativeFileCount, eligibleFileCount, writtenFileCount, excludedFileCount, unboundFileCount, effectiveMaxRows als Strings, writeLimited als Boolean. |
| samples | rawSampleCount, candidateSampleCount, fileContextSampleCount, statusSampleCount; je ein String. |
| previousCaptureRunId | Unmittelbar vorherige finalisierte FILE_IO-ID als String oder null. |
| fileRawContextManifestSha256 | Hashstring des tatsächlichen gespeicherten Manifests. |

Frameworkhash verwendet exakt das Objekt mit databaseId als JSON-Zahl,
databaseName als String und databaseCreateDateNative als String, in dieser
Reihenfolge. Der Name muss binär CaptureRun.SourceDatabaseName entsprechen;
die gespeicherte Kontext-ID wird für die Rekonstruktion als native int-Zahl
geschrieben. Enginehash verwendet exakt serverName, sqlServerStartTimeLocal,
sqlServerStartTimeMsTicks als Strings, in dieser Reihenfolge. Der tatsächliche
SERVER-Scope muss denselben Inhalt in seinem engine-Unterobjekt besitzen.
Weder Scope-ID noch ScopeKeyHash wird anstelle dieses Engineobjekts gehasht. Auswahlhash bindet die drei Identitätsfelder
je Datenbank, geordnet nach numerischer ID. Alle Hashes verwenden feste
JSON-Memberreihenfolge, INCLUDE_NULL_VALUES und UTF-16LE. Das Manifest besteht
je geschriebener Datei aus ScopeId, ResetEpochId, RawProjectionSha256,
FileContextSha256 als Strings, geordnet nach numerischer Scope-ID.

Native FileCount ist die tatsächliche Anzahl ausgewählter VFS-Zeilen.
Eligible zählt zuordenbare ROWS-/LOG-Zeilen einschließlich gültiger Nullcounter.
Eine unbekannte GUID allein verhindert keine Rohspeicherung. Unbekannter
Dateityp oder widersprüchlicher Datenbankbezug erlaubt dagegen keine erfundene
ROWS-/LOG-Zuordnung. Geeignete Dateien werden nach numerischer Datenbank-ID
und Datei-ID ausgewählt; Written=min(Eligible,MaxRows), WriteLimited folgt
dem tatsächlichen Vergleich. Ausgeschlossene und ungebundene Mengen bleiben
getrennt. Kein Zähler ersetzt die Prüfung der tatsächlichen Zeilenmenge.

Zuordenbar verlangt bestätigte Datenbankbindung sowie vor und nach dem Read
passende Datei-IDs, denselben Typ 0 oder 1 und FileState=0 in beiden Metadatenbeobachtungen. Guid-/LSN-/Handlelücken allein
verhindern diese Rohspeicherung nicht. Eindeutig nicht unterstützte Typen
sind excluded. Ein stabiler nichtonline FileState ist ebenfalls excluded;
fehlende Typ-/State-/Datenbankbindung ist unbound. Typ- oder Statewechsel
innerhalb des Fensters sind unbound und machen SourceComplete=false. Für erfolgreich
enumerierte ausgewählte Zeilen gilt Native=Eligible+Excluded+Unbound. Die Identitätsvollständigkeit
ist eine zusätzliche Vergleichsbedingung und keine Behauptung permanenter Identität.

SourceComplete=false gilt bei fehlgeschlagenem Read, Datenbank-Kontextwechsel,
fehlenden Metadaten, nicht verfügbaren erwarteten nativen Zeilen oder
unaufgelöster expliziter Auswahl. Ein vollständig gelesener unbekannter GUID-
Wert oder ein beobachteter Dateigenerationswechsel ist dagegen eine
Identitätsgrenze; er behauptet keinen Fehler der gesamten Enumeration.
Nicht unterstützte Typen sind eine ausdrückliche Scopegrenze; freie Statuswerte
sind nicht zulässig. Stabile Offline-Katalogdateien ohne VFS-Zeile werden
nur als FILE_NOT_ONLINE-Issue geführt und nicht zusätzlich in die auf
Nativezeilen bezogenen Partitionzähler aufgenommen. Nur erwartete online
ROWS-/LOG-Dateien ohne native Zeile erzeugen NATIVE_FILE_UNAVAILABLE.

RawSampleCount=7*N, CandidateSampleCount=6*C und die beiden übrigen Mengen=N.
Das globale Kontextsample wird bei der Run-Gesamtsumme zusätzlich gezählt.
Tatsächliche MetricDefinition-IDs, Typen, Einheiten, Scope-/Epochbezug und
Rohhash müssen passen. Ein geänderter Rohwert mit unveränderter Zeilenanzahl
ist weiterhin ungültige Vorwertevidenz. Ein erhaltenes Tombstone ohne Kinder
erlaubt keine Zahlen. Frühere Kandidatenwerte ersetzen keine Rohbasis.

Beide StringValue-Kontexte müssen einschließlich JSON-Escaping innerhalb
von 4000 UTF-16-Codeeinheiten liegen. Native Namen werden deshalb nicht im
globalen Kontext dupliziert. Grenzfälle mit maximalen Namen und Escaping
gehören zur Abnahme. Ein Überlauf darf weder still truncieren noch ein
scheinbar gültiges teilweise gespeichertes Kontextdokument erzeugen.

## Dauerhafte Quellfehler und Qualitätscodes

PayloadEnabled=0 darf einzelne Quellenfehler nicht verschwinden lassen.
Jeder gültige Issue erzeugt atomar zwei ModuleStatus-Zeilen. Die erste trägt
SourceName als ModuleName, unveränderten StatusCode, ErrorNumber und
ErrorMessage sowie den vollständigen EvidenceLimit-String innerhalb seines
1000er-Limits. Beide Issuezeilen tragen IsPartial=1. Der tatsächlich erzeugte
ModuleStatusId der ersten Zeile wird gebunden.
Die zweite trägt ModuleName=FileIOSourceIssueContext, denselben Status und
IsPartial=1, aber ErrorNumber=NULL. Ihr ErrorMessage-Feld enthält exakt das
kanonische JSON-Objekt sourceModuleStatusId als Dezimalstring, ScopeType als
String, DatabaseId und FileId als Zahl/null, DatabaseName als String/null
und StatusCode als String in dieser Reihenfolge. Der tatsächliche native
Meldungstext wird dafür nicht verkürzt. Das Entityobjekt passt mit den
festgelegten nativen Namenslimits in 2048 UTF-16-Codeeinheiten; Grenzfälle
mit Escaping werden geprüft. Es ist eine Diagnoseprojektion, kein erfundener
zusätzlicher nativer Fehler.

Zusätzlich wird genau eine Summaryzeile mit ModuleName=FileIOCollector
persistiert. Ihre Fehlernummer ist null; CaptureRun und OUTPUT behalten die
erste tatsächliche Fehlernummer gemäß Source-Issue-Reihenfolge. Ohne Issue
wird kein Fehler erfunden. Bei J Issues bestehen damit 1+2*J Modulzeilen.
MaxRows begrenzt Datei-Metrics und weder Issues noch deren Persistenz.
Bei fatalem Sourcefehler bleiben diese Modulzeilen erhalten, obwohl keine
Metrics geschrieben werden. Bei einem ungültigen Sourcevertrag wird ein
kontrollierter SOURCE_CONTRACT-Issue anstelle nicht validierter Daten erzeugt.

Source-meta, CaptureRun und OUTPUT verwenden die erste nicht NULL
Issue-Fehlernummer und den Meldungstext derselben Issuezeile. Ohne eine
solche Nummer bleibt ErrorNumber NULL; ein vorhandener diagnostischer
Meldungstext der ersten Issue bleibt erhalten. Ohne Issues bleiben beide
Fehlerfelder NULL. CollectionTimeUtc ist das gültige Messende oder bei
fehlender Zeitbindung die tatsächliche UTC-Fehleraufzeichnung. Die Summary
trägt den ehrlichen Runstatus mit IsPartial=1. NativeRead-/Issuefehler werden
nicht durch einen erfundenen zweiten SQL-Fehler ersetzt.


IO_DELTA_STATUS verwendet QualityCode=COMPARISON_STATUS, IO_FILE_CONTEXT
verwendet FILE_IO_CONTEXT und IO_CAPTURE_CONTEXT verwendet CAPTURE_CONTEXT.
Alle drei tragen IsPartial=1. Die übrigen festen Qualitäten sind
NATIVE_CUMULATIVE, NATIVE_GAUGE und MONOTONIC_CONTINUITY_UNPROVEN nach den
bereits beschriebenen Regeln; freie Qualitätsliterale werden nicht eingeführt.

## Vorwertsuche und Vergleichspriorität

Die Vorwertsuche betrachtet ausschließlich den unmittelbar vorherigen
finalisierten FILE_IO-Run. Ihr reiner Suchschlüssel ist DatabaseId+FileId
aus den dort tatsächlich geschriebenen Dateikontexten und ihren gebundenen
Scope-Identitäten. Dieser Schlüssel beweist weder dieselbe Datenbank noch
dieselbe Dateigeneration. Es muss genau ein Treffer vorliegen. Kein Treffer
bedeutet PREVIOUS_FILE_UNAVAILABLE, mehrere Treffer bedeuten
PREVIOUS_FILE_CONTEXT_INVALID. Erst nach dieser eindeutigen Suche werden
vollständige Kontext-/Roh-/Epochenbindung, beobachtete Generation und Handle
getrennt geprüft. Die Suche nach aktueller ScopeId oder aktuellem vollständigem
Identitätshash ist ausdrücklich kein Ersatz: Sonst würden Generations- und
Handlewechsel vorzeitig als fehlender Vorwert verborgen. Ein älterer Run
wird auch bei fehlendem oder fehlerhaftem Treffer nicht herangezogen.

Ein fataler Sourcefehler finalisiert seinen Run ohne numerische Samples.
Für gültige geschriebene Dateien gewinnt die erste zutreffende Grenze:

1. Aktuelle Quellenpartialität unterdrückt alle Kandidaten dieses Captures.
2. Fehlende oder widersprüchliche aktuelle Identität erzeugt eine neue Beobachtungsepoche.
3. Ein fehlender vorheriger finalisierter FILE_IO-Lauf ist keine Baseline.
4. Ein unmittelbar vorheriger Fehlerlauf wird nicht übersprungen.
5. Fehlender, ungültiger oder roh-/mengenmäßig nicht gebundener globaler Kontext verhindert den Vergleich.
6. Vorherige Quellenpartialität oder eine andere tatsächliche Auswahl verhindert den Vergleich.
7. Ein fehlender vorheriger geschriebener Dateikontext wird nicht mit älteren Dateien ersetzt.
8. Ungültiger Dateikontext, Rohhash, Scope- oder Epochenbezug verhindert Zahlen.
9. Eine andere beobachtete Engine-/Datenbank-/Dateigeneration oder ein anderer Handle bricht die Basis.
10. Eine rückläufige native Uptime-Beobachtung bricht die Basis.
11. Ein nicht positives Fenster zwischen vorherigem Messende und aktuellem Messbeginn unterdrückt Zahlen.
12. Ein fallender kumulativer Counter bricht die gesamte Dateibasis.
13. Andernfalls entstehen sechs nichtnegative MONOTONIC_CONTINUITY_UNPROVEN-Kandidaten mit IsPartial=1.

Die Statuscodes in dieser Priorität lauten SOURCE_PARTIAL,
CURRENT_IDENTITY_INCOMPLETE, NO_PREVIOUS_CAPTURE, PREVIOUS_CAPTURE_FAILED,
PREVIOUS_CAPTURE_CONTEXT_INVALID, PREVIOUS_SOURCE_PARTIAL, SELECTION_CHANGED,
PREVIOUS_FILE_UNAVAILABLE, PREVIOUS_FILE_CONTEXT_INVALID,
PREVIOUS_RAW_INCOMPLETE, OBSERVED_IDENTITY_CHANGED, FILE_HANDLE_CHANGED,
UPTIME_DECREASED, NONPOSITIVE_INTERVAL, COUNTER_DECREASED und
MONOTONIC_CONTINUITY_UNPROVEN. Bei Identitätsvergleich wird zunächst die
Bindung ohne Handle geprüft, danach der Handle separat. Namenslabels
entscheiden dabei nicht über Identitätsgleichheit. Die Epochenentscheidung besitzt eine eigene eindeutige Priorität: aktuelle
Identität unvollständig bedeutet NEW_UNBOUND_OBSERVATION; danach bedeutet
gültiger monotoner Vergleich RETAIN_OBSERVED_EPOCH; danach bedeutet fehlender
Vorläufer bei SourceComplete=true NEW_BASELINE; alle übrigen Fälle bedeuten
NEW_COMPARISON_BREAK. Sourcepartialität ohne Vorläufer erzeugt somit keine
scheinbar gültige Baseline. Die allgemeine vorherige Kurzbeschreibung wird
ausschließlich in dieser Reihenfolge angewandt.

Veränderte Namen sind keine alleinige Identitätsbegründung. Ein verborgener
Reset mit anschließendem Wiederanstieg kann bei identischen Beobachtungen
unerkannt bleiben; auch dann werden Kandidaten nie als bewiesene Deltas
ausgegeben. Der Gesamtstatus eines erfolgreichen Captures bleibt PARTIAL.

## Bekannte Migration und tatsächliche Aufnahmeprüfung

| Stand | Geplante Behandlung |
|---|---|
| 1.0.0 / Schema 1 | Nur exakt bekannte Altstruktur datenbewahrend nach Schema 3 migrieren. |
| 1.1.0, 1.1.1, 1.2.0, 1.2.1 / Schema 2 | Nur exakt bekannte Strukturen und Eigentümerschaft migrieren. |
| 1.2.2 / Schema 3 | Bekanntes unvollständiges eigenes Stadium; keine FILE_IO-/neue Waitaufnahme. |
| 1.3.0 / Schema 3 | Vollständig installiert und wiederholbar, sofern tatsächliche Verträge passen. |
| Andere Version, gemischte Domäne oder unbekannte Facette | Vor Produktwrites abbrechen; keine automatische Reparatur. |

CollectorPolicy erhält zusätzlich FILE_IO, ScopeType zusätzlich FILE_IO_FILE.
Tabelleninhalte, Identitäten, eigene Policies, Counter-/Waitdaten und fremde
Objekte bleiben erhalten. Die bekannten Constraintänderungen und ihre
Vorzustände gehören in denselben verlustfreien Installationsvertrag.

030 markiert Schema 3 nur als 1.2.2. Die bisherige Waitclosure 075 ergänzt
und prüft weiterhin ihre neun Seeds und verwendeten Verträge, finalisiert
dieses Stadium aber nicht zu einem scheinbar fertigen alten Waittarget.
Ein neuer letzter Abschluss prüft alle benötigten Helper, typisierten
Signaturen, Wait-/Datei-I/O-Seeds und den tatsächlichen Retentionsvertrag 2;
erst danach markiert er 1.3.0. Standalone-/Gesamtinstaller behalten ihre
äußere atomare Transaktion; SQLCMD-Recovery erkennt ausschließlich bekannte
eigene Zwischenstände.

Der aus dem veröffentlichten 1.2.1-Quellstand berechnete Stored-Sollhash lautet
aeb295d67a15ce0fcf452404dde233729012e42340c138c8924f27447e1b8762
und wird vor der Recoveryabnahme nativ bestätigt. Die bereits qualifizierte 1.2.0-Bindung bleibt bei den dafür
vorgesehenen Recoverywegen erhalten. Grundlage ist ausschließlich die
vorhandene kanonische Stored-Header-Normalisierung. Fremde neue Helpernamen
unter älteren Paketmarkern werden nicht pauschal als eigene Recovery akzeptiert.

Das neue Framework muss vollständiges 1.2.1 / Schema 2 mit tatsächlichem
Retentionsvertrag 1 weiterhin für Waits unterstützen. 1.3.0 / Schema 3
verlangt Retentionsvertrag 2. FILE_IO ist ausschließlich am neuen vollständigen
Stand zulässig. Der Target-Backend-Schritt liefert diese notwendige
Framework-Waitkompatibilität mit; die öffentliche FILE_IO-Welle folgt danach.
Beim getrennten Rollout wird zuerst das kompatible Framework aktualisiert.
Ein altes Framework kennt einen künftigen Targetmarker nicht; eine umgekehrte
Reihenfolge darf deshalb nicht als unterbrechungsfrei behauptet werden.

Der neue Retentionsvertrag erhält ausschließlich für WAIT_STATS und FILE_IO
jeweils die größte finalisierte Capture-ID als Tombstone, einschließlich
Fehlern. PERFORMANCE_COUNTERS behält seinen bisherigen Löschpfad. Er überspringt keine
Fehlerbasis und lässt Kinder normal ablaufen. ContractOnly bleibt schreibfrei
mit null Run-ID und ohne Budgetaktion. Der gemeinsame Sessionlock und die
bereits geprüfte explizite Besitzertransaktion werden nicht durch lange
Transaktionen um Sourcequeries ersetzt.

## Review und spätere Abnahme

Der unabhängige Review und die gezielte Nachprüfung des gebündelten
Korrekturstands sind abgeschlossen. Es bestehen keine offenen P1/P2 im
Feld- und Migrationsvertrag; Produktcode und native Abnahme sind nicht
dadurch ersetzt. Aus einem noch offenen materiellen Vertragsbefund wird keine
scheinbar ausführbare Produktwelle abgeleitet. Der bestehende autonome
Benutzerauftrag erlaubt die folgende kohärente Umsetzung nach diesem Review;
eine zusätzliche Freigabe wird durch den Dokumententwurf nicht erfunden.

Die spätere Abnahme umfasst echte bekannte Upgrades über alle drei
Installationswege, unterbrochene Recovery, Fremdobjekt-/Seedkonflikte,
Erhaltung alter Waitziele, unabhängige native Dateimengen-/Wertgrenzen,
fehlende Identität, beobachtete Wechsel, Gauge-Rückgang, Counterrückgang,
verborgenen Reset als weiterhin unbewiesen, Auswahl-/Vorwert-/Retentions-
und Outputfehler. Hier wird kein solcher Lauf als ausgeführt dargestellt.
