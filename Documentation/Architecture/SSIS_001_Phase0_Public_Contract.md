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

## Konkreter Legacy-Vertrag vom 16. Oktober 2026

Der Benutzer hat die geprüfte Revision 3 mit 20 Parametern und neun Schemas ausdrücklich freigegeben und ihre Implementierung beauftragt. Der Vertrag enthält gespeicherte Meldungstexte standardmäßig und verlangt keine zusätzlichen Indizes. Er konkretisiert den zuvor geplanten Legacy-Analyzer; breitere frühere Parser- oder Kausalitätsversprechen werden dadurch nicht aktiviert.

### 1. Entscheidung und Abgrenzung

Die Procedure soll die vom SQL-Server-Log-Provider angelegten Legacy-Ereignisse einschließlich der gespeicherten Diagnosemeldungen lesen, deren zeitliche Reihenfolge darstellen, eindeutige Ereignispaare rekonstruieren und Grenzen der vorhandenen Protokollierung ausweisen. Eine fachlich fehlgeschlagene Ausführung ist von einem Fehler des Analyzers getrennt. Eine vollständige Sammlung belegt nur die sichtbaren protokollierten Zeilen der ausgewählten ID, keine vollständige oder erfolgreiche Paketausführung.

Dieser freigegebene Vertrag konkretisiert die geplante Legacy-Procedure aus `Documentation/Architecture/SSIS_Package_and_Execution_Analysis_Plan.md`, Abschnitte 4.2 und 9, und die neun Resultsetnamen aus `Documentation/Architecture/SSIS_001_Phase0_Public_Contract.md`. Er legt für die erste Implementierung folgende bewusste Einschränkungen gegenüber dem breiteren Plan fest:

- Gespeicherte `message`-Texte werden standardmäßig als wesentliche Fehler- und Diagnoseinformation vollständig gelesen und ausgegeben. `@IncludeMessages = 0` schaltet diese Projektion ausdrücklich ab. Die dedizierten Spalten `databytes`, `computer` und `operator` bleiben ausgeschlossen; dafür gibt es keinen Opt-in.
- Die geplanten Parameter `@PackageXml` und `@IncludeRawEvents` entfallen. Die Timeline enthält die unveränderten strukturierten Ereignisfelder; es gibt kein weiteres Raw-Payload-Resultset. Paketgraphen, Elternbeziehungen und die Zusammenführung anderer Execution-IDs gehören nicht zu dieser Procedure.
- `errorChain` bezeichnet eine nachvollziehbare zeitliche Folge relevanter Ereignisse. Sie erhält die zugehörigen Meldungstexte, behauptet ohne verifizierte Paketbeziehungen und semantische Gegenprobe jedoch weder Fehlerpropagation noch eine technische Root Cause. Wiederholte gleichartige Zeilen bleiben erhalten.
- `iterations` bezeichnet beobachtete Ereignispaare je Source-ID und Paarart. Wiederholte Paare belegen keine For-/Foreach-Schleife.
- Data-Flow-Zeilenmengen, Komponentenzeittexte und Ursachen werden nicht automatisch aus Freitext geparst. Der gespeicherte Originaltext bleibt bei eingeschlossener Meldungsprojektion zur Diagnose verfügbar. Weiterführende automatische Legacy-Interpretationen bleiben eigenständige spätere Verträge.

Der normale Aufruf benötigt ausschließlich die vom Benutzer gewählte Loggingdatenbank und die Execution-ID. Schema und Tabellenname besitzen die Defaults dbo und sysssislog; die beiden optionalen Abweichungsparameter erlauben bereits vorhandene kompatible andere Ablagen, nicht die Konfiguration oder Umgestaltung des nativen Providers. Die Procedure verlangt weder manuelle Tabellenanlage noch zusätzliche Indexe oder sonstige Änderungen am SSIS-erzeugten Quellschema. Ein Beispiel mit ausschließlich synthetischen Werten lautet:

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
     @LoggingDatabase=N'ExampleSsisLogs',
     @ExecutionId='00000000-0000-0000-0000-000000000001';
```

Die Pflichtangabe der Datenbank richtet sich nach dem tatsächlich gewählten Loggingziel. msdb wird nicht implizit verwendet; auch eine ausdrücklich ausgewählte msdb ist ein zulässiger Scope. Der dokumentierte Provider erstellt sysssislog im konfigurierten Datenbankziel. Für eine frei konfigurierbare Umbenennung dieser Providertabelle wird hier keine Herstellerfunktion behauptet.

Diese Einschränkungen werden bei einer Umsetzung ausdrücklich in Plan, Vertrag, Guide und Implementierungsstatus übernommen; ältere Planungsabschnitte werden nicht als bereits erfüllte Funktion ausgegeben. Die ausdrückliche menschliche Freigabe der geprüften Revision 3 legt diesen Umfang fest.

### 2. Parameter in Deklarationsreihenfolge

| Nr. | Parameter | SQL-Typ und Default | Vertrag |
|---|---|---|---|
| 1 | `@LoggingDatabase` | `sysname = NULL` | Explizite lokale Datenbank; NULL, leer oder nur Leerzeichen sind ungültig. Kein CURRENT-Default. |
| 2 | `@LoggingSchema` | `sysname = N'dbo'` | Optionaler exakter Bezeichner einer bereits vorhandenen Quelle; Default dbo. Kein Auftrag, das SSIS-Quellschema zu ändern. NULL oder leer ist ungültig. |
| 3 | `@LoggingTable` | `sysname = N'sysssislog'` | Optionaler exakter Name einer bereits vorhandenen kompatiblen Quelle; Default sysssislog. Keine behauptete Provider-Umbenennungsoption. NULL oder leer ist ungültig. |
| 4 | `@ExecutionId` | `uniqueidentifier = NULL` | Genau eine ID; NULL und die Null-GUID sind ungültig. |
| 5 | `@IncludeTimeline` | `bit = 1` | Steuert ausschließlich den Timeline-Export. Bei 0 bleibt dessen Schema erhalten und dessen Zeilenmenge leer; die übrige Analyse verwendet weiterhin den gemeinsamen Ereignispuffer. |
| 6 | `@IncludeMessages` | `bit = 1` | Liest die gespeicherte message-Spalte für alle gepufferten Ereignisse verlustfrei. 0 unterbindet ihren fachlichen Datenzugriff und liefert typisierte NULL-Textfelder; die vier Ergebnisprojektionen werden in Abschnitt 5 definiert. |
| 7 | `@HighImpactConfirmed` | `bit = 0` | Explizite Zustimmung zur unbegrenzten Sammlung oder zur eingeschlossenen nvarchar(max)-Meldungsquelle. Fehlende Indexe allein benötigen diese Bestätigung nicht; genaue Regeln stehen in Abschnitt 4. |
| 8 | `@MaxZeilen` | `int = 1000` | Positiv begrenzt den Ereignispuffer und die fünf Fachdetailmengen aus Abschnitt 6. Status, Executionübersicht und die endlich begrenzte Steuerdiagnostik warnings bleiben ungekürzt. NULL/0 ist unbegrenzt und benötigt HighImpactConfirmed=1; negativ ist ungültig. |
| 9 | `@MaxDurationSeconds` | `int = 30` | 1–60, nicht NULL. Kooperative Prüfung zwischen Metadaten-, Index-, Ereignis- und Ableitungsschritt; keine harte Abbruchgarantie einer laufenden SQL-Abfrage. |
| 10 | `@LockTimeoutMs` | `int = 0` | 0–60000, nicht NULL; begrenzt Sperrwartezeit, keine allgemeine Querylaufzeit. |
| 11 | `@ResultSetArt` | `varchar(16) = 'CONSOLE'` | CONSOLE, RAW, TABLE oder NONE; Steuerwert wird getrimmt und case-insensitiv normalisiert. NULL/leer/andere Werte sind ungültig. |
| 12 | `@ResultTablesJson` | `nvarchar(max) = NULL` | Bestehender Frameworkvertrag für die neun benannten TABLE-Ziele. Nichtleeres Mapping außerhalb von TABLE ist ungültig. |
| 13 | `@JsonErzeugen` | `bit = 0` | Erzeugt JSON desselben materialisierten Aufrufs. |
| 14 | `@Json` | `nvarchar(max) = NULL OUTPUT` | Wird am Aufrufbeginn gelöscht und nur bei angefordertem JSON gesetzt. |
| 15 | `@PrintMeldungen` | `bit = 1` | Steuert optionale Frameworkmeldungen; keine zusätzlichen fachlichen Grids. |
| 16 | `@Hilfe` | `bit = 0` | Hilfe hat Vorrang vor fachlicher Validierung, TABLE-Vorbereitung und jedem Quellenzugriff. |
| 17 | `@StatusCodeOut` | `varchar(40) = NULL OUTPUT` | Entspricht exakt moduleStatus.StatusCode. |
| 18 | `@IsPartialOut` | `bit = NULL OUTPUT` | Entspricht exakt moduleStatus.IsPartial. |
| 19 | `@ErrorNumberOut` | `int = NULL OUTPUT` | Erste tatsächlich erhobene native Fehlernummer der festen Quellenfolge; sonst NULL. |
| 20 | `@ErrorMessageOut` | `nvarchar(4000) = NULL OUTPUT` | Vollständige zugehörige native Fehlermeldung; sonst NULL. |

NULL bei IncludeTimeline, IncludeMessages und PrintMeldungen entspricht 1; NULL bei HighImpactConfirmed, JsonErzeugen und Hilfe entspricht 0. Alle OUTPUT-Werte werden zu Beginn zurückgesetzt; Hilfe lässt sie einschließlich JSON NULL. Datenbank-, Schema- und Tabellenparameter sind keine SQL-Fragmente: Jeder vollständige übergebene Wert wird einzeln mit QUOTENAME begrenzt; Punkte oder Klammern innerhalb eines Werts werden nicht als Multipartsyntax zerlegt. Keine Wildcards, Remotequellen oder frei übergebenen WHERE-/ORDER-/SQL-Ausdrücke werden ausgeführt.

Nach Hilfe werden Ausgabeart und Mappingkontext geprüft. Bei TABLE folgt die vorhandene Mappingvorbereitung vor der fachlichen Parameterprüfung; ungültige Mappings werfen unverändert Frameworkfehler 51011. Andere semantisch ungültige Parameter liefern INVALID_PARAMETER/IsPartial=1 mit strukturiertem Grund und ohne Quellzugriff. Bei gültigem Mapping behalten die TABLE-Ziele auch dann die neun nativen Schemas. Gültige technische Parameter und ein erst durch Metadaten erkennbares High-Impact-Gate erlauben ausschließlich die vorherigen Metadatenprüfungen, noch keinen Ereigniszugriff.

### 3. Quellenvertrag und Datenschutz

Zugelassen ist ausschließlich eine sichtbare physische lokale Loggingtabelle im expliziten Datenbank-/Schema-/Objektscope, einschließlich der vom SSIS-Provider angelegten und möglicherweise als Systemtabelle gekennzeichneten sysssislog. Ein is_ms_shipped=0-Filter darf diese native Quelle nicht ausschließen. Views, Synonyme, externe Tabellen und Linked Server sind ausgeschlossen. Keine SSISDB-, msdb-Paket-, Datei-, Registry-, SQLCLR- oder Hostquelle wird ersatzweise gelesen. Die Installation selbst benötigt keine SSIS-Installation und keine vorhandene Loggingtabelle.

Die folgende strukturierte Projektion ist der Mindestvertrag einer unterstützten `sysssislog`-kompatiblen Tabelle. Zusätzlich wird message bei IncludeMessages=1 benötigt. Weitere Spalten sind erlaubt, bleiben aber ungelesen. Es gibt kein `SELECT *`.

| Exakter Spaltenname | Zulässiger Basistyp | Verwendung |
|---|---|---|
| `id` | `int NOT NULL` | Eindeutige Ordnung innerhalb der gewählten Execution-ID. |
| `event` | `nvarchar(n)`, 1≤n≤128; einschließlich sysname | Ereignisname; NULL bleibt erhalten. |
| `source` | `nvarchar(n)`, 1≤n≤4000 | Unveränderter Executable-Name; NULL bleibt erhalten. MAX wird vor dem Datenzugriff als nicht unterstütztes Schema abgewiesen. |
| `sourceid` | `uniqueidentifier` | Technische Source-Kennung, NULL bleibt unbekannt. |
| `executionid` | `uniqueidentifier` | Ausschließlich `= @ExecutionId`; keine angrenzenden IDs. |
| `starttime` | `datetime` | Nativer protokollierter Ereigniszeitpunkt ohne Zeitzonenannahme. |
| `endtime` | `datetime` | Unveränderter Rohwert ausschließlich in timeline; kein Laufzeitendpunkt. |
| `datacode` | `int` | Unveränderter Ereigniscode; kein universeller HRESULT-/Outcome-Decoder. |
| `message` | `nvarchar(n)` mit 1≤n≤4000 oder `nvarchar(max)` | Bei IncludeMessages=1 erforderlich, einschließlich beliebiger NULL-Werte. Vollständiger gespeicherter Inhalt, keine SQL-seitige Zeichenkappung. Bei MAX benötigt der Ereigniszugriff zusätzlich HighImpactConfirmed=1. |

Die acht strukturierten Eingabefelder und, bei IncludeMessages=1, das neunte Feld message müssen gespeicherte, nicht berechnete Spalten sein. Berechnete Spalten werden auch dann ausgeschlossen, wenn sie persistiert sind oder ihre resultierenden Typen passen; damit erhält die Projektion keinen indirekten Ausdrucks- oder UDF-Zugriff auf weiterhin ausgeschlossene Spalten. Die Metadatenzulassung prüft diese Eigenschaft vor jedem Ereigniszugriff. Zusätzliche, nicht projizierte berechnete Spalten sind für diese Zulassung unerheblich.

Abgesehen von id darf die Quellnullbarkeit abweichen. Aliasdatentypen werden nur akzeptiert, wenn ihr Basistyp, ihre Länge und ihre relevante Nullbarkeit dem Vertrag entsprechen. Berechnete Eingabefelder, nicht unterstützte Typen, Case-Abweichungen auf case-sensitiven Quellen oder fehlende Felder liefern SOURCE_UNAVAILABLE mit SOURCE_SCHEMA_UNSUPPORTED, ohne eine implizite Datenkonvertierung oder Umbenennung.

Die dokumentierte native Tabelle besitzt weitere Loggingfelder wie computer, operator und databytes. Dieser konkrete Vertrag benötigt deren Werte oder Existenz nicht. Bei IncludeMessages=0 ist auch message keine Zulassungsvoraussetzung: Existenz, Typ und Berechnungseigenschaft dieser ausgeschalteten Spalte verhindern die strukturierte Analyse nicht; keine fachliche Abfrage referenziert sie dann. Die SQL-Projektion verwendet dafür ein typisiertes NULL statt eines CASE-Ausdrucks über message. Die acht strukturierten Felder werden verlustfrei in die unten festgelegten Ausgabetypen übernommen. Alle Frameworktextfelder verwenden explizit `COLLATE SQL_Latin1_General_CP1_CS_AS`; Quelltexte werden nicht getrimmt, übersetzt oder anonymisiert. Reale Laufzeitausgaben bleiben lokal und dürfen nicht in Repositoryartefakte gelangen.

Die dedizierten Computer-/Operator-/Binärspalten werden auch nicht für Hashing, Deduplizierung, Längenprüfung, Parsing, Fehlerklassifikation oder Diagnosemeldungen gelesen. Freier Meldungstext kann selbst Identitäten, SQL, Pfade, Parameterwerte oder Secrets enthalten. Der Ausschluss der dedizierten Identitätsspalten ist deshalb keine Zusage eines identitätsfreien Meldungstexts. Es gibt keine stille Anonymisierung oder automatische Schwärzung der Laufzeitresultate. Das Projektverbot für reale Daten in Repository-/GitHub-/Downloadartefakten bleibt unabhängig davon bestehen. Meldungstexte werden weder per PRINT noch in warnings/findings-Detailtexte oder native ErrorMessageOut-Werte kopiert. Fachliche Quellwerte werden nicht durch dynamisches SQL interpoliert; die Execution-ID ist ein typisierter Parameter. Keine Impersonation, Berechtigungserweiterung, Quell-DDL, Indexanlage, Retentionaktion, Paketausführung oder Schreiboperation in einer Quelltabelle ist Teil des Moduls.

### 4. Zulassung, Quellenfolge und Eigenlast

Die feste Reihenfolge lautet:

1. `sourceMetadata`: lokale Datenbank-/Schema-/Tabellensichtbarkeit und die acht strukturierten Spaltendefinitionen sowie bei IncludeMessages=1 die message-Definition über Systemkataloge;
2. `sourceIndexes`: ausschließlich beratende sichtbare Indexmetadaten des einen Objekts; ihre Nichtverfügbarkeit verhindert die spätere Ereignisabfrage nicht;
3. `sourceEvents`: eine materialisierte Abfrage der acht strukturierten Felder und bei IncludeMessages=1 des gespeicherten Meldungstexts für die eine Execution-ID;
4. `eventDerivation`: ausschließlich lokale Ableitung aus diesem Puffer, kein weiterer fachlicher Quellenzugriff.

Die vorhandene native Loggingtabelle ist auch als Heap oder ohne zusätzlich angelegte Indexe eine zulässige Quelle. Eine per Indexmetadaten nachgewiesene Eindeutigkeit ist keine Zulassungsvoraussetzung. id bezeichnet gemäß dokumentiertem Loggingformat die Ereigniskennung; tatsächliche doppelt materialisierte IDs werden wie nachfolgend beschrieben verworfen. Es gibt keine zweite unbeschränkte Integritätsabfrage über die gesamte Tabelle oder über die komplette Execution-ID. Außerhalb des eingelesenen Puffers wird keine neue Eindeutigkeitsprüfung behauptet.

sourceIndexes prüft nur zur Einordnung der Last, ob ein sichtbarer aktivierter nicht gefilterter B-Tree-Index executionid als führenden Schlüssel besitzt. Falls nicht beobachtet, wird SUPPORTING_INDEX_NOT_OBSERVED als INFO-Steuerwarnung ausgegeben; das ist weder ein sicherer Nachweis des Nichtvorhandenseins noch eine Lesesperre. Eine tatsächliche Indexmetadaten-Exception bleibt in sourceStatus2 mit ihrem nativen Fehlerpaar und SOURCE_INDEX_METADATA_UNAVAILABLE erhalten; sourceEvents wird bei weiterhin gültiger erforderlicher Quellenzulassung trotzdem gelesen. Die Procedure erstellt oder verändert keine Indexe und erzwingt keinen bestimmten Indexplan.

HighImpactConfirmed=1 bleibt erforderlich, wenn MaxZeilen NULL/0 ist oder wenn IncludeMessages=1 eine deklarierte nvarchar(max)-message-Spalte einschließt. Diese Grenzen ergeben HIGH_IMPACT_CONFIRMATION_REQUIRED vor sourceEvents, nicht das bloße Fehlen eines beobachteten Indexes. Normale begrenzte Aufrufe gegen die native nvarchar(2048)-Providerquelle funktionieren ohne zusätzliche Bestätigung auch dann, wenn kein passender Filterindex beobachtet wurde. Bei ausgeschalteten Meldungen entfällt ausschließlich das zusätzliche MAX-Text-Gate.

Ein fehlender Filterindex kann zu einem Tabellenscan oder einer teuren Sortierung führen. Das ist ein transparenter Lastvorbehalt der angeforderten bestehenden Logquelle: TOP(N+1) begrenzt die aufgenommenen Zeilen, nicht die garantierte physische Lese-/CPU-Menge. Ein Index umgekehrt garantiert keinen bestimmten tatsächlichen Plan. Zeitbudget und Locktimeout bleiben die unten beschriebenen kooperativen beziehungsweise sperrbezogenen Grenzen; es wird keine harte Querydeadline versprochen.

Bei positivem N liest sourceEvents höchstens N+1 Zeilen nach id ASC und materialisiert diese einmal. Vor der Sentinelentfernung wird die ganze materialisierte N+1-Menge auf doppelte id geprüft. Bei einem solchen Befund wird die gesamte Aufnahme ohne Deduplizierung verworfen: sourceEvents und das Modul liefern ERROR_HANDLED/IsPartial=1 mit DUPLICATE_LOG_ID_OBSERVED, eventDerivation bleibt NOT_READ und alle fachlichen Ableitungen bleiben leer. ObservedRowCount und ReturnedRowCount von sourceEvents bleiben dann NULL; dessen eigenes ErrorNumber/ErrorMessage-Paar bleibt ebenfalls NULL, weil dieser Integritätsbefund keinen nativen SQL-Fehler erzeugt. Ein zuvor tatsächlich erfasstes erstes natives Fehlerpaar, etwa aus sourceIndexes, bleibt dagegen in moduleStatus und den Modul-OUTPUTs erhalten; nur ohne vorherige native Exception bleiben auch diese NULL. Es folgt keine erneute Abfrage. Diese Pufferprüfung gilt unabhängig von vorhandenen oder fehlenden Indexen; eine unbemerkte Anomalie außerhalb des Puffers wird dadurch nicht ausgeschlossen.

Nur ein gültiger Puffer wird anschließend um die N+1-Sentinelzeile gekürzt. ObservedRowCount=N+1 ist bei Sentinel eine Untergrenze; ReturnedRowCount=N beschreibt den verwendeten Ereignispuffer. Ohne Sentinel ist dessen sichtbare Zeilenzahl exakt für diese Abfrage. Bei unbegrenztem Aufruf wird der gesamte materialisierte Puffer auf doppelte id geprüft und kein Sentinel hinzugefügt. Es gibt keine zweite COUNT-Abfrage, keine Abfrage benachbarter IDs und keine aus vermeintlichen fehlenden Zeilen abgeleitete Retentionursache.

Metadaten und Ereignisse werden ohne absichtliche lange Sperrhaltung gelesen. NOLOCK/READUNCOMMITTED kann bei gleichzeitigen Änderungen unbestätigte, fehlende oder doppelt beobachtete Zeilen liefern. Es wird keine transaktionskonsistente Momentaufnahme zugesagt. Gegenproben und native Abnahmen benötigen einen dokumentiert ruhenden Quellslice. Datenbank-ID, Objekt-ID und Anlagezeit werden vor und nach sourceEvents gebunden geprüft; eine erkannte Änderung verwirft den Ereignispuffer und meldet ERROR_HANDLED/SOURCE_IDENTITY_CHANGED. Es wird dafür keine native Fehlernummer erfunden.

Zeitbudget und Locktimeout werden vor jedem neuen Schritt geprüft beziehungsweise gesetzt. Eine noch laufende Quellabfrage wird vom Modul nicht hart abgebrochen. Nach einem Timeout, nativen Fehler oder Identitätswechsel werden keine nur teilweise gefüllten Ereignispuffer als gültige Analyse übernommen. Die ursprünglichen LOCK_TIMEOUT-, XACT_ABORT- und Transaktionszustände bleiben bei Erfolg und Fehler erhalten; Callertransaktionen werden weder committed noch zurückgerollt.

### 5. Fachliche Ableitung

### Zeit und Klassifikation

Timeline und Ableitungen verwenden id ASC als protokollierte Reihenfolge; das ist keine Behauptung einer globalen realen Ausführungsreihenfolge paralleler Vorgänge. StartTime/EndTime bleiben native datetime-Werte ohne UTC-Konvertierung. CollectionTimeUtc ist separat datetime2(3). Zeitdifferenzen werden nur aus den starttime-Werten zweier zugelassener Ereignisse berechnet. RawEndTime wird niemals zur Dauerberechnung verwendet.

Eventnamen werden ausschließlich mit expliziter CS_AS-Vergleichssemantik erkannt. Die vier relevanten Diagnoseereignisse sind OnError, OnTaskFailed, OnWarning und OnQueryCancel; sie erhalten ERROR, WARNING, WARNING beziehungsweise INFO. Andere oder NULL-Namen bleiben in der Timeline sichtbar und erhalten INFO beziehungsweise UNKNOWN. Ein OnQueryCancel belegt nur die protokollierte Abbruchanfrage, keinen vollzogenen Abbruch. DataCode wird unverändert erhalten und nicht pauschal auf PackageSuccess/Failure abgebildet.

### Meldungstexte und erster Fehler

IncludeMessages=1 projiziert den vollständigen in der unterstützten Quelltabelle gespeicherten Text einmal in den gemeinsamen Ereignispuffer. Alle Ereignisarten sind eingeschlossen, damit diagnostisch relevante Nachbarinformationen nicht anhand einer vorab angenommenen Fehlerklassifikation verschwinden. MessageText in timeline und errorChain verwendet nvarchar(max), explizite CS_AS-Collation und die unveränderten gespeicherten Zeichen einschließlich Zeilenumbrüchen und abschließenden Leerzeichen. NULL bleibt NULL, leer bleibt leer. Es erfolgt keine Zeichenkappung, Textnormalisierung, Übersetzung, Hash-Deduplizierung oder Freitextauswertung. Die äußeren N+1-/Zeilenlimits gelten weiterhin. JSON maskiert Sonderzeichen nur gemäß JSON-Syntax und muss nach dem Dekodieren denselben Text liefern.

Die vollständige Textprojektion umfasst ausdrücklich auch Informations- und Warnmeldungen über geladene Lookup-Referenzzeilen, Cacheaufbau, transportierte Zeilenzahlen, Komponentenphasen und deren Laufzeiten sowie Lookup-Mehrfachtreffer. Sie wird nicht auf OnError oder die vier Ereignisarten von errorChain eingeschränkt. Solche Meldungen bleiben in timeline mit LogId, EventName, SourceId, SourceName und EventTime verknüpft; bei IncludeTimeline=0 wird dieser vollständige Ereignisexport bewusst unterdrückt. errorChain behält die Texte seiner vier definierten Diagnoseereignisarten; die Einzeilenübersicht ersetzt den vollständigen Timelineexport nicht.

Dieser freigegebene Vertrag sichert die vollständigen gespeicherten Meldungen für die Diagnose, definiert aber noch keinen sprach-/versionsspezifischen Freitextparser für strukturierte Lookup-Zahlen, Phasenzeiten oder Duplicate-Befunde. Eine solche automatische Auswertung benötigt explizite akzeptierte Formate, Einheiten, Komponentenbindung und Regeln für unbekannte Formate; sie darf nicht aus beliebigen Zahlen oder einzelnen Suchwörtern entstehen. Native Meldung, interpretierter Wert und daraus abgeleiteter Befund müssen dabei getrennt nachvollziehbar bleiben. Aus dem Fehlen einer Duplicate-Warnung darf kein Nachweis eindeutiger Lookup-Referenzdaten entstehen: Laut Hersteller hängt die entsprechende Warnung vom Cachemodus ab. Diese Aussage erlaubt keine direkte Abfrage oder Veränderung einer Lookup-Referenztabelle durch den Legacy-Analyzer.

Eine bereits vom Provider beziehungsweise beim ursprünglichen Speichern abgeschnittene oder ausgelassene Meldung kann der Analyzer nicht wiederherstellen. Vollständig bedeutet hier ausschließlich vollständiger gespeicherter SQL-Wert, nicht vollständige ursprüngliche Engine-/Providerdiagnose. Der dokumentierte SQL-Log-Provider verwendet für message nvarchar(2048); aus einer ausgeschöpften Speicherlänge wird keine sichere vorherige Abschneidung abgeleitet.

FirstErrorLogId ist die kleinste gepufferte LogId eines OnError; nur wenn kein OnError vorhanden ist, wird die kleinste OnTaskFailed-LogId gewählt. FirstErrorMessage stammt exakt aus derselben Zeile. Ein NULL-/Leertext wird nicht durch den Text eines anderen Ereignisses ersetzt. Die Kennzeichnung ist der erste beobachtete Fehler des Puffers, keine garantierte technische Erstursache. Die Übersicht und CONSOLE zeigen diesen gespeicherten Text vollständig; alle weiteren Texte bleiben in errorChain beziehungsweise timeline erhalten. Zeilengrenzen können spätere Fehler ausschließen und bleiben über IsCompleteSlice/IsPartial sichtbar.

Bei IncludeMessages=0 wird message nicht fachlich gelesen. MessageText und FirstErrorMessage bleiben in allen Modi typisierte NULL-Werte; moduleStatus.MessagesIncluded ist 0 und MESSAGES_NOT_REQUESTED macht die bewusste Abschaltung sichtbar. FirstErrorLogId und strukturelle Ereignisauswertung bleiben verfügbar. Der Opt-out allein erzeugt keine Modulpartialität. Bei IncludeMessages=1 ist MessagesIncluded=1 auch dann, wenn eine fehlende/inkompatible message-Spalte den Quellzugriff verhindert; das Kennzeichen bezeichnet die gewählte Projektion, nicht einen Erfolgsnachweis. Tatsächlicher Leseerfolg steht in sourceStatus.

ErrorNumberOut/ErrorMessageOut bleiben ausschließlich native SQL-Fehler der Sammlung oder Ableitung. Ein gespeichertes OnError-Ereignis wird nicht als SQL-Exception des Analyzers ausgegeben und sein message-Text nicht in ErrorMessageOut umgedeutet. Native Fehler dürfen ihre tatsächlichen vollständigen Meldungen behalten.

### execution

Eine nicht leere Sammlung liefert genau eine Executionzeile. FirstObservedTime und LastObservedTime sind MIN/MAX der vorhandenen starttime-Werte des Puffers, keine Paketstart-/Endegarantie. Event-, Error-, Warning-, TaskFailed- und CancelRequest-Counts zählen ausschließlich den Puffer. SourceCount zählt DISTINCT der nicht NULL SourceIds. Counts beziehen sich auch bei Trunkierung nur auf den analysierten Ausschnitt und haben IsCompleteSlice=0. Eine leere sichtbare Sammlung erzeugt keine künstliche Executionzeile.

BoundaryStatus beruht ausschließlich auf PackageStart/PackageEnd: PAIRED bei genau einem vollständig zeitlich gültigen Paar derselben nicht NULL SourceId; START_ONLY oder END_ONLY bei genau einem entsprechenden Einzelereignis; ABSENT, wenn keines existiert; andernfalls AMBIGUOUS. PackageDurationMs wird nur für PAIRED berechnet. Es ist keine Summe paralleler Taskzeiten.

ObservedOutcome wird in dieser Priorität bestimmt: ERROR_EVENT_OBSERVED bei mindestens einem OnError; sonst TASK_FAILURE_OBSERVED bei OnTaskFailed; sonst CANCEL_REQUEST_OBSERVED bei OnQueryCancel; sonst COMPLETION_EVENT_PAIR_OBSERVED bei BoundaryStatus=PAIRED; sonst INCOMPLETE_OR_UNRESOLVED. Kein dieser Werte behauptet PackageSuccess oder eine technische Root Cause.

### iterations

Für jede nicht NULL SourceId werden die drei Paararten VALIDATE (OnPreValidate/OnPostValidate), EXECUTE (OnPreExecute/OnPostExecute) und PACKAGE (PackageStart/PackageEnd) unabhängig betrachtet. SourceName dient der Anzeige, niemals der Identität. Der nur aus den beiden jeweiligen Eventnamen bestehende Teilstrom wird nach id sortiert.

Ein streng alternierender Start-/Endstrom liefert die aufeinanderfolgenden Paare. Genau ein anfängliches Endereignis beziehungsweise ein abschließendes Startereignis darf zusätzlich als END_ONLY beziehungsweise START_ONLY erscheinen. Enthält der verbleibende Teilstrom zwei Starts oder zwei Ends unmittelbar hintereinander, ist die ganze SourceId/Paarart-Gruppe AMBIGUOUS: Jedes ihrer Ereignisse bleibt als einzelne ungepaarte Zeile erhalten; es wird keine FIFO-/Stack-/Nearest-Time-Zuordnung erfunden. Fehlende SourceId ergibt ebenfalls eine ungepaarte UNRESOLVED_SOURCE-Zeile je erkanntem Paarereignis.

Bei zugelassenem Paar mit fehlendem Zeitwert lautet PairStatus PAIRED_TIME_UNKNOWN; bei EndTime vor StartTime NON_MONOTONIC_TIME. Beide behalten ihre Log-IDs, aber DurationMs=NULL. Sonst PAIRED mit DATEDIFF_BIG(millisecond, StartTime, EndTime); dieser Wert besitzt die Granularität einer Millisekunden-Grenzzählung. IterationOrdinal nummeriert Zeilen innerhalb des Aufrufs nach SourceId, Paarart und erstem vorhandenen LogId; es ist keine stabile Paketiteration. SampleIsPartial zeigt für jede Zeile, ob der Eingabepuffer unvollständig ist. Ein Start am Ende eines gekappten Puffers ist kein Nachweis eines tatsächlich nicht beendeten Tasks.

### errorChain und loggingQuality

errorChain enthält alle vier relevanten Ereignisarten ohne Deduplizierung in id-Reihenfolge. PreviousRelevantLogId verweist lediglich auf die vorherige solche Zeile desselben Puffers; RelationKind ist immer TEMPORAL_ONLY. Ein zeitlich früher Fehler wird nicht automatisch Ursache späterer Fehler. Eltern-/Kindbeziehungen und PackagePath werden nicht erfunden.

loggingQuality unterscheidet Beobachtung und Schlussgrenze. Fehlende Fehler- oder Performanceereignisse beweisen weder fehlende Loggingkonfiguration noch Fehlerfreiheit. Verbindliche QualityCodes sind EVENT_BUFFER_TRUNCATED, PACKAGE_BOUNDARY_ABSENT, PACKAGE_BOUNDARY_UNRESOLVED, PAIRING_AMBIGUOUS, PAIRING_INCOMPLETE, SOURCE_ID_MISSING, EVENT_NAME_MISSING, EVENT_TIME_MISSING, NON_MONOTONIC_TIME, UNKNOWN_EVENT_NAME, NO_ERROR_EVENTS_OBSERVED, ERROR_MESSAGE_MISSING und CONSISTENT_SNAPSHOT_NOT_GUARANTEED. Der letzte Code erscheint nach gültiger Materialisierung und erfolgreicher Ableitung als INFO. NO_ERROR_EVENTS_OBSERVED und PACKAGE_BOUNDARY_ABSENT sind INFO; die übrigen Codes WARNING. Die positiven Prüfhinweise benennen nur tatsächlich beobachtete Bedingungen; der Codebestand ist keine erwartete Mindestzahl von Quellereignissen.

PAIRING_INCOMPLETE erscheint genau dann, wenn mindestens eine iterations-Zeile START_ONLY oder END_ONLY besitzt. Ihre Severity ist WARNING; AffectedRowCount zählt die DISTINCT LogIds der vorhandenen Einzelereignisse dieser beiden Zustände über alle drei Paararten. Ein Ereignis hat nur eine der sechs Paarrollen; es wird hier nicht zweimal gezählt. Die Qualitätszeile und das gleichnamige DERIVED-Finding entstehen vor Exportkappung und setzen das Modul auf AVAILABLE_LIMITED/IsPartial=1. Das gilt auch bei gekapptem Eingabepuffer und behauptet keinen tatsächlich nicht beendeten Task. AMBIGUOUS und UNRESOLVED_SOURCE werden separat durch PAIRING_AMBIGUOUS beziehungsweise SOURCE_ID_MISSING ausgewiesen.

ERROR_MESSAGE_MISSING wird ausschließlich bei IncludeMessages=1 und mindestens einem OnError-/OnTaskFailed-Ereignis mit NULL oder DATALENGTH(MessageText)=0 erzeugt. Severity ist WARNING, AffectedRowCount ist die Zahl dieser gepufferten Ereignisse. Das gleichnamige DERIVED-Finding und AVAILABLE_LIMITED/IsPartial=1 machen die fehlende konkrete Textdiagnose sichtbar, ohne eine Ursache für den fehlenden Text zu behaupten. Bei IncludeMessages=0 wird dieser Code nicht erzeugt.

UNKNOWN_EVENT_NAME gilt für Nicht-NULL-Namen außerhalb der vier Diagnose- und sechs Paarereignisnamen. Er kennzeichnet die fehlende Interpretation des Ereignisses, keinen ungültigen SSIS-Eintrag. Für jeden zutreffenden QualityCode existiert vor Ausgabebegrenzung genau eine Zeile. AffectedRowCount zählt die betroffenen Pufferzeilen; für nicht zeilenbezogene Hinweise ist der Wert NULL. Keine Ausgabe führt eine universelle Performance- oder Fehlerbewertung ein.

### 6. Neun Ergebnisschemas in fester RAW-Reihenfolge

Alle Textfelder besitzen explizit COLLATE SQL_Latin1_General_CP1_CS_AS. `NN` bedeutet NOT NULL; jedes andere Feld ist NULL-fähig. Die Spaltenreihenfolge und die angegebenen SQL-Typen sind für RAW und TABLE identisch; JSON übernimmt dieselben fachlichen Werte einschließlich NULL-Feldern. Es gibt keine Identity-Spalte in einem Exportschema.

| Nr. / Name | Spalten in Reihenfolge |
|---|---|
| 1 `moduleStatus` | ModuleName sysname NN; SchemaVersion int NN; LoggingDatabase sysname; LoggingSchema sysname; LoggingTable sysname; ExecutionId uniqueidentifier; MessagesIncluded bit NN; StatusCode varchar(40) NN; IsPartial bit NN; ErrorNumber int; ErrorMessage nvarchar(4000); CollectionTimeUtc datetime2(3) NN |
| 2 `execution` | ExecutionId uniqueidentifier NN; AnalyzedEventCount bigint NN; SourceCount bigint NN; FirstObservedTime datetime; LastObservedTime datetime; ErrorEventCount bigint NN; WarningEventCount bigint NN; TaskFailedEventCount bigint NN; CancelRequestCount bigint NN; BoundaryStatus varchar(40) NN; PackageStartLogId int; PackageEndLogId int; PackageDurationMs bigint; ObservedOutcome varchar(40) NN; FirstErrorLogId int; FirstErrorMessage nvarchar(max); IsCompleteSlice bit NN |
| 3 `timeline` | TimelineOrdinal bigint NN; LogId int NN; ExecutionId uniqueidentifier NN; EventName nvarchar(128); SourceName nvarchar(4000); SourceId uniqueidentifier; EventTime datetime; RawEndTime datetime; DataCode int; PreviousLogId int; DeltaFromPreviousMs bigint; Severity varchar(16) NN; MessageText nvarchar(max) |
| 4 `errorChain` | ErrorOrdinal bigint NN; LogId int NN; ExecutionId uniqueidentifier NN; EventName nvarchar(128); SourceName nvarchar(4000); SourceId uniqueidentifier; EventTime datetime; DataCode int; Severity varchar(16) NN; PreviousRelevantLogId int; RelationKind varchar(40) NN; MessageText nvarchar(max) |
| 5 `iterations` | IterationOrdinal bigint NN; ExecutionId uniqueidentifier NN; SourceId uniqueidentifier; SourceName nvarchar(4000); PairKind varchar(16) NN; StartLogId int; EndLogId int; StartTime datetime; EndTime datetime; DurationMs bigint; PairStatus varchar(40) NN; SampleIsPartial bit NN |
| 6 `loggingQuality` | QualityOrdinal int NN; QualityCode varchar(64) NN; Severity varchar(16) NN; AffectedRowCount bigint; Detail nvarchar(2000) NN |
| 7 `findings` | FindingOrdinal int NN; FindingCode varchar(64) NN; Severity varchar(16) NN; ExecutionId uniqueidentifier NN; EvidenceLevel varchar(32) NN; EvidenceSource nvarchar(160) NN; LogId int; Detail nvarchar(2000) NN |
| 8 `sourceStatus` | SourceOrdinal int NN; SourceName nvarchar(160) NN; StatusCode varchar(40) NN; IsPartial bit NN; ObservedRowCount bigint; ReturnedRowCount bigint; IsTruncated bit NN; ErrorNumber int; ErrorMessage nvarchar(4000); Detail nvarchar(2000) NN; CollectionTimeUtc datetime2(3) NN |
| 9 `warnings` | WarningOrdinal int NN; WarningCode varchar(64) NN; SourceName nvarchar(160); Detail nvarchar(2000) NN |

moduleStatus enthält genau eine Zeile, sourceStatus genau die vier Zeilen mit SourceOrdinal 1–4 und den in Abschnitt 4 festgelegten konstanten SourceNames. Diese beiden Mengen und execution werden nicht durch MaxZeilen gekappt. TimelineOrdinal und ErrorOrdinal beziehen sich auf id ASC. PreviousLogId und DeltaFromPreviousMs beziehen sich auf die vorherige gepufferte Ereigniszeile; fehlende oder rückläufige Zeit ergibt Delta=NULL und einen Qualitätshinweis. SourceName einer gepaarten iterations-Zeile stammt vom Startereignis, sonst vom vorhandenen Einzelereignis; abweichende Namen an derselben SourceId ändern die Zuordnung nicht.

loggingQuality ist nach QualityCode CS_AS geordnet. findings hat genau einen ungruppierten Eintrag pro OnError, OnTaskFailed oder OnQueryCancel und einen Eintrag pro WARNING-QualityCode. Ereignis-FindingCodes sind LEGACY_ERROR_EVENT, LEGACY_TASK_FAILED_EVENT und LEGACY_CANCEL_REQUEST; Severity entspricht der Ereignisklassifikation, EvidenceLevel ist RUNTIME_OBSERVED. Qualitätsfindings verwenden denselben Code wie loggingQuality, LogId=NULL und EvidenceLevel=DERIVED. EvidenceSource ist die konstante Kennzeichnung `Legacy event buffer`. FindingOrdinal ordnet Ereignisfindings zuerst nach LogId und danach Qualitätsfindings nach FindingCode. Native Fehler und Warnungen sind keine Quelle frei interpolierter Nutzdaten in diesen Detailtexten.

warnings enthält feste Modul-/Sammlungsgrenzen: EXECUTION_NOT_VISIBLE_OR_ABSENT, HIGH_IMPACT_CONFIRMATION_REQUIRED, SOURCE_SCHEMA_UNSUPPORTED, SOURCE_IDENTITY_CHANGED, SUPPORTING_INDEX_NOT_OBSERVED, SOURCE_INDEX_METADATA_UNAVAILABLE, DUPLICATE_LOG_ID_OBSERVED, TIME_BUDGET_EXHAUSTED, SOURCE_EVENTS_TRUNCATED, RESULT_TRUNCATED, TIMELINE_NOT_REQUESTED und MESSAGES_NOT_REQUESTED, jeweils nur bei tatsächlich zutreffender Bedingung. warnings bleibt als Steuerdiagnostik ungekürzt. Pro Code außer RESULT_TRUNCATED existiert höchstens eine Zeile; SourceName bezeichnet den ersten auslösenden Schritt der festen Quellenfolge oder NULL für einen reinen Parameterfehler. Für RESULT_TRUNCATED bezeichnet SourceName genau den gekappten ResultName aus den fünf folgenden Fachdetailmengen; je ResultName existiert höchstens eine solche Zeile. SUPPORTING_INDEX_NOT_OBSERVED entsteht höchstens einmal mit SourceName=sourceIndexes und allein ohne IsPartial-Erhöhung. SOURCE_INDEX_METADATA_UNAVAILABLE entsteht höchstens einmal ebenfalls mit SourceName=sourceIndexes; tatsächliche native Indexfehler bleiben zusätzlich in sourceStatus2. Die Zeilenidentität ist damit WarningCode plus SourceName, wobei NULL als eigener Wert gilt. Es gibt höchstens elf einfache Warnungen plus fünf RESULT_TRUNCATED-Warnungen, insgesamt höchstens 16 Zeilen. Die fertige Menge wird nach WarningCode CS_AS, dann SourceName CS_AS mit NULL zuerst geordnet und erhält danach ihre unveränderten WarningOrdinals. Alle dynamischen Details bestehen aus freigegebenen Metadaten, Counts und festen Beschreibungstexten; keine verworfenen Payloadwerte werden aufgenommen.

Positive MaxZeilen begrenzt nach der Ableitung zusätzlich jede der fünf Fachdetailmengen timeline, errorChain, iterations, loggingQuality und findings auf die ersten N Zeilen ihrer definierten Ordnung. Deren Ordinals werden vor Exportkappung vergeben und nicht neu nummeriert. Danach wird je tatsächlich gekappter Menge die eine RESULT_TRUNCATED-Steuerwarnung erzeugt; warnings selbst wird weder gekappt noch rekursiv um weitere Trunkierungswarnungen ergänzt. sourceStatus4 hält ungekappte Counts der erzeugten/ausgegebenen Fachdetailzeilen und die betroffenen ResultNames in seinem festen Detailformat fest. Dieses Detailformat lautet für jede der fünf Mengen `ResultName:Observed=<n>;Returned=<n>;Truncated=<0|1>` in der oben genannten Mengenreihenfolge; es enthält ausschließlich die fünf festen Namen und Zahlen. Der sourceStatus4-Count ist die Summe genau dieser fünf Counts vor beziehungsweise nach Exportkappung, ohne die Steuerdiagnostik warnings. Timeline-Opt-out zählt als Observed=0/Returned=0/Truncated=0; die zugrunde liegende Ereignissammlung bleibt unverändert.

### 7. Status, Partialität und Fehlerisolation

| Bedingung | Modulstatus / IsPartial | Bedeutung |
|---|---|---|
| Vollständig gelesener nicht leerer Scope ohne Ableitungs- oder Exportgrenzen | AVAILABLE / 0 | Gültige Sammlung; beobachtete OnError-/TaskFailed-Ereignisse ändern den Analyzerstatus nicht. |
| Gültiger Quellzugriff, keine sichtbaren Zeilen | AVAILABLE_EMPTY / 0 | Kein Abwesenheitsnachweis für eine Ausführung; warning EXECUTION_NOT_VISIBLE_OR_ABSENT. |
| Sentinel, Detailkappung, mehrdeutige/unvollständige zeitliche Paare, fehlende SourceId/Eventname/Zeit, fehlender eingeschlossener Fehlertext oder unbekannte Ereignisinterpretation | AVAILABLE_LIMITED / 1 | Beobachtete Daten bleiben mit ihrer Einschränkung erhalten. Reine INFO-Hinweise allein ändern die Partialität nicht. |
| Parameter oder erforderliche High-Impact-Bestätigung ungültig | INVALID_PARAMETER / 1 | Kein Ereigniszugriff und kein neues natives Fehlerpaar. Frühe Parameterfehler vor Quellenzugriff behalten NULL; ein erst nach Metadaten erkanntes Gate bewahrt ein zuvor tatsächlich erfasstes erstes natives Fehlerpaar in Modul/OUTPUTs. |
| Quelle nicht sichtbar, nicht vorhanden oder nicht unterstützt | SOURCE_UNAVAILABLE / 1 | Metadaten allein unterscheiden Unsichtbarkeit und Abwesenheit nicht sicher. |
| Tatsächlicher nativer Berechtigungsfehler 229/262/297/300/371 | DENIED / 1 | Native Fehlernummer und vollständige Fehlermeldung bleiben erhalten. |
| Andere native Fehler, einschließlich 1222; erkanntes Identitätsrennen oder doppelt materialisierte LogId | ERROR_HANDLED / 1 | Quellfehler beziehungsweise Integritätsbefund wird isoliert; kein erfundenes erfolgreiches Leerresultat. Nichtnative Gründe erzeugen kein eigenes Fehlerpaar; ein früheres tatsächliches natives Paar bleibt in Modul/OUTPUTs erhalten. |
| Kooperatives Budget vor einem notwendigen weiteren Schritt ausgeschöpft | AVAILABLE_LIMITED / 1 | Betroffener und folgende notwendige Schritte sind NOT_READ; TIME_BUDGET_EXHAUSTED. |

Native Fehler 207/208/911/916/942 werden SOURCE_UNAVAILABLE zugeordnet; 916 allein ist kein pauschaler DENIED-Nachweis. Fehlertexte sind Laufzeitausgaben und keine zur Veröffentlichung freigegebenen Daten. Synthetische Zustände erzeugen keine eigene native Fehlernummer oder Fehlermeldung; sie löschen jedoch kein zuvor tatsächlich erfasstes erstes natives Paar aus moduleStatus oder den OUTPUTs. Quellbezogene synthetische Befunde behalten ihr eigenes NULL-Paar. Die erste tatsächliche native Fehlerpaarung in Quellenfolge 1–4 wird für die Modul-OUTPUTs beibehalten; Quellzeilen behalten ihren eigenen Fehler. Notwendige nachfolgende Schritte werden nach einem nicht erfüllten erforderlichen Zulassungsgate nicht ausgeführt. sourceIndexes ist ausdrücklich kein solches Gate: Ein Fehler nur dieser beratenden Quelle blockiert die gültige Ereignissammlung nicht. Gelingt diese samt Ableitung, lautet der Modulstatus wegen der fehlenden Indexmetadaten AVAILABLE_LIMITED/IsPartial=1; der erste tatsächlich erhobene native Indexfehler bleibt in den Modul-OUTPUTs erhalten. Scheitert anschließend eine erforderliche Quelle, bestimmt deren Status den Modulstatus und das erste native Fehlerpaar bleibt dennoch erhalten. Das ist die ausdrückliche Ausnahme zur vorstehenden Modulstatuszuordnung für ausschließlich optionale Indexfehler; sourceStatus2 behält seinen eigenen ursprünglichen Status.

sourceStatus verwendet dieselben Ergebnisstatus sowie NOT_READ für nicht angesprochene Schritte. Vor einem Datenzugriff sind Datenzeilenzahlen NULL, nicht 0. Metadaten- und Indexcounts zählen ausschließlich die tatsächlich erfassten Metadatenzeilen des einen Objekts; sie sind keine Logereigniszahlen. sourceEvents zählt nur nach erfolgreicher Materialisierung und Integritätsprüfung. Nach verworfenem Puffer wegen Fehler, Identitätswechsel oder doppelter id bleiben seine Counts NULL. eventDerivation ist erst AVAILABLE oder AVAILABLE_LIMITED, wenn die Ableitung vollständig aus einem gültigen Puffer beendet wurde; bei notwendiger Unterbrechung wird keine halbe Ableitung exportiert.

Bei leerem Puffer bleiben execution, timeline, errorChain, iterations und findings leer. loggingQuality darf nur den tatsächlich zutreffenden Hinweis CONSISTENT_SNAPSHOT_NOT_GUARANTEED enthalten; fehlende Package-/Fehlerereignisse werden im Leerfall nicht als zusätzliche Mängel abgeleitet. IncludeTimeline=0 unterdrückt nur diesen Export mit TIMELINE_NOT_REQUESTED und führt allein nicht zu IsPartial=1. IncludeMessages=0 ist davon unabhängig: errorChain, execution und CONSOLE behalten ihre jeweils definierten Textfelder, deren Wert dann NULL ist; MESSAGES_NOT_REQUESTED erscheint auch bei leerem Scope oder vorzeitigem Quellfehler als Steuerhinweis auf den gewählten Opt-out.

### 8. Gemeinsamer Ausgabe- und Installationsvertrag

RAW liefert immer alle neun typisierten Resultsets in der festgelegten Reihenfolge, auch für Parameterfehler, leere oder nicht verfügbare Quellen. TABLE exportiert nur die gültig gemappten Namen über die gemeinsamen Prepare-/Write-Helper. NONE erzeugt keine fachlichen Grids. JSON enthält Metadaten mit ModuleName, SchemaVersion, CollectionTimeUtc, StatusCode und IsPartial sowie die neun gleichnamigen Arrays; leere Mengen sind `[]`, NULL-Felder bleiben enthalten. Alle Modi verwenden denselben materialisierten und begrenzten Exportstand. Ein Fehler des Framework-Mappings bleibt 51011 und wird nicht zu einem fachlichen Quellenstatus umgedeutet.

CONSOLE liefert über InternalEmitConsoleResult genau eine Modul-/Executionübersicht oder eine verständliche Status-/Leerzeile. Die endgültige fachliche Spaltenfolge lautet Status varchar(40), Unvollständig bit, ExecutionId uniqueidentifier, AnalysierteEreignisse bigint, BeobachteterAusgang varchar(40), ErsteFehlerLogId int, ErsterFehlertext nvarchar(max), ErsterZeitpunkt datetime, LetzterZeitpunkt datetime und Hinweis nvarchar(200). ErsterFehlertext stammt unverändert aus execution.FirstErrorMessage; er wird nicht auf die Länge des getrennten Hinweis-Felds gekürzt. Der zentrale Renderer ergänzt ausschließlich seinen bestehenden Ergebnisbezeichner `SSIS-Legacy-Ausführung`. Es gibt keine weiteren Resultsets aus Helperaufrufen oder Diagnose-SELECTs.

Die Umsetzung bindet eine neue kanonische Einzelquelle unter `Code/10_SSIS/` in den bestehenden Standalone- und Gesamtinstaller ein. Bezeichnung, konkrete Inventare, Navigator, Guide, Testregistrierung und OPS-005-Adapter werden gemeinsam fortgeschrieben. Das öffentliche Abhängigkeitsinventar verwendet ausschließlich generische Quellen und keine konkreten Runtimeidentitäten. SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION, solange andere Pflichtumfänge offen sind.


Die synthetische Integrationssuite 202 prüft das kompatible Tabellenformat. Die getrennte [Providerabnahme vom 18. Oktober 2026](SSIS_Package_and_Execution_Analysis_Plan.md#legacy-providerabnahme-vom-18-oktober-2026) bestätigt vier tatsächlich ausgeführte synthetische Paketfälle mit zwölf gebundenen Cap-Einzelbelegen auf Windows SQL/SSIS 17.0.1000.7. Neun Einzelbelege stammen aus insgesamt fehlgeschlagenen früheren Versuchen; ein neuer gemeinsamer Vierfällelauf wird nicht behauptet. Zusätzliche Rollen und ältere native Engines bleiben offen. Der öffentliche Revision-3-Vertrag bleibt unverändert.

## Freigegebene Erweiterung: Legacy-Tasklaufzeiten und Loggingabdeckung vom 18. Oktober 2026

**Status:** Vertrag am 18. Oktober 2026 ausdrücklich menschlich freigegeben; Umsetzung und Abnahme werden getrennt nachgewiesen.

**Zuordnung:** begrenzte Erweiterung von `SSIS-001`, Backlogschritt 1 und Laufzeitteil von Schritt 2.

**Liefergegenstand:** begrenzte Erweiterung um beobachtete Taskintervalle und Ereignisabdeckung, einschließlich Abnahme und regulärer PR-Lieferung.

Die nachfolgenden Festlegungen konkretisieren die freigegebene Erweiterung.
Der Revision-3-Vertrag bleibt für Aufrufe ohne Opt-in erhalten. Die
Procedureversion ist 1.1.0; die Opt-in-Ausgabe verwendet SchemaVersion 2.
Die Freigabe umfasst die Implementierung und den hier begrenzten Abnahmeplan.
Die Tabellen in G und H beschreiben Sollfälle; ihr Ausführungsnachweis wird
im Architekturplan getrennt von dieser Spezifikation geführt.

### A. Entscheidungsfrage und begrenzter Umfang

Welche Ausführungs- und Validierungsintervalle sind für beobachtete
Ausführungsquellen einer bekannten Legacy-Execution gespeichert, welche
Aggregationen erlauben ihre eindeutigen Zeitpaare und welche Grenzen der
Loggingabdeckung sind im gelesenen Ausschnitt sichtbar?

Die Erweiterung verwendet dieselbe explizite lokale Loggingquelle und genau
eine Execution-ID wie v1. Sie liest die Quelle genau einmal in den bestehenden
N+1-Puffer und verwendet dessen geprüften, gegebenenfalls gekappten Bestand.
Sie ergänzt die beiden Resultsets `taskDurations` und `taskLoggingCoverage`.
Einzelintervalle und ihre Log-IDs stehen weiterhin in `iterations`.
Es wird kein zweiter Paaralgorithmus eingeführt und kein früher mehrdeutiger
Strom nachträglich zu gültigen Paaren umgedeutet.

Der Name `taskDurations` ist kein Nachweis des Executable-Typs. Eine Source-ID
kann auch Paket oder Container bezeichnen. Ohne gesonderte Paketbindung bleibt
SourceType stets `UNRESOLVED`; Task, Container, Elternbeziehung und tatsächliche
Schleifeniteration werden nicht aus Namen abgeleitet. Ein nicht protokollierter
Task kann ohne erwartetes Paketinventar nicht als fehlend identifiziert werden.
Loggingabdeckung bedeutet hier ausschließlich beobachtete Ereignisabdeckung,
nicht Prüfung der Loggingkonfiguration oder Vollständigkeit eines Paketlaufs.

Freitextdecoder, Fehlerursachen oder Propagationsgruppen, Retry-/Loop-Erkennung,
exklusive Taskzeiten, CPU-Zeit, kritischer Pfad, Zeilenfluss, Durchsatz,
Lookup-/Cachewerte, Historie, eigene Kennzahlen und DTSX-/SSISDB-Korrelation
gehören nicht zu diesem Slice. Der bestehende Meldungsdefault und seine
vollständigen gespeicherten Texte bleiben erhalten.

### B. Aufruf, Kompatibilität und Ausgabeversionierung

Die bestehenden 20 Parameter behalten Position, Namen, Typ, Default und
Bedeutung. Ausschließlich am Ende der Signatur wird folgender Parameter
ergänzt; vorhandene positionale Aufrufe behalten dadurch ihre Zuordnung:

| Position | Parameter | Typ und Default | Bedeutung |
|---|---|---|---|
| 21 | `@IncludeTaskAnalysis` | `bit = 0` | Explizites Opt-in für beide neuen Mengen; NULL wird wie 0 behandelt. |

Bei 0 bleiben RAW9, die neun TABLE-Namen, die neun JSON-Arrays,
SchemaVersion 1, die vier sourceStatus-Zeilen und das bisherige CONSOLE-Schema
unverändert. Es gibt weder neue leere Zusatzarrays noch zusätzliche Status-
oder Qualitätszeilen. Unvermeidlich aufrufabhängige Zeitwerte werden bei
späteren Regressionsvergleichen nur nach dem bestehenden Vertrag verglichen.

Bei 1 liefert RAW die bisherigen neun Resultsets in unveränderter Reihenfolge,
anschließend `taskDurations` und `taskLoggingCoverage`, insgesamt elf.
Die 94 Spalten der bisherigen neun Schemas behalten Typ und Reihenfolge.
moduleStatus.SchemaVersion und die SchemaVersion der JSON-Metadaten sind 2.
JSON ergänzt genau die beiden gleichnamigen Arrays sowie in den Metadaten
`TaskAnalysisCatalogVersion` als JSON-Zahl 1. Ein angefordertes Array bleibt
auch bei Fehler oder Leermenge vorhanden und enthält dann `[]`.

TABLE akzeptiert bei eingeschaltetem Opt-in die elf Namen. Mappings für einen
neuen Namen bei ausgeschaltetem Opt-in sind ungültig und werfen vor jedem
Quellzugriff unverändert 51011. Ein gültiger benannter Export erhält auch bei
semantisch ungültigen Fachparametern seine typisierten leeren Zielschnemas.
Die übrige Reihenfolge Hilfe, Ausgabemodus, TABLE-Vorbereitung und fachliche
Parameterprüfung bleibt wie in Revision 3. Hilfe greift auf keine Quelle zu.
Ein teilweises gültiges Mapping folgt dem bestehenden Frameworkvertrag;
unbenannte Mengen werden nicht in ein anderes Ziel geschrieben.

CONSOLE bleibt genau ein Resultset. Bei Opt-in werden nach den bestehenden
Spalten zusätzlich `BeobachteteQuellen bigint`, `GueltigeIntervalle bigint`
und `UngeklaerteGrenzereignisse bigint` angefügt. Sie zählen den intern
abgeleiteten Bestand vor Exportbegrenzung: verschiedene nicht-NULL Source-IDs,
gültige EXECUTE-/VALIDATE-Paare sowie ungepaarte Start-/Endereignisse,
mehrdeutige Einzelgrenzen und erkannte Paarereignisse ohne Source-ID.
Ein zeitlich ungültiges, aber zugeordnetes Paar zählt nicht als ungeklärte
Grenze; es bleibt über die neuen Detailmengen sichtbar. Bei gültigem leerem
Puffer sind die drei Zähler 0, vor erfolgreicher Zusatzableitung NULL.
Der erste Fehlertext und die bisherigen Spaltenwerte bleiben erhalten,
abgesehen von den ausdrücklich erweiterten Modulstatusregeln in Abschnitt F.
NONE liefert weiterhin kein fachliches Resultset; angefordertes JSON bleibt
modusunabhängig. Print-Ausgaben erzeugen keine Zusatzgrids.

### C. Ereigniskatalog, Identität und Zeitbasis

Katalogversion 1 enthält exakt die folgenden strukturellen Zuordnungen.
Die Eventnamen werden unverändert und gemäß CS_AS verglichen. Sprache oder
Inhalt von message werden weder für Paarbildung noch für Kennzahlen verwendet.

| Eventnamen | Rolle in dieser Erweiterung |
|---|---|
| `OnPreExecute`, `OnPostExecute` | Start und Ende der Paarart EXECUTE. |
| `OnPreValidate`, `OnPostValidate` | Start und Ende der Paarart VALIDATE. |
| `PackageStart`, `PackageEnd` | Bekannte andere Ereignisse; ihre bestehende PACKAGE-Auswertung bleibt v1 vorbehalten. |
| `OnError`, `OnTaskFailed`, `OnWarning`, `OnQueryCancel` | Bekannte andere Ereignisse; keine Ableitung von Erfolg, Retry oder Ursache. |
| Alle übrigen Nicht-NULL Eventnamen | Für diesen Katalog nicht interpretiert; keine Freitext- oder Codeheuristik. |
| NULL | Fehlender Eventname, getrennt von unbekannten Namen gezählt. |

Ein Daueraggregat wird durch ExecutionId, nicht-NULL SourceId und PairKind
bestimmt. Verschiedene Source-IDs bleiben auch bei gleichem SourceName getrennt.
Verschiedene Execution-IDs werden nie verbunden. Namen sind Anzeigeattribute.
Für eine Source-ID wird der einzige vorhandene nicht-NULL Name verwendet,
wenn alle nicht-NULL Namen ordinal dieselben UTF-16-Bytes besitzen. Gibt es
mehrere solche Werte, sind SourceName=NULL und SourceNameConflict=1; fehlen
alle Namen, sind SourceName=NULL und SourceNameConflict=0. Es gibt keine
Auswahl eines beliebigen MIN-/MAX-Namens und kein Zusammenführen nach Namen.

Der bestehende iterations-Vertrag bleibt maßgeblich: Nach LogId geordnete,
streng alternierende Start-/Endströme liefern Paare. Ein anfängliches Ende
und ein abschließender Start bleiben Einzelereignisse. Zwei aufeinanderfolgende
Starts oder Ends machen die ganze SourceId/PairKind-Gruppe mehrdeutig; ihre
Grenzereignisse bleiben ungepaart. NULL SourceId wird nicht durch einen
synthetischen GUID ersetzt. Fehlende Zeitwerte und rückläufige Paarzeiten
behalten ihre IDs, liefern aber keine Dauer. Ein gleicher Start- und Endzeitwert
liefert ein gültiges Intervall mit 0 ms. IDs sind nur die bestehende
Ordnungshilfe, kein Beweis der tatsächlichen Engineausführungsreihenfolge.

EventTime stammt unverändert aus starttime. Die native endtime-Spalte wird
nicht als Endpunkt verwendet. Es gibt weder erfundene UTC-Konvertierung noch
Präzisionsgewinn: DurationMs bleibt DATEDIFF_BIG(millisecond,StartTime,EndTime)
und damit eine Millisekunden-Grenzzählung auf gespeicherten datetime-Werten.
Der Hersteller beschreibt Source-ID und selektierbare Loggingereignisse in
[sysssislog](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/sysssislog-transact-sql?view=sql-server-ver17)
und [SSIS Logging](https://learn.microsoft.com/en-us/sql/integration-services/performance/integration-services-ssis-logging?view=sql-server-ver17).
Der Verzicht auf eine Tasktyp- oder Konfigurationsbehauptung ist die bewusste
Aussagegrenze dieses Vertrags, keine zusätzliche Herstellerzusage.

### D. Zwei zusätzliche physische Schemas

Die folgenden Spaltenfolgen gelten identisch für RAW und TABLE. `NN` bezeichnet
NOT NULL; alle anderen Felder sind nullable. Jedes Textfeld besitzt explizit
COLLATE SQL_Latin1_General_CP1_CS_AS. Es gibt keine Identity-Spalte.

| Resultset | Spalten in Reihenfolge |
|---|---|
| `taskDurations` | TaskDurationOrdinal bigint NN; ExecutionId uniqueidentifier NN; SourceId uniqueidentifier NN; SourceName nvarchar(4000); SourceType varchar(24) NN; PairKind varchar(16) NN; BasisFirstLogId int NN; BasisLastLogId int NN; EvidenceLogIdsJson nvarchar(max) NN; PairRowCount bigint NN; ValidPairCount bigint NN; UnknownTimePairCount bigint NN; NonMonotonicPairCount bigint NN; OpenStartCount bigint NN; OpenEndCount bigint NN; AmbiguousBoundaryCount bigint NN; TotalDurationMs decimal(38,0); AverageDurationMs decimal(38,6); MinDurationMs bigint; MaxDurationMs bigint; SourceNameConflict bit NN; InputIsTruncated bit NN; MetricStatus varchar(40) NN |
| `taskLoggingCoverage` | CoverageOrdinal bigint NN; ExecutionId uniqueidentifier NN; SourceId uniqueidentifier; UnresolvedLogId int; SourceName nvarchar(4000); SourceType varchar(24) NN; BasisFirstLogId int NN; BasisLastLogId int NN; EvidenceLogIdsJson nvarchar(max) NN; ObservedEventCount bigint NN; ExecuteStartCount bigint NN; ExecuteEndCount bigint NN; ValidateStartCount bigint NN; ValidateEndCount bigint NN; KnownOtherEventCount bigint NN; UnknownEventNameCount bigint NN; MissingEventNameCount bigint NN; MissingEventTimeCount bigint NN; AmbiguousBoundaryCount bigint NN; UnresolvedBoundaryCount bigint NN; IncompleteBoundaryCount bigint NN; InvalidTimePairCount bigint NN; SourceNameConflict bit NN; InputIsTruncated bit NN; CoverageStatus varchar(40) NN |

`taskDurations` enthält genau eine Zeile je nicht-NULL SourceId und Paarart
EXECUTE oder VALIDATE mit mindestens einem entsprechenden Grenzereignis.
PACKAGE wird hier nicht ausgegeben. TaskDurationOrdinal ordnet nach SourceId
und danach PairKind CS_AS. PairRowCount zählt die zugehörigen internen
iterations-Zeilen vor deren Exportkappung. Er ist genau die Summe aus
ValidPairCount, UnknownTimePairCount, NonMonotonicPairCount, OpenStartCount,
OpenEndCount und AmbiguousBoundaryCount. Die Counts zählen je nach Namen
Paare oder einzelne Grenzen; sie werden nicht als Taskausführungsanzahl ausgegeben.

Nur PAIRED-Zeilen mit nicht-NULL und nicht negativer DurationMs gehen in
TotalDurationMs, AverageDurationMs, MinDurationMs und MaxDurationMs ein.
Ohne gültiges Paar sind alle vier Werte NULL; eine echte Nullzeit bleibt 0.
Die Summe wird in decimal(38,0) gebildet. Der Mittelwert ist diese Summe
geteilt durch ValidPairCount und kaufmännisch auf sechs Nachkommastellen
gerundet; Nullmengen werden nicht als Nenner verwendet. Maximum und Minimum
beziehen sich auf dieselbe gültige Teilmenge. Summen mehrerer Vorkommen oder
Quellen sind weder Paketlaufzeit noch CPU-Zeit oder exklusive Ausführungszeit.
Es gibt keine Subtraktion von Kindzeiten und keine erfundene Parallelitätskorrektur.

MetricStatus verwendet die erste zutreffende Bedingung in dieser Priorität:
TRUNCATED_INPUT, AMBIGUOUS_BOUNDARIES, INCOMPLETE_BOUNDARIES,
INVALID_BOUNDARY_TIME, NO_VALID_PAIRS, OBSERVED_INTERVALS. INVALID_BOUNDARY_TIME
gilt bei UnknownTimePairCount oder NonMonotonicPairCount größer 0.
Eine gültige Teilmenge darf trotz unvollständiger Grenzen Zahlen liefern;
Status und Counts kennzeichnen deren begrenzte Basis. Die Werte werden nicht
als vollständige Kennzahlen des ursprünglichen Laufs bezeichnet.

`taskLoggingCoverage` enthält eine Zeile je nicht-NULL SourceId des gesamten
gültigen Ereignispuffers. Jedes Ereignis ohne SourceId erhält dagegen seine
eigene Zeile mit SourceId=NULL und UnresolvedLogId=LogId. Bei bekannten IDs
ist UnresolvedLogId=NULL. Dadurch werden unbekannte Quellen nicht miteinander
verschmolzen. CoverageOrdinal ordnet bekannte Source-IDs zuerst nach SourceId,
danach unbekannte Quellen nach UnresolvedLogId. SourceType ist in beiden
Mengen konstant UNRESOLVED. Daueranzeigen übernehmen Name und Konfliktflag
aus der Coveragezeile derselben Source-ID.

ObservedEventCount zählt alle Pufferereignisse dieser Coveragezeile. Die vier
Grenzcounts, KnownOtherEventCount, UnknownEventNameCount und MissingEventNameCount
bilden eine disjunkte Zerlegung dieses Counts nach Abschnitt C. MissingEventTimeCount
zählt davon unabhängig alle Ereignisse mit EventTime=NULL. AmbiguousBoundaryCount
zählt EXECUTE-/VALIDATE-Einzelgrenzen mit PairStatus AMBIGUOUS;
UnresolvedBoundaryCount die erkannten vier Grenzereignisse ohne SourceId;
IncompleteBoundaryCount die einzelnen START_ONLY-/END_ONLY-Grenzen.
InvalidTimePairCount zählt PAIRED_TIME_UNKNOWN- und NON_MONOTONIC_TIME-Paare.
PACKAGE-Grenzen erhöhen diese vier Zusatzcounts nicht.

CoverageStatus verwendet die erste zutreffende Bedingung:
UNRESOLVED_SOURCE, TRUNCATED_INPUT, AMBIGUOUS_BOUNDARIES,
INCOMPLETE_BOUNDARIES, INVALID_BOUNDARY_TIME, NO_BOUNDARY_OBSERVED,
OBSERVED_BOUNDARIES. INVALID_BOUNDARY_TIME erfordert InvalidTimePairCount>0.
NO_BOUNDARY_OBSERVED bedeutet, dass alle vier Grenzcounts 0 sind. Kein Status
heißt COMPLETE oder LOGGING_DISABLED. Auch OBSERVED_BOUNDARIES belegt keine
vollständige Loggingkonfiguration oder vollständige Taskliste.

EvidenceLogIdsJson ist in RAW und TABLE ein nvarchar-Wert mit einem gültigen,
aufsteigend sortierten JSON-Array eindeutiger ganzzahliger Log-IDs. Im äußeren
JSON wird derselbe Wert als JSON-String transportiert, nicht automatisch als
verschachteltes Array. Für taskDurations enthält er die Grenzereignis-IDs
der jeweiligen SourceId/PairKind-Gruppe; für Coverage alle IDs der jeweiligen
Gruppe beziehungsweise die eine ungeklärte Log-ID. BasisFirstLogId und
BasisLastLogId sind deren Minimum und Maximum. Der Namensbeleg einer Dauerzeile
ist über die Coveragezeile derselben Source-ID nachvollziehbar. Es gibt keine
Annahme, dass zwischen Minimum und Maximum nur Ereignisse dieser Gruppe liegen.

### E. Materialisierung, Grenzen und Eigenlast

Die neuen Mengen entstehen aus dem internen geprüften Puffer und den internen
iterations-Zeilen vor allen fachlichen Exportkappungen. IncludeTimeline=0
unterdrückt weiterhin nur den Timelineexport. IncludeMessages=0 verhindert
weiterhin den fachlichen message-Zugriff; die neuen Kennzahlen benötigen
weder message noch datacode, computer, operator oder databytes.

@MaxZeilen bleibt die bestehende gemeinsame Ereignis- und Exportgrenze.
Cap 0 oder NULL bedeutet unbegrenzt und benötigt weiterhin HighImpactConfirmed=1.
Ein positiver Cap N liest höchstens N+1 Ereignisse; der Sentinel wird nach
der bestehenden Duplikatprüfung entfernt. Er nimmt an keinem neuen Count,
Namen, Zeitwert oder Evidenzarray teil. Bei Trunkierung ist InputIsTruncated=1
in allen neuen Zeilen; es gibt keine Extrapolation auf ausgelassene Ereignisse.

Bei E gepufferten Ereignissen entstehen höchstens E Dauerzeilen und E
Coveragezeilen. Jede Log-ID steht höchstens einmal in einer Dauerbasis und
einmal in einer Coveragebasis. Damit sind beide Zeilenmengen bei positivem
Ereigniscap bereits höchstens N groß; es wird kein separater neuer Ausgabecap
eingeführt. Der Vertrag verspricht keine feste Speicher-, CPU- oder Lesemenge.
Die neuen Sortierungen, Aggregationen und Evidenzarrays benötigen zusätzliche
tempdb- und Arbeitsspeicherkapazität. Kostenklasse bleibt LOW_HIGH_OPT_IN;
fehlende Quellindizes bleiben beratend und begründen keine zusätzliche Indexpflicht.
Ein bestehendes MAX-Text-Gate wird durch das Opt-in nicht abgeschwächt.

### F. Quellenstatus, Fehlerisolation und Zeitbudget

Nur bei Opt-in ergänzt sourceStatus genau die Zeile SourceOrdinal=5,
SourceName=`taskAnalysis`. Die Zeilen 1–4 behalten ihre jeweilige Bedeutung.
Nach erfolgreicher Zusatzableitung zählen ObservedRowCount und ReturnedRowCount
die Summe der beiden neuen Zeilenmengen, nicht die Zahl der Tasks oder
Ereignisse. IsTruncated ist für diese vollständig exportierten abgeleiteten
Mengen 0; die Eingabetrunkierung steht separat in den Zeilen und in sourceEvents.
Vor gültiger vollständiger Ableitung sind beide Counts NULL.

Bei gültiger Leermenge lautet der neue Quellenstatus AVAILABLE_EMPTY/0 mit
Counts 0. Sonst ist er AVAILABLE_LIMITED/1 bei Eingabetrunkierung,
mehrdeutigen oder offenen EXECUTE-/VALIDATE-Grenzen, ungültigen Paarzeiten,
fehlender Source-ID oder SourceNameConflict; andernfalls AVAILABLE/0.
NO_BOUNDARY_OBSERVED und SourceType=UNRESOLVED sind allein keine neue
Modulpartialität, weil der zugesagte Umfang nur beobachtete Quellen auswertet.
Schon bestehende v1-Qualitätsgrenzen bleiben unabhängig davon wirksam.

SourceNameConflict ergänzt bei Opt-in genau einen WarningCode
TASK_ANALYSIS_SOURCE_NAME_CONFLICT mit SourceName taskAnalysis; er zählt nicht
als native SQL-Exception. Die bisherigen loggingQuality- und findings-Mengen
werden durch neue Zusammenfassungswarnungen nicht fachlich umdefiniert.

Der bestehende Deadlinezeitpunkt wird weiterverwendet. Vor Beginn der
Zusatzableitung und vor deren gemeinsamer Übernahme wird das kooperative
Budget geprüft. Ist es vorher erschöpft, bleibt Zeile 5 NOT_READ/1 mit Grund
TIME_BUDGET_EXHAUSTED; ist der Schritt begonnen, aber nicht rechtzeitig
übernahmefähig, lautet sie AVAILABLE_LIMITED/1 mit demselben Grund. In beiden
Fällen sind Counts NULL und beide neuen Mengen leer. Eine halb veröffentlichte
Zusatzableitung ist ausgeschlossen. Eine laufende SQL-Anweisung wird durch
diese Prüfung nicht hart abgebrochen.

Voraussetzung für den Zusatzschritt sind sowohl ein gültiger v1-Ereignispuffer
als auch die vollständig abgeschlossene bisherige eventDerivation einschließlich
des gültigen internen iterations-Bestands. Ein leerer Bestand ist nur nach
erfolgreich beendeter Ableitung ein gültiger Leerfall; der nach einem Fehler
geleerte Bestand darf nicht als erfolgreiche Nullmenge verwendet werden.
Eine nur auf den Puffer oder auf einen Statusnamen beschränkte Zulassung
genügt nicht; der Zusatzschritt benötigt den nachweislich erreichten
Abschluss des gesamten bisherigen Ableitungsschritts.

Fehlt ein gültiger v1-Ereignispuffer, lautet der Zusatzstatus NOT_READ/1 mit
Grund NO_VALID_EVENT_BUFFER. Ist der Puffer gültig, aber die bisherige
Ableitung nicht vollständig abgeschlossen, gilt NOT_READ/1 mit Grund
PRIOR_DERIVATION_NOT_COMPLETED. In beiden Fällen sind die Zusatzcounts und
die drei neuen CONSOLE-Zähler NULL und beide Zusatzmengen leer; insbesondere
werden keine Null-Paarcounts oder NO_VALID_PAIRS als Erfolg veröffentlicht.
Der ursprüngliche Modulstatus und das ursprüngliche native Fehlerpaar bleiben
erhalten. Bei einem semantisch ungültigen Aufruf gilt INVALID_PARAMETER als
Grund. V1-Hilfe erzeugt auch diese Zeile nicht.
Ein nativer Fehler nur im Zusatzschritt wird in Zeile 5 mit dem bestehenden
nativen Klassifikationsvertrag und dem echten Fehlerpaar erhalten; beide
Zusatzmengen werden verworfen, die schon gültigen bisherigen Fachmengen bleiben
erhalten. Die erste native Fehlerpaarung aus den Schritten 1–4 hat Vorrang
vor einer Paarung aus Schritt 5. Die beiden neuen Zeitbudgetfälle ergänzen
genau einen TASK_ANALYSIS_TIME_BUDGET_EXHAUSTED-Warningeintrag; ein tatsächlicher
Zusatzfehler genau einen TASK_ANALYSIS_ERROR-Eintrag ohne interpolierten Quelltext.

Zusätzliche Partialität setzt moduleStatus und IsPartialOut auf 1. War der
bisherige Modulstatus AVAILABLE, AVAILABLE_EMPTY oder AVAILABLE_LIMITED,
wird er bei einer begrenzten oder fehlgeschlagenen Zusatzableitung
AVAILABLE_LIMITED; sonst bleibt der schon schwerere v1-Status erhalten.
StatusCodeOut folgt dem finalen moduleStatus. Die nativen Error-OUTPUTs
behalten die erste tatsächlich erhobene Fehlerpaarung. Ein gespeichertes
OnError, ein Namenskonflikt und ein Zeitbudgethinweis erzeugen keine neue
native Fehlernummer. Die drei neuen CONSOLE-Zähler sind bei verworfener oder
nicht gestarteter Zusatzableitung NULL. NULL-Fehlerwerte sind kein PASS-Beleg.

### G. Geplanter synthetischer Abnahmeumfang

Die folgenden Fälle definieren die synthetischen Abnahmekriterien. Die Implementierung muss
eigene kompatible Quellen verwenden, unabhängige Sollwerte festlegen und die
neuen Schemas einschließlich Datentypen, Collation, NULL-Eigenschaften und
Spaltenreihenfolge physisch vergleichen. Alle neuen TABLE-/JSON-Felder werden
miteinander verglichen. Davon getrennt prüft ein unabhängiges Referenzorakel
Identitäten, Mitgliedschaft der Evidenz-IDs, Paarcounts, Aggregationen und Status.
TABLE-/JSON-Gleichheit allein ist kein unabhängiger fachlicher Nachweis.

| Fall | Eingabe und eigenständiges Soll |
|---|---|
| S01 Wiederholungen | Eine Source-ID hat VALIDATE 0–1 s sowie EXECUTE 2–4 s und 6–9 s in Log-ID-Reihenfolge. VALIDATE: ein gültiges Paar und 1000 ms. EXECUTE: zwei gültige Paare, Summe 5000, Mittelwert 2500.000000, Minimum 2000, Maximum 3000 ms. Coverage zählt sechs Ereignisse; ExecuteStart/End je 2, ValidateStart/End je 1. |
| S02 Gleiche Namen und Parallelität | Zwei verschiedene Source-IDs tragen denselben Namen; Intervalle 0–4 s und 1–3 s. Zwei getrennte 4000-/2000-ms-Aggregate; keine Paketdauer von 6000 ms, keine Typ- oder Elternzuordnung. |
| S03 Offene Grenzen | End vor dem ersten Start und Start nach dem letzten Ende bleiben Einzelgrenzen; vorhandene eindeutige Zwischenpaare behalten ihre beobachteten Dauern. Keine Behauptung eines tatsächlich hängenden Tasks. |
| S04 Mehrdeutigkeit | Start, Start, End derselben SourceId/Paarart: drei mehrdeutige Einzelgrenzen, kein gültiges Paar und vier NULL-Dauerwerte. Ein anderer gültiger Source-/Paarartstrom bleibt getrennt. |
| S05 Zeitwerte | Fehlende Paarzeit und rückläufige Paarzeit liefern je keinen Dauerwert; gleiche Zeit ergibt 0 ms. Stundenübergreifende Intervalle und datetime-Grenzen prüfen DATEDIFF_BIG ohne int-Verengung. |
| S06 Identitäten und Namen | Zwei NULL Source-IDs bleiben zwei Coveragezeilen mit ihren ursprünglichen Log-IDs, ohne Dauerzeile. Andere Execution-ID bleibt ausgeschlossen. Namenskonflikte einschließlich Groß-/Kleinschreibung und nachgestellter Leerzeichen setzen nur bei ordinal verschiedenen nicht-NULL Namen das Konfliktflag. |
| S07 Logginglücken | Quellen mit ausschließlich OnError, unbekanntem Eventnamen beziehungsweise NULL Eventnamen erhalten ihre zutreffenden Counts und NO_BOUNDARY_OBSERVED; keine frei erfundenen Tasks oder Konfigurationsdiagnosen. Kein Ereignis ergibt leere neue Mengen, gültige Counts 0 und keine Taskliste. |
| S08 Eingabegrenze | Caps 1, 2 und vollständig: ausschließlich Mitgliedschaft im tatsächlich gelesenen Puffer bestimmt Counts und Namen. Ein Sentinel mit Konfliktname oder Ende darf die neue Ableitung nicht beeinflussen. Doppelte IDs auch im Sentinel verwerfen weiterhin den gesamten Puffer vor jeder Ableitung. |
| S09 Neue Ausgabe | Opt-in liefert RAW11, elf benannte JSON-Arrays und physische Zielschemas; CONSOLE1 besitzt genau drei neue typisierte Spalten, NONE0 keine Grids. Evidenz-ID-Strings bleiben ordinal gleich und parsebar. |
| S10 V1-Kompatibilität | Ausgelassener neuer Parameter, 0 und NULL behalten die alte Signaturzuordnung und RAW9/JSON9/TABLE9/CONSOLE1. Bei ausgeschaltetem Opt-in werden die neuen TABLE-Namen mit 51011 zurückgewiesen. |
| S11 Meldungsopt-out | IncludeMessages=0 benötigt die message-Spalte nicht fachlich und liefert dieselben neuen Kennzahlen; IncludeTimeline=0 ändert nur den bestehenden Timelineexport. Vollständige Meldungen und Erstfehlerzuordnung bleiben bei IncludeMessages=1 unverändert. |
| S12 Quelle und Berechtigung | Fehlende oder inkompatible Quelle, verweigerter Zugriff und bestehende High-Impact-Gates verhindern die Zusatzableitung ohne Ersatzquelle; keine falschen Nullmengen, kein natives Ersatzfehlerpaar. |
| S13 Budget und Zusatzfehler | Kontrollierte spätere Testeinbringung vor beziehungsweise innerhalb des Zusatzschritts prüft NOT_READ gegen verworfene begonnene Ableitung, leere Zusatzmengen und Erhaltung der bisherigen gültigen Fachmengen. Eine zusätzliche Gegenprobe lässt sourceEvents bestehen und eventDerivation nativ scheitern: Trotz gültigem Puffer muss taskAnalysis NOT_READ/1 mit PRIOR_DERIVATION_NOT_COMPLETED, NULL-Counts und NULL-CONSOLE-Zählern sowie leeren neuen Arrays bleiben; ursprünglicher Status und Fehler bleiben erhalten. Tatsächlicher eigener SQL-Fehler und synthetischer Zeitbudgethinweis bleiben getrennt. |
| S14 Caller und Mengenbasis | Originale Calleroptionen, Locktimeout und Transaktionszahl bleiben erhalten. PairRowCount-Zerlegung, disjunkte Coveragecounts, eindeutige Evidenz-IDs, gültige 0-Zeit, NULL statt falscher 0 und dezimale Mittelwertrundung werden unabhängig geprüft. |

Für S13 bleibt die öffentliche Signatur bei genau 21 Parametern. Es werden
keine Produktions-Faultparameter, versteckten Testschalter oder Produkt-,
Lab- und System-Overrides eingeführt. Kontrollierte Stufen- und Deadlinefälle
werden ausschließlich als synthetische Pfadprüfungen in einem getrennten
privaten Harness mit quellhashgebundenen extrahierten Originalstufen geplant.
Eine dort tatsächlich ausgelöste eigene SQL-Exception kann durch direkte
native Gegenprobe ihre Nummer und ihren Text belegen. Sie ist damit kein
natürlich auftretender Fehler des unveränderten Analyzers und kein Ersatz
für dessen spätere Original-SUT-Abnahme. Stufenprüfung und Original-SUT-Lauf
werden in der Ergebnisevidenz ausdrücklich getrennt geführt.

Die folgende Aufrufvorlage aktiviert ausschließlich den freigegebenen Zusatzumfang:

```sql
EXEC [monitor].[USP_SsisLegacyLogAnalysis]
    @LoggingDatabase=N'ExampleSsisTaskLogs',
    @ExecutionId='00000000-0000-0000-0000-000000000001',
    @MaxZeilen=0,
    @HighImpactConfirmed=1,
    @ResultSetArt='RAW',
    @IncludeTaskAnalysis=1;
```

### H. Geplante begrenzte native Abnahme und Cleanup

N01 und N02 bilden den freigegebenen neuen nativen Abnahmeumfang. Vor Effekten
wird ein eigenes endliches Budget festgelegt; Freigabe und Review allein sind
kein Laufzeitnachweis. Die historische Vierfälleabnahme des v1-Providers und
ihre geschlossenen Budgets werden nicht neu gestartet.

| Szenario | Eigene Paketkonstellation | Passkriterium |
|---|---|---|
| N01 Serielle Wiederholung | Ein eigenes Paket führt denselben Task in drei kontrollierten Vorkommen aus. VALIDATE- und EXECUTE-Logging werden für die eigenen Objekte aktiviert. | Tatsächliche SDK-Ereignisse und Providerzeilen sind an Paketbytes, Execution-ID und Source-IDs gebunden. Beobachtete Paare und Summen entsprechen einem separat berechneten Orakel auf den gespeicherten Zeiten. Drei Execute-Vorkommen müssen unabhängig belegt sein; die Anzahl der Validierungen wird nicht pauschal als drei angenommen. |
| N02 Parallelität und selektives Logging | Ein eigenes Paket enthält getrennte parallele Ausführungsquellen mit gleichem Anzeigenamen und einen eigenen Task mit bewusst unterdrücktem Logging. | Gleiche Namen werden nicht verbunden; gültige Dauerwerte sind keine CPU-/Paketzeit. Der nicht protokollierte Task erhält keine erfundene Analyzerzeile. Der Analyzer behauptet weder vollständige Taskabdeckung noch die Ursache fehlender Ereignisse. |

Vor Arrange werden aktuelle öffentliche Lab-Quelle, erreichbare Windows-/SQL-/
SSIS-Umgebung, Zugangsart, Berechtigungen und Eigentumsbindungen aufgenommen.
Analyze verantwortet seine eigenen synthetischen Pakete, Logging- und
Frameworkdatenbanken sowie das unabhängige Orakel. Eine zusätzliche vom Lab
gelieferte fachliche Fixture wird nicht vorausgesetzt. Falls eine eigene
Umgebung benötigt wird, verlangt deren konkrete Nutzung die hierfür geltende
Freigabe für eigene Testressourcen. Eine vorhandene geeignete native Umgebung
kann mit eigenen isolierten Testobjekten verwendet werden; fremde Quellen
und globale Einstellungen bleiben unverändert.

Die später auszuführenden Schritte sind: eigene Objektintents und Inventar
sichern, unveränderte installierte Produkt-/Helperbytes binden, die beiden
Pakete erzeugen und deren tatsächliche Komponenten-/Source-IDs auslesen,
N01 und N02 tatsächlich ausführen, Originalcallbacks und Providerzeilen vor
Assertions speichern, Referenzwerte separat berechnen und die neuen Consumer
mit den tatsächlich erreichten IDs aufrufen. Vollständiger Puffer und ein
gezielter Cap prüfen Menge und Trunkierung; alle Ausgabearten verwenden
jeweils ihren eigenen aufrufgebundenen JSON-Vergleich. Das Caller- und
Quelleninventar wird vor eigenem Cleanup erneut geprüft.

Die spätere Abnahme liefert Paket-/Source-/Produktbindungen, Originalcounts,
Referenzformeln, physische neue Schemas, TABLE-/JSON-Parität und ausdrücklich
ausgewiesene unabhängige Fachprüfungen. Fehlversuche und NOT_EXECUTED-Teile
bleiben erhalten. Ein beobachteter Native-Ausgang allein qualifiziert keine
Analyzerkennzahl. Rohwerte und Runtimeidentitäten bleiben privat; für eine
Repositorylieferung sind ausschließlich abstrahierte synthetische Ergebnisse
und geeignete Provenienz zulässig.

Im Erfolg und Fehlerfall werden nur eindeutig eigene Datenbankobjekte,
Pakete und Gasttemporärdaten über ihre vorab gesicherten Identitäten bereinigt.
Eine eigene VM wird ausschließlich über ihren öffentlichen, exakt gebundenen
Lab-Lifecycle behandelt. Fremde Runs, Pakete und erhaltene Fixtures werden
weder geändert noch entfernt. Cleanupfehler bleiben vom Primärfehler getrennt
und verhindern eine vollständige Abschlussbehauptung. Policyblockierte
Dateilöschungen werden nicht über eine andere API wiederholt. Ein bewusst
erhaltenes eigenes Objekt wird mit Grund und sicherem Folgezustand ausgewiesen.

### I. Review, spätere Lieferung und Freigabegrenze

Der Vertragsreview prüft insbesondere Kompatibilität, Identität ohne
Tasktypraten, konservative Paarbildung, genaue Counts und Evidenzbasis,
fehlende gegen echte Nullwerte, Fehlerisolation, Zeitgrenzen, Datenschutz und
die Trennung von Outputparität und unabhängigem Orakel. Ein abgeschlossener
Review ist keine menschliche Implementierungs- oder Runtimefreigabe.

Die konkrete menschliche Freigabe liegt vor. Produktcode, neue Tests,
Inventare, betroffene Installer und Anleitungen bilden einen Lieferabschnitt.
Die Testauswahl folgt ausschließlich der CI_Test_Strategy: impact-basierte
SQL-2025-Prüfung für ausführbare Änderungen und gezieltes Windows-Gate für
die neuen nativen Fähigkeiten; keine pauschale Wiederholung älterer Engines.
Exakte Head-CI, reguläre MatchHead-Integration und eigenes Cleanup bleiben
für die Produktlieferung verbindlich. Die aktive Inventarisierung bleibt auf
diesen Slice begrenzt. SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION; weitere
Backlogfunktionen und WI-0009 GATE-0001 werden dadurch nicht abgeschlossen.

## Freigegebene Erweiterung: Legacy-Zeilenfluss aus OnPipelineRowsSent vom 18. Oktober 2026

**Status:** konkret menschlich freigegebener Erweiterungsvertrag für die
begrenzte Implementierung, Abnahme und reguläre PR-Lieferung.

**Zuordnung:** Erweiterung von SSIS-001, begrenzter Mengenanteil aus
Backlogschritt 3. Der gelieferte Taskintervallvertrag bleibt unverändert.

Die Freigabe bezieht sich auf die nachfolgenden Abschnitte R1–R9. Ein
Vertragsreview ist kein Laufzeitnachweis. Der tatsächlich ausgeführte
Abnahmeumfang wird getrennt im kanonischen Analyseplan dokumentiert.

### R1. Zweck, Quelle und Aussagegrenze

Welche Zeilenübergaben meldet OnPipelineRowsSent für eine explizite lokale
Legacy-Execution, welche Meldungen sind durch das festgelegte Format lesbar
und welche beobachteten Summen lassen sich einem eindeutigen Ereignispaar
und einer Pfad-/Eingabekennung zuordnen?

Die Quelle, Rechteprüfung, neun gespeicherten Eingabefelder, vollständigen
Meldungstexte und der einzelne N+1-Ereignispuffer bleiben wie in Revision 3.
Die neue Stufe verwendet ausschließlich diesen geprüften Puffer und den
vollständig abgeschlossenen internen v1-iterations-Bestand vor Exportkappung.
Sie ergänzt rowFlowEvents als eine Zeile je Kandidatenmeldung und rowFlow
als Summe eindeutig zugeordneter, erfolgreich gelesener Meldungen derselben
beobachteten Pfadgruppe. Sie liest weder eine zweite Quelle noch Pakete,
SSISDB, Dateien oder databytes. Source-ID und Komponenten-ID sind verschiedene
Kennungen; aus dem Source-Namen wird kein Executable-Typ abgeleitet.

Microsoft beschreibt das Ereignis als Zeilenübergabe an einen Komponenteneingang
bei einem ProcessInput-Aufruf. Der dokumentierte erste Zahlenwert heißt
PathID; ein Feld OutputId und eine Zuordnung zur Quellkomponente werden daraus
nicht erfunden. RowsSent bezeichnet eine gemeldete Übergabemenge, keine Zahl
eindeutiger Paketdatensätze, physischer Buffer oder dauerhaft geschriebener
Zielzeilen. Eine Meldung beweist keinen Commit und keine Datenkorrektheit.

Der Slice enthält keine Komponentenphasen, Raten, Durchsatz-, CPU- oder
exklusiven Zeiten, Graphrekonstruktion, Lookup-/Cachedecoder, Historie,
eigene Kennzahlen oder automatische Loggingänderung. Unterschiedliche Pfade
werden auch bei Multicast oder Aggregationen nicht zu einem Paketgesamtwert
addiert. Fehlende Ereignisse erlauben keine Nullmenge und keine Aussage über
deaktiviertes Logging, nicht durchlaufene Zweige oder gelöschte Protokolle.

### R2. Signatur und vier kompatible Ausgabeformen

Die 21 gelieferten Parameter behalten ihre Position, Typen, Defaults und
Bedeutung. Ausschließlich am Ende folgt als freigegebener Parameter Position 22
`@IncludeRowFlowAnalysis bit = 0`; NULL bedeutet 0. Die
Procedureversion ist 1.2.0. IncludeTaskAnalysis bleibt unabhängig schaltbar.

| IncludeTaskAnalysis | IncludeRowFlowAnalysis | SchemaVersion | RAW-/JSON-/TABLE-Mengen |
|---|---|---|---|
| 0 oder NULL | 0 oder NULL | 1 | Die bisherigen neun Mengen bleiben erhalten. |
| 1 | 0 oder NULL | 2 | Die neun Mengen sowie taskDurations und taskLoggingCoverage bleiben erhalten. |
| 0 oder NULL | 1 | 3 | Nach den neun Mengen folgen rowFlowEvents und rowFlow; insgesamt elf Mengen. |
| 1 | 1 | 3 | Nach den neun Mengen folgen taskDurations, taskLoggingCoverage, rowFlowEvents und rowFlow; insgesamt dreizehn Mengen. |

SchemaVersion in moduleStatus und JSON-meta stimmt überein. Nur bei neuem
Opt-in ergänzt meta die JSON-Zahl RowFlowCatalogVersion=1. Die bisherige
TaskAnalysisCatalogVersion erscheint weiterhin ausschließlich bei Task-Opt-in.
Beide neuen Arrays bleiben bei angefordertem Opt-in auch bei Fehler oder
Leermenge als [] vorhanden. NULL-Felder bleiben enthalten. Ohne neues Opt-in
entstehen weder neue Arrays, Status-/Warningzeilen noch CONSOLE-Spalten;
die 94 alten und 48 gelieferten Taskfelder werden nicht umdefiniert.

TABLE akzeptiert einen neuen Namen ausschließlich bei neuem Opt-in;
ausgeschaltete, unbekannte oder ungültig zugeordnete Namen werfen wie bisher
51011 vor fachlichem Quellzugriff. Hilfe, Ausgabemodus, TABLE-Vorbereitung und
fachliche Zulassung behalten ihre Reihenfolge. Ein gültiges Mapping erhält
bei semantisch ungültigen Parametern typisierte leere Ziele. NONE bleibt ohne
fachliches Grid; angefordertes JSON ist vom Ausgabemodus unabhängig.

CONSOLE bleibt ein Resultset. Nur bei neuem Opt-in folgen nach den jeweils
bisherigen Spalten RowFlowMeldungen bigint, RowFlowGeleseneMeldungen bigint
und RowFlowZugeordneteMeldungen bigint; alle drei sind nullable. Sie zählen
vor Exportkappung Kandidaten, erfolgreich geparste Kandidaten und erfolgreich
zugeordnete Kandidaten, ausdrücklich keine Zeilensumme über verschiedene
Pfade. Nach erfolgreicher leerer Ableitung sind sie 0, andernfalls bis zur
vollständigen Übernahme NULL. Bei beiden Opt-ins stehen die drei bisherigen
Taskzähler vor diesen drei neuen Zählern. Es gibt kein zusätzliches Grid.

### R3. Kandidaten und versionierte Grammatik

Ein Kandidat besitzt exakt den Eventnamen OnPipelineRowsSent. Eventname und
Formatpräfix werden ordinal anhand der UTF-16-Bytes verglichen, ohne Trimmen,
Case-Faltung oder Übersetzung. Varianten des Eventnamens bleiben wie bisher
in timeline sichtbar, gehören aber nicht zum Kandidatenbestand. Inhalt oder
datacode eines anderen Ereignisses aktivieren den Decoder nicht.

Parserkennung ORPS_EN_1 bezeichnet ausschließlich das folgende konservative
Profil des englischen Herstellerbeispiels. Ein Profil ist keine Zusage für
alle Versionen oder sprachlichen Installationen. Der unterstützte native
Versionsumfang wird erst durch die später tatsächlich ausgeführte Abnahme
qualifiziert. SERVERPROPERTY des Analysehosts bestimmt weder Produzenten-
version noch Sprache historischer Meldungen.

Der genaue Unicode-Präfix lautet `Rows were provided to a data flow component as input. : : `.
Danach folgen genau sieben durch ` : ` getrennte Felder in dieser Reihenfolge:
PathId, PathName, DestinationComponentId, DestinationComponentName, InputId,
InputName und RowsSent. Der gesamte gespeicherte Text muss dem Profil
entsprechen; Präfix-/Substringtreffer oder übrig gebliebener Suffix genügen
nicht. Nach dem letzten Zähler ist kein Punkt oder Whitespace zugelassen.

Die drei IDs bestehen aus ASCII-Ziffern ohne Vorzeichen und ohne führende
Null, passen verlustfrei in int und liegen zwischen 1 und 2147483647.
RowsSent besteht entweder aus der einzelnen Ziffer 0 oder aus ASCII-Ziffern
mit einer ersten Ziffer 1–9 und passt in bigint bis 9223372036854775807.
Vorzeichen, Dezimal-/Tausendertrenner, Exponenten, leere und überlaufende
Zahlen werden abgewiesen. Namen enthalten mindestens eine und höchstens 4000
UTF-16-Codeeinheiten; Doppelpunkt, CR, LF, TAB und U+0000 sind darin nicht
zugelassen. Namen werden nicht normalisiert. Insbesondere bleiben führende
oder nachfolgende Leerzeichen innerhalb eines Namens und ordinal verschiedene
Schreibweisen erhalten. Das enge Profil kann legitime, aber mit diesem Profil
nicht eindeutig zerlegbare Namen ablehnen; der Analyzer rät keine Teilung.

Das native SQL-Logging begrenzt message auf nvarchar(2048). Auch eine formal
gültige Zahl am Ende eines kapazitätsfüllenden Texts könnte abgeschnitten
sein. Deshalb wird vor Parsing die UTF-16-Bytezahl DATALENGTH(message) des
gespeicherten Puffers gegen B=min(deklarierter positiver message.max_length,
4096) geprüft; bei nvarchar(max) gilt B=4096. Bei Länge >=B bleibt der Kandidat
POTENTIALLY_TRUNCATED und sämtliche Payloadfelder bleiben NULL. LEN ist dafür
wegen nachfolgender Leerzeichen ungeeignet. Der konservative 4096-Byte-Deckel
gilt auch für breitere kompatible Quellen und ändert deren vollständigen
Timelineexport nicht. Frühere Kürzung unterhalb dieser Grenze ist ohne
zusätzliche Herkunftsevidenz nicht erkennbar; PARSED garantiert keine
ursprünglich ungekürzte Produzentenmeldung.

Bei IncludeMessages=0 wird die neue Stufe nicht gestartet: keine fachliche
Referenz auf message, keine Längenprüfung dieser Spalte und kein versteckter
erneuter Quellzugriff. Meldungsopt-out bleibt auch bei fehlender oder
berechneter message-Spalte zulässig. Englische Dokumentation und deutsche
Übersetzung belegen dasselbe englische Beispielprofil, aber keinen stabilen
deutschen nativen Präfix. Deutschsprachige und sonstige abweichende Payloads
erhalten UNSUPPORTED_FORMAT; sie werden nicht per Übersetzungsheuristik
interpretiert. Weitere Sprachprofile benötigen eigene Quellen und Abnahme.

Die ParseStatus-Auswahl hat folgende feste Priorität:

| Bedingung | ParseStatus | ParserId und sieben Payloadfelder |
|---|---|---|
| message ist NULL. | MESSAGE_MISSING | ParserId und Payload sind NULL. |
| Die gespeicherte Bytezahl erreicht B. | POTENTIALLY_TRUNCATED | ParserId und Payload sind NULL. |
| Der exakte Präfix fehlt. | UNSUPPORTED_FORMAT | ParserId und Payload sind NULL. |
| Anzahl oder Form der sieben Felder stimmt nicht, einschließlich leerer Namen oder verbotener Zeichen. | MALFORMED_PAYLOAD | ParserId=ORPS_EN_1; Payload ist NULL. |
| Ein syntaktisch korrekter Zahlentoken überschreitet seinen Bereich. | NUMERIC_OUT_OF_RANGE | ParserId=ORPS_EN_1; Payload ist NULL. |
| Alle Prüfungen bestehen. | PARSED | ParserId=ORPS_EN_1; alle sieben Payloadfelder sind vorhanden. |

Eine leere Meldung ist UNSUPPORTED_FORMAT. Ein negativer Zähler ist wegen des
Vorzeichens MALFORMED_PAYLOAD; 0 ist allein für RowsSent zulässig und eine
ID 0 ist NUMERIC_OUT_OF_RANGE. Es werden keine teilweise geparsten Zahlen
oder Namen veröffentlicht. Vollständiger Originaltext und datacode bleiben
in timeline, soweit deren Export angefordert ist; kein zusätzliches Raw-
Message-Resultset und kein DataBytes-Pfad werden eingeführt.

### R4. Zuordnung zu beobachteten Ereignispaaren

Die neue Zuordnung ändert weder v1-iterations noch die PR393-Taskaggregate.
Sie verwendet nur interne EXECUTE-Zeilen mit PairStatus=PAIRED aus vollständig
abgeschlossener v1-Ableitung. Paargrenzen und Ereigniszeit behalten die
gespeicherten datetime-Werte; LogId ist nur die vorhandene Ordnungshilfe.
Ein Kandidat ist eindeutig zugeordnet, wenn SourceId vorhanden ist und genau
ein solches Paar derselben SourceId die Bedingung StartLogId<LogId<EndLogId
erfüllt und StartTime<=EventTime<=EndTime gilt. Gleiche gespeicherte Zeitwerte
sind zulässig. PACKAGE-/VALIDATE-Paare, Namen, benachbarte Source-IDs oder ein
beliebiges MIN-/MAX-Paar sind kein Ersatz. Es wird kein neuer Paarmatcher
eingeführt und keine Ausführung eines tatsächlichen Loops behauptet.

GroupingStatus wird in dieser Reihenfolge festgelegt: Nicht-PARSED ergibt
NOT_PARSED; fehlende SourceId ergibt SOURCE_ID_MISSING; fehlende EventTime
ergibt EVENT_TIME_MISSING; kein zugelassenes ID-einschließendes Paar ergibt
NO_OBSERVED_PAIR; mehrere solche Paare ergeben AMBIGUOUS_PAIR; ein nicht
einschließender Zeitbereich des einzigen Paars ergibt TIME_OUTSIDE_PAIR;
sonst gilt ASSIGNED. Nur ASSIGNED setzt beide Occurrence-Log-IDs und trägt
zu rowFlow bei. Jeder andere Zustand behält die Kandidatenzeile und bei
PARSED den gemeldeten RowsSent-Wert, erhält aber keine Vorkommenssumme.

rowFlow gruppiert ausschließlich nach ExecutionId, SourceId, den beiden
Occurrence-Log-IDs, PathId, DestinationComponentId und InputId. Verschiedene
Inputs, Pfade, Source-IDs oder Paare bleiben auch bei gleichen Namen getrennt.
Jede zugeordnete Meldung gehört genau einer Gruppe an. Der SourceName und
die drei Payloadnamen einer Gruppe ergeben sich jeweils ausschließlich aus
den beitragenden Kandidaten: ein einziger ordinaler Nicht-NULL Name bleibt
erhalten; mehrere ordinale Werte ergeben NULL und das jeweilige Conflict-Bit.
Sind alle Source-Namen NULL, bleibt SourceName NULL ohne Conflict-Bit.
Es gibt keine Auswahl eines beliebigen Namenwerts und keinen Paketversionsbeweis.

EventCount zählt beitragende Log-IDs. RowsSentSum addiert die gemeldeten
RowsSent-Werte nach vorheriger Konvertierung in decimal(38,0). MinRowsSent
und MaxRowsSent sind Minimum und Maximum dieser bigint-Werte. Ein Nullsummen-
ergebnis entsteht ausschließlich aus tatsächlich vorhandenen expliziten
Nullmeldungen; eine leere Gruppe erzeugt keine rowFlow-Zeile. Gleiche Texte
mit verschiedenen IDs werden nicht dedupliziert. Ihre Summe beschreibt die
gespeicherten gemeldeten Übergaben, keine unabhängig garantierte Menge realer
eindeutiger Transfers. Doppelte IDs im N+1-Puffer werden weiterhin vor jeder
Sentinelverarbeitung nach v1 verworfen.

FirstObservedTime und LastObservedTime sind Minimum und Maximum der
beitragenden EventTime-Werte, keine Dauer oder Ratenbasis. EvidenceLogIdsJson
enthält deren aufsteigend sortierte eindeutige ganzzahlige Log-IDs als gültigen
JSON-Array-String. RAW und TABLE transportieren nvarchar(max); das äußere
JSON erhält denselben String und macht daraus kein verschachteltes Array.
Paargrenzen sind gesonderte Evidenz-IDs und keine RowsSent-Beiträge.

### R5. Zwei zusätzliche physische Schemas

NN bedeutet NOT NULL; sonst ist das Feld nullable. Alle neuen Textfelder
verwenden SQL_Latin1_General_CP1_CS_AS, keine Identity- oder berechneten Spalten.
Die Feldreihenfolge und Typen sind Teil des vorgeschlagenen Vertrags.

| Menge | Spalten in physischer Reihenfolge |
|---|---|
| rowFlowEvents, 19 Spalten | RowFlowEventOrdinal bigint NN; ExecutionId uniqueidentifier NN; LogId int NN; SourceId uniqueidentifier; SourceName nvarchar(4000); EventTime datetime; ParserId varchar(32); ParseStatus varchar(40) NN; PathId int; PathName nvarchar(4000); DestinationComponentId int; DestinationComponentName nvarchar(4000); InputId int; InputName nvarchar(4000); RowsSent bigint; OccurrenceStartLogId int; OccurrenceEndLogId int; GroupingStatus varchar(40) NN; InputIsTruncated bit NN |
| rowFlow, 25 Spalten | RowFlowOrdinal bigint NN; ExecutionId uniqueidentifier NN; SourceId uniqueidentifier NN; SourceName nvarchar(4000); OccurrenceStartLogId int NN; OccurrenceEndLogId int NN; PathId int NN; PathName nvarchar(4000); DestinationComponentId int NN; DestinationComponentName nvarchar(4000); InputId int NN; InputName nvarchar(4000); EventCount bigint NN; RowsSentSum decimal(38,0) NN; MinRowsSent bigint NN; MaxRowsSent bigint NN; FirstObservedTime datetime NN; LastObservedTime datetime NN; EvidenceLogIdsJson nvarchar(max) NN; SourceNameConflict bit NN; PathNameConflict bit NN; DestinationNameConflict bit NN; InputNameConflict bit NN; InputIsTruncated bit NN; CoverageStatus varchar(40) NN |

rowFlowEvents ist nach LogId geordnet; RowFlowEventOrdinal beginnt pro Aufruf
bei 1. rowFlow wird nach nativer SQL-uniqueidentifier-Ordnung für SourceId,
OccurrenceStartLogId, OccurrenceEndLogId, PathId, DestinationComponentId und
InputId geordnet; RowFlowOrdinal beginnt ebenfalls bei 1. Es sind keine über
Aufrufe stabilen IDs. ExecutionId ist im Aufruf konstant.

CoverageStatus lautet OBSERVED_NAME_CONFLICT bei mindestens einem Conflict-Bit,
sonst OBSERVED_PREFIX bei InputIsTruncated=1, sonst OBSERVED_TRANSFERS. Das
Trunkierungsbit bleibt auch bei Namenskonflikt erhalten. Keiner dieser Werte
behauptet vollständiges Logging. Es gibt kein RowsPerSecond- oder TotalRows-
Feld über die Gesamtheit aller Pfade. Ein geparster Kandidat ohne ASSIGNED
bleibt ausschließlich in rowFlowEvents sichtbar.

### R6. Puffer, Grenzen, Quellenstatus und Fehlerisolation

Die neue Stufe benötigt einen gültigen sourceEvents-Puffer und den nachweislich
erreichten Abschluss der ganzen v1-eventDerivation. Ein nach deren Fehler
geleerter iterations-Bestand ist keine erfolgreiche Leermenge. Die separate
Taskaggregate-Stufe darf für neues Row-Flow-Opt-in ausgeschaltet sein;
ihr eigener Fehler blockiert einen gültigen v1-Paarbestand nicht. Umgekehrt
darf ein Row-Flow-Fehler gültige frühere Fachmengen nicht löschen.

Nur bei neuem Opt-in folgt sourceStatus mit SourceOrdinal=6 und
SourceName=rowFlowAnalysis. Die festen Ordinale 1–4 und das optionale Ordinal 5
bleiben erhalten; ohne Task-Opt-in ist 5 nicht vorhanden, 6 wird nicht auf 5
umbenannt. ObservedRowCount und ReturnedRowCount zählen nach erfolgreicher
Stufe die Summe aus rowFlowEvents- und rowFlow-Zeilen, nicht RowsSentSum.
Counts und die drei neuen CONSOLE-Werte sind bis zur atomaren Übernahme NULL.
Detail hat nach Erfolg die Form Candidates=C;Parsed=P;Assigned=A;Groups=G
mit exakten dezimalen bigint-Counts; ObservedRowCount=ReturnedRowCount=C+G.

Bei erfolgreich leerem Kandidatenbestand gilt AVAILABLE_EMPTY/IsPartial=0,
Counts 0 und genau eine Warnung ROWFLOW_EVENT_NOT_OBSERVED. Ohne diese
Ereignisse wird keine echte Null-Transfermenge und keine Ursache behauptet.
Bei erfolgreicher nichtleerer Stufe gilt AVAILABLE_LIMITED/1, wenn der
Eingabepuffer gekappt ist, ein Kandidat nicht PARSED/ASSIGNED ist oder ein
Gruppenname Konflikt besitzt; andernfalls gilt AVAILABLE/0. Solche Partialität
behauptet keine falsche Produzentenmeldung oder einen Paketfehler.

Die Zulassungsgründe werden in fester Priorität ausgewählt: INVALID_PARAMETER,
NO_VALID_EVENT_BUFFER, PRIOR_DERIVATION_NOT_COMPLETED, MESSAGES_DISABLED und
TIME_BUDGET_EXHAUSTED. In diesen Fällen ist Zeile 6 NOT_READ/1 mit NULL-Counts
und leeren neuen Mengen. MESSAGES_DISABLED ergänzt genau eine Warnung
ROWFLOW_MESSAGES_DISABLED, führt aber keinen message-Zugriff aus. Hilfe
liefert keine neue Quellenzeile. Die aufgerufenen übrigen Stufen und ein
gültiger eigener Taskexport bleiben erhalten.

Der bestehende kooperative Deadlinezeitpunkt wird vor Beginn und vor der
gemeinsamen Übernahme beider neuen Mengen geprüft. Bei Ablauf nach Beginn
gilt AVAILABLE_LIMITED/1 mit TIME_BUDGET_EXHAUSTED; beide Mengen werden verworfen,
Counts und neue CONSOLE-Werte sind NULL. Vor Beginn gilt NOT_READ/1. Genau eine
Warnung ROWFLOW_TIME_BUDGET_EXHAUSTED entsteht. Das beendet keine laufende
SQL-Anweisung hart und verlängert das gemeinsame Budget nicht.

Ein tatsächlicher nativer Fehler der neuen Stufe erhält die bestehende native
Fehlerklassifikation samt echter Nummer und vollständigem Fehlertext in
Zeile 6; beide neuen Mengen werden verworfen, Counts bleiben NULL und genau
eine Warnung ROWFLOW_ANALYSIS_ERROR entsteht. Fachliche Parserablehnungen
sind keine SQL-Exceptions. Bei erfolgreicher Stufe werden zusätzlich höchstens
je eine Warnung ROWFLOW_PAYLOAD_NOT_PARSED, ROWFLOW_OCCURRENCE_NOT_ASSIGNED
und ROWFLOW_NAME_CONFLICT für ihre tatsächlich vorhandenen Zustände erzeugt.
NOT_PARSED zählt nicht zusätzlich als Zuordnungsablehnung. Stufe 6 erzeugt
keine neuen loggingQuality- oder findings-Zeilen. Warningtexte enthalten nur
feste Erklärungen und generische Counts, keinen interpolierten Payload.

Neue Partialität setzt IsPartialOut und moduleStatus.IsPartial auf 1. Ein
bisher AVAILABLE, AVAILABLE_EMPTY oder AVAILABLE_LIMITED lautender Modulstatus
wird bei begrenzter oder fehlgeschlagener Stufe AVAILABLE_LIMITED; ein schon
schwererer Status bleibt erhalten. StatusCodeOut folgt dem finalen Modulstatus.
ErrorNumberOut und ErrorMessageOut behalten das erste tatsächliche native
Fehlerpaar in der Quellenfolge 1–4, optional 5, dann 6. Parserstatus, Warnungen
und gespeicherte OnError-Ereignisse erfinden keine native Fehlernummer.

MaxZeilen behält seine gemeinsame Lese-/Exportbedeutung. Positiv N erlaubt
genau den bestehenden N+1-Präfix; der geprüfte Sentinel wird vor jeder neuen
Kandidaten-, Zeit-, Namens- oder Evidenzauswertung entfernt. Die Eingabekappung
steht als InputIsTruncated in jeder neuen Zeile. Beide neuen Mengen enthalten
je höchstens E Zeilen bei E Ereignissen; deshalb ist bei positivem N kein
zweiter Fachcap nötig. sourceStatus.IsTruncated ist für vollständig exportierte
abgeleitete Mengen 0, auch bei gekapptem Eingang. NULL/0 und MAX-Texte behalten
ihre vorhandenen HighImpact-Gates. IncludeTimeline=0 betrifft nur den Export.
Kostenklasse bleibt LOW_HIGH_OPT_IN; Parsing, Gruppierung, Sortierung und
Evidenzstrings benötigen zusätzliche CPU-, Speicher- und tempdb-Arbeit ohne
feste Ressourcen- oder Performancegarantie. Zusätzliche Indizes sind keine
Voraussetzung; es gibt weder DDL in fremden Quellen noch globale Änderungen.

### R7. Geplanter synthetischer Abnahmeumfang

Die folgenden Gruppen bilden den freigegebenen synthetischen Umfang. Die
Implementierung prüft
die unveränderte Gesamtprocedure mit eigenen gespeicherten kompatiblen Quellen.
Referenzen berechnen sämtliche 44 neuen Felder unabhängig vom Produktdecoder;
reine TABLE-/JSON-Parität ersetzt dieses Orakel nicht. Genau bekannte Zahlen,
IDs und UTF-16-Namen werden vor Ausführung festgelegt.

| Gruppe | Gegenstand und notwendiges Soll |
|---|---|
| R-S01 | Exaktes EN-Profil, eine Übergabe mit 7 Zeilen: vollständige 19-/25-Feldwerte, Schemafacetten, Identitäten und Evidenzarray stimmen. |
| R-S02 | Mehrere Übergaben 3, 0 und 8 im selben Paar/Pfad ergeben EventCount=3, RowsSentSum=11, Min=0, Max=8; verschiedene IDs mit gleichem Text bleiben Beiträge. |
| R-S03 | Explizite 0, fehlender Kandidat, NULL-/leere Meldung, unbekannter Präfix und abweichender Eventname bleiben unterscheidbar; kein künstlicher Nullsummenpfad. |
| R-S04 | Drei int-IDs bis zur Obergrenze und bigint-Zähler über int, bis bigint-Max; Summen werden vor Addition decimal(38,0). Überlauf, ID0, Minus, Plus, führende Null, Localezahlen und Exponenten liefern die festgelegte Ablehnung ohne Teilpayload. |
| R-S05 | UTF-16-Namen, Case-/Trailing-Space-Konflikte und gleiche Anzeigenamen bei verschiedenen IDs bleiben getrennt; Konfliktbits, NULL-Namen und Basis-IDs stimmen. |
| R-S06 | Zu wenige/zusätzliche Trenner, Doppelpunkt in Namen, CR/LF/TAB/NUL, zusätzliche Endzeichen und eingefügte zweite gültig aussehende Zahl werden nicht teilweise angenommen. |
| R-S07 | Nachricht an B−2, B und B+2 Bytes, schmale/breite/MAX-Meldungstypen und abschließende Leerzeichen prüfen DATALENGTH, die konservative Kappungsgrenze und unveränderten Rawtext. Ein formal gültiger, abgeschnittener Zahlenrest an B wird nicht summiert. |
| R-S08 | Mehrere geschlossene EXECUTE-Paare, identische Zeiten, Anfangsende/Endstart, mehrdeutiger Strom, rückläufige/fehlende Zeit, fehlende SourceId und Zeit außerhalb des ID-Paars erlauben nur exakt definierte ASSIGNED-Zeilen. |
| R-S09 | Getrennte Execution-/Source-IDs, wiederholte Vorkommen und parallele gleichnamige Sources; Multicastpfade mit 10/10 und ein nachfolgender Aggregatpfad mit 2 ergeben getrennte Gruppen, keinen Paketwert 22. |
| R-S10 | Caps 1, 2 und vollständig mit passenden Grenzreihenfolgen; Sentinel trägt nie bei. Doppelte ID einschließlich Sentinel verwirft den ganzen Puffer. Counts, Eingabekappung und leere nicht zugelassene Exporte stimmen. |
| R-S11 | Alle vier Opt-in-Kombinationen, NULL wie 0, positionale Altaufrufe, RAW9/11/13, JSON-Zahlenversionen/Arrays, Teilmapping, 51011 vor Zugriff, typisierte Leerziele, CONSOLE1 und NONE0 werden geprüft. |
| R-S12 | IncludeMessages=0 bei fehlender/ungültiger/berechneter message-Spalte aktiviert keine Decoderreferenz; IncludeTimeline=0 ändert keine Decoderwerte. Computed Pflichtfelder, Quellen-/Berechtigungsfehler und direkte echte Fehlermeldungen bleiben getrennt. |
| R-S13 | Quellgebundene extrahierte Stufen prüfen Deadline vor Beginn/vor Übernahme, tatsächlichen neuen SQL-Fehler und fehlgeschlagene vorherige v1-Ableitung bei gültigem Puffer: NULL-Counts, leere Zusatzmengen und Originalfehler bleiben korrekt. Diese isolierten Pfadprüfungen sind keine natürlich aufgetretenen Fehler des unveränderten Gesamtprodukts. |
| R-S14 | Reine Capturemutationen entfernen ein Feld/Array, vertauschen Pfad/Input/Source/Paar, verändern Count/NULL/Evidenzmitgliedschaft oder Callerframe und müssen den unabhängigen Prüfer scheitern lassen. Quellen, Callerzustand und Cleanupidentitäten bleiben aufrufgebunden. |

Fehlerpfade erhalten keine öffentlichen Faultparameter, privaten Produkt-
schalter oder Lab-/System-Overrides. Gegenproben, die einen Fehler nicht
kontrolliert am Original erzeugen können, bleiben als extrahierte Stufen
gekennzeichnet. Bereits geschlossene Task- und Vierfälleabnahmen werden nur
bei relevanter unveränderter Bindung wiederverwendet, nicht pauschal neu gestartet.

### R8. Geplante begrenzte native Abnahme

R-N01 und R-N02 bilden den konkret freigegebenen neuen nativen Umfang.
Die Ausführung zählt vor Effekten in einer eigenen endlichen Welle. Analyze erstellt
seine eigenen Pakete und Orakel auf einer dafür qualifizierten verfügbaren
Windows-/SQL-/SSIS-Umgebung. Es gibt keine Pflicht, dass das Lab zuvor eine
fachliche Legacy-Fixture erstellt. Neue Labentwicklung, Imagebeschaffung,
Installation, allgemeine Rechteänderung oder alte Runtime-Replays folgen
nicht aus diesem Plan. Die tatsächliche Engine-, SSIS-, Provider-, Sprach-
und CL-Bindung wird vor einem späteren Versuch erhoben; UNKNOWN bleibt UNKNOWN.

R-N01 verwendet einen eigenen linearen Data Flow mit vorab festgelegten 10007
synthetischen Zeilen und unabhängig gezähltem Zielbestand. Ein tatsächlich
ausgeführtes Paket erzeugt native SQL-Providerzeilen. Pro beobachtetem
Pfad/Input müssen die gemeldeten Übergaben zum bekannten Weg passen. Die
Anzahl ProcessInput-Ereignisse und eine physische Bufferzahl werden nicht
vorher aus der Zeilenzahl erfunden.

R-N02 verwendet ein eigenes Paket mit zwei wiederholten Data-Flow-Vorkommen
derselben Source-ID sowie einer parallel ausgeführten gleichnamigen Source
mit eigener ID. Eine kleine bekannte Datenmenge von zehn Zeilen wird im
Multicast auf zwei Pfade verteilt; ein Zweig aggregiert zu zwei Gruppen.
Ein zusätzlicher leerer Zweig prüft die beobachtete Logginggrenze, ohne eine
native Nullmeldung vorauszusetzen. Paketdefinition, tatsächliche Source-/
Path-/Komponenten-/Input-IDs, SDK-Vorkommen und eigene Zielreferenzen werden
vor Analyzerassertions gespeichert. Nur vorhandene Meldungen und eindeutige
Paare dürfen die jeweiligen 10-/2-Pfadsummen begründen. Fehlende native
Ereignisse werden als fehlende Qualifikation ausgewiesen, nicht synthetisch
nachgetragen oder durch ein anderes Ereignis ersetzt.

Für die spätere Consumerabnahme sind höchstens acht Aufrufe geplant:
R-N01 mit RAW vollständig, TABLE vollständig, CONSOLE, NONE, neuem Opt-in bei
Messages=0 und dem unveränderten v1.1-Taskmodus ohne neues Opt-in; R-N02 mit
RAW vollständig und TABLE unter gezieltem positivem Cap. Jeder Aufruf bindet
seinen eigenen JSON-/Status-/Callerframe an denselben erfassten Quellstand.
Vollständige Aufrufe behalten HighImpactConfirmed=1; der gezielte Cap wird
nach gespeicherten tatsächlichen Log-IDs so festgelegt, dass er eine fachliche
Grenze schneidet. Ein nicht erreichter Modus bleibt NOT_EXECUTED.

Die Qualifikation braucht Originalproviderzeilen mit exakten IDs und Texten,
ein unabhängiges Orakel für alle 44 neuen Felder, physischen Schemaabgleich,
gleichaufrufbezogene TABLE-/JSON-Parität, Versions-/Statusregeln, Caller- und
Quellenstabilität sowie gebundenes eigenes Cleanup. Erwartungswerte dürfen
nicht aus dem Analyzerergebnis zurückgerechnet werden. Ein neues natives
Format außerhalb ORPS_EN_1 führt zu einem erhaltenen fehlgeschlagenen oder
nicht qualifizierten Versuch und einer konkreten Vertragsentscheidung;
es wird nicht während derselben Abnahme heuristisch zugelassen.

Vor DDL oder Ausführung werden eigene Ressourcen eindeutig reserviert und
an Datenbank-/Objekt-ID, Erstellungszeit und eigene Scopekennung gebunden.
Auch teilweise angelegte eigene Objekte erhalten einen separaten Recoveryplan.
Primärfehler, Cleanupfehler, Quelleninventar und bewusst erhaltene Ressourcen
werden getrennt gespeichert. Fremde Runs, Pakete und Loggingquellen bleiben
unberührt; policyblockierte Löschungen werden nicht über andere APIs wiederholt.
Native Aufrufe zählen vor ihren Effekten in einer eigenen endlichen späteren
Welle; historische Budgets und Fehlrecords werden nicht zurückgesetzt.

### R9. Primärquellen, Review und weitere Freigabe

Am 18. Oktober 2026 wurden ausschließlich folgende Herstellerseiten gelesen:

- [Data Flow Task, Meldungsfelder und Beispiele](https://learn.microsoft.com/en-us/sql/integration-services/control-flow/data-flow-task?view=sql-server-ver17) beschreibt PathID, Zielkomponente, Input und Übergabemenge. Die enge Grammatik und alle Ablehnungsregeln sind Entwurfsentscheidungen, keine zusätzliche Herstellerzusage.
- [SSIS Logging, Ereignis und SQL-Providergrenzen](https://learn.microsoft.com/en-us/sql/integration-services/performance/integration-services-ssis-logging?view=sql-server-ver17) beschreibt selektives Logging und die message-Kapazität des SQL-Providers. Fehlende Meldungen sind deshalb kein Abwesenheitsnachweis.

Der bisherige unabhängige Reviewer prüft den konkreten Entwurf einschließlich
Kompatibilitätsmatrix, PathID-Semantik, strikter Grammatik, Kappungsrisiko,
Paarzuordnung, Mengenbasis, NULL-/Nullmengen, atomarer Fehlerbehandlung,
Quellprojektion und unabhängigem Abnahmeorakel. Der Review wurde ohne offene P1/P2 abgeschlossen. Die konkrete menschliche
Freigabe zur Umsetzung samt begrenztem Abnahmeumfang und regulärem PR liegt vor.

Eine spätere Lieferung umfasst Produktquelle, betroffene Inventare,
Installer, Consumerverträge, Guide und Status zusammen. Testauswahl und CI
folgen der kanonischen CI_Test_Strategy, einschließlich exaktem Head und
regulärer MatchHead-Integration. Die Freigabe umfasst den begrenzten Slice mit seinen betroffenen
Prüfungen und der regulären Integration. Historische grüne Abnahmen werden
nicht erneut als eigene Welle gestartet. SSIS-001 bleibt
PARTIAL_PRODUCT_FUNCTION; weitere Backlogs und WI-0009 GATE-0001 bleiben offen.


## Erforderliche Vertragsentscheidung: beobachtetes natives Zeilenflussformat vom 18. Oktober 2026

**Status:** am 18. Oktober 2026 ausdrücklich menschlich freigegebene Ergänzung.
Der Benutzer hat ORPS_EN_2 samt begrenzter Folgeabnahme und regulärer
PR-Lieferung freigegeben. Die folgenden Formatregeln und Abnahmegrenzen sind
verbindlich; historische fehlgeschlagene Versuche bleiben erhalten.

### Tatsächlicher Unterschied und Liefergrenze

Die zwei tatsächlich ausgeführten eigenen Paketszenarien auf Windows
SQL/SSIS 17.0.5015.4 mit CL170 erzeugen OnPipelineRowsSent-Meldungen, deren
gespeicherter Präfix `Rows were provided to a data flow component as input. :  : `
lautet. Zwischen den beiden Doppelpunkten stehen zwei Leerzeichen. Danach
folgen zehn Felder sowie ein abschließender Trenner, während ORPS_EN_1 genau
sieben Felder ohne Suffix und einen anderen Präfix verlangt. Die Quelle
enthält drei Kandidaten im linearen Szenario und 25 im zweiten Szenario.
Der unveränderte Decoder klassifiziert diese Texte als UNSUPPORTED_FORMAT;
rowFlow bleibt leer. Das entspricht der freigegebenen Ablehnungsregel und
ist keine positive native Pfadsummenabnahme.

Die sechs wiederverwendeten Consumervergleiche mit 682 Prüfungen bestätigen
die konservative Ausgabe, Status- und Paritätsverträge. Sie qualifizieren
weder erfolgreich geparste native Payloadfelder noch positive native
Pfadsummen. Die abschließende positive Profilprüfung schlägt fehl. Beide
historischen nativen Versuche mit Paket- beziehungsweise Restfortschritt
bleiben insgesamt FAILED_NOT_QUALIFIED; die ursprünglichen Captures und
Fehlhistorien werden erhalten. Eigene Laufzeitdatenbanken sind entfernt,
ihre Inventare restauriert; es wird kein weiterer Paketlauf gestartet.

### Freigegebene enge Ergänzung ORPS_EN_2

ORPS_EN_2 ergänzt als zweites streng vollständiges Profil den Decoder. ORPS_EN_1 und seine
Ablehnungsregeln bleiben erhalten. Produktziel 1.2.0, Parameterposition 22,
SchemaVersion 3, RowFlowCatalogVersion 1 sowie alle 19-/25-Feldschemas bleiben
für diese erste noch nicht veröffentlichte Lieferung unverändert. Die
ParserId unterscheidet die beiden freigegebenen Profile.

Der neue genaue Unicode-Präfix ist der oben dokumentierte beobachtete Text.
Nach dem Präfix stehen genau zehn durch ` : ` getrennte Felder in dieser
Reihenfolge; anschließend ist genau ein abschließender ` : ` erforderlich:

| Position | Inhalt und Zulassung |
|---|---|
| 1–7 | PathId, PathName, DestinationComponentId, DestinationComponentName, InputId, InputName und RowsSent behalten die Typ-, Zahlen-, Namens- und Bereichsregeln aus R3. |
| 8 | Der Text muss ordinal einschließlich aller Leerzeichen mit DestinationComponentName aus Feld 4 übereinstimmen. |
| 9 | Der Text hat die genaue äußere Form Paths[Inhalt]. Inhalt ist nicht leer und enthält keinen Doppelpunkt, CR, LF, TAB, NUL oder weitere eckige Klammern. Er wird ausschließlich zur vollständigen Formprüfung verwendet und nicht als zusätzliche Lineage ausgegeben. |
| 10 | Der Text muss ordinal der Verkettung DestinationComponentName + .Inputs[ + InputName + ] entsprechen. |

Leere oder zusätzliche Felder, fehlender oder mehrfacher Endtrenner,
abweichender Wiederholungstext und sonstiger Suffix werden abgewiesen.
Nur bei erfolgreicher vollständiger Prüfung aller zehn Felder werden die
sieben bestehenden Payloadfelder ausgegeben. Die drei Zusatztexte erzeugen
keine neuen Ergebnisspalten und keine Interpretation als technische Root Cause,
Quellkomponente oder Graph. Der vorhandene Bytekapazitätsguard gilt vor jeder
Profilwahl; opt-out, NULL-, Fehler-, Deadline- und Paarregeln bleiben erhalten.
Die bestehende ParseStatus-Priorität gilt entsprechend; ein erkannter neuer
Präfix mit fehlerhaftem Gesamtaufbau erhält ORPS_EN_2/MALFORMED_PAYLOAD.
Syntaktisch gültige Zahlen außerhalb des Bereichs erhalten erst danach
NUMERIC_OUT_OF_RANGE. Ein anderes Format wird weiterhin nicht heuristisch
zugelassen. Die Laufzeitquelle qualifiziert ausschließlich das konkret
beobachtete Profil, keine allgemeine Sprach- oder Versionsmatrix.

### Numerische IDs und unabhängige Gegenprüfung

Die native Meldung enthält andere numerische Path-/Komponenten-/Input-IDs
als die vor SaveToXml erfassten SDK-Authoringobjekte. Solche Zahlen werden
nicht gleichgesetzt. Die öffentlichen Felder behalten die tatsächlich
gespeicherten Laufzeitkennungen; es erfolgt keine Normalisierung auf
Authoring-IDs und keine Umbenennung von PathId in OutputId.

Die zusätzliche Gegenprüfung bindet die tatsächlichen Providerzeilen über
ihre Originalhashes, Execution-ID, Source-ID und Log-ID. Die sieben Werte
werden unabhängig vom Produkt aus dem gespeicherten vollständigen Text
bestimmt. Die erhaltene Paketdefinition und SDK-Callbacks binden Source,
eindeutige synthetische Pfad-/Komponenten-/Inputnamen, bekannte Zielmengen,
Wiederholungen und überlappende Ausführung. Ein gleicher numerischer Wert
zwischen Authoring und Runtime wird ausdrücklich nicht als Beweis verlangt
oder behauptet. Zusätzliche oder nicht gebundene beobachtete Pfad-/Input-
Tupel dürfen nicht allein wegen passender Summen akzeptiert werden.

### Freigegebene begrenzte Fortsetzung

Die neue Profilergänzung benötigt gezielte synthetische Positiv- und
Negativfälle für sämtliche Zusatzregeln und den unveränderten Guard. Eine
unabhängige Gegenprüfung verwirft Mutationen von Präfix, Trennern, Zusatztext,
Runtime-IDs, Paarzuordnung, Summe, NULL, Evidenz und Callerframe. Bereits
erfolgreiche unveränderte Fälle werden gebunden wiederverwendet.

Für den positiven Decodervergleich sollen die erhaltenen eigenen nativen
Originalproviderzeilen samt IDs, Typen und vollständigen Texten hashgebunden
in eine neue eindeutig eigene isolierte Loggingtesttabelle übernommen
werden. Das ist eine Wiederherstellung bereits erzeugter synthetischer
Providerdaten für den Analyzerconsumer, kein frischer SSIS-Providerlauf.
Die Originalevidenz wird nicht überschrieben. Es wird weder ein Paket erneut
ausgeführt noch eine VM, Installation oder alte Quelle wiederhergestellt.

Geplant sind höchstens zwei neue Arrange-/Consumer-Versuche mit jeweils
höchstens acht bereits definierten Consumerkonstellationen; erfolgreiche
unveränderte Einzelbelege werden nicht erneut ausgeführt. Die Kombinationen
von R-N01 und R-N02 behalten ihre bekannten 10007-/10-/2-Zielmengen und die
aktuell gespeicherten ursprünglichen Ereignisgrenzen. Alle 44 neuen Felder,
physische Schemas, JSON-Parität, Status, Caps und Outputmodi werden gegen
die gebundenen Originalzeilen unabhängig geprüft. Bericht und Status trennen
frühere tatsächliche Paketausführung von neuer Consumerabnahme aus
wiederhergestelltem Material. Ein neuer vollständiger nativer Paketlauf wird
daraus nicht behauptet. Identitätsgebundenes eigenes Cleanup und Vor-/Nach-
Inventar gehören zu jedem neuen Versuch.

Die Freigabe umfasst genau diesen Profil- und Abnahmeänderungsumfang einschließlich
eines begrenzten unabhängigen Delta-/Ergebnisreviews sowie der erforderlichen
exakten Head-CI und regulären PR-Integration abdecken. Geschlossene frühere
Budgets bleiben unverändert; Native3 ist kein Anlass für Native4 oder einen
Budgetreset. Weitere Decoder, Sprachen und vertiefte SSIS-Funktionen bleiben
ausgenommen. Die konkrete Freigabe liegt vor. Die neue Consumerabnahme wird getrennt
von den geschlossenen historischen Paketversuchen geführt; eine erfolgreiche
Lieferung wird erst nach Erfüllung der zugehörigen Gates dokumentiert.

## Freigegebene Erweiterung: Legacy-Komponentenphasenzeiten aus PipelineComponentTime vom 18. Oktober 2026

**Status:** konkreter menschlich freigegebener P1–P9-Erweiterungsvertrag
für Implementierung, begrenzte Abnahme und reguläre PR-Lieferung. Der vorherige
Vertragsreview wurde ohne offene P1/P2 abgeschlossen und bleibt vom
tatsächlich ausgeführten Abnahmenachweis getrennt.

### P1. Auswahl und begrenzter Nutzen

PR393 liefert beobachtete Taskintervalle und Loggingabdeckung, PR394 die
beobachteten Legacy-Pfadtransfers. Im Legacy-Analyzer fehlt weiterhin die
strukturierte Interpretation gemeldeter Komponentenphasenzeiten. Der nächste
empfohlene Teilslice aus Backlogschritt 3 umfasst deshalb PipelineComponentTime,
zunächst ausschließlich die unten genau festgelegten englischen Meldungen für
ProcessInput und PrimeOutput. Diese Auswahl erklärt nicht die übrigen Teile
der Backlogschritte 2 oder 3 für abgeschlossen.

Der Katalogkern projiziert bereits catalog.execution_component_phases. Dieser
Entwurf erweitert ausschließlich monitor.USP_SsisLegacyLogAnalysis und weder
den Katalogvertrag noch dessen noch offene Performance-/Verbose-Abnahme.
Durchsatz, CPU-Zeit, exklusive Zeit, kritischer Pfad, komplette Phasenabdeckung,
Tasktypen, Looprekonstruktion, Graphkorrelation und historische Vergleiche
gehören nicht zum Slice. Die bestehende RowFlow-Summe wird nicht durch eine
gemeldete Komponentenzeit geteilt.

Die beiden erhaltenen Originalquellen der begrenzten Zeilenflussabnahme
enthalten kein PipelineComponentTime. Ihr damaliger Ereignisfilter forderte
dieses Ereignis nicht an. Daraus folgt nur eine fehlende positive Quelle in
diesen zwei Beständen, keine Aussage über andere Datenbestände oder fehlende
Herstellerfähigkeit. Geschlossene Abnahmen werden dafür nicht wiederholt.

### P2. API, Opt-in und Ausgabeversionierung

Die freigegebene Procedureversion ist 1.3.0 mit genau einem zusätzlichen Parameter
IncludeComponentPhaseAnalysis bit=0 an Position 23. NULL wird wie 0 behandelt.
Alle bisherigen 22 Positionen, Defaults, OUTPUTs und Aufrufbedeutungen bleiben
erhalten. Das neue Opt-in ist unabhängig von IncludeTaskAnalysis und
IncludeRowFlowAnalysis. Es verwendet dieselbe explizite Loggingquelle,
Execution-GUID, bestätigte N+1-Eingabe und vorhandene v1-Ableitung.

| Task-Opt-in | RowFlow-Opt-in | Phasen-Opt-in | SchemaVersion | Fachliche RAW-/TABLE-/JSON-Mengen |
|---|---|---|---|---|
| 0 | 0 | 0 | 1 | 9 |
| 1 | 0 | 0 | 2 | 11 |
| 0 | 1 | 0 | 3 | 11 |
| 1 | 1 | 0 | 3 | 13 |
| 0 | 0 | 1 | 4 | 11 |
| 1 | 0 | 1 | 4 | 13 |
| 0 | 1 | 1 | 4 | 13 |
| 1 | 1 | 1 | 4 | 15 |

Die bisherigen technischen Fachmengen behalten ihre Reihenfolge. Bei neuem
Opt-in folgen componentPhaseEvents und componentPhaseTimes als letzte zwei
Mengen nach gegebenenfalls vorhandenen Task- und RowFlow-Mengen. Nur dann
enthält JSON die beiden gleichnamigen Arrays und die numerische Metadatenangabe
ComponentPhaseCatalogVersion=1. TaskAnalysisCatalogVersion und
RowFlowCatalogVersion erscheinen weiterhin ausschließlich bei ihrem eigenen
Opt-in. Ohne neues Opt-in fehlen die neuen Arrays, Metadaten und Quellenzeile;
die bisherige Schemaauswahl bleibt exakt erhalten.

TABLE erlaubt die beiden Namen nur bei neuem Opt-in. Sie sind vor dem ersten
fachlichen Quellzugriff in die bestehende Mappingprüfung aufzunehmen.
Unbekannte, deaktivierte oder kollidierende Ziele behalten Fehler 51011 und die
bisherigen Temp-Tabellen-/Ownershipregeln. RAW und TABLE liefern native Werte,
JSON dieselben Werte einschließlich expliziter NULLs. CONSOLE ergänzt im
bisherigen einzigen Grid als letzte Spalten PhasenMeldungen,
PhasenGeleseneMeldungen und PhasenKontextMeldungen, jeweils nullable bigint.
Die Zähler zählen Kandidaten, erfolgreich geparste Kandidaten und Kandidaten
mit eindeutigem Berichtskontext, niemals Millisekunden. Vor atomarer Übernahme
sind sie NULL; NONE liefert kein fachliches Grid. Hilfe erzeugt keine neue
Quellenzeile und ändert keine Lese- oder Fehlerdefaults.

### P3. Exakter Meldungskatalog PCT_EN_1

Ein Kandidat ist ausschließlich eine gespeicherte Zeile mit ordinal exakt
PipelineComponentTime als event. OnInformation, lokalisierte Ereignisnamen,
ähnliche Schreibweisen, datacode und DataBytes sind kein Ersatz. datacode bleibt
uninterpretiert in der bestehenden Timeline; zusätzliche Quellspalten werden
nicht fachlich gelesen. IncludeMessages=0 verhindert wie bisher jeden fachlichen
message-Zugriff und lässt beide neuen Mengen leer.

Das freigegebene Profil PCT_EN_1 hat genau zwei vollständige Alternativen.
Die geschweiften Variablennamen bezeichnen Felder und sind keine Textbestandteile:

```text
The component "{ComponentName}" ({ComponentId}) spent {ReportedDurationMs} milliseconds in ProcessInput.
The component "{ComponentName}" ({ComponentId}) spent {ReportedDurationMs} milliseconds in PrimeOutput filling buffers on output "{OutputName}" ({OutputId}).
```

Jedes Leerzeichen, Anführungszeichen, jede Klammer und der abschließende Punkt
ist festgelegt. Es gibt weder Präfix-/Suffixtext noch Endleerzeichen,
Zeilenumbrüche, alternative Einheiten, optionale Teilsätze oder mehrere
verkettete Meldungen. ComponentName und gegebenenfalls OutputName besitzen
1 bis 4000 UTF-16-Codeeinheiten und enthalten weder ein doppeltes Anführungszeichen
noch CR, LF, TAB oder NUL. Namen bleiben einschließlich Case, Leerzeichen und
sonstiger erlaubter Zeichen ordinal erhalten; es gibt kein Trim, Unescape,
Namensfallback oder Normalisieren auf Authoringnamen.

Zahlentoken bestehen ausschließlich aus ASCII-Ziffern. Ihre kanonische Form
ist 0 oder eine Ziffer 1–9 mit nachfolgenden Ziffern; Plus, Minus, führende
Nullen, Dezimal-/Tausendertrenner, Exponenten und zusätzliche Leerzeichen sind
unzulässig. ComponentId und OutputId liegen in 1 bis 2147483647,
ReportedDurationMs in 0 bis 9223372036854775807. Die gespeicherte Runtime-ID
wird ausgegeben; SDK-Authoring-IDs sind kein numerischer Gleichheitsbeweis.
ProcessInput setzt OutputId und OutputName auf NULL. PrimeOutput benötigt
beide Outputfelder; OutputId ist ausdrücklich keine RowFlow-PathId.

Validate, PreExecute, PostExecute, ProcessOutput, andere Methoden, Sprachen und
Formate bleiben in diesem ersten Profil uninterpretiert. Insbesondere wird
ProcessOutput nicht als Alias für PrimeOutput zugelassen. Ein späterer Ausbau
benötigt einen eigenen konkreten Vertrag und passende Primär-/Runtimequellen.

Der bestehende Kapazitätsguard wird vor einer Formatprüfung angewendet.
B ist die kleinere positive deklarierte message-Bytekapazität und 4096;
bei nvarchar(max) ist B=4096. DATALENGTH(message)>=B bedeutet mögliche Kappung,
auch bei abschließenden Leerzeichen. Die Priorität ist:

| Bedingung | ParseStatus | ParserId und Payload |
|---|---|---|
| message ist NULL. | MESSAGE_MISSING | Alles ist NULL. |
| Gespeicherte Bytezahl erreicht B. | POTENTIALLY_TRUNCATED | Alles ist NULL. |
| Der exakte Anfang The component mit anschließendem Leerzeichen und doppeltem Anführungszeichen fehlt. | UNSUPPORTED_FORMAT | Alles ist NULL. |
| Keine der zwei Gesamtformen, Feld-/Namens- oder Zahlensyntaxregeln passt. | MALFORMED_PAYLOAD | ParserId=PCT_EN_1, alle sechs Payloadfelder sind NULL. |
| Vollständige Form ist gültig, aber eine Zahl liegt außerhalb ihres Bereichs. | NUMERIC_OUT_OF_RANGE | ParserId=PCT_EN_1, alle sechs Payloadfelder sind NULL. |
| Sämtliche Prüfungen bestehen. | PARSED | ParserId=PCT_EN_1, alle formabhängigen Payloadfelder sind vorhanden. |

Die sechs Payloadfelder sind ComponentId, ComponentName, PhaseName,
ReportedDurationMs, OutputId und OutputName. PhaseName ist ausschließlich
ProcessInput oder PrimeOutput. Ein formal nicht zugelassener Methodentext
mit erkanntem Präfix erhält MALFORMED_PAYLOAD, ohne damit einen Hersteller-
oder Paketfehler zu behaupten. Eine leere Meldung ist UNSUPPORTED_FORMAT.
Es werden keine teilweise geparsten Kennungen, Namen oder Zeiten übernommen.
Der vollständige gespeicherte Rawtext bleibt über den bisherigen Timelineexport
verfügbar; ein weiteres Message- oder DataBytes-Resultset wird nicht eingeführt.

### P4. Berichtskontext und Aggregation

EventTime ist der gespeicherte Zeitpunkt der Meldung. Er ist kein Phasenbeginn
oder Phasenende. Aus EventTime und ReportedDurationMs wird kein künstliches
Intervall rekonstruiert. ReportedDurationMs ist eine vom Produzenten berichtete
Methodenzeit; die Abnahme prüft deren unveränderte Übernahme, nicht die
Genauigkeit einer herstellerinternen Uhr oder gemessene CPU-Arbeit.

Die bestehende v1-iterations-Ableitung bleibt unverändert. Für einen PARSED-
Kandidaten wird lediglich ein Berichtskontext bestimmt: Genau ein vorhandenes
EXECUTE-Paar derselben SourceId mit PairStatus=PAIRED muss
StartLogId<LogId<EndLogId und StartTime<=EventTime<=EndTime erfüllen.
Gleiche gespeicherte Zeiten sind erlaubt. Die IDs und Zeiten bezeichnen die
beobachteten äußeren Grenzen des Kontextes, keine Messgrenzen der Methode.
Auch ein passender Kontext beweist keine additive, exklusive oder vollständig
diesem Vorkommen zurechenbare interne Methodenzeit. Spät protokollierte oder
kumulierte Berichte werden nicht heuristisch einem früheren Vorkommen zugeteilt.

ContextStatus gilt in fester Reihenfolge: Nicht-PARSED ergibt NOT_PARSED;
fehlende SourceId SOURCE_ID_MISSING; fehlende EventTime EVENT_TIME_MISSING;
kein ID-einschließendes zugelassenes Paar NO_OBSERVED_PAIR; mehrere solche
Paare AMBIGUOUS_PAIR; Zeit außerhalb des einzigen Paars TIME_OUTSIDE_PAIR;
sonst ASSIGNED. Nur ASSIGNED setzt ContextStartLogId und ContextEndLogId.
PACKAGE-/VALIDATE-Paare, gleiche Namen oder Nachbar-Source-IDs sind kein Ersatz.
Nicht zugeordnete geparste Kandidaten behalten ihren berichteten Wert, tragen
aber zu keiner Kontextgruppe bei.

componentPhaseTimes gruppiert ausschließlich ASSIGNED-Kandidaten nach
ExecutionId, SourceId, beiden Context-Log-IDs, ComponentId, PhaseName und
OutputId. Für ProcessInput ist OutputId ein eigener NULL-Schlüssel, kein
erfundener numerischer Sentinel. Unterschiedliche Ausgänge, Methoden, Sources
oder Kontexte bleiben getrennt. Keine Gruppe vereinigt mehrere Phasen oder
bildet eine Komponenten-, Task- oder Pakettotalzeit.

EventCount zählt beitragende Log-IDs. ReportedDurationSumMs ist deren Summe
nach Konvertierung in decimal(38,0), Min/Max das Minimum/Maximum der bigint-
Werte. AvgReportedDurationMs ist der arithmetische Mittelwert der gemeldeten
Werte als decimal(38,6), auf sechs Nachkommastellen kaufmännisch gerundet (bei exakter Hälfte aufwärts). Das ist ein
Mittelwert gespeicherter Berichte, kein Mittelwert einzelner Methodenaufrufe:
Ein Bericht kann seinerseits mehrere interne Aufrufe zusammenfassen. Der
Nenner ist exakt EventCount und nie 0. Summe und Mittelwert werden nicht
stillschweigend in bigint eingeengt oder in eine andere Einheit umgerechnet.

Explizite 0 bleibt 0; eine fehlende Meldung erzeugt weder 0 noch eine künstliche
Gruppe. Identische Texte mit verschiedenen IDs bleiben Beiträge. Die Summe
ist ausschließlich die Summe gespeicherter berichteter Werte, keine Zusage
über disjunkte Messungen oder Deduplizierung kumulativer Meldungen.
Gruppennamen ergeben sich nur aus den beitragenden Zeilen. Genau ein ordinaler
Nicht-NULL-Wert bleibt erhalten; mehrere Werte ergeben NULL und das jeweilige
Conflict-Bit. Nur NULL-Source-Namen ergeben NULL ohne Konflikt. EvidenceLogIdsJson
ist ein JSON-Arraystring der Log-IDs in aufsteigender Reihenfolge. First/Last-
ObservedTime verwenden die gespeicherten Meldungszeiten, keine Methodenzeiten.

### P5. Native Ergebnisschemas

Alle Textspalten verwenden explizit COLLATE SQL_Latin1_General_CP1_CS_AS.
Typen, Nullbarkeit und Reihenfolge gelten identisch für RAW und TABLE;
JSON transportiert dieselben Schlüssel und Werte. Die technischen Mengen verwenden #SsisLegacyLogAnalysis_ComponentPhaseEvents
und #SsisLegacyLogAnalysis_ComponentPhaseTimes.

componentPhaseEvents besitzt genau 18 Spalten:

| Position | Spalte | Typ und Nullbarkeit |
|---|---|---|
| 1 | PhaseEventOrdinal | bigint NOT NULL |
| 2 | ExecutionId | uniqueidentifier NOT NULL |
| 3 | LogId | int NOT NULL |
| 4 | SourceId | uniqueidentifier NULL |
| 5 | SourceName | nvarchar(4000) NULL |
| 6 | EventTime | datetime NULL |
| 7 | ParserId | varchar(32) NULL |
| 8 | ParseStatus | varchar(40) NOT NULL |
| 9 | ComponentId | int NULL |
| 10 | ComponentName | nvarchar(4000) NULL |
| 11 | PhaseName | varchar(32) NULL |
| 12 | ReportedDurationMs | bigint NULL |
| 13 | OutputId | int NULL |
| 14 | OutputName | nvarchar(4000) NULL |
| 15 | ContextStartLogId | int NULL |
| 16 | ContextEndLogId | int NULL |
| 17 | ContextStatus | varchar(40) NOT NULL |
| 18 | InputIsTruncated | bit NOT NULL |

componentPhaseTimes besitzt genau 24 Spalten:

| Position | Spalte | Typ und Nullbarkeit |
|---|---|---|
| 1 | PhaseTimeOrdinal | bigint NOT NULL |
| 2 | ExecutionId | uniqueidentifier NOT NULL |
| 3 | SourceId | uniqueidentifier NOT NULL |
| 4 | SourceName | nvarchar(4000) NULL |
| 5 | ContextStartLogId | int NOT NULL |
| 6 | ContextEndLogId | int NOT NULL |
| 7 | ComponentId | int NOT NULL |
| 8 | ComponentName | nvarchar(4000) NULL |
| 9 | PhaseName | varchar(32) NOT NULL |
| 10 | OutputId | int NULL |
| 11 | OutputName | nvarchar(4000) NULL |
| 12 | EventCount | bigint NOT NULL |
| 13 | ReportedDurationSumMs | decimal(38,0) NOT NULL |
| 14 | MinReportedDurationMs | bigint NOT NULL |
| 15 | MaxReportedDurationMs | bigint NOT NULL |
| 16 | AvgReportedDurationMs | decimal(38,6) NOT NULL |
| 17 | FirstObservedTime | datetime NOT NULL |
| 18 | LastObservedTime | datetime NOT NULL |
| 19 | EvidenceLogIdsJson | nvarchar(max) NOT NULL |
| 20 | SourceNameConflict | bit NOT NULL |
| 21 | ComponentNameConflict | bit NOT NULL |
| 22 | OutputNameConflict | bit NOT NULL |
| 23 | InputIsTruncated | bit NOT NULL |
| 24 | CoverageStatus | varchar(40) NOT NULL |

PhaseEventOrdinal folgt LogId aufsteigend. PhaseTimeOrdinal folgt SourceId
nach bestehender SQL-uniqueidentifier-Ordnung, ContextStartLogId,
ContextEndLogId, ComponentId, PhaseName ordinal und OutputId mit NULL zuerst,
jeweils aufsteigend. CoverageStatus ist bei Namenskonflikt
OBSERVED_NAME_CONFLICT, sonst bei Eingabekappung OBSERVED_PREFIX, sonst
OBSERVED_REPORTS. Es gibt keinen Coveragewert COMPLETE_PHASE_TIME.

### P6. Quellenstatus, Fehler, Deadline und Grenzen

Nur beim neuen Opt-in erscheint sourceStatus mit SourceOrdinal=7 und
SourceName=componentPhaseAnalysis. Die festen Ordinale 1–4 und optionalen
5/6 bleiben unverändert; Lücken werden nicht umnummeriert. Die neue Stufe
benötigt einen gültigen bestehenden Puffer und vollständig abgeschlossene
v1-eventDerivation. Task- und RowFlow-Opt-in dürfen ausgeschaltet sein;
ihr eigener Fehler zerstört einen gültigen v1-Bestand nicht.

Zulassungsgründe haben die Reihenfolge INVALID_PARAMETER,
NO_VALID_EVENT_BUFFER, PRIOR_DERIVATION_NOT_COMPLETED, MESSAGES_DISABLED und
TIME_BUDGET_EXHAUSTED. Vor Stufenbeginn ergibt jeder dieser Gründe NOT_READ/1
mit beiden neuen Arrays leer, Counts und CONSOLE-Werten NULL. Vorhandene
native Fehlerpaare und andere gültige Resultsets bleiben erhalten. Kein
message-Zugriff wird durch einen anschließenden Parser-Opt-out kaschiert.

Der gemeinsame kooperative Deadlinezeitpunkt wird vor Beginn und vor der
atomaren Übernahme beider Mengen geprüft. Ablauf nach Beginn verwirft beide
Mengen und alle drei Zähler; Zeile 7 wird AVAILABLE_LIMITED/1 mit dem Detail
TIME_BUDGET_EXHAUSTED. Kein Timeout verlängert das Aufrufbudget oder beendet
eine laufende SQL-Anweisung hart. Fehlerprüfungen erhalten ihre echte native
Nummer und ihren vollständigen Text in Zeile 7. Die bestehende Klassifikation
bleibt maßgeblich: 229/262/297/300/371 ergeben DENIED,
207/208/911/916/942 SOURCE_UNAVAILABLE und sonstige echte Fehler ERROR_HANDLED.
Ein Fehler verwirft
beide neuen Mengen und setzt ihre Counts NULL; Parserablehnungen sind keine
SQL-Exceptions. Es gibt keine Faultparameter, versteckten Testschalter oder
Produkt-, Lab- oder System-Overrides.

Nach erfolgreicher nichtleerer Übernahme gilt AVAILABLE_LIMITED/1 bei
Eingabekappung, einem nicht geparsten oder nicht zugeordneten Kandidaten oder
einem Namenskonflikt; andernfalls AVAILABLE/0. Ohne Kandidaten gilt
AVAILABLE_EMPTY/0 mit Counts 0. Ein leeres Ergebnis beweist weder fehlende
Komponentenausführung noch deaktiviertes Logging. ObservedRowCount und
ReturnedRowCount sind C+G bei C Kandidaten und G Gruppen. Detail lautet
Candidates=C;Parsed=P;ContextAssigned=A;Groups=G. IsTruncated bleibt bei
vollständigem Export dieser abgeleiteten Mengen 0; InputIsTruncated beschreibt
die vorgelagerte Eingabekappung. Jede neue Menge hat höchstens E Zeilen bei
E freigegebenen Pufferereignissen und benötigt keinen zweiten Fachcap.

Die Warnungscodes sind jeweils höchstens einmal pro tatsächlichem Zustand:
COMPONENT_PHASE_EVENT_NOT_OBSERVED, COMPONENT_PHASE_MESSAGES_DISABLED,
COMPONENT_PHASE_TIME_BUDGET_EXHAUSTED, COMPONENT_PHASE_ANALYSIS_ERROR,
COMPONENT_PHASE_PAYLOAD_NOT_PARSED, COMPONENT_PHASE_CONTEXT_NOT_ASSIGNED und
COMPONENT_PHASE_NAME_CONFLICT. Ein NOT_PARSED-Kandidat erzeugt keine zusätzliche
Kontextablehnungswarnung. Warntexte verwenden feste Erklärungen und generische
Counts, keine interpolierten Meldungswerte. Die neue Stufe erzeugt keine
loggingQuality- oder findings-Zeilen. Die unveränderte v1-Qualitätsstufe darf
PipelineComponentTime weiterhin als unbekannt markieren; dann kann der
Modulstatus trotz AVAILABLE der Zeile 7 AVAILABLE_LIMITED bleiben.

Neue Partialität wird in Modulstatus und OUTPUTs übernommen, ohne einen schon
schwereren Status herabzustufen. Das erste echte native Fehlerpaar bleibt in
der Quellenfolge 1–4, optional 5, optional 6, dann 7 erhalten. Bestehende
OnError-Nutzdaten sind kein erfundener SQL-Fehler. MaxZeilen, HighImpact-Gates,
LockTimeout, Callerzustand und die vollständige Duplikatprüfung des N+1-Puffers
bleiben unverändert. Der Sentinel wird vor jedem neuen Fachschritt entfernt.
IncludeTimeline=0 unterdrückt nur den Timelineexport. Kostenklasse bleibt
LOW_HIGH_OPT_IN; zusätzlicher Parser-, Sortier-, Evidenz- und Gruppenaufwand
beansprucht CPU, Speicher und tempdb ohne Laufzeit- oder Eigenlastgarantie.
Der Analyzer verändert keine Quelle, Pakete, Rechte oder Loggingkonfiguration
und verlangt keine zusätzlichen Quellindizes.

### P7. Geplante synthetische Abnahme

Die folgenden Gruppen bilden den freigegebenen synthetischen Umfang. Die
Umsetzung verwendet
eine eigene kompatible gespeicherte Quelle und die unveränderte Gesamt-SUT.
Eine unabhängige Referenz bestimmt alle 42 neuen Felder aus vorher festgelegten
Ereignissen und Sollwerten; reine Parität ist kein Ersatz. Physische Schema-
Facetten umfassen Reihenfolge, Typ, Länge, Precision, Scale, Collation,
Nullbarkeit und fehlende Identity-/Computed-Eigenschaften.

| Gruppe | Verbindliches Soll für eine spätere Abnahme |
|---|---|
| P-S01 | Beide vollständigen englischen Alternativen liefern alle 18-/24-Feldwerte; ProcessInput hat NULL-Output, PrimeOutput den expliziten Output und eigene Gruppe. |
| P-S02 | Exakte Präfixe, Satzpunkt, Leerzeichen, Quotes, Klammern und suffixfreies Ende; fehlende/zusätzliche Tokens und nicht zugelassene Methoden oder Sprachen liefern keinen Teilpayload. |
| P-S03 | IDs bis int-Max, Zeitwerte 0, über int und bis bigint-Max sowie Bereichsüberschreitungen; Vorzeichen, führende Nullen, Localezahlen und Exponenten erhalten die festgelegte Ablehnung. Formfehler haben Vorrang vor Bereichsfehlern. |
| P-S04 | Berichte 3, 0 und 8 ergeben EventCount=3, Summe=11, Min=0, Max=8 und Mittelwert=3.666667. Zwei bigint-Max-Berichte ergeben eine decimal-Summe oberhalb bigint; gleiche Texte mit verschiedenen IDs bleiben Beiträge. |
| P-S05 | Getrennte Methoden, Ausgänge, Komponenten, Sources und Berichtskontexte bleiben getrennt; gleiche Anzeigenamen und Runtime-/Design-ID-Unterschiede erzeugen keine Querverknüpfung oder Gesamtlaufzeit. |
| P-S06 | Nur eindeutiger EXECUTE-Berichtskontext; gleiche Zeitwerte, fehlende IDs/Zeit/Ende, mehrdeutige Paare, rückläufige Zeit und Zeit außerhalb des ID-Paars prüfen jede ContextStatus-Priorität. Der berichtete Wert erzeugt kein errechnetes Phasenintervall. |
| P-S07 | UTF-16-Namen einschließlich Case und Endleerzeichen, Konflikte und ausschließlich NULL-Source-Namen; verbotene Quotes, CR/LF/TAB/NUL werden abgewiesen. Die tatsächlichen Namen und Konfliktbits sind ordinal geprüft. |
| P-S08 | DATALENGTH an B−2, B und B+2, schmale/breite/MAX-Meldungsspalten und Endleerzeichen; potenzielle Kappung liefert weder Zeitpayload noch Gruppensumme. |
| P-S09 | N+1-Präfix schneidet Meldung oder Kontextende; Sentinel beeinflusst keine Namen, Zeiten oder Evidenz. Doppelte IDs auch am Sentinel verwerfen den gesamten Puffer vor der Zusatzstufe. |
| P-S10 | Alle acht Opt-in-Kombinationen prüfen Parameterpositionen, Schema1/2/3/4, Fachmengenanzahl, Metadaten und lückenhafte feste Source-Ordinale. Deaktivierte TABLE-Namen werfen vor dem Quellzugriff 51011. |
| P-S11 | Unabhängige 42-Feldreferenz, JSON-Feld-/Arraypflicht und NULLs; RAW/TABLE/JSON-Parität, physische Schemata, CONSOLE genau ein Grid mit drei nullable bigint-Zählern und NONE ohne Fachgrid. |
| P-S12 | Meldungs-Opt-out ohne fachlichen message-Zugriff, ungültige Quelle, nicht zugelassene berechnete Pflichtspalten, direkte native 229-Gegenprobe und unveränderte erste native Fehlertexte/Callerframes. |
| P-S13 | Prior-v1-Ableitungsfehler, vor Beginn erschöpftes Budget, Deadline vor atomarer Übernahme und echter Fehler in der neuen Stufe; neue Mengen/Counts werden gemeinsam verworfen. Falls keine deterministische Original-SUT-Erzeugung möglich ist, werden quellgebundene extrahierte Stufen getrennt ausgewiesen, ohne Produktions-Testhooks oder Native-Fehlerbehauptung. |
| P-S14 | Capturemutationen entfernen ein Pflichtfeld und Array und verändern Komponente, Output, Source, Methode, Zeitwert, Kontext, Summe/Mittelwert, NULL, Evidenz und Caller. Originaltextmutationen prüfen beide vollständigen Grammatikformen. Jede Änderung muss durch das unabhängige Orakel abgewiesen werden. |

### P8. Geplante native Quelle, Gegenprüfung und endliche Grenzen

Beide Szenarien bilden den freigegebenen nativen Umfang. Vor Runtime sind die
aktuelle veröffentlichte beziehungsweise lokal installierte Windows-/SQL-/SSIS-
Umgebung, Zugangsbindung, Version, Bitness, Rechte und Compatibility Level
konkret zu prüfen. Jeder Versuch wird vor Effekten gezählt. Es werden
keine bestehenden fremden Labfixtures, alten Runs oder entfernten Quellen
restauriert. Die konkret freigegebene Analyze-Testkonstellation darf
nur eigene eindeutig gebundene Pakete und eigene isolierte Logging-/Framework-
Datenbanken auf geeigneter vorhandener Umgebung verwenden. Neue Infrastruktur,
Installation, Imagebeschaffung, globale Rechte- oder Loggingänderungen sind
nicht Teil des Vorschlags.

| Szenario | Neue eigene Quelle und verlangte unabhängige Gegenprobe |
|---|---|
| P-N01 | Ein neuer einfacher Data Flow mit Quelle, Transformation und Ziel erzeugt PipelineComponentTime für mindestens ProcessInput und PrimeOutput. Paketbytes, tatsächliche Komponentennamen/-klassen, Source-IDs, SDK-Callbacks und native Originalzeilen bleiben gebunden. Ein ausgeführter Geschwistertask ohne Phasenlogging prüft ausschließlich das Fehlen gemeldeter Phasen, keine erfundene 0. |
| P-N02 | Ein neues Paket mit wiederholtem und parallel ausgeführtem gleichnamigem Data Flow bei getrennten GUIDs und mehreren Ausgängen prüft Kontext-/Komponenten-/Outputtrennung. Unzuordenbare Berichte bleiben korrekt sichtbar; positive Gruppen brauchen tatsächlich belegte eindeutige Berichtskontexte. |

Die Referenz liest die endgültig gespeicherten Originaltexte unabhängig vom
Produktdecoder und verifiziert alle sechs Payloadwerte. Sie prüft IDs, Namen,
Einheit und die berichteten Zahlen, aber behauptet keine unabhängig gemessene
herstellerinterne Methodendauer. Kontext und Aggregate werden aus den
unveränderten Originalereignissen unabhängig berechnet. SDK-/Paketdaten dienen
der kontrollierten Source-/Namens-/Klassenbindung; Authoringnummern werden
nicht als Runtimekennungen vorausgesetzt. Zusätzliche oder ungebundene Tupel
dürfen nicht allein aufgrund passender Summen bestehen.

Freigegeben sind höchstens drei Arrange-/Runtimeversuche innerhalb einer
neuen gesonderten Umsetzungswelle, insgesamt höchstens zwei tatsächliche
Paketausführungen und insgesamt höchstens acht native Consumeraufrufe.
Auch ein fehlgeschlagener Consumeraufruf verbraucht einen dieser acht Plätze;
ein Arrangefehler vor dem ersten Consumer verbraucht nur den Runtimeversuch.
Es gibt keine zusätzliche ungezählte Wiederholung einer Konstellation.
Die acht vorgesehenen Konstellationen sind P-N01 RAW nur Phasen, TABLE nur die beiden neuen Mengen, CONSOLE mit
allen drei Opt-ins, NONE mit Phasen, Messages-off mit Phasen und Phasen-off bei
Task-/RowFlow-Opt-in sowie P-N02 RAW mit allen drei Opt-ins und TABLE mit einem
gezielt vor dem Kontextende gekappten N+1-Präfix. Die neue Phase-off-Probe
gegen die neue Quelle prüft die hinzugefügte Option und ist keine Wiederholung
alter Paketläufe. Bereits bestandene unveränderte Einzelbelege werden nach
aktueller Quellen-/Abhängigkeitsbindung weiterverwendet.

Die native Positivabnahme verlangt beide Profilalternativen, gespeicherte
PARSED-Kandidaten, mindestens einen belegten Berichtskontext je Alternative,
positive korrekt getrennte Gruppen, alle 42 neuen Felder, physische Schemas,
N+1, JSON-Parität und Outputmodi. Eine native explizite 0 darf nur bei tatsächlich
gespeicherter Nullmeldung behauptet werden; der garantierte 0-Fall bleibt
synthetisch. Fehlende Kandidaten, nicht passende Formate oder ausschließlich
unzuordenbare Berichte ergeben keine bestandene Positivabnahme.

Ein natives Format außerhalb PCT_EN_1 oder eine nicht erfüllbare Kontextannahme
führt zu erhaltener Nichtqualifikation und konkreter menschlicher
Vertragsentscheidung. Es gibt keine automatische Alias-/Präfixergänzung,
Namensheuristik, Guardlockerung, Paketwiederholung oder Budgetrücksetzung.
Ein fehlgeschlagener Versuch bleibt auch bei späteren Teilerfolgen erhalten.
Originalevidenz wird privat behalten; Runtimeidentitäten, Logs oder Zugangsdaten
werden nicht in Repositoryartefakte übernommen.

Vor Mutation werden eigene Creation-Intents und eindeutige Nonces gespeichert;
Datenbank-ID, create_date, OwnerSID und Marker binden Schreib- und Cleanupziele.
Fehlanlage oder Identitätsabweichung bleibt Recovery statt Präfixlöschung.
Caller, Quellzeilen und Datenbankinventar sind vor und nach der Prüfung zu
vergleichen. Eigene Testdatenbanken/-objekte werden auch auf Fehlerpfaden
identitätsgebunden bereinigt; Cleanupfehler schließen Erfolg aus. Fremde
Ressourcen und historische policyblockierte Löschungen bleiben unangetastet.

### P9. Freigabe-, Integrations- und Quellenvertrag

Der direkte Benutzer hat den geprüften P1–P9-Vertrag einschließlich seiner
Profil-/Kontextgrenzen und des endlichen Abnahmeumfangs konkret freigegeben.
Die abgeschlossene Entwurfswelle bleibt mit einem Vertragsreview, Native0 und
CI0 erhalten. Die Umsetzung hat ein eigenes endliches Budget: ein Autor,
derselbe unabhängige Reviewer für höchstens drei begründete Prüfungen
(Produkt-/Vertragsdelta, Adapter-/Orakeldelta vor Runtime und Ergebnis-/
Lieferdelta), höchstens drei synthetische Versuche, die nativen Grenzen aus P8
und höchstens vier CI-Qualifikations-Heads einschließlich Pflicht-Mainlauf.
Unveränderte erfolgreiche Nachweise werden nach aktueller Bindungsprüfung
weiterverwendet. Kosten und Kontingente bleiben UNKNOWN. Ausführung und
Qualifikation werden erst nach tatsächlichem Ergebnis dokumentiert;
bis dahin bleiben die betroffenen Nachweise NOT_EXECUTED.

Die Lieferung muss Produktversion, Installer, betroffene Inventare,
Guide, Referenz, kanonischen Plan und Status gemeinsam aktualisieren. Erst
erfolgreiche betroffene Tests nach der kanonischen CI-Strategie, exakte
Head-Checks, normaler MatchHead-Merge, Treeidentität, Main-Folgeprüfung,
Synchronisierung und eigenes Cleanup schließen diesen Slice. Kein Admin,
Bypass oder AutoMerge ist vorgesehen. Historische erfolgreiche Abnahmen und
geschlossene Budgets bleiben erhalten. SSIS-001 bleibt auch danach insgesamt
PARTIAL_PRODUCT_FUNCTION; zusätzliche Phasenprofile, Katalogabnahmen und
WI-0009 GATE-0001 bleiben getrennt offen.

Die am 18. Oktober 2026 gelesenen öffentlichen Primärquellen sind
[Microsoft: SSIS Logging, Abschnitt PipelineComponentTime](https://learn.microsoft.com/en-us/sql/integration-services/performance/integration-services-ssis-logging?view=sql-server-ver17#use-the-pipelinecomponenttime-event)
und [Microsoft: Data Flow Task, Sample Messages](https://learn.microsoft.com/en-us/sql/integration-services/control-flow/data-flow-task?view=sql-server-ver17#sample-messages-from-a-data-flow-task).
Sie beschreiben berichtete Millisekunden und zeigen die hier eng ausgewählten
Textformen. Die zweite Quelle bezeichnet in ihrer Übersicht einen Schritt
als ProcessOutput, während ihre Beispiele PrimeOutput verwenden. Dieser
Entwurf folgt ausschließlich den genauen Beispielen und führt keinen Alias ein.
Die übergeordnete Herstellerliste weiterer Phasen ist keine Vorlage für
unbelegte zusätzliche Textdecoder. Die hier festgelegten API-, Zahlen-,
Kapazitäts-, Kontext- und Statusregeln sind Projektentscheidungen; die
Herstellerbeispiele ersetzen keine native Formatzulassung oder Eigenmessung.


## Freigegebene native Legacy-Komponentenzeitberichte ohne numerische IDs vom 18. Oktober 2026

**Status:** B1–B7 wurde vom Benutzer ausdrücklich zur Implementierung,
begrenzten Folgeabnahme und regulären PR-Lieferung freigegeben. Die Ergänzung
ändert P1–P9 ausschließlich an den nachfolgenden ausdrücklich beschriebenen
Ereignis-, Payload- und Gruppengrenzen. Nachweise werden erst nach tatsächlicher
Ausführung als bestanden ausgewiesen. Die ursprünglichen Freigabe- und
Fehlhistorien bleiben erhalten.

### B1. Tatsächliche neue Vertragsgrenze

Die begrenzte neue native Abnahme erzeugte ein eigenes Paket mit Erfolg und
33 gespeicherten Providerzeilen. Darin sind 15 Meldungen unter dem exakten
Ereignisnamen User:PipelineComponentTime und keine unter PipelineComponentTime.
Zwei Texte berichten ProcessInput, einer PrimeOutput; zwölf betreffen bisher
nicht zugelassene Validate-/PreExecute-/PostExecute-Methoden. Die Originaltexte
berichten Komponenten- und Outputnamen, aber keine numerischen Komponenten-
oder Outputkennungen. Ein Outputtext verwendet ComponentName.Outputs[OutputName].
Die drei für PCT_EN_2 vorgesehenen ProcessInput-/PrimeOutput-Berichte liegen
in ihrer beobachteten EXECUTE-Source-Klammer. Diese Aussage wird nicht auf
die übrigen Methodenberichte verallgemeinert. Es handelt sich um eine
Quellenbeobachtung und noch keine Analyzer-Consumerqualifikation.

Der bisherige exakte Ereignisvertrag lässt diese Zeilen nicht als Kandidaten
zu. Sein unabhängiges Positivgate stoppte deshalb vor dem ersten Consumeraufruf
und vor dem zweiten Paketszenario. Drei Arrange-/Runtimeversuche sind verbraucht;
die ersten zwei scheiterten beim eigenen Paketaufbau vor Execute an einem
doppelten Geschwisternamen beziehungsweise einem nicht vorhandenen SDK-Typ.
Das dritte Paket wurde tatsächlich ausgeführt. Alle drei Versuche bleiben
FAILED_NOT_QUALIFIED. Die eigenen Datenbanken wurden identitätsgebunden entfernt,
Cleanupfehler waren 0 und das Datenbankinventar ist wiederhergestellt.
Die neun ursprünglichen Providerfelder stimmen vor und nach der Aufnahme
überein. Originalevidenz und SDK-/Paketbindungen bleiben privat.

Diese Meldungsformen sind keine Ungenauigkeit, die durch Normalisierung,
ID-Raten oder ein liberaleres Gate behoben werden dürfte. B2–B7 legen die
zusätzlich erforderliche fachliche Entscheidung konkret vor.

### B2. Genau ein zusätzliches Ereignis- und Textprofil

PipelineComponentTime bleibt ordinal ausschließlich PCT_EN_1 zugeordnet.
Zusätzlich würde ausschließlich das ordinal exakte User:PipelineComponentTime
als Kandidat für PCT_EN_2 zugelassen. Es gibt keinen allgemeinen User:-Alias,
kein Präfixtrimmen und keine Änderung des gespeicherten Ereignisnamens.
OnInformation, andere Ereignisse, weitere Sprachen und Methoden werden nicht
aus Textähnlichkeit zugelassen. Die beiden vollständigen PCT_EN_2-Formen lauten:

```text
The {ComponentName} spent {ReportedDurationMs} milliseconds in ProcessInput.
The {ComponentName} spent {ReportedDurationMs} milliseconds in PrimeOutput filling buffers on {ComponentName}.Outputs[{OutputName}].
```

ComponentName wird in der PrimeOutput-Form ordinal identisch wiederholt.
Namen bleiben ungetrimmt, einschließlich Case und Endleerzeichen, mit
1 bis 4000 UTF-16-Codeeinheiten. Beide Namensfelder dürfen weder doppelte
Anführungszeichen noch CR, LF, TAB, NUL oder eckige Klammern enthalten.
ComponentName darf zusätzlich weder die vollständige Zeichenfolge
` spent ` noch `.Outputs[` enthalten. Die Trenner sind dadurch eindeutig;
es gibt kein Unescape oder mehrdeutiges Rückwärtsraten. Ein Satzpunkt und
alle festen Leerzeichen sind obligatorisch, nachfolgender Text unzulässig.
Der Zahlenvertrag bleibt ASCII-kanonisches bigint von 0 bis zum Maximum.

Für dieses zusätzliche Ereignis ist der erkannte Profilanfang exakt `The `.
Ohne diesen Anfang gilt UNSUPPORTED_FORMAT mit ParserId NULL. Mit erkanntem
Anfang gilt ParserId=PCT_EN_2 und bei Form-/Namens-/Zahlensyntaxabweichung
MALFORMED_PAYLOAD, bei formal gültiger Zahl außerhalb bigint
NUMERIC_OUT_OF_RANGE. Fehlender Text und der bestehende DATALENGTH-Guard haben
weiter Vorrang. Validate, PreExecute und PostExecute werden als Kandidaten
mit MALFORMED_PAYLOAD sichtbar, ohne Teilpayload oder Methodenzeitgruppe.

### B3. Fehlende numerische Kennungen bleiben NULL

Nur für ein erfolgreiches PCT_EN_2 werden ComponentName, PhaseName und
ReportedDurationMs sowie bei PrimeOutput OutputName übernommen. ComponentId
und OutputId bleiben NULL, weil sie nicht berichtet wurden. ProcessInput
behält auch OutputName NULL. PARSED bedeutet die vollständig zugelassene
profilabhängige Projektion und keinen Nachweis numerischer Identität.

SDK-Authoringnummern, RowFlow-PathIds, Reihenfolgen, Hashes oder künstliche
Ersatznummern werden weder als native IDs eingesetzt noch aus anderen
Ereignissen hinzugefügt. Der vollständige gespeicherte Text bleibt über den
bisherigen Timelineexport verfügbar. Die 18 Ereignisfelder ändern ihren
Typ und ihre Nullbarkeit nicht.

### B4. Benannte Berichtsgruppen statt erfundener Komponentenidentität

Die bisherigen PCT_EN_1-Gruppen bleiben nach den nativen numerischen IDs aus
P4 gebunden. PCT_EN_2-Gruppen würden ausschließlich ASSIGNED-Berichte nach
ExecutionId, SourceId, beiden Kontext-Log-IDs, internem ParserId, ordinalem
ComponentName, PhaseName und ordinalem OutputName zusammenfassen.
ProcessInput hat einen echten NULL-Outputnamen-Schlüssel. Es gibt kein
Zusammenführen mit PCT_EN_1 oder über Sources, Kontexte, Methoden oder
verschiedene berichtete Namen hinweg.

Die Gruppierung belegt nur übereinstimmende berichtete Labels innerhalb eines
Source-Kontextes, keine eindeutige Runtimekomponente oder Vollständigkeit der
Komponentenliste. Gleiche Labels dürfen deshalb nicht als technische Identität
oder Hinweis auf dieselbe Komponente außerhalb dieses Berichtsschlüssels gelten.
Der Produktdecoder liest hierfür keine Paketdatei oder SDK-Metadaten.
Die spätere Fixtureabnahme bindet Labels an die eigenen kontrollierten
Komponenten und Klassen, ohne diese Fixturebindung auf beliebige Quellen
zu verallgemeinern.

Die 24 Gruppenfelder bleiben erhalten. Ausschließlich ComponentId an Position 7
ändert sich physisch von int NOT NULL zu int NULL; bei PCT_EN_1 bleibt sein
Wert obligatorisch, bei PCT_EN_2 sind ComponentId und OutputId NULL.
Für letzteren Zweig sind ComponentName und bei PrimeOutput OutputName die
berichteten Gruppenschlüssel; ihre Konfliktbits sind dort 0. Das beweist keine
globale Namenseindeutigkeit. SourceName-Konflikte bleiben wie bisher sichtbar.
Die bestehende Ordinalsortierung bleibt erhalten; bei den zusätzlichen
NULL-ComponentId-/NULL-OutputId-Schlüsseln folgen ComponentName und OutputName
jeweils binär aufsteigend als eindeutige Sortierergänzung, NULL zuerst.

Summe, Min/Max, exakt auf sechs Stellen kaufmännisch gerundeter Mittelwert,
EventCount, Evidenz-IDs, beobachtete Meldungszeiten und Coveragewerte behalten
P4–P6. Identische gespeicherte Texte mit verschiedenen Log-IDs bleiben Beiträge.
Es entstehen weiterhin keine Methodenintervalle, CPU-, exklusive oder
Komponenten-/Task-/Paketgesamtzeiten. Erwartet fehlende IDs lösen allein keine
zusätzliche Partialität aus; abgelehnte Kandidaten und andere Grenzen tun dies
weiterhin. Weitere API-Parameter, Felder oder Console-Grids entstehen nicht.
SchemaVersion4 und ComponentPhaseCatalogVersion1 sind noch nicht ausgeliefert
und würden diesen konkret erweiterten ersten Liefervertrag bezeichnen.

### B5. Status- und Integritätsgrenzen bleiben bestehen

Die Quellenzeile 7 zählt ausschließlich zugelassene Ereignisnamen und behält
den bestehenden C+G-/Detailvertrag. Der ursprüngliche v1-Puffer, doppelte IDs,
N+1-Sentinel, Messages-off, Prior-v1-Zulassung, atomare Deadlineübernahme,
Fehlerisolation und das erste native Fehlerpaar bleiben unverändert.
ContextStatus folgt P4, unabhängig von optionalen numerischen Payload-IDs.
Ein PCT_EN_2 ohne SourceId oder eindeutigen zeitlich einschließenden Kontext
bleibt sichtbar und trägt zu keiner Gruppe bei. Es gibt keinen Namen- oder
Nachbar-Source-Fallback für die Kontextzuordnung.

### B6. Konkrete begrenzte Folgeabnahme

Alle folgenden Prüfungen sind geplant und NOT_EXECUTED. Der erfolgreiche
synthetische Restumfang einschließlich fünf klar getrennt ausgewiesener
extrahierter Stufen bleibt gebunden erhalten. Die erste Fehlerhistorie 8632
und der ursprüngliche Mittelwert 3.666666 bleiben erhalten; der korrigierte
P-S04-Wert 3.666667 und die restlichen Abschnitte bestanden im dritten
synthetischen Versuch. P-S14 an positiven nativen Consumercaptures ist
NOT_EXECUTED. Bereits abgeschlossene unveränderte Abschnitte werden
nicht neu als lokale Welle gestartet.

Die neue synthetische Deltaprüfung umfasst beide PCT_EN_2-Formen, genau beide
Ereigniszuordnungen, Methoden-/Präfix-/Trenner-/Zahlenablehnungen, NULL-IDs,
physische ComponentId-Nullbarkeit, binäre Namen mit Endspaces und Konflikten,
gemischte EN1-/EN2-Gruppen ohne Querverknüpfung sowie Feld-/Arrayentfernung und
Identitäts-/Zeit-/Summen-/NULL-Mutationen. PCT_EN_1-Parser und unveränderte
historische Provider-/Task-/RowFlow-Abnahmen werden nicht wiederholt.

Die erhaltenen ursprünglichen P-N01-Providerzeilen würden unverändert aus einem
einmal gelesenen und gehashten Puffer in eine neue eigene isolierte Datenbank
restauriert. Es gibt keine erneute P-N01-Paketausführung und keine Änderung
der neun gespeicherten Felder oder ihrer Ereignisnamen. Geplant sind seine
sechs bislang sämtlich NOT_EXECUTED-Consumer aus P8. Danach ist höchstens
eine erstmalige tatsächliche P-N02-Paketausführung für den bislang fehlenden
Mehrfach-/Parallelkontext und dessen zwei Consumer vorgesehen.

Die gesonderte Ergänzungswelle ist auf zwei synthetische und zwei Arrange-/
Runtimeversuche, insgesamt eine tatsächliche P-N02-Paketausführung und acht
Consumeraufrufe einschließlich Fehlversuchen begrenzt. Ein gescheiterter
Paketlauf wird nicht erneut ausgeführt. Die acht Label-/Mode-/Cap-/Options-
Tupel aus P8 bleiben fest; P-N02-Prefixcap kommt aus einer tatsächlich
PARSED+ASSIGNED-Originalmeldung und schneidet ihr belegtes Kontextende ab.
Die Referenz prüft alle 42 Felder unabhängig, inklusive fehlender IDs und
aller neuen Namensschlüssel, plus TABLE-/JSON-Parität, physische Facetten,
RAW11/13/15, CONSOLE1, NONE0, Originaltexte und Caller-/Quell-/Inventarklammern.
Zwei zusätzliche begründete Prüfungen desselben Reviewers sind vorgeschlagen:
Ergänzungs-/Adapterdelta vor Ausführung und Ergebnis-/Lieferdelta danach.

Die bisherigen Budgets bleiben geschlossen und unverändert; insbesondere
ist kein vierter Versuch der alten nativen oder synthetischen Welle abgeleitet.
Das bisher ungenutzte CI-Budget bleibt bis zur fachlichen Qualifikation
zurückgestellt und wird nicht zurückgesetzt oder verdoppelt. Es gibt keine
Setup-, Lab-, VM-, Installations- oder Imagewelle. Datenbanken bleiben eigene
ID-/create_date-/OwnerSID-/Nonce-/Marker-gebundene Objekte mit Cleanup auch auf
Fehlerpfaden. Ein Cleanupfehler verhindert Erfolg. Neue native Formate oder
fehlende Positivquellen führen erneut zu erhaltener Nichtqualifikation und
konkreter Entscheidung; freie Restplätze erlauben keinen blinden Replay.

### B7. Menschliche Freigabe und Liefergate

Die konkrete menschliche Freigabe umfasst B1–B7 und den begrenzten Umfang aus
B6. PCT_EN_2 wird ergänzt und mit den erhaltenen P-N01-Originaldaten sowie
höchstens einem erstmaligen P-N02-Paketlauf geprüft. Der unabhängige Review
ersetzt weder die tatsächliche Abnahme noch exakte Head-CI, regulären Merge,
Treeidentität und Main-Synchronisierung. Bis zur Qualifikation bleiben
Worktree und Originalevidenz erhalten. SSIS-001 bleibt PARTIAL_PRODUCT_FUNCTION
und WI-0009 GATE-0001 offen.

### Nachweisgrenze der freigegebenen Komponentenzeit-Ergänzung

Die [kanonische begrenzte Abnahme](SSIS_Package_and_Execution_Analysis_Plan.md#legacy-komponentenphasenzeiten-begrenzte-abnahme-vom-18-oktober-2026)
trennt sechs wiederverwendete Originaldaten-Consumer von genau zwei neuen
P-N02-Consumern. Alle 42 zusätzlichen Felder werden unabhängig geprüft;
berichtete Namensgruppen sind weiterhin keine technische Komponentenidentität.
Die alte Nichtqualifikation mit Provider-Schreibfehlern und der erhaltene
Offline-Zielmengenfehler werden nicht überschrieben. Die neue EN1-NUL-
Regression bleibt bis exakter Head-CI NOT_EXECUTED. Der Nachweis ist keine
allgemeine Methoden-, Sprach-, Rollen- oder weitere Enginequalifikation.
