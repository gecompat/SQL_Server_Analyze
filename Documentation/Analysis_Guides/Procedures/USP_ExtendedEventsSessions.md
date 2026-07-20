# [monitor].[USP_ExtendedEventsSessions]

**Bereich:** Extended Events<br>
**Zweck:** Inventarisiert XE-Sessions, Laufzeitstatus, Events, Actions, Targets und Felder.<br>
**Beobachtungsart:** Konfigurations- und Runtime-Snapshot<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche XE-Sessions existieren, laufen sie, welche Events/Actions/Predicates und Targets besitzen sie?** Der dokumentierte Zweck ist: Inventarisiert XE-Sessions, Laufzeitstatus, Events, Actions, Targets und Felder. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob die konfigurierte Ereignisquelle die gesuchte Situation erfasst hat und welche einzelne Datei, Session oder XML-Struktur anschließend vertieft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ereignisse, die nicht konfiguriert, vor Sessionstart aufgetreten oder durch Rollover/Targetgrenzen verloren gegangen sind. Ihr Zeitvertrag lautet ausdrücklich: Aktuelle Konfiguration plus Runtimezustand; Serverstart und Sessionstart beeinflussen Targetinhalt. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsSessions]
      @ExtendedEventSessionNames = N'ExampleSession',
      @MitEvents = 1,
      @MitActions = 0,
      @MitTargets = 1,
      @MitFeldern = 0,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Dieser Einstieg grenzt das Inventar auf eine synthetisch benannte Session ein.
Er liest Konfiguration und optionalen Laufzeitstatus, aber weder `target_data`
noch XEL-Dateien und löst deshalb keinen Target-Flush aus.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `sessions` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Session, einem Event, einer Action, einem Target oder einem konfigurierten Feld.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Sessiondefinition, Laufzeitstatus, Events, Actions, Targets, Predicates und Verlustzähler getrennt prüfen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Eine definierte, aber gestoppte Session sammelt nichts. Fehlende Actions begrenzen spätere Korrelation; Dropped Events machen Historie unvollständig.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Eine bewusst nur bei Bedarf gestartete Session darf gestoppt sein.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Deadlockevent vorhanden, aber nur kleiner Ringbuffer: historische Tiefe kann fehlen. Danach Target Runtime und Events prüfen.

**Ähnlich aussehender Gegenfall:** Eine bewusst nur bei Bedarf gestartete Session darf gestoppt sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Eine laufende Session kann ohne passendes Ereignis leer sein; außerdem können Target, Dateipfad, Rollover, Flushzustand und Berechtigung die Sicht einschränken.

Für `USP_ExtendedEventsSessions` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Gering. Es werden nur Extended-Events-Katalogviews und optional sys.dm_xe_sessions gelesen. Targetdaten werden nicht gelesen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Liest Sessiondefinitionen, laufenden Status sowie standardmäßig Events, Actions und Targets; explizit konfigurierte Felder sind mit `@MitFeldern = 0` aus. `target_data` wird in keinem Pfad dieser Procedure gelesen. |
| Teuerster Pfad | Ungefiltertes Inventar mit allen fünf Detailarten, `@MitFeldern = 1` und `@MaxZeilen = 0`; die Kosten bleiben Katalog-/Runtimekosten und enthalten weder XEL-Lesen noch XML-Parsing von Targetinhalten. |
| Haupttreiber | Anzahl der definierten Sessions und ihrer Events, Actions, Targets und Felder. `sys.dm_xe_sessions` ergänzt nur für aktuell laufende Sessions den Runtimezustand. |
| Skalierung | Jede aktivierte Detailart wird separat aus den `sys.server_event_session_*`-Katalogviews materialisiert und sortiert. Viele Konfigurationselemente erhöhen CPU, Temp-Tabellen- und Transferkosten; nicht die Ereignismenge in den Targets. |
| Ressourcen | Geringe bis mittlere CPU für XE-Katalogviews, den optionalen Join auf `sys.dm_xe_sessions`, Filterung und Ausgabe. Es gibt keinen Targetdata-, XML- oder Datei-I/O-Pfad. |
| Begrenzungswirkung | Exakte Namen und LIKE-Pattern wirken in den Katalogabfragen. `@MaxZeilen` begrenzt jedes Detailresultset separat, nicht die Summe aller Resultsets. Regex wird nach der Materialisierung angewandt; dadurch schützt ein kleines Limit zwar die Menge, kann aber passende, zuvor nicht ausgewählte Zeilen ausblenden. |
| Locking und Nebenwirkungen | Read-only. Die Procedure startet oder stoppt keine XE-Session und liest `sys.dm_xe_session_targets` nicht; deshalb verursacht sie keinen Target-Flush. Katalog und Laufzeitstatus sind nicht atomar und können während des Aufrufs auseinanderlaufen. |
| Schutzmechanismus | Kein Forensik-Gate, weil diese Procedure weder XEL noch `target_data` liest. Session-/Event-/Targetfilter, einzelne `@Mit...`-Schalter und das je Resultset wirkende Limit begrenzen das Inventar; `@MitFeldern = 0` spart die größte optionale Katalogprojektion. |
| Sicherer Einsatz | Eine `ExampleSession`, nicht benötigte Detailarten abschalten und je Resultset ein kleines `@MaxZeilen` verwenden. Für Ereignisinhalt anschließend gezielt `USP_ExtendedEventsReadEvents`; für Targetdaten bewusst `USP_ExtendedEventsTargetRuntime` mit dessen separaten Gates wählen. |
| Aussagegrenze | Die Ausgabe beschreibt Definition und momentanen Laufzeitstatus, nicht die in Targets gespeicherten Ereignisse. Ein fehlendes Event im Inventar heißt „nicht konfiguriert“; ein vorhandenes Event beweist weder Auslösung noch Aufbewahrung. Limits und späte Regexfilter können die sichtbare Konfiguration zusätzlich verkürzen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche XE-Sessions existieren, laufen sie, welche Events/Actions/Predicates und Targets besitzen sie?

### Technischer Hintergrund

Katalogsichten für Sessions, Events, Actions, Fields und Targets bilden Definitionen; Runtime-DMVs liefern gestartete Sessions und Targetdaten. Eventname allein reicht nicht, wenn für Analyse notwendige Actions wie SQL Text, DatabaseId oder SessionId fehlen.

### Datenkette

`master.sys.databases`, `sys.dm_xe_sessions`, `sys.server_event_session_actions`, `sys.server_event_session_events`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktuelle Konfiguration plus Runtimezustand; Serverstart und Sessionstart beeinflussen Targetinhalt.

### Bewertung und Gegenprobe

Definition und Runtime verbinden: Session vorhanden/läuft, Event enthalten, Predicate nicht zu eng, Actions ausreichend, Target erreichbar. Startup State ist nur Startverhalten.

### Typische Fehlinterpretation

Eine laufende Session beweist keine vollständige Erfassung. Eine konfigurierte, aber gestoppte Session besitzt möglicherweise alte Targetdaten.

### Folgeanalyse

`USP_ExtendedEventsTargetRuntime` und anschließend Eventreader.

## Primärquellen

- [Extended Events](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/extended-events?view=sql-server-ver17)

[Technische Detailbeschreibung](../06_Extended_Events.md#1-monitorusp_extendedeventssessions)
