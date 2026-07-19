# [monitor].[USP_CheckFrameworkCapabilities]

**Bereich:** Common  
**Zweck:** Prüft Version, Policy, Berechtigung, Abfragbarkeit und Featurestatus für Diagnosepfade.

## Sicherer Einstieg

```sql
EXEC [monitor].[USP_CheckFrameworkCapabilities]
      @NurNichtVerfuegbar = 1,
      @ResultSetArt = 'CONSOLE';
```

## Eine Zeile bedeutet

Eine Capability-Zeile bewertet ein Feature in einem Server- oder Datenbank-Scope. Dieselbe Fähigkeit kann deshalb je Datenbank unterschiedlich ausfallen.

## So lesen

In dieser Reihenfolge lesen: `VersionSupported` → `GroupAccessAllowed` → `HasRequiredPermission` → `IsQueryable` → `IsFeatureEnabled` → `IsUsable`.

## Warum kann das problematisch sein?

`HasRequiredPermission=1`, aber `IsQueryable=0` zeigt, dass eine formale Permission nicht genügt. Datenbankstatus, Plattform, Replica-Rolle oder Laufzeitfehler begrenzen den Pfad.

## Wann ist es kein Problem?

Ein deaktiviertes Feature ist kein Serverfehler, wenn es nicht benötigt wird. Es erklärt lediglich, warum die zugehörige Analyse keine Daten liefern kann.

## Beispiel und Folgeschritt

Query Store kann versionsseitig unterstützt und lesbar, aber deaktiviert sein. Ein leeres Query-Store-Resultset sagt dann nichts über die Queryqualität. Nur Scopes mit `IsUsable=1` fachlich auswerten.

## Leere oder partielle Ausgabe

Fehlende Capability-Zeilen können durch Datenbankauswahl, Rechte oder `@MaxDatenbanken` entstehen. Status- und Warnresultsets gehören zwingend zur Bewertung.

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

Ist ein Analysepfad auf dieser konkreten Instanz nicht nur theoretisch unterstützt, sondern tatsächlich nutzbar?

### Technischer Hintergrund

Version, Edition, Featurekonfiguration und formale Permission sind verschiedene Ebenen. Die Procedure führt capability-orientierte Prüfungen aus und kann geschützte Testabfragen dynamisch ausführen. Dadurch wird zwischen `supported`, `enabled`, `permitted`, `queryable` und `usable` unterschieden.

### Datenkette

`sys.sp_executesql`.

### Zeit- und Scope-Modell

Aktueller Umgebungszustand; Ergebnisse können sich nach Konfigurationsänderung, Failover, Datenbankstatuswechsel oder Berechtigungsänderung ändern.

### Bewertung und Gegenprobe

Die Prüfkette in der dokumentierten Reihenfolge lesen. `HasRequiredPermission=1` bei `IsQueryable=0` weist auf eine zusätzliche Laufzeitgrenze hin. `IsFeatureEnabled=0` kann bei bewusst ungenutztem Feature normal sein.

### Typische Fehlinterpretation

Capability ist kein Nachweis, dass relevante Daten vorhanden sind. Query Store kann nutzbar, aber leer sein; XE kann abfragbar, aber ohne passende Session sein.

### Folgeanalyse

Nur Fachmodule starten, deren benötigte Quelle nutzbar ist; bei Partialstatus die jeweilige Datenbank/Quelle gezielt prüfen.

[Technische Detailbeschreibung](../01_Common.md#2-monitorusp_checkframeworkcapabilities)
