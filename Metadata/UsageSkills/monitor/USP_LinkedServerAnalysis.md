---
skill_format_version: "1.0.0"
name: "monitor.USP_LinkedServerAnalysis"
schema_name: "monitor"
object_name: "USP_LinkedServerAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "OPS-005: local inventory by default; connectivity is explicit double opt-in."
source_path: "Code/08_ServerHealth/220_USP_LinkedServerAnalysis.sql"
---

# monitor.USP_LinkedServerAnalysis

## Zweck und Einsatz

OPS-005: local inventory by default; connectivity is explicit double opt-in.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_LinkedServerAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareSingleResultTable]`, `[sys].[servers]`, `[master].[dbo].[sp_testlinkedserver]`, `[sys].[dm_os_wait_stats]`, `[monitor].[InternalEmitConsoleResult]`, `[monitor].[InternalWriteResultTable]`, `[sys].[sp_executesql]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @ConnectivityTestEnabled | bit | nein | 0 |
| @HighImpactConfirmed | bit | nein | 0 |
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

**@ConnectivityTestEnabled:** @ConnectivityTestEnabled bit; Default: 0. 0 führt keinen Remote-Test aus; 1 fordert ihn an und startet ihn nur gemeinsam mit @HighImpactConfirmed=1. NULL ist ungültig und ergibt INVALID_PARAMETER. sp_testlinkedserver läuft für jeden inventarisierten Linked Server. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. 0 bestätigt den Remotezugriff nicht; 1 bestätigt ihn. NULL ist ungültig. Tests starten nur bei @ConnectivityTestEnabled=1 und diesem Schalter=1. Bei aktivem Test und fehlender Bestätigung lautet der Status AUTHORIZATION_REQUIRED; allein aktiviert dieser Schalter keinen Test. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@MaxZeilen:** @MaxZeilen int; Default: 2000. NULL wird zu 0; 0 bedeutet unbegrenzt. Positive Werte wählen nach ServerName sortierte Inventarzeilen für RAW/CONSOLE/TABLE/JSON. Inventarisierung und Remoteprüfungen laufen vollständig vor Begrenzung; Status und LinkedServerCount beziehen sich auf alle Server. Negative Werte ergeben INVALID_PARAMETER und keine begrenzten Zeilen.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Wählt CONSOLE für die beschriftete Linked-Server-Ansicht, RAW für Status, Inventarzeilen und zusätzliche kumulative Waitwerte, TABLE für die benannte Tabellenausgabe oder NONE ohne reguläre Resultsets. Äußere U+0020-Leerzeichen werden entfernt und Groß-/Kleinschreibung normalisiert. JSON enthält nur Linked-Server-Zeilen und wird unabhängig über @JsonErzeugen angefordert. NULL, Leertext oder andere Werte ergeben INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel linkedServers und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 serialisiert LimitedRows nach ServerName sortiert, also dieselbe begrenzte Auswahl wie die Inventar-Zeilenausgaben. NULL aktiviert IF nicht; leer wird []. Waitwerte sind nicht Teil des JSON-Arrays. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und den abschließenden Status-/Fehler-OUTPUT-Zuweisungen; diese vier Empfänger bleiben unverändert. @Json wurde bereits am Eintritt auf NULL gesetzt. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Gesamtwerte: AVAILABLE, AVAILABLE_EMPTY (kein Linked Server), AVAILABLE_LIMITED (Remoteprüfung teilweise fehlgeschlagen), AUTHORIZATION_REQUIRED (Test angefordert, zweites Opt-in fehlt), INVALID_PARAMETER (ungültige Ausgabeart, Zeilengrenze oder NULL-Opt-in). Zeilenstatus: AVAILABLE oder bei Remotefehler DENIED_PERMISSION, SOURCE_TIMEOUT, SOURCE_UNAVAILABLE; ConnectivityStatus ist NOT_EXECUTED, AUTHORIZATION_REQUIRED, SUCCEEDED oder FAILED. NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss NULL ohne abgefangenen Remote-Testfehler. Andernfalls enthält der Wert ERROR_NUMBER() des zuletzt abgefangenen Remote-Testfehlers; mehrere Fehler überschreiben den Wert jeweils. Die Einzelzeilen behalten ihre jeweiligen Fehlerhinweise. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Parametern oder fehlender Remote-Testbestätigung. Bei abgefangenen Remote-Testfehlern enthält der Wert die letzte ERROR_MESSAGE(); sonst NULL. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| linkedServers | 1 | 1 | [ServerName] sysname NOT NULL , [Product] nvarchar(128) NULL , [Provider] nvarchar(128) NULL , [IsDataAccessEnabled] bit NULL , [IsRpcOutEnabled] bit NULL , [IsCollationCompatible] bit NULL , [ConnectivityStatus] varchar(40) NOT NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_LinkedServerAnalysis

inventarisiert lokal registrierte Linked Server und zeigt kumulative OLEDB-/REMOTE-Waits. Standardmäßig wird keine Remoteverbindung aufgebaut. sp_testlinkedserver läuft je sichtbarem Linked Server nur mit beiden ausdrücklichen Opt-ins @ConnectivityTestEnabled=1 und @HighImpactConfirmed=1.

Der Test belegt nur den Verbindungsaufbau zum Testzeitpunkt, keine Remoteobjektberechtigung, Abfragelaufzeit oder fachliche Erreichbarkeit. Waitwerte sind kumulativ und keiner Registrierung zugeordnet. @MaxZeilen begrenzt die Inventarzeilen in CONSOLE, RAW, TABLE und JSON auf dieselbe Mitgliedschaft. Die positive Grenze wählt deterministisch nach ServerName; RAW und JSON geben diese Zeilen sortiert aus, CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. RAW enthält zusätzlich Waitwerte. Status und Remote-Tests beziehen sich weiterhin auf das vollständige Inventar.

DECLARE @Json nvarchar(max); EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];

CREATE TABLE [#LinkedServerAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"linkedServers":"#LinkedServerAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#LinkedServerAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#LinkedServerAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#LinkedServerAnalysis_HelpExample];
    THROW;
END CATCH;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
OPS-005: local inventory by default; connectivity is explicit double opt-in.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_LinkedServerAnalysis
inventarisiert lokal registrierte Linked Server und zeigt kumulative OLEDB-/REMOTE-Waits. Standardmäßig wird keine Remoteverbindung aufgebaut. sp_testlinkedserver läuft je sichtbarem Linked Server nur mit beiden ausdrücklichen Opt-ins @ConnectivityTestEnabled=1 und @HighImpactConfirmed=1.
Der Test belegt nur den Verbindungsaufbau zum Testzeitpunkt, keine Remoteobjektberechtigung, Abfragelaufzeit oder fachliche Erreichbarkeit. Waitwerte sind kumulativ und keiner Registrierung zugeordnet. @MaxZeilen begrenzt die Inventarzeilen in CONSOLE, RAW, TABLE und JSON auf dieselbe Mitgliedschaft. Die positive Grenze wählt deterministisch nach ServerName; RAW und JSON geben diese Zeilen sortiert aus, CONSOLE und TABLE garantieren keine physische Zeilenreihenfolge. RAW enthält zusätzlich Waitwerte. Status und Remote-Tests beziehen sich weiterhin auf das vollständige Inventar.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE [#LinkedServerAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"linkedServers":"#LinkedServerAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_LinkedServerAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#LinkedServerAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#LinkedServerAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#LinkedServerAnalysis_HelpExample];
    THROW;
END CATCH;
```

