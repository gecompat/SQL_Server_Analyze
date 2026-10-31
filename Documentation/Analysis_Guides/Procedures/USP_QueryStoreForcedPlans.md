# [monitor].[USP_QueryStoreForcedPlans]

**Bereich:** Query Store<br>
**Zweck:** Inventarisiert erzwungene Pläne und Plan-Forcing-Fehler.<br>
**Beobachtungsart:** persistierter Konfigurationsstand + Planhistorie<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Pläne werden erzwungen, funktionieren sie technisch und sind sie noch betrieblich begründet?** Sie unterstützt die Entscheidung, ob persistierte Query-Store-Evidenz eine zeitlich belastbare Abweichung zeigt und welcher Query-/Plan-Scope danach gezielt geprüft wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine Ausführungen außerhalb Capture und Retention sowie keinen Beweis, dass ein beobachteter Planwechsel allein die Auswirkung verursacht hat. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

`EXEC [monitor].[USP_QueryStoreForcedPlans] @Hilfe = 1;` beschreibt alle Parameter, Filter- und Ausgabeoptionen sowie Beispielaufrufe direkt in der Procedure.

```sql
EXEC [monitor].[USP_QueryStoreForcedPlans]
      @QueryStoreDatabaseNames = N'[ExampleDatabase]',
      @NurMitFehler = 0,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@QueryStoreDatabaseNames` | `nvarchar(max)` | `NULL` | Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]&#124;[OtherDatabase]'; &#124; trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen. |
| `@QueryStoreDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert. |
| `@HighImpactConfirmed` | `bit` | `0` | ausgelassen/0 = nicht bestätigt. NULL ist im Datenbankhelfer INVALID_PARAMETER. 1 bestätigt nur ein aktiviertes Gruppengate: QUERY_STORE_CURRENT hat kein Gruppengate, QUERY_STORE_DEEP verwendet es. Die Bestätigung ändert keinen Scope und erteilt weder SQL-Berechtigung noch Gruppenmitgliedschaft. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@ReferencedDatabaseNames` | `nvarchar(max)` | `NULL` | ausgelassen/NULL kein Showplan-Referenzfilter. Sonst nichtleere bracket-aware Pipe-Liste einteiliger SQL-Namen; &#124; trennt außerhalb von [...], ]] maskiert ]. Leerwert/Leerzeichen ungültig. Teil 1 muss nicht NULL, Teil 2 NULL und LEN(Teil 1) höchstens 128 sein; Teile 3/4 werden nicht gesondert geprüft. Gültige Namen werden mit expliziter Framework-Collation SQL_Latin1_General_CP1_CS_AS verglichen. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Exklusiv mit @ReferencedDatabaseNamePattern; setzt QUERY_STORE_DEEP voraus. |
| `@ReferencedDatabaseNamePattern` | `nvarchar(4000)` | `NULL` | ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung. Ohne Präfix LIKE; Rest wird nicht erneut getrimmt; leer/leer nach Präfix ungültig. Exklusiv mit @ReferencedDatabaseNames; setzt QUERY_STORE_DEEP voraus. REGEX/REGEXI laufen je Quelldatenbank und benötigen SQL Server 2025 sowie CL170 dort; Syntax wird nicht vorab validiert. |
| `@QueryId` | `bigint` | `NULL` | Ausgelassen/NULL: kein Query-ID-Filter. Einen ganzzahligen bigint-Wert von -9223372036854775808 bis 9223372036854775807 übergeben; keine zusätzliche Positivitäts- oder Existenzprüfung. Exakter Vergleich je Quelle; Query-IDs sind quellenspezifisch. |
| `@NurMitFehler` | `bit` | `0` | Weglassen ergibt 0. Numerisches 0 wird zu 0, jeder numerische Nichtnullwert zu 1. 0 zeigt alle als erzwungen markierten Pläne; 1 beschränkt auf ForceFailureCount &gt; 0 oder LastForceFailureReason &lt;&gt; 0. NULL ist nicht als 0 behandelt und lässt durch SQL-NULL-Semantik praktisch nur Zeilen mit erfüllter Fehlerbedingung passieren. |
| `@MitPlanXml` | `bit` | `0` | Ausgelassen/0: keine exportierte Plan-XML und kein XML-Parsing; QueryPlanStatus ist NOT_REQUESTED. 1 aktiviert Ausgabe und Parsing des gespeicherten historischen Query-Store-Plans für alle lokal gesammelten Kandidaten vor dem globalen Limit und löst Deep aus; kein aktueller Laufzeitplan. NULL aktiviert weder Ausgabe/Parsing noch allein Deep, hat aber PENDING statt NOT_REQUESTED. Referenzfilter können Plan-XML unabhängig vom Ausgabeschalter lesen. Ungültiges XML bleibt als Rohtext mit Fehler-/Partialhinweis erhalten. Als bit 0/1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. |
| `@MaxZeilen` | `int` | `100` | Weglassen ergibt globales Exportlimit 100. NULL oder 0 bedeutet unbegrenzt; positive Werte sind das globale Ausgabelimit. Negative Werte sind im normalen Aufruf ungültig. Je Datenbank wird lokal mit N+1 (bei int-Maximum höchstens int-Maximum) gelesen und die gemeinsame Menge anschließend global begrenzt; es handelt sich nicht um ein globales TOP im Quellzugriff. Ein normalisiertes Limit über 1000, auch NULL/0, aktiviert den Deep-Check. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben. Lokales und globales Ranking stellen Pläne mit LastForceFailureReason ungleich 0 voran, danach LastExecutionTimeUtc absteigend. ForceFailureCount ist kein Sortierschlüssel; Sortties garantieren keine bestimmte Auswahl. Textprojektion, XML-Parsing, Warnungen und Zähler betreffen alle lokalen Kandidaten vor dem globalen Limit. |
| `@MaxSqlTextZeichen` | `int` | `4000` | Weglassen begrenzt den projizierten Query-Text auf 4000 Zeichen. NULL oder 0 bedeutet unbegrenzt; ein positiver Wert ist die Unicode-sichere Zeichengrenze. Negative Werte sind im normalen Aufruf ungültig. Bei Kürzung kann abhängig von @PrintMeldungen eine Truncationwarnung erscheinen; die Grenze beschränkt die Ausgabeprojektion, nicht die Quellabfrage. Als ganze Zahl im SQL-int-Bereich bis 2147483647 übergeben. SC-Collation zählt ein Surrogatpaar als ein Zeichen; keine Graphemzählung, keine Kürzung des Plan-XML. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung sind genau vier Werte erlaubt: RAW liefert drei Resultsets (Metadaten, forcedPlans, Warnungen); CONSOLE liefert die fachliche Exportmenge mit Ergebnislabel oder bei Leere eine Hinweiszeile, ohne zusätzliche Metadaten-/Warnungsgrids; TABLE schreibt nur forcedPlans ins geprüfte lokale Temp-Ziel; NONE unterdrückt normale Fachresultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen und andere Werte sind im normalen Analysepfad ungültig. Der TABLE-Preflight liegt vor Hilfe und Fachvalidierung. Der Eingabewert unterliegt der varchar(16)-Bindungsbreite. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | außerhalb TABLE nur NULL, leer oder Leerzeichen zulässig; anderer nichtleerer Inhalt wirft 51011. Bei TABLE nichtleeres JSON-Objekt mit genau dem Schlüssel forcedPlans und einem Ziel. Ziel: vorhandene, leere lokale #Temp-Tabelle (kein ##), maximal 116 Zeichen und genau eine beliebige Seed-Spalte; das volle Ergebnis-Schema muss nicht angelegt werden. Fehlendes/ungültiges Mapping/Ziel wird im frühen Preflight abgelehnt; leerer Wert ist in TABLE ungültig. Schlüssel binär exakt und ohne Duplikate; Ziele dürfen weder ## noch das reservierte #Monitor-Präfix verwenden. Ein Seed-Datensatz ist nicht zulässig; der Writer ersetzt die Seed-Struktur durch das Ergebnisschema. |
| `@JsonErzeugen` | `bit` | `0` | Weglassen ergibt 0; numerisches 0 wird 0, jeder numerische Nichtnullwert wird zu 1. NULL aktiviert JSON nicht. Bei 1 wird das JSON-Objekt mit meta, forcedPlans und warnings erzeugt; dies ist unabhängig von @ResultSetArt. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Parameter. Zum Empfang nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Beim Eintritt auf NULL gesetzt und nur bei @JsonErzeugen=1 gefüllt; bei Hilfe bleibt es NULL. Ausgelassen gilt der Vorgabewert, das Ergebnis ist dann nicht abrufbar. Leerwert als Eingabe wird nicht ausgewertet. Bei ungefangenem THROW besteht keine Zusage einer OUTPUT-Rückübertragung. |
| `@PrintMeldungen` | `bit` | `1` | ausgelassen lässt Meldungen zu. 1 erlaubt Fehlerhinweise und die Truncationwarnung; 0 unterdrückt diese Meldungen. NULL unterdrückt die Truncationwarnung und erfüllt die direkte Fehlerausgabebedingung nicht. Status, Resultsets und Datenmenge bleiben davon unberührt. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |
| `@Hilfe` | `bit` | `0` | ausgelassen/NULL führt normal aus. Nur 1 druckt die Hilfe und beendet vor normaler Parameter- und Datenvalidierung. Rohe SQL-Bindung und früher TABLE-Mapping-Preflight bleiben aktiv und können vorher scheitern; @Json wurde beim Eintritt geleert. Als bit 0 oder 1 übergeben; SQL-Typkonvertierung kann andere numerische Nichtnullwerte auf 1 abbilden. |

```sql
EXEC [monitor].[USP_QueryStoreForcedPlans] @Hilfe=1;
```

```sql
EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';
```

```sql
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
```

```sql
CREATE TABLE [#QueryStoreForcedPlans_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreForcedPlans] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"forcedPlans":"#QueryStoreForcedPlans_HelpExample"}';
 SELECT * FROM [#QueryStoreForcedPlans_HelpExample];
 DROP TABLE IF EXISTS [#QueryStoreForcedPlans_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreForcedPlans_HelpExample];
 THROW;
END CATCH;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `forcedPlans`. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

RAW, CONSOLE, TABLE und JSON verwenden dieselbe global begrenzte `forcedPlans`-Menge mit 32 Feldern und zwölf explizit `SQL_Latin1_General_CP1_CS_AS` collatierten Textspalten. `QueryStoreDatabaseName` bleibt NOT NULL; die übrigen 31 Felder sind nullable, keine Spalte ist eine Identity. `@MaxZeilen` mit NULL oder 0 bedeutet unbegrenzt. Die Reihenfolge priorisiert einen von null verschiedenen `LastForceFailureReason` und danach `LastExecutionTimeUtc` absteigend; bei gleichen Sortwerten ist die Auswahl nicht eindeutig.

Die Sammlung wird weiterhin lokal mit TOP N+1 begrenzt und vor der globalen Ausgabe bewertet. `hasMoreRows`, Gesamtstatus und Truncationwarnungen beziehen sich auf diese vollständige Sammlung, nicht nur auf den ausgegebenen Ausschnitt. Die Procedure erzeugt keine zusätzliche Auswahlwarning für eine fehlende Datenbank. Bestehende Analyseklassen und deren Freigaben gelten auch für NULL/0-Limits und Plan-XML.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Query-Store-Plan mit Forcingmetadaten.

## So lesen

Berücksichtigen Sie `IsForcedPlan`, Forcing Type, Failure Count/Reason, letzte Ausführung, Engineversion und Compatibility gemeinsam.

## Warum kann das problematisch sein?

Force-Fehler bedeuten, dass die gewünschte Bindung nicht zuverlässig angewendet wird. Ein alter Forced Plan kann neue Optimizerverbesserungen verhindern.

## Wann ist es kein Problem?

Ein fehlerfrei erzwungener Plan mit stabiler Performance kann bewusste Risikokontrolle sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 50 Force-Fehler plus aktuelle Regression ist dringender als ein stabiler alter Forced Plan ohne Fehler. Prüfen Sie Runtimevergleich, Plan Changes und Rücknahmepfad.

**Ähnlich aussehender Gegenfall:** Ein fehlerfrei erzwungener Plan mit stabiler Performance kann bewusste Risikokontrolle sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Eine leere Ausgabe kann trotz nutzbarem Query Store entstehen, wenn kein sichtbarer Plan als forced markiert ist oder die gewählten Query-/Fehler-/Referenzfilter keinen Treffer zulassen. Diese Procedure besitzt keinen Zeitfensterparameter; prüfen Sie Forcingstatus, Quellenauswahl, Berechtigungen und Warnungen.

Für `USP_QueryStoreForcedPlans` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Ohne Datenbankfilter werden alle sichtbaren geeigneten Online-Benutzerdatenbanken geprüft; TOP 100, gekürzter SQL-Text und kein Plan-XML. Inventarisiert werden ausschließlich aktuell als forced markierte Pläne. Der sichere Beispielaufruf begrenzt auf `ExampleDatabase`. |
| Teuerster Pfad | Viele Datenbanken, unbegrenztes/hohes Limit, vollständiger SQL-Text, Plan XML und Referenzdatenbank-/Regexfilter. Einen Zeitfensterparameter besitzt die Procedure nicht. |
| Haupttreiber | Zahl gewählter Query Stores und aktuell forced markierter Pläne samt Querytext. Volltext, Plan-XML, Regex und Referenzdatenbankfilter verbreitern beziehungsweise verteuern jeden Kandidaten; ein Zeitfenster existiert nicht. |
| Skalierung | Aufwand wächst mit Query-Store-Plan-/Queryzeilen und ausgewählten Datenbanken; Plan-/Textbreite sowie Referenz-XML-Parsing können CPU, Speicher und Transfer dominieren. |
| Ressourcen | Query-Store-I/O und CPU für Plan-/Query-/Textjoin und Ranking; optional Plan-XML-Materialisierung beziehungsweise XML-Shredding. Keine Fensteraggregation. |
| Begrenzungswirkung | QueryId und `@NurMitFehler` wirken vor dem lokalen TOP N+1. Das Limit ist lokal mit N+1 und anschließend global für alle vier Ausgabearten, verhindert aber Referenz-XML-Prüfung der zu betrachtenden Forced-Plan-Zeilen nicht zuverlässig. Textzeichen begrenzen nur Ausgabegröße. |
| Locking und Nebenwirkungen | Read-only gegenüber Query Store; normale interne Synchronisation/Schema-Stability ist möglich. Die Procedure erzwingt, entfernt oder bereinigt keine Pläne/Hints. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `QUERY_STORE_CURRENT`, `QUERY_STORE_DEEP`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, `@NurMitFehler = 1`, TOP 100 und kein Plan XML. Plan XML, Referenzfilter oder >1000/unbegrenzt nur nach `QUERY_STORE_DEEP`. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „persistierter Konfigurationsstand + Planhistorie“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Pläne werden erzwungen, funktionieren sie technisch und sind sie noch betrieblich begründet?

### Technischer Hintergrund

Query Store Plan Forcing beeinflusst die Planwahl über gespeicherte Planrepräsentation. Metadaten enthalten Forcing Type, Failure Count/Reason, Compile-/Executionzeit und Version. Schema-/Index-/Engineänderungen können Forcing verhindern oder seine Qualität verändern.

### Datenkette

`sys.database_query_store_options`, `sys.objects`, `sys.query_store_plan`, `sys.query_store_query`, `sys.query_store_query_text`, `sys.schemas`, `sys.sp_executesql`.

### Source Select

Forced Plans werden über Plan, Query und Query Text verbunden; der Force-Status ist das frühe Fachprädikat:

```sql
SELECT
      [p].[plan_id]
    , [p].[query_id]
    , [p].[is_forced_plan]
    , [p].[force_failure_count]
    , [p].[last_force_failure_reason_desc]
    , [q].[object_id]
    , [qt].[query_sql_text]
FROM [sys].[query_store_plan] AS [p] WITH (NOLOCK)
JOIN [sys].[query_store_query] AS [q] WITH (NOLOCK)
  ON [q].[query_id] = [p].[query_id]
JOIN [sys].[query_store_query_text] AS [qt] WITH (NOLOCK)
  ON [qt].[query_text_id] = [q].[query_text_id]
WHERE [p].[is_forced_plan] = 1;
```

**Wichtig für die Eigenlast:** Datenbank und Forced-Status vor SQL-Text und Plan-XML anwenden. Vollständiges XML nur für einzelne `plan_id`-Kandidaten lesen; die Inventarisierung benötigt es nicht.

### Zeit- und Scope-Modell

Exakte `@ReferencedDatabaseNames` werden mit dem Parser der Frameworkdatenbank geprüft und in den dynamischen Quellabfragen über dessen dreigliedrigen Namen aufgelöst. Der Frameworkname wird vor `USE` aus `master.sys.databases` mit `NOLOCK` gelesen und mit `QUOTENAME` geschützt. Die Liste filtert Datenbankreferenzen im Showplan, nicht die Query-Store-Quelldatenbanken. `NULL` lässt diesen Referenzfilter weg; eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Gültige doppelte Namen bleiben erlaubt und vervielfachen wegen `EXISTS` keine Zeilen. Die dekodierten XML-Namen werden weiterhin mit der expliziten Framework-CS-Collation verglichen; LIKE- und Regexpfade behalten ihre bisherigen Verträge.

Die Auswertung beschreibt den aktuellen Forcingstatus sowie den persistierten Planlebenszyklus.

### Bewertung und Gegenprobe

Prüfen Sie Fehler, letzte Nutzung, Runtime im Vergleich zu Alternativen, Engine-/Compatibilitywechsel und Owner/Reviewdatum. Stabilität kann wichtiger als minimaler Durchschnitt sein.

### Typische Fehlinterpretation

`IsForcedPlan=1` beweist nicht, dass der Plan aktuell benutzt oder optimal ist. Ein Fehlerzähler von `0` bedeutet, dass im sichtbaren Metadatenstand keine entsprechenden Force-Fehler gezählt sind; daraus folgen weder die tatsächliche aktuelle Nutzung noch fachlicher Nutzen.

### Folgeanalyse

Verwenden Sie für die weitere Analyse Runtime, Regressions und PlanChanges. Nehmen Sie eine Änderung nur mit einem Rollback- und Monitoringplan vor.

## Primärquellen

- [Query Store: Überwachung und Auswertung](https://learn.microsoft.com/en-us/sql/relational-databases/performance/monitoring-performance-by-using-the-query-store?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [SQL Server First Responder Kit – ergänzende, quelloffene Praxiswerkzeuge für Triage](https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit)

[Technische Detailbeschreibung](../05_Query_Store.md#6-monitorusp_querystoreforcedplans)
