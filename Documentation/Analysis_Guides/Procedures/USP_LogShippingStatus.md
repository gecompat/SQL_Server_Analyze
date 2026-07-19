# [monitor].[USP_LogShippingStatus]

**Bereich:** Infrastruktur  
**Zweck:** Zeigt Backup-, Copy- und Restorefortschritt von Log Shipping.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_LogShippingStatus]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Primary-/Secondary-Konfiguration, Datenbankbeziehung oder Überwachungszeile.

## So lesen

Zeit des letzten Backups, Kopierens und Restores, Schwellenstatus, Restore Delay und Metadatenverfügbarkeit vergleichen.

## Warum kann das problematisch sein?

Eine wachsende Differenz zeigt, ob Backup-, Transport- oder Restorephase zurückfällt.

## Wann ist es kein Problem?

Ein geplanter Restore Delay erzeugt absichtlich Verzögerung.

## Beispiel und Folgeschritt

Backups aktuell, Copy 90 Minuten zurück, Restore ebenfalls zurück: Transportpfad wahrscheinlicher als Backupjob. Jobhistorie, Netzwerk, Share und Secondary prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Erzeugen, kopieren und restaurieren die Log-Shipping-Jobs Backups innerhalb der konfigurierten Schwellen?

### Technischer Hintergrund

Log Shipping besteht aus Backupjob auf Primary, Copy-/Restorejobs auf Secondary und optional Monitorserver. Monitor-/Primary-/Secondarytabellen halten letzte Datei-/Zeit-/Schwellenwerte. Jede Stufe kann unabhängig zurückliegen.

### Datenkette

`msdb.dbo.log_shipping_monitor_primary`, `msdb.dbo.log_shipping_monitor_secondary`, `msdb.dbo.log_shipping_primary_databases`, `msdb.dbo.log_shipping_secondary_databases`.

### Zeit- und Scope-Modell

Monitor-Metadaten mit eigener Aktualisierungszeit plus Jobhistory. Clock Skew und stale Monitor beeinflussen Interpretation.

### Bewertung und Gegenprobe

Backup-, Copy- und Restorelatenz getrennt lesen; letzte Dateinamen/Zeiten, Threshold, Alertstatus, Jobzustand und Monitoraktualität korrelieren. Restore Mode/Delay kann absichtlich verzögern.

### Typische Fehlinterpretation

Ein grüner Monitor kann stale sein. Eine alte Restorezeit ist bei konfiguriertem Delay nicht automatisch Fehler. Dateinamen allein beweisen keine lückenlose LSN-Kette.

### Folgeanalyse

Agent Jobs, Backup Chain und Secondary-/Shareprüfung.

[Technische Detailbeschreibung](../07_Infrastructure.md#6-monitorusp_logshippingstatus)
