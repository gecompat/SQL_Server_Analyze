# [monitor].[USP_SsisExecutionBaseline]

**Bereich:** SSIS<br>
**Zweck:** Vergleicht einen Kandidaten mit einer expliziten Kohorte unabhängig gebundener Ausführungen derselben Modellrevision.<br>
**Beobachtungsart:** Lokal attestierte historische Katalogcaptures.<br>
**Kostenklasse:** LOW_MEDIUM; die Zahl der Captures und Kennzahlen bestimmt Validierungs-, TempDB- und Gruppierungsaufwand.

## Entscheidungsfrage und Einsatz

Die Procedure zeigt, wie eine beobachtete Kennzahl des Kandidaten zum Median und Wertebereich ausgewählter Basisläufe steht. Die Kohorte enthält 1 bis 20 explizite Basisläufe und genau einen verschiedenen Kandidaten. Es erfolgt keine automatische Suche nach geeigneten Ausführungen. Der [SSIS-Installer](../../../Code/Install/Install_SSIS_Analysis.sql) enthält die API im Quellstand; das Produkt-ZIP 1.1.2 enthält sie noch nicht.

Jeder Capture benötigt eine eigene lokale Scopeübergabe. Die Aufnahme verwendet `Invoke-SsisCatalogHandover.ps1 -IncludeExecutionScopes -IncludePipelineCorrelation -IncludeComparisonContext`. Die Aufnahmeanleitung der [Einzelanalyse](USP_SsisPackageModelAnalysis.md) erläutert Toolbelt-Exporthost, Quellbindung und lokale Attestierung. Die Übergaben müssen auf dem Analyze-Ziel sichtbar und gültig sein. Auf dem Analyze-Server sind weder Toolbelt noch SQL CLR erforderlich. Parser, Komponentenprofile und Lineage werden ausschließlich in Toolbelt gepflegt.

## Nicht beantwortete Fragen

Die API beweist weder gleiche Arbeitslast noch statistische Signifikanz, SLA-Einhaltung oder Regressionsursachen. Gleiche Paketbytes, Aufrufpositionen und Pfadzähler belegen keine gleichen Eingaben, Parameter, Datenzeilen, Ressourcen oder Cachezustände. Persistente Historisierung, automatische Baselineauswahl und Paketausführung gehören nicht zu diesem Vertrag. `WorkloadEquivalence` bleibt `UNPROVEN`; alle Ergebnisse bleiben partiell.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_SsisExecutionBaseline] @Hilfe = 1;

-- Modell- und Capturetexte bleiben Strings, damit ihre exakten Bytes erhalten bleiben.
-- Für weitere Basisläufe enthält das Array entsprechend weitere getrennte Einträge.
DECLARE @Baselines nvarchar(max)=(
 SELECT @BaselineModels AS projectModelsJson,
        @BaselineCapture AS scopeSnapshotJson,
        CONVERT(varchar(36),@BaselineHandover) AS scopeHandoverId,
        CONVERT(varchar(20),@BaselineExecution) AS executionId
 FOR JSON PATH);

EXEC [monitor].[USP_SsisExecutionBaseline]
      @BaselineExecutionsJson=@Baselines,
      @CandidateProjectModelsJson=@CandidateModels,
      @CandidateScopeSnapshotJson=@CandidateCapture,
      @CandidateScopeHandoverId=@CandidateHandover,
      @CandidateExecutionId=@CandidateExecution,
      @MaxZeilen=200, @ResultSetArt='CONSOLE';
```

Jedes Arrayelement enthält genau die vier genannten Stringfelder. Ausführungskennungen sind positive kanonische Dezimalstrings ohne Vorzeichen oder führende Nullen. Sie müssen innerhalb der gesamten Kohorte einschließlich Kandidat verschieden sein. Übergabekennungen sind gültige GUIDs; zu jedem Eintrag muss der passende lokale Scopebeleg vorliegen. Das Einführungsbeispiel liefert einen deskriptiven Vergleich mit zu kleiner Basis für fachliche Hinweise. Mindestens fünf verwendbare Werte sind je Kennzahl erforderlich.

Quelle, Katalog-GUID, Projektkennung, Projekt-LSN, Archiv und Rootpaketdatei müssen übereinstimmen. Alle Modelltexte müssen bytegleich in UTF-16LE sein. Schon andere Leerzeichen führen zu `BASELINE_MODEL_EXPORT_DIFFERENT`. Unterschiedliche Quell- oder Projektversionen liefern `BASELINE_SOURCE_VERSION_DIFFERENT`; eine gesamte Kohorte wird abgelehnt. Die API qualifiziert keine semantische Gleichheit unterschiedlich serialisierter Exporte.

## Resultsets und Leserichtung

RAW, TABLE und JSON verwenden dieselben fünf nativen Gruppen in Schemaversion 1. CONSOLE liefert eine Bindungsübersicht; NONE liefert keine fachlichen Resultsets. JSON entsteht mit `@JsonErzeugen=1` über `@Json OUTPUT`. TABLE verwendet lokale, vom Caller erstellte Temp-Tabellen und `@ResultTablesJson`. Fehlerhafte Zuordnungen werfen Frameworkfehler 51011.

| Gruppe | Bedeutung einer Zeile |
|---|---|
| `baselineBinding` | Kohortenbindung, Kandidat, Zahl der Eingabe- und analysierten Läufe, Projekt-/Exportbindung und Mindestzahl für Hinweise. |
| `executionCohort` | Ein expliziter Lauf mit Rolle, Abschlussstatus, Logging, Bitness, Kontext sowie Zahl einbezogener und ausgeschlossener Kennzahlen. Ordinal 0 bezeichnet den Kandidaten. |
| `metricBaseline` | Eine Modell-/Aufrufposition und numerische Kennzahl mit verwendbarer Laufzahl, Median, Minimum, Maximum, Spannweite und Kandidatendelta. |
| `baselineFindings` | Ein versionierter INFO-Hinweis oder eine ausdrückliche Evidenzgrenze. |
| `baselineCoverage` | Ein Ein-/Ausschluss je Lauf und Kennzahl, Quellenbeleg oder Kohortenübersicht mit Ausgabekürzung. |

Lesen Sie zuerst Binding, danach Kohorte und Coverage und anschließend die Statistik. `AnalyzedExecutionCount` zählt die erfolgreich zurückgegebenen Einzelanalysen; jeder Eingabecapture wird einmal analysiert. Die Coverage nennt bei Kennzahlen Quellen-ID und beobachteten Wert. Bei mehrdeutigen Beobachtungen bleiben beide NULL. Quellen-IDs werden ausschließlich innerhalb des jeweiligen Captures ausgewertet.

## Eine Zeile bedeutet

`ComparisonKeySha256` bindet Objektart, Paket, Modellobjekt, Flow, qualifizierten Aufrufpfad, Phase und Kennzahl. Native Statistikkennungen bilden keinen laufübergreifenden Schlüssel. Schleifen und unterschiedliche Kindpaketaufrufe bleiben getrennt. Pfad- und Phasentext werden ordinal einschließlich nachlaufender Leerzeichen unterschieden.

Die Statistik umfasst Flowdauer, Phasenintervallsumme, längstes Intervall, Phasenspannweite und Intervallanzahl sowie Pfadzeilen und Transferanzahl. Statuswerte werden nicht gemittelt; der Abschlussstatus steht in der Laufkohorte. Phasensummen sind keine CPU-Zeit, und Pfadzähler ergeben keine globale Paketzeilenzahl. Die Portrolle stammt unverändert aus dem Toolbelt-Modell.

## So lesen

Jede Kennzahl erhält ihre eigene verwendbare Basiszahl `ValidBaselineCount`. Einbezogen werden nur eindeutige, bekannte und quellenqualifizierte Beobachtungen bei gleichem bekannten Logginggrad 1, 2 oder 3, gleicher attestierter Bitness und erfolgreichem Abschluss von Basis und Kandidat. Dauerwerte verlangen zusätzlich dasselbe bekannte beobachtete Pfadzeilenset innerhalb der konkreten Flowinstanz. Diese Einschränkung kann die verwendbare Laufzahl je Kennzahl verändern.

`MedianValue`, `MinValue`, `MaxValue` und `SpreadValue` beschreiben ausschließlich einbezogene Basiswerte. Bei einer geraden Zahl ist der Median das exakte Mittel der beiden mittleren Werte einschließlich halber Einheiten. `SpreadValue` ist Maximum minus Minimum. Die Berechnung verwendet keine Gleitkommaarithmetik. Fehlende Beobachtungen sind unbekannt und werden nicht zu null ergänzt.

`DeltaValue` ist Kandidat minus Median. `DeltaPercent` verwendet den Median als Nenner und wird auf sechs Nachkommastellen gerundet; bei Median null bleibt der Prozentwert NULL. Strikte Grenzwerte werden unabhängig von der Anzeigerundung geprüft. Bei keinem verwendbaren Basiswert bleiben Statistik und Deltas NULL. Bei einem unbekannten Kandidaten kann die deskriptive Basisstatistik weiterhin vorliegen, das Kandidatendelta bleibt NULL.

`COMPARABLE_OBSERVATION` verlangt mindestens fünf verwendbare Basiswerte und einen verwendbaren Kandidaten. `INSUFFICIENT_BASELINE_COUNT` erlaubt deskriptive Statistik und Deltas bei weniger als fünf Werten, erzeugt aber keinen fachlichen Grenzwerthinweis. `NO_BASELINE_OBSERVATIONS` und `CANDIDATE_EVIDENCE_LIMITED` benennen die jeweilige Grenze. Die Ausschlussgründe stehen je Lauf und Kennzahl in Coverage; fehlendes Logging, Bitness, Quellenzugriff, Mehrdeutigkeit und unbekannte Werte werden nicht ergänzt.

## Warum kann das problematisch sein?

Eine vom Anwender ausgewählte kleine Kohorte kann ungeeignet oder verzerrt sein. Eine Mindestzahl von fünf belegt keine statistische Stabilität. Unterschiedliche Loggingstufen verändern Sichtbarkeit und Eigenlast; Fehler und Abbrüche können vor den ersten Statistikbelegen liegen. Ein geändertes beobachtetes Volumen verhindert belastbare Dauerhinweise für diese Instanz.

## Wann ist es kein Problem?

Eine höhere beobachtete Dauer oder ein anderer Pfadzähler kann beabsichtigte Verarbeitung beschreiben. Ein INFO-Hinweis verlangt eine fachliche Gegenprobe. Die API verändert weder Logging noch Paketstatus und gibt keine automatische Optimierungs-, Wiederholungs- oder Abbruchaktion frei.

## Beispiele und Gegenbeispiele

`@MinDurationDeltaMs` und `@MinDurationDeltaPercent` sind optionale nichtnegative Grenzen. `SSIS_BASELINE_DURATION_THRESHOLD_EXCEEDED` verlangt mindestens fünf verwendbare Basiswerte, einen verwendbaren Kandidaten, eine positive Daueränderung und striktes Überschreiten jeder gesetzten Grenze. Ohne Grenzen entsteht kein Dauerhinweis. Ein Median null kann eine alleinige absolute Grenze erfüllen, aber keine relative Grenze.

`SSIS_BASELINE_OBSERVED_ROWS_CHANGED` beschreibt einen vom Median verschiedenen bekannten Pfadzähler ab fünf verwendbaren Basiswerten. Die Regel verwendet die explizite Bedingung Delta ungleich null und behauptet keine Volumenregression. `SSIS_BASELINE_EVIDENCE_LIMITED` meldet eine begrenzte Bindung, ausgeschlossene Läufe oder Kennzahlen und zu kleine verwendbare Mengen. Alle Regeln tragen Version 1.0.0 und Severity INFO.

## Leere oder partielle Ausgabe

Ein ungültiger Capture, doppelte Ausführungskennungen oder eine abweichende Modell-/Quellversion verhindern die gesamte Kohortenbindung. Die Kennzahlengruppe bleibt leer; Binding und Coverage nennen die Grenze. Alte Captures ohne optionalen Vergleichskontext bleiben für die Einzelanalyse gültig, liefern hier jedoch `RUNTIME_CONTEXT_UNPROVEN`.

`@MaxZeilen` begrenzt jede Gruppe nach der Berechnung; 0 und NULL bedeuten ungekürzt. Negative Werte sind ungültig. `baselineBinding.MetricCount` und die Kohortenzähler beschreiben das ungekürzte Set. Coverage meldet eine Kürzung ausdrücklich. Ein referenzierter Quellenbeleg kann außerhalb der ausgegebenen Zeilen liegen.

## Eigenlast und Grenzen

Die gesamte Eingabe ist auf 64 MiB begrenzt, jeder Modell- und Capturetext zusätzlich auf 16 MiB. Je Capture gelten die bestehenden 50000 Quellbelege und 200000 normalisierten Kennzahlen. Die gesamte Kohorte erlaubt höchstens 100000 Quellzeilen, 400000 Kennzahlen und 400000 Kombinationen aus Lauf und unterschiedlicher Kennzahl. Damit wird auch die Darstellung fehlender Beobachtungen begrenzt. Die Ausgabegrenze senkt den Validierungsaufwand nicht.

Das gemeinsame kooperative Zeitbudget beträgt standardmäßig 30, höchstens 60 Sekunden. Jeder Eingabecapture wird einmal durch den gemeinsamen nativen Kennzahlconsumer geprüft. JSON, lokale Temp-Tabellen, Hashes, Aufrufzuordnung und Sortierungen bestimmen die Eigenlast; das Budget ist keine harte CPU- oder Speichergrenze. Beginnen Sie mit einer kleinen expliziten Kohorte und begrenzter Ausgabe.

Die Procedure liest keine SSISDB und öffnet keine externe Verbindung. EXECUTE und sichtbare gültige lokale Scopebelege sind erforderlich. Geschrieben werden eigene Temp-Objekte und explizite TABLE-Ziele. Locktimeout und XACT_ABORT des Callers werden wiederhergestellt. Eine fehlende oder abgelehnte Herkunft wird nicht durch zusätzliche Berechtigungen oder automatische Infrastrukturänderungen repariert.

## Technische Vertiefung

### Leitfrage

Welche Kennzahlen des Kandidaten lassen sich mit mindestens fünf verwendbaren Beobachtungen derselben gebundenen Modellrevision vergleichen?

### Technischer Hintergrund

`InternalSsisExecutionMetrics` validiert und projiziert jeden Capture für Paarvergleich und Baseline. Der bestehende Modell-/Scopeconsumer übernimmt Herkunft, Version, Aufrufauflösung und Diagnoseaggregation. Die Baseline bildet daraus eine endliche explizite Kohorte; sie ergänzt keinen Parser und keine Lineageimplementierung.

### Datenkette

Toolbelt exportiert das Modell. Der Katalogadapter nimmt jeden Lauf getrennt auf und registriert den hashgebundenen lokalen Scopebeleg. Analyze prüft jeden Capture einmal, bildet gemeinsame Positionsschlüssel und bewertet die Einbeziehbarkeit je Kennzahl.

### Source Select

Kein einzelnes Grundselect bildet die Mehrlaufstatistik ab. **Wichtig für die Eigenlast:** Alle Eingabecaptures werden vor der Ausgabekürzung validiert. Die Statistik verbindet ausschließlich aufgelöste Modell-/Aufrufschlüssel; Quellen-IDs bleiben lauflokal.

### Zeit- und Scope-Modell

Die Captures gelten zu ihren Aufnahmezeitpunkten und innerhalb der lokalen Attestgültigkeit. Projekt-LSN und Archivbindung verhindern die Vermischung verschiedener Revisionen. Die explizite Kohorte ist keine persistent verwaltete Zeitreihe.

### Bewertung und Gegenprobe

Prüfen Sie Ausschlüsse und verwendbare Laufzahl für genau die betroffene Kennzahl. Vergleichen Sie ausgewählte Paare mit der unveränderten [Paar-API](USP_SsisExecutionComparison.md) und prüfen Sie die Einzelbelege. Die fachlichen Eingaben und Ressourcenbedingungen müssen außerhalb dieses Vertrags beurteilt werden.

### Typische Fehlinterpretation

Ein positiver Abstand zum Median beweist keine softwarebedingte Regression. Gleiche Iterationsnummern können unterschiedliche Eingaben enthalten; fünf Läufe garantieren keine belastbare Verteilung.

### Folgeanalyse

Die [Einzelanalyse](USP_SsisPackageModelAnalysis.md) zeigt Scopes, Phasen, Transfers und Herkunft. Die [Kataloganalyse](USP_SsisCatalogExecutionAnalysis.md) ergänzt strukturierte Metadaten eines konkreten Laufs.

## Primärquellen

- [Austauschvertrag](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)
- [Kanonische Implementierung](../../../Code/10_SSIS/060_USP_SsisExecutionBaseline.sql)
- [Gemeinsamer Kennzahlconsumer](../../../Code/10_SSIS/045_InternalSsisExecutionMetrics.sql)
- [Resultsetinventar](../../../Metadata/Inventory/ResultSets.csv)

[Technische Detailbeschreibung](../../Architecture/SSIS_Analyze_Toolbelt_Exchange_Contract.md)

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)
