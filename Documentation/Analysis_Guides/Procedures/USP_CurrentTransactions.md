# [monitor].[USP_CurrentTransactions]

**Bereich:** Current State<br>
**Zweck:** Zeigt offene Transaktionen, Alter, Sessionzustand, Logverbrauch und SQL-Kontext.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche offenen Transaktionen halten Zustand, Locks oder Lograum länger als erwartet?** Der dokumentierte Zweck ist: Zeigt offene Transaktionen, Alter, Sessionzustand, Logverbrauch und SQL-Kontext. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Ihr Zeitvertrag lautet ausdrücklich: Aktueller offener Zustand; Alter seit Transaktionsbeginn. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

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

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `transactions` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile beschreibt die Zuordnung einer sichtbaren Transaktion zu Session- und Datenbankkontext. Mehrere technische Transaktionszeilen können zu einer Session gehören.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Transaktionsalter, Sessionstatus, `OpenTransactionCount`, Logbytes, Blocking und SQL-Kontext gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Eine alte Transaktion kann Locks halten, Log-Wiederverwendung verhindern und bei Rollback lange benötigen. `sleeping` erhöht den Verdacht auf fehlendes Commit/Rollback.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Geplante Batchloads oder Wartung dürfen lange Transaktionen besitzen, sofern Fortschritt, Logkapazität und Blocking kontrolliert sind.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Sleeping seit 30 Minuten, offene Transaktion, wachsender Logverbrauch und mehrere Blockierte: starke Evidenz für einen nicht abgeschlossenen Anwendungspfad. Blocking, Log und Anwendungstransaktion prüfen.

**Ähnlich aussehender Gegenfall:** Geplante Batchloads oder Wartung dürfen lange Transaktionen besitzen, sofern Fortschritt, Logkapazität und Blocking kontrolliert sind. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentTransactions` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Aktive User-Transaktionen ab 60 Sekunden, höchstens 1000 Kandidaten plus eine Überlaufzeile; SQL-Text ist auf 3000 Zeichen gekürzt. |
| Teuerster Pfad | `@MaxZeilen = 0`, kein Alters-/Sessionfilter, System-Sessions einbezogen und vollständiger SQL-Text bei sehr vielen aktiven Transaktionsbindungen. |
| Haupttreiber | Zahl aktiver Transaktionen und Session-/Datenbankbindungen, die für Alter und Logverbrauch korreliert werden. Ein breiter Sessionscope sowie vollständiger SQL-Text erhöhen Sortier-, Speicher- und Transferbedarf je Kandidat. |
| Skalierung | Join- und Sortierarbeit wächst mit aktiven Transaktionen und ihren Session-/Datenbankbindungen. SQL-Textbreite erhöht Cachezugriff, Speicher und Transfer; Locks werden nicht materialisiert. |
| Ressourcen | CPU und Arbeitsspeicher für Transaktions-/Session-/Request-DMV-Joins und Sortierung; optional Plan-Cache-/Textzugriff. Keine Benutzerobjektscans. |
| Begrenzungswirkung | Session-, Mindestalter-, Sleeping- und Systemfilter wirken in der Quellabfrage. `TOP (@MaxZeilen + 1)` begrenzt die materialisierten Kandidaten; die DMVs und Joins können zur Filterung/Sortierung dennoch breiter gelesen werden. Das Zeichenlimit reduziert nur Textbreite. |
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

### Zeit- und Scope-Modell

Aktueller offener Zustand; Alter seit Transaktionsbeginn. Logbytes und Locks können während der Abfrage weiter wachsen.

### Bewertung und Gegenprobe

Alter, Sessionstatus, Requestfortschritt, Logverbrauch, Blockingopfer und `log_reuse_wait_desc` korrelieren. Lange Batchloads können legitim sein, benötigen aber Kapazitäts- und Fortschrittskontrolle.

### Typische Fehlinterpretation

`OpenTransactionCount>0` nennt nicht automatisch die äußerste fachliche Transaktion; implizite, verschachtelte oder verteilte Kontexte beachten. Ein Rollback kann ungefähr so teuer wie die bisherige Änderung sein.

### Folgeanalyse

`USP_CurrentBlocking`, `USP_CurrentLog`, Request/Anwendungs-Transaktionslogik.

## Primärquellen

- [Transaktions-DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/transaction-related-dynamic-management-views-and-functions-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#5-monitorusp_currenttransactions)
