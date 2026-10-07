USE [DeineDatenbank];
GO
-- Die Regression erzeugt das eigene Prüfschema im Laufzeit-Runner.
GO
INSERT monitor.WaitTypeCatalog(WaitType,WaitGroup,Severity,IsGenerallyBenign,Meaning,TypicalOccurrence,HighWaitImpact,RecommendedChecks,IsFrameworkDefault,LastUpdatedUtc)
VALUES(N'SYNTHETIC_CUSTOM_WAIT',N'SYNTHETIC_GROUP',1,0,N'Ä漢字  ',N'fixture  ',N'fixture',N'fixture',0,'20010101'),
(N'CURSOR',N'SYNTHETIC_RETIRED',1,0,N'Ä漢字 retired  ',N'fixture',N'fixture',N'fixture',1,'20010101');
INSERT monitor.WaitTypeCatalogSource(WaitType,SourceOrdinal,SourceType,Publisher,SourceTitle,SourceUrl,SupportsFields,EvidenceLevel,SourceNotes,IsFrameworkDefault,LastVerifiedUtc)
VALUES(N'SYNTHETIC_CUSTOM_WAIT',20,'SYNTHETIC',N'SYNTHETIC',N'Ä漢字  ',N'https://example.invalid/fixture',N'fixture','SYNTHETIC',NULL,0,'20010101'),
(N'CURSOR',1,'SYNTHETIC',N'SYNTHETIC',N'Ä漢字 retired  ',N'https://example.invalid/fixture',N'fixture','SYNTHETIC',N'  ',1,'20010101');
INSERT monitor.FrameworkVersion VALUES(N'SYNTHETIC_OTHER_FRAMEWORK','0.0.1','20010101',15,'1.0','20010101',N'Ä漢字  ');
UPDATE monitor.FrameworkVersion SET LastInstalledUtc='20010101' WHERE FrameworkName=N'SQLServerMonitoringFramework';
INSERT monitor.ToolBackgroundQueryPattern(RuleCode,Priority,IsEnabled,ProgramNameLikePattern,ToolBackgroundCategory,ToolBackgroundDetection,ToolBackgroundConfidence,SourceUrl,SourceNotes,IsFrameworkDefault,LastVerifiedUtc)
VALUES('SYNTHETIC_CUSTOM_TOOL',1,0,N'Ä漢字  ','SYNTHETIC','SYNTHETIC','LOW',NULL,N'  ',0,'20010101');
UPDATE monitor.ToolBackgroundQueryPattern SET IsEnabled=0 WHERE RuleCode='SSMS_OBJECT_EXPLORER';
INSERT monitor.PlanAnalysisProfile VALUES('SYNTHETIC_CUSTOM_PROFILE',N'Ä漢字  ',1,0,0,0,'20010101');
UPDATE monitor.PlanAnalysisProfile SET IsEnabled=0,SeedVersion=0,LastUpdatedUtc='20010101' WHERE ProfileCode='BALANCED';
INSERT monitor.PlanAnalysisRuleThreshold(RuleCode,ProfileCode,Severity,IsEnabled,MinRatio,AdditionalConfigurationJson,IsFrameworkDefault,SeedVersion,LastUpdatedUtc)
VALUES('SYNTHETIC_CUSTOM_RULE','SYNTHETIC_CUSTOM_PROFILE','LOW',0,1.234567,N'{"synthetic":"Ä漢字  "}',0,0,'20010101');
UPDATE monitor.PlanAnalysisRuleThreshold SET IsEnabled=0,SeedVersion=0,LastUpdatedUtc='20010101' WHERE ProfileCode='BALANCED';
SET IDENTITY_INSERT monitor.PlanAnalysisProfileAssignment ON;
INSERT monitor.PlanAnalysisProfileAssignment(AssignmentId,Priority,IsEnabled,ProfileCode,DatabaseNamePattern,QueryHash,IsFrameworkDefault,Comment,LastUpdatedUtc)
VALUES(701,1,0,'SYNTHETIC_CUSTOM_PROFILE',N'SYNTHETIC_DB%',0x0001020304050607,0,N'Ä漢字  ','20010101');
SET IDENTITY_INSERT monitor.PlanAnalysisProfileAssignment OFF;
INSERT monitor.SqlServerBuildCatalog SELECT '99.0.1.1',99,1,1,N'SYNTHETIC_BUILD','RTM',NULL,'20010101','SYNTHETIC',0,0,N'https://example.invalid/build',NULL,'20010101',N'https://example.invalid/source','20010101';
INSERT monitor.SqlServerLifecycleCatalog VALUES(99,N'SYNTHETIC_LIFECYCLE','20010101','20020101','20030101','SYNTHETIC',N'https://example.invalid/lifecycle','20010101','20010101');
UPDATE monitor.SnapshotTargetConfiguration SET TargetDatabaseName=N'SYNTHETIC_HISTORY_OVERRIDE',IsEnabled=0,DefaultSchedulerType='MANUAL',SeedVersion=17,LastUpdatedUtc='20010101';
CREATE TABLE monitor.FrameworkProcedureContract(Id int NOT NULL PRIMARY KEY,Value nvarchar(100) NULL);
CREATE TABLE monitor.FrameworkExpectedObject(Id int NOT NULL PRIMARY KEY,Value varbinary(100) NULL);
CREATE TABLE monitor.FrameworkInstallationHistory(Id bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,Value nvarchar(100) NULL);
INSERT monitor.FrameworkProcedureContract VALUES(1,N'Ä漢字  ');
INSERT monitor.FrameworkExpectedObject VALUES(1,0x000102FF0000);
INSERT monitor.FrameworkInstallationHistory VALUES(NULL);
GO
CREATE OR ALTER VIEW monitor.VW_AnalyseAccessPolicy AS
SELECT CAST('PLAN_CACHE_DEEP' AS varchar(64)) AnalysisClass,CAST(N'SYNTHETIC\GROUP' AS nvarchar(256)) ADGroupName,CAST(1 AS bit) IsEnabled,
CAST(NULL AS datetime2(0)) ValidFromUtc,CAST(NULL AS datetime2(0)) ValidToUtc,CAST(100 AS smallint) Priority,CAST(N'Ä漢字  ' AS nvarchar(1000)) Comment;
GO
