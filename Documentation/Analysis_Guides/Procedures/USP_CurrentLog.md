# [monitor].[USP_CurrentLog]

**Bereich:** Current State  
**Zweck:** Zeigt Logauslastung, Wiederverwendungswartegrund, VLF- und optional PVS-Kontext.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentLog]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Datenbank, eine Logdatei, einen VLF- oder PVS-Aspekt. Den jeweiligen Scope vor Summenbildung prüfen.

## So lesen

Used Percent, absolute Loggröße, `log_reuse_wait_desc`, Growth, VLF und offene Transaktionen gemeinsam lesen.

## Warum kann das problematisch sein?

Hohe Nutzung ist besonders kritisch, wenn Wiederverwendung durch eine alte Transaktion, fehlende Logbackups oder HA-/Replikations-Lag blockiert wird. Reines Vergrößern behebt die Ursache nicht.

## Wann ist es kein Problem?

Hohe Nutzung während eines geplanten Batches kann akzeptabel sein, wenn Kapazität, Backupfolge und anschließende Wiederverwendung gesichert sind.

## Beispiel und Folgeschritt

95 % genutzt plus `ACTIVE_TRANSACTION` plus zwei Stunden alte Transaktion: Primärursache ist die offene Transaktion. `USP_CurrentTransactions`, Backupstatus und Kapazität prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie voll ist das Transaktionslog, warum kann es nicht wiederverwendet werden und welches Risiko entsteht?

### Technischer Hintergrund

Das Log ist eine sequenzielle Recoverystruktur aus VLFs. Log Records müssen für Commit gehärtet und für Recovery/Backup/HADR/Replication je nach Konfiguration erhalten werden. Space-Usage, Filemetadaten, VLF-Kontext und `log_reuse_wait_desc` erklären verschiedene Ebenen.

### Datenkette

`master.sys.databases`, `sys.dm_db_log_info`, `sys.dm_db_log_space_usage`, `sys.dm_db_log_stats`, `sys.dm_tran_persistent_version_store_stats`, `sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Space-/Reusezustand; Filegröße und VLFs Metadaten, einzelne Zähler kumulativ. Reuse-Wait kann sich nach Backup/Commit rasch ändern.

### Bewertung und Gegenprobe

Used Percent, absolute freie MB, Wachstumsoption, Volumeplatz und Reuse-Wait zusammen lesen. `ACTIVE_TRANSACTION`, `LOG_BACKUP`, `AVAILABILITY_REPLICA` oder `REPLICATION` führen zu unterschiedlichen Maßnahmen.

### Typische Fehlinterpretation

Logvergrößerung beseitigt die Reuse-Ursache nicht. Shrink ist keine dauerhafte Lösung und kann VLF-/Autogrowthprobleme verschärfen.

### Folgeanalyse

`USP_CurrentTransactions`, Backup-/AG-/Replicationmodule, `USP_CurrentIO` für Logfilelatenz.

[Technische Detailbeschreibung](../02_Current_State.md#9-monitorusp_currentlog)
