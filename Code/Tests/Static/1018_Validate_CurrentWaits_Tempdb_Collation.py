#!/usr/bin/env python3
"""Validate literal CurrentWaits work-table ABI and existing shared consumer contracts."""
from __future__ import annotations
import argparse,re
from pathlib import Path
PROCEDURE=Path("Code/02_CurrentState/040_USP_CurrentWaits.sql")
TABLES={'#CurrentWaits_SessionIdFilter': [('SessionId', 'smallint NOT NULL PRIMARY KEY')],
 '#CurrentWaits_WaitTypeFilter': [('WaitType',
                                   'nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY '
                                   'KEY')],
 '#CurrentWaits_WaitGroupFilter': [('WaitGroup',
                                    'nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY '
                                    'KEY')],
 '#CurrentWaits_Tasks': [('SessionId', 'smallint NULL'),
                         ('ExecContextId', 'int NULL'),
                         ('WaitDurationMs', 'bigint NULL'),
                         ('WaitType', 'nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('BlockingSessionId', 'smallint NULL'),
                         ('ResourceDescription', 'nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('SessionStatus', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('RequestStatus', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('LoginName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('HostName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('ProgramName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('IsToolBackgroundQuery', 'bit NOT NULL'),
                         ('ToolBackgroundRuleCode', 'varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('ToolBackgroundCategory', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('ToolBackgroundDetection', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('ToolBackgroundConfidence',
                          'varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('DatabaseId', 'smallint NULL'),
                         ('Command', 'nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('CurrentStatementCharacters', 'bigint NULL'),
                         ('CurrentStatementBytes', 'bigint NULL'),
                         ('CurrentStatementIsTruncated', 'bit NOT NULL DEFAULT(0)'),
                         ('CurrentStatement', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('WaitGroup', 'nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('WaitSeverity', 'tinyint NULL'),
                         ('IsGenerallyBenign', 'bit NULL'),
                         ('WaitMeaning', 'nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('WaitTypicalOccurrence',
                          'nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('HighWaitImpact', 'nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('RecommendedChecks', 'nvarchar(1500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('WaitHelpUrl', 'nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('DescriptionSource', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('DescriptionQuality', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                         ('CatalogMatchType', 'varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentWaits_A': [('WaitType', 'nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY'),
                     ('WaitingTasksCount', 'bigint'),
                     ('WaitTimeMs', 'bigint'),
                     ('SignalWaitTimeMs', 'bigint')],
 '#CurrentWaits_B': [('WaitType', 'nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS PRIMARY KEY'),
                     ('WaitingTasksCount', 'bigint'),
                     ('WaitTimeMs', 'bigint'),
                     ('SignalWaitTimeMs', 'bigint')],
 '#CurrentWaits_RawInstance': [('WaitType', 'nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                               ('WaitingTasksCount', 'bigint NULL'),
                               ('WaitTimeMs', 'bigint NULL'),
                               ('SignalWaitTimeMs', 'bigint NULL'),
                               ('ResourceWaitTimeMs', 'bigint NULL'),
                               ('SampleSeconds', 'int NULL'),
                               ('MeasurementType',
                                'varchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentWaits_Instance': [('WaitType', 'nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                            ('WaitingTasksCount', 'bigint NULL'),
                            ('WaitTimeMs', 'bigint NULL'),
                            ('SignalWaitTimeMs', 'bigint NULL'),
                            ('ResourceWaitTimeMs', 'bigint NULL'),
                            ('SampleSeconds', 'int NULL'),
                            ('MeasurementType', 'varchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                            ('WaitGroup', 'nvarchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('WaitSeverity', 'tinyint NULL'),
                            ('IsGenerallyBenign', 'bit NULL'),
                            ('WaitMeaning', 'nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('WaitTypicalOccurrence',
                             'nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('HighWaitImpact', 'nvarchar(1200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('RecommendedChecks', 'nvarchar(1500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('WaitHelpUrl', 'nvarchar(500) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('DescriptionSource', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('DescriptionQuality', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('CatalogMatchType', 'varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('WaitPercentage', 'decimal(9,4) NULL'),
                            ('CumulativePercentage', 'decimal(9,4) NULL'),
                            ('AverageWaitMs', 'decimal(19,4) NULL'),
                            ('AverageResourceWaitMs', 'decimal(19,4) NULL'),
                            ('AverageSignalWaitMs', 'decimal(19,4) NULL')],
 '#CurrentWaits_Warnings': [('WarningCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                            ('WarningMessage',
                             'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentWaits_SourceWaitingTasks': [('waiting_task_address', 'varbinary(8) NOT NULL'),
                                      ('session_id', 'smallint NULL'),
                                      ('exec_context_id', 'int NULL'),
                                      ('wait_duration_ms', 'bigint NOT NULL'),
                                      ('wait_type',
                                       'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                      ('blocking_session_id', 'smallint NULL'),
                                      ('resource_description',
                                       'nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentWaits_SourceSessions': [('session_id', 'smallint NOT NULL PRIMARY KEY'),
                                  ('is_user_process', 'bit NOT NULL'),
                                  ('status', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                  ('login_name',
                                   'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                  ('host_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                  ('program_name',
                                   'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentWaits_SourceRequests': [('session_id', 'smallint NOT NULL'),
                                  ('request_id', 'int NOT NULL'),
                                  ('status', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                  ('database_id', 'smallint NOT NULL'),
                                  ('command', 'nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                  ('sql_handle', 'varbinary(64) NULL'),
                                  ('statement_start_offset', 'int NULL'),
                                  ('statement_end_offset', 'int NULL')],
 '#CurrentWaits_SourceSqlText': [('SqlHandle', 'varbinary(64) NOT NULL PRIMARY KEY'),
                                 ('Text', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')]}
PARAMETERS=[('@SessionIds', 'nvarchar(max)  = NULL'), ('@MinWaitMs', 'bigint         = 0'), ('@WaitTypes', 'nvarchar(max)  = NULL'), ('@WaitTypePattern', 'nvarchar(4000) = NULL'), ('@WaitGroups', 'nvarchar(max)  = NULL'), ('@WaitGroupPattern', 'nvarchar(4000) = NULL'), ('@SystemSessionsEinbeziehen', 'bit            = 0'), ('@ToolHintergrundabfragenEinbeziehen', 'bit       = 0'), ('@MitSqlText', 'bit            = 1'), ('@MaxSqlTextZeichen', 'int            = 2000'), ('@SampleSeconds', 'tinyint        = 0'), ('@UnkritischeWaitsEinbeziehen', 'bit            = 0'), ('@TopWaitPercentage', 'decimal(5,2)   = 95.00'), ('@MaxZeilen', 'int            = 1000'), ('@ResultSetArt', "varchar(16)    = 'CONSOLE'"), ('@ResultTablesJson', 'nvarchar(max) = NULL'), ('@JsonErzeugen', 'bit            = 0'), ('@Json', 'nvarchar(max)  = NULL OUTPUT'), ('@PrintMeldungen', 'bit            = 1'), ('@Hilfe', 'bit            = 0'), ('@ParentCurrentStateSnapshotId', 'uniqueidentifier = NULL')]
TOKEN_COUNTS={'Version      : 4.0.0': 1, 'Stand        : 2026-07-23': 1, '3 AS [schemaVersion]': 1, "N'2.0' AS [ContractVersion]": 1, '@TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable]': 1, "@ResultName=N'currentTasks'": 1, 'ELSE CONVERT(bigint,@MaxZeilen)+1 END': 1, '@MaxZeilen<0': 1, '@MaxSqlTextZeichen<0': 1, '@SampleSeconds>60': 1, '@TopWaitPercentage<=0 OR @TopWaitPercentage>100': 1, '[OwnerSessionId]=CONVERT(smallint,@@SPID)': 1, '[ContractVersion]=2': 1, "[SourceCode] IN ('WAITING_TASKS','SESSIONS','REQUESTS','SQL_TEXT')": 1, '[SnapshotId]=@ParentCurrentStateSnapshotId': 6, '@ToolHintergrundabfragenEinbeziehen=1 OR [tool].[IsToolBackgroundQuery]=0': 1, '[b].[WaitTimeMs]<[a].[WaitTimeMs]': 1, '[b].[WaitingTasksCount]<[a].[WaitingTasksCount]': 1, '[b].[SignalWaitTimeMs]<[a].[SignalWaitTimeMs]': 1, 'WAITFOR DELAY @Delay': 1, '@StartBefore<>@StartAfter': 1, "'MEASUREMENT_RESET'": 1, '[CumulativePercentage]-[WaitPercentage]>=@TopWaitPercentage': 1, '[w].[wait_duration_ms] DESC,[w].[session_id]': 1, '[WaitTimeMs] DESC,[WaitType]': 5, '[rn]>@MaxZeilen': 2, "@SourceTable=N'#CurrentWaits_Tasks'": 2, "@SourceTable = N'#CurrentWaits_Tasks'": 1, 'FOR JSON PATH,INCLUDE_NULL_VALUES': 3, 'REGEXP_LIKE([WaitType],@WaitType,@WaitTypeFlags)': 2, 'REGEXP_LIKE([WaitGroup],@WaitGroup,@WaitGroupFlags)': 2}

def definitions(source):
 result={}
 for m in re.finditer(r"CREATE TABLE \[(#CurrentWaits_[^]]+)\]\s*\((.*?)\);",source,re.S):
  fields=[]
  for p in re.split(r",\s*(?=\[|PRIMARY KEY)",m[2].strip()):
   f=re.fullmatch(r"\s*\[([^]]+)\]\s+(.*?)\s*",p,re.S)
   if f:fields.append((f[1],re.sub(r"\s+"," ",f[2])))
  result[m[1]]=fields
 return result

def validate(source):
 errors=[];actual=definitions(source)
 if list(actual)!=list(TABLES):errors.append("TABLE_ORDER")
 for t,fields in TABLES.items():
  if actual.get(t)!=fields:errors.append("DDL:"+t)
 parameters=re.findall(r"^\s*,?\s*(@\w+)\s+(.*?)\s*$",source[source.find("CREATE OR ALTER PROCEDURE"):source.find("\nAS\n")],re.M)
 if parameters!=PARAMETERS:errors.append("ABI")
 for token,count in TOKEN_COUNTS.items():
  if source.count(token)!=count:errors.append("BOUNDARY:"+token)
 order=[source.find("IF @HasRegex=1\n"),source.find(";WITH [C] AS"),source.find("DELETE FROM [#CurrentWaits_Instance] WHERE [CumulativePercentage]"),source.find(";WITH [T] AS"),source.find(";WITH [I] AS"),source.find("EXEC [monitor].[InternalProjectUnicodeTextColumn]"),source.find("EXEC [monitor].[InternalEmitTruncationWarning]"),source.find("SELECT @TaskRowCount=COUNT_BIG(*)"),source.find("IF @JsonErzeugen=1")]
 if any(x<0 for x in order) or order!=sorted(order):errors.append("SHARED_CAP_ORDER")
 if source.find("InternalPrepareSingleResultTable")>source.find("IF @StatusCode='AVAILABLE'"):errors.append("EARLY_MAPPING")
 if source.find("CREATE TABLE [#CurrentWaits_Tasks]")>source.find("WITH NOWAIT"):errors.append("EARLY_CONSUMER_DDL")
 for name in ("Tasks","Instance"):
  if not re.search(r"SELECT \* FROM \[#CurrentWaits_"+name+r"\] ORDER BY",source):errors.append("JSON_RAW_SOURCE:"+name)
 return errors

def self_test(source):
 assert not validate(source),validate(source)
 mutations=[]
 for t,fields in TABLES.items():
  start=source.index("CREATE TABLE ["+t+"]");end=source.index(");",start);block=source[start:end]
  for name,definition in fields:
   m=re.search(r"\["+re.escape(name)+r"\]\s+"+r"\s+".join(re.escape(x) for x in definition.split()),block);assert m,(t,name)
   old=m[0];variants=[old.replace("["+name+"]","[ExampleWrong]",1),old.replace(definition.split()[0],"sql_variant",1)]
   if "COLLATE" in old:variants.append(old.replace("SQL_Latin1_General_CP1_CS_AS","Latin1_General_100_CI_AS"))
   if "NOT NULL" in old:variants.append(old.replace("NOT NULL","NULL",1))
   elif re.search(r"\bNULL\b",old):variants.append(re.sub(r"\bNULL\b","NOT NULL",old,count=1))
   else:variants.append(old+" NULL")
   for v in variants:mutations.append(source[:start]+block[:m.start()]+v+block[m.end():]+source[end:])
  if len(fields)>1:
   first="["+fields[0][0]+"]";second="["+fields[1][0]+"]"
   mutations.append(source[:start]+block.replace(first,"[ExampleSwap]",1).replace(second,first,1).replace("[ExampleSwap]",second,1)+source[end:])
 for name,definition in PARAMETERS:
  exact=re.search(re.escape(name)+r"\s+"+r"\s+".join(re.escape(x) for x in definition.split()),source);assert exact,name
  old=exact[0]
  for v in (old.replace(name,"@ExampleWrong",1),old.replace(definition.split()[0],"sql_variant",1),old.replace("OUTPUT","",1) if "OUTPUT" in old else old+" OUTPUT",old.split("=")[0]+"= 'ExampleWrongDefault'"):
   mutations.append(source[:exact.start()]+v+source[exact.end():])
 for (first,fd),(second,sd) in zip(PARAMETERS,PARAMETERS[1:]):
  header_end=source.index("\nAS\n");header=source[:header_end]
  mutations.append(header.replace(first,"@ExampleSwap",1).replace(second,first,1).replace("@ExampleSwap",second,1)+source[header_end:])
 for token in TOKEN_COUNTS:mutations.append(source.replace(token,"EXAMPLE_REMOVED",1))
 cap=source[source.index("        IF @MaxZeilen IS NOT NULL AND @MaxZeilen>0"):source.index("        DECLARE @TruncatedValueCount")]
 mutations.append(source.replace(cap,"",1).replace("        IF @HasRegex=1",cap+"        IF @HasRegex=1",1))
 for i,m in enumerate(mutations):assert validate(m),f"undetected mutation {i}"
 return len(mutations)

def main():
 p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,required=True);p.add_argument('--self-test',action='store_true');a=p.parse_args()
 source=(a.repository_root/PROCEDURE).read_text(encoding='utf-8-sig')
 if a.self_test:print(f'Current Waits self-test passed: mutations={self_test(source)} findings=0');return 0
 errors=validate(source)
 if errors:print('Current Waits failed: '+', '.join(errors));return 1
 print('Current Waits passed: tables=13 fields=99 text_collations=50 task_fields=33 instance_fields=23 ABI=21');return 0
if __name__=='__main__':raise SystemExit(main())
