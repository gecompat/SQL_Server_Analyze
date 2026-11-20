---
skill_format_version: "1.0.0"
name: "monitor.USP_BackupRecovery"
schema_name: "monitor"
object_name: "USP_BackupRecovery"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure bewertet Backup-Aktualität und Restore-Historie je ausgewählter sichtbarer Datenbank."
source_path: "Code/07_Infrastructure/050_USP_BackupRecovery.sql"
---

# monitor.USP_BackupRecovery

## Zweck und Einsatz

Die Procedure bewertet Backup-Aktualität und Restore-Historie je ausgewählter sichtbarer Datenbank.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_BackupRecovery] im vorgesehenen Datenbankkontext. Die Procedure liest `msdb`-Backupset, Medien- und Restorehistorie sowie Konfiguration. Ein lesbarer Ausschnitt bestätigt weder vollständige Medien noch eine gelungene Restoreprobe.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @FullWarnHours | int | nein | 48 |
| @DiffWarnHours | int | nein | 24 |
| @LogWarnMinutes | int | nein | 30 |
| @MitRestoreHistory | bit | nein | 1 |
| @MaxZeilen | int | nein | 5000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames nvarchar(max)=NULL; Default: NULL. NULL sowie nach Trim leere Eingaben wählen alle für den Aufrufer sichtbaren, online befindlichen und zugänglichen Datenbanken, standardmäßig ohne Systemdatenbanken. Andernfalls wird eine Pipe-Liste einteiliger SQL-Datenbanknamen verarbeitet; äußere Leerzeichen je Element werden entfernt. Bracket-quotierte Elemente erlauben ein wörtliches Pipe-Zeichen und maskieren eine schließende Klammer als `]]`. Jedes Element muss ein gültiger höchstens 128 Zeichen langer SQL-Name sein; leere, doppelte, fehlerhaft geklammerte, mehrteilige oder ungültige Namen führen zu `INVALID_PARAMETER`. Eine explizite Liste kann nicht zusammen mit einem Pattern verwendet werden. Die Auswahl wird nicht vorab begrenzt; Namen, die nicht im zugänglichen Kandidatenscope liegen, liefern keine Kandidaten. Gültige explizite Namen außerhalb des zugänglichen Kandidatenscopes erzeugen Warnzeilen mit DATABASE_UNAVAILABLE beziehungsweise SYSTEM_DATABASE_EXCLUDED und führen zu AVAILABLE_LIMITED mit IsPartial=1; sie werden nicht stillschweigend ignoriert. Bei ausgelassenem Argument gilt der angegebene Default.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit=0; Default: 0. 0 schließt die vier Systemdatenbanken anhand ihrer database_id aus; 1 nimmt zugängliche, online befindliche Systemdatenbanken in denselben Kandidatenpfad auf. NULL ist ungültig und führt über die Kandidatenvalidierung zu `INVALID_PARAMETER`. Diese Procedure übergibt `@AnalysisClass = NULL`; deshalb aktiviert dieser Schalter kein High-Impact-Analyse-Gate. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000)=NULL; Default: NULL. NULL bedeutet kein Pattern; sonst werden äußere Leerzeichen entfernt und der Wert als Pattern ausgewertet. Zulässige Präfixe sind `LIKE:`, `REGEX:` und `REGEXI:` (Präfixerkennung ohne Beachtung der Groß-/Kleinschreibung); ohne Präfix gilt LIKE. `REGEX:` verlangt case-sensitive Regex, `REGEXI:` case-insensitive Regex; `LIKE:` entfernt nur das Präfix und verwendet SQL-LIKE-Musterzeichen. Der Inhalt nach dem Präfix darf nicht leer sein. Die maximale Eingabelänge beträgt 4000 UTF-16-Codeeinheiten. Ein Pattern ist mit einer exakten Namensliste unzulässig. Jedes nicht-NULL Pattern, das nach Trim beziehungsweise Präfixentfernung leer ist, sowie die Kombination mit einer exakten Liste setzen den Status `INVALID_PARAMETER`. Für `REGEX` und `REGEXI` benötigt die Installationsinstanz SQL Server 2025 und Compatibility Level 170; andernfalls meldet der Kandidatenhelfer `UNAVAILABLE_FEATURE`. Bei ausgelassenem Argument gilt der angegebene Default.

**@HighImpactConfirmed:** @HighImpactConfirmed aktiviert für diese Procedure keinen Analysepfad. Ein Status oder eine msdb-Historyzeile belegt weder Dateiexistenz noch erfolgreiche Wiederherstellbarkeit.

**@FullWarnHours:** @FullWarnHours int=48; Default: 48. Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 2147483647. Ganzzahlige Stundenschwelle für `FULL_TOO_OLD`; Werte kleiner als 1 sind ungültig. NULL ist `INVALID_PARAMETER` und liefert leere fachliche Ergebnismengen. Die Eingabe wird als `int` gebunden; Leertext hat keinen Sonderdefault und unterliegt vor Eintritt der SQL-Konvertierung, danach der Bereichsprüfung. Die Schwelle begrenzt keine gelesene msdb-Historie und ist kein RPO. Der Vergleich verwendet DATEDIFF(HOUR, ..., GETDATE()) > @FullWarnHours; DATEDIFF zählt Stundengrenzen. Bei ausgelassenem Argument gilt der angegebene Default.

**@DiffWarnHours:** @DiffWarnHours int=24; Default: 24. Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 2147483647. Ganzzahlige Stundenschwelle für den informativen Status `DIFF_OLD_INFORMATIONAL`; Werte kleiner als 1 sind ungültig. NULL ist `INVALID_PARAMETER` und liefert leere fachliche Ergebnismengen. Die Eingabe wird als `int` gebunden; Leertext hat keinen Sonderdefault und unterliegt vor Eintritt der SQL-Konvertierung, danach der Bereichsprüfung. Die Schwelle begrenzt keine gelesene Historie und ist kein RPO. Der Vergleich verwendet DATEDIFF(HOUR, ..., GETDATE()) > @DiffWarnHours; DATEDIFF zählt Stundengrenzen. Bei ausgelassenem Argument gilt der angegebene Default.

**@LogWarnMinutes:** @LogWarnMinutes int=30; Default: 30. Zulässige nicht-NULL Werte sind ganze Zahlen von 1 bis 2147483647. Ganzzahlige Minutenschwelle für `LOG_TOO_OLD`; Werte kleiner als 1 sind ungültig. NULL ist `INVALID_PARAMETER` und liefert leere fachliche Ergebnismengen. Die Eingabe wird als `int` gebunden; Leertext hat keinen Sonderdefault und unterliegt vor Eintritt der SQL-Konvertierung, danach der Bereichsprüfung. Der Vergleich verwendet `DATEDIFF(MINUTE, ..., GETDATE())`; die Schwelle begrenzt keine msdb-Historie und ist kein RPO. Bei ausgelassenem Argument gilt der angegebene Default.

**@MitRestoreHistory:** @MitRestoreHistory bit=1; Default: 1. 0 lässt die Abfrage der msdb-Restorehistorie aus; 1 liest die Restorehistorie für ausgewählte Datenbanken. NULL verhält sich in `IF @MitRestoreHistory = 1` wie nicht aktiviert. Dieser Schalter betrifft nur Restoreausgabe und entfernt weder Backup- noch Freshnessauswertung. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int=5000; Default: 5000. Eine positive Grenze ist eine ganze Zeilenzahl von 1 bis 2147483647. Negative Werte führen zu `INVALID_PARAMETER`; NULL oder 0 werden in eine unbegrenzte Obergrenze umgewandelt. Positive Werte begrenzen Freshness, Backup-, Kompressions-Backupset- und Restoreausgabe jeweils separat; die kleinen serverweiten Konfigurations- und Capability-Einträge bleiben sichtbar. Die Freshnessgrenze wird nach der Bewertung angewandt. Das Limit beschränkt nicht die zuvor geprüfte Backupsetmenge für Aggregation und Freshness und ist kein gemeinsames Gesamtlimit. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16)='CONSOLE'; Default: 'CONSOLE'. Nach `LTRIM`/`RTRIM` und Umwandlung in Großbuchstaben sind ausschließlich `CONSOLE`, `RAW`, `TABLE` und `NONE` zulässig; NULL und andere Texte führen zu `INVALID_PARAMETER`. `CONSOLE` liefert ausschließlich eine formatierte Freshnessausgabe ohne zusätzliches Modulstatus-Resultset; bei leerer Menge wird eine verständliche Hinweiszeile ausgegeben, `RAW` liefert die technischen Resultsets, `TABLE` schreibt ausschließlich die benannten lokalen Ziele, und `NONE` unterdrückt Resultsets. Für `CONSOLE` und `TABLE` wird der interne Resultsetpfad auf NONE gestellt, bevor die jeweilige Ausgabeadapterlogik läuft. Die Auswahl ist unabhängig von JSON-OUTPUT. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL; Default: NULL. Nur bei `TABLE` darf dieser Wert nicht leer sein: Er muss ein JSON-Objekt mit Stringwerten für die case-sensitiven Schlüssel `freshness` und/oder `compression` enthalten; jeder Wert bezeichnet eine vorhandene lokale `#`-Temp-Tabelle. Ziele müssen leer sein und genau eine Seed-Spalte besitzen; doppelte/unbekannte Schlüssel, doppelte Ziele, globale oder reservierte `#Monitor`-Ziele, falsche Namen/Schemas oder ein ungültiges Mapping lösen den TABLE-Preflightfehler 51011 aus. Der Preflight prüft und verändert Ziele vorübergehend durch Hinzufügen und Entfernen einer Marker-Spalte. Bei allen anderen Ausgabearten ist NULL oder ein Leer-/Whitespacewert zulässig; ein nichtleeres Mapping löst 51011 aus. Das Mapping ändert keine fachlichen Backupdaten. Die Zielnamen dürfen höchstens 116 Zeichen lang sein. Zielnamen-Duplikate werden ohne Beachtung der Groß-/Kleinschreibung geprüft; Resultset-Schlüssel müssen dagegen exakt einschließlich Groß-/Kleinschreibung stimmen. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit=0; Default: 0. 1 erzeugt das JSON-Dokument und weist es `@Json` zu; 0 oder NULL lässt es bei der anfänglichen Rücksetzung auf NULL. Das Root-Objekt enthält `meta` (u. a. resultName, schemaVersion, generatedAtUtc, statusCode, isPartial, requestedMaxRows, errorNumber und errorMessage), `freshness`, `backups`, `compression`, `restores` und `warnings`. JSON-Erzeugung ist unabhängig von der gewählten Resultsetart. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max)=NULL OUTPUT; Default: NULL. OUTPUT-Empfangsparameter für das erzeugte JSON-Dokument. Die Procedure setzt ihn zu Beginn immer auf NULL; ein JSON-Text wird nur bei `@JsonErzeugen = 1` zugewiesen. Inhalt und Schlüssel stehen im Vertrag von `@JsonErzeugen`; bei HELP und bei deaktivierter JSON-Erzeugung bleibt der OUTPUT-Wert NULL. Binden Sie eine nvarchar(max)-Variable mit @Json=@Variable OUTPUT. Ohne OUTPUT-Bindung wird kein Wert an eine aufrufende Variable zurückgegeben.

**@PrintMeldungen:** @PrintMeldungen bit=1; Default: 1. 1 erlaubt die vorgesehenen Informations-/Warnmeldungen über `RAISERROR` mit Severity 10; 0 unterdrückt diese Meldungen. NULL wird durch die Prüfung `IF @PrintMeldungen = 1` ebenfalls nicht aktiviert. Der Schalter unterdrückt weder Resultsets noch JSON und ändert keinen Status. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit=0; Default: 0. 1 gibt den Hilfetext mit `PRINT` aus und kehrt vor Kandidatensuche, Backup-/Restoreabfragen und Ausgabeverarbeitung zurück; 0 führt den normalen Ablauf aus. NULL wird nicht als aktiviert behandelt. Die TABLE-Zielvorprüfung liegt vor dieser Verzweigung: Bei `TABLE` kann deshalb bereits vorher Mapping validiert und eine Marker-Spalte temporär hinzugefügt/entfernt werden. HELP ist kein Backup-, Restore- oder Agent-Aufruf. SQL Server bindet das Argument vor Eintritt an bit: 0 wird 0, ein konvertierbarer numerischer Wert ungleich 0 wird 1. Andere Literalformen unterliegen der SQL-Typkonvertierung; Bindungsfehler treten vor dem Prozedurcode auf. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

RAW: Modulstatus, Datenbankstatus, Backup-Aktualität, Backup-Historie, Kompressionsevidenz und Restore-Historie.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| freshness | 1 | 1 | [DatabaseName] sysname , [StateDesc] nvarchar(60) , [RecoveryModelDesc] nvarchar(60) , [LastFullFinish] datetime , [FullAgeMinutes] int , [LastDiffFinish] datetime , [DiffAgeMinutes] int , [LastLogFinish] datetime , [LogAgeMinutes] int , [LastCopyOnlyFullFinish] datetime , [BackupStatus] varchar(100) |
| compression | 1 | 1 | [EvidenceScope] varchar(32) NOT NULL , [DatabaseName] sysname NULL , [BackupSetId] int NULL , [BackupFinishDate] datetime NULL , [ConfigurationName] sysname NULL , [ConfiguredValue] int NULL , [AlgorithmName] nvarchar(32) NULL , [SourceStatus] varchar(40) NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL , [CollectionTimeUtc] datetime2(3) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_BackupRecovery] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_BackupRecovery

Die Hilfe beendet die fachliche Auswertung vor Kandidaten- und Backup-/Restoreabfragen; der TABLE-Preflight für lokale Zieltabellen läuft davor.

Der normale Pfad liest sichtbare, online zugängliche Datenbankmetadaten sowie msdb-Backup-, Medien- und optional Restorehistorie. Er führt keine Sicherung, Wiederherstellung oder Agentaktion aus.

Warnschwellen klassifizieren Freshness und schneiden die gelesene Historie nicht zeitlich ab. @MaxZeilen begrenzt die vorgesehenen Ergebnismengen separat; NULL oder 0 bedeutet unbegrenzt.

Beispiel 1: EXEC [monitor].[USP_BackupRecovery] @Hilfe=1;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_BackupRecovery
Version      : 2.1.0
Stand        : 2026-10-10
Typ          : Stored Procedure
Zweck        : Die Procedure bewertet Backup-Aktualität und Restore-Historie je ausgewählter
               sichtbarer Datenbank.
SQL-Version  : SQL Server 2019 oder neuer.
Filter       : @DatabaseNames als bracket-aware Pipe-Liste oder alternativ
               @DatabaseNamePattern mit LIKE/regex/regexi.
Resultsets   : RAW: Modulstatus, Datenbankstatus, Backup-Aktualität,
               Backup-Historie, Kompressionsevidenz und Restore-Historie.
               CONSOLE: Backup-Aktualität. TABLE: freshness und/oder compression.
               NONE: keine Resultsets.
JSON         : meta, freshness, backups, compression, restores, warnings.
Änderungen   : 2.1.0 - Getrennte Server-, Capability- und Backupset-
                         Kompressionsevidenz.
               2.0.0 - Mehrfachfilter, Patternvertrag und Ausgabeadapter.
               1.0.0 - Erstfassung Phase 6.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_BackupRecovery
Die Hilfe beendet die fachliche Auswertung vor Kandidaten- und Backup-/Restoreabfragen; der TABLE-Preflight für lokale Zieltabellen läuft davor.
Der normale Pfad liest sichtbare, online zugängliche Datenbankmetadaten sowie msdb-Backup-, Medien- und optional Restorehistorie. Er führt keine Sicherung, Wiederherstellung oder Agentaktion aus.
Warnschwellen klassifizieren Freshness und schneiden die gelesene Historie nicht zeitlich ab. @MaxZeilen begrenzt die vorgesehenen Ergebnismengen separat; NULL oder 0 bedeutet unbegrenzt.
Beispiel 1: EXEC [monitor].[USP_BackupRecovery] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N'[ExampleDatabase]', @MitRestoreHistory=0, @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 3: DECLARE @BackupRecoveryJson nvarchar(max); EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@BackupRecoveryJson OUTPUT; SELECT @BackupRecoveryJson AS [Json];
Beispiel 4: CREATE TABLE #BackupRecovery_Freshness_HelpExample ([Seed] int NULL); CREATE TABLE #BackupRecovery_Compression_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"freshness":"#BackupRecovery_Freshness_HelpExample","compression":"#BackupRecovery_Compression_HelpExample"}'; SELECT * FROM #BackupRecovery_Freshness_HelpExample; SELECT * FROM #BackupRecovery_Compression_HelpExample; DROP TABLE #BackupRecovery_Compression_HelpExample; DROP TABLE #BackupRecovery_Freshness_HelpExample; END TRY BEGIN CATCH DROP TABLE #BackupRecovery_Compression_HelpExample; DROP TABLE #BackupRecovery_Freshness_HelpExample; THROW; END CATCH;
Beispiel 5: EXEC [monitor].[USP_BackupRecovery] @DatabaseNamePattern=N'like:ExampleDatabase%', @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 6: EXEC [monitor].[USP_BackupRecovery] @DatabaseNames=N'[ExampleDatabase]', @FullWarnHours=48, @DiffWarnHours=24, @LogWarnMinutes=30, @MitRestoreHistory=1, @MaxZeilen=100, @ResultSetArt='RAW';
```

