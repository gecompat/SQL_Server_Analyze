# [monitor].[USP_BufferPoolAnalysis]

**Bereich:** Server Health<br>
**Zweck:** Zeigt Memory- und Resource-Semaphore-Snapshotwerte sowie optional Memory Clerks und eine nach Datenbanken gruppierte Buffer-Pool-Verteilung; der Descriptorpfad ist Opt-in.<br>
**Beobachtungsart:** Snapshot<br>
**Kostenklasse:** LOW–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wie verteilt sich der Buffer Pool auf Datenbanken, Objekte und Pagearten, und gibt es Hinweise auf Cache-/Memorydruck?** Sie unterstützt die Entscheidung, ob eine Instanzressource oder Konfiguration als belastbare Spur zum Symptom passt und welche unabhängige OS-, Verlaufs- oder Workloadevidenz fehlt.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine vollständige OS-/Hypervisorursache und ohne Delta oder Verlauf keine belastbare Aussage über einen dauerhaften Engpass. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_BufferPoolAnalysis]
      @MitMemoryClerks = 1,
      @MitBufferPoolVerteilung = 0,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

## Parameter und weitere Aufrufbeispiele

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
|---|---|---|---|
| `@MitMemoryClerks` | `bit` | `1` | NULL, 0 oder 1. Nur 1 liest sys.dm_os_memory_clerks und gruppiert nach Clerktyp; 0/NULL überspringt diese Quelle und ihr Resultset bleibt leer. MemorySnapshot und Resource Semaphores werden unabhängig gesammelt. |
| `@MitBufferPoolVerteilung` | `bit` | `0` | NULL, 0 oder 1. Nur 1 scannt sys.dm_os_buffer_descriptors und aggregiert gecachte Seiten nach Datenbank-ID und aufgelöstem Namen; 0/NULL ist der sichere Standard und überspringt den breiten Descriptorpfad. Die Quelle wird vor Gruppierung gelesen. MaxZeilen begrenzt nicht den Scan. Nicht aufgelöste Datenbanknamen bleiben NULL. |
| `@MaxZeilen` | `int` | `100` | int-Eingabe: NULL oder 0 bedeutet unbegrenzt; positive Werte bis 2147483647 begrenzen Semaphore-, Clerk- und Buffer-Pool-Gruppen ausschließlich in RAW und JSON. Negative Werte sind INVALID_PARAMETER. MemorySnapshot bleibt ungekürzt; CONSOLE liefert nur den vollständigen MemorySnapshot, TABLE schreibt nur diesen Snapshot. Die Grenze folgt auf Sammlung und Aggregation und begrenzt insbesondere den Descriptor-Scan nicht. |
| `@ResultSetArt` | `varchar(16)` | `'CONSOLE'` | NULL oder Text, der nach Trim und Großschreibung CONSOLE, RAW, TABLE oder NONE ergibt. RAW liefert Statuskontext und vier Fachresultsets. CONSOLE wird intern zu NONE normalisiert und ruft danach den Console-Helper nur für MemorySnapshot auf; die direkte CONSOLE-Resultsetansicht im Procedurekörper ist dadurch nicht erreichbar. TABLE wird ebenfalls zu NONE normalisiert und schreibt ausschließlich MemorySnapshot in die lokale Zieltabellenzuordnung; NONE unterdrückt normale Resultsets. NULL/Leertext und andere Werte setzen INVALID_PARAMETER. Nichtleeres Mapping außerhalb TABLE wirft 51011; das TABLE-Mapping wird vor Hilfe und Parameterprüfung vorbereitet. |
| `@ResultTablesJson` | `nvarchar(max)` | `NULL` | NULL oder ein JSON-Objekt mit genau dem Schlüssel memory und einem Stringwert für den Namen einer vorhandenen lokalen #Temp-Tabelle, etwa N'{"memory":"#BufferPoolAnalysis_HelpExample"}'. Für TABLE muss das Ziel leer sein und genau eine beliebig typisierte Seed-Spalte besitzen. NULL, nach Trim von U+0020 leere Eingabe oder fehlerhaftes Mapping scheitern am Preflight vor @Hilfe und Sammlung. Der Preflight prüft das Ziel; erst beim TABLE-Schreiben werden seine Zielspalten eingerichtet. Außerhalb TABLE sind NULL oder nach diesem Trim leere Werte zulässig, sonst wird 51011 geworfen. Globale und permanente Tabellen sowie der reservierte #Monitor-Präfix sind unzulässig. |
| `@JsonErzeugen` | `bit` | `0` | NULL, 0 oder 1. Nur 1 baut zusätzlich JSON in @Json; 0/NULL lässt @Json NULL. Die Gruppen memory, resourceSemaphores, memoryClerks und bufferPool werden unabhängig von der JSON-Ausgabe gesammelt, wenn ihre Quellen eingeschaltet sind. MaxZeilen begrenzt die drei Gruppenarrays, nicht memory. |
| `@Json` | `nvarchar(max) OUTPUT` | `NULL` | OUTPUT-Bindung nvarchar(max), mit vorab deklarierter nvarchar(max)-Variable und OUTPUT zu übergeben. Beim Eintritt wird sie auf NULL gesetzt; nur @JsonErzeugen=1 belegt sie nach Erfassung mit dem JSON-Dokument. Zusätzlicher Rückgabekanal, kein Resultset. |
| `@PrintMeldungen` | `bit` | `1` | NULL, 0 oder 1. Der aktuelle Procedurekörper liest den Parameter nicht; er steuert keine PRINT-Ausgabe. Die Hilfeausgabe wird von @Hilfe gesteuert. |
| `@Hilfe` | `bit` | `0` | NULL, 0 oder 1. Nur 1 druckt Objektname, Snapshotgrenze, Opt-in-Hinweis und Kurzangaben zu Limit/Modi und kehrt vor Quellensammlung zurück. TABLE-Mapping wird davor vorbereitet. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | Optionaler varchar(40)-OUTPUT-Empfang. Werte und Bedeutungen: AVAILABLE (kein gesetzter Finding-, Teil- oder Fehlerstatus), AVAILABLE_WITH_FINDING (Semaphore-Waiter oder Speicher-Finding, sofern der Status zuvor AVAILABLE war), AVAILABLE_LIMITED (optionale Clerk- oder Descriptorquelle fehlerhaft), INVALID_PARAMETER (negatives Zeilenlimit oder ungültiger Ausgabemodus), DENIED_PERMISSION (klassifizierter Berechtigungsfehler einer Kernquelle), ERROR_HANDLED (sonstiger abgefangener Kernquellenfehler). Zuweisung nach Sammlung und vor JSON/Resultsets. Optional zum Empfang mit @StatusCodeOut=@Empfaenger OUTPUT und einer varchar(40)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | Optionaler bit-OUTPUT-Empfang. 1 kennzeichnet ungültige Parameter, klassifizierte Berechtigungsfehler oder sonstige Kernquellenfehler einschließlich ERROR_HANDLED sowie Fehler optionaler Clerk-/Descriptorquellen. Ein optionaler Quellfehler führt zu AVAILABLE_LIMITED. Im regulären Ablauf ohne Teilfehler gilt 0, auch bei AVAILABLE_WITH_FINDING. Das Bit ist kein allgemeiner Vollständigkeitsbeweis. Optional zum Empfang mit @IsPartialOut=@Empfaenger OUTPUT und einer bit-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | OUTPUT-Bindung int. Bei abgefangenem Fehler einer Kernquelle oder optionalen Quelle enthält sie die SQL-Fehlernummer; sonst NULL. Bei mehreren optionalen Fehlern bleibt die erste Nummer erhalten. Mit int-Variable und OUTPUT binden; Hilfe weist nicht zu. Optional zum Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT und einer int-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | OUTPUT-Bindung nvarchar(2048). Enthält abgefangene Kernquellenmeldung oder ersten optionalen Quellenhinweis; sonst NULL. Mit kompatibler Variable und OUTPUT binden; Hilfe weist nicht zu. Optional zum Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT und einer nvarchar(2048)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung. |

### Aufrufbeispiele

Alle Example-Werte und Tabellennamen sind synthetisch.

#### RAW

~~~sql
EXEC [monitor].[USP_BufferPoolAnalysis] @MitMemoryClerks=1,@MitBufferPoolVerteilung=0,@MaxZeilen=50,@ResultSetArt='RAW';
~~~

#### JSON

~~~sql
DECLARE @JsonOut nvarchar(max);
EXEC [monitor].[USP_BufferPoolAnalysis] @MitMemoryClerks=1,@MitBufferPoolVerteilung=0,@JsonErzeugen=1,@Json=@JsonOut OUTPUT,@ResultSetArt='NONE';
SELECT @JsonOut AS [Json];
~~~

#### TABLE

Die Seed-Tabelle mit einer einzelnen Dummy-Spalte wird außerhalb des TRY-Blocks angelegt. Beide Pfade räumen sie mit DROP TABLE IF EXISTS auf.

~~~sql
CREATE TABLE [#BufferPoolAnalysis_HelpExample]([Seed] int NULL);
BEGIN TRY
    EXEC [monitor].[USP_BufferPoolAnalysis] @ResultSetArt='TABLE',@ResultTablesJson=N'{"memory":"#BufferPoolAnalysis_HelpExample"}';
    SELECT * FROM [#BufferPoolAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#BufferPoolAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#BufferPoolAnalysis_HelpExample];
    THROW;
END CATCH;
~~~

#### Hilfe

~~~sql
EXEC [monitor].[USP_BufferPoolAnalysis] @Hilfe=1;
~~~

## Resultsets und Leserichtung

Der TABLE-Vertrag schreibt ausschließlich memory in das benannte vorhandene Ziel. CONSOLE gibt nur die lesbare MemorySnapshot-Fachmenge aus; beide Modi liefern kein separates Modulstatusresultset. RAW enthält den technischen Modulstatus und getrennte Fachmengen. Angefordertes JSON und die OUTPUT-Parameter stellen den technischen Kontext gemäß ihren individuellen Parameterverträgen bereit. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

Die sechs Textspalten der lokalen Arbeitstabellen verwenden explizit
`SQL_Latin1_General_CP1_CS_AS`. Der TABLE-Export `memory` übernimmt diese
Frameworkcollation für seine vier Textspalten auch bei abweichender
Server- oder `tempdb`-Collation. Die optionale JSON-Verteilung bleibt nach
Datenbankkennungen gruppiert; ein in `master.sys.databases` nicht auflösbarer
Name bleibt `NULL`.

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Memoryzusammenfassung, einen Clerk oder eine Datenbank-/Page-Verteilung.

## So lesen

Berücksichtigen Sie Gesamtbuffer, Clerks, Datenbankanteile, Dirty/Clean Pages und Memory Pressure gemeinsam.

## Warum kann das problematisch sein?

Dominante Clerks oder ungewöhnliche Verteilung können Speicher verdrängen; viele Dirty Pages können Checkpoint-/I/O-Druck anzeigen.

## Wann ist es kein Problem?

Eine große aktive Datenbank darf den Buffer Pool dominieren.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** 80 % Buffer für ExampleDatabase ist nicht automatisch schlecht. Problematisch wird es, wenn andere aktive Datenbanken physisch lesen und Memory Pressure besteht. Prüfen Sie Memory, I/O und Query Reads.

**Ähnlich aussehender Gegenfall:** Eine große aktive Datenbank darf den Buffer Pool dominieren. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Server-DMVs können plattform-, editions- oder berechtigungsbedingt fehlen. NULL und PARTIAL sind dann Evidenzgrenzen, keine Nullmessung.

Für `USP_BufferPoolAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | LOW–HIGH_OPT_IN |
| Standardpfad | Memorysummary und begrenzte Clerk-/Semaphore-Sicht ohne Buffer-Pool-Verteilung. |
| Teuerster Pfad | Aktivierte Buffer-Pool-Verteilung auf einer Instanz mit sehr großem Cache; Descriptoren werden vor der Begrenzung ausgegebener Gruppen aggregiert. |
| Haupttreiber | Zahl der Memory-Clerk-Typen und – nur bei aktivierter Verteilung – aller sichtbaren Buffer Descriptors vor der Gruppierung. Memory-/Semaphore-Summary ist klein; ein kleines Ausgabelimit verkürzt den Descriptor-Scan nicht. |
| Skalierung | Laufzeit und CPU wachsen mit dem Haupttreiber. Sortierung/Aggregation erhöht Speicher- und gegebenenfalls TempDB-Bedarf; breite Texte/XML sowie viele Zeilen erhöhen Netzwerk- und Clientkosten. Für USP_BufferPoolAnalysis ist insbesondere die im Datenkettenabschnitt beschriebene Reihenfolge maßgeblich. |
| Ressourcen | SQLOS-DMV-CPU; der optionale Scan von sys.dm_os_buffer_descriptors wächst mit der Zahl gecachter Pages und benötigt Aggregationsspeicher. |
| Begrenzungswirkung | MaxZeilen kürzt Semaphore-, Clerk- und Buffer-Pool-Gruppen nur in RAW und JSON; CONSOLE und TABLE erhalten den ungekürzten MemorySnapshot. Die Descriptorquelle wird vor Gruppierung und Ausgabelimit breit gelesen. |
| Locking und Nebenwirkungen | Keine Nutzdatenlocks oder Cachebereinigung; der breite Descriptor-Scan verbraucht jedoch CPU/Schedulerzeit auf der beobachteten Instanz. |
| Schutzmechanismus | Kein High-Impact-Gate. Der wichtigste Schutz ist, `@MitBufferPoolVerteilung = 0` zu belassen; nur dadurch entfällt der breite Descriptorpfad. `@MitMemoryClerks` steuert die Clerksicht, während `@MaxZeilen` nach der jeweiligen Aggregation lediglich die Ausgabe kürzt. |
| Sicherer Einsatz | Mit @MitBufferPoolVerteilung=0 starten; Verteilung nur nach Summary und außerhalb der Lastspitze aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Snapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie verteilt sich der Buffer Pool auf Datenbanken, Objekte und Pagearten, und gibt es Hinweise auf Cache-/Memorydruck?

### Technischer Hintergrund

Buffer Descriptors repräsentieren gecachte 8-KB-Datenseiten. Verteilung nach Database/File/Page/Object kann Working Set zeigen; Memory Clerks und PLE/Lazy Writes ergänzen Drucksignale. Clean Pages sind verwerfbar, Dirty Pages benötigen Flush.

### Datenkette

`sys.dm_exec_query_resource_semaphores`, `sys.dm_os_buffer_descriptors`, `sys.dm_os_memory_clerks`, `sys.dm_os_process_memory`, `sys.dm_os_sys_memory`.

### Source Select

Der datenbankbezogene Buffer-Pool-Kern entsteht durch Gruppierung der Buffer Descriptors und Zuordnung zur Datenbank:

```sql
SELECT
      [d].[name] AS [DatabaseName]
    , COUNT_BIG(*) AS [CachedPages]
    , COUNT_BIG(*) * 8.0 / 1024.0 AS [CachedMb]
FROM [sys].[dm_os_buffer_descriptors] AS [bd] WITH (NOLOCK)
JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[database_id] = [bd].[database_id]
WHERE [d].[name] = N'ExampleDatabase'
GROUP BY [d].[name];
```

**Wichtig für die Eigenlast:** `sys.dm_os_buffer_descriptors` kann sehr groß sein. Ein Datenbankprädikat reduziert Ergebnis und Aggregation, garantiert aber nicht, dass die Engine die DMV intern nur teilweise materialisiert; deshalb den Detailpfad bewusst verwenden.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Cachebestand; dieser verändert sich fortlaufend durch Reads, Writes, Checkpoints und Memory Pressure.

### Bewertung und Gegenprobe

Berücksichtigen Sie Cached MB und Pages, Dirtyanteil, Datenbank- und Objektanteil, Page Life und Reads, OS- und Prozessdruck sowie Workloadgröße gemeinsam. Ein dominanter Cacheanteil kann ein legitimes Working Set darstellen.

### Typische Fehlinterpretation

Bufferanteil ist keine Hit Ratio und häufig gecacht bedeutet nicht automatisch problematisch. Breiter Descriptor-Scan kann selbst CPU/Memory/I/O-Metadatenlast erzeugen.

### Folgeanalyse

Verwenden Sie für die weitere Analyse Server Memory, Performance Counters sowie Query Reads und Plans. Aktivieren Sie den Deep-Pfad nur kontrolliert.

## Primärquellen

- [sys.dm_os_buffer_descriptors](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-views/sys-dm-os-buffer-descriptors-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../08_Server_Health.md#16-monitorusp_bufferpoolanalysis)
