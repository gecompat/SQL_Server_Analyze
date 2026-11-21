---
skill_format_version: "1.0.0"
name: "monitor.USP_StartupParameters"
schema_name: "monitor"
object_name: "USP_StartupParameters"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure liest SQL-Startparameter und Registry-basierte Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin."
source_path: "Code/08_ServerHealth/070_USP_StartupParameters.sql"
---

# monitor.USP_StartupParameters

## Zweck und Einsatz

Die Procedure liest SQL-Startparameter und Registry-basierte Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_StartupParameters] im vorgesehenen Datenbankkontext. Die Procedure liest `sys.dm_os_host_info` und `sys.dm_server_registry` sowie Masterkataloge; Registry-/Hostsicht kann nach Plattform und Callerrechten fehlen.

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

**@Hilfe:** @Hilfe bit; Default: 0. 1 gibt die Parameterhilfe aus und beendet vor den Fachquellen; 0 erhebt Daten. NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. Bei @Hilfe=1 wird der Ziel-Preflight übersprungen; bei ResultSetArt TABLE läuft er im normalen Pfad.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Bindung an varchar(16): CONSOLE beschriftet startupParameters, RAW liefert die technischen Zeilen und TABLE exportiert startupParameters; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden intern für reguläre Resultsets zu NONE und danach über eigene Exportzweige bedient. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch. Bei einem Quellenfehler ersetzt dessen Status INVALID_PARAMETER; bei erfolgreicher Quellenprüfung bleibt INVALID_PARAMETER bestehen.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ist ein JSON-Objekt mit startupParameters erforderlich, das auf eine existierende leere lokale #temp-Tabelle mit genau einer Seed-Spalte zeigt. Andernfalls wirft der Preflight im normalen Pfad Fehler 51011; Hilfe kehrt vorher zurück. Außerhalb von TABLE ist nur NULL oder leerer/nur aus Leerzeichen bestehender Inhalt zulässig.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erzeugt unabhängig von ResultSetArt zusätzlich JSON, 0 erzeugt es nicht; NULL wirkt wie 0; numerische 0 bleibt 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. NONE unterdrückt Resultsets, nicht aber Quellenabfragen oder angefordertes JSON. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. Statuswerte: AVAILABLE; INVALID_PARAMETER; UNAVAILABLE_PLATFORM (DMV fehlt und Host ist Linux); UNAVAILABLE_OBJECT (DMV fehlt und Linux ist nicht erkannt); DENIED_PERMISSION (Fehler 229, 297, 300 oder 371); ERROR_HANDLED (sonstiger Registrylesefehler). Zuweisung erst nach Quellenprüfung, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, 1 bei invalidem Modus, nicht verfügbarer DMV oder abgefangenem Quellfehler. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer eines abgefangenen Registrylesefehlers, sonst NULL. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Enthält Quell-/Validierungshinweis oder NULL bei AVAILABLE. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| startupParameters | 1 | 1 | [registry_key] nvarchar(512),[value_name] nvarchar(256),[value_data] nvarchar(2048),[ParameterType] varchar(40) |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_StartupParameters] @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_StartupParameters

Erfasst lesend SQL-Startargumente sowie ImagePath und ObjectName aus sys.dm_server_registry; die Momentaufnahme ist nicht atomar.

Die Hilfe läuft vor einem eventuellen TABLE-Preflight sowie vor Plattform- und Quellenabfrage. JSON ist unabhängig von ResultSetArt.

DECLARE @j nvarchar(max); EXEC [monitor].[USP_StartupParameters] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;

CREATE TABLE [#StartupParameters_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_StartupParameters] @ResultSetArt='TABLE', @ResultTablesJson=N'{"startupParameters":"#StartupParameters_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#StartupParameters_HelpExample]; THROW; END CATCH; DROP TABLE [#StartupParameters_HelpExample];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_StartupParameters
Version      : 2.0.0
Stand        : 2026-07-15
Zweck        : Die Procedure liest SQL-Startparameter und Registry-basierte
               Dienstparameter und weist auf eine nicht verfügbare Plattformquelle hin.
Datenquellen : sys.dm_server_registry
Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach ein technisches Fachresultset.
               CONSOLE gibt nur die Console-Helferausgabe für startupParameters aus; TABLE schreibt ausschließlich das gemappte startupParameters-Resultset.
               CONSOLE und TABLE liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.
               Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_StartupParameters
Erfasst lesend SQL-Startargumente sowie ImagePath und ObjectName aus sys.dm_server_registry; die Momentaufnahme ist nicht atomar.
Die Hilfe läuft vor einem eventuellen TABLE-Preflight sowie vor Plattform- und Quellenabfrage. JSON ist unabhängig von ResultSetArt.
DECLARE @j nvarchar(max); EXEC [monitor].[USP_StartupParameters] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;
CREATE TABLE [#StartupParameters_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_StartupParameters] @ResultSetArt='TABLE', @ResultTablesJson=N'{"startupParameters":"#StartupParameters_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#StartupParameters_HelpExample]; THROW; END CATCH; DROP TABLE [#StartupParameters_HelpExample];
```

