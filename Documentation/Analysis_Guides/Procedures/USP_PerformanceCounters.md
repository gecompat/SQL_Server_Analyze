# [monitor].[USP_PerformanceCounters]

**Bereich:** Server Health<br>
**Zweck:** Liest typisierte SQL-Server-Performance-Counter und berechnet bei Bedarf Sample-/Delta-Werte.<br>
**Beobachtungsart:** kumulative Datei-/Counterwerte + optionale Stichprobe<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie werden SQL-Server-Performance-Counter korrekt als Raw, Ratio, Rate oder Delta interpretiert?** Der dokumentierte Zweck ist: Liest typisierte SQL-Server-Performance-Counter und berechnet bei Bedarf Sample-/Delta-Werte. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Rawstand oder Frameworksample; Reset typischerweise Engine-Start. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PerformanceCounters]
      @SampleSeconds = 5,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `counters` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Counter beziehungsweise einer normalisierten Countermessung für eine Instanzbezeichnung.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

`UNAVAILABLE_OBJECT` mit `IsPartial=1` bedeutet, dass die Instanz keine aktivierten oder nach Ausschluss alleinstehender Basiscounter keine auswertbaren Zeilen aus `sys.dm_os_performance_counters` bereitstellt. In diesem Zustand werden weder Snapshotwerte noch Raten synthetisiert.

Objektname, Countername und Instanzname allein sind nicht die vollständige technische Identität: `cntr_type` gehört zum Schlüssel. Gleich benannte Zeilen unterschiedlicher Typen werden deshalb getrennt gesampelt und nicht miteinander verrechnet.

Die reine Funktion `monitor.TVF_InterpretPerformanceCounter` kapselt denselben Rechenpfad. Sie ermöglicht einen deterministischen Resetnachweis mit fallendem Vorher-/Nachher-Wert, ohne einen Serverneustart während einer laufenden Procedure zu simulieren.

Countertyp, Raw Value, Base, Delta, Samplezeit und normalisierten Wert unterscheiden.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Rate- und Fraction-Counter werden ohne Typ/Base schnell falsch interpretiert. Kumulative Rohwerte spiegeln oft nur Uptime wider.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein einzelner hoher kumulativer Wert oder eine alte Faustregel ohne Baseline ist keine Diagnose.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Page Life Expectancy besitzt keine universelle feste Grenze. Ein abrupter Einbruch plus Memory Pressure und I/O ist relevanter als ein einzelner Wert. Memory, I/O und Workload prüfen.

**Ähnlich aussehender Gegenfall:** Ein einzelner hoher kumulativer Wert oder eine alte Faustregel ohne Baseline ist keine Diagnose. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_PerformanceCounters` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Mit Default `@SampleSeconds = 0` werden zwei unmittelbar aufeinanderfolgende Snapshots der ausgewählten Counter aufgenommen und typabhängig interpretiert; es gibt kein WAITFOR. Kumulative Counter bleiben kumulativ, Rate-/Bruchtypen benötigen für belastbare Werte ein echtes Sample. |
| Teuerster Pfad | Alle Counter/Instanzen, 60 Sekunden und unbegrenzte Ausgabe. Die gefilterte Countermenge wird zweimal gelesen; parallele Aufrufe halten jeweils eine Session und duplizieren die Snapshotarbeit. |
| Haupttreiber | Anzahl ausgewählter `(object_name, counter_name, instance_name)`-Kombinationen. Objekt-/Counternamen filtern bereits den ersten Snapshot; benötigte `base`-Counter werden automatisch mit aufgenommen. |
| Skalierung | Der zweite Snapshot joint nur auf die im ersten gefundenen Schlüssel. Berechnung und Speicher wachsen daher mit der gefilterten Countermenge; Sampledauer erhöht die Verbindungszeit linear, nicht die Anzahl der Counter. |
| Ressourcen | Zwei Lesezugriffe auf `sys.dm_os_performance_counters`, ein kleiner Startzeitlookup, Temp-Tabellen und CPU für typabhängige Delta-/Ratiointerpretation; optional eine wartende Verbindung. |
| Begrenzungswirkung | Objekt-/Counterlisten reduzieren die Quellmenge wirksam. `@MaxZeilen` wird dagegen erst bei RAW/CONSOLE/JSON/TABLE-Ausgabe angewandt und spart weder Snapshots noch Counterinterpretation. |
| Locking und Nebenwirkungen | Read-only. WAITFOR hält keine Nutzdatenlocks absichtlich, belegt aber die Session. Restart oder Counterrückgang zwischen den Messpunkten wird als Resetkontext behandelt; die Procedure setzt keine Counter zurück. |
| Schutzmechanismus | Kein High-Impact-Gate. Objekt-/Counterlisten reduzieren beide Snapshots früh und `@SampleSeconds` ist auf 60 begrenzt; `@MaxZeilen` ist ausdrücklich nur ein Ausgabelimit. Mehrere parallele Sampler werden durch die Procedure nicht zentral verhindert. |
| Sicherer Einsatz | Fünf Sekunden, `@MaxZeilen = 100`, möglichst konkrete Objekt-/Counternamen und nur ein Sampler. Für eine Baseline mehrere getrennte Intervalle mit identischem Filter erfassen. |
| Aussagegrenze | Ein Rohwert ohne Countertyp/Base ist nicht interpretierbar. Kurze Samples können Bursts überbetonen, lange Samples Spitzen glätten. Das Ausgabelimit ist keine repräsentative Stichprobe und kann zusammengehörige Zähler-/Basezeilen unterschiedlich sichtbar machen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie werden SQL-Server-Performance-Counter korrekt als Raw, Ratio, Rate oder Delta interpretiert?

### Technischer Hintergrund

`sys.dm_os_performance_counters` enthält Counter mit `cntr_type`. Manche sind Momentwerte, manche kumulative Zähler, manche benötigen Basecounter und manche Differenz/Zeit. Instanznamen trennen Total, DB, Buffer Node oder Objektinstanzen.

### Datenkette

`sys.dm_os_performance_counters`, `sys.dm_os_sys_info`.

### Zeit- und Scope-Modell

Aktueller Rawstand oder Frameworksample; Reset typischerweise Engine-Start.

### Bewertung und Gegenprobe

Countertyp zuerst; Ratio mit passender Base, Rate als Delta pro Zeit, kumulative Counter mit Uptime. Instance Name und Units dokumentieren. Mehrere Counter als Kausalkette verwenden.

### Typische Fehlinterpretation

Raw `cntr_value` ist nicht allgemein Prozent oder pro Sekunde. Basecounter aus anderer Instanz/Probe erzeugt falsche Ratio.

### Folgeanalyse

Server Memory/CPU/IO, Current State und OS-Counter.

## Primärquellen

- [sys.dm_os_performance_counters](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-performance-counters-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#13-monitorusp_performancecounters)
