---
skill_format_version: "1.0.0"
name: "monitor.USP_MaintenanceOperations"
schema_name: "monitor"
object_name: "USP_MaintenanceOperations"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert eine korrelierte, rein lesende Sicht auf laufende Wartungsanforderungen, resumierbare Indexoperationen, ADR/PVS und explizit gewählte Jobs."
source_path: "Code/07_Infrastructure/130_USP_MaintenanceOperations.sql"
---

# monitor.USP_MaintenanceOperations

## Zweck und Einsatz

Liefert eine korrelierte, rein lesende Sicht auf laufende Wartungsanforderungen, resumierbare Indexoperationen, ADR/PVS und explizit gewählte Jobs.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_MaintenanceOperations]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[TVF_ParseStringList]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `[sys].[index_resumable_operations]`, `[sys].[tables]`, `[sys].[schemas]`, `[sys].[indexes]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @JobNames | nvarchar(max) | nein | NULL |
| @JobNamePattern | nvarchar(4000) | nein | NULL |
| @NurProblematisch | bit | nein | 0 |
| @ResumablePausedWarnMinutes | int | nein | 60 |
| @BlockedWarnMs | bigint | nein | 5000 |
| @PvsWarnMb | decimal(19,2) | nein | 1024 |
| @AbortedTransactionsWarnCount | bigint | nein | 1 |
| @MaxZeilen | int | nein | 1000 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger SQL-Namen. Klammern schützen enthaltene Pipe-Zeichen. ]] maskiert eine schließende Klammer. Äußere Segmentleerzeichen werden entfernt. Ungültige Elemente werden abgelehnt. NULL, Leertext und reine Leerzeichen bedeuten keine exakte Einschränkung. Eine wirksame Liste darf nicht mit DatabaseNamePattern kombiniert werden.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit. Default ist 0. 0 schließt Systemdatenbanken aus. 1 erlaubt ihre Einbeziehung in Kandidaten. Ändert nicht die separaten Ausschlüsse fest kodierter Datenbanken/Quellen. NULL wird als ungültiger Bit-Wert abgelehnt.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert das Muster. Ohne Präfix oder mit LIKE: gilt SQL LIKE mit % und _. REGEX: berücksichtigt Groß- und Kleinschreibung, REGEXI: ignoriert sie. Regex benötigt SQL Server 2025 und Compatibility Level 170. Leertext ist ungültig. Nicht mit wirksamer exakter Liste kombinieren.

**@HighImpactConfirmed:** @HighImpactConfirmed bit. Default ist 0. 0 bestätigt keinen geschützten Pfad. 1 bestätigt einen tatsächlich aktivierten Pfad. NULL wird vom Candidate-Helper abgelehnt. Dieser Aufruf übergibt AnalysisClass=NULL und aktiviert damit keine zusätzliche Klassenprüfung.

**@JobNames:** @JobNames nvarchar(max). Default ist NULL. Pipe-Liste exakter einteiliger SQL-Namen. Klammern schützen enthaltene Pipe-Zeichen. ]] maskiert eine schließende Klammer. Äußere Segmentleerzeichen werden entfernt. Ungültige Elemente werden abgelehnt. Ohne wirksame Jobliste und ohne Jobmuster liest die Procedure keine Jobdaten. Eine nichtleere ungültige Liste ergibt INVALID_PARAMETER. Nicht mit JobNamePattern kombinieren.

**@JobNamePattern:** @JobNamePattern nvarchar(4000). Default ist NULL. NULL deaktiviert das Jobmuster. Ohne Präfix oder mit LIKE: gilt SQL LIKE. REGEX: und REGEXI: ergeben UNAVAILABLE_FEATURE. Leertext und reine Leerzeichen ergeben INVALID_PARAMETER. Nicht mit JobNames kombinieren.

**@NurProblematisch:** @NurProblematisch bit. Default ist 0. 0 zeigt alle bewerteten Befunde. 1 und NULL beschränken die vier fachlichen Mengen auf HIGH und MEDIUM. Die Filterung erfolgt nach dem Quellenlesen.

**@ResumablePausedWarnMinutes:** @ResumablePausedWarnMinutes int. Default ist 60. Warnschwelle in Minuten von 1 bis 525600. Zahlen außerhalb des Bereichs sind ungültig. NULL ergibt INVALID_PARAMETER und leere fachliche Ergebnismengen. Die Eingabe wird als int gebunden; Leertext hat keinen Sonderdefault und unterliegt vor der Procedure der SQL-Konvertierung, danach der Bereichsprüfung.

**@BlockedWarnMs:** @BlockedWarnMs bigint. Default ist 5000. Nichtnegative Warnschwelle in Millisekunden bei positiver BlockingSessionId. Negative Werte sind ungültig. NULL ergibt INVALID_PARAMETER und leere fachliche Ergebnismengen. Die Eingabe wird als bigint gebunden; Leertext hat keinen Sonderdefault und unterliegt vor der Procedure der SQL-Konvertierung, danach der Bereichsprüfung.

**@PvsWarnMb:** @PvsWarnMb decimal(19,2). Default ist 1024. Nichtnegative PVS-Warnschwelle in MB. Die Warnung setzt zusätzlich die Grenze für abgebrochene Transaktionen voraus. Negative Werte sind ungültig. NULL ergibt INVALID_PARAMETER und leere fachliche Ergebnismengen. Die Eingabe wird als decimal(19,2) gebunden; Leertext hat keinen Sonderdefault und unterliegt vor der Procedure der SQL-Konvertierung, danach der Bereichsprüfung.

**@AbortedTransactionsWarnCount:** @AbortedTransactionsWarnCount bigint. Default ist 1. Nichtnegative Mindestzahl abgebrochener Transaktionen für die gemeinsame PVS-Warnung. Negative Werte sind ungültig. NULL ergibt INVALID_PARAMETER und leere fachliche Ergebnismengen. Die Eingabe wird als bigint gebunden; Leertext hat keinen Sonderdefault und unterliegt vor der Procedure der SQL-Konvertierung, danach der Bereichsprüfung.

**@MaxZeilen:** @MaxZeilen int. Default ist 1000. Je fachliche Menge: NULL oder 0 unbegrenzt, positiv Top-N nach jeweiliger Sortierung, negativ INVALID_PARAMETER. Wirkt nach vollständiger Quellenmaterialisierung und NurProblematisch-Auswahl.

**@LockTimeoutMs:** @LockTimeoutMs int. Default ist 0. Nichtnegative Millisekunden für datenbanklokale Abfragen. 0 bedeutet NOWAIT. Negative Werte sind ungültig. NULL ergibt INVALID_PARAMETER und leere fachliche Ergebnismengen; ein dynamischer Abfragebatch wird dafür nicht aufgebaut. Die Eingabe wird als int gebunden; Leertext hat keinen Sonderdefault und unterliegt vor der Procedure der SQL-Konvertierung, danach der Bereichsprüfung.

**@ResultSetArt:** @ResultSetArt varchar(16). Default ist 'CONSOLE'. CONSOLE zeigt resumableOperations mit Beschriftung. RAW liefert Modulstatus, fachliche Mengen und Quellenstatus. TABLE exportiert ausschließlich resumableOperations. NONE unterdrückt die Datenresultsets. Rand-Leerzeichen und Groß- und Kleinschreibung werden normalisiert. NULL, Leertext und andere Werte sind ungültig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max). Default ist NULL. Nur mit ResultSetArt=TABLE erlaubt. JSON-Objekt mit genau dem Schlüssel resumableOperations und Zielnamen einer vorher angelegten, leeren lokalen #Temp-Tabelle mit genau einer Seed-Spalte. mapping wird vor fachlichen Quellen geprüft. NULL/leer bei TABLE führt zu Mapping-Fehler. Bei anderen Modi muss NULL/leer sein, sonst THROW 51011. Keine persistente Tabelle.

**@JsonErzeugen:** @JsonErzeugen bit. Default ist 0. 1 erzeugt JSON in Json unabhängig von der Ausgabeart. 0 und NULL erzeugen kein Dokument.

**@Json:** @Json nvarchar(max) OUTPUT. Default ist NULL. Ausgabeparameter. wird beim Eintritt auf NULL gesetzt und bei JSON-Erzeugung befüllt. Eingabewert wird ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. 1 aktiviert informative Statusmeldungen. 0 und NULL unterdrücken sie.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 zeigt die Hilfe nach der TABLE-Vorprüfung und beendet vor dem Quellzugriff. 0 und NULL setzen die normale Verarbeitung fort.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT. Default ist NULL. Ausgabeparameter. Statuscode des Laufs, z.B. AVAILABLE/AVAILABLE_LIMITED/INVALID_PARAMETER. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

**@IsPartialOut:** @IsPartialOut bit OUTPUT. Default ist NULL. Ausgabeparameter. 1 kennzeichnet unvollständige Evidenz, 0 vollständig im erreichbaren Scope. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT. Default ist NULL. Ausgabeparameter für erfasste SQL-Fehlernummer. NULL wenn keiner erfasst wurde. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT. Default ist NULL. Ausgabeparameter für erfasste Fehlermeldung. NULL ohne Fehler. Eingabe ignoriert. Für den Empfang eine Variable des deklarierten Typs mit OUTPUT binden.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| resumableOperations | 1 | 1 | [DatabaseId] int NOT NULL,[DatabaseName] sysname NOT NULL,[SchemaName] sysname NULL , [ObjectName] sysname NULL,[IndexName] sysname NULL,[PartitionNumber] int NULL , [StateDesc] nvarchar(60) NULL,[StartTime] datetime NULL,[LastPauseTime] datetime NULL , [TotalExecutionTimeMinutes] bigint NULL,[PercentComplete] real NULL,[PageCount] bigint NULL , [FindingCode] varchar(100) NOT NULL,[FindingSeverity] varchar(16) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_MaintenanceOperations] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Dauer und Pausenzustand sind Kontext, kein automatischer Defekt. Die Prozedur setzt nichts fort, bricht nichts ab und beendet nichts.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_MaintenanceOperations
Version      : 1.0.0
Stand        : 2026-07-18
Zweck        : Liefert eine korrelierte, rein lesende Sicht auf laufende
               Wartungsanforderungen, resumierbare Indexoperationen, ADR/PVS
               und explizit gewählte Jobs.
Datenschutz  : Liest keine SQL-Texte, Jobschritte, Befehle, Meldungen, Konten,
               Clientdaten, Wait-Ressourcen oder Objektdefinitionen.
Grenzen      : Dauer und Pausenzustand sind Kontext, kein automatischer Defekt.
               Die Prozedur setzt nichts fort, bricht nichts ab und beendet nichts.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_MaintenanceOperations
Beispiel 1. EXEC [monitor].[USP_MaintenanceOperations] @Hilfe=1;
Beispiel 2. EXEC [monitor].[USP_MaintenanceOperations] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=50, @ResultSetArt='RAW';
Beispiel 3. DECLARE @ResultJson nvarchar(max); EXEC [monitor].[USP_MaintenanceOperations] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=50, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@ResultJson OUTPUT; SELECT @ResultJson AS [Json];
Beispiel 4. CREATE TABLE #MaintenanceOperations_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_MaintenanceOperations] @DatabaseNames=N'[ExampleDatabase]', @MaxZeilen=50, @ResultSetArt='TABLE', @ResultTablesJson=N'{"resumableOperations":"#MaintenanceOperations_HelpExample"}'; SELECT * FROM #MaintenanceOperations_HelpExample; DROP TABLE #MaintenanceOperations_HelpExample; END TRY BEGIN CATCH DROP TABLE #MaintenanceOperations_HelpExample; THROW; END CATCH;
```

