---
skill_format_version: "1.0.0"
name: "monitor.VW_AnalysisCatalog"
schema_name: "monitor"
object_name: "VW_AnalysisCatalog"
object_type: "VIEW"
database_role: "framework"
is_internal: false
description: "Stellt fest eingetragene Navigationsmetadaten für öffentliche Framework-Procedures bereit."
source_path: "Code/01_Common/021_VW_AnalysisCatalog.sql"
---

# monitor.VW_AnalysisCatalog

## Zweck und Einsatz

Stellt fest eingetragene Navigationsmetadaten für öffentliche Framework-Procedures bereit. Die View nimmt keine Parameter an.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[VW_AnalysisCatalog]. Die View stellt fest definierte Frameworkdaten bereit und liest keine DMVs, fremden Kataloge oder Anwendungsdaten; aus einer Katalogzeile folgt keine Berechtigung auf andere Objekte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

Die View projiziert die Spalten der folgenden gebundenen Definition:

```sql
CREATE OR ALTER VIEW [monitor].[VW_AnalysisCatalog]
AS
    SELECT
          CONVERT(sysname, [v].[ProcedureName]) AS [ProcedureName]
        , CONVERT(nvarchar(160), [v].[DisplayName]) AS [DisplayName]
        , CONVERT(varchar(40), [v].[PrimaryAreaCode]) AS [PrimaryAreaCode]
        , CONVERT(nvarchar(160), [v].[PrimaryAreaName]) AS [PrimaryAreaName]
        , CONVERT(varchar(24), [v].[NavigationRole]) AS [NavigationRole]
        , CONVERT(varchar(40), [v].[ScopeCode]) AS [ScopeCode]
        , CONVERT(varchar(40), [v].[EvidenceType]) AS [EvidenceType]
        , CONVERT(varchar(32), [v].[CostRangeCode]) AS [CostRangeCode]
        , CONVERT(varchar(64), [v].[RepresentativeAnalysisClass]) AS [RepresentativeAnalysisClass]
        , CONVERT(bit, [v].[RequiresKnownTarget]) AS [RequiresKnownTarget]
        , CONVERT(bit, [v].[RequiresHighImpactForSafeStart]) AS [RequiresHighImpactForSafeStart]
        , CONVERT(bit, [v].[HighImpactPathAvailable]) AS [HighImpactPathAvailable]
        , CONVERT(varchar(32), [v].[PackageCode]) AS [PackageCode]
        , CONVERT(smallint, [v].[DefaultRank]) AS [DefaultRank]
        , CONVERT(nvarchar(1000), [v].[Purpose]) AS [Purpose]
        , CONVERT(nvarchar(1000), [v].[PrerequisiteSummary]) AS [PrerequisiteSummary]
        , CONVERT(nvarchar(2000), [v].[SafeCall]) AS [SafeCall]
        , CONVERT(nvarchar(400), [v].[DocumentationPath]) AS [DocumentationPath]
        , CONVERT(nvarchar(400), [v].[RunbookPath]) AS [RunbookPath]
    FROM
    (
        VALUES
          (N'USP_AnalysisNavigator',N'Analyseweg finden','NAVIGATION',N'Einstieg und Orientierung','ENTRY','FRAMEWORK','FRAMEWORK_METADATA','LOW',NULL,0,0,0,'CORE',NULL,N'Findet passende Framework-Procedures nach Symptom, Ziel, Scope oder Fachbegriff, ohne eine Diagnose auszuführen.',N'Keine fachliche Voraussetzung; der Katalog liest ausschließlich statische Frameworkmetadaten.',N'EXEC [monitor].[USP_AnalysisNavigator];',N'Documentation/Analysis_Guides/Procedures/USP_AnalysisNavigator.md',NULL)
        , (N'USP_CheckAnalyseAccess',N'Analysefreigaben prüfen','FRAMEWORK',N'Framework und Zugriff','SETUP','FRAMEWORK','FRAMEWORK_METADATA','LOW',NULL,0,0,0,'CORE',NULL,N'Zeigt die interne Gruppen- und Analyseklassenfreigabe des aktuellen Sicherheitskontexts.',N'Nur für Ressourcenfreigaben; die Ausgabe ersetzt keine SQL-Server-Berechtigungsprüfung.',N'EXEC [monitor].[USP_CheckAnalyseAccess] @ResultSetArt = ''CONSOLE'';',N'Documentation/Analysis_Guides/Procedures/USP_CheckAnalyseAccess.md',NULL)
        , (N'USP_CheckFrameworkCapabilities',N'Framework-Capabilities prüfen','FRAMEWORK',N'Framework und Zugriff','SETUP','FRAMEWORK','FRAMEWORK_METADATA','LOW_MEDIUM',NULL,0,0,0,'CORE',NULL,N'Prüft Version, Policy, Berechtigung, Abfragbarkeit und Featurestatus für Diagnosepfade.',N'Sichtbarkeit und Rechte bestimmen die Vollständigkeit; die Procedure vergibt keine Rechte.',N'EXEC [monitor].[USP_CheckFrameworkCapabilities] @NurNichtVerfuegbar = 1, @ResultSetArt = ''CONSOLE'';',N'Documentation/Analysis_Guides/Procedures/USP_CheckFrameworkCapabilities.md',NULL)
        , (N'USP_PrepareDatabaseCandidates',N'Datenbankauswahl vorbereiten','FRAMEWORK',N'Framework und Zugriff','SUPPORT','FRAMEWORK','FRAMEWORK_METADATA','LOW',NULL,1,0,0,'CORE',NULL,N'Befüllt eine vom Aufrufer bereitgestellte temporäre Kandidatenliste nach dem zentralen Datenbankvertrag.',N'Interner Aufrufvertrag für Framework-Procedures; kein eigenständiger Diagnoseeinstieg.',N'EXEC [monitor].[USP_AnalysisNavigator] @Suchbegriff = N''USP_PrepareDatabaseCandidates'';',N'Documentation/Analysis_Guides/Procedures/USP_PrepareDatabaseCandidates.md',NULL)
        , (N'USP_PrepareNameFilters',N'Namensfilter vorbereiten','FRAMEWORK',N'Framework und Zugriff','SUPPORT','FRAMEWORK','FRAMEWORK_METADATA','LOW',NULL,1,0,0,'CORE',NULL,N'Validiert und zerlegt case-sensitive, bracket-aware Namensfilter für aufrufende Procedures.',N'Interner Aufrufvertrag; der Aufrufer muss die vorgesehenen lokalen Zieltabellen bereitstellen.',N'EXEC [monitor].[USP_AnalysisNavigator] @Suchbegriff = N''USP_PrepareNameFilters'';',N'Documentation/Analysis_Guides/Procedures/USP_PrepareNameFilters.md',NULL)

        , (N'USP_CurrentSessions',N'Aktuelle Sessions','LIVE',N'Akute Störung und laufende Requests','FOLLOW_UP','SESSION_REQUEST','LIVE_SNAPSHOT','LOW_MEDIUM','STANDARD_CURRENT',0,0,0,'CORE',NULL,N'Inventarisiert Sessions, Verbindungskontext, kumulative Aktivität und offene Transaktionen.',N'Flüchtiger Snapshot; Session- und Clientangaben können sich unmittelbar ändern.',N'EXEC [monitor].[USP_CurrentSessions] @MitSqlText = 0, @MaxZeilen = 100, @ResultSetArt = ''CONSOLE'';',N'Documentation/Analysis_Guides/Procedures/USP_CurrentSessions.md',NULL)
        , (N'USP_CurrentRequests',N'Aktive Requests und Ressourcen','LIVE',N'Akute Störung und laufende Requests','ENTRY','SESSION_REQUEST','LIVE_SNAPSHOT','LOW_MEDIUM','STANDARD_CURRENT',0,0,0,'CORE',3,N'Ordnet laufende Requests nach Laufzeit, CPU, I/O, Wait, Blocking, Memory Grant und Ausführungskontext ein.',N'Nur aktuell laufende Requests; für vergangene Regressionen Query Store oder Extended Events verwenden.',N'EXEC [monitor].[USP_CurrentRequests] @MaxZeilen = 50, @MitSqlText = 0, @ResultSetArt = ''CONSOLE'';',N'Documentation/Analysis_Guides/Procedures/USP_CurrentRequests.md',N'Documentation/Analysis_Guides/Runbooks/02_High_CPU.md')
        , (N'USP_CurrentBlocking',N'Aktuelle Blocking-Ketten','LIVE',N'Akute Störung und laufende Requests','ENTRY','SESSION_REQUEST','LIVE_SNAPSHOT','LOW_HIGH_OPT_IN','STANDARD_CURRENT',0,0,1,'CORE',2,N'Rekonstruiert aktuelle Blockingkanten, Root Blocker und bei Bedarf technische Lockressourcen.',N'Blocking muss während des Snapshots noch bestehen; Lockdetails sind ein expliziter High-Impact-Pfad.',N'EXEC [monitor].[USP_CurrentBlocking] @MinWaitMs = 1000, @BlockingObjektTiefe = ''STANDARD'', @ResultSetArt = ''CONSOLE'';',N'Documentation/Analysis_Guides/Procedures/USP_CurrentBlocking.md',N'Documentation/Analysis_Guides/Runbooks/01_User_Hangs_Blocking.md')
        , (N'USP_CurrentWaits',N'Aktuelle und gesampelte Waits','LIVE',N'Akute Störung und laufende Requests','FOLLOW_UP','SERVER','SAMPLE_DELTA','LOW_MEDIUM','STANDARD_CURRENT',0,0,0,'CORE',NULL,N'Zeigt aktuelle Tasks, kumulative Waits und optional ein kurzes Wait-Delta.',N'Waits sind Symptome; Scope, Dauer, Workload und Gegenprobe bestimmen die Interpretation.',N'EXEC [monitor].[USP_CurrentWaits] @SampleSeconds = 5, @MitSqlText = 0, @MaxZeilen = 100, @ResultSetArt =
```


## Beispiel

```sql
WITH (NOLOCK) ist ein Lesehinweis und garantiert keine
               transaktionskonsistente Sicht.
===============================================================================
SELECT [ProcedureName], [DisplayName], [NavigationRole], [CostRangeCode],
       [DefaultRank], [SafeCall]
FROM [monitor].[VW_AnalysisCatalog] WITH (NOLOCK)
ORDER BY [DefaultRank], [ProcedureName];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Ein SELECT wertet die in der View-Definition benannten konstanten oder gelesenen Quellen aus und persistiert keine Daten. Ein CREATE OR ALTER VIEW ändert nur die View-Definition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.VW_AnalysisCatalog
Version      : 1.4.0
Stand        : 2026-10-13
Typ          : View
Zweck        : Stellt fest eingetragene Navigationsmetadaten für öffentliche
               Framework-Procedures bereit. Die View nimmt keine Parameter an.
Quelle       : Die Zeilen stammen aus den statischen VALUES-Einträgen im
               View-Text. Es werden keine DMVs, Benutzerkataloge oder
               produktiven Daten gelesen. Die Metadaten belegen weder, dass
               eine Procedure installiert, ausführbar oder für den aktuellen
               Aufrufer berechtigt ist, noch dass ein angegebener Pfad existiert.
Spalten      : Die Projektion enthält 19 Spalten:
               ProcedureName (sysname) bezeichnet den eingetragenen
               Procedure-Namen; DisplayName (nvarchar(160)) ist seine
               lesbare Bezeichnung.
               PrimaryAreaCode (varchar(40)) und PrimaryAreaName
               (nvarchar(160)) ordnen den Eintrag einem Themenbereich zu.
               NavigationRole (varchar(24)) bezeichnet seine Navigationsrolle;
               ScopeCode (varchar(40)) den dokumentierten Geltungsbereich und
               EvidenceType (varchar(40)) die dokumentierte Evidenzart.
               CostRangeCode (varchar(32)) kennzeichnet die dokumentierte
               Kostenspanne. RepresentativeAnalysisClass
               (varchar(64)) nennt eine repräsentative Analyseklasse, sofern
               eine eingetragen ist; sie beschreibt nicht alle Ausführungspfade.
               RequiresKnownTarget, RequiresHighImpactForSafeStart und
               HighImpactPathAvailable (jeweils bit) sind statische Hinweise
               für die Navigation. Sie prüfen weder Ziel, Berechtigung,
               High-Impact-Freigabe noch konkrete Laufzeitbedingungen.
               PackageCode (varchar(32)) bezeichnet die Paketzuordnung;
               DefaultRank (smallint) einen statischen Sortierhinweis, der
               NULL sein kann und keine eigene Reihenfolge festlegt.
               Purpose (nvarchar(1000)) beschreibt den Zweck,
               PrerequisiteSummary (nvarchar(1000)) fasst dokumentierte
               Voraussetzungen zusammen und SafeCall (nvarchar(2000)) enthält
               einen Beispielaufruf als Text. SafeCall wird nicht ausgeführt,
               ist keine automatische Freigabe und ersetzt keine Prüfung der
               tatsächlichen Procedure-Gates.
               DocumentationPath und RunbookPath (jeweils nvarchar(400))
               enthalten Pfadtexte; sie werden nicht auf Existenz geprüft.
Beispiel     : Die Abfrage liest die View und sortiert ihre statischen Einträge.
               WITH (NOLOCK) ist ein Lesehinweis und garantiert keine
               transaktionskonsistente Sicht.
===============================================================================
SELECT [ProcedureName], [DisplayName], [NavigationRole], [CostRangeCode],
       [DefaultRank], [SafeCall]
FROM [monitor].[VW_AnalysisCatalog] WITH (NOLOCK)
ORDER BY [DefaultRank], [ProcedureName];
```

