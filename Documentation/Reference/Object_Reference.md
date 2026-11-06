# Referenz der unterstützenden Frameworkobjekte

Stand: 2026-10-25

Diese Referenz ergänzt die [Procedure-Referenz](Procedure_Reference.md). Sie
beschreibt alle inventarisierten Framework- und optionalen Paketobjekte, die
keine öffentliche `USP_*`-Analyse sind. Maßgeblich für die Abdeckung ist
[`Metadata/Inventory/Objects.csv`](../../Metadata/Inventory/Objects.csv).

Jeder Objektabschnitt dokumentiert Aufgabe, Schnittstelle, vorgesehene
Verwendung, Last-/Sperrverhalten und Stabilitätsgrenze. Die drei Analysis-
Navigator-Views besitzen einen dokumentierten lesenden Katalogvertrag. Alle
übrigen internen Bausteine sind auffindbar, aber kein eigenständiger
Analyseendpunkt. Anwendungen verwenden grundsätzlich die
[öffentlichen Analyse-Procedures](../Analysis_Guides/Object_Index.md).

## Abdeckung

| Objektklasse | Inventarisiert | Dokumentationsumfang |
|---|---:|---|
| Views | 8 | ein Abschnitt je View |
| Table-Valued Functions (TVFs) | 29 | ein Abschnitt je TVF |
| Scalar-Valued Functions (SVFs) | 0 | derzeit keine SVF installiert |
| Interne Procedures | 19 | ein Abschnitt je Procedure |
| Tabellen | 20 | ein Abschnitt je Tabelle |

## Direktnavigation

Die persistenten Corekataloge `FrameworkVersion`, `WaitTypeCatalog` und `WaitTypeCatalogSource` sind ebenfalls Teil des Tabelleninventars. Ihre Aufgabe und Erhaltung sind in den folgenden Abschnitten beschrieben.

### `[monitor].[FrameworkVersion]`

Quelle: `Code/01_Common/077_FrameworkVersion.sql`

`FrameworkVersion` und `ContractVersion` sind die bei Installation oder Upgrade
geschriebenen Werte dieses Katalogs. `ReleaseDate` ist das darin hinterlegte
Releasedatum und kein Datum des letzten Git-Commits. `LastInstalledUtc`
bezeichnet die konkrete Installation. Das optionale Zielpaket verwendet
zusätzlich seinen eigenen Versionskatalog `snapshot.PackageVersion`.

Die `Version`-Angaben in SQL-Objektheadern bezeichnen dagegen den jeweiligen
dokumentierten Objektstand. Sie müssen nicht mit der Frameworkversion
übereinstimmen. Eine allgemeine verbindliche Regel für semantische
Major-/Minor-/Patch-Erhöhungen dieser Header ist derzeit nicht dokumentiert.
Für einen reproduzierbaren Vergleich bleiben Git-Commit, kanonische Quelle
und der tatsächliche Testumfang erforderlich. Diese Erläuterung ändert keine
vorhandene Versionsnummer oder historische Zuordnung.

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Die Tabelle dokumentiert den installierten Frameworkstand pro Frameworkname. Sie hält Versionswerte, Installationszeitpunkte, Mindestversion und Installationshinweise als persistente Katalogdaten. |
| Schnittstelle | Der Frameworkname ist der eindeutige Schlüssel. Der kanonische Installer schreibt den Schlüssel `SQLServerMonitoringFramework`; zusätzliche vorhandene Frameworkschlüssel werden nicht als eigene Seedwerte interpretiert. |
| Verwendung | Installation und Wiederholung aktualisieren den eigenen Versionsschlüssel. `Deploy_All.generated.sql` erhält davor die gesamte Tabelle typgetreu im Deploymentarchiv, einschließlich zusätzlicher Frameworkzeilen und ursprünglicher Zeitwerte. |
| Last und Sperren | Installationen sperren die Tabelle während des gemeinsamen Deploymentlaufs. Die Vorzustandskopie benötigt zusätzlichen Speicher und Transaktionslog; normale Laufzeitanalysen schreiben diesen Versionskatalog nicht fort. |
| Vertrag | Ein Versionswert allein belegt weder die Vollständigkeit der übrigen Objekte noch einen erfolgreichen fachlichen Laufzeittest. Der erfolgreiche Gesamtabschluss wird anhand von Receipt, Quellhash und Objektgestalt geprüft. |

### `[monitor].[WaitTypeCatalog]`

Quelle: `Code/01_Common/074_WaitTypeCatalog.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Die Tabelle enthält kuratierte und lokale Wait-Beschreibungen sowie Analysefelder für Bedeutung, Messung, Ursachen, Gegenbelege und geeignete weitere Prüfung. Die Beschreibungen ersetzen keine aktive Wait- oder Lastmessung. |
| Schnittstelle | Der Waitname ist der eindeutige Schlüssel. `IsFrameworkDefault` trennt Frameworkseeds von Customzeilen. Die zugehörigen Wait-Funktionen veröffentlichen den diagnostischen Katalog für aktuelle Wait- und Query-Store-Analysen. |
| Verwendung | Die Quellen ergänzen fehlende bekannte Einträge und aktualisieren eigene Defaultwerte. Customwerte bleiben erhalten. Die zwölf bekannten additiven Spalten werden nach ihren Namen und Facetten geprüft; ihre physische Spaltenreihenfolge muss nicht der Erstinstallation entsprechen. |
| Last und Sperren | Der Gesamtdeploymentweg sperrt die Tabelle und erhält vor Änderungen ihren ursprünglichen Stand. Die Kopie benötigt Speicher und Transaktionslog proportional zum vorhandenen Tabelleninhalt. |
| Vertrag | Retirierte Frameworknamen dürfen erst nach Vorzustandserhaltung entfernt werden. Bestehende Customverweise verhindern diese Migration. Installation und analytische Nutzung besitzen unterschiedliche Schreib- und Sperrverträge. |

### `[monitor].[WaitTypeCatalogSource]`

Quelle: `Code/01_Common/074_WaitTypeCatalog.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Die Tabelle ordnet einem Wait dokumentierte Quellenrollen zu. Sie hält unter anderem Titel, URL, unterstützte Analysefelder, Evidenzgrenze und Prüfzeitpunkt für die nachvollziehbare Herkunft der Katalogbeschreibungen. |
| Schnittstelle | Waitname und Quellenordinal bilden gemeinsam den eindeutigen Schlüssel. Der Fremdschlüssel verweist auf `WaitTypeCatalog`; `IsFrameworkDefault` kennzeichnet die vom Framework verwalteten Quellenzeilen. |
| Verwendung | Bei der Migration retirierter Frameworknamen werden erhaltene Frameworkquellen vor ihrem Elternwait aus der aktiven Menge entfernt. Customquellen bleiben erhalten. Die Wait-Quellenfunktion bietet den lesenden Zugriff für Analyse und Prüfung. |
| Last und Sperren | Der Gesamtdeploymentweg sperrt die Tabelle und kopiert ihren ursprünglichen Inhalt in das persistente Vorzustandsarchiv. Nullwerte und abschließende Leerzeichen bleiben dort erhalten. Das Archiv besitzt keine automatische Löschfrist. |
| Vertrag | Customverweise auf retirierende Eltern und Überschneidungen mit erforderlichen Frameworkschlüsseln führen vor Änderungen zum Abbruch. Eine Quellenbeschreibung allein belegt keine aktuelle Ursache in der untersuchten Last. |

### Views

| Objekt | Schema | Quelle |
|---|---|---|
| [`VW_ModuleStatusCatalog`](#monitorvw_modulestatuscatalog) | `monitor` | `Code/01_Common/010_VW_ModuleStatusCatalog.sql` |
| [`VW_AnalyseClassCatalog`](#monitorvw_analyseclasscatalog) | `monitor` | `Code/01_Common/020_VW_AnalyseClassCatalog.sql` |
| [`VW_AnalysisCatalog`](#monitorvw_analysiscatalog) | `monitor` | `Code/01_Common/021_VW_AnalysisCatalog.sql` |
| [`VW_AnalysisSearchTerm`](#monitorvw_analysissearchterm) | `monitor` | `Code/01_Common/022_VW_AnalysisSearchTerm.sql` |
| [`VW_AnalysisRelation`](#monitorvw_analysisrelation) | `monitor` | `Code/01_Common/023_VW_AnalysisRelation.sql` |
| [`VW_AnalyseAccessPolicy`](#monitorvw_analyseaccesspolicy) | `monitor` | `Code/01_Common/030_VW_AnalyseAccessPolicy.sql` |
| [`VW_AnalyseAccessCurrent`](#monitorvw_analyseaccesscurrent) | `monitor` | `Code/01_Common/040_VW_AnalyseAccessCurrent.sql` |
| [`VW_FrameworkFeatureCatalog`](#monitorvw_frameworkfeaturecatalog) | `monitor` | `Code/01_Common/060_VW_FrameworkFeatureCatalog.sql` |

### Table-Valued Functions (TVFs)

| Objekt | Schema | Quelle |
|---|---|---|
| [`TVF_WaitTypeInfo`](#monitortvf_waittypeinfo) | `monitor` | `Code/01_Common/075_TVF_WaitTypeInfo.sql` |
| [`TVF_WaitTypeSources`](#monitortvf_waittypesources) | `monitor` | `Code/01_Common/075a_TVF_WaitTypeSources.sql` |
| [`TVF_QueryStoreWaitCategoryInfo`](#monitortvf_querystorewaitcategoryinfo) | `monitor` | `Code/01_Common/076_TVF_QueryStoreWaitCategoryInfo.sql` |
| [`TVF_QueryStoreReplicaRoleInfo`](#monitortvf_querystorereplicaroleinfo) | `monitor` | `Code/05_QueryStore/005_TVF_QueryStoreReplicaRoleInfo.sql` |
| [`TVF_ParsePipeList`](#monitortvf_parsepipelist) | `monitor` | `Code/01_Common/078_TVF_ParsePipeList.sql` |
| [`TVF_ParsePattern`](#monitortvf_parsepattern) | `monitor` | `Code/01_Common/079_TVF_ParsePattern.sql` |
| [`TVF_ParseSqlNameList`](#monitortvf_parsesqlnamelist) | `monitor` | `Code/01_Common/080_TVF_ParseSqlNameList.sql` |
| [`TVF_ParseFullObjectNameList`](#monitortvf_parsefullobjectnamelist) | `monitor` | `Code/01_Common/081_TVF_ParseFullObjectNameList.sql` |
| [`TVF_DatabaseCandidates`](#monitortvf_databasecandidates) | `monitor` | `Code/01_Common/082_TVF_DatabaseCandidates.sql` |
| [`TVF_ParseBigintList`](#monitortvf_parsebigintlist) | `monitor` | `Code/01_Common/085_TVF_ParseBigintList.sql` |
| [`TVF_ParseStringList`](#monitortvf_parsestringlist) | `monitor` | `Code/01_Common/086_TVF_ParseStringList.sql` |
| [`TVF_ParseBlockingResource`](#monitortvf_parseblockingresource) | `monitor` | `Code/01_Common/086a_TVF_ParseBlockingResource.sql` |
| [`TVF_StatementText`](#monitortvf_statementtext) | `monitor` | `Code/01_Common/087_TVF_StatementText.sql` |
| [`TVF_ToolBackgroundQueryInfo`](#monitortvf_toolbackgroundqueryinfo) | `monitor` | `Code/01_Common/087c_TVF_ToolBackgroundQueryInfo.sql` |
| [`TVF_ProjectUnicodeText`](#monitortvf_projectunicodetext) | `monitor` | `Code/01_Common/087d_TVF_ProjectUnicodeText.sql` |
| [`TVF_ClassifyErrorLogEvent`](#monitortvf_classifyerrorlogevent) | `monitor` | `Code/01_Common/087e_TVF_ClassifyErrorLogEvent.sql` |
| [`TVF_InterpretPerformanceCounter`](#monitortvf_interpretperformancecounter) | `monitor` | `Code/01_Common/088_TVF_InterpretPerformanceCounter.sql` |
| [`TVF_InterpretContentionCounter`](#monitortvf_interpretcontentioncounter) | `monitor` | `Code/01_Common/089_TVF_InterpretContentionCounter.sql` |
| [`TVF_InterpretAvailabilityDatabaseState`](#monitortvf_interpretavailabilitydatabasestate) | `monitor` | `Code/01_Common/090_TVF_InterpretAvailabilityDatabaseState.sql` |
| [`TVF_InterpretAvailabilitySeedingState`](#monitortvf_interpretavailabilityseedingstate) | `monitor` | `Code/01_Common/091_TVF_InterpretAvailabilitySeedingState.sql` |
| [`TVF_InterpretAgentAlertRoute`](#monitortvf_interpretagentalertroute) | `monitor` | `Code/01_Common/092_TVF_InterpretAgentAlertRoute.sql` |
| [`TVF_InterpretAgentJobState`](#monitortvf_interpretagentjobstate) | `monitor` | `Code/01_Common/093_TVF_InterpretAgentJobState.sql` |
| [`TVF_InterpretDatabaseMailStatus`](#monitortvf_interpretdatabasemailstatus) | `monitor` | `Code/01_Common/094_TVF_InterpretDatabaseMailStatus.sql` |
| [`TVF_ParseStatisticsIoText`](#monitortvf_parsestatisticsiotext) | `monitor` | `Code/04_PlanCache/044_TVF_ParseStatisticsIoText.sql` |
| [`TVF_ParseStatisticsTimeText`](#monitortvf_parsestatisticstimetext) | `monitor` | `Code/04_PlanCache/045_TVF_ParseStatisticsTimeText.sql` |
| [`TVF_ExecutionPlanObjectReferences`](#monitortvf_executionplanobjectreferences) | `monitor` | `Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql` |
| [`TVF_ExecutionPlanStatisticsUsage`](#monitortvf_executionplanstatisticsusage) | `monitor` | `Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql` |
| [`TVF_ExecutionPlanColumnReferences`](#monitortvf_executionplancolumnreferences) | `monitor` | `Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql` |

### `[monitor].[TVF_QueryStoreReplicaRoleInfo]`

Quelle: `Code/05_QueryStore/005_TVF_QueryStoreReplicaRoleInfo.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ordnet den von SQL Server 2025 gelieferten `role_type` einer stabilen Query-Store-Rollen- und Scopeklasse zu. |
| Schnittstelle | Inline TVF; Eingabe: `@RoleType tinyint`. Die Funktion liefert Rollenbezeichnung, Rollenklasse, Primary-/Secondary-/Named-Replica-Flags und eine feste Aussagegrenze. |
| Verwendung | `USP_QueryStoreReplicaAnalysis` verwendet die Funktion nach der capability-adaptiven Katalogprüfung. Ein Direktaufruf eignet sich nur für Entwicklung und Vertragstests. |
| Last und Sperren | Konstante Projektion ohne Katalog-, DMV- oder Tabellenzugriff. Die Funktion erzeugt weder I/O noch Sperren auf Benutzerdaten. |
| Vertrag | Unterstützende TVF. Die Rollenabbildung beschreibt beobachtete Query-Store-Evidenz und ist keine aktuelle Availability-Group-, Synchronitäts- oder Healthaussage. |

## Interne Procedures

| Objekt | Schema | Quelle |
|---|---|---|
| [`InternalCheckAnalysisPath`](#monitorinternalcheckanalysispath) | `monitor` | `Code/01_Common/083a_USP_InternalCheckAnalysisPath.sql` |
| [`InternalWriteResultTable`](#monitorinternalwriteresulttable) | `monitor` | `Code/01_Common/095_USP_InternalWriteResultTable.sql` |
| [`InternalPrepareResultTables`](#monitorinternalprepareresulttables) | `monitor` | `Code/01_Common/096_USP_InternalPrepareResultTables.sql` |
| [`InternalPrepareSingleResultTable`](#monitorinternalpreparesingleresulttable) | `monitor` | `Code/01_Common/097_USP_InternalPrepareSingleResultTable.sql` |
| [`InternalEmitConsoleResult`](#monitorinternalemitconsoleresult) | `monitor` | `Code/01_Common/098_USP_InternalEmitConsoleResult.sql` |
| [`InternalProjectUnicodeTextColumn`](#monitorinternalprojectunicodetextcolumn) | `monitor` | `Code/01_Common/098_USP_InternalProjectUnicodeTextColumn.sql` |
| [`InternalEmitTruncationWarning`](#monitorinternalemittruncationwarning) | `monitor` | `Code/01_Common/099_USP_InternalEmitTruncationWarning.sql` |
| [`InternalParseXmlText`](#monitorinternalparsexmltext) | `monitor` | `Code/01_Common/099a_USP_InternalParseXmlText.sql` |
| [`InternalCaptureCurrentStateSnapshot`](#monitorinternalcapturecurrentstatesnapshot) | `monitor` | `Code/02_CurrentState/005_InternalCaptureCurrentStateSnapshot.sql` |
| [`InternalCollectExecutionPlanMetadata`](#monitorinternalcollectexecutionplanmetadata) | `monitor` | `Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql` |
| [`InternalAnalyzeExecutionPlan`](#monitorinternalanalyzeexecutionplan) | `monitor` | `Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql` |
| [`InternalConfigureSnapshotPolicy`](#snapshotinternalconfiguresnapshotpolicy) | `snapshot` | `Code/10_SnapshotBaseline/020_InternalConfigureSnapshotPolicy.sql` |
| [`InternalPrepareCollectionCycle`](#snapshotinternalpreparecollectioncycle) | `snapshot` | `Code/10_SnapshotBaseline/040_InternalPrepareCollectionCycle.sql` |
| [`InternalCompletePerformanceCounterCycle`](#snapshotinternalcompleteperformancecountercycle) | `snapshot` | `Code/10_SnapshotBaseline/050_InternalCompletePerformanceCounterCycle.sql` |
| [`InternalCompleteWaitStatsCycle`](#snapshotinternalcompletewaitstatscycle) | `snapshot` | `Code/10_SnapshotBaseline/055_InternalCompleteWaitStatsCycle.sql` |
| [`InternalCompleteFileIOCycle`](#snapshotinternalcompletefileiocycle) | `snapshot` | `Code/10_SnapshotBaseline/057_InternalCompleteFileIOCycle.sql` |
| [`InternalFinalizeCollectionCycle`](#snapshotinternalfinalizecollectioncycle) | `snapshot` | `Code/10_SnapshotBaseline/060_InternalFinalizeCollectionCycle.sql` |
| [`InternalPurgeExpiredData`](#snapshotinternalpurgeexpireddata) | `snapshot` | `Code/10_SnapshotBaseline/070_InternalPurgeExpiredData.sql` |
| [`InternalValidateSnapshotWaitTarget`](#monitorinternalvalidatesnapshotwaittarget) | `monitor` | `Code/10_SnapshotBaseline/076_InternalValidateSnapshotWaitTarget.sql` |
| [`InternalRunSnapshotWaitStatsCycle`](#monitorinternalrunsnapshotwaitstatscycle) | `monitor` | `Code/10_SnapshotBaseline/085_InternalRunSnapshotWaitStatsCycle.sql` |
| [`InternalRunSnapshotFileIOCycle`](#monitorinternalrunsnapshotfileiocycle) | `monitor` | `Code/10_SnapshotBaseline/087_InternalRunSnapshotFileIOCycle.sql` |

### Tabellen

| Objekt | Schema | Quelle |
|---|---|---|
| [`FrameworkVersion`](#monitorframeworkversion) | `monitor` | `Code/01_Common/077_FrameworkVersion.sql` |
| [`WaitTypeCatalog`](#monitorwaittypecatalog) | `monitor` | `Code/01_Common/074_WaitTypeCatalog.sql` |
| [`WaitTypeCatalogSource`](#monitorwaittypecatalogsource) | `monitor` | `Code/01_Common/074_WaitTypeCatalog.sql` |
| [`ToolBackgroundQueryPattern`](#monitortoolbackgroundquerypattern) | `monitor` | `Code/01_Common/087a_ToolBackgroundQueryPattern.sql` |
| [`SqlServerBuildCatalog`](#monitorsqlserverbuildcatalog) | `monitor` | `Code/09_VersionAdaptive/011_SqlServerBuildCatalog.sql` |
| [`SqlServerLifecycleCatalog`](#monitorsqlserverlifecyclecatalog) | `monitor` | `Code/09_VersionAdaptive/012_SqlServerLifecycleCatalog.sql` |
| [`PlanAnalysisProfile`](#monitorplananalysisprofile) | `monitor` | `Code/04_PlanCache/041_PlanAnalysisProfile.sql` |
| [`PlanAnalysisRuleThreshold`](#monitorplananalysisrulethreshold) | `monitor` | `Code/04_PlanCache/042_PlanAnalysisRuleThreshold.sql` |
| [`PlanAnalysisProfileAssignment`](#monitorplananalysisprofileassignment) | `monitor` | `Code/04_PlanCache/043_PlanAnalysisProfileAssignment.sql` |
| [`SnapshotTargetConfiguration`](#monitorsnapshottargetconfiguration) | `monitor` | `Code/10_SnapshotBaseline/010_SnapshotTargetConfiguration.sql` |
| [`PackageVersion`](#snapshotpackageversion) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |
| [`RetentionPolicy`](#snapshotretentionpolicy) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |
| [`CollectorPolicy`](#snapshotcollectorpolicy) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |
| [`CaptureRun`](#snapshotcapturerun) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |
| [`ModuleStatus`](#snapshotmodulestatus) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |
| [`Scope`](#snapshotscope) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |
| [`MetricDefinition`](#snapshotmetricdefinition) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |
| [`MetricSample`](#snapshotmetricsample) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |
| [`PayloadSnapshot`](#snapshotpayloadsnapshot) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |
| [`PurgeRun`](#snapshotpurgerun) | `snapshot` | `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql` |

## Views

### `[monitor].[VW_ModuleStatusCatalog]`

Quelle: `Code/01_Common/010_VW_ModuleStatusCatalog.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Stellt den gemeinsamen Katalog der Modul- und Statusbezeichnungen bereit, damit Ausgaben und Orchestratoren dieselben technischen Zustände benennen. |
| Schnittstelle | Parameterlose, read-only View. Der Spaltenvertrag wird durch das `SELECT` der kanonischen Quelle festgelegt; die View besitzt keinen eigenen Datenspeicher. |
| Verwendung | Framework-Procedures lesen diese Projektion, um Status-, Policy- oder Capability-Entscheidungen einheitlich zu treffen. Für Diagnoseaufrufe bleibt die jeweilige öffentliche `USP_*`-Procedure der unterstützte Einstieg. |
| Last und Sperren | Read-only Projektion über konstante Framework-Metadaten. Der Aufruf schreibt nichts; CPU- und I/O-Kosten sind klein und unabhängig von der Größe der überwachten Benutzerdatenbanken. |
| Vertrag | Unterstützendes Objekt, kein eigenständiger Analyseendpunkt. Spalten können mit internen Frameworkversionen erweitert werden; Verbraucher verwenden die dokumentierten öffentlichen Procedures. |

### `[monitor].[VW_AnalyseClassCatalog]`

Quelle: `Code/01_Common/020_VW_AnalyseClassCatalog.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Liefert die Klassifikation von Analysepfaden, insbesondere für Kosten- und Zugriffsentscheidungen. Sie ist eine Lesesicht auf Frameworkmetadaten. |
| Schnittstelle | Parameterlose, read-only View. Der Spaltenvertrag wird durch das `SELECT` der kanonischen Quelle festgelegt; die View besitzt keinen eigenen Datenspeicher. |
| Verwendung | Framework-Procedures lesen diese Projektion, um Status-, Policy- oder Capability-Entscheidungen einheitlich zu treffen. Für Diagnoseaufrufe bleibt die jeweilige öffentliche `USP_*`-Procedure der unterstützte Einstieg. |
| Last und Sperren | Read-only Projektion über konstante Framework-Metadaten. Der Aufruf schreibt nichts; CPU- und I/O-Kosten sind klein und unabhängig von der Größe der überwachten Benutzerdatenbanken. |
| Vertrag | Unterstützendes Objekt, kein eigenständiger Analyseendpunkt. Spalten können mit internen Frameworkversionen erweitert werden; Verbraucher verwenden die dokumentierten öffentlichen Procedures. |

### `[monitor].[VW_AnalysisCatalog]`

Quelle: `Code/01_Common/021_VW_AnalysisCatalog.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ordnet jede öffentliche Procedure genau einer primären Navigationsrolle und einem Primärbereich zu. Ergänzt werden Anzeigename, Scope, Evidenzart, Kostenband, repräsentative Analyseklasse, Voraussetzungen, Paket, sicherer Aufruf und Dokumentationspfade. |
| Schnittstelle | Parameterlose read-only View mit genau einer Zeile je öffentlicher Procedure. Schlüssel ist `ProcedureName`. Die Spalten `NavigationRole`, `PrimaryAreaCode`, `ScopeCode`, `EvidenceType`, `CostRangeCode` und `PackageCode` verwenden dokumentierte Codewerte. |
| Verwendung | `USP_AnalysisNavigator` nutzt die View als kanonische fachliche Objektbasis. Power User können sie direkt per `SELECT` nach Rolle, Bereich, Scope, Paket oder Kostenband filtern. Mehrfachzuordnungen stehen absichtlich nicht als doppelte Zeilen, sondern in Suchbegriffen und Relationen. |
| Last und Sperren | Konstante `VALUES`-Projektion ohne Tabellen-, DMV- oder Systemkatalogzugriff. CPU und Ergebnistransfer wachsen nur mit der kleinen öffentlichen Objektzahl; keine Schreib- oder fachlichen Sperrwirkungen. |
| Vertrag | Dokumentierte lesende Katalogschnittstelle. `ProcedureName` bleibt mit dem öffentlichen Objektinventar synchron. Neue Procedures oder zusätzliche Codewerte können Zeilen beziehungsweise Werte ergänzen; Verbraucher dürfen keine feste Zeilenzahl voraussetzen. `RepresentativeAnalysisClass` ist keine vollständige Laufzeitfreigabe. |

Wesentliche Spaltengruppen:

- Identität: `ProcedureName`, `DisplayName`, `Purpose`;
- Navigation: `PrimaryAreaCode`, `PrimaryAreaName`, `NavigationRole`, `DefaultRank`;
- Scope und Evidenz: `ScopeCode`, `EvidenceType`, `PrerequisiteSummary`;
- Kosten: `CostRangeCode`, `RepresentativeAnalysisClass`, Target- und High-Impact-Flags;
- Paket und Verwendung: `PackageCode`, `SafeCall`, `DocumentationPath`, `RunbookPath`.

### `[monitor].[VW_AnalysisSearchTerm]`

Quelle: `Code/01_Common/022_VW_AnalysisSearchTerm.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Liefert deutsche und englische Symptome, Ziele, Synonyme und technische Begriffe für jede öffentliche Procedure. Ein fachliches Gewicht priorisiert spezifische gegenüber allgemeinen Begriffen; `MatchReason` erklärt den Treffer. |
| Schnittstelle | Parameterlose read-only View. Granularität ist eine Suchphrase je `ProcedureName`, `SearchTerm` und `LanguageCode`. `LanguageCode` ist `de` oder `en`; `SearchWeight` liegt zwischen 1 und 100. |
| Verwendung | Der Navigator bewertet exakte und teilweise Phrasentreffer und verwendet `MatchReason` für `WhyMatched`. Direkte Abfragen eignen sich zur Begriffsübersicht einer Procedure oder zur Suche nach einem bekannten Synonym. |
| Last und Sperren | Konstante `VALUES`-Projektion. Keine produktiven Quellen und keine Schreibzugriffe. Suchkosten wachsen linear mit der kleinen Phrasezahl und werden im Navigator durch Suchtext- und Ergebnisgrenzen kontrolliert. |
| Vertrag | Dokumentierte lesende Suchschnittstelle. Jede öffentliche Procedure besitzt mindestens einen deutschen und einen englischen Begriff. Gewichte und Phrasen dürfen fachlich präzisiert werden; sie sind keine dauerhaften Business-Keys. |

`SearchTerm` ist bewusst nicht eindeutig über alle Procedures. Begriffe wie `CPU hoch`, `blocking` oder `memory pressure` können mehrere plausible Pfade besitzen; Procedure, Gewicht, Rolle und Trefferart bestimmen die Reihenfolge.

### `[monitor].[VW_AnalysisRelation]`

Quelle: `Code/01_Common/023_VW_AnalysisRelation.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Verbindet öffentliche Procedures durch fachlich begründete nächste Schritte. Die View unterscheidet Vertiefung, unabhängige Gegenprobe, alternativen Evidenzpfad und Vorbereitung. |
| Schnittstelle | Parameterlose read-only View. Eine Zeile verbindet `FromProcedureName` über `RelationType` mit `ToProcedureName`. `RelationPriority` gilt je Ausgangsprocedure und Relationstyp; `ConditionSummary` beschreibt, wann der Übergang sinnvoll ist. |
| Verwendung | Der Navigator zeigt die höchstpriorisierte Relation je Treffer. Direkte Abfragen liefern alle Alternativen eines Ausgangsobjekts. Keine Relation führt die Zielprocedure aus und keine Relation behauptet automatisch Kausalität. |
| Last und Sperren | Konstante `VALUES`-Projektion ohne fachliche Datenquelle. Keine Schreibzugriffe; Kosten sind unabhängig von Benutzer- und Systemdatenmengen. |
| Vertrag | Dokumentierte lesende Relationsschnittstelle. Gültige Typen sind `REFINE_WITH`, `CONFIRM_WITH`, `ALTERNATIVE_TO` und `PREPARE_WITH`. Beide Endpunkte müssen öffentliche Katalogobjekte sein; Selbstbeziehungen sind ausgeschlossen. Weitere begründete Relationen dürfen ergänzt werden. |

Die Relationstypen bedeuten:

- `REFINE_WITH`: dasselbe Signal genauer untersuchen;
- `CONFIRM_WITH`: einen anderen Mess- oder Evidenzpfad gegenprüfen;
- `ALTERNATIVE_TO`: bei einer anderen verfügbaren Eingabe einen geeigneteren Zugang wählen;
- `PREPARE_WITH`: eine dokumentierte Voraussetzung oder Betriebsfolge herstellen.

### `[monitor].[VW_AnalyseAccessPolicy]`

Quelle: `Code/01_Common/030_VW_AnalyseAccessPolicy.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Zeigt die konfigurierte interne Analysezugriffspolicy. Die View vergibt weder SQL-Server-Rechte noch verändert sie die Policy. |
| Schnittstelle | Parameterlose, read-only View. Der Spaltenvertrag wird durch das `SELECT` der kanonischen Quelle festgelegt; die View besitzt keinen eigenen Datenspeicher. |
| Verwendung | Framework-Procedures lesen diese Projektion, um Status-, Policy- oder Capability-Entscheidungen einheitlich zu treffen. Für Diagnoseaufrufe bleibt die jeweilige öffentliche `USP_*`-Procedure der unterstützte Einstieg. |
| Last und Sperren | Read-only Projektion über konstante Framework-Metadaten. Der Aufruf schreibt nichts; CPU- und I/O-Kosten sind klein und unabhängig von der Größe der überwachten Benutzerdatenbanken. |
| Vertrag | Unterstützendes Objekt, kein eigenständiger Analyseendpunkt. Spalten können mit internen Frameworkversionen erweitert werden; Verbraucher verwenden die dokumentierten öffentlichen Procedures. |

### `[monitor].[VW_AnalyseAccessCurrent]`

Quelle: `Code/01_Common/040_VW_AnalyseAccessCurrent.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Projiziert die für die aktuelle Ausführung relevante Zugriffsauswertung. Sie ist die lesbare Grundlage der internen Berechtigungsschiene. |
| Schnittstelle | Parameterlose, read-only View. Der Spaltenvertrag wird durch das `SELECT` der kanonischen Quelle festgelegt; die View besitzt keinen eigenen Datenspeicher. |
| Verwendung | Framework-Procedures lesen diese Projektion, um Status-, Policy- oder Capability-Entscheidungen einheitlich zu treffen. Für Diagnoseaufrufe bleibt die jeweilige öffentliche `USP_*`-Procedure der unterstützte Einstieg. |
| Last und Sperren | Liest die kleine Policy-View und `sys.login_token`; der Katalogzugriff verwendet `NOLOCK`. Die View schreibt nichts und hält keine dauerhaften Sperren. |
| Vertrag | Unterstützendes Objekt, kein eigenständiger Analyseendpunkt. Spalten können mit internen Frameworkversionen erweitert werden; Verbraucher verwenden die dokumentierten öffentlichen Procedures. |

### `[monitor].[VW_FrameworkFeatureCatalog]`

Quelle: `Code/01_Common/060_VW_FrameworkFeatureCatalog.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Katalogisiert Framework-Features und deren Voraussetzungen, damit Procedures Verfügbarkeit und Teilresultate konsistent ausweisen können. |
| Schnittstelle | Parameterlose, read-only View. Der Spaltenvertrag wird durch das `SELECT` der kanonischen Quelle festgelegt; die View besitzt keinen eigenen Datenspeicher. |
| Verwendung | Framework-Procedures lesen diese Projektion, um Status-, Policy- oder Capability-Entscheidungen einheitlich zu treffen. Für Diagnoseaufrufe bleibt die jeweilige öffentliche `USP_*`-Procedure der unterstützte Einstieg. |
| Last und Sperren | Read-only Projektion über konstante Framework-Metadaten. Der Aufruf schreibt nichts; CPU- und I/O-Kosten sind klein und unabhängig von der Größe der überwachten Benutzerdatenbanken. |
| Vertrag | Unterstützendes Objekt, kein eigenständiger Analyseendpunkt. Spalten können mit internen Frameworkversionen erweitert werden; Verbraucher verwenden die dokumentierten öffentlichen Procedures. |

## Table-Valued Functions (TVFs)

### `[monitor].[TVF_WaitTypeInfo]`

Quelle: `Code/01_Common/075_TVF_WaitTypeInfo.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ordnet Wait-Typen der kuratierten Einordnung und Interpretation zu. |
| Schnittstelle | Inline TVF; Eingaben: `@WaitType nvarchar(120)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; Katalog- oder Metadatenreads verwenden `NOLOCK`. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_WaitTypeSources]`

Quelle: `Code/01_Common/075a_TVF_WaitTypeSources.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Liefert quellenbezogene Metadaten zu einem Wait-Typ für die Dokumentations- und Evidenzausgabe. |
| Schnittstelle | Inline TVF; Eingaben: `@WaitType nvarchar(120)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; Katalog- oder Metadatenreads verwenden `NOLOCK`. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_QueryStoreWaitCategoryInfo]`

Quelle: `Code/01_Common/076_TVF_QueryStoreWaitCategoryInfo.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Übersetzt Query-Store-Waitkategorien in die Frameworkklassifikation. |
| Schnittstelle | Inline TVF; Eingaben: `@WaitCategoryDesc nvarchar(128)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ParsePipeList]`

Quelle: `Code/01_Common/078_TVF_ParsePipeList.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Parst eine Pipe-getrennte Liste unter Beachtung geklammerter SQL-Identifier. |
| Schnittstelle | Multi-statement TVF; Eingaben: `@List nvarchar(max)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Der Parser arbeitet sequenziell; CPU skaliert mit der Länge des Eingabetexts; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ParsePattern]`

Quelle: `Code/01_Common/079_TVF_ParsePattern.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Normalisiert einen unterstützten Patternfilter und trennt dessen Modus vom eigentlichen Suchmuster. |
| Schnittstelle | Inline TVF; Eingaben: `@Pattern nvarchar(4000)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ParseSqlNameList]`

Quelle: `Code/01_Common/080_TVF_ParseSqlNameList.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Zerlegt eine Liste von SQL-Namen in sicher weiterverarbeitbare Bestandteile. |
| Schnittstelle | Inline TVF; Eingaben: `@List nvarchar(max)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ParseFullObjectNameList]`

Quelle: `Code/01_Common/081_TVF_ParseFullObjectNameList.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Parst mehrteilige Objektnamen für datenbankübergreifende Filter. |
| Schnittstelle | Inline TVF; Eingabe: `@List nvarchar(max)`. Die Funktion liefert Listenelemente mit aufgelösten Datenbank-, Schema- und Objektnamen sowie Validierungsstatus und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_DatabaseCandidates]`

Quelle: `Code/01_Common/082_TVF_DatabaseCandidates.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ermittelt die Kandidatenmenge für die Datenbankauswahl; die aufrufende Procedure verantwortet anschließend Scope und Zugriffsprüfung. |
| Schnittstelle | Inline TVF; Eingaben: `@DatabaseNames nvarchar(max) = NULL`; `@SystemdatenbankenEinbeziehen bit = 0`; `@DatabaseNamePattern nvarchar(4000) = NULL`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; Katalog- oder Metadatenreads verwenden `NOLOCK`. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ParseBigintList]`

Quelle: `Code/01_Common/085_TVF_ParseBigintList.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Zerlegt numerische `bigint`-Listen für explizite IDs oder Schwellenwerte. |
| Schnittstelle | Inline TVF; Eingaben: `@List nvarchar(max)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ParseStringList]`

Quelle: `Code/01_Common/086_TVF_ParseStringList.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Parst generische Zeichenlisten ohne SQL-Identifiersemantik. |
| Schnittstelle | Inline TVF; Eingaben: `@List nvarchar(max)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ParseBlockingResource]`

Quelle: `Code/01_Common/086a_TVF_ParseBlockingResource.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Extrahiert strukturierte Informationen aus einer Blocking-Ressourcenbeschreibung. |
| Schnittstelle | Multi-statement TVF; Eingaben: `@WaitResource nvarchar(3072)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Der Parser arbeitet sequenziell; CPU skaliert mit der Länge des Eingabetexts; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Textspalten der Rückgabe und der internen Arbeitstabellen verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_StatementText]`

Quelle: `Code/01_Common/087_TVF_StatementText.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ermittelt mittels Statement-Offsets den aktuell relevanten Statementausschnitt eines Batchtexts. |
| Schnittstelle | Inline TVF; Eingaben: `@BatchText nvarchar(max)`; `@StatementStartOffsetBytes int`; `@StatementEndOffsetBytes int`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ToolBackgroundQueryInfo]`

Quelle: `Code/01_Common/087c_TVF_ToolBackgroundQueryInfo.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Klassifiziert bekannte Hintergrundabfragen von Clienttools anhand der metadatengesteuerten Regeln. |
| Schnittstelle | Inline TVF; Eingaben: `@ProgramName nvarchar(128)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; Katalog- oder Metadatenreads verwenden `NOLOCK`. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ProjectUnicodeText]`

Quelle: `Code/01_Common/087d_TVF_ProjectUnicodeText.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Projiziert Unicode-Langtext mit dem gemeinsamen Kürzungs- und Statusvertrag. |
| Schnittstelle | Inline TVF; Eingaben: `@Value nvarchar(max)`; `@MaxCharacters int`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ClassifyErrorLogEvent]`

Quelle: `Code/01_Common/087e_TVF_ClassifyErrorLogEvent.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ordnet begrenzt gelesene Errorlog-Ereignisse einer technischen Kategorie zu. |
| Schnittstelle | Inline TVF; Eingaben: `@ProductName varchar(32)`; `@RuleCategory varchar(80)`; `@MessageText nvarchar(max)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_InterpretPerformanceCounter]`

Quelle: `Code/01_Common/088_TVF_InterpretPerformanceCounter.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Berechnet die sichere Delta- und Resetinterpretation für Performance Counter. |
| Schnittstelle | Inline TVF; Eingaben: `@CounterType int`; `@BeforeValue bigint`; `@AfterValue bigint`; `@BaseBeforeValue bigint`; `@BaseAfterValue bigint`; `@SampleSeconds decimal(19, 6)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_InterpretContentionCounter]`

Quelle: `Code/01_Common/089_TVF_InterpretContentionCounter.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Bewertet die Counter-Differenz für interne Contention ohne einen Befund zu erzwingen. |
| Schnittstelle | Inline TVF; Eingaben: `@BeforeValue bigint`; `@AfterValue bigint`; `@RequestedSampleSeconds tinyint`; `@ActualSampleSeconds decimal(19, 6)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_InterpretAvailabilityDatabaseState]`

Quelle: `Code/01_Common/090_TVF_InterpretAvailabilityDatabaseState.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Klassifiziert den beobachteten Availability-Datenbankzustand. |
| Schnittstelle | Inline TVF; Eingaben: `@IsSuspended bit`; `@SynchronizationHealthDesc nvarchar(60)`; `@SynchronizationStateDesc nvarchar(60)`; `@LogSendQueueSizeKb bigint`; `@RedoQueueSizeKb bigint`; `@SecondaryLagSeconds bigint`; `@QueueWarnMb bigint`; `@SecondaryLagWarnSeconds int`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_InterpretAvailabilitySeedingState]`

Quelle: `Code/01_Common/091_TVF_InterpretAvailabilitySeedingState.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Klassifiziert den Status des Availability-Seeding. |
| Schnittstelle | Inline TVF; Eingaben: `@FailureCode int`; `@TransferredSizeBytes bigint`; `@DatabaseSizeBytes bigint`; `@TransferRateBytesPerSecond bigint`; `@EndTimeUtc datetime`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_InterpretAgentAlertRoute]`

Quelle: `Code/01_Common/092_TVF_InterpretAgentAlertRoute.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Interpretiert den konfigurierten SQL-Agent-Alert-Routingzustand. |
| Schnittstelle | Inline TVF; Eingaben: `@IsEnabled bit`; `@HasJobAction bit`; `@NotificationCount bigint`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_InterpretAgentJobState]`

Quelle: `Code/01_Common/093_TVF_InterpretAgentJobState.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Übersetzt den Agent-Jobstatus in eine einheitliche technische Einordnung. |
| Schnittstelle | Inline TVF; Eingaben: `@IsEnabled tinyint`; `@LatestRunStatus int`; `@LatestRunDateTime datetime`; `@CutoffLocal datetime`; `@ScheduleCount bigint`; `@EnabledScheduleCount bigint`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_InterpretDatabaseMailStatus]`

Quelle: `Code/01_Common/094_TVF_InterpretDatabaseMailStatus.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ordnet den sichtbaren Database-Mail-Zustand der Frameworkklassifikation zu. |
| Schnittstelle | Inline TVF; Eingaben: `@SentStatus varchar(8)`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Die Berechnung ist set-basiert und skaliert mit den Eingabezeilen; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ParseStatisticsIoText]`

Quelle: `Code/04_PlanCache/044_TVF_ParseStatisticsIoText.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Parst die textuelle `STATISTICS IO`-Evidenz in strukturierte Werte. |
| Schnittstelle | Multi-statement TVF; Eingaben: `@StatisticsIoText nvarchar(max)`; `@StatisticsLanguage varchar(16) = 'AUTO'`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Der Parser arbeitet sequenziell; CPU skaliert mit der Länge des Eingabetexts; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Textspalten der Rückgabe und der internen Arbeitstabellen verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ParseStatisticsTimeText]`

Quelle: `Code/04_PlanCache/045_TVF_ParseStatisticsTimeText.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Parst die textuelle `STATISTICS TIME`-Evidenz in strukturierte Werte. |
| Schnittstelle | Multi-statement TVF; Eingaben: `@StatisticsTimeText nvarchar(max)`; `@StatisticsLanguage varchar(16) = 'AUTO'`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | Der Parser arbeitet sequenziell; CPU skaliert mit der Länge des Eingabetexts; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Textspalten der Rückgabe verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. |

### `[monitor].[TVF_ExecutionPlanObjectReferences]`

Quelle: `Code/04_PlanCache/046_TVF_ExecutionPlanObjectReferences.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Extrahiert objektbezogene Referenzen aus einem Showplan-XML. |
| Schnittstelle | Inline TVF; Eingaben: `@PlanXml xml`; `@StatementId int = NULL`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | XML-Shredding skaliert mit Anzahl und Größe der übergebenen Planelemente; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. Die Textprojektionen verwenden explizit `SQL_Latin1_General_CP1_CS_AS`; der Statementfilter greift vor der Ordinalbildung. Objekt- und Indexnamen werden aus XML-Attributen entklammert, ohne Katalogauflösung. |

### `[monitor].[TVF_ExecutionPlanStatisticsUsage]`

Quelle: `Code/04_PlanCache/047_TVF_ExecutionPlanStatisticsUsage.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Extrahiert die im Showplan dokumentierte Statistikverwendung. |
| Schnittstelle | Inline TVF; Eingaben: `@PlanXml xml`; `@StatementId int = NULL`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | XML-Shredding skaliert mit Anzahl und Größe der übergebenen Planelemente; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. Die Textprojektionen verwenden explizit `SQL_Latin1_General_CP1_CS_AS`; der Statementfilter greift vor der Ordinalbildung. Compilezeitwerte werden weiterhin mit `TRY_CONVERT` gelesen; unvollständige Namensreferenzen bleiben als Zeilen mit `ParseStatus` erhalten. |

### `[monitor].[TVF_ExecutionPlanColumnReferences]`

Quelle: `Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Extrahiert Spaltenreferenzen aus dem Showplan für die Plandiagnose. |
| Schnittstelle | Inline TVF; Eingaben: `@PlanXml xml`; `@StatementId int = NULL`. Die Funktion liefert eine relationale Zeile oder Zeilenmenge und verändert keine persistenten Daten. |
| Verwendung | Die Funktion wird innerhalb öffentlicher Analysen per `JOIN`, `APPLY` oder direktem `SELECT` verwendet. Ein Direktaufruf eignet sich nur für Entwicklung und Tests, nicht als stabiler Integrationsvertrag. |
| Last und Sperren | XML-Shredding skaliert mit Anzahl und Größe der übergebenen Planelemente; die Funktion führt keine persistenten Schreiboperationen aus. Der aufrufende öffentliche Analysepfad bestimmt die Gesamtlast. |
| Vertrag | Unterstützende TVF, keine scalar-valued function. Parameter und Rückgabespalten sind interne Implementierungsdetails und können sich zusammen mit den aufrufenden Procedures ändern. Die Textprojektionen verwenden explizit `SQL_Latin1_General_CP1_CS_AS`. Die sechs Rollenpfade beginnen am materialisierten `RelOp`-Element; verschachtelte Operatoren behalten ihre eigenen `NodeId`-Werte. Nur ein fehlender oder tatsächlich leerer Spaltenname schließt die Zeile aus; ein fehlender Objektname bleibt `NULL`. |

## Interne Procedures

### `[monitor].[InternalCheckAnalysisPath]`

Quelle: `Code/01_Common/083a_USP_InternalCheckAnalysisPath.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Prüft den aktivierten fachlichen Analysepfad auf bekannte Klasse, erforderliche Bestätigung und den aktuellen Freigabepfad. Zuerst werden die Framework-Views `VW_AnalyseClassCatalog` und `VW_AnalyseAccessCurrent` gelesen. |
| Schnittstelle | Interne Stored Procedure mit vier Pflichtargumenten ohne Default. Die einzelnen Parameterverträge und die vollständige Klassenmenge folgen unten. |
| Verwendung | Versiongleiche Framework-Aufrufer führen den Helfer vor den fachlichen DMV-, Cache-, Query-Store- oder Katalogzugriffen aus. Anwendungen sollen ihn nicht direkt aufrufen oder von seiner Parameterreihenfolge abhängen. |
| Last und Sperren | Liest Framework-Katalog, Policy und über die Zugriffssicht Login-/Gruppeninformationen. Der Code setzt `LOCK_TIMEOUT 0`; fachliche Daten werden nicht persistiert. Eine eigene Wiederherstellung eines eingehenden Timeoutwerts wird nicht zugesagt. |
| Vertrag | Nicht öffentlicher, versionsgebundener Vertrag. Ein bestandenes Gate erteilt keine SQL-Berechtigungen und belegt keine Live-Abfrage von Active Directory. Nicht abgefangene native Fehler können entweichen. |

#### Parameter von InternalCheckAnalysisPath

| Parameter | Typ und Default | Eingabeform und Wirkung |
|---|---|---|
| `@AnalysisClass` | `varchar(64)`; Default: kein Default, Pflichtparameter | Ein einzelner Code der unten taxativ beschriebenen Katalogfassung 1.9.0, keine Liste und kein Pattern. NULL und leere Zeichenfolge sind ungültig; Weglassen ist nicht zulässig. Es gibt keine explizite Trim- oder Schreibweisennormalisierung; der Katalogvergleich folgt der Datenbankkollation und ist nicht fest binär oder case-insensitive. Das Policy-Wildcard `*` ist kein Katalogcode dieses Parameters. |
| `@HighImpactConfirmed` | `bit`; Default: kein Default, Pflichtparameter | `0` bestätigt keine High-Impact-Ausführung; für eine Klasse mit `RequiresGroupGate=1` folgt `HIGH_IMPACT_CONFIRMATION_REQUIRED`. `1` bestätigt diese Ausführung und setzt keine Gruppenfreigabe außer Kraft. NULL ergibt `INVALID_PARAMETER`; Leertext ist keine unterstützte Schalterform. Weglassen ist nicht zulässig. Für ungeschützte Klassen ist `0` zulässig. Auch bei `sysadmin` oder offener Policy bleibt die Bestätigung geschützter Klassen erforderlich und wird vor einer Gruppenablehnung geprüft. |
| `@StatusCode` | `varchar(40) OUTPUT`; Default: kein Default, Pflichtargument | Eingehendes NULL, Leertext oder andere Anfangswerte werden sofort durch `AVAILABLE` ersetzt. Die geschlossene Ausgabe lautet `AVAILABLE` (Klasse, erforderliche Bestätigung und Freigabepfad bestanden), `INVALID_PARAMETER` (`@AnalysisClass` ist NULL, leer oder unbekannt beziehungsweise `@HighImpactConfirmed` ist ungültig), `HIGH_IMPACT_CONFIRMATION_REQUIRED` (erforderliche Bestätigung fehlt) oder `DENIED_GROUP` (Freigabepfad nicht erlaubt). Zum Empfang eine passende Variable mit `OUTPUT` binden; ohne dieses Schlüsselwort kann der Ausgabewert verworfen werden. Das Argument darf nicht ausgelassen werden. Ausgelassene Pflichtargumente verursachen einen Aufruffehler vor der Statusinitialisierung; ein nativer Fehler ist kein zusätzlicher Statuswert. |
| `@ErrorMessage` | `nvarchar(2048) OUTPUT`; Default: kein Default, Pflichtargument | Eingehendes NULL, Leertext oder andere Anfangswerte werden sofort durch NULL ersetzt. Bei behandeltem Fehler folgt der zugehörige Meldungstext; bei `AVAILABLE` bleibt NULL. Zum Empfang eine passende Variable mit `OUTPUT` binden; ohne dieses Schlüsselwort kann der Ausgabewert verworfen werden. Das Argument darf nicht ausgelassen werden. |

#### Klassen von InternalCheckAnalysisPath

Die 31 Kennungen der ausgelieferten `VW_AnalyseClassCatalog`-Fassung 1.9.0 bilden die folgende geschlossene Menge. `RequiresGroupGate=1` löst in diesem Helfer sowohl die Bestätigungsanforderung als auch den geschützten Freigabepfad aus. Die Kataloghinweise `DefaultMaxRows` und `DefaultTimeoutSeconds` werden von diesem Helfer nicht durchgesetzt.

| Kennung | Stufe | RequiresGroupGate | Bedeutung |
|---|---|---|---|
| `STANDARD_CURRENT` | `STANDARD` | `0` | Leichtgewichtige Current-State-Abfragen für Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O. |
| `EXTENDED_CURRENT` | `ERWEITERT` | `0` | Gezielte Current-State-Vertiefung mit begrenzter SQL-Text-, Plan- und Objektauflösung. |
| `PLAN_CACHE_CURRENT` | `ERWEITERT` | `0` | Begrenzte Query-Stats- und Plan-Cache-Auswertungen ohne vollständiges XML-Shredding. |
| `SHOWPLAN_TARGETED` | `ERWEITERT` | `0` | Gezielte Showplan-Extraktion und XML-Analyse für konkret gefilterte Planhandles oder Query Hashes. |
| `OBJECT_ANALYSIS_CURRENT` | `ERWEITERT` | `0` | Gezielte Objekt-, Index-, Partitions- und Columnstore-Kataloganalyse einer Datenbank. |
| `EXTERNAL_RUNTIME_CURRENT` | `ERWEITERT` | `0` | Lesende Konfigurations-, Katalog-, Request-, Pool- und Counteranalyse externer SQL-Server-Runtimes ohne Testausführung. |
| `CLR_CURRENT` | `ERWEITERT` | `0` | Lesende SQL-CLR-Katalog-, Host-, AppDomain-, Task-, Request-, Speicher- und Counteranalyse ohne Assemblyausführung. |
| `MISSING_INDEX_CURRENT` | `ERWEITERT` | `0` | Flüchtige Missing-Index-Hinweise mit begrenzter Ergebnismenge; keine automatische DDL-Ausführung. |
| `STATISTICS_TARGETED` | `ERWEITERT` | `0` | Gezielte Statistik-Eigenschaftsanalyse für gefilterte Objekte. |
| `COLUMNSTORE_CURRENT` | `ERWEITERT` | `0` | Gezielte Columnstore-Rowgroup-Analyse über Katalogsicht ohne Segment-/Dictionary-Vollscan. |
| `LOCKS_DEEP` | `DEEP` | `1` | Detaillierte Materialisierung von sys.dm_tran_locks für die aktuell relevante Sessionmenge. |
| `LOG_VLF_DEEP` | `DEEP` | `1` | Datenbankübergreifende VLF-Auswertung über sys.dm_db_log_info. |
| `PLAN_CACHE_DEEP` | `DEEP` | `1` | Breite oder vollständige Analyse von Query Stats und Plan Cache. |
| `SHOWPLAN_XML_DEEP` | `DEEP` | `1` | XML-Analyse gecachter oder aktueller Showplans einschließlich Warnings, Spills, Objekten und Statistiken. |
| `CATALOG_DEEP` | `DEEP` | `1` | Breite Systemkatalog-, Objekt-, Index-, Statistik- und Partitionsanalyse. |
| `PHYSICAL_STATS_DEEP` | `DEEP` | `1` | Explizite Auswertung von sys.dm_db_index_physical_stats in einem bewusst gewählten Modus. |
| `INDEX_OPERATIONAL_DEEP` | `DEEP` | `1` | Breite kumulative Index-Operational-Stats mit Lock-, Latch-, I/O-Latch- und Page-Split-Zählern. |
| `QUERY_STORE_CURRENT` | `ERWEITERT` | `0` | Gezielte lesende Query-Store-Status-, Runtime-, Wait-, Plan- und Force-Auswertung mit engem Zeit- und Zeilenlimit. |
| `EXTENDED_EVENTS_CURRENT` | `ERWEITERT` | `0` | Leichte Inventarisierung vorhandener Extended-Events-Definitionen und laufender Sessions ohne Targetdaten oder Eventhistorie. |
| `QUERY_STORE_DEEP` | `DEEP` | `1` | Breite Query-Store-Historie, Regressionen, Planwechsel und Wait-Auswertungen. |
| `CROSS_DATABASE_DEEP` | `DEEP` | `1` | Datenbankübergreifende Inventarisierung und Diagnose. |
| `COLUMNSTORE_DEEP` | `DEEP` | `1` | Breite Columnstore-Analyse einschließlich Rowgroups, Deleted Rows, Dictionaries und Segmenten. |
| `EXTENDED_EVENTS_FORENSICS_DEEP` | `FORENSIK` | `1` | Optionale Auswertung vorhandener Extended-Events-Sessions und Event-Dateien; niemals Primärquelle des Standardlaufs. |
| `SERVER_HEALTH_CURRENT` | `ERWEITERT` | `0` | CPU-, NUMA-, Memory-, TempDB-, OS- und Dienstzustand der aktuellen Instanz. |
| `SERVER_CONFIGURATION_CURRENT` | `ERWEITERT` | `0` | Lesende Serverkonfiguration, Trace Flags und Startup-Parameter. |
| `SECURITY_CONFIGURATION_CURRENT` | `ERWEITERT` | `0` | Lesende sicherheits- und dienstbezogene Betriebsparameter. |
| `SQL_AGENT_CURRENT` | `ERWEITERT` | `0` | Lesende SQL-Server-Agent-Status-, Job-, Schedule- und Historienanalyse aus msdb. |
| `RESOURCE_GOVERNOR_CURRENT` | `ERWEITERT` | `0` | Lesende Resource-Governor-Konfigurations- und Laufzeitanalyse. |
| `HA_DR_CURRENT` | `ERWEITERT` | `0` | Begrenzte lesende Analyse von Availability Groups, Backup, Log Shipping, Replication, CDC und Change Tracking. |
| `ENTERPRISE_TOPOLOGY_DEEP` | `DEEP` | `1` | Vertiefte enterpriseweite Topologie- und Distribution-Analyse für HA/DR und Replication. |
| `DATA_PLATFORM_ADAPTER_CURRENT` | `ERWEITERT` | `0` | Optionale Current-State-Anreicherung aus kundenspezifischen Data-Platform-/ETL-Loggingobjekten mit isolierter Existenz- und Rechteprüfung. |

Nur die Fehlernummern `229`, `371` und `916` im initialen TRY-Zugriff auf die Framework-Views führen zum datenbankgebundenen Fallback; andere Fehler werden erneut ausgelöst. Auch Katalog- und Policyzugriffe im Fallback können nativ fehlschlagen. Der Fallback erlaubt ungeschützte Klassen, einen erkannten `sysadmin` oder den Fall ohne global aktive Policyzeilen. Aktiv sind Zeilen mit `IsEnabled=1`, `ValidFromUtc` NULL oder nicht später als `SYSUTCDATETIME()`, `ValidToUtc` NULL oder später als diese UTC-Zeit sowie nichtleeren, mit `LTRIM/RTRIM` geprüften Klassen- und Gruppennamen. Die Prüfung entfernt diese Randzeichen nicht aus den gespeicherten Werten.

Eine aktive Policy für eine andere Klasse kann im Fallback bereits zur Ablehnung einer geschützten Klasse führen, wenn der serverseitige Token im Datenbankkontext nicht lesbar ist. Eine einzelne Gruppenmitgliedschaft wird dort nicht geprüft. Die High-Impact-Bestätigung bleibt unabhängig davon erforderlich. Die normale Zugriffssicht und der Fallback sind keine SQL-Rechtevergabe oder allgemeine Umwandlung nativer Fehler in Statuswerte.

### `[monitor].[InternalWriteResultTable]`

Quelle: `Code/01_Common/095_USP_InternalWriteResultTable.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Schreibt die Spaltenwerte eines bereits materialisierten Analyseergebnisses in eine vorhandene lokale Ergebnistabelle. Eine leere Zieltabelle mit genau einer beliebigen Dummy-Spalte kann an die Quelle angepasst werden; ein passendes Ziel erhält die Zeilen als Anhang. |
| Schnittstelle | Interne Stored Procedure. Die Einzelverträge der sieben Parameter einschließlich Typ, Default, Eingabeform, NULL- und Leerwertverhalten, Statusmenge sowie OUTPUT-Bindung stehen in der folgenden Parametertabelle. |
| Verwendung | Öffentliche Procedures im Schema `monitor` rufen diesen Baustein zur Orchestrierung auf. Anwendungen sollen ihn weder direkt ausführen noch von seiner Parameterreihenfolge oder seinen temporären Zwischenstrukturen abhängen. |
| Last und Sperren | Quelle und Ziel sind vorhandene lokale `#Temp`-Tabellen. Fremde Tabellenoperationen verwenden `LOCK_TIMEOUT 0`; eigene lokale Temp-DDL erhält bei eingehendem Timeout 0 je Anlage bis zu 1000 ms. Positive und unbegrenzte Eingangswerte bleiben während der eigenen Anlage erhalten. Die temporäre Markierungs-DDL verändert Quelle und Ziel. |
| Vertrag | Nicht öffentlicher, an den versiongleichen internen Framework-Aufrufer gebundener Vertrag. Die Procedure garantiert weder eine Transaktion noch atomaren Rollback oder Bereinigung nach Fehlern. |

| Parameter | Typ und Default | Vertrag |
|---|---|---|
| `@SourceTable` | `sysname`; Default: kein Default, Pflichtparameter | Erwartet einen unqualifizierten, ungetrimmten Namen einer vorhandenen lokalen `#`-Temp-Tabelle. NULL, Leerwert, fehlendes `#`, `##` und `LEN` größer als 116 nach SQL-Server-Bindung sind ungültig. Es wird nativ quotiert; Schema- oder Klammerausdrücke sind keine Eingabeform. Quell- und Zielname werden ohne Beachtung der Groß-/Kleinschreibung verglichen. `#Monitor` ist als Quellpräfix nicht reserviert. |
| `@TargetTable` | `sysname`; Default: kein Default, Pflichtparameter | Erwartet einen unqualifizierten, ungetrimmten Namen einer vorhandenen lokalen `#`-Temp-Tabelle. NULL, Leerwert, fehlendes `#`, `##` und `LEN` größer als 116 nach SQL-Server-Bindung sind ungültig. Es wird nativ quotiert; Schema- oder Klammerausdrücke sind keine Eingabeform. `#Monitor` ist als Zielpräfix ohne Beachtung der Groß-/Kleinschreibung reserviert. Quell- und Zielname dürfen nicht identisch sein. |
| `@InsertedRows` | `bigint`; Default NULL; optional OUTPUT | Der Eingabewert wird ignoriert und nach der internen Temp-Tabellenanlage auf 0 gesetzt. Bei Erfolg enthält er `@@ROWCOUNT` des abschließenden `INSERT SELECT`, nicht eine unabhängig ermittelte Gesamtzahl der Zielhistorie. Ein gebundener Empfänger braucht eine bigint-Variable mit OUTPUT; das Argument darf ausgelassen werden. |
| `@StatusCode` | `varchar(40)`; Default NULL; optional OUTPUT | Der Eingabewert wird ignoriert und nach der internen Temp-Tabellenanlage auf `AVAILABLE` gesetzt. Die geschlossene Wertemenge lautet: `AVAILABLE` (erfolgreich), `INVALID_PARAMETER` (ungültige Parameter), `LOCK_TIMEOUT` (abgefangener Timeout bei Markierung, Leerheitsprüfung oder Schemaanpassung), `SOURCE_NOT_FOUND` (Quelle nicht auflösbar), `TARGET_NOT_FOUND` (Ziel nicht auflösbar), `METADATA_NOT_VISIBLE` (Katalogzeile nicht sichtbar), `UNSUPPORTED_SOURCE_SCHEMA` (nicht unterstützte Quelle), `TARGET_SCHEMA_MISMATCH` (Zielstruktur nicht passend/anpassbar) und `TABLE_WRITE_ERROR` (sonstiger abgefangener Tabellenfehler). Fehler 1222 beim finalen INSERT SELECT ergibt `TABLE_WRITE_ERROR`. Zum Empfang ist eine varchar(40)-Variable mit OUTPUT zu binden; das Argument darf ausgelassen werden. |
| `@ErrorNumber` | `int`; Default NULL; optional OUTPUT | Der Eingabewert wird ignoriert und nach der internen Temp-Tabellenanlage auf NULL gesetzt. Bei einem abgefangenen nativen Fehler enthält er dessen Fehlernummer; bei Validierungsfehlern ohne nativen Fehler bleibt er NULL. Nicht abgefangene Fehler, einschließlich eines Fehlers vor dieser Initialisierung, sind nicht über diesen Parameter zugesichert. Zum Empfang ist eine int-Variable mit OUTPUT zu binden; das Argument darf ausgelassen werden. |
| `@ErrorMessage` | `nvarchar(2048)`; Default NULL; optional OUTPUT | Der Eingabewert wird ignoriert und nach der internen Temp-Tabellenanlage auf NULL gesetzt. Bei einem behandelten Fehler enthält er Validierungs- oder Fehlerdiagnostik; bei Erfolg bleibt er NULL. Zum Empfang ist eine nvarchar(2048)-Variable mit OUTPUT zu binden; das Argument darf ausgelassen werden. |
| `@ThrowOnError` | `bit`; Default 0; optional Eingabe | Auslassen verwendet Default 0. Leerer Text ist keine unterstützte Schalterform. 0 gibt behandelte Fehler über die OUTPUT-Parameter zurück; 1 löst bei einem behandelten Fehler Fehlernummer 51010 aus. NULL ist ungültig, ergibt `INVALID_PARAMETER` und löst selbst keinen Fehler 51010 aus. Nicht alle nativen Fehler werden abgefangen und umgewandelt. |

Die vier OUTPUT-Parameter werden erst nach der eigenen Temp-DDL initialisiert; bei einem Fehler davor werden keine neu gesetzten Werte zugesichert.

Die Quelle darf keine berechneten Spalten, benutzerdefinierten oder
Assembly-Datentypen, typisiertes XML sowie timestamp-/rowversion-Spalten
enthalten. Quellidentitätswerte werden in gewöhnliche Zielspalten kopiert; eine
Identitätseigenschaft wird nicht übertragen. Ein passendes Ziel muss hinsichtlich
Spaltenanzahl und -reihenfolge, Name, vergleichbarem Typ, Länge, Genauigkeit,
Skala, Sortierung und NULL-Zulässigkeit übereinstimmen und darf keine
Identitäts- oder berechneten Spalten, benutzerdefinierten oder
Assembly-Datentypen oder typisiertes XML enthalten. Eine abweichende Zielstruktur
wird nur bei einer leeren Tabelle mit genau einer Dummy-Spalte angepasst.
Passende Ziele müssen nicht leer sein und werden beschrieben, indem Zeilen
angehängt werden. Markierungs-DDL, Leerheitsprüfung und Schemaanpassung können
bei Fehler sichtbare Änderungen hinterlassen; eine Transaktions-, Rollback- oder
Cleanup-Garantie besteht nicht.

Bei bereits abgefangenen Fehlern mit `StatusCode=LOCK_TIMEOUT` und
`ErrorNumber=1222` nennt `ErrorMessage` zusätzlich `TargetTable` und `SqlStep`.
`TargetTable` ist der übergebene logische Temp-Tabellenname als JSON-Zeichenfolge;
Prozentzeichen werden für die Fehlerweitergabe als `\u0025` kodiert.
Die Schrittkennungen `SOURCE_MARKER_ADD`, `SOURCE_MARKER_DROP`,
`TARGET_MARKER_ADD` und `TARGET_MARKER_DROP` bezeichnen die temporären
Auflösungsmarkierungen. `TARGET_EMPTY_CHECK` bezeichnet die Leerheitsprüfung;
`TARGET_SCHEMA_ADAPT` umfasst den bestehenden vierteiligen `ALTER TABLE`-Batch.
Bei `@ThrowOnError=1` bleiben Fehlernummer 51010 und das Präfix
`TABLE-Ausgabe fehlgeschlagen (LOCK_TIMEOUT): ` erhalten. Der Kontext steht vor
dem ursprünglichen Fehlertext, damit er innerhalb der Grenze von 2048 Zeichen
erhalten bleibt. Er benennt weder einen Blocker noch die Sperrressource und
enthält keinen SQL-Text. Ohne passende Stichprobe bleibt die CI-Einstufung
`BLOCKER_NOT_CAPTURED`.

### `[monitor].[InternalPrepareResultTables]`

Quelle: `Code/01_Common/096_USP_InternalPrepareResultTables.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Prüft die angeforderten Zuordnungen und hängt sie an die vom Aufrufer bereitgestellte Mapping-Temp-Tabelle an. |
| Schnittstelle | Interne Stored Procedure; Parameter: `@ResultTablesJson nvarchar(max)`; `@AllowedResultNames nvarchar(max)`; `@MappingTable sysname`; `@StatusCode varchar(40) = NULL OUTPUT`; `@ErrorMessage nvarchar(2048) = NULL OUTPUT`; `@ThrowOnError bit = 0`. |
| Verwendung | Öffentliche Procedures im Schema `monitor` rufen diesen Baustein im versiongleichen internen Ablauf auf. Anwendungen sollen ihn nicht direkt ausführen. |
| Last und Sperren | Erzeugt lokale Prüftabellen und prüft vorhandene lokale Ziele mit NOWAIT; eigene Temp-DDL erhält je Anlage bei eingehendem Timeout 0 bis zu 1000 ms. Zielprüfung fügt temporär eine Marker-Spalte hinzu und entfernt sie best effort. Es werden keine Framework- oder Snapshot-Daten persistiert. |
| Vertrag | Nicht öffentlicher, versionsgebundener Vertrag. Mapping-Zeilen werden angehängt; vorhandene Mapping-Zeilen bleiben bestehen. Es gibt keine atomare Transaktions- oder Rollback-Zusage. |

#### Parameterverträge

| Parameter | Typ und Default | Eingabeform, NULL/leer/ausgelassen und Wirkung |
|---|---|---|
| `@ResultTablesJson` | `nvarchar(max)`; Default: kein Default, Pflichtparameter | JSON-Objekt, keine Liste. NULL, leerer Text, `{}` und Objekt ohne Zuordnung sind ungültig. Werte und Schlüssel müssen Zeichenketten sein. Schlüssel und Ziele werden vor Guards nach `sysname` konvertiert. Schlüssel ohne Vorab-Trim werden binär exakt verglichen; doppelte konvertierte Schlüssel sind ungültig. |
| `@AllowedResultNames` | `nvarchar(max)`; Default: kein Default, Pflichtparameter | Pipe-getrennte offene Liste des Aufrufers. NULL, leer oder nur leere Tokens bedeutet keine erlaubten Namen. `|` wird nicht escaped. Nur U+0020 an Tokengrenzen wird entfernt; leere Tokens ignoriert. Tokens werden nach `sysname` konvertiert und binär verglichen. Doppelte konvertierte Tokens können beim ungeschützten INSERT einen nativen Fehler auslösen. |
| `@MappingTable` | `sysname`; Default: kein Default, Pflichtparameter | NULL oder leer ungültig; kein Trimmen. Roher, unqualifizierter Name ohne Klammer- oder Schemaangabe einer vorhandenen lokalen `#Temp`-Tabelle, kein `##`, maximal 116 Zeichen nach sysname-Konvertierung. Aufrufer erstellt sie mit `ResultName sysname` und `TargetTable sysname`. TOP (0) prüft Lookup/Konvertierung, nicht das exakte physische Schema. |
| `@StatusCode` | `varchar(40)`; Default: `NULL OUTPUT` | OUTPUT-Variable vom Typ `varchar(40)`; nach eigener DDL auf `AVAILABLE` gesetzt; eingehende NULL-, Leertext- oder andere Werte werden überschrieben. AVAILABLE = erfolgreich; INVALID_PARAMETER = ungültiger Schalter/Mappingname; INVALID_RESULT_TABLE_MAPPING = JSON-/Namens-/Duplikat-/Whitelistfehler; INVALID_RESULT_TABLE_TARGET = fehlendes, nicht leeres oder nicht genau eine Seed-Spalte enthaltendes oder nicht sicher prüfbares Ziel; INTERNAL_ERROR = Mapping-Spalten nicht auflösbar/konvertierbar. Auslassen setzt den Default; Empfang erfordert Caller-Variable mit OUTPUT. |
| `@ErrorMessage` | `nvarchar(2048)`; Default: `NULL OUTPUT` | OUTPUT-Variable vom Typ `nvarchar(2048)`; nach eigener DDL auf NULL, bei erkanntem Fehler auf Meldung gesetzt; eingehende NULL-, Leertext- oder andere Werte werden überschrieben. Auslassen setzt den Default; Empfang erfordert Caller-Variable mit OUTPUT. |
| `@ThrowOnError` | `bit`; Default: `0` | 0 unterdrückt behandelte Preflightfehler und gibt Status/Meldung zurück; 1 wirft dafür 51011. NULL ist ungültig, ergibt INVALID_PARAMETER, wirft wegen NULL aber nicht 51011. Leerer Text ist keine unterstützte Bit-Eingabe; ausgelassen gilt 0. Unbehandelte native Fehler werden nicht unterdrückt. |

JSON-Zielwerte werden nach sysname-Konvertierung als rohe, unqualifizierte lokale #Temp-Namen geprüft: kein ##, kein #Monitor-Präfix (CI), LEN höchstens 116. Es wird nicht getrimmt; doppelte Ziele werden CI verglichen. Klammer- und Schemanamen sind unzulässig. Ziele müssen vorbestehen, leer sein und genau eine Seed-Spalte haben. Marker-ADD und -DROP sind temporäre Schemaänderungen; Bereinigung im Fehlerpfad ist best effort. Keine permanente Spaltenanpassung oder atomare Rücknahmezusage.

Eigene Temp-DDL liegt vor Initialisierung der Status-OUTPUTs. Die Allowed-Liste wird ohne TRY/CATCH eingefügt; doppelte konvertierte Tokens können nativ fehlschlagen. Das finale Mapping-INSERT liegt ebenfalls außerhalb TRY/CATCH. Solche Fehler können entweichen. Bei ThrowOnError 1 werden nur behandelte Fehler als 51011 geworfen.

### `[monitor].[InternalPrepareSingleResultTable]`

Quelle: `Code/01_Common/097_USP_InternalPrepareSingleResultTable.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Leitet eine TABLE-Zuordnung an den Mehrfach-Preflight weiter und gibt bei erfolgreicher Auflösung ein Ziel zurück. |
| Schnittstelle | Interne Stored Procedure; Parameter: `@ResultTablesJson nvarchar(max)`; `@ResultName sysname`; `@TargetTable sysname OUTPUT`; `@ThrowOnError bit = 1`. |
| Verwendung | Öffentliche Procedures im Schema `monitor` rufen diesen Baustein im versiongleichen internen Ablauf auf. Anwendungen sollen ihn nicht direkt ausführen. |
| Last und Sperren | Erzeugt die lokale Mapping-Temp-Tabelle und delegiert Zielprüfung mit NOWAIT; die Prüfung fügt am Ziel temporär eine Marker-Spalte hinzu und entfernt sie best effort. Eigene Mapping-DDL erhält 1000 ms. Es werden keine Framework- oder Snapshot-Daten persistiert. |
| Vertrag | Nicht öffentlicher, versionsgebundener Vertrag. Gibt das aufgelöste Ziel zurück; richtet keine dauerhafte Ergebnisspaltenstruktur ein. Es gibt keine atomare Transaktions- oder Rollback-Zusage. |

#### Parameterverträge

| Parameter | Typ und Default | Eingabeform, NULL/leer/ausgelassen und Wirkung |
|---|---|---|
| `@ResultTablesJson` | `nvarchar(max)`; Default: kein Default, Pflichtparameter | JSON-Objekt, keine Liste; NULL, leerer Text, `{}` oder kein Paar ist ungültig. Mehrere Paare werden nicht grundsätzlich ausgeschlossen. Schlüssel und Werte müssen Zeichenketten sein; der Mehrfachbaustein konvertiert sie vor Guards zu `sysname`. Zielwerte sind rohe, unqualifizierte lokale `#Temp`-Namen ohne Klammer- oder Schemaangabe, kein `##` und kein `#Monitor`-Präfix (CI), `LEN` höchstens 116 nach Konvertierung. Namen/Ziele werden nicht getrimmt; Schlüssel müssen binär der erlaubten Liste entsprechen. Doppelte Schlüssel sind binär, doppelte Ziele unter `Latin1_General_100_CI_AS` unzulässig. |
| `@ResultName` | `sysname`; Default: kein Default, Pflichtparameter | Wird als Allowed-Liste weitergereicht. NULL, leer oder leere Tokens ergibt keine erlaubten Namen. `|` ohne Escape; nur U+0020 an Tokengrenzen wird entfernt. Der spätere Lookup nutzt den ursprünglichen Wert unter CS-Kollation, daher kann Normalisierung trotz AVAILABLE ohne Treffer bleiben. |
| `@TargetTable` | `sysname`; Default: kein Default, OUTPUT, Pflichtparameter | Argument muss angegeben werden; zum Empfang wird eine Variable mit OUTPUT gebunden. Eingabewert wird ignoriert und beim Eintritt auf NULL gesetzt. Bei behandeltem Fehler oder fehlendem originalen CS-Treffer bleibt NULL. Ein übergebener NULL-, Leertext- oder anderer Anfangswert wird ignoriert. |
| `@ThrowOnError` | `bit`; Default: `1` | 0 unterdrückt behandelte Fehler; 1 lässt den Mehrfachbaustein 51011 werfen. NULL wird als INVALID_PARAMETER behandelt, löst aber nicht 51011 aus. Leerer Text ist keine unterstützte Bit-Eingabe; ausgelassen gilt 1. Unbehandelte native Fehler entweichen. |

Der Mehrfachbaustein verlangt ein bestehendes, leeres lokales #Temp-Ziel mit genau einer Seed-Spalte. Temporärer Marker-ADD/DROP verändert das Zielschema während der Prüfung; Bereinigung ist best effort. Es gibt keine permanente Ergebnisspaltenanpassung und keine atomare Rücknahmezusage. Eigene Mapping-DDL liegt vor Statusinitialisierung; Fehler werden erneut ausgelöst. Danach setzt der Baustein LOCK_TIMEOUT 0.

### `[monitor].[InternalEmitConsoleResult]`

Quelle: `Code/01_Common/098_USP_InternalEmitConsoleResult.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Rendert aus der materialisierten lokalen Temp-Tabelle eine Fachansicht oder Leerzeile. |
| Schnittstelle | Interne Stored Procedure: drei Pflichtparameter ohne Default und zwei INPUT-Parameter mit Default NULL; keine OUTPUTs. Für den unveränderten versionsgleichen internen Frameworkcaller, nicht für Anwendungs-Direktaufrufe. |
| `@SourceTable` | sysname; Default: keiner; Pflichtargument. Einzelner roher unqualifizierter lokaler #Name. NULL, fehlendes #, ##Name oder LEN(Name)>116 lösen 51012 aus; keine Liste/SQL-Expression. Kein Existenz-/Schematest. |
| `@ResultLabel` | nvarchar(200); Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM trimmt U+0020; NULL oder Leerwert nach Trim wird Ergebnis. Für nichtleere Quelle Wert in [Ergebnis]. |
| `@EmptyMessage` | nvarchar(200); Default: keiner; Pflichtargument. Unicode-Text. LTRIM/RTRIM trimmt U+0020; NULL oder Leerwert nach Trim wird Keine Ergebnisse. Für leere Quelle Wert in [Ergebnis]. |
| `@StatusCode` | varchar(40); Default: NULL; INPUT. Im Leerfall unverändert als [Status]; NULL/Leer bleiben. Keine Enum- oder Whitelist-Prüfung. |
| `@StatusMessage` | nvarchar(2048); Default: NULL; INPUT. Im Leerfall unverändert als [Hinweis]; NULL/Leer bleiben. |
| Verwendung | Bei nichtleerer Quelle genau ein Resultset mit [Ergebnis] und src.*. Bei leerer Quelle genau eine Zeile mit [Ergebnis], [Status] und [Hinweis]; Statusinputs werden nur dann unverändert ausgegeben. |
| Last und Sperren | LOCK_TIMEOUT 0. Erzeugt keine Temp-Tabelle und greift nicht auf fachliche Systemquellen zu. |
| Vertrag | Keine Sortierung oder Kappung; StatusCode hat keine feste Whitelist. Der Statuscode ist ein unverändert weitergereichter Text ohne eigene Wertemengenprüfung. |

### `[monitor].[InternalProjectUnicodeTextColumn]`

Quelle: `Code/01_Common/098_USP_InternalProjectUnicodeTextColumn.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Projiziert eine bereits materialisierte nvarchar(max)-Spalte, aktualisiert Metadaten und überschreibt den Text IN PLACE. |
| Schnittstelle | Interne Stored Procedure mit acht Pflichtparametern ohne Default: fünf sysname, int-Grenze und zwei bigint OUTPUTs. Nur für den unveränderten, versionsgleichen internen Frameworkcaller; keine Anwendungs-Direktaufrufe. |
| `@SourceTable` | sysname; Default: keiner; Pflichtargument. Einzelner roher unqualifizierter lokaler #Name. NULL, fehlendes # oder ##Name lösen 51021 aus; keine Liste/SQL-Expression. Kein eigener 116-Zeichen-Check; keine Existenz-/Schema-Vorprüfung. |
| `@TextColumn` | sysname; Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL 51021; QUOTENAME angewandt. Erwartet materialisierte nvarchar(max)-Textspalte, die IN PLACE überschrieben wird. |
| `@CharactersColumn` | sysname; Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL 51021; QUOTENAME angewandt. Ziel bigint OriginalCharacters je Zeile: SC-Zeichenanzahl des Originalwerts einschließlich nachgestellter Leerzeichen; Surrogatpaar zählt als ein Zeichen. |
| `@BytesColumn` | sysname; Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL 51021; QUOTENAME angewandt. Ziel bigint OriginalBytes je Zeile, gemessen durch DATALENGTH des Originalwerts. |
| `@IsTruncatedColumn` | sysname; Default: keiner; Pflichtargument. Einzelner roher Spaltenbezeichner; NULL 51021; QUOTENAME angewandt. Ziel bit IsTruncated je Zeile gemäß TVF_ProjectUnicodeText. |
| `@MaxCharacters` | int; Default: keiner; Pflichtargument. Negativ 51021. NULL passiert Guard und bedeutet wie 0 unbegrenzt; positiv setzt TVF-Limit auf diese Anzahl SC-Zeichen. Die TVF zählt jedes Surrogatpaar als ein Zeichen und teilt es nicht; keine Graphemgarantie. |
| `@TruncatedValueCount` | bigint OUTPUT; Default: keiner; Pflichtargument. Binden mit @TruncatedValueCount=@bigintVariable OUTPUT. Nach Guard 0; danach COUNT_BIG nur gekürzter Zeilen; ohne Kürzung 0. |
| `@LargestRequiredCharacters` | bigint OUTPUT; Default: keiner; Pflichtargument. Binden mit @LargestRequiredCharacters=@bigintVariable OUTPUT. Nach Guard NULL; danach MAX OriginalCharacters nur gekürzter Zeilen; ohne Kürzung NULL. |
| Verwendung | Caller materialisiert die vollständige fachliche Quelle vorab. Die Abhängigkeit monitor.TVF_ProjectUnicodeText zählt unter Latin1_General_100_CI_AS_SC Surrogatpaare als ein Zeichen, zählt nachgestellte Leerzeichen, liefert Bytes als DATALENGTH und garantiert keine Grapheme. |
| Last und Sperren | LOCK_TIMEOUT 0; dynamisches UPDATE der lokalen Caller-Tabelle. Keine eigene Transaktion oder CATCH-Behandlung. |
| Vertrag | Alle drei Metadaten werden für alle Zeilen geschrieben. Nach Guard OUTPUTs 0/NULL; danach COUNT_BIG/MAX ausschließlich gekürzter Zeilen, ohne Kürzung 0/NULL. Leere/fehlende/typinkompatible Spalten werden nicht vorab geprüft und können normale dynamische SQL-Fehler auslösen. |

### `[monitor].[InternalEmitTruncationWarning]`

Quelle: `Code/01_Common/099_USP_InternalEmitTruncationWarning.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Gibt genau eine technische Severity-10-Warning aus, wenn die Ausgabe aktiviert ist und der Zähler positiv ist. Die Nachricht wird intern durch nvarchar(2048) begrenzt; eine vollständige Clientanzeige ist nicht zugesichert. |
| Schnittstelle | Interne Stored Procedure ohne fachliches Resultset und ohne OUTPUT-Parameter. Die vier ersten Eingabeparameter sind Pflichtargumente; `@PrintMeldungen bit` hat den expliziten Default `1`. |
| `@TruncatedValueCount` | `bigint`, Default: keiner; Pflichtargument. Der Caller meldet damit die Anzahl gekürzter Werte; der Helper ermittelt diese Anzahl nicht selbst und gleicht sie nicht mit Quelldaten ab. Bei NULL, 0 oder negativen Werten wird keine Meldung ausgegeben; nur ein Wert größer 0 kann eine Meldung auslösen. Der Wert wird als Zählertext angezeigt. |
| `@ParameterName` | `sysname`, Default: keiner; Pflichtargument und ausschließlich Textlabel; es erfolgt keine Objektauflösung und keine SQL-Ausführung. NULL wird im ersten Textvorkommen zu `<unbekannter Parameter>` und im Vorschlag zu `den begrenzenden Parameter`. Ein leerer Wert wird nicht ersetzt. |
| `@ParameterValue` | `int`, Default: keiner; Pflichtargument und ausschließlich angezeigter Wert; NULL erscheint als `NULL`. Es gibt keine fachliche Bereichsvalidierung. |
| `@LargestRequiredCharacters` | `bigint`, Default: keiner; Pflichtargument. Der Caller meldet damit den größten benötigten Zeichenbedarf; der Helper berechnet oder prüft diesen Wert nicht. Der Parameter ist ausschließlich angezeigter Bedarfs- und Vorschlagswert. NULL erscheint im Bedarfstext als `NULL` und im Vorschlag als `0`. Negative und inkonsistente Werte werden nicht geprüft. |
| `@PrintMeldungen` | `bit`, Default `1`. 0 oder NULL unterdrückt die Meldung; 1 erlaubt eine Meldung, wenn `@TruncatedValueCount` positiv ist. Die normale SQL-bit-Konvertierung kann von 0 verschiedene konvertierbare Zahlen auf 1 abbilden. |
| Verwendung | Ausschließlich für den versiongleichen internen Frameworkcaller vorgesehen. Anwendungen sollen den Baustein weder direkt ausführen noch von Parameterreihenfolge oder temporären Zwischenstrukturen abhängen. |
| Last und Sperren | Die Procedure führt `SET LOCK_TIMEOUT 0` aus und erzeugt bei erfüllter Bedingung ein `RAISERROR` mit Severity 10, State 1 und `WITH NOWAIT`. Es werden keine Parameterwerte verändert; der Helper berechnet weder Kürzungen noch deren Anzahl und prüft keinen objektbezogenen Grenzvertrag. |
| Vertrag | Nicht öffentlicher Vertrag für den versiongleichen internen Frameworkcaller. Genau dann, wenn `COALESCE(@PrintMeldungen,0)=1` und `COALESCE(@TruncatedValueCount,0)>0` gilt, wird ein `RAISERROR` ausgeführt; sonst erfolgt keine Meldung. Die Nachricht wird mit `CONCAT` und `LEFT` auf `nvarchar(2048)` begrenzt. Es wird keine vollständige Clientanzeige und keine Wiederherstellung von `SET`-Einstellungen zugesichert. |

### `[monitor].[InternalParseXmlText]`

Quelle: `Code/01_Common/099a_USP_InternalParseXmlText.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Parst Text defensiv zu XML und liefert dafür einen strukturierten Status. |
| Schnittstelle | Interne Stored Procedure; Parameter: `@XmlText nvarchar(max)`; `@XmlValue xml = NULL OUTPUT`; `@StatusCode varchar(40) = NULL OUTPUT`; `@ErrorNumber int = NULL OUTPUT`; `@ErrorMessage nvarchar(2048) = NULL OUTPUT`. Status-, Fehler- und weitere OUTPUT-Parameter werden ausschließlich zwischen Frameworkbausteinen weitergereicht. |
| `@XmlText` | Eingabe vom Typ nvarchar(max) in der von CONVERT(xml, ...) unterstützten nativen XML-Syntax. Default: keiner; Pflichtargument. NULL beendet die Verarbeitung mit SOURCE_NULL. Für nicht-NULL Werte ist XML_EMPTY nur der erfolgreiche Status, wenn LTRIM/RTRIM mit U+0020 einen leeren Wert ergibt; sonst ist der erfolgreiche Status AVAILABLE. Tabs werden nicht pauschal als XML_EMPTY behandelt. |
| `@XmlValue` | OUTPUT vom Typ xml; Default: NULL. Ein bestehender Empfängerwert wird zu Beginn auf NULL gesetzt. Bei erfolgreicher Konvertierung wird der native XML-Wert geliefert, auch bei XML_EMPTY; bei SOURCE_NULL oder gefangenem Fehler bleibt der Wert NULL. |
| `@StatusCode` | OUTPUT vom Typ varchar(40); Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert und neu gesetzt. Normale Endstatus: SOURCE_NULL bedeutet NULL-Quellwert; XML_EMPTY bedeutet erfolgreiche Konvertierung bei leerem LTRIM/RTRIM(U+0020)-Ergebnis; AVAILABLE bedeutet erfolgreiche Konvertierung bei nichtleerem Ergebnis; XML_UNAVAILABLE_LIMIT bedeutet gefangener Fehler 6335, 6336 oder 6337; XML_INVALID bedeutet jeder andere gefangene Fehler. PENDING ist ausschließlich der initiale Zwischenwert vor CONVERT und kein normaler Endstatus. |
| `@ErrorNumber` | OUTPUT vom Typ int; Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert und neu gesetzt. Bei einem gefangenen Fehler enthält der Wert ERROR_NUMBER(); sonst bleibt er NULL. |
| `@ErrorMessage` | OUTPUT vom Typ nvarchar(2048); Default: NULL. Ein bestehender Empfängerwert wird als Eingabe ignoriert und neu gesetzt. Bei einem gefangenen Fehler enthält der Wert den nativen ERROR_MESSAGE()-Text, begrenzt durch den Empfängertyp nvarchar(2048); sonst bleibt er NULL. |
| OUTPUT-Bindung | OUTPUT-Werte werden mit @Parameter=@typisierteVariable OUTPUT gebunden. Wird ein optionales OUTPUT-Argument ausgelassen, empfängt der Aufrufer dafür keine Daten. |
| Verwendung | Öffentliche Procedures im Schema `monitor` rufen diesen Baustein zur Orchestrierung auf. Anwendungen sollen ihn weder direkt ausführen noch von seiner Parameterreihenfolge oder seinen temporären Zwischenstrukturen abhängen. |
| Last und Sperren | Die Procedure koordiniert interne Verarbeitung ohne fachliche Persistenz unter `LOCK_TIMEOUT 0`. Sie darf nur über den zugehörigen öffentlichen Einstieg ausgeführt werden. |
| Vertrag | Nicht öffentlicher Vertrag. Fehlerbehandlung, OUTPUT-Parameter und Seiteneffekte sind nur für den versiongleichen internen Aufrufer zugesichert. |

### `[monitor].[InternalCaptureCurrentStateSnapshot]`
Quelle: `Code/02_CurrentState/005_InternalCaptureCurrentStateSnapshot.sql`
| Dimension | Beschreibung |
|---|---|
| Aufgabe | Die Procedure materialisiert angeforderte DMV- und SQL-Textdaten einmalig in den lokalen Temp-Tabellen des aufrufenden Orchestrators. Nicht aktivierte Quellen werden nicht angefordert. |
| Schnittstelle | Interne Stored Procedure mit ausschließlich INPUT-Parametern. Der Aufrufer legt den Temp-Table-Vertrag Version 2 an und besitzt dessen Lebensdauer. |
| Verwendung | `USP_CurrentOverview` ruft die Procedure vor den Children für Sessions, Requests, Blocking, Waits, Transactions, Memory Grants, TempDB und I/O auf. Einzelne Children erhalten keine Parent-ID und lesen ihre Quellen frisch. |
| Last und Sperren | Read-only unter `LOCK_TIMEOUT 0`. Aktivierte Quellen werden in separaten TRY/CATCH-Blöcken erfasst; ein Fehler einer Quelle wird als Source-Status festgehalten. Das garantiert keine globale Atomarität über alle Quellen. |
| Vertrag | Der dynamische Probezugriff bestätigt die Existenz der benannten lokalen Temp-Tabellen, nicht deren vollständiges Spaltenschema. Die Procedure schreibt Context- und Source-Status-Daten in die vom Aufrufer angelegten Temp-Tabellen; die 20 Zieltabellen werden nicht von der Procedure angelegt. Es gibt keine OUTPUT-Parameter. |
| Snapshot-ID | Eine im aktuellen Context bereits vorhandene `@SnapshotId` wird als Duplikat abgelehnt; außerdem werden NULL und der Temp-Table-Vertrag geprüft. Der Null-GUID ist technisch zulässig; die Aufruferkonvention verlangt eine frische ID. |

Jeder Parameter ist ein einzelner skalarer INPUT. `@SnapshotId` ist erforderlich und hat keinen Default. Nur optionale Parameter können ausgelassen werden; dann gilt der jeweilige Default. Nicht zutreffende Text- oder Listenformen sind nicht vorgesehen. SQL Server konvertiert Argumente vor Prozedureintritt in den deklarierten Typ.

| Parameter | Datentyp | Eingabeform | Default | NULL- und Leerwertregel | Zulässige Werte und Wirkung |
|---|---|---|---|---|---|
| `@SnapshotId` | `uniqueidentifier` | ein einzelner GUID-Skalar | keiner | NULL wird abgelehnt; eine leere Zeichenfolge ist keine GUID-Eingabe. | Jeder uniqueidentifier-Wert ist syntaktisch zulässig, auch 00000000-0000-0000-0000-000000000000. Der Aufrufer verwendet gemäß Konvention eine frische ID. Eine bereits im aktuellen Context vorhandene ID wird zusätzlich als Duplikat abgelehnt. |
| `@CaptureSessions` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst Sessions aus sys.dm_exec_sessions. |
| `@CaptureRequests` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst laufende Requests aus sys.dm_exec_requests. |
| `@CaptureConnections` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst Connections aus sys.dm_exec_connections. |
| `@CaptureWaitingTasks` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst wartende Tasks aus sys.dm_os_waiting_tasks. |
| `@CaptureMemoryGrants` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst Memory Grants und Resource Semaphores. |
| `@CaptureResourceGovernor` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst Workload Groups, Resource Pools und zugehörige TempDB-Governance-Daten, soweit Version und verfügbare Quellenspalten dies erlauben. |
| `@CaptureTasks` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst Tasks aus sys.dm_os_tasks, gefiltert auf bereits erfasste Requests. |
| `@CaptureSchedulers` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst Scheduler zu IDs bereits erfasster Requests oder Tasks. |
| `@CaptureTransactions` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst Session-, aktive und Datenbanktransaktionen zu bereits erfassten Sessions. |
| `@CaptureTempDbUsage` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst Session-Nutzung zu bereits erfassten Sessions und Task-Nutzung zu bereits erfassten Requests. |
| `@CaptureVersionStore` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst traditionellen und persistenten Version Store innerhalb des Sessions-Zweigs. |
| `@CaptureSqlText` | `bit` | ein einzelner nach Typkonvertierung als bit übergebener Wert | 0 | NULL wird abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in bit. | 0 lässt die Quelle aus; 1 erfasst SQL-Text zu deduplizierten Handles bereits erfasster Requests und Connections; diese Quellen werden nicht automatisch aktiviert. |
| `@MaxSqlTextHandles` | `int` | eine Ganzzahl von 0 bis 2147483647 als Skalar | 1000 | NULL und negative konvertierte Werte werden abgelehnt. Leere Textwerte sind keine vorgesehene Eingabeform; SQL Server konvertiert Argumente vor Prozedureintritt in int. | 0 bedeutet keine Begrenzung. Ein positiver Wert begrenzt deterministisch auf die nach binärem SqlHandle sortierten unterschiedlichen Handles. Der Wert wird auch bei @CaptureSqlText=0 validiert. |

Für die zwölf `bit`-Schalter gelten die konvertierten Werte `0` und `1`: `0` überspringt die jeweilige Quelle, `1` aktiviert sie. SQL Server kann andere Quellwerte vor Prozedureintritt in diese Werte konvertieren; beispielsweise wird ein numerischer Wert ungleich null zu `1`. Die Prüfung schließt solche Quellwerte nicht generell aus. NULL wird bei jedem Schalter abgelehnt. Die Procedure erhält bereits einen bit-Wert; die Typkonvertierung erfolgt vor ihrer Validierung. Ein ausgelassener Schalter verwendet `Default: 0`.

Abhängigkeiten innerhalb der Capture-Zweige werden nicht automatisch aktiviert. `@CaptureVersionStore=1` wird im Sessions-Zweig verarbeitet und benötigt deshalb auch `@CaptureSessions=1`. `@CaptureTasks=1` benötigt bereits erfasste Requests. `@CaptureSchedulers=1` bezieht Scheduler nur aus IDs bereits erfasster Requests oder Tasks. `@CaptureTransactions=1` benötigt bereits erfasste Sessions. `@CaptureTempDbUsage=1` begrenzt Session-Nutzung auf erfasste Sessions und Task-Nutzung auf erfasste Requests. `@CaptureSqlText=1` nimmt Handles nur aus bereits erfassten Requests und Connections; es aktiviert `@CaptureRequests` oder `@CaptureConnections` nicht.

Die Memory-Grants-Erfassung umfasst zusätzlich die Resource-Semaphores. Die Resource-Governor-Erfassung passt TempDB-Governance-Daten an SQL-Server-Version und verfügbare Quellenspalten an. Der Statuscode der `WORKLOAD_GROUPS`-Quelle und der pro Workload Group gespeicherte TempDB-Governance-Status sind getrennte Angaben; eine verfügbare Workload-Group-Quelle garantiert keine verfügbare Governance-Aussage. Bei SQL-Text begrenzt `@MaxSqlTextHandles=0` nicht; ein positiver Wert begrenzt deterministisch die deduplizierten Handles nach binärer `SqlHandle`-Sortierung. Der Wert wird auch bei `@CaptureSqlText=0` validiert.

Der Status der SQL-TEXT-Quelle beschreibt die Erfassung des Zweigs. Der Evidenzstatus `TEXT_UNAVAILABLE` beschreibt einen einzelnen Handle ohne verfügbaren Text und kann zusammen mit erfolgreichem SQL_TEXT-Quellstatus vorkommen.

### `[monitor].[InternalCollectExecutionPlanMetadata]`

Quelle: `Code/04_PlanCache/049_InternalCollectExecutionPlanMetadata.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Die Procedure ermittelt zu einem XML-Ausführungsplan aktuelle Statistikmetadaten katalogauflösbarer Objekte. Sie kann Statistiken nach Planverwendung, relevanten führenden Spalten oder allen Statistiken der Planobjekte auswählen und Histogrammschritte, Zusammenfassungen sowie Prädikatzuordnungen sammeln. |
| Schnittstelle | Interne Stored Procedure mit 13 Parametern. Jeder Eintrag nennt Typ, Eingabeform, Default, NULL-/Leerwertverhalten und Wirkung. |
| Verwendung | Der versiongleiche Ausführungsplan-Evidenzgenerator ruft sie mit fünf zuvor angelegten lokalen Temp-Tabellen auf. Direkte Aufrufe müssen dasselbe Schema und denselben Ausführungskontext bereitstellen. Ergebnisse liegen in diesen Caller-Temp-Tabellen; Anwendungen sollen nicht von internen Zwischenstrukturen oder einer stabilen internen Schnittstelle abhängen. |
| Last und Sperren | Die Procedure liest Planreferenzen und passende Datenbank-, Objekt-, Statistik- und Histogrammkataloge. RELEVANT, OBJECT_ALL und STEPS benötigen High-Impact-Bestätigung; wenn monitor.InternalCheckAnalysisPath existiert, wird zusätzlich CATALOG_DEEP geprüft. Das Statistiklimit greift erst nach vollständigem Sammeln der Kandidaten und verhindert die anfängliche Kandidaten-Katalogabfrage nicht. Das Histogrammlimit zählt vorhandene Caller-Zeilen mit und begrenzt zusätzliche Zeilen global. LOCK_TIMEOUT wird am Anfang auf 0 gesetzt; der Wiederherstellungswert wird erst danach erfasst, sodass am Ende 0 statt eines vorherigen Aufruferwerts gilt. Wird eine Datenbank erst bei der späteren Statistikabfrage unzugänglich, hat dieser Schleifenzweig keinen ELSE-Statusdatensatz; Vollständigkeit ist daher nicht zugesichert. |
| Vertrag | Nicht öffentlicher Vertrag. Ergebnisse werden in #CreateExecutionEvidenceJson_StatisticsCurrent, #CreateExecutionEvidenceJson_HistogramSteps, #CreateExecutionEvidenceJson_HistogramSummary, #CreateExecutionEvidenceJson_PredicateHistogramMappings und #CreateExecutionEvidenceJson_CollectionStatus geschrieben. Die fünf TOP (0)-Proben geben fünf leere Resultsets aus und prüfen Existenz/Schemaauflösung, nicht vollständiges Schema oder Berechtigungen. Behandelte Fehler können nach Einfügungen partielle Ergebnisse hinterlassen; atomare Ausführung und vollständige Katalogerfassung sind nicht zugesichert. |
| Fehlergrenzen | SET LOCK_TIMEOUT 0 erfolgt vor allen Prüfungen und gilt innerhalb der Procedure auch auf frühen Rückgabepfaden. Die eigene Wiederherstellungsanweisung im Hauptteil verwendet den danach gespeicherten Wert 0, keine vor Eintritt gesicherte Kopie. Der optionale Gate-Aufruf und sein Katalogzugriff liegen vor dem Hauptteil-TRY; dort unerwartet weitergeworfene Fehler können ohne Umsetzung in die globalen Fehlerausgaben entweichen. |
| Parameter | Optional ausgelassene Eingabeparameter verwenden den Signatur-Default. Bei bit-Eingaben kann ein numerischer Nichtnullwert ungleich 0 bereits bei SQL Server Typkonvertierung zu 1 werden. |
| `@PlanXml` | xml; Default: keiner, obligatorisch. Eingabeform: einzelner XML-Wert oder gebundene XML-Variable. NULL ergibt INVALID_PARAMETER. Leeres, gültiges XML wird nicht ausdrücklich abgewiesen. |
| `@StatistikEvidenzModus` | varchar(16); Default: 'USED'. Eingabeform: einzelner Modus-Textwert, keine Liste. NULL wird zu USED; äußere Leerzeichen werden entfernt und der Text in Großbuchstaben umgewandelt. Leertext oder nur Leerzeichen ist ungültig. Endliche Werte: USED sammelt nur vom Plan gemeldete verwendete Statistiken; RELEVANT ergänzt Statistiken, deren führende Spalte im Plan als SEEK, RESIDUAL, JOIN, ORDER_BY oder GROUP_BY vorkommt; OBJECT_ALL ergänzt alle Statistiken katalogauflösbarer Planobjekte. RELEVANT und OBJECT_ALL benötigen High-Impact-Bestätigung. |
| `@HistogrammModus` | varchar(16); Default: 'NONE'. Eingabeform: einzelner Modus-Textwert, keine Liste. NULL wird zu NONE; äußere Leerzeichen werden entfernt und der Text in Großbuchstaben umgewandelt. Leertext oder nur Leerzeichen ist ungültig. Endliche Werte: NONE fügt im Hauptteil keine zusätzlichen Schritte ein; SUMMARY und STEPS sammeln Schritte und bilden Zusammenfassungen, wobei STEPS zusätzlich High-Impact-Bestätigung verlangt. Die Sammlung ist bei SUMMARY und STEPS gleich. Vorhandene Zeilen in der Caller-Schritttabelle werden auch bei NONE zusammengefasst und können zugeordnet werden. Bei SUMMARY und STEPS werden gesammelte Schritte in die Caller-Schritttabelle eingefügt. |
| `@QuellumgebungBestaetigt` | bit; Default: 0. Eingabeform: einzelner SQL-bit-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt die Quellumgebung, 0 bestätigt nicht; ausgelassen wird 0 verwendet und INVALID_PARAMETER gemeldet. NULL wird nicht ausdrücklich mit IS NULL geprüft: NULL <> 1 ist UNKNOWN und kann die anfängliche Ablehnung passieren. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und wie fehlende Bestätigung abgelehnt. |
| `@MitPredicateHistogramMap` | bit; Default: 1. Eingabeform: einzelner SQL-bit-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 ordnet extrahierte Planparameterwerte Histogrammschritten zu, 0 überspringt die Zuordnung. NULL wird nicht ausdrücklich mit IS NULL geprüft, passiert die NOT IN-Prüfung wegen UNKNOWN und überspringt später die Zuordnung, da nur = 1 ausgeführt wird. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert und überspringt die Zuordnung. |
| `@MaxStatistiken` | int; Default: 100. Eingabeform: einzelner SQL-int-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 1 bis 1000 einschließlich; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt Kandidaten insgesamt nach Priorität PLAN_USED, dann RELEVANT_LEADING_COLUMN, danach übrige; innerhalb der Auswahl wird nach Datenbank, Schema, Objekt und Statistikname sortiert. RELEVANT/OBJECT_ALL-Kandidaten werden vor dem Limit aus dem Katalog gelesen. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und liegt außerhalb des gültigen Bereichs. |
| `@MaxHistogrammSchritte` | int; Default: 20000. Eingabeform: einzelner SQL-int-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 200000 einschließlich; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Begrenzt zusätzlich eingefügte Schritte über alle Datenbanken. Vorhandene Zeilen in #CreateExecutionEvidenceJson_HistogramSteps werden mitgezählt; 0 fügt keine neuen Schritte ein. Bei erreichtem oder überschrittenem Limit werden keine weiteren eingefügt und vorhandene Zeilen nicht entfernt. Das Limit setzt nicht selbst IsPartialOut. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert und fügt keine neuen Schritte ein. |
| `@LockTimeoutMs` | int; Default: 0. Eingabeform: einzelner SQL-int-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Ganze Zahl 0 bis 60000 Millisekunden einschließlich; NULL und Werte außerhalb ergeben INVALID_PARAMETER. Steuert LOCK_TIMEOUT im Hauptteil. Da vorher bereits LOCK_TIMEOUT 0 gesetzt und erst danach gespeichert wird, wird am Ende 0 statt eines vorherigen Sitzungswerts wiederhergestellt. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; 0 Millisekunden bedeutet kein Warten auf eine Sperre. |
| `@HighImpactConfirmed` | bit; Default: 0. Eingabeform: einzelner SQL-bit-Wert oder Variable; leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. SQL-bit-Eingabe: 1 bestätigt den Pfad, 0 nicht. Für RELEVANT, OBJECT_ALL und STEPS führt 0 zu HIGH_IMPACT_CONFIRMATION_REQUIRED; SUMMARY allein verlangt die Bestätigung nicht. NULL wird in der anfänglichen NOT IN-Prüfung nicht ausdrücklich abgefangen; <> 1 blockiert NULL lokal ebenfalls nicht. Der optionale Gate-Helper kann NULL als INVALID_PARAMETER zurückweisen. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; für einen breiten Pfad fehlt damit die Bestätigung. |
| `@StatusCodeOut` | varchar(40); Default: NULL OUTPUT. Eingabeform: einzelner varchar-Wert/Skalar oder OUTPUT-Variable; NULL und Leertext sind erlaubt und werden ignoriert. Eingehender Wert wird ignoriert und zuerst auf AVAILABLE gesetzt. Lokal mögliche Werte: AVAILABLE, INVALID_PARAMETER, INTERNAL_ERROR, HIGH_IMPACT_CONFIRMATION_REQUIRED, PARTIAL, LOCK_TIMEOUT und ERROR_HANDLED; Gate-Statuswerte INVALID_PARAMETER (ungültige Klasse/Bestätigung), HIGH_IMPACT_CONFIRMATION_REQUIRED (Bestätigung fehlt) und DENIED_GROUP (Pfad nicht freigegeben) werden weitergereicht. Zum Empfangen Variable passenden Typs mit OUTPUT binden; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. AVAILABLE bedeutet regulär beendet ohne gesetztes Teilfehlerflag, nicht vollständige Metadaten; INVALID_PARAMETER bedeutet lokal erkannter ungültiger Parameter oder ein entsprechendes Gate-Ergebnis; INTERNAL_ERROR bedeutet Fehler einer Temp-Tabellenprobe; HIGH_IMPACT_CONFIRMATION_REQUIRED bedeutet fehlende Bestätigung des breiten Pfads; PARTIAL bedeutet verzeichneten Teilfehler bei ansonsten regulärem Ende; LOCK_TIMEOUT bedeutet Fehler 1222 im äußeren Hauptteil-CATCH; ERROR_HANDLED bedeutet einen anderen Fehler in diesem CATCH; DENIED_GROUP bedeutet vom Gate nicht freigegebenen CATALOG_DEEP-Pfad. Das Gate kann INVALID_PARAMETER insbesondere bei NULL-Bestätigung oder ungültiger/unbekannter Analyseklasse liefern. |
| `@IsPartialOut` | bit; Default: NULL OUTPUT. Eingabeform: einzelner SQL-bit-Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert, zuerst 0 und bei Teil- oder Fehlerausgabe 1. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu bit 0 konvertiert; der Eingang wird wie NULL ignoriert. |
| `@ErrorNumberOut` | int; Default: NULL OUTPUT. Eingabeform: einzelner SQL-int-Wert/Skalar oder OUTPUT-Variable; NULL ist erlaubt und wird ignoriert, leere Zeichenfolge ist keine vorgesehene Typform und wird vor Eintritt konvertiert. Eingehender Wert wird ignoriert und zunächst auf NULL gesetzt. Bei abgefangenen Fehlern enthält er ERROR_NUMBER(); bei Parameter-, Gate- und PARTIAL-Statuswerten kann er NULL bleiben. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. Leerer Zeichenfolgeneingang wird vor Eintritt zu int 0 konvertiert; der Eingang wird wie NULL ignoriert. |
| `@ErrorMessageOut` | nvarchar(2048); Default: NULL OUTPUT. Eingabeform: einzelner nvarchar-Wert/Skalar oder OUTPUT-Variable; NULL und Leertext sind erlaubt und werden ignoriert. Eingehender Wert wird ignoriert und zunächst auf NULL gesetzt. Lokale Parameterfehler, Temp-Tabellenprobe, Gate-Rückgabe und Hauptteil-CATCH setzen die jeweilige Meldung. Bei AVAILABLE sowie PARTIAL durch Einzelquellenfehler kann er NULL bleiben; Details stehen dann im CollectionStatus. Zum Empfangen passende Variable mit OUTPUT; ohne OUTPUT kann typgerechter Skalar übergeben und Ausgabe verworfen werden. |

### `[monitor].[InternalAnalyzeExecutionPlan]`

Quelle: `Code/04_PlanCache/051_InternalAnalyzeExecutionPlan.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Führt die interne Regel- und Evidenzanalyse eines Showplan-XML durch. |
| Schnittstelle | Interne Stored Procedure; Parameter: `@AnalysisObjectId int`; `@PlanXml xml`; `@PlanSource varchar(24)`; `@RuntimeCounterScope varchar(32)`; `@WorkloadProfile varchar(32) = 'BALANCED'`; `@MinSeverity varchar(16) = 'INFO'`; `@EvidenceJson nvarchar(max) = NULL`; `@MitThreadRuntime bit = 0`; `@EvidenzDatenschutzModus varchar(24) = 'DERIVED_ONLY'`; `@IdentifierDatenschutzModus varchar(16) = 'RAW'`; `@StatusCodeOut varchar(40) = NULL OUTPUT`; `@IsPartialOut bit = NULL OUTPUT`; `@ErrorNumberOut int = NULL OUTPUT`; `@ErrorMessageOut nvarchar(2048) = NULL OUTPUT`. Status-, Fehler- und weitere OUTPUT-Parameter werden ausschließlich zwischen Frameworkbausteinen weitergereicht. |
| Verwendung | Öffentliche Procedures im Schema `monitor` rufen diesen Baustein zur Orchestrierung auf. Anwendungen sollen ihn weder direkt ausführen noch von seiner Parameterreihenfolge oder seinen temporären Zwischenstrukturen abhängen. |
| Last und Sperren | Die Procedure schreibt nur in die ausdrücklich vorgesehenen Framework-, Snapshot- oder lokalen Ergebnisspeicher und kann lokale Temp-Tabellen materialisieren, unter `LOCK_TIMEOUT 0`. Sie darf nur über den zugehörigen öffentlichen Einstieg ausgeführt werden. |
| Vertrag | Nicht öffentlicher Vertrag. Fehlerbehandlung, OUTPUT-Parameter und Seiteneffekte sind nur für den versiongleichen internen Aufrufer zugesichert. |

### `[snapshot].[InternalConfigureSnapshotPolicy]`

Quelle: `Code/10_SnapshotBaseline/020_InternalConfigureSnapshotPolicy.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Prüft den Aufrufvertrag und schreibt typisierte Collector- sowie optional die gemeinsame DEFAULT-Retentionpolicy. |
| Schnittstelle | Interne Stored Procedure; vollständige Parameterverträge folgen. OUTPUT-Werte sind für versiongleiche interne Aufrufer bestimmt. |
| Verwendung | Öffentliche Procedures im Schema monitor orchestrieren den Aufruf. Anwendungen sollen ihn nicht direkt ausführen oder von Parameterreihenfolge und Zwischenstrukturen abhängen. |
| Last und Sperren | Aktualisiert vorhandene Policyzeilen in der verbundenen Snapshot-Datenbank unter `LOCK_TIMEOUT 0`. Sie fügt keine Zeilen ein, erfasst oder bereinigt keine Daten und führt kein DDL aus. |
| Vertrag | Interner, versionsgebundener Vertrag; Transaktions-, Identitäts-, Status- und Fehlergrenzen richten sich nach Aufrufpfad. |

#### Parametervertrag für InternalConfigureSnapshotPolicy

| Parameter | Datentyp | Default | Eingabeform und Wirkung |
| --- | --- | --- | --- |
| `@CollectionIntervalSeconds` | smallint | Kein Default; Pflichtargument | Erwartet eine ganze Sekundenzahl von 1 bis 3600. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |
| `@MaxRows` | int | Kein Default; Pflichtargument | Erwartet eine ganze Zeilenzahl von 1 bis 100000. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |
| `@PayloadEnabled` | bit | Kein Default; Pflichtargument | 0 speichert eine deaktivierte Payloadpolicy, 1 eine aktivierte Payloadpolicy. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Im erweiterten Pfad wird NULL ausdrücklich zurückgewiesen. Im Legacy-Pfad gibt es keine ausdrückliche NULL-Prüfung; NULL kann die Bereichsprüfung passieren und erst beim NOT-NULL-Schreiben einen abgefangenen Fehler auslösen. |
| `@RawRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@PayloadRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@RollupRetentionDays` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 3650 Tagen. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@SoftBudgetMB` | int | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 2147483647 MB. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@PurgeIntervalMinutes` | smallint | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zahl von 1 bis 1440 Minuten. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@PurgeBatchRows` | int | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 gilt eine ganze Zeilenzahl von 1 bis 100000 als gespeicherte Purge-Batchgröße. Das Argument darf nicht ausgelassen werden; leerer Text ist keine unterstützte Eingabeform. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück; im Legacy-Pfad kann NULL die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL ignoriert; das Argument bleibt erforderlich. |
| `@BudgetAction` | varchar(32) | Kein Default; Pflichtargument | Bei wirksamem `@UpdateSharedPolicy`=1 ist ausschließlich `PURGE_EXPIRED_THEN_STOP` zulässig; dies bezeichnet die gespeicherte Aktion zur Bereinigung abgelaufener Daten vor einem budgetbedingten Sammelstopp. Die Procedure speichert den Wert, führt selbst jedoch keine Bereinigung aus. Das Argument darf nicht ausgelassen werden. Bei wirksamem `@UpdateSharedPolicy`=1 ist Leertext ungültig; erweiterte Aufrufe weisen NULL ausdrücklich zurück. Im Legacy-Pfad kann NULL die Dreiwertlogik der Wertprüfung passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Bei `@UpdateSharedPolicy`=0 wird der Wert einschließlich NULL oder Leertext ignoriert; das Argument bleibt erforderlich. |
| `@StatusCodeOut` | varchar(40) OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um den Wert zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf `AVAILABLE` zurückgesetzt. Geschlossene Statuswerte: `AVAILABLE` (verfügbar/erfolgreich), `INVALID_PARAMETER` (ungültiger Parameter oder Aufrufvertrag), `TARGET_UNAVAILABLE` (Zielidentität oder Paket nicht verfügbar), `DENIED_PERMISSION` (abgefangener Berechtigungsfehler), `ERROR_HANDLED` (sonstiger abgefangener Fehler). |
| `@ErrorNumberOut` | int OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um die Nummer oder NULL zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf NULL zurückgesetzt. Frühe Vertragsfehler setzen 51011 und RETURN 51011; Bereichsfehler setzen keine Fehlernummer und führen dieses RETURN nicht aus. 53764 bezeichnet eine abweichende Zielidentität, 53761 einen fehlenden erweiterten Paketvertrag und 53781 die fehlende `FILE_IO`-Version. Abgefangene Fehler 229, 262, 297, 300 und 371 ergeben `DENIED_PERMISSION`; sonstige abgefangene Fehler ergeben `ERROR_HANDLED`. Fehler 53700 bezeichnet eine fehlende Collectorzeile. Nicht alle nativen Fehler werden abgefangen; die Fehlernummer ist daher kein geschlossenes Set. |
| `@ErrorMessageOut` | nvarchar(2048) OUTPUT | Kein Default; Pflichtargument | Das Argument darf nicht ausgelassen werden. Eine gebundene Variable muss mit OUTPUT übergeben werden, um Meldung oder NULL zu empfangen; ohne OUTPUT wird die Ausgabe verworfen. Eingehende NULL-, Leer- oder sonstige Anfangswerte werden ignoriert; die Variable wird auf NULL zurückgesetzt. Bei behandelten Fehlern enthält der Parameter den Meldungstext; bei regulärem Erfolg bleibt NULL. Identitäts-, Paket- und Modulprüfungen können vor TRY zurückkehren. |
| `@CollectorCode` | varchar(64) | `'PERFORMANCE_COUNTERS'` | Ein einzelner Code, keine Liste und kein Pattern. Beim Auslassen gilt der Default `PERFORMANCE_COUNTERS`. Normalisierung erfolgt mit UPPER(LTRIM(RTRIM(COALESCE(Wert,'')))); getrimmt wird das SQL-Leerzeichen U+0020. NULL sowie leerer oder nur aus Leerzeichen bestehender Text werden zu leer und sind ungültig; sie lösen nicht den Default aus. Zulässige Werte und Bedeutung: `PERFORMANCE_COUNTERS` (Performance Counter), `WAIT_STATS` (Wartestatistik), `FILE_IO` (Datei-I/O). |
| `@CollectorEnabled` | bit | 1 | Default 1. 0 deaktiviert die Collectorpolicy, 1 aktiviert sie. NULL ist ungültig; leerer Text ist keine unterstützte Eingabeform. Das Argument kann wegen des Defaults ausgelassen werden. Der Wert konfiguriert nur die Policy und startet keine Erfassung. |
| `@UpdateSharedPolicy` | bit | NULL | Beim Auslassen gilt Default NULL. NULL wählt automatisch 1 für `PERFORMANCE_COUNTERS` und 0 für `WAIT_STATS`/`FILE_IO`. 0 aktualisiert nur den Collector, erhält dessen bestehendes RetentionPolicyCode und ignoriert alle sieben Shared-Parameter einschließlich NULL; diese Argumente bleiben dennoch erforderlich. 1 aktualisiert die `DEFAULT`-Retentionpolicy und weist dem Collector `DEFAULT` zu; dies wirkt auf weitere Collector, die `DEFAULT` verwenden. Erweiterte Aufrufe weisen NULL für wirksame Shared-Werte ausdrücklich zurück. Im Legacy-Pfad können NULL-Werte die Dreiwertlogik der Bereichsprädikate passieren und beim NOT-NULL-Schreiben als abgefangener Fehler enden. Leertext ist keine unterstützte Eingabeform. Konfigurationswerte starten keine Erfassung oder Bereinigung. |
| `@ExpectedTargetDatabaseId` | int | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Die ID muss größer als 4 und gleich `DB_ID()` der aktuell verbundenen Datenbank sein. Leertext ist keine unterstützte Eingabeform. |
| `@ExpectedTargetDatabaseName` | sysname | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Verglichen wird der rohe Datenbankname binär exakt mit `master.sys.databases.name`, ohne Trim oder Groß-/Kleinschreibungsnormalisierung. Ein leerer Name kann den Vergleich nicht erfüllen. |
| `@ExpectedTargetCreateDate` | datetime | NULL | Default NULL; das Argument kann ausgelassen werden. Für `PERFORMANCE_COUNTERS` darf das gesamte Identitätstripel auch im erweiterten Pfad NULL sein. `WAIT_STATS`/`FILE_IO` benötigen ID, Name und CreateDate; sobald irgendein Identitätsfeld ungleich NULL ist, müssen alle drei vorliegen. Leertext ist keine unterstützte Datumseingabe. Erwartet wird der typisierte, als datetime erfasste Erstellungswert; er muss exakt dem als datetime erfassten `master.sys.databases.create_date` entsprechen; keine UTC-Konvertierung. Die Zieldatenbank muss ONLINE und schreibbar sein. Das Tripel schützt vor Wiederverwendung einer Datenbank; die Procedure wechselt die Datenbank nicht. |
| `@JoinFrameworkTransaction` | bit | 0 | Default 0; das Argument kann ausgelassen werden. NULL ist ungültig; leerer Text ist keine unterstützte Eingabeform. 1 ist nur für `WAIT_STATS`/`FILE_IO` bei wirksamem `@UpdateSharedPolicy`=1, genau einer committable Callertransaktion (`XACT_STATE()`=1) und `IMPLICIT_TRANSACTIONS` OFF zulässig. Der Eigentümer behält COMMIT/ROLLBACK; bei Join=1 erstellt die Procedure keinen Savepoint. Bei Join=0 verlangen erweiterte `WAIT_STATS`/`FILE_IO`-Aufrufe keine Callertransaktion. Alle erweiterten Aufrufe verlangen `IMPLICIT_TRANSACTIONS` OFF. Erweiterte `PERFORMANCE_COUNTERS`-Aufrufe können eine eigene Transaktion oder bei Callertransaktion einen Savepoint nutzen; Rollback zum Savepoint erfolgt ausschließlich bei `XACT_STATE()`=1. Der Legacy-Standardaufruf `PERFORMANCE_COUNTERS` mit CollectorEnabled=1, wirksamem Shared=1 (explizit oder automatisch), allen Identitätswerten NULL und Join=0 führt BEGIN TRANSACTION und bei Erfolg COMMIT TRANSACTION auch innerhalb einer bestehenden Transaktion aus; CATCH kann die gesamte Callertransaktion zurückrollen. Andere gültige Einstellungen wählen erweiterte Prüfungen; die optionale PC-Identität allein aktiviert sie nicht. |

#### Transaktionspfade von InternalConfigureSnapshotPolicy

Der Legacy-Standardaufruf PERFORMANCE_COUNTERS mit @CollectorEnabled=1, wirksamem @UpdateSharedPolicy=1 (explizit oder automatisch), vollständig NULL gesetzter Identität und @JoinFrameworkTransaction=0 führt BEGIN TRANSACTION und bei Erfolg COMMIT TRANSACTION auch innerhalb einer bestehenden Transaktion aus; bei einem Fehler kann CATCH die gesamte Callertransaktion zurückrollen. Andere gültige Einstellungen wählen erweiterte Prüfungen; eine vollständig NULL gelassene PC-Identität allein aktiviert diese Prüfungen nicht. Alle erweiterten Pfade verlangen IMPLICIT_TRANSACTIONS OFF. Erweiterte WAIT_STATS/FILE_IO-Aufrufe mit Join=0 verlangen keine Callertransaktion. Join=1 ist nur für WAIT_STATS/FILE_IO mit Shared=1 und genau einer committable Callertransaktion (XACT_STATE()=1) zulässig; der Eigentümer führt COMMIT/ROLLBACK aus und die Procedure erstellt keinen Savepoint. Erweiterte PERFORMANCE_COUNTERS-Aufrufe können eine eigene Transaktion oder bei Callertransaktion einen Savepoint verwenden; ein Savepoint-Rollback erfolgt nur bei XACT_STATE()=1.

Der erweiterte Paketvertrag erfordert genau eine SC-023-Zeile mit 1.2.1/Schema 2 oder 1.3.0 beziehungsweise 1.3.1/Schema 3, InternalCompleteWaitStatsCycle und InternalPurgeExpiredData mit @ContractOnly. FILE_IO verlangt 1.3.1/Schema 3; der Meldungstext nennt historisch 1.3.0. Die vorhandene CollectorPolicy muss genau eine Zeile liefern, sonst Fehler 53700.

Das Identitätstripel darf für PERFORMANCE_COUNTERS auch in erweiterten Aufrufen vollständig NULL sein; WAIT_STATS/FILE_IO erfordern es, ebenso jeder Aufruf mit mindestens einem gesetzten Identitätsfeld. Erweiterte Aufrufe weisen NULL für wirksame Werte ausdrücklich zurück. Im Legacy-Pfad können NULL bei CollectionIntervalSeconds, MaxRows, PayloadEnabled oder Shared-Werten wegen SQL-Dreiwertlogik die Bereichsprüfung passieren und erst beim NOT NULL-Schreiben im CATCH scheitern. Frühe Vertragsfehler setzen 51011 und RETURN 51011; Bereichsfehler führen dieses RETURN nicht aus und setzen keine Fehlernummer. Identitäts-/Paket-/Modulprüfungen erfolgen vor TRY; nicht alle nativen Fehler werden abgefangen.

### `[snapshot].[InternalPrepareCollectionCycle]`

Quelle: `Code/10_SnapshotBaseline/040_InternalPrepareCollectionCycle.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Prüft Zielidentität, Collectorvertrag, Aktivierung, Datenbudget und Fälligkeit; eröffnet abhängig vom Collector einen Lauf oder gibt einen Policy-Status zurück. |
| Schnittstelle | Interne Stored Procedure mit zwölf Parametern. Die vier OUTPUT-Parameter sind `@CaptureRunIdOut` bigint OUTPUT, `@ShouldCollectOut` bit OUTPUT, `@StatusCodeOut` varchar(40) OUTPUT und `@ErrorMessageOut` nvarchar(2048) OUTPUT; die übrigen acht sind Eingaben. |
| Verwendung | Öffentliche Procedures im Schema monitor rufen den Baustein zur Orchestrierung auf. Anwendungen sollen ihn nicht direkt ausführen und nicht von Parameterreihenfolge oder internen Zwischenstrukturen abhängen. |
| Last und Sperren | Liest Richtlinien, Laufhistorie, Zieldatenbankmetadaten und außerhalb PolicyOnly die Größe aktueller Datenbankdateien. Kann CaptureRun und bei nicht sammelndem PERFORMANCE_COUNTERS ModuleStatus schreiben. Setzt LOCK_TIMEOUT 0; keine eigene Transaktion und kein CATCH für native Fehler. |
| Vertrag | Nicht öffentlicher Vertrag für versiongleiche interne Aufrufer. Keine globale Serialisierung oder atomare Mehrstatement-Ausführung zugesichert. |

#### Parameter von InternalPrepareCollectionCycle

| Parameter | Vertrag |
|---|---|
| `@SourceDatabaseName` | sysname; **Default: Kein Default. Weglassen ist nicht zulässig.** Obligatorischer Rohname und reines Label der Quellmetadaten; keine Validierung einer existierenden Datenbank, kein Datenbankwechsel oder Lookup. Leertext wird beim INSERT gespeichert. NULL scheitert nur bei einem tatsächlich ausgeführten INSERT an NOT NULL; ohne INSERT wird er nicht geschrieben. |
| `@SchedulerType` | varchar(16); **Default: Kein Default. Weglassen ist nicht zulässig.** Pflichtwert MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) oder SQL_AGENT (SQL Server Agent). Herkunftslabel, startet/verifiziert keinen Scheduler. Keine explizite Normalisierung. NULL, leer oder ungültig kann beim INSERT an NOT NULL/CHECK scheitern; ohne INSERT ungenutzt. |
| `@RunEvenIfNotDue` | bit; **Default: Kein Default. Weglassen ist nicht zulässig.** 0 prüft Due, 1 übergeht nur Due. Leerer Text ist keine unterstützte Schalterform. NULL wird nicht validiert und umgeht durch den =0-Test ebenfalls Due. Disabled-, Budget- und Target-Gates bleiben wirksam. |
| `@CaptureRunIdOut` | bigint OUTPUT; **Default: Kein Default. Weglassen ist nicht zulässig.** Eintritt NULL, Eingang ignoriert; ohne OUTPUT wird die Ausgabe verworfen. Zum Empfang ist eine gebundene Variable als OUTPUT-Argument erforderlich. ID erst nach INSERT. Performance-Counter-Abbrüche durch Disabled/Budget/Due schreiben beendeten partiellen Lauf samt ModuleStatus; ID ist kein Sammlungsbeweis. Wait/File frühe Abbrüche ohne ID; PolicyOnly immer ohne Lauf/ID. |
| `@ShouldCollectOut` | bit OUTPUT; **Default: Kein Default. Weglassen ist nicht zulässig.** Eintritt 0, Eingang ignoriert; ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang ist eine gebundene Variable als OUTPUT-Argument erforderlich. Nach INSERT nur bei AVAILABLE 1; PolicyOnly bleibt 0. |
| `@StatusCodeOut` | varchar(40) OUTPUT; **Default: Kein Default. Weglassen ist nicht zulässig.** Eintritt AVAILABLE, Eingang ignoriert; ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang ist eine gebundene Variable als OUTPUT-Argument erforderlich. Genau AVAILABLE (bereit), INVALID_PARAMETER (ungültiger Collector/PolicyOnly/Wait-Transaktionszustand), TARGET_UNAVAILABLE (Ziel/Vertrag nicht verfügbar), DISABLED (Policy deaktiviert/fehlt), STOPPED_SIZE_BUDGET (Budget überschritten), SKIPPED_NOT_DUE (Intervall offen). RUNNING ist CaptureRun-Zeilenstatus, kein Ausgabe-Enum; native Fehler werden nicht allgemein übersetzt. |
| `@ErrorMessageOut` | nvarchar(2048) OUTPUT; **Default: Kein Default. Weglassen ist nicht zulässig.** Eintritt NULL, Eingang ignoriert; ohne OUTPUT kann die Ausgabe verworfen werden. Zum Empfang ist eine gebundene Variable als OUTPUT-Argument erforderlich. Statusdiagnose oder NULL; native SQL-Fehler können direkt abbrechen. |
| `@CollectorCode` | varchar(64); **Default: PERFORMANCE_COUNTERS. Weglassen verwendet PERFORMANCE_COUNTERS.** NULL wird leer, dann UPPER und Entfernen äußerer U+0020-Leerzeichen. Exakt PERFORMANCE_COUNTERS (Performance Counter), WAIT_STATS (Wait-Statistiken), FILE_IO (Datei-I/O); leer/anderer normalisierter Wert ergibt INVALID_PARAMETER. |
| `@ExpectedTargetDatabaseId` | int; **Default: NULL. Weglassen verwendet NULL.** Ziel-ID; NULL nur bei identitätslosem Performance-Counter-Aufruf. Sobald irgendeine Identitätskomponente gesetzt ist und immer für Wait/File sind alle drei Pflicht. Die ID ist eine ganze Zahl größer als 4 und muss DB_ID() der aktuellen Datenbank entsprechen; die master-Zieldatenbank muss online und beschreibbar sein. Leertext ist keine unterstützte Ganzzahleingabe; eine abweichende Identität ergibt TARGET_UNAVAILABLE. |
| `@ExpectedTargetDatabaseName` | sysname; **Default: NULL. Weglassen verwendet NULL.** Zielname, binärer Vergleich. NULL nur im identitätslosen Performance-Counter-Fall; sonst alle drei Pflicht. Leertext ist keine unterstützte Eingabe; ein nicht passender gesetzter Name ergibt TARGET_UNAVAILABLE. |
| `@ExpectedTargetCreateDate` | datetime; **Default: NULL. Weglassen verwendet NULL.** Exakter datetime-Wert von master.sys.databases.create_date, ohne UTC-Umrechnung. NULL nur im identitätslosen PERFORMANCE_COUNTERS-Fall; sonst sind alle drei Identitätsfelder Pflicht. Leertext ist keine unterstützte Datumsangabe. Abweichung ergibt TARGET_UNAVAILABLE. |
| `@PolicyOnly` | bit; **Default: 0. Weglassen verwendet 0.** 0 normaler Pfad mit Budgetread und vorgesehenen Writes. 1 nur WAIT_STATS/FILE_IO: Enabled/Due aus abgeschlossener Historie; der SoftBudgetMB-Policywert wird zuvor gelesen, Dateigrößenmessung, Budgetvergleich und Writes entfallen, keine Run-ID und ShouldCollect 0 auch bei AVAILABLE. NULL ergibt INVALID_PARAMETER; leerer Text ist keine unterstützte Eingabe. Wait/File sind auch hier nur ohne Callertransaktion und ohne aktivierte implizite Transaktionen zulässig. |


#### Zulassung und Grenzen von InternalPrepareCollectionCycle

Die Target-Identität wird für WAIT_STATS und FILE_IO immer verlangt. Für PERFORMANCE_COUNTERS wird sie geprüft, sobald ein Identitätsfeld übergeben ist. Der Wait-/File-Paketcheck verlangt genau eine PackageVersion mit SC-023-Version 1.2.1 und Schema 2 oder 1.3.0 beziehungsweise 1.3.1 und Schema 3 sowie die Procedure InternalCompleteWaitStatsCycle und den Parameter `@ContractOnly` von InternalPurgeExpiredData. FILE_IO erfordert zusätzlich Version 1.3.1 mit Schema 3. PERFORMANCE_COUNTERS hat kein entsprechendes Package-Gate. Diese Prüfung führt kein Purge aus.

Das Softbudget wird exakt als SUM(size der sys.database_files-Zeilen mit type=0) * 8 / 1024 MB berechnet. Es beschreibt die allokierte Kapazität der Datendateien der aktuellen Datenbank. Logdateien gehen nicht in die Summe ein; der Wert misst keine tatsächlich belegten Snapshot- oder Payloadbytes. Ein Wert strikt über SoftBudgetMB stoppt die Admission, Gleichheit besteht die Prüfung. Die Procedure selbst führt kein Purge aus.

Die Due-Prüfung verwendet den jüngsten abgeschlossenen Lauf nach CaptureRunId, also eine Zeile mit nicht-NULL EndedAtUtc. Im normalen PERFORMANCE_COUNTERS-Pfad zählen nur Status AVAILABLE oder PARTIAL. WAIT_STATS und FILE_IO sowie PolicyOnly werten jeden abgeschlossenen Status aus. RunEvenIfNotDue=1 übergeht nur die Due-Prüfung.

PolicyOnly ist ausschließlich für WAIT_STATS und FILE_IO verfügbar. Es liest den SoftBudgetMB-Policywert mit der Policyquelle und prüft Enabled sowie Due anhand der Historie; es misst keine Dateigrößen, führt keinen Budgetvergleich aus und schreibt nichts; es erzeugt keine CaptureRun-ID und ShouldCollectOut bleibt auch bei AVAILABLE 0. Bei fehlgeschlagener normaler Admission schreiben WAIT_STATS und FILE_IO ebenfalls keine Zeilen. PERFORMANCE_COUNTERS schreibt bei Disabled, Budgetstopp oder Due-Skip dagegen einen beendeten partiellen CaptureRun samt ModuleStatus ohne Quellread.

Native SQL-Fehler werden nicht durch CATCH abgefangen. Die Procedure besitzt keine eigene Transaktion und keine Admission-Reservierung oder Serialisierung. Die beiden Writes des PERFORMANCE_COUNTERS-Abbruchpfads können bei einem nativen Fehler teilweise erfolgt sein; parallele Aufrufe bilden keine globale genau-einmalige Admission.

### `[snapshot].[InternalCompletePerformanceCounterCycle]`

Quelle: `Code/10_SnapshotBaseline/050_InternalCompletePerformanceCounterCycle.sql`

Die Procedure übernimmt Ergebnisse eines Performance-Counter-Collectors aus einem JSON-Text und schreibt typisierte Snapshotdaten. Sie führt keine Quellmessung und keine Ratenberechnung aus. Der aufrufende Collector begrenzt die Eingabezeilen; diese Procedure setzt `CollectorPolicy.MaxRows` nicht durch.

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Verarbeitet Counterdaten für eine vorhandene `CaptureRunId` und schreibt Scope-, Sample-, optional Payload- und Modulstatusdaten. |
| Schnittstelle | Interne Stored Procedure mit zehn Pflichtargumenten ohne SQL-Defaults. Die Tabelle unten beschreibt jeden Parameter einzeln. |
| Verwendung | Öffentliche Procedures im Schema `monitor` rufen diesen Baustein zur Orchestrierung auf. Anwendungen sollen ihn weder direkt ausführen noch von Parameterreihenfolge oder temporären Zwischenstrukturen abhängen. |
| Last und Sperren | Die Procedure erstellt eine lokale Counterprojektion unter `LOCK_TIMEOUT 0` und schreibt in Snapshot- und Frameworktabellen. Die Eingabe wird nicht anhand von `CollectorPolicy.MaxRows` begrenzt. |
| Vertrag | Nicht öffentlicher Vertrag für versiongleiche interne Aufrufer. Die Procedure besitzt keine eigene Transaktion und keine Atomaritäts- oder Rollback-Zusage; sie setzt `CaptureRun.EndedAtUtc` nicht. |

#### `InternalCompletePerformanceCounterCycle`: Parametervertrag

Jedes Argument ist bei jedem Aufruf anzugeben; die Signatur enthält keinen SQL-Default. Bei Auslassung entsteht ein Aufruffehler. Zulässiges NULL ersetzt die Pflicht zur Argumentübergabe nicht.

| Parameter und Typ | Default und Pflicht | Eingabeform, NULL, Leerwert und Wirkung |
|---|---|---|
| `@CaptureRunId bigint` | Kein Default; Pflichtargument. | Erwartet eine vorhandene Lauf-ID. NULL ist syntaktisch übergebbar, kann aber bei abhängigen Constraints scheitern; ein fehlender Lauf wird nicht angelegt und kann bei schreibenden Vorgängen an Fremdschlüsseln scheitern. Die Procedure prüft weder Collectorfamilie noch offenen Lauf oder Quellidentität. Eine Leertexteingabe ist keine unterstützte Zahlenform; ein bestimmter Konvertierungsfehler wird nicht zugesichert. Samples, Payload und Modulstatus werden dieser ID zugeordnet. |
| `@CollectorJson nvarchar(max)` | Kein Default; Pflichtargument. | Erwartet einen JSON-Text, keinen Dateinamen oder Pfad. NULL, leerer Text und ungültiges JSON werden als ungültiger Vertrag behandelt. Gültiges JSON wird mit OPENJSON projiziert; es gibt keine strikte Objekt-/Array-Schema-Prüfung. Ein gültiges Objekt oder Array ohne passende Counter kann null Samples ergeben, wobei Quellstatus und Partial-Wert unverändert initial bleiben. Bei passender Form gilt die Feldtabelle. |
| `@SourceStatusCode varchar(40)` | Kein Default; Pflichtargument. | Akzeptiert NULL, einen Statuswert oder leeren Text; der Bereich wird nicht als Enum validiert. Bei gültigem JSON wird der Wert initial weitergereicht, NULL wird zu ERROR_HANDLED und leer bleibt leer. Bei ungültigem JSON bleiben DENIED_PERMISSION und UNAVAILABLE_OBJECT erhalten; alle anderen Werte ergeben ERROR_HANDLED. |
| `@SourceIsPartial bit` | Kein Default; Pflichtargument. | Akzeptiert 0 (als nicht partiell markiert), 1 (als partiell markiert) oder NULL. NULL wird initial zur Laufzeit zu 1; kein SQL-Default. Leertext ist keine unterstützte Bit-Eingabeform; ein bestimmter Konvertierungsfehler wird nicht zugesichert. Bei gültigem JSON werden 0 oder 1 weitergereicht; ungültiges JSON setzt 1. Status und Partial-Wert werden nicht auf Konsistenz geprüft. |
| `@SourceErrorNumber int` | Kein Default; Pflichtargument. | Akzeptiert NULL oder eine vorzeichenbehaftete int-Diagnosezahl; Leertext ist keine unterstützte Zahlenform, ohne Zusage eines bestimmten Konvertierungsfehlers. Die Zahl löst selbst keinen SQL-Fehler aus und wird zunächst weitergereicht. Ungültiges JSON ändert sie nicht; ein abgefangener Fehler ersetzt sie durch die native Fehlernummer. |
| `@SourceErrorMessage nvarchar(2048)` | Kein Default; Pflichtargument. | Akzeptiert NULL oder Aufrufertext bis zur Typgrenze; SQL-leerer Text ist gültig und bleibt leer. Der Wert wird zunächst weitergereicht. Bei ungültigem JSON ersetzt eingebauter Text nur NULL. Ein abgefangener SQL-Fehler setzt ERROR_MESSAGE(). |
| `@StatusCodeOut varchar(40) OUTPUT` | Kein Default; Pflichtargument. | Das Argument muss vom Typ varchar(40) sein. Sein eingehender Variablenwert wird ignoriert und darf uninitialisiert sein. Der Startwert ist COALESCE(@SourceStatusCode,'ERROR_HANDLED'). OUTPUT ist nur zum Empfangen in einer Variablen erforderlich; ohne OUTPUT kann das Pflichtargument übergeben und das Ergebnis verworfen werden. Bei ungültigem JSON gilt die Statusregel der Eingabe. Im CATCH ergeben Fehlernummern 229, 262, 297, 300 und 371 DENIED_PERMISSION, andere Fehler ERROR_HANDLED. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. |
| `@IsPartialOut bit OUTPUT` | Kein Default; Pflichtargument. | Argumenttyp bit; eingehender Variablenwert wird ignoriert und darf uninitialisiert sein. Startwert ist COALESCE(@SourceIsPartial,1). 0 markiert das Ergebnis als nicht partiell, 1 als partiell; die tatsächliche Vollständigkeit wird nicht nachgeprüft. Ungültiges JSON und abgefangene Fehler setzen 1. OUTPUT ist nur für den Empfang erforderlich; ohne OUTPUT kann das Pflichtargument übergeben und das Ergebnis verworfen werden. |
| `@ErrorNumberOut int OUTPUT` | Kein Default; Pflichtargument. | Argumenttyp int; eingehender Wert wird ignoriert und darf uninitialisiert sein. Startwert ist `@SourceErrorNumber`; ungültiges JSON ändert ihn nicht, ein abgefangener Fehler ersetzt ihn durch die native Fehlernummer. OUTPUT ist nur zum Empfangen erforderlich; ohne OUTPUT kann das Pflichtargument übergeben und das Ergebnis verworfen werden. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. |
| `@ErrorMessageOut nvarchar(2048) OUTPUT` | Kein Default; Pflichtargument. | Argumenttyp nvarchar(2048); eingehender Wert wird ignoriert und darf uninitialisiert sein. Startwert ist `@SourceErrorMessage`; ungültiges JSON verwendet eingebauten Text nur bei NULL, leer bleibt leer. Ein abgefangener Fehler ersetzt den Wert durch ERROR_MESSAGE(). OUTPUT ist nur zum Empfangen erforderlich; ohne OUTPUT kann das Pflichtargument übergeben und das Ergebnis verworfen werden. Bei entweichenden nativen Fehlern ist keine erfolgreiche Ausgabe zugesichert. |

#### `InternalCompletePerformanceCounterCycle`: JSON-Feldprojektion

OPENJSON verwendet für `$.counters` den lax-Modus und ordnet Pfadschlüssel case-sensitiv zu. Zuerst wird `$.counters` gewählt; die Tabelle nennt die expliziten Pfade relativ zum jeweiligen Objekt oder Arrayelement. Die vier als erforderlich markierten Felder werden nach der Projektion auf NULL geprüft und filtern betroffene Zeilen still heraus. Konvertierungsfehler eines nicht passenden Werts können dagegen in den CATCH-Pfad gelangen.

| JSON-Pfad | Zieltyp | NULL und Wirkung |
|---|---|---|
| `$.ObjectName` | nvarchar(128) | Erforderlich nach Projektion; NULL filtert die Zeile. Leerer Text ist zulässig. |
| `$.CounterName` | nvarchar(128) | Erforderlich nach Projektion; NULL filtert die Zeile. Leerer Text ist zulässig. |
| `$.InstanceName` | nvarchar(128) | Erforderlich nach Projektion; NULL filtert die Zeile. Leerer Text ist zulässig. |
| `$.CounterType` | int | Erforderlich nach Projektion; NULL filtert die Zeile. |
| `$.MetricValue` | decimal(38,6) | Optional; ein Wert erzeugt ein interpretiertes Sample. Der Collector liefert ihn, die Procedure berechnet ihn nicht. |
| `$.MetricUnit` | varchar(40) | Optional; wird in die Counter-Scope-Identität aufgenommen. Der Wert wird nicht aus einer Metrik abgeleitet. |
| `$.AfterValue` | bigint | Optional; ein Wert erzeugt ein Rohsample. |
| `$.FindingCode` | varchar(80) | Optional; NULL oder leer wird zu MEASURED, sonst wird der Text als QualityCode übernommen. Keine Enum-Prüfung. |

Wenn sowohl `MetricValue` als auch `AfterValue` vorhanden sind, entstehen beide Samplearten. Fehlende erforderliche Felder können ohne Fehler null Samples ergeben. Nicht konvertierbare Werte können einen SQL-Fehler verursachen und werden nicht als stille Filterung zugesichert. Ein Strukturbeispiel mit hypothetischen Werten hat die Form `{"meta":{"sqlServerStartTime":"2026-07-21T10:00:00"},"counters":[{"ObjectName":"SQLServer:General Statistics","CounterName":"User Connections","InstanceName":"_Total","CounterType":65792,"MetricValue":12.000000,"MetricUnit":"connections","AfterValue":12,"FindingCode":null}]}`.

#### `InternalCompletePerformanceCounterCycle`: Persistenz, Metadaten und Grenzen

Bei gültigem JSON wird `$.meta.sqlServerStartTime` mit TRY_CONVERT als datetime2(3) gelesen; fehlender oder nicht konvertierbarer Inhalt ergibt NULL, ohne UTC-Umrechnung. JSON ohne Counter kann null Samples ergeben; in diesem Fall bleibt der initiale Quellstatus und Partial-Wert bestehen.

Vor TRY initialisiert die Procedure die OUTPUT-Werte und erstellt unter `LOCK_TIMEOUT 0` eine lokale Temp-Tabelle. Fehler bei diesem CREATE liegen außerhalb des CATCH. Im TRY-Pfad verwendet oder ergänzt sie SERVER- und PERFORMANCE_COUNTER-Scope-Zeilen, schlägt die festen Metrikdefinitionen PERFORMANCE_COUNTER_RAW und PERFORMANCE_COUNTER_INTERPRETED nach und schreibt MetricSample- sowie ModuleStatus-Zeilen.

Nur bei `PayloadEnabled=1` für PERFORMANCE_COUNTERS wird der originale JSON-Text als GZIP in PayloadSnapshot geschrieben. Hash und Payload beziehen sich auf den Originaltext ohne Kanonisierung; die mittels LEN gespeicherte Zeichenanzahl ist keine vollständige Speicherbytezählung. Die Procedure aktualisiert CaptureRun.SqlServerStartTimeUtc und CaptureRun.ResetEpochId, nicht aber StartedAtUtc oder EndedAtUtc. Sie verwendet die Epoch aus dem Lauf mit höchster CaptureRunId, dessen geparste Startzeit übereinstimmt und dessen Epoch nicht NULL ist; andernfalls erzeugt sie NEWID(). Dies beweist keine Identität des Quellservers.

Im CATCH werden native Fehler 229, 262, 297, 300 und 371 als DENIED_PERMISSION, andere native Fehler als ERROR_HANDLED ausgegeben; Partial wird auf 1 und Fehlernummer/-text auf die nativen Werte gesetzt. Danach versucht der CATCH einen weiteren ModuleStatus-INSERT, der selbst scheitern kann, etwa wegen einer bereits vorhandenen Modulzeile. Entweichende native Fehler, darunter Fehler außerhalb TRY und Fehler des zweiten INSERT, haben keine zugesicherte erfolgreiche Ausgabe. Es gibt keine eigene Transaktion und keine Atomaritäts- oder Rollback-Zusage. Ein separater Finalisierer setzt EndedAtUtc. Die Procedure setzt CollectorPolicy.MaxRows nicht durch; diese Begrenzung muss der Collector vor dem Aufruf einhalten.

#### `InternalCompletePerformanceCounterCycle`: JSON-Quellen

Die SQL-Server-Dokumentation beschreibt die case-sensitive BIN2-Zuordnung von JSON-Pfaden und den lax-Standardmodus in [OPENJSON (Transact-SQL)](https://learn.microsoft.com/en-us/sql/t-sql/functions/openjson-transact-sql?view=sql-server-ver17). Die Projektion eines Objekts oder von Arrayelementen mit explizitem WITH-Schema ist in [OPENJSON mit explizitem Schema](https://learn.microsoft.com/en-us/sql/relational-databases/json/use-openjson-with-an-explicit-schema-sql-server?view=sql-server-ver17) beschrieben.

### `[snapshot].[InternalCompleteWaitStatsCycle]`

Quelle: `Code/10_SnapshotBaseline/055_InternalCompleteWaitStatsCycle.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Die Procedure validiert Source-v1 und finalisiert ausschließlich einen unbeschriebenen eigenen Wait-Run. Erfolgreich gespeicherte Aufnahmen erhalten PARTIAL, weil Vergleichskandidaten keine lückenlose Resetkontinuität beweisen. |
| Schnittstelle | Interne Stored Procedure mit neun erforderlichen Parametern ohne Defaults: fünf Eingaben und vier OUTPUT-Ausgaben. Die einzelnen Typ-, NULL-, Leerwert-, Bindungs- und JSON-Regeln stehen in den folgenden Parameter- und Source-v1-Verträgen. |
| Verwendung | Der interne Frameworkbaustein übergibt den vollständigen JSON-Vertrag inline; ein Dateipfad ist keine Eingabe. Das Target-Backend allein stellt keinen öffentlichen Wait-Collector bereit. |
| Last und Sperren | Die Procedure setzt nach den frühen Guards NOCOUNT, LOCK_TIMEOUT 0 und XACT_ABORT ON. Sie schreibt nur den gebundenen eigenen Wait-Run in einer eigenen Transaktion; MaxRows begrenzt die Backend-Schreibmenge. |
| Vertrag | Frühe ungültige Run-/Transaktionsparameter ergeben INVALID_PARAMETER/51011. Fehlerhafte Sourceverträge nach Übernahme des eigenen Runs werden als ERROR_HANDLED behandelt; ein gültiger Fehlervertrag behält seinen Source-Status. Die Fehlerfinalisierung ist ein Versuch, dessen Erfolg nicht garantiert ist. Installations- und Aktivierungsgrenzen beschreibt der [Snapshotvertrag](../Architecture/Snapshot_Baseline_Package_Contract.md). |

#### InternalCompleteWaitStatsCycle – Parameterverträge

| Parameter | Vertrag |
|---|---|
| @CaptureRunId | bigint; Default: Kein Default. Erforderlich und größer als 0. NULL oder kleiner gleich 0, Callertransaktion und IMPLICIT_TRANSACTIONS ON lösen vor Fachzugriff INVALID_PARAMETER/RETURN 51011 aus. Leertext ist keine unterstützte bigint-Eingabe. |
| @CollectorJson | nvarchar(max); Default: Kein Default. Erforderlicher vollständiger JSON-Source-v1-Text inline, kein Dateipfad. NULL, leerer oder ungültiger JSON-Text scheitert an der Sourcevalidierung: Sie erfolgt erst nach Übernahme des eigenen Runs und führt bei Fehler zu ERROR_HANDLED / 53763 und einem Versuch der Fehlerfinalisierung. Eine zuvor abgewiesene Runbindung ergibt stattdessen INVALID_PARAMETER / 51011. |
| @ExpectedTargetDatabaseId | int; Default: Kein Default. Erforderliche ID der aktuellen Datenbank, größer als 4. NULL, andere aktuelle ID oder Abweichung führt zu TARGET_UNAVAILABLE/53764. Leertext ist keine unterstützte int-Eingabe. |
| @ExpectedTargetDatabaseName | sysname; Default: Kein Default. Erforderlicher roher Name, binär mit master.sys.databases.name verglichen, ohne Trimmen oder Normalisierung der Schreibweise. NULL oder Leertext passt nicht und führt zu TARGET_UNAVAILABLE/53764. |
| @ExpectedTargetCreateDate | datetime; Default: Kein Default. Erforderlicher typisierter Wert aus master.sys.databases.create_date für dieselbe aktuelle Datenbank. NULL oder Abweichung führt zu TARGET_UNAVAILABLE/53764. Leertext ist keine unterstützte Datumsform. |
| @StatusCodeOut | varchar(40) OUTPUT; Default: Kein Default. Erforderliches Argument, anfänglich AVAILABLE. Gebundener Eingang einschließlich NULL oder Leertext wird ignoriert. Ohne OUTPUT am Aufruf kann ein typkompatibler skalarer Wert oder NULL als Pflichtargument übergeben und die Ausgabe verworfen werden; zum Empfang sind eine typkompatible Variable und OUTPUT erforderlich. |
| @IsPartialOut | bit OUTPUT; Default: Kein Default. Erforderliches Argument, anfänglich 0 als Nicht-Partialwert; gebundener Eingang einschließlich NULL wird ignoriert. Nach jedem fachlichen Ergebnis wird 1 als partiell oder nicht vollständig bestätigt ausgegeben. Variable plus OUTPUT ist zum Empfang nötig. |
| @ErrorNumberOut | int OUTPUT; Default: Kein Default. Erforderliches Argument, anfänglich NULL; gebundener Eingang einschließlich NULL wird ignoriert. Guards und behandelte Fehler können eine Fehlernummer setzen; erfolgreicher gespeicherter PARTIAL-Abschluss gibt NULL aus. Variable plus OUTPUT ist zum Empfang nötig. |
| @ErrorMessageOut | nvarchar(2048) OUTPUT; Default: Kein Default. Erforderliches Argument, anfänglich NULL; gebundener Eingang einschließlich NULL oder Leertext wird ignoriert. Ausgabe kann Guard-/Fehlertext, einen der zwölf im Abschnitt Vergleichsgründe aufgezählten Codes, NULL oder Leertext enthalten. Variable plus OUTPUT ist zum Empfang nötig. |

Keiner der neun Parameter ist auslassbar. OUTPUT-Eingabewerte werden für alle vier Ausgabeparameter ignoriert; ohne OUTPUT-Kennzeichnung kann der Aufruf den Wert verwerfen, mit typkompatibler Variable und OUTPUT wird er empfangen.

Die normalen SQL-Typkonvertierungen gelten vor dem Eintritt in die Prozedur. Ohne Rückgabe darf jedes obligatorische OUTPUT-Argument als typkompatibler Skalar oder NULL gebunden werden; für numerische Typen ist Leertext keine unterstützte Eingabeform. Die Initialisierung ersetzt erst den erfolgreich gebundenen Eingangswert.

#### InternalCompleteWaitStatsCycle – Source-v1-JSON-Vertrag

Der Root ist ein JSON-Objekt mit genau meta als Objekt und waits als Array. Zusätzliche und doppelte Eigenschaften sind unzulässig; Namen werden binär verglichen, also groß-/kleinschreibungsabhängig. Alle Pflichtfelder müssen vorhanden sein, auch wenn sie JSON null enthalten.

| Objekt | Genau vorgeschriebene Felder und JSON-Typen |
|---|---|
| meta | Genau elf Pflichtfelder: schemaVersion als JSON-Zahl exakt 1; resultName als Zeichenfolge exakt SnapshotWaitStats; measurementStartUtc und measurementEndUtc jeweils als NULL oder 24 Zeichen YYYY-MM-DDTHH:mm:ss.fffZ; statusCode als eine der fünf Source-Statuszeichenfolgen; isPartial und sourceComplete als JSON-Boolean; errorNumber als NULL oder kanonische JSON-Ganzzahl 1..2147483647; errorMessage als NULL oder Unicode-Zeichenfolge bis 2048 UTF-16-Codeeinheiten; nativeRows als NULL oder kanonische nichtnegative bigint-Dezimalzeichenfolge 0..9223372036854775807; engineContext als NULL oder vollständiges Engineobjekt. |
| engineContext | Genau drei Eigenschaften, alle JSON-Zeichenfolgen: serverName mit 1..128 UTF-16-Codeeinheiten; sqlServerStartTimeLocal mit exakt 23 Zeichen YYYY-MM-DDTHH:mm:ss.fff ohne Z im lokalen DATETIME-Rundtripformat; sqlServerStartTimeMsTicks als kanonische nichtnegative bigint-Dezimalzeichenfolge 0..9223372036854775807. |
| jedes waits-Element | JSON-Objekt mit genau WaitType als Zeichenfolge mit 1..60 UTF-16-Codeeinheiten und WaitingTasksCount, WaitTimeMs, MaxWaitTimeMs sowie SignalWaitTimeMs als kanonische JSON-Ganzzahlen 0..9223372036854775807. Die vier numerischen Felder erlauben weder Vorzeichen noch führende Nullen, Dezimalpunkt oder Exponent. WaitType-Identitäten dürfen nicht doppelt vorkommen. |

Ein vorhandenes UTC-Messfenster enthält beide Zeitpunkte und ist geordnet. Vollständige Source verlangt beide Zeitpunkte; Start liegt nicht vor dem Runstart und Ende nicht nach aktueller UTC. Für sourceComplete=true sind nur AVAILABLE (nichtleere Zeilenmenge, isPartial=false) und EMPTY_UNPROVEN (leere Menge, isPartial=true) erlaubt; errorNumber und errorMessage müssen NULL, Enginekontext und Zeitpunkte vorhanden und nativeRows gleich der tatsächlichen Zeilenzahl sein. Für sourceComplete=false sind nur DENIED_PERMISSION, UNAVAILABLE_OBJECT und ERROR_HANDLED erlaubt; isPartial muss true, waits leer und nativeRows NULL sein. Der Fehlerzweig darf ein gültiges Engineobjekt enthalten; es muss nicht NULL sein. Die Messzeitpunkte dürfen dort gemeinsam NULL oder gemeinsam vorhanden und geordnet sein.

Die fünf Source-Statuswerte bedeuten: AVAILABLE = vollständige, nichtleere Aufnahme; EMPTY_UNPROVEN = vollständige, aber leere und deshalb als partiell markierte Aufnahme; DENIED_PERMISSION = behandelter Berechtigungsfehler; UNAVAILABLE_OBJECT = nicht verfügbares natives Objekt; ERROR_HANDLED = sonstiger behandelter Fehler bei der nativen Erfassung.

#### InternalCompleteWaitStatsCycle – Vergleichsgründe in @ErrorMessageOut

Bei einem erfolgreich gespeicherten PARTIAL-Ergebnis enthält @ErrorMessageOut genau einen der folgenden zwölf geschlossenen Vergleichsgründe. Die Auswahl folgt der Reihenfolge der ersten zutreffenden Prüfung in der Liste; die Codes sind keine Werte von @StatusCodeOut.
- SOURCE_EMPTY_UNPROVEN: Die vollständige Sourceaufnahme enthält keine Waitzeilen.
- WRITE_LIMITED: MaxRows ließ nicht alle zur Speicherung berücksichtigungsfähigen WaitTypes zur Speicherung zu.
- FIRST_OBSERVATION: Es gibt keinen früheren finalisierten Wait-Run.
- PREVIOUS_CAPTURE_PARTIAL: Der frühere Lauf war technisch partiell oder enthielt einen Fehler.
- PREVIOUS_CONTEXT_INVALID: Der frühere Vergleichskontext besteht seine Vertragsprüfung nicht.
- PREVIOUS_RAW_INCOMPLETE: Der frühere Lauf enthält nicht alle erforderlichen Rohmetriken.
- ENGINE_CONTEXT_CHANGED: Der native Enginekontext unterscheidet sich vom vorherigen.
- INTERVAL_NOT_POSITIVE: Das Fenster überlappt oder läuft rückwärts; insbesondere liegt der aktuelle Start vor dem vorherigen Ende oder das aktuelle Ende ist nicht später als das vorherige Ende.
- WAIT_TYPE_MISSING: Ein erforderlicher vorheriger WaitType fehlt in der aktuellen Aufnahme.
- COUNTER_DECREASE: Mindestens ein verglichener Counter ist gegenüber dem Vorwert gesunken.
- NO_COMPARABLE_TYPES: Es gibt keinen ausgewählten aktuellen WaitType mit passendem Vorwert.
- MONOTONIC_CONTINUITY_UNPROVEN: Vergleichbare Werte sind monoton, aber daraus folgt keine lückenlose Resetkontinuität.

#### InternalCompleteWaitStatsCycle – Persistenz- und Ausgabevertrag

Die Targetprüfung liegt vor TRY und erfordert die aktuelle, online befindliche und schreibbare Datenbank mit ID größer als 4 sowie binär passendem Namen und passendem create_date; der Vorprüfungszugriff kann selbst einen ungefangenen SQL-Fehler auslösen. Zulässig ist genau eine passende SC-023-Paketzeile: 1.2.1 mit Schema 2, 1.3.0 mit Schema 3 oder 1.3.1 mit Schema 3. Der Retentions-Handshake muss den zugehörigen Vertrag 1, 2 beziehungsweise 3 bestätigen.

Der eigene WAIT_STATS-Run muss RUNNING, unbeschrieben, ohne Endzeit und ResetEpochId sowie ohne Sample-, Payload- oder ModuleStatus-Zeilen sein. Die aktive Policy muss enabled sein und MaxRows zwischen 1 und 100000 liegen; dieser Wert begrenzt nur Backend-Schreibvorgänge. Je ausgewähltem WaitType werden vier rohe numerische Metriken und ein Vergleichsstatus gespeichert. Hinzu kommen höchstens drei numerische Differenzkandidaten je vergleichbarem Typ und ein Serverkontextsample insgesamt. Vorzustand und Vergleichskontext entscheiden über die Zulässigkeit; ein beliebiger vorheriger Zustand oder eine lückenlose Resetkontinuität ist nicht garantiert. Bei aktiver Payload-Policy wird der Sourcevertrag als JSON-Payload mit GZIP gespeichert. Schreibvorgänge und Abschluss liegen in einer eigenen Transaktion und werden gemeinsam committet.

Die sieben möglichen Ausgabe-Statuswerte bedeuten: AVAILABLE ist nur der anfängliche OUTPUT-Wert und bestätigt keinen abgeschlossenen Wait-Run; INVALID_PARAMETER bezeichnet die frühen Run-/Callertransaktions-/Implizittransaktions-Guards und eine mit 53763 abgewiesene Runbindung vor Übernahme des eigenen Runs; TARGET_UNAVAILABLE bezeichnet eine nicht passende Targetidentität oder einen nicht passenden Paket-/Retentionsvertrag; DENIED_PERMISSION bezeichnet einen behandelten Berechtigungsfehler; UNAVAILABLE_OBJECT übernimmt den Status eines gültigen Source-Fehlervertrags für ein nicht verfügbares Objekt; ERROR_HANDLED bezeichnet sonstige behandelte Vertrags-, Backend-, Transaktions- oder Finalisierungsfehler einschließlich Sourcefehlern mit 53763 nach Übernahme des eigenen Runs; PARTIAL bezeichnet einen erfolgreich gespeicherten vollständigen oder leeren Sourceabschluss. Ein erfolgreicher PARTIAL-Abschluss gibt IsPartial=1, ErrorNumber=NULL und im ErrorMessageOut die Vergleichsentscheidung aus. Fehlerhafte Sourceverträge nach Übernahme des eigenen Runs erzeugen keine Rohsamples, kein Kontextsample und keine erfundene Epoche. Ein gültiger Source-Fehlervertrag wird ohne numerische Roh- oder Kontextsamples und ohne Epoche abgeschlossen; nur dieser reguläre Fehlerpfad speichert bei aktivierter Payload-Policy auch den übergebenen Sourcevertrag als GZIP-Payload. Bei einem SQL- oder Validierungsfehler rollt der CATCH eine aktive Schreibtransaktion zurück. Nur nach Übernahme eines eigenen Runs und bei weiterhin bestätigter Targetidentität versucht er einen getrennten Fehlerabschluss mit ModuleStatus und Run-Update, ohne Payload. Dieser Versuch kann scheitern oder die nötigen Runbedingungen nicht mehr vorfinden; dann ist keine abgeschlossene Finalisierung zugesichert. FINALIZATION_UNCONFIRMED ist kein Status dieser Procedure.


### `[snapshot].[InternalCompleteFileIOCycle]`

Quelle: `Code/10_SnapshotBaseline/057_InternalCompleteFileIOCycle.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Validiert den geschlossenen Source-v1-Vertrag und bindet sieben Rohwerte je ausgewählter Datei, Status, Kontexte und bis zu sechs belegbare Differenzkandidaten atomar an einen vorbereiteten eigenen Lauf. |
| Schnittstelle | Neun erforderliche Parameter ohne Defaults: CaptureRunId bigint, CollectorJson nvarchar(max), erwartete Target-ID int, Targetname sysname, Erstellungszeit datetime und vier OUTPUT-Parameter der Typen varchar(40), bit, int und nvarchar(2048). |
| Verwendung | Die öffentliche monitor.USP_RunSnapshotCollectionCycle delegiert an monitor.InternalRunSnapshotFileIOCycle. Dieser Backend-Helper allein ist nicht der vollständige öffentliche Collector. |
| Last und Sperren | Eigene Transaktion mit LOCK_TIMEOUT 0 für einen vorbereiteten eigenen RUNNING-Lauf; Sourceabfragen liegen außerhalb. Caller- und implizite Transaktionen werden vor Fachzugriff abgelehnt. |
| Vertrag | Target 1.3.1 / Schema 3 und tatsächlicher schreibfreier Retentionshandshake. Dateiepochen, Rohhashes und der unmittelbar vorherige FILE_IO-Lauf einschließlich offener Läufe begrenzen Kandidaten. Sourcefehler bleiben ohne Payload als gebundene Issues erhalten. Erfolg bleibt PARTIAL und behauptet keine Resetkontinuität. Der [interne Datei-I/O-Vertrag](../Architecture/Snapshot_Baseline_Package_Contract.md#internes-datei-io-target) beschreibt die Bindungen. |

#### InternalCompleteFileIOCycle – Parameter

Alle Parameter sind Pflicht; es gibt keine Defaults.

| Parameter | Vertrag |
|---|---|
| `@CaptureRunId` | bigint; > 0; ID des unbeschriebenen eigenen FILE_IO-Laufs mit Status RUNNING. NULL/0/negativ ergibt INVALID_PARAMETER / 51011; Default: kein Default |
| `@CollectorJson` | nvarchar(max); vollständiges JSON-Objekt gemäß Schema. NULL, Leertext und ungültiges JSON werden erst nach bestätigtem eigenem Lauf als ERROR_HANDLED / 53782 behandelt, nicht als globales INVALID_PARAMETER; Default: kein Default |
| `@ExpectedTargetDatabaseId` | int; einzelner typisierter Wert > 4 für die aktuelle, online befindliche, beschreibbare Zieldatenbank. NULL oder abweichende Identität ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |
| `@ExpectedTargetDatabaseName` | sysname; einzelner roher Datenbankname bis 128 UTF-16-Codeeinheiten. Vergleich mit dem aktuellen Katalognamen ist binär, ohne Trimmen oder Schreibweisenausgleich. NULL oder ein fehlender exakter Match ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |
| `@ExpectedTargetCreateDate` | datetime; einzelner typisierter Erstellungszeitpunkt aus master.sys.databases.create_date für das aktuelle Target. NULL oder Abweichung ergibt TARGET_UNAVAILABLE / 53764; Default: kein Default |
| `@StatusCodeOut` | varchar(40) OUTPUT; initial AVAILABLE. AVAILABLE: ausschließlich Initialwert, kein Abschlussnachweis; INVALID_PARAMETER: frühe Eingabe oder Lauf ungültig; TARGET_UNAVAILABLE: Target nicht verfügbar; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: durchgereichter Source-Status für ein nicht verfügbares Objekt; ERROR_HANDLED: behandelter Fehler; ein nachträglicher Fehlerabschluss ist nicht generell garantiert; PARTIAL: bestätigter regulärer Sourceabschluss unter den beschriebenen Evidenzgrenzen; FINALIZATION_UNCONFIRMED: Finalisierung unbestätigt; Default: kein Default |
| `@IsPartialOut` | bit OUTPUT; initial 0; Fehler-, PARTIAL- und FINALIZATION_UNCONFIRMED-Pfade setzen 1; Default: kein Default |
| `@ErrorNumberOut` | int OUTPUT; initial NULL. Frühe Fehlernummern 51011/53764; sonst Nummer des ersten nummerierten Issue, ersatzweise erstes Issue. Erfolgreiches PARTIAL kann Sourcefehlernummer behalten; Default: kein Default |
| `@ErrorMessageOut` | nvarchar(2048) OUTPUT; initial NULL; Meldung desselben ausgewählten Issues wie ErrorNumberOut; META errorNumber und errorMessage müssen dessen Nummer und Text exakt übernehmen. NULL und Leertext sind verschieden. Der Helper fügt keinen Vergleichscode an; Sourcefehlertext wird nicht gefiltert; Default: kein Default |

#### InternalCompleteFileIOCycle – JSON-Sourcevertrag

Das Rootobjekt hat genau meta (Objekt), databases (Array), files (Array), issues (Array). Alle unten aufgeführten Member sind je Objekt genau einmal erforderlich; keine Zusatzmember oder Duplikate. Member werden mit BIN2 und gleicher UTF-16-Länge verglichen. OPENJSON-Typen: Objekt, Array, String, Zahl, Boolean, NULL. NULL nur wo ausgewiesen. Keine Defaults.

| Objekt | Member | Typ / NULL | Format und Grenzen |
|---|---|---|---|
| META | schemaVersion; resultName; statusCode; nativeReadState; isPartial; sourceComplete | Zahl; String; String; String; Boolean; Boolean, alle nicht-null | Version exakt 1; SnapshotFileIO (max 40); Source status AVAILABLE/EMPTY_UNPROVEN/PARTIAL/DENIED_PERMISSION/UNAVAILABLE_OBJECT/ERROR_HANDLED; Readstatus NOT_STARTED/SUCCEEDED/FAILED; isPartial genau false bei AVAILABLE sonst true; sourceComplete genau true bei AVAILABLE oder EMPTY_UNPROVEN. |
| META | errorNumber; errorMessage | Zahl/NULL; String/NULL | Vorzeichenbehafteter SQL int einschließlich 0 und negative Werte; Nachricht max 2048 UTF-16-Codeeinheiten, NULL ≠ Leertext. |
| META | measurementStartUtc, measurementEndUtc; nativeReadStartUtc, nativeReadEndUtc | String/NULL | Paarweise beide NULL oder gesetzt; Reihenfolge gültig. UTC exakt yyyy-MM-ddTHH:mm:ss.fffZ. Bei nichtfatalem Status ist das Messfenster erforderlich; ein nichtfataler SUCCEEDED-Read benötigt darin ein vorhandenes Readfenster. Bei fatalem SUCCEEDED darf das geordnete Readfenster NULL sein. NOT_STARTED und FAILED besitzen kein Readfenster. |
| META | selectedNativeRows | String/NULL | Nichtnegative kanonische Dezimalzahl ohne führende Nullen, bigint-Bereich; SUCCEEDED erforderlich, FAILED NULL. |
| META | framework; selection; engine | Objekt; Objekt; Objekt/NULL | FW- und SEL-Schema unten; ENGINE bei nichtfatalen Sourcezuständen erforderlich, bei DENIED_PERMISSION/UNAVAILABLE_OBJECT/ERROR_HANDLED NULL. |
| FW | databaseId; databaseName; databaseCreateDateNative | Zahl; String; String | ID 1..2147483647; Name max 128; native datetime yyyy-MM-ddTHH:mm:ss.fff. ID, Name und CreateDateNative müssen master.sys.databases sowie CaptureRun.SourceDatabaseName treffen; das belegt keine authentische DMV-Herkunft. |
| ENGINE | serverName; sqlServerStartTimeLocal; sqlServerStartTimeMsTicks | String; String; String | Name max 128 ohne zusätzliche Mindestlänge; native datetime yyyy-MM-ddTHH:mm:ss.fff; kanonische nichtnegative Dezimalzahl im bigint-Bereich. |
| SEL | requestedDatabaseNames; requestedDatabaseNamePattern | String/NULL; String/NULL | Pattern max 4000; beide Provenienzlabels: Helper parst die Grammatik nicht erneut, filtert nicht erneut und setzt keine gegenseitige Ausschließlichkeit voraus. |
| SEL | systemDatabasesIncluded; selectedDatabaseCount; selectionSha256 | Boolean; String; String | Count kanonisch nichtnegativ im bigint-Bereich und gleich DB-Arraygröße; Hash 64 kleingeschriebene Hexzeichen ohne Präfix: SHA-256 der SQL-spezifischen FOR JSON-Serialisierung der nach DatabaseId geordneten Datenbanktripel mit den Propertynamen DatabaseId, DatabaseName, DatabaseCreateDateNative in dieser Reihenfolge, UTF-16LE. |
| DB | DatabaseId; DatabaseName; DatabaseCreateDateNative; MetadataStatusCode | Zahl; String; String; String | ID 1..2147483647 und eindeutig; Name max 128 ohne Mindestlänge; native datetime yyyy-MM-ddTHH:mm:ss.fff; Status AVAILABLE/DENIED_PERMISSION/UNAVAILABLE_OBJECT/TARGET_CHANGED (beobachtete DB-Identität geändert)/ERROR_HANDLED. |
| FILE | DatabaseId; FileId | Zahl; Zahl | ID jeweils 1..2147483647; DB-ID muss im DB-Array liegen; Paar eindeutig. |
| FILE | SampleMs; Reads; ReadBytes; ReadStallMs; Writes; WriteBytes; WriteStallMs; SizeOnDiskBytes | Zahl (8 Werte) | Je bigint, nichtnegative kanonische Dezimalzahl ohne führende Nullen. |
| FILE | FileHandle; MetadataBefore; MetadataAfter | String/NULL; Objekt/NULL; Objekt/NULL | Handle NULL oder 0x + 16 kleingeschriebene Hexzeichen. Metadaten NULL oder vollständiges MB/MA-Objekt. |
| MB/MA | DatabaseId; FileId; FileGuid; CreateLsn | Zahl; Zahl; String/NULL; String/NULL | IDs 1..2147483647; Abweichung von FILE-Identität macht die Beobachtung UNBOUND, ist kein JSON-Formfehler. GUID NULL oder kanonisch 36 Zeichen lowercase, Null-GUID zulässig; LSN NULL oder nichtnegativ kanonisch im decimal(25,0)-Bereich. |
| MB/MA | FileType; FileState; LogicalName | Zahl; Zahl; String | Beide tinyint 0..255; ROWS/LOG-Eignung nutzt Type 0/1 und State 0, andere typisierte Werte bleiben beobachtbar und können ausgeschlossen sein. LogicalName max 128, keine Mindestlänge. |
| ISSUE | ScopeType; SourceName; DatabaseName; StatusCode | String; String; String/NULL; String | ScopeType: `SELECTION` (Auswahl), `SOURCE` (Source-/Engine-Read), `DATABASE` (Datenbankmetadaten), `FILE` (Dateimetadaten/native Zeile). SourceName: `DATABASE_SELECTION` (Auswahlauflösung), `sys.databases` (Datenbankidentitätsread), `sys.database_files` (Dateimetadaten), `sys.dm_os_sys_info` (Enginekontext), `sys.dm_io_virtual_file_stats` (nativer Cache), `SOURCE_CONTRACT` (Sourcevertragsvalidierung); alle sechs Werte max. 128 UTF-16-Codeeinheiten. |
| ISSUE | ErrorMessage; EvidenceLimit; DatabaseId; FileId; ErrorNumber | String/NULL; String/NULL; Zahl/NULL; Zahl/NULL; Zahl/NULL | Grenzen 2048/1000 UTF-16-Codeeinheiten; IDs NULL oder 1..2147483647; ErrorNumber NULL oder signed SQL int einschließlich 0/negativ. |

Stringzahlen: ASCII-Ziffern, nichtnegativ, keine führenden Nullen außer 0. GUID ist lowercase; Handle beginnt 0x und hat 16 lowercase Hexziffern; SHA hat 64 lowercase Hexziffern ohne 0x. UTC hat Z und Millisekunden, native datetime exakt drei Millisekunden ohne Z. Binäre Kanonizitätsprüfung. BIN2+UTF-16-Länge bei Membern bedeutet keine Zusage, dass jedes Enum mit abschließendem U+0020 eigens abgelehnt wird.

| Katalog | Geschlossene Werte mit Bedeutung |
|---|---|
| Source status | AVAILABLE: vollständige Beobachtung; EMPTY_UNPROVEN: vollständig mit null ELIGIBLE-Dateien, aber kein Nachweis für null native Zeilen oder einen leeren Scope; PARTIAL: nichtfatale, nicht als vollständig bestätigte Beobachtung; DENIED_PERMISSION: Berechtigung verweigert; UNAVAILABLE_OBJECT: erforderliches Objekt fehlt; ERROR_HANDLED: sonstiger abgefangener Sourcefehler. |
| Native Read | NOT_STARTED: kein nativer Read; SUCCEEDED: vollständiger nativer Cache-Read; FAILED: nativer Read fehlgeschlagen. |
| DB MetadataStatusCode | AVAILABLE: Vorher-/Nachher-Metadatenread abgeschlossen; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: Katalogobjekt fehlt; TARGET_CHANGED: beobachtete Datenbankidentität änderte sich; ERROR_HANDLED: anderer Metadatenfehler. |
| Issue ScopeType | SELECTION: Auswahlauflösung; SOURCE: Source- oder Engine-Read; DATABASE: Datenbankmetadaten; FILE: Datei-Metadaten oder nativer Dateieintrag. |
| Issue SourceName | DATABASE_SELECTION: Auswahlauflösung; sys.databases: Datenbankidentitätsread; sys.database_files: Datei-Metadaten; sys.dm_os_sys_info: Enginekontext; sys.dm_io_virtual_file_stats: nativer Dateicache; SOURCE_CONTRACT: Sourcevertragsvalidierung. Alle sechs Werte haben maximal 128 UTF-16-Codeeinheiten. |
| Issue StatusCode | SELECTION_UNRESOLVED: Auswahl nicht bestätigt; DATABASE_CONTEXT_CHANGED: Datenbankkontext änderte sich; DENIED_PERMISSION: Zugriff verweigert; UNAVAILABLE_OBJECT: Objekt fehlt; ERROR_HANDLED: abgefangener Fehler; FILE_METADATA_UNAVAILABLE: zwei stabile Katalogbindungen fehlen; FILE_TYPE_CHANGED: Dateityp änderte sich; FILE_STATE_CHANGED: Dateistatus änderte sich; UNSUPPORTED_FILE_TYPE: außerhalb ROWS-/LOG-Scope; FILE_NOT_ONLINE: nicht ONLINE; IDENTITY_FIELD_UNKNOWN: Identitätsfeld fehlt; IDENTITY_OBSERVATION_CHANGED: Identitätsbeobachtung änderte sich; NATIVE_FILE_UNAVAILABLE: Online-ROWS-/LOG-Datei fehlt im nativen Cache. |

#### InternalCompleteFileIOCycle – Fachliche Bindungen und Fehlerbehandlung

Der Helper verlangt SC-023-Version 1.3.1 / Schema 3 und den tatsächlich installierten schreibfreien Retentionshandshake. Eigener Lauf ist nur die unbeschriebene FILE_IO-CaptureRun-Zeile mit Status RUNNING. Fehlender, fremder, abgeschlossener oder bereits beschriebener Lauf ergibt INVALID_PARAMETER / 51011 und wird nicht finalisiert. Eine ungültige aktive Policy (53783) nach OwnRun=1 wird zunächst als ERROR_HANDLED behandelt; der getrennte Fehlerabschluss kann scheitern und FINALIZATION_UNCONFIRMED ergeben. Die nichtfatalen Sourcezustände AVAILABLE, EMPTY_UNPROVEN und PARTIAL verlangen Enginekontext und Messfenster; DENIED_PERMISSION, UNAVAILABLE_OBJECT und ERROR_HANDLED sind fatal und verlangen engine=NULL. NOT_STARTED: leeres databases-Array verlangt native Anzahl 0; nichtleeres Array verlangt fatalen Status und Anzahl NULL. SUCCEEDED kann bei fatalem Status die native Anzahl behalten, aber files bleibt leer; bei nichtfatalem Status entspricht FILE-Anzahl der nativen Anzahl. FAILED verlangt fatalen Status, Anzahl NULL und kein Readfenster. sourceComplete=true gilt nur bei AVAILABLE oder EMPTY_UNPROVEN; außerdem müssen alle DB-Metadaten AVAILABLE sein, UNBOUND fehlen und Issues auf UNSUPPORTED_FILE_TYPE, FILE_NOT_ONLINE, IDENTITY_OBSERVATION_CHANGED oder IDENTITY_FIELD_UNKNOWN begrenzt sein. Der Selektionshash nutzt SQL-spezifisches FOR JSON; requestedDatabaseNames und requestedDatabaseNamePattern sind unveränderte, opake Provenienzlabels. Framework-ID, -Name und -CreateDate müssen master.sys.databases und CaptureRun.SourceDatabaseName treffen; dies belegt keine authentische DMV-Herkunft. Datenbankanzahl, Identitäten, Dateien und Issues sind gebunden.

Eine identitätsunvollständige, sonst geeignete Datei kann ELIGIBLE sein und sieben numerische Rohwerte mit Partialstatus als Per-Run-Beobachtung erhalten; sie erhält keinen Differenzvergleich. UNBOUND bezeichnet dagegen eine wegen DB-/Metadaten-/Typ-/Statusabweichung nicht ausgewählte Rohzeile und erzeugt keine Raw-Messwerte. Ausgeschlossene Dateien bleiben von geeigneten unterscheidbar. MaxRows der aktiven FILE_IO-Policy ist 1..100000 und begrenzt geschriebene Dateizeilen. Pro ausgewählter Datei: sieben Rohwerte, Status und Dateikontext; bis zu sechs Differenzkandidaten nur bei belegter Vergleichbarkeit. Ein regulär abgeschlossener nichtfataler Lauf speichert zusätzlich genau ein IO_CAPTURE_CONTEXT-Sample auf dem Serverscope, auch bei null ausgewählten Dateien. Die tatsächliche Metrikzahl beträgt damit 9 × geschriebene Dateien + 6 × vergleichbare Dateien + 1: je ausgewählter Datei sieben Rohwerte, ein Status- und ein Dateikontextsample sowie sechs Kandidaten je vergleichbarer Datei. Fatale Sourcepfade überspringen diese Metrikpersistierung. Erfolgreiche Vollaufnahme bleibt PARTIAL; weder atomare Katalog-/DMV-Sicht noch Resetkontinuität wird behauptet. Optionales GZIP nur für reguläre valide Sourcezweige.

Nach Catch rollt der Helper zurück. Getrennte Fehlerfinalisierung ohne Payload wird nur bei OwnRun=1, erneut bestätigtem Target und bestätigtem unbeschriebenen Lauf. Nach validierter Source können SourceErrorNumber und SourceErrorMessage trotz Backendfehler NULL bleiben; der tatsächliche Backendfehler steht in ModuleStatus. Sourceissues bleiben gebunden. Geschlossene Finalisierung kann ERROR_HANDLED ergeben; offene/fehlgeschlagene kann FINALIZATION_UNCONFIRMED liefern. ErrorMessageOut erhält keinen angefügten Vergleichscode; Sourcefehlertext wird nicht gefiltert. Fehlende Beobachtungen werden nicht als Nullsamples erzeugt.
Kanonische JSON-Zahlen sind Ganzzahlen ohne Dezimalpunkt oder Exponent und ohne führende Nullen außer 0. ID-Werte liegen zwischen 1 und 2147483647, INT-Fehlernummern zwischen -2147483648 und 2147483647, TINY-Werte zwischen 0 und 255. Nichtnegative bigint-Werte reichen von 0 bis 9223372036854775807; Vorzeichen sind dort unzulässig. CreateLsn ist eine JSON-Zeichenfolge mit einem kanonischen nichtnegativen decimal(25,0)-Ganzzahlwert. Native Zeitzeichenfolgen sind genau 23 Zeichen lang und müssen den SQL-datetime-Rundtrip bestehen; UTC-Zeichenfolgen sind gültige datetime2(3)-Werte mit genau 24 Zeichen einschließlich abschließendem Z. Stringgrenzen beziehen sich auf UTF-16-Codeeinheiten. Issue.ScopeType hat maximal 16, Issue.StatusCode und DB.MetadataStatusCode maximal 40; META.resultName, META.statusCode und META.nativeReadState ebenfalls maximal 40.

Die Identitäts- und Kontextprüfungen prüfen die übergebenen Daten auf Konsistenz; sie authentifizieren die Erfassung nicht nachträglich. Die frühe Targetabfrage gegen master.sys.databases liegt vor TRY und kann einen SQL-Fehler ungefangen weiterreichen. Die Retentionsprobe muss tatsächlich AVAILABLE, Vertrag 3, keine Run-ID, keine Fehlernummer und Budgetsignal 0 zurückgeben. Die aktive FILE_IO-Policy verlangt MaxRows von 1 bis 100000 und einen nicht-NULL PayloadEnabled-Wert. Die Source-Meldung bindet den ersten Issue mit nicht-NULL Fehlernummer, ersatzweise den ersten Issue in Arrayreihenfolge; ohne Issues sind beide META-Fehlerwerte NULL. Metadatennamen und Katalogwerte sind damit auf innere Konsistenz geprüft, nicht auf eine kryptografisch authentische DMV-Herkunft.

Ein nachfolgender SQL-Fehler kann nach bereits validierter Source deren ursprüngliche Fehlernummer und Meldung als Ausgabe erhalten, einschließlich NULL oder Leertext; der tatsächliche SQL-Fehler wird separat in ModuleStatus festgehalten, soweit die Fehlerfinalisierung gelingt. Schlägt dieser Versuch fehl, kann FINALIZATION_UNCONFIRMED stattdessen die dabei entstandene SQL-Fehlernummer und Meldung ausgeben. Eine offene Finalisierungsgrenze ist kein erfolgreicher Runabschluss.

### `[snapshot].[InternalFinalizeCollectionCycle]`

Quelle: `Code/10_SnapshotBaseline/060_InternalFinalizeCollectionCycle.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Schreibt Abschlussstatus und Diagnosedaten in die adressierte CaptureRun-Zeile und zählt zugehörige MetricSample- und PayloadSnapshot-Zeilen. |
| Schnittstelle | Interne Stored Procedure mit fünf obligatorischen Eingabeparametern. Keine OUTPUT-Parameter und kein Resultset. |
| Verwendung | Öffentliche Procedures im Schema monitor rufen den Baustein zur Orchestrierung auf. Anwendungen sollen ihn nicht direkt ausführen und nicht von Parameterreihenfolge oder internen Zwischenstrukturen abhängen. |
| Last und Sperren | Aktualisiert die passende CaptureRun-Zeile, setzt EndedAtUtc auf SYSUTCDATETIME() und berechnet MetricSampleCount sowie PayloadCount per COUNT_BIG aus MetricSample und PayloadSnapshot. Eine beendete Zeile darf erneut finalisiert werden. Es gibt keine zugesicherte stabile gemeinsame Momentaufnahme bei konkurrierenden Änderungen, keine eigene Transaktion und keinen CATCH für native Fehler; LOCK_TIMEOUT ist 0. |
| Vertrag | Nicht öffentlicher Vertrag für versiongleiche interne Aufrufer. Keine einmalige Finalisierung oder stabile gemeinsame Zählmomentaufnahme zugesichert. |

#### Parameter von InternalFinalizeCollectionCycle

| Parameter | Vertrag |
|---|---|
| `@CaptureRunId` | bigint; **Default: Kein Default. Weglassen ist nicht zulässig.** Einzelne Pflicht-ID, keine Positivitäts-/Existenzprüfung. NULL/kein Treffer aktualisiert null Zeilen ohne eigene Fehlermeldung; erneute Finalisierung möglich. Fehlendes Argument scheitert beim Aufruf, nicht gleich NULL. |
| `@StatusCode` | varchar(40); **Default: Kein Default. Weglassen ist nicht zulässig.** Pflichttext unverändert. CaptureRun hat keine Status-CHECK-Wertemenge; jeder nicht-NULL-Text inklusive Leertext ist speicherbar. NULL scheitert bei Treffer an NOT NULL. Keine IsPartial-Konsistenzprüfung. |
| `@IsPartial` | bit; **Default: Kein Default. Weglassen ist nicht zulässig.** Pflichtwert 0 = nicht partiell, 1 = partiell; leerer Text ist keine unterstützte Schalterform; direkte Speicherung. NULL scheitert bei Treffer an NOT NULL. Keine Statuskonsistenzprüfung. |
| `@ErrorNumber` | int; **Default: Kein Default. Weglassen ist nicht zulässig.** Pflichtargument; NULL löscht den nullable Spaltenwert. Jede vorzeichenbehaftete int-Zahl wird als Callerdiagnose gespeichert, ohne Validierung oder Fehlerauslösung. |
| `@ErrorMessage` | nvarchar(2048); **Default: Kein Default. Weglassen ist nicht zulässig.** Pflichtargument; NULL löscht, Leertext wird gespeichert. Unveränderter Unicode-Rohtext wird nicht ausgeführt oder normalisiert. |


#### Abschluss und Grenzen von InternalFinalizeCollectionCycle

Bei passender CaptureRunId setzt die Procedure EndedAtUtc auf SYSUTCDATETIME(), übernimmt die Eingaben StatusCode, IsPartial, ErrorNumber und ErrorMessage und setzt MetricSampleCount sowie PayloadCount auf die jeweiligen COUNT_BIG-Ergebnisse aus MetricSample und PayloadSnapshot. Eine beendete Zeile darf erneut finalisiert werden.

Die beiden Zählabfragen garantieren bei konkurrierenden Änderungen keine stabile gemeinsame Momentaufnahme. Es gibt keine eigene Transaktion und keinen CATCH für native Fehler; LOCK_TIMEOUT ist 0. Ohne passende Lauf-ID bleibt die Zeilenanzahl null, ohne Resultset oder eigene Fehlermeldung.

### `[snapshot].[InternalPurgeExpiredData]`

Quelle: `Code/10_SnapshotBaseline/070_InternalPurgeExpiredData.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Löscht Snapshotdaten in begrenzten Batches. Ablaufzeiten gelten für Messwerte, Payloads und zugehörige Läufe; verwaiste Scopes ungleich SERVER werden ohne Altersprüfung entfernt. |
| Schnittstelle | Interne Stored Procedure mit zwölf Parametern; vollständige Einzelverträge folgen in der Parametertabelle. |
| Verwendung | Öffentliche Procedures im Schema monitor rufen diesen Baustein zur Orchestrierung auf. Anwendungen sollen ihn weder direkt ausführen noch von Parameterreihenfolge oder temporären Zwischenstrukturen abhängen. |
| Last und Sperren | Normaler Lauf liest DEFAULT-Aufbewahrungsrichtlinie und löscht je Iteration bis PurgeBatchRows pro Tabelle unter LOCK_TIMEOUT 0. Messwerte nach CollectedAtUtc/RawRetentionDays, Payloads nach CapturedAtUtc/PayloadRetentionDays, verwaiste ModuleStatus- und CaptureRun-Zeilen nach StartedAtUtc/RawRetentionDays; Scopes ungleich SERVER ohne Altersprüfung. Keine Rollup-Löschung. |
| Vertrag | Nicht öffentlicher Vertrag. Status, Fehlerausgaben und Seiteneffekte gelten für versiongleiche interne Aufrufer. Jede Iteration führt BEGIN/COMMIT aus; bei äußerer Caller-Transaktion persistiert ein verschachteltes COMMIT nicht unabhängig und CATCH kann die gesamte äußere Transaktion zurückrollen. Ohne äußere Transaktion bleiben zuvor committete Iterationen bei einem späteren Fehler erhalten. Vorprüfungen, Richtlinien-/Größenlesung und Receipt-INSERT liegen außerhalb TRY. |

#### InternalPurgeExpiredData – Parameter

Die ersten sieben Argumente müssen übergeben werden. OUTPUT-Argumente dürfen ohne OUTPUT-Kennzeichnung gebunden werden, wenn die Ausgabe verworfen wird; zum Empfang sind Variable und OUTPUT-Kennzeichnung erforderlich. Eingehende Werte aller OUTPUT-Parameter, auch NULL oder Leertext, werden ignoriert.

| Parameter | Vertrag |
|---|---|
| `@MaxBatches int` | Kein Default; Argument muss übergeben werden; Nicht-NULL ganze Zahl 1 bis 1000. NULL macht die BETWEEN-Prüfung UNKNOWN und löst den Guard nicht aus. Ohne frühere Rückkehr können Receipt und Status AVAILABLE mit null Schleifeniterationen entstehen. Ein Nicht-NULL-Wert außerhalb 1 bis 1000 ergibt INVALID_PARAMETER, ErrorNumber bleibt NULL. Leertext keine unterstützte Zahleneingabe. Begrenzt Schleifeniterationen, nicht Zeilen. Bei ContractOnly=1 ignoriert, aber Argument muss übergeben werden. |
| `@Force bit` | Kein Default; erforderlich; Werte 0/1, NULL nicht abgewiesen. Leertext keine unterstützte Bit-Eingabe. 0 überspringt nur bei zugeteilter Typ-0-Dateikapazität innerhalb des Budgets, einem vorhandenen letzten erfolgreichen AVAILABLE/AVAILABLE_LIMITED-Lauf und noch nicht abgelaufenem Intervall. 1 umgeht diese Prüfung; NULL erfüllt Force=0 ebenso wenig. Bei ContractOnly=1 ignoriert. Force ändert nur die Skip-Berechtigung. Es lockert keine Retention-Grenze für Messwerte, Payloads oder Läufe; Scope-Bereinigung bleibt altersunabhängig. |
| `@PurgeRunIdOut bigint OUTPUT` | Kein Default; muss auch bei verworfener Ausgabe übergeben werden; NULL-/Leertext-Eingaben werden ignoriert. Eingang ignoriert, initial NULL; normale Receipt-ID erst nach Vorprüfungen, kein Erfolgsnachweis. Bei Handshake, Skip oder frühem Abbruch NULL. MaxBatches=NULL kann nach Receipt-INSERT null Iterationen und AVAILABLE ergeben; ein Nicht-NULL-Bereichsfehler kehrt vor Receipt zurück. Empfang bigint oder kompatibel. |
| `@StatusCodeOut varchar(40) OUTPUT` | Kein Default; erforderlich zu übergeben; NULL-/Leertext-Eingaben werden ignoriert. Eingang ignoriert, Anfang AVAILABLE; Ein regulär erfolgreicher Handshake belässt AVAILABLE; frühe Guards können andere Statuswerte setzen. Empfang varchar(40) oder kompatibel. Statuswerte siehe unten. |
| `@BudgetExceededOut bit OUTPUT` | Kein Default; erforderlich. Eingang ignoriert, initial 0. Handshake/früher Fehler kann „nicht gemessen“ bedeuten; Überspringen: vorher innerhalb Budget. Erfolgreich: Typ-0-Dateigröße strikt über SoftBudgetMB ergibt 1, Gleichheit 0. CATCH setzt 1 konservativ, nicht als Messung. Empfang bit oder kompatibel. |
| `@ErrorNumberOut int OUTPUT` | Kein Default; erforderlich. Eingang ignoriert, initial NULL; Fehlernummer bei behandelten Fehlern. MaxBatches-Bereichsfehler lässt NULL. Frühe ContractOnly-NULL-/Implicit-Guards 51011, Identität 53764. Empfang int oder kompatibel. |
| `@ErrorMessageOut nvarchar(2048) OUTPUT` | Kein Default; erforderlich; NULL-/Leertext-Eingaben werden ignoriert. Eingang ignoriert, initial NULL, bei Fehler Fehlermeldung oder Guard-Text. Empfang Unicode-Variable bis 2048 Zeichen. |
| `@ContractOnly bit` | Default 0; optional, auslassbar; 0 normal, 1 nur Handshake, NULL INVALID_PARAMETER/RETURN 51011. Leertext keine unterstützte Bit-Eingabe. Handshake löscht nicht, schreibt kein Receipt, misst kein Budget; liest PackageVersion und gegebenenfalls Identitätsmetadaten, setzt NOCOUNT und LOCK_TIMEOUT 0. Erfordert IMPLICIT_TRANSACTIONS OFF. |
| `@RetentionContractVersionOut int OUTPUT` | Default NULL; optional, auslassbar oder zum Empfang binden. NULL-Eingabe zulässig; Leertext keine unterstützte Zahleneingabe. Eingang ignoriert; anfangs 1, dann 3 bei irgendeiner PackageVersion-Zeile mit SchemaVersion 3 und Version 1.2.2, 1.3.0 oder 1.3.1, sonst 1. Auslassen verwirft Ausgabe. Wert 1 beweist kein Schema 1; Wert 3 keine vollständige Zielqualifikation. Empfang int oder kompatibel. |
| `@ExpectedTargetDatabaseId int` | Default NULL; optional. Weglassen verwendet NULL. Erwartet eine ganze Datenbank-ID größer als 4, die DB_ID() der aktuell verbundenen Datenbank entspricht; Leertext ist keine vorgesehene Zahlenform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; sobald irgendein Feld gesetzt ist, müssen alle drei zur gleichen online und schreibbaren Zieldatenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Die Datenbank wird nicht gewechselt. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder irgendeinem gesetzten Identitätsfeld verlangt; für ContractOnly=0 mit allen drei NULL gibt es diesen Guard nicht. |
| `@ExpectedTargetDatabaseName sysname` | Default NULL; optional. Weglassen verwendet NULL. Erwartet den rohen Datenbanknamen als sysname-Wert, der ohne Trimmen oder Schreibweisennormalisierung binär mit master.sys.databases.name übereinstimmt; Leertext passt nicht. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei vorliegen und zur online und schreibbaren aktuellen Datenbank passen. Sonst folgen TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht. |
| `@ExpectedTargetCreateDate datetime` | Default NULL; optional. Weglassen verwendet NULL. Erwartet den typisierten datetime-Wert von master.sys.databases.create_date der Zieldatenbank, ohne UTC-Konvertierung; Leertext ist keine vorgesehene Datumsform. Alle drei Identitätswerte dürfen NULL sein, auch im Handshake; bei irgendeinem gesetzten Feld müssen alle drei zur online und schreibbaren aktuellen Datenbank passen. Eine Abweichung ergibt TARGET_UNAVAILABLE und 53764. Kein Datenbankwechsel. IMPLICIT_TRANSACTIONS OFF wird bei ContractOnly=1 oder einem gesetzten Identitätsfeld verlangt; bei ContractOnly=0 und vollständigem NULL-Tripel gibt es diesen Guard nicht. |

#### InternalPurgeExpiredData – Status- und Fehlerverhalten

| Status | Bedeutung |
|---|---|
| `AVAILABLE` | Nicht übersprungen und Limit nicht mit löschendem letzten Batch ausgeschöpft; Handshake behält Anfangsstatus. Kein Nachweis gelöschter Daten. |
| `INVALID_PARAMETER` | ContractOnly NULL oder frühe Vertragsverletzung. Ein Nicht-NULL-MaxBatches außerhalb 1 bis 1000 setzt Status, aber ErrorNumber bleibt NULL. |
| `TARGET_UNAVAILABLE` | Zielidentität unvollständig oder weicht von aktueller DB/master-Metadaten ab; 53764. |
| `SKIPPED_NOT_DUE` | Force=0 und Budget-, Vorlauf- und Intervallbedingungen erlauben Überspringen; BudgetExceeded=0 heißt hier vorher innerhalb Budget. |
| `AVAILABLE_LIMITED` | Batchlimit erreicht und letzter Batch löschte mindestens eine Zeile; kein Beleg weiterer abgelaufener Zeilen. |
| `DENIED_PERMISSION` | Im CATCH erfasste Nummer 229, 262, 297, 300 oder 371. |
| `ERROR_HANDLED` | Anderer CATCH-Fehler. TRY deckt nicht jeden Fehler ab; CATCH-Audit-UPDATE kann selbst fehlschlagen. |

RUNNING ist nur ein Receipt-Zustand, kein StatusCodeOut-Wert. Zähler können bei CATCH Versuche aus zurückgerollter Iteration enthalten und bestätigen keinen Commit.

#### InternalPurgeExpiredData – Daten-, Transaktions- und Budgetgrenzen

Je Iteration gilt PurgeBatchRows pro Tabelle. Messwerte nutzen CollectedAtUtc/RawRetentionDays, Payloads CapturedAtUtc/PayloadRetentionDays. ModuleStatus und CaptureRun folgen StartedAtUtc/RawRetentionDays, wenn Kinddaten fehlen. Geschützt bleibt der neueste finalisierte WAIT_STATS-Lauf sowie der neueste FILE_IO-Lauf auch ohne Finalisierung oder Kinddaten. Verwaiste Scopes ungleich SERVER haben keine Altersbedingung. Rollups werden nicht gelöscht.

Jede Iteration führt BEGIN/COMMIT aus. Bei äußerer Caller-Transaktion persistiert ein verschachteltes COMMIT die Iteration nicht unabhängig; CATCH kann die gesamte äußere Transaktion zurückrollen. Ohne äußere Transaktion bleiben zuvor committete Iterationen bei späterem Fehler bestehen. Vorprüfungen, Richtlinien-/Größenlesung und Receipt-INSERT liegen außerhalb TRY. CATCH-Audit-UPDATE kann selbst fehlschlagen. Kein @@TRANCOUNT-Guard: explizite Caller-Transaktionen werden nicht abgewiesen. ContractOnly=1 und jede gesetzte Identität verlangen jedoch IMPLICIT_TRANSACTIONS OFF.

Budgetmessung summiert Dateigrößen Typ 0 und rechnet Seiten in MB um; sie misst nicht belegte Snapshot-/Payload-Bytes oder Logdateien. Kein Shrink; Budget kann nach Purge überschritten bleiben. BudgetExceeded=0 bei Handshake/frühem ungültigem Ende kann „nicht gemessen“ heißen; CATCH setzt 1 vorsorglich, nicht als Messergebnis. Receipt-ID entsteht nach Vorprüfungen und beweist keinen Erfolg. Der Normalpfad setzt XACT_ABORT ON und LOCK_TIMEOUT 0; der Handshake erreicht XACT_ABORT ON nicht.

## Tabellen

### `[monitor].[ToolBackgroundQueryPattern]`

Quelle: `Code/01_Common/087a_ToolBackgroundQueryPattern.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Enthält die pflegbaren, metadatengesteuerten Erkennungsmuster für Tool-Hintergrundabfragen. Direkte Änderungen außerhalb des dokumentierten Administrationswegs sind nicht Teil des öffentlichen Vertrags. |
| Schnittstelle | Persistente Tabelle mit 11 in der Quelle typisierten Spalten: `RuleCode`, `Priority`, `IsEnabled`, `ProgramNameLikePattern`, `ToolBackgroundCategory`, `ToolBackgroundDetection`, `ToolBackgroundConfidence`, `SourceUrl`, `SourceNotes`, `IsFrameworkDefault`, `LastVerifiedUtc`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle wird von den zugehörigen Framework-Procedures gelesen oder gepflegt. Direkte DML kann Katalog- oder Analyseverträge verletzen und ist daher kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine, überwiegend read-only Framework-Metadatentabelle. DML erfolgt nur über Installer oder den dokumentierten Konfigurationspfad; Analysen lesen wenige Zeilen. Sperren bleiben auf die kurze Metadatenpflege begrenzt. |
| Vertrag | Persistenter interner Frameworkvertrag. Schema und Seeds werden über den Installer gepflegt; direkte Abhängigkeiten externer Anwendungen sind nicht unterstützt. |

### `[monitor].[SqlServerBuildCatalog]`

Quelle: `Code/09_VersionAdaptive/011_SqlServerBuildCatalog.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Stellt die kuratierte Build- und Servicingzuordnung für die Offlinebewertung der Serverversion bereit. |
| Schnittstelle | Persistente Tabelle mit 16 in der Quelle typisierten Spalten: `BuildVersion`, `ProductMajorVersion`, `BuildNumber`, `RevisionNumber`, `ReleaseName`, `ServicingBranch`, `KnowledgeBaseNumber`, `ReleaseDate`, `PlatformScope`, `IsSecurityRelease`, `IsLatestInBranch`, `BuildOverviewUrl` sowie 4 weitere Spalten. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle wird von den zugehörigen Framework-Procedures gelesen oder gepflegt. Direkte DML kann Katalog- oder Analyseverträge verletzen und ist daher kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine, überwiegend read-only Framework-Metadatentabelle. DML erfolgt nur über Installer oder den dokumentierten Konfigurationspfad; Analysen lesen wenige Zeilen. Sperren bleiben auf die kurze Metadatenpflege begrenzt. |
| Vertrag | Persistenter interner Frameworkvertrag. Schema und Seeds werden über den Installer gepflegt; direkte Abhängigkeiten externer Anwendungen sind nicht unterstützt. |

### `[monitor].[SqlServerLifecycleCatalog]`

Quelle: `Code/09_VersionAdaptive/012_SqlServerLifecycleCatalog.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Stellt die kuratierte Lifecyclezuordnung für die Offlinebewertung bereit. |
| Schnittstelle | Persistente Tabelle mit 9 in der Quelle typisierten Spalten: `ProductMajorVersion`, `ProductName`, `StartDate`, `MainstreamEndDate`, `ExtendedEndDate`, `LifecyclePolicy`, `LifecycleUrl`, `CatalogAsOfDate`, `SourceRetrievedAtUtc`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle wird von den zugehörigen Framework-Procedures gelesen oder gepflegt. Direkte DML kann Katalog- oder Analyseverträge verletzen und ist daher kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine, überwiegend read-only Framework-Metadatentabelle. DML erfolgt nur über Installer oder den dokumentierten Konfigurationspfad; Analysen lesen wenige Zeilen. Sperren bleiben auf die kurze Metadatenpflege begrenzt. |
| Vertrag | Persistenter interner Frameworkvertrag. Schema und Seeds werden über den Installer gepflegt; direkte Abhängigkeiten externer Anwendungen sind nicht unterstützt. |

### `[monitor].[PlanAnalysisProfile]`

Quelle: `Code/04_PlanCache/041_PlanAnalysisProfile.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Definiert benannte Analyseprofile für die Ausführungsplananalyse. |
| Schnittstelle | Persistente Tabelle mit 7 in der Quelle typisierten Spalten: `ProfileCode`, `Description`, `Priority`, `IsEnabled`, `IsFrameworkDefault`, `SeedVersion`, `LastUpdatedUtc`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle wird von den zugehörigen Framework-Procedures gelesen oder gepflegt. Direkte DML kann Katalog- oder Analyseverträge verletzen und ist daher kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine, überwiegend read-only Framework-Metadatentabelle. DML erfolgt nur über Installer oder den dokumentierten Konfigurationspfad; Analysen lesen wenige Zeilen. Sperren bleiben auf die kurze Metadatenpflege begrenzt. |
| Vertrag | Persistenter interner Frameworkvertrag. Schema und Seeds werden über den Installer gepflegt; direkte Abhängigkeiten externer Anwendungen sind nicht unterstützt. |

### `[monitor].[PlanAnalysisRuleThreshold]`

Quelle: `Code/04_PlanCache/042_PlanAnalysisRuleThreshold.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Hinterlegt je Analyseprofil die Schwellenwerte der Plananalyse-Regeln. |
| Schnittstelle | Persistente Tabelle mit 24 in der Quelle typisierten Spalten: `RuleCode`, `ProfileCode`, `Severity`, `IsEnabled`, `MinRatio`, `MaxRatio`, `MinAbsoluteRows`, `MinRowsRead`, `MinRowsNotReturned`, `MinRowsNotReturnedPercent`, `MinExecutionCount`, `MinLogicalReadsPerExecution` sowie 12 weitere Spalten. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle wird von den zugehörigen Framework-Procedures gelesen oder gepflegt. Direkte DML kann Katalog- oder Analyseverträge verletzen und ist daher kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine, überwiegend read-only Framework-Metadatentabelle. DML erfolgt nur über Installer oder den dokumentierten Konfigurationspfad; Analysen lesen wenige Zeilen. Sperren bleiben auf die kurze Metadatenpflege begrenzt. |
| Vertrag | Persistenter interner Frameworkvertrag. Schema und Seeds werden über den Installer gepflegt; direkte Abhängigkeiten externer Anwendungen sind nicht unterstützt. |

### `[monitor].[PlanAnalysisProfileAssignment]`

Quelle: `Code/04_PlanCache/043_PlanAnalysisProfileAssignment.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ordnet einer Plananalyse ein passendes Profil zu. |
| Schnittstelle | Persistente Tabelle mit 16 in der Quelle typisierten Spalten: `AssignmentId`, `Priority`, `IsEnabled`, `ProfileCode`, `DatabaseNamePattern`, `SchemaNamePattern`, `ObjectNamePattern`, `QueryHash`, `QueryStoreQueryId`, `StatementId`, `ProgramNameLikePattern`, `ResourcePoolId` sowie 4 weitere Spalten. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle wird von den zugehörigen Framework-Procedures gelesen oder gepflegt. Direkte DML kann Katalog- oder Analyseverträge verletzen und ist daher kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine, überwiegend read-only Framework-Metadatentabelle. DML erfolgt nur über Installer oder den dokumentierten Konfigurationspfad; Analysen lesen wenige Zeilen. Sperren bleiben auf die kurze Metadatenpflege begrenzt. |
| Vertrag | Persistenter interner Frameworkvertrag. Schema und Seeds werden über den Installer gepflegt; direkte Abhängigkeiten externer Anwendungen sind nicht unterstützt. |

### `[monitor].[SnapshotTargetConfiguration]`

Quelle: `Code/10_SnapshotBaseline/010_SnapshotTargetConfiguration.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Hält als typisierter Singleton das ausdrücklich konfigurierte lokale Snapshotziel. Ohne separate Paketinstallation bleibt der Frameworkkern zustandslos. |
| Schnittstelle | Persistente Tabelle mit 8 in der Quelle typisierten Spalten: `ConfigurationId`, `TargetDatabaseName`, `IsEnabled`, `DefaultSchedulerType`, `PackageContractVersion`, `SeedVersion`, `LastUpdatedUtc`, `RowVersion`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle wird von den zugehörigen Framework-Procedures gelesen oder gepflegt. Direkte DML kann Katalog- oder Analyseverträge verletzen und ist daher kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine Singleton-Konfiguration. Nur die öffentliche Konfigurations-Procedure schreibt transaktional; normale Prüfungen lesen eine Zeile. Daraus entstehen keine volumenabhängigen Scans oder anhaltenden Nutzerdatensperren. |
| Vertrag | Persistenter interner Frameworkvertrag. Schema und Seeds werden über den Installer gepflegt; direkte Abhängigkeiten externer Anwendungen sind nicht unterstützt. |

### `[snapshot].[PackageVersion]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Versioniert Paket und Zielschema und protokolliert den letzten Installerlauf. |
| Schnittstelle | Persistente Tabelle mit 5 in der Quelle typisierten Spalten: `PackageCode`, `PackageVersion`, `SchemaVersion`, `InstalledAtUtc`, `LastInstallerRunUtc`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine Paketmetadatentabelle. Der versionierte Installer aktualisiert genau die SC-023-Zeile; Betriebsprüfungen lesen sie punktuell. Dadurch entstehen nur kurze Schlüssel- und Zeilensperren, keine volumenabhängigen Scans. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

### `[snapshot].[RetentionPolicy]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Definiert typisierte Retention-, Batch- und Softbudgetgrenzen. |
| Schnittstelle | Persistente Tabelle mit 11 in der Quelle typisierten Spalten: `RetentionPolicyCode`, `RawRetentionDays`, `PayloadRetentionDays`, `RollupRetentionDays`, `SoftBudgetMB`, `PurgeIntervalMinutes`, `PurgeBatchRows`, `BudgetAction`, `IsFrameworkDefault`, `SeedVersion`, `LastUpdatedUtc`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine Policytabelle. Die öffentliche Konfiguration schreibt die ausgewählte Policy transaktional; Collection und Purge lesen wenige Zeilen. Die Last ist nicht von der Menge persistierter Samples abhängig. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

### `[snapshot].[CollectorPolicy]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Begrenzt Intervall, Zeilenumfang und optionales Payload je Collector. |
| Schnittstelle | Persistente Tabelle mit 9 in der Quelle typisierten Spalten: `CollectorCode`, `IsEnabled`, `CollectionIntervalSeconds`, `MaxRows`, `PayloadEnabled`, `RetentionPolicyCode`, `IsFrameworkDefault`, `SeedVersion`, `LastUpdatedUtc`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine Policytabelle. Die öffentliche Konfiguration aktualisiert Collectorgrenzen transaktional; der Scheduler liest die aktive Zeile. Sperren bleiben auf kurze Schlüssel- und Zeilenzugriffe begrenzt. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

### `[snapshot].[CaptureRun]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Speichert Lauf, Schedulerherkunft, UTC-Grenzen, Reset-Epoche und Gesamtstatus. |
| Schnittstelle | Persistente Tabelle mit 15 in der Quelle typisierten Spalten: `CaptureRunId`, `CollectorCode`, `SchedulerType`, `StartedAtUtc`, `EndedAtUtc`, `SourceDatabaseName`, `SqlServerStartTimeUtc`, `ResetEpochId`, `ContractVersion`, `StatusCode`, `IsPartial`, `ErrorNumber` sowie 3 weitere Spalten. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Persistenter Snapshot-Speicher. Collection erzeugt protokollierte Inserts; Retention löscht abgelaufene Zeilen child-first und begrenzt in Batches. Fremdschlüssel und Indizes bestimmen die kurzzeitigen Zeilen- und Schlüsselsperren. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

### `[snapshot].[ModuleStatus]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Bewahrt Partialität, Fehlergrenze und Evidenzlimit je Laufmodul. |
| Schnittstelle | Persistente Tabelle mit 9 in der Quelle typisierten Spalten: `ModuleStatusId`, `CaptureRunId`, `ModuleName`, `CollectionTimeUtc`, `StatusCode`, `IsPartial`, `ErrorNumber`, `ErrorMessage`, `EvidenceLimit`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Persistenter Snapshot-Speicher. Collection erzeugt protokollierte Inserts; Retention löscht abgelaufene Zeilen child-first und begrenzt in Batches. Fremdschlüssel und Indizes bestimmen die kurzzeitigen Zeilen- und Schlüsselsperren. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

### `[snapshot].[Scope]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ordnet gehashte technische Scopeidentitäten den persistierten Samples zu. |
| Schnittstelle | Persistente Tabelle mit 6 in der Quelle typisierten Spalten: `ScopeId`, `ScopeType`, `ParentScopeId`, `ScopeKeyHash`, `ScopeIdentityJson`, `CreatedAtUtc`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Persistenter Snapshot-Speicher. Collection erzeugt protokollierte Inserts; Retention löscht abgelaufene Zeilen child-first und begrenzt in Batches. Fremdschlüssel und Indizes bestimmen die kurzzeitigen Zeilen- und Schlüsselsperren. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

### `[snapshot].[MetricDefinition]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Versioniert Metrikcode, Datentyp, Einheit und Bedeutung. |
| Schnittstelle | Persistente Tabelle mit 9 in der Quelle typisierten Spalten: `MetricDefinitionId`, `MetricCode`, `ValueType`, `Unit`, `ContractVersion`, `Description`, `IsFrameworkDefault`, `SeedVersion`, `LastUpdatedUtc`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Kleine, versionierte Definitions- und Seedtabelle. Der Installer pflegt Definitionen; Collection löst Metrik-IDs per indexiertem Lookup auf und verändert die Definitionen nicht. Die Last wächst nicht mit der Samplehistorie. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

### `[snapshot].[MetricSample]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Speichert genau einen typisierten Wert je Lauf, Scope und Metrikdefinition. |
| Schnittstelle | Persistente Tabelle mit 11 in der Quelle typisierten Spalten: `MetricSampleId`, `CaptureRunId`, `ScopeId`, `MetricDefinitionId`, `CollectedAtUtc`, `ResetEpochId`, `NumericValue`, `BigintValue`, `StringValue`, `QualityCode`, `IsPartial`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Persistenter Snapshot-Speicher. Collection erzeugt protokollierte Inserts; Retention löscht abgelaufene Zeilen child-first und begrenzt in Batches. Fremdschlüssel und Indizes bestimmen die kurzzeitigen Zeilen- und Schlüsselsperren. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

### `[snapshot].[PayloadSnapshot]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Hält optional den vollständigen komprimierten und hashgebundenen Collectorvertrag im autorisierten Zielsystem. |
| Schnittstelle | Persistente Tabelle mit 10 in der Quelle typisierten Spalten: `PayloadSnapshotId`, `CaptureRunId`, `ModuleName`, `CapturedAtUtc`, `PayloadFormat`, `PayloadContractVersion`, `CompressionType`, `PayloadHash`, `Payload`, `UncompressedCharacterCount`. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Persistenter Snapshot-Speicher. Collection erzeugt protokollierte Inserts; Retention löscht abgelaufene Zeilen child-first und begrenzt in Batches. Fremdschlüssel und Indizes bestimmen die kurzzeitigen Zeilen- und Schlüsselsperren. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

### `[snapshot].[PurgeRun]`

Quelle: `Code/10_SnapshotBaseline/030_Snapshot_Target_Schema.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Protokolliert ausschließlich technische Summen begrenzter Retentionläufe. |
| Schnittstelle | Persistente Tabelle mit 15 in der Quelle typisierten Spalten: `PurgeRunId`, `StartedAtUtc`, `EndedAtUtc`, `StatusCode`, `BatchesExecuted`, `MetricRowsDeleted`, `PayloadRowsDeleted`, `ModuleRowsDeleted`, `CaptureRunsDeleted`, `ScopeRowsDeleted`, `UsedDataMbBefore`, `UsedDataMbAfter` sowie 3 weitere Spalten. Schlüssel, Constraints und Defaults sind Bestandteil des Installationsskripts. |
| Verwendung | Die Tabelle gehört zum optionalen Snapshot-/Baseline-Paket und wird ausschließlich von dessen Installations-, Collection- und Retentionpfaden verwaltet. Direkte DML ist kein unterstützter Betriebsweg. |
| Last und Sperren | Schreibt pro Retentionlauf eine technische Laufzeile und aktualisiert deren Summen. Diese Metadaten sind klein gegenüber den Sampletabellen; die eigentlichen Löschkosten entstehen in den child-first verarbeiteten Evidenztabellen. |
| Vertrag | Persistenter interner Paketvertrag. Schemaänderungen erfolgen ausschließlich über den versionierten SC-023-Installer; außerhalb des Pakets besteht keine Kompatibilitätszusage. |

## monitor.USP_ExternalDataAnalysis

Öffentliche Procedure für lokale externe Kataloge. [Parameter und Vertrag](Procedure_Reference.md#monitorusp_externaldataanalysis).

### `[monitor].[InternalSsisScopePathMatch]`

Quelle: `Code/10_SSIS/034_InternalSsisScopePathMatch.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Vergleicht einen beobachteten Ausführungspfad mit einer qualifizierten Paketwurzel und den bereits vom Toolbelt klassifizierten Pfadschritten. |
| Schnittstelle | Die Table-Valued Function nimmt `@Root`, `@Path` und `@Steps` an und liefert genau eine Zeile mit `IsMatch`. Ein unbekannter oder ungültiger Vergleich liefert `0` als Bitwert. |
| Verwendung | Der interne Scopeconsumer verwendet das Ergebnis zusätzlich zu Paketname, GUID, nativem Paketpfad und eindeutiger Instanzbindung. Die Funktion liest weder DTSX noch SSISDB und klassifiziert keine Komponenten. |
| Last und Sperren | Der Vergleich verarbeitet höchstens 32 Schritte und je 4000 UTF-16-Codeeinheiten. Er erzeugt keine Katalogsperren; kanonische positive Iterationszähler werden nur an ausdrücklich qualifizierten Schritten akzeptiert. |
| Vertrag | Interner Bestandteil der optionalen Ausführungsscopeanalyse. Der öffentliche Einstieg bleibt `USP_SsisPackageModelAnalysis`; ein Pfadtreffer allein beweist keine Ausführung oder Lineage. |

### `[monitor].[InternalSsisExecutionScopes]`

Quelle: `Code/10_SSIS/035_InternalSsisExecutionScopes.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Validiert einen lokal attestierten Paketsatz und ordnet dessen gebundene Statistik- und Ereignisbeobachtungen eindeutigen Paketaufrufen und Handlerkörpern zu. |
| Schnittstelle | Die interne Procedure erhält die Dokumente und Ausgabeparameter vom öffentlichen Scopeopt-in. Sie liefert sieben benannte Ergebnisgruppen einschließlich Herkunftsstatus, Paketinstanzen, Einzelbelegen und partieller Abdeckung. Das Pipelineopt-in ergänzt vier eigene Gruppen; das Diagnoseopt-in ergänzt vier weitere Gruppen. |
| Verwendung | Aufrufer verwenden `USP_SsisPackageModelAnalysis` mit `IncludeExecutionScopes=1`. Parser, Pfadprofile und Lineage werden ausschließlich vom Toolbelt übernommen; gewöhnliche Caller können keine qualifizierten lokalen Belege registrieren. |
| Last und Sperren | Höchstens 16 Pakete, acht Aufrufebenen, 1024 Instanzen und 50000 Quellzeilen teilen ein kooperatives Zeitbudget. Die lokale Herkunftsentscheidung liest Receipt und Eigentümermetadaten committed mit dem expliziten Locktimeout und stellt den Callerwert wieder her. |
| Vertrag | Interner Consumer ohne SQL CLR. Mehrdeutige Instanzen bleiben unzugeordnet; Handlerbelege enthalten keine erfundene Auslöserkausalität. Ausgabegrenzen ändern die zuvor ermittelten Abdeckungszahlen nicht. |

### `[monitor].[InternalSsisPipelineCorrelation]`

Quelle: `Code/10_SSIS/036_InternalSsisPipelineCorrelation.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Ordnet optionale Komponentenphasen und Pfadtransfers bereits gebundenen Dataflow-Statistikinstanzen zu. |
| Schnittstelle | Der Scopeconsumer übergibt Paketsatz, Capture, Bindungsstatus, Deadline und Ausgabelimit. Seine vier temporären Ergebnisziele erhalten Instanzen, Einzelbelege und Quellenabdeckung. |
| Verwendung | Der öffentliche Einstieg verwendet `IncludeExecutionScopes=1` und `IncludePipelineCorrelation=1`. Toolbelt liefert die Referenzen auf vorhandene Komponenten, Ports und Kanten. |
| Last und Sperren | Der Baustein teilt das Zeit- und Zeilenbudget des Scopeconsumers und liest ausschließlich dessen temporäre Modelle und JSON. Er greift nicht auf SSISDB zu und erhält den Caller-Locktimeout. |
| Vertrag | Ein ordinal exakter eindeutiger Instanzpfad ist Voraussetzung. Komponenten werden anschließend über scoped Namen, Pfade zusätzlich über Referenz und Endpunkte zugeordnet. Zeitintervalle sind keine CPU-Zeit; Transferzähler sind keine globale Paketzeilenzahl. |

### `[monitor].[InternalSsisPipelineDiagnostics]`

Quelle: `Code/10_SSIS/037_InternalSsisPipelineDiagnostics.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Fasst bereits gebundene Phasen und Transfers innerhalb ihrer konkreten Dataflowinstanz zusammen und erzeugt endliche versionierte Diagnosehinweise. |
| Schnittstelle | Der Scopeconsumer übergibt validierte Modelle, Bindungsstatus, gemeinsame Deadline, Ausgabegrenze und einen optionalen Einzelintervall-Grenzwert. Vier temporäre Ausgabeziele enthalten Kennzahlen, Regelbelege und Abdeckung. |
| Verwendung | Der öffentliche Einstieg ergänzt `IncludePipelineDiagnostics=1` zur Scope- und Pipelinekorrelation. Statische Portrollen werden ausschließlich aus dem Toolbelt-Modell übernommen. |
| Last und Sperren | Gruppierungen und Fensterfunktionen verarbeiten höchstens den bereits begrenzten Capturebestand in eigenen Temp-Objekten. Es erfolgen keine zusätzlichen Katalogabfragen oder Berechtigungsänderungen. |
| Vertrag | Unbekannte Werte, Zuordnungslücken, überlappende Intervalle und Quellenkürzung bleiben sichtbar. Summen gelten nur je Instanz und Objekt; Hinweise belegen keine CPU-Zeit, Engpassursache oder globale Paketzeilenzahl. |

### `[monitor].[InternalValidateSnapshotWaitTarget]`

Quelle: `Code/10_SnapshotBaseline/076_InternalValidateSnapshotWaitTarget.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Prüft die gebundene Zielidentität, tatsächlich benötigte Wait- oder Datei-I/O-Signaturen, erforderliche Metrikdefinitionen und den lesenden Retentionsvertrag vor der Aufnahme. |
| Schnittstelle | Sechs Argumente sind erforderlich: Zielname und fünf OUTPUT-Parameter. Erwartete ID und Erstellungsdatum sind gemeinsam NULL oder gemeinsam angegeben. CollectorCode hat Default WAIT_STATS; zugelassen sind exakt WAIT_STATS und FILE_IO. |
| Verwendung | Interner gemeinsamer Eintritt für Konfiguration und Waitlauf; Anwendungen verwenden die öffentlichen Snapshot-Procedures. |
| Last und Sperren | Liest Datenbank-, Prozedur-, Parameter-, Metrik- und Policykataloge und führt eine ContractOnly-Retentionsprobe aus. Die Aussage ohne Produktwrite gilt für den vertrauenswürdigen kanonischen ContractOnly-Helper; andere installierte Inhalte werden dadurch nicht als schreibfrei bewiesen. |
| Vertrag | Ziel muss eine separate, online befindliche und beschreibbare Benutzerdatenbank mit ID > 4 sein. WAIT_STATS akzeptiert SC-023 1.2.1/Schema 2, 1.3.0/Schema 3 und 1.3.1/Schema 3; FILE_IO nur 1.3.1/Schema 3. Erwartete Retentionsvertragsversionen sind 1, 2 und 3 in derselben Paketversionsreihenfolge. Die neun Wait- beziehungsweise 16 Datei-I/O-Metriken sind erforderliche Teilmengen; zusätzliche Definitionen sind zulässig. CollectorPolicy muss vorhanden sein; ihre Aktivierung wird nicht geprüft. |

#### [monitor].[InternalValidateSnapshotWaitTarget] – Parametervertrag

| Parameter | Typ und Eingabeform | Default | Erforderlichkeit und Verhalten |
|---|---|---|---|
| @TargetDatabaseName | sysname; einzelner Name bis 128 Zeichen, Punkte bleiben Teil desselben Namens | kein Default | Erforderlich. NULL, leer oder nur Rand-Leerzeichen ist ungültig. Binärer Vergleich ohne Trimmen oder Fallnormalisierung; keine Qualifizierungsauslegung. |
| @ExpectedTargetDatabaseId | int; einzelner typisierter Skalar oder NULL | NULL | Optional. NULL bedeutet keine erwartete ID; bei Wert Vergleich mit tatsächlicher ID. Muss gemeinsam mit @ExpectedTargetCreateDate NULL oder angegeben sein. Leerer Text ist keine zulässige Eingabeform. |
| @ExpectedTargetCreateDate | datetime; einzelner typisierter Skalar oder NULL | NULL | Optional. NULL bedeutet kein erwartetes Erstellungsdatum; bei Wert Vergleich mit tatsächlichem datetime-Wert. Muss gemeinsam mit @ExpectedTargetDatabaseId NULL oder angegeben sein. Leerer Text ist keine zulässige Eingabeform. |
| @TargetDatabaseIdOut | int OUTPUT; typisierter Wert/NULL oder Empfangsvariable | kein Default | Erforderliches Argument; Eingabewert wird ignoriert und Ausgang auf NULL initialisiert. Liefert später die tatsächliche ID, die auch vor einem späteren Fehler befüllt sein kann. Für Rückgabe Variable und OUTPUT/OUT-Schlüsselwort erforderlich. |
| @TargetCreateDateOut | datetime OUTPUT; typisierter Wert/NULL oder Empfangsvariable | kein Default | Erforderliches Argument; Eingabewert wird ignoriert und Ausgang auf NULL initialisiert. Liefert später das tatsächliche Erstellungsdatum, das auch vor einem späteren Fehler befüllt sein kann. Für Rückgabe Variable und OUTPUT/OUT-Schlüsselwort erforderlich. |
| @StatusCodeOut | varchar(40) OUTPUT; typisierter Wert/NULL oder Empfangsvariable | kein Default | Erforderliches Argument; Eingabewert wird ignoriert und Status auf AVAILABLE initialisiert. Für Rückgabe Variable und OUTPUT/OUT-Schlüsselwort erforderlich. |
| @ErrorNumberOut | int OUTPUT; typisierter Wert/NULL oder Empfangsvariable | kein Default | Erforderliches Argument; Eingabewert wird ignoriert und Fehlernummer auf NULL initialisiert. Für Rückgabe Variable und OUTPUT/OUT-Schlüsselwort erforderlich. |
| @ErrorMessageOut | nvarchar(2048) OUTPUT; typisierter Wert/NULL oder Empfangsvariable | kein Default | Erforderliches Argument; Eingabewert wird ignoriert und Meldung auf NULL initialisiert. Für Rückgabe Variable und OUTPUT/OUT-Schlüsselwort erforderlich. |
| @CollectorCode | varchar(64); einzelner Auswahlcode | WAIT_STATS | Optional. WAIT_STATS wählt Waitstatistik, FILE_IO Datei-I/O. Ausschließlich diese beiden binär exakt verglichenen Werte sind gültig; NULL, andere Groß-/Kleinschreibung und Rand-Leerzeichen werden abgewiesen. |

Die sechs erforderlichen Argumente sind @TargetDatabaseName und die fünf OUTPUT-Parameter. Jeder OUTPUT-Ausgang wird beim Prozedurstart initialisiert: ID, Erstellungsdatum, Fehlernummer und Fehlermeldung auf NULL, Status auf AVAILABLE. Die Eingabewerte der OUTPUT-Argumente werden ignoriert. Für einen zurückzugebenden Ausgangswert muss eine passende Variable gebunden und OUTPUT/OUT angegeben werden; ohne Rückgabewunsch kann ein typisierter Wert oder NULL als Argument dienen.

#### [monitor].[InternalValidateSnapshotWaitTarget] – Aufnahmestatus

| Status | Bedeutung |
|---|---|
| AVAILABLE | Ziel- und Vertragsprüfung bestätigt die Aufnahme. |
| INVALID_PARAMETER | Eingabe, erwartete Identität oder Transaktionskontext ist ungültig; die frühe Parameterprüfung setzt Fehler 51011. |
| TARGET_UNAVAILABLE | Ziel oder erforderlicher Vertrag wurde nicht bestätigt. |
| DENIED_PERMISSION | Ein abgefangener Berechtigungsfehler verhinderte die Prüfung. |

#### [monitor].[InternalValidateSnapshotWaitTarget] – Aufnahme- und Probegrenzen

Eine explizite oder implizite Callertransaktion wird bereits bei der frühen Eingabeprüfung mit INVALID_PARAMETER / 51011 abgewiesen. Die Zielsuche in master.sys.databases liegt außerhalb des TRY/CATCH. Berechtigungsfehler 229, 262, 297, 300 und 371 werden innerhalb des TRY/CATCH als DENIED_PERMISSION abgebildet.

Die Retentionsprobe verlangt AVAILABLE, NULL für Fehlernummer und Run-ID, ein gesetztes Budgetsignal 0 sowie die erwartete Retentionvertragsversion. Eine Probe-Meldung darf befüllt sein und der Rückgabecode wird nicht geprüft. Für FILE_IO werden zuerst Existenz, Sichtbarkeit und ANSI-Einstellungen der Wait-Abschlussprozedur geprüft. Der anschließende Signaturabgleich betrifft stattdessen InternalCompleteFileIOCycle, nicht zusätzlich die Wait-Abschlusssignatur. Signatur- und Probeerfolg vertrauen dem installierten kanonischen Paketnamensraum; sie weisen weder Codeintegrität noch ein vollständiges Schemaaudit nach.
Der Helper prüft bei den ausgewählten Methoden Existenz, Sichtbarkeit, ANSI_NULLS und QUOTED_IDENTIFIER sowie die genaue Anzahl der Parameter mit Namen, Systemtypen, Maximallängen und OUTPUT-Flags. Defaults, Reihenfolge und Modultext werden nicht abgeglichen. Für die erforderlichen Metriken müssen Code, Typ und Einheit binär passen und ContractVersion muss 1 sein. Eine fehlende Zielidentität oder ein nicht passendes erwartetes Paar ergibt TARGET_UNAVAILABLE / 53764; bei einer späteren Vertragsabweichung können die tatsächlichen Identitätsausgänge bereits befüllt sein.


### `[monitor].[InternalRunSnapshotWaitStatsCycle]`

Quelle: `Code/10_SnapshotBaseline/085_InternalRunSnapshotWaitStatsCycle.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Orchestriert die vollständige native Waitquelle und deren gebundenen Targetabschluss. |
| Schnittstelle | Schedulerart und Force sowie OUTPUT für Capture-ID, Targetname, Status, Partialität und Fehler. Die Ergebnisse fließen in die beiden internen Run-/Modulziele des öffentlichen Aufrufers. |
| Verwendung | Ausschließlich `USP_RunSnapshotCollectionCycle` mit `CollectorCode=WAIT_STATS` ruft diesen Baustein auf. |
| Last und Sperren | Ein Sessionlock mit Wartezeit null umfasst Aufnahmeprüfung, Purge, Vorbereitung, vollständigen DMV-Read, Abschluss und Ausgabe. MaxRows begrenzt nur Targetwrites. |
| Vertrag | Enabled und Due werden vor Writes geprüft. Ein noch nicht fälliger Purge verhindert den Capture nicht. Enginekontext vor/nach dem Read beweist keine atomare Sicht oder Resetkontinuität; ein Ausgabefehler hebt einen bereits bestätigten Capture nicht auf. |

#### InternalRunSnapshotWaitStatsCycle – Parametervertrag

Alle acht Parameter sind erforderlich; keiner hat einen Default. Die ersten beiden sind Eingaben. Die sechs OUTPUT-Parameter müssen auch beim Verwerfen der Ausgabe gebunden werden. Zum Empfang sind eine Variable passenden Typs und das Schlüsselwort OUTPUT erforderlich. Eingehende OUTPUT-Werte werden ignoriert.

- `@SchedulerType` (varchar(16); Default: Kein Default): MANUAL (manueller Aufruf), EXTERNAL (externer Scheduler) oder SQL_AGENT (SQL Server Agent). Der Wert ist ein Herkunftslabel und startet keinen Scheduler. NULL oder ein anderer Wert führt zu INVALID_PARAMETER und RETURN 51011. Der Vergleich folgt der Datenbankkollation und SQL-Server-Paddingregeln; nachgestellte Leerzeichen können gleichwertig sein. Es gibt weder binären Vergleich noch Trimmen oder Normalisieren.
- `@RunEvenIfNotDue` (bit; Default: Kein Default): 0 prüft Fälligkeit; 1 umgeht nur den Due-Check. NULL ist INVALID_PARAMETER mit RETURN 51011. Leertext ist keine unterstützte Eingabe. Disabled-, Target-, Budget- und Sperrprüfungen bleiben aktiv.
- `@CaptureRunIdOut` (bigint OUTPUT; Default: Kein Default): Eintritt NULL; Eingangswert ignoriert. Kann bei der Vorbereitung gesetzt werden und bei einem späteren Fehler erhalten bleiben. Die ID beweist keine erfolgreiche Sammlung oder Finalisierung. Zum Empfang bigint-kompatible Variable mit OUTPUT.
- `@TargetDatabaseNameOut` (sysname OUTPUT; Default: Kein Default): Eintritt NULL; Eingangswert ignoriert. Gibt den konfigurierten Targetnamen zurück, auch bei deaktiviertem Collector, sobald die Konfiguration gelesen wurde. Zum Empfang sysname-kompatible Variable mit OUTPUT.
- `@StatusCodeOut` (varchar(40) OUTPUT; Default: Kein Default): Eintritt AVAILABLE; Eingangswert ignoriert. Lokale kanonische Ergebnisse: AVAILABLE, INVALID_PARAMETER, TARGET_UNAVAILABLE, DENIED_PERMISSION, DISABLED, SKIPPED_CONCURRENT, SKIPPED_NOT_DUE, STOPPED_SIZE_BUDGET, PARTIAL, UNAVAILABLE_OBJECT und ERROR_HANDLED. AVAILABLE_LIMITED ist nur ein akzeptiertes Purge-Zwischenergebnis und kein finaler Wait-Status. Der erfolgreiche Backendstatus wird weitergereicht; eine lokale vollständige Allowlist für Backendstatus besteht nicht.
- `@IsPartialOut` (bit OUTPUT; Default: Kein Default): Eintritt 0; Eingangswert ignoriert. Frühe Abbrüche und Fehler liefern 1; sonst wird der Backendwert übernommen. Zum Empfang bit-kompatible Variable mit OUTPUT.
- `@ErrorNumberOut` (int OUTPUT; Default: Kein Default): Eintritt NULL; Eingangswert ignoriert. Erkannte Fehlernummer oder NULL, wenn der Pfad keine Nummer setzt. Zum Empfang int-kompatible Variable mit OUTPUT.
- `@ErrorMessageOut` (nvarchar(2048) OUTPUT; Default: Kein Default): Eintritt NULL; Eingangswert ignoriert. Diagnose oder NULL. Zum Empfang Unicode-Variable bis 2048 Zeichen mit OUTPUT.

Ohne Rückgabe kann jeder obligatorische OUTPUT-Parameter als typisierter Wert oder NULL übergeben werden. Eine Empfangsvariable und OUTPUT oder OUT sind nur erforderlich, um den Ausgangswert zurückzulesen. Für numerische und zeitbezogene Typen ist Leertext keine unterstützte Eingabeform; textuelle Eingangswerte der OUTPUT-Parameter einschließlich Leertext werden durch die Initialisierung ersetzt.

#### InternalRunSnapshotWaitStatsCycle – Scheduler, Fälligkeit und Sperre

Zulässige Schedulerlabels sind MANUAL, EXTERNAL und SQL_AGENT. Sie bezeichnen nur die Aufrufherkunft. RunEvenIfNotDue=1 übergeht ausschließlich die Fälligkeitsprüfung und deaktiviert weder den Collector noch Target-, Budget- oder Lock-Gates.

Die gemeinsame Session-Exclusive-Applockressource `SQL_Server_Analyze.SC023.CollectionCycle` wird ohne Wartezeit beansprucht und auch vom Purge verwendet. Jeder negative Rückgabewert ergibt SKIPPED_CONCURRENT; die genaue Ursache wird nicht behauptet. Der Purge wird nach einer schreibfreien Policyprüfung ausgeführt. AVAILABLE, AVAILABLE_LIMITED und SKIPPED_NOT_DUE erlauben anschließend die erneute Targetprüfung und normale Vorbereitung. Ein nicht fälliger Purge blockiert den Capture nicht.

#### InternalRunSnapshotWaitStatsCycle – DMV-Read und Ergebnisgrenzen

Die Quelle wird mit genau einer vollständigen Enumeration von `sys.dm_os_wait_stats` gelesen. MaxRows begrenzt Backendwrites, nicht die Enumeration. EMPTY_UNPROVEN ist ein interner Quellstatus. Auch bei gesundem Backendpfad lautet das Ergebnis PARTIAL mit Vergleichsstatuscode; es wird nicht AVAILABLE. Enginekontext vor und nach dem Read belegt keine atomare DMV-Sicht und keine durchgehende Resetkontinuität.

Der Aufrufer muss kompatible temporäre Tabellen `#RunSnapshotCollectionCycle_Run` und `#RunSnapshotCollectionCycle_Modules` vorab anlegen; dieses Objekt führt kein DDL aus. Ein fehlendes Ziel oder Projektionsfehler wird behandelt. Ein Modulnachweis wird bestmöglich geschrieben. Der Run-Nachweis setzt einen passenden eigenen WAIT_STATS-Lauf voraus. Bereits committete Backenddaten bleiben bei späterem Projektions- oder Applockfreigabefehler bestehen; Run-ID allein belegt keine Finalisierung.

Ein aktives Transaktionsfragment wird im CATCH zurückgerollt. Fehler bei der Applockfreigabe überschreiben den Status mit ERROR_HANDLED. Es gibt keinen Legacy-Fallback und keine erfundene Nullprojektion. Ein ergänzender Modulfehlernachweis ist Best Effort; bei dessen Scheitern bleiben die Fehlerausgaben maßgeblich.

Die genannten geschlossenen Statuswerte beschreiben die lokalen Zweige. Weitergereichte Helper- oder Backendstatus werden nicht lokal vollständig allowlisted; die Dokumentation garantiert deshalb keine beliebige Statusmenge einer installierten Version.

#### InternalRunSnapshotWaitStatsCycle – Statusbedeutung

Die folgenden Werte umfassen die aktuellen lokalen Zweige und kanonischen Helperergebnisse; weitergereichte Statuswerte werden an dieser Aufrufstelle nicht erneut vollständig begrenzt.

- AVAILABLE: Initialzustand oder weitergereichte Bestätigung; kein Beleg einer erfolgreich persistierten Waitaufnahme.
- INVALID_PARAMETER: Ungültige Scheduler-/Force-Eingabe, unzulässiger Transaktionskontext oder entsprechender Helperbefund.
- TARGET_UNAVAILABLE: Zielidentität, Paket oder erforderlicher Helpervertrag nicht bestätigt.
- DENIED_PERMISSION: Abgefangener oder weitergereichter Berechtigungsfehler.
- DISABLED: Snapshotpaket oder Wait-Collector nicht aktiviert.
- SKIPPED_CONCURRENT: Die Session-Applock wurde mit negativem Rückgabewert nicht bestätigt.
- SKIPPED_NOT_DUE: Die Capture-Vorbereitung hat die Aufnahme wegen noch nicht erreichter Fälligkeit übersprungen.
- STOPPED_SIZE_BUDGET: Die Vorbereitung bestätigt die zulässige Größenbudgetgrenze nicht.
- PARTIAL: Der kanonische Waitabschluss hat die Aufnahme gespeichert; Vergleichskandidaten beweisen keine ununterbrochene Resetkontinuität.
- UNAVAILABLE_OBJECT: Die native Quelle meldet ein nicht verfügbares Objekt; das Backend übernimmt den Quellfehler.
- ERROR_HANDLED: Sonstiger behandelter Ablauf-, Backend-, Projektions- oder Sperrfreigabefehler.

### `[monitor].[InternalRunSnapshotFileIOCycle]`

Quelle: `Code/10_SnapshotBaseline/087_InternalRunSnapshotFileIOCycle.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Bindet den vollständigen nativen Datei-I/O-Cache an beobachtete Engine-, Datenbank- und Dateimetadaten und den eigenen Targetlauf. |
| Schnittstelle | Schedulerart, Force und die drei CurrentIO-Datenbankfilter; OUTPUT liefert Capture-ID, Targetname, Status, Partialität und Fehler. |
| Verwendung | Der öffentliche Collectioneinstieg wählt diesen internen Baustein ausschließlich mit CollectorCode=FILE_IO. |
| Last und Sperren | Ein Sessionlock ohne Wartezeit umfasst Policyprüfung, Purge, Vorbereitung, Quelle, Abschluss und Projektion. Ein vollständiger VFS-Read erfolgt vor dem Schreiblimit; Katalogreads laufen je ausgewählter Datenbank vorher und nachher. |
| Vertrag | Erfolgreiche Aufnahmen bleiben PARTIAL. Späte Bindungsfehler erhalten den tatsächlichen Readzustand. Unbestätigte Abschlüsse und ihre Vorgängergrenze bleiben sichtbar; fehlgeschlagenes Readback erzeugt keine erfundene Runzeile. Der [öffentliche Datei-I/O-Vertrag](../Architecture/Snapshot_Baseline_Package_Contract.md#öffentliche-datei-io-aufnahme) beschreibt Status und Retention. |

#### monitor.InternalRunSnapshotFileIOCycle – Parameterverträge

Die acht ersten Argumente sind erforderlich. OUTPUT-Eingabewerte werden ignoriert. Zum Empfang sind Variable und OUTPUT-Kennzeichnung erforderlich; zum Verwerfen der Ausgabe kann ein typisierter NULL-Wert oder kompatibler skalarer Wert ohne OUTPUT gebunden werden; die normale SQL-Typkonvertierung gilt weiterhin. Anfangswerte: Status AVAILABLE, Partialität 0, Capture-ID, Targetname, Fehlernummer und Fehlermeldung NULL. NULL-Fehlermeldung bedeutet keinen Text; Leertext ist davon verschieden. Die drei abschließenden Filter sind optional. Für NULL, Leerwerte und Auslassung gelten die folgenden Einzelverträge.

- @SchedulerType (varchar(16); Default: kein Default): MANUAL (manuell), EXTERNAL (externer Aufruf) oder SQL_AGENT (SQL-Agent-Aufruf). Der Vergleich verwendet die aktuelle Datenbankcollation und Paddingregeln; kein TRIM/UPPER. NULL, Leertext und andere Werte sind ungültig.
- @RunEvenIfNotDue (bit; Default: kein Default): 0 beachtet den Intervallskip, 1 umgeht ihn. NULL ist ungültig; numerische Werte ungleich 0 werden zu 1 konvertiert. Leertext ist keine unterstützte Eingabe. Der Größenstopp bleibt aktiv.
- @CaptureRunIdOut (bigint OUTPUT; Default: kein Default): erforderlich; Eingabe ignoriert, anfangs NULL. Gibt die vorbereitete Capture-ID aus, die nach einem späteren Fehler erhalten bleiben kann und keinen Sammlungs- oder Finalisierungserfolg beweist.
- @TargetDatabaseNameOut (sysname OUTPUT; Default: kein Default): erforderlich; Eingabe ignoriert, anfangs NULL. Gibt den konfigurierten Targetnamen zurück; er kann schon bei DISABLED gesetzt sein.
- @StatusCodeOut (varchar(40) OUTPUT; Default: kein Default): erforderlich; Eingabe ignoriert, anfangs AVAILABLE. Gibt den Ergebnisstatus zurück.
- @IsPartialOut (bit OUTPUT; Default: kein Default): erforderlich; Eingabe ignoriert, anfangs 0. 1 kennzeichnet Einschränkung oder unbestätigtes Ergebnis; 0 allein bestätigt keinen Read.
- @ErrorNumberOut (int OUTPUT; Default: kein Default): erforderlich; Eingabe ignoriert, anfangs NULL. Enthält eine gemeldete Fehlernummer oder NULL, wenn der betreffende Statuspfad keine Nummer setzt.
- @ErrorMessageOut (nvarchar(2048) OUTPUT; Default: kein Default): erforderlich; Eingabe ignoriert, anfangs NULL. Enthält verfügbaren Fehler- oder Einschränkungstext bis 2048 Zeichen.
- @DatabaseNames (nvarchar(max); Default: NULL): optional; ausgelassen entspricht NULL. Pipe-getrennte, bracket-aware Liste einteiliger Namen; | trennt außerhalb von Klammern, ]] maskiert ] innen. Äußere Elementleerzeichen werden entfernt. Namen werden case-sensitive verglichen; die PARSENAME-Prüfung ist keine vollständige SQL-Bezeichnergrammatik. Snapshots werden nicht ausgewählt. Rohsegment maximal 4000 UTF-16-Codeeinheiten, Name maximal 128 Zeichen. Leere oder fehlerhaft geklammerte Elemente sowie case-sensitive Duplikate sind ungültig. NULL, leer oder nur Leerzeichen bedeutet keine Liste. Fehlende Namen erzeugen Warnungen und nicht automatisch den Gesamtabbruch.
- @SystemdatenbankenEinbeziehen (bit; Default: 0): optional. 0 schließt IDs <=4 aus; 1 lässt Systemdatenbanken zu, garantiert ihre Auswahl nicht. NULL ist ungültig; Leertext ist keine unterstützte Bit-Eingabe; numerische Werte ungleich 0 werden zu 1.
- @DatabaseNamePattern (nvarchar(4000); Default: NULL): optional; NULL/ausgelassen bedeutet kein Pattern. Äußere Leerzeichen werden entfernt. Zulässig sind normale LIKE-Muster und case-insensitive Präfixe like:, regex:, regexi:. LIKE verwendet SQL_Latin1_General_CP1_CS_AS samt Padding, nicht binäre Gleichheit; %, _, und [...] sind LIKE-Metazeichen. regex: verwendet Option c, regexi: Option i. Nur äußere U+0020-Leerzeichen werden entfernt; der Präfixrest wird nicht erneut getrimmt. Leerwert und leeres Präfixergebnis sind ungültig. Ein nicht-NULL Pattern ist mit wirksamer Namensliste unzulässig. Regex erfordert SQL Server 2025 und Installations-Compatibility-Level >=170; Regexsyntax kann SQL-Fehler werfen. Keine automatische Installation oder Aktivierung.

#### monitor.InternalRunSnapshotFileIOCycle – Ablauf und Status

Die Reihenfolge ist initiale Targetprüfung, PolicyOnly, Kandidatenauswahl, Purge, Revalidierung, Vorbereitung und erneute Revalidierung. Der gemeinsame Session-Applock wird ohne Wartezeit angefordert und mit Purge geteilt; jeder negative sp_getapplock-Rückgabewert führt zu SKIPPED_CONCURRENT. STANDARD_CURRENT wird mit HighImpactConfirmed=0 ausgeführt; das aktuelle Katalogelement hat RequiresGroupGate=0, während die Klassen-/Pfadprüfung des Helpers aktiv bleibt.

Bei nicht leerer Auswahl erfolgt genau ein vollständiger sys.dm_io_virtual_file_stats(NULL,NULL)-Read. Filter und MaxRows wirken erst danach. Ein leerer Scope wird als leer oder nicht gestartet ausgewiesen, nicht als bestätigte Nullmessung. Vorher-/Nachher-Metadaten werden je ausgewählter Datenbank gelesen. Unterstützt werden ROWS (Dateityp 0) und LOG (Typ 1); andere Typen und Offline-Dateien sind ausgeschlossen. Die Identitätsbeobachtung beweist keine atomare Sicht oder ununterbrochene Resetkontinuität. Ein gesunder Backendabschluss bleibt PARTIAL.

AVAILABLE_LIMITED und SKIPPED_NOT_DUE sind zulässige Purgeergebnisse; SKIPPED_NOT_DUE schließt einen späteren Capture nicht aus. FINALIZATION_UNCONFIRMED bleibt auch bei äußerem CATCH oder Fehler der Lockfreigabe erhalten. Ein möglicher gespeicherter Lauf bleibt bestehen; fehlendes Readback erzeugt keine erfundene Runzeile. Die Caller-Result-Tabellen #RunSnapshotCollectionCycle_Run und #RunSnapshotCollectionCycle_Modules sind vorausgesetzt und werden nicht erstellt. Vier eigene #Temp-Tabellen werden vor TRY erstellt; deren native Erstellungsfehler können entkommen.

#### monitor.InternalRunSnapshotFileIOCycle – Statuswerte

Die aktuellen kanonischen Statuswerte sind AVAILABLE (initial/verfügbarer Schritt, kein Read- oder Purgeerfolgsbeweis), INVALID_PARAMETER (ungültige Eingabe oder Transaktionskontext; früher Guard RETURN 51011), TARGET_UNAVAILABLE (Target/Vertrag nicht bestätigt), DENIED_PERMISSION (abgefangener Berechtigungsfehler), DISABLED (Paket/Sammler deaktiviert), SKIPPED_CONCURRENT (beliebiger negativer sp_getapplock-Rückgabewert; kein Warten), SKIPPED_NOT_DUE (Intervall seit dem letzten beendeten FILE_IO-Lauf noch nicht abgelaufen und RunEvenIfNotDue=0), STOPPED_SIZE_BUDGET (Policy stoppt wegen Datendateigröße), PARTIAL (gespeicherte Backendaufnahme unter Evidenzgrenzen), UNAVAILABLE_OBJECT (benötigtes Objekt fehlt), ERROR_HANDLED (anderer behandelter Fehler; manche native Fehler entkommen), INTERNAL_ERROR (Kandidaten-Temp-Tabellenschema ungültig), UNAVAILABLE_FEATURE (Regexvoraussetzungen fehlen) und FINALIZATION_UNCONFIRMED (Backendabschluss oder Fehlerfinalisierung unbestätigt; Speicherung bleibt möglich; ein bloßer nachgelagerter Projektionsfehler setzt diesen Status nicht).

Der finale Sammlerstatus SKIPPED_NOT_DUE bezieht sich auf das noch nicht abgelaufene Intervall seit dem letzten beendeten FILE_IO-Lauf, nicht auf einen erfolgreichen Purge oder ein aktuell gemessenes Größenbudget. RunEvenIfNotDue=1 umgeht nur diesen Intervallskip, nicht DISABLED, Targetidentität, Lockkonflikt oder Größenbudget. AVAILABLE_LIMITED ist ausschließlich ein akzeptierter Purge-Zwischenstatus, wenn das Batchlimit nach einem löschenden Batch erreicht wurde; er ist kein normaler finaler Sammlerstatus. Ein Purge-SKIPPED_NOT_DUE verhindert einen späteren Capture nicht.

DENIED_GROUP und HIGH_IMPACT_CONFIRMATION_REQUIRED sind allgemeine Kandidatenhelper-Ausgaben für andere Klassen oder Freigabekonfigurationen, keine erwarteten aktuellen Ergebnisse des fest verdrahteten STANDARD_CURRENT-Aufrufs mit HighImpactConfirmed=0. Der [öffentliche Datei-I/O-Vertrag](../Architecture/Snapshot_Baseline_Package_Contract.md#öffentliche-datei-io-aufnahme) beschreibt Retention.

### `[monitor].[InternalSsisExecutionMetrics]`

Quelle: `Code/10_SSIS/045_InternalSsisExecutionMetrics.sql`

| Dimension | Beschreibung |
|---|---|
| Aufgabe | Validiert einen Capture und projiziert die Kennzahlen, Positionsschlüssel und bekannten beobachteten Pfadzeilensets für Paarvergleich und Mehrlauf-Baseline. |
| Schnittstelle | Laufordinal, Modell, Capture, lokale Übergabe, Ausführungs-ID, gemeinsame Deadline und Locktimeout; OUTPUT liefert Einzelanalyse, Bindungsstatus und attestierte Bitness. Ein interner JSON-OUTPUT-Vertrag liefert die nativen Kennzahlen mit hexkodierten Hashes; jeder Consumer besitzt sein eigenes temporäres Empfangsziel. |
| Verwendung | Die beiden öffentlichen Vergleichsprocedures rufen diesen Consumer je Eingabecapture genau einmal auf. |
| Last und Sperren | Höchstens 16 MiB je Modell/Capture, die bestehenden 50000 Quellbelege und 200000 Kennzahlen je Capture; eigene Temp-Objekte ohne zusätzlichen SSISDB-Zugriff. |
| Vertrag | Die bestehende Einzelanalyse prüft Herkunft, Version und Aufrufscope. Schlüssel enthalten Modellobjekt und beobachtete Aufrufposition; native Statistik-IDs bleiben Quellenbelege. Parser, Profile und Lineage werden ausschließlich in Toolbelt gepflegt. |
