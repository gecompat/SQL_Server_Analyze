# [monitor].[USP_ServerHealthAnalysis]

**Bereich:** Server Health, Orchestrator<br>
**Zweck:** Orchestriert Topologie, Memory, TempDB, Konfiguration, OS und optionale Spezialmodule.<br>
**Beobachtungsart:** nicht atomare Folge von Server-Snapshots<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Server-Health-Bereiche sind auffällig und welches Spezialmodul soll als Nächstes laufen?** Der dokumentierte Zweck ist: Orchestriert Topologie, Memory, TempDB, Konfiguration, OS und optionale Spezialmodule. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Nicht atomare Folge aktueller Konfigurations-/Runtimeabfragen. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerHealthAnalysis]
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Spezialmodule nur bei konkreter Frage aktivieren.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `moduleStatus` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: CPU, Scheduler, Node, Memory, Datei, Konfiguration, Ereignis oder Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Childstatus zuerst und Symptome familienweise lesen. Eine Summenzeile ist keine vollständige Gesundheitsgarantie.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein Child kann partiell sein; ein anderes zeigt nur Konfiguration statt aktueller Auswirkung.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Nicht aktivierte Spezialmodule fehlen absichtlich.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Memorykonfiguration auffällig, aktuelle Memorywerte normal: Review, kein akuter Incident. Das betreffende Child fokussiert erneut ausführen.

**Ähnlich aussehender Gegenfall:** Nicht aktivierte Spezialmodule fehlen absichtlich. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_ServerHealthAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Neun kleine Server-Snapshots: CPU, NUMA, Memory, TempDB-Konfiguration, Serverkonfiguration, Trace Flags, Startparameter, OS und Security. Datenbankweite Integrität/Kapazität und alle Spezialmodule sind aus. |
| Teuerster Pfad | Alle sieben Opt-ins: Datenbankintegrität/-kapazität, Performance-Counter-Snapshot, `system_health`-Ereignisse, fünf Sekunden Contention, Buffer-Pool-Kontext und Findings. Findings kann weitere Standardchildren frisch erheben, verwendet aber vorhandene Integritäts-, Kapazitäts- und Buffer-Pool-JSONs wieder. |
| Haupttreiber | Im Default überwiegend kleine SQLOS-/Serverkataloge. Im erweiterten Pfad wachsen Kosten mit Datenbanken/Dateien, `msdb`-Historie, System-Health-Ereignissen, Latch-/Spinlockklassen und den von Findings zusätzlich benötigten Quellen. |
| Skalierung | Children laufen sequenziell. Aktivierte Integritäts-/Kapazitäts-/Buffer-Pool-Ergebnisse werden an Findings weitergereicht und dort nicht doppelt gelesen; andere Findings-Quellen bleiben zusätzliche Arbeit. |
| Ressourcen | Server-/OS-DMVs und Kataloge; optional Datenbankmetadaten, `msdb`, XE-Datei-/XML-Verarbeitung, TempDB/JSON sowie ein festes fünfsekündiges WAITFOR im Contention-Child. Es gibt keinen Plan-Cache- oder Query-Store-Pfad. |
| Begrenzungswirkung | `@MaxZeilen` wird nur an Children mit passendem Parameter übergeben und gilt dort je Resultset. Kleine Topologiechildren sind ohnehin unlimitiert; bei XE-/Historien-/Katalogchildren kann Quellarbeit vor der Ausgabegrenze stattfinden. |
| Locking und Nebenwirkungen | Read-only. Contention hält die Session fünf Sekunden; die übrigen Children verändern weder Konfiguration noch Daten. Weil alle nacheinander laufen, können Memory-, TempDB-, XE- und Findings-Sicht verschiedene Zeitpunkte repräsentieren. |
| Schutzmechanismus | Alle breiteren Spezialmodule sind standardmäßig aus. `@HighImpactConfirmed` wird an datenbankweite Children/Findings weitergereicht und wirkt nur an deren Policygates; es ist kein Kostenbudget. Critical Events läuft hier bewusst ohne Server-Diagnostics- und Event-XML-Ausgabe. |
| Sicherer Einsatz | Defaultmodule mit `@MaxZeilen = 100`; für eine Datenbankfrage Scope explizit setzen. Danach genau ein Spezialmodul aktivieren und dessen Childstatus/Kostenvertrag lesen, statt alle sieben zugleich einzuschalten. |
| Aussagegrenze | Der Default bewertet Plattformzustand, nicht automatisch Workloadgesundheit. Optionale Findings sind abgeleitete Triage und wegen sequenzieller Erhebung nicht atomar; leere Spezialresultate können deaktivierte Quelle, fehlende Rechte oder fehlende Ereignisse bedeuten. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Server-Health-Bereiche sind auffällig und welches Spezialmodul soll als Nächstes laufen?

### Technischer Hintergrund

Wrapper über CPU, NUMA, Memory, TempDB, Config, Trace Flags, Startup, OS und Security. Er verbindet keine atomare Systemaufnahme; Children können verschiedene Rechte/Quellen haben.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in Childmodulen.

### Zeit- und Scope-Modell

Nicht atomare Folge aktueller Konfigurations-/Runtimeabfragen.

### Bewertung und Gegenprobe

Childstatus und Partials zuerst, dann Befunde nach Ressource korrelieren. Triagepriorität statt Gesamtgesundheitsscore.

### Typische Fehlinterpretation

Ein grüner Wrapper beweist keine Lastfreiheit oder Integrität; optionale/gesperrte Children können fehlen.

### Folgeanalyse

Betroffenes Spezialmodul und Current-State-/Historical-Evidenz.

## Primärquellen

- [System Dynamic Management Views](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/system-dynamic-management-views?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../08_Server_Health.md#10-monitorusp_serverhealthanalysis)
