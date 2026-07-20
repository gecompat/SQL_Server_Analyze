# [monitor].[USP_ServerMemory]

**Bereich:** Server Health<br>
**Zweck:** Verknüpft OS-, SQL-Prozess-, Target-/Total-Memory- und Clerk-Evidenz.<br>
**Beobachtungsart:** Snapshot + kumulative Runtimezähler<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Hat SQL Server oder das Betriebssystem Memory Pressure, und welche Clerks/Komponenten verwenden Speicher?** Der dokumentierte Zweck ist: Verknüpft OS-, SQL-Prozess-, Target-/Total-Memory- und Clerk-Evidenz. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Zustand; Clerk-/Processwerte verändern sich, einzelne Counter seit Start. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerMemory]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `summary` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Memory-Zusammenfassung, Prozess-/OS-Signal oder einen Memory Clerk.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

OS Available Memory, SQL Process Memory, Target/Total Server Memory, Pressure-Signale und größte Clerks gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

OS- und SQL-Druck gleichzeitig kann Paging, Cacheverdrängung und Grantknappheit verursachen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Total Server Memory nahe Target ist im Steady State normal: SQL Server soll zugewiesenen Speicher nutzen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Total≈Target allein ist gesund. Total≈Target plus kaum OS-Reserve, Physical Memory Low und Grantwaits ist problematisch. Grants, Buffer Pool und max server memory prüfen.

**Ähnlich aussehender Gegenfall:** Total Server Memory nahe Target ist im Steady State normal: SQL Server soll zugewiesenen Speicher nutzen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_ServerMemory` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Ein Instanzsnapshot aus je einer OS-/Prozess-/SQLOS-Summaryzeile, den Top 100 aggregierten Memory-Clerk-Typen und einer aggregierten Memory-Grant-Zeile. |
| Teuerster Pfad | `@MaxZeilen = 0` auf einer Instanz mit sehr vielen Clerktypen; alle Clerkzeilen werden gruppiert und ausgegeben. Die Grantquelle bleibt eine Aggregatzeile, nicht ein Detailinventar. |
| Haupttreiber | Zahl der Memory-Clerk-Zeilen und -Typen; OS-, Prozess-, SQLOS- und Grantzusammenfassung besitzen feste Granularität. Das Clerk-TOP greift erst nach der Typaggregation. |
| Skalierung | Dominant ist Gruppierung/Sortierung von `sys.dm_os_memory_clerks`; die anderen DMVs und zwei Konfigurationszeilen sind klein. Keine Datenbank-, Datei- oder Cross-Database-Schleife. |
| Ressourcen | Geringe bis mittlere CPU/SQLOS-DMV-Arbeit und Speicher für Clerkaggregation; kein Volume-, msdb-, Benutzerdaten- oder Textzugriff. |
| Begrenzungswirkung | `@MaxZeilen` wird als TOP erst nach Gruppierung der Clerkzeilen angewandt. Es begrenzt ausgegebene Clerktypen, nicht den Scan/Aggregationsaufwand; Summary und Grantaggregat bleiben unabhängig davon vollständig. |
| Locking und Nebenwirkungen | Read-only; kurze Metadatenzugriffe und nicht atomare Runtime-DMVs. Es wird weder CHECKDB noch Growth noch Konfigurationsänderung ausgeführt. |
| Schutzmechanismus | Kein Gate. Die drei Summaryquellen und das Grantaggregat haben feste Granularität; nur die Clerktypen sind variabel und werden standardmäßig auf 100 Ausgaberänge begrenzt. Dieses TOP ist kein Schutz vor der vorherigen Clerkaggregation. |
| Sicherer Einsatz | Defaultlimit 100. Ein unbegrenztes Clerkresultset nur bei konkreter Clerkfrage und nach Prüfung der vorhandenen Typanzahl anfordern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot + kumulative Runtimezähler“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Hat SQL Server oder das Betriebssystem Memory Pressure, und welche Clerks/Komponenten verwenden Speicher?

### Technischer Hintergrund

SQL Server Memory Manager balanciert Buffer Pool, Plan Cache, Query Execution Memory und weitere Clerks unter Min/Max Server Memory. OS-/Process-DMVs zeigen physisches Memory, Commit/Pagefile und Process Working Set. Target versus Total Server Memory und Memory Notifications liefern Drucksignale.

### Datenkette

`sys.configurations`, `sys.dm_exec_query_memory_grants`, `sys.dm_os_memory_clerks`, `sys.dm_os_process_memory`, `sys.dm_os_sys_info`, `sys.dm_os_sys_memory`.

### Zeit- und Scope-Modell

Aktueller Zustand; Clerk-/Processwerte verändern sich, einzelne Counter seit Start.

### Bewertung und Gegenprobe

OS Available/Commit, process physical/virtual low flags, Total/Target, Max Server Memory, locked pages, clerk distribution, pending grants und paging zusammen lesen. Hoher SQL-Memoryverbrauch allein ist erwartbar.

### Typische Fehlinterpretation

`Available MBytes` oder PLE besitzen keine universellen Einzelgrenzen. Buffer Pool und Query Grants sind unterschiedliche Verbraucher; VM Ballooning kann außerhalb SQL-Sicht liegen.

### Folgeanalyse

`USP_BufferPoolAnalysis`, Current Memory Grants, Performance Counters und OS/Hypervisor-Telemetrie.

## Primärquellen

- [sys.dm_os_process_memory](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-process-memory-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#3-monitorusp_servermemory)
