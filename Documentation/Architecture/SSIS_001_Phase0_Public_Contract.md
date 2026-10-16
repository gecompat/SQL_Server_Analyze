# SSIS-001 Phase 0 – öffentlicher Vertrag

Status: Vertragsphase abgeschlossen; der direkte DTSX-v2-Kern ist teilweise implementiert.

## Öffentliche Procedures und Resultsets

| Procedure | Resultsetreihenfolge | Schemaversion |
|---|---|---|
| `USP_SsisPackageAnalysis` | `moduleStatus`, `package`, `executables`, `controlFlowConstraints`, `dataFlowComponents`, `connections`, `parameters`, `expressions`, `lineage`, `findings`, `sourceStatus`, `warnings`, `variables` | `3` |
| `USP_SsisLegacyLogAnalysis` | `moduleStatus`, `execution`, `timeline`, `errorChain`, `iterations`, `loggingQuality`, `findings`, `sourceStatus`, `warnings` | `1` |
| `USP_SsisCatalogExecutionAnalysis` | `moduleStatus`, `execution`, `executables`, `messages`, `parameters`, `phases`, `rowFlow`, `findings`, `sourceStatus`, `warnings` | `1` |

Alle drei Procedures erhalten den vorhandenen Frameworkvertrag für
`CONSOLE|RAW|TABLE|NONE`, JSON, `@Hilfe`, Status-OUTPUT-Parameter,
`@MaxZeilen`, `@MaxDurationSeconds` und `@LockTimeoutMs`. `TABLE` verwendet
benannte Ziele aus `@ResultTablesJson`; Schemaänderungen erhöhen die jeweilige
Schemaversion.

## Festgelegte Entscheidungen

1. Der erste Parser unterstützt ausschließlich DTSX Version 2. Andere gültige
   XML-Formate liefern `UNSUPPORTED_PACKAGE_FORMAT`, keine heuristische
   Vollanalyse.
2. Der direkte Kern inventarisiert Property-Expressions ausschließlich über
   Scope und Eigenschaftsname. Expressiontexte werden weder gelesen noch
   aufgelöst. Eine spätere Auflösung direkter Literal-, Variablen- und
   Parameterreferenzen sowie die Kennzeichnung komplexer Ausdrücke als
   `EXPRESSION_NOT_EVALUATED` benötigt einen eigenen Parser-Slice.
3. Komponentenprofile besitzen `componentCode`, `componentKind`,
   `implementationOwner`, `synchronousKind`, `knownInputs`, `knownOutputs`,
   `riskTags` und `profileVersion`. Unbekannte Komponenten bleiben als
   `UNKNOWN_COMPONENT` im Inventar.
4. Verbindliche Quellenstatus sind `AVAILABLE`, `AVAILABLE_EMPTY`,
   `AVAILABLE_LIMITED`, `SOURCE_UNAVAILABLE`, `UNAVAILABLE_PLATFORM`,
   `UNSUPPORTED_PACKAGE_FORMAT`, `ENCRYPTED_CONTENT`, `UNKNOWN_COMPONENT`,
   `PARTIAL_LINEAGE`, `EXPRESSION_NOT_EVALUATED`, `TRUNCATED` und
   `INVALID_PARAMETER`.
5. Optionale Lookup-Datenprüfung ist `HIGH_IMPACT`, standardmäßig aus und
   benötigt `@ResolveSqlMetadata = 1`, `@CheckLookupData = 1` sowie
   `@HighImpactConfirmed = 1`. Maximal 10 Lookups, 10.000 Schlüsselzeilen je
   Lookup und 30 Sekunden Gesamtbudget sind erlaubt.
6. Standardausgaben enthalten keine Operator-, Computer-, Login-, Host-,
   vollständigen Pfad-, Secret-, Connection-String- oder Binärwerte.
   Laufzeitidentitäten benötigen einen separaten Datenschutz-Opt-in.
7. Der eigenständige Kerninstaller wird
   `Code/Install/Install_SSIS_Analysis.sql`; sein Abhängigkeitsinventar wird
   `Metadata/Packages/SSIS_001_Dependencies.csv`. Der Gesamtinstaller bindet
   dieselben kanonischen Quelldateien ein.
8. Datei- und ISPAC-Adapter gehören nicht zum Kerninstaller. Ein späterer
   Dateiadapter erhält ein eigenes Paket und eine explizite Dateisystemfreigabe.
   ISPAC-Extraktion erfolgt zunächst ausschließlich außerhalb von T-SQL; eine
   spätere SQLCLR-Lösung benötigt einen eigenen Security-Vertrag.

## Variableninventar in Schema v3

Schema v3 ergänzt `variables` als dreizehntes RAW-Resultset nach `warnings`.
Die ersten zwölf Resultsetnamen, Reihenfolge und Spaltenschemas bleiben
erhalten. JSON enthält das Array `variables`; TABLE akzeptiert das gleichnamige
Ziel in `@ResultTablesJson`. Bestehende Aufrufe wechseln unmittelbar auf v3;
eine Auswahl des bisherigen Schemas wird nicht angeboten.

Eine Zeile beschreibt eine direkt unter `DTS:Variables` definierte Variable
im Paket, Container oder Task. `ScopeExecutableOrdinal` verweist auf die
`ExecutableOrdinal` derselben vollständigen Analyse. Namen sind keine
Identität; gleichnamige Variablen in unterschiedlichen Scopes bleiben getrennt.
Ordinals sind innerhalb des Aufrufs gültig und keine dauerhaften Paketkennungen.
Das Inventar erzeugt keine zusätzlichen Systemvariablen.

| Spalte | SQL-Typ | Bedeutung |
|---|---|---|
| `VariableOrdinal` | `int NOT NULL` | Die Nummer bezeichnet eine Zeile im nach Scopeordinal, Namespace und Namen geordneten Inventar. |
| `ScopeExecutableOrdinal` | `int NOT NULL` | Die Nummer ordnet die Definition einem erfassten Executable zu. |
| `VariableNamespace` | `nvarchar(256) NOT NULL` | Der Namespace stammt aus dem XML; ein fehlendes Attribut entspricht dem spezifizierten leeren Default. |
| `VariableName` | `nvarchar(256) NULL` | Der Name stammt aus `DTS:ObjectName`; ein fehlender oder leerer Name bleibt NULL. |
| `DataTypeCode` | `int NULL` | Der Code stammt ausschließlich aus `DTS:VariableValue/@DTS:DataType`; ein fehlender oder nicht konvertierbarer Code bleibt NULL. |
| `IsReadOnly` | `bit NULL` | Das Kennzeichen stammt aus `DTS:ReadOnly`; ein fehlendes Attribut entspricht False, ein ungültiges Kennzeichen bleibt NULL. |
| `EvaluateAsExpression` | `bit NULL` | Das Kennzeichen stammt aus `DTS:EvaluateAsExpression`; ein fehlendes Attribut entspricht False, ein ungültiges Kennzeichen bleibt NULL. |
| `SourceStatus` | `varchar(40) NOT NULL` | AVAILABLE bezeichnet die erfassten Metadaten; AVAILABLE_LIMITED kennzeichnet fehlenden Namen oder Datentyp sowie nicht konvertierbare Kennzeichen. |

Die False-Defaults entsprechen der [DTSX2-Spezifikation](https://learn.microsoft.com/en-us/openspecs/sql_data_portability/ms-dtsx2/).
Variablenwerte, Ausdruckstexte und serialisierte Objekte werden nicht gelesen
oder ausgegeben. Das Kennzeichen `EvaluateAsExpression` belegt keine Auswertung,
Gültigkeit oder erfolgreiche Auflösung eines Ausdrucks.

RAW, TABLE und JSON verwenden denselben begrenzten Variablenexport. NULL und 0
für `@MaxZeilen` bedeuten unbegrenzt; ein positiver Wert begrenzt die Zeilen
nach `VariableOrdinal`. `VARIABLES_TRUNCATED` und der Quellenstatus `TRUNCATED`
kennzeichnen die Begrenzung. Die ursprünglichen Ordinals bleiben erhalten.
Ein Scopeordinal kann auf ein Executable verweisen, das wegen des eigenen
RAW-Executable-Limits nicht ausgegeben wird. Die bisherigen Limitverträge der
anderen Resultsets werden durch diesen Slice nicht vereinheitlicht.
JSON erhält auch die NULL-Felder. Ein leeres Inventar liefert null Zeilen in
RAW und TABLE sowie `[]` in JSON; CONSOLE bleibt die einzelne Modulübersicht.

Der zusätzliche Quellenstatus `DTSX variables` unterscheidet AVAILABLE,
AVAILABLE_EMPTY, AVAILABLE_LIMITED und TRUNCATED; ungültige Aufrufe übernehmen
den jeweiligen Fehlerstatus. `ReturnedRowCount` zählt ausgegebene
Variablenzeilen. Ein vorhandener Event Handler erzeugt
`VARIABLES_EVENT_HANDLER_SCOPE_NOT_SUPPORTED` und IsPartial=1 für diese Quelle;
dessen Variablen und die Variablen seiner untergeordneten Executables bleiben
ausgeschlossen. Eine fehlende Executable-Kennung erzeugt
`VARIABLES_SCOPE_UNRESOLVED`, AVAILABLE_LIMITED und IsPartial=1. Nicht
zuordenbare Definitionen werden nicht ausgegeben; ein leeres Inventar ist in
diesen partiellen Fällen kein Abwesenheitsnachweis. Der Modulstatus bleibt
AVAILABLE_LIMITED, weil weitere Paketanalysen fehlen.

## Quellenprojektionen

- DTSX: Der direkte Kern projiziert Paketkopf, Executables, statische
  Precedence Constraints, Paket-Connection-Manager, Paketparameter, Paket-/Container-/Task-Variablendefinitionen, Namen
  sowie Klassenkennungen von Pipeline-Komponenten, Scope sowie
  Eigenschaftsnamen direkter Property-Expressions und direkte Pipeline-Linien
  zwischen zugeordneten Komponenten. Constraints ordnen `From` und `To` den sichtbaren
  Executable-Namen zu und geben nur `HasExpression` aus, nie den Ausdruckstext.
  Nicht zuordenbare Endpunkte erhalten `PARTIAL_LINEAGE`. Weitere Projektionen
  Connection Strings, Parameterwerte und andere sensitive Werte werden nicht
  gelesen oder ausgegeben. Komponenteneigenschaften, Ein-/Ausgaben,
  Spaltenmetadaten und Werte werden nicht gelesen oder ausgegeben. Direkte
  Pipeline-Linien lesen ausschließlich `startId` und `endId`; weitere
  Ein-/Ausgangs- und Spaltenmetadaten bleiben ausgeschlossen. Weitere
  Projektionen umfassen künftig Event Handler, weitere Connection Managers,
  weitere Parameterdefinitionen und Expressionauflösung. Expressiontexte,
  Script-/Assembly-Binärdaten
  sowie sensitive Werte werden nicht gelesen oder ausgegeben.
- Legacy Log: ausschließlich die dokumentierten `sysssislog`-Spalten der
  explizit benannten Tabelle und Execution ID.
- SSISDB: katalogisierte Execution-, Executable-, Message-, Parameter-, Phase-
  und Row-Flow-Views; keine Projektbinärstreams und keine Mutation.

Die Implementierung beginnt erst mit Phase 1. Dieser Vertrag erlaubt keine
Behauptung, dass SSIS-001 bereits als Produktfunktion verfügbar ist.

## Konkreter Katalogvertrag vom 16. Oktober 2026

Der Benutzer hat den konkreten Vertrag mit 17 Parametern und zehn Ergebnisschemas sowie eine eigene separate Framework-Testdatenbank zur Consumerprüfung ausdrücklich freigegeben. Der folgende Katalogvertrag konkretisiert die zuvor geplante Procedure. Der Kataloganalyzer besitzt keinen Identitäts- oder Raw-Payload-Opt-in. Der Legacy-Analyzer bleibt geplant.

## Zweck und Grenze

`monitor.USP_SsisCatalogExecutionAnalysis` liest genau eine explizite positive
Execution-ID aus der lokalen `SSISDB`. Der Analyzer startet oder stoppt keine
Ausführung, verändert keine Loggingstufe oder Retention und liest keine
Projektbinärstreams. Er öffnet keine Dateien, Netzwerkverbindungen oder
externen Datenquellen. Der direkte DTSX-Parser und der künftige Legacy-Analyzer
bleiben getrennte Verfahren.

Es werden ausschließlich strukturierte Katalogmetadaten gelesen.
Meldungstexte, Meldungskontextwerte, Parameterwerte, Executable-Rückgabewerte,
Paket-/Ausführungspfade, Host-, Server-, Login-, Caller- und SID-Felder sind
ausgeschlossen. Logische Ordner-, Projekt-, Paket-, Task-, Komponenten- und
Parameternamen bleiben diagnostische Metadaten. Es gibt keinen Raw-Payload-
oder Identitäts-Opt-in. Der nur geplante Parameter `IncludeRawEvents` wird
deshalb nicht Bestandteil dieser ersten öffentlichen Implementierung.

## Parameter

| Name | Typ und Default | Bedeutung |
|---|---|---|
| @ExecutionId | bigint=NULL | Genau eine positive ID; NULL und Werte kleiner eins sind ungültig. |
| @IncludeMessages | bit=1 | Liest strukturierte Ereignismetadaten ohne Meldungstext. |
| @IncludeParameters | bit=1 | Liest Definition, Datentyp und Flags ohne irgendeinen Parameterwert. |
| @IncludePerformance | bit=1 | Liest Executable-Statistik, Namen, Phasen und Row-Flow. |
| @MaxZeilen | int=1000 | Positive Grenze je Detailmenge; NULL/0 unbegrenzt, negativ ungültig. |
| @MaxDurationSeconds | int=30 | 1–60; kooperatives Budget zwischen Quellen, keine harte Abbruchgarantie für eine laufende SQL-Abfrage. |
| @LockTimeoutMs | int=0 | 0–60000; begrenzt Sperrwartezeit, keine allgemeine Querydeadline. |
| @ResultSetArt | varchar(16)='CONSOLE' | CONSOLE, RAW, TABLE oder NONE. |
| @ResultTablesJson | nvarchar(max)=NULL | Bestehender benannter TABLE-Vertrag. |
| @JsonErzeugen | bit=0 | JSON-Schema 1 mit benannten Arrays. |
| @Json | nvarchar(max)=NULL OUTPUT | JSON desselben materialisierten Aufrufs. |
| @PrintMeldungen | bit=1 | Bestehender Meldevertrag. |
| @Hilfe | bit=0 | Hilfe ohne fachlichen Quellenzugriff oder TABLE-Vorbereitung. |
| @StatusCodeOut | varchar(40)=NULL OUTPUT | Modulstatus. |
| @IsPartialOut | bit=NULL OUTPUT | Unvollständige Sammlung. |
| @ErrorNumberOut | int=NULL OUTPUT | Erste tatsächlich erhobene native Fehlernummer. |
| @ErrorMessageOut | nvarchar(4000)=NULL OUTPUT | Zugehörige vollständige native Fehlermeldung. |

NULL bei Include-Flags entspricht dem jeweiligen dokumentierten Default;
NULL bei Hilfe und JSON-Erzeugung entspricht 0. NULL bei Zeitbudget oder
Locktimeout ist ungültig. Hilfe hat Vorrang. Danach werden Ausgabeart,
TABLE-Mapping und fachliche Parameter vor Plattform- oder Katalogzugriff
geprüft. Ungültige Parameter liefern INVALID_PARAMETER mit IsPartial=1;
ungültige TABLE-Mappings behalten den Frameworkfehler 51011.

## Ausgabe in fester Reihenfolge

Die Reihenfolge entspricht dem Phase-0-Vertrag. `NN` bedeutet NOT NULL;
alle nicht mit NN bezeichneten Felder erlauben NULL. Alle Textfelder erhalten
explizit SQL_Latin1_General_CP1_CS_AS. Native Zeiten bleiben datetimeoffset(7).

| Menge | Spalten in Reihenfolge |
|---|---|
| moduleStatus | ModuleName sysname NN, SchemaVersion int NN, ExecutionId bigint NULL, StatusCode varchar(40) NN, IsPartial bit NN, ErrorNumber int NULL, ErrorMessage nvarchar(4000) NULL, CollectionTimeUtc datetime2(3) NN |
| execution | ExecutionId bigint NN, FolderName nvarchar(128), ProjectName nvarchar(128), PackageName nvarchar(260), ProjectLsn bigint, OperationType smallint, ExecutionStatus int, CreatedTime datetimeoffset(7), StartTime datetimeoffset(7), EndTime datetimeoffset(7), Use32BitRuntime bit |
| executables | StatisticsId bigint NN, ExecutionId bigint NN, ExecutableId bigint, ExecutableName nvarchar(4000), PackageName nvarchar(260), StartTime datetimeoffset(7), EndTime datetimeoffset(7), ExecutionDurationMs int, ExecutionResult smallint |
| messages | EventMessageId bigint NN, ExecutionId bigint NN, MessageTime datetimeoffset(7), MessageType smallint, MessageSourceType smallint, PackageName nvarchar(260), EventName nvarchar(1024), MessageSourceName nvarchar(4000), SubcomponentName nvarchar(4000), MessageCode int |
| parameters | ExecutionParameterId bigint NN, ExecutionId bigint NN, ObjectType smallint, ParameterName nvarchar(128), ParameterDataType nvarchar(128), IsSensitive bit, IsRequired bit, IsValueSet bit, IsRuntimeOverride bit |
| phases | PhaseStatsId bigint NN, ExecutionId bigint NN, PackageName nvarchar(260), TaskName nvarchar(4000), SubcomponentName nvarchar(4000), PhaseName nvarchar(128), StartTime datetimeoffset(7), EndTime datetimeoffset(7) |
| rowFlow | DataStatsId bigint NN, ExecutionId bigint NN, PackageName nvarchar(260), TaskName nvarchar(4000), SourceComponentName nvarchar(4000), DestinationComponentName nvarchar(4000), RowsSent bigint, CreatedTime datetimeoffset(7) |
| findings | FindingOrdinal int NN, FindingCode varchar(64) NN, Severity varchar(16) NN, ExecutionId bigint NN, EvidenceSource nvarchar(160) NN, Detail nvarchar(2000) NN |
| sourceStatus | SourceOrdinal int NN, SourceName nvarchar(160) NN, StatusCode varchar(40) NN, IsPartial bit NN, ObservedRowCount bigint, ReturnedRowCount bigint, IsTruncated bit NN, ErrorNumber int, ErrorMessage nvarchar(4000), Detail nvarchar(2000) NN, CollectionTimeUtc datetime2(3) NN |
| warnings | WarningOrdinal int NN, WarningCode varchar(64) NN, SourceName nvarchar(160), Detail nvarchar(2000) NN |

RAW liefert immer alle zehn typisierten Mengen. TABLE exportiert ausschließlich
die gemappten erlaubten Mengen. NONE unterdrückt fachliche Grids. JSON und
TABLE verwenden identische materialisierte Zeilen; NULL-Felder bleiben
enthalten, leere Mengen sind []. CONSOLE liefert genau eine formatierte
Executionübersicht beziehungsweise eine verständliche Status-/Leerzeile.
Auch deaktivierte oder fehlende Mengen behalten ihre Schemas.

## Quellenfolge, Bindung und Grenzen

Die fachliche Reihenfolge lautet:
1. catalog.executions, gefiltert auf execution_id;
2. catalog.executable_statistics, gefiltert auf execution_id;
3. catalog.executables, gefiltert auf execution_id;
4. catalog.event_messages, gefiltert auf operation_id = ExecutionId;
5. catalog.execution_parameter_values, gefiltert auf execution_id;
6. catalog.execution_component_phases, gefiltert auf execution_id;
7. catalog.execution_data_statistics, gefiltert auf execution_id.

Quellen 2/3/6/7 hängen von IncludePerformance ab; 4 von IncludeMessages,
5 von IncludeParameters. Deaktivierte Quellen werden nicht angesprochen und
erhalten AVAILABLE_LIMITED mit IsPartial=0 und Detail SOURCE_NOT_REQUESTED.
Es gibt keinen globalen Katalogscan und keine dynamisch frei benannte Quelle.
Alle SSISDB-Zugriffe sind dynamisch qualifiziert, sodass die Procedure auch
ohne vorhandenen Katalog installierbar bleibt.

Erst nach einer sichtbaren Executionzeile werden die Childquellen gelesen.
Bei keiner sichtbaren Execution bleibt execution leer; das Modul meldet
AVAILABLE_LIMITED/IsPartial=1 mit EXECUTION_NOT_VISIBLE_OR_ABSENT. Eine
RLS-bedingt unsichtbare Zeile wird nicht als sicher gelöschte oder fehlende
Ausführung bezeichnet. Aktivierte Childquellen erhalten in diesem Fall
AVAILABLE_LIMITED/IsPartial=1, NULL-Counts und SOURCE_NOT_READ_NO_VISIBLE_EXECUTION;
sie werden nicht als tatsächlich erfolgreich leer gelesene Quellen ausgegeben.
Mehrere Executionzeilen oder doppelte erwartete
Quellenschlüssel sind SOURCE_UNAVAILABLE und werden nicht dedupliziert.

Die Statistik ist die führende Executablemenge. Die Namen werden links über
(ExecutionId, ExecutableId) ergänzt. Fehlende oder ausgefallene Namensmetadaten
erhalten Statistikzeilen mit NULL-Namen und einen begrenzten Quellenstatus;
sie löschen keine Statistik. Die Namensquelle meldet dabei
EXECUTABLE_METADATA_NOT_VISIBLE, ohne eine konkrete Berechtigungsursache
zu behaupten. Ihr ReturnedRowCount zählt unterschiedliche tatsächlich
verwendete ExecutableIds, nicht die durch Iterationen vervielfachten
Statistikzeilen. Nicht positive Row-Flow-Werte werden weder
ersetzt noch als erfolgreicher Datentransfer umgedeutet. Zeitdauern werden
nicht über offene oder fehlende Endzeiten erfunden.

Bei positiver Zeilengrenze liest jede Detailquelle einen stabil nach ihrer
nativen ID geordneten N+1-Präfix. Der Sentinel belegt nur eine Untergrenze,
keine Gesamtanzahl. N+1 wird mit bigint ohne int-Überlauf gebildet.
Er wird nicht ausgegeben; ObservedRowCount zählt die
beobachteten N+1-Zeilen, IsTruncated=1 und Quellenstatus TRUNCATED markieren
die Begrenzung. ReturnedRowCount zählt die ausgegebenen Zeilen. Die Namensquelle
verwendet ExecutableId als Ordnungsschlüssel; eine eigene Begrenzung bleibt
als solche sichtbar. Ohne Grenze zählt ObservedRowCount die tatsächlich
materialisierten sichtbaren Zeilen. Findings werden nach FindingCode geordnet
und mit demselben MaxZeilen-Vertrag begrenzt; Status und warnings bleiben
unlimitiert. Limits beeinflussen keine Executionstatuswerte.

Die kooperative Deadline wird zwischen Quellen geprüft. Nach Ablauf bleiben
erfolgreiche Teilmengen erhalten; noch nicht angesprochene aktive Quellen
erhalten AVAILABLE_LIMITED/IsPartial=1 und TIME_BUDGET_EXHAUSTED. Es gibt
keine Loop-, Wait-, Sampling- oder KILL-Aktion und keine Abbruchgarantie für
einen bereits laufenden Aufruf.

## Plattform-, Fehler- und Statusvertrag

Ohne sichtbare SSISDB wird die Hostplattform begrenzt über sys.dm_os_host_info
beobachtet. Nur tatsächlich beobachtetes Linux ergibt UNAVAILABLE_PLATFORM.
Windows oder unbekannte Plattform ohne sichtbaren Katalog ergeben
SOURCE_UNAVAILABLE. Ein tatsächlicher Fehler dieser Plattformprobe wird
als eigenes sourceStatus-Fehlerpaar erhalten; eine unbekannte Plattform
wird nicht als Linux angenommen. Bei vorhandener SSISDB ist diese Probe
nicht Voraussetzung für die Katalogabfragen. Sie besitzt SourceOrdinal 0
und SourceName sys.dm_os_host_info; ohne erforderliche Plattformprobe wird
diese Zeile nicht erzeugt. Die übrigen Ordinale entsprechen der festen
Quellenfolge. Bei fehlendem Katalog werden aktivierte Katalogquellen mit
NULL-Counts und dem beobachteten Plattform-/Katalogstatus ausgewiesen;
deaktivierte Quellen behalten SOURCE_NOT_REQUESTED.

Jede aktivierte Quelle wird einzeln behandelt. 229/262/297/300/371 ergeben
DENIED_PERMISSION; 1222 ergibt ERROR_HANDLED; 207/208/911/916 ergeben
SOURCE_UNAVAILABLE, andere native Fehler ERROR_HANDLED. Es werden keine
Fehlernummern für bloße Abwesenheit erfunden. Die erste tatsächliche native
Fehlerpaarung in der festen Zugriffsfolge bleibt separat erhalten.

Erfolgreiche leere Quellen sind AVAILABLE_EMPTY/IsPartial=0, erfolgreiche
nichtleere Quellen AVAILABLE/IsPartial=0. Fehlende optionale Loggingzeilen
beweisen weder Nullaufwand noch einen Defekt; warnings benennt
LOGGING_EVIDENCE_NOT_OBSERVED, ohne eine bestimmte Loggingstufe zu behaupten.
Ein nichtterminaler nativer Status ist kein Fehler des Analyzers. Findings
benennen ausschließlich beobachtete Status 3 als EXECUTION_CANCELED,
4 als EXECUTION_FAILED, 6 als EXECUTION_ENDED_UNEXPECTEDLY,
1 als EXECUTION_NOT_STARTED und 2/5/8 als EXECUTION_NOT_TERMINAL. Die
nativen Status 7/9 bleiben unverändert; es gibt keine automatische
Root-Cause-, Fehlerketten-, Durchsatz- oder Performancebehauptung.
Findings für 3/4/6 haben Severity WARNING, für 1/2/5/8 INFO; alle anderen
Statuswerte erzeugen keinen synthetischen Erfolgs- oder Fehlerbefund.
Die Loggingwarnung entsteht nur bei aktivierter, tatsächlich erfolgreich
leer gelesener Performancequelle. Sie unterstellt weder Abwesenheit einer
Komponente noch eine bestimmte Ursache oder Loggingkonfiguration.

Ohne Problem und bei sichtbarer Execution ist das Modul AVAILABLE.
Die genannten Findings beschreiben ausschließlich den gelesenen
Executionzustand. Auch für Status 1/2/3/4/5/6/8 bleibt eine erfolgreiche,
vollständige Sammlung AVAILABLE/IsPartial=0 mit NULL in beiden Error-Outputs.
Finding-Severity WARNING ändert weder Modulstatus noch Partialität oder
native Fehlerfelder. Ausschließlich die nachstehenden Sammlungsprobleme
ändern diese Werte; die Warnung über eine tatsächlich leere Loggingquelle
ist für sich ebenfalls kein Sammlungsfehler.
Deaktivierte Quellen und erfolgreiche Leerquellen erzeugen keine Partialität.
Bei Trunkierung, Deadline, fehlender Execution oder einem Quellenproblem
mit erhaltenen fachlichen Daten ist es AVAILABLE_LIMITED/IsPartial=1.
Ohne erfolgreich gelesene Executionquelle erhält es deren Fehlerstatus;
fehlender Katalog oder Plattformfallback haben Vorrang vor Childquellen.
Outputwerte und moduleStatus sind konsistent.

TranCount, LOCK_TIMEOUT und XACT_ABORT des Callers bleiben erhalten. Der
Analyzer beginnt keine Transaktion und ändert keine persistenten Daten oder
Rechte. Es gibt keine Ergebnisatomarität über mehrere Katalogabfragen:
laufende Ausführungen können sich zwischen Aufnahmen verändern.

Die veröffentlichten Lab-Quellen bestätigen Basic-Logging mit Erfolg, Fehler und einer erstellten, nicht gestarteten Ausführung. Positive Task-, Schleifen-, Performance-/Verbose-, RowFlow- und Least-Privilege-Nachweise bleiben getrennte Abnahmen. Eine Linuxprüfung belegt ausschließlich den Plattformfallback.
