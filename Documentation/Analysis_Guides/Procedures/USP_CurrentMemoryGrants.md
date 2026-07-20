# [monitor].[USP_CurrentMemoryGrants]

**Bereich:** Current State<br>
**Zweck:** Zeigt angeforderte, gewährte und genutzte Query Execution Memory Grants.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Queries besitzen oder erwarten Workspace Memory für Sorts, Hashes und ähnliche Operatoren?** Der dokumentierte Zweck ist: Zeigt angeforderte, gewährte und genutzte Query Execution Memory Grants. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Ihr Zeitvertrag lautet ausdrücklich: Flüchtiger Zustand. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentMemoryGrants]
      @NurWartende = 1,
      @MitSqlText = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

So beginnt die Triage bei tatsächlich wartenden Grants und vermeidet zunächst
SQL-Textmaterialisierung. Für eine Kapazitätssicht auf bereits gewährte Grants
`@NurWartende` anschließend bewusst auf `0` setzen.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `memoryGrants` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem sichtbaren Memory-Grant-Vorgang einer Query beziehungsweise eines Requests.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

`RequestedMemoryMb`, `GrantedMemoryMb`, `UsedMemoryMb`, Wartezeit, Queryzustand und konkurrierende Grants vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ein großer angeforderter Grant mit `GrantedMemoryMb=0` wartet auf verfügbaren Execution Memory. Viele wartende Requests können einen Stau bilden.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein großer gewährter und tatsächlich genutzter Grant kann für einen großen Sort oder Hash Join angemessen sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 32 GB angefordert, 0 gewährt, 60 Sekunden `RESOURCE_SEMAPHORE`: Die Query rechnet nicht langsam, sie durfte noch nicht beginnen. Dagegen sind 32 GB gewährt und 28 GB genutzt bei einem geplanten großen Report plausibel.

**Bisher dokumentierter Folgeschritt:** Plan, Kardinalität, DOP, Konkurrenz und `USP_ServerMemory` prüfen.

**Ähnlich aussehender Gegenfall:** Ein großer gewährter und tatsächlich genutzter Grant kann für einen großen Sort oder Hash Join angemessen sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentMemoryGrants` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Gering; die DMV enthält nur aktuelle Grants/Anforderungen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Ein Snapshot der aktuell vorhandenen Memory Grants mit Defaultlimit 1000. SQL-Text ist standardmäßig aktiv, wird aber nur für die begrenzte Kandidatenmenge aufgelöst und auf 3000 Zeichen gekürzt. |
| Teuerster Pfad | `@MaxZeilen = 0`, keine Session-/Größenfilter und ungekürzter SQL-Text während sehr vieler gleichzeitig wartender oder gewährter Grants. Zusätzlich werden Workload-Group-, Pool- und Semaphorekontext je Grant korreliert. |
| Haupttreiber | Zahl gleichzeitig wartender/gewährter Grants und ihrer Request-, Semaphore-, Workload-Group- und Poolkorrelationen. Ungekürzter SQL-Text verbreitert jeden behaltenen Kandidaten; Filter und N+1-Limit reduzieren ihn vor der Textauflösung. |
| Skalierung | Die normalerweise kleine DMV-Menge bestimmt die Join- und Sortierarbeit. Breite oder ungekürzte Batchtexte erhöhen Speicher und Transfer; die Procedure liest keine Pläne und keine Benutzertabellen. |
| Ressourcen | CPU und Arbeitsspeicher für Live-DMV-Joins und Sortierung; bei `@MitSqlText = 1` zusätzlicher Plan-Cache-/Textzugriff und Ergebnistransfer. |
| Begrenzungswirkung | Session-, Waiting- und MB-Filter stehen in der Quellabfrage. Intern werden höchstens `@MaxZeilen + 1` Kandidaten materialisiert, um `HasMoreRows` zu bestimmen. Der DMV-/Joinpfad kann für Filter und Sortierung dennoch mehr Quellzeilen untersuchen; `@MaxSqlTextZeichen` begrenzt nur Textbreite. |
| Locking und Nebenwirkungen | Read-only gegenüber Nutzdaten. Flüchtige DMVs werden nacheinander gelesen; Katalog-/SQL-Textauflösung kann kurze interne Synchronisation verursachen, erzeugt aber keinen atomaren Snapshot. |
| Schutzmechanismus | Kein High-Impact-Gate. Session-, Waiting- und Größenfilter sowie das N+1-Kandidatenlimit wirken vor der Textauflösung; `@MitSqlText = 0` und das Zeichenbudget sparen Breite. Das Sortieren/Filtern der sichtbaren Grantquelle bleibt notwendig. |
| Sicherer Einsatz | Bei akuter Grantwartefrage mit `@NurWartende = 1`, endlichem Limit und zunächst `@MitSqlText = 0` beginnen; Text nur für identifizierte Sessions ergänzen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Queries besitzen oder erwarten Workspace Memory für Sorts, Hashes und ähnliche Operatoren?

### Technischer Hintergrund

Der Optimizer schätzt den benötigten Query Execution Memory Grant aus Plan, Kardinalität, Row Size und DOP. Ein Request kann erst starten beziehungsweise bestimmte Operatoren ausführen, wenn der Grant verfügbar ist. `sys.dm_exec_query_memory_grants` zeigt angefordert, gewährt, genutzt und ideal sowie wartende Grants.

### Datenkette

`sys.databases`, `sys.dm_exec_query_memory_grants`, `sys.dm_exec_query_resource_semaphores`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_resource_governor_resource_pools`, `sys.dm_resource_governor_workload_groups`.

### Zeit- und Scope-Modell

Flüchtiger Zustand. Wartende Grants verschwinden bei Zuteilung/Abbruch; Nutzung verändert sich während der Ausführung.

### Bewertung und Gegenprobe

Wartedauer, Requested/Granted/Used/Ideal, DOP, Konkurrenz und Planoperatoren zusammen lesen. Große tatsächlich genutzte Grants können korrekt sein; großer ungenutzter Anteil spricht eher für Übergrant oder Schätzfehler.

### Typische Fehlinterpretation

`GrantedMemory=0` kann vor Start normal kurz sichtbar sein; ein einzelner großer Grant beweist keinen Servermemorymangel. Server Memory und Query Execution Memory sind verwandte, aber nicht identische Ebenen.

### Folgeanalyse

`USP_CurrentRequests`, `USP_ServerMemory`, Showplan/Statistics und Query Store Runtime.

## Primärquellen

- [sys.dm_exec_query_memory_grants](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-memory-grants-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#6-monitorusp_currentmemorygrants)
