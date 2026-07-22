# [monitor].[USP_AgentJobs]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Jobs, Schritte, Laufstatus, Historie, Dauer und Fehler.<br>
**Beobachtungsart:** Konfigurationssnapshot + retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Jobs sind aktiviert, geplant, aktuell laufend oder zuletzt fehlgeschlagen beziehungsweise ungewöhnlich langsam?** Der dokumentierte Zweck ist: Zeigt Jobs, Schritte, Laufstatus, Historie, Dauer und Fehler. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Konfigurationssnapshot plus aufbewahrte History. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentJobs]
      @NurProblematisch = 1,
      @LongRunningMinutes = 60,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `jobs` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Job, einem Jobschritt, einer Historienzeile oder einem aktuellen Laufzustand.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Enabled, aktueller Laufstatus, letzter Outcome, Dauer, nächste Ausführung und Schrittfehler gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Wiederholte Fehler oder stark verlängerte Laufzeiten können Backups, Ladeprozesse und Wartungsfenster gefährden.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein Full Backup oder eine große Wartung darf lange laufen, wenn dies dem historischen Normalwert und Wartungsfenster entspricht.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 90 Minuten aktuelle Dauer bei 20 Minuten Normalwert und blockierten Folgeschritten: echte Abweichung. Schrittoutput, Blocking, I/O und Historie prüfen.

**Ähnlich aussehender Gegenfall:** Ein Full Backup oder eine große Wartung darf lange laufen, wenn dies dem historischen Normalwert und Wartungsfenster entspricht. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_AgentJobs` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Bis zu 2000 Agent-Jobs mit aktuellem Aktivitätszustand, jeweils letzter Jobausgang und den zugehörigen Jobsteps; kein frei wählbares Historyfenster. |
| Teuerster Pfad | `@MaxZeilen = 0`, kein Jobfilter und Regexpattern auf einer msdb mit sehr vielen Jobs, Steps und Historyzeilen. Bei Regex entfällt die frühe Kandidatenbegrenzung. |
| Haupttreiber | Zahl der Jobkandidaten, ihrer Steps und der für „letzter Ausgang“ zu durchsuchenden Historyzeilen. Exakte Namen/LIKE reduzieren Jobs früh; Regex erzwingt die spätere Nachfilterung der bereits materialisierten Menge. |
| Skalierung | Aufwand wächst mit Jobs/Steps und der Suche nach letzter Aktivitäts-/Historyzeile je Job. Regex muss die vollständige vorselektierte Jobmenge materialisieren und nachfiltern. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | Exakte Jobliste und LIKE wirken in der Quellabfrage. Ohne Regex begrenzt TOP die Jobkandidaten früh; Regex wird nach Materialisierung angewandt. `@MaxZeilen` gilt für Jobs und beeinflusst indirekt Steps, begrenzt aber die Suche nach der letzten Historyzeile nicht proportional. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Kein High-Impact-Gate. Exakte Jobnamen, LIKE, Problemscope und das endliche Joblimit begrenzen Kandidaten; Regex ist bewusst ein später Filter und hebt den frühen TOP-Schutz auf. Es gibt keinen frei erweiterbaren Historyzeitraum. |
| Sicherer Einsatz | Mit einem `ExampleJob` oder einer kleinen exakten Jobliste und endlichem Limit beginnen; Regex beziehungsweise vollständiges Jobinventar bei großer msdb außerhalb der Lastspitze. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurationssnapshot + retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Jobs sind aktiviert, geplant, aktuell laufend oder zuletzt fehlgeschlagen beziehungsweise ungewöhnlich langsam?

### Technischer Hintergrund

`msdb.dbo.sysjobs`, Steps, Schedules, Job Activity und History bilden Definition, aktuelle Instanzaktivität und vergangene Outcomes. `sysjobhistory` speichert Job-/Stepzeilen mit integercodierten Datum-/Zeit-/Dauerwerten; laufende Aktivität liegt in `sysjobactivity`.

### Datenkette

`master.sys.databases`, `msdb.dbo.agent_datetime`, `msdb.dbo.syscategories`, `msdb.dbo.sysjobactivity`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `msdb.dbo.sysjobschedules`, `msdb.dbo.sysjobsteps`, `msdb.dbo.sysschedules`, `sys.sp_executesql`.

### Source Select

Das reduzierte Grundselect zeigt Jobdefinition, aktuellen Lauf und den Outcome der Job-Gesamtzeile:

```sql
WITH [LatestActivity] AS
(
    SELECT
          [ja].*
        , ROW_NUMBER() OVER
          (PARTITION BY [ja].[job_id] ORDER BY [ja].[session_id] DESC) AS [rn]
    FROM [msdb].[dbo].[sysjobactivity] AS [ja] WITH (NOLOCK)
),
[LatestOutcome] AS
(
    SELECT
          [h].*
        , ROW_NUMBER() OVER
          (PARTITION BY [h].[job_id] ORDER BY [h].[instance_id] DESC) AS [rn]
    FROM [msdb].[dbo].[sysjobhistory] AS [h] WITH (NOLOCK)
    WHERE [h].[step_id] = 0
)
SELECT
      [j].[job_id]
    , [j].[name] AS [JobName]
    , [ja].[start_execution_date]
    , [ja].[stop_execution_date]
    , [h].[run_status]
FROM [msdb].[dbo].[sysjobs] AS [j] WITH (NOLOCK)
LEFT JOIN [LatestActivity] AS [ja]
  ON [ja].[job_id] = [j].[job_id]
 AND [ja].[rn] = 1
LEFT JOIN [LatestOutcome] AS [h]
  ON [h].[job_id] = [j].[job_id]
 AND [h].[rn] = 1
WHERE [j].[enabled] = 1;
```

**Wichtig für die Eigenlast:** Jobname oder `job_id` möglichst vor Schedule-, Step- und History-Vertiefungen einschränken. `sysjobhistory` kann wesentlich größer als die Jobdefinition sein; ein Zeitfenster auf `run_date` spart dort die meiste Arbeit.

### Zeit- und Scope-Modell

Konfigurationssnapshot plus aufbewahrte History. Agentrestart erzeugt neue Sessionkontexte; Cleanup begrenzt Historie.

### Bewertung und Gegenprobe

Jobstatus, aktueller Step, Run Requested/Start/Stop, Retry, letzte Outcomes, Schedule und typische Laufzeit zusammen lesen. Jobgesamtzeile und Stepfehler unterscheiden.

### Typische Fehlinterpretation

`LastRunOutcome=Succeeded` kann einen später aktuell laufenden/steckenden Lauf überdecken. History kann abgeschnitten sein; lange Dauer muss mit Workloadfenster verglichen werden.

### Folgeanalyse

`USP_AgentMonitoringAnalysis`, Current Requests/Blocking und Jobstep-/Logoutput.

## Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/en-us/ssms/agent/sql-server-agent?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#2-monitorusp_agentjobs)
