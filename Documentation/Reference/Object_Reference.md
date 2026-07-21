# Referenz der unterstützenden Frameworkobjekte

Stand: 2026-07-21

Diese Referenz ergänzt die [Procedure-Referenz](Procedure_Reference.md). Sie
beschreibt alle inventarisierten Framework- und optionalen Paketobjekte, die
keine öffentliche `USP_*`-Analyse sind: Views, Table-Valued Functions (TVFs),
interne Procedures und Tabellen.
Die vollständige und maschinenlesbare Installationsmenge ist
[`Metadata/Inventory/Objects.csv`](../../Metadata/Inventory/Objects.csv).

Interne Objects sind Implementierungsdetails. Anwendungen und Administratoren
sollen sie nicht direkt aufrufen oder ihre Tabellen verändern. Ihre Signaturen,
Spalten und Abläufe sind kein stabiler öffentlicher Vertrag. Öffentliche
`USP_*`-Objekte sind ausschließlich über die Procedure-Referenz und die
[Analyse-Guides](../Analysis_Guides/Object_Index.md) zu verwenden.

## Views

### `[monitor].[VW_ModuleStatusCatalog]`

Quelle: `Code/01_Common/010_VW_ModuleStatusCatalog.sql`

Stellt den gemeinsamen Katalog der Modul- und Statusbezeichnungen bereit, damit
Ausgaben und Orchestratoren dieselben technischen Zustände benennen.

### `[monitor].[VW_AnalyseClassCatalog]`

Quelle: `Code/01_Common/020_VW_AnalyseClassCatalog.sql`

Liefert die Klassifikation von Analysepfaden, insbesondere für Kosten- und
Zugriffsentscheidungen. Sie ist eine Lesesicht auf Frameworkmetadaten.

### `[monitor].[VW_AnalyseAccessPolicy]`

Quelle: `Code/01_Common/030_VW_AnalyseAccessPolicy.sql`

Zeigt die konfigurierte interne Analysezugriffspolicy. Die View vergibt weder
SQL-Server-Rechte noch verändert sie die Policy.

### `[monitor].[VW_AnalyseAccessCurrent]`

Quelle: `Code/01_Common/040_VW_AnalyseAccessCurrent.sql`

Projiziert die für die aktuelle Ausführung relevante Zugriffsauswertung. Sie
ist die lesbare Grundlage der internen Berechtigungsschiene.

### `[monitor].[VW_FrameworkFeatureCatalog]`

Quelle: `Code/01_Common/060_VW_FrameworkFeatureCatalog.sql`

Katalogisiert Framework-Features und deren Voraussetzungen, damit Procedures
Verfügbarkeit und Teilresultate konsistent ausweisen können.

## Table-Valued Functions

### `[monitor].[TVF_WaitTypeInfo]`

Quelle: `Code/01_Common/075_TVF_WaitTypeInfo.sql`

Ordnet Wait-Typen der kuratierten Einordnung und Interpretation zu.

### `[monitor].[TVF_WaitTypeSources]`

Quelle: `Code/01_Common/075a_TVF_WaitTypeSources.sql`

Liefert quellenbezogene Metadaten zu einem Wait-Typ für die Dokumentations- und
Evidenzausgabe.

### `[monitor].[TVF_QueryStoreWaitCategoryInfo]`

Quelle: `Code/01_Common/076_TVF_QueryStoreWaitCategoryInfo.sql`

Übersetzt Query-Store-Waitkategorien in die Frameworkklassifikation.

### `[monitor].[TVF_ParsePipeList]`

Quelle: `Code/01_Common/078_TVF_ParsePipeList.sql`

Parst eine Pipe-getrennte Liste unter Beachtung geklammerter SQL-Identifier.

### `[monitor].[TVF_ParsePattern]`

Quelle: `Code/01_Common/079_TVF_ParsePattern.sql`

Normalisiert einen unterstützten Patternfilter und trennt dessen Modus vom
eigentlichen Suchmuster.

### `[monitor].[TVF_ParseSqlNameList]`

Quelle: `Code/01_Common/080_TVF_ParseSqlNameList.sql`

Zerlegt eine Liste von SQL-Namen in sicher weiterverarbeitbare Bestandteile.

### `[monitor].[TVF_ParseFullObjectNameList]`

Quelle: `Code/01_Common/081_TVF_ParseFullObjectNameList.sql`

Parst mehrteilige Objektnamen für datenbankübergreifende Filter.

### `[monitor].[TVF_DatabaseCandidates]`

Quelle: `Code/01_Common/082_TVF_DatabaseCandidates.sql`

Ermittelt die Kandidatenmenge für die Datenbankauswahl; die aufrufende
Procedure verantwortet anschließend Scope und Zugriffsprüfung.

### `[monitor].[TVF_ParseBigintList]`

Quelle: `Code/01_Common/085_TVF_ParseBigintList.sql`

Zerlegt numerische `bigint`-Listen für explizite IDs oder Schwellenwerte.

### `[monitor].[TVF_ParseStringList]`

Quelle: `Code/01_Common/086_TVF_ParseStringList.sql`

Parst generische Zeichenlisten ohne SQL-Identifiersemantik.

### `[monitor].[TVF_ParseBlockingResource]`

Quelle: `Code/01_Common/086a_TVF_ParseBlockingResource.sql`

Extrahiert strukturierte Informationen aus einer Blocking-Ressourcenbeschreibung.

### `[monitor].[TVF_StatementText]`

Quelle: `Code/01_Common/087_TVF_StatementText.sql`

Ermittelt mittels Statement-Offsets den aktuell relevanten Statementausschnitt
eines Batchtexts.

### `[monitor].[TVF_ToolBackgroundQueryInfo]`

Quelle: `Code/01_Common/087c_TVF_ToolBackgroundQueryInfo.sql`

Klassifiziert bekannte Hintergrundabfragen von Clienttools anhand der
metadatengesteuerten Regeln.

### `[monitor].[TVF_ProjectUnicodeText]`

Quelle: `Code/01_Common/087d_TVF_ProjectUnicodeText.sql`

Projiziert Unicode-Langtext mit dem gemeinsamen Kürzungs- und Statusvertrag.

### `[monitor].[TVF_ClassifyErrorLogEvent]`

Quelle: `Code/01_Common/087e_TVF_ClassifyErrorLogEvent.sql`

Ordnet begrenzt gelesene Errorlog-Ereignisse einer technischen Kategorie zu.

### `[monitor].[TVF_InterpretPerformanceCounter]`

Quelle: `Code/01_Common/088_TVF_InterpretPerformanceCounter.sql`

Berechnet die sichere Delta- und Resetinterpretation für Performance Counter.

### `[monitor].[TVF_InterpretContentionCounter]`

Quelle: `Code/01_Common/089_TVF_InterpretContentionCounter.sql`

Bewertet die Counter-Differenz für interne Contention ohne einen Befund zu
erzwingen.

### `[monitor].[TVF_InterpretAvailabilityDatabaseState]`

Quelle: `Code/01_Common/090_TVF_InterpretAvailabilityDatabaseState.sql`

Klassifiziert den beobachteten Availability-Datenbankzustand.

### `[monitor].[TVF_InterpretAvailabilitySeedingState]`

Quelle: `Code/01_Common/091_TVF_InterpretAvailabilitySeedingState.sql`

Klassifiziert den Status des Availability-Seeding.

### `[monitor].[TVF_InterpretAgentAlertRoute]`

Quelle: `Code/01_Common/092_TVF_InterpretAgentAlertRoute.sql`

Interpretiert den konfigurierten SQL-Agent-Alert-Routingzustand.

### `[monitor].[TVF_InterpretAgentJobState]`

Quelle: `Code/01_Common/093_TVF_InterpretAgentJobState.sql`

Übersetzt den Agent-Jobstatus in eine einheitliche technische Einordnung.

### `[monitor].[TVF_InterpretDatabaseMailStatus]`

Quelle: `Code/01_Common/094_TVF_InterpretDatabaseMailStatus.sql`

Ordnet den sichtbaren Database-Mail-Zustand der Frameworkklassifikation zu.

### `[monitor].[TVF_ParseStatisticsIoText]`

Quelle: `Code/04_PlanCache/044_TVF_ParseStatisticsIoText.sql`

Parst die textuelle `STATISTICS IO`-Evidenz in strukturierte Werte.

### `[monitor].[TVF_ParseStatisticsTimeText]`

Quelle: `Code/04_PlanCache/045_TVF_ParseStatisticsTimeText.sql`

Parst die textuelle `STATISTICS TIME`-Evidenz in strukturierte Werte.

### `[monitor].[TVF_ExecutionPlanObjectReferences]`

Quelle: `Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql`

Extrahiert objektbezogene Referenzen aus einem Showplan-XML.

### `[monitor].[TVF_ExecutionPlanStatisticsUsage]`

Quelle: `Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql`

Extrahiert die im Showplan dokumentierte Statistikverwendung.

### `[monitor].[TVF_ExecutionPlanColumnReferences]`

Quelle: `Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql`

Extrahiert Spaltenreferenzen aus dem Showplan für die Plandiagnose.

## Interne Procedures

### `[monitor].[InternalCheckAnalysisPath]`

Quelle: `Code/01_Common/083a_USP_InternalCheckAnalysisPath.sql`

Prüft vor der Ausführung den internen Kosten- und Berechtigungspfad.

### `[monitor].[InternalWriteResultTable]`

Quelle: `Code/01_Common/095_USP_InternalWriteResultTable.sql`

Schreibt eine kanonische Ergebnismenge in eine bereits vorbereitete lokale
Ergebnistabelle.

### `[monitor].[InternalPrepareResultTables]`

Quelle: `Code/01_Common/096_USP_InternalPrepareResultTables.sql`

Bereitet alle im TABLE-Vertrag angeforderten lokalen Ergebnistabellen vor.

### `[monitor].[InternalPrepareSingleResultTable]`

Quelle: `Code/01_Common/097_USP_InternalPrepareSingleResultTable.sql`

Validiert und richtet eine einzelne lokale Ergebnistabelle des TABLE-Vertrags
ein.

### `[monitor].[InternalEmitConsoleResult]`

Quelle: `Code/01_Common/098_USP_InternalEmitConsoleResult.sql`

Erzeugt die standardisierte CONSOLE-Darstellung aus der kanonischen Datenbasis.

### `[monitor].[InternalProjectUnicodeTextColumn]`

Quelle: `Code/01_Common/098_USP_InternalProjectUnicodeTextColumn.sql`

Projiziert eine Langtextspalte für Ausgabearten mit konsistenter Kürzung.

### `[monitor].[InternalEmitTruncationWarning]`

Quelle: `Code/01_Common/099_USP_InternalEmitTruncationWarning.sql`

Meldet eine sichtbare Textkürzung einschließlich des passenden
Parameterhinweises.

### `[monitor].[InternalParseXmlText]`

Quelle: `Code/01_Common/099a_USP_InternalParseXmlText.sql`

Parst Text defensiv zu XML und liefert dafür einen strukturierten Status.

### `[monitor].[InternalCollectExecutionPlanMetadata]`

Quelle: `Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql`

Sammelt die für die eigenständige Ausführungsplananalyse erforderlichen
Metadaten.

### `[monitor].[InternalAnalyzeExecutionPlan]`

Quelle: `Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql`

Führt die interne Regel- und Evidenzanalyse eines Showplan-XML durch.

## Tabellen

### `[monitor].[ToolBackgroundQueryPattern]`

Quelle: `Code/01_Common/087a_ToolBackgroundQueryPattern.sql`

Enthält die pflegbaren, metadatengesteuerten Erkennungsmuster für
Tool-Hintergrundabfragen. Direkte Änderungen außerhalb des dokumentierten
Administrationswegs sind nicht Teil des öffentlichen Vertrags.

### `[monitor].[SqlServerBuildCatalog]`

Quelle: `Code/09_VersionAdaptive/011_SqlServerBuildCatalog.sql`

Stellt die kuratierte Build- und Servicingzuordnung für die Offlinebewertung
der Serverversion bereit.

### `[monitor].[SqlServerLifecycleCatalog]`

Quelle: `Code/09_VersionAdaptive/012_SqlServerLifecycleCatalog.sql`

Stellt die kuratierte Lifecyclezuordnung für die Offlinebewertung bereit.

### `[monitor].[PlanAnalysisProfile]`

Quelle: `Code/04_PlanCache/041_PlanAnalysisProfile.sql`

Definiert benannte Analyseprofile für die Ausführungsplananalyse.

### `[monitor].[PlanAnalysisRuleThreshold]`

Quelle: `Code/04_PlanCache/042_PlanAnalysisRuleThreshold.sql`

Hinterlegt je Analyseprofil die Schwellenwerte der Plananalyse-Regeln.

### `[monitor].[PlanAnalysisProfileAssignment]`

Quelle: `Code/04_PlanCache/043_PlanAnalysisProfileAssignment.sql`

Ordnet einer Plananalyse ein passendes Profil zu.

## Optionales Snapshot-/Baseline-Paket SC-023

### `[monitor].[SnapshotTargetConfiguration]`

Quelle: `Code/10_SnapshotBaseline/010_SnapshotTargetConfiguration.sql`

Hält als typisierter Singleton das ausdrücklich konfigurierte lokale
Snapshotziel. Ohne separate Paketinstallation bleibt der Frameworkkern
zustandslos.

### `[snapshot].[PackageVersion]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Versioniert Paket und Zielschema und protokolliert den letzten Installerlauf.

### `[snapshot].[RetentionPolicy]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Definiert typisierte Retention-, Batch- und Softbudgetgrenzen.

### `[snapshot].[CollectorPolicy]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Begrenzt Intervall, Zeilenumfang und optionales Payload je Collector.

### `[snapshot].[CaptureRun]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Speichert Lauf, Schedulerherkunft, UTC-Grenzen, Reset-Epoche und Gesamtstatus.

### `[snapshot].[ModuleStatus]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Bewahrt Partialität, Fehlergrenze und Evidenzlimit je Laufmodul.

### `[snapshot].[Scope]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Ordnet gehashte technische Scopeidentitäten den persistierten Samples zu.

### `[snapshot].[MetricDefinition]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Versioniert Metrikcode, Datentyp, Einheit und Bedeutung.

### `[snapshot].[MetricSample]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Speichert genau einen typisierten Wert je Lauf, Scope und Metrikdefinition.

### `[snapshot].[PayloadSnapshot]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Hält optional den vollständigen komprimierten und hashgebundenen
Collectorvertrag im autorisierten Zielsystem.

### `[snapshot].[PurgeRun]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

Protokolliert ausschließlich technische Summen begrenzter Retentionläufe.

### `[snapshot].[InternalConfigureSnapshotPolicy]`

Quelle: `Code/10_SnapshotBaseline/020_InternalConfigureSnapshotPolicy.sql`

Validiert und schreibt die typisierten Zielpolicies transaktional.

### `[snapshot].[InternalPrepareCollectionCycle]`

Quelle: `Code/10_SnapshotBaseline/040_InternalPrepareCollectionCycle.sql`

Prüft Due-Zeit und Softbudget vor jedem Quellread und eröffnet den Lauf.

### `[snapshot].[InternalCompletePerformanceCounterCycle]`

Quelle: `Code/10_SnapshotBaseline/050_InternalCompletePerformanceCounterCycle.sql`

Normalisiert den transient übergebenen Performance-Counter-JSON-Vertrag und
persistiert optionale Payloads.

### `[snapshot].[InternalFinalizeCollectionCycle]`

Quelle: `Code/10_SnapshotBaseline/060_InternalFinalizeCollectionCycle.sql`

Schließt einen eröffneten Lauf mit Status und technischen Zeilensummen ab.

### `[snapshot].[InternalPurgeExpiredData]`

Quelle: `Code/10_SnapshotBaseline/070_InternalPurgeExpiredData.sql`

Entfernt ausschließlich abgelaufene Evidenz child-first in begrenzten Batches.
