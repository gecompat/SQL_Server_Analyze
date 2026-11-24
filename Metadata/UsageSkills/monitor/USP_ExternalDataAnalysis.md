---
skill_format_version: "1.0.0"
name: "monitor.USP_ExternalDataAnalysis"
schema_name: "monitor"
object_name: "USP_ExternalDataAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure analysiert sichtbare lokale externe Katalogobjekte und Referenzen."
source_path: "Code/09_VersionAdaptive/110_USP_ExternalDataAnalysis.sql"
---

# monitor.USP_ExternalDataAnalysis

## Zweck und Einsatz

Die Procedure analysiert sichtbare lokale externe Katalogobjekte und Referenzen.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_ExternalDataAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `sys.external_data_sources`, `sys.external_file_formats`, `sys.external_tables`, `sys.schemas`, `sys.columns`, `sys.external_models` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. NULL, Leerstring oder ausschließlich äußere U+0020-Leerzeichen bedeuten keine exakte Einschränkung. Sonst eine bracket-aware Pipe-Liste: | trennt außerhalb von [...], ]] maskiert innen eine schließende Klammer; äußere U+0020-Leerzeichen je Element werden entfernt. Jedes rohe Segment darf höchstens 4000 UTF-16-Codeeinheiten umfassen. TVF_ParseSqlNameList prüft PARSENAME-Teil 1 auf einen nicht-NULL Namen, Teil 2 auf NULL und LEN(Teil 1) auf höchstens 128. Punkte außerhalb eines einzelnen quotierten Namens sind auch bei ausgelassenen Qualifizierern ungültig. Dies ist keine vollständige SQL-Bezeichnergrammatik, Existenz- oder Berechtigungsprüfung. Leere/fehlerhaft geklammerte Elemente, Parserablehnung und case-sensitive doppelte gültige Namen ergeben INVALID_PARAMETER. Eine wirksame Liste und jeder nicht-NULL @DatabaseNamePattern-Wert sind zusammen ungültig. Nur sichtbare, ONLINE befindliche, zugreifbare Datenbanken ohne Snapshotmarkierung werden Kandidaten; Systemdatenbanken bleiben ohne Opt-in ausgeschlossen. Nicht verfügbare explizit angeforderte Namen können Auswahlwarnungen liefern. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. NULL oder ausgelassen bedeutet kein Pattern. Ein nicht-NULL Wert wird außen mit LTRIM/RTRIM getrimmt. Zulässige Eingabe ist ein LIKE-Pattern (case-sensitive SQL_Latin1_General_CP1_CS_AS; SQL-LIKE-Metazeichen %, _, [...] gelten) oder ein optionales Präfix LIKE:, REGEX: oder REGEXI:, dessen Erkennung nicht auf Groß-/Kleinschreibung achtet. Nach Entfernen des Präfixes wird der Rest nicht erneut getrimmt. Ein leerer oder nur aus U+0020-Leerzeichen bestehender Eingang oder leeres Präfixergebnis ist ungültig und führt zu INVALID_PARAMETER. Eine wirksame @DatabaseNames-Liste und jeder nicht-NULL Patternwert sind zusammen ungültig. REGEX verwendet Flag c, REGEXI Flag i; Regex-Syntax wird nicht vorab validiert. Regexausführung benötigt SQL Server 2025 (Major 17) und Compatibility Level 170 der Installationsdatenbank; andernfalls UNAVAILABLE_FEATURE. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Numerische 0 schließt Systemdatenbanken mit IDs bis 4 (master, tempdb, model, msdb) aus; jeder numerische Wert ungleich 0 wird als 1 behandelt und lässt sie in die Auswahl ein. NULL ist ungültig und führt zu INVALID_PARAMETER; ausgelassen gilt 0. Ausgeschlossene explizit angeforderte Systemdatenbanken können als SYSTEM_DATABASE_EXCLUDED-Warnung gemeldet werden. Beeinflusst nur Kandidatenauswahl. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int; Default: 2000. NULL oder 0 hebt das Ausgabelimit praktisch auf. Positive Werte begrenzen jeweils getrennt die ausgegebenen Zeilen in dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings; die Sortierschlüssel sind Datenbankname plus jeweilige Kennung/Quelle beziehungsweise Warnung. Negative Werte führen zu INVALID_PARAMETER. Die Grenze steuert weder Datenbankscope, Sammelarbeit noch Counts: DataSourceCount, FileFormatCount, ExternalTableCount, ExternalModelCount und RowCount beruhen auf der Sammlung vor Ausgabelimits. moduleStatus und databaseStatus werden nicht durch dieses Detailgruppenlimit abgeschnitten. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. NULL wird wie leer behandelt, danach werden äußere Leerzeichen entfernt und in Großbuchstaben normalisiert; ausgelassen gilt CONSOLE. Zulässige endliche Werte: RAW gibt die acht nativen Resultsets aus (moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus, warnings); TABLE schreibt die ausgewählten Resultsets in Caller-Temp-Tabellen; CONSOLE gibt eine menschenlesbare Ansicht von databaseStatus aus; NONE unterdrückt fachliche Resultsets. Jeder andere Wert einschließlich JSON führt zu INVALID_PARAMETER. JSON wird unabhängig davon mit @JsonErzeugen angefordert und kann zusätzlich zu jeder zulässigen Ausgabeart erzeugt werden. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. NULL, N'' oder nur Leerzeichen bedeutet keine Zuordnung; ausgelassen gilt NULL. Nur TABLE darf eine nicht-leere JSON-Zuordnung erhalten; bei anderer @ResultSetArt wirft die Procedure Fehler 51011. Das JSON-Objekt muss mindestens ein Schlüssel-Wert-Paar enthalten; jeder Schlüssel muss exakt (case-sensitive, binärer Vergleich) einer der acht Namen moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus oder warnings entsprechen. Jeder Wert muss eine nicht-leere Zeichenfolge mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein. Resultset-Schlüsseldubletten werden binär erkannt; doppelte Zieltabellennamen sind unter Latin1_General_100_CI_AS unzulässig. Zielname muss mit # beginnen, darf nicht ## sein, höchstens 116 Zeichen lang sein und nicht mit dem reservierten Präfix #Monitor beginnen (case-insensitive). Jede Zieltemp-Tabelle muss beim Aufruf leer sein und genau eine Seed-Spalte besitzen; die Vorprüfung erkennt dies, indem sie temporär eine Marker-Spalte hinzufügt und insgesamt zwei Spalten erwartet. Der Seedname/-typ wird dabei nicht als Quellschema vorgegeben: InternalWriteResultTable passt die leere Ein-Spalten-Tabelle an das native Schema des jeweiligen Resultsets an und fügt dessen Zeilen ein. Vorprüfung läuft für alle Ziele vor dem Schreiben. Schreibvorgänge erfolgen je Mapping nacheinander ohne behauptete Gesamttransaktion/atomare Mehrzieltabelle; ein späterer Fehler kann bereits geschriebene frühere Ziele belassen. Ungültige Zuordnung oder Ziele werden vor dem Schreiben mit 51011 abgelehnt. Alle acht Schlüssel mit jeweiligem Inhalt: moduleStatus liefert Modulstatus und Partialität; databaseStatus Datenbankstatus und ungekürzte Counts; dataSources sichtbare lokale Datenquellen; fileFormats sichtbare Dateiformate; externalTables externe Tabellen mit Referenzsichtbarkeit und Spaltenanzahl; modelSummary Modellanzahl und Modellquellenstatus; sourceStatus Quellenstatus mit nativen Fehlerfeldern; warnings Auswahl-/Quellenwarnungen. Jede nichtleere Teilmenge der acht Schlüssel genügt. Im TABLE-Modus sind NULL, Leerstring und ein leeres Objekt ungültig. Vorprüfungsablehnungen werfen 51011; Writerablehnungen werfen 51010. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Numerische 0 deaktiviert JSON; jeder numerische Wert ungleich 0 aktiviert es. NULL ist ungültig und führt zu INVALID_PARAMETER; ausgelassen gilt 0. Die JSON-Ausgabe ist zusätzlich zu RAW/TABLE/CONSOLE/NONE und enthält meta sowie stets acht Arrays: moduleStatus, databaseStatus, dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings. Die sechs Detailgruppen dataSources, fileFormats, externalTables, modelSummary, sourceStatus und warnings sind bereits je @MaxZeilen begrenzt; JSON enthält NULL-Spalten ausdrücklich. Wird JSON nicht angefordert, wird @Json zu Beginn auf NULL gesetzt. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT nvarchar(max), ohne Eingabeparameterwirkung. Beim regulären Eintritt wird die Ausgabebindung vor dem Hilfezweig auf NULL gesetzt; bei @JsonErzeugen=1 wird sie am regulären JSON-Zweig mit dem JSON-Dokument belegt, sonst bleibt sie NULL. Zum Empfang muss eine Caller-Variable vom Typ nvarchar(max) mit OUTPUT gebunden werden; ohne OUTPUT-Bindung wird der Wert nicht zurückgegeben. Bei ungefangenen Fehlern ist keine reguläre Ausgabegarantie beschrieben. Bei ausgelassenem Argument gilt der angegebene Default.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Numerische 0 unterdrückt die Statusmeldung per RAISERROR severity 10; jeder numerische Wert ungleich 0 aktiviert sie. NULL ist ungültig und führt zu INVALID_PARAMETER; ausgelassen gilt 1. Eine Meldung wird nur erzeugt, wenn der abschließende Status nicht AVAILABLE ist, und enthält Status sowie Kurztext, nicht ein zusätzliches Resultset. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit; Default: 0. Numerische 0 führt die Analyse aus; jeder numerische Wert ungleich 0 aktiviert die Hilfe. NULL aktiviert die Hilfe nicht und wird in der anschließenden normalen Parameterprüfung als ungültig behandelt; ausgelassen gilt 0. Der Hilfezweig druckt die Hilfetexte, setzt @StatusCodeOut auf AVAILABLE und @IsPartialOut auf 0 und kehrt vor Katalogaufnahme zurück. @Json bleibt wegen der Initialisierung NULL. Der Zweig validiert keine übrigen Parameter. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT varchar(40). Regulärer Rückgabestatus nach Auswertung der Datenbank-/Quellenaufnahme; bei @Hilfe=1 ausdrücklich AVAILABLE. Sämtliche Modulstatuswerte und ihre Bedeutung/Priorität: AVAILABLE = regulärer Abschluss ohne festgestellte Partialität; AVAILABLE_LIMITED = mindestens ein Datenbank-/Quellenbefund ist partiell und mindestens eine Quelle ist AVAILABLE; sonst wird der erste partielle Datenbankstatus nach Datenbankname übernommen. INVALID_PARAMETER = ungültige Ausgabeart, negatives @MaxZeilen oder NULL in den geprüften Bitparametern; dieser Parameterfehlerstatus hat vor der Kandidatenermittlung Vorrang. INTERNAL_ERROR = der Kandidatenhelfer kann die erwartete Kandidatentabelle nicht verwenden; dieser Status wird unverändert übernommen. DENIED_PERMISSION = Kandidatenvorbereitung oder Quelle scheitert mit einer der explizit klassifizierten Berechtigungsfehlernummern 229, 262, 297, 300, 371. SOURCE_UNAVAILABLE = Fehler 207 oder 208 beim Kandidaten-/Quellenzugriff. ERROR_HANDLED = sonstiger abgefangener Fehler der Kandidatenvorbereitung/Quelle. DATABASE_UNAVAILABLE = explizit angeforderte Datenbank wurde nicht als Kandidat verarbeitet. UNAVAILABLE_FEATURE = Regex kann wegen fehlender SQL Server 2025-/Compatibility-Level-170-Voraussetzung nicht ausgeführt werden. Auf Quellenebene zusätzlich: UNAVAILABLE_VERSION = external_models wird bei ProductMajorVersion <17 nicht gelesen und allein daraus folgt keine Partialität; AVAILABLE bedeutet erfolgreiche Quellenabfrage, auch bei null Zeilen; DENIED_PERMISSION, SOURCE_UNAVAILABLE und ERROR_HANDLED kennzeichnen fehlgeschlagene Abfragen. Partielle Datenbank ohne erfolgreiche Quelle übernimmt den ersten nicht erfolgreichen Quellenstatus nach fester Quellenrangfolge; bei mindestens einer erfolgreichen Quelle wird sie AVAILABLE_LIMITED. Der erste native Fehlerwert für das Top-Level wird nach Datenbankname und Quellenrangfolge gewählt. Ausgabe-/Mapping-Preflight kann Fehler werfen (51011), bevor reguläre Outputzuweisung erfolgt; der äußere Catch wirft wieder und setzt keine Status-Outputs. Für den Empfang Caller-Variable varchar(40) mit OUTPUT binden; ohne OUTPUT wird der Wert nicht empfangen. SYSTEM_DATABASE_EXCLUDED ist hier ein Auswahlwarnungscode, kein zusätzlicher Modulstatus: die zugehörige nicht verarbeitete angeforderte Datenbank wird als DATABASE_UNAVAILABLE in databaseStatus aufgenommen und kann zur Modulaggregation DATABASE_UNAVAILABLE oder AVAILABLE_LIMITED beitragen. Die feste Klasse STANDARD_CURRENT verlangt im Katalog kein Gruppengate; ihr Freigabepfad ergänzt keine Gruppen-/High-Impact-Statuswerte. Bei ausgelassenem Argument gilt der angegebene Default.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Bindung an eine bit-Variable. Hilfe liefert ausdrücklich 0. Die lokale Prüfung von Ausgabeart, Zeilenlimit und geprüften Bit-NULLs setzt INVALID_PARAMETER und 1. Eine partielle Datenbank-/Quellenaufnahme setzt ebenfalls 1. Zurückgegebene Statuswerte des Kandidatenhelfers, darunter INVALID_PARAMETER, INTERNAL_ERROR und UNAVAILABLE_FEATURE, setzen die anfangs mit 0 belegte Partialvariable dagegen nicht automatisch auf 1. Ein solcher Status kann daher mit 0 enden; 0 allein ist kein Nachweis einer erfolgreichen vollständigen Aufnahme. Ohne OUTPUT-Bindung wird der Wert nicht empfangen. Bei geworfenen Fehlern einschließlich TABLE-Vorprüfungsfehlern ist keine reguläre abschließende OUTPUT-Zuweisung garantiert. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [CollectionTimeUtc] datetime2(3) NOT NULL |
| databaseStatus | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [DataSourceCount] bigint NULL , [FileFormatCount] bigint NULL , [ExternalTableCount] bigint NULL , [ExternalModelCount] bigint NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| dataSources | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [DataSourceId] int NOT NULL , [DataSourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [TypeCode] tinyint NULL , [TypeDescription] nvarchar(255) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| fileFormats | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FileFormatId] int NOT NULL , [FileFormatName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FormatTypeCode] tinyint NULL |
| externalTables | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ObjectId] int NOT NULL , [SchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [TableName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [DataSourceId] int NULL , [FileFormatId] int NULL , [DataSourceReferenceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FileFormatReferenceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [VisibleColumnCount] bigint NULL |
| modelSummary | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [VisibleModelCount] bigint NULL , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |
| sourceStatus | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [CollectionTimeUtc] datetime2(3) NOT NULL |
| warnings | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Detail] nvarchar(2000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

`fileFormats.FormatTypeCode` enthält den nativen Formatwert, soweit er als `tinyint` darstellbar ist. Native Formatnamen wie `DELIMITEDTEXT` ergeben `NULL`. Die gelesene Formatzeile und ihre Tabellenreferenzen bleiben verfügbar.

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ExternalDataAnalysis] @MaxZeilen=200, @ResultSetArt='RAW', @PrintMeldungen=0;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Keine Remote-, Location-, Credential-, Modellnamen- oder Payloadlesung. Fehlende sichtbare Referenzen beweisen keinen defekten Fremdschlüssel.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ExternalDataAnalysis
Version      : 1.0.0
Stand        : 2026-10-14
Zweck        : Die Procedure analysiert sichtbare lokale externe Katalogobjekte und Referenzen.
Eigenlast    : Lokale Katalogabfragen und aggregierte sichtbare Spalten je Datenbank.
Grenzen      : Keine Remote-, Location-, Credential-, Modellnamen- oder Payloadlesung.
               Fehlende sichtbare Referenzen beweisen keinen defekten Fremdschlüssel.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ExternalDataAnalysis
Die Procedure erfasst ausschließlich caller-sichtbare lokale Katalogmetadaten ausgewählter Datenbanken; sie fragt keine Remotequelle oder externen Inhalte ab.
RAW liefert acht native Resultsets, TABLE die ausgewählten benannten Mengen und CONSOLE die Datenbankübersicht. NONE unterdrückt fachliche Resultsets; JSON wird unabhängig über @JsonErzeugen angefordert.
Quellstatus und Partialität sind gemeinsam zu lesen. Fehlende sichtbare Referenzen beweisen keinen defekten Fremdschlüssel; nicht gelesene oder ausgefallene Quellen erhalten keine erfundenen Werte.
DECLARE @Json nvarchar(max), @Status varchar(40), @Partial bit, @ReturnCode int; EXEC @ReturnCode=[monitor].[USP_ExternalDataAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT, @StatusCodeOut=@Status OUTPUT, @IsPartialOut=@Partial OUTPUT, @PrintMeldungen=0; SELECT @ReturnCode AS [ReturnCode], @Status AS [StatusCode], @Partial AS [IsPartial], @Json AS [DiagnosticJson];
CREATE TABLE [#ExternalDataAnalysis_HelpExample] ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_ExternalDataAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=N'{"databaseStatus":"#ExternalDataAnalysis_HelpExample"}', @PrintMeldungen=0; SELECT * FROM [#ExternalDataAnalysis_HelpExample]; DROP TABLE IF EXISTS [#ExternalDataAnalysis_HelpExample]; END TRY BEGIN CATCH DROP TABLE IF EXISTS [#ExternalDataAnalysis_HelpExample]; THROW; END CATCH;
```

