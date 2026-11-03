# [monitor].[USP_PlanDetails]

**Bereich:** Plan Cache<br>
**Zweck:** Löst gezielte Plan-Kandidaten auf und liefert Attribute sowie Compile-, Last-Actual- oder Live-Plan.<br>
**Beobachtungsart:** flüchtiger Cache-Snapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Attribute, Texte, Statements und Planinformationen gehören zu einem konkreten Handle?** Sie unterstützt die Entscheidung, welche aktuell gecachten Query-/Plan-Kandidaten vertieft werden sollen und welche Historienquelle die flüchtige Cachebeobachtung bestätigen muss.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige Workloadhistorie; evictete Pläne, nicht gecachte Statements und Ursachen außerhalb des Plans bleiben unsichtbar. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PlanDetails]
      @SessionIds = N'57',
      @MitCompilePlan = 1,
      @MitLastActualPlan = 0,
      @MitLivePlan = 0,
      @MaxAnalyseobjekte = 5,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'CONSOLE';
```

Die Session-ID ist vollständig synthetisch. Arbeiten Sie alternativ gezielt mit einem vorhandenen Plan Handle oder Query Hash und vermeiden Sie breite Läufe.

Alle `Example*`-Werte im Aufruf sind synthetisch.

### Berechtigungen des Aufrufers

Die Serverquellen verwenden `VIEW SERVER STATE` beziehungsweise ab SQL Server 2022 `VIEW SERVER PERFORMANCE STATE`. Bei eingeschränkten Frameworkrechten muss außerdem der dynamische Unicodepfad zugänglich sein. Die begrenzte SQL-Server-2025-Abnahme verwendete `EXECUTE` auf Schema `monitor` und zusätzlich `SELECT` auf `[monitor].[TVF_ProjectUnicodeText]`. Schema-`EXECUTE` allein deckte den dynamischen TVF-Zugriff nicht ab; der fehlende Helperzugriff führte zu Fehler 229 außerhalb der quellenspezifischen Planstatuszeilen. Diese geprüfte Konfiguration ist kein Vertrag für eine minimale oder allgemeine Frameworkrolle.

Die native Requestquelle kann andere Sessions bei fehlender oder ausdrücklich verweigerter Serverberechtigung ohne Fehler ausblenden. Eine begrenzte SQL-Server-2025-Abnahme bestätigt beim Sessionselektor in diesem Fall `AVAILABLE` mit leerer Auswahl und ohne Partialität. Dieser Status bestätigt den fehlerfreien Quellenzugriff innerhalb der sichtbaren Menge; er belegt keine Berechtigung zur Sicht auf eine andere Session.

Ein separat aktivierter Livezugriff kann trotz leerer Requestauswahl einen Berechtigungsfehler liefern. Die begrenzte SQL-Server-2025-Abnahme beobachtet hierfür `PARTIAL` und eine `LIVE_XML`-Planzeile mit `CandidateId = NULL`, `ERROR_HANDLED` und Fehler 300. Die bestehenden Modulfelder `ErrorNumber` und `ErrorMessage` bleiben bei diesem isolierten Livefehler NULL; der konkrete Fehler steht in der Planzeile. Prüfen Sie deshalb zusätzlich zum Modulstatus die Planzeilen in RAW, TABLE oder JSON.

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@SessionIds` | `nvarchar(max)` | `NULL` | Liste ganzer Session-IDs von 1 bis 32767, z. B. 57&#124;61. Pipe, Beistrich und Strichpunkt sind Trennzeichen. NULL lässt diesen Selektor aus. Leere, nur aus Leerzeichen bestehende oder ungültige Elemente ergeben INVALID_PARAMETER. Doppelte IDs werden zusammengefasst. Live-XML erfordert genau eine eindeutige Session-ID. |
| `@PlanHandle` | `varbinary(64)` | `NULL` | Exakter Planhandle. NULL lässt diesen Selektor aus. Nicht-null wird als Kandidat aufgenommen, auch wenn der Handle inzwischen nicht mehr im Cache auflösbar ist. |
| `@SqlHandle` | `varbinary(64)` | `NULL` | Exakter SQL-Handle. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Zeilen dieses Handles. Bis zum Kandidatenlimit, nach total_worker_time absteigend. |
| `@QueryHash` | `binary(8)` | `NULL` | Exakter 8-Byte Queryhash. NULL lässt Selektor aus. Nicht-null sucht sichtbare Query-Stats-Kandidaten dieses Hashes. Bis zum Kandidatenlimit, nach total_worker_time absteigend. |
| `@MitPlanAttributes` | `bit` | `1` | 0 unterdrückt Planattribute. 1 liest sie für jeden behaltenen Kandidaten. NULL wird von der Implementierung nicht als eigener Modus unterstützt (SQL-IF-Zweig wird nicht aktiviert). |
| `@MitCompilePlan` | `bit` | `1` | 0 unterdrückt kompiliertes Showplan-XML. 1 fordert sys.dm_exec_query_plan an. NULL aktiviert den Zweig nicht. Fehlender Plan wird als nicht verfügbar je Candidate ausgegeben. |
| `@MitTextPlan` | `bit` | `0` | 0 unterdrückt Text-Showplan. 1 fordert ihn an. NULL aktiviert den Zweig nicht. |
| `@MitLastActualPlan` | `bit` | `0` | 0 unterdrückt Last-known-Actual-Plan. 1 liest vorhandene LAST_QUERY_PLAN_STATS-Evidenz. Die Procedure aktiviert die Datenbankoption nicht. NULL aktiviert den Zweig nicht. Fehlendes XML kann deaktiviert, ungeeignet, nicht cachebar oder evicted bedeuten. |
| `@MitLivePlan` | `bit` | `0` | 0 unterdrückt Live-Abfrage. 1 erfordert genau eine eindeutige Session-ID in SessionIds. Sonst wird ein INVALID_PARAMETER-Planstatus ausgegeben. Liest laufenden Request, aktiviert kein Profiling. NULL aktiviert den Zweig nicht. |
| `@MaxAnalyseobjekte` | `int` | `20` | Positive Zahl begrenzt die zusammengeführten Kandidaten. 0 oder NULL bedeutet unbegrenzt. Negativ ist INVALID_PARAMETER. Oberhalb 20 einschließlich unbegrenzt wird PLAN_CACHE_DEEP geprüft und je Policy kann HighImpactConfirmed erforderlich sein. Limit ist keine Ergebniszeilengrenze. |
| `@HighImpactConfirmed` | `bit` | `0` | 0 keine Bestätigung, 1 bestätigt das Deep-Analyse-Gate gemäß zentraler Policy. Der Parameter übergeht das Gate nicht selbständig. NULL ist kein eigener bestätigender Wert. |
| `@MaxSqlTextZeichen` | `int` | `8000` | Positive Zahl kürzt Statement- und Batchtext auf diese Zeichenanzahl. 0 oder NULL erhält beide vollständig. Negativ ist INVALID_PARAMETER. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Nach Trim und Großschreibung: CONSOLE gibt lesbare benannte Resultsets. RAW gibt kanonische rohe Resultsets. NONE unterdrückt direkte Resultsets. TABLE schreibt in registrierte Zieltabellen. Geschlossene Menge: CONSOLE, RAW, NONE, TABLE. NULL/Leerwert normalisiert zu leer und ist ungültig. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Bei TABLE ist ein gültiges, nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakt geschriebenen Schlüssel candidates, attributes und plans. Jeder Wert muss als Zeichenfolge eine andere vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte benennen. Erlaubt sind höchstens 116 Zeichen und weder ## noch #Monitor als Präfix. Außerhalb von TABLE sind nur NULL, die leere Zeichenfolge und reine Leerzeichen zulässig. Die Prüfung läuft vor der Hilfe. Ein ungültiges Mapping kann Fehler 51011 auslösen. |
| `@JsonErzeugen` | `bit` | `0` | 0 erzeugt kein JSON. 1 erzeugt JSON im OUTPUT-Parameter. NULL kein aktiver Schalterwert/keine JSON-Erzeugung. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | Binden Sie eine nvarchar(max)-Variable mit OUTPUT. Der Aufruf setzt sie zunächst auf NULL. Bei @JsonErzeugen=1 enthält sie ein Objekt mit meta, candidates, attributes, plans und warnings. |
| `@PrintMeldungen` | `bit` | `1` | 1 erlaubt Status-/Hinweismeldungen via PRINT. 0 unterdrückt sie. NULL wird nicht als 1 behandelt. |
| `@Hilfe` | `bit` | `0` | 1 zeigt die Hilfe nach der Prüfung von @ResultTablesJson und beendet den Aufruf vor der fachlichen Analyse. 0 und NULL führen die Analyse aus. |

## Aufrufbeispiele

Hilfe anzeigen.

```sql
EXEC [monitor].[USP_PlanDetails] @Hilfe=1;
```

Technische Resultsets lesen.

```sql
EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @MitCompilePlan=1, @ResultSetArt='RAW';
```

Nur JSON ausgeben.

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_PlanDetails] @PlanHandle=0x0102030405060708090A0B0C0D0E0F10, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json AS [Json];
```

Ein Resultset in eine lokale Temp-Tabelle schreiben.

```sql
CREATE TABLE #PlanDetails_HelpExample ([Seed] int NULL);
BEGIN TRY EXEC [monitor].[USP_PlanDetails] @QueryHash=0x0102030405060708, @ResultSetArt='TABLE', @ResultTablesJson=N'{"plans":"#PlanDetails_HelpExample"}';
SELECT * FROM #PlanDetails_HelpExample;
DROP TABLE #PlanDetails_HelpExample;
END TRY BEGIN CATCH DROP TABLE #PlanDetails_HelpExample;
THROW;
END CATCH;
```

## Resultsets und Leserichtung

TABLE registriert `candidates`, `attributes` und `plans` mit 23, vier und zehn Feldern. Die neun Textfelder sind explizit mit der Frameworkcollation versehen; keines dieser Exportschemas erzeugt Identitywerte. RAW liefert zuerst neun Modulstatusfelder, danach Kandidaten und die angeforderten Attribut-/Planresultsets. Die aktive CONSOLE zeigt ausschließlich den generischen Kandidatenexport mit 24 Feldern einschließlich Label oder eine dreifeldrige Leerzeile. JSON enthält `meta`, die drei Arrays und das bestehende leere `warnings`-Array; alle Fachfelder einschließlich NULL-Werten bleiben enthalten. Unterschiedliche Zeilengranularitäten dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Kandidaten-, Attribut- und Planresultsets besitzen unterschiedliche Granularität: Kandidat, Attribut je Kandidat beziehungsweise Planquelle je Kandidat.

## So lesen

Bestimmen Sie zuerst die Kandidatenidentität. Unterscheiden Sie danach die Cache-Key-Attribute und schließlich die Planquelle: Compile, Last Actual oder Live.

## Warum kann das problematisch sein?

Abweichende Cache-Key-Attribute können mehrere Handles erzeugen. Actual-Pläne können große Schätzfehler, Spills und reale Zeilenmengen sichtbar machen.

## Wann ist es kein Problem?

Compile-Pläne enthalten nur Schätzungen. Fehlende Actualwerte sind daher kein Queryfehler.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Identischer Text mit unterschiedlichen `set_options` erklärt getrennte Cacheeinträge. Verwenden Sie danach `USP_ShowplanAnalysis` oder manuellen Planvergleich.

**Ähnlich aussehender Gegenfall:** Compile-Pläne enthalten nur Schätzungen. Fehlende Actualwerte sind daher kein Queryfehler. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Im Plan Cache kann leer bedeuten: evicted, nie gecacht, recompile, nicht passender Session-/Handle-/Hashselektor oder fehlender Text-/Planzugriff. Diese Procedure besitzt keinen Datenbankfilter.

Für `USP_PlanDetails` bedeutet **keine Kandidatenzeile**, dass kein passender Request oder Cachekandidat sichtbar war. Ein direkt angegebenes Planhandle kann dagegen als Kandidat bestehen bleiben, obwohl sein Text oder Plan nicht mehr auflösbar ist. **NULL** bezeichnet nicht verfügbare Werte; Quellenstatus und isolierte Fehler stehen in den Planzeilen beziehungsweise im Modulstatus. Das JSON-Warningsarray bleibt leer. Fehler eines Handles werden je behaltenem Kandidat und aktivierter Quelle abgefangen. Der Modulstatus meldet `PARTIAL` und erhält den ersten tatsächlichen Fehler. Fehlerhafte Planquellen erhalten ausschließlich für den betroffenen Kandidaten `ERROR_HANDLED`; Attribute und Planwerte anderer Kandidaten bleiben erhalten. Schlägt die SQL-Textauflösung fehl, bleibt die rohe Kandidatenzeile mit NULL-Texten und NULL-Textmetriken sowie beiden Truncationbits auf false erhalten. Die Modulwarnung wird nach der Textauflösung und Unicodeprojektion ausgegeben. Eine feste Handlelänge dient nicht als Gültigkeitsprüfung. Negative Kandidaten- oder Textlimits liefern `INVALID_PARAMETER` und leere Fachmengen; gültige TABLE-Zuordnungen erhalten dabei ihre vollständigen angeforderten Schemas. Die frühere Ablehnung des negativen Textlimits durch den internen Projektionshelper wird verhindert, ohne den öffentlichen Parameterwert zu verändern.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Zielgerichtet und auf @MaxAnalyseobjekte begrenzt. Mehr als 20 Pläne prüft PLAN_CACHE_DEEP. Das Framework aktiviert keine Profilingoption.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Ohne Session/Handle/Hash entsteht keine Candidate-Zeile. Mit einem Selektor werden höchstens 20 Kandidaten ermittelt und standardmäßig Attribute, Compile-XML und auf 8000 Zeichen gekürzter SQL-Text je Kandidat geladen. |
| Teuerster Pfad | `@MaxAnalyseobjekte = 0` mit vollständigen Compile-, Text-, Last-Actual- oder Live-Plänen und ungekürztem SQL-Text. |
| Haupttreiber | Kandidatenzahl und Größe der angeforderten Planrepräsentationen. Sessionfilter liest aktive Requests, PlanHandle ist direkt, SQL-/QueryHash filtern `sys.dm_exec_query_stats`; danach entstehen planweise Attribute, Text und XML. |
| Skalierung | Detailaufrufe wachsen ungefähr mit Kandidaten × aktivierten Planquellen. Planattribute und SQL-Text werden je Candidate separat aufgelöst; große XML-Pläne erhöhen Speicher und Netzwerk, werden hier aber nicht in Operatorzeilen geschreddert. |
| Ressourcen | CPU und Speicher für Kandidaten-/Handleauflösung, Planattribute und optionale Compile-, Text-, Last-Actual- oder Live-Plan-XML; großer Transfer bei breiten Plänen. Die Procedure führt kein fachliches XML-Shredding in Operatorresultsets aus. |
| Begrenzungswirkung | `@MaxAnalyseobjekte` begrenzt Kandidaten vor der planweisen Detailauflösung; NULL und 0 bedeuten unbegrenzt und prüfen wie Werte über 20 `PLAN_CACHE_DEEP`. Attribute und aktivierte Planquellen bleiben je behaltenem Kandidat vollständig; das Kandidatenlimit ist keine gemeinsame Zeilengrenze dieser Detailarrays. Das SQL-Textzeichenlimit begrenzt Statement- und Batchtext; NULL und 0 erhalten beide vollständig. Einen separaten Ergebniszeilen- oder Deadlineparameter besitzt diese Procedure nicht. |
| Locking und Nebenwirkungen | Keine Nutzdatenänderung; Live-Plan-Zugriff beobachtet aktive Requests und Cachehandles können verschwinden. XML-Auswertung kann Schedulerzeit verbrauchen. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `PLAN_CACHE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Genau einen `ExampleQueryHash`/PlanHandle oder eine synthetische Session, maximal fünf Candidates und zunächst nur Compile-Plan. Last-Actual/Live separat und bewusst anfordern; einen `VOLL`-Modus gibt es nicht. |
| Aussagegrenze | Ein Planhandle kann zwischen Candidate- und Detailauflösung verschwinden. Die Last-Actual-Quelle wird anhand ihres tatsächlichen DMV-Ergebnisses bewertet; ein Konfigurationsschalter allein belegt weder NULL noch verfügbares XML; Live zeigt den laufenden Zeitpunkt. Fehlendes XML bedeutet deshalb nicht „kein Plan“ und Candidate-TOP keine repräsentative Planmenge. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Attribute, Texte, Statements und Planinformationen gehören zu einem konkreten Handle?

### Technischer Hintergrund

SQL-/Planhandles referenzieren flüchtige Cacheobjekte. Plan Attributes enthalten DBID, Set Options, User-/Languagekontext und weitere Cachekeyeinflüsse. Unterschiedliche SET Options können separate Pläne derselben Textform erzeugen.

### Datenkette

`sys.dm_exec_plan_attributes`, `sys.dm_exec_query_plan`, `sys.dm_exec_query_plan_stats`, `sys.dm_exec_query_statistics_xml`, `sys.dm_exec_query_stats`, `sys.dm_exec_requests`, `sys.dm_exec_sql_text`, `sys.dm_exec_text_query_plan`.

### Source Select

Ein exaktes Plan-Handle vermeidet eine breite Cache-Suche und verbindet Planinhalt mit ausgewählten Planattributen:

```sql
SELECT
      [qp].[query_plan]
    , [pa].[attribute]
    , [pa].[value]
FROM [sys].[dm_exec_query_plan](@PlanHandle) AS [qp]
CROSS APPLY [sys].[dm_exec_plan_attributes](@PlanHandle) AS [pa]
WHERE [pa].[attribute] IN (N'dbid', N'objectid', N'set_options');
```

**Wichtig für die Eigenlast:** Geben Sie Handle oder Session vor Planbeschaffung eindeutig an. Last-Actual- und Live-Planquellen nur gezielt aktivieren; XML und vollständiger SQL-Text können Transfer und Speicher deutlich erhöhen.

### Zeit- und Scope-Modell

Die Auswertung liefert eine Momentaufnahme eines Cacheeintrags. Das Handle kann zwischen Auswahl und Detailabruf aus dem Cache entfernt werden.

### Bewertung und Gegenprobe

Berücksichtigen Sie Plan Attributes, Statementoffset, Creation/Last Execution, Use Count und XML gemeinsam. Set-Option-Unterschiede können scheinbare Planverdoppelung erklären.

### Typische Fehlinterpretation

Ein Handle ist keine persistente Referenz und darf nicht langfristig gespeichert werden, ohne Gültigkeitsprüfung.

### Folgeanalyse

Verwenden Sie für die weitere Analyse `USP_ShowplanAnalysis` und Query-Store-IDs für eine dauerhaftere Korrelation.

## Primärquellen

- [sys.dm_exec_query_plan](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-exec-query-plan-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../04_Plan_Cache.md#4-monitorusp_plandetails)
`USP_PlanDetails` bleibt die native Plan-/Attributansicht. Für normalisierte
Warnungs-, Optimizer-, Runtime-, Query-Store- und Variantenresultsets reichen
Sie das ausgewählte Planhandle anschließend an `USP_ExecutionPlanAnalysis`
weiter; die Detailprocedure führt keine konkurrierende XML-Zerlegung aus.

