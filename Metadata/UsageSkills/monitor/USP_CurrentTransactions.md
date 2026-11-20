---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentTransactions"
schema_name: "monitor"
object_name: "USP_CurrentTransactions"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Zeigt aktive Transaktionen einschließlich Session-, Request- und Logverbrauchsinformationen."
source_path: "Code/02_CurrentState/050_USP_CurrentTransactions.sql"
---

# monitor.USP_CurrentTransactions

## Zweck und Einsatz

Zeigt aktive Transaktionen einschließlich Session-, Request- und Logverbrauchsinformationen. Unterstützt Sessionlisten sowie RAW-, CONSOLE- und JSON-Ausgabe.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CurrentTransactions]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `monitor.TVF_ParseBigintList`, `[monitor].[TVF_ParseBigintList]`, `[sys].[sp_executesql]`, `[sys].[dm_tran_session_transactions]`, `[sys].[dm_tran_active_transactions]`, `[sys].[dm_tran_database_transactions]`, `[sys].[dm_exec_sessions]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SessionIds | nvarchar(max) | nein | NULL |
| @MinAlterSekunden | int | nein | 0 |
| @NurSleeping | bit | nein | 0 |
| @SystemSessionsEinbeziehen | bit | nein | 0 |
| @MitSqlText | bit | nein | 1 |
| @MaxSqlTextZeichen | int | nein | 3000 |
| @MaxZeilen | int | nein | 1000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ParentCurrentStateSnapshotId | uniqueidentifier | nein | NULL |

**@SessionIds:** @SessionIds: Typ nvarchar(max); Default=NULL. NULL lässt den Sessionfilter aus. Die Liste wird durch monitor.TVF_ParseBigintList verarbeitet: Pipe (|), Komma (,) und Semikolon (;) sind gleichwertige, mischbare Trenner; Komma und Semikolon werden auch innerhalb eckiger Klammern in Trenner umgewandelt. Pipe trennt nur außerhalb von [...]; ]] maskiert innerhalb eine schließende Klammer. Rand-Leerzeichen je Element werden entfernt, Klammern werden für die Zahlkonvertierung nicht entquotet. Exakt leere Liste und leere Elemente sind ungültig; Rohsegmente über 4000 UTF-16-Codeeinheiten, fehlerhafte Klammerstruktur und nicht in bigint konvertierbare Elemente sind ungültig. Jede Zahl muss zusätzlich 0 bis 32767 einschließlich sein; Duplikate nach Zahlkonvertierung sind ungültig. Eine gesetzte gültige Liste filtert auf passende Session-IDs; ID 0 ist zulässig.

**@MinAlterSekunden:** @MinAlterSekunden: Typ int; Default=0. Ausgelassen wird 0. NULL ist ungültig; negative Werte sind INVALID_PARAMETER. Nichtnegative ganze Sekunden bilden die Untergrenze: DATEDIFF_BIG(SECOND, transaction_begin_time, GETDATE()) >= Wert. 0 lässt jedes nichtnegative gemessene Alter zu; höhere Werte schließen jüngere Transaktionen aus.

**@NurSleeping:** @NurSleeping: Typ bit; Default=0. Ausgelassen=0. Nach SQL-Server-Konvertierung bedeutet 0 alle Sessionstatus und 1 ausschließlich Sessionstatus sleeping. NULL lässt das tatsächliche Prädikat nur für sleeping-Zeilen wahr werden; andere Zeilen fallen heraus. NULL ist keine INVALID_PARAMETER-Ablehnung. Numerische 0 wird zu 0, jeder Nichtnullwert vor Eintritt zu 1 konvertiert.

**@SystemSessionsEinbeziehen:** @SystemSessionsEinbeziehen: Typ bit; Default=0. Ausgelassen=0. Nach SQL-Server-Konvertierung bedeutet 0 ausschließlich Sessions mit is_user_process=1; 1 schließt diese Einschränkung aus und lässt auch nicht als Benutzerprozess markierte Sessions zu. NULL lässt das tatsächliche Prädikat nur für Benutzerprozess-Sessions wahr werden; andere Zeilen fallen heraus, ohne INVALID_PARAMETER. Numerische 0 wird zu 0, jeder Nichtnullwert zu 1 konvertiert.

**@MitSqlText:** @MitSqlText: Typ bit; Default=1. Ausgelassen=1. 1 materialisiert SQL-Text für Requesthandles und ordnet den aktuellen Statementtext zu. 0 lässt SQL-Textquelle und Statementextraktion aus; Text sowie Längen-/Bytewerte bleiben NULL und der Kürzungsindikator bleibt 0. NULL aktiviert den Textpfad nicht und wird nicht als ungültig abgelehnt. Numerische 0 wird zu 0, Nichtnull zu 1 konvertiert.

**@MaxSqlTextZeichen:** @MaxSqlTextZeichen: Typ int; Default=3000. Ausgelassen=3000. Ein positiver Wert begrenzt den bereits ermittelten Statementtext auf diese Anzahl Unicode-Zeichen mit SC-sicherer Projektion; Original-Zeichenanzahl, Originalbytes und Kürzungsflag werden mitgeführt. 0 oder NULL bedeutet unbegrenzt. Negativ ist INVALID_PARAMETER. Zeichen sind keine Grapheme; die Grenze erspart nicht die vorherige Quellenermittlung.

**@MaxZeilen:** @MaxZeilen: Typ int; Default=1000. Ausgelassen=1000. Positiv begrenzt die gemeinsame ausgegebene Transaktionsmenge nach Alter absteigend, SessionId und TransactionId; dieselbe Fachmenge gilt für RAW, TABLE, CONSOLE und JSON. NULL oder 0 bedeutet unbegrenzt. Negativ ist INVALID_PARAMETER. Für 1 bis 2147483646 materialisiert der Code höchstens N+1 Kandidaten zur HasMoreRows-Erkennung; bei 2147483647 ist Candidates=2147483647 und es wird kein zusätzlicher Kandidat addiert. Die Obergrenze beschränkt nicht vorherige DMV-Materialisierung, Joins, Filterung, Sortierung oder SQL-Textauflösung. TABLE/CONSOLE-Helper versprechen keine zusätzliche Sortierung.

**@ResultSetArt:** @ResultSetArt: Typ varchar(16); Default=CONSOLE. Ausgelassen=CONSOLE. Äußere SQL-Leerzeichen werden entfernt, dann wird UPPER angewendet. Die vollständige erlaubte Wertemenge: CONSOLE rendert eine lesbare Ergebnisansicht und bei leerer Menge eine verständliche Leerzeile; RAW gibt Status-, Transaktions- und Warningresultsets aus; TABLE exportiert transactions in das gemappte lokale Ziel; NONE unterdrückt fachliche Resultsets. JSON bleibt unabhängig davon möglich. NULL, leer, nur Leerzeichen und jeder andere Code sind INVALID_PARAMETER, außer ein angeforderter TABLE-Preflight hat bereits vorher abgebrochen. Codes sind nach TRIM/UPPER case-insensitiv.

**@ResultTablesJson:** @ResultTablesJson: Typ nvarchar(max); Default=NULL. Bei TABLE ist ein gültiges JSON-Objekt mit exakt case-sensitivem Schlüssel transactions und einem nichtleeren JSON-String als Wert erforderlich; der Wert bezeichnet eine vorhandene lokale #Temp-Tabelle. transactions ist der einzige erlaubte Schlüssel. Zielname beginnt mit #, darf nicht ## sein, ist höchstens 116 Zeichen lang und darf den Präfix #Monitor case-insensitiv nicht haben. Das Ziel muss im aktuellen Scope existieren, leer sein und genau eine beliebige Seed-Spalte besitzen. Ungültiges JSON/Form, leerer String, falscher Schlüssel/Typ, doppelte case-sensitive Resultnamen, doppelte Ziele (case-insensitive Zielvergleich), fehlendes/nichtleeres/anders strukturiertes Ziel führen im TABLE-Preflight zu THROW 51011. Außerhalb TABLE muss der Wert NULL, leer oder nach SQL-LTRIM/RTRIM leer sein; jede nichtleere Zuordnung wirft 51011. Der Nicht-TABLE-Guard läuft zuerst, danach TABLE-Preflight; beides liegt vor Hilfe, semantischer Parameterprüfung und fachlichen Datenquellen. Preflight kann TempDB-Metadaten-DDL am Ziel ausführen. Ausgelassen/NULL ist ohne TABLE zulässig und bei TABLE nicht ausreichend.

**@JsonErzeugen:** @JsonErzeugen: Typ bit; Default=0. Ausgelassen=0. 0 deaktiviert JSON; 1 erzeugt unabhängig von ResultSetArt ein Envelope mit meta, transactions und warnings in @Json. NULL ist INVALID_PARAMETER. SQL konvertiert numerisch 0 zu 0 und numerische Nichtnullwerte zu 1; es gibt keine weiteren eigenen Wertoptionen.

**@Json:** @Json: Typ nvarchar(max), OUTPUT; Default=NULL. Der optionale Empfänger muss nvarchar(max) sein und im EXEC als OUTPUT gebunden werden, damit der Aufrufer den Wert erhält. Die Procedure setzt den Wert unmittelbar bei Eintritt auf NULL. Bei @JsonErzeugen=1 wird das Envelope mit meta, transactions und warnings zugewiesen; andernfalls bleibt es NULL. Ein Preflight-THROW liefert kein Envelope. Ohne OUTPUT-Bindung empfängt der Aufrufer den Wert nicht.

**@PrintMeldungen:** @PrintMeldungen: Typ bit; Default=1. Ausgelassen=1. 1 erlaubt optionale Severity-10-Status- und Textkürzungswarnungen; 0 unterdrückt diese Meldungen, aber nicht Resultsets, JSON oder Hilfe. NULL wird in IF-gleich-1-Pfaden nicht als 1 erkannt und unterdrückt die Meldungen; es ist kein Parameterfehler. Numerische 0 wird zu 0, Nichtnull zu 1 konvertiert.

**@Hilfe:** @Hilfe: Typ bit; Default=0. Ausgelassen=0. Genau 1 gibt statische Hilfe per PRINT aus und kehrt vor der fachlichen Analyse zurück. 0 und NULL führen in den normalen Pfad; NULL ist kein Fehler. Numerische 0 wird zu 0, Nichtnull zu 1 konvertiert. Der Nicht-TABLE-Guard und ein angeforderter TABLE-Preflight liegen vor dem Hilfezweig; ungültige TABLE-Zuordnung kann daher trotz @Hilfe=1 mit 51011 abbrechen.

**@ParentCurrentStateSnapshotId:** @ParentCurrentStateSnapshotId: Typ uniqueidentifier; Default=NULL. NULL liest aktuelle DMV-Quellen eigenständig und ordnet eine neue EvidenceSnapshotId zu. Eine UUID verlangt kompatible CurrentState-Snapshot-Tabellen aus demselben Aufrufkontext. Geprüft werden SnapshotId, OwnerSessionId=@@SPID und ContractVersion=2; andernfalls THROW 51020. Gelesen werden SessionTransactions, ActiveTransactions, DatabaseTransactions, Sessions, Requests und bei @MitSqlText=1 SqlText für diese SnapshotId. Quellpartialität und früheste CapturedAtUtc stammen aus SourceStatus für SESSION_TRANSACTIONS, ACTIVE_TRANSACTIONS, DATABASE_TRANSACTIONS, SESSIONS, REQUESTS und SQL_TEXT. Es gibt keine zusätzliche Alters-/Frischegrenze: der Zeitstempel beschreibt die gespeicherte Erfassung, nicht die Aktualität zum späteren Lesezeitpunkt. Direkte Live-Quellen werden nacheinander materialisiert und bilden keinen atomaren Snapshot.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| transactions | 1 | 1 | [SessionId] smallint NOT NULL , [TransactionId] bigint NOT NULL , [TransactionBeginTimeUtc] datetime NULL , [TransactionAgeSeconds] bigint NULL , [TransactionType] int NULL , [TransactionState] int NULL , [OpenTransactionCount] int NULL , [LoginName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [HostName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [ProgramName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [SessionStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [RequestStatus] nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [DatabaseId] int NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL , [LogBytesUsed] bigint NULL , [LogBytesReserved] bigint NULL , [StatementTextCharacters] bigint NULL , [StatementTextBytes] bigint NULL , [StatementTextIsTruncated] bit NOT NULL DEFAULT(0) , [StatementText] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentTransactions] @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentTransactions

Erfasst aktuell sichtbare Transaktionen aus den SQL-Server-DMVs und ordnet ihnen Session-, Request- und Statementtext-Kontext zu. Das Ergebnis ist eine Momentaufnahme; es beweist weder eine dauerhafte Ursache noch einen späteren Zustand. Eine über @ParentCurrentStateSnapshotId gelesene Quelle muss aus dem kompatiblen CurrentState-Aufruf stammen.

Berechtigungen richten sich nach den abgefragten DMVs und dem verwendeten SQL-Textzugriff; fehlende Sichtbarkeit kann zu strukturiertem Teilstatus führen. Es wird keine Laufzeitberechtigung durch diese Hilfe zugesichert.

CONSOLE-Beispiel:

TABLE-Beispiel:


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_CurrentTransactions
Version      : 3.0.0
Stand        : 2026-07-23
Zweck        : Zeigt aktive Transaktionen einschließlich Session-, Request- und
               Logverbrauchsinformationen. Unterstützt Sessionlisten sowie
               RAW-, CONSOLE- und JSON-Ausgabe.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentTransactions
Erfasst aktuell sichtbare Transaktionen aus den SQL-Server-DMVs und ordnet ihnen Session-, Request- und Statementtext-Kontext zu. Das Ergebnis ist eine Momentaufnahme; es beweist weder eine dauerhafte Ursache noch einen späteren Zustand. Eine über @ParentCurrentStateSnapshotId gelesene Quelle muss aus dem kompatiblen CurrentState-Aufruf stammen.
Berechtigungen richten sich nach den abgefragten DMVs und dem verwendeten SQL-Textzugriff; fehlende Sichtbarkeit kann zu strukturiertem Teilstatus führen. Es wird keine Laufzeitberechtigung durch diese Hilfe zugesichert.
CONSOLE-Beispiel:
TABLE-Beispiel:
DECLARE @Tables nvarchar(max)=N'{"transactions":"#CurrentTransactions_HelpExample"}'; CREATE TABLE #CurrentTransactions_HelpExample([Placeholder] int); EXEC [monitor].[USP_CurrentTransactions] @ResultSetArt='TABLE',@ResultTablesJson=@Tables; SELECT * FROM [#CurrentTransactions_HelpExample]; DROP TABLE [#CurrentTransactions_HelpExample];
JSON-Beispiel:
DECLARE @J nvarchar(max); EXEC [monitor].[USP_CurrentTransactions] @ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT; SELECT @J AS [Json];
Das Envelope enthält meta, transactions und warnings.
```

