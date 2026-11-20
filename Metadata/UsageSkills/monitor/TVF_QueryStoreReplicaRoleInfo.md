---
skill_format_version: "1.0.0"
name: "monitor.TVF_QueryStoreReplicaRoleInfo"
schema_name: "monitor"
object_name: "TVF_QueryStoreReplicaRoleInfo"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Die Funktion ordnet @RoleType einer Query-Store-Rollenbeschreibung, einer Scopeklasse und den zugehörigen Flags zu."
source_path: "Code/05_QueryStore/005_TVF_QueryStoreReplicaRoleInfo.sql"
---

# monitor.TVF_QueryStoreReplicaRoleInfo

## Zweck und Einsatz

Die Funktion ordnet @RoleType einer Query-Store-Rollenbeschreibung, einer Scopeklasse und den zugehörigen Flags zu. Sie referenziert keine versionsspezifischen Kataloge.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[TVF_QueryStoreReplicaRoleInfo]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @RoleType | tinyint | ja | kein Default |

**@RoleType:** Pflichtwert tinyint, kein Default. NULL und 0 ergeben UNKNOWN. 1 bis 5 bilden die definierten Rollen PRIMARY, SECONDARY, GEO_PRIMARY, GEO_SECONDARY und NAMED_REPLICA; 6 bis 255 verwenden den offenen NAMED_REPLICA-Fallback. Die Zuordnung belegt keine tatsächliche Replikatkonfiguration oder Erreichbarkeit.

## Resultate und Ausgabe

Genau eine Zeile mit RoleType tinyint (der Eingabewert, NULL bleibt NULL), RoleTypeDesc varchar(40), RoleClass varchar(24), IsPrimaryRole, IsSecondaryRole und IsNamedReplica jeweils bit sowie EvidenceLimit nvarchar(500). Für NULL und 0 sind alle drei Flags 0. Für 1 und 3 ist RoleClass READ_WRITE_ROLE und nur IsPrimaryRole 1. Für 2 und 4 ist RoleClass READ_ONLY_ROLE und nur IsSecondaryRole 1. Für 5 bis 255 ist RoleClass READ_ONLY_ROLE, IsSecondaryRole und IsNamedReplica sind 1, IsPrimaryRole ist 0.


## Beispiel

```sql
SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](1); SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](5); SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](0); SELECT * FROM [monitor].[TVF_QueryStoreReplicaRoleInfo](NULL);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
