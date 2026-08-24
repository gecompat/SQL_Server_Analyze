# SSIS-001 Phase 0 – öffentlicher Vertrag

Status: Vertragsphase abgeschlossen, noch keine öffentliche T-SQL-Procedure.

## Öffentliche Procedures und Resultsets

| Procedure | Resultsetreihenfolge | Schemaversion |
|---|---|---|
| `USP_SsisPackageAnalysis` | `moduleStatus`, `package`, `executables`, `dataFlowComponents`, `connections`, `parameters`, `expressions`, `lineage`, `findings`, `sourceStatus`, `warnings` | `1` |
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
2. Expressions werden nur als direkte Literal-, Variablen- und
   Parameterreferenzen aufgelöst. Verkettung, Funktionen, Typkonvertierung und
   bedingte Ausdrücke bleiben sichtbar als `EXPRESSION_NOT_EVALUATED`.
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

## Quellenprojektionen

- DTSX: Paketkopf, Executables, Precedence Constraints, Event Handler,
  Connection Managers, Parameter-/Variablendefinitionen, Pipelinekomponenten,
  Ein-/Ausgaben, Spaltenmetadaten und Expressions. Script-/Assembly-Binärdaten
  sowie sensitive Werte werden nicht gelesen oder ausgegeben.
- Legacy Log: ausschließlich die dokumentierten `sysssislog`-Spalten der
  explizit benannten Tabelle und Execution ID.
- SSISDB: katalogisierte Execution-, Executable-, Message-, Parameter-, Phase-
  und Row-Flow-Views; keine Projektbinärstreams und keine Mutation.

Die Implementierung beginnt erst mit Phase 1. Dieser Vertrag erlaubt keine
Behauptung, dass SSIS-001 bereits als Produktfunktion verfügbar ist.
