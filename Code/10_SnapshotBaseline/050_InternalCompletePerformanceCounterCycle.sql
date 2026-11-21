/*
===============================================================================
Objekt       : snapshot.InternalCompletePerformanceCounterCycle
Version      : 1.0.0
Stand        : 2026-07-21
Zweck        : Persistiert einen transient übergebenen Performance-Counter-
               JSON-Vertrag als typisierte Samples und optionales Rohpayload.
===============================================================================


Vertrag
-------
Alle zehn Parameter sind Pflichtargumente; die Signatur definiert keinen
SQL-Default. Ausgelassene Argumente verursachen einen Aufruffehler. Auch
NULL-fähige Argumente müssen angegeben werden.

Parameter
---------
@CaptureRunId bigint
Default: Kein Default; Pflichtargument.
Ordnet Samples, Payload und Modulstatus einer vorhandenen CaptureRunId zu.
Leerer Text ist keine vorgesehene Ganzzahleingabe.
Das Objekt erzeugt keine CaptureRun-Zeile und garantiert weder Laufexistenz,
CollectorCode noch einen offenen Lauf oder Quellenbezug. NULL oder eine
fehlende Zielzeile kann an Constraints scheitern; Wiederholungen können
eindeutige Run-/Metrik- oder Run-/Modul-Bindungen verletzen. EndedAtUtc wird
nicht gesetzt; ein separater Finalisierer schließt den Lauf.

@CollectorJson nvarchar(max)
Default: Kein Default; Pflichtargument.
Erwartet einen einzelnen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer
Text oder ISJSON(...) <> 1 gilt als ungültig. OPENJSON projiziert aus
$.counters genau diese case-sensitiven Felder und SQL-Typen: ObjectName,
CounterName und InstanceName als nvarchar(128); CounterType als int;
MetricValue als decimal(38,6); MetricUnit als varchar(40); AfterValue als
bigint; FindingCode als varchar(80). Native Konvertierungen gelten. Es gibt
keine strikte Schema- oder Array-Validierung. Zusätzliche Schlüssel werden
für Samples ignoriert, bleiben aber im optionalen Rohpayload erhalten.
ObjectName, CounterName, InstanceName und CounterType müssen nach der
Projektion nicht-NULL sein, sonst wird die Zeile still herausgefiltert;
leere Namen sind zulässig. Fehlende Counter oder Pflichtwerte können ohne
Fehler oder Partial-Markierung null Samples ergeben. Gültiges JSON kann die
erwartete Form dennoch verfehlen. MetricValue und MetricUnit stammen vom
Collector, werden nicht berechnet. AfterValue erzeugt ein RAW-, MetricValue
ein INTERPRETED-Sample; beides erzeugt beide. FindingCode NULL oder SQL-leer
wird MEASURED, sonst ungeprüft übernommen. $.meta.sqlServerStartTime wird
mit TRY_CONVERT als datetime2(3) gelesen; fehlend/ungültig ergibt NULL, ohne
UTC-Umrechnung.

@SourceStatusCode varchar(40)
Default: Kein Default; Pflichtargument.
Gültiges JSON leitet den Wert weiter; NULL wird initial ERROR_HANDLED, leer
bleibt leer. Keine Enum-Prüfung oder geschlossene Ausgabemenge. Bei
ungültigem JSON bleiben nur DENIED_PERMISSION und UNAVAILABLE_OBJECT
erhalten, sonst folgt ERROR_HANDLED.

@SourceIsPartial bit
Default: Kein Default; Pflichtargument.
Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL.
Leerer Text ist keine vorgesehene Bit-Eingabeform. NULL wird zur Laufzeit initial zu 1, kein SQL-Default.
Ungültiges JSON setzt 1. Keine Status-/Partial-Konsistenzprüfung.

@SourceErrorNumber int
Default: Kein Default; Pflichtargument.
Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl.
Leerer Text ist keine vorgesehene Ganzzahleingabe. Löst selbst
keinen SQL-Fehler aus und wird initial weitergereicht. Ungültiges JSON ändert
ihn nicht; ein abgefangener SQL-Fehler ersetzt ihn durch seine Fehlernummer.

@SourceErrorMessage nvarchar(2048)
Default: Kein Default; Pflichtargument.
Akzeptiert NULL oder Aufrufertext bis nvarchar(2048); SQL-leer bleibt leer. Initiale Weitergabe.
Bei ungültigem JSON ersetzt der eingebaute Text nur NULL. Ein abgefangener
SQL-Fehler setzt ERROR_MESSAGE().

@StatusCodeOut varchar(40) OUTPUT
Default: Kein Default; Pflichtargument.
Argumenttyp varchar(40); eingehender Variablenwert wird ignoriert und darf
uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT kann das
Pflichtargument übergeben und der Rückgabewert verworfen werden. Initialwert
COALESCE(@SourceStatusCode,'ERROR_HANDLED'). Ungültiges JSON folgt obiger
Regel. Abgefangene Fehler 229, 262, 297, 300, 371 setzen DENIED_PERMISSION,
andere ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.

@IsPartialOut bit OUTPUT
Default: Kein Default; Pflichtargument.
Argumenttyp bit; eingehender Wert wird ignoriert und darf uninitialisiert sein.
OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.
0 markiert nicht partiell, 1 partiell; eine Vollständigkeitsprüfung erfolgt nicht.
Initialwert COALESCE(@SourceIsPartial,1); ungültiges JSON und abgefangene
Fehler setzen 1. Keine Konsistenzprüfung.

@ErrorNumberOut int OUTPUT
Default: Kein Default; Pflichtargument.
Argumenttyp int; eingehender Wert ignoriert, darf uninitialisiert sein.
OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.
Initialwert @SourceErrorNumber; ungültiges JSON ändert ihn nicht, abgefangene
Fehler überschreiben ihn. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.

@ErrorMessageOut nvarchar(2048) OUTPUT
Default: Kein Default; Pflichtargument.
Argumenttyp nvarchar(2048); eingehender Wert ignoriert, darf uninitialisiert
sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen
werden. Initialwert @SourceErrorMessage; ungültiges JSON verwendet den
eingebauten Text nur bei NULL; abgefangene Fehler überschreiben mit
ERROR_MESSAGE(). Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.

Seiteneffekte und Fehlergrenzen
-------------------------------
Vor TRY initialisiert das Objekt OUTPUT-Werte und erstellt bei
LOCK_TIMEOUT 0 eine lokale Temp-Tabelle; deren Anlagefehler kann entweichen.
Im TRY-Pfad werden SERVER-/Counter-Scope-Zeilen wiederverwendet oder ergänzt,
feste RAW-/INTERPRETED-MetricDefinitionen nachgeschlagen und MetricSamples
geschrieben. Bei PERFORMANCE_COUNTERS PayloadEnabled wird das Original-JSON
ohne Kanonisierung samt Hash als GZIP-Payload gespeichert. LEN zählt Zeichen
und nicht alle Speicherbytes. CaptureRun.SqlServerStartTimeUtc wird auf die geparste Serverstartzeit
gesetzt und CaptureRun.ResetEpochId wird aktualisiert. Die Epoch stammt aus der höchsten
CaptureRunId mit gleicher Startzeit und nicht-NULL Epoch, sonst aus NEWID();
das belegt keine Quellserveridentität. ModuleStatus wird geschrieben. Es gibt
keine eigene Transaktion, Atomaritäts- oder Rollback-Zusage. Der CATCH setzt
Status/Partial/Fehlerwerte nach nativem Fehler und versucht ModuleStatus
erneut einzufügen; auch dieser INSERT kann scheitern. Fehler werden nicht
allgemein kontrolliert in Statuswerte umgewandelt. Quellmessung und
Ratenberechnung finden nicht statt. CollectorPolicy.MaxRows wird nicht
durchgesetzt und muss vom Produzenten eingehalten werden. EndedAtUtc setzt
ein separater Finalisierer.
*/
-- USAGE_SKILL_BEGIN snapshot.InternalCompletePerformanceCounterCycle 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "snapshot.InternalCompletePerformanceCounterCycle"
-- schema_name: "snapshot"
-- object_name: "InternalCompletePerformanceCounterCycle"
-- object_type: "INTERNAL_PROCEDURE"
-- database_role: "snapshot_target"
-- is_internal: true
-- description: "Persistiert einen transient übergebenen Performance-Counter- JSON-Vertrag als typisierte Samples und optionales Rohpayload."
-- source_path: "Code/10_SnapshotBaseline/050_InternalCompletePerformanceCounterCycle.sql"
-- ---
-- 
-- # snapshot.InternalCompletePerformanceCounterCycle
-- 
-- ## Zweck und Einsatz
-- 
-- Persistiert einen transient übergebenen Performance-Counter- JSON-Vertrag als typisierte Samples und optionales Rohpayload.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalCompletePerformanceCounterCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[snapshot].[CaptureRun]`, `[snapshot].[Scope]`, `[snapshot].[MetricDefinition]`, `[snapshot].[MetricSample]`, `[snapshot].[CollectorPolicy]`, `[snapshot].[PayloadSnapshot]`, `monitor.USP_PerformanceCounters`, `[snapshot].[ModuleStatus]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @CaptureRunId | bigint | ja | kein Default |
-- | @CollectorJson | nvarchar(max) | ja | kein Default |
-- | @SourceStatusCode | varchar(40) | ja | kein Default |
-- | @SourceIsPartial | bit | ja | kein Default |
-- | @SourceErrorNumber | int | ja | kein Default |
-- | @SourceErrorMessage | nvarchar(2048) | ja | kein Default |
-- | @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |
-- | @IsPartialOut | bit OUTPUT | ja | kein Default |
-- | @ErrorNumberOut | int OUTPUT | ja | kein Default |
-- | @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |
-- | @Hilfe | bit | nein | 0 |
-- 
-- **@CaptureRunId:** @CaptureRunId bigint Default: Kein Default; Pflichtargument. Ordnet Samples, Payload und Modulstatus einer vorhandenen CaptureRunId zu. Leerer Text ist keine vorgesehene Ganzzahleingabe. Das Objekt erzeugt keine CaptureRun-Zeile und garantiert weder Laufexistenz, CollectorCode noch einen offenen Lauf oder Quellenbezug. NULL oder eine fehlende Zielzeile kann an Constraints scheitern; Wiederholungen können eindeutige Run-/Metrik- oder Run-/Modul-Bindungen verletzen. EndedAtUtc wird nicht gesetzt; ein separater Finalisierer schließt den Lauf.
-- 
-- **@CollectorJson:** @CollectorJson nvarchar(max) Default: Kein Default; Pflichtargument. Erwartet einen einzelnen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer Text oder ISJSON(...) <> 1 gilt als ungültig. OPENJSON projiziert aus $.counters genau diese case-sensitiven Felder und SQL-Typen: ObjectName, CounterName und InstanceName als nvarchar(128); CounterType als int; MetricValue als decimal(38,6); MetricUnit als varchar(40); AfterValue als bigint; FindingCode als varchar(80). Native Konvertierungen gelten. Es gibt keine strikte Schema- oder Array-Validierung. Zusätzliche Schlüssel werden für Samples ignoriert, bleiben aber im optionalen Rohpayload erhalten. ObjectName, CounterName, InstanceName und CounterType müssen nach der Projektion nicht-NULL sein, sonst wird die Zeile still herausgefiltert; leere Namen sind zulässig. Fehlende Counter oder Pflichtwerte können ohne Fehler oder Partial-Markierung null Samples ergeben. Gültiges JSON kann die erwartete Form dennoch verfehlen. MetricValue und MetricUnit stammen vom Collector, werden nicht berechnet. AfterValue erzeugt ein RAW-, MetricValue ein INTERPRETED-Sample; beides erzeugt beide. FindingCode NULL oder SQL-leer wird MEASURED, sonst ungeprüft übernommen. $.meta.sqlServerStartTime wird mit TRY_CONVERT als datetime2(3) gelesen; fehlend/ungültig ergibt NULL, ohne UTC-Umrechnung.
-- 
-- **@SourceStatusCode:** @SourceStatusCode varchar(40) Default: Kein Default; Pflichtargument. Gültiges JSON leitet den Wert weiter; NULL wird initial ERROR_HANDLED, leer bleibt leer. Keine Enum-Prüfung oder geschlossene Ausgabemenge. Bei ungültigem JSON bleiben nur DENIED_PERMISSION und UNAVAILABLE_OBJECT erhalten, sonst folgt ERROR_HANDLED.
-- 
-- **@SourceIsPartial:** @SourceIsPartial bit Default: Kein Default; Pflichtargument. Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL. Leerer Text ist keine vorgesehene Bit-Eingabeform. NULL wird zur Laufzeit initial zu 1, kein SQL-Default. Ungültiges JSON setzt 1. Keine Status-/Partial-Konsistenzprüfung.
-- 
-- **@SourceErrorNumber:** @SourceErrorNumber int Default: Kein Default; Pflichtargument. Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl. Leerer Text ist keine vorgesehene Ganzzahleingabe. Löst selbst keinen SQL-Fehler aus und wird initial weitergereicht. Ungültiges JSON ändert ihn nicht; ein abgefangener SQL-Fehler ersetzt ihn durch seine Fehlernummer.
-- 
-- **@SourceErrorMessage:** @SourceErrorMessage nvarchar(2048) Default: Kein Default; Pflichtargument. Akzeptiert NULL oder Aufrufertext bis nvarchar(2048); SQL-leer bleibt leer. Initiale Weitergabe. Bei ungültigem JSON ersetzt der eingebaute Text nur NULL. Ein abgefangener SQL-Fehler setzt ERROR_MESSAGE().
-- 
-- **@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp varchar(40); eingehender Variablenwert wird ignoriert und darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT kann das Pflichtargument übergeben und der Rückgabewert verworfen werden. Initialwert COALESCE(@SourceStatusCode,'ERROR_HANDLED'). Ungültiges JSON folgt obiger Regel. Abgefangene Fehler 229, 262, 297, 300, 371 setzen DENIED_PERMISSION, andere ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@IsPartialOut:** @IsPartialOut bit OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp bit; eingehender Wert wird ignoriert und darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. 0 markiert nicht partiell, 1 partiell; eine Vollständigkeitsprüfung erfolgt nicht. Initialwert COALESCE(@SourceIsPartial,1); ungültiges JSON und abgefangene Fehler setzen 1. Keine Konsistenzprüfung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorNumberOut:** @ErrorNumberOut int OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp int; eingehender Wert ignoriert, darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. Initialwert @SourceErrorNumber; ungültiges JSON ändert ihn nicht, abgefangene Fehler überschreiben ihn. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp nvarchar(2048); eingehender Wert ignoriert, darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. Initialwert @SourceErrorMessage; ungültiges JSON verwendet den eingebauten Text nur bei NULL; abgefangene Fehler überschreiben mit ERROR_MESSAGE(). Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.
-- 
-- **@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.
-- 
-- ## Resultate und Ausgabe
-- 
-- Kein Fach-Resultset. `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` melden Validierung, Speicherung und Fehler der Performance-Counter-Erfassung. Der Helper schreibt eigene Capture-/Metric-/ModuleStatus-Zeilen im Snapshot-Ziel; bei Teilstatus oder nativem Fehler ist keine vollständige Quellenaufnahme belegt.
-- 
-- ## Beispiel
-- 
-- Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:
-- 
-- ```sql
-- SELECT [SkillMarkdown]
-- FROM [monitor_metadata].[VW_ObjectUsageSkills]
-- WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'InternalCompletePerformanceCounterCycle';
-- ```
-- 
-- Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:
-- 
-- ```sql
-- EXEC [snapshot].[InternalCompletePerformanceCounterCycle] @CaptureRunId=NULL, @CollectorJson=NULL, @SourceStatusCode=NULL, @SourceIsPartial=NULL, @SourceErrorNumber=NULL, @SourceErrorMessage=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Vertrag
-- -------
-- Alle zehn Parameter sind Pflichtargumente; die Signatur definiert keinen
-- SQL-Default. Ausgelassene Argumente verursachen einen Aufruffehler. Auch
-- NULL-fähige Argumente müssen angegeben werden.
-- 
-- ### Quellgebundene Detailbeschreibung
-- 
-- Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.
-- 
-- ```text
-- Objekt       : snapshot.InternalCompletePerformanceCounterCycle
-- Version      : 1.0.0
-- Stand        : 2026-07-21
-- Zweck        : Persistiert einen transient übergebenen Performance-Counter-
--                JSON-Vertrag als typisierte Samples und optionales Rohpayload.
-- ===============================================================================
-- 
-- 
-- Vertrag
-- -------
-- Alle zehn Parameter sind Pflichtargumente; die Signatur definiert keinen
-- SQL-Default. Ausgelassene Argumente verursachen einen Aufruffehler. Auch
-- NULL-fähige Argumente müssen angegeben werden.
-- 
-- Parameter
-- ---------
-- @CaptureRunId bigint
-- Default: Kein Default; Pflichtargument.
-- Ordnet Samples, Payload und Modulstatus einer vorhandenen CaptureRunId zu.
-- Leerer Text ist keine vorgesehene Ganzzahleingabe.
-- Das Objekt erzeugt keine CaptureRun-Zeile und garantiert weder Laufexistenz,
-- CollectorCode noch einen offenen Lauf oder Quellenbezug. NULL oder eine
-- fehlende Zielzeile kann an Constraints scheitern; Wiederholungen können
-- eindeutige Run-/Metrik- oder Run-/Modul-Bindungen verletzen. EndedAtUtc wird
-- nicht gesetzt; ein separater Finalisierer schließt den Lauf.
-- 
-- @CollectorJson nvarchar(max)
-- Default: Kein Default; Pflichtargument.
-- Erwartet einen einzelnen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer
-- Text oder ISJSON(...) <> 1 gilt als ungültig. OPENJSON projiziert aus
-- $.counters genau diese case-sensitiven Felder und SQL-Typen: ObjectName,
-- CounterName und InstanceName als nvarchar(128); CounterType als int;
-- MetricValue als decimal(38,6); MetricUnit als varchar(40); AfterValue als
-- bigint; FindingCode als varchar(80). Native Konvertierungen gelten. Es gibt
-- keine strikte Schema- oder Array-Validierung. Zusätzliche Schlüssel werden
-- für Samples ignoriert, bleiben aber im optionalen Rohpayload erhalten.
-- ObjectName, CounterName, InstanceName und CounterType müssen nach der
-- Projektion nicht-NULL sein, sonst wird die Zeile still herausgefiltert;
-- leere Namen sind zulässig. Fehlende Counter oder Pflichtwerte können ohne
-- Fehler oder Partial-Markierung null Samples ergeben. Gültiges JSON kann die
-- erwartete Form dennoch verfehlen. MetricValue und MetricUnit stammen vom
-- Collector, werden nicht berechnet. AfterValue erzeugt ein RAW-, MetricValue
-- ein INTERPRETED-Sample; beides erzeugt beide. FindingCode NULL oder SQL-leer
-- wird MEASURED, sonst ungeprüft übernommen. $.meta.sqlServerStartTime wird
-- mit TRY_CONVERT als datetime2(3) gelesen; fehlend/ungültig ergibt NULL, ohne
-- UTC-Umrechnung.
-- 
-- @SourceStatusCode varchar(40)
-- Default: Kein Default; Pflichtargument.
-- Gültiges JSON leitet den Wert weiter; NULL wird initial ERROR_HANDLED, leer
-- bleibt leer. Keine Enum-Prüfung oder geschlossene Ausgabemenge. Bei
-- ungültigem JSON bleiben nur DENIED_PERMISSION und UNAVAILABLE_OBJECT
-- erhalten, sonst folgt ERROR_HANDLED.
-- 
-- @SourceIsPartial bit
-- Default: Kein Default; Pflichtargument.
-- Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL.
-- Leerer Text ist keine vorgesehene Bit-Eingabeform. NULL wird zur Laufzeit initial zu 1, kein SQL-Default.
-- Ungültiges JSON setzt 1. Keine Status-/Partial-Konsistenzprüfung.
-- 
-- @SourceErrorNumber int
-- Default: Kein Default; Pflichtargument.
-- Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl.
-- Leerer Text ist keine vorgesehene Ganzzahleingabe. Löst selbst
-- keinen SQL-Fehler aus und wird initial weitergereicht. Ungültiges JSON ändert
-- ihn nicht; ein abgefangener SQL-Fehler ersetzt ihn durch seine Fehlernummer.
-- 
-- @SourceErrorMessage nvarchar(2048)
-- Default: Kein Default; Pflichtargument.
-- Akzeptiert NULL oder Aufrufertext bis nvarchar(2048); SQL-leer bleibt leer. Initiale Weitergabe.
-- Bei ungültigem JSON ersetzt der eingebaute Text nur NULL. Ein abgefangener
-- SQL-Fehler setzt ERROR_MESSAGE().
-- 
-- @StatusCodeOut varchar(40) OUTPUT
-- Default: Kein Default; Pflichtargument.
-- Argumenttyp varchar(40); eingehender Variablenwert wird ignoriert und darf
-- uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT kann das
-- Pflichtargument übergeben und der Rückgabewert verworfen werden. Initialwert
-- COALESCE(@SourceStatusCode,'ERROR_HANDLED'). Ungültiges JSON folgt obiger
-- Regel. Abgefangene Fehler 229, 262, 297, 300, 371 setzen DENIED_PERMISSION,
-- andere ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.
-- 
-- @IsPartialOut bit OUTPUT
-- Default: Kein Default; Pflichtargument.
-- Argumenttyp bit; eingehender Wert wird ignoriert und darf uninitialisiert sein.
-- OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.
-- 0 markiert nicht partiell, 1 partiell; eine Vollständigkeitsprüfung erfolgt nicht.
-- Initialwert COALESCE(@SourceIsPartial,1); ungültiges JSON und abgefangene
-- Fehler setzen 1. Keine Konsistenzprüfung.
-- 
-- @ErrorNumberOut int OUTPUT
-- Default: Kein Default; Pflichtargument.
-- Argumenttyp int; eingehender Wert ignoriert, darf uninitialisiert sein.
-- OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.
-- Initialwert @SourceErrorNumber; ungültiges JSON ändert ihn nicht, abgefangene
-- Fehler überschreiben ihn. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.
-- 
-- @ErrorMessageOut nvarchar(2048) OUTPUT
-- Default: Kein Default; Pflichtargument.
-- Argumenttyp nvarchar(2048); eingehender Wert ignoriert, darf uninitialisiert
-- sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen
-- werden. Initialwert @SourceErrorMessage; ungültiges JSON verwendet den
-- eingebauten Text nur bei NULL; abgefangene Fehler überschreiben mit
-- ERROR_MESSAGE(). Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.
-- 
-- Seiteneffekte und Fehlergrenzen
-- -------------------------------
-- Vor TRY initialisiert das Objekt OUTPUT-Werte und erstellt bei
-- LOCK_TIMEOUT 0 eine lokale Temp-Tabelle; deren Anlagefehler kann entweichen.
-- Im TRY-Pfad werden SERVER-/Counter-Scope-Zeilen wiederverwendet oder ergänzt,
-- feste RAW-/INTERPRETED-MetricDefinitionen nachgeschlagen und MetricSamples
-- geschrieben. Bei PERFORMANCE_COUNTERS PayloadEnabled wird das Original-JSON
-- ohne Kanonisierung samt Hash als GZIP-Payload gespeichert. LEN zählt Zeichen
-- und nicht alle Speicherbytes. CaptureRun.SqlServerStartTimeUtc wird auf die geparste Serverstartzeit
-- gesetzt und CaptureRun.ResetEpochId wird aktualisiert. Die Epoch stammt aus der höchsten
-- CaptureRunId mit gleicher Startzeit und nicht-NULL Epoch, sonst aus NEWID();
-- das belegt keine Quellserveridentität. ModuleStatus wird geschrieben. Es gibt
-- keine eigene Transaktion, Atomaritäts- oder Rollback-Zusage. Der CATCH setzt
-- Status/Partial/Fehlerwerte nach nativem Fehler und versucht ModuleStatus
-- erneut einzufügen; auch dieser INSERT kann scheitern. Fehler werden nicht
-- allgemein kontrolliert in Statuswerte umgewandelt. Quellmessung und
-- Ratenberechnung finden nicht statt. CollectorPolicy.MaxRows wird nicht
-- durchgesetzt und muss vom Produzenten eingehalten werden. EndedAtUtc setzt
-- ein separater Finalisierer.
-- ```
-- 
-- USAGE_SKILL_END snapshot.InternalCompletePerformanceCounterCycle
CREATE OR ALTER PROCEDURE [snapshot].[InternalCompletePerformanceCounterCycle]
      @CaptureRunId       bigint
    , @CollectorJson      nvarchar(max)
    , @SourceStatusCode   varchar(40)
    , @SourceIsPartial    bit
    , @SourceErrorNumber  int
    , @SourceErrorMessage nvarchar(2048)
    , @StatusCodeOut      varchar(40) OUTPUT
    , @IsPartialOut       bit OUTPUT
    , @ErrorNumberOut     int OUTPUT
    , @ErrorMessageOut    nvarchar(2048) OUTPUT
    , @Hilfe bit = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF @Hilfe=1
    BEGIN
        -- USAGE_SKILL_HELP_BEGIN snapshot.InternalCompletePerformanceCounterCycle
        SELECT CONVERT(varchar(16),'1.0.0') AS [SkillFormatVersion],CONVERT(sysname,N'snapshot') AS [SchemaName],CONVERT(sysname,N'InternalCompletePerformanceCounterCycle') AS [ObjectName],CONVERT(nvarchar(max),N'---')
            + NCHAR(10)
            + N'skill_format_version: "1.0.0"'
            + NCHAR(10)
            + N'name: "snapshot.InternalCompletePerformanceCounterCycle"'
            + NCHAR(10)
            + N'schema_name: "snapshot"'
            + NCHAR(10)
            + N'object_name: "InternalCompletePerformanceCounterCycle"'
            + NCHAR(10)
            + N'object_type: "INTERNAL_PROCEDURE"'
            + NCHAR(10)
            + N'database_role: "snapshot_target"'
            + NCHAR(10)
            + N'is_internal: true'
            + NCHAR(10)
            + N'description: "Persistiert einen transient übergebenen Performance-Counter- JSON-Vertrag als typisierte Samples und optionales Rohpayload."'
            + NCHAR(10)
            + N'source_path: "Code/10_SnapshotBaseline/050_InternalCompletePerformanceCounterCycle.sql"'
            + NCHAR(10)
            + N'---'
            + NCHAR(10)
            + NCHAR(10)
            + N'# snapshot.InternalCompletePerformanceCounterCycle'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Zweck und Einsatz'
            + NCHAR(10)
            + NCHAR(10)
            + N'Persistiert einen transient übergebenen Performance-Counter- JSON-Vertrag als typisierte Samples und optionales Rohpayload.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Voraussetzungen und Rechte'
            + NCHAR(10)
            + NCHAR(10)
            + N'Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalCompletePerformanceCounterCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[snapshot].[CaptureRun]`, `[snapshot].[Scope]`, `[snapshot].[MetricDefinition]`, `[snapshot].[MetricSample]`, `[snapshot].[CollectorPolicy]`, `[snapshot].[PayloadSnapshot]`, `monitor.USP_PerformanceCounters`, `[snapshot].[ModuleStatus]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.'
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
            + N'| @CaptureRunId | bigint | ja | kein Default |'
            + NCHAR(10)
            + N'| @CollectorJson | nvarchar(max) | ja | kein Default |'
            + NCHAR(10)
            + N'| @SourceStatusCode | varchar(40) | ja | kein Default |'
            + NCHAR(10)
            + N'| @SourceIsPartial | bit | ja | kein Default |'
            + NCHAR(10)
            + N'| @SourceErrorNumber | int | ja | kein Default |'
            + NCHAR(10)
            + N'| @SourceErrorMessage | nvarchar(2048) | ja | kein Default |'
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
            + N'**@CaptureRunId:** @CaptureRunId bigint Default: Kein Default; Pflichtargument. Ordnet Samples, Payload und Modulstatus einer vorhandenen CaptureRunId zu. Leerer Text ist keine vorgesehene Ganzzahleingabe. Das Objekt erzeugt keine CaptureRun-Zeile und garantiert weder Laufexistenz, CollectorCode noch einen offenen Lauf oder Quellenbezug. NULL oder eine fehlende Zielzeile kann an Constraints scheitern; Wiederholungen können eindeutige Run-/Metrik- oder Run-/Modul-Bindungen verletzen. EndedAtUtc wird nicht gesetzt; ein separater Finalisierer schließt den Lauf.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@CollectorJson:** @CollectorJson nvarchar(max) Default: Kein Default; Pflichtargument. Erwartet einen einzelnen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer Text oder ISJSON(...) <> 1 gilt als ungültig. OPENJSON projiziert aus $.counters genau diese case-sensitiven Felder und SQL-Typen: ObjectName, CounterName und InstanceName als nvarchar(128); CounterType als int; MetricValue als decimal(38,6); MetricUnit als varchar(40); AfterValue als bigint; FindingCode als varchar(80). Native Konvertierungen gelten. Es gibt keine strikte Schema- oder Array-Validierung. Zusätzliche Schlüssel werden für Samples ignoriert, bleiben aber im optionalen Rohpayload erhalten. ObjectName, CounterName, InstanceName und CounterType müssen nach der Projektion nicht-NULL sein, sonst wird die Zeile still herausgefiltert; leere Namen sind zulässig. Fehlende Counter oder Pflichtwerte können ohne Fehler oder Partial-Markierung null Samples ergeben. Gültiges JSON kann die erwartete Form dennoch verfehlen.'
            + N' MetricValue und MetricUnit stammen vom Collector, werden nicht berechnet. AfterValue erzeugt ein RAW-, MetricValue ein INTERPRETED-Sample; beides erzeugt beide. FindingCode NULL oder SQL-leer wird MEASURED, sonst ungeprüft übernommen. $.meta.sqlServerStartTime wird mit TRY_CONVERT als datetime2(3) gelesen; fehlend/ungültig ergibt NULL, ohne UTC-Umrechnung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceStatusCode:** @SourceStatusCode varchar(40) Default: Kein Default; Pflichtargument. Gültiges JSON leitet den Wert weiter; NULL wird initial ERROR_HANDLED, leer bleibt leer. Keine Enum-Prüfung oder geschlossene Ausgabemenge. Bei ungültigem JSON bleiben nur DENIED_PERMISSION und UNAVAILABLE_OBJECT erhalten, sonst folgt ERROR_HANDLED.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceIsPartial:** @SourceIsPartial bit Default: Kein Default; Pflichtargument. Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL. Leerer Text ist keine vorgesehene Bit-Eingabeform. NULL wird zur Laufzeit initial zu 1, kein SQL-Default. Ungültiges JSON setzt 1. Keine Status-/Partial-Konsistenzprüfung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceErrorNumber:** @SourceErrorNumber int Default: Kein Default; Pflichtargument. Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl. Leerer Text ist keine vorgesehene Ganzzahleingabe. Löst selbst keinen SQL-Fehler aus und wird initial weitergereicht. Ungültiges JSON ändert ihn nicht; ein abgefangener SQL-Fehler ersetzt ihn durch seine Fehlernummer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@SourceErrorMessage:** @SourceErrorMessage nvarchar(2048) Default: Kein Default; Pflichtargument. Akzeptiert NULL oder Aufrufertext bis nvarchar(2048); SQL-leer bleibt leer. Initiale Weitergabe. Bei ungültigem JSON ersetzt der eingebaute Text nur NULL. Ein abgefangener SQL-Fehler setzt ERROR_MESSAGE().'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp varchar(40); eingehender Variablenwert wird ignoriert und darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT kann das Pflichtargument übergeben und der Rückgabewert verworfen werden. Initialwert COALESCE(@SourceStatusCode,''ERROR_HANDLED''). Ungültiges JSON folgt obiger Regel. Abgefangene Fehler 229, 262, 297, 300, 371 setzen DENIED_PERMISSION, andere ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@IsPartialOut:** @IsPartialOut bit OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp bit; eingehender Wert wird ignoriert und darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. 0 markiert nicht partiell, 1 partiell; eine Vollständigkeitsprüfung erfolgt nicht. Initialwert COALESCE(@SourceIsPartial,1); ungültiges JSON und abgefangene Fehler setzen 1. Keine Konsistenzprüfung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp int; eingehender Wert ignoriert, darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. Initialwert @SourceErrorNumber; ungültiges JSON ändert ihn nicht, abgefangene Fehler überschreiben ihn. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp nvarchar(2048); eingehender Wert ignoriert, darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. Initialwert @SourceErrorMessage; ungültiges JSON verwendet den eingebauten Text nur bei NULL; abgefangene Fehler überschreiben mit ERROR_MESSAGE(). Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Resultate und Ausgabe'
            + NCHAR(10)
            + NCHAR(10)
            + N'Kein Fach-Resultset. `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` melden Validierung, Speicherung und Fehler der Performance-Counter-Erfassung. Der Helper schreibt eigene Capture-/Metric-/ModuleStatus-Zeilen im Snapshot-Ziel; bei Teilstatus oder nativem Fehler ist keine vollständige Quellenaufnahme belegt.'
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
            + N'WHERE [SchemaName]=N''snapshot'' AND [ObjectName]=N''InternalCompletePerformanceCounterCycle'';'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:'
            + NCHAR(10)
            + NCHAR(10)
            + N'```sql'
            + NCHAR(10)
            + N'EXEC [snapshot].[InternalCompletePerformanceCounterCycle] @CaptureRunId=NULL, @CollectorJson=NULL, @SourceStatusCode=NULL, @SourceIsPartial=NULL, @SourceErrorNumber=NULL, @SourceErrorMessage=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10)
            + N'## Aufwand, Nebenwirkungen, Fehler und Grenzen'
            + NCHAR(10)
            + NCHAR(10)
            + N'Vertrag'
            + NCHAR(10)
            + N'-------'
            + NCHAR(10)
            + N'Alle zehn Parameter sind Pflichtargumente; die Signatur definiert keinen'
            + NCHAR(10)
            + N'SQL-Default. Ausgelassene Argumente verursachen einen Aufruffehler. Auch'
            + NCHAR(10)
            + N'NULL-fähige Argumente müssen angegeben werden.'
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
            + N'Objekt       : snapshot.InternalCompletePerformanceCounterCycle'
            + NCHAR(10)
            + N'Version      : 1.0.0'
            + NCHAR(10)
            + N'Stand        : 2026-07-21'
            + NCHAR(10)
            + N'Zweck        : Persistiert einen transient übergebenen Performance-Counter-'
            + NCHAR(10)
            + N'               JSON-Vertrag als typisierte Samples und optionales Rohpayload.'
            + NCHAR(10)
            + N'==============================================================================='
            + NCHAR(10)
            + NCHAR(10)
            + NCHAR(10)
            + N'Vertrag'
            + NCHAR(10)
            + N'-------'
            + NCHAR(10)
            + N'Alle zehn Parameter sind Pflichtargumente; die Signatur definiert keinen'
            + NCHAR(10)
            + N'SQL-Default. Ausgelassene Argumente verursachen einen Aufruffehler. Auch'
            + NCHAR(10)
            + N'NULL-fähige Argumente müssen angegeben werden.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Parameter'
            + NCHAR(10)
            + N'---------'
            + NCHAR(10)
            + N'@CaptureRunId bigint'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Ordnet Samples, Payload und Modulstatus einer vorhandenen CaptureRunId zu.'
            + NCHAR(10)
            + N'Leerer Text ist keine vorgesehene Ganzzahleingabe.'
            + NCHAR(10)
            + N'Das Objekt erzeugt keine CaptureRun-Zeile und garantiert weder Laufexistenz,'
            + NCHAR(10)
            + N'CollectorCode noch einen offenen Lauf oder Quellenbezug. NULL oder eine'
            + NCHAR(10)
            + N'fehlende Zielzeile kann an Constraints scheitern; Wiederholungen können'
            + NCHAR(10)
            + N'eindeutige Run-/Metrik- oder Run-/Modul-Bindungen verletzen. EndedAtUtc wird'
            + NCHAR(10)
            + N'nicht gesetzt; ein separater Finalisierer schließt den Lauf.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@CollectorJson nvarchar(max)'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Erwartet einen einzelnen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer'
            + NCHAR(10)
            + N'Text oder ISJSON(...) <> 1 gilt als ungültig. OPENJSON projiziert aus'
            + NCHAR(10)
            + N'$.counters genau diese case-sensitiven Felder und SQL-Typen: ObjectName,'
            + NCHAR(10)
            + N'CounterName und InstanceName als nvarchar(128); CounterType als int;'
            + NCHAR(10)
            + N'MetricValue als decimal(38,6); MetricUnit als varchar(40); AfterValue als'
            + NCHAR(10)
            + N'bigint; FindingCode als varchar(80). Native Konvertierungen gelten. Es gibt'
            + NCHAR(10)
            + N'keine strikte Schema- oder Array-Validierung. Zusätzliche Schlüssel werden'
            + NCHAR(10)
            + N'für Samples ignoriert, bleiben aber im optionalen Rohpayload erhalten.'
            + NCHAR(10)
            + N'ObjectName, CounterName, InstanceName und CounterType müssen nach der'
            + NCHAR(10)
            + N'Projektion nicht-NULL sein, sonst wird die Zeile still herausgefiltert;'
            + NCHAR(10)
            + N'leere Namen sind zulässig. Fehlende Counter oder Pflichtwerte können ohne'
            + NCHAR(10)
            + N'Fehler oder Partial-Markierung null Samples ergeben. Gültiges JSON kann die'
            + NCHAR(10)
            + N'erwartete Form dennoch verfehlen. MetricValue und MetricUnit stammen vom'
            + NCHAR(10)
            + N'Collector, werden nicht berechnet. AfterValue erzeugt ein RAW-, MetricValue'
            + NCHAR(10)
            + N'ein INTERPRETED-Sample; beides erzeugt beide. FindingCode NULL oder SQL-leer'
            + NCHAR(10)
            + N'wird MEASURED, sonst ungeprüft übernommen. $.meta.sqlServerStartTime wird'
            + NCHAR(10)
            + N'mit TRY_CONVERT als datetime2(3) gelesen; fehlend/ungültig ergibt NULL, ohne'
            + NCHAR(10)
            + N'UTC-Umrechnung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@SourceStatusCode varchar(40)'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Gültiges JSON leitet den Wert weiter; NULL wird initial ERROR_HANDLED, leer'
            + NCHAR(10)
            + N'bleibt leer. Keine Enum-Prüfung oder geschlossene Ausgabemenge. Bei'
            + NCHAR(10)
            + N'ungültigem JSON bleiben nur DENIED_PERMISSION und UNAVAILABLE_OBJECT'
            + NCHAR(10)
            + N'erhalten, sonst folgt ERROR_HANDLED.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@SourceIsPartial bit'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL.'
            + NCHAR(10)
            + N'Leerer Text ist keine vorgesehene Bit-Eingabeform. NULL wird zur Laufzeit initial zu 1, kein SQL-Default.'
            + NCHAR(10)
            + N'Ungültiges JSON setzt 1. Keine Status-/Partial-Konsistenzprüfung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@SourceErrorNumber int'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl.'
            + NCHAR(10)
            + N'Leerer Text ist keine vorgesehene Ganzzahleingabe. Löst selbst'
            + NCHAR(10)
            + N'keinen SQL-Fehler aus und wird initial weitergereicht. Ungültiges JSON ändert'
            + NCHAR(10)
            + N'ihn nicht; ein abgefangener SQL-Fehler ersetzt ihn durch seine Fehlernummer.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@SourceErrorMessage nvarchar(2048)'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Akzeptiert NULL oder Aufrufertext bis nvarchar(2048); SQL-leer bleibt leer. Initiale Weitergabe.'
            + NCHAR(10)
            + N'Bei ungültigem JSON ersetzt der eingebaute Text nur NULL. Ein abgefangener'
            + NCHAR(10)
            + N'SQL-Fehler setzt ERROR_MESSAGE().'
            + NCHAR(10)
            + NCHAR(10)
            + N'@StatusCodeOut varchar(40) OUTPUT'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Argumenttyp varchar(40); eingehender Variablenwert wird ignoriert und darf'
            + NCHAR(10)
            + N'uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT kann das'
            + NCHAR(10)
            + N'Pflichtargument übergeben und der Rückgabewert verworfen werden. Initialwert'
            + NCHAR(10)
            + N'COALESCE(@SourceStatusCode,''ERROR_HANDLED''). Ungültiges JSON folgt obiger'
            + NCHAR(10)
            + N'Regel. Abgefangene Fehler 229, 262, 297, 300, 371 setzen DENIED_PERMISSION,'
            + NCHAR(10)
            + N'andere ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@IsPartialOut bit OUTPUT'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Argumenttyp bit; eingehender Wert wird ignoriert und darf uninitialisiert sein.'
            + NCHAR(10)
            + N'OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.'
            + NCHAR(10)
            + N'0 markiert nicht partiell, 1 partiell; eine Vollständigkeitsprüfung erfolgt nicht.'
            + NCHAR(10)
            + N'Initialwert COALESCE(@SourceIsPartial,1); ungültiges JSON und abgefangene'
            + NCHAR(10)
            + N'Fehler setzen 1. Keine Konsistenzprüfung.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@ErrorNumberOut int OUTPUT'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Argumenttyp int; eingehender Wert ignoriert, darf uninitialisiert sein.'
            + NCHAR(10)
            + N'OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden.'
            + NCHAR(10)
            + N'Initialwert @SourceErrorNumber; ungültiges JSON ändert ihn nicht, abgefangene'
            + NCHAR(10)
            + N'Fehler überschreiben ihn. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'@ErrorMessageOut nvarchar(2048) OUTPUT'
            + NCHAR(10)
            + N'Default: Kein Default; Pflichtargument.'
            + NCHAR(10)
            + N'Argumenttyp nvarchar(2048); eingehender Wert ignoriert, darf uninitialisiert'
            + NCHAR(10)
            + N'sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen'
            + NCHAR(10)
            + N'werden. Initialwert @SourceErrorMessage; ungültiges JSON verwendet den'
            + NCHAR(10)
            + N'eingebauten Text nur bei NULL; abgefangene Fehler überschreiben mit'
            + NCHAR(10)
            + N'ERROR_MESSAGE(). Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert.'
            + NCHAR(10)
            + NCHAR(10)
            + N'Seiteneffekte und Fehlergrenzen'
            + NCHAR(10)
            + N'-------------------------------'
            + NCHAR(10)
            + N'Vor TRY initialisiert das Objekt OUTPUT-Werte und erstellt bei'
            + NCHAR(10)
            + N'LOCK_TIMEOUT 0 eine lokale Temp-Tabelle; deren Anlagefehler kann entweichen.'
            + NCHAR(10)
            + N'Im TRY-Pfad werden SERVER-/Counter-Scope-Zeilen wiederverwendet oder ergänzt,'
            + NCHAR(10)
            + N'feste RAW-/INTERPRETED-MetricDefinitionen nachgeschlagen und MetricSamples'
            + NCHAR(10)
            + N'geschrieben. Bei PERFORMANCE_COUNTERS PayloadEnabled wird das Original-JSON'
            + NCHAR(10)
            + N'ohne Kanonisierung samt Hash als GZIP-Payload gespeichert. LEN zählt Zeichen'
            + NCHAR(10)
            + N'und nicht alle Speicherbytes. CaptureRun.SqlServerStartTimeUtc wird auf die geparste Serverstartzeit'
            + NCHAR(10)
            + N'gesetzt und CaptureRun.ResetEpochId wird aktualisiert. Die Epoch stammt aus der höchsten'
            + NCHAR(10)
            + N'CaptureRunId mit gleicher Startzeit und nicht-NULL Epoch, sonst aus NEWID();'
            + NCHAR(10)
            + N'das belegt keine Quellserveridentität. ModuleStatus wird geschrieben. Es gibt'
            + NCHAR(10)
            + N'keine eigene Transaktion, Atomaritäts- oder Rollback-Zusage. Der CATCH setzt'
            + NCHAR(10)
            + N'Status/Partial/Fehlerwerte nach nativem Fehler und versucht ModuleStatus'
            + NCHAR(10)
            + N'erneut einzufügen; auch dieser INSERT kann scheitern. Fehler werden nicht'
            + NCHAR(10)
            + N'allgemein kontrolliert in Statuswerte umgewandelt. Quellmessung und'
            + NCHAR(10)
            + N'Ratenberechnung finden nicht statt. CollectorPolicy.MaxRows wird nicht'
            + NCHAR(10)
            + N'durchgesetzt und muss vom Produzenten eingehalten werden. EndedAtUtc setzt'
            + NCHAR(10)
            + N'ein separater Finalisierer.'
            + NCHAR(10)
            + N'```'
            + NCHAR(10)
            + NCHAR(10) AS [SkillMarkdown];
        -- USAGE_SKILL_HELP_END snapshot.InternalCompletePerformanceCounterCycle
        RETURN;
    END;

    SET LOCK_TIMEOUT 0;

    SELECT @StatusCodeOut=COALESCE(@SourceStatusCode,'ERROR_HANDLED'),
           @IsPartialOut=COALESCE(@SourceIsPartial,1),
           @ErrorNumberOut=@SourceErrorNumber,
           @ErrorMessageOut=@SourceErrorMessage;

    CREATE TABLE [#InternalCompletePerformanceCounterCycle_Counters]
    (
          [ObjectName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [InstanceName] nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
        , [CounterType] int NOT NULL
        , [MetricValue] decimal(38,6) NULL
        , [MetricUnit] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [AfterValue] bigint NULL
        , [FindingCode] varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
        , [ScopeKeyHash] varbinary(32) NULL
        , [ScopeIdentityJson] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
    );

    BEGIN TRY
        IF @CollectorJson IS NULL OR ISJSON(@CollectorJson)<>1
        BEGIN
            SELECT @StatusCodeOut=CASE WHEN @SourceStatusCode IN ('DENIED_PERMISSION','UNAVAILABLE_OBJECT')
                                       THEN @SourceStatusCode ELSE 'ERROR_HANDLED' END,
                   @IsPartialOut=1,
                   @ErrorMessageOut=COALESCE(@SourceErrorMessage,N'Der Collector lieferte keinen gültigen JSON-Vertrag.');
        END
        ELSE
        BEGIN
            INSERT [#InternalCompletePerformanceCounterCycle_Counters]
            (
                  [ObjectName],[CounterName],[InstanceName],[CounterType]
                , [MetricValue],[MetricUnit],[AfterValue],[FindingCode]
            )
            SELECT
                  [ObjectName],[CounterName],[InstanceName],[CounterType]
                , [MetricValue],[MetricUnit],[AfterValue],[FindingCode]
            FROM OPENJSON(@CollectorJson,N'$.counters')
            WITH
            (
                  [ObjectName] nvarchar(128) N'$.ObjectName'
                , [CounterName] nvarchar(128) N'$.CounterName'
                , [InstanceName] nvarchar(128) N'$.InstanceName'
                , [CounterType] int N'$.CounterType'
                , [MetricValue] decimal(38,6) N'$.MetricValue'
                , [MetricUnit] varchar(40) N'$.MetricUnit'
                , [AfterValue] bigint N'$.AfterValue'
                , [FindingCode] varchar(80) N'$.FindingCode'
            )
            WHERE [ObjectName] IS NOT NULL
              AND [CounterName] IS NOT NULL
              AND [InstanceName] IS NOT NULL
              AND [CounterType] IS NOT NULL;

            UPDATE [c]
            SET [ScopeIdentityJson]=[j].[ScopeIdentityJson],
                [ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),[j].[ScopeIdentityJson]))
            FROM [#InternalCompletePerformanceCounterCycle_Counters] AS [c]
            CROSS APPLY
            (
                SELECT
                (
                    SELECT [c].[ObjectName] AS [objectName],
                           [c].[CounterName] AS [counterName],
                           [c].[InstanceName] AS [instanceName],
                           [c].[CounterType] AS [counterType],
                           [c].[MetricUnit] AS [metricUnit]
                    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES
                ) AS [ScopeIdentityJson]
            ) AS [j];

            DECLARE @SqlServerStartTimeUtc datetime2(3)=TRY_CONVERT(datetime2(3),JSON_VALUE(@CollectorJson,N'$.meta.sqlServerStartTime')),
                    @ResetEpochId uniqueidentifier,
                    @Now datetime2(3)=SYSUTCDATETIME(),
                    @ServerScopeId bigint,
                    @RawMetricDefinitionId bigint,
                    @InterpretedMetricDefinitionId bigint,
                    @PayloadEnabled bit=0;

            SELECT TOP (1) @ResetEpochId=[ResetEpochId]
            FROM [snapshot].[CaptureRun]
            WHERE [SqlServerStartTimeUtc]=@SqlServerStartTimeUtc
              AND [ResetEpochId] IS NOT NULL
            ORDER BY [CaptureRunId] DESC;
            IF @ResetEpochId IS NULL SET @ResetEpochId=NEWID();

            IF NOT EXISTS
            (
                SELECT 1
                FROM [snapshot].[Scope]
                WHERE [ScopeType]='SERVER'
                  AND [ParentScopeId] IS NULL
                  AND [ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),N'{"scope":"SERVER"}'))
            )
                INSERT [snapshot].[Scope]
                ([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
                VALUES
                ('SERVER',NULL,HASHBYTES('SHA2_256',CONVERT(varbinary(max),N'{"scope":"SERVER"}')),N'{"scope":"SERVER"}',@Now);

            SELECT @ServerScopeId=[ScopeId]
            FROM [snapshot].[Scope]
            WHERE [ScopeType]='SERVER'
              AND [ParentScopeId] IS NULL
              AND [ScopeKeyHash]=HASHBYTES('SHA2_256',CONVERT(varbinary(max),N'{"scope":"SERVER"}'));

            INSERT [snapshot].[Scope]
            ([ScopeType],[ParentScopeId],[ScopeKeyHash],[ScopeIdentityJson],[CreatedAtUtc])
            SELECT 'PERFORMANCE_COUNTER',@ServerScopeId,[c].[ScopeKeyHash],[c].[ScopeIdentityJson],@Now
            FROM [#InternalCompletePerformanceCounterCycle_Counters] AS [c]
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM [snapshot].[Scope] AS [s]
                WHERE [s].[ScopeType]='PERFORMANCE_COUNTER'
                  AND [s].[ParentScopeId]=@ServerScopeId
                  AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
            )
            GROUP BY [c].[ScopeKeyHash],[c].[ScopeIdentityJson];

            SELECT @RawMetricDefinitionId=[MetricDefinitionId]
            FROM [snapshot].[MetricDefinition]
            WHERE [MetricCode]='PERFORMANCE_COUNTER_RAW';
            SELECT @InterpretedMetricDefinitionId=[MetricDefinitionId]
            FROM [snapshot].[MetricDefinition]
            WHERE [MetricCode]='PERFORMANCE_COUNTER_INTERPRETED';

            INSERT [snapshot].[MetricSample]
            (
                  [CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc]
                , [ResetEpochId],[BigintValue],[QualityCode],[IsPartial]
            )
            SELECT @CaptureRunId,[s].[ScopeId],@RawMetricDefinitionId,@Now,@ResetEpochId,
                   [c].[AfterValue],COALESCE(NULLIF([c].[FindingCode],''),'MEASURED'),@IsPartialOut
            FROM [#InternalCompletePerformanceCounterCycle_Counters] AS [c]
            JOIN [snapshot].[Scope] AS [s]
              ON [s].[ScopeType]='PERFORMANCE_COUNTER'
             AND [s].[ParentScopeId]=@ServerScopeId
             AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
            WHERE [c].[AfterValue] IS NOT NULL;

            INSERT [snapshot].[MetricSample]
            (
                  [CaptureRunId],[ScopeId],[MetricDefinitionId],[CollectedAtUtc]
                , [ResetEpochId],[NumericValue],[QualityCode],[IsPartial]
            )
            SELECT @CaptureRunId,[s].[ScopeId],@InterpretedMetricDefinitionId,@Now,@ResetEpochId,
                   [c].[MetricValue],COALESCE(NULLIF([c].[FindingCode],''),'MEASURED'),@IsPartialOut
            FROM [#InternalCompletePerformanceCounterCycle_Counters] AS [c]
            JOIN [snapshot].[Scope] AS [s]
              ON [s].[ScopeType]='PERFORMANCE_COUNTER'
             AND [s].[ParentScopeId]=@ServerScopeId
             AND [s].[ScopeKeyHash]=[c].[ScopeKeyHash]
            WHERE [c].[MetricValue] IS NOT NULL;

            SELECT @PayloadEnabled=[PayloadEnabled]
            FROM [snapshot].[CollectorPolicy]
            WHERE [CollectorCode]='PERFORMANCE_COUNTERS';

            IF @PayloadEnabled=1
                INSERT [snapshot].[PayloadSnapshot]
                (
                      [CaptureRunId],[ModuleName],[CapturedAtUtc],[PayloadFormat]
                    , [PayloadContractVersion],[CompressionType],[PayloadHash]
                    , [Payload],[UncompressedCharacterCount]
                )
                VALUES
                (
                      @CaptureRunId,N'monitor.USP_PerformanceCounters',@Now,'JSON',1,'GZIP'
                    , HASHBYTES('SHA2_256',CONVERT(varbinary(max),@CollectorJson))
                    , COMPRESS(@CollectorJson),CONVERT(bigint,LEN(@CollectorJson))
                );

            UPDATE [snapshot].[CaptureRun]
            SET [SqlServerStartTimeUtc]=@SqlServerStartTimeUtc,
                [ResetEpochId]=@ResetEpochId
            WHERE [CaptureRunId]=@CaptureRunId;
        END;

        INSERT [snapshot].[ModuleStatus]
        (
              [CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode]
            , [IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit]
        )
        VALUES
        (
              @CaptureRunId,N'monitor.USP_PerformanceCounters',SYSUTCDATETIME(),@StatusCodeOut
            , @IsPartialOut,@ErrorNumberOut,@ErrorMessageOut
            , N'@SampleSeconds=0; CollectorPolicy.MaxRows begrenzt die persistierte Collectorprojektion.'
        );
    END TRY
    BEGIN CATCH
        SELECT @StatusCodeOut=CASE WHEN ERROR_NUMBER() IN (229,262,297,300,371)
                                   THEN 'DENIED_PERMISSION' ELSE 'ERROR_HANDLED' END,
               @IsPartialOut=1,@ErrorNumberOut=ERROR_NUMBER(),@ErrorMessageOut=ERROR_MESSAGE();
        INSERT [snapshot].[ModuleStatus]
        ([CaptureRunId],[ModuleName],[CollectionTimeUtc],[StatusCode],[IsPartial],[ErrorNumber],[ErrorMessage],[EvidenceLimit])
        VALUES
        (@CaptureRunId,N'monitor.USP_PerformanceCounters',SYSUTCDATETIME(),@StatusCodeOut,1,@ErrorNumberOut,@ErrorMessageOut,
         N'Persistenz wurde kontrolliert als partiell markiert.');
    END CATCH;
END;
GO
