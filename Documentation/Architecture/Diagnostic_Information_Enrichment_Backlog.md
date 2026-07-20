# Zukunftsvertrag für zusätzliche Diagnoseinformationen

Stand: 2026-07-20
Status: `BACKLOG_RESEARCHED_NOT_IMPLEMENTED`
Backlog: `DIAG-001` bis `DIAG-007`

## Ziel

Dieser Vertrag bündelt zukünftige Erweiterungen für Serverversions-, Build-,
Statement-, Parameter-, Plan- und Laufzeitinformationen. Er ist ein
verbindlicher To-do-Rahmen, aber noch kein Implementierungsauftrag. Neue
Informationen müssen in den frameworkweiten Datenbank-, CONSOLE-, RAW-, JSON-
und benannten TABLE-Vertrag integriert werden, ohne Quellen mehrfach zu lesen.

Der bestehende Kern liefert bereits viele Einzelinformationen. Insbesondere
`USP_CurrentRequests`, `USP_QueryStats`, `USP_PlanDetails`,
`USP_ShowplanAnalysis`, die Query-Store-Module,
`USP_ServerFeatureCapabilities` und `USP_OSInformation` sind vor einer
Implementierung als vorhandene Quellen und mögliche Materialisierungs-Owner zu
prüfen. Neue Procedures dürfen diese Quellen in einem Overview- oder
Exportaufruf nicht erneut lesen.

## DIAG-001: Serverversion, Build, CU und Lifecycle

Eine leichte Procedure, Arbeitstitel `monitor.USP_ServerVersionInformation`,
soll ohne High-Impact-Gate die technische Instanzversion und eine offline
reproduzierbare Buildbewertung liefern.

### Direkt aus der Instanz

- `ProductVersion`, `ProductMajorVersion`, `ProductMinorVersion` und
  `ProductBuild`;
- `ProductLevel`, `ProductUpdateLevel`, `ProductUpdateReference` und
  `ProductBuildType`;
- `ResourceVersion`, `ResourceLastUpdateDateTime` und `BuildClrVersion`;
- `Edition`, `EditionID`, `EngineEdition` und abgeleitete Engineklasse;
- Plattform, Distribution, OS-Release, OS-SKU und OS-LCID;
- SQL-Server-Startzeit, Uptime, Prozess-ID und letzter sichtbarer Dienststart;
- `IsClustered`, `IsHadrEnabled`, `HadrManagerStatus`, `IsLocalDB` und
  relevante installierte Featureflags;
- Server- und `tempdb`-Collation sowie optional der Compatibility-Level-Kontext
  sichtbarer Datenbanken.

`LicenseType` und `NumLicenses` werden nicht als Lizenznachweis verwendet, weil
SQL Server diese Eigenschaften nicht belastbar pflegt. Identitäts- und
Pfadwerte wie Server-, Host-, Instanz-, Dienstkonto-, Backup-, Daten- und
Logpfade gehören nicht in die normale CONSOLE-Projektion; eine technisch
begründete RAW-Ausgabe bleibt getrennt zu entscheiden.

### Offline-Buildkatalog

Ein versionierter Frameworkkatalog soll mindestens enthalten:

- vollständige Engine-Buildnummer;
- Major Version und Releasebezeichnung, beispielsweise `CU26`;
- Servicing-Zweig `RTM`, `CU`, `GDR`, `CU_GDR` oder `OD`;
- KB-Nummer, Veröffentlichungsdatum und Plattformscope;
- Kennzeichnung eines Security-Releases, soweit durch die Primärquelle belegt;
- stabile Microsoft-Buildübersicht und konkrete KB-URL;
- Katalogstand, Primärquelle und Quellabrufdatum;
- je Servicing-Zweig den neuesten im Katalog bekannten Build.

Die Procedure darf vollständig offline `EXACT_MATCH`, `UNKNOWN_BUILD`,
`BUILD_NEWER_THAN_OFFLINE_CATALOG`, `OLDER_KNOWN_BUILD`, `CATALOG_STALE`,
`PREVIEW_BUILD`, `ON_DEMAND_BUILD` oder `SERVICING_BRANCH_AMBIGUOUS` melden.
Eine unbekannte oder höhere Buildnummer ist niemals automatisch veraltet. Eine
CU-Differenz darf nur innerhalb eines eindeutig bestimmten, vergleichbaren
Servicing-Zweigs berechnet werden.

Stabile Buildübersichten können anhand der Major Version offline zugeordnet
werden. Das Öffnen der URL benötigt Internet, ihre Erzeugung nicht:

- SQL Server 2019: `https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2019/build-versions`
- SQL Server 2022: `https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2022/build-versions`
- SQL Server 2025: `https://learn.microsoft.com/en-us/troubleshoot/sql/releases/sqlserver-2025/build-versions`
- versionsübergreifend: `https://learn.microsoft.com/en-us/troubleshoot/sql/releases/download-and-install-latest-updates`

Zusätzlich soll ein kleiner Offline-Lifecycle-Katalog Veröffentlichungsdatum,
Ende von Mainstream und Extended Support, Katalogstand und offizielle
Lifecycle-URL enthalten. Eine Buildnummer allein beweist weder vollständige
Security-Patches noch Verwundbarkeit, ausstehenden Neustart oder betriebliche
Freigabe der neuesten CU.

Vorgesehene benannte Resultsets:

- `serverVersion`;
- `buildAssessment`;
- `lifecycle`;
- `instanceFeatures`;
- `databaseCompatibility`;
- `references`;
- `warnings`.

## DIAG-002: Native strukturierte Datentypen erhalten

XML-Daten müssen als SQL-Datentyp `xml` materialisiert und ausgegeben werden,
wenn die Quelle valides XML liefert. Dies gilt insbesondere für Showplan XML,
Deadlockgraphen und Extended-Events-XML. In SSMS bleibt ein Showplan dadurch
direkt anklickbar und kann grafisch geöffnet werden.

Verbindliche Regeln:

1. Liefert die Systemquelle bereits `xml`, wird nicht zuerst nach
   `nvarchar(max)` konvertiert.
2. Liefert eine Quelle XML als Text, wird das ungekürzte Original kontrolliert
   in `xml` konvertiert. `TRY_CAST` beziehungsweise `TRY_CONVERT` ist nur dort
   zulässig, wo Datentyp und Länge dies zuverlässig erlauben. Insbesondere ist
   die dokumentierte `TRY_CAST`-Grenze für `nvarchar(max)` oberhalb von 4.000
   und `varchar(max)` oberhalb von 8.000 Zeichen zu berücksichtigen.
3. Ein Parsefehler erzeugt `XML_INVALID`, ein Quell- oder XML-Tiefenlimit
   `XML_UNAVAILABLE_LIMIT`; beides bleibt von einem tatsächlichen leeren XML
   unterscheidbar.
4. Bei nicht als `xml` lieferbaren, zu tief verschachtelten oder nur textuell
   verfügbaren Plänen darf ein separates Textfallback erhalten bleiben. Das
   primäre Planfeld bleibt typisiert und wird nicht stillschweigend durch Text
   ersetzt.
5. Plantext wird nicht vor der XML-Konvertierung gekürzt. Größenbegrenzungen
   wählen ganze Pläne beziehungsweise Zeilen aus und markieren ausgelassene
   Ergebnisse.
6. Showplan-Namespace, Rootstruktur und Encoding werden nicht verändert.
7. TABLE-Ziele erhalten eine echte `xml`-Spalte. Das Resultsetinventar muss den
   Typ ausweisen und der TABLE-Writer muss ihn unverändert übernehmen.
8. JSON kann XML technisch nur als String transportieren. Der JSON-Vertrag
   kennzeichnet deshalb Format und Encoding; er ersetzt nicht den nativen XML-
   Vertrag von RAW, CONSOLE und TABLE.
9. CONSOLE zeigt einen Plan nur in einer fachlich passenden Detailstufe. Eine
   große XML-Spalte darf das normale Ein-Grid-Ziel nicht unkontrolliert
   verdrängen.

Frameworkweit zu prüfen sind mindestens Query-Store-Pläne, die derzeit teils
als `nvarchar(max)` materialisiert werden, Plan-Cache-Pläne, Live-/Last-Actual-
Pläne, Deadlock-XML und Extended-Events-Eventdaten.

## DIAG-003: Parameter- und Variablenwerte

SQL Server stellt keine allgemeine DMV bereit, über die zu einem fremden
laufenden Statement sämtliche aktuellen lokalen T-SQL-Variablenwerte gelesen
werden können. Das Framework darf daher nie behaupten, eine vollständige
Variablenliste zu liefern.

Folgende Evidenzquellen sind getrennt nutzbar:

| Quelle | Mögliche Information | Grenze |
|---|---|---|
| Input Buffer | übermittelter Batch beziehungsweise RPC-Text und Parameteranzahl; Literale oder Aufrufwerte können im Text stehen | kein strukturiertes, vollständiges Abbild lokaler Variablen |
| kompiliertes Showplan XML | Parametername, Datentyp und `ParameterCompiledValue` | Kompilierwert ist nicht der aktuelle Laufzeitwert |
| Live-/Actual-Showplan | falls vorhanden `ParameterRuntimeValue` | abhängig von Build, Profiling und Konfiguration; fehlend bedeutet unbekannt |
| Last Actual Plan | letzter bekannter tatsächlicher Plan und Runtimeoperatorwerte | opt-in `LAST_QUERY_PLAN_STATS`, nicht zwingend aktueller Aufruf |
| Extended Events | RPC-/Batch-/Statement- und Actual-Plan-Evidenz je Eventkonfiguration | zeitlich begrenzt, potenziell teuer und inhaltsreich |
| Query Store | Querytext, Plan und aggregierte Runtimewerte | keine vollständige Liste der Parameterwerte je Ausführung |

`USP_ShowplanAnalysis` extrahiert bereits `ParameterCompiledValue` und
`ParameterRuntimeValue`. Dieser Bestand ist zu einem stabil benannten,
TABLE-exportierbaren `parameters`-Resultset auszubauen. Jede Zeile benötigt
mindestens:

- Candidate-, Session-, Request-, Query- und Planbezug, soweit verfügbar;
- Parametername und deklarierter Datentyp;
- `CompiledValue` und `RuntimeValue` getrennt;
- `ValueSource`, beispielsweise `COMPILE_PLAN`, `LIVE_PLAN`,
  `LAST_ACTUAL_PLAN`, `INPUT_BUFFER` oder `EXTENDED_EVENT`;
- `ValueCapturedAtUtc` beziehungsweise Quellzeit;
- `IsCurrentExecution`, `IsLastKnownExecution` und `IsComplete`;
- `ValueStatus`, etwa `AVAILABLE`, `NOT_COLLECTED`,
  `UNAVAILABLE_CONFIGURATION`, `UNAVAILABLE_BUILD`, `PLAN_EVICTED`,
  `REQUEST_FINISHED` oder `LOCAL_VARIABLE_NOT_EXPOSED`.

Ein fehlendes `ParameterRuntimeValue` ist unbekannte Evidenz und niemals der
Nachweis eines SQL-`NULL`-Werts. Werte aus Input-Buffer-Text dürfen nur als
Textquelle ausgewiesen und nicht durch heuristisches Parsing als vollständig
behauptet werden. Lokale Variablen können höchstens indirekt in eingebetteten
Prädikaten, recompile-bedingten Plänen oder über externe Instrumentierung
sichtbar werden; diese Fälle bleiben ausdrücklich inferenziell.

Das Framework aktiviert weder Traceflag 2446 noch
`FORCE_SHOWPLAN_RUNTIME_PARAMETER_COLLECTION`, `LAST_QUERY_PLAN_STATS` oder
eine Extended-Events-Session automatisch. Solche Pfade benötigen explizite
Aktivierung, Kostenstatus und – bei breiter oder fortlaufender Erfassung – das
High-Impact-Gate. Parameterwerte können Zugangsdaten, Tokens, personenbezogene
Werte oder Geschäftsdaten enthalten. Die Runtime-Ausgabe wird nicht heimlich
maskiert; Persistenz, Export in Artefakte oder Git und externe Weitergabe
unterliegen jedoch dem Repository-Datenschutzvertrag.

## DIAG-004: Statement- und Requestkontext

Vorhandene Materialisierungen sind um eine einheitliche, quellenbezogene Sicht
zu konsolidieren. Sinnvolle Informationen sind:

- aktuelles Statement und vollständiger Batch mit gültigen Byte- und
  Zeichenoffsets, Zeilenbereich, Länge und Trunkierungsstatus;
- Modul-, Datenbank-, Schema- und Objektbezug ohne blockierende
  `OBJECT_NAME()`-/`OBJECT_ID()`-Auflösung;
- Input-Buffer-Typ, Parameteranzahl und ungekürzter beziehungsweise bewusst
  begrenzter Inputtext;
- Session-, Request-, Connection-, Task-, Scheduler- und Execution-Context;
- Startzeit, Dauer, CPU, Reads, Writes, Logical Reads, Row Count,
  Percent Complete und geschätzte Restzeit;
- Wait, Blocking, offene Transaktion, Isolation Level und Waitresource;
- Memory Grant, tatsächliche Nutzung, Idealwert, Spill- und TempDB-Evidenz;
- DOP, Parallel Worker, Workload Group und Resource Pool;
- Query Hash, Plan Hash, SQL Handle, Plan Handle und Statement SQL Handle;
- Plan-Generation, Compile-/Recompile-Zeitpunkt und Cachealter;
- Verbindungsprotokoll, Transport, Verschlüsselung und Authentisierung;
- Client-, Host-, Programm- und Loginangaben nur in fachlich begründeten
  Detail- beziehungsweise RAW-Pfaden.

Die Informationen müssen innerhalb eines Aufrufs aus demselben Snapshot
stammen oder ihren abweichenden Erfassungszeitpunkt ausweisen. Ein Join auf
später erneut gelesene DMVs darf keine scheinbar atomare Sicht vortäuschen.

## DIAG-005: Plan-, Query-Store- und Optimizerkontext

Neben dem anklickbaren XML sind folgende Informationen sinnvoll:

- Planquelle: Compile, Live, Last Actual, Query Store oder Extended Event;
- Optimization Level, Early Abort Reason, Cardinality Estimation Model,
  Statement- und Subtree-Cost;
- geschätzte und tatsächliche Zeilen, Rows Read, Ausführungen und Abweichung;
- Memory Grant, Grant Wait, Max Used Memory, Spilltypen und Spillvolumen;
- Parallelität, tatsächlicher DOP, Worker, Skew und Exchange-Waits;
- verwendete Objekte, Indizes und Statistiken einschließlich
  Aktualitäts-/Samplingevidenz;
- Missing-Index-Hinweise mit der bestehenden False-Positive-Grenze;
- implizite Konvertierungen, Planwarnungen, residuale Prädikate, Row Goals,
  Sort-/Hashwarnungen und nicht parallele Gründe;
- Adaptive Join, Batch Mode, Memory Grant Feedback, DOP Feedback,
  Cardinality Feedback, PSP- und OPPO-Varianten;
- Query-Store-Query-/Plan-ID, Force-/Hintstatus, Forcefehler,
  Regressions- und Planwechselkontext;
- Cacheobjekttyp, Use Count, Plangröße, Set Options, Compile User und weitere
  dokumentierte Planattribute;
- Vergleich von Compile- und Runtimeparametern als mögliche
  Parameter-Sensitivitätsevidenz, niemals als alleiniger Ursachenbeweis.

Teure XML-, Plan-Cache-, Live-Plan-, Last-Actual- und Extended-Events-Pfade
bleiben gezielt, begrenzt und laufintern wiederverwendet. Microsoft weist für
breit aktiviertes `query_post_execution_showplan` auf relevanten Overhead hin;
dieser Pfad ist nur ad hoc mit restriktiven Prädikaten zulässig.

## DIAG-006: Provenienz, Zeitbezug und Evidenzgrenzen

Jede neue Information benötigt, soweit fachlich relevant:

- `SourceType` und konkretes Quellobjekt;
- `CapturedAtUtc` sowie gegebenenfalls Compile-, Start-, Last-Execution- oder
  Intervallzeit;
- Scope und Granularität;
- `IsCurrent`, `IsLastKnown`, `IsCumulative` oder `IsAggregated`;
- `StatusCode`, Partialität und Fehler-/Auslassungsgrund;
- Berechtigungs-, Versions-, Plattform-, Konfigurations- und Cachegrenze;
- Trunkierungs-, Zeilenlimit- und Payloadstatus;
- Hinweis, ob der Wert direkt gemessen, aus XML gelesen oder inferiert wurde.

Freitext `NULL` reicht nicht aus, um nicht vorhanden, nicht erhoben, nicht
berechtigt, nicht unterstützt, evictet, zu groß, zu tief oder ungültig zu
unterscheiden.

## DIAG-007: Ausgabe-, Inventar- und Testvertrag

Vor einer Umsetzung werden alle neuen Resultsets semantisch benannt und in
`Metadata/Inventory/ResultSets.csv` mit stabilen Schemas erfasst. TABLE-Ziele
werden vor Systemzugriffen validiert. Alle Exporte verwenden ausschließlich die
im selben Aufruf materialisierten Daten.

Erforderliche Tests auf SQL Server 2019, 2022 und 2025:

- native XML-Spalte ist in RAW und TABLE tatsächlich `xml` und in SSMS als
  Showplan verwendbar;
- valides, ungültiges, leeres, sehr großes und zu tiefes XML bleiben
  unterscheidbar;
- Query-Store-Plantext wird ohne vorherige Kürzung kontrolliert konvertiert;
- Compilewert, Runtimewert, fehlende Erfassung und echter SQL-`NULL` bleiben
  semantisch getrennt;
- lokaler Variablenwert wird nicht erfunden;
- Input Buffer, Request, Plan und Query Store behalten eigenen Zeitbezug;
- Requestende und Cache-Eviction erzeugen partielle, nicht falsche Ergebnisse;
- eingeschränkte Berechtigungen deaktivieren nur das betroffene Teilresultset;
- Plan- und Parameterquellen werden pro Aufruf höchstens einmal gelesen;
- High-Impact-Abbruch erfolgt vor dem teuren Zugriff;
- CONSOLE bleibt kompakt, RAW vollständig und TABLE/JSON schemafest;
- Datenschutz-, Nonblocking-, Dokumentations- und Commit-Gates bleiben grün.

## Offizielle Primärquellen

- `SERVERPROPERTY`: https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql?view=sql-server-ver17
- aktuelle SQL-Server-Builds: https://learn.microsoft.com/en-us/troubleshoot/sql/releases/download-and-install-latest-updates
- Live-Showplan: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-query-statistics-xml-transact-sql?view=sql-server-ver17
- Last Actual Plan: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-query-plan-stats-transact-sql?view=sql-server-ver17
- Input Buffer: https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-input-buffer-transact-sql?view=sql-server-ver17
- `TRY_CAST`: https://learn.microsoft.com/en-us/sql/t-sql/functions/try-cast-transact-sql?view=sql-server-ver17
- Extended-Events-Actual-Showplan: https://learn.microsoft.com/en-us/shows/sql-workshops/extended-event-query-post-execution-showplan-in-sql-server

## Empfohlene Umsetzungsreihenfolge

1. `DIAG-002`: frameworkweites XML-Typaudit und Korrektur der verlustbehafteten
   `nvarchar(max)`-Planpfade.
2. `DIAG-001`: leichte Serverversions-Procedure und versionierter
   Offline-Build-/Lifecycle-Katalog.
3. `DIAG-003`: vorhandene Parameterextraktion mit stabiler Provenienz und
   TABLE-Vertrag ausbauen.
4. `DIAG-004`: Statement-/Requestkontext ohne erneute DMV-Lesung konsolidieren.
5. `DIAG-005`: zusätzliche Plan-/Optimizerinformationen priorisiert ergänzen.
6. `DIAG-006` und `DIAG-007`: Provenienz-, Inventar- und Testvertrag in jeder
   vertikalen Umsetzung gleichzeitig abschließen.
