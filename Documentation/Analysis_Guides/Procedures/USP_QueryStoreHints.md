# [monitor].[USP_QueryStoreHints]

**Bereich:** Query Store<br>
**Zweck:** Inventarisiert Query Store Hints, Herkunft und Anwendungsfehler.<br>
**Beobachtungsart:** persistierter Konfigurationsstand<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Query Store Hints greifen auf Queries ein, und schlagen sie fehl oder überdecken sie inzwischen bessere Optimizerentscheidungen?** Der dokumentierte Zweck ist: Inventarisiert Query Store Hints, Herkunft und Anwendungsfehler. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Ihr Zeitvertrag lautet ausdrücklich: Aktueller persistierter Hintbestand; QueryId ist datenbanklokal. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreHints]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `queryHints` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Query Store Hint für eine Query und gegebenenfalls Replica-Gruppe.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Hinttext, Quelle, Failure Count/Reason, Queryidentität und letzte Relevanz gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein Hint begrenzt Optimizerfreiheit und kann nach Daten-, Schema- oder Versionsänderungen schädlich werden.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein dokumentierter, getesteter Hint kann eine bewusste Maßnahme sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Fehlerfrei angewendet bedeutet nur „wirksam“, nicht „weiterhin nützlich“. Runtime, Regression, Plan Changes, Owner und Reviewdatum prüfen.

**Ähnlich aussehender Gegenfall:** Ein dokumentierter, getesteter Hint kann eine bewusste Maßnahme sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Query Store kann nutzbar, aber im gewählten Fenster leer sein; Capturemodus, Read-only-Status, Retention und UTC-Fenster zuerst prüfen.

Für `USP_QueryStoreHints` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, TOP 100 und auf 4000 Zeichen gekürzter Querytext. Die Procedure liest Hinttext und Anwendungsfehler, aber weder Zeitfenster noch Plan XML. |
| Teuerster Pfad | Viele Datenbanken, unbegrenztes/hohes Limit und ungekürzte Hint-/Querytexte bei sehr vielen gespeicherten Query Store Hints. |
| Haupttreiber | Zahl gewählter Query Stores und vorhandener Hintzeilen samt zugehörigem Querytext. Volltext und Regex erhöhen Breite beziehungsweise späte Filterarbeit; Runtimeintervalle und Plan-XML werden in diesem Inventarpfad nicht gelesen. |
| Skalierung | Aufwand wächst mit Hintzeilen, Query-/Textjoins und Datenbanken; ungekürzte Hint- und Querytexte erhöhen Arbeitsspeicher und Ergebnistransfer. |
| Ressourcen | Geringe bis mittlere Query-Store-I/O-/CPU-Last für Hint-/Query-/Textjoin und Ranking; keine Intervallaggregation oder XML-Verarbeitung. |
| Begrenzungswirkung | QueryId und Fehlerfilter wirken vor dem lokalen TOP N+1; danach wird global begrenzt. Das Zeichenlimit reduziert nur Querytextbreite, nicht Hinttext oder Quelllesung. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, `@NurMitFehler = 1`, TOP 100 und gekürzter Text. Erst bei Bedarf alle Hints zeigen; >1000/unbegrenzt erfordert `QUERY_STORE_DEEP`. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierter Konfigurationsstand“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Query Store Hints greifen auf Queries ein, und schlagen sie fehl oder überdecken sie inzwischen bessere Optimizerentscheidungen?

### Technischer Hintergrund

Query Store Hints hängen an QueryId und injizieren unterstützte Queryoptionen ohne Textänderung. Source, Hinttext, Failure Reason/Count und Replica Group liefern Governance-/Fehlerkontext. Verfügbarkeit ist versionsabhängig.

### Datenkette

`sys.query_store_query`, `sys.query_store_query_hints`, `sys.query_store_query_text`, `sys.sp_executesql`.

### Source Select

Query Store Hints werden über `query_id` mit Query- und Textkatalog verbunden:

```sql
SELECT
      [h].[query_id]
    , [h].[query_hint_text]
    , [h].[last_query_hint_failure_reason_desc]
    , [q].[object_id]
    , [qt].[query_sql_text]
FROM [sys].[query_store_query_hints] AS [h] WITH (NOLOCK)
JOIN [sys].[query_store_query] AS [q] WITH (NOLOCK)
  ON [q].[query_id] = [h].[query_id]
JOIN [sys].[query_store_query_text] AS [qt] WITH (NOLOCK)
  ON [qt].[query_text_id] = [q].[query_text_id]
WHERE @QueryId IS NULL OR [h].[query_id] = @QueryId;
```

**Wichtig für die Eigenlast:** Wenn bekannt, `query_id` vor Textprojektion setzen. Query Store Hints sind ab SQL Server 2022 verfügbar; fehlende Sicht oder Version wird als Status behandelt, nicht durch einen Ersatzscan kompensiert.

### Zeit- und Scope-Modell

Aktueller persistierter Hintbestand; QueryId ist datenbanklokal.

### Bewertung und Gegenprobe

Hint, Zielquery, Failure Count, letzte Runtime, Planveränderung, Version/Compatibility und Begründung korrelieren. Jede Intervention benötigt Owner, Reviewdatum und Rücknahmepfad.

### Typische Fehlinterpretation

Fehlerfrei bedeutet nicht sinnvoll. Nach Upgrade kann ein alter Hint Adaptive/IQP-Verbesserungen verhindern.

### Folgeanalyse

RuntimeStats, Regressions, PlanChanges und Change-Dokumentation.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#7-monitorusp_querystorehints)
