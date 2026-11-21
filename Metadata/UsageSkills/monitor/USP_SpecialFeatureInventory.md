---
skill_format_version: "1.0.0"
name: "monitor.USP_SpecialFeatureInventory"
schema_name: "monitor"
object_name: "USP_SpecialFeatureInventory"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Inventarisiert leichtgewichtig die im sichtbaren Metadatenscope genutzten oder lediglich konfigurierten SQL-Server- Spezialfeatures und verweist auf passende Deep-Dive-Module."
source_path: "Code/09_VersionAdaptive/020_USP_SpecialFeatureInventory.sql"
---

# monitor.USP_SpecialFeatureInventory

## Zweck und Einsatz

Inventarisiert leichtgewichtig die im sichtbaren Metadatenscope genutzten oder lediglich konfigurierten SQL-Server- Spezialfeatures und verweist auf passende Deep-Dive-Module.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

Datenbank- und Objektkataloge für In-Memory OLTP, Temporal, Service Broker, Full-Text, Data Capture, Verschlüsselung, CLR, External Tables/Models/Runtimes, FILESTREAM, Graph, Spatial, XML, native JSON-/Vector-Typen und benutzerdefinierte Typen.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @NurErkannteFeatures | bit | nein | 0 |
| @MaxZeilen | int | nein | 2000 |
| @LockTimeoutMs | int | nein | 0 |
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

**@DatabaseNames:** @DatabaseNames ist eine bracket-aware Pipe-Liste: | trennt außerhalb von [...], ]] maskiert ], Pipe innerhalb von [...] bleibt Bestandteil; nur einteilige SQL-Namen.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL ist INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@DatabaseNamePattern:** @DatabaseNamePattern (nvarchar(4000); Default: NULL; ausgelassen = Default): Ausgelassen = NULL. NULL ohne Patternfilter; alternativ zur Namensliste. Äußere Leerzeichen werden entfernt, Präfixe case-insensitiv erkannt: like: (SQL-LIKE), regex: (case-sensitive Regex, Flag c), regexi: (case-insensitive Regex, Flag i); ohne Präfix gilt SQL-LIKE. LIKE verwendet %, _, Zeichenklassen [...] und SQL_Latin1_General_CP1_CS_AS. Der Inhalt wird nach Präfixentfernung nicht nochmals getrimmt; leerer Inhalt ist ungültig. Regex benötigt SQL Server 2025 und Compatibility Level 170 der Installationsdatenbank.

**@HighImpactConfirmed:** @HighImpactConfirmed (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. An USP_PrepareDatabaseCandidates übergeben. Diese Procedure übergibt @AnalysisClass=NULL, daher wird hier kein High-Impact-/Gruppengate aktiviert. NULL ist für den Helper trotzdem INVALID_PARAMETER; 1 gewährt keine Gruppenberechtigung. Numerisch 0 wird bit 0, jeder Nichtnullwert bit 1.

**@NurErkannteFeatures:** @NurErkannteFeatures (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. 1 behält ausschließlich DETECTED (sichtbarer Katalogmarker) und CONFIGURED_ONLY (Konfiguration ohne belegte Nutzung); 0 behält zusätzlich NOT_DETECTED_VISIBLE_SCOPE (kein sichtbarer Marker), UNAVAILABLE_VERSION (versionsbedingt nicht verfügbar) und SOURCE_UNAVAILABLE (Quellenfehler). NULL ist INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@MaxZeilen:** @MaxZeilen (int; Default: 2000; ausgelassen = Default): Ausgelassen = 2000. NULL oder 0 bedeutet unbegrenzt; positiv begrenzt nur den exportierten Featurebestand nach DatabaseName, FeatureCode. Negative Werte setzen INVALID_PARAMETER. Vollständige Inventur, Datenbankstatus und Zähler bleiben erhalten.

**@LockTimeoutMs:** @LockTimeoutMs (int; Default: 0; ausgelassen = Default): Ausgelassen = 0 ms. Zulässig ist jeder ganzzahlige Wert von 0 bis 60000 einschließlich; NULL oder außerhalb des Bereichs setzt INVALID_PARAMETER. Der Wert gilt für die Katalogpfade; vor Ausgabe wird der zuvor geltende Session-Lock-Timeout wiederhergestellt. 0 bedeutet NOWAIT und ist kein Berechtigungsopt-in.

**@ResultSetArt:** @ResultSetArt: CONSOLE=formatierte Featureausgabe mit Console-Leerzeile bei leerem Scope, RAW=Aufrufstatus/Datenbankstatus/Features, TABLE=nur features, NONE=keine fachlichen Resultsets.

**@ResultTablesJson:** @ResultTablesJson TABLE-JSON muss den Schlüssel features exakt auf eine vorhandene lokale #Temp-Tabelle abbilden. Ein leeres Einspalten-Dummyziel genügt ohne Seedzeile. Preflight kommt vor Hilfe und Inventur.

**@JsonErzeugen:** @JsonErzeugen (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. Nur 1 erzeugt JSON, unabhängig vom ResultSetArt; 0 erzeugt keines. NULL ist INVALID_PARAMETER. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@Json:** @Json wird bei Eintritt auf NULL gesetzt; JSON umfasst meta, databaseStatus und features.

**@PrintMeldungen:** @PrintMeldungen (bit; Default: 1; ausgelassen = Default): Ausgelassen = 1. 1 gibt normale Meldungen aus, wenn Status nicht AVAILABLE oder NOT_APPLICABLE ist; 0 unterdrückt sie. NULL ist INVALID_PARAMETER. Help-PRINT bleibt unabhängig davon aktiv. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@Hilfe:** @Hilfe (bit; Default: 0; ausgelassen = Default): Ausgelassen = 0. Nur 1 druckt Hilfe und kehrt vor der normalen Parameter-/Filtervalidierung zurück; 0 und NULL laufen in die normale Validierung. JSON wird zuvor auf NULL gesetzt. TABLE-Preflight und die Ablehnung eines nichtleeren @ResultTablesJson außerhalb von TABLE erfolgen vor diesem Return. T-SQL konvertiert numerisch 0 zu 0 und jeden Nichtnullwert zu 1.

**@StatusCodeOut:** @StatusCodeOut (varchar(40) OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Im normalen Abschluss liefert es den Aufrufstatus. Direkt gesetzte Modulwerte sind AVAILABLE, AVAILABLE_LIMITED, NOT_APPLICABLE und INVALID_PARAMETER; vom Kandidatenhelfer oder Quellenpfad übernommene tatsächliche Statuswerte bleiben möglich. Hilfe lässt den übergebenen Wert unverändert.

**@IsPartialOut:** @IsPartialOut (bit OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Gibt im normalen Abschluss 0/1 für Vollständigkeit/Teilstatus zurück; Hilfe lässt den übergebenen Wert unverändert.

**@ErrorNumberOut:** @ErrorNumberOut (int OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Enthält die tatsächlich erfasste Fehlernummer oder NULL; Hilfe lässt den übergebenen Wert unverändert.

**@ErrorMessageOut:** @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: NULL; ausgelassen = Default): Ausgelassen = NULL als OUTPUT-Parameter; mit OUTPUT binden. Enthält den tatsächlich erfassten Fehlertext oder NULL; Hilfe lässt den übergebenen Wert unverändert.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| features | 1 | 1 | [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , [FeatureCode] varchar(64) NOT NULL , [FeatureFamily] nvarchar(120) NOT NULL , [DetectionStatus] varchar(40) NOT NULL , [DetectedItemCount] bigint NULL , [ConfigurationState] nvarchar(120) NULL , [SourceObjects] nvarchar(1000) NOT NULL , [RecommendedModule] sysname NULL , [RecommendedModuleStatus] varchar(40) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_SpecialFeatureInventory] @DatabaseNames=N'[ExampleDatabase]', @NurErkannteFeatures=1, @ResultSetArt='CONSOLE';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

LOW. Ausschließlich aggregierte Systemkatalogabfragen; keine Benutzertabellen-, Payload-, Definitions- oder Datenscans.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_SpecialFeatureInventory
Version      : 1.3.0
Stand        : 2026-10-13
Typ          : Stored Procedure
Zweck        : Inventarisiert leichtgewichtig die im sichtbaren Metadatenscope
               genutzten oder lediglich konfigurierten SQL-Server-
               Spezialfeatures und verweist auf passende Deep-Dive-Module.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : Datenbank- und Objektkataloge für In-Memory OLTP, Temporal,
               Service Broker, Full-Text, Data Capture, Verschlüsselung, CLR,
               External Tables/Models/Runtimes, FILESTREAM, Graph, Spatial, XML,
               native JSON-/Vector-Typen und benutzerdefinierte Typen.
Abgrenzung   : Das Ergebnis ist ein Nutzungsinventar, kein Gesundheitsurteil.
               Nicht sichtbare Metadaten können zu Nullzählungen führen.
               Externe Locations, Credentials, Service-Broker-Payloads,
               CLR-Binaries und Moduldefinitionen werden nicht gelesen.
Kosten       : LOW. Ausschließlich aggregierte Systemkatalogabfragen; keine
               Benutzertabellen-, Payload-, Definitions- oder Datenscans.
Locking      : Der angeforderte LOCK_TIMEOUT gilt für die Katalogpfade; der
               vorherige Sessionwert wird vor der Ausgabe wiederhergestellt.
Änderungen   : 1.3.0 - Aggregierte External-Model-Inventur mit isoliertem
                         Quellenfehler und versionsadaptivem NULL-Fallback.
               1.2.0 - Native-JSON-Erkennung auf das implementierte
                         JSON-Indexinventar in USP_ObjectInventory geroutet.
```

### Weitere bestehende Hilfehinweise

```text
Die Procedure zählt aggregierte sichtbare Featuremetadaten; kein Gesundheits- oder Laufzeitnutzungsurteil.
Direkt gesetzte StatusCodeOut-Werte: AVAILABLE, AVAILABLE_LIMITED, NOT_APPLICABLE und INVALID_PARAMETER; Kandidaten-/Quellenstatus bleiben an den tatsächlichen Pfad gebunden.
Die taxativen DetectionStatuswerte sind DETECTED, CONFIGURED_ONLY, NOT_DETECTED_VISIBLE_SCOPE, UNAVAILABLE_VERSION und SOURCE_UNAVAILABLE. 0 ist ein sichtbarer Nullbefund; NULL ist unbekannt/nicht verfügbar.
Zähler fassen je Feature unterschiedliche Metadatenobjekte zusammen; erst Aufruf- und Datenbankstatus, dann DetectionStatus und EvidenceLimit lesen.
Native JSON verweist für JSON-Index- und Pfadmetadaten auf USP_ObjectInventory; SQL-Datenwerte bleiben ungelesen.
CREATE TABLE #SpecialFeatureInventory_HelpExample (Placeholder int NULL);
DECLARE @FeatureJson nvarchar(max);
Alle ExampleDatabase-Namen sind synthetisch. Keine externen Locations, Credentials, Broker-Payloads, CLR-Binaries, Moduldefinitionen oder Benutzerdaten werden gelesen.
```

