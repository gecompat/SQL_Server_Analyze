---
skill_format_version: "1.0.0"
name: "monitor.USP_IndexOperationalStats"
schema_name: "monitor"
object_name: "USP_IndexOperationalStats"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Analysiert aktuelle kumulative Zugriffs-, Lock-, Latch-, I/O- Latch-, Page-Split- und Lock-Eskalationszähler je Indexpartition."
source_path: "Code/03_ObjectIndex/025_USP_IndexOperationalStats.sql"
---

# monitor.USP_IndexOperationalStats

## Zweck und Einsatz

Analysiert aktuelle kumulative Zugriffs-, Lock-, Latch-, I/O- Latch-, Page-Split- und Lock-Eskalationszähler je Indexpartition.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.dm_db_index_operational_stats sowie sys.objects, sys.schemas, sys.indexes und sys.tables der jeweiligen Zieldatenbank.

GEZIELT: CONTROL auf dem Objekt oder ausreichender Database-State- Zugriff. VOLL: SQL 2019 VIEW DATABASE STATE, SQL 2022+ VIEW DATABASE PERFORMANCE STATE. Keine Rechtevergabe.

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
| @IndexNames | nvarchar(max) | nein | NULL |
| @IndexNamePattern | nvarchar(4000) | nein | NULL |
| @AnalyseModus | varchar(16) | nein | 'GEZIELT' |
| @PartitionNumber | int | nein | NULL |
| @NurMitAktivitaet | bit | nein | 1 |
| @MinLeafPageAllocations | bigint | nein | 0 |
| @MinLockWaitMs | bigint | nein | 0 |
| @MaxZeilen | int | nein | 5000 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Ein einzelner Datenbankname oder bracket-aware Pipe-Liste einteiliger SQL-Namen. NULL oder nach Trim leere Eingabe bedeutet keine explizite Auswahl und lässt die Datenbankauswahl alle zulässigen sichtbaren Online-Datenbanken bestimmen. Nichtleere Liste: äußere Elementleerzeichen werden getrimmt, [] quotiert Namen und ]] maskiert ]; Pipe trennt außerhalb von Klammern. Leere Elemente, ungültige SQL-Namen und case-sensitive Duplikate führen zu INVALID_PARAMETER. Eine nichtleere Liste ist mit @DatabaseNamePattern gegenseitig exklusiv; NULL/Leerraum plus Pattern ist möglich. Eine Datenbankliste allein erfüllt den GEZIELT-Objektfilter nicht. Die Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. bit-Schalter: 0 schließt master, model, msdb und tempdb aus; 1 erlaubt ihre Aufnahme, soweit sichtbar und online. SQL Server konvertiert beim Binden von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Pattern für Datenbanknamen nach TVF_ParsePattern: äußere Leerzeichen trimmen; Präfixe like:, regex: und regexi: werden ohne Beachtung der Großschreibung erkannt; ohne Präfix gilt LIKE. Der verbleibende Inhalt wird nicht erneut getrimmt; NULL bedeutet kein Pattern, leerer Wert oder leeres Präfix ist ungültig. Datenbankname-Pattern ist mit nichtleerer @DatabaseNames-Liste exklusiv. LIKE-Wildcards gelten im Datenbankkandidatenpfad. regex: setzt Flag c, regexi: Flag i; Regex-Verfügbarkeit wird am Installationsdatenbank-Kontext geprüft und erfordert SQL Server 2025 sowie Compatibility Level 170. LIKE nutzt %, _ und Zeichenklassen [...] unter expliziter case-sensitiver Framework-Collation. Ein Übergabebeispiel ist N'like:App%'; nach Präfixentfernung wird nicht erneut getrimmt.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. bit-Bestätigung für den VOLL-Pfad INDEX_OPERATIONAL_DEEP, der erst nach OBJECT_ANALYSIS_CURRENT aktiviert wird: 0 bestätigt den Deep-Pfad nicht; 1 erfüllt die Bestätigungsanforderung, erteilt selbst aber keine Berechtigung. SQL Server konvertiert gebundene von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines bit-Parameters zu 1. NULL wird vom Datenbankauswahlhelfer als INVALID_PARAMETER abgewiesen. GEZIELT nutzt OBJECT_ANALYSIS_CURRENT und verlangt diese Bestätigung nicht.

**@SchemaNames:** @SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. In GEZIELT benötigt diese Liste zusätzlich die exakte @ObjectNames-Liste; alternativ wird ausschließlich @FullObjectNames verwendet.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Schemanamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @SchemaNames kombinieren. Übergabe zum Beispiel N'like:App%'. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht.

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. Im GEZIELT-Modus benötigt diese Liste zusätzlich eine exakte @SchemaNames-Liste; Pattern ersetzt diese nicht. @FullObjectNames ist eine alternative Auswahl und darf nicht damit kombiniert werden.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @ObjectNames kombinieren. Übergabe zum Beispiel N'like:App%'. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht.

**@FullObjectNames:** @FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. Dient als zulässiger Objektfilter für GEZIELT.

**@IndexNames:** @IndexNames nvarchar(max); Default: NULL. Exakte einteilige Indexnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Indexnamenfilter, eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb von [...]; ]] maskiert ]. Elemente werden getrimmt, als einteilige SQL-Namen validiert und case-sensitive verglichen. Rohsegmente über 4000 UTF-16-Codeeinheiten und Namen über die sysname-Grenze werden abgewiesen. Case-sensitive Duplikate sind ungültig. Nicht gemeinsam mit @IndexNamePattern verwenden.

**@IndexNamePattern:** @IndexNamePattern nvarchar(4000); Default: NULL. Optionales Indexnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @IndexNames kombinieren. Übergabe zum Beispiel N'like:App%'. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht. Ein aktiver Filter trifft keinen NULL-Indexnamen eines Heaps.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'GEZIELT'. Nach LTRIM/RTRIM und Großschreibung sind nur GEZIELT und VOLL gültig; NULL wird wie GEZIELT normalisiert. GEZIELT verlangt @FullObjectNames oder beide exakten Listen @SchemaNames und @ObjectNames. Die Filter können mehrere Objekte bezeichnen; der Quellcode löst @ObjectIdFilter per SELECT-Variablenzuweisung auf passende Objekte auf und garantiert dabei keine bestimmte Auswahl, falls mehrere übereinstimmen. VOLL aktiviert INDEX_OPERATIONAL_DEEP und benötigt dessen Freigabe sowie @HighImpactConfirmed=1. Leer oder nur Leerzeichen sowie andere Werte sind INVALID_PARAMETER.

**@PartitionNumber:** @PartitionNumber int; Default: NULL. Optionale positive int-Partitionsnummer, Bereich 1 bis 2147483647. In GEZIELT wird sie für die zugewiesene ObjectId an die DMF übergeben; NULL umfasst dort alle Partitionen dieses Objekts. VOLL verlangt NULL und verwendet den breiten Rowset-Pfad; nur ein nicht-NULL-Wert ist auf GEZIELT beschränkt. Werte kleiner 1 sind INVALID_PARAMETER.

**@NurMitAktivitaet:** @NurMitAktivitaet bit; Default: 1. bit-Filter: 0 lässt auch Nullaktivitätszeilen zu; 1 verlangt mindestens einen der im Quellprädikat addierten DML-, Range-/Lookup-, Lock-, Page-Latch- oder I/O-Latch-Zähler größer Null. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte konvertieren beim Binden zu 1. Bei NULL wird die Bedingung @P=0 OR Aktivitätsausdruck>0 für Nullaktivität nicht TRUE, sodass solche Zeilen ausgeschlossen werden.

**@MinLeafPageAllocations:** @MinLeafPageAllocations bigint; Default: 0. Nichtnegative bigint-Mindestzahl kumulativer Leaf-Page-Allokationen je Partition, Bereich 0 bis 9223372036854775807; Default 0 schränkt nicht ein. Negative Werte sind INVALID_PARAMETER. NULL besteht den negativen Wertecheck durch UNKNOWN, macht aber leaf_allocation_count >= @P UNKNOWN und lässt keine Zeile passieren.

**@MinLockWaitMs:** @MinLockWaitMs bigint; Default: 0. Nichtnegative bigint-Mindestzeit in Millisekunden für Row- plus Page-Lock-Wait-Zeit, Bereich 0 bis 9223372036854775807; Default 0 schränkt nicht ein. Negative Werte sind INVALID_PARAMETER. NULL besteht den negativen Wertecheck durch UNKNOWN, macht aber den nachfolgenden Summenvergleich UNKNOWN und lässt keine Zeile passieren.

**@MaxZeilen:** @MaxZeilen int; Default: 5000. Nichtnegative int-TOP-Grenze, Bereich 0 bis 2147483647, Default 5000; 0 oder NULL wird intern zu der bigint-Grenze 9223372036854775807 umgerechnet. Negative Werte führen zu INVALID_PARAMETER. TOP gilt für die Operational-Stats-Quellabfrage je Datenbank. Die Auswahl sortiert vorab nach I/O-Latch-Wartezeit, Page-Latch-Wartezeit, Row-/Page-Lock-Wartezeit und Leaf-Page-Allokationen absteigend; die Endausgabe verwendet eine eigene Sortierung. Keine globale Zeilenobergrenze und kein Limit für die vorherige DMF-/Katalogarbeit.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. int in Millisekunden; gültiger nicht-NULL-Wertebereich 0 bis 60000, 0 setzt vor den fachlichen Zugriffen NOWAIT. Der Bereichstest @LockTimeoutMs NOT BETWEEN 0 AND 60000 wertet NULL als UNKNOWN; mit nichtnegativen übrigen Zahlen wird NULL dadurch nicht als INVALID_PARAMETER erkannt. Anschließend wird der Wert mit N'SET LOCK_TIMEOUT ' + CONVERT(nvarchar(11), @LockTimeoutMs) + ... in dynamisches SQL konkateniniert. Bei NULL wird der zusammengebaute SQL-Text NULL; der Quellcode setzt darin keinen konkreten Wert. Vor der Datenbankschleife setzt die Procedure ausdrücklich LOCK_TIMEOUT 0. Der NULL-Batch setzt keine andere konkrete Wartezeit; die zuvor gesetzte NOWAIT-Einstellung bleibt für diesen Ausführungspfad maßgeblich.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Operational-Stats-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: indexOperationalStats als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"indexOperationalStats":"#IndexHelpTarget"}'.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, indexOperationalStats und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, indexOperationalStats und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung.

**@Hilfe:** @Hilfe bit; Default: 0. bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht.

## Resultate und Ausgabe

RAW liefert Modulstatus, Datenbankstatus und Operational Stats. CONSOLE und TABLE liefern nur Operational Stats; JSON enthält meta, indexOperationalStats und databaseStatus. NONE unterdrückt direkte Resultsets. Hilfe folgt bereits erfolgter Filtervorbereitung und gegebenenfalls TABLE-Preflight.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| indexOperationalStats | 1 | 1 | [DatabaseName] sysname NOT NULL, [SchemaName] sysname NULL, [ObjectName] sysname NULL, [ObjectId] int NOT NULL, [IsMemoryOptimized] bit NULL, [IndexId] int NOT NULL, [IndexName] sysname NULL, [IndexTypeDesc] nvarchar(60) NULL, [PartitionNumber] int NOT NULL, [HobtId] bigint NULL, [LeafInsertCount] bigint NOT NULL, [LeafDeleteCount] bigint NOT NULL, [LeafUpdateCount] bigint NOT NULL, [LeafGhostCount] bigint NOT NULL, [LeafPageAllocationCount] bigint NOT NULL, [NonleafPageAllocationCount] bigint NOT NULL, [LeafPageMergeCount] bigint NOT NULL, [RangeScanCount] bigint NOT NULL, [SingletonLookupCount] bigint NOT NULL, [ForwardedFetchCount] bigint NOT NULL, [LobFetchPages] bigint NOT NULL, [RowOverflowFetchPages] bigint NOT NULL, [RowLockCount] bigint NOT NULL, [RowLockWaitCount] bigint NOT NULL, [RowLockWaitMs] bigint NOT NULL, [PageLockCount] bigint NOT NULL, [PageLockWaitCount] bigint NOT NULL, [PageLockWaitMs] bigint NOT NULL, [LockPromotionAttemptCount] bigint NOT NULL, [LockPromotionCount] bigint NOT NULL, [PageLatchWaitCount] bigint NOT NULL, [PageLatchWaitMs] bigint NOT NULL, [PageIoLatchWaitCount] bigint NOT NULL, [PageIoLatchWaitMs] bigint NOT NULL, [TreePageLatchWaitCount] bigint NOT NULL, [TreePageLatchWaitMs] bigint NOT NULL, [PageCompressionAttemptCount] bigint NOT NULL, [PageCompressionSuccessCount] bigint NOT NULL, [LeafAllocationsPerInsert] decimal(19,6) NULL, [LockWaitMsPerWait] decimal(19,4) NULL, [PageLatchWaitMsPerWait] decimal(19,4) NULL, [PageIoLatchWaitMsPerWait] decimal(19,4) NULL, [UsageClassification] varchar(48) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_IndexOperationalStats] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_IndexOperationalStats

Liefert kumulative Operational-Stats-Zähler je Indexpartition; darunter DML, Page-Allokationen, Locks, Latches, I/O-Latches, Scans und Lookups. Metadata-Cache-Eviction kann die Counter zurücksetzen.

GEZIELT verlangt @FullObjectNames oder beide exakten Listen @SchemaNames und @ObjectNames. Muster können zusätzlich filtern; sie ersetzen diese Auswahlvoraussetzung nicht. VOLL prüft INDEX_OPERATIONAL_DEEP und verlangt Freigabe sowie @HighImpactConfirmed=1.

CONSOLE: EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'dbo', @ObjectNames=N'ExampleTable', @ResultSetArt='CONSOLE';

RAW und JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'dbo.ExampleTable', @ResultSetArt='RAW', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_IndexOperationalStats
Version      : 1.1.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Analysiert aktuelle kumulative Zugriffs-, Lock-, Latch-, I/O-
               Latch-, Page-Split- und Lock-Eskalationszähler je Indexpartition.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_db_index_operational_stats sowie sys.objects, sys.schemas,
               sys.indexes und sys.tables der jeweiligen Zieldatenbank.
Parameter    : Signatur und Defaults stehen unmittelbar unter diesem DDL-Kommentar.
               Die PRINT-Hilfe beschreibt jeden Parameter mit Eingabeform,
               NULL-Regeln, Grenzen und den vollständigen festen Optionen.
               GEZIELT verlangt FullObjectNames oder exakte SchemaNames und
               ObjectNames. Zusätzliche Pattern bleiben Patternfilter; sie
               ersetzen diese Anforderung nicht. VOLL prüft
               INDEX_OPERATIONAL_DEEP einschließlich Bestätigung und separater
               Gruppenberechtigung; PartitionNumber ist dann unzulässig.
Ausgabe      : RAW liefert Modulstatus, Datenbankstatus und Operational Stats.
               CONSOLE und TABLE liefern nur Operational Stats; JSON enthält
               meta, indexOperationalStats und databaseStatus. NONE
               unterdrückt direkte Resultsets. Hilfe folgt bereits erfolgter
               Filtervorbereitung und gegebenenfalls TABLE-Preflight.
Berechtigung : GEZIELT: CONTROL auf dem Objekt oder ausreichender Database-State-
               Zugriff. VOLL: SQL 2019 VIEW DATABASE STATE, SQL 2022+
               VIEW DATABASE PERFORMANCE STATE. Keine Rechtevergabe.
Eigenlast    : GEZIELT ruft die DMF je Datenbank für eine zugewiesene ObjectId
               auf. Bei mehreren passenden Objekten ist die Auswahl nicht
               festgelegt; ohne Treffer wird keine NULL-Wildcard übergeben. VOLL kann alle Heap-/B-Tree-/Columnstore-Rowsets lesen und ist
               deshalb explizit gruppengeschützt. TOP reduziert nicht zwingend
               die DMF-Arbeit.
Locking      : Rein lesend, kann Metadaten-/Objektzugriffe auslösen; LOCK_TIMEOUT
               begrenzt Warten. Memory-optimized Indizes sind nicht enthalten und
               werden über USP_IndexUsage/XTP separat analysiert.
Partial      : Datenbankfehler werden isoliert. Ein nicht auflösbares Zielobjekt
               wird niemals als NULL-Wildcard an die DMF übergeben.
Beispiele    :
  EXEC monitor.USP_IndexOperationalStats @DatabaseNames=N'SampleDatabase',
       @SchemaNames=N'dbo', @ObjectNames=N'FactSales';
  EXEC monitor.USP_IndexOperationalStats @DatabaseNames=N'SampleDatabase',
       @AnalyseModus='VOLL', @HighImpactConfirmed=1, @ObjectNamePattern=N'Fact%', @MaxZeilen=10000;
  EXEC monitor.USP_IndexOperationalStats @Hilfe=1;
Änderungen   : 1.1.0 - Exakte Equality-Auflösung erlaubt Unterstriche und andere reguläre Namenszeichen.
               1.0.0 - Erstfassung Phase 2.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_IndexOperationalStats
Liefert kumulative Operational-Stats-Zähler je Indexpartition; darunter DML, Page-Allokationen, Locks, Latches, I/O-Latches, Scans und Lookups. Metadata-Cache-Eviction kann die Counter zurücksetzen.
GEZIELT verlangt @FullObjectNames oder beide exakten Listen @SchemaNames und @ObjectNames. Muster können zusätzlich filtern; sie ersetzen diese Auswahlvoraussetzung nicht. VOLL prüft INDEX_OPERATIONAL_DEEP und verlangt Freigabe sowie @HighImpactConfirmed=1.
CONSOLE: EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N'[ExampleDatabase]', @SchemaNames=N'dbo', @ObjectNames=N'ExampleTable', @ResultSetArt='CONSOLE';
RAW und JSON: DECLARE @Json nvarchar(max); EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'dbo.ExampleTable', @ResultSetArt='RAW', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json;
TABLE: CREATE TABLE #IndexOperationalStatsTarget([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_IndexOperationalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'dbo.ExampleTable', @ResultSetArt='TABLE', @ResultTablesJson=N'{"indexOperationalStats":"#IndexOperationalStatsTarget"}'; END TRY BEGIN CATCH DROP TABLE #IndexOperationalStatsTarget; THROW; END CATCH; DROP TABLE #IndexOperationalStatsTarget;
Hilfe: EXEC [monitor].[USP_IndexOperationalStats] @Hilfe=1;
```

