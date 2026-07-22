# [monitor].[USP_AgentStatus]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Plattformunterstützung, Dienststatus und SQL-Agent-Konfiguration.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Ist SQL Server Agent auf dieser Plattform vorhanden und läuft der Dienst?** Der dokumentierte Zweck ist: Zeigt Plattformunterstützung, Dienststatus und SQL-Agent-Konfiguration. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Servicezustand; bei Restart/Failover kann der Status wechseln. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentStatus]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `agentStatus` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile einen Dienst-, Plattform- oder Konfigurationsaspekt des SQL Agents.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Plattformunterstützung, Dienststatus, Startmodus und Agentkonfiguration unterscheiden.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein gestoppter Agent verhindert geplante Backups, Wartung, ETL und Alerts.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Auf Plattformen ohne klassischen SQL Agent oder bei bewusst externem Scheduling ist Nichtverfügbarkeit erwartbar.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Agent gestoppt auf einer Instanz mit geplanten Logbackups: kritisch. Auf einer agentlosen Plattform: alternativen Scheduler dokumentieren. Danach Jobs und Monitoringpfad prüfen.

**Ähnlich aussehender Gegenfall:** Auf Plattformen ohne klassischen SQL Agent oder bei bewusst externem Scheduling ist Nichtverfügbarkeit erwartbar. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_AgentStatus` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Gering.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Ein kleiner Instanzsnapshot aus Agent-Dienstzeile, letzter Agent-Session und zwei Jobzählungen. Die Procedure besitzt keine Scope-, History- oder Zeilenparameter. |
| Teuerster Pfad | Praktisch derselbe feste Pfad auf einer Instanz mit sehr vielen Jobs; nur die beiden `COUNT(*)`-Abfragen über `msdb.dbo.sysjobs` wachsen mit der Jobzahl. |
| Haupttreiber | Praktisch nur die Zahl der Zeilen in `msdb.dbo.sysjobs`, weil sie zweimal aggregiert wird. Dienststatus und letzte Agent-Session sind fest auf eine beziehungsweise `TOP (1)` Zeile begrenzt. |
| Skalierung | Nahezu konstant; lediglich die Jobzählungen wachsen mit `sysjobs`. Es werden keine Jobhistory, Steps oder Meldungstexte gelesen. |
| Ressourcen | Sehr geringe CPU-/Katalog-/msdb-I/O-Last und eine schmale Ergebniszeile; kein relevanter TempDB- oder Transferbedarf. |
| Begrenzungswirkung | Nicht anwendbar: Der Pfad ist bereits auf einen Dienstsnapshot, `TOP (1)` Agent-Session und aggregierte Jobzahlen fest begrenzt. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Kein Gate und kein Aufruferlimit. Der Schutz ist konstruktiv: genau eine Dienstzeile, `TOP (1)` für die letzte Agent-Session und zwei reine Jobzählungen; weder Jobsteps noch frei wählbare History werden gelesen. |
| Sicherer Einsatz | Der Default-CONSOLE-Aufruf ist der kleinste fachliche Pfad und kann ohne zusätzliche Scopewahl verwendet werden. |
| Aussagegrenze | Der Snapshot sagt nur, ob Agent unterstützt/erkannt ist, welcher Dienstzustand sichtbar ist und wie viele Jobs aktiviert beziehungsweise deaktiviert sind. Er zeigt weder einzelne Jobprobleme noch Steps, letzte Ausgänge, Laufdauer oder einen Historyzeitraum. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist SQL Server Agent auf dieser Plattform vorhanden und läuft der Dienst?

### Technischer Hintergrund

Agent führt Jobs über einen separaten Dienst und `msdb`-Metadaten aus. Dienstzustand, Startmodus und Plattformverfügbarkeit sind Voraussetzungen, aber noch keine Aussage über Scheduler, Jobowner, Proxies oder einzelne Jobs.

### Datenkette

`msdb.dbo.sysjobs`, `msdb.dbo.syssessions`, `sys.dm_server_services`.

### Source Select

Der Status entsteht aus dem sichtbaren Agent-Dienst und der letzten Agent-Session in `msdb`:

```sql
SELECT
      [svc].[servicename]
    , [svc].[status_desc]
    , [agent].[session_id]
    , [agent].[agent_start_date]
FROM [sys].[dm_server_services] AS [svc] WITH (NOLOCK)
OUTER APPLY
(
    SELECT TOP (1)
          [ss].[session_id]
        , [ss].[agent_start_date]
    FROM [msdb].[dbo].[syssessions] AS [ss] WITH (NOLOCK)
    ORDER BY [ss].[agent_start_date] DESC
) AS [agent]
WHERE [svc].[servicename] LIKE N'SQL Server Agent%';
```

**Wichtig für die Eigenlast:** Die Quellen sind klein. Der Dienstfilter verhindert, dass nicht benötigte SQL-Dienste in die weitere Auswertung gelangen.

### Zeit- und Scope-Modell

Aktueller Servicezustand; bei Restart/Failover kann der Status wechseln.

### Bewertung und Gegenprobe

Dienst vorhanden/läuft, Edition/Plattform, Startmodus und Agent-XPs/Erreichbarkeit gemeinsam lesen. Ein bewusst deaktivierter Agent kann in containerisierten oder extern orchestrierten Umgebungen normal sein.

### Typische Fehlinterpretation

`Running` beweist weder aktive Schedules noch erfolgreiche Jobs. Ein gestoppter Agent erklärt fehlende Ausführungen, aber nicht deren ursprüngliche Ursache.

### Folgeanalyse

`USP_AgentJobs` und `USP_AgentMonitoringAnalysis`.

## Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/en-us/ssms/agent/sql-server-agent?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#1-monitorusp_agentstatus)
