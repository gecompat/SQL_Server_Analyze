---
skill_format_version: "1.0.0"
name: "monitor.VW_AnalyseClassCatalog"
schema_name: "monitor"
object_name: "VW_AnalyseClassCatalog"
object_type: "VIEW"
database_role: "framework"
is_internal: false
description: "Liefert den statischen Katalog der Analyseklassen mit Einordnung und hinterlegten Standardhinweisen."
source_path: "Code/01_Common/020_VW_AnalyseClassCatalog.sql"
---

# monitor.VW_AnalyseClassCatalog

## Zweck und Einsatz

Liefert den statischen Katalog der Analyseklassen mit Einordnung und hinterlegten Standardhinweisen.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[VW_AnalyseClassCatalog]. Die View stellt fest definierte Frameworkdaten bereit und liest keine DMVs, fremden Kataloge oder Anwendungsdaten; aus einer Katalogzeile folgt keine Berechtigung auf andere Objekte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

AnalysisClass (varchar(64)) ist die Kennung der Klasse. AnalysisLevel (varchar(16)) benennt die eingetragene Stufe, zum Beispiel STANDARD, ERWEITERT, DEEP oder FORENSIK. RequiresGroupGate (bit) zeigt den im Katalog hinterlegten Hinweis, ob für die Klasse eine Gruppenprüfung vorgesehen ist; das Feld prüft keine Gruppenmitgliedschaft und erzwingt keine Freigabe. DefaultMaxRows und DefaultTimeoutSeconds (int) sind Klassenhinweise auf Standardwerte für Zeilen und Zeit. Sie begrenzen eine Abfrage durch diese View nicht. Description (nvarchar(1000)) beschreibt den vorgesehenen Analyseumfang und dessen im Literal genannte Grenzen.


## Beispiel

```sql
SELECT [AnalysisClass], [AnalysisLevel], [RequiresGroupGate], [DefaultMaxRows], [DefaultTimeoutSeconds], [Description] FROM [monitor].[VW_AnalyseClassCatalog] WITH (NOLOCK) ORDER BY [AnalysisLevel], [AnalysisClass];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Diese Katalog-View führt keine Analyse aus, prüft oder erzwingt kein AD-Gruppengate und gewährt keine Berechtigung. Sie setzt weder Zeilen- noch Zeitlimits durch. Diese Wirkungen liegen außerhalb ihrer VALUES-Ausgabe.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.VW_AnalyseClassCatalog
Version      : 1.9.0
Stand        : 2026-07-22
Typ          : View
Zweck        : Liefert den statischen Katalog der Analyseklassen mit
               Einordnung und hinterlegten Standardhinweisen.
Datenquelle  : Die Klassen, Werte und Beschreibungen stammen ausschließlich
               aus den VALUES-Literalen dieser View. Die View wertet weder
               AD-Gruppenmitgliedschaften noch eine Zugriffspolicy aus.
Ausgabe      : AnalysisClass (varchar(64)) ist die Kennung der Klasse.
               AnalysisLevel (varchar(16)) benennt die eingetragene Stufe,
               zum Beispiel STANDARD, ERWEITERT, DEEP oder FORENSIK.
               RequiresGroupGate (bit) zeigt den im Katalog hinterlegten
               Hinweis, ob für die Klasse eine Gruppenprüfung vorgesehen ist;
               das Feld prüft keine Gruppenmitgliedschaft und erzwingt keine
               Freigabe.
               DefaultMaxRows und DefaultTimeoutSeconds (int) sind
               Klassenhinweise auf Standardwerte für Zeilen und Zeit.
               Sie begrenzen eine Abfrage durch diese View nicht.
               Description (nvarchar(1000)) beschreibt den vorgesehenen
               Analyseumfang und dessen im Literal genannte Grenzen.
Parameter    : Keine.
Berechtigung : Der Aufrufende benötigt SELECT auf der View. Die View selbst
               wertet keine Zugriffsrechte aus und vergibt keine Rechte.
Grenzen      : Diese Katalog-View führt keine Analyse aus, prüft oder erzwingt
               kein AD-Gruppengate und gewährt keine Berechtigung. Sie setzt
               weder Zeilen- noch Zeitlimits durch. Diese Wirkungen liegen
               außerhalb ihrer VALUES-Ausgabe.
Beispiel     : SELECT [AnalysisClass], [AnalysisLevel], [RequiresGroupGate],
                      [DefaultMaxRows], [DefaultTimeoutSeconds],
                      [Description]
               FROM [monitor].[VW_AnalyseClassCatalog] WITH (NOLOCK)
               ORDER BY [AnalysisLevel], [AnalysisClass];
Änderungen   : 1.9.0 - EXTERNAL_RUNTIME_CURRENT und CLR_CURRENT ergänzt.
               1.8.0 - SERVER_HEALTH_CURRENT, SERVER_CONFIGURATION_CURRENT und SECURITY_CONFIGURATION_CURRENT ergänzt.
               1.7.0 - SQL_AGENT_CURRENT, RESOURCE_GOVERNOR_CURRENT, HA_DR_CURRENT und ENTERPRISE_TOPOLOGY_DEEP ergänzt.
               1.6.0 - EXTENDED_EVENTS_CURRENT für leichte reine Sessioninventarisierung ergänzt.
               1.5.0 - QUERY_STORE_CURRENT für gezielte lesende Query-Store-Analysen ergänzt.
               1.4.0 - PLAN_CACHE_CURRENT und SHOWPLAN_TARGETED ergänzt.
               1.3.0 - INDEX_OPERATIONAL_DEEP ergänzt.
               1.2.0 - Zielgerichtete Phase-2-Analyseklassen ergänzt.
               1.1.0 - LOCKS_DEEP und LOG_VLF_DEEP ergänzt.
               1.0.0 - Erstfassung Phase 1A.
```

