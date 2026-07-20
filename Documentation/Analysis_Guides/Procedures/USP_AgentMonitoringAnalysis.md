# [monitor].[USP_AgentMonitoringAnalysis]

**Bereich:** Infrastruktur<br>
**Zweck:** Verknüpft Jobprobleme mit Alerts, Operatoren und Database Mail.<br>
**Beobachtungsart:** Konfigurationssnapshot + retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Jobs, Alerts und Benachrichtigungsketten gefährden geplante Betriebsabläufe?** Der dokumentierte Zweck ist: Verknüpft Jobprobleme mit Alerts, Operatoren und Database Mail. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Konfigurationssnapshot plus begrenzte Ausführungshistorie. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_AgentMonitoringAnalysis]
      @HistoryHours = 24,
      @MitJobStatus = 1,
      @MitDatabaseMail = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `findings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Jobproblem, Alert, Operator, Mailstatus oder normalisierten Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Jobfehler, Alertkonfiguration, Operatorerreichbarkeit und Mailpfad getrennt prüfen und anschließend verbinden.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein Fehler kann unbemerkt bleiben, wenn Alert, Operator oder Mailpfad fehlt.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Database Mail ist nicht zwingend, wenn ein dokumentierter alternativer Alarmweg existiert.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Kritischer Job schlägt wiederholt fehl, aber kein aktiver Operator ist erreichbar: höheres Betriebsrisiko als der Jobfehler allein. Jobdetails und Monitoringprozess prüfen.

**Ähnlich aussehender Gegenfall:** Database Mail ist nicht zwingend, wenn ein dokumentierter alternativer Alarmweg existiert. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_AgentMonitoringAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | 24 Stunden lokale msdb-Evidenz mit Jobstatus und aggregiertem Database-Mail-Status, dazu aktuelle Service-/Alert-/Operator-/Schedulekonfiguration. |
| Teuerster Pfad | `@HistoryHours = 8760`, beide optionalen Pfade aktiv und unbegrenzte Ausgabe auf einer msdb mit umfangreicher Job- und Mailhistorie. Einen Datenbank- oder Jobfilter besitzt die Procedure nicht. |
| Haupttreiber | Zahl der Jobs, Alerts, Operatoren und Schedules sowie Job- und Database-Mail-Historyzeilen innerhalb `@HistoryHours`. Das spätere Findingslimit verkleinert diese vorgelagerte msdb-Aggregation nicht. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_AgentMonitoringAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und I/O auf Katalogen beziehungsweise msdb-Historie; TempDB für Korrelation und Transfer bei langen Meldungen. |
| Begrenzungswirkung | `@HistoryHours` begrenzt Jobhistory und Mailzeilen zeitlich. `@MitJobStatus`/`@MitDatabaseMail` können ganze Pfade auslassen. `@MaxZeilen` wirkt erst auf fertige Findings/Jobs und begrenzt die vorherige Konfigurations- und Historyaggregation nicht. |
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

### Zeit- und Scope-Modell

Konfigurationssnapshot plus begrenzte Ausführungshistorie.

### Bewertung und Gegenprobe

Fehlerhäufigkeit, letzter/aktueller Lauf, typische Dauer, Schedulemiss, Retry, Alertbedingungen, Operatorzeiten und Mailstatus korrelieren. Kritische Jobs nach Funktion priorisieren.

### Typische Fehlinterpretation

Keine Mail bedeutet nicht kein Fehler und ein erfolgreicher Mailtest nicht funktionierende Jobnotification. P95-/Baselinewerte sind bei wenigen Läufen schwach.

### Folgeanalyse

Agent Jobs, Jobstepoutput, Database Mail Logs und Current State.

## Primärquellen

- [SQL Server Agent](https://learn.microsoft.com/en-us/ssms/agent/sql-server-agent?view=sql-server-ver17)

[Technische Detailbeschreibung](../07_Infrastructure.md#11-monitorusp_agentmonitoringanalysis)
