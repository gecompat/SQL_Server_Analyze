---
skill_format_version: "1.0.0"
name: "monitor.TVF_InterpretPerformanceCounter"
schema_name: "monitor"
object_name: "TVF_InterpretPerformanceCounter"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Interpretiert ein übergebenes Performance-Counter-Paar nach CounterType und liefert Interpretation, Metrik, Einheit und FindingCode als einzelne Tabellenzeile."
source_path: "Code/01_Common/088_TVF_InterpretPerformanceCounter.sql"
---

# monitor.TVF_InterpretPerformanceCounter

## Zweck und Einsatz

Interpretiert ein übergebenes Performance-Counter-Paar nach CounterType und liefert Interpretation, Metrik, Einheit und FindingCode als einzelne Tabellenzeile.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_InterpretPerformanceCounter]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @CounterType | int | ja | kein Default |
| @BeforeValue | bigint | ja | kein Default |
| @AfterValue | bigint | ja | kein Default |
| @BaseBeforeValue | bigint | ja | kein Default |
| @BaseAfterValue | bigint | ja | kein Default |
| @SampleSeconds | decimal(19,6) | ja | kein Default |

**@CounterType:** Pflichtwert int, kein Default. 65792 wird RAW_SNAPSHOT, 272696320/272696576 RATE_PER_SECOND, 537003264 FRACTION_DELTA_PERCENT, 1073874176 AVERAGE_DELTA_RATIO; weitere Typen sind RAW_UNINTERPRETED. NULL kann über SQL-UNKNOWN zum VALUE_AVAILABLE-Code führen.

**@BeforeValue:** Pflichtwert bigint, kein Default. Vorheriger Zählerstand für Delta-/Basisformeln; NULL oder fallender Wert kann die Metrik verhindern bzw. Reset-Finding auslösen.

**@AfterValue:** Pflichtwert bigint, kein Default. Nachheriger Zählerstand; Roh- und unbekannte Typen geben ihn direkt als Metrik aus. Deltaformeln benötigen einen nicht fallenden Wert gegenüber BeforeValue.

**@BaseBeforeValue:** Pflichtwert bigint, kein Default. Vorheriger Basiszähler nur für Basiscountertypen; fehlender Wert führt dort zu BASE_COUNTER_MISSING.

**@BaseAfterValue:** Pflichtwert bigint, kein Default. Nachheriger Basiszähler für FRACTION_DELTA_PERCENT/AVERAGE_DELTA_RATIO; fallender oder nicht steigender Basiswert erhält eigene FindingCodes.

**@SampleSeconds:** Pflichtwert decimal(19,6), kein Default. Delta-Metriken verlangen >0; sonst SAMPLE_REQUIRED_FOR_DELTA_METRIC. Die Basisformeln verlangen ebenfalls >0, teilen aber nicht durch die Zeit.

## Resultate und Ausgabe

[Interpretation] varchar, [MetricValue] decimal(38,6), [MetricUnit] varchar und [FindingCode] varchar. NULL-Eingaben können NULL-Metriken ergeben, ohne selbst einen FindingCode auszulösen. Ein verfügbarer Wert belegt weder eine Diagnose noch einen Schwellwertbefund.


## Beispiel

```sql
SELECT * FROM [monitor].[TVF_InterpretPerformanceCounter](537003264, 10, 16, 100, 120, 5.0);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Liest keine DMVs und persistiert nichts. Die Funktion validiert keine Eingabekonsistenz und schützt nicht vor Überläufen der verwendeten Arithmetik. Roh- und unbekannte Typen liefern @AfterValue als Rohmetrikwert; das ist keine automatische Interpretation des Counters.

