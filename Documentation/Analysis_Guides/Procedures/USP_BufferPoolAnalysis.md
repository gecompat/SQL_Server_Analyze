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

[Technische Detailbeschreibung](../08_Server_Health.md#16-monitorusp_bufferpoolanalysis)
