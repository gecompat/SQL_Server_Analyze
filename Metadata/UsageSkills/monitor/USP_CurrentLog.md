---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentLog"
schema_name: "monitor"
object_name: "USP_CurrentLog"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert den aktuellen Transaktionslogzustand einer expliziten Datenbankliste oder aller zulässigen Datenbanken."
source_path: "Code/02_CurrentState/090_USP_CurrentLog.sql"
---

# monitor.USP_CurrentLog

## Zweck und Einsatz

Liefert den aktuellen Transaktionslogzustand einer expliziten Datenbankliste oder aller zulässigen Datenbanken. Fehler einer Datenbank brechen die übrigen Abfragen nicht ab.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

master.sys.databases, sys.dm_db_log_space_usage, sys.dm_db_log_stats, optional sys.dm_db_log_info, optional sys.dm_tran_persistent_version_store_stats.

Je Datenquelle VIEW SERVER STATE/VIEW SERVER PERFORMANCE STATE bzw. VIEW DATABASE PERFORMANCE STATE ab SQL Server 2022.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MinUsedPercent | decimal(5,2) | nein | NULL |
| @MitVlfInformationen | bit | nein | 0 |
| @MitPersistentVersionStore | bit | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames nvarchar(max), Default=NULL; bracket-aware Pipe-Liste exakter Datenbanknamen, z. B. N'[DbA]|[DbB]'; case-sensitive Vergleich, keine Duplikate. Ausgelassen/NULL/leer/nur Leerzeichen bedeutet keine Einschränkung innerhalb sichtbarer, zugreifbarer ONLINE Datenbanken; nicht verfügbare explizite Namen erzeugen Auswahlwarning. Exklusiv mit @DatabaseNamePattern. Das Zeichen | trennt nur außerhalb von [...]; in [...] bleibt | im Namen, und ]] maskiert ein inneres ].

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit, Default=0; Schalter 0 schließt master, tempdb, model, msdb aus; 1 erlaubt sie. Ausgelassen ergibt 0; NULL wird als INVALID_PARAMETER abgewiesen. Numerische Eingaben werden vor Procedure-Eintritt nach bit konvertiert; ungleich 0 wird 1.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000), Default=NULL; einzelnes nichtleeres Pattern, exklusiv mit exakter Liste. Kein Präfix oder like: = case-sensitive SQL-LIKE (%, _, []); regex: = case-sensitive Regex; regexi: = case-insensitive Regex. Präfix case-insensitive erkannt, äußere Leerzeichen entfernt; Inhalt unverändert. Ausgelassen/NULL deaktiviert; leer/Whitespace/Präfix ohne Muster ungültig. Regex benötigt SQL Server 2025 und Installationsdatenbank-Compatibility-Level 170.

**@HighImpactConfirmed:** @HighImpactConfirmed bit, Default=0; 0/ausgelassen bestätigt nicht, numerischer Wert ungleich 0 wird vor Eintritt zu 1. NULL führt bei Pfadprüfung zu INVALID_PARAMETER. Bestätigt angeforderten High-Impact-Pfad, erteilt aber keine Gruppenfreigabe: Auswahl prüft STANDARD_CURRENT; bei @MitVlfInformationen=1 zusätzlich LOG_VLF_DEEP; nur aktivierte, gruppengated Klassen verlangen beides.

**@MinUsedPercent:** @MinUsedPercent decimal(5,2), Default=NULL Prozent; Wertebereich 0.00..100.00. NULL/ausgelassen deaktiviert Filter; Wert filtert nach Erfassung darunterliegende UsedLogPercent-Zeilen. Bei aktivem Filter gilt NULL UsedLogPercent als -1 und wird auch bei Schwelle 0 entfernt; NULL heißt unbekannt, nicht 0.

**@MitVlfInformationen:** @MitVlfInformationen bit, Default=0; 1 fragt nach LOG_VLF_DEEP je Datenbank COUNT_BIG(*) aus dm_db_log_info ab und ergänzt TotalVlfCount nur, wenn dm_db_log_stats keinen Gesamtwert lieferte; 0 überspringt (VlfStatus SKIPPED). Ausgelassen ergibt 0; NULL deaktiviert Abfrage und ergibt SKIPPED. Nichtnull/numerische Konvertierung: jeder Wert ungleich 0 wird 1.

**@MitPersistentVersionStore:** @MitPersistentVersionStore bit, Default=0; 1 liest/aggregiert PVS-KB aus sys.dm_tran_persistent_version_store_stats für ausgewählte Datenbanken mit ADR; bei deaktiviertem ADR NOT_APPLICABLE. 0 überspringt (SKIPPED). Ausgelassen ergibt 0; NULL lässt PvsStatus PENDING und fragt nicht ab; numerischer Wert ungleich 0 wird vor Eintritt zu 1.

**@MaxZeilen:** @MaxZeilen int, Default=1000 Zeilen; ganze Zahl 0..2147483647. NULL oder 0 unbegrenzt; negativ INVALID_PARAMETER. Positiv begrenzt nach Sammlung/Prozentfilter sortiert auf UsedLogPercent DESC, DatabaseName, ohne Erfassungsarbeit einzuschränken. RAW und JSON sortieren; TABLE/CONSOLE haben keine Ordnungszusage.

**@ResultSetArt:** @ResultSetArt varchar(16), Default='CONSOLE'; nach Trim/UPPER taxativ RAW (Status, Logs, Teilquellenfehler), CONSOLE (Status, Logzeilen, Warnings), TABLE (logs-Temp-Export), NONE (keine fachlichen Resultsets). Ausgelassen ergibt CONSOLE; NULL/leer normalisiert zu '' und ist ungültig. Andere Werte INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max), Default=NULL; nur TABLE: JSON-Objekt mit exakt einem erlaubten Key logs (Logzeilen je Datenbank) und einem JSON-String als Zielname einer vorhandenen lokalen #Temp-Tabelle. Ziel muss leer und mit genau einer Seed-Spalte vorbereitet sein; Vorbereitung/Validierung erfolgt vor semantischer Parameterprüfung, ungültige Zuordnung wirft 51011. Andere Modi verlangen NULL/leer, sonst 51011. Ausgelassen/NULL oder leer ist nur außerhalb TABLE zulässig; TABLE benötigt die nichtleere Zuordnung mit Key logs.

**@JsonErzeugen:** @JsonErzeugen bit, Default=0; 1 erzeugt JSON-Envelope meta, logs, databaseStatus, warnings, unabhängig vom Resultsetmodus; 0 deaktiviert. Ausgelassen ergibt 0; NULL erzeugt keines. Jeder numerische Nichtnullwert ungleich 0 konvertiert zu 1.

**@Json:** @Json nvarchar(max) OUTPUT, Default=NULL; optionale Empfangsvariable nvarchar(max), beim EXEC mit OUTPUT binden. Beim Eintritt NULL, bei @JsonErzeugen=1 mit Envelope befüllt; ohne Erzeugung bleibt NULL. Auslassen, wenn nicht empfangen.

**@PrintMeldungen:** @PrintMeldungen bit, Default=1; 1 sendet bei Endstatus ungleich AVAILABLE Severity-10-Warnung mit NOWAIT; 0 unterdrückt Meldung. Ausgelassen ergibt 1; NULL unterdrückt Meldung. Ändert Resultsets/JSON nicht; numerischer Wert ungleich 0 wird zu 1.

**@Hilfe:** @Hilfe bit, Default=0; 1 gibt PRINT-Hilfe aus und kehrt vor fachlicher Verarbeitung zurück; 0/NULL führt normalen Pfad aus. Ausgelassen ergibt 0. Vor Eintritt konvertiert SQL Server numerische Werte ungleich 0 zu 1.

## Resultate und Ausgabe

RAW = stabiler technischer Vertrag; CONSOLE = formatierte Darstellung; NONE = kein Resultset. JSON enthält meta, logs, databaseStatus und warnings als benannte Arrays.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| logs | 1 | 1 | [DatabaseId] int NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RecoveryModel] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [LogReuseWaitDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [TotalLogSizeMb] decimal(19,2) NULL , [UsedLogSizeMb] decimal(19,2) NULL , [UsedLogPercent] decimal(19,4) NULL , [LogSinceLastBackupMb] decimal(19,2) NULL , [ActiveVlfCount] bigint NULL , [TotalVlfCount] bigint NULL , [LogTruncationHoldupReason] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [LogBackupTime] datetime NULL , [LogRecoverySizeMb] decimal(19,2) NULL , [IsAdrEnabled] bit NULL , [PersistentVersionStoreMb] decimal(19,2) NULL , [SpaceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatsStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [VlfStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [PvsStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentLog] @ResultSetArt = 'CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentLog – Hilfe; Ausgabe über PRINT und genau ein Skill-Resultset, ohne fachliche Abfragen.

Die Procedure zeigt den aktuellen Transaktionslogplatz, den Wiederverwendungsgrund und Logstatistiken je ausgewählter Datenbank. Optional ergänzt sie die VLF-Anzahl und die PVS-Größe. Sie liefert keine Verlaufs- oder Ursachenanalyse.

Quellen: master.sys.databases, sys.dm_db_log_space_usage und sys.dm_db_log_stats; optional sys.dm_db_log_info und sys.dm_tran_persistent_version_store_stats. SQL Server 2019 oder neuer.

Scope: sichtbare, zugreifbare, ONLINE befindliche Datenbanken. Ohne Einschränkung alle zulässigen Benutzerdatenbanken; Systemdatenbanken nur mit Opt-in. Die Kandidatenwahl hat keine Vorabbegrenzung.

Berechtigung: Sichtbarkeit, HAS_DBACCESS und die installierte Zugriffsrichtlinie begrenzen die Kandidaten. Für dm_db_log_space_usage und dm_db_log_stats gilt auf SQL Server 2019 VIEW SERVER STATE, ab 2022 VIEW SERVER PERFORMANCE STATE auf Serverebene. dm_db_log_info verlangt ab 2022 VIEW DATABASE PERFORMANCE STATE in der Quelldatenbank. PVS-Rechte sind separat versionsbezogen zu prüfen; requiredPermission ist ein Hinweis und keine Zusage, dass damit jede Teilquelle zugänglich ist. Quellfehler und Timeout 1222 werden erfasst, soweit deren TRY/CATCH greift.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentLog
Version      : 2.0.0
Stand        : 2026-07-15
Typ          : Stored Procedure
Zweck        : Liefert den aktuellen Transaktionslogzustand einer expliziten
               Datenbankliste oder aller zulässigen Datenbanken. Fehler einer
               Datenbank brechen die übrigen Abfragen nicht ab.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : master.sys.databases, sys.dm_db_log_space_usage,
               sys.dm_db_log_stats, optional sys.dm_db_log_info,
               optional sys.dm_tran_persistent_version_store_stats.
Parameter    : @DatabaseNames, @DatabaseNamePattern,
               @SystemdatenbankenEinbeziehen, @MinUsedPercent,
               @MitVlfInformationen, @MitPersistentVersionStore,
               @MaxZeilen, @ResultSetArt,
               @JsonErzeugen, @Json OUTPUT, @PrintMeldungen, @Hilfe.
Semantik     : @DatabaseNames enthält eine bracket-aware Pipe-Liste exakter
               Namen. NULL, N'' und Leerzeichen bedeuten alle zulässigen
               Datenbanken. Exakte Liste und Pattern sind exklusiv.
Ausgabe      : RAW = stabiler technischer Vertrag; CONSOLE = formatierte
               Darstellung; NONE = kein Resultset. JSON enthält meta, logs,
               databaseStatus und warnings als benannte Arrays.
Berechtigung : Je Datenquelle VIEW SERVER STATE/VIEW SERVER PERFORMANCE STATE
               bzw. VIEW DATABASE PERFORMANCE STATE ab SQL Server 2022.
Gruppengate  : Datenbankauswahl über STANDARD_CURRENT; VLF über LOG_VLF_DEEP.
Eigenlast    : Standard moderat; automatische Datenbankauswahl ist durch
               keine Datenbank-Vorabbegrenzung.
Locking      : Datenbankliste READUNCOMMITTED; System-DMVs je Datenbank.
Beispiele    : EXEC [monitor].[USP_CurrentLog]
                    @DatabaseNames=N'[DeineDatenbank]|[BeispielDatenbankB]';
               EXEC [monitor].[USP_CurrentLog]
                    @DatabaseNames=NULL,@DatabaseNamePattern=N'like:Database_%';
               DECLARE @J nvarchar(max);
               EXEC [monitor].[USP_CurrentLog] @DatabaseNames=N'[DeineDatenbank]',
                    @ResultSetArt='none',@JsonErzeugen=1,@Json=@J OUTPUT;
               SELECT @J AS [Json];
Änderungen   : 2.0.0 - @AlleDatenbanken entfernt; Listen-/Patternvertrag,
                         RAW/CONSOLE/NONE und JSON-Envelope eingeführt.
               1.0.0 - Erstfassung Phase 1B.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentLog – Hilfe; Ausgabe über PRINT und genau ein Skill-Resultset, ohne fachliche Abfragen.
Die Procedure zeigt den aktuellen Transaktionslogplatz, den Wiederverwendungsgrund und Logstatistiken je ausgewählter Datenbank. Optional ergänzt sie die VLF-Anzahl und die PVS-Größe. Sie liefert keine Verlaufs- oder Ursachenanalyse.
Quellen: master.sys.databases, sys.dm_db_log_space_usage und sys.dm_db_log_stats; optional sys.dm_db_log_info und sys.dm_tran_persistent_version_store_stats. SQL Server 2019 oder neuer.
Scope: sichtbare, zugreifbare, ONLINE befindliche Datenbanken. Ohne Einschränkung alle zulässigen Benutzerdatenbanken; Systemdatenbanken nur mit Opt-in. Die Kandidatenwahl hat keine Vorabbegrenzung.
Berechtigung: Sichtbarkeit, HAS_DBACCESS und die installierte Zugriffsrichtlinie begrenzen die Kandidaten. Für dm_db_log_space_usage und dm_db_log_stats gilt auf SQL Server 2019 VIEW SERVER STATE, ab 2022 VIEW SERVER PERFORMANCE STATE auf Serverebene. dm_db_log_info verlangt ab 2022 VIEW DATABASE PERFORMANCE STATE in der Quelldatenbank. PVS-Rechte sind separat versionsbezogen zu prüfen; requiredPermission ist ein Hinweis und keine Zusage, dass damit jede Teilquelle zugänglich ist. Quellfehler und Timeout 1222 werden erfasst, soweit deren TRY/CATCH greift.
Werte und Partialität: SpaceStatus, StatsStatus, VlfStatus und PvsStatus zeigen Teilquellenstatus. NULL ist kein gemessener Nullwert. Datenbankfehler brechen andere Datenbanken nicht ab; Fehler oder Auswahlwarnings ergeben PARTIAL_RESULT bei verbleibenden Zeilen, sonst ERROR_HANDLED. Frühe Auswahl-/Parameterfehler behalten ihren Fehlerstatus. JSON meta enthält statusCode, isPartial, requestedMaxRows, returnedRows, resultLimited/hasMoreRows, requiredPermission, errorNumber/errorMessage und detail; databaseStatus enthält Teilquellenfehler, warnings die Auswahlwarnings. Die Meta-Fehlerfelder können bei abgefangenen Datenbankfehlern NULL sein; deren konkrete Details stehen dann in databaseStatus.
Beispiel CONSOLE (kopierbarer Aufruf; Standard-Scope):
Beispiel TABLE (PRINT-Zeilen separat kopieren und in derselben Session ausführen):
CREATE TABLE #CurrentLog_HelpExample (Seed int NULL);
Beispiel JSON (kopierbarer Batch; Standard-Scope):
DECLARE @CurrentLogJson nvarchar(max);
```

