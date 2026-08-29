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
     @IsEnabled = 1,
     @SchedulerType = 'EXTERNAL',
     @PayloadEnabled = 0;
```

## Resultsets und Leserichtung

Die Procedure besitzt kein fachliches Resultset. Lesen Sie `@StatusCodeOut`, `@IsPartialOut`, Fehlernummer und Fehlermeldung als Ergebnis genau dieses Konfigurationsversuchs. Prüfen Sie danach die persistierte Framework-Singletonzeile und die Zielpolicy getrennt. Ein `AVAILABLE`-Status bezieht sich auf die atomare Konfigurationsänderung, nicht auf einen Collection Cycle.

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
| Begrenzungswirkung | Typisierte Grenzwerte werden vor dem Schreiben validiert |
| Locking und Nebenwirkungen | Kurze Schreibtransaktion; keine Datenbank-, Rechte- oder Schedulererstellung |
| Schutzmechanismus | Expliziter Zielname, Zielvertrag und atomare Reihenfolge |
| Sicherer Einsatz | Zuerst deaktiviert mit synthetischem Ziel konfigurieren und gegenprüfen |
| Aussagegrenze | Konfiguration ist keine Collection- oder Betriebsberechtigungsevidenz |

## Eine Zeile bedeutet

Die Procedure besitzt kein fachliches Resultset. OUTPUT-Status beschreibt genau den atomaren Konfigurationsversuch; die persistierte Singletonzeile bezeichnet das aktive lokale Ziel.

## So lesen

`AVAILABLE` bedeutet, dass die Ziel-Datenbank online, schreibbar und mit dem erwarteten internen Konfigurationsobjekt erreichbar war. `TARGET_UNAVAILABLE` trennt fehlenden Zielkontext von `DENIED_PERMISSION`. `IsEnabled=0` bewahrt vorhandene Historie und verhindert neue Collection Cycles.

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

**Wichtig für die Eigenlast:** Das Lesen ist trivial. Die Procedure ist jedoch ein Konfigurations-Schreibpfad: Sie validiert genau eine Zieldatenbank, aktualisiert zuerst deren Snapshotpolicy und danach die Framework-Singletonzeile in einer Transaktion.

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
