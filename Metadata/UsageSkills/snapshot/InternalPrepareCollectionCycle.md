---
skill_format_version: "1.0.0"
name: "snapshot.InternalPrepareCollectionCycle"
schema_name: "snapshot"
object_name: "InternalPrepareCollectionCycle"
object_type: "INTERNAL_PROCEDURE"
database_role: "snapshot_target"
is_internal: true
description: "Prüft Zielidentität, Collectorvertrag, Aktivierung, Datenbudget und Fälligkeit; eröffnet abhängig vom Collector einen Lauf."
source_path: "Code/10_SnapshotBaseline/040_InternalPrepareCollectionCycle.sql"
---

# snapshot.InternalPrepareCollectionCycle

## Zweck und Einsatz

Prüft Zielidentität, Collectorvertrag, Aktivierung, Datenbudget und Fälligkeit; eröffnet abhängig vom Collector einen Lauf.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalPrepareCollectionCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `master.sys.databases`, `sys.database_files`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[sys].[procedures]`, `[sys].[schemas]`, `[sys].[parameters]`, `[snapshot].[CollectorPolicy]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SourceDatabaseName | sysname | ja | kein Default |
| @SchedulerType | varchar(16) | ja | kein Default |
| @RunEvenIfNotDue | bit | ja | kein Default |
| @CaptureRunIdOut | bigint OUTPUT | ja | kein Default |
| @ShouldCollectOut | bit OUTPUT | ja | kein Default |
| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |
| @CollectorCode | varchar(64) | nein | 'PERFORMANCE_COUNTERS' |
| @ExpectedTargetDatabaseId | int | nein | NULL |
| @ExpectedTargetDatabaseName | sysname | nein | NULL |
| @ExpectedTargetCreateDate | datetime | nein | NULL |
| @PolicyOnly | bit | nein | 0 |
| @Hilfe | bit | nein | 0 |

**@SourceDatabaseName:** `@SourceDatabaseName` sysname; Default: Kein Default. Weglassen ist nicht zulässig. Obligatorischer Rohname der Quellmetadaten, ohne Datenbankwechsel oder Datenbanklookup. Leertext wird unverändert gespeichert; NULL scheitert bei einem tatsächlich ausgeführten INSERT an NOT NULL. Ohne INSERT wird er nicht geschrieben; das Argument bleibt Pflicht.

**@SchedulerType:** `@SchedulerType` varchar(16); Default: Kein Default. Weglassen ist nicht zulässig. MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler), SQL_AGENT (SQL Server Agent). Nur Herkunftslabel; startet oder prüft keinen Scheduler. Keine explizite Normalisierung. NULL, Leertext oder ein anderer Wert kann beim INSERT an NOT NULL/CHECK scheitern (nativer SQL-Fehler, kein INVALID_PARAMETER); ohne INSERT bleibt der Wert ungenutzt.

**@RunEvenIfNotDue:** `@RunEvenIfNotDue` bit; Default: Kein Default. Weglassen ist nicht zulässig. 0 prüft Fälligkeit, 1 umgeht nur die Due-Prüfung. Leertext ist keine unterstützte Eingabe. NULL wird nicht validiert und umgeht wegen des Tests = 0 ebenfalls die Prüfung. Disabled-, Budget- und Target-Gates bleiben wirksam.

**@CaptureRunIdOut:** `@CaptureRunIdOut` bigint OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt NULL; Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Zuweisung erst nach CaptureRun-INSERT. PERFORMANCE_COUNTERS legt bei Disabled-, Budget- oder Due-Abbruch einen beendeten partiellen Lauf samt ModuleStatus an; ID beweist keine Sammlung. WAIT_STATS/FILE_IO liefern bei frühem Abbruch keine ID. PolicyOnly=1 legt nie einen Lauf an. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ShouldCollectOut:** `@ShouldCollectOut` bit OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt 0; Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Nach INSERT nur bei AVAILABLE 1; PolicyOnly bleibt immer 0. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@StatusCodeOut:** `@StatusCodeOut` varchar(40) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt AVAILABLE; Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Ausgaben genau: AVAILABLE (Admission bereit), INVALID_PARAMETER (Collector, PolicyOnly-Kombination oder Wait-Transaktionszustand ungültig), TARGET_UNAVAILABLE (Ziel/erforderlicher Vertrag fehlt), DISABLED (Policy deaktiviert/fehlt), STOPPED_SIZE_BUDGET (Softbudget überschritten), SKIPPED_NOT_DUE (Intervall nicht abgelaufen). RUNNING ist nur der Status der eingefügten CaptureRun-Zeile, kein Ausgabe-Status. Native Fehler werden nicht allgemein in diese Statuswerte übersetzt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** `@ErrorMessageOut` nvarchar(2048) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt NULL; Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Diagnose eines erkannten Statuspfads oder NULL; native SQL-Fehler können direkt abbrechen. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@CollectorCode:** `@CollectorCode` varchar(64); Default: PERFORMANCE_COUNTERS. Weglassen verwendet den Default. Einzelcode; NULL wird leer, dann UPPER und äußere U+0020-Leerzeichen entfernt. Zulässig: PERFORMANCE_COUNTERS (Performance Counter), WAIT_STATS (Wait-Statistiken), FILE_IO (Datei-I/O). Leertext/anderer normalisierter Wert ergibt INVALID_PARAMETER.

**@ExpectedTargetDatabaseId:** `@ExpectedTargetDatabaseId` int; Default: NULL. Weglassen verwendet NULL. Teil der Zielidentität. NULL nur im identitätslosen PERFORMANCE_COUNTERS-Fall; sobald eine Komponente gesetzt ist und bei WAIT_STATS/FILE_IO alle drei Angaben erforderlich. ID >4, die ID muss DB_ID() der aktuellen Datenbank entsprechen; Ziel in master online und beschreibbar. Leertext ist keine unterstützte Ganzzahleingabe. Abweichung ergibt TARGET_UNAVAILABLE.

**@ExpectedTargetDatabaseName:** `@ExpectedTargetDatabaseName` sysname; Default: NULL. Weglassen verwendet den Default. Rohname der Zielidentität, binär verglichen. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall; sonst alle drei Werte Pflicht. Leertext passt nicht und ergibt TARGET_UNAVAILABLE.

**@ExpectedTargetCreateDate:** `@ExpectedTargetCreateDate` datetime; Default: NULL. Weglassen verwendet den Default. Ein typisierter datetime-Wert aus master.sys.databases.create_date, ohne UTC-Konvertierung; Leertext ist keine unterstützte Datumsangabe. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall; sonst alle drei Werte Pflicht. Abweichung ergibt TARGET_UNAVAILABLE.

**@PolicyOnly:** `@PolicyOnly` bit; Default: 0. Weglassen verwendet den Default. 0 normaler Admission-Pfad mit Budgetermittlung und vorgesehenen Writes. 1 nur WAIT_STATS/FILE_IO: Enabled und Due aus abgeschlossener Historie prüfen. Der SoftBudgetMB-Policywert wird zuvor mit der Policyquelle gelesen; Dateigrößenmessung, Budgetvergleich und Writes entfallen; keine Run-ID, ShouldCollect bleibt 0, auch bei AVAILABLE. NULL ergibt INVALID_PARAMETER; leerer Text ist keine unterstützte Eingabe. Wait-/File-Aufrufe erfordern auch hier keine Callertransaktion und keine aktivierten impliziten Transaktionen.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Im Normalpfad gibt es kein fachliches Resultset. `@CaptureRunIdOut` (bigint OUTPUT) bleibt bei frühem Abbruch, PolicyOnly und den WAIT_STATS-/FILE_IO-Skipfällen NULL; eine gesetzte ID belegt einen angelegten CaptureRun, keine erfolgreiche Sammlung. `@ShouldCollectOut` (bit OUTPUT) beginnt 0 und wird nach INSERT nur bei AVAILABLE 1. `@StatusCodeOut` (varchar(40) OUTPUT) beginnt AVAILABLE und meldet bei erkannten Grenzen INVALID_PARAMETER, TARGET_UNAVAILABLE, DISABLED, STOPPED_SIZE_BUDGET oder SKIPPED_NOT_DUE; RUNNING ist nur ein persistierter CaptureRun-Zustand, kein OUTPUT-Status. `@ErrorMessageOut` (nvarchar(2048) OUTPUT) ist NULL oder erläutert einen erkannten Statuspfad. Native SQL-Fehler sind nicht generell in diese Werte übersetzt.

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.


## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'InternalPrepareCollectionCycle';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [snapshot].[InternalPrepareCollectionCycle] @SourceDatabaseName=NULL, @SchedulerType=NULL, @RunEvenIfNotDue=NULL, @CaptureRunIdOut=NULL, @ShouldCollectOut=NULL, @StatusCodeOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

`@SchedulerType` varchar(16); Default: Kein Default. Weglassen ist nicht zulässig. MANUAL (manueller Aufruf),
EXTERNAL (externer Scheduler), SQL_AGENT (SQL Server Agent). Nur Herkunftslabel;
startet oder prüft keinen Scheduler. Keine explizite Normalisierung. NULL,
Leertext oder ein anderer Wert kann beim INSERT an NOT NULL/CHECK scheitern
(nativer SQL-Fehler, kein INVALID_PARAMETER); ohne
INSERT bleibt der Wert ungenutzt.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : snapshot.InternalPrepareCollectionCycle
Version      : 1.2.0
Stand        : 2026-10-26
Zweck        : Prüft Zielidentität, Collectorvertrag, Aktivierung, Datenbudget
               und Fälligkeit; eröffnet abhängig vom Collector einen Lauf.
===============================================================================

Schnittstelle und Parameter
---------------------------
`@SourceDatabaseName` sysname; Default: Kein Default. Weglassen ist nicht zulässig. Obligatorischer Rohname
der Quellmetadaten, ohne Datenbankwechsel oder Datenbanklookup. Leertext wird unverändert gespeichert; NULL scheitert bei einem tatsächlich ausgeführten INSERT an
NOT NULL. Ohne INSERT wird er nicht geschrieben; das Argument bleibt Pflicht.

`@SchedulerType` varchar(16); Default: Kein Default. Weglassen ist nicht zulässig. MANUAL (manueller Aufruf),
EXTERNAL (externer Scheduler), SQL_AGENT (SQL Server Agent). Nur Herkunftslabel;
startet oder prüft keinen Scheduler. Keine explizite Normalisierung. NULL,
Leertext oder ein anderer Wert kann beim INSERT an NOT NULL/CHECK scheitern
(nativer SQL-Fehler, kein INVALID_PARAMETER); ohne
INSERT bleibt der Wert ungenutzt.

`@RunEvenIfNotDue` bit; Default: Kein Default. Weglassen ist nicht zulässig. 0 prüft Fälligkeit, 1 umgeht nur
die Due-Prüfung. Leertext ist keine unterstützte Eingabe. NULL wird nicht validiert und umgeht wegen des Tests = 0
ebenfalls die Prüfung. Disabled-, Budget- und Target-Gates bleiben wirksam.

`@CaptureRunIdOut` bigint OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt NULL;
Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben. Zuweisung erst nach CaptureRun-INSERT. PERFORMANCE_COUNTERS legt
bei Disabled-, Budget- oder Due-Abbruch einen beendeten partiellen Lauf samt
ModuleStatus an; ID beweist keine Sammlung. WAIT_STATS/FILE_IO liefern bei
frühem Abbruch keine ID. PolicyOnly=1 legt nie einen Lauf an.

`@ShouldCollectOut` bit OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Beim Eintritt 0;
Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben.
Nach INSERT nur bei AVAILABLE 1; PolicyOnly bleibt immer 0.

`@StatusCodeOut` varchar(40) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt AVAILABLE;
Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben.
Ausgaben genau: AVAILABLE (Admission bereit), INVALID_PARAMETER (Collector,
PolicyOnly-Kombination oder Wait-Transaktionszustand ungültig),
TARGET_UNAVAILABLE (Ziel/erforderlicher Vertrag fehlt), DISABLED (Policy
deaktiviert/fehlt), STOPPED_SIZE_BUDGET (Softbudget überschritten),
SKIPPED_NOT_DUE (Intervall nicht abgelaufen). RUNNING ist nur der Status der
eingefügten CaptureRun-Zeile, kein Ausgabe-Status. Native Fehler werden nicht
allgemein in diese Statuswerte übersetzt.

`@ErrorMessageOut` nvarchar(2048) OUTPUT; Default: Kein Default. Weglassen ist nicht zulässig. Eintritt NULL;
Eingangswert ignoriert. Ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang eine gebundene Variable als OUTPUT-Argument angeben.
Diagnose eines erkannten Statuspfads oder NULL; native SQL-Fehler können
direkt abbrechen.

`@CollectorCode` varchar(64); Default: PERFORMANCE_COUNTERS. Weglassen verwendet den Default. Einzelcode;
NULL wird leer, dann UPPER und äußere U+0020-Leerzeichen entfernt. Zulässig:
PERFORMANCE_COUNTERS (Performance Counter), WAIT_STATS (Wait-Statistiken),
FILE_IO (Datei-I/O). Leertext/anderer normalisierter Wert ergibt
INVALID_PARAMETER.

`@ExpectedTargetDatabaseId` int; Default: NULL. Weglassen verwendet NULL. Teil der Zielidentität. NULL
nur im identitätslosen PERFORMANCE_COUNTERS-Fall; sobald eine Komponente
gesetzt ist und bei WAIT_STATS/FILE_IO alle drei Angaben erforderlich. ID >4,
die ID muss DB_ID() der aktuellen Datenbank entsprechen; Ziel in master online und beschreibbar. Leertext ist keine unterstützte Ganzzahleingabe.
Abweichung ergibt TARGET_UNAVAILABLE.

`@ExpectedTargetDatabaseName` sysname; Default: NULL. Weglassen verwendet den Default. Rohname der Zielidentität,
binär verglichen. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall;
sonst alle drei Werte Pflicht. Leertext passt nicht und ergibt
TARGET_UNAVAILABLE.

`@ExpectedTargetCreateDate` datetime; Default: NULL. Weglassen verwendet den Default. Ein typisierter datetime-Wert aus master.sys.databases.create_date, ohne UTC-Konvertierung; Leertext ist keine unterstützte Datumsangabe. NULL nur beim identitätslosen PERFORMANCE_COUNTERS-Fall;
sonst alle drei Werte Pflicht. Abweichung ergibt TARGET_UNAVAILABLE.

`@PolicyOnly` bit; Default: 0. Weglassen verwendet den Default. 0 normaler Admission-Pfad mit Budgetermittlung
und vorgesehenen Writes. 1 nur WAIT_STATS/FILE_IO: Enabled und Due aus
abgeschlossener Historie prüfen. Der SoftBudgetMB-Policywert wird zuvor
mit der Policyquelle gelesen; Dateigrößenmessung, Budgetvergleich und Writes entfallen; keine
Run-ID, ShouldCollect bleibt 0, auch bei AVAILABLE. NULL ergibt
INVALID_PARAMETER; leerer Text ist keine unterstützte Eingabe. Wait-/File-Aufrufe erfordern auch hier keine
Callertransaktion und keine aktivierten impliziten Transaktionen.

Verhalten und Grenzen
---------------------
Erste Parameterprüfung liefert zusätzlich RETURN 51011. WAIT_STATS/FILE_IO
prüfen den installierten SC-023-Vertrag: genau eine PackageVersion mit
1.2.1/Schema 2 oder 1.3.0 beziehungsweise 1.3.1/Schema 3, außerdem
InternalCompleteWaitStatsCycle und Parameter `@ContractOnly` von
InternalPurgeExpiredData. FILE_IO benötigt zusätzlich 1.3.1/Schema 3.
Die Prüfung führt kein Purge aus.

Das Budget berechnet SUM(size) aus sys.database_files für type=0,
multipliziert mit 8.0 und dividiert durch 1024.0. Das sind allokierte
Datendatei-MB der aktuellen Datenbank. Logdateien gehen nicht in die Summe
ein; der Wert misst keine tatsächlich belegten Snapshot- oder Payloadbytes. Nur strikt größer stoppt; Gleichheit passiert. Due verwendet die jüngste
CaptureRun-ID mit EndedAtUtc. PERFORMANCE_COUNTERS zählt nur AVAILABLE/PARTIAL;
WAIT_STATS, FILE_IO und PolicyOnly jeden beendeten Lauf. RunEvenIfNotDue=1
übergeht allein diese Prüfung.

WAIT_STATS/FILE_IO kehren bei Nicht-AVAILABLE vor dem INSERT ohne Lauf zurück.
PERFORMANCE_COUNTERS schreibt bei Disabled, Budgetstopp oder Due-Skip einen
beendeten partiellen Lauf plus ModuleStatus ohne Quellread. PolicyOnly schreibt
nie. Keine eigene Transaktion, kein CATCH, keine Reservierung/Serialisierung;
Mehrstatement-Schreiben kann bei nativen Fehlern partiell sein. Keine global
exakt einmalige Admission.
```

