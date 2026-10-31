# [monitor].[USP_ObjectInventory]

**Bereich:** Object und Index<br>
**Zweck:** Liefert Objekt- und Indexinventar mit Größe, Zeilen, Partitionierung, Kompression, Definition und capability-adaptiven JSON-Index-/Pfadmetadaten.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche Objekte und physischen Zugriffsstrukturen existieren, wie groß sind sie und welche Eigenschaften besitzen sie?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ObjectInventory]
      @DatabaseNames = N'[ExampleDatabase]',
      @SchemaNames = N'[ExampleSchema]',
      @ObjectNames = N'[ExampleTable]',
      @ResultSetArt = 'RAW';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt. |
| `@HighImpactConfirmed` | `bit` | `0` | bit-Bestätigung für den VOLL-Pfad CATALOG_DEEP, der erst nach OBJECT_ANALYSIS_CURRENT aktiviert wird: 0 bestätigt den Deep-Pfad nicht; 1 erfüllt die Bestätigungsanforderung, erteilt selbst aber keine Berechtigung. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. GEZIELT nutzt OBJECT_ANALYSIS_CURRENT und verlangt diese Bestätigung nicht. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Schemanamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @SchemaNames kombinieren. Übergabe zum Beispiel N'like:App%'. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Objektnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @ObjectNames kombinieren. Übergabe zum Beispiel N'like:App%'. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. |
| `@ObjectType` | `varchar(16)` | `'TABLE'` | Wählen Sie TABLE für Benutzertabellen, VIEW für Sichten oder ALLE für beide Objektarten. Der Wert wird mit LTRIM/RTRIM und UPPER normalisiert; Groß-/Kleinschreibung und äußere Leerzeichen ändern die Auswahl nicht. NULL wird vor der Prüfung zu TABLE. Ein leerer oder anderer Wert führt zu INVALID_PARAMETER. |
| `@AnalyseModus` | `varchar(16)` | `'GEZIELT'` | GEZIELT analysiert einen durch exakte Namenslisten, @FullObjectNames oder ein Schema-/Objekt-Pattern begrenzten Scope; mindestens eine solche Objektbegrenzung muss vorhanden sein. VOLL wählt den Katalogpfad und prüft zusätzlich die Freigabe CATALOG_DEEP. Der Wert wird getrimmt und in Großbuchstaben umgewandelt; NULL wird zu GEZIELT, GEZIELT und VOLL sind die einzigen gültigen Werte. Leertext und andere Werte führen zu INVALID_PARAMETER. VOLL ohne Freigabe wird abgewiesen. VOLL erfordert außerdem ausdrücklich @HighImpactConfirmed=1; eine Bestätigung ersetzt keine Gruppen- oder SQL-Berechtigung. |
| `@MitIndizes` | `bit` | `1` | 1 gibt Indexdetails aus; bei Tabellen entstehen dadurch grundsätzlich Zeilen je Index, und Index- sowie JSON-Indexfelder werden befüllt, soweit ihre Quellen verfügbar sind. 0 unterdrückt Indexdetails und liefert je Objekt eine Summenzeile mit den Objektgesamtwerten; Index- und JSON-Indexfelder bleiben NULL. Für bit-Eingaben sind 0 und 1 die Schalterwerte. NULL wird nicht auf einen Schalterwert normalisiert: Der Index-Join wird dadurch nicht aktiviert; Tabellenzeilen erfüllen anschließend den Filter nicht, Views können ihn erfüllen, während ihre Indexdetails NULL bleiben. Binden Sie deshalb ausdrücklich 0 oder 1. Numerisch 0 bleibt beim Binden 0; von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1. |
| `@MitSpaltenlisten` | `bit` | `1` | 1 ergänzt bei angeforderten Indexdetails KeyColumns und IncludedColumns. Schlüsselspalten folgen key_ordinal und enthalten DESC für absteigende Schlüssel; Include-Spalten folgen index_column_id. 0 unterdrückt beide Listen. NULL wird nicht zu 0 oder 1 normalisiert und erfüllt die CASE-Bedingung nicht, daher bleiben die Listen NULL. Auch bei @MitIndizes=0 werden keine Spaltenlisten ausgegeben. Für bit-Eingaben sind 0 und 1 die Schalterwerte. Numerisch 0 bleibt beim Binden 0; von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1. |
| `@MaxZeilen` | `int` | `5000` | Nichtnegative ganze Zahl von 0 bis 2147483647. NULL oder 0 wird intern zur bigint-TOP-Grenze 9223372036854775807; negative Werte sind INVALID_PARAMETER. TOP begrenzt die Inventarzeilen je Datenbank, geordnet nach reservierten Objektseiten absteigend, danach ObjectId und IndexId. Die Endausgabe sortiert nach ObjectReservedMb absteigend, Datenbank, Schema, Objekt und IndexId. Keine globale Zeilengrenze und keine verlässliche Begrenzung der vorherigen Katalogaggregation. |
| `@LockTimeoutMs` | `int` | `0` | Ganzzahlige Millisekunden von 0 bis 60000; andere nicht-NULL-Werte sind INVALID_PARAMETER. Der dynamische Hauptbatch enthält SET LOCK_TIMEOUT und die Inventarabfrage im selben Batch: 0 wartet dort nicht auf Locks, positive Werte begrenzen das Warten. Separate JSON-Metadatenbatches beginnen mit USE und enthalten diesen SET-Befehl nicht. Der Code speichert den Eingangswert und baut vor beziehungsweise nach der Sammlung eigene SET-/Restore-Batches; SET-Änderungen gelten nach den SQL-Server-Regeln im jeweiligen Prozedur-/dynamischen Batch-Scope und werden bei dessen Rückkehr zurückgenommen. Aus den separaten Hilfsbatches folgt keine übergreifende Timeout-Steuerung der JSON-Metadaten. Hilfe kehrt vor diesen eigenen SET-/Restore-Blöcken zurück. NULL passiert den Bereichstest als UNKNOWN und erzeugt durch Verkettung NULL statt des SET- beziehungsweise Hauptbatches; ein Fehler- oder No-op-Verhalten des NULL-Statements wird daraus nicht behauptet. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Objektinventar-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: objects als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"objects":"#IndexHelpTarget"}'. |
| `@JsonErzeugen` | `bit` | `0` | bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, objects und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, objects und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück. |
| `@PrintMeldungen` | `bit` | `1` | bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung. |
| `@Hilfe` | `bit` | `0` | bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht. |

Die folgenden Aufrufe verwenden synthetische Namen und beginnen mit einem einzelnen Objekt. RAW erhält den Modul- und Datenbankstatus.

```sql
EXEC [monitor].[USP_ObjectInventory] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';

DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_ObjectInventory] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;

CREATE TABLE #ObjectInventory_HelpExample([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_ObjectInventory] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"objects":"#ObjectInventory_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE #ObjectInventory_HelpExample;
    THROW;
END CATCH;
DROP TABLE #ObjectInventory_HelpExample;

EXEC [monitor].[USP_ObjectInventory] @Hilfe=1;
```

Zum Geltungsbereich der SET-Anweisungen: [Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-statements-transact-sql?view=sql-server-ver17).

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `objects`. RAW liefert zuerst Modul- und Datenbankstatus, danach die Fachzeilen. CONSOLE liefert ausschließlich die Fachdaten; TABLE exportiert nur objects. JSON enthält meta, objects und databaseStatus. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Auf SQL Server 2025 ergänzt `objects` die Felder `IsJsonIndex`,
`OptimizeForArraySearch`, `JsonPathCount`, `JsonPaths`,
`JsonIndexStatusCode` und `JsonIndexEvidenceLimit`. `databaseStatus` trennt
Version, Buildfähigkeit, Pflichtschema, Sichtbarkeit und behandelte
Quellenfehler. Vor SQL Server 2025 lautet der Status
`UNAVAILABLE_VERSION`; die beiden neuen Systemquellen werden dort nicht
referenziert.

## Eine Zeile bedeutet

Eine Inventarzeile beschreibt typischerweise eine Objekt-/Index-Kombination. Objektgesamtwerte können deshalb je Index wiederholt erscheinen.

## So lesen

Berücksichtigen Sie zuerst die Objektgröße und die Zeilenanzahl, danach Indexart, Schlüssel und Includes, Partitionierung, Kompression und Sonderzustände.

## Warum kann das problematisch sein?

Große deaktivierte, hypothetische oder redundante Indizes können Speicher- und Wartungskosten erzeugen. Die Definition allein beweist aber keine Entbehrlichkeit.

## Wann ist es kein Problem?

Gemischte Kompression oder ähnliche Indizes können Teil einer Hot-/Cold-, Constraint- oder Coverage-Strategie sein.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Zwei Indizes besitzen gleiche Schlüssel, aber einer sichert eine Unique Constraint. Er darf nicht wie ein normaler Duplikatindex behandelt werden. Prüfen Sie Usage, Operational Stats und Pläne.

**Ähnlich aussehender Gegenfall:** Gemischte Kompression oder ähnliche Indizes können Teil einer Hot-/Cold-, Constraint- oder Coverage-Strategie sein. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für JSON-Indizes bedeutet `AVAILABLE_EMPTY_OR_RESTRICTED`, dass im
angeforderten sichtbaren Scope keine Indexzeile entstand. Dieser Zustand
beweist wegen Metadata Visibility keine serverweite Featureabwesenheit.
`AVAILABLE_LIMITED` erhält eine sichtbare Indexdefinition, weist aber eine
fehlende, schemaabweichende oder nicht lesbare Pfadquelle ausdrücklich aus.

Für `USP_ObjectInventory` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Ein enger Datenbank-/Objektscope begrenzt die ausgegebenen Inventarzeilen. TOP wird je Datenbank angewandt und ist keine verlässliche Grenze der vorgelagerten Katalogaggregation oder Spaltenlistenarbeit.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine explizit benannte `ExampleDatabase` und ein Objekt im Modus `GEZIELT`; Indizes und Spaltenlisten bleiben auf diesen Kandidatenscope begrenzt. |
| Teuerster Pfad | Cross-Database-`VOLL`, `@MaxZeilen = 0`, alle Objekttypen sowie Index-/Spaltenlisten bei sehr vielen Objekten und Indexspalten. |
| Haupttreiber | Zahl gewählter Datenbanken und ausgegebener Objekte/Indizes sowie Partitionen, Indexspalten und Allocation Units. Der Quellcode formuliert Partitions- und Allocation-Unit-Aggregationen getrennt vom abschließenden Objektfilter; eine Begrenzung ihrer gesamten Arbeit durch Filter oder TOP ist nicht belegt. Definitionstexte und breite Cross-Database-Inventare erhöhen TempDB- und Transferbedarf. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_ObjectInventory ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU, Katalogseiten und TempDB für Joins/Aggregation; bei breitem Cross-Database-Scope zusätzlicher Compile- und Ergebnistransferaufwand. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen die Quellarbeit. TOP oder MaxZeilen werden häufig nach Katalogjoins und Aggregation angewandt und sind dann nur Ausgabelimits. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. Der dynamische Hauptbatch enthält den konfigurierten SET LOCK_TIMEOUT. Die separaten JSON-Metadatenbatches enthalten diesen SET-Befehl nicht; die eigenständigen SET-/Restore-Hilfsbatches belegen keine übergreifende Timeout-Steuerung. |
| Schutzmechanismus | `OBJECT_ANALYSIS_CURRENT` schützt den gezielten Pfad ohne High-Impact-Pflicht. Nur `VOLL` prüft zusätzlich `CATALOG_DEEP` und benötigt `@HighImpactConfirmed = 1`; das Gate ersetzt keine Objekt-/Datenbankgrenze. |
| Sicherer Einsatz | Mit einer ExampleDb und einem ExampleObject starten; erst nach Größenprüfung auf mehrere Datenbanken oder VOLL erweitern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Objekte und physischen Zugriffsstrukturen existieren, wie groß sind sie und welche Eigenschaften besitzen sie?

### Technischer Hintergrund

Tabellen, Views, Indizes, Spalten, Partitionen, Kompression und Allocation Units bilden mehrere Katalogebenen. Rowcount und reservierte/benutzte Seiten kommen typischerweise aus Partition Stats; Definition und Schutzmerkmale aus Objekt-/Indexkatalogen. Ein Unique Constraint oder Primary Key ist fachlich/relational geschützt, auch wenn ein Index technisch ähnlich zu einem anderen wirkt.

### Datenkette

`master.sys.databases`, `sys.allocation_units`, `sys.columns`, `sys.data_spaces`, `sys.index_columns`, `sys.indexes`, `sys.objects`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`, `sys.tables` sowie capability-abhängig `sys.json_indexes` und `sys.json_index_paths`.

Jede der beiden JSON-Quellen wird je Zieldatenbank und Procedureaufruf
höchstens einmal gelesen. Die Indexquelle bleibt auf den gewählten
Objektscope begrenzt; die Pfadquelle wird nur zu den bereits materialisierten
JSON-Indizes aggregiert. JSON-Dokumentwerte und Benutzertabellenzeilen werden
nicht gelesen.

### Source Select

Der Größenkern verbindet Objekt, Schema, Tabelle, Index, Partition und Allocation Unit:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [o].[name] AS [ObjectName]
    , [i].[name] AS [IndexName]
    , [p].[partition_number]
    , SUM([au].[total_pages]) * 8.0 / 1024.0 AS [ReservedMb]
FROM [sys].[objects] AS [o] WITH (NOLOCK)
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [o].[schema_id]
LEFT JOIN [sys].[indexes] AS [i] WITH (NOLOCK)
  ON [i].[object_id] = [o].[object_id]
LEFT JOIN [sys].[partitions] AS [p] WITH (NOLOCK)
  ON [p].[object_id] = [i].[object_id]
 AND [p].[index_id] = [i].[index_id]
LEFT JOIN [sys].[allocation_units] AS [au] WITH (NOLOCK)
  ON [au].[container_id] IN ([p].[hobt_id], [p].[partition_id])
WHERE [s].[name] = N'ExampleSchema'
  AND [o].[name] = N'ExampleObject'
GROUP BY [s].[name], [o].[name], [i].[name], [p].[partition_number];
```

**Wichtig für die Eigenlast:** Filtern Sie Schema und Objekt vor Partitionen, Allocation Units, Spalten und Indexspalten. Summieren Sie wegen mehrerer Allocation Units niemals ungeprüft Zeilen- oder Größenwerte über verschiedene Granularitäten.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Metadaten- und Größenstand. Rowcounts aus DMVs sind für Diagnosezwecke geeignet, aber keine transaktional exakte `COUNT_BIG(*)`-Messung.

### Bewertung und Gegenprobe

Berücksichtigen Sie Größe, Zeilen, Indexart, Schlüssel/Includes, Filter, Partitionierung, Kompression und Schutzmerkmale gemeinsam. Ähnliche Schlüsselreihenfolgen können unterschiedliche Coverage, Sortierung oder Constraints bedienen.

### Typische Fehlinterpretation

Inventar zeigt Existenz, nicht Nutzen, Nutzung oder Redundanz. Eine kleine Tabelle mit vielen Indizes kann andere Trade-offs haben als eine große schreibintensive Tabelle. Insbesondere beweisen ein sichtbarer JSON-Index, seine Pfadzahl oder `OptimizeForArraySearch` weder passende Workloadabdeckung noch Gesundheit oder Rebuildbedarf.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_IndexUsage`, `USP_IndexOperationalStats`, Query Store/Plan Cache und Abhängigkeitsprüfung.

## Primärquellen

- [SQL-Server-Katalogsichten](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/catalog-views-transact-sql?view=sql-server-ver17)
- [sys.json_indexes (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-json-indexes-transact-sql?view=sql-server-ver17)
- [sys.json_index_paths (Transact-SQL)](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-json-index-paths-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#1-monitorusp_objectinventory)

[SQL-Server-2025-JSON-Index-Vertrag](../../Architecture/SQL_Server_2025_JSON_Index_Inventory.md)
