---
skill_format_version: "1.0.0"
name: "monitor.USP_DatabaseConfigurationAnalysis"
schema_name: "monitor"
object_name: "USP_DatabaseConfigurationAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure inventarisiert sichtbare, online befindliche und zugreifbare Datenbankoptionen, Database Scoped Configurations sowie Query-Store-Einstellungen."
source_path: "Code/08_ServerHealth/190_USP_DatabaseConfigurationAnalysis.sql"
---

# monitor.USP_DatabaseConfigurationAnalysis

## Zweck und Einsatz

Die Procedure inventarisiert sichtbare, online befindliche und zugreifbare Datenbankoptionen, Database Scoped Configurations sowie Query-Store-Einstellungen. Ohne explizites Sollprofil weist sie Unterschiede als lokale Variation aus; ein Profil ergänzt getrennte Abweichungsbefunde.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_DatabaseConfigurationAnalysis]. Die Quelle nennt insbesondere `[monitor].[InternalPrepareResultTables]`, `[monitor].[USP_PrepareDatabaseCandidates]`, `master.sys.databases`, `[master].[sys].[databases]`, `[master].[sys].[all_columns]`, `[master].[sys].[all_objects]`, `[master].[sys].[schemas]`, `[sys].[sp_executesql]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @ProfileJson | nvarchar(max) | nein | NULL |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Bracket-aware Pipe-Liste exakter, einteiliger SQL-Datenbanknamen, z. B. N'AppDb|[Reporting Db]'. | trennt außerhalb von [...]; ]] maskiert eine schließende Klammer. Äußere Elementleerzeichen werden entfernt. Leere Elemente, ungültige Klammerung, mehrteilige oder überlange Namen und doppelte gültige Namen sind ungültig. NULL, leerer Text oder nur U+0020-Leerzeichen bedeuten keinen Namensfilter; dann gelten alle sichtbaren, online befindlichen und zugreifbaren Kandidaten ohne Datenbanksnapshots. Nur eine nach Entfernung äußerer U+0020-Leerzeichen nichtleere Liste ist mit einem nicht-NULL-Pattern unvereinbar. Nicht vorhandene, ausgeschlossene, offline befindliche oder für den Login nicht zugreifbare explizite Namen erzeugen DATABASE_UNAVAILABLE; explizite Systemnamen master, tempdb, model und msdb ohne Opt-in erzeugen SYSTEM_DATABASE_EXCLUDED. Namen und Duplikate werden case-sensitiv verglichen.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. 0 schließt Systemdatenbanken mit ID 1 bis 4 aus; 1 bezieht sie zusätzlich zu Datenbanken mit ID über 4 ein. NULL ist ungültig. Der Wert wird auf bit konvertiert: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1. Auch einbezogene Systemdatenbanken müssen sichtbar, online und zugreifbar sein.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Filtert Datenbanknamen. NULL bedeutet kein Pattern. Nach Entfernung äußerer U+0020-Leerzeichen wird optional ohne Beachtung der Groß-/Kleinschreibung ein Präfix entfernt: LIKE: für SQL-LIKE, REGEX: für case-sensitive Regex oder REGEXI: für case-insensitive Regex. Ohne Präfix gilt LIKE. Der Rest wird nach Präfixentfernung nicht erneut getrimmt; leerer Eingang und leeres Präfixergebnis sind ungültig. LIKE wird case-sensitiv ausgewertet. Regex erfordert SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; der Parser validiert die Regex-Syntax nicht vorab. Der Kandidatenhelper führt REGEXP_LIKE aus; eine fehlerhafte Regex kann dabei einen nicht abgefangenen Laufzeitfehler auslösen, ohne normalen Statusabschluss. Nur eine aktive, nichtleere Datenbankliste ist mit einem nicht-NULL-Pattern unvereinbar.

**@ProfileJson:** @ProfileJson nvarchar(max); Default: NULL. NULL verwendet ausschließlich den lokalen Vergleich; Leertext, U+0020-Leertext und ein leeres Array sind ungültig. Ansonsten ein JSON-Array eindeutiger Objekte mit exakt den case-sensitiven Feldnamen settingScope, settingName und expectedValue, z. B. [{"settingScope":"DATABASE","settingName":"AUTO_CLOSE","expectedValue":"OFF"}]. settingScope wird getrimmt und großgeschrieben; erlaubt sind ausschließlich DATABASE für Datenbankoptionen, SCOPED für Database Scoped Configurations und QUERY_STORE für Query-Store-Optionen. settingName wird zu nvarchar(128) konvertiert, getrimmt und muss nichtleer sein. expectedValue wird zu nvarchar(4000) konvertiert und darf nicht NULL sein; leerer Text ist zulässig. Nicht konvertierbare Einträge, ungültiges/leer strukturiertes Array, NULL-Felder, unbekannte Scopes und doppelte Scope/Name-Paare unter case-sensitivem Vergleich sind ungültig. Zusätzliche JSON-Felder werden ignoriert. Einstellungsnamen und Soll-/Istwerte werden mit SQL_Latin1_General_CP1_CI_AS verglichen; reine Unterschiede der Groß-/Kleinschreibung erzeugen keine Abweichung. Ein Name ohne sichtbare passende Einstellung erzeugt PROFILE_SETTING_NOT_VISIBLE. Ohne Profil wird lokale Variation, mit Profil zusätzlich DriftType PROFILE_MISMATCH mit FindingCode EXPLICIT_PROFILE_MISMATCH ausgewiesen; keine Konfiguration wird geändert.

**@MaxZeilen:** @MaxZeilen int; Default: 2000. Begrenzt settings- und drift-Zeilen jeweils separat, nicht die Inventarisierung oder andere Gruppen. Positive Werte sind das jeweilige Maximum; 0 oder NULL bedeutet unbegrenzt. Negative Werte sind ungültig. Die vollständigen Einstellungen und Befunde werden zunächst berechnet und materialisiert, danach werden Zeilen über dem Limit entfernt. settings wird nach DatabaseName, SettingScope und SettingName sortiert; drift nach DriftType, SettingScope, SettingName und DatabaseName. HasMoreSettingRows und HasMoreDriftRows melden erkannte Kürzungen; Die Statuszählung erfolgt vor dem Entfernen überzähliger Zeilen; SettingRowCount und DriftRowCount geben jeweils das Minimum aus Vollmenge und Limit an. Profil, Quellenstatus und Warnungen bleiben ungekürzt.

**@ResultSetArt:** @ResultSetArt: CONSOLE, RAW, TABLE oder NONE. JSON wird unabhängig mit @JsonErzeugen und @Json angefordert.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur für TABLE ist ein JSON-Objekt mit Resultatnamen und vorhandenen lokalen #Temp-Zielen erforderlich, z. B. {"settings":"#DbSettings"}. Erlaubt sind moduleStatus, settings, drift, profile, sourceStatus und warnings; Namen werden case-sensitiv verglichen. Ziele müssen vorhandene leere lokale #Temp-Tabellen mit genau einer Seed-Spalte sein. ##Tabellen, reservierte #Monitor-Namen, doppelte Zuordnungen/Ziele und unbekannte Resultatnamen sind ungültig. In TABLE muss die Zuordnung nichtleer und gültig sein. Außerhalb von TABLE sind NULL, Leertext und nur U+0020-Leerzeichen zulässig; ein anderer nichtleerer Wert ist ungültig. Zielnamen sind höchstens 116 Zeichen lang. Der Preflight prüft die Zuordnung und Ziele; der spätere Writer ersetzt die Seed-Spalte durch das Ergebnisschema. Die Gruppen bedeuten: moduleStatus Modulstatus, settings Einstellungen, drift Unterschiede, profile Sollprofil, sourceStatus Quellenstatus, warnings Warnungen.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. 0 lässt @Json auf NULL; 1 befüllt es mit meta, settings, drift, profile, sourceStatus und warnings. settings und drift beachten jeweils @MaxZeilen. NULL ist ungültig. Konvertierung auf bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. OUTPUT-Parameter für das optionale JSON-Ergebnis. Wird vor Hilfe- und Analyseverzweigung auf NULL gesetzt und nur bei @JsonErzeugen=1 befüllt. Zum Empfangen ist OUTPUT zu binden; der Parameter kann ausgelassen werden, wenn kein JSON benötigt wird.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Steuert nur die zusätzliche Meldung mit RAISERROR-Schweregrad 10 und NOWAIT bei Modulstatus ungleich AVAILABLE. 0 unterdrückt die Meldung, 1 gibt sie aus; Resultsets und Status-OUTPUT-Werte bleiben unabhängig. NULL ist ungültig. Konvertierung auf bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@Hilfe:** @Hilfe bit; Default: 0. Bei 1 wird PRINT-Hilfe ausgegeben und vor Validierung sowie Katalogzugriff zurückgekehrt. @Json wurde zuvor auf NULL gesetzt; Status-OUTPUT-Parameter werden in diesem Pfad nicht beschrieben. Bei 0 oder NULL läuft die Analyse. Konvertierung auf bit: numerische 0 ergibt 0, von 0 verschiedene numerische Werte ergeben 1.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. OUTPUT-Status im normalen Analysepfad: AVAILABLE bedeutet keine Teilquellenwarnung; AVAILABLE_LIMITED bedeutet, dass mindestens eine Quelle oder Kandidat eingeschränkt war; INVALID_PARAMETER bezeichnet ungültige Auswahl-, Profil-, Zeilen- oder Ausgabeparameter; INTERNAL_ERROR bezeichnet einen internen Kandidaten-/Temp-Tabellenfehler; UNAVAILABLE_FEATURE meldet nicht verfügbare Regex-Funktionalität (SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank erforderlich). DENIED_PERMISSION und TIMEOUT sind Quellenstatus und führen regelmäßig zu AVAILABLE_LIMITED, nicht zu globalen Statuswerten. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist den Parameter nicht zu und erhält den vorherigen Variableninhalt.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. OUTPUT-Bit: 0 bei AVAILABLE, 1 bei eingeschränktem oder fehlgeschlagenem Ergebnis. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist ihn nicht zu, daher bleibt ein gebundener NULL-Eingang NULL und ein anderer Anfangswert erhalten.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. OUTPUT-Fehlernummer aus der ersten maßgeblichen Warnung, falls vorhanden, sonst NULL. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist ihn nicht zu und erhält den vorherigen Variableninhalt.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. OUTPUT-Fehler- oder Hinweismeldung aus der ersten maßgeblichen Warnung, falls vorhanden, sonst NULL. Der Parameter kann ausgelassen werden; nur beim Empfangen ist OUTPUT-Bindung nötig. Hilfe weist ihn nicht zu und erhält den vorherigen Variableninhalt.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| moduleStatus | 1 | 1 | [ModuleName] sysname NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [CrossDatabaseRequested] bit NOT NULL , [DatabaseCount] int NOT NULL , [SettingRowCount] bigint NOT NULL , [DriftRowCount] bigint NOT NULL , [ProfileEntryCount] int NOT NULL , [HasMoreSettingRows] bit NOT NULL , [HasMoreDriftRows] bit NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL |
| settings | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [SettingScope] varchar(32) NOT NULL , [SettingName] nvarchar(128) NOT NULL , [ActualValue] nvarchar(4000) NULL , [SecondaryValue] nvarchar(4000) NULL , [IsDefault] bit NULL , [SourceObject] nvarchar(256) NOT NULL , [SourceStatus] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| drift | 1 | 1 | [CapturedAtUtc] datetime2(3) NOT NULL , [DriftType] varchar(32) NOT NULL , [DatabaseId] int NULL , [DatabaseName] sysname NULL , [SettingScope] varchar(32) NOT NULL , [SettingName] nvarchar(128) NOT NULL , [ActualValue] nvarchar(4000) NULL , [ReferenceValue] nvarchar(4000) NULL , [MatchingDatabaseCount] int NULL , [ComparedDatabaseCount] int NOT NULL , [FindingCode] varchar(80) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| profile | 1 | 1 | [ProfileOrdinal] int NOT NULL PRIMARY KEY , [SettingScope] varchar(32) NOT NULL , [SettingName] nvarchar(128) NOT NULL , [ExpectedValue] nvarchar(4000) NOT NULL |
| sourceStatus | 1 | 1 | [SourceOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY , [DatabaseId] int NULL , [DatabaseName] sysname NULL , [SourceName] sysname NOT NULL , [SourceObject] nvarchar(256) NOT NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [StatusCode] varchar(40) NOT NULL , [IsPartial] bit NOT NULL , [ReturnedRowCount] bigint NOT NULL , [ErrorNumber] int NULL , [ErrorMessage] nvarchar(2048) NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
| warnings | 1 | 1 | [WarningOrdinal] int IDENTITY(1,1) NOT NULL PRIMARY KEY , [DatabaseName] sysname NULL , [SourceName] sysname NOT NULL , [StatusCode] varchar(40) NOT NULL , [ErrorNumber] int NULL , [Message] nvarchar(2048) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DatabaseConfigurationAnalysis] @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_DatabaseConfigurationAnalysis

Inventarisiert sichtbare, online befindliche und zugreifbare Datenbanken sowie Optionen, Database Scoped Configurations und Query-Store-Einstellungen.

Ohne Profil ist ein häufiger Wert nur eine lokale Vergleichsreferenz, kein Sollwert. Ein explizites Profil ergänzt Abweichungsbefunde, aber keine Änderungsanweisung.

Exakte Namensliste und Pattern sind alternative Filter. Nicht sichtbare oder nicht zugreifbare Datenbanken können fehlen.

Katalogzugriffe warten nicht auf Sperren. Berechtigungs- und Quellenfehler werden soweit möglich als Teilstatus erfasst.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_DatabaseConfigurationAnalysis
Version      : 1.0.0
Stand        : 2026-07-21
Zweck        : Die Procedure inventarisiert sichtbare, online befindliche
               und zugreifbare Datenbankoptionen, Database Scoped Configurations
               sowie Query-Store-Einstellungen. Ohne explizites Sollprofil
               weist sie Unterschiede als lokale Variation aus; ein Profil
               ergänzt getrennte Abweichungsbefunde.
Profil       : JSON-Array aus settingScope, settingName und expectedValue.
               Ohne Profil wird ausschließlich lokale Variation ausgewiesen.
Abgrenzung   : Variation oder Profilabweichung ist ein Review-Befund, keine
               universelle Fehlkonfiguration und keine automatische DDL-Anweisung.
Eigenlast    : Serverkatalog einmal; je sichtbarer Datenbank zwei kleine
               Katalogabfragen mit LOCK_TIMEOUT 0 und isoliertem Partialstatus.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DatabaseConfigurationAnalysis
Inventarisiert sichtbare, online befindliche und zugreifbare Datenbanken sowie Optionen, Database Scoped Configurations und Query-Store-Einstellungen.
Ohne Profil ist ein häufiger Wert nur eine lokale Vergleichsreferenz, kein Sollwert. Ein explizites Profil ergänzt Abweichungsbefunde, aber keine Änderungsanweisung.
Exakte Namensliste und Pattern sind alternative Filter. Nicht sichtbare oder nicht zugreifbare Datenbanken können fehlen.
Katalogzugriffe warten nicht auf Sperren. Berechtigungs- und Quellenfehler werden soweit möglich als Teilstatus erfasst.
LIKE wird case-sensitiv ausgewertet. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank.
DECLARE @Json nvarchar(max); DECLARE @Profile nvarchar(max)=N'[{"settingScope":"DATABASE","settingName":"AUTO_CLOSE","expectedValue":"OFF"}]'; EXEC [monitor].[USP_DatabaseConfigurationAnalysis] @ProfileJson=@Profile, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json];
CREATE TABLE #DatabaseConfigurationAnalysis_HelpExample (Seed int NULL);
DECLARE @ConfigurationTableMap nvarchar(max)=N'{"settings":"#DatabaseConfigurationAnalysis_HelpExample"}';
BEGIN TRY
    EXEC [monitor].[USP_DatabaseConfigurationAnalysis]
          @ResultSetArt='TABLE'
        , @ResultTablesJson=@ConfigurationTableMap;
    SELECT * FROM #DatabaseConfigurationAnalysis_HelpExample;
    DROP TABLE IF EXISTS #DatabaseConfigurationAnalysis_HelpExample;
END TRY
BEGIN CATCH
    DROP TABLE IF EXISTS #DatabaseConfigurationAnalysis_HelpExample;
    THROW;
END CATCH;
```

