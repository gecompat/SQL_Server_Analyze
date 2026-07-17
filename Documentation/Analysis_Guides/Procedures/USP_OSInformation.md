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

[Technische Detailbeschreibung](../08_Server_Health.md#8-monitorusp_osinformation)
