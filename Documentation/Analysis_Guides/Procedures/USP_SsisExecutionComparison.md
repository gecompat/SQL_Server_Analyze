# [monitor].[USP_SsisExecutionComparison]

**Bereich:** SSIS<br>
**Zweck:** Vergleicht genau eine Basisausführung und einen Kandidaten desselben exakten Paketmodellexports.<br>
**Beobachtungsart:** Zwei lokal gebundene historische Katalogcaptures.<br>
**Kostenklasse:** LOW_MEDIUM; JSON-Validierung, vorhandene Scopeauflösung und Kennzahlenpaarung bestimmen den Aufwand.

## Entscheidungsfrage und Einsatz

Die Procedure zeigt Änderungen beobachteter Status-, Dauer- und Pfadwerte. Sie verwendet die bestehenden Modell-, Scope- und Diagnoseconsumer. Parser, Komponentenprofile und Lineage verbleiben in Toolbelt; auf dem Analyze-Server sind weder Toolbelt noch SQL CLR erforderlich. Die API gehört zum Quellstand und ist über den [SSIS-Installer](../../../Code/Install/Install_SSIS_Analysis.sql) verfügbar; das Produkt-ZIP 1.1.2 enthält sie noch nicht.

Beide Seiten benötigen eine unabhängig registrierte lokale Scopeübergabe. Die Aufnahme erfolgt mit `Invoke-SsisCatalogHandover.ps1 -IncludeExecutionScopes -IncludePipelineCorrelation -IncludeComparisonContext`. Das neue Opt-in übernimmt ausschließlich die vor und nach der Aufnahme übereinstimmende 32-/64-Bit-Kennung aus `catalog.executions`. Es überträgt keine Parameterwerte oder Verbindungszeichenfolgen.

## Nicht beantwortete Fragen

Der Vergleich beweist weder Arbeitslastgleichheit noch eine Regressionsursache. Gleiche Pfade und Iterationsnummern bezeichnen beobachtete Positionen; sie identifizieren keine gleiche Datei oder Datenzeile. Unterschiedliche Paketrevisionen, Expressionauswertung und Paketausführung gehören nicht zu diesem Vertrag. `WorkloadEquivalence` bleibt `UNPROVEN`; alle Ergebnisse bleiben partiell.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisExecutionComparison] @Hilfe = 1;

-- Die Eingabewerte stammen aus zwei getrennten lokalen Übergaben.
EXEC [monitor].[USP_SsisExecutionComparison]
      @BaselineProjectModelsJson=@BaselineModels,
      @BaselineScopeSnapshotJson=@BaselineCapture,
      @BaselineScopeHandoverId=@BaselineHandover,
      @BaselineExecutionId=@BaselineExecution,
      @CandidateProjectModelsJson=@CandidateModels,
      @CandidateScopeSnapshotJson=@CandidateCapture,
      @CandidateScopeHandoverId=@CandidateHandover,
      @CandidateExecutionId=@CandidateExecution,
      @MaxZeilen=200, @ResultSetArt='CONSOLE';
```

Die Ausführungskennungen müssen positiv und verschieden sein. Beide Captures müssen dieselbe Quellbindung, Katalog-GUID, Projektkennung, Projekt-LSN, Archivkennung und Rootpaketdatei belegen. Beide Modelltexte müssen bytegleich in UTF-16LE sein; andere Leerzeichen führen bereits zu `COMPARISON_MODEL_EXPORT_DIFFERENT`. Diese konservative Bindung verhindert einen Vergleich unterschiedlicher Modell- oder Producerprofile. Unterschiedlich serialisierte Exporte werden nicht als semantisch gleich qualifiziert.

## Resultsets und Leserichtung

RAW, TABLE und JSON verwenden Schemaversion 1 und dieselben vier Gruppen. CONSOLE liefert genau eine Bindungsübersicht, NONE keine fachlichen Resultsets. JSON wird mit `@JsonErzeugen=1` über `@Json OUTPUT` geliefert. TABLE verwendet vom Caller erstellte lokale Temp-Tabellen und eine benannte Zuordnung in `@ResultTablesJson`; ungültige Zuordnungen werfen Frameworkfehler 51011.

| Gruppe | Bedeutung einer Zeile |
|---|---|
| `comparisonBinding` | Bindung beider Ausführungen, Versionen, Exportidentität, Protokollierung und Bitness mit übergeordnetem Status. |
| `objectComparison` | Eine Modell-/Aufrufposition und Kennzahl mit beiden Werten, Quellenkennungen, Trefferzahlen und gegebenenfalls Delta. |
| `comparisonFindings` | Ein versionierter INFO-Hinweis mit Kennzahl- und Quellenbezug oder eine ausdrückliche Evidenzgrenze. |
| `comparisonCoverage` | Quellenabdeckung je Seite oder Paarungszahlen vor der Ausgabekürzung. |

Lesen Sie zuerst Binding, dann Coverage und danach einzelne Deltas. `ComparisonKeySha256` bindet Objektart, Paket, Modellobjekt, Flow, qualifizierten Ausführungspfad, Phase und Kennzahl. Native Statistikkennungen bleiben Belege je Seite und werden nicht laufübergreifend verbunden. Schleifen und verschiedene Kindpaketaufrufstellen bleiben getrennt. Phasennamen und Pfade werden ordinal einschließlich nachlaufender Leerzeichen unterschieden.

## Eine Zeile bedeutet

Die Objektgruppe enthält Flowdauer und Ergebnis, Phasenintervallsumme, längstes Intervall, Spannweite und Anzahl sowie Pfadzeilen und Transferanzahl. Die gelieferte Portrolle bleibt erhalten. Eine Intervallsumme ist keine CPU-Zeit; Pfadzeilen werden nicht zu einer vermeintlichen Paketzeilenzahl summiert.

## So lesen

`COMPARABLE_OBSERVATION` verlangt je Seite genau einen bekannten, quellenqualifizierten Treffer, gleichen bekannten Protokollierungsgrad 1, 2 oder 3, gleiche attestierte Bitness und zwei erfolgreiche Ausführungen. `STATUS_ONLY` vergleicht Statuswerte ohne numerische Deltas. `BASELINE_ONLY` und `CANDIDATE_ONLY` erhalten die fehlende Gegenseite als NULL. `AMBIGUOUS` unterdrückt Wert und Quellen-ID einer mehrdeutigen Seite. `NOT_COMPARABLE` und `CONTEXT_LIMITED` liefern keine numerischen Deltas.

`DeltaValue` ist Kandidat minus Basis. `DeltaPercent` verwendet die Basis und wird auf sechs Nachkommastellen gerundet; bei Basis null bleibt der Prozentwert unbekannt. Die strikte Prozentgrenze wird unabhängig von dieser Rundung geprüft. Dauerzeilen mit fehlenden, unbekannten oder geänderten beobachteten Pfadzeilensets erhalten `VOLUME_CONTEXT_LIMITED`. Deren bereits berechnete Deltas bleiben beschreibend sichtbar; die Dauergrenzwertregel wird unterdrückt.

## Warum kann das problematisch sein?

Gleiche Paketbytes, Zähler und Laufzeitkontexte beweisen keine gleichen Daten, Parameter, Ressourcen oder Cachezustände. Unterschiedliche Protokollierung verändert Sichtbarkeit und Eigenlast. Ein Abbruch kann vor dem ersten qualifizierbaren Statistikbeleg erfolgen. Fehlende Ereignisse dürfen deshalb weder zu null noch zu erfundenen Aufrufen werden.

## Wann ist es kein Problem?

Ein positiver No-Match-Zähler oder eine längere Dauer kann zur beabsichtigten Verarbeitung gehören. Ein INFO-Hinweis verlangt eine fachliche Gegenprobe. Die Procedure verändert keinen Paketstatus und gibt keine automatische Optimierungs- oder Wiederholungsaktion frei.

## Beispiele und Gegenbeispiele

Die optionalen nichtnegativen Grenzen `@MinDurationDeltaMs` und `@MinDurationDeltaPercent` aktivieren `SSIS_COMPARISON_DURATION_THRESHOLD_EXCEEDED`. Eine bekannte positive Daueränderung muss jede gesetzte Grenze strikt überschreiten. Bei NULL für beide Grenzen entsteht kein Dauerhinweis; Gleichheit genügt nicht. Ein Basiswert null erfüllt keine relative Grenze, kann aber eine allein gesetzte absolute Grenze erfüllen.

`SSIS_COMPARISON_STATUS_CHANGED` zeigt unterschiedliche Statuswerte. `SSIS_COMPARISON_OBSERVED_ROWS_CHANGED` zeigt unterschiedliche bekannte Pfadzähler bei passendem Kontext. `SSIS_COMPARISON_EVIDENCE_LIMITED` benennt begrenzte Bindung, Quelle, Paarung oder Vergleichbarkeit. Alle Regeln tragen Version 1.0.0 und Severity INFO. Quellenkennungen referenzieren den ursprünglichen Capture und beweisen keine Ursache.

## Leere oder partielle Ausgabe

Bei ungültiger Bindung bleibt die Objektgruppe leer; Binding und Coverage erklären die Grenze. Alte Captures ohne optionalen Vergleichskontext bleiben für die Einzelanalyse gültig, erhalten hier jedoch `RUNTIME_CONTEXT_UNPROVEN`. Unbekannter Kontext wird nicht ergänzt.

`@MaxZeilen` begrenzt jede Gruppe erst nach der Berechnung; 0 und NULL bedeuten ungekürzt, negative Werte sind ungültig. Coverage zählt das gesamte berechnete Set und meldet eine Ausgabekürzung. Ein referenzierter Beleg kann außerhalb der ausgegebenen Detailzeilen liegen.

## Eigenlast und Grenzen

Der Standardpfad validiert zwei Modelle und zwei Captures mit jeweils höchstens 16 MiB. Je Seite gelten die bestehenden Quellgrenzen von 50000 Belegen und höchstens 200000 normalisierte Kennzahlen. Das gemeinsame kooperative Budget beträgt standardmäßig 30, höchstens 60 Sekunden. JSON, lokale Temp-Objekte, Hashes und Gruppierungen sind die Haupttreiber; die gelieferte Beobachtungsmenge bestimmt die Skalierung.

Der teuerste Pfad bleibt auf zwei Captures beschränkt und liest weder SSISDB noch externe Datenbanken. EXECUTE und sichtbare lokale Übergabeatteste sind erforderlich. Geschrieben werden eigene Temp-Objekte und ausdrücklich zugeordnete TABLE-Ziele. Caller-Locktimeout und XACT_ABORT werden wiederhergestellt. Das kooperative Zeitbudget ist keine harte CPU- oder Speichergrenze. Begrenzte Eingaben und zunächst kleine Ausgaben ermöglichen einen sicheren Einstieg; der Ausgabegrenzwert reduziert nicht den Validierungsaufwand.

## Technische Vertiefung

### Leitfrage

Sind zwei unabhängig belegte Beobachtungssets derselben Modellrevision an derselben Aufrufposition vergleichbar?

### Technischer Hintergrund

Die bestehende `USP_SsisPackageModelAnalysis` übernimmt Bindung, Pfadauflösung und Diagnoseaggregation je Seite. Der Vergleich projiziert deren Ergebnisse und ergänzt keine zweite Parser- oder Lineageimplementierung.

### Datenkette

Toolbelt-Export und Archivbytes werden lokal qualifiziert. Der Adapter registriert zwei getrennte hashgebundene Scopebelege. Die vorhandenen Consumer prüfen sie, bevor der Vergleich Schlüssel und Kennzahlen bildet.

### Source Select

Kein einzelnes Grundselect bildet den Vergleich ab. **Wichtig für die Eigenlast:** Beide vollständigen Captures werden vor der Ausgabekürzung lokal validiert und gruppiert.

Der Vergleich verarbeitet Caller-JSON und lokale Übergabeatteste. Die vorgeschaltete Aufnahme filtert strukturierte Katalogquellen auf genau eine Ausführung; nur dort werden `catalog.executions.use32bitruntime`, Phasen und Transfers gelesen.

### Zeit- und Scope-Modell

Captures gelten zum Aufnahmezeitpunkt und innerhalb ihrer lokalen Gültigkeit. Projekt-LSN und Archivbindung verhindern einen Vergleich aktueller Bytes mit einer fremden historischen Revision. Zwei Zeitpunkte bilden keine Zeitreihe.

### Bewertung und Gegenprobe

Prüfen Sie beide Einzelanalysen, die Belege, Protokollierungsstufen und beobachteten Mengen. Prüfen Sie zusätzlich die fachlichen Eingaben außerhalb dieses Vertrags, bevor Sie gleiche Arbeitslast annehmen.

### Typische Fehlinterpretation

Ein positiver Prozentwert belegt eine Differenz, keine softwarebedingte Regression. Eine gleich nummerierte Iteration muss nicht dieselbe Eingabe verarbeitet haben.

### Folgeanalyse

Die [Einzelanalyse](USP_SsisPackageModelAnalysis.md) zeigt Scopes, Phasen und Transfers. Die [Kataloganalyse](USP_SsisCatalogExecutionAnalysis.md) ergänzt strukturierte Metadaten einer Ausführung.

## Primärquellen

- [Austauschvertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
- [Kanonische Implementierung](../../../Code/10_SSIS/050_USP_SsisExecutionComparison.sql)
- [Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv)
- [SSISDB-Ausführungsmetadaten](https://learn.microsoft.com/en-us/sql/integration-services/system-views/catalog-executions-ssisdb-database)

[Technische Detailbeschreibung](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)
