# [monitor].[USP_IntelligentQueryProcessingAnalysis]

**Bereich:** Query Store und IQP<br>
**Zweck:** Zeigt Featureeignung, datenbankbezogene Konfiguration und aggregierte Feedbacksignale.<br>
**Beobachtungsart:** Konfigurationssnapshot + persistierte Feedbackhistorie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche IQP-Funktionen sind technisch möglich, konfiguriert und durch sichtbare Query-/Planfeedbacksignale belegt?** Der dokumentierte Zweck ist: Zeigt Featureeignung, datenbankbezogene Konfiguration und aggregierte Feedbacksignale. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Version-/Compatibility-/Configurationzustand plus persistierte, sichtbare Feedback-/Variantenevidenz. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Der datenbankweise IQP-Katalogpfad ist als `CATALOG_DEEP` geschützt. `@HighImpactConfirmed = 1` bestätigt die Policyfreigabe, begrenzt aber weder die Zahl der Datenbanken noch die dort vorhandenen Feedbackzeilen.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `signals` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Datenbank, einer Configuration, Automatic-Tuning-Option oder einem aggregierten Signal.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Eligibility, Compatibility, Database-scoped Configurations, Query-Store-Zustand und Evidence Counts getrennt betrachten.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein Feature kann versionsseitig geeignet, aber deaktiviert sein. Query Store OFF oder READ_ONLY kann persistentes Feedback begrenzen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

`EvidenceCount=0` beweist weder Erfolg noch Misserfolg; eventuell existierte keine geeignete Query oder keine persistierte Evidenz.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** PSP eligible, aber keine Query Variants: kein Fehler. Erst eine bekannte parameter-sensitive Query liefert eine sinnvolle Gegenprobe. Query Store und Showplan prüfen.

**Ähnlich aussehender Gegenfall:** `EvidenceCount=0` beweist weder Erfolg noch Misserfolg; eventuell existierte keine geeignete Query oder keine persistierte Evidenz. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Query Store kann nutzbar, aber im gewählten Fenster leer sein; Capturemodus, Read-only-Status, Retention und UTC-Fenster zuerst prüfen.

Für `USP_IntelligentQueryProcessingAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase` mit endlichem Limit; gelesen werden IQP-/Query-Store-/Automatic-Tuning-Konfiguration und aggregierte Varianten-/Feedbacksignale, ohne Query-Text oder Showplan. |
| Teuerster Pfad | Alle sichtbaren Datenbanken und `@MaxZeilen = 0` bei sehr vielen Query-Store-Varianten, Plan-Feedbackzeilen und Tuningempfehlungen. Ein Zeitfenster- oder XML-Pfad existiert nicht. |
| Haupttreiber | Zahl gewählter Datenbanken sowie Query-Store-Varianten, Plan-Feedback- und Automatic-Tuning-Empfehlungszeilen. Konfigurationsquellen sind klein; unbegrenzte Feedback-/Variantenbestände dominieren, obwohl weder Querytext noch Showplan gelesen wird. |
| Skalierung | Feste Konfigurationszeilen bleiben klein; Aufwand wächst mit ausgewählten Datenbanken und sichtbaren Query-Variant-/Plan-Feedback-/Tuningzeilen. Keine Text-, Plan-XML- oder Intervallaggregation. |
| Ressourcen | CPU und Katalog-/Query-Store-Metadaten-I/O sowie dynamisches SQL/temporäre Signalresultate; Ergebnistransfer wächst mit der Signalmenge. |
| Begrenzungswirkung | Der Datenbankscope begrenzt Quellarbeit. `@MaxZeilen` wird erst auf die vollständig gesammelten Signale angewandt und begrenzt weder Datenbankcursor noch vorgelagerte Feedbackabfragen. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, Standardlimit und CONSOLE. Die zwingende `CATALOG_DEEP`-Bestätigung nicht mit einer Freigabe für alle Datenbanken verwechseln; zunächst Status-/Versionspfad lesen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurationssnapshot + persistierte Feedbackhistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche IQP-Funktionen sind technisch möglich, konfiguriert und durch sichtbare Query-/Planfeedbacksignale belegt?

### Technischer Hintergrund

IQP umfasst unter anderem PSP, OPPO, Memory Grant Feedback, DOP/CE Feedback, Adaptive Joins, Deferred Compilation und weitere versions-/compatibilityabhängige Features. Database Scoped Configurations und Query-Store-basierte Feedbacks sind getrennte Ebenen.

### Datenkette

`sys.database_automatic_tuning_options`, `sys.database_query_store_options`, `sys.database_scoped_configurations`, `sys.databases`, `sys.dm_db_tuning_recommendations`, `sys.query_store_plan_feedback`, `sys.query_store_query_variant`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Version-/Compatibility-/Configurationzustand plus persistierte, sichtbare Feedback-/Variantenevidenz.

### Bewertung und Gegenprobe

`Eligible`, Configuration Value, Query Store State und Evidence Count trennen. Ein Signal führt zur konkreten Query-/Plananalyse, nicht zur pauschalen Aktivierung/Deaktivierung.

### Typische Fehlinterpretation

`Eligible=1` ist kein Wirksamkeitsbeweis; `EvidenceCount=0` beweist weder fehlendes Problem noch Featureversagen.

### Folgeanalyse

Query Store Runtime/PlanChanges, Showplan und konkrete Parameterworkload.

## Primärquellen

- [Intelligent query processing](https://learn.microsoft.com/en-us/sql/relational-databases/performance/intelligent-query-processing?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#8-monitorusp_intelligentqueryprocessinganalysis)
