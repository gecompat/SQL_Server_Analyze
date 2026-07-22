# [monitor].[USP_MaintenanceOperations]

**Bereich:** Infrastruktur<br>
**Zweck:** Korrelierte read-only Sicht auf resumierbare Indexoperationen, technische Wartungsrequests, ADR/PVS und ausdrücklich ausgewählte Agent-Jobs.<br>
**Beobachtungsart:** Runtime-Snapshot + persistierter Operationszustand<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Wartungsoperationen laufen, sind pausiert/resumable oder blockiert, und wie belastbar ist ihre Fortschrittsanzeige?** Der dokumentierte Zweck ist: Korrelierte read-only Sicht auf resumierbare Indexoperationen, technische Wartungsrequests, ADR/PVS und ausdrücklich ausgewählte Agent-Jobs. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Requestsnapshot plus persistierter resumable Zustand. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_MaintenanceOperations]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `resumableOperations` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer resumierbaren Indexoperation, einem laufenden Wartungsrequest, dem ADR/PVS-Zustand einer Datenbank, einem ausdrücklich gefilterten Job oder einem Quellenstatus.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst Quellenstatus und Versionsgrenze prüfen. Ein pausierter resumierbarer Vorgang wird mit Alter und Fortschritt gelesen. Bei Requests Blockierung, Wait, Fortschritt und Engine-Schätzung gemeinsam bewerten. PVS ist eine Momentaufnahme. Ohne `@JobNames` oder `@JobNamePattern` ist die Jobquelle absichtlich `NOT_REQUESTED`.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Lange pausierte Indexoperationen, blockierte Wartung oder eine große PVS mit abgebrochenen Transaktionen können Ressourcen binden und geplante Wartungsziele verfehlen. Überlappende ausdrücklich gewählte Jobs können konkurrieren.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Pause, lange Dauer, hoher IO-Zähler oder ein laufender Rollback können beabsichtigt beziehungsweise arbeitsmengenbedingt sein. Ein einzelner PVS-Wert beweist keine Bereinigungsstörung. Jobnamen werden ohne explizite Auswahl nicht einmal gelesen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Lange pausierte Indexoperationen, blockierte Wartung oder eine große PVS mit abgebrochenen Transaktionen können Ressourcen binden und geplante Wartungsziele verfehlen. Überlappende ausdrücklich gewählte Jobs können konkurrieren.

**Ähnlich aussehender Gegenfall:** Pause, lange Dauer, hoher IO-Zähler oder ein laufender Rollback können beabsichtigt beziehungsweise arbeitsmengenbedingt sein. Ein einzelner PVS-Wert beweist keine Bereinigungsstörung. Jobnamen werden ohne explizite Auswahl nicht einmal gelesen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_MaintenanceOperations` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Die Procedure führt kein `RESUME`, `ABORT`, `KILL`, Cleanup, Job-Start oder Job-Stop aus. Sie liest keine SQL-Texte, Jobschritte, Jobbefehle, Meldungen, Konten, Clientdaten oder Wait-Ressourcen.

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase`, Problemscope und ausdrücklich gewählte Agent-Jobs; aktueller Snapshot resumierbarer Operationen, Wartungsrequests und ADR/PVS. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, ungefilterte Jobauswahl, `@MaxZeilen = 0` und Problemscope aus bei vielen resumierbaren Indexoperationen, Requests, PVS-Zeilen und Jobs. Es gibt kein Historyfenster. |
| Haupttreiber | Zahl gewählter Datenbanken mit resumierbaren Indexoperationen/ADR-PVS-Kontext, aktuell passender technischer Requests und ausdrücklich ausgewählter Agent-Jobs samt Aktivität. Ohne Jobauswahl wird kein breites Jobinventar geöffnet. |
| Skalierung | Aufwand wächst mit Datenbanken, `sys.index_resumable_operations`, passenden Live-Requests, ADR/PVS-Metadaten und der gewählten Jobmenge. Teilquellen werden separat materialisiert und bewertet. |
| Ressourcen | CPU und Katalog-/DMV-/msdb-I/O sowie temporäre Tabellen für vier nicht atomare Snapshots; keine SQL-/Jobsteptexte oder Wait-Ressourcen. |
| Begrenzungswirkung | Datenbank- und Jobfilter begrenzen jeweilige Quellen. `@NurProblematisch` und `@MaxZeilen` wirken erst beim Ausgeben der bereits vollständig gesammelten Teilresultsets. |
| Locking und Nebenwirkungen | Read-only; kurze Schema-Stability-Zugriffe auf msdb/Systemkataloge. Jobs, Backups oder Wartung laufen parallel weiter, daher ist das Ergebnis nicht atomar. |
| Schutzmechanismus | Der Datenbankkandidatenpfad verwendet `@AnalysisClass = NULL`; `@HighImpactConfirmed` schaltet keinen Deep-Pfad frei. Schutz bieten Datenbank-/Jobscope, Problemscope und Locktimeout. |
| Sicherer Einsatz | Eine `ExampleDatabase`, kleine explizite Jobliste und `@NurProblematisch = 1`; Teilquellenstatus vor einer Korrelation lesen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Runtime-Snapshot + persistierter Operationszustand“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Wartungsoperationen laufen, sind pausiert/resumable oder blockiert, und wie belastbar ist ihre Fortschrittsanzeige?

### Technischer Hintergrund

Aktive BACKUP/RESTORE/DBCC/INDEX-Commands erscheinen in Requests; resumable Indexoperationen besitzen persistierte Katalogzeilen mit State, Start/Pause, Prozent und Ressourcenoptionen. Locks, Log, TempDB und I/O können die Laufzeit dominieren.

### Datenkette

`msdb.dbo.sysjobactivity`, `msdb.dbo.sysjobs`, `msdb.dbo.syssessions`, `sys.databases`, `sys.dm_exec_requests`, `sys.dm_tran_persistent_version_store_stats`, `sys.index_resumable_operations`.

### Source Select

Der aktuelle Requestpfad filtert Wartungsbefehle direkt an der DMV und ergänzt nur den Datenbanknamen:

```sql
SELECT
      [r].[session_id]
    , [r].[request_id]
    , [d].[name] AS [DatabaseName]
    , [r].[command]
    , [r].[percent_complete]
    , [r].[estimated_completion_time]
    , [r].[blocking_session_id]
    , [r].[wait_type]
FROM [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
LEFT JOIN [sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id] = [r].[database_id]
WHERE [r].[session_id] <> @@SPID
  AND
  (
       [r].[command] LIKE N'ALTER INDEX%'
    OR [r].[command] LIKE N'DBCC%'
    OR [r].[command] LIKE N'BACKUP%'
    OR [r].[command] LIKE N'RESTORE%'
    OR [r].[command] LIKE N'ROLLBACK%'
  );
```

**Wichtig für die Eigenlast:** Datenbankscope vor `sys.index_resumable_operations` und PVS-Statistiken setzen. Agent-Jobaktivität nur bei angefordertem Jobfilter lesen; SQL- und Plantexte gehören bewusst nicht zu diesem Pfad.

### Zeit- und Scope-Modell

Aktueller Requestsnapshot plus persistierter resumable Zustand.

### Bewertung und Gegenprobe

Command, Status, Percent Complete, Estimated Completion, DOP, Wait/Blocker, Log-/TempDB-/I/O-Kontext und Resume/Pauseoptionen lesen. Pausierte Operation kann weiterhin Speicher/Strukturzustand belegen.

### Typische Fehlinterpretation

Percent Complete ist nur für unterstützte Commands und nicht linear. Abbruch kann Rollback-/Cleanupkosten verursachen; `PAUSED` ist nicht erfolgreich abgeschlossen.

### Folgeanalyse

Current Requests/Blocking/IO/Log und operationsspezifischer Runbook.

## Primärquellen

- [Resumable Index Operations](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/perform-index-operations-online?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)
- [Ola Hallengren: SQL Server Backup – betriebliche Backup-Praxis](https://ola.hallengren.com/sql-server-backup.html)

[Technische Detailbeschreibung](../07_Infrastructure.md)
