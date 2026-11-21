---
skill_format_version: "1.0.0"
name: "monitor.USP_VectorIndexAnalysis"
schema_name: "monitor"
object_name: "USP_VectorIndexAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert sichtbare Vector-Indizes und korreliert deren aktuellen Hintergrundwartungszustand auf SQL Server 2025."
source_path: "Code/03_ObjectIndex/075_USP_VectorIndexAnalysis.sql"
---

# monitor.USP_VectorIndexAnalysis

## Zweck und Einsatz

Inventarisiert sichtbare Vector-Indizes und korreliert deren aktuellen Hintergrundwartungszustand auf SQL Server 2025.

## Voraussetzungen und Rechte

Installierbar ab SQL Server 2019. Vector-Quellen werden erst ab Product Major Version 17 nach Versions- und Schema-Prüfung dynamisch referenziert; ältere Versionen erhalten UNAVAILABLE_VERSION.

Je Zieldatenbank höchstens einmal sys.vector_indexes und sys.dm_db_vector_indexes; Katalog- und Runtimequelle erhalten getrennte Status.

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
| @StalenessReviewPercent | decimal(5,2) | nein | 15.00 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Optionaler einteiliger Datenbankname oder bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; Elemente außen getrimmt und case-sensitive. NULL, N'' oder nur Leerzeichen bedeutet keine exakte Auswahl und prüft alle zulässigen sichtbaren ONLINE-Benutzerdatenbanken. Nichtleere Liste ist mit nicht-NULL @DatabaseNamePattern exklusiv. Leere/ungültige Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten sind INVALID_PARAMETER; LEN höchstens 128.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 (Default) schließt master, model, msdb und tempdb aus; 1 lässt sie in die Auswahl zu. NULL INVALID_PARAMETER. Beim Binden an bit werden konvertierbare numerische Werte ungleich 0 auf 1 abgebildet.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Optionales Datenbankpattern; NULL kein Filter, leer/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest nicht erneut trimmen; ohne Präfix LIKE. LIKE nutzt %, _ und [...] case-sensitiv. regex: Flag c, regexi: Flag i; Syntax wird nicht vorgeprüft. Dieser Datenbankpatternpfad prüft Regex-Verfügbarkeit im Installationsdatenbankkontext (SQL Server 2025, Compatibility Level 170), sonst UNAVAILABLE_FEATURE. Nicht mit wirksamer nichtleerer Datenbankliste kombinieren.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. 0 (Default) bestätigt kein High-Impact-Gate; 1 bestätigt die Anforderung eines tatsächlich aktivierten Analysepfads. NULL INVALID_PARAMETER. Dieses Modul übergibt OBJECT_ANALYSIS_CURRENT an den Kandidatenhelfer. Bestätigung ersetzt weder Aktivierung/Freigabe noch die Prüfung, ob die Klasse ein Gruppengate verlangt. Bit-Bindung bildet konvertierbare numerische Nichtnullwerte auf 1 ab.

**@SchemaNames:** @SchemaNames nvarchar(max); Default: NULL. Optionale exakte einteilige Schemanamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; außen getrimmt und case-sensitive. NULL kein Filter; nicht-NULL leer/Whitespace, leere/ungültige Elemente, Duplikate, ungültiger PARSENAME-Name oder Rohsegment über 4000 UTF-16-Codeeinheiten ungültig. Teil 1 muss vorhanden, Teil 2 NULL und LEN höchstens 128 sein. Nicht mit nicht-NULL @SchemaNamePattern oder @FullObjectNames kombinieren.

**@SchemaNamePattern:** @SchemaNamePattern nvarchar(4000); Default: NULL. Optionales Schema-Pattern; NULL deaktiviert, leer/Whitespace oder leeres Präfix ungültig. Außen trimmen; Präfixe like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Regex läuft in der jeweiligen Zieldatenbank ohne separate Versions-/Kompatibilitätsvorprüfung; fehlende Funktion kann als datenbankweise isolierter ERROR_HANDLED-Fehler erscheinen. Nicht mit nicht-NULL @SchemaNames kombinieren.

**@ObjectNames:** @ObjectNames nvarchar(max); Default: NULL. Optionale exakte einteilige Objektnamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; außen getrimmt, case-sensitive. NULL kein Filter; nicht-NULL leere Liste, leere/ungültige Elemente, Duplikate, PARSENAME-Fehler oder Rohsegment über 4000 UTF-16-Codeeinheiten ungültig; LEN höchstens 128. Nicht mit nicht-NULL @ObjectNamePattern oder @FullObjectNames kombinieren.

**@ObjectNamePattern:** @ObjectNamePattern nvarchar(4000); Default: NULL. Optionales Objektpattern; NULL deaktiviert, leer/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; Präfixe like:, regex:, regexi: case-insensitiv erkannt; Rest nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Feldregex läuft in Zieldatenbank ohne eigene Versions-/Kompatibilitätsvorprüfung und kann je Datenbank als ERROR_HANDLED isoliert werden. Nicht mit nicht-NULL @ObjectNames kombinieren.

**@FullObjectNames:** @FullObjectNames nvarchar(max); Default: NULL. Optionale bracket-aware Pipe-Liste vollständiger Objektbezüge mit 1 bis 3 Teilen: Objekt, Schema.Objekt oder Datenbank.Schema.Objekt. | trennt außerhalb von [...], ]] maskiert ]; geparst mit PARSENAME, case-sensitive, Rohsegment bis 4000 UTF-16-Codeeinheiten und Bestandteile sysname-limitiert. Datenbankteil braucht Schema; vier Teile unzulässig. NULL kein Filter; nicht-NULL leere Liste ungültig. Nicht angegebene Datenbank-/Schemaanteile bleiben offen. Mit nicht-NULL @SchemaNames oder @ObjectNames exklusiv.

**@IndexNames:** @IndexNames nvarchar(max); Default: NULL. Optionale exakte einteilige Indexnamen als bracket-aware Pipe-Liste; | trennt außerhalb von [...], ]] maskiert ]; außen getrimmt und case-sensitive. NULL kein Filter; nicht-NULL leer/Whitespace, ungültige/leere Elemente, Duplikate oder ungültiger PARSENAME-/sysname-Wert INVALID_PARAMETER. Rohsegmente bis 4000 UTF-16-Codeeinheiten. Mit nicht-NULL @IndexNamePattern exklusiv.

**@IndexNamePattern:** @IndexNamePattern nvarchar(4000); Default: NULL. Optionales Indexpattern; NULL kein Filter, leer/Whitespace oder Präfix ohne Inhalt ungültig. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung; Rest danach nicht erneut trimmen; ohne Präfix LIKE. LIKE-Wildcards %, _ und [...] case-sensitiv; regex: c, regexi: i. Regex wird in Zieldatenbank ohne separate Versions-/Kompatibilitätsvorprüfung ausgeführt und kann datenbankweise isoliert fehlschlagen. Nicht mit nicht-NULL @IndexNames kombinieren.

**@StalenessReviewPercent:** @StalenessReviewPercent decimal(5,2); Default: 15.00. Optionaler Reviewgrenzwert in Prozent, 0 bis 100 einschließlich; NULL deaktiviert nur das VECTOR_STALENESS_REVIEW-Finding. Default 15.00: Finding bei verfügbarer ungefährer Staleness >= Grenzwert. Kein universeller Fehler-/Rebuildgrenzwert.

**@MaxZeilen:** @MaxZeilen int; Default: 2000. Nichtnegative int-Grenze; 0 oder NULL bedeutet unbegrenzt, negative Werte führen zu INVALID_PARAMETER. Nur in RAW und JSON begrenzt ein positiver Wert vectorIndexes, maintenance und findings jeweils separat; hasMore meldet weitere Zeilen. CONSOLE zeigt alle Findings, TABLE schreibt die vollständigen gemappten Quellen. Status-, Quellenstatus- und Warnmengen bleiben ungekürzt; Ermittlung und Korrelation werden dadurch nicht global begrenzt.

**@LockTimeoutMs:** @LockTimeoutMs int; Default: 0. Lockwartezeit in Millisekunden von 0 bis 60000 einschließlich; 0 bedeutet NOWAIT, außerhalb INVALID_PARAMETER. Im Analysepfad wird der Wert dynamisch gesetzt; vor der Ausgabe wird aus dem zuvor gespeicherten @@LOCK_TIMEOUT ein separater Wiederherstellungsbatch gebildet. NULL wird von der Bereichsprüfung nicht als ungültig erkannt; die spätere dynamische SET-LOCK_TIMEOUT-Textbildung wird durch den NULL-Wert NULL. Ein konkreter Ausführungsstatus dieses NULL-Batches wird hier nicht zugesichert.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach TRIM/UPPER genau CONSOLE, RAW, TABLE oder NONE; NULL/leer wird ungültig. CONSOLE zeigt eine menschenlesbare Findings-Ansicht. RAW liefert sechs getrennte Mengen: moduleStatus, vectorIndexes, maintenance, findings, sourceStatus, warnings. TABLE schreibt gemappte Namen; NONE unterdrückt reguläre Resultsets. JSON-OUTPUT unabhängig über @JsonErzeugen.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE ein JSON-Objekt Resultsetname→vorhandene lokale #Temp-Tabelle. TABLE erfordert gültiges nichtleeres Objekt mit ausschließlich moduleStatus, vectorIndexes, maintenance, findings, sourceStatus oder warnings. Ziele eindeutig, lokal, leer und mit genau einer Seed-Spalte; der Helper prüft und wirft bei Fehler. Außerhalb TABLE führt nichtleerer Inhalt zu INVALID_PARAMETER; NULL/leer dort zulässig.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 unterdrückt JSON-Erzeugung; 1 befüllt @Json mit Schema 1 und Schlüsseln meta, vectorIndexes, maintenance, findings, sourceStatus, warnings. NULL ist INVALID_PARAMETER. JSON-Facharrays folgen der jeweiligen @MaxZeilen-Grenze; hasMore… zeigt weitere Zeilen an.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler nvarchar(max)-OUTPUT-Empfänger, zu Beginn auf NULL gesetzt; mit @JsonErzeugen=1 enthält er das JSON-Dokument. Zum Empfang Variable des passenden Typs mit OUTPUT binden; ohne OUTPUT kommt Zuweisung nicht beim Aufrufer an. Hilfe kehrt nach dem NULL-Set zurück.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt Severity-10-Statusmeldung; 1 (Default) sendet sie bei Abschluss außer bei AVAILABLE, AVAILABLE_WITH_FINDING und NOT_APPLICABLE. NULL INVALID_PARAMETER. Meldung ergänzt Status-/Warnings-Ausgaben.

**@Hilfe:** @Hilfe bit; Default: 0. 1 druckt fünf Hilfezeilen und kehrt sofort vor Filter-, Ausgabe-, Datenbank- und Engineprüfungen sowie vor OUTPUT-Statuszuweisungen zurück. @Json ist zuvor bereits NULL. 0 normaler Ablauf; NULL wird nicht als 1 behandelt.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger varchar(40); erhält am regulären Ablaufende den finalen Modulstatus. Mit passender varchar(40)-Aufrufervariable samt OUTPUT binden; ohne OUTPUT erreicht die Zuweisung den Aufrufer nicht. Default NULL; bei frühem @Hilfe-Return unverändert. AVAILABLE bedeutet verfügbare Erhebung ohne Finding/Partialität; AVAILABLE_WITH_FINDING kennzeichnet mindestens ein WARN-Finding; AVAILABLE_LIMITED bedeutet partielle Erhebung; NOT_APPLICABLE: keine sichtbaren Vector-Indizes; UNAVAILABLE_VERSION: Product Major Version fehlt oder kleiner 17; UNAVAILABLE_FEATURE: keine verfügbare Vector-Quelle. Bei fehlendem erfolgreichem Katalogstatus kann zusätzlich der erste Katalogquellenstatus wie DENIED_PERMISSION, TIMEOUT, ERROR_HANDLED oder UNAVAILABLE_SOURCE_SCHEMA ausgegeben werden; ungültige Eingabe ergibt INVALID_PARAMETER. Quellenstatus bleibt separat in sourceStatus.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger bit; erhält am regulären Ablaufende den Partialitätsindikator. 1 kennzeichnet unvollständige/abgewiesene Erhebung; 0 eine nicht als partiell markierte Erhebung. Mit bit-Variable samt OUTPUT binden; ohne OUTPUT keine Rückgabe. Default NULL und bei frühem Hilfe-Return unverändert.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger int; erhält am normalen Ablaufende die gesetzte Fehlernummer oder NULL, wenn keine Fehlernummer für den Modulstatus gewählt wurde. Eine int-Variable mit OUTPUT bindet den Rückgabewert; ohne OUTPUT keine Rückgabe. Default NULL und bei Hilfe unverändert.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger nvarchar(2048); erhält am normalen Ablaufende die gewählte Fehler-/Warnmeldung oder NULL. Bei fehlendem expliziten Fehlertext wird die erste Warnmeldung gewählt. Eine nvarchar(2048)-Variable mit OUTPUT bindet den Rückgabewert; ohne OUTPUT keine Rückgabe. Default NULL und bei Hilfe unverändert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ProductMajorVersion] int NULL , [CrossDatabaseRequested] bit NOT NULL , [DatabaseCount] int NOT NULL , [VectorIndexRowCount] bigint NOT NULL , [MaintenanceRowCount] bigint NOT NULL , [FindingRowCount] bigint NOT NULL , [HasMoreVectorIndexRows] bit NOT NULL , [HasMoreMaintenanceRows] bit NOT NULL , [HasMoreFindingRows] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL |
| vectorIndexes | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [CompatibilityLevel] tinyint NULL , [PreviewFeaturesEnabled] bit NULL , [SchemaName] sysname NOT NULL , [ObjectId] int NOT NULL , [ObjectName] sysname NOT NULL , [IndexId] int NOT NULL , [IndexName] sysname NOT NULL , [VectorIndexType] varchar(20) NULL , [DistanceMetric] varchar(20) NULL , [IsDisabled] bit NOT NULL , [CatalogStatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL , PRIMARY KEY ([DatabaseId],[ObjectId],[IndexId]) |
| maintenance | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [SchemaName] sysname NOT NULL , [ObjectId] int NOT NULL , [ObjectName] sysname NOT NULL , [IndexId] int NOT NULL , [IndexName] sysname NOT NULL , [ApproximateStalenessPercent] decimal(10,2) NULL , [QuantizedKeysUsedPercent] decimal(10,2) NULL , [LastBackgroundTaskTime] datetime2(7) NULL , [LastBackgroundTaskSucceeded] bit NULL , [LastBackgroundTaskDurationSeconds] bigint NULL , [LastBackgroundTaskProcessedInserts] bigint NULL , [LastBackgroundTaskProcessedDeletes] bigint NULL , [LastBackgroundTaskErrorMessage] nvarchar(max) NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL , PRIMARY KEY ([DatabaseId],[ObjectId],[IndexId]) |
| findings | 1 | 1 | [FindingOrdinal] bigint IDENTITY(1,1) NOT NULL , [DatabaseName] sysname NULL , [SchemaName] sysname NULL , [ObjectName] sysname NULL , [IndexName] sysname NULL , [Severity] varchar(16) NOT NULL , [Confidence] varchar(16) NOT NULL , [FindingCode] varchar(120) NOT NULL , [MetricName] varchar(80) NOT NULL , [MetricValue] decimal(38,4) NULL , [ThresholdValue] decimal(38,4) NULL , [Evidence] nvarchar(1000) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL , [RecommendedNextCheck] nvarchar(1000) NOT NULL |
| sourceStatus | 1 | 1 | [SourceOrdinal] int IDENTITY(1,1) NOT NULL , [DatabaseId] int NULL , [DatabaseName] sysname NULL , [SourceName] sysname NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [RequiredPermission] nvarchar(256) NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| warnings | 1 | 1 | [WarningOrdinal] int IDENTITY(1,1) NOT NULL , [DatabaseName] sysname NULL , [SourceName] sysname NOT NULL , [StatusCode] varchar(40) NOT NULL , [ErrorNumber] int NULL , [Message] nvarchar(2048) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_VectorIndexAnalysis] @DatabaseNames=N'[ExampleDatabase]', @FullObjectNames=N'[ExampleSchema].[ExampleTable]', @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

LOW_TO_HIGH_OPT_IN. Scopefilter begrenzen Datenbanken/Objekte. @MaxZeilen begrenzt vectorIndexes, maintenance und findings jeweils separat nur in RAW und JSON. CONSOLE und TABLE erhalten die vollständigen jeweiligen Quellen; die vorgelagerte Ermittlung bleibt ungekürzt.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_VectorIndexAnalysis
Version      : 1.0.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Inventarisiert sichtbare Vector-Indizes und korreliert deren
               aktuellen Hintergrundwartungszustand auf SQL Server 2025.
SQL-Version  : Installierbar ab SQL Server 2019. Vector-Quellen werden erst ab Product Major Version 17 nach Versions- und Schema-Prüfung dynamisch referenziert; ältere Versionen erhalten UNAVAILABLE_VERSION.
Datenquellen : Je Zieldatenbank höchstens einmal sys.vector_indexes und sys.dm_db_vector_indexes; Katalog- und Runtimequelle erhalten getrennte Status.
Abgrenzung   : Keine Vector-Nutzdaten, keine internen build_parameters, keine DDL-, Rebuild-, Such- oder Wartungsaktion. Staleness ist flüchtige Reviewevidenz und kein alleiniger Rebuildnachweis.
Kosten       : LOW_TO_HIGH_OPT_IN. Scopefilter begrenzen Datenbanken/Objekte. @MaxZeilen begrenzt vectorIndexes, maintenance und findings jeweils separat nur in RAW und JSON. CONSOLE und TABLE erhalten die vollständigen jeweiligen Quellen; die vorgelagerte Ermittlung bleibt ungekürzt.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_VectorIndexAnalysis
Inventarisiert sichtbare Vector-Indizes und korreliert deren aktuelle Hintergrundwartung; keine Vector-Werte, Suche, DDL oder Wartung.
Vector-Systemquellen werden erst ab Product Major Version 17 nach Versions- und Schema-Prüfung dynamisch referenziert; ältere Engineversionen erhalten UNAVAILABLE_VERSION.
Katalog- und Runtimequelle besitzen getrennte Status. Wartungswerte sind flüchtige Evidenz und kein historischer Verlauf.
DECLARE @VectorIndexAnalysis_JsonExample nvarchar(max); EXEC [monitor].[USP_VectorIndexAnalysis] @DatabaseNames=N'[ExampleDatabase]', @JsonErzeugen=1, @Json=@VectorIndexAnalysis_JsonExample OUTPUT; SELECT @VectorIndexAnalysis_JsonExample AS [JsonDocument];
```

