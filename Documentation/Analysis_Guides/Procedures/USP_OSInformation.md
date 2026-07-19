# [monitor].[USP_OSInformation]

**Bereich:** Server Health  
**Zweck:** Zeigt Betriebssystem, Virtualisierung, Speicher, Zeit, Uptime und Plattformgrenzen.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_OSInformation]
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Je Resultset beschreibt eine Zeile eine OS-/Plattformeigenschaft oder eine Zusammenfassung.

## So lesen

OS-Version, Virtualisierung, Speicher, Zeit, Uptime und Plattform gemeinsam lesen.

## Warum kann das problematisch sein?

Sehr geringe Uptime erklärt resetete DMVs; Zeitabweichungen erschweren Ereigniskorrelation; Memory-/VM-Grenzen beeinflussen SQL.

## Wann ist es kein Problem?

Virtualisierung ist nicht automatisch langsam.

## Beispiel und Folgeschritt

Index Usage zeigt 0 Reads, OS Uptime zwei Stunden: Beobachtungsfenster zu kurz für eine Löschung. CPU, Memory, I/O und Hypervisor-Monitoring korrelieren.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Betriebssystem-, Host-, Virtualisierungs- und Ressourceninformationen sieht SQL Server?

### Technischer Hintergrund

Host-/Windows-/Linux-DMVs liefern OS-Version, Hostplattform, Memory/Pagefile, Startzeit und Virtualization/Containerhinweise soweit verfügbar. SQL Server sieht im Gast nicht zwingend Hypervisor-Steal, SAN- oder Hostcontention vollständig.

### Datenkette

`sys.dm_os_host_info`, `sys.dm_os_process_memory`, `sys.dm_os_sys_memory`, `sys.dm_server_services`.

### Zeit- und Scope-Modell

Aktueller Gast-/Instanzkontext; OS-/Engine-Startzeiten können verschieden sein.

### Bewertung und Gegenprobe

OS/Build Support, VM/Physical, Memory/Commit, Pagefile, Uptime und Instanzbuild korrelieren. Für Performance CPU-, Storage- und Memorytelemetrie außerhalb SQL ergänzen.

### Typische Fehlinterpretation

Unauffällige Gastwerte schließen Hostengpass nicht aus. Pagefile vorhanden/benutzt ist allein keine SQL-Memorydiagnose.

### Folgeanalyse

Server CPU/Memory/IO und OS-/Hypervisormonitoring.

[Technische Detailbeschreibung](../08_Server_Health.md#8-monitorusp_osinformation)
