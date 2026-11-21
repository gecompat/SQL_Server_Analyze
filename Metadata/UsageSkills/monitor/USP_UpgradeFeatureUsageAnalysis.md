---
skill_format_version: "1.0.0"
name: "monitor.USP_UpgradeFeatureUsageAnalysis"
schema_name: "monitor"
object_name: "USP_UpgradeFeatureUsageAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Zeigt native Deprecated-Begegnungszähler und eine begrenzte Zielversionsregel ohne Upgradefreigabe oder Datenbankattribution."
source_path: "Code/09_VersionAdaptive/120_USP_UpgradeFeatureUsageAnalysis.sql"
---

# monitor.USP_UpgradeFeatureUsageAnalysis

## Zweck und Einsatz

Zeigt native Deprecated-Begegnungszähler und eine begrenzte Zielversionsregel ohne Upgradefreigabe oder Datenbankattribution.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_UpgradeFeatureUsageAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `sys.dm_os_sys_info`, `sys.dm_os_performance_counters`, `sys.configurations`, `[sys].[dm_os_sys_info]`, `[sys].[dm_os_performance_counters]`, `[sys].[configurations]`, `[monitor].[InternalWriteResultTable]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @TargetMajorVersion | int | nein | NULL |
| @MaxZeilen | int | nein | 1000 |
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

**@TargetMajorVersion:** @TargetMajorVersion int; Default: NULL. Eingabeform: einzelne SQL-int-Zahl 15, 16 oder 17; andere Werte sind ungültig. NULL wählt keine Zielbewertung. Ausgelassen entspricht Default NULL. Leerwert ist für int keine eigene Eingabeform und wird bei expliziter Konvertierung gemäß SQL Server behandelt. Zulässige Werte taxativ: 15 = SQL Server 2019, 16 = SQL Server 2022, 17 = SQL Server 2025. Bei beobachteter Source-Major 15/16/17 muss das Ziel mindestens der Source-Major entsprechen. Eine nicht unterstützte oder nicht ermittelte Sourceversion verhindert diese Sourcebewertung. Wirkung: Zielregel gilt nur für lightweight pooling ab Ziel 17; Usage-Zeilen bleiben TARGET_NOT_SELECTED bei NULL beziehungsweise UNMAPPED_SOURCE_FEATURE bei ausgewähltem Ziel.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Eingabeform: SQL-int; NULL oder 0 bedeutet unbegrenzte Ausgabe der nativen Counterzeilen, positive Werte 1 bis 2147483647 begrenzen ausschließlich deprecatedUsage/Counter-Ausgabe, negative Werte sind ungültig. Ausgelassen entspricht 1000. Leerwert ist keine eigene int-Eingabeform; explizite Konvertierung folgt SQL Server. Der vollständige gefilterte native Countercache wird vor diesem Limit gelesen; context, configuration und sources werden nicht dadurch gekürzt. OutputLimited vergleicht NativeCounterRows mit ReturnedCounterRows.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Eingabeform: Zeichenwert; äußere U+0020-Leerzeichen werden entfernt, dann mit UPPER normalisiert; zulässige Werte taxativ: CONSOLE = vier fachliche Gruppen formatiert ausgeben; RAW = vier typisierte Resultsets in Reihenfolge context, deprecatedUsage, configuration, sources; TABLE = zugeordnete Gruppen in Caller-Temp-Tabellen schreiben; NONE = fachliche Resultsets unterdrücken. Maßgeblich ist der bei Eintritt bereits an varchar(16) zugewiesene SQL-Wert; längere Textargumente können davor auf diese Typbreite gekürzt werden. Erst dieser Wert wird normalisiert und gegen die vier Optionen geprüft. NULL und leer oder nur U+0020-Leerzeichen werden zu leer und sind ungültig; ausgelassen verwendet Default 'CONSOLE'. Andere nach Typzuweisung und Normalisierung verbleibende Werte sind ungültig. Bei TABLE muss @ResultTablesJson eine gültige Zuordnung enthalten; bei allen anderen Modi muss es NULL, leer oder nur U+0020-Leerzeichen sein. NONE unterdrückt nur fachliche Resultsets; JSON, Status-OUTPUTs und durch @PrintMeldungen gesteuerte Meldungen bleiben möglich.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Eingabeform: bei @ResultSetArt=TABLE ein nichtleeres gültiges JSON-Objekt, dessen Schlüssel taxativ folgende Bedeutung haben: context = Aufnahme-, Versions- und Enginekontext; deprecatedUsage = native Deprecated-Counter; configuration = begrenzte Optionsbewertung; sources = vier Quellenzustände und Fehler und dessen Werte eindeutige Namen vorhandener leerer lokaler #Temp-Tabellen sind. Jede Zuordnung ist optional; mindestens eine ist erforderlich. Resultset-Schlüssel werden binär und damit einschließlich Groß-/Kleinschreibung verglichen. Zielnamen dürfen höchstens LEN 116 umfassen; doppelte Ziele werden case-insensitiv erkannt. JSON-Werte müssen Strings sein; doppelte Resultsetnamen, doppelte Zieltabellen und unbekannte Schlüssel sind unzulässig. Jede Ziel-Temp-Tabelle muss eine beliebige einzelne Seed-Spalte haben; Typ und Spaltenname sind nicht festgelegt, und eine Seed-Zeile ist nicht zulässig. Ziel muss lokale #Temp-Tabelle, nicht ##Temp oder #Monitor-Präfix sein. Ein Teilmapping exportiert nur die benannten Gruppen. NULL/leer oder nur U+0020-Leerzeichen wird außerhalb TABLE akzeptiert; in TABLE ungültig. Ausgelassen entspricht NULL. Ungültige Zuordnung schlägt vor den fachlichen Quellenreads fehl.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Eingabeform: bit-Schalter. 0 = kein JSON erzeugen; 1 = JSON im OUTPUT @Json erzeugen. NULL ist ungültig. Ausgelassen entspricht 0. Andere bitkonvertierbare Nichtnullwerte werden durch SQL-bit-Konvertierung auf 0 oder 1 abgebildet (0 bleibt 0, jeder Nichtnullwert ungleich 0 wird 1). Hilfe und Parameter-/Setup-/Ausgabefehler liefern @Json=NULL; regulär abgefangene Quellenfehler erlauben weiterhin ein partielles JSON.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Argument optional; für den Rückgabewert eine Variable des deklarierten Typs mit OUTPUT binden. Default NULL; initial wird der empfangene Wert auf NULL zurückgesetzt. Bei @Hilfe=1 oder Parameter-/Setup-/Ausgabefehlern bleibt beziehungsweise wird er NULL; regulär abgefangene Quellenfehler erlauben partielles JSON. Bei regulärer Analyse und @JsonErzeugen=1 enthält er ein JSON-Objekt mit meta sowie context, deprecatedUsage, configuration und sources als Arrays; bei @JsonErzeugen=0 bleibt er NULL. Eingabeinhalt wird nicht als Steuerwert verwendet; ausgelassen ist die OUTPUT-Bindung optional, der Default initialisiert intern NULL.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Eingabeform: bit-Schalter. 0 = keine zusätzlichen Severity-10-Meldungen über RAISERROR bei regulären Quellenfehlern oder im CATCH; 1 = solche Meldungen ausgeben, wenn der jeweilige Fehlerpfad eintritt. NULL ist ungültig. Ausgelassen entspricht 1. Andere bitkonvertierbare Nichtnullwerte werden als 0 oder 1 abgebildet (0 bleibt 0, jeder Nichtnullwert ungleich 0 wird 1). Steuert weder Resultsets noch Status-OUTPUTs. Die Hilfe-PRINTs bleiben unabhängig von diesem Schalter aktiv.

**@Hilfe:** @Hilfe bit; Default: 0. Eingabeform: bit-Schalter. 0 = normale Parameterprüfung und Analyse; 1 = Hilfe-PRINTs ausgeben und ohne gewöhnliche Parameter-/Quellenvalidierung RETURN ausführen. NULL ist ungültig, wenn nicht 1. Ausgelassen entspricht 0. Andere bitkonvertierbare Nichtnullwerte werden als 0 oder 1 abgebildet (0 bleibt 0, jeder Nichtnullwert ungleich 0 wird 1). Vor dem Hilfepfad werden @Json=NULL, @StatusCodeOut=PARTIAL, @IsPartialOut=1 und Fehler-OUTPUTs NULL initialisiert; Hilfe überschreibt Status auf AVAILABLE und IsPartial auf 0.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Bindung: Caller bindet varchar(40) OUTPUT; Eingabewert wird zurückgesetzt. Default NULL. Taxative Statuswerte: AVAILABLE = Hilfe wurde ausgegeben; PARTIAL = reguläre Analyse mit beobachteten Counter- oder Optionszeilen; DENIED_PERMISSION = keine fachlichen Zeilen und ausschließlich Rechtefehler; ERROR_HANDLED = sonstiger Fehler beziehungsweise abgefangener Ausgabe-/Setupfehler; EMPTY_UNPROVEN = erfolgreiche leere Beobachtung ohne Nutzungsfrei- oder Kompatibilitätsnachweis; UNAVAILABLE_OBJECT = tatsächliche Source-Major nicht unterstützt/nicht ermittelbar; INVALID_PARAMETER = ungültige Aufruf-/TABLE-Zuordnung. Normale Quellenfehler werden als Status gemeldet und liefern RETURN 0; technische Fehler liefern nonzero RETURN. Bei Ausgabe-/Setupfehlern wird der technische Fehlerstatus über die Fehlerprojektion auf ERROR_HANDLED oder bei 51011 auf INVALID_PARAMETER abgebildet.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT-Bindung: Caller bindet bit OUTPUT; Eingabewert wird zurückgesetzt. Default NULL. Reguläre Analyse setzt 1, weil AssessmentCoverage stets LIMITED_OBSERVATION ist; Hilfe setzt 0, weil keine Analyse ausgeführt wurde. Bei ungültigen Parametern oder technischen Fehlern bleibt der Teilstatus 1; beim Eintritt wird 1 initialisiert. Die Eingabewerte NULL, 0 und 1 steuern den Aufruf nicht.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT-Bindung: Caller bindet int OUTPUT; Eingabewert wird zurückgesetzt. Default NULL. Hilfe und fehlerfreie Ausführung liefern NULL. Bei regulären Quellenfehlern wird der erste tatsächliche SQL-Fehler nach Quellenreihenfolge ausgegeben; bei Parameterfehlern 51011; bei technischem Ausgabe-/Setupfehler der tatsächliche Fehler beziehungsweise der gesetzte technische Fehlercode. Ohne Fehler bleibt NULL.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT-Bindung: Caller bindet nvarchar(2048) OUTPUT; Eingabewert wird zurückgesetzt. Default NULL. Hilfe und fehlerfreie Ausführung liefern NULL. Vorrang hat die Meldung des ersten Quellenfehlers mit Fehlernummer nach Quellenreihenfolge; ohne Fehlernummer folgt die erste vorhandene Quellenmeldung. Auch eine fehlende Enginebindung kann eine Meldung ohne Fehlernummer liefern; bei Parameter-/TABLE-Preflightfehlern oder technischem Fehler wird die tatsächlich gesetzte Fehlermeldung ausgegeben. Die vollständige quellenbezogene Fehlerlage bleibt im sources-Ergebnis, soweit dieses Ergebnis erreicht wird.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| context | 1 | 1 | [CollectionTimeUtc] datetime2(3) NOT NULL,[SourceMajorVersion] int NULL,[SourceBuild] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [TargetMajorVersion] int NULL,[SqlServerStartTimeLocal] datetime NULL,[SqlServerStartTimeMsTicks] bigint NULL,[EngineContextConfirmed] bit NOT NULL, [MeasurementStartUtc] datetime2(3) NULL,[MeasurementEndUtc] datetime2(3) NULL, [CounterReadState] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeCounterRows] bigint NULL,[ReturnedCounterRows] bigint NOT NULL, [OutputLimited] bit NOT NULL,[AssessmentCoverage] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [RuleCatalogVersion] int NOT NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[IsPartial] bit NOT NULL |
| deprecatedUsage | 1 | 1 | [ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [FeatureName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeCounterType] int NOT NULL,[NativeCounterValue] bigint NOT NULL, [ObservationStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TargetAssessment] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| configuration | 1 | 1 | [ConfigurationName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ConfiguredValue] int NULL,[ValueInUse] int NULL,[IsDynamic] bit NULL, [TargetMajorVersion] int NULL,[RuleCode] varchar(96) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[RuleCatalogVersion] int NOT NULL, [AssessmentStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[SourceReference] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sources | 1 | 1 | [SourceOrdinal] smallint NOT NULL,[SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[NativeReadState] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, [NativeRows] bigint NULL,[ErrorNumber] int NULL,[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Nur SQL-sichtbare Metadaten; keine Konfigurations- oder Hoständerung.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_UpgradeFeatureUsageAnalysis
Version      : 1.0.0
Stand        : 2026-10-26
Zweck        : Zeigt native Deprecated-Begegnungszähler und eine begrenzte
               Zielversionsregel ohne Upgradefreigabe oder Datenbankattribution.
Grenze       : Begegnungen können Kompilierungen zählen; Null ist kein Nutzungsfrei-Beweis.
Nebenwirkung : Nur SQL-sichtbare Metadaten; keine Konfigurations- oder Hoständerung.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_UpgradeFeatureUsageAnalysis
Instanzweite native Deprecated-Begegnungszähler; Kompilierungen können zählen. Kein Ausführungs-, Datenbank- oder Upgrade-ready-Urteil.
Eine begrenzte Regel beschreibt lightweight pooling ab Ziel 17; weitere deprecated/discontinued/breaking Features bleiben getrennt offen.
Normale Analyse außerhalb einer Callertransaktion und mit IMPLICIT_TRANSACTIONS OFF ausführen. Hilfe kehrt nach Initialisierung der OUTPUTs vor gewöhnlicher Validierung und Quellenreads zurück.
Beispiel Hilfe: EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis] @Hilfe=1;
Beispiel Ziel und Rohdaten: EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis] @TargetMajorVersion=17,@ResultSetArt='RAW';
Beispiel JSON: DECLARE @j nvarchar(max); EXEC [monitor].[USP_UpgradeFeatureUsageAnalysis] @TargetMajorVersion=17,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@j OUTPUT; SELECT @j;
```

