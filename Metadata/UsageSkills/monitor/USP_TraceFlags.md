---
skill_format_version: "1.0.0"
name: "monitor.USP_TraceFlags"
schema_name: "monitor"
object_name: "USP_TraceFlags"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure liest aktive globale und zur aufrufenden Session gehörende Trace Flags über DBCC TRACESTATUS(-1)."
source_path: "Code/08_ServerHealth/060_USP_TraceFlags.sql"
---

# monitor.USP_TraceFlags

## Zweck und Einsatz

Die Procedure liest aktive globale und zur aufrufenden Session gehörende Trace Flags über DBCC TRACESTATUS(-1).

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_TraceFlags] im vorgesehenen Datenbankkontext. Die Procedure führt lesend `DBCC TRACESTATUS` aus. Dessen serverseitige Berechtigung wird beim Aufruf geprüft; ohne sie kann die Quelle nicht als vollständig gelten.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Eingabeform: SQL-bit; 0 bedeutet unterdrückt die Informationsmeldung bei einem Nicht-AVAILABLE-Status, 1 bedeutet gibt eine Severity-10-Meldung mit Modulname und Fehlertext aus. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default.

**@Hilfe:** @Hilfe bit; Default: 0. Eingabeform: SQL-bit; 0 bedeutet führt nach dem Preflight die DBCC-Erhebung ohne Hilfetext fort, 1 bedeutet druckt Hilfe und kehrt vor DBCC und Statusoutputs zurück. NULL ist zulässig und wird in der jeweiligen IF/CASE-Bedingung nicht als 0 behandelt: die Bedingung =1 ist dann nicht wahr. Ein leerer String wird bei SQL-bit-Konvertierung zu 0; andere nicht konvertierbare Eingaben lösen einen Konvertierungsfehler aus. Zahlen 0 bleiben 0, jeder konvertierbare Nichtnullwert ungleich 0 wird zu 1. Bei ausgelassenem Argument gilt der Default.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Eingabeform: ein einzelner Code CONSOLE, RAW, TABLE oder NONE; führende/abschließende Leerzeichen werden entfernt und Groß-/Kleinschreibung wird mit UPPER vereinheitlicht. NULL wird durch COALESCE zu leerem Text, ein leerer oder nur aus Leerzeichen bestehender Wert bleibt leer; alle drei Fälle sind ungültig. Nur die vier genannten Werte sind gültig. CONSOLE und TABLE wählen ihre Fachprojektion und setzen den internen Modus anschließend auf NONE, damit kein generisches Fachresultset zusätzlich ausgegeben wird; RAW liefert rohe Fachresultsets, NONE unterdrückt Resultsets. Ungültige Codes (einschließlich NULL/leer) setzen INVALID_PARAMETER und IsPartial=1; intern werden wegen des nicht-NONE-Modus Status und die nicht-RAW-Fachprojektion ausgegeben. Bei TABLE erfolgt zuerst der Ziel-Preflight; sein Fehler wird geworfen. JSON-Erzeugung ist unabhängig vom ResultSetArt.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max)=NULL ist nur für TABLE nötig; zuvor eine leere lokale #temp-Tabelle mit einer Seed-Spalte anlegen. Bei Nicht-TABLE sind nur NULL oder leer zulässig.

**@JsonErzeugen:** @JsonErzeugen bit=0 erzeugt bei 1 unabhängig von der ResultSetArt ein JSON-Dokument in @Json nvarchar(max)=NULL OUTPUT.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang des JSON-Dokuments, etwa @Json=@Payload OUTPUT mit einer nvarchar(max)-Variablen. Der Eingabewert wird beim Eintritt vor TABLE-Preflight und Hilfe auf NULL gesetzt. Bei erfolgreicher Hilfe-Rückkehr bleibt @Json NULL; andere Status-/Fehler-OUTPUTs werden dort nicht zugewiesen. Im normalen Pfad wird @Json nur bei @JsonErzeugen=1 nach der Quellverarbeitung befüllt; sonst bleibt es NULL. Ohne OUTPUT-Bindung wird kein Wert empfangen.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfang, etwa @StatusCodeOut=@Status OUTPUT mit einer varchar(40)-Variablen. Werte und Bedeutungen: AVAILABLE (kein festgestellter Eingabe- oder abgefangener Quellfehler), INVALID_PARAMETER (ungültige ResultSetArt), DENIED_PERMISSION (abgefangene Quellfehler 229, 297, 300 oder 371), ERROR_HANDLED (übrige abgefangene Quellfehler, einschließlich 1222; kein eigener TIMEOUT-Code). Die reguläre Zuweisung erfolgt nach der Quellverarbeitung; Hilfe lässt einen gebundenen Anfangswert einschließlich NULL unverändert und ein früher Preflight-THROW erreicht die Zuweisung nicht. Ohne OUTPUT-Bindung wird kein Wert empfangen.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionaler OUTPUT-Parameter für die Teilstatuskennzeichnung: 0 bei AVAILABLE, 1 bei INVALID_PARAMETER oder behandeltem Quellfehler. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @IsPartialOut=@Empfaenger OUTPUT angeben; die Variable muss bit sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionaler OUTPUT-Parameter für bei abgefangenem DBCC-Fehler die Quellfehlernummer; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorNumberOut=@Empfaenger OUTPUT angeben; die Variable muss int sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionaler OUTPUT-Parameter für bei Fehler den Quelltext beziehungsweise bei INVALID_PARAMETER den Hinweis auf die zulässigen ResultSetArt-Werte; sonst NULL. Die Procedure weist den Wert erst nach der Quellverarbeitung zu; bei frühem HELP-Rücksprung bleibt der Empfängerwert außer @Json unverändert. Zum Binden eine passende lokale Variable deklarieren und z.B. @ErrorMessageOut=@Empfaenger OUTPUT angeben; die Variable muss nvarchar(2048) sein. OUTPUT-Bindung ist optional, wenn der Rückgabewert nicht benötigt wird.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| traceFlags | 1 | 1 | [TraceFlag] int,[Status] int,[GlobalFlag] int,[SessionFlag] int |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_TraceFlags] @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_TraceFlags

Die Procedure USP_TraceFlags erstellt einen read-only Snapshot; die Quellansichten sind zeitlich nicht atomar.

Parameterformen und Defaults: @PrintMeldungen bit=1, @Hilfe bit=0, @ResultSetArt varchar(16)=CONSOLE (CONSOLE, RAW, TABLE, NONE; trimmen und Großschreibung normalisieren).

AVAILABLE bei erfolgreicher Erhebung; INVALID_PARAMETER bei ungültigem ResultSetArt; DENIED_PERMISSION für Fehlernummern 229, 297, 300 oder 371; sonst ERROR_HANDLED. Es gibt keine speziell abgebildete TIMEOUT-Klasse. Jeder abgefangene Quellfehler setzt IsPartial=1 sowie ErrorNumber/ErrorMessage. Statusoutputs werden nach dem TRY/CATCH gesetzt. DBCC TRACESTATUS erfordert laut Hilfe unter SQL Server public; der Procedure-Aufruf erfordert EXECUTE.

Die Procedure liest aktive globale Trace Flags und Trace Flags der aktuellen Verbindung mit einem Aufruf von DBCC TRACESTATUS(-1). Sie fragt keine Sitzungsflags anderer Verbindungen ab. JSON enthält meta, traceFlags und warnings; TABLE registriert traceFlags.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_TraceFlags
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liest aktive globale und zur aufrufenden Session
               gehörende Trace Flags über DBCC TRACESTATUS(-1).
Datenquellen : DBCC TRACESTATUS
Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach ein technisches Fachresultset.
               CONSOLE gibt nur die Console-Helferausgabe für traceFlags aus; TABLE schreibt ausschließlich das gemappte traceFlags-Resultset.
               CONSOLE und TABLE liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.
               Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_TraceFlags
Die Procedure USP_TraceFlags erstellt einen read-only Snapshot; die Quellansichten sind zeitlich nicht atomar.
Parameterformen und Defaults: @PrintMeldungen bit=1, @Hilfe bit=0, @ResultSetArt varchar(16)=CONSOLE (CONSOLE, RAW, TABLE, NONE; trimmen und Großschreibung normalisieren).
AVAILABLE bei erfolgreicher Erhebung; INVALID_PARAMETER bei ungültigem ResultSetArt; DENIED_PERMISSION für Fehlernummern 229, 297, 300 oder 371; sonst ERROR_HANDLED. Es gibt keine speziell abgebildete TIMEOUT-Klasse. Jeder abgefangene Quellfehler setzt IsPartial=1 sowie ErrorNumber/ErrorMessage. Statusoutputs werden nach dem TRY/CATCH gesetzt. DBCC TRACESTATUS erfordert laut Hilfe unter SQL Server public; der Procedure-Aufruf erfordert EXECUTE.
Die Procedure liest aktive globale Trace Flags und Trace Flags der aktuellen Verbindung mit einem Aufruf von DBCC TRACESTATUS(-1). Sie fragt keine Sitzungsflags anderer Verbindungen ab. JSON enthält meta, traceFlags und warnings; TABLE registriert traceFlags.
Quellen: DBCC TRACESTATUS(-1) WITH NO_INFOMSGS.. Es gibt kein Zeilenlimit. Ausgabeunterdrückung verhindert die Quellabfrage nicht.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_TraceFlags] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
```

