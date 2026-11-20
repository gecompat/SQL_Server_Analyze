---
skill_format_version: "1.0.0"
name: "monitor.USP_ServerFeatureCapabilities"
schema_name: "monitor"
object_name: "USP_ServerFeatureCapabilities"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Erkennt zusätzliche Diagnosefunktionen versionsadaptiv für eine explizite Datenbankliste oder alle zulässigen Datenbanken."
source_path: "Code/09_VersionAdaptive/010_USP_ServerFeatureCapabilities.sql"
---

# monitor.USP_ServerFeatureCapabilities

## Zweck und Einsatz

Erkennt zusätzliche Diagnosefunktionen versionsadaptiv für eine explizite Datenbankliste oder alle zulässigen Datenbanken.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_ServerFeatureCapabilities] im vorgesehenen Datenbankkontext. Die Procedure prüft `sys.dm_os_host_info` und ausgewählte Systemkataloge für Featureerkennung; sichtbare Katalogeinträge belegen keine OS-/Agent-/Provider-Ausführung.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MitSpezialindizes | bit | nein | 1 |
| @MitQueryStoreReplicas | bit | nein | 1 |
| @MitPlattformdetails | bit | nein | 1 |
| @MaxZeilen | int | nein | 5000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@DatabaseNames:** @DatabaseNames ist eine bracket-aware Pipe-Liste: | trennt außerhalb von [...], ]] maskiert ], Pipe innerhalb von [...] bleibt im Namen; nur einteilige SQL-Namen.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. 0 schließt master, tempdb, model und msdb aus; 1 lässt Systemdatenbanken im Kandidatenscope zu. NULL wird vom Kandidatenhelfer als INVALID_PARAMETER abgelehnt. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@DatabaseNamePattern:** @DatabaseNamePattern (nvarchar(4000); Default: NULL; ausgelassen = Default): Ausgelassen = NULL. NULL lässt den Patternfilter aus; andernfalls alternativ zu @DatabaseNames. Äußere Leerzeichen werden entfernt; Präfixe werden ohne Beachtung der Groß-/Kleinschreibung erkannt: like: (SQL-LIKE), regex: (case-sensitive Regex, Flag c), regexi: (case-insensitive Regex, Flag i); ohne Präfix gilt SQL-LIKE. LIKE nutzt %, _ und SQL-Zeichenklassen [...] mit SQL_Latin1_General_CP1_CS_AS. Nach Präfixentfernung bleibt der Patterninhalt unverändert; leeres Pattern ist ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank; Syntax und Treffer werden erst bei Ausführung bewertet.

**@HighImpactConfirmed:** @HighImpactConfirmed wird an die Klasse OBJECT_ANALYSIS_CURRENT übergeben; RequiresGroupGate=0. Die Prozedur bestätigt dadurch keine Berechtigung für Datenbankgruppen.

**@MitSpezialindizes:** @MitSpezialindizes (bit; Default: 1; ausgelassen = Default): Ausgelassen = 1. 1 erfasst die optionalen Vector-/JSON-Spezialindizes; 0 und NULL lassen diesen Zweig aus. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@MitQueryStoreReplicas:** @MitQueryStoreReplicas (bit; Default: 1; ausgelassen = Default): Ausgelassen = 1. 1 erfasst Query-Store-Replica-Metadaten; 0 und NULL lassen diesen Zweig aus. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@MitPlattformdetails:** @MitPlattformdetails (bit; Default: 1; ausgelassen = Default): Ausgelassen = 1. 1 ergänzt Linux-Host-DMV-Capabilities; 0 und NULL lassen diesen Zweig aus. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@MaxZeilen:** @MaxZeilen (int; Default: 5000; ausgelassen = Default): Ausgelassen = 5000. NULL oder 0 bedeutet unbegrenzt; ein positiver Wert begrenzt nach der Erhebung unabhängig je capabilities-, databaseFeatures- und specialIndexes-Export in deren dokumentierter Sortierung. Ein negativer Wert setzt INVALID_PARAMETER. Das Limit reduziert keine Katalogprobes und kürzt keine Warnungen.

**@ResultSetArt:** @ResultSetArt: CONSOLE=formatierte Ausgabe, RAW=technische Resultsets, TABLE=capabilities, NONE=keine fachlichen Resultsets.

**@ResultTablesJson:** @ResultTablesJson TABLE-JSON muss den Schlüssel capabilities exakt auf eine lokale #Temp-Zieltabelle abbilden. Ein leeres Einspalten-Dummyziel braucht keine Seedzeile. Der Preflight liegt vor Hilfe.

**@JsonErzeugen:** @JsonErzeugen (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. 1 erzeugt JSON unabhängig von ResultSetArt; 0 und NULL erzeugen kein JSON. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@Json:** @Json wird bei Eintritt auf NULL gesetzt. @JsonErzeugen=1 liefert JSON unabhängig vom ResultSetArt.

**@PrintMeldungen:** @PrintMeldungen (bit; Default: 1; ausgelassen = Default): Ausgelassen = 1. 1 gibt bei einem Status ungleich AVAILABLE die normale Statuswarnung aus; 0 und NULL unterdrücken diese Meldung. Die Hilfe-PRINT-Ausgabe wird dadurch nicht unterdrückt. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@Hilfe:** @Hilfe (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. Nur 1 druckt Hilfe und kehrt vor Auswahl, Katalogprobes und normaler Parameter-/Filtervalidierung zurück; 0 und NULL führen den normalen Ablauf aus. @Json wird davor auf NULL gesetzt. Der TABLE-Zielpreflight und die Ablehnung eines nichtleeren @ResultTablesJson außerhalb von TABLE liegen davor. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

## Resultate und Ausgabe

RAW/CONSOLE/NONE sowie JSON mit benannten Arrays.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| capabilities | 1 | 1 | [ScopeName] nvarchar(128) NOT NULL , [FeatureName] nvarchar(128) NOT NULL , [AvailabilityStatus] varchar(40) NOT NULL , [LogicPath] nvarchar(256) NULL , [MinimumKnownMajorVersion] int NULL , [SourceObject] nvarchar(512) NULL , [Detail] nvarchar(2000) NULL , [RequiredPermission] nvarchar(512) NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_ServerFeatureCapabilities] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='CONSOLE', @JsonErzeugen=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Feature-Capabilities sind sichtbare Versions-/Plattform-/Datenbankmetadaten und kein Healthcheck.

CONSOLE und RAW geben Aufrufstatus, capabilities, databaseFeatures, specialIndexes und warnings aus; JSON umfasst meta und diese Arrays. TABLE exportiert nur capabilities.

Das Featurelimit wirkt nach Sammlung separat auf capabilities, databaseFeatures und specialIndexes; es reduziert keine Katalogprobes. Warnungen bleiben ungekürzt.

Spezialindexdetail enthält Array-Suchoption, Pfadanzahl und Disabled-Status; konkrete SQL/JSON-Pfade und JSON-Dokumentwerte werden nicht gelesen.

CREATE TABLE #ServerFeatureCapabilities_HelpExample (Placeholder int NULL);


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ServerFeatureCapabilities
Version      : 3.2.1
Stand        : 2026-10-27
Typ          : Stored Procedure
Zweck        : Erkennt zusätzliche Diagnosefunktionen versionsadaptiv für eine
               explizite Datenbankliste oder alle zulässigen Datenbanken.
SQL-Version  : SQL Server 2019 oder neuer.
Parameter    : @DatabaseNames, @DatabaseNamePattern,
               @SystemdatenbankenEinbeziehen,
               @MitSpezialindizes, @MitQueryStoreReplicas,
               @MitPlattformdetails, @MaxZeilen, @ResultSetArt,
               @JsonErzeugen, @Json OUTPUT, @PrintMeldungen, @Hilfe.
Semantik     : bracket-aware Pipe-Liste; NULL/N''=alle. Pattern ist
               separat und mit exakter Liste gegenseitig exklusiv.
Ausgabe      : RAW/CONSOLE/NONE sowie JSON mit benannten Arrays.
Locking      : Systemkataloge READUNCOMMITTED/NOLOCK; kein OBJECT_ID-Aufruf für
               versionsabhängige Objekterkennung. Der vorherige LOCK_TIMEOUT
               wird wiederhergestellt.
Änderungen   : 3.2.1 - Systemkataloge für Vector-Indizes und Query-Store-Replikas
                         über sys.all_views statt sys.views erkennen.
               3.2.0 - SQL25-002: JSON-Indizes mit Array-Option und
                         Pfadanzahl capability-adaptiv inventarisiert.
               3.1.0 - External-Runtime- und SQL-CLR-Quellen ergänzt.
               3.0.0 - @AlleDatenbanken entfernt; zentraler Datenbankvertrag,
                         Ausgabevertrag und katalogbasierte Featureerkennung.
               2.1.0 - Vorheriger Stand.
```

### Weitere bestehende Hilfehinweise

```text
Feature-Capabilities sind sichtbare Versions-/Plattform-/Datenbankmetadaten und kein Healthcheck.
CONSOLE und RAW geben Aufrufstatus, capabilities, databaseFeatures, specialIndexes und warnings aus; JSON umfasst meta und diese Arrays. TABLE exportiert nur capabilities.
Das Featurelimit wirkt nach Sammlung separat auf capabilities, databaseFeatures und specialIndexes; es reduziert keine Katalogprobes. Warnungen bleiben ungekürzt.
Spezialindexdetail enthält Array-Suchoption, Pfadanzahl und Disabled-Status; konkrete SQL/JSON-Pfade und JSON-Dokumentwerte werden nicht gelesen.
CREATE TABLE #ServerFeatureCapabilities_HelpExample (Placeholder int NULL);
DECLARE @FeatureJson nvarchar(max);
```

