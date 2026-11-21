---
skill_format_version: "1.0.0"
name: "monitor.USP_QueryStoreReplicaAnalysis"
schema_name: "monitor"
object_name: "USP_QueryStoreReplicaAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Trennt Query-Store-Laufzeit-, Wait- und Plan-Forcing-Evidenz nach replica_group_id und ordnet beobachtete Rollen zu."
source_path: "Code/05_QueryStore/100_USP_QueryStoreReplicaAnalysis.sql"
---

# monitor.USP_QueryStoreReplicaAnalysis

## Zweck und Einsatz

Trennt Query-Store-Laufzeit-, Wait- und Plan-Forcing-Evidenz nach replica_group_id und ordnet beobachtete Rollen zu.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer; Replica-Kataloge ab SQL Server 2025.

sys.database_query_store_options, sys.query_store_replicas, sys.query_store_runtime_stats, sys.query_store_wait_stats, sys.query_store_plan_forcing_locations.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @QueryStoreDatabaseNames | nvarchar(max) | nein | NULL |
| @QueryStoreDatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @ReplicaGroupIds | nvarchar(max) | nein | NULL |
| @VonUtc | datetime2(7) | nein | NULL |
| @BisUtc | datetime2(7) | nein | NULL |
| @MaxZeilen | int | nein | 200 |
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

**@QueryStoreDatabaseNames:** @QueryStoreDatabaseNames nvarchar(max); Default: NULL. Ausgelassen/NULL, N'' oder nur äußere U+0020-Leerzeichen: keine Einschränkung. Sonst bracket-aware Pipe-Liste exakter einteiliger SQL-Datenbanknamen, zum Beispiel N'[ExampleDatabase]|[OtherDatabase]'; | trennt außerhalb von [...], ]] maskiert ]. Leere Elemente, ungültige Namen und Duplikate sind INVALID_PARAMETER. Eine effektive nichtleere Liste ist exklusiv mit dem nicht-NULL Quellpattern. Ohne Filter werden sichtbare geeignete Online-Benutzerdatenbanken gewählt; Systemdatenbanken bleiben ausgeschlossen.

**@QueryStoreDatabaseNamePattern:** @QueryStoreDatabaseNamePattern nvarchar(4000); Default: NULL. ausgelassen/NULL kein Filter. Äußeres Trimmen, dann like: bedeutet SQL-LIKE-Muster, regex: regulärer Ausdruck mit Flag c (case-sensitiv), regexi: regulärer Ausdruck mit Flag i (case-insensitiv); Präfixe ohne Beachtung der Großschreibung entfernen. Ohne Präfix gilt LIKE; Rest wird nicht erneut getrimmt. Leer oder leer nach Präfix ist ungültig; exklusiv mit @QueryStoreDatabaseNames. REGEX/REGEXI laufen in der Installationsdatenbank und benötigen SQL Server 2025 plus CL170 dort; Syntax wird nicht vorab validiert.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. Ausgelassen/0: keine High-Impact-Bestätigung. NULL ist im normalen Analysepfad INVALID_PARAMETER. Der Auswahlhelfer prüft QUERY_STORE_CURRENT, derzeit ohne Gruppengate; dieses Modul ruft QUERY_STORE_DEEP auch bei breitem Zeitfenster oder unbegrenztem Limit nicht auf. 1 verändert weder Scope noch Rechte und vergibt keine Gruppenmitgliedschaft.

**@ReplicaGroupIds:** @ReplicaGroupIds nvarchar(max); Default: NULL. Ausgelassen/NULL: kein Replica-Gruppenfilter. Sonst Textliste ganzer bigint-Werte von -9223372036854775808 bis 9223372036854775807; |, Beistrich und Strichpunkt dürfen gemischt werden, zum Beispiel N'1|2,3;2'. U+0020-Randleerzeichen werden entfernt. Duplikate sind erlaubt; EXISTS vervielfacht keine Zeilen. Kein zusätzlicher Positivitätsfilter: auch 0 und negative Werte werden exakt verglichen. Leerwert, leere Elemente, ungültige Klammerstruktur, Rohsegmente über 4000 UTF-16-Codeeinheiten und nicht zu bigint konvertierbare Werte machen den normalen Aufruf ungültig. Beistrich/Strichpunkt werden vor der bracket-aware Pipe-Zerlegung überall ersetzt; Klammern werden für die Zahlenkonvertierung nicht entfernt, deshalb keine Zahlen in eckigen Klammern übergeben. Filtert alle vier Fachmengen, nicht die Quelldatenbankauswahl.

**@VonUtc:** @VonUtc datetime2(7); Default: NULL. Ausgelassen/NULL: nach dem Hilfezweig eine Stunde vor dem effektiven @BisUtc. Als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T12:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Muss vor @BisUtc liegen, sonst INVALID_PARAMETER. Runtime und Waits berücksichtigen vollständige Intervalle mit end_time > @VonUtc und start_time < @BisUtc, ohne anteilige Kürzung. Replica-Katalog und Forcing-Locations bleiben zeitlich ungefiltert. Der Default DATEADD(HOUR,-1,@BisUtc) benötigt eine darstellbare Stunde vor dem Ende; bei einem zu frühen datetime2-Endwert (etwa 0001-01-01T00:00:00) kann die Berechnung vor der normalen Validierung ungefangen überlaufen.

**@BisUtc:** @BisUtc datetime2(7); Default: NULL. Ausgelassen/NULL: nach dem Hilfezweig SYSUTCDATETIME(); zugleich NULLer Beginn ergibt die letzte Stunde. Als datetime2(7)-Variable oder UTC-ISO-8601-Literal wie 2026-01-01T13:00:00.0000000 übergeben; keine Zeitzonenumrechnung. Muss nach @VonUtc liegen. Nur Runtime/Waits werden über vollständige überlappende Intervalle gefiltert, Replica-Katalog und Forcing-Locations nicht.

**@MaxZeilen:** @MaxZeilen int; Default: 200. Ausgelassen: 200. NULL/0: unbegrenzt. Positive ganze int-Werte bis 2147483647 begrenzen jede der vier Fachmengen getrennt: replicas nach DatabaseId/ReplicaGroupId/RoleType aufsteigend; runtimeByReplica nach TotalCpuMs und LastExecutionTimeUtc absteigend, danach DatabaseId/ReplicaGroupId; waitsByReplica nach TotalQueryWaitTimeMs und LastIntervalEndUtc absteigend, danach DatabaseId/ReplicaGroupId; forcingByReplica nach ForcingLocationCount absteigend, danach DatabaseId/ReplicaGroupId. moduleStatus, sourceStatus und warnings sind nicht begrenzt. Nur der Wait-Quellpfad materialisiert je Quelldatenbank höchstens N+1 bereits aggregierte Waitgruppen, bei int-Maximum N; die zugrunde liegenden Quellzeilen werden vor diesem TOP aggregiert; die anderen Fachmengen werden vollständig gesammelt und danach global gekürzt. Modulzähler zählen die Ausgabe, sourceStatus.ReturnedRowCount die Sammlung vor globaler Kürzung. Negative Werte ergeben INVALID_PARAMETER mit Partialität, vier leere Fachmengen und vier false-HasMore-Flags. Das Limit löst keinen Deep-Check aus. Sortties garantieren keine zusätzliche eindeutige Auswahl; TABLE/CONSOLE keine physische Reihenfolge.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Ausgelassen/0: kein Warten auf gesperrte Ressourcen beim Quellzugriff. Positive ganze Millisekunden von 1 bis 60000 setzen den Lock-Timeout für die Sammlung; andere nicht-NULL Werte sind INVALID_PARAMETER. Kein Gesamtzeitbudget. Nach regulärer Sammlung und behandelten Quellenfehlern wird der zuvor erfasste @@LOCK_TIMEOUT wiederhergestellt; ungefangene Fehler sind davon nicht pauschal abgedeckt. NULL wird durch NOT BETWEEN nicht explizit abgewiesen und nicht auf 0 normalisiert: der dynamische SET-Text wird NULL, also keine ausdrückliche Timeoutzuweisung. Für einen definierten Wert 0 bis 60000 übergeben.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Ausgelassen: CONSOLE. Nach U+0020-Trim/Großschreibung genau vier Optionen: CONSOLE zeigt nur den Modulstatus mit Ergebnislabel; RAW liefert sieben Resultsets in der Reihenfolge moduleStatus, replicas, runtimeByReplica, waitsByReplica, forcingByReplica, sourceStatus, warnings; TABLE schreibt nur die gemappte nichtleere Teilmenge dieser sieben; NONE unterdrückt normale Resultsets. JSON ist unabhängig. NULL, leer, nur Leerzeichen oder andere Werte sind im normalen Analysepfad INVALID_PARAMETER. Der an varchar(16) gebundene Wert ist maßgeblich. Hilfe kehrt vor dieser Validierung zurück.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Ausgelassen/NULL sowie leer/U+0020 sind außerhalb TABLE zulässig; anderer nichtleerer Inhalt ist dort INVALID_PARAMETER. Bei TABLE ist ein nichtleeres JSON-Objekt mit ein bis sieben binär exakten, eindeutigen Schlüsseln erforderlich: moduleStatus (Gesamtstatus/Zähler), replicas (beobachtete Rollen), runtimeByReplica (Runtimeaggregate), waitsByReplica (Waitaggregate), forcingByReplica (Forcing-Locations), sourceStatus (Quellenstatus/Zähler), warnings (Warnungen). Jeder Wert ist der Name einer eigenen vorhandenen, leeren lokalen #Temp-Tabelle mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, höchstens LEN 116 und kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel, case-insensitiv doppelte Ziele, Nicht-Stringwerte oder ungültige Ziele scheitern im ThrowOnError-Preflight vor Fachvalidierung, aber nach Hilfe. Der Writer ersetzt die Seed-Struktur durch das Ergebnisschema; nicht angeforderte Ziele bleiben unberührt. Gültige Zuordnungen erhalten auch bei ungültigen Fachparametern ihre Schemas und gegebenenfalls den Ablehnungsstatus.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. Ausgelassen/0: kein JSON, @Json bleibt NULL. 1 erzeugt unabhängig vom Ausgabemodus ein Objekt mit meta sowie den sieben Arrays moduleStatus, replicas, runtimeByReplica, waitsByReplica, forcingByReplica, sourceStatus und warnings. NULL ist im normalen Analysepfad INVALID_PARAMETER; es aktiviert JSON nicht.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter für das JSON-Dokument; beim Eintritt stets NULL, ein Eingabewert wird überschrieben. Zum Empfang eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Nur @JsonErzeugen=1 befüllt den Wert; bei Hilfe bleibt NULL. Ohne OUTPUT-Bindung wird kein Wert an den Aufrufer übernommen. Ein ungefangener THROW garantiert keine OUTPUT-Rückübertragung.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. Ausgelassen: 1. NULL ist im normalen Analysepfad INVALID_PARAMETER. Der aktuelle Modulkörper nutzt den Parameter nur für diese NULL-Prüfung; 0 und 1 verändern weder Warnungsdaten noch die Meldungsausgabe. Hilfe-PRINTs erfolgen unabhängig davon vor der Prüfung.

**@Hilfe:** @Hilfe bit; Default: 0. Ausgelassen/0 oder NULL: normaler Analysepfad. 1 druckt Hilfe und Beispiele und kehrt vor Zeitdefaults, TABLE-Zielprüfung, fachlicher Validierung und Sammlung zurück. SQL-Typbindung bleibt vorher erforderlich. Nur @Json wurde bereits NULL; die vier Status-/Fehler-OUTPUTs behalten im Hilfezweig ihre Eingabewerte. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT des abschließenden Modulstatus im normalen Ablauf; kein Eingabefilter. Zum Empfang varchar(40)-Variable mit OUTPUT binden. AVAILABLE: nutzbare Evidenz; AVAILABLE_LIMITED: partielle Sammlung/Zuordnung; NOT_APPLICABLE: keine Fachmenge bei sonst nutzbarer Prüfung; UNAVAILABLE_VERSION: Replica-Auswertung vor SQL Server 2025 nicht unterstützt; INVALID_PARAMETER: ungültiger Aufruf. Vorbereitungsfehler werden unverändert übernommen, insbesondere INTERNAL_ERROR (interner Helfer-/Tabellenfehler), UNAVAILABLE_FEATURE (nicht unterstützter Quellregex), sowie je Analyseklassenregel HIGH_IMPACT_CONFIRMATION_REQUIRED (fehlende Bestätigung) oder DENIED_GROUP (fehlende Gruppenfreigabe); die aktuell verwendete Klasse QUERY_STORE_CURRENT verlangt kein Gruppengate. Bei Hilfe bleibt der Eingabewert unverändert. Bei ungefangenem THROW keine zugesicherte Rückübertragung.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT des abschließenden Partialitätsbits, kein Eingabeschalter. Eine bit-Variable mit OUTPUT binden. Im normalen Ablauf 0: keine festgestellte Partialität, 1: unvollständige Sammlung/Zuordnung oder ungültige Fachparameter. Ein Limit allein setzt dieses Bit nicht. Bei Hilfe bleibt der Eingabewert einschließlich NULL unverändert; bei ungefangenem THROW keine zugesicherte Rückübertragung.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT der Modulfehlernummer, kein Eingabefilter. Eine int-Variable mit OUTPUT binden. Die interne Nummer wird NULL initialisiert und im aktuellen Modulkörper nicht gesetzt; Quellenfehlernummern stehen getrennt in sourceStatus/warnings und werden nicht automatisch übernommen. Bei Hilfe bleibt der Eingabewert unverändert; bei ungefangenem THROW keine zugesicherte Rückübertragung.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT des Modulfehlertexts, kein Eingabefilter. Eine nvarchar(2048)-Variable mit OUTPUT binden. Im normalen Ablauf NULL, sofern keine Modulvalidierung oder Datenbankvorbereitung einen Fehlertext setzt; Quellenmeldungen werden nicht automatisch als erste Fehlermeldung übernommen, sondern stehen in sourceStatus/warnings. Bei Hilfe bleibt der Eingabewert unverändert; bei ungefangenem THROW keine zugesicherte Rückübertragung.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ProductMajorVersion] int NULL , [CrossDatabaseRequested] bit NOT NULL , [DatabaseCount] int NOT NULL , [ReplicaRowCount] bigint NOT NULL , [RuntimeRowCount] bigint NOT NULL , [WaitRowCount] bigint NOT NULL , [ForcingRowCount] bigint NOT NULL , [HasMoreReplicaRows] bit NOT NULL , [HasMoreRuntimeRows] bit NOT NULL , [HasMoreWaitRows] bit NOT NULL , [HasMoreForcingRows] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| replicas | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CurrentQueryStoreStateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [CurrentConnectionRoleDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ReplicaGroupId] bigint NOT NULL , [RoleType] tinyint NULL , [RoleTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RoleClass] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ReplicaName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [IsPrimaryRole] bit NOT NULL , [IsSecondaryRole] bit NOT NULL , [IsNamedReplica] bit NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| runtimeByReplica | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CurrentConnectionRoleDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ReplicaGroupId] bigint NULL , [RoleType] tinyint NULL , [RoleTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RoleClass] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ReplicaName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [MappingStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RecordedRows] bigint NOT NULL , [QueryCount] bigint NOT NULL , [PlanCount] bigint NOT NULL , [ExecutionCount] bigint NOT NULL , [FirstExecutionTimeUtc] datetimeoffset NULL , [LastExecutionTimeUtc] datetimeoffset NULL , [TotalDurationMs] decimal(38,3) NULL , [TotalCpuMs] decimal(38,3) NULL , [TotalLogicalReads] decimal(38,3) NULL , [TotalLogicalWrites] decimal(38,3) NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| waitsByReplica | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CurrentConnectionRoleDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ReplicaGroupId] bigint NULL , [RoleType] tinyint NULL , [RoleTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RoleClass] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ReplicaName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [MappingStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ExecutionTypeDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [WaitCategory] tinyint NULL , [WaitCategoryDesc] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RecordedRows] bigint NOT NULL , [FirstIntervalStartUtc] datetimeoffset NULL , [LastIntervalEndUtc] datetimeoffset NULL , [TotalQueryWaitTimeMs] bigint NULL , [MaxQueryWaitTimeMs] bigint NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| forcingByReplica | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CurrentConnectionRoleDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ReplicaGroupId] bigint NULL , [RoleType] tinyint NULL , [RoleTypeDesc] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [RoleClass] varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ReplicaName] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [MappingStatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ForcingLocationCount] bigint NOT NULL , [ForcedQueryCount] bigint NOT NULL , [ForcedPlanCount] bigint NOT NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [SourceOrdinal] int NOT NULL , [DatabaseId] int NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [RequiredPermission] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| warnings | 1 | 1 | [WarningOrdinal] int NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ErrorNumber] int NULL , [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_QueryStoreReplicaAnalysis

Trennt gespeicherte Query-Store-Runtime-, Wait- und Forcing-Evidenz nach replica_group_id. Beobachtete Rollen sind historischer Kontext, keine aktuelle AG-Gesundheits- oder Synchronitätsaussage. Keine Querytexte, Hinttexte oder Plan-XML. Replica-Quellen werden erst ab SQL Server 2025 nach Objekt-/Spaltenprüfung gelesen.

DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];

CREATE TABLE [#QueryStoreReplicaAnalysis_HelpStatus]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#QueryStoreReplicaAnalysis_HelpStatus"}';
 SELECT * FROM [#QueryStoreReplicaAnalysis_HelpStatus];
 DROP TABLE IF EXISTS [#QueryStoreReplicaAnalysis_HelpStatus];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreReplicaAnalysis_HelpStatus];
 THROW;
END CATCH;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_QueryStoreReplicaAnalysis
Version      : 1.0.0
Stand        : 2026-07-27
Typ          : Stored Procedure
Zweck        : Trennt Query-Store-Laufzeit-, Wait- und Plan-Forcing-Evidenz
               nach replica_group_id und ordnet beobachtete Rollen zu.
SQL-Version  : SQL Server 2019 oder neuer; Replica-Kataloge ab SQL Server 2025.
Datenquellen : sys.database_query_store_options, sys.query_store_replicas,
               sys.query_store_runtime_stats, sys.query_store_wait_stats,
               sys.query_store_plan_forcing_locations.
Abgrenzung   : Keine Querytexte, Plan-XML, Hints, Identitäten oder Nutzdaten.
               Beobachtete Rollen sind historischer Query-Store-Kontext und
               keine aktuelle Verfügbarkeits-, Synchronitäts- oder Healthaussage.
Eigenlast    : LOW_MEDIUM. Jede unterstützte Quelle wird je Datenbank höchstens
               einmal gelesen; Zeitfenster, Datenbankscope und Zeilenlimit gelten.
Locking      : Konfigurierbarer LOCK_TIMEOUT; ursprünglicher Wert wird restauriert.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_QueryStoreReplicaAnalysis
Trennt gespeicherte Query-Store-Runtime-, Wait- und Forcing-Evidenz nach replica_group_id. Beobachtete Rollen sind historischer Kontext, keine aktuelle AG-Gesundheits- oder Synchronitätsaussage. Keine Querytexte, Hinttexte oder Plan-XML. Replica-Quellen werden erst ab SQL Server 2025 nach Objekt-/Spaltenprüfung gelesen.
DECLARE @ExampleJson nvarchar(max); EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ExampleJson OUTPUT; SELECT @ExampleJson AS [Json];
CREATE TABLE [#QueryStoreReplicaAnalysis_HelpStatus]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_QueryStoreReplicaAnalysis] @QueryStoreDatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#QueryStoreReplicaAnalysis_HelpStatus"}';
 SELECT * FROM [#QueryStoreReplicaAnalysis_HelpStatus];
 DROP TABLE IF EXISTS [#QueryStoreReplicaAnalysis_HelpStatus];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#QueryStoreReplicaAnalysis_HelpStatus];
 THROW;
END CATCH;
```

