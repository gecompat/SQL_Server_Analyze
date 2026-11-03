# [monitor].[USP_ShowplanAnalysis]

**Bereich:** Plan Cache und Showplan<br>
**Zweck:** Extrahiert Statements, Warnungen, Objekte, Statistiken, Operatoren, Kardinalität, Memory und Parameter aus Plan-XML.<br>
**Beobachtungsart:** flüchtiger Cache-Snapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Operatoren, Schätzungen, Warnungen, Objekte, Statistiken und Optimizerhinweise enthält ein Showplan?** Sie unterstützt die Entscheidung, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ShowplanAnalysis]
      @QueryHash = 0x0102030405060708,
      @AnalyseModus = 'GEZIELT',
      @MaxAnalyseobjekte = 5,
      @MaxDurationSeconds = 10,
      @MaxZeilen = 1000,
      @ResultSetArt = 'CONSOLE';
```

Der Aufruf verwendet ausschließlich einen synthetischen Beispielhash. Echte Hashes dürfen nur für eine kontrollierte Laufzeitanalyse verwendet und nicht ungeprüft weitergegeben werden.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@PlanHandle` | `varbinary(64)` | `NULL` | Exakter Planhandle. Nicht-NULL fügt den Handle direkt als Kandidat hinzu. NULL erlaubt Cacheauswahl per weiteren Selektoren oder VOLL. |
| `@QueryHash` | `binary(8)` | `NULL` | Exakter binärer 8-Byte-Queryhash für die Cacheauswahl. NULL lässt diesen Filter aus. |
| `@QueryPlanHash` | `binary(8)` | `NULL` | Exakter binärer 8-Byte-Plan-Hash für die Cacheauswahl. NULL lässt diesen Filter aus. |
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Pipe-Liste exakter Datenbanknamen. NULL, leer oder nur Leerzeichen = keine exakte Einschränkung. &#124; trennt außerhalb von [...]. ]] maskiert ] innerhalb. Äußere Segmentleerzeichen entfernt. Elemente einteilige Namen bis 128 Zeichen. Ungültige Liste INVALID_PARAMETER. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | 0 schließt master, tempdb, model und msdb aus. 1 lässt sie zu. NULL führt zur Parameterablehnung. Ausgelassen = 0. SQL-bit-Konvertierung kann numerische Nichtnullwerte als 1 abbilden. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Ein LIKE-Pattern oder Präfix like:, regex:, regexi:. Erkennung ohne Beachtung der Großschreibung. Äußere Leerzeichen getrimmt, Musterrest nicht erneut. NULL = kein Pattern. Leerer Inhalt ungültig. Nicht mit wirksamer @DatabaseNames-Liste kombinierbar. Regex Flag c/i und Ausführung nur SQL Server 2025 + Compatibility Level 170 der Installationsdatenbank. Sonst UNAVAILABLE_FEATURE. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 keine Bestätigung. 1 bestätigt angeforderte Policy-Gates für PLAN_CACHE_DEEP und/oder SHOWPLAN_XML_DEEP. Bestätigung hebt Filter und Limits nicht auf. |
| `@TextPattern` | `nvarchar(4000)` | `NULL` | SQL-Textpattern. NULL = kein Filter. Parser erkennt case-insensitive like:, regex:, regexi:, sonst LIKE. Außenleerzeichen getrimmt, Patternrest nicht. Leerer effektiver Inhalt INVALID_PARAMETER. Nicht als Pipe-Liste zerlegt. LIKE nutzt %/_/SQL LIKE-Syntax. Regex braucht SQL Server 2025 und Installations-DB-Kompatibilität 170, Syntaxfehler werden von Regex-Ausführung gemeldet. |
| `@AnalyseModus` | `varchar(16)` | `'GEZIELT'` | GEZIELT erfordert einen Planhandle, einen der beiden Hashes, eine nichtleere Datenbankliste oder ein Datenbank- oder Textmuster. Die Listen und Muster werden anschließend separat geprüft. Der Modus verwendet die Child-Tiefe STANDARD. VOLL prüft PLAN_CACHE_DEEP und verwendet FULL. NULL entspricht GEZIELT. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte sind ungültig. |
| `@PlanQuelle` | `varchar(16)` | `'AUTO'` | AUTO versucht den verfügbaren letzten Actual-Plan und fällt auf COMPILE zurück. COMPILE verwendet den kompilierten Cacheplan. LAST_ACTUAL fordert den letzten verfügbaren Actual-Plan ohne Aktivierung von Profiling an. NULL entspricht AUTO. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. Leere und andere Werte sind ungültig. |
| `@Sortierung` | `varchar(32)` | `'CPU_TOTAL'` | Trim/Upper, bestimmt Top-Kandidaten-Ranking. CPU_TOTAL=gesamte Workerzeit. ELAPSED_TOTAL=gesamte Laufzeit. READS_TOTAL=gesamte Reads. EXECUTIONS=Ausführungszahl. SPILLS_TOTAL=Spillmaß. GRANT_MAX=größtes Grant. LAST_EXECUTION=letzte Ausführung. Alle sieben erlaubten Codes, NULL fällt auf CPU_TOTAL zurück. Leer ungültig. |
| `@MinExecutionCount` | `bigint` | `1` | Ganzzahliges Minimum für die Ausführungszahl in der Cacheauswahl. 0 lässt auch Einträge mit 0 Ausführungen zu. Negative Werte ergeben INVALID_PARAMETER. Bei NULL trifft der Vergleich auf keine Cachezeile. Ein direkt angegebener Planhandle bleibt ein eigener Kandidatenpfad. |
| `@MaxAnalyseobjekte` | `int` | `20` | Positive Grenze der Kandidaten vor Planladen. 0/NULL unbegrenzt. Negativ ungültig. >20 oder unbegrenzt prüft PLAN_CACHE_DEEP, danach kann VOLL zusätzlich SHOWPLAN_XML_DEEP prüfen. |
| `@MaxDurationSeconds` | `int` | `30` | Ganzzahl von 1 bis 3600 Sekunden. Das Zeitbudget wird zwischen Kandidaten geprüft. Es unterbricht eine laufende XML-Analyse nicht. NULL setzt auf Wrapper-Ebene keine wirksame Deadline und wird an die Child-Analyse weitergegeben. Die Child-Analyse weist NULL als ungültig zurück. |
| `@MaxZeilen` | `int` | `50000` | Positiv begrenzt Ergebniszeilen/Findingbudget. 0/NULL unbegrenzt (Childbudget wird intern auf 50000 gedeckelt). Negativ ungültig. Resultset-TOP und Candidate-Limit sind getrennte Grenzen. |
| `@ParentQueryStatsSnapshot` | `bit` | `0` | 0 liest Query Stats frisch. 1 verwendet den laufgebundenen Snapshot von USP_PlanCacheAnalysis. NULL aktiviert den Snapshot-Zweig nicht. Verwenden Sie 0 für eigenständige Aufrufe. |
| `@WorkloadProfil` | `varchar(32)` | `'AUTO'` | Auswahl des aktiven Workloadprofils für Regeln und Schwellwerte. AUTO wählt innerhalb der Analyse aus der aktivierten Profilkonfiguration (monitor.PlanAnalysisProfile). Der konkrete gültige Profilcode ist damit installations-/konfigurationsabhängig, keine im Wrapper geschlossene Liste. Profilcodes werden im Child auf Großschreibung normalisiert. Unbekannter/deaktivierter Code fällt intern kontrolliert auf BALANCED zurück. NULL wird vom Child auf AUTO normalisiert. Leerwert führt zum unbekannten Profil und Fallback BALANCED. |
| `@MinSchweregrad` | `varchar(16)` | `'INFO'` | Mindestschweregrad für Findings. Geschlossene Menge INFO, LOW, MEDIUM, HIGH, CRITICAL. Stufen sind aufsteigende Mindestschwellen, INFO lässt die niedrigste Stufe zu, CRITICAL nur höchste Schwere. NULL wird auf INFO normalisiert. Leertext ist ungültig. |
| `@MitThreadRuntime` | `bit` | `0` | 0 unterdrückt Thread-Runtime-Evidenz. 1 fordert sie an. Verwenden Sie 0 oder 1 als eindeutigen Schalter. Für Threaddaten können Quellverfügbarkeit und Planumfang Grenzen setzen. |
| `@MitSqlText` | `bit` | `0` | 0 unterdrückt SQL-Text. 1 fordert Statementtext an und benötigt zusätzlich SensitiveDataConfirmed=1, da Literale/proprietärer Text enthalten sein können. Verwenden Sie 0 oder 1 als eindeutigen Schalter. |
| `@StatistikEvidenzModus` | `varchar(16)` | `'PLAN_ONLY'` | Geschlossene Menge: NONE=keine Statistik-Evidenz. PLAN_ONLY=nur Statistikhinweise aus Plan-XML. USED=Statistiken, die der Plan als benutzt ausweist. RELEVANT=erweiterte relevante Statistiken samt tieferer Evidence. OBJECT_ALL=alle Statistiken der referenzierten Objekte. NULL normalisiert zu PLAN_ONLY. Leertext ungültig. RELEVANT und OBJECT_ALL lösen tiefere Statistik-/Katalogpfade aus. |
| `@HistogrammModus` | `varchar(16)` | `'NONE'` | Geschlossene Menge: NONE=kein Histogramm. SUMMARY=Zusammenfassung. STEPS=Schrittwerte des Histogramms. NULL wird zu NONE normalisiert. Leertext ungültig. STEPS gehört zum tiefen Pfad. MaxHistogrammSchritte begrenzt die gelieferten Schritte. |
| `@MetadatenQuellenmodus` | `varchar(16)` | `'EVIDENCE_ONLY'` | Geschlossene Menge: EVIDENCE_ONLY verwendet im Plan/Evidence vorhandene Metadaten. CURRENT_SERVER reichert aus dem aktuellen Serverkatalog an. NULL wird zu EVIDENCE_ONLY normalisiert. Leertext ungültig. CURRENT_SERVER erfordert QuellumgebungBestaetigt=1, damit die aktuelle Umgebung ausdrücklich als Datenquelle bestätigt ist. |
| `@QuellumgebungBestaetigt` | `bit` | `0` | 0 keine Bestätigung. 1 bestätigt, dass CURRENT_SERVER-Katalogmetadaten der Quellumgebung zugeordnet werden dürfen. Nur 0/1. NULL ungültig. CURRENT_SERVER ohne 1 wird abgelehnt. |
| `@EvidenzDatenschutzModus` | `varchar(24)` | `'DERIVED_ONLY'` | Geschlossene Menge: DERIVED_ONLY gibt abgeleitete Evidenz ohne rohe Parameter-/Histogrammwerte aus. TOKENIZED ersetzt sensible Werte durch Token. STRUCTURE_ONLY gibt Struktur/Metadaten ohne Werte aus. RAW gibt rohe Parameter- und Histogrammwerte aus. NULL wird zu DERIVED_ONLY normalisiert. Leertext ungültig. RAW erfordert SensitiveDataConfirmed=1. |
| `@IdentifierDatenschutzModus` | `varchar(16)` | `'RAW'` | Geschlossene Menge: RAW gibt Objekt-/Statistikidentifikatoren im Original aus. TOKENIZED ersetzt sie durch Token. OMIT lässt Identifikatoren weg. NULL wird zu RAW normalisiert. Leertext ungültig. |
| `@SensitiveDataConfirmed` | `bit` | `0` | 0 keine Freigabebestätigung. 1 bestätigt die bewusste Verarbeitung potentiell sensibler Rohwerte. Verwenden Sie 0 oder 1 als eindeutigen Schalter. Erforderlich bei EvidenzDatenschutzModus=RAW oder MitSqlText=1. Kein allgemeiner Gate-Bypass. |
| `@MaxStatistiken` | `int` | `100` | Anzahlbegrenzung der gelesenen Statistikobjekte, Bereich 1..1000. 0 und NULL ungültig. Bei tiefer Statistik-Evidenz begrenzt diese Zahl die Katalogarbeit. |
| `@MaxHistogrammSchritte` | `int` | `20000` | Maximal gelesene Histogrammschritte, Bereich 0..200000. 0 erlaubt keine Schritte (Zusammenfassung bleibt möglich), NULL ungültig. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Trim/Upper. CONSOLE lesbare Resultsets, RAW kanonische Detailresultsets, TABLE schreibt die typisierten Resultsets in Zieltabellen, NONE unterdrückt direkte Resultsets. Erlaubt genau CONSOLE, RAW, TABLE, NONE. NULL wird leer und ungültig, Leerwert ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakt geschriebenen Schlüssel parameters, planWarnings, optimizerContext, runtimeFeedback, queryStoreContext, feedbackAndVariants und findings. Jeder Wert muss als Zeichenfolge eine andere vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte benennen. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE ist ausschließlich NULL erlaubt. Auch eine leere Zeichenfolge ist ungültig. Die Zuordnung wird nach dem Hilfe-Return und vor den Quellzugriffen geprüft. Ein ungültiges Mapping kann Fehler 51011 auslösen. |
| `@JsonErzeugen` | `bit` | `0` | 1 erzeugt JSON in @Json unabhängig von der Ausgabeart. 0 oder NULL erzeugt kein Dokument. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT nvarchar(max), wird beim Eintritt auf NULL gesetzt und bei JsonErzeugen=1 mit Objekt meta, planStatus und den sieben Fachergebnisarrays sowie analyses befüllt. Caller muss gleich typisierten Variable OUTPUT binden. |
| `@PrintMeldungen` | `bit` | `1` | 1 PRINT-Meldungen aktiv. 0 unterdrückt. NULL nicht als aktiv darstellen. |
| `@Hilfe` | `bit` | `0` | 1 zeigt die Hilfe und beendet den Aufruf vor Validierung, TABLE-Zuordnungsprüfung und fachlicher Analyse. 0 und NULL führen die Analyse aus. |

## Aufrufbeispiele

Hilfe anzeigen.

```sql
EXEC [monitor].[USP_ShowplanAnalysis] @Hilfe=1;
```

Technische Resultsets lesen.

```sql
EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @AnalyseModus='GEZIELT', @PlanQuelle='COMPILE', @MaxAnalyseobjekte=5, @MaxDurationSeconds=10, @MaxZeilen=1000, @ResultSetArt='RAW';
```

Nur JSON ausgeben.

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @JsonErzeugen=1, @ResultSetArt='NONE', @Json=@Json OUTPUT;
SELECT @Json AS [Json];
```

Ein Resultset in eine lokale Temp-Tabelle schreiben.

```sql
CREATE TABLE #ShowplanAnalysis_HelpExample ([Seed] int NULL);
BEGIN TRY EXEC [monitor].[USP_ShowplanAnalysis] @QueryHash=0x0102030405060708, @ResultSetArt='TABLE', @ResultTablesJson=N'{"findings":"#ShowplanAnalysis_HelpExample"}';
SELECT * FROM #ShowplanAnalysis_HelpExample;
DROP TABLE #ShowplanAnalysis_HelpExample;
END TRY BEGIN CATCH DROP TABLE #ShowplanAnalysis_HelpExample;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `parameters`, `planWarnings`,
`optimizerContext`, `runtimeFeedback`, `queryStoreContext`,
`feedbackAndVariants` und `findings`. Status und Scope sind vor den
Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON
erhalten zusätzlich `moduleStatus`, `planStatus` und die kandidatengenauen
DIAG-003-/DIAG-005-Ergebnisse. Resultsets mit unterschiedlicher
Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Finding, einer Parameterevidenz,
einer Planwarnung, einem Statementkontext, einer Runtimebeobachtung, einem
Query-Store-Kontext oder einem Feature-/Variantenmerkmal. `CandidateId` und
`PlanHandle` stellen in allen kanonischen Ergebnissen den äußeren
Mehrplanbezug her.

## So lesen

Prüfen Sie zuerst `planStatus`. Lesen Sie in `parameters` anschließend
`ValueSource`, Presence-/SQL-NULL-Flags, `ValueStatus`, Quellzeit,
Current-/Last-known-Semantik und `IsComplete`. Ordnen Sie dann Warnungen,
Optimizer-/Cachekontext, Runtimefeedback und Varianten anhand von Quelle,
Zeitbezug, Mess-/Ableitungsflags und False-Positive-Grenze ein. Vertiefen Sie
danach die Findings im jeweiligen Child-Analyse-JSON.

## Warum kann das problematisch sein?

Große Estimate-/Actual-Abweichungen können ungeeignete Joinarten, Grants und Zugriffspfade verursachen. Spills zeigen Auslagerung nach TempDB.

## Wann ist es kein Problem?

Ratio 10 bei 1 zu 10 Zeilen ist meist weniger relevant als Ratio 10 bei 10 Mio. zu 100 Mio. Zeilen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Estimate 1, Actual 10 Mio. kann Nested Loops oder einen kleinen Grant kollabieren lassen. Prüfen Sie Statistik, Parameter, Query Store, Index und Memory.

**Ähnlich aussehender Gegenfall:** Ratio 10 bei 1 zu 10 Zeilen ist meist weniger relevant als Ratio 10 bei 10 Mio. zu 100 Mio. Zeilen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, falscher Datenbank-/Hashfilter oder fehlender Text-/Planzugriff.

Für `USP_ShowplanAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

XML-XQuery ist CPU-intensiv. Halten Sie Scope, Zeit- und Objektbudget klein.

**Quellcode-Hinweis zur Eigenlast:** XML wird erst nach Kandidatenselektion planweise geladen und geschreddert. VOLL oder mehr als 20 Pläne prüft PLAN_CACHE_DEEP und SHOWPLAN_XML_DEEP; dies gilt ebenfalls ab mehr als 20 Plänen. Zeit- und Mengenlimits sind hart vorgesehen.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | `GEZIELT`, maximal 20 Candidates, 30-Sekunden-Deadline und 50.000 Ergebniszeilen. GEZIELT verlangt mindestens einen Planhandle, einen der beiden Hashes, eine nichtleere Datenbankliste oder ein Datenbank- oder Textmuster. Ohne Selektor liefert der Aufruf INVALID_PARAMETER. |
| Teuerster Pfad | `VOLL` oder unbegrenzte Candidates, große Plan-XMLs, 3.600-Sekunden-Deadline und unbegrenztes Zeilenbudget. Jeder Plan wird durch die zentrale Engine in mehrere fachliche Granularitäten zerlegt. |
| Haupttreiber | Zahl/Größe der ausgewählten Compile- oder Last-Actual-Pläne und Operator-/Statementknoten je XML. Candidate-Ranking liest frisch `sys.dm_exec_query_stats` oder verwendet den Parent-Snapshot. |
| Skalierung | Candidateauswahl scannt/rangiert den Cache einmal und materialisiert dabei den wiederverwendeten Cachekontext; anschließend wächst XQuery-Arbeit planweise mit XML-Komplexität. Die Child-Analyse zerlegt den Plan einmal; die äußere Procedure aggregiert deren JSON und führt keine zweite Parameter- oder Feature-XQuery aus. |
| Ressourcen | CPU, Speicher und TempDB für XML-Laden und -Shredding; Cachezugriff sowie großer Transfer bei vollständigem Plan XML. |
| Begrenzungswirkung | Candidate-Limit wirkt vor dem Planladen. Deadline und Finding-/Zeilenbudget werden zwischen Candidates geprüft, können aber das bereits begonnene XML-Shredding eines großen Plans nicht abbrechen. Die Ausgabe erhält zusätzlich pro Resultset TOP; Filter vor dem Ranking sind wirksamer. |
| Locking und Nebenwirkungen | Keine Nutzdatenänderung. Cachehandles können verschwinden; `LAST_ACTUAL` liefert nur vorhandene Last-Actual-Evidenz und aktiviert kein Profiling. XML-Auswertung kann erhebliche Schedulerzeit verbrauchen. |
| Schutzmechanismus | Bei `VOLL` oder mehr als 20/unbegrenzten Candidates prüft der Code nacheinander `PLAN_CACHE_DEEP` und `SHOWPLAN_XML_DEEP`. Einen separaten `SHOWPLAN_TARGETED`-Check gibt es in dieser Implementierung nicht. Bestätigung ersetzt Filter, Deadline und Mengenbudget nicht. |
| Sicherer Einsatz | Genau einen `ExampleQueryHash`/PlanHandle untersuchen, höchstens wenige Kandidaten und kurze Deadline. `LAST_ACTUAL` sowie `VOLL` nur bewusst und mit beiden Deep-Gates. |
| Aussagegrenze | Cacheeviction kann zwischen Ranking und XML-Laden auftreten. Compile-Pläne enthalten keine Ist-Zeilen; LAST_ACTUAL nur bereits vorhandene Profilingevidenz. Deadline/Top-N priorisiert, kann aber gerade den ursächlichen späteren Plan auslassen. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Operatoren, Schätzungen, Warnungen, Objekte, Statistiken und Optimizerhinweise enthält ein Showplan?

### Technischer Hintergrund

Showplan XML modelliert RelOp-Baum, Estimated Rows/Cost, Predicate, Object/Index, Statistics, Memory Grant, Parallelism und Warnings. Cached/Query-Store-Pläne sind typischerweise Estimated-/Compilepläne; Actual Rows existieren nur in tatsächlichen Ausführungsplänen beziehungsweise entsprechenden Runtimefeatures.

### Datenkette

`master.sys.databases`, `sys.dm_exec_plan_attributes`, `sys.dm_exec_query_plan`, `sys.dm_exec_query_plan_stats`, `sys.dm_exec_query_stats`, `sys.dm_exec_sql_text`, `sys.sp_executesql`.

### Source Select

Die Procedure selektiert zuerst eindeutige Planhandles und delegiert deren Planauflösung an `USP_ExecutionPlanAnalysis`:

```sql
SELECT
      [qs].[query_hash]
    , [qs].[query_plan_hash]
    , [qs].[plan_handle]
    , [qs].[execution_count]
    , [st].[text]
FROM [sys].[dm_exec_query_stats] AS [qs] WITH (NOLOCK)
OUTER APPLY [sys].[dm_exec_sql_text]([qs].[sql_handle]) AS [st]
WHERE [qs].[plan_handle] = @PlanHandle;
```

**Wichtig für die Eigenlast:** Setzen Sie Plan Handle, Query Hash oder enger Top-Kandidat vor dem Childaufruf. Erst `USP_ExecutionPlanAnalysis` beschafft und zerlegt das Plan-XML; Operator- und Warning-Extraktion wächst mit der XML-Größe und benötigt im breiten Pfad das entsprechende Gate.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den Planstand zum Compile- beziehungsweise Capturezeitpunkt; die zugrunde liegenden Daten oder Statistiken können inzwischen geändert sein.

### Bewertung und Gegenprobe

Berücksichtigen Sie den Operatorfluss von unten nach oben, Estimated und Actual, sofern vorhanden, die Join- und Accessmethode, Predicate, Spills, Conversions, Missing Index sowie Memory und Parallelism gemeinsam. Priorisieren Sie eine Warnung zusammen mit ihrer Runtimewirkung.

### Typische Fehlinterpretation

Estimated Cost ist keine gemessene Zeit und zwischen unabhängigen Servern/CE-Kontexten nicht absolut vergleichbar. Missing-Index-XML ist keine fertige DDL.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Statistics Distribution, Query Store Runtime/Regression und reale Laufzeitmessung.

## Primärquellen

- [Showplan XML](https://learn.microsoft.com/en-us/sql/relational-databases/showplan-logical-and-physical-operators-reference?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#5-monitorusp_showplananalysis)
