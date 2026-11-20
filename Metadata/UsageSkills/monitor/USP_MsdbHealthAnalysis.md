---
skill_format_version: "1.0.0"
name: "monitor.USP_MsdbHealthAnalysis"
schema_name: "monitor"
object_name: "USP_MsdbHealthAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen."
source_path: "Code/08_ServerHealth/210_USP_MsdbHealthAnalysis.sql"
---

# monitor.USP_MsdbHealthAnalysis

## Zweck und Einsatz

OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_MsdbHealthAnalysis]. Die Quelle nennt insbesondere `msdb.dbo.syspolicy_policies`, `[monitor].[InternalPrepareSingleResultTable]`, `[sys].[databases]`, `master.sys.master_files`, `[sys].[master_files]`, `msdb.dbo`, `[msdb].[dbo]`, `[sys].[sp_executesql]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

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

**@MaxZeilen:** @MaxZeilen int; Default: 2000. NULL wird vor der Validierung zu 0; 0 bedeutet unbegrenzt. Positive Werte behalten nach Area sortiert die ersten Zeilen. EvidenceRows wird vor dem Kürzen gezählt. Negative Werte ergeben INVALID_PARAMETER und verhindern Quellenaggregation.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Wählt CONSOLE (beschriftete Fachansicht mit Leeranzeige), RAW (Status/Zählkopf und rohe Zeilen), TABLE (benannte Tabellenausgabe) oder NONE (keine Zeilenresultsets). Äußere Leerzeichen werden entfernt und Groß-/Kleinschreibung ignoriert. TABLE und CONSOLE werden intern im NONE-Pfad gerendert. Ungültige Werte sowie NULL/leer ergeben INVALID_PARAMETER.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur bei ResultSetArt=TABLE ausgewertetes JSON-Objekt mit genau einem Schlüssel msdbHealth und dem Zielnamen. Das Ziel muss eine bereits vorhandene, leere lokale #Temp-Tabelle mit genau einer Seed-/Platzhalterspalte sein. NULL/leer reicht im TABLE-Pfad nicht. Außerhalb TABLE wird nur ein nichtleerer Wert mit Fehler 51011 abgewiesen; NULL oder U+0020-Leerzeichen wird ignoriert. Preflight validiert das Ziel vor dem Schreiben. Der Schlüssel ist case-sensitiv. Zielnamen dürfen höchstens 116 Zeichen haben; globale ##Tabellen und das ohne Beachtung der Groß-/Kleinschreibung reservierte Präfix #Monitor sind unzulässig. Der Preflight prüft Form und leere Seed-Tabelle; erst der Writer ersetzt die Seed-Spalte durch das Ergebnisschema.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json NULL; 1 serialisiert die bereits nach @MaxZeilen gekürzten Zeilen nach Area sortiert. NULL aktiviert IF nicht; leere Menge wird []. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionaler OUTPUT-Empfänger für ein JSON-Array der Fachzeilen. Am Eintritt wird @Json auch vor @Hilfe=1 auf NULL gesetzt; nur @JsonErzeugen=1 erzeugt danach das Array, bei leerer Fachmenge []. Zum Empfangen eine nvarchar(max)-Variable mit OUTPUT binden; das Argument kann ausgelassen werden. Ein anfänglicher NULL- oder anderer Variablenwert wird überschrieben.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. 0 unterdrückt die Status-PRINT-Meldung; Nicht-NULL-Bitwerte ungleich 0 aktivieren sie. NULL aktiviert sie nicht. Die Statusmeldung erscheint bei den vom Aufrufer gewählten Modi NONE, CONSOLE und TABLE; diese beiden Ansichtsmodi werden intern auf NONE normalisiert. RAW erzeugt diese Statusmeldung nicht. @Hilfe=1 kehrt vor dieser Meldung zurück. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. 0 führt die Analyse aus; jeder Nicht-NULL-Wert ungleich 0 druckt die Hilfe und beendet den Aufruf früh. NULL startet die Hilfe nicht. Der RETURN erfolgt vor Analyse und den abschließenden Status-/Fehler-OUTPUT-Zuweisungen; diese vier Empfänger bleiben unverändert. @Json wurde bereits am Eintritt auf NULL gesetzt. Bei der SQL-Konvertierung nach bit ergibt numerische 0 den Wert 0; von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Empfänger für den in diesem Modul ermittelten Gesamtstatus. Mögliche Gesamtwerte sind AVAILABLE (Auswertung ohne gemeldete Quellfehler), AVAILABLE_LIMITED (mindestens eine Quelle nicht lesbar), UNSUPPORTED (msdb fehlt) und INVALID_PARAMETER (negative Zeilengrenze oder ungültige Ausgabeart). Evidenzzeilen haben AVAILABLE, UNSUPPORTED (fehlendes bisheriges Historienobjekt) oder SOURCE_UNAVAILABLE (Quellenfehler; PBM-Views werden ohne Sichtbarkeitsvorprüfung direkt gelesen). NULL-Default erlaubt das Auslassen des Arguments; um den Wert zu empfangen, muss eine kompatible Variable ausdrücklich mit OUTPUT gebunden werden. Im Hilfezweig bleibt ein gebundener Empfänger wegen des frühen RETURN unverändert.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionale OUTPUT-Variable: 0 bedeutet nicht partiell, 1 bedeutet eingeschränkte/partielle Evidenz. NULL-Default erlaubt Auslassen und ist kein Ergebniswert. Empfang erfordert eine passende OUTPUT-Bindung; Hilfe-RETURN lässt sie unverändert.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Bei regulärem Abschluss bleibt die technische Fehlernummer in dieser Implementierung NULL. Fehler einzelner Quellen werden als Fach-/Quellenzeilen dokumentiert und nicht in diesen Empfänger kopiert. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Bei regulärem Abschluss eine Meldung zu ungültigen Parametern oder fehlender msdb; sonst NULL. Fehler einzelner Historien- und PBM-Quellen stehen in den Fachzeilen. Optionale OUTPUT-Bindung an eine Variable des deklarierten Typs; ohne Empfang kann das Argument entfallen. @Hilfe=1 weist den Wert nicht zu und erhält einen anfänglichen NULL- oder anderen Empfängerwert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| msdbHealth | 1 | 1 | [Area] varchar(40) NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [RowCount] bigint NULL , [OldestUtc] datetime2(3) NULL , [NewestUtc] datetime2(3) NULL , [SizeMb] decimal(19,2) NULL , [StatusCode] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt='RAW', @MaxZeilen=100;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_MsdbHealthAnalysis

Die Procedure inventarisiert msdb-Dateigröße, sichtbare Aggregate ausgewählter Backup-, Restore-, Agent-, Database-Mail- und Maintenance-Plan-Quellen sowie reine Zählwerte für PBM-Policies, -Conditions und -Categories. Es ändert oder löscht keine Daten.

Die Auswertung zählt Quellzeilen und ermittelt Zeitgrenzen nur für datierte Historien; Agent-Historie und PBM-Katalogzählungen erhalten keine Zeitgrenzen. PBM-Zeilen liefern weder Identitäten noch Ausdrücke oder Policy-Evaluation. Sie belegt weder fachlich richtige Retention noch Restorefähigkeit, Jobausführung, Mailzustellung, freien Speicher, nötige Dateiverkleinerung oder PBM-Gesundheit. Große Aggregate können I/O verursachen. @MaxZeilen begrenzt die Ausgabe, nicht die Quellaggregation. Quellenfehler können partielle Evidenz ergeben.

PBM_POLICIES, PBM_CONDITIONS und PBM_CATEGORIES lesen msdb.dbo.syspolicy_policies, syspolicy_conditions und syspolicy_policy_categories direkt. Sie liefern nur COUNT_BIG; OldestUtc, NewestUtc und SizeMb bleiben NULL. Die Views erfordern PolicyAdministratorRole in msdb; das Produkt vergibt keine Rolle. Ein Lesefehler liefert SOURCE_UNAVAILABLE mit unbekanntem RowCount statt UNSUPPORTED oder Nullbestand.

DECLARE @Json nvarchar(max); EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
OPS-008: Die Procedure inventarisiert msdb-Historien, Dateigröße und PBM-Zählwerte, ohne Historien zu löschen.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_MsdbHealthAnalysis
Die Procedure inventarisiert msdb-Dateigröße, sichtbare Aggregate ausgewählter Backup-, Restore-, Agent-, Database-Mail- und Maintenance-Plan-Quellen sowie reine Zählwerte für PBM-Policies, -Conditions und -Categories. Es ändert oder löscht keine Daten.
Die Auswertung zählt Quellzeilen und ermittelt Zeitgrenzen nur für datierte Historien; Agent-Historie und PBM-Katalogzählungen erhalten keine Zeitgrenzen. PBM-Zeilen liefern weder Identitäten noch Ausdrücke oder Policy-Evaluation. Sie belegt weder fachlich richtige Retention noch Restorefähigkeit, Jobausführung, Mailzustellung, freien Speicher, nötige Dateiverkleinerung oder PBM-Gesundheit. Große Aggregate können I/O verursachen. @MaxZeilen begrenzt die Ausgabe, nicht die Quellaggregation. Quellenfehler können partielle Evidenz ergeben.
PBM_POLICIES, PBM_CONDITIONS und PBM_CATEGORIES lesen msdb.dbo.syspolicy_policies, syspolicy_conditions und syspolicy_policy_categories direkt. Sie liefern nur COUNT_BIG; OldestUtc, NewestUtc und SizeMb bleiben NULL. Die Views erfordern PolicyAdministratorRole in msdb; das Produkt vergibt keine Rolle. Ein Lesefehler liefert SOURCE_UNAVAILABLE mit unbekanntem RowCount statt UNSUPPORTED oder Nullbestand.
DECLARE @Json nvarchar(max); EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE [#MsdbHealthAnalysis_HelpExample] ([Seed] int NULL);
DECLARE @ResultTablesJson nvarchar(max)=N'{"msdbHealth":"#MsdbHealthAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_MsdbHealthAnalysis] @ResultSetArt='TABLE', @ResultTablesJson=@ResultTablesJson;
    SELECT * FROM [#MsdbHealthAnalysis_HelpExample];
    DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS [#MsdbHealthAnalysis_HelpExample];
    THROW;
END CATCH;
```

