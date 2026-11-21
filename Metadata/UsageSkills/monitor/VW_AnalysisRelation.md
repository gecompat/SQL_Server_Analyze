---
skill_format_version: "1.0.0"
name: "monitor.VW_AnalysisRelation"
schema_name: "monitor"
object_name: "VW_AnalysisRelation"
object_type: "VIEW"
database_role: "framework"
is_internal: false
description: "Beschreibt statisch eingetragene fachliche Beziehungen zwischen Procedures als mögliche Navigationshinweise."
source_path: "Code/01_Common/023_VW_AnalysisRelation.sql"
---

# monitor.VW_AnalysisRelation

## Zweck und Einsatz

Beschreibt statisch eingetragene fachliche Beziehungen zwischen Procedures als mögliche Navigationshinweise. Die View nimmt keine Parameter an und führt keine Procedure aus.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[VW_AnalysisRelation]. Die View stellt fest definierte Frameworkdaten bereit und liest keine DMVs, fremden Kataloge oder Anwendungsdaten; aus einer Katalogzeile folgt keine Berechtigung auf andere Objekte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

Die View projiziert die Spalten der folgenden gebundenen Definition:

```sql
CREATE OR ALTER VIEW [monitor].[VW_AnalysisRelation]
AS
    SELECT
          CONVERT(sysname, [v].[FromProcedureName]) AS [FromProcedureName]
        , CONVERT(varchar(24), [v].[RelationType]) AS [RelationType]
        , CONVERT(sysname, [v].[ToProcedureName]) AS [ToProcedureName]
        , CONVERT(tinyint, [v].[RelationPriority]) AS [RelationPriority]
        , CONVERT(nvarchar(700), [v].[ConditionSummary]) AS [ConditionSummary]
    FROM
    (
        VALUES
          (N'USP_CheckAnalyseAccess','CONFIRM_WITH',N'USP_CheckFrameworkCapabilities',1,N'Wenn eine Analyseklasse nicht freigegeben ist, zusätzlich Version, Berechtigungen, Featurefähigkeit und Policygrenze prüfen.')
        , (N'USP_CheckFrameworkCapabilities','CONFIRM_WITH',N'USP_CheckAnalyseAccess',1,N'Bei einer Policy- oder Gruppenabweichung den effektiven Sicherheitskontext und die Analyseklasse separat prüfen.')

        , (N'USP_CurrentSessions','REFINE_WITH',N'USP_CurrentRequests',1,N'Aktive oder auffällige Sessions auf laufende Requests, Waits und Ressourcenverbrauch eingrenzen.')
        , (N'USP_CurrentSessions','CONFIRM_WITH',N'USP_CurrentTransactions',1,N'Offene Transaktionen unabhängig vom aktuellen Requestzustand gegenprüfen.')
        , (N'USP_CurrentRequests','REFINE_WITH',N'USP_CurrentBlocking',1,N'Bei blockierten Requests die vollständige Blocking-Kette und den Head Blocker bestimmen.')
        , (N'USP_CurrentRequests','REFINE_WITH',N'USP_CurrentMemoryGrants',2,N'Bei Grant-Waits, großen Grants oder Spillverdacht die Memory-Grant-Sicht vertiefen.')
        , (N'USP_CurrentRequests','CONFIRM_WITH',N'USP_QueryStats',1,N'Ein Live-Signal gegen kumulierte Query- und Plan-Cache-Evidenz abgleichen.')
        , (N'USP_CurrentBlocking','REFINE_WITH',N'USP_CurrentTransactions',1,N'Head Blocker und offene Transaktionen samt Alter und Logbezug untersuchen.')
        , (N'USP_CurrentBlocking','CONFIRM_WITH',N'USP_ExtendedEventsBlockedProcesses',1,N'Für wiederkehrendes oder vergangenes Blocking eine zeitliche XE-Evidenz gegenprüfen.')
        , (N'USP_CurrentWaits','REFINE_WITH',N'USP_CurrentRequests',1,N'Instanzweite Wait-Signale auf aktuell verursachende Requests eingrenzen.')
        , (N'USP_CurrentWaits','CONFIRM_WITH',N'USP_PerformanceCounters',1,N'Waitverteilung mit begrenzten Performance-Counter-Deltas gegenprüfen.')
        , (N'USP_CurrentTransactions','REFINE_WITH',N'USP_CurrentBlocking',1,N'Bei wartenden oder lange offenen Transaktionen die Blocking-Beziehung bestimmen.')
        , (N'USP_CurrentTransactions','CONFIRM_WITH',N'USP_CurrentLog',1,N'Alter und Logverbrauch der Transaktionen mit dem aktuellen Logzustand abgleichen.')
        , (N'USP_CurrentMemoryGrants','REFINE_WITH',N'USP_ShowplanAnalysis',1,N'Bei bekanntem Plan Spill-, Sort-, Join- und Grantursachen im Showplan vertiefen.')
        , (N'USP_CurrentMemoryGrants','CONFIRM_WITH',N'USP_ServerMemory',1,N'Aktuelle Grants gegen Server-Memory-Konfiguration und Pressure-Evidenz prüfen.')
        , (N'USP_CurrentTempDB','REFINE_WITH',N'USP_CurrentRequests',1,N'Session- oder Taskverbrauch auf den verursachenden aktuellen Request zurückführen.')
        , (N'USP_CurrentTempDB','CONFIRM_WITH',N'USP_TempDBConfiguration',1,N'Aktuellen Verbrauch unabhängig gegen Dateilayout, Wachstum und Konfiguration prüfen.')
        , (N'USP_CurrentIO','REFINE_WITH',N'USP_CurrentRequests',1,N'Aktuelle I/O-Wartezeit mit den gegenwärtig laufenden Requests korrelieren.')
        , (N'USP_CurrentIO','CONFIRM_WITH',N'USP_PerformanceCounters',1,N'Datei- und Volume-Sicht mit einem kurzen Counter-Delta gegenprüfen.')
        , (N'USP_CurrentLog','REFINE_WITH',N'USP_CurrentTransactions',1,N'Log-Reuse-Blocker und aktive Transaktionen gemeinsam untersuchen.')
        , (N'USP_CurrentLog','CONFIRM_WITH',N'USP_BackupRecovery',1,N'Logzustand mit Recovery-Modell, Logbackup-Frische und Backupkette abgleichen.')
        , (N'USP_CurrentOverview','REFINE_WITH',N'USP_CurrentRequests',1,N'Auffällige aktive Requests aus der Übersicht gezielt vertiefen.')
        , (N'USP_CurrentOverview','REFINE_WITH',N'USP_CurrentBlocking',2,N'Bei Warteschlangen oder Blockern die Blocking-Kette separat ausgeben.')
        , (N'USP_CurrentOverview','CONFIRM_WITH',N'USP_DiagnosticFindings',1,N'Live-Snapshot durch priorisierte Betriebs-, Kapazitäts- und Konfigurationsbefunde ergänzen.')

        , (N'USP_ObjectInventory','REFINE_WITH',N'USP_ObjectAnalysis',1,N'Auffällige Objektgrößen oder Strukturen im konsolidierten Objektpfad vertiefen.')
        , (N'USP_IndexUsage','REFINE_WITH',N'USP_IndexOperationalStats',1,N'Bei auffälliger Nutzung die operative Indexbelastung und Latch-/Lockaktivität ergänzen.')
        , (N'USP_IndexUsage','CONFIRM_WITH',N'USP_QueryStats',1,N'Indexnutzung mit der tatsächlichen Query- und Plannutzung gegenprüfen.')
        , (N'USP_IndexOperationalStats','CONFIRM_WITH',N'USP_IndexPhysicalStats',1,N'Operative Belastung unabhängig von physischer Fragmentierung und Seitendichte prüfen.')
        , (N'USP_MissingIndexes','CONFIRM_WITH',N'USP_IndexUsage',1,N'Fehlindexhinweise gegen bestehende Indizes und deren reale Nutzung validieren.')
        , (N'USP_MissingIndexes','REFINE_WITH',N'USP_QueryStats',1,N'Kandidaten auf konkrete teure Query- und Planmuster zurückführen.')
        , (N'USP_Statistics','REFINE_WITH',N'USP_StatisticsDistributionAnalysis',1,N'Bei Skew- oder Kardinalitätsverdacht ausgewählte Histogramme gezielt untersuchen.')
        , (N'USP_Statistics','CONFIRM_WITH',N'USP_ShowplanAnalysis',1,N'Statistikstatus mit Estimate-/Actual-Abweichungen eines bekannten Plans abgleichen.')
        , (N'USP_StatisticsDistributionAnalysis','CONFIRM_WITH',N'USP_ShowplanAnalysis',1,N'Histogrammverteilung gegen die im Plan sichtbare Kardinalitätsschätzung prüfen.')
        , (N'USP_Partitions','CONFIRM_WITH',N'USP_IndexPhysicalStats',1,N'Partitionsgrößen und -grenzen mit physischem Indexzustand je Partition abgleichen.')
        , (N'USP_Columnstore','CONFIRM_WITH',N'USP_IndexOperationalStats',1,N'Rowgroupzustand mit operativer Änderungs- und Leseaktivität gegenprüfen.')
        , (N'USP_IndexPhysicalStats','CONFIRM_WITH',N'USP_IndexUsage',1,N'Physische Auffälligkeiten nur zusammen mit Nutzung und Workloadrelevanz bewerten.')
        , (N'USP_ObjectAnalysis','REFINE_WITH',N'USP_IndexUsage',1,N'Indexbezogene Signale auf Nutzung und Änderungsaktivität eingrenzen.')
        , (N'USP_ObjectAnalysis','REFINE_WITH',N'USP_Statistics',2,N'Statistiksignale auf Alter, Modifikationen und ausgewählte Obje
```


## Beispiel

```sql
WITH (NOLOCK)
               garantiert keine transaktionskonsistente Sicht.
===============================================================================
SELECT [FromProcedureName], [RelationType], [ToProcedureName],
       [RelationPriority], [ConditionSummary]
FROM [monitor].[VW_AnalysisRelation] WITH (NOLOCK)
ORDER BY [FromProcedureName], [RelationType], [RelationPriority],
         [ToProcedureName];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Ein SELECT wertet die in der View-Definition benannten konstanten oder gelesenen Quellen aus und persistiert keine Daten. Ein CREATE OR ALTER VIEW ändert nur die View-Definition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.VW_AnalysisRelation
Version      : 1.2.0
Stand        : 2026-10-13
Typ          : View
Zweck        : Beschreibt statisch eingetragene fachliche Beziehungen zwischen
               Procedures als mögliche Navigationshinweise. Die View nimmt
               keine Parameter an und führt keine Procedure aus.
Quelle       : Die Zeilen stammen aus den VALUES-Einträgen im View-Text. Sie
               belegen weder die Verfügbarkeit der genannten Procedures noch
               die Erfüllung einer Voraussetzung oder Bedingung.
Spalten      : FromProcedureName und ToProcedureName (jeweils sysname)
               bezeichnen Ausgangs- und Ziel-Procedure.
               RelationType (varchar(24)) benennt die eingetragene Beziehung:
               REFINE_WITH vertieft ein vorhandenes Signal,
               CONFIRM_WITH ergänzt eine Gegenprobe,
               ALTERNATIVE_TO verweist auf einen anderen Evidenzpfad und
               PREPARE_WITH bezeichnet eine mögliche Vorbereitung.
               RelationPriority (tinyint) ordnet Einträge je Ausgangs-
               Procedure und RelationType; sie erzwingt weder eine
               Ausführungsreihenfolge noch eine Auswahl.
               ConditionSummary (nvarchar(700)) enthält erläuternden Text.
               Dieser Text wird nicht als Bedingung ausgewertet.
               Die View erzwingt keine Beziehungen und prüft keine
               Voraussetzungen, Gates oder Laufzeitresultate.
Beispiel     : Die Abfrage zeigt eingetragene Beziehungen geordnet nach
               Ausgangs-Procedure, Beziehungstyp und Priorität. WITH (NOLOCK)
               garantiert keine transaktionskonsistente Sicht.
===============================================================================
SELECT [FromProcedureName], [RelationType], [ToProcedureName],
       [RelationPriority], [ConditionSummary]
FROM [monitor].[VW_AnalysisRelation] WITH (NOLOCK)
ORDER BY [FromProcedureName], [RelationType], [RelationPriority],
         [ToProcedureName];
```

