USE [DeineDatenbank];
GO
/*
===============================================================================
Objekt       : monitor.InternalRunSnapshotWaitStatsCycle
Version      : 1.0.0
Stand        : 2026-10-25
Zweck        : Die Procedure orchestriert einen nativen Wait-Snapshot für ein
               konfiguriertes Target und übergibt ihn dem gebundenen Backend.
Grenze       : Ein vollständiger DMV-Read sowie gleicher Enginekontext davor
               und danach beweisen weder atomare Sicht noch Resetkontinuität.
===============================================================================

#### InternalRunSnapshotWaitStatsCycle – Parameterverträge

Alle acht Parameter sind erforderlich und besitzen keinen Default. Die ersten zwei sind Eingaben; die sechs OUTPUT-Parameter müssen auch dann gebunden werden, wenn ihre Ausgabe verworfen wird. Zum Empfangen bindet der Aufrufer eine Variable passenden Typs mit OUTPUT. Eingehende Werte der OUTPUT-Parameter werden ignoriert und beim Eintritt initialisiert.

- @SchedulerType (varchar(16); Default: Kein Default): erforderlich; erlaubt sind MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) und SQL_AGENT (SQL Server Agent). Der Wert dient als Herkunftslabel und startet oder prüft keinen Scheduler. NULL oder ein anderer, nach gewöhnlichem SQL-Server-Zeichenkettenvergleich abweichender Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich verwendet die Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können daher gleichwertig sein. Es erfolgt keine binäre Prüfung oder Trimmen/Normalisierung. Leertext ist kein gültiger Wert.
- @RunEvenIfNotDue (bit; Default: Kein Default): erforderlich; 0 wendet die Fälligkeitsprüfung an, 1 umgeht ausschließlich diese Prüfung. NULL führt zu INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte Bit-Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben wirksam.
- @CaptureRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Beim vorbereiteten Capture kann die ID nach dessen INSERT ausgegeben werden. Die ID allein bestätigt weder erfolgreichen Quellread noch erfolgreiche Finalisierung. Empfang über bigint-Variable und OUTPUT.
- @TargetDatabaseNameOut (sysname OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Enthält den konfigurierten Zielnamen, sobald die Konfiguration gelesen wurde, auch wenn der Collector deaktiviert ist. Empfang über sysname-kompatible Variable und OUTPUT.
- @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert AVAILABLE. Empfang über varchar(40)-kompatible Variable und OUTPUT. Die kanonischen lokalen Ergebnisse sind AVAILABLE, INVALID_PARAMETER, TARGET_UNAVAILABLE, DENIED_PERMISSION, DISABLED, SKIPPED_CONCURRENT, SKIPPED_NOT_DUE, STOPPED_SIZE_BUDGET, PARTIAL, UNAVAILABLE_OBJECT und ERROR_HANDLED. AVAILABLE_LIMITED ist kein Endstatus dieses Aufrufers; der Purge-Status wird nur als akzeptiertes Zwischenergebnis ausgewertet. Bei erfolgreichem Backendabschluss wird dessen Status weitergereicht; die Aufrufstelle erzwingt keine eigene Allowlist aller Backendstatus und garantiert daher keine beliebige Statusmenge eines installierten Backends.
- @IsPartialOut (bit OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert 0. Frühe Abbrüche und Fehlerpfade setzen 1; bei erfolgreichem Backendabschluss wird dessen Wert übernommen. Empfang über bit-kompatible Variable und OUTPUT.
- @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine erkannte Fehlernummer oder bleibt NULL; nicht jeder Statuspfad setzt eine Nummer. Empfang über int-kompatible Variable und OUTPUT.
- @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine Diagnose oder bleibt NULL. Empfang über Unicode-Variable mit bis zu 2048 Zeichen und OUTPUT.

Ohne Rückgabe kann jeder obligatorische OUTPUT-Parameter als typisierter Wert oder NULL übergeben werden. Eine Empfangsvariable und OUTPUT oder OUT sind nur erforderlich, um den Ausgangswert zurückzulesen. Für numerische und zeitbezogene Typen ist Leertext keine unterstützte Eingabeform; textuelle Eingangswerte der OUTPUT-Parameter einschließlich Leertext werden durch die Initialisierung ersetzt.

#### InternalRunSnapshotWaitStatsCycle – Ablauf und Scheduler

Nach der Eingabeprüfung liest die Procedure Targetname und Enabled-Konfiguration. Eine fehlende Konfigurationszeile oder ein nicht aktiviertes Snapshotpaket führt zu DISABLED; ein aktiviertes, aber nicht verfügbares Datenbankziel wird anschließend gesondert geprüft. Anschließend bestimmt sie den tatsächlichen Frameworkdatenbanknamen und beansprucht mit einer Session-Exclusive-Applock und Timeout 0 die gemeinsame Paketressource SQL_Server_Analyze.SC023.CollectionCycle. Dieselbe Ressource schützt den Purge. Jeder negative Rückgabewert der Lockanforderung führt zu SKIPPED_CONCURRENT; daraus wird keine genaue Blockerursache abgeleitet.

Der Schedulerwert wird an die Policy- und Capture-Vorbereitung weitergegeben und beim Capture als Herkunftslabel gespeichert. Zulässig sind MANUAL, EXTERNAL und SQL_AGENT; die Procedure plant keine Ausführung. RunEvenIfNotDue=1 umgeht nur den Due-Check. Es deaktiviert weder den Collector noch umgeht es Targetidentität, Budgetgrenze oder Applock.

Die Procedure prüft zuerst die Targetidentität, führt eine schreibfreie PolicyOnly-Prüfung aus und akzeptiert danach den Purge mit AVAILABLE, AVAILABLE_LIMITED oder SKIPPED_NOT_DUE. Diese drei Purge-Ergebnisse erlauben die Fortsetzung. AVAILABLE_LIMITED wird nur als Purge-Zwischenergebnis ausgewertet; SKIPPED_NOT_DUE kann später unabhängig davon aus der Capture-Vorbereitung als Endstatus zurückkommen. Anschließend prüft sie die Targetidentität erneut und ruft die normale Vorbereitung auf. Ein Purge, der noch nicht fällig ist, verhindert den Capture nicht. Die normale Vorbereitung kann unter anderem DISABLED, STOPPED_SIZE_BUDGET oder SKIPPED_NOT_DUE liefern; RunEvenIfNotDue übergeht davon ausschließlich den Due-Check.

#### InternalRunSnapshotWaitStatsCycle – Quelle und Abschluss

Bei erfolgreicher Vorbereitung liest die Procedure genau einmal die vollständige native DMV sys.dm_os_wait_stats. MaxRows begrenzt ausschließlich die Writes im Backend und kürzt diese Enumeration nicht. Ein leerer Quellread wird intern als EMPTY_UNPROVEN markiert; ein erfolgreich persistierter vollständiger Quellread wird als PARTIAL mit Vergleichsstatuscode abgeschlossen; AVAILABLE wird dabei nicht als erfolgreicher Abschluss gemeldet. Vorher-/Nachher-Enginekontext und Messfenster dokumentieren den Read, beweisen jedoch weder eine atomare DMV-Sicht noch ununterbrochene Resetkontinuität.

Der Aufrufer muss die kompatiblen temporären Tabellen #RunSnapshotCollectionCycle_Run und #RunSnapshotCollectionCycle_Modules vor dem Aufruf bereitstellen. Diese Procedure erstellt kein DDL. Fehlt eine Tabelle oder scheitert die Projektion, wird der Fehler behandelt; ein partieller Modulnachweis wird bestmöglich geschrieben. Die Run-Projektion erfordert einen passenden eigenen WAIT_STATS-Lauf. Ein nachträglicher Projektions- oder Sperrfreigabefehler macht einen bereits committeten Backendlauf nicht rückgängig. Die ausgegebene Run-ID ist kein Finalisierungsbeweis.

Bei einem Fehler rollt der CATCH eine aktive Transaktion zurück. Ein Fehler bei der Freigabe der gehaltenen Applock überschreibt die Fehlerausgabe mit ERROR_HANDLED. Es gibt keinen Legacy-Abschluss und keine künstliche Nullprojektion. Der Modulnachweis ist Best Effort; scheitert auch er, bleiben die maßgeblichen Fehlerausgaben erhalten.

Die geschlossenen lokalen Ergebniswerte beschreiben die hier implementierten Zweige. An Backend und Helfer weitergereichte Statuswerte werden nicht durch eine lokale vollständige Allowlist beschränkt; daraus folgt keine Garantie für beliebige Statuswerte einer installierten Version.
#### InternalRunSnapshotWaitStatsCycle – Statusbedeutung

Die folgenden Werte umfassen die aktuellen lokalen Zweige und kanonischen Helperergebnisse; weitergereichte Statuswerte werden an dieser Aufrufstelle nicht erneut vollständig begrenzt.

- AVAILABLE: Initialzustand oder weitergereichte Bestätigung; kein Beleg einer erfolgreich persistierten Waitaufnahme.
- INVALID_PARAMETER: Ungültige Scheduler-/Force-Eingabe, unzulässiger Transaktionskontext oder entsprechender Helperbefund.
- TARGET_UNAVAILABLE: Zielidentität, Paket oder erforderlicher Helpervertrag nicht bestätigt.
- DENIED_PERMISSION: Abgefangener oder weitergereichter Berechtigungsfehler.
- DISABLED: Snapshotpaket oder Wait-Collector nicht aktiviert.
- SKIPPED_CONCURRENT: Die Session-Applock wurde mit negativem Rückgabewert nicht bestätigt.
- SKIPPED_NOT_DUE: Die Capture-Vorbereitung hat die Aufnahme wegen noch nicht erreichter Fälligkeit übersprungen.
- STOPPED_SIZE_BUDGET: Die Vorbereitung bestätigt die zulässige Größenbudgetgrenze nicht.
- PARTIAL: Der kanonische Waitabschluss hat die Aufnahme gespeichert; Vergleichskandidaten beweisen keine ununterbrochene Resetkontinuität.
- UNAVAILABLE_OBJECT: Die native Quelle meldet ein nicht verfügbares Objekt; das Backend übernimmt den Quellfehler.
- ERROR_HANDLED: Sonstiger behandelter Ablauf-, Backend-, Projektions- oder Sperrfreigabefehler.

*/
-- USAGE_SKILL_BEGIN monitor.InternalRunSnapshotWaitStatsCycle 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.InternalRunSnapshotWaitStatsCycle"
-- schema_name: "monitor"
-- object_name: "InternalRunSnapshotWaitStatsCycle"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "framework"
-- is_internal: true
-- description: "Die Procedure orchestriert einen nativen Wait-Snapshot für ein konfiguriertes Target und übergibt ihn dem gebundenen Backend."
-- source_path: "Code/10_SnapshotBaseline/085_InternalRunSnapshotWaitStatsCycle.sql"
-- ---
-- 
-- # monitor.InternalRunSnapshotWaitStatsCycle
-- 
-- ## Zweck und Einsatz
-- 
-- Die Procedure orchestriert einen nativen Wait-Snapshot für ein konfiguriertes Target und übergibt ihn dem gebundenen Backend.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalRunSnapshotWaitStatsCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[monitor].[SnapshotTargetConfiguration]`, `[master].[sys].[databases]`, `[sys].[sp_getapplock]`, `[monitor].[InternalValidateSnapshotWaitTarget]`, `[snapshot].[InternalPrepareCollectionCycle]`, `[sys].[sp_executesql]`, `[snapshot].[InternalPurgeExpiredData]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @SchedulerType | varchar(16) | ja | kein Default |
-- | @RunEvenIfNotDue | bit | ja | kein Default |
-- | @CaptureRunIdOut | bigint OUTPUT | ja | kein Default |
-- | @TargetDatabaseNameOut | sysname OUTPUT | ja | kein Default |
-- | @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |
-- | @IsPartialOut | bit OUTPUT | ja | kein Default |
-- | @ErrorNumberOut | int OUTPUT | ja | kein Default |
-- | @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@SchedulerType:** - @SchedulerType (varchar(16); Default: Kein Default): erforderlich; erlaubt sind MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) und SQL_AGENT (SQL Server Agent). Der Wert dient als Herkunftslabel und startet oder prüft keinen Scheduler. NULL oder ein anderer, nach gewöhnlichem SQL-Server-Zeichenkettenvergleich abweichender Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich verwendet die Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können daher gleichwertig sein. Es erfolgt keine binäre Prüfung oder Trimmen/Normalisierung. Leertext ist kein gültiger Wert.
-- 
-- **@RunEvenIfNotDue:** - @RunEvenIfNotDue (bit; Default: Kein Default): erforderlich; 0 wendet die Fälligkeitsprüfung an, 1 umgeht ausschließlich diese Prüfung. NULL führt zu INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte Bit-Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben wirksam.
-- 
-- **@CaptureRunIdOut:** - @CaptureRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Beim vorbereiteten Capture kann die ID nach dessen INSERT ausgegeben werden. Die ID allein bestätigt weder erfolgreichen Quellread noch erfolgreiche Finalisierung. Empfang über bigint-Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@TargetDatabaseNameOut:** - @TargetDatabaseNameOut (sysname OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Enthält den konfigurierten Zielnamen, sobald die Konfiguration gelesen wurde, auch wenn der Collector deaktiviert ist. Empfang über sysname-kompatible Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@StatusCodeOut:** - @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert AVAILABLE. Empfang über varchar(40)-kompatible Variable und OUTPUT. Die kanonischen lokalen Ergebnisse sind AVAILABLE, INVALID_PARAMETER, TARGET_UNAVAILABLE, DENIED_PERMISSION, DISABLED, SKIPPED_CONCURRENT, SKIPPED_NOT_DUE, STOPPED_SIZE_BUDGET, PARTIAL, UNAVAILABLE_OBJECT und ERROR_HANDLED. AVAILABLE_LIMITED ist kein Endstatus dieses Aufrufers; der Purge-Status wird nur als akzeptiertes Zwischenergebnis ausgewertet. Bei erfolgreichem Backendabschluss wird dessen Status weitergereicht; die Aufrufstelle erzwingt keine eigene Allowlist aller Backendstatus und garantiert daher keine beliebige Statusmenge eines installierten Backends. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@IsPartialOut:** - @IsPartialOut (bit OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert 0. Frühe Abbrüche und Fehlerpfade setzen 1; bei erfolgreichem Backendabschluss wird dessen Wert übernommen. Empfang über bit-kompatible Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorNumberOut:** - @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine erkannte Fehlernummer oder bleibt NULL; nicht jeder Statuspfad setzt eine Nummer. Empfang über int-kompatible Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorMessageOut:** - @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine Diagnose oder bleibt NULL. Empfang über Unicode-Variable mit bis zu 2048 Zeichen und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Kein Fach-Resultset. `@CaptureRunIdOut bigint`, `@TargetDatabaseNameOut sysname`, `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` dokumentieren Vorbereitung, gebundenes Ziel und Abschluss des WaitStats-Zyklus. Eine ausgegebene Run-ID oder ein Zielname allein bestätigt keine erfolgreiche Quellaufnahme/Finalisierung; Status, Partial und Fehler bleiben maßgeblich.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalRunSnapshotWaitStatsCycle';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [monitor].[InternalRunSnapshotWaitStatsCycle] @SchedulerType=NULL, @RunEvenIfNotDue=NULL, @CaptureRunIdOut=NULL, @TargetDatabaseNameOut=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- - @SchedulerType (varchar(16); Default: Kein Default): erforderlich; erlaubt sind MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) und SQL_AGENT (SQL Server Agent). Der Wert dient als Herkunftslabel und startet oder prüft keinen Scheduler. NULL oder ein anderer, nach gewöhnlichem SQL-Server-Zeichenkettenvergleich abweichender Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich verwendet die Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können daher gleichwertig sein. Es erfolgt keine binäre Prüfung oder Trimmen/Normalisierung. Leertext ist kein gültiger Wert.
-- - @RunEvenIfNotDue (bit; Default: Kein Default): erforderlich; 0 wendet die Fälligkeitsprüfung an, 1 umgeht ausschließlich diese Prüfung. NULL führt zu INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte Bit-Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben wirksam.
-- - @CaptureRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Beim vorbereiteten Capture kann die ID nach dessen INSERT ausgegeben werden. Die ID allein bestätigt weder erfolgreichen Quellread noch erfolgrei
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : monitor.InternalRunSnapshotWaitStatsCycle
-- Version      : 1.0.0
-- Stand        : 2026-10-25
-- Zweck        : Die Procedure orchestriert einen nativen Wait-Snapshot für ein
--                konfiguriertes Target und übergibt ihn dem gebundenen Backend.
-- Grenze       : Ein vollständiger DMV-Read sowie gleicher Enginekontext davor
--                und danach beweisen weder atomare Sicht noch Resetkontinuität.
-- ===============================================================================
-- 
-- #### InternalRunSnapshotWaitStatsCycle – Parameterverträge
-- 
-- Alle acht Parameter sind erforderlich und besitzen keinen Default. Die ersten zwei sind Eingaben; die sechs OUTPUT-Parameter müssen auch dann gebunden werden, wenn ihre Ausgabe verworfen wird. Zum Empfangen bindet der Aufrufer eine Variable passenden Typs mit OUTPUT. Eingehende Werte der OUTPUT-Parameter werden ignoriert und beim Eintritt initialisiert.
-- 
-- - @SchedulerType (varchar(16); Default: Kein Default): erforderlich; erlaubt sind MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) und SQL_AGENT (SQL Server Agent). Der Wert dient als Herkunftslabel und startet oder prüft keinen Scheduler. NULL oder ein anderer, nach gewöhnlichem SQL-Server-Zeichenkettenvergleich abweichender Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich verwendet die Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können daher gleichwertig sein. Es erfolgt keine binäre Prüfung oder Trimmen/Normalisierung. Leertext ist kein gültiger Wert.
-- - @RunEvenIfNotDue (bit; Default: Kein Default): erforderlich; 0 wendet die Fälligkeitsprüfung an, 1 umgeht ausschließlich diese Prüfung. NULL führt zu INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte Bit-Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben wirksam.
-- - @CaptureRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Beim vorbereiteten Capture kann die ID nach dessen INSERT ausgegeben werden. Die ID allein bestätigt weder erfolgreichen Quellread noch erfolgreiche Finalisierung. Empfang über bigint-Variable und OUTPUT.
-- - @TargetDatabaseNameOut (sysname OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Enthält den konfigurierten Zielnamen, sobald die Konfiguration gelesen wurde, auch wenn der Collector deaktiviert ist. Empfang über sysname-kompatible Variable und OUTPUT.
-- - @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert AVAILABLE. Empfang über varchar(40)-kompatible Variable und OUTPUT. Die kanonischen lokalen Ergebnisse sind AVAILABLE, INVALID_PARAMETER, TARGET_UNAVAILABLE, DENIED_PERMISSION, DISABLED, SKIPPED_CONCURRENT, SKIPPED_NOT_DUE, STOPPED_SIZE_BUDGET, PARTIAL, UNAVAILABLE_OBJECT und ERROR_HANDLED. AVAILABLE_LIMITED ist kein Endstatus dieses Aufrufers; der Purge-Status wird nur als akzeptiertes Zwischenergebnis ausgewertet. Bei erfolgreichem Backendabschluss wird dessen Status weitergereicht; die Aufrufstelle erzwingt keine eigene Allowlist aller Backendstatus und garantiert daher keine beliebige Statusmenge eines installierten Backends.
-- - @IsPartialOut (bit OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert 0. Frühe Abbrüche und Fehlerpfade setzen 1; bei erfolgreichem Backendabschluss wird dessen Wert übernommen. Empfang über bit-kompatible Variable und OUTPUT.
-- - @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine erkannte Fehlernummer oder bleibt NULL; nicht jeder Statuspfad setzt eine Nummer. Empfang über int-kompatible Variable und OUTPUT.
-- - @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine Diagnose oder bleibt NULL. Empfang über Unicode-Variable mit bis zu 2048 Zeichen und OUTPUT.
-- 
-- Ohne Rückgabe kann jeder obligatorische OUTPUT-Parameter als typisierter Wert oder NULL übergeben werden. Eine Empfangsvariable und OUTPUT oder OUT sind nur erforderlich, um den Ausgangswert zurückzulesen. Für numerische und zeitbezogene Typen ist Leertext keine unterstützte Eingabeform; textuelle Eingangswerte der OUTPUT-Parameter einschließlich Leertext werden durch die Initialisierung ersetzt.
-- 
-- #### InternalRunSnapshotWaitStatsCycle – Ablauf und Scheduler
-- 
-- Nach der Eingabeprüfung liest die Procedure Targetname und Enabled-Konfiguration. Eine fehlende Konfigurationszeile oder ein nicht aktiviertes Snapshotpaket führt zu DISABLED; ein aktiviertes, aber nicht verfügbares Datenbankziel wird anschließend gesondert geprüft. Anschließend bestimmt sie den tatsächlichen Frameworkdatenbanknamen und beansprucht mit einer Session-Exclusive-Applock und Timeout 0 die gemeinsame Paketressource SQL_Server_Analyze.SC023.CollectionCycle. Dieselbe Ressource schützt den Purge. Jeder negative Rückgabewert der Lockanforderung führt zu SKIPPED_CONCURRENT; daraus wird keine genaue Blockerursache abgeleitet.
-- 
-- Der Schedulerwert wird an die Policy- und Capture-Vorbereitung weitergegeben und beim Capture als Herkunftslabel gespeichert. Zulässig sind MANUAL, EXTERNAL und SQL_AGENT; die Procedure plant keine Ausführung. RunEvenIfNotDue=1 umgeht nur den Due-Check. Es deaktiviert weder den Collector noch umgeht es Targetidentität, Budgetgrenze oder Applock.
-- 
-- Die Procedure prüft zuerst die Targetidentität, führt eine schreibfreie PolicyOnly-Prüfung aus und akzeptiert danach den Purge mit AVAILABLE, AVAILABLE_LIMITED oder SKIPPED_NOT_DUE. Diese drei Purge-Ergebnisse erlauben die Fortsetzung. AVAILABLE_LIMITED wird nur als Purge-Zwischenergebnis ausgewertet; SKIPPED_NOT_DUE kann später unabhängig davon aus der Capture-Vorbereitung als Endstatus zurückkommen. Anschließend prüft sie die Targetidentität erneut und ruft die normale Vorbereitung auf. Ein Purge, der noch nicht fällig ist, verhindert den Capture nicht. Die normale Vorbereitung kann unter anderem DISABLED, STOPPED_SIZE_BUDGET oder SKIPPED_NOT_DUE liefern; RunEvenIfNotDue übergeht davon ausschließlich den Due-Check.
-- 
-- #### InternalRunSnapshotWaitStatsCycle – Quelle und Abschluss
-- 
-- Bei erfolgreicher Vorbereitung liest die Procedure genau einmal die vollständige native DMV sys.dm_os_wait_stats. MaxRows begrenzt ausschließlich die Writes im Backend und kürzt diese Enumeration nicht. Ein leerer Quellread wird intern als EMPTY_UNPROVEN markiert; ein erfolgreich persistierter vollständiger Quellread wird als PARTIAL mit Vergleichsstatuscode abgeschlossen; AVAILABLE wird dabei nicht als erfolgreicher Abschluss gemeldet. Vorher-/Nachher-Enginekontext und Messfenster dokumentieren den Read, beweisen jedoch weder eine atomare DMV-Sicht noch ununterbrochene Resetkontinuität.
-- 
-- Der Aufrufer muss die kompatiblen temporären Tabellen #RunSnapshotCollectionCycle_Run und #RunSnapshotCollectionCycle_Modules vor dem Aufruf bereitstellen. Diese Procedure erstellt kein DDL. Fehlt eine Tabelle oder scheitert die Projektion, wird der Fehler behandelt; ein partieller Modulnachweis wird bestmöglich geschrieben. Die Run-Projektion erfordert einen passenden eigenen WAIT_STATS-Lauf. Ein nachträglicher Projektions- oder Sperrfreigabefehler macht einen bereits committeten Backendlauf nicht rückgängig. Die ausgegebene Run-ID ist kein Finalisierungsbeweis.
-- 
-- Bei einem Fehler rollt der CATCH eine aktive Transaktion zurück. Ein Fehler bei der Freigabe der gehaltenen Applock überschreibt die Fehlerausgabe mit ERROR_HANDLED. Es gibt keinen Legacy-Abschluss und keine künstliche Nullprojektion. Der Modulnachweis ist Best Effort; scheitert auch er, bleiben die maßgeblichen Fehlerausgaben erhalten.
-- 
-- Die geschlossenen lokalen Ergebniswerte beschreiben die hier implementierten Zweige. An Backend und Helfer weitergereichte Statuswerte werden nicht durch eine lokale vollständige Allowlist beschränkt; daraus folgt keine Garantie für beliebige Statuswerte einer installierten Version.
-- #### InternalRunSnapshotWaitStatsCycle – Statusbedeutung
-- 
-- Die folgenden Werte umfassen die aktuellen lokalen Zweige und kanonischen Helperergebnisse; weitergereichte Statuswerte werden an dieser Aufrufstelle nicht erneut vollständig begrenzt.
-- 
-- - AVAILABLE: Initialzustand oder weitergereichte Bestätigung; kein Beleg einer erfolgreich persistierten Waitaufnahme.
-- - INVALID_PARAMETER: Ungültige Scheduler-/Force-Eingabe, unzulässiger Transaktionskontext oder entsprechender Helperbefund.
-- - TARGET_UNAVAILABLE: Zielidentität, Paket oder erforderlicher Helpervertrag nicht bestätigt.
-- - DENIED_PERMISSION: Abgefangener oder weitergereichter Berechtigungsfehler.
-- - DISABLED: Snapshotpaket oder Wait-Collector nicht aktiviert.
-- - SKIPPED_CONCURRENT: Die Session-Applock wurde mit negativem Rückgabewert nicht bestätigt.
-- - SKIPPED_NOT_DUE: Die Capture-Vorbereitung hat die Aufnahme wegen noch nicht erreichter Fälligkeit übersprungen.
-- - STOPPED_SIZE_BUDGET: Die Vorbereitung bestätigt die zulässige Größenbudgetgrenze nicht.
-- - PARTIAL: Der kanonische Waitabschluss hat die Aufnahme gespeichert; Vergleichskandidaten beweisen keine ununterbrochene Resetkontinuität.
-- - UNAVAILABLE_OBJECT: Die native Quelle meldet ein nicht verfügbares Objekt; das Backend übernimmt den Quellfehler.
-- - ERROR_HANDLED: Sonstiger behandelter Ablauf-, Backend-, Projektions- oder Sperrfreigabefehler.
-- ```
-- 
-- USAGE_SKILL_END monitor.InternalRunSnapshotWaitStatsCycle
CREATE OR ALTER PROCEDURE [monitor].[InternalRunSnapshotWaitStatsCycle]
      @SchedulerType varchar(16)
    , @RunEvenIfNotDue bit
    , @CaptureRunIdOut bigint OUTPUT
    , @TargetDatabaseNameOut sysname OUTPUT
    , @StatusCodeOut varchar(40) OUTPUT
    , @IsPartialOut bit OUTPUT
    , @ErrorNumberOut int OUTPUT
    , @ErrorMessageOut nvarchar(2048) OUTPUT
    , @Hilfe bit = 0
AS
BEGIN
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN monitor.InternalRunSnapshotWaitStatsCycle
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'monitor') AS [SchemaName],CONVERT(sysname,N'InternalRunSnapshotWaitStatsCycle') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "monitor.InternalRunSnapshotWaitStatsCycle"'
            + NCHAR(10)
            + N'schema_name: "monitor"'
            + NCHAR(10)
            + N'object_name: "InternalRunSnapshotWaitStatsCycle"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "framework"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Die Procedure orchestriert einen nativen Wait-Snapshot für ein konfiguriertes Target und übergibt ihn dem gebundenen Backend."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/085_InternalRunSnapshotWaitStatsCycle.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# monitor.InternalRunSnapshotWaitStatsCycle'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure orchestriert einen nativen Wait-Snapshot für ein konfiguriertes Target und übergibt ihn dem gebundenen Backend.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalRunSnapshotWaitStatsCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[monitor].[SnapshotTargetConfiguration]`, `[master].[sys].[databases]`, `[sys].[sp_getapplock]`, `[monitor].[InternalValidateSnapshotWaitTarget]`, `[snapshot].[InternalPrepareCollectionCycle]`, `[sys].[sp_executesql]`, `[snapshot].[InternalPurgeExpiredData]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'| @SchedulerType | varchar(16) | ja | kein Default |'
            + NCHAR(10)
            + N'| @RunEvenIfNotDue | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @CaptureRunIdOut | bigint OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @TargetDatabaseNameOut | sysname OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @IsPartialOut | bit OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorNumberOut | int OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |'
            + NCHAR(10)
            + N'| @Hilfe | bit | nein | 0 |'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SchedulerType:** - @SchedulerType (varchar(16); Default: Kein Default): erforderlich; erlaubt sind MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) und SQL_AGENT (SQL Server Agent). Der Wert dient als Herkunftslabel und startet oder prüft keinen Scheduler. NULL oder ein anderer, nach gewöhnlichem SQL-Server-Zeichenkettenvergleich abweichender Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich verwendet die Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können daher gleichwertig sein. Es erfolgt keine binäre Prüfung oder Trimmen/Normalisierung. Leertext ist kein gültiger Wert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@RunEvenIfNotDue:** - @RunEvenIfNotDue (bit; Default: Kein Default): erforderlich; 0 wendet die Fälligkeitsprüfung an, 1 umgeht ausschließlich diese Prüfung. NULL führt zu INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte Bit-Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben wirksam.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CaptureRunIdOut:** - @CaptureRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Beim vorbereiteten Capture kann die ID nach dessen INSERT ausgegeben werden. Die ID allein bestätigt weder erfolgreichen Quellread noch erfolgreiche Finalisierung. Empfang über bigint-Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@TargetDatabaseNameOut:** - @TargetDatabaseNameOut (sysname OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Enthält den konfigurierten Zielnamen, sobald die Konfiguration gelesen wurde, auch wenn der Collector deaktiviert ist. Empfang über sysname-kompatible Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** - @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert AVAILABLE. Empfang über varchar(40)-kompatible Variable und OUTPUT. Die kanonischen lokalen Ergebnisse sind AVAILABLE, INVALID_PARAMETER, TARGET_UNAVAILABLE, DENIED_PERMISSION, DISABLED, SKIPPED_CONCURRENT, SKIPPED_NOT_DUE, STOPPED_SIZE_BUDGET, PARTIAL, UNAVAILABLE_OBJECT und ERROR_HANDLED. AVAILABLE_LIMITED ist kein Endstatus dieses Aufrufers; der Purge-Status wird nur als akzeptiertes Zwischenergebnis ausgewertet. Bei erfolgreichem Backendabschluss wird dessen Status weitergereicht; die Aufrufstelle erzwingt keine eigene Allowlist aller Backendstatus und garantiert daher keine beliebige Statusmenge eines installierten Backends. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** - @IsPartialOut (bit OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert 0. Frühe Abbrüche und Fehlerpfade setzen 1; bei erfolgreichem Backendabschluss wird dessen Wert übernommen. Empfang über bit-kompatible Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** - @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine erkannte Fehlernummer oder bleibt NULL; nicht jeder Statuspfad setzt eine Nummer. Empfang über int-kompatible Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** - @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine Diagnose oder bleibt NULL. Empfang über Unicode-Variable mit bis zu 2048 Zeichen und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. `@CaptureRunIdOut bigint`, `@TargetDatabaseNameOut sysname`, `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` dokumentieren Vorbereitung, gebundenes Ziel und Abschluss des WaitStats-Zyklus. Eine ausgegebene Run-ID oder ein Zielname allein bestätigt keine erfolgreiche Quellaufnahme/Finalisierung; Status, Partial und Fehler bleiben maßgeblich.'
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
            + N'WHERE [SchemaName]=N''monitor'' AND [ObjectName]=N''InternalRunSnapshotWaitStatsCycle'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [monitor].[InternalRunSnapshotWaitStatsCycle] @SchedulerType=NULL, @RunEvenIfNotDue=NULL, @CaptureRunIdOut=NULL, @TargetDatabaseNameOut=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'- @SchedulerType (varchar(16); Default: Kein Default): erforderlich; erlaubt sind MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) und SQL_AGENT (SQL Server Agent). Der Wert dient als Herkunftslabel und startet oder prüft keinen Scheduler. NULL oder ein anderer, nach gewöhnlichem SQL-Server-Zeichenkettenvergleich abweichender Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich verwendet die Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können daher gleichwertig sein. Es erfolgt keine binäre Prüfung oder Trimmen/Normalisierung. Leertext ist kein gültiger Wert.'
            + NCHAR(10)
            + N'- @RunEvenIfNotDue (bit; Default: Kein Default): erforderlich; 0 wendet die Fälligkeitsprüfung an, 1 umgeht ausschließlich diese Prüfung. NULL führt zu INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte Bit-Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben wirksam.'
            + NCHAR(10)
            + N'- @CaptureRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Beim vorbereiteten Capture kann die ID nach dessen INSERT ausgegeben werden. Die ID allein bestätigt weder erfolgreichen Quellread noch erfolgrei'
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
            + N'Objekt       : monitor.InternalRunSnapshotWaitStatsCycle'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-10-25'
            + NCHAR(10)
            + N'Zweck        : Die Procedure orchestriert einen nativen Wait-Snapshot für ein'
            + NCHAR(10)
            + N'               konfiguriertes Target und übergibt ihn dem gebundenen Backend.'
            + NCHAR(10)
            + N'Grenze       : Ein vollständiger DMV-Read sowie gleicher Enginekontext davor'
            + NCHAR(10)
            + N'               und danach beweisen weder atomare Sicht noch Resetkontinuität.'
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + NCHAR(10)
            + N'#### InternalRunSnapshotWaitStatsCycle – Parameterverträge'
            + NCHAR(10)
            + NCHAR(10)
            + N'Alle acht Parameter sind erforderlich und besitzen keinen Default. Die ersten zwei sind Eingaben; die sechs OUTPUT-Parameter müssen auch dann gebunden werden, wenn ihre Ausgabe verworfen wird. Zum Empfangen bindet der Aufrufer eine Variable passenden Typs mit OUTPUT. Eingehende Werte der OUTPUT-Parameter werden ignoriert und beim Eintritt initialisiert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'- @SchedulerType (varchar(16); Default: Kein Default): erforderlich; erlaubt sind MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) und SQL_AGENT (SQL Server Agent). Der Wert dient als Herkunftslabel und startet oder prüft keinen Scheduler. NULL oder ein anderer, nach gewöhnlichem SQL-Server-Zeichenkettenvergleich abweichender Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich verwendet die Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können daher gleichwertig sein. Es erfolgt keine binäre Prüfung oder Trimmen/Normalisierung. Leertext ist kein gültiger Wert.'
            + NCHAR(10)
            + N'- @RunEvenIfNotDue (bit; Default: Kein Default): erforderlich; 0 wendet die Fälligkeitsprüfung an, 1 umgeht ausschließlich diese Prüfung. NULL führt zu INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte Bit-Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben wirksam.'
            + NCHAR(10)
            + N'- @CaptureRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Beim vorbereiteten Capture kann die ID nach dessen INSERT ausgegeben werden. Die ID allein bestätigt weder erfolgreichen Quellread noch erfolgreiche Finalisierung. Empfang über bigint-Variable und OUTPUT.'
            + NCHAR(10)
            + N'- @TargetDatabaseNameOut (sysname OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Enthält den konfigurierten Zielnamen, sobald die Konfiguration gelesen wurde, auch wenn der Collector deaktiviert ist. Empfang über sysname-kompatible Variable und OUTPUT.'
            + NCHAR(10)
            + N'- @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert AVAILABLE. Empfang über varchar(40)-kompatible Variable und OUTPUT. Die kanonischen lokalen Ergebnisse sind AVAILABLE, INVALID_PARAMETER, TARGET_UNAVAILABLE, DENIED_PERMISSION, DISABLED, SKIPPED_CONCURRENT, SKIPPED_NOT_DUE, STOPPED_SIZE_BUDGET, PARTIAL, UNAVAILABLE_OBJECT und ERROR_HANDLED. AVAILABLE_LIMITED ist kein Endstatus dieses Aufrufers; der Purge-Status wird nur als akzeptiertes Zwischenergebnis ausgewertet. Bei erfolgreichem Backendabschluss wird dessen Status weitergereicht; die Aufrufstelle erzwingt keine eigene Allowlist aller Backendstatus und garantiert daher keine beliebige Statusmenge eines installierten Backends.'
            + NCHAR(10)
            + N'- @IsPartialOut (bit OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert 0. Frühe Abbrüche und Fehlerpfade setzen 1; bei erfolgreichem Backendabschluss wird dessen Wert übernommen. Empfang über bit-kompatible Variable und OUTPUT.'
            + NCHAR(10)
            + N'- @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine erkannte Fehlernummer oder bleibt NULL; nicht jeder Statuspfad setzt eine Nummer. Empfang über int-kompatible Variable und OUTPUT.'
            + NCHAR(10)
            + N'- @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine Diagnose oder bleibt NULL. Empfang über Unicode-Variable mit bis zu 2048 Zeichen und OUTPUT.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ohne Rückgabe kann jeder obligatorische OUTPUT-Parameter als typisierter Wert oder NULL übergeben werden. Eine Empfangsvariable und OUTPUT oder OUT sind nur erforderlich, um den Ausgangswert zurückzulesen. Für numerische und zeitbezogene Typen ist Leertext keine unterstützte Eingabeform; textuelle Eingangswerte der OUTPUT-Parameter einschließlich Leertext werden durch die Initialisierung ersetzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'#### InternalRunSnapshotWaitStatsCycle – Ablauf und Scheduler'
            + NCHAR(10)
            + NCHAR(10)
            + N'Nach der Eingabeprüfung liest die Procedure Targetname und Enabled-Konfiguration. Eine fehlende Konfigurationszeile oder ein nicht aktiviertes Snapshotpaket führt zu DISABLED; ein aktiviertes, aber nicht verfügbares Datenbankziel wird anschließend gesondert geprüft. Anschließend bestimmt sie den tatsächlichen Frameworkdatenbanknamen und beansprucht mit einer Session-Exclusive-Applock und Timeout 0 die gemeinsame Paketressource SQL_Server_Analyze.SC023.CollectionCycle. Dieselbe Ressource schützt den Purge. Jeder negative Rückgabewert der Lockanforderung führt zu SKIPPED_CONCURRENT; daraus wird keine genaue Blockerursache abgeleitet.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Schedulerwert wird an die Policy- und Capture-Vorbereitung weitergegeben und beim Capture als Herkunftslabel gespeichert. Zulässig sind MANUAL, EXTERNAL und SQL_AGENT; die Procedure plant keine Ausführung. RunEvenIfNotDue=1 umgeht nur den Due-Check. Es deaktiviert weder den Collector noch umgeht es Targetidentität, Budgetgrenze oder Applock.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die Procedure prüft zuerst die Targetidentität, führt eine schreibfreie PolicyOnly-Prüfung aus und akzeptiert danach den Purge mit AVAILABLE, AVAILABLE_LIMITED oder SKIPPED_NOT_DUE. Diese drei Purge-Ergebnisse erlauben die Fortsetzung. AVAILABLE_LIMITED wird nur als Purge-Zwischenergebnis ausgewertet; SKIPPED_NOT_DUE kann später unabhängig davon aus der Capture-Vorbereitung als Endstatus zurückkommen. Anschließend prüft sie die Targetidentität erneut und ruft die normale Vorbereitung auf. Ein Purge, der noch nicht fällig ist, verhindert den Capture nicht. Die normale Vorbereitung kann unter anderem DISABLED, STOPPED_SIZE_BUDGET oder SKIPPED_NOT_DUE liefern; RunEvenIfNotDue übergeht davon ausschließlich den Due-Check.'
            + NCHAR(10)
            + NCHAR(10)
            + N'#### InternalRunSnapshotWaitStatsCycle – Quelle und Abschluss'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei erfolgreicher Vorbereitung liest die Procedure genau einmal die vollständige native DMV sys.dm_os_wait_stats. MaxRows begrenzt ausschließlich die Writes im Backend und kürzt diese Enumeration nicht. Ein leerer Quellread wird intern als EMPTY_UNPROVEN markiert; ein erfolgreich persistierter vollständiger Quellread wird als PARTIAL mit Vergleichsstatuscode abgeschlossen; AVAILABLE wird dabei nicht als erfolgreicher Abschluss gemeldet. Vorher-/Nachher-Enginekontext und Messfenster dokumentieren den Read, beweisen jedoch weder eine atomare DMV-Sicht noch ununterbrochene Resetkontinuität.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der Aufrufer muss die kompatiblen temporären Tabellen #RunSnapshotCollectionCycle_Run und #RunSnapshotCollectionCycle_Modules vor dem Aufruf bereitstellen. Diese Procedure erstellt kein DDL. Fehlt eine Tabelle oder scheitert die Projektion, wird der Fehler behandelt; ein partieller Modulnachweis wird bestmöglich geschrieben. Die Run-Projektion erfordert einen passenden eigenen WAIT_STATS-Lauf. Ein nachträglicher Projektions- oder Sperrfreigabefehler macht einen bereits committeten Backendlauf nicht rückgängig. Die ausgegebene Run-ID ist kein Finalisierungsbeweis.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Bei einem Fehler rollt der CATCH eine aktive Transaktion zurück. Ein Fehler bei der Freigabe der gehaltenen Applock überschreibt die Fehlerausgabe mit ERROR_HANDLED. Es gibt keinen Legacy-Abschluss und keine künstliche Nullprojektion. Der Modulnachweis ist Best Effort; scheitert auch er, bleiben die maßgeblichen Fehlerausgaben erhalten.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die geschlossenen lokalen Ergebniswerte beschreiben die hier implementierten Zweige. An Backend und Helfer weitergereichte Statuswerte werden nicht durch eine lokale vollständige Allowlist beschränkt; daraus folgt keine Garantie für beliebige Statuswerte einer installierten Version.'
            + NCHAR(10)
            + N'#### InternalRunSnapshotWaitStatsCycle – Statusbedeutung'
            + NCHAR(10)
            + NCHAR(10)
            + N'Die folgenden Werte umfassen die aktuellen lokalen Zweige und kanonischen Helperergebnisse; weitergereichte Statuswerte werden an dieser Aufrufstelle nicht erneut vollständig begrenzt.'
            + NCHAR(10)
            + NCHAR(10)
            + N'- AVAILABLE: Initialzustand oder weitergereichte Bestätigung; kein Beleg einer erfolgreich persistierten Waitaufnahme.'
            + NCHAR(10)
            + N'- INVALID_PARAMETER: Ungültige Scheduler-/Force-Eingabe, unzulässiger Transaktionskontext oder entsprechender Helperbefund.'
            + NCHAR(10)
            + N'- TARGET_UNAVAILABLE: Zielidentität, Paket oder erforderlicher Helpervertrag nicht bestätigt.'
            + NCHAR(10)
            + N'- DENIED_PERMISSION: Abgefangener oder weitergereichter Berechtigungsfehler.'
            + NCHAR(10)
            + N'- DISABLED: Snapshotpaket oder Wait-Collector nicht aktiviert.'
            + NCHAR(10)
            + N'- SKIPPED_CONCURRENT: Die Session-Applock wurde mit negativem Rückgabewert nicht bestätigt.'
            + NCHAR(10)
            + N'- SKIPPED_NOT_DUE: Die Capture-Vorbereitung hat die Aufnahme wegen noch nicht erreichter Fälligkeit übersprungen.'
            + NCHAR(10)
            + N'- STOPPED_SIZE_BUDGET: Die Vorbereitung bestätigt die zulässige Größenbudgetgrenze nicht.'
            + NCHAR(10)
            + N'- PARTIAL: Der kanonische Waitabschluss hat die Aufnahme gespeichert; Vergleichskandidaten beweisen keine ununterbrochene Resetkontinuität.'
            + NCHAR(10)
            + N'- UNAVAILABLE_OBJECT: Die native Quelle meldet ein nicht verfügbares Objekt; das Backend übernimmt den Quellfehler.'
            + NCHAR(10)
            + N'- ERROR_HANDLED: Sonstiger behandelter Ablauf-, Backend-, Projektions- oder Sperrfreigabefehler.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END monitor.InternalRunSnapshotWaitStatsCycle
        RETURN;
    END;

    SELECT @CaptureRunIdOut=NULL,@TargetDatabaseNameOut=NULL,@StatusCodeOut='AVAILABLE',
           @IsPartialOut=0,@ErrorNumberOut=NULL,@ErrorMessageOut=NULL;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0 OR @RunEvenIfNotDue IS NULL
       OR @SchedulerType IS NULL OR @SchedulerType NOT IN('MANUAL','EXTERNAL','SQL_AGENT')
    BEGIN
        SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011,
               @ErrorMessageOut=N'Der Waitlauf benötigt gültige Steuerwerte ohne Callertransaktion oder implizite Transaktionen.';
        RETURN 51011;
    END;
    SET NOCOUNT ON;
    SET LOCK_TIMEOUT 0;
    SET XACT_ABORT ON;
    DECLARE @TargetId int,@TargetCreated datetime,@CheckId int,@CheckCreated datetime,
            @TargetQuoted nvarchar(258),@SourceName sysname,@Enabled bit,
            @Sql nvarchar(max),@LockResult int,@LockHeld bit=0,@Unhandled bit=0,
            @Prepared bit=0,@CompletionReturned bit=0,@ProjectionFound bit=0,
            @AdmissionStatus varchar(40),@AdmissionError int,@AdmissionMessage nvarchar(2048),
            @PurgeId bigint,@PurgeStatus varchar(40),@PurgeBudget bit,@PurgeError int,@PurgeMessage nvarchar(2048),
            @PrepareStatus varchar(40),@PrepareMessage nvarchar(2048),@PolicyRun bigint,@PolicyCollect bit,
            @EngineName nvarchar(128),@EngineStart datetime,@EngineTicks bigint,
            @AfterName nvarchar(128),@AfterStart datetime,@AfterTicks bigint,
            @StartUtc datetime2(3),@EndUtc datetime2(3),@NativeRows bigint,
            @SourceStatus varchar(40),@SourcePartial bit,@SourceComplete bit,
            @SourceError int,@SourceMessage nvarchar(2048),@EngineJson nvarchar(max),@RowsJson nvarchar(max),@SourceJson nvarchar(max);
    DECLARE @WaitRows TABLE
    ([WaitType] nvarchar(60) COLLATE Latin1_General_100_BIN2 NOT NULL,
     [WaitingTasksCount] bigint NOT NULL,[WaitTimeMs] bigint NOT NULL,
     [MaxWaitTimeMs] bigint NOT NULL,[SignalWaitTimeMs] bigint NOT NULL);
    BEGIN TRY
        SELECT @TargetDatabaseNameOut=[TargetDatabaseName],@Enabled=[IsEnabled]
        FROM [monitor].[SnapshotTargetConfiguration] WHERE [ConfigurationId]=1;
        IF COALESCE(@Enabled,0)<>1
        BEGIN
            SELECT @StatusCodeOut='DISABLED',@IsPartialOut=1,@ErrorMessageOut=N'Das optionale Snapshotpaket ist nicht aktiviert.';
            GOTO WaitFinish;
        END;
        SELECT @SourceName=[name] FROM [master].[sys].[databases] WITH (NOLOCK) WHERE [database_id]=DB_ID();
        IF @SourceName IS NULL THROW 53764,N'Der tatsächliche Frameworkkontext ist nicht sichtbar.',1;
        EXEC @LockResult=[sys].[sp_getapplock]
         @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0,@DbPrincipal=N'public';
        IF @LockResult<0
        BEGIN
            SELECT @StatusCodeOut='SKIPPED_CONCURRENT',@IsPartialOut=1,
                   @ErrorMessageOut=N'Ein anderer Snapshotlauf oder Purge besitzt bereits die Paket-Applock.';
            GOTO WaitFinish;
        END;
        SET @LockHeld=1;
        EXEC [monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=@TargetDatabaseNameOut,@TargetDatabaseIdOut=@TargetId OUTPUT,@TargetCreateDateOut=@TargetCreated OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,@ErrorMessageOut=@AdmissionMessage OUTPUT;
        IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@AdmissionStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                   @ErrorNumberOut=@AdmissionError,@ErrorMessageOut=@AdmissionMessage;
            GOTO WaitFinish;
        END;
        SET @TargetQuoted=QUOTENAME(@TargetDatabaseNameOut);
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=@Source,@SchedulerType=@Scheduler,@RunEvenIfNotDue=@Force,@CollectorCode=''WAIT_STATS'',@PolicyOnly=1,
 @CaptureRunIdOut=@Run OUTPUT,@ShouldCollectOut=@Collect OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Source sysname,@Scheduler varchar(16),@Force bit,@Run bigint OUTPUT,@Collect bit OUTPUT,@Status varchar(40) OUTPUT,@Message nvarchar(2048) OUTPUT,@Id int,@Name sysname,@Created datetime',
 @Source=@SourceName,@Scheduler=@SchedulerType,@Force=@RunEvenIfNotDue,@Run=@PolicyRun OUTPUT,@Collect=@PolicyCollect OUTPUT,
 @Status=@PrepareStatus OUTPUT,@Message=@PrepareMessage OUTPUT,@Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated;
        IF @PolicyRun IS NOT NULL OR COALESCE(@PolicyCollect,0)<>0 THROW 53768,N'Die Policyprüfung bestätigt keinen schreibfreien Aufruf.',1;
        IF COALESCE(@PrepareStatus,'')<>'AVAILABLE'
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@PrepareStatus,''),'ERROR_HANDLED'),@IsPartialOut=1,@ErrorMessageOut=@PrepareMessage;
            GOTO WaitFinish;
        END;
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPurgeExpiredData]
 @MaxBatches=10,@Force=0,@PurgeRunIdOut=@Run OUTPUT,@StatusCodeOut=@Status OUTPUT,
 @BudgetExceededOut=@Budget OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Run bigint OUTPUT,@Status varchar(40) OUTPUT,@Budget bit OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT,@Id int,@Name sysname,@Created datetime',
 @Run=@PurgeId OUTPUT,@Status=@PurgeStatus OUTPUT,@Budget=@PurgeBudget OUTPUT,@Error=@PurgeError OUTPUT,@Message=@PurgeMessage OUTPUT,
 @Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated;
        IF COALESCE(@PurgeStatus,'') NOT IN('AVAILABLE','AVAILABLE_LIMITED','SKIPPED_NOT_DUE') OR @PurgeError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@PurgeStatus,''),'ERROR_HANDLED'),@IsPartialOut=1,
                   @ErrorNumberOut=@PurgeError,@ErrorMessageOut=@PurgeMessage;
            GOTO WaitFinish;
        END;
        EXEC [monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=@TargetDatabaseNameOut,@ExpectedTargetDatabaseId=@TargetId,@ExpectedTargetCreateDate=@TargetCreated,
         @TargetDatabaseIdOut=@CheckId OUTPUT,@TargetCreateDateOut=@CheckCreated OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,@ErrorMessageOut=@AdmissionMessage OUTPUT;
        IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@AdmissionStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                   @ErrorNumberOut=@AdmissionError,@ErrorMessageOut=@AdmissionMessage;
            GOTO WaitFinish;
        END;
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalPrepareCollectionCycle]
 @SourceDatabaseName=@Source,@SchedulerType=@Scheduler,@RunEvenIfNotDue=@Force,
 @CaptureRunIdOut=@Run OUTPUT,@ShouldCollectOut=@Collect OUTPUT,@StatusCodeOut=@Status OUTPUT,@ErrorMessageOut=@Message OUTPUT,
 @CollectorCode=''WAIT_STATS'',@ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Source sysname,@Scheduler varchar(16),@Force bit,@Run bigint OUTPUT,@Collect bit OUTPUT,@Status varchar(40) OUTPUT,@Message nvarchar(2048) OUTPUT,@Id int,@Name sysname,@Created datetime',
 @Source=@SourceName,@Scheduler=@SchedulerType,@Force=@RunEvenIfNotDue,@Run=@CaptureRunIdOut OUTPUT,@Collect=@Prepared OUTPUT,
 @Status=@PrepareStatus OUTPUT,@Message=@PrepareMessage OUTPUT,@Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated;
        IF COALESCE(@Prepared,0)<>1
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@PrepareStatus,''),'ERROR_HANDLED'),@IsPartialOut=1,@ErrorMessageOut=@PrepareMessage;
            GOTO WaitFinish;
        END;
        IF @CaptureRunIdOut IS NULL OR @CaptureRunIdOut<=0 THROW 53763,N'Die Vorbereitung bestätigt keinen eigenen Wait-Run.',1;
        EXEC [monitor].[InternalValidateSnapshotWaitTarget]
         @TargetDatabaseName=@TargetDatabaseNameOut,@ExpectedTargetDatabaseId=@TargetId,@ExpectedTargetCreateDate=@TargetCreated,
         @TargetDatabaseIdOut=@CheckId OUTPUT,@TargetCreateDateOut=@CheckCreated OUTPUT,
         @StatusCodeOut=@AdmissionStatus OUTPUT,@ErrorNumberOut=@AdmissionError OUTPUT,@ErrorMessageOut=@AdmissionMessage OUTPUT;
        IF COALESCE(@AdmissionStatus,'')<>'AVAILABLE' OR @AdmissionError IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut=COALESCE(NULLIF(@AdmissionStatus,''),'TARGET_UNAVAILABLE'),@IsPartialOut=1,
                   @ErrorNumberOut=@AdmissionError,@ErrorMessageOut=@AdmissionMessage,@Unhandled=1;
            GOTO WaitFinish;
        END;

        SELECT @SourceStatus='AVAILABLE',@SourcePartial=0,@SourceComplete=1,@SourceError=NULL,@SourceMessage=NULL,
               @StartUtc=SYSUTCDATETIME(),@EngineJson=NULL,@RowsJson=NULL,@NativeRows=NULL;
        BEGIN TRY
            SELECT @EngineName=CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),
                   @EngineStart=[sqlserver_start_time],@EngineTicks=[sqlserver_start_time_ms_ticks]
            FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
            IF @@ROWCOUNT<>1 OR @EngineName IS NULL OR DATALENGTH(@EngineName)=0 OR @EngineStart IS NULL OR @EngineTicks IS NULL OR @EngineTicks<0
                THROW 53767,N'Der native Enginekontext vor dem Waitread ist nicht vollständig.',1;
            -- Exactly one complete native enumeration; MaxRows limits only backend writes.
            INSERT @WaitRows ([WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs])
            SELECT [wait_type],[waiting_tasks_count],[wait_time_ms],[max_wait_time_ms],[signal_wait_time_ms]
            FROM [sys].[dm_os_wait_stats] WITH (NOLOCK);
            SELECT @NativeRows=COUNT_BIG(*) FROM @WaitRows;
            SELECT @AfterName=CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),
                   @AfterStart=[sqlserver_start_time],@AfterTicks=[sqlserver_start_time_ms_ticks]
            FROM [sys].[dm_os_sys_info] WITH (NOLOCK);
            IF @@ROWCOUNT<>1 OR @AfterName IS NULL OR @AfterStart IS NULL OR @AfterTicks IS NULL
               OR CONVERT(varbinary(max),@AfterName)<>CONVERT(varbinary(max),@EngineName)
               OR @AfterStart<>@EngineStart OR @AfterTicks<>@EngineTicks
                THROW 53767,N'Der Enginekontext vor und nach dem vollständigen Waitread stimmt nicht überein.',1;
            SET @EndUtc=SYSUTCDATETIME();
            IF @EndUtc<@StartUtc THROW 53767,N'Das native UTC-Messfenster ist nicht geordnet.',1;
            SELECT @EngineJson=(SELECT @EngineName AS [serverName],
             CONVERT(nvarchar(19),@EngineStart,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@EngineStart)),3) AS [sqlServerStartTimeLocal],
             CONVERT(varchar(20),@EngineTicks) AS [sqlServerStartTimeMsTicks]
             FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
            SELECT @RowsJson=(SELECT [WaitType],[WaitingTasksCount],[WaitTimeMs],[MaxWaitTimeMs],[SignalWaitTimeMs]
              FROM @WaitRows ORDER BY [WaitType] COLLATE Latin1_General_100_BIN2,DATALENGTH([WaitType]) FOR JSON PATH,INCLUDE_NULL_VALUES);
            SET @RowsJson=COALESCE(@RowsJson,N'[]');
            IF @NativeRows=0 SELECT @SourceStatus='EMPTY_UNPROVEN',@SourcePartial=1;
        END TRY
        BEGIN CATCH
            SELECT @SourceStatus=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                     WHEN ERROR_NUMBER() IN(207,208) THEN 'UNAVAILABLE_OBJECT' ELSE 'ERROR_HANDLED' END,
                   @SourcePartial=1,@SourceComplete=0,@SourceError=ERROR_NUMBER(),
                   @SourceMessage=CONVERT(nvarchar(2048),ERROR_MESSAGE()),@NativeRows=NULL,@RowsJson=N'[]',@EngineJson=NULL,
                   @EndUtc=SYSUTCDATETIME();
            IF @EndUtc<@StartUtc SELECT @StartUtc=NULL,@EndUtc=NULL;
        END CATCH;
        SELECT @SourceJson=(SELECT JSON_QUERY((SELECT 1 AS [schemaVersion],N'SnapshotWaitStats' AS [resultName],
          CASE WHEN @StartUtc IS NOT NULL THEN CONVERT(nvarchar(19),@StartUtc,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@StartUtc)),3)+N'Z' END AS [measurementStartUtc],
          CASE WHEN @EndUtc IS NOT NULL THEN CONVERT(nvarchar(19),@EndUtc,126)+N'.'+RIGHT(N'00'+CONVERT(nvarchar(3),DATEPART(MILLISECOND,@EndUtc)),3)+N'Z' END AS [measurementEndUtc],
          @SourceStatus AS [statusCode],@SourcePartial AS [isPartial],@SourceError AS [errorNumber],@SourceMessage AS [errorMessage],
          CONVERT(varchar(20),@NativeRows) AS [nativeRows],@SourceComplete AS [sourceComplete],JSON_QUERY(@EngineJson) AS [engineContext]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)) AS [meta],JSON_QUERY(@RowsJson) AS [waits]
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
        SET @Sql=N'EXEC '+@TargetQuoted+N'.[snapshot].[InternalCompleteWaitStatsCycle]
 @CaptureRunId=@Run,@CollectorJson=@Json,@ExpectedTargetDatabaseId=@Id,@ExpectedTargetDatabaseName=@Name,@ExpectedTargetCreateDate=@Created,
 @StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;';
        EXEC [sys].[sp_executesql] @Sql,
 N'@Run bigint,@Json nvarchar(max),@Id int,@Name sysname,@Created datetime,@Status varchar(40) OUTPUT,@Partial bit OUTPUT,@Error int OUTPUT,@Message nvarchar(2048) OUTPUT',
 @Run=@CaptureRunIdOut,@Json=@SourceJson,@Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated,
 @Status=@StatusCodeOut OUTPUT,@Partial=@IsPartialOut OUTPUT,@Error=@ErrorNumberOut OUTPUT,@Message=@ErrorMessageOut OUTPUT;
        SET @CompletionReturned=1;
        IF @@TRANCOUNT<>0 THROW 53768,N'Der Waitabschluss hat eine unerwartete Transaktion hinterlassen.',1;
        SET @Sql=N'USE '+@TargetQuoted+N';
IF DB_ID()<>@Id OR NOT EXISTS(SELECT 1 FROM [master].[sys].[databases] WITH (NOLOCK)
 WHERE [database_id]=@Id AND CONVERT(varbinary(max),[name])=CONVERT(varbinary(max),@Name) AND [create_date]=@Created AND [state]=0 AND [is_read_only]=0)
 THROW 53764,N''Die Targetidentität vor der Ergebnisprojektion hat sich geändert.'',1;
INSERT [#RunSnapshotCollectionCycle_Run]
([CaptureRunId],[TargetDatabaseName],[CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SqlServerStartTimeUtc],[ResetEpochId],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage])
SELECT [CaptureRunId],@Name,[CollectorCode],[SchedulerType],[StartedAtUtc],[EndedAtUtc],[SqlServerStartTimeUtc],[ResetEpochId],[StatusCode],[IsPartial],[MetricSampleCount],[PayloadCount],[ErrorNumber],[ErrorMessage]
FROM [snapshot].[CaptureRun] WHERE [CaptureRunId]=@Run AND CONVERT(varbinary(max),[CollectorCode])=CONVERT(varbinary(max),''WAIT_STATS'')
 AND CONVERT(varbinary(max),[SourceDatabaseName])=CONVERT(varbinary(max),@Source);
SET @Found=CASE WHEN @@ROWCOUNT=1 THEN 1 ELSE 0 END;
INSERT [#RunSnapshotCollectionCycle_Modules]
([ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
SELECT [ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
FROM [snapshot].[ModuleStatus] WHERE [CaptureRunId]=@Run;';
        EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Name sysname,@Created datetime,@Run bigint,@Source sysname,@Found bit OUTPUT',
 @Id=@TargetId,@Name=@TargetDatabaseNameOut,@Created=@TargetCreated,@Run=@CaptureRunIdOut,@Source=@SourceName,@Found=@ProjectionFound OUTPUT;
        IF @ProjectionFound<>1 THROW 53763,N'Die Projektion bestätigt keinen passenden eigenen Wait-Run.',1;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN(229,262,297,300,371) THEN 'DENIED_PERMISSION'
                                  WHEN ERROR_NUMBER() IN(53760,53761,53762,53764,208,2812,8144,8145) THEN 'TARGET_UNAVAILABLE' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE()),@Unhandled=1;
    END CATCH;
WaitFinish:
    IF @LockHeld=1
    BEGIN TRY
        EXEC @LockResult=[sys].[sp_releaseapplock] @Resource=N'SQL_Server_Analyze.SC023.CollectionCycle',@LockOwner='Session',@DbPrincipal=N'public';
        IF @LockResult<0 THROW 53768,N'Die Freigabe der eigenen Paket-Applock ist nicht bestätigt.',1;
        SET @LockHeld=0;
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut='ERROR_HANDLED',@IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),
               @ErrorMessageOut=CONVERT(nvarchar(2048),ERROR_MESSAGE()),@Unhandled=1;
    END CATCH;
    IF @Unhandled=1 OR (@Prepared=1 AND @StatusCodeOut='TARGET_UNAVAILABLE')
    BEGIN TRY
        DECLARE @Limit nvarchar(1000)=CASE WHEN @CompletionReturned=1
          THEN N'Der Backendaufruf ist beendet; eine gespeicherte Aufnahme bleibt erhalten. Ergebnisprojektion und Abschlussdetails sind hier nicht vollständig bestätigt.'
          ELSE N'Ein eröffneter Lauf kann unvollständig sein. Es wird kein Legacy-Abschluss und keine erfundene Nullprojektion geschrieben.' END;
        SET @Limit=CONCAT(@Limit,N' Gebundenes Target: ',QUOTENAME(@TargetDatabaseNameOut),N'.');
        SET @Sql=N'INSERT [#RunSnapshotCollectionCycle_Modules]
([ModuleStatusId],[CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
VALUES(NULL,@Run,N''monitor.InternalRunSnapshotWaitStatsCycle'',SYSUTCDATETIME(),@Status,1,@Error,@Message,@Limit);';
        EXEC [sys].[sp_executesql] @Sql,N'@Run bigint,@Status varchar(40),@Error int,@Message nvarchar(2048),@Limit nvarchar(1000)',
 @Run=@CaptureRunIdOut,@Status=@StatusCodeOut,@Error=@ErrorNumberOut,@Message=@ErrorMessageOut,@Limit=@Limit;
    END TRY
    BEGIN CATCH
        -- Preserve the authoritative failure outputs if the caller result table is unavailable.
    END CATCH;
END;
GO
