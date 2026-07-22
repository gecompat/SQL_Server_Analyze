# [monitor].[USP_ServerConfiguration]

**Bereich:** Server Health<br>
**Zweck:** Zeigt konfigurierte und aktive Serveroptionen mit Bewertungscontext.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche Serveroptionen weichen von Default/Empfehlung ab und welche Werte sind tatsächlich aktiv?** Der dokumentierte Zweck ist: Zeigt konfigurierte und aktive Serveroptionen mit Bewertungscontext. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Konfigurationsstand; einige `value`-Änderungen noch nicht in use. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerConfiguration]
      @NurKernparameter = 1,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `configuration` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Serverkonfigurationsoption.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Configured Value, Run Value, Dynamic/Advanced-Status, Default und Beschreibung vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Abweichende Run Values können ausstehendes Reconfigure/Restart anzeigen; extreme Werte können Ressourcen falsch begrenzen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Abweichung vom Default ist kein Fehler. Produktive Systeme benötigen oft bewusste Anpassungen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Niedriges max server memory kann absichtlich Speicher für andere Dienste reservieren. Erst OS-, Workload- und Memorykontext prüfen.

**Ähnlich aussehender Gegenfall:** Abweichung vom Default ist kein Fehler. Produktive Systeme benötigen oft bewusste Anpassungen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_ServerConfiguration` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | `@NurKernparameter = 1` liest eine feste Liste betriebsrelevanter Optionen und eine Schedulerzahl für Kontext/Findinglogik. Konfigurierter und aktiver Wert werden gemeinsam ausgegeben. |
| Teuerster Pfad | `@NurKernparameter = 0` liest alle Zeilen aus `sys.configurations`; auch das bleibt ein kleiner Serverkatalog ohne Child- oder Historienpfad. |
| Haupttreiber | Anzahl der Serverkonfigurationsoptionen. Die Procedure liest keine `sp_configure`-Änderungshistorie und keine Database-Scoped Configurations. |
| Skalierung | Linear mit wenigen hundert Konfigurationszeilen; CASE-Bewertung und Sortierung sind gering. Resultgröße ist unabhängig von Datenbank-/Workloadgröße. |
| Ressourcen | Eine SQLOS-Infozeile, ein Serverkatalogscan und eine kleine Temp-Tabelle. Kein `RECONFIGURE`, XML, Sampling oder Cross-Database-SQL. |
| Begrenzungswirkung | Der Kernparameter-Schalter reduziert Quelle und Ausgabe fachlich; ein Max-Rows-Parameter existiert nicht. `NONE` unterdrückt nur Resultsets, nicht die Erhebung. |
| Locking und Nebenwirkungen | Read-only. Werte können zwischen `dm_os_sys_info` und `sys.configurations` geändert werden; die Procedure selbst setzt keine Option und führt kein `RECONFIGURE` aus. |
| Schutzmechanismus | Kein Gate. `@NurKernparameter = 1` ist der einzige fachliche Scope und hält Quelle wie Ausgabe bei der fest definierten Kernliste; auch der Vollpfad bleibt ein read-only Scan von `sys.configurations` ohne Konfigurationsänderung. |
| Sicherer Einsatz | Mit `@NurKernparameter = 1` starten; erst für ein Konfigurationsaudit auf alle Optionen erweitern. Ausgabe enthält keine Kennwörter oder Dateipfade. |
| Aussagegrenze | Ein Finding markiert Reviewbedarf, nicht automatisch Fehlkonfiguration. Edition, Workload, NUMA, verfügbare RAM-/CPU-Ressourcen und Änderungsfenster müssen separat berücksichtigt werden. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Serveroptionen weichen von Default/Empfehlung ab und welche Werte sind tatsächlich aktiv?

### Technischer Hintergrund

`sys.configurations` besitzt configured `value` und `value_in_use`, Dynamic/Advanced Flags. Manche Änderungen greifen sofort, andere nach RECONFIGURE oder Restart. Optionen beeinflussen Parallelität, Memory, Security, Remotezugriff und Engineverhalten.

### Datenkette

`sys.configurations`, `sys.dm_os_sys_info`.

### Source Select

Der Konfigurationskern liest dokumentierten und aktiven Wert direkt aus `sys.configurations`:

```sql
SELECT
      [c].[configuration_id]
    , [c].[name]
    , [c].[value]
    , [c].[value_in_use]
    , [c].[is_dynamic]
    , [c].[is_advanced]
FROM [sys].[configurations] AS [c] WITH (NOLOCK)
WHERE [c].[name] IN
      (N'max server memory (MB)',
       N'max degree of parallelism',
       N'cost threshold for parallelism');
```

**Wichtig für die Eigenlast:** Die Quelle ist klein. Konfigurationsnamen bereits im Quellselect begrenzen; die Procedure liest nur und führt weder `sp_configure` noch `RECONFIGURE` aus.

### Zeit- und Scope-Modell

Aktueller Konfigurationsstand; einige `value`-Änderungen noch nicht in use.

### Bewertung und Gegenprobe

Configured/In Use, Is Dynamic, Is Advanced, Version/Edition, Workload und Changegrund gemeinsam lesen. Abweichungen priorisieren, aber nicht automatisch korrigieren.

### Typische Fehlinterpretation

Default ist nicht immer optimal; bekannte Empfehlung ist nicht universell. Mehrere Optionen interagieren, etwa MAXDOP/Cost Threshold oder Max Memory/OS Reserve.

### Folgeanalyse

Spezifische Topologie-/Memory-/Securitymodule und kontrolliertes Changeverfahren.

## Primärquellen

- [sys.configurations](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-configurations-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#5-monitorusp_serverconfiguration)
