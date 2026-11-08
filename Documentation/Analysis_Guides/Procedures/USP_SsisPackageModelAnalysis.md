# [monitor].[USP_SsisPackageModelAnalysis]

**Bereich:** SSIS<br>
**Zweck:** Validiert ein vom Caller übergebenes neutrales SSIS-Paketmodell und zeigt seine Struktur, Herkunft und Evidenzgrenzen.<br>
**Beobachtungsart:** Statische importierte Producerbehauptungen<br>
**Kostenklasse:** LOW_MEDIUM; Eingangsgröße, Objektzahl und Beziehungen bestimmen den Aufwand.

## Entscheidungsfrage und Einsatz

Die Procedure prüft ein JSON-Modell nach dem
[Abgrenzungs- und Austauschvertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md).
Der Import liest weder DTSX noch Dateien, SSISDB oder Paket-SQL. Die optionale
SQL-Metadatenprüfung liest ausschließlich ausdrücklich zugeordnete lokale Kataloge.
SQL CLR und eine Toolbelt-Installation werden auf dem Analyze-Server nicht benötigt.
Die vorhandene direkte XML-Inventur bleibt über `USP_SsisPackageAnalysis` verfügbar.

Die neue API gehört zum aktuellen Quellstand. Das bestehende Produkt-ZIP 1.1.2
enthält sie noch nicht. Der [kanonische SSIS-Quellinstaller](../../../Code/Install/Install_SSIS_Analysis.sql)
bindet sie gemeinsam mit ihren nativen Hilfsobjekten ein.

## Nicht beantwortete Fragen

Ein formal gültiges Modell beweist weder Paketerfolg noch Datenqualität oder
richtige Ableitung durch den angegebenen Producer. Producerangaben bleiben ohne kontrollierte lokale Übergabe `UNVERIFIED`.
Ein Caller kann sich nicht durch ein Trust-Flag im JSON selbst qualifizieren.
Die optionale Laufzeitkorrelation verlangt einen kontrollierten Capture.
Expressionauswertung und eine transitive Lineageberechnung gehören nicht zum Import.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisPackageModelAnalysis] @Hilfe = 1;

-- @PackageModelJson und optional @PackageBytes stammen aus dem Caller.
EXEC [monitor].[USP_SsisPackageModelAnalysis]
      @PackageModelJson = @PackageModelJson
    , @PackageBytes = @PackageBytes
    , @MaxZeilen = 200
    , @ResultSetArt = 'CONSOLE';
```

`@PackageBytes` ist optional. Der Importer vergleicht bei Übergabe SHA-256 und
Länge der Originalbytes mit den deklarierten Paketwerten. Ein neu serialisierter
SQL-`xml`-Wert ist dafür ungeeignet. Bytes und Modell werden nicht ausgeführt.

## Parameter und Eingabeformen

Die folgenden 32 Verträge unterscheiden den flachen Einzelmodellimport und den exklusiven Ausführungsscope. Die Modi haben eigene JSON- und Kombinationsregeln. Ausgelassene Argumente verwenden den bezeichneten Default; Unicode-JSON wird als nvarchar(max)-Variable oder T-SQL-Literal mit N-Präfix übergeben. Ein Dateipfad ist keine JSON-Eingabe. Die Größenmessung erfolgt mit DATALENGTH in SQL-Bytes, nicht als UTF-8-Dateilänge. Typkonvertierungen gelten vor Eintritt in die Procedure. OUTPUT-Werte werden nur mit einer passenden Variable und OUTPUT am Aufruf empfangen. Hilfe setzt @Json=NULL und erhält die vier Status-/Fehler-OUTPUTs.

### @PackageModelJson

**Datentyp:** `nvarchar(max)`. Default NULL. Im flachen Standardmodus erforderlich: genau ein JSON-Objekt mit den durch die SQL-Feldregelmatrix vollständig festgelegten Schlüsseln und Typen: contract="ssis-package-model", version="1.0.0", identityProfile="document-order-v1"; producer={id="toolbelt.ssis-model", version (String <=32), sourceCommit (40 Hexzeichen), buildSha256 (64 Hexzeichen)}; source={kind="DTSX_BYTES", packageSha256 (64 Hexzeichen), byteLength (1–16.777.216), packageFormatVersion (NULL oder nichtnegative Zahl), xmlProfile=2012/01|2014/01|UNKNOWN}; profiles={format,components,lineage} (Strings bis 32 Zeichen); coverage (genau 8 Objekte); nodes (1–20.000 Objekte); edges (höchstens 50.000 Objekte); diagnostics (höchstens 1.000 Objekte). Node-Objekte tragen id (bis 128), kind, nullable parentId/name (bis 128/256) und kindgebundenes attributes-Objekt; Edge-Objekte tragen id/kind/scopeId, nullable fromId/toId, resolution/evidence, nullable mappingRole/ruleId. Der Schemaabschnitt definiert außerdem alle Pflichtfelder je Rolle und verbietet fremde Schlüssel, doppelte Objektschlüssel und falsche JSON-Typen. Höchstgröße DATALENGTH 16.777.216 SQL-Bytes (nvarchar, UTF-16); Tiefe maximal 32, Parser-Token maximal 1.000.000 und gemeinsames kooperatives Zeitbudget. Diese SQL-Bytegrenze ist keine UTF-8-Dateigrößengrenze. Im Scope-Modus muss der Parameter NULL bleiben; dort liegen Modelle in @ProjectModelsJson. Kein Paketcode wird ausgeführt. Die acht coverage.feature-Werte sind inventory (Objektinventar), controlFlow (Kontrollfluss), pipelineGraph (Datenflussgraph), columnMetadata (Spaltenmetadaten), directColumnMapping (direkte Spaltenzuordnung), valueLineage (Wertabhängigkeit), rowLineage (Zeilenabhängigkeit), expressionReferences (Ausdrucksreferenzen). coverage.status: COMPLETE (vollständig geliefert), PARTIAL (teilweise), UNSUPPORTED (nicht unterstützt), NOT_REQUESTED (nicht angefordert). coverage.reasonCode: NULL (kein Grund) oder PROFILE_LIMIT (Profilgrenze), UNKNOWN_COMPONENT (unbekannte Komponente), ENCRYPTED_CONTENT (verschlüsselter Inhalt), EXPRESSION_UNRESOLVED (unaufgelöster Ausdruck), MISSING_CONTEXT (fehlender Kontext), UNSUPPORTED_PACKAGE_FORMAT (nicht unterstütztes Paketformat), SCOPE_NOT_REQUESTED (Scope nicht angefordert). diagnostics.code: UNKNOWN_COMPONENT (unbekannte Komponente), ENCRYPTED_CONTENT (verschlüsselt), EXPRESSION_UNRESOLVED (Ausdruck unaufgelöst), MISSING_CONTEXT (Kontext fehlt), PARTIAL_LINEAGE (unvollständige Beziehung), PROFILE_LIMIT (Profilgrenze), UNSUPPORTED_PACKAGE_FORMAT (nicht unterstütztes Format). node.kind: PACKAGE (Paket), EXECUTABLE (Task/Container), COMPONENT (Pipeline-Komponente), PORT (Port), COLUMN (Spalte), VARIABLE (Variable), PARAMETER (Parameter), CONNECTION (Verbindungsmanager), EXPRESSION (Ausdruck). edge.kind: CONTROL_FLOW (Kontrollflusskante), PIPELINE_PATH (direkter Pipelinepfad), COLUMN_MAP (Spaltenzuordnung), VALUE_DEPENDENCY (Wertabhängigkeit), ROW_DEPENDENCY (Zeilenabhängigkeit), EXPRESSION_REFERENCE (Ausdrucksreferenz). resolution: RESOLVED (aufgelöst), UNRESOLVED (unaufgelöst), UNSUPPORTED (nicht unterstützt); evidence: DECLARED (deklariert), DERIVED (vom Producer abgeleitet); mappingRole: NULL (keine Rolle), DATA_TRANSFER (Datentransfer), METADATA_REFERENCE (Metadatenreferenz). PORT.direction: NULL (unbelegt), INPUT (Eingang), OUTPUT (Ausgang); PORT.portRole: NULL (unbelegt), REGULAR (regulär), ERROR (Fehler), NO_MATCH (kein Treffer), DEFAULT (Standard-/Fallbackpfad), UNKNOWN (unbekannt). COLUMN.columnRole: DATA (Datenspalte), EXTERNAL_METADATA (externe Metadatenspalte). source.xmlProfile: 2012/01 und 2014/01 (gelieferte XML-Profilkennungen), UNKNOWN (unbekannt); keine Engineversionsqualifikation. Die exakten kindabhängigen Attribute, ID-/Versionssyntax und strukturellen Regeln stehen im mitgelieferten Austauschschema Metadata/Quality/SSIS_Exchange_V1.schema.json; ein vollständiges synthetisches Modell steht in Metadata/Quality/SSIS_Exchange_V1.example.json. Es wird ein vollständiger Producerexport als JSON-Text übergeben, keine Dateipfadangabe. Pflichtfelder mit zulässigem NULL müssen als explizite JSON-null-Eigenschaften vorhanden sein; ausgelassene Pflichtfelder sind ungültig.

### @PackageBytes

**Datentyp:** `varbinary(max)`. Default NULL. Optionale exakte Originalpaketbytes zum unabhängigen SHA-256- und Längenvergleich mit source.packageSha256/byteLength; neu serialisiertes SQL-xml ist ungeeignet. Höchstens 16.777.216 Bytes, gemessen unmittelbar am varbinary-Inhalt. Zusammen mit @LocalHandoverId erforderlich, wenn lokales Producervertrauen angefordert wird. Im Scope-Modus muss NULL bleiben. Bytes werden nicht interpretiert oder ausgeführt. Als varbinary(max)-Variable oder 0x-Hexliteral übergeben; NULL deaktiviert den unabhängigen Bytevergleich, leere 0x-Bytes passen nicht zur geforderten positiven Quelllänge.

### @MaxZeilen

**Datentyp:** `int`. Default 1000. Nichtnegative Obergrenze pro ausgegebener Detailgruppe, angewendet nach vollständiger Validierung und Korrelation; kürzt nicht die Eingabeprüfung. NULL oder 0 bedeutet unbegrenzt (im Scope-Helper bis int-Maximum); negative Werte sind im flachen Modus ungültig, Scope-Helper verwirft Werte mit resultierender Grenze <1. Positiver Bereich: 1 bis 2147483647; keine Gesamtgrenze aller Gruppen.

### @MaxDurationSeconds

**Datentyp:** `int`. Default 30 Sekunden. Erlaubt 1–60 einschließlich; NULL und Werte außerhalb ungültig. Kooperatives gemeinsames Zeitbudget der SQL-Validierung, optionalen Quellen-/Scope-Auswertung und Diagnose. Es ist keine Clienttimeout- oder harte Unterbrechungsgarantie.

### @LockTimeoutMs

**Datentyp:** `int`; einzelner skalarer SQL-int-Wert in Millisekunden. **Default:** `0`; ausgelassen ergibt `0`. NULL oder Werte außerhalb 0–60.000 sind ungültig; Leertext kann vor Eintritt durch implizite SQL-Konvertierung zu `0` werden. Der SQL-Wert `0` bedeutet `NOWAIT`, positive Werte erlauben begrenztes Warten und `-1` wäre unbegrenzt, ist hier aber unzulässig. Im flachen Einzelmodellpfad wird der Wert validiert und `SET LOCK_TIMEOUT` in einem dynamischen `sp_executesql`-Batch ausgeführt; nach dessen Rückkehr begrenzt die Einstellung die anschließenden direkten Prozeduranweisungen nicht. Im Scope-Modus wird der Wert an `InternalSsisExecutionScopes` weitergegeben. Der Helper validiert den Bereich und führt `SET LOCK_TIMEOUT` ebenfalls dynamisch aus; diese Einstellung begrenzt seine anschließenden direkten Anweisungen nicht.

### @ResultSetArt

**Datentyp:** `varchar(16)`. Default 'CONSOLE'. CONSOLE rendert im flachen Modus die Modulübersicht, im Scope-Modus die Bindungsübersicht; RAW liefert die aktivierten benannten Resultsets; TABLE schreibt ausgewählte aktivierte Gruppen in lokale Caller-Temp-Tabellen; NONE unterdrückt fachliche Resultsets. JSON ist keine Ausgabeart; verwenden Sie dafür @JsonErzeugen. Flat normalisiert mit UPPER und entfernt äußere U+0020-Leerzeichen; Scope verwendet nur UPPER, ohne explizites Trim. Führende Leerzeichen werden im Scope nicht entfernt; nachgestellte U+0020-Leerzeichen können aufgrund des SQL-Auffüllvergleichs gleichwertig sein. Verwenden Sie die vier Codes ohne Rand-Leerzeichen. NULL, Leerwert und unbekannte Codes sind ungültig.

### @ResultTablesJson

**Datentyp:** `nvarchar(max)`. Default NULL. Nur bei ResultSetArt=TABLE zulässig und erforderlich: nichtleeres JSON-Objekt aus aktivierten Resultsetnamen auf lokale Temp-Tabellennamen, etwa {"moduleStatus":"#Seed"}. Jede Zuordnung hat einen eindeutigen Resultsetnamen und ein eindeutiges Ziel; beliebige Teilmengen der in diesem Modus aktivierten Namen sind zulässig, aber kein leeres Objekt. Ziele müssen vorhandene leere lokale #Temp-Tabellen (keine ##, keine #Monitor*-Namen, höchstens 116 Zeichen) mit genau einer Seed-Spalte sein. Unbekannte/nicht aktivierte Namen, doppelte Ziele, JSON-Null/Leerwerte und ungültige Ziele werden vor fachlichen Zugriffen abgewiesen. Für CONSOLE/RAW/NONE muss der Parameter NULL sein. Keine eigene Eingabegrößengrenze im Empfänger gefunden; nicht mit den 16-MiB-Grenzen anderer JSON-Parameter gleichsetzen. Flacher Grundbestand: moduleStatus (Modulstatus/Zähler), sourceBinding (Paketbindung/Vertrauen), nodes (Modellobjekte), edges (gerichtete Beziehungen), coverage (Featureabdeckung), findings (Profilbefunde), sourceStatus (Quellenstatus), warnings (Warnungen). Mit IncludePackageViews=1: packageOverview (Paketübersicht), executables (Tasks/Container), dataFlows (Datenflussscopes), components (Pipeline-Komponenten), columnRelations (direkte Spaltenbeziehungen). Mit IncludeObjectRules=1: objectFindings (objektbezogene statische Befunde). Mit IncludeSqlMetadata=1: sqlMetadata (explizit gebundene lokale Katalogmetadaten). Mit IncludeExecutionCorrelation=1: runtimeBinding (Capturebindung), executionCorrelation (zugeordnete Laufzeitbeobachtungen); zusätzlich bei IncludeIterationCorrelation=1: executionObjectSummary (beobachtete Objektsummen), executionCoverage (Iterations-/Loggingabdeckung). Im Scope-Modus ersetzt dieser Bestand alle flachen Gruppen: scopeBinding (Scope-/Capturebindung), packageScopes (Paketmodelle), packageInvocations (Aufrufinstanzen), scopeObservations (Statistik-/Ereignisbelege), handlerActivity (Handlerbelege), scopeObjectSummary (Objektsummen), scopeCoverage (Scope-/Quellenabdeckung). Mit IncludePipelineCorrelation=1 zusätzlich: pipelineInstances (Datenflussinstanzen), componentPhases (Komponentenphasen), pathTransfers (Pfadtransfers), pipelineCoverage (Pipelineabdeckung). Mit IncludePipelineDiagnostics=1 zusätzlich: componentPhaseSummary (Phasensummen), pathTransferSummary (Transfersummen), pipelineFindings (versionierte Beobachtungshinweise), pipelineDiagnosticCoverage (Diagnoseabdeckung). Alle Schlüssel sind exakt und case-sensitive. Zielnamenduplikate und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft. Das JSON enthält Stringwerte, etwa N'{"nodes":"#ModelNodes"}' im flachen Modus oder N'{"scopeBinding":"#ScopeBinding"}' im Scope-Modus.

### @JsonErzeugen

**Datentyp:** `bit`. Default 0. 0 erzeugt kein JSON-Dokument; @Json ist zuvor auf NULL initialisiert. 1 erzeugt das JSON-Ausgabeobjekt, das über gebundenes @Json OUTPUT zurückkommt. NULL ist im regulären flachen und Scope-Modus ungültig; andere Bitwerte sind nicht darstellbar. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Json

**Datentyp:** `nvarchar(max) OUTPUT`. Default NULL OUTPUT. Als OUTPUT-Parameter mit lokaler nvarchar(max)-Variablen zu binden. Beim Eintritt wird er stets auf NULL gesetzt; bei @JsonErzeugen=1 enthält er die tatsächlichen Arrays und Metadaten, sonst bleibt er NULL. Flat-JSON: meta.schemaVersion=1, meta.statusCode, meta.isPartial; stets moduleStatus, sourceBinding, nodes, edges, coverage, findings, sourceStatus, warnings; per Opt-in meta.packageViewsSchemaVersion/objectRulesSchemaVersion/sqlMetadataSchemaVersion/executionCorrelationSchemaVersion/iterationCorrelationSchemaVersion jeweils mit packageOverview/executables/dataFlows/components/columnRelations, objectFindings, sqlMetadata, runtimeBinding+executionCorrelation beziehungsweise executionObjectSummary+executionCoverage. Scope-JSON: meta.schemaVersion=1, meta.executionScopesSchemaVersion=1, meta.isPartial=true; stets scopeBinding, packageScopes, packageInvocations, scopeObservations, handlerActivity, scopeObjectSummary, scopeCoverage; Pipelineopt-in ergänzt meta.pipelineCorrelationSchemaVersion=1 und pipelineInstances/componentPhases/pathTransfers/pipelineCoverage; Diagnose ergänzt meta.pipelineDiagnosticsSchemaVersion=1 und componentPhaseSummary/pathTransferSummary/pipelineFindings/pipelineDiagnosticCoverage. Alle Arrayelemente enthalten die tatsächlichen Tabellenspalten einschließlich NULL-Werten; Nur die im jeweiligen Modus begrenzten Detailgruppen werden gemäß @MaxZeilen gekürzt; die flachen Status-, Bindungs- und Coveragegruppen behalten ihren eigenen unverkleinerten Umfang. Bei @Hilfe bleibt Json NULL. Nicht als Eingabe-JSON verwenden. meta.statusCode entspricht im flachen JSON genau @StatusCodeOut und verwendet dessen hier vollständig aufgeführte zehn flache Codes mit denselben Bedeutungen. Scope-JSON besitzt kein meta.statusCode; lesen Sie dort scopeBinding und den Status-OUTPUT.

### @PrintMeldungen

**Datentyp:** `bit`. Default 1. Flat-Modus prüft NULL als ungültig, verwendet den Wert danach aber nicht; 0 und 1 haben daher dieselbe Wirkung und steuern die PRINT-Ausgabe nicht. Im Scope-Modus wird der Parameter nicht an den Helper übergeben und ist wirkungslos, auch bei NULL. @Hilfe=1 druckt seine Hilfetexte unabhängig von diesem Schalter. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Hilfe

**Datentyp:** `bit`. Default 0. 1 druckt den statischen Hilfetext und kehrt vor Datenvalidierung, Katalog-/Extended-Property-Zugriff und Scope-Delegation zurück; keine Runtime oder Eingabedaten erforderlich. @Json wird vorher auf NULL gesetzt. Andere OUTPUT-Parameter werden im Hilfezweig nicht beschrieben. 0 führt den normalen Pfad aus; NULL verhält sich wegen IF @Hilfe=1 als nicht gesetzt und läuft in die normale Verarbeitung statt als Parameterfehler abgewiesen zu werden. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @StatusCodeOut

**Datentyp:** `varchar(40) OUTPUT`. Default NULL OUTPUT. Mit einer varchar(40)-Variable und OUTPUT am Aufruf binden; der Eingangswert steuert keine Analyse. Im flachen Modus sind die zehn Ergebniswerte: AVAILABLE_LIMITED (Modell im implementierten begrenzten Umfang verarbeitet), INVALID_PARAMETER (ungültige Steuerwerte oder Kombination), EXCHANGE_INVALID (ungültige Modellstruktur/-typen oder nicht gesondert klassifizierter nativer Validierungsfehler), EXCHANGE_VERSION_UNSUPPORTED (Vertrags-, Versions- oder Identitätsprofilkennung nicht unterstützt), EXCHANGE_LIMIT_EXCEEDED (Größen-, Mengen-, Tiefen- oder Besitzertiefengrenze überschritten), EXCHANGE_REFERENCE_INVALID (ungültige Objekt-/Kanten-/Besitzerreferenz), EXCHANGE_PROFILE_UNSUPPORTED (nicht unterstütztes Formatprofil), EXCHANGE_SOURCE_MISMATCH (Originalbytes passen nicht zu deklariertem Paketdigest oder Länge), EXCHANGE_HANDOVER_INVALID (lokaler Producerbeleg fehlt, ist abgelaufen oder passt nicht), EXCHANGE_TIME_BUDGET_EXHAUSTED (kooperatives Zeitbudget an einer Prüfstelle erschöpft). Der Scope-Modus verwendet stattdessen SCOPE_CAPTURE_BOUND (Scope-Capture und Paketsatz sind gebunden; Ergebnis bleibt partiell), SCOPE_BINDING_UNPROVEN (Bindung/Scopeverarbeitung nicht belegt; Ursachen stehen in Fehler- und Bindungsfeldern) oder INVALID_PARAMETER (ungültige Scope-Steuerwerte/Kombination). Bei Hilfe bleibt der vorgebundene Wert unverändert. Eine vorzeitige ungefangene Ausnahme kann die Ergebniszuweisung umgehen.

### @IsPartialOut

**Datentyp:** `bit OUTPUT`. Default NULL OUTPUT. Mit einer bit-Variable und OUTPUT binden; signalisiert Partialität des Ergebnisses. Der Scope-Helper setzt immer 1. Im Hilfezweig unverändert; bei normalem Lauf nach Modus befüllt. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @ErrorNumberOut

**Datentyp:** `int OUTPUT`. Default NULL OUTPUT. Mit einer int-Variable und OUTPUT binden; Fehlernummer der kontrolliert erfassten Analyse-/Bindungsantwort, falls vorhanden. Scope-Modus befüllt denselben Wert aus seinem Helper. Im Hilfezweig unverändert. SQL-THROW-Abbrüche können den normalen Abschluss und damit diese Ergebniszuweisung umgehen.

### @ErrorMessageOut

**Datentyp:** `nvarchar(2048) OUTPUT`. Default NULL OUTPUT. Mit einer nvarchar(2048)-Variable und OUTPUT binden; kontrollierte Fehlermeldung/-ursache, falls vorhanden. Im Scope-Modus Helper-Ausgabe; bei Hilfe unverändert. Ein SQL-THROW-Abbruch kann vor der normalen Zuweisung enden. nvarchar(2048) umfasst höchstens 2048 UTF-16-Codeeinheiten; OUTPUT ist auch am Aufruf nötig.

### @IncludePackageViews

**Datentyp:** `bit`. Default 0. 0 behält die acht Grundgruppen; 1 ergänzt packageOverview, executables, dataFlows, components und columnRelations in RAW/JSON sowie deren zulässige TABLE-Ziele. Alle fünf zeigen gelieferte Modellbeziehungen; kein Laufzeiturteil. NULL ist im flachen Modus ungültig; im Scope-Modus muss der Schalter effektiv 0 sein (NULL wird durch COALESCE wie 1 behandelt und damit als unzulässige Kombination abgewiesen). Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @IncludeObjectRules

**Datentyp:** `bit`. Default 0. 0 liefert keine objektbezogenen Hinweise; 1 ergänzt objectFindings aus festen Regeln und konkreten Knoten-/Kantenbelegen. Ausschließlich statische Hinweise, keine Laufzeiturteile. NULL ist im flachen Modus ungültig; im Scope-Modus muss der Schalter effektiv 0 sein (NULL wird als 1 behandelt und ist dort unzulässig). Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @LocalHandoverId

**Datentyp:** `uniqueidentifier`. Default NULL. Optionale UUID für den lokal gespeicherten qualifizierten Producerbeleg SSIS_HANDOVER_<UUID in Kleinschreibung> auf genau dieser Procedure. Erfordert zugleich @PackageBytes; Beleg bindet exakte UTF-16-JSON-Bytes, Paketdigest/-länge, Buildhash und Source-Commit, issuedUtc darf nicht nach Analysebeginn liegen, expiresUtc muss nach Analysebeginn liegen und höchstens 24 Stunden nach issuedUtc liegen; es gibt keine Mindestgültigkeitsdauer. Ohne ID bleibt ProducerTrust UNVERIFIED; ID ist kein Caller-JSON-Trustflag. Im Scope-Modus muss NULL sein; dort gilt ausschließlich @ScopeHandoverId.

### @IncludeSqlMetadata

**Datentyp:** `bit`. Default 0. 0 lässt sqlMetadata aus; dann muss @SqlMetadataBindingsJson NULL sein. 1 validiert explizite paketgebundene lokale SQL-Spaltenzuordnungen und ergänzt sqlMetadata. Benötigt zugehöriges JSON; optional nur im flachen Modus, nicht mit Scope-Modus kombinierbar. NULL im flachen Modus ungültig; im Scope-Modus muss 0 sein (NULL wird als 1 behandelt und abgewiesen). Keine Paket-SQL-Ausführung oder Typkonvertierungsfreigabe. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @SqlMetadataBindingsJson

**Datentyp:** `nvarchar(max)`. Default NULL. Nur mit @IncludeSqlMetadata=1: JSON-Objekt contract="ssis-sql-metadata-bindings", version="1.0.0", packageSha256 passend zum Modell und bindings-Array mit 1–1.000 Einträgen. Jedes flache Element besitzt genau bindingId, nodeId, databaseName, schemaName, objectName, columnName, keySetId: bindingId eindeutige ASCII-Kennung bis 64 Zeichen [A-Za-z0-9_.:-]; nodeId vorhandener COLUMN; databaseName ausdrücklich lokale Datenbank; Schema/Objekt/Spalte nichtleere SQL-Bezeichner bis 128 UTF-16-Codeeinheiten; keySetId null oder ASCII-Kennung, wobei ein Satz ein Objekt und jede SQL-Spalte höchstens einmal bezeichnet. Maximal DATALENGTH 16.777.216 SQL-Bytes (nvarchar UTF-16; keine UTF-8-Dateigröße). Ohne Opt-in muss NULL sein; im Scope-Modus NULL.

### @IncludeExecutionCorrelation

**Datentyp:** `bit`. Default 0. 0 verlangt im flachen Modus @ExecutionId, @ExecutionSnapshotJson und @RuntimeHandoverId alle NULL; 1 aktiviert Laufzeitkorrelation und verlangt positive @ExecutionId, Snapshot und Runtime-Handover-ID sowie verifiziertes Modellvertrauen und Paketbytes/LocalHandover. Ergänzt runtimeBinding und executionCorrelation. NULL ungültig. Im Scope-Modus muss 0 sein; dessen Korrelationspfad nutzt @IncludeExecutionScopes. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @ExecutionId

**Datentyp:** `bigint`. Default NULL. Positive SSISDB Execution-ID (>0), byte-/wertgleich im gebundenen Capture. Erforderlich bei @IncludeExecutionCorrelation=1 oder @IncludeExecutionScopes=1; bei flacher Laufzeitkorrelation sonst NULL. NULL und Werte <1 werden im aktivierten Korrelationsmodus abgewiesen. Bereich durch bigint begrenzt. Als einzelne Ganzzahl von 1 bis 9223372036854775807 übergeben, keine Liste und kein Datenbankpfad.

### @ExecutionSnapshotJson

**Datentyp:** `nvarchar(max)`. Default NULL. Nur bei @IncludeExecutionCorrelation=1: JSON-Objekt ssis-execution-snapshot mit version 1.0.0/method SSISDB_CURRENT_PROJECT_ROOT_SCOPE_V1 oder bei Iterationskorrelation 1.1.0/SSISDB_CURRENT_PROJECT_ITERATION_SCOPE_V1, identityProfile document-order-v1, Modellhash und Paketdigest, identities-Vertrag ssis-object-identities mit passender Version/PackageSha256 sowie execution-Bindungen (executionId, catalogDatabaseGuid, sourceBindingSha256, projectId, projectLsn, packageFileName, Zeit-/Statusfelder) und observations-Array. Bei 1.1.0 muss die Iterationsklassifikation im identities-Array gebunden sein. Alle Objektschlüssel müssen eindeutig sein; unbekannte Annotationen sind im Capturetransport zulässig, bekannte Bindungen werden streng geprüft. Maximal 16 MiB DATALENGTH in SQL-Bytes, Tiefe 16 und 1.048.576 JSON-Tokens. Hash bindet exakten UTF-16-Inhalt; nicht neu serialisieren. Ohne Opt-in NULL.

### @RuntimeHandoverId

**Datentyp:** `uniqueidentifier`. Default NULL. Bei @IncludeExecutionCorrelation=1 erforderlich: UUID des separat berechtigten und zeitlich gültigen Extended-Property-Belegs SSIS_RUNTIME_<UUID in Kleinschreibung>. Beleg contract ssis-local-runtime-handover 1.0.0 bindet SHA-256 des exakten ExecutionSnapshotJson und issued/expires (höchstens 24 Stunden); ersetzt weder @LocalHandoverId noch verifiziertes Modellvertrauen. Bei ausgeschalteter Korrelation und im Scope-Modus NULL.

### @IncludeIterationCorrelation

**Datentyp:** `bit`. Default 0. 0 lässt executionObjectSummary/executionCoverage weg; 1 erfordert zugleich @IncludeExecutionCorrelation=1 sowie den daran gebundenen Capture 1.1.0 mit SSISDB_CURRENT_PROJECT_ITERATION_SCOPE_V1 und ergänzt diese zwei Gruppen. Nur bereits vom Toolbelt gelieferte iterationContainer-Rollen werden verwendet; Analyze leitet sie nicht neu ab. NULL ungültig; im Scope-Modus muss 0 sein. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @IncludeExecutionScopes

**Datentyp:** `bit`. Default 0. 0 verwendet den flachen Einzelmodellpfad. 1 delegiert exklusiv an InternalSsisExecutionScopes und verlangt @ProjectModelsJson, @ScopeSnapshotJson, @ScopeHandoverId und positive @ExecutionId. Dann müssen PackageModelJson/PackageBytes, LocalHandoverId, ExecutionSnapshotJson, RuntimeHandoverId, SqlMetadataBindingsJson sowie PackageViews/ObjectRules/SqlMetadata/ExecutionCorrelation/IterationCorrelation NULL/0 sein; IncludePipelineCorrelation muss nicht-NULL sein. Scope-Ergebnisse sind stets partiell. NULL im flachen Modus ungültig. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @ProjectModelsJson

**Datentyp:** `nvarchar(max)`. Default NULL. Nur bei @IncludeExecutionScopes=1 erforderlich: JSON-Objekt contract ssis-project-model-set, version 1.0.0, rootPackageKey und packages-Array mit 1–16 Einträgen. Jedes Paketobjekt liefert packageKey (eindeutige alphanumerische Kennung bis 16 Zeichen), entryName (exakter, eindeutiger Archivdateiname ohne /, \ oder :, 6–260 Zeichen), model (vollständiges ssis-package-model 1.0.0) und identities (ssis-object-identities 1.2.0 mit packageSha256 passend zum Modell sowie objects-Array). Jedes identities.objects-Element enthält nodeId, nullable parentId, nodeKind PACKAGE/EXECUTABLE, nullable dtsId/packagePath, scopeKind PACKAGE/CALL/LOOP/HANDLER/EXECUTABLE, steps (Array mit höchstens 32 Objekten; jedes Objekt genau text als nichtleerer String mit DATALENGTH 2–8.000 SQL-Bytes und counter als JSON-Boolean (`true` oder `false`)), profileStatus SUPPORTED/UNQUALIFIED, eventName und callTarget als nullable Werte; Handler-Events sind OnPreExecute/OnPostExecute/OnError. Identitätsanzahl muss der Zahl der PACKAGE/EXECUTABLE-Knoten entsprechen und jede ID/Parentbeziehung passt exakt zum eingebetteten Modell. Bei Pipelineopt-in zusätzlich pipelineIdentities je Paket (ssis-pipeline-identities 1.0.0, identityProfile=document-order-v1, identischer packageSha256, pipelines-Array). Jedes Pipelineobjekt enthält nodeId/profileStatus und components/paths-Arrays; Komponenten binden nodeId/name/nativeRefId/profileStatus an vorhandene Component-Knoten, Pfade binden edgeId/fromPortId/toPortId/sourceComponentId/destinationComponentId/nativeRefId/name/identificationString/profileStatus an exakte Pipelinekanten/Ports. Anzahl und Scopes müssen dem Modell entsprechen. RootPackageKey muss eines der eindeutigen packageKey bezeichnen. Maximal 16 MiB DATALENGTH SQL-Bytes; gemeinsam mit Capture Tiefe <=32 und 50.000 Beobachtungen/Ereignisse.

### @ScopeSnapshotJson

**Datentyp:** `nvarchar(max)`. Default NULL. Nur bei @IncludeExecutionScopes=1 erforderlich: Captureobjekt contract ssis-execution-scopes, version 1.0.0 und method SSISDB_CURRENT_PROJECT_SCOPES_V1; bei Pipelinekorrelation stattdessen 1.1.0 und SSISDB_CURRENT_PROJECT_PIPELINES_V1. Bindet positive execution.executionId, packageFileName exakt an root entryName, projectId/projectLsn >0, catalogDatabaseGuid, sourceBindingSha256, archiveSha256 sowie modelSetSha256=SHA-256 der exakten @ProjectModelsJson-Bytes. observations ist ein Array mit executionId/statisticsId/executableId, packageName/packagePath/executionPath und nullable executableGuid/startTime/endTime/durationMs/executionResult; events enthält eventMessageId, packageName/packagePath/executionPath, nullable executableGuid/eventName/messageCode/messageTime. IDs müssen positiv sein, Execution-ID stimmt für alle Beobachtungen überein, und Namen/Pfade/GUIDs sowie Zeit-/Ergebnisfelder müssen konvertierbar und innerhalb der Helpergrenzen liegen; gemeinsam höchstens 50.000 Einträge. Bei Pipelineopt-in sind zusätzlich arrays componentPhases (phaseStatsId, packageName, taskName, componentName, phaseName, executionPath, nullable startTime/endTime), pathTransfers (dataStatsId, packageName, taskName, pathIdentificationString, pathName, sourceComponentName, destinationComponentName, executionPath, nullable rowsSent/createdTime) und genau zwei pipelineSources erforderlich. Die Quellenobjekte enthalten source/status/errorNumber; source ist componentPhases oder pathTransfers, status AVAILABLE/AVAILABLE_EMPTY/UNAVAILABLE/DENIED_PERMISSION, errorNumber bei den letzten zwei positiv und sonst NULL. IDs sind positiv; Zähler nichtnegativ; Zeitfelder ISO-konvertierbar. Doppelte Schlüssel werden abgewiesen. Maximal 16 MiB DATALENGTH SQL-Bytes je Dokument, Tiefe 32, gemeinsames Zeitbudget. Übergabe-ID bindet exakte Dokumentbytes.

### @ScopeHandoverId

**Datentyp:** `uniqueidentifier`. Default NULL. Bei @IncludeExecutionScopes=1 erforderliche UUID des lokal auf dieser Procedure registrierten Extended-Property-Belegs SSIS_SCOPE_<UUID in Kleinschreibung>. Beleg contract ssis-local-scope-handover 1.0.0 enthält genau sechs eindeutige Schlüssel einschließlich issuedUtc/expiresUtc, modelSetSha256 und captureSha256; Gültigkeit maximal 24 Stunden und Hashes binden exakt die übergebenen UTF-16-JSON-Dokumente. READCOMMITTEDLOCK verhindert Trust aus uncommittetem Beleg. Bei flachem Modus muss NULL sein.

### @IncludePipelineCorrelation

**Datentyp:** `bit`. Default 0. Nur im Scope-Modus zulässig; 0 behält die sieben Scopegruppen, 1 verlangt Scope-Modus plus Captureversion 1.1.0/Methode SSISDB_CURRENT_PROJECT_PIPELINES_V1 und gebundene pipelineIdentities sowie Komponentenphasen-/Pfadtransferquellen; ergänzt pipelineInstances, componentPhases, pathTransfers und pipelineCoverage. Im flachen Modus muss 0 sein. Scope-Helper akzeptiert keinen NULL-Wert. Schalter ist keine Lineage. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @IncludePipelineDiagnostics

**Datentyp:** `bit`. Default 0. 0 lässt Diagnosegruppen weg. 1 verlangt @IncludeExecutionScopes=1 und @IncludePipelineCorrelation=1; ergänzt componentPhaseSummary, pathTransferSummary, pipelineFindings und pipelineDiagnosticCoverage. NULL ungültig. Im flachen Modus muss exakt 0 sein. Nur Beobachtungsaggregation und versionierte Hinweise, ändert keinen Ausführungsstatus; die Eingaben bleiben auf höchstens 50.000 gebundene Quellzeilen und das gemeinsame Zeitbudget begrenzt. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @PipelinePhaseThresholdMs

**Datentyp:** `bigint`. Default NULL deaktiviert SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED. Ein expliziter nichtnegativer Millisekundenwert aktiviert bei @IncludePipelineDiagnostics=1 die Regel, wenn ein bekanntes einzelnes Komponentenphasenintervall den Wert strikt überschreitet (nicht bei Gleichheit). Negative Werte, NULL-Schalter, fehlendes Diagnoseopt-in oder jeder nicht-NULL-Wert im flachen Modus sind ungültig. Kein CPU- oder kritischer-Pfad-Grenzwert. Der explizite Zahlenbereich ist 0 bis 9223372036854775807 Millisekunden.

Die vollständige JSON-Feldgrammatik liegt im [mitgelieferten Austauschschema](../../../Metadata/Quality/SSIS_Exchange_V1.schema.json); das [synthetische Modell](../../../Metadata/Quality/SSIS_Exchange_V1.example.json) zeigt eine vollständige Eingabeform. Diese Dateien beschreiben den Transport und installieren keine Toolbelt-, CLR- oder LLM-Komponente auf dem Analyze-Server.

## Hilfe ohne Daten- und Runtimeprüfung

Alle vier Aufrufe enden vor Modell-, Capture- und Handoverprüfung. Es wird kein Paket ausgeführt und keine externe Datenquelle gelesen.

```sql
EXEC [monitor].[USP_SsisPackageModelAnalysis] @Hilfe = 1;

DECLARE @helpJson nvarchar(max)=N'vorheriger Wert';
EXEC [monitor].[USP_SsisPackageModelAnalysis] @Hilfe=1, @Json=@helpJson OUTPUT;
SELECT @helpJson AS JsonOutput;

DECLARE @status varchar(40)='caller-value', @partial bit=0, @err int=7, @message nvarchar(2048)=N'caller-value';
EXEC [monitor].[USP_SsisPackageModelAnalysis] @Hilfe=1, @StatusCodeOut=@status OUTPUT, @IsPartialOut=@partial OUTPUT, @ErrorNumberOut=@err OUTPUT, @ErrorMessageOut=@message OUTPUT;
SELECT @status AS StatusCodeOut, @partial AS IsPartialOut, @err AS ErrorNumberOut, @message AS ErrorMessageOut;

EXEC [monitor].[USP_SsisPackageModelAnalysis] @Hilfe=1, @PrintMeldungen=0;
```

## Resultsets und Leserichtung

RAW liefert `moduleStatus`, `sourceBinding`, `nodes`, `edges`, `coverage`,
`findings`, `sourceStatus` und `warnings`, Schemaversion 1. Lesen Sie zuerst
Modulstatus, Paketbindung und Producervertrauen. Prüfen Sie danach Coverage und
`IsInterpretable`, bevor Sie eine Beziehung als auswertbare statische Angabe verwenden.

Mit `@IncludePackageViews=1` ergänzt Version 1.1.0 fünf fachliche Gruppen in
RAW, TABLE und JSON. Ohne Opt-in bleiben die bisherigen acht Gruppen erhalten.
`meta.packageViewsSchemaVersion=1` beschreibt das zusätzliche JSON-Profil.

| Gruppe | Bedeutung |
|---|---|
| `packageOverview` | Enthält Objektzahlen, beobachtete Datenflussscopes, direkte Beziehungen, offene Referenzen und begrenzte Features des vollständigen validierten Modells. |
| `executables` | Zeigt Tasks, Container und Event Handler mit Parent, Besitzertiefe, deklarierter Art und gegebenenfalls deaktiviertem Zustand. |
| `dataFlows` | Zeigt Executable-Scopes mit gelieferten Komponenten oder Datenflusskanten und deren Objektzahlen. Ein leerer, nicht entsprechend belegter Scope wird nicht als vollständig inventarisierter Datenfluss behauptet. |
| `components` | Zeigt Klassenkennung sowie Port- und Spaltenzahlen. Analyze klassifiziert die Komponenten nicht erneut. |
| `columnRelations` | Verbindet gelieferte direkte Spaltenzuordnungen und Wertabhängigkeiten mit den Endpunkten. `FromNodeKind` unterscheidet Spalten, Variablen und Parameter; spaltenbezogene Quellfelder bleiben für andere Arten NULL. Metadatenverweise bleiben durch `MappingRole` von Datentransfers getrennt. |

Die zusätzlichen Gruppen entstehen vor jeder Ausgabekürzung. Ihre Zähler
verwenden deshalb den vollständigen Graphen. `@MaxZeilen` begrenzt jede neue
Detailgruppe auf deren erste Zeilen in Quellreihenfolge; `NodeOrdinal` und
`EdgeOrdinal` behalten ihre ursprüngliche Bedeutung. Fehlende Endpunkte und
Metadaten bleiben NULL. Die Sichten erzeugen weder transitive Lineage noch
eine neue Typkompatibilitätsbewertung. Zulässige numerische Darstellungen wie
`1e2` und `100.0` werden aus der vorhandenen exakten Zahlenvalidierung übernommen
und als 100 dargestellt. Producervertrauen und Featureabdeckung
bleiben für ihre Interpretation maßgeblich.

CONSOLE liefert eine Modulübersicht. TABLE verwendet dieselben acht benannten
Ziele in `@ResultTablesJson`; bei aktivierten Paketsichten kommen deren fünf
Namen hinzu. Der Caller legt die leeren lokalen Temp-Tabellen an.
JSON wird optional über `@JsonErzeugen=1, @Json=@Json OUTPUT` erzeugt. NONE
unterdrückt fachliche Resultsets. Ausgabearten verändern die Validierung nicht.

## Eine Zeile bedeutet

Eine `nodes`-Zeile ist ein paketlokales Objekt aus dem übergebenen Modell.
`AttributesJson` enthält ausschließlich die für dessen Objektart zulässigen
typisierten Felder. Anzeigenamen sind keine Identität. Eine `edges`-Zeile ist
eine gerichtete deklarierte oder abgeleitete Beziehung mit explizitem Scope.
Eine unbekannte Ableitungsregel erhält `IsInterpretable=0`.

`coverage` bewahrt den berichteten Status und ergänzt, ob der Importer das
Profil unterstützt. `sourceBinding` trennt `DECLARED_ONLY` von
`PACKAGE_BYTES_MATCH`. Hashgleichheit authentifiziert das Modell nicht.
Findings des ersten Slices benennen fehlende Abdeckung und unbestätigte
Producerherkunft; sie geben kein Gesundheitsurteil über eine Ausführung ab.

## So lesen

`AVAILABLE_LIMITED` bezeichnet einen erfolgreich validierten Import mit
unbestätigter Producerherkunft. Ein vollständiger Datenbestand bleibt daher
von einer bestätigten betrieblichen Aussage getrennt. Fehlende Informationen,
unbekannte Profile oder Regeln erlauben keine Aussage, dass die betreffende
SSIS-Aktivität oder Abhängigkeit nicht existiert.

## Warum kann das problematisch sein?

Ein ungeprüftes Modell kann plausible, aber falsche Paketstrukturen enthalten.
Strukturprüfung und Paketbytevergleich erkennen keine absichtlich erfundenen
semantischen Ableitungen. Die vollständige Modellherkunft und eine spätere
Ausführungszuordnung benötigen eigenständige Belege.

## Wann ist es kein Problem?

Eine begrenzte Expression- oder Zeilenlineage ist erwartbar, wenn der Producer
diese Semantik noch nicht qualifiziert hat. Direkte Struktur- und
Spaltenzuordnungen können trotzdem unabhängig nutzbar sein. Die Procedure
rekonstruiert keine fehlenden Kanten anhand ähnlicher Namen.

## Beispiele und Gegenbeispiele

```sql
EXEC [monitor].[USP_SsisPackageModelAnalysis]
      @PackageModelJson = @PackageModelJson
    , @IncludePackageViews = 1
    , @MaxZeilen = 200
    , @ResultSetArt = 'RAW';
```

Eine reduzierte Knotenausgabe darf die Komponentenanzahl einer Datenflusssicht
nicht verkleinern. Ein nicht aufgelöster Spaltenbezug erhält keinen erfundenen
Quellnamen. Dieselbe direkte Beziehung wird nicht zu einem zusätzlichen,
abgeleiteten Pfad erweitert.

Ein anderer Anzeigename bei gleicher Objektkennung ändert nicht die
Referenzauflösung. Gleiche Komponentennamen in verschiedenen Datenflüssen
werden über unterschiedliche IDs und Scopes getrennt. Dagegen ist eine
identische DTSID kein ausreichender Nachweis für dieselben Paketdateibytes.

## Leere oder partielle Ausgabe

Ungültiges JSON, unbekannte Felder, doppelte Keys oder Kennungen, falsche
Objektarten, Besitzzyklen und ungültige Beziehungen verwerfen den Import
atomar. `EXCHANGE_SOURCE_MISMATCH` verwirft ein Modell mit abweichenden
Originalbytes. Ein Quellenfehler liefert Status und Warnkontext, aber keine
teilweise bereits validierten Knoten oder Kanten. JSON behält leere Arrays.

`@MaxZeilen` begrenzt nur den Export von Knoten und Kanten. Modulzähler und
Validierung beziehen sich auf den vollständigen Bestand. `RESULT_TRUNCATED`
kennzeichnet die begrenzte Ausgabe. NULL und 0 sind unbegrenzt.

## Eigenlast und Grenzen

Kostenklasse: LOW_MEDIUM. Standardpfad: ein bereits übergebenes JSON-Modell,
ohne Katalog- oder Dateizugriff. Teuerster Pfad: 16 MiB JSON mit 20.000 Knoten
und 50.000 Kanten. Haupttreiber: Tokenisierung, Referenzen und Besitzerhierarchie.
Skalierung: mit der Modellgröße, nicht mit dem Datenbestand einer Quelldatenbank.
Ressourcen: lokale Temp-Tabellen und optionale JSON-Ausgabe.
Begrenzungswirkung: 32 JSON-Ebenen, 128 Besitzebenen, eine Million interne
Tokens und höchstens 1.000 Diagnosen. Sperrwartezeit: 0 bis 60.000 ms.
Locking und Nebenwirkungen: eigene Temp-Objekte sowie ausdrücklich zugeordnete
TABLE-Ziele; keine persistenten Paket- oder Quelländerungen.
Schutzmechanismus: Größen- und Feldprüfung vor Veröffentlichung, 1 bis 60
Sekunden kooperatives Zeitbudget, standardmäßig 30 Sekunden.
Sicherer Einsatz: ein begrenzter, bewusst ausgewählter statischer Import.
Aussagegrenze: keine harte Deadline innerhalb einer laufenden SQL-Anweisung
und keine gemessene Maximalkapazität. Eine Callertransaktion wird nicht übernommen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Entspricht das zugelieferte Modell dem vereinbarten Format und welche
statischen Beziehungen sind innerhalb seiner Abdeckung interpretierbar?

### Technischer Hintergrund

Die Feldprüfungen werden durch `Code/Tools/Build_Ssis_Exchange_Rules.py` aus
der unveränderten Toolbelt-Schemakopie generiert. Der native Importer ergänzt
Objekt-, Scope-, Referenz- und Paketbindungsprüfungen. Er enthält keinen
SSIS-Komponentenparser und keine eigene Lineageableitung.

### Datenkette

Caller-JSON → geschlossene Feldprüfung → Referenzprüfung → optionale
Paketbytebindung → einmal materialisierte Ausgaben. Der externe Toolbelt-Host
ist eine mögliche Zulieferung und keine vom Importer aufgerufene Abhängigkeit.

### Source Select

```sql
SELECT @PackageModelJson AS [CallerPackageModel];
```

Der Parameter bezeichnet die Eingabequelle. Die Procedure gibt das Rohdokument
nicht zusätzlich aus und übernimmt keine darin enthaltenen Befehle.

**Wichtig für die Eigenlast:** Die Quelle ist das bereits übergebene Modell;
es wird kein zusätzlicher Datenbank-, Datei- oder Netzwerkbestand gelesen.

### Zeit- und Scope-Modell

Die Analyse gilt für ein übergebenes Modell und dessen deklarierte Paketrevision.
Sie besitzt kein Laufzeitbeobachtungsfenster. Der Producerbytehash ist weder
eine Berechtigung noch ein Nachweis der Ausführungsrevision.

### Bewertung und Gegenprobe

Vergleichen Sie Originalbytes, Producerbuild und freigegebene Profile unabhängig.
Verwenden Sie für Betriebsbeobachtungen die getrennten SSISDB- oder Legacy-Analyser.
Die gemeinsamen synthetischen Konformitätsfälle prüfen beide Producerhosts
gegen dieselben Objekt- und Kanten-Erwartungen.

### Typische Fehlinterpretation

`PACKAGE_BYTES_MATCH` belegt keine korrekte Modellableitung und
`IsInterpretable=1` keine tatsächlich ausgeführte Datenbewegung.

### Folgeanalyse

Weitere fachliche Regeln können die validierten typisierten Metadaten nutzen,
sofern ihre Feature- und Evidenzvoraussetzungen erfüllt sind. Vertiefte
Parser- und Lineagelogik bleibt im kanonischen Toolbelt-Kern.

## Kontrollierte lokale Übergabe

`@LocalHandoverId` ist optional und benötigt zugleich `@PackageBytes`.
Ohne ID wird kein Übergabebeleg gelesen. Mit ID prüft Analyze die an dieser
Procedure gespeicherte Extended Property `SSIS_HANDOVER_<uuid-in-kleinschreibung>`.
Nur Besitzer, berechtigte DDL-Administratoren oder Principals mit ALTER/CONTROL
auf der Procedure dürfen diese Metadaten schreiben. Diese Principals bilden
zusammen mit dem lokalen Account, Adapter und der qualifizierten .NET-Runtime
die Vertrauenswurzel. Analyze erteilt keine zusätzlichen Berechtigungen.

Der [lokale Zulieferadapter](../../../Code/Tools/Invoke-SsisQualifiedHandover.ps1)
benötigt eine bereits offene Verbindung zur ausdrücklich gewählten Analyze-
Datenbank sowie unabhängig freigegebene SHA-256- und Source-Commit-Werte des
Toolbelt-Exporthosts. Die Freigabewerte dürfen nicht erst aus dem ungeprüften
Kandidaten als eigene Freigabe abgeleitet werden. Der Adapter prüft vorhandenes
ALTER-Recht, liest begrenzte private Snapshots von DLL und Paket, vergleicht den
Buildhash und führt genau diesen Hostsnapshot mit einer eigenen .NET-10-
Runtimekonfiguration aus. Der Snapshotordner besitzt vor dem Schreiben ausschließlich Accountzugriff
(unter Unix Modus 0700); Größenprüfungen begrenzen bereits jeden Kopierschritt.
Auch nach fehlgeschlagenem Prozessstart wird der eigene Ordner bereinigt.
Der Adapter kopiert keine fremden Abhängigkeiten und entfernt
DOTNET-/CoreCLR-Konfigurationsvariablen aus der Kindprozessumgebung.

```powershell
$handover = & ./Code/Tools/Invoke-SsisQualifiedHandover.ps1 `
    -ProducerAssemblyPath $qualifiedProducerAssembly `
    -ExpectedBuildSha256 $approvedBuildSha256 `
    -ExpectedSourceCommit $approvedSourceCommit `
    -PackagePath $packagePath -Connection $openAnalyzeConnection
```

Der Adapter kontrolliert die vom tatsächlichen Host gemeldete Build-/Commit-
Identität. Analyze validiert das Ergebnis und die Paketbytes bereits vor der
Registrierung. Der separat berechtigte Metadatenzugriff speichert ausschließlich
Digests, Länge, Methode und SQL-Server-Zeitstempel; er speichert keine Pakete,
Modelle, Dateipfade, Konten oder Verbindungsdaten. Der Adapter liefert Modell,
Originalbytes und Übergabe-ID an den Caller zurück. Private temporäre Snapshots
werden anschließend entfernt. Es findet keine Paket- oder Paket-SQL-Ausführung
statt; ausgeführt wird ausschließlich der ausdrücklich qualifizierte Exporthost.

Die spätere Analyse vergleicht den SHA-256 über die exakten UTF-16LE-Bytes des
übergebenen JSON-Strings sowie Paketdigest, Byteanzahl, Buildhash und Commit.
Schon eine Neuserialisierung benötigt einen neuen Beleg. `issuedUtc` und
`expiresUtc` begrenzen die Gültigkeit auf die gewählte Dauer von einer bis
höchstens 24 Stunden. Der Beleg ist ein geschlossener lokaler Vertrag
`ssis-local-handover`, Version `1.0.0`, Methode `QUALIFIED_HOST_SNAPSHOT`.
Er ist keine Fernsignatur und kein Nachweis richtiger Parsersemantik.

Nur bei erfolgreicher Gesamtprüfung wird `ProducerTrust=VERIFIED_LOCAL`
ausgegeben und an objektbezogene Hinweise weitergereicht. Diese bleiben
statische importierte Aussagen. Unbekannte, abgelaufene oder widersprüchliche
Belege ergeben `EXCHANGE_HANDOVER_INVALID` und atomar leere fachliche Gruppen.
Ein falscher Paketbytehash wird bereits als `EXCHANGE_SOURCE_MISMATCH` abgewiesen.
Für den Vertrauenszugriff gilt ein fest begrenzter Metadatenzugriff mit
`READCOMMITTEDLOCK` und dem bestehenden Lock-Timeout; ein uncommittierter Beleg
wird nicht über NOLOCK als vertrauenswürdig übernommen.

Der verantwortliche Administrator kann einen Beleg durch Entfernen seiner
Extended Property widerrufen. Abgelaufene Eigenschaften werden ignoriert,
aber nicht automatisch gelöscht. CREATE OR ALTER erhält die Eigenschaften;
ein Drop/Recreate oder ein Datenbankwechsel überträgt ihre Vertrauenswirkung
nicht automatisch. Ein anderes Datenbank- oder Laufzeitziel benötigt seine
separat kontrollierte Übergabe. Der eigenständige Pfad ohne ID und ohne SQL CLR
bleibt verfügbar.

## Objektbezogene Regeln

`@IncludeObjectRules=1` ergänzt `objectFindings` unabhängig von den
Paketsichten. Der Standard behält acht RAW-Gruppen; Regeln allein liefern neun,
Regeln mit Paketsichten vierzehn Gruppen. JSON kennzeichnet den optionalen
Vertrag mit `meta.objectRulesSchemaVersion=1`; TABLE akzeptiert den Gruppennamen
nur bei aktiviertem Flag. CONSOLE bleibt die einzelne Modulstatusausgabe.

| RuleId | Gelieferter Beleg und Aussagegrenze |
|---|---|
| `SSIS_EXECUTABLE_DISABLED` | Ein Executable besitzt ausdrücklich `isDisabled=true`. Eine tatsächliche Ausführung ist damit nicht nachgewiesen. |
| `SSIS_COMPONENT_PROFILE_UNKNOWN` | Eine Producerdiagnose `UNKNOWN_COMPONENT` verweist auf einen vorhandenen Komponentenknoten. Analyze führt keinen eigenen Komponentenkatalog. |
| `SSIS_EDGE_UNRESOLVED` | Eine konkrete Kante besitzt `resolution=UNRESOLVED`. Analyze ergänzt keine Endpunkte. |
| `SSIS_COLUMN_MULTIPLE_DIRECT_SOURCES` | Mehrere unterschiedliche gelieferte, aufgelöste `DATA_TRANSFER`-Quellen zeigen auf dieselbe Spalte im selben Scope. Das ist kein Fehlernachweis. |
| `SSIS_PORT_NO_DECLARED_PATH` | Ein regulärer gerichteter Port besitzt keine passende deklarierte Pipelinekante. Diese Abwesenheitsaussage setzt `COMPLETE` für Inventar und Pipelinegraph sowie das unterstützte Format- und Komponentenprofil voraus. Unaufgelöste oder nicht unterstützte Pipelinepfade sperren die Abwesenheitsregel im betreffenden Scope; Laufzeiterreichbarkeit und Zeilenfluss bleiben unbelegt. |

Alle Hinweise besitzen Severity `INFO` und EvidenceLevel `IMPORTED_STATIC`.
`NodeId`, `EdgeId` und `ScopeNodeId` lokalisieren den Beleg; `PackageSha256`,
`BindingStatus` und `ProducerTrust` erhalten seine Herkunft. Fehlende Namen,
unbekannte Eigenschaften und nicht vorhandene Runtimebelege werden nicht
ersetzt. Die Regeln arbeiten vor der Ausgabekürzung; `@MaxZeilen` begrenzt die
Gruppe anschließend und erzeugt bei Kürzung `RESULT_TRUNCATED`. Ungültige
Modelle liefern auch bei aktiviertem Flag keine Teilbefunde.

## Ausführungskorrelation aus einem kontrollierten Capture

`@IncludeExecutionCorrelation=1` ergänzt `runtimeBinding` und
`executionCorrelation` für eine positive `@ExecutionId`. Korrelation allein
liefert zehn RAW-Gruppen, zusammen mit Paketsichten und Regeln sechzehn.
CONSOLE bleibt eine Modulstatusausgabe. JSON kennzeichnet den Zusatzvertrag
mit `meta.executionCorrelationSchemaVersion=1`; TABLE akzeptiert die zwei
Namen nur bei aktiviertem Flag. Die vier Korrelationseingaben müssen bei
abgeschaltetem Flag leer bleiben. `@MaxZeilen` begrenzt die Ausgabe erst
nach Prüfung und Zuordnung des gesamten Captures.

Der native Importer führt keinen SSISDB-Zugriff aus. Der optionale externe
[Katalogadapter](../../../Code/Tools/Invoke-SsisCatalogHandover.ps1) liest
Ausführung, aktuelle Projektversion, Projektarchiv und sichtbare Statistiken
in einem gebundenen Kanal. Projekt und Ordner bleiben während der begrenzten
Lesetransaktion mit `HOLDLOCK` geschützt. Die Ausführungsrevision muss der
aktuellen Projektrevision entsprechen. Nicht verfügbare alte Versionen werden
nicht durch heutige Pakete ersetzt oder wiederhergestellt. Nur der exakt
benannte ZIP-Eintrag wird im Speicher geöffnet; Pakete werden nicht ausgeführt.

Voraussetzungen sind PowerShell 7/.NET 10, ein unabhängig freigegebener
Toolbelt-Host mit Exportbundle, eine dedizierte offene SSISDB-Quellverbindung
und eine offene Analyze-Zielverbindung mit ALTER-Autorität. Beide Verbindungen
dürfen keine Callertransaktion besitzen oder gleichzeitig anderweitig verwendet
werden. Die Quelle benötigt die dokumentierten Katalog-/`catalog.get_project`-
Rechte. Die Scriptparameter verlangen Buildhash und Source-Commit. Ein optionaler
`SourceReader` ist selbst Teil der qualifizierten Vertrauensgrenze: Er führt den
vorgegebenen Gesamtbatch einmal gegen denselben frisch geprüften Quellkanal aus,
bindet dessen eindeutige `SourceBindingId` und liefert begrenzte Ergebnistabellen.
Er ist kein Importpfad für fertige fremde Captures.

Modell und Identitätssidecar stammen aus einem einzigen Toolbelt-Export.
Nur Toolbelt liest native IDs und vorhandene namespacequalifizierte `refId`-
Pfade. Zwei eigene lokale Extended Properties registrieren Modell und Capture
atomar. Der Adapter liefert `PackageModelJson`, `PackageBytes`, `LocalHandoverId`,
`ExecutionSnapshotJson` und `RuntimeHandoverId`; diese Werte werden gemeinsam
an die Procedure übergeben. Ein Laufzeitbeleg ersetzt den Modellbeleg nicht.

`runtimeBinding` nennt Ausführung, Katalog-GUID, Kanalbindungshash, Projekt-ID/-LSN,
Paketdigest, Capturezeitraum und vollständige Zeilen-/Trefferzahlen.
`RUNTIME_BOUND_CAPTURE` bestätigt diesen importierten Capture zum genannten
Zeitpunkt. Jede Statistikzeile bleibt separat erhalten. Objektzuordnung verlangt
eine im Modell eindeutige native GUID und bytegenaue Gleichheit von importiertem
Modellpaketpfad und Katalogpaketpfad. Zusätzlich muss genau eine Paketwurzel
mit passender GUID, passendem Paketpfad und dem Paketdateinamen der Ausführung
beobachtet sein. Ihr Ausführungspfad muss genau ein oberstes Pfadsegment sein.
Damit qualifiziert ein verschachtelter Paketaufruf keine Wurzel.

Der bisherige Capturevertrag `SSISDB_CURRENT_PROJECT_ROOT_SCOPE_V1` ohne
Iterationsoption erhält beide
Pfadrepräsentationen. SSISDB verwendet beispielsweise `\Package` als
Paketpfad und `\SyntheticRuntimeRoot` als Ausführungspfad derselben Wurzel.
Analyze bindet diese zwei beobachteten Wurzeln zusammen und vergleicht den
unveränderten restlichen Paketpfad innerhalb dieses Scopes exakt mit dem
Ausführungspfad. Eine Pfadsegmentgrenze ist Pflicht; `\PackageSuffix` ist
kein Kind von `\Package`. Modellanzeigenamen bestimmen die Laufzeitwurzel
nicht. Zeichen, Iterationszusätze und Kindpaketsegmente werden weder entfernt
noch normalisiert. Mehrdeutige GUIDs, fehlende Pfade und Abweichungen bleiben
unzugeordnet. Dies ist eine native Laufzeitzuordnungsregel auf bereits
zugelieferten Identitäten, kein DTSX-Parser und keine Lineageableitung.

EvidenceLevel ist `IMPORTED_CATALOG_OBSERVATION`; wegen unbekannter
Loggingabdeckung bleibt die Quelle partiell. Analyze erzeugt keine neue
Lineage. Fehlende, veränderte oder abgelaufene Captures liefern
`RUNTIME_BINDING_UNPROVEN` und leere Korrelationszeilen; das gültige statische
Modell bleibt nutzbar. Capturegrenzen sind 16 MiB, 16 JSON-Ebenen und 50000
Beobachtungen; Archivgrenzen sind 64 MiB/10000 Einträge und 16 MiB je Paket.
Das gemeinsame Importerzeitbudget bleibt wirksam. Der eigenständige statische
Pfad benötigt weder diesen Adapter noch SSISDB, Toolbelt oder SQL CLR.

Der manuelle
[Windows-Quellentest](../../../Code/Tests/Integration/216_SsisCatalogHandover_Native_Contract.ps1)
verwendet einen ausdrücklich eigenen Lab-Run mit bereits bereitgestellter
SSISDB. Sein getrennt kompilierter
[SDK-Fixtureautor](../../../Code/Tests/Fixtures/SSIS_Execution_Correlation/CreateProject.cs)
liefert die erwarteten GUIDs, Paketpfade und Originalbytes unabhängig vom
Toolbelt-Exporter. Der Test prüft einen echten Paketlauf und eine abweichende
spätere Projektrevision. Er entfernt seine eigenen Katalogobjekte und die
temporäre Analyze-Datenbank; der bereitgestellte Lab-Run verbleibt beim
Aufrufer. Private Receipts und Capturedokumente gehören nicht in Git.

## Iterationsgebundene Ausführungskorrelation

`@IncludeIterationCorrelation=1` verlangt zugleich
`@IncludeExecutionCorrelation=1`. Der Katalogadapter wird mit demselben
Schalter aufgerufen. Er verwendet den optionalen Toolbelt-Export
`--iteration-bundle`, den Identitätssidecar 1.1.0 und den Capturevertrag
`ssis-execution-snapshot` 1.1.0 mit
`method=SSISDB_CURRENT_PROJECT_ITERATION_SCOPE_V1`. Ein älterer Host wird
nicht durch einen ungeprüften Ersatzpfad ergänzt. Die Standardoptionen und
der bisherige Capture 1.0.0 bleiben unverändert.

Nur Toolbelt klassifiziert die unterstützten For-/Foreach-Container im
Booleanfeld `iterationContainer`. Analyze verwendet die gelieferten Parent-IDs
und die unveränderten nativen Pfadsegmente. Eine eindeutige native GUID,
derselbe Paketpfad, Paketdateiname, Paketdigest und eine qualifizierte
Ausführungswurzel bleiben Voraussetzung. Zwischen einem bekannten
Schleifensegment und seinem Kind ist zusätzlich ein kanonischer positiver
ASCII-Zähler in eckigen Klammern erlaubt. Der Zähler muss in `bigint` passen;
Vorzeichen, führende Nullen, Leerzeichen, zusätzliche Klammern und Unicodeziffern
qualifizieren keine Zuordnung. Im eigentlichen Objektnamen vorhandene Klammern
bleiben erhalten. Analyze leitet weder Containerrollen noch Lineage neu ab.

Jede Ausführung behält ihre `StatisticsId`, `ExecutableId`, den ursprünglichen
`ExecutionPath`, Zeitangaben und das Ergebnis in `executionCorrelation`.
Eine zusätzliche Zuordnung trägt `EXACT_GUID_AND_ITERATION_PATH`. Mehrere
Beobachtungen dürfen dieselbe `ModelNodeId` besitzen. Kindpaketsegmente und
Ereignishandler erweitern diesen Scope nicht. Mehrdeutige GUIDs und nicht
passende Pfade bleiben unzugeordnet.

Die Option ergänzt zwei RAW-/TABLE-Gruppen und JSON-Arrays. JSON kennzeichnet
sie mit `meta.iterationCorrelationSchemaVersion=1`. Mit Ausführungskorrelation
sind zwölf RAW-Gruppen vorhanden; mit sämtlichen bisherigen Optionen sind es
neunzehn. CONSOLE bleibt eine Statusgruppe, NONE liefert keine fachlichen
Resultsets, JSON bleibt ein OUTPUT-Parameter.

| Gruppe | Bedeutung und Aussagegrenze |
|---|---|
| `executionObjectSummary` | Eine Zeile je importiertem Paket-/Executableobjekt mit beobachteter Instanzzahl, Erfolgs-, Fehler-, Abbruch- und übrigen Ergebnissen sowie bekannten Dauerwerten. `UNASSIGNED_OR_NOT_OBSERVED` beweist keine Nichtausführung. |
| `executionCoverage` | Eine Zeile für den angefragten Capture mit beobachteter Loggingkonfiguration, Capturezustand und vollständigen beobachteten, zugeordneten und unzugeordneten Zeilenzahlen. `CONFIGURATION_OBSERVED` ist kein Vollständigkeitsnachweis; unbekannte Loggingwerte bleiben `UNKNOWN`. |

`InclusiveObservedDurationMs` summiert ausschließlich die bekannten,
nicht negativen Dauern der beobachteten Instanzen desselben Modellobjekts.
Fehlt eine Instanzdauer, bleibt die Summe unbekannt. Die Summe über mehrere
Container und deren Kinder ist keine Paketdauer oder kritische Pfadzeit;
verschachtelte und parallele Laufzeitanteile können sich überlagern.
`IsPartial=1` bleibt für diese importierten Laufzeitbelege erhalten.
Sichtbarkeit, Loggingkonfiguration, Aufbewahrung und der Erfassungszeitpunkt
begrenzen den Befund auch bei einer am Captureende abgeschlossenen Ausführung.
Die Procedure nimmt keine Änderungen an Logging oder Paketkonfiguration vor.

Die Zuordnung und Aggregation verwenden alle validierten Beobachtungen vor
`@MaxZeilen`. Eine Ausgabekürzung verändert die Zählungen in
`executionCoverage` nicht. Die bestehenden Größen- und Zeitgrenzen gelten
weiter. Ohne gültige Capturebindung bleiben die statischen Modellangaben
nutzbar; die Objektzusammenfassung bleibt leer und die Abdeckung nennt
`UNPROVEN`. Der manuelle Windows-Test verwendet eigene synthetische
Katalogobjekte in einer ausdrücklich vorhandenen SSISDB-Umgebung und entfernt
nur diese Consumerobjekte. Er provisioniert oder entfernt keine Labumgebung.
Der Testschalter `-IterationCases` ergänzt die mit dem SDK erzeugte For- und
Foreach-NodeList-Fixture; `-LoggingLevel 1` beziehungsweise `3` wählt Basic
oder Verbose. Nur der Testautor benötigt .NET Framework x64 sowie die
passenden SDK-Assemblies `Microsoft.SqlServer.ManagedDTS.dll` und
`Microsoft.SqlServer.ForEachNodeListEnumerator.dll`. Die native Abnahme dieser
Erweiterung bezieht sich auf Windows SQL2025 und diese synthetischen Pakete;
andere Engines und Enumeratorprofile werden dadurch nicht pauschal qualifiziert.

## Optionale lokale SQL-Metadatenprüfung

`@IncludeSqlMetadata=1` ergänzt `sqlMetadata`. Die Standardausgabe bleibt bei
acht Gruppen; Metadaten allein liefern neun, zusammen mit Paketsichten und
Objektregeln fünfzehn RAW-Gruppen. Mit zusätzlich aktivierter
Ausführungskorrelation sind es siebzehn Gruppen. CONSOLE bleibt eine Statusgruppe. JSON
verwendet `meta.sqlMetadataSchemaVersion=1`; TABLE akzeptiert `sqlMetadata`
nur bei aktiviertem Flag. Ohne Flag muss `@SqlMetadataBindingsJson` leer bleiben.

Der Caller ordnet vorhandene Modellspalten ausdrücklich lokalen SQL-Spalten
zu. Das Dokument besitzt genau `contract="ssis-sql-metadata-bindings"`,
`version="1.0.0"`, den `packageSha256` des aktuellen Modells und `bindings`.
Dieses Array enthält eine bis höchstens 1000 flache Zuordnungen mit jeweils
genau sieben Feldern:

| Feld | Vertrag |
|---|---|
| `bindingId` | Eine eindeutige ASCII-Kennung mit höchstens 64 Zeichen aus Buchstaben, Ziffern und `_.:-`. |
| `nodeId` | Die genaue ID eines vorhandenen `COLUMN`-Knotens dieses Modells. |
| `databaseName` | Der ausdrücklich benannte lokale Datenbankname; es gibt keinen impliziten CURRENT-Scope. |
| `schemaName`, `objectName`, `columnName` | Je ein nicht leerer SQL-Bezeichner mit höchstens 128 UTF-16-Codeeinheiten. |
| `keySetId` | `null` ohne Schlüsselprüfung oder eine ASCII-Kennung wie `bindingId`; derselbe Satz bezeichnet genau ein SQL-Objekt und enthält jede SQL-Spalte höchstens einmal. |

Der Importer validiert den gesamten maximal 16 MiB großen Zuordnungsvertrag
vor dem ersten Katalogzugriff. Er löst keine Connection Strings, Expressions,
Lookupabfragen oder Paket-SQL auf. Nur ausdrücklich benannte sichtbare
Datenbanken werden gelesen. Der Datenbankbezeichner stammt aus dem geprüften
lokalen Katalog und wird mit `QUOTENAME` geschützt; Objekt- und Spaltennamen
bleiben Daten. Vergleich ist ordinal einschließlich Länge. Der Caller benötigt
Zugriff auf die jeweiligen Datenbanken und Sichtbarkeit der betreffenden
Metadaten. EXECUTE allein erweitert diese Rechte nicht.

`sqlMetadata` liefert beobachtete Objekt-/Spalten-IDs, deklarierten SQL-Typ mit
Schema, Längen in Bytes, Präzision, Skala, Collation, Nullable-/Computed-/Identity-
Eigenschaften und Beobachtungszeit. `ModelTypeCode` bleibt der unveränderte
Producerwert. `NullableAgreement` vergleicht nur zwei bekannte Nullablewerte;
fehlende Werte bleiben `UNKNOWN`. `TypeCompatibilityStatus=NOT_QUALIFIED`
erteilt keine Konvertierungs- oder Ladefreigabe. Dadurch entsteht in Analyze
keine zweite SSIS-Typenregelpflege.

`UNIQUE_INDEX_OBSERVED` verlangt einen sichtbaren, aktivierten, nicht
hypothetischen und ungefilterten Unique Index mit genau der ausdrücklich
angegebenen Schlüsselspaltenmenge. Include-Spalten zählen nicht zum Schlüssel.
Ein zusammengesetzter Schlüssel beweist keine Eindeutigkeit einer Teilmenge;
gefilterte und deaktivierte Indizes qualifizieren den Satz nicht. Fehlende
Sichtbarkeit ergibt `SQL_OBJECT_NOT_VISIBLE` beziehungsweise
`SQL_COLUMN_NOT_VISIBLE`, keinen Nachweis einer tatsächlichen Objektabwesenheit.

Die Zuordnung bleibt `CALLER_EXPLICIT`, die Evidenz `LOCAL_CATALOG_METADATA`.
Paketdigest und Producervertrauen werden mitgeführt. Die Katalogbeobachtung
unter NOLOCK bleibt partiell und ist bei gleichzeitiger DDL kein konsistenter
Datenbanksnapshot. Es gibt keine Datenscans, GRANTs, DDL oder Paketabfragen.
Fehler eines Datenbankzugriffs bleiben in dieser Quelle; ungültige Zuordnungen
liefern leere Metadaten und erhalten das gültige statische Modell. Das
gemeinsame Zeitbudget bleibt wirksam. `@MaxZeilen` kürzt erst nach der
Prüfung aller Schlüsselmitglieder und kennzeichnet eine Kürzung.

## Kindpaket- und Ereignishandlerkorrelation

`@IncludeExecutionScopes=1` ist ein eigener, exklusiver Ausgabemodus. Er verlangt
`@ProjectModelsJson`, `@ScopeSnapshotJson`, `@ScopeHandoverId` und `@ExecutionId`;
die bisherigen Modell-, Regel-, Metadaten- und Korrelationsopt-ins werden dabei
nicht kombiniert. Ohne diesen Schalter bleiben die bisherigen Verträge erhalten.
Der SQL-Empfänger verwendet ausschließlich JSON und lokale Herkunftsbelege und
benötigt weder SQL CLR noch eine Toolbelt-Installation.

Der externe Katalogadapter erhält `-IncludeExecutionScopes` und führt einen
gebundenen, lesenden SSISDB-Batch aus. Vorher-/Nachherprüfung, Projekt-LSN,
Katalogdatenbankkennung und Execution-ID sichern den Quellenbezug. Nur die zur
Ausführung unverändert aktuelle Projektversion ist zulässig. Aus diesem Archiv
exportiert genau der freigegebene Toolbelt-Host die erreichbaren Pakete; jeder
Paketdigest, unveränderte Einzelmodelle und Sidecars 1.2.0 gehen in einen
hashgebundenen Paketsatz ein. Eine erneute Projektbereitstellung erlaubt keinen
Import aktueller Bytes als Modell einer historischen Ausführung.

Der lokale Attestor benötigt ALTER-Recht auf die Analyseprocedure. Seine
zeitlich begrenzte Registrierung bindet die exakten UTF-16-JSON-Dokumente.
Diese administrative Autorität, der geprüfte Hostbuild und dessen Runtime sind
die Vertrauenswurzel. Ein JSON-Trustflag oder gewöhnliches EXECUTE genügt nicht.
Der gespeicherte Capture bleibt nach einem Redeployment zeitbezogener Beleg
seiner Aufnahme; er behauptet keine aktuelle Projektversion.

| Ergebnisgruppe | Bedeutung einer Zeile |
|---|---|
| `scopeBinding` | Bindungsstatus, qualifizierte Wurzel und Herkunft dieses Captures. |
| `packageScopes` | Ein erreichbares Paketmodell mit eigener `PackageKey` und Bytehash. |
| `packageInvocations` | Eine eindeutig belegte Paketwurzelstatistik mit Elterninstanz und aufrufender Statistik-ID. |
| `scopeObservations` | Eine unveränderte Statistik- oder Ereignisidentität mit beobachteten Pfaden und optionaler Modellzuordnung. |
| `handlerActivity` | Ein dem Handlerkörper zugeordneter Einzelbeleg mit Handler- und Eigentümerknoten. |
| `scopeObjectSummary` | Beobachtete Statistikanzahlen und inklusive Dauern genau eines paketgebundenen Modellknotens. |
| `scopeCoverage` | Vollständige Quell- und Zuordnungszahlen vor dem Ausgabelimit, Logging-Level und Capturestatus. |

`CONSOLE` liefert eine fachliche Bindungsausgabe, `RAW` sieben typisierte
Resultsets, `TABLE` die ausdrücklich benannten lokalen Seed-Ziele und `NONE`
keine Resultsets. JSON wird ausschließlich über OUTPUT geliefert und enthält
`executionScopesSchemaVersion=1`. `@MaxZeilen` begrenzt jede Ergebnisgruppe erst
nach Validierung und Korrelation. `OutputTruncated` kennzeichnet eine Kürzung;
die Abdeckungszahlen bleiben dabei auf den gesamten Capture bezogen.

Unterstützt sind feste projektlokale Execute Package Tasks desselben Archivs,
Kind- und Enkelpakete sowie `OnPreExecute`, `OnPostExecute` und `OnError`.
Wiederholte, parallele und schleifengebundene Aufrufstellen benötigen exakte
beobachtete Pfade. GUIDs gelten innerhalb ihres Pakets; gleiche GUIDs in zwei
Paketen werden nicht zusammengeführt. Identische mehrdeutige Instanzpfade
bleiben unzugeordnet. Dynamische Ziele, externe Projekte, Datei-/MSDB-Pakete,
rekursive Aufrufe und andere Handlerereignisse sind nicht qualifiziert.

Ein Handlerkörper kann durch propagierte Ereignisse mehrfach denselben Pfad
besitzen. Seine Statistik- und Ereigniszeilen bleiben getrennte Belege.
`TriggerEventMessageId` bleibt unbekannt und `CausalityStatus=UNPROVEN`:
Ereignisname, Zeitnähe und Meldungstext beweisen keinen konkreten Auslöser.
Der Adapter übernimmt keine Meldungstexte oder Parameterwerte. Fehlende
Beobachtungen beweisen keine Nichtausführung. `IsPartial` bleibt wahr; Dauern
werden nicht über Objekte zu einer Paketlaufzeit addiert. Bei unbekannten oder
negativen Einzeldauern bleibt die betreffende Dauersumme unbekannt.

Der Paketsatz ist auf 16 Pakete, acht Aufrufebenen, 1024 Instanzen und zusammen
50000 Statistik-/Ereigniszeilen begrenzt. Archive enthalten höchstens 10000
Einträge, 64 MiB expandierte Paketbytes und 16 MiB je Paket; beide JSON-Dokumente
haben jeweils ein 16-MiB-Limit. Export und Modellvalidierung teilen 60 Sekunden;
der SQL-Consumer verwendet das angegebene kooperative Zeitbudget. Der
Locktimeout wird nach Eintritt in den Consumer geprüft, angewendet und
wiederhergestellt. Sperren vor dem Eintritt in eine SQL-Procedure benötigen
wie bei anderen SQL-Aufrufen einen begrenzten Caller- oder Clienttimeout. Parser,
Komponentenprofile und paketübergreifende Daten-/Parameterlineage werden nicht
in Analyze nachgebaut; solche Lineage ist nicht Bestandteil dieses Modus.

## Optionale Dataflow-Ausführungskorrelation

`@IncludePipelineCorrelation=1` erweitert ausschließlich
`@IncludeExecutionScopes=1`. Der externe Katalogadapter erhält beide Schalter.
Der gebundene Batch liest zusätzlich Komponentenphasen und Pfadtransfers
derselben Ausführung. Der Capture verwendet `ssis-execution-scopes` 1.1.0 und
`SSISDB_CURRENT_PROJECT_PIPELINES_V1`; der Paketsatz ergänzt pro Paket
`ssis-pipeline-identities` 1.0.0. Der Toolbelt-Host liefert diesen Sidecar mit
`--pipeline-bundle` aus seinem bestehenden Modell. Ohne Opt-in bleiben
Capture, Hostaufruf und sieben Scopeausgaben unverändert. Im vorbereiteten
Katalogaufruf werden `-IncludeExecutionScopes -IncludePipelineCorrelation`
zusammen angegeben; der SQL-Aufruf übernimmt anschließend den Paketsatz und
Capture dieser Übergabe mit beiden gleichnamigen SQL-Opt-ins. Die vorherigen
Abschnitte zur lokalen Übergabe beschreiben die Host- und Berechtigungsvorbereitung.

| Zusätzliche Ergebnisgruppe | Bedeutung einer Zeile |
|---|---|
| `pipelineInstances` | Eine bereits gebundene Dataflow-Statistikinstanz mit Paket-, Aufruf- und Modellkennung sowie beobachtetem Ausführungspfad. |
| `componentPhases` | Ein Quellbeleg einer Komponentenphase mit Zeitintervall und optionaler scoped Komponentenzuordnung. |
| `pathTransfers` | Ein Quellbeleg eines Pfadtransfers mit beobachtetem Zeilenzähler und optionaler Zuordnung zur vorhandenen Modellkante. |
| `pipelineCoverage` | Der Status genau einer zusätzlichen Quelle mit vollständigen Quell-, Zuordnungs- und Restzahlen vor dem Ausgabelimit. |

`RAW` liefert in diesem Opt-in elf Resultsets; `CONSOLE` weiterhin eines und
`NONE` keines. `TABLE` akzeptiert die vier zusätzlichen Namen mit denselben
nativen Schemas wie JSON und RAW. JSON ergänzt
`pipelineCorrelationSchemaVersion=1`. Die gemeinsame Grenze von 50000
Quellzeilen umfasst Statistiken, Ereignisse, Phasen und Transfers; die bisherigen
Paket-, Archiv-, Dokument- und Zeitgrenzen gelten weiter.

Zuerst muss der ordinal exakte Ausführungspfad genau eine bereits gebundene
Dataflow-Statistikinstanz bestimmen. Taskname und Komponentenname gelten danach
innerhalb dieses Paketmodells und Dataflows. Phasen erhalten
`SCOPED_EXACT_COMPONENT_NAME`; die Quelle liefert keine Komponenten-GUID.
Ein Pfadtransfer verlangt zusätzlich Identifikationsstring, Pfadname und beide
Komponentennamen sowie passende Ports und Kante aus dem Toolbelt-Sidecar.
Sein Status lautet `SCOPED_EXACT_PATH_REFERENCE`. Mehrdeutige, unbekannte oder
abweichende Referenzen bleiben `UNASSIGNED`; Zeitnähe ersetzt keine Identität.
Die SSISDB-Spalte `package_name` bezeichnet bei beiden zusätzlichen Quellen das
zugehörige Paket, einschließlich eines aufgerufenen Kindpakets. Der Name muss
ordinal und längengleich zum Archiveintrag des bereits gebundenen Paketmodells
passen. Die Paket- und Aufrufkennung stammt weiterhin aus der Statistikinstanz;
ein übereinstimmender Paketname allein begründet keine Zuordnung. Nach einem
frühen Abbruch können Phasen vorliegen, während Executable-Statistiken fehlen.
Die Ausgabe behält diese Phasen unzugeordnet bei, meldet keine Flowinstanz und
kennzeichnet die Abdeckung als partiell.

`ObservedDurationMs` ist das nichtnegative Intervall einer einzelnen Phase.
Unbekannte oder umgekehrte Grenzen ergeben keine Dauer. `RowsSent` bleibt der
unveränderte nichtnegative Zähler genau eines Transfers; unbekannte Werte
bleiben unbekannt. Wiederholte Transfers und verzweigte Pfade werden nicht zu
einer Paketzeilenzahl zusammengezählt. Die Ausgaben behaupten weder CPU-Zeit
noch Wert- oder Zeilenlineage.

Der Status in `scopeBinding` beschreibt weiterhin die grundlegende Paket- und
Ausführungsbindung. Ein ungültiger Pipelinesidecar oder Pipelinecapture führt
zusätzlich zu `PIPELINE_BINDING_UNPROVEN` in beiden Quellenabdeckungen und
leeren Pipelinedetails; eine erfolgreiche Basisbindung überstimmt diesen
Fehlerstatus nicht.

Die Quellen erfordern sichtbare Ausführungsrechte und unterliegen der
SSISDB-Zeilensicherheit. Komponentenphasen benötigen Performance oder Verbose,
Zeilentransfers Verbose. Der Adapter ändert keine produktive Loggingeinstellung.
Leere sichtbare Quellen erhalten `AVAILABLE_EMPTY`; fehlende oder verweigerte
Quellen werden getrennt als `UNAVAILABLE` beziehungsweise `DENIED_PERMISSION`
mit Fehlernummer ausgewiesen. Ein Quellenfehler verwirft keine lesbare
Nachbarquelle. `IsPartial` bleibt wahr: Logginglücken, Rechte und ein laufender
Capture erlauben keinen Schluss auf Nichtausführung oder globale Vollständigkeit.

## Optionale Dataflow-Diagnose

`@IncludePipelineDiagnostics=1` verlangt Scope- und Pipelinekorrelation und
ergänzt vier Ergebnisgruppen. Der Empfänger wertet ausschließlich die bereits
gebundenen Modelle, Komponentenphasen und Pfadtransfers aus. Die bestehende
lokale Übergabe bindet weiterhin Projektversion, Paketbytes und konkrete
Ausführung. Analyze benötigt dafür kein SQL CLR und keinen eigenen Parser.

| Ergebnisgruppe | Bedeutung einer Zeile |
|---|---|
| `componentPhaseSummary` | Beobachtete Intervalle genau einer Komponente, Phase und Dataflowinstanz mit Anzahl, gültiger Intervallsumme, längstem Intervall, Spannweite, Überlappungsflag und Rang innerhalb derselben Phase und Instanz. |
| `pathTransferSummary` | Beobachtete Transfers genau einer Modellkante und Dataflowinstanz mit bekannter Zeilensumme, unbekannten Zählern und der gelieferten Ausgangsrolle. |
| `pipelineFindings` | Ein versionierter Regelhinweis mit Modell-, Aufruf- und Quellenbezug oder ein ausdrücklich quellenbezogener Hinweis auf begrenzte Evidenz. |
| `pipelineDiagnosticCoverage` | Quellenstatus, vollständige Beobachtungs-, Zuordnungs-, Zusammenfassungs- und Unbekanntenzahlen vor der Ausgabekürzung. |

```sql
EXEC [monitor].[USP_SsisPackageModelAnalysis]
      @IncludeExecutionScopes=1, @IncludePipelineCorrelation=1,
      @IncludePipelineDiagnostics=1, @PipelinePhaseThresholdMs=1000,
      @ProjectModelsJson=@Models, @ScopeSnapshotJson=@Capture,
      @ScopeHandoverId=@Handover, @ExecutionId=@Execution,
      @ResultSetArt='RAW';
```

Das Opt-in liefert 15 RAW-Gruppen. TABLE verwendet dieselben benannten Schemas;
JSON ergänzt `pipelineDiagnosticsSchemaVersion=1`. CONSOLE bleibt die einzelne
Bindungsübersicht. Ohne Opt-in bleiben die bisherigen Ausgabegruppen erhalten.
`@MaxZeilen` begrenzt erst die Ausgabe. Alle neuen Abdeckungszeilen melden eine
Kürzung, sobald eine Diagnosegruppe gekürzt wird.

Die Intervallsumme enthält ausschließlich bekannte, nichtnegative Einzelwerte.
`UnknownIntervalCount` zählt fehlende oder umgekehrte Grenzen. Die Spannweite
verwendet die früheste Start- und späteste Endgrenze gültiger Intervalle;
überlappende Intervalle können eine größere Summe als diese Spannweite ergeben.
Die Kennzahlen belegen weder CPU-Zeit noch einen kritischen Pfad. Der Rang
vergleicht die längsten Einzelintervalle derselben Phase innerhalb genau einer
Flowinstanz und behauptet keine Engpassursache.

Transferwerte werden nur innerhalb derselben gebundenen Kante und Instanz
addiert. Fehlende Zähler bleiben unbekannt; eine ausschließlich unbekannte
Gruppe erhält keine Nullsumme. Multicastzweige werden separat ausgewiesen.
Eine Zeilensumme ist keine Paketzeilenzahl und keine Datenqualitätsaussage.

| Regel | Voraussetzung und Aussage |
|---|---|
| `SSIS_PIPELINE_ERROR_OUTPUT_OBSERVED` | Ein positiver Transfer liegt auf einer vom Toolbelt-Modell als `ERROR` gelieferten Ausgangsrolle. |
| `SSIS_PIPELINE_NO_MATCH_OBSERVED` | Ein positiver Transfer liegt auf einer ausdrücklich gelieferten `NO_MATCH`-Rolle. No-Match ist allein kein Paketfehler. |
| `SSIS_PIPELINE_ZERO_OBSERVED_TRANSFER` | Alle tatsächlich beobachteten Zähler dieser Kante sind bekannt und null. Fehlende Transfers erfüllen diese Voraussetzung nicht. |
| `SSIS_PIPELINE_PHASE_THRESHOLD_EXCEEDED` | Ein bekanntes Einzelintervall überschreitet den ausdrücklich gesetzten Grenzwert. |
| `SSIS_PIPELINE_DIAGNOSTIC_EVIDENCE_LIMITED` | Quellen fehlen, Beobachtungen bleiben unzugeordnet, benötigte Werte beziehungsweise Portrollen sind unbekannt oder eine Quellkürzung beziehungsweise ein Diagnosefehler begrenzt die Auswertung. |

`@PipelinePhaseThresholdMs` ist standardmäßig NULL und aktiviert dann keine
Grenzwertregel. Ein expliziter Wert muss nichtnegativ sein und verlangt das
Diagnose-Opt-in. Alle Hinweise besitzen `INFO`; die Regeln verändern keinen
Ausführungsstatus. `SourceName` und `SourceId` referenzieren den ursprünglichen
Capture. Bei `SOURCE_OUTPUT_TRUNCATED` kann die zugehörige Einzelzeile in der
begrenzten Detailausgabe fehlen; die unveränderte Quellenkennung bleibt erhalten.
Quellenabdeckung besitzt ausdrücklich keine erfundene Ereignis-ID.
Ein gültiger Basisbeleg überstimmt keinen Fehler der zusätzlichen Diagnose.

Die Laufzeitkosten folgen der bereits auf 50000 Belege begrenzten Datenmenge.
Fensterfunktionen und Gruppierungen nutzen lokale Temp-Objekte und das gemeinsame
kooperative Zeitbudget. Es entstehen keine zusätzlichen SSISDB-Quellabfragen.
Unbekannte Portrollen werden nicht aus Namen oder Komponentenklassen erraten;
deren Interpretation verbleibt im kanonischen Toolbelt-Profil.

## Primärquellen

- [Freigegebener projektübergreifender Vertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
- [Austauschschema](../../../Metadata/Quality/SSIS_Exchange_V1.schema.json)
- [Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv)
- [SSISDB-Ausführungen](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-executions-ssisdb-database)
- [SSISDB-Executable-Statistiken](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-executable-statistics)
- [SSISDB-Komponentenphasen](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-execution-component-phases)
- [SSISDB-Pfadtransfers](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-execution-data-statistics)
- [Indexkatalog](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-indexes-transact-sql)
- [Indexspalten und Metadatensichtbarkeit](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-index-columns-transact-sql)

[Technische Detailbeschreibung](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)

Der separate [Ausführungsvergleich](USP_SsisExecutionComparison.md) verwendet zwei unabhängig gebundene Scope-/Pipelinecaptures desselben Exports. `-IncludeComparisonContext` ergänzt bei der Aufnahme attestierte Bitness; bestehende Einzelanalyse-Opt-ins bleiben unverändert.
