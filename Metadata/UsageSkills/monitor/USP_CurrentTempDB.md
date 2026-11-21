---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentTempDB"
schema_name: "monitor"
object_name: "USP_CurrentTempDB"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Zeigt aktuellen TempDB-Verbrauch je Session, optional Dateien und SQL-Server-2025-TempDB-Governance je Workload Group sowie den traditionellen und persistenten Version Store je Datenbank."
source_path: "Code/02_CurrentState/070_USP_CurrentTempDB.sql"
---

# monitor.USP_CurrentTempDB

## Zweck und Einsatz

Zeigt aktuellen TempDB-Verbrauch je Session, optional Dateien und SQL-Server-2025-TempDB-Governance je Workload Group sowie den traditionellen und persistenten Version Store je Datenbank.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer; Governance ab 2025 (17.x).

sys.dm_exec_sessions, tempdb.sys.dm_db_session_space_usage, tempdb.sys.database_files, Resource-Governor-Katalog/DMV und master.sys.master_files; im Parentpfad gemeinsame Materialisierung.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SessionIds | nvarchar(max) | nein | NULL |
| @AktuelleSessionEinbeziehen | bit | nein | 0 |
| @MinNettoMb | decimal(19,2) | nein | 0 |
| @SystemSessionsEinbeziehen | bit | nein | 0 |
| @MitDateien | bit | nein | 1 |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ParentCurrentStateSnapshotId | uniqueidentifier | nein | NULL |

**@SessionIds:** @SessionIds: Typ nvarchar(max); Default=NULL. NULL deaktiviert den ID-Filter. Sonst Liste von Ganzzahlen; 085 ersetzt zuerst Komma und Semikolon durch Pipe und zerlegt anschließend Pipe bracket-aware: Pipe innerhalb [...] bleibt Bestandteil; zuvor dort ersetzte Kommas/Semikolons bleiben daher als Pipe im Segment. ]] maskiert eine schließende Klammer. Äußere U+0020-Leerzeichen werden entfernt; Klammern werden nicht entquotet, daher ist [12] keine gültige ID. N'' ergibt EMPTY_LIST, nur Leerzeichen oder leere Segmente EMPTY_ITEM; Fehlerhafte oder nicht geschlossene Klammerstruktur ergibt INVALID_BRACKET_SYNTAX, Rohsegmente über 4000 UTF-16-Codeeinheiten ITEM_TOO_LONG. Diese Parserfehler, ungültige bigint-Zahlen, Werte außerhalb 0..32767 und Duplikate führen im normalen Pfad zu INVALID_PARAMETER und THROW 51011. Gültige IDs wählen Sessions; Filter wirken zusätzlich zu den Session-Schaltern. Ausgelassen entspricht NULL.

**@AktuelleSessionEinbeziehen:** @AktuelleSessionEinbeziehen: Typ bit; Default=0. 0 schließt @@SPID aus, 1 lässt die aufrufende Session zu; Session-ID- und Systemsessionfilter gelten zusätzlich. NULL ist INVALID_PARAMETER/THROW 51011. Numerische Eingaben werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1); nicht konvertierbare Eingaben scheitern bei SQL-Typkonvertierung. Ausgelassen=0.

**@MinNettoMb:** @MinNettoMb: Typ decimal(19,2); Default=0. Zahl in der ausgegebenen MB-Skalierung (Nettoseiten * 8 / 1024); Grenzwert für Netto-User-Object- plus Netto-Internal-Object-Seiten. 0 schließt Nullverbrauch ein; positive Werte verlangen mindestens diesen Verbrauch. Negative Werte lösen INVALID_PARAMETER und THROW 51011 aus. NULL wird nicht explizit abgelehnt, aber der Vergleich >= NULL lässt keine Sessionzeile passieren. Datentypbereich: -99999999999999999.99 bis 99999999999999999.99 mit zwei Nachkommastellen; negative Werte werden fachlich abgewiesen. Ausgelassen=0.

**@SystemSessionsEinbeziehen:** @SystemSessionsEinbeziehen: Typ bit; Default=0. 0 schließt anhand is_user_process bekannte interne/System-Sessions aus; 1 nimmt sie auf. Wirkt zusätzlich zu aktueller Session und @SessionIds. Bei fehlender Sessionidentität behandelt COALESCE(is_user_process,1) die Zeile wie eine User-Session. NULL ist INVALID_PARAMETER/THROW 51011. Numerisch 0→0, Nichtnull→1 vor Eintritt. Ausgelassen=0.

**@MitDateien:** @MitDateien: Typ bit; Default=1. 1 liest TempDB-Dateien frisch aus tempdb.sys.database_files einschließlich FILEPROPERTY(SpaceUsed) und gibt sie in RAW/CONSOLE sowie im JSON-Array tempdbFiles aus; 0 überspringt die Quelle, unterdrückt das Dateiresultset und lässt tempdbFiles als leeres Array erscheinen. TABLE kann Dateien nicht exportieren; es gibt keinen Datei-Key. Unabhängig von Parent-Snapshot und @MaxZeilen. NULL ist INVALID_PARAMETER/THROW 51011; numerisch 0→0, Nichtnull→1. Ausgelassen=1.

**@MaxZeilen:** @MaxZeilen: Typ int; Default=1000. Nichtnegative Ganzzahl; negative Werte lösen INVALID_PARAMETER/THROW 51011 aus, NULL oder 0 bedeutet unbegrenzt. Positive N begrenzt Sessions und Governance-Gruppen separat, nicht als Gesamtbudget. Sessions verwenden im Direkt- und Parentpfad höchstens N+1 Kandidaten für hasMoreRows, falls N<2147483647; bei int-Maximum ist keine N+1-Erhöhung möglich. Parent-Snapshotzeilen werden zuvor vollständig übernommen. Danach werden Sessions auf N begrenzt. Governance wird direkt vor Statusauswertung nach GroupId auf N vorselektiert; im Parentpfad erst nach Übernahme und Statusbewertung. Dateien, Version-Store-Zeilen und Warnings sind unbeschränkt. returnedRows/hasMoreRows beziehen sich nur auf Sessions. Ausgelassen=1000.

**@ResultSetArt:** @ResultSetArt: Typ varchar(16); Default=CONSOLE. Einzelner Modus; LTRIM/RTRIM entfernt Rand-U+0020-Leerzeichen, UPPER normalisiert Groß-/Kleinschreibung. Geschlossene Werte: CONSOLE gibt Sessions, optionale Dateien, Governance und Version Store lesbar aus; RAW gibt Statusmetadaten, Sessions, optionale Dateien, Governance, Version Store und Warnings als Resultsets aus; TABLE schreibt nur die benannten Mengen sessions, tempdbGovernance und versionStore in lokale Ziele; NONE unterdrückt Fachdaten-Resultsets, nicht angeforderte JSON-OUTPUT-Ausgabe. NULL/leer/Leerraum wird zu leerem Modus und löst INVALID_PARAMETER/THROW 51011 aus; andere Werte sind ungültig. Ausgelassen=CONSOLE.

**@ResultTablesJson:** @ResultTablesJson: Typ nvarchar(max); Default=NULL. Bei TABLE nichtleeres JSON-Objekt mit mindestens einem Key. Exakte case-sensitive Keys und Bedeutungen: sessions = Sessionverbrauchszeilen; tempdbGovernance = Workload-Group-Governance; versionStore = traditionelle und persistente Version-Store-Zeilen je Datenbank. Nichtleere Teilmenge zulässig; kein Datei-Key. Jeder Wert muss ein JSON-String mit Name einer vorhandenen lokalen #Temp-Tabelle sein. Ziele müssen leer und mit genau einer Seed-Spalte angelegt sein; Resultnamen und Ziele eindeutig. Keine ##-/permanenten Tabellen, Zielname höchstens 116 Zeichen, kein reserviertes #Monitor-Präfix (case-insensitive). Resultnamen werden binär/case-sensitiv verglichen, Zieldubletten case-insensitiv. Ungültige Form, Keys, Werte oder Ziele führen beim normalen TABLE-Preflight zu THROW 51011. Außerhalb TABLE sind NULL, leer oder nur U+0020 erlaubt; nichtleerer Wert ist INVALID_PARAMETER/THROW 51011. @Hilfe=1 umgeht Guard und Preflight; normal erfolgt der Preflight nach dem Parameter-Guard und vor Quellenzugriff.

**@JsonErzeugen:** @JsonErzeugen: Typ bit; Default=0. 0 deaktiviert JSON; 1 erzeugt zusätzlich zur ResultSetArt ein JSON-Dokument über @Json, auch bei NONE. Envelope enthält meta sowie sessions, tempdbFiles, tempdbGovernance, versionStore und warnings. Bei @MitDateien=0 ist tempdbFiles leer. NULL ist INVALID_PARAMETER/THROW 51011; numerisch 0→0, Nichtnull→1. Ausgelassen=0.

**@Json:** @Json: Typ nvarchar(max) OUTPUT; Default=NULL. Empfangsvariable gleichen Typs muss mit OUTPUT gebunden werden. Wird bei Procedure-Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 mit JSON befüllt, sonst bleibt NULL. Ohne OUTPUT-Bindung wird der Wert nicht empfangen. Ausgelassen=Default NULL.

**@PrintMeldungen:** @PrintMeldungen: Typ bit; Default=1. Bei 1 wird für Status ungleich AVAILABLE eine Severity-10-Warnmeldung mit Status und Fehlermeldung ausgegeben; 0 unterdrückt nur die Meldung, nicht Statusfelder, Resultsets oder JSON. NULL wird nicht geprüft und wirkt wegen IF=1 wie nicht aktiviert, also Meldung unterdrückt. Numerisch 0→0, Nichtnull→1 vor Eintritt. Ausgelassen=1.

**@Hilfe:** @Hilfe: Typ bit; Default=0. 1 druckt die Hilfe und kehrt vor Parameterprüfung, TABLE-Guard/-Preflight und Quellenzugriff zurück; normale Parameter und TABLE-Zuordnung werden dabei nicht validiert. 0 führt Diagnose aus. NULL wird nicht als Hilfe erkannt und führt in den normalen Pfad, ist nicht selbst ungültig. Numerisch 0→0, Nichtnull→1 vor Eintritt. Ausgelassen=0.

**@ParentCurrentStateSnapshotId:** @ParentCurrentStateSnapshotId: Typ uniqueidentifier; Default=NULL. NULL erhebt Sessions, Sessionzähler, traditionellen und persistenten Version Store sowie Governance direkt. Eine GUID übernimmt diese Daten aus dem aktuellen USP_CurrentOverview-Aufruf, wenn SnapshotId, OwnerSessionId=@@SPID und ContractVersion=2 passen. Fehlende Parent-Temp-Tabellen, fremde/abgelaufene ID oder falscher Aufrufkontext werden als INVALID_PARENT_SNAPSHOT mit partieller Status-/Warning-Ausgabe erfasst. Parentquellen werden nacheinander erhoben, nicht atomar; SourceStatus trägt Quellstatus, Partialität, Erfassungs-/Abschlusszeit, Zeilenzahl und Fehlerfelder. TempDB-Dateien sind keine Parent-Snapshotquelle und werden bei @MitDateien=1 immer frisch gelesen; Task-Space-Usage wird nicht ausgegeben. Ausgelassen=NULL.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| sessions | 1 | 1 | [SessionId] smallint NOT NULL , [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [UserObjectsAllocatedMb] decimal(19,2) NOT NULL , [UserObjectsDeallocatedMb] decimal(19,2) NOT NULL , [UserObjectsNetMb] decimal(19,2) NOT NULL , [InternalObjectsAllocatedMb] decimal(19,2) NOT NULL , [InternalObjectsDeallocatedMb] decimal(19,2) NOT NULL , [InternalObjectsNetMb] decimal(19,2) NOT NULL , [TotalNetMb] decimal(19,2) NOT NULL |
| tempdbGovernance | 1 | 1 | [GroupId] int NULL , [GroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [PoolId] int NULL , [PoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ConfiguredGroupMaxTempdbDataMb] decimal(19,2) NULL , [ConfiguredGroupMaxTempdbDataPercent] decimal(9,4) NULL , [TempdbMaximumSizeMb] decimal(19,2) NULL , [EffectiveGroupMaxTempdbDataMb] decimal(19,2) NULL , [EffectiveLimitSource] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPercentLimitEffective] bit NULL , [TempdbDataSpaceMb] decimal(19,2) NULL , [PeakTempdbDataSpaceMb] decimal(19,2) NULL , [EffectiveLimitUtilizationPercent] decimal(9,2) NULL , [TotalTempdbDataLimitViolationCount] bigint NULL , [HasRecordedLimitViolation] bit NULL , [StatisticsStartTime] datetime NULL , [IsResourceGovernorEnabled] bit NULL , [ReconfigurationPending] bit NULL , [SourceStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| versionStore | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [TraditionalVersionStoreReservedPages] bigint NULL , [TraditionalVersionStoreReservedMb] decimal(19,2) NULL , [PersistentVersionStoreSizeKb] bigint NULL , [OnlineIndexVersionStoreSizeKb] bigint NULL , [PersistentVersionStoreFilegroupId] smallint NULL , [CollectionTimeUtc] datetime2(3) NOT NULL , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentTempDB] @MitDateien=1, @MaxZeilen=100, @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentTempDB liest Sessionzustand und kumulative TempDB-Allokationszähler, optional TempDB-Dateien, Version-Store-Werte je Datenbank und Resource-Governor-TempDB-Grenzen je Workload Group. Quellen sind sys.dm_exec_sessions, tempdb.sys.dm_db_session_space_usage, tempdb.sys.database_files, tempdb.sys.dm_tran_version_store_space_usage, sys.dm_tran_persistent_version_store_stats, Resource-Governor-Kataloge/DMVs und bedingt master.sys.master_files.

Die Sicht ist nicht atomar: Sessionzähler gelten für die Lebensdauer der Session und werden nach abgeschlossenen Tasks aktualisiert; Quellen werden nacheinander gelesen. Für die vollständige serverweite DMV-Sicht braucht der Aufrufer EXECUTE auf diese Procedure und VIEW SERVER STATE auf SQL Server 2019 oder VIEW SERVER PERFORMANCE STATE ab SQL Server 2022; abgefangene Berechtigungsfehler erscheinen als DENIED_PERMISSION in Status oder Warnings, ohne volle Rechte kann die Sicht eingeschränkt sein. Die Procedure vergibt keine Rechte.

sessions zeigt Sessionidentität und netto User-/Internal-Object-MB; tempdbFiles zeigt Größe, Nutzung, freien Platz und Wachstum; tempdbGovernance zeigt konfigurierte/wirksame Limits, Nutzung, Peak und Verletzungen je Workload Group; versionStore zeigt traditionellen und persistenten Version Store je Datenbank; warnings trägt Quellenfehler.

SQL Server 2019/2022 liefern für tempdbGovernance den Quellenstatus UNAVAILABLE_VERSION, da TempDB Resource Governance erst ab SQL Server 2025 (17.x) verfügbar ist. Rechte- und Quellenfehler bleiben in Status/Warnings sichtbar; ein leeres Resultat beweist nicht, dass kein Verbrauch auftrat.

RAW enthält StatusCode, IsPartial, ErrorNumber und ErrorMessage. JSON besteht aus meta plus sessions, tempdbFiles, tempdbGovernance, versionStore und warnings; meta enthält statusCode, isPartial, Snapshot-ID, Zeit- und Mengenfelder, warnings enthält StatusCode/ErrorNumber/ErrorMessage. Ungültige Parameter oder TABLE-Zuordnungen führen vor den Ergebnisformen zu THROW 51011.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentTempDB
Version      : 4.1.0
Stand        : 2026-07-23
Zweck        : Zeigt aktuellen TempDB-Verbrauch je Session, optional Dateien
               und SQL-Server-2025-TempDB-Governance je Workload Group sowie
               den traditionellen und persistenten Version Store je Datenbank.
SQL-Version  : SQL Server 2019 oder neuer; Governance ab 2025 (17.x).
Datenquellen : sys.dm_exec_sessions, tempdb.sys.dm_db_session_space_usage,
               tempdb.sys.database_files, Resource-Governor-Katalog/DMV und
               master.sys.master_files; im Parentpfad gemeinsame Materialisierung.
Output       : sessions, tempdbFiles, tempdbGovernance, versionStore und warnings;
               RAW, CONSOLE, NONE, JSON und benannte TABLE-Ziele.
Locking      : LOCK_TIMEOUT 0 für Quellen; vorheriger Sessionwert wird
               auch nach TABLE- und CONSOLE-Ausgabe wiederhergestellt.
Datenschutz  : Laufzeitwerte werden nur ausgegeben, nicht persistiert.
Änderungen   : 4.1.0 - WI-0002 TempDB-ADR- und PVS-Diagnostik.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentTempDB liest Sessionzustand und kumulative TempDB-Allokationszähler, optional TempDB-Dateien, Version-Store-Werte je Datenbank und Resource-Governor-TempDB-Grenzen je Workload Group. Quellen sind sys.dm_exec_sessions, tempdb.sys.dm_db_session_space_usage, tempdb.sys.database_files, tempdb.sys.dm_tran_version_store_space_usage, sys.dm_tran_persistent_version_store_stats, Resource-Governor-Kataloge/DMVs und bedingt master.sys.master_files.
Die Sicht ist nicht atomar: Sessionzähler gelten für die Lebensdauer der Session und werden nach abgeschlossenen Tasks aktualisiert; Quellen werden nacheinander gelesen. Für die vollständige serverweite DMV-Sicht braucht der Aufrufer EXECUTE auf diese Procedure und VIEW SERVER STATE auf SQL Server 2019 oder VIEW SERVER PERFORMANCE STATE ab SQL Server 2022; abgefangene Berechtigungsfehler erscheinen als DENIED_PERMISSION in Status oder Warnings, ohne volle Rechte kann die Sicht eingeschränkt sein. Die Procedure vergibt keine Rechte.
sessions zeigt Sessionidentität und netto User-/Internal-Object-MB; tempdbFiles zeigt Größe, Nutzung, freien Platz und Wachstum; tempdbGovernance zeigt konfigurierte/wirksame Limits, Nutzung, Peak und Verletzungen je Workload Group; versionStore zeigt traditionellen und persistenten Version Store je Datenbank; warnings trägt Quellenfehler.
SQL Server 2019/2022 liefern für tempdbGovernance den Quellenstatus UNAVAILABLE_VERSION, da TempDB Resource Governance erst ab SQL Server 2025 (17.x) verfügbar ist. Rechte- und Quellenfehler bleiben in Status/Warnings sichtbar; ein leeres Resultat beweist nicht, dass kein Verbrauch auftrat.
RAW enthält StatusCode, IsPartial, ErrorNumber und ErrorMessage. JSON besteht aus meta plus sessions, tempdbFiles, tempdbGovernance, versionStore und warnings; meta enthält statusCode, isPartial, Snapshot-ID, Zeit- und Mengenfelder, warnings enthält StatusCode/ErrorNumber/ErrorMessage. Ungültige Parameter oder TABLE-Zuordnungen führen vor den Ergebnisformen zu THROW 51011.
Der übergreifende Status ist AVAILABLE oder AVAILABLE_LIMITED; abgefangene Fehler werden als DENIED_PERMISSION, TIMEOUT, INVALID_PARENT_SNAPSHOT oder ERROR_HANDLED gemeldet. tempdbGovernance kann UNAVAILABLE_VERSION ausweisen. INVALID_PARAMETER und ungültige TABLE-Zuordnungen werden mit THROW 51011 beendet, bevor Resultsets oder JSON zurückgegeben werden.
CREATE TABLE #CurrentTempDB_HelpExample (Placeholder int NULL); DECLARE @ResultTablesJson nvarchar(max)=N'{"sessions":"#CurrentTempDB_HelpExample"}'; EXEC [monitor].[USP_CurrentTempDB] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson; SELECT * FROM #CurrentTempDB_HelpExample; DROP TABLE #CurrentTempDB_HelpExample;
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_CurrentTempDB] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [JsonResult];
```

