# [monitor].[USP_InternalContentionAnalysis]

**Bereich:** Server Health  
**Zweck:** Analysiert Spinlocks, Latches und Hot Pages über ein begrenztes Sample.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_InternalContentionAnalysis]
      @SampleSeconds = 5,
      @MitPageDetails = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset entspricht eine Zeile einer Spinlockklasse, einem Latch-/Hot-Page-Kandidaten, Page Detail oder Finding.

## So lesen

Delta über Sample, Klasse, Waitdauer, Hot Page, Session-/Objektkontext und Wiederholung betrachten.

Delta-, Rate- und Resetlogik verwendet die reine Funktion `monitor.TVF_InterpretContentionCounter`. Fallende Zähler liefern weder eine Differenz noch eine Rate; die Procedure setzt stattdessen `CounterResetDetected=1`.

## Warum kann das problematisch sein?

Interne Synchronisationswartezeiten können CPU-Durchsatz begrenzen, obwohl einzelne Queries unauffällig wirken.

## Wann ist es kein Problem?

Hohe kumulative Zähler ohne aktuelles Delta sind schwach.

## Beispiel und Folgeschritt

Dieselbe Hot Page in mehreren Samples mit wachsender Waitzeit: belastbare Contention. Ein einmaliger kleiner Peak nicht. TempDB-/Indexdesign, Insertmuster und Requests prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Latches, Spinlocks, Tasks oder Hot Pages zeigen interne Synchronisationskonkurrenz?

### Technischer Hintergrund

Latches schützen interne In-Memory-Strukturen/Pages, Spinlocks sehr kurze Critical Sections ohne sofortiges Schlafen. Hohe Konkurrenz erzeugt Waits, Spins/Backoffs oder Schedulerlast. Sampling zweier kumulativer DMVs lokalisiert aktuelle Deltas; Waiting Tasks/Resource Description können Hotspots zeigen.

### Datenkette

`sys.dm_db_page_info`, `sys.dm_exec_requests`, `sys.dm_os_latch_stats`, `sys.dm_os_spinlock_stats`, `sys.dm_os_sys_info`.

### Zeit- und Scope-Modell

Kurzes Sampledelta plus Tasksnapshot; Reset/Restart macht Delta ungültig.

### Bewertung und Gegenprobe

Delta-Waitzeit/Count, Average, Spin/Backoff, CPU, Resource/Page und wiederholte Samples korrelieren. PAGELATCH an TempDB Allocation unterscheidet sich von B-Tree Last-Page Contention.

### Typische Fehlinterpretation

Hohe kumulative Latchwerte seit langem Uptime sind kein aktueller Hotspot. Undokumentierte interne Namen/Verhalten können versionsabhängig sein.

### Folgeanalyse

Current Waits/TempDB/Requests, Page-/Objectauflösung und versionsspezifische Microsoftguidance.

[Technische Detailbeschreibung](../08_Server_Health.md#15-monitorusp_internalcontentionanalysis)
