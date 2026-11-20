USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.USP_PrepareDatabaseCandidates
Version      : 2.0.2
Stand        : 2026-10-14
Typ          : Öffentlicher Vorbereitungshelfer
Zweck        : Validiert die frameworkweite Datenbankauswahl, prüft den
               tatsächlich aktivierten Analysepfad und befüllt lokale
               Kandidaten- und Warning-Temp-Tabellen des Aufrufers.
Semantik     : Ohne explizite Einschränkung alle sichtbaren, online befindlichen
               Benutzerdatenbanken. Kein CURRENT-Scope und keine Vorabbegrenzung.
High Impact  : Nur eine tatsächlich aktivierte Analyseklasse mit
               RequiresGroupGate=1 verlangt @HighImpactConfirmed=1.
Vertrag      : Die Procedure kennt keine Datenbank-Mengenbegrenzung.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.USP_PrepareDatabaseCandidates 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.USP_PrepareDatabaseCandidates"
-- schema_name: "monitor"
-- object_name: "USP_PrepareDatabaseCandidates"
-- object_type: "PROCEDURE"
-- database_role: "framework"
-- is_internal: false
-- description: "Validiert die frameworkweite Datenbankauswahl, prüft den tatsächlich aktivierten Analysepfad und befüllt lokale Kandidaten- und Warning-Temp-Tabellen des Aufrufers."
-- source_path: "Code/01_Common/083_USP_PrepareDatabaseCandidates.sql"
-- ---
-- 
-- # monitor.USP_PrepareDatabaseCandidates
-- 
-- ## Zweck und Einsatz
-- 
-- Validiert die frameworkweite Datenbankauswahl, prüft den tatsächlich aktivierten Analysepfad und befüllt lokale Kandidaten- und Warning-Temp-Tabellen des Aufrufers.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_PrepareDatabaseCandidates]. Die Quelle nennt insbesondere `[monitor].[TVF_ParseSqlNameList]`, `[sys].[sp_executesql]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[InternalCheckAnalysisPath]`, `[monitor].[TVF_DatabaseCandidates]`, `[master].[sys].[databases]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
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
-- | @AnalysisClass | varchar(64) | nein | NULL |
-- | @HighImpactConfirmed | bit | nein | 0 |
-- | @StatusCode | varchar(40) | ja | kein Default; OUTPUT |
-- | @ErrorMessage | nvarchar(2048) | ja | kein Default; OUTPUT |
-- | @CrossDatabaseRequested | bit | ja | kein Default; OUTPUT |
-- | @CandidateTable | sysname | nein | N'#PrepareDatabaseCandidates_Result' |
-- | @WarningTable | sysname | nein | NULL |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@DatabaseNames:** @DatabaseNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL, leer oder nur Leerzeichen bedeutet nicht angegeben; ausgelassen verwendet NULL. Gültige Namen begrenzen Datenbankauswahl; nicht angegebene Liste bedeutet keine exakte Einschränkung. Ungültiger Name => INVALID_PARAMETER.
-- 
-- **@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen: bit, Default 0. 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL => INVALID_PARAMETER; ausgelassen =0. Bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Wirkt auf Auswahl und SYSTEM_DATABASE_EXCLUDED-Warnung.
-- 
-- **@DatabaseNamePattern:** @DatabaseNamePattern: nvarchar(4000), Default NULL. LIKE-Pattern (%, _, [...]) oder Präfix like:, regex:, regexi:; Präfixerkennung ohne Beachtung der Großschreibung. NULL/ausgelassen = kein Pattern. Äußere Leerzeichen werden entfernt; Inhalt nach Präfixentfernung nicht erneut getrimmt. Leerwert oder leeres Präfixergebnis ungültig; jedes nicht-NULL Pattern zusammen mit wirksamer @DatabaseNames-Liste ungültig. LIKE nutzt SQL_Latin1_General_CP1_CS_AS. Regex-Syntax wird nicht vorgeprüft; regex: Flag c, regexi: Flag i; Ausführung benötigt SQL Server 2025 und Compatibility Level >=170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. Regex filtert nach der Kandidatenermittlung alle Zeilen des Ziels.
-- 
-- **@AnalysisClass:** @AnalysisClass: varchar(64), Default NULL. NULL oder eine leere beziehungsweise nur aus U+0020-Leerzeichen bestehende Zeichenfolge schaltet die optionale Pfadprüfung aus; ausgelassen = NULL. Der Quellcode nutzt NULLIF(@AnalysisClass, ''); SQLs Auffüllvergleich behandelt eine leere oder nur aus U+0020-Leerzeichen bestehende Zeichenfolge als leer. Es gibt kein explizites Trim; führende Leerzeichen und andere Whitespace-Zeichen werden nicht normalisiert. Sonst einer der 31 Codes: 
-- 
-- **@HighImpactConfirmed:** @HighImpactConfirmed: bit, Default 0. 0 bestätigt nicht; 1 bestätigt nur ein Gate der tatsächlich angegebenen aktivierten Klasse. NULL => INVALID_PARAMETER auch ohne Klasse; ausgelassen =0. Bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Ersetzt Klassen- und Freigabeprüfung nicht.
-- 
-- **@StatusCode:** @StatusCode: Datentyp varchar(40); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ varchar(40) mit OUTPUT binden, zum Beispiel @StatusCode=@CallerStatusCode OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. AVAILABLE bedeutet, dass die Vorbereitung ohne erkannten Fehler abgeschlossen wurde; es bestätigt nicht, dass jeder angeforderte Name als Kandidat ausgewählt wurde. INVALID_PARAMETER kennzeichnet ungültige Auswahl-/Bestätigungs-/Temp-Tabellenparameter, ungültiges Pattern oder ungültige/duplizierte Namensliste sowie einen unbekannten Analyseklassencode. INTERNAL_ERROR kennzeichnet, dass die Kandidaten-Temp-Tabelle die geprüften erwarteten Spalten DatabaseId und DatabaseName nicht bereitstellt. UNAVAILABLE_FEATURE bedeutet, dass Regex mangels erforderlicher SQL-Server-Version oder Compatibility Level nicht ausgeführt werden kann. Delegiert kann HIGH_IMPACT_CONFIRMATION_REQUIRED bedeuten, dass eine tatsächlich aktivierte Klasse mit RequiresGroupGate=1 nicht mit @HighImpactConfirmed=1 bestätigt wurde; DENIED_GROUP bedeutet, dass die aktuelle Analysepfadfreigabe fehlt. Bei @Hilfe=1 bleibt die Aufrufervariable unverändert.
-- 
-- **@ErrorMessage:** @ErrorMessage: Datentyp nvarchar(2048); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ nvarchar(2048) mit OUTPUT binden, zum Beispiel @ErrorMessage=@CallerErrorMessage OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. Empfängt die Fehlerbeschreibung; bei erfolgreich abgeschlossener Vorbereitung ist der Wert NULL. Bei @Hilfe=1 wird er vor der Rückkehr nicht initialisiert und bleibt unverändert.
-- 
-- **@CrossDatabaseRequested:** @CrossDatabaseRequested: bit OUTPUT, ohne Default. Ein Argument ist auch bei Hilfe erforderlich. Für den Empfang eine bit-Variable mit OUTPUT binden; ohne OUTPUT wird der Rückgabewert nicht empfangen. 1 wenn normalisierte exakte Liste fehlt oder mehr als ein gültiges geparstes Element vorliegt, sonst 0. Beschreibt Anfrageform, keine Verfügbarkeit; vor Listenfehlerprüfung ermittelt. Bei Hilfe unverändert.
-- 
-- **@CandidateTable:** @CandidateTable: sysname, Default #PrepareDatabaseCandidates_Result. Name einer vorhandenen lokalen # Temp-Tabelle derselben Session; kein ##, max. 116 Zeichen. NULL/falscher Präfix/Überlänge => INVALID_PARAMETER. Spalten: DatabaseId int NOT NULL, DatabaseName sysname NOT NULL, StateDesc nvarchar(60) NULL, UserAccessDesc nvarchar(60) NULL, IsReadOnly bit NULL, CompatibilityLevel tinyint NULL, CollationName sysname NULL, RecoveryModelDesc nvarchar(60) NULL, IsSystemDatabase bit NULL, RequestedOrdinal int NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. TOP(0) prüft nur DatabaseId/DatabaseName; spätere Schema-/Insertfehler können entkommen. Hängt Kandidaten an; regulär keine Löschung. Bei nicht verfügbarer Regexfunktion werden vor UNAVAILABLE_FEATURE alle Zielzeilen gelöscht; Regex filtert auch Altzeilen.
-- 
-- **@WarningTable:** @WarningTable: sysname, Default NULL; NULL/ausgelassen deaktiviert Warnungen. Sonst vorhandene lokale # Tabelle derselben Session, kein ##, max. 116 Zeichen; falscher Präfix/Überlänge => INVALID_PARAMETER. Spalten RequestedName sysname NULL, StatusCode varchar(40) NULL, ErrorMessage nvarchar(2048) NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. Fehlende explizite Namen erhalten DATABASE_UNAVAILABLE oder SYSTEM_DATABASE_EXCLUDED. Scheiternde TOP(0)-Probe überspringt Tabelle still; späterer Insertfehler kann entkommen. Warnungen werden angehängt; Alt-Kandidaten beeinflussen Fehlend-Erkennung.
-- 
-- **@Hilfe:** @Hilfe: bit, Default 0. 0 verarbeitet; 1 druckt Hilfe und kehrt vor OUTPUT-Initialisierung und Tabellenverarbeitung zurück; NULL normaler Pfad. Ausgelassen =0; numerisch ungleich 0 wird bit-konvertiert zu 1. Für alle drei OUTPUT-Parameter sind auch bei Hilfe Argumente anzugeben. Für den Empfang Variable mit OUTPUT binden; im Hilfepfad bleiben die übergebenen Eingangswerte unverändert.
-- 
-- ## Resultate und Ausgabe
-- 
-- Kein Fach-Resultset. Die Procedure füllt die vom Aufrufer benannte Kandidaten-Temp-Tabelle und meldet `@StatusCode varchar(40)`, `@ErrorMessage nvarchar(2048)` und `@CrossDatabaseRequested bit` per OUTPUT. Normale Kandidaten sind sichtbare, online und zugängliche Datenbanken; ausgeschlossene oder nicht auffindbare angeforderte Namen werden im zugehörigen Warnziel festgehalten. Bei nicht verfügbarer Regex-Funktion wird die Kandidatenmenge geleert und `UNAVAILABLE_FEATURE` gesetzt. Die OUTPUT-Werte sind kein Nachweis einer atomaren Datenbanksicht.
-- 
-- ## Beispiel
-- 
-- ```sql
-- EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=N'[ExampleDatabase]', @CandidateTable=N'#PrepareDatabaseCandidates_HelpExample', @WarningTable=N'#PrepareDatabaseCandidates_WarningExample', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- monitor.USP_PrepareDatabaseCandidates befüllt lokale Kandidaten- und optionale Warnungstabellen des Aufrufers. Sie liefert keine Analyse-Resultsets und ergänzt vorhandene Zeilen.
-- 
--   STANDARD_CURRENT (leichte Sessions-, Requests-, Blocking-, Wait-, Memory-, TempDB- und I/O-Abfragen)
-- 
--   EXTENDED_CURRENT (gezielte Current-State-Vertiefung mit begrenzter Text-, Plan- und Objektauflösung)
-- 
--   PLAN_CACHE_CURRENT (begrenzte Query-Stats-/Plan-Cache-Auswertung ohne vollständiges XML-Shredding)
-- 
--   SHOWPLAN_TARGETED (gezielte Showplan-Extraktion und XML-Analyse für gefilterte Handles/Hashes)
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.USP_PrepareDatabaseCandidates
-- Version      : 2.0.2
-- Stand        : 2026-10-14
-- Typ          : Öffentlicher Vorbereitungshelfer
-- Zweck        : Validiert die frameworkweite Datenbankauswahl, prüft den
--                tatsächlich aktivierten Analysepfad und befüllt lokale
--                Kandidaten- und Warning-Temp-Tabellen des Aufrufers.
-- Semantik     : Ohne explizite Einschränkung alle sichtbaren, online befindlichen
--                Benutzerdatenbanken. Kein CURRENT-Scope und keine Vorabbegrenzung.
-- High Impact  : Nur eine tatsächlich aktivierte Analyseklasse mit
--                RequiresGroupGate=1 verlangt @HighImpactConfirmed=1.
-- Vertrag      : Die Procedure kennt keine Datenbank-Mengenbegrenzung.
-- ```
-- 
-- ### Weitere bestehende Hilfehinweise
-- 
-- ```text
-- monitor.USP_PrepareDatabaseCandidates befüllt lokale Kandidaten- und optionale Warnungstabellen des Aufrufers. Sie liefert keine Analyse-Resultsets und ergänzt vorhandene Zeilen.
--   STANDARD_CURRENT (leichte Sessions-, Requests-, Blocking-, Wait-, Memory-, TempDB- und I/O-Abfragen)
--   EXTENDED_CURRENT (gezielte Current-State-Vertiefung mit begrenzter Text-, Plan- und Objektauflösung)
--   PLAN_CACHE_CURRENT (begrenzte Query-Stats-/Plan-Cache-Auswertung ohne vollständiges XML-Shredding)
--   SHOWPLAN_TARGETED (gezielte Showplan-Extraktion und XML-Analyse für gefilterte Handles/Hashes)
--   OBJECT_ANALYSIS_CURRENT (gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse)
--   EXTERNAL_RUNTIME_CURRENT (lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer Runtimes)
--   CLR_CURRENT (lesende CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse)
--   MISSING_INDEX_CURRENT (begrenzte flüchtige Missing-Index-Hinweise, keine DDL)
--   STATISTICS_TARGETED (gezielte Statistik-Eigenschaften gefilterter Objekte)
--   COLUMNSTORE_CURRENT (gezielte Columnstore-Rowgroups ohne Segment-/Dictionary-Vollscan)
--   LOCKS_DEEP (detaillierte Locks für relevante Sessions)
--   LOG_VLF_DEEP (datenbankübergreifende VLF-Auswertung)
--   PLAN_CACHE_DEEP (breite Query-Stats-/Plan-Cache-Analyse)
--   SHOWPLAN_XML_DEEP (breite Showplan-XML-Analyse)
--   CATALOG_DEEP (breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse)
--   PHYSICAL_STATS_DEEP (gezielte physische Indexstatistiken im gewählten Modus)
--   INDEX_OPERATIONAL_DEEP (breite kumulative Index-Operational-Stats)
--   QUERY_STORE_CURRENT (gezielte lesende Query-Store-Auswertung mit Zeit-/Zeilenlimit)
--   EXTENDED_EVENTS_CURRENT (Inventar vorhandener XE-Definitionen/laufender Sessions ohne Targets/Historie)
--   QUERY_STORE_DEEP (breite Query-Store-Historie, Regressionen, Planwechsel und Waits)
--   CROSS_DATABASE_DEEP (datenbankübergreifende Inventarisierung und Diagnose)
--   COLUMNSTORE_DEEP (breite Columnstore-Analyse einschließlich Segmenten)
--   EXTENDED_EVENTS_FORENSICS_DEEP (optionale XE-Forensik aus Session/Event-Dateien)
--   SERVER_HEALTH_CURRENT (CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand)
--   SERVER_CONFIGURATION_CURRENT (lesende Serverkonfiguration, Trace Flags und Startparameter)
--   SECURITY_CONFIGURATION_CURRENT (lesende Sicherheits- und Dienstparameter)
--   SQL_AGENT_CURRENT (lesender SQL-Agent-Status, Jobs, Schedules und Historie)
--   RESOURCE_GOVERNOR_CURRENT (lesende Resource-Governor-Konfiguration und Laufzeit)
--   HA_DR_CURRENT (begrenzte lesende HA/DR-, Backup-, Replication-, CDC- und CT-Analyse)
--   ENTERPRISE_TOPOLOGY_DEEP (vertiefte Enterprise-Topologie/Distribution für HA/DR und Replication)
--   DATA_PLATFORM_ADAPTER_CURRENT (optionale angereicherte kundenspezifische Data-Platform-/ETL-Logginganalyse)
-- Beide Tabellen müssen vom Aufrufer angelegt werden. Die Procedure löscht sie im regulären Pfad nicht; wiederverwendete Ziele behalten alte Zeilen. Es gibt keine allgemeine atomare Rücknahme bei späteren Fehlern. Der Regexfilter verarbeitet alle Zeilen der Kandidatentabelle, einschließlich bereits vorhandener Zeilen. Fehlt SQL-Server-Version oder Compatibility Level für Regex, löscht die Procedure vor UNAVAILABLE_FEATURE sämtliche Zeilen aus diesem Ziel.
-- Beispiel: ausführbarer Aufruf mit frischen, korrekt typisierten lokalen Tabellen und synthetischem Datenbanknamen:
-- CREATE TABLE #PrepareDatabaseCandidates_HelpExample (DatabaseId int NOT NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, StateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, UserAccessDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsReadOnly bit NULL, CompatibilityLevel tinyint NULL, CollationName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, RecoveryModelDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsSystemDatabase bit NULL, RequestedOrdinal int NULL);
-- CREATE TABLE #PrepareDatabaseCandidates_WarningExample (RequestedName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
-- DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048), @CrossDatabaseRequested bit;
-- DROP TABLE #PrepareDatabaseCandidates_WarningExample; DROP TABLE #PrepareDatabaseCandidates_HelpExample;
-- Parsergrenzen: PARSENAME-basierte Strukturprüfungen sind keine vollständige SQL-Bezeichnergrammatik und prüfen weder Existenz noch Berechtigungen.
-- ```
-- 
-- USAGE_SKILL_END monitor.USP_PrepareDatabaseCandidates
CREATE OR ALTER PROCEDURE [monitor].[USP_PrepareDatabaseCandidates]
      @DatabaseNames                    nvarchar(max)  = NULL
    , @SystemdatenbankenEinbeziehen     bit            = 0
    , @DatabaseNamePattern              nvarchar(4000) = NULL
    , @AnalysisClass                    varchar(64)    = NULL
    , @HighImpactConfirmed              bit            = 0
    , @StatusCode                       varchar(40)    OUTPUT
    , @ErrorMessage                     nvarchar(2048) OUTPUT
    , @CrossDatabaseRequested           bit            OUTPUT
    , @CandidateTable                   sysname        = N'#PrepareDatabaseCandidates_Result'
    , @WarningTable                     sysname        = NULL
    , @Hilfe                            bit            = 0
AS
BEGIN
    ;

    SET NOCOUNT ON;

    IF @Hilfe = 1
    BEGIN
        PRINT N'monitor.USP_PrepareDatabaseCandidates befüllt lokale Kandidaten- und optionale Warnungstabellen des Aufrufers. Sie liefert keine Analyse-Resultsets und ergänzt vorhandene Zeilen.';
        PRINT N'@DatabaseNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL, leer oder nur Leerzeichen bedeutet nicht angegeben; ausgelassen verwendet NULL. Gültige Namen begrenzen Datenbankauswahl; nicht angegebene Liste bedeutet keine exakte Einschränkung. Ungültiger Name => INVALID_PARAMETER.';
        PRINT N'@SystemdatenbankenEinbeziehen: bit, Default 0. 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL => INVALID_PARAMETER; ausgelassen =0. Bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Wirkt auf Auswahl und SYSTEM_DATABASE_EXCLUDED-Warnung.';
        PRINT N'@DatabaseNamePattern: nvarchar(4000), Default NULL. LIKE-Pattern (%, _, [...]) oder Präfix like:, regex:, regexi:; Präfixerkennung ohne Beachtung der Großschreibung. NULL/ausgelassen = kein Pattern. Äußere Leerzeichen werden entfernt; Inhalt nach Präfixentfernung nicht erneut getrimmt. Leerwert oder leeres Präfixergebnis ungültig; jedes nicht-NULL Pattern zusammen mit wirksamer @DatabaseNames-Liste ungültig. LIKE nutzt SQL_Latin1_General_CP1_CS_AS. Regex-Syntax wird nicht vorgeprüft; regex: Flag c, regexi: Flag i; Ausführung benötigt SQL Server 2025 und Compatibility Level >=170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. Regex filtert nach der Kandidatenermittlung alle Zeilen des Ziels.';
        PRINT N'@AnalysisClass: varchar(64), Default NULL. NULL oder eine leere beziehungsweise nur aus U+0020-Leerzeichen bestehende Zeichenfolge schaltet die optionale Pfadprüfung aus; ausgelassen = NULL. Der Quellcode nutzt NULLIF(@AnalysisClass, ''''); SQLs Auffüllvergleich behandelt eine leere oder nur aus U+0020-Leerzeichen bestehende Zeichenfolge als leer. Es gibt kein explizites Trim; führende Leerzeichen und andere Whitespace-Zeichen werden nicht normalisiert. Sonst einer der 31 Codes: ';
        PRINT N'  STANDARD_CURRENT (leichte Sessions-, Requests-, Blocking-, Wait-, Memory-, TempDB- und I/O-Abfragen)';
        PRINT N'  EXTENDED_CURRENT (gezielte Current-State-Vertiefung mit begrenzter Text-, Plan- und Objektauflösung)';
        PRINT N'  PLAN_CACHE_CURRENT (begrenzte Query-Stats-/Plan-Cache-Auswertung ohne vollständiges XML-Shredding)';
        PRINT N'  SHOWPLAN_TARGETED (gezielte Showplan-Extraktion und XML-Analyse für gefilterte Handles/Hashes)';
        PRINT N'  OBJECT_ANALYSIS_CURRENT (gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse)';
        PRINT N'  EXTERNAL_RUNTIME_CURRENT (lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer Runtimes)';
        PRINT N'  CLR_CURRENT (lesende CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse)';
        PRINT N'  MISSING_INDEX_CURRENT (begrenzte flüchtige Missing-Index-Hinweise, keine DDL)';
        PRINT N'  STATISTICS_TARGETED (gezielte Statistik-Eigenschaften gefilterter Objekte)';
        PRINT N'  COLUMNSTORE_CURRENT (gezielte Columnstore-Rowgroups ohne Segment-/Dictionary-Vollscan)';
        PRINT N'  LOCKS_DEEP (detaillierte Locks für relevante Sessions)';
        PRINT N'  LOG_VLF_DEEP (datenbankübergreifende VLF-Auswertung)';
        PRINT N'  PLAN_CACHE_DEEP (breite Query-Stats-/Plan-Cache-Analyse)';
        PRINT N'  SHOWPLAN_XML_DEEP (breite Showplan-XML-Analyse)';
        PRINT N'  CATALOG_DEEP (breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse)';
        PRINT N'  PHYSICAL_STATS_DEEP (gezielte physische Indexstatistiken im gewählten Modus)';
        PRINT N'  INDEX_OPERATIONAL_DEEP (breite kumulative Index-Operational-Stats)';
        PRINT N'  QUERY_STORE_CURRENT (gezielte lesende Query-Store-Auswertung mit Zeit-/Zeilenlimit)';
        PRINT N'  EXTENDED_EVENTS_CURRENT (Inventar vorhandener XE-Definitionen/laufender Sessions ohne Targets/Historie)';
        PRINT N'  QUERY_STORE_DEEP (breite Query-Store-Historie, Regressionen, Planwechsel und Waits)';
        PRINT N'  CROSS_DATABASE_DEEP (datenbankübergreifende Inventarisierung und Diagnose)';
        PRINT N'  COLUMNSTORE_DEEP (breite Columnstore-Analyse einschließlich Segmenten)';
        PRINT N'  EXTENDED_EVENTS_FORENSICS_DEEP (optionale XE-Forensik aus Session/Event-Dateien)';
        PRINT N'  SERVER_HEALTH_CURRENT (CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand)';
        PRINT N'  SERVER_CONFIGURATION_CURRENT (lesende Serverkonfiguration, Trace Flags und Startparameter)';
        PRINT N'  SECURITY_CONFIGURATION_CURRENT (lesende Sicherheits- und Dienstparameter)';
        PRINT N'  SQL_AGENT_CURRENT (lesender SQL-Agent-Status, Jobs, Schedules und Historie)';
        PRINT N'  RESOURCE_GOVERNOR_CURRENT (lesende Resource-Governor-Konfiguration und Laufzeit)';
        PRINT N'  HA_DR_CURRENT (begrenzte lesende HA/DR-, Backup-, Replication-, CDC- und CT-Analyse)';
        PRINT N'  ENTERPRISE_TOPOLOGY_DEEP (vertiefte Enterprise-Topologie/Distribution für HA/DR und Replication)';
        PRINT N'  DATA_PLATFORM_ADAPTER_CURRENT (optionale angereicherte kundenspezifische Data-Platform-/ETL-Logginganalyse)';
        PRINT N'@AnalysisClass – weitere Regeln: Ein unbekannter Code ergibt INVALID_PARAMETER. InternalCheckAnalysisPath prüft tatsächlichen Katalogeintrag und aktuelle Freigabe. Nur eine aktivierte Klasse mit RequiresGroupGate=1 benötigt @HighImpactConfirmed=1; ein Fehlerstatus beendet vor Kandidatenermittlung.';
        PRINT N'@HighImpactConfirmed: bit, Default 0. 0 bestätigt nicht; 1 bestätigt nur ein Gate der tatsächlich angegebenen aktivierten Klasse. NULL => INVALID_PARAMETER auch ohne Klasse; ausgelassen =0. Bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Ersetzt Klassen- und Freigabeprüfung nicht.';
        PRINT N'@StatusCode: Datentyp varchar(40); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ varchar(40) mit OUTPUT binden, zum Beispiel @StatusCode=@CallerStatusCode OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. AVAILABLE bedeutet, dass die Vorbereitung ohne erkannten Fehler abgeschlossen wurde; es bestätigt nicht, dass jeder angeforderte Name als Kandidat ausgewählt wurde. INVALID_PARAMETER kennzeichnet ungültige Auswahl-/Bestätigungs-/Temp-Tabellenparameter, ungültiges Pattern oder ungültige/duplizierte Namensliste sowie einen unbekannten Analyseklassencode. INTERNAL_ERROR kennzeichnet, dass die Kandidaten-Temp-Tabelle die geprüften erwarteten Spalten DatabaseId und DatabaseName nicht bereitstellt. UNAVAILABLE_FEATURE bedeutet, dass Regex mangels erforderlicher SQL-Server-Version oder Compatibility Level nicht ausgeführt werden kann. Delegiert kann HIGH_IMPACT_CONFIRMATION_REQUIRED bedeuten, dass eine tatsächlich aktivierte Klasse mit RequiresGroupGate=1 nicht mit @HighImpactConfirmed=1 bestätigt wurde; DENIED_GROUP bedeutet, dass die aktuelle Analysepfadfreigabe fehlt. Bei @Hilfe=1 bleibt die Aufrufervariable unverändert.';
        PRINT N'@ErrorMessage: Datentyp nvarchar(2048); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ nvarchar(2048) mit OUTPUT binden, zum Beispiel @ErrorMessage=@CallerErrorMessage OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. Empfängt die Fehlerbeschreibung; bei erfolgreich abgeschlossener Vorbereitung ist der Wert NULL. Bei @Hilfe=1 wird er vor der Rückkehr nicht initialisiert und bleibt unverändert.';
        PRINT N'@CrossDatabaseRequested: bit OUTPUT, ohne Default. Ein Argument ist auch bei Hilfe erforderlich. Für den Empfang eine bit-Variable mit OUTPUT binden; ohne OUTPUT wird der Rückgabewert nicht empfangen. 1 wenn normalisierte exakte Liste fehlt oder mehr als ein gültiges geparstes Element vorliegt, sonst 0. Beschreibt Anfrageform, keine Verfügbarkeit; vor Listenfehlerprüfung ermittelt. Bei Hilfe unverändert.';
        PRINT N'@CandidateTable: sysname, Default #PrepareDatabaseCandidates_Result. Name einer vorhandenen lokalen # Temp-Tabelle derselben Session; kein ##, max. 116 Zeichen. NULL/falscher Präfix/Überlänge => INVALID_PARAMETER. Spalten: DatabaseId int NOT NULL, DatabaseName sysname NOT NULL, StateDesc nvarchar(60) NULL, UserAccessDesc nvarchar(60) NULL, IsReadOnly bit NULL, CompatibilityLevel tinyint NULL, CollationName sysname NULL, RecoveryModelDesc nvarchar(60) NULL, IsSystemDatabase bit NULL, RequestedOrdinal int NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. TOP(0) prüft nur DatabaseId/DatabaseName; spätere Schema-/Insertfehler können entkommen. Hängt Kandidaten an; regulär keine Löschung. Bei nicht verfügbarer Regexfunktion werden vor UNAVAILABLE_FEATURE alle Zielzeilen gelöscht; Regex filtert auch Altzeilen.';
        PRINT N'@WarningTable: sysname, Default NULL; NULL/ausgelassen deaktiviert Warnungen. Sonst vorhandene lokale # Tabelle derselben Session, kein ##, max. 116 Zeichen; falscher Präfix/Überlänge => INVALID_PARAMETER. Spalten RequestedName sysname NULL, StatusCode varchar(40) NULL, ErrorMessage nvarchar(2048) NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. Fehlende explizite Namen erhalten DATABASE_UNAVAILABLE oder SYSTEM_DATABASE_EXCLUDED. Scheiternde TOP(0)-Probe überspringt Tabelle still; späterer Insertfehler kann entkommen. Warnungen werden angehängt; Alt-Kandidaten beeinflussen Fehlend-Erkennung.';
        PRINT N'Beide Tabellen müssen vom Aufrufer angelegt werden. Die Procedure löscht sie im regulären Pfad nicht; wiederverwendete Ziele behalten alte Zeilen. Es gibt keine allgemeine atomare Rücknahme bei späteren Fehlern. Der Regexfilter verarbeitet alle Zeilen der Kandidatentabelle, einschließlich bereits vorhandener Zeilen. Fehlt SQL-Server-Version oder Compatibility Level für Regex, löscht die Procedure vor UNAVAILABLE_FEATURE sämtliche Zeilen aus diesem Ziel.';
        PRINT N'@Hilfe: bit, Default 0. 0 verarbeitet; 1 druckt Hilfe und kehrt vor OUTPUT-Initialisierung und Tabellenverarbeitung zurück; NULL normaler Pfad. Ausgelassen =0; numerisch ungleich 0 wird bit-konvertiert zu 1. Für alle drei OUTPUT-Parameter sind auch bei Hilfe Argumente anzugeben. Für den Empfang Variable mit OUTPUT binden; im Hilfepfad bleiben die übergebenen Eingangswerte unverändert.';
        PRINT N'Beispiel: ausführbarer Aufruf mit frischen, korrekt typisierten lokalen Tabellen und synthetischem Datenbanknamen:';
        PRINT N'CREATE TABLE #PrepareDatabaseCandidates_HelpExample (DatabaseId int NOT NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, StateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, UserAccessDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsReadOnly bit NULL, CompatibilityLevel tinyint NULL, CollationName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, RecoveryModelDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsSystemDatabase bit NULL, RequestedOrdinal int NULL);';
        PRINT N'CREATE TABLE #PrepareDatabaseCandidates_WarningExample (RequestedName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);';
        PRINT N'DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048), @CrossDatabaseRequested bit;';
        PRINT N'EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=N''[ExampleDatabase]'', @CandidateTable=N''#PrepareDatabaseCandidates_HelpExample'', @WarningTable=N''#PrepareDatabaseCandidates_WarningExample'', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT;';
        PRINT N'SELECT @StatusCode AS StatusCode, @ErrorMessage AS ErrorMessage, @CrossDatabaseRequested AS CrossDatabaseRequested;';
        PRINT N'SELECT * FROM #PrepareDatabaseCandidates_HelpExample ORDER BY RequestedOrdinal, DatabaseName;';
        PRINT N'SELECT * FROM #PrepareDatabaseCandidates_WarningExample ORDER BY RequestedName;';
        PRINT N'DROP TABLE #PrepareDatabaseCandidates_WarningExample; DROP TABLE #PrepareDatabaseCandidates_HelpExample;';
        PRINT N'Parsergrenzen: PARSENAME-basierte Strukturprüfungen sind keine vollständige SQL-Bezeichnergrammatik und prüfen weder Existenz noch Berechtigungen.';
        -- USAGE_SKILL_HELP_BEGIN monitor.USP_PrepareDatabaseCandidates
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'USP_PrepareDatabaseCandidates') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.USP_PrepareDatabaseCandidates"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "USP_PrepareDatabaseCandidates"'
            + NCHAR(10)
            + N'object_type: "PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: false'
            + NCHAR(10)
            + N'description: "Validiert die frameworkweite Datenbankauswahl, prüft den tatsächlich aktivierten Analysepfad und befüllt lokale Kandidaten- und Warning-Temp-Tabellen des Aufrufers."'
            + NCHAR(10)
            + N'source_path: "Code/01_Common/083_USP_PrepareDatabaseCandidates.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.USP_PrepareDatabaseCandidates'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Validiert die frameworkweite Datenbankauswahl, prüft den tatsächlich aktivierten Analysepfad und befüllt lokale Kandidaten- und Warning-Temp-Tabellen des Aufrufers.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[USP_PrepareDatabaseCandidates]. Die Quelle nennt insbesondere `[monitor].[TVF_ParseSqlNameList]`, `[sys].[sp_executesql]`, `[monitor].[TVF_ParsePattern]`, `[monitor].[InternalCheckAnalysisPath]`, `[monitor].[TVF_DatabaseCandidates]`, `[master].[sys].[databases]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'| @AnalysisClass | varchar(64) | nein | NULL |'
            + NCHAR(10)
            + N'| @HighImpactConfirmed | bit | nein | 0 |'
            + NCHAR(10)
            + N'| @StatusCode | varchar(40) | ja | kein Default; OUTPUT |'
            + NCHAR(10)
            + N'| @ErrorMessage | nvarchar(2048) | ja | kein Default; OUTPUT |'
            + NCHAR(10)
            + N'| @CrossDatabaseRequested | bit | ja | kein Default; OUTPUT |'
            + NCHAR(10)
            + N'| @CandidateTable | sysname | nein | N''#PrepareDatabaseCandidates_Result'' |'
            + NCHAR(10)
            + N'| @WarningTable | sysname | nein | NULL |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@DatabaseNames:** @DatabaseNames: Datentyp nvarchar(max), Default NULL. Eingabe bracket-aware Pipe-Liste via TVF_ParseSqlNameList/TVF_ParsePipeList: | trennt außerhalb von [...], ]] maskiert ] innen; äußere Elementleerzeichen entfernt. Rohsegment max 4000 UTF-16-Codeeinheiten; leere/fehlerhaft geklammerte Elemente ungültig. Einteiliger PARSENAME-Name, max 128 Zeichen; keine vollständige Bezeichnergrammatik. Case-sensitive Duplikate je FilterType ungültig. NULL, leer oder nur Leerzeichen bedeutet nicht angegeben; ausgelassen verwendet NULL. Gültige Namen begrenzen Datenbankauswahl; nicht angegebene Liste bedeutet keine exakte Einschränkung. Ungültiger Name => INVALID_PARAMETER.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SystemdatenbankenEinbeziehen:** @SystemdatenbankenEinbeziehen: bit, Default 0. 0 schließt master, tempdb, model und msdb aus; 1 lässt sie zu. NULL => INVALID_PARAMETER; ausgelassen =0. Bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Wirkt auf Auswahl und SYSTEM_DATABASE_EXCLUDED-Warnung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@DatabaseNamePattern:** @DatabaseNamePattern: nvarchar(4000), Default NULL. LIKE-Pattern (%, _, [...]) oder Präfix like:, regex:, regexi:; Präfixerkennung ohne Beachtung der Großschreibung. NULL/ausgelassen = kein Pattern. Äußere Leerzeichen werden entfernt; Inhalt nach Präfixentfernung nicht erneut getrimmt. Leerwert oder leeres Präfixergebnis ungültig; jedes nicht-NULL Pattern zusammen mit wirksamer @DatabaseNames-Liste ungültig. LIKE nutzt SQL_Latin1_General_CP1_CS_AS. Regex-Syntax wird nicht vorgeprüft; regex: Flag c, regexi: Flag i; Ausführung benötigt SQL Server 2025 und Compatibility Level >=170 der Installationsdatenbank, sonst UNAVAILABLE_FEATURE. Regex filtert nach der Kandidatenermittlung alle Zeilen des Ziels.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@AnalysisClass:** @AnalysisClass: varchar(64), Default NULL. NULL oder eine leere beziehungsweise nur aus U+0020-Leerzeichen bestehende Zeichenfolge schaltet die optionale Pfadprüfung aus; ausgelassen = NULL. Der Quellcode nutzt NULLIF(@AnalysisClass, ''''); SQLs Auffüllvergleich behandelt eine leere oder nur aus U+0020-Leerzeichen bestehende Zeichenfolge als leer. Es gibt kein explizites Trim; führende Leerzeichen und andere Whitespace-Zeichen werden nicht normalisiert. Sonst einer der 31 Codes: '
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed: bit, Default 0. 0 bestätigt nicht; 1 bestätigt nur ein Gate der tatsächlich angegebenen aktivierten Klasse. NULL => INVALID_PARAMETER auch ohne Klasse; ausgelassen =0. Bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab. Ersetzt Klassen- und Freigabeprüfung nicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCode:** @StatusCode: Datentyp varchar(40); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ varchar(40) mit OUTPUT binden, zum Beispiel @StatusCode=@CallerStatusCode OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. AVAILABLE bedeutet, dass die Vorbereitung ohne erkannten Fehler abgeschlossen wurde; es bestätigt nicht, dass jeder angeforderte Name als Kandidat ausgewählt wurde. INVALID_PARAMETER kennzeichnet ungültige Auswahl-/Bestätigungs-/Temp-Tabellenparameter, ungültiges Pattern oder ungültige/duplizierte Namensliste sowie einen unbekannten Analyseklassencode. INTERNAL_ERROR kennzeichnet, dass die Kandidaten-Temp-Tabelle die geprüften erwarteten Spalten DatabaseId und DatabaseName nicht bereitstellt. UNAVAILABLE_FEATURE bedeutet, dass Regex mangels erforderlicher SQL-Server-Version oder Compatibility Level nicht ausgeführt werden kann. Delegiert kann HIGH_IMPAC'
            + N'T_CONFIRMATION_REQUIRED bedeuten, dass eine tatsächlich aktivierte Klasse mit RequiresGroupGate=1 nicht mit @HighImpactConfirmed=1 bestätigt wurde; DENIED_GROUP bedeutet, dass die aktuelle Analysepfadfreigabe fehlt. Bei @Hilfe=1 bleibt die Aufrufervariable unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessage:** @ErrorMessage: Datentyp nvarchar(2048); OUTPUT, ohne Default. Ein Argument ist auch bei @Hilfe=1 erforderlich, da kein Default existiert. Für den Empfang eine Aufrufervariable vom Typ nvarchar(2048) mit OUTPUT binden, zum Beispiel @ErrorMessage=@CallerErrorMessage OUTPUT. Ohne OUTPUT am Aufruf wird der Rückgabewert nicht empfangen. Empfängt die Fehlerbeschreibung; bei erfolgreich abgeschlossener Vorbereitung ist der Wert NULL. Bei @Hilfe=1 wird er vor der Rückkehr nicht initialisiert und bleibt unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CrossDatabaseRequested:** @CrossDatabaseRequested: bit OUTPUT, ohne Default. Ein Argument ist auch bei Hilfe erforderlich. Für den Empfang eine bit-Variable mit OUTPUT binden; ohne OUTPUT wird der Rückgabewert nicht empfangen. 1 wenn normalisierte exakte Liste fehlt oder mehr als ein gültiges geparstes Element vorliegt, sonst 0. Beschreibt Anfrageform, keine Verfügbarkeit; vor Listenfehlerprüfung ermittelt. Bei Hilfe unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CandidateTable:** @CandidateTable: sysname, Default #PrepareDatabaseCandidates_Result. Name einer vorhandenen lokalen # Temp-Tabelle derselben Session; kein ##, max. 116 Zeichen. NULL/falscher Präfix/Überlänge => INVALID_PARAMETER. Spalten: DatabaseId int NOT NULL, DatabaseName sysname NOT NULL, StateDesc nvarchar(60) NULL, UserAccessDesc nvarchar(60) NULL, IsReadOnly bit NULL, CompatibilityLevel tinyint NULL, CollationName sysname NULL, RecoveryModelDesc nvarchar(60) NULL, IsSystemDatabase bit NULL, RequestedOrdinal int NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. TOP(0) prüft nur DatabaseId/DatabaseName; spätere Schema-/Insertfehler können entkommen. Hängt Kandidaten an; regulär keine Löschung. Bei nicht verfügbarer Regexfunktion werden vor UNAVAILABLE_FEATURE alle Zielzeilen gelöscht; Regex filtert auch Altzeilen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@WarningTable:** @WarningTable: sysname, Default NULL; NULL/ausgelassen deaktiviert Warnungen. Sonst vorhandene lokale # Tabelle derselben Session, kein ##, max. 116 Zeichen; falscher Präfix/Überlänge => INVALID_PARAMETER. Spalten RequestedName sysname NULL, StatusCode varchar(40) NULL, ErrorMessage nvarchar(2048) NULL; Textcollation SQL_Latin1_General_CP1_CS_AS. Fehlende explizite Namen erhalten DATABASE_UNAVAILABLE oder SYSTEM_DATABASE_EXCLUDED. Scheiternde TOP(0)-Probe überspringt Tabelle still; späterer Insertfehler kann entkommen. Warnungen werden angehängt; Alt-Kandidaten beeinflussen Fehlend-Erkennung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** @Hilfe: bit, Default 0. 0 verarbeitet; 1 druckt Hilfe und kehrt vor OUTPUT-Initialisierung und Tabellenverarbeitung zurück; NULL normaler Pfad. Ausgelassen =0; numerisch ungleich 0 wird bit-konvertiert zu 1. Für alle drei OUTPUT-Parameter sind auch bei Hilfe Argumente anzugeben. Für den Empfang Variable mit OUTPUT binden; im Hilfepfad bleiben die übergebenen Eingangswerte unverändert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. Die Procedure füllt die vom Aufrufer benannte Kandidaten-Temp-Tabelle und meldet `@StatusCode varchar(40)`, `@ErrorMessage nvarchar(2048)` und `@CrossDatabaseRequested bit` per OUTPUT. Normale Kandidaten sind sichtbare, online und zugängliche Datenbanken; ausgeschlossene oder nicht auffindbare angeforderte Namen werden im zugehörigen Warnziel festgehalten. Bei nicht verfügbarer Regex-Funktion wird die Kandidatenmenge geleert und `UNAVAILABLE_FEATURE` gesetzt. Die OUTPUT-Werte sind kein Nachweis einer atomaren Datenbanksicht.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=N''[ExampleDatabase]'', @CandidateTable=N''#PrepareDatabaseCandidates_HelpExample'', @WarningTable=N''#PrepareDatabaseCandidates_WarningExample'', @StatusCode=@StatusCode OUTPUT, @ErrorMessage=@ErrorMessage OUTPUT, @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'monitor.USP_PrepareDatabaseCandidates befüllt lokale Kandidaten- und optionale Warnungstabellen des Aufrufers. Sie liefert keine Analyse-Resultsets und ergänzt vorhandene Zeilen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'  STANDARD_CURRENT (leichte Sessions-, Requests-, Blocking-, Wait-, Memory-, TempDB- und I/O-Abfragen)'
            + NCHAR(10)
            + NCHAR(10)
            + N'  EXTENDED_CURRENT (gezielte Current-State-Vertiefung mit begrenzter Text-, Plan- und Objektauflösung)'
            + NCHAR(10)
            + NCHAR(10)
            + N'  PLAN_CACHE_CURRENT (begrenzte Query-Stats-/Plan-Cache-Auswertung ohne vollständiges XML-Shredding)'
            + NCHAR(10)
            + NCHAR(10)
            + N'  SHOWPLAN_TARGETED (gezielte Showplan-Extraktion und XML-Analyse für gefilterte Handles/Hashes)'
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
            + N'Objekt       : monitor.USP_PrepareDatabaseCandidates'
            + NCHAR(10)
            + N'Version      : 2.0.2'
            + NCHAR(10)
            + N'Stand        : 2026-10-14'
            + NCHAR(10)
            + N'Typ          : Öffentlicher Vorbereitungshelfer'
            + NCHAR(10)
            + N'Zweck        : Validiert die frameworkweite Datenbankauswahl, prüft den'
            + NCHAR(10)
            + N'               tatsächlich aktivierten Analysepfad und befüllt lokale'
            + NCHAR(10)
            + N'               Kandidaten- und Warning-Temp-Tabellen des Aufrufers.'
            + NCHAR(10)
            + N'Semantik     : Ohne explizite Einschränkung alle sichtbaren, online befindlichen'
            + NCHAR(10)
            + N'               Benutzerdatenbanken. Kein CURRENT-Scope und keine Vorabbegrenzung.'
            + NCHAR(10)
            + N'High Impact  : Nur eine tatsächlich aktivierte Analyseklasse mit'
            + NCHAR(10)
            + N'               RequiresGroupGate=1 verlangt @HighImpactConfirmed=1.'
            + NCHAR(10)
            + N'Vertrag      : Die Procedure kennt keine Datenbank-Mengenbegrenzung.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'### Weitere bestehende Hilfehinweise'
            + NCHAR(10)
            + NCHAR(10)
            + N'```text'
            + NCHAR(10)
            + N'monitor.USP_PrepareDatabaseCandidates befüllt lokale Kandidaten- und optionale Warnungstabellen des Aufrufers. Sie liefert keine Analyse-Resultsets und ergänzt vorhandene Zeilen.'
            + NCHAR(10)
            + N'  STANDARD_CURRENT (leichte Sessions-, Requests-, Blocking-, Wait-, Memory-, TempDB- und I/O-Abfragen)'
            + NCHAR(10)
            + N'  EXTENDED_CURRENT (gezielte Current-State-Vertiefung mit begrenzter Text-, Plan- und Objektauflösung)'
            + NCHAR(10)
            + N'  PLAN_CACHE_CURRENT (begrenzte Query-Stats-/Plan-Cache-Auswertung ohne vollständiges XML-Shredding)'
            + NCHAR(10)
            + N'  SHOWPLAN_TARGETED (gezielte Showplan-Extraktion und XML-Analyse für gefilterte Handles/Hashes)'
            + NCHAR(10)
            + N'  OBJECT_ANALYSIS_CURRENT (gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse)'
            + NCHAR(10)
            + N'  EXTERNAL_RUNTIME_CURRENT (lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer Runtimes)'
            + NCHAR(10)
            + N'  CLR_CURRENT (lesende CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse)'
            + NCHAR(10)
            + N'  MISSING_INDEX_CURRENT (begrenzte flüchtige Missing-Index-Hinweise, keine DDL)'
            + NCHAR(10)
            + N'  STATISTICS_TARGETED (gezielte Statistik-Eigenschaften gefilterter Objekte)'
            + NCHAR(10)
            + N'  COLUMNSTORE_CURRENT (gezielte Columnstore-Rowgroups ohne Segment-/Dictionary-Vollscan)'
            + NCHAR(10)
            + N'  LOCKS_DEEP (detaillierte Locks für relevante Sessions)'
            + NCHAR(10)
            + N'  LOG_VLF_DEEP (datenbankübergreifende VLF-Auswertung)'
            + NCHAR(10)
            + N'  PLAN_CACHE_DEEP (breite Query-Stats-/Plan-Cache-Analyse)'
            + NCHAR(10)
            + N'  SHOWPLAN_XML_DEEP (breite Showplan-XML-Analyse)'
            + NCHAR(10)
            + N'  CATALOG_DEEP (breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse)'
            + NCHAR(10)
            + N'  PHYSICAL_STATS_DEEP (gezielte physische Indexstatistiken im gewählten Modus)'
            + NCHAR(10)
            + N'  INDEX_OPERATIONAL_DEEP (breite kumulative Index-Operational-Stats)'
            + NCHAR(10)
            + N'  QUERY_STORE_CURRENT (gezielte lesende Query-Store-Auswertung mit Zeit-/Zeilenlimit)'
            + NCHAR(10)
            + N'  EXTENDED_EVENTS_CURRENT (Inventar vorhandener XE-Definitionen/laufender Sessions ohne Targets/Historie)'
            + NCHAR(10)
            + N'  QUERY_STORE_DEEP (breite Query-Store-Historie, Regressionen, Planwechsel und Waits)'
            + NCHAR(10)
            + N'  CROSS_DATABASE_DEEP (datenbankübergreifende Inventarisierung und Diagnose)'
            + NCHAR(10)
            + N'  COLUMNSTORE_DEEP (breite Columnstore-Analyse einschließlich Segmenten)'
            + NCHAR(10)
            + N'  EXTENDED_EVENTS_FORENSICS_DEEP (optionale XE-Forensik aus Session/Event-Dateien)'
            + NCHAR(10)
            + N'  SERVER_HEALTH_CURRENT (CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand)'
            + NCHAR(10)
            + N'  SERVER_CONFIGURATION_CURRENT (lesende Serverkonfiguration, Trace Flags und Startparameter)'
            + NCHAR(10)
            + N'  SECURITY_CONFIGURATION_CURRENT (lesende Sicherheits- und Dienstparameter)'
            + NCHAR(10)
            + N'  SQL_AGENT_CURRENT (lesender SQL-Agent-Status, Jobs, Schedules und Historie)'
            + NCHAR(10)
            + N'  RESOURCE_GOVERNOR_CURRENT (lesende Resource-Governor-Konfiguration und Laufzeit)'
            + NCHAR(10)
            + N'  HA_DR_CURRENT (begrenzte lesende HA/DR-, Backup-, Replication-, CDC- und CT-Analyse)'
            + NCHAR(10)
            + N'  ENTERPRISE_TOPOLOGY_DEEP (vertiefte Enterprise-Topologie/Distribution für HA/DR und Replication)'
            + NCHAR(10)
            + N'  DATA_PLATFORM_ADAPTER_CURRENT (optionale angereicherte kundenspezifische Data-Platform-/ETL-Logginganalyse)'
            + NCHAR(10)
            + N'Beide Tabellen müssen vom Aufrufer angelegt werden. Die Procedure löscht sie im regulären Pfad nicht; wiederverwendete Ziele behalten alte Zeilen. Es gibt keine allgemeine atomare Rücknahme bei späteren Fehlern. Der Regexfilter verarbeitet alle Zeilen der Kandidatentabelle, einschließlich bereits vorhandener Zeilen. Fehlt SQL-Server-Version oder Compatibility Level für Regex, löscht die Procedure vor UNAVAILABLE_FEATURE sämtliche Zeilen aus diesem Ziel.'
            + NCHAR(10)
            + N'Beispiel: ausführbarer Aufruf mit frischen, korrekt typisierten lokalen Tabellen und synthetischem Datenbanknamen:'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE #PrepareDatabaseCandidates_HelpExample (DatabaseId int NOT NULL, DatabaseName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL, StateDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, UserAccessDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsReadOnly bit NULL, CompatibilityLevel tinyint NULL, CollationName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, RecoveryModelDesc nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, IsSystemDatabase bit NULL, RequestedOrdinal int NULL);'
            + NCHAR(10)
            + N'C'
            + N'REATE TABLE #PrepareDatabaseCandidates_WarningExample (RequestedName sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL, StatusCode varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL, ErrorMessage nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL);'
            + NCHAR(10)
            + N'DECLARE @StatusCode varchar(40), @ErrorMessage nvarchar(2048), @CrossDatabaseRequested bit;'
            + NCHAR(10)
            + N'DROP TABLE #PrepareDatabaseCandidates_WarningExample; DROP TABLE #PrepareDatabaseCandidates_HelpExample;'
            + NCHAR(10)
            + N'Parsergrenzen: PARSENAME-basierte Strukturprüfungen sind keine vollständige SQL-Bezeichnergrammatik und prüfen weder Existenz noch Berechtigungen.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.USP_PrepareDatabaseCandidates
        RETURN;
    END

    SET LOCK_TIMEOUT 0;

    SELECT
          @StatusCode = 'AVAILABLE'
        , @ErrorMessage = NULL
        , @CrossDatabaseRequested = 0;

    DECLARE @EffectiveDatabaseNames nvarchar(max) =
        CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames, N''))), N'') IS NULL
             THEN NULL ELSE @DatabaseNames END;
    DECLARE @PatternMode varchar(8);
    DECLARE @PatternValue nvarchar(4000);
    DECLARE @RegexFlags varchar(8);
    DECLARE @PatternIsValid bit;
    DECLARE @DatabaseListCount int = 0;
    DECLARE @Sql nvarchar(max);
    DECLARE @CandidateTableQuoted nvarchar(258);
    DECLARE @WarningTableQuoted nvarchar(258);

    IF @SystemdatenbankenEinbeziehen IS NULL
       OR @SystemdatenbankenEinbeziehen NOT IN (0,1)
       OR @HighImpactConfirmed IS NULL
       OR @HighImpactConfirmed NOT IN (0,1)
       OR @CandidateTable IS NULL
       OR LEFT(@CandidateTable,1) <> N'#'
       OR LEFT(@CandidateTable,2) = N'##'
       OR LEN(@CandidateTable) > 116
       OR
       (
           @WarningTable IS NOT NULL
           AND
           (
               LEFT(@WarningTable,1) <> N'#'
               OR LEFT(@WarningTable,2) = N'##'
               OR LEN(@WarningTable) > 116
           )
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültige Auswahl-, Bestätigungs- oder interne Temp-Tabellenparameter.';
        RETURN;
    END;

    SELECT
          @CandidateTableQuoted = QUOTENAME(@CandidateTable)
        , @WarningTableQuoted = QUOTENAME(@WarningTable);

    -- Ausschließlich eigene Temp-Anlagen dürfen je Statement bis zu 100 ms
    -- auf eine Sperre warten. Fachliche Zugriffe bleiben anschließend NOWAIT.
    BEGIN TRY
    SET LOCK_TIMEOUT 100;
    CREATE TABLE [#PrepareDatabaseCandidates_Work]
    (
          [DatabaseId] int NOT NULL
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

    CREATE TABLE [#PrepareDatabaseCandidates_RequestedNames]
    (
          [NameValue] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [IsValid] bit NOT NULL
    );
    SET LOCK_TIMEOUT 0;
    END TRY
    BEGIN CATCH
        SET LOCK_TIMEOUT 0;
        THROW;
    END CATCH;

    IF @EffectiveDatabaseNames IS NOT NULL
        INSERT [#PrepareDatabaseCandidates_RequestedNames]([NameValue],[IsValid])
        SELECT [NameValue],[IsValid]
        FROM [monitor].[TVF_ParseSqlNameList](@EffectiveDatabaseNames);

    BEGIN TRY
        SET @Sql = N'DECLARE @DatabaseId int,@DatabaseName sysname;
SELECT TOP (0) @DatabaseId=[DatabaseId],@DatabaseName=[DatabaseName]
FROM ' + @CandidateTableQuoted + N';';
        EXEC [sys].[sp_executesql] @Sql;
    END TRY
    BEGIN CATCH
        SET @StatusCode = 'INTERNAL_ERROR';
        SET @ErrorMessage = N'Die Kandidaten-Temp-Tabelle wurde nicht mit dem erwarteten Schema angelegt.';
        RETURN;
    END CATCH;

    SELECT
          @PatternMode = [PatternMode]
        , @PatternValue = [PatternValue]
        , @RegexFlags = [RegexFlags]
        , @PatternIsValid = [IsValid]
    FROM [monitor].[TVF_ParsePattern](@DatabaseNamePattern);

    IF @EffectiveDatabaseNames IS NOT NULL
        SELECT @DatabaseListCount = COUNT(*)
        FROM [#PrepareDatabaseCandidates_RequestedNames]
        WHERE [IsValid] = 1;

    SET @CrossDatabaseRequested = CONVERT
    (
        bit,
        CASE WHEN @EffectiveDatabaseNames IS NULL OR @DatabaseListCount > 1
             THEN 1 ELSE 0 END
    );

    IF @PatternIsValid = 0
       OR
       (
           @EffectiveDatabaseNames IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM [#PrepareDatabaseCandidates_RequestedNames]
               WHERE [IsValid] = 0
           )
       )
       OR (@EffectiveDatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL)
       OR
       (
           @EffectiveDatabaseNames IS NOT NULL
           AND EXISTS
           (
               SELECT [NameValue]
               FROM [#PrepareDatabaseCandidates_RequestedNames]
               WHERE [IsValid] = 1
               GROUP BY [NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
               HAVING COUNT(*) > 1
           )
       )
    BEGIN
        SET @StatusCode = 'INVALID_PARAMETER';
        SET @ErrorMessage = N'Ungültige oder doppelte Datenbankliste beziehungsweise ungültiges Pattern. Exakte Liste und Pattern sind gegenseitig exklusiv.';
        RETURN;
    END;

    IF NULLIF(@AnalysisClass, '') IS NOT NULL
    BEGIN
        EXEC [monitor].[InternalCheckAnalysisPath]
              @AnalysisClass=@AnalysisClass
            , @HighImpactConfirmed=@HighImpactConfirmed
            , @StatusCode=@StatusCode OUTPUT
            , @ErrorMessage=@ErrorMessage OUTPUT;

        IF @StatusCode<>'AVAILABLE'
            RETURN;
    END;

    INSERT [#PrepareDatabaseCandidates_Work]
    (
          [DatabaseId],[DatabaseName],[StateDesc],[UserAccessDesc],[IsReadOnly]
        , [CompatibilityLevel],[CollationName],[RecoveryModelDesc]
        , [IsSystemDatabase],[RequestedOrdinal]
    )
    SELECT
          [DatabaseId],[DatabaseName],[StateDesc],[UserAccessDesc],[IsReadOnly]
        , [CompatibilityLevel],[CollationName],[RecoveryModelDesc]
        , [IsSystemDatabase],[RequestedOrdinal]
    FROM [monitor].[TVF_DatabaseCandidates]
    (
          @EffectiveDatabaseNames
        , @SystemdatenbankenEinbeziehen
        , @DatabaseNamePattern
    );

    SET @Sql = N'INSERT ' + @CandidateTableQuoted + N'
(
      [DatabaseId],[DatabaseName],[StateDesc],[UserAccessDesc],[IsReadOnly]
    , [CompatibilityLevel],[CollationName],[RecoveryModelDesc]
    , [IsSystemDatabase],[RequestedOrdinal]
)
SELECT
      [DatabaseId],[DatabaseName],[StateDesc],[UserAccessDesc],[IsReadOnly]
    , [CompatibilityLevel],[CollationName],[RecoveryModelDesc]
    , [IsSystemDatabase],[RequestedOrdinal]
FROM [#PrepareDatabaseCandidates_Work];';
    EXEC [sys].[sp_executesql] @Sql;

    DECLARE @WarningTableAvailable bit = 0;
    IF @WarningTable IS NOT NULL
    BEGIN
        BEGIN TRY
            SET @Sql = N'DECLARE @RequestedName sysname,@WarningStatus varchar(40),@WarningError nvarchar(2048);
SELECT TOP (0) @RequestedName=[RequestedName],@WarningStatus=[StatusCode],@WarningError=[ErrorMessage]
FROM ' + @WarningTableQuoted + N';';
            EXEC [sys].[sp_executesql] @Sql;
            SET @WarningTableAvailable = 1;
        END TRY
        BEGIN CATCH
            SET @WarningTableAvailable = 0;
        END CATCH;
    END;

    IF @WarningTableAvailable = 1 AND @EffectiveDatabaseNames IS NOT NULL
    BEGIN
        SET @Sql = N'INSERT ' + @WarningTableQuoted + N' ([RequestedName],[StatusCode],[ErrorMessage])
SELECT
      [n].[NameValue]
    , CASE
          WHEN @IncludeSystem = 0
           AND [n].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
               IN (N''master'',N''tempdb'',N''model'',N''msdb'')
              THEN ''SYSTEM_DATABASE_EXCLUDED''
          ELSE ''DATABASE_UNAVAILABLE''
      END
    , CASE
          WHEN @IncludeSystem = 0
           AND [n].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
               IN (N''master'',N''tempdb'',N''model'',N''msdb'')
              THEN N''Die explizit angeforderte Systemdatenbank ist ohne Opt-in ausgeschlossen.''
          ELSE N''Die explizit angeforderte Datenbank ist nicht vorhanden, nicht online oder für den aktuellen Login nicht zugreifbar.''
      END
FROM [#PrepareDatabaseCandidates_RequestedNames] AS [n]
WHERE [n].[IsValid] = 1
  AND NOT EXISTS
      (
          SELECT 1
          FROM ' + @CandidateTableQuoted + N' AS [c]
          WHERE [c].[DatabaseName] COLLATE SQL_Latin1_General_CP1_CS_AS
              = [n].[NameValue] COLLATE SQL_Latin1_General_CP1_CS_AS
      );';

        EXEC [sys].[sp_executesql]
              @Sql
            , N'@IncludeSystem bit'
            , @IncludeSystem = @SystemdatenbankenEinbeziehen;
    END;

    IF @PatternMode IN ('REGEX', 'REGEXI')
    BEGIN
        IF TRY_CONVERT(int, SERVERPROPERTY(N'ProductMajorVersion')) < 17
           OR NOT EXISTS
              (
                  SELECT 1
                  FROM [master].[sys].[databases] AS [d] WITH (NOLOCK)
                  WHERE [d].[database_id] = DB_ID()
                    AND [d].[compatibility_level] >= 170
              )
        BEGIN
            SET @Sql = N'DELETE FROM ' + @CandidateTableQuoted + N';';
            EXEC [sys].[sp_executesql] @Sql;
            SET @StatusCode = 'UNAVAILABLE_FEATURE';
            SET @ErrorMessage = N'Regex benötigt SQL Server 2025 und Compatibility Level 170 für die Installationsdatenbank.';
            RETURN;
        END;

        SET @Sql = N'DELETE [c]
FROM ' + @CandidateTableQuoted + N' AS [c]
WHERE NOT REGEXP_LIKE([c].[DatabaseName], @Pattern, @Flags);';

        EXEC [sys].[sp_executesql]
              @Sql
            , N'@Pattern nvarchar(4000), @Flags varchar(8)'
            , @Pattern = @PatternValue
            , @Flags = @RegexFlags;
    END;
END;
GO
