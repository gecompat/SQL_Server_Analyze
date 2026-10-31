# [monitor].[USP_Partitions]

**Bereich:** Object und Index<br>
**Zweck:** Zeigt partitionsgenaue Größe, Grenzen, Ablage und Kompression.<br>
**Beobachtungsart:** Katalogsnapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wie verteilen Partition Function und Scheme Daten über Partitionen und Storage, und sind Grenzen/Lebenszyklus plausibel?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_Partitions]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleTable]',
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
| `@AnalyseModus` | `varchar(16)` | `'GEZIELT'` | GEZIELT analysiert einen durch exakte Namenslisten, @FullObjectNames oder ein Schema-/Objekt-Pattern begrenzten Scope; mindestens eine solche Objektbegrenzung muss vorhanden sein. VOLL wählt den Katalogpfad und prüft zusätzlich CATALOG_DEEP. Der Wert wird getrimmt und in Großbuchstaben umgewandelt; NULL wird zu GEZIELT, GEZIELT und VOLL sind die einzigen gültigen Werte. Leertext und andere Werte führen zu INVALID_PARAMETER. VOLL ohne Freigabe wird abgewiesen. VOLL erfordert außerdem ausdrücklich @HighImpactConfirmed=1; eine Bestätigung ersetzt keine Gruppen- oder SQL-Berechtigung. |
| `@NurPartitionierte` | `bit` | `0` | 1 lässt nur Partitionen von Indizes mit mehr als einer Partition durch; 0 wendet diese zusätzliche Einschränkung nicht an. Die Prüfung erfolgt mit PartitionCount &gt; 1 und gilt auf Indexebene. Bei NULL greift weder der 0-Zweig noch die Wahrheitsbedingung für einpartitionige Indizes: Mehrpartitionige Indizes können passieren, einpartitionige nicht. Für bit-Eingaben sind 0 und 1 die Schalterwerte; NULL ist daher nicht gleichbedeutend mit 0. Numerisch 0 bleibt beim Binden 0; von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1. |
| `@NurGemischteKompression` | `bit` | `0` | 1 lässt nur Indizes durch, deren Partitionen mehrere Kompressionsarten aufweisen; technisch wird MinCompression &lt;&gt; MaxCompression geprüft. 0 wendet diese zusätzliche Einschränkung nicht an. Bei NULL liefert die SQL-OR-Bedingung nur für Indizes mit verschiedenen Minimal- und Maximalwerten TRUE; homogene Kompression erfüllt den Filter nicht. Für bit-Eingaben sind 0 und 1 die Schalterwerte; NULL ist daher nicht gleichbedeutend mit 0. Numerisch 0 bleibt beim Binden 0; von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1. |
| `@MaxZeilen` | `int` | `10000` | Nichtnegative ganze Zahl von 0 bis 2147483647. NULL oder 0 wird intern zur bigint-TOP-Grenze 9223372036854775807; negative Werte sind INVALID_PARAMETER. TOP begrenzt Partitionszeilen je Datenbank, geordnet nach ReservedPages absteigend, ObjectId, IndexId und PartitionNumber. Die Endausgabe ergänzt Datenbank-, Schema- und Objektnamen zur Sortierung. Kein globales Zeilenlimit und keine verlässliche Begrenzung der vorherigen Katalogjoins und Aggregation. |
| `@LockTimeoutMs` | `int` | `0` | Wartezeit als nicht-NULL int von 0 bis 60000 Millisekunden. 0 setzt NOWAIT; positive Werte werden im dynamischen Fachbatch als SET LOCK_TIMEOUT übernommen. Werte außerhalb sind INVALID_PARAMETER. NULL passiert den Bereichstest als UNKNOWN, macht den verketteten SQL-Text aber NULL statt des vorgesehenen Fachbatches. Vor der Datenbankschleife setzt die Procedure LOCK_TIMEOUT 0. Für einen regulären Fachaufruf einen konkreten Wert von 0 bis 60000 übergeben; ein bestimmter Fehlerstatus für das NULL-Statement wird hier nicht zugesichert. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Partitions-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: partitions als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"partitions":"#IndexHelpTarget"}'. |
| `@JsonErzeugen` | `bit` | `0` | bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, partitions und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, partitions und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück. |
| `@PrintMeldungen` | `bit` | `1` | bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung. |
| `@Hilfe` | `bit` | `0` | bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht. |

Die folgenden Aufrufe verwenden synthetische Namen und beginnen mit einem einzelnen Objekt. RAW erhält den Modul- und Datenbankstatus.

```sql
EXEC [monitor].[USP_Partitions] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';

DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_Partitions] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;

CREATE TABLE #Partitions_HelpExample([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_Partitions] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"partitions":"#Partitions_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE #Partitions_HelpExample;
    THROW;
END CATCH;
DROP TABLE #Partitions_HelpExample;

EXEC [monitor].[USP_Partitions] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `partitions`. RAW liefert zuerst Modul- und Datenbankstatus, danach die Fachzeilen. CONSOLE liefert ausschließlich die Fachdaten; TABLE exportiert nur partitions. JSON enthält meta, partitions und databaseStatus. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Partition eines Indexes oder Heaps. Ein Objekt mit mehreren Indizes besitzt entsprechend mehrere Zeilen je Partitionsnummer.

Die lokalen Kandidaten-, Status- und Ergebnistabellen verwenden für
Textspalten explizit `SQL_Latin1_General_CP1_CS_AS`. Der TABLE-Export erhält
dadurch die Frameworkcollation auch bei abweichender `tempdb`-Collation.
Ein kontrollierter SQL-Server-2025-Vertrag prüft drei RANGE-RIGHT-Partitionen
mit gemischter Kompression, Grenzinklusion, nativen Zeilen-/Kompressionswerten,
Zeilenlimit und case-sensitivem Objektfilter. Dieser Nachweis belegt keinen
VOLL-Pfad und keine allgemeine Collation- oder Storagegarantie.

## So lesen

Vergleichen Sie RowCount und Größe je Partition, Grenzintervalle, Filegroup, Kompression und Indexausrichtung.

## Warum kann das problematisch sein?

Ungünstige Grenzen oder nicht ausgerichtete Indizes können Partition Elimination, Switching und Wartung verhindern. Extreme Schieflage kann Hotspots bilden.

## Wann ist es kein Problem?

Leere Randpartitionen und ungleiche Größen sind bei Sliding-Window- oder Hot-/Cold-Design häufig beabsichtigt.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine leere zukünftige Monatspartition ist normal. Eine aktuelle Partition mit 95 % aller Zeilen und fehlender Elimination verlangt Plan-, Statistik- und Designprüfung.

**Ähnlich aussehender Gegenfall:** Leere Randpartitionen und ungleiche Größen sind bei Sliding-Window- oder Hot-/Cold-Design häufig beabsichtigt. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_Partitions` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** Die Procedure aggregiert Katalog- und Allocation-Unit-Daten. VOLL ist gruppengeschützt; TOP begrenzt die Ausgabe je Datenbank, nicht verlässlich die gesamte vorherige Aggregation.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Eine explizit benannte `ExampleDatabase` und ein Objekt in `GEZIELT`; Partitions-, Allocation-Unit- und Data-Space-Kataloge werden aggregiert. |
| Teuerster Pfad | Cross-Database-`VOLL`, unbegrenzte Ausgabe und keine Objektfilter bei sehr vielen Partitionen/Allocation Units. |
| Haupttreiber | Zahl gewählter Datenbanken/Objekte sowie Partitionen, Allocation Units, Partition-Scheme-Ziele und Data Spaces. Objektfilter begrenzen die ausgewählten Ergebnisobjekte; eine Begrenzung der gesamten Partitions-/Allocation-Unit-Aggregation durch diese Filter oder das spätere TOP ist nicht belegt. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_Partitions ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | CPU, Katalogseiten und TempDB für Joins/Aggregation; bei breitem Cross-Database-Scope zusätzlicher Compile- und Ergebnistransferaufwand. |
| Begrenzungswirkung | Datenbank-/Objektfilter begrenzen die Quellarbeit. TOP oder MaxZeilen werden häufig nach Katalogjoins und Aggregation angewandt und sind dann nur Ausgabelimits. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | `GEZIELT` nutzt `OBJECT_ANALYSIS_CURRENT` ohne High-Impact-Pflicht. `VOLL` prüft zusätzlich `CATALOG_DEEP` und erfordert `@HighImpactConfirmed = 1`. |
| Sicherer Einsatz | Mit einer ExampleDb und einem ExampleObject starten; erst nach Größenprüfung auf mehrere Datenbanken oder VOLL erweitern. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie verteilen Partition Function und Scheme Daten über Partitionen und Storage, und sind Grenzen/Lebenszyklus plausibel?

### Technischer Hintergrund

Partition Functions übersetzen Boundary Values in Partitionsnummern; RANGE LEFT/RIGHT bestimmt Grenzwertzuordnung. Schemes ordnen Partitionen Filegroups zu. Indizes müssen für Alignment dieselbe Partitionierungslogik passend verwenden.

### Datenkette

`sys.allocation_units`, `sys.data_spaces`, `sys.destination_data_spaces`, `sys.dm_db_partition_stats`, `sys.indexes`, `sys.objects`, `sys.partition_functions`, `sys.partition_range_values`, `sys.partition_schemes`, `sys.partitions`, `sys.schemas`, `sys.sp_executesql`.

### Source Select

Die Partitionskette verbindet Indexpartition, Partitionsschema/-funktion und die unteren beziehungsweise oberen Grenzwerte:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [o].[name] AS [ObjectName]
    , [i].[name] AS [IndexName]
    , [p].[partition_number]
    , [pf].[name] AS [PartitionFunctionName]
    , [lo].[value] AS [LowerBoundaryValue]
    , [hi].[value] AS [UpperBoundaryValue]
FROM [sys].[objects] AS [o] WITH (NOLOCK)
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [o].[schema_id]
JOIN [sys].[indexes] AS [i] WITH (NOLOCK)
  ON [i].[object_id] = [o].[object_id]
JOIN [sys].[partitions] AS [p] WITH (NOLOCK)
  ON [p].[object_id] = [i].[object_id]
 AND [p].[index_id] = [i].[index_id]
LEFT JOIN [sys].[partition_schemes] AS [ps] WITH (NOLOCK)
  ON [ps].[data_space_id] = [i].[data_space_id]
LEFT JOIN [sys].[partition_functions] AS [pf] WITH (NOLOCK)
  ON [pf].[function_id] = [ps].[function_id]
LEFT JOIN [sys].[partition_range_values] AS [lo] WITH (NOLOCK)
  ON [lo].[function_id] = [pf].[function_id]
 AND [lo].[boundary_id] = [p].[partition_number] - 1
LEFT JOIN [sys].[partition_range_values] AS [hi] WITH (NOLOCK)
  ON [hi].[function_id] = [pf].[function_id]
 AND [hi].[boundary_id] = [p].[partition_number]
WHERE [s].[name] = N'ExampleSchema'
  AND [o].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Begrenzen Sie Objekt und Index vor Allocation-, Destination-Data-Space- und Boundary-Vertiefung. Ob die untere beziehungsweise obere Grenze inklusive ist, ergibt sich zusätzlich aus `sys.partition_functions.boundary_value_on_right`.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Katalog- und Rowcount-/Spacezustand.

### Bewertung und Gegenprobe

Prüfen Sie Boundary-Reihenfolge, leere Randpartitionen, Größenverteilung, Kompression, Filegroups, aligned/non-aligned Indizes und Sliding-Window-Prozess. Skew kann fachlich erwartbar sein.

### Typische Fehlinterpretation

Viele oder ungleiche Partitionen sind nicht automatisch schlecht. Partitionierung garantiert weder schnellere Queries noch Partition Elimination; Prädikat und Plan entscheiden.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Showplan Partition Elimination, Wartungs-/Switchprozess und Capacityanalyse.

## Primärquellen

- [sys.dm_db_partition_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-partition-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#7-monitorusp_partitions)
