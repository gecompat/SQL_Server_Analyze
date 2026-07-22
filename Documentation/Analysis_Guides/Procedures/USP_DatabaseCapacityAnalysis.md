# [monitor].[USP_DatabaseCapacityAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Bewertet Dateien, Volumes, freien Platz, Autogrowth, MaxSize und Wachstumsspielraum.<br>
**Beobachtungsart:** Snapshot ohne Wachstumsprognose<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Wie viel Datei-/Volumeplatz bleibt, wie sind Growth/MaxSize konfiguriert und welche Kapazitätsrisiken sind sichtbar?** Der dokumentierte Zweck ist: Bewertet Dateien, Volumes, freien Platz, Autogrowth, MaxSize und Wachstumsspielraum. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Ihr Zeitvertrag lautet ausdrücklich: Aktueller Snapshot. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DatabaseCapacityAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Für vollständige Volumenevidenz ist auf SQL Server 2019 `VIEW SERVER STATE`, ab SQL Server 2022 `VIEW SERVER PERFORMANCE STATE` erforderlich. Fehlt dieses Recht, bleibt zulässige Dateievidenz sichtbar, der Status lautet jedoch ausdrücklich `AVAILABLE_LIMITED` mit `IsPartial=1`.

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `capacity` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Datenbankdatei, einem Volume, einer Datenbankaggregation oder einem Finding.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Dateigröße, belegt/frei, Volume Free, Growthsetting, MaxSize und absoluten Wachstumsspielraum gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Wenig freier Raum plus kleine häufige Autogrowths kann Pausen erzeugen; MaxSize oder volles Volume kann Wachstum vollständig verhindern.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Niedriger Prozentwert bei sehr großem Volume kann absolut ausreichend sein; hoher Prozentwert auf kleinem Volume nicht.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 5 % von 20 TB = 1 TB; 20 % von 10 GB = 2 GB. Prozent und absolute Menge gemeinsam lesen. Wachstumstrend, Log-/Backupstatus und Storage prüfen.

**Ähnlich aussehender Gegenfall:** Niedriger Prozentwert bei sehr großem Volume kann absolut ausreichend sein; hoher Prozentwert auf kleinem Volume nicht. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_DatabaseCapacityAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine `ExampleDatabase`; pro Datei werden Kataloggröße, `FILEPROPERTY(...,'SpaceUsed')`, Volume-Freiraum und der nächste Autogrowth-Schritt als Snapshot bewertet. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, unbegrenzte Ausgabe und viele Daten-/Logdateien auf zahlreichen Volumes. Es gibt keinen History-, Growth- oder Benutzerdatenscan. |
| Haupttreiber | Zahl gewählter Datenbanken und ihrer Daten-/Logdateien; für jede Datei werden Kataloggröße, belegte Seiten und Volumeinformationen korreliert. Dateigröße verändert die Werte, nicht proportional die Metadatenarbeit. |
| Skalierung | Aufwand wächst ungefähr mit Datenbanken und Dateien. Volumeabfragen können je Datei wiederholt werden; Sortierung und Resultat bleiben im Verhältnis zur Dateimenge klein. |
| Ressourcen | Katalog-/Dateimetadaten-I/O, CPU für dynamische Datenbankabfragen und `sys.dm_os_volume_stats`; kleine temporäre Ergebnistabelle. Keine msdb- oder Memory-Clerk-Abfrage. |
| Begrenzungswirkung | Datenbankliste/-pattern begrenzen den Cursor früh. `@NurProblematisch` und `@MaxZeilen` wirken erst auf die vollständig erzeugten Dateibewertungen und begrenzen `FILEPROPERTY`-/Volumezugriffe nicht. |
| Locking und Nebenwirkungen | Read-only; kurze Metadatenzugriffe und nicht atomare Runtime-DMVs. Es wird weder CHECKDB noch Growth noch Konfigurationsänderung ausgeführt. |
| Schutzmechanismus | `SERVER_HEALTH_CURRENT` muss freigegeben sein, verlangt laut Klassenkatalog keine High-Impact-Bestätigung. Wirksamer Schutz ist eine einzelne Datenbank; `@HighImpactConfirmed` öffnet keinen weiteren Pfad. |
| Sicherer Einsatz | Eine `ExampleDatabase`, Problemscope und endliches Limit; erst nach Sichtung von Dateianzahl und Laufzeit weitere Datenbanken aufnehmen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot ohne Wachstumsprognose“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie viel Datei-/Volumeplatz bleibt, wie sind Growth/MaxSize konfiguriert und welche Kapazitätsrisiken sind sichtbar?

### Technischer Hintergrund

Database Files wachsen innerhalb Volume-/MaxSizegrenzen. Percent Growth erzeugt mit wachsender Datei zunehmend große Schritte; kleine Growthsteps erzeugen häufige Growth Events. Loggrowth/Zero Initialization und Datafile IFI unterscheiden sich.

### Datenkette

`sys.database_files`, `sys.dm_os_volume_stats`, `sys.sp_executesql`.

### Source Select

Im Kontext einer bereits ausgewählten Datenbank werden Dateikatalog und Volume-Information verbunden:

```sql
SELECT
      DB_NAME() AS [DatabaseName]
    , [f].[file_id]
    , [f].[name] AS [LogicalFileName]
    , [f].[type_desc]
    , [f].[size] * 8.0 / 1024.0 AS [SizeMb]
    , [v].[volume_mount_point]
    , [v].[available_bytes]
FROM [sys].[database_files] AS [f] WITH (NOLOCK)
OUTER APPLY [sys].[dm_os_volume_stats](DB_ID(), [f].[file_id]) AS [v]
WHERE [f].[state] = 0;
```

**Wichtig für die Eigenlast:** Zuerst die Datenbankkandidaten begrenzen. `dm_os_volume_stats` nur für deren Dateien aufrufen; `@MaxZeilen` reduziert sonst gegebenenfalls nur die spätere Ausgabe, nicht die Zahl der Volume-Auflösungen.

### Zeit- und Scope-Modell

Aktueller Snapshot. Ohne historische Messpunkte keine Wachstumsrate/Forecast.

### Bewertung und Gegenprobe

Absolute freie MB und Prozent, Filegröße, Growthtyp/-schritt, MaxSize, Volume Free, Dateityp und geplante Workloadspitzen kombinieren. Autogrowth als Sicherheitsnetz, proaktives Sizing als Betrieb.

### Typische Fehlinterpretation

Viel freier Platz im File bedeutet nicht freien Volumeplatz; viel Volumeplatz bedeutet nicht passende MaxSize/Growth. Forecast aus einem Snapshot ist Heuristik.

### Folgeanalyse

Current Log/IO, Backup-/Loadplanung und externes Capacitytrendmonitoring.

## Primärquellen

- [sys.dm_os_volume_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-volume-stats-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#12-monitorusp_databasecapacityanalysis)
