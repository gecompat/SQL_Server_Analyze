# [monitor].[USP_PurgeSnapshotData]

**Bereich:** Optionales Snapshot-/Baseline-Paket SC-023
**Zweck:** Entfernt ausschließlich abgelaufene Snapshotdaten in begrenzten Child-first-Batches.
**Beobachtungsart:** expliziter begrenzter Retention-Schreibvorgang
**Kostenklasse:** MEDIUM bis HIGH_OPT_IN

## Entscheidungsfrage und Einsatz

Die Procedure wird eingesetzt, wenn die aktive Retentionpolicy abgelaufene Snapshotdaten in kontrollierten Batches entfernen soll. Sie bewahrt referenzielle Reihenfolgen durch Child-first-Löschungen und protokolliert technische Summen. Der Purge ist kein Deinstallationspfad und entfernt weder die Snapshotdatenbank noch frische Evidenz allein wegen eines Softbudgets.

## Nicht beantwortete Fragen

Ein erfolgreicher Purge beweist keine physische Dateiverkleinerung und keine angemessene fachliche Retention. Die Procedure entscheidet nicht über Compliance, Backup oder Recovery der Snapshotdatenbank. Ein weiterhin überschrittenes Softbudget kann durch geschützte, noch nicht abgelaufene Evidenz verursacht sein und ist keine Berechtigung für Shrink oder zusätzliche Löschungen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_PurgeSnapshotData]
     @MaxBatches = 10,
     @Force = 0,
     @ResultSetArt = 'CONSOLE';
```

## Resultsets und Leserichtung

CONSOLE priorisiert das benannte Resultset `purge`. RAW, TABLE und JSON verwenden dieselbe technische Laufzusammenfassung. Lesen Sie Status, Batchzahl, gelöschte Zeilen je Objektklasse, Budgetstatus und Fehlergrenze gemeinsam. `AVAILABLE_LIMITED` kann einen erfolgreichen, aber durch `@MaxBatches` begrenzten Fortschritt bezeichnen.

## Beispiele und Gegenbeispiele

Ein geeigneter Example-Test erzeugt alte und neue synthetische CaptureRuns, führt einen kleinen Purgebatch aus und weist nach, dass der neue Run erhalten bleibt. Ein Gegenbeispiel ist die Erwartung, dass ein logischer Delete die MDF-Datei sofort verkleinert. Ebenso darf `@Force = 1` nicht als Erlaubnis verstanden werden, nicht abgelaufene Daten zu entfernen.

## Leere oder partielle Ausgabe

`SKIPPED_NOT_DUE` und null gelöschte Zeilen sind zulässig. Sie bedeuten nicht, dass kein Budgetrisiko besteht. Wird das Batchlimit erreicht, bleiben weitere abgelaufene Zeilen für den nächsten Lauf erhalten. Fehler in einer Child-first-Stufe müssen den Lauf partiell oder fehlgeschlagen kennzeichnen; Summen dürfen nur tatsächlich abgeschlossene Deletes enthalten.

## Eigenlast und Grenzen

| Dimension | Einordnung |
|---|---|
| Kostenklasse | `MEDIUM` bis `HIGH_OPT_IN` |
| Standardpfad | Fälligkeitsprüfung und begrenzte Child-first-Deletes |
| Teuerster Pfad | Viele Batches bei großem Retentionrückstand |
| Haupttreiber | Abgelaufene Zeilen, Batchgröße, Logdurchsatz und Indizes |
| Skalierung | Linear mit abgearbeiteten Batches innerhalb des Aufruflimits |
| Ressourcen | Transaktionslog, Ziel-I/O, CPU und kurzzeitige Locks |
| Begrenzungswirkung | `@MaxBatches` und Policy-Batchgröße begrenzen den Aufruf |
| Locking und Nebenwirkungen | Explizite Deletes im lokalen Snapshotziel |
| Schutzmechanismus | Ablaufgrenzen, Child-first-Reihenfolge und frische Evidenzgrenze |
| Sicherer Einsatz | Kleine Batchzahl, synthetische Gegenprobe und Logbeobachtung |
| Aussagegrenze | Logisches Purge ist kein Shrink-, Backup- oder Retentionsurteil |

## Eine Zeile bedeutet

Eine `purge`-Zeile beschreibt einen technischen Löschlauf: Batches, gelöschte Zeilenzahlen, Größenbezug, Budgetstatus und Fehlergrenze. Sie enthält keine Kopie gelöschter Payloads.

## So lesen

`AVAILABLE_LIMITED` bedeutet, dass das Batchbudget vor vollständigem Abarbeiten erreicht wurde; der nächste Lauf setzt fort. `BudgetExceeded=1` kann trotz erfolgreichem Löschen bestehen, weil nicht abgelaufene Evidenz geschützt bleibt.

## Warum kann das problematisch sein?

Unbegrenzte Deletes erhöhen Log, Locks und Wiederherstellungszeit. Ein Löschverfahren, das beim Größenlimit auch frische Daten entfernt, würde die interpretierbare Baseline ohne ausdrückliche Entscheidung zerstören.

## Wann ist es kein Problem?

`SKIPPED_NOT_DUE` ist bei noch nicht erreichtem Purgeintervall normal. Null gelöschte Zeilen sind korrekt, wenn keine Evidenz abgelaufen ist; sie beweisen nicht, dass die Datenbank unter dem Softbudget liegt.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wurden nur abgelaufene Daten in kontrollierter Menge entfernt, ohne frische Evidenz oder Historie bei Deinstallation anzutasten?

### Technischer Hintergrund

Der Purge löscht MetricSample und PayloadSnapshot zuerst, anschließend ModuleStatus, leere CaptureRuns und verwaiste Nicht-Server-Scopes. Jede Schleife besitzt eine konfigurierte Zeilen- und eine aufrufbezogene Batchgrenze.

### Datenkette

RetentionPolicy → Ablaufgrenzen → child-first Deletes → PurgeRun-Summen → erneute Größenbewertung.

### Source Select

Der Purge liest zuerst die aktive Retentionpolicy im Ziel und leitet daraus die Ablaufgrenzen für die Child-Tabellen ab:

```sql
SELECT
      [p].[RetentionPolicyCode]
    , [p].[RawRetentionDays]
    , [p].[PayloadRetentionDays]
    , [p].[RollupRetentionDays]
    , [p].[PurgeBatchRows]
    , [p].[SoftBudgetMB]
FROM [ExampleSnapshotDatabase].[snapshot].[RetentionPolicy] AS [p] WITH (NOLOCK)
WHERE [p].[IsFrameworkDefault] = 1;
```

**Wichtig für die Eigenlast:** Der eigentliche Pfad ist schreibend: abhängige Payload-, Metric-, Module- und Runzeilen werden child-first in kleinen Batches gelöscht. Ablaufzeit und Batchgröße begrenzen Log, Locks und Laufzeit; `@MaxBatches` ist der operative Schutz. `ExampleSnapshotDatabase` ist synthetisch.

### Zeit- und Scope-Modell

Ablaufgrenzen werden aus `SYSUTCDATETIME()` berechnet. Raw- und Payloadretention sind getrennt; Rollupretention ist bereits reserviert, Rollups gehören aber nicht zum ersten Slice.

### Bewertung und Gegenprobe

Vergleichen Sie vor und nach dem Lauf nur technische Summen und weisen Sie stichprobenartig nach, dass ein neuer synthetischer Run bestehen blieb. Die Datenbankdateigröße kann trotz logischer Löschung allokiert bleiben.

### Typische Fehlinterpretation

Ein erfolgreiches Purge schrumpft keine Datei und ist kein Auftrag zu `DBCC SHRINK*`. Softbudget und physische Dateigröße sind unterschiedliche Betriebsgrößen.

### Folgeanalyse

Für die weitere Analyse gelten folgende Schritte und Quellen: RetentionPolicy, CaptureRun-Status, Datenbankkapazität und Backup-/Recoveryplanung der Snapshot-Datenbank.

## Primärquellen

- [DELETE](https://learn.microsoft.com/en-us/sql/t-sql/statements/delete-transact-sql?view=sql-server-ver17)
- [Transaction locking and row versioning guide](https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide?view=sql-server-ver17)

[Technische Detailbeschreibung](../../Operations/Snapshot_Baseline_Operations.md)
