---
skill_format_version: "1.0.0"
name: "monitor.USP_AvailabilityGroups"
schema_name: "monitor"
object_name: "USP_AvailabilityGroups"
object_type: "PROCEDURE"
database_role: "framework"
is_internal: false
description: "Die Procedure analysiert Availability Groups, Replikate, Datenbanken, Listener, Routing sowie Send-/Redo-Queues und geschätzte Lags."
source_path: "Code/07_Infrastructure/040_USP_AvailabilityGroups.sql"
---

# monitor.USP_AvailabilityGroups

## Zweck und Einsatz

Die Procedure analysiert Availability Groups, Replikate, Datenbanken, Listener, Routing sowie Send-/Redo-Queues und geschätzte Lags.

## Voraussetzungen und Rechte

SQL Server 2019 oder neuer.

sys.availability_groups, sys.availability_replicas, sys.dm_hadr_*, sys.availability_group_listeners

Nur lesender Zugriff auf die genannten Systemobjekte. Das Framework vergibt keine Rechte und ändert keine Konfiguration.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @MitRouting | bit | nein | 1 |
| @MaxZeilen | int | nein | 5000 |
| @ResultSetArt | varchar(16) | nein | 'CONSOLE' |
| @ResultTablesJson | nvarchar(max) | nein | NULL |
| @JsonErzeugen | bit | nein | 0 |
| @Json | nvarchar(max) | nein | NULL OUTPUT |
| @PrintMeldungen | bit | nein | 1 |
| @Hilfe | bit | nein | 0 |

**@MitRouting:** @MitRouting bit; Default: 1. SQL Server konvertiert das Argument vor Aufruf; NULL bleibt NULL. Nur ein Argument, das SQL Server zu bit 1 konvertiert, führt die zusätzliche Read-only-Abfrage der Read-Only-Routinglisten aus. Bei 0 oder NULL bleibt diese Ergebnismenge leer. Bei ausgelassenem Argument gilt der angegebene Default.

**@MaxZeilen:** @MaxZeilen int; Default: 5000. Der SQL-int-Bereich von -2.147.483.648 bis 2.147.483.647. Ein negativer Wert ergibt INVALID_PARAMETER. NULL oder 0 wird in bigint-Maximalwert umgerechnet und bedeutet damit praktisch unbegrenzt; ein positiver Wert begrenzt jede der vier Ergebnismengen getrennt. Er filtert weder AGs noch Datenbanken vor der Quellabfrage. Nicht konvertierbare Argumente scheitern bereits vor dem Procedure-Body. Einheit: Zeilen je Ergebnismenge. Ein negativer Wert allein lässt IsPartial=0. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultSetArt:** @ResultSetArt varchar(16); Default: 'CONSOLE'. SQL-Konvertierung findet vor dem Body statt; danach werden Leerzeichen an den Rändern entfernt und die Eingabe in Großbuchstaben normalisiert. Vorgesehen sind CONSOLE, RAW, TABLE und NONE. NULL, leerer oder unbekannter Wert ist ungültig. RAW liefert zuerst den Modulstatus und danach vier native Ergebnismengen; NONE unterdrückt Ergebnismengen. CONSOLE wird intern zunächst zu NONE und am Ende über den erreichbaren gemeinsamen Console-Adapter für die Replikamenge ausgegeben. TABLE unterdrückt die nativen Mengen und exportiert nur replicas. Außerhalb von TABLE muss ResultTablesJson NULL oder leer sein. Bei ausgelassenem Argument gilt der angegebene Default.

**@ResultTablesJson:** @ResultTablesJson nvarchar(max); Default: NULL. Nur im TABLE-Modus wird ein JSON-Objekt mit dem exakt erlaubten Schlüssel replicas angenommen; sein Zeichenkettenwert muss auf eine bereits angelegte, leere lokale #Temp-Tabelle mit genau einer beliebigen Seed-Spalte zeigen. Globale ##Temp- und permanente Ziele sind unzulässig; der Tabellenname darf höchstens 116 Zeichen lang sein. NULL oder leer wird im TABLE-Modus vom Helper abgelehnt. Außerhalb davon löst nichtleeres JSON nach Trimmen Fehler 51011 aus; Whitespace gilt als leer. Der Helper prüft Schlüssel und Stringtyp, Eindeutigkeit sowie den Zielnamen. Diese Prüfung liegt vor HELP. Das Präfix #Monitor ist unabhängig von Groß- und Kleinschreibung reserviert. Der Preflight kann vor HELP vorübergehend eine Markerspalte hinzufügen und entfernen. Bei ausgelassenem Argument gilt der angegebene Default.

**@JsonErzeugen:** @JsonErzeugen bit; Default: 0. Nur der nach SQL-Konvertierung vorliegende Wert 1 aktiviert die JSON-Erzeugung für den OUTPUT-Parameter Json; NULL wirkt wie deaktiviert. JSON-Erzeugung ist unabhängig von ResultSetArt. Der gebundene Wert 0 deaktiviert die JSON-Erzeugung. Bei ausgelassenem Argument gilt der angegebene Default.

**@Json:** @Json nvarchar(max) OUTPUT; Default: NULL. Die Procedure setzt ihn am Eintritt auf NULL; nur bei JsonErzeugen=1 enthält er ein JSON-Objekt mit den Schlüsseln meta, replicas, databases, listeners und routing. Die Arrays enthalten auch NULL-Felder. Die OUTPUT-Bindung ändert die normalen Resultsets nicht. Binden Sie eine Variable des deklarierten Typs mit OUTPUT.

**@PrintMeldungen:** @PrintMeldungen bit; Default: 1. Bei einem abgefangenen Fehler der Erfassung gibt nur der Wert 1 eine Meldung mit Severity 10 und WITH NOWAIT aus. 0 oder NULL unterdrücken nur diese Zusatzmeldung, nicht Status oder Daten. SQL-konvertierte bit-Eingaben werden vor dem Body gebunden. Bei ausgelassenem Argument gilt der angegebene Default.

**@Hilfe:** @Hilfe bit; Default: 0. Nur der gebundene bit-Wert 1 gibt die Hilfe mit PRINT aus und kehrt vor der Erfassung zurück. 0 und NULL aktivieren die Hilfe nicht. Json wird vorher auf NULL gesetzt; auch die TABLE-Vorprüfung findet bereits statt. Bei ausgelassenem Argument gilt der angegebene Default.

## Resultate und Ausgabe

1. Modulstatus. 2. Gruppen/Replikate. 3. Datenbanken/Queues. 4. Listener. 5. Routing.

| Resultmenge | RAW | TABLE | Felder laut Inventar |
| --- | --- | --- | --- |
| replicas | 1 | 1 | [AgName] sysname,[ReplicaServerName] nvarchar(256),[LocalReplica] bit,[RoleDesc] nvarchar(60),[OperationalStateDesc] nvarchar(60),[ConnectedStateDesc] nvarchar(60),[RecoveryHealthDesc] nvarchar(60),[SynchronizationHealthDesc] nvarchar(60),[AvailabilityModeDesc] nvarchar(60),[FailoverModeDesc] nvarchar(60),[SessionTimeout] int,[EndpointUrl] nvarchar(256),[PrimaryRoleAllowConnectionsDesc] nvarchar(60),[SecondaryRoleAllowConnectionsDesc] nvarchar(60),[ReadOnlyRoutingUrl] nvarchar(256) |

Bei @Hilfe=1 kommt genau ein Resultset mit SkillFormatVersion, SchemaName, ObjectName und SkillMarkdown hinzu; bestehende PRINT-Hinweise bleiben erhalten.

## Beispiel

```sql
EXEC [monitor].[USP_AvailabilityGroups] @Hilfe=1;
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

monitor.USP_AvailabilityGroups

Beispiel 1: EXEC [monitor].[USP_AvailabilityGroups] @Hilfe=1;

Beispiel 2: EXEC [monitor].[USP_AvailabilityGroups] @MitRouting=0, @MaxZeilen=100, @ResultSetArt='RAW';

Beispiel 3: DECLARE @AgJson nvarchar(max); EXEC [monitor].[USP_AvailabilityGroups] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgJson OUTPUT; SELECT @AgJson AS [Json];

Beispiel 4: CREATE TABLE #AvailabilityGroups_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AvailabilityGroups] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"replicas":"#AvailabilityGroups_HelpExample"}'; SELECT * FROM #AvailabilityGroups_HelpExample; DROP TABLE #AvailabilityGroups_HelpExample; END TRY BEGIN CATCH DROP TABLE #AvailabilityGroups_HelpExample; THROW; END CATCH;


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.USP_AvailabilityGroups
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : Stored Procedure
Zweck        : Die Procedure analysiert Availability Groups, Replikate, Datenbanken, Listener, Routing sowie Send-/Redo-Queues und geschätzte Lags.
SQL-Version  : SQL Server 2019 oder neuer.
Datenquellen : sys.availability_groups, sys.availability_replicas, sys.dm_hadr_*, sys.availability_group_listeners
Parameter    : @MitRouting, @MaxZeilen, @PrintMeldungen, @Hilfe
Resultsets   : 1. Modulstatus. 2. Gruppen/Replikate. 3. Datenbanken/Queues. 4. Listener. 5. Routing.
Berechtigung : Nur lesender Zugriff auf die genannten Systemobjekte. Das
               Framework vergibt keine Rechte und ändert keine Konfiguration.
Eigenlast    : Mittel; reine HADR-Katalog- und DMV-Auswertung.
Locking      : LOCK_TIMEOUT 0; keine fachlichen Schreibzugriffe.
Status       : Ungültige Parameter ergeben INVALID_PARAMETER. Nicht aktiviertes
               HADR ergibt UNAVAILABLE_FEATURE; abgefangene Erfassungsfehler ergeben
               ERROR_HANDLED mit Partial Result.
Änderungen   : 1.0.0 - Erstfassung Phase 6.
```

### Weitere bestehende Hilfehinweise

```text
monitor.USP_AvailabilityGroups
Beispiel 1: EXEC [monitor].[USP_AvailabilityGroups] @Hilfe=1;
Beispiel 2: EXEC [monitor].[USP_AvailabilityGroups] @MitRouting=0, @MaxZeilen=100, @ResultSetArt='RAW';
Beispiel 3: DECLARE @AgJson nvarchar(max); EXEC [monitor].[USP_AvailabilityGroups] @MaxZeilen=100, @ResultSetArt='NONE', @JsonErzeugen=1, @Json=@AgJson OUTPUT; SELECT @AgJson AS [Json];
Beispiel 4: CREATE TABLE #AvailabilityGroups_HelpExample ([Seed] int NULL); BEGIN TRY EXEC [monitor].[USP_AvailabilityGroups] @MaxZeilen=100, @ResultSetArt='TABLE', @ResultTablesJson=N'{"replicas":"#AvailabilityGroups_HelpExample"}'; SELECT * FROM #AvailabilityGroups_HelpExample; DROP TABLE #AvailabilityGroups_HelpExample; END TRY BEGIN CATCH DROP TABLE #AvailabilityGroups_HelpExample; THROW; END CATCH;
```

