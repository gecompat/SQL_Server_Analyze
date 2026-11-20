---
skill_format_version: "1.0.0"
name: "monitor.TVF_InterpretDatabaseMailStatus"
schema_name: "monitor"
object_name: "TVF_InterpretDatabaseMailStatus"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Klassifiziert aggregierte Database-Mail-Status ohne Seiteneffekte."
source_path: "Code/01_Common/094_TVF_InterpretDatabaseMailStatus.sql"
---

# monitor.TVF_InterpretDatabaseMailStatus

## Zweck und Einsatz

Klassifiziert aggregierte Database-Mail-Status ohne Seiteneffekte.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_InterpretDatabaseMailStatus]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @SentStatus | varchar(8) | ja | kein Default |

**@SentStatus:** Pflichtwert varchar(8), kein Default. 'failed' ergibt DATABASE_MAIL_FAILED_IN_WINDOW/HIGH, 'unsent' oder 'retrying' MEDIUM, alle anderen Werte einschließlich NULL INFO. Vergleich folgt der Datenbankcollation; es wird kein Mail-Verlauf gelesen oder Versand ausgeführt.

## Resultate und Ausgabe

Genau eine Zeile mit FindingCode (varchar(100)) und FindingSeverity (varchar(16)). 'failed' ergibt DATABASE_MAIL_FAILED_IN_WINDOW/HIGH; 'unsent' und 'retrying' ergeben DATABASE_MAIL_PENDING_IN_WINDOW/MEDIUM; sonst DATABASE_MAIL_STATUS_INFORMATIONAL/INFO.


## Beispiel

```sql
SELECT FindingCode, FindingSeverity FROM monitor.TVF_InterpretDatabaseMailStatus('failed');
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die Funktion klassifiziert nur den übergebenen Status; sie liest weder Mail-Verlauf noch Kataloge und führt keinen Versand aus. Das Ergebnis beweist weder Zustellung noch Fehlerursache.

