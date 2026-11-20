---
skill_format_version: "1.0.0"
name: "monitor.USP_BackupChainAnalysis"
schema_name: "monitor"
object_name: "USP_BackupChainAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure bewertet Backupketten und Wiederherstellbarkeitsevidenz aus msdb."
source_path: "Code/07_Infrastructure/100_USP_BackupChainAnalysis.sql"
---

# monitor.USP_BackupChainAnalysis

## Zweck und Einsatz

Die Procedure bewertet Backupketten und Wiederherstellbarkeitsevidenz aus msdb.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_BackupChainAnalysis] im vorgesehenen Datenbankkontext. Die Procedure liest `msdb.dbo.backupset` und `restorehistory` im aktuellen Metadatenkontext; historische Lücken und fehlende Rechte bleiben als eingeschränkte Evidenz sichtbar.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @HistoryDays | int | nein | 35 |
| @MitRestoreEvidence | bit | nein | 1 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max)=NULL; Default: NULL. Die optionale Liste ist eine durch Pipezeichen getrennte Folge einteiliger SQL-Namen. Der Parser behandelt | innerhalb von [...] als Namenstext, ]] als maskierte schließende Klammer und entfernt äußere Leerzeichen jedes Elements. Rohsegmente über 4000 UTF-16-Codeeinheiten und Namen über 128 Zeichen sind ungültig; mehrteilige SQL-Namen, ungültige Klammern, leere Elemente und nach SQL_Latin1_General_CP1_CS_AS doppelte Namen führen ebenfalls zu INVALID_PARAMETER. NULL, eine leere Zeichenfolge und ein nur aus Leerzeichen bestehender Wert werden vor dem Listenparser wie keine Liste behandelt und wählen alle für den Aufrufer sichtbaren, online befindlichen und zugänglichen Datenbanken; Systemdatenbanken bleiben ohne Opt-in ausgeschlossen. Nicht verfügbare explizite Namen erzeugen DATABASE_UNAVAILABLE, ohne Opt-in ausgeschlossene Systemnamen SYSTEM_DATABASE_EXCLUDED in der Warning-Tabelle; wenn solche Warnungen vorliegen, wird der Status AVAILABLE_LIMITED. Die Liste ist mit einem nicht-NULL Pattern unvereinbar. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0; Default: 0. Der Parameter wird als SQL-bit gebunden; numerische Null wird 0, jeder numerische Nichtnullwert wird 1, NULL bleibt NULL. Nach der Bindung sind nur 0 und 1 gültig: NULL führt beim Kandidatenhelfer zu INVALID_PARAMETER. 0 lässt Systemdatenbanken aus, 1 schließt sie in die Kandidatenauswahl ein. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. Das Eingabefeld ist nvarchar(4000) und nimmt höchstens 4000 UTF-16-Codeeinheiten an. NULL bedeutet Modus NONE; eine leere oder nur aus Leerzeichen bestehende Eingabe ist ungültig, und ein Inhalt, der nach einem Präfix leer bleibt, ebenfalls. Der Parser trimmt äußere Leerzeichen, erkennt LIKE:, REGEX: und REGEXI: ohne Beachtung der Großschreibung und entfernt danach das Präfix; der verbleibende Inhalt wird nicht erneut getrimmt. Ohne Präfix gilt LIKE. LIKE wertet das Pattern mit SQL_Latin1_General_CP1_CS_AS case-sensitiv aus; exakte Datenbanknamen werden ebenfalls mit dieser Collation verglichen; REGEX nutzt Flag c und REGEXI Flag i. REGEX und REGEXI benötigen SQL Server 2025 sowie Compatibility Level 170 der Installationsdatenbank. Ein nicht-NULL Pattern kann nicht zusammen mit einer wirksamen exakten Datenbankliste verwendet werden. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed bit=0; Default: 0. Der Parameter wird als SQL-bit gebunden: numerische Null wird 0, jeder numerische Nichtnullwert wird 1, NULL bleibt NULL. NULL ist beim Kandidatenhelfer ungültig. Der Aufrufer übergibt @AnalysisClass ausdrücklich als NULL; dadurch wird kein Analyseklassen- oder High-Impact-Gate ausgelöst. Eine gebundene 1 erteilt keine zusätzliche Berechtigung. Bei ausgelassenem Argument gilt der angegebene Default.

**@HistoryDays:** @HistoryDays int=35; Default: 35. Zulässig sind ganze SQL-int-Werte von 1 bis 3650 Tagen. Die Eingabe wird vor Prozedureintritt an int gebunden; Textwerte durchlaufen die SQL-Typkonvertierung, Leertext hat keinen eigenen Sonderdefault. NULL ergibt nach Hilfe und TABLE-Preflight, aber vor Kandidatenauswahl und Backupabfrage INVALID_PARAMETER mit IsPartial=1 und leeren Fachmengen. Die Backuphistorie wird bei gültigem Wert mit DATEADD(DAY, -@HistoryDays, GETDATE()) auf backup_finish_date gefiltert; GETDATE verwendet die lokale Serverzeit. Der jüngste nicht-copy-only Full je Kandidat wird per separater OR-Bedingung unabhängig vom Fenster einbezogen. Ein zu kurzes Fenster kann weitere benötigte Full-/Diff-/Logevidenz ausschließen. Das Zeitfenster begrenzt Backupsets; die optionale Restorehistory-Abfrage wird nicht durch @HistoryDays begrenzt. msdb-Historie kann bereinigt oder unvollständig sein; ein scheinbares Gap kann deshalb auch aus nicht sichtbarer Historie resultieren. Sichtbare Metadatenkonsistenz beweist weder vorhandene/lesbare Medien noch eine erfolgreiche Wiederherstellung. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitRestoreEvidence:** @MitRestoreEvidence bit=1; Default: 1. Der SQL-bit-Parameter ist standardmäßig 1; nach Bindung aktiviert nur 1 die zusätzliche Auswertung von msdb.dbo.restorehistory und die Bewertung fehlender Restoreevidenz. Gebundene 0 und NULL deaktivieren beides; NULL wird nicht als ungültiger Parameter geprüft. Die Restorehistory-Abfrage ist für ausgewählte Datenbanken nicht nach @HistoryDays zeitlich eingeschränkt. Ein msdb-Restoreeintrag ist kein Nachweis eines erfolgreichen Test-Restores. Die Abfrage gruppiert nach destination_database_name und nimmt MAX(restore_date); sie belegt deshalb nur den letzten lokalen msdb-Eintrag für das Ziel, keine Zuordnung zu einem konkreten Backupset, Medienverfügbarkeit, Entschlüsselbarkeit oder erfolgreiche Wiederherstellung. SQL Server bindet das Argument vor Eintritt an bit: 0 ergibt 0, ein konvertierbarer numerischer Nichtnullwert ergibt 1, NULL bleibt NULL; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=1000; Default: 1000. Der int-Parameter akzeptiert 0 bis 2147483647; negative Werte sind ungültig. NULL und 0 werden vor der Ausgabe in das unbegrenzte bigint-Limit 9223372036854775807 überführt. Ein positives Limit entfernt nach vollständigem msdb-Scan und Kettenaggregation zusätzliche Summaryzeilen nach DatabaseId sowie Backupzeilen nach Abschlusszeit und Backupset-ID absteigend. Das Limit kürzt weder den Scan noch die vollständig berechneten Summaryzähler oder die Warning-Tabelle und setzt kein Truncation- oder Partial-Flag. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Nach COALESCE mit leerem Text, Trimmen und Großschreibung sind RAW, CONSOLE, TABLE und NONE zulässig. CONSOLE und TABLE werden für die Modusprüfung zunächst auf NONE normalisiert, danach aber über getrennte Adapter ausgeführt. RAW liefert vier Resultsets: Status-/Kontextzeile, Summary, Backups und Warnings. CONSOLE liefert nur Summary über InternalEmitConsoleResult; eine leere Summary ergibt dort eine erklärende Zeile, ohne separaten Status- oder Warning-Datensatz. TABLE schreibt nur das Resultset summary in die benannte lokale Zieltabelle und wirft bei einem Schreibfehler. NONE erzeugt keine fachlichen Resultsets. NULL, leer und andere Werte sind ungültig. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Ein nichtleerer Wert ist ausschließlich bei @ResultSetArt=TABLE zulässig; andernfalls wirft der Code vor Hilfe Fehler 51011. TABLE erwartet vor Hilfe ein gültiges JSON-Objekt mit genau dem case-sensitiven Schlüssel summary und einem JSON-String als Zieltabellennamen. Zulässig ist nur eine vorhandene lokale #Temp-Tabelle, nicht ##, nicht #Monitor*, mit höchstens 116 Zeichen. Das Ziel muss leer sein und genau eine Dummy-Seed-Spalte besitzen; der Schreibhelfer passt eine leere Zieltabelle an die native Struktur von summary an. Bei TABLE fehlt die Zuordnung, ist das JSON ungültig oder ist das Ziel nicht verfügbar, nicht leer oder anders strukturiert, schlägt der Preflight fehl. Bei Nicht-TABLE-Modi sind NULL, leerer oder nur aus Leerzeichen bestehender Wert zulässig. Resultset-Schlüssel und JSON-Stringwerte dürfen nicht doppelt vorkommen; zusätzliche Schlüssel, globale ##-Ziele und reservierte #Monitor-Präfixe sind unzulässig. Der Preflight prüft das Ziel unter anderem durch temporäres Hinzufügen und Entfernen einer Marker-Spalte. Ein ungültiges Mapping kann vor Hilfe Fehler 51011 auslösen; der spätere TABLE-Writer kann nach der Status-OUTPUT-Zuweisung Fehler 51010 werfen. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. Der SQL-bit-Parameter wird vor der Ausführung konvertiert; nur der gebundene Wert 1 erzeugt JSON, während 0 und NULL überspringen. Das Dokument hat ein meta-Objekt und die Arrays summary, backups und warnings. summary und backups spiegeln das nach @MaxZeilen begrenzte Material; warnings bleiben ungekürzt. meta enthält resultName, schemaVersion, generatedAtUtc, statusCode, isPartial und historyDays und lässt NULL-Eigenschaften weg. Die drei Arrays verwenden INCLUDE_NULL_VALUES; Fehlernummer und Fehlermeldung werden separat über die Fehler-OUTPUTs beziehungsweise RAW bereitgestellt. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. nvarchar(max) OUTPUT wird beim Eintritt auf NULL gesetzt. Nur wenn @JsonErzeugen=1 und der Hilfezweig nicht vorher zurückkehrt, wird ein JSON-Dokument mit meta-Objekt sowie summary-, backups- und warnings-Arrays zugewiesen. Bei fehlender JSON-Anforderung bleibt der OUTPUT-Wert NULL. Binden Sie eine Variable des deklarierten Typs mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. Der SQL-bit-Parameter wird in der Procedure weder gelesen noch zur Ausgabe verwendet. Die Signatur setzt ihn auf 1; auch ein gebundenes NULL oder 0 ändert den Ausgabepfad nicht. SQL Server bindet das Argument vor Eintritt an bit: 0 ergibt 0, ein konvertierbarer numerischer Nichtnullwert ergibt 1, NULL bleibt NULL; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. Nur der gebundene bit-Wert 1 gibt die Hilfe mit PRINT aus und kehrt zurück. Numerische Nichtnullwerte werden vor Eintritt zu bit 1 konvertiert; 0 aktiviert die Hilfe nicht. NULL bleibt NULL und aktiviert IF @Hilfe=1 ebenfalls nicht. Modusnormalisierung sowie TABLE-/ResultTablesJson-Vorprüfung liegen vor diesem Rücksprung. Der TABLE-Preflight kann die lokale Zieltabelle bereits durch temporäres Hinzufügen und Entfernen einer Marker-Spalte prüfen. Die Status-, Partial- und Fehler-OUTPUTs bleiben im Hilfezweig auf ihren Eingangs-/Bindungswerten; @Json wurde zuvor bereits auf NULL gesetzt. Bei ausgelassenem Argument gilt der angegebene Default.

**@StatusCodeOut:** @StatusCodeOut varchar(40)=NULL OUTPUT; Default: NULL. Empfängt am gemeinsamen Zuweisungspunkt vor JSON und Resultsets genau einen dieser acht Statuswerte: AVAILABLE, wenn ohne Kandidatenwarnungen kein abweichender Summarybefund vorliegt; CHAIN_METADATA_CONSISTENT und TEMPDB_NOT_APPLICABLE sind damit vereinbar. INVALID_PARAMETER bezeichnet eine ungültige Modus-, Historien-, Zeilen- oder Kandidatenauswahl. INTERNAL_ERROR bezeichnet einen Fehler bei der defensiven Kandidatentabellenprobe, ohne die Ursache ausschließlich auf ein falsches Schema festzulegen. UNAVAILABLE_FEATURE bezeichnet einen nicht unterstützten Regex-Engine-/Compatibility-Pfad. AVAILABLE_LIMITED hat bei vorhandenen Kandidatenwarnungen Vorrang. AVAILABLE_WITH_FINDING bezeichnet ohne Kandidatenwarnungen mindestens einen Summarycode außerhalb von CHAIN_METADATA_CONSISTENT und TEMPDB_NOT_APPLICABLE. DENIED_PERMISSION ist die Codeklassifikation des Analyse-CATCH für Fehler 229, 371 oder 916, keine unabhängige Ursachendiagnose. ERROR_HANDLED bezeichnet andere im Analyse-CATCH erfasste SQL-Fehler. @AnalysisClass=NULL überspringt die Analyseklassengates. Bei Hilfe oder frühem Preflight-THROW bleibt der gebundene Eingangswert unverändert. Vom TABLE-Writer behandelte Schreibfehler können nach der OUTPUT-Zuweisung Fehler 51010 auslösen und ändern den bereits zugewiesenen Status nicht. Binden Sie eine Variable des deklarierten Typs mit @StatusCodeOut=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@IsPartialOut:** @IsPartialOut bit=NULL OUTPUT; Default: NULL. bit OUTPUT wird im regulären Ablauf gemeinsam mit Status vor JSON und Resultsets zugewiesen; in HELP und bei einem früheren Preflight-THROW bleibt der gebundene OUTPUT-Eingangswert bestehen. Der interne Analyseflag wird mit 0 initialisiert; der Signatur-Default des OUTPUT-Arguments ist NULL. Die Hauptparameterprüfung für @HistoryDays, @MaxZeilen und @ResultSetArt setzt bei Fehlern 1; Kandidatenwarnungen und behandelte Analysefehler setzen ebenfalls 1. Ein Fehlerstatus des Kandidatenhelfers (INVALID_PARAMETER, UNAVAILABLE_FEATURE oder INTERNAL_ERROR) kann dagegen mit Partial=0 ankommen. Ein positives @MaxZeilen-Limit oder Ausgabeabschneiden setzt es nicht auf 1. Binden Sie eine Variable des deklarierten Typs mit @IsPartialOut=@Variable OUTPUT. SQL Server bindet das Argument vor Eintritt an bit: 0 ergibt 0, ein konvertierbarer numerischer Nichtnullwert ergibt 1, NULL bleibt NULL; Bindungsfehler treten vor dem Prozedurcode auf. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorNumberOut:** @ErrorNumberOut int=NULL OUTPUT; Default: NULL. int OUTPUT wird am gemeinsamen regulären Zuweisungspunkt befüllt; in HELP und bei einem früheren Preflight-THROW bleibt der gebundene OUTPUT-Eingangswert bestehen. Der Analyse-CATCH setzt ihn auf die abgefangene SQL-Fehlernummer; ohne solchen CATCH bleibt er NULL. Binden Sie eine Variable des deklarierten Typs mit @ErrorNumberOut=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048)=NULL OUTPUT; Default: NULL. nvarchar(2048) OUTPUT wird am gemeinsamen regulären Zuweisungspunkt befüllt; in HELP und bei einem früheren Preflight-THROW bleibt der gebundene OUTPUT-Eingangswert bestehen. Er enthält eine Validierungs-, Kandidaten- oder Analysefehlermeldung und bleibt bei erfolgreicher Auswertung NULL. Binden Sie eine Variable des deklarierten Typs mit @ErrorMessageOut=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| summary | 1 | 1 | [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [RecoveryModelDesc] nvarchar(60) NULL , [LatestFullFinish] datetime NULL , [LatestMatchingDifferentialFinish] datetime NULL , [LatestLogFinish] datetime NULL , [LogBackupCountInWindow] bigint NOT NULL , [LogGapCountInWindow] bigint NOT NULL , [RecoveryForkTransitionCount] bigint NOT NULL , [DamagedBackupCount] bigint NOT NULL , [BackupWithoutChecksumCount] bigint NOT NULL , [LatestRestoreDate] datetime NULL , [FindingCode] varchar(100) NOT NULL , [FindingSeverity] varchar(16) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_BackupChainAnalysis] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

msdb-Historie kann bereinigt oder unvollständig sein. Nur ein erfolgreicher Test-Restore beweist die Wiederherstellbarkeit.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_BackupChainAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Die Procedure bewertet Backupketten und Wiederherstellbarkeitsevidenz aus msdb.
Datenquellen : msdb.dbo.backupset und msdb.dbo.restorehistory.
Methodik     : Prüft Full-/Differentialbasis, Log-LSN-Übergänge,
               Recovery-Fork-Wechsel, Prüfsummen, Schadensflags und Restorebeleg.
Grenzen      : msdb-Historie kann bereinigt oder unvollständig sein. Nur ein
               erfolgreicher Test-Restore beweist die Wiederherstellbarkeit.
Datenschutz  : Liest keine Medienpfade, Benutzernamen oder Backupinhalte.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_BackupChainAnalysis
Analysiert Backup- und Restoremetadaten aus msdb für die ausgewählten Datenbanken.
Das Historienfenster begrenzt die sichtbare Kettenevidenz; der jüngste nicht-copy-only Full wird zusätzlich berücksichtigt.
Restorehistorie ist nur ein Metadatenbeleg; die Wiederherstellbarkeit ist durch einen erfolgreichen Test-Restore zu prüfen.
Beispiel 1: EXEC [monitor].[USP_BackupChainAnalysis] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HistoryDays=35, @MitRestoreEvidence=0, @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 3: DECLARE @BackupChainJson nvarchar(max), @BackupChainStatus varchar(40), @BackupChainPartial bit, @BackupChainError int, @BackupChainMessage nvarchar(2048); EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HistoryDays=35, @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@BackupChainJson OUTPUT, @StatusCodeOut=@BackupChainStatus OUTPUT, @IsPartialOut=@BackupChainPartial OUTPUT, @ErrorNumberOut=@BackupChainError OUTPUT, @ErrorMessageOut=@BackupChainMessage OUTPUT; SELECT @BackupChainStatus AS [StatusCode], @BackupChainPartial AS [IsPartial], @BackupChainError AS [ErrorNumber], @BackupChainMessage AS [ErrorMessage], @BackupChainJson AS [Json];
Beispiel 4: CREATE TABLE #BackupChainAnalysis_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HistoryDays=35, @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"summary":"#BackupChainAnalysis_HelpExample"}'; SELECT * FROM #BackupChainAnalysis_HelpExample; DROP TABLE #BackupChainAnalysis_HelpExample; END TRY BEGIN CATCH DROP TABLE #BackupChainAnalysis_HelpExample; THROW; END CATCH;
Beispiel 5: EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNamePattern=N'like:ExampleDatabase%', @HistoryDays=35, @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 6: EXEC [monitor].[USP_BackupChainAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HistoryDays=7, @MitRestoreEvidence=1, @MaxZeilen=100, @ResultSetArt='RAW';
```

