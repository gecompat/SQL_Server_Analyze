---
skill_format_version: "1.0.0"
name: "snapshot.InternalCompleteWaitStatsCycle"
schema_name: "snapshot"
object_name: "InternalCompleteWaitStatsCycle"
object_type: "INTERNAL_PROCEDURE"
database_role: "snapshot_target"
is_internal: true
description: "Die Procedure validiert einen vollständigen internen Source-v1- Vertrag für sys.dm_os_wait_stats und finalisiert den gebundenen eigenen Wait-Run mit Rohwerten und Vergleichskandidaten."
source_path: "Code/10_SnapshotBaseline/055_InternalCompleteWaitStatsCycle.sql"
---

# snapshot.InternalCompleteWaitStatsCycle

## Zweck und Einsatz

Die Procedure validiert einen vollständigen internen Source-v1- Vertrag für sys.dm_os_wait_stats und finalisiert den gebundenen eigenen Wait-Run mit Rohwerten und Vergleichskandidaten.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [snapshot].[InternalCompleteWaitStatsCycle]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `sys.dm_os_wait_stats`, `master.sys.databases`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[snapshot].[InternalPurgeExpiredData]`, `[snapshot].[CaptureRun]`, `[snapshot].[MetricSample]`, `[snapshot].[PayloadSnapshot]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @CaptureRunId | bigint | ja | kein Default |
| @CollectorJson | nvarchar(max) | ja | kein Default |
| @ExpectedTargetDatabaseId | int | ja | kein Default |
| @ExpectedTargetDatabaseName | sysname | ja | kein Default |
| @ExpectedTargetCreateDate | datetime | ja | kein Default |
| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |
| @IsPartialOut | bit OUTPUT | ja | kein Default |
| @ErrorNumberOut | int OUTPUT | ja | kein Default |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |
| @Hilfe | bit | nein | 0 |

**@CaptureRunId:** - @CaptureRunId (bigint; Default: Kein Default): Erforderlich ist eine Run-ID größer als 0. NULL oder ein Wert kleiner gleich 0 sowie eine Callertransaktion oder IMPLICIT_TRANSACTIONS ON ergeben vor dem Fachzugriff INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte bigint-Eingabe.

**@CollectorJson:** - @CollectorJson (nvarchar(max); Default: Kein Default): Erforderlich ist der Source-v1-Vertrag als JSON-Text inline im Parameter. Ein Dateipfad ist kein Vertrag. NULL, Leertext oder fehlerhaftes JSON scheitern bei der Sourcevalidierung mit 53763. Die JSON-Prüfung erfolgt erst nach bestätigter Übernahme des eigenen Runs; ihr Fehler setzt ERROR_HANDLED / 53763 und löst einen Versuch der Fehlerfinalisierung aus. Eine vorher gescheiterte Runbindung kann stattdessen INVALID_PARAMETER / RETURN 51011 ergeben.

**@ExpectedTargetDatabaseId:** - @ExpectedTargetDatabaseId (int; Default: Kein Default): Erforderlich ist die ID der aktuellen Zieldatenbank und ein Wert größer als 4. NULL, eine andere aktuelle Datenbank oder eine abweichende ID ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte int-Eingabe.

**@ExpectedTargetDatabaseName:** - @ExpectedTargetDatabaseName (sysname; Default: Kein Default): Erforderlich ist der rohe Datenbankname, der binär mit master.sys.databases.name übereinstimmt; es erfolgt kein Trimmen und kein Schreibweisenausgleich. NULL oder ein leerer beziehungsweise abweichender Name ergeben TARGET_UNAVAILABLE und 53764.

**@ExpectedTargetCreateDate:** - @ExpectedTargetCreateDate (datetime; Default: Kein Default): Erforderlich ist der Erstellungszeitpunkt aus master.sys.databases.create_date für dieselbe aktuelle Zieldatenbank. NULL oder eine Abweichung ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte Datumsform.

**@StatusCodeOut:** - @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL oder Leertext wird ignoriert; die Procedure initialisiert AVAILABLE. Ohne Variablenbindung mit OUTPUT wird der Ausgabewert verworfen. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@IsPartialOut:** - @IsPartialOut (bit OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL wird ignoriert; die Procedure initialisiert 0 als anfänglichen Nicht-Partialwert. Jeder fachliche Abschlussstatus meldet 1 als partiell oder nicht vollständig bestätigt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** - @ErrorNumberOut (int OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL wird ignoriert; die Procedure initialisiert NULL und kann bei Guards oder behandelten Fehlern eine Fehlernummer setzen; ein gültiger Source-Fehlervertrag darf NULL weiterreichen. Beim erfolgreichen gespeicherten PARTIAL-Ergebnis bleibt der Wert NULL. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** - @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL oder Leertext wird ignoriert; die Procedure initialisiert NULL und kann Fehlertext, eine Guard-Meldung oder beim gespeicherten PARTIAL-Ergebnis eine Vergleichsentscheidung ausgeben. Je nach Pfad kann der Wert NULL oder leer bleiben. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein Fach-Resultset. `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` geben die Ziel-/Quellvalidierung und Speicherung zurück. Ein PARTIAL-Ausgang enthält einen begrenzten Vergleichsgrund in `@ErrorMessageOut`; der Helper schreibt nur zum gebundenen CaptureRun im Snapshot-Ziel und beweist weder vollständige Wait-Aufnahme noch spätere Retention.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'snapshot' AND [ObjectName]=N'InternalCompleteWaitStatsCycle';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [snapshot].[InternalCompleteWaitStatsCycle] @CaptureRunId=NULL, @CollectorJson=NULL, @ExpectedTargetDatabaseId=NULL, @ExpectedTargetDatabaseName=NULL, @ExpectedTargetCreateDate=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

- @CaptureRunId (bigint; Default: Kein Default): Erforderlich ist eine Run-ID größer als 0. NULL oder ein Wert kleiner gleich 0 sowie eine Callertransaktion oder IMPLICIT_TRANSACTIONS ON ergeben vor dem Fachzugriff INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte bigint-Eingabe.
- @CollectorJson (nvarchar(max); Default: Kein Default): Erforderlich ist der Source-v1-Vertrag als JSON-Text inline im Parameter. Ein Dateipfad ist kein Vertrag. NULL, Leertext oder fehlerhaftes JSON scheitern bei der Sourcevalidierung mit 53763. Die JSON-Prüfung erfolgt erst nach bestätigter Übernahme des eigenen Runs; ihr Fehler setzt ERROR_HANDLED / 53763 und löst einen Versuch der Fehlerfinalisierung aus. Eine vorher gescheiterte Runbindung kann stattdessen INVALID_PARAMETER / RETURN 51011 ergeben.
- @ExpectedTargetDatabaseId (int; Default: Kein Default): Erforderlich ist die ID der aktuellen Zieldatenbank und ein Wert größer als 4. NULL, eine andere aktuelle Datenbank oder eine abweichende ID ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte int-Eingabe.
- @ExpectedTargetDatabaseName (sysname; Default: Kein Default): Erforderlich ist der rohe Datenbankname, der b

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : snapshot.InternalCompleteWaitStatsCycle
Version      : 1.0.1
Stand        : 2026-10-26
Zweck        : Die Procedure validiert einen vollständigen internen Source-v1-
               Vertrag für sys.dm_os_wait_stats und finalisiert den gebundenen
               eigenen Wait-Run mit Rohwerten und Vergleichskandidaten.
Grenze       : Monotonie beweist keine ununterbrochene Resetkontinuität.
===============================================================================

#### InternalCompleteWaitStatsCycle – Parameterverträge

Alle neun Parameter sind erforderlich; keiner besitzt einen Default. Der Aufruf kann Argumente positionsgebunden in Signaturreihenfolge oder mit Parameternamen übergeben. Auch die vier OUTPUT-Argumente sind erforderlich. Eingehende OUTPUT-Werte werden ignoriert. Ein OUTPUT-Wert wird nur in eine Variable übernommen, wenn der Aufruf eine typkompatible Variable mit OUTPUT bindet; ohne OUTPUT-Kennzeichnung wird die Ausgabe verworfen.

- @CaptureRunId (bigint; Default: Kein Default): Erforderlich ist eine Run-ID größer als 0. NULL oder ein Wert kleiner gleich 0 sowie eine Callertransaktion oder IMPLICIT_TRANSACTIONS ON ergeben vor dem Fachzugriff INVALID_PARAMETER und RETURN 51011. Leertext ist keine unterstützte bigint-Eingabe.
- @CollectorJson (nvarchar(max); Default: Kein Default): Erforderlich ist der Source-v1-Vertrag als JSON-Text inline im Parameter. Ein Dateipfad ist kein Vertrag. NULL, Leertext oder fehlerhaftes JSON scheitern bei der Sourcevalidierung mit 53763. Die JSON-Prüfung erfolgt erst nach bestätigter Übernahme des eigenen Runs; ihr Fehler setzt ERROR_HANDLED / 53763 und löst einen Versuch der Fehlerfinalisierung aus. Eine vorher gescheiterte Runbindung kann stattdessen INVALID_PARAMETER / RETURN 51011 ergeben.
- @ExpectedTargetDatabaseId (int; Default: Kein Default): Erforderlich ist die ID der aktuellen Zieldatenbank und ein Wert größer als 4. NULL, eine andere aktuelle Datenbank oder eine abweichende ID ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte int-Eingabe.
- @ExpectedTargetDatabaseName (sysname; Default: Kein Default): Erforderlich ist der rohe Datenbankname, der binär mit master.sys.databases.name übereinstimmt; es erfolgt kein Trimmen und kein Schreibweisenausgleich. NULL oder ein leerer beziehungsweise abweichender Name ergeben TARGET_UNAVAILABLE und 53764.
- @ExpectedTargetCreateDate (datetime; Default: Kein Default): Erforderlich ist der Erstellungszeitpunkt aus master.sys.databases.create_date für dieselbe aktuelle Zieldatenbank. NULL oder eine Abweichung ergeben TARGET_UNAVAILABLE und 53764. Leertext ist keine unterstützte Datumsform.
- @StatusCodeOut (varchar(40) OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL oder Leertext wird ignoriert; die Procedure initialisiert AVAILABLE. Ohne Variablenbindung mit OUTPUT wird der Ausgabewert verworfen.
- @IsPartialOut (bit OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL wird ignoriert; die Procedure initialisiert 0 als anfänglichen Nicht-Partialwert. Jeder fachliche Abschlussstatus meldet 1 als partiell oder nicht vollständig bestätigt.
- @ErrorNumberOut (int OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL wird ignoriert; die Procedure initialisiert NULL und kann bei Guards oder behandelten Fehlern eine Fehlernummer setzen; ein gültiger Source-Fehlervertrag darf NULL weiterreichen. Beim erfolgreichen gespeicherten PARTIAL-Ergebnis bleibt der Wert NULL.
- @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: Kein Default): Erforderlicher Ausgabeparameter. Der gebundene Eingabewert einschließlich NULL oder Leertext wird ignoriert; die Procedure initialisiert NULL und kann Fehlertext, eine Guard-Meldung oder beim gespeicherten PARTIAL-Ergebnis eine Vergleichsentscheidung ausgeben. Je nach Pfad kann der Wert NULL oder leer bleiben.

Die normalen SQL-Typkonvertierungen gelten vor dem Eintritt in die Prozedur. Ohne Rückgabe darf jedes obligatorische OUTPUT-Argument als typkompatibler Skalar oder NULL gebunden werden; für numerische Typen ist Leertext keine unterstützte Eingabeform. Die Initialisierung ersetzt erst den erfolgreich gebundenen Eingangswert.

#### InternalCompleteWaitStatsCycle – Source-v1-JSON-Vertrag

@CollectorJson muss ein JSON-Objekt mit genau den Eigenschaften meta (Objekt) und waits (Array) enthalten. Zusätzliche oder doppelte Eigenschaften werden abgewiesen. Eigenschaftsnamen werden binär verglichen und sind groß-/kleinschreibungsabhängig. Alle genannten Eigenschaften müssen vorhanden sein, auch wenn ihr Wert JSON null ist.

Das meta-Objekt enthält genau diese elf Eigenschaften:

| Eigenschaft | JSON-Typ und Inhalt |
|---|---|
| schemaVersion | JSON-Zahl exakt 1. |
| resultName | Zeichenfolge exakt SnapshotWaitStats. |
| measurementStartUtc | NULL oder exakt 24 Zeichen im Format YYYY-MM-DDTHH:mm:ss.fffZ. |
| measurementEndUtc | NULL oder exakt 24 Zeichen im Format YYYY-MM-DDTHH:mm:ss.fffZ. |
| statusCode | Eine der fünf unten definierten Source-Statuszeichenfolgen. |
| isPartial | JSON-Boolean true oder false. |
| errorNumber | NULL oder JSON-Ganzzahl von 1 bis 2147483647 in kanonischer Dezimalschreibweise. |
| errorMessage | NULL oder Unicode-Zeichenfolge mit höchstens 2048 UTF-16-Codeeinheiten. |
| nativeRows | NULL oder kanonische nichtnegative bigint-Dezimalzeichenfolge von 0 bis 9223372036854775807. |
| sourceComplete | JSON-Boolean true oder false. |
| engineContext | NULL oder das unten definierte Engineobjekt. |

Ein nicht-NULL-Zeitfenster muss beide Zeitpunkte enthalten und geordnet sein. Ein vollständiger Sourcevertrag erfordert beide Zeitpunkte; der Start liegt frühestens beim Runstart und das Ende nicht nach der aktuellen UTC-Zeit.

Ein nicht-NULL-engineContext-Objekt enthält genau drei Eigenschaften, jeweils als JSON-Zeichenfolge: serverName mit 1 bis 128 UTF-16-Codeeinheiten; sqlServerStartTimeLocal mit exakt 23 Zeichen im lokalen DATETIME-Rundtripformat YYYY-MM-DDTHH:mm:ss.fff ohne Z; und sqlServerStartTimeMsTicks als kanonische nichtnegative bigint-Dezimalzeichenfolge von 0 bis 9223372036854775807. Für einen vollständigen Sourcevertrag ist das Engineobjekt erforderlich. Ein Fehlervertrag darf ein gültiges Engineobjekt enthalten; NULL ist dort nicht vorgeschrieben.

Jedes Element von waits muss ein Objekt mit genau fünf Eigenschaften sein: WaitType als Zeichenfolge mit 1 bis 60 UTF-16-Codeeinheiten sowie WaitingTasksCount, WaitTimeMs, MaxWaitTimeMs und SignalWaitTimeMs als JSON-Ganzzahlen von 0 bis 9223372036854775807. Die vier Zahlen müssen kanonische Dezimalinteger ohne Vorzeichen, führende Nullen, Dezimalpunkt oder Exponent sein. WaitType-Identitäten dürfen nicht doppelt vorkommen.

Source-Statuswerte und ihre Bedeutung:
- AVAILABLE bezeichnet eine vollständige, nichtleere Aufnahme mit isPartial=false.
- EMPTY_UNPROVEN bezeichnet eine vollständige, leere Aufnahme, deren Leere nicht als Beweis für eine fachlich vollständige Baseline gilt; isPartial=true.
- DENIED_PERMISSION bezeichnet einen behandelten nativen Berechtigungsfehler.
- UNAVAILABLE_OBJECT bezeichnet ein nicht verfügbares natives Objekt.
- ERROR_HANDLED bezeichnet einen sonstigen behandelten Fehler bei der nativen Erfassung.

Bei sourceComplete=true sind nur AVAILABLE und EMPTY_UNPROVEN zulässig. errorNumber und errorMessage müssen NULL sein; engineContext und beide geordneten Messzeitpunkte müssen vorhanden sein; nativeRows muss der tatsächlichen Zahl der Waitzeilen entsprechen. AVAILABLE verlangt mindestens eine Zeile und isPartial=false. EMPTY_UNPROVEN verlangt null Zeilen und isPartial=true. Bei sourceComplete=false sind nur DENIED_PERMISSION, UNAVAILABLE_OBJECT und ERROR_HANDLED zulässig; isPartial muss true, waits muss leer und nativeRows NULL sein. Das Fehlerobjekt muss nicht engineContext=NULL setzen; falls es vorhanden ist, muss es den vollständigen Enginevertrag erfüllen. Messzeitpunkte dürfen im Fehlerzweig gemeinsam NULL oder gemeinsam vorhanden und geordnet sein.

#### InternalCompleteWaitStatsCycle – Vergleichsgründe in @ErrorMessageOut

Bei einem erfolgreich gespeicherten PARTIAL-Ergebnis enthält @ErrorMessageOut genau einen der folgenden zwölf geschlossenen Vergleichsgründe. Die Auswahl folgt der Reihenfolge der ersten zutreffenden Prüfung in der Liste; die Codes sind keine Werte von @StatusCodeOut.
- SOURCE_EMPTY_UNPROVEN: Die vollständige Sourceaufnahme enthält keine Waitzeilen.
- WRITE_LIMITED: MaxRows ließ nicht alle zur Speicherung berücksichtigungsfähigen WaitTypes zur Speicherung zu.
- FIRST_OBSERVATION: Es gibt keinen früheren finalisierten Wait-Run.
- PREVIOUS_CAPTURE_PARTIAL: Der frühere Lauf war technisch partiell oder enthielt einen Fehler.
- PREVIOUS_CONTEXT_INVALID: Der frühere Vergleichskontext besteht seine Vertragsprüfung nicht.
- PREVIOUS_RAW_INCOMPLETE: Der frühere Lauf enthält nicht alle erforderlichen Rohmetriken.
- ENGINE_CONTEXT_CHANGED: Der native Enginekontext unterscheidet sich vom vorherigen.
- INTERVAL_NOT_POSITIVE: Das Fenster überlappt oder läuft rückwärts; insbesondere liegt der aktuelle Start vor dem vorherigen Ende oder das aktuelle Ende ist nicht später als das vorherige Ende.
- WAIT_TYPE_MISSING: Ein erforderlicher vorheriger WaitType fehlt in der aktuellen Aufnahme.
- COUNTER_DECREASE: Mindestens ein verglichener Counter ist gegenüber dem Vorwert gesunken.
- NO_COMPARABLE_TYPES: Es gibt keinen ausgewählten aktuellen WaitType mit passendem Vorwert.
- MONOTONIC_CONTINUITY_UNPROVEN: Vergleichbare Werte sind monoton, aber daraus folgt keine lückenlose Resetkontinuität.

#### InternalCompleteWaitStatsCycle – Persistenz- und Ausgabevertrag

Die Targetprüfung liegt vor TRY und verlangt die aktuelle, online befindliche und schreibbare Datenbank mit ID größer als 4 sowie exakt passendem binärem Namen und create_date; ein Fehler aus dieser Vorprüfung kann ungefangen auftreten. Danach erfordert die Procedure genau eine PackageVersion-Zeile für SC-023 mit Version 1.2.1/SchemaVersion 2 oder 1.3.0 beziehungsweise 1.3.1/SchemaVersion 3. Der read-only Retentionsvertrag muss zum Paketstand 1, 2 oder 3 entsprechen.

Die Procedure übernimmt ausschließlich einen unbeschriebenen eigenen WAIT_STATS-Run im Status RUNNING, ohne Endzeit oder ResetEpochId und ohne MetricSample-, PayloadSnapshot- oder ModuleStatus-Zeile. Die aktive Policy muss enabled sein; MaxRows muss 1 bis 100000 betragen und begrenzt nur die Backend-Schreibmenge. Bei auswählbaren WaitTypes werden vier rohe numerische Waitmetriken und ein Vergleichsstatus je Typ gespeichert; höchstens drei numerische Differenzkandidaten je vergleichbarem Typ sowie ein Serverkontextsample insgesamt ergänzen die Rohwerte. Der Vergleich stützt sich auf verfügbaren Vorzustand und passende Kontextentscheidungen; er beweist keine ununterbrochene Resetkontinuität und vergleicht nicht bedingungslos mit beliebigem vorherigem Zustand. Eine aktivierte Payload-Policy speichert den Sourcevertrag als JSON-Payload mit GZIP-Kompression. Backend-Schreibvorgänge und Runabschluss liegen in einer eigenen Transaktion und werden gemeinsam committet.

Die sieben möglichen Werte von @StatusCodeOut sind:
- AVAILABLE ist ausschließlich der anfängliche OUTPUT-Wert und bestätigt für sich keinen abgeschlossenen Wait-Run.
- INVALID_PARAMETER bezeichnet die frühen Guards für ungültige Run-ID, Callertransaktion oder implizite Transaktionen sowie eine mit 53763 abgewiesene Runbindung vor Übernahme eines eigenen Runs. Eine Sourcevalidierung mit 53763 nach bestätigtem eigenen Run wird nicht so ausgegeben.
- TARGET_UNAVAILABLE bezeichnet eine abgewiesene Targetidentität oder einen erkannten nicht passenden Installations-/Retentionsvertrag.
- DENIED_PERMISSION bezeichnet einen behandelten Berechtigungsfehler.
- UNAVAILABLE_OBJECT übernimmt den Status eines gültigen Source-Fehlervertrags für ein nicht verfügbares Objekt.
- ERROR_HANDLED bezeichnet einen sonstigen behandelten Backend-, Vertrags-, Transaktions- oder Finalisierungsfehler; dazu gehört eine ungültige Sourcevalidierung mit 53763 nach Übernahme des eigenen Runs.
- PARTIAL bezeichnet den erfolgreich gespeicherten vollständigen oder leeren Sourceabschluss. @IsPartialOut ist dabei 1; @ErrorNumberOut ist NULL und @ErrorMessageOut enthält die Vergleichsentscheidung.

Fehlerhafte Sourceverträge nach Übernahme des eigenen Runs erhalten keine Rohsamples, kein Kontextsample und keine erfundene Epoche. Ein gültiger Source-Fehlervertrag wird ohne numerische Roh- oder Kontextsamples und ohne Epoche abgeschlossen; nur dieser reguläre Fehlerpfad speichert bei aktivierter Payload-Policy auch den übergebenen Sourcevertrag als GZIP-Payload. Bei einem SQL- oder Validierungsfehler rollt der CATCH eine aktive Schreibtransaktion zurück. Nur nach Übernahme eines eigenen Runs und bei weiterhin bestätigter Targetidentität versucht er einen getrennten Fehlerabschluss mit ModuleStatus und Run-Update, ohne Payload. Dieser Versuch kann scheitern oder die nötigen Runbedingungen nicht mehr vorfinden; dann ist keine abgeschlossene Finalisierung zugesichert. Der Helper gibt keinen Status FINALIZATION_UNCONFIRMED aus. Der Sourcevertrag allein stellt keinen öffentlichen Wait-Collector bereit; Installations- und Aktivierungsgrenzen beschreibt der Snapshotvertrag.
```

