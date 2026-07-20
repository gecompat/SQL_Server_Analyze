# [monitor].[USP_DataCaptureDeepAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Bewertet Change-Tracking-Versionen, CDC-Capture/Cleanup und lokal erreichbare Replikationsmetadaten, ohne Nutzdaten, Change-Zeilen, Replikationsbefehle oder Konfiguration zu verändern.<br>
**Beobachtungsart:** Snapshot + retentionbegrenzte Metadatenhistorie<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Sind CDC, Change Tracking oder Replication nicht nur aktiviert, sondern innerhalb Retention, LSN-/Versiongrenzen und Agentdurchsatz nutzbar?** Der dokumentierte Zweck ist: Bewertet Change-Tracking-Versionen, CDC-Capture/Cleanup und lokal erreichbare Replikationsmetadaten, ohne Nutzdaten, Change-Zeilen, Replikationsbefehle oder Konfiguration zu verändern. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das Spezialfeature vorhanden und in einem auffälligen Zustand ist und welches featureeigene Diagnoseverfahren als Nächstes gebraucht wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Enablement-/Job-/Session-/LSN-/Versionstand plus begrenzte Historie. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DataCaptureDeepAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Einen Change-Tracking-Consumer nur mit seinem echten, zuletzt bestätigten Wasserstand prüfen:

```sql
EXEC [monitor].[USP_DataCaptureDeepAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ChangeTrackingClientVersion = 100,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'RAW';
```

Der Zahlenwert ist synthetisch. Der Parameter ist datenbankspezifisch und erzwingt genau eine ausgewählte Datenbank. Wasserstände verschiedener Consumer dürfen fachlich nicht vermischt werden.

Beide fachlichen Pfade sind als `CATALOG_DEEP` klassifiziert. Die Bestätigung erfüllt das Gruppengate, ersetzt aber weder den Einzeldatenbank-Scope noch einen fachlich verifizierten Consumer-Wasserstand.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Datenbankstatus, isolierten Quellenstatus, Finding, einer Change-Tracking-Tabelle, CDC-Capture-Instanz, CDC-Scan-Sitzung, aggregierten CDC-Fehlergruppe, CDC-Jobkonfiguration, lokal sichtbaren Replikationsagenten oder aggregierten Replikationsfehlergruppe.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst `StatusCode`, `IsPartial` und `SourceStatus` prüfen. Danach die drei Funktionsfamilien getrennt lesen:

- Change Tracking: `ClientVersion` pro Consumer gegen `MinValidVersion` und `CurrentVersion`.
- CDC: Capture-Instanzen, Jobs, aggregierte Scan-Latenz und Fehler gemeinsam.
- Replikation: Agentstatus, lokaler Rückstand, Latenz und Fehler im selben Zeitfenster.

`REPLICATION_TOPOLOGY_NOT_LOCALLY_OBSERVABLE` ist eine Evidenzlücke. Sie darf nie als gesunder Replikationszustand interpretiert werden.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein CT-Wasserstand unter `MinValidVersion` kann nicht mehr vollständig inkrementell enumeriert werden. Fehlende oder deaktivierte CDC-Jobs, wiederholte Scanfehler oder anhaltende Capture-Latenz können die Datenbereitstellung verzögern. Hohe undistributed-command-Zahlen, Retry/Fail-Agentstatus und lokale Replikationsfehler können auf einen Zustellrückstand hinweisen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ohne echten CT-Consumer-Wasserstand ist kein Synchronisationsverlust beweisbar. CDC mit nicht kontinuierlichem Capture kann zwischen geplanten Läufen erwartbar hohe Latenz zeigen. Ein Replikationsagent im Zustand `Idle` ist ohne Rückstand kein Fehler. Einzelne DMV- oder History-Zeilen sind keine lückenlose Zeitreihe.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein CT-Wasserstand unter `MinValidVersion` kann nicht mehr vollständig inkrementell enumeriert werden. Fehlende oder deaktivierte CDC-Jobs, wiederholte Scanfehler oder anhaltende Capture-Latenz können die Datenbereitstellung verzögern. Hohe undistributed-command-Zahlen, Retry/Fail-Agentstatus und lokale Replikationsfehler können auf einen Zustellrückstand hinweisen.

**Ähnlich aussehender Gegenfall:** Ohne echten CT-Consumer-Wasserstand ist kein Synchronisationsverlust beweisbar. CDC mit nicht kontinuierlichem Capture kann zwischen geplanten Läufen erwartbar hohe Latenz zeigen. Ein Replikationsagent im Zustand `Idle` ist ohne Rückstand kein Fehler. Einzelne DMV- oder History-Zeilen sind keine lückenlose Zeitreihe. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_DataCaptureDeepAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Eine leere CDC-Scan-DMV kann nach Neustart/Failover oder auf einer AG-Sekundärreplik auftreten. Alle in `msdb` sichtbaren lokalen Distributionsdatenbanken werden getrennt gelesen und in Agent- und Fehlerzeilen ausgewiesen; lokale Distributionstabellen zeigen dennoch keinen Remote Distributor. Fehlende Rechte werden pro Quelle als `AVAILABLE_LIMITED` erhalten; zugängliche andere Evidenz bleibt gültig.

## Eigenlast und Grenzen

MEDIUM: sichtbare Kataloge, kleine CDC-DMVs, msdb-Jobmetadaten und aggregierte lokale Distributionstabellen. Das Modul liest keine `CHANGETABLE`-Ergebnisse, CDC-Change-Table-Zeilen, Replikationscommands, Kommentare, Fehlertexte, LSNs, Credentials oder Agentjob-Commands. Runtime-Namen bleiben für die Diagnose vollständig sichtbar, dürfen aber nicht in Repository- oder Downloadartefakte übernommen werden.

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, `@NurProblematisch = 1`, 24 Stunden Fehlerlookback und endliches Limit. Change-Tracking-Verlust wird nur bewertet, wenn ein echter Consumer-Wasserstand explizit übergeben wurde. |
| Teuerster Pfad | Alle sichtbaren Datenbanken ohne Objektfilter, sehr langer Fehlerlookback und unbegrenzte Ausgabe; zusätzlich große lokale CDC-/msdb- und Distributionsmetadatenbestände mit vielen Agents und Fehlergruppen. |
| Haupttreiber | Zahl gewählter Datenbanken, Change-Tracking-Tabellen, CDC-Capture-Instanzen/-Jobs und lokal sichtbarer Replikationsobjekte plus deren msdb-Jobhistory im Lookback. Change-Zeilen und Replikationsbefehle werden nicht gelesen. |
| Skalierung | Katalogpfade wachsen mit Datenbanken und erfassten Tabellen; CDC-/Replikationspfade zusätzlich mit Scan-Sessions, Fehlergruppen, Jobs und lokal erreichbaren Agentmetadaten im Lookback. |
| Ressourcen | CPU und Katalog-/msdb-/lokales Distribution-DB-I/O, dynamisches SQL je Datenbank sowie TempDB/Arbeitsspeicher für isolierte Quelltabellen, Aggregation und Findings. |
| Begrenzungswirkung | Datenbank- und Objektfilter begrenzen lokale Katalogarbeit. `@ErrorLookbackHours` begrenzt Fehlerhistorie. `@MaxZeilen` wird erst beim Ausgeben jedes Resultsets angewandt und begrenzt die vorherige Quellenlesung und Findingerzeugung nicht. |
| Locking und Nebenwirkungen | Read-only; keine Change-Table-Zeilen, Replikationscommands oder Agentbefehle werden gelesen. Katalog-, msdb- und lokale Distribution-DB-Zugriffe können mit Cleanup/Agentaktivität zeitlich überlappen; die Teilquellen sind nicht atomar. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleDatabase`, Problemscope und kurzer Lookback. Einen Consumer-Wasserstand nur datenbankspezifisch und fachlich verifiziert übergeben; danach Quellenstatus vor Findings lesen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + retentionbegrenzte Metadatenhistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Sind CDC, Change Tracking oder Replication nicht nur aktiviert, sondern innerhalb Retention, LSN-/Versiongrenzen und Agentdurchsatz nutzbar?

### Technischer Hintergrund

CDC Capture liest das Transaktionslog in Change Tables; Cleanup verschiebt `min_lsn`. Consumer müssen ihren LSN-Checkpoint vor Cleanup verarbeiten. Change Tracking speichert Versionsmarken; `CHANGE_TRACKING_MIN_VALID_VERSION` bestimmt, ob ein Consumer reinitialisieren muss. Replication nutzt Logreader/Distributoragenten und eigene History.

### Datenkette

`msdb.dbo.agent_datetime`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `sys.change_tracking_databases`, `sys.change_tracking_tables`, `sys.databases`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`, `cdc.change_tables`, `msdb.dbo.cdc_jobs`, `msdb.dbo.MSdistributiondbs`, `distribution.dbo.MSdistribution_agents`, `distribution.dbo.MSdistribution_history`, `distribution.dbo.MSdistribution_status`, `distribution.dbo.MSsubscriptions`, `distribution.dbo.MSlogreader_agents`, `distribution.dbo.MSlogreader_history`, `distribution.dbo.MSmerge_agents`, `distribution.dbo.MSmerge_sessions`, `distribution.dbo.MSrepl_errors`, `sys.dm_cdc_errors`, `sys.dm_cdc_log_scan_sessions`, `sys.fn_cdc_get_min_lsn`, `sys.fn_cdc_map_lsn_to_time`, `CHANGE_TRACKING_CURRENT_VERSION`, `CHANGE_TRACKING_MIN_VALID_VERSION`.

### Zeit- und Scope-Modell

Aktueller Enablement-/Job-/Session-/LSN-/Versionstand plus begrenzte Historie.

### Bewertung und Gegenprobe

Capture Instance, Start/End LSN, Min/Max, Consumercheckpoint, Cleanup Retention, Log Scan Sessions/Errors, Change Tracking Current/Min Valid Version und Replicationagenten korrelieren. Lag als Abstand und Zeit bewerten.

### Typische Fehlinterpretation

Enabled und laufender Job beweisen keine lückenlose Konsumierbarkeit. Wenn Consumercheckpoint älter als Min Valid/Min LSN ist, helfen weitere Reads nicht; Reinitialisierungsstrategie nötig.

### Folgeanalyse

Agent Monitoring, Replication, Log/Capacity und Consumerstatus.

## Primärquellen

- [Change Data Capture](https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-data-capture-sql-server?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#7-monitorusp_datacapturedeepanalysis)
