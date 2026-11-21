---
skill_format_version: "1.0.0"
name: "snapshot.InternalCompleteFileIOCycle"
schema_name: "snapshot"
object_name: "InternalCompleteFileIOCycle"
object_type: "INTERNAL_PROCEDURE"
database_role: "snapshot_target"
is_internal: true
description: "Die Procedure bindet Datei-I/O-Rohwerte und Vergleichskontexte atomar an einen vorbereiteten eigenen Lauf."
source_path: "Code/10_SnapshotBaseline/057_InternalCompleteFileIOCycle.sql"
---

# snapshot.InternalCompleteFileIOCycle

## Zweck und Einsatz

Die Procedure bindet Datei-I/O-Rohwerte und Vergleichskontexte atomar an einen vorbereiteten eigenen Lauf.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalCompleteFileIOCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `master.sys.databases`, `sys.databases`, `sys.database_files`, `sys.dm_os_sys_info`, `sys.dm_io_virtual_file_stats`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[snapshot].[InternalPurgeExpiredData]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @CaptureRunId | bigint | ja | kein Default |
| @CollectorJson | nvarchar(max) | ja | kein Default |
| @ExpectedTargetDatabaseId | int | ja | kein Default |
| @ExpectedTargetDatabaseName | sysname | ja | kein Default |
| @ExpectedTargetCreateDate | datetime | ja | kein Default |
| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |
| @IsPartialOut | bit OUTPUT | ja | kein Default |
| @ErrorNumberOut | int OUTPUT | ja | kein Default |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |
| @Hilfe | bit | nein | 0 |

**@CaptureRunId:** | @CaptureRunId | bigint; > 0; ID des unbeschriebenen eigenen FILE_IO-Laufs mit Status RUNNING. NULL/0/negativ ergibt INVALID_PARAMETER / 51011; Default: kein Default |

**@CollectorJson:** | @CollectorJson | nvarchar(max); vollständiges JSON-Objekt gemäß Schema. NULL, Leertext und ungültiges JSON werden erst nach bestätigtem eigenem Lauf als ERROR_HANDLED / 53782 behandelt, nicht als globales INVALID_PARAMETER; Default: kein Default |

**@ExpectedTargetDatabaseId:** | @ExpectedTargetDatabaseId | int; einzelner typisierter Wert > 4 für die aktuelle, online befindliche, beschreibbare Zieldatenbank. NULL oder abweichende Identität ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |

**@ExpectedTargetDatabaseName:** | @ExpectedTargetDatabaseName | sysname; einzelner roher Datenbankname bis 128 UTF-16-Codeeinheiten. Vergleich mit dem aktuellen Katalognamen ist binär, ohne Trimmen oder Schreibweisenausgleich. NULL oder ein fehlender exakter Match ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |

**@ExpectedTargetCreateDate:** | @ExpectedTargetCreateDate | datetime; einzelner typisierter Erstellungszeitpunkt aus master.sys.databases.create_date für das aktuelle Target. NULL oder Abweichung ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |

**@StatusCodeOut:** | @StatusCodeOut | varchar(40) OUTPUT; initial AVAILABLE. AVAILABLE: ausschließlich Initialwert, kein Abschlussnachweis; INVALID_PARAMETER: frühe Eingabe oder Lauf ungültig; TARGET_UNAVAILABLE: Target nicht verfügbar; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: durchgereichter Source-Status für ein nicht verfügbares Objekt; ERROR_HANDLED: behandelter Fehler; ein nachträglicher Fehlerabschluss ist nicht generell garantiert; PARTIAL: bestätigter regulärer Sourceabschluss unter den beschriebenen Evidenzgrenzen; FINALIZATION_UNCONFIRMED: Finalisierung unbestätigt; Default: kein Default | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@IsPartialOut:** | @IsPartialOut | bit OUTPUT; initial 0; Fehler-, PARTIAL- und FINALIZATION_UNCONFIRMED-Pfade setzen 1; Default: kein Default | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** | @ErrorNumberOut | Der erforderliche Parameter @ErrorNumberOut ist int OUTPUT ohne Default. Er wird beim Eintritt zunächst auf NULL gesetzt. NULL, ein typisierter int-Wert oder ein ohne OUTPUT-Bindung übergebener Wert sind zulässige Argumentformen; die SQL-Typkonvertierung erfolgt vor Eintritt. Zum Erfassen muss eine int-Variable mit OUTPUT gebunden werden. Das Argument darf nicht ausgelassen werden. Bei frühen Eingabefehlern wird 51011 ausgegeben, bei der frühen Prüfung einer nicht bestätigten erwarteten Targetidentität 53764. Andere vor SourceValidated abgefangene Fehler geben grundsätzlich die tatsächliche SQL-Fehlernummer aus; 53783 bei OwnRun=0 (kein bestätigter eigener unbeschriebener Lauf) wird als 51011 zurückgegeben. Eingehende Werte werden durch die Initialisierung verworfen; leerer Text kann zuvor nach int 0 konvertiert werden. Ohne OUTPUT-Bindung wird der Rückgabewert verworfen. Nach validierter Source entspricht die Nummer dem ersten Issue mit nicht-NULL ErrorNumber, ersatzweise dem ersten Issue in Issue-Arrayreihenfolge; ohne Issues ist sie NULL. META.errorNumber muss der ausgewählten Sourcefehlernummer entsprechen. Bei erfolgreichem regulären Abschluss kann PARTIAL diese Sourcefehlernummer behalten. Scheitert das Backend nach SourceValidated, gibt eine erfolgreiche getrennte Fehlerfinalisierung die Sourcefehlernummer einschließlich NULL zurück; der tatsächliche Backendfehler wird separat in ModuleStatus festgehalten, soweit diese Finalisierung persistiert. Ist die Finalisierungsgrenze unbestätigt, kann die Ausgabe weiterhin die Sourcefehlernummer enthalten, wenn die Grenzmarkierung geschrieben wird, oder bei einem Fehler in der inneren Finalisierung die Nummer dieses Finalisierungsfehlers. Source- und native Fehlernummern sind vorzeichenbehaftete SQL-int-Werte; 0 und negative Werte sind zulässig. Der Bereich wird nicht auf eine geschlossene Liste von Fehlercodes begrenzt. Eine Fehlerausgabe ist nicht für jeden Aufruf garantiert, weil etwa die frühe Targetabfrage vor TRY ungefangen fehlschlagen kann. | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** | @ErrorMessageOut | Der erforderliche Parameter @ErrorMessageOut ist nvarchar(2048) OUTPUT ohne Default und wird beim Eintritt zunächst auf NULL gesetzt. NULL oder ein typisierter nvarchar(2048)-Wert kann übergeben werden; die SQL-Typkonvertierung erfolgt vor Eintritt. Zum Erfassen muss eine nvarchar(2048)-Variable mit OUTPUT gebunden werden. Das Argument darf nicht ausgelassen werden. Ein Wert ohne OUTPUT-Bindung verwirft die Rückgabe; eingehende Werte einschließlich NULL oder Leertext werden bei Eintritt zurückgesetzt. Bei frühen Eingabefehlern wird die Meldung zu 51011 ausgegeben, bei einer früh nicht bestätigten erwarteten Targetidentität die Meldung zu 53764. Andere vor SourceValidated abgefangene Fehler geben ihre SQL-Fehlermeldung aus. Bei OwnRun=0 wird 53783 wegen eines nicht bestätigten eigenen unbeschriebenen Laufs als 51011 zurückgegeben, seine Meldung bleibt unverändert. Nach validierter Source stammt die Meldung aus demselben Issue wie @ErrorNumberOut: dem ersten Issue mit nicht-NULL ErrorNumber, ersatzweise dem ersten in Arrayreihenfolge. META.errorMessage muss dem Text desselben ausgewählten Issues binär exakt entsprechen. Ohne Issues sind beide META-Fehlerwerte und damit diese Sourceausgaben NULL. Die Meldung kann NULL oder Leertext sein; beides ist verschieden. Bei erfolgreichem regulären Abschluss kann PARTIAL den Sourcefehlertext unverändert behalten. Scheitert das Backend nach SourceValidated, gibt eine erfolgreiche getrennte Fehlerfinalisierung den Sourcefehlertext einschließlich NULL oder Leertext aus; der tatsächliche Backendfehler wird separat in ModuleStatus festgehalten, soweit diese Finalisierung persistiert. Ist die Finalisierungsgrenze unbestätigt, kann die Ausgabe weiterhin den Sourcefehlertext enthalten, wenn die Grenzmarkierung geschrieben wird, oder bei einem Fehler in der inneren Finalisierung die Meldung dieses Finalisierungsfehlers. Der Helper fügt keinen Vergleichscode an und filtert den Sourcefehlertext nicht. Eine Fehlerausgabe ist nicht in jedem Pfad garantiert; die frühe Targetabfrage vor TRY kann ungefangen fehlschlagen. | Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein Fach-Resultset. `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` melden den gebundenen File-I/O-Zielabschluss. Der Helper validiert CollectorJson/Targetidentität und schreibt nur zum eigenen CaptureRun; PARTIAL oder Fehler belegen keinen vollständigen Dateiquellenread.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'InternalCompleteFileIOCycle';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [snapshot].[InternalCompleteFileIOCycle] @CaptureRunId=NULL, @CollectorJson=NULL, @ExpectedTargetDatabaseId=NULL, @ExpectedTargetDatabaseName=NULL, @ExpectedTargetCreateDate=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Alle neun Parameter sind erforderlich; die Signatur hat keine Defaults.
| Parameter | Vertrag |
|---|---|
| @CaptureRunId | bigint; > 0; ID des unbeschriebenen eigenen FILE_IO-Laufs mit Status RUNNING. NULL/0/negativ ergibt INVALID_PARAMETER / 51011; Default: kein Default |
| @CollectorJson | nvarchar(max); vollständiges JSON-Objekt gemäß Schema. NULL, Leertext und ungültiges JSON werden erst nach bestätigtem eigenem Lauf als ERROR_HANDLED / 53782 behandelt, nicht als globales INVALID_PARAMETER; Default: kein Default |
| @ExpectedTargetDatabaseId | int; einzelner typisierter Wert > 4 für die aktuelle, online befindliche, beschreibbare Zieldatenbank. NULL oder abweichende Identität ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |
| @ExpectedTargetDatabaseName | sysname; einzelner roher Datenbankname bis 128 UTF-16-Codeeinheiten. Vergleich mit dem aktuellen Katalognamen ist binär, ohne Trimmen oder Schreibweisenausgleich. NULL oder ein fehlender exakter Match ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |
| @ExpectedTargetCreateDate | datetime; einzelner typisierter Erstellungszeitpunkt aus master.sys.databases.create_date für das aktuelle Target. NULL oder Abwe

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : snapshot.InternalCompleteFileIOCycle
Version      : 1.1.0
Stand        : 2026-10-26
Zweck        : Die Procedure bindet Datei-I/O-Rohwerte und Vergleichskontexte
               atomar an einen vorbereiteten eigenen Lauf.
Grenze       : Monotone Kandidaten beweisen keine Resetkontinuität.

Alle neun Parameter sind erforderlich; die Signatur hat keine Defaults.
| Parameter | Vertrag |
|---|---|
| @CaptureRunId | bigint; > 0; ID des unbeschriebenen eigenen FILE_IO-Laufs mit Status RUNNING. NULL/0/negativ ergibt INVALID_PARAMETER / 51011; Default: kein Default |
| @CollectorJson | nvarchar(max); vollständiges JSON-Objekt gemäß Schema. NULL, Leertext und ungültiges JSON werden erst nach bestätigtem eigenem Lauf als ERROR_HANDLED / 53782 behandelt, nicht als globales INVALID_PARAMETER; Default: kein Default |
| @ExpectedTargetDatabaseId | int; einzelner typisierter Wert > 4 für die aktuelle, online befindliche, beschreibbare Zieldatenbank. NULL oder abweichende Identität ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |
| @ExpectedTargetDatabaseName | sysname; einzelner roher Datenbankname bis 128 UTF-16-Codeeinheiten. Vergleich mit dem aktuellen Katalognamen ist binär, ohne Trimmen oder Schreibweisenausgleich. NULL oder ein fehlender exakter Match ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |
| @ExpectedTargetCreateDate | datetime; einzelner typisierter Erstellungszeitpunkt aus master.sys.databases.create_date für das aktuelle Target. NULL oder Abweichung ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |
| @StatusCodeOut | varchar(40) OUTPUT; initial AVAILABLE. AVAILABLE: ausschließlich Initialwert, kein Abschlussnachweis; INVALID_PARAMETER: frühe Eingabe oder Lauf ungültig; TARGET_UNAVAILABLE: Target nicht verfügbar; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: durchgereichter Source-Status für ein nicht verfügbares Objekt; ERROR_HANDLED: behandelter Fehler; ein nachträglicher Fehlerabschluss ist nicht generell garantiert; PARTIAL: bestätigter regulärer Sourceabschluss unter den beschriebenen Evidenzgrenzen; FINALIZATION_UNCONFIRMED: Finalisierung unbestätigt; Default: kein Default |
| @IsPartialOut | bit OUTPUT; initial 0; Fehler-, PARTIAL- und FINALIZATION_UNCONFIRMED-Pfade setzen 1; Default: kein Default |
| @ErrorNumberOut | Der erforderliche Parameter @ErrorNumberOut ist int OUTPUT ohne Default. Er wird beim Eintritt zunächst auf NULL gesetzt. NULL, ein typisierter int-Wert oder ein ohne OUTPUT-Bindung übergebener Wert sind zulässige Argumentformen; die SQL-Typkonvertierung erfolgt vor Eintritt. Zum Erfassen muss eine int-Variable mit OUTPUT gebunden werden. Das Argument darf nicht ausgelassen werden. Bei frühen Eingabefehlern wird 51011 ausgegeben, bei der frühen Prüfung einer nicht bestätigten erwarteten Targetidentität 53764. Andere vor SourceValidated abgefangene Fehler geben grundsätzlich die tatsächliche SQL-Fehlernummer aus; 53783 bei OwnRun=0 (kein bestätigter eigener unbeschriebener Lauf) wird als 51011 zurückgegeben. Eingehende Werte werden durch die Initialisierung verworfen; leerer Text kann zuvor nach int 0 konvertiert werden. Ohne OUTPUT-Bindung wird der Rückgabewert verworfen. Nach validierter Source entspricht die Nummer dem ersten Issue mit nicht-NULL ErrorNumber, ersatzweise dem ersten Issue in Issue-Arrayreihenfolge; ohne Issues ist sie NULL. META.errorNumber muss der ausgewählten Sourcefehlernummer entsprechen. Bei erfolgreichem regulären Abschluss kann PARTIAL diese Sourcefehlernummer behalten. Scheitert das Backend nach SourceValidated, gibt eine erfolgreiche getrennte Fehlerfinalisierung die Sourcefehlernummer einschließlich NULL zurück; der tatsächliche Backendfehler wird separat in ModuleStatus festgehalten, soweit diese Finalisierung persistiert. Ist die Finalisierungsgrenze unbestätigt, kann die Ausgabe weiterhin die Sourcefehlernummer enthalten, wenn die Grenzmarkierung geschrieben wird, oder bei einem Fehler in der inneren Finalisierung die Nummer dieses Finalisierungsfehlers. Source- und native Fehlernummern sind vorzeichenbehaftete SQL-int-Werte; 0 und negative Werte sind zulässig. Der Bereich wird nicht auf eine geschlossene Liste von Fehlercodes begrenzt. Eine Fehlerausgabe ist nicht für jeden Aufruf garantiert, weil etwa die frühe Targetabfrage vor TRY ungefangen fehlschlagen kann. |
| @ErrorMessageOut | Der erforderliche Parameter @ErrorMessageOut ist nvarchar(2048) OUTPUT ohne Default und wird beim Eintritt zunächst auf NULL gesetzt. NULL oder ein typisierter nvarchar(2048)-Wert kann übergeben werden; die SQL-Typkonvertierung erfolgt vor Eintritt. Zum Erfassen muss eine nvarchar(2048)-Variable mit OUTPUT gebunden werden. Das Argument darf nicht ausgelassen werden. Ein Wert ohne OUTPUT-Bindung verwirft die Rückgabe; eingehende Werte einschließlich NULL oder Leertext werden bei Eintritt zurückgesetzt. Bei frühen Eingabefehlern wird die Meldung zu 51011 ausgegeben, bei einer früh nicht bestätigten erwarteten Targetidentität die Meldung zu 53764. Andere vor SourceValidated abgefangene Fehler geben ihre SQL-Fehlermeldung aus. Bei OwnRun=0 wird 53783 wegen eines nicht bestätigten eigenen unbeschriebenen Laufs als 51011 zurückgegeben, seine Meldung bleibt unverändert. Nach validierter Source stammt die Meldung aus demselben Issue wie @ErrorNumberOut: dem ersten Issue mit nicht-NULL ErrorNumber, ersatzweise dem ersten in Arrayreihenfolge. META.errorMessage muss dem Text desselben ausgewählten Issues binär exakt entsprechen. Ohne Issues sind beide META-Fehlerwerte und damit diese Sourceausgaben NULL. Die Meldung kann NULL oder Leertext sein; beides ist verschieden. Bei erfolgreichem regulären Abschluss kann PARTIAL den Sourcefehlertext unverändert behalten. Scheitert das Backend nach SourceValidated, gibt eine erfolgreiche getrennte Fehlerfinalisierung den Sourcefehlertext einschließlich NULL oder Leertext aus; der tatsächliche Backendfehler wird separat in ModuleStatus festgehalten, soweit diese Finalisierung persistiert. Ist die Finalisierungsgrenze unbestätigt, kann die Ausgabe weiterhin den Sourcefehlertext enthalten, wenn die Grenzmarkierung geschrieben wird, oder bei einem Fehler in der inneren Finalisierung die Meldung dieses Finalisierungsfehlers. Der Helper fügt keinen Vergleichscode an und filtert den Sourcefehlertext nicht. Eine Fehlerausgabe ist nicht in jedem Pfad garantiert; die frühe Targetabfrage vor TRY kann ungefangen fehlschlagen. |

Alle neun Argumente sind erforderlich. OUTPUT-Argumente dürfen als typisierte
Werte oder NULL ohne OUTPUT-Bindung übergeben werden; normale SQL-
Konvertierungen gelten. Eine Variable mit OUTPUT ist nur zur Erfassung nötig.
Alle vier gebundenen OUTPUT-Eingangswerte werden ignoriert; die normalen SQL-Typkonvertierungen erfolgen vor dem Eintritt. Leertext ist keine unterstützte Eingabeform für numerische oder datetime-Parameter.

JSON-Sourcevertrag
Das Rootobjekt hat genau meta (Objekt), databases (Array), files (Array), issues (Array). Alle unten aufgeführten Member sind je Objekt genau einmal erforderlich; keine Zusatzmember oder Duplikate. Member werden mit BIN2 und gleicher UTF-16-Länge verglichen. OPENJSON-Typen: Objekt, Array, String, Zahl, Boolean, NULL. NULL nur wo ausgewiesen. Keine Defaults.

| Objekt | Member | Typ / NULL | Format und Grenzen |
|---|---|---|---|
| META | schemaVersion; resultName; statusCode; nativeReadState; isPartial; sourceComplete | Zahl; String; String; String; Boolean; Boolean, alle nicht-null | Version exakt 1; SnapshotFileIO (max 40); Source status AVAILABLE/EMPTY_UNPROVEN/PARTIAL/DENIED_PERMISSION/UNAVAILABLE_OBJECT/ERROR_HANDLED; Readstatus NOT_STARTED/SUCCEEDED/FAILED; isPartial genau false bei AVAILABLE sonst true; sourceComplete genau true bei AVAILABLE oder EMPTY_UNPROVEN. |
| META | errorNumber; errorMessage | Zahl/NULL; String/NULL | Vorzeichenbehafteter SQL int einschließlich 0 und negative Werte; Nachricht max 2048 UTF-16-Codeeinheiten, NULL ≠ Leertext. |
| META | measurementStartUtc, measurementEndUtc; nativeReadStartUtc, nativeReadEndUtc | String/NULL | Paarweise beide NULL oder gesetzt; Reihenfolge gültig. UTC exakt yyyy-MM-ddTHH:mm:ss.fffZ. Bei nichtfatalem Status ist das Messfenster erforderlich; ein nichtfataler SUCCEEDED-Read benötigt darin ein vorhandenes Readfenster. Bei fatalem SUCCEEDED darf das geordnete Readfenster NULL sein. NOT_STARTED und FAILED besitzen kein Readfenster. |
| META | selectedNativeRows | String/NULL | Nichtnegative kanonische Dezimalzahl ohne führende Nullen, bigint-Bereich; SUCCEEDED erforderlich, FAILED NULL. |
| META | framework; selection; engine | Objekt; Objekt; Objekt/NULL | FW- und SEL-Schema unten; ENGINE bei nichtfatalen Sourcezuständen erforderlich, bei DENIED_PERMISSION/UNAVAILABLE_OBJECT/ERROR_HANDLED NULL. |
| FW | databaseId; databaseName; databaseCreateDateNative | Zahl; String; String | ID 1..2147483647; Name max 128; native datetime yyyy-MM-ddTHH:mm:ss.fff. ID, Name und CreateDateNative müssen master.sys.databases sowie CaptureRun.SourceDatabaseName treffen; das belegt keine authentische DMV-Herkunft. |
| ENGINE | serverName; sqlServerStartTimeLocal; sqlServerStartTimeMsTicks | String; String; String | Name max 128 ohne zusätzliche Mindestlänge; native datetime yyyy-MM-ddTHH:mm:ss.fff; kanonische nichtnegative Dezimalzahl im bigint-Bereich. |
| SEL | requestedDatabaseNames; requestedDatabaseNamePattern | String/NULL; String/NULL | Pattern max 4000; beide Provenienzlabels: Helper parst die Grammatik nicht erneut, filtert nicht erneut und setzt keine gegenseitige Ausschließlichkeit voraus. |
| SEL | systemDatabasesIncluded; selectedDatabaseCount; selectionSha256 | Boolean; String; String | Count kanonisch nichtnegativ im bigint-Bereich und gleich DB-Arraygröße; Hash 64 kleingeschriebene Hexzeichen ohne Präfix: SHA-256 der SQL-spezifischen FOR JSON-Serialisierung der nach DatabaseId geordneten Datenbanktripel mit den Propertynamen DatabaseId, DatabaseName, DatabaseCreateDateNative in dieser Reihenfolge, UTF-16LE. |
| DB | DatabaseId; DatabaseName; DatabaseCreateDateNative; MetadataStatusCode | Zahl; String; String; String | ID 1..2147483647 und eindeutig; Name max 128 ohne Mindestlänge; native datetime yyyy-MM-ddTHH:mm:ss.fff; Status AVAILABLE/DENIED_PERMISSION/UNAVAILABLE_OBJECT/TARGET_CHANGED/ERROR_HANDLED (TARGET_CHANGED: beobachtete DB-Identität geändert). |
| FILE | DatabaseId; FileId | Zahl; Zahl | ID jeweils 1..2147483647; DB-ID muss im DB-Array liegen; Paar eindeutig. |
| FILE | SampleMs; Reads; ReadBytes; ReadStallMs; Writes; WriteBytes; WriteStallMs; SizeOnDiskBytes | Zahl (8 Werte) | Je bigint, nichtnegative kanonische Dezimalzahl ohne führende Nullen. |
| FILE | FileHandle; MetadataBefore; MetadataAfter | String/NULL; Objekt/NULL; Objekt/NULL | Handle NULL oder 0x + 16 kleingeschriebene Hexzeichen. Metadaten NULL oder vollständiges MB/MA-Objekt. |
| MB/MA | DatabaseId; FileId; FileGuid; CreateLsn | Zahl; Zahl; String/NULL; String/NULL | IDs 1..2147483647; Abweichung von FILE-Identität macht die Beobachtung UNBOUND, aber ist kein JSON-Formfehler. GUID NULL oder kanonisch 36 Zeichen lowercase, Null-GUID zulässig; LSN NULL oder nichtnegativ kanonisch im decimal(25,0)-Bereich. |
| MB/MA | FileType; FileState; LogicalName | Zahl; Zahl; String | Beide tinyint 0..255; ROWS/LOG-Eignung nutzt Type 0/1 und State 0, andere typisierte Werte bleiben beobachtbar und können ausgeschlossen sein. LogicalName max 128, keine Mindestlänge. |
| ISSUE | ScopeType; SourceName; DatabaseName; StatusCode | String; String; String/NULL; String | ScopeType: SELECTION (Auswahl), SOURCE (Source-/Engine-Read), DATABASE (Datenbankmetadaten), FILE (Dateimetadaten/native Zeile). SourceName: DATABASE_SELECTION (Auswahlauflösung), sys.databases (Datenbankidentitätsread), sys.database_files (Dateimetadaten), sys.dm_os_sys_info (Engine), sys.dm_io_virtual_file_stats (nativer Cache), SOURCE_CONTRACT (Sourcevertragsvalidierung); alle sechs Werte max. 128 UTF-16-Codeeinheiten. DatabaseName max. 128. Status aus Issue-Katalog unten. |
| ISSUE | ErrorMessage; EvidenceLimit; DatabaseId; FileId; ErrorNumber | String/NULL; String/NULL; Zahl/NULL; Zahl/NULL; Zahl/NULL | Grenzen 2048/1000 UTF-16-Codeeinheiten; IDs NULL oder 1..2147483647; ErrorNumber NULL oder signed SQL int einschließlich 0/negativ. |

Stringzahlen: ASCII-Ziffern, nichtnegativ, keine führenden Nullen außer 0. GUID ist lowercase; Handle beginnt 0x und hat 16 lowercase Hexziffern; SHA hat 64 lowercase Hexziffern ohne 0x. UTC hat Z und Millisekunden, native datetime exakt drei Millisekunden ohne Z. Binäre Kanonizitätsprüfung. BIN2+UTF-16-Länge bei Membern bedeutet keine Zusage, dass jedes Enum mit abschließendem U+0020 eigens abgelehnt wird.

| Katalog | Geschlossene Werte mit Bedeutung |
|---|---|
| Source status | AVAILABLE: vollständige Beobachtung; EMPTY_UNPROVEN: vollständig mit null ELIGIBLE-Dateien, aber kein Nachweis für null native Zeilen oder einen leeren Scope; PARTIAL: nichtfatale, nicht als vollständig bestätigte Beobachtung; DENIED_PERMISSION: Berechtigung verweigert; UNAVAILABLE_OBJECT: erforderliches Objekt fehlt; ERROR_HANDLED: sonstiger abgefangener Sourcefehler. |
| Native Read | NOT_STARTED: kein nativer Read; SUCCEEDED: vollständiger nativer Cache-Read; FAILED: nativer Read fehlgeschlagen. |
| DB MetadataStatusCode | AVAILABLE: Vorher-/Nachher-Metadatenread abgeschlossen; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: Katalogobjekt fehlt; TARGET_CHANGED: beobachtete Datenbankidentität änderte sich; ERROR_HANDLED: anderer Metadatenfehler. |
| Issue ScopeType | SELECTION: Auswahlauflösung; SOURCE: Source- oder Engine-Read; DATABASE: Datenbankmetadaten; FILE: Datei-Metadaten oder nativer Dateieintrag. |
| Issue SourceName | DATABASE_SELECTION: Auswahlauflösung; sys.databases: Datenbankidentitätsread; sys.database_files: Datei-Metadaten; sys.dm_os_sys_info: Enginekontext; sys.dm_io_virtual_file_stats: nativer Dateicache; SOURCE_CONTRACT: Sourcevertragsvalidierung. Alle sechs Werte haben maximal 128 UTF-16-Codeeinheiten. |
| Issue StatusCode | SELECTION_UNRESOLVED: Auswahl nicht bestätigt; DATABASE_CONTEXT_CHANGED: Datenbankkontext änderte sich; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: Objekt fehlt; ERROR_HANDLED: abgefangener Fehler; FILE_METADATA_UNAVAILABLE: zwei stabile Katalogbindungen fehlen; FILE_TYPE_CHANGED: Dateityp änderte sich; FILE_STATE_CHANGED: Dateistatus änderte sich; UNSUPPORTED_FILE_TYPE: außerhalb ROWS-/LOG-Scope; FILE_NOT_ONLINE: nicht ONLINE; IDENTITY_FIELD_UNKNOWN: Identitätsfeld fehlt; IDENTITY_OBSERVATION_CHANGED: Identitätsbeobachtung änderte sich; NATIVE_FILE_UNAVAILABLE: Online-ROWS-/LOG-Datei fehlt im nativen Cache. |

Fachliche Bindungen und Fehlerbehandlung
Der Helper verlangt SC-023-Version 1.3.1 / Schema 3 und den tatsächlich installierten schreibfreien Retentionshandshake. Eigener Lauf ist nur die unbeschriebene FILE_IO-CaptureRun-Zeile mit Status RUNNING. Fehlender, fremder, abgeschlossener oder bereits beschriebener Lauf ergibt INVALID_PARAMETER / 51011 und wird nicht finalisiert. Eine ungültige aktive Policy (53783) nach OwnRun=1 wird zunächst als ERROR_HANDLED behandelt; der getrennte Fehlerabschluss kann scheitern und FINALIZATION_UNCONFIRMED ergeben. Die nichtfatalen Sourcezustände AVAILABLE, EMPTY_UNPROVEN und PARTIAL verlangen Enginekontext und Messfenster; DENIED_PERMISSION, UNAVAILABLE_OBJECT und ERROR_HANDLED sind fatal und verlangen engine=NULL. NOT_STARTED: leeres databases-Array verlangt native Anzahl 0; nichtleeres Array verlangt fatalen Status und Anzahl NULL. SUCCEEDED kann bei fatalem Status die native Anzahl behalten, aber files bleibt leer; bei nichtfatalem Status entspricht FILE-Anzahl der nativen Anzahl. FAILED verlangt fatalen Status, Anzahl NULL und kein Readfenster. sourceComplete=true gilt nur bei AVAILABLE oder EMPTY_UNPROVEN; außerdem müssen alle DB-Metadaten AVAILABLE sein, UNBOUND fehlen und Issues auf UNSUPPORTED_FILE_TYPE, FILE_NOT_ONLINE, IDENTITY_OBSERVATION_CHANGED oder IDENTITY_FIELD_UNKNOWN begrenzt sein. Der Selektionshash nutzt SQL-spezifisches FOR JSON; requestedDatabaseNames und requestedDatabaseNamePattern sind unveränderte, opake Provenienzlabels. Framework-ID, -Name und -CreateDate müssen master.sys.databases und CaptureRun.SourceDatabaseName treffen; dies belegt keine authentische DMV-Herkunft. Datenbankanzahl, Identitäten, Dateien und Issues sind gebunden.

Eine identitätsunvollständige, sonst geeignete Datei kann ELIGIBLE sein und sieben numerische Rohwerte mit Partialstatus als Per-Run-Beobachtung erhalten; sie erhält keinen Differenzvergleich. UNBOUND bezeichnet dagegen eine wegen DB-/Metadaten-/Typ-/Statusabweichung nicht ausgewählte Rohzeile und erzeugt keine Raw-Messwerte. Ausgeschlossene Dateien bleiben von geeigneten unterscheidbar. MaxRows der aktiven FILE_IO-Policy ist 1..100000 und begrenzt geschriebene Dateizeilen. Pro ausgewählter Datei: sieben Rohwerte, Status und Dateikontext; bis zu sechs Differenzkandidaten nur bei belegter Vergleichbarkeit. Ein regulär abgeschlossener nichtfataler Lauf speichert zusätzlich genau ein IO_CAPTURE_CONTEXT-Sample auf dem Serverscope, auch bei null ausgewählten Dateien. Die tatsächliche Metrikzahl beträgt damit 9 × geschriebene Dateien + 6 × vergleichbare Dateien + 1: je ausgewählter Datei sieben Rohwerte, ein Status- und ein Dateikontextsample sowie sechs Kandidaten je vergleichbarer Datei. Fatale Sourcepfade überspringen diese Metrikpersistierung. Erfolgreiche Vollaufnahme bleibt PARTIAL; weder atomare Katalog-/DMV-Sicht noch Resetkontinuität wird behauptet. Optionales GZIP nur für reguläre valide Sourcezweige.

Nach Catch rollt der Helper zurück. Getrennte Fehlerfinalisierung ohne Payload wird nur bei OwnRun=1, erneut bestätigtem Target und bestätigtem unbeschriebenen Lauf versucht. Nach validierter Source können SourceErrorNumber und SourceErrorMessage trotz Backendfehler NULL bleiben; der tatsächliche Backendfehler steht in ModuleStatus. Gebundene Sourceissues bleiben erhalten. Geschlossene Finalisierung kann ERROR_HANDLED ergeben; offene/fehlgeschlagene kann FINALIZATION_UNCONFIRMED liefern. ErrorMessageOut erhält keinen vom Helper angefügten Vergleichscode; Sourcefehlertext wird nicht gefiltert.
Kanonische JSON-Zahlen sind Ganzzahlen ohne Dezimalpunkt oder Exponent und ohne führende Nullen außer 0. ID-Werte liegen zwischen 1 und 2147483647, INT-Fehlernummern zwischen -2147483648 und 2147483647, TINY-Werte zwischen 0 und 255. Nichtnegative bigint-Werte reichen von 0 bis 9223372036854775807; Vorzeichen sind dort unzulässig. CreateLsn ist eine JSON-Zeichenfolge mit einem kanonischen nichtnegativen decimal(25,0)-Ganzzahlwert. Native Zeitzeichenfolgen sind genau 23 Zeichen lang und müssen den SQL-datetime-Rundtrip bestehen; UTC-Zeichenfolgen sind gültige datetime2(3)-Werte mit genau 24 Zeichen einschließlich abschließendem Z. Stringgrenzen beziehen sich auf UTF-16-Codeeinheiten. Issue.ScopeType hat maximal 16, Issue.StatusCode und DB.MetadataStatusCode maximal 40; META.resultName, META.statusCode und META.nativeReadState ebenfalls maximal 40.

Die Identitäts- und Kontextprüfungen prüfen die übergebenen Daten auf Konsistenz; sie authentifizieren die Erfassung nicht nachträglich. Die frühe Targetabfrage gegen master.sys.databases liegt vor TRY und kann einen SQL-Fehler ungefangen weiterreichen. Die Retentionsprobe muss tatsächlich AVAILABLE, Vertrag 3, keine Run-ID, keine Fehlernummer und Budgetsignal 0 zurückgeben. Die aktive FILE_IO-Policy verlangt MaxRows von 1 bis 100000 und einen nicht-NULL PayloadEnabled-Wert. Die Source-Meldung bindet den ersten Issue mit nicht-NULL Fehlernummer, ersatzweise den ersten Issue in Arrayreihenfolge; ohne Issues sind beide META-Fehlerwerte NULL. Metadatennamen und Katalogwerte sind damit auf innere Konsistenz geprüft, nicht auf eine kryptografisch authentische DMV-Herkunft.

Ein nachfolgender SQL-Fehler kann nach bereits validierter Source deren ursprüngliche Fehlernummer und Meldung als Ausgabe erhalten, einschließlich NULL oder Leertext; der tatsächliche SQL-Fehler wird separat in ModuleStatus festgehalten, soweit die Fehlerfinalisierung gelingt. Schlägt dieser Versuch fehl, kann FINALIZATION_UNCONFIRMED stattdessen die dabei entstandene SQL-Fehlernummer und Meldung ausgeben. Eine offene Finalisierungsgrenze ist kein erfolgreicher Runabschluss.
```

