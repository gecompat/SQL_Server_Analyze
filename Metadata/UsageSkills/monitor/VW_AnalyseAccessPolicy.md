---
skill_format_version: "1.0.0"
name: "monitor.VW_AnalyseAccessPolicy"
schema_name: "monitor"
object_name: "VW_AnalyseAccessPolicy"
object_type: "VIEW"
database_role: "framework"
is_internal: false
description: "Stellt die rein lesende Policyquelle für Analyseklassen und zugeordnete Windows-Gruppen bereit."
source_path: "Code/01_Common/030_VW_AnalyseAccessPolicy.sql"
---

# monitor.VW_AnalyseAccessPolicy

## Zweck und Einsatz

Stellt die rein lesende Policyquelle für Analyseklassen und zugeordnete Windows-Gruppen bereit. Die ausgelieferte View gibt wegen WHERE 1 = 0 keine Zeilen zurück; ihre sieben Ausgabespalten behalten dabei die unten angegebenen Typen.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[VW_AnalyseAccessPolicy]. Die View stellt fest definierte Frameworkdaten bereit und liest keine DMVs, fremden Kataloge oder Anwendungsdaten; aus einer Katalogzeile folgt keine Berechtigung auf andere Objekte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

AnalysisClass (varchar(64)), ADGroupName (nvarchar(256)), IsEnabled (bit), ValidFromUtc und ValidToUtc (datetime2(0)), Priority (smallint) sowie Comment (nvarchar(1000)).


## Beispiel

```sql
SELECT [AnalysisClass], [ADGroupName], [IsEnabled], [ValidFromUtc], [ValidToUtc], [Priority], [Comment] FROM [monitor].[VW_AnalyseAccessPolicy] WITH (NOLOCK) ORDER BY [AnalysisClass], [Priority], [ADGroupName];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Die View prüft keine Gruppenmitgliedschaft und führt keine Analyse aus. Das Framework nimmt hier keine GRANT-, DENY- oder REVOKE-Änderung vor.


### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.VW_AnalyseAccessPolicy
Version      : 1.0.0
Stand        : 2026-07-14
Typ          : View
Zweck        : Stellt die rein lesende Policyquelle für Analyseklassen und
               zugeordnete Windows-Gruppen bereit. Die ausgelieferte View gibt
               wegen WHERE 1 = 0 keine Zeilen zurück; ihre sieben Ausgabespalten
               behalten dabei die unten angegebenen Typen.
Parameter    : Keine.
Ausgabe      : AnalysisClass (varchar(64)), ADGroupName (nvarchar(256)),
               IsEnabled (bit), ValidFromUtc und ValidToUtc (datetime2(0)),
               Priority (smallint) sowie Comment (nvarchar(1000)).
Verwendung   : Eine spätere, manuell gepflegte Policy-View kann diese Spalten
               mit Gruppenregeln befüllen. Die kommentierte VALUES-Vorlage am
               Dateiende wird nicht ausgeführt und ändert die ausgelieferte
               leere View nicht. Priority wird vom Verbraucher mitgeführt,
               steuert derzeit aber weder Auswahlreihenfolge noch Freigabe.
Wirkung      : VW_AnalyseAccessCurrent wertet aktive Policyzeilen aus. Sind
               keine aktiven Zeilen vorhanden, ist die Gruppenprüfung offen;
               sind welche vorhanden, können geschützte Klassen ohne passende
               spezifische oder globale Regel gesperrt sein. Eine Regel mit
               AnalysisClass='*' gilt für alle geschützten Klassen. Diese
               Policyquelle vergibt selbst keine SQL-Berechtigungen.
Grenzen      : Die View prüft keine Gruppenmitgliedschaft und führt keine
               Analyse aus. Das Framework nimmt hier keine GRANT-, DENY- oder
               REVOKE-Änderung vor.
Beispiel     : SELECT [AnalysisClass], [ADGroupName], [IsEnabled],
                      [ValidFromUtc], [ValidToUtc], [Priority], [Comment]
               FROM [monitor].[VW_AnalyseAccessPolicy] WITH (NOLOCK)
               ORDER BY [AnalysisClass], [Priority], [ADGroupName];
Änderungen   : 1.0.0 - Erstfassung Phase 1A.
```

