# [monitor].[USP_BufferPoolAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Zeigt Buffer-Pool-Verteilung, Memory Clerks und Pressure-Kontext.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie verteilt sich der Buffer Pool auf Datenbanken, Objekte und Pagearten, und gibt es Hinweise auf Cache-/Memorydruck?** Der dokumentierte Zweck ist: Zeigt Buffer-Pool-Verteilung, Memory Clerks und Pressure-Kontext. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Cachebestand; laufend durch Reads, Writes, Checkpoint und Memory Pressure verändert. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_BufferPoolAnalysis]
      @MitMemoryClerks = 1,
      @MitBufferPoolVerteilung = 0,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `memory` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Memoryzusammenfassung, einen Clerk oder eine Datenbank-/Page-Verteilung.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Gesamtbuffer, Clerks, Datenbankanteile, Dirty/Clean Pages und Memory Pressure gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Dominante Clerks oder ungewöhnliche Verteilung können Speicher verdrängen; viele Dirty Pages können Checkpoint-/I/O-Druck anzeigen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Eine große aktive Datenbank darf den Buffer Pool dominieren.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 80 % Buffer für ExampleDatabase ist nicht automatisch schlecht. Problematisch wird es, wenn andere aktive Datenbanken physisch lesen und Memory Pressure besteht. Memory, I/O und Query Reads prüfen.

**Ähnlich aussehender Gegenfall:** Eine große aktive Datenbank darf den Buffer Pool dominieren. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_BufferPoolAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Memorysummary und begrenzte Clerk-/Semaphore-Sicht ohne Buffer-Pool-Verteilung. |
| Teuerster Pfad | Aktivierte Buffer-Pool-Verteilung auf einer Instanz mit sehr großem Cache; MaxZeilen wirkt erst nach Descriptoraggregation. |
| Haupttreiber | Zahl der Memory-Clerk-Typen und – nur bei aktivierter Verteilung – aller sichtbaren Buffer Descriptors vor der Gruppierung. Memory-/Semaphore-Summary ist klein; ein kleines Ausgabelimit verkürzt den Descriptor-Scan nicht. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_BufferPoolAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | SQLOS-DMV-CPU; der optionale Scan von sys.dm_os_buffer_descriptors wächst mit der Zahl gecachter Pages und benötigt Aggregationsspeicher. |
| Begrenzungswirkung | MaxZeilen kürzt die ausgegebenen Gruppen. Bei aktivierter Buffer-Pool-Verteilung wird die Descriptorquelle dennoch vor der Gruppierung breit gelesen. |
| Locking und Nebenwirkungen | Keine Nutzdatenlocks oder Cachebereinigung; der breite Descriptor-Scan verbraucht jedoch CPU/Schedulerzeit auf der beobachteten Instanz. |
| Schutzmechanismus | Kein High-Impact-Gate. Der wichtigste Schutz ist, `@MitBufferPoolVerteilung = 0` zu belassen; nur dadurch entfällt der breite Descriptorpfad. `@MitMemoryClerks` steuert die Clerksicht, während `@MaxZeilen` nach der jeweiligen Aggregation lediglich die Ausgabe kürzt. |
| Sicherer Einsatz | Mit @MitBufferPoolVerteilung=0 starten; Verteilung nur nach Summary und außerhalb der Lastspitze aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie verteilt sich der Buffer Pool auf Datenbanken, Objekte und Pagearten, und gibt es Hinweise auf Cache-/Memorydruck?

### Technischer Hintergrund

Buffer Descriptors repräsentieren gecachte 8-KB-Datenseiten. Verteilung nach Database/File/Page/Object kann Working Set zeigen; Memory Clerks und PLE/Lazy Writes ergänzen Drucksignale. Clean Pages sind verwerfbar, Dirty Pages benötigen Flush.

### Datenkette

`sys.dm_exec_query_resource_semaphores`, `sys.dm_os_buffer_descriptors`, `sys.dm_os_memory_clerks`, `sys.dm_os_process_memory`, `sys.dm_os_sys_memory`.

### Source Select

Der datenbankbezogene Buffer-Pool-Kern entsteht durch Gruppierung der Buffer Descriptors und Zuordnung zur Datenbank:

```sql
SELECT
      [d].[name] AS [DatabaseName]
    , COUNT_BIG(*) AS [CachedPages]
    , COUNT_BIG(*) * 8.0 / 1024.0 AS [CachedMb]
FROM [sys].[dm_os_buffer_descriptors] AS [bd] WITH (NOLOCK)
JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id] = [bd].[database_id]
WHERE [d].[name] = N'ExampleDatabase'
GROUP BY [d].[name];
```

**Wichtig für die Eigenlast:** `sys.dm_os_buffer_descriptors` kann sehr groß sein. Ein Datenbankprädikat reduziert Ergebnis und Aggregation, garantiert aber nicht, dass die Engine die DMV intern nur teilweise materialisiert; deshalb den Detailpfad bewusst verwenden.

### Zeit- und Scope-Modell

Aktueller Cachebestand; laufend durch Reads, Writes, Checkpoint und Memory Pressure verändert.

### Bewertung und Gegenprobe

Cached MB/Pages, Dirtyanteil, Datenbank-/Objektanteil, Page Life/Reads, OS-/Processdruck und Workloadgröße kombinieren. Dominanter Cacheanteil kann legitimes Working Set sein.

### Typische Fehlinterpretation

Bufferanteil ist keine Hit Ratio und häufig gecacht bedeutet nicht automatisch problematisch. Breiter Descriptor-Scan kann selbst CPU/Memory/I/O-Metadatenlast erzeugen.

### Folgeanalyse

Server Memory, Performance Counters, Query Reads/Plans; Deep-Pfad nur kontrolliert.

## Primärquellen

- [sys.dm_os_buffer_descriptors](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-buffer-descriptors-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#16-monitorusp_bufferpoolanalysis)
