---
skill_format_version: "1.0.0"
name: "monitor.USP_ConfigureSnapshotTarget"
schema_name: "monitor"
object_name: "USP_ConfigureSnapshotTarget"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Aktiviert ein explizit installiertes SC-023-Ziel und schreibt alle bekannten Collector-/Retentionwerte typisiert."
source_path: "Code/10_SnapshotBaseline/080_USP_ConfigureSnapshotTarget.sql"
---

# monitor.USP_ConfigureSnapshotTarget

## Zweck und Einsatz

Aktiviert ein explizit installiertes SC-023-Ziel und schreibt alle bekannten Collector-/Retentionwerte typisiert.

## Voraussetzungen und Rechte

Der Aufruf braucht EXECUTE auf [monitor].[USP_ConfigureSnapshotTarget] im vorgesehenen Datenbankkontext. Die Procedure liest und aktualisiert die eigene `monitor.SnapshotTargetConfiguration` und prüft den benannten Snapshot-Zielkontext. EXECUTE allein belegt keine Schreibrechte auf eine fremde Ziel-Datenbank; die Ausführung benötigt den vorgesehenen Installations-/Zugriffskontext.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @TargetDatabaseName | sysname | ja | kein Default |
| @IsEnabled | bit | nein | 1 |
| @SchedulerType | varchar(16) | nein | 'EXTERNAL' |
| @CollectionIntervalSeconds | smallint | nein | 30 |
| @MaxRows | int | nein | 1000 |
| @PayloadEnabled | bit | nein | 0 |
| @RawRetentionDays | smallint | nein | 14 |
| @PayloadRetentionDays | smallint | nein | 7 |
| @RollupRetentionDays | smallint | nein | 180 |
| @SoftBudgetMB | int | nein | 10240 |
| @PurgeIntervalMinutes | smallint | nein | 60 |
| @PurgeBatchRows | int | nein | 10000 |
| @BudgetAction | varchar(32) | nein | 'PURGE_EXPIRED_THEN_STOP' |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |
| @StatusCodeOut | varchar(40) | nein | NULL OUTPUT |
| @IsPartialOut | bit | nein | NULL OUTPUT |
| @ErrorNumberOut | int | nein | NULL OUTPUT |
| @ErrorMessageOut | nvarchar(2048) | nein | NULL OUTPUT |
| @CollectorCode | varchar(64) | nein | 'PERFORMANCE_COUNTERS' |
| @CollectorEnabled | bit | nein | 1 |
| @UpdateSharedPolicy | bit | nein | NULL |

**@TargetDatabaseName:** @TargetDatabaseName sysname. Kein Default; Pflichtargument. Pflichtargument ohne Default, auch bei Hilfe: ein einzelner Datenbankname als sysname mit höchstens 128 Zeichen, ohne Server-/Schemaqualifier oder Liste. Der übergebene Name wird als Datenwert mit QUOTENAME verwendet; Bezeichnerklammern sind keine automatisch entfernte Eingabemaskierung. Normalaufrufe benötigen einen nicht-NULL, nicht nur aus Leerzeichen bestehenden Namen eines separat installierten, erreichbaren, online befindlichen und schreibbaren SC-023-Ziels. Bei neuen Collectoroptionen werden Systemdatenbanken, Frameworkselbstziel und eine nicht passende Zielidentität abgewiesen; Datenbank-ID und Erstellungszeitpunkt werden vor dem Write gebunden. Es wird keine Datenbank angelegt.

**@IsEnabled:** @IsEnabled bit. Default ist 1. bit-Schalter für die gemeinsame Framework-Zielkonfiguration: 0 deaktiviert sie, 1 aktiviert sie. NULL ist in der gemeinsamen Aktualisierung ungültig. Bei @UpdateSharedPolicy=0 bleibt dieser gemeinsam gespeicherte Wert unberührt und wird nicht wirksam verwendet; bei Collector-only-Konfiguration gilt die bestehende Bindung. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.

**@SchedulerType:** @SchedulerType varchar(16). Default ist 'EXTERNAL'. Ein Code: MANUAL kennzeichnet manuellen Aufruf, EXTERNAL einen externen Scheduler und SQL_AGENT einen SQL-Server-Agent-Aufruf. Äußere Leerzeichen werden entfernt und Großschreibung normalisiert. NULL wird zu leer normalisiert; bei gemeinsamer Aktualisierung sind leere oder unbekannte Codes ungültig. Bei UpdateSharedPolicy=0 wird der Wert nicht geprüft oder geschrieben. Es werden weder Schedulerobjekte noch Agent-Jobs erzeugt oder gestartet.

**@CollectionIntervalSeconds:** @CollectionIntervalSeconds smallint. Default ist 30. Ganzzahlige Sekunden von 1 bis 3600 für die ausgewählte Collectorpolicy. Der Wert wird auch bei UpdateSharedPolicy=0 geschrieben; er ist keine gemeinsame Retentionseinstellung. Er speichert den Mindestabstand für spätere Zyklen, startet aber keinen Collector und wartet nicht. NULL ist im neuen Policyvertrag explizit ungültig; der Legacy-Pfad prüft NULL nicht vollständig vor dem Zielwrite. 0 ist nicht unbegrenzt.

**@MaxRows:** @MaxRows int. Default ist 1000. int, positive ganze Zeilenzahl von 1 bis 100000 je Collection-Grenze. NULL ist im neuen Policyvertrag ungültig, Werte außerhalb des Bereichs ungültig. Gilt für die ausgewählte Collectorpolicy. Bei shared=0 wird diese Collectorgrenze aktualisiert; der Parameter ist wirksam.

**@PayloadEnabled:** @PayloadEnabled bit. Default ist 0. 0 speichert keine Payloadfreigabe, 1 erlaubt optionale Payloads nach dem Collectorvertrag. Es wird ausschließlich PayloadEnabled der ausgewählten Collectorpolicy geschrieben, auch bei UpdateSharedPolicy=0; dieser Konfigurationsaufruf erfasst keine Payloaddaten. NULL ist im neuen Policyvertrag explizit ungültig und kann im Legacy-Pfad erst am Zielwrite scheitern. T-SQL konvertiert numerische Nichtnullwerte zuvor zu bit 1; verwenden Sie 0 oder 1.

**@RawRetentionDays:** @RawRetentionDays smallint. Default ist 14. smallint in Tagen, im Bereich 1 bis 3650. NULL und Bereichsverletzung sind ungültig, wenn @UpdateSharedPolicy=1; andernfalls bleibt die gemeinsame Retention erhalten und der übergebene Wert wird ignoriert. Bestimmt die Aufbewahrungsdauer der Rohdaten. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.

**@PayloadRetentionDays:** @PayloadRetentionDays smallint. Default ist 7. smallint in Tagen, 1 bis 3650. Bei shared=1 darf der Wert nicht NULL und nicht außerhalb des Bereichs sein; bei shared=0 wird er ignoriert. Bestimmt die Payload-Aufbewahrung. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.

**@RollupRetentionDays:** @RollupRetentionDays smallint. Default ist 180. smallint in Tagen, 1 bis 3650. Bei shared=1 erforderlich und im Bereich; bei shared=0 wirkungslos und die vorhandene gemeinsame Rollup-Retention bleibt bestehen. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.

**@SoftBudgetMB:** @SoftBudgetMB int. Default ist 10240. int in MiB, von 1 bis 2147483647. Bei shared=1 darf der Wert nicht NULL oder kleiner 1 sein. Bei shared=0 wird das gemeinsame Budget nicht geändert und der Wert ignoriert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.

**@PurgeIntervalMinutes:** @PurgeIntervalMinutes smallint. Default ist 60. smallint in Minuten, 1 bis 1440. Bei shared=1 erforderlich und bereichsgeprüft; bei shared=0 bleibt der gemeinsame Purge-Takt unverändert und der Wert wird ignoriert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.

**@PurgeBatchRows:** @PurgeBatchRows int. Default ist 10000. int, Zeilen je Purge-Batch, 1 bis 100000. Bei shared=1 erforderlich und bereichsgeprüft; bei shared=0 wird die gemeinsame Purge-Batchgrenze nicht geändert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default.

**@BudgetAction:** @BudgetAction varchar(32). Default ist 'PURGE_EXPIRED_THEN_STOP'. varchar(32), nach Trimmen und Großschreibung ausschließlich PURGE_EXPIRED_THEN_STOP. Der Wert bezeichnet das Löschen abgelaufener Daten vor dem Anhalten bei weiterhin überschrittenem Softbudget. NULL oder ein anderer Text ist bei shared=1 ungültig; bei shared=0 ignoriert, da die gemeinsame Budgetpolicy unverändert bleibt. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. Dieser Aufruf speichert nur den Aktionscode und führt keinen Purge aus.

**@PrintMeldungen:** @PrintMeldungen bit. Default ist 1. bit-Ausgabeschalter: 0 unterdrückt die abschließende Severity-10-Statusmeldung bei Fehlern; 1 gibt sie mit RAISERROR ... WITH NOWAIT aus. NULL verhält sich nicht wie 1 und unterdrückt die Bedingung (SQL NULL-Vergleich); beeinflusst weder Status-OUTPUT noch Persistenz. Hilfe-PRINTs werden hiervon nicht gesteuert. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.

**@Hilfe:** @Hilfe bit. Default ist 0. 1 druckt die Hilfe und kehrt vor Zielprüfung und persistenten Konfigurationswrites zurück; 0 oder NULL folgt dem normalen Pfad. TargetDatabaseName bleibt als Pflichtargument erforderlich. Der frühe Hilfezweig für neue oder ungültige Collectoroptionen liegt vor der Collector-/Transaktionsvalidierung und vor SET XACT_ABORT/LOCK_TIMEOUT. Der Legacy-Hilfezweig liegt nach SET XACT_ABORT ON und LOCK_TIMEOUT 0. NOCOUNT und die initialisierten Status-OUTPUTs werden bereits zuvor gesetzt. Ein Hilfeaufruf belegt deshalb keine zulässige normale Konfiguration. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.

**@StatusCodeOut:** @StatusCodeOut varchar(40) OUTPUT. Default ist NULL. varchar(40) OUTPUT; als Variable binden und nach dem EXEC auslesen. Liefert den Status dieses Aufrufs, anfänglich AVAILABLE, bei Fehlerpfaden unter anderem INVALID_PARAMETER, TARGET_UNAVAILABLE oder DENIED_PERMISSION. Im Hilfezweig bleibt der initialisierte Wert AVAILABLE. Kein Resultset. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen.

**@IsPartialOut:** @IsPartialOut bit OUTPUT. Default ist NULL. bit OUTPUT; als Variable binden. 0 bedeutet kein als partiell markierter Fehler, 1 kennzeichnet einen Fehler-/Teilstatus. Wird beim Eintritt auf 0 gesetzt und in den Fehlerpfaden typischerweise auf 1; im Hilfezweig bleibt es 0. Kein separates Resultset. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen.

**@ErrorNumberOut:** @ErrorNumberOut int OUTPUT. Default ist NULL. int OUTPUT; als Variable binden. NULL bedeutet, dass beim initialisierten Status keine Fehlernummer gesetzt ist; Fehlerpfade liefern die ermittelte SQL- oder Vertragsfehlernummer, soweit vorhanden. Wird beim Eintritt auf NULL gesetzt und bei Hilfe nicht geändert. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen.

**@ErrorMessageOut:** @ErrorMessageOut nvarchar(2048) OUTPUT. Default ist NULL. Optionaler nvarchar(2048)-OUTPUT-Empfang für Unicode-Fehlertext mit höchstens 2048 UTF-16-Codeeinheiten. Der Anfangswert wird auf NULL gesetzt. Ohne Fehler kann NULL zurückkommen; eine Meldung allein ersetzt nicht die Statusprüfung. Aufruf als Variable mit OUTPUT, sonst wird beim Aufrufer kein Wert empfangen.

**@CollectorCode:** @CollectorCode varchar(64). Default ist 'PERFORMANCE_COUNTERS'. Nach Trim und Großschreibung sind genau PERFORMANCE_COUNTERS (Performance-Counter-Policy), WAIT_STATS (Wait-Statistik-Policy) und FILE_IO (Datei-I/O-Policy) zulässig. NULL wird zu leer und ist bei normalem Aufruf ungültig. Für WAIT_STATS erkennt die Admission die Version/Schema-Paare 1.2.1/2, 1.3.0/3 und 1.3.1/3 und fordert dazu Retentionsvertrag 1, 2 beziehungsweise 3 sowie passende Signaturen. Das Versionsetikett allein reicht nicht: der aktuelle Purge-Helfer liefert bei 1.3.0/3 Vertrag 3 statt 2; diese Kombination wird abgewiesen. Eine funktionsfähige historische 1.3.0-Closure wird hier nicht qualifiziert. FILE_IO verlangt 1.3.1/3 mit Retentionsvertrag 3. PERFORMANCE_COUNTERS mit CollectorEnabled=1 und wirksamem UpdateSharedPolicy=1 nimmt den Legacy-Pfad; andere Performance-Counter-Kombinationen benötigen ebenfalls die neue Admission. Die Auswahl startet keine Sammlung.

**@CollectorEnabled:** @CollectorEnabled bit. Default ist 1. bit-Schalter: 0 deaktiviert, 1 aktiviert ausschließlich den ausgewählten Collector. NULL ist ungültig. Kombinationen mit CollectorCode und UpdateSharedPolicy bestimmen den neuen Policyvertrag; ein deaktivierter Collector erzwingt diesen Vertrag. Der Wert aktiviert weder Datenbank noch Job. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.

**@UpdateSharedPolicy:** @UpdateSharedPolicy bit. Default ist NULL. 0 erhält Framework-Singleton und gemeinsame Retention/Budget/Purgewerte sowie die bisherige Retentionszuordnung. CollectorEnabled, CollectionIntervalSeconds, MaxRows und PayloadEnabled der gewählten Policy werden trotzdem geschrieben. IsEnabled, SchedulerType und gemeinsame Retentions-/Budget-/Purgeargumente werden bei 0 ignoriert. 1 ändert gemeinsame Werte und gewählte Policy atomar. NULL löst vor der Hilfe zu 1 für PERFORMANCE_COUNTERS, sonst zu 0 für WAIT_STATS oder FILE_IO auf. Neue Varianten mit 0 benötigen eine bereits passende Framework-Zielbindung. Der normale neue Vertrag weist Callertransaktionen und IMPLICIT_TRANSACTIONS ON zurück; der Legacy-Pfad hat keine entsprechende Vorabablehnung und sollte ebenfalls außerhalb eigener Transaktionen aufgerufen werden. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an.

## Resultate und Ausgabe

Der normale Aufruf liefert Status über `@StatusCodeOut` (varchar(40) OUTPUT, zunächst AVAILABLE), `@IsPartialOut` (bit OUTPUT, zunächst 0), `@ErrorNumberOut` (int OUTPUT, zunächst NULL) und `@ErrorMessageOut` (nvarchar(2048) OUTPUT, zunächst NULL). Erkannte Parameter-, Ziel- oder Berechtigungsfehler ändern diese Ausgaben; ein Status allein ersetzt weder Identitäts- noch Retentionsprüfung. Die Procedure persistiert bei gültigem Fachaufruf typisierte Collector-/Retentionkonfiguration in Framework und ausdrücklich gewähltem Snapshot-Ziel. Im Hilfezweig bleiben die initialisierten OUTPUTs AVAILABLE/0/NULL/NULL, und es gibt genau ein Skill-Resultset zusätzlich zu bestehenden PRINT-Hinweisen; die Zielkonfiguration wird dort nicht geschrieben.

## Beispiel

```sql
EXEC [monitor].[USP_ConfigureSnapshotTarget] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Persistente Konfiguration in Framework- und Snapshot-Datenbank.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_ConfigureSnapshotTarget
Version      : 1.2.0
Stand        : 2026-10-26
Zweck        : Aktiviert ein explizit installiertes SC-023-Ziel und schreibt
               alle bekannten Collector-/Retentionwerte typisiert.
Nebenwirkung : Persistente Konfiguration in Framework- und Snapshot-Datenbank.
Rechte       : Vergibt keine Rechte; DDL-/DML- und EXECUTE-Rechte sind extern.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_ConfigureSnapshotTarget
Beispiel 1. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase', @Hilfe=1, @CollectorCode='PERFORMANCE_COUNTERS', @CollectorEnabled=1, @UpdateSharedPolicy=1;
Beispiel 2. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase', @Hilfe=1, @CollectorCode='WAIT_STATS', @CollectorEnabled=1, @UpdateSharedPolicy=0;
Beispiel 3. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase', @Hilfe=1, @CollectorCode='WAIT_STATS', @CollectorEnabled=0, @UpdateSharedPolicy=1;
Beispiel 4. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase', @Hilfe=1, @CollectorCode='FILE_IO', @CollectorEnabled=1, @UpdateSharedPolicy=1;
monitor.USP_ConfigureSnapshotTarget
Beispiel 1. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase', @Hilfe=1, @CollectorCode='PERFORMANCE_COUNTERS', @CollectorEnabled=1, @UpdateSharedPolicy=1;
Beispiel 2. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase', @Hilfe=1, @CollectorCode='WAIT_STATS', @CollectorEnabled=1, @UpdateSharedPolicy=0;
Beispiel 3. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase', @Hilfe=1, @CollectorCode='WAIT_STATS', @CollectorEnabled=0, @UpdateSharedPolicy=1;
Beispiel 4. EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase', @Hilfe=1, @CollectorCode='FILE_IO', @CollectorEnabled=1, @UpdateSharedPolicy=1;
```

