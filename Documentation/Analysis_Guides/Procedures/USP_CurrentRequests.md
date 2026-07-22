# [monitor].[USP_CurrentRequests]

**Bereich:** Current State<br>
**Zweck:** Ordnet aktuell laufende Requests nach Laufzeit, CPU, I/O, Wait, Blocking, Memory Grant und Ausführungskontext ein.<br>
**Beobachtungsart:** flüchtige Instanz-Momentaufnahme<br>
**Kostenklasse:** `LOW` bis `MEDIUM`

## Entscheidungsfrage und Einsatz

Diese Auswertung beantwortet: **Welche Requests sind genau jetzt aktiv, worin ist ihre bisherige Laufzeit gebunden und welche nächste Analyse ist dafür sinnvoll?** Sie ist der Einstieg bei einem akuten Hänger, plötzlich hoher CPU, sichtbarem Blocking, wartenden Memory Grants oder einer einzelnen unerwartet langen Ausführung.

Das Ergebnis soll noch keine Änderung auslösen. Es trennt zunächst vier Arbeitsrichtungen:

- überwiegend CPU und viele Reads → Query-/Plan- und Datenmengenkontext prüfen,
- überwiegend Warten mit Blocker → Blockingkette und offene Transaktion prüfen,
- wartender oder übergroßer Grant → Memory-Grant- und Kardinalitätsevidenz prüfen,
- kurze, erwartete Arbeit ohne Konkurrenzwirkung → möglicherweise kein Problem.

## Nicht beantwortete Fragen

Die Procedure zeigt keine beendeten Requests und keine verlässliche Historie. Ein Request, der zwischen zwei Aufrufen startet und endet, bleibt unsichtbar. Sie beweist weder die Root Cause eines Waits noch die Qualität eines Ausführungsplans, die Geschäftsauswirkung oder das übliche Lastniveau.

`BlockingSessionId` zeigt den unmittelbaren Blocker, nicht zwingend den Root Blocker. `SqlText`, Handles und Query Hashes liefern Korrelationsschlüssel, aber keinen Planinhalt. Für Trends oder bereits abgeschlossene Ausführungen sind Query Store, Extended Events oder eine geplante Stichprobe geeigneter.

## Sicherer Einstieg

Der erste Lauf reduziert Text-, Modul- und Input-Buffer-Arbeit und begrenzt die Ergebnismenge:

```sql
EXEC [monitor].[USP_CurrentRequests]
      @MaxZeilen = 50,
      @MitSqlText = 0,
      @ModulInfoEinbeziehen = 0,
      @InputBufferEinbeziehen = 0,
      @ResultSetArt = 'CONSOLE';
```

Erst danach einen auffälligen Request gezielt mit Textkontext nachlesen. Die Variable ist ausdrücklich synthetisch:

```sql
DECLARE @ExampleSessionId smallint = 57;
DECLARE @ExampleSessionIds nvarchar(max) = CONVERT(nvarchar(10), @ExampleSessionId);

EXEC [monitor].[USP_CurrentRequests]
      @SessionIds = @ExampleSessionIds,
      @MitSqlText = 1,
      @GesamtenSqlTextEinbeziehen = 0,
      @InputBufferEinbeziehen = 0,
      @ModulInfoEinbeziehen = 1,
      @MaxSqlTextZeichen = 4000,
      @ResultSetArt = 'RAW';
```

SQL-Text, Login, Host, Programm, Clientadresse und Input Buffer können in einer realen Laufzeitumgebung schutzbedürftige Inhalte enthalten. Ergebnisse nur im erforderlichen Umfang anzeigen und nicht ungeprüft exportieren oder weitergeben.

Object-Explorer-, Copilot- und SQL-Prompt-Hintergrundrequests sind
standardmäßig ausgeblendet. Für eine bewusste Vollansicht gilt:

```sql
EXEC [monitor].[USP_CurrentRequests]
      @ToolHintergrundabfragenEinbeziehen = 1,
      @ResultSetArt = 'CONSOLE';
```

Die [LIKE-Regeln und ihre Grenzen](../../Architecture/Tool_Background_Query_Filtering.md)
sind zentral dokumentiert. Die clientseitige Kennzeichnung ist keine
Sicherheitsidentität.

## Resultsets und Leserichtung

- `CONSOLE` liefert genau ein fachliches Resultset aus der materialisierten Requestmenge. Es eignet sich für die erste Sichtung.
- `RAW` liefert zuerst den Modulstatus, danach die vollständigen Requests mit Wait-Kataloganreicherung und zuletzt optionale Warnungen. Für eine belastbare Analyse immer erst `StatusCode`, `IsPartial`, `HasMoreRows` und `RequiredPermission` lesen.
- `TABLE` schreibt ausschließlich das im Inventar benannte Primärergebnis `requests` in die über `@ResultTablesJson` zugeordnete lokale Temp-Tabelle. Status und Warnungen werden nicht als eigene TABLE-Ergebnisse exportiert.
- `@JsonErzeugen = 1` trennt `meta`, `requests`, `statements`, `batches`, `inputBuffers` und `warnings`.

Eine Statuszeile ist keine Requestzeile. Eine Warnung zur Modulauflösung macht die bereits gelesenen Requestwerte nicht automatisch falsch, kann aber Namen und Kontext unvollständig lassen.

## Eine Zeile bedeutet

Eine Zeile in `requests` entspricht der zum Lesezeitpunkt sichtbaren Kombination aus `SessionId` und `RequestId`. Sie ist kein Task und kein historischer Ausführungsdatensatz. Ein paralleler Request kann mehrere Tasks und gleichzeitig unterschiedliche Task-Waits besitzen, bleibt aber eine Requestzeile.

Die Zähler `ElapsedMs`, `CpuMs`, `LogicalReads`, `Reads`, `Writes` und `RowCount` gelten für die bisherige Lebensdauer dieses Requests. Sie sind keine Rate pro Sekunde. `WaitTimeMs` beschreibt den aktuell auf `sys.dm_exec_requests` sichtbaren Request-Wait; `WaitingTaskCount`, `MaxTaskWaitMs` und `TaskWaitTypes` werden zusätzlich aus Waiting Tasks für die Session aggregiert. Bei mehreren gleichzeitigen Requests derselben Session, etwa durch MARS, ist diese Sessionaggregation nicht exklusiv einem einzelnen Request zuzurechnen.

## So lesen

1. **Vollständigkeit:** In `RAW` Status, partielle Sicht und Zeilenlimit prüfen. Ohne vollständige Server-State-Berechtigung kann die Engine nur eingeschränkte Sessions zeigen.
2. **Identität und Scope:** `SessionId`, `RequestId`, Datenbank, Command und Startzeit bestimmen. Die aktuelle eigene Session, System-Sessions und erkannte Tool-Hintergrundrequests sind standardmäßig ausgeschlossen. Bei Opt-in Regelcode und Konfidenz prüfen.
3. **Zeitaufteilung:** `ElapsedMs` mit `CpuMs` vergleichen. CPU ist verbrauchte Rechenzeit, Elapsed ist verstrichene Wanduhrzeit. Die Differenz ist nicht automatisch ein einzelner Wait, sondern kann verschiedene Warte- und Runnable-Phasen enthalten.
4. **Arbeit:** `LogicalReads`, physische `Reads`, `Writes` und `RowCount` gemeinsam lesen. Viele Logical Reads zeigen Seitenzugriffe im Buffer Pool, nicht automatisch langsames Storage. Bei parallelen Row-Mode-Requests weist Microsoft darauf hin, dass bestimmte Zähler in `sys.dm_exec_requests` nur am Coordinator sichtbar und dort nicht für alle Worker fortgeschrieben werden; sie sind dann keine vollständige Tasksumme.
5. **Warten und Blocking:** `WaitType`, `WaitTimeMs`, `TaskWaitTypes`, `BlockingSessionId` und `WaitResource` zusammen bewerten. Der Wait-Katalog liefert eine Einordnung, keine Root-Cause-Garantie.
6. **Memory und Parallelität:** angeforderten, gewährten und verwendeten Grant sowie `Dop` und `ParallelWorkerCount` vergleichen. `NULL` kann bedeuten, dass kein Query-Execution-Memory-Grant existiert; 0 ist ein tatsächlich gelieferter Zahlenwert.
7. **Text und Modul:** aktiven Statementausschnitt vor Batchtext lesen. `CurrentStatementIsTruncated`, Offsetgültigkeit und Verschlüsselung prüfen, bevor aus fehlendem oder abgeschnittenem Text geschlossen wird.

## Warum kann das problematisch sein?

Ein Request mit hoher Elapsed-Zeit und sehr wenig CPU kann Durchsatz oder Antwortzeit beeinträchtigen, wenn er auf einen Lock, I/O, einen Grant oder Schedulerzeit wartet. Ein Blocker kann weitere Sessions kaskadenartig zurückhalten. Hohe CPU zusammen mit hohen Logical Reads kann Konkurrenz um Scheduler und Buffer Pool erzeugen. Ein wartender Memory Grant kann eine Queue aufbauen, obwohl der Request selbst noch kaum CPU verbraucht hat.

Die Auswirkung entsteht aber nicht aus dem Einzelwert allein. Entscheidend sind Parallelität, Zahl betroffener Sessions, Dauer, SLA und ob die Arbeit erwartet ist. Auch die Diagnoseabfrage selbst aggregiert Waiting Tasks, sortiert Kandidaten und kann SQL-Text materialisieren; bei sehr vielen aktiven Requests ist sie nicht kostenlos.

## Wann ist es kein Problem?

Hohe CPU kann bei einer erwarteten, kurzen analytischen Abfrage produktive Arbeit sein. Viele Logical Reads können für einen kontrollierten Scan mit passender Laufzeit und ohne Konkurrenz akzeptabel sein. Ein kurzer Lock-Wait ist im normalen Transaktionsbetrieb üblich. Ein großer gewährter Grant ist nicht automatisch schädlich, wenn genügend Speicher verfügbar ist, keine Queue besteht und die tatsächliche Nutzung plausibel ist.

Ebenso ist `PercentComplete = NULL` kein Fehler: SQL Server liefert Fortschritt nur für bestimmte Commands. Ein fehlender Blocker bei einem Wait ist nicht widersprüchlich; viele Waitarten besitzen keinen Sessionblocker.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall `ExampleBlockedRequest`:** `ElapsedMs = 180000`, `CpuMs = 900`, `WaitType = LCK_M_X`, `WaitTimeMs = 176000` und `BlockingSessionId = 57`. Beobachtung: Fast die gesamte Wanduhrzeit wurde nicht als CPU verbraucht, und aktuell ist ein inkompatibler Lock sichtbar. Hypothese: Blocking dominiert die Antwortzeit. Gegenprobe: Mit `USP_CurrentBlocking` die vollständige Kette und mit `USP_CurrentTransactions` Alter und Logwirkung der Root-Transaktion prüfen. Noch keine Session beenden.

**Ähnlich auffällig, aber nicht automatisch problematisch `ExampleExpectedAnalytics`:** `ElapsedMs = 180000`, `CpuMs = 162000`, hohe Logical Reads, kein Wait und kein Blocker. Das ist CPU-/datenintensive Arbeit, aber noch kein Beweis für einen schlechten Plan. Erwartete Ausführung, DOP, gleichzeitige Konkurrenz, Query-Store-Vergleich und Planoperatoren entscheiden über die Bewertung.

**Nicht entscheidbarer Grantfall `ExampleGrant`:** `RequestedMemoryMb = 2048`, `GrantedMemoryMb = 2048`, `UsedMemoryMb = 180`. Die Differenz kann auf eine Überschätzung hinweisen, beweist sie aber nicht aus einem Snapshot. Wiederholbarkeit, Spillhinweise, Kardinalitätsschätzungen und konkurrierende Grants sind die Gegenprobe.

## Leere oder partielle Ausgabe

Keine Requestzeile bedeutet nur: Zum Snapshot war nach allen Filtern kein sichtbarer Request übrig. Mögliche Erklärungen sind ein tatsächlich ruhiger Moment, ein bereits beendeter Request, Ausschluss der eigenen oder von System-Sessions, ein zu enger Zeit-/Text-/Namensfilter, ein Zeilenlimit oder eingeschränkte Berechtigungen.

`AVAILABLE_LIMITED` weist auf eingeschränkte Server-Sicht hin. `PARTIAL_RESULT` kann entstehen, wenn Requests gelesen wurden, aber eine optionale Modulauflösung in einer Datenbank fehlschlug. Fehlender SQL-Text kann außerdem durch deaktivierte Textoptionen, ein verschlüsseltes Modul, ein nicht mehr gültiges Handle oder fehlenden Textkontext entstehen. `HasMoreRows = 1` bedeutet, dass der gewählte Ergebnis-Scope gekürzt wurde.

Ein zweiter Aufruf kann eine andere Menge liefern, ohne dass der erste falsch war: Die beteiligten DMVs werden nacheinander gelesen, während Requests und Tasks ihren Zustand ändern.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | `LOW` bis `MEDIUM`; kein physischer Benutzertabellenscan, aber variable Live-DMV-, Text-, Aggregations- und Sortierarbeit |
| Standardpfad | Der oben dokumentierte Lauf mit 50 Zeilen ohne SQL-Text, Modulauflösung und Input Buffer ist `LOW`. |
| Teuerster Pfad | Unbegrenzte Ausgabe mit vielen aktiven Requests, mehreren Regexfiltern, vollständigem Batchtext, Input Buffers, datenbankübergreifender Modulauflösung und JSON-Erzeugung ist `MEDIUM`. |
| Haupttreiber | Zahl aktiver Requests und Waiting Tasks, Textlänge, Anzahl aufzulösender Moduldatenbanken, Regexprüfung, Sortierung und Ausgabebreite |
| Skalierung | CPU und Speicher wachsen mit Aggregation/Sortierung; Metadatenzugriffe mit Moduldatenbanken; Transfer und Clientspeicher mit Text, JSON und Zeilenzahl. |
| Ressourcen | primär CPU, Arbeitsspeicher/Memory Grant der Diagnose, Metadatenzugriffe und Ergebnistransfer; nur temporäre eigene Datenstrukturen |
| Begrenzungswirkung | Ohne Regex materialisiert die Procedure höchstens `@MaxZeilen + 1` sortierte Kandidaten. Das garantiert wegen Filterung, Waiting-Task-Aggregation und Sortierung keinen entsprechend kleinen DMV-Quellzugriff. Bei Regex werden zunächst alle Kandidaten materialisiert und erst danach gelöscht und gekürzt. |
| Locking und Nebenwirkungen | `LOCK_TIMEOUT 0` verhindert Lock-Warten der Procedure; DMV-/Kataloglesungen verwenden überwiegend `NOLOCK`. Es werden keine Benutzerdaten geändert. Ausgabe kann jedoch schutzbedürftigen Laufzeittext enthalten. |
| Schutzmechanismus | endliches Defaultlimit, Ausschluss der eigenen und von System-Sessions sowie abschaltbare Textpfade; kein zusätzlicher High-Impact-Gate-Pfad in dieser Procedure |
| Sicherer Einsatz | erst kleine CONSOLE-Sicht ohne Texte, danach einzelne synthetisch identifizierte Session in RAW vertiefen; unlimitierte Text-/Regexläufe auf stark belasteten Instanzen vermeiden |
| Aussagegrenze | Snapshot ist nicht atomar oder historisch; Limit und Filter können relevante Requests ausblenden; Session-Waitaggregation kann bei mehreren Requests breiter als die Requestzeile sein. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Was führt SQL Server im Erfassungsmoment aus, worin wurde bisher Zeit und Arbeit investiert, und welche unabhängige Evidenz soll als Nächstes erhoben werden?

### Technischer Hintergrund

`sys.dm_exec_requests` liefert den Requestkern: Status, Command, bisherige Zeit-/I/O-Zähler, aktuellen Wait, Blocker, Handles und Statementoffsets. Sessions und Connections ergänzen Herkunft und Verbindung. Waiting Tasks verdichten das Taskbild, Query Memory Grants den Workspace-Memory-Zustand, Resource Governor die Workloadgruppe. `sys.dm_exec_sql_text` und `TVF_StatementText` trennen den aktiven Statementausschnitt vom gesamten Batch.

Die Quellen werden nicht in einem transaktional konsistenten Snapshot eingefroren. Der Request kann zwischen Kernlesung, optionaler Modulauflösung und Input-Buffer-Ergänzung weiterlaufen oder enden. Darum sind kleine Abweichungen zwischen Status, Wait und Taskbild erwartbar.

### Datenkette

1. Listen- und Patternfilter werden validiert; Regex ist erst ab dem dafür vorgesehenen SQL-Server-/Compatibility-Level verfügbar.
2. `sys.dm_exec_requests` wird mit `sys.dm_exec_sessions`, `sys.dm_exec_connections` und `sys.databases` verbunden.
3. Pro sichtbarer Session werden Waiting Tasks aggregiert; Memory Grants und Resource-Governor-Zuordnung werden ergänzt.
4. Nur wenn Text oder Modulkontext benötigt wird, werden SQL-Text und Statementoffsets aufgelöst.
5. Exakte und LIKE-Filter wirken in der Quellabfrage. Regexfilter wirken nach der Materialisierung in der Temp-Tabelle.
6. Das Ergebnis wird nach Relevanz, CPU, Reads oder Dauer sortiert und auf die gewünschte Zeilenzahl gekürzt.
7. Optional folgen je betroffener Datenbank die Modulauflösung und je verbliebener Request der Input Buffer; Texte werden erst danach auf `@MaxSqlTextZeichen` gekürzt.
8. Ausgabe erfolgt als CONSOLE, RAW, TABLE und/oder JSON.

### Source Select

Das zentrale Live-Select verbindet laufende Requests mit Session und Connection; optionale Quellen werden erst später ergänzt:

```sql
SELECT
      [r].[session_id]
    , [r].[request_id]
    , [r].[status]
    , [r].[command]
    , [r].[total_elapsed_time]
    , [r].[cpu_time]
    , [r].[logical_reads]
    , [r].[wait_type]
    , [r].[blocking_session_id]
    , [s].[program_name]
    , [c].[client_net_address]
FROM [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
JOIN [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK)
  ON [s].[session_id] = [r].[session_id]
LEFT JOIN [sys].[dm_exec_connections] AS [c] WITH (NOLOCK)
  ON [c].[session_id] = [r].[session_id]
WHERE [r].[session_id] <> @@SPID
  AND [s].[is_user_process] = 1
  AND [r].[total_elapsed_time] >= @MinDauerMs;
```

**Wichtig für die Eigenlast:** Exakte Session-, Datenbank- und Dauerfilter vor Waiting-Task-, Grant-, SQL-Text-, Modul- und Input-Buffer-Anreicherung setzen. Regex wirkt erst nach Materialisierung und spart daher keine DMV-Quellarbeit.

### Zeit- und Scope-Modell

Instanzweite Live-Momentaufnahme der sichtbaren aktiven Requests. Zähler beginnen mit dem jeweiligen Request; sie besitzen keinen gemeinsamen globalen Resetzeitpunkt. Session-IDs können nach Sessionende wiederverwendet werden, daher für spätere Korrelation mindestens Startzeit und RequestId mitführen. Das Ergebnis enthält standardmäßig User-Requests außer der aufrufenden Session; Filter verengen diesen Scope.

### Bewertung und Gegenprobe

Elapsed, CPU, Reads/Writes, aktueller Wait, Task-Waits, Blocking, Grant und DOP bilden zusammen eine Hypothese. Blocking wird mit Blockingkette/Transaktion bestätigt; CPU/Reads mit Query Store und Plan; Grants mit `USP_CurrentMemoryGrants`; I/O-Vermutungen mit Datei- und Betriebssystemevidenz. Eine zweite Quelle sollte einen anderen Messmechanismus besitzen und nicht nur dieselbe DMV anders sortieren.

### Typische Fehlinterpretation

`ElapsedMs - CpuMs` ist keine exakt gemessene Waitzeit. `WaitType` ist ein Momentwert, der letzte oder parallele Phasen nicht vollständig beschreibt. Ein hoher kumulierter Read-Wert beweist keinen aktuellen Storageengpass; bei parallelem Row Mode können Requestzähler außerdem die Workerarbeit unvollständig repräsentieren. Batchtext ist nicht automatisch das aktive Statement. `NOLOCK` macht die nacheinander gelesenen DMVs nicht atomar.

### Folgeanalyse

- Blocking: `USP_CurrentBlocking` und `USP_CurrentTransactions`
- Memory Grant: `USP_CurrentMemoryGrants`
- CPU/Reads und Verlauf: `USP_QueryStats` oder Query Store, anschließend `USP_ShowplanAnalysis`
- Dateilatenz: `USP_CurrentIO`
- wiederholt sehr kurzer Zustand: geplante XE- oder Stichprobenerfassung statt manuellem Polling

## Primärquellen

- [sys.dm_exec_requests](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-requests-transact-sql?view=sql-server-ver17)
- [sys.dm_os_waiting_tasks](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-waiting-tasks-transact-sql?view=sql-server-ver17)
- [sys.dm_exec_query_memory_grants](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-exec-query-memory-grants-transact-sql?view=sql-server-ver17)
- [sys.dm_exec_sql_text](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sql-text-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../02_Current_State.md#2-monitorusp_currentrequests)
