# [monitor].[USP_InfrastructureAnalysis]

**Bereich:** Infrastruktur, Orchestrator<br>
**Zweck:** Orchestriert Agent, Resource Governor, HA, Backup, Log Shipping, Replikation und Data Capture.<br>
**Beobachtungsart:** nicht atomarer Mix aus Konfiguration, Runtime und Historie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Infrastrukturmodule sollen als Triage in einem kontrollierten Lauf zusammengeführt werden?** Der dokumentierte Zweck ist: Orchestriert Agent, Resource Governor, HA, Backup, Log Shipping, Replikation und Data Capture. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Nicht atomare Mischung aus Snapshots und `msdb`-Historien. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InfrastructureAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Tiefenmodule nur bei konkreter Fragestellung aktivieren.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `moduleStatus` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: Dienst, Job, Pool, Replica, Datenbank, Backup, Log-Shipping-Paar, Replikationsobjekt oder Capturefeature.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Childstatus zuerst; nicht verwendete Features von fehlenden Rechten oder Fehlern unterscheiden.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein leeres Child kann „Feature nicht eingesetzt“ oder „Quelle nicht lesbar“ bedeuten. Beide Aussagen sind fachlich verschieden.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Keine AG-Zeilen auf einer Standalone-Instanz sind erwartbar.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Backupchild partiell, AG-Child unavailable feature: Nur der Backupbereich benötigt Nacharbeit. Auffälliges Child gezielt erneut ausführen.

**Ähnlich aussehender Gegenfall:** Keine AG-Zeilen auf einer Standalone-Instanz sind erwartbar. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_InfrastructureAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Acht Children laufen: Agentstatus/-jobs, Resource Governor, Availability Groups, Backup/Recovery, Log Shipping, Replikation und Data Capture. Das ist eine breite Konfigurations-/Statusrunde, kein einzelner „kleiner“ Query. |
| Teuerster Pfad | Zusätzlich Distributiondetails, Backupketten, tiefe Availability-Evidenz und Agent Monitoring. Dieselben `msdb`-, HA- und Datenbankbereiche werden dabei teilweise in mehreren Children aus anderer Perspektive erneut gelesen. |
| Haupttreiber | Größe von `msdb`-Job-/Backup-/Restorehistorie, Zahl der Datenbanken und Captureobjekte, Replikations-/Distributionsmetadaten sowie AG-Replicas und -Datenbanken. Nicht aktivierte Technologien sind meist günstig, müssen aber zunächst erkannt werden. |
| Skalierung | Die Module laufen sequenziell ohne gemeinsamen Snapshot oder gemeinsamen Quellcache. Mehr aktivierte Children addieren ihre Kosten; ein breiter Datenbankscope wird von mehreren Children separat enumeriert. |
| Ressourcen | Vor allem `msdb`-I/O, Server-/HA-DMVs, Datenbankkataloge, CPU für Aggregation und JSON/Ergebnistransfer. Der Orchestrator enthält weder Sampling noch XEL-/Plan-XML-Parsing. |
| Begrenzungswirkung | `@MaxZeilen` wird je Child weitergereicht, aber nicht an `USP_AgentStatus`, dessen Quelle ohnehin konstant klein ist. Historien- und Statuschildren setzen Limits an unterschiedlichen Stellen; ein kleines Parentlimit verhindert deshalb nicht jede `msdb`-Aggregation oder Datenbankenumeration. |
| Locking und Nebenwirkungen | Read-only und sequenziell. Es werden weder Jobs gestartet noch Backup-, HA-, Replikations- oder Capturekonfigurationen geändert; Status kann sich zwischen den Childaufrufen ändern. `LOCK_TIMEOUT 0` am Parent ist keine globale Laufzeitgrenze für Children. |
| Schutzmechanismus | Die drei tieferen Zusatzmodule sind standardmäßig aus; Distributiondetails besitzen einen eigenen Schalter. `@HighImpactConfirmed` wird nur an Children weitergegeben, die ein Policygate auswerten. Er ersetzt weder Datenbankscope noch Historienlimit. |
| Sicherer Einsatz | Eine Datenbank und kleines `@MaxZeilen` wählen, die vier Opt-ins aus lassen und nicht benötigte Standardchildren explizit deaktivieren. Modulstatus vor fachlichen Resultsets lesen. |
| Aussagegrenze | Ein leerer Child kann „Feature nicht genutzt“, „nicht lokal sichtbar“ oder „Berechtigung/Quelle fehlt“ bedeuten. Wegen getrennten Messzeitpunkten dürfen Job-, Backup- und HA-Zustände nicht als atomarer Infrastrukturzustand zusammeninterpretiert werden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Infrastrukturmodule sollen als Triage in einem kontrollierten Lauf zusammengeführt werden?

### Technischer Hintergrund

Der Wrapper orchestriert Agent, Resource Governor, AG, Backup, Log Shipping, Replication und Capture. Nicht konfigurierte Features sollen als Status statt Fehler behandelt werden; Deep Children bleiben opt-in.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in Childmodulen.

### Zeit- und Scope-Modell

Nicht atomare Mischung aus Snapshots und `msdb`-Historien.

### Bewertung und Gegenprobe

Modulstatus zuerst, dann nur konfigurierte/auffällige Komponenten vertiefen. Ein nicht vorhandenes Feature ist normal, sofern der Scope es nicht erwartet.

### Typische Fehlinterpretation

Leere Resultsets dürfen nicht familienübergreifend als gesund zusammengefasst werden; jede Quelle besitzt eigene Retention und Berechtigung.

### Folgeanalyse

Betroffenes Childmodul mit engem Scope.

## Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/en-us/ssms/agent/sql-server-agent?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#12-monitorusp_infrastructureanalysis)
