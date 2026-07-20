# [monitor].[USP_ResourceGovernorAnalysis]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Resource Pools, Workload Groups, Limits und optional zugeordnete Sessions.<br>
**Beobachtungsart:** Konfigurations- und Runtime-Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie klassifiziert und begrenzt Resource Governor Sessions und welche Pools/Groups zeigen Druck oder Abweichungen?** Der dokumentierte Zweck ist: Zeigt Resource Pools, Workload Groups, Limits und optional zugeordnete Sessions. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Config-/Runtimezustand; Counter meist kumulativ seit Aktivierung/Start. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ResourceGovernorAnalysis]
      @MitSessions = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `configuration` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile einen Resource Pool, eine Workload Group oder eine aktuell zugeordnete Session.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Poollimits, Group-Limits, aktuelle Nutzung, Cap-/Min-Werte und Sessionzuordnung gemeinsam betrachten.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

CPU-, Memory- oder Parallelitätslimits können Requests absichtlich drosseln oder Grants begrenzen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Drosselung kann genau das gewünschte Schutzverhalten für andere Workloads sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine Query ist langsam, ihrer Gruppe stehen aber nur 20 % CPU zu: zunächst Policywirkung statt schlechten Plan vermuten. Classifier, Zuordnung und SLA prüfen.

**Ähnlich aussehender Gegenfall:** Drosselung kann genau das gewünschte Schutzverhalten für andere Workloads sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_ResourceGovernorAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Gering bis mittel.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Aktuelle Resource-Governor-Konfiguration und Runtimezustände von Pools/Workload Groups; standardmäßig zusätzlich bis zu 5000 aktuell zugeordnete Sessions. |
| Teuerster Pfad | `@MitSessions = 1` und `@MaxZeilen = 0` auf einer Instanz mit sehr vielen Sessions, Pools und Gruppen. msdb, Datenbankhistory und Cross-Database-Quellen werden nicht gelesen. |
| Haupttreiber | Zahl der Resource Pools/Workload Groups und – im standardmäßig aktiven Sessionspfad – aktuell sichtbarer Sessionzuordnungen. Die Konfigurationsmenge ist klein; viele Sessions dominieren Materialisierung und Transfer. |
| Skalierung | Pool-/Gruppenkonfiguration ist klein; der optionale Sessionpfad wächst mit aktiven Sessions und deren Gruppenzuordnung. |
| Ressourcen | Geringe bis mittlere CPU-/Speicherlast auf Resource-Governor-Katalogen/-DMVs und optional `sys.dm_exec_sessions`; kein History- oder Benutzerdatenscan. |
| Begrenzungswirkung | `@MitSessions = 0` lässt den größten variablen Pfad aus. `@MaxZeilen` wird je ausgegebenem Konfigurations-/Runtime-/Sessionresultset angewandt und ist keine gemeinsame Gesamtgrenze. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Kein High-Impact-Gate. `@MitSessions = 0` ist der wirksame Opt-out für den einzigen großen variablen Pfad; `@MaxZeilen` begrenzt die Resultsets separat. Der Default aktiviert Sessions allerdings, daher ist für reine Konfigurationsfragen ein explizites Abschalten sinnvoll. |
| Sicherer Einsatz | Zuerst `@MitSessions = 0` für Konfiguration/Runtime; Sessions nur bei einer konkreten Pool-/Gruppenfrage mit endlichem Limit ergänzen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurations- und Runtime-Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie klassifiziert und begrenzt Resource Governor Sessions und welche Pools/Groups zeigen Druck oder Abweichungen?

### Technischer Hintergrund

Classifier Function ordnet neue Sessions Workload Groups zu; Groups verweisen auf Resource Pools. Katalogsichten enthalten konfigurierte Werte, Runtime-DMVs `value_in_use` und Counter. CPU Caps, Min/Max Memory, Grant Percentage, Request Limits und External Pools wirken auf unterschiedliche Ressourcen.

### Datenkette

`master.sys.objects`, `master.sys.schemas`, `sys.dm_exec_sessions`, `sys.dm_resource_governor_configuration`, `sys.dm_resource_governor_resource_pools`, `sys.dm_resource_governor_workload_groups`, `sys.resource_governor_configuration`, `sys.resource_governor_resource_pools`, `sys.resource_governor_workload_groups`.

### Zeit- und Scope-Modell

Aktueller Config-/Runtimezustand; Counter meist kumulativ seit Aktivierung/Start. Bereits verbundene Sessions werden durch Classifieränderung nicht automatisch neu klassifiziert.

### Bewertung und Gegenprobe

Configured vs runtime, Pool/Group-Zuordnung, aktive Requests, Queues, CPU/Memory/Grantlimits und Default/Internal-Kontext lesen. Throttling kann absichtlich sein.

### Typische Fehlinterpretation

Eine Query in einer Group beweist nicht, dass der Classifier aktuell dieselbe Entscheidung für neue Logins treffen würde. Limits sind nicht alle harte Reservierungen.

### Folgeanalyse

Current Requests/Memory Grants, Configuration und reproduzierbarer Login-/Classifiertest.

## Primärquellen

- [Resource Governor](https://learn.microsoft.com/en-us/sql/relational-databases/resource-governor/resource-governor?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#3-monitorusp_resourcegovernoranalysis)
