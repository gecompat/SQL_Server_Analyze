---
skill_format_version: "1.0.0"
name: "monitor.USP_IndexUsage"
schema_name: "monitor"
object_name: "USP_IndexUsage"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert kumulative Indexnutzung seit dem letzten DMV-Reset und klassifiziert gelesene, schreiblastige sowie seit Reset ungenutzte Indizes."
source_path: "Code/03_ObjectIndex/020_USP_IndexUsage.sql"
---

# monitor.USP_IndexUsage

## Zweck und Einsatz

Liefert kumulative Indexnutzung seit dem letzten DMV-Reset und klassifiziert gelesene, schreiblastige sowie seit Reset ungenutzte Indizes.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.dm_db_index_usage_stats, sys.dm_db_xtp_index_stats, sys.dm_os_sys_info sowie je Datenbank sys.objects, sys.tables, sys.schemas, sys.indexes, sys.hash_indexes und sys.partitions.

SQL Server 2019 VIEW SERVER STATE; SQL Server 2022+ VIEW SERVER PERFORMANCE STATE. Metadaten zusätzlich gemäß Sichtbarkeit.

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
| @NurUngenutzt | bit | nein | 0 |
| @MinUserUpdates | bigint | nein | 0 |
| @PrimaryUndUniqueEinbeziehen | bit | nein | 1 |
| @MitMemoryOptimized | bit | nein | 1 |
| @MaxZeilen | int | nein | 5000 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Eine Datenbankliste allein erfüllt den GEZIELT-Objektfilter nicht. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. bit-Bestätigung für den VOLL-Pfad CATALOG_DEEP, der erst nach OBJECT_ANALYSIS_CURRENT aktiviert wird: 0 bestätigt den Deep-Pfad nicht; 1 erfüllt die Bestätigungsanforderung, erteilt selbst aber keine Berechtigung. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. GEZIELT nutzt OBJECT_ANALYSIS_CURRENT und verlangt diese Bestätigung nicht.

**@SchemaNames:** @SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Schemanamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @SchemaNames kombinieren. Übergabe zum Beispiel N'like:App%'.

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. Für GEZIELT genügt eine nichtleere exakte Namensliste als Objektfilter; zusätzliche Schemafilter können den Scope weiter einschränken.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @ObjectNames kombinieren. Übergabe zum Beispiel N'like:App%'.

**@FullObjectNames:** @FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. Dient als zulässiger Objektfilter für GEZIELT.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'GEZIELT'. Nach LTRIM/RTRIM und Großschreibung sind nur GEZIELT und VOLL gültig; NULL wird wie GEZIELT normalisiert. GEZIELT verlangt eine exakte Namenliste, FullObjectNames oder mindestens ein Schema-/Objekt-Pattern; nur DatabaseNames genügt nicht. VOLL erweitert auf die breite Indexkataloganalyse und aktiviert CATALOG_DEEP. Dieser Pfad benötigt die Freigabe für CATALOG_DEEP sowie @HighImpactConfirmed=1; GEZIELT verlangt keine High-Impact-Bestätigung. Leer oder nur Leerzeichen sowie andere Werte sind INVALID_PARAMETER.

**@NurUngenutzt:** @NurUngenutzt bit; Default: 0. bit-Filter auf beide Resultsets: 0 lässt Rowstore- und XTP-Zeilen unabhängig von Nutzung zu; 1 lässt Rowstore-Indizes ohne User-Seeks, Scans und Lookups seit sichtbarem Reset zu und XTP-Indizes mit ScansStarted=0. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte des bit-Parameters zu 1. Bei NULL macht die jeweilige Gleich-Null-ODER-Ungenutzt-Bedingung reguläre genutzte Zeilen nicht wahr; nur Zeilen, deren Ungenutzt-Prüfung wahr ist, können passieren.

**@MinUserUpdates:** @MinUserUpdates bigint; Default: 0. Nichtnegative bigint-Mindestzahl kumulativer User-Update-Operationen im klassischen Rowstore-Resultset; zulässiger Bereich 0 bis 9223372036854775807, Default 0 schränkt nicht ein. Negative Werte führen bei fachlicher Validierung zu INVALID_PARAMETER. NULL besteht den Kleiner-Null-Prüftest in SQL-Dreifachlogik, macht danach aber COALESCE(user_updates,0) >= @MinUserUpdates UNKNOWN und lässt dadurch keine Rowstore-Zeile passieren. Für XTP wird dieser Filter nicht angewandt.

**@PrimaryUndUniqueEinbeziehen:** @PrimaryUndUniqueEinbeziehen bit; Default: 1. bit-Schalter für Primary-Key- und Unique-Constraint-Indizes in Rowstore und XTP: 0 schließt diese beiden Schutzarten aus; 1 lässt sie zu. Bei NULL lautet die Filterbedingung @P=1 OR (is_primary_key=0 AND is_unique_constraint=0): normale Indizes können passieren, PK-/Unique-Constraint-Indizes nicht. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte des bit-Parameters werden beim Binden zu 1 konvertiert.

**@MitMemoryOptimized:** @MitMemoryOptimized bit; Default: 1. bit-Schalter für die separate XTP-Abfrage: 0 überspringt sie; 1 versucht sys.dm_db_xtp_index_stats und befüllt bei Erfolg den XTP-Datenbestand; das vierte RAW-Resultset und der JSON-Schlüssel memoryOptimizedIndexes existieren auch bei übersprungenem Zweig mit leerer Datenmenge. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte des bit-Parameters zu 1. NULL erfüllt IF @MitMemoryOptimized=1 nicht und überspringt den Zweig. Der klassische Rowstore-Zweig bleibt separat.

**@MaxZeilen:** @MaxZeilen int; Default: 5000. Nichtnegative int-TOP-Grenze, Bereich 0 bis 2147483647, Default 5000; 0 oder NULL wird intern zu der bigint-Grenze 9223372036854775807 umgerechnet. Negative Werte führen zu INVALID_PARAMETER. Die Grenze gilt je Datenbank und getrennt für die Rowstore- und XTP-Quellabfragen. Rowstore-TOP sortiert vorab nach UserUpdates absteigend, dann RowCount absteigend; XTP-TOP nach ScansStarted absteigend, dann RowsTouched absteigend. Keine globale Zeilenobergrenze; die Endausgabe hat eigene Sortierung und Katalog-/DMV-Vorarbeit ist nicht dadurch begrenzt.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. int in Millisekunden; gültiger nicht-NULL-Wertebereich 0 bis 60000, 0 setzt vor den fachlichen Zugriffen NOWAIT. Der Bereichstest @LockTimeoutMs NOT BETWEEN 0 AND 60000 wertet NULL als UNKNOWN; zusammen mit nichtnegativem MaxZeilen wird NULL dadurch nicht als INVALID_PARAMETER erkannt. Anschließend wird der Wert mit N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + ... in dynamisches SQL konkateniniert. Bei NULL wird der zusammengebaute SQL-Text NULL; der Quellcode setzt darin keinen konkreten Wert. Vor der Datenbankschleife setzt die Procedure ausdrücklich LOCK_TIMEOUT 0. Der NULL-Batch setzt keine andere konkrete Wartezeit; die zuvor gesetzte NOWAIT-Einstellung bleibt für diesen Ausführungspfad maßgeblich.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Rowstore-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus, Rowstore und stets als viertes Resultset den XTP-Datensatz, bei übersprungenem XTP-Zweig leer als Resultsets aus; TABLE schreibt das Rowstore-Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitive Resultnamen und Stringziel erwartet: rowstoreIndexes als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"rowstoreIndexes":"#IndexHelpTarget"}'.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, rowstoreIndexes, memoryOptimizedIndexes und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, rowstoreIndexes, memoryOptimizedIndexes und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung.

**@Hilfe:** @Hilfe bit; Default: 0. bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht.

## Resultate und Ausgabe

RAW liefert Modulstatus, Datenbankstatus, klassische Indexnutzung und XTP-Nutzung. CONSOLE und TABLE liefern nur klassische Indexnutzung; JSON enthält meta, rowstoreIndexes, memoryOptimizedIndexes und databaseStatus. NONE unterdrückt direkte Resultsets. Hilfe kann vorherige Filtervorbereitung und TABLE-Preflight nicht rückgängig machen.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| rowstoreIndexes | 1 | 1 | [DatabaseName] sysname NOT NULL , [SchemaName] sysname NOT NULL , [ObjectName] sysname NOT NULL , [ObjectId] int NOT NULL , [IndexId] int NOT NULL , [IndexName] sysname NULL , [IndexTypeDesc] nvarchar(60) NULL , [IsMemoryOptimized] bit NOT NULL , [IsSpatialIndex] bit NOT NULL , [IsPrimaryKey] bit NULL , [IsUniqueConstraint] bit NULL , [IsDisabled] bit NULL , [RowCount] bigint NULL , [UserSeeks] bigint NOT NULL , [UserScans] bigint NOT NULL , [UserLookups] bigint NOT NULL , [UserUpdates] bigint NOT NULL , [TotalUserReads] bigint NOT NULL , [ReadWriteRatio] decimal(19,4) NULL , [LastUserSeek] datetime NULL , [LastUserScan] datetime NULL , [LastUserLookup] datetime NULL , [LastUserUpdate] datetime NULL , [SystemSeeks] bigint NOT NULL , [SystemScans] bigint NOT NULL , [SystemLookups] bigint NOT NULL , [SystemUpdates] bigint NOT NULL , [DmvResetTimeServerLocal] datetime2(3) NULL , [UsageClassification] varchar(48) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_IndexUsage] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_IndexUsage

Liefert kumulative Indexnutzungszähler seit dem DMV-Reset für klassische Indizes einschließlich sichtbarer Columnstore- und Spatial-Indizes; XTP-Zähler werden optional getrennt erhoben.

GEZIELT braucht einen Objekt-/Namensfilter; eine Datenbankauswahl allein genügt nicht. VOLL prüft CATALOG_DEEP und verlangt Freigabe sowie @HighImpactConfirmed=1.

CONSOLE: EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'dbo', @ObjectNames=N'ExampleTable', @ResultSetArt='CONSOLE';

RAW und JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'dbo', @ObjectNames=N'ExampleTable', @ResultSetArt='RAW', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_IndexUsage
Version      : 1.1.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Liefert kumulative Indexnutzung seit dem letzten DMV-Reset und klassifiziert gelesene, schreiblastige sowie seit Reset ungenutzte Indizes.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_db_index_usage_stats, sys.dm_db_xtp_index_stats,
               sys.dm_os_sys_info sowie je Datenbank sys.objects, sys.tables,
               sys.schemas, sys.indexes, sys.hash_indexes und sys.partitions.
Parameter    : Signatur und Defaults stehen unmittelbar unter diesem DDL-Kommentar.
               Die PRINT-Hilfe beschreibt jeden Parameter mit Eingabeform,
               NULL-Regeln, Grenzen und den vollständigen festen Optionen.
               GEZIELT benötigt einen Objektfilter; VOLL prüft CATALOG_DEEP
               einschließlich Bestätigung und separater Gruppenberechtigung.
Ausgabe      : RAW liefert Modulstatus, Datenbankstatus, klassische Indexnutzung
               und XTP-Nutzung. CONSOLE und TABLE liefern nur klassische
               Indexnutzung; JSON enthält meta, rowstoreIndexes,
               memoryOptimizedIndexes und databaseStatus. NONE unterdrückt
               direkte Resultsets. Hilfe kann vorherige Filtervorbereitung
               und TABLE-Preflight nicht rückgängig machen.
Berechtigung : SQL Server 2019 VIEW SERVER STATE; SQL Server 2022+ VIEW SERVER PERFORMANCE STATE. Metadaten zusätzlich gemäß Sichtbarkeit.
Eigenlast    : Moderate DMV-/Katalogabfrage; keine Physical-Stats-Scans.
Locking      : DMV plus READUNCOMMITTED-Kataloge; LOCK_TIMEOUT konfigurierbar.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_IndexUsage @DatabaseNames=N'[SampleDatabase]', @ObjectNamePattern=N'like:Fact%';
  EXEC monitor.USP_IndexUsage @DatabaseNames=N'SampleDatabase', @AnalyseModus='VOLL', @HighImpactConfirmed=1, @NurUngenutzt=1, @MinUserUpdates=1000;
  EXEC monitor.USP_IndexUsage @Hilfe=1;
Änderungen   : 1.1.0 - Indexed Views, Spatial-Kennzeichnung und isolierter
               In-Memory-OLTP-Resultset ergänzt.
               1.0.0 - Erstfassung Phase 2.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_IndexUsage
Liefert kumulative Indexnutzungszähler seit dem DMV-Reset für klassische Indizes einschließlich sichtbarer Columnstore- und Spatial-Indizes; XTP-Zähler werden optional getrennt erhoben.
GEZIELT braucht einen Objekt-/Namensfilter; eine Datenbankauswahl allein genügt nicht. VOLL prüft CATALOG_DEEP und verlangt Freigabe sowie @HighImpactConfirmed=1.
CONSOLE: EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'dbo', @ObjectNames=N'ExampleTable', @ResultSetArt='CONSOLE';
RAW und JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'dbo', @ObjectNames=N'ExampleTable', @ResultSetArt='RAW', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json;
TABLE: CREATE TABLE #IndexUsageTarget([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_IndexUsage] @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'dbo', @ObjectNames=N'ExampleTable', @ResultSetArt='TABLE', @ResultTablesJson=N'{"rowstoreIndexes":"#IndexUsageTarget"}'; END TRY BEGIN CATCH DROP TABLE #IndexUsageTarget; THROW; END CATCH; DROP TABLE #IndexUsageTarget;
Hilfe: EXEC [monitor].[USP_IndexUsage] @Hilfe=1;
```

