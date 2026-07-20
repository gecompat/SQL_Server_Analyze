# [monitor].[USP_CurrentBlocking]

**Bereich:** Current State<br>
**Zweck:** Rekonstruiert aktuelle Blockingkanten und -ketten bis zum Root Blocker.<br>
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
      @ResultSetArt = 'CONSOLE';
```

Lockdetails nur gezielt aktivieren.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `blockingChains` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Im Kettenresultset beschreibt eine Zeile eine Blockingkante. Eine vollständige Kette besteht häufig aus mehreren Zeilen; Lockdetails besitzen eine eigene Granularität.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Vom `LeafSessionId` über jede Kante bis `RootBlockingSessionId` gehen. Waitzeit, Ressource, Aktivität und Transaktionszustand des Root Blockers vergleichen.

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

Blocking entsteht, wenn ein Task einen Lock oder eine andere blockierende Ressource benötigt, die inkompatibel gehalten wird. Die Procedure korreliert Request-/Taskblocker, Sessions, SQL-Kontext und Locks und rekonstruiert Kanten beziehungsweise Ketten. Ein Root Blocker ist die oberste sichtbare Session ohne weiteren sichtbaren Blocker.

### Datenkette

`master.sys.databases`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_os_waiting_tasks`, `sys.dm_tran_locks`.

### Zeit- und Scope-Modell

Momentaufnahme. Ketten können während der Rekonstruktion wachsen, verschwinden oder ihre Root-Session wechseln.

### Bewertung und Gegenprobe

Anzahl Opfer, längste Wartezeit, Lock-/Ressourcentyp, offene Transaktion und Zustand des Root Blockers gemeinsam bewerten. Ein aktiv arbeitender Root Blocker kann Fortschritt machen; ein sleeping Root Blocker mit alter Transaktion ist verdächtiger.

### Typische Fehlinterpretation

Die am längsten wartende Session ist nicht automatisch Ursache. `KILL` eines Opfers entfernt den Root Lock nicht; `KILL` des Root Blockers kann langen Rollback und weitere Last auslösen.

### Folgeanalyse

`USP_CurrentTransactions`, `USP_CurrentRequests`; für Historie Blocked-Process-/Deadlock-XE.

## Primärquellen

- [sys.dm_tran_locks](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-tran-locks-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#3-monitorusp_currentblocking)
