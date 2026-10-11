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
