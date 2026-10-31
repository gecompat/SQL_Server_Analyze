# [monitor].[USP_IndexPhysicalStats]

**Bereich:** Object und Index<br>
**Zweck:** Misst beim Aufruf physische Rowstore-/Heap-Strukturen wie Page Count, Fragmentierung, Seitendichte, Ebenen, Ghosts und Forwarded Records.<br>
**Beobachtungsart:** aufrufbezogener physischer Strukturzustand<br>
**Kostenklasse:** `HIGH_OPT_IN`

## Entscheidungsfrage und Einsatz

Diese Auswertung beantwortet: **Wie ist ein konkret verdächtiges Heap- oder Rowstore-Indexobjekt physisch aufgebaut, und ist die Strukturgröße groß genug, um Fragmentierung, niedrige Seitendichte oder Forwarded Records als mögliche Mitursache weiterzuprüfen?**

Sie gehört nicht an den Anfang einer pauschalen „alle Indizes warten“-Routine. Ein sinnvoller Einsatz beginnt mit einem benannten Objekt, für das bereits Workloadevidenz vorliegt: relevante Scans, zusätzliche Reads, hohe Cachebelegung, Heap-Lookups oder eine belastbare Wartungsfrage. Der kleinste Pfad ist eine Datenbank, genau ein Objekt, `GEZIELT` und `LIMITED`.

## Nicht beantwortete Fragen

Die Procedure misst keine tatsächliche Indexnutzung, keine Querylaufzeit, keine Planqualität und keinen Nutzen einer Wartungsaktion. Sie entscheidet weder „REORGANIZE oder REBUILD“ noch beweist ein hoher Fragmentierungswert eine Performanceursache. Logvolumen, verfügbare Edition-/Onlineoptionen, Replikation, AG-Auswirkungen, TempDB-Bedarf und Wartungsfenster liegen außerhalb des Resultsets.

Die Messung umfasst physische Statistiken im gewählten Scanmodus. `SAMPLED` ist näherungsweise, und nicht jede Spalte ist für jeden Indextyp, Allocation-Unit-Typ oder Modus anwendbar. `NULL` ist deshalb nicht mit 0 gleichzusetzen.

## Sicherer Einstieg

Der Zugriff ist als `PHYSICAL_STATS_DEEP` geschützt und erfordert sowohl die konfigurierte Analysefreigabe als auch die bewusste Bestätigung. Der Beispielscope ist vollständig synthetisch:

```sql
EXEC [monitor].[USP_IndexPhysicalStats]
      @DatabaseNames = N'[ExampleDatabase]',
      @FullObjectNames = N'[ExampleSchema].[ExampleTable]',
      @AnalyseModus = 'GEZIELT',
      @ScanMode = 'LIMITED',
      @MinPageCount = 1000,
      @MaxZeilen = 1000,
      @LockTimeoutMs = 0,
      @HighImpactConfirmed = 1,
      @ResultSetArt = 'RAW';
```

Prüfen Sie vor dem Aufruf Objektname und Datenbank. `@DatabaseNames = NULL` bedeutet nach dem gemeinsamen Datenbankvertrag nicht „aktuelle Datenbank“, sondern alle sichtbaren, zugreifbaren, online befindlichen Userdatenbanken. Ein breiter Lauf ist daher niemals ein unbemerkter Ersatz für den gezielten Einstieg.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@DatabaseNames` | `nvarchar(max)` | `NULL` | Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Eine Datenbankliste allein erfüllt den GEZIELT-Objektfilter nicht. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. |
| `@SystemdatenbankenEinbeziehen` | `bit` | `0` | bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. |
| `@DatabaseNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt. |
| `@HighImpactConfirmed` | `bit` | `0` | SQL-bit-Bestätigung mit 0 oder 1; von 0 verschiedene konvertierbare Zahlen werden beim Binden 1. PHYSICAL_STATS_DEEP ist stets aktiv, auch für GEZIELT, eine Datenbank und LIMITED. 0 bestätigt den Pfad nicht und führt im Auswahlpfad zu HIGH_IMPACT_CONFIRMATION_REQUIRED; 1 erfüllt die Bestätigung, benötigt aber weiterhin die separate Gruppenfreigabe. NULL wird im normalen Auswahlpfad als INVALID_PARAMETER abgewiesen. Der Schalter vergibt keine SQL-Rechte. |
| `@SchemaNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. In GEZIELT benötigt diese Liste zusätzlich die exakte @ObjectNames-Liste; alternativ wird ausschließlich @FullObjectNames verwendet. |
| `@SchemaNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Schemanamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @SchemaNames kombinieren. Übergabe zum Beispiel N'like:App%'. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht. |
| `@ObjectNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. Im GEZIELT-Modus benötigt diese Liste zusätzlich eine exakte @SchemaNames-Liste; Pattern ersetzt diese nicht. @FullObjectNames ist eine alternative Auswahl und darf nicht damit kombiniert werden. |
| `@ObjectNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Objektnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @ObjectNames kombinieren. Übergabe zum Beispiel N'like:App%'. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht. |
| `@FullObjectNames` | `nvarchar(max)` | `NULL` | Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. Dient als zulässiger Objektfilter für GEZIELT. |
| `@IndexNames` | `nvarchar(max)` | `NULL` | Exakte einteilige Indexnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Indexnamenfilter, eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb von [...]; ]] maskiert ]. Elemente werden getrimmt, als einteilige SQL-Namen validiert und case-sensitive verglichen. Rohsegmente über 4000 UTF-16-Codeeinheiten und Namen über die sysname-Grenze werden abgewiesen. Case-sensitive Duplikate sind ungültig. Nicht gemeinsam mit @IndexNamePattern verwenden. Ein aktiver Indexnamensfilter trifft keinen NULL-Indexnamen eines Heaps. |
| `@IndexNamePattern` | `nvarchar(4000)` | `NULL` | Optionales Indexnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @IndexNames kombinieren. Übergabe zum Beispiel N'like:App%'. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht. Ein aktiver Filter trifft keinen NULL-Indexnamen eines Heaps. |
| `@AnalyseModus` | `varchar(16)` | `'GEZIELT'` | Nach LTRIM/RTRIM und UPPER sind ausschließlich GEZIELT und VOLL zulässig; NULL wird GEZIELT, leer oder ein anderer Wert ist INVALID_PARAMETER. GEZIELT verlangt @FullObjectNames oder beide exakten Listen @SchemaNames und @ObjectNames; Pattern allein genügt nicht. Je Datenbank weist SELECT eine passende ObjectId einer Variablen zu; mehrere Treffer ergeben eine nicht zugesicherte Auswahl, nicht mehrere Objektaufrufe. Ohne auflösbares Objekt wird keine NULL-Wildcard an die DMF übergeben. VOLL lässt ObjectId NULL und wendet Namensfilter erst auf die DMF-Zeilen an. Beide Modi bleiben PHYSICAL_STATS_DEEP und benötigen @HighImpactConfirmed=1 sowie die separate Gruppenfreigabe. |
| `@ScanMode` | `varchar(16)` | `'LIMITED'` | Nach LTRIM/RTRIM und UPPER sind ausschließlich LIMITED, SAMPLED und DETAILED zulässig; NULL wird LIMITED, leer oder andere Werte sind INVALID_PARAMETER. LIMITED liest bei B-Bäumen obere Ebenen. SAMPLED schätzt mit etwa 1 % der Seiten, unter 10.000 Seiten als DETAILED. DETAILED liest alle Seiten; Heaps können schon in LIMITED Datenzugriffe erfordern. Die Wahl beeinflusst die Diagnosearbeit, ersetzt aber keine Analysefreigabe. |
| `@IndexId` | `int` | `NULL` | Optionale numerische Index-ID, kein Indexname. Die Procedure akzeptiert NULL oder ganze Zahlen von 0 bis 2147483647; 0 bezeichnet den Heap, positive Werte eine Index-ID. Negative Werte sind INVALID_PARAMETER. Die IDs werden unverändert an die DMF weitergereicht; die Procedure prüft ihre Existenz und native Argumentkombination nicht vorab. VOLL erfordert nativ NULL; bei NULL muss auch @PartitionNumber NULL sein. Native Fehler werden je Datenbank protokolliert. |
| `@PartitionNumber` | `int` | `NULL` | Optionale ganze Partitionsnummer von 1 bis 2147483647; NULL wählt alle Partitionen des wirksamen DMF-Scopes. Kleinere nicht-NULL-Werte sind INVALID_PARAMETER. Die Procedure prüft Existenz und native Argumentkombination nicht vorab. Ein gesetzter Wert benötigt nativ konkrete Objekt- und Index-IDs. Fehler werden je Datenbank protokolliert; ein kleiner Zahlenwert garantiert keine vorhandene Partition. |
| `@MinPageCount` | `bigint` | `1000` | Nichtnegative ganze Zahl von 0 bis 9223372036854775807 in Seiten. Der Default 1000 filtert kleine Ergebniszeilen; 0 setzt keine positive Mindestgröße. Negative Werte sind INVALID_PARAMETER. NULL passiert den negativen Wertecheck, macht den Vergleich page_count &gt;= @MinPageCount aber UNKNOWN und liefert keine Treffer. Das WHERE-Prädikat folgt dem DMF-Aufruf und begrenzt dessen vorherige Arbeit nicht. |
| `@MinFragmentationPercent` | `decimal(9,2)` | `0` | Dezimaler Mindestwert von 0.00 bis 100.00 Prozent einschließlich; decimal(9,2) rundet beim Binden auf zwei Nachkommastellen. Außerhalb: INVALID_PARAMETER. NULL passiert die Bereichsprüfung als UNKNOWN, liefert aber keine Treffer. Auch NULL im nativen avg_fragmentation_in_percent erfüllt den Vergleich nicht, selbst bei Mindestwert 0. Der Filter wirkt auf DMF-Ergebnisse und begrenzt keine vorherige Scanarbeit. |
| `@MaxZeilen` | `int` | `10000` | Nichtnegative ganze Zahl von 0 bis 2147483647. NULL oder 0 wird intern zur bigint-TOP-Grenze 9223372036854775807; negative Werte sind INVALID_PARAMETER. Der Default ist 10000. TOP gilt je Datenbank nach DMF-Aufruf und Filtern, geordnet nach page_count und avg_fragmentation_in_percent absteigend; Gleichstände haben keinen zugesicherten Tie-Breaker. Die Endausgabe ergänzt Identitätsfelder zur Sortierung. Kein globales Zeilenlimit und keine Begrenzung der vorherigen DMF-Arbeit. |
| `@LockTimeoutMs` | `int` | `0` | Wartezeit als nicht-NULL int von 0 bis 60000 Millisekunden. 0 setzt NOWAIT; positive Werte werden im dynamischen Fachbatch als SET LOCK_TIMEOUT übernommen. Werte außerhalb sind INVALID_PARAMETER. NULL passiert den Bereichstest als UNKNOWN, macht den verketteten SQL-Text aber NULL statt des vorgesehenen Fachbatches. Vor der Datenbankschleife setzt die Procedure LOCK_TIMEOUT 0. Für einen regulären Fachaufruf einen konkreten Wert von 0 bis 60000 übergeben; ein bestimmter Fehlerstatus für das NULL-Statement wird hier nicht zugesichert. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Physical-Stats-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: indexPhysicalStats als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"indexPhysicalStats":"#IndexHelpTarget"}'. |
| `@JsonErzeugen` | `bit` | `0` | bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, indexPhysicalStats und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, indexPhysicalStats und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück. |
| `@PrintMeldungen` | `bit` | `1` | bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung. |
| `@Hilfe` | `bit` | `0` | bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht. |

Die folgenden Aufrufe verwenden ausschließlich synthetische Namen. RAW erhält den Modul- und Datenbankstatus.

```sql
EXEC [monitor].[USP_IndexPhysicalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @ScanMode='LIMITED', @ResultSetArt='RAW';

DECLARE @Json nvarchar(max);
EXEC [monitor].[USP_IndexPhysicalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @ScanMode='LIMITED', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT;
SELECT @Json;

CREATE TABLE #IndexPhysicalStats_HelpExample([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_IndexPhysicalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @ScanMode='LIMITED', @ResultSetArt='TABLE', @ResultTablesJson=N'{"indexPhysicalStats":"#IndexPhysicalStats_HelpExample"}';
END TRY
BEGIN CATCH
    DROP TABLE #IndexPhysicalStats_HelpExample;
    THROW;
END CATCH;
DROP TABLE #IndexPhysicalStats_HelpExample;

EXEC [monitor].[USP_IndexPhysicalStats] @Hilfe=1;
```

Grundlage der nativen Scan-Optionen: [Microsoft Learn](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-db-index-physical-stats-transact-sql?view=sql-server-ver17).

## Resultsets und Leserichtung

- `CONSOLE` liefert genau ein fachliches Resultset aus `indexPhysicalStats`. Bei leerer Menge erscheint eine verständliche Leerzeile, aber kein separates Datenbankstatus-Grid.
- `RAW` liefert Modulstatus, danach einen Status je ausgewählter Datenbank und erst anschließend die physischen Zeilen. Bei mehreren Datenbanken ist diese Reihenfolge entscheidend: `PARTIAL`, `AVAILABLE_LIMITED`, `SKIPPED`, `DENIED_PERMISSION` oder `TIMEOUT` erklären Lücken.
- `TABLE` exportiert ausschließlich das Primärergebnis `indexPhysicalStats` in die zugeordnete lokale Temp-Tabelle. Der Datenbankstatus wird nicht als TABLE-Resultset exportiert.
- JSON enthält `meta`, `indexPhysicalStats` und `databaseStatus`.

Eine leere Fachdatenmenge ohne Statuskontext ist keine Wartungsaussage. Verwenden Sie für Freigaben oder Cross-Database-Läufe deshalb zunächst `RAW` oder JSON.

## Eine Zeile bedeutet

Eine Zeile entspricht einer Kombination aus Datenbank, Objekt, `IndexId`, Partition, `IndexLevel` und `AllocationUnitTypeDesc`, die `sys.dm_db_index_physical_stats` im gewählten Modus liefert. Ein einzelner Index kann daher mehrere Zeilen besitzen:

- je Partition,
- je B-Tree-Ebene,
- je Allocation Unit wie `IN_ROW_DATA`, `LOB_DATA` oder `ROW_OVERFLOW_DATA`.

Werte dürfen nicht ungeprüft über diese Zeilen addiert oder gemittelt werden. Isolieren Sie für die übliche Leaf-Bewertung eines Rowstore-Indexes zuerst die relevante Partition und `IndexLevel = 0`. Bei einem Heap (`IndexId = 0`) gelten andere Strukturmerkmale; insbesondere `ForwardedRecordCount` ist ein Heapkontext und keine allgemeine Indexkennzahl.

## So lesen

1. **Datenbankstatus:** Wurde die beabsichtigte Datenbank tatsächlich analysiert, oder wurde sie ausgelassen, abgelehnt beziehungsweise mit Fehler isoliert?
2. **Identität:** Legen Sie Datenbank, Schema, Objekt, Index, Partition, Ebene und Allocation Unit fest. Vergleichen Sie erst danach die Werte.
3. **Größe als Nenner:** Berücksichtigen Sie zuerst `PageCount` und, soweit passend, `RecordCount`. Ein Prozentwert ohne Größenbezug ist nicht entscheidungsfähig.
4. **Scanmodus:** Berücksichtigen Sie außerdem `ScanMode`. `LIMITED` ist der leichteste Modus, `SAMPLED` liefert eine Stichprobe, `DETAILED` untersucht alle Pages und Ebenen am tiefsten.
5. **Fragmentierung:** Betrachten Sie `AvgFragmentationPercent`, `FragmentCount` und `AvgFragmentSizePages` gemeinsam. Die mögliche Auswirkung hängt von Scanform, Read-Ahead, Storage, Größe und Workload ab.
6. **Seitendichte:** `AvgPageSpaceUsedPercent` zeigt die durchschnittliche Belegung der betrachteten Pages. Niedrige Dichte kann dieselbe Datenmenge auf mehr Pages verteilen und dadurch Buffer-Pool- und I/O-Bedarf erhöhen.
7. **Spezialwerte:** Ghost-/Version-Ghost-Werte nur im MVCC-/Cleanupkontext; Forwarded Records nur beim Heap; `CompressedPageCount` nur dort interpretieren, wo Modus und Struktur den Wert sinnvoll liefern.

## Warum kann das problematisch sein?

Eine große Struktur mit niedriger Seitendichte benötigt für dieselben Datensätze tendenziell mehr Pages. Das kann mehr Logical Reads, Cachebelegung und physische I/O verursachen. Starke logische Fragmentierung kann bei Range Scans zusammenhängendes Read-Ahead erschweren. Viele Forwarded Records in einem häufig gelesenen Heap können zusätzliche Pagezugriffe auslösen.

Die Diagnose selbst kann dabei erheblich sein: Die DMF liest physische Strukturinformationen. `DETAILED` untersucht alle Pages und alle Ebenen, ein breiter `VOLL`-Lauf kann dies über viele Objekte und Datenbanken wiederholen. Das Ergebnislimit greift erst nach dem DMF-Zugriff und schützt nicht vor dieser Quellarbeit.

## Wann ist es kein Problem?

99 Prozent Fragmentierung auf acht Pages besitzt einen sehr kleinen absoluten Scope und wird durch den Default `@MinPageCount = 1000` ohnehin ausgefiltert. Eine große Fragmentierung kann für überwiegende Punkt-Seeks ohne messbare zusätzliche Reads weniger relevant sein. Niedrige Dichte kann beabsichtigt sein, wenn der Fill Factor Insert-/Update-Splits für eine passende Workload reduziert.

Auch mehrere Ergebniszeilen für denselben Index sind kein Duplikatfehler, wenn Partition, Ebene oder Allocation Unit verschieden sind. `NULL` in einer nicht unterstützten Modus-/Strukturkombination ist kein gemessener Nullwert.

## Beispiele und Gegenbeispiele

**Synthetischer Prüfbedarf `ExampleLargeIndex`:** Leafebene einer großen Partition mit `PageCount = 5000000`, `AvgFragmentationPercent = 45` und `AvgPageSpaceUsedPercent = 55`. Beobachtung: große, wenig dicht belegte und fragmentierte Struktur. Mögliche Auswirkung: mehr Pages im Buffer Pool und mehr Arbeit bei Range Scans. Gegenprobe: `USP_IndexUsage`, Query Store und konkrete Pläne müssen zeigen, dass relevante Scans/Reads und eine Geschäftsauswirkung existieren. Bewerten Sie erst danach Wartungsoption, Log-/I/O-Budget und Rollback.

**Unkritischer Gegenfall `ExampleTinyIndex`:** `PageCount = 8` bei ebenfalls 45 Prozent Fragmentierung. Der Prozentwert sieht gleich aus, die absolute Struktur ist aber winzig. Ohne messbare Auswirkung ist eine Wartungsaktion typischerweise teurer als die potenzielle Einsparung.

**Heapfall `ExampleHeap`:** viele `ForwardedRecordCount`-Einträge bei großem `RecordCount` und Plänen mit RID Lookups. Das legt zusätzliche Zugriffe als Hypothese nahe. Derselbe absolute Forwarded-Wert ohne RecordCount, Nutzung und Planbezug ist nicht bewertbar; es gibt keine universelle Prozentgrenze in dieser Procedure.

## Leere oder partielle Ausgabe

Keine Fachzeile kann bedeuten:

- das synthetisch angegebene Zielobjekt existiert nicht oder ist nicht sichtbar,
- `@MinPageCount`, `@MinFragmentationPercent`, Index- oder Partitionsfilter schließen alles aus,
- die Datenbank ist offline, nicht zugreifbar oder vom Scope ausgeschlossen,
- Berechtigung oder Analyseklasse fehlt,
- `LOCK_TIMEOUT` wurde beim Metadaten-/Objektzugriff erreicht,
- der gewählte Struktur-/Moduspfad liefert für die Filterkombination keine Zeile.

Bei mehreren Datenbanken isoliert die Procedure Fehler je Datenbank und kann trotz `PARTIAL` Fachdaten anderer Datenbanken liefern. Daher nie nur die letzte Fachtabelle archivieren, wenn Vollständigkeit relevant ist. Ein gezieltes Objekt, das in einer der ausgewählten Datenbanken fehlt, wird nicht als `NULL`-Wildcard breit analysiert; dieser Schutz verhindert einen unbeabsichtigten Full Scan.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | `HIGH_OPT_IN`; selbst der kleine Pfad erfordert die Analyseklasse `PHYSICAL_STATS_DEEP` und `@HighImpactConfirmed = 1`. |
| Standardpfad | Eine Datenbank, ein exakt aufgelöstes Objekt, `GEZIELT`, `LIMITED`, Mindestgröße 1000 Pages und endliche Ausgabe ist der kleinste Pfad; seine reale Last hängt von der Objektgröße ab. |
| Teuerster Pfad | `VOLL` plus `DETAILED` über alle sichtbaren Userdatenbanken, ohne Objekt-/Partitionsfilter, mit `@MinPageCount = 0` und unbegrenzter Ausgabe untersucht sehr große Pagebestände. |
| Haupttreiber | Zahl ausgewählter Datenbanken und Objekte, Page Count, Partitionen, Indexebenen und `ScanMode` |
| Skalierung | primär Page-/I/O-Umfang; zusätzlich CPU für DMF, Katalogjoins, Filter und Sortierung sowie Transfer für breite Resultate |
| Ressourcen | Buffer Pool und physische I/O, CPU, eigener Memory Grant für Sortierung, Metadatenzugriffe und Ergebnistransfer; Abfrageplan ist mit `MAXDOP 1` begrenzt. |
| Begrenzungswirkung | Die intern aufgelöste ObjectId sowie die optionalen öffentlichen Parameter `@IndexId` und `@PartitionNumber` gehen an die DMF. Native Argumentabhängigkeiten gelten zusätzlich; ein eigenständiger öffentlicher Parameter `@ObjectId` existiert nicht. Namenspattern in `VOLL`, Mindestseiten, Mindestfragmentierung und `TOP (@MaxZeilen)` wirken erst nach dem DMF-Aufruf. `@MaxZeilen` gilt technisch je Datenbanklauf; die Gesamtausgabe kann bei mehreren Datenbanken darüber liegen. |
| Locking und Nebenwirkungen | Die DMF kann unabhängig vom Modus Intent-Shared-Locks anfordern. Auf einer lesbaren Secondary kann dies mit einem REDO-Thread kollidieren, der einen X-Lock benötigt. Keine DDL- oder Indexwartung; nur eigene Temp-Tabellen werden beschrieben. |
| Schutzmechanismus | Analyseklasse `PHYSICAL_STATS_DEEP`, explizites `@HighImpactConfirmed`, gezielter Modus mit Pflichtobjekt, Datenbankscope und `@LockTimeoutMs`; der Timeout begrenzt Lock-Warten, nicht I/O oder CPU. |
| Sicherer Einsatz | explizite Datenbank und exaktes Objekt, `LIMITED`, niedriges Ergebnislimit, Monitoring der Systemlast; `SAMPLED`/`DETAILED` oder `VOLL` nur mit begründetem Erkenntnisgewinn und geeignetem Betriebsfenster |
| Aussagegrenze | `LIMITED` und `SAMPLED` liefern weniger tiefe beziehungsweise näherungsweise Evidenz. Ein enger Scope kann andere problematische Strukturen nicht ausschließen; ein breiter Scope erhöht umgekehrt die Diagnosekosten massiv. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welcher physische Strukturzustand ist für das bereits fachlich verdächtige Objekt sichtbar, und rechtfertigt dessen absolute Größe eine tiefergehende Workload- oder Wartungsbewertung?

### Technischer Hintergrund

`sys.dm_db_index_physical_stats` traversiert Allocation- und Page-Strukturen abhängig von `LIMITED`, `SAMPLED` oder `DETAILED`. Fragmentierung beschreibt die Reihenfolge beziehungsweise Zusammenhängigkeit physischer Strukturen; Page Space Used beschreibt Dichte. Diese Mechanismen können I/O-Verhalten beeinflussen, bleiben aber ohne Workloadbezug Strukturevidenz.

Die Procedure verwendet die DMF ausschließlich lesend. Sie reorganisiert oder rebuildet nichts. Dass der Pfad „read-only“ ist, bedeutet nicht geringe Last: Ein physischer Scan kann mit der Größe des untersuchten Pagebestands wachsen.

### Datenkette

1. `USP_PrepareNameFilters` validiert zunächst die exakten Namens- und Objektlisten; die Procedure ergänzt die Patternprüfung.
2. `USP_PrepareDatabaseCandidates` bestimmt sichtbare Online-Datenbanken nach den Datenbank- und Systemdatenbankfiltern und prüft `PHYSICAL_STATS_DEEP` mit Bestätigung und Gruppenfreigabe. Eine zusätzliche Klasse `CROSS_DATABASE_DEEP` wird in diesem Aufrufpfad nicht geprüft.
3. In `GEZIELT` weist SELECT eine passende ObjectId aus `sys.objects` und `sys.schemas` einer Variablen zu. Mehrere Treffer garantieren keine bestimmte Auswahl; ohne Treffer wird kein NULL-Wildcardaufruf ausgeführt. `VOLL` lässt ObjectId NULL.
4. Die DMF erhält Datenbank-ID, gezielte Objekt-ID sowie optionale Index-/Partitions-ID und Scanmodus.
5. Erst auf den gelieferten DMF-Zeilen wirken Mindestpages, Mindestfragmentierung und bei breitem Modus Namenspattern; danach werden die größten Strukturen sortiert und je Datenbank begrenzt.
6. Fehler und Zeilenzahl werden je Datenbank protokolliert, anschließend als CONSOLE, RAW, TABLE oder JSON ausgegeben.

### Source Select

Die kostenentscheidende Struktur ist die gezielte Katalogauflösung vor dem Physical-Stats-Aufruf:

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
IF @TargetObjectId IS NULL
    THROW 50001, N'Das beabsichtigte Beispielobjekt ist nicht sichtbar; kein breiter DMF-Aufruf.', 1;

SELECT
      [ps].[object_id]
    , [ps].[index_id]
    , [ps].[partition_number]
    , [ps].[page_count]
    , [ps].[avg_fragmentation_in_percent]
    , [ps].[avg_page_space_used_in_percent]
FROM [sys].[dm_db_index_physical_stats]
     (DB_ID(), @TargetObjectId, NULL, NULL, N'LIMITED') AS [ps]
WHERE [ps].[page_count] >= @MinPageCount;
```

**Wichtig für die Eigenlast:** Objekt-ID, optional Index und Partition vor dem DMF-Aufruf bestimmen. `LIMITED` klein beginnen; Mindestpages und Fragmentierungsfilter wirken erst auf gelieferten DMF-Zeilen und verhindern den physischen Scan nicht.

### Zeit- und Scope-Modell

Die Messung gilt für den physischen Zustand während des Aufrufs. Gleichzeitige DML, Page Splits, Ghost Cleanup oder Wartung können Werte während eines längeren Scans verändern; es gibt keinen transaktional eingefrorenen Strukturzeitpunkt. Es existiert kein kumulativer Resetzähler. Der Scope folgt expliziter Datenbank-, Objekt-, Index- und Partitionsauswahl sowie dem Scanmodus.

### Bewertung und Gegenprobe

Page Count ist der erste Nenner. Bewerten Sie danach Dichte und Fragmentierung auf derselben Partition und Ebene. Nutzung und Auswirkung werden unabhängig über `USP_IndexUsage`, Query Store, konkrete Pläne und I/O- und Cacheevidenz bestätigt. Planen Sie für einen Wartungsentscheid zusätzlich Logwachstum, AG und Replikation, Blocking, Onlinefähigkeit, TempDB, Wartungsfenster und einen beobachtbaren Vorher-Nachher-Effekt ein.

### Typische Fehlinterpretation

Pauschale 5-/30-Prozent-Schwellen sind keine universelle Engineentscheidung. Das Addieren von Pages über Leaf-, Nonleaf- und Allocation-Unit-Zeilen kann doppelte oder fachlich inkompatible Größen erzeugen. Ein niedriger Fill Factor kann beabsichtigt sein. `TOP 100` macht einen vorangegangenen `DETAILED`-Scan nicht klein.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_IndexUsage` für Nutzung, `USP_IndexOperationalStats` für betriebliche Zugriffsmuster, Query Store und `USP_ShowplanAnalysis` für betroffene Queries. Formulieren Sie erst bei bestätigter Auswirkung eine Wartungsstrategie mit Ressourcenbudget und Rollback.

## Primärquellen

- [sys.dm_db_index_physical_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-db-index-physical-stats-transact-sql?view=sql-server-ver17)
- [Optimieren der Indexwartung](https://learn.microsoft.com/en-us/sql/relational-databases/indexes/reorganize-and-rebuild-indexes?view=sql-server-ver17)

[Technische Detailbeschreibung](../03_Object_Index.md#9-monitorusp_indexphysicalstats)
