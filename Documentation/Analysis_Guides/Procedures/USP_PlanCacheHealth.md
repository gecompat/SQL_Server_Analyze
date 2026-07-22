# [monitor].[USP_PlanCacheHealth]

**Bereich:** Plan Cache<br>
**Zweck:** Bewertet Cachegröße, Kategorien und Single-Use-Anteil.<br>
**Beobachtungsart:** flüchtiger Cache-Snapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie viel Memory bindet der Plan Cache und welche Planarten/Use-Count-Muster dominieren?** Der dokumentierte Zweck ist: Bewertet Cachegröße, Kategorien und Single-Use-Anteil. Der Aufruf soll die Arbeitsentscheidung vorbereiten, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Cachebestand; flüchtig und durch Workload/Memorydruck verändert. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanCacheHealth]
      @AnalyseModus = 'SUMMARY',
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `overview` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile den gesamten Cache, eine Cachekategorie, eine Datenbankaggregation oder einen einzelnen Single-Use-Plan.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Gesamtgröße, Plananzahl, Single-Use-Anteil, Use Counts, Planarten und aktuellen Memory Pressure gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Viele große Single-Use-Pläne belegen Cache für selten wiederverwendete Texte und können nützlichere Pläne oder Datenseiten verdrängen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Hoher Single-Use-Anteil ohne Speicherdruck ist technische Schuld, aber möglicherweise kein akuter Engpass.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 70 % Single-Use bei reichlich freiem Speicher ist weniger dringend als 20 % bei starkem Memory Pressure. Textvarianz, Parametrisierung, Optimize for Ad Hoc und Servermemory prüfen.

**Ähnlich aussehender Gegenfall:** Hoher Single-Use-Anteil ohne Speicherdruck ist technische Schuld, aber möglicherweise kein akuter Engpass. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_PlanCacheHealth` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Basis gruppiert die Plan-Cache-DMV. Datenbankverteilung und Details sind opt-in und PLAN_CACHE_DEEP-geschützt.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | `SUMMARY`: der gesamte sichtbare Plan Cache wird einmal nach Cache-/Objekttyp aggregiert; keine Datenbankverteilung, Single-Use-Details oder SQL-Texte. |
| Teuerster Pfad | `VOLL`, Datenbankverteilung und Single-Use-Details, `@MaxZeilen = 0` sowie ungekürzte Texte auf einem sehr großen, ad-hoc-lastigen Plan Cache. |
| Haupttreiber | Zahl der Cacheeinträge und der je Plan auszulesenden Attribute sowie Gruppierung nach Cache-/Objekttyp. Das Ergebnis ist klein, aber Kategorien und Single-Use-Anteile benötigen zuvor den breiten Cache-Snapshot. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_PlanCacheHealth ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Speicher für Cache-DMV-Scan, Textauflösung, Gruppierung und Sortierung; Ergebnistransfer bei langen Texten. |
| Begrenzungswirkung | Der Summarypfad gruppiert vor jeder Ausgabe den gesamten sichtbaren Cache. `@MaxZeilen` begrenzt nur Single-Use-Details; Datenbankverteilung und Summary müssen ihre jeweiligen Cachezeilen zuvor attributseitig auflösen/aggregieren. |
| Locking und Nebenwirkungen | Keine Nutzdatenlocks. Cacheeinträge können während des Lesens evicted oder neu kompiliert werden; Text-/Attributauflösung ist daher nicht atomar. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `PLAN_CACHE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Mit `SUMMARY` starten. `VOLL`, Datenbankverteilung oder Single-Use-Details nur nach Summary/Cachegrößenprüfung, mit endlichem Limit und `@HighImpactConfirmed = 1`. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „flüchtiger Cache-Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie viel Memory bindet der Plan Cache und welche Planarten/Use-Count-Muster dominieren?

### Technischer Hintergrund

Cache Stores und Cached Plans zeigen Planarten, Objekt-/Ad-hoc-Pläne, Größen und Use Counts. Viele Single-Use-Ad-hoc-Pläne können Kompilierungs-/Memorydruck erzeugen; Clock Hands und Memory Pressure steuern Eviction.

### Datenkette

`sys.configurations`, `sys.dm_exec_cached_plans`, `sys.dm_exec_plan_attributes`, `sys.dm_exec_sql_text`.

### Source Select

Cachegröße und Nutzungsgrad stammen aus `dm_exec_cached_plans`; der Datenbankbezug wird gezielt aus den Planattributen gelesen:

```sql
SELECT
      [cp].[cacheobjtype]
    , [cp].[objtype]
    , [cp].[usecounts]
    , [cp].[size_in_bytes]
    , TRY_CONVERT(int, [dbid].[value]) AS [DatabaseId]
FROM [sys].[dm_exec_cached_plans] AS [cp] WITH (NOLOCK)
OUTER APPLY
(
    SELECT TOP (1) [pa].[value]
    FROM [sys].[dm_exec_plan_attributes]([cp].[plan_handle]) AS [pa]
    WHERE [pa].[attribute] = N'dbid'
) AS [dbid]
WHERE [cp].[cacheobjtype] = N'Compiled Plan';
```

**Wichtig für die Eigenlast:** Cacheobjekttyp vor Planattribut- und SQL-Textauflösung filtern. Für reine Gesamtgrößenanalyse sind Text und Datenbankattribute nicht erforderlich und sollten ausgeschaltet bleiben.

### Zeit- und Scope-Modell

Aktueller Cachebestand; flüchtig und durch Workload/Memorydruck verändert.

### Bewertung und Gegenprobe

Cachegröße relativ zu Servermemory, Single-Use-Anteil in Bytes und Count, Ad-hoc-Workload, Compile/sec und Parameterisierungsstrategie bewerten.

### Typische Fehlinterpretation

Viele Single-Use-Pläne sind nicht automatisch Hauptproblem. `optimize for ad hoc workloads` reduziert zunächst Stubgröße, behebt aber keine Querygenerierung oder Compileursache.

### Folgeanalyse

`USP_ServerMemory`, Performance Counters, Query Hash und Anwendung/Parameterisierung.

## Primärquellen

- [sys.dm_exec_cached_plans](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-cached-plans-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#3-monitorusp_plancachehealth)
