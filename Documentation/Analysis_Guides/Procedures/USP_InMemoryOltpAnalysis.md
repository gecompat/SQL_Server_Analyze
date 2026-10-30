# [monitor].[USP_InMemoryOltpAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen<br>
**Zweck:** Analysiert XTP-Tabellen, Hashindizes, Checkpoints, Transaktionen und Resource Pools.<br>
**Beobachtungsart:** Runtime- und Katalogsnapshot<br>
**Kostenklasse:** MEDIUM–HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure beantwortet die Betriebsfrage: **Wie sind Memory-Optimized-Objekte, Indizes, Memoryverbrauch und Persistenz-/Checkpointpfade konfiguriert und belastet?** Sie unterstützt die Entscheidung, ob das Spezialfeature vorhanden und in einem auffälligen Zustand ist und welches featureeigene Diagnoseverfahren als Nächstes gebraucht wird.

## Nicht beantwortete Fragen

Die Procedure beantwortet keine fachliche Korrektheit der Featurekonfiguration, keine geschützten Inhalte und keine End-to-End-Funktionsprüfung außerhalb sichtbarer Metadaten. Der Zeitvertrag ist im Abschnitt „Zeit- und Scope-Modell“ konkretisiert. Ein Einzelwert gilt daher nur für diesen Scope und Zeitpunkt; er belegt weder eine Ursache noch eine Entwicklung.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InMemoryOltpAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @MitHashIndexStats = 0,
      @ResultSetArt = 'CONSOLE';
```

Alle `Example*`-Werte im Aufruf sind synthetisch.

### Parametervertrag

| Parameter | Typ und Default | Eingabeform, zulässige Werte und Wirkung |
|---|---|---|
| `@DatabaseNames` | `nvarchar(max)`; Default=NULL | Eingabe: bracket-aware Pipe-Liste einteiliger Datenbanknamen (sysname, maximal 128 Zeichen je Element); `]]` maskiert `]`, äußere Elementleerzeichen werden entfernt. NULL, leer oder nur Leerzeichen bedeutet keine Listenbegrenzung; Vergleiche case-sensitiv. Duplikate/leere Elemente ungültig. Standard wählt sichtbare Online-Benutzerdatenbanken; Systemdatenbanken bleiben ausgeschlossen, solange `@SystemdatenbankenEinbeziehen=1` fehlt. Mit `@DatabaseNamePattern` exklusiv. Das Zeichen `\|` trennt nur außerhalb von `[...]`; in `[...]` bleibt `\|` im Namen, und `]]` maskiert ein inneres `]`. |
| `@SystemdatenbankenEinbeziehen` | `bit`; Default=0 | Eingabe: 0 oder 1. 0 schließt master, tempdb, model und msdb aus; 1 lässt diese Systemdatenbanken zu. Andere konvertierbare numerische Nichtnullwerte werden zu 1. NULL ist im Kandidatenpfad INVALID_PARAMETER. |
| `@DatabaseNamePattern` | `nvarchar(4000)`; Default=NULL | NULL bedeutet kein Patternfilter. Eingabe: ein Patterntext. Unpräfigiert oder `like:` = SQL LIKE (`%`, `_`, Zeichenklassen `[...]`, case-sensitiv); `regex:` = case-sensitive Regex; `regexi:` = case-insensitive Regex. Präfixe werden case-insensitive erkannt; äußere Eingabeleerzeichen werden zuvor entfernt, Patterninhalt nach Präfixentfernung nicht erneut getrimmt. Leerer Inhalt ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Mit `@DatabaseNames` exklusiv. |
| `@HighImpactConfirmed` | `bit`; Default=0 | Eingabe: 0 oder 1. 0 bestätigt keinen zusätzlichen High-Impact-Pfad; 1 bestätigt dessen Nutzung, wenn ein geschützter Pfad tatsächlich aktiviert ist. Diese Bestätigung ist von der unabhängigen Gruppenautorisierung getrennt und verleiht keine Gruppenmitgliedschaft oder Freigabe. NULL ist im Datenbankauswahlpfad ungültig. |
| `@SchemaNames` | `nvarchar(max)`; Default=NULL | Eingabe: bracket-aware Pipe-Liste einteiliger Schemanamen (sysname, maximal 128 Zeichen je Element); `]]` maskiert `]`, äußere Elementleerzeichen werden entfernt; case-sensitiver Vergleich. NULL bedeutet kein Filter; leere Liste/Elemente, Duplikate und ungültige/mehrteilige Namen sind ungültig. Mit `@SchemaNamePattern` und `@FullObjectNames` exklusiv. Das Zeichen `\|` trennt nur außerhalb von `[...]`; in `[...]` bleibt `\|` im Namen, und `]]` maskiert ein inneres `]`. |
| `@SchemaNamePattern` | `nvarchar(4000)`; Default=NULL | NULL bedeutet kein Patternfilter. Eingabe: ein Patterntext. Unpräfigiert oder `like:` = SQL LIKE (`%`, `_`, `[...]`, case-sensitiv); `regex:` = case-sensitive Regex; `regexi:` = case-insensitive Regex. Präfixerkennung case-insensitive; äußere Eingabeleerzeichen werden entfernt, Rest nicht erneut getrimmt. Leerer Inhalt ungültig. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Mit `@SchemaNames` exklusiv; mit `@FullObjectNames` kombinierbar. |
| `@ObjectNames` | `nvarchar(max)`; Default=NULL | Eingabe: bracket-aware Pipe-Liste einteiliger Objektnamen (sysname, maximal 128 Zeichen je Element); `]]` maskiert `]`, äußere Elementleerzeichen werden entfernt; case-sensitiver Vergleich. NULL bedeutet kein Filter; leere Liste/Elemente, Duplikate und ungültige/mehrteilige Namen sind ungültig. Mit `@ObjectNamePattern` und `@FullObjectNames` exklusiv. Das Zeichen `\|` trennt nur außerhalb von `[...]`; in `[...]` bleibt `\|` im Namen, und `]]` maskiert ein inneres `]`. |
| `@ObjectNamePattern` | `nvarchar(4000)`; Default=NULL | NULL bedeutet kein Patternfilter. Eingabe: ein Patterntext. Unpräfigiert oder `like:` = SQL LIKE (`%`, `_`, `[...]`, case-sensitiv); `regex:` = case-sensitive Regex; `regexi:` = case-insensitive Regex. Präfixerkennung case-insensitive; äußere Eingabeleerzeichen werden entfernt, Rest nicht erneut getrimmt. Leerer Inhalt ungültig. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Mit `@ObjectNames` exklusiv; mit `@FullObjectNames` kombinierbar. |
| `@FullObjectNames` | `nvarchar(max)`; Default=NULL | Eingabe: bracket-aware Pipe-Liste mit verpflichtendem Objektnamen (jeder Bestandteil ist sysname bis 128 Zeichen): `Objekt`, `Schema.Objekt` oder `Datenbank.Schema.Objekt`; nur Qualifier dürfen fehlen. `]]` maskiert `]`; Vergleiche case-sensitiv. NULL bedeutet kein Filter; leere Liste/Elemente und Duplikate ungültig. Drei Teile verlangen Schema; vier Teile ungültig. PARSENAME prüft Struktur, keine vollständige Bezeichnergrammatik. Mit `@SchemaNames` und `@ObjectNames` exklusiv; passende Schema-/Objektpattern dürfen zusätzlich wirken. Das Zeichen `\|` trennt nur außerhalb von `[...]`; in `[...]` bleibt `\|` im Namen, und `]]` maskiert ein inneres `]`. |
| `@MitHashIndexStats` | `bit`; Default=0 | Eingabe: 0 oder 1. 0 lässt `sys.dm_db_xtp_hash_index_stats` aus; 1 aktiviert die optionale vollständige Hashindex-DMV-Auswertung und `CATALOG_DEEP`. Die DMV kann vollständige In-Memory-Tabellen scannen; `@MaxZeilen` begrenzt diese Arbeit nicht. `@HighImpactConfirmed=1` und, soweit Policy verlangt, unabhängige Gruppenautorisierung erforderlich. NULL ungültig. |
| `@NurProblematisch` | `bit`; Default=0 | Eingabe: 0 oder 1. 0 filtert Problemscope nicht; Findings sind INFO/WARN, Details können NONE enthalten. 1 wählt WARN-Findings und WARN-Detailzeilen; TableMemory bleibt leer, da es nur INFO/NONE liefert, und MemoryConsumer-Details ohne Severity entfallen. Status, Findingszähler und Quellzeilenzahlen bleiben vollständig. NULL ungültig. |
| `@MinTableMemoryMb` | `decimal(19,2)`; Default=1024 MB | Eingabe: nichtnegative MB-Zahl bis 99999999999999999.99. Verfügbare Summe `TableUsedMb + IndexUsedMb >= Wert` erzeugt `LARGE_MEMORY_CONSUMER_CONTEXT` als INFO. Bei 0 greift der Vergleich ab 0; SQL-NULL wird nicht zu 0 konvertiert und erzeugt keinen FindingCode über diesen Vergleich. NULL Parameter ungültig. |
| `@HashAvgChainWarn` | `decimal(19,4)`; Default=10 Kettenglieder | Eingabe: Zahl von 1 bis 100000. WARN bei `AverageChainLength > Wert` (strikt größer). 0 und NULL ungültig. |
| `@HashMaxChainWarn` | `bigint`; Default=100 Kettenglieder | Eingabe: Ganzzahl von 1 bis 9223372036854775807. WARN bei `MaxChainLength >= Wert`. 0 und NULL ungültig. |
| `@HashMinEmptyBucketPercent` | `decimal(9,4)`; Default=10 Prozent | Eingabe: Prozentzahl von 0 bis 100. WARN bei `EmptyBucketPercent < Wert` (strikt kleiner). Bei 0 löst dieser Vergleich keine Warnung aus. NULL ungültig. |
| `@WaitingCheckpointWarnMb` | `decimal(19,2)`; Default=1024 MB | Eingabe: nichtnegative MB-Zahl bis 99999999999999999.99. WARN wenn aggregierte Dateigröße im Zustand WAITING FOR LOG TRUNCATION `>= Wert` ist. Bei 0 wird jede passende Zeile mit verfügbarem Größenwert gewarnt. NULL ungültig. |
| `@ActiveTransactionWarnCount` | `int`; Default=100 Transaktionen | Eingabe: Ganzzahl von 1 bis 2147483647. WARN für ACTIVE/VALIDATING, wenn die aggregierte Anzahl `>= Wert` ist. 0 und NULL ungültig. |
| `@PoolUsedWarnPercent` | `decimal(9,4)`; Default=80 Prozent | Eingabe: Prozentzahl von 0 bis 100. WARN für benannte Pools bei Used/Target `>= Wert` oder OutOfMemoryCount > 0. Bei 0 greift der Auslastungsvergleich bei verfügbarem Quotienten. Kein Herstellerlimit oder Autotuningwert. NULL ungültig. |
| `@MaxZeilen` | `int`; Default=2000 Zeilen je Findings-/Detailresultset | Eingabe: NULL oder 0 = unbegrenzt; 1 bis 2147483647 = Limit je einzelnem Findings-/Detailresultset; negativ ist `INVALID_PARAMETER`. Wirkt nach jeweiliger Sortierung und begrenzt weder Status-/Quellenzähler noch Quellarbeit/Hash-DMV-Scan. |
| `@LockTimeoutMs` | `int`; Default=0 Millisekunden | Eingabe: Ganzzahl 0 bis 60000. 0 bedeutet NOWAIT; positive Werte geben den Lock-Timeout für datenbankbezogene Abfragen an. Danach wird der Sitzungswert auf 0 zurückgesetzt. NULL und Werte außerhalb des Bereichs sind `INVALID_PARAMETER`. |
| `@ResultSetArt` | `varchar(16)`; Default=CONSOLE | Eingabe: getrimmter, case-insensitiver Auswahlwert. Zulässige Menge exakt CONSOLE (formatiertes Findingsresultat), RAW (Meta-, Status-/Quellen- und sieben fachliche Resultsets), TABLE (nur findings in das benannte Ziel), NONE (keine Resultsets). Keine weiteren Werte; NULL ungültig. JSON ist unabhängig. |
| `@ResultTablesJson` | `nvarchar(max)`; Default=NULL | Eingabeform bei TABLE: JSON-Objekt mit genau einem Key `findings` und einem Stringziel: Name einer vorhandenen, leeren lokalen `#`-Temp-Tabelle mit genau einer beliebigen Seed-Spalte. Keine `##`-, permanenten, `#Monitor*`- oder über 116 Zeichen langen Ziele. NULL/leerer Inhalt ist bei TABLE ungültig; außerhalb TABLE darf nur NULL/leerer Text stehen. |
| `@JsonErzeugen` | `bit`; Default=0 | Eingabe: 0 lässt JSON aus; 1 erzeugt die JSON-Ausgabe unabhängig von `@ResultSetArt`. Andere numerische Nichtnullwerte konvertieren zu 1; NULL ungültig. |
| `@Json` | `nvarchar(max)`; Default=NULL OUTPUT | Kein Eingabewert. Optionaler OUTPUT-Empfang; wenn der Aufrufer JSON entgegennehmen will, als OUTPUT binden. Procedure setzt den gebundenen Wert beim Einstieg einschließlich Hilfe auf NULL. Objektform: `meta` plus neun Arrays `databaseStatus`, `sourceStatus`, `findings`, `tableMemory`, `hashIndexes`, `memoryConsumers`, `checkpointFiles`, `transactions`, `resourcePools`; NULL-Properties werden ausgelassen. |
| `@PrintMeldungen` | `bit`; Default=1 | Eingabe: 0 unterdrückt normale Status-PRINTs; 1 gibt sie bei Status außerhalb AVAILABLE/NOT_APPLICABLE aus. Andere numerische Nichtnullwerte werden zu 1; NULL ungültig. Steuert nicht die Hilfe-PRINTs. |
| `@Hilfe` | `bit`; Default=0 | Eingabe: 0 führt normal aus; 1 druckt Hilfe und kehrt nach einem etwaigen TABLE-Preflight früh zurück. Andere numerische Nichtnullwerte werden zu 1. NULL folgt normalem Pfad, keine NULL-Fehlermeldung. Im Hilfe-RETURN bleibt `@Json` NULL und vier gebundene Status-/Fehler-OUTPUT-Werte bleiben unverändert. |
| `@StatusCodeOut` | `varchar(40)`; Default=NULL OUTPUT | Kein Eingabewert. Optional OUTPUT binden, um den Modulstatus beim normalen Abschluss zu empfangen; ungebunden kein Rückgabewert. Im Hilfe-RETURN unverändert. |
| `@IsPartialOut` | `bit`; Default=NULL OUTPUT | Kein Eingabewert. Optional OUTPUT binden, um Partialität (0 oder 1) beim normalen Abschluss zu empfangen; ungebunden kein Rückgabewert. Im Hilfe-RETURN unverändert. |
| `@ErrorNumberOut` | `int`; Default=NULL OUTPUT | Kein Eingabewert. Optional OUTPUT binden, um eine verfügbare SQL-Fehlernummer oder NULL ohne Fehler zu empfangen; ungebunden kein Rückgabewert. Im Hilfe-RETURN unverändert. |
| `@ErrorMessageOut` | `nvarchar(2048)`; Default=NULL OUTPUT | Kein Eingabewert. Optional OUTPUT binden, um verfügbaren Fehlertext oder NULL ohne Meldung zu empfangen; ungebunden kein Rückgabewert. Im Hilfe-RETURN unverändert. |
Alle Bitparameter werden durch T-SQL vor dem Procedureaufruf numerisch zu bit konvertiert: 0 bleibt 0, ein anderer konvertierbarer Zahlenwert wird 1. NULL ist je Parameter und aktivem Pfad gesondert validiert; es gibt keinen einheitlichen NULL-Vertrag für Bitparameter. Die sieben Schwellen sind heuristische Momentaufnahmevergleiche, keine Herstellerlimits oder automatischen DDL-, Bucket-, Memory- oder Kapazitätsempfehlungen.

Die JSON-Hülle enthält `meta`, `databaseStatus`, `sourceStatus`, `findings`, `tableMemory`, `hashIndexes`, `memoryConsumers`, `checkpointFiles`, `transactions` und `resourcePools`. `@JsonErzeugen=1` funktioniert auch mit `@ResultSetArt='NONE'`; NULL-Properties bleiben gemäß FOR JSON PATH ausgelassen. Die Status-/Fehler-OUTPUT-Bindungen sind unabhängig davon.

Beispiel für den unabhängigen JSON-OUTPUT-Vertrag:

```sql
DECLARE @InMemoryJson nvarchar(max);
EXEC [monitor].[USP_InMemoryOltpAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'NONE',
      @JsonErzeugen = 1,
      @Json = @InMemoryJson OUTPUT;
```

Beispiel für den einzelnen TABLE-Key und ein leeres lokales Seed-Ziel:

```sql
CREATE TABLE #InMemoryOltpAnalysis_HelpExample (Placeholder int NULL);
EXEC [monitor].[USP_InMemoryOltpAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ResultSetArt = 'TABLE',
      @ResultTablesJson = N'{"findings":"#InMemoryOltpAnalysis_HelpExample"}';
```

Die Beispiele verwenden synthetische Datenbank- und Temp-Tabellennamen. Exec-Parameter im gedruckten SQL-Hilfetext sind Konstanten oder Variablen; Verkettungen und Funktionsaufrufe stehen nicht direkt als Argument.

## Resultsets und Leserichtung

Der typisierte TABLE-Vertrag registriert ausschließlich `findings`; die elf Textspalten verwenden die Frameworkcollation. Die JSON-Hülle enthält unabhängig von `@ResultSetArt` die zehn Schlüssel `meta`, `databaseStatus`, `sourceStatus`, `findings`, `tableMemory`, `hashIndexes`, `memoryConsumers`, `checkpointFiles`, `transactions` und `resourcePools`. RAW liefert Status-/Quellenresultsets und die sieben fachlichen Detailresultsets. CONSOLE rendert Findings; TABLE schreibt den Findings-Export in das benannte Ziel; NONE unterdrückt Resultsets. `@NurProblematisch = 1` filtert Findings und Detailausgaben auf WARN; TableMemory entfällt, weil seine Zeilen INFO/NONE sind, und MemoryConsumer-Details entfallen dabei. Status, vollständige Quellzeilenzahlen und Findingszähler werden nicht durch den Problemscope verkürzt. `@MaxZeilen` begrenzt danach Findings und jedes Detailresultset einzeln in dessen dokumentierter Sortierung, nicht Datenbank-/Quellenstatus oder Quellenarbeit. Nicht auswertbare explizite Datenbanknamen behalten ihren Warnstatus und Partialwert. Status, Scope und Warnings sind vor den Fachergebnissen zu lesen. CONSOLE dient der interaktiven Triage; RAW und JSON erhalten den technischen Kontext, während TABLE nur die ausdrücklich benannten stabilen Resultsets schreibt. Resultsets mit unterschiedlicher Zeilengranularität dürfen nicht ungeprüft vereinigt oder summiert werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer XTP-Tabelle, einem Index, Hashstatistik, Checkpointzustand, Transaktionssignal, Pool oder Finding.

## So lesen

Berücksichtigen Sie Tabellenmemory, Bucket Count, Chainlängen, leere Buckets, Checkpointfiles, aktive Transaktionen und Poolauslastung gemeinsam.

## Warum kann das problematisch sein?

Lange Hashketten verursachen mehr Vergleiche; wartende Checkpointdaten oder hohe Poolauslastung können Persistenz-/Memorydruck anzeigen.

## Wann ist es kein Problem?

Große Memorynutzung ist bei bewusst großen XTP-Tabellen normal. Absolute Größe allein genügt nicht.

## Beispiele und Gegenbeispiele

**Synthetischer Problemfall (`Example*`):** Average Chain 20, Max 500, kaum leere Buckets und viele Equality Lookups: Bucketzahl wahrscheinlich zu klein. Prüfen Sie Workload, Indexart, Pool und Checkpoints.

**Ähnlich aussehender Gegenfall:** Große Memorynutzung ist bei bewusst großen XTP-Tabellen normal. Absolute Größe allein genügt nicht. Der gleiche Einzelwert kann deshalb bei `ExampleDb` ohne Nutzerauswirkung unkritisch sein, während er bei zeitgleicher SLA-Verletzung eine Vertiefung rechtfertigt.

## Leere oder partielle Ausgabe

Nicht installiert, nicht aktiviert, in der gewählten Datenbank nicht verwendet und nicht abfragbar sind vier verschiedene Zustände.

Für `USP_InMemoryOltpAnalysis` gilt zusätzlich: **keine Zeile** bedeutet, dass im sichtbaren und gefilterten Scope kein ausgabefähiger Datensatz entstand. **0** ist ein gemessener Nullwert nur dann, wenn die Quellspalte tatsächlich verfügbar war. **NULL** bedeutet unbekannt, nicht anwendbar oder nicht auflösbar. **PARTIAL/Warning** bedeutet, dass mindestens eine Teilquelle, Datenbank oder Detailstufe fehlt. Ein Limit kann eine nichtleere Quelle vollständig aus dem sichtbaren Ausschnitt verdrängen.

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | MEDIUM–HIGH_OPT_IN |
| Standardpfad | Eine `ExampleDatabase`, Problemscope, Objektfilter und `@MitHashIndexStats = 0`; gelesen werden Kataloge und die übrigen XTP-Snapshot-DMVs. |
| Teuerster Pfad | Alle sichtbaren Datenbanken ohne Objektfilter, unbegrenzte Ausgabe und `@MitHashIndexStats = 1`. Die Hashindex-DMV kann nach Produktdokumentation vollständige In-Memory-Tabellen scannen. |
| Haupttreiber | Zahl gewählter Datenbanken, speicheroptimierter Tabellen/Indizes, XTP-Memory-Consumer, Checkpointdateien und aktueller XTP-Transaktionszeilen. Nutzdatenzeilen werden nicht gelesen, doch große Checkpoint-/Consumerinventare verbreitern den Runtimepfad. |
| Skalierung | Basispfad wächst mit In-Memory-Tabellen, Speicherconsumern, Checkpointdateien und aktiven XTP-Transaktionen. Der opt-in Hashpfad wächst zusätzlich mit den zu scannenden Tabellen-/Indexstrukturen und kann dominant werden. |
| Ressourcen | CPU und Speicher für XTP-DMVs, Katalog-/Checkpointmetadaten, dynamisches SQL und temporäre Resultate; der Hashpfad kann erhebliche CPU-/Speicherzugriffe in In-Memory-Tabellen verursachen. |
| Begrenzungswirkung | Datenbankfilter begrenzen die ausgewählten Quellen. Objektfilter begrenzen Tabellenmemory und Hashindexkataloge; Memory-Consumer, Checkpointdateien und Transaktionen werden weiterhin datenbankweit aggregiert. `@MaxZeilen` wird erst je fertigem Resultset angewandt. Insbesondere begrenzt es den Tabellenvollscan von `sys.dm_db_xtp_hash_index_stats` nicht. |
| Locking und Nebenwirkungen | Rein lesend; keine XTP-DDL oder Datenänderung. Runtime-DMVs sind flüchtig und nicht atomar. Der Hashindexscan kann trotz fehlender Benutzerlocks spürbare Konkurrenz um CPU/Speicher erzeugen. |
| Schutzmechanismus | Der Code prüft die Analyseklassen `CATALOG_DEEP`, `OBJECT_ANALYSIS_CURRENT`. Verlangt deren Policy ein Gruppengate, ist zusätzlich `@HighImpactConfirmed = 1` nötig; Freigabe und Bestätigung ersetzen keine Scopebegrenzung. |
| Sicherer Einsatz | Eine bekannte `ExampleDatabase`, enger Objektfilter und Hashstatistik aus. Den Hashpfad erst nach Baseline, außerhalb der Lastspitze und mit `@HighImpactConfirmed = 1` aktivieren. |
| Aussagegrenze | Scope- oder Zeilenbegrenzungen können relevante, seltene oder später einsortierte Zeilen ausblenden. Die Aussage bleibt auf das Modell „Runtime- und Katalogsnapshot“, die dokumentierte Granularität und den sichtbaren Quellenscope begrenzt; ein kleines Resultset ist weder automatisch vollständig noch repräsentativ. |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie sind Memory-Optimized-Objekte, Indizes, Memoryverbrauch und Persistenz-/Checkpointpfade konfiguriert und belastet?

### Technischer Hintergrund

In-Memory OLTP speichert Rows in Memory und nutzt MVCC statt klassischer Page Locks/Latches. Hashindizes verteilen Schlüssel auf Buckets; Rangeindizes verwenden Bw-Trees. Durable Tabellen schreiben Log und Checkpoint File Pairs; SCHEMA_ONLY nicht. Garbage Collection entfernt nicht mehr sichtbare Versionen.

### Datenkette

`sys.databases`, `sys.dm_db_xtp_checkpoint_files`, `sys.dm_db_xtp_hash_index_stats`, `sys.dm_db_xtp_memory_consumers`, `sys.dm_db_xtp_table_memory_stats`, `sys.dm_db_xtp_transactions`, `sys.dm_resource_governor_resource_pools`, `sys.filegroups`, `sys.hash_indexes`, `sys.schemas`, `sys.sp_executesql`, `sys.table_types`, `sys.tables`.

### Source Select

Der Speicherpfad verbindet Memory-Optimized-Tabellen mit den XTP-Tabellenstatistiken:

```sql
SELECT
      [s].[name] AS [SchemaName]
    , [t].[name] AS [TableName]
    , [m].[memory_allocated_for_table_kb]
    , [m].[memory_used_by_table_kb]
    , [m].[memory_allocated_for_indexes_kb]
    , [m].[memory_used_by_indexes_kb]
FROM [sys].[tables] AS [t] WITH (NOLOCK)
JOIN [sys].[schemas] AS [s] WITH (NOLOCK)
  ON [s].[schema_id] = [t].[schema_id]
LEFT JOIN [sys].[dm_db_xtp_table_memory_stats] AS [m] WITH (NOLOCK)
  ON [m].[object_id] = [t].[object_id]
WHERE [t].[is_memory_optimized] = 1
  AND [s].[name] = N'ExampleSchema'
  AND [t].[name] = N'ExampleObject';
```

**Wichtig für die Eigenlast:** Ein enger Objektfilter reduziert den Tabellen- und Hashindexausschnitt. Nach positivem Feature-Gate werden Consumer-, Checkpoint- und Transaktionsquellen unabhängig davon datenbankweit gelesen. Der Hashindex-Laufzeitpfad bleibt opt-in; der Objektfilter begrenzt den möglichen DMV-Tabellenscan nicht zuverlässig.

### Zeit- und Scope-Modell

Die Auswertung beschreibt den aktuellen Katalog- und Runtimezustand. Memory-, Transaction- und Checkpointwerte gelten teilweise seit dem Start; der Objektbestand ist aktuell.

### Bewertung und Gegenprobe

Berücksichtigen Sie Table Durability, Rows/Memory, Hash Bucket Count, Empty/Chainverteilung, Indexart, GC/Transactionalter, Checkpointstorage und Database Memoryquota gemeinsam. Hashketten benötigen Datenverteilungs-/Lookupkontext.

### Typische Fehlinterpretation

Viele Empty Buckets allein sind nicht automatisch schlecht; lange Chains sind besonders bei häufigen Equality Lookups relevant. Memory-Optimized heißt nicht logfrei oder ohne Capacitygrenze.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: Current Transactions/Memory, Querypläne, XTP DMVs und Checkpoint-/Logstorage.

## Primärquellen

- [In-Memory OLTP](https://learn.microsoft.com/en-us/sql/relational-databases/in-memory-oltp/overview-and-usage-scenarios?view=sql-server-ver17)

[Technische Detailbeschreibung](../09_Version_Adaptive.md#3-monitorusp_inmemoryoltpanalysis)
