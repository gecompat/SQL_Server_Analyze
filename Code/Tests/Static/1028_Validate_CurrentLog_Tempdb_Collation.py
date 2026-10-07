#!/usr/bin/env python3
"""Validate literal CurrentLog fields/ABI and bounded shared cap."""
from __future__ import annotations
import argparse,re
from pathlib import Path
PROCEDURE_PATH=Path("Code/02_CurrentState/090_USP_CurrentLog.sql")
TABLES={'#CurrentLog_DatabaseCandidates': [('DatabaseId', 'int NOT NULL'),
                                    ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                    ('StateDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                    ('UserAccessDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                    ('IsReadOnly', 'bit NULL'),
                                    ('CompatibilityLevel', 'tinyint NULL'),
                                    ('CollationName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                    ('RecoveryModelDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                    ('IsSystemDatabase', 'bit NULL'),
                                    ('RequestedOrdinal', 'int NULL')],
 '#CurrentLog_DatabaseCandidateWarnings': [('RequestedName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                           ('StatusCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                           ('ErrorMessage',
                                            'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentLog_Result': [('DatabaseId', 'int NOT NULL'),
                        ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                        ('RecoveryModel', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                        ('LogReuseWaitDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                        ('TotalLogSizeMb', 'decimal(19,2) NULL'),
                        ('UsedLogSizeMb', 'decimal(19,2) NULL'),
                        ('UsedLogPercent', 'decimal(19,4) NULL'),
                        ('LogSinceLastBackupMb', 'decimal(19,2) NULL'),
                        ('ActiveVlfCount', 'bigint NULL'),
                        ('TotalVlfCount', 'bigint NULL'),
                        ('LogTruncationHoldupReason', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                        ('LogBackupTime', 'datetime NULL'),
                        ('LogRecoverySizeMb', 'decimal(19,2) NULL'),
                        ('IsAdrEnabled', 'bit NULL'),
                        ('PersistentVersionStoreMb', 'decimal(19,2) NULL'),
                        ('SpaceStatus', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                        ('StatsStatus', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                        ('VlfStatus', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                        ('PvsStatus', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentLog_Errors': [('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                        ('SubModule', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                        ('StatusCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                        ('ErrorNumber', 'int NULL'),
                        ('ErrorMessage', 'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')]}

PARAMETERS=[('@DatabaseNames','nvarchar(max) = NULL'),('@SystemdatenbankenEinbeziehen','bit = 0'),('@DatabaseNamePattern','nvarchar(4000) = NULL'),('@HighImpactConfirmed','bit = 0'),('@MinUsedPercent','decimal(5,2) = NULL'),('@MitVlfInformationen','bit = 0'),('@MitPersistentVersionStore','bit = 0'),('@MaxZeilen','int = 1000'),('@ResultSetArt',"varchar(16) = 'CONSOLE'"),('@ResultTablesJson','nvarchar(max) = NULL'),('@JsonErzeugen','bit = 0'),('@Json','nvarchar(max) = NULL OUTPUT'),('@PrintMeldungen','bit = 1'),('@Hilfe','bit = 0')]
CAP="""    IF @MaxZeilen IS NOT NULL AND @MaxZeilen > 0
    BEGIN
        ;WITH [R] AS
        (
            SELECT *, ROW_NUMBER() OVER (ORDER BY [UsedLogPercent] DESC, [DatabaseName]) AS [rn]
            FROM [#CurrentLog_Result]
        )
        DELETE FROM [R] WHERE [rn] > @EffectiveMaxZeilen;
    END;

"""
TOKENS={
 'Version      : 2.0.0':1,'Stand        : 2026-07-15':1,'1 AS [schemaVersion]':1,
 "@AnalysisClass = 'STANDARD_CURRENT'":1,"@AnalysisClass='LOG_VLF_DEEP'":1,
 'SELECT @CandidateRowCount = COUNT_BIG(*) FROM [#CurrentLog_Result];':1,
 'SET @HasMoreRows = CONVERT(bit, CASE WHEN @CandidateRowCount > @EffectiveMaxZeilen THEN 1 ELSE 0 END);':1,
 'SET @RowCount = CASE WHEN @CandidateRowCount > @EffectiveMaxZeilen THEN @EffectiveMaxZeilen ELSE @CandidateRowCount END;':1,
 "SET @StatusCode = CASE WHEN @RowCount > 0 THEN 'PARTIAL_RESULT' ELSE 'ERROR_HANDLED' END;":1,
 'COALESCE([UsedLogPercent], -1) < @MinUsedPercent':1,
 '[total_log_size_in_bytes] / 1048576.0':1,'[used_log_space_in_bytes] / 1048576.0':1,
 'CONVERT(decimal(19,4), [used_log_space_in_percent])':1,'[log_space_in_bytes_since_last_backup] / 1048576.0':1,
 'SELECT @Cnt = COUNT_BIG(*) FROM [sys].[dm_db_log_info](DB_ID());':1,
 '[TotalVlfCount] = COALESCE([TotalVlfCount], @Cnt)':1,
 'SUM([persistent_version_store_size_kb])':1,'COALESCE([p].[PersistentVersionStoreSizeKb], 0) / 1024.0':1,
 'SELECT TOP (@EffectiveMaxZeilen) [r].*':2,
 "@SourceTable=N'#CurrentLog_Result'":1,"@SourceTable = N'#CurrentLog_Result'":1,
 'ORDER BY [r].[UsedLogPercent] DESC, [r].[DatabaseName]':3,
 'InternalPrepareSingleResultTable':1,"@ResultName=N'logs'":1,
 'WHERE [r].[IsAdrEnabled] = 1':1,"WHERE [IsAdrEnabled] = 0 AND [PvsStatus] = 'PENDING'":1,
}
def norm(s): return re.sub(r'\s+',' ',s).strip()
def findings(source):
 errors=[]
 actual={m[1]:[(n,norm(d)) for n,d in re.findall(r'^\s*(?:,\s*)?\[([^]]+)\]\s+([^\n]+)',m[2],re.M)] for m in re.finditer(r'CREATE TABLE \[(#CurrentLog_[^]]+)\]\s*\((.*?)\);',source,re.S)}
 if list(actual)!=list(TABLES): errors.append('TABLE_NAMES_ORDER')
 for table,fields in TABLES.items():
  if actual.get(table)!=fields: errors.append('DDL:'+table)
 sig=source[source.find('CREATE OR ALTER PROCEDURE'):source.find('\nAS\n')]
 if [(n,norm(d)) for n,d in re.findall(r'^\s*,?\s*(@\w+)\s+([^\n]+)',sig,re.M)]!=PARAMETERS: errors.append('PARAMETERS')
 for token,count in TOKENS.items():
  if source.count(token)!=count: errors.append('BOUNDARY:'+token)
 prepare=source.find('EXEC [monitor].[InternalPrepareSingleResultTable]')
 help_at=source.find('IF @Hilfe = 1');validation=source.find('IF @MaxZeilen < 0')
 if not 0<prepare<help_at<validation: errors.append('EARLY_TABLE_PREFLIGHT')
 if '@ParentCurrentStateSnapshotId' in source or 'CREATE TABLE [#CurrentOverview_' in source: errors.append('NO_SNAPSHOT_OWNER')
 if 'ELSE CONVERT(bigint, 0) END;' not in source: errors.append('SAFE_NEGATIVE_LIMIT')
 if source.count(CAP)!=1: errors.append('EXACT_SHARED_CAP')
 else:
  count=source.find('SELECT @CandidateRowCount = COUNT_BIG(*)');more=source.find('SET @HasMoreRows')
  status=source.find("SET @StatusCode = CASE WHEN @RowCount > 0")
  detail=source.find('SET @Detail = CONCAT');detail_end=source.find('    END;',detail)
  cap=source.find(CAP);warning=source.find("IF @StatusCode <> 'AVAILABLE' AND @PrintMeldungen = 1")
  json=source.find('IF @JsonErzeugen = 1')
  if not 0<count<more<status<detail<detail_end<cap<warning<json: errors.append('CAP_AFTER_FULL_STATUS_DETAIL')
  if len(re.findall(r'\bDELETE\b',source[detail_end:warning],re.I))!=1: errors.append('ONLY_RESULT_CAP')
 return errors

def self_test(source):
 if findings(source): raise AssertionError(('baseline fails',findings(source)))
 mutations=[]
 for table,fields in TABLES.items():
  start=source.index('CREATE TABLE ['+table+']');end=source.index(');',start);block=source[start:end]
  for name,definition in fields:
   m=re.search(r'\['+re.escape(name)+r'\]\s+'+r'\s+'.join(re.escape(x) for x in definition.split()),block);assert m
   literal=m[0]
   variants=[literal.replace('['+name+']','[ExampleWrong]',1),re.sub(r'(\]\s+)\w+(?:\([^)]*\))?',r'\1sql_variant',literal,count=1),literal.replace(' NOT NULL',' NULL') if ' NOT NULL' in literal else literal.replace(' NULL',' NOT NULL'),literal+' IDENTITY(1,1)']
   if 'COLLATE ' in literal:variants += [literal.replace(' COLLATE SQL_Latin1_General_CP1_CS_AS',''),literal.replace('SQL_Latin1_General_CP1_CS_AS','Latin1_General_100_CI_AS')]
   if re.search(r'\((\d+)\)',literal):variants.append(re.sub(r'\((\d+)\)',lambda m:'('+str(int(m[1])+1)+')',literal,count=1))
   if re.search(r'\((\d+),(\d+)\)',literal):
    variants.append(re.sub(r'\((\d+),(\d+)\)',lambda m:'('+str(int(m[1])-1)+','+m[2]+')',literal,count=1))
    variants.append(re.sub(r'\((\d+),(\d+)\)',lambda m:'('+m[1]+','+str(int(m[2])+1)+')',literal,count=1))
   for v in variants:mutations.append(source[:start]+block.replace(literal,v,1)+source[end:])
 sigstart=source.index('CREATE OR ALTER PROCEDURE');sigend=source.index('\nAS\n');sig=source[sigstart:sigend]
 for name,definition in PARAMETERS:
  m=re.search(re.escape(name)+r'\s+'+r'\s+'.join(re.escape(x) for x in definition.split()),sig);assert m
  literal=m[0]
  variants=[literal.replace(name,'@ExampleWrong',1),re.sub(r'(@\w+\s+)\w+(?:\([^)]*\))?',r'\1sql_variant',literal,count=1),re.sub(r'=\s*(?:NULL|0|1|1000|\x27CONSOLE\x27)',"= 'ExampleWrong'",literal,count=1),literal.replace(' OUTPUT','') if ' OUTPUT' in literal else literal+' OUTPUT']
  for v in variants:mutations.append(source[:sigstart]+sig.replace(literal,v,1)+source[sigend:])
 lines=sig.splitlines();a=next(i for i,x in enumerate(lines) if '@DatabaseNames' in x);b=next(i for i,x in enumerate(lines) if '@DatabaseNamePattern' in x);lines[a],lines[b]=lines[b],lines[a];mutations.append(source[:sigstart]+'\n'.join(lines)+source[sigend:])
 for token in TOKENS:mutations.append(source.replace(token,'ExampleMutation',1))
 mutations.append(source.replace(CAP,''))
 mutations.append(source.replace(CAP,CAP.replace('[UsedLogPercent] DESC, [DatabaseName]','[DatabaseName], [UsedLogPercent] DESC')))
 early=source.replace(CAP,'');at=early.index('        SELECT @CandidateRowCount');mutations.append(early[:at]+CAP+early[at:])
 early=source.replace(CAP,'');at=early.index('        SET @Detail = CONCAT');mutations.append(early[:at]+CAP+early[at:])
 mutations.append(source.replace(CAP,CAP+'    DELETE FROM [#CurrentLog_Errors];\n'))
 for i,m in enumerate(mutations):
  if not findings(m): raise AssertionError(('mutation survived',i))
 return len(mutations)

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--repository-root',type=Path,required=True);ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
 source=(a.repository_root/PROCEDURE_PATH).read_text(encoding='utf-8-sig').replace('\r\n','\n')
 errors=findings(source)
 if errors:print('Current Log validation failed: '+', '.join(errors));return 1
 if a.self_test:print(f'Current Log genuine mutation self-test passed: {self_test(source)} mutations.')
 else:print('Current Log literal validation passed: 37 fields/20 collations/14 parameters.')
 return 0
if __name__=='__main__':raise SystemExit(main())
