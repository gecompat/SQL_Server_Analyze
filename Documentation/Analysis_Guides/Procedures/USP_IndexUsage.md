# [monitor].[USP_IndexUsage]

**Bereich:** Object und Index<br>
**Zweck:** Zeigt kumulative Read-/Write-Nutzung klassischer und optional In-Memory-Indizes.<br>
**Beobachtungsart:** kumulativ seit Struktur-/Instanzreset<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche sichtbaren Reads und Writes wurden einem Index seit dem DMV-Reset zugerechnet?** Der dokumentierte Zweck ist: Zeigt kumulative Read-/Write-Nutzung klassischer und optional In-Memory-Indizes. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Kumulativ seit Engine-/Datenbank-/DMV-Lebenszyklus. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IndexUsage]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `rowstoreIndexes` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Index im sichtbaren DMV-Scope; XTP-Indizes erscheinen in einem separaten Resultset mit eigener Zählersemantik.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Resetzeit, Reads, Updates, letzte Nutzung und Schutzmerkmale wie PK, Unique oder Constraint gemeinsam lesen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Viele Updates ohne Reads bedeuten mögliche Schreib-, Log-, Lock- und Speicherlast ohne sichtbaren Lesebedarf.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

Kurzes Beobachtungsfenster, saisonale Reports oder Constraintfunktionen machen `0 Reads` unzureichend für eine Löschungsentscheidung.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 0 Reads, 8 Mio. Updates, 180 Tage Beobachtung: starker Reviewkandidat. 0 Reads, 40 Updates, zwei Stunden seit Restart: praktisch keine belastbare Aussage.

**Bisher dokumentierter Folgeschritt:** Query Store, Abhängigkeiten, Constraints und `USP_IndexOperationalStats` prüfen. Niemals allein aus dieser DMV einen Index löschen.

**Ähnlich aussehender Gegenfall:** Kurzes Beobachtungsfenster, saisonale Reports oder Constraintfunktionen machen `0 Reads` unzureichend für eine Löschungsentscheidung. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_IndexUsage` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** Moderate DMV-/Katalogabfrage; keine Physical-Stats-Scans.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine explizit benannte `ExampleDatabase` und ein Objekt im Modus `GEZIELT`; klassische und optional In-Memory-Indexzähler werden korreliert. |
| Teuerster Pfad | Cross-Database-`VOLL`, unbegrenzte Ausgabe, Memory-Optimized-Pfad und alle sichtbaren Indizes auf einer indexreichen Instanz. Es werden weiterhin keine Physical Stats gelesen. |
| Haupttreiber | Zahl gewählter Datenbanken/Objekte und ihrer klassischen Indizes sowie optional XTP-Indizes. Katalog-/Usage-Stats-Korrelation erfolgt je Datenbank; ein späteres Rankinglimit spart diese Vorarbeit nicht vollständig. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_IndexUsage ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU, Katalogseiten und TempDB für Joins/Aggregation; bei breitem Cross-Database-Scope zusätzlicher Compile- und Ergebnistransferaufwand. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen die Quellarbeit. TOP oder MaxZeilen werden häufig nach Katalogjoins und Aggregation angewandt und sind dann nur Ausgabelimits. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | Der gezielte `OBJECT_ANALYSIS_CURRENT`-Pfad braucht keine High-Impact-Bestätigung. `VOLL` prüft zusätzlich `CATALOG_DEEP` und erfordert `@HighImpactConfirmed = 1`. |
| Sicherer Einsatz | Mit einer ExampleDb und einem ExampleObject starten; erst nach Größenprüfung auf mehrere Datenbanken oder VOLL erweitern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „kumulativ seit Struktur-/Instanzreset“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche sichtbaren Reads und Writes wurden einem Index seit dem DMV-Reset zugerechnet?

### Technischer Hintergrund

`sys.dm_db_index_usage_stats` zählt user/system seeks, scans, lookups und updates sowie letzte Zeitpunkte. Ein einzelnes DML-Statement kann mehrere Indexupdates verursachen. Der Zähler erfasst nicht jede semantische Abhängigkeit, etwa Constraintwirkung oder seltene saisonale Reports.

### Datenkette

`sys.dm_db_index_usage_stats`, `sys.dm_db_xtp_index_stats`, `sys.dm_os_sys_info`, `sys.hash_indexes`, `sys.indexes`, `sys.objects`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Zeit- und Scope-Modell

Kumulativ seit Engine-/Datenbank-/DMV-Lebenszyklus. Restart, Detach/Attach, Offline/Online und andere Ereignisse können den Beobachtungszeitraum verkürzen.

### Bewertung und Gegenprobe

Reads, Updates, letzte Nutzung, Uptime/Resetzeit, Indexgröße und Schutzstatus kombinieren. Viele Updates ohne Reads über ein ausreichend langes repräsentatives Fenster sind ein Reviewkandidat, kein Dropbefehl.

### Typische Fehlinterpretation

`0 Reads` bedeutet nur keine in dieser DMV sichtbare Nutzung im Fenster. Planforcing, Query Store, Wartung, FK/Unique/PK und Monats-/Jahresworkloads gegenprüfen.

### Folgeanalyse

`USP_IndexOperationalStats`, Query Store, Dependency-/Constraintreview.

## Primärquellen

- [sys.dm_db_index_usage_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-usage-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#2-monitorusp_indexusage)
