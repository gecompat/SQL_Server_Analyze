# [monitor].[USP_DatabaseSnapshotInventory]

**Bereich:** Server Health  
**Stand:** 15. November 2026  
**Status:** Source- und nativer Vertragskandidat; eine SQL-Laufzeitabnahme ist noch nicht erfolgt.

## Diagnosefrage und Aussagegrenze

Die Procedure inventarisiert caller-sichtbare Datenbank-Snapshots aus master.sys.databases und deren caller-sichtbare Sparse-Dateikatalogzeilen aus master.sys.master_files. Sie erkennt Snapshots an source_database_id IS NOT NULL. SourceDatabaseId bleibt erhalten, auch wenn SourceDatabaseName für den Caller nicht sichtbar ist; der Name bleibt dann NULL. Der Default umfasst sichtbare ONLINE-Snapshots von Benutzerdatenbankquellen.

Der Produktpfad ändert keine persistenten Datenbank- oder Snapshot-Objekte; lokale Temp-DDL dient der Aufbereitung und TABLE-Ausgabe. Er greift weder auf Host-Dateien noch auf sys.dm_io_virtual_file_stats zu. MaximumSnapshotSizePages stammt aus sys.master_files.size und beschreibt die maximale mögliche Snapshot-Dateikapazität, nicht tatsächlich belegte Bytes. MaximumSnapshotSizeBytes ist die verlustfreie Multiplikation mit 8192. CatalogCreateDate bleibt ein nativer datetime-Katalogwert ohne UTC-Interpretation. Eine Umbenennung kann seinen Zeitbezug verändern. Die Procedure beurteilt kein verlässliches Alter, keine physische Belegung, kein Wachstum über die Zeit, keine Quellgesundheit, Snapshot-Nutzbarkeit, Restore-Eignung oder globale Vollständigkeit. Die beiden Kataloglesungen sind nicht atomar.

Für die Sicht auf eine Zeile in sys.master_files werden mindestens CREATE DATABASE, ALTER ANY DATABASE oder VIEW ANY DEFINITION benötigt. Ein sichtbarer Snapshot ohne sichtbare Sparse-Dateizeile erhält VisibleSparseFileCount=NULL und FileMetadataStatus=SOURCE_UNAVAILABLE; das ist kein Nullbestand. Native Namen und Dateipfade erscheinen vollständig in der angeforderten flüchtigen Runtime-Ausgabe. Repositorybeispiele bleiben synthetisch.

## Parameter

| Parameter | Typ, Default und Eingabe | Wirkung |
|---|---|---|
| @SnapshotNames | nvarchar(max), Default NULL. NULL, leer oder nur äußere U+0020-Leerzeichen wählen alle sichtbaren Snapshots. Sonst bracket-aware Pipe-Liste einteiliger Namen: Pipe innerhalb von [...] ist Inhalt, ]] maskiert ]. Rohsegment höchstens 4000 UTF-16-Einheiten, Name höchstens 128 Zeichen. | Exakt und case-sensitiv. Leere, ungültige oder doppelte Elemente ergeben INVALID_PARAMETER. Ausgelassen gilt NULL; kein Patternparameter. |
| @NurOnline | bit, Default 1. 1 wählt nur ONLINE, 0 alle sichtbaren Katalogzustände; NULL ungültig. | Ausgelassen gilt 1. Numerisch ungleich 0 wird durch SQL Server zu 1 konvertiert. Andere Katalogzustände belegen keine Nutzbarkeit. |
| @SystemdatenbankenEinbeziehen | bit, Default 0. 0 verlangt SourceDatabaseId größer 4; 1 lässt zulässige Systemquellen zu. NULL ungültig. | Ausgelassen gilt 0; numerisch ungleich 0 wird 1. Sichtbarkeit bleibt erforderlich. |
| @MaxZeilen | int, Default 1000. Positiv begrenzt Snapshot-Zeilen nach SnapshotDatabaseId; NULL und 0 unbegrenzt, negativ ungültig. | Alle sichtbaren Dateizeilen je ausgegebenem Snapshot bleiben zusammen. Katalogarbeit vor dem Ausgabelimit bleibt vollständig. OUTPUT_LIMIT warnt bei Kürzung. |
| @LockTimeoutMs | int, Default 0. Nur 0 bis 60000 Millisekunden, NULL ungültig. | 0 bedeutet NOWAIT; je Katalogbatch, kein Gesamtlaufzeitbudget. Vorheriger Sessionwert wird wiederhergestellt. |
| @ResultSetArt | varchar(16), Default CONSOLE. SQL Server bindet längere Eingaben bereits vor der Validierung auf höchstens 16 Zeichen. Danach sind nach äußerem U+0020-Trimmen und Großschreibung genau CONSOLE, RAW, TABLE, NONE erlaubt; NULL und leer ungültig. | CONSOLE liefert eine formatierte Menge, RAW fünf Mengen, TABLE gemappte Temp-Ziele, NONE keine Resultsets. |
| @ResultTablesJson | nvarchar(max), Default NULL. Bei TABLE JSON-Objekt mit mindestens einer Zuordnung; exakte Schlüssel moduleStatus, snapshots, snapshotFiles, sourceStatus, warnings; Werte unterschiedliche vorhandene leere lokale #Temp-Ziele mit einer Seed-Spalte, maximal 116 Zeichen, weder ## noch reserviertes #Monitor. | Schlüssel werden binär und doppelte Zielnamen case-insensitiv geprüft. Unbekannte oder doppelte Zuordnungen und ungültige Ziele werden vor Quellenlesung abgewiesen. Außerhalb TABLE nur NULL, leer oder U+0020-Leerzeichen. Ein späterer Writer-Fehler kann bereits geschriebene Ziele hinterlassen; dessen technische Nummer und Meldung bleiben in den Fehler-OUTPUTs erhalten. |
| @JsonErzeugen | bit, Default 0. 1 erzeugt JSON; NULL und 0 keines. | Ausgelassen 0, numerisch ungleich 0 wird 1. JSON ist unabhängig vom Ausgabemodus. |
| @Json | nvarchar(max) OUTPUT, Default NULL. Optional mit OUTPUT binden. | Eingang wird zurückgesetzt. Nur @JsonErzeugen=1 erzeugt im normalen Erfolgspfad meta und fünf Arrays. Hilfe, früher Eingabefehler und äußerer Fehler lassen NULL. |
| @PrintMeldungen | bit, Default 1. 1 meldet ausschließlich einen äußeren CATCH-Fehler mit konstanter Severity-10-Meldung und NOWAIT; NULL und 0 unterdrücken diese Meldung. | Ausgelassen 1, numerisch ungleich 0 wird 1. Status und Resultsets bleiben maßgeblich. |
| @Hilfe | bit, Default 0. 1 druckt Hilfe, NULL und 0 führen den normalen Pfad aus. | Ausgelassen 0, numerisch ungleich 0 wird 1. Hilfe kehrt vor Temp-DDL und Katalogzugriff zurück, auch in einer Caller-Transaktion. |
| @StatusCodeOut | varchar(40) OUTPUT, Default NULL; optional mit OUTPUT binden. | AVAILABLE nur Hilfe; AVAILABLE_LIMITED sichtbare Aufnahme; SKIPPED kein sichtbarer Treffer; INVALID_PARAMETER Eingabe; SOURCE_UNAVAILABLE unbekannte Dateisicht oder Quellenfehler; DENIED_PERMISSION nativer Rechtefehler; TIMEOUT SQL 1222; ERROR_HANDLED äußerer Fehler. Eingang wird zurückgesetzt. |
| @IsPartialOut | bit OUTPUT, Default NULL; optional mit OUTPUT binden. | Hilfe 0, jeder normale Pfad 1 wegen begrenzter Metadatensicht. Eingang wird zurückgesetzt. |
| @ErrorNumberOut | int OUTPUT, Default NULL; optional mit OUTPUT binden. | Nativer Fehler oder 51011 bei direktem Eingabefehler, sonst NULL. Eingang wird zurückgesetzt. |
| @ErrorMessageOut | nvarchar(2048) OUTPUT, Default NULL; optional mit OUTPUT binden. | Fehlertext bis 2048 Zeichen, sonst NULL. Eingang wird zurückgesetzt. |

Der normale Pfad verlangt @@TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF, bevor Temp-Tabellen oder Katalogquellen verwendet werden. Die Procedure erteilt keine Rechte. Sie verwendet den gemeinsamen Namenslistenparser, jedoch nicht den allgemeinen Datenbankkandidatenhelfer: Dieser schließt Datenbank-Snapshots aus.

## Ergebnisgruppen

RAW liefert die Gruppen in dieser Reihenfolge:

1. moduleStatus: ModuleName, CapturedAtUtc, StatusCode, IsPartial, RowCount, Detail.
2. snapshots: SnapshotDatabaseId, SnapshotName, SourceDatabaseId, SourceDatabaseName, CatalogCreateDate, SnapshotStateDesc, IsReadOnly, VisibleSparseFileCount, FileMetadataStatus, MetadataVisibility.
3. snapshotFiles: SnapshotDatabaseId, SnapshotName, FileId, LogicalFileName, PhysicalName, IsSparse, FileStateDesc, MaximumSnapshotSizePages, MaximumSnapshotSizeBytes, MetadataVisibility.
4. sourceStatus: DatabaseId, DatabaseName, SourceKey, SourceKind, StartedAtUtc, CompletedAtUtc, StatusCode, VisibilityScope, ObservedRows, ReturnedRows, IsLimited, ErrorNumber, ErrorMessage.
5. warnings: DatabaseId, DatabaseName, WarningCode, SourceKey, Detail.

MetadataVisibility=VISIBLE_ONLY gilt für zurückgegebene Zeilen, nicht für einen globalen Bestand. VisibleSparseFileCount ist nur bei mindestens einer sichtbaren Sparse-Dateizeile positiv; NULL bedeutet unbekannt. sourceStatus unterscheidet Auswahl- und Dateikatalogquelle. JSON enthält meta und dieselben fünf Gruppen; TABLE schreibt die ausdrücklich gemappten Gruppen. Eine normale leere Auswahl bleibt SKIPPED und belegt keinen globalen Snapshot-Nullbestand.

## Eine Zeile bedeutet

Eine Zeile in `snapshots` beschreibt genau einen caller-sichtbaren Datenbank-Snapshot. `snapshotFiles` enthält je sichtbarer Sparse-Dateikatalogzeile eine eigene Zeile mit der maximalen Dateikapazität. `sourceStatus` enthält eine `SNAPSHOT_CATALOG`-Zeile und je aufgenommenem Snapshot vor dem Ausgabelimit eine `SNAPSHOT_FILES`-Zeile. Für einen später ausgeblendeten Snapshot kann `ReturnedRows=0` bleiben; bei leerer Auswahl oder frühem Katalogfehler liegt nur die Katalogstatuszeile vor. `warnings` hält begrenzte Sicht- und Ausgabefunde fest.

## So lesen

Prüfen Sie zuerst `moduleStatus` und alle vorhandenen `sourceStatus`-Zeilen. Ordnen Sie danach `snapshotFiles` über `SnapshotDatabaseId` dem Snapshot zu. `SourceDatabaseId` bleibt auch bei verborgenem `SourceDatabaseName` erhalten. Ein NULL in `VisibleSparseFileCount` bedeutet unbekannte Dateisicht; ein kleiner `@MaxZeilen` begrenzt ausgegebene Snapshots, aber keine Dateizeile des behaltenen Snapshots.

## Warum kann das problematisch sein?

Ein Snapshot mit unerwarteter Source-Beziehung, unbekannter Dateisicht oder großer maximaler Sparse-Dateikapazität begründet eine gezielte Prüfung der Katalogsicht und der tatsächlichen Speicherung. Die maximale Kapazität allein belegt weder aktuellen Verbrauch noch einen akuten Speicherengpass.

## Wann ist es kein Problem?

`SKIPPED` bei fehlendem sichtbarem Treffer ist für sich kein Fehler. Auch eine große maximale Sparse-Dateikapazität ist ohne tatsächliche Belegungs- und Betriebsevidenz kein Gesundheitsbefund. Die begrenzte Caller-Sicht erlaubt keinen Schluss auf den globalen Bestand.

## Technische Vertiefung

### Leitfrage

Welche Datenbank-Snapshots und zugehörigen Sparse-Dateikatalogzeilen sind für diesen Caller sichtbar, und welcher Quell-Datenbank-ID sind sie zugeordnet?

### Technischer Hintergrund

`master.sys.databases.source_database_id IS NOT NULL` kennzeichnet Snapshot-Datenbanken. `master.sys.master_files` liefert die caller-sichtbaren Sparse-Dateizeilen. `size` wird in 8-KiB-Seiten als maximale Snapshot-Dateikapazität gelesen; eine physische Nutzungs-DMV wird nicht abgefragt.

### Datenkette

Die Procedure liest zuerst Snapshot- und Quellmetadaten, danach Dateikatalogzeilen für die sichtbaren Kandidaten. Sie erfasst Status und Fehler getrennt, begrenzt anschließend die ausgegebenen Snapshot-Zeilen und behält alle sichtbaren Dateizeilen dieser Auswahl. RAW und JSON geben dieselben fünf fachlichen Gruppen aus; TABLE schreibt nur ausdrücklich gemappte lokale Ziele.

### Source Select

Der Ausschnitt zeigt die Snapshot-Erkennung im Katalog. Die Procedure ergänzt Filter, Fehlergrenzen und den zweiten Dateikatalogread.

```sql
SELECT d.database_id AS SnapshotDatabaseId,
       d.name AS SnapshotName,
       d.source_database_id AS SourceDatabaseId,
       src.name AS SourceDatabaseName,
       d.create_date AS CatalogCreateDate
FROM master.sys.databases AS d WITH (NOLOCK)
LEFT JOIN master.sys.databases AS src WITH (NOLOCK)
  ON src.database_id=d.source_database_id
WHERE d.source_database_id IS NOT NULL;
```

**Wichtig für die Eigenlast:** Die Katalogkandidaten werden vor `@MaxZeilen` gelesen; der Parameter ist kein Quellenbudget. Die zweite Kataloglesung ist nicht atomar mit der ersten. Für die Sicht auf eine Zeile in `sys.master_files` ist eines der dokumentierten Datenbank- oder Serverrechte erforderlich.

### Zeit- und Scope-Modell

`CapturedAtUtc` markiert den Aufnahmebeginn und keine atomare Katalogversion. `CatalogCreateDate` bleibt ein nativer `datetime`-Wert ohne UTC-Deutung; Umbenennung kann seinen Bezug ändern. `MetadataVisibility=VISIBLE_ONLY` gilt nur für zurückgegebene Zeilen.

### Bewertung und Gegenprobe

Vergleichen Sie bei unerwarteten Zeilen `SnapshotDatabaseId`, `SourceDatabaseId` und die sichtbaren `FileId`-Werte unter demselben Caller mit den beiden Systemkatalogen. Für tatsächliche Dateibelegung ist eine gesonderte Quelle erforderlich. Ein nicht sichtbarer Quellname darf nicht durch einen geratenen Namen ersetzt werden.

### Typische Fehlinterpretation

`MaximumSnapshotSizeBytes` ist die maximale mögliche Kapazität der Sparse-Datei, kein gemessener Verbrauch. `VisibleSparseFileCount=NULL` ist kein Dateizähler von null. `CatalogCreateDate` belegt nach einer Umbenennung kein verlässliches Snapshot-Alter.

### Folgeanalyse

Prüfen Sie bei `SOURCE_UNAVAILABLE` den nativen Fehler und die Caller-Rechte. Bei Kapazitätsfragen betrachten Sie tatsächliche Datei- und Volumeevidenz getrennt; bei Restore- oder Gesundheitsfragen verwenden Sie einen ausdrücklich dafür qualifizierten Betriebsvertrag.

Die [Technische Detailbeschreibung](../../../Code/08_ServerHealth/340_USP_DatabaseSnapshotInventory.sql) zeigt den kanonischen Produktcode. Die Seite [Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md) erklärt die allgemeinen Beobachtungsgrenzen.

## Synthetische Aufrufe

~~~sql
EXEC [monitor].[USP_DatabaseSnapshotInventory]
    @SnapshotNames=N'[ExampleSnapshotA]|[ExampleSnapshotB]',
    @ResultSetArt='RAW',@PrintMeldungen=0;
~~~

~~~sql
DECLARE @SnapshotJson nvarchar(max);
EXEC [monitor].[USP_DatabaseSnapshotInventory]
    @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@SnapshotJson OUTPUT;
SELECT @SnapshotJson AS [Json];
~~~

~~~sql
CREATE TABLE #ExampleSnapshotRows([Seed] int NULL);
EXEC [monitor].[USP_DatabaseSnapshotInventory]
    @ResultSetArt='TABLE',
    @ResultTablesJson=N'{"snapshots":"#ExampleSnapshotRows"}';
SELECT * FROM #ExampleSnapshotRows;
DROP TABLE #ExampleSnapshotRows;
~~~

## Primärquellen

- [Microsoft: Sicht auf Datenbank-Snapshots](https://learn.microsoft.com/en-us/sql/relational-databases/databases/view-a-database-snapshot-sql-server?view=sql-server-ver17).
- [Microsoft: sys.databases](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql?view=sql-server-ver17).
- [Microsoft: sys.master_files](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-master-files-transact-sql?view=sql-server-ver17).
