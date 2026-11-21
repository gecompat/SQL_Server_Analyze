USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_DatabaseIntegrityAnalysis
Version      : 1.0.2
Stand        : 2026-07-18
Zweck        : Die Procedure liefert korrelierte, rein lesende Integritätsindikatoren je
               ausgewählter Datenbank, ohne DBCC CHECKDB auszuführen.
Datenquellen : master.sys.databases,
               msdb.dbo.suspect_pages, msdb.dbo.backupset,
               sys.dm_hadr_auto_page_repair und optional sys.dm_db_page_info.
Grenzen      : Leere Indikatoren beweisen keine Integrität. Die Procedure führt
               weder DBCC CHECKDB noch Restore, Reparatur oder Konfiguration aus.
Kosten       : Metadaten LOW; gezielte Seitenauflösung MEDIUM und opt-in.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_DatabaseIntegrityAnalysis 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_DatabaseIntegrityAnalysis"
-- schema_name: "monitor"
-- object_name: "USP_DatabaseIntegrityAnalysis"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Die Procedure liefert korrelierte, rein lesende Integritätsindikatoren je ausgewählter Datenbank, ohne DBCC CHECKDB auszuführen."
-- source_path: "Code/08_ServerHealth/110_USP_DatabaseIntegrityAnalysis.sql"
-- ---
-- 
-- # monitor.USP_DatabaseIntegrityAnalysis
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure liefert korrelierte, rein lesende Integritätsindikatoren je ausgewählter Datenbank, ohne DBCC CHECKDB auszuführen.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der Aufruf braucht EXECUTE auf [monitor].[USP_DatabaseIntegrityAnalysis] im vorgesehenen Datenbankkontext. Die Procedure liest `msdb`-Historie, Auto-Page-Repair und optional Page-Informationen in zugänglichen Datenbanken. Historie und Metadatensicht ersetzen keine neue DBCC-Integritätsprüfung.
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
-- | @CheckdbWarnHours | int | nein | 168 |
-- | @BackupHistoryDays | int | nein | 35 |
-- | @MitPageDetails | bit | nein | 0 |
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
-- **@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Bit-Bestätigung der fest verdrahteten Analyseklasse; 0 = nicht bestätigt, 1 = bestätigt. NULL ungültig; ausgelassen = 0. Numerische Werte werden als bit konvertiert: 0 bleibt 0, konvertierbarer Nichtnullwert wird 1. Die Bestätigung selbst erteilt weder Gruppenmitgliedschaft noch Berechtigung; der Helper prüft zusätzlich die aktivierte Klassen-/Gruppenpolicy.
-- 
-- **@CheckdbWarnHours:** @CheckdbWarnHours int; Default: 168. Ganzzahl Stunden, zulässig ab 1; ausgelassen = 168. NULL wird von < 1 nicht zurückgewiesen. Im aktuellen Pfad wird der Wert nur validiert: LastGoodCheckDbTime und CheckdbAgeHours bleiben NULL, ein CHECKDB-Alter wird nicht damit verglichen.
-- 
-- **@BackupHistoryDays:** @BackupHistoryDays int; Default: 35. Ganzzahl Tage, 1 bis 3650; ausgelassen = 35. NULL wird nicht ausdrücklich zurückgewiesen. Begrenzt nur Backupmetadaten mit backup_finish_date >= DATEADD(DAY,-@BackupHistoryDays,GETDATE()); Basis ist lokale Serverzeit via GETDATE(), nicht UTC. DATEADD setzt einen Kalenderzeitpunkt, keine garantierte Anzahl verstrichener 24-Stunden-Intervalle. Bei NULL wird der DATEADD-Stichtag NULL; der Vergleich backup_finish_date >= NULL trifft auf keine Backupzeile zu. Dies belegt keinen Erfolg der Backups.
-- 
-- **@MitPageDetails:** @MitPageDetails bit; Default: 0. 0 oder NULL überspringt Seitenauflösung; 1 fordert sie nur bei bisherigem Status AVAILABLE an. sys.dm_db_page_info(...,LIMITED) löst höchstens @MaxZeilen suspect_pages-Zeilen der ausgewählten Kandidaten auf; NULL/0 bei @MaxZeilen bedeutet unbegrenzt. Die begrenzte Kandidatenauswahl ordnet LastUpdateDate DESC, DatabaseId, FileId, PageId. RAW ordnet die Details danach nach LastUpdateDate DESC, DatabaseName, FileId, PageId; JSON ordnet nur nach LastUpdateDate DESC. Ein Auflösungsfehler setzt IsPartial=1. Details erscheinen ausschließlich als RAW-Seitendetailresultset beziehungsweise in JSON.pageDetails bei @JsonErzeugen=1; CONSOLE und TABLE enthalten nur integrity-Zeilen, NONE gibt keine normalen Resultsets aus. Es erfolgt kein DBCC CHECKDB. Numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1.
-- 
-- **@MaxZeilen:** @MaxZeilen int; Default: 1000. Ganzzahlig; negative Werte ungültig, NULL/0 wird auf den größten bigint-Wert abgebildet (praktisch unbegrenzt), ausgelassen = 1000. Integritätszeilen nach Quellenaggregation: Findings vor NO_INDICATOR_FOUND, dann DatabaseName und DatabaseId. PageDetails hat zusätzlich ein eigenes TOP-Limit in gleicher Höhe. Keine Vorabbegrenzung der Kandidaten/Quellen.
-- 
-- **@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. Nach Bindung an varchar(16), Trim von U+0020-Leerzeichen und UPPER gelten RAW, CONSOLE, TABLE und NONE. NULL, leer und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. RAW liefert Status und die technischen Fachresultsets. CONSOLE liefert nur die lesbare integrity-Fachmenge über den Console-Helfer, ohne separates Statusresultset; TABLE schreibt nur diese benannte Fachmenge in das Ziel. NONE unterdrückt normale Resultsets. TABLE-Zielvorprüfung oder Ablehnung eines nicht leeren Mappings außerhalb TABLE laufen vor @Hilfe=1 und können werfen. Hilfe kehrt danach vor der Analyse und JSON-Erzeugung zurück; angefordertes JSON im normalen Pfad ist unabhängig vom Ausgabemodus.
-- 
-- **@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Für TABLE ist ein JSON-Objekt mit genau dem Schlüssel integrity erforderlich; der Wert muss ein String mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein, etwa N'{"integrity":"#DatabaseIntegrityAnalysis_HelpExample"}'. Das Ziel muss leer sein und genau eine beliebig typisierte Seed-Spalte besitzen; beim TABLE-Schreiben richtet der Ausgabehelfer daraus die Zielspalten ein. NULL oder nach Trim von U+0020 leere Eingabe ist in TABLE ungültig. Außerhalb TABLE sind nur NULL oder nach diesem Trim leere Werte zulässig; andere Werte werfen 51011. Diese Prüfung läuft auch bei TABLE zusammen mit @Hilfe=1 vor der Hilfe-Rückkehr. Ausgelassen = NULL.
-- 
-- **@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter 0 = kein JSON, 1 = JSON erzeugen; NULL wirkt wegen IF wie aus; ausgelassen = 0. Zahlen folgen bit-Konvertierung (0 bleibt 0, konvertierbarer Nichtnullwert wird 1). JSON ist unabhängig vom ResultSetArt-Modus.
-- 
-- **@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionales nvarchar(max)-OUTPUT. Beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält es meta, integrity, pageDetails und warnings, sonst bleibt es NULL. Als Variable mit OUTPUT binden; Eingabewert bleibt nicht erhalten.
-- 
-- **@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit-Schalter für Severity-10-RAISERROR mit NOWAIT bei globalem Status ungleich AVAILABLE: 1 aktiviert, 0 unterdrückt; NULL wirkt wie aus; ausgelassen = 1. Kandidatenwarnungen sind davon getrennte Resultate.
-- 
-- **@Hilfe:** @Hilfe bit; Default: 0. Bit-Schalter: 1 druckt Hilfe und kehrt vor Analyse-Resultaten zurück, 0 führt Analyse aus; NULL wirkt wie aus; ausgelassen = 0. OUTPUT-Ziele, die erst am normalen Ende gesetzt werden, bleiben im HELP-Pfad unverändert.
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionales varchar(40)-OUTPUT. Im normalen Pfad wird am Ende gesetzt; vor dieser Zuweisung initialisiert die Procedure das Outputziel nicht, und HELP kehrt vorher zurück, sodass ein gebundener vorhandener Variablenwert erhalten bleibt. Globale Werte: AVAILABLE = kein gesetzter Finding- oder Teilstatus; AVAILABLE_WITH_FINDING = bei vorherigem AVAILABLE ohne Teilstatus mindestens eine integrity-Zeile mit FindingCode ungleich NO_INDICATOR_FOUND; dazu zählt CHECKDB_EVIDENCE_UNAVAILABLE. Der aktuelle INSERT-CASE erzeugt NO_INDICATOR_FOUND nicht, daher reicht eine normale nichtleere Integrity-Menge für diesen Status; er bestätigt keinen Schaden; AVAILABLE_LIMITED = Teilquelle oder Kandidatenwarnung begrenzt die Vollständigkeit; INVALID_PARAMETER = ungültige Eingabe; DENIED_GROUP = Analyseklasse laut aktueller Policy nicht freigegeben; DENIED_PERMISSION = erforderliche Abfrage verweigert; ERROR_HANDLED = sonstiger behandelter Analysefehler; INTERNAL_ERROR = interner Kandidatenvorbereitungsfehler; UNAVAILABLE_FEATURE = Regexmodus auf nicht unterstützter Engine-/Installationsdatenbank-Kompatibilität. Beide fest verdrahteten Klassen haben RequiresGroupGate=0, daher verlangen sie keine High-Impact-Bestätigung. Per-Datenbank-Warnungen wie SYSTEM_DATABASE_EXCLUDED (Systemdatenbank aus Scope ausgelassen) und DATABASE_UNAVAILABLE (Kandidat nicht verfügbar) sind Warnungszeilen, keine globalen Codes. Teilstatus wird zusätzlich über @IsPartialOut signalisiert. Als Variable mit OUTPUT-Bindung übergeben; ausgelassen wird kein Wert zurückgegeben. Optionaler Empfang mit @StatusCodeOut=@Empfaenger OUTPUT; die Variable muss varchar(40) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.
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
-- | integrity | 1 | 1 | [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [StateDesc] nvarchar(60) NULL , [PageVerifyOptionDesc] nvarchar(60) NULL , [LastGoodCheckDbTime] datetime2(3) NULL , [CheckdbAgeHours] bigint NULL , [SuspectPageCount] bigint NOT NULL , [LatestSuspectPageUtc] datetime NULL , [DamagedBackupCount] bigint NOT NULL , [BackupWithoutChecksumCount] bigint NOT NULL , [HadrPageRepairCount] bigint NOT NULL , [HadrPageRepairPendingCount] bigint NOT NULL , [FindingCode] varchar(80) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |
-- 
-- Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='RAW';
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Leere Indikatoren beweisen keine Integrität. Die Procedure führt weder DBCC CHECKDB noch Restore, Reparatur oder Konfiguration aus.
-- 
-- Metadaten LOW; gezielte Seitenauflösung MEDIUM und opt-in.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_DatabaseIntegrityAnalysis
-- Version      : 1.0.2
-- Stand        : 2026-07-18
-- Zweck        : Die Procedure liefert korrelierte, rein lesende Integritätsindikatoren je
--                ausgewählter Datenbank, ohne DBCC CHECKDB auszuführen.
-- Datenquellen : master.sys.databases,
--                msdb.dbo.suspect_pages, msdb.dbo.backupset,
--                sys.dm_hadr_auto_page_repair und optional sys.dm_db_page_info.
-- Grenzen      : Leere Indikatoren beweisen keine Integrität. Die Procedure führt
--                weder DBCC CHECKDB noch Restore, Reparatur oder Konfiguration aus.
-- Kosten       : Metadaten LOW; gezielte Seitenauflösung MEDIUM und opt-in.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_DatabaseIntegrityAnalysis
-- Die Procedure sammelt rein lesende, korrelierte Integritätsindikatoren je Datenbank. Sie führt kein DBCC CHECKDB, Restore oder Repair aus; fehlende Indikatoren belegen keine Integrität.
-- DECLARE @IntegrityJson nvarchar(max); EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@IntegrityJson OUTPUT; SELECT @IntegrityJson AS [Json];
-- CREATE TABLE [#DatabaseIntegrityAnalysis_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N'[ExampleDatabase]', @ResultSetArt='TABLE', @ResultTablesJson=N'{"integrity":"#DatabaseIntegrityAnalysis_HelpExample"}'; END TRY BEGIN CATCH DROP TABLE [#DatabaseIntegrityAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE [#DatabaseIntegrityAnalysis_HelpExample];
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_DatabaseIntegrityAnalysis
CREATE OR ALTER PROCEDURE [monitor].[USP_DatabaseIntegrityAnalysis]
      @DatabaseNames                nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen bit            = 0
    , @DatabaseNamePattern          nvarchar(4000) = NULL
    , @HighImpactConfirmed              bit            = 0
    , @CheckdbWarnHours             int            = 168
    , @BackupHistoryDays            int            = 35
    , @MitPageDetails               bit            = 0
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
        PRINT N'monitor.USP_DatabaseIntegrityAnalysis';
        PRINT N'Die Procedure sammelt rein lesende, korrelierte Integritätsindikatoren je Datenbank. Sie führt kein DBCC CHECKDB, Restore oder Repair aus; fehlende Indikatoren belegen keine Integrität.';
        PRINT N'@DatabaseNames nvarchar(max); Default: NULL. Eingabe ist eine bracket-aware Pipe-Liste einteiliger Datenbanknamen: | trennt außerhalb von [...], ]] maskiert ] innen. Äußere Leerzeichen je Element werden entfernt; Rohsegment höchstens 4000 UTF-16-Codeeinheiten, Name höchstens 128 Zeichen. Leere/fehlerhaft geklammerte Elemente, mehrteilige Namen und case-sensitive Duplikate desselben Filtertyps sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Namensbegrenzung; ausgelassen entspricht NULL. Nicht mit einem nichtleeren Pattern kombinierbar.';
        PRINT N'@SystemdatenbankenEinbeziehen bit; Default: 0. Bit-Schalter: 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL ist ungültig; ausgelassen = 0. Nach bit-Konvertierung bleibt numerisch 0 aus, ein konvertierbarer Nichtnullwert wird 1. Verändert Kandidatenauswahl und systemdatenbankbezogene Warnungen.';
        PRINT N'@DatabaseNamePattern nvarchar(4000); Default: NULL. Ein Pattern (nvarchar(4000)); NULL/ausgelassen bedeutet kein Pattern; leer oder nach LTRIM/RTRIM von U+0020-Leerzeichen leer ist ungültig. Andere Whitespacezeichen wie Tabulatoren werden nicht allgemein normalisiert. Äußere U+0020-Leerzeichen werden getrimmt. Unterstützte Modi: LIKE (ohne Präfix oder like:), regex: (case-sensitive, Flag c), regexi: (case-insensitive, Flag i); Präfixerkennung ignoriert Groß-/Kleinschreibung. Der Inhalt nach Präfixentfernung wird nicht erneut getrimmt. LIKE nutzt %, _ und [...] unter SQL_Latin1_General_CP1_CS_AS. Regexsyntax/Treffer werden durch Präfixprüfung nicht validiert. Regexausführung erfordert SQL Server 2025 sowie Compatibility Level mindestens 170 der Installationsdatenbank; sonst wird der Kandidatenpfad mit UNAVAILABLE_FEATURE beendet. Ein nicht-NULL Pattern und eine wirksame Namensliste schließen einander aus. Das Pattern begrenzt Kandidaten, setzt aber keine Mengenobergrenze.';
        PRINT N'@HighImpactConfirmed bit; Default: 0. Bit-Bestätigung der fest verdrahteten Analyseklasse; 0 = nicht bestätigt, 1 = bestätigt. NULL ungültig; ausgelassen = 0. Numerische Werte werden als bit konvertiert: 0 bleibt 0, konvertierbarer Nichtnullwert wird 1. Die Bestätigung selbst erteilt weder Gruppenmitgliedschaft noch Berechtigung; der Helper prüft zusätzlich die aktivierte Klassen-/Gruppenpolicy.';
        PRINT N'@CheckdbWarnHours int; Default: 168. Ganzzahl Stunden, zulässig ab 1; ausgelassen = 168. NULL wird von < 1 nicht zurückgewiesen. Im aktuellen Pfad wird der Wert nur validiert: LastGoodCheckDbTime und CheckdbAgeHours bleiben NULL, ein CHECKDB-Alter wird nicht damit verglichen.';
        PRINT N'@BackupHistoryDays int; Default: 35. Ganzzahl Tage, 1 bis 3650; ausgelassen = 35. NULL wird nicht ausdrücklich zurückgewiesen. Begrenzt nur Backupmetadaten mit backup_finish_date >= DATEADD(DAY,-@BackupHistoryDays,GETDATE()); Basis ist lokale Serverzeit via GETDATE(), nicht UTC. DATEADD setzt einen Kalenderzeitpunkt, keine garantierte Anzahl verstrichener 24-Stunden-Intervalle. Bei NULL wird der DATEADD-Stichtag NULL; der Vergleich backup_finish_date >= NULL trifft auf keine Backupzeile zu. Dies belegt keinen Erfolg der Backups.';
        PRINT N'@MitPageDetails bit; Default: 0. 0 oder NULL überspringt Seitenauflösung; 1 fordert sie nur bei bisherigem Status AVAILABLE an. sys.dm_db_page_info(...,LIMITED) löst höchstens @MaxZeilen suspect_pages-Zeilen der ausgewählten Kandidaten auf; NULL/0 bei @MaxZeilen bedeutet unbegrenzt. Die begrenzte Kandidatenauswahl ordnet LastUpdateDate DESC, DatabaseId, FileId, PageId. RAW ordnet die Details danach nach LastUpdateDate DESC, DatabaseName, FileId, PageId; JSON ordnet nur nach LastUpdateDate DESC. Ein Auflösungsfehler setzt IsPartial=1. Details erscheinen ausschließlich als RAW-Seitendetailresultset beziehungsweise in JSON.pageDetails bei @JsonErzeugen=1; CONSOLE und TABLE enthalten nur integrity-Zeilen, NONE gibt keine normalen Resultsets aus. Es erfolgt kein DBCC CHECKDB. Numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1.';
        PRINT N'@MaxZeilen int; Default: 1000. Ganzzahlig; negative Werte ungültig, NULL/0 wird auf den größten bigint-Wert abgebildet (praktisch unbegrenzt), ausgelassen = 1000. Integritätszeilen nach Quellenaggregation: Findings vor NO_INDICATOR_FOUND, dann DatabaseName und DatabaseId. PageDetails hat zusätzlich ein eigenes TOP-Limit in gleicher Höhe. Keine Vorabbegrenzung der Kandidaten/Quellen.';
        PRINT N'@ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Bindung an varchar(16), Trim von U+0020-Leerzeichen und UPPER gelten RAW, CONSOLE, TABLE und NONE. NULL, leer und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. RAW liefert Status und die technischen Fachresultsets. CONSOLE liefert nur die lesbare integrity-Fachmenge über den Console-Helfer, ohne separates Statusresultset; TABLE schreibt nur diese benannte Fachmenge in das Ziel. NONE unterdrückt normale Resultsets. TABLE-Zielvorprüfung oder Ablehnung eines nicht leeren Mappings außerhalb TABLE laufen vor @Hilfe=1 und können werfen. Hilfe kehrt danach vor der Analyse und JSON-Erzeugung zurück; angefordertes JSON im normalen Pfad ist unabhängig vom Ausgabemodus.';
        PRINT N'@ResultTablesJson nvarchar(max); Default: NULL. Für TABLE ist ein JSON-Objekt mit genau dem Schlüssel integrity erforderlich; der Wert muss ein String mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein, etwa N''{"integrity":"#DatabaseIntegrityAnalysis_HelpExample"}''. Das Ziel muss leer sein und genau eine beliebig typisierte Seed-Spalte besitzen; beim TABLE-Schreiben richtet der Ausgabehelfer daraus die Zielspalten ein. NULL oder nach Trim von U+0020 leere Eingabe ist in TABLE ungültig. Außerhalb TABLE sind nur NULL oder nach diesem Trim leere Werte zulässig; andere Werte werfen 51011. Diese Prüfung läuft auch bei TABLE zusammen mit @Hilfe=1 vor der Hilfe-Rückkehr. Ausgelassen = NULL.';
        PRINT N'@JsonErzeugen bit; Default: 0. Bit-Schalter 0 = kein JSON, 1 = JSON erzeugen; NULL wirkt wegen IF wie aus; ausgelassen = 0. Zahlen folgen bit-Konvertierung (0 bleibt 0, konvertierbarer Nichtnullwert wird 1). JSON ist unabhängig vom ResultSetArt-Modus.';
        PRINT N'@Json nvarchar(max) OUTPUT; Default: NULL. Optionales nvarchar(max)-OUTPUT. Beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält es meta, integrity, pageDetails und warnings, sonst bleibt es NULL. Als Variable mit OUTPUT binden; Eingabewert bleibt nicht erhalten.';
        PRINT N'@PrintMeldungen bit; Default: 1. Bit-Schalter für Severity-10-RAISERROR mit NOWAIT bei globalem Status ungleich AVAILABLE: 1 aktiviert, 0 unterdrückt; NULL wirkt wie aus; ausgelassen = 1. Kandidatenwarnungen sind davon getrennte Resultate.';
        PRINT N'@Hilfe bit; Default: 0. Bit-Schalter: 1 druckt Hilfe und kehrt vor Analyse-Resultaten zurück, 0 führt Analyse aus; NULL wirkt wie aus; ausgelassen = 0. OUTPUT-Ziele, die erst am normalen Ende gesetzt werden, bleiben im HELP-Pfad unverändert.';
        PRINT N'@StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionales varchar(40)-OUTPUT. Im normalen Pfad wird am Ende gesetzt; vor dieser Zuweisung initialisiert die Procedure das Outputziel nicht, und HELP kehrt vorher zurück, sodass ein gebundener vorhandener Variablenwert erhalten bleibt. Globale Werte: AVAILABLE = kein gesetzter Finding- oder Teilstatus; AVAILABLE_WITH_FINDING = bei vorherigem AVAILABLE ohne Teilstatus mindestens eine integrity-Zeile mit FindingCode ungleich NO_INDICATOR_FOUND; dazu zählt CHECKDB_EVIDENCE_UNAVAILABLE. Der aktuelle INSERT-CASE erzeugt NO_INDICATOR_FOUND nicht, daher reicht eine normale nichtleere Integrity-Menge für diesen Status; er bestätigt keinen Schaden; AVAILABLE_LIMITED = Teilquelle oder Kandidatenwarnung begrenzt die Vollständigkeit; INVALID_PARAMETER = ungültige Eingabe; DENIED_GROUP = Analyseklasse laut aktueller Policy nicht freigegeben; DENIED_PERMISSION = erforderliche Abfrage verweigert; ERROR_HANDLED = sonstiger behandelter Analysefehler; INTERNAL_ERROR = interner Kandidatenvorbereitungsfehler; UNAVAILABLE_FEATURE = Regexmodus auf nicht unterstützter Engine-/Installationsdatenbank-Kompatibilität. Beide fest verdrahteten Klassen haben RequiresGroupGate=0, daher verlangen sie keine High-Impact-Bestätigung. Per-Datenbank-Warnungen wie SYSTEM_DATABASE_EXCLUDED (Systemdatenbank aus Scope ausgelassen) und DATABASE_UNAVAILABLE (Kandidat nicht verfügbar) sind Warnungszeilen, keine globalen Codes. Teilstatus wird zusätzlich über @IsPartialOut signalisiert. Als Variable mit OUTPUT-Bindung übergeben; ausgelassen wird kein Wert zurückgegeben. Optionaler Empfang mit @StatusCodeOut=@Empfaenger OUTPUT; die Variable muss varchar(40) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.';
        PRINT N'@IsPartialOut bit OUTPUT; Default: NULL. Optionales bit-OUTPUT zur Teilvollständigkeit (0 vollständig, 1 Teilquelle/Berechtigungs-/Warnungseinschränkung). HELP erreicht die normale Zuweisung nicht und lässt den bisherigen Variablenwert unverändert. Als Variable mit OUTPUT binden. Optionaler Empfang mit @IsPartialOut=@Empfaenger OUTPUT; die Variable muss bit sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.';
        PRINT N'@ErrorNumberOut int OUTPUT; Default: NULL. Optionales int-OUTPUT für die gespeicherte SQL-Fehlernummer; NULL, wenn keine gespeichert wurde. HELP weist nicht zu. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorNumberOut=@Empfaenger OUTPUT; die Variable muss int sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.';
        PRINT N'@ErrorMessageOut nvarchar(2048) OUTPUT; Default: NULL. Optionales nvarchar(2048)-OUTPUT für gespeicherten Fehler-/Teilhinweis; ohne Hinweis NULL. HELP weist nicht zu. Kandidatenwarnungen bleiben separat. Als Variable mit OUTPUT binden. Optionaler Empfang mit @ErrorMessageOut=@Empfaenger OUTPUT; die Variable muss nvarchar(2048) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.';
        PRINT N'EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'';';
        PRINT N'DECLARE @IntegrityJson nvarchar(max); EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@IntegrityJson OUTPUT; SELECT @IntegrityJson AS [Json];';
        PRINT N'CREATE TABLE [#DatabaseIntegrityAnalysis_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"integrity":"#DatabaseIntegrityAnalysis_HelpExample"}''; END TRY BEGIN CATCH DROP TABLE [#DatabaseIntegrityAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE [#DatabaseIntegrityAnalysis_HelpExample];';
        PRINT N'EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @Hilfe=1;';





        -- USAGE_SKILL_HELP_BEGIN monitor.USP_DatabaseIntegrityAnalysis
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_DatabaseIntegrityAnalysis') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_DatabaseIntegrityAnalysis"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_DatabaseIntegrityAnalysis"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Die Procedure liefert korrelierte, rein lesende Integritätsindikatoren je ausgewählter Datenbank, ohne DBCC CHECKDB auszuführen."'
            + NCHAR(10)
            + N'source_path: "Code/08_ServerHealth/110_USP_DatabaseIntegrityAnalysis.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_DatabaseIntegrityAnalysis'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure liefert korrelierte, rein lesende Integritätsindikatoren je ausgewählter Datenbank, ohne DBCC CHECKDB auszuführen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Aufruf braucht EXECUTE auf [monitor].[USP_DatabaseIntegrityAnalysis] im vorgesehenen Datenbankkontext. Die Procedure liest `msdb`-Historie, Auto-Page-Repair und optional Page-Informationen in zugänglichen Datenbanken. Historie und Metadatensicht ersetzen keine neue DBCC-Integritätsprüfung.'
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
            + N'| @CheckdbWarnHours | int | nein | 168 |'
            + NCHAR(10)
            + N'| @BackupHistoryDays | int | nein | 35 |'
            + NCHAR(10)
            + N'| @MitPageDetails | bit | nein | 0 |'
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
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed bit; Default: 0. Bit-Bestätigung der fest verdrahteten Analyseklasse; 0 = nicht bestätigt, 1 = bestätigt. NULL ungültig; ausgelassen = 0. Numerische Werte werden als bit konvertiert: 0 bleibt 0, konvertierbarer Nichtnullwert wird 1. Die Bestätigung selbst erteilt weder Gruppenmitgliedschaft noch Berechtigung; der Helper prüft zusätzlich die aktivierte Klassen-/Gruppenpolicy.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CheckdbWarnHours:** @CheckdbWarnHours int; Default: 168. Ganzzahl Stunden, zulässig ab 1; ausgelassen = 168. NULL wird von < 1 nicht zurückgewiesen. Im aktuellen Pfad wird der Wert nur validiert: LastGoodCheckDbTime und CheckdbAgeHours bleiben NULL, ein CHECKDB-Alter wird nicht damit verglichen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@BackupHistoryDays:** @BackupHistoryDays int; Default: 35. Ganzzahl Tage, 1 bis 3650; ausgelassen = 35. NULL wird nicht ausdrücklich zurückgewiesen. Begrenzt nur Backupmetadaten mit backup_finish_date >= DATEADD(DAY,-@BackupHistoryDays,GETDATE()); Basis ist lokale Serverzeit via GETDATE(), nicht UTC. DATEADD setzt einen Kalenderzeitpunkt, keine garantierte Anzahl verstrichener 24-Stunden-Intervalle. Bei NULL wird der DATEADD-Stichtag NULL; der Vergleich backup_finish_date >= NULL trifft auf keine Backupzeile zu. Dies belegt keinen Erfolg der Backups.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MitPageDetails:** @MitPageDetails bit; Default: 0. 0 oder NULL überspringt Seitenauflösung; 1 fordert sie nur bei bisherigem Status AVAILABLE an. sys.dm_db_page_info(...,LIMITED) löst höchstens @MaxZeilen suspect_pages-Zeilen der ausgewählten Kandidaten auf; NULL/0 bei @MaxZeilen bedeutet unbegrenzt. Die begrenzte Kandidatenauswahl ordnet LastUpdateDate DESC, DatabaseId, FileId, PageId. RAW ordnet die Details danach nach LastUpdateDate DESC, DatabaseName, FileId, PageId; JSON ordnet nur nach LastUpdateDate DESC. Ein Auflösungsfehler setzt IsPartial=1. Details erscheinen ausschließlich als RAW-Seitendetailresultset beziehungsweise in JSON.pageDetails bei @JsonErzeugen=1; CONSOLE und TABLE enthalten nur integrity-Zeilen, NONE gibt keine normalen Resultsets aus. Es erfolgt kein DBCC CHECKDB. Numerische 0 bleibt bit 0, von 0 verschiedene konvertierbare Zahlen werden bit 1.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@MaxZeilen:** @MaxZeilen int; Default: 1000. Ganzzahlig; negative Werte ungültig, NULL/0 wird auf den größten bigint-Wert abgebildet (praktisch unbegrenzt), ausgelassen = 1000. Integritätszeilen nach Quellenaggregation: Findings vor NO_INDICATOR_FOUND, dann DatabaseName und DatabaseId. PageDetails hat zusätzlich ein eigenes TOP-Limit in gleicher Höhe. Keine Vorabbegrenzung der Kandidaten/Quellen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultSetArt:** @ResultSetArt varchar(16); Default: ''CONSOLE''. Nach Bindung an varchar(16), Trim von U+0020-Leerzeichen und UPPER gelten RAW, CONSOLE, TABLE und NONE. NULL, leer und andere Texte sind INVALID_PARAMETER; ausgelassen = CONSOLE. RAW liefert Status und die technischen Fachresultsets. CONSOLE liefert nur die lesbare integrity-Fachmenge über den Console-Helfer, ohne separates Statusresultset; TABLE schreibt nur diese benannte Fachmenge in das Ziel. NONE unterdrückt normale Resultsets. TABLE-Zielvorprüfung oder Ablehnung eines nicht leeren Mappings außerhalb TABLE laufen vor @Hilfe=1 und können werfen. Hilfe kehrt danach vor der Analyse und JSON-Erzeugung zurück; angefordertes JSON im normalen Pfad ist unabhängig vom Ausgabemodus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Für TABLE ist ein JSON-Objekt mit genau dem Schlüssel integrity erforderlich; der Wert muss ein String mit dem Namen einer vorhandenen lokalen #Temp-Tabelle sein, etwa N''{"integrity":"#DatabaseIntegrityAnalysis_HelpExample"}''. Das Ziel muss leer sein und genau eine beliebig typisierte Seed-Spalte besitzen; beim TABLE-Schreiben richtet der Ausgabehelfer daraus die Zielspalten ein. NULL oder nach Trim von U+0020 leere Eingabe ist in TABLE ungültig. Außerhalb TABLE sind nur NULL oder nach diesem Trim leere Werte zulässig; andere Werte werfen 51011. Diese Prüfung läuft auch bei TABLE zusammen mit @Hilfe=1 vor der Hilfe-Rückkehr. Ausgelassen = NULL.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Bit-Schalter 0 = kein JSON, 1 = JSON erzeugen; NULL wirkt wegen IF wie aus; ausgelassen = 0. Zahlen folgen bit-Konvertierung (0 bleibt 0, konvertierbarer Nichtnullwert wird 1). JSON ist unabhängig vom ResultSetArt-Modus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Optionales nvarchar(max)-OUTPUT. Beim Eintritt auf NULL gesetzt; bei @JsonErzeugen=1 enthält es meta, integrity, pageDetails und warnings, sonst bleibt es NULL. Als Variable mit OUTPUT binden; Eingabewert bleibt nicht erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bit-Schalter für Severity-10-RAISERROR mit NOWAIT bei globalem Status ungleich AVAILABLE: 1 aktiviert, 0 unterdrückt; NULL wirkt wie aus; ausgelassen = 1. Kandidatenwarnungen sind davon getrennte Resultate.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe bit; Default: 0. Bit-Schalter: 1 druckt Hilfe und kehrt vor Analyse-Resultaten zurück, 0 führt Analyse aus; NULL wirkt wie aus; ausgelassen = 0. OUTPUT-Ziele, die erst am normalen Ende gesetzt werden, bleiben im HELP-Pfad unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT; Default: NULL. Optionales varchar(40)-OUTPUT. Im normalen Pfad wird am Ende gesetzt; vor dieser Zuweisung initialisiert die Procedure das Outputziel nicht, und HELP kehrt vorher zurück, sodass ein gebundener vorhandener Variablenwert erhalten bleibt. Globale Werte: AVAILABLE = kein gesetzter Finding- oder Teilstatus; AVAILABLE_WITH_FINDING = bei vorherigem AVAILABLE ohne Teilstatus mindestens eine integrity-Zeile mit FindingCode ungleich NO_INDICATOR_FOUND; dazu zählt CHECKDB_EVIDENCE_UNAVAILABLE. Der aktuelle INSERT-CASE erzeugt NO_INDICATOR_FOUND nicht, daher reicht eine normale nichtleere Integrity-Menge für diesen Status; er bestätigt keinen Schaden; AVAILABLE_LIMITED = Teilquelle oder Kandidatenwarnung begrenzt die Vollständigkeit; INVALID_PARAMETER = ungültige Eingabe; DENIED_GROUP = Analyseklasse laut aktueller Policy nicht freigegeben; DENIED_PERMISSION = erforderliche Abfrage verweigert; ERROR_HANDLED = sonstiger behandelt'
            + N'er Analysefehler; INTERNAL_ERROR = interner Kandidatenvorbereitungsfehler; UNAVAILABLE_FEATURE = Regexmodus auf nicht unterstützter Engine-/Installationsdatenbank-Kompatibilität. Beide fest verdrahteten Klassen haben RequiresGroupGate=0, daher verlangen sie keine High-Impact-Bestätigung. Per-Datenbank-Warnungen wie SYSTEM_DATABASE_EXCLUDED (Systemdatenbank aus Scope ausgelassen) und DATABASE_UNAVAILABLE (Kandidat nicht verfügbar) sind Warnungszeilen, keine globalen Codes. Teilstatus wird zusätzlich über @IsPartialOut signalisiert. Als Variable mit OUTPUT-Bindung übergeben; ausgelassen wird kein Wert zurückgegeben. Optionaler Empfang mit @StatusCodeOut=@Empfaenger OUTPUT; die Variable muss varchar(40) sein. Ein Anfangswert einschließlich NULL wird im normalen Pfad überschrieben, bei Hilfe unverändert gelassen; ein früher Preflight-THROW umgeht diese Zuweisung.'
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
            + N'| integrity | 1 | 1 | [DatabaseId] int NOT NULL , [DatabaseName] sysname NOT NULL , [StateDesc] nvarchar(60) NULL , [PageVerifyOptionDesc] nvarchar(60) NULL , [LastGoodCheckDbTime] datetime2(3) NULL , [CheckdbAgeHours] bigint NULL , [SuspectPageCount] bigint NOT NULL , [LatestSuspectPageUtc] datetime NULL , [DamagedBackupCount] bigint NOT NULL , [BackupWithoutChecksumCount] bigint NOT NULL , [HadrPageRepairCount] bigint NOT NULL , [HadrPageRepairPendingCount] bigint NOT NULL , [FindingCode] varchar(80) NOT NULL , [EvidenceLimit] nvarchar(1000) NOT NULL |'
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
            + N'EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''RAW'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Leere Indikatoren beweisen keine Integrität. Die Procedure führt weder DBCC CHECKDB noch Restore, Reparatur oder Konfiguration aus.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Metadaten LOW; gezielte Seitenauflösung MEDIUM und opt-in.'
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
            + N'Objekt       : monitor.USP_DatabaseIntegrityAnalysis'
            + NCHAR(10)
            + N'Version      : 1.0.2'
            + NCHAR(10)
            + N'Stand        : 2026-07-18'
            + NCHAR(10)
            + N'Zweck        : Die Procedure liefert korrelierte, rein lesende Integritätsindikatoren je'
            + NCHAR(10)
            + N'               ausgewählter Datenbank, ohne DBCC CHECKDB auszuführen.'
            + NCHAR(10)
            + N'Datenquellen : master.sys.databases,'
            + NCHAR(10)
            + N'               msdb.dbo.suspect_pages, msdb.dbo.backupset,'
            + NCHAR(10)
            + N'               sys.dm_hadr_auto_page_repair und optional sys.dm_db_page_info.'
            + NCHAR(10)
            + N'Grenzen      : Leere Indikatoren beweisen keine Integrität. Die Procedure führt'
            + NCHAR(10)
            + N'               weder DBCC CHECKDB noch Restore, Reparatur oder Konfiguration aus.'
            + NCHAR(10)
            + N'Kosten       : Metadaten LOW; gezielte Seitenauflösung MEDIUM und opt-in.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_DatabaseIntegrityAnalysis'
            + NCHAR(10)
            + N'Die Procedure sammelt rein lesende, korrelierte Integritätsindikatoren je Datenbank. Sie führt kein DBCC CHECKDB, Restore oder Repair aus; fehlende Indikatoren belegen keine Integrität.'
            + NCHAR(10)
            + N'DECLARE @IntegrityJson nvarchar(max); EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''NONE'', @JsonErzeugen=1, @Json=@IntegrityJson OUTPUT; SELECT @IntegrityJson AS [Json];'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE [#DatabaseIntegrityAnalysis_HelpExample]([Seed] bit NULL); BEGIN TRY EXEC [monitor].[USP_DatabaseIntegrityAnalysis] @DatabaseNames=N''[ExampleDatabase]'', @ResultSetArt=''TABLE'', @ResultTablesJson=N''{"integrity":"#DatabaseIntegrityAnalysis_HelpExample"}''; END TRY BEGIN CATCH DROP TABLE [#DatabaseIntegrityAnalysis_HelpExample]; THROW; END CATCH; DROP TABLE [#DatabaseIntegrityAnalysis_HelpExample];'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_DatabaseIntegrityAnalysis
        RETURN;
    END

    SET @Json = NULL;

    DECLARE @OutputMode varchar(16) =
        UPPER(LTRIM(RTRIM(COALESCE(@ResultSetArt, ''))));
    DECLARE @TableResultRequested bit = CASE WHEN @OutputMode = 'TABLE' THEN 1 ELSE 0 END;
    DECLARE @ConsoleResultRequested bit = CASE WHEN @OutputMode = 'CONSOLE' THEN 1 ELSE 0 END;
    DECLARE @TableTarget sysname=NULL;
    IF @TableResultRequested=0 AND NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL THROW 51011,N'@ResultTablesJson ist ausschließlich mit @ResultSetArt=TABLE zulässig.',1;
    IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'integrity',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;
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

    CREATE TABLE [#DatabaseIntegrityAnalysis_DatabaseCandidates]
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

    CREATE TABLE [#DatabaseIntegrityAnalysis_DatabaseCandidateWarnings]
    (
          [RequestedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    CREATE TABLE [#DatabaseIntegrityAnalysis_Suspect]
    (
          [DatabaseId] int NOT NULL
        , [FileId] int NOT NULL
        , [PageId] bigint NOT NULL
        , [EventType] int NOT NULL
        , [ErrorCount] int NULL
        , [LastUpdateDate] datetime NULL
    );

    CREATE TABLE [#DatabaseIntegrityAnalysis_HadrRepair]
    (
          [DatabaseId] int NOT NULL
        , [FileId] int NOT NULL
        , [PageId] bigint NOT NULL
        , [ErrorType] int NULL
        , [PageStatus] int NULL
        , [ModificationTime] datetime NULL
    );

    CREATE TABLE [#DatabaseIntegrityAnalysis_Integrity]
    (
          [DatabaseId] int NOT NULL
        , [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [StateDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [PageVerifyOptionDesc] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [LastGoodCheckDbTime] datetime2(3) NULL
        , [CheckdbAgeHours] bigint NULL
        , [SuspectPageCount] bigint NOT NULL
        , [LatestSuspectPageUtc] datetime NULL
        , [DamagedBackupCount] bigint NOT NULL
        , [BackupWithoutChecksumCount] bigint NOT NULL
        , [HadrPageRepairCount] bigint NOT NULL
        , [HadrPageRepairPendingCount] bigint NOT NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [EvidenceLimit] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
    );

    CREATE TABLE [#DatabaseIntegrityAnalysis_PageDetails]
    (
          [DatabaseName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [FileId] int NULL
        , [PageId] bigint NULL
        , [EventType] int NULL
        , [LastUpdateDate] datetime NULL
        , [ObjectId] int NULL
        , [IndexId] int NULL
        , [PartitionId] bigint NULL
        , [PageTypeDesc] nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AllocUnitId] bigint NULL
    );

    IF @CheckdbWarnHours < 1
       OR @BackupHistoryDays < 1
       OR @BackupHistoryDays > 3650
       OR @MaxZeilen < 0
       OR @OutputMode NOT IN ('RAW', 'CONSOLE', 'NONE')
    BEGIN
        SELECT @StatusCode = 'INVALID_PARAMETER',
               @IsPartial = 1,
               @ErrorMessage = N'Ungültige Datenbank-, Zeit-, Zeilen- oder Ausgabeparameter.';
    END;

    IF @StatusCode = 'AVAILABLE'
       AND @HasRequiredServerPermission = 0
    BEGIN
        SELECT @IsPartial = 1,
               @ErrorMessage = CONCAT(N'Für vollständige serverweite Integritätsevidenz fehlt ',
                                      @RequiredServerPermission, N'.');
    END;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        EXEC [monitor].[USP_PrepareDatabaseCandidates]
              @DatabaseNames = @DatabaseNames
            , @SystemdatenbankenEinbeziehen = @SystemdatenbankenEinbeziehen
            , @DatabaseNamePattern = @DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed

            , @AnalysisClass = 'HA_DR_CURRENT'
            , @StatusCode = @StatusCode OUTPUT
            , @ErrorMessage = @ErrorMessage OUTPUT
            , @CrossDatabaseRequested = @CrossDatabaseRequested OUTPUT,@CandidateTable=N'#DatabaseIntegrityAnalysis_DatabaseCandidates',@WarningTable=N'#DatabaseIntegrityAnalysis_DatabaseCandidateWarnings';
    END;

    SET LOCK_TIMEOUT 0;

    IF @StatusCode = 'AVAILABLE'
    BEGIN
        BEGIN TRY
            INSERT [#DatabaseIntegrityAnalysis_Suspect]
            (
                  [DatabaseId], [FileId], [PageId], [EventType]
                , [ErrorCount], [LastUpdateDate]
            )
            SELECT
                  [sp].[database_id], [sp].[file_id], [sp].[page_id]
                , [sp].[event_type], [sp].[error_count], [sp].[last_update_date]
            FROM [msdb].[dbo].[suspect_pages] AS [sp] WITH (NOLOCK)
            JOIN [#DatabaseIntegrityAnalysis_DatabaseCandidates] AS [c]
              ON [c].[DatabaseId] = [sp].[database_id];
        END TRY
        BEGIN CATCH
            SELECT @IsPartial = 1,
                   @ErrorNumber = ERROR_NUMBER(),
                   @ErrorMessage = CONCAT(N'suspect_pages nicht lesbar: ', ERROR_MESSAGE());
        END CATCH;

        BEGIN TRY
            INSERT [#DatabaseIntegrityAnalysis_HadrRepair]
            (
                  [DatabaseId], [FileId], [PageId], [ErrorType]
                , [PageStatus], [ModificationTime]
            )
            SELECT
                  [r].[database_id], [r].[file_id], [r].[page_id]
                , [r].[error_type], [r].[page_status], [r].[modification_time]
            FROM [sys].[dm_hadr_auto_page_repair] AS [r] WITH (NOLOCK)
            JOIN [#DatabaseIntegrityAnalysis_DatabaseCandidates] AS [c]
              ON [c].[DatabaseId] = [r].[database_id];
        END TRY
        BEGIN CATCH
            SET @IsPartial = 1;
            IF @ErrorNumber IS NULL
            BEGIN
                SELECT @ErrorNumber = ERROR_NUMBER(),
                       @ErrorMessage = CONCAT(N'HADR-Seitenreparaturstatus nicht lesbar: ', ERROR_MESSAGE());
            END;
        END CATCH;

        BEGIN TRY
            ;WITH [BackupEvidence] AS
            (
                SELECT
                      [bs].[database_name]
                    , SUM(CONVERT(bigint, CASE WHEN [bs].[is_damaged] = 1 THEN 1 ELSE 0 END)) AS [DamagedCount]
                    , SUM(CONVERT(bigint, CASE WHEN COALESCE([bs].[has_backup_checksums], 0) = 0 THEN 1 ELSE 0 END)) AS [NoChecksumCount]
                FROM [msdb].[dbo].[backupset] AS [bs] WITH (NOLOCK)
                JOIN [#DatabaseIntegrityAnalysis_DatabaseCandidates] AS [c]
                  ON [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
                   = [bs].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
                WHERE [bs].[backup_finish_date] >= DATEADD(DAY, -@BackupHistoryDays, GETDATE())
                GROUP BY [bs].[database_name]
            ),
            [SuspectEvidence] AS
            (
                SELECT [DatabaseId], COUNT_BIG(*) AS [PageCount],
                       MAX([LastUpdateDate]) AS [LatestDate]
                FROM [#DatabaseIntegrityAnalysis_Suspect]
                GROUP BY [DatabaseId]
            ),
            [RepairEvidence] AS
            (
                SELECT [DatabaseId], COUNT_BIG(*) AS [RepairCount],
                       SUM(CONVERT(bigint, CASE WHEN [PageStatus] <> 5 THEN 1 ELSE 0 END)) AS [PendingCount]
                FROM [#DatabaseIntegrityAnalysis_HadrRepair]
                GROUP BY [DatabaseId]
            )
            INSERT [#DatabaseIntegrityAnalysis_Integrity]
            SELECT
                  [c].[DatabaseId]
                , [c].[DatabaseName]
                , [c].[StateDesc]
                , [d].[page_verify_option_desc]
                , CONVERT(datetime2(3), NULL)
                , CONVERT(int, NULL)
                , COALESCE([s].[PageCount], 0)
                , [s].[LatestDate]
                , COALESCE([b].[DamagedCount], 0)
                , COALESCE([b].[NoChecksumCount], 0)
                , COALESCE([r].[RepairCount], 0)
                , COALESCE([r].[PendingCount], 0)
                , CASE
                      WHEN COALESCE([s].[PageCount], 0) > 0 THEN 'SUSPECT_PAGES_PRESENT'
                      WHEN COALESCE([b].[DamagedCount], 0) > 0 THEN 'DAMAGED_BACKUP_METADATA'
                      WHEN COALESCE([r].[PendingCount], 0) > 0 THEN 'HADR_PAGE_REPAIR_PENDING'
                      WHEN [d].[page_verify_option_desc] <> N'CHECKSUM' THEN 'PAGE_VERIFY_NOT_CHECKSUM'
                      WHEN COALESCE([b].[NoChecksumCount], 0) > 0 THEN 'BACKUP_WITHOUT_CHECKSUM_IN_VISIBLE_HISTORY'
                      ELSE 'CHECKDB_EVIDENCE_UNAVAILABLE'
                  END
                , CONCAT(N'Diese Metadaten sind Indizien; Backupmetadaten-Sichtfenster ', @BackupHistoryDays,
                         N' Tage. LastGoodCheckDbTime wird bewusst nicht über DATABASEPROPERTYEX gelesen, ',
                         N'da diese Metadatenfunktion blockieren kann. Auch CHECKDB_EVIDENCE_UNAVAILABLE ',
                         N'beweist weder logische noch physische Integrität.')
            FROM [#DatabaseIntegrityAnalysis_DatabaseCandidates] AS [c]
            JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
              ON [d].[database_id] = [c].[DatabaseId]
            LEFT JOIN [BackupEvidence] AS [b]
              ON [b].[database_name] COLLATE SQL_Latin1_General_CP1_CS_AS
               = [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
            LEFT JOIN [SuspectEvidence] AS [s]
              ON [s].[DatabaseId] = [c].[DatabaseId]
            LEFT JOIN [RepairEvidence] AS [r]
              ON [r].[DatabaseId] = [c].[DatabaseId];
        END TRY
        BEGIN CATCH
            SELECT @StatusCode =
                       CASE WHEN ERROR_NUMBER() IN (229, 262, 297, 300, 371)
                            THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
                   @IsPartial = 1,
                   @ErrorNumber = ERROR_NUMBER(),
                   @ErrorMessage = ERROR_MESSAGE();
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE' AND @MitPageDetails = 1
    BEGIN
        BEGIN TRY
            INSERT [#DatabaseIntegrityAnalysis_PageDetails]
            SELECT TOP (@Limit)
                  [c].[DatabaseName]
                , [s].[FileId]
                , [s].[PageId]
                , [s].[EventType]
                , [s].[LastUpdateDate]
                , [p].[object_id]
                , [p].[index_id]
                , [p].[partition_id]
                , [p].[page_type_desc]
                , [p].[alloc_unit_id]
            FROM [#DatabaseIntegrityAnalysis_Suspect] AS [s]
            JOIN [#DatabaseIntegrityAnalysis_DatabaseCandidates] AS [c]
              ON [c].[DatabaseId] = [s].[DatabaseId]
            OUTER APPLY [sys].[dm_db_page_info]
            (
                  [s].[DatabaseId], [s].[FileId], [s].[PageId], 'LIMITED'
            ) AS [p]
            ORDER BY [s].[LastUpdateDate] DESC, [s].[DatabaseId], [s].[FileId], [s].[PageId];
        END TRY
        BEGIN CATCH
            SET @IsPartial = 1;
            IF @ErrorNumber IS NULL
            BEGIN
                SELECT @ErrorNumber = ERROR_NUMBER(),
                       @ErrorMessage = CONCAT(N'Seitenmetadaten nicht lesbar: ', ERROR_MESSAGE());
            END;
        END CATCH;
    END;

    IF @StatusCode = 'AVAILABLE'
       AND (@IsPartial = 1 OR EXISTS (SELECT 1 FROM [#DatabaseIntegrityAnalysis_DatabaseCandidateWarnings]))
        SET @StatusCode = 'AVAILABLE_LIMITED';
    ELSE IF @StatusCode = 'AVAILABLE'
        AND EXISTS (SELECT 1 FROM [#DatabaseIntegrityAnalysis_Integrity] WHERE [FindingCode] <> 'NO_INDICATOR_FOUND')
        SET @StatusCode = 'AVAILABLE_WITH_FINDING';

    ;WITH [RankedIntegrity] AS
    (
        SELECT *,ROW_NUMBER() OVER
            (ORDER BY CASE WHEN [FindingCode]='NO_INDICATOR_FOUND' THEN 1 ELSE 0 END,
                      [DatabaseName],[DatabaseId]) AS [OutputOrdinal]
        FROM [#DatabaseIntegrityAnalysis_Integrity]
    )
    DELETE FROM [RankedIntegrity] WHERE [OutputOrdinal]>@Limit;

    SELECT @StatusCodeOut = @StatusCode,
           @IsPartialOut = @IsPartial,
           @ErrorNumberOut = @ErrorNumber,
           @ErrorMessageOut = @ErrorMessage;

    IF @PrintMeldungen = 1 AND @StatusCode <> 'AVAILABLE'
    BEGIN
        SET @MonitorPrintMessage = COALESCE(@ErrorMessage, CONVERT(nvarchar(2048), @StatusCode));
        RAISERROR(N'USP_DatabaseIntegrityAnalysis: %s', 10, 1, @MonitorPrintMessage) WITH NOWAIT;
    END;

    IF @OutputMode <> 'NONE'
    BEGIN
        SELECT
              CAST('1.0' AS varchar(16)) AS [ContractVersion]
            , @Now AS [CollectionTimeUtc]
            , N'monitor.USP_DatabaseIntegrityAnalysis' AS [ModuleName]
            , @StatusCode AS [StatusCode]
            , @IsPartial AS [IsPartial]
            , @ErrorNumber AS [ErrorNumber]
            , @ErrorMessage AS [ErrorMessage];

        IF @OutputMode = 'RAW'
        BEGIN
            SELECT * FROM [#DatabaseIntegrityAnalysis_Integrity]
            ORDER BY CASE WHEN [FindingCode] = 'NO_INDICATOR_FOUND' THEN 1 ELSE 0 END,
                     [DatabaseName];
            SELECT * FROM [#DatabaseIntegrityAnalysis_PageDetails]
            ORDER BY [LastUpdateDate] DESC, [DatabaseName], [FileId], [PageId];
            SELECT * FROM [#DatabaseIntegrityAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName];
        END
        ELSE
        BEGIN
            SELECT
                  N'Integritätsevidenz' AS [Ergebnis]
                , [DatabaseName] AS [Datenbank]
                , [FindingCode] AS [Bewertung]
                , [PageVerifyOptionDesc] AS [Page Verify]
                , [LastGoodCheckDbTime] AS [Letzter erfolgreicher CHECKDB-Nachweis]
                , [CheckdbAgeHours] AS [Nachweisalter Stunden]
                , [SuspectPageCount] AS [Verdächtige Seiten]
                , [DamagedBackupCount] AS [Beschädigte Backupmetadaten]
                , [BackupWithoutChecksumCount] AS [Backups ohne Checksum]
                , [HadrPageRepairPendingCount] AS [Offene HADR-Seitenreparaturen]
                , [EvidenceLimit] AS [Aussagegrenze]
            FROM [#DatabaseIntegrityAnalysis_Integrity]
            ORDER BY CASE WHEN [FindingCode] = 'NO_INDICATOR_FOUND' THEN 1 ELSE 0 END,
                     [DatabaseName];

            SELECT N'Seitenmetadaten' AS [Ergebnis], [p].*
            FROM [#DatabaseIntegrityAnalysis_PageDetails] AS [p]
            ORDER BY [LastUpdateDate] DESC, [DatabaseName], [FileId], [PageId];
        END;
    END;

    IF @JsonErzeugen = 1
    BEGIN
        DECLARE @MetaJson nvarchar(max) =
        (
            SELECT N'DatabaseIntegrityAnalysis' AS [resultName], 1 AS [schemaVersion],
                   @Now AS [generatedAtUtc], @StatusCode AS [statusCode],
                   @IsPartial AS [isPartial], @ErrorNumber AS [errorNumber],
                   @ErrorMessage AS [errorMessage]
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES
        );
        DECLARE @IntegrityJson nvarchar(max) =
            (SELECT * FROM [#DatabaseIntegrityAnalysis_Integrity] ORDER BY [DatabaseName] FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @PagesJson nvarchar(max) =
            (SELECT * FROM [#DatabaseIntegrityAnalysis_PageDetails] ORDER BY [LastUpdateDate] DESC FOR JSON PATH, INCLUDE_NULL_VALUES);
        DECLARE @WarningsJson nvarchar(max) =
            (SELECT * FROM [#DatabaseIntegrityAnalysis_DatabaseCandidateWarnings] ORDER BY [RequestedName] FOR JSON PATH, INCLUDE_NULL_VALUES);

        SET @Json = CONCAT
        (
              N'{"meta":', COALESCE(@MetaJson, N'{}')
            , N',"integrity":', COALESCE(@IntegrityJson, N'[]')
            , N',"pageDetails":', COALESCE(@PagesJson, N'[]')
            , N',"warnings":', COALESCE(@WarningsJson, N'[]')
            , N'}'
        );
    END;
    IF @ConsoleResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalEmitConsoleResult]
              @SourceTable=N'#DatabaseIntegrityAnalysis_Integrity'
            , @ResultLabel=N'DatabaseIntegrityAnalysis'
            , @EmptyMessage=N'Keine fachlichen Ergebnisse';
    END;
    IF @TableResultRequested = 1
    BEGIN
        EXEC [monitor].[InternalWriteResultTable]
              @SourceTable = N'#DatabaseIntegrityAnalysis_Integrity'
            , @TargetTable=@TableTarget
            , @ThrowOnError = 1;
    END;
END;
GO
