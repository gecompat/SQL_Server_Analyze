#!/usr/bin/env python3
"""Validate the literal CurrentBlocking ABI and late shared chain selection."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
PROCEDURE_PATH=Path("Code/02_CurrentState/030_USP_CurrentBlocking.sql")
TABLES={'#CurrentBlocking_SessionFilter': [('SessionId', 'smallint NOT NULL PRIMARY KEY')],
 '#CurrentBlocking_Edges': [('BlockedSessionId', 'smallint NOT NULL'),
                            ('BlockingSessionId', 'smallint NOT NULL'),
                            ('WaitType', 'nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('WaitTimeMs', 'bigint NULL'),
                            ('WaitResource', 'nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('SourceCode', 'varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentBlocking_BlockingChains': [('LeafSessionId', 'smallint NOT NULL'),
                                     ('BlockedSessionId', 'smallint NOT NULL'),
                                     ('BlockingSessionId', 'smallint NOT NULL'),
                                     ('RootBlockingSessionId', 'smallint NULL'),
                                     ('BlockingOwnerType', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingOwnerDescription',
                                      'nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingChain', 'nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('ChainDepth', 'int NOT NULL'),
                                     ('IsCycle', 'bit NOT NULL'),
                                     ('WaitType', 'nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('WaitTimeMs', 'bigint NULL'),
                                     ('WaitResource', 'nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourceType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourceDatabaseId', 'int NULL'),
                                     ('BlockingResourceDatabaseName',
                                      'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourceSchemaName',
                                      'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourceObjectId', 'int NULL'),
                                     ('BlockingResourceObjectName',
                                      'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourceIndexId', 'int NULL'),
                                     ('BlockingResourceIndexName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourcePartitionId', 'bigint NULL'),
                                     ('BlockingResourcePartitionNumber', 'int NULL'),
                                     ('BlockingResourceFileId', 'int NULL'),
                                     ('BlockingResourcePageId', 'bigint NULL'),
                                     ('BlockingResourceRowId', 'int NULL'),
                                     ('BlockingResourceMetadataSubtype',
                                      'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourceMetadataName',
                                      'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourcePageTypeDesc',
                                      'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourceName',
                                      'nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockingResourceResolutionStatus',
                                      'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockedLoginName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockedHostName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockedProgramName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockedIsToolBackgroundQuery', 'bit NOT NULL'),
                                     ('BlockedToolBackgroundRuleCode',
                                      'varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockedToolBackgroundCategory',
                                      'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockedToolBackgroundDetection',
                                      'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockedToolBackgroundConfidence',
                                      'varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockerLoginName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockerHostName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockerProgramName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootBlockerLoginName',
                                      'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootBlockerHostName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootBlockerProgramName',
                                      'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootBlockerSessionStatus',
                                      'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootBlockerRequestStatus',
                                      'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootBlockerOpenTransactionCount', 'int NULL'),
                                     ('RootBlockerLastRequestStartTime', 'datetime NULL'),
                                     ('RootBlockerLastRequestEndTime', 'datetime NULL'),
                                     ('RootIsToolBackgroundQuery', 'bit NOT NULL'),
                                     ('RootToolBackgroundRuleCode',
                                      'varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootToolBackgroundCategory',
                                      'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootToolBackgroundDetection',
                                      'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootToolBackgroundConfidence',
                                      'varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockedStatementCharacters', 'bigint NULL'),
                                     ('BlockedStatementBytes', 'bigint NULL'),
                                     ('BlockedStatementIsTruncated', 'bit NOT NULL DEFAULT(0)'),
                                     ('BlockedStatement', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('BlockerStatementCharacters', 'bigint NULL'),
                                     ('BlockerStatementBytes', 'bigint NULL'),
                                     ('BlockerStatementIsTruncated', 'bit NOT NULL DEFAULT(0)'),
                                     ('BlockerStatement', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootBlockerStatementSource',
                                      'varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('RootBlockerStatementCharacters', 'bigint NULL'),
                                     ('RootBlockerStatementBytes', 'bigint NULL'),
                                     ('RootBlockerStatementIsTruncated', 'bit NOT NULL DEFAULT(0)'),
                                     ('RootBlockerStatement',
                                      'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentBlocking_RetainedSessions': [('SessionId', 'smallint NOT NULL PRIMARY KEY')],
 '#CurrentBlocking_Locks': [('SessionId', 'smallint NULL'),
                            ('ResourceType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('ResourceDatabaseId', 'int NULL'),
                            ('ResourceDatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('ResourceDescription', 'nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('ResourceSubtype', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('ResourceAssociatedEntityId', 'bigint NULL'),
                            ('ResourceLockPartition', 'int NULL'),
                            ('RequestMode', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('RequestStatus', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('RequestOwnerType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('RequestReferenceCount', 'smallint NULL'),
                            ('LockOwnerAddress', 'varbinary(8) NULL'),
                            ('ResolvedResourceType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('ResolvedSchemaName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('ResolvedObjectId', 'int NULL'),
                            ('ResolvedObjectName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('ResolvedIndexId', 'int NULL'),
                            ('ResolvedIndexName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('ResolvedPartitionId', 'bigint NULL'),
                            ('ResolvedPartitionNumber', 'int NULL'),
                            ('ResolvedResourceName', 'nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                            ('ResourceResolutionStatus', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentBlocking_ResourceResolution': [('CandidateId', 'int IDENTITY(1,1) NOT NULL PRIMARY KEY'),
                                         ('SourceCode', 'varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                         ('WaitResource', 'nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('ResourceType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('FormatCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                         ('DatabaseId', 'int NULL'),
                                         ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('EntityId', 'bigint NULL'),
                                         ('SubEntityId', 'bigint NULL'),
                                         ('FileId', 'int NULL'),
                                         ('FileName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('PageId', 'bigint NULL'),
                                         ('RowId', 'int NULL'),
                                         ('MetadataSubtype', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('MetadataName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('ResourceQualifier',
                                          'nvarchar(512) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('SchemaName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('ObjectId', 'int NULL'),
                                         ('ObjectName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('IndexId', 'int NULL'),
                                         ('IndexName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('PartitionId', 'bigint NULL'),
                                         ('PartitionNumber', 'int NULL'),
                                         ('PageTypeDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('ResourceName', 'nvarchar(1024) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('ResolutionStatus',
                                          'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentBlocking_Warnings': [('ScopeName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                               ('StatusCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                               ('ErrorNumber', 'int NULL'),
                               ('ErrorMessage', 'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentBlocking_SourceSessions': [('session_id', 'smallint NOT NULL PRIMARY KEY'),
                                     ('is_user_process', 'bit NOT NULL'),
                                     ('status', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('login_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('host_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('program_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('open_transaction_count', 'int NOT NULL'),
                                     ('last_request_start_time', 'datetime NOT NULL'),
                                     ('last_request_end_time', 'datetime NULL')],
 '#CurrentBlocking_SourceRequests': [('session_id', 'smallint NOT NULL'),
                                     ('request_id', 'int NOT NULL'),
                                     ('status', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('blocking_session_id', 'smallint NULL'),
                                     ('wait_type', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('wait_time', 'int NOT NULL'),
                                     ('wait_resource', 'nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('sql_handle', 'varbinary(64) NULL'),
                                     ('statement_start_offset', 'int NULL'),
                                     ('statement_end_offset', 'int NULL')],
 '#CurrentBlocking_SourceWaitingTasks': [('session_id', 'smallint NULL'),
                                         ('wait_duration_ms', 'bigint NOT NULL'),
                                         ('wait_type', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                         ('blocking_session_id', 'smallint NULL'),
                                         ('resource_description',
                                          'nvarchar(3072) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentBlocking_SourceConnections': [('session_id', 'int NULL'),
                                        ('connection_id', 'uniqueidentifier NOT NULL PRIMARY KEY'),
                                        ('most_recent_sql_handle', 'varbinary(64) NULL'),
                                        ('connect_time', 'datetime NOT NULL')],
 '#CurrentBlocking_SourceSqlText': [('SqlHandle', 'varbinary(64) NOT NULL PRIMARY KEY'),
                                    ('Text', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')]}
PARAMETERS=[('@SessionIds', 'nvarchar(max) = NULL'),
 ('@MinWaitMs', 'bigint = 0'),
 ('@SystemSessionsEinbeziehen', 'bit = 0'),
 ('@ToolHintergrundabfragenEinbeziehen', 'bit = 0'),
 ('@MitSqlText', 'bit = 1'),
 ('@MaxSqlTextZeichen', 'int = 3000'),
 ('@BlockingObjektTiefe', "varchar(16) = 'STANDARD'"),
 ('@MaxObjektAufloesungen', 'int = 100'),
 ('@MitLockDetails', 'bit = 0'),
 ('@HighImpactConfirmed', 'bit = 0'),
 ('@MaxZeilen', 'int = 1000'),
 ('@ResultSetArt', "varchar(16) = 'CONSOLE'"),
 ('@ResultTablesJson', 'nvarchar(max) = NULL'),
 ('@JsonErzeugen', 'bit = 0'),
 ('@Json', 'nvarchar(max) = NULL OUTPUT'),
 ('@PrintMeldungen', 'bit = 1'),
 ('@Hilfe', 'bit = 0'),
 ('@ParentCurrentStateSnapshotId', 'uniqueidentifier = NULL')]
TOKENS={'Version      : 3.0.0': 1,
 'Stand        : 2026-07-23': 1,
 '3 AS [schemaVersion]': 1,
 '[ContractVersion]=2': 1,
 '[OwnerSessionId]=CONVERT(smallint,@@SPID)': 1,
 '[SnapshotId]=@ParentCurrentStateSnapshotId': 7,
 "'INVALID_PARENT_SNAPSHOT'": 1,
 'OPTION (MAXRECURSION 32)': 2,
 '[c].[ChainDepth] < 32': 1,
 '[chain].[ChainDepth] < 32': 1,
 '[Path] LIKE CONCAT': 2,
 '[blockedTool].[IsToolBackgroundQuery] = 0': 1,
 '[r].[RowNumber] = 1': 1,
 'ORDER BY [e].[WaitTimeMs] DESC, [e].[BlockedSessionId]': 1,
 '@MaxSqlTextZeichen < 0': 1,
 '@MaxZeilen < 0': 1,
 "@AnalysisClass='LOCKS_DEEP'": 1,
 'SELECT TOP (@CandidateRows)': 2,
 'SET LOCK_TIMEOUT 0;': 5,
 "@TextColumn=N'BlockedStatement'": 1,
 "@TextColumn=N'BlockerStatement'": 1,
 "@TextColumn=N'RootBlockerStatement'": 1,
 "@SourceTable=N'#CurrentBlocking_BlockingChains'": 4,
 "@SourceTable = N'#CurrentBlocking_BlockingChains'": 1,
 'SELECT TOP (@EffectiveMaxZeilen) *': 2}

CAP="DELETE FROM [R] WHERE [rn]>@EffectiveMaxZeilen;"
REFERENCE_CAP="""
    IF @MaxZeilen IS NOT NULL AND @MaxZeilen>0
    BEGIN
        ;WITH [R] AS
        (
            SELECT *,ROW_NUMBER() OVER(ORDER BY [WaitTimeMs] DESC,[BlockedSessionId]) AS [rn]
            FROM [#CurrentBlocking_BlockingChains]
        )
        DELETE FROM [R] WHERE [rn]>@EffectiveMaxZeilen;
    END;
"""
def normalize(value:str)->str:
 return re.sub(r"\s+"," ",value).strip()
def definitions(source:str)->dict[str,list[tuple[str,str]]]:
 result={}
 for m in re.finditer(r"CREATE TABLE \[(#CurrentBlocking_[^]]+)\]\s*\((.*?)\);",source,re.S):
  result[m[1]]=[(n,normalize(d)) for n,d in re.findall(r"^\s*(?:,\s*)?\[([^]]+)\]\s+([^\n]+)",m[2],re.M)]
 return result
def findings(source:str)->list[str]:
 errors=[]
 actual=definitions(source)
 if list(actual)!=list(TABLES):errors.append("TABLE_NAMES_ORDER")
 for table,fields in TABLES.items():
  if actual.get(table)!=fields:errors.append("DDL:"+table)
 p=re.findall(r"^\s*,?\s*(@\w+)\s+([^\n]+)",source[source.find("CREATE OR ALTER PROCEDURE"):source.find("\nAS\n")],re.M)
 if [(n,normalize(d)) for n,d in p]!=PARAMETERS:errors.append("PARAMETERS")
 for token,count in TOKENS.items():
  if source.count(token)!=count:errors.append("BOUNDARY:"+token)
 prepare=source.find("EXEC [monitor].[InternalPrepareSingleResultTable]")
 validation=source.find("IF @SessionIds IS NOT NULL")
 if prepare<0 or prepare>validation:errors.append("EARLY_MAPPING")
 chain=source.find(";WITH [Chain] AS")
 filter_pos=source.find("WHERE [r].[Path] LIKE")
 tool=source.find("[blockedTool].[IsToolBackgroundQuery] = 0")
 if min(chain,filter_pos,tool)<0 or not chain<filter_pos<tool:errors.append("CHAIN_BEFORE_FILTERS")
 start=source.find("IF @IsPartial = 1 AND @StatusCode = 'AVAILABLE'")
 if source.count(CAP)!=1:errors.append("LATE_SHARED_CAP")
 else:
  cap=source.index(CAP)
  project=source.rfind("EXEC [monitor].[InternalEmitTruncationWarning]")
  resolution=source.find("UPDATE [c]\n            SET")
  count=source.find("SELECT @MainCandidateCount = COUNT_BIG(*)")
  catch_end=source.find("END CATCH;",project)
  if min(project,resolution,count,start,catch_end)<0 or not count<resolution<project<catch_end<cap<start:errors.append("CAP_AFTER_FULL_WORK")
  capblock=source[source.rfind("IF @MaxZeilen",0,cap):cap+len(CAP)]
  if not re.search(r"@MaxZeilen\s+IS NOT NULL\s+AND\s+@MaxZeilen\s*>\s*0",capblock):errors.append("CAP_UNLIMITED")
  if not re.search(r"ROW_NUMBER\(\)\s+OVER\s*\(\s*ORDER BY\s+\[WaitTimeMs\]\s+DESC\s*,\s*\[BlockedSessionId\]\s*\)",capblock):errors.append("CAP_RANK")
  if "FROM [#CurrentBlocking_BlockingChains]" not in capblock:errors.append("CAP_SOURCE")
  final_work=source[catch_end:start]
  if len(re.findall(r"\bDELETE\b",final_work,re.I))!=1 or len(re.findall(r"\bTOP\s*\(",final_work,re.I))!=0 or "#CurrentBlocking_Locks" in final_work:errors.append("FINAL_CHAIN_CAP_ONLY")
 # RAW and JSON expose every chain field in the same ABI; helper consumers use the same table.
 raw_start=source.find("SELECT TOP (@EffectiveMaxZeilen)")
 raw_end=source.find("FROM [#CurrentBlocking_BlockingChains]",raw_start)
 if re.findall(r"\[([^]]+)\]",source[raw_start:raw_end])!=[n for n,_ in TABLES['#CurrentBlocking_BlockingChains']]:errors.append("RAW_CHAIN_FIELDS")
 return errors

def self_test(source:str)->tuple[int,bool]:
 # An unrepaired original is an expected negative input. The reference cap below
 # is a validator fixture only; it is never written into the production source.
 original_missing=CAP not in source
 reference=source
 if original_missing:
  anchor="    IF @IsPartial = 1 AND @StatusCode = 'AVAILABLE'"
  assert source.count(anchor)==1
  reference=source.replace(anchor,REFERENCE_CAP+"\n"+anchor,1)
 assert not findings(reference),findings(reference)
 mutations=[]
 for table,fields in TABLES.items():
  start=reference.index("CREATE TABLE ["+table+"]");end=reference.index(");",start)
  block=reference[start:end]
  for name,definition in fields:
   m=re.search(r"\["+re.escape(name)+r"\]\s+"+r"\s+".join(re.escape(x) for x in definition.split()),block)
   assert m,(table,name)
   literal=m[0]
   variants=[literal.replace("["+name+"]","[ExampleWrong]",1),re.sub(r"(\]\s+)\w+(?:\([^)]*\))?",r"\1sql_variant",literal,count=1)]
   if 'COLLATE ' in literal:variants.append(literal.replace('SQL_Latin1_General_CP1_CS_AS','Latin1_General_100_CI_AS'))
   variants.append(literal.replace('NOT NULL','NULL',1) if 'NOT NULL' in literal else re.sub(r'\bNULL\b','NOT NULL',literal,count=1))
   for variant in variants:
    assert variant!=literal,(table,name)
    mutations.append(reference[:start]+block[:m.start()]+variant+block[m.end():]+reference[end:])
 # ABI mutations affect the declaration only; body references remain intact.
 signature_start=reference.index("CREATE OR ALTER PROCEDURE")
 signature_end=reference.index("\nAS\n",signature_start)
 signature=reference[signature_start:signature_end]
 parameter_lines=list(re.finditer(r"^\s*,?\s*(@\w+)\s+([^\n]+)",signature,re.M))
 assert len(parameter_lines)==18
 for line in parameter_lines:
  literal=line[0]
  variants=[literal.replace(line[1],"@ExampleWrong",1),re.sub(r"(@\w+\s+)\w+(?:\([^)]*\))?",r"\1sql_variant",literal,count=1),
   re.sub(r"(=\s*)[^\n]+",r"\1N'ExampleWrong'",literal,count=1)]
  variants.append(literal.replace(" OUTPUT","") if " OUTPUT" in literal else literal+" OUTPUT")
  for variant in variants:
   assert variant!=literal
   mutations.append(reference[:signature_start]+signature[:line.start()]+variant+signature[line.end():]+reference[signature_end:])
 first,second=parameter_lines[:2]
 swapped=signature[:first.start()]+second[0]+signature[first.end():second.start()]+first[0]+signature[second.end():]
 mutations.append(reference[:signature_start]+swapped+reference[signature_end:])
 for token in TOKENS:mutations.append(reference.replace(token,'EXAMPLE_REMOVED',1))
 mutations.extend([reference.replace(CAP,'',1),reference.replace(CAP,CAP.replace('>','>='),1),
  reference.replace('ORDER BY [WaitTimeMs] DESC,[BlockedSessionId]','ORDER BY [BlockedSessionId],[WaitTimeMs] DESC',1),
  reference.replace('@MaxZeilen>0','@MaxZeilen>=0',1),
  reference.replace(REFERENCE_CAP,'',1).replace('SELECT @MainCandidateCount = COUNT_BIG(*)',REFERENCE_CAP+'\n        SELECT @MainCandidateCount = COUNT_BIG(*)',1),
  reference.replace(REFERENCE_CAP,'',1).replace('    END TRY\n    BEGIN CATCH\n        SET @ErrorNumber = ERROR_NUMBER();',REFERENCE_CAP+'\n    END TRY\n    BEGIN CATCH\n        SET @ErrorNumber = ERROR_NUMBER();',1),
  reference.replace(CAP,CAP+"\nDELETE FROM [#CurrentBlocking_Locks];",1)])
 for i,mutation in enumerate(mutations):assert mutation!=reference and findings(mutation),f'undetected mutation {i}'
 if original_missing:assert 'LATE_SHARED_CAP' in findings(source)
 return len(mutations),original_missing

def main()->int:
 p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,default=Path('.'));p.add_argument('--self-test',action='store_true');a=p.parse_args()
 source=(a.repository_root/PROCEDURE_PATH).read_text(encoding='utf-8-sig')
 if a.self_test:
  count,original=self_test(source)
  print(f'CurrentBlocking self-test passed: mutations={count} reference_cap_fixture={original} original_missing_cap={original}')
  return 0
 errors=findings(source)
 if errors:print('CurrentBlocking contract failed: '+', '.join(errors));return 1
 print('CurrentBlocking contract passed: tables=12 fields=158 texts=82 public_fields=67 public_texts=38 parameters=18')
 return 0
if __name__=='__main__':raise SystemExit(main())
