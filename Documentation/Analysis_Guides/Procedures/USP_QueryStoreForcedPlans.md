# [monitor].[USP_QueryStoreForcedPlans]

**Bereich:** Query Store<br>
**Zweck:** Inventarisiert erzwungene Pläne und Plan-Forcing-Fehler.<br>
**Beobachtungsart:** persistierter Konfigurationsstand + Planhistorie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Pläne werden erzwungen, funktionieren sie technisch und sind sie noch betrieblich begründet?** Der dokumentierte Zweck ist: Inventarisiert erzwungene Pläne und Plan-Forcing-Fehler. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Forcingstatus plus persistierter Planlebenszyklus. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_QueryStoreForcedPlans]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @NurMitFehler = 0,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `forcedPlans` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Query-Store-Plan mit Forcingmetadaten.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

`IsForcedPlan`, Forcing Type, Failure Count/Reason, letzte Ausführung, Engineversion und Compatibility gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Force-Fehler bedeuten, dass die gewünschte Bindung nicht zuverlässig angewendet wird. Ein alter Forced Plan kann neue Optimizerverbesserungen verhindern.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein fehlerfrei erzwungener Plan mit stabiler Performance kann bewusste Risikokontrolle sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 50 Force-Fehler plus aktuelle Regression ist dringender als ein stabiler alter Forced Plan ohne Fehler. Runtimevergleich, Plan Changes und Rücknahmepfad prüfen.

**Ähnlich aussehender Gegenfall:** Ein fehlerfrei erzwungener Plan mit stabiler Performance kann bewusste Risikokontrolle sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Query Store kann nutzbar, aber im gewählten Fenster leer sein; Capturemodus, Read-only-Status, Retention und UTC-Fenster zuerst prüfen.

Für `USP_QueryStoreForcedPlans` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, TOP 100, gekürzter SQL-Text und kein Plan XML; es werden ausschließlich aktuell als forced markierte Query-Store-Pläne inventarisiert. |
| Teuerster Pfad | Viele Datenbanken, unbegrenztes/hohes Limit, vollständiger SQL-Text, Plan XML und Referenzdatenbank-/Regexfilter. Einen Zeitfensterparameter besitzt die Procedure nicht. |
| Haupttreiber | Zahl gewählter Query Stores und aktuell forced markierter Pläne samt Querytext. Volltext, Plan-XML, Regex und Referenzdatenbankfilter verbreitern beziehungsweise verteuern jeden Kandidaten; ein Zeitfenster existiert nicht. |
| Skalierung | Aufwand wächst mit Query-Store-Plan-/Queryzeilen und ausgewählten Datenbanken; Plan-/Textbreite sowie Referenz-XML-Parsing können CPU, Speicher und Transfer dominieren. |
| Ressourcen | Query-Store-I/O und CPU für Plan-/Query-/Textjoin und Ranking; optional Plan-XML-Materialisierung beziehungsweise XML-Shredding. Keine Fensteraggregation. |
| Begrenzungswirkung | QueryId und `@NurMitFehler` wirken vor dem lokalen TOP N+1. Das Limit ist lokal und anschließend global, verhindert aber Referenz-XML-Prüfung der zu betrachtenden Forced-Plan-Zeilen nicht zuverlässig. Textzeichen begrenzen nur Ausgabegröße. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, `@NurMitFehler = 1`, TOP 100 und kein Plan XML. Plan XML, Referenzfilter oder >1000/unbegrenzt nur nach `QUERY_STORE_DEEP`. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierter Konfigurationsstand + Planhistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Pläne werden erzwungen, funktionieren sie technisch und sind sie noch betrieblich begründet?

### Technischer Hintergrund

Query Store Plan Forcing beeinflusst die Planwahl über gespeicherte Planrepräsentation. Metadaten enthalten Forcing Type, Failure Count/Reason, Compile-/Executionzeit und Version. Schema-/Index-/Engineänderungen können Forcing verhindern oder seine Qualität verändern.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.schemas`, `sys.sp_executesql`.

### Source Select

Forced Plans werden über Plan, Query und Query Text verbunden; der Force-Status ist das frühe Fachprädikat:

```sql
SELECT
      [p].[plan_id]
    , [p].[query_id]
    , [p].[is_forced_plan]
    , [p].[force_failure_count]
    , [p].[last_force_failure_reason_desc]
    , [q].[object_id]
    , [qt].[query_sql_text]
FROM [sys].[query_store_plan] AS [p] WITH (NOLOCK)
JOIN [sys].[query_store_query] AS [q] WITH (NOLOCK)
  ON [q].[query_id] = [p].[query_id]
JOIN [sys].[query_store_query_text] AS [qt] WITH (NOLOCK)
  ON [qt].[query_text_id] = [q].[query_text_id]
WHERE [p].[is_forced_plan] = 1;
```

**Wichtig für die Eigenlast:** Datenbank und Forced-Status vor SQL-Text und Plan-XML anwenden. Vollständiges XML nur für einzelne `plan_id`-Kandidaten lesen; die Inventarisierung benötigt es nicht.

### Zeit- und Scope-Modell

Aktueller Forcingstatus plus persistierter Planlebenszyklus.

### Bewertung und Gegenprobe

Fehler, letzte Nutzung, Runtime im Vergleich zu Alternativen, Engine-/Compatibilitywechsel und Owner/Reviewdatum prüfen. Stabilität kann wichtiger als minimaler Durchschnitt sein.

### Typische Fehlinterpretation

`IsForcedPlan=1` beweist nicht, dass der Plan aktuell benutzt oder optimal ist. `0` Fehler beweist nur technischen Erfolg, nicht fachlichen Nutzen.

### Folgeanalyse

Runtime/Regressions/PlanChanges; Änderung nur mit Rollback- und Monitoringplan.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#6-monitorusp_querystoreforcedplans)
