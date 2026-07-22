# [monitor].[USP_AvailabilityDeepAnalysis]

**Bereich:** Infrastruktur<br>
**Zweck:** Vertieft Availability Groups mit Send-/Redo-Queues, Lag, Cluster- und Replica-Evidenz.<br>
**Beobachtungsart:** verteilter, nicht atomarer Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Warum ist eine AG/Replica nicht gesund, welche Datenbewegungsstufe staut und welche Risiken entstehen?** Der dokumentierte Zweck ist: Vertieft Availability Groups mit Send-/Redo-Queues, Lag, Cluster- und Replica-Evidenz. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller verteilungsabhängiger Snapshot; einige Daten nur auf Primary oder lokalem Replica verfügbar. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AvailabilityDeepAnalysis]
      @MitClusterNetzwerken = 0,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `replicas` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Replica-/Datenbank-Beziehung, Queue-/Lagmetrik, Clusterkomponente oder ein Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Send Queue, Redo Queue, geschätzte Lagzeit, Synchronisierungszustand, Rolle und Trend gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Wachsende Send Queue weist eher auf Transport/Primary hin; wachsende Redo Queue auf Secondary-Redo, I/O oder CPU.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein kurzer Peak nach großer Transaktion kann sich normal abbauen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Send Queue stabil klein, Redo Queue wächst über mehrere Messungen: Fokus auf Secondary-I/O/CPU/Redo statt Netzwerk. Counter, Storage und Cluster prüfen.

**Ähnlich aussehender Gegenfall:** Ein kurzer Peak nach großer Transaktion kann sich normal abbauen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Eine leere Deep-Sicht kann bedeuten, dass keine AG konfiguriert ist oder dass lokale Rolle, Plattform, Version beziehungsweise Berechtigung Cluster-, Seeding- oder Reparatur-DMVs nicht verfügbar machen. SourceStatus und Partialität sind deshalb Teil des Ergebnisses.

Für `USP_AvailabilityDeepAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Lokaler HADR-/Clustersnapshot mit `@MitClusterNetzwerken = 0` und Standardlimit. |
| Teuerster Pfad | Unbegrenzte RAW-Ausgabe mit Cluster-Netzwerken über viele AGs, Replicas, Datenbanken, Seeding- und Page-Repair-Zeilen. |
| Haupttreiber | Zahl lokaler AGs, Replicas und Availability-Datenbanken sowie Seeding-, Auto-Page-Repair-, Cluster- und optional Netzwerkzeilen. Ohne AG-/Datenbankfilter wird dieser lokale Gesamtbestand vor den Resultsetlimits erhoben. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_AvailabilityDeepAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | Geringe bis mittlere CPU für lokale HADR-/Cluster-DMVs und Temp-Tabellen; kein Remotequery, Nutzdaten-, Log- oder Storage-Scan. |
| Begrenzungswirkung | MaxZeilen begrenzt Resultsets, aber nicht zwingend alle vorab gelesenen HADR-/Clusterzeilen und nie die zeitliche Nicht-Atomarität der Teilquellen. |
| Locking und Nebenwirkungen | Read-only. Zustände ändern sich während der verteilten Erfassung; nicht erreichbare Komponenten liefern partielle Evidenz statt eines konsistenten Gesamtsnapshots. |
| Schutzmechanismus | Kein High-Impact-Gate. `@MitClusterNetzwerken = 0` lässt die optionale Netzwerksicht aus, Schwellen priorisieren Findings und `@MaxZeilen` begrenzt jedes Resultset. Da weder Datenbank- noch AG-Filter existieren, schützt das Limit nicht vor dem vollständigen lokalen HADR-/Cluster-Snapshot. |
| Sicherer Einsatz | Mit `@MitClusterNetzwerken = 0` und Standardlimit beginnen; lokale Rolle dokumentieren und Netzwerkdetails nur bei passender Clusterhypothese aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „verteilter, nicht atomarer Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Warum ist eine AG/Replica nicht gesund, welche Datenbewegungsstufe staut und welche Risiken entstehen?

### Technischer Hintergrund

Vertiefung kombiniert Cluster-/Replica-/Databasezustand, Send/Redo, Flow Control, Suspend Reason, Seeding, Page Repair und gegebenenfalls Read-only Routing. Logproduktion, Capture, Send, Harden und Redo sind getrennte Pipelineabschnitte.

### Datenkette

`sys.availability_groups`, `sys.availability_replicas`, `sys.dm_hadr_auto_page_repair`, `sys.dm_hadr_availability_replica_states`, `sys.dm_hadr_cluster`, `sys.dm_hadr_cluster_members`, `sys.dm_hadr_cluster_networks`, `sys.dm_hadr_database_replica_states`, `sys.dm_hadr_physical_seeding_stats`.

### Source Select

Das Grundselect zeigt die zentrale AG-Kette von Gruppe über Replikat bis zur lokalen Datenbank-Replikatzustandszeile:

```sql
SELECT
      [ag].[name] AS [AvailabilityGroupName]
    , [ar].[replica_server_name]
    , [ars].[role_desc]
    , [d].[name] AS [DatabaseName]
    , [drs].[synchronization_state_desc]
    , [drs].[log_send_queue_size]
    , [drs].[redo_queue_size]
FROM [sys].[availability_groups] AS [ag] WITH (NOLOCK)
JOIN [sys].[availability_replicas] AS [ar] WITH (NOLOCK)
  ON [ar].[group_id] = [ag].[group_id]
LEFT JOIN [sys].[dm_hadr_availability_replica_states] AS [ars] WITH (NOLOCK)
  ON [ars].[replica_id] = [ar].[replica_id]
LEFT JOIN [sys].[dm_hadr_database_replica_states] AS [drs] WITH (NOLOCK)
  ON [drs].[group_id] = [ag].[group_id]
 AND [drs].[replica_id] = [ar].[replica_id]
LEFT JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id] = [drs].[database_id]
WHERE [ag].[name] = N'ExampleAvailabilityGroup';
```

**Wichtig für die Eigenlast:** Gruppe oder Datenbank vor Physical-Seeding- und Auto-Page-Repair-Historie eingrenzen. Die synthetische Gruppe `ExampleAvailabilityGroup` ist nur ein Platzhalter.

### Zeit- und Scope-Modell

Aktueller verteilungsabhängiger Snapshot; einige Daten nur auf Primary oder lokalem Replica verfügbar.

### Bewertung und Gegenprobe

Pipeline lokalisieren: Log Send Queue vs Redo Queue, Rate/Trend, Connected/Suspended, Last Hardened/Redone, Sync Commit Waits, Disk-/Networkkontext. Partialvisibility explizit halten.

### Typische Fehlinterpretation

Estimated catch-up time aus Queue/aktueller Rate ist bei Rateänderung instabil. `NOT_HEALTHY` ist Folge, nicht Root Cause.

### Folgeanalyse

Current Log/I/O/Waits, Clusterlog, OS-/Netzwerktelemetrie.

## Primärquellen

- [Always On Availability Groups](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/monitor-availability-groups-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#10-monitorusp_availabilitydeepanalysis)
