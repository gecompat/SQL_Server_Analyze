---
skill_format_version: "1.0.0"
name: "monitor.TVF_InterpretAvailabilitySeedingState"
schema_name: "monitor"
object_name: "TVF_InterpretAvailabilitySeedingState"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Die Funktion berechnet Fortschritt und Restbytes und klassifiziert den übergebenen Momentzustand eines physischen Seedings."
source_path: "Code/01_Common/091_TVF_InterpretAvailabilitySeedingState.sql"
---

# monitor.TVF_InterpretAvailabilitySeedingState

## Zweck und Einsatz

Die Funktion berechnet Fortschritt und Restbytes und klassifiziert den übergebenen Momentzustand eines physischen Seedings. Sie wertet ausschließlich Parameter aus und hat keine Seiteneffekte.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_InterpretAvailabilitySeedingState]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @FailureCode | int | ja | kein Default |
| @TransferredSizeBytes | bigint | ja | kein Default |
| @DatabaseSizeBytes | bigint | ja | kein Default |
| @TransferRateBytesPerSecond | bigint | ja | kein Default |
| @EndTimeUtc | datetime | ja | kein Default |

**@FailureCode:** Pflichtwert int, kein Default. Ein von 0 verschiedener COALESCE(FailureCode,0) löst vorrangig SEEDING_FAILED/HIGH aus; NULL wirkt in diesem Test wie 0.

**@TransferredSizeBytes:** Pflichtwert bigint, kein Default. Übertragene Bytes bestimmen Fortschritt und Restbytes; COALESCE(NULL,0) wird verwendet. Negative/fehlende Werte können unerwartete Werte oder Rechenfehler ergeben.

**@DatabaseSizeBytes:** Pflichtwert bigint, kein Default. Nenner für Fortschritt; COALESCE(NULL,0)<=0 liefert NULL-Fortschritt. Restbytes und Statusfolge verwenden den normalisierten Wert; fehlende Größe kann SEEDING_COMPLETED ermöglichen.

**@TransferRateBytesPerSecond:** Pflichtwert bigint, kein Default. Übergebener Momentwert; bei offenem Rest, NULL-Endzeit und zu 0 normalisierter Rate folgt SEEDING_NO_CURRENT_THROUGHPUT. Keine ETA-Berechnung.

**@EndTimeUtc:** Pflichtwert datetime, kein Default. Wird nur auf NULL geprüft; keine Zeitdifferenz oder Zeitzonenumrechnung. Ein gesetzter Wert kann zusammen mit ausreichenden Bytes SEEDING_COMPLETED ergeben.

## Resultate und Ausgabe

Eine Zeile mit [ProgressPercent] (decimal(9,4)), [RemainingBytes] (bigint), [FindingCode] (varchar(100)) und [FindingSeverity] (varchar(16)).


## Beispiel

```sql
SELECT *
               FROM [monitor].[TVF_InterpretAvailabilitySeedingState]
               (
                   0, NULL, NULL, NULL, '2026-01-01T00:00:00'
               );
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

COALESCE(NULL, 0) kann bei fehlenden Zählern den Code SEEDING_COMPLETED ermöglichen, wenn auch die normalisierte Größe 0 ist. Die Kennzahlen belegen weder eine ETA noch vollständige Gesundheit oder erfolgreichen Empfang auf einer Zielreplik. Die Rate ist ein übergebener Momentwert.

