---
skill_format_version: "1.0.0"
name: "monitor.USP_IntelligentQueryProcessingAnalysis"
schema_name: "monitor"
object_name: "USP_IntelligentQueryProcessingAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Dokumentiert IQP-Voraussetzungen, Query-Store-Feedback, Query-Varianten und Automatic-Tuning-Evidenz je Datenbank."
source_path: "Code/05_QueryStore/090_USP_IntelligentQueryProcessingAnalysis.sql"
---

# monitor.USP_IntelligentQueryProcessingAnalysis

## Zweck und Einsatz

Dokumentiert IQP-Voraussetzungen, Query-Store-Feedback, Query-Varianten und Automatic-Tuning-Evidenz je Datenbank.

## Voraussetzungen und Rechte

sys.database_query_store_options, sys.database_scoped_configurations, sys.query_store_query_variant, sys.query_store_plan_feedback, sys.database_automatic_tuning_options und sys.dm_db_tuning_recommendations.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MaxZeilen | int | nein | 1000 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Eingabe: optionale bracket-aware Pipe-Liste exakter Datenbanknamen; jeder Name kann als [Name] geklammert sein. NULL, leerer String oder nur äußere U+0020-Leerzeichen bedeuten keine Listenbegrenzung und wählen zusammen mit fehlendem Pattern alle sichtbaren, online befindlichen Datenbanken entsprechend dem Systemdatenbankschalter. Nichtleere Liste und Pattern sind exklusiv; leere Elemente und doppelte Namen sind ungültig. Nicht verfügbare Namen werden Warnungen. Systemdatenbanken erfordern zusätzlich @SystemdatenbankenEinbeziehen=1. CATALOG_DEEP ist immer aktiv und braucht @HighImpactConfirmed=1, auch bei einer Datenbank und kleinem Limit. Pipe trennt nur außerhalb von [...]; ]] maskiert eine schließende Klammer. Ein gültiger Name benötigt PARSENAME-Teil 1 ungleich NULL, Teil 2 gleich NULL und LEN von Teil 1 höchstens 128; Teile 3 und 4 werden nicht gesondert geprüft. Rohsegmente über 4000 UTF-16-Codeeinheiten sind ungültig.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Eingabe: 0 schließt Systemdatenbanken aus; 1 nimmt sie in den Kandidatenscope auf. NULL ist ungültig. Gilt für Listen- und Patternauswahl; Opt-in erteilt keine CATALOG_DEEP-Bestätigung. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. 1 umgeht weder Online-/Sichtbarkeitsfilter noch Namens-/Patternauswahl. Die NULL-Prüfung erfolgt bei erreichter Datenbankvorbereitung.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Eingabe: optionaler Datenbanknamenfilter, exklusiv zu jeder nichtleeren @DatabaseNames-Liste. NULL bedeutet kein Pattern; ohne Liste werden sichtbare, online befindliche Datenbanken entsprechend dem Systemdatenbankschalter gewählt. Leeres oder nur aus äußeren U+0020-Leerzeichen bestehendes Pattern ist ungültig. Standardmodus LIKE mit den üblichen Wildcards % für beliebig viele und _ für genau ein Zeichen; Präfix LIKE:, REGEX: oder REGEXI: wählt LIKE, case-sensitive Regex (Flag c) oder case-insensitive Regex (Flag i). Außenliegende Leerzeichen werden entfernt; Inhalt nach Präfix nicht erneut. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank. Pattern begrenzt Datenbankkandidaten, nicht Feedbackzeilen. LIKE wird mit expliziter Framework-CS-Collation verglichen; auch Zeichenklassen [...] sind möglich. Präfixerkennung ist case-insensitiv. Leerer Rest nach jedem Präfix ist ungültig; Regex-Syntax wird nicht vorab geprüft. Die Zuweisung an nvarchar(4000) erfolgt vor der Parameterprüfung.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Eingabe: 0 verweigert den stets aktivierten CATALOG_DEEP-Pfad mit Status HIGH_IMPACT_CONFIRMATION_REQUIRED; 1 bestätigt ihn. NULL ist ungültig. Die Bestätigung ist unabhängig von Zeilenlimit, Scopebreite und Gruppenzugehörigkeit; sie erteilt keine fehlende Gruppenfreigabe. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. Die Statusfolge setzt voraus, dass keine frühere Parameterablehnung die Auswahl verhindert; Hilfe kehrt vorher zurück.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Eingabe: ganzzahlig von 0 bis 2.147.483.647. Positive Werte begrenzen nach vollständiger Sammlung in RAW und JSON die Fachmengen databaseState, configuration, automaticTuning und signals jeweils getrennt mit TOP; Signale werden einmal materialisiert. NULL und 0 bedeuten unbegrenzt. Negative Werte liefern INVALID_PARAMETER, IsPartial=1 und leere Fachsammlungen. Das Limit begrenzt weder Datenbankauswahl/-cursor noch vorgelagerte Abfragen/Zählungen; Warnungen bleiben unbegrenzt. Kein HasMore-Indikator. Datenbankzustand wird nach DatabaseId, Konfiguration nach DatabaseId/ConfigurationName, Automatic Tuning nach DatabaseId/OptionName und Signale nach DatabaseId/SignalCode gewählt, jeweils aufsteigend. TABLE und aktive CONSOLE geben nur signals aus und versprechen keine physische Reihenfolge.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Eingabe: nach Trim und Großschreibung nur CONSOLE, RAW, TABLE oder NONE; NULL, leerer String und andere Werte sind ungültig. CONSOLE gibt ausschließlich Signals mit Ergebnisbeschriftung aus; leer erscheint eine verständliche Leerzeile. RAW gibt sechs Resultsets: Meta, DatabaseState, Configuration, AutomaticTuning, Signals und Errors. TABLE exportiert ausschließlich Signals. NONE erzeugt keine Resultsets. Ein nichtleeres @ResultTablesJson ist nur mit TABLE zulässig und löst sonst vor der Hilfeprüfung einen Fehler aus. LTRIM/RTRIM entfernt nur äußere U+0020-Leerzeichen; ein solcher Leerwert ist ungültig. Die Bindung an varchar(16) erfolgt vor der Prüfung. JSON bleibt unabhängig.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Außerhalb TABLE sind ausgelassen/NULL, leer oder nur äußere U+0020-Leerzeichen zulässig; anderer nichtleerer Inhalt wirft vor Hilfe Fehler 51011. Bei TABLE ist ein nichtleeres JSON-Objekt mit genau dem binär exakten Schlüssel signals (aggregierte IQP-Signale) erforderlich. Der Stringwert benennt eine vorhandene, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte und keiner Seed-Zeile; kein ##, LEN höchstens 116 und kein reserviertes #Monitor-Präfix. Unbekannte/doppelte Schlüssel, Nicht-Stringwerte oder ungültige Ziele scheitern im frühen ThrowOnError-Preflight vor Hilfe und Fachvalidierung. Der Writer ersetzt die Seed-Struktur durch die sechs Signalfelder. Andere IQP-Ergebnisgruppen können nicht über TABLE gemappt werden.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Eingabe: 1 erzeugt unabhängig von ResultSetArt das JSON; 0 deaktiviert es. NULL verhält sich wie deaktiviert und wird nicht eigens validiert. Hilfe kehrt vorher zurück. JSON enthält meta, databaseState, configuration, automaticTuning, signals und warnings; Fachsammlungen folgen ihrem Limit. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1. meta enthält Modulstatus/Partialität; databaseState die Eignung/Zustände, configuration die erfassten Optionen, automaticTuning die Tuningzustände, signals die aggregierten Zähler und warnings die Quellenfehler.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Ausgabe: wird sofort auf NULL zurückgesetzt. Bei normalem Lauf wird bei @JsonErzeugen=1 das Dokument gesetzt, sonst bleibt es NULL. Eingabewert wird ignoriert. Bei Hilfe bleibt es NULL; Parameter darf weggelassen werden. Zum Empfang eine nvarchar(max)-Variable als @Json=@Variable OUTPUT binden. Ohne OUTPUT-Bindung wird kein Wert an den Aufrufer übernommen. Bei ungefangenem THROW keine zugesicherte OUTPUT-Rückübertragung.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Eingabe: derzeit vollständig unbenutzt. 0, 1 und NULL ändern weder PRINT-, Resultset-, JSON- noch Fehlerverhalten; keine Auswirkung auf Validierung. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@Hilfe:** @Hilfe bit; Default: 0. Eingabe: genau 1 gibt Hilfe per PRINT aus und kehrt vor normaler Validierung/Quellensammlung zurück; NULL oder 0 führen den normalen Pfad aus. @Json wird vorher auf NULL gesetzt; die vier Status-/Fehler-OUTPUT-Werte bleiben im Hilfepfad unverändert. Vor Hilfe kann ein nichtleeres Mapping bei Nicht-TABLE bereits einen Fehler werfen; TABLE führt zuerst den signals-Preflight aus. Als bit 0 oder 1 übergeben; konvertierbare numerische Werte ungleich 0 werden 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT des abschließenden Modulstatus, kein Eingabefilter. Vollständige aktuelle Statusmenge: AVAILABLE (Sammlung ohne festgestellten Befund), AVAILABLE_WITH_FINDING (Sammlung mit Konfigurationsbefund), AVAILABLE_LIMITED (verfügbare, aber partielle Sammlung), DATABASE_UNAVAILABLE (kein auswertbarer Datenbankzustand), DENIED_PERMISSION (keine Zustandsmenge bei erfasstem Berechtigungsfehler), INVALID_PARAMETER (ungültiger Aufruf). Der Vorbereitungshelfer kann zusätzlich HIGH_IMPACT_CONFIRMATION_REQUIRED (fehlende Bestätigung), DENIED_GROUP (fehlende Gruppenfreigabe), UNAVAILABLE_FEATURE (nicht unterstützter Quellregex) oder INTERNAL_ERROR (interner Helfer-/Tabellenfehler) liefern. ERROR_HANDLED ist nur Quellenstatus, kein Modulstatus. Eine varchar(40)-Variable mit OUTPUT binden. Zuweisung vor JSON und fachlicher Ausgabe; bei Hilfe bleibt der Eingabewert unverändert. Bei ungefangenem THROW keine zugesicherte Rückübertragung.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT der Partialität, kein Eingabeschalter. 1 bei eigenem ungültigem Zeilenlimit/Ausgabemodus sowie erfassten Datenbank-/Quellfehlern oder Kandidatenwarnungen; 0 bei keiner festgestellten Partialität, auch eine Helfer-Gate-Ablehnung kann 0 behalten. Ein Limit allein setzt das Bit nicht. Eine bit-Variable mit OUTPUT binden. Zuweisung vor JSON und Ausgabe; bei Hilfe bleibt der Eingabewert einschließlich NULL unverändert. Bei ungefangenem THROW keine zugesicherte Rückübertragung.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Ausgabe: interne ErrorNumber wird im aktuellen Implementierungsstand nie gesetzt; normal daher NULL. Quellfehlernummern stehen in RAW Errors bzw. JSON warnings, nicht hier. Bei Hilfe bleibt Wert unverändert; Argument kann entfallen. Eine int-Variable mit OUTPUT binden; kein Eingabefilter. Zuweisung vor JSON und Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Ausgabe: Modulvalidierungs- oder Helfermeldung, falls gesetzt; Meldung des ersten Quellfehlers wird nicht hierher kopiert. Quellfehler stehen in RAW Errors bzw. JSON warnings. Sonst normal NULL. Bei Hilfe bleibt Wert unverändert; Argument kann entfallen. Eine nvarchar(2048)-Variable mit OUTPUT binden; kein Eingabefilter. Zuweisung vor JSON und Ausgabe; bei ungefangenem THROW keine zugesicherte Rückübertragung.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| signals | 1 | 1 | [DatabaseId] int NOT NULL , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [SignalCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsSourceAvailable] bit NOT NULL , [EvidenceCount] bigint NULL , [Interpretation] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @Hilfe = 1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Vorhandene oder fehlende Feedbackzeilen beweisen weder Nutzen noch Fehler. Verfügbarkeit wird versionsadaptiv ausgewiesen.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_IntelligentQueryProcessingAnalysis
Version      : 1.0.0
Stand        : 2026-07-17
Zweck        : Dokumentiert IQP-Voraussetzungen, Query-Store-Feedback,
               Query-Varianten und Automatic-Tuning-Evidenz je Datenbank.
Datenquellen : sys.database_query_store_options,
               sys.database_scoped_configurations,
               sys.query_store_query_variant,
               sys.query_store_plan_feedback,
               sys.database_automatic_tuning_options und
               sys.dm_db_tuning_recommendations.
Datenschutz  : Liest weder Query-Text noch Showplan, Objekt- oder Benutzerdaten.
Grenzen      : Vorhandene oder fehlende Feedbackzeilen beweisen weder Nutzen
               noch Fehler. Verfügbarkeit wird versionsadaptiv ausgewiesen.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_IntelligentQueryProcessingAnalysis
Liest IQP-Konfiguration und aggregierte Varianten-, Planfeedback- und Automatic-Tuning-Evidenz; niemals Query-Text oder Showplan.
CATALOG_DEEP ist immer aktiv: @HighImpactConfirmed=1 ist auch bei kleinem Scope und Limit erforderlich; Gruppenfreigabe wird separat geprüft.
Sammlung erfolgt vor @MaxZeilen. NULL/0 bedeutet unbegrenzt; Warnungen sind unbegrenzt. Ausgabeart ändert den Sammlungspfad nicht.
Die beschriebenen Parameterprüfungen gelten im normalen Analysepfad; Hilfe kehrt nach frühen Mappingprüfungen davor zurück. Ausgelassen gilt jeweils der ausdrücklich bezeichnete Default. Quellen werden je Datenbank als gemeinsamer Batch verarbeitet; frühere Einfügungen können bei einem späteren Quellenfehler als partielle Evidenz erhalten bleiben.
DECLARE @JsonOut nvarchar(max);
EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames = N'[ExampleDatabase]', @HighImpactConfirmed = 1, @MaxZeilen = 100, @ResultSetArt = 'NONE', @JsonErzeugen = 1, @Json = @JsonOut OUTPUT;
SELECT @JsonOut AS [Json];
CREATE TABLE [#IntelligentQueryProcessingAnalysis_HelpExample]([Seed] int NULL);
BEGIN TRY
 EXEC [monitor].[USP_IntelligentQueryProcessingAnalysis] @DatabaseNames=N'[ExampleDatabase]', @HighImpactConfirmed=1, @ResultSetArt='TABLE', @ResultTablesJson=N'{"signals":"#IntelligentQueryProcessingAnalysis_HelpExample"}';
 SELECT * FROM [#IntelligentQueryProcessingAnalysis_HelpExample];
 DROP TABLE IF EXISTS [#IntelligentQueryProcessingAnalysis_HelpExample];
END TRY
BEGIN CATCH
 DROP TABLE IF EXISTS [#IntelligentQueryProcessingAnalysis_HelpExample];
 THROW;
END CATCH;
```

