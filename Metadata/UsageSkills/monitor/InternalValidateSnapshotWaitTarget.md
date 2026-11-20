---
skill_format_version: "1.0.0"
name: "monitor.InternalValidateSnapshotWaitTarget"
schema_name: "monitor"
object_name: "InternalValidateSnapshotWaitTarget"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Prüft die gebundene Snapshot-Zielidentität und die tatsächlich benötigten Wait- oder Datei-I/O-Verträge ohne Produktwrite."
source_path: "Code/10_SnapshotBaseline/076_InternalValidateSnapshotWaitTarget.sql"
---

# monitor.InternalValidateSnapshotWaitTarget

## Zweck und Einsatz

Prüft die gebundene Snapshot-Zielidentität und die tatsächlich benötigten Wait- oder Datei-I/O-Verträge ohne Produktwrite.

## Voraussetzungen und Rechte

Ein direkter Aufruf erfordert EXECUTE auf [monitor].[InternalValidateSnapshotWaitTarget]. Der normale Einsatz erfolgt über die öffentliche aufrufende Prozedur; direkter Fachbetrieb dieses Helpers ist nicht vorgesehen. Die Quelle nennt insbesondere `master.sys.databases`, `[master].[sys].[databases]`, `[snapshot].[PackageVersion]`, `[sys].[procedures]`, `[sys].[schemas]`, `[sys].[sql_modules]`, `[sys].[parameters]`, `[snapshot].[MetricDefinition]` und weitere im SQL-Text. Für deren Metadaten- oder Fachzugriff gelten die Rechte des jeweiligen SQL-Ausführungskontexts; der Skill erteilt sie nicht.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @TargetDatabaseName | sysname | ja | kein Default |
| @ExpectedTargetDatabaseId | int | nein | NULL |
| @ExpectedTargetCreateDate | datetime | nein | NULL |
| @TargetDatabaseIdOut | int OUTPUT | ja | kein Default |
| @TargetCreateDateOut | datetime OUTPUT | ja | kein Default |
| @StatusCodeOut | varchar(40) OUTPUT | ja | kein Default |
| @ErrorNumberOut | int OUTPUT | ja | kein Default |
| @ErrorMessageOut | nvarchar(2048) OUTPUT | ja | kein Default |
| @CollectorCode | varchar(64) | nein | 'WAIT_STATS' |
| @Hilfe | bit | nein | 0 |

**@TargetDatabaseName:** @TargetDatabaseName (sysname, Eingabe, erforderlich; kein Default): Erwartet einen einzelnen sysname-Eingabewert (nvarchar mit bis zu 128 Zeichen), der als ein Datenbankname behandelt wird. Punkte und andere Zeichen werden nicht als Qualifizierung interpretiert; ein Literal mit Punkten bezeichnet daher nicht mehrere Namensbestandteile. NULL, leerer Text und nur aus Rand-Leerzeichen bestehender Text sind ungültig. Der Wert wird nicht getrimmt oder hinsichtlich Groß-/Kleinschreibung normalisiert; der Namensvergleich erfolgt binär.

**@ExpectedTargetDatabaseId:** @ExpectedTargetDatabaseId (int, Eingabe, optional; Default: NULL): Erwartet einen einzelnen int-Wert oder NULL; eine leere Texteingabe ist keine zulässige Eingabeform. NULL bedeutet, dass keine erwartete Identität vorgegeben wird. Ein Zahlenwert wird mit der ermittelten ID verglichen. Zusammen mit @ExpectedTargetCreateDate muss der Wert entweder NULL oder angegeben sein; eine teilweise Bindung ergibt INVALID_PARAMETER.

**@ExpectedTargetCreateDate:** @ExpectedTargetCreateDate (datetime, Eingabe, optional; Default: NULL): Erwartet einen einzelnen datetime-Wert oder NULL; eine leere Texteingabe ist keine zulässige Eingabeform. NULL bedeutet, dass kein erwartetes Erstellungsdatum vorgegeben wird. Ein datetime-Wert wird mit dem Katalogwert verglichen. Zusammen mit @ExpectedTargetDatabaseId muss der Wert entweder NULL oder angegeben sein; eine teilweise Bindung ergibt INVALID_PARAMETER.

**@TargetDatabaseIdOut:** @TargetDatabaseIdOut (int, OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf NULL und setzt die tatsächliche Datenbank-ID, sobald das Ziel vor der Probe als verfügbar ermittelt wurde. Dieser Wert kann vor einem späteren Fehler befüllt sein. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@TargetCreateDateOut:** @TargetCreateDateOut (datetime, OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf NULL und setzt das tatsächliche Erstellungsdatum, sobald das Ziel vor der Probe als verfügbar ermittelt wurde. Dieser Wert kann vor einem späteren Fehler befüllt sein. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@StatusCodeOut:** @StatusCodeOut (varchar(40), OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf AVAILABLE und setzt den endgültigen Aufnahmestatus. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** @ErrorNumberOut (int, OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf NULL und setzt bei einer abgewiesenen Aufnahme die Fehlernummer. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** @ErrorMessageOut (nvarchar(2048), OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf NULL und setzt bei einer abgewiesenen Aufnahme die Meldung. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@CollectorCode:** @CollectorCode (varchar(64), Eingabe, optional; Default: WAIT_STATS): Erwartet einen einzelnen Auswahlcode. Zulässig sind ausschließlich WAIT_STATS (Waitstatistik-Vertrag) und FILE_IO (Datei-I/O-Vertrag). Der Vergleich ist binär und exakt; Groß-/Kleinschreibung, Rand-Leerzeichen oder andere Schreibweisen werden nicht normalisiert und sind ungültig. NULL ist ungültig. Der ausgelassene Parameter verwendet WAIT_STATS.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein Fach-Resultset. `@TargetDatabaseIdOut int`, `@TargetCreateDateOut datetime`, `@StatusCodeOut varchar(40)`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` sind OUTPUTs. Die Ziel-ID kann vor einem späteren Fehler bereits gesetzt sein; Status und Fehlerwerte entscheiden über die nutzbare Zielbindung. Der Helper bestätigt Zielidentität und Paketstruktur im aktuellen Aufruf, keine Collector-Ausführung.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalValidateSnapshotWaitTarget';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalValidateSnapshotWaitTarget] @TargetDatabaseName=NULL, @TargetDatabaseIdOut=NULL, @TargetCreateDateOut=NULL, @StatusCodeOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

@TargetDatabaseIdOut (int, OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf NULL und setzt die tatsächliche Datenbank-ID, sobald das Ziel vor der Probe als verfügbar ermittelt wurde. Dieser Wert kann vor einem späteren Fehler befüllt sein. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalValidateSnapshotWaitTarget
Version      : 1.1.0
Stand        : 2026-10-26
Zweck        : Prüft die gebundene Snapshot-Zielidentität und die tatsächlich benötigten Wait- oder Datei-I/O-Verträge ohne Produktwrite.
Verwendung   : Interner gemeinsamer Eintritt für Konfiguration und Waitlauf.
===============================================================================

Parameter

@TargetDatabaseName (sysname, Eingabe, erforderlich; kein Default): Erwartet einen einzelnen sysname-Eingabewert (nvarchar mit bis zu 128 Zeichen), der als ein Datenbankname behandelt wird. Punkte und andere Zeichen werden nicht als Qualifizierung interpretiert; ein Literal mit Punkten bezeichnet daher nicht mehrere Namensbestandteile. NULL, leerer Text und nur aus Rand-Leerzeichen bestehender Text sind ungültig. Der Wert wird nicht getrimmt oder hinsichtlich Groß-/Kleinschreibung normalisiert; der Namensvergleich erfolgt binär.

@ExpectedTargetDatabaseId (int, Eingabe, optional; Default: NULL): Erwartet einen einzelnen int-Wert oder NULL; eine leere Texteingabe ist keine zulässige Eingabeform. NULL bedeutet, dass keine erwartete Identität vorgegeben wird. Ein Zahlenwert wird mit der ermittelten ID verglichen. Zusammen mit @ExpectedTargetCreateDate muss der Wert entweder NULL oder angegeben sein; eine teilweise Bindung ergibt INVALID_PARAMETER.

@ExpectedTargetCreateDate (datetime, Eingabe, optional; Default: NULL): Erwartet einen einzelnen datetime-Wert oder NULL; eine leere Texteingabe ist keine zulässige Eingabeform. NULL bedeutet, dass kein erwartetes Erstellungsdatum vorgegeben wird. Ein datetime-Wert wird mit dem Katalogwert verglichen. Zusammen mit @ExpectedTargetDatabaseId muss der Wert entweder NULL oder angegeben sein; eine teilweise Bindung ergibt INVALID_PARAMETER.

@TargetDatabaseIdOut (int, OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf NULL und setzt die tatsächliche Datenbank-ID, sobald das Ziel vor der Probe als verfügbar ermittelt wurde. Dieser Wert kann vor einem späteren Fehler befüllt sein. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden.

@TargetCreateDateOut (datetime, OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf NULL und setzt das tatsächliche Erstellungsdatum, sobald das Ziel vor der Probe als verfügbar ermittelt wurde. Dieser Wert kann vor einem späteren Fehler befüllt sein. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden.

@StatusCodeOut (varchar(40), OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf AVAILABLE und setzt den endgültigen Aufnahmestatus. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden.

@ErrorNumberOut (int, OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf NULL und setzt bei einer abgewiesenen Aufnahme die Fehlernummer. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden.

@ErrorMessageOut (nvarchar(2048), OUTPUT, erforderlich; kein Default): Das Argument ist zwingend. Der Eingabewert wird ignoriert; die Prozedur initialisiert den Ausgang auf NULL und setzt bei einer abgewiesenen Aufnahme die Meldung. Für die Rückgabe muss der Aufrufer eine passende Empfangsvariable binden und das Schlüsselwort OUTPUT beziehungsweise OUT angeben; ohne Rückgabewunsch kann als Argument ein typisierter Wert oder NULL übergeben werden.

@CollectorCode (varchar(64), Eingabe, optional; Default: WAIT_STATS): Erwartet einen einzelnen Auswahlcode. Zulässig sind ausschließlich WAIT_STATS (Waitstatistik-Vertrag) und FILE_IO (Datei-I/O-Vertrag). Der Vergleich ist binär und exakt; Groß-/Kleinschreibung, Rand-Leerzeichen oder andere Schreibweisen werden nicht normalisiert und sind ungültig. NULL ist ungültig. Der ausgelassene Parameter verwendet WAIT_STATS.

Es sind sechs Argumente zwingend anzugeben: @TargetDatabaseName und die fünf OUTPUT-Parameter. Ohne Rückgabewunsch dürfen OUTPUT-Argumente als typisierter Wert oder NULL übergeben werden. Um einen Ausgangswert zu empfangen, muss eine passende Variable gebunden und das Aufrufschlüsselwort OUTPUT/OUT angegeben werden. Die drei Eingabeparameter mit Default können ausgelassen oder benannt übergeben werden.

Aufnahmevertrag

Eine Callertransaktion (explizit oder implizit) wird früh mit INVALID_PARAMETER und Fehler 51011 abgewiesen. Das Ziel muss eine separate, online befindliche, beschreibbare Benutzerdatenbank mit database_id > 4 sein und darf nicht die aktuelle Datenbank sein. Bei gesetzter erwarteter Identität müssen ID und Erstellungsdatum gemeinsam passen.

WAIT_STATS akzeptiert Paket SC-023 in Version 1.2.1 / Schema 2, 1.3.0 / Schema 3 oder 1.3.1 / Schema 3. FILE_IO akzeptiert ausschließlich 1.3.1 / Schema 3. Für die benötigten Helper werden Existenz, ANSI_NULLS- und QUOTED_IDENTIFIER-Flags sowie Parameternamen, Parametertypen, Maximallängen, OUTPUT-Flags und Parameteranzahl geprüft. Parameterdefaults, Parameterreihenfolge, Modultext oder Codehash werden dabei nicht geprüft. Die erforderlichen Metriken bilden eine Teilmenge: neun Definitionen für WAIT_STATS beziehungsweise 16 für FILE_IO. Für jede erforderliche Definition werden Typ, Einheit und ContractVersion 1 verglichen; zusätzliche Metrikdefinitionen sind zulässig. Eine CollectorPolicy muss vorhanden sein; ihr Aktivierungszustand wird nicht geprüft. Für FILE_IO werden zunächst auch Existenz, Sichtbarkeit und ANSI-Einstellungen der Wait-Abschlussprozedur geprüft. Danach wird der Signaturabgleich auf InternalCompleteFileIOCycle umgestellt; die Wait-Abschlusssignatur wird in diesem Pfad nicht geprüft.

Die Retentionsprobe ruft den installierten kanonischen InternalPurgeExpiredData-Helper mit @MaxBatches=1, @Force=0 und @ContractOnly=1 auf. Sie muss AVAILABLE, NULL für Fehlernummer und Run-ID, ein gesetztes Budgetsignal 0 und die zur Paketversion passende Retentionvertragsversion bestätigen: Version 1 bei Paket 1.2.1, Version 2 bei 1.3.0 und Version 3 bei 1.3.1. Die Prüfungen vor dem Probeaufruf setzen zusätzlich die Paket-/Schemaversion und die passenden Methodensignaturen voraus. Die Probe-Meldung muss nicht NULL sein; ein Rückgabecode wird nicht ausgewertet. Die Zusage ohne Produktwrite gilt für diesen vertrauenswürdigen kanonischen ContractOnly-Helper, nicht für beliebige Inhalte eines installierten Namensraums.

Die Statuswerte sind AVAILABLE (Aufnahme bestätigt), INVALID_PARAMETER (Parameter oder Transaktionskontext ungültig), TARGET_UNAVAILABLE (Ziel oder Vertrag nicht bestätigt) und DENIED_PERMISSION (abgewiesene Berechtigung). Berechtigungsfehler 229, 262, 297, 300 und 371 werden innerhalb des TRY/CATCH als DENIED_PERMISSION gemeldet. Die erste Zielsuche in master.sys.databases erfolgt außerhalb des TRY/CATCH und kann daher als SQL-Fehler an den Aufrufer gelangen. Ein Probesignal, das die Aufnahme nicht bestätigt, ergibt TARGET_UNAVAILABLE, außer die Probe meldet DENIED_PERMISSION. Dem installierten Paketnamensraum wird vertraut; Signatur-, Flag- und Probeprüfungen belegen weder Codeintegrität noch ein vollständiges Schemaaudit.
```

