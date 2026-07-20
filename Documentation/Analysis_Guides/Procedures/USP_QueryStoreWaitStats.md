# [monitor].[USP_QueryStoreWaitStats]

**Bereich:** Query Store<br>
**Zweck:** Aggregiert historische Query-Store-Waitkategorien je Query und Plan.<br>
**Beobachtungsart:** persistierte, retentionbegrenzte Historie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche groben Waitkategorien dominierten historisch je Query-Store-Plan?** Der dokumentierte Zweck ist: Aggregiert historische Query-Store-Waitkategorien je Query und Plan. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Ihr Zeitvertrag lautet ausdrücklich: Persistierte Waitkategorien innerhalb Retention und aktivem Wait Capture; datenbank-/planbezogen. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
DECLARE @ExampleBisUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -1, @ExampleBisUtc);

EXEC [monitor].[USP_QueryStoreWaitStats]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @VonUtc = @ExampleVonUtc,
      @BisUtc = @ExampleBisUtc,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `waitStats` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Query-/Plan-/Waitkategorie-Aggregation über gespeicherte Intervalle. `RecordedRows` ist nicht die Zahl einzelner Waits oder Ausführungen.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Waitkategorie, Totalzeit, Maxwert, Recorded Rows, Query-/Planidentität und Zeitintervalle gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Hohe Totalzeit zeigt kumulative Auswirkung; hoher Maxwert kann einzelne Ausreißer anzeigen. Kategorien sind gröber als Live-Waittypen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Viele Recorded Rows bedeuten viele gespeicherte Messpunkte, nicht automatisch viele Ausführungen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Lock-Wait dominiert nur ein Intervall: möglicher Burst. Täglich stundenlang dominant: systematisches Problem. Runtime, Planwechsel und bei Reproduktion Live-Blocking prüfen.

**Ähnlich aussehender Gegenfall:** Viele Recorded Rows bedeuten viele gespeicherte Messpunkte, nicht automatisch viele Ausführungen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Query Store kann nutzbar, aber im gewählten Fenster leer sein; Capturemodus, Read-only-Status, Retention und UTC-Fenster zuerst prüfen.

Für `USP_QueryStoreWaitStats` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, das standardmäßige einstündige UTC-Fenster und globales TOP 100 ohne Referenzdatenbankfilter. |
| Teuerster Pfad | Viele Datenbanken, `VOLL`/unbegrenztes Limit, mehr als 24 Stunden und Referenzdatenbankfilter; letzterer lädt und zerlegt gespeicherte Showplan-XML, obwohl kein Plan-XML ausgegeben wird. |
| Haupttreiber | Zahl gewählter Query Stores, überlappender Intervalle, Query-/Plan-Kombinationen und Wait-Stats-Zeilen im UTC-Fenster. Referenzdatenbankfilter lädt zusätzlich gespeicherte Showplan-XML; das abschließende TOP spart diese Vorarbeit nicht. |
| Skalierung | Aufwand wächst mit Wait-Stat-Zeilen in überlappenden Intervallen, Plänen, Waitkategorien und Datenbanken. Referenzfilter addieren Showplan-XML-Parsing; SQL-Textbreite erhöht Transfer. |
| Ressourcen | CPU und I/O auf Query-Store-Wait-/Intervalltabellen, Speicher/TempDB für Gruppierung und Sortierung; optional XML-CPU für Referenzobjekte. |
| Begrenzungswirkung | UTC-, Query- und Waitkategoriefilter wirken vor der Aggregation. Das lokale N+1 greift erst nach Gruppierung/Sortierung je Datenbank, das globale TOP anschließend; beide begrenzen nicht alle gelesenen Intervallzeilen. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, eine Stunde, TOP 100 und möglichst Query-/Waitfilter. Referenzdatenbankfilter, >24 Stunden, `VOLL` oder >1000 Zeilen nur bewusst mit `QUERY_STORE_DEEP`. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierte, retentionbegrenzte Historie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche groben Waitkategorien dominierten historisch je Query-Store-Plan?

### Technischer Hintergrund

Query Store ordnet konkrete Waittypen Kategorien zu und speichert Total/Avg/Min/Max je Plan, Intervall und Execution Type. Es erfasst Waits während Queryausführung, nicht Compile-Waits. Der Frameworkcode mittelt gespeicherte Intervallmittelwerte ungewichtet und summiert vollständig einbezogene Überlappungsintervalle.

### Datenkette

`sys.database_query_store_options`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.query_store_runtime_stats_interval`, `sys.query_store_wait_stats`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Persistierte Waitkategorien innerhalb Retention und aktivem Wait Capture; datenbank-/planbezogen.

### Bewertung und Gegenprobe

Total, Max, Recorded Rows, Execution Type und Runtime-Ausführungen korrelieren. Kategorien priorisieren den Troubleshootingpfad, liefern aber keinen konkreten Blocker oder Wait Resource.

### Typische Fehlinterpretation

`RecordedRows` sind Messzeilen, keine Waitanzahl. Die Average-Spalte ist kein execution-weighted Gesamtdurchschnitt.

### Folgeanalyse

Die kanonischen [Query-Store-Wait-Details](../05_Query_Store.md#3-monitorusp_querystorewaitstats) und das [Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) verwenden; historische Kategorien bei Bedarf mit Current Waits und Requests validieren.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#3-monitorusp_querystorewaitstats)
