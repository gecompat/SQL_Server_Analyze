# [monitor].[USP_CurrentSessions]

**Bereich:** Current State<br>
**Zweck:** Inventarisiert aktuelle Sessions, Verbindungskontext, kumulative Aktivität und offene Transaktionen.<br>
**Beobachtungsart:** Snapshot + kumulative Sessionzähler<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Sessions sind verbunden, welchen Kontext besitzen sie und gibt es inaktive Sessions mit fortwirkendem Zustand?** Sie unterstützt die Entscheidung, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentSessions]
      @MitSqlText = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Der Einstieg erhebt Session- und Requestmetadaten ohne SQL-Text. Grenzen Sie eine
auffällige Session anschließend über `@SessionIds` ein und ergänzen Sie Text nur für
diesen Kandidaten.

Erkannte Tool-Hintergrundsessions sind im Default ausgeblendet. Mit
`@ToolHintergrundabfragenEinbeziehen = 1` werden sie samt Regelcode, Kategorie,
Erkennungsart und Konfidenz sichtbar. Die Erkennung ist eine
[konfigurierbare Diagnoseheuristik](../../Architecture/Tool_Background_Query_Filtering.md),
kein Sicherheitsmerkmal.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `sessions` mit 51 Feldern, 22 expliziten Framework-Textcollations und fünf nicht-nullbaren Feldern. Aktive CONSOLE-Ausgaben ergänzen das Feld `Ergebnis`; eine leere Ausgabe besitzt `Ergebnis`, `Status` und `Hinweis`. RAW ergänzt zehn Wait-Felder und stellt ein Statusresultset voran. JSON ergänzt die drei Felder `waitGroup`, `waitSeverity` und `waitMeaning` und enthält `meta`, `sessions` und `warnings`. Status und Scope sind vor den Fachwerten zu lesen. Ein Warning kann auch den Detailtext eines erfolgreichen Aufrufs enthalten.

Alle vier Ausgaben verwenden dieselbe bereits begrenzte Sessionmenge. `@MaxZeilen = NULL` oder `0` liefert sie ohne Zeilenlimit; ein positives Limit setzt bei weiteren Kandidaten `hasMoreRows`. Die Auswahl richtet sich nach `@Sortierung` und `SessionId`. RAW sortiert seine Ausgabe nach diesen Schlüsseln, JSON nach `SessionId`; TABLE und der aktive CONSOLE-Helper garantieren keine Zeilenreihenfolge.


## Snapshot-Verhalten

Ein direkter Aufruf liest die Systemquellen immer frisch.
`@ParentCurrentStateSnapshotId` ist ein interner Consumerparameter für
`USP_CurrentOverview`; Anwender sollen ihn nicht setzen. Innerhalb des
Overview-Aufrufs werden Sessions, Requests, Connections und bei Bedarf
deduplizierter SQL-Text aus demselben laufinternen Primär-Snapshot verwendet.
RAW und JSON weisen den Startzeitpunkt sowie die Snapshot-ID aus. Der Overview-Consumer reicht `@AktuelleSessionEinbeziehen` nicht weiter; die aufrufende Session bleibt dort nach dem Childdefault ausgeschlossen.

## Eine Zeile bedeutet

Eine Zeile beschreibt eine aktuell sichtbare Session mit ihrem korrelierten Verbindungskontext. Der aktuelle Request wird über die kleinste sichtbare `request_id` ausgewählt; bei einer inaktiven Session kann er fehlen. Mehrere sichtbare Connections können die Zeilengranularität beeinflussen.

## So lesen

Prüfen Sie zuerst `SessionStatus`, `RequestStatus` und `OpenTransactionCount`. Berücksichtigen Sie danach die letzte Aktivität, kumulative CPU- und I/O-Werte sowie Verbindungsinformationen. Berücksichtigen Sie bei eingeblendeten Tool-Sessions außerdem `ToolBackgroundRuleCode` und `ToolBackgroundConfidence`.

## Warum kann das problematisch sein?

`sleeping` plus offene Transaktion bedeutet: Der Client führt nichts aus, hält aber möglicherweise Locks und verhindert Log-Wiederverwendung.

## Wann ist es kein Problem?

Eine lange angemeldete sleeping Session ohne offene Transaktion ist bei Connection Pools normal. Das Login-Alter allein ist kein Befund.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine seit acht Stunden verbundene Session mit letzter Aktivität vor zehn Sekunden und ohne offene Transaktion ist unauffällig. Prüfen Sie dieselbe Session bei einer zwei Stunden alten Transaktion mit `USP_CurrentTransactions` und der Blockinganalyse.

**Ähnlich aussehender Gegenfall:** Eine lange angemeldete sleeping Session ohne offene Transaktion ist bei Connection Pools normal. Das Login-Alter allein ist kein Befund. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentSessions` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Ein eingeschränkter Berechtigungsscope kann fremde Sessions ausblenden. Prüfen Sie vor einer Entwarnung Status, eigene Sessionfilter und Systemsessionfilter.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Maximal 500 Ergebniszeilen aus sichtbaren User-Sessions einschließlich inaktiver Sessions, ohne SQL-Text. Die aufrufende Session und erkannte Tool-Hintergrundsessions sind standardmäßig ausgeschlossen. Pro Session wird höchstens ein aktueller Request korreliert. |
| Teuerster Pfad | `@MaxZeilen = 0`, System- und inaktive Sessions, `@MitSqlText = 1` ohne Zeichenlimit sowie mehrere Regexfilter. Regex wird nach der unbeschränkten Kandidatenmaterialisierung angewandt. |
| Haupttreiber | Zahl sichtbarer Sessions und korrelierter Connections/Requests. System-/Inaktivscope, SQL-Textbreite und späte Regexfilter bestimmen, ob nur eine frühe N+1-Kandidatenmenge oder alle vorgefilterten Sessions materialisiert werden. |
| Skalierung | Ohne Regex und bei positivem Limit werden höchstens `@MaxZeilen + 1` Kandidaten materialisiert. Mit Regex entfällt dieses frühe TOP. Die Quellenreads, Joins, Filter, Sortierung und optionale SQL-Textauflösung sind damit nicht auf N+1 beschränkt. |
| Ressourcen | CPU und Arbeitsspeicher für Session-/Connection-/Request-Joins, Sortierung und optional Regex; bei SQL-Text zusätzlicher Cachezugriff und Ergebnistransfer. |
| Begrenzungswirkung | Die DMV-Quellen werden zunächst in lokale Arbeitstabellen gelesen. Exakte Listen und LIKE-Prädikate filtern den anschließenden Join vor der Kandidatenmaterialisierung. Regex filtert erst danach per `DELETE`. Das gemeinsame Zeilenlimit wirkt vor der anschließenden Unicodeprojektion der behaltenen Texte. |
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
OUTER APPLY
(
    SELECT TOP (1) [rr].*
    FROM [sys].[dm_exec_requests] AS [rr] WITH (NOLOCK)
    WHERE [rr].[session_id] = [s].[session_id]
    ORDER BY [rr].[request_id]
) AS [r]
WHERE [s].[session_id] <> @@SPID
  AND [s].[is_user_process] = 1;
```

**Wichtig für die Eigenlast:** Bei `@MitSqlText = 1` werden zunächst die eindeutigen Handles der sichtbaren Request- und Connectionquellen aufgelöst. Die Sessionfilter und das Kandidaten-TOP folgen danach. Ein kleines Ergebnislimit begrenzt deshalb weder diesen Cachezugriff noch die physische Statementextraktion. Die anschließende Unicodeprojektion bearbeitet nur die behaltenen Ergebniszeilen. Eine inaktive Session kann Text über den letzten Connectionhandle besitzen, obwohl ihre Requestfelder einschließlich `DatabaseName` NULL bleiben.

### Zeit- und Scope-Modell

Die Auswertung liefert eine Sessionmomentaufnahme mit kumulativen Zählern seit dem Sessionbeginn. Session-IDs können nach dem Ende wiederverwendet werden; Uhrzeit sowie Login- und Verbindungskontext gehören zur Identität.

### Bewertung und Gegenprobe

`sleeping` ohne offene Transaktion ist häufig normal. `sleeping` mit offener Transaktion, Locks oder wachsendem Logverbrauch ist wesentlich kritischer. Hohe kumulative CPU einer alten Poolsession beweist keine aktuelle Last.

### Typische Fehlinterpretation

`LastRequestEndTime` ist nicht automatisch Transaktionsende. Clientangaben wie Host/Program sind nicht manipulationssicher.

### Folgeanalyse

Verwenden Sie für die weitere Analyse `USP_CurrentTransactions`, bei aktiver Arbeit `USP_CurrentRequests` und bei sichtbaren Auswirkungen `USP_CurrentBlocking`.

## Primärquellen

- [sys.dm_exec_sessions](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-sessions-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#1-monitorusp_currentsessions)
