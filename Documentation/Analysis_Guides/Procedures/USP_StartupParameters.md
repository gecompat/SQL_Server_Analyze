# [monitor].[USP_StartupParameters]

**Bereich:** Server Health<br>
**Zweck:** Zeigt SQL-Server-Startparameter, Pfade und dauerhaft aktivierte Flags.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Mit welchen Service-/Engineparametern wurde die Instanz gestartet?** Der dokumentierte Zweck ist: Zeigt SQL-Server-Startparameter, Pfade und dauerhaft aktivierte Flags. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Konfiguration der laufenden Instanz; Wirkung seit letztem Start. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_StartupParameters]
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `startupParameters` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Startparameter oder einer daraus abgeleiteten Konfigurationsinformation.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Parameterart, Pfade, Trace Flags, Startoptionen und Dienstkontext prüfen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Falsche Master-/Errorlog-/Startpfade oder unerwartete Flags können Start und Engineverhalten beeinflussen.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Abweichende Pfade sind häufig bewusstes Storage-Design.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Ein Trace Flag als Startup-Parameter erklärt, warum es nach jedem Restart wieder aktiv ist. Trace-Flag-Dokumentation, Dateisystem und Dienstkonfiguration prüfen.

**Ähnlich aussehender Gegenfall:** Abweichende Pfade sind häufig bewusstes Storage-Design. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_StartupParameters` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW |
| Standardpfad | Erkennt zunächst Plattform/Verfügbarkeit und liest dann aus `sys.dm_server_registry` nur `SQLArg%`, `ImagePath` und `ObjectName`; Werte werden als Trace Flag, Master-Daten-/Logpfad, Errorlogpfad oder Other klassifiziert. |
| Teuerster Pfad | Kein Deep-Pfad. Auch eine Instanz mit vielen Startargumenten liefert nur wenige Registry-DMV-Zeilen; RAW/JSON verbreitern lediglich die Ausgabe. |
| Haupttreiber | Anzahl der SQL-Startargument-/Dienstparameterzeilen. Auf Linux oder ohne DMV wird kontrolliert `UNAVAILABLE_PLATFORM`/`UNAVAILABLE_OBJECT` geliefert, kein alternativer Datei-/Shellzugriff gestartet. |
| Skalierung | Praktisch konstant; LIKE-Klassifikation und Sortierung wachsen linear mit wenigen Registrywerten. |
| Ressourcen | Ein Hostplattform-Lookup, ein kleiner Metadaten-Existenzcheck und optional ein gefilterter `sys.dm_server_registry`-Scan. Kein direkter Registryzugriff außerhalb SQL Server. |
| Begrenzungswirkung | Kein Zeilenlimit; vollständige Startargumente sind fachlich erforderlich. `NONE` unterdrückt Ausgabe, führt Plattform-/DMV-Prüfung und Quellabfrage dennoch aus. |
| Locking und Nebenwirkungen | Read-only. Startparameter werden weder geschrieben noch aktiviert; Änderungen außerhalb SQL Server können nach dem Snapshot erfolgen und wirken teils erst nach Dienstneustart. |
| Schutzmechanismus | Kein Gate und kein Zeilenparameter. Die Implementierung beschränkt `sys.dm_server_registry` fest auf `SQLArg%`, `ImagePath` und `ObjectName`, prüft zuvor die Plattform/Quellverfügbarkeit und führt keinen allgemeinen Registryscan aus. |
| Sicherer Einsatz | CONSOLE direkt nutzen, aber Pfade, Dienstkonto und ImagePath als sensible Betriebsmetadaten schützen. Trace-Flag-Wirkung separat versionsspezifisch prüfen. |
| Aussagegrenze | Die Procedure zeigt DMV-sichtbare Startwerte, nicht deren Änderungsverlauf oder tatsächliche Dateiexistenz. Ein `-T`-Argument beweist Konfiguration beim Start, aber nicht automatisch aktuelle Notwendigkeit oder Supportstatus. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Mit welchen Service-/Engineparametern wurde die Instanz gestartet?

### Technischer Hintergrund

Startupparameter definieren unter anderem Master Data/Log, Errorlog, Trace Flags und weitere Engineoptionen. Registry-/Service-DMVs liefern konfigurierte Parameter; einige Änderungen benötigen Dienstneustart und können Startfähigkeit beeinflussen.

### Datenkette

`sys.dm_os_host_info`, `sys.dm_server_registry`.

### Zeit- und Scope-Modell

Konfiguration der laufenden Instanz; Wirkung seit letztem Start.

### Bewertung und Gegenprobe

Parameter, Quelle, Reihenfolge, Pfad-/Flagbedeutung und Abgleich mit Runtime Trace Flags/Errorlog prüfen. Abweichung von Standard kann bewusst sein.

### Typische Fehlinterpretation

Ein angezeigter Parameter beweist nicht, dass sein Zielpfad gesund oder noch erforderlich ist. Änderungen ohne Recoveryzugang können Instanzstart verhindern.

### Folgeanalyse

Trace Flags, OS/Filesystem und dokumentiertes Restart-/Rollbackrunbook.

## Primärquellen

- [sys.dm_server_registry](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-server-registry-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#7-monitorusp_startupparameters)
