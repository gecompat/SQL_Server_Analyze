---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStoreStatus"
schema_name: "monitor"
object_name: "USP_QueryStoreStatus"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Prüft den Query-Store-Zustand je ausgewählter Quelldatenbank."
source_path: "Code/05_QueryStore/010_USP_QueryStoreStatus.sql"
---

# monitor.USP_QueryStoreStatus

## Zweck und Einsatz

Prüft den Query-Store-Zustand je ausgewählter Quelldatenbank.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

monitor.TVF_DatabaseCandidates, monitor.TVF_ParseSqlNameList, monitor.TVF_ParsePattern, sys.database_query_store_options.

SQL 2019 VIEW DATABASE STATE; SQL 2022+ VIEW DATABASE PERFORMANCE STATE oder höher.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Im normalen Analysepfad: Bei Auslassung gilt NULL. NULL sowie N'', N' ' oder ausschließlich äußere U+0020-Leerzeichen bedeuten keine Namenseinschränkung; damit werden alle sichtbaren, zugreifbaren Online-Datenbanken im durch @SystemdatenbankenEinbeziehen bestimmten Scope gewählt, sofern kein Pattern gesetzt ist. Sonst eine bracket-aware Pipe-Liste eintragen: | trennt Elemente nur außerhalb von eckigen Klammern, ]] maskiert eine schließende Klammer; äußere Leerzeichen je Element werden entfernt. Vorgesehen ist ein einteiliger SQL-Name je Element; leere Elemente, ungültige Klammern und ungültige Namen sind INVALID_PARAMETER. Die Liste wird gegen sichtbare Datenbanknamen verglichen; die Parsefunktion ist keine allgemeine Bezeichnervalidierung und prüft weder Existenz noch Zugriff. Doppelte gültige Namen werden vom Auswahlhelfer abgelehnt (Vergleich mit SQL_Latin1_General_CP1_CS_AS). Eine wirksame nichtleere explizite Liste und ein nicht-NULL Pattern sind unzulässig zusammen. Eine nicht auffindbare/offline/nicht zugreifbare explizite Datenbank erzeugt eine Warnung; gültige übrige Treffer können als AVAILABLE_LIMITED ausgegeben werden. Ausgelassen gilt der deklarierte Default NULL. Die tatsächliche Namensprüfung verlangt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und höchstens 128 Zeichen für Teil 1. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Im normalen Analysepfad: Bei Auslassung gilt 0. 0 schließt Systemdatenbanken mit database_id 1 bis 4 aus; 1 bezieht diese ein. NULL ist INVALID_PARAMETER und wird nicht als 0 behandelt. Der Wert muss als bit 0 oder 1 gebunden werden. Leere Textwerte sind keine bit-Eingabeform. Bei @Hilfe=1 kehrt die Procedure vor dem Aufruf von 083 zurück; die NULL-Prüfung des normalen Auswahlpfads wird im Hilfezweig übersprungen. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. Im normalen Analysepfad: Bei Auslassung gilt NULL und es wird kein Pattern angewandt. NULL ist gültig; leerer Text oder ein nach äußerem LTRIM/RTRIM leerer Wert ist INVALID_PARAMETER. Alle erlaubten Präfixe werden ohne Beachtung der Groß-/Kleinschreibung erkannt: kein Präfix oder like: wählt SQL-LIKE-Modus (case-sensitive Vergleich); regex: wählt case-sensitive Regex (Flag c); regexi: wählt case-insensitive Regex (Flag i). Nach dem Präfix wird der Inhalt nicht erneut getrimmt und darf nicht leer sein. Regex wird nur auf SQL Server 2025 bei Compatibility Level 170 der Installationsdatenbank ausgeführt; diese Voraussetzung wird nicht je Quelldatenbank geprüft. Die Regex-Syntax wird vom Parser nicht vorab validiert. Das Pattern wirkt auf die Kandidatennamen im Frameworkhelfer und ist keine pro Quelldatenbank erneut ausgeführte Patternabfrage. Ein nicht-NULL Pattern und eine nichtleere explizite Namensliste sind gegenseitig exklusiv. Ausgelassen gilt der deklarierte Default NULL. LIKE verwendet %, _ und Zeichenklassen [...]. Präfix- und Eingabeformat sind Textwerte, zum Beispiel N'like:App%'; nach Präfixentfernung bleiben Inhalt und Groß-/Kleinschreibung erhalten.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Im normalen Auswahlpfad: Default: 0. Bei Auslassung gilt 0. 0 übergibt keine High-Impact-Bestätigung; 1 übergibt den gesetzten Bestätigungswert an InternalCheckAnalysisPath. NULL ist INVALID_PARAMETER und wird nicht als Default behandelt. QUERY_STORE_CURRENT ist in diesem Quellstand keine gruppengeschützte Analyseklasse (RequiresGroupGate=0); 1 löst in dieser Procedure keinen zusätzlichen Deep-Pfad aus und ist kein Nachweis, dass ein Gate erforderlich war oder passiert wurde. Leere Textwerte sind keine bit-Eingabeform. Bei @Hilfe=1 wird 083 nicht aufgerufen; diese normale Validierung wird dann übersprungen. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Im normalen Analysepfad: Bei Auslassung gilt CONSOLE. Der Eingabetext wird vor der Auswertung mit LTRIM/RTRIM und UPPER normalisiert (nach Bindung an varchar(16)); NULL wird zu leerem Text und ist INVALID_PARAMETER. Zulässig sind genau CONSOLE, RAW, TABLE und NONE, jeweils ohne Beachtung der Groß-/Kleinschreibung: CONSOLE ruft InternalEmitConsoleResult auf und liefert die fachliche Statusdatenmenge oder bei Leere einen formatierten Hinweis; RAW liefert drei Resultsets mit Modulmetadaten/-status, queryStoreStatus-Daten und Fehlern; TABLE schreibt ausschließlich das Resultset queryStoreStatus in das vorab gemappte Ziel; NONE unterdrückt Grid-Resultsets. JSON-Erzeugung ist unabhängig von dieser Auswahl. Andere Werte sind INVALID_PARAMETER. Ausgelassen gilt der deklarierte Default 'CONSOLE'. Maßgeblich ist der bereits an varchar(16) zugewiesene Wert; eine längere Textangabe kann davor auf die Typbreite gekürzt werden. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Bei Auslassung gilt NULL. Nur für TABLE ist eine nichtleere Zuordnung zulässig und dort zwingend erforderlich. Sie muss ein gültiges, nichtleeres JSON-Objekt mit genau einem Schlüssel queryStoreStatus und einem nichtleeren Stringwert sein, z. B. N'{"queryStoreStatus":"#QueryStoreStatusTarget"}'. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle sein, die genau eine beliebige Seed-Spalte hat; das vollständige Ergebnisschema wird nicht als Seed angelegt. Das Mapping wird vor HELP und vor fachlichen Quellenzugriffen validiert; Fehler werfen bei dieser Procedure. Bei CONSOLE, RAW oder NONE führt eine nicht-NULL, nicht nur aus äußerem LTRIM/RTRIM-Leerraum bestehende Zuordnung zu THROW 51011. NULL oder leerer/U+0020-Leerzeichen-Wert ist außerhalb TABLE zulässig, erfüllt aber die TABLE-Pflicht nicht. Ausgelassen gilt der deklarierte Default NULL. Schlüssel werden binär einschließlich Groß-/Kleinschreibung verglichen; doppelte Schlüssel sind ungültig. Zielnamen sind Strings mit LEN höchstens 116, beginnen mit #, aber nicht ## oder case-insensitiv #Monitor; doppelte Ziele werden case-insensitiv abgewiesen. Die einzelne Seed-Spalte hat einen beliebigen Namen und Typ; eine Seed-Zeile ist nicht zulässig.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Im normalen Analysepfad: Bei Auslassung gilt 0. 0 oder NULL erzeugt kein JSON; 1 erzeugt im @Json-OUTPUT-Parameter das JSON-Objekt mit meta, queryStoreStatus und warnings, unabhängig von @ResultSetArt. Der Parameter wird nur auf =1 geprüft; NULL wird daher wie ausgeschaltet behandelt und ist kein INVALID_PARAMETER. Als Eingabeform ist ein bit-Wert 0 oder 1 vorgesehen; leere Textwerte sind keine bit-Eingabeform. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Bei Auslassung gilt NULL und es gibt keinen Empfänger für den Output. Zur Übernahme ist eine nvarchar(max)-kompatible lokale Variable mit OUTPUT zu binden. Die Procedure setzt den Parameter am Anfang auf NULL; nur wenn @JsonErzeugen=1 wird anschließend das JSON mit meta, queryStoreStatus und warnings zugewiesen. Ohne JSON-Erzeugung bleibt der gebundene Output NULL. Ein nicht gebundener OUTPUT-Aufruf kann kein JSON zurückgeben. Ausgelassen gilt der deklarierte Default NULL. Der Eingabewert dient nicht als Steuerwert; bei Hilfe bleibt der intern zurückgesetzte Wert NULL. Bei vorzeitigem THROW ist kein übernommener OUTPUT zugesichert.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bei Auslassung gilt 1. 1 gibt die normalen Warn-/Statusmeldungen als RAISERROR severity 10 aus, wenn der jeweilige Fehler-/Warnpfad erreicht wird; 0 unterdrückt diese Meldungen. NULL wird nur auf =1 geprüft und unterdrückt daher ebenfalls. Der Schalter ändert weder gespeicherte Error-/Warning-Daten noch Resultsets oder JSON; der HELP-Zweig verwendet PRINT unabhängig davon. Als Eingabeform ist ein bit-Wert 0 oder 1 vorgesehen; leere Textwerte sind keine bit-Eingabeform. Ausgelassen gilt der deklarierte Default 1. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1.

**@Hilfe:** @Hilfe bit; Default: 0. Bei Auslassung gilt 0. 1 druckt die eingebaute Parameterhilfe und beendet die Procedure danach; 0 führt die Statusprüfung aus. NULL erfüllt die Prüfung =1 nicht und führt deshalb die normale Verarbeitung aus. Bei @Hilfe=1 findet keine TABLE-Mappingprüfung statt; im normalen Pfad kann sie mit Fehler abbrechen. Als Eingabeform ist ein bit-Wert 0 oder 1 vorgesehen; leere Textwerte sind keine bit-Eingabeform. Ausgelassen gilt der deklarierte Default 0. Als SQL-bit 0 oder 1 übergeben; vor dem Körper bleibt numerisch 0 gleich 0, ein von 0 verschiedener konvertierbarer Zahlenwert wird 1. Die normale Validierung von Ausgabemodus, Pattern, Namenslisten und Auswahlhelferparametern wird im Hilfezweig übersprungen; der Nicht-TABLE-Mappingguard und TABLE-Zielpreflight laufen nur im normalen Pfad.

## Resultate und Ausgabe

RAW, CONSOLE, TABLE oder NONE; optionales JSON mit meta, queryStoreStatus und warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| queryStoreStatus | 1 | 1 | [DatabaseId] int NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [DesiredState] smallint NULL , [DesiredStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ActualState] smallint NULL , [ActualStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ReadonlyReason] int NULL , [CurrentStorageSizeMb] bigint NULL , [MaxStorageSizeMb] bigint NULL , [StorageUsedPercent] decimal(9,2) NULL , [FlushIntervalSeconds] bigint NULL , [IntervalLengthMinutes] bigint NULL , [StaleQueryThresholdDays] bigint NULL , [MaxPlansPerQuery] bigint NULL , [QueryCaptureMode] smallint NULL , [QueryCaptureModeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SizeBasedCleanupMode] smallint NULL , [SizeBasedCleanupModeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [WaitStatsCaptureMode] smallint NULL , [WaitStatsCaptureModeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [CapturePolicyExecutionCount] int NULL , [CapturePolicyTotalCompileCpuTimeMs] bigint NULL , [CapturePolicyTotalExecutionCpuTimeMs] bigint NULL , [CapturePolicyStaleThresholdHours] int NULL , [IsEnabled] bit NULL , [IsWritable] bit NULL , [StatusHint] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStoreStatus] @Hilfe = 1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStoreStatus

Prüft den aktuellen Query-Store-Zustand je ausgewählter Datenbank.

Hilfe kehrt vor den ResultTablesJson-Prüfungen und der normalen Analyseparameter-Validierung zurück. Ungültige fachliche Filter, Ausgabewerte und Mappings werden im Hilfezweig nicht geprüft.

DECLARE @Json nvarchar(max) = NULL; EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT; SELECT @Json AS [JsonPayload];

CREATE TABLE [#QueryStoreStatusTarget] ([Seed] bit NULL); EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt = 'TABLE', @ResultTablesJson = N'{"queryStoreStatus":"#QueryStoreStatusTarget"}'; SELECT * FROM [#QueryStoreStatusTarget]; DROP TABLE [#QueryStoreStatusTarget];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStoreStatus
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Prüft den Query-Store-Zustand je ausgewählter Quelldatenbank.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : monitor.TVF_DatabaseCandidates,
               monitor.TVF_ParseSqlNameList, monitor.TVF_ParsePattern,
               sys.database_query_store_options.
Parameter    : @QueryStoreDatabaseNames, @SystemdatenbankenEinbeziehen,
               @QueryStoreDatabaseNamePattern,
               @ResultSetArt, @JsonErzeugen, @Json OUTPUT,
               @PrintMeldungen, @Hilfe.
Semantik     : @QueryStoreDatabaseNames ist eine bracket-aware Pipe-Liste.
               NULL, N'' und Leerzeichen bedeuten keine Einschränkung.
               Die Datenbankauswahl wird nicht vorab begrenzt.
Ausgabe      : RAW, CONSOLE, TABLE oder NONE; optionales JSON mit meta,
               queryStoreStatus und warnings.
Berechtigung : SQL 2019 VIEW DATABASE STATE; SQL 2022+
               VIEW DATABASE PERFORMANCE STATE oder höher.
Eigenlast    : Sehr gering; eine Statuszeile je Datenbank.
Locking      : LOCK_TIMEOUT 0; keine Änderungen.
Änderungen   : 2.0.0 - @AlleDatenbanken entfernt; Listen-/Patternvertrag,
                         case-insensitive Steuerwerte und JSON eingeführt.
               1.0.0 - Erstfassung Phase 4.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStoreStatus
Prüft den aktuellen Query-Store-Zustand je ausgewählter Datenbank.
Hilfe kehrt vor den ResultTablesJson-Prüfungen und der normalen Analyseparameter-Validierung zurück. Ungültige fachliche Filter, Ausgabewerte und Mappings werden im Hilfezweig nicht geprüft.
DECLARE @Json nvarchar(max) = NULL; EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @Json OUTPUT; SELECT @Json AS [JsonPayload];
CREATE TABLE [#QueryStoreStatusTarget] ([Seed] bit NULL); EXEC [monitor].[USP_QueryStoreStatus] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt = 'TABLE', @ResultTablesJson = N'{"queryStoreStatus":"#QueryStoreStatusTarget"}'; SELECT * FROM [#QueryStoreStatusTarget]; DROP TABLE [#QueryStoreStatusTarget];
```

