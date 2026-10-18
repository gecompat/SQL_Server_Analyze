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
