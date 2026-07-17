# Template für eine Procedure-Seite

Jede neue öffentliche Analyse-Procedure benötigt eine Datei unter `Procedures/USP_Name.md`.

## Pflichtstruktur

```markdown
# [monitor].[USP_Name]

**Bereich:** ...
**Zweck:** ...

## Sicherer Einstieg

## Eine Zeile bedeutet

## So lesen

## Warum kann das problematisch sein?

## Wann ist es kein Problem?

## Beispiel und Folgeschritt

## Leere oder partielle Ausgabe

## Eigenlast

Technische Detailbeschreibung: ../Familienguide.md#anker
```

Nicht jede Seite benötigt einen langen Abschnitt zu jedem Punkt. Nicht anwendbare Punkte müssen jedoch ausdrücklich als nicht anwendbar erklärt werden.

## Inhaltliche Regeln

- Beobachtung, Ursachehypothese und Auswirkung trennen.
- Prozentwerte immer mit Nenner erklären.
- Live, Sample, kumulativ und historisch unterscheiden.
- `NULL`, 0 und keine Zeile unterscheiden.
- Repository-Default, Produktaussage und Heuristik kennzeichnen.
- CONSOLE für Einstieg, RAW für vollständige technische Analyse.
- Keine automatische DDL-, KILL-, Failover-, Repair- oder Forcing-Empfehlung.
- Nur eindeutig synthetische `Example*`-Werte in Beispielen.
