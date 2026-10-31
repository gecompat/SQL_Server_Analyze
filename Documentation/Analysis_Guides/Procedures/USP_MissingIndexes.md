# [monitor].[USP_MissingIndexes]

**Bereich:** Object und Index<br>
**Zweck:** Priorisiert flüchtige Missing-Index-Evidenz und erzeugt einen ausdrücklich unverbindlichen DDL-Entwurf.<br>
**Beobachtungsart:** kumulativ seit Struktur-/Instanzreset<br>
**Kostenklasse:** LOW–MEDIUM

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche zusätzlichen Nonclustered-Indexstrukturen hat der Optimizer während Kompilierungen als potenziell kostensenkend eingeschätzt?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_MissingIndexes]
      @DatabaseNames = N'[ExampleDatabase]',
      @MinUserReads = 10,
      @ResultSetArt = 'RAW';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt. |
| `@HighImpactConfirmed` | `bit` | `0` | SQL-bit-Schalter mit 0 oder 1; von 0 verschiedene konvertierbare Zahlen werden beim Binden 1. MISSING_INDEX_CURRENT verlangt laut Klassenkatalog kein Gruppengate: 0 und 1 aktivieren keinen weiteren Analysepfad und ändern den Scope nicht. NULL wird im normalen Datenbankauswahlpfad als INVALID_PARAMETER abgewiesen. Der Schalter vergibt keine SQL-Rechte. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Schemanamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @SchemaNames kombinieren. Übergabe zum Beispiel N'like:App%'. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Objektnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @ObjectNames kombinieren. Übergabe zum Beispiel N'like:App%'. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. |
| `@MinUserReads` | `bigint` | `1` | Nichtnegative ganze Zahl von 0 bis 9223372036854775807; SQL-bigint-Eingabe. Filtert auf user_seeks + user_scans je Missing-Index-Gruppe. Negative Werte sind INVALID_PARAMETER. NULL passiert den negativen Wertecheck als UNKNOWN; der anschließende Vergleich liefert dann keine Treffer. Der Default 1 verlangt mindestens einen Read-Hinweis. |
| `@MinAvgUserImpact` | `decimal(9,2)` | `0` | Dezimaler Mindestwert für den vom Optimizer geschätzten avg_user_impact in Prozent, zulässig 0.00 bis 100.00 einschließlich. Die Bindung an decimal(9,2) rundet vor der Fachprüfung auf zwei Nachkommastellen. Außerhalb des zulässigen Bereichs: INVALID_PARAMETER. NULL passiert die Bereichsprüfung als UNKNOWN, liefert aber im nachfolgenden Vergleich keine Treffer. Dies ist keine gemessene Einsparung. |
| `@MinImprovementMeasure` | `decimal(28,2)` | `0` | Nichtnegative Dezimalzahl von 0.00 bis 99999999999999999999999999.99; Bindung an decimal(28,2) mit Rundung auf zwei Nachkommastellen vor der Fachprüfung. Filtert auf avg_total_user_cost * avg_user_impact * (user_seeks + user_scans), ohne Division durch 100. Die Formel ist eine Priorisierungsmetrik ohne Zeit- oder Geldeinheit; gefiltert wird ihr ungerundeter Ausdruck, ausgegeben die decimal(28,2)-Projektion. Negative Werte sind INVALID_PARAMETER; NULL passiert den negativen Wertecheck, liefert aber keine Treffer. |
| `@MaxZeilen` | `int` | `5000` | Nichtnegative ganze Zahl von 0 bis 2147483647. NULL oder 0 wird intern zur bigint-TOP-Grenze 9223372036854775807. Negative Werte sind INVALID_PARAMETER. TOP gilt getrennt je Datenbank nach den Filtern, geordnet nach dem ungerundeten Improvement-Ausdruck absteigend; Gleichstände haben keinen zugesicherten Tie-Breaker. Die Endausgabe ordnet zusätzlich nach Datenbank, Schema und Objekt. Keine globale Zeilengrenze und kein Limit der vorausgehenden DMV-/Joinarbeit. |
| `@LockTimeoutMs` | `int` | `0` | Wartezeit als nicht-NULL int von 0 bis 60000 Millisekunden. 0 setzt NOWAIT; positive Werte werden im dynamischen Fachbatch als SET LOCK_TIMEOUT übernommen. Werte außerhalb sind INVALID_PARAMETER. NULL passiert den Bereichstest als UNKNOWN, macht den verketteten SQL-Text aber NULL statt des vorgesehenen Fachbatches. Vor der Datenbankschleife setzt die Procedure LOCK_TIMEOUT 0. Für einen regulären Fachaufruf einen konkreten Wert von 0 bis 60000 übergeben; ein bestimmter Fehlerstatus für das NULL-Statement wird hier nicht zugesichert. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Missing-Index-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: missingIndexes als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"missingIndexes":"#IndexHelpTarget"}'. |
| `@JsonErzeugen` | `bit` | `0` | bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, missingIndexes und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, missingIndexes und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück. |
| `@PrintMeldungen` | `bit` | `1` | bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung. |
| `@Hilfe` | `bit` | `0` | bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht. |

Die folgenden Aufrufe verwenden ausschließlich synthetische Namen. RAW erhält den Modul- und Datenbankstatus.

```sql
EXEC [monitor].[USP_MissingIndexes] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';

DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_MissingIndexes] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;

CREATE TABLE #MissingIndexes_HelpExample([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_MissingIndexes] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"missingIndexes":"#MissingIndexes_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE #MissingIndexes_HelpExample;
    THROW;
END CATCH;
DROP TABLE #MissingIndexes_HelpExample;

EXEC [monitor].[USP_MissingIndexes] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `missingIndexes`. RAW liefert zuerst Modul- und Datenbankstatus, danach das Fachresultset. CONSOLE liefert nur die Fachdaten; TABLE exportiert ausschließlich missingIndexes. JSON enthält meta, missingIndexes und databaseStatus. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Missing-Index-Gruppe aus den Optimizer-DMVs, nicht einem fertig geprüften Indexdesign.

## So lesen

Prüfen Sie zuerst Reads und Compiles und danach Impact und Improvement Measure. Vergleichen Sie Schlüssel und Includes mit vorhandenen Indizes.

## Warum kann das problematisch sein?

Der Optimizer sieht mögliche Lesekosten, aber nicht vollständig Schreiblast, Speicher, Wartung, Redundanz und fachliche Abhängigkeiten.

## Wann ist es kein Problem?

98 % Impact bei zwei Reads ist plakativ, aber schwach. Ein ähnlicher vorhandener Index kann den Vorschlag überflüssig machen.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 25 % Impact bei fünf Millionen Reads kann mehr Gesamtnutzen besitzen als 99 % bei einer Ausführung. Prüfen Sie vor DDL immer Inventar, Usage, Querytext, Plan und Write-Last.

**Ähnlich aussehender Gegenfall:** 98 % Impact bei zwei Reads ist plakativ, aber schwach. Ein ähnlicher vorhandener Index kann den Vorschlag überflüssig machen. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_MissingIndexes` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

Missing-Index-DMVs sind flüchtig und begrenzt. Leer kann Reset, fehlende Compiles oder nicht geeignete Queries bedeuten.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** TOP begrenzt die sortierte Ausgabe je Datenbank. Das Ergebnislimit begrenzt die vorherige DMV-Korrelation und Join-/Sortierarbeit nicht verbindlich.

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

**Wichtig für die Eigenlast:** Filtern Sie Datenbank und Mindestnutzung vor der Objekt- und Schemaauflösung sowie dem DDL-Entwurf. Die DMVs bleiben serverweit flüchtig; ein `TOP` nach der Bewertung reduziert nicht die zugrunde liegende DMV-Menge.

### Zeit- und Scope-Modell

Die Daten sind seit einem Neustart oder Reset flüchtig beziehungsweise kumulativ und auf eine begrenzte Anzahl gespeicherter Gruppen beschränkt. Vorschläge können nach Änderungen am Plan Cache oder an Metadaten verschwinden.

### Bewertung und Gegenprobe

Prüfen Sie Queryhäufigkeit, Kosten, tatsächliche Reads, vorhandene Präfixe und Includes, Selectivity, DML-Kosten, Speicher und Locking. Konsolidieren Sie mehrere Vorschläge nach fachlicher Prüfung zu einem tragfähigen Indexdesign.

### Typische Fehlinterpretation

Ein hoher Improvement-Wert ist keine gemessene Einsparung. Der Vorschlag kennt Write Amplification, andere Queries, Filtered Indexes und vollständige Datenverteilung nur begrenzt.

### Folgeanalyse

Verwenden Sie für die weitere Analyse die betroffenen Pläne, Query Store, `USP_ObjectInventory` und `USP_IndexUsage`. Führen Sie DDL nur nach einem Test und mit einem Rollbackplan aus.

## Primärquellen

- [Missing-Index-DMVs](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/tune-nonclustered-missing-index-suggestions?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#4-monitorusp_missingindexes)
