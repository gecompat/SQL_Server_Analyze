---
skill_format_version: "1.0.0"
name: "monitor.TVF_InterpretAvailabilityDatabaseState"
schema_name: "monitor"
object_name: "TVF_InterpretAvailabilityDatabaseState"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Die Funktion klassifiziert den übergebenen Momentzustand einer Always On-Verfügbarkeitsdatenbank anhand von Status-, Queue- und Lagwerten; sie liest keine DMV und hat keine Seiteneffekte."
source_path: "Code/01_Common/090_TVF_InterpretAvailabilityDatabaseState.sql"
---

# monitor.TVF_InterpretAvailabilityDatabaseState

## Zweck und Einsatz

Die Funktion klassifiziert den übergebenen Momentzustand einer Always On-Verfügbarkeitsdatenbank anhand von Status-, Queue- und Lagwerten; sie liest keine DMV und hat keine Seiteneffekte.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_InterpretAvailabilityDatabaseState]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @IsSuspended | bit | ja | kein Default |
| @SynchronizationHealthDesc | nvarchar(60) | ja | kein Default |
| @SynchronizationStateDesc | nvarchar(60) | ja | kein Default |
| @LogSendQueueSizeKb | bigint | ja | kein Default |
| @RedoQueueSizeKb | bigint | ja | kein Default |
| @SecondaryLagSeconds | bigint | ja | kein Default |
| @QueueWarnMb | bigint | ja | kein Default |
| @SecondaryLagWarnSeconds | int | ja | kein Default |

**@IsSuspended:** Pflichtwert bit, kein Default. Exakt 1 löst DATA_MOVEMENT_SUSPENDED/HIGH vorrangig aus; NULL erfüllt diesen Fall nicht und wird nicht eigens abgewiesen.

**@SynchronizationHealthDesc:** Pflichtwert nvarchar(60), kein Default. Der Status NOT_HEALTHY löst DATABASE_NOT_HEALTHY/HIGH aus, sofern kein vorrangiger Stillstand vorliegt; NULL/andere Texte lösen diesen Fall nicht aus.

**@SynchronizationStateDesc:** Pflichtwert nvarchar(60), kein Default. NOT_SYNCHRONIZING löst DATABASE_NOT_SYNCHRONIZING/HIGH nach den vorrangigen Fällen aus; SQL-Textvergleich folgt der Eingabecollation.

**@LogSendQueueSizeKb:** Pflichtwert bigint, kein Default. COALESCE(NULL,0) wird gegen QueueWarnMb*1024 einschließlich Grenzwert geprüft; die Funktion liest keine DMV.

**@RedoQueueSizeKb:** Pflichtwert bigint, kein Default. COALESCE(NULL,0) wird nach dem Log-Send-Queuefall gegen QueueWarnMb*1024 geprüft; zutreffender Queuefall ergibt MEDIUM.

**@SecondaryLagSeconds:** Pflichtwert bigint, kein Default. COALESCE(NULL,0) wird gegen SecondaryLagWarnSeconds einschließlich Grenzwert verglichen; zutreffender Lagfall ergibt MEDIUM.

**@QueueWarnMb:** Pflichtwert bigint, kein Default. Schwelle in MiB für beide Queuewerte; Multiplikation mit 1024 liefert KiB. NULL macht die jeweilige Vergleichsbedingung nicht zutreffend; negative Werte werden nicht validiert.

**@SecondaryLagWarnSeconds:** Pflichtwert int, kein Default. Sekundenschwelle für den Lagvergleich; NULL macht diesen Vergleich nicht zutreffend. Die Funktion prüft weder negative noch andere ungewöhnliche Grenzwerte.

## Resultate und Ausgabe

Eine Zeile mit [FindingCode] (varchar(100)) und [FindingSeverity] (varchar(16)).


## Beispiel

```sql
SELECT *
               FROM [monitor].[TVF_InterpretAvailabilityDatabaseState]
               (
                   0, N'HEALTHY', N'SYNCHRONIZED',
                   0, 0, 0, 10, 30
               );
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

DATABASE_STATE_ACCEPTABLE besagt nur, dass keine der implementierten Bedingungen zutraf. Der Wert belegt weder vollständige Gesundheit noch Erreichbarkeit einer Replik oder eine künftige Catch-up-Zeit. Queue- und Laggrenzen sind Sichtungswerte und beweisen weder Ursache noch zukünftige Catch-up-Zeit.

