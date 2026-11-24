---
skill_format_version: "1.0.0"
name: "monitor.USP_ObjectInventory"
schema_name: "monitor"
object_name: "USP_ObjectInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert ein fehlertolerantes Objekt- und Indexinventar einschließlich Größe, Zeilen, Kompression, Partitionierung, optionalen Spaltenlisten sowie versionsadaptiven SQL-Server-2025-JSON-Index- und Pfadmetadaten."
source_path: "Code/03_ObjectIndex/010_USP_ObjectInventory.sql"
---

# monitor.USP_ObjectInventory

## Zweck und Einsatz

Liefert ein fehlertolerantes Objekt- und Indexinventar einschließlich Größe, Zeilen, Kompression, Partitionierung, optionalen Spaltenlisten sowie versionsadaptiven SQL-Server-2025-JSON-Index- und Pfadmetadaten.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

master.sys.databases sowie je Zieldatenbank sys.objects, sys.tables, sys.schemas, sys.indexes, sys.index_columns, sys.columns, sys.partitions, sys.allocation_units, sys.data_spaces und capability-abhängig sys.json_indexes sowie sys.json_index_paths.

Katalogsicht gemäß Metadata Visibility; VOLL prüft zusätzlich CATALOG_DEEP. Keine Rechtevergabe.

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
| @ObjectType | varchar(16) | nein | 'TABLE' |
| @AnalyseModus | varchar(16) | nein | 'GEZIELT' |
| @MitIndizes | bit | nein | 1 |
| @MitSpaltenlisten | bit | nein | 1 |
| @MaxZeilen | int | nein | 5000 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. bit-Bestätigung für den VOLL-Pfad CATALOG_DEEP, der erst nach OBJECT_ANALYSIS_CURRENT aktiviert wird: 0 bestätigt den Deep-Pfad nicht; 1 erfüllt die Bestätigungsanforderung, erteilt selbst aber keine Berechtigung. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. GEZIELT nutzt OBJECT_ANALYSIS_CURRENT und verlangt diese Bestätigung nicht.

**@SchemaNames:** @SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Schemanamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @SchemaNames kombinieren. Übergabe zum Beispiel N'like:App%'.

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @ObjectNames kombinieren. Übergabe zum Beispiel N'like:App%'.

**@FullObjectNames:** @FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination.

**@ObjectType:** @ObjectType varchar(16); Default: 'TABLE'. Wählen Sie TABLE für Benutzertabellen, VIEW für Sichten oder ALLE für beide Objektarten. Der Wert wird mit LTRIM/RTRIM und UPPER normalisiert; Groß-/Kleinschreibung und äußere Leerzeichen ändern die Auswahl nicht. NULL wird vor der Prüfung zu TABLE. Ein leerer oder anderer Wert führt zu INVALID_PARAMETER.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'GEZIELT'. GEZIELT analysiert einen durch exakte Namenslisten, @FullObjectNames oder ein Schema-/Objekt-Pattern begrenzten Scope; mindestens eine solche Objektbegrenzung muss vorhanden sein. VOLL wählt den Katalogpfad und prüft zusätzlich die Freigabe CATALOG_DEEP. Der Wert wird getrimmt und in Großbuchstaben umgewandelt; NULL wird zu GEZIELT, GEZIELT und VOLL sind die einzigen gültigen Werte. Leertext und andere Werte führen zu INVALID_PARAMETER. VOLL ohne Freigabe wird abgewiesen. VOLL erfordert außerdem ausdrücklich @HighImpactConfirmed=1; eine Bestätigung ersetzt keine Gruppen- oder SQL-Berechtigung.

**@MitIndizes:** @MitIndizes bit; Default: 1. 1 gibt Indexdetails aus; bei Tabellen entstehen dadurch grundsätzlich Zeilen je Index, und Index- sowie JSON-Indexfelder werden befüllt, soweit ihre Quellen verfügbar sind. 0 unterdrückt Indexdetails und liefert je Objekt eine Summenzeile mit den Objektgesamtwerten; Index- und JSON-Indexfelder bleiben NULL. Für bit-Eingaben sind 0 und 1 die Schalterwerte. NULL wird nicht auf einen Schalterwert normalisiert: Der Index-Join wird dadurch nicht aktiviert; Tabellenzeilen erfüllen anschließend den Filter nicht, Views können ihn erfüllen, während ihre Indexdetails NULL bleiben. Binden Sie deshalb ausdrücklich 0 oder 1. Numerisch 0 bleibt beim Binden 0; von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1.

**@MitSpaltenlisten:** @MitSpaltenlisten bit; Default: 1. 1 ergänzt bei angeforderten Indexdetails KeyColumns und IncludedColumns. Schlüsselspalten folgen key_ordinal und enthalten DESC für absteigende Schlüssel; Include-Spalten folgen index_column_id. 0 unterdrückt beide Listen. NULL wird nicht zu 0 oder 1 normalisiert und erfüllt die CASE-Bedingung nicht, daher bleiben die Listen NULL. Auch bei @MitIndizes=0 werden keine Spaltenlisten ausgegeben. Für bit-Eingaben sind 0 und 1 die Schalterwerte. Numerisch 0 bleibt beim Binden 0; von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1.

**@MaxZeilen:** @MaxZeilen int; Default: 5000. Nichtnegative ganze Zahl von 0 bis 2147483647. NULL oder 0 wird intern zur bigint-TOP-Grenze 9223372036854775807; negative Werte sind INVALID_PARAMETER. TOP begrenzt die Inventarzeilen je Datenbank, geordnet nach reservierten Objektseiten absteigend, danach ObjectId und IndexId. Die Endausgabe sortiert nach ObjectReservedMb absteigend, Datenbank, Schema, Objekt und IndexId. Keine globale Zeilengrenze und keine verlässliche Begrenzung der vorherigen Katalogaggregation.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Ganzzahlige Millisekunden von 0 bis 60000; andere nicht-NULL-Werte sind INVALID_PARAMETER. Der dynamische Hauptbatch enthält SET LOCK_TIMEOUT und die Inventarabfrage im selben Batch: 0 wartet dort nicht auf Locks, positive Werte begrenzen das Warten. Separate JSON-Metadatenbatches beginnen mit USE und enthalten diesen SET-Befehl nicht. Der Code speichert den Eingangswert und baut vor beziehungsweise nach der Sammlung eigene SET-/Restore-Batches; SET-Änderungen gelten nach den SQL-Server-Regeln im jeweiligen Prozedur-/dynamischen Batch-Scope und werden bei dessen Rückkehr zurückgenommen. Aus den separaten Hilfsbatches folgt keine übergreifende Timeout-Steuerung der JSON-Metadaten. Hilfe kehrt vor diesen eigenen SET-/Restore-Blöcken zurück. NULL passiert den Bereichstest als UNKNOWN und erzeugt durch Verkettung NULL statt des SET- beziehungsweise Hauptbatches; ein Fehler- oder No-op-Verhalten des NULL-Statements wird daraus nicht behauptet.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Objektinventar-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: objects als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"objects":"#IndexHelpTarget"}'.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, objects und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, objects und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung.

**@Hilfe:** @Hilfe bit; Default: 0. bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht.

## Resultate und Ausgabe

RAW liefert Modulstatus, Datenbankstatus und Fachdaten. CONSOLE und TABLE liefern ausschließlich objects. JSON enthält meta, objects und databaseStatus; NONE unterdrückt direkte Resultsets. Hilfe folgt der bereits erfolgten Filtervorbereitung und gegebenenfalls TABLE-Preflight.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| objects | 1 | 1 | [DatabaseName] sysname NOT NULL , [SchemaName] sysname NOT NULL , [ObjectName] sysname NOT NULL , [ObjectType] varchar(20) NOT NULL , [ObjectId] int NOT NULL , [IsMsShipped] bit NOT NULL , [IsMemoryOptimized] bit NULL , [TemporalTypeDesc] nvarchar(60) NULL , [DurabilityDesc] nvarchar(60) NULL , [CreateDate] datetime NULL , [ModifyDate] datetime NULL , [ObjectRowCount] bigint NULL , [ObjectReservedMb] decimal(19,2) NULL , [ObjectUsedMb] decimal(19,2) NULL , [IndexId] int NULL , [IndexName] sysname NULL , [IndexTypeDesc] nvarchar(60) NULL , [IsUnique] bit NULL , [IsPrimaryKey] bit NULL , [IsUniqueConstraint] bit NULL , [IsDisabled] bit NULL , [IsHypothetical] bit NULL , [HasFilter] bit NULL , [FilterDefinition] nvarchar(max) NULL , [FillFactor] tinyint NULL , [AllowRowLocks] bit NULL , [AllowPageLocks] bit NULL , [OptimizeForSequentialKey] bit NULL , [DataSpaceName] sysname NULL , [PartitionCount] int NULL , [IndexRowCount] bigint NULL , [IndexReservedMb] decimal(19,2) NULL , [IndexUsedMb] decimal(19,2) NULL , [MinCompressionDesc] nvarchar(60) NULL , [MaxCompressionDesc] nvarchar(60) NULL , [HasMixedCompression] bit NULL , [KeyColumns] nvarchar(max) NULL , [IncludedColumns] nvarchar(max) NULL , [IsJsonIndex] bit NULL , [OptimizeForArraySearch] bit NULL , [JsonPathCount] bigint NULL , [JsonPaths] nvarchar(max) NULL , [JsonIndexStatusCode] varchar(40) NULL , [JsonIndexEvidenceLimit] nvarchar(1000) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ObjectInventory] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_ObjectInventory

Liefert einen gefilterten Katalogsnapshot zu Tabellen und Sichten mit Objekt-/Indexgrößen, Zeilen, Partitionierung, Kompression und optionalen Schlüssel-/Include- sowie SQL-Server-2025-JSON-Indexmetadaten. Der GEZIELT-Modus benötigt einen Objektfilter; VOLL prüft zusätzlich CATALOG_DEEP.

Die PRINT-Hilfe folgt der Namens-/Datenbank- und Gate-Vorbereitung sowie gegebenenfalls TABLE-Preflight. Sie kehrt vor der eigenen Fachanalyse zurück.

Beispiel RAW: EXEC [monitor].[USP_ObjectInventory] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';

Hilfe: EXEC [monitor].[USP_ObjectInventory] @Hilfe=1;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ObjectInventory
Version      : 1.1.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Liefert ein fehlertolerantes Objekt- und Indexinventar
               einschließlich Größe, Zeilen, Kompression, Partitionierung,
               optionalen Spaltenlisten sowie versionsadaptiven
               SQL-Server-2025-JSON-Index- und Pfadmetadaten.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : master.sys.databases sowie je Zieldatenbank sys.objects,
               sys.tables, sys.schemas, sys.indexes, sys.index_columns,
               sys.columns, sys.partitions, sys.allocation_units,
               sys.data_spaces und capability-abhängig sys.json_indexes
               sowie sys.json_index_paths.
Parameter    : Signatur und Defaults stehen unmittelbar unter diesem DDL-Kommentar.
               Die PRINT-Hilfe beschreibt jeden Parameter mit Eingabeform,
               NULL-/Leerwertregeln, Grenzen und allen festen Optionen.
               GEZIELT benötigt einen Objektfilter; VOLL prüft zusätzlich
               CATALOG_DEEP mit Bestätigung und separater Gruppenfreigabe.
Ausgabe      : RAW liefert Modulstatus, Datenbankstatus und Fachdaten.
               CONSOLE und TABLE liefern ausschließlich objects.
               JSON enthält meta, objects und databaseStatus; NONE
               unterdrückt direkte Resultsets. Hilfe folgt der bereits
               erfolgten Filtervorbereitung und gegebenenfalls TABLE-Preflight.
Berechtigung : Katalogsicht gemäß Metadata Visibility; VOLL prüft zusätzlich CATALOG_DEEP. Keine Rechtevergabe.
Eigenlast    : TOP begrenzt Inventarzeilen je Datenbank, nicht verlässlich die gesamte Katalogaggregation oder Spaltenlistenarbeit.
Locking      : READUNCOMMITTED/NOLOCK auf Systemkatalogen; @LockTimeoutMs
               steht im dynamischen Hauptbatch. Separate JSON-Metadatenbatches
               enthalten diesen SET-Befehl nicht. SET-Gültigkeit folgt dem
               jeweiligen Prozedur-/dynamischen Batch-Scope.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_ObjectInventory @DatabaseNames=N'[ExampleDatabase]', @ObjectNamePattern=N'like:Fact%';
  EXEC monitor.USP_ObjectInventory @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'[dbo]', @ObjectNamePattern=N'like:Fact%';
  EXEC monitor.USP_ObjectInventory @DatabaseNames=N'[ExampleDatabase]', @AnalyseModus='VOLL', @HighImpactConfirmed=1, @MaxZeilen=20000;
  EXEC monitor.USP_ObjectInventory @Hilfe=1;
Änderungen   : 1.1.0 - SQL25-002: JSON-Indizes und aggregierte SQL/JSON-Pfade
                         ohne Lesen von JSON-Dokumentwerten ergänzt.
               1.0.0 - Erstfassung Phase 2.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ObjectInventory
Liefert einen gefilterten Katalogsnapshot zu Tabellen und Sichten mit Objekt-/Indexgrößen, Zeilen, Partitionierung, Kompression und optionalen Schlüssel-/Include- sowie SQL-Server-2025-JSON-Indexmetadaten. Der GEZIELT-Modus benötigt einen Objektfilter; VOLL prüft zusätzlich CATALOG_DEEP.
Die PRINT-Hilfe folgt der Namens-/Datenbank- und Gate-Vorbereitung sowie gegebenenfalls TABLE-Preflight. Sie kehrt vor der eigenen Fachanalyse zurück.
Beispiel RAW: EXEC [monitor].[USP_ObjectInventory] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';
Hilfe: EXEC [monitor].[USP_ObjectInventory] @Hilfe=1;
```

