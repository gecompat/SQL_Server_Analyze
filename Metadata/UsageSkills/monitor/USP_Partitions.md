---
skill_format_version: "1.0.0"
name: "monitor.USP_Partitions"
schema_name: "monitor"
object_name: "USP_Partitions"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert Partitionierung, Grenzwerte, Filegroups, Zeilen, Größe und Datenkompression; ungezielte Vollanalyse ist gruppengeschützt."
source_path: "Code/03_ObjectIndex/050_USP_Partitions.sql"
---

# monitor.USP_Partitions

## Zweck und Einsatz

Liefert Partitionierung, Grenzwerte, Filegroups, Zeilen, Größe und Datenkompression; ungezielte Vollanalyse ist gruppengeschützt.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

Je Datenbank sys.objects, sys.schemas, sys.indexes, sys.partitions, sys.allocation_units, sys.data_spaces, sys.partition_schemes, sys.partition_functions und sys.partition_range_values.

Metadata Visibility; sys.dm_db_partition_stats wird nicht benötigt.

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
| @NurPartitionierte | bit | nein | 0 |
| @NurGemischteKompression | bit | nein | 0 |
| @MaxZeilen | int | nein | 10000 |
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

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'GEZIELT'. GEZIELT analysiert einen durch exakte Namenslisten, @FullObjectNames oder ein Schema-/Objekt-Pattern begrenzten Scope; mindestens eine solche Objektbegrenzung muss vorhanden sein. VOLL wählt den Katalogpfad und prüft zusätzlich CATALOG_DEEP. Der Wert wird getrimmt und in Großbuchstaben umgewandelt; NULL wird zu GEZIELT, GEZIELT und VOLL sind die einzigen gültigen Werte. Leertext und andere Werte führen zu INVALID_PARAMETER. VOLL ohne Freigabe wird abgewiesen. VOLL erfordert außerdem ausdrücklich @HighImpactConfirmed=1; eine Bestätigung ersetzt keine Gruppen- oder SQL-Berechtigung.

**@NurPartitionierte:** @NurPartitionierte bit; Default: 0. 1 lässt nur Partitionen von Indizes mit mehr als einer Partition durch; 0 wendet diese zusätzliche Einschränkung nicht an. Die Prüfung erfolgt mit PartitionCount > 1 und gilt auf Indexebene. Bei NULL greift weder der 0-Zweig noch die Wahrheitsbedingung für einpartitionige Indizes: Mehrpartitionige Indizes können passieren, einpartitionige nicht. Für bit-Eingaben sind 0 und 1 die Schalterwerte; NULL ist daher nicht gleichbedeutend mit 0. Numerisch 0 bleibt beim Binden 0; von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1.

**@NurGemischteKompression:** @NurGemischteKompression bit; Default: 0. 1 lässt nur Indizes durch, deren Partitionen mehrere Kompressionsarten aufweisen; technisch wird MinCompression <> MaxCompression geprüft. 0 wendet diese zusätzliche Einschränkung nicht an. Bei NULL liefert die SQL-OR-Bedingung nur für Indizes mit verschiedenen Minimal- und Maximalwerten TRUE; homogene Kompression erfüllt den Filter nicht. Für bit-Eingaben sind 0 und 1 die Schalterwerte; NULL ist daher nicht gleichbedeutend mit 0. Numerisch 0 bleibt beim Binden 0; von 0 verschiedene zu bit konvertierbare Zahlenwerte werden 1.

**@MaxZeilen:** @MaxZeilen int; Default: 10000. Nichtnegative ganze Zahl von 0 bis 2147483647. NULL oder 0 wird intern zur bigint-TOP-Grenze 9223372036854775807; negative Werte sind INVALID_PARAMETER. TOP begrenzt Partitionszeilen je Datenbank, geordnet nach ReservedPages absteigend, ObjectId, IndexId und PartitionNumber. Die Endausgabe ergänzt Datenbank-, Schema- und Objektnamen zur Sortierung. Kein globales Zeilenlimit und keine verlässliche Begrenzung der vorherigen Katalogjoins und Aggregation.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Wartezeit als nicht-NULL int von 0 bis 60000 Millisekunden. 0 setzt NOWAIT; positive Werte werden im dynamischen Fachbatch als SET LOCK_TIMEOUT übernommen. Werte außerhalb sind INVALID_PARAMETER. NULL passiert den Bereichstest als UNKNOWN, macht den verketteten SQL-Text aber NULL statt des vorgesehenen Fachbatches. Vor der Datenbankschleife setzt die Procedure LOCK_TIMEOUT 0. Für einen regulären Fachaufruf einen konkreten Wert von 0 bis 60000 übergeben; ein bestimmter Fehlerstatus für das NULL-Statement wird hier nicht zugesichert.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Partitions-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: partitions als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"partitions":"#IndexHelpTarget"}'.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, partitions und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, partitions und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung.

**@Hilfe:** @Hilfe bit; Default: 0. bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht.

## Resultate und Ausgabe

RAW liefert Modulstatus, Datenbankstatus und Fachdaten. CONSOLE und TABLE liefern ausschließlich partitions. JSON enthält meta, partitions und databaseStatus; NONE unterdrückt direkte Resultsets. Hilfe folgt der bereits erfolgten Filtervorbereitung und gegebenenfalls TABLE-Preflight.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| partitions | 1 | 1 | [DatabaseName] sysname NOT NULL,[SchemaName] sysname NOT NULL,[ObjectName] sysname NOT NULL,[ObjectId] int NOT NULL, [IndexId] int NOT NULL,[IndexName] sysname NULL,[IndexTypeDesc] nvarchar(60) NULL,[PartitionNumber] int NOT NULL,[PartitionCount] int NOT NULL, [PartitionId] bigint NOT NULL,[HobtId] bigint NULL,[RowCount] bigint NULL,[ReservedMb] decimal(19,2) NULL,[UsedMb] decimal(19,2) NULL, [DataCompressionDesc] nvarchar(60) NULL,[XmlCompressionDesc] varchar(3) NULL,[DataSpaceName] sysname NULL,[DestinationFilegroupName] sysname NULL, [PartitionSchemeName] sysname NULL,[PartitionFunctionName] sysname NULL,[BoundaryOnRight] bit NULL, [LowerBoundaryValue] nvarchar(4000) NULL,[LowerBoundaryInclusive] bit NULL,[UpperBoundaryValue] nvarchar(4000) NULL,[UpperBoundaryInclusive] bit NULL, [HasMixedCompression] bit NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_Partitions] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_Partitions

Zeigt einen gefilterten Katalogsnapshot mit einer Zeile je Indexpartition und Angaben zu Größe, Grenzintervallen, Ablage und Kompression. GEZIELT benötigt einen Objektfilter; VOLL prüft zusätzlich CATALOG_DEEP.

Die PRINT-Hilfe folgt der Namens-/Datenbank- und Gate-Vorbereitung sowie gegebenenfalls TABLE-Preflight. Sie kehrt vor der eigenen Fachanalyse zurück.

Beispiel RAW: EXEC [monitor].[USP_Partitions] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';

Hilfe: EXEC [monitor].[USP_Partitions] @Hilfe=1;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_Partitions
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Liefert Partitionierung, Grenzwerte, Filegroups, Zeilen, Größe und Datenkompression; ungezielte Vollanalyse ist gruppengeschützt.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : Je Datenbank sys.objects, sys.schemas, sys.indexes, sys.partitions, sys.allocation_units, sys.data_spaces, sys.partition_schemes, sys.partition_functions und sys.partition_range_values.
Parameter    : Signatur und Defaults stehen unmittelbar unter diesem DDL-Kommentar.
               Die PRINT-Hilfe beschreibt jeden Parameter mit Eingabeform,
               NULL-/Leerwertregeln, Grenzen und allen festen Optionen.
               GEZIELT benötigt einen Objektfilter; VOLL prüft zusätzlich
               CATALOG_DEEP mit Bestätigung und separater Gruppenfreigabe.
Ausgabe      : RAW liefert Modulstatus, Datenbankstatus und Fachdaten.
               CONSOLE und TABLE liefern ausschließlich partitions.
               JSON enthält meta, partitions und databaseStatus; NONE
               unterdrückt direkte Resultsets. Hilfe folgt der bereits
               erfolgten Filtervorbereitung und gegebenenfalls TABLE-Preflight.
Berechtigung : Metadata Visibility; sys.dm_db_partition_stats wird nicht benötigt.
Eigenlast    : Katalog- und Allocation-Unit-Aggregation; VOLL ist gruppengeschützt. TOP begrenzt die Ausgabe je Datenbank, nicht verlässlich die gesamte Vorarbeit.
Locking      : READUNCOMMITTED-Systemkataloge und LOCK_TIMEOUT.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_Partitions @DatabaseNames=N'ExampleDatabase', @ObjectNamePattern=N'FactSales';
  EXEC monitor.USP_Partitions @DatabaseNames=N'ExampleDatabase', @AnalyseModus='VOLL', @HighImpactConfirmed=1, @NurPartitionierte=1;
  EXEC monitor.USP_Partitions @Hilfe=1;
Änderungen   : 1.0.0 - Erstfassung Phase 2.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_Partitions
Zeigt einen gefilterten Katalogsnapshot mit einer Zeile je Indexpartition und Angaben zu Größe, Grenzintervallen, Ablage und Kompression. GEZIELT benötigt einen Objektfilter; VOLL prüft zusätzlich CATALOG_DEEP.
Die PRINT-Hilfe folgt der Namens-/Datenbank- und Gate-Vorbereitung sowie gegebenenfalls TABLE-Preflight. Sie kehrt vor der eigenen Fachanalyse zurück.
Beispiel RAW: EXEC [monitor].[USP_Partitions] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';
Hilfe: EXEC [monitor].[USP_Partitions] @Hilfe=1;
```

