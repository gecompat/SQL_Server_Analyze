USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DatabaseCapacityAnalysis
Version      : 1.0.1
Stand        : 2026-07-18
Zweck        : Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei
               der ausgewählten Datenbanken als lesenden Snapshot.
Datenquellen : sys.database_files, FILEPROPERTY, sys.dm_os_volume_stats.
Grenzen      : Eine Zeit-bis-voll-Prognose wird ohne persistente Historie nicht
               erzeugt. Alle Bewertungen sind Momentaufnahmen.
Nebenwirkung : rein lesend; keine Datei- oder Datenbankänderung.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_DatabaseCapacityAnalysis 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_DatabaseCapacityAnalysis"
-- schema_name: "monitor"
-- object_name: "USP_DatabaseCapacityAnalysis"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei der ausgewählten Datenbanken als lesenden Snapshot."
-- source_path: "Code/08_ServerHealth/120_USP_DatabaseCapacityAnalysis.sql"
-- ---
-- 
-- # monitor.USP_DatabaseCapacityAnalysis
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei der ausgewählten Datenbanken als lesenden Snapshot.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufruf braucht EXECUTE auf [monitor].[USP_DatabaseCapacityAnalysis] im vorgesehenen Datenbankkontext. Die Procedure liest Dateikataloge und `sys.dm_os_volume_stats` pro ausgewählter Datenbank; Volume-Sicht hängt von Callerrechten und Plattform ab.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @DatabaseNames | nvarchar(max) | nein | NULL |
-- | @SystemdatenbankenEinbeziehen | bit | nein | 0 |
-- | @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
-- | @HighImpactConfirmed | bit | nein | 0 |
-- | @MinVolumeFreePercent | decimal(9,2) | nein | 10.00 |
-- | @NurProblematisch | bit | nein | 0 |
-- | @MaxZeilen | int | nein | 1000 |
-- | @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
-- | @ResultTablesJson | nvarchar(max) | nein | NULL |
-- | @JsonErzeugen | bit | nein | 0 |
-- | @Json | nvarchar(max) | nein | NULL OUTPUT |
-- | @PrintMeldungen | bit | nein | 1 |
-- | @Hilfe | bit | nein | 0 |
-- | @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
-- | @IsPartialOut | bit | nein | NULL OUTPUT |
-- | @ErrorNumberOut | int | nein | NULL OUTPUT |
-- | @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |
-- 
-- **@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Eingabe ist eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], ]] maskiert ] innen. Äußere Leerzeichen je Element werden entfernt; Rohsegment höchstens 4000 UTF-16-Codeeinheiten, Name höchstens 128 Zeichen. Leere/fehlerhaft geklammerte Elemente, mehrteilige Namen und case-sensitive Duplikate desselben Filtertyps sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Namensbegrenzung; ausgelassen entspricht NULL. Nicht mit einem nichtleeren Pattern kombinierbar.
-- 
-- **@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Schalter: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL ist ungültig; ausgelassen = 0. Nach bit-Konvertierung bleibt numerisch 0 aus, ein konvertierbarer Nichtnullwert wird 1. Verändert Kandidatenauswahl und systemdatenbankbezogene Warnungen.
-- 
-- **@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Ein Pattern (nvarchar(4000)); NULL/ausgelassen bedeutet kein Pattern; leer oder nach LTRIM/RTRIM von U+0020-Leerzeichen leer ist ungültig. Andere Whitespacezeichen wie Tabulatoren werden nicht allgemein normalisiert. Äußere U+0020-Leerzeichen werden getrimmt. Unterstützte Modi: LIKE (ohne Präfix oder like:), regex: (case-sensitive, Flag c), regexi: (case-insensitive, Flag i); Präfixerkennung ignoriert Groß-/Kleinschreibung. Der Inhalt nach Präfixentfernung wird nicht erneut getrimmt. LIKE nutzt %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. Regexsyntax/Treffer werden durch Präfixprüfung nicht validiert. Regexausführung erfordert SQL Server 2025 sowie Compatibility Level mindestens 170 der Installationsdatenbank; sonst wird der Kandidatenpfad mit UNAVAILABLE_FEATURE beendet. Ein nicht-NULL Pattern und eine wirksame Namensliste schließen einander aus. Das Pattern begrenzt Kandidaten, setzt aber keine Mengenobergrenze.
-- 
-- **@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Bit-Bestätigung der fest verdrahteten Analyseklasse SERVER_HEALTH_CURRENT; 0 = nicht bestätigt, 1 = bestätigt. NULL ungültig; ausgelassen = 0. Numerische Werte werden als bit konvertiert: 0 bleibt 0, konvertierbarer Nichtnullwert wird 1. Die Bestätigung selbst erteilt weder Gruppenmitgliedschaft noch Berechtigung; der Helper prüft zusätzlich die aktivierte Klassen-/Gruppenpolicy.
-- 
-- **@MinVolumeFreePercent:** @MinVolumeFreePercent decimal(9,2); Default: 10.00. decimal(9,2) Prozent-Schwelle, gültig 0 bis 100; ausgelassen = 10.00. NULL passiert die Rangeprüfungen, ergibt beim Vergleich UNKNOWN. LOW_VOLUME_FREE_PERCENT entsteht nur bei bekannter Volume-Gesamtgröße > 0 und wenn freier Prozentanteil < Schwelle ist; Gleichheit löst keinen Befund aus. Übergabe an dynamisches SQL als decimal(9,2).
-- 
-- **@NurProblematisch:** @NurProblematisch bit; Default: 0. Bit-Schalter: 0 behält auch NO_CAPACITY_INDICATOR; 1 entfernt NULL-FindingCode und NO_CAPACITY_INDICATOR. NULL erfüllt ebenfalls die IF-Bedingung und löst denselben DELETE-Pfad aus. Die anschließenden WHERE-Vergleiche mit NULL sind UNKNOWN; nach dem DELETE verbleiben reguläre Findingzeilen. Ausgelassen = 0; numerische Nichtnullwerte werden nach bit-Konvertierung 1. Filter erfolgt nach Aggregation und Status, begrenzt keine Scans.
-- 
-- **@MaxZeilen:** @MaxZeilen int; Default: 1000. Ganzzahlig; negative Werte ungültig, NULL/0 unbegrenzt, ausgelassen = 1000. Nach der Datei-Bewertung Findings zuerst, dann VolumeFreePercent, DatabaseName, FileId, DatabaseId. Dieselbe gefilterte und begrenzte Menge gilt für RAW, CONSOLE, TABLE und JSON. Begrenzt nicht Kandidaten, FILEPROPERTY-/Volumeabfragen, Quellenarbeit oder Laufzeit.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Bindung an varchar(16), Trim von U+0020-Leerzeichen und UPPER gelten RAW, CONSOLE, TABLE und NONE. NULL, leer und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. RAW liefert Status und die technischen Fachresultsets. CONSOLE liefert nur die lesbare capacity-Fachmenge über den Console-Helfer, ohne separates Statusresultset; TABLE schreibt nur diese benannte Fachmenge in das Ziel. NONE unterdrückt normale Resultsets. TABLE-Zielvorprüfung oder Ablehnung eines nicht leeren Mappings außerhalb TABLE laufen vor @Hilfe=1 und können werfen. Hilfe kehrt danach vor der Analyse und JSON-Erzeugung zurück; angefordertes JSON im normalen Pfad ist unabhängig vom Ausgabemodus.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Für TABLE ist ein JSON-Objekt mit genau dem Schlüssel capacity erforderlich; der Wert muss ein String mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein, etwa N'{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}'. Das Ziel muss leer sein und genau eine beliebig typisierte Seed-Spalte besitzen; beim TABLE-Schreiben richtet der Ausgabehelfer daraus die Zielspalten ein. NULL oder nach Trim von U+0020 leere Eingabe ist in TABLE ungültig. Außerhalb TABLE sind nur NULL oder nach diesem Trim leere Werte zulässig; andere Werte werfen 51011. Diese Prüfung läuft auch bei TABLE zusammen mit @Hilfe=1 vor der Hilfe-Rückkehr. Ausgelassen = NULL.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter 0 = kein JSON, 1 = JSON erzeugen; NULL wirkt wegen IF wie aus; ausgelassen = 0. Zahlen folgen bit-Konvertierung (0 bleibt 0, konvertierbarer Nichtnullwert wird 1). JSON ist unabhängig vom ResultSetArt-Modus.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionales nvarchar(max)-OUTPUT. Beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält es meta, capacity und warnings, sonst bleibt es NULL. Als Variable mit OUTPUT binden; Eingabewert bleibt nicht erhalten.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit-Schalter für Severity-10-RAISERROR mit NOWAIT bei globalem Status ungleich AVAILABLE: 1 aktiviert, 0 unterdrückt; NULL wirkt wie aus; ausgelassen = 1. Kandidatenwarnungen sind davon getrennte Resultate.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. Bit-Schalter: 1 druckt Hilfe und kehrt vor Analyse-Resultaten zurück, 0 führt Analyse aus; NULL wirkt wie aus; ausgelassen = 0. OUTPUT-Ziele, die erst am normalen Ende gesetzt werden, bleiben im HELP-Pfad unverändert.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionales varchar(40)-OUTPUT. Im normalen Pfad wird am Ende gesetzt; vor dieser Zuweisung initialisiert die Procedure das Outputziel nicht, und HELP kehrt vorher zurück, sodass ein gebundener vorhandener Variablenwert erhalten bleibt. Globale Werte: AVAILABLE = kein gesetzter Finding- oder Teilstatus; AVAILABLE_WITH_FINDING = mindestens ein Finding ohne Teilstatus; AVAILABLE_LIMITED = Teilquelle oder Kandidatenwarnung begrenzt die Vollständigkeit; INVALID_PARAMETER = ungültige Eingabe; DENIED_GROUP = Analyseklasse laut aktueller Policy nicht freigegeben; DENIED_PERMISSION = erforderliche Abfrage verweigert; ERROR_HANDLED = sonstiger behandelter Analysefehler; INTERNAL_ERROR = interner Kandidatenvorbereitungsfehler; UNAVAILABLE_FEATURE = Regexmodus auf nicht unterstützter Engine-/Installationsdatenbank-Kompatibilität. Beide fest verdrahteten Klassen haben RequiresGroupGate=0, daher verlangen sie keine High-Impact-Bestätigung. Per-Datenbank-Warnungen wie SYSTEM_DATABASE_EXCLUDED (Systemdatenbank aus Scope ausgelassen) und DATABASE_UNAVAILABLE (Kandidat nicht verfügbar) sind Warnungszeilen, keine globalen Codes; Kapazitätsabfragefehler werden ebenfalls dort je Datenbank erfasst. Teilstatus wird zusätzlich über @IsPartialOut signalisiert. Als Variable mit OUTPUT-Bindung übergeben; ausgelassen wird kein Wert zurückgegeben. Optionaler Empfang mit @StatusCodeOut=@Empfaenger OUTPUT; die Variable muss varchar(40) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.
-- 
-- **@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionales bit-OUTPUT zur Teilvollständigkeit (0 vollständig, 1 Teilquelle/Berechtigungs-/Warnungseinschränkung). HELP erreicht die normale Zuweisung nicht und lässt den bisherigen Variablenwert unverändert. Als Variable mit OUTPUT binden. Optionaler Empfang mit @IsPartialOut=@Empfaenger OUTPUT; die Variable muss bit sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionales int-OUTPUT für die gespeicherte SQL-Fehlernummer; NULL, wenn keine gespeichert wurde. HELP weist nicht zu. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT; die Variable muss int sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionales nvarchar(2048)-OUTPUT für gespeicherten Fehler-/Teilhinweis; ohne Hinweis NULL. HELP weist nicht zu. Kandidatenwarnungen bleiben separat. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT; die Variable muss nvarchar(2048) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.
-- 
-- ## Resultate und Ausgabe
-- 
-- | Resultmenge | RAW | TABLE | Felder laut Inventar |
-- | --- | --- | --- | --- |
-- | capacity | 1 | 1 | [DatabaseId] int NULL , [DatabaseName] sysname NULL , [FileId] int NULL , [LogicalFileName] sysname NULL , [FileTypeDesc] nvarchar(60) NULL , [PhysicalName] nvarchar(260) NULL , [FileSizeMb] decimal(19,2) NULL , [UsedInFileMb] decimal(19,2) NULL , [FreeInFileMb] decimal(19,2) NULL , [FreeInFilePercent] decimal(9,2) NULL , [GrowthDescription] nvarchar(80) NULL , [NextGrowthMb] decimal(19,2) NULL , [MaxSizeMb] decimal(19,2) NULL , [VolumeMountPoint] nvarchar(512) NULL , [LogicalVolumeName] nvarchar(512) NULL , [VolumeTotalMb] decimal(19,2) NULL , [VolumeAvailableMb] decimal(19,2) NULL , [VolumeFreePercent] decimal(9,2) NULL , [FindingCode] varchar(80) NULL , [EvidenceLimit] nvarchar(500) NOT NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Eine Zeit-bis-voll-Prognose wird ohne persistente Historie nicht erzeugt. Alle Bewertungen sind Momentaufnahmen.
-- 
-- rein lesend; keine Datei- oder Datenbankänderung.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_DatabaseCapacityAnalysis
-- Version      : 1.0.1
-- Stand        : 2026-07-18
-- Zweck        : Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei
--                der ausgewählten Datenbanken als lesenden Snapshot.
-- Datenquellen : sys.database_files, FILEPROPERTY, sys.dm_os_volume_stats.
-- Grenzen      : Eine Zeit-bis-voll-Prognose wird ohne persistente Historie nicht
--                erzeugt. Alle Bewertungen sind Momentaufnahmen.
-- Nebenwirkung : rein lesend; keine Datei- oder Datenbankänderung.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_DatabaseCapacityAnalysis
-- Die Procedure bewertet je Datenbank und Datei einen lesenden Snapshot von Datei- und Volume-Freiraum sowie Wachstumseinstellungen. Ohne Historie entsteht keine Zeit-bis-voll-Prognose.
-- DECLARE @CapacityJson nvarchar(max); EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@CapacityJson OUTPUT; SELECT @CapacityJson AS [Json];
-- CREATE TABLE [#DatabaseCapacityAnalysis_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#DatabaseCapacityAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE [#DatabaseCapacityAnalysis_HelpExample];
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_DatabaseCapacityAnalysis
CREATE OR ALTER PROCEDURE [monitor].[USP_DatabaseCapacityAnalysis]
      @DatabaseNames                nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen bit            = 0
    , @DatabaseNamePattern          nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @MinVolumeFreePercent         decimal(9,2)   = 10.00
    , @NurProblematisch             bit            = 0
    , @MaxZeilen                    int            = 1000
    , @ResultSetArt                 varchar(16)    = 'CONSOLE'
    , @ResultTablesJson               nvarchar(max) = NULL
    , @JsonErzeugen                 bit            = 0
    , @Json                         nvarchar(max)  = NULL OUTPUT
    , @PrintMeldungen               bit            = 1
    , @Hilfe                        bit            = 0
    , @StatusCodeOut                varchar(40)    = NULL OUTPUT
    , @IsPartialOut                 bit            = NULL OUTPUT
    , @ErrorNumberOut               int            = NULL OUTPUT
    , @ErrorMessageOut              nvarchar(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        SET @Json=NULL;
        PRINT N'monitor.USP_DatabaseCapacityAnalysis';
        PRINT N'Die Procedure bewertet je Datenbank und Datei einen lesenden Snapshot von Datei- und Volume-Freiraum sowie Wachstumseinstellungen. Ohne Historie entsteht keine Zeit-bis-voll-Prognose.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Eingabe ist eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], ]] maskiert ] innen. Äußere Leerzeichen je Element werden entfernt; Rohsegment höchstens 4000 UTF-16-Codeeinheiten, Name höchstens 128 Zeichen. Leere/fehlerhaft geklammerte Elemente, mehrteilige Namen und case-sensitive Duplikate desselben Filtertyps sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Namensbegrenzung; ausgelassen entspricht NULL. Nicht mit einem nichtleeren Pattern kombinierbar.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Schalter: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL ist ungültig; ausgelassen = 0. Nach bit-Konvertierung bleibt numerisch 0 aus, ein konvertierbarer Nichtnullwert wird 1. Verändert Kandidatenauswahl und systemdatenbankbezogene Warnungen.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Ein Pattern (nvarchar(4000)); NULL/ausgelassen bedeutet kein Pattern; leer oder nach LTRIM/RTRIM von U+0020-Leerzeichen leer ist ungültig. Andere Whitespacezeichen wie Tabulatoren werden nicht allgemein normalisiert. Äußere U+0020-Leerzeichen werden getrimmt. Unterstützte Modi: LIKE (ohne Präfix oder like:), regex: (case-sensitive, Flag c), regexi: (case-insensitive, Flag i); Präfixerkennung ignoriert Groß-/Kleinschreibung. Der Inhalt nach Präfixentfernung wird nicht erneut getrimmt. LIKE nutzt %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. Regexsyntax/Treffer werden durch Präfixprüfung nicht validiert. Regexausführung erfordert SQL Server 2025 sowie Compatibility Level mindestens 170 der Installationsdatenbank; sonst wird der Kandidatenpfad mit UNAVAILABLE_FEATURE beendet. Ein nicht-NULL Pattern und eine wirksame Namensliste schließen einander aus. Das Pattern begrenzt Kandidaten, setzt aber keine Mengenobergrenze.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. Bit-Bestätigung der fest verdrahteten Analyseklasse SERVER_HEALTH_CURRENT; 0 = nicht bestätigt, 1 = bestätigt. NULL ungültig; ausgelassen = 0. Numerische Werte werden als bit konvertiert: 0 bleibt 0, konvertierbarer Nichtnullwert wird 1. Die Bestätigung selbst erteilt weder Gruppenmitgliedschaft noch Berechtigung; der Helper prüft zusätzlich die aktivierte Klassen-/Gruppenpolicy.';
        PRINT N'@MinVolumeFreePercent decimal(9,2); Default: 10.00. decimal(9,2) Prozent-Schwelle, gültig 0 bis 100; ausgelassen = 10.00. NULL passiert die Rangeprüfungen, ergibt beim Vergleich UNKNOWN. LOW_VOLUME_FREE_PERCENT entsteht nur bei bekannter Volume-Gesamtgröße > 0 und wenn freier Prozentanteil < Schwelle ist; Gleichheit löst keinen Befund aus. Übergabe an dynamisches SQL als decimal(9,2).';
        PRINT N'@NurProblematisch bit; Default: 0. Bit-Schalter: 0 behält auch NO_CAPACITY_INDICATOR; 1 entfernt NULL-FindingCode und NO_CAPACITY_INDICATOR. NULL erfüllt ebenfalls die IF-Bedingung und löst denselben DELETE-Pfad aus. Die anschließenden WHERE-Vergleiche mit NULL sind UNKNOWN; nach dem DELETE verbleiben reguläre Findingzeilen. Ausgelassen = 0; numerische Nichtnullwerte werden nach bit-Konvertierung 1. Filter erfolgt nach Aggregation und Status, begrenzt keine Scans.';
        PRINT N'@MaxZeilen int; Default: 1000. Ganzzahlig; negative Werte ungültig, NULL/0 unbegrenzt, ausgelassen = 1000. Nach der Datei-Bewertung Findings zuerst, dann VolumeFreePercent, DatabaseName, FileId, DatabaseId. Dieselbe gefilterte und begrenzte Menge gilt für RAW, CONSOLE, TABLE und JSON. Begrenzt nicht Kandidaten, FILEPROPERTY-/Volumeabfragen, Quellenarbeit oder Laufzeit.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Bindung an varchar(16), Trim von U+0020-Leerzeichen und UPPER gelten RAW, CONSOLE, TABLE und NONE. NULL, leer und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. RAW liefert Status und die technischen Fachresultsets. CONSOLE liefert nur die lesbare capacity-Fachmenge über den Console-Helfer, ohne separates Statusresultset; TABLE schreibt nur diese benannte Fachmenge in das Ziel. NONE unterdrückt normale Resultsets. TABLE-Zielvorprüfung oder Ablehnung eines nicht leeren Mappings außerhalb TABLE laufen vor @Hilfe=1 und können werfen. Hilfe kehrt danach vor der Analyse und JSON-Erzeugung zurück; angefordertes JSON im normalen Pfad ist unabhängig vom Ausgabemodus.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Für TABLE ist ein JSON-Objekt mit genau dem Schlüssel capacity erforderlich; der Wert muss ein String mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein, etwa N''{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}''. Das Ziel muss leer sein und genau eine beliebig typisierte Seed-Spalte besitzen; beim TABLE-Schreiben richtet der Ausgabehelfer daraus die Zielspalten ein. NULL oder nach Trim von U+0020 leere Eingabe ist in TABLE ungültig. Außerhalb TABLE sind nur NULL oder nach diesem Trim leere Werte zulässig; andere Werte werfen 51011. Diese Prüfung läuft auch bei TABLE zusammen mit @Hilfe=1 vor der Hilfe-Rückkehr. Ausgelassen = NULL.';
        PRINT N'@JsonErzeugen bit; Default: 0. Bit-Schalter 0 = kein JSON, 1 = JSON erzeugen; NULL wirkt wegen IF wie aus; ausgelassen = 0. Zahlen folgen bit-Konvertierung (0 bleibt 0, konvertierbarer Nichtnullwert wird 1). JSON ist unabhängig vom ResultSetArt-Modus.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionales nvarchar(max)-OUTPUT. Beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält es meta, capacity und warnings, sonst bleibt es NULL. Als Variable mit OUTPUT binden; Eingabewert bleibt nicht erhalten.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bit-Schalter für Severity-10-RAISERROR mit NOWAIT bei globalem Status ungleich AVAILABLE: 1 aktiviert, 0 unterdrückt; NULL wirkt wie aus; ausgelassen = 1. Kandidatenwarnungen sind davon getrennte Resultate.';
        PRINT N'@Hilfe bit; Default: 0. Bit-Schalter: 1 druckt Hilfe und kehrt vor Analyse-Resultaten zurück, 0 führt Analyse aus; NULL wirkt wie aus; ausgelassen = 0. OUTPUT-Ziele, die erst am normalen Ende gesetzt werden, bleiben im HELP-Pfad unverändert.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionales varchar(40)-OUTPUT. Im normalen Pfad wird am Ende gesetzt; vor dieser Zuweisung initialisiert die Procedure das Outputziel nicht, und HELP kehrt vorher zurück, sodass ein gebundener vorhandener Variablenwert erhalten bleibt. Globale Werte: AVAILABLE = kein gesetzter Finding- oder Teilstatus; AVAILABLE_WITH_FINDING = mindestens ein Finding ohne Teilstatus; AVAILABLE_LIMITED = Teilquelle oder Kandidatenwarnung begrenzt die Vollständigkeit; INVALID_PARAMETER = ungültige Eingabe; DENIED_GROUP = Analyseklasse laut aktueller Policy nicht freigegeben; DENIED_PERMISSION = erforderliche Abfrage verweigert; ERROR_HANDLED = sonstiger behandelter Analysefehler; INTERNAL_ERROR = interner Kandidatenvorbereitungsfehler; UNAVAILABLE_FEATURE = Regexmodus auf nicht unterstützter Engine-/Installationsdatenbank-Kompatibilität. Beide fest verdrahteten Klassen haben RequiresGroupGate=0, daher verlangen sie keine High-Impact-Bestätigung. Per-Datenbank-Warnungen wie SYSTEM_DATABASE_EXCLUDED (Systemdatenbank aus Scope ausgelassen) und DATABASE_UNAVAILABLE (Kandidat nicht verfügbar) sind Warnungszeilen, keine globalen Codes; Kapazitätsabfragefehler werden ebenfalls dort je Datenbank erfasst. Teilstatus wird zusätzlich über @IsPartialOut signalisiert. Als Variable mit OUTPUT-Bindung übergeben; ausgelassen wird kein Wert zurückgegeben. Optionaler Empfang mit @StatusCodeOut=@Empfaenger OUTPUT; die Variable muss varchar(40) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionales bit-OUTPUT zur Teilvollständigkeit (0 vollständig, 1 Teilquelle/Berechtigungs-/Warnungseinschränkung). HELP erreicht die normale Zuweisung nicht und lässt den bisherigen Variablenwert unverändert. Als Variable mit OUTPUT binden. Optionaler Empfang mit @IsPartialOut=@Empfaenger OUTPUT; die Variable muss bit sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionales int-OUTPUT für die gespeicherte SQL-Fehlernummer; NULL, wenn keine gespeichert wurde. HELP weist nicht zu. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT; die Variable muss int sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionales nvarchar(2048)-OUTPUT für gespeicherten Fehler-/Teilhinweis; ohne Hinweis NULL. HELP weist nicht zu. Kandidatenwarnungen bleiben separat. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT; die Variable muss nvarchar(2048) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.';
        PRINT N'EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @CapacityJson nvarchar(max); EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@CapacityJson OUTPUT; SELECT @CapacityJson AS [Json];';
        PRINT N'CREATE TABLE [#DatabaseCapacityAnalysis_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}''; END TRY BEGIN CATCH DROP TABLE [#DatabaseCapacityAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE [#DatabaseCapacityAnalysis_HelpExample];';
        PRINT N'EXEC [monitor].[USP_DatabaseCapacityAnalysis] @Hilfe=1;';



        -- USAGE_SKILL_HELP_BEGIN monitor.USP_DatabaseCapacityAnalysis
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_DatabaseCapacityAnalysis') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_DatabaseCapacityAnalysis"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_DatabaseCapacityAnalysis"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei der ausgewählten Datenbanken als lesenden Snapshot."'
            + NCHAR(10)
            + N'source_path: "Code/08_ServerHealth/120_USP_DatabaseCapacityAnalysis.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_DatabaseCapacityAnalysis'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei der ausgewählten Datenbanken als lesenden Snapshot.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Aufruf braucht EXECUTE auf [monitor].[USP_DatabaseCapacityAnalysis] im vorgesehenen Datenbankkontext. Die Procedure liest Dateikataloge und `sys.dm_os_volume_stats` pro ausgewählter Datenbank; Volume-Sicht hängt von Callerrechten und Plattform ab.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Parameter und Eingabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| @DatabaseNames | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @SystemdatenbankenEinbeziehen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |'
            + NCHAR(10)
            + N'| @HighImpactConfirmed | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MinVolumeFreePercent | decimal(9,2) | nein | 10.00 |'
            + NCHAR(10)
            + N'| @NurProblematisch | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @MaxZeilen | int | nein | 1000 |'
            + NCHAR(10)
            + N'| @ResultSetArt | varchar(16) | nein | ''CONSOLE'' |'
            + NCHAR(10)
            + N'| @ResultTablesJson | nvarchar(max) | nein | NULL |'
            + NCHAR(10)
            + N'| @JsonErzeugen | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @Json | nvarchar(max) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @PrintMeldungen | bit | nein | 1 |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int | nein | NULL OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@DatabaseNames:** @DatabaseNames nvarchar(max); Default: NULL. Eingabe ist eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], ]] maskiert ] innen. Äußere Leerzeichen je Element werden entfernt; Rohsegment höchstens 4000 UTF-16-Codeeinheiten, Name höchstens 128 Zeichen. Leere/fehlerhaft geklammerte Elemente, mehrteilige Namen und case-sensitive Duplikate desselben Filtertyps sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Namensbegrenzung; ausgelassen entspricht NULL. Nicht mit einem nichtleeren Pattern kombinierbar.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Schalter: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL ist ungültig; ausgelassen = 0. Nach bit-Konvertierung bleibt numerisch 0 aus, ein konvertierbarer Nichtnullwert wird 1. Verändert Kandidatenauswahl und systemdatenbankbezogene Warnungen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@DatabaseNamePattern:** @DatabaseNamePattern nvarchar(4000); Default: NULL. Ein Pattern (nvarchar(4000)); NULL/ausgelassen bedeutet kein Pattern; leer oder nach LTRIM/RTRIM von U+0020-Leerzeichen leer ist ungültig. Andere Whitespacezeichen wie Tabulatoren werden nicht allgemein normalisiert. Äußere U+0020-Leerzeichen werden getrimmt. Unterstützte Modi: LIKE (ohne Präfix oder like:), regex: (case-sensitive, Flag c), regexi: (case-insensitive, Flag i); Präfixerkennung ignoriert Groß-/Kleinschreibung. Der Inhalt nach Präfixentfernung wird nicht erneut getrimmt. LIKE nutzt %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. Regexsyntax/Treffer werden durch Präfixprüfung nicht validiert. Regexausführung erfordert SQL Server 2025 sowie Compatibility Level mindestens 170 der Installationsdatenbank; sonst wird der Kandidatenpfad mit UNAVAILABLE_FEATURE beendet. Ein nicht-NULL Pattern und eine wirksame Namensliste schließen einander aus. Das Pattern begrenzt Kandidaten, setzt aber keine Mengen'
            + N'obergrenze.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Bit-Bestätigung der fest verdrahteten Analyseklasse SERVER_HEALTH_CURRENT; 0 = nicht bestätigt, 1 = bestätigt. NULL ungültig; ausgelassen = 0. Numerische Werte werden als bit konvertiert: 0 bleibt 0, konvertierbarer Nichtnullwert wird 1. Die Bestätigung selbst erteilt weder Gruppenmitgliedschaft noch Berechtigung; der Helper prüft zusätzlich die aktivierte Klassen-/Gruppenpolicy.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MinVolumeFreePercent:** @MinVolumeFreePercent decimal(9,2); Default: 10.00. decimal(9,2) Prozent-Schwelle, gültig 0 bis 100; ausgelassen = 10.00. NULL passiert die Rangeprüfungen, ergibt beim Vergleich UNKNOWN. LOW_VOLUME_FREE_PERCENT entsteht nur bei bekannter Volume-Gesamtgröße > 0 und wenn freier Prozentanteil < Schwelle ist; Gleichheit löst keinen Befund aus. Übergabe an dynamisches SQL als decimal(9,2).'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@NurProblematisch:** @NurProblematisch bit; Default: 0. Bit-Schalter: 0 behält auch NO_CAPACITY_INDICATOR; 1 entfernt NULL-FindingCode und NO_CAPACITY_INDICATOR. NULL erfüllt ebenfalls die IF-Bedingung und löst denselben DELETE-Pfad aus. Die anschließenden WHERE-Vergleiche mit NULL sind UNKNOWN; nach dem DELETE verbleiben reguläre Findingzeilen. Ausgelassen = 0; numerische Nichtnullwerte werden nach bit-Konvertierung 1. Filter erfolgt nach Aggregation und Status, begrenzt keine Scans.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int; Default: 1000. Ganzzahlig; negative Werte ungültig, NULL/0 unbegrenzt, ausgelassen = 1000. Nach der Datei-Bewertung Findings zuerst, dann VolumeFreePercent, DatabaseName, FileId, DatabaseId. Dieselbe gefilterte und begrenzte Menge gilt für RAW, CONSOLE, TABLE und JSON. Begrenzt nicht Kandidaten, FILEPROPERTY-/Volumeabfragen, Quellenarbeit oder Laufzeit.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Bindung an varchar(16), Trim von U+0020-Leerzeichen und UPPER gelten RAW, CONSOLE, TABLE und NONE. NULL, leer und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. RAW liefert Status und die technischen Fachresultsets. CONSOLE liefert nur die lesbare capacity-Fachmenge über den Console-Helfer, ohne separates Statusresultset; TABLE schreibt nur diese benannte Fachmenge in das Ziel. NONE unterdrückt normale Resultsets. TABLE-Zielvorprüfung oder Ablehnung eines nicht leeren Mappings außerhalb TABLE laufen vor @Hilfe=1 und können werfen. Hilfe kehrt danach vor der Analyse und JSON-Erzeugung zurück; angefordertes JSON im normalen Pfad ist unabhängig vom Ausgabemodus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Für TABLE ist ein JSON-Objekt mit genau dem Schlüssel capacity erforderlich; der Wert muss ein String mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein, etwa N''{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}''. Das Ziel muss leer sein und genau eine beliebig typisierte Seed-Spalte besitzen; beim TABLE-Schreiben richtet der Ausgabehelfer daraus die Zielspalten ein. NULL oder nach Trim von U+0020 leere Eingabe ist in TABLE ungültig. Außerhalb TABLE sind nur NULL oder nach diesem Trim leere Werte zulässig; andere Werte werfen 51011. Diese Prüfung läuft auch bei TABLE zusammen mit @Hilfe=1 vor der Hilfe-Rückkehr. Ausgelassen = NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter 0 = kein JSON, 1 = JSON erzeugen; NULL wirkt wegen IF wie aus; ausgelassen = 0. Zahlen folgen bit-Konvertierung (0 bleibt 0, konvertierbarer Nichtnullwert wird 1). JSON ist unabhängig vom ResultSetArt-Modus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionales nvarchar(max)-OUTPUT. Beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält es meta, capacity und warnings, sonst bleibt es NULL. Als Variable mit OUTPUT binden; Eingabewert bleibt nicht erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit-Schalter für Severity-10-RAISERROR mit NOWAIT bei globalem Status ungleich AVAILABLE: 1 aktiviert, 0 unterdrückt; NULL wirkt wie aus; ausgelassen = 1. Kandidatenwarnungen sind davon getrennte Resultate.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit; Default: 0. Bit-Schalter: 1 druckt Hilfe und kehrt vor Analyse-Resultaten zurück, 0 führt Analyse aus; NULL wirkt wie aus; ausgelassen = 0. OUTPUT-Ziele, die erst am normalen Ende gesetzt werden, bleiben im HELP-Pfad unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionales varchar(40)-OUTPUT. Im normalen Pfad wird am Ende gesetzt; vor dieser Zuweisung initialisiert die Procedure das Outputziel nicht, und HELP kehrt vorher zurück, sodass ein gebundener vorhandener Variablenwert erhalten bleibt. Globale Werte: AVAILABLE = kein gesetzter Finding- oder Teilstatus; AVAILABLE_WITH_FINDING = mindestens ein Finding ohne Teilstatus; AVAILABLE_LIMITED = Teilquelle oder Kandidatenwarnung begrenzt die Vollständigkeit; INVALID_PARAMETER = ungültige Eingabe; DENIED_GROUP = Analyseklasse laut aktueller Policy nicht freigegeben; DENIED_PERMISSION = erforderliche Abfrage verweigert; ERROR_HANDLED = sonstiger behandelter Analysefehler; INTERNAL_ERROR = interner Kandidatenvorbereitungsfehler; UNAVAILABLE_FEATURE = Regexmodus auf nicht unterstützter Engine-/Installationsdatenbank-Kompatibilität. Beide fest verdrahteten Klassen haben RequiresGroupGate=0, daher verlangen sie keine High-Impact-Bes'
            + N'tätigung. Per-Datenbank-Warnungen wie SYSTEM_DATABASE_EXCLUDED (Systemdatenbank aus Scope ausgelassen) und DATABASE_UNAVAILABLE (Kandidat nicht verfügbar) sind Warnungszeilen, keine globalen Codes; Kapazitätsabfragefehler werden ebenfalls dort je Datenbank erfasst. Teilstatus wird zusätzlich über @IsPartialOut signalisiert. Als Variable mit OUTPUT-Bindung übergeben; ausgelassen wird kein Wert zurückgegeben. Optionaler Empfang mit @StatusCodeOut=@Empfaenger OUTPUT; die Variable muss varchar(40) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit OUTPUT; Default: NULL. Optionales bit-OUTPUT zur Teilvollständigkeit (0 vollständig, 1 Teilquelle/Berechtigungs-/Warnungseinschränkung). HELP erreicht die normale Zuweisung nicht und lässt den bisherigen Variablenwert unverändert. Als Variable mit OUTPUT binden. Optionaler Empfang mit @IsPartialOut=@Empfaenger OUTPUT; die Variable muss bit sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT; Default: NULL. Optionales int-OUTPUT für die gespeicherte SQL-Fehlernummer; NULL, wenn keine gespeichert wurde. HELP weist nicht zu. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT; die Variable muss int sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionales nvarchar(2048)-OUTPUT für gespeicherten Fehler-/Teilhinweis; ohne Hinweis NULL. HELP weist nicht zu. Kandidatenwarnungen bleiben separat. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT; die Variable muss nvarchar(2048) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'| Resultmenge | RAW | TABLE | Felder laut Inventar |'
            + NCHAR(10)
            + N'| --- | --- | --- | --- |'
            + NCHAR(10)
            + N'| capacity | 1 | 1 | [DatabaseId] int NULL , [DatabaseName] sysname NULL , [FileId] int NULL , [LogicalFileName] sysname NULL , [FileTypeDesc] nvarchar(60) NULL , [PhysicalName] nvarchar(260) NULL , [FileSizeMb] decimal(19,2) NULL , [UsedInFileMb] decimal(19,2) NULL , [FreeInFileMb] decimal(19,2) NULL , [FreeInFilePercent] decimal(9,2) NULL , [GrowthDescription] nvarchar(80) NULL , [NextGrowthMb] decimal(19,2) NULL , [MaxSizeMb] decimal(19,2) NULL , [VolumeMountPoint] nvarchar(512) NULL , [LogicalVolumeName] nvarchar(512) NULL , [VolumeTotalMb] decimal(19,2) NULL , [VolumeAvailableMb] decimal(19,2) NULL , [VolumeFreePercent] decimal(9,2) NULL , [FindingCode] varchar(80) NULL , [EvidenceLimit] nvarchar(500) NOT NULL |'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Eine Zeit-bis-voll-Prognose wird ohne persistente Historie nicht erzeugt. Alle Bewertungen sind Momentaufnahmen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'rein lesend; keine Datei- oder Datenbankänderung.'
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'### Quellgebundene Detailbeschreibung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'Objekt       : monitor.USP_DatabaseCapacityAnalysis'
            + NCHAR(10)
            + N'Version      : 1.0.1'
            + NCHAR(10)
            + N'Stand        : 2026-07-18'
            + NCHAR(10)
            + N'Zweck        : Die Procedure bewertet Datei- und Volumefreiraum sowie das nächste Autogrowth je Datei'
            + NCHAR(10)
            + N'               der ausgewählten Datenbanken als lesenden Snapshot.'
            + NCHAR(10)
            + N'Datenquellen : sys.database_files, FILEPROPERTY, sys.dm_os_volume_stats.'
            + NCHAR(10)
            + N'Grenzen      : Eine Zeit-bis-voll-Prognose wird ohne persistente Historie nicht'
            + NCHAR(10)
            + N'               erzeugt. Alle Bewertungen sind Momentaufnahmen.'
            + NCHAR(10)
            + N'Nebenwirkung : rein lesend; keine Datei- oder Datenbankänderung.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_DatabaseCapacityAnalysis'
            + NCHAR(10)
            + N'Die Procedure bewertet je Datenbank und Datei einen lesenden Snapshot von Datei- und Volume-Freiraum sowie Wachstumseinstellungen. Ohne Historie entsteht keine Zeit-bis-voll-Prognose.'
            + NCHAR(10)
            + N'DECLARE @CapacityJson nvarchar(max); EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@CapacityJson OUTPUT; SELECT @CapacityJson AS [Json];'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#DatabaseCapacityAnalysis_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseCapacityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"capacity":"#DatabaseCapacityAnalysis_HelpExample"}''; END TRY BEGIN CATCH DROP TABLE [#DatabaseCapacityAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE [#DatabaseCapacityAnalysis_HelpExample];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_DatabaseCapacityAnalysis
        RETURN;
    END

    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'capacity',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
    IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @OutputMode = 'NONE';
    DECLARE @Limit bigint =
        CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen = 0
             THEN CONVERT(bigint, 9223372036854775807)
             ELSE CONVERT(bigint, @MaxZeilen) END;

    ;

    DECLARE @Now datetime2(3) = SYSUTCDATETIME();
    DECLARE @StatusCode varchar(40) = 'AVAILABLE';
    DECLARE @IsPartial bit = 0;
    DECLARE @ErrorNumber int = NULL;
    DECLARE @ErrorMessage nvarchar(2048) = NULL;
    DECLARE @MonitorPrintMessage nvarchar(2048) = NULL;
    DECLARE @CrossDatabaseRequested bit = 0;
    DECLARE @RequiredServerPermission sysname =
        CASE WHEN TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) >= 16
             THEN N'VIEW SERVER PERFORMANCE STATE' ELSE N'VIEW SERVER STATE' END;
    DECLARE @HasRequiredServerPermission bit =
        CASE WHEN IS_SRVROLEMEMBER(N'sysadmin') = 1 THEN 1
             ELSE COALESCE(HAS_PERMS_BY_NAME(NULL, N'SERVER', @RequiredServerPermission), 0) END;

    CREATE TABLE [#DatabaseCapacityAnalysis_DatabaseCandidates]
    (
          [DatabaseId] int NOT NULL PRIMARY KEY
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [UserAccessDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsReadOnly] bit NULL
        , [CompatibilityLevel] tinyint NULL
        , [CollationName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [RecoveryModelDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsSystemDatabase] bit NULL
        , [RequestedOrdinal] int NULL
    );

    CREATE TABLE [#DatabaseCapacityAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#DatabaseCapacityAnalysis_Capacity]
    (
          [DatabaseId] int NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileId] int NULL
        , [LogicalFileName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileTypeDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PhysicalName] nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileSizeMb] decimal(19,2) NULL
        , [UsedInFileMb] decimal(19,2) NULL
        , [FreeInFileMb] decimal(19,2) NULL
        , [FreeInFilePercent] decimal(9,2) NULL
        , [GrowthDescription] nvarchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [NextGrowthMb] decimal(19,2) NULL
        , [MaxSizeMb] decimal(19,2) NULL
        , [VolumeMountPoint] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LogicalVolumeName] nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [VolumeTotalMb] decimal(19,2) NULL
        , [VolumeAvailableMb] decimal(19,2) NULL
        , [VolumeFreePercent] decimal(9,2) NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [EvidenceLimit] nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    IF @MaxZeilen < 0
       OR @MinVolumeFreePercent < 0
       OR @MinVolumeFreePercent > 100
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER',
               @IsPartial = 1,
               @ErrorMessage = N'Ungültige Datenbank-, Prozent-, Zeilen- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND @HasRequiredServerPermission = 0
    BEGIN
        SELECT @IsPartial = 1,
               @ErrorMessage = CONCAT(N'Für vollständige serverweite Volumenevidenz fehlt ',
                                      @RequiredServerPermission, N'.');
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass = 'SERVER_HEALTH_CURRENT'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT,@CandidateTable=N'#DatabaseCapacityAnalysis_DatabaseCandidates',@WarningTable=N'#DatabaseCapacityAnalysis_DatabaseCandidateWarnings';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        DECLARE @DatabaseId int;
        DECLARE @DatabaseName sysname;
        DECLARE @Sql nvarchar(max);

        DECLARE [DatabaseCursor] CURSOR LOCAL FAST_FORWARD FOR
            SELECT [DatabaseId], [DatabaseName]
            FROM [#DatabaseCapacityAnalysis_DatabaseCandidates]
            ORDER BY COALESCE([RequestedOrdinal], [DatabaseId]), [DatabaseId];

        OPEN [DatabaseCursor];
        FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId, @DatabaseName;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            BEGIN TRY
                SET @Sql = N'USE ' + QUOTENAME(@DatabaseName) + N';
INSERT [#DatabaseCapacityAnalysis_Capacity]
(
      [DatabaseId], [DatabaseName], [FileId], [LogicalFileName]
    , [FileTypeDesc], [PhysicalName], [FileSizeMb], [UsedInFileMb]
    , [FreeInFileMb], [FreeInFilePercent], [GrowthDescription]
    , [NextGrowthMb], [MaxSizeMb], [VolumeMountPoint], [LogicalVolumeName]
    , [VolumeTotalMb], [VolumeAvailableMb], [VolumeFreePercent]
    , [FindingCode], [EvidenceLimit]
)
SELECT
      DB_ID(), (SELECT [name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id] = DB_ID()), [f].[file_id], [f].[name], [f].[type_desc], [f].[physical_name]
    , CONVERT(decimal(19,2), [f].[size] * 8.0 / 1024.0)
    , CONVERT(decimal(19,2), COALESCE(FILEPROPERTY([f].[name], ''SpaceUsed''), 0) * 8.0 / 1024.0)
    , CONVERT(decimal(19,2), ([f].[size] - COALESCE(FILEPROPERTY([f].[name], ''SpaceUsed''), 0)) * 8.0 / 1024.0)
    , CONVERT(decimal(9,2), 100.0 * ([f].[size] - COALESCE(FILEPROPERTY([f].[name], ''SpaceUsed''), 0)) / NULLIF([f].[size], 0))
    , CASE WHEN [f].[growth] = 0 THEN N''DISABLED''
           WHEN [f].[is_percent_growth] = 1 THEN CONCAT([f].[growth], N'' percent'')
           ELSE CONCAT(CONVERT(decimal(19,2), [f].[growth] * 8.0 / 1024.0), N'' MB'') END
    , CASE WHEN [f].[growth] = 0 THEN NULL
           WHEN [f].[is_percent_growth] = 1
               THEN CONVERT(decimal(19,2), CEILING([f].[size] * [f].[growth] / 100.0) * 8.0 / 1024.0)
           ELSE CONVERT(decimal(19,2), [f].[growth] * 8.0 / 1024.0) END
    , CASE WHEN [f].[max_size] = -1 THEN NULL
           ELSE CONVERT(decimal(19,2), [f].[max_size] * 8.0 / 1024.0) END
    , [v].[volume_mount_point], [v].[logical_volume_name]
    , CONVERT(decimal(19,2), [v].[total_bytes] / 1048576.0)
    , CONVERT(decimal(19,2), [v].[available_bytes] / 1048576.0)
    , CONVERT(decimal(9,2), 100.0 * [v].[available_bytes] / NULLIF([v].[total_bytes], 0))
    , CASE
          WHEN [f].[growth] = 0 THEN ''GROWTH_DISABLED''
          WHEN [f].[max_size] <> -1 AND [f].[size] >= [f].[max_size] THEN ''FILE_MAX_SIZE_REACHED''
          WHEN [v].[available_bytes] IS NOT NULL
           AND (CASE WHEN [f].[is_percent_growth] = 1
                     THEN CEILING([f].[size] * [f].[growth] / 100.0) * 8192.0
                     ELSE [f].[growth] * 8192.0 END) > [v].[available_bytes]
              THEN ''NEXT_GROWTH_EXCEEDS_VOLUME_FREE''
          WHEN [v].[total_bytes] > 0
           AND 100.0 * [v].[available_bytes] / [v].[total_bytes] < @pMinVolumeFreePercent
              THEN ''LOW_VOLUME_FREE_PERCENT''
          WHEN [f].[is_percent_growth] = 1 THEN ''PERCENT_GROWTH_REVIEW''
          ELSE ''NO_CAPACITY_INDICATOR''
      END
    , N''Momentaufnahme; ohne persistente Messpunkte wird keine Zeit-bis-voll-Prognose erzeugt.''
FROM [sys].[database_files] AS [f] WITH (NOLOCK)
OUTER APPLY [sys].[dm_os_volume_stats](DB_ID(), [f].[file_id]) AS [v];';

                EXEC [sys].[sp_executesql]
                      @Sql
                    , N'@pMinVolumeFreePercent decimal(9,2)'
                    , @pMinVolumeFreePercent = @MinVolumeFreePercent;
            END TRY
            BEGIN CATCH
                SET @IsPartial = 1;
                INSERT [#DatabaseCapacityAnalysis_DatabaseCandidateWarnings]
                VALUES
                (
                      @DatabaseName
                    , CASE WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371)
                           THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END
                    , ERROR_MESSAGE()
                );
            END CATCH;

            FETCH NEXT FROM [DatabaseCursor] INTO @DatabaseId, @DatabaseName;
        END;
        CLOSE [DatabaseCursor];
        DEALLOCATE [DatabaseCursor];
    END;

    IF @StatusCode = 'AVAILABLE'
       AND (@IsPartial = 1 OR EXISTS (SELECT 1 FROM [#DatabaseCapacityAnalysis_DatabaseCandidateWarnings]))
        SET @StatusCode = 'AVAILABLE_LIMITED';
    ELSE IF @StatusCode = 'AVAILABLE'
        AND EXISTS (SELECT 1 FROM [#DatabaseCapacityAnalysis_Capacity] WHERE [FindingCode] <> 'NO_CAPACITY_INDICATOR')
        SET @StatusCode = 'AVAILABLE_WITH_FINDING';

    IF @NurProblematisch = 1 OR @NurProblematisch IS NULL
        DELETE FROM [#DatabaseCapacityAnalysis_Capacity]
        WHERE [FindingCode] IS NULL OR [FindingCode] = 'NO_CAPACITY_INDICATOR';

    ;WITH [RankedCapacity] AS
    (
        SELECT *, ROW_NUMBER() OVER
        (
            ORDER BY CASE WHEN [FindingCode] = 'NO_CAPACITY_INDICATOR' THEN 1 ELSE 0 END,
                     [VolumeFreePercent], [DatabaseName], [FileId], [DatabaseId]
        ) AS [OutputOrdinal]
        FROM [#DatabaseCapacityAnalysis_Capacity]
    )
    DELETE FROM [RankedCapacity] WHERE [OutputOrdinal] > @Limit;

    SELECT @StatusCodeOut = @StatusCode,
           @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber,
           @ErrorMessageOut = @ErrorMessage;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @MonitorPrintMessage = COALESCE(@ErrorMessage, CONVERT(nvarchar(2048), @StatusCode));
        RAISERROR(N'USP_DatabaseCapacityAnalysis: %s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT CAST('1.0' AS varchar(16)) AS [ContractVersion], @Now AS [CollectionTimeUtc],
               N'monitor.USP_DatabaseCapacityAnalysis' AS [ModuleName],
               @StatusCode AS [StatusCode], @IsPartial AS [IsPartial],
               @ErrorNumber AS [ErrorNumber], @ErrorMessage AS [ErrorMessage];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT TOP (@Limit) *
            FROM [#DatabaseCapacityAnalysis_Capacity]
            WHERE @NurProblematisch = 0 OR [FindingCode] <> 'NO_CAPACITY_INDICATOR'
            ORDER BY CASE WHEN [FindingCode] = 'NO_CAPACITY_INDICATOR' THEN 1 ELSE 0 END,
                     [VolumeFreePercent], [DatabaseName], [FileId];
            SELECT * FROM [#DatabaseCapacityAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName];
        END
        ELSE
        BEGIN
            SELECT TOP (@Limit)
                  N'Kapazität' AS [Ergebnis]
                , [DatabaseName] AS [Datenbank]
                , [LogicalFileName] AS [Datei]
                , [FileTypeDesc] AS [Typ]
                , [FindingCode] AS [Bewertung]
                , [FileSizeMb] AS [Dateigröße MB]
                , [FreeInFileMb] AS [Frei in Datei MB]
                , [GrowthDescription] AS [Wachstum]
                , [NextGrowthMb] AS [Nächstes Wachstum MB]
                , [VolumeAvailableMb] AS [Frei auf Volume MB]
                , [VolumeFreePercent] AS [Frei auf Volume Prozent]
                , [VolumeMountPoint] AS [Volume]
                , [EvidenceLimit] AS [Aussagegrenze]
            FROM [#DatabaseCapacityAnalysis_Capacity]
            WHERE @NurProblematisch = 0 OR [FindingCode] <> 'NO_CAPACITY_INDICATOR'
            ORDER BY CASE WHEN [FindingCode] = 'NO_CAPACITY_INDICATOR' THEN 1 ELSE 0 END,
                     [VolumeFreePercent], [DatabaseName], [FileId];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT N'DatabaseCapacityAnalysis' AS [resultName], 1 AS [schemaVersion],
                   @Now AS [generatedAtUtc], @StatusCode AS [statusCode],
                   @IsPartial AS [isPartial], @ErrorNumber AS [errorNumber],
                   @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @CapacityJson nvarchar(max) =
        (
            SELECT TOP (@Limit) *
            FROM [#DatabaseCapacityAnalysis_Capacity]
            WHERE @NurProblematisch = 0 OR [FindingCode] <> 'NO_CAPACITY_INDICATOR'
            ORDER BY CASE WHEN [FindingCode] = 'NO_CAPACITY_INDICATOR' THEN 1 ELSE 0 END,
                     [VolumeFreePercent], [DatabaseName], [FileId]
            FOR JSON PATH, INCLUDE_NULL_VALUES
        );
        DECLARE @WarningsJson nvarchar(max) =
            (SELECT * FROM [#DatabaseCapacityAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName] FOR JSON PATH, INCLUDE_NULL_VALUES);

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"capacity":', COALESCE(@CapacityJson, N'[]')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#DatabaseCapacityAnalysis_Capacity'
            , @ResultLabel=N'DatabaseCapacityAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#DatabaseCapacityAnalysis_Capacity'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
