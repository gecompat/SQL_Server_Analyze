---
skill_format_version: "1.0.0"
name: "monitor.USP_SystemDatabaseObjectInventory"
schema_name: "monitor"
object_name: "USP_SystemDatabaseObjectInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "OPS-009: visible user-object inventory in master, model and msdb; no DDL."
source_path: "Code/08_ServerHealth/230_USP_SystemDatabaseObjectInventory.sql"
---

# monitor.USP_SystemDatabaseObjectInventory

## Zweck und Einsatz

OPS-009: visible user-object inventory in master, model and msdb; no DDL.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_SystemDatabaseObjectInventory]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[sys].[databases]`, `[sys].[objects]`, `[sys].[schemas]`, `[sys].[sp_executesql]`, `[monitor].[InternalEmitConsoleResult]`, `[monitor].[InternalWriteResultTable]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MaxZeilen | int | nein | 2000 |
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

**@MaxZeilen:** @MaxZeilen int; Default: 2000. NULL wird zu 0; 0 bedeutet unbegrenzt. Positive Werte behalten nach DatabaseName, SchemaName und ObjectName sortiert die ersten Zeilen. Begrenzung erfolgt nach vollständiger Katalogabfrage und reduziert deren Aufwand nicht; Status/ObjectCount beziehen sich auf den vollen Scope. Negative Werte ergeben INVALID_PARAMETER und keine Inventarzeilen.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel systemDatabaseObjects und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 serialisiert die nach @MaxZeilen begrenzten LimitedRows sortiert nach den drei Namen. NULL aktiviert IF nicht; leere Auswahl wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und den abschließenden Status-/Fehler-OUTPUT-Zuweisungen; diese vier Empfänger bleiben unverändert. @Json wurde bereits am Eintritt auf NULL gesetzt. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Gesamtwerte: AVAILABLE, AVAILABLE_EMPTY (keine sichtbaren Inventarzeilen), AVAILABLE_LIMITED (fehlender Zugriff/Quellenfehler) und INVALID_PARAMETER (negative Grenze oder ungültige Ausgabeart). Zeilenstatus ist AVAILABLE, DENIED_PERMISSION oder SOURCE_UNAVAILABLE. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung bei ungültigen Parametern; sonst NULL. Fehler einzelner Datenbankquellen stehen in den Inventarzeilen, ohne automatische Übernahme. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| systemDatabaseObjects | 1 | 1 | [DatabaseName] sysname NULL , [SchemaName] sysname NULL , [ObjectName] sysname NULL , [ObjectType] nvarchar(60) NULL , [CreateDate] datetime NULL , [ModifyDate] datetime NULL , [StatusCode] varchar(40) NULL , [EvidenceLimit] nvarchar(1000) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_SystemDatabaseObjectInventory

inventarisiert sichtbare, nicht als Microsoft-Objekte markierte Benutzerobjekte in online befindlichen Datenbanken master, model und msdb. Interne Tabellen und Objekte der Typen S und IT sind ausgeschlossen. Es liest Katalogmetadaten, keine Objektinhalte oder Definitionen, und führt keine DDL aus.

Das Inventar hängt vom aktuellen Sicherheitskontext ab; eine leere Ausgabe beweist keine Objektfreiheit. Fehlende Sicht oder Datenbankzugriff kann die Evidenz einschränken. @MaxZeilen begrenzt CONSOLE, RAW, TABLE und JSON auf dieselbe Mitgliedschaft. Die positive Grenze wählt deterministisch nach DatabaseName, SchemaName und ObjectName; RAW und JSON geben diese Zeilen sortiert aus, CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. Status und Teilsichtbarkeit beziehen sich auf das vollständige Inventar. Die Grenze reduziert den Katalogzugriff nicht.

DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];

CREATE TABLE [#SystemDatabaseObjectInventory_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"systemDatabaseObjects":"#SystemDatabaseObjectInventory_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#SystemDatabaseObjectInventory_HelpExample];
    DROP TABLE IF EXISTS [#SystemDatabaseObjectInventory_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#SystemDatabaseObjectInventory_HelpExample];
    THROW;
END CATCH;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
OPS-009: visible user-object inventory in master, model and msdb; no DDL.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_SystemDatabaseObjectInventory
inventarisiert sichtbare, nicht als Microsoft-Objekte markierte Benutzerobjekte in online befindlichen Datenbanken master, model und msdb. Interne Tabellen und Objekte der Typen S und IT sind ausgeschlossen. Es liest Katalogmetadaten, keine Objektinhalte oder Definitionen, und führt keine DDL aus.
Das Inventar hängt vom aktuellen Sicherheitskontext ab; eine leere Ausgabe beweist keine Objektfreiheit. Fehlende Sicht oder Datenbankzugriff kann die Evidenz einschränken. @MaxZeilen begrenzt CONSOLE, RAW, TABLE und JSON auf dieselbe Mitgliedschaft. Die positive Grenze wählt deterministisch nach DatabaseName, SchemaName und ObjectName; RAW und JSON geben diese Zeilen sortiert aus, CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. Status und Teilsichtbarkeit beziehen sich auf das vollständige Inventar. Die Grenze reduziert den Katalogzugriff nicht.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE [#SystemDatabaseObjectInventory_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"systemDatabaseObjects":"#SystemDatabaseObjectInventory_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_SystemDatabaseObjectInventory] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#SystemDatabaseObjectInventory_HelpExample];
    DROP TABLE IF EXISTS [#SystemDatabaseObjectInventory_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#SystemDatabaseObjectInventory_HelpExample];
    THROW;
END CATCH;
```

