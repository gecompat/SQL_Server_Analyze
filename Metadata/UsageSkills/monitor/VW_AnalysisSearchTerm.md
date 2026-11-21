---
skill_format_version: "1.0.0"
name: "monitor.VW_AnalysisSearchTerm"
schema_name: "monitor"
object_name: "VW_AnalysisSearchTerm"
object_type: "VIEW"
database_role: "framework"
is_internal: false
description: "Liefert statisch eingetragene deutsch- und englischsprachige Suchbegriffe für den Analysis Navigator."
source_path: "Code/01_Common/022_VW_AnalysisSearchTerm.sql"
---

# monitor.VW_AnalysisSearchTerm

## Zweck und Einsatz

Liefert statisch eingetragene deutsch- und englischsprachige Suchbegriffe für den Analysis Navigator. Die View nimmt keine Parameter an und führt keine Suche oder Rangberechnung aus.

## Voraussetzungen und Rechte

Der lesende Aufruf braucht SELECT auf [monitor].[VW_AnalysisSearchTerm]. Die View stellt fest definierte Frameworkdaten bereit und liest keine DMVs, fremden Kataloge oder Anwendungsdaten; aus einer Katalogzeile folgt keine Berechtigung auf andere Objekte.

## Parameter und Eingabe

Keine Aufrufparameter.

## Resultate und Ausgabe

Die View projiziert die Spalten der folgenden gebundenen Definition:

```sql
CREATE OR ALTER VIEW [monitor].[VW_AnalysisSearchTerm]
AS
    SELECT
          CONVERT(sysname, [v].[ProcedureName]) AS [ProcedureName]
        , CONVERT(nvarchar(200), [v].[SearchTerm]) AS [SearchTerm]
        , CONVERT(char(2), [v].[LanguageCode]) AS [LanguageCode]
        , CONVERT(tinyint, [v].[SearchWeight]) AS [SearchWeight]
        , CONVERT(nvarchar(500), [v].[MatchReason]) AS [MatchReason]
    FROM
    (
        VALUES
          (N'USP_AnalysisNavigator',N'welche Analyse verwenden','de',100,N'Der Navigator beantwortet die Auswahlfrage, ohne eine Diagnose zu starten.')
        , (N'USP_AnalysisNavigator',N'find analysis','en',100,N'Direkter Einstieg in die symptom- und zielorientierte Suche.')
        , (N'USP_CheckAnalyseAccess',N'Analyse nicht freigegeben','de',100,N'Prüft die interne Ressourcenfreigabe des aktuellen Sicherheitskontexts.')
        , (N'USP_CheckAnalyseAccess',N'access denied analysis class','en',95,N'Zeigt Gruppenmatch und Analyseklassenpolicy.')
        , (N'USP_CheckFrameworkCapabilities',N'fehlende Berechtigung oder Feature','de',100,N'Prüft Version, Rechte, Policy und Featurefähigkeit gemeinsam.')
        , (N'USP_CheckFrameworkCapabilities',N'capability permission feature unavailable','en',95,N'Geeignet zur Erklärung nicht verfügbarer Diagnosepfade.')
        , (N'USP_PrepareDatabaseCandidates',N'Datenbankauswahlvertrag','de',90,N'Interner Vertrag für die konsistente Datenbankauswahl.')
        , (N'USP_PrepareDatabaseCandidates',N'database candidate selection','en',85,N'Unterstützender Datenbankscope-Baustein.')
        , (N'USP_PrepareNameFilters',N'Namensfiltervertrag','de',90,N'Interner Vertrag für exakte und Pattern-basierte Namensfilter.')
        , (N'USP_PrepareNameFilters',N'name filter parser','en',85,N'Unterstützender Filterbaustein.')

        , (N'USP_CurrentSessions',N'aktive Sessions Verbindungen','de',90,N'Inventarisiert aktuelle Sessions und Verbindungen.')
        , (N'USP_CurrentSessions',N'current sessions connections','en',85,N'Geeignet für Session- und Verbindungskontext.')
        , (N'USP_CurrentRequests',N'CPU hoch','de',100,N'Zeigt aktuell CPU-intensive Requests und ihren Laufzeitkontext.')
        , (N'USP_CurrentRequests',N'langsame Query jetzt','de',100,N'Geeignet, wenn die Query im Moment noch läuft.')
        , (N'USP_CurrentRequests',N'high CPU active request slow query','en',95,N'Korrelierte Live-Sicht auf aktive Requests.')
        , (N'USP_CurrentBlocking',N'Benutzer warten','de',100,N'Prüft aktuelle Blockingketten und den Root Blocker.')
        , (N'USP_CurrentBlocking',N'Hänger Blocking Sperre','de',100,N'Direkter Live-Einstieg bei blockierten Benutzern.')
        , (N'USP_CurrentBlocking',N'blocking root blocker lock chain','en',95,N'Rekonstruiert aktuelle Blocking Chains.')
        , (N'USP_CurrentWaits',N'aktuelle Waits Wartezeiten','de',95,N'Ordnet aktuelle und gesampelte Waits fachlich ein.')
        , (N'USP_CurrentWaits',N'current waits wait statistics','en',90,N'Wait-Snapshot und optionales Delta.')
        , (N'USP_CurrentTransactions',N'alte offene Transaktion','de',100,N'Findet lange oder vergessene offene Transaktionen.')
        , (N'USP_CurrentTransactions',N'old open transaction sleeping session','en',95,N'Korrelierter Transaktions- und Sessionkontext.')
        , (N'USP_CurrentMemoryGrants',N'Memory Grants warten','de',100,N'Zeigt wartende Query Memory Grants.')
        , (N'USP_CurrentMemoryGrants',N'Benutzer warten Speicher','de',75,N'Kann bei RESOURCE_SEMAPHORE-Warteschlangen relevant sein.')
        , (N'USP_CurrentMemoryGrants',N'memory grant queue resource semaphore','en',95,N'Korrelierte Grant- und Waitsicht.')
        , (N'USP_CurrentTempDB',N'TempDB wächst','de',100,N'Zeigt aktuellen TempDB-Verbrauch nach Ursache und Session.')
        , (N'USP_CurrentTempDB',N'TempDB voll Version Store','de',95,N'Trennt User Objects, Internal Objects und Version Store.')
        , (N'USP_CurrentTempDB',N'tempdb growth space usage','en',95,N'Aktueller TempDB-Verbrauch.')
        , (N'USP_CurrentTempDB',N'TempDB Workload Group Limit Verletzung','de',100,N'Trennt wirksames Limit, Nutzung, Peak und kumulative Verletzungen.')
        , (N'USP_CurrentTempDB',N'tempdb resource governance limit violation','en',100,N'SQL-Server-2025-Workload-Group-Governance im TempDB-Kontext.')
        , (N'USP_CurrentIO',N'I/O Latenz hoch','de',100,N'Bewertet aktuelle Datei-I/O-Latenz und Pending I/O.')
        , (N'USP_CurrentIO',N'langsame Datendatei Storage','de',90,N'Korrelierte Datei- und Sampleevidenz.')
        , (N'USP_CurrentIO',N'io latency slow storage pending io','en',95,N'Kumulative und gesampelte I/O-Sicht.')
        , (N'USP_CurrentLog',N'Log voll','de',100,N'Zeigt Logauslastung und Wiederverwendungswartegrund.')
        , (N'USP_CurrentLog',N'Transaktionslog wächst','de',100,N'Verknüpft Logverbrauch, Reuse Wait und VLF-Kontext.')
        , (N'USP_CurrentLog',N'transaction log full log reuse wait','en',95,N'Aktueller Log- und Wiederverwendungskontext.')
        , (N'USP_CurrentOverview',N'etwas ist jetzt langsam','de',100,N'Orchestrierter leichter Live-Einstieg bei unklarem aktuellem Symptom.')
        , (N'USP_CurrentOverview',N'Server hängt aktuell','de',95,N'Bündelt mehrere aktuelle Triagequellen.')
        , (N'USP_CurrentOverview',N'live triage current overview','en',95,N'Sicherer allgemeiner Live-Einstieg.')

        , (N'USP_ObjectInventory',N'Objekte Größe Indizes inventarisieren','de',95,N'Liefert Objekt-, Index-, Größen- und Partitionsinventar.')
        , (N'USP_ObjectInventory',N'object inventory index size','en',90,N'Gezielte Objektinventur.')
        , (N'USP_ObjectInventory',N'JSON-Index Pfade inventarisieren','de',100,N'Liefert sichtbare SQL-Server-2025-JSON-Index- und SQL/JSON-Pfadmetadaten.')
        , (N'USP_ObjectInventory',N'json index paths inventory','en',100,N'Routes visible JSON-index definitions and path metadata to the object inventory.')
        , (N'USP_IndexUsage',N'Index ungenutzt','de',100,N'Zeigt kumulative Lese- und Schreibnutzung seit Reset.')
        , (N'USP_IndexUsage',N'unused index usage statistics','en',95,N'Prüft Indexnutzung mit Resetgrenzen.')
        , (N'USP_IndexOperationalStats',N'Index Locks Latches Page Splits','de',100,N'Zeigt operative Indexzähler je Partition.')
        , (N'USP_IndexOperationalStats',N'index operational stats latch lock','en',95,N'Vertiefung für operative Indexaktivität.')
        , (N'USP_MissingIndexes',N'fehlender Index','de',100,N'Prio
```


## Beispiel

```sql
WITH (NOLOCK) garantiert keine
               transaktionskonsistente Sicht.
===============================================================================
SELECT [ProcedureName], [SearchTerm], [LanguageCode], [SearchWeight],
       [MatchReason]
FROM [monitor].[VW_AnalysisSearchTerm] WITH (NOLOCK)
ORDER BY [ProcedureName], [LanguageCode], [SearchWeight] DESC, [SearchTerm];
```

## Aufwand, Nebenwirkungen, Fehler und Grenzen

Ein SELECT wertet die in der View-Definition benannten konstanten oder gelesenen Quellen aus und persistiert keine Daten. Ein CREATE OR ALTER VIEW ändert nur die View-Definition.

### Quellgebundene Detailbeschreibung

Der folgende Quellkopf bewahrt die zusätzlichen Implementierungsgrenzen für diesen Skill.

```text
Objekt       : monitor.VW_AnalysisSearchTerm
Version      : 1.3.0
Stand        : 2026-10-13
Typ          : View
Zweck        : Liefert statisch eingetragene deutsch- und englischsprachige
               Suchbegriffe für den Analysis Navigator. Die View nimmt keine
               Parameter an und führt keine Suche oder Rangberechnung aus.
Quelle       : Die Zeilen stammen aus den VALUES-Einträgen im View-Text. Sie
               sind keine Laufzeitergebnisse und belegen nicht, dass eine
               referenzierte Procedure installiert, ausführbar oder für den
               aktuellen Aufrufer berechtigt ist.
Spalten      : ProcedureName (sysname) bezeichnet die zugeordnete Procedure.
               SearchTerm (nvarchar(200)) enthält einen Begriff, ein Symptom,
               Ziel, Synonym oder technischen Suchtext.
               LanguageCode (char(2)) kennzeichnet die Sprache des Eintrags;
               de und en sind eingetragene Sprachcodes. Daraus folgt keine
               Übersetzung oder automatische Spracherkennung.
               SearchWeight (tinyint) ist ein statisches Gewicht für eine
               mögliche spätere Priorisierung, kein berechneter Trefferwert.
               MatchReason (nvarchar(500)) erläutert den fachlichen Bezug des
               Begriffs. Mehrere Begriffe je Procedure sind vorgesehen.
               Die View bewertet weder Suchanfragen noch erzeugt sie Treffer.
Beispiel     : Die Abfrage zeigt die eingetragenen Begriffe in einer
               nachvollziehbaren Reihenfolge. WITH (NOLOCK) garantiert keine
               transaktionskonsistente Sicht.
===============================================================================
SELECT [ProcedureName], [SearchTerm], [LanguageCode], [SearchWeight],
       [MatchReason]
FROM [monitor].[VW_AnalysisSearchTerm] WITH (NOLOCK)
ORDER BY [ProcedureName], [LanguageCode], [SearchWeight] DESC, [SearchTerm];
```

