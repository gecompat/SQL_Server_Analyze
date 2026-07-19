# [monitor].[USP_ServerHealthAnalysis]

**Bereich:** Server Health, Orchestrator  
**Zweck:** Orchestriert Topologie, Memory, TempDB, Konfiguration, OS und optionale Spezialmodule.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_ServerHealthAnalysis]
      @ResultSetArt = 'CONSOLE';
```

Spezialmodule nur bei konkreter Frage aktivieren.

## Eine Zeile bedeutet

Die Granularität hängt vom Child ab: CPU, Scheduler, Node, Memory, Datei, Konfiguration, Ereignis oder Finding.

## So lesen

Childstatus zuerst und Symptome familienweise lesen. Eine Summenzeile ist keine vollständige Gesundheitsgarantie.

## Warum kann das problematisch sein?

Ein Child kann partiell sein; ein anderes zeigt nur Konfiguration statt aktueller Auswirkung.

## Wann ist es kein Problem?

Nicht aktivierte Spezialmodule fehlen absichtlich.

## Beispiel und Folgeschritt

Memorykonfiguration auffällig, aktuelle Memorywerte normal: Review, kein akuter Incident. Das betreffende Child fokussiert erneut ausführen.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Welche Server-Health-Bereiche sind auffällig und welches Spezialmodul soll als Nächstes laufen?

### Technischer Hintergrund

Wrapper über CPU, NUMA, Memory, TempDB, Config, Trace Flags, Startup, OS und Security. Er verbindet keine atomare Systemaufnahme; Children können verschiedene Rechte/Quellen haben.

### Datenkette

Frameworkinterne Orchestrierung; Quellen liegen in Childmodulen.

### Zeit- und Scope-Modell

Nicht atomare Folge aktueller Konfigurations-/Runtimeabfragen.

### Bewertung und Gegenprobe

Childstatus und Partials zuerst, dann Befunde nach Ressource korrelieren. Triagepriorität statt Gesamtgesundheitsscore.

### Typische Fehlinterpretation

Ein grüner Wrapper beweist keine Lastfreiheit oder Integrität; optionale/gesperrte Children können fehlen.

### Folgeanalyse

Betroffenes Spezialmodul und Current-State-/Historical-Evidenz.

[Technische Detailbeschreibung](../08_Server_Health.md#10-monitorusp_serverhealthanalysis)
