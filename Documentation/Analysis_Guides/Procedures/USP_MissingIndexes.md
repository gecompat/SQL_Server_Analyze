# [monitor].[USP_MissingIndexes]

**Bereich:** Object und Index<br>
**Zweck:** Priorisiert flüchtige Missing-Index-Evidenz und erzeugt einen ausdrücklich unverbindlichen DDL-Entwurf.<br>
**Beobachtungsart:** kumulativ seit Struktur-/Instanzreset<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Diese Procedure ist passend, wenn die konkrete Betriebsfrage lautet: **Welche zusätzlichen Nonclustered-Indexstrukturen hat der Optimizer während Kompilierungen als potenziell kostensenkend eingeschätzt?** Der dokumentierte Zweck ist: Priorisiert flüchtige Missing-Index-Evidenz und erzeugt einen ausdrücklich unverbindlichen DDL-Entwurf. Der Aufruf soll die Arbeitsentscheidung vorbereiten, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll. Status und Scope sind dabei Teil der Evidenz, nicht bloß technische Begleitinformation.

Die Auswertung ist eine Triage- und Eingrenzungshilfe. Zuerst wird festgestellt, ob die benötigte Quelle vollständig und im erwarteten Scope verfügbar war. Danach werden zusammengehörige Metriken gelesen und gegen eine zweite, möglichst anders erhobene Quelle geprüft. Erst diese Kette kann eine Änderung, Eskalation oder weitere Messung begründen; die Procedure selbst ist keine automatische Handlungsanweisung.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Ihr Zeitvertrag lautet ausdrücklich: Flüchtig/kumulativ seit Restart/Reset und begrenzt in der Zahl gespeicherter Gruppen. Daraus folgt: Ein auffälliger Einzelwert ist Beobachtung, noch keine Ursache; eine unauffällige Zeile ist keine Garantie für andere Zeitpunkte, Scopes oder unsichtbare Quellen.

Nicht ableitbar sind außerdem Daten außerhalb der Filter, wegen fehlender Rechte ausgelassene Details und bereits durch Retention, Restart, Eviction oder Statuswechsel verlorene Zustände. Findings, Prozentwerte und Durchschnitte müssen mit Nenner, Erfassungsfenster und Zeilengranularität gelesen werden. Eine Änderung an DDL, Forcing, Failover, KILL, Repair oder Konfiguration benötigt unabhängige Evidenz und einen Rollbackplan.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_MissingIndexes]
      @DatabaseNames = N'[ExampleDatabase]',
      @MinUserReads = 10,
      @ResultSetArt = 'CONSOLE';
```

Die im Beispiel verwendeten Bezeichner `ExampleServer`, `ExampleDb`, `ExampleSchema`, `ExampleObject` und `ExampleLogin` sind ausschließlich synthetische Platzhalter. Vor Produktionseinsatz mit `@Hilfe=1` beziehungsweise der Referenzsignatur prüfen, welche Filter tatsächlich früh wirken und welche Ausgabeoptionen zusätzliche Quellarbeit auslösen.

## Resultsets und Leserichtung

Im typisierten TABLE-Vertrag sind für diese Procedure `missingIndexes` registriert. Diese Namen bezeichnen die stabil exportierbaren Fachergebnisse; CONSOLE und RAW können zusätzlich Status-, Warning- und Detailresultsets liefern, deren vollständige Reihenfolge der verlinkte Familienguide beschreibt. Bei CONSOLE zuerst Status/Vollständigkeit und Scope lesen, danach das fachliche Summary und erst dann Details. RAW ist für vollständige technische Korrelation gedacht. TABLE ist für SQL-interne, typisierte Weiterverarbeitung des ausdrücklich benannten Resultsets bestimmt; JSON übernimmt die fachliche Hüllensemantik. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder aufsummiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Missing-Index-Gruppe aus den Optimizer-DMVs, nicht einem fertig geprüften Indexdesign.

Die Identität einer Zeile muss daher zusammen mit Resultsetname, Datenbank-/Objekt-/Session-/Planbezug und Messzeitpunkt gespeichert werden. Gleich aussehende Namen oder IDs aus verschiedenen Scopes sind nicht automatisch dasselbe Analyseobjekt; wiederverwendbare IDs benötigen zusätzliche Zeit- oder Handlemerkmale.

## So lesen

Reads und Compiles zuerst, danach Impact und Improvement Measure. Schlüssel und Includes mit vorhandenen Indizes vergleichen.

Die feste Reihenfolge lautet: **(1)** Status und Partialität, **(2)** Scope und Filterwirkung, **(3)** Zeit-/Reset-/Retentionbezug, **(4)** Nenner und Datenmenge, **(5)** zusammengehörige Schlüsselwerte, **(6)** plausible Gegenhypothese. Danach folgt eine zweite Evidenzquelle. Eine Sortierung nach einem auffälligen Wert ist nur eine Priorisierung und verändert weder Bedeutung noch Vollständigkeit der zugrunde liegenden Messung.

## Warum kann das problematisch sein?

Der Optimizer sieht mögliche Lesekosten, aber nicht vollständig Schreiblast, Speicher, Wartung, Redundanz und fachliche Abhängigkeiten.

Problematisch wird ein Signal erst durch die Kombination aus technischer Abweichung, passender Workloadwirkung und zeitlicher Korrelation. Das Dokument trennt deshalb Beobachtung, Ursachehypothese und Auswirkung. Wiederholung über mehrere gültige Messpunkte erhöht die Konfidenz; bloßes Wiederholen derselben DMV-Abfrage ist jedoch keine unabhängige Gegenprobe.

## Wann ist es kein Problem?

98 % Impact bei zwei Reads ist plakativ, aber schwach. Ein ähnlicher vorhandener Index kann den Vorschlag überflüssig machen.

Insbesondere sind kleine Nenner, geplante Betriebsphasen, einmalige Wartung und bekannte Featuresemantik mögliche Gegenhypothesen. Die Schwelle einer Frameworkregel ist eine Triageheuristik, keine Microsoft-Garantie und kein universeller SLO. Abweichende Baselines je Instanz, Datenbank und Tageszeit müssen dokumentiert werden.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 25 % Impact bei fünf Millionen Reads kann mehr Gesamtnutzen besitzen als 99 % bei einer Ausführung. Vor DDL immer Inventar, Usage, Querytext, Plan und Write-Last prüfen.

**Ähnlich aussehender Gegenfall:** 98 % Impact bei zwei Reads ist plakativ, aber schwach. Ein ähnlicher vorhandener Index kann den Vorschlag überflüssig machen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

**Noch nicht entscheidbar:** Sind Status, Nenner, Resetmarker oder Vergleichsfenster unbekannt, darf weder Entwarnung noch Änderungsentscheidung folgen. Dann zuerst denselben Scope sauber wiederholen oder eine unabhängige Historien-/OS-/Workloadquelle heranziehen.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_MissingIndexes` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Missing-Index-DMVs sind flüchtig und begrenzt. Leer kann Reset, fehlende Compiles oder nicht geeignete Queries bedeuten.

## Eigenlast und Grenzen

Kostenklassen sind qualitative Betriebsrisiken, keine Laufzeitgarantie. Entscheidend ist, ob Filter vor dem teuren Zugriff oder erst nach Materialisierung, XML-Parsing, Aggregation und Sortierung wirken.

**Quellcode-Hinweis zur Eigenlast:** DMV-Menge ist intern begrenzt; Join und Sortierung werden durch TOP begrenzt.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–MEDIUM |
| Standardpfad | Eine explizit benannte `ExampleDatabase`, möglichst ein Objekt und endliches Limit; die intern begrenzten Missing-Index-DMVs werden mit Objektkatalogen verbunden. |
| Teuerster Pfad | Alle sichtbaren Datenbanken, keine Objekt-/Mindestschwelle und `@MaxZeilen = 0`; einen `VOLL`-Modus oder physischen Scan besitzt die Procedure nicht. |
| Haupttreiber | Zahl gewählter Datenbanken und sichtbarer Missing-Index-Detail-/Group-Stats-Zeilen sowie Breite der Spaltenlisten für den DDL-Entwurf. Datenbank-/Objektfilter wirken vor Ranking; das Ausgabelimit ersetzt keine vollständige DMV-Korrelation. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_MissingIndexes ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU, Katalogseiten und TempDB für Joins/Aggregation; bei breitem Cross-Database-Scope zusätzlicher Compile- und Ergebnistransferaufwand. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen die Quellarbeit. TOP oder MaxZeilen werden häufig nach Katalogjoins und Aggregation angewandt und sind dann nur Ausgabelimits. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | `MISSING_INDEX_CURRENT` muss freigegeben sein, verlangt laut Klassenkatalog keine High-Impact-Bestätigung. `@HighImpactConfirmed` aktiviert keinen weiteren Pfad; Datenbank-/Objektfilter und Schwellen sind die Schutzgrenzen. |
| Sicherer Einsatz | Mit einer `ExampleDatabase`, einem `ExampleObject`, sinnvollen Mindestreads/-impact und endlichem Limit starten; mehrere Datenbanken anschließend einzeln ergänzen. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „kumulativ seit Struktur-/Instanzreset“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche zusätzlichen Nonclustered-Indexstrukturen hat der Optimizer während Kompilierungen als potenziell kostensenkend eingeschätzt?

### Technischer Hintergrund

Missing-Index-DMVs sammeln Gleichheits-, Ungleichheits- und Include-Spalten aus Optimizerentscheidungen. Der oft verwendete Improvement-Wert kombiniert geschätzte Kosten, Impact und Nutzungshäufigkeit; er ist eine Priorisierungsheuristik. Die Engine konsolidiert Vorschläge nicht automatisch mit bestehenden Indizes.

### Datenkette

`sys.dm_db_missing_index_details`, `sys.dm_db_missing_index_group_stats`, `sys.dm_db_missing_index_groups`, `sys.objects`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Source Select

Die drei Missing-Index-DMVs werden über Group- und Index-Handle verbunden; der Datenbankscope gehört in die erste Kandidatenmenge:

```sql
SELECT
      [mid].[database_id]
    , [mid].[object_id]
    , [mid].[equality_columns]
    , [mid].[inequality_columns]
    , [mid].[included_columns]
    , [migs].[user_seeks]
    , [migs].[user_scans]
    , [migs].[avg_total_user_cost]
    , [migs].[avg_user_impact]
FROM [sys].[dm_db_missing_index_details] AS [mid] WITH (NOLOCK)
JOIN [sys].[dm_db_missing_index_groups] AS [mig] WITH (NOLOCK)
  ON [mig].[index_handle] = [mid].[index_handle]
JOIN [sys].[dm_db_missing_index_group_stats] AS [migs] WITH (NOLOCK)
  ON [migs].[group_handle] = [mig].[index_group_handle]
WHERE [mid].[database_id] = DB_ID()
  AND [migs].[user_seeks] + [migs].[user_scans] >= @MinUserReads;
```

**Wichtig für die Eigenlast:** Datenbank und Mindestnutzung vor Objekt-/Schemaauflösung und DDL-Entwurf filtern. Die DMVs bleiben serverweit flüchtig; ein `TOP` nach der Bewertung reduziert nicht die zugrunde liegende DMV-Menge.

### Zeit- und Scope-Modell

Flüchtig/kumulativ seit Restart/Reset und begrenzt in der Zahl gespeicherter Gruppen. Vorschläge können nach Plan Cache-/Metadatenänderungen verschwinden.

### Bewertung und Gegenprobe

Queryhäufigkeit, Kosten, tatsächliche Reads, vorhandene Präfixe/Includes, Selectivity, DML-Kosten, Speicher und Locking prüfen. Mehrere Vorschläge häufig zu einem tragfähigen Indexdesign konsolidieren.

### Typische Fehlinterpretation

Ein hoher Improvement-Wert ist keine gemessene Einsparung. Der Vorschlag kennt Write Amplification, andere Queries, Filtered Indexes und vollständige Datenverteilung nur begrenzt.

### Folgeanalyse

Betroffene Pläne/Query Store, `USP_ObjectInventory`, `USP_IndexUsage`; DDL nur nach Test und Rollbackplan.

## Primärquellen

- [Missing-Index-DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/tune-nonclustered-missing-index-suggestions?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#4-monitorusp_missingindexes)
