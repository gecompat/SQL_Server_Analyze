---
skill_format_version: "1.0.0"
name: "monitor.TVF_WaitTypeInfo"
schema_name: "monitor"
object_name: "TVF_WaitTypeInfo"
object_type: "FUNCTION"
database_role: "framework"
is_internal: false
description: "Ordnet einen Wait Type dem persistenten Wait-Katalog zu und liefert"
source_path: "Code/01_Common/075_TVF_WaitTypeInfo.sql"
---

# monitor.TVF_WaitTypeInfo

## Zweck und Einsatz

Ordnet einen Wait Type dem persistenten Wait-Katalog zu und liefert

## Voraussetzungen und Rechte

Der Aufruf braucht SELECT auf [monitor].[TVF_WaitTypeInfo] im vorgesehenen Datenbankkontext. Die Funktion liest die Frameworktabellen `WaitTypeCatalog` und `WaitTypeCatalogSource`; sie erfasst keine Live-Waits.

## Parameter und Eingabe

„SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.

| Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
| --- | --- | --- | --- |
| @WaitType | nvarchar(120) | ja | kein Default |

**@WaitType:** Pflichtwert nvarchar(120), kein Default. Ein einzelner Wait-Type-Schlüssel, keine Patternsuche; Datenbankcollation gilt. NULL bezeichnet KEIN_WAIT und führt zum Regel-Fallback. Ein exakter Katalogtreffer hat Vorrang vor Familienregeln; ein unbekannter Schlüssel kann OTHER_OR_NEW ergeben.

## Resultate und Ausgabe

WaitType, WaitGroup, Severity und IsGenerallyBenign beschreiben die Taxonomie. Meaning, TypicalOccurrence, HighWaitImpact und RecommendedChecks enthalten allgemeine Hinweise. DefaultAssessment, AssessmentBasis, CommonCauses, PerformanceImpact, Mitigation, CounterEvidence, RelatedWaitTypes, MeasurementGuidance und AnalysisConfidence liefern die zugehörigen Analysefelder. HelpUrl, DescriptionSource, DescriptionQuality und SourceReference kennzeichnen Beschreibung und Herkunft; SourceCount zählt passende Quellzeilen. InterpretationScope und CatalogMatchType grenzen den Treffer ein. [monitor].[WaitTypeCatalog]. Der Fallback wird aus dem Wait-Type-Text abgeleitet und kann nur allgemeine Gruppenhinweise liefern. Ein Katalogtreffer ist keine Messung. Die NOLOCK-Lesevorgänge können uncommittierte oder inkonsistente Zwischenstände sehen; SourceCount ist daher ebenfalls nur ein momentaner Kataloghinweis. Für eine Leistungsbewertung sind aktive Tasks, Ressource, zeitliches Delta und Workloadwirkung separat zu prüfen. Die Funktion führt keine Messung, externe Abfrage oder Netzwerkabruf aus; HelpUrl ist nur ein Wert.


## Beispiel

```sql
SELECT * FROM [monitor].[TVF_WaitTypeInfo](N'LCK_M_S');
SELECT * FROM [monitor].[TVF_WaitTypeInfo](NULL);
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
