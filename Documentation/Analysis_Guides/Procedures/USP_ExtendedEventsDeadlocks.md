# [monitor].[USP_ExtendedEventsDeadlocks]

**Bereich:** Extended Events<br>
**Zweck:** Zerlegt Deadlockgraphs in Summary, Victims, Processes und Resources.<br>
**Beobachtungsart:** retentionbegrenzte Ereignishistorie<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Sessions/Prozesse bildeten einen Deadlockzyklus, welches Opfer wurde gewählt und welche Ressourcen/Kanten waren beteiligt?** Der dokumentierte Zweck ist: Zerlegt Deadlockgraphs in Summary, Victims, Processes und Resources. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob die konfigurierte Ereignisquelle die gesuchte Situation erfasst hat und welche einzelne Datei, Session oder XML-Struktur anschließend vertieft wird. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ereignisse, die nicht konfiguriert, vor Sessionstart aufgetreten oder durch Rollover/Targetgrenzen verloren gegangen sind. Ihr Zeitvertrag lautet ausdrücklich: Einzelne historische Deadlockereignisse soweit im Target erhalten. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
DECLARE @ExampleVonUtc datetime2(7) = DATEADD(HOUR, -24, SYSUTCDATETIME());

EXEC [monitor].[USP_ExtendedEventsDeadlocks]
      @SourceExtendedEventSessionName = N'system_health',
      @VonUtc = @ExampleVonUtc,
      @MitDeadlockXml = 0,
      @MitProcessDetails = 0,
      @MitResourceDetails = 0,
      @MaxZeilen = 50,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Jeder fachliche Lauf ist als `EXTENDED_EVENTS_FORENSICS_DEEP` geschützt. Die Bestätigung ist trotz engem Zeitfenster erforderlich; sie begrenzt weder die Zahl der Rolloverdateien noch garantiert sie einen frühen Dateifilter.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `deadlocks` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Summary-Zeile = Deadlock; Victim-Zeile = Opferprozess; Process-Zeile = Graphprozess; Resource-Zeile = beteiligte Lockressource.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Opfer, alle Prozesse, Ressourcen und Zugriffsreihenfolge gemeinsam lesen. Das Opfer ist nicht automatisch der Verursacher.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Deadlock ist zyklisches Warten; SQL Server muss mindestens eine Transaktion abbrechen. Wiederholung erzeugt Fehler, Rollbacks und Durchsatzverlust.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Ein einmaliges Ereignis nach seltenem Deployment kann geringere Priorität besitzen als ein minütlich wiederkehrendes Muster.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Zwei Sessions sperren Objekte in umgekehrter Reihenfolge: konsistente Zugriffsreihenfolge, Isolation, Indizes und Transaktionsumfang prüfen.

**Ähnlich aussehender Gegenfall:** Ein einmaliges Ereignis nach seltenem Deployment kann geringere Priorität besitzen als ein minütlich wiederkehrendes Muster. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Eine laufende Session kann ohne passendes Ereignis leer sein; außerdem können Target, Dateipfad, Rollover, Flushzustand und Berechtigung die Sicht einschränken.

Für `USP_ExtendedEventsDeadlocks` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Event-Datei- und XML-abhängig; Maximalzahl und UTC-Filter werden vor der XML-Zerlegung angewandt. Trotzdem können XEL-Dateien vollständig gelesen werden müssen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | AUTO liest bis zu 100 `xml_deadlock_report`-Events aus dem `system_health`-Eventfile. Default gibt Deadlock-XML aus und zerlegt zusätzlich Victims, alle Prozesse und Ressourcen – der Default ist bereits eine vollständige Graphanalyse. |
| Teuerster Pfad | Unbegrenzte XEL-Rollovermenge oder großer Ring Buffer ohne Zeitfenster mit vollständiger XML-, Prozess- und Ressourcenausgabe; Ring Buffer benötigt bestätigten Target-Flush. |
| Haupttreiber | Rolloverdateigröße beziehungsweise Ring-Buffer-Größe, Zahl der ausgewählten Deadlocks und Anzahl/Komplexität von Prozess- und Ressourcenknoten je Graph. |
| Skalierung | TOP/UTC wählen Graphen vor dem fachlichen Shredding. Danach wächst CPU annähernd mit allen Victim-, Prozess- und Ressourcenknoten; eingebettete Inputbuf-/Owner-/Waiter-XML erhöht Speicher und Transfer. |
| Ressourcen | Datei-I/O über das SQL-Server-Dienstkonto, CPU/Speicher für XML-Parsing, TempDB/Transfer für zerlegte Ereignisse. |
| Begrenzungswirkung | `@MaxZeilen` begrenzt Deadlockevents vor Graph-Shredding, aber nicht garantiert den physischen XEL-Wildcardscan. `@MitProcessDetails`/`@MitResourceDetails` sparen das jeweilige Shredding; `@MitDeadlockXml = 0` spart primär Ausgabe. |
| Locking und Nebenwirkungen | Keine XE-Konfigurationsänderung. Eventfilelesen konkurriert mit Storage-I/O; Ring-Buffer-Lesen kann erst nach `@BestaetigeTargetFlush = 1` Targetpuffer flushen. Kein `sp_server_diagnostics`-Pfad. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `EXTENDED_EVENTS_FORENSICS_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | `system_health`, enges UTC-Fenster, 50 Graphen und zunächst nur Summary/Victim; High-Impact bestätigen. Prozesse/Ressourcen für konkrete Deadlock-IDs nachfordern, Ring Buffer nur nach Flushentscheidung. |
| Aussagegrenze | Ein Graph zeigt genau den von SQL Server gewählten Zyklus/Opferzeitpunkt, nicht alle vorausgehenden Warteketten. Objekt-/Indexnamen können fehlen, IDs wiederverwendet werden, und Rollover/Top-N verhindert eine vollständige Häufigkeitsaussage. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Sessions/Prozesse bildeten einen Deadlockzyklus, welches Opfer wurde gewählt und welche Ressourcen/Kanten waren beteiligt?

### Technischer Hintergrund

Der Lock Monitor erkennt einen Zyklus, wählt anhand Deadlock Priority und Rollbackkosten ein Opfer und erzeugt einen Deadlockgraph. XML enthält Victim List, Process List und Resource List mit Owner-/Waiter-Kanten.

### Datenkette

`sys.dm_xe_session_targets`, `sys.dm_xe_sessions`, `sys.fn_xe_file_target_read_file`, `sys.server_event_session_fields`, `sys.server_event_session_targets`, `sys.server_event_sessions`.

### Source Select

Der zentrale Forensikpfad liest ausschließlich Deadlockevents aus der bereits ausgewählten XEL-Dateimenge:

```sql
SELECT
      [x].[timestamp_utc]
    , [x].[file_name]
    , [x].[file_offset]
    , TRY_CAST([x].[event_data] AS xml) AS [EventXml]
FROM [sys].[fn_xe_file_target_read_file]
     (@EventFilePattern, NULL, NULL, NULL) AS [x]
WHERE [x].[object_name] = N'xml_deadlock_report'
  AND [x].[timestamp_utc] >= @VonUtc
ORDER BY [x].[timestamp_utc] DESC;
```

**Wichtig für die Eigenlast:** Rollovermenge und Zeitfenster begrenzen, bevor Deadlock-XML zerlegt wird. `TOP` nach einer unbeschränkten Dateifunktion reduziert möglicherweise nur Sortierungsausgabe, nicht den gesamten Dateizugriff.

### Zeit- und Scope-Modell

Einzelne historische Deadlockereignisse soweit im Target erhalten.

### Bewertung und Gegenprobe

Zyklus vollständig lesen: Opfer ist nicht automatisch Verursacher. Zugriffsreihenfolge, Lockmodi, Isolation, Indexzugriff, Transaktionsscope und wiederkehrende Query-/Objektmuster bewerten.

### Typische Fehlinterpretation

Nur SQL-Text des Opfers zu optimieren kann den Zyklus unverändert lassen. Blocking ohne Zyklus erscheint nicht als Deadlock.

### Folgeanalyse

Showplan/Indexanalyse, Anwendungstransaktionsreihenfolge, wiederholte Graphen gruppieren.

## Primärquellen

- [Extended Events](https://learn.microsoft.com/en-us/sql/relational-databases/extended-events/extended-events?view=sql-server-ver17)

[Technische Detailbeschreibung](../06_Extended_Events.md#3-monitorusp_extendedeventsdeadlocks)
