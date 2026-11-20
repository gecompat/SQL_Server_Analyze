---
skill_format_version: "1.0.0"
name: "monitor.USP_BufferPoolAnalysis"
schema_name: "monitor"
object_name: "USP_BufferPoolAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure liefert eine korrelierte Momentaufnahme von Prozess-, Betriebssystem- und Resource-Semaphore-Speicherwerten sowie optionalen Memory-Clerk- und Buffer-Pool-Verteilungen."
source_path: "Code/08_ServerHealth/160_USP_BufferPoolAnalysis.sql"
---

# monitor.USP_BufferPoolAnalysis

## Zweck und Einsatz

Die Procedure liefert eine korrelierte Momentaufnahme von Prozess-, Betriebssystem- und Resource-Semaphore-Speicherwerten sowie optionalen Memory-Clerk- und Buffer-Pool-Verteilungen.

## Voraussetzungen und Rechte

sys.dm_os_process_memory, sys.dm_os_sys_memory, sys.dm_exec_query_resource_semaphores, sys.dm_os_memory_clerks und optional sys.dm_os_buffer_descriptors.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MitMemoryClerks | bit | nein | 1 |
| @MitBufferPoolVerteilung | bit | nein | 0 |
| @MaxZeilen | int | nein | 100 |
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

**@MitMemoryClerks:** @MitMemoryClerks bit; Default: 1. NULL, 0 oder 1. Nur 1 liest sys.dm_os_memory_clerks und gruppiert nach Clerktyp; 0/NULL überspringt diese Quelle und ihr Resultset bleibt leer. MemorySnapshot und Resource Semaphores werden unabhängig gesammelt.

**@MitBufferPoolVerteilung:** @MitBufferPoolVerteilung bit; Default: 0. NULL, 0 oder 1. Nur 1 scannt sys.dm_os_buffer_descriptors und aggregiert gecachte Seiten nach Datenbank-ID und aufgelöstem Namen; 0/NULL ist der sichere Standard und überspringt den breiten Descriptorpfad. Die Quelle wird vor Gruppierung gelesen. MaxZeilen begrenzt nicht den Scan. Nicht aufgelöste Datenbanknamen bleiben NULL.

**@MaxZeilen:** @MaxZeilen int; Default: 100. int-Eingabe: NULL oder 0 bedeutet unbegrenzt; positive Werte bis 2147483647 begrenzen Semaphore-, Clerk- und Buffer-Pool-Gruppen ausschließlich in RAW und JSON. Negative Werte sind INVALID_PARAMETER. MemorySnapshot bleibt ungekürzt; CONSOLE liefert nur den vollständigen MemorySnapshot, TABLE schreibt nur diesen Snapshot. Die Grenze folgt auf Sammlung und Aggregation und begrenzt insbesondere den Descriptor-Scan nicht.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. NULL oder Text, der nach Trim und Großschreibung CONSOLE, RAW, TABLE oder NONE ergibt. RAW liefert Statuskontext und vier Fachresultsets. CONSOLE wird intern zu NONE normalisiert und ruft danach den Console-Helper nur für MemorySnapshot auf; die direkte CONSOLE-Resultsetansicht im Procedurekörper ist dadurch nicht erreichbar. TABLE wird ebenfalls zu NONE normalisiert und schreibt ausschließlich MemorySnapshot in die lokale Zieltabellenzuordnung; NONE unterdrückt normale Resultsets. NULL/Leertext und andere Werte setzen INVALID_PARAMETER. Nichtleeres Mapping außerhalb TABLE wirft 51011; das TABLE-Mapping wird vor Hilfe und Parameterprüfung vorbereitet.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. NULL oder ein JSON-Objekt mit genau dem Schlüssel memory und einem Stringwert für den Namen einer vorhandenen lokalen #Temp-Tabelle, etwa N'{"memory":"#BufferPoolAnalysis_HelpExample"}'. Für TABLE muss das Ziel leer sein und genau eine beliebig typisierte Seed-Spalte besitzen. NULL, nach Trim von U+0020 leere Eingabe oder fehlerhaftes Mapping scheitern am Preflight vor @Hilfe und Sammlung. Der Preflight prüft das Ziel; erst beim TABLE-Schreiben werden seine Zielspalten eingerichtet. Außerhalb TABLE sind NULL oder nach diesem Trim leere Werte zulässig, sonst wird 51011 geworfen. Globale und permanente Tabellen sowie der reservierte #Monitor-Präfix sind unzulässig.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. NULL, 0 oder 1. Nur 1 baut zusätzlich JSON in @Json; 0/NULL lässt @Json NULL. Die Gruppen memory, resourceSemaphores, memoryClerks und bufferPool werden unabhängig von der JSON-Ausgabe gesammelt, wenn ihre Quellen eingeschaltet sind. MaxZeilen begrenzt die drei Gruppenarrays, nicht memory.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Bindung nvarchar(max), mit vorab deklarierter nvarchar(max)-Variable und OUTPUT zu übergeben. Beim Eintritt wird sie auf NULL gesetzt; nur @JsonErzeugen=1 belegt sie nach Erfassung mit dem JSON-Dokument. Zusätzlicher Rückgabekanal, kein Resultset.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. NULL, 0 oder 1. Der aktuelle Procedurekörper liest den Parameter nicht; er steuert keine PRINT-Ausgabe. Die Hilfeausgabe wird von @Hilfe gesteuert.

**@Hilfe:** @Hilfe bit; Default: 0. NULL, 0 oder 1. Nur 1 druckt Objektname, Snapshotgrenze, Opt-in-Hinweis und Kurzangaben zu Limit/Modi und kehrt vor Quellensammlung zurück. TABLE-Mapping wird davor vorbereitet.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler varchar(40)-OUTPUT-Empfang. Werte und Bedeutungen: AVAILABLE (kein gesetzter Finding-, Teil- oder Fehlerstatus), AVAILABLE_WITH_FINDING (Semaphore-Waiter oder Speicher-Finding, sofern der Status zuvor AVAILABLE war), AVAILABLE_LIMITED (optionale Clerk- oder Descriptorquelle fehlerhaft), INVALID_PARAMETER (negatives Zeilenlimit oder ungültiger Ausgabemodus), DENIED_PERMISSION (klassifizierter Berechtigungsfehler einer Kernquelle), ERROR_HANDLED (sonstiger abgefangener Kernquellenfehler). Zuweisung nach Sammlung und vor JSON/Resultsets. Optional zum Empfang mit @StatusCodeOut=@Empfaenger OUTPUT und einer varchar(40)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler bit-OUTPUT-Empfang. 1 kennzeichnet ungültige Parameter, klassifizierte Berechtigungsfehler oder sonstige Kernquellenfehler einschließlich ERROR_HANDLED sowie Fehler optionaler Clerk-/Descriptorquellen. Ein optionaler Quellfehler führt zu AVAILABLE_LIMITED. Im regulären Ablauf ohne Teilfehler gilt 0, auch bei AVAILABLE_WITH_FINDING. Das Bit ist kein allgemeiner Vollständigkeitsbeweis. Optional zum Empfang mit @IsPartialOut=@Empfaenger OUTPUT und einer bit-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT-Bindung int. Bei abgefangenem Fehler einer Kernquelle oder optionalen Quelle enthält sie die SQL-Fehlernummer; sonst NULL. Bei mehreren optionalen Fehlern bleibt die erste Nummer erhalten. Mit int-Variable und OUTPUT binden; Hilfe weist nicht zu. Optional zum Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT und einer int-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT-Bindung nvarchar(2048). Enthält abgefangene Kernquellenmeldung oder ersten optionalen Quellenhinweis; sonst NULL. Mit kompatibler Variable und OUTPUT binden; Hilfe weist nicht zu. Optional zum Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT und einer nvarchar(2048)-Variablen binden. Ein Anfangswert einschließlich NULL wird im normalen Pfad ersetzt; Hilfe lässt ihn unverändert und ein früher Preflight-THROW umgeht die reguläre Zuweisung.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| memory | 1 | 1 | [PhysicalMemoryInUseKb] bigint NULL , [LockedPageAllocationsKb] bigint NULL , [LargePageAllocationsKb] bigint NULL , [MemoryUtilizationPercent] int NULL , [AvailableCommitLimitKb] bigint NULL , [ProcessPhysicalMemoryLow] bit NULL , [ProcessVirtualMemoryLow] bit NULL , [TotalPhysicalMemoryKb] bigint NULL , [AvailablePhysicalMemoryKb] bigint NULL , [AvailablePhysicalMemoryPercent] decimal(9,2) NULL , [SystemMemoryStateDesc] nvarchar(256) NULL , [FindingCode] varchar(80) NOT NULL , [FindingSeverity] varchar(16) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_BufferPoolAnalysis] @MitMemoryClerks=1,@MitBufferPoolVerteilung=0,@MaxZeilen=50,@ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Basis LOW; Buffer-Pool-Verteilung kann auf großen Instanzen HIGH sein und ist deshalb standardmäßig deaktiviert.

Eine Momentaufnahme beweist keinen Trend und berechnet keine automatische max-server-memory-Empfehlung.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_BufferPoolAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Die Procedure liefert eine korrelierte Momentaufnahme von
               Prozess-, Betriebssystem- und Resource-Semaphore-Speicherwerten
               sowie optionalen Memory-Clerk- und Buffer-Pool-Verteilungen.
Datenquellen : sys.dm_os_process_memory, sys.dm_os_sys_memory,
               sys.dm_exec_query_resource_semaphores,
               sys.dm_os_memory_clerks und optional sys.dm_os_buffer_descriptors.
Kosten       : Basis LOW; Buffer-Pool-Verteilung kann auf großen Instanzen HIGH
               sein und ist deshalb standardmäßig deaktiviert.
Grenzen      : Eine Momentaufnahme beweist keinen Trend und berechnet keine
               automatische max-server-memory-Empfehlung.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_BufferPoolAnalysis
Sammelt Memory-/OS-Momentaufnahme und Resource Semaphores, ergänzt optional nach Clerktyp gruppierte Memory Clerks und aktiviert die nach Datenbanken gruppierte Buffer-Pool-Verteilung nur mit @MitBufferPoolVerteilung=1.
Der Descriptorpfad scannt sys.dm_os_buffer_descriptors vor Gruppierung; ein kleines MaxZeilen begrenzt nur ausgegebene Gruppen, nicht den Scan.
DECLARE @JsonOut nvarchar(max); EXEC [monitor].[USP_BufferPoolAnalysis] @MitMemoryClerks=1,@MitBufferPoolVerteilung=0,@JsonErzeugen=1,@Json=@JsonOut OUTPUT,@ResultSetArt='NONE'; SELECT @JsonOut AS [Json];
CREATE TABLE [#BufferPoolAnalysis_HelpExample]([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_BufferPoolAnalysis] @ResultSetArt='TABLE',@ResultTablesJson=N'{"memory":"#BufferPoolAnalysis_HelpExample"}'; SELECT * FROM [#BufferPoolAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#BufferPoolAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE IF EXISTS [#BufferPoolAnalysis_HelpExample];
```

