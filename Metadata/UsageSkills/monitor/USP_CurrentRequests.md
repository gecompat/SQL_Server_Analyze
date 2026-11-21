---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentRequests"
schema_name: "monitor"
object_name: "USP_CurrentRequests"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert aktive Requests mit Session-, Wait-, Memory-Grant-, Modul- und exakt abgegrenztem SQL-Statement- sowie Ausführungs- und Verschachtelungskontext."
source_path: "Code/02_CurrentState/020_USP_CurrentRequests.sql"
---

# monitor.USP_CurrentRequests

## Zweck und Einsatz

Liefert aktive Requests mit Session-, Wait-, Memory-Grant-, Modul- und exakt abgegrenztem SQL-Statement- sowie Ausführungs- und Verschachtelungskontext.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CurrentRequests]. Die Quelle nennt insbesondere `sys.dm_exec_input_buffer`, `[sys].[sp_executesql]`, `[monitor].[InternalPrepareResultTables]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[TVF_ParseBigintList]`, `[monitor].[TVF_ParseStringList]`, `[monitor].[TVF_ParseSqlNameList]`, `[master].[sys].[databases]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SessionIds | nvarchar(max) | nein | NULL |
| @EigeneSessionsModus | varchar(16) | nein | 'ALLE' |
| @AktuelleSessionEinbeziehen | bit | nein | 0 |
| @SystemSessionsEinbeziehen | bit | nein | 0 |
| @ToolHintergrundabfragenEinbeziehen | bit | nein | 0 |
| @NurBlockierte | bit | nein | 0 |
| @NurMitWait | bit | nein | 0 |
| @MinLaufzeitSekunden | int | nein | NULL |
| @MinCpuMs | bigint | nein | NULL |
| @MinLogicalReads | bigint | nein | NULL |
| @LoginNames | nvarchar(max) | nein | NULL |
| @LoginNamePattern | nvarchar(4000) | nein | NULL |
| @HostNames | nvarchar(max) | nein | NULL |
| @HostNamePattern | nvarchar(4000) | nein | NULL |
| @ProgramNames | nvarchar(max) | nein | NULL |
| @ProgramNamePattern | nvarchar(4000) | nein | NULL |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @TextPattern | nvarchar(4000) | nein | NULL |
| @MitSqlText | bit | nein | 1 |
| @GesamtenSqlTextEinbeziehen | bit | nein | 0 |
| @InputBufferEinbeziehen | bit | nein | 0 |
| @ModulInfoEinbeziehen | bit | nein | 1 |
| @MaxSqlTextZeichen | int | nein | 4000 |
| @MaxZeilen | int | nein | 500 |
| @Sortierung | varchar(32) | nein | 'RELEVANZ' |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ParentCurrentStateSnapshotId | uniqueidentifier | nein | NULL |

**@SessionIds:** @SessionIds: Typ nvarchar(max); Default NULL. Zulässig ist eine Liste ganzzahliger IDs 1 bis 32767. Pipe, Komma und Semikolon dürfen gemischt werden; Komma/Semikolon werden vor Pipe-Aufteilung überall, auch in Klammern, zu Trennern. Äußere Elementleerzeichen werden getrimmt, Duplikate zusammengeführt; Klammerquotierung macht keine gültige Zahl. NULL deaktiviert den Filter; ausgelassen nutzt NULL. Leerstring ist EMPTY_LIST; leere/ungültige Elemente, Nichtzahl oder Bereichsverletzung ergeben INVALID_PARAMETER. Wirkung: Beschränkt auf die genannten Session-IDs.

**@EigeneSessionsModus:** @EigeneSessionsModus: Typ varchar(16); Default ALLE. Geschlossene Menge nach äußerem Trim und Großschreibung: ALLE lässt alle Original-Logins zu; NUR behält Sessions mit Original-Login gleich ORIGINAL_LOGIN(); AUSSCHLIESSEN entfernt diese. NULL wird ALLE; ausgelassen nutzt ALLE. Leer oder unbekannter Wert ist INVALID_PARAMETER. Wirkung: Filtert nach ORIGINAL_LOGIN(), nicht nach effektivem Login.

**@AktuelleSessionEinbeziehen:** @AktuelleSessionEinbeziehen: Typ bit; Default 0. SQL-konvertierter Schalter: numerisch 0 bleibt 0, numerischer Wert ungleich 0 wird 1. NULL wird in der tatsächlichen Bedingung wie 0 behandelt; ausgelassen nutzt 0. Wirkung: 1 erlaubt die aufrufende Session @@SPID, 0/NULL schließt sie aus.

**@SystemSessionsEinbeziehen:** @SystemSessionsEinbeziehen: Typ bit; Default 0. Numerischer 0/1-Schalter; numerischer Wert ungleich 0 wird vor Eintritt zu 1 konvertiert. NULL wirkt in der Filterbedingung wie 0; ausgelassen nutzt 0. Wirkung: 1 nimmt Nicht-User-Sessions auf; 0/NULL beschränkt auf is_user_process=1.

**@ToolHintergrundabfragenEinbeziehen:** @ToolHintergrundabfragenEinbeziehen: Typ bit; Default 0. Numerischer Schalter, Wert ungleich 0 wird zu 1 konvertiert. NULL ist INVALID_PARAMETER; ausgelassen nutzt 0. Wirkung: 1 nimmt erkannte Object-Explorer-, Copilot- und SQL-Prompt-Hintergrundrequests auf, 0 blendet sie aus. Die metadatengetriebene LIKE-Erkennung ist eine Heuristik und keine Sicherheitsidentität.

**@NurBlockierte:** @NurBlockierte: Typ bit; Default 0. Numerischer Schalter nach SQL-bit-Konvertierung: 0 deaktiviert den Filter, 1 behält Requests mit blocking_session_id ungleich 0. NULL ist kein Parameterfehler und deaktiviert den Filter nicht: passende blockierte Requests bleiben erhalten, nicht passende werden wegen der dreistelligen SQL-Logik verworfen. Auslassen nutzt 0; numerische Werte ungleich 0 werden zu 1 konvertiert.

**@NurMitWait:** @NurMitWait: Typ bit; Default 0. 0 deaktiviert den Filter; 1 behält Requests mit Request-Wait (wait_type IS NOT NULL) oder mindestens einem Waiting Task derselben Session. Bei mehreren gleichzeitigen Requests dieser Session kann der Task zu einem anderen Request gehören. NULL ist kein Parameterfehler und wirkt hinsichtlich der behaltenen Menge wie 1: Requests, die mindestens eine der beiden Bedingungen erfüllen, bleiben erhalten, nicht passende werden verworfen. Auslassen nutzt 0; numerische Werte ungleich 0 werden vor Eintritt zu 1 konvertiert.

**@MinLaufzeitSekunden:** @MinLaufzeitSekunden: Typ int; Default NULL. Nichtnegative ganze Sekunden von 0 bis 2147483647; vor Multiplikation mit 1000 wird nach bigint konvertiert. NULL deaktiviert den Mindestdauerfilter; ausgelassen nutzt NULL. Negative Werte sind INVALID_PARAMETER; leer ist keine int-Eingabe. Wirkung: Mindestdauer seit Requeststart.

**@MinCpuMs:** @MinCpuMs: Typ bigint; Default NULL. Nichtnegative ganzzahlige Millisekunden von 0 bis 9223372036854775807. NULL deaktiviert den Filter; ausgelassen nutzt NULL. Negative Werte sind INVALID_PARAMETER; leer ist keine bigint-Eingabe. Wirkung: Behält Requests ab dieser kumulierten CPU-Zeit.

**@MinLogicalReads:** @MinLogicalReads: Typ bigint; Default NULL. Nichtnegative ganze Logical Reads von 0 bis 9223372036854775807. NULL deaktiviert den Filter; ausgelassen nutzt NULL. Negative Werte sind INVALID_PARAMETER; leer ist keine bigint-Eingabe. Wirkung: Behält Requests ab diesem kumulierten Logical-Read-Wert.

**@LoginNames:** @LoginNames: Typ nvarchar(max); Default NULL. Exakte Textliste, höchstens 128 Zeichen je entquotetem Wert. Pipe trennt nur außerhalb eckiger Klammern; ]] maskiert darin eine schließende Klammer. Elementränder werden getrimmt; vollständig geklammerte Werte entquotet. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring, leeres/ungültiges Element, leeres entquotetes Ergebnis, fehlerhafte Klammerung oder Überlänge ergibt INVALID_PARAMETER. Wirkung: Case-sensitive Gleichheit unter SQL_Latin1_General_CP1_CS_AS; Duplikate werden zusammengeführt. Ungültig in Kombination mit nicht-NULL @LoginNamePattern.

**@LoginNamePattern:** @LoginNamePattern: Typ nvarchar(4000); Default NULL. Einzelpattern: außen trimmen, Präfix like:, regex: oder regexi: case-insensitiv erkennen; Rest nicht erneut trimmen. Unpräfixiert und like: verwenden SQL-LIKE-Syntax unverändert (%, _ und [] sind Wildcards; keine Wildcards werden ergänzt). regex: ist case-sensitive (Flag c), regexi: case-insensitive (Flag i). NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ergibt INVALID_PARAMETER. Wirkung: Filtert Login; ungültig bei nicht-NULL @LoginNames. Regex erfordert SQL Server 2025 und Compatibility Level 170; Engine behandelt Regexsyntax.

**@HostNames:** @HostNames: Typ nvarchar(max); Default NULL. Exakte Textliste, höchstens 128 Zeichen je entquotetem Wert; Pipe trennt nur außerhalb eckiger Klammern, ]] maskiert ] innerhalb; Elementränder getrimmt, geklammerte Werte entquotet. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring, leeres/ungültiges Element, falsche Klammerung, leeres Ergebnis oder Überlänge ergibt INVALID_PARAMETER. Wirkung: Case-sensitive Gleichheit zu HostName; Duplikate zusammengeführt. Ungültig mit nicht-NULL @HostNamePattern.

**@HostNamePattern:** @HostNamePattern: Typ nvarchar(4000); Default NULL. Außen trimmen; like:, regex:, regexi: ohne Beachtung der Großschreibung erkennen; Rest nicht erneut trimmen. Unpräfixiert/like: nutzt unveränderte SQL-LIKE-Wildcards %, _ und [], ohne automatische Wildcards; regex: Flag c, regexi: Flag i. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ungültig. Wirkung: Filtert HostName; ungültig mit nicht-NULL @HostNames. Regex nur SQL Server 2025/Compatibility Level 170.

**@ProgramNames:** @ProgramNames: Typ nvarchar(max); Default NULL. Exakte Textliste, höchstens 128 Zeichen je entquotetem Wert; Pipe nur außerhalb eckiger Klammern, ]] maskiert ] darin; Trim und Entquotung geklammerter Werte. NULL deaktiviert; ausgelassen nutzt NULL. Leere/ungültige Elemente, falsche Klammerung, leeres Ergebnis oder Überlänge ergibt INVALID_PARAMETER. Wirkung: Case-sensitive Gleichheit zu ProgramName; Duplikate zusammengeführt. Ungültig mit nicht-NULL @ProgramNamePattern.

**@ProgramNamePattern:** @ProgramNamePattern: Typ nvarchar(4000); Default NULL. Außen trimmen; Präfix like:, regex:, regexi: case-insensitiv erkennen; Rest nicht erneut trimmen. Unpräfixiert/like: nutzt unveränderte SQL-LIKE-Wildcards %, _ und [], ohne Wildcardergänzung; regex: Flag c, regexi: Flag i. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ungültig. Wirkung: Filtert ProgramName; ungültig mit nicht-NULL @ProgramNames. Regex nur SQL Server 2025/CL170.

**@DatabaseNames:** @DatabaseNames: Typ nvarchar(max); Default NULL. Bracket-aware Pipe-Liste einteiliger SQL-Namen nach PARSENAME; | trennt nur außerhalb [...], ]] maskiert ]; Elementränder getrimmt; Name maximal 128 Zeichen. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Element, fehlerhafte Klammerung, ungültiger oder mehrteiliger Name und Überlänge ergeben INVALID_PARAMETER. Wirkung: Case-sensitive Gleichheit zu Datenbankname. Ungültig mit nicht-NULL @DatabaseNamePattern.

**@DatabaseNamePattern:** @DatabaseNamePattern: Typ nvarchar(4000); Default NULL. Außen trimmen; Präfix like:, regex:, regexi: case-insensitiv erkennen; Rest nicht erneut trimmen. Unpräfixiert/like: nutzt unveränderte SQL-LIKE-Wildcards %, _ und [], keine Ergänzung; regex: Flag c, regexi: Flag i. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ungültig. Wirkung: Filtert Datenbanknamen; ungültig mit nicht-NULL @DatabaseNames. Regex nur SQL Server 2025/CL170.

**@HighImpactConfirmed:** @HighImpactConfirmed: Typ bit; Default 0. Numerischer SQL-bit-Schalter; numerischer Wert ungleich 0 wird 1. NULL und Auslassen ändern nichts. Der Procedurekörper liest den Parameter nicht; er bestätigt oder aktiviert keinen Zugriff und erteilt keine Berechtigung. Caller-Sicht und Serverrechte bleiben eigenständig; es gibt hier kein separates Gruppenautorisierungsargument.

**@TextPattern:** @TextPattern: Typ nvarchar(4000); Default NULL. Einzelpattern mit denselben Außen-Trim- und Präfixregeln: like:, regex:, regexi: case-insensitiv; Rest nicht erneut trimmen. LIKE-Wildcards werden unverändert ohne Ergänzung angewendet; regex: Flag c, regexi: Flag i. NULL deaktiviert; ausgelassen nutzt NULL. Leerstring/leeres Präfix ist INVALID_PARAMETER. Wirkung: Durchsucht aktuelles Statement oder Batchtext; kann Text bei @MitSqlText=0 intern lesen. Regex nur SQL Server 2025/CL170.

**@MitSqlText:** @MitSqlText: Typ bit; Default 1. Numerischer Schalter; Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 1. Wirkung: 1 gibt das Statement anhand gültiger Request-Offsets aus; 0 unterdrückt diese Ausgabe. Patternfilter und Modulauflösung können SQL-Text unabhängig davon intern lesen.

**@GesamtenSqlTextEinbeziehen:** @GesamtenSqlTextEinbeziehen: Typ bit; Default 0. Numerischer Schalter; Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 0. Wirkung: 1 gibt Batch-/Modultext zusätzlich aus; 0 unterdrückt dessen Ausgabe. TextPattern kann den Text trotzdem intern lesen. Es wird kein Showplan abgerufen.

**@InputBufferEinbeziehen:** @InputBufferEinbeziehen: Typ bit; Default 0. Numerischer Schalter; Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 0. Wirkung: 1 liest sys.dm_exec_input_buffer erst nach Kandidatenfiltern und Zeilenlimit für behaltene Requests. Der Clientbefehl ist nicht zwingend das aktuelle Statement.

**@ModulInfoEinbeziehen:** @ModulInfoEinbeziehen: Typ bit; Default 1. Numerischer Schalter; Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 1. Wirkung: 1 löst Textdatenbank und Objekt über Systemkataloge auf; Berechtigungsfehler oder Timeout können PARTIAL_RESULT ergeben. Dies ruft keinen Plan ab und erteilt keine Rechte.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen: Typ int; Default 4000. Nichtnegative int-Zeichenanzahl je Statement, Batch und Input Buffer; 0 bedeutet ungekürzt. NULL/0 ungekürzt; ausgelassen 4000; negative Werte INVALID_PARAMETER. Begrenzt ausgegebenen Text, nicht interne Lesung und nicht Anonymisierung.

**@MaxZeilen:** @MaxZeilen: Typ int; Default 500. Positive Limits 1 bis 2147483647. NULL oder 0 bedeutet unbegrenzt; ausgelassen 500; negative Werte INVALID_PARAMETER. Gilt nach Filterung und Sortierung für alle Ausgabearten, vor Modulauflösung und Input Buffer. HasMoreRows zeigt weitere Kandidaten.

**@Sortierung:** @Sortierung: Typ varchar(32); Default RELEVANZ. Außen trimmen und großschreiben. Taxative Werte: RELEVANZ priorisiert blockierte Requests mit blocking_session_id ungleich 0 vor solchen mit wait_type IS NOT NULL vor den übrigen; dies identifiziert keinen Root-Blocker. CPU ordnet CpuMs absteigend; READS LogicalReads absteigend; DAUER ElapsedMs absteigend; SESSION nach SessionId, RequestId. NULL wird zu RELEVANZ; ausgelassen nutzt RELEVANZ. Leer oder unbekannter Wert ist INVALID_PARAMETER. In allen Modi sind SessionId und RequestId die Tie-Breaker.

**@ResultSetArt:** @ResultSetArt: Typ varchar(16); Default CONSOLE. Außen trimmen und großschreiben. Taxative Werte: CONSOLE beschriftete Sicht; RAW Status und sieben Resultsets; TABLE ausschließlich explizit benannte Ziele; NONE keine fachlichen Resultsets. NULL wird leer und ist ungültig; ausgelassen CONSOLE; leer/unbekannt INVALID_PARAMETER. TABLE-Vorprüfung geschieht vor semantischer Parameterprüfung; JSON ist unabhängig schaltbar.

**@ResultTablesJson:** @ResultTablesJson: Typ nvarchar(max); Default NULL. Im normalen Ausführungspfad bei TABLE ein nichtleeres JSON-Objekt mit Schlüssel aus der exakten Menge requests (Requestzeilen), requestContext (Requestkontext), snapshotStatus (Status je Snapshotquelle), statements (Statementtexte und Evidenz), batches (Batchtexte und Evidenz), inputBuffers (Input-Buffer-Evidenz), warnings (Warnungen) und einem JSON-String als Name einer vorhandenen lokalen #Temp-Tabelle. Keine unbekannten/duplizierten Namen oder Ziele und keine globale ##Temp. Jedes Ziel muss leer und mit genau einer Seed-Spalte angelegt sein. NULL/leer/fehlende Zuordnung in TABLE ungültig. Außerhalb TABLE NULL/leer zulässig; nichtleer löst Fehler 51011 aus. Auslassen nutzt NULL. Nur benannte Ziele werden befüllt. Vorprüfung belegt keine Frische oder Herkunft; sie erfolgt vor semantischer Validierung. Die Ablehnung einer nichtleeren Zuordnung außerhalb TABLE erfolgt auch vor dem Hilfepfad.

**@JsonErzeugen:** @JsonErzeugen: Typ bit; Default 0. Numerischer Schalter, Wert ungleich 0 wird zu 1. NULL ist INVALID_PARAMETER; ausgelassen nutzt 0. Wirkung: 1 erzeugt unabhängig von ResultSetArt JSON Schema 4 mit meta, requests, requestContext, snapshotStatus, statements, batches, inputBuffers und warnings.

**@Json:** @Json: Typ nvarchar(max) OUTPUT; Default NULL. Wenn verwendet, muss EXEC an eine beschreibbare nvarchar(max)-Variable mit OUTPUT gebunden werden; kein Literal. Beim Procedureintritt wird der gebundene Wert auf NULL gesetzt. Ohne @JsonErzeugen=1 bleibt er NULL; Auslassen zulässig, sofern JSON nicht angefordert ist. Bei @JsonErzeugen=1 enthält er das Envelope. Resultset und JSON sind unabhängig.

**@PrintMeldungen:** @PrintMeldungen: Typ bit; Default 1. Numerischer Schalter, Wert ungleich 0 wird zu 1. NULL unterdrückt wie 0; ausgelassen nutzt 1. Bei Status ungleich AVAILABLE sendet 1 eine Severity-10-Meldung mit Status und Fehler/Hinweis; 0/NULL unterdrückt sie.

**@Hilfe:** @Hilfe: Typ bit; Default 0. 1 druckt die Hilfe und kehrt vor TABLE-Zielvorbereitung, regulärer fachlicher Parameterprüfung und Quellenaufnahme zurück. Bereits davor wird eine nichtleere @ResultTablesJson-Zuordnung außerhalb TABLE mit 51011 abgelehnt, auch bei Hilfe=1. @Json wird zuvor auf NULL gesetzt. 0 oder NULL führt den normalen Pfad aus; ausgelassen nutzt 0. Numerische Werte ungleich 0 werden vor Eintritt zu 1 konvertiert.

**@ParentCurrentStateSnapshotId:** @ParentCurrentStateSnapshotId: Typ uniqueidentifier; Default NULL. Einzelne GUID, ausschließlich für den internen Consumer USP_CurrentOverview, der sie während derselben laufenden Snapshotaufnahme erzeugt. NULL erzwingt eine frische Einzelaufnahme; ausgelassen nutzt NULL. Nicht-NULL muss einen Parent mit OwnerSessionId=@@SPID und ContractVersion=2 bezeichnen; fehlender/fremder Snapshot wird INVALID_PARENT_SNAPSHOT. Übernommene Quellzeitpunkte bleiben Parent-Zeitpunkte.

## Resultate und Ausgabe

CONSOLE (Default), RAW, TABLE, NONE sowie optionales JSON-Envelope mit requests (Legacy), requestContext, snapshotStatus, statements, batches, inputBuffers und warnings.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| requests | 1 | 1 | [SessionId] smallint NOT NULL , [RequestId] int NOT NULL , [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [DatabaseId] smallint NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [OriginalLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [IsToolBackgroundQuery] bit NOT NULL , [ToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [StartTime] datetime NULL , [ElapsedMs] int NULL , [CpuMs] int NULL , [LogicalReads] bigint NULL , [Reads] bigint NULL , [Writes] bigint NULL , [RowCount] bigint NULL , [PercentComplete] real NULL , [EstimatedCompletionTimeMs] bigint NULL , [BlockingSessionId] smallint NULL , [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [WaitTimeMs] int NULL , [LastWaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [WaitResource] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [WaitingTaskCount] int NULL , [MaxTaskWaitMs] bigint NULL , [TaskWaitTypes] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RequestedMemoryMb] decimal(19,2) NULL , [GrantedMemoryMb] decimal(19,2) NULL , [UsedMemoryMb] decimal(19,2) NULL , [IdealMemoryMb] decimal(19,2) NULL , [Dop] smallint NULL , [ParallelWorkerCount] int NULL , [TransactionIsolationLevel] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [OpenTransactionCount] int NULL , [OpenResultsetCount] int NULL , [TransactionId] bigint NULL , [ConnectionId] uniqueidentifier NULL , [SchedulerId] int NULL , [TaskAddress] varbinary(8) NULL , [NestLevel] int NULL , [WorkloadGroupId] int NULL , [WorkloadGroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ResourcePoolId] int NULL , [ResourcePoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [StatementSqlHandle] varbinary(64) NULL , [StatementContextId] bigint NULL , [IsResumable] bit NULL , [ExecutingManagedCode] bit NULL , [ContextInfo] varbinary(128) NULL , [ClientNetAddress] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [QueryHash] binary(8) NULL , [QueryPlanHash] binary(8) NULL , [SqlHandle] varbinary(64) NULL , [PlanHandle] varbinary(64) NULL , [SqlTextDatabaseId] int NULL , [SqlTextObjectId] int NULL , [SqlTextObjectNumber] smallint NULL , [SqlTextIsEncrypted] bit NULL , [ExecutionContextType] varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ModuleDatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ModuleSchemaName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ModuleObjectName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ModuleType] char(2) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ModuleTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ModuleFullName] nvarchar(776) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [HasStatementOffsets] bit NULL , [IsStatementOffsetValid] bit NULL , [StatementStartOffsetBytes] int NULL , [StatementEndOffsetBytes] int NULL , [StatementStartCharacter] int NULL , [StatementEndCharacter] int NULL , [StatementStartLine] int NULL , [StatementEndLine] int NULL , [CurrentStatementCharacterCount] bigint NULL , [CurrentStatementBytes] bigint NULL , [CurrentStatementIsTruncated] bit NULL , [BatchTextCharacterCount] bigint NULL , [BatchTextBytes] bigint NULL , [BatchTextIsTruncated] bit NULL , [CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [InputBufferEventType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [InputBufferParameterCount] smallint NULL , [InputBufferCharacterCount] bigint NULL , [InputBufferBytes] bigint NULL , [InputBufferIsTruncated] bit NULL , [InputBufferText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , PRIMARY KEY ([SessionId], [RequestId]) |
| requestContext | 1 | 1 | [SnapshotId] uniqueidentifier NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [SessionId] smallint NOT NULL , [RequestId] int NOT NULL , [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Command] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [DatabaseId] smallint NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [StartTime] datetime NULL , [ElapsedMs] int NULL , [CpuMs] int NULL , [LogicalReads] bigint NULL , [Reads] bigint NULL , [Writes] bigint NULL , [RowCount] bigint NULL , [PercentComplete] real NULL , [EstimatedCompletionTimeMs] bigint NULL , [BlockingSessionId] smallint NULL , [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [WaitTimeMs] bigint NULL , [WaitResource] nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ConnectionId] uniqueidentifier NULL , [ClientNetAddress] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [AuthScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [TaskCount] int NULL , [WorkerCount] int NULL , [ExecutionContextCount] int NULL , [RunnableTaskCount] int NULL , [SuspendedTaskCount] int NULL , [SchedulerId] int NULL , [SchedulerStatus] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SchedulerParentNodeId] int NULL , [SchedulerRunnableTaskCount] int NULL , [SchedulerWorkQueueCount] bigint NULL , [SchedulerPendingDiskIoCount] int NULL , [SchedulerLoadFactor] int NULL , [TransactionId] bigint NULL , [TransactionBeginTime] datetime NULL , [TransactionAgeSeconds] bigint NULL , [TransactionType] int NULL , [TransactionState] int NULL , [IsUserTransaction] bit NULL , [IsLocalTransaction] bit NULL , [IsEnlistedTransaction] bit NULL , [IsBoundTransaction] bit NULL , [TransactionLogBytesUsed] bigint NULL , [TransactionLogBytesReserved] bigint NULL , [RequestedMemoryMb] decimal(19,2) NULL , [GrantedMemoryMb] decimal(19,2) NULL , [UsedMemoryMb] decimal(19,2) NULL , [IdealMemoryMb] decimal(19,2) NULL , [TempDbSessionNetMb] decimal(19,2) NULL , [TempDbRequestNetMb] decimal(19,2) NULL , [Dop] smallint NULL , [ParallelWorkerCount] int NULL , [WorkloadGroupId] int NULL , [WorkloadGroupName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ResourcePoolId] int NULL , [ResourcePoolName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [QueryHash] binary(8) NULL , [QueryPlanHash] binary(8) NULL , [SqlHandle] varbinary(64) NULL , [PlanHandle] varbinary(64) NULL , [StatementSqlHandle] varbinary(64) NULL , [StatementContextId] bigint NULL , [ModuleFullName] nvarchar(776) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [IsCurrent] bit NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [EvidenceBoundary] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , PRIMARY KEY ([SessionId],[RequestId]) |
| snapshotStatus | 1 | 1 | [SourceOrdinal] int NOT NULL , [SnapshotId] uniqueidentifier NOT NULL , [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [CompletedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , [CapturedRowCount] bigint NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , PRIMARY KEY ([SourceCode]) |
| statements | 1 | 1 | [SnapshotId] uniqueidentifier NOT NULL , [SessionId] smallint NOT NULL , [RequestId] int NOT NULL , [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [HasStatementOffsets] bit NULL , [IsStatementOffsetValid] bit NULL , [StartOffsetBytes] int NULL , [EndOffsetBytes] int NULL , [StartCharacter] int NULL , [EndCharacter] int NULL , [StartLine] int NULL , [EndLine] int NULL , [CharacterCount] bigint NULL , [Bytes] bigint NULL , [IsTruncated] bit NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [OmissionReason] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , PRIMARY KEY ([SessionId],[RequestId]) |
| batches | 1 | 1 | [SnapshotId] uniqueidentifier NOT NULL , [SessionId] smallint NOT NULL , [RequestId] int NOT NULL , [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [SqlTextDatabaseId] int NULL , [SqlTextObjectId] int NULL , [SqlTextObjectNumber] smallint NULL , [IsEncrypted] bit NULL , [CharacterCount] bigint NULL , [Bytes] bigint NULL , [IsTruncated] bit NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [OmissionReason] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , PRIMARY KEY ([SessionId],[RequestId]) |
| inputBuffers | 1 | 1 | [SnapshotId] uniqueidentifier NOT NULL , [SessionId] smallint NOT NULL , [RequestId] int NOT NULL , [SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [EventType] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ParameterCount] smallint NULL , [CharacterCount] bigint NULL , [Bytes] bigint NULL , [IsTruncated] bit NOT NULL , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [OmissionReason] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Text] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , PRIMARY KEY ([SessionId],[RequestId]) |
| warnings | 1 | 1 | [WarningId] int IDENTITY(1,1) NOT NULL , [SessionId] smallint NULL , [RequestId] int NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [Code] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , PRIMARY KEY ([WarningId]) |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentRequests] @ResultSetArt = 'CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentRequests

Die Procedure liest aktuell sichtbare Requests frisch oder übernimmt die intern bereitgestellte Current-Overview-Aufnahme und ordnet Arbeit, Wartezeiten sowie Ausführungskontext ein.

Die Quellen umfassen Sessions, Requests, Connections, Waiting Tasks, Memory Grants, Tasks, Scheduler, Transaktionen, TempDB-Nutzung, Resource-Governor-Kataloge und bei Bedarf deduplizierte SQL-Handles.

Die Quellzeitpunkte sind je DMV dokumentiert und bilden keine transaktional atomare Gesamtaufnahme; ein Request kann während der Erfassung enden oder sich ändern.

Ohne vollständige Serverberechtigung ist die Sicht eingeschränkt. Ab SQL Server 2022 wird VIEW SERVER PERFORMANCE STATE, auf älteren Versionen VIEW SERVER STATE benötigt; sysadmin genügt.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentRequests
Version      : 4.0.0
Stand        : 2026-07-23
Typ          : Stored Procedure
Zweck        : Liefert aktive Requests mit Session-, Wait-, Memory-Grant-,
               Modul- und exakt abgegrenztem SQL-Statement- sowie Ausführungs-
               und Verschachtelungskontext.
Filter       : Session-ID-Liste, exakte bracket-aware Textlisten und getrennte
               LIKE-/Regex-Patterns.
SQL-Text     : Das laufende Statement wird über statement_start_offset und
               statement_end_offset aus dem Batch beziehungsweise persistenten
               Modul extrahiert. Optional sind vollständiger Batch-/Modultext,
               Input Buffer und Modulauflösung verfügbar.
Ausgabe      : CONSOLE (Default), RAW, TABLE, NONE sowie optionales JSON-Envelope
               mit requests (Legacy), requestContext, snapshotStatus,
               statements, batches, inputBuffers und warnings.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentRequests
Die Procedure liest aktuell sichtbare Requests frisch oder übernimmt die intern bereitgestellte Current-Overview-Aufnahme und ordnet Arbeit, Wartezeiten sowie Ausführungskontext ein.
Die Quellen umfassen Sessions, Requests, Connections, Waiting Tasks, Memory Grants, Tasks, Scheduler, Transaktionen, TempDB-Nutzung, Resource-Governor-Kataloge und bei Bedarf deduplizierte SQL-Handles.
Die Quellzeitpunkte sind je DMV dokumentiert und bilden keine transaktional atomare Gesamtaufnahme; ein Request kann während der Erfassung enden oder sich ändern.
Ohne vollständige Serverberechtigung ist die Sicht eingeschränkt. Ab SQL Server 2022 wird VIEW SERVER PERFORMANCE STATE, auf älteren Versionen VIEW SERVER STATE benötigt; sysadmin genügt.
Parameter (Deklaration mit Typ und Default; anschließend Wirkung und gültige Werte):
Unpräfixierte Pattern und like: verwenden SQL-LIKE-Wildcards; regex: und regexi: verwenden Regex-Syntax, case-sensitiv beziehungsweise case-insensitiv. Beide Regex-Modi benötigen SQL Server 2025 mit Compatibility Level 170.
Namenslisten und die zugehörigen Pattern-Parameter derselben Dimension dürfen nicht gleichzeitig belegt sein. Ungültige Listen, Kombinationen, Pattern und Steuerwerte liefern INVALID_PARAMETER.
Für Textpattern und optionale Modulauflösung wird SQL-Text gelesen; vollständiger Batch und Input Buffer können SQL-Literale und Clientinformationen enthalten. MaxSqlTextZeichen kürzt die Übertragung, anonymisiert jedoch nicht.
CONSOLE-Beispiel im Standardscope:
Ausgabelabel der Console-Ansicht: Aktuelle Requests. Die Console liefert ein beschriftetes fachliches Resultset; ohne Treffer enthält sie eine verständliche Leerzeile.
TABLE-Beispiel: Das Ziel ist eine frische lokale Seed-Tabelle mit genau einer Spalte. Der Writer ergänzt das ausgewählte Ergebnis um sein Vertragsschema.
CREATE TABLE #CurrentRequests_HelpExample (Seed int NULL);
DECLARE @CurrentRequestsTables nvarchar(max) = N'{"requests":"#CurrentRequests_HelpExample"}';
DROP TABLE #CurrentRequests_HelpExample;
TABLE-Zuordnungen sind auf requests, requestContext, snapshotStatus, statements, batches, inputBuffers und warnings begrenzt; nur benannte Ziele werden beschrieben. NULL/leer ist in TABLE ungültig; außerhalb TABLE ist NULL/leer zulässig, nichtleere Zuordnung löst Fehler 51011 aus.
JSON-Beispiel ohne Resultsets:
DECLARE @CurrentRequestsJson nvarchar(max);
Statuswerte unterscheiden verfügbare, eingeschränkte oder partielle Sicht sowie ungültige Parameter, fehlende Regex-Funktion, Berechtigungsfehler, Timeout und nicht verfügbare Objekte; Einzelquellenstatus und Warnungen bleiben separat sichtbar.
```

