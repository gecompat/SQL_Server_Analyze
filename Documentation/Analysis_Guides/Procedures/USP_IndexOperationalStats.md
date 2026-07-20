# [monitor].[USP_IndexOperationalStats]

**Bereich:** Object und Index<br>
**Zweck:** Zeigt partitionsgenaue DML-, Allocation-, Lock-, Latch- und Zugriffsaktivität.<br>
**Beobachtungsart:** kumulativ seit Struktur-/Instanzreset<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche internen Zugriffsmuster, Allocations, Locks und Latches erzeugt ein Index?** Der dokumentierte Zweck ist: Zeigt partitionsgenaue DML-, Allocation-, Lock-, Latch- und Zugriffsaktivität. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Kumulativ im Lebenszyklus der internen Struktur/Instanz. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IndexOperationalStats]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleTable]',
      @NurMitAktivitaet = 1,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

`GEZIELT` löst genau ein Objekt auf und übergibt dessen ID an die DMF. Ohne
Objektfilter wäre der Einstieg ungültig; `VOLL` ist ein eigener Deep-Pfad.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `indexOperationalStats` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Index oder Heap **und einer Partition**. Werte verschiedener Partitionen dürfen nur bewusst aggregiert werden.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

DML, Allocations, Locks, Latches und Scans vergleichen; absolute Zähler pro Aktivität, Wait oder Beobachtungszeit normalisieren.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Viele Page Allocations pro Insert können Split-/Wachstumsdruck anzeigen. Hohe Lock-/Latchzeit kann Parallelität und Durchsatz begrenzen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Hohe absolute Zähler sind bei stark genutzten Indizes normal. Verhältnis, Delta und aktuelle Auswirkung sind entscheidend.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine Million Latch-Waits über ein Jahr kann weniger kritisch sein als 50.000 in fünf Minuten auf derselben Hot Page. Live-Waits, Keyverteilung, Plan und Contention prüfen.

**Ähnlich aussehender Gegenfall:** Hohe absolute Zähler sind bei stark genutzten Indizes normal. Verhältnis, Delta und aktuelle Auswirkung sind entscheidend. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_IndexOperationalStats` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** GEZIELT ruft die DMF für genau ein zuvor sicher aufgelöstes Objekt auf. VOLL kann alle Heap-/B-Tree-/Columnstore-Rowsets lesen und ist deshalb explizit gruppengeschützt. TOP reduziert nicht zwingend die DMF-Arbeit.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | `GEZIELT` verlangt genau ein aufgelöstes Objekt und ruft `sys.dm_db_index_operational_stats` mit dessen ObjectId auf; inaktive Partitionen werden standardmäßig ausgeblendet. |
| Teuerster Pfad | `VOLL` über alle Datenbanken/Rowsets, Aktivitätsfilter aus und `@MaxZeilen = 0`. Ein Partitionsfilter ist in VOLL absichtlich ungültig; Scope muss über Datenbank-/Objektpattern erfolgen. |
| Haupttreiber | Zahl der von der DMF betrachteten Heap-/Index-/Partitionsrowsets. Nutzdatenzeilen werden nicht gescannt, aber VOLL muss instanzweite operative Zähler für alle Rowsets des Datenbankscope bereitstellen. |
| Skalierung | GEZIELT skaliert mit Partitionen/Indizes eines Objekts; VOLL mit allen Rowsets je Datenbank. Dynamisches SQL/DMF-Aufruf erfolgt separat pro Kandidatendatenbank. |
| Ressourcen | DMV-CPU, Katalogjoins für Namen/Typen und TempDB/Transfer. Kein Seiteninhaltsscan; die DMF selbst kann bei sehr vielen Rowsets dennoch spürbar sein. |
| Begrenzungswirkung | ObjectId und optional Index-/Partitionsfilter reduzieren GEZIELT früh. `@MaxZeilen` ist TOP in der Resultquery je Datenbank, garantiert aber nicht, dass die DMF nur diese Rowsets intern betrachtet; VOLL bleibt deshalb gatepflichtig. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `INDEX_OPERATIONAL_DEEP`, `OBJECT_ANALYSIS_CURRENT`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, genau ein `ExampleSchema.ExampleTable`, aktive Rowsets und 100 Zeilen. Erst bei klarer Flottenfrage VOLL separat bestätigen. |
| Aussagegrenze | Zähler sind kumulativ seit Instanzstart beziehungsweise Rowset-/Indexneuanlage und zeigen keine aktuelle Rate. Rebuild, Restart oder Partitionwechsel setzt Vergleichbarkeit zurück; hohe Counts benötigen Laufzeit-/Baselinebezug. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche internen Zugriffsmuster, Allocations, Locks und Latches erzeugt ein Index?

### Technischer Hintergrund

`sys.dm_db_index_operational_stats` liefert Blatt-/Nichtblattoperationen, Range-/Singleton-Lookups, Page Allocations, Lock-/Latch-Waits und weitere Low-Level-Zähler. Diese Zähler spiegeln physische Arbeitsweise wider und ergänzen die gröbere Usage-Sicht.

### Datenkette

`sys.dm_db_index_operational_stats`, `sys.indexes`, `sys.objects`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Kumulativ im Lebenszyklus der internen Struktur/Instanz. Werte können bei Neustart oder Strukturänderung zurückgesetzt werden.

### Bewertung und Gegenprobe

Zähler durch passende Aktivität normieren: Page Allocations pro Insert, Lockwaitzeit pro Lockwait, Latchwaitzeit pro Zugriff. Hohe absolute Werte sind bei stark genutzten Indizes erwartbar.

### Typische Fehlinterpretation

`leaf_allocation_count` ist nicht identisch mit dokumentiertem Page Split jeder Art. Eine Korrelation mit Fragmentierung/Fillfactor und DML-Muster ist nötig.

### Folgeanalyse

`USP_IndexPhysicalStats`, Current Blocking/Waits und konkrete DML-Pläne.

## Primärquellen

- [sys.dm_db_index_operational_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-operational-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#3-monitorusp_indexoperationalstats)
