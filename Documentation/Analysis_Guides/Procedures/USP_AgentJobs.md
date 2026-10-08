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

Die letzte Stepzeile wird getrennt je Job und Step nach `instance_id`
gewählt. Die begrenzte SQL-2025-Fixture bestätigt drei injizierte lokale
Startzeitpunkte und Dauerwerte sowie alle zehn JSON-Felder zweier Steps.
Eine jeweils jüngere Zeile des anderen Steps verändert den ersten Step
nicht. Injizierte Retryzahlen sind gespeicherte Werte und belegen kein
tatsächliches Retryverhalten oder eine Stepausführung.

Die identische Dauerformel für Job und Step kann für den deklarierten
`int`-Bereich von `sysjobhistory.run_duration` keinen Integerüberlauf erzeugen.
Eine statische Betragsabschätzung begrenzt Stunden-, Minuten- und Sekundenanteil
auf 773.092.800, 5.940 und 99; beide Additionen bleiben damit innerhalb von
`int`. Die konservative Summenschranke 773.098.839 bestimmt kein exaktes
Maximum und keine zulässige fachliche Maximaldauer. Die Rechnung validiert
weder negative oder fehlerhaft codierte Dauern noch `agent_datetime`, andere
Procedurearithmetik oder tatsächliche Laufzeiten; native Endpunktfälle wurden
für diesen statischen Nachweis nicht ausgeführt.

Eine getrennte SQL-2025-Gegenprobe injiziert ausschließlich die ungültigen
Kalenderdaten 20230229 und 20240230, jeweils als Job- und Stepoutcome.
AgentJobs meldet in allen vier Fällen `ERROR_HANDLED`, `isPartial=true`
und den zuvor direkt gemessenen nativen Fehler 242. Bei ungültigem
Joboutcome bleiben Job- und Steparray leer. Bei ungültigem Stepoutcome
bleibt der zuvor gelesene gültige Joboutcome erhalten; das Steparray ist
leer. Diese Beobachtung gilt für NONE/JSON bei `XACT_ABORT OFF`; andere
ungültige Datums-/Zeitwerte und `XACT_ABORT ON` sind damit nicht abgenommen.

Eine weitere getrennte SQL-2025-Gegenprobe bestätigt dieselben Fehler-
und Arrayzustände für die Uhrzeitwerte 236060 und 240000 bei gültigem
Datum 20240229, jeweils als Job- oder Stepoutcome. Vier direkte Orakel
messen Fehler 242. Der Wert 236060 prüft ungültige Minuten und Sekunden
gemeinsam; ein isolierter Fehlernachweis je Teilfeld wird nicht behauptet.
Weitere Uhrzeitwerte und XACT_ABORT ON bleiben ungeprüft.

Eine getrennte tatsächliche SQL-2025-Ausführung prüft einen eigenen lokalen
TSQL-Step mit genau einem konfigurierten Retry und Intervall 0. Nach dem
kontrollierten Erstfehler folgen nativ Retrystatus 2, Steperfolg 1 und
Joberfolg 1. Die neueste Erfolgszeile besitzt im beobachteten Dockerlauf
retries_attempted 0; LastRunRetries erhält diesen gespeicherten Wert.
Der tatsächliche Retry wird durch die Statusfolge belegt. NONE/JSON liefert
den letzten erfolgreichen Step; @NurProblematisch=1 enthält den danach
deaktivierten Job, aber keinen problematischen Step. Der ältere Retryoutcome
wird nicht als letzter Step ausgewählt. Retryerschöpfung, positive Intervalle,
Parallelität und andere Engines sind damit nicht geprüft.

Eine spätere getrennte SQL-2025/Docker-Gegenprobe bestätigt die Erschöpfung
eines konfigurierten Retries bei Intervall 0. Der TSQL-Step des eigenen aktivierten Jobs
scheitert auch beim zweiten Versuch. Die native Folge ist Retrystatus 2,
Stepfailure 0 und Jobfailure 0. Die letzte Stepzeile speichert diesmal
retries_attempted 1; LastRunRetries erhält diesen unabhängig gelesenen Wert.
Beide NONE-/JSON-Aufrufe mit @NurProblematisch 0 beziehungsweise 1 enthalten
den eigenen fehlgeschlagenen Job und den letzten failed Step. Dieser
Failureumfang bestätigt keine positiven Intervalle oder allgemeine
plattformübergreifende Retryzählung.

Eine getrennte tatsächliche SQL-2025/Docker-Probe bestätigt eine automatisch
angewandte Vierzeilen-Grenze pro Job. Drei erfolgreiche Läufe eines eigenen
aktivierten Jobs mit einem TSQL-Step hinterlassen zwei, vier und vier
Historyzeilen. Das erste Paar nach instance_id verschwindet automatisch;
sämtliche Werte des zweiten Paars bleiben erhalten. NONE/JSON liefert
in allen drei Phasen den letzten erfolgreichen Job und Step. Der
Problemfilter enthält den schedulefreien Job, aber keinen erfolgreichen Step.
Die zusätzlich konfigurierte globale Grenze 64 wird nicht erreicht;
Altersretention, Parallelität und andere Engines bleiben ungeprüft.

Eine getrennte tatsächliche SQL-2025/Docker-Probe prüft eine globale
Agent-Historiengrenze von sechs Zeilen bei einer Vierzeilen-Grenze pro Job.
Vier erfolgreiche Läufe zweier eigener aktivierter Jobs mit je einem TSQL-Step in der
Reihenfolge A, B, A, B hinterlassen zwei, vier, sechs und sechs Zeilen.
Das erste A-Paar verschwindet; vollständige Werte der beiden jüngeren
Paare bleiben erhalten. Kein Job überschreitet vier erzeugte Zeilen.
NONE/JSON erhält in jeder Phase die letzten erfolgreichen Jobs und Steps;
der Problemfilter enthält die schedulefreien Jobs, aber keine Steps.
Andere Limits, Altersretention und Parallelität bleiben ungeprüft.

Eine getrennte tatsächliche SQL-2025/Docker-Probe prüft einen eigenen
TSQL-Step mit einem Retry und positivem Intervall von einer Minute.
Nach kontrolliertem Erstfehler entsteht nativ eine Retryzeile mit Status 2;
danach folgen Steperfolg und Joberfolg mit Status 1. Mindestens 50 durch
Einsekunden-Waits getrennte Pollzyklen erfassen den noch nicht abgeschlossenen
Job bei vorhandener Retryzeile; die gemessene Spanne bis zum beobachteten
Abschluss beträgt mindestens 50 Sekunden. Der letzte erfolgreiche Step
speichert retries_attempted 0; NONE/JSON erhält diesen Wert und
den Erfolg, während der Problemfilter den älteren Retry ausschließt.
Andere Intervalle, Retryerschöpfung mit positivem Intervall und Consumer
während des laufenden Jobs bleiben ungeprüft.

Eine getrennte tatsächliche SQL-2025/Docker-Probe bestätigt
Retryerschöpfung bei einem konfigurierten Retry mit Intervall einer Minute.
Beide Versuche desselben eigenen TSQL-Steps scheitern kontrolliert;
drei native Historyzeilen zeigen Retry 2, Stepfailure 0 und Jobfailure 0.
Mindestens 50 durch Einsekunden-Waits getrennte Pollzyklen erfassen den
noch nicht abgeschlossenen Job nach vorhandener Retryzeile. Die gemessene
Spanne bis zum beobachteten Abschluss beträgt mindestens 50 Sekunden.
Beide NONE-/JSON-Filter erhalten den letzten failed Step und dessen
gespeicherten retries_attempted-Wert 1. Consumer während des laufenden
Jobs, weitere Intervalle und Parallelität bleiben ungeprüft.

Eine spätere getrennte SQL-2025-Kalenderprobe mit XACT_ABORT ON und
jeweils frischer committable Callertransaktion erfasst eine Fehlergrenze.
Bei 20230229 und 20240230 als Job- oder Stepoutcome meldet NONE/JSON
weiterhin ERROR_HANDLED/Partial mit Fehler 242, aber XACT_STATE wird -1.
Bei ungültigem Joboutcome bleibt das Jobarray leer; bei ungültigem Step
enthält es eine Zeile. Die Steparrays bleiben leer. Die vier Callertransaktionen sind danach
uncommittable; unveränderte Optionen und Quellwerte belegen hier keine
erhaltene Committability. Der private Beobachter rollt jede Transaktion zurück.
Die Korrektur begrenzt XACT_ABORT OFF auf die Job-/Stepcollection und
stellt die ursprüngliche Einstellung vor der Ausgabe wieder her. Eine
nachfolgende SQL-2025-Gegenprobe mit denselben vier Kalenderfällen besteht
bei ON und OFF: NONE/JSON liefert ERROR_HANDLED/Partial mit Fehler 242,
die eigene Callertransaktion bleibt schreibfähig mit XACT_STATE 1. Die
Jobarrays enthalten null Zeilen bei ungültigem Joboutcome und eine Zeile
bei ungültigem Step; die Steparrays bleiben leer. Quellwerte, TX1 und
Locktimeout 31 bleiben erhalten. Die erweiterte registrierte TEST-0001-
Fixture besteht außerdem 21 positive und zwölf Kalenderconsumeraufrufe.
Die Gegenprobe belegt diese Werte und Ausgabeart auf SQL Server 2025;
andere Lesefehler und ungültige Kalenderfälle im TABLE-Export sind daraus
nicht abgeleitet. Eine bereits uncommittable Callertransaktion wird nicht repariert.

Eine nachfolgende getrennte SQL-2025-Gegenprobe prüft die ungültigen
Uhrzeiten 236060 und 240000 bei gültigem Datum 20240229 jeweils als Job-
und Stepoutcome. Bei XACT_ABORT ON und OFF bleibt die eigene frische
Callertransaktion nach jedem NONE-/JSON-Aufruf schreibfähig. AgentJobs
liefert ERROR_HANDLED/Partial mit Fehler 242 und nicht leerer Fehlermeldung;
Jobs enthält null Zeilen beim Jobfehler und eine Zeile beim Stepfehler,
Steps bleibt leer. Sechs vollständige Quellen, TX1 und Locktimeout 31
bleiben erhalten. Die bestehende TEST-0001-Fixture besteht nun 21 positive
und 24 Kalender-/Uhrzeitconsumeraufrufe einschließlich 24 eigener Rollbacks.
236060 kombiniert ungültige Minuten und Sekunden; isolierte Teilfeldgrenzen,
andere Uhrzeiten und fehlerhafte Kalenderwerte in TABLE/RAW/CONSOLE
bleiben ungeprüft.

Eine getrennte native SQL-2025-Probe führt einen eigenen TSQL-Job mit
einem Step und drei Sekunden WAITFOR ohne Retry aus. Nach Abschluss
wird der Job deaktiviert. Native History enthält Step- und Joberfolg mit
3 beziehungsweise 4 Sekunden. AgentJobs bestätigt LastRunDurationSeconds
und LastRunDateTime gegen diese nativen Werte; Startzeiten werden
unabhängig aus run_date und run_time gebildet. Die normale Ausgabe
enthält einen Job und einen Step. Der Problemfilter enthält den
deaktivierten Job mit korrekter Dauer und Startzeit, aber keinen Step.
NONE-/JSON-Aufrufe erhalten sechs vollständige Quellen und ON/31/TX1.
Diese kurze positive Probe belegt keine Minuten-/Stundenübergänge,
lange Ausführungen oder Durationparität anderer Ausgabearten.

Eine weitere getrennte SQL-2025-Probe isoliert ungültige Minuten und
Sekunden: 6000 entspricht 00:60:00, 60 entspricht 00:00:60. Bei gültigem
Datum 20240229 werden beide Werte als Job- und Stepoutcome geprüft.
Je zwölf NONE-/JSON-Aufrufe bei ON und OFF bleiben schreibfähig.
AgentJobs liefert ERROR_HANDLED/Partial/242 mit nicht leerer Message;
Jobs enthält null Zeilen beim Jobfehler und eine beim Stepfehler,
Steps bleibt leer. Sechs vollständige Quellen, TX1 und Locktimeout 31
bleiben erhalten. TEST-0001 besteht nun 21 positive und 36 Kalender-/
Uhrzeitaufrufe mit 36 eigenen Kalenderrollbacks. Andere Werte und
ungültige Kalenderfälle in TABLE/RAW/CONSOLE bleiben ungeprüft.

Eine weitere native SQL-2025-Probe führt einen eigenen TSQL-Job mit
einem Step und 63 Sekunden WAITFOR ohne Retry aus. Nach abgeschlossenem
Joberfolg wird der Job deaktiviert. Native History speichert den HHmmss-
Rohwert 103 für den Step und 103 für den Job. Der private Guard begrenzt
beide Werte auf 100 bis 159. Die unabhängige Referenz 60 + (Rohwert - 100)
ergibt 63 beziehungsweise 63 Sekunden. AgentJobs bestätigt beide Werte in
LastRunDurationSeconds sowie unabhängig gebildete Startzeiten in
LastRunDateTime. Die normale NONE-/JSON-Ausgabe enthält einen Job und
einen Step; der Problemfilter enthält den deaktivierten Job, aber keinen
Step. Sechs vollständige Quellen und ON/31/TX1 bleiben erhalten.
Diese einzelne tatsächliche Probe belegt die Minutenkomponente eins;
Stundenwerte, weitere Dauergrenzen und andere Ausgabearten bleiben offen.

Eine getrennte native SQL-2025-Probe injiziert acht gültige Dauergrenzen
in die History eines eigenen deaktivierten Jobs mit einem definierten Step.
Die Rohwerte 59, 100, 159, 200, 5959, 10000, 235959 und 240000 entsprechen
den festen Sekundenreferenzen 59, 60, 119, 120, 3599, 3600, 86399 und 86400.
AgentJobs bestätigt LastRunDurationSeconds für Job und Step sowie den
festen Startwert 2024-02-29T01:02:03. Die normale NONE-/JSON-Ausgabe
enthält einen Job und einen Step; der Problemfilter enthält den
deaktivierten erfolgreichen Job, aber keinen Step. 32 Consumeraufrufe
und acht eigene Rollbacks erhalten sechs vollständige Quellen und den
Callerzustand. Der Job wird nicht ausgeführt. Tatsächliche Stundenläufe,
fehlerhafte Dauerformate und andere Ausgabearten bleiben ungeprüft.

Eine getrennte native SQL-2025-Probe charakterisiert drei injizierte
nicht kanonische positive Dauercodierungen. Die run_duration-Rohwerte
60, 6000 und 236060 ergeben in LastRunDurationSeconds für Job und Step
die festen Referenzen 60, 3600 und 86460. Datum und Uhrzeit bleiben gültig;
der feste Startwert ist 2024-02-29T01:02:03. Die normale NONE-/JSON-Ausgabe
enthält einen Job und einen Step; der Problemfilter enthält den
deaktivierten erfolgreichen Job, aber keinen Step. Zwölf Consumeraufrufe
und drei eigene Rollbacks erhalten sechs vollständige Quellen und den
Callerzustand. Der Job wird nicht ausgeführt. Dies charakterisiert die
bestehende Arithmetik für diese gespeicherten Werte; Formatvalidierung,
Normalisierung, tatsächliche Ausführungsdauer und allgemeine semantische
Zulässigkeit werden nicht belegt.

Eine getrennte native SQL-2025-Probe charakterisiert die selektive
Historybereinigung eines eigenen deaktivierten Jobs bei erhaltenem zweitem
Job. Vier frisch aufgebaute unabhängige Phasen liefern Gesamtcounts
8, 6, 4 und 2 sowie Zieljobcounts 6, 4, 2 und 0. Der native Purge erhält
Einträge genau an der Datumsgrenze; die um eine Sekunde erhöhte Grenze
entfernt sie. Der NULL-Datumsfall entfernt ausschließlich die History des
ausgewählten Jobs. AgentJobs behält beide Job- und Stepdefinitionen;
nach dem NULL-Purge sind nur die Historienfelder des Zieljobs und seines
Steps NULL. Der Problemfilter enthält die beiden deaktivierten Jobs und
keinen Step. 16 NONE-/JSON-Aufrufe und vier eigene Rollbacks erhalten
Quellen und Callerzustand. Die History ist injiziert; tatsächliche
Jobausführung, automatische Altersretention und allgemeine Purgegarantien
werden nicht belegt.

### Bewertung und Gegenprobe

Berücksichtigen Sie den Jobstatus, den aktuellen Step, Run Requested, Start und Stop, Retry, die letzten Outcomes, den Schedule und die typische Laufzeit gemeinsam. Unterscheiden Sie die Jobgesamtzeile von Stepfehlern.

### Typische Fehlinterpretation

`LastRunOutcome=Succeeded` kann einen später aktuell laufenden/steckenden Lauf überdecken. History kann abgeschnitten sein; lange Dauer muss mit Workloadfenster verglichen werden.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_AgentMonitoringAnalysis`, Current Requests/Blocking und Jobstep-/Logoutput.

## Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/en-us/ssms/agent/sql-server-agent?view=sql-server-ver17)
- [sysjobhistory: Datentyp und Dauerformat](https://learn.microsoft.com/en-us/sql/relational-databases/system-tables/dbo-sysjobhistory-transact-sql?view=sql-server-ver17)
- [Integerbereiche](https://learn.microsoft.com/en-us/sql/t-sql/data-types/int-bigint-smallint-and-tinyint-transact-sql?view=sql-server-ver17)
- [Division: Abschneiden des Bruchteils](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/divide-transact-sql?view=sql-server-ver17)
- [Modulo: Divisionsrest](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/modulo-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#2-monitorusp_agentjobs)
