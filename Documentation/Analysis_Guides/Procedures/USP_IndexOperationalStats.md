# [monitor].[USP_IndexOperationalStats]

**Bereich:** Object und Index<br>
**Zweck:** Zeigt partitionsgenaue DML-, Allocation-, Lock-, Latch- und Zugriffsaktivität.<br>
**Beobachtungsart:** kumulativ seit Struktur-/Instanzreset<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Welche internen Zugriffsmuster, Allocations, Locks und Latches erzeugt ein Index?** Sie unterstützt die Entscheidung, ob ein Struktur- oder Metadatensignal eine workloadbezogene Gegenprüfung rechtfertigt, nicht ob automatisch DDL ausgeführt werden soll.

## Nicht beantwortete Fragen

Die Procedure beantwortet keinen Geschäftsnutzen einer Strukturänderung, keine repräsentative Workload und keine automatische Aussage über den optimalen Index- oder Statistikzustand. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_IndexOperationalStats]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleTable]',
      @NurMitAktivitaet = 1,
      @MaxZeilen = 100,
      @ResultSetArt = 'CONSOLE';
```

GEZIELT erfordert FullObjectNames oder beide exakten Listen SchemaNames und ObjectNames. Die Listen können mehrere Treffer bezeichnen; die Variablenzuweisung an ObjectIdFilter garantiert bei mehreren Treffern keine bestimmte Auswahl. Ohne auflösbare ObjectId wird die DMF nicht mit NULL als Wildcard aufgerufen. VOLL ist ein eigener Deep-Pfad.

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Eine Datenbankliste allein erfüllt den GEZIELT-Objektfilter nicht. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt. |
| `@HighImpactConfirmed` | `bit` | `0` | bit-Bestätigung für den VOLL-Pfad INDEX_OPERATIONAL_DEEP, der erst nach OBJECT_ANALYSIS_CURRENT aktiviert wird: 0 bestätigt den Deep-Pfad nicht; 1 erfüllt die Bestätigungsanforderung, erteilt selbst aber keine Berechtigung. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. GEZIELT nutzt OBJECT_ANALYSIS_CURRENT und verlangt diese Bestätigung nicht. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. In GEZIELT benötigt diese Liste zusätzlich die exakte @ObjectNames-Liste; alternativ wird ausschließlich @FullObjectNames verwendet. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Schema-Pattern gemäß TVF_ParsePattern: NULL = keines; äußere Leerzeichen trimmen, Präfix like:/regex:/regexi: ohne Beachtung der Großschreibung, sonst LIKE; leerer Inhalt oder leeres Präfix ungültig. LIKE-Schemavergleiche sind case-sensitive und nutzen SQL-LIKE-Wildcards. regex: verwendet Flag c, regexi: Flag i. Schema-Regex wird am Schemaquellpfad ausgeführt; dieser Pfad prüft SQL Server 2025 und Compatibility Level 170. Exakte Liste und Pattern derselben Eigenschaft sind exklusiv. In GEZIELT ersetzt ein Muster nicht die Voraussetzung aus FullObjectNames oder beiden exakten Listen. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. Im GEZIELT-Modus benötigt diese Liste zusätzlich eine exakte @SchemaNames-Liste; Pattern ersetzt diese nicht. @FullObjectNames ist eine alternative Auswahl und darf nicht damit kombiniert werden. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Objekt-Pattern gemäß TVF_ParsePattern: NULL = keines; äußerer Trim; Präfix like:/regex:/regexi: wird ohne Beachtung der Großschreibung erkannt, sonst LIKE; leere Werte oder leeres Präfix sind ungültig. LIKE-Objektvergleiche sind case-sensitive und nutzen SQL-LIKE-Wildcards. regex: verwendet Flag c, regexi: Flag i; Objekt-Regex wird im Objektquellpfad ausgeführt und prüft SQL Server 2025/Compatibility Level 170. Nicht gemeinsam mit @ObjectNames. Ein Muster allein erfüllt die GEZIELT-Auswahlvoraussetzung nicht. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. Dient als zulässiger Objektfilter für GEZIELT. |
| `@IndexNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Indexnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Indexnamenfilter, eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb von [...]; ]] maskiert ]. Elemente werden getrimmt, als einteilige SQL-Namen validiert und case-sensitive verglichen. Rohsegmente über 4000 UTF-16-Codeeinheiten und Namen über die sysname-Grenze werden abgewiesen. Case-sensitive Duplikate sind ungültig. Nicht gemeinsam mit @IndexNamePattern verwenden. |
| `@IndexNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Indexnamen-Pattern gemäß TVF_ParsePattern: NULL = keines; äußerer Trim; Präfix like:, regex: oder regexi: ohne Beachtung der Großschreibung, sonst LIKE. Leerer Rest/Präfix ist ungültig. LIKE ist case-sensitive mit SQL-Wildcards; regex: verwendet Flag c und regexi: Flag i und benötigt SQL Server 2025/Compatibility Level 170, geprüft am Indexquellpfad. Nicht gemeinsam mit @IndexNames. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt. |
| `@AnalyseModus` | `varchar(16)` | `'GEZIELT'` | Nach LTRIM/RTRIM und Großschreibung sind nur GEZIELT und VOLL gültig; NULL wird wie GEZIELT normalisiert. GEZIELT verlangt @FullObjectNames oder beide exakten Listen @SchemaNames und @ObjectNames. Die Filter können mehrere Objekte bezeichnen; der Quellcode löst @ObjectIdFilter per SELECT-Variablenzuweisung auf passende Objekte auf und garantiert dabei keine bestimmte Auswahl, falls mehrere übereinstimmen. VOLL aktiviert INDEX_OPERATIONAL_DEEP und benötigt dessen Freigabe sowie @HighImpactConfirmed=1. Leer oder nur Leerzeichen sowie andere Werte sind INVALID_PARAMETER. |
| `@PartitionNumber` | `int` | `NULL` | Optionale positive int-Partitionsnummer, Bereich 1 bis 2147483647. In GEZIELT wird sie für die zugewiesene ObjectId an die DMF übergeben; NULL umfasst dort alle Partitionen dieses Objekts. VOLL verlangt NULL und verwendet den breiten Rowset-Pfad; nur ein nicht-NULL-Wert ist auf GEZIELT beschränkt. Werte kleiner 1 sind INVALID_PARAMETER. |
| `@NurMitAktivitaet` | `bit` | `1` | bit-Filter: 0 lässt auch Nullaktivitätszeilen zu; 1 verlangt mindestens einen der im Quellprädikat addierten DML-, Range-/Lookup-, Lock-, Page-Latch- oder I/O-Latch-Zähler größer Null. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte konvertieren beim Binden zu 1. Bei NULL wird die Bedingung @P=0 OR Aktivitätsausdruck&gt;0 für Nullaktivität nicht TRUE, sodass solche Zeilen ausgeschlossen werden. |
| `@MinLeafPageAllocations` | `bigint` | `0` | Nichtnegative bigint-Mindestzahl kumulativer Leaf-Page-Allokationen je Partition, Bereich 0 bis 9223372036854775807; Default 0 schränkt nicht ein. Negative Werte sind INVALID_PARAMETER. NULL besteht den negativen Wertecheck durch UNKNOWN, macht aber leaf_allocation_count &gt;= @P UNKNOWN und lässt keine Zeile passieren. |
| `@MinLockWaitMs` | `bigint` | `0` | Nichtnegative bigint-Mindestzeit in Millisekunden für Row- plus Page-Lock-Wait-Zeit, Bereich 0 bis 9223372036854775807; Default 0 schränkt nicht ein. Negative Werte sind INVALID_PARAMETER. NULL besteht den negativen Wertecheck durch UNKNOWN, macht aber den nachfolgenden Summenvergleich UNKNOWN und lässt keine Zeile passieren. |
| `@MaxZeilen` | `int` | `5000` | Nichtnegative int-TOP-Grenze, Bereich 0 bis 2147483647, Default 5000; 0 oder NULL wird intern zu der bigint-Grenze 9223372036854775807 umgerechnet. Negative Werte führen zu INVALID_PARAMETER. TOP gilt für die Operational-Stats-Quellabfrage je Datenbank. Die Auswahl sortiert vorab nach I/O-Latch-Wartezeit, Page-Latch-Wartezeit, Row-/Page-Lock-Wartezeit und Leaf-Page-Allokationen absteigend; die Endausgabe verwendet eine eigene Sortierung. Keine globale Zeilenobergrenze und kein Limit für die vorherige DMF-/Katalogarbeit. |
| `@LockTimeoutMs` | `int` | `0` | int in Millisekunden; gültiger nicht-NULL-Wertebereich 0 bis 60000, 0 setzt vor den fachlichen Zugriffen NOWAIT. Der Bereichstest @LockTimeoutMs NOT BETWEEN 0 AND 60000 wertet NULL als UNKNOWN; mit nichtnegativen übrigen Zahlen wird NULL dadurch nicht als INVALID_PARAMETER erkannt. Anschließend wird der Wert mit N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + ... in dynamisches SQL konkateniniert. Bei NULL wird der zusammengebaute SQL-Text NULL; der Quellcode setzt darin keinen konkreten Wert. Vor der Datenbankschleife setzt die Procedure ausdrücklich LOCK_TIMEOUT 0. Der NULL-Batch setzt keine andere konkrete Wartezeit; die zuvor gesetzte NOWAIT-Einstellung bleibt für diesen Ausführungspfad maßgeblich. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Operational-Stats-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: indexOperationalStats als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"indexOperationalStats":"#IndexHelpTarget"}'. |
| `@JsonErzeugen` | `bit` | `0` | bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, indexOperationalStats und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, indexOperationalStats und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück. |
| `@PrintMeldungen` | `bit` | `1` | bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung. |
| `@Hilfe` | `bit` | `0` | bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht. |

```sql
DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'dbo.ExampleTable', @ResultSetArt='RAW', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;
CREATE TABLE #IndexOperationalStatsTarget([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'dbo.ExampleTable', @ResultSetArt='TABLE', @ResultTablesJson=N'{"indexOperationalStats":"#IndexOperationalStatsTarget"}';
END TRY
BEGIN CATCH
    DROP TABLE #IndexOperationalStatsTarget;
    THROW;
END CATCH;
DROP TABLE #IndexOperationalStatsTarget;
EXEC [monitor].[USP_IndexOperationalStats] @Hilfe=1;
```

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert `indexOperationalStats`. RAW liefert zuerst Modul- und Datenbankstatus, danach die Fachresultsets. CONSOLE gibt nur das menschenlesbare Fachresultset aus; TABLE schreibt das registrierte Fachresultset ins Ziel. JSON enthält seine Metadaten, die Fachdaten und den Datenbankstatus. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Eine Zeile entspricht einem Index oder Heap **und einer Partition**. Werte verschiedener Partitionen dürfen nur bewusst aggregiert werden.

Die Textspalten der lokalen Kandidaten-, Status- und Ergebnistabellen
verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Der TABLE-Export übernimmt
diese Frameworkcollation unabhängig von der `tempdb`-Collation. Ein
kontrollierter SQL-Server-2025-Lauf mit abweichender Server- und
`tempdb`-Collation prüft die gezielte JSON-/TABLE-Ausgabe und die Übereinstimmung
der Insert-, Allocation-, Page-Latch- und Tree-Page-Latch-Zähler mit der
nativen Quelle für eine einzelne Fixturepartition. Dieser Nachweis erweitert
keine allgemeine Collation- oder Lastgarantie.

## So lesen

Vergleichen Sie DML, Allocations, Locks, Latches und Scans. Normalisieren Sie absolute Zähler pro Aktivität, Wait oder Beobachtungszeit.

## Warum kann das problematisch sein?

Viele Page Allocations pro Insert können Split-/Wachstumsdruck anzeigen. Hohe Lock-/Latchzeit kann Parallelität und Durchsatz begrenzen.

## Wann ist es kein Problem?

Hohe absolute Zähler sind bei stark genutzten Indizes normal. Verhältnis, Delta und aktuelle Auswirkung sind entscheidend.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Eine Million Latch-Waits über ein Jahr kann weniger kritisch sein als 50.000 in fünf Minuten auf derselben Hot Page. Prüfen Sie Live-Waits, Keyverteilung, Plan und Contention.

**Ähnlich aussehender Gegenfall:** Hohe absolute Zähler sind bei stark genutzten Indizes normal. Verhältnis, Delta und aktuelle Auswirkung sind entscheidend. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Bei Katalogpfaden sind Featureabwesenheit, Filter, Offline-/Permission-Scope und tatsächlich fehlende Objekte getrennte Erklärungen.

Für `USP_IndexOperationalStats` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

**Quellcode-Hinweis zur Eigenlast:** GEZIELT verlangt einen passenden FullObjectNames-Bezug oder beide exakten Listen SchemaNames und ObjectNames. Die Variablenzuweisung an ObjectIdFilter garantiert bei mehreren passenden Objekten keine bestimmte Auswahl; bei keinem Treffer wird die DMF nicht mit NULL-Wildcard aufgerufen. VOLL kann alle Heap-/B-Tree-/Columnstore-Rowsets lesen und ist deshalb explizit gruppengeschützt. TOP reduziert nicht zwingend die DMF-Arbeit.

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | GEZIELT verlangt FullObjectNames oder beide exakten Listen SchemaNames und ObjectNames. Die Objekt-ID wird aus passenden Katalogzeilen zugewiesen; bei mehreren Treffern ist keine bestimmte Auswahl zugesichert. Die DMF erhält keine NULL-Wildcard bei nicht auflösbarem Ziel. Inaktive Partitionen werden standardmäßig ausgeblendet. |
| Teuerster Pfad | `VOLL` über alle Datenbanken/Rowsets, Aktivitätsfilter aus und `@MaxZeilen = 0`. Ein Partitionsfilter ist in VOLL absichtlich ungültig; Scope muss über Datenbank-/Objektpattern erfolgen. |
| Haupttreiber | Zahl der von der DMF betrachteten Heap-/Index-/Partitionsrowsets. Nutzdatenzeilen werden nicht gescannt, aber VOLL muss instanzweite operative Zähler für alle Rowsets des Datenbankscope bereitstellen. |
| Skalierung | GEZIELT skaliert mit Partitionen/Indizes eines Objekts; VOLL mit allen Rowsets je Datenbank. Dynamisches SQL/DMF-Aufruf erfolgt separat pro Kandidatendatenbank. |
| Ressourcen | DMV-CPU, Katalogjoins für Namen/Typen und TempDB/Transfer. Kein Seiteninhaltsscan; die DMF selbst kann bei sehr vielen Rowsets dennoch spürbar sein. |
| Begrenzungswirkung | ObjectId und optional Index-/Partitionsfilter reduzieren GEZIELT früh. `@MaxZeilen` ist TOP in der Resultquery je Datenbank, garantiert aber nicht, dass die DMF nur diese Rowsets intern betrachtet; VOLL bleibt deshalb gatepflichtig. |
| Locking und Nebenwirkungen | Read-only; Katalogabfragen nehmen üblicherweise kurze Schema-Stability-Zugriffe und können mit gleichzeitigem DDL oder Datenbankstatuswechseln konkurrieren. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `INDEX_OPERATIONAL_DEEP`, `OBJECT_ANALYSIS_CURRENT`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine `ExampleDatabase`, genau ein `ExampleSchema.ExampleTable`, aktive Rowsets und 100 Zeilen. Erst bei klarer Flottenfrage VOLL separat bestätigen. |
| Aussagegrenze | Zähler sind kumulativ seit Instanzstart beziehungsweise Rowset-/Indexneuanlage und zeigen keine aktuelle Rate. Rebuild, Restart oder Partitionwechsel setzt Vergleichbarkeit zurück; hohe Counts benötigen Laufzeit-/Baselinebezug. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche internen Zugriffsmuster, Allocations, Locks und Latches erzeugt ein Index?

### Technischer Hintergrund

`sys.dm_db_index_operational_stats` liefert Blatt-/Nichtblattoperationen, Range-/Singleton-Lookups, Page Allocations, Lock-/Latch-Waits und weitere Low-Level-Zähler. Diese Zähler spiegeln physische Arbeitsweise wider und ergänzen die gröbere Usage-Sicht.

### Datenkette

`sys.dm_db_index_operational_stats`, `sys.indexes`, `sys.objects`, `sys.schemas`, `sys.sp_executesql`, `sys.tables`.

### Source Select

Die Objekt-ID wird direkt aus Katalogen aufgelöst und als enger DMF-Parameter verwendet:

```sql
DECLARE @TargetObjectId int =
(
    SELECT [o].[object_id]
    FROM [sys].[objects] AS [o] WITH (NOLOCK)
    JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
      ON [s].[schema_id] = [o].[schema_id]
    WHERE [s].[name] = N'ExampleSchema'
      AND [o].[name] = N'ExampleObject'
);

SELECT
      [os].[object_id]
    , [os].[index_id]
    , [os].[partition_number]
    , [os].[leaf_allocation_count]
    , [os].[row_lock_wait_in_ms]
    , [os].[page_latch_wait_in_ms]
FROM [sys].[dm_db_index_operational_stats]
     (DB_ID(), @TargetObjectId, NULL, NULL) AS [os];
```

**Wichtig für die Eigenlast:** In GEZIELT wird die DMF ohne auflösbare ObjectId nicht mit NULL als Objekt-Wildcard aufgerufen. Die Eingabe sollte ein einzelnes beabsichtigtes Objekt bezeichnen; bei mehreren passenden Katalogzeilen garantiert die SELECT-Variablenzuweisung keine bestimmte Auswahl. VOLL ist der ausdrücklich freizugebende breite Pfad.

### Zeit- und Scope-Modell

Die Zähler sind innerhalb des Lebenszyklus der internen Struktur oder Instanz kumulativ. Die Werte können bei einem Neustart oder einer Strukturänderung zurückgesetzt werden.

### Bewertung und Gegenprobe

Normieren Sie die Zähler anhand der passenden Aktivität, beispielsweise Page Allocations pro Insert, Lockwaitzeit pro Lockwait und Latchwaitzeit pro Zugriff. Hohe absolute Werte sind bei stark genutzten Indizes erwartbar.

### Typische Fehlinterpretation

`leaf_allocation_count` ist nicht identisch mit dokumentiertem Page Split jeder Art. Eine Korrelation mit Fragmentierung/Fillfactor und DML-Muster ist nötig.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_IndexPhysicalStats`, Current Blocking/Waits und konkrete DML-Pläne.

## Primärquellen

- [sys.dm_db_index_operational_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-operational-stats-transact-sql?view=sql-server-ver17)

## Weiterführende Vertiefung

Die folgenden Quellen ergänzen die Produktspezifikation um Praxis- oder Toolingperspektiven. Sie sind keine Grundlage für versions-, Berechtigungs- oder Engineaussagen dieser Seite.

- [Ola Hallengren: Index and Statistics Maintenance – betriebliche Wartungsperspektive](https://ola.hallengren.com/sql-server-index-and-statistics-maintenance.html)

[Technische Detailbeschreibung](../03_Object_Index.md#3-monitorusp_indexoperationalstats)
