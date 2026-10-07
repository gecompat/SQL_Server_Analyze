#!/usr/bin/env python3
"""Validate literal CurrentTempDB ABI, fields, parent isolation and late caps."""
from __future__ import annotations
import argparse,re
from pathlib import Path
PROCEDURE_PATH=Path("Code/02_CurrentState/070_USP_CurrentTempDB.sql")
TABLES={'#CurrentTempDB_ResultTableMap': [('ResultName',
                                    'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL PRIMARY KEY'),
                                   ('TargetTable',
                                    'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE')],
 '#CurrentTempDB_SessionFilter': [('SessionId', 'smallint NOT NULL PRIMARY KEY')],
 '#CurrentTempDB_Sessions': [('SessionId', 'smallint NOT NULL'),
                             ('LoginName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('HostName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('ProgramName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('SessionStatus', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('UserObjectsAllocatedMb', 'decimal(19,2) NOT NULL'),
                             ('UserObjectsDeallocatedMb', 'decimal(19,2) NOT NULL'),
                             ('UserObjectsNetMb', 'decimal(19,2) NOT NULL'),
                             ('InternalObjectsAllocatedMb', 'decimal(19,2) NOT NULL'),
                             ('InternalObjectsDeallocatedMb', 'decimal(19,2) NOT NULL'),
                             ('InternalObjectsNetMb', 'decimal(19,2) NOT NULL'),
                             ('TotalNetMb', 'decimal(19,2) NOT NULL')],
 '#CurrentTempDB_Files': [('FileId', 'int NOT NULL'),
                          ('LogicalName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                          ('PhysicalName', 'nvarchar(260) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                          ('FileTypeDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                          ('SizeMb', 'decimal(19,2) NOT NULL'),
                          ('UsedMb', 'decimal(19,2) NULL'),
                          ('FreeMb', 'decimal(19,2) NULL'),
                          ('UsedPercent', 'decimal(9,2) NULL'),
                          ('GrowthMb', 'decimal(19,2) NULL'),
                          ('IsPercentGrowth', 'bit NOT NULL')],
 '#CurrentTempDB_TempdbGovernance': [('GroupId', 'int NULL'),
                                     ('GroupName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('PoolId', 'int NULL'),
                                     ('PoolName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('ConfiguredGroupMaxTempdbDataMb', 'decimal(19,2) NULL'),
                                     ('ConfiguredGroupMaxTempdbDataPercent', 'decimal(9,4) NULL'),
                                     ('TempdbMaximumSizeMb', 'decimal(19,2) NULL'),
                                     ('EffectiveGroupMaxTempdbDataMb', 'decimal(19,2) NULL'),
                                     ('EffectiveLimitSource',
                                      'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('IsPercentLimitEffective', 'bit NULL'),
                                     ('TempdbDataSpaceMb', 'decimal(19,2) NULL'),
                                     ('PeakTempdbDataSpaceMb', 'decimal(19,2) NULL'),
                                     ('EffectiveLimitUtilizationPercent', 'decimal(9,2) NULL'),
                                     ('TotalTempdbDataLimitViolationCount', 'bigint NULL'),
                                     ('HasRecordedLimitViolation', 'bit NULL'),
                                     ('StatisticsStartTime', 'datetime NULL'),
                                     ('IsResourceGovernorEnabled', 'bit NULL'),
                                     ('ReconfigurationPending', 'bit NULL'),
                                     ('SourceStatusCode',
                                      'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('IsPartial', 'bit NOT NULL'),
                                     ('EvidenceLimit',
                                      'nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentTempDB_Warnings': [('StatusCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                             ('ErrorNumber', 'int NULL'),
                             ('ErrorMessage', 'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentTempDB_SourceSessions': [('session_id', 'smallint NOT NULL PRIMARY KEY'),
                                   ('is_user_process', 'bit NOT NULL'),
                                   ('status', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                   ('login_name',
                                    'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                   ('host_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                   ('program_name',
                                    'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentTempDB_SourceSessionUsage': [('session_id', 'smallint NOT NULL PRIMARY KEY'),
                                       ('user_objects_alloc_page_count', 'bigint NOT NULL'),
                                       ('user_objects_dealloc_page_count', 'bigint NOT NULL'),
                                       ('internal_objects_alloc_page_count', 'bigint NOT NULL'),
                                       ('internal_objects_dealloc_page_count', 'bigint NOT NULL')],
 '#CurrentTempDB_SourceGroupCatalog': [('GroupId', 'int NOT NULL PRIMARY KEY'),
                                       ('GroupName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                       ('PoolId', 'int NOT NULL'),
                                       ('ConfiguredGroupMaxTempdbDataMb', 'decimal(19,2) NULL'),
                                       ('ConfiguredGroupMaxTempdbDataPercent', 'decimal(9,4) NULL')],
 '#CurrentTempDB_SourceGroupRuntime': [('GroupId', 'int NOT NULL PRIMARY KEY'),
                                       ('GroupName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                       ('PoolId', 'int NOT NULL'),
                                       ('StatisticsStartTime', 'datetime NULL'),
                                       ('TempdbDataSpaceKb', 'bigint NULL'),
                                       ('PeakTempdbDataSpaceKb', 'bigint NULL'),
                                       ('TotalTempdbDataLimitViolationCount', 'bigint NULL')],
 '#CurrentTempDB_SourcePools': [('PoolId', 'int NOT NULL PRIMARY KEY'),
                                ('PoolName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentTempDB_TempdbConfigFiles': [('FileId', 'int NOT NULL PRIMARY KEY'),
                                      ('SizePages', 'bigint NOT NULL'),
                                      ('MaxSizePages', 'bigint NOT NULL'),
                                      ('GrowthPagesOrPercent', 'bigint NOT NULL')]}
PARAMETERS=[('@SessionIds', 'nvarchar(max) = NULL'), ('@AktuelleSessionEinbeziehen', 'bit = 0'), ('@MinNettoMb', 'decimal(19,2) = 0'), ('@SystemSessionsEinbeziehen', 'bit = 0'), ('@MitDateien', 'bit = 1'), ('@MaxZeilen', 'int = 1000'), ('@ResultSetArt', "varchar(16) = 'CONSOLE'"), ('@ResultTablesJson', 'nvarchar(max) = NULL'), ('@JsonErzeugen', 'bit = 0'), ('@Json', 'nvarchar(max) = NULL OUTPUT'), ('@PrintMeldungen', 'bit = 1'), ('@Hilfe', 'bit = 0'), ('@ParentCurrentStateSnapshotId', 'uniqueidentifier = NULL')]
TOKENS={'Version      : 4.0.0': 1, 'Stand        : 2026-07-23': 1, '3 AS [schemaVersion]': 1, '[ContractVersion]=2': 1, '[OwnerSessionId]=CONVERT(smallint,@@SPID)': 1, '[SnapshotId]=@ParentCurrentStateSnapshotId': 8, 'THROW 51011,@ErrorMessage,1;': 1, 'SELECT TOP (@Candidates)': 1, 'SELECT TOP (@Limit)': 3, 'SELECT @RowCount=COUNT_BIG(*)': 1, 'SET @HasMoreRows=CONVERT': 1, "@AllowedResultNames=N'sessions|tempdbGovernance'": 1, 'HAVING COUNT(*)>1': 1, '[NumberValue] NOT BETWEEN 0 AND 32767': 1, "@SourceTable=N'#CurrentTempDB_Sessions'": 2, "@SourceTable=N'#CurrentTempDB_Files'": 1, "@SourceTable=N'#CurrentTempDB_TempdbGovernance'": 2, 'ORDER BY [TotalNetMb] DESC,[SessionId]': 3, 'ORDER BY [GroupId]': 3, '@MinNettoMb<0': 1, '@MaxZeilen<0': 1, '@MitDateien IS NULL': 1, '[p].[SnapshotId]=[g].[SnapshotId]': 1}
REFERENCE_CAP='    IF @MaxZeilen IS NOT NULL AND @MaxZeilen>0\n    BEGIN\n        ;WITH [R] AS\n        (\n            SELECT *,ROW_NUMBER() OVER(ORDER BY [TotalNetMb] DESC,[SessionId]) AS [rn]\n            FROM [#CurrentTempDB_Sessions]\n        )\n        DELETE FROM [R] WHERE [rn]>@Limit;\n\n        ;WITH [R] AS\n        (\n            SELECT *,ROW_NUMBER() OVER(ORDER BY [GroupId]) AS [rn]\n            FROM [#CurrentTempDB_TempdbGovernance]\n        )\n        DELETE FROM [R] WHERE [rn]>@Limit;\n    END;\n\n'

def normalize(value:str)->str:return re.sub(r"\s+"," ",value).strip()
def definitions(source:str)->dict:
 result={m[1]:[(n,normalize(d)) for n,d in re.findall(r"^\s*(?:,\s*)?\[([^]]+)\]\s+([^\n]+)",m[2],re.M)] for m in re.finditer(r"CREATE TABLE \[(#CurrentTempDB_[^]]+)\]\s*\((.*?)\);",source,re.S)}
 # This single-field declaration is inline; preserve its complete contract too.
 m=re.search(r"CREATE TABLE \[#CurrentTempDB_SessionFilter\]\(\[([^]]+)\]\s+([^)]*)\);",source)
 if m:result['#CurrentTempDB_SessionFilter']=[(m[1],normalize(m[2]))]
 return result
def findings(source:str)->list[str]:
 errors=[];actual=definitions(source)
 if list(actual)!=list(TABLES):errors.append('TABLE_NAMES_ORDER')
 for table,fields in TABLES.items():
  if actual.get(table)!=fields:errors.append('DDL:'+table)
 sig=source[source.find('CREATE OR ALTER PROCEDURE'):source.find('\nAS\n')]
 if [(n,normalize(d)) for n,d in re.findall(r"^\s*,?\s*(@\w+)\s+([^\n]+)",sig,re.M)]!=PARAMETERS:errors.append('PARAMETERS')
 for token,count in TOKENS.items():
  if source.count(token)!=count:errors.append('BOUNDARY:'+token)
 if source.count(REFERENCE_CAP)!=1:errors.append('EXACT_SHARED_CAPS')
 else:
  count=source.find('SELECT @RowCount=COUNT_BIG(*)');more=source.find('SET @HasMoreRows=CONVERT')
  catch=source.find('END CATCH;',more);cap=source.index(REFERENCE_CAP);consumer=source.find("IF @PrintMeldungen=1 AND @StatusCode<>'AVAILABLE'")
  if min(count,more,catch,consumer)<0 or not count<more<catch<cap<consumer:errors.append('CAP_AFTER_COUNT_AND_CATCH')
  if len(re.findall(r'\bDELETE\b',source[catch:consumer],re.I))!=2:errors.append('ONLY_TWO_RESULT_CAPS')
 prepare=source.find('EXEC [monitor].[InternalPrepareResultTables]');validation=source.find('IF @SessionIds IS NOT NULL');failure=source.find('THROW 51011,@ErrorMessage,1;');lock=source.find('    SET LOCK_TIMEOUT 0;')
 if not 0<validation<prepare<failure<lock:errors.append('UNCHANGED_VALIDATION_PREFLIGHT')
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
 mutations.extend([source.replace(REFERENCE_CAP,'',1),source.replace('WHERE [rn]>@Limit','WHERE [rn]>=@Limit',1),source.replace('IF @MaxZeilen IS NOT NULL AND @MaxZeilen>0','IF @MaxZeilen IS NOT NULL AND @MaxZeilen>=0',1),source.replace('ORDER BY [TotalNetMb] DESC,[SessionId]) AS [rn]','ORDER BY [SessionId],[TotalNetMb] DESC) AS [rn]',1),source.replace('ORDER BY [GroupId]) AS [rn]','ORDER BY [GroupId] DESC) AS [rn]',1),source.replace(REFERENCE_CAP,'',1).replace('        SELECT @RowCount=COUNT_BIG(*)',REFERENCE_CAP+'        SELECT @RowCount=COUNT_BIG(*)',1),source.replace(REFERENCE_CAP,'',1).replace('    END TRY\n    BEGIN CATCH\n        SET @ErrorNumber=ERROR_NUMBER();',REFERENCE_CAP+'    END TRY\n    BEGIN CATCH\n        SET @ErrorNumber=ERROR_NUMBER();',1),source.replace(REFERENCE_CAP,REFERENCE_CAP+'DELETE FROM [#CurrentTempDB_Files];\n',1)])
 for i,mutation in enumerate(mutations):assert mutation!=source and findings(mutation),f'undetected mutation {i}'
 return len(mutations)
def main()->int:
 p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,default=Path('.'));p.add_argument('--self-test',action='store_true');a=p.parse_args()
 source=(a.repository_root/PROCEDURE_PATH).read_text(encoding='utf-8-sig')
 if a.self_test:print(f'CurrentTempDB self-test passed: mutations={self_test(source)}');return 0
 errors=findings(source)
 if errors:print('CurrentTempDB contract failed: '+', '.join(errors));return 1
 print('CurrentTempDB contract passed: tables=12 fields=78 texts=23 parameters=13 sessions=12 governance=21');return 0
if __name__=='__main__':raise SystemExit(main())
