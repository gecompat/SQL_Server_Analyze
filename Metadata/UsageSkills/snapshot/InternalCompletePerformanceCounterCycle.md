---
skill_format_version: "1.0.0"
name: "snapshot.InternalCompletePerformanceCounterCycle"
schema_name: "snapshot"
object_name: "InternalCompletePerformanceCounterCycle"
object_type: "INTERNAL_PROCEDURE"
database_role: "snapshot_target"
is_internal: true
description: "Persistiert einen transient übergebenen Performance-Counter- JSON-Vertrag als typisierte Samples und optionales Rohpayload."
source_path: "Code/10_SnapshotBaseline/050_InternalCompletePerformanceCounterCycle.sql"
---

# snapshot.InternalCompletePerformanceCounterCycle

## Zweck und Einsatz

Persistiert einen transient übergebenen Performance-Counter- JSON-Vertrag als typisierte Samples und optionales Rohpayload.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalCompletePerformanceCounterCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[snapshot].[CaptureRun]`, `[snapshot].[Scope]`, `[snapshot].[MetricDefinition]`, `[snapshot].[MetricSample]`, `[snapshot].[CollectorPolicy]`, `[snapshot].[PayloadSnapshot]`, `monitor.USP_PerformanceCounters`, `[snapshot].[ModuleStatus]`. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @CaptureRunId | bigint | ja | kein Default |
| @CollectorJson | nvarchar(max) | ja | kein Default |
| @SourceStatusCode | varchar(40) | ja | kein Default |
| @SourceIsPartial | bit | ja | kein Default |
| @SourceErrorNumber | int | ja | kein Default |
| @SourceErrorMessage | nvarchar(2048) | ja | kein Default |
| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |
| @IsPartialOut | bit OUTPUT | ja | kein Default |
| @ErrorNumberOut | int OUTPUT | ja | kein Default |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |
| @Hilfe | bit | nein | 0 |

**@CaptureRunId:** @CaptureRunId bigint Default: Kein Default; Pflichtargument. Ordnet Samples, Payload und Modulstatus einer vorhandenen CaptureRunId zu. Leerer Text ist keine vorgesehene Ganzzahleingabe. Das Objekt erzeugt keine CaptureRun-Zeile und garantiert weder Laufexistenz, CollectorCode noch einen offenen Lauf oder Quellenbezug. NULL oder eine fehlende Zielzeile kann an Constraints scheitern; Wiederholungen können eindeutige Run-/Metrik- oder Run-/Modul-Bindungen verletzen. EndedAtUtc wird nicht gesetzt; ein separater Finalisierer schließt den Lauf.

**@CollectorJson:** @CollectorJson nvarchar(max) Default: Kein Default; Pflichtargument. Erwartet einen einzelnen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer Text oder ISJSON(...) <> 1 gilt als ungültig. OPENJSON projiziert aus $.counters genau diese case-sensitiven Felder und SQL-Typen: ObjectName, CounterName und InstanceName als nvarchar(128); CounterType als int; MetricValue als decimal(38,6); MetricUnit als varchar(40); AfterValue als bigint; FindingCode als varchar(80). Native Konvertierungen gelten. Es gibt keine strikte Schema- oder Array-Validierung. Zusätzliche Schlüssel werden für Samples ignoriert, bleiben aber im optionalen Rohpayload erhalten. ObjectName, CounterName, InstanceName und CounterType müssen nach der Projektion nicht-NULL sein, sonst wird die Zeile still herausgefiltert; leere Namen sind zulässig. Fehlende Counter oder Pflichtwerte können ohne Fehler oder Partial-Markierung null Samples ergeben. Gültiges JSON kann die erwartete Form dennoch verfehlen. MetricValue und MetricUnit stammen vom Collector, werden nicht berechnet. AfterValue erzeugt ein RAW-, MetricValue ein INTERPRETED-Sample; beides erzeugt beide. FindingCode NULL oder SQL-leer wird MEASURED, sonst ungeprüft übernommen. $.meta.sqlServerStartTime wird mit TRY_CONVERT als datetime2(3) gelesen; fehlend/ungültig ergibt NULL, ohne UTC-Umrechnung.

**@SourceStatusCode:** @SourceStatusCode varchar(40) Default: Kein Default; Pflichtargument. Gültiges JSON leitet den Wert weiter; NULL wird initial ERROR_HANDLED, leer bleibt leer. Keine Enum-Prüfung oder geschlossene Ausgabemenge. Bei ungültigem JSON bleiben nur DENIED_PERMISSION und UNAVAILABLE_OBJECT erhalten, sonst folgt ERROR_HANDLED.

**@SourceIsPartial:** @SourceIsPartial bit Default: Kein Default; Pflichtargument. Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL. Leerer Text ist keine vorgesehene Bit-Eingabeform. NULL wird zur Laufzeit initial zu 1, kein SQL-Default. Ungültiges JSON setzt 1. Keine Status-/Partial-Konsistenzprüfung.

**@SourceErrorNumber:** @SourceErrorNumber int Default: Kein Default; Pflichtargument. Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl. Leerer Text ist keine vorgesehene Ganzzahleingabe. Löst selbst keinen SQL-Fehler aus und wird initial weitergereicht. Ungültiges JSON ändert ihn nicht; ein abgefangener SQL-Fehler ersetzt ihn durch seine Fehlernummer.

**@SourceErrorMessage:** @SourceErrorMessage nvarchar(2048) Default: Kein Default; Pflichtargument. Akzeptiert NULL oder Aufrufertext bis nvarchar(2048); SQL-leer bleibt leer. Initiale Weitergabe. Bei ungültigem JSON ersetzt der eingebaute Text nur NULL. Ein abgefangener SQL-Fehler setzt ERROR_MESSAGE().

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp varchar(40); eingehender Variablenwert wird ignoriert und darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT kann das Pflichtargument übergeben und der Rückgabewert verworfen werden. Initialwert COALESCE(@SourceStatusCode,'ERROR_HANDLED'). Ungültiges JSON folgt obiger Regel. Abgefangene Fehler 229, 262, 297, 300, 371 setzen DENIED_PERMISSION, andere ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@IsPartialOut:** @IsPartialOut bit OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp bit; eingehender Wert wird ignoriert und darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. 0 markiert nicht partiell, 1 partiell; eine Vollständigkeitsprüfung erfolgt nicht. Initialwert COALESCE(@SourceIsPartial,1); ungültiges JSON und abgefangene Fehler setzen 1. Keine Konsistenzprüfung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp int; eingehender Wert ignoriert, darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. Initialwert @SourceErrorNumber; ungültiges JSON ändert ihn nicht, abgefangene Fehler überschreiben ihn. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT Default: Kein Default; Pflichtargument. Argumenttyp nvarchar(2048); eingehender Wert ignoriert, darf uninitialisiert sein. OUTPUT empfängt den Wert; ohne OUTPUT darf das Ergebnis verworfen werden. Initialwert @SourceErrorMessage; ungültiges JSON verwendet den eingebauten Text nur bei NULL; abgefangene Fehler überschreiben mit ERROR_MESSAGE(). Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein Fach-Resultset. `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` melden Validierung, Speicherung und Fehler der Performance-Counter-Erfassung. Der Helper schreibt eigene Capture-/Metric-/ModuleStatus-Zeilen im Snapshot-Ziel; bei Teilstatus oder nativem Fehler ist keine vollständige Quellenaufnahme belegt.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'InternalCompletePerformanceCounterCycle';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [snapshot].[InternalCompletePerformanceCounterCycle] @CaptureRunId=NULL, @CollectorJson=NULL, @SourceStatusCode=NULL, @SourceIsPartial=NULL, @SourceErrorNumber=NULL, @SourceErrorMessage=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Vertrag
-------
Alle zehn Parameter sind Pflichtargumente; die Signatur definiert keinen
SQL-Default. Ausgelassene Argumente verursachen einen Aufruffehler. Auch
NULL-fähige Argumente müssen angegeben werden.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

