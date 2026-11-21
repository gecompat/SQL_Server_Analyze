---
skill_format_version: "1.0.0"
name: "monitor.InternalRunSnapshotFileIOCycle"
schema_name: "monitor"
object_name: "InternalRunSnapshotFileIOCycle"
object_type: "INTERNAL_PROCEDURE"
database_role: "framework"
is_internal: true
description: "Die Procedure erfasst den nativen Datei-I/O-Cache für ausgewählte Online- datenbanken und bindet ihn an beobachtete Engine-, Datenbank- und Dateimetadaten sowie den eigenen Targetlauf."
source_path: "Code/10_SnapshotBaseline/087_InternalRunSnapshotFileIOCycle.sql"
---

# monitor.InternalRunSnapshotFileIOCycle

## Zweck und Einsatz

Die Procedure erfasst den nativen Datei-I/O-Cache für ausgewählte Online- datenbanken und bindet ihn an beobachtete Engine-, Datenbank- und Dateimetadaten sowie den eigenen Targetlauf.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[InternalRunSnapshotFileIOCycle] im vorgesehenen Datenbankkontext. Der interne Helper liest die Framework-Zielkonfiguration und Snapshot-Targettabellen und schreibt gebundene Capture-/Modulzeilen. Datenbankzugang und Zielrechte müssen für den konkreten Aufruf vorliegen; der Helper verleiht sie nicht.

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
| @DatabaseNames | nvarchar(max) | nein | NULL |
| @SystemdatenbankenEinbeziehen | bit | nein | 0 |
| @DatabaseNamePattern | nvarchar(4000) | nein | NULL |
| @Hilfe | bit | nein | 0 |

**@SchedulerType:** - @SchedulerType (varchar(16), Eingabe; Default: kein Default): MANUAL (manueller Aufruf), EXTERNAL (externer Aufruf) oder SQL_AGENT (SQL-Agent-Aufruf). Der Vergleich verwendet die aktuelle Datenbankcollation und deren Paddingregeln; es erfolgt kein TRIM oder UPPER. NULL, Leertext und andere Werte sind ungültig.

**@RunEvenIfNotDue:** - @RunEvenIfNotDue (bit, Eingabe; Default: kein Default): 0 beachtet den Intervallskip, 1 umgeht ihn. NULL ist ungültig; numerische Werte ungleich 0 werden bei Bit-Konvertierung zu 1. Leertext ist keine unterstützte Eingabe. Der Größenstopp bleibt wirksam.

**@CaptureRunIdOut:** - @CaptureRunIdOut (bigint OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs NULL. Gibt die bei Vorbereitung erzeugte Capture-ID aus. Sie kann nach einem späteren Fehler erhalten bleiben; sie allein bestätigt keine Sammlung oder Finalisierung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@TargetDatabaseNameOut:** - @TargetDatabaseNameOut (sysname OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs NULL. Gibt den konfigurierten Targetnamen aus; er kann bereits bei DISABLED ausgefüllt sein. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@StatusCodeOut:** - @StatusCodeOut (varchar(40) OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs AVAILABLE. Gibt den aktuellen Status zurück. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@IsPartialOut:** - @IsPartialOut (bit OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs 0. 1 kennzeichnet Einschränkung oder unbestätigtes Ergebnis; 0 beweist keine native Erfassung. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorNumberOut:** - @ErrorNumberOut (int OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs NULL. Enthält eine gemeldete Fehlernummer oder NULL, wenn der betreffende Statuspfad keine Nummer setzt. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@ErrorMessageOut:** - @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs NULL. Enthält verfügbaren Fehler- oder Einschränkungstext bis 2048 Zeichen. Bei @Hilfe=1 bleibt ein mit OUTPUT gebundener Aufrufwert unverändert; die normale Initialisierung erfolgt nur im Fachpfad.

**@DatabaseNames:** - @DatabaseNames (nvarchar(max), Eingabe; Default: NULL): optional, ausgelassen entspricht NULL. Pipe-getrennte, bracket-aware Liste einteiliger Datenbanknamen; | trennt nur außerhalb von Klammern, ]] maskiert ] innen. Äußere Elementleerzeichen werden entfernt. Rohsegment maximal 4000 UTF-16-Codeeinheiten, Name maximal 128 Zeichen. Leere oder fehlerhaft geklammerte Elemente und case-sensitive Duplikate sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Liste. Fehlende oder nicht zugängliche Namen erzeugen Warnungen und verwerfen nicht automatisch alle übrigen Kandidaten.

**@SystemdatenbankenEinbeziehen:** - @SystemdatenbankenEinbeziehen (bit, Eingabe; Default: 0): optional. 0 schließt IDs <=4 aus; 1 lässt Systemdatenbanken zu, garantiert ihre Auswahl oder Zugänglichkeit aber nicht. NULL ist ungültig. Leertext ist keine unterstützte Bit-Eingabe; numerische Werte ungleich 0 werden zu 1 konvertiert.

**@DatabaseNamePattern:** - @DatabaseNamePattern (nvarchar(4000), Eingabe; Default: NULL): optional; NULL oder ausgelassen bedeutet kein Pattern. Äußere Leerzeichen werden entfernt. Zulässig sind LIKE-Muster sowie case-insensitiv erkannte Präfixe like:, regex:, regexi:. LIKE verwendet SQL_Latin1_General_CP1_CS_AS mit dessen Paddingregeln, nicht binäre Gleichheit; %, _, und [...] behalten LIKE-Bedeutung. Die Präfixerkennung ist case-insensitiv. Nur äußere U+0020-Leerzeichen werden entfernt; der Inhalt nach dem Präfix wird nicht erneut getrimmt. regex: verwendet Option c, regexi: Option i. Leerer Wert oder leeres Präfixergebnis ist ungültig. Ein nicht-NULL Pattern ist mit einer wirksamen Namensliste unzulässig. Regex benötigt SQL Server 2025 und Compatibility Level mindestens 170 für die Installationsdatenbank; Regexsyntax kann SQL-Fehler auslösen. Es werden keine Features installiert oder aktiviert.

**@Hilfe:** bit, Default 0; 1 liefert vor Fachzugriff genau ein Usage-Skill-Resultset. Vorhandene reguläre PRINT-Meldungen bleiben dem normalen Fachpfad vorbehalten. Der Hilfezweig initialisiert OUTPUT-Parameter nicht; übergebene Werte bleiben unverändert. 0 und NULL folgen dem bisherigen normalen Prozedurpfad.

## Resultate und Ausgabe

Kein Fach-Resultset. `@CaptureRunIdOut bigint`, `@TargetDatabaseNameOut sysname`, `@StatusCodeOut varchar(40)`, `@IsPartialOut bit`, `@ErrorNumberOut int` und `@ErrorMessageOut nvarchar(2048)` melden Vorbereitung, Ziel und File-I/O-Abschluss. Run-ID und Zielname können auch bei späterer Teil-/Fehlerlage gesetzt sein; eine erfolgreiche Speicherung ist nur aus Status und gebundenem Zielkontext abzuleiten.

## Beispiel

Der interne Helper ist kein selbstständiger Fachbericht. Der lesende Katalogaufruf zeigt den Vertrag, ohne den Helper auszuführen:

```sql
SELECT [SkillMarkdown]
FROM [monitor_metadata].[VW_ObjectUsageSkills]
WHERE [SchemaName]=N'monitor' AND [ObjectName]=N'InternalRunSnapshotFileIOCycle';
```

Der folgende Aufruf demonstriert ausschließlich den frühen Hilfezweig; die NULL-Pflichtwerte sind nicht für den normalen Fachpfad zulässig:

```sql
EXEC [monitor].[InternalRunSnapshotFileIOCycle] @SchedulerType=NULL, @RunEvenIfNotDue=NULL, @CaptureRunIdOut=NULL, @TargetDatabaseNameOut=NULL, @StatusCodeOut=NULL, @IsPartialOut=NULL, @ErrorNumberOut=NULL, @ErrorMessageOut=NULL, @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die acht zuerst deklarierten Parameter sind erforderlich; sie können positionsgebunden in Signaturreihenfolge oder mit Parameternamen gebunden werden. Die drei Datenbankfilter am Ende sind optional. Eingabewerte der OUTPUT-Parameter werden ignoriert. Zum Empfang ist eine typgerechte Aufrufervariable mit OUTPUT erforderlich. Soll die Ausgabe verworfen werden, kann ein typisierter NULL-Wert oder kompatibler skalarer Wert ohne OUTPUT gebunden werden; die normale SQL-Typkonvertierung gilt weiterhin. Status wird anfangs AVAILABLE, Partialität 0, Capture-ID, Targetname, Fehlernummer und Fehlermeldung werden anfangs NULL gesetzt. Eine NULL-Fehlermeldung bedeutet, dass kein Text vorliegt; Leertext ist davon verschieden.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.InternalRunSnapshotFileIOCycle
Version      : 1.0.0
Stand        : 2026-10-26
Zweck        : Die Procedure erfasst den nativen Datei-I/O-Cache für ausgewählte Online-
               datenbanken und bindet ihn an beobachtete Engine-, Datenbank-
               und Dateimetadaten sowie den eigenen Targetlauf.
Grenze       : Der vollständige VFS-Read belegt keine atomare Sicht. Vorher-/Nachher-
               Beobachtungen belegen weder eine ununterbrochene Resetkontinuität
               noch eine atomare DMV-Sicht.
Voraussetzung: Aktuelles SC-023-Target mit Version 1.3.1 und Schema 3 sowie
               SQL Server 2025 und Compatibility Level 170 für Regex-Filter.
===============================================================================

#### monitor.InternalRunSnapshotFileIOCycle – Parameterverträge

Die acht zuerst deklarierten Parameter sind erforderlich; sie können positionsgebunden in Signaturreihenfolge oder mit Parameternamen gebunden werden. Die drei Datenbankfilter am Ende sind optional. Eingabewerte der OUTPUT-Parameter werden ignoriert. Zum Empfang ist eine typgerechte Aufrufervariable mit OUTPUT erforderlich. Soll die Ausgabe verworfen werden, kann ein typisierter NULL-Wert oder kompatibler skalarer Wert ohne OUTPUT gebunden werden; die normale SQL-Typkonvertierung gilt weiterhin. Status wird anfangs AVAILABLE, Partialität 0, Capture-ID, Targetname, Fehlernummer und Fehlermeldung werden anfangs NULL gesetzt. Eine NULL-Fehlermeldung bedeutet, dass kein Text vorliegt; Leertext ist davon verschieden.

- @SchedulerType (varchar(16), Eingabe; Default: kein Default): MANUAL (manueller Aufruf), EXTERNAL (externer Aufruf) oder SQL_AGENT (SQL-Agent-Aufruf). Der Vergleich verwendet die aktuelle Datenbankcollation und deren Paddingregeln; es erfolgt kein TRIM oder UPPER. NULL, Leertext und andere Werte sind ungültig.
- @RunEvenIfNotDue (bit, Eingabe; Default: kein Default): 0 beachtet den Intervallskip, 1 umgeht ihn. NULL ist ungültig; numerische Werte ungleich 0 werden bei Bit-Konvertierung zu 1. Leertext ist keine unterstützte Eingabe. Der Größenstopp bleibt wirksam.
- @CaptureRunIdOut (bigint OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs NULL. Gibt die bei Vorbereitung erzeugte Capture-ID aus. Sie kann nach einem späteren Fehler erhalten bleiben; sie allein bestätigt keine Sammlung oder Finalisierung.
- @TargetDatabaseNameOut (sysname OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs NULL. Gibt den konfigurierten Targetnamen aus; er kann bereits bei DISABLED ausgefüllt sein.
- @StatusCodeOut (varchar(40) OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs AVAILABLE. Gibt den aktuellen Status zurück.
- @IsPartialOut (bit OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs 0. 1 kennzeichnet Einschränkung oder unbestätigtes Ergebnis; 0 beweist keine native Erfassung.
- @ErrorNumberOut (int OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs NULL. Enthält eine gemeldete Fehlernummer oder NULL, wenn der betreffende Statuspfad keine Nummer setzt.
- @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: kein Default): erforderliches Argument; Eingabe ignoriert und anfangs NULL. Enthält verfügbaren Fehler- oder Einschränkungstext bis 2048 Zeichen.
- @DatabaseNames (nvarchar(max), Eingabe; Default: NULL): optional, ausgelassen entspricht NULL. Pipe-getrennte, bracket-aware Liste einteiliger Datenbanknamen; | trennt nur außerhalb von Klammern, ]] maskiert ] innen. Äußere Elementleerzeichen werden entfernt. Rohsegment maximal 4000 UTF-16-Codeeinheiten, Name maximal 128 Zeichen. Leere oder fehlerhaft geklammerte Elemente und case-sensitive Duplikate sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Liste. Fehlende oder nicht zugängliche Namen erzeugen Warnungen und verwerfen nicht automatisch alle übrigen Kandidaten.
- @SystemdatenbankenEinbeziehen (bit, Eingabe; Default: 0): optional. 0 schließt IDs <=4 aus; 1 lässt Systemdatenbanken zu, garantiert ihre Auswahl oder Zugänglichkeit aber nicht. NULL ist ungültig. Leertext ist keine unterstützte Bit-Eingabe; numerische Werte ungleich 0 werden zu 1 konvertiert.
- @DatabaseNamePattern (nvarchar(4000), Eingabe; Default: NULL): optional; NULL oder ausgelassen bedeutet kein Pattern. Äußere Leerzeichen werden entfernt. Zulässig sind LIKE-Muster sowie case-insensitiv erkannte Präfixe like:, regex:, regexi:. LIKE verwendet SQL_Latin1_General_CP1_CS_AS mit dessen Paddingregeln, nicht binäre Gleichheit; %, _, und [...] behalten LIKE-Bedeutung. Die Präfixerkennung ist case-insensitiv. Nur äußere U+0020-Leerzeichen werden entfernt; der Inhalt nach dem Präfix wird nicht erneut getrimmt. regex: verwendet Option c, regexi: Option i. Leerer Wert oder leeres Präfixergebnis ist ungültig. Ein nicht-NULL Pattern ist mit einer wirksamen Namensliste unzulässig. Regex benötigt SQL Server 2025 und Compatibility Level mindestens 170 für die Installationsdatenbank; Regexsyntax kann SQL-Fehler auslösen. Es werden keine Features installiert oder aktiviert.

Callertransaktionen und implizite Transaktionen werden früh mit INVALID_PARAMETER und Return 51011 abgewiesen. Die Auswahl betrachtet sichtbare, online befindliche und zugängliche Kandidaten; Snapshots werden ausgeschlossen. Die Namen werden case-sensitive behandelt. Der Parser verwendet PARSENAME für den einteiligen Namen und prüft keine vollständige SQL-Bezeichnergrammatik. Der Aufruf verwendet STANDARD_CURRENT mit HighImpactConfirmed=0; das aktuelle Katalogelement hat RequiresGroupGate=0. Die Klassen- und Pfadprüfung des Helpers bleibt aktiv, DENIED_GROUP und HIGH_IMPACT_CONFIRMATION_REQUIRED sind für diesen konkreten Aufruf keine erwarteten kanonischen Statusausgänge.

#### monitor.InternalRunSnapshotFileIOCycle – Ablauf und Evidenzgrenzen

Ein nicht wartender Session-Applock SQL_Server_Analyze.SC023.CollectionCycle wird mit Purge und anderen Collectionläufen geteilt. Jeder negative Rückgabewert von sp_getapplock führt zu SKIPPED_CONCURRENT. Die Reihenfolge ist initiale Targetprüfung, PolicyOnly, Datenbankkandidaten, Purge, Revalidierung, Vorbereitung und erneute Revalidierung. FILE_IO benötigt SC-023 Version 1.3.1 / Schema 3.

Nur bei mindestens einer ausgewählten Datenbank erfolgt genau ein vollständiger sys.dm_io_virtual_file_stats(NULL,NULL)-Read. Datenbankfilter und MaxRows begrenzen diesen Read nicht, sondern greifen erst danach. Ein leerer Scope wird als leer oder nicht gestartet ausgewiesen, nicht als bestätigte Nullmessung. Pro ausgewählter Datenbank werden Dateimetadaten vorher und nachher gelesen. Diese Beobachtungen sind nicht atomar und beweisen keine ununterbrochene Resetkontinuität.

Berücksichtigt werden ROWS (Dateityp 0) und LOG (Typ 1); andere Dateitypen und Offline-Dateien werden ausgeschlossen. Der Vorher-/Nachher-Identitätsvergleich kann Änderungen erkennen, beweist aber keine unveränderte Identität während des Intervalls. Erfolgreiche Backendaufnahmen bleiben wegen der DMV- und Resetgrenzen PARTIAL. Ein gesundes Backend kann somit eine partielle Aufnahme speichern.

Fehlende oder nicht zugängliche Namen werden als Warnungen oder Issues geführt; einzelne Fehler verwerfen nicht pauschal alle übrigen Kandidaten. Der Purge darf AVAILABLE, AVAILABLE_LIMITED oder SKIPPED_NOT_DUE liefern. AVAILABLE_LIMITED bedeutet, dass das Batchlimit mit einem löschenden Batch erreicht wurde. SKIPPED_NOT_DUE kann vor einem späteren Capture regulär finalisiert werden.

Backendabschluss und Ergebnisprojektion sind getrennte Nachweise. FINALIZATION_UNCONFIRMED bleibt auch bei äußerem CATCH oder Fehler beim Freigeben des Locks erhalten. Eine gespeicherte Aufnahme bleibt bestehen; fehlgeschlagenes Readback erzeugt keine erfundene Runzeile. Eine Capture-ID allein bestätigt keinen Erfolg. Die Caller-Ergebnistabellen #RunSnapshotCollectionCycle_Run und #RunSnapshotCollectionCycle_Modules müssen vorab existieren. Vier eigene lokale #Temp-Tabellen entstehen vor dem äußeren TRY; deren Erstellungsfehler können daher als native SQL-Fehler entkommen. Die Fehlerbehandlung fängt nicht sämtliche SQL-Fehler auf.

#### monitor.InternalRunSnapshotFileIOCycle – Statusvertrag

Die 14 aktuellen kanonischen Statuswerte haben folgende Bedeutung:

- AVAILABLE: initialer Status und Status für verfügbare Schritte oder explizit durchgereichte Helperantwort; beim Sammler kein Beleg eines Reads oder finalen Purgeabschlusses.
- INVALID_PARAMETER: Eingabe, Transaktionskontext oder Vertragsvoraussetzung ungültig; der frühe Guard liefert Return 51011.
- TARGET_UNAVAILABLE: Target oder benötigter Targetvertrag wurde nicht bestätigt.
- DENIED_PERMISSION: ein im vorgesehenen TRY/CATCH erkannter Berechtigungsfehler.
- DISABLED: Snapshotpaket oder FILE_IO-Sammler ist deaktiviert.
- SKIPPED_CONCURRENT: sp_getapplock lieferte einen beliebigen negativen Rückgabewert; es wird nicht auf den Lock gewartet.
- SKIPPED_NOT_DUE: der Vorbereitungsschritt bestätigt bei RunEvenIfNotDue=0, dass das konfigurierte Intervall seit dem letzten beendeten FILE_IO-Lauf noch nicht abgelaufen ist. Dieser finale Sammlerstatus ist keine Aussage über einen erfolgreichen Purge oder ein aktuell gemessenes Größenbudget. Force=1 umgeht den Intervallskip, nicht DISABLED, ungültige Targetidentität, Lockkonflikt oder Größenbudget.
- STOPPED_SIZE_BUDGET: die Policy stoppt die Sammlung wegen des Größenbudgets.
- PARTIAL: vom Backend bestätigte Speicherung mit den inhärenten Grenzen der Datei-I/O-Beobachtung.
- UNAVAILABLE_OBJECT: ein benötigtes Objekt fehlt oder ist nicht verfügbar.
- ERROR_HANDLED: ein anderer Fehler wurde im behandelten Pfad gemeldet; Fehler vor TRY oder innerhalb eines Fehlerpfads können entkommen.
- INTERNAL_ERROR: interne Kandidatentabellenprüfung ist fehlgeschlagen.
- UNAVAILABLE_FEATURE: Regex kann mangels Engineversion oder Installations-Compatibility-Level nicht ausgeführt werden.
- FINALIZATION_UNCONFIRMED: Das Backend konnte den Abschluss beziehungsweise seine Fehlerfinalisierung nicht bestätigen. Ein späterer Projektionsfehler allein setzt diesen Status nicht; ein bereits gemeldeter Wert bleibt dabei erhalten. Eine gespeicherte Aufnahme bleibt möglich und wird nicht als bestätigter Erfolg ausgegeben.

AVAILABLE_LIMITED ist kein finaler Sammlerstatus. Es ist ein akzeptierter Purge-Zwischenstatus und bedeutet, dass das Batchlimit nach einem löschenden Batch erreicht wurde. Ein Purge-Status SKIPPED_NOT_DUE verhindert die spätere Vorbereitung und Finalisierung des Datei-I/O-Capture nicht.

Die Kandidatenroutine kann DENIED_GROUP oder HIGH_IMPACT_CONFIRMATION_REQUIRED für andere Klassen oder Freigabekonfigurationen liefern. Diese Helperausgaben sind keine erwarteten kanonischen Ergebnisse des fest verdrahteten STANDARD_CURRENT-Aufrufs mit HighImpactConfirmed=0; unerwartete Codes können weitergereicht werden. Der öffentliche Datei-I/O-Vertrag beschreibt die übergreifende Retentionsemantik.
```

