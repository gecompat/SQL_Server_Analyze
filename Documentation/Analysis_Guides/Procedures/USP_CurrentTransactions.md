# [monitor].[USP_CurrentTransactions]

**Bereich:** Current State  
**Zweck:** Zeigt offene Transaktionen, Alter, Sessionzustand, Logverbrauch und SQL-Kontext.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CurrentTransactions]
      @MinAlterSekunden = 60,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Zeile beschreibt die Zuordnung einer sichtbaren Transaktion zu Session- und Datenbankkontext. Mehrere technische Transaktionszeilen können zu einer Session gehören.

## So lesen

Transaktionsalter, Sessionstatus, `OpenTransactionCount`, Logbytes, Blocking und SQL-Kontext gemeinsam lesen.

## Warum kann das problematisch sein?

Eine alte Transaktion kann Locks halten, Log-Wiederverwendung verhindern und bei Rollback lange benötigen. `sleeping` erhöht den Verdacht auf fehlendes Commit/Rollback.

## Wann ist es kein Problem?

Geplante Batchloads oder Wartung dürfen lange Transaktionen besitzen, sofern Fortschritt, Logkapazität und Blocking kontrolliert sind.

## Beispiel und Folgeschritt

Sleeping seit 30 Minuten, offene Transaktion, wachsender Logverbrauch und mehrere Blockierte: starke Evidenz für einen nicht abgeschlossenen Anwendungspfad. Blocking, Log und Anwendungstransaktion prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche offenen Transaktionen halten Zustand, Locks oder Lograum länger als erwartet?

### Technischer Hintergrund

Transaktions-DMVs verbinden Datenbank-/Sessiontransaktionen mit Beginn, Zustand, Logbytes und Session/Request. Commit oder Rollback beendet die logische Transaktion; bis dahin können Locks und die für Recovery benötigte Logkette erhalten bleiben. Eine alte aktive Transaktion kann Logtruncation verhindern.

### Datenkette

`master.sys.databases`, `sys.dm_exec_requests`, `sys.dm_exec_sessions`, `sys.dm_exec_sql_text`, `sys.dm_tran_active_transactions`, `sys.dm_tran_database_transactions`, `sys.dm_tran_session_transactions`.

### Zeit- und Scope-Modell

Aktueller offener Zustand; Alter seit Transaktionsbeginn. Logbytes und Locks können während der Abfrage weiter wachsen.

### Bewertung und Gegenprobe

Alter, Sessionstatus, Requestfortschritt, Logverbrauch, Blockingopfer und `log_reuse_wait_desc` korrelieren. Lange Batchloads können legitim sein, benötigen aber Kapazitäts- und Fortschrittskontrolle.

### Typische Fehlinterpretation

`OpenTransactionCount>0` nennt nicht automatisch die äußerste fachliche Transaktion; implizite, verschachtelte oder verteilte Kontexte beachten. Ein Rollback kann ungefähr so teuer wie die bisherige Änderung sein.

### Folgeanalyse

`USP_CurrentBlocking`, `USP_CurrentLog`, Request/Anwendungs-Transaktionslogik.

[Technische Detailbeschreibung](../02_Current_State.md#5-monitorusp_currenttransactions)
