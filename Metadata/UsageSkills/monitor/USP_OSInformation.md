---
skill_format_version: "1.0.0"
name: "monitor.USP_OSInformation"
schema_name: "monitor"
object_name: "USP_OSInformation"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure liest Host-, Betriebssystem-Speicher-, SQL-Prozess- und Dienstdaten; jede optionale Quelle hat eine eigene Fehlergrenze."
source_path: "Code/08_ServerHealth/080_USP_OSInformation.sql"
---

# monitor.USP_OSInformation

## Zweck und Einsatz

Die Procedure liest Host-, Betriebssystem-Speicher-, SQL-Prozess- und Dienstdaten; jede optionale Quelle hat eine eigene Fehlergrenze.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_OSInformation] im vorgesehenen Datenbankkontext. Die Procedure liest `sys.dm_os_host_info`, OS-/Prozessspeicher und `sys.dm_server_services`; diese DMV-Sichten werden unter den aktuellen Serverrechten geprüft.

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

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 1 gibt nach der Quellenprüfung bei einem Status ungleich AVAILABLE eine Statusmeldung aus; 0 unterdrückt sie. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1, da nur der Vergleich mit 1 die Ausgabe auslöst.

**@Hilfe:** @Hilfe bit; Default: 0. 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei ResultSetArt TABLE wird der Ziel-Preflight vor der Hilfe ausgeführt.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Bindung an varchar(16): CONSOLE gibt ausschließlich host unter dem Label OSInformation aus; bei leerer host-Tabelle liefert der Helfer eine Leerzeile; die weiteren Quellresultate stehen in RAW beziehungsweise JSON; RAW liefert technische Resultsets; TABLE exportiert nur host; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden für reguläre Resultsets zu NONE und separat ausgegeben. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ist ein JSON-Objekt mit dem einzelnen Resultatnamen host erforderlich, abgebildet auf eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte. Permanente und globale ##-Tabellen, nichtleere Ziele und Ziele mit fertigem Ausgabeschema werden vom Preflight zurückgewiesen; er läuft vor der Hilfe und Fehler lösen 51011 aus. Außerhalb von TABLE sind NULL, Leertext oder Leerzeichen erlaubt; sonst wird 51011 ausgelöst.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erstellt JSON mit meta, sources, host, systemMemory, processMemory, services und warnings als leerem Array; 0 bzw. NULL unterdrückt die Erstellung; numerische 0 bleibt 0 und von 0 verschiedene konvertierbare Zahlen werden bit 1. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. AVAILABLE bei vier verfügbaren Quellen; PARTIAL bei mindestens einer verfügbaren und einer fehlgeschlagenen Quelle; INVALID_PARAMETER für ungültige ResultSetArt; bei Gesamtausfall DENIED_PERMISSION für Fehler 229/297/300/371, sonst ERROR_HANDLED. Zuweisung nach Quellversuchen, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, sonst 1 sobald eine Quelle ausfällt oder ResultSetArt ungültig ist. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer des ersten Fehlers aus einer fehlgeschlagenen Quelle; die Auswahl ist ohne explizite Sortierung, sonst NULL; im Hilfezweig keine Zuweisung.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Meldung der ersten fehlgeschlagenen Quelle oder Validierungstext, sonst NULL; im Hilfezweig keine Zuweisung.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| host | 1 | 1 | [host_platform] nvarchar(60),[host_distribution] nvarchar(256),[host_release] nvarchar(256),[host_service_pack_level] nvarchar(256),[host_sku] int,[os_language_version] int |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_OSInformation] @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_OSInformation

Erfasst Hostidentität, Betriebssystemspeicher, SQL-Prozessspeicher und SQL-Dienstdetails aus vier unabhängigen Quellen.

Die Hilfe läuft nach einem eventuellen TABLE-Preflight und vor Quellabfragen. Teilfehler bleiben pro Quelle sichtbar.

DECLARE @j nvarchar(max); EXEC [monitor].[USP_OSInformation] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;

CREATE TABLE [#OSInformation_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_OSInformation] @ResultSetArt='TABLE', @ResultTablesJson=N'{"host":"#OSInformation_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#OSInformation_HelpExample]; THROW; END CATCH; DROP TABLE [#OSInformation_HelpExample];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_OSInformation
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liest Host-, Betriebssystem-Speicher-, SQL-Prozess-
               und Dienstdaten; jede optionale Quelle hat eine eigene Fehlergrenze.
Datenquellen : sys.dm_os_host_info, sys.dm_os_sys_memory, sys.dm_os_process_memory, sys.dm_server_services
Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach fünf technische Fachresultsets.
               CONSOLE gibt nur die Console-Helferausgabe für host aus; TABLE schreibt ausschließlich das gemappte host-Resultset.
               CONSOLE und TABLE liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.
               Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_OSInformation
Erfasst Hostidentität, Betriebssystemspeicher, SQL-Prozessspeicher und SQL-Dienstdetails aus vier unabhängigen Quellen.
Die Hilfe läuft nach einem eventuellen TABLE-Preflight und vor Quellabfragen. Teilfehler bleiben pro Quelle sichtbar.
DECLARE @j nvarchar(max); EXEC [monitor].[USP_OSInformation] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;
CREATE TABLE [#OSInformation_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_OSInformation] @ResultSetArt='TABLE', @ResultTablesJson=N'{"host":"#OSInformation_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#OSInformation_HelpExample]; THROW; END CATCH; DROP TABLE [#OSInformation_HelpExample];
```

