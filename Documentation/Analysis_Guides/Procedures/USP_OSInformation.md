# [monitor].[USP_OSInformation]

**Bereich:** Server Health<br>
**Zweck:** Zeigt Betriebssystem, Virtualisierung, Speicher, Zeit, Uptime und Plattformgrenzen.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Betriebssystem-, Host-, Virtualisierungs- und Ressourceninformationen sieht SQL Server?** Der dokumentierte Zweck ist: Zeigt Betriebssystem, Virtualisierung, Speicher, Zeit, Uptime und Plattformgrenzen. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Gast-/Instanzkontext; OS-/Engine-Startzeiten können verschieden sein. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_OSInformation]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `host` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine OS-/Plattformeigenschaft oder eine Zusammenfassung.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

OS-Version, Virtualisierung, Speicher, Zeit, Uptime und Plattform gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Sehr geringe Uptime erklärt resetete DMVs; Zeitabweichungen erschweren Ereigniskorrelation; Memory-/VM-Grenzen beeinflussen SQL.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Virtualisierung ist nicht automatisch langsam.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Index Usage zeigt 0 Reads, OS Uptime zwei Stunden: Beobachtungsfenster zu kurz für eine Löschung. CPU, Memory, I/O und Hypervisor-Monitoring korrelieren.

**Ähnlich aussehender Gegenfall:** Virtualisierung ist nicht automatisch langsam. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_OSInformation` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Liest vier unabhängige Quellen: Host, OS-Speicher, SQL-Prozessspeicher und Dienststatus. Jede Quelle hat eigenen Status, sodass fehlende Serviceberechtigung die Memorysicht nicht verdeckt. |
| Teuerster Pfad | Kein Deep-Pfad. RAW/JSON geben alle vier kleinen Resultsets plus SourceStatus aus; die Zahl SQL-bezogener Dienste ist gewöhnlich einstellig. |
| Haupttreiber | Feste Ein-Zeilen-DMVs und Zahl der SQL-Dienste in `sys.dm_server_services`. Datenbanken, Sessions und OS-Prozesse außerhalb SQL Server werden nicht enumeriert. |
| Skalierung | Praktisch konstant pro Instanz. Serialisierung wächst gering mit Dienstzeilen; Memorygröße beeinflusst nur Werte, nicht Abfragearbeit. |
| Ressourcen | Vier kurze SQLOS-/Service-DMV-Lesezugriffe und kleine Temp-Tabellen. Kein WMI, Registryscan, Dateisystem-I/O oder WAITFOR. |
| Begrenzungswirkung | Kein Scope-/Zeilenlimit nötig. `NONE` unterdrückt Resultsets, die vier Quellen werden für Status/JSON-Vertrag weiterhin versucht. |
| Locking und Nebenwirkungen | Read-only ohne Nutzdatenlocks. Speicherzustand und Dienststatus sind getrennte Momentaufnahmen; partieller SourceStatus ist erwartbarer als ein Abbruch des Gesamtmoduls. |
| Schutzmechanismus | Kein Gate und kein Scopeparameter. Die Procedure ist durch vier fest gewählte SQL-seitige Quellen mit eigener Statusbehandlung begrenzt; sie startet weder WMI-/Shellaufrufe noch eine Enumeration fremder Prozesse oder Dateisysteme. |
| Sicherer Einsatz | CONSOLE direkt nutzen; Dienstkonto, Prozess-ID und Hostdetails aus RAW/JSON nur im geschützten Betriebskontext teilen. SourceStatus je Teilquelle mit speichern. |
| Aussagegrenze | Die Procedure zeigt SQL-seitig sichtbare OS-/Prozesswerte, keine vollständige Hosttelemetrie, VM-Steal-Time oder Containerlimits. Ein momentaner Low-Memory-Flag benötigt Verlauf und OS-Gegenprobe. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Betriebssystem-, Host-, Virtualisierungs- und Ressourceninformationen sieht SQL Server?

### Technischer Hintergrund

Host-/Windows-/Linux-DMVs liefern OS-Version, Hostplattform, Memory/Pagefile, Startzeit und Virtualization/Containerhinweise soweit verfügbar. SQL Server sieht im Gast nicht zwingend Hypervisor-Steal, SAN- oder Hostcontention vollständig.

### Datenkette

`sys.dm_os_host_info`, `sys.dm_os_process_memory`, `sys.dm_os_sys_memory`, `sys.dm_server_services`.

### Zeit- und Scope-Modell

Aktueller Gast-/Instanzkontext; OS-/Engine-Startzeiten können verschieden sein.

### Bewertung und Gegenprobe

OS/Build Support, VM/Physical, Memory/Commit, Pagefile, Uptime und Instanzbuild korrelieren. Für Performance CPU-, Storage- und Memorytelemetrie außerhalb SQL ergänzen.

### Typische Fehlinterpretation

Unauffällige Gastwerte schließen Hostengpass nicht aus. Pagefile vorhanden/benutzt ist allein keine SQL-Memorydiagnose.

### Folgeanalyse

Server CPU/Memory/IO und OS-/Hypervisormonitoring.

## Primärquellen

- [sys.dm_os_host_info](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-host-info-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#8-monitorusp_osinformation)
