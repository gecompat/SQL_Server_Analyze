# [monitor].[USP_TempDBConfiguration]

**Bereich:** Server Health<br>
**Zweck:** Bewertet TempDB-Dateien, Größen, Wachstum, Gleichheit und Konfigurationsrisiken.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Ist TempDB hinsichtlich Dateianzahl, Größe, Growth, Layout und Optionen robust konfiguriert?** Der dokumentierte Zweck ist: Bewertet TempDB-Dateien, Größen, Wachstum, Gleichheit und Konfigurationsrisiken. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Katalog-/Dateistand; TempDB-Inhalt seit Engine-Start. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_TempDBConfiguration]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `files` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer TempDB-Datei, Konfigurationseigenschaft oder einem Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Dateianzahl, Größen-/Growth-Gleichheit, Autogrowth-Einheit, freien Platz, Version Store und Contentionkontext gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Ungleich große Datenfiles werden proportional unterschiedlich genutzt; kleine Growthschritte erzeugen viele Wachstumsereignisse.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Nicht jede Instanz benötigt acht Dateien. CPU, Contention und Workload entscheiden.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Vier gleich große Dateien ohne Contention können besser sein als acht ungleich große. Current TempDB, Filegrowth-Historie und Contention prüfen.

**Ähnlich aussehender Gegenfall:** Nicht jede Instanz benötigt acht Dateien. CPU, Contention und Workload entscheiden. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_TempDBConfiguration` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Liest alle aktuellen TempDB-Dateizeilen sowie genau drei bekannte TempDB-Konfigurationsnamen. CONSOLE/TABLE exportieren die Dateisicht; RAW/JSON enthalten zusätzlich die Konfigurationssicht. |
| Teuerster Pfad | Gegenüber dem Standard existiert kein tiefer Modus. Viele TempDB-Dateien und gleichzeitige JSON-/RAW-Ausgabe verbreitern nur die kleine Katalogmenge; Dateiinhalte und Allokationsseiten werden nicht gelesen. |
| Haupttreiber | Anzahl der Zeilen in `tempdb.sys.database_files`; die `sys.configurations`-Quelle ist auf drei Namen begrenzt. Dateigröße beeinflusst die Abfragekosten nicht. |
| Skalierung | Linear mit der Zahl der TempDB-Dateien. Umrechnung von Pages in MB, Growthtyp und Sortierung nach `file_id` sind konstante beziehungsweise sehr kleine CPU-Arbeit. |
| Ressourcen | Zwei kurze Katalogabfragen und kleine Temp-Tabellen. Kein Zugriff auf `sys.dm_db_file_space_usage`, Dateiinhalte, PFS/GAM/SGAM oder Nutzerobjekte. |
| Begrenzungswirkung | Es gibt bewusst kein `@MaxZeilen`: die vollständige Dateiliste ist Teil der Konfigurationsbewertung. `@ResultSetArt = 'NONE'` spart nur Ausgabe, nicht die beiden Quellabfragen. |
| Locking und Nebenwirkungen | Read-only; kurze Metadatenzugriffe auf TempDB und Serverkonfiguration. Gleichzeitiges Datei-ADD/GROWTH kann dazu führen, dass Dateiliste und Konfigurationssicht verschiedene Momente abbilden. |
| Schutzmechanismus | Kein Gate und kein Scopeparameter. Die feste Begrenzung ist die reale TempDB-Dateizahl plus genau drei abgefragte Konfigurationsnamen; Benutzerdaten, Allokationsseiten und Dateiinhalte liegen außerhalb des implementierten Pfads. |
| Sicherer Einsatz | CONSOLE ist kostengünstig; physische Dateipfade aus RAW/JSON/TABLE nur im geschützten Betriebskontext speichern oder weitergeben. |
| Aussagegrenze | Die Procedure bewertet Konfiguration, nicht aktuelle TempDB-Auslastung, Latchkonkurrenz oder Dateilatenz. Gleiche Dateigröße beweist weder gleichmäßiges Autogrowth noch proportionale Nutzung. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist TempDB hinsichtlich Dateianzahl, Größe, Growth, Layout und Optionen robust konfiguriert?

### Technischer Hintergrund

TempDB wird bei jedem Start neu erstellt. Datafiles bilden Allocationkonkurrenz ab; gleich große Dateien begünstigen Proportional Fill. Autogrowth ist Notfallkapazität, kein laufendes Sizingmodell. Version Store, Internal/User Objects verursachen Runtimebelegung.

### Datenkette

`sys.configurations`, `tempdb.sys.database_files`.

### Zeit- und Scope-Modell

Aktueller Katalog-/Dateistand; TempDB-Inhalt seit Engine-Start.

### Bewertung und Gegenprobe

Datafile Count relativ zu Workload/CPU, gleiche Initialgröße/Growth, absolute Growthgröße, Volumeplatz, Logfile und versionsabhängige Optionen prüfen. Änderungen anhand gemessener Contention statt pauschaler Maximalzahl.

### Typische Fehlinterpretation

Mehr Dateien lösen nicht jeden PAGELATCH-Wait; zu viele Dateien erhöhen Verwaltung/Recovery/Storage. Gleichheit beweist keine ausreichende Kapazität.

### Folgeanalyse

`USP_CurrentTempDB`, Internal Contention, Current IO.

## Primärquellen

- [tempdb database](https://learn.microsoft.com/en-us/sql/relational-databases/databases/tempdb-database?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#4-monitorusp_tempdbconfiguration)
