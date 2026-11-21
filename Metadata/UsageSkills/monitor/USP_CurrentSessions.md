---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentSessions"
schema_name: "monitor"
object_name: "USP_CurrentSessions"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Liefert aktuelle Sessions mit exakten Mehrfachfiltern, Pattern- Filtern und RAW-, CONSOLE- oder JSON-Ausgabe."
source_path: "Code/02_CurrentState/010_USP_CurrentSessions.sql"
---

# monitor.USP_CurrentSessions

## Zweck und Einsatz

Liefert aktuelle Sessions mit exakten Mehrfachfiltern, Pattern- Filtern und RAW-, CONSOLE- oder JSON-Ausgabe.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_CurrentSessions] im vorgesehenen Datenbankkontext. Die Procedure liest unter dem Caller `sys.dm_exec_sessions`, `sys.dm_exec_requests` und weitere ausgewählte CurrentState-DMVs; fehlende Server-Sicht oder einzelne Quellenrechte erscheinen als begrenzter Quellenstatus, nicht als vollständige Sitzungsinventur.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SessionIds | nvarchar(max) | nein | NULL |
| @EigeneSessionsModus | varchar(16) | nein | 'ALLE' |
| @AktuelleSessionEinbeziehen | bit | nein | 0 |
| @SystemSessionsEinbeziehen | bit | nein | 0 |
| @ToolHintergrundabfragenEinbeziehen | bit | nein | 0 |
| @InaktiveSessionsEinbeziehen | bit | nein | 1 |
| @LoginNames | nvarchar(max) | nein | NULL |
| @LoginNamePattern | nvarchar(4000) | nein | NULL |
| @HostNames | nvarchar(max) | nein | NULL |
| @HostNamePattern | nvarchar(4000) | nein | NULL |
| @ProgramNames | nvarchar(max) | nein | NULL |
| @ProgramNamePattern | nvarchar(4000) | nein | NULL |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MitSqlText | bit | nein | 0 |
| @MaxSqlTextZeichen | int | nein | 2000 |
| @MaxZeilen | int | nein | 500 |
| @Sortierung | varchar(32) | nein | 'CPU' |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ParentCurrentStateSnapshotId | uniqueidentifier | nein | NULL |

**@SessionIds:** @SessionIds: nvarchar(max); Default=NULL. NULL deaktiviert den Filter; ausgelassen ergibt NULL. Jeder nicht-NULL-Wert wird durch TVF_ParseBigintList geparst. Die Funktion ersetzt zuerst jedes Komma und Semikolon in Pipe-Zeichen, auch innerhalb eckiger Klammern; anschließend trennt Pipe außerhalb von [...] und ]] maskiert dort eine schließende Klammer. Äußere Leerzeichen je Segment werden getrimmt; ein einzelner leerer String ergibt EMPTY_LIST, Leerzeichen oder leere Segmente ergeben EMPTY_ITEM, fehlerhafte Klammern INVALID_BRACKET_SYNTAX und Rohsegmente über 4000 UTF-16-Codeeinheiten ITEM_TOO_LONG. Doppelte und ungültige Segmente bleiben im Helper erhalten; jedes gültige Zahlenfeld wird mit TRY_CONVERT(bigint) geparst. Klammern werden nicht entquotet, daher sind bracket-quotierte Zahlen keine gültigen IDs. Die Procedure verlangt für jede Zeile IsValid=1 und NumberValue von 1 bis 32767; sonst Status INVALID_PARAMETER. Gültige Duplikate werden anschließend gruppiert. Alle drei Trenner Pipe, Komma und Semikolon können gemischt verwendet werden.

**@EigeneSessionsModus:** @EigeneSessionsModus: varchar(16); Default='ALLE'. NULL wird durch COALESCE zu ALLE; ausgelassen ergibt ALLE. Nach LTRIM/RTRIM und UPPER sind exakt ALLE (kein OriginalLoginName-Filter), NUR (OriginalLoginName = ORIGINAL_LOGIN()) und AUSSCHLIESSEN (ISNULL(OriginalLoginName,'') <> ORIGINAL_LOGIN()) zulässig; leer oder jeder andere Wert ist INVALID_PARAMETER. Die Auswahl betrifft OriginalLoginName, nicht LoginName oder einen angenommenen Effektivlogin. Bei NULL auf der Zeile lässt AUSSCHLIESSEN die Zeile passieren, NUR nicht.

**@AktuelleSessionEinbeziehen:** @AktuelleSessionEinbeziehen: bit; Default=0. 0 und ausgelassen schließen @@SPID aus; 1 nimmt die aufrufende Session in den direkten Aufruf auf. NULL besteht die Validierung, aber das Prädikat (@AktuelleSessionEinbeziehen=1 OR session_id<>@@SPID) ist dann UNKNOWN für die eigene Session und schließt sie aus; andere Sessions passieren. SQL-Konvertierung numerischer Eingaben: 0→0, jeder numerische Nichtnullwert→1. USP_CurrentOverview reicht diesen Parameter nicht weiter, daher bleibt dort der Childdefault wirksam.

**@SystemSessionsEinbeziehen:** @SystemSessionsEinbeziehen: bit; Default=0. 0 und ausgelassen lassen nur Zeilen mit is_user_process=1 passieren; 1 lässt sichtbare System- und User-Sessions passieren. NULL ist nicht gesondert ungültig und wegen (NULL=1 OR is_user_process=1) nur bei User-Sessions TRUE; Systemzeilen werden ausgeschlossen. Numerische Eingaben werden vor Eintritt zu bit konvertiert: 0→0, jeder Nichtnullwert→1.

**@ToolHintergrundabfragenEinbeziehen:** @ToolHintergrundabfragenEinbeziehen: bit; Default=0. 0 und ausgelassen schließen Sessions aus, die TVF_ToolBackgroundQueryInfo anhand aktivierter ToolBackgroundQueryPattern-LIKE-Regeln als Tool-Hintergrundabfrage klassifiziert; 1 lässt sie passieren und gibt Klassifikationsfelder mit aus. NULL und nach bit-Konvertierung jeder Wert außer 0/1 führen ausdrücklich zu INVALID_PARAMETER; numerisches 0→0, numerischer Nichtnullwert→1 vor Eintritt. Die Erkennung ist eine Diagnoseheuristik, keine Berechtigungs- oder Sicherheitsgrenze.

**@InaktiveSessionsEinbeziehen:** @InaktiveSessionsEinbeziehen: bit; Default=1. 1 und ausgelassen lassen auch eine Session ohne Request und ohne offene Transaktion passieren. 0 schließt genau solche Zeilen aus; ein Request oder open_transaction_count>0 genügt jeweils für Aufnahme. NULL ist nicht ausdrücklich ungültig: Das Prädikat (NULL=1 OR request.session_id IS NOT NULL OR open_transaction_count>0) lässt bei UNKNOWN nur Zeilen mit Request oder offener Transaktion passieren. Numerische Werte werden vor Eintritt nach bit konvertiert, 0→0 und Nichtnull→1.

**@LoginNames:** @LoginNames: nvarchar(max); Default=NULL. NULL deaktiviert den Filter; ausgelassen ergibt NULL. Ein nicht-NULL-Argument wird als bracket-aware Pipe-Liste von TVF_ParseStringList geparst; auch leerer String und nur Leerzeichen sind ungültig (EMPTY_LIST bzw. EMPTY_ITEM), ebenso leere Segmente, fehlerhafte Klammerstruktur oder Rohsegmente über 4000 UTF-16-Codeeinheiten. Äußere Segmentleerzeichen werden entfernt; Pipe trennt außerhalb von [...], innerhalb ist es Literaleingabe, ]] maskiert dort ]. Bei bracket-quotierten Werten entfernt der Parser die äußeren Klammern und entmaskiert ]]; anschließend sind leere Werte ungültig. Die Procedure beschränkt jeden StringValue auf höchstens 128 Zeichen, gruppiert gültige Duplikate und vergleicht unter SQL_Latin1_General_CP1_CS_AS. Exklusiv mit @LoginNamePattern, sobald beide Argumente nicht NULL sind. NULL LoginName passiert den exakten Vergleich nicht.

**@LoginNamePattern:** @LoginNamePattern: nvarchar(4000); Default=NULL. NULL deaktiviert das Pattern; ausgelassen ergibt NULL. TVF_ParsePattern trimmt äußere Leerzeichen des gesamten Eingangs, case-insensitiv erkennt und entfernt genau regexi:, regex: oder like:, und trimmt den verbleibenden Inhalt nicht erneut. Kein Präfix bedeutet LIKE; andere Prefixtexte sind ebenfalls unpräfixierter LIKE-Inhalt. LIKE und like: sind case-sensitive SQL-LIKE mit %, _ und SQL-LIKE-Klassen. regex: liefert case-sensitive Regex-Flag c; regexi: case-insensitive Flag i. Nur leeres Gesamteingabepattern oder leeres Präfixergebnis ist EMPTY_PATTERN/INVALID_PARAMETER; Leerzeichen unmittelbar nach einem Präfix bleiben Inhalt. Exklusiv mit @LoginNames bei beiden nicht-NULL. Regex setzt SQL Server 2025/Majorversion 17 und Compatibility Level mindestens 170 der Installationsdatenbank voraus, andernfalls UNAVAILABLE_FEATURE. LIKE/Regex-Filter lassen NULL LoginName nicht passieren.

**@HostNames:** @HostNames: nvarchar(max); Default=NULL. NULL deaktiviert; ausgelassen ergibt NULL. Sonst bracket-aware Pipe-Liste gemäß TVF_ParseStringList: Pipe trennt außerhalb eckiger Klammern, ]] maskiert innen ], äußere Elementleerzeichen werden entfernt und bracket-quotierte Werte werden entklammert sowie entmaskiert. Leere Gesamteingabe (EMPTY_LIST), reine Leerzeichen/leere Segmente (EMPTY_ITEM), leere entquotete Werte, fehlerhafte Klammern und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Die aufrufende Procedure lehnt Parsefehler und Stringwerte über 128 Zeichen mit INVALID_PARAMETER ab, gruppiert gültige Duplikate und vergleicht HostName case-sensitive unter SQL_Latin1_General_CP1_CS_AS. Exklusiv mit @HostNamePattern bei beiderseitig nicht-NULL Argumenten; NULL HostName erfüllt den Filter nicht.

**@HostNamePattern:** @HostNamePattern: nvarchar(4000); Default=NULL. NULL deaktiviert; ausgelassen ergibt NULL. TVF_ParsePattern trimmt äußere Eingabezeichen, erkennt case-insensitiv nur regexi:, regex: oder like: und entfernt das Präfix, ohne den danach verbleibenden Inhalt erneut zu trimmen; kein oder sonstiges Präfix bedeutet LIKE. LIKE und like: verwenden case-sensitive SQL-LIKE-Semantik mit %, _ und Klassen in eckigen Klammern; regex: setzt Regex-Flag c, regexi: Flag i. EMPTY_PATTERN entsteht, wenn Gesamteingabe oder Präfixrest leer ist; Leerzeichen nach dem Präfix bleiben Musterinhalt. Exklusiv mit @HostNames bei beiderseits nicht-NULL Eingaben. Regex nur auf SQL Server 2025/Majorversion 17 und Compatibility Level >=170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. NULL HostName besteht den Filter nicht.

**@ProgramNames:** @ProgramNames: nvarchar(max); Default=NULL. NULL deaktiviert; ausgelassen ergibt NULL. Ein nicht-NULL-Wert ist eine bracket-aware Pipe-Liste des TVF_ParseStringList: Pipe außerhalb [...] trennt, innerhalb gehört es zum Wert, ]] maskiert eine schließende Klammer; äußere Elementleerzeichen werden getrimmt, bracket-quotierte Werte entklammert und entmaskiert. Leere Eingabe (EMPTY_LIST), Leerzeichen/leere Segmente (EMPTY_ITEM), leere entquotete Werte, fehlerhafte Klammerstruktur und Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig. Die Procedure verlangt gültige Werte bis 128 Zeichen, fasst Duplikate zusammen und vergleicht case-sensitive mit SQL_Latin1_General_CP1_CS_AS. Exklusiv mit @ProgramNamePattern, wenn beide nicht NULL sind; NULL ProgramName ist kein Treffer.

**@ProgramNamePattern:** @ProgramNamePattern: nvarchar(4000); Default=NULL. NULL/ausgelassen deaktiviert. Der Helper trimmt außen, erkennt ohne Beachtung der Schreibweise genau regexi:, regex: und like:, entfernt das Präfix und trimmt den Rest nicht erneut; ohne diese Präfixe gilt LIKE. LIKE ist case-sensitive SQL-LIKE mit %, _ und []-Klassen; regex: ist case-sensitive (Flag c), regexi: case-insensitive (Flag i). Ein leeres Gesamteingabepattern oder ein leeres Präfixresultat wird EMPTY_PATTERN und in der Procedure INVALID_PARAMETER; nach Präfix verbleibende Leerzeichen sind Inhalt. Exklusiv mit @ProgramNames, sobald beide Eingaben nicht NULL sind. Regex erfordert SQL Server 2025/Majorversion 17 plus Compatibility Level mindestens 170 der Installationsdatenbank; andernfalls UNAVAILABLE_FEATURE. NULL ProgramName wird nicht als Treffer behandelt.

**@DatabaseNames:** @DatabaseNames: nvarchar(max); Default=NULL. NULL deaktiviert; ausgelassen ergibt NULL. Sonst bracket-aware Pipe-Liste über TVF_ParseSqlNameList und TVF_ParsePipeList: Pipe trennt außerhalb von [...], ]] maskiert innen ], äußere Segmentleerzeichen werden entfernt; gleiche Segmente bleiben im Parser erhalten. Leerer String ist EMPTY_LIST; Leerzeichen oder leere Segmente sind EMPTY_ITEM; über 4000 UTF-16-Codeeinheiten ITEM_TOO_LONG; fehlerhafte Klammern werden abgelehnt. Jede gültige Eingabe muss nach PARSENAME genau einen einteiligen Namen ergeben und höchstens 128 Zeichen haben; mehrteilige Namen, ungültige SQL-Namen und zu lange Werte führen in der Procedure zu INVALID_PARAMETER. Es wird nicht gegen Datenbankexistenz geprüft. Gültige Duplikate werden nach NameValue gruppiert und unter SQL_Latin1_General_CP1_CS_AS case-sensitive verglichen. Exklusiv mit @DatabaseNamePattern, wenn beide Argumente nicht NULL sind. NULL DatabaseName erfüllt die aktive Gleichheit nicht.

**@DatabaseNamePattern:** @DatabaseNamePattern: nvarchar(4000); Default=NULL. NULL oder ausgelassen deaktiviert; TVF_ParsePattern trimmt äußere Zeichen, erkennt case-insensitiv genau regexi:, regex: und like:, entfernt das Präfix und trimmt den Rest nicht erneut. Ohne/bei sonstigem Präfix wird SQL-LIKE verwendet. LIKE/like: ist case-sensitive und unterstützt %, _ und []-Klassen; regex: verwendet Flag c (case-sensitive), regexi: Flag i (case-insensitive). Leerer Gesamteingang oder leerer Präfixrest führt zu EMPTY_PATTERN und dann INVALID_PARAMETER; whitespace nach Präfix bleibt Inhalt. Exklusiv mit @DatabaseNames, sobald beide nicht NULL sind. Regex ist nur mit SQL Server 2025/Majorversion 17 und Compatibility Level >=170 in der Installationsdatenbank verfügbar, sonst UNAVAILABLE_FEATURE. SQL-LIKE und Regex auf NULL DatabaseName lassen die Zeile nicht passieren.

**@HighImpactConfirmed:** @HighImpactConfirmed: bit; Default=0. Ausgelassen ist 0; im Procedure-Body wird der Parameter nicht ausgewertet, geprüft oder weitergereicht und er bestätigt/freigibt/ändert keine Ausführung. NULL, 0 und 1 haben daher hier keine Wirkung; SQL konvertiert numerische Eingaben vor Eintritt zu bit (0→0, Nichtnull→1). Dieses Objekt besitzt dafür kein High-Impact-Gate und keine zusätzliche Berechtigungsgruppe; die tatsächliche Quellensicht folgt den festgelegten DMV-Berechtigungen.

**@MitSqlText:** @MitSqlText: bit; Default=0. 0/ausgelassen überspringt sys.dm_exec_sql_text und lässt CurrentStatement sowie BatchText NULL; 1 löst deduplizierte, nicht-NULL Request-sql_handle und letzte Connection-most_recent_sql_handle vor Ergebnisfiltern und Zeilenlimit auf und projektiert verfügbare Texte. NULL ist nicht als ungültig abgefangen und wirkt im IF @MitSqlText=1-Pfad wie aus; numerisch 0→0, Nichtnull→1 vor Eintritt. Text kann bei direktem Aufruf auch von einer inaktiven Session über den letzten Connection-Handle stammen; im Parent-Snapshot wird Text nur aus dem Snapshot übernommen.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen: int; Default=2000 Zeichen je CurrentStatement und BatchText. NULL oder 0 ist unbegrenzt; ausgelassen nutzt 2000; negativ führt zu INVALID_PARAMETER. Der Writer zählt Unicodezeichen einschließlich abschließender Leerzeichen und projiziert erst für behaltene Ergebniszeilen. Bei positiver Grenze wird nur ein längerer Wert auf die Grenze gekürzt; SC-Collation zählt ein Surrogatpaar als ein Zeichen und trennt das Paar nicht. NULL-Text bleibt NULL. Originalzeichen und Bytes sowie Kürzungsflag werden ausgegeben und Kürzungen über den Warnhelper gemeldet. Diese Begrenzung anonymisiert nicht und reduziert weder vorgelagerte Textauflösung noch alle Quellenarbeit.

**@MaxZeilen:** @MaxZeilen: int; Default=500 Sessionzeilen. NULL oder 0 hebt das Ausgabelimit auf; ausgelassen nutzt 500, negative Werte sind INVALID_PARAMETER. Bei positivem N wird ohne Regex früh höchstens N+1 Kandidatenzeilen materialisiert; bei aktivem Regex wird das frühe Limit aufgehoben und erst nach Regexfilterung die sortierte Ergebnismenge auf N gekürzt. hasMoreRows=1 wird gesetzt, wenn nach Kandidaten-/Regexfilterung mehr als N passende Zeilen vorliegen. Filter- und Quellenerhebung sowie optionale Textauflösung sind dadurch nicht allgemein auf N+1 begrenzt. Dieselbe begrenzte Menge speist die Ausgabeformen.

**@Sortierung:** @Sortierung: varchar(32); Default='CPU'. NULL wird via COALESCE zu CPU; Eingabe wird mit LTRIM/RTRIM und UPPER normalisiert. Zulässig sind exakt CPU (Request-CPU, sonst Session-CPU, absteigend), READS (Request-logical_reads, sonst Session-logical_reads, absteigend), WRITES (Request-writes, sonst Session-writes, absteigend), LOGIN (login_time absteigend) und SESSION (session_id aufsteigend). Ungültiger normalisierter Wert ist INVALID_PARAMETER. Gleichstände werden bei Kandidatenauswahl nach Session-ID aufgelöst; RAW sortiert nach Schlüssel und Session-ID, JSON nach Session-ID, TABLE und CONSOLE-Helper geben keine Zeilenordnung zu.

**@ResultSetArt:** @ResultSetArt: varchar(16); Default='CONSOLE'. NULL wird bei Normalisierung zu leer und ist ungültig; sonst LTRIM/RTRIM/UPPER und exakt CONSOLE, RAW, TABLE oder NONE. CONSOLE liefert Status und danach lesbare Sessionansicht über InternalEmitConsoleResult; RAW liefert Status mit 13 Feldern und Sessiondaten mit 51 Session- plus zehn Wait-Feldern; TABLE schreibt das benannte sessions-Ziel mit 51 Sessionfeldern, ohne Reihenfolgegarantie; NONE unterdrückt Resultsets. Ausgabeart verändert nicht die Fachmenge; JSON wird unabhängig davon nur mit @JsonErzeugen gesteuert. ResultSetArt=TABLE verlangt ein gültiges Zielmapping.

**@ResultTablesJson:** @ResultTablesJson: nvarchar(max); Default=NULL. Nur in normalisiertem ResultSetArt=TABLE ist ein gültiges Mapping erforderlich: ein nichtleeres JSON-Objekt mit exakt einem case-sensitiven Key sessions und einem nichtleeren JSON-Stringwert, zum Beispiel {"sessions":"#CurrentSessions"}. Der Wert muss eine bereits vorhandene lokale #Temp-Tabelle bezeichnen; ##-Tabellen, Namen über 116 Zeichen und das case-insensitive reservierte Präfix #Monitor sind unzulässig. Zielnamen dürfen nicht doppelt vorkommen; das Ziel muss leer sein und genau eine Seed-Spalte haben. Bei Nicht-TABLE ist NULL, leer oder ausschließlich gewöhnliche Leerzeichen U+0020, die LTRIM/RTRIM entfernt zulässig; eine nichtleere Map wirft 51011. Der Nicht-TABLE-Map-Guard läuft vor Hilfe und Parameterprüfung; TABLE-Preflight läuft ebenfalls vor Hilfe und validiert JSON-Objekt, Stringtyp, erlaubten Key, Eindeutigkeit, Zielname, Existenz, Leere und Seedspaltenform. Erfolgreiches Mapping garantiert keine Zeile oder Frische; der Writer passt das leere Seed-Ziel an das sessions-Ausgabeschema an.

**@JsonErzeugen:** @JsonErzeugen: bit; Default=0. 0/ausgelassen deaktiviert JSON; exakt 1 erzeugt unabhängig von ResultSetArt das Envelope in @Json. NULL wird nicht zurückgewiesen, ist aber nicht =1 und lässt den zuvor zu NULL gesetzten OUTPUT-Wert NULL. Numerische Werte werden vor Eintritt zu bit konvertiert (0→0, jeder Nichtnullwert→1).

**@Json:** @Json: nvarchar(max) OUTPUT; Default=NULL. Empfangsparameter zur Bindung einer aufruferseitigen Variable vom Typ nvarchar(max); im EXEC muss die Variable mit OUTPUT gebunden werden, damit der Caller den Rückgabewert empfängt. Der Procedure-Einstieg setzt den Wert stets auf NULL; wenn @JsonErzeugen=1 wird das Envelope geschrieben, sonst bleibt er NULL. Ausgelassene Empfangsbindung stellt keinen Callerwert bereit.

**@PrintMeldungen:** @PrintMeldungen: bit; Default=1. Bei 1 und Status ungleich AVAILABLE gibt die Procedure eine Severity-10-Warnmeldung mit NOWAIT aus; 0 unterdrückt diese Zusatzmeldung. Ausgelassen ergibt 1. NULL wird nicht gesondert validiert und erfüllt IF =1 nicht, daher keine Warnung; numerische Eingaben werden vor Eintritt zu bit konvertiert (0→0, Nichtnull→1). Resultsets und JSON bleiben davon unabhängig.

**@Hilfe:** @Hilfe: bit; Default=0. Nur exakt 1 aktiviert PRINT-Hilfe und Rückkehr vor fachlicher Parameterprüfung und Datenquellenzugriff; ausgelassen und NULL führen in den normalen Pfad, numerische Werte werden vor Eintritt zu bit konvertiert. Vor dem Hilfezweig läuft jedoch der Nicht-TABLE-Guard: eine nichtleere nach LTRIM/RTRIM verbleibende ResultTablesJson-Eingabe bei anderer Ausgabeart wirft 51011. Bei ResultSetArt=TABLE läuft zuvor zusätzlich das Mapping-Preflight mit den Form-, Key-, Ziel- und Seedprüfungen; ungültige Zuordnung wirft 51011 statt Hilfe zu liefern. Der Procedure-Einstieg setzt @Json bereits vor den Guards auf NULL; nach erfolgreichem Preflight erzeugt Hilfe keine fachlichen Resultsets.

**@ParentCurrentStateSnapshotId:** @ParentCurrentStateSnapshotId: uniqueidentifier; Default=NULL. NULL oder ausgelassen wählt direkte frische Quellenreads. Eine gesetzte GUID aktiviert den internen USP_CurrentOverview-Consumerpfad und muss in dessen lokalen Snapshottabellen zur aktuellen @@SPID-Session sowie ContractVersion=2 gehören; Andernfalls entsteht ein Status für einen ungültigen Parent-Snapshot oder ein passender Fehlerstatus mit partieller Sicht. Der Consumerpfad übernimmt Sessions, Requests, Connections und bei @MitSqlText=1 den SQL-Text samt Quellenstatus aus diesem aufrufinternen Snapshot; es entsteht keine Frischegarantie. Anwender sollen diesen internen Parameter nicht selbst setzen.

## Resultate und Ausgabe

RAW: Status, Sessions. CONSOLE: lesbare Status-/Sessionansicht.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| sessions | 1 | 1 | [SessionId] smallint NOT NULL, [RequestId] int NULL, [IsUserProcess] bit NOT NULL , [SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [OriginalLoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [IsToolBackgroundQuery] bit NOT NULL , [ToolBackgroundRuleCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ToolBackgroundCategory] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ToolBackgroundDetection] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ToolBackgroundConfidence] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ClientInterfaceName] nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [LoginTime] datetime NULL , [LastRequestStartTime] datetime NULL, [LastRequestEndTime] datetime NULL , [DatabaseId] smallint NULL, [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [OpenTransactionCount] int NULL, [TransactionIsolationLevel] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SessionCpuMs] int NULL, [SessionReads] bigint NULL, [SessionWrites] bigint NULL , [SessionLogicalReads] bigint NULL, [SessionMemoryMb] decimal(19,2) NULL , [SessionRowCount] bigint NULL, [RequestCpuMs] int NULL, [RequestElapsedMs] int NULL , [RequestLogicalReads] bigint NULL, [RequestReads] bigint NULL, [RequestWrites] bigint NULL , [BlockingSessionId] smallint NULL, [WaitType] nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [WaitTimeMs] int NULL , [WaitResource] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [PercentComplete] real NULL , [ClientNetAddress] varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [AuthScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [CurrentStatementCharacters] bigint NULL, [CurrentStatementBytes] bigint NULL , [CurrentStatementIsTruncated] bit NOT NULL DEFAULT(0), [CurrentStatement] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [BatchTextCharacters] bigint NULL, [BatchTextBytes] bigint NULL , [BatchTextIsTruncated] bit NOT NULL DEFAULT(0), [BatchText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentSessions] @ResultSetArt = 'CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Diese Hilfe beschreibt die aktuelle Sessioninventarisierung, ihre Quellen und ihre Ausgabeformen.

Der direkte Aufruf liest sys.dm_exec_sessions, sys.dm_exec_requests und sys.dm_exec_connections nacheinander mit NOLOCK; optional löst sys.dm_exec_sql_text die eindeutigen Request- und letzten Connection-Handles auf.

Sessionzähler wie SessionCpuMs, SessionReads, SessionWrites und SessionLogicalReads kumulieren seit Sessionbeginn, während Requestwerte und Verbindungsdaten den Lesezeitpunkt beschreiben; die nacheinander gelesenen Quellen bilden keinen atomaren Snapshot.

Pro Session wird der Request mit der kleinsten sichtbaren request_id korreliert; eine inaktive Session kann deshalb Request- und DatabaseName-Werte als NULL liefern, und mehrere sichtbare Connections können die Zeilengranularität beeinflussen.

Der sichtbare Scope hängt von Serverberechtigungen ab: ab SQL Server 2022 wird VIEW SERVER PERFORMANCE STATE benötigt, auf früheren Versionen VIEW SERVER STATE; sysadmin gilt als Vollsicht, eingeschränkte Quellensicht kann AVAILABLE_LIMITED ergeben.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentSessions
Version      : 2.2.0
Stand        : 2026-07-22
Typ          : Stored Procedure
Zweck        : Liefert aktuelle Sessions mit exakten Mehrfachfiltern, Pattern-
               Filtern und RAW-, CONSOLE- oder JSON-Ausgabe.
SQL-Version  : SQL Server 2019 oder neuer; Regex ab SQL Server 2025 und
               Compatibility Level 170.
Listen       : | trennt außerhalb von [...]. Werte bleiben case-sensitiv.
Steuerwerte  : werden getrimmt und case-insensitiv normalisiert.
Resultsets   : RAW: Status, Sessions. CONSOLE: lesbare Status-/Sessionansicht.
               NONE: keine Resultsets. JSON: meta, sessions, warnings.
```

### Weitere bestehende Hilfehinweise

```text
Diese Hilfe beschreibt die aktuelle Sessioninventarisierung, ihre Quellen und ihre Ausgabeformen.
Der direkte Aufruf liest sys.dm_exec_sessions, sys.dm_exec_requests und sys.dm_exec_connections nacheinander mit NOLOCK; optional löst sys.dm_exec_sql_text die eindeutigen Request- und letzten Connection-Handles auf.
Sessionzähler wie SessionCpuMs, SessionReads, SessionWrites und SessionLogicalReads kumulieren seit Sessionbeginn, während Requestwerte und Verbindungsdaten den Lesezeitpunkt beschreiben; die nacheinander gelesenen Quellen bilden keinen atomaren Snapshot.
Pro Session wird der Request mit der kleinsten sichtbaren request_id korreliert; eine inaktive Session kann deshalb Request- und DatabaseName-Werte als NULL liefern, und mehrere sichtbare Connections können die Zeilengranularität beeinflussen.
Der sichtbare Scope hängt von Serverberechtigungen ab: ab SQL Server 2022 wird VIEW SERVER PERFORMANCE STATE benötigt, auf früheren Versionen VIEW SERVER STATE; sysadmin gilt als Vollsicht, eingeschränkte Quellensicht kann AVAILABLE_LIMITED ergeben.
Tool-Erkennung ist eine Diagnoseheuristik aus aktivierten LIKE-Regeln und kein Sicherheitsmerkmal; die Klassifikation liefert TVF_ToolBackgroundQueryInfo mit RuleCode, Category, Detection und Confidence.
Die Filter verwenden TVF_ParseBigintList, TVF_ParseStringList, TVF_ParseSqlNameList und TVF_ParsePattern; Statementprojektion und Warnungen nutzen TVF_StatementText, TVF_WaitTypeInfo, InternalProjectUnicodeTextColumn und InternalEmitTruncationWarning.
Für TABLE prüft InternalPrepareSingleResultTable die Zuordnung sessions. InternalWriteResultTable passt ein bereits vorhandenes, leeres lokales #Temp-Ziel mit genau einer Seedspalte an das exportierte Schema an. Fehlende, nichtleere oder anders aufgebaute Ziele sowie unzulässige Zuordnungen werden abgelehnt.
Im JSON enthält meta unter anderem Status, Teilstatus, Snapshot-ID, angeforderte und gelieferte Zeilen sowie hasMoreRows; sessions enthält die Sessionwerte und drei Wait-Einordnungen, warnings kann auch einen erfolgreichen Detailhinweis enthalten.
RAW gibt zuerst den Status mit 13 Feldern und danach Sessionwerte mit 51 Feldern sowie zehn Wait-Feldern aus; TABLE exportiert die 51 Sessionfelder, CONSOLE ergänzt Status und eine lesbare Übersicht, und die Tabellenreihenfolge ist für TABLE nicht zugesichert.
Mögliche Statuswerte sind AVAILABLE, AVAILABLE_LIMITED, INVALID_PARAMETER, UNAVAILABLE_FEATURE, DENIED_PERMISSION, TIMEOUT, UNAVAILABLE_OBJECT, ERROR_HANDLED und ein abgelehnter Parent-Kontext; Fehlerdetails erscheinen in Status, JSON-Metadaten oder warnings, sofern ein JSON angefordert wurde.
Bei AVAILABLE_LIMITED sind mindestens eine relevante Quelle oder der Parent-Snapshot eingeschränkt; eine leere oder gefilterte Menge beweist nicht, dass außerhalb des sichtbaren Scopes keine Session existiert.
Beispiel CONSOLE-Aufruf:
Beispiel TABLE-Aufruf; das leere Seed-Ziel wird vom Writer an das sessions-Schema angepasst:
CREATE TABLE #CurrentSessions_HelpExample ([Seed] int NULL);
DROP TABLE #CurrentSessions_HelpExample;
Beispiel JSON-OUTPUT ohne Resultset:
DECLARE @CurrentSessionsJson nvarchar(max);
Parameterdefinitionen einschließlich Typ und Standardwert stehen in Metadata/Inventory/Parameters.csv.
Bei bit-Parametern wandelt SQL Server numerische Nichtnullwerte vor Procedure-Eintritt in 0 oder 1 um; NULL wird nur beim Tool-Schalter als ungültig geprüft und folgt bei den übrigen Schaltern den jeweiligen Bedingungen.
```

