# [monitor].[USP_BufferPoolAnalysis]

**Bereich:** Server Health  
**Zweck:** Zeigt Buffer-Pool-Verteilung, Memory Clerks und Pressure-Kontext.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_BufferPoolAnalysis]
      @MitMemoryClerks = 1,
      @MitBufferPoolVerteilung = 0,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine Memoryzusammenfassung, einen Clerk oder eine Datenbank-/Page-Verteilung.

## So lesen

Gesamtbuffer, Clerks, Datenbankanteile, Dirty/Clean Pages und Memory Pressure gemeinsam lesen.

## Warum kann das problematisch sein?

Dominante Clerks oder ungewöhnliche Verteilung können Speicher verdrängen; viele Dirty Pages können Checkpoint-/I/O-Druck anzeigen.

## Wann ist es kein Problem?

Eine große aktive Datenbank darf den Buffer Pool dominieren.

## Beispiel und Folgeschritt

80 % Buffer für ExampleDatabase ist nicht automatisch schlecht. Problematisch wird es, wenn andere aktive Datenbanken physisch lesen und Memory Pressure besteht. Memory, I/O und Query Reads prüfen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Wie verteilt sich der Buffer Pool auf Datenbanken, Objekte und Pagearten, und gibt es Hinweise auf Cache-/Memorydruck?

### Technischer Hintergrund

Buffer Descriptors repräsentieren gecachte 8-KB-Datenseiten. Verteilung nach Database/File/Page/Object kann Working Set zeigen; Memory Clerks und PLE/Lazy Writes ergänzen Drucksignale. Clean Pages sind verwerfbar, Dirty Pages benötigen Flush.

### Datenkette

`sys.dm_exec_query_resource_semaphores`, `sys.dm_os_buffer_descriptors`, `sys.dm_os_memory_clerks`, `sys.dm_os_process_memory`, `sys.dm_os_sys_memory`.

### Zeit- und Scope-Modell

Aktueller Cachebestand; laufend durch Reads, Writes, Checkpoint und Memory Pressure verändert.

### Bewertung und Gegenprobe

Cached MB/Pages, Dirtyanteil, Datenbank-/Objektanteil, Page Life/Reads, OS-/Processdruck und Workloadgröße kombinieren. Dominanter Cacheanteil kann legitimes Working Set sein.

### Typische Fehlinterpretation

Bufferanteil ist keine Hit Ratio und häufig gecacht bedeutet nicht automatisch problematisch. Breiter Descriptor-Scan kann selbst CPU/Memory/I/O-Metadatenlast erzeugen.

### Folgeanalyse

Server Memory, Performance Counters, Query Reads/Plans; Deep-Pfad nur kontrolliert.

[Technische Detailbeschreibung](../08_Server_Health.md#16-monitorusp_bufferpoolanalysis)
