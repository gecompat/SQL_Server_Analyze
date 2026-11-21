---
skill_format_version: "1.0.0"
name: "monitor.USP_ServerVersionInformation"
schema_name: "monitor"
object_name: "USP_ServerVersionInformation"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert Instanzversion, Offline-Buildbewertung, Lifecycle, Featureflags und optional sichtbaren Datenbank-Kompatibilitäts- kontext mit expliziter Provenienz und Evidenzgrenzen."
source_path: "Code/09_VersionAdaptive/015_USP_ServerVersionInformation.sql"
---

# monitor.USP_ServerVersionInformation

## Zweck und Einsatz

Liefert Instanzversion, Offline-Buildbewertung, Lifecycle, Featureflags und optional sichtbaren Datenbank-Kompatibilitäts- kontext mit expliziter Provenienz und Evidenzgrenzen.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_ServerVersionInformation] im vorgesehenen Datenbankkontext. Die Procedure liest Version-/Host-/OS-Metadaten sowie die Frameworktabellen `SqlServerBuildCatalog` und `SqlServerLifecycleCatalog`; Katalogstände sind Quellstand, kein Live-Supportnachweis.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MitDatenbankKompatibilitaet | bit | nein | 0 |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @MaxZeilen | int | nein | 2000 |
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

**@MitDatenbankKompatibilitaet:** @MitDatenbankKompatibilitaet (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. 1 aktiviert databaseCompatibility. 0 überspringt dessen Kandidatenpfad; dann müssen @DatabaseNames und @DatabaseNamePattern NULL bleiben, sonst INVALID_PARAMETER. NULL ist im normalen Pfad INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@DatabaseNames:** @DatabaseNames ist eine bracket-aware Pipe-Liste: | trennt außerhalb von [...], ]] maskiert ], Pipe innerhalb von [...] bleibt Bestandteil; nur einteilige SQL-Namen.

**@DatabaseNamePattern:** @DatabaseNamePattern (nvarchar(4000); Default: NULL; ausgelassen = Default): Ausgelassen = NULL. Nur bei aktivierter Compatibility-Ausgabe; alternativ zur Liste. Äußere Leerzeichen werden entfernt, Präfixe sind case-insensitiv: like: (SQL-LIKE), regex: (case-sensitive Regex, Flag c), regexi: (case-insensitive Regex, Flag i); ohne Präfix gilt SQL-LIKE. LIKE verwendet %, _ und SQL-Zeichenklassen [...] unter SQL_Latin1_General_CP1_CS_AS. Leerer Patterninhalt ist ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Bei deaktivierter Compatibility-Ausgabe muss der Wert NULL sein.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. Nur bei aktivierter Compatibility-Ausgabe bewirkt 0 den Ausschluss und 1 die Zulassung von master, tempdb, model und msdb. NULL ist auch bei deaktivierter Compatibility-Ausgabe im normalen Pfad INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@MaxZeilen:** @MaxZeilen begrenzt ausschließlich databaseCompatibility; ein negativer Wert wird auch ohne aktivierte Compatibility-Ausgabe abgelehnt.

**@ResultSetArt:** @ResultSetArt: CONSOLE=Build-/Lifecyclezusammenfassung, RAW=sieben Resultsets, TABLE=gemappte Resultsetziele, NONE=keine fachlichen Resultsets.

**@ResultTablesJson:** @ResultTablesJson wird bei TABLE als eindeutige Zuordnung dieser sieben Schlüssel zu vorhandenen leeren lokalen #Temp-Tabellen geprüft; ein leeres Einspalten-Dummyziel kann der Writer anpassen. Mapping-Preflight kommt nach dem Help-Return.

**@JsonErzeugen:** @JsonErzeugen (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. 1 erzeugt JSON unabhängig von ResultSetArt; 0 lässt JSON aus. NULL ist im normalen Pfad INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@Json:** @Json wird gleich beim Eintritt auf NULL gesetzt. Help lässt Status-/Fehler-OUTPUT-Werte unverändert und liegt vor Tabellenmapping.

**@PrintMeldungen:** @PrintMeldungen (bit; Default: 1; ausgelassen = Default): Ausgelassen = 1. 1 gibt normale Warnmeldungen bei Status ungleich AVAILABLE aus; 0 unterdrückt sie. NULL ist im normalen Pfad INVALID_PARAMETER. Hilfe-PRINT bleibt aktiv. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@Hilfe:** @Hilfe (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. Nur 1 druckt Hilfe und kehrt vor Bewertung, normaler Parameter-/Filtervalidierung und TABLE-Mapping-Preflight zurück; 0 und NULL führen normal weiter. @Json ist davor bereits NULL; die Status-/Fehler-OUTPUT-Werte bleiben beim Help-RETURN unverändert. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@StatusCodeOut:** @StatusCodeOut (varchar(40) OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Wird im normalen Abschluss mit dem tatsächlichen Modulstatus belegt. Die Procedure setzt unter anderem AVAILABLE, AVAILABLE_LIMITED und INVALID_PARAMETER; abgefangene Quellenfehler behalten ihren jeweiligen tatsächlichen Status. Beim Help-RETURN bleibt der übergebene Wert unverändert.

**@IsPartialOut:** @IsPartialOut (bit OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Liefert im normalen Abschluss 0 für vollständige bzw. 1 für partielle Ausgabe. Beim Help-RETURN bleibt der übergebene Wert unverändert.

**@ErrorNumberOut:** @ErrorNumberOut (int OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Liefert die tatsächlich abgefangene Fehlernummer oder NULL, wenn kein Fehler erfasst wurde. Beim Help-RETURN bleibt der übergebene Wert unverändert.

**@ErrorMessageOut:** @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Liefert den tatsächlich erfassten Fehlertext oder NULL, wenn kein Fehler erfasst wurde. Beim Help-RETURN bleibt der übergebene Wert unverändert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| serverVersion | 1 | 1 | [SourceType] varchar(32) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [EvidenceScope] varchar(40) NOT NULL , [IsCurrent] bit NOT NULL , [StatusCode] varchar(40) NOT NULL , [ProductVersion] varchar(32) NULL , [ProductMajorVersion] int NULL , [ProductMinorVersion] int NULL , [ProductBuild] int NULL , [ProductRevision] int NULL , [ProductLevel] nvarchar(128) NULL , [ProductUpdateLevel] nvarchar(128) NULL , [ProductUpdateReference] nvarchar(128) NULL , [ProductBuildType] nvarchar(128) NULL , [ResourceVersion] nvarchar(128) NULL , [ResourceLastUpdateDateTime] datetime NULL , [BuildClrVersion] nvarchar(128) NULL , [Edition] nvarchar(128) NULL , [EditionId] bigint NULL , [EngineEdition] int NULL , [EngineClass] varchar(40) NULL , [HostPlatform] nvarchar(256) NULL , [HostDistribution] nvarchar(256) NULL , [HostRelease] nvarchar(256) NULL , [HostServicePackLevel] nvarchar(256) NULL , [HostSku] int NULL , [OsLanguageVersion] int NULL , [SqlServerStartTimeUtc] datetime NULL , [UptimeMilliseconds] bigint NULL , [ProcessId] int NULL , [IsClustered] bit NULL , [IsHadrEnabled] bit NULL , [HadrManagerStatus] int NULL , [IsLocalDb] bit NULL , [ServerCollation] sysname NULL , [TempDbCollation] sysname NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| buildAssessment | 1 | 1 | [SourceType] varchar(32) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [EvidenceScope] varchar(40) NOT NULL , [AssessmentStatus] varchar(40) NOT NULL , [CatalogFreshnessStatus] varchar(40) NOT NULL , [ProductVersion] varchar(32) NULL , [KnownReleaseName] nvarchar(64) NULL , [ServicingBranch] varchar(16) NULL , [KnowledgeBaseNumber] varchar(16) NULL , [ReleaseDate] date NULL , [IsSecurityRelease] bit NULL , [LatestKnownBuildInBranch] varchar(32) NULL , [LatestKnownBuildForMajor] varchar(32) NULL , [CatalogAsOfDate] date NULL , [BuildOverviewUrl] nvarchar(512) NULL , [KnowledgeBaseUrl] nvarchar(512) NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| lifecycle | 1 | 1 | [SourceType] varchar(32) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [EvidenceScope] varchar(40) NOT NULL , [LifecycleStatus] varchar(40) NOT NULL , [ProductMajorVersion] int NULL , [ProductName] nvarchar(64) NULL , [StartDate] date NULL , [MainstreamEndDate] date NULL , [ExtendedEndDate] date NULL , [LifecyclePolicy] varchar(32) NULL , [CatalogAsOfDate] date NULL , [LifecycleUrl] nvarchar(512) NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| instanceFeatures | 1 | 1 | [SourceType] varchar(32) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [EvidenceScope] varchar(40) NOT NULL , [FeatureName] sysname NOT NULL , [FeatureValue] int NULL , [ValueStatus] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| databaseCompatibility | 1 | 1 | [SourceType] varchar(32) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [EvidenceScope] varchar(40) NOT NULL , [IsCurrent] bit NOT NULL , [StatusCode] varchar(40) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [CompatibilityLevel] tinyint NULL , [CollationName] sysname NULL , [StateDesc] nvarchar(60) NULL , [IsReadOnly] bit NULL , [IsSystemDatabase] bit NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| references | 1 | 1 | [ReferenceType] varchar(40) NOT NULL , [ProductMajorVersion] int NULL , [Title] nvarchar(256) NOT NULL , [Url] nvarchar(512) NOT NULL , [CatalogAsOfDate] date NOT NULL |
| warnings | 1 | 1 | [WarningOrdinal] bigint IDENTITY(1,1) NOT NULL , [SourceType] varchar(32) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ErrorNumber] int NULL , [Message] nvarchar(2048) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ServerVersionInformation] @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die Procedure ordnet aktuellen Build, offline mitgelieferten Servicing-Katalog und Lifecycle getrennt ein. Sie führt keinen Onlinezugriff aus.

CONSOLE verdichtet zu einer Zeile. Die sieben Resultsets heißen serverVersion, buildAssessment, lifecycle, instanceFeatures, databaseCompatibility, references und warnings. JSON verwendet gleichnamige Arrays unter meta.

databaseCompatibility ist opt-in. Bei @MitDatenbankKompatibilitaet=0 müssen @DatabaseNames und @DatabaseNamePattern NULL bleiben; der Systemdatenbankwert muss dennoch im normalen Aufruf nicht-NULL sein.

Der Offline-Katalog beweist weder vollständige Security-Patches, Verwundbarkeit, Neustartbedarf, Supportentitlement noch betriebliche Freigabe.

DECLARE @Status varchar(40), @Partial bit, @ErrNo int, @ErrMsg nvarchar(2048);


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ServerVersionInformation
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Stored Procedure
Zweck        : Liefert Instanzversion, Offline-Buildbewertung, Lifecycle,
               Featureflags und optional sichtbaren Datenbank-Kompatibilitäts-
               kontext mit expliziter Provenienz und Evidenzgrenzen.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : SERVERPROPERTY, sys.dm_os_sys_info, sys.dm_os_host_info,
               master.sys.databases sowie monitor.SqlServer*Catalog.
Eigenlast    : Gering; kein Plan-Cache-, Query-Store- oder Benutzerdatenzugriff.
Datenschutz  : Normale Ausgabe enthält keine Server-, Host-, Instanz-, Konto-
               oder Pfadidentität. Datenbanknamen erscheinen nur im explizit
               aktivierten Kompatibilitätsresultset.
Grenze       : Offline-Katalog; kein Vulnerability-, Neustart-, Lizenz- oder
               betrieblicher Freigabenachweis.
```

### Weitere bestehende Hilfehinweise

```text
Die Procedure ordnet aktuellen Build, offline mitgelieferten Servicing-Katalog und Lifecycle getrennt ein. Sie führt keinen Onlinezugriff aus.
CONSOLE verdichtet zu einer Zeile. Die sieben Resultsets heißen serverVersion, buildAssessment, lifecycle, instanceFeatures, databaseCompatibility, references und warnings. JSON verwendet gleichnamige Arrays unter meta.
databaseCompatibility ist opt-in. Bei @MitDatenbankKompatibilitaet=0 müssen @DatabaseNames und @DatabaseNamePattern NULL bleiben; der Systemdatenbankwert muss dennoch im normalen Aufruf nicht-NULL sein.
Der Offline-Katalog beweist weder vollständige Security-Patches, Verwundbarkeit, Neustartbedarf, Supportentitlement noch betriebliche Freigabe.
DECLARE @Status varchar(40), @Partial bit, @ErrNo int, @ErrMsg nvarchar(2048);
DECLARE @VersionJson nvarchar(max);
CREATE TABLE #ServerVersionInformation_HelpExample (Placeholder int NULL);
```

