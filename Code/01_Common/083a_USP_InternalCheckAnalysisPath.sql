USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.InternalCheckAnalysisPath
Version      : 1.1.0
Stand        : 2026-07-21
Typ          : Interne Stored Procedure
Zweck        : Prüft vor fachlichen DMV-, Cache-, Query-Store- oder
               Katalogzugriffen die einzelne Analyseklasse, erforderliche
               High-Impact-Bestätigung und den aktuell ausgewerteten
               Freigabepfad. Die Prüfung liest zuerst die Framework-Views
               VW_AnalyseClassCatalog und VW_AnalyseAccessCurrent.
Eingabe      :
  @AnalysisClass varchar(64), Default: kein Default; obligatorisch.
               Ein einzelner Katalogcode, keine Liste und kein Pattern.
               NULL und '' sind ungültig. Es erfolgt keine ausdrückliche
               Leerzeichenentfernung oder Groß-/Kleinschreibungsnormalisierung;
               Vergleiche folgen der Datenbankkollation, die nicht zwingend
               binär oder case-insensitive ist. Die gültigen Codes dieser
               ausgelieferten Katalogfassung 1.9.0 sind abschließend:
               STANDARD_CURRENT (STANDARD, RequiresGroupGate=0): Leichtgewichtige Current-State-Abfragen für Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O.
               EXTENDED_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Current-State-Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung.
               PLAN_CACHE_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte Query-Stats- und Plan-Cache-Auswertungen ohne vollständiges XML-Shredding.
               SHOWPLAN_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Showplan-Extraktion und XML-Analyse für konkret gefilterte Planhandles oder Query Hashes.
               OBJECT_ANALYSIS_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank.
               EXTERNAL_RUNTIME_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer SQL-Server-Runtimes ohne Testausführung.
               CLR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse ohne Assemblyausführung.
               MISSING_INDEX_CURRENT (ERWEITERT, RequiresGroupGate=0): Flüchtige Missing-Index-Hinweise mit begrenzter Ergebnismenge; keine automatische DDL-Ausführung.
               STATISTICS_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Statistik-Eigenschaftsanalyse für gefilterte Objekte.
               COLUMNSTORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Columnstore-Rowgroup-Analyse über Katalogsicht ohne Segment-/Dictionary-Vollscan.
               LOCKS_DEEP (DEEP, RequiresGroupGate=1): Detaillierte Materialisierung von sys.dm_tran_locks für die aktuell relevante Sessionmenge.
               LOG_VLF_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende VLF-Auswertung über sys.dm_db_log_info.
               PLAN_CACHE_DEEP (DEEP, RequiresGroupGate=1): Breite oder vollständige Analyse von Query Stats und Plan Cache.
               SHOWPLAN_XML_DEEP (DEEP, RequiresGroupGate=1): XML-Analyse gecachter oder aktueller Showplans einschließlich Warnings, Spills, Objekten und Statistiken.
               CATALOG_DEEP (DEEP, RequiresGroupGate=1): Breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse.
               PHYSICAL_STATS_DEEP (DEEP, RequiresGroupGate=1): Explizite Auswertung von sys.dm_db_index_physical_stats in einem bewusst gewählten Modus.
               INDEX_OPERATIONAL_DEEP (DEEP, RequiresGroupGate=1): Breite kumulative Index-Operational-Stats mit Lock-, Latch-, I/O-Latch- und Page-Split-Zählern.
               QUERY_STORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan- und Force-Auswertung mit engem Zeit- und Zeilenlimit.
               EXTENDED_EVENTS_CURRENT (ERWEITERT, RequiresGroupGate=0): Leichte Inventarisierung vorhandener Extended-Events-Definitionen und laufender Sessions ohne Targetdaten oder Eventhistorie.
               QUERY_STORE_DEEP (DEEP, RequiresGroupGate=1): Breite Query-Store-Historie, Regressionen, Planwechsel und Wait-Auswertungen.
               CROSS_DATABASE_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende Inventarisierung und Diagnose.
               COLUMNSTORE_DEEP (DEEP, RequiresGroupGate=1): Breite Columnstore-Analyse einschließlich Rowgroups, Deleted Rows, Dictionaries und Segmenten.
               EXTENDED_EVENTS_FORENSICS_DEEP (FORENSIK, RequiresGroupGate=1): Optionale Auswertung vorhandener Extended-Events-Sessions und Event-Dateien; niemals Primärquelle des Standardlaufs.
               SERVER_HEALTH_CURRENT (ERWEITERT, RequiresGroupGate=0): CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der aktuellen Instanz.
               SERVER_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Serverkonfiguration, Trace Flags und Startup-Parameter.
               SECURITY_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende sicherheits- und dienstbezogene Betriebsparameter.
               SQL_AGENT_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-Server-Agent-Status-, Job-, Schedule- und Historienanalyse aus msdb.
               RESOURCE_GOVERNOR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Resource-Governor-Konfigurations- und Laufzeitanalyse.
               HA_DR_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte lesende Analyse von Availability Groups, Backup, Log Shipping, Replication, CDC und Change Tracking.
               ENTERPRISE_TOPOLOGY_DEEP (DEEP, RequiresGroupGate=1): Vertiefte enterpriseweite Topologie- und Distribution-Analyse für HA/DR und Replication.
               DATA_PLATFORM_ADAPTER_CURRENT (ERWEITERT, RequiresGroupGate=0): Optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Loggingobjekten mit isolierter Existenz- und Rechteprüfung.
               Die Katalog-DefaultMaxRows- und DefaultTimeoutSeconds-Werte
               sind Hinweise der Katalogzeilen und werden von dieser Prüfung
               nicht erzwungen.
  @HighImpactConfirmed bit, Default: kein Default; obligatorisch.
               1 bestätigt die angeforderte High-Impact-Ausführung; 0
               bestätigt sie nicht und ist bei RequiresGroupGate=1 unzulässig.
               NULL ist ungültig; ein Leerwert ist für bit nicht unterstützt.
               Die Bestätigung ist auch bei sysadmin oder offener Policy
               erforderlich. Ihr Fehlen wird vor DENIED_GROUP gemeldet.
  @StatusCode varchar(40) OUTPUT, Default: kein Default; obligatorisches
               Argument. Eingehendes NULL, Leertext und andere Werte werden auf AVAILABLE
               zurückgesetzt und bei behandeltem Ergebnis auf genau einen
               Status gesetzt: AVAILABLE (Klasse und Gateprüfung bestanden),
               INVALID_PARAMETER (@AnalysisClass ist NULL, leer oder unbekannt
               oder @HighImpactConfirmed ist ungültig), HIGH_IMPACT_CONFIRMATION_REQUIRED
               (erforderliche Bestätigung fehlt), DENIED_GROUP (Gruppenpfad
               nicht freigegeben). Eine aufrufende Variable mit passendem
               Typ ist zum Empfangen erforderlich; ohne OUTPUT beim Aufruf
               kann der Wert verworfen werden.
  @ErrorMessage nvarchar(2048) OUTPUT, Default: kein Default; obligatorisches
               Argument. Der Eingabewert wird sofort auf NULL zurückgesetzt;
               bei behandeltem Fehler enthält er den zugehörigen Text, bei
               AVAILABLE bleibt er NULL. Der anfängliche NULL- oder Leerwert
               wird ignoriert. Eine aufrufende Variable mit passendem Typ ist
               zum Empfangen erforderlich; ohne OUTPUT beim Aufruf kann der
               Wert verworfen werden.
Aufruf        : Alle vier Argumente müssen beim EXEC angegeben werden.
               Ausgelassene Pflichtargumente verursachen einen Aufruffehler,
               bevor diese Procedure einen Status setzen kann.
               OUTPUT-Argumente dürfen ohne das Schlüsselwort OUTPUT
               übergeben werden, wenn ihr Ergebnis verworfen wird.
Fehler        : Nur Fehlernummern 229, 371 und 916 beim initialen Zugriff auf
               die Framework-Views lösen den Datenbank-only-Fallback aus.
               Andere Fehler werden erneut ausgelöst. Auch Unterabfragen des
               Fallbacks können fehlschlagen. Es wird keine Zusage gemacht,
               native Fehler in Statuswerte umzuwandeln.
Fallback      : Ohne lesbaren serverseitigen Login-Token erlaubt der
               Datenbank-only-Fallback ungeschützte Klassen, sysadmin oder
               den Fall ohne global aktive Policyzeilen. Eine aktive Policy
               an anderer Stelle kann eine geschützte Klasse verweigern,
               wenn der serverseitige Token nicht lesbar ist. Der Fallback
               prüft keine einzelne Gruppenmitgliedschaft und übergeht nie
               die High-Impact-Bestätigung. Global aktiv sind Policyzeilen
               mit IsEnabled=1, ValidFromUtc NULL oder nicht später als jetzt,
               ValidToUtc NULL oder später als jetzt sowie nichtleeren, mit
               LTRIM/RTRIM geprüften Klassen- und Gruppennamen; die Zeitbasis
               ist SYSUTCDATETIME().
Wirkung       : Keine SQL-Berechtigung wird erteilt und keine AD-
               Gruppenmitgliedschaft live verifiziert. Es erfolgt keine
               fachliche Persistenz. Der Code setzt LOCK_TIMEOUT 0; eine
               Wiederherstellung eines vorherigen Werts wird nicht zugesagt.
===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.InternalCheckAnalysisPath 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalCheckAnalysisPath"
-- schema_name: "monitor"
-- object_name: "InternalCheckAnalysisPath"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Prüft vor fachlichen DMV-, Cache-, Query-Store- oder Katalogzugriffen die einzelne Analyseklasse, erforderliche High-Impact-Bestätigung und den aktuell ausgewerteten Freigabepfad."
-- source_path: "Code/01_Common/083a_USP_InternalCheckAnalysisPath.sql"
-- ---
-- 
-- # monitor.InternalCheckAnalysisPath
-- 
-- ## Zweck und Einsatz
-- 
-- Prüft vor fachlichen DMV-, Cache-, Query-Store- oder Katalogzugriffen die einzelne Analyseklasse, erforderliche High-Impact-Bestätigung und den aktuell ausgewerteten Freigabepfad. Die Prüfung liest zuerst die Framework-Views VW_AnalyseClassCatalog und VW_AnalyseAccessCurrent.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalCheckAnalysisPath]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[monitor].[VW_AnalyseClassCatalog]`, `[monitor].[VW_AnalyseAccessCurrent]`, `[monitor].[VW_AnalyseAccessPolicy]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @AnalysisClass | varchar(64) | ja | kein Default |
-- | @HighImpactConfirmed | bit | ja | kein Default |
-- | @StatusCode | varchar(40) OUTPUT | ja | kein Default |
-- | @ErrorMessage | nvarchar(2048) OUTPUT | ja | kein Default |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@AnalysisClass:** @AnalysisClass varchar(64), Default: kein Default; obligatorisch. Ein einzelner Katalogcode, keine Liste und kein Pattern. NULL und '' sind ungültig. Es erfolgt keine ausdrückliche Leerzeichenentfernung oder Groß-/Kleinschreibungsnormalisierung; Vergleiche folgen der Datenbankkollation, die nicht zwingend binär oder case-insensitive ist. Die gültigen Codes dieser ausgelieferten Katalogfassung 1.9.0 sind abschließend: STANDARD_CURRENT (STANDARD, RequiresGroupGate=0): Leichtgewichtige Current-State-Abfragen für Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O. EXTENDED_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Current-State-Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung. PLAN_CACHE_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte Query-Stats- und Plan-Cache-Auswertungen ohne vollständiges XML-Shredding. SHOWPLAN_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Showplan-Extraktion und XML-Analyse für konkret gefilterte Planhandles oder Query Hashes. OBJECT_ANALYSIS_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank. EXTERNAL_RUNTIME_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer SQL-Server-Runtimes ohne Testausführung. CLR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse ohne Assemblyausführung. MISSING_INDEX_CURRENT (ERWEITERT, RequiresGroupGate=0): Flüchtige Missing-Index-Hinweise mit begrenzter Ergebnismenge; keine automatische DDL-Ausführung. STATISTICS_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Statistik-Eigenschaftsanalyse für gefilterte Objekte. COLUMNSTORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Columnstore-Rowgroup-Analyse über Katalogsicht ohne Segment-/Dictionary-Vollscan. LOCKS_DEEP (DEEP, RequiresGroupGate=1): Detaillierte Materialisierung von sys.dm_tran_locks für die aktuell relevante Sessionmenge. LOG_VLF_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende VLF-Auswertung über sys.dm_db_log_info. PLAN_CACHE_DEEP (DEEP, RequiresGroupGate=1): Breite oder vollständige Analyse von Query Stats und Plan Cache. SHOWPLAN_XML_DEEP (DEEP, RequiresGroupGate=1): XML-Analyse gecachter oder aktueller Showplans einschließlich Warnings, Spills, Objekten und Statistiken. CATALOG_DEEP (DEEP, RequiresGroupGate=1): Breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse. PHYSICAL_STATS_DEEP (DEEP, RequiresGroupGate=1): Explizite Auswertung von sys.dm_db_index_physical_stats in einem bewusst gewählten Modus. INDEX_OPERATIONAL_DEEP (DEEP, RequiresGroupGate=1): Breite kumulative Index-Operational-Stats mit Lock-, Latch-, I/O-Latch- und Page-Split-Zählern. QUERY_STORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan- und Force-Auswertung mit engem Zeit- und Zeilenlimit. EXTENDED_EVENTS_CURRENT (ERWEITERT, RequiresGroupGate=0): Leichte Inventarisierung vorhandener Extended-Events-Definitionen und laufender Sessions ohne Targetdaten oder Eventhistorie. QUERY_STORE_DEEP (DEEP, RequiresGroupGate=1): Breite Query-Store-Historie, Regressionen, Planwechsel und Wait-Auswertungen. CROSS_DATABASE_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende Inventarisierung und Diagnose. COLUMNSTORE_DEEP (DEEP, RequiresGroupGate=1): Breite Columnstore-Analyse einschließlich Rowgroups, Deleted Rows, Dictionaries und Segmenten. EXTENDED_EVENTS_FORENSICS_DEEP (FORENSIK, RequiresGroupGate=1): Optionale Auswertung vorhandener Extended-Events-Sessions und Event-Dateien; niemals Primärquelle des Standardlaufs. SERVER_HEALTH_CURRENT (ERWEITERT, RequiresGroupGate=0): CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der aktuellen Instanz. SERVER_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Serverkonfiguration, Trace Flags und Startup-Parameter. SECURITY_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende sicherheits- und dienstbezogene Betriebsparameter. SQL_AGENT_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-Server-Agent-Status-, Job-, Schedule- und Historienanalyse aus msdb. RESOURCE_GOVERNOR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Resource-Governor-Konfigurations- und Laufzeitanalyse. HA_DR_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte lesende Analyse von Availability Groups, Backup, Log Shipping, Replication, CDC und Change Tracking. ENTERPRISE_TOPOLOGY_DEEP (DEEP, RequiresGroupGate=1): Vertiefte enterpriseweite Topologie- und Distribution-Analyse für HA/DR und Replication. DATA_PLATFORM_ADAPTER_CURRENT (ERWEITERT, RequiresGroupGate=0): Optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Loggingobjekten mit isolierter Existenz- und Rechteprüfung. Die Katalog-DefaultMaxRows- und DefaultTimeoutSeconds-Werte sind Hinweise der Katalogzeilen und werden von dieser Prüfung nicht erzwungen.
-- 
-- **@HighImpactConfirmed:** @HighImpactConfirmed bit, Default: kein Default; obligatorisch. 1 bestätigt die angeforderte High-Impact-Ausführung; 0 bestätigt sie nicht und ist bei RequiresGroupGate=1 unzulässig. NULL ist ungültig; ein Leerwert ist für bit nicht unterstützt. Die Bestätigung ist auch bei sysadmin oder offener Policy erforderlich. Ihr Fehlen wird vor DENIED_GROUP gemeldet.
-- 
-- **@StatusCode:** @StatusCode varchar(40) OUTPUT, Default: kein Default; obligatorisches Argument. Eingehendes NULL, Leertext und andere Werte werden auf AVAILABLE zurückgesetzt und bei behandeltem Ergebnis auf genau einen Status gesetzt: AVAILABLE (Klasse und Gateprüfung bestanden), INVALID_PARAMETER (@AnalysisClass ist NULL, leer oder unbekannt oder @HighImpactConfirmed ist ungültig), HIGH_IMPACT_CONFIRMATION_REQUIRED (erforderliche Bestätigung fehlt), DENIED_GROUP (Gruppenpfad nicht freigegeben). Eine aufrufende Variable mit passendem Typ ist zum Empfangen erforderlich; ohne OUTPUT beim Aufruf kann der Wert verworfen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorMessage:** @ErrorMessage nvarchar(2048) OUTPUT, Default: kein Default; obligatorisches Argument. Der Eingabewert wird sofort auf NULL zurückgesetzt; bei behandeltem Fehler enthält er den zugehörigen Text, bei AVAILABLE bleibt er NULL. Der anfängliche NULL- oder Leerwert wird ignoriert. Eine aufrufende Variable mit passendem Typ ist zum Empfangen erforderlich; ohne OUTPUT beim Aufruf kann der Wert verworfen werden. Aufruf        : Alle vier Argumente müssen beim EXEC angegeben werden. Ausgelassene Pflichtargumente verursachen einen Aufruffehler, bevor diese Procedure einen Status setzen kann. OUTPUT-Argumente dürfen ohne das Schlüsselwort OUTPUT übergeben werden, wenn ihr Ergebnis verworfen wird. Fehler        : Nur Fehlernummern 229, 371 und 916 beim initialen Zugriff auf die Framework-Views lösen den Datenbank-only-Fallback aus. Andere Fehler werden erneut ausgelöst. Auch Unterabfragen des Fallbacks können fehlschlagen. Es wird keine Zusage gemacht, native Fehler in Statuswerte umzuwandeln. Fallback      : Ohne lesbaren serverseitigen Login-Token erlaubt der Datenbank-only-Fallback ungeschützte Klassen, sysadmin oder den Fall ohne global aktive Policyzeilen. Eine aktive Policy an anderer Stelle kann eine geschützte Klasse verweigern, wenn der serverseitige Token nicht lesbar ist. Der Fallback prüft keine einzelne Gruppenmitgliedschaft und übergeht nie die High-Impact-Bestätigung. Global aktiv sind Policyzeilen mit IsEnabled=1, ValidFromUtc NULL oder nicht später als jetzt, ValidToUtc NULL oder später als jetzt sowie nichtleeren, mit LTRIM/RTRIM geprüften Klassen- und Gruppennamen; die Zeitbasis ist SYSUTCDATETIME(). Wirkung       : Keine SQL-Berechtigung wird erteilt und keine AD- Gruppenmitgliedschaft live verifiziert. Es erfolgt keine fachliche Persistenz. Der Code setzt LOCK_TIMEOUT 0; eine Wiederherstellung eines vorherigen Werts wird nicht zugesagt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Kein Fach-Resultset. `@StatusCode varchar(40)` und `@ErrorMessage nvarchar(2048)` sind die einzigen OUTPUTs; `AVAILABLE` erlaubt den geprüften Analysepfad, `INVALID_PARAMETER`, `HIGH_IMPACT_CONFIRMATION_REQUIRED` oder `DENIED_GROUP` sperren ihn. Die Prüfung liest den Klassen- und Zugriffskatalog im aktuellen Kontext; ein Datenbank-Fallback ersetzt keinen lesbaren serverseitigen Gruppentoken.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalCheckAnalysisPath';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass=NULL, @HighImpactConfirmed=NULL, @StatusCode=NULL, @ErrorMessage=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Nur Fehlernummern 229, 371 und 916 beim initialen Zugriff auf die Framework-Views lösen den Datenbank-only-Fallback aus. Andere Fehler werden erneut ausgelöst. Auch Unterabfragen des Fallbacks können fehlschlagen. Es wird keine Zusage gemacht, native Fehler in Statuswerte umzuwandeln.
-- 
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalCheckAnalysisPath
-- Version      : 1.1.0
-- Stand        : 2026-07-21
-- Typ          : Interne Stored Procedure
-- Zweck        : Prüft vor fachlichen DMV-, Cache-, Query-Store- oder
--                Katalogzugriffen die einzelne Analyseklasse, erforderliche
--                High-Impact-Bestätigung und den aktuell ausgewerteten
--                Freigabepfad. Die Prüfung liest zuerst die Framework-Views
--                VW_AnalyseClassCatalog und VW_AnalyseAccessCurrent.
-- Eingabe      :
--   @AnalysisClass varchar(64), Default: kein Default; obligatorisch.
--                Ein einzelner Katalogcode, keine Liste und kein Pattern.
--                NULL und '' sind ungültig. Es erfolgt keine ausdrückliche
--                Leerzeichenentfernung oder Groß-/Kleinschreibungsnormalisierung;
--                Vergleiche folgen der Datenbankkollation, die nicht zwingend
--                binär oder case-insensitive ist. Die gültigen Codes dieser
--                ausgelieferten Katalogfassung 1.9.0 sind abschließend:
--                STANDARD_CURRENT (STANDARD, RequiresGroupGate=0): Leichtgewichtige Current-State-Abfragen für Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O.
--                EXTENDED_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Current-State-Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung.
--                PLAN_CACHE_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte Query-Stats- und Plan-Cache-Auswertungen ohne vollständiges XML-Shredding.
--                SHOWPLAN_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Showplan-Extraktion und XML-Analyse für konkret gefilterte Planhandles oder Query Hashes.
--                OBJECT_ANALYSIS_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank.
--                EXTERNAL_RUNTIME_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer SQL-Server-Runtimes ohne Testausführung.
--                CLR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse ohne Assemblyausführung.
--                MISSING_INDEX_CURRENT (ERWEITERT, RequiresGroupGate=0): Flüchtige Missing-Index-Hinweise mit begrenzter Ergebnismenge; keine automatische DDL-Ausführung.
--                STATISTICS_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Statistik-Eigenschaftsanalyse für gefilterte Objekte.
--                COLUMNSTORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Columnstore-Rowgroup-Analyse über Katalogsicht ohne Segment-/Dictionary-Vollscan.
--                LOCKS_DEEP (DEEP, RequiresGroupGate=1): Detaillierte Materialisierung von sys.dm_tran_locks für die aktuell relevante Sessionmenge.
--                LOG_VLF_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende VLF-Auswertung über sys.dm_db_log_info.
--                PLAN_CACHE_DEEP (DEEP, RequiresGroupGate=1): Breite oder vollständige Analyse von Query Stats und Plan Cache.
--                SHOWPLAN_XML_DEEP (DEEP, RequiresGroupGate=1): XML-Analyse gecachter oder aktueller Showplans einschließlich Warnings, Spills, Objekten und Statistiken.
--                CATALOG_DEEP (DEEP, RequiresGroupGate=1): Breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse.
--                PHYSICAL_STATS_DEEP (DEEP, RequiresGroupGate=1): Explizite Auswertung von sys.dm_db_index_physical_stats in einem bewusst gewählten Modus.
--                INDEX_OPERATIONAL_DEEP (DEEP, RequiresGroupGate=1): Breite kumulative Index-Operational-Stats mit Lock-, Latch-, I/O-Latch- und Page-Split-Zählern.
--                QUERY_STORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan- und Force-Auswertung mit engem Zeit- und Zeilenlimit.
--                EXTENDED_EVENTS_CURRENT (ERWEITERT, RequiresGroupGate=0): Leichte Inventarisierung vorhandener Extended-Events-Definitionen und laufender Sessions ohne Targetdaten oder Eventhistorie.
--                QUERY_STORE_DEEP (DEEP, RequiresGroupGate=1): Breite Query-Store-Historie, Regressionen, Planwechsel und Wait-Auswertungen.
--                CROSS_DATABASE_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende Inventarisierung und Diagnose.
--                COLUMNSTORE_DEEP (DEEP, RequiresGroupGate=1): Breite Columnstore-Analyse einschließlich Rowgroups, Deleted Rows, Dictionaries und Segmenten.
--                EXTENDED_EVENTS_FORENSICS_DEEP (FORENSIK, RequiresGroupGate=1): Optionale Auswertung vorhandener Extended-Events-Sessions und Event-Dateien; niemals Primärquelle des Standardlaufs.
--                SERVER_HEALTH_CURRENT (ERWEITERT, RequiresGroupGate=0): CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der aktuellen Instanz.
--                SERVER_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Serverkonfiguration, Trace Flags und Startup-Parameter.
--                SECURITY_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende sicherheits- und dienstbezogene Betriebsparameter.
--                SQL_AGENT_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-Server-Agent-Status-, Job-, Schedule- und Historienanalyse aus msdb.
--                RESOURCE_GOVERNOR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Resource-Governor-Konfigurations- und Laufzeitanalyse.
--                HA_DR_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte lesende Analyse von Availability Groups, Backup, Log Shipping, Replication, CDC und Change Tracking.
--                ENTERPRISE_TOPOLOGY_DEEP (DEEP, RequiresGroupGate=1): Vertiefte enterpriseweite Topologie- und Distribution-Analyse für HA/DR und Replication.
--                DATA_PLATFORM_ADAPTER_CURRENT (ERWEITERT, RequiresGroupGate=0): Optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Loggingobjekten mit isolierter Existenz- und Rechteprüfung.
--                Die Katalog-DefaultMaxRows- und DefaultTimeoutSeconds-Werte
--                sind Hinweise der Katalogzeilen und werden von dieser Prüfung
--                nicht erzwungen.
--   @HighImpactConfirmed bit, Default: kein Default; obligatorisch.
--                1 bestätigt die angeforderte High-Impact-Ausführung; 0
--                bestätigt sie nicht und ist bei RequiresGroupGate=1 unzulässig.
--                NULL ist ungültig; ein Leerwert ist für bit nicht unterstützt.
--                Die Bestätigung ist auch bei sysadmin oder offener Policy
--                erforderlich. Ihr Fehlen wird vor DENIED_GROUP gemeldet.
--   @StatusCode varchar(40) OUTPUT, Default: kein Default; obligatorisches
--                Argument. Eingehendes NULL, Leertext und andere Werte werden auf AVAILABLE
--                zurückgesetzt und bei behandeltem Ergebnis auf genau einen
--                Status gesetzt: AVAILABLE (Klasse und Gateprüfung bestanden),
--                INVALID_PARAMETER (@AnalysisClass ist NULL, leer oder unbekannt
--                oder @HighImpactConfirmed ist ungültig), HIGH_IMPACT_CONFIRMATION_REQUIRED
--                (erforderliche Bestätigung fehlt), DENIED_GROUP (Gruppenpfad
--                nicht freigegeben). Eine aufrufende Variable mit passendem
--                Typ ist zum Empfangen erforderlich; ohne OUTPUT beim Aufruf
--                kann der Wert verworfen werden.
--   @ErrorMessage nvarchar(2048) OUTPUT, Default: kein Default; obligatorisches
--                Argument. Der Eingabewert wird sofort auf NULL zurückgesetzt;
--                bei behandeltem Fehler enthält er den zugehörigen Text, bei
--                AVAILABLE bleibt er NULL. Der anfängliche NULL- oder Leerwert
--                wird ignoriert. Eine aufrufende Variable mit passendem Typ ist
--                zum Empfangen erforderlich; ohne OUTPUT beim Aufruf kann der
--                Wert verworfen werden.
-- Aufruf        : Alle vier Argumente müssen beim EXEC angegeben werden.
--                Ausgelassene Pflichtargumente verursachen einen Aufruffehler,
--                bevor diese Procedure einen Status setzen kann.
--                OUTPUT-Argumente dürfen ohne das Schlüsselwort OUTPUT
--                übergeben werden, wenn ihr Ergebnis verworfen wird.
-- Fehler        : Nur Fehlernummern 229, 371 und 916 beim initialen Zugriff auf
--                die Framework-Views lösen den Datenbank-only-Fallback aus.
--                Andere Fehler werden erneut ausgelöst. Auch Unterabfragen des
--                Fallbacks können fehlschlagen. Es wird keine Zusage gemacht,
--                native Fehler in Statuswerte umzuwandeln.
-- Fallback      : Ohne lesbaren serverseitigen Login-Token erlaubt der
--                Datenbank-only-Fallback ungeschützte Klassen, sysadmin oder
--                den Fall ohne global aktive Policyzeilen. Eine aktive Policy
--                an anderer Stelle kann eine geschützte Klasse verweigern,
--                wenn der serverseitige Token nicht lesbar ist. Der Fallback
--                prüft keine einzelne Gruppenmitgliedschaft und übergeht nie
--                die High-Impact-Bestätigung. Global aktiv sind Policyzeilen
--                mit IsEnabled=1, ValidFromUtc NULL oder nicht später als jetzt,
--                ValidToUtc NULL oder später als jetzt sowie nichtleeren, mit
--                LTRIM/RTRIM geprüften Klassen- und Gruppennamen; die Zeitbasis
--                ist SYSUTCDATETIME().
-- Wirkung       : Keine SQL-Berechtigung wird erteilt und keine AD-
--                Gruppenmitgliedschaft live verifiziert. Es erfolgt keine
--                fachliche Persistenz. Der Code setzt LOCK_TIMEOUT 0; eine
--                Wiederherstellung eines vorherigen Werts wird nicht zugesagt.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalCheckAnalysisPath
CREATE OR ALTER PROCEDURE [monitor].[InternalCheckAnalysisPath]
      @AnalysisClass        varchar(64)
    , @HighImpactConfirmed  bit
    , @StatusCode           varchar(40)    OUTPUT
    , @ErrorMessage         nvarchar(2048) OUTPUT
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalCheckAnalysisPath
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalCheckAnalysisPath') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalCheckAnalysisPath"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalCheckAnalysisPath"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Prüft vor fachlichen DMV-, Cache-, Query-Store- oder Katalogzugriffen die einzelne Analyseklasse, erforderliche High-Impact-Bestätigung und den aktuell ausgewerteten Freigabepfad."'
            + NCHAR(10)
            + N'source_path: "Code/01_Common/083a_USP_InternalCheckAnalysisPath.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalCheckAnalysisPath'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Prüft vor fachlichen DMV-, Cache-, Query-Store- oder Katalogzugriffen die einzelne Analyseklasse, erforderliche High-Impact-Bestätigung und den aktuell ausgewerteten Freigabepfad. Die Prüfung liest zuerst die Framework-Views VW_AnalyseClassCatalog und VW_AnalyseAccessCurrent.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalCheckAnalysisPath]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[monitor].[VW_AnalyseClassCatalog]`, `[monitor].[VW_AnalyseAccessCurrent]`, `[monitor].[VW_AnalyseAccessPolicy]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'| @AnalysisClass | varchar(64) | ja | kein Default |'
            + NCHAR(10)
            + N'| @HighImpactConfirmed | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCode | varchar(40) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessage | nvarchar(2048) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@AnalysisClass:** @AnalysisClass varchar(64), Default: kein Default; obligatorisch. Ein einzelner Katalogcode, keine Liste und kein Pattern. NULL und '''' sind ungültig. Es erfolgt keine ausdrückliche Leerzeichenentfernung oder Groß-/Kleinschreibungsnormalisierung; Vergleiche folgen der Datenbankkollation, die nicht zwingend binär oder case-insensitive ist. Die gültigen Codes dieser ausgelieferten Katalogfassung 1.9.0 sind abschließend: STANDARD_CURRENT (STANDARD, RequiresGroupGate=0): Leichtgewichtige Current-State-Abfragen für Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O. EXTENDED_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Current-State-Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung. PLAN_CACHE_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte Query-Stats- und Plan-Cache-Auswertungen ohne vollständiges XML-Shredding. SHOWPLAN_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Showplan-Extraktion und XML-Analyse für konkret gefilterte Planhand'
            + N'les oder Query Hashes. OBJECT_ANALYSIS_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank. EXTERNAL_RUNTIME_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer SQL-Server-Runtimes ohne Testausführung. CLR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse ohne Assemblyausführung. MISSING_INDEX_CURRENT (ERWEITERT, RequiresGroupGate=0): Flüchtige Missing-Index-Hinweise mit begrenzter Ergebnismenge; keine automatische DDL-Ausführung. STATISTICS_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Statistik-Eigenschaftsanalyse für gefilterte Objekte. COLUMNSTORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Columnstore-Rowgroup-Analyse über Katalogsicht ohne Segment-/Dictionary-Vollscan. LOCKS_DEEP (DEEP, RequiresGroupGate=1): Detaillierte Materialisierung von sy'
            + N's.dm_tran_locks für die aktuell relevante Sessionmenge. LOG_VLF_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende VLF-Auswertung über sys.dm_db_log_info. PLAN_CACHE_DEEP (DEEP, RequiresGroupGate=1): Breite oder vollständige Analyse von Query Stats und Plan Cache. SHOWPLAN_XML_DEEP (DEEP, RequiresGroupGate=1): XML-Analyse gecachter oder aktueller Showplans einschließlich Warnings, Spills, Objekten und Statistiken. CATALOG_DEEP (DEEP, RequiresGroupGate=1): Breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse. PHYSICAL_STATS_DEEP (DEEP, RequiresGroupGate=1): Explizite Auswertung von sys.dm_db_index_physical_stats in einem bewusst gewählten Modus. INDEX_OPERATIONAL_DEEP (DEEP, RequiresGroupGate=1): Breite kumulative Index-Operational-Stats mit Lock-, Latch-, I/O-Latch- und Page-Split-Zählern. QUERY_STORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan- und Force-Auswertung mit engem Zeit- und Zeilenlimit. EXTE'
            + N'NDED_EVENTS_CURRENT (ERWEITERT, RequiresGroupGate=0): Leichte Inventarisierung vorhandener Extended-Events-Definitionen und laufender Sessions ohne Targetdaten oder Eventhistorie. QUERY_STORE_DEEP (DEEP, RequiresGroupGate=1): Breite Query-Store-Historie, Regressionen, Planwechsel und Wait-Auswertungen. CROSS_DATABASE_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende Inventarisierung und Diagnose. COLUMNSTORE_DEEP (DEEP, RequiresGroupGate=1): Breite Columnstore-Analyse einschließlich Rowgroups, Deleted Rows, Dictionaries und Segmenten. EXTENDED_EVENTS_FORENSICS_DEEP (FORENSIK, RequiresGroupGate=1): Optionale Auswertung vorhandener Extended-Events-Sessions und Event-Dateien; niemals Primärquelle des Standardlaufs. SERVER_HEALTH_CURRENT (ERWEITERT, RequiresGroupGate=0): CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der aktuellen Instanz. SERVER_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Serverkonfiguration, Trace Flags und Startup-Parameter. SECURITY_CON'
            + N'FIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende sicherheits- und dienstbezogene Betriebsparameter. SQL_AGENT_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-Server-Agent-Status-, Job-, Schedule- und Historienanalyse aus msdb. RESOURCE_GOVERNOR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Resource-Governor-Konfigurations- und Laufzeitanalyse. HA_DR_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte lesende Analyse von Availability Groups, Backup, Log Shipping, Replication, CDC und Change Tracking. ENTERPRISE_TOPOLOGY_DEEP (DEEP, RequiresGroupGate=1): Vertiefte enterpriseweite Topologie- und Distribution-Analyse für HA/DR und Replication. DATA_PLATFORM_ADAPTER_CURRENT (ERWEITERT, RequiresGroupGate=0): Optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Loggingobjekten mit isolierter Existenz- und Rechteprüfung. Die Katalog-DefaultMaxRows- und DefaultTimeoutSeconds-Werte sind Hinweise der Katalogzeilen und werden von dieser Prüfung nicht'
            + N' erzwungen.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@HighImpactConfirmed:** @HighImpactConfirmed bit, Default: kein Default; obligatorisch. 1 bestätigt die angeforderte High-Impact-Ausführung; 0 bestätigt sie nicht und ist bei RequiresGroupGate=1 unzulässig. NULL ist ungültig; ein Leerwert ist für bit nicht unterstützt. Die Bestätigung ist auch bei sysadmin oder offener Policy erforderlich. Ihr Fehlen wird vor DENIED_GROUP gemeldet.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCode:** @StatusCode varchar(40) OUTPUT, Default: kein Default; obligatorisches Argument. Eingehendes NULL, Leertext und andere Werte werden auf AVAILABLE zurückgesetzt und bei behandeltem Ergebnis auf genau einen Status gesetzt: AVAILABLE (Klasse und Gateprüfung bestanden), INVALID_PARAMETER (@AnalysisClass ist NULL, leer oder unbekannt oder @HighImpactConfirmed ist ungültig), HIGH_IMPACT_CONFIRMATION_REQUIRED (erforderliche Bestätigung fehlt), DENIED_GROUP (Gruppenpfad nicht freigegeben). Eine aufrufende Variable mit passendem Typ ist zum Empfangen erforderlich; ohne OUTPUT beim Aufruf kann der Wert verworfen werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessage:** @ErrorMessage nvarchar(2048) OUTPUT, Default: kein Default; obligatorisches Argument. Der Eingabewert wird sofort auf NULL zurückgesetzt; bei behandeltem Fehler enthält er den zugehörigen Text, bei AVAILABLE bleibt er NULL. Der anfängliche NULL- oder Leerwert wird ignoriert. Eine aufrufende Variable mit passendem Typ ist zum Empfangen erforderlich; ohne OUTPUT beim Aufruf kann der Wert verworfen werden. Aufruf        : Alle vier Argumente müssen beim EXEC angegeben werden. Ausgelassene Pflichtargumente verursachen einen Aufruffehler, bevor diese Procedure einen Status setzen kann. OUTPUT-Argumente dürfen ohne das Schlüsselwort OUTPUT übergeben werden, wenn ihr Ergebnis verworfen wird. Fehler        : Nur Fehlernummern 229, 371 und 916 beim initialen Zugriff auf die Framework-Views lösen den Datenbank-only-Fallback aus. Andere Fehler werden erneut ausgelöst. Auch Unterabfragen des Fallbacks können fehlschlagen. Es wird keine Zusage gemacht, native Fehler in Statuswert'
            + N'e umzuwandeln. Fallback      : Ohne lesbaren serverseitigen Login-Token erlaubt der Datenbank-only-Fallback ungeschützte Klassen, sysadmin oder den Fall ohne global aktive Policyzeilen. Eine aktive Policy an anderer Stelle kann eine geschützte Klasse verweigern, wenn der serverseitige Token nicht lesbar ist. Der Fallback prüft keine einzelne Gruppenmitgliedschaft und übergeht nie die High-Impact-Bestätigung. Global aktiv sind Policyzeilen mit IsEnabled=1, ValidFromUtc NULL oder nicht später als jetzt, ValidToUtc NULL oder später als jetzt sowie nichtleeren, mit LTRIM/RTRIM geprüften Klassen- und Gruppennamen; die Zeitbasis ist SYSUTCDATETIME(). Wirkung       : Keine SQL-Berechtigung wird erteilt und keine AD- Gruppenmitgliedschaft live verifiziert. Es erfolgt keine fachliche Persistenz. Der Code setzt LOCK_TIMEOUT 0; eine Wiederherstellung eines vorherigen Werts wird nicht zugesagt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolg'
            + N't nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. `@StatusCode varchar(40)` und `@ErrorMessage nvarchar(2048)` sind die einzigen OUTPUTs; `AVAILABLE` erlaubt den geprüften Analysepfad, `INVALID_PARAMETER`, `HIGH_IMPACT_CONFIRMATION_REQUIRED` oder `DENIED_GROUP` sperren ihn. Die Prüfung liest den Klassen- und Zugriffskatalog im aktuellen Kontext; ein Datenbank-Fallback ersetzt keinen lesbaren serverseitigen Gruppentoken.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Beispiel'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'SELECT [SkillMarkdown]'
            + NCHAR(10)
            + N'FROM [monitor_metadata].[VW_ObjectUsageSkills]'
            + NCHAR(10)
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalCheckAnalysisPath'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalCheckAnalysisPath] @AnalysisClass=NULL, @HighImpactConfirmed=NULL, @StatusCode=NULL, @ErrorMessage=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Nur Fehlernummern 229, 371 und 916 beim initialen Zugriff auf die Framework-Views lösen den Datenbank-only-Fallback aus. Andere Fehler werden erneut ausgelöst. Auch Unterabfragen des Fallbacks können fehlschlagen. Es wird keine Zusage gemacht, native Fehler in Statuswerte umzuwandeln.'
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
            + N'Objekt       : monitor.InternalCheckAnalysisPath'
            + NCHAR(10)
            + N'Version      : 1.1.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-21'
            + NCHAR(10)
            + N'Typ          : Interne Stored Procedure'
            + NCHAR(10)
            + N'Zweck        : Prüft vor fachlichen DMV-, Cache-, Query-Store- oder'
            + NCHAR(10)
            + N'               Katalogzugriffen die einzelne Analyseklasse, erforderliche'
            + NCHAR(10)
            + N'               High-Impact-Bestätigung und den aktuell ausgewerteten'
            + NCHAR(10)
            + N'               Freigabepfad. Die Prüfung liest zuerst die Framework-Views'
            + NCHAR(10)
            + N'               VW_AnalyseClassCatalog und VW_AnalyseAccessCurrent.'
            + NCHAR(10)
            + N'Eingabe      :'
            + NCHAR(10)
            + N'  @AnalysisClass varchar(64), Default: kein Default; obligatorisch.'
            + NCHAR(10)
            + N'               Ein einzelner Katalogcode, keine Liste und kein Pattern.'
            + NCHAR(10)
            + N'               NULL und '''' sind ungültig. Es erfolgt keine ausdrückliche'
            + NCHAR(10)
            + N'               Leerzeichenentfernung oder Groß-/Kleinschreibungsnormalisierung;'
            + NCHAR(10)
            + N'               Vergleiche folgen der Datenbankkollation, die nicht zwingend'
            + NCHAR(10)
            + N'               binär oder case-insensitive ist. Die gültigen Codes dieser'
            + NCHAR(10)
            + N'               ausgelieferten Katalogfassung 1.9.0 sind abschließend:'
            + NCHAR(10)
            + N'               STANDARD_CURRENT (STANDARD, RequiresGroupGate=0): Leichtgewichtige Current-State-Abfragen für Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O.'
            + NCHAR(10)
            + N'               EXTENDED_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Current-State-Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung.'
            + NCHAR(10)
            + N'               PLAN_CACHE_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte Query-Stats- und Plan-Cache-Auswertungen ohne vollständiges XML-Shredding.'
            + NCHAR(10)
            + N'               SHOWPLAN_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Showplan-Extraktion und XML-Analyse für konkret gefilterte Planhandles oder Query Hashes.'
            + NCHAR(10)
            + N'               OBJECT_ANALYSIS_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank.'
            + NCHAR(10)
            + N'               EXTERNAL_RUNTIME_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer SQL-Server-Runtimes ohne Testausführung.'
            + NCHAR(10)
            + N'               CLR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse ohne Assemblyausführung.'
            + NCHAR(10)
            + N'               MISSING_INDEX_CURRENT (ERWEITERT, RequiresGroupGate=0): Flüchtige Missing-Index-Hinweise mit begrenzter Ergebnismenge; keine automatische DDL-Ausführung.'
            + NCHAR(10)
            + N'               STATISTICS_TARGETED (ERWEITERT, RequiresGroupGate=0): Gezielte Statistik-Eigenschaftsanalyse für gefilterte Objekte.'
            + NCHAR(10)
            + N'               COLUMNSTORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte Columnstore-Rowgroup-Analyse über Katalogsicht ohne Segment-/Dictionary-Vollscan.'
            + NCHAR(10)
            + N'               LOCKS_DEEP (DEEP, RequiresGroupGate=1): Detaillierte Materialisierung von sys.dm_tran_locks für die aktuell relevante Sessionmenge.'
            + NCHAR(10)
            + N'               LOG_VLF_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende VLF-Auswertung über sys.dm_db_log_info.'
            + NCHAR(10)
            + N'               PLAN_CACHE_DEEP (DEEP, RequiresGroupGate=1): Breite oder vollständige Analyse von Query Stats und Plan Cache.'
            + NCHAR(10)
            + N'               SHOWPLAN_XML_DEEP (DEEP, RequiresGroupGate=1): XML-Analyse gecachter oder aktueller Showplans einschließlich Warnings, Spills, Objekten und Statistiken.'
            + NCHAR(10)
            + N'               CATALOG_DEEP (DEEP, RequiresGroupGate=1): Breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse.'
            + NCHAR(10)
            + N'               PHYSICAL_STATS_DEEP (DEEP, RequiresGroupGate=1): Explizite Auswertung von sys.dm_db_index_physical_stats in einem bewusst gewählten Modus.'
            + NCHAR(10)
            + N'               INDEX_OPERATIONAL_DEEP (DEEP, RequiresGroupGate=1): Breite kumulative Index-Operational-Stats mit Lock-, Latch-, I/O-Latch- und Page-Split-Zählern.'
            + NCHAR(10)
            + N'               QUERY_STORE_CURRENT (ERWEITERT, RequiresGroupGate=0): Gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan- und Force-Auswertung mit engem Zeit- und Zeilenlimit.'
            + NCHAR(10)
            + N'               EXTENDED_EVENTS_CURRENT (ERWEITERT, RequiresGroupGate=0): Leichte Inventarisierung vorhandener Extended-Events-Definitionen und laufender Sessions ohne Targetdaten oder Eventhistorie.'
            + NCHAR(10)
            + N'               QUERY_STORE_DEEP (DEEP, RequiresGroupGate=1): Breite Query-Store-Historie, Regressionen, Planwechsel und Wait-Auswertungen.'
            + NCHAR(10)
            + N'               CROSS_DATABASE_DEEP (DEEP, RequiresGroupGate=1): Datenbankübergreifende Inventarisierung und Diagnose.'
            + NCHAR(10)
            + N'               COLUMNSTORE_DEEP (DEEP, RequiresGroupGate=1): Breite Columnstore-Analyse einschließlich Rowgroups, Deleted Rows, Dictionaries und Segmenten.'
            + NCHAR(10)
            + N'               EXTENDED_EVENTS_FORENSICS_DEEP (FORENSIK, RequiresGroupGate=1): Optionale Auswertung vorhandener Extended-Events-Sessions und Event-Dateien; niemals Primärquelle des Standardlaufs.'
            + NCHAR(10)
            + N'               SERVER_HEALTH_CURRENT (ERWEITERT, RequiresGroupGate=0): CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der aktuellen Instanz.'
            + NCHAR(10)
            + N'               SERVER_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Serverkonfiguration, Trace Flags und Startup-Parameter.'
            + NCHAR(10)
            + N'               SECURITY_CONFIGURATION_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende sicherheits- und dienstbezogene Betriebsparameter.'
            + NCHAR(10)
            + N'               SQL_AGENT_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende SQL-Server-Agent-Status-, Job-, Schedule- und Historienanalyse aus msdb.'
            + NCHAR(10)
            + N'               RESOURCE_GOVERNOR_CURRENT (ERWEITERT, RequiresGroupGate=0): Lesende Resource-Governor-Konfigurations- und Laufzeitanalyse.'
            + NCHAR(10)
            + N'               HA_DR_CURRENT (ERWEITERT, RequiresGroupGate=0): Begrenzte lesende Analyse von Availability Groups, Backup, Log Shipping, Replication, CDC und Change Tracking.'
            + NCHAR(10)
            + N'               ENTERPRISE_TOPOLOGY_DEEP (DEEP, RequiresGroupGate=1): Vertiefte enterpriseweite Topologie- und Distribution-Analyse für HA/DR und Replication.'
            + NCHAR(10)
            + N'               DATA_PLATFORM_ADAPTER_CURRENT (ERWEITERT, RequiresGroupGate=0): Optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Loggingobjekten mit isolierter Existenz- und Rechteprüfung.'
            + NCHAR(10)
            + N'               Die Katalog-DefaultMaxRows- und DefaultTimeoutSeconds-Werte'
            + NCHAR(10)
            + N'               sind Hinweise der Katalogzeilen und werden von dieser Prüfung'
            + NCHAR(10)
            + N'               nicht erzwungen.'
            + NCHAR(10)
            + N'  @HighImpactConfirmed bit, Default: kein Default; obligatorisch.'
            + NCHAR(10)
            + N'               1 bestätigt die angeforderte High-Impact-Ausführung; 0'
            + NCHAR(10)
            + N'               bestätigt sie nicht und ist bei RequiresGroupGate=1 unzulässig.'
            + NCHAR(10)
            + N'               NULL ist ungültig; ein Leerwert ist für bit nicht unterstützt.'
            + NCHAR(10)
            + N'               Die Bestätigung ist auch bei sysadmin oder offener Policy'
            + NCHAR(10)
            + N'               erforderlich. Ihr Fehlen wird vor DENIED_GROUP gemeldet.'
            + NCHAR(10)
            + N'  @StatusCode varchar(40) OUTPUT, Default: kein Default; obligatorisches'
            + NCHAR(10)
            + N'               Argument. Eingehendes NULL, Leertext und andere Werte werden auf AVAILABLE'
            + NCHAR(10)
            + N'               zurückgesetzt und bei behandeltem Ergebnis auf genau einen'
            + NCHAR(10)
            + N'               Status gesetzt: AVAILABLE (Klasse und Gateprüfung bestanden),'
            + NCHAR(10)
            + N'               INVALID_PARAMETER (@AnalysisClass ist NULL, leer oder unbekannt'
            + NCHAR(10)
            + N'               oder @HighImpactConfirmed ist ungültig), HIGH_IMPACT_CONFIRMATION_REQUIRED'
            + NCHAR(10)
            + N'               (erforderliche Bestätigung fehlt), DENIED_GROUP (Gruppenpfad'
            + NCHAR(10)
            + N'               nicht freigegeben). Eine aufrufende Variable mit passendem'
            + NCHAR(10)
            + N'               Typ ist zum Empfangen erforderlich; ohne OUTPUT beim Aufruf'
            + NCHAR(10)
            + N'               kann der Wert verworfen werden.'
            + NCHAR(10)
            + N'  @ErrorMessage nvarchar(2048) OUTPUT, Default: kein Default; obligatorisches'
            + NCHAR(10)
            + N'               Argument. Der Eingabewert wird sofort auf NULL zurückgesetzt;'
            + NCHAR(10)
            + N'               bei behandeltem Fehler enthält er den zugehörigen Text, bei'
            + NCHAR(10)
            + N'               AVAILABLE bleibt er NULL. Der anfängliche NULL- oder Leerwert'
            + NCHAR(10)
            + N'               wird ignoriert. Eine aufrufende Variable mit passendem Typ ist'
            + NCHAR(10)
            + N'               zum Empfangen erforderlich; ohne OUTPUT beim Aufruf kann der'
            + NCHAR(10)
            + N'               Wert verworfen werden.'
            + NCHAR(10)
            + N'Aufruf        : Alle vier Argumente müssen beim EXEC angegeben werden.'
            + NCHAR(10)
            + N'               Ausgelassene Pflichtargumente verursachen einen Aufruffehler,'
            + NCHAR(10)
            + N'               bevor diese Procedure einen Status setzen kann.'
            + NCHAR(10)
            + N'               OUTPUT-Argumente dürfen ohne das Schlüsselwort OUTPUT'
            + NCHAR(10)
            + N'               übergeben werden, wenn ihr Ergebnis verworfen wird.'
            + NCHAR(10)
            + N'Fehler        : Nur Fehlernummern 229, 371 und 916 beim initialen Zugriff auf'
            + NCHAR(10)
            + N'               die Framework-Views lösen den Datenbank-only-Fallback aus.'
            + NCHAR(10)
            + N'               Andere Fehler werden erneut ausgelöst. Auch Unterabfragen des'
            + NCHAR(10)
            + N'               Fallbacks können fehlschlagen. Es wird keine Zusage gemacht,'
            + NCHAR(10)
            + N'               native Fehler in Statuswerte umzuwandeln.'
            + NCHAR(10)
            + N'Fallback      : Ohne lesbaren serverseitigen Login-Token erlaubt der'
            + NCHAR(10)
            + N'               Datenbank-only-Fallback ungeschützte Klassen, sysadmin oder'
            + NCHAR(10)
            + N'               den Fall ohne global aktive Policyzeilen. Eine aktive Policy'
            + NCHAR(10)
            + N'               an anderer Stelle kann eine geschützte Klasse verweigern,'
            + NCHAR(10)
            + N'               wenn der serverseitige Token nicht lesbar ist. Der Fallback'
            + NCHAR(10)
            + N'               prüft keine einzelne Gruppenmitgliedschaft und übergeht nie'
            + NCHAR(10)
            + N'               die High-Impact-Bestätigung. Global aktiv sind Policyzeilen'
            + NCHAR(10)
            + N'               mit IsEnabled=1, ValidFromUtc NULL oder nicht später als jetzt,'
            + NCHAR(10)
            + N'               ValidToUtc NULL oder später als jetzt sowie nichtleeren, mit'
            + NCHAR(10)
            + N'               LTRIM/RTRIM geprüften Klassen- und Gruppennamen; die Zeitbasis'
            + NCHAR(10)
            + N'               ist SYSUTCDATETIME().'
            + NCHAR(10)
            + N'Wirkung       : Keine SQL-Berechtigung wird erteilt und keine AD-'
            + NCHAR(10)
            + N'               Gruppenmitgliedschaft live verifiziert. Es erfolgt keine'
            + NCHAR(10)
            + N'               fachliche Persistenz. Der Code setzt LOCK_TIMEOUT 0; eine'
            + NCHAR(10)
            + N'               Wiederherstellung eines vorherigen Werts wird nicht zugesagt.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalCheckAnalysisPath
        RETURN;
    END;

    SET LOCK_TIMEOUT 0;

    SELECT @StatusCode='AVAILABLE',@ErrorMessage=NULL;

    IF NULLIF(@AnalysisClass,'') IS NULL
       OR @HighImpactConfirmed IS NULL
       OR @HighImpactConfirmed NOT IN (0,1)
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=N'Analyseklasse oder High-Impact-Bestätigung ist ungültig.';
        RETURN;
    END;

    DECLARE
          @RequiresHighImpact bit=0
        , @Allowed bit=0
        , @UsedDatabaseOnlyFallback bit=0
        , @IsSysadmin bit=CONVERT(bit,CASE WHEN IS_SRVROLEMEMBER(N'sysadmin')=1 THEN 1 ELSE 0 END);

    BEGIN TRY
        SELECT
              @RequiresHighImpact=COALESCE(MAX(CONVERT(tinyint,[c].[RequiresGroupGate])),0)
            , @Allowed=COALESCE(MAX(CONVERT(tinyint,[a].[IsAllowed])),0)
        FROM [monitor].[VW_AnalyseClassCatalog] AS [c]
        LEFT JOIN [monitor].[VW_AnalyseAccessCurrent] AS [a]
          ON [a].[AnalysisClass]=[c].[AnalysisClass]
        WHERE [c].[AnalysisClass]=@AnalysisClass;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() NOT IN (229,371,916)
            THROW;

        SET @UsedDatabaseOnlyFallback=1;

        SELECT @RequiresHighImpact=COALESCE(MAX(CONVERT(tinyint,[c].[RequiresGroupGate])),0)
        FROM [monitor].[VW_AnalyseClassCatalog] AS [c]
        WHERE [c].[AnalysisClass]=@AnalysisClass;

        SET @Allowed=CONVERT(bit,CASE
              WHEN @RequiresHighImpact=0 THEN 1
              WHEN @IsSysadmin=1 THEN 1
              WHEN NOT EXISTS
                   (
                       SELECT 1
                       FROM [monitor].[VW_AnalyseAccessPolicy] AS [p]
                       WHERE [p].[IsEnabled]=1
                         AND ([p].[ValidFromUtc] IS NULL OR [p].[ValidFromUtc]<=SYSUTCDATETIME())
                         AND ([p].[ValidToUtc] IS NULL OR [p].[ValidToUtc]>SYSUTCDATETIME())
                         AND NULLIF(LTRIM(RTRIM([p].[AnalysisClass])),N'') IS NOT NULL
                         AND NULLIF(LTRIM(RTRIM([p].[ADGroupName])),N'') IS NOT NULL
                   ) THEN 1
              ELSE 0 END);
    END CATCH;

    IF NOT EXISTS
       (
           SELECT 1
           FROM [monitor].[VW_AnalyseClassCatalog]
           WHERE [AnalysisClass]=@AnalysisClass
       )
    BEGIN
        SET @StatusCode='INVALID_PARAMETER';
        SET @ErrorMessage=CONCAT(N'Unbekannte Analyseklasse: ',@AnalysisClass,N'.');
        RETURN;
    END;

    IF @RequiresHighImpact=1 AND @HighImpactConfirmed<>1
    BEGIN
        SET @StatusCode='HIGH_IMPACT_CONFIRMATION_REQUIRED';
        SET @ErrorMessage=CONCAT(N'Der aktivierte Analysepfad ',@AnalysisClass,N' erfordert @HighImpactConfirmed=1.');
        RETURN;
    END;

    IF @Allowed<>1
    BEGIN
        SET @StatusCode='DENIED_GROUP';
        SET @ErrorMessage=CASE WHEN @UsedDatabaseOnlyFallback=1
                              THEN CONCAT(@AnalysisClass,N' ist nicht freigegeben; der serverseitige Gruppentoken war im aktuellen Datenbankkontext nicht lesbar.')
                              ELSE CONCAT(@AnalysisClass,N' ist nicht freigegeben.') END;
    END;
END;
GO
