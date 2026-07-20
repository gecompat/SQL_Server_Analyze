# [monitor].[USP_ExtendedEventsTargetRuntime]

**Bereich:** Extended Events<br>
**Zweck:** Zeigt Runtimezustand und optional Daten laufender XE-Targets.<br>
**Beobachtungsart:** Konfigurations- und Runtime-Snapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Verliert, begrenzt oder rotiert das Target Ereignisse, und ist es für die gewünschte Historie geeignet?** Der dokumentierte Zweck ist: Zeigt Runtimezustand und optional Daten laufender XE-Targets. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob die konfigurierte Ereignisquelle die gesuchte Situation erfasst hat und welche einzelne Datei, Session oder XML-Struktur anschließend vertieft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ereignisse, die nicht konfiguriert, vor Sessionstart aufgetreten oder durch Rollover/Targetgrenzen verloren gegangen sind. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Runtimezustand und Targetinhalt seit Sessionstart beziehungsweise Rollover. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ExtendedEventsTargetRuntime]
      @MitTargetData = 0,
      @BestaetigeTargetFlush = 0,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Der Aufruf passiert das zwingende `EXTENDED_EVENTS_FORENSICS_DEEP`-Gate, bestätigt aber keinen Target-Flush und liefert daher bewusst nur den deaktivierten Statuspfad. Einen Flush und Targetdaten erst nach eigener Prüfung separat bestätigen; das High-Impact-Gate allein löst keinen Flush aus.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `targets` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Target einer laufenden Session. Optionales Targetdata-Resultset besitzt targetabhängige Struktur.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Targettyp, Laufzeitstatus, Pfad, Speicher, Event-/Bufferzähler und Dropped Events prüfen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Dropped Events oder zu kleine Targets bedeuten Evidenzverlust. Das Lesen bestimmter Runtime-Targets kann einen Flush auslösen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein kleiner Ringbuffer kann für kurzfristige Ad-hoc-Diagnose passend sein, aber nicht für lange Historie.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Session läuft, aber viele Events wurden verworfen: ein leeres Spezialresultset ist keine Entwarnung. Targetgröße, Eventrate und Event-File-Strategie prüfen.

**Ähnlich aussehender Gegenfall:** Ein kleiner Ringbuffer kann für kurzfristige Ad-hoc-Diagnose passend sein, aber nicht für lange Historie. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Eine laufende Session kann ohne passendes Ereignis leer sein; außerdem können Target, Dateipfad, Rollover, Flushzustand und Berechtigung die Sicht einschränken.

Für `USP_ExtendedEventsTargetRuntime` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Normalerweise gering, kann aber durch große target_data-Inhalte sowie einen Target-Flush merkbar werden.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Inventar-/Runtime-Snapshot mit Session- und Targetfilter; Targetdaten ausgeschaltet oder stark gekürzt. |
| Teuerster Pfad | Viele große Targetdokumente mit `@MitTargetData = 1`, hohem Zeichenbudget und ausdrücklich bestätigtem Target-Flush. |
| Haupttreiber | Zahl laufender Session-/Targetkombinationen und – bei `@MitTargetData = 1` – Größe der jeweiligen `target_data`-XML. Zeichenbudget reduziert die Rückgabebreite; ein bestätigter Flush kann vorher zusätzliche Targetarbeit auslösen. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_ExtendedEventsTargetRuntime ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Speicher für XE-Katalog-/Runtimezeilen; bei Targetdata zusätzlich XML-/Stringmaterialisierung und Transfer. |
| Begrenzungswirkung | Session-/Targetfilter reduzieren die Quelle. Eine Zeichenkürzung begrenzt Transfer, nicht zwingend die Erzeugung des Targetdokuments durch die Engine. |
| Locking und Nebenwirkungen | Keine Konfigurationsänderung, aber das Lesen von `sys.dm_xe_session_targets` kann Targetpuffer flushen. Deshalb liest die Procedure diese DMV erst nach `@BestaetigeTargetFlush = 1`; Session- und Targetzustand können sich während des Aufrufs trotzdem ändern. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `EXTENDED_EVENTS_FORENSICS_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine ExampleSession, `@MitTargetData = 0` und kein Flush; Targetinhalt und Flush nur gezielt mit kleinem Zeichenbudget anfordern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Konfigurations- und Runtime-Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Verliert, begrenzt oder rotiert das Target Ereignisse, und ist es für die gewünschte Historie geeignet?

### Technischer Hintergrund

Runtime-DMVs liefern Targettyp/-daten, Buffer-/Memory-/Eventcounter und je Version Drop-/Dispatchinformationen. Event File Konfiguration bestimmt Dateigröße/Rollover; Ring Buffer hat XML-/Memorygrenzen.

### Datenkette

`master.sys.databases`, `sys.dm_xe_session_targets`, `sys.dm_xe_sessions`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Runtimezustand und Targetinhalt seit Sessionstart beziehungsweise Rollover.

### Bewertung und Gegenprobe

Dropped Events/Buffers, Memory, File/Ring-Buffer-Auslastung, Dispatch Latency, Retention Mode und Eventrate zusammen lesen. Target muss zur Ereignisrate passen.

### Typische Fehlinterpretation

`0 Drops` beweist keine ausreichende historische Retention; sauberes Rollover kann alte Ereignisse ohne Dropindikator entfernen.

### Folgeanalyse

Sessionkonfiguration anpassen, externe Dateiretention/Monitoring und Eventreader validieren.

## Primärquellen

- [Extended Events](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/extended-events?view=sql-server-ver17)

[Technische Detailbeschreibung](../06_Extended_Events.md#5-monitorusp_extendedeventstargetruntime)
