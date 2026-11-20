---
skill_format_version: "1.0.0"
name: "monitor.VW_ModuleStatusCatalog"
schema_name: "monitor"
object_name: "VW_ModuleStatusCatalog"
object_type: "VIEW"
database_role: "framework"
is_internal: false
description: "Liefert den statischen Katalog der Framework-Statuscodes."
source_path: "Code/01_Common/010_VW_ModuleStatusCatalog.sql"
---

# monitor.VW_ModuleStatusCatalog

## Zweck und Einsatz

Liefert den statischen Katalog der Framework-Statuscodes.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[VW_ModuleStatusCatalog]. Die View stellt fest definierte Frameworkdaten bereit und liest keine DMVs, fremden Kataloge oder Anwendungsdaten; aus einer Katalogzeile folgt keine Berechtigung auf andere Objekte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

`StatusCode` (varchar(40)) identifiziert den Status; `SeverityLevel` (tinyint) enthält die hinterlegte Stufe 0, 1 oder 2. `IsSuccess`, `IsQueryable` und `IsTerminal` (bit) sind unabhängige Katalogeigenschaften, keine aus der Stufe abgeleiteten Flags. `GermanDescription` (nvarchar(200)) und `TechnicalMeaning` (nvarchar(1000)) erklären Status und fachliche Grenze. Die Zeilen stammen aus den VALUES-Literalen der View, nicht aus einer Laufzeitmessung.

## Beispiel

```sql
SELECT [StatusCode], [SeverityLevel], [IsSuccess], [IsQueryable], [IsTerminal], [GermanDescription], [TechnicalMeaning] FROM [monitor].[VW_ModuleStatusCatalog] WITH (NOLOCK) ORDER BY [SeverityLevel], [StatusCode];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Ein SELECT wertet die in der View-Definition benannten konstanten oder gelesenen Quellen aus und persistiert keine Daten. Ein CREATE OR ALTER VIEW ändert nur die View-Definition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.VW_ModuleStatusCatalog
Version      : 1.2.0
Stand        : 2026-07-20
Typ          : View
Zweck        : Liefert den statischen Katalog der Framework-Statuscodes.
Datenquelle  : Die Zeilen und Beschreibungen stammen ausschließlich aus den
               VALUES-Literalen dieser View; Laufzeitstatus werden hier nicht
               ermittelt.
Ausgabe      : StatusCode (varchar(40)) identifiziert den maschinenlesbaren
               Status. SeverityLevel (tinyint) ist die im Katalog hinterlegte
               Stufe: 0 für reguläre beziehungsweise nicht anwendbare Zustände,
               1 für eingeschränkte oder übersprungene Ergebnisse und 2 für
               Fehler-, Verfügbarkeits- oder Abbruchzustände. Diese Zuordnung
               beschreibt nur die vorhandenen Literale.
               IsSuccess, IsQueryable und IsTerminal (bit) sind voneinander
               unabhängige Eigenschaften. IsSuccess kennzeichnet die im
               Katalog erklärte Erfolgswertung, IsQueryable die Abfragbarkeit
               der Quelle und IsTerminal einen abschließenden Zustand. Zum
               Beispiel hat AVAILABLE_DISABLED IsQueryable = 1, aber
               IsSuccess = 0; aus SeverityLevel folgt kein Flag.
               GermanDescription (nvarchar(200)) und TechnicalMeaning
               (nvarchar(1000)) erklären
               Status und fachliche Grenze für Anzeige und Interpretation.
Parameter    : Keine.
Beispiel     : SELECT [StatusCode], [SeverityLevel], [IsSuccess],
                      [IsQueryable], [IsTerminal], [GermanDescription],
                      [TechnicalMeaning]
               FROM [monitor].[VW_ModuleStatusCatalog] WITH (NOLOCK)
               ORDER BY [SeverityLevel], [StatusCode];
Änderungen   : 1.2.0 - Datenbank-, High-Impact-, Childstatus- und TABLE-
                         Preflightstatus des Ausgabe-Vertrags 2.0 ergänzt.
               1.1.0 - Plattform-, Messkontext- und Resetstatus ergänzt.
```

