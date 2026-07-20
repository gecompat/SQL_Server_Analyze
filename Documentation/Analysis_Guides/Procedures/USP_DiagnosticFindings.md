# [monitor].[USP_DiagnosticFindings]

**Bereich:** Server Health<br>
**Zweck:** Konsolidiert normalisierte Findings mit Priorität, Konfidenz, Evidenz und Aussagegrenze.<br>
**Beobachtungsart:** nicht atomarer Mix aus Child-Snapshots, Stichproben und Historien<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche normalisierten Befunde aus mehreren Spezialmodulen verdienen Priorität und wie stark ist die Evidenz?** Der dokumentierte Zweck ist: Konsolidiert normalisierte Findings mit Priorität, Konfidenz, Evidenz und Aussagegrenze. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Mix aus Child-Snapshots, Samples und Historien im selben Lauf. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DiagnosticFindings]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurAbPrioritaet = 'INFO',
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem normalisierten Finding aus einem SourceModule. Modulstatuszeilen sind getrennt zu lesen.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Severity **und** Confidence mit SourceModule, Evidence, `EvidenceLimit`, RecommendedNextCheck und Modulstatus lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

HIGH/HIGH ist starke priorisierte Evidenz. HIGH/LOW verlangt dringende Verifikation, ist aber noch keine bestätigte Ursache.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Keine Findings sind nur beruhigend, wenn alle relevanten SourceModules vollständig liefen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Leeres Findingsresultset plus Integritätsmodul `PERMISSION_DENIED` ist keine Entwarnung. Ein HIGH/HIGH-Suspect-Page-Finding verlangt sofortige Detailprüfung im SourceModule.

**Ähnlich aussehender Gegenfall:** Keine Findings sind nur beruhigend, wenn alle relevanten SourceModules vollständig liefen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_DiagnosticFindings` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

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

### Zeit- und Scope-Modell

Mix aus Child-Snapshots, Samples und Historien im selben Lauf. Wiederverwendung gilt nur innerhalb desselben Parent-Laufs; es gibt keinen sitzungs- oder aufrufübergreifenden Cache.

### Bewertung und Gegenprobe

Severity und Confidence gemeinsam lesen, SourceModule/Scope zum Detail zurückverfolgen, EvidenceLimit nicht ausblenden. HIGH+LOW verlangt schnelle Validierung, nicht automatische Aktion.

### Typische Fehlinterpretation

Keine Findings bedeutet nur dann wenig Auffälliges, wenn alle relevanten Children vollständig erfolgreich waren. Normalisierung kann Details bewusst weglassen.

### Folgeanalyse

SourceModule direkt mit engem Scope aufrufen.

## Primärquellen

- [sp_server_diagnostics](https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-server-diagnostics-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../08_Server_Health.md#17-monitorusp_diagnosticfindings)
