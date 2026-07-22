# [monitor].[USP_ReplicationStatus]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Publikationen, Subscriptions, Agents, Latenz, Backlog und Fehler.<br>
**Beobachtungsart:** verteilter Snapshot + retentionbegrenzte Agenthistorie<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Replikationstopologie und Agentzustände sind lokal sichtbar, und gibt es Fehler oder Rückstand?** Der dokumentierte Zweck ist: Zeigt Publikationen, Subscriptions, Agents, Latenz, Backlog und Fehler. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Verteilte Momentaufnahme plus Distributor-/Agenthistory innerhalb Retention. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ReplicationStatus]
      @MitDistributionDetails = 0,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `databases` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Publikation, Subscription, einen Agent oder eine Distributor-/Backlogmetrik.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Agentstatus, letzte Aktion, Latenz, Pending Commands, Fehler und Trend über mehrere Messungen lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Wachsender Backlog bedeutet, dass Änderungen schneller entstehen als verteilt werden oder ein Agent/Distributor blockiert ist.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Kurzzeitiger Backlog während Lastspitzen ist akzeptabel, wenn er anschließend sichtbar abgebaut wird.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Pending Commands steigen in drei Messungen kontinuierlich und Latenz wächst: systematischer Rückstand. Agentjob, Distributor, Blocking und Netzwerk prüfen.

**Ähnlich aussehender Gegenfall:** Kurzzeitiger Backlog während Lastspitzen ist akzeptabel, wenn er anschließend sichtbar abgebaut wird. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_ReplicationStatus` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Mittel; optionale Distribution-DB-Auswertung.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Lokaler Instanzsnapshot der als Publisher, Subscriber, Merge-Publisher oder Distributor markierten Datenbanken; `@MitDistributionDetails = 0`. |
| Teuerster Pfad | `@MitDistributionDetails = 1`, unbegrenzte Ausgabe und eine große lokale Distribution-Datenbank mit vielen Publikationen, Subscriptions, Agents, History- und Fehlerzeilen. AG-/HADR-Quellen werden nicht gelesen. |
| Haupttreiber | Ohne Details die kleine `sys.databases`-Menge; mit Details Publikationen, Subscriptions und insbesondere Latest-History-Suche je Agent sowie `MSrepl_errors` in der lokal erkannten Distribution-Datenbank. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_ReplicationStatus ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und lokales Katalog-/Distribution-DB-I/O; dynamisches SQL für die erkannte Distribution-Datenbank und temporäre Resultate. Keine Remote-Distributorabfrage. |
| Begrenzungswirkung | `@MaxZeilen` wird getrennt auf Datenbanken, Publikationen, Subscriptions und Fehler angewandt. Es begrenzt nicht als gemeinsames Budget und verhindert die Latest-History-Suche je ausgewählter Subscription nicht sicher. |
| Locking und Nebenwirkungen | Read-only. Zustände ändern sich während der verteilten Erfassung; nicht erreichbare Komponenten liefern partielle Evidenz statt eines konsistenten Gesamtsnapshots. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `ENTERPRISE_TOPOLOGY_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Zuerst ohne Distributiondetails. Den lokalen Distributionpfad nur bei erkannter Distributorrolle, endlichem Limit und `@HighImpactConfirmed = 1` aktivieren; Fehler-/Historytexte als sensible Laufzeitdaten behandeln. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „verteilter Snapshot + retentionbegrenzte Agenthistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Replikationstopologie und Agentzustände sind lokal sichtbar, und gibt es Fehler oder Rückstand?

### Technischer Hintergrund

Transactional Replication nutzt Log Reader und Distribution Agents; Merge Replication eigene Agents/Sessions. Publisher-, Distributor- und Subscriber-Metadaten liegen auf verschiedenen Servern/Datenbanken. History und Commands bilden begrenzte Zustände/Latenz.

### Datenkette

`sys.databases`, `sys.sp_executesql`.

### Source Select

Der leichte Basispfad erkennt nur Datenbanken mit sichtbaren Replication-Rollen:

```sql
SELECT
      [d].[name]
    , [d].[is_published]
    , [d].[is_subscribed]
    , [d].[is_merge_published]
    , [d].[is_distributor]
FROM [sys].[databases] AS [d] WITH (NOLOCK)
WHERE [d].[is_published] = 1
   OR [d].[is_subscribed] = 1
   OR [d].[is_merge_published] = 1
   OR [d].[is_distributor] = 1;
```

**Wichtig für die Eigenlast:** Dieser Katalogfilter ist der sichere Einstieg. Distributionstabellen, Agenthistorien und Fehlerdetails nur für erkannte Rollen und im expliziten Tiefenpfad lesen; dort Datenbank und Zeitfenster weiter einschränken.

### Zeit- und Scope-Modell

Verteilte Momentaufnahme plus Distributor-/Agenthistory innerhalb Retention.

### Bewertung und Gegenprobe

Topologierolle, Agentstatus, letzte Aktion/Fehler, undistributed commands, geschätzte Latenz und Zeitmarken zusammen lesen. Remote-/Distributorzugriff als Partialstatus ausgeben.

### Typische Fehlinterpretation

`Running` bedeutet nur aktiver Agent, nicht geringe Latenz. Lokale Leere kann fehlende Rolle oder fehlenden Remotezugriff bedeuten.

### Folgeanalyse

`USP_DataCaptureDeepAnalysis`, Agent Jobs, Log/Distributor-DB-Kapazität und Replication Monitor.

## Primärquellen

- [SQL Server Replication](https://learn.microsoft.com/en-us/sql/relational-databases/replication/sql-server-replication?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#7-monitorusp_replicationstatus)
