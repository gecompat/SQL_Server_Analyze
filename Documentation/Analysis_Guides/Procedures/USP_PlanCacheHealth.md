# [monitor].[USP_PlanCacheHealth]

**Bereich:** Plan Cache<br>
**Zweck:** Bewertet Cachegröße, Kategorien und Single-Use-Anteil.<br>
**Beobachtungsart:** flüchtiger Cache-Snapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wie viel Memory bindet der Plan Cache und welche Planarten/Use-Count-Muster dominieren?** Sie unterstützt die Entscheidung, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanCacheHealth]
      @AnalyseModus = 'SUMMARY',
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag `overview` enthält acht Felder je Cache-/Objekttyp und entspricht `JSON.categories`. Er ist von der siebenfeldrigen RAW-Gesamtübersicht und dem sechsfeldrigen JSON-Objekt `overview` zu unterscheiden. RAW ergänzt den neunfeldrigen Modulstatus und die angeforderten Detailresultsets. Die aktive CONSOLE-Ausgabe zeigt ausschließlich die Kategorien mit einer Ergebnisbeschriftung, also neun Felder; bei leerer Kategoriequelle liefert sie drei Felder mit der Ergebnismeldung „Keine fachlichen Ergebnisse“ sowie NULL für Status und Hinweis. TABLE und CONSOLE garantieren keine Anzeigeordnung. RAW und JSON sortieren Kategorien nach `TotalSizeBytes DESC, PlanCount DESC`.

## Eine Zeile bedeutet

Eine TABLE-Zeile beschreibt eine Cache-/Objekttypkategorie. Die getrennte Gesamtübersicht aggregiert den sichtbaren Cache, die optionale Datenbankverteilung den Compilekontext und die optionalen Single-Use-Details jeweils einen Cacheeintrag.

## So lesen

Berücksichtigen Sie Gesamtgröße, Plananzahl, Single-Use-Anteil, Use Counts, Planarten und aktuellen Memory Pressure gemeinsam.

## Warum kann das problematisch sein?

Viele große Single-Use-Pläne belegen Cache für selten wiederverwendete Texte und können nützlichere Pläne oder Datenseiten verdrängen.

## Wann ist es kein Problem?

Hoher Single-Use-Anteil ohne Speicherdruck ist technische Schuld, aber möglicherweise kein akuter Engpass.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 70 % Single-Use bei reichlich freiem Speicher ist weniger dringend als 20 % bei starkem Memory Pressure. Prüfen Sie Textvarianz, Parametrisierung, Optimize for Ad Hoc und Servermemory.

**Ähnlich aussehender Gegenfall:** Hoher Single-Use-Anteil ohne Speicherdruck ist technische Schuld, aber möglicherweise kein akuter Engpass. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Diese Procedure besitzt keinen Datenbank- oder Hashfilter. Leere Kategorien können aus einem leeren sichtbaren Cache oder einer abgelehnten beziehungsweise fehlgeschlagenen Sammlung entstehen. Text und Datenbankzuordnung einzelner Detailzeilen können bei Eviction oder fehlendem Zugriff NULL bleiben.

Für `USP_PlanCacheHealth` bedeutet **keine Kategoriezeile**, dass im sichtbaren Cache kein ausgabefähiger Datensatz entstand oder die Sammlung abgelehnt beziehungsweise fehlgeschlagen ist. **0** ist ein gemessener Nullwert nur bei verfügbarer Quelle. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL** bezeichnet einen Fehler bei einer optionalen Teilquelle; der Modulstatus erhält den ersten Fehler. Ein positives Zeilenlimit lässt spätere Single-Use-Kandidaten aus, entfernt aber nicht alle vorhandenen Kandidaten. Es begrenzt keine Kategorie- oder Datenbankmenge.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Basis gruppiert die Plan-Cache-DMV. Datenbankverteilung und Details sind opt-in und PLAN_CACHE_DEEP-geschützt.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | `SUMMARY`: der gesamte sichtbare Plan Cache wird einmal nach Cache-/Objekttyp aggregiert; keine Datenbankverteilung, Single-Use-Details oder SQL-Texte. |
| Teuerster Pfad | `VOLL`, Datenbankverteilung und Single-Use-Details, `@MaxZeilen = 0` sowie ungekürzte Texte auf einem sehr großen, ad-hoc-lastigen Plan Cache. |
| Haupttreiber | Zahl der Cacheeinträge und der je Plan auszulesenden Attribute sowie Gruppierung nach Cache-/Objekttyp. Das Ergebnis ist klein, aber Kategorien und Single-Use-Anteile benötigen zuvor den breiten Cache-Snapshot. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_PlanCacheHealth ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU und Speicher für Cache-DMV-Scan, Textauflösung, Gruppierung und Sortierung; Ergebnistransfer bei langen Texten. |
| Begrenzungswirkung | Der Summarypfad gruppiert vor jeder Ausgabe den gesamten sichtbaren Cache. `@MaxZeilen` begrenzt nur Single-Use-Details; Datenbankverteilung und Summary müssen ihre jeweiligen Cachezeilen zuvor attributseitig auflösen/aggregieren. |
| Locking und Nebenwirkungen | Keine Nutzdatenlocks. Cacheeinträge können während des Lesens evicted oder neu kompiliert werden; Text-/Attributauflösung ist daher nicht atomar. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `PLAN_CACHE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Mit `SUMMARY` starten. `VOLL`, Datenbankverteilung oder Single-Use-Details nur nach Summary/Cachegrößenprüfung, mit endlichem Limit und `@HighImpactConfirmed = 1`. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „flüchtiger Cache-Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie viel Memory bindet der Plan Cache und welche Planarten/Use-Count-Muster dominieren?

### Technischer Hintergrund

Cache Stores und Cached Plans zeigen Planarten, Objekt-/Ad-hoc-Pläne, Größen und Use Counts. Viele Single-Use-Ad-hoc-Pläne können Kompilierungs-/Memorydruck erzeugen; Clock Hands und Memory Pressure steuern Eviction.

### Datenkette

`sys.configurations`, `sys.dm_exec_cached_plans`, `sys.dm_exec_plan_attributes`, `sys.dm_exec_sql_text`.

### Source Select

Cachegröße und Nutzungsgrad stammen aus `dm_exec_cached_plans`; der Datenbankbezug wird gezielt aus den Planattributen gelesen:

```sql
SELECT
      [cp].[cacheobjtype]
    , [cp].[objtype]
    , [cp].[usecounts]
    , [cp].[size_in_bytes]
    , TRY_CONVERT(int, [dbid].[value]) AS [DatabaseId]
FROM [sys].[dm_exec_cached_plans] AS [cp] WITH (NOLOCK)
OUTER APPLY
(
    SELECT TOP (1) [pa].[value]
    FROM [sys].[dm_exec_plan_attributes]([cp].[plan_handle]) AS [pa]
    WHERE [pa].[attribute] = N'dbid'
) AS [dbid];
```

**Wichtig für die Eigenlast:** Der Kategorienpfad umfasst alle sichtbaren Cacheobjekttypen und benötigt weder SQL-Text noch Datenbankattribute. Die optionale Datenbankverteilung liest Planattribute für ihren gesamten Scope. Nur Single-Use-Details werden vor ihrer Materialisierung nach `size_in_bytes DESC` begrenzt; die anschließend materialisierten Texte werden Unicode-sicher projiziert. Zusätzliche Scan-, Sortier- und Auflösungsarbeit wird damit nicht ausgeschlossen.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den sichtbaren aktuellen Cachebestand. Kategorien, Datenbankverteilung und Details werden nacheinander gelesen und sind keine atomare Momentaufnahme. `@MaxZeilen` begrenzt ausschließlich Single-Use-Details; NULL und 0 sind unbegrenzt. Kategorien und Datenbankverteilung bleiben unabhängig von diesem Limit vollständig für ihren jeweiligen Sammlungsscope. Gleiche Detailgrößen erlauben verschiedene Auswahlen zwischen Aufrufen. NULL oder 0 als Textlimit liefert vollständige verfügbare Texte; positive Werte begrenzen SC-Zeichen und erhalten ursprüngliche Zeichen- und Bytezahlen. Negative Zeilen- oder Textlimits liefern `INVALID_PARAMETER`.

### Bewertung und Gegenprobe

Bewerten Sie Cachegröße relativ zu Servermemory, Single-Use-Anteil in Bytes und Count, Ad-hoc-Workload, Compile/sec und Parameterisierungsstrategie.

### Typische Fehlinterpretation

Viele Single-Use-Pläne sind nicht automatisch Hauptproblem. `optimize for ad hoc workloads` reduziert zunächst Stubgröße, behebt aber keine Querygenerierung oder Compileursache.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_ServerMemory`, Performance Counters, Query Hash und Anwendung/Parameterisierung.

## Primärquellen

- [sys.dm_exec_cached_plans](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-cached-plans-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#3-monitorusp_plancachehealth)
