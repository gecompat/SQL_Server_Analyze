# [monitor].[USP_DiagnosticFindings]

**Bereich:** Server Health<br>
**Zweck:** Konsolidiert normalisierte Findings mit Priorität, Konfidenz, Evidenz und Aussagegrenze.<br>
**Beobachtungsart:** nicht atomarer Mix aus Child-Snapshots, Stichproben und Historien<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche normalisierten Befunde aus mehreren Spezialmodulen verdienen Priorität und wie stark ist die Evidenz?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DiagnosticFindings]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurAbPrioritaet = 'INFO',
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die zehn Textspalten der lokalen Befundtabelle und die vier Textspalten der
Modulstatusvariable verwenden explizit `SQL_Latin1_General_CP1_CS_AS`.
Der TABLE-Export behält diese Frameworkcollation auch bei einer abweichenden
Server- oder `tempdb`-Collation. Nach Befunderzeugung und Statusermittlung wird
die gemeinsame Ausgabemenge nach `@NurAbPrioritaet` gefiltert und nach
`@MaxZeilen` begrenzt. RAW, CONSOLE, TABLE und JSON verwenden dieselben Befunde.

Die vorhandenen Zähler werden vor der Ausgabekürzung ermittelt:
`totalFindingCount` sowie die RAW- und CONSOLE-Gesamtzahl zählen alle erzeugten
Befunde. Das bisherige JSON-Feld `returnedFindingCount` zählt die Befunde nach
Prioritätsfilter, aber vor dem Zeilenlimit. Bei vier passenden Befunden und
`@MaxZeilen=1` beträgt dieser Zähler weiterhin vier; das Findingarray und der
TABLE-Export enthalten jeweils eine Zeile.

## Eine Zeile bedeutet

Eine Zeile entspricht einem normalisierten Finding aus einem SourceModule. Modulstatuszeilen sind getrennt zu lesen.

## So lesen

Berücksichtigen Sie Severity **und** Confidence mit SourceModule, Evidence, `EvidenceLimit`, RecommendedNextCheck und Modulstatus.

## Warum kann das problematisch sein?

HIGH/HIGH ist starke priorisierte Evidenz. HIGH/LOW verlangt dringende Verifikation, ist aber noch keine bestätigte Ursache.

## Wann ist es kein Problem?

Keine Findings sind nur beruhigend, wenn alle relevanten SourceModules vollständig liefen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Leeres Findingsresultset plus Integritätsmodul `PERMISSION_DENIED` ist keine Entwarnung. Ein HIGH/HIGH-Suspect-Page-Finding verlangt sofortige Detailprüfung im SourceModule.

**Ähnlich aussehender Gegenfall:** Keine Findings sind nur beruhigend, wenn alle relevanten SourceModules vollständig liefen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_DiagnosticFindings` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Sechs Children sind an: Integritäts-, Kapazitäts-, reduzierte Buffer-Pool-, Backupketten-, Availability- und Agent-Evidenz. Die Procedure liest deren JSON-Verträge und erzeugt daraus normalisierte Findings; Schema, Histogramme, IQP und Contention bleiben aus. |
| Teuerster Pfad | Breiter Datenbankscope plus alle vier Opt-ins. Besonders `USP_StatisticsDistributionAnalysis` läuft dann mit `@AnalyseModus = 'VOLL'`; SchemaDesign scannt Datenbankkataloge, und Contention hält für das konfigurierte Sample eine Session. |
| Haupttreiber | Zahl der Datenbanken, Dateien, Backup-/Restorehistorienzeilen und HA-/Agentobjekte sowie bei Opt-in die Anzahl von Schemaobjekten und Statistik-Histogrammen. Das abschließende Mapping der JSON-Evidenz ist meist kleiner als die Childerhebung. |
| Skalierung | Children laufen sequenziell und erzeugen jeweils JSON. Ohne `@ParentIntegrityJson`, `@ParentCapacityJson` und `@ParentBufferPoolJson` werden diese Quellen frisch gelesen; ein übergeordneter Orchestrator kann genau diese drei Ergebnisse wiederverwenden und Doppelarbeit vermeiden. |
| Ressourcen | Datenbank-/Server-DMVs, Kataloge und `msdb`-Historie; optional Histogrammzugriff, TempDB/JSON und ein Contention-WAITFOR. Es gibt in diesem Aggregator keinen Ereignisdatei- oder Plan-XML-Pfad. |
| Begrenzungswirkung | `@MaxZeilen` begrenzt das finale Findingresultset und wird an Children weitergereicht. Es ist kein gemeinsames Quellbudget: Backup- oder Katalogaggregation kann vor dem Childlimit stattfinden, und die VOLL-Histogrammauswahl hat eigene Kandidatenregeln. `@NurAbPrioritaet` filtert Findings erst nach der Erhebung. |
| Locking und Nebenwirkungen | Read-only. Childaufrufe sind nicht atomar; Backup-, HA- oder Agentzustände können zwischen ihnen wechseln. Nur das optionale Contention-Sample verlängert den Aufruf per WAITFOR, ohne absichtlich Nutzdatenlocks zu halten. |
| Schutzmechanismus | `@HighImpactConfirmed` wird an datenbankweite und tiefe Children weitergereicht. Schema-, Statistikverteilungs- und IQP-Pfade bleiben zusätzlich standardmäßig deaktiviert. Freigabe, Childschalter und Mengen-/Zeitrahmen sind drei getrennte Schutzebenen. |
| Sicherer Einsatz | Eine Datenbank, `@MaxZeilen = 100`, die vier Deep-Schalter aus und vollständigen Childstatus lesen. Danach nur das Finding mit hoher Priorität im zuständigen Fachmodul reproduzieren. |
| Aussagegrenze | Ein Finding ist aus normalisierten Childfeldern abgeleitete Triage, keine Root-Cause-Feststellung. Wiederverwendete Parent-JSONs können etwas älter als frisch gelesene Children sein; Limits oder ein fehlgeschlagenes Child können Findingkategorien ganz entfernen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche normalisierten Befunde aus mehreren Spezialmodulen verdienen Priorität und wie stark ist die Evidenz?

### Technischer Hintergrund

Aggregator ruft Children über definierte JSON-/RAW-Verträge auf und normalisiert Category, Severity, Confidence, Scope, Evidence, EvidenceLimit und Next Check. Innerhalb von `USP_ServerHealthAnalysis` werden bereits kontextgleich erhobene Integritäts-, Kapazitäts- und Buffer-Pool-Ergebnisse wiederverwendet; `InvocationStatus=REUSED_PARENT_RESULT` macht dies sichtbar. Ein direkter Aufruf ohne Parent-Ergebnis liest die aktivierten Quellen frisch.

### Datenkette

`sys.databases`, `sys.sp_executesql`.

### Source Select

Kein einzelnes Grundselect wird verwendet. Die Procedure ruft die ausgewählten Diagnosemodule auf, übernimmt deren strukturierte Ergebnisse und normalisiert sie zu Findings. Direkte Quellen liegen unter anderem in `USP_DatabaseIntegrityAnalysis`, `USP_DatabaseCapacityAnalysis`, `USP_BufferPoolAnalysis`, `USP_BackupChainAnalysis`, `USP_AvailabilityDeepAnalysis`, `USP_AgentMonitoringAnalysis`, `USP_SchemaDesignAnalysis`, `USP_StatisticsDistributionAnalysis`, `USP_IntelligentQueryProcessingAnalysis` und `USP_InternalContentionAnalysis`.

**Wichtig für die Eigenlast:** Aktivieren Sie nur benötigte Finding-Gruppen und reichen Sie den Datenbankscope früh weiter. Das spätere `@MaxZeilen` begrenzt die Findingausgabe, nicht automatisch die Quellarbeit jedes Childmoduls.

### Zeit- und Scope-Modell

Die Auswertung kombiniert Child-Snapshots, Samples und Historien im selben Lauf. Die Wiederverwendung gilt nur innerhalb desselben Parent-Laufs; es gibt keinen sitzungs- oder aufrufübergreifenden Cache.

### Bewertung und Gegenprobe

Lesen Sie Severity und Confidence gemeinsam, verfolgen Sie SourceModule und Scope zum Detail zurück und blenden Sie `EvidenceLimit` nicht aus. Die Kombination HIGH und LOW verlangt eine schnelle Validierung, aber keine automatische Aktion.

### Typische Fehlinterpretation

Keine Findings bedeutet nur dann wenig Auffälliges, wenn alle relevanten Children vollständig erfolgreich waren. Normalisierung kann Details bewusst weglassen.

### Folgeanalyse

Rufen Sie SourceModule direkt mit engem Scope auf.

## Primärquellen

- [sp_server_diagnostics](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-server-diagnostics-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../08_Server_Health.md#17-monitorusp_diagnosticfindings)
