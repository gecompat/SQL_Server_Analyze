# [monitor].[USP_CurrentTransactions]

**Bereich:** Current State<br>
**Zweck:** Zeigt offene Transaktionen, Alter, Sessionzustand, Logverbrauch und SQL-Kontext.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche offenen Transaktionen halten Zustand, Locks oder Lograum länger als erwartet?** Sie unterstützt die Entscheidung, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentTransactions]
      @MinAlterSekunden = 60,
      @MitSqlText = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Damit werden zunächst ältere Transaktionen ohne SQL-Text priorisiert. SQL-Text
ist nur eine momentane Zuordnung zur Session und sollte erst für konkrete
`@SessionIds` ergänzt werden.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Resultsets und Leserichtung

Der TABLE-Vertrag `transactions` enthält 20 Felder, sieben explizite Frameworktextcollations und drei NOT-NULL-Felder ohne Identity. RAW liefert zuerst zehn Statusfelder, danach dieselben 20 Transaktionsfelder und drei Warningfelder. JSON enthält `meta`, `transactions` und `warnings` einschließlich NULL-Werten. Die aktive CONSOLE liefert die 20 Fachfelder mit der zusätzlichen Beschriftung `Ergebnis`; bei leerer Menge liefert sie `Ergebnis`, `Status` und `Hinweis`. Status und Warnings stehen für CONSOLE im optionalen JSON zur Verfügung; ein RAW-Metaresultset wird dort nicht ausgegeben.

Alle vier Ausgabeformen verwenden dieselbe spät begrenzte Fachmenge. Ein positives `@MaxZeilen` begrenzt sie nach der bestehenden Ordnung aus Alter absteigend, SessionId und TransactionId; NULL oder 0 bleibt unbegrenzt. N+1-Kandidaten, `HasMoreRows` und Textwarnungen werden davor bewertet. TABLE- und CONSOLE-Helper garantieren keine zusätzliche Zeilenordnung. Gültige TABLE-Zuordnungen werden vor der semantischen Parameterprüfung validiert; bei ungültigen Parametern wird das vollständige leere Fachschema exportiert.

Im Overview werden Session-, Request-, Transaktions- und SQL-Textquellen aus
dem gemeinsamen Snapshot übernommen. Ein direkter Aufruf materialisiert diese
Quellen neu; eine Parent-ID aus einem anderen Aufruf wird abgelehnt.

## Eine Zeile bedeutet

Eine Zeile beschreibt die Zuordnung einer sichtbaren Transaktion zu Session- und Datenbankkontext. Mehrere technische Transaktionszeilen können zu einer Session gehören.

## So lesen

Berücksichtigen Sie Transaktionsalter, Sessionstatus, `OpenTransactionCount`, Logbytes, Blocking und SQL-Kontext gemeinsam.

## Warum kann das problematisch sein?

Eine alte Transaktion kann Locks halten, Log-Wiederverwendung verhindern und bei Rollback lange benötigen. `sleeping` erhöht den Verdacht auf fehlendes Commit/Rollback.

## Wann ist es kein Problem?

Geplante Batchloads oder Wartung dürfen lange Transaktionen besitzen, sofern Fortschritt, Logkapazität und Blocking kontrolliert sind.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Sleeping seit 30 Minuten, offene Transaktion, wachsender Logverbrauch und mehrere Blockierte: starke Evidenz für einen nicht abgeschlossenen Anwendungspfad. Prüfen Sie Blocking, Log und Anwendungstransaktion.

**Ähnlich aussehender Gegenfall:** Geplante Batchloads oder Wartung dürfen lange Transaktionen besitzen, sofern Fortschritt, Logkapazität und Blocking kontrolliert sind. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentTransactions` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Aktive User-Transaktionsbindungen ab 0 Sekunden; höchstens 1000 ausgegebene Zeilen und eine zusätzliche materialisierte Kandidatenzeile. SQL-Text ist eingeschaltet und auf 3000 SC-Zeichen begrenzt. |
| Teuerster Pfad | `@MaxZeilen = 0`, kein Alters-/Sessionfilter, System-Sessions einbezogen und vollständiger SQL-Text bei sehr vielen aktiven Transaktionsbindungen. |
| Haupttreiber | Zahl aktiver Transaktionen und Session-/Datenbankbindungen, die für Alter und Logverbrauch korreliert werden. Ein breiter Sessionscope sowie vollständiger SQL-Text erhöhen Sortier-, Speicher- und Transferbedarf je Kandidat. |
| Skalierung | Join- und Sortierarbeit wächst mit aktiven Transaktionen und ihren Session-/Datenbankbindungen. SQL-Textbreite erhöht Cachezugriff, Speicher und Transfer; Locks werden nicht materialisiert. |
| Ressourcen | CPU und Arbeitsspeicher für Transaktions-/Session-/Request-DMV-Joins und Sortierung; optional Plan-Cache-/Textzugriff. Keine Benutzerobjektscans. |
| Begrenzungswirkung | Session-, Mindestalter-, Sleeping- und Systemfilter wirken in der Quellabfrage. Die sichere N+1-Grenze begrenzt die materialisierten Kandidaten. Nach Unicodeprojektion, Textwarnung und Zählerbewertung wird die gemeinsame Ausgabemenge zugeschnitten; weitere DMV-, Join-, Filter-, Sortier- und Extraktionsarbeit bleibt möglich. Das Zeichenlimit begrenzt den bereits materialisierten Text, nicht dessen ursprüngliche Ermittlung. |
| Locking und Nebenwirkungen | Read-only gegenüber Nutzdaten. Flüchtige DMVs werden nacheinander gelesen; Katalog-/SQL-Textauflösung kann kurze interne Synchronisation verursachen, erzeugt aber keinen atomaren Snapshot. |
| Schutzmechanismus | Kein High-Impact-Gate. Früh wirkende Session-/Altersfilter, der standardmäßige Systemscope, `@MaxZeilen` und das SQL-Text-Zeichenbudget schützen den Kandidatenpfad; `@MitSqlText = 0` spart die Textauflösung vollständig. |
| Sicherer Einsatz | Ein sinnvolles Mindestalter, User-Scope und endliches Limit; SQL-Text bei erster Triage ausschalten oder gekürzt lassen und nur für auffällige Sessions vertiefen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche offenen Transaktionen halten Zustand, Locks oder Lograum länger als erwartet?

### Technischer Hintergrund

Transaktions-DMVs verbinden Datenbank-/Sessiontransaktionen mit Beginn, Zustand, Logbytes und Session/Request. Commit oder Rollback beendet die logische Transaktion; bis dahin können Locks und die für Recovery benötigte Logkette erhalten bleiben. Eine alte aktive Transaktion kann Logtruncation verhindern.

### Datenkette

`master.sys.databases`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_tran_active_transactions`, `sys.dm_tran_database_transactions`, `sys.dm_tran_session_transactions`.

### Source Select

Die tragende Beziehung läuft von Session-Transaktionen zu aktiver Transaktion, Session, Request und datenbankbezogenem Logverbrauch:

```sql
SELECT
      [st].[session_id]
    , [at].[transaction_id]
    , [at].[transaction_begin_time]
    , [at].[transaction_type]
    , [s].[status] AS [SessionStatus]
    , [r].[request_id]
    , [dt].[database_id]
    , [dt].[database_transaction_log_bytes_used]
FROM [sys].[dm_tran_session_transactions] AS [st] WITH (NOLOCK)
JOIN [sys].[dm_tran_active_transactions] AS [at] WITH (NOLOCK)
  ON [at].[transaction_id] = [st].[transaction_id]
INNER JOIN [sys].[dm_exec_sessions] AS [s] WITH (NOLOCK)
  ON [s].[session_id] = [st].[session_id]
LEFT JOIN [sys].[dm_exec_requests] AS [r] WITH (NOLOCK)
  ON [r].[session_id] = [st].[session_id]
LEFT JOIN [sys].[dm_tran_database_transactions] AS [dt] WITH (NOLOCK)
  ON [dt].[transaction_id] = [at].[transaction_id]
WHERE DATEDIFF_BIG(SECOND, [at].[transaction_begin_time], GETDATE()) >= @MinAlterSekunden;
```

**Wichtig für die Eigenlast:** Die Systemquellen werden vor der gefilterten Kandidatenabfrage materialisiert; bei eingeschaltetem SQL-Text werden unterschiedliche Requesthandles bereits dort aufgelöst. Session- und Altersfilter begrenzen anschließend die Fachkandidaten. Die Procedure aggregiert Logbytes nicht. Mehrere Datenbankbindungen und Requests können mehrere Zeilen derselben Session-/Transaktionszuordnung erzeugen; ein Requestdatenbankkontext hat bei der ausgegebenen Datenbankidentität Vorrang vor der jeweiligen Datenbanktransaktionszeile. Eine Summierung erfordert deshalb eine eigene Prüfung der Granularität.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen offenen Zustand. `TransactionBeginTimeUtc` übernimmt den DMV-Datetimewert ohne UTC-Konvertierung; `TransactionAgeSeconds` wird mit `DATEDIFF_BIG` und `GETDATE()` ermittelt. Erfassungsmetadaten verwenden dagegen `SYSUTCDATETIME()`. Die nacheinander materialisierten Quellen bilden keinen atomaren Snapshot; Logbytes und andere Zustandswerte können sich zwischen Aufrufen ändern.

### Bewertung und Gegenprobe

Korrelieren Sie Alter, Sessionstatus, Requestfortschritt, Logverbrauch, Blockingopfer und `log_reuse_wait_desc`. Lange Batchloads können legitim sein, benötigen aber Kapazitäts- und Fortschrittskontrolle.

### Typische Fehlinterpretation

`OpenTransactionCount>0` nennt nicht automatisch die äußerste fachliche Transaktion; berücksichtigen Sie implizite, verschachtelte oder verteilte Kontexte. Ein Rollback kann ungefähr so teuer wie die bisherige Änderung sein.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_CurrentBlocking`, `USP_CurrentLog`, Request/Anwendungs-Transaktionslogik.

## Primärquellen

- [Transaktions-DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/transaction-related-dynamic-management-views-and-functions-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#5-monitorusp_currenttransactions)
