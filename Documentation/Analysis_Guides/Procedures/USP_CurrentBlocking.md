# [monitor].[USP_CurrentBlocking]

**Bereich:** Current State<br>
**Zweck:** Rekonstruiert aktuelle Blockingkanten und -ketten bis zum Root Blocker und übersetzt technische Wait-/Lockressourcen in den sichtbaren Datenbank-, Objekt-, Index-, Partitions- oder Seitenkontext.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Session blockiert welche andere Session, und wo liegt der Root Blocker der Kette?** Der dokumentierte Zweck ist: Rekonstruiert aktuelle Blockingkanten und -ketten bis zum Root Blocker. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Ihr Zeitvertrag lautet ausdrücklich: Momentaufnahme. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentBlocking]
      @MinWaitMs = 1000,
      @BlockingObjektTiefe = 'STANDARD',
      @ResultSetArt = 'CONSOLE';
```

`STANDARD` ist der ressourcenschonende Default. Die Procedure dedupliziert ausschließlich Ressourcen bereits erkannter Blockingketten und löst höchstens `@MaxObjektAufloesungen` Kandidaten auf.

Für einen vollständigen Lockkontext:

```sql
EXEC [monitor].[USP_CurrentBlocking]
      @MinWaitMs = 1000,
      @BlockingObjektTiefe = 'DEEP',
      @MaxObjektAufloesungen = 500,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'RAW';
```

`DEEP` aktiviert zusätzlich `sys.dm_tran_locks` für die beteiligten Sessions und ist über `LOCKS_DEEP` gruppen- und bestätigungsgeschützt.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `blockingChains` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Im Kettenresultset beschreibt eine Zeile eine sichtbare Blockingbeziehung mit ihrem Root Blocker. `BlockingResourceName` ist die bestmögliche Übersetzung der weiterhin unverändert ausgegebenen `WaitResource`. Lockdetails besitzen eine eigene Granularität.

Das additive Ketten- und JSON-Schema trägt Version `2`.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst `BlockingResourceResolutionStatus` lesen:

- `RESOLVED`: ein fachlicher Name oder eine eindeutig klassifizierte Ressource wurde ermittelt;
- `PARTIAL`: Typ beziehungsweise Datenbank ist bekannt, eine tiefere Zuordnung war nicht möglich;
- `RAW_ONLY`: interne oder versionsabhängige Ressource ohne sichere Namensübersetzung;
- `SKIPPED_LIMIT`: Rohwert vorhanden, aber Kandidatenlimit erreicht;
- `SKIPPED`: Auflösung mit `NONE` deaktiviert;
- `TIMEOUT`: ausschließlich die Anreicherung dieses Kandidaten traf auf einen Lock;
- `DENIED_PERMISSION` oder `ERROR_HANDLED`: ausschließlich diese Anreicherung war nicht lesbar beziehungsweise schlug kontrolliert fehl;
- `INVALID_FORMAT` oder `EMPTY`: Quelle war nicht interpretierbar beziehungsweise leer.

Danach Waitzeit, `BlockingResourceName`, Aktivität und Transaktionszustand des Root Blockers vergleichen. `BlockingOwnerType` kennzeichnet neben Sessions auch die SQL-Server-Sonderblocker `ORPHAN_DTC`, `DEFERRED_RECOVERY`, `LATCH_OWNER_TRANSIENT` und `LATCH_OWNER_UNTRACKED`.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Viele Opfer können von einer einzelnen Root-Session abhängen. Das Beenden eines Opfers beseitigt die gehaltene Ressource nicht.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Kurze Lockwartezeiten gehören zur transaktionalen Konsistenz. Kritischer sind wachsende, wiederkehrende Ketten und SLA-Auswirkungen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Zehn Sessions warten zwei Minuten auf eine sleeping Session mit offener Transaktion: starke Root-Blocker-Evidenz. Mit `USP_CurrentTransactions` und `USP_CurrentRequests` prüfen; erst danach betriebliche Eingriffe erwägen.

**Ähnlich aussehender Gegenfall:** Kurze Lockwartezeiten gehören zur transaktionalen Konsistenz. Kritischer sind wachsende, wiederkehrende Ketten und SLA-Auswirkungen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentBlocking` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Standard gering. sys.dm_tran_locks wird nur bei expliziter Anforderung und nur für beteiligte Sessions gelesen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Gefilterter CONSOLE-Snapshot ohne breite Text- oder Lockdetails; gewöhnlich kurze Laufzeit. |
| Teuerster Pfad | `@MitLockDetails = 1` bei vielen beteiligten Sessions; erst dann wird `sys.dm_tran_locks` für den Kettenscope gelesen. |
| Haupttreiber | Zahl aktuell blockierter Requests/Waiting Tasks und die daraus rekonstruierten Kanten/Ketten. Sessionfilter und Mindestwait verkleinern Kandidaten; SQL-Text-/Input-Buffer-Auflösung verbreitert jede behaltene Session. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_CurrentBlocking ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Arbeitsspeicher für DMV-Korrelation und Sortierung; optional TempDB und Ergebnistransfer für Text-/Detailspalten. |
| Begrenzungswirkung | Filter reduzieren die Kandidaten früh, TOP/Zeilenlimits können aber erst nach DMV-Lesung, Join oder Aggregation wirken und begrenzen dann primär die Ausgabe. |
| Locking und Nebenwirkungen | Read-only gegenüber Nutzdaten. Flüchtige DMVs werden nacheinander gelesen; Katalog-/SQL-Textauflösung kann kurze interne Synchronisation verursachen, erzeugt aber keinen atomaren Snapshot. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `LOCKS_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Mit `@MitLockDetails = 0` beginnen; LOCKS_DEEP erst für eine bereits sichtbare Blockingkette und möglichst wenige Sessions freigeben. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Session blockiert welche andere Session, und wo liegt der Root Blocker der Kette?

### Technischer Hintergrund

Blocking entsteht, wenn ein Task einen Lock oder eine andere blockierende Ressource benötigt, die nicht verfügbar ist. Die Procedure korreliert Request-/Taskblocker, Sessions, SQL-Kontext und – nur in `DEEP` beziehungsweise mit expliziten Lockdetails – Locks.

Die leichte Auflösung interpretiert unter anderem `OBJECT`, `KEY`, `PAGE`, `RID`, `EXTENT`, `HOBT`, `OIB`, `DATABASE`, `FILE`, `APPLICATION`, `XACT`, numerische Page-Ressourcen, Metadata-Varianten und benannte interne Ressourcen. Für Page/RID/Extent wird `sys.dm_db_page_info(..., 'LIMITED')` ausschließlich für die begrenzten Kandidaten verwendet. Objekt-, Index-, Partitions-, Statistik- und Schema-Namen werden nur in den tatsächlich referenzierten Online-Datenbanken nachgeschlagen. Dafür werden bekannte IDs direkt mit `sys.objects`, `sys.schemas` und den weiteren Katalogsichten verbunden; Metadatenfunktionen wie `OBJECT_ID()` oder `OBJECT_NAME()` sind nicht Teil des Ausführungspfads. Das gilt auch bei `database_id = 2`: Eine bekannte TempDB-Objekt-ID wird direkt über `tempdb.sys.objects` aufgelöst.

Im tiefen Pfad kommen `DATABASE`, `FILE`, `OBJECT`, `PAGE`, `KEY`, `RID`, `HOBT`, `EXTENT`, `ALLOCATION_UNIT`, `APPLICATION`, `METADATA`, `XACT`, `OIB`, `ROW_GROUP` und künftige von `sys.dm_tran_locks` gelieferte Typen hinzu. `OIB` wird wie eine HoBt-Ressource behandelt. Bei `ROW_GROUP` und anderen Typen ohne dokumentierte stabile Objekt-ID-Beziehung bleiben Rohbeschreibung, Subtyp und Entity-ID erhalten; das Framework erfindet keine Objektzuordnung.

### Datenkette

`master.sys.databases`, `master.sys.master_files`, `sys.servers`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_os_waiting_tasks`, gezielt `sys.dm_db_page_info` sowie im tiefen Pfad `sys.dm_tran_locks`; für die begrenzten Kandidaten außerdem `sys.objects`, `sys.schemas`, `sys.indexes`, `sys.partitions`, `sys.allocation_units` und `sys.stats` der betroffenen Datenbanken.

### Zeit- und Scope-Modell

Momentaufnahme. Ketten können während der Rekonstruktion wachsen, verschwinden oder ihre Root-Session wechseln.

### Kosten und Grenzen

- `NONE` überspringt die Namensauflösung vollständig.
- `STANDARD` liest `sys.dm_tran_locks` nicht zusätzlich. Parsing erfolgt im Speicher; Katalog- und Page-Zugriffe sind dedupliziert und standardmäßig auf 100 Ressourcen begrenzt.
- `DEEP` liest Lockzeilen nur für Sessions der bereits erkannten Ketten. Der Pfad kann bei vielen Locks merkliche CPU- und DMV-Kosten verursachen und verlangt deshalb Freigabe und `@HighImpactConfirmed=1`.
- `@MaxObjektAufloesungen` akzeptiert 1 bis 1000. Bei Erreichen des Limits bleiben alle Rohressourcen sichtbar und der Status wird `SKIPPED_LIMIT` beziehungsweise `AVAILABLE_LIMITED`.
- `@MaxZeilen` begrenzt auch die erfassten Lockzeilen. Wer in einem kontrollierten Einzelaufruf wirklich jeden aktuell beobachteten nativen Locktyp sehen muss, kann `@MaxZeilen = 0` verwenden; die Namensauflösung bleibt trotzdem auf höchstens 1000 deduplizierte Kandidaten begrenzt.
- Der Blocking-/Wait-Snapshot wird zuerst in lokalen Temp-Tabellen materialisiert. Erst danach läuft jede deduplizierte Datenbank-, Datei-, Page- oder Kataloganreicherung in einem eigenen Batch mit `LOCK_TIMEOUT 0`. Timeout, fehlende Berechtigung oder Fehler markieren nur diesen Kandidaten; alle weiteren Kandidaten werden trotzdem verarbeitet.
- Die Meta-Zähler `ObjectResolutionResolvedCount`, `ObjectResolutionPartialCount`, `ObjectResolutionRawOnlyCount`, `ObjectResolutionTimeoutCount`, `ObjectResolutionDeniedCount`, `ObjectResolutionErrorCount` und `ObjectResolutionSkippedLimitCount` machen sichtbar, ob einzelne Anreicherungen fehlen. Rohressource und native IDs bleiben in jedem Fall erhalten.
- `NOLOCK` und mehrere flüchtige Quellen bilden keinen transaktional atomaren Snapshot. Eine zweite Messung kann andere Ketten oder Namen zeigen.
- Hashwerte eines `KEY`-Locks lassen sich nicht zuverlässig in den konkreten Schlüsselwert zurückrechnen. Die Auflösung endet deshalb bei Tabelle, Index und Partition.
- Nicht öffentlich dokumentierte oder versionsabhängige interne Ressourcen werden klassifiziert und roh ausgegeben, aber nur bei belastbarer ID-Beziehung auf ein Objekt abgebildet.

### Bewertung und Gegenprobe

Anzahl Opfer, längste Wartezeit, Lock-/Ressourcentyp, offene Transaktion und Zustand des Root Blockers gemeinsam bewerten. Ein aktiv arbeitender Root Blocker kann Fortschritt machen; ein sleeping Root Blocker mit alter Transaktion ist verdächtiger.

### Typische Fehlinterpretation

Die am längsten wartende Session ist nicht automatisch Ursache. `KILL` eines Opfers entfernt den Root Lock nicht; `KILL` des Root Blockers kann langen Rollback und weitere Last auslösen.

### Folgeanalyse

`USP_CurrentTransactions`, `USP_CurrentRequests`; für Historie Blocked-Process-/Deadlock-XE.

## Primärquellen

- [sys.dm_exec_requests und Sonderwerte von blocking_session_id](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-requests-transact-sql)
- [sys.dm_tran_locks](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-locks-transact-sql?view=sql-server-ver17)
- [sys.dm_db_page_info](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-page-info-transact-sql)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#3-monitorusp_currentblocking)
