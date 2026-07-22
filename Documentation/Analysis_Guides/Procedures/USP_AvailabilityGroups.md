# [monitor].[USP_AvailabilityGroups]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Availability-Group-, Replica-, Datenbank- und Routingzustand.<br>
**Beobachtungsart:** verteilter, nicht atomarer Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche AG-Replicas und Availability Databases sind verbunden, synchronisiert und mit welchen Send-/Redoqueues?** Der dokumentierte Zweck ist: Zeigt Availability-Group-, Replica-, Datenbank- und Routingzustand. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller lokaler Snapshot; Ratewerte können intern über begrenzte Intervalle berechnet werden und schwanken. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AvailabilityGroups]
      @MitRouting = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `replicas` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine AG, Replica, Availability Database oder Routingkonfiguration.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Replica-Rolle, Connected State, Synchronization State, Health, Availability Mode, Failover Mode und Routing gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Disconnected oder not synchronizing kann RPO-/Failoverrisiko erhöhen; fehlerhaftes Routing kann Read-Only-Workload falsch lenken.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Asynchrone Replicas dürfen Lag besitzen. Entscheidend sind vereinbartes RPO, Trend und geplanter Einsatzzweck.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 30 Sekunden Lag bei asynchroner DR-Replica kann policykonform sein; vor synchronem Failover ist derselbe Zustand kritisch. Danach `USP_AvailabilityDeepAnalysis` verwenden.

**Ähnlich aussehender Gegenfall:** Asynchrone Replicas dürfen Lag besitzen. Entscheidend sind vereinbartes RPO, Trend und geplanter Einsatzzweck. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Eine leere AG-/Replica-Sicht kann bedeuten, dass Always On nicht konfiguriert ist, der lokale Knoten keine sichtbare Replica besitzt oder Berechtigung beziehungsweise Rolle einzelne Runtime-DMVs ausblendet. Deshalb zuerst Katalog- und Quellenstatus unterscheiden.

Für `USP_AvailabilityGroups` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Mittel; reine HADR-Katalog- und DMV-Auswertung.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Lokaler HADR-Katalog-/DMV-Snapshot mit Standardlimit; Routingdetails nur soweit konfiguriert und angefordert. |
| Teuerster Pfad | Unbegrenzte RAW-Ausgabe aller AGs, Replicas, Datenbanken, Listener und Routinglisten auf einer großen Instanz. |
| Haupttreiber | Anzahl lokaler AGs, Replicas, Availability-Datenbanken, Listener/IPs und – falls angefordert – Routinglisteneinträge. Es gibt keinen AG-/Datenbankfilter; `@MaxZeilen` reduziert erst die einzelnen Resultsets. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_AvailabilityGroups ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | Geringe bis mittlere CPU für lokale HADR-Kataloge/DMVs und Zusammenführung; kein Remotequery und kein Nutzdaten- oder Logscan. |
| Begrenzungswirkung | MaxZeilen begrenzt die einzelnen Ausgaben, nicht die davor gelesenen HADR-Katalog-/DMV-Zeilen und nicht die zeitliche Nicht-Atomarität. |
| Locking und Nebenwirkungen | Read-only. Zustände ändern sich während der verteilten Erfassung; nicht erreichbare Komponenten liefern partielle Evidenz statt eines konsistenten Gesamtsnapshots. |
| Schutzmechanismus | Kein High-Impact-Gate und kein AG-/Datenbankfilter. `@MitRouting = 0` lässt Routingdetails aus, und `@MaxZeilen` begrenzt die einzelnen Ausgaben; die lokalen HADR-Kataloge/DMVs werden davor dennoch instanzweit gelesen. |
| Sicherer Einsatz | CONSOLE mit Standardlimit; lokale Rolle und Erfassungszeit notieren, anschließend nur die betroffene ExampleAG beziehungsweise ExampleDb korrelieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „verteilter, nicht atomarer Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche AG-Replicas und Availability Databases sind verbunden, synchronisiert und mit welchen Send-/Redoqueues?

### Technischer Hintergrund

Primär erzeugt Log Records, sendet Logblöcke an Secondaries, diese harden und redoen. Synchroner Commit wartet je Konfiguration auf Bestätigung. Replica-/Database-DMVs liefern Role, Connection, Synchronization State/Health, Send/Redo Queue, Rate und Last Hardened/Redone.

### Datenkette

`sys.availability_group_listener_ip_addresses`, `sys.availability_group_listeners`, `sys.availability_groups`, `sys.availability_read_only_routing_lists`, `sys.availability_replicas`, `sys.dm_hadr_`, `sys.dm_hadr_availability_replica_states`, `sys.dm_hadr_database_replica_states`, `sys.fn_hadr_is_primary_replica`.

### Source Select

Die wesentliche Beziehung verbindet AG-Konfiguration, Replikate und deren aktuellen Laufzeitzustand:

```sql
SELECT
      [ag].[name] AS [AvailabilityGroupName]
    , [ar].[replica_server_name]
    , [ar].[availability_mode_desc]
    , [ar].[failover_mode_desc]
    , [ars].[role_desc]
    , [ars].[connected_state_desc]
FROM [sys].[availability_groups] AS [ag] WITH (NOLOCK)
JOIN [sys].[availability_replicas] AS [ar] WITH (NOLOCK)
  ON [ar].[group_id] = [ag].[group_id]
LEFT JOIN [sys].[dm_hadr_availability_replica_states] AS [ars] WITH (NOLOCK)
  ON [ars].[replica_id] = [ar].[replica_id]
WHERE [ag].[name] = N'ExampleAvailabilityGroup';
```

**Wichtig für die Eigenlast:** Der AG-Name ist der wirksamste frühe Scope. Listener, IP-Adressen, Routinglisten und Datenbankzustände werden erst für die verbleibenden Gruppen ergänzt.

### Zeit- und Scope-Modell

Aktueller lokaler Snapshot; Ratewerte können intern über begrenzte Intervalle berechnet werden und schwanken.

### Bewertung und Gegenprobe

Role, Availability Mode, Failover Mode, Connected State, Sync State, Queue MB, Rate und Zeitmarken kombinieren. Queue/Rate liefert eine grobe Abarbeitungszeit nur bei stabiler Rate.

### Typische Fehlinterpretation

`SYNCHRONIZED` bedeutet nicht null Latenz oder lesbare Secondary. Queuegröße allein ohne Trend und Workloadrate ist keine Prognose.

### Folgeanalyse

`USP_AvailabilityDeepAnalysis`, Current Log/I/O und externe Cluster-/Netzwerktelemetrie.

## Primärquellen

- [Always On Availability Groups](https://learn.microsoft.com/en-us/sql/database-engine/availability-groups/windows/overview-of-always-on-availability-groups-sql-server?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#4-monitorusp_availabilitygroups)
