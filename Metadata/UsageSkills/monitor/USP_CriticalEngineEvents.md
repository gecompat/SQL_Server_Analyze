---
skill_format_version: "1.0.0"
name: "monitor.USP_CriticalEngineEvents"
schema_name: "monitor"
object_name: "USP_CriticalEngineEvents"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liest ausgewählte kritische Ereignisse aus vorhandenen XEL-Dateien der benannten Extended-Events-Session und optional einen einmaligen sys.sp_server_diagnostics-Snapshot."
source_path: "Code/08_ServerHealth/140_USP_CriticalEngineEvents.sql"
---

# monitor.USP_CriticalEngineEvents

## Zweck und Einsatz

Liest ausgewählte kritische Ereignisse aus vorhandenen XEL-Dateien der benannten Extended-Events-Session und optional einen einmaligen sys.sp_server_diagnostics-Snapshot.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CriticalEngineEvents]. Die Quelle nennt insbesondere `sys.sp_server_diagnostics`, `[monitor].[InternalPrepareSingleResultTable]`, `monitor.TVF_ParseSqlNameList`, `sys.fn_xe_file_target_read_file`, `[monitor].[TVF_ParseSqlNameList]`, `[sys].[server_event_sessions]`, `[sys].[server_event_session_targets]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SourceExtendedEventSessionName | nvarchar(258) | nein | N'system_health' |
| @FilePath | nvarchar(4000) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @BisUtc | datetime2(7) | nein | NULL |
| @MinErrorSeverity | tinyint | nein | 20 |
| @MitSystemHealth | bit | nein | 1 |
| @MitServerDiagnostics | bit | nein | 0 |
| @MitEventXml | bit | nein | 0 |
| @MaxZeilen | int | nein | 500 |
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

**@SourceExtendedEventSessionName:** @SourceExtendedEventSessionName nvarchar(258); Default: N'system_health'. Ein einzelner, einteiliger SQL-Name der Extended-Events-Session. monitor.TVF_ParseSqlNameList verarbeitet bracket-aware Pipe-Listen, äußerer Whitespace wird entfernt, ]] maskiert ], aber dieser Parameter akzeptiert genau einen gültigen Listeneintrag; multipart-Namen und Namen über 128 Zeichen sind ungültig. NULL, leere Eingabe, leere/fehlerhafte Elemente oder mehr als ein gültiger Name führen zu INVALID_PARAMETER. Der Default system_health wird durch die Procedure-Signatur gesetzt. Der Name wird für die Katalogsuche des event_file-Targets verwendet; die Procedure startet oder ändert die Session nicht.

**@FilePath:** @FilePath nvarchar(4000); Default: NULL. Optionaler serverseitiger Dateipfad oder XEL-Muster. NULL oder leerer String verwendet den im Katalog für die angegebene Session konfigurierten event_file-Dateinamen; der Eingabewert wird nicht mit LTRIM/RTRIM normalisiert. Ein Suffix .xel wird durch Basisname plus *.xel ersetzt (case-insensitiv); ohne * und ohne .xel wird *.xel angefügt; vorhandenes * bleibt erhalten. Ein expliziter Pfad ersetzt den konfigurierten Pfad und muss für den SQL-Server-Dienstprozess lesbar sein. Gelesen wird mit sys.fn_xe_file_target_read_file; kein Clientpfad und kein Ringbuffer-Fallback.

**@VonUtc:** @VonUtc datetime2(7); Default: NULL. datetime2(7)-Zeitpunkt in UTC als inklusiver Unterrand: Eventzeitstempel müssen >= VonUtc sein. NULL lässt die Untergrenze offen. Kein Zeitzonenoffset/keine Konvertierung; UTC liefert der Aufrufer. Wird unabhängig von BisUtc vor XML-Parsing angewandt.

**@BisUtc:** @BisUtc datetime2(7); Default: NULL. datetime2(7)-Zeitpunkt in UTC als exklusiver Oberrand: Eventzeitstempel müssen < BisUtc sein. NULL lässt die Obergrenze offen. Kein Zeitzonenoffset/keine Konvertierung; UTC liefert der Aufrufer. Wird unabhängig von VonUtc vor XML-Parsing angewandt. Sind beide gesetzt, muss VonUtc strikt kleiner sein.

**@MinErrorSeverity:** @MinErrorSeverity tinyint; Default: 20. Severity-Schwelle 0 bis 25; tinyint lässt keine negativen Eingaben zu, Werte >25 sind INVALID_PARAMETER. Betrifft nur error_reported und wird nach dem TOP-Kandidatenset angewandt. Fehlernummern 701, 802, 823, 824, 825, 832, 833, 8645, 8651 und 17803 passieren unabhängig von der Severity. NULL umgeht die >25-Prüfung; der Severityvergleich ergibt UNKNOWN, sodass normale error_reported-Einträge entfallen und nur die Nummernausnahmen verbleiben. Andere ausgewählte Eventnamen werden nicht nach Severity gefiltert.

**@MitSystemHealth:** @MitSystemHealth bit; Default: 1. Bit-Schalter: 1 liest das vorhandene event_file-Target der benannten Session; 0 überspringt die XEL-Quelle. Es werden ausschließlich error_reported, scheduler_monitor_non_yielding_ring_buffer_recorded, scheduler_monitor_non_yielding_iocp_ring_buffer_recorded, scheduler_monitor_stalled_dispatcher_ring_buffer_recorded, sp_server_diagnostics_component_result, memory_broker_ring_buffer_recorded, resource_monitor_ring_buffer_recorded, connectivity_ring_buffer_recorded und xml_deadlock_report berücksichtigt. NULL aktiviert die Quelle nicht und ist nicht eigenständig ungültig. Keine XE-Änderung; kein Ringbuffer-Fallback. Sind beide Quellflags explizit 0, ist die Eingabe INVALID_PARAMETER. Sind Flags NULL/0, kann der Validierungsvergleich UNKNOWN sein und beide Quellen überspringen, während der globale Status AVAILABLE bleibt.

**@MitServerDiagnostics:** @MitServerDiagnostics bit; Default: 0. Bit-Schalter: 1 führt sys.sp_server_diagnostics 0 einmalig ohne Repeat-Modus aus; 0 überspringt die Quelle. NULL aktiviert sie nicht und ist nicht eigenständig ungültig. Vollständige Daten können laut SourceStatus mindestens fünf Sekunden benötigen. Der Aufruf bildet einen separaten aktuellen Snapshot und ist kein XEL-Ereignis.

**@MitEventXml:** @MitEventXml bit; Default: 0. Bit-Schalter: 1 gibt das vollständige EventXml und Diagnostics-Data aus (einschließlich JSON); 0 oder NULL liefert diese XML-Ausgabefelder als NULL. Event-XML wird für extrahierte Felder und Filter auch ohne Opt-in gelesen und geparst; Diagnostics Data wird durch den One-Shot geliefert, aber nur mit Opt-in ausgegeben. Das Flag reduziert vollständigen XML-Transfer, nicht Parsing oder MessageText (nvarchar(4000)). MessageText/EventXml können sensible Runtimeinhalte enthalten; es gibt keine Persistenz.

**@MaxZeilen:** @MaxZeilen int; Default: 500. Nichtnegative int-Obergrenze. Werte <0 sind INVALID_PARAMETER. Werte 1..2147483647 begrenzen mit TOP das nach Zeit/Eventnamen gefilterte XEL-Kandidatenset, bevor XML extrahiert und Severity angewandt wird. 0 und NULL nutzen die größte bigint-TOP-Grenze. Sortiert wird nach Zeitstempel absteigend, Dateiname und Dateioffset absteigend. Das begrenzt weder das physische Lesen aller passenden Rolloverdateien noch ungefilterte Diagnostics-/SourceStatus-Zeilen; viele neuere Events können ältere relevante Fehler verdrängen.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach LTRIM/RTRIM und UPPER normalisierte Ausgabeart. RAW liefert Status und drei technische Resultsets: Events, Diagnostics, SourceStatus. CONSOLE wird intern NONE und danach über InternalEmitConsoleResult ausschließlich aus der Ereignistabelle gerendert; ein Status- oder Diagnostics-Resultset sowie der im Branch vorhandene CONSOLE-Formatierungszweig werden nicht ausgegeben. Leere Ereignisse erzeugen die Helper-Hinweiszeile. TABLE wird intern NONE und schreibt nur events in das lokale Ziel. NONE unterdrückt reguläre Resultsets. Zulässig: RAW, CONSOLE, TABLE, NONE; NULL/Leertext/andere Werte ergeben INVALID_PARAMETER. JSON kann unabhängig erstellt werden.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. TABLE-Aufrufe benötigen ein gültiges JSON-Objekt mit dem Schlüssel events und dem Wert eines bereits angelegten zulässigen lokalen #Temp-Ziels. Der Single-Result-Preflight läuft vor Hilfe und validiert Zuordnung und Ziel; NULL, leerer Text, ungültiges JSON oder fehlendes events-Mapping schlagen im TABLE-Modus fehl. Außerhalb TABLE ist NULL/leer zulässig; ein nichtleerer Wert löst wegen der Caller-Prüfung Fehler 51011 aus.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit: 0 unterdrückt JSON, 1 erstellt es; NULL aktiviert den IF-Zweig nicht. JSON-Gruppen: meta, events, serverDiagnostics, sources und warnings (leeres Array). Events und Diagnostics stammen aus denselben materialisierten Tabellen wie übrige Ausgaben; der Eventkandidatensatz ist bereits durch MaxZeilen begrenzt.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT nvarchar(max), beim Eintritt auf NULL gesetzt. Mit JsonErzeugen=1 wird später das JSON-Objekt meta/events/serverDiagnostics/sources/warnings zugewiesen, sonst bleibt NULL. Hilfe kehrt nach dem Reset zurück. EXEC mit nvarchar(max)-Empfängervariable und OUTPUT binden.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit: 0 unterdrückt Meldungen, 1 sendet bei globalem Status ungleich AVAILABLE eine Severity-10-RAISERROR-Meldung WITH NOWAIT. NULL aktiviert die IF nicht. Da Quellenfehler im SourceStatus protokolliert werden, während globale ErrorMessage NULL bleiben kann, meldet dieser Pfad dann den globalen Statuscode. JSON/Resultsets bleiben unabhängig.

**@Hilfe:** @Hilfe bit; Default: 0. Bit: 1 druckt Kurzinfos und kehrt vor Sessionparser, Quellenzugriff und Status-OUTPUT-Zuweisungen zurück; NULL/0 läuft regulär. @Json wurde beim Eintritt bereits auf NULL gesetzt. Ungültiges ResultTablesJson außerhalb TABLE sowie TABLE-Preflight werden vorher ausgeführt.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT varchar(40) mit globalem Status: INVALID_PARAMETER bei ungültiger Session/Zeit/Severity/Quell-/Ausgabeangabe; AVAILABLE_LIMITED bei markierter Teilquelle oder SourceStatus ungleich AVAILABLE; AVAILABLE_WITH_FINDING wenn Events vorhanden und keine Teilquelle gemeldet ist; sonst AVAILABLE. Per-source Codes: UNAVAILABLE_OBJECT bei fehlendem Dateipfad; AVAILABLE bei erfolgreicher Quelle; DENIED_PERMISSION für SQL-Fehler 229/262/297/300/371; XML_UNAVAILABLE_LIMIT für 6335/6336/6337; XML_INVALID für 9400..9431; ERROR_HANDLED für sonstige Quellfehler (Diagnostics nutzt DENIED_PERMISSION oder ERROR_HANDLED). Quellenfehler bleiben im SourceStatus und setzen nicht notwendigerweise globale ErrorNumber/ErrorMessage. Hilfe lässt den Empfänger unverändert. Mit @StatusCodeOut=@Variable OUTPUT binden.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT bit: 1 bei ungültigen Eingaben oder markierten/fehlgeschlagenen Teilquellen; sonst 0. 0 beweist nicht, dass system_health-Retention oder Eventauswahl vollständig ist. Teilquellenfehler führen global zu AVAILABLE_LIMITED. Hilfe lässt Empfänger unverändert; mit OUTPUT binden.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT int für einen global gesetzten Fehler; im Quellen-CATCH werden Fehlernummern stattdessen je Quelle in SourceStatus erfasst, daher kann dieser Empfänger NULL bleiben. Hilfe weist ihn nicht zu. Mit @ErrorNumberOut=@Variable OUTPUT binden.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT nvarchar(2048) für globale Validierungs-/Fehlermeldung. Fehlertexte einzelner XEL-/Diagnostics-Quellen stehen im SourceStatus und setzen diesen Wert nicht zwingend; dann bleibt er NULL. Hilfe weist ihn nicht zu. Mit @ErrorMessageOut=@Variable OUTPUT binden.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| events | 1 | 1 | [TimestampUtc] datetime2(7) NULL , [EventName] sysname NULL , [ErrorNumber] int NULL , [Severity] int NULL , [ComponentName] sysname NULL , [StateDesc] sysname NULL , [MessageText] nvarchar(4000) NULL , [FindingCode] varchar(100) NOT NULL , [EventXml] xml NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CriticalEngineEvents] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Keine XE- oder Serveränderung. Eventfiles werden nur gelesen. sp_server_diagnostics läuft ausschließlich als One-Shot.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CriticalEngineEvents
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Liest ausgewählte kritische Ereignisse aus vorhandenen
               XEL-Dateien der benannten Extended-Events-Session und optional
               einen einmaligen sys.sp_server_diagnostics-Snapshot.
Nebenwirkung : Keine XE- oder Serveränderung. Eventfiles werden nur gelesen.
               sp_server_diagnostics läuft ausschließlich als One-Shot.
Eigenlast    : Eventfile-Lesen MEDIUM. Positive @MaxZeilen-Werte begrenzen
               das gefilterte XEL-Kandidatenset vor XML-Extraktion und
               Severity-Auswertung, garantieren aber keine Begrenzung des
               physischen Dateilesens. XML-Transfer ist opt-in.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CriticalEngineEvents
Die Sessionangabe muss genau einen einteiligen SQL-Namen bezeichnen; die Procedure ändert keine XE-Session.
FilePath bezeichnet serverseitige XEL-Dateien; ohne Angabe wird das konfigurierte event_file-Target verwendet. Ringbuffer werden nicht gelesen.
UTC-Untergrenze inklusiv, Obergrenze exklusiv. Das Kandidatenlimit greift vor XML-Parsing und Severityfilter.
Severity filtert error_reported; ausgewählte Fehlernummern bleiben unabhängig von der Schwelle enthalten.
Server-Diagnostics läuft einmalig; vollständiges Event-XML ist Opt-in.
RAW liefert Status, Events, Diagnostics und SourceStatus; TABLE exportiert nur events.
DECLARE @ExampleFromUtc datetime2(7)=DATEADD(HOUR,-24,SYSUTCDATETIME()); EXEC [monitor].[USP_CriticalEngineEvents] @VonUtc=@ExampleFromUtc,@MaxZeilen=100,@ResultSetArt='RAW';
DECLARE @ExampleJson nvarchar(max)=NULL; EXEC [monitor].[USP_CriticalEngineEvents] @JsonErzeugen=1,@Json=@ExampleJson OUTPUT,@ResultSetArt='NONE'; SELECT @ExampleJson;
DECLARE @ExampleEventsMap nvarchar(max)=CONCAT(N'{',NCHAR(34),N'events',NCHAR(34),N':',NCHAR(34),N'#CriticalEngineEvents_HelpExample',NCHAR(34),N'}'); CREATE TABLE #CriticalEngineEvents_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_CriticalEngineEvents] @ResultSetArt='TABLE',@ResultTablesJson=@ExampleEventsMap; SELECT * FROM #CriticalEngineEvents_HelpExample; DROP TABLE #CriticalEngineEvents_HelpExample; END TRY BEGIN CATCH DROP TABLE IF EXISTS #CriticalEngineEvents_HelpExample; THROW; END CATCH;
```

