USE [DeineDatenbank];
GO
SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET CONCAT_NULL_YIELDS_NULL ON; SET ARITHABORT ON; SET NUMERIC_ROUNDABORT OFF;
UPDATE snapshot.PackageVersion SET InstalledAtUtc='20010101',LastInstallerRunUtc='20010101';
INSERT snapshot.RetentionPolicy VALUES('SYNTHETIC_RETENTION',10,10,10,100,10,100,'PURGE_EXPIRED_THEN_STOP',0,1,'20010101');
UPDATE snapshot.CollectorPolicy SET IsEnabled=0,CollectionIntervalSeconds=77,MaxRows=17,PayloadEnabled=1,SeedVersion=11,LastUpdatedUtc='20010101';
SET IDENTITY_INSERT snapshot.CaptureRun ON;
INSERT snapshot.CaptureRun(CaptureRunId,CollectorCode,SchedulerType,StartedAtUtc,SourceDatabaseName,ResetEpochId,ContractVersion,StatusCode,IsPartial,ErrorNumber,ErrorMessage,MetricSampleCount,PayloadCount)
VALUES(801,'PERFORMANCE_COUNTERS','MANUAL','20010101',N'SYNTHETIC_SOURCE','00000000-0000-0000-0000-000000000001',1,'SYNTHETIC',1,NULL,N'Ä漢字  ',1,1);
SET IDENTITY_INSERT snapshot.CaptureRun OFF;
SET IDENTITY_INSERT snapshot.ModuleStatus ON;
INSERT snapshot.ModuleStatus(ModuleStatusId,CaptureRunId,ModuleName,CollectionTimeUtc,StatusCode,IsPartial,ErrorNumber,ErrorMessage,EvidenceLimit)
VALUES(802,801,N'SYNTHETIC_MODULE','20010101','SYNTHETIC',1,NULL,N'Ä漢字  ',NULL);
SET IDENTITY_INSERT snapshot.ModuleStatus OFF;
SET IDENTITY_INSERT snapshot.Scope ON;
INSERT snapshot.Scope(ScopeId,ScopeType,ParentScopeId,ScopeKeyHash,ScopeIdentityJson,CreatedAtUtc)
VALUES(803,'SERVER',NULL,HASHBYTES('SHA2_256','SYNTHETIC_SCOPE'),N'{"synthetic":"Ä漢字  "}','20010101');
SET IDENTITY_INSERT snapshot.Scope OFF;
SET IDENTITY_INSERT snapshot.MetricDefinition ON;
INSERT snapshot.MetricDefinition(MetricDefinitionId,MetricCode,ValueType,Unit,ContractVersion,Description,IsFrameworkDefault,SeedVersion,LastUpdatedUtc) VALUES(804,'SYNTHETIC_METRIC','STRING','SYNTHETIC',1,N'Ä漢字  ',0,1,'20010101');
SET IDENTITY_INSERT snapshot.MetricDefinition OFF;
SET IDENTITY_INSERT snapshot.MetricSample ON;
INSERT snapshot.MetricSample(MetricSampleId,CaptureRunId,ScopeId,MetricDefinitionId,CollectedAtUtc,ResetEpochId,NumericValue,BigintValue,StringValue,QualityCode,IsPartial)
VALUES(805,801,803,804,'20010101','00000000-0000-0000-0000-000000000001',NULL,NULL,N'Ä漢字  ','SYNTHETIC',1);
SET IDENTITY_INSERT snapshot.MetricSample OFF;
SET IDENTITY_INSERT snapshot.PayloadSnapshot ON;
INSERT snapshot.PayloadSnapshot(PayloadSnapshotId,CaptureRunId,ModuleName,CapturedAtUtc,PayloadFormat,PayloadContractVersion,CompressionType,PayloadHash,Payload,UncompressedCharacterCount) VALUES(806,801,N'SYNTHETIC_MODULE','20010101','TEXT',1,'NONE',HASHBYTES('SHA2_256','SYNTHETIC_PAYLOAD'),0x000102FF0000,1);
SET IDENTITY_INSERT snapshot.PayloadSnapshot OFF;
SET IDENTITY_INSERT snapshot.PurgeRun ON;
INSERT snapshot.PurgeRun(PurgeRunId,StartedAtUtc,EndedAtUtc,StatusCode,BatchesExecuted,MetricRowsDeleted,PayloadRowsDeleted,ModuleRowsDeleted,CaptureRunsDeleted,ScopeRowsDeleted,UsedDataMbBefore,UsedDataMbAfter,SoftBudgetMb,ErrorNumber,ErrorMessage)
VALUES(807,'20010101',NULL,'SYNTHETIC',0,0,0,0,0,0,1.123,NULL,100,NULL,N'Ä漢字  ');
SET IDENTITY_INSERT snapshot.PurgeRun OFF;
GO
