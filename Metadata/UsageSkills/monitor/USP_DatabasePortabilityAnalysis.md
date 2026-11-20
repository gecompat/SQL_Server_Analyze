---
skill_format_version: "1.0.0"
name: "monitor.USP_DatabasePortabilityAnalysis"
schema_name: "monitor"
object_name: "USP_DatabasePortabilityAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "OPS-006: read-only portability evidence; no automatic DDL."
source_path: "Code/08_ServerHealth/200_USP_DatabasePortabilityAnalysis.sql"
---

# monitor.USP_DatabasePortabilityAnalysis

## Zweck und Einsatz

OPS-006: read-only portability evidence; no automatic DDL.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabasePortabilityAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[monitor].[TVF_ParseSqlNameList]`, `[sys].[databases]`, `sys.dm_db_persisted_sku_features`, `[sys].[dm_db_persisted_sku_features]`, `[sys].[sp_executesql]`, `sys.dm_db_uncontained_entities`, `[sys].[dm_db_uncontained_entities]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste expliziter, einteiliger Datenbanknamen. NULL, leer oder nur U+0020-Leerzeichen wählt alle online befindlichen, zugänglichen Benutzerdatenbanken (database_id>4). Ungültige/duplizierte Namen oder keine gültigen Namen ergeben INVALID_PARAMETER. Abgleich ist case-sensitiv unter SQL_Latin1_General_CP1_CS_AS; Systemdatenbanken sind ausgeschlossen. Sind alle explizit angeforderten Namen offline/unsichtbar, Status NOT_FOUND; bei teilweise fehlendem Scope AVAILABLE_LIMITED. Der Trenner | wirkt außerhalb eckiger Klammern; ]] maskiert eine schließende Klammer. Äußere U+0020-Leerzeichen je Element werden entfernt. Leere Listenelemente sind ungültig; ein rohes Element ist auf 4.000 Zeichen und der ausgewertete Namensbestandteil auf 128 Zeichen begrenzt.

**@MaxZeilen:** @MaxZeilen int; Default: 2000. Positive Werte von 1 bis 2.147.483.647 begrenzen ausschließlich RAW- und JSON-Evidenzzeilen, sortiert nach DatabaseName, EvidenceType und FeatureName. 0 und NULL verwenden dort die technische Höchstgrenze 2.147.483.647 und bedeuten praktisch unbegrenzt. CONSOLE und TABLE übernehmen die gesamte materialisierte Evidenzmenge ohne dieses Limit; Status und Zählkopf beziehen sich ebenfalls auf die Vollmenge. Die Grenze reduziert die Quellabfragen nicht. Negative Werte sind ungültig, setzen INVALID_PARAMETER/IsPartial=1 und überspringen Quellenabfragen; RAW/JSON liefern dann eine leere Evidenzmenge mit sicherer TOP-Grenze 0.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel portability und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 erzeugt nach DatabaseName, EvidenceType und FeatureName sortiertes Array mit derselben TOP-Grenze wie die Zeilenausgabe. NULL aktiviert IF nicht; leer wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und den abschließenden Status-/Fehler-OUTPUT-Zuweisungen; diese vier Empfänger bleiben unverändert. @Json wurde bereits am Eintritt auf NULL gesetzt. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Im regulären Aufruf werden AVAILABLE (Quellen liefen), AVAILABLE_EMPTY (beide Evidenzquellen lieferten keine Zeile), AVAILABLE_LIMITED (mindestens eine Quelle/Datenbank eingeschränkt), NOT_FOUND (alle explizit genannten Benutzerdatenbanken offline oder unsichtbar) oder INVALID_PARAMETER (ungültige Zeilengrenze, Ausgabeart oder Namensliste) zurückgegeben. Die einzelnen Quellenzeilen haben zusätzlich AVAILABLE oder SOURCE_STATUS mit DENIED_PERMISSION, UNSUPPORTED_SOURCE, LOCK_TIMEOUT oder SOURCE_UNAVAILABLE. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Eingaben oder nicht verfügbaren angeforderten Datenbanken; sonst NULL. Einzelne Quellenfehler stehen in den Evidenzzeilen, ohne automatische Übernahme in diesen Parameter. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| portability | 1 | 1 | [DatabaseName] sysname NOT NULL , [EvidenceType] varchar(40) NOT NULL , [FeatureName] nvarchar(256) NULL , [FeatureType] nvarchar(256) NULL , [StatementType] nvarchar(256) NULL , [SourceObject] nvarchar(256) NOT NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_DatabasePortabilityAnalysis

Inventarisiert persistierte Edition-Features und uncontained dependencies sichtbarer Datenbanken.

DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];

CREATE TABLE [#DatabasePortabilityAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"portability":"#DatabasePortabilityAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#DatabasePortabilityAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
    THROW;
END CATCH;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
OPS-006: read-only portability evidence; no automatic DDL.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DatabasePortabilityAnalysis
Inventarisiert persistierte Edition-Features und uncontained dependencies sichtbarer Datenbanken.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE [#DatabasePortabilityAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"portability":"#DatabasePortabilityAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_DatabasePortabilityAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#DatabasePortabilityAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#DatabasePortabilityAnalysis_HelpExample];
    THROW;
END CATCH;
```

