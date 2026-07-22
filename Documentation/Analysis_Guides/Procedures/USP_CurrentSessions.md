# [monitor].[USP_CurrentSessions]

**Bereich:** Current State<br>
**Zweck:** Inventarisiert aktuelle Sessions, Verbindungskontext, kumulative Aktivität und offene Transaktionen.<br>
**Beobachtungsart:** Snapshot + kumulative Sessionzähler<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Sessions sind verbunden, welchen Kontext besitzen sie und gibt es inaktive Sessions mit fortwirkendem Zustand?** Der dokumentierte Zweck ist: Inventarisiert aktuelle Sessions, Verbindungskontext, kumulative Aktivität und offene Transaktionen. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Ihr Zeitvertrag lautet ausdrücklich: Sessionmomentaufnahme mit kumulativen Zählern seit Sessionbeginn. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentSessions]
      @MitSqlText = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Der Einstieg erhebt Session- und Requestmetadaten ohne SQL-Text. Bei einer
auffälligen Session anschließend über `@SessionIds` eingrenzen und Text nur für
diesen Kandidaten ergänzen.

Erkannte Tool-Hintergrundsessions sind im Default ausgeblendet. Mit
`@ToolHintergrundabfragenEinbeziehen = 1` werden sie samt Regelcode, Kategorie,
Erkennungsart und Konfidenz sichtbar. Die Erkennung ist eine
[konfigurierbare Diagnoseheuristik](../../Architecture/Tool_Background_Query_Filtering.md),
kein Sicherheitsmerkmal.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `sessions` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile beschreibt eine aktuell sichtbare Session; ein Request kann fehlen, wenn die Session gerade inaktiv ist.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Zuerst `SessionStatus`, `RequestStatus` und `OpenTransactionCount`, danach letzte Aktivität, kumulative CPU/I/O-Werte und Verbindungsinformationen. Bei eingeblendeten Tool-Sessions `ToolBackgroundRuleCode` und `ToolBackgroundConfidence` mitlesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

`sleeping` plus offene Transaktion bedeutet: Der Client führt nichts aus, hält aber möglicherweise Locks und verhindert Log-Wiederverwendung.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Eine lange angemeldete sleeping Session ohne offene Transaktion ist bei Connection Pools normal. Das Login-Alter allein ist kein Befund.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Acht Stunden verbunden, letzte Aktivität vor zehn Sekunden, keine offene Transaktion: unauffällig. Dieselbe Session mit zwei Stunden alter Transaktion: `USP_CurrentTransactions` und Blocking prüfen.

**Ähnlich aussehender Gegenfall:** Eine lange angemeldete sleeping Session ohne offene Transaktion ist bei Connection Pools normal. Das Login-Alter allein ist kein Befund. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentSessions` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Ein eingeschränkter Berechtigungsscope kann fremde Sessions ausblenden. Vor einer Entwarnung Status, eigene Sessionfilter und Systemsessionfilter prüfen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Maximal 500 sichtbare User-Sessions einschließlich inaktiver Sessions, ohne SQL-Text. Pro Session wird höchstens ein aktueller Request korreliert. |
| Teuerster Pfad | `@MaxZeilen = 0`, System- und inaktive Sessions, `@MitSqlText = 1` ohne Zeichenlimit sowie mehrere Regexfilter. Regex wird nach der unbeschränkten Kandidatenmaterialisierung angewandt. |
| Haupttreiber | Zahl sichtbarer Sessions und korrelierter Connections/Requests. System-/Inaktivscope, SQL-Textbreite und späte Regexfilter bestimmen, ob nur eine frühe N+1-Kandidatenmenge oder alle vorgefilterten Sessions materialisiert werden. |
| Skalierung | Ohne Regex wird die Kandidatenmenge auf `@MaxZeilen + 1` begrenzt. Mit Regex wachsen Materialisierung und dynamische Nachfilterung mit allen vorgefilterten Sessions; SQL-Textbreite erhöht zusätzlich Speicher und Transfer. |
| Ressourcen | CPU und Arbeitsspeicher für Session-/Connection-/Request-Joins, Sortierung und optional Regex; bei SQL-Text zusätzlicher Cachezugriff und Ergebnistransfer. |
| Begrenzungswirkung | Exakte Listen und LIKE-Prädikate wirken in der DMV-Abfrage. Regex wird erst nach Materialisierung per `DELETE` angewandt, weshalb das frühe TOP bewusst entfällt. Das spätere `@MaxZeilen` reduziert dann nur das behaltene Resultset. |
| Locking und Nebenwirkungen | Read-only gegenüber Nutzdaten. Flüchtige DMVs werden nacheinander gelesen; Katalog-/SQL-Textauflösung kann kurze interne Synchronisation verursachen, erzeugt aber keinen atomaren Snapshot. |
| Schutzmechanismus | Es gibt kein Deep-Gate. `@HighImpactConfirmed` ist in der aktuellen Implementierung nur Signaturkompatibilität und wird nach der Deklaration nicht ausgewertet; wirksame Schutzgrenzen sind Sessionfilter, Defaultlimit 500 und `@MitSqlText = 0`. |
| Sicherer Einsatz | Mit User-Scope, endlichem Limit, SQL-Text aus und möglichst exakten/LIKE-Filtern beginnen. Regex und ungekürzten Text erst nach Abschätzung der sichtbaren Sessionmenge aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + kumulative Sessionzähler“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Sessions sind verbunden, welchen Kontext besitzen sie und gibt es inaktive Sessions mit fortwirkendem Zustand?

### Technischer Hintergrund

`sys.dm_exec_sessions` hält den Sitzungskontext, während `sys.dm_exec_connections` Transport-/Verbindungsdaten und `sys.dm_exec_requests` aktuelle Arbeit ergänzt. Sessionzähler wie CPU oder Reads akkumulieren über die Session; Connection Pools können Sessions lange offen und `sleeping` halten.

### Datenkette

`master.sys.databases`, `sys.databases`, `sys.dm_exec_connections`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.sp_executesql`.

### Source Select

Das Grundselect zeigt die Session als führende Quelle und die optional vorhandene Connection beziehungsweise den aktuellen Request:

```sql
SELECT
      [s].[session_id]
    , [s].[status] AS [SessionStatus]
    , [s].[open_transaction_count]
    , [s].[cpu_time]
    , [s].[logical_reads]
    , [c].[connect_time]
    , [r].[status] AS [RequestStatus]
    , [r].[database_id]
FROM [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK)
LEFT JOIN [sys].[dm_exec_connections] AS [c] WITH (NOLOCK)
  ON [c].[session_id] = [s].[session_id]
LEFT JOIN [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
  ON [r].[session_id] = [s].[session_id]
WHERE [s].[session_id] <> @@SPID
  AND [s].[is_user_process] = 1;
```

**Wichtig für die Eigenlast:** User-/Session-/Statusfilter vor SQL-Textauflösung setzen. Eine Session kann inaktiv sein und deshalb keine Requestzeile besitzen; SQL-Text ist ein optionaler N+1-artiger Detailpfad.

### Zeit- und Scope-Modell

Sessionmomentaufnahme mit kumulativen Zählern seit Sessionbeginn. Session-IDs können nach Ende wiederverwendet werden; Uhrzeit und Login-/Connectionkontext gehören zur Identität.

### Bewertung und Gegenprobe

`sleeping` ohne offene Transaktion ist häufig normal. `sleeping` mit offener Transaktion, Locks oder wachsendem Logverbrauch ist wesentlich kritischer. Hohe kumulative CPU einer alten Poolsession beweist keine aktuelle Last.

### Typische Fehlinterpretation

`LastRequestEndTime` ist nicht automatisch Transaktionsende. Clientangaben wie Host/Program sind nicht manipulationssicher.

### Folgeanalyse

`USP_CurrentTransactions`; bei aktiver Arbeit `USP_CurrentRequests`; bei Auswirkungen `USP_CurrentBlocking`.

## Primärquellen

- [sys.dm_exec_sessions](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#1-monitorusp_currentsessions)
