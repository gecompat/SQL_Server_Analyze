# [monitor].[USP_AgentJobs]

**Bereich:** Infrastruktur<br>
**Zweck:** Zeigt Jobs, Schritte, Laufstatus, Historie, Dauer und Fehler.<br>
**Beobachtungsart:** Konfigurationssnapshot + retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Jobs sind aktiviert, geplant, aktuell laufend oder zuletzt fehlgeschlagen beziehungsweise ungewöhnlich langsam?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentJobs]
      @NurProblematisch = 1,
      @LongRunningMinutes = 60,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert ausschließlich `jobs` mit unverändert 17 Feldern und sechs explizit collatierten Textspalten. CONSOLE zeigt dieselbe Jobsmenge mit einer zusätzlichen Ergebnisbezeichnung; eine leere Menge erhält eine Hinweiszeile. RAW liefert Modulstatus, Jobs und Steps. JSON enthält `meta`, `jobs` und `steps`; es besitzt kein Warnings-Array. Die lokalen Jobs- und Steps-Textspalten verwenden `SQL_Latin1_General_CP1_CS_AS`. Gültige doppelte Namen in der exakten Pipe-Liste werden unter dieser Collation zusammengeführt; der erste Listenordinal bleibt erhalten. Namen, die sich nur in der Groß-/Kleinschreibung unterscheiden, bleiben getrennt. Prüfen Sie den Modulstatus vor den Fachmengen und vereinigen Sie Jobs und Steps nicht ungeprüft.

## Eine Zeile bedeutet

Eine Jobszeile entspricht einem ausgewählten Job mit seinem letzten Gesamtoutcome und aktuellen Aktivitätskontext. Eine Stepszeile entspricht einem Schritt eines bereits ausgewählten Jobs mit seinem letzten Stepoutcome; die Procedure exportiert keine einzelne Historyzeile.

## So lesen

Berücksichtigen Sie Enabled, aktueller Laufstatus, letzter Outcome, Dauer, nächste Ausführung und Schrittfehler gemeinsam.

## Warum kann das problematisch sein?

Wiederholte Fehler oder stark verlängerte Laufzeiten können Backups, Ladeprozesse und Wartungsfenster gefährden.

## Wann ist es kein Problem?

Ein Full Backup oder eine große Wartung darf lange laufen, wenn dies dem historischen Normalwert und Wartungsfenster entspricht.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 90 Minuten aktuelle Dauer bei 20 Minuten Normalwert und blockierten Folgeschritten: echte Abweichung. Prüfen Sie Schrittoutput, Blocking, I/O und Historie.

**Ähnlich aussehender Gegenfall:** Ein Full Backup oder eine große Wartung darf lange laufen, wenn dies dem historischen Normalwert und Wartungsfenster entspricht. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_AgentJobs` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Bis zu 2000 Agent-Jobs mit aktuellem Aktivitätszustand, jeweils letzter Jobausgang und den zugehörigen Jobsteps; kein frei wählbares Historyfenster. |
| Teuerster Pfad | `@MaxZeilen = 0`, kein Jobfilter und Regexpattern auf einer msdb mit sehr vielen Jobs, Steps und Historyzeilen. Bei Regex entfällt die frühe Kandidatenbegrenzung. |
| Haupttreiber | Zahl der Jobkandidaten, ihrer Steps und der für „letzter Ausgang“ zu durchsuchenden Historyzeilen. Exakte Namen/LIKE reduzieren Jobs früh; Regex erzwingt die spätere Nachfilterung der bereits materialisierten Menge. |
| Skalierung | Aufwand wächst mit Jobs/Steps und der Suche nach letzter Aktivitäts-/Historyzeile je Job. Regex muss die vollständige vorselektierte Jobmenge materialisieren und nachfiltern. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | Exakte Jobliste und LIKE wirken in der Quellabfrage. Ohne Regex begrenzt TOP die Jobkandidaten früh; Regex wird nach Materialisierung angewandt. `@MaxZeilen` begrenzt Jobs und die anschließende Stepsmenge jeweils; NULL und 0 sind unbegrenzt. Es begrenzt die Suche nach der letzten Historyzeile nicht proportional. Die frühe Jobsauswahl wird durch das spätere Problemranking nicht zu einer globalen Problemauswahl. |
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

**Wichtig für die Eigenlast:** Verwenden Sie eine kleine exakte Jobliste oder LIKE vor der weiteren Analyse. `sysjobhistory` kann wesentlich größer als die Jobdefinition sein; die Procedure bietet weder einen `job_id`-Parameter noch ein frei wählbares Historyzeitfenster. Bei `@NurProblematisch=1` bleiben Steps ohne gespeicherten Outcome 0, 2 oder 3 leer, auch wenn ein ausgewählter problematischer Job definierte Steps besitzt.

### Zeit- und Scope-Modell

Die Auswertung kombiniert einen Konfigurationssnapshot mit der aufbewahrten Historie. Ein Agent-Neustart erzeugt neue Sessionkontexte; Cleanup begrenzt die Historie.

Die letzte Jobgesamtzeile wird nach `instance_id` gewählt. `LastRunDateTime`
interpretiert deren Integerdatum und Uhrzeit als lokalen Startzeitpunkt;
`LastRunDurationSeconds` konvertiert die codierte Dauer in Sekunden, auch
bei einer Stundenkomponente über 24. Die lokalen Jobfilter verwenden einen
Primärschlüssel mit automatisch vergebenem Constraintnamen. Die begrenzte
SQL-2025-Gegenprobe bestätigt wiederholte Aufrufe in derselben Callertransaktion.

### Bewertung und Gegenprobe

Berücksichtigen Sie den Jobstatus, den aktuellen Step, Run Requested, Start und Stop, Retry, die letzten Outcomes, den Schedule und die typische Laufzeit gemeinsam. Unterscheiden Sie die Jobgesamtzeile von Stepfehlern.

### Typische Fehlinterpretation

`LastRunOutcome=Succeeded` kann einen später aktuell laufenden/steckenden Lauf überdecken. History kann abgeschnitten sein; lange Dauer muss mit Workloadfenster verglichen werden.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_AgentMonitoringAnalysis`, Current Requests/Blocking und Jobstep-/Logoutput.

## Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/en-us/ssms/agent/sql-server-agent?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#2-monitorusp_agentjobs)
