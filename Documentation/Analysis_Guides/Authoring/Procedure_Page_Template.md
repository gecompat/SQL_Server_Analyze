# Template für eine Procedure-Seite

Jede neue öffentliche Analyse-Procedure benötigt eine Datei unter `Procedures/USP_Name.md` und einen Eintrag im [Review-Manifest](../../../Metadata/Quality/Analysis_Documentation_Review.csv). Der verbindliche Inhalt steht im [Qualitätsvertrag](../Documentation_Quality_Contract.md).

## Pflichtstruktur für `DEEP_REVIEWED`

```markdown
# [monitor].[USP_Name]

**Bereich:** ...
**Zweck:** ...
**Beobachtungsart:** Snapshot | kumulativ | Stichprobe | Historie | Katalog
**Kostenklasse:** LOW | MEDIUM | HIGH_OPT_IN | Spannweite

## Entscheidungsfrage und Einsatz

## Nicht beantwortete Fragen

## Sicherer Einstieg

## Resultsets und Leserichtung

## Eine Zeile bedeutet

## So lesen

## Warum kann das problematisch sein?

## Wann ist es kein Problem?

## Beispiele und Gegenbeispiele

## Leere oder partielle Ausgabe

## Eigenlast und Grenzen

| Dimension | Aussage für diese Procedure |
|---|---|
| Kostenklasse | ... |
| Standardpfad | ... |
| Teuerster Pfad | ... |
| Haupttreiber | ... |
| Skalierung | ... |
| Ressourcen | ... |
| Begrenzungswirkung | ... |
| Locking und Nebenwirkungen | ... |
| Schutzmechanismus | ... |
| Sicherer Einsatz | ... |
| Aussagegrenze | ... |

## Technische Vertiefung

[Gemeinsames Execution-, Zeit- und Evidenzmodell](../Technical_Foundations.md)

### Leitfrage

### Technischer Hintergrund

### Datenkette

### Zeit- und Scope-Modell

### Bewertung und Gegenprobe

### Typische Fehlinterpretation

### Folgeanalyse

## Primärquellen

- [Passende Microsoft-Produktdokumentation](https://learn.microsoft.com/...)

Technische Detailbeschreibung: ../Familienguide.md#anker
```

## Inhaltliche Regeln

- Den erwarteten Anwendungsfall so konkret beschreiben, dass ein Leser entscheiden kann, ob die Procedure überhaupt die richtige ist.
- Beobachtung, Ursachehypothese, Auswirkung und Handlung trennen.
- Prozentwerte und Durchschnitte immer mit Nenner erklären.
- Live, Sample, kumulativ und historisch unterscheiden; Restart, Reset, Eviction, Capture und Retention nennen.
- `NULL`, 0, keine Zeile, fehlende Berechtigung und partielle Quelle unterscheiden.
- Repository-Default, Produktaussage und Heuristik kennzeichnen.
- CONSOLE als fachlichen Einstieg, RAW für vollständige technische Resultsets und TABLE für die typisierte SQL-interne Weiterverarbeitung des im Resultset-Inventar benannten Ergebnisses erklären.
- Bei `@MaxZeilen`, `TOP` und Filtern anhand des T-SQL angeben, ob sie Quellarbeit oder nur Rückgabemenge begrenzen.
- Kosten des Standardpfads und des teuersten zulässigen Pfads getrennt bewerten.
- Locking, I/O, CPU, Speicher, TempDB, Ergebnistransfer und bewusste Nebenwirkungen nur als nicht anwendbar ausweisen, wenn dies aus dem Quellpfad begründbar ist.
- Keine automatische DDL-, `KILL`-, Failover-, Repair- oder Forcing-Empfehlung.
- Nur eindeutig synthetische `Example*`-Werte in Beispielen.
- Primärquellen direkt auf die relevante Microsoft-Produktseite verlinken; Drafts oder Sekundärblogs sind kein Ersatz.

Nicht jede Seite benötigt dieselbe Länge. Nicht anwendbare Punkte müssen jedoch ausdrücklich erklärt werden. Der Manifeststatus wird erst nach fachlichem Abgleich mit der kanonischen SQL-Quelle auf `DEEP_REVIEWED` gesetzt.
