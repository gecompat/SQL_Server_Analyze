---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentOverview"
schema_name: "monitor"
object_name: "USP_CurrentOverview"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Orchestriert jedes aktivierte Current-State-Child genau einmal, übernimmt dessen expliziten Status und materialisiert Daten für CONSOLE, JSON und benannte TABLE-Exporte ohne erneute Systemlese."
source_path: "Code/02_CurrentState/100_USP_CurrentOverview.sql"
---

# monitor.USP_CurrentOverview

## Zweck und Einsatz

Orchestriert jedes aktivierte Current-State-Child genau einmal, übernimmt dessen expliziten Status und materialisiert Daten für CONSOLE, JSON und benannte TABLE-Exporte ohne erneute Systemlese.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CurrentOverview]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[sys].[sp_executesql]`, `[monitor].[InternalCaptureCurrentStateSnapshot]`, `monitor.InternalCaptureCurrentStateSnapshot`, `[monitor].[USP_CurrentSessions]`, `[monitor].[USP_CurrentRequests]`, `[monitor].[USP_CurrentBlocking]`, `[monitor].[USP_CurrentWaits]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SessionIds | nvarchar(max) | nein | NULL |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @ToolHintergrundabfragenEinbeziehen | bit | nein | 0 |
| @Detailgrad | varchar(16) | nein | 'SUMMARY' |
| @MitSessions | bit | nein | 1 |
| @MitRequests | bit | nein | 1 |
| @MitBlocking | bit | nein | 1 |
| @BlockingObjektTiefe | varchar(16) | nein | 'STANDARD' |
| @MaxObjektAufloesungen | int | nein | 100 |
| @MitWaits | bit | nein | 1 |
| @MitTransactions | bit | nein | 1 |
| @MitMemoryGrants | bit | nein | 1 |
| @MitTempDB | bit | nein | 1 |
| @MitIO | bit | nein | 1 |
| @MitLog | bit | nein | 1 |
| @MitSqlText | bit | nein | 1 |
| @GesamtenSqlTextEinbeziehen | bit | nein | 0 |
| @InputBufferEinbeziehen | bit | nein | 0 |
| @ModulInfoEinbeziehen | bit | nein | 1 |
| @MaxSqlTextZeichen | int | nein | 4000 |
| @SampleSeconds | tinyint | nein | 0 |
| @MaxZeilen | int | nein | 500 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@SessionIds:** @SessionIds: nvarchar(max); Default=NULL. Der Parent normalisiert oder parst den Wert nicht, sondern übergibt ihn unverändert an genau sieben Children: USP_CurrentSessions, USP_CurrentRequests, USP_CurrentBlocking, USP_CurrentWaits, USP_CurrentTransactions, USP_CurrentMemoryGrants und USP_CurrentTempDB. NULL deaktiviert den ID-Filter. Eine Liste kann Pipe, Komma und Semikolon auch gemischt verwenden; Komma und Semikolon werden vor der Pipe-Zerlegung überall in Trenner umgewandelt, auch innerhalb von [...]. Pipe trennt nur außerhalb bracket-quotierter Bereiche; äußere Elementleerzeichen werden getrimmt. Jedes Element muss eine Ganzzahl sein. Leerstring ergibt EMPTY_LIST, reine Leerzeichen oder leere Elemente EMPTY_ITEM; ungültige Elemente und Bereichsverletzungen führen zu INVALID_PARAMETER. Gültige Bereiche und Duplikate unterscheiden sich je Child: Sessions, Requests, Waits und MemoryGrants akzeptieren 1..32767 und fassen Duplikate zusammen; Blocking, Transactions und TempDB akzeptieren 0..32767, lehnen Duplikate ab. Die Liste wird nicht entquotet; Klammerquotierung macht aus einem Zahlenwert keine gültige ID.

**@DatabaseNames:** @DatabaseNames: nvarchar(max); Default=NULL. Bracket-aware Pipe-Liste exakter einteiliger Datenbanknamen mit höchstens 128 Zeichen je Name für I/O und Log; | trennt nur außerhalb von [...], ein | in [...] ist Teil des Namens, und ]] maskiert ein inneres ]. Verglichen wird case-sensitiv; doppelte/ungültige Einträge erzeugen Auswahlfehler oder Warnings. NULL, leer, nur gewöhnliche Leerzeichen oder ausgelassen bedeutet alle sichtbaren, zugreifbaren ONLINE-Benutzerdatenbanken. Exklusiv mit @DatabaseNamePattern; explizit nicht verfügbare Namen können Auswahlwarnings erzeugen. Nur I/O und Log erhalten diesen Filter.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen: bit; Default=0. 0 schließt master, tempdb, model und msdb aus; 1 erlaubt diese sichtbaren ONLINE-Systemdatenbanken für I/O/Log. Ausgelassen ergibt 0; NULL wird als INVALID_PARAMETER abgelehnt. Numerische Eingaben werden vor Eintritt zu bit konvertiert: 0 bleibt 0, jeder numerische Nichtnullwert wird 1. Keine Wirkung auf andere Children.

**@DatabaseNamePattern:** @DatabaseNamePattern: nvarchar(4000); Default=NULL. Ein nichtleeres einzelnes Pattern, exklusiv mit @DatabaseNames, für I/O und Log. Kein Präfix oder like: = case-sensitives SQL-LIKE mit %, _ und []-Klassen; regex: = case-sensitive Regex; regexi: = case-insensitive Regex. Präfixerkennung ist case-insensitiv, äußere Leerzeichen werden entfernt, Musterinhalt bleibt erhalten. NULL/ausgelassen deaktiviert; leer, nur gewöhnliche Leerzeichen oder Präfix ohne Muster ist ungültig. Regex verlangt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Andere Children verwenden das Pattern nicht.

**@HighImpactConfirmed:** @HighImpactConfirmed: bit; Default=0. 0/ausgelassen bestätigt keine angeforderten Hochwirkungswege; 1 bestätigt sie. Numerische Werte werden vor Eintritt zu bit konvertiert (0→0, jeder Nichtnullwert→1); NULL wird als INVALID_PARAMETER abgelehnt. Diese Bestätigung erteilt keine Zugriffsgruppenfreigabe: Children prüfen ihre eigenen erforderlichen Gruppenrechte und Gates; Parent reicht den Wert an Blocking, I/O und Log weiter. DEEP Blocking braucht zusätzlich LOCKS_DEEP.

**@ToolHintergrundabfragenEinbeziehen:** @ToolHintergrundabfragenEinbeziehen: bit; Default=0. 0 blendet erkannte Toolaktivität in Sessions, Requests, Blocking-Blättern und aktuellen Waiting Tasks aus; 1 bezieht sie ein, ohne normale Blockingketten abzuschneiden. Ausgelassen ergibt 0; NULL ist INVALID_PARAMETER; numerisch 0 bleibt 0, jeder Nichtnullwert wird vor Procedure-Eintritt 1. Andere Children erhalten diesen Filter nicht.

**@Detailgrad:** @Detailgrad: varchar(16); Default='SUMMARY'. Nach TRIM/UPPER exakt SUMMARY (nur Modulstatus), RELEVANT (Status plus nichtleere als relevant markierte Childdetails) oder ALL (Status plus nichtleere Resultate aller aktivierten Children mit AVAILABLE/AVAILABLE_LIMITED). Reihenfolge folgt den neun Modulen; Zeilen innerhalb der Grids sind nicht geordnet. Ausgelassen ergibt SUMMARY; NULL/leer normalisiert zu leer und ist ungültig. Keine Reduktion der Child-Erhebungsarbeit.

**@MitSessions:** @MitSessions: bit; Default=1. 1 ruft USP_CurrentSessions genau einmal mit TABLE auf; 0 überspringt es und setzt Modulstatus SKIPPED. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1 vor Eintritt.

**@MitRequests:** @MitRequests: bit; Default=1. 1 ruft USP_CurrentRequests genau einmal mit TABLE auf; 0 überspringt das Child (SKIPPED). Aktiviertes Requests-Child kann Requestkontext, Statements, Batches und InputBuffers liefern. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@MitBlocking:** @MitBlocking: bit; Default=1. 1 ruft USP_CurrentBlocking einmal auf; 0 überspringt Blockingketten und Ressourcenauflösung (SKIPPED). DEEP-Einstellungen wirken nur bei aktiviertem Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@BlockingObjektTiefe:** @BlockingObjektTiefe: varchar(16); Default='STANDARD'. Nach TRIM/UPPER exakt NONE (keine Ressourcenauflösung), STANDARD (Auflösung mit begrenzter Kandidatenzahl) oder DEEP (zusätzlich Locks beteiligter Blocking-Sessions, Prüfung von LOCKS_DEEP; Gruppenfreigabe und @HighImpactConfirmed=1 nur bei aktiver Policy RequiresGroupGate=1). Ausgelassen=STANDARD; NULL/leer/andere Werte ungültig. Wird an Blocking weitergereicht; bei deaktiviertem Blocking keine Childauswirkung.

**@MaxObjektAufloesungen:** @MaxObjektAufloesungen: int; Default=100 Kandidaten. Ganze Zahl 1 bis 1000 einschließlich; begrenzt Blocking-Ressourcenkandidaten, nicht die gesamte Ausgabe. Ausgelassen=100; NULL und Werte außerhalb des Bereichs INVALID_PARAMETER. Child verwendet diesen Wert für die Objektauflösung.

**@MitWaits:** @MitWaits: bit; Default=1. 1 ruft USP_CurrentWaits auf; 0 überspringt aktuelle Waiting Tasks und Wait-Analyse. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@MitTransactions:** @MitTransactions: bit; Default=1. 1 ruft USP_CurrentTransactions auf; 0 überspringt das Transaktions-Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@MitMemoryGrants:** @MitMemoryGrants: bit; Default=1. 1 ruft USP_CurrentMemoryGrants auf; 0 überspringt das Memory-Grant-Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@MitTempDB:** @MitTempDB: bit; Default=1. 1 ruft USP_CurrentTempDB auf und exportiert bei TABLE sessions, tempdbGovernance und versionStore; 0 überspringt diese Quellen/Childexports. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@MitIO:** @MitIO: bit; Default=1. 1 ruft USP_CurrentIO für Datei-I/O auf; 0 überspringt dieses datenbankbezogene Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@MitLog:** @MitLog: bit; Default=1. 1 ruft USP_CurrentLog für Transaktionslogzustände auf; 0 überspringt dieses datenbankbezogene Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@MitSqlText:** @MitSqlText: bit; Default=1. 1 erlaubt unterstützenden Children SQL-Text; 0 deaktiviert ihn. Parent-Snapshot materialisiert Text nur bei mindestens einem tatsächlichen Consumer; Handles werden vor DMF-Zugriff dedupliziert/begrenzt. Requests-Child muss dafür aktiviert sein, und weitere Children können den gemeinsamen Text verbrauchen. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@GesamtenSqlTextEinbeziehen:** @GesamtenSqlTextEinbeziehen: bit; Default=0. 1 fordert bei Requests vollständigen Batch-/Modultext an; 0 fordert ihn nicht an. Separater Childschalter neben @MitSqlText und nur wirksam mit aktiviertem Requests-Child. Ausgelassen=0, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@InputBufferEinbeziehen:** @InputBufferEinbeziehen: bit; Default=0. 1 fordert den Input Buffer als gezielte Requests-Quelle an; 0 nicht. Input Buffer ist kein gemeinsamer Primär-Snapshot und wird nur durch das aktivierte Requests-Child erhoben. Ausgelassen=0, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@ModulInfoEinbeziehen:** @ModulInfoEinbeziehen: bit; Default=1. 1 fordert Request-Modulkontext an; 0 nicht. Der gemeinsame SQL-Text-Capture berücksichtigt diesen Schalter nur bei aktiviertem Requests-Child. Ausgelassen=1, NULL INVALID_PARAMETER; numerisch 0→0, sonst→1.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen: int; Default=4000 Zeichen. Nichtnegative ganze Zahl bis 2147483647; wird an die textausgebenden Children weitergereicht. Eine positive Grenze kürzt die jeweilige Textprojektion nur bei Überschreitung. NULL oder 0 hebt die durch diesen Parameter bewirkte Textbegrenzung auf; es wird dann nicht aufgrund dieses Limits gekürzt. Ausgelassen nutzt 4000. Der Parent lässt NULL passieren; negative Werte sind INVALID_PARAMETER. Das Limit ist keine Anonymisierung.

**@SampleSeconds:** @SampleSeconds: tinyint; Default=0 Sekunden; zulässige Werte 0 bis 60. 0 deaktiviert WAITFOR-Sampling; 1 bis 60 sampelt Waits und I/O nacheinander, verlängert den Parent entsprechend und kann durch Scheduling länger dauern. Ausgelassen nutzt 0. Die Parentprüfung lässt NULL durch: Bei aktiviertem I/O wird es als INVALID_PARAMETER abgelehnt; Waits gelangt damit in den Samplingpfad mit NULL-Verzögerung und behandelt den daraus entstehenden Fehler im DeltaStatus als ERROR_HANDLED mit partieller Sicht. Bereits verfügbare Taskdaten können dabei erhalten bleiben. Werte über 60 sind INVALID_PARAMETER; die Konvertierung zu tinyint erfolgt vor Eintritt.

**@MaxZeilen:** @MaxZeilen: int; Default=500 Zeilen je Child, nicht als Gesamtbudget. Negative Werte INVALID_PARAMETER; NULL oder 0 sind im Parent zulässig und können je Child unbegrenzt bedeuten; positive Werte werden weitergereicht und je Childstufe unterschiedlich angewandt. Ausgelassen=500. Kein globales Limit für Modulstatus oder alle Resultate zusammen.

**@ResultSetArt:** @ResultSetArt: varchar(16); Default='CONSOLE'. Nach TRIM/UPPER exakt CONSOLE (Modulstatusgrid plus gemäß @Detailgrad gewählte nichtleere Childgrids), RAW (Modulstatus, Snapshotstatus und Warnings; keine Childdatengrids), TABLE (nur angeforderte benannte Exporte), NONE (keine fachlichen Resultsets). Ausgelassen=CONSOLE; NULL/leer wird zu '' und ist ungültig. Anders als der Modus entscheidet @Detailgrad über zusätzliche CONSOLE-Details.

**@ResultTablesJson:** @ResultTablesJson: nvarchar(max); Default=NULL. TABLE-Zuordnung als nichtleeres JSON-Objekt; die exakt case-sensitiven Key-Bedeutungen sind moduleStatus = Parent-Modulstatus, snapshotStatus = Status der Snapshotquellen, sessions = Sessionresultate, requests = Requestresultate, requestContext = Requestkontext, statements = Statementtexte, batches = Batch-/Modultexte, inputBuffers = Input-Buffer-Daten, blocking = Blockingketten, waits = aktuelle Waiting Tasks, transactions = Transaktionsresultate, memoryGrants = Memory-Grant-Resultate, tempdbSessions = TempDB-Sessionverbrauch, tempdbGovernance = TempDB-Governancewerte, versionStore = Version-Store-Werte, io = Datei-I/O-Resultate, logs = Transaktionslogzustände und warnings = Warnungen. Jeder zugehörige Wert muss ein nichtleerer JSON-String mit Name einer vorhandenen lokalen #Temp-Tabelle sein (keine ##-Temp, Name höchstens 116 Zeichen, nicht #Monitor...). Ziele müssen leer sein und genau eine Seed-Spalte haben; Resultnamen und Zieltabellen dürfen nicht doppelt vorkommen. Unbekannte Keys, ungültige JSON/Form, Typen oder Ziele schlagen im Preflight mit 51011 fehl. Für TABLE erforderlich. Außerhalb TABLE muss der Wert NULL, leer oder nach SQL-LTRIM/RTRIM nur aus gewöhnlichen Leerzeichen bestehen; eine nichtleere Map ist unzulässig. Wird nur im normalen Pfad nach dem Hilfezweig und vor semantischen Parentchecks validiert. Gültiges Mapping garantiert keine späteren Daten/Frische; deaktivierte Childtargets können ungeschrieben bleiben, Request-Kontext/Textziele Seed-Schema behalten.

**@JsonErzeugen:** @JsonErzeugen: bit; Default=0. 0 deaktiviert JSON; 1 baut unabhängig von @ResultSetArt ein JSON-Objekt. Ausgelassen=0; NULL und Werte außer 0/1 sind INVALID_PARAMETER. Numerische Eingaben vor Eintritt: 0→0, Nichtnull→1. Envelope: meta (resultName, schemaVersion, generatedAtUtc, statusCode, evidenceSnapshotId, isPartial, executedModules, failedModules, partialModules, toolBackgroundQueriesIncluded), moduleStatus, snapshotStatus, warnings sowie je aktiviertem Child dessen benanntes Array in Modulreihenfolge. Resultfehler können als null-Childvalue erscheinen.

**@Json:** @Json: nvarchar(max) OUTPUT; Default=NULL. Optionale Aufrufvariable vom Typ nvarchar(max), im EXEC mit OUTPUT zu binden. Wird bei Procedure-Eintritt immer zuerst auf NULL gesetzt; wenn @JsonErzeugen=1 wird sie mit dem JSON-Envelope befüllt, andernfalls bleibt sie NULL. Das Auslassen der Empfangsbindung verhindert das Empfangen des Werts.

**@PrintMeldungen:** @PrintMeldungen: bit; Default=1. 1 aktiviert die optionalen Status-/Warnmeldungen der aktivierten Children; 0 unterdrückt diese Meldungen, ohne Resultsets oder JSON zu deaktivieren. Ausgelassen nutzt 1. Der Parent weist NULL nicht zurück: Blocking und I/O lehnen NULL als INVALID_PARAMETER ab; Sessions, Requests, Waits, Transactions, MemoryGrants, TempDB und Log unterdrücken damit die Meldungen ihrer IF-gleich-1-Pfade. Diese Folgen betreffen nur die jeweils aktivierten Childmodule. SQL Server konvertiert numerisch 0 vor Eintritt zu bit 0 und numerische Werte ungleich 0 zu bit 1.

**@Hilfe:** @Hilfe: bit; Default=0. Bei exakt 1 wird PRINT-Hilfe ausgegeben und vor einer gegebenenfalls angeforderten TABLE-Map-Vorprüfung zurückgekehrt, ohne Children oder Exporte auszuführen. 0 führt den normalen Pfad aus. Ausgelassen=0; NULL wird nicht als Hilfe erkannt und führt in den normalen Pfad, nicht zu INVALID_PARAMETER. Numerische Werte werden vor Eintritt zu bit konvertiert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleOrdinal] int NOT NULL , [ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [DurationMs] bigint NOT NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , PRIMARY KEY ([ModuleOrdinal]) |
| snapshotStatus | 1 | 1 | [SourceOrdinal] int NOT NULL , [SnapshotId] uniqueidentifier NOT NULL , [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [CompletedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [CapturedRowCount] bigint NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , PRIMARY KEY ([SourceOrdinal]) |
| sessions | 1 | 1 | [Seed] bit NULL |
| requests | 1 | 1 | [Seed] bit NULL |
| blocking | 1 | 1 | [Seed] bit NULL |
| waits | 1 | 1 | [Seed] bit NULL |
| transactions | 1 | 1 | [Seed] bit NULL |
| memoryGrants | 1 | 1 | [Seed] bit NULL |
| tempdbSessions | 1 | 1 | [Seed] bit NULL |
| tempdbGovernance | 0 | 1 | [Seed] bit NULL |
| versionStore | 0 | 1 | [Seed] bit NULL |
| io | 1 | 1 | [Seed] bit NULL |
| logs | 1 | 1 | [Seed] bit NULL |
| warnings | 1 | 1 | [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |
| requestContext | 1 | 1 | [Seed] bit NULL |
| statements | 1 | 1 | [Seed] bit NULL |
| batches | 1 | 1 | [Seed] bit NULL |
| inputBuffers | 1 | 1 | [Seed] bit NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentOverview] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentOverview liefert eine aktuelle, sequenzielle Orchestrierung und keine atomare Gesamtaufnahme.

Für Hilfe ohne TABLE-Ziel verwenden Sie @ResultSetArt='CONSOLE', @ResultTablesJson=NULL und @Hilfe=1; Für den normalen TABLE-Pfad muss vor dem Aufruf ein vorhandenes, leeres lokales #Temp-Ziel mit einer Seed-Spalte bereitstehen; @Hilfe=1 prüft dieses Ziel nicht.

Regexmuster in @DatabaseNamePattern benötigen SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; leere Muster sind ungültig.

RELEVANT zeigt nur als relevant markierte nichtleere Childresultate; ALL zeigt nichtleere Resultate aller aktivierten Children mit Status AVAILABLE oder AVAILABLE_LIMITED.

Ein numerischer Wert 0 bleibt bei der Konvertierung zu bit 0; jeder von 0 verschiedene numerische Wert wird zu 1 und NULL bleibt NULL, wird aber von der Parameterprüfung abgelehnt.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentOverview
Version      : 4.1.0
Stand        : 2026-07-23
Zweck        : Orchestriert jedes aktivierte Current-State-Child genau einmal,
               übernimmt dessen expliziten Status und materialisiert Daten für
               CONSOLE, JSON und benannte TABLE-Exporte ohne erneute Systemlese.
CONSOLE      : SUMMARY ist der Default. RELEVANT und ALL ergänzen ausschließlich
               nicht leere Childdetails; Children erhalten niemals CONSOLE.
TABLE-Namen  : moduleStatus, snapshotStatus, sessions, requests, requestContext,
               statements, batches, inputBuffers, blocking, waits, transactions,
               memoryGrants, tempdbSessions, tempdbGovernance, versionStore, io, logs und warnings.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentOverview liefert eine aktuelle, sequenzielle Orchestrierung und keine atomare Gesamtaufnahme.
Für Hilfe ohne TABLE-Ziel verwenden Sie @ResultSetArt='CONSOLE', @ResultTablesJson=NULL und @Hilfe=1; Für den normalen TABLE-Pfad muss vor dem Aufruf ein vorhandenes, leeres lokales #Temp-Ziel mit einer Seed-Spalte bereitstehen; @Hilfe=1 prüft dieses Ziel nicht.
Regexmuster in @DatabaseNamePattern benötigen SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; leere Muster sind ungültig.
RELEVANT zeigt nur als relevant markierte nichtleere Childresultate; ALL zeigt nichtleere Resultate aller aktivierten Children mit Status AVAILABLE oder AVAILABLE_LIMITED.
Ein numerischer Wert 0 bleibt bei der Konvertierung zu bit 0; jeder von 0 verschiedene numerische Wert wird zu 1 und NULL bleibt NULL, wird aber von der Parameterprüfung abgelehnt.
CONSOLE und RAW geben das Modulstatus-Grid aus; RAW ergänzt Snapshotstatus und Warnings, aber keine Childdaten-Grids. TABLE exportiert angeforderte Resultnamen, NONE unterdrückt Resultsets.
Erlaubte TABLE-Namen sind moduleStatus, snapshotStatus, sessions, requests, requestContext, statements, batches, inputBuffers, blocking, waits, transactions, memoryGrants, tempdbSessions, tempdbGovernance, versionStore, io, logs und warnings.
TABLE-Zuordnungen werden nur im normalen Pfad geprüft; @Hilfe=1 kehrt davor zurück. Ungültige Zuordnungen lösen dort Fehler 51011 aus.
meta enthält unter anderem Schemaversion, Status, Snapshot-ID, Partialität und Modulzähler; moduleStatus, snapshotStatus und warnings sind JSON-Arrays.
Ungültige semantische Parameter ergeben INVALID_PARAMETER; Childfehler oder fehlende Snapshotquellen können Status AVAILABLE_LIMITED, Fehlerstatus oder PARTIAL und Warnings erzeugen.
Jedes aktivierte Child wird genau einmal sequenziell und intern mit TABLE aufgerufen; sind alle Childflags aus, läuft keines. Gemeinsame Capturequellen folgen Abhängigkeiten und sind nicht mit den Childflags identisch.
CONSOLE-Beispiel: EXEC [monitor].[USP_CurrentOverview] @MitSqlText=0, @SampleSeconds=0, @MaxZeilen=100, @ResultSetArt='CONSOLE';
TABLE-Beispiel: CREATE TABLE #CurrentOverview_HelpExample (Seed bit NULL); EXEC [monitor].[USP_CurrentOverview] @MitSqlText=0, @SampleSeconds=0, @ResultSetArt='TABLE', @ResultTablesJson=N'{"moduleStatus":"#CurrentOverview_HelpExample"}'; SELECT * FROM #CurrentOverview_HelpExample; DROP TABLE #CurrentOverview_HelpExample;
JSON-Beispiel: DECLARE @OverviewJson nvarchar(max); EXEC [monitor].[USP_CurrentOverview] @MitSqlText=0, @SampleSeconds=0, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@OverviewJson OUTPUT; SELECT @OverviewJson;
Alle Beispielwerte sind synthetisch; SUMMARY reduziert die Ausgabe, nicht die Childarbeit, und die sequenziellen Messungen belegen keinen atomaren Gesamtzustand.
```

