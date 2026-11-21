---
skill_format_version: "1.0.0"
name: "monitor.USP_IndexPhysicalStats"
schema_name: "monitor"
object_name: "USP_IndexPhysicalStats"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Führt eine bewusst aktivierte und gruppengeschützte Physical-Stats-Analyse für Rowstore-Indizes/Heaps durch; LIMITED ist Default, SAMPLED/DETAILED sind explizit."
source_path: "Code/03_ObjectIndex/070_USP_IndexPhysicalStats.sql"
---

# monitor.USP_IndexPhysicalStats

## Zweck und Einsatz

Führt eine bewusst aktivierte und gruppengeschützte Physical-Stats-Analyse für Rowstore-Indizes/Heaps durch; LIMITED ist Default, SAMPLED/DETAILED sind explizit.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.dm_db_index_physical_stats sowie je Datenbank sys.objects, sys.schemas und sys.indexes.

Immer PHYSICAL_STATS_DEEP mit @HighImpactConfirmed=1 und separater Gruppenfreigabe. SQL 2019 VIEW DATABASE STATE bzw. CONTROL am Objekt; SQL 2022+ VIEW DATABASE PERFORMANCE STATE.

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
| @ScanMode | varchar(16) | nein | 'LIMITED' |
| @IndexId | int | nein | NULL |
| @PartitionNumber | int | nein | NULL |
| @MinPageCount | bigint | nein | 1000 |
| @MinFragmentationPercent | decimal(9,2) | nein | 0 |
| @MaxZeilen | int | nein | 10000 |
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

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. SQL-bit-Bestätigung mit 0 oder 1; von 0 verschiedene konvertierbare Zahlen werden beim Binden 1. PHYSICAL_STATS_DEEP ist stets aktiv, auch für GEZIELT, eine Datenbank und LIMITED. 0 bestätigt den Pfad nicht und führt im Auswahlpfad zu HIGH_IMPACT_CONFIRMATION_REQUIRED; 1 erfüllt die Bestätigung, benötigt aber weiterhin die separate Gruppenfreigabe. NULL wird im normalen Auswahlpfad als INVALID_PARAMETER abgewiesen. Der Schalter vergibt keine SQL-Rechte.

**@SchemaNames:** @SchemaNames nvarchar(max); Default: NULL. Exakte einteilige Schemanamen als bracket-aware Pipe-Liste. NULL bedeutet kein Filter; eine leere oder nur aus Leerzeichen bestehende Liste ist kein NULL und wird als ungültige Namensliste abgewiesen. Pipe trennt außerhalb von [...]; ]] maskiert eine Klammer. Namen werden getrimmt, als einteilige SQL-Namen mit höchstens 128 Zeichen geprüft und case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Doppelte Werte derselben Namensart sind ungültig. Nicht gemeinsam mit @SchemaNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. In GEZIELT benötigt diese Liste zusätzlich die exakte @ObjectNames-Liste; alternativ wird ausschließlich @FullObjectNames verwendet.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Schemanamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @SchemaNames kombinieren. Übergabe zum Beispiel N'like:App%'. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht.

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Exakte einteilige Objektnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Filter, eine leere Liste ist ungültig. Pipe trennt außerhalb geklammerter Namen; ]] maskiert ]. Elemente werden getrimmt und als einteilige SQL-Namen mit höchstens 128 Zeichen validiert, case-sensitive verglichen; Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Duplikate derselben Namensart sind ungültig. Nicht gemeinsam mit @ObjectNamePattern. Bei @FullObjectNames ist die Kombination mit @SchemaNames oder @ObjectNames ungültig. Im GEZIELT-Modus benötigt diese Liste zusätzlich eine exakte @SchemaNames-Liste; Pattern ersetzt diese nicht. @FullObjectNames ist eine alternative Auswahl und darf nicht damit kombiniert werden.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @ObjectNames kombinieren. Übergabe zum Beispiel N'like:App%'. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht.

**@FullObjectNames:** @FullObjectNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; bei Datenbankteil ist das Schema erforderlich, vier Teile sind unzulässig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig; Namensbestandteile werden nach PARSENAME und sysname-Länge geprüft. Pipe trennt nur außerhalb von [...]; ]] maskiert ]. NULL bedeutet kein Filter; N'' ist EMPTY_LIST, Leerzeichen erzeugt ein ungültiges Element. Bestandteile werden case-sensitive verglichen; nicht angegebene Datenbank-/Schemaanteile bleiben im Prädikat offen. Doppelte vollständige Bezüge sind ungültig. Der Helper weist @FullObjectNames zusammen mit @SchemaNames oder @ObjectNames ab, sobald die betreffenden Eingaben nicht NULL sind; auch leere Nicht-NULL-Listen sind also eine Kombination. Dient als zulässiger Objektfilter für GEZIELT.

**@IndexNames:** @IndexNames nvarchar(max); Default: NULL. Exakte einteilige Indexnamen als bracket-aware Pipe-Liste; NULL bedeutet kein Indexnamenfilter, eine leere oder nur aus Leerzeichen bestehende Liste ist ungültig. Pipe trennt außerhalb von [...]; ]] maskiert ]. Elemente werden getrimmt, als einteilige SQL-Namen validiert und case-sensitive verglichen. Rohsegmente über 4000 UTF-16-Codeeinheiten und Namen über die sysname-Grenze werden abgewiesen. Case-sensitive Duplikate sind ungültig. Nicht gemeinsam mit @IndexNamePattern verwenden. Ein aktiver Indexnamensfilter trifft keinen NULL-Indexnamen eines Heaps.

**@IndexNamePattern:** @IndexNamePattern nvarchar(4000); Default: NULL. Optionales Indexnamen-Pattern als nvarchar(4000). NULL deaktiviert den Filter; leer, nur U+0020-Leerzeichen oder ein Präfix ohne Inhalt ist ungültig. Äußere U+0020-Leerzeichen werden zuerst getrimmt; nach Präfixentfernung bleibt der Inhalt unverändert. Präfixe werden ohne Beachtung der Großschreibung erkannt: unpräfigiert oder like: bedeutet case-sensitive SQL-LIKE mit %, _ und [...]; regex: verwendet Flag c, regexi: Flag i. Der dynamische REGEXP_LIKE-Ausdruck wird in der jeweiligen Quelldatenbank ausgeführt und benötigt dort SQL Server 2025 mit Compatibility Level 170. Für diesen Feldfilter gibt es keine separate Versions-/Kompatibilitätsvorprüfung; fehlende Regexunterstützung kann erst beim Ausführen als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit einem nicht-NULL @IndexNames kombinieren. Übergabe zum Beispiel N'like:App%'. In GEZIELT ersetzt ein Pattern die geforderten exakten Schema-/Objektlisten oder @FullObjectNames nicht. Ein aktiver Filter trifft keinen NULL-Indexnamen eines Heaps.

**@AnalyseModus:** @AnalyseModus varchar(16); Default: 'GEZIELT'. Nach LTRIM/RTRIM und UPPER sind ausschließlich GEZIELT und VOLL zulässig; NULL wird GEZIELT, leer oder ein anderer Wert ist INVALID_PARAMETER. GEZIELT verlangt @FullObjectNames oder beide exakten Listen @SchemaNames und @ObjectNames; Pattern allein genügt nicht. Je Datenbank weist SELECT eine passende ObjectId einer Variablen zu; mehrere Treffer ergeben eine nicht zugesicherte Auswahl, nicht mehrere Objektaufrufe. Ohne auflösbares Objekt wird keine NULL-Wildcard an die DMF übergeben. VOLL lässt ObjectId NULL und wendet Namensfilter erst auf die DMF-Zeilen an. Beide Modi bleiben PHYSICAL_STATS_DEEP und benötigen @HighImpactConfirmed=1 sowie die separate Gruppenfreigabe.

**@ScanMode:** @ScanMode varchar(16); Default: 'LIMITED'. Nach LTRIM/RTRIM und UPPER sind ausschließlich LIMITED, SAMPLED und DETAILED zulässig; NULL wird LIMITED, leer oder andere Werte sind INVALID_PARAMETER. LIMITED liest bei B-Bäumen obere Ebenen. SAMPLED schätzt mit etwa 1 % der Seiten, unter 10.000 Seiten als DETAILED. DETAILED liest alle Seiten; Heaps können schon in LIMITED Datenzugriffe erfordern. Die Wahl beeinflusst die Diagnosearbeit, ersetzt aber keine Analysefreigabe.

**@IndexId:** @IndexId int; Default: NULL. Optionale numerische Index-ID, kein Indexname. Die Procedure akzeptiert NULL oder ganze Zahlen von 0 bis 2147483647; 0 bezeichnet den Heap, positive Werte eine Index-ID. Negative Werte sind INVALID_PARAMETER. Die IDs werden unverändert an die DMF weitergereicht; die Procedure prüft ihre Existenz und native Argumentkombination nicht vorab. VOLL erfordert nativ NULL; bei NULL muss auch @PartitionNumber NULL sein. Native Fehler werden je Datenbank protokolliert.

**@PartitionNumber:** @PartitionNumber int; Default: NULL. Optionale ganze Partitionsnummer von 1 bis 2147483647; NULL wählt alle Partitionen des wirksamen DMF-Scopes. Kleinere nicht-NULL-Werte sind INVALID_PARAMETER. Die Procedure prüft Existenz und native Argumentkombination nicht vorab. Ein gesetzter Wert benötigt nativ konkrete Objekt- und Index-IDs. Fehler werden je Datenbank protokolliert; ein kleiner Zahlenwert garantiert keine vorhandene Partition.

**@MinPageCount:** @MinPageCount bigint; Default: 1000. Nichtnegative ganze Zahl von 0 bis 9223372036854775807 in Seiten. Der Default 1000 filtert kleine Ergebniszeilen; 0 setzt keine positive Mindestgröße. Negative Werte sind INVALID_PARAMETER. NULL passiert den negativen Wertecheck, macht den Vergleich page_count >= @MinPageCount aber UNKNOWN und liefert keine Treffer. Das WHERE-Prädikat folgt dem DMF-Aufruf und begrenzt dessen vorherige Arbeit nicht.

**@MinFragmentationPercent:** @MinFragmentationPercent decimal(9,2); Default: 0. Dezimaler Mindestwert von 0.00 bis 100.00 Prozent einschließlich; decimal(9,2) rundet beim Binden auf zwei Nachkommastellen. Außerhalb: INVALID_PARAMETER. NULL passiert die Bereichsprüfung als UNKNOWN, liefert aber keine Treffer. Auch NULL im nativen avg_fragmentation_in_percent erfüllt den Vergleich nicht, selbst bei Mindestwert 0. Der Filter wirkt auf DMF-Ergebnisse und begrenzt keine vorherige Scanarbeit.

**@MaxZeilen:** @MaxZeilen int; Default: 10000. Nichtnegative ganze Zahl von 0 bis 2147483647. NULL oder 0 wird intern zur bigint-TOP-Grenze 9223372036854775807; negative Werte sind INVALID_PARAMETER. Der Default ist 10000. TOP gilt je Datenbank nach DMF-Aufruf und Filtern, geordnet nach page_count und avg_fragmentation_in_percent absteigend; Gleichstände haben keinen zugesicherten Tie-Breaker. Die Endausgabe ergänzt Identitätsfelder zur Sortierung. Kein globales Zeilenlimit und keine Begrenzung der vorherigen DMF-Arbeit.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Wartezeit als nicht-NULL int von 0 bis 60000 Millisekunden. 0 setzt NOWAIT; positive Werte werden im dynamischen Fachbatch als SET LOCK_TIMEOUT übernommen. Werte außerhalb sind INVALID_PARAMETER. NULL passiert den Bereichstest als UNKNOWN, macht den verketteten SQL-Text aber NULL statt des vorgesehenen Fachbatches. Vor der Datenbankschleife setzt die Procedure LOCK_TIMEOUT 0. Für einen regulären Fachaufruf einen konkreten Wert von 0 bis 60000 übergeben; ein bestimmter Fehlerstatus für das NULL-Statement wird hier nicht zugesichert.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. varchar(16), nach LTRIM/RTRIM und UPPER genau CONSOLE, RAW, TABLE oder NONE. NULL und leer werden als leerer String normalisiert und als INVALID_PARAMETER validiert, nicht als NONE behandelt. CONSOLE gibt nur das menschenlesbare Physical-Stats-Fachresultset als Resultset aus; RAW gibt Modulstatus, Datenbankstatus und Fachresultset aus; TABLE schreibt das Fachresultset ins Ziel; NONE unterdrückt normale Resultsets. JSON entsteht unabhängig über @JsonErzeugen. Statuswarnungen können bei @PrintMeldungen=1 zusätzlich als Meldung ausgegeben werden.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE wird ein JSON-Objekt mit exakt einem erlaubten, case-sensitiven Resultnamen und Stringziel erwartet: indexPhysicalStats als Schlüssel. Ziel ist eine vorhandene, leere lokale #Temp-Tabelle, kein ##Temp oder #Monitor*-Name, mit genau einer Seed-Spalte; Zielzuordnungen sind eindeutig. NULL/leer bei TABLE scheitert am Preflight. Bei jeder nicht-TABLE-Ausgabe löst ein nichtleerer, nicht aus Leerzeichen bestehender Wert THROW 51011 aus; NULL, leerer oder nur aus Leerzeichen bestehender Wert ist zulässig. Der Zielname darf höchstens 116 Zeichen haben; Beispiel: N'{"indexPhysicalStats":"#IndexHelpTarget"}'.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. bit-Schalter: 0 erzeugt kein JSON; 1 erstellt JSON unabhängig von @ResultSetArt. Das JSON-Objekt enthält die Schlüssel meta, indexPhysicalStats und databaseStatus. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte eines gebundenen bit-Parameters werden zu 1 konvertiert; NULL aktiviert die IF-Bedingung nicht und erzeugt kein JSON.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. nvarchar(max)-OUTPUT-Parameter; zum Empfangen des JSON eine nvarchar(max)-Variable mit OUTPUT binden; der Parameter darf ausgelassen werden, dann gilt der deklarierte Default NULL. Die Procedure setzt den Wert beim Eintritt auf NULL; wenn @JsonErzeugen=1, wird das JSON-Dokument mit meta, indexPhysicalStats und databaseStatus zurückgegeben, andernfalls bleibt der Output NULL; der frühe @Hilfe-Zweig gibt ebenfalls kein JSON zurück.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. bit-Schalter: 0 unterdrückt strukturierte Warnmeldungen; 1 sendet bei Status ungleich AVAILABLE eine RAISERROR-Meldung mit Severity 10 und NOWAIT. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert. NULL erfüllt IF @PrintMeldungen=1 nicht und unterdrückt die Meldung.

**@Hilfe:** @Hilfe bit; Default: 0. bit-Schalter: 0 führt nach Auswahl-/Filtervorbereitung die Fachanalyse aus; 1 gibt die eingebauten PRINT-Zeilen aus und kehrt vor der fachlichen DMV-/Katalogerhebung zurück. Namefilter- und Datenbankkandidatenauswahl sowie Gate-Prüfungen liegen davor; TABLE führt außerdem das Mapping-Preflight vorher aus. Die Vorbereitung wird durch den Hilfezweig nicht unterlassen. Von 0 verschiedene, zu bit konvertierbare Zahlenwerte werden beim Binden zu 1 konvertiert; NULL erfüllt den Hilfezweig nicht.

## Resultate und Ausgabe

RAW liefert Modulstatus, Datenbankstatus und Fachdaten. CONSOLE und TABLE liefern ausschließlich die Fachdaten; JSON enthält meta, indexPhysicalStats und databaseStatus. NONE unterdrückt direkte Resultsets. Hilfe folgt bereits erfolgter Filtervorbereitung und gegebenenfalls TABLE-Preflight.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| indexPhysicalStats | 1 | 1 | [DatabaseName] sysname NOT NULL,[SchemaName] sysname NULL,[ObjectName] sysname NULL,[ObjectId] int NOT NULL,[IndexId] int NOT NULL,[IndexName] sysname NULL,[IndexTypeDesc] nvarchar(60) NULL, [PartitionNumber] int NULL,[IndexLevel] tinyint NULL,[AllocationUnitTypeDesc] nvarchar(60) NULL,[IndexDepth] tinyint NULL,[IndexTypeDescPhysical] nvarchar(60) NULL, [AvgFragmentationPercent] float NULL,[FragmentCount] bigint NULL,[AvgFragmentSizePages] float NULL,[PageCount] bigint NULL,[AvgPageSpaceUsedPercent] float NULL, [RecordCount] bigint NULL,[GhostRecordCount] bigint NULL,[VersionGhostRecordCount] bigint NULL,[MinRecordSizeBytes] int NULL,[MaxRecordSizeBytes] int NULL,[AvgRecordSizeBytes] float NULL, [ForwardedRecordCount] bigint NULL,[CompressedPageCount] bigint NULL,[ScanMode] varchar(16) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_IndexPhysicalStats] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_IndexPhysicalStats

Liest physische Strukturstatistiken über sys.dm_db_index_physical_stats; eine Wartungsaktion wird nicht ausgeführt.

PHYSICAL_STATS_DEEP ist in jedem Modus aktiv und verlangt @HighImpactConfirmed=1 sowie die separate Gruppenfreigabe. GEZIELT benötigt FullObjectNames oder exakte SchemaNames und ObjectNames.

Die PRINT-Hilfe folgt Namens-/Datenbankvorbereitung und gegebenenfalls TABLE-Preflight. Normale Analyseparameter werden danach geprüft.

Beispiel RAW: EXEC [monitor].[USP_IndexPhysicalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @ScanMode='LIMITED', @ResultSetArt='RAW';


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_IndexPhysicalStats
Version      : 1.1.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Führt eine bewusst aktivierte und gruppengeschützte Physical-Stats-Analyse für Rowstore-Indizes/Heaps durch; LIMITED ist Default, SAMPLED/DETAILED sind explizit.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.dm_db_index_physical_stats sowie je Datenbank sys.objects, sys.schemas und sys.indexes.
Parameter    : Signatur und Defaults stehen unmittelbar unter diesem DDL-Kommentar.
               Die PRINT-Hilfe erklärt jeden Parameter mit Eingabeform,
               NULL-/Leerwertregeln, Grenzen und allen festen Optionen.
Ausgabe      : RAW liefert Modulstatus, Datenbankstatus und Fachdaten.
               CONSOLE und TABLE liefern ausschließlich die Fachdaten;
               JSON enthält meta, indexPhysicalStats und databaseStatus.
               NONE unterdrückt direkte Resultsets. Hilfe folgt bereits
               erfolgter Filtervorbereitung und gegebenenfalls TABLE-Preflight.
Berechtigung : Immer PHYSICAL_STATS_DEEP mit @HighImpactConfirmed=1 und separater Gruppenfreigabe. SQL 2019 VIEW DATABASE STATE bzw. CONTROL am Objekt; SQL 2022+ VIEW DATABASE PERFORMANCE STATE.
Eigenlast    : GEZIELT weist je Datenbank eine ObjectId zu; mehrere Treffer garantieren keine bestimmte Auswahl. Ohne Treffer wird keine NULL-Wildcard übergeben. VOLL kann breit lesen. LIMITED kann bereits relevant sein; SAMPLED/DETAILED können hohe I/O-/CPU-Kosten erzeugen. TOP filtert erst nach DMF-Ausführung.
Locking      : DMF kann IS-Locks auf Metadaten/Objekten anfordern; LOCK_TIMEOUT begrenzt Warten. Keine automatische Wartung.
Partial      : Fehler je Datenbank bzw. Teilquelle werden isoliert; vorhandene
               Teilergebnisse bleiben erhalten. Das Framework vergibt keine Rechte.
Beispiele    :
  EXEC monitor.USP_IndexPhysicalStats @DatabaseNames=N'SampleDatabase', @FullObjectNames=N'ExampleSchema.ExampleTable', @HighImpactConfirmed=1;
  EXEC monitor.USP_IndexPhysicalStats @DatabaseNames=N'SampleDatabase', @AnalyseModus='VOLL', @HighImpactConfirmed=1, @ObjectNamePattern=N'like:Fact%', @ScanMode='SAMPLED', @MinPageCount=10000;
  EXEC monitor.USP_IndexPhysicalStats @Hilfe=1;
Änderungen   : 1.1.0 - GEZIELT als sicherer Default; fehlende exakte Objektauflösung löst keinen Datenbank-Wildcardscan aus.
               1.0.0 - Erstfassung Phase 2.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_IndexPhysicalStats
Liest physische Strukturstatistiken über sys.dm_db_index_physical_stats; eine Wartungsaktion wird nicht ausgeführt.
PHYSICAL_STATS_DEEP ist in jedem Modus aktiv und verlangt @HighImpactConfirmed=1 sowie die separate Gruppenfreigabe. GEZIELT benötigt FullObjectNames oder exakte SchemaNames und ObjectNames.
Die PRINT-Hilfe folgt Namens-/Datenbankvorbereitung und gegebenenfalls TABLE-Preflight. Normale Analyseparameter werden danach geprüft.
Beispiel RAW: EXEC [monitor].[USP_IndexPhysicalStats] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @HighImpactConfirmed=1, @ScanMode='LIMITED', @ResultSetArt='RAW';
Hilfe: EXEC [monitor].[USP_IndexPhysicalStats] @Hilfe=1;
```

