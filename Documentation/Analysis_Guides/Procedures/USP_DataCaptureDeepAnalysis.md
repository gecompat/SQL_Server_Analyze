# [monitor].[USP_DataCaptureDeepAnalysis]

**Bereich:** Versionsadaptive Spezialanalysen
**Zweck:** Bewertet Change-Tracking-Versionen, CDC-Capture/Cleanup und lokal erreichbare Replikationsmetadaten, ohne Nutzdaten, Change-Zeilen, Replikationsbefehle oder Konfiguration zu verändern.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_DataCaptureDeepAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @ResultSetArt = 'CONSOLE';
```

Einen Change-Tracking-Consumer nur mit seinem echten, zuletzt bestätigten Wasserstand prüfen:

```sql
EXEC [monitor].[USP_DataCaptureDeepAnalysis]
      @DatabaseNames = N'[ExampleDatabase]',
      @ChangeTrackingClientVersion = 100,
      @ResultSetArt = 'RAW';
```

Der Zahlenwert ist synthetisch. Der Parameter ist datenbankspezifisch und erzwingt genau eine ausgewählte Datenbank. Wasserstände verschiedener Consumer dürfen fachlich nicht vermischt werden.

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einem Datenbankstatus, isolierten Quellenstatus, Finding, einer Change-Tracking-Tabelle, CDC-Capture-Instanz, CDC-Scan-Sitzung, aggregierten CDC-Fehlergruppe, CDC-Jobkonfiguration, lokal sichtbaren Replikationsagenten oder aggregierten Replikationsfehlergruppe.

## So lesen

Zuerst `StatusCode`, `IsPartial` und `SourceStatus` prüfen. Danach die drei Funktionsfamilien getrennt lesen:

- Change Tracking: `ClientVersion` pro Consumer gegen `MinValidVersion` und `CurrentVersion`.
- CDC: Capture-Instanzen, Jobs, aggregierte Scan-Latenz und Fehler gemeinsam.
- Replikation: Agentstatus, lokaler Rückstand, Latenz und Fehler im selben Zeitfenster.

`REPLICATION_TOPOLOGY_NOT_LOCALLY_OBSERVABLE` ist eine Evidenzlücke. Sie darf nie als gesunder Replikationszustand interpretiert werden.

## Warum kann das problematisch sein?

Ein CT-Wasserstand unter `MinValidVersion` kann nicht mehr vollständig inkrementell enumeriert werden. Fehlende oder deaktivierte CDC-Jobs, wiederholte Scanfehler oder anhaltende Capture-Latenz können die Datenbereitstellung verzögern. Hohe undistributed-command-Zahlen, Retry/Fail-Agentstatus und lokale Replikationsfehler können auf einen Zustellrückstand hinweisen.

## Wann ist es kein Problem?

Ohne echten CT-Consumer-Wasserstand ist kein Synchronisationsverlust beweisbar. CDC mit nicht kontinuierlichem Capture kann zwischen geplanten Läufen erwartbar hohe Latenz zeigen. Ein Replikationsagent im Zustand `Idle` ist ohne Rückstand kein Fehler. Einzelne DMV- oder History-Zeilen sind keine lückenlose Zeitreihe.

## Leere oder partielle Ausgabe

Eine leere CDC-Scan-DMV kann nach Neustart/Failover oder auf einer AG-Sekundärreplik auftreten. Alle in `msdb` sichtbaren lokalen Distributionsdatenbanken werden getrennt gelesen und in Agent- und Fehlerzeilen ausgewiesen; lokale Distributionstabellen zeigen dennoch keinen Remote Distributor. Fehlende Rechte werden pro Quelle als `AVAILABLE_LIMITED` erhalten; zugängliche andere Evidenz bleibt gültig.

## Eigenlast und Datenschutzgrenze

MEDIUM: sichtbare Kataloge, kleine CDC-DMVs, msdb-Jobmetadaten und aggregierte lokale Distributionstabellen. Das Modul liest keine `CHANGETABLE`-Ergebnisse, CDC-Change-Table-Zeilen, Replikationscommands, Kommentare, Fehlertexte, LSNs, Credentials oder Agentjob-Commands. Runtime-Namen bleiben für die Diagnose vollständig sichtbar, dürfen aber nicht in Repository- oder Downloadartefakte übernommen werden.

[Technische Detailbeschreibung](../09_Version_Adaptive.md#7-monitorusp_datacapturedeepanalysis)
