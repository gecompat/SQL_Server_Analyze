---
skill_format_version: "1.0.0"
name: "monitor.USP_DatabaseCapacityAnalysis"
schema_name: "monitor"
object_name: "USP_DatabaseCapacityAnalysis"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei der ausgewählten Datenbanken als lesenden Snapshot."
source_path: "Code/08_ServerHealth/120_USP_DatabaseCapacityAnalysis.sql"
---

# monitor.USP_DatabaseCapacityAnalysis

## Zweck und Einsatz

Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei der ausgewählten Datenbanken als lesenden Snapshot.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_DatabaseCapacityAnalysis] im vorgesehenen Datenbankkontext. Die Procedure liest Dateikataloge und `sys.dm_os_volume_stats` pro ausgewählter Datenbank; Volume-Sicht hängt von Callerrechten und Plattform ab.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @HighImpactConfirmed | bit | nein | 0 |
| @MinVolumeFreePercent | decimal(9,2) | nein | 10.00 |
| @NurProblematisch | bit | nein | 0 |
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

**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Eingabe ist eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], ]] maskiert ] innen. Äußere Leerzeichen je Element werden entfernt; Rohsegment höchstens 4000 UTF-16-Codeeinheiten, Name höchstens 128 Zeichen. Leere/fehlerhaft geklammerte Elemente, mehrteilige Namen und case-sensitive Duplikate desselben Filtertyps sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Namensbegrenzung; ausgelassen entspricht NULL. Nicht mit einem nichtleeren Pattern kombinierbar.

**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Schalter: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL ist ungültig; ausgelassen = 0. Nach bit-Konvertierung bleibt numerisch 0 aus, ein konvertierbarer Nichtnullwert wird 1. Verändert Kandidatenauswahl und systemdatenbankbezogene Warnungen.

**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Ein Pattern (nvarchar(4000)); NULL/ausgelassen bedeutet kein Pattern; leer oder nach LTRIM/RTRIM von U+0020-Leerzeichen leer ist ungültig. Andere Whitespacezeichen wie Tabulatoren werden nicht allgemein normalisiert. Äußere U+0020-Leerzeichen werden getrimmt. Unterstützte Modi: LIKE (ohne Präfix oder like:), regex: (case-sensitive, Flag c), regexi: (case-insensitive, Flag i); Präfixerkennung ignoriert Groß-/Kleinschreibung. Der Inhalt nach Präfixentfernung wird nicht erneut getrimmt. LIKE nutzt %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. Regexsyntax/Treffer werden durch Präfixprüfung nicht validiert. Regexausführung erfordert SQL Server 2025 sowie Compatibility Level mindestens 170 der Installationsdatenbank; sonst wird der Kandidatenpfad mit UNAVAILABLE_FEATURE beendet. Ein nicht-NULL Pattern und eine wirksame Namensliste schließen einander aus. Das Pattern begrenzt Kandidaten, setzt aber keine Mengenobergrenze.

**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Bit-Bestätigung der fest verdrahteten Analyseklasse SERVER_HEALTH_CURRENT; 0 = nicht bestätigt, 1 = bestätigt. NULL ungültig; ausgelassen = 0. Numerische Werte werden als bit konvertiert: 0 bleibt 0, konvertierbarer Nichtnullwert wird 1. Die Bestätigung selbst erteilt weder Gruppenmitgliedschaft noch Berechtigung; der Helper prüft zusätzlich die aktivierte Klassen-/Gruppenpolicy.

**@MinVolumeFreePercent:** @MinVolumeFreePercent decimal(9,2); Default: 10.00. decimal(9,2) Prozent-Schwelle, gültig 0 bis 100; ausgelassen = 10.00. NULL passiert die Rangeprüfungen, ergibt beim Vergleich UNKNOWN. LOW_VOLUME_FREE_PERCENT entsteht nur bei bekannter Volume-Gesamtgröße > 0 und wenn freier Prozentanteil < Schwelle ist; Gleichheit löst keinen Befund aus. Übergabe an dynamisches SQL als decimal(9,2).

**@NurProblematisch:** @NurProblematisch bit; Default: 0. Bit-Schalter: 0 behält auch NO_CAPACITY_INDICATOR; 1 entfernt NULL-FindingCode und NO_CAPACITY_INDICATOR. NULL erfüllt ebenfalls die IF-Bedingung und löst denselben DELETE-Pfad aus. Die anschließenden WHERE-Vergleiche mit NULL sind UNKNOWN; nach dem DELETE verbleiben reguläre Findingzeilen. Ausgelassen = 0; numerische Nichtnullwerte werden nach bit-Konvertierung 1. Filter erfolgt nach Aggregation und Status, begrenzt keine Scans.

**@MaxZeilen:** @MaxZeilen int; Default: 1000. Ganzzahlig; negative Werte ungültig, NULL/0 unbegrenzt, ausgelassen = 1000. Nach der Datei-Bewertung Findings zuerst, dann VolumeFreePercent, DatabaseName, FileId, DatabaseId. Dieselbe gefilterte und begrenzte Menge gilt für RAW, CONSOLE, TABLE und JSON. Begrenzt nicht Kandidaten, FILEPROPERTY-/Volumeabfragen, Quellenarbeit oder Laufzeit.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Bindung an varchar(16), Trim von U+0020-Leerzeichen und UPPER gelten RAW, CONSOLE, TABLE und NONE. NULL, leer und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. RAW liefert Status und die technischen Fachresultsets. CONSOLE liefert nur die lesbare capacity-Fachmenge über den Console-Helfer, ohne separates Statusresultset; TABLE schreibt nur diese benannte Fachmenge in das Ziel. NONE unterdrückt normale Resultsets. TABLE-Zielvorprüfung oder Ablehnung eines nicht leeren Mappings außerhalb TABLE laufen vor @Hilfe=1 und können werfen. Hilfe kehrt danach vor der Analyse und JSON-Erzeugung zurück; angefordertes JSON im normalen Pfad ist unabhängig vom Ausgabemodus.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Für TABLE ist ein JSON-Objekt mit genau dem Schlüssel capacity erforderlich; der Wert muss ein String mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein, etwa N'{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}'. Das Ziel muss leer sein und genau eine beliebig typisierte Seed-Spalte besitzen; beim TABLE-Schreiben richtet der Ausgabehelfer daraus die Zielspalten ein. NULL oder nach Trim von U+0020 leere Eingabe ist in TABLE ungültig. Außerhalb TABLE sind nur NULL oder nach diesem Trim leere Werte zulässig; andere Werte werfen 51011. Diese Prüfung läuft auch bei TABLE zusammen mit @Hilfe=1 vor der Hilfe-Rückkehr. Ausgelassen = NULL.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter 0 = kein JSON, 1 = JSON erzeugen; NULL wirkt wegen IF wie aus; ausgelassen = 0. Zahlen folgen bit-Konvertierung (0 bleibt 0, konvertierbarer Nichtnullwert wird 1). JSON ist unabhängig vom ResultSetArt-Modus.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionales nvarchar(max)-OUTPUT. Beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält es meta, capacity und warnings, sonst bleibt es NULL. Als Variable mit OUTPUT binden; Eingabewert bleibt nicht erhalten.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit-Schalter für Severity-10-RAISERROR mit NOWAIT bei globalem Status ungleich AVAILABLE: 1 aktiviert, 0 unterdrückt; NULL wirkt wie aus; ausgelassen = 1. Kandidatenwarnungen sind davon getrennte Resultate.

**@Hilfe:** @Hilfe bit; Default: 0. Bit-Schalter: 1 druckt Hilfe und kehrt vor Analyse-Resultaten zurück, 0 führt Analyse aus; NULL wirkt wie aus; ausgelassen = 0. OUTPUT-Ziele, die erst am normalen Ende gesetzt werden, bleiben im HELP-Pfad unverändert.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionales varchar(40)-OUTPUT. Im normalen Pfad wird am Ende gesetzt; vor dieser Zuweisung initialisiert die Procedure das Outputziel nicht, und HELP kehrt vorher zurück, sodass ein gebundener vorhandener Variablenwert erhalten bleibt. Globale Werte: AVAILABLE = kein gesetzter Finding- oder Teilstatus; AVAILABLE_WITH_FINDING = mindestens ein Finding ohne Teilstatus; AVAILABLE_LIMITED = Teilquelle oder Kandidatenwarnung begrenzt die Vollständigkeit; INVALID_PARAMETER = ungültige Eingabe; DENIED_GROUP = Analyseklasse laut aktueller Policy nicht freigegeben; DENIED_PERMISSION = erforderliche Abfrage verweigert; ERROR_HANDLED = sonstiger behandelter Analysefehler; INTERNAL_ERROR = interner Kandidatenvorbereitungsfehler; UNAVAILABLE_FEATURE = Regexmodus auf nicht unterstützter Engine-/Installationsdatenbank-Kompatibilität. Beide fest verdrahteten Klassen haben RequiresGroupGate=0, daher verlangen sie keine High-Impact-Bestätigung. Per-Datenbank-Warnungen wie SYSTEM_DATABASE_EXCLUDED (Systemdatenbank aus Scope ausgelassen) und DATABASE_UNAVAILABLE (Kandidat nicht verfügbar) sind Warnungszeilen, keine globalen Codes; Kapazitätsabfragefehler werden ebenfalls dort je Datenbank erfasst. Teilstatus wird zusätzlich über @IsPartialOut signalisiert. Als Variable mit OUTPUT-Bindung übergeben; ausgelassen wird kein Wert zurückgegeben. Optionaler Empfang mit @StatusCodeOut=@Empfaenger OUTPUT; die Variable muss varchar(40) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.

**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionales bit-OUTPUT zur Teilvollständigkeit (0 vollständig, 1 Teilquelle/Berechtigungs-/Warnungseinschränkung). HELP erreicht die normale Zuweisung nicht und lässt den bisherigen Variablenwert unverändert. Als Variable mit OUTPUT binden. Optionaler Empfang mit @IsPartialOut=@Empfaenger OUTPUT; die Variable muss bit sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionales int-OUTPUT für die gespeicherte SQL-Fehlernummer; NULL, wenn keine gespeichert wurde. HELP weist nicht zu. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT; die Variable muss int sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionales nvarchar(2048)-OUTPUT für gespeicherten Fehler-/Teilhinweis; ohne Hinweis NULL. HELP weist nicht zu. Kandidatenwarnungen bleiben separat. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT; die Variable muss nvarchar(2048) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.

## Resultate und Ausgabe

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| capacity | 1 | 1 | [DatabaseId] int NULL , [DatabaseName] sysname NULL , [FileId] int NULL , [LogicalFileName] sysname NULL , [FileTypeDesc] nvarchar(60) NULL , [PhysicalName] nvarchar(260) NULL , [FileSizeMb] decimal(19,2) NULL , [UsedInFileMb] decimal(19,2) NULL , [FreeInFileMb] decimal(19,2) NULL , [FreeInFilePercent] decimal(9,2) NULL , [GrowthDescription] nvarchar(80) NULL , [NextGrowthMb] decimal(19,2) NULL , [MaxSizeMb] decimal(19,2) NULL , [VolumeMountPoint] nvarchar(512) NULL , [LogicalVolumeName] nvarchar(512) NULL , [VolumeTotalMb] decimal(19,2) NULL , [VolumeAvailableMb] decimal(19,2) NULL , [VolumeFreePercent] decimal(9,2) NULL , [FindingCode] varchar(80) NULL , [EvidenceLimit] nvarchar(500) NOT NULL |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Eine Zeit-bis-voll-Prognose wird ohne persistente Historie nicht erzeugt. Alle Bewertungen sind Momentaufnahmen.

rein lesend; keine Datei- oder Datenbankänderung.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_DatabaseCapacityAnalysis
Version      : 1.0.1
Stand        : 2026-07-18
Zweck        : Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei
               der ausgewählten Datenbanken als lesenden Snapshot.
Datenquellen : sys.database_files, FILEPROPERTY, sys.dm_os_volume_stats.
Grenzen      : Eine Zeit-bis-voll-Prognose wird ohne persistente Historie nicht
               erzeugt. Alle Bewertungen sind Momentaufnahmen.
Nebenwirkung : rein lesend; keine Datei- oder Datenbankänderung.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_DatabaseCapacityAnalysis
Die Procedure bewertet je Datenbank und Datei einen lesenden Snapshot von Datei- und Volume-Freiraum sowie Wachstumseinstellungen. Ohne Historie entsteht keine Zeit-bis-voll-Prognose.
DECLARE @CapacityJson nvarchar(max); EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@CapacityJson OUTPUT; SELECT @CapacityJson AS [Json];
CREATE TABLE [#DatabaseCapacityAnalysis_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#DatabaseCapacityAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE [#DatabaseCapacityAnalysis_HelpExample];
```

