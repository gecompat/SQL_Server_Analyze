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

[Technische Detailbeschreibung](../07_Infrastructure.md#6-monitorusp_logshippingstatus)
