---
skill_format_version: "1.0.0"
name: "monitor.USP_CurrentCursorAnalysis"
schema_name: "monitor"
object_name: "USP_CurrentCursorAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "OPS-007: bounded, session-scoped cursor evidence; opt-in only."
source_path: "Code/02_CurrentState/110_USP_CurrentCursorAnalysis.sql"
---

# monitor.USP_CurrentCursorAnalysis

## Zweck und Einsatz

OPS-007: bounded, session-scoped cursor evidence; opt-in only.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_CurrentCursorAnalysis]. Die Quelle nennt insbesondere `sys.dm_exec_cursors`, `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParseBigintList]`, `[sys].[dm_exec_cursors]`, `[monitor].[InternalEmitConsoleResult]`, `[monitor].[InternalWriteResultTable]`, `[sys].[sp_executesql]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @IncludeCursorDetails | bit | nein | 0 |
| @SessionIds | nvarchar(max) | nein | NULL |
| @MaxZeilen | int | nein | 200 |
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

**@IncludeCursorDetails:** @IncludeCursorDetails: bit, Default 0. 0 liest keine Zeilen aus sys.dm_exec_cursors und lässt Status NOT_EXECUTED (sofern kein Parameterfehler vorliegt); 1 aktiviert den Quellscan. NULL ist ungültig und ergibt INVALID_PARAMETER. Andere bit-Werte sind bei T-SQL-Konvertierung nicht darstellbar. Das Opt-in betrifft genau @TargetSessionId; es erfolgt kein instanzweiter Cursor-Scan.

**@SessionIds:** @SessionIds: nvarchar(max), Default NULL. NULL sowie eine nach LTRIM/RTRIM leere Eingabe (äußere U+0020-Leerzeichen) wählen die aufrufende Session @@SPID. Sonst ersetzt die Funktion zunächst jedes Komma und Semikolon durch Pipe und zerlegt danach an Pipes außerhalb bracket-quotierter Bereiche [ ... ]; innerhalb eines solchen Bereichs trennt Pipe nicht und ]] maskiert eine schließende Klammer. Der Parser trimmt äußere U+0020-Leerzeichen, entquotet Klammern aber nicht. Ein Rohsegment über 4000 UTF-16-Codeeinheiten wird ITEM_TOO_LONG; leere Segmente werden EMPTY_ITEM und ungültige/unvollständige Klammerstruktur INVALID_BRACKET_SYNTAX. Für eine gültige Parserzeile muss TRY_CONVERT(bigint, ItemText) gelingen. Nach der Zahlenkonvertierung muss genau ein gültiger Zahlenwert im Bereich 1 bis 32767 verbleiben. Mehrere Elemente (auch Duplikate), ungültige Segmente, nicht konvertierbare Zahlenwerte und Werte außerhalb des Bereichs ergeben INVALID_PARAMETER. Es findet keine Deduplikation statt und es wird nicht vorab geprüft, ob die Session existiert oder sichtbar ist. Tabs oder sonstige Zeichen werden nicht pauschal als ungültig eingestuft; die Parser- und TRY_CONVERT-Ergebnisse entscheiden.

**@MaxZeilen:** @MaxZeilen: int, Default 200. NULL wird ausdrücklich zu 0 normalisiert. Negative Werte ergeben INVALID_PARAMETER. 0 bedeutet keine praktische Limitierung bis TOP(2147483647), nicht null Zeilen; positive Werte begrenzen die in die lokale Tabelle übernommenen Zeilen auf höchstens diesen Wert. Auswahlreihenfolge für TOP: WorkerTime absteigend, Reads absteigend, CursorId aufsteigend. JSON ordnet WorkerTime absteigend, CursorId aufsteigend; die materialisierten Zeilen bleiben dieselben.

**@ResultSetArt:** @ResultSetArt: varchar(16), Default 'CONSOLE'. NULL und nach LTRIM/RTRIM (Entfernung äußerer U+0020-Leerzeichen) leere Eingaben ergeben nach UPPER einen ungültigen Modus und INVALID_PARAMETER. Geschlossene Werte: CONSOLE erzeugt über InternalEmitConsoleResult ein lesbares Resultset mit Ergebnislabel cursors (bei leerer Quelle eine verständliche Leerzeile); RAW gibt ein Status-/Zähler-Resultset und nur bei @IncludeCursorDetails=1 zusätzlich Cursorzeilen aus; TABLE materialisiert die erlaubte Zuordnung cursors in eine geprüfte lokale #Temp-Zieltabelle; NONE gibt keine fachlichen Resultsets aus. Es gibt keine weiteren erlaubten Werte. Groß-/Kleinschreibung wird durch UPPER vereinheitlicht, äußere U+0020-Leerzeichen werden entfernt. CONSOLE und TABLE setzen intern den Modus für die Statusmeldung auf NONE; @PrintMeldungen=1 kann daher auch bei diesen beiden Ausgabearten eine Status-PRINT-Meldung auslösen.

**@ResultTablesJson:** @ResultTablesJson: nvarchar(max), Default NULL. Für CONSOLE, RAW und NONE muss der Wert NULL oder nach LTRIM/RTRIM (Entfernung äußerer U+0020-Leerzeichen) leer sein; ein anderer Wert löst 51011 aus. Für TABLE ist ein gültiges JSON-Objekt mit genau der Zuordnung des Resultnamens cursors zu einer lokalen #Temp-Tabelle erforderlich, z. B. N'{"cursors":"#CursorExport"}'. NULL/leer, falsche Schlüssel oder Typen, globale ##- und permanente Tabellen, reserviertes Präfix #Monitor, zu lange/fehlende Ziele sowie doppelte Ziele werden abgelehnt. Das Ziel muss vorab vorhanden und leer sein und genau eine Seed-/Dummy-Spalte haben; diese wird an das Cursor-Resultatschema angepasst. Die TABLE-Vorprüfung läuft vor Parameter-/Quellenprüfung und kann bei Fehlern mit THROW abbrechen.

**@JsonErzeugen:** @JsonErzeugen: bit, Default 0. 0 oder NULL erzeugt kein JSON; @Json bleibt NULL. 1 erzeugt @Json als JSON-Array der materialisierten Cursorzeilen ohne Status-/Fehler-Envelope; bei null Cursorzeilen ist der Wert []. Das Array enthält dieselbe begrenzte Materialisierung und wird nach WorkerTime absteigend und CursorId aufsteigend geordnet. Der Parameter wird nicht separat validiert; nur der Vergleich mit 1 aktiviert die Erzeugung.

**@Json:** @Json: nvarchar(max), OUTPUT, Default NULL (Bindung als OUTPUT erforderlich, wenn der Aufrufer den Wert empfangen soll). Der bisherige Eingabewert wird beim Eintritt sofort überschrieben und auf NULL gesetzt; bei @JsonErzeugen=1 wird er später durch das JSON-Array ersetzt, sonst bleibt er NULL. Bei @Hilfe=1 ist er ebenfalls bereits NULL, weil die Initialisierung vor dem Hilfezweig liegt. Das JSON enthält keine Status- oder Fehlerhülle.

**@PrintMeldungen:** @PrintMeldungen: bit, Default 1. 1 gibt nach der Analyse Status: <Status> per PRINT aus, wenn der interne Modus NONE ist; dies gilt direkt für NONE und wegen der internen Umschaltung auch für CONSOLE und TABLE. 0 oder NULL unterdrückt diese Statusmeldung. Der Hilfezweig liegt davor und druckt seine Hilfe unabhängig von diesem Parameter.

**@Hilfe:** @Hilfe: bit, Default 0. 1 druckt die eingebettete Hilfe und Beispielaufrufe und kehrt vor Lock-Timeout-Änderung, TABLE-Vorprüfung, Parameter-Validierung und Quellenzugriff zurück. 0 oder NULL setzt den normalen Pfad fort. Im Hilfezweig wird @Json zuvor auf NULL gesetzt; die vier Status-/Fehler-OUTPUT-Parameter werden nicht beschrieben und behalten daher ihre übergebenen Eingangswerte. Die Hilfe-PRINTs hängen nicht von @PrintMeldungen ab.

**@StatusCodeOut:** @StatusCodeOut: varchar(40), OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert überschrieben. Geschlossene Statusmenge: NOT_EXECUTED bedeutet, dass Cursordetails nicht angefordert wurden; INVALID_PARAMETER kennzeichnet ungültige Parameter; AVAILABLE bedeutet, dass mindestens eine Cursorzeile gelesen wurde; AVAILABLE_EMPTY bedeutet, dass keine Cursorzeile sichtbar war; DENIED_PERMISSION kennzeichnet abgefangene Fehler 229, 297, 300, 371 oder 916 beim DMV-Zugriff; SOURCE_UNAVAILABLE kennzeichnet einen anderen abgefangenen Fehler beim Quellzugriff. Der Hilfezweig kehrt vor der Zuweisung zurück und lässt den Eingangswert bestehen. Ein THROW vor normalem Rücklauf erreicht die Zuweisung am Prozedurende nicht.

**@IsPartialOut:** @IsPartialOut: bit, OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert mit 0 (vollständig im Modulstatus) oder 1 überschrieben. 1 wird bei INVALID_PARAMETER und abgefangenem DMV-Fehler gesetzt. Der Hilfezweig weist den Parameter nicht zu; ein THROW vor normalem Rücklauf erreicht die Zuweisung nicht.

**@ErrorNumberOut:** @ErrorNumberOut: int, OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert mit der abgefangenen SQL-Fehlernummer überschrieben; ohne abgefangenen Fehler bleibt das Ergebnis NULL. Der Hilfezweig weist ihn nicht zu; ein THROW vor normalem Rücklauf erreicht die Zuweisung nicht.

**@ErrorMessageOut:** @ErrorMessageOut: nvarchar(2048), OUTPUT, Default NULL (OUTPUT-Bindung erforderlich für Empfang). Bei normalem Rücklauf wird der Eingangswert mit der Validierungs-/abgefangenen DMV-Fehlermeldung überschrieben; wenn keine gesetzt ist, ist das Ergebnis NULL. Der Hilfezweig weist ihn nicht zu; ein THROW vor normalem Rücklauf erreicht die Zuweisung nicht.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| cursors | 1 | 1 | [SessionId] int NULL , [CursorId] int NULL , [CursorName] nvarchar(256) NULL , [Properties] nvarchar(256) NULL , [CreationTime] datetime NULL , [IsOpen] bit NULL , [FetchStatus] int NULL , [WorkerTime] bigint NULL , [Reads] bigint NULL , [Writes] bigint NULL , [DormantDuration] bigint NULL , [FindingContext] varchar(40) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_CurrentCursorAnalysis] @IncludeCursorDetails=1,@ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_CurrentCursorAnalysis

Erfasst Cursor der aktuell gewählten Session ausschließlich aus sys.dm_exec_cursors(@TargetSessionId). Ohne @IncludeCursorDetails=1 wird kein Cursor-Quellscan ausgeführt; die Analyse ist opt-in und liefert eine begrenzte Momentaufnahme, keine Aussage über frühere oder spätere Cursorzustände.

Die Quelle verlangt ausreichende Sichtbarkeit für sys.dm_exec_cursors; bei verweigertem Zugriff oder nicht verfügbarer Quelle stehen Status und Fehler im RAW-Status und in den Status-OUTPUTs. JSON enthält ausschließlich Cursorzeilen und keine Status- oder Fehlerfelder.

CONSOLE-Beispiel:

TABLE-Beispiel:


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
OPS-007: bounded, session-scoped cursor evidence; opt-in only.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_CurrentCursorAnalysis
Erfasst Cursor der aktuell gewählten Session ausschließlich aus sys.dm_exec_cursors(@TargetSessionId). Ohne @IncludeCursorDetails=1 wird kein Cursor-Quellscan ausgeführt; die Analyse ist opt-in und liefert eine begrenzte Momentaufnahme, keine Aussage über frühere oder spätere Cursorzustände.
Die Quelle verlangt ausreichende Sichtbarkeit für sys.dm_exec_cursors; bei verweigertem Zugriff oder nicht verfügbarer Quelle stehen Status und Fehler im RAW-Status und in den Status-OUTPUTs. JSON enthält ausschließlich Cursorzeilen und keine Status- oder Fehlerfelder.
CONSOLE-Beispiel:
TABLE-Beispiel:
DECLARE @Tables nvarchar(max)=N'{"cursors":"#CurrentCursorAnalysis_HelpExample"}'; CREATE TABLE [#CurrentCursorAnalysis_HelpExample]([Placeholder] int); EXEC [monitor].[USP_CurrentCursorAnalysis] @IncludeCursorDetails=1,@ResultSetArt='TABLE',@ResultTablesJson=@Tables; SELECT * FROM [#CurrentCursorAnalysis_HelpExample]; DROP TABLE [#CurrentCursorAnalysis_HelpExample];
JSON-Beispiel:
DECLARE @J nvarchar(max); EXEC [monitor].[USP_CurrentCursorAnalysis] @IncludeCursorDetails=1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@J OUTPUT; SELECT @J AS [Json];
Die Ausgabe ist ein JSON-Array.
```

