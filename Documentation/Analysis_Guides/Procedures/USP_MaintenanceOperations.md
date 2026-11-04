# [monitor].[USP_MaintenanceOperations]

**Bereich:** Infrastruktur<br>
**Zweck:** Korrelierte read-only Sicht auf resumierbare Indexoperationen, technische Wartungsrequests, ADR/PVS und ausdrücklich ausgewählte Agent-Jobs.<br>
**Beobachtungsart:** Runtime-Snapshot + persistierter Operationszustand<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Wartungsoperationen laufen, sind pausiert/resumable oder blockiert, und wie belastbar ist ihre Fortschrittsanzeige?** Sie unterstützt die Entscheidung, ob Betriebsbereitschaft, Wiederherstellbarkeit oder verteilte Datenbewegung auffällig ist und welcher zuständige Teilprozess geprüft werden muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen erfolgreichen Restore, Failover oder End-to-End-Datenfluss nur aus Konfigurations- und Historymetadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_MaintenanceOperations]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Pipe-Liste exakter einteiliger SQL-Namen. Klammern schützen enthaltene Pipe-Zeichen. ]] maskiert eine schließende Klammer. Äußere Segmentleerzeichen werden entfernt. Ungültige Elemente werden abgelehnt. NULL, Leertext und reine Leerzeichen bedeuten keine exakte Einschränkung. Eine wirksame Liste darf nicht mit DatabaseNamePattern kombiniert werden. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt Systemdatenbanken aus. 1 erlaubt ihre Einbeziehung in Kandidaten. Ändert nicht die separaten Ausschlüsse fest kodierter Datenbanken/Quellen. NULL wird als ungültiger Bit-Wert abgelehnt. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | NULL deaktiviert das Muster. Ohne Präfix oder mit LIKE: gilt SQL LIKE mit % und _. REGEX: berücksichtigt Groß- und Kleinschreibung, REGEXI: ignoriert sie. Regex benötigt SQL Server 2025 und Compatibility Level 170. Leertext ist ungültig. Nicht mit wirksamer exakter Liste kombinieren. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 bestätigt keinen geschützten Pfad. 1 bestätigt einen tatsächlich aktivierten Pfad. NULL wird vom Candidate-Helper abgelehnt. Dieser Aufruf übergibt AnalysisClass=NULL und aktiviert damit keine zusätzliche Klassenprüfung. |
| `@JobNames` | `nvarchar(max)` | `NULL` | Pipe-Liste exakter einteiliger SQL-Namen. Klammern schützen enthaltene Pipe-Zeichen. ]] maskiert eine schließende Klammer. Äußere Segmentleerzeichen werden entfernt. Ungültige Elemente werden abgelehnt. Ohne wirksame Jobliste und ohne Jobmuster liest die Procedure keine Jobdaten. Eine nichtleere ungültige Liste ergibt INVALID_PARAMETER. Nicht mit JobNamePattern kombinieren. |
| `@JobNamePattern` | `nvarchar(4000)` | `NULL` | NULL deaktiviert das Jobmuster. Ohne Präfix oder mit LIKE: gilt SQL LIKE. REGEX: und REGEXI: ergeben UNAVAILABLE_FEATURE. Leertext und reine Leerzeichen ergeben INVALID_PARAMETER. Nicht mit JobNames kombinieren. |
| `@NurProblematisch` | `bit` | `0` | 0 zeigt alle bewerteten Befunde. 1 und NULL beschränken die vier fachlichen Mengen auf HIGH und MEDIUM. Die Filterung erfolgt nach dem Quellenlesen. |
| `@ResumablePausedWarnMinutes` | `int` | `60` | Warnschwelle in Minuten von 1 bis 525600. Zahlen außerhalb des Bereichs sind ungültig. NULL wird nicht ausdrücklich abgelehnt und erfüllt den Schwellwertvergleich nicht. |
| `@BlockedWarnMs` | `bigint` | `5000` | Nichtnegative Warnschwelle in Millisekunden bei positiver BlockingSessionId. Negative Werte sind ungültig. NULL erfüllt den Schwellwertvergleich nicht. |
| `@PvsWarnMb` | `decimal(19,2)` | `1024` | Nichtnegative PVS-Warnschwelle in MB. Die Warnung setzt zusätzlich die Grenze für abgebrochene Transaktionen voraus. Negative Werte sind ungültig. Bei NULL ist der gemeinsame Schwellwertvergleich nicht wahr. |
| `@AbortedTransactionsWarnCount` | `bigint` | `1` | Nichtnegative Mindestzahl abgebrochener Transaktionen für die gemeinsame PVS-Warnung. Negative Werte sind ungültig. Bei NULL ist der gemeinsame Schwellwertvergleich nicht wahr. |
| `@MaxZeilen` | `int` | `1000` | Je fachliche Menge: NULL oder 0 unbegrenzt, positiv Top-N nach jeweiliger Sortierung, negativ INVALID_PARAMETER. Wirkt nach vollständiger Quellenmaterialisierung und NurProblematisch-Auswahl. |
| `@LockTimeoutMs` | `int` | `0` | Nichtnegative Millisekunden für datenbanklokale Abfragen. 0 bedeutet NOWAIT. Negative Werte sind ungültig. NULL wird im Vorfeld nicht abgelehnt und kann beim Aufbau des dynamischen SQL zu fehlender Teilevidenz führen. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | CONSOLE zeigt resumableOperations mit Beschriftung. RAW liefert Modulstatus, fachliche Mengen und Quellenstatus. TABLE exportiert ausschließlich resumableOperations. NONE unterdrückt die Datenresultsets. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur mit ResultSetArt=TABLE erlaubt. JSON-Objekt mit genau dem Schlüssel resumableOperations und Zielnamen einer vorher angelegten, leeren lokalen #Temp-Tabelle mit genau einer Seed-Spalte. mapping wird vor fachlichen Quellen geprüft. NULL/leer bei TABLE führt zu Mapping-Fehler. Bei anderen Modi muss NULL/leer sein, sonst THROW 51011. Keine persistente Tabelle. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON in Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Ausgabeparameter. wird beim Eintritt auf NULL gesetzt und bei JSON-Erzeugung befüllt. Eingabewert wird ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |
| `@PrintMeldungen` | `bit` | `1` | 1 aktiviert informative Statusmeldungen. 0 und NULL unterdrücken sie. |
| `@Hilfe` | `bit` | `0` | 1 zeigt die Hilfe nach der TABLE-Vorprüfung und beendet vor dem Quellzugriff. 0 und NULL setzen die normale Verarbeitung fort. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Ausgabeparameter. Statuscode des Laufs, z.B. AVAILABLE/AVAILABLE_LIMITED/INVALID_PARAMETER. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Ausgabeparameter. 1 kennzeichnet unvollständige Evidenz, 0 vollständig im erreichbaren Scope. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | Ausgabeparameter für erfasste SQL-Fehlernummer. NULL wenn keiner erfasst wurde. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Ausgabeparameter für erfasste Fehlermeldung. NULL ohne Fehler. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden. |

## Aufrufbeispiele

```sql
EXEC [monitor].[USP_MaintenanceOperations] @Hilfe=1;
```

```sql
EXEC [monitor].[USP_MaintenanceOperations] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=50, @ResultSetArt='RAW';
```

```sql
DECLARE @ResultJson nvarchar(max);
EXEC [monitor].[USP_MaintenanceOperations] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT;
SELECT @ResultJson AS [Json];
```

```sql
CREATE TABLE #MaintenanceOperations_HelpExample ([Seed] int NULL);
BEGIN TRY EXEC [monitor].[USP_MaintenanceOperations] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"resumableOperations":"#MaintenanceOperations_HelpExample"}';
SELECT * FROM #MaintenanceOperations_HelpExample;
DROP TABLE #MaintenanceOperations_HelpExample;
END TRY BEGIN CATCH DROP TABLE #MaintenanceOperations_HelpExample;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert ausschließlich `resumableOperations` mit 15 Feldern. Das aktive CONSOLE zeigt dieselbe fachliche Menge. RAW und JSON enthalten zusätzlich Requests, ADR/PVS und ausdrücklich ausgewählte Jobs sowie Quellenstatus; Auswahlwarnings bleiben im vorhandenen RAW-Resultset. JSON besitzt kein zusätzliches Warning-Array. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Jede der vier fachlichen Mengen wird nach der vollständigen Befundbewertung einmal nach `@NurProblematisch` und `@MaxZeilen` ausgewählt. Die jeweilige Auswahl ist für alle Ausgabepfade identisch. Positive Limits wirken je fachlicher Menge; `NULL` und `0` bedeuten unbegrenzt. Negative Limits liefern `INVALID_PARAMETER` mit partieller, leerer Fachausgabe. Die acht Textfelder des TABLE-Exports verwenden explizit `SQL_Latin1_General_CP1_CS_AS`.

Quellenstatus und Modulstatus gelten für den vollständigen ausgewählten Quellenscope vor dem Ausgabelimit. Eine fehlende ausdrücklich gewählte Datenbank begrenzt das Modul zu `AVAILABLE_LIMITED/IsPartial=1`; erfolgreich gelesene Einzelquellen bleiben unabhängig davon erfolgreich.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer resumierbaren Indexoperation, einem laufenden Wartungsrequest, dem ADR/PVS-Zustand einer Datenbank, einem ausdrücklich gefilterten Job oder einem Quellenstatus.

## So lesen

Prüfen Sie zuerst Quellenstatus und Versionsgrenze. Ein pausierter resumierbarer Vorgang wird mit Alter und Fortschritt gelesen. Bewerten Sie bei Requests Blockierung, Wait, Fortschritt und Engine-Schätzung gemeinsam. PVS ist eine Momentaufnahme. Ohne `@JobNames` oder `@JobNamePattern` ist die Jobquelle absichtlich `NOT_REQUESTED`.

## Warum kann das problematisch sein?

Lange pausierte Indexoperationen, blockierte Wartung oder eine große PVS mit abgebrochenen Transaktionen können Ressourcen binden und geplante Wartungsziele verfehlen. Überlappende ausdrücklich gewählte Jobs können konkurrieren.

## Wann ist es kein Problem?

Eine Pause, eine lange Dauer, ein hoher I/O-Zähler oder ein laufender Rollback können beabsichtigt beziehungsweise arbeitsmengenbedingt sein. Ein einzelner PVS-Wert beweist keine Bereinigungsstörung. Jobnamen werden ohne explizite Auswahl nicht gelesen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Lange pausierte Indexoperationen, blockierte Wartung oder eine große PVS mit abgebrochenen Transaktionen können Ressourcen binden und geplante Wartungsziele verfehlen. Überlappende ausdrücklich gewählte Jobs können konkurrieren.

**Ähnlich aussehender Gegenfall:** Eine Pause, eine lange Dauer, ein hoher I/O-Zähler oder ein laufender Rollback können beabsichtigt beziehungsweise arbeitsmengenbedingt sein. Ein einzelner PVS-Wert beweist keine Bereinigungsstörung. Jobnamen werden ohne explizite Auswahl nicht gelesen. Derselbe Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei einer zeitgleichen SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Ein leerer Historypfad kann Retention/Cleanup, deaktivierte Komponente oder falschen Scope bedeuten; er beweist keine erfolgreiche Ausführung.

Für `USP_MaintenanceOperations` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Die Procedure führt kein `RESUME`, `ABORT`, `KILL`, Cleanup, Job-Start oder Job-Stop aus. Sie liest keine SQL-Texte, Jobschritte, Jobbefehle, Meldungen, Konten, Clientdaten oder Wait-Ressourcen.

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

**Wichtig für die Eigenlast:** Setzen Sie Datenbankscope vor `sys.index_resumable_operations` und PVS-Statistiken. Agent-Jobaktivität nur bei angefordertem Jobfilter lesen; SQL- und Plantexte gehören bewusst nicht zu diesem Pfad.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Requestsnapshot sowie den persistierten Zustand resumierbarer Operationen.

Der Collation-Runtimevertrag Common 161 verwendet eigene Datenbanken ohne Nutzdaten und vergleicht die PVS-Ausgabe mit unabhängigen nativen Metadaten. Interne ADR-Allokationen können die PVS-Größe zwischen Abfragen verändern. Der Vertrag prüft deshalb deren JSON-Zahlenwert innerhalb der Messgrenzen vor und unmittelbar nach dem Aufruf; die übrigen acht PVS-Felder, Properties, Typen und Häufigkeiten werden exakt verglichen. Ein fehlender oder nicht numerischer Größenknoten wird abgelehnt; NULL ist nur bei zwei nativen NULL-Messwerten zulässig. Der leere Resumable-Scope prüft Schema und Collation, liefert jedoch keine positive Resumable-Filter- oder Limitevidenz.

### Bewertung und Gegenprobe

Berücksichtigen Sie Command, Status, Percent Complete, Estimated Completion, DOP, Wait und Blocker, den Log-, TempDB- und I/O-Kontext sowie Resume- und Pauseoptionen. Eine pausierte Operation kann weiterhin Speicher und Strukturzustand belegen.

### Typische Fehlinterpretation

Percent Complete ist nur für unterstützte Commands und nicht linear. Abbruch kann Rollback-/Cleanupkosten verursachen; `PAUSED` ist nicht erfolgreich abgeschlossen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Current Requests/Blocking/IO/Log und operationsspezifischer Runbook.

## Primärquellen

- [Resumable Index Operations](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/perform-index-operations-online?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)
- [Ola Hallengren: SQL Server Backup – betriebliche Backup-Praxis](https://ola.hallengren.com/sql-server-backup.html)

[Technische Detailbeschreibung](../07_Infrastructure.md)
