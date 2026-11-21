---
skill_format_version: "1.0.0"
name: "monitor.USP_Columnstore"
schema_name: "monitor"
object_name: "USP_Columnstore"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Analysiert Columnstore-Indizes, Rowgroups und Deleted Rows; Physical Stats, Segmente und Dictionaries sind explizite gruppengeschützte Vertiefungen."
source_path: "Code/03_ObjectIndex/060_USP_Columnstore.sql"
---

# monitor.USP_Columnstore

## Zweck und Einsatz

Analysiert Columnstore-Indizes, Rowgroups und Deleted Rows; Physical Stats, Segmente und Dictionaries sind explizite gruppengeschützte Vertiefungen.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

Je Datenbank sys.column_store_row_groups, sys.index_columns (geordnete Metadaten), optional sys.dm_db_column_store_row_group_physical_stats, sys.column_store_segments, sys.column_store_dictionaries sowie Systemkataloge.

Basis gemäß Metadata Visibility/VIEW DEFINITION; Physical Stats SQL 2019 VIEW DATABASE STATE plus CONTROL, SQL 2022+ VIEW DATABASE PERFORMANCE STATE; Detailwerte können SELECT erfordern. Datenbankauswahl prüft COLUMNSTORE_CURRENT. Physical-/Segment-/Dictionaryoptionen und Segmentüberlappung prüfen COLUMNSTORE_DEEP; VOLL prüft zusätzlich CATALOG_DEEP. Aktuelle Freigabe und ein ggf. erforderliches High-Impact-Gate werden separat geprüft.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @SchemaNames | nvarchar(max) | nein | NULL |
| @SchemaNamePattern | nvarchar(4000) | nein | NULL |
| @ObjectNames | nvarchar(max) | nein | NULL |
| @ObjectNamePattern | nvarchar(4000) | nein | NULL |
| @FullObjectNames | nvarchar(max) | nein | NULL |
| @AnalyseModus | varchar(16) | nein | 'GEZIELT' |
| @MitPhysicalStats | bit | nein | 0 |
| @MitSegmenten | bit | nein | 0 |
| @MitDictionaries | bit | nein | 0 |
| @MinDeletedPercent | decimal(9,2) | nein | 0 |
| @NurProblematisch | bit | nein | 0 |
| @MaxZeilen | int | nein | 10000 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @MitSegmentUeberlappung | bit | nein | 0 |
| @MaxSegmenteAnalyse | int | nein | 2000 |

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Optionaler einteiliger Datenbankname oder bracket-aware Pipe-Liste solcher Namen. | trennt außerhalb von [...]; ]] maskiert ]. Elemente werden außen getrimmt; case-sensitive Duplikate und ungültige/leere Elemente sind INVALID_PARAMETER. NULL, N'' und nur Leerzeichen bedeuten keine exakte Einschränkung und wählen alle zulässigen sichtbaren ONLINE-Datenbanken. Nichtleere Liste und nicht-NULL @DatabaseNamePattern sind gegenseitig exklusiv. PARSENAME-Prüfung: Teil 1 vorhanden, Teil 2 NULL, LEN höchstens 128; keine vollständige SQL-Namensgrammatik. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 (Default) schließt master, model, msdb und tempdb aus; 1 lässt sie in der Auswahl zu. NULL wird vom Datenbankhelfer als INVALID_PARAMETER abgewiesen. Beim Binden an bit werden konvertierbare numerische Werte ungleich 0 zu 1.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Pattern; NULL kein Filter, leer/Whitespace oder leeres Präfix-Ergebnis ungültig. Außen trimmen; Präfixe like:, regex:, regexi: werden ohne Beachtung der Großschreibung erkannt; Rest nicht nochmals trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] sind case-sensitiv. regex: übergibt c, regexi: i; Syntax wird nicht vorgeprüft. Der Datenbankpattern-Helfer prüft Regexverfügbarkeit im Installationsdatenbankkontext (SQL Server 2025 und Compatibility Level 170), sonst UNAVAILABLE_FEATURE. Feldregex für Schema/Objekt hat diese Vorprüfung nicht. Mit wirksamer Datenbankliste exklusiv.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. 0 (Default) bestätigt kein Gate; 1 bestätigt nur die Anforderung eines tatsächlich aktivierten Analysepfads. NULL ungültig. Datenbankauswahl prüft COLUMNSTORE_CURRENT; Physical-/Segment-/Dictionaryoptionen sowie Segmentüberlappung zusätzlich COLUMNSTORE_DEEP; VOLL prüft CATALOG_DEEP. Ob ein aktivierter Pfad eine Gruppengate-Bestätigung verlangt, bestimmt dessen Policy. Bestätigung ersetzt weder Freigabe noch Scopegrenzen. Bit-Bindung mappt konvertierbare numerische Nichtnullwerte auf 1.

**@SchemaNames:** @SchemaNames nvarchar(max); Default: NULL. Optionale exakte einteilige Schemanamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; Elemente außen getrimmt und case-sensitiv verglichen. NULL bedeutet kein Filter; nicht-NULL leere/Whitespace-Liste, leere Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten sind ungültig. LEN höchstens 128. Nicht mit nicht-NULL @SchemaNamePattern oder @FullObjectNames kombinieren.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Pattern; NULL kein Filter, Leerwert/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung; Restinhalt nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: Flag c, regexi: Flag i. Regex wird in der jeweiligen Zieldatenbank ausgeführt, ohne separate Versions-/Kompatibilitätsvorprüfung; fehlende Unterstützung kann als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit nicht-NULL @SchemaNames kombinieren.

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Optionale exakte einteilige Objektnamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; außen getrimmt, case-sensitiv. NULL bedeutet kein Filter; nicht-NULL leer/Whitespace, leere Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten ungültig. LEN höchstens 128. Mit nicht-NULL @ObjectNamePattern oder @FullObjectNames exklusiv.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektpattern; NULL deaktiviert, leeres/Whitespace-Muster oder Präfix ohne Inhalt ungültig. Außen trimmen; Präfixe like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest danach nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Regex läuft in der jeweiligen Zieldatenbank ohne separate Versions-/Kompatibilitätsvorprüfung; fehlende Unterstützung kann je Datenbank als ERROR_HANDLED erscheinen. Nicht mit nicht-NULL @ObjectNames kombinieren.

**@FullObjectNames:** @FullObjectNames nvarchar(max); Default: NULL. Optionale bracket-aware Pipe-Liste ein-, zwei- oder dreiteiliger Bezüge: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. | trennt außerhalb von [...], ]] maskiert ]; PARSENAME/sysname-Grenzen, Rohsegment höchstens 4000 UTF-16-Codeeinheiten. Datenbankteil verlangt Schema; vier Teile unzulässig. NULL kein Filter; nicht-NULL leere Liste ungültig. Vergleiche case-sensitive; nicht angegebene Datenbank-/Schemaanteile bleiben offen. Mit nicht-NULL @SchemaNames oder @ObjectNames exklusiv.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'GEZIELT'. GEZIELT oder VOLL; bei deaktivierter Segmentüberlappung wird NULL zu GEZIELT normalisiert, Außenleerzeichen werden entfernt und die Großschreibung vereinheitlicht. Andere Werte einschließlich leerer Eingabe führen zu INVALID_PARAMETER. Bei @MitSegmentUeberlappung=1 prüft die normale Vorbedingung vor dieser Normalisierung auf ausdrücklich übergebenes GEZIELT; NULL wird in diesem Pfad als INVALID_PARAMETER abgewiesen. VOLL prüft CATALOG_DEEP samt aktueller Aktivierung/Freigabe und ggf. High-Impact-Gate.

**@MitPhysicalStats:** @MitPhysicalStats bit; Default: 0. Opt-in: 0 lässt zusätzliche Physical-Rowgroup-Stats aus; 1 fordert sie an und prüft COLUMNSTORE_DEEP. NULL wird nicht ausdrücklich abgewiesen und aktiviert den =1-Zweig nicht. Detailwerte und Berechtigungen hängen von Quelle und Version ab.

**@MitSegmenten:** @MitSegmenten bit; Default: 0. Opt-in: 0 lässt Segmentmetadaten aus; 1 fordert sie an und prüft COLUMNSTORE_DEEP. NULL wird nicht eigens validiert und aktiviert den =1-Zweig nicht. Die Segmentzahl wächst ungefähr mit Rowgroups × Spalten; TOP begrenzt die je Datenbank materialisierten Zeilen, nicht zuverlässig die vorgelagerte Rowgroupermittlung.

**@MitDictionaries:** @MitDictionaries bit; Default: 0. Opt-in: 0 lässt Dictionarymetadaten aus; 1 fordert sie an und prüft COLUMNSTORE_DEEP. NULL wird nicht eigens abgewiesen und aktiviert den =1-Zweig nicht. Ergebnisverfügbarkeit und erforderliche Rechte hängen vom Quellpfad ab.

**@MinDeletedPercent:** @MinDeletedPercent decimal(9,2); Default: 0. Rowgroup-Schwelle in Prozentpunkten, einschließlich 0 bis 100; außerhalb INVALID_PARAMETER. NULL passiert den <0/>100-Test aufgrund SQL-Dreiwertlogik, macht aber den nachfolgenden >=-Vergleich UNKNOWN, sodass keine Zeile den Vergleich erfüllt. Kein Rebuildurteil.

**@NurProblematisch:** @NurProblematisch bit; Default: 0. 0 lässt die Rowgroup-Auswahl ungefiltert; 1 filtert auf Zustand ungleich COMPRESSED oder vorhandene gelöschte Zeilen. NULL wird nicht separat validiert, sondern an SQL-Prädikate weitergereicht; deren Dreiwertlogik gilt.

**@MaxZeilen:** @MaxZeilen int; Default: 10000. Positive int begrenzt TOP je relevanter Ergebnismenge und Ziel-Datenbank; 0 oder NULL bedeutet unbegrenzt; negative Werte INVALID_PARAMETER. Die Grenze begrenzt nicht zuverlässig vorgelagerte Katalog-/DMV-Arbeit. Segmentüberlappung hat die separate Grenze @MaxSegmenteAnalyse.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Lockwartezeit in Millisekunden von 0 bis 60000; außerhalb INVALID_PARAMETER. 0 bedeutet NOWAIT. Der Parameter wird in dynamischen Datenbankzugriffs-Batches als SET LOCK_TIMEOUT gesetzt; der Modulablauf setzt außerhalb dieser Batches außerdem stellenweise LOCK_TIMEOUT 0. NULL wird von der Bereichsprüfung nicht als ungültig erkannt; die spätere dynamische SET-LOCK_TIMEOUT-Textbildung wird durch den NULL-Wert NULL. Ein konkreter Ausführungsstatus dieses NULL-Batches wird hier nicht zugesichert.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach TRIM/UPPER einer der endlichen Werte CONSOLE, RAW, TABLE, NONE; NULL/leer wird ungültig. CONSOLE zeigt Statuskontext und menschenlesbare Fachansicht; RAW gibt getrennte Status- und Fachmengen; TABLE schreibt nur gemappte Mengen; NONE unterdrückt reguläre Resultsets. JSON ist unabhängig über @JsonErzeugen steuerbar. TABLE-Mapping wird vor dem Hilfezweig vorgeprüft.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur mit TABLE: JSON-Objekt Resultsetname zu lokaler #Temp-Zieltabelle. Für TABLE ist NULL/leeres oder ungültiges Objekt ungültig; außerhalb TABLE führt nichtleerer Inhalt zu THROW 51011. Erlaubte exakte Namen: rowgroups, ordering; segmentOverlap zusätzlich nur bei aktivierter Segmentüberlappung. Ziele müssen eindeutig, lokal, leer und mit genau einer Seed-Spalte angelegt sein; der Helper prüft und wirft bei Fehler.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 unterdrückt JSON; 1 erzeugt es in @Json. NULL wird nicht eigens als ungültig geprüft und führt nicht in den IF-Zweig. JSON-Schema 1 ohne Segmentüberlappung, Schema 2 mit ihr; Schlüssel meta, rowgroups, ordering, physicalStats, segments, dictionaries, databaseStatus und beim Opt-in segmentOverlap.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler nvarchar(max)-OUTPUT-Empfänger; zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 enthält er das erzeugte JSON, sonst NULL. Zum Empfangen Variable passenden Typs mit OUTPUT binden; ohne OUTPUT wird die Zuweisung nicht zurückgegeben. Im Hilfezweig ist die Variable NULL.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt die ergänzende Severity-10-Warnmeldung; 1 (Default) gibt sie bei Status ungleich AVAILABLE aus. NULL wird nicht separat validiert und die Meldungsbedingung greift nicht. Keine zusätzliche Fachmenge.

**@Hilfe:** @Hilfe bit; Default: 0. 0 normaler Ablauf; 1 druckt Hilfe und beendet vor der Analyse. Der Return liegt nach Filter-, TABLE-Mapping-, Kandidaten- und Gateprüfungen, diese können also vorher stattfinden. NULL wird nicht als 1 behandelt.

**@MitSegmentUeberlappung:** @MitSegmentUeberlappung bit; Default: 0. 0 (auch NULL, durch COALESCE zu 0 normalisiert) lässt segmentOverlap aus; 1 fordert die Diagnose und COLUMNSTORE_DEEP-Prüfung. Normaler Aufruf verlangt außerdem GEZIELT, genau eine explizite Datenbank, genau ein zweigliedriges FullObjectNames-Objekt, keine konkurrierenden Schema-/Objektfilter und @MaxSegmenteAnalyse 1..10000; sonst INVALID_PARAMETER. Opt-in ergänzt RAW/TABLE/JSON/CONSOLE; JSON wechselt zu Schema 2.

**@MaxSegmenteAnalyse:** @MaxSegmenteAnalyse int; Default: 2000. Nur im aktivierten Segmentüberlappungspfad gültige Grenze 1..10000 einschließlich; NULL/außerhalb ungültig. Höchstens N+1 Segmentzeilen als Sentinel werden materialisiert; bei Überschreitung entfällt die gesamte Paarberechnung. Kein globales TOP-/Zeitlimit; bei ausgeschaltetem Pfad ungeprüft.

## Resultate und Ausgabe

RAW gibt Status und getrennte Fachmengen aus; CONSOLE Statusmengen und eine menschenlesbare Fachansicht; TABLE schreibt benannte Mengen; NONE unterdrückt reguläre Resultsets. JSON enthält meta, rowgroups, ordering, physicalStats, segments, dictionaries und databaseStatus; bei Segmentüberlappung Schema 2 mit zusätzlichem segmentOverlap.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| rowgroups | 1 | 1 | [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL,[ObjectId] int NOT NULL,[IndexId] int NOT NULL,[IndexName] sysname NULL,[IndexTypeDesc] nvarchar(60) NULL, [PartitionNumber] int NOT NULL,[RowGroupId] int NOT NULL,[StateDesc] nvarchar(60) NULL,[TotalRows] bigint NULL,[DeletedRows] bigint NULL,[ActiveRows] bigint NULL, [DeletedPercent] decimal(9,4) NULL,[FullnessPercent] decimal(9,4) NULL,[SizeMb] decimal(19,2) NULL,[DeltaStoreHobtId] bigint NULL, [TrimReasonDesc] nvarchar(60) NULL,[TransitionToCompressedStateDesc] nvarchar(60) NULL,[HasVertipaqOptimization] bit NULL,[Generation] bigint NULL,[CreatedTime] datetime2 NULL,[ClosedTime] datetime2 NULL, [Assessment] varchar(60) NOT NULL |
| ordering | 1 | 1 | [DatabaseName] sysname NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[ObjectId] int NULL,[IndexId] int NULL,[IndexName] sysname NULL,[IndexTypeDesc] nvarchar(60) NULL,[ColumnId] int NULL,[ColumnName] sysname NULL,[ColumnStoreOrderOrdinal] tinyint NULL,[DataClusteringOrdinal] tinyint NULL,[SourceStatus] varchar(40) NOT NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) NULL,[CollectionTimeUtc] datetime2(3) NOT NULL |
| segmentOverlap | 1 | 1 | [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL,[ObjectId] int NOT NULL,[IndexId] int NOT NULL,[IndexName] sysname NULL,[PartitionNumber] int NOT NULL,[ColumnId] int NOT NULL,[ColumnName] sysname NULL,[SystemTypeName] sysname NULL,[ObservedSegmentCount] bigint NOT NULL,[ComparableSegmentCount] bigint NOT NULL,[UncomparableSegmentCount] bigint NOT NULL,[StrictOverlapPairCount] bigint NULL,[BoundaryTouchPairCount] bigint NULL,[SourceStatus] varchar(40) NOT NULL,[IsPartial] bit NOT NULL,[ReasonCode] varchar(60) NULL,[CollectionTimeUtc] datetime2(3) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_Columnstore] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_Columnstore

Analysiert sichtbare Columnstore-Rowgroups und geordnete Indexmetadaten; Physical Stats, Segmente, Dictionaries und Segmentüberlappung sind optionale Vertiefungen.

Segmentüberlappung ist ein gezielter Snapshot für genau eine Datenbank und ein Objekt. Bei Überschreitung entfällt ihre gesamte Paarberechnung; sie ersetzt keine Workload- oder Qualitätsbewertung.

Der HELP-Zweig liegt nach frühen Filter-, TABLE-Mapping-, Kandidaten- und Gate-Prüfungen.

DECLARE @Columnstore_JsonExample nvarchar(max); EXEC [monitor].[USP_Columnstore] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @JsonErzeugen=1, @Json=@Columnstore_JsonExample OUTPUT; SELECT @Columnstore_JsonExample AS [JsonDocument];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_Columnstore
Version      : 1.2.0
Stand        : 2026-10-14
Typ          : Stored Procedure
Zweck        : Analysiert Columnstore-Indizes, Rowgroups und Deleted Rows; Physical Stats, Segmente und Dictionaries sind explizite gruppengeschützte Vertiefungen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : Je Datenbank sys.column_store_row_groups, sys.index_columns (geordnete Metadaten), optional sys.dm_db_column_store_row_group_physical_stats, sys.column_store_segments, sys.column_store_dictionaries sowie Systemkataloge.
Parameter    : Die vollständige Eingabeschnittstelle ist in der Procedure-Signatur aufgeführt. Sie umfasst Datenbank-, Schema-, Objekt- und Vollobjektfilter, GEZIELT/VOLL, optionale Physical-Stats-, Segment- und Dictionarypfade, Deleted-Row-Filter, ResultSetArt/TABLE-Mapping, JSON- und Meldungsschalter sowie Segmentüberlappung. @MaxZeilen begrenzt je Datenbank die jeweilige Ergebnismenge; @MaxSegmenteAnalyse begrenzt separat die Segmentaufnahme mit N+1-Sentinel. @Json ist OUTPUT und wird nur bei @JsonErzeugen=1 mit JSON befüllt.
Resultsets   : RAW gibt Status und getrennte Fachmengen aus; CONSOLE Statusmengen und eine menschenlesbare Fachansicht; TABLE schreibt benannte Mengen; NONE unterdrückt reguläre Resultsets. JSON enthält meta, rowgroups, ordering, physicalStats, segments, dictionaries und databaseStatus; bei Segmentüberlappung Schema 2 mit zusätzlichem segmentOverlap.
Berechtigung : Basis gemäß Metadata Visibility/VIEW DEFINITION; Physical Stats SQL 2019 VIEW DATABASE STATE plus CONTROL, SQL 2022+ VIEW DATABASE PERFORMANCE STATE; Detailwerte können SELECT erfordern. Datenbankauswahl prüft COLUMNSTORE_CURRENT. Physical-/Segment-/Dictionaryoptionen und Segmentüberlappung prüfen COLUMNSTORE_DEEP; VOLL prüft zusätzlich CATALOG_DEEP. Aktuelle Freigabe und ein ggf. erforderliches High-Impact-Gate werden separat geprüft.
Eigenlast    : Der Basispfad ist moderat. Optionale Detailmengen können umfangreich sein; Segmentzeilen wachsen ungefähr mit Rowgroups × Spalten. @MaxZeilen begrenzt Ergebnismengen und Materialisierung, nicht zuverlässig vorgelagerte Quellermittlung. Segmentüberlappung übernimmt höchstens @MaxSegmenteAnalyse + 1 Segmentzeilen in die Zwischenmenge; beim Sentinel entfällt die Paarberechnung.
Locking      : READUNCOMMITTED-Kataloge, LOCK_TIMEOUT; keine Wartungs-DDL.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_Columnstore @DatabaseNames=N'[SampleDatabase]', @ObjectNamePattern=N'like:Fact%';
  EXEC monitor.USP_Columnstore @DatabaseNames=N'[SampleDatabase]', @ObjectNamePattern=N'like:Fact%', @MinDeletedPercent=10, @NurProblematisch=1;
  EXEC monitor.USP_Columnstore @DatabaseNames=N'SampleDatabase', @AnalyseModus='VOLL', @MitPhysicalStats=1, @MitSegmenten=1;
  EXEC monitor.USP_Columnstore @Hilfe=1;
Änderungen   : 1.2.0 - Freigegebene begrenzte opt-in Segmentüberlappung mit getrennten Paar- und Berührungszahlen.
               1.1.0 - Additive, versionsadaptive geordnete Columnstore-Metadaten.
               1.0.0 - Erstfassung Phase 2.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_Columnstore
Analysiert sichtbare Columnstore-Rowgroups und geordnete Indexmetadaten; Physical Stats, Segmente, Dictionaries und Segmentüberlappung sind optionale Vertiefungen.
Segmentüberlappung ist ein gezielter Snapshot für genau eine Datenbank und ein Objekt. Bei Überschreitung entfällt ihre gesamte Paarberechnung; sie ersetzt keine Workload- oder Qualitätsbewertung.
Der HELP-Zweig liegt nach frühen Filter-, TABLE-Mapping-, Kandidaten- und Gate-Prüfungen.
DECLARE @Columnstore_JsonExample nvarchar(max); EXEC [monitor].[USP_Columnstore] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @JsonErzeugen=1, @Json=@Columnstore_JsonExample OUTPUT; SELECT @Columnstore_JsonExample AS [JsonDocument];
```

