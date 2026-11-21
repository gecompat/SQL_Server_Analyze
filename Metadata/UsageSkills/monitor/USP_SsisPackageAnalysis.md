---
skill_format_version: "1.0.0"
name: "monitor.USP_SsisPackageAnalysis"
schema_name: "monitor"
object_name: "USP_SsisPackageAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert ein direkt übergebenes DTSX-v2-Paket statisch."
source_path: "Code/10_SSIS/010_USP_SsisPackageAnalysis.sql"
---

# monitor.USP_SsisPackageAnalysis

## Zweck und Einsatz

Inventarisiert ein direkt übergebenes DTSX-v2-Paket statisch.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_SsisPackageAnalysis] im vorgesehenen Datenbankkontext. Der Bericht liest ausschließlich den übergebenen Paketmodell-/Dateiinhalt im gebundenen Analysekontext; externe SSIS-Ausführung, Katalogzugriff und fremde Dateien sind keine durch EXECUTE automatisch erteilten Rechte.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @PackageXml | xml | nein | NULL |
| @PackageParametersJson | nvarchar(max) | nein | NULL |
| @AnalysisDepth | varchar(16) | nein | 'STANDARD' |
| @ResolveSqlMetadata | bit | nein | 0 |
| @CheckLookupData | bit | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
| @MaxDurationSeconds | int | nein | 30 |
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

**@PackageXml:** @PackageXml: Datentyp xml. Direkt übergebenes SQL-xml-Instanz; Default: NULL. Erforderlich für eine Analyse; NULL wird als ungültiger Parameter bewertet. Geprüft werden ein Executable-Wurzelelement im Namespace www.microsoft.com/SqlServer/Dts sowie ein nichtleerer ExecutableType passend zu %Package%; andere Formen ergeben UNSUPPORTED_PACKAGE_FORMAT. Eine vollständige DTSX-Schemavalidierung wird damit nicht behauptet. Es wird ausschließlich dieser Wert untersucht; die Procedure öffnet keine Datei, ISPAC-, SSISDB-, Datenbank- oder externe Verbindungsquelle. Für @Hilfe = 1 wird das Argument vor der Quellenprüfung nicht verwendet.

**@PackageParametersJson:** @PackageParametersJson: Datentyp nvarchar(max). Unverwendetes Eingabeargument; Default: NULL. Die Procedure liest diesen Wert nicht, validiert weder JSON-Syntax noch Inhalt und wendet keine Paketparameter auf das XML an. NULL, Leertext, syntaktisch ungültiges JSON und sonstige Inhalte haben für den Parserpfad keine Wirkung. Paketparameter im XML werden nur als Metadaten inventarisiert; Werte werden nicht ausgegeben.

**@AnalysisDepth:** @AnalysisDepth: Datentyp varchar(16). Analyseumfang; Default: STANDARD. Zulässige Form ist nach Trim und Umwandlung in Großbuchstaben ausschließlich STANDARD. Damit wird der implementierte statische Parser-Slice angefordert. NULL und jeder andere Wert sind ungültig; ein Leerwert ist ebenfalls ungültig.

**@ResolveSqlMetadata:** @ResolveSqlMetadata: Datentyp bit. Reservierter Schalter für SQL-Metadatenauflösung; Default: 0. Nur 0 ist zulässig. NULL und 1 werden als ungültige Parameter bewertet. Eine Metadatenauflösung ist in diesem Parser-Slice nicht implementiert; der Schalter aktiviert keine solche Funktion. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@CheckLookupData:** @CheckLookupData: Datentyp bit. Reservierter Schalter für Lookup-Datenprüfungen; Default: 0. Nur 0 ist zulässig. NULL und 1 werden als ungültige Parameter bewertet. Lookup-Daten werden in diesem Parser-Slice nicht gelesen; der Schalter aktiviert keine Prüfung. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@HighImpactConfirmed:** @HighImpactConfirmed: Datentyp bit. Bestätigungsschalter; Default: 0. Beide Bitwerte 0 und 1 werden angenommen; NULL wird als ungültiger Parameter bewertet. Der Wert wird nicht zur Freigabe oder Erweiterung einer Analyse verwendet und ändert den Parserumfang nicht. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@MaxZeilen:** @MaxZeilen: Datentyp int. Zeilengrenze; Default: 1000. Zulässig sind NULL, 0 oder positive Ganzzahlen von 1 bis 2147483647; negative Werte sind ungültig. NULL und 0 bedeuten unbegrenzt. Bei RAW begrenzt der Wert acht Detailgruppen (Executables, Constraints, Data-Flow-Komponenten, Connections, Parameter, Expressions, Lineage und Variablen); Modulstatus, Paket, Findings, Quellenstatus und Warnungen werden davon nicht begrenzt. Das interne Inventar wird nicht vorab auf diese Grenze beschränkt. Für TABLE und JSON begrenzt @MaxZeilen nur das Variableninventar; die übrigen Arrays/Zieltabellen werden nicht durch diesen Parameter gekürzt.

**@MaxDurationSeconds:** @MaxDurationSeconds: Datentyp int; SQL-int-Skalarwert in Sekunden; Default: 30. Zulässig sind Ganzzahlen von 1 bis 60. NULL sowie Werte außerhalb dieses Bereichs werden als INVALID_PARAMETER mit Teilstatus und Diagnose zurückgegeben. Ein als Leertext übergebenes Argument kann bei SQL Server implizit zu 0 konvertiert werden und ist deshalb ungültig. Der Parameter wird nicht für eine Frist, einen Abbruch oder ein Laufzeitlimit verwendet; eine tatsächliche Zeitbegrenzung besteht nicht.

**@LockTimeoutMs:** @LockTimeoutMs: Datentyp int. SQL-int-Skalarwert in Millisekunden; bei ausgelassenem Argument gilt der Default 0. Leertext kann bei SQL Server implizit zu 0 konvertiert werden und wird nicht als eigenständige Leerwerteingabe geprüft. Zulässig sind 0 bis 60000; NULL und Zahlen außerhalb dieses Bereichs werden als INVALID_PARAMETER zurückgegeben. Der Parameter ist derzeit reserviert: Zulässige Werte werden validiert, ändern aber die Sperrwartezeit der nachfolgenden Analyse nicht. Die direkte Prozedurarbeit verwendet die beim Aufruf geltende LOCK_TIMEOUT-Einstellung. Der dynamische SET-Batch endet vor der Analyse; SQL Server stellt seine Einstellung bei der Rückkehr aus dem Batch wieder her. TABLE-Hilfsprocedures behalten ihre eigene Sperrwartezeitregel für die geerbte Sitzungseinstellung: Bei initialer Temp-Tabellen-DDL erhöhen sie einen eingehenden Wert 0 auf 1000 ms, behalten andere eingehende Werte für diese Anlage bei und setzen für Zieloperationen 0 (NOWAIT). Die Sitzungseinstellung des Aufrufers bleibt erhalten.

**@ResultSetArt:** @ResultSetArt: Datentyp varchar(16). Ausgabeform; Default: CONSOLE. Der Wert wird getrimmt und in Großbuchstaben umgewandelt. Zulässige Werte: CONSOLE gibt die Zusammenfassung über InternalEmitConsoleResult aus; RAW gibt die dreizehn Resultsets in dokumentierter Reihenfolge aus; TABLE schreibt angeforderte Gruppen in benannte lokale #Temp-Ziele; NONE gibt keine fachlichen Resultsets dieser drei Formen aus. NULL, Leerwert und andere Werte sind ungültig. TABLE erfordert eine gültige, nichtleere Zuordnung in @ResultTablesJson. Außerhalb von TABLE muss @ResultTablesJson NULL oder leer oder nur aus U+0020-Leerzeichen bestehend sein. JSON ist keine zulässige Ausgabeart; JSON wird separat mit @JsonErzeugen angefordert.

**@ResultTablesJson:** @ResultTablesJson: Datentyp nvarchar(max). JSON-Zuordnung für TABLE-Ausgabe; Default: NULL. Nur bei @ResultSetArt = TABLE wird die Eingabe als nichtleeres JSON-Objekt ausgewertet. Zulässige Schlüssel sind exakt (groß-/kleinschreibungssensitiv): moduleStatus = Zusammenfassungsstatus; package = Paketmetadaten; executables = Executable-Inventar; controlFlowConstraints = direkte Kontrollflusskanten; dataFlowComponents = Pipeline-Komponenten; connections = Connection-Manager-Metadaten; parameters = Paketparameter-Metadaten; expressions = direkte Property-Expressions; lineage = direkte Pipeline-Verbindungen; findings = Befunde; sourceStatus = Quellenstatus; warnings = Hinweise; variables = Variablendefinitionen. Jeder Wert muss ein nichtleerer Tabellenname als JSON-String sein. Jede Zuordnung muss auf eine bereits angelegte, leere lokale #Temp-Tabelle mit genau einer Seed-Spalte zeigen; ##-Tabellen, Namen über 116 Zeichen und #Monitor*-Ziele sind unzulässig. Eine nichtleere Teilmenge der 13 Gruppen ist zulässig; nicht zugeordnete Gruppen werden nicht geschrieben. Beispiel: N'{"moduleStatus":"#SsisModuleStatus"}'. Resultsetnamen dürfen nicht doppelt vorkommen; doppelte Zielnamen und das reservierte Präfix #Monitor werden ohne Beachtung der Großschreibung geprüft; unbekannte Schlüssel werden abgelehnt. Die Zuordnung wird vor dem fachlichen XML-Parsing vollständig geprüft. Bei TABLE führen NULL, ungültiges JSON, ein leeres Objekt oder fehlende/unzulässige Ziele zum Fehler. Bei anderen Ausgabeformen wird ein nichtleerer Wert als ungültige Kombination abgewiesen; NULL und Leer-/U+0020-Leerzeichen-Text werden ignoriert.

**@JsonErzeugen:** @JsonErzeugen: Datentyp bit. Steuert die Ausgabe über @Json; Default: 0. 0 erzeugt kein JSON; 1 weist das erzeugte JSON @Json zu. NULL ist ungültig. Das JSON-Wurzelobjekt enthält 13 Arrays mit den Schlüsseln moduleStatus, package, executables, controlFlowConstraints, dataFlowComponents, connections, parameters, expressions, lineage, findings, sourceStatus, warnings und variables; ein zusätzliches meta-Objekt ist nicht implementiert. Das package-Array wird bei leerem Paketinventar ausdrücklich als [] ausgegeben. Nur variables wird mit INCLUDE_NULL_VALUES serialisiert. Das JSON wird unabhängig von @ResultSetArt erzeugt, sofern der reguläre Analysepfad erreicht wird. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Json:** @Json: Datentyp nvarchar(max) OUTPUT. OUTPUT-Parameter für das JSON-Dokument; Default: NULL OUTPUT. Beim Eintritt wird @Json stets auf NULL initialisiert. Bei @JsonErzeugen = 1 wird es im regulären Pfad an das JSON-Wurzelobjekt gebunden; andernfalls bleibt es NULL. Im Hilfezweig bleibt es NULL. Der Aufrufer muss die Ausgabe wie im Beispiel mit @Json = @Variable OUTPUT binden.

**@PrintMeldungen:** @PrintMeldungen: Datentyp bit. Historischer Meldungsschalter; Default: 1. Die implementierte Validierung akzeptiert 0 und 1; NULL wird als ungültig bewertet. Der Wert wird nach der NULL-Prüfung nicht weiter ausgewertet und steuert die CONSOLE-Ausgabe oder PRINT-Meldungen nicht. Die CONSOLE-Ausgabe richtet sich nach @ResultSetArt. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

**@Hilfe:** @Hilfe: Datentyp bit. Gibt die eingebaute Hilfe aus; Default: 0. Nur der Wert 1 löst die Hilfe aus: die Procedure druckt feste Hilfetexte und kehrt vor Mappingprüfung, XML-Validierung und Analyse zurück; eine Paketquelle ist dafür nicht erforderlich. Der Hilfezweig prüft diesen Parameter nicht auf NULL; NULL verhält sich daher wie kein Hilfeaufruf und führt in den regulären Pfad. SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. 0 führt regulär fort. Die Hilfe setzt nur @Json=NULL; die vier Status-/Fehler-OUTPUTs bleiben unverändert, unabhängig von @PrintMeldungen.

**@StatusCodeOut:** @StatusCodeOut: Datentyp varchar(40) OUTPUT. varchar(40)-Variable mit OUTPUT am Aufruf binden; Default: NULL OUTPUT. Bei regulärer Zuweisung sind die im Code gesetzten Statuswerte AVAILABLE_LIMITED (implementiertes begrenztes Inventar), INVALID_PARAMETER (erkannte ungültige Argumente) und UNSUPPORTED_PACKAGE_FORMAT (nicht unterstützte XML-/Paketwurzel) möglich. Dies ist kein Eingabeauswahlcode; der Eingangswert wird erst bei regulärem Abschluss überschrieben. Bei Hilfe oder einem vorher entkommenden Fehler bleibt er unverändert.

**@IsPartialOut:** @IsPartialOut: Datentyp bit OUTPUT. bit-Variable mit OUTPUT am Aufruf binden; Default: NULL OUTPUT. Bei regulärem Abschluss wird im aktuellen begrenzten Parser-Slice stets 1 zugewiesen; 0 wird von diesem Implementierungsstand nicht erzeugt. Ein vorgebundener 0-, 1- oder NULL-Wert hat keine Steuerwirkung. Bei Hilfe oder einem Fehler vor der Zuweisung bleibt er unverändert.

**@ErrorNumberOut:** @ErrorNumberOut: Datentyp int OUTPUT. int-Variable mit OUTPUT am Aufruf binden; Default: NULL OUTPUT. Der aktuelle reguläre Pfad weist NULL zu; erkannte Parameter-/Formatfehler liefern einen Status und Meldungstext, aber keine interne Fehlernummer. Ein entkommender SQL-Fehler wird hier nicht allgemein abgefangen. Eingangswerte sind keine Steuerung und bleiben bei Hilfe beziehungsweise vorzeitiger Ausnahme unverändert.

**@ErrorMessageOut:** @ErrorMessageOut: Datentyp nvarchar(2048) OUTPUT. nvarchar(2048)-Variable mit OUTPUT am Aufruf binden; Default: NULL OUTPUT. Kapazität: 2048 UTF-16-Codeeinheiten. Bei regulärem Abschluss enthält sie den Parameter-/Formatfehlertext oder NULL; sie ist kein Eingabefilter. Bei Hilfe oder einem Fehler vor der abschließenden Zuweisung bleibt ein vorgebundener Wert unverändert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname NOT NULL, [CollectionTimeUtc] datetime2(3) NOT NULL, [SchemaVersion] int NOT NULL, [StatusCode] varchar(40) NOT NULL, [IsPartial] bit NOT NULL, [PackageCount] int NOT NULL, [ExecutableCount] int NOT NULL, [FindingCount] int NOT NULL, [ErrorNumber] int NULL, [ErrorMessage] nvarchar(2048) NULL |
| package | 1 | 1 | [PackageName] nvarchar(256) NULL, [PackageFormatVersion] int NULL, [RootExecutableType] nvarchar(256) NULL, [ProtectionLevel] nvarchar(64) NULL, [ExecutableCount] int NOT NULL, [AnalysisStatus] varchar(40) NOT NULL, [EvidenceLimit] nvarchar(1000) NOT NULL |
| executables | 1 | 1 | [ExecutableOrdinal] int NOT NULL, [ParentExecutableName] nvarchar(256) NULL, [ExecutableName] nvarchar(256) NULL, [ExecutableType] nvarchar(256) NULL, [CreationName] nvarchar(256) NULL, [IsPackageRoot] bit NOT NULL, [IsDisabled] bit NULL, [SourceStatus] varchar(40) NOT NULL |
| controlFlowConstraints | 1 | 1 | [ConstraintOrdinal] int NOT NULL, [ParentExecutableName] nvarchar(256) NULL, [FromExecutableName] nvarchar(256) NULL, [ToExecutableName] nvarchar(256) NULL, [EvaluationOperation] tinyint NULL, [OutcomeValue] tinyint NULL, [LogicalAnd] bit NULL, [HasExpression] bit NOT NULL, [SourceStatus] varchar(40) NOT NULL |
| dataFlowComponents | 1 | 1 | [ComponentOrdinal] int NOT NULL, [ComponentName] nvarchar(256) NULL, [ComponentKind] nvarchar(128) NULL, [SourceStatus] varchar(40) NOT NULL |
| connections | 1 | 1 | [ConnectionOrdinal] int NOT NULL, [ConnectionName] nvarchar(256) NULL, [ConnectionKind] nvarchar(128) NULL, [SourceStatus] varchar(40) NOT NULL |
| parameters | 1 | 1 | [ParameterOrdinal] int NOT NULL, [ParameterScope] varchar(16) NULL, [ParameterName] nvarchar(256) NULL, [SourceStatus] varchar(40) NOT NULL |
| expressions | 1 | 1 | [ExpressionOrdinal] int NOT NULL, [ExpressionScope] nvarchar(256) NULL, [PropertyName] nvarchar(256) NULL, [SourceStatus] varchar(40) NOT NULL |
| lineage | 1 | 1 | [LineageOrdinal] int NOT NULL, [SourceComponent] nvarchar(256) NULL, [TargetComponent] nvarchar(256) NULL, [SourceStatus] varchar(40) NOT NULL |
| findings | 1 | 1 | [RuleId] varchar(64) NOT NULL, [Severity] varchar(16) NOT NULL, [EvidenceLevel] varchar(32) NOT NULL, [Finding] nvarchar(1000) NOT NULL, [SourceStatus] varchar(40) NOT NULL |
| sourceStatus | 1 | 1 | [SourceName] nvarchar(160) NOT NULL, [StatusCode] varchar(40) NOT NULL, [IsPartial] bit NOT NULL, [ReturnedRowCount] bigint NULL, [Detail] nvarchar(1000) NOT NULL |
| warnings | 1 | 1 | [WarningCode] varchar(64) NOT NULL, [WarningSeverity] varchar(16) NOT NULL, [Detail] nvarchar(1000) NOT NULL |
| variables | 1 | 1 | [VariableOrdinal] int NOT NULL, [ScopeExecutableOrdinal] int NOT NULL, [VariableNamespace] nvarchar(256) NOT NULL, [VariableName] nvarchar(256) NULL, [DataTypeCode] int NULL, [IsReadOnly] bit NULL, [EvaluateAsExpression] bit NULL, [SourceStatus] varchar(40) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_SsisPackageAnalysis] @Hilfe = 1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_SsisPackageAnalysis inventarisiert direkt übergebenes XML ohne Paket-, SQL-, Datei- oder SSISDB-Ausführung.

Ausgelassene Argumente verwenden den Signaturdefault. Strings als T-SQL-Literale übergeben, Unicode mit N-Präfix; XML als xml-Variable oder konvertierbaren XML-Text, Zahlen als skalare Werte. Typkonvertierung findet vor dem Aufruf statt. Die normale Analyse bleibt read-only gegenüber externen Quellen; TABLE verändert ausdrücklich übergebene lokale Temp-Ziele.

Vier Hilfeaufrufe ohne XML-Analyse:

DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SsisPackageAnalysis] @Hilfe = 1, @JsonErzeugen = 1, @Json = @Json OUTPUT; SELECT @Json AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_SsisPackageAnalysis
Version      : 1.2.0
Stand        : 2026-10-11
Typ          : Stored Procedure
Zweck        : Inventarisiert ein direkt übergebenes DTSX-v2-Paket statisch.
Datenquelle  : Ausschließlich @PackageXml; keine Datei-, ISPAC-, SSISDB-,
               Datenbank- oder externe Verbindungsquelle wird geöffnet.
Datenschutz  : Keine Connection Strings, Secret-, Binary-, Host-, Login- oder
               vollständigen Pfadwerte werden gelesen oder ausgegeben.
Abgrenzung   : Dieser erste Slice stabilisiert Paket-, Executable- und direkte
               Parent-Container-Inventare.
               Direkte Pipeline-Komponentenlinien werden inventarisiert; weitergehende
               Lineage und Regeln bleiben ausdrücklich begrenzt. Direkte
               Precedence Constraints, Connection Manager und
               Property-Expressions werden ohne Ausdrucks- oder
               Connection-String-Werte inventarisiert.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_SsisPackageAnalysis inventarisiert direkt übergebenes XML ohne Paket-, SQL-, Datei- oder SSISDB-Ausführung.
Ausgelassene Argumente verwenden den Signaturdefault. Strings als T-SQL-Literale übergeben, Unicode mit N-Präfix; XML als xml-Variable oder konvertierbaren XML-Text, Zahlen als skalare Werte. Typkonvertierung findet vor dem Aufruf statt. Die normale Analyse bleibt read-only gegenüber externen Quellen; TABLE verändert ausdrücklich übergebene lokale Temp-Ziele.
Vier Hilfeaufrufe ohne XML-Analyse:
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SsisPackageAnalysis] @Hilfe = 1, @JsonErzeugen = 1, @Json = @Json OUTPUT; SELECT @Json AS [Json];
```

