# [monitor].[USP_ConfigureSnapshotTarget]

**Bereich:** Optionales Snapshot-/Baseline-Paket SC-023
**Zweck:** Verknüpft die Frameworkdatenbank mit einer separat installierten Snapshot-Datenbank und schreibt Collector-, Retention- und Budgetpolicy typisiert.
**Beobachtungsart:** expliziter lokaler Konfigurations-Schreibvorgang
**Kostenklasse:** LOW

## Entscheidungsfrage und Einsatz

Die Procedure wird eingesetzt, wenn eine bereits installierte Frameworkdatenbank genau einer bereits installierten lokalen Snapshot-Datenbank zugeordnet werden soll. Sie schreibt Aktivierung, Schedulerart, Collectorgrenzen, Retention und Softbudget in die dafür vorgesehenen typisierten Konfigurationsobjekte. Der Aufruf ist keine allgemeine Zielsuche und kein Deploymentmechanismus.

## Nicht beantwortete Fragen

Eine erfolgreiche Konfiguration beweist weder spätere DMV-Leserechte noch ausreichenden Speicher, Backup, Recovery oder Schedulerbetrieb. Die Procedure entscheidet nicht, welcher Retentionswert fachlich angemessen ist, und prüft keine Fleet-, Transport- oder Mandantengrenzen. Ein deaktivierter Collector sagt nichts über bereits gespeicherte Historie aus.

## Sicherer Einstieg

Die Procedure erstellt weder Datenbanken noch Rechte oder Schedulerobjekte. Der Aufruf ist erst nach beiden SC-023-Installern sinnvoll. Alle Beispielnamen sind synthetisch.

```sql
EXEC [monitor].[USP_ConfigureSnapshotTarget]
     @TargetDatabaseName = N'ExampleSnapshotDatabase',
     @IsEnabled = 0,
     @SchedulerType = 'EXTERNAL',
     @PayloadEnabled = 0;
```

## Parameter

| Parameter | Typ | Default | Eingabe und Wirkung |
|---|---|---|---|
| `@TargetDatabaseName` | `sysname` | Keiner; Pflichtargument | Pflichtargument ohne Default, auch bei Hilfe: ein einzelner Datenbankname als sysname mit höchstens 128 Zeichen, ohne Server-/Schemaqualifier oder Liste. Der übergebene Name wird als Datenwert mit QUOTENAME verwendet; Bezeichnerklammern sind keine automatisch entfernte Eingabemaskierung. Normalaufrufe benötigen einen nicht-NULL, nicht nur aus Leerzeichen bestehenden Namen eines separat installierten, erreichbaren, online befindlichen und schreibbaren SC-023-Ziels. Bei neuen Collectoroptionen werden Systemdatenbanken, Frameworkselbstziel und eine nicht passende Zielidentität abgewiesen; Datenbank-ID und Erstellungszeitpunkt werden vor dem Write gebunden. Es wird keine Datenbank angelegt. |
| `@IsEnabled` | `bit` | `1` | bit-Schalter für die gemeinsame Framework-Zielkonfiguration: 0 deaktiviert sie, 1 aktiviert sie. NULL ist in der gemeinsamen Aktualisierung ungültig. Bei @UpdateSharedPolicy=0 bleibt dieser gemeinsam gespeicherte Wert unberührt und wird nicht wirksam verwendet; bei Collector-only-Konfiguration gilt die bestehende Bindung. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an. |
| `@SchedulerType` | `varchar(16)` | `'EXTERNAL'` | Ein Code: MANUAL kennzeichnet manuellen Aufruf, EXTERNAL einen externen Scheduler und SQL_AGENT einen SQL-Server-Agent-Aufruf. Äußere Leerzeichen werden entfernt und Großschreibung normalisiert. NULL wird zu leer normalisiert; bei gemeinsamer Aktualisierung sind leere oder unbekannte Codes ungültig. Bei UpdateSharedPolicy=0 wird der Wert nicht geprüft oder geschrieben. Es werden weder Schedulerobjekte noch Agent-Jobs erzeugt oder gestartet. |
| `@CollectionIntervalSeconds` | `smallint` | `30` | Ganzzahlige Sekunden von 1 bis 3600 für die ausgewählte Collectorpolicy. Der Wert wird auch bei UpdateSharedPolicy=0 geschrieben; er ist keine gemeinsame Retentionseinstellung. Er speichert den Mindestabstand für spätere Zyklen, startet aber keinen Collector und wartet nicht. NULL ist im neuen Policyvertrag explizit ungültig; der Legacy-Pfad prüft NULL nicht vollständig vor dem Zielwrite. 0 ist nicht unbegrenzt. |
| `@MaxRows` | `int` | `1000` | int, positive ganze Zeilenzahl von 1 bis 100000 je Collection-Grenze. NULL ist im neuen Policyvertrag ungültig, Werte außerhalb des Bereichs ungültig. Gilt für die ausgewählte Collectorpolicy. Bei shared=0 wird diese Collectorgrenze aktualisiert; der Parameter ist wirksam. |
| `@PayloadEnabled` | `bit` | `0` | 0 speichert keine Payloadfreigabe, 1 erlaubt optionale Payloads nach dem Collectorvertrag. Es wird ausschließlich PayloadEnabled der ausgewählten Collectorpolicy geschrieben, auch bei UpdateSharedPolicy=0; dieser Konfigurationsaufruf erfasst keine Payloaddaten. NULL ist im neuen Policyvertrag explizit ungültig und kann im Legacy-Pfad erst am Zielwrite scheitern. T-SQL konvertiert numerische Nichtnullwerte zuvor zu bit 1; verwenden Sie 0 oder 1. |
| `@RawRetentionDays` | `smallint` | `14` | smallint in Tagen, im Bereich 1 bis 3650. NULL und Bereichsverletzung sind ungültig, wenn @UpdateSharedPolicy=1; andernfalls bleibt die gemeinsame Retention erhalten und der übergebene Wert wird ignoriert. Bestimmt die Aufbewahrungsdauer der Rohdaten. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. |
| `@PayloadRetentionDays` | `smallint` | `7` | smallint in Tagen, 1 bis 3650. Bei shared=1 darf der Wert nicht NULL und nicht außerhalb des Bereichs sein; bei shared=0 wird er ignoriert. Bestimmt die Payload-Aufbewahrung. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. |
| `@RollupRetentionDays` | `smallint` | `180` | smallint in Tagen, 1 bis 3650. Bei shared=1 erforderlich und im Bereich; bei shared=0 wirkungslos und die vorhandene gemeinsame Rollup-Retention bleibt bestehen. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. |
| `@SoftBudgetMB` | `int` | `10240` | int in MiB, von 1 bis 2147483647. Bei shared=1 darf der Wert nicht NULL oder kleiner 1 sein. Bei shared=0 wird das gemeinsame Budget nicht geändert und der Wert ignoriert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. |
| `@PurgeIntervalMinutes` | `smallint` | `60` | smallint in Minuten, 1 bis 1440. Bei shared=1 erforderlich und bereichsgeprüft; bei shared=0 bleibt der gemeinsame Purge-Takt unverändert und der Wert wird ignoriert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. |
| `@PurgeBatchRows` | `int` | `10000` | int, Zeilen je Purge-Batch, 1 bis 100000. Bei shared=1 erforderlich und bereichsgeprüft; bei shared=0 wird die gemeinsame Purge-Batchgrenze nicht geändert. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. |
| `@BudgetAction` | `varchar(32)` | `'PURGE_EXPIRED_THEN_STOP'` | varchar(32), nach Trimmen und Großschreibung ausschließlich PURGE_EXPIRED_THEN_STOP. Der Wert bezeichnet das Löschen abgelaufener Daten vor dem Anhalten bei weiterhin überschrittenem Softbudget. NULL oder ein anderer Text ist bei shared=1 ungültig; bei shared=0 ignoriert, da die gemeinsame Budgetpolicy unverändert bleibt. Im Legacy-Pfad wird NULL nicht vollständig vorab geprüft und kann erst beim Zielwrite scheitern; es bedeutet keinen automatischen Default. Dieser Aufruf speichert nur den Aktionscode und führt keinen Purge aus. |
| `@PrintMeldungen` | `bit` | `1` | bit-Ausgabeschalter: 0 unterdrückt die abschließende Severity-10-Statusmeldung bei Fehlern; 1 gibt sie mit RAISERROR ... WITH NOWAIT aus. NULL verhält sich nicht wie 1 und unterdrückt die Bedingung (SQL NULL-Vergleich); beeinflusst weder Status-OUTPUT noch Persistenz. Hilfe-PRINTs werden hiervon nicht gesteuert. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an. |
| `@Hilfe` | `bit` | `0` | 1 druckt die Hilfe und kehrt vor Zielprüfung und persistenten Konfigurationswrites zurück; 0 oder NULL folgt dem normalen Pfad. TargetDatabaseName bleibt als Pflichtargument erforderlich. Der frühe Hilfezweig für neue oder ungültige Collectoroptionen liegt vor der Collector-/Transaktionsvalidierung und vor SET XACT_ABORT/LOCK_TIMEOUT. Der Legacy-Hilfezweig liegt nach SET XACT_ABORT ON und LOCK_TIMEOUT 0. NOCOUNT und die initialisierten Status-OUTPUTs werden bereits zuvor gesetzt. Ein Hilfeaufruf belegt deshalb keine zulässige normale Konfiguration. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an. |
| `@StatusCodeOut` | `varchar(40) OUTPUT` | `NULL` | varchar(40) OUTPUT; als Variable binden und nach dem EXEC auslesen. Liefert den Status dieses Aufrufs, anfänglich AVAILABLE, bei Fehlerpfaden unter anderem INVALID_PARAMETER, TARGET_UNAVAILABLE oder DENIED_PERMISSION. Im Hilfezweig bleibt der initialisierte Wert AVAILABLE. Kein Resultset. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen. |
| `@IsPartialOut` | `bit OUTPUT` | `NULL` | bit OUTPUT; als Variable binden. 0 bedeutet kein als partiell markierter Fehler, 1 kennzeichnet einen Fehler-/Teilstatus. Wird beim Eintritt auf 0 gesetzt und in den Fehlerpfaden typischerweise auf 1; im Hilfezweig bleibt es 0. Kein separates Resultset. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen. |
| `@ErrorNumberOut` | `int OUTPUT` | `NULL` | int OUTPUT; als Variable binden. NULL bedeutet, dass beim initialisierten Status keine Fehlernummer gesetzt ist; Fehlerpfade liefern die ermittelte SQL- oder Vertragsfehlernummer, soweit vorhanden. Wird beim Eintritt auf NULL gesetzt und bei Hilfe nicht geändert. Der Anfangswert wird überschrieben; für Rückgabe die Variable mit OUTPUT übergeben. Ohne Bindung wird kein Wert beim Aufrufer empfangen. |
| `@ErrorMessageOut` | `nvarchar(2048) OUTPUT` | `NULL` | Optionaler nvarchar(2048)-OUTPUT-Empfang für Unicode-Fehlertext mit höchstens 2048 UTF-16-Codeeinheiten. Der Anfangswert wird auf NULL gesetzt. Ohne Fehler kann NULL zurückkommen; eine Meldung allein ersetzt nicht die Statusprüfung. Aufruf als Variable mit OUTPUT, sonst wird beim Aufrufer kein Wert empfangen. |
| `@CollectorCode` | `varchar(64)` | `'PERFORMANCE_COUNTERS'` | Nach Trim und Großschreibung sind genau PERFORMANCE_COUNTERS (Performance-Counter-Policy), WAIT_STATS (Wait-Statistik-Policy) und FILE_IO (Datei-I/O-Policy) zulässig. NULL wird zu leer und ist bei normalem Aufruf ungültig. Für WAIT_STATS erkennt die Admission die Version/Schema-Paare 1.2.1/2, 1.3.0/3 und 1.3.1/3 und fordert dazu Retentionsvertrag 1, 2 beziehungsweise 3 sowie passende Signaturen. Das Versionsetikett allein reicht nicht: der aktuelle Purge-Helfer liefert bei 1.3.0/3 Vertrag 3 statt 2; diese Kombination wird abgewiesen. Eine funktionsfähige historische 1.3.0-Closure wird hier nicht qualifiziert. FILE_IO verlangt 1.3.1/3 mit Retentionsvertrag 3. PERFORMANCE_COUNTERS mit CollectorEnabled=1 und wirksamem UpdateSharedPolicy=1 nimmt den Legacy-Pfad; andere Performance-Counter-Kombinationen benötigen ebenfalls die neue Admission. Die Auswahl startet keine Sammlung. |
| `@CollectorEnabled` | `bit` | `1` | bit-Schalter: 0 deaktiviert, 1 aktiviert ausschließlich den ausgewählten Collector. NULL ist ungültig. Kombinationen mit CollectorCode und UpdateSharedPolicy bestimmen den neuen Policyvertrag; ein deaktivierter Collector erzwingt diesen Vertrag. Der Wert aktiviert weder Datenbank noch Job. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an. |
| `@UpdateSharedPolicy` | `bit` | `NULL` | 0 erhält Framework-Singleton und gemeinsame Retention/Budget/Purgewerte sowie die bisherige Retentionszuordnung. CollectorEnabled, CollectionIntervalSeconds, MaxRows und PayloadEnabled der gewählten Policy werden trotzdem geschrieben. IsEnabled, SchedulerType und gemeinsame Retentions-/Budget-/Purgeargumente werden bei 0 ignoriert. 1 ändert gemeinsame Werte und gewählte Policy atomar. NULL löst vor der Hilfe zu 1 für PERFORMANCE_COUNTERS, sonst zu 0 für WAIT_STATS oder FILE_IO auf. Neue Varianten mit 0 benötigen eine bereits passende Framework-Zielbindung. Der normale neue Vertrag weist Callertransaktionen und IMPLICIT_TRANSACTIONS ON zurück; der Legacy-Pfad hat keine entsprechende Vorabablehnung und sollte ebenfalls außerhalb eigener Transaktionen aufgerufen werden. Numerische Nichtnullwerte werden durch T-SQL vor dem Aufruf zu bit 1 konvertiert; geben Sie ausdrücklich 0 oder 1 an. |

## Aufrufbeispiele

Die vier folgenden Hilfeaufrufe schreiben keine Zielkonfiguration. Sie zeigen die drei Collectorcodes und beide Aktualisierungsarten; der Pflichtname wird nur als synthetisches Argument gebunden. Die Hilfe ist kein Nachweis einer gültigen Zielinstallation.

```sql
EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase',
    @Hilfe=1,
    @CollectorCode='PERFORMANCE_COUNTERS',
    @CollectorEnabled=1,
    @UpdateSharedPolicy=1;
```

```sql
EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase',
    @Hilfe=1,
    @CollectorCode='WAIT_STATS',
    @CollectorEnabled=1,
    @UpdateSharedPolicy=0;
```

```sql
EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase',
    @Hilfe=1,
    @CollectorCode='WAIT_STATS',
    @CollectorEnabled=0,
    @UpdateSharedPolicy=1;
```

```sql
EXEC [monitor].[USP_ConfigureSnapshotTarget] @TargetDatabaseName=N'ExampleSnapshotDatabase',
    @Hilfe=1,
    @CollectorCode='FILE_IO',
    @CollectorEnabled=1,
    @UpdateSharedPolicy=1;
```

## Collectorwahl und gemeinsame Policy

Die drei angehängten Parameter erhalten die bisherigen positionalen Aufrufe:

| Parameter | Bedeutung |
|---|---|
| `@CollectorCode` | `PERFORMANCE_COUNTERS` ist der Default; `WAIT_STATS` oder `FILE_IO` werden ausdrücklich gewählt. |
| `@CollectorEnabled` | Aktiviert oder deaktiviert ausschließlich die ausgewählte Collectorpolicy; Default ist `1`. |
| `@UpdateSharedPolicy` | `NULL` bedeutet `1` für Performance Counter und `0` für Waits und Datei-I/O. Mit `0` bleiben Frameworkzeile, gemeinsame Retention und die bestehende Retentionszuordnung erhalten. Mit `1` werden gemeinsame Werte und ausgewählte Policy atomar aktualisiert. |

Neue normale Collectoroptionen benötigen die vollständige Zielclosure, eine passende Zielidentität und die tatsächlich erwartete Purgesignatur. Die WAIT_STATS-Admission erkennt 1.2.1/Schema 2, 1.3.0/Schema 3 und 1.3.1/Schema 3 und verlangt dazu Retentionsvertrag 1, 2 beziehungsweise 3. Der aktuelle Purge-Helfer liefert beim Versionsetikett 1.3.0/Schema 3 jedoch Vertrag 3; diese gemischte Kombination wird abgewiesen. Daraus folgt keine Qualifikation einer historischen 1.3.0-Closure. FILE_IO verlangt 1.3.1/Schema 3 mit Vertrag 3.

Normale neue Varianten benötigen IMPLICIT_TRANSACTIONS OFF und dürfen keine Callertransaktion besitzen. Bei UpdateSharedPolicy=0 muss die Framework-Zielbindung bereits passen. Gemeinsame neue Änderungen werden über beide Datenbanken in der eigenen Transaktion geschrieben. Der Legacy-Performance-Counter-Pfad besitzt keine entsprechende Vorabablehnung einer Callertransaktion; Konfiguration sollte außerhalb eigener Transaktionen erfolgen. Die frühe Hilfe für neue Optionen liegt vor dieser Prüfung; der Legacy-Hilfezweig setzt zuvor XACT_ABORT ON und LOCK_TIMEOUT 0. Hilfe initialisiert nur die Statuswerte und prüft kein Ziel.

Nach bestehender gemeinsamer Zielkonfiguration aktiviert dieser Aufruf nur Waits:

```sql
EXEC [monitor].[USP_ConfigureSnapshotTarget]
     @TargetDatabaseName = N'ExampleSnapshotDatabase',
     @CollectorCode = 'WAIT_STATS',
     @CollectorEnabled = 1,
     @UpdateSharedPolicy = 0,
     @MaxRows = 1000;
```

## Resultsets und Leserichtung

Die Procedure besitzt kein fachliches Resultset. Lesen Sie `@StatusCodeOut`, `@IsPartialOut`, Fehlernummer und Fehlermeldung als Ergebnis genau dieses Konfigurationsversuchs. Prüfen Sie danach die persistierte Framework-Singletonzeile und die Zielpolicy getrennt. Bei einem normalen Konfigurationsaufruf bezieht sich `AVAILABLE` auf die Konfigurationsänderung, nicht auf einen Collection Cycle. Beide Hilfezweige liefern dagegen die initialisierten Werte AVAILABLE, 0, NULL und NULL ohne Zielprüfung. Ein numerischer SQL-RETURN-Wert allein ersetzt die Status-OUTPUTs nicht.

## Beispiele und Gegenbeispiele

Ein zulässiger Example-Fall verknüpft eine isolierte `ExampleSnapshotDatabase`, setzt `SchedulerType = 'EXTERNAL'` und lässt Payloads deaktiviert. Ein Gegenbeispiel ist die Verwendung der Procedure zur Datenbankerstellung oder Rechtevergabe. Ebenso darf `IsEnabled = 1` nicht als Nachweis eines laufenden Schedulers interpretiert werden.

## Leere oder partielle Ausgabe

Da kein fachliches Resultset existiert, ist eine leere Tabellenausgabe normal. `TARGET_UNAVAILABLE` bezeichnet ein fehlendes, nicht online befindliches, schreibgeschütztes oder vertraglich unpassendes Ziel. `DENIED_PERMISSION` trennt fehlende Rechte. Ein Fehler darf keine halb aktualisierte Framework-/Zielkonfiguration als erfolgreich darstellen.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `LOW` |
| Standardpfad | Validierung einer Zieldatenbank und zweier typisierter Policybereiche |
| Teuerster Pfad | Kurze transaktionale Aktualisierung in Framework- und Zieldatenbank |
| Haupttreiber | Zielerreichbarkeit, Berechtigungen und konkurrierende Konfigurationszugriffe |
| Skalierung | Singletonbeziehung; kein Fleet- oder Mehrzielpfad |
| Ressourcen | Geringe Katalog-I/O und wenige Konfigurationswrites |
| Begrenzungswirkung | Wirksame Werte werden im Ziel geprüft; Legacy-NULL-Werte können erst an Zielconstraints scheitern |
| Locking und Nebenwirkungen | Kurze Schreibtransaktion; keine Datenbank-, Rechte- oder Schedulererstellung |
| Schutzmechanismus | Expliziter Zielname, Zielvertrag und atomare Reihenfolge |
| Sicherer Einsatz | Zuerst deaktiviert mit synthetischem Ziel konfigurieren und gegenprüfen |
| Aussagegrenze | Konfiguration ist keine Collection- oder Betriebsberechtigungsevidenz |

## Eine Zeile bedeutet

Die Procedure besitzt kein fachliches Resultset. OUTPUT-Status beschreibt genau den atomaren Konfigurationsversuch; die persistierte Singletonzeile bezeichnet das aktive lokale Ziel.

## So lesen

Nur nach einem normalen Konfigurationsaufruf bedeutet `AVAILABLE`, dass das Ziel erreichbar war und die benötigten Konfigurationswrites erfolgreich abgeschlossen wurden. Ein Hilfeaufruf trifft diese Aussage nicht. `TARGET_UNAVAILABLE` trennt fehlenden Zielkontext von `DENIED_PERMISSION`. `IsEnabled=0` bewahrt vorhandene Historie und verhindert neue Collection Cycles.

## Warum kann das problematisch sein?

Ein falsches Ziel kann reale Laufzeitwerte in einer unerwarteten Datenbank persistieren. Zu lange Retention, aktivierte Payloads oder ein zu großes Zeilenlimit erhöhen Speicher-, Log- und Purgekosten. Der Installer vergibt deshalb absichtlich keine Rechte und aktiviert keinen Job.

## Wann ist es kein Problem?

Eine deaktivierte Konfiguration ist ein gültiger sicherer Zustand. Dokumentierte Beispiele verwenden ausschließlich eindeutige Platzhalter wie `ExampleSnapshotDatabase`; der reale Zielname verbleibt in der geschützten Betriebsdatenbank.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welches explizite Ziel und welche begrenzte Policy dürfen der schedulerneutrale Collector und der Purge verwenden?

### Technischer Hintergrund

`monitor.SnapshotTargetConfiguration` ist ein typisierter Singleton. Zielseitig bilden `snapshot.CollectorPolicy` und `snapshot.RetentionPolicy` die validierten Optionen ab; ein allgemeiner Key-Value-Speicher ersetzt diese bekannten Felder nicht.

### Datenkette

Framework-Singleton → validierter Drei-Part-Name → `snapshot.InternalConfigureSnapshotPolicy` → typisierte Zielpolicy.

### Source Select

Die bestehende Singleton-Konfiguration wird mit dem sichtbaren Zustand der Zieldatenbank korreliert:

```sql
SELECT
      [c].[TargetDatabaseName]
    , [c].[IsEnabled]
    , [c].[DefaultSchedulerType]
    , [d].[state_desc]
    , [d].[is_read_only]
FROM [monitor].[SnapshotTargetConfiguration] AS [c] WITH (NOLOCK)
LEFT JOIN [master].[sys].[databases] AS [d] WITH (NOLOCK)
  ON [d].[name] = [c].[TargetDatabaseName]
WHERE [c].[ConfigurationId] = 1;
```

**Wichtig für die Eigenlast:** Das Lesen ist trivial. Die Procedure ist jedoch ein Konfigurations-Schreibpfad: Mit `@UpdateSharedPolicy=1` validiert sie genau eine Zieldatenbank und aktualisiert zuerst deren Policy und danach die Frameworkzeile innerhalb ihrer eigenen Transaktion. Mit `0` ändert sie nur die gewählte Collectorpolicy.

### Zeit- und Scope-Modell

`LastUpdatedUtc` ist UTC. Die Konfiguration gilt für genau die lokale Framework-/Snapshot-Datenbankbeziehung; Fleet-Transport gehört nicht zu SC-023.

### Bewertung und Gegenprobe

Prüfen Sie nach dem Aufruf Zielname, Aktivierungsstatus und Policy in beiden Datenbanken. Starten Sie danach einen manuellen Cycle mit einem begrenzten Zeilenlimit.

### Typische Fehlinterpretation

`AVAILABLE` beweist nicht, dass der Ausführer später alle DMV- und Zielschreibrechte besitzt. Konfiguration und Collection haben getrennte Rechte- und Statuspfade.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: `USP_RunSnapshotCollectionCycle`, `USP_PurgeSnapshotData` und der Betriebsleitfaden.

## Primärquellen

- [Transactions](https://learn.microsoft.com/en-us/sql/t-sql/language-elements/transactions-transact-sql?view=sql-server-ver17)
- [sys.databases](https://learn.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql?view=sql-server-ver17)

[Technische Detailbeschreibung](../../Operations/Snapshot_Baseline_Operations.md)
