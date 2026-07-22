# [monitor].[USP_CurrentWaits]

**Bereich:** Current State<br>
**Zweck:** Zeigt aktuelle oder kurz gesampelte Waits und ordnet sie Waitgruppen zu.<br>
**Beobachtungsart:** Snapshot + kumulativ + optionale Stichprobe<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Auf welche Ressourcen oder Ereignisse warten Tasks aktuell, und welche Waits dominierten Instanz oder Sample?** Der dokumentierte Zweck ist: Zeigt aktuelle oder kurz gesampelte Waits und ordnet sie Waitgruppen zu. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Ihr Zeitvertrag lautet ausdrücklich: Tasksnapshot plus kumulativer Kontext oder gültiges Sampledelta. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentWaits]
      @SampleSeconds = 5,
      @MitSqlText = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Das Sample betrifft die instanzweiten Wait-Statistiken; aktuelle wartende Tasks
werden einmalig als Snapshot gelesen. SQL-Text anschließend nur für konkrete
Sessions zuschalten.

Erkannte Tool-Hintergrundtasks sind im Default ausgeblendet und werden mit
`@ToolHintergrundabfragenEinbeziehen = 1` samt Klassifikation sichtbar. Der
Schalter betrifft nur aktuelle Tasks; instanzweite Wait-Stats lassen sich nicht
nach Client aufteilen.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `currentTasks` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile einen sichtbaren Wait beziehungsweise eine Aggregation nach Session, Request, Waittyp oder Gruppe. Im Samplemodus ist das Delta maßgeblich.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Waittyp und Waitgruppe mit Dauer, Anzahl, Session, Request und Samplemodus lesen. Gesamtzeit und Wiederholung vor Einzelspitzen priorisieren. Für die vertiefte Einordnung `TVF_WaitTypeInfo` und für die aussagebezogenen Belege `TVF_WaitTypeSources` verwenden.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein dominanter Wait zeigt, wo Zeit verloren geht. Relevant wird er durch hohe Gesamtdauer, Wiederholung und konkrete Workloadauswirkung.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Viele Waits sind normale Hintergrund- oder Koordinationszustände. Parallelitätswaits allein beweisen keine falsche MAXDOP-Konfiguration.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein einzelner `PAGEIOLATCH_SH` über 20 ms beweist kein Storageproblem. Viele solche Waits plus hohe Datei-Latenz und langsame Requests bilden dagegen eine belastbare I/O-Spur. Danach `USP_CurrentIO` verwenden.

**Ähnlich aussehender Gegenfall:** Viele Waits sind normale Hintergrund- oder Koordinationszustände. Parallelitätswaits allein beweisen keine falsche MAXDOP-Konfiguration. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentWaits` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Default `@SampleSeconds = 0`: ein Snapshot aktueller wartender Tasks plus kumulative `sys.dm_os_wait_stats` seit SQL-Server-Start. SQL-Text ist standardmäßig an. |
| Teuerster Pfad | 60-Sekunden-Delta, SQL-Text ohne Zeichenlimit, Regexfilter und `@MaxZeilen = 0`. Regex wird spät angewandt und hebt das frühe Kandidatenlimit für Tasks auf; mehrere parallele Sampler belegen mehrere Sessions. |
| Haupttreiber | Zahl aktuell wartender Tasks/Requests und SQL-Textbreite; die instanzweite Waittypmenge ist vergleichsweise klein. Für ein Delta wird `sys.dm_os_wait_stats` zweimal gelesen, aktuelle Tasks aber nur einmal. |
| Skalierung | Taskarbeit wächst mit aktiven Waitern und optionalem Textzugriff. Instanzwaits werden nach Waittyp aggregiert und prozentual eingeordnet; Sampledauer erhöht vor allem Verbindungszeit, nicht die Zeilenzahl. |
| Ressourcen | Joins auf `sys.dm_os_waiting_tasks`, Requests/Sessions und optional `sys.dm_exec_sql_text`; ein oder zwei Wait-Stats-Snapshots, Temp-Tabellen und bei Sampling WAITFOR. |
| Begrenzungswirkung | Für Tasks gilt bei einfachen Filtern ein N+1-Kandidatenlimit; Regex oder unbegrenzte Ausgabe materialisiert alle sichtbaren Kandidaten und löscht erst danach. Instanzwaits werden vollständig aggregiert und erst anschließend auf `@MaxZeilen` gekürzt. Das Limit verkürzt das WAITFOR nicht. |
| Locking und Nebenwirkungen | Read-only. WAITFOR hält nur die aufrufende Verbindung; die Procedure hält keine Nutzdatenlocks über das Intervall. Ein Engine-Restart zwischen Wait-Stats-Snapshots verwirft das Delta. |
| Schutzmechanismus | Kein High-Impact-Gate. `@SampleSeconds` ist auf 60 begrenzt; Session-/Waitfilter, `@MaxZeilen`, `@MaxSqlTextZeichen` und `@MitSqlText = 0` begrenzen Kandidaten beziehungsweise Breite. Regex hebt das frühe Tasklimit auf, und kein Parameter vermeidet den vollständigen Instanz-Wait-Stats-Snapshot. |
| Sicherer Einsatz | Fünf Sekunden, SQL-Text aus, `@MaxZeilen = 100` und bei Bedarf exakte Session-/Waitfilter. Text erst für einen identifizierten Request nachfordern. |
| Aussagegrenze | Aktuelle Tasks und Instanzdelta haben unterschiedliche Zeitmodelle und dürfen nicht zeilengleich korreliert werden. Kumulative Waits sind keine aktuelle Last; ein kurzes Delta kann seltene Ereignisse verpassen. Top-N und späte Regexfilter können relevante Waittypen oder Sessions ausblenden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Auf welche Ressourcen oder Ereignisse warten Tasks aktuell, und welche Waits dominierten Instanz oder Sample?

### Technischer Hintergrund

Die Procedure kombiniert aktuelle Waiting Tasks mit instanzweiten abgeschlossenen Waits und optionalem Delta. Ressource, Signalzeit, Taskparallelität und Waitfamilie gehören zum technischen Modell.

### Datenkette

`master.sys.databases`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_os_sys_info`, `sys.dm_os_wait_stats`, `sys.dm_os_waiting_tasks`, `sys.sp_executesql`.

### Source Select

Der Livepfad verbindet wartende Tasks mit Session und aktuellem Request:

```sql
SELECT
      [wt].[session_id]
    , [wt].[exec_context_id]
    , [wt].[wait_type]
    , [wt].[wait_duration_ms]
    , [wt].[blocking_session_id]
    , [r].[request_id]
    , [r].[database_id]
    , [s].[status] AS [SessionStatus]
FROM [sys].[dm_os_waiting_tasks] AS [wt] WITH (NOLOCK)
LEFT JOIN [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
  ON [r].[session_id] = [wt].[session_id]
LEFT JOIN [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK)
  ON [s].[session_id] = [wt].[session_id]
WHERE [wt].[session_id] <> @@SPID
  AND [wt].[wait_duration_ms] >= @MinWaitMs;
```

**Wichtig für die Eigenlast:** Waittyp, Mindestdauer und Session vor SQL-Textauflösung filtern. Der optionale Delta-Pfad liest `sys.dm_os_wait_stats` zweimal; `@SampleSeconds` verursacht bewusst Wartezeit, aber keine Nutzdatenlocks.

### Zeit- und Scope-Modell

Tasksnapshot plus kumulativer Kontext oder gültiges Sampledelta. Current Tasks werden vor der optionalen Samplingpause erfasst.

### Bewertung und Gegenprobe

Waittyp, Dauer, Anzahl, Resource/Signalanteil, Workloadwirkung und zweite Evidenzquelle kombinieren.

### Typische Fehlinterpretation

Ein Wait ist keine Root Cause und ein hoher kumulativer Wert kein aktuelles Problem.

### Folgeanalyse

Die kanonischen [Wait-Details](../02_Current_State.md#4-monitorusp_currentwaits), den [Betriebsvertrag des Wait-Katalogs](../../Operations/Wait_Type_Catalog.md) und das [Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) verwenden; danach je Familie Blocking, I/O, Grants, CPU oder HADR weiterverfolgen.

## Primärquellen

- [sys.dm_os_wait_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQLskills Wait Types Library – vertiefende Einordnung einzelner Waittypen](https://www.sqlskills.com/help/waits/)
- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#4-monitorusp_currentwaits)
