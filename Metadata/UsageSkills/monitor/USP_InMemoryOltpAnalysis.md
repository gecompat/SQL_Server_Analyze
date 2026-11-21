---
skill_format_version: "1.0.0"
name: "monitor.USP_InMemoryOltpAnalysis"
schema_name: "monitor"
object_name: "USP_InMemoryOltpAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Analysiert sichtbare In-Memory-OLTP-Konfiguration und isolierte Laufzeitevidenz zu Speicher, Hashindizes, Checkpoint-Dateien, aktiven Transaktionen und Resource-Governor-Pools."
source_path: "Code/09_VersionAdaptive/030_USP_InMemoryOltpAnalysis.sql"
---

# monitor.USP_InMemoryOltpAnalysis

## Zweck und Einsatz

Analysiert sichtbare In-Memory-OLTP-Konfiguration und isolierte Laufzeitevidenz zu Speicher, Hashindizes, Checkpoint-Dateien, aktiven Transaktionen und Resource-Governor-Pools.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.tables, sys.table_types, sys.filegroups, sys.hash_indexes, sys.dm_db_xtp_table_memory_stats, sys.dm_db_xtp_memory_consumers, sys.dm_db_xtp_hash_index_stats (opt-in), sys.dm_db_xtp_checkpoint_files, sys.dm_db_xtp_transactions, sys.databases und sys.dm_resource_governor_resource_pools.

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
| @MitHashIndexStats | bit | nein | 0 |
| @NurProblematisch | bit | nein | 0 |
| @MinTableMemoryMb | decimal(19,2) | nein | 1024 |
| @HashAvgChainWarn | decimal(19,4) | nein | 10 |
| @HashMaxChainWarn | bigint | nein | 100 |
| @HashMinEmptyBucketPercent | decimal(9,4) | nein | 10 |
| @WaitingCheckpointWarnMb | decimal(19,2) | nein | 1024 |
| @ActiveTransactionWarnCount | int | nein | 100 |
| @PoolUsedWarnPercent | decimal(9,4) | nein | 80 |
| @MaxZeilen | int | nein | 2000 |
| @LockTimeoutMs | int | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@DatabaseNames:** @DatabaseNames: nvarchar(max); Default=NULL. Datenform: bracket-aware Pipe-Liste einteiliger Datenbanknamen (sysname, maximal 128 Zeichen je Name); äußere Elementleerzeichen werden entfernt, ]] maskiert ] innerhalb [...], Namen werden case-sensitiv verglichen. NULL, leer oder nur Leerzeichen wählt alle sichtbaren Online-Benutzerdatenbanken, außer den per @SystemdatenbankenEinbeziehen ausgeschlossenen Systemdatenbanken. Duplikate, leere Elemente oder ungültige Namen sind INVALID_PARAMETER. Mit @DatabaseNamePattern exklusiv. Das Zeichen | trennt nur außerhalb von [...]; in [...] bleibt | im Namen, und ]] maskiert ein inneres ].

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen: bit; Default=0. Zulässige Werte: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. Numerische Nichtnullwerte werden durch T-SQL zu 1 konvertiert. NULL ist im normalen Datenbankauswahlpfad INVALID_PARAMETER.

**@DatabaseNamePattern:** @DatabaseNamePattern: nvarchar(4000); Default=NULL. NULL bedeutet kein Datenbank-Patternfilter. Datenform: ein Patterntext. Unpräfigiertes Pattern und like: bedeuten SQL LIKE mit %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS; regex: ist case-sensitive, regexi: case-insensitive. Präfixerkennung ist case-insensitive; äußere Eingabeleerzeichen werden vor Erkennung entfernt, Rest danach nicht erneut getrimmt. Leerer Inhalt ungültig. Regex braucht SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Exklusiv mit @DatabaseNames.

**@HighImpactConfirmed:** @HighImpactConfirmed: bit; Default=0. Zulässige Werte: 0 bestätigt keinen zusätzlichen High-Impact-Pfad; 1 bestätigt High-Impact-Ausführung eines tatsächlich aktivierten Pfads. Diese Bestätigung ist von der unabhängigen Gruppenautorisierung getrennt und verleiht keine Gruppenmitgliedschaft oder Freigabe. Ist das Gruppengate aktiv, muss der Aufrufer bereits autorisiert sein. NULL ist im Datenbankauswahlpfad ungültig.

**@SchemaNames:** @SchemaNames: nvarchar(max); Default=NULL. Datenform: bracket-aware Pipe-Liste einteiliger Schemanamen (sysname, maximal 128 Zeichen je Name); ]] maskiert ] innerhalb [...], äußere Elementleerzeichen werden entfernt, Vergleich ist case-sensitiv. NULL bedeutet kein Filter; leere Liste/Elemente, Duplikate und ungültige oder mehrteilige Namen sind ungültig. Exklusiv mit @SchemaNamePattern und @FullObjectNames. Das Zeichen | trennt nur außerhalb von [...]; in [...] bleibt | im Namen, und ]] maskiert ein inneres ].

**@SchemaNamePattern:** @SchemaNamePattern: nvarchar(4000); Default=NULL. NULL bedeutet kein Schema-Patternfilter. Datenform: ein Patterntext. Unpräfigiert oder like: = SQL LIKE; regex: = case-sensitive, regexi: = case-insensitive. %, _, [...] gelten bei LIKE. Präfixerkennung ohne Beachtung der Großschreibung; äußere Eingabeleerzeichen werden entfernt, Rest nicht erneut getrimmt. Leerer Inhalt ungültig; Regex braucht SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Exklusiv mit @SchemaNames; mit @FullObjectNames kombinierbar.

**@ObjectNames:** @ObjectNames: nvarchar(max); Default=NULL. Datenform: bracket-aware Pipe-Liste einteiliger Objektnamen (sysname, maximal 128 Zeichen je Name); ]] maskiert ] innerhalb [...], äußere Elementleerzeichen werden entfernt, Vergleich ist case-sensitiv. NULL bedeutet kein Filter; leere Liste/Elemente, Duplikate und ungültige oder mehrteilige Namen sind ungültig. Exklusiv mit @ObjectNamePattern und @FullObjectNames. Das Zeichen | trennt nur außerhalb von [...]; in [...] bleibt | im Namen, und ]] maskiert ein inneres ].

**@ObjectNamePattern:** @ObjectNamePattern: nvarchar(4000); Default=NULL. NULL bedeutet kein Objekt-Patternfilter. Datenform: ein Patterntext. Unpräfigiert oder like: = SQL LIKE; regex: = case-sensitive, regexi: = case-insensitive. %, _, [...] gelten bei LIKE. Präfixerkennung ohne Beachtung der Großschreibung; äußere Eingabeleerzeichen werden entfernt, Rest nicht erneut getrimmt. Leerer Inhalt ungültig; Regex braucht SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Exklusiv mit @ObjectNames; mit @FullObjectNames kombinierbar.

**@FullObjectNames:** @FullObjectNames: nvarchar(max); Default=NULL. Datenform: bracket-aware Pipe-Liste mit verpflichtendem Objektnamen als Objekt, Schema.Objekt oder Datenbank.Schema.Objekt; Schema und Datenbank sind optionale Qualifier. ]] maskiert ] in [...], Vergleiche sind case-sensitiv. NULL bedeutet kein Filter; leere Liste/Elemente oder Duplikate ungültig. Vier Teile sind ungültig; PARSENAME-Strukturprüfung ist keine vollständige SQL-Bezeichnergrammatik. Exklusiv mit den exakten Listen @SchemaNames und @ObjectNames; @SchemaNamePattern und @ObjectNamePattern dürfen zusätzlich filtern. Das Zeichen | trennt nur außerhalb von [...]; in [...] bleibt | im Namen, und ]] maskiert ein inneres ].

**@MitHashIndexStats:** @MitHashIndexStats: bit; Default=0. Zulässige Werte: 0 lässt sys.dm_db_xtp_hash_index_stats aus; 1 aktiviert diese optionale vollständige Hashindex-DMV-Auswertung und CATALOG_DEEP. Die DMV kann vollständige In-Memory-Tabellen scannen; diese Arbeit ist nicht durch @MaxZeilen begrenzt. Dafür sind @HighImpactConfirmed=1 und, sofern das Policy-Gruppengate gilt, unabhängige Gruppenautorisierung erforderlich. NULL ist ungültig.

**@NurProblematisch:** @NurProblematisch: bit; Default=0. Zulässige Werte: 0 filtert den Problemscope nicht; Findings und sämtliche Detailzeilen bleiben sichtbar (Findings sind INFO/WARN, Details können NONE enthalten); 1 wählt Findings und Details mit Severity WARN. TableMemory ist dann leer (nur INFO/NONE); MemoryConsumer-Details ohne Severity entfallen. Findingszähler, Status und Quellzeilenzahlen bleiben ungekürzt. NULL ist ungültig.

**@MinTableMemoryMb:** @MinTableMemoryMb: decimal(19,2); Default=1024 MB. Zulässig 0 bis 99999999999999999.99. Wenn verfügbare TableUsedMb+IndexUsedMb mindestens den Wert erreicht, entsteht LARGE_MEMORY_CONSUMER_CONTEXT (INFO). Bei 0 greift der Vergleich für verfügbare Summen ab 0; SQL-NULL wird nicht in 0 umgewandelt und begründet keinen FindingCode aus diesem Vergleich. NULL Parameter ungültig.

**@HashAvgChainWarn:** @HashAvgChainWarn: decimal(19,4); Default=10 Kettenglieder. Zulässig 1 bis 100000; WARN bei AverageChainLength strikt größer als dem Wert. 0 ist ungültig; NULL ist ungültig.

**@HashMaxChainWarn:** @HashMaxChainWarn: bigint; Default=100 Kettenglieder. Zulässig 1 bis 9223372036854775807; WARN bei MaxChainLength größer oder gleich dem Wert. 0 ist ungültig; NULL ist ungültig.

**@HashMinEmptyBucketPercent:** @HashMinEmptyBucketPercent: decimal(9,4); Default=10 Prozent. Zulässig 0 bis 100; WARN bei EmptyBucketPercent strikt kleiner als dem Wert. Bei 0 löst dieser Vergleich keine Warnung aus. NULL ist ungültig.

**@WaitingCheckpointWarnMb:** @WaitingCheckpointWarnMb: decimal(19,2); Default=1024 MB. Zulässig 0 bis 99999999999999999.99; WARN, wenn aggregierte Dateigröße im Zustand WAITING FOR LOG TRUNCATION mindestens den Wert erreicht. Bei 0 wird jede verfügbare passende Zeile gewarnt. NULL ist ungültig.

**@ActiveTransactionWarnCount:** @ActiveTransactionWarnCount: int; Default=100 Transaktionen. Zulässig 1 bis 2147483647; WARN für ACTIVE/VALIDATING, wenn die aggregierte Anzahl mindestens den Wert erreicht. 0 ist ungültig; NULL ist ungültig.

**@PoolUsedWarnPercent:** @PoolUsedWarnPercent: decimal(9,4); Default=80 Prozent. Zulässig 0 bis 100; WARN für benannte Pools bei Used/Target ab dem Wert oder OutOfMemoryCount>0. Bei 0 greift der Auslastungsvergleich bei verfügbarem Quotienten. NULL ist ungültig. Kein Herstellerlimit oder Autotuningwert.

**@MaxZeilen:** @MaxZeilen: int; Default=2000 Zeilen je Findings-/Detailresultset. Zulässig: NULL oder 0 = unbegrenzt, 1 bis 2147483647 = jeweiliges TOP-Limit, negativ = INVALID_PARAMETER. Wirkt separat nach der Sortierung jeder Ausgabe; DB-/Quellenstatus und Quellzeilenzahlen bleiben vollständig. Es begrenzt keine Quellarbeit und insbesondere keinen Hash-DMV-Tabellenscan.

**@LockTimeoutMs:** @LockTimeoutMs: int; Default=0 Millisekunden. Zulässig 0 bis 60000. 0 bedeutet NOWAIT; sonst ist der Wert das Timeout der datenbankbezogenen Abfragen. Danach setzt die Procedure den Sitzungswert auf 0 zurück. NULL oder außerhalb des Bereichs ist INVALID_PARAMETER.

**@ResultSetArt:** @ResultSetArt: varchar(16); Default=CONSOLE. Exakte Menge getrimmter, case-insensitiver Werte: CONSOLE rendert Findings; RAW liefert Meta-, Datenbank-/Quellenstatus und alle sieben fachlichen Resultsets; TABLE schreibt ausschließlich findings in das benannte Ziel; NONE unterdrückt Resultsets. NULL oder jeder andere Wert ist INVALID_PARAMETER. JSON-Ausgabe bleibt unabhängig davon.

**@ResultTablesJson:** @ResultTablesJson: nvarchar(max); Default=NULL. Datenform bei TABLE: JSON-Objekt mit genau einem Key findings und einem Stringziel für eine vorhandene, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte. Name höchstens 116 Zeichen; keine ##-, permanenten oder reservierten #Monitor*-Ziele. NULL/leer ist bei TABLE ungültig; außerhalb TABLE darf nur NULL/leerer Text stehen. TABLE-Preflight läuft vor @Hilfe.

**@JsonErzeugen:** @JsonErzeugen: bit; Default=0. Zulässige Werte: 0 erzeugt kein JSON; 1 erzeugt JSON unabhängig von @ResultSetArt. NULL ist ungültig.

**@Json:** @Json: nvarchar(max); Default=NULL OUTPUT. Kein Eingabewert. Optionaler OUTPUT-Empfang; bei gewünschter Rückgabe den Parameter als OUTPUT binden. Die Procedure setzt ihn beim Einstieg auch im Hilfepfad auf NULL. Das JSON-Objekt enthält meta sowie die neun Arrays databaseStatus, sourceStatus, findings, tableMemory, hashIndexes, memoryConsumers, checkpointFiles, transactions und resourcePools; NULL-Properties werden ausgelassen.

**@PrintMeldungen:** @PrintMeldungen: bit; Default=1. Zulässige Werte: 0 unterdrückt normale Status-PRINTs; 1 druckt sie bei Status außerhalb AVAILABLE/NOT_APPLICABLE. NULL ist ungültig. Help-PRINTs werden davon nicht gesteuert.

**@Hilfe:** @Hilfe: bit; Default=0. Zulässige Werte: 0 führt die Analyse aus; 1 druckt diese Hilfe und kehrt früh zurück. NULL folgt dem normalen Pfad. TABLE-Preflight liegt davor; @Json wird zuvor auf NULL gesetzt. Die vier Status-/Fehler-OUTPUT-Werte bleiben im Hilfe-RETURN unverändert.

**@StatusCodeOut:** @StatusCodeOut: varchar(40); Default=NULL OUTPUT. Kein Eingabewert; optionale OUTPUT-Bindung für den Modulstatus des normalen Abschlusses. Nicht gebunden bedeutet kein empfangener Rückgabewert. Im Hilfe-RETURN unverändert.

**@IsPartialOut:** @IsPartialOut: bit; Default=NULL OUTPUT. Kein Eingabewert; optionale OUTPUT-Bindung für Partialität (0 oder 1) des normalen Abschlusses. Nicht gebunden bedeutet kein empfangener Rückgabewert. Im Hilfe-RETURN unverändert.

**@ErrorNumberOut:** @ErrorNumberOut: int; Default=NULL OUTPUT. Kein Eingabewert; optionale OUTPUT-Bindung für eine verfügbare Fehlernummer oder NULL, wenn keine gemeldet wird. Nicht gebunden bedeutet kein empfangener Rückgabewert. Im Hilfe-RETURN unverändert.

**@ErrorMessageOut:** @ErrorMessageOut: nvarchar(2048); Default=NULL OUTPUT. Kein Eingabewert; optionale OUTPUT-Bindung für verfügbaren Fehlertext oder NULL. Nicht gebunden bedeutet kein empfangener Rückgabewert. Im Hilfe-RETURN unverändert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| findings | 1 | 1 | [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL , [DatabaseName] sysname NULL , [SchemaName] sysname NULL , [ObjectName] sysname NULL , [IndexName] sysname NULL , [Severity] varchar(16) NOT NULL , [Confidence] varchar(16) NOT NULL , [FindingCode] varchar(120) NOT NULL , [MetricName] varchar(80) NOT NULL , [MetricValue] decimal(38,4) NULL , [ThresholdValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL , [RecommendedNextCheck] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_InMemoryOltpAnalysis] @DatabaseNames=N'[ExampleDatabase]', @MitHashIndexStats=0, @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Momentaufnahmen und heuristische Prüfhinweise sind kein Beweis für Speicherknappheit, fehlerhafte Bucket-Zahlen, Log-Stau oder Transaktionsprobleme. Keine DDL-, Daten- oder Definitionsscans.

MEDIUM; Hashindex-Laufzeitstatistik HIGH_OPT_IN, da die DMV nach Herstellerdokumentation vollständige Tabellen scannen kann.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_InMemoryOltpAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Typ          : Stored Procedure
Zweck        : Analysiert sichtbare In-Memory-OLTP-Konfiguration und isolierte
               Laufzeitevidenz zu Speicher, Hashindizes, Checkpoint-Dateien,
               aktiven Transaktionen und Resource-Governor-Pools.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.tables, sys.table_types, sys.filegroups, sys.hash_indexes,
               sys.dm_db_xtp_table_memory_stats,
               sys.dm_db_xtp_memory_consumers,
               sys.dm_db_xtp_hash_index_stats (opt-in),
               sys.dm_db_xtp_checkpoint_files, sys.dm_db_xtp_transactions,
               sys.databases und sys.dm_resource_governor_resource_pools.
Methodik     : Jede DMV-Quelle wird separat best effort ausgewertet. Fehlende
               Rechte oder Quellen verwerfen andere zugängliche Evidenz nicht.
Grenzen      : Momentaufnahmen und heuristische Prüfhinweise sind kein Beweis
               für Speicherknappheit, fehlerhafte Bucket-Zahlen, Log-Stau oder
               Transaktionsprobleme. Keine DDL-, Daten- oder Definitionsscans.
Kosten       : MEDIUM; Hashindex-Laufzeitstatistik HIGH_OPT_IN, da die DMV nach
               Herstellerdokumentation vollständige Tabellen scannen kann.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_InMemoryOltpAnalysis
Die Procedure führt eine rein lesende Best-Effort-Tiefenanalyse sichtbarer In-Memory-OLTP-Katalogmetadaten und isolierter Laufzeitquellen durch. Momentaufnahmen sind nicht atomar; fehlende Quellen entwerten andere erfolgreiche Quellen nicht.
Namenslisten prüfen Struktur und Duplikate, nicht vorab Katalogexistenz oder Berechtigungen. Bei @FullObjectNames bleibt das Objekt erforderlich; Schema und Datenbank können als Qualifier fehlen. Überlange PARSENAME-Bestandteile garantieren keinen bestimmten Fehlercode.
Grenzwerte erzeugen Prüfhinweise, keine automatische DDL- oder Kapazitätsempfehlung.
Bitparameter werden als 0 oder 1 angegeben; 0 und 1 haben die jeweilige Bedeutung oben. T-SQL konvertiert andere konvertierbare numerische Nichtnullwerte zu 1. NULL-Verhalten ist je Parameter oben getrennt; @Hilfe=NULL folgt dem normalen Pfad.
Beispiel: begrenzte Standardanalyse einer synthetischen Datenbank:
Beispiel: JSON unabhängig von der Console-Ausgabe:
DECLARE @InMemoryJson nvarchar(max);
Beispiel: TABLE mit leerem lokalem Seed-Ziel; der einzige gültige Key ist findings:
CREATE TABLE #InMemoryOltpAnalysis_HelpExample (Placeholder int NULL);
Es werden keine Benutzertabellendaten, Moduldefinitionen, SQL-Texte, Transaktions-IDs oder Checkpoint-Dateipfade gelesen. Keine Datenänderung, DDL oder automatische Gesundheitsentscheidung.
```

