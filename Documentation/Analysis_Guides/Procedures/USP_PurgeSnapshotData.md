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

## Parameter und Eingabeformen

Die Hilfe folgt auf SET LOCK_TIMEOUT 0, Temp-Tabellenanlage und OUTPUT-Initialisierung; sie beendet vor Zielprüfung und Purge. AVAILABLE/0 bei Hilfe bestätigt keinen Löschlauf. Der normale Aufruf kann abgelaufene Daten im optionalen Snapshotziel löschen. Er besitzt kein allgemeines vorgeschaltetes Callertransaktionsgate; verwenden Sie für den schreibenden Purge einen separaten Aufruf ohne Callertransaktion.

Ausgelassene Argumente verwenden den jeweils bezeichneten Default. Die Beschreibung nennt die tatsächliche Behandlung von NULL; leere Zeichenfolgen sind für Zahlen und bit keine eigene Eingabesyntax und können bereits bei SQL-Typkonvertierung verändert werden. OUTPUT-Werte werden nur bei Bindung einer passenden Variable mit OUTPUT am Aufruf empfangen.

### @MaxBatches

**Datentyp:** `int`. Ganzzahl von 1 bis 1000 einschließlich; Obergrenze der Child-first-Schleifendurchläufe, keine globale Zeilenzahl. Je Durchlauf erfolgen begrenzte Deletes für MetricSample, PayloadSnapshot, ModuleStatus, CaptureRun und verwaiste Nicht-Server-Scopes; PurgeBatchRows begrenzt jedes Delete. Ein Durchlauf ohne Deletes beendet früher. NULL oder Werte außerhalb 1 bis 1000 sind ungültig. Default: 10.

### @Force

**Datentyp:** `bit`. 0 beachtet Purgeintervall; 1 umgeht nur dieses Intervall. Nicht abgelaufene Daten bleiben geschützt. NULL ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @ResultSetArt

**Datentyp:** `varchar(16)`. CONSOLE zeigt die priorisierte Purge-Laufzusammenfassung; RAW liefert die technische purge-Zeile; TABLE schreibt diese Zeile in das gemappte lokale Temp-Ziel; JSON stellt den JSON-Vertrag im @Json-OUTPUT bereit; NONE unterdrückt reguläre Resultsets. Zulässige Werte ausschließlich CONSOLE, RAW, TABLE, JSON, NONE. Außen getrimmt, Groß-/Kleinschreibung ignoriert; NULL/leer ungültig. Default: 'CONSOLE'.

### @ResultTablesJson

**Datentyp:** `nvarchar(max)`. Nur TABLE: JSON-Objekt mit genau dem Schlüssel purge und einem Textwert als lokalem Temp-Tabellennamen, etwa N'{"purge":"#MyPurge"}'. Die Zieltabelle muss in derselben Sitzung vorhanden, leer und mit genau einer Seed-Spalte angelegt sein; der Writer passt sie an das Ergebnis an. Leeres Objekt, unbekannte oder doppelte Schlüssel, Nicht-Textwerte, ##- oder permanente Tabellen, Namen über 116 Zeichen sowie das reservierte Präfix #Monitor (ohne Beachtung der Großschreibung) sind unzulässig. Der Schlüssel purge ist case-sensitive. Bei TABLE sind NULL/leer/Leerzeichen ungültig; außerhalb TABLE sind sie zulässig, nichtleere Werte ungültig. Default: NULL.

### @JsonErzeugen

**Datentyp:** `bit`. 0 erzeugt JSON nur bei ResultSetArt JSON; 1 befüllt JSON-OUTPUT zusätzlich zu anderer Ausgabeart. NULL ungültig. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Json

**Datentyp:** `nvarchar(max) OUTPUT`. nvarchar(max)-Variable mit OUTPUT; am Eintritt NULL. Bei JsonErzeugen=1 oder Ausgabeart JSON enthält das Objekt meta (contractVersion 1, resultName SnapshotPurge) und purge als Objekt, jeweils mit enthaltenen NULL-Werten. Bei Hilfe bleibt NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @PrintMeldungen

**Datentyp:** `bit`. 1 gibt am Ende für Statuswerte außer AVAILABLE, AVAILABLE_LIMITED und SKIPPED_NOT_DUE RAISERROR severity 10 mit NOWAIT aus; 0 unterdrückt. NULL wird nicht validiert und löst die IF-Ausgabe nicht aus. Default: 1. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @Hilfe

**Datentyp:** `bit`. 1 druckt Hilfe und kehrt mit RETURN zurück; 0 normaler Ablauf. NULL wird nicht als 1 behandelt. OUTPUTs werden zuvor initialisiert. Default: 0. Die SQL-bit-Konvertierung bildet numerische Werte ungleich 0 auf 1 ab.

### @PurgeRunIdOut

**Datentyp:** `bigint OUTPUT`. bigint-Variable mit OUTPUT; initial NULL, enthält PurgeRun-ID falls vorhanden. Bei Hilfe NULL. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @StatusCodeOut

**Datentyp:** `varchar(40) OUTPUT`. varchar(40)-Variable mit OUTPUT; initial AVAILABLE, danach tatsächlicher Status. Bei Hilfe AVAILABLE. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @IsPartialOut

**Datentyp:** `bit OUTPUT`. bit-Variable mit OUTPUT; initial 0, danach gemäß Fehler-/Laufpfad. Bei Hilfe 0. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @ErrorNumberOut

**Datentyp:** `int OUTPUT`. int-Variable mit OUTPUT; initial NULL, bei Fehler gegebenenfalls Fehlernummer. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

### @ErrorMessageOut

**Datentyp:** `nvarchar(2048) OUTPUT`. OUTPUT-Parameter nvarchar(2048), mit nvarchar(2048)-Variable und OUTPUT zu binden; Kapazität entspricht 2048 UTF-16-Codeeinheiten. Initial NULL, bei Fehler gegebenenfalls Meldung. Default: NULL OUTPUT. Zum Empfang ist OUTPUT auch am Aufruf erforderlich; ein übergebener Eingangswert wird initial überschrieben.

## Hilfe ohne fachliche Writes

Die vier folgenden Aufrufe enden im Hilfezweig. Sie starten keine Collection und keinen Purge; die Hilfepfade können lokale Temp-Tabellen anlegen.

```sql
EXEC [monitor].[USP_PurgeSnapshotData] @Hilfe=1;
EXEC [monitor].[USP_PurgeSnapshotData] @Hilfe=1, @MaxBatches=1;
EXEC [monitor].[USP_PurgeSnapshotData] @Hilfe=1, @Force=1;
EXEC [monitor].[USP_PurgeSnapshotData] @Hilfe=1, @ResultSetArt='RAW';
```

## Resultsets und Leserichtung

CONSOLE priorisiert das benannte Resultset `purge`. RAW, TABLE und JSON verwenden dieselbe technische Laufzusammenfassung. Lesen Sie Status, Batchzahl, gelöschte Zeilen je Objektklasse, Budgetstatus und Fehlergrenze gemeinsam. `AVAILABLE_LIMITED` kann einen erfolgreichen, aber durch `@MaxBatches` begrenzten Fortschritt bezeichnen.

Die fünf lokalen Textspalten einschließlich der TABLE-Zuordnung verwenden
`SQL_Latin1_General_CP1_CS_AS`. Die drei Textspalten von `purge` behalten
die Frameworkcollation auch bei abweichender `tempdb`-Collation. Ablauf-
und Budgetgrenzen sowie bestehende persistente Zieltabellen bleiben erhalten.

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

Die letzte finalisierte WAIT_STATS-CaptureRun-Zeile bleibt unabhängig von
Status und Kindern erhalten, bis ein neuerer Wait-Lauf finalisiert ist.
Ein neuerer Performance-Counter-Lauf oder ein unfinalisierter Wait-Lauf hebt
diesen Schutz nicht auf. MetricSamples, Payloads und Modulstatus dieser
Grenzzeile verfallen regulär; ein erhaltener Run ist keine vollständige
Vergleichsbasis. Für FILE_IO bleibt dagegen die letzte CaptureRun-Zeile auch ohne bestätigte Finalisierung erhalten, bis eine neuere Datei-I/O-Capture-ID vorliegt. Ihre abgelaufenen Kinddaten bleiben regulär löschbar. Diese Retentionsvorbereitung installiert oder aktiviert
keinen Wait-Collector und verändert die Performance-Counter-Retention nicht.


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
