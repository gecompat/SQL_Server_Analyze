---
skill_format_version: "1.0.0"
name: "monitor.InternalRunSnapshotWaitStatsCycle"
schema_name: "monitor"
object_name: "InternalRunSnapshotWaitStatsCycle"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Die Procedure orchestriert einen nativen Wait-Snapshot für ein konfiguriertes Target und übergibt ihn dem gebundenen Backend."
source_path: "Code/10_SnapshotBaseline/085_InternalRunSnapshotWaitStatsCycle.sql"
---

# monitor.InternalRunSnapshotWaitStatsCycle

## Zweck und Einsatz

Die Procedure orchestriert einen nativen Wait-Snapshot für ein konfiguriertes Target und übergibt ihn dem gebundenen Backend.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalRunSnapshotWaitStatsCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `[monitor].[SnapshotTargetConfiguration]`, `[master].[sys].[databases]`, `[sys].[sp_getapplock]`, `[monitor].[InternalValidateSnapshotWaitTarget]`, `[snapshot].[InternalPrepareCollectionCycle]`, `[sys].[sp_executesql]`, `[snapshot].[InternalPurgeExpiredData]` sowie weitere tatsächlich aufgerufene Quellen. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SchedulerType | varchar(16) | ja | kein Default |
| @RunEvenIfNotDue | bit | ja | kein Default |
| @CaptureRunIdOut | bigint OUTPUT | ja | kein Default |
| @TargetDatabaseNameOut | sysname OUTPUT | ja | kein Default |
| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |
| @IsPartialOut | bit OUTPUT | ja | kein Default |
| @ErrorNumberOut | int OUTPUT | ja | kein Default |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |
| @Hilfe | bit | nein | 0 |

**@SchedulerType:** - @SchedulerType (varchar(16); Default: Kein Default): erforderlich; erlaubt sind MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) und SQL_AGENT (SQL Server Agent). Der Wert dient als Herkunftslabel und startet oder prüft keinen Scheduler. NULL oder ein anderer, nach gewöhnlichem SQL-Server-Zeichenkettenvergleich abweichender Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich verwendet die Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können daher gleichwertig sein. Es erfolgt keine binäre Prüfung oder Trimmen/Normalisierung. Leertext ist kein gültiger Wert.

**@RunEvenIfNotDue:** - @RunEvenIfNotDue (bit; Default: Kein Default): erforderlich; 0 wendet die Fälligkeitsprüfung an, 1 umgeht ausschließlich diese Prüfung. NULL führt zu INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte Bit-Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben wirksam.

**@CaptureRunIdOut:** - @CaptureRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Beim vorbereiteten Capture kann die ID nach dessen INSERT ausgegeben werden. Die ID allein bestätigt weder erfolgreichen Quellread noch erfolgreiche Finalisierung. Empfang über bigint-Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@TargetDatabaseNameOut:** - @TargetDatabaseNameOut (sysname OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Enthält den konfigurierten Zielnamen, sobald die Konfiguration gelesen wurde, auch wenn der Collector deaktiviert ist. Empfang über sysname-kompatible Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@StatusCodeOut:** - @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert AVAILABLE. Empfang über varchar(40)-kompatible Variable und OUTPUT. Die kanonischen lokalen Ergebnisse sind AVAILABLE, INVALID_PARAMETER, TARGET_UNAVAILABLE, DENIED_PERMISSION, DISABLED, SKIPPED_CONCURRENT, SKIPPED_NOT_DUE, STOPPED_SIZE_BUDGET, PARTIAL, UNAVAILABLE_OBJECT und ERROR_HANDLED. AVAILABLE_LIMITED ist kein Endstatus dieses Aufrufers; der Purge-Status wird nur als akzeptiertes Zwischenergebnis ausgewertet. Bei erfolgreichem Backendabschluss wird dessen Status weitergereicht; die Aufrufstelle erzwingt keine eigene Allowlist aller Backendstatus und garantiert daher keine beliebige Statusmenge eines installierten Backends. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@IsPartialOut:** - @IsPartialOut (bit OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert 0. Frühe Abbrüche und Fehlerpfade setzen 1; bei erfolgreichem Backendabschluss wird dessen Wert übernommen. Empfang über bit-kompatible Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** - @ErrorNumberOut (int OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine erkannte Fehlernummer oder bleibt NULL; nicht jeder Statuspfad setzt eine Nummer. Empfang über int-kompatible Variable und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** - @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert ignoriert, Eintrittswert NULL. Enthält eine Diagnose oder bleibt NULL. Empfang über Unicode-Variable mit bis zu 2048 Zeichen und OUTPUT. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein Fach-Resultset. `@CaptureRunIdOut bigint`, `@TargetDatabaseNameOut sysname`, `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` dokumentieren Vorbereitung, gebundenes Ziel und Abschluss des WaitStats-Zyklus. Eine ausgegebene Run-ID oder ein Zielname allein bestätigt keine erfolgreiche Quellaufnahme/Finalisierung; Status, Partial und Fehler bleiben maßgeblich.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalRunSnapshotWaitStatsCycle';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalRunSnapshotWaitStatsCycle] @SchedulerType=NULL, @RunEvenIfNotDue=NULL, @CaptureRunIdOut=NULL, @TargetDatabaseNameOut=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

- @SchedulerType (varchar(16); Default: Kein Default): erforderlich; erlaubt sind MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) und SQL_AGENT (SQL Server Agent). Der Wert dient als Herkunftslabel und startet oder prüft keinen Scheduler. NULL oder ein anderer, nach gewöhnlichem SQL-Server-Zeichenkettenvergleich abweichender Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich verwendet die Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können daher gleichwertig sein. Es erfolgt keine binäre Prüfung oder Trimmen/Normalisierung. Leertext ist kein gültiger Wert.
- @RunEvenIfNotDue (bit; Default: Kein Default): erforderlich; 0 wendet die Fälligkeitsprüfung an, 1 umgeht ausschließlich diese Prüfung. NULL führt zu INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte Bit-Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben wirksam.
- @CaptureRunIdOut (bigint OUTPUT; Default: Kein Default): erforderlich, auch wenn verworfen; Eingangswert wird ignoriert, Eintrittswert NULL. Beim vorbereiteten Capture kann die ID nach dessen INSERT ausgegeben werden. Die ID allein bestätigt weder erfolgreichen Quellread noch erfolgrei

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
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
```

