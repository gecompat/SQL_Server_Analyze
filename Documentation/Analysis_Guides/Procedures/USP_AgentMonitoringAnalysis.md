# [monitor].[USP_AgentMonitoringAnalysis]

**Bereich:** Infrastruktur<br>
**Zweck:** Verknüpft Jobprobleme mit Alerts, Operatoren und Database Mail.<br>
**Beobachtungsart:** Konfigurationssnapshot + retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Jobs, Alerts und Benachrichtigungsketten gefährden geplante Betriebsabläufe?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentMonitoringAnalysis]
      @HistoryHours = 24,
      @MitJobStatus = 1,
      @MitDatabaseMail = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `findings`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Jobproblem, Alert, Operator, Mailstatus oder normalisierten Finding.

## So lesen

Prüfen Sie Jobfehler, Alertkonfiguration, Operatorerreichbarkeit und Mailpfad getrennt und verbinden Sie die Ergebnisse anschließend.

## Warum kann das problematisch sein?

Ein Fehler kann unbemerkt bleiben, wenn Alert, Operator oder Mailpfad fehlt.

## Wann ist es kein Problem?

Database Mail ist nicht zwingend, wenn ein dokumentierter alternativer Alarmweg existiert.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Kritischer Job schlägt wiederholt fehl, aber kein aktiver Operator ist erreichbar: höheres Betriebsrisiko als der Jobfehler allein. Prüfen Sie Jobdetails und Monitoringprozess.

**Ähnlich aussehender Gegenfall:** Database Mail ist nicht zwingend, wenn ein dokumentierter alternativer Alarmweg existiert. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_AgentMonitoringAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Aktueller Service-/Alert-/Operator-/Schedulezustand, der letzte Job-Outcome und 24 Stunden Alertaktivität beziehungsweise aggregierter Database-Mail-Status. |
| Teuerster Pfad | `@HistoryHours = 8760`, beide optionalen Pfade aktiv und unbegrenzte Ausgabe auf einer msdb mit umfangreicher Job- und Mailhistorie. Einen Datenbank- oder Jobfilter besitzt die Procedure nicht. |
| Haupttreiber | Zahl der Jobs, Alerts, Operatoren und Schedules, die gesamte sichtbare Job-Outcome-Historie sowie Database-Mail-Zeilen innerhalb `@HistoryHours`. Das spätere Findingslimit verkleinert diese vorgelagerte msdb-Aggregation nicht. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_AgentMonitoringAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | `@HistoryHours` begrenzt Alertaktivität und Mailzeilen zeitlich; Jobhistory wird für den letzten Outcome ohne Zeitfilter gelesen und danach zeitlich klassifiziert. `@MitJobStatus`/`@MitDatabaseMail` können ganze Pfade auslassen. `@MaxZeilen` wirkt erst auf fertige Findings/Jobs und begrenzt die vorherige Konfigurations- und Historyaggregation nicht. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Kein High-Impact-Gate. `@HistoryHours` ist auf höchstens 8760 begrenzt; `@MitJobStatus` und `@MitDatabaseMail` lassen die beiden variablen Historypfade vollständig aus. `@MaxZeilen` schützt dagegen nur die fertige Ausgabe, nicht die vorherige Aggregation. |
| Sicherer Einsatz | Mit 24 Stunden und nur dem aktuell benötigten optionalen Pfad beginnen. Da kein Jobfilter existiert, lange Lookbacks auf großen msdb-Beständen außerhalb der Lastspitze ausführen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurationssnapshot + retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Jobs, Alerts und Benachrichtigungsketten gefährden geplante Betriebsabläufe?

### Technischer Hintergrund

Die Procedure verbindet Job-/Step-/Schedule-/Historyanalyse mit Alerts, Operators und Database Mail-/Notificationkontext. Laufzeitanomalien benötigen historische Vergleichswerte; Notifications benötigen korrekt verknüpfte Operator-/Mailkonfiguration.

### Datenkette

`msdb.dbo.agent_datetime`, `msdb.dbo.sysalerts`, `msdb.dbo.sysjobhistory`, `msdb.dbo.sysjobs`, `msdb.dbo.sysjobschedules`, `msdb.dbo.sysmail_allitems`, `msdb.dbo.sysnotifications`, `msdb.dbo.sysoperators`, `msdb.dbo.sysschedules`, `sys.dm_server_services`.

### Collation und Ausgabegrenzen

Die sieben Textspalten des `findings`-TABLE-Exports verwenden die
Frameworkcollation `SQL_Latin1_General_CP1_CS_AS`. RAW, CONSOLE, TABLE und
JSON verwenden dieselbe begrenzte Findingsmenge. Ein positives `@MaxZeilen`
begrenzt diese Menge nach dem bestehenden Rang HIGH, MEDIUM und anschließend
INFO, danach nach Kategorie und Scope-Name. Job-JSON besitzt eine eigene
Namensgrenze. Null und NULL sind unbegrenzt. Der Modulstatus wird vor der
Ausgabegrenze auf der vollständigen Erhebung bestimmt; eine ausgeblendete
Befundzeile ändert den Status nicht. Service- und Mailstatus bleiben getrennte
Kontextarrays.

### Source Select

Die Procedure besitzt mehrere fachlich getrennte Quellen. Der folgende Kernpfad zeigt die Beziehung für Alert-Routing; Jobzustand und Database Mail werden in separaten Zweigen gelesen:

```sql
SELECT
      [a].[id] AS [AlertId]
    , [a].[name] AS [AlertName]
    , [n].[notification_method]
    , [o].[name] AS [OperatorName]
FROM [msdb].[dbo].[sysalerts] AS [a] WITH (NOLOCK)
LEFT JOIN [msdb].[dbo].[sysnotifications] AS [n] WITH (NOLOCK)
  ON [n].[alert_id] = [a].[id]
LEFT JOIN [msdb].[dbo].[sysoperators] AS [o] WITH (NOLOCK)
  ON [o].[id] = [n].[operator_id]
WHERE [a].[enabled] = 1;
```

**Wichtig für die Eigenlast:** Die Procedure besitzt keine Alert- oder Jobfilter. Der Jobpfad liest die gesamte sichtbare Outcome-Historie für den letzten Lauf je Job; `@HistoryHours` steuert dessen zeitliche Klassifikation. Der Mailpfad liest dagegen nur Zeilen innerhalb dieses Zeitfensters. Die beiden Opt-in-Schalter können die jeweiligen Pfade auslassen; das Findingslimit verkleinert diese vorgelagerten Zugriffe nicht.

### Zeit- und Scope-Modell

Die Auswertung kombiniert aktuelle Konfiguration mit dem letzten sichtbaren Job-Outcome sowie zeitlich begrenzter Alertaktivität und Mailhistorie. Fehlende Jobhistory bleibt NULL; die Procedure liefert keine vollständige Ausführungsreihe und keine Laufzeitbaseline.

Der letzte Job-Outcome wird nach `instance_id` aus Gesamtzeilen mit positivem
`run_date` gewählt. `LatestRunDateTime` interpretiert Datum und Uhrzeit als
lokalen Startzeitpunkt. `LatestRunDuration` erhält den Integerrohwert aus
`run_duration`; das Feld enthält keine umgerechneten Sekunden. Die
Schaltag-/Dauergegenprobe auf SQL Server 2025 prüft diese bestehenden NONE-/JSON-
Felder getrennt von der Sekundenumrechnung in `USP_AgentJobs`.

Die getrennte SQL-2025-Kalendergegenprobe bestätigt bei Joboutcomes
20230229 und 20240230 den Status `AVAILABLE_LIMITED`, `isPartial=true`,
den direkt gemessenen nativen Fehler 242 und ein leeres Jobarray.
Dieselben ungültigen Werte in Stepoutcomes beeinträchtigen den gültigen
Jobgesamtoutcome in dieser Probe nicht: Monitoring meldet
`AVAILABLE_WITH_FINDING` ohne Partial- oder Fehlerstatus und erhält den
lokalen Jobstart samt Rohdauer. Die Probe verwendet NONE/JSON mit
Jobstatus an, Database Mail aus und `XACT_ABORT OFF`.

Eine weitere getrennte SQL-2025-Gegenprobe bestätigt diese Modul- und
Jobarrayzustände für 236060 und 240000 bei gültigem Datum 20240229,
jeweils als Job- oder Stepoutcome. Vier direkte Orakel messen Fehler 242.
236060 verändert Minuten und Sekunden gemeinsam. Weitere Uhrzeitwerte,
isolierte Minuten-/Sekundengrenzen und XACT_ABORT ON bleiben ungeprüft.

Eine getrennte tatsächliche SQL-2025-Ausführung eines eigenen lokalen
TSQL-Steps mit einem konfigurierten Retry und Intervall 0 bestätigt den
abschließenden Joberfolg nach kontrolliertem Erstfehler und Steperfolg.
Nach Deaktivierung des eigenen Jobs liefert NONE/JSON bei Jobstatus an und
Database Mail aus genau diesen letzten Gesamtoutcome mit Runstatus 1 und
JOB_STATE_INFORMATIONAL/INFO. Der Modulstatus ist AVAILABLE_WITH_FINDING
ohne Partial und ohne Fehlernummer/-meldung. Diese Probe bestätigt keine
laufende Retryphase, Retryerschöpfung oder allgemeine Retryzählung.

Eine spätere getrennte SQL-2025/Docker-Gegenprobe hält den eigenen Job
nach ausgeschöpftem Retry aktiviert. Der TSQL-Step scheitert in beiden
Versuchen bei einem konfigurierten Retry und Intervall 0. NONE/JSON mit
Jobstatus an und Mail aus liefert den letzten fehlgeschlagenen Gesamtoutcome
mit LatestRunStatus 0 und LATEST_JOB_RUN_FAILED_IN_WINDOW/HIGH. Der
Modulstatus bleibt AVAILABLE_WITH_FINDING ohne Partial und ohne Fehlerstatus.
Der native Jobfehler ist ein fachlicher Befund und kein Consumerfehler.
Positive Intervalle, Parallelität und andere Engines sind damit nicht geprüft.

Eine getrennte tatsächliche SQL-2025/Docker-Probe prüft drei erfolgreiche
Läufe eines eigenen aktivierten Jobs unter automatischer Vierzeilen-Retention
pro Job. Die Historycounts sind zwei, vier und vier; das erste native
Zeilenpaar verschwindet, während sämtliche Werte des zweiten erhalten bleiben.
NONE/JSON liefert in jeder Phase LatestRunStatus 1 und den Befund
ENABLED_JOB_WITHOUT_SCHEDULE/INFO. AVAILABLE_WITH_FINDING ohne Partial oder
Consumerfehler beschreibt den fehlenden Schedule dieses aktivierten Jobs.
Die Probe belegt weder globale Grenzüberschreitung noch Altersretention.

Eine getrennte tatsächliche SQL-2025/Docker-Probe prüft eine globale
Agent-Historiengrenze von sechs Zeilen bei einer Vierzeilen-Grenze pro Job.
Vier erfolgreiche Läufe zweier eigener aktivierter Jobs mit je einem TSQL-Step in der
Reihenfolge A, B, A, B hinterlassen zwei, vier, sechs und sechs Zeilen.
Das erste A-Paar verschwindet; vollständige Werte der beiden jüngeren
Paare bleiben erhalten. NONE/JSON liefert für jeden vorhandenen Job
LatestRunStatus 1 und ENABLED_JOB_WITHOUT_SCHEDULE/INFO ohne Partial oder
Consumerfehler. Andere Limits, Altersretention und Parallelität bleiben offen.

### Bewertung und Gegenprobe

Korrelieren Sie Fehlerhäufigkeit, letzten und aktuellen Lauf, typische Dauer, Schedule Miss, Retry, Alertbedingungen, Operatorzeiten und Mailstatus. Priorisieren Sie kritische Jobs nach ihrer Funktion.

### Typische Fehlinterpretation

Keine Mail bedeutet nicht kein Fehler und ein erfolgreicher Mailtest nicht funktionierende Jobnotification. P95-/Baselinewerte sind bei wenigen Läufen schwach.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Agent Jobs, Jobstepoutput, Database Mail Logs und Current State.

## Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/en-us/ssms/agent/sql-server-agent?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#11-monitorusp_agentmonitoringanalysis)
