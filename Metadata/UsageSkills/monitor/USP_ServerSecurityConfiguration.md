---
skill_format_version: "1.0.0"
name: "monitor.USP_ServerSecurityConfiguration"
schema_name: "monitor"
object_name: "USP_ServerSecurityConfiguration"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure liest ausgewählte sicherheitsrelevante Serveroptionen, Dienstinformationen und Servereigenschaften, ohne sie zu verändern."
source_path: "Code/08_ServerHealth/090_USP_ServerSecurityConfiguration.sql"
---

# monitor.USP_ServerSecurityConfiguration

## Zweck und Einsatz

Die Procedure liest ausgewählte sicherheitsrelevante Serveroptionen, Dienstinformationen und Servereigenschaften, ohne sie zu verändern.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_ServerSecurityConfiguration] im vorgesehenen Datenbankkontext. Die Procedure liest `sys.configurations` und `sys.dm_server_services`; sichtbare Einstellungen sind keine Prüfung des effektiven Hostschutzes.

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

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Bindung an varchar(16): CONSOLE gibt ausschließlich die Sicherheitskonfiguration unter dem Label ServerSecurityConfiguration aus; bei leerer Konfiguration liefert der Helfer eine Leerzeile; Quellenstatus, Dienste und Eigenschaften stehen in RAW beziehungsweise JSON; RAW liefert technische Resultsets; TABLE exportiert nur configuration; NONE unterdrückt Resultsets. Äußere U+0020-Leerzeichen werden entfernt, Großschreibung vereinheitlicht; NULL wird leer und ist ungültig. TABLE/CONSOLE werden für reguläre Resultsets zu NONE und separat ausgegeben. Ungültige Werte setzen INVALID_PARAMETER und IsPartial=1; Quellprüfung läuft dennoch.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Bei TABLE ist ein JSON-Objekt mit dem einzelnen Resultatnamen configuration erforderlich, abgebildet auf eine vorhandene, leere lokale #temp-Tabelle mit genau einer Seed-Spalte. Permanente und globale ##-Tabellen, nichtleere Ziele und Ziele mit fertigem Ausgabeschema werden vom Preflight zurückgewiesen; er läuft vor der Hilfe und Fehler lösen 51011 aus. Außerhalb von TABLE sind NULL, Leertext oder Leerzeichen erlaubt; sonst wird 51011 ausgelöst.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 1 erstellt JSON mit meta, sources, configuration, services, properties und warnings als leerem Array; 0 bzw. NULL unterdrückt die Erstellung. NULL wirkt wie 0; numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1. @Hilfe=1 kehrt vor der JSON-Erzeugung zurück; @Json ist beim Eintritt bereits auf NULL gesetzt.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(max)-Variable binden, z. B. @Json=@j OUTPUT. Der Eingangswert wird zu Beginn auf NULL gesetzt. Bei @JsonErzeugen=1 wird nach der Sammlung das JSON-Dokument geschrieben; sonst bleibt er NULL. Der Hilfezweig beendet vor der Erzeugung.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine varchar(40)-Variable binden. AVAILABLE bei Erfolg, PARTIAL bei gemischter Quellenverfügbarkeit, INVALID_PARAMETER bei ungültiger ResultSetArt. Bei Gesamtausfall gilt der alphabetisch erste Quellenfehler: DENIED_PERMISSION (229/297/300/371), TIMEOUT (1222) oder ERROR_HANDLED (sonst). Ein ungültiger Modus wird durch Quellenfehlerstatus ersetzt. Zuweisung nach Quellenversuchen, nicht bei Hilfe; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine bit-Variable binden. 0 bei AVAILABLE, sonst 1 für invaliden Modus oder mindestens einen ausgefallenen Quellzweig. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine int-Variable binden. Fehlernummer des alphabetisch ersten ausgefallenen Quellenzweigs, sonst NULL. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Die OUTPUT-Bindung ist optional; zum Empfang eine nvarchar(2048)-Variable binden. Fehlermeldung des alphabetisch ersten ausgefallenen Quellenzweigs, Validierungstext oder NULL bei Erfolg. Im Hilfezweig keine Zuweisung; eine gebundene, mit NULL initialisierte Variable bleibt NULL.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| configuration | 1 | 1 | [ConfigurationName] nvarchar(128) NOT NULL, [ConfiguredValue] sql_variant NULL, [RunningValue] sql_variant NULL, [Finding] varchar(60) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ServerSecurityConfiguration] @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_ServerSecurityConfiguration

Erfasst ausgewählte sicherheitsrelevante Serveroptionen, SQL-Dienste und Servereigenschaften lesend.

Die Hilfe läuft nach einem eventuellen TABLE-Preflight und vor der Erhebung. Befunde sind Prüfsignale, keine automatische Richtlinienentscheidung.

Der kuratierte Konfigurationszweig liest auf SQL Server 2025 auch den caller-sichtbaren Wert external rest endpoint enabled mit konfiguriertem und aktivem Zustand. Der Wert belegt weder einen REST-Aufruf noch erreichbare Endpoints, Berechtigungen, Credentials, Nutzung oder Wirksamkeit; die Procedure ändert die Option nicht.

DECLARE @j nvarchar(max); EXEC [monitor].[USP_ServerSecurityConfiguration] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ServerSecurityConfiguration
Version      : 2.0.1
Stand        : 2026-07-15
Zweck        : Die Procedure liest ausgewählte sicherheitsrelevante Serveroptionen,
               Dienstinformationen und Servereigenschaften, ohne sie zu verändern.
Datenquellen : sys.configurations, sys.dm_server_services, SERVERPROPERTY
Vertrag      : Im regulären Pfad liefert RAW zuerst Modulstatus, danach vier technische Fachresultsets.
               CONSOLE gibt nur die Console-Helferausgabe für configuration aus; TABLE schreibt ausschließlich das gemappte configuration-Resultset.
               CONSOLE und TABLE liefern kein separates Modulstatusresultset; NONE unterdrückt Resultsets.
               Optionales JSON wird im regulären Pfad unabhängig von @ResultSetArt durch @JsonErzeugen gesteuert; im Hilfezweig wird es nicht erzeugt.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ServerSecurityConfiguration
Erfasst ausgewählte sicherheitsrelevante Serveroptionen, SQL-Dienste und Servereigenschaften lesend.
Die Hilfe läuft nach einem eventuellen TABLE-Preflight und vor der Erhebung. Befunde sind Prüfsignale, keine automatische Richtlinienentscheidung.
Der kuratierte Konfigurationszweig liest auf SQL Server 2025 auch den caller-sichtbaren Wert external rest endpoint enabled mit konfiguriertem und aktivem Zustand. Der Wert belegt weder einen REST-Aufruf noch erreichbare Endpoints, Berechtigungen, Credentials, Nutzung oder Wirksamkeit; die Procedure ändert die Option nicht.
DECLARE @j nvarchar(max); EXEC [monitor].[USP_ServerSecurityConfiguration] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@j OUTPUT; SELECT @j;
CREATE TABLE [#ServerSecurityConfiguration_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_ServerSecurityConfiguration] @ResultSetArt='TABLE', @ResultTablesJson=N'{"configuration":"#ServerSecurityConfiguration_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#ServerSecurityConfiguration_HelpExample]; THROW; END CATCH; DROP TABLE [#ServerSecurityConfiguration_HelpExample];
```

