#!/usr/bin/env python3
"""Validate the literal CurrentIO DDL, ABI and existing source boundaries."""
from __future__ import annotations
import argparse,re
from pathlib import Path
PROCEDURE_PATH=Path("Code/02_CurrentState/080_USP_CurrentIO.sql")
TABLES={'#CurrentIO_ResultTableMap': [('ResultName',
                                'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY'),
                               ('TargetTable', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE')],
 '#CurrentIO_DatabaseCandidates': [('DatabaseId', 'int NOT NULL PRIMARY KEY'),
                                   ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                   ('StateDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                   ('UserAccessDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                   ('IsReadOnly', 'bit NULL'),
                                   ('CompatibilityLevel', 'tinyint NULL'),
                                   ('CollationName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                   ('RecoveryModelDesc',
                                    'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                   ('IsSystemDatabase', 'bit NULL'),
                                   ('RequestedOrdinal', 'int NULL')],
 '#CurrentIO_DatabaseCandidateWarnings': [('RequestedName',
                                           'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                          ('StatusCode',
                                           'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                          ('ErrorMessage',
                                           'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentIO_Before': [('DatabaseId', 'int NOT NULL'),
                       ('FileId', 'int NOT NULL'),
                       ('SampleMs', 'bigint NULL'),
                       ('Reads', 'bigint NOT NULL'),
                       ('ReadStallMs', 'bigint NOT NULL'),
                       ('ReadBytes', 'bigint NOT NULL'),
                       ('Writes', 'bigint NOT NULL'),
                       ('WriteStallMs', 'bigint NOT NULL'),
                       ('WriteBytes', 'bigint NOT NULL'),
                       ('SizeOnDiskBytes', 'bigint NOT NULL'),
                       ('FileHandle', 'varbinary(8) NULL')],
 '#CurrentIO_After': [('DatabaseId', 'int NOT NULL'),
                      ('FileId', 'int NOT NULL'),
                      ('SampleMs', 'bigint NULL'),
                      ('Reads', 'bigint NOT NULL'),
                      ('ReadStallMs', 'bigint NOT NULL'),
                      ('ReadBytes', 'bigint NOT NULL'),
                      ('Writes', 'bigint NOT NULL'),
                      ('WriteStallMs', 'bigint NOT NULL'),
                      ('WriteBytes', 'bigint NOT NULL'),
                      ('SizeOnDiskBytes', 'bigint NOT NULL'),
                      ('FileHandle', 'varbinary(8) NULL')],
 '#CurrentIO_Result': [('DatabaseId', 'int NOT NULL'),
                       ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                       ('FileId', 'int NOT NULL'),
                       ('LogicalName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                       ('PhysicalName', 'nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                       ('FileTypeDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                       ('SampleSeconds', 'int NOT NULL'),
                       ('Reads', 'bigint NOT NULL'),
                       ('ReadBytes', 'bigint NOT NULL'),
                       ('ReadStallMs', 'bigint NOT NULL'),
                       ('Writes', 'bigint NOT NULL'),
                       ('WriteBytes', 'bigint NOT NULL'),
                       ('WriteStallMs', 'bigint NOT NULL'),
                       ('ReadLatencyMs', 'decimal(19,3) NULL'),
                       ('WriteLatencyMs', 'decimal(19,3) NULL'),
                       ('OverallLatencyMs', 'decimal(19,3) NULL'),
                       ('ReadThroughputMbPerSecond', 'decimal(19,3) NULL'),
                       ('WriteThroughputMbPerSecond', 'decimal(19,3) NULL'),
                       ('SizeOnDiskMb', 'decimal(19,2) NULL')],
 '#CurrentIO_PendingBefore': [('RequestAddress', 'varbinary(8) NOT NULL PRIMARY KEY'),
                              ('IoType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                              ('PendingDurationMs', 'bigint NOT NULL'),
                              ('IoPending', 'int NOT NULL'),
                              ('SchedulerAddress', 'varbinary(8) NOT NULL'),
                              ('IoHandle', 'varbinary(8) NULL'),
                              ('IoOffset', 'bigint NOT NULL'),
                              ('IoHandlePath', 'nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentIO_PendingAfter': [('RequestAddress', 'varbinary(8) NOT NULL PRIMARY KEY'),
                             ('IoType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                             ('PendingDurationMs', 'bigint NOT NULL'),
                             ('IoPending', 'int NOT NULL'),
                             ('SchedulerAddress', 'varbinary(8) NOT NULL'),
                             ('IoHandle', 'varbinary(8) NULL'),
                             ('IoOffset', 'bigint NOT NULL'),
                             ('IoHandlePath', 'nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentIO_SchedulerContext': [('SchedulerAddress', 'varbinary(8) NOT NULL PRIMARY KEY'),
                                 ('SchedulerId', 'int NOT NULL'),
                                 ('RequestCountOnScheduler', 'int NOT NULL'),
                                 ('IoWaitTaskCountOnScheduler', 'int NOT NULL')],
 '#CurrentIO_SourceRequests': [('session_id', 'smallint NOT NULL'),
                               ('request_id', 'int NOT NULL'),
                               ('scheduler_id', 'int NULL')],
 '#CurrentIO_SourceTasks': [('task_address', 'varbinary(8) NOT NULL PRIMARY KEY'),
                            ('scheduler_id', 'int NULL')],
 '#CurrentIO_SourceWaitingTasks': [('waiting_task_address', 'varbinary(8) NOT NULL'),
                                   ('wait_type', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentIO_SourceSchedulers': [('scheduler_address', 'varbinary(8) NOT NULL PRIMARY KEY'),
                                 ('scheduler_id', 'int NOT NULL')],
 '#CurrentIO_PendingResult': [('CapturedAtUtc', 'datetime2(3) NOT NULL'),
                              ('RequestAddress', 'varbinary(8) NOT NULL'),
                              ('DatabaseId', 'int NULL'),
                              ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                              ('FileId', 'int NULL'),
                              ('LogicalName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                              ('FileTypeDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                              ('PhysicalPath', 'nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                              ('IoType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                              ('PendingLayer', 'varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                              ('PendingDurationMs', 'bigint NOT NULL'),
                              ('SchedulerId', 'int NULL'),
                              ('RequestCountOnScheduler', 'int NULL'),
                              ('IoWaitTaskCountOnScheduler', 'int NULL'),
                              ('WasPresentInFirstSample', 'bit NOT NULL'),
                              ('ObservationCount', 'tinyint NOT NULL'),
                              ('FirstSamplePendingMs', 'bigint NULL'),
                              ('IoOffset', 'bigint NOT NULL'),
                              ('FindingCode', 'varchar(80) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                              ('CorrelationScope',
                               'nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentIO_SourceStatus': [('SourceOrdinal', 'int NOT NULL PRIMARY KEY'),
                             ('SourceName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                             ('SourceObject', 'nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                             ('CapturedAtUtc', 'datetime2(3) NOT NULL'),
                             ('StatusCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                             ('IsPartial', 'bit NOT NULL'),
                             ('ReturnedRowCount', 'bigint NOT NULL'),
                             ('ErrorNumber', 'int NULL'),
                             ('ErrorMessage', 'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('EvidenceLimit', 'nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentIO_ModuleStatus': [('ModuleName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                             ('CollectionTimeUtc', 'datetime2(3) NOT NULL'),
                             ('StatusCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                             ('IsPartial', 'bit NOT NULL'),
                             ('ReturnedRowCount', 'bigint NOT NULL'),
                             ('HasMoreRows', 'bit NOT NULL'),
                             ('CrossDatabaseRequested', 'bit NOT NULL'),
                             ('SampleSeconds', 'tinyint NOT NULL'),
                             ('PendingIoRequested', 'bit NOT NULL'),
                             ('PendingIoRowCount', 'bigint NOT NULL'),
                             ('PendingIoHasMoreRows', 'bit NOT NULL'),
                             ('ErrorNumber', 'int NULL'),
                             ('ErrorMessage', 'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')]}
PARAMETERS=[('@DatabaseNames', 'nvarchar(max) = NULL'), ('@SystemdatenbankenEinbeziehen', 'bit = 0'), ('@DatabaseNamePattern', 'nvarchar(4000) = NULL'), ('@HighImpactConfirmed', 'bit = 0'), ('@MinLatencyMs', 'decimal(19,3) = 0'), ('@SampleSeconds', 'tinyint = 0'), ('@PendingIoEinbeziehen', 'bit = 1'), ('@NurWiederholtPending', 'bit = 0'), ('@MinPendingIoMs', 'bigint = 0'), ('@PhysischePfadeEinbeziehen', 'bit = 0'), ('@MaxZeilen', 'int = 1000'), ('@ResultSetArt', "varchar(16) = 'CONSOLE'"), ('@ResultTablesJson', 'nvarchar(max) = NULL'), ('@JsonErzeugen', 'bit = 0'), ('@Json', 'nvarchar(max) = NULL OUTPUT'), ('@PrintMeldungen', 'bit = 1'), ('@Hilfe', 'bit = 0'), ('@ParentCurrentStateSnapshotId', 'uniqueidentifier = NULL')]
TOKENS={'Version      : 4.0.0': 1, 'Stand        : 2026-07-23': 1, '3 AS [schemaVersion]': 1, '[ContractVersion]=2': 2, '[OwnerSessionId]=CONVERT(smallint,@@SPID)': 2, "@AllowedResultNames = N'moduleStatus|sourceStatus|files|pendingIo|warnings'": 1, 'THEN CONVERT(bigint,9223372036854775807)': 2, 'SET LOCK_TIMEOUT 0;': 1, 'WAITFOR DELAY @Delay;': 1, 'SELECT TOP (@CandidateLimit)': 1, 'SELECT TOP(@CandidateLimit)': 1, 'SELECT @RowCount=COUNT_BIG(*) FROM [#CurrentIO_Result];': 1, 'SELECT @PendingRowCount=COUNT_BIG(*) FROM [#CurrentIO_PendingResult];': 1, '[SnapshotId]=@ParentCurrentStateSnapshotId': 8, 'FROM [sys].[dm_io_virtual_file_stats](NULL,NULL)': 2, 'FROM [sys].[dm_io_pending_io_requests]': 2, 'ON [v].[FileHandle]=[p].[IoHandle]': 1, 'ON [b].[RequestAddress]=[p].[RequestAddress]': 1, '@ParentCurrentStateSnapshotId IS NOT NULL': 2, "@SourceTable=N'#CurrentIO_Result'": 1, "@SourceTable=N'#CurrentIO_PendingResult'": 1, 'FOR JSON PATH,INCLUDE_NULL_VALUES': 4, '@NurWiederholtPending = 1 AND @SampleSeconds = 0': 1}

def normalize(value:str)->str:return re.sub(r"\s+"," ",value).strip()
def definitions(source:str)->dict:
 return {m[1]:[(n,normalize(d)) for n,d in re.findall(r"^\s*(?:,\s*)?\[([^]]+)\]\s+([^\n]+)",m[2],re.M)] for m in re.finditer(r"CREATE TABLE \[(#CurrentIO_[^]]+)\]\s*\((.*?)\);",source,re.S)}
def findings(source:str)->list[str]:
 errors=[];actual=definitions(source)
 if list(actual)!=list(TABLES):errors.append('TABLE_NAMES_ORDER')
 for table,fields in TABLES.items():
  if actual.get(table)!=fields:errors.append('DDL:'+table)
 sig=source[source.find('CREATE OR ALTER PROCEDURE'):source.find('\nAS\n')]
 if [(n,normalize(d)) for n,d in re.findall(r"^\s*,?\s*(@\w+)\s+([^\n]+)",sig,re.M)]!=PARAMETERS:errors.append('PARAMETERS')
 for token,count in TOKENS.items():
  if source.count(token)!=count:errors.append('BOUNDARY:'+token)
 ddl=source.rfind('CREATE TABLE [#CurrentIO_');lock=source.find('    SET LOCK_TIMEOUT 0;')
 if not 0<ddl<lock:errors.append('EARLY_DDL')
 prepare=source.find("    IF @StatusCode = 'AVAILABLE' AND @OutputMode = 'TABLE'")
 semantic=source.find('    IF @MaxZeilen < 0')
 project=source.find('SELECT @PendingRowCount=COUNT_BIG(*)')
 catch=source.find('    END CATCH;',source.find('    BEGIN CATCH',project))
 partial=source.find("    IF @StatusCode <> 'AVAILABLE'")
 cap=source.find('    IF @Limit<9223372036854775807',catch)
 if not lock<prepare<semantic:errors.append('EARLY_VALID_MAPPING')
 expected_cap="""IF @Limit<9223372036854775807 BEGIN ;WITH [R] AS ( SELECT *,ROW_NUMBER() OVER(ORDER BY [OverallLatencyMs] DESC,[DatabaseName],[FileId]) AS [rn] FROM [#CurrentIO_Result] ) DELETE FROM [R] WHERE [rn]>@Limit; ;WITH [R] AS ( SELECT *,ROW_NUMBER() OVER(ORDER BY [PendingDurationMs] DESC,[DatabaseName],[FileId],[IoOffset]) AS [rn] FROM [#CurrentIO_PendingResult] ) DELETE FROM [R] WHERE [rn]>@Limit; END;"""
 if not 0<project<catch<cap<partial or normalize(source[cap:partial])!=expected_cap:errors.append('LATE_SHARED_CAP')
 if source.count('DELETE FROM [R] WHERE [rn]>@Limit;')!=2:errors.append('ONLY_TWO_CAPS')
 module=source[source.find('    INSERT [#CurrentIO_ModuleStatus]'):source.find('    IF @PrintMeldungen = 1')]
 if ', @HasMoreRows,@CrossDatabaseRequested,COALESCE(@SampleSeconds,CONVERT(tinyint,0)),COALESCE(@PendingIoEinbeziehen,CONVERT(bit,0))' not in module:errors.append('NULL_MODULE_ARGUMENTS')
 if ', @SampleSeconds AS [sampleSeconds]' not in source or ', @PendingIoEinbeziehen AS [pendingIoRequested]' not in source:errors.append('ORIGINAL_JSON_ARGUMENTS')
 return errors

def self_test(source:str)->int:
 assert not findings(source),findings(source)
 mutations=[]
 for table,fields in TABLES.items():
  start=source.index('CREATE TABLE ['+table+']');end=source.index(');',start);block=source[start:end]
  for name,definition in fields:
   m=re.search(r'\['+re.escape(name)+r'\]\s+'+r'\s+'.join(re.escape(x) for x in definition.split()),block);assert m,(table,name)
   literal=m[0]
   variants=[literal.replace('['+name+']','[ExampleWrong]',1),re.sub(r'(\]\s+)\w+(?:\([^)]*\))?',r'\1sql_variant',literal,count=1)]
   if 'COLLATE ' in literal:variants.append(literal.replace('SQL_Latin1_General_CP1_CS_AS','Latin1_General_100_CI_AS'))
   variants.append(literal.replace('NOT NULL','NULL',1) if 'NOT NULL' in literal else re.sub(r'\bNULL\b','NOT NULL',literal,count=1))
   for variant in variants:mutations.append(source[:start]+block[:m.start()]+variant+block[m.end():]+source[end:])
 start=source.index('CREATE OR ALTER PROCEDURE');end=source.index('\nAS\n',start);sig=source[start:end]
 lines=list(re.finditer(r'^\s*,?\s*(@\w+)\s+([^\n]+)',sig,re.M))
 for line in lines:
  literal=line[0]
  variants=[literal.replace(line[1],'@ExampleWrong',1),re.sub(r'(@\w+\s+)\w+(?:\([^)]*\))?',r'\1sql_variant',literal,count=1),re.sub(r'(=\s*)[^\n]+',r"\1N'ExampleWrong'",literal,count=1),literal.replace(' OUTPUT','') if ' OUTPUT' in literal else literal+' OUTPUT']
  for variant in variants:mutations.append(source[:start]+sig[:line.start()]+variant+sig[line.end():]+source[end:])
 first,second=lines[:2]
 mutations.append(source[:start]+sig[:first.start()]+second[0]+sig[first.end():second.start()]+first[0]+sig[second.end():]+source[end:])
 for token in TOKENS:mutations.append(source.replace(token,'EXAMPLE_REMOVED',1))
 # Actual control mutations preserve unrelated source text.
 prepare_start=source.index("    IF @StatusCode = 'AVAILABLE' AND @OutputMode = 'TABLE'")
 prepare_end=source.index('    IF @MaxZeilen < 0',prepare_start)
 prepare=source[prepare_start:prepare_end]
 rest=source[:prepare_start]+source[prepare_end:]
 at=rest.index("    IF @StatusCode='AVAILABLE' AND @Parent")
 mutations.append(rest[:at]+prepare+rest[at:])
 cap_start=source.index('    IF @Limit<9223372036854775807',source.index('SELECT @PendingRowCount=COUNT_BIG(*)'))
 cap_end=source.index("    IF @StatusCode <> 'AVAILABLE'",cap_start)
 cap=source[cap_start:cap_end];rest=source[:cap_start]+source[cap_end:]
 at=rest.index('    BEGIN CATCH',rest.index('SELECT @PendingRowCount=COUNT_BIG(*)'))
 mutations.append(rest[:at]+cap+rest[at:])
 for old,new in [('ORDER BY [OverallLatencyMs] DESC,[DatabaseName],[FileId]','ORDER BY [FileId]'),('ORDER BY [PendingDurationMs] DESC,[DatabaseName],[FileId],[IoOffset]','ORDER BY [IoOffset]'),('DELETE FROM [R] WHERE [rn]>@Limit;','DELETE FROM [R] WHERE [rn]>=@Limit;'),('COALESCE(@SampleSeconds,CONVERT(tinyint,0))','@SampleSeconds'),('COALESCE(@PendingIoEinbeziehen,CONVERT(bit,0))','@PendingIoEinbeziehen'),(', @SampleSeconds AS [sampleSeconds]',', CONVERT(tinyint,0) AS [sampleSeconds]'),(', @PendingIoEinbeziehen AS [pendingIoRequested]',', CONVERT(bit,0) AS [pendingIoRequested]')]:
  # Scoped replacement: mutate the late cap instead of an earlier sort where relevant.
  if old.startswith('ORDER BY'):
   mutated=source[:cap_start]+source[cap_start:].replace(old,new,1)
  else:mutated=source.replace(old,new,1)
  mutations.append(mutated)
 for i,mutation in enumerate(mutations):assert mutation!=source and findings(mutation),f'undetected mutation {i}'
 return len(mutations)
def main()->int:
 p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,default=Path('.'));p.add_argument('--self-test',action='store_true');a=p.parse_args()
 source=(a.repository_root/PROCEDURE_PATH).read_text(encoding='utf-8-sig')
 if a.self_test:print(f'CurrentIO literal self-test passed: mutations={self_test(source)}');return 0
 errors=findings(source)
 if errors:print('CurrentIO literal contract failed: '+', '.join(errors));return 1
 print('CurrentIO literal contract passed: tables=16 fields=128 texts=35 parameters=18 exports=65');return 0
if __name__=='__main__':raise SystemExit(main())
