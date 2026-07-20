# [monitor].[USP_CurrentIO]

**Bereich:** Current State<br>
**Zweck:** Bewertet Datei-I/O kumulativ oder als kurzes Delta-Sample.<br>
**Beobachtungsart:** kumulative Datei-/Counterwerte + optionale Stichprobe<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie viele I/O-Operationen und Bytes wurden pro Datei verarbeitet, und wie lange dauerten sie?** Der dokumentierte Zweck ist: Bewertet Datei-I/O kumulativ oder als kurzes Delta-Sample. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob das aktuelle Symptom im Erfassungsmoment sichtbar ist und welcher engere Live-, Verlaufs- oder Planpfad als Nächstes sinnvoll ist. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine lückenlose Historie und allein aus einem Snapshot weder Dauerhäufigkeit noch Root Cause oder zukünftige Entwicklung. Ihr Zeitvertrag lautet ausdrücklich: Kumulativ seit Start/Dateizustand oder Sampledelta. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentIO]
      @DatabaseNames = N'[ExampleDatabase]',
      @SampleSeconds = 5,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

Ohne `@DatabaseNames` oder `@DatabaseNamePattern` werden alle sichtbaren,
online befindlichen Benutzerdatenbanken ausgewertet. Systemdatenbanken bleiben
mit `@SystemdatenbankenEinbeziehen = 0` ausgeschlossen. Das Modul ist
leichtgewichtig und verlangt keine High-Impact-Bestätigung.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `moduleStatus`, `files`, `warnings` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Datenbankdatei im gewählten Scope. Im Samplemodus beschreiben Raten und Latenzen die Differenz zwischen zwei Messpunkten.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Kumulative Durchschnittswerte und Sample-Delta trennen. Operationen, Bytes und Latenz für Reads und Writes je Datei vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Hohe aktuelle Latenz bei vielen I/O-Operationen kann Requests direkt bremsen. Ein alter kumulativer Durchschnitt kann hingegen durch ein historisches Ereignis verzerrt sein.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Eine einzige seltene langsame Operation kann einen extremen Durchschnitt erzeugen, ohne aktuelle Relevanz.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 500 ms Durchschnitt bei einer Operation seit Start: schwach. 25 ms im 10-Sekunden-Sample bei zehntausenden Reads plus `PAGEIOLATCH`: starke I/O-Spur. Betroffene Queries und externes Storage-Monitoring korrelieren.

**Ähnlich aussehender Gegenfall:** Eine einzige seltene langsame Operation kann einen extremen Durchschnitt erzeugen, ohne aktuelle Relevanz. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Live-DMVs kann der Zustand bereits beendet sein, bevor die Quelle gelesen wird. Eine leere Menge ist deshalb höchstens 'jetzt nicht sichtbar', nicht 'trat nicht auf'.

Für `USP_CurrentIO` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Mit Default `@SampleSeconds = 0` wird `sys.dm_io_virtual_file_stats(NULL,NULL)` einmal gelesen; Vorher/Nachher sind identisch und die Ausgabe zeigt kumulative Werte seit Engine-/Dateistart, keine aktuelle Rate. |
| Teuerster Pfad | `@SampleSeconds = 60`, alle sichtbaren Datenbanken und unbegrenzte Ausgabe: die instanzweite DMV-Funktion wird zweimal aufgerufen, dazwischen bleibt die Session im WAITFOR. Viele parallele Sampler vervielfachen diese Arbeit. |
| Haupttreiber | Anzahl der Dateien auf der Instanz und ein oder zwei Aufrufe von `sys.dm_io_virtual_file_stats(NULL,NULL)`. Kandidatendatenbanken bestimmen die behaltenen Zeilen; `master.sys.master_files` ergänzt Namen/Pfade erst für die Rangliste. |
| Skalierung | Snapshotkosten wachsen annähernd mit der Dateizahl. Das Delta benötigt zwei vollständige Messpunkte; Sortierung nach Latenz erfolgt danach. Transferkosten hängen vom Limit ab, die DMV-Aufrufe selbst nicht im selben Maß. |
| Ressourcen | SQLOS-DMV-CPU, kleine Temp-Tabellen, Join auf `master.sys.master_files` und bei Sampling eine wartende Verbindung. Kein Dateiinhalt wird gelesen und keine Nutzdatenbanktabelle gescannt. |
| Begrenzungswirkung | Datenbankscope filtert die behaltenen DMV-Zeilen, ändert aber nicht die Funktionssignatur `dm_io_virtual_file_stats(NULL,NULL)`. `@MaxZeilen` greift erst beim sortierten Kandidatenset als N+1-Limit; es reduziert weder den ersten noch den zweiten Messpunkt. |
| Locking und Nebenwirkungen | Read-only; WAITFOR hält die Session, aber die Procedure hält keine Nutzdatenlocks absichtlich über das Intervall. Ein SQL-Server-Restart oder Counterreset zwischen den Messpunkten macht das Delta ungültig und wird als Statuskontext behandelt. |
| Schutzmechanismus | Die Kandidatenliste verwendet `STANDARD_CURRENT` und verlangt im aktuellen Code kein Gruppengate. `@HighImpactConfirmed` ist zwar deklariert, wird von diesem Implementierungsstand aber in keinem Analysepfad ausgewertet; Schutz liefern Scope, maximal 60 Sekunden und Zeilenlimit. |
| Sicherer Einsatz | Eine `ExampleDatabase`, fünf Sekunden, `@MaxZeilen = 100` und nur ein Sampler. Für Baselinefragen mehrere getrennte Intervalle statt vieler paralleler Aufrufe erfassen. |
| Aussagegrenze | Kumulative Latenz ist ein Lebenszeitmittel und kann aktuelle Probleme verdünnen; ein kurzes Delta kann einzelne Bursts überbetonen. Nicht ausgewählte Datenbanken fehlen, und Top-N nach Latenz kann stark ausgelastete, aber schnellere Dateien verdrängen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie viele I/O-Operationen und Bytes wurden pro Datei verarbeitet, und wie lange dauerten sie?

### Technischer Hintergrund

`sys.dm_io_virtual_file_stats` liefert kumulative Read-/Writeanzahl, Bytes und Stalls pro Daten-/Logdatei. Aus Differenzen zweier Messungen entstehen aktuelle IOPS, Durchsatz und Latenz. Die Procedure liest die DMV serverweit mit `(NULL, NULL)` genau einmal je Messzeitpunkt und schränkt die materialisierte Menge danach relational auf die Datenbankkandidaten ein. Dateimetadaten lösen Database/File/Type auf.

### Ausgabe

CONSOLE liefert ohne separates technisches Meta-Grid genau die lesbare
Dateiansicht. Bei leerem Ergebnis erscheint eine einzelne verständliche Zeile.
TABLE verwendet `@ResultTablesJson` mit den stabilen Namen `moduleStatus`,
`files` und `warnings`; alle Ziele stammen aus derselben Messung.

### Datenkette

`master.sys.master_files`, `sys.dm_io_virtual_file_stats`.

### Zeit- und Scope-Modell

Kumulativ seit Start/Dateizustand oder Sampledelta. Reset, Restart, Dateiwechsel und sehr kleine Nenner begrenzen Vergleichbarkeit.

### Bewertung und Gegenprobe

Reads und Writes getrennt bewerten; Latenz immer mit Operationszahl, Bytes und Sampledauer lesen. Datenfiles und Logfiles besitzen unterschiedliche I/O-Muster. Parallel sichtbare PAGEIOLATCH/WRITELOG- und Requestwerte erhöhen die Evidenz.

### Typische Fehlinterpretation

Eine einzelne Operation mit 500 ms erzeugt 500 ms Durchschnitt, aber keine anhaltende Last. DMV-Stall enthält Queueing aus SQL-Sicht, nicht automatisch reine Geräte-Servicezeit.

### Folgeanalyse

`USP_CurrentRequests`, `USP_CurrentWaits`, `USP_CurrentLog`; externe OS-/Storage-Telemetrie.

## Primärquellen

- [sys.dm_io_virtual_file_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-io-virtual-file-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [sp_WhoIsActive – ergänzende Live-Diagnostik und andere Aufbereitung aktueller Aktivität](https://github.com/amachanic/sp_whoisactive)

[Technische Detailbeschreibung](../02_Current_State.md#8-monitorusp_currentio)
