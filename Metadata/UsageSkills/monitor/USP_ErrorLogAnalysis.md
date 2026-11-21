---
skill_format_version: "1.0.0"
name: "monitor.USP_ErrorLogAnalysis"
schema_name: "monitor"
object_name: "USP_ErrorLogAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liest SQL-Server- und optional Agent-Errorlogs über dokumentierte sp_readerrorlog-Filter in Kategorien, Summary und Source-Status."
source_path: "Code/07_Infrastructure/140_USP_ErrorLogAnalysis.sql"
---

# monitor.USP_ErrorLogAnalysis

## Zweck und Einsatz

Liest SQL-Server- und optional Agent-Errorlogs über dokumentierte sp_readerrorlog-Filter in Kategorien, Summary und Source-Status.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_ErrorLogAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `master.sys.sp_readerrorlog`, `[master].[sys].[sp_readerrorlog]`, `[monitor].[TVF_ClassifyErrorLogEvent]`, `[monitor].[TVF_ProjectUnicodeText]`, `[monitor].[InternalEmitConsoleResult]`, `[monitor].[InternalWriteResultTable]`, `[monitor].[InternalEmitTruncationWarning]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @AgentEinbeziehen | bit | nein | 0 |
| @MaxArchivNummer | tinyint | nein | 0 |
| @SeitServerlokalzeit | datetime2(3) | nein | NULL |
| @Suchtext1 | nvarchar(4000) | nein | NULL |
| @Suchtext2 | nvarchar(4000) | nein | NULL |
| @MeldungstextEinbeziehen | bit | nein | 0 |
| @MaxMeldungszeichen | int | nein | 4000 |
| @MaxQuellzeilen | int | nein | 10000 |
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

**@AgentEinbeziehen:** @AgentEinbeziehen bit. Default ist 0. 0 liest nur SQL-Server-Logs. 1 nimmt zusätzlich Agent-Logs auf. NULL/andere Bitwerte ungültig.

**@MaxArchivNummer:** @MaxArchivNummer tinyint. Default ist 0. Höchste Archivnummer. 0 nur aktuelles Log, n liest Archive 0..n für gewählte Produkte. 0..20 inkl.. NULL oder >20 ungültig. Keine Rotation.

**@SeitServerlokalzeit:** @SeitServerlokalzeit datetime2(3). Default ist NULL. Untergrenze für LogDate in Serverlokalzeit. NULL berechnet 24 Stunden vor serverlokaler SYSDATETIME beim Prozedurstart. Der Grenzwert wird nach Keywordfilter angewandt, sp_readerrorlog wird dadurch zeitlich nicht eingeengt. Fester Zeitpunkt empfohlen für reproduzierbare Läufe. kein UTC-Offset wird angenommen.

**@Suchtext1:** @Suchtext1 nvarchar(4000). Default ist NULL. NULL zusammen mit Suchtext2=NULL aktiviert kuratierte Suchregeln. Ein nichtleerer Suchtext ersetzt diese Regeln durch den dokumentierten Keywordfilter. Leertext und reine Leerzeichen sind ungültig. Suchtext2 darf nur zusammen mit Suchtext1 gesetzt sein.

**@Suchtext2:** @Suchtext2 nvarchar(4000). Default ist NULL. Optionaler zweiter Keywordfilter zusammen mit Suchtext1. NULL deaktiviert ihn. Ohne ersten Suchtext oder bei leerer beziehungsweise nur aus Leerzeichen bestehender Eingabe ist der Aufruf ungültig.

**@MeldungstextEinbeziehen:** @MeldungstextEinbeziehen bit. Default ist 0. 0 lässt Details/Volltext aus. 1 aktiviert Detailausgabe mit ProcessInfo und projiziertem Meldungstext (Datenschutz-Opt-in). NULL ungültig. Ausgabe bleibt durch MaxZeilen und MaxMeldungszeichen begrenzbar.

**@MaxMeldungszeichen:** @MaxMeldungszeichen int. Default ist 4000. Maximale Zeichen pro projiziertem Meldungstext. 4000 default, 0 explizit unbegrenzt. nichtnegativ. Kürzung erzeugt genau eine Warning. NULL/negativ ungültig.

**@MaxQuellzeilen:** @MaxQuellzeilen int. Default ist 10000. Eine positive ganze Zahl begrenzt die materialisierten Quelltreffer. NULL oder 0 hebt die Grenze auf. Negative Werte sind ungültig. Keywordfilter wirken beim Loglesen, die Zeitprüfung anschließend.

**@MaxZeilen:** @MaxZeilen int. Default ist 1000. Detailausgabe Top-N nach Sortierung. 1000 default, 0 oder NULL unbegrenzt, positiv begrenzt, negativ ungültig. Begrenzt keine Summary, Quellenstatus, Zähler oder Warnungen.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt die Zusammenfassung. RAW liefert alle fachlichen Mengen mit Status und Warnungen. TABLE schreibt benannte Ergebnismengen. NONE unterdrückt die Resultsets. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Bei TABLE ist ein gültiges nichtleeres JSON-Objekt erforderlich. Wählen Sie eine Teilmenge der exakten Schlüssel moduleStatus, summary, details, sourceStatus und warnings. Jeder Wert benennt eine andere vorhandene leere lokale #Temp-Tabelle mit einer Seed-Spalte. Globale Tabellen und #Monitor-Präfixe sind ausgeschlossen. Außerhalb von TABLE sind nur NULL, Leertext und reine Leerzeichen zulässig.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON, 0 aus. NULL ungültig. JSON enthält Metadaten, Summary und je nach Opt-in Details.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Outputparameter, wird zu Beginn NULL gesetzt. bei JsonErzeugen=1 befüllt. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. Steuert PRINT-Meldungen. 1 an, 0 aus, NULL ungültig. Verändert nicht das Resultset.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe vor dem Logzugriff und der Parameterprüfung. 0 und NULL führen die Analyse aus.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT. Default ist NULL. Outputstatus des Laufs, z.B. AVAILABLE/AVAILABLE_LIMITED/DENIED_PERMISSION. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

**@IsPartialOut:** @IsPartialOut bit OUTPUT. Default ist NULL. Outputbit, kennzeichnet unvollständige Quellen/Evidenz. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT. Default ist NULL. Outputfehlernummer oder NULL, wenn keiner erfasst. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT. Default ist NULL. Outputfehlertext oder NULL, wenn keiner erfasst. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [SinceServerLocalTime] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [AgentRequested] bit NOT NULL , [HighestArchiveRequested] tinyint NOT NULL , [SourceRowLimit] int NULL , [AcceptedSourceRows] bigint NOT NULL , [SummaryRowCount] bigint NOT NULL , [DetailRowCount] bigint NOT NULL , [HasMoreSourceRows] bit NOT NULL , [HasMoreDetailRows] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL |
| summary | 1 | 1 | [ProductName] varchar(32) NOT NULL , [Category] varchar(80) NOT NULL , [EventCount] bigint NOT NULL , [FirstOccurrenceServerLocal] datetime NOT NULL , [LastOccurrenceServerLocal] datetime NOT NULL , [ArchiveCount] int NOT NULL , [HighestArchiveNumber] int NOT NULL , [TimeSemantics] varchar(64) NOT NULL , [FindingCode] varchar(80) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| details | 1 | 1 | [ProductName] varchar(32) NOT NULL , [ArchiveNumber] int NOT NULL , [Category] varchar(80) NOT NULL , [LogDateServerLocal] datetime NOT NULL , [TimeSemantics] varchar(64) NOT NULL , [ProcessInfo] nvarchar(50) NULL , [MessageCharacters] bigint NULL , [MessageBytes] bigint NULL , [MessageIsTruncated] bit NOT NULL , [MessageText] nvarchar(max) NULL |
| sourceStatus | 1 | 1 | [SourceOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY , [ProductName] varchar(32) NOT NULL , [ArchiveNumber] int NOT NULL , [RuleCategory] varchar(80) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ReadRowCount] bigint NOT NULL , [AcceptedRowCount] bigint NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| warnings | 1 | 1 | [WarningOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY , [SourceName] sysname NOT NULL , [StatusCode] varchar(40) NOT NULL , [ErrorNumber] int NULL , [Message] nvarchar(2048) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ErrorLogAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

sp_readerrorlog besitzt keinen dokumentierten Zeitparameter. Deshalb wird serverseitig nach Keywords und anschließend nach LogDate begrenzt. Sehr große Treffer werden AVAILABLE_LIMITED.

Kein Logwechsel, keine Konfiguration, keine Persistenz.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ErrorLogAnalysis
Version      : 1.0.0
Stand        : 2026-07-21
Zweck        : Liest SQL-Server- und optional Agent-Errorlogs über dokumentierte
               sp_readerrorlog-Filter in Kategorien, Summary und Source-Status.
Default      : Aktuelles SQL-Server-Log, letzte 24 Stunden Serverlokalzeit,
               kuratierte High-Signal-Filter, kein Meldungsvolltext.
Grenzen      : sp_readerrorlog besitzt keinen dokumentierten Zeitparameter.
               Deshalb wird serverseitig nach Keywords und anschließend nach
               LogDate begrenzt. Sehr große Treffer werden AVAILABLE_LIMITED.
Nebenwirkung : Kein Logwechsel, keine Konfiguration, keine Persistenz.
Datenschutz  : Meldungstext und ProcessInfo nur opt-in; Laufzeitausgabe darf
               reale Diagnosewerte enthalten, Repositoryartefakte niemals.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ErrorLogAnalysis
Beispiel 1. EXEC [monitor].[USP_ErrorLogAnalysis] @Hilfe=1;
Beispiel 2. DECLARE @Since datetime2(3)='2026-01-01T00:00:00'; EXEC [monitor].[USP_ErrorLogAnalysis] @SeitServerlokalzeit=@Since, @Suchtext1=N'ExampleNoMatch', @MaxQuellzeilen=100, @MaxZeilen=25, @ResultSetArt='RAW';
Beispiel 3. DECLARE @Since datetime2(3)='2026-01-01T00:00:00'; DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_ErrorLogAnalysis] @SeitServerlokalzeit=@Since, @Suchtext1=N'ExampleNoMatch', @MaxQuellzeilen=100, @MaxZeilen=25, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Beispiel 4. CREATE TABLE #ErrorLogAnalysis_HelpExample ([Seed] int NULL); DECLARE @Since datetime2(3)='2026-01-01T00:00:00'; BEGIN TRY EXEC [monitor].[USP_ErrorLogAnalysis] @SeitServerlokalzeit=@Since, @Suchtext1=N'ExampleNoMatch', @MaxQuellzeilen=100, @MaxZeilen=25, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#ErrorLogAnalysis_HelpExample"}'; SELECT * FROM #ErrorLogAnalysis_HelpExample; DROP TABLE #ErrorLogAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #ErrorLogAnalysis_HelpExample; THROW; END CATCH;
```

