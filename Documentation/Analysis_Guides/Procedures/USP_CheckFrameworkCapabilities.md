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

[Technische Detailbeschreibung](../01_Common.md#2-monitorusp_checkframeworkcapabilities)
