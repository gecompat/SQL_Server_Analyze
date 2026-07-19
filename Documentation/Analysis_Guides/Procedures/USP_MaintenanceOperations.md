# [monitor].[USP_MaintenanceOperations]

**Bereich:** Infrastruktur  
**Zweck:** Korrelierte read-only Sicht auf resumierbare Indexoperationen, technische Wartungsrequests, ADR/PVS und ausdrücklich ausgewählte Agent-Jobs.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_MaintenanceOperations]
      @DatabaseNames = N'[ExampleDatabase]',
      @NurProblematisch = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer resumierbaren Indexoperation, einem laufenden Wartungsrequest, dem ADR/PVS-Zustand einer Datenbank, einem ausdrücklich gefilterten Job oder einem Quellenstatus.

## So lesen

Zuerst Quellenstatus und Versionsgrenze prüfen. Ein pausierter resumierbarer Vorgang wird mit Alter und Fortschritt gelesen. Bei Requests Blockierung, Wait, Fortschritt und Engine-Schätzung gemeinsam bewerten. PVS ist eine Momentaufnahme. Ohne `@JobNames` oder `@JobNamePattern` ist die Jobquelle absichtlich `NOT_REQUESTED`.

## Warum kann das problematisch sein?

Lange pausierte Indexoperationen, blockierte Wartung oder eine große PVS mit abgebrochenen Transaktionen können Ressourcen binden und geplante Wartungsziele verfehlen. Überlappende ausdrücklich gewählte Jobs können konkurrieren.

## Wann ist es kein Problem?

Pause, lange Dauer, hoher IO-Zähler oder ein laufender Rollback können beabsichtigt beziehungsweise arbeitsmengenbedingt sein. Ein einzelner PVS-Wert beweist keine Bereinigungsstörung. Jobnamen werden ohne explizite Auswahl nicht einmal gelesen.

## Read-only-Grenze

Die Procedure führt kein `RESUME`, `ABORT`, `KILL`, Cleanup, Job-Start oder Job-Stop aus. Sie liest keine SQL-Texte, Jobschritte, Jobbefehle, Meldungen, Konten, Clientdaten oder Wait-Ressourcen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Wartungsoperationen laufen, sind pausiert/resumable oder blockiert, und wie belastbar ist ihre Fortschrittsanzeige?

### Technischer Hintergrund

Aktive BACKUP/RESTORE/DBCC/INDEX-Commands erscheinen in Requests; resumable Indexoperationen besitzen persistierte Katalogzeilen mit State, Start/Pause, Prozent und Ressourcenoptionen. Locks, Log, TempDB und I/O können die Laufzeit dominieren.

### Datenkette

`msdb.dbo.sysjobactivity`, `msdb.dbo.sysjobs`, `msdb.dbo.syssessions`, `sys.databases`, `sys.dm_exec_requests`, `sys.dm_tran_persistent_version_store_stats`, `sys.index_resumable_operations`.

### Zeit- und Scope-Modell

Aktueller Requestsnapshot plus persistierter resumable Zustand.

### Bewertung und Gegenprobe

Command, Status, Percent Complete, Estimated Completion, DOP, Wait/Blocker, Log-/TempDB-/I/O-Kontext und Resume/Pauseoptionen lesen. Pausierte Operation kann weiterhin Speicher/Strukturzustand belegen.

### Typische Fehlinterpretation

Percent Complete ist nur für unterstützte Commands und nicht linear. Abbruch kann Rollback-/Cleanupkosten verursachen; `PAUSED` ist nicht erfolgreich abgeschlossen.

### Folgeanalyse

Current Requests/Blocking/IO/Log und operationsspezifischer Runbook.

[Technische Detailbeschreibung](../07_Infrastructure.md)
