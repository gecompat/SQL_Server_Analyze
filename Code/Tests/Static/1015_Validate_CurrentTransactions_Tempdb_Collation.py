#!/usr/bin/env python3
"""Validate literal CurrentTransactions fields, ABI, parent isolation and late cap."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
PROCEDURE_PATH=Path("Code/02_CurrentState/050_USP_CurrentTransactions.sql")
TABLES={'#CurrentTransactions_SessionFilter': [('SessionId', 'smallint NOT NULL PRIMARY KEY')],
 '#CurrentTransactions_Result': [('SessionId', 'smallint NOT NULL'),
                                 ('TransactionId', 'bigint NOT NULL'),
                                 ('TransactionBeginTimeUtc', 'datetime NULL'),
                                 ('TransactionAgeSeconds', 'bigint NULL'),
                                 ('TransactionType', 'int NULL'),
                                 ('TransactionState', 'int NULL'),
                                 ('OpenTransactionCount', 'int NULL'),
                                 ('LoginName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                 ('HostName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                 ('ProgramName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                 ('SessionStatus', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                 ('RequestStatus', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                 ('DatabaseId', 'int NULL'),
                                 ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                 ('LogBytesUsed', 'bigint NULL'),
                                 ('LogBytesReserved', 'bigint NULL'),
                                 ('StatementTextCharacters', 'bigint NULL'),
                                 ('StatementTextBytes', 'bigint NULL'),
                                 ('StatementTextIsTruncated', 'bit NOT NULL DEFAULT(0)'),
                                 ('StatementText', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentTransactions_Warnings': [('StatusCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                   ('ErrorNumber', 'int NULL'),
                                   ('ErrorMessage', 'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentTransactions_SourceSessionTransactions': [('session_id', 'int NOT NULL'),
                                                    ('transaction_id', 'bigint NOT NULL')],
 '#CurrentTransactions_SourceActiveTransactions': [('transaction_id', 'bigint NOT NULL PRIMARY KEY'),
                                                   ('transaction_begin_time', 'datetime NULL'),
                                                   ('transaction_type', 'int NULL'),
                                                   ('transaction_state', 'int NULL')],
 '#CurrentTransactions_SourceDatabaseTransactions': [('transaction_id', 'bigint NOT NULL'),
                                                     ('database_id', 'int NOT NULL'),
                                                     ('database_transaction_log_bytes_used', 'bigint NOT NULL'),
                                                     ('database_transaction_log_bytes_reserved', 'bigint NOT NULL')],
 '#CurrentTransactions_SourceSessions': [('session_id', 'smallint NOT NULL PRIMARY KEY'),
                                         ('is_user_process', 'bit NOT NULL'),
                                         ('status', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                         ('open_transaction_count', 'int NOT NULL'),
                                         ('login_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                         ('host_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                         ('program_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentTransactions_SourceRequests': [('session_id', 'smallint NOT NULL'),
                                         ('request_id', 'int NOT NULL'),
                                         ('status', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                         ('database_id', 'smallint NOT NULL'),
                                         ('sql_handle', 'varbinary(64) NULL'),
                                         ('statement_start_offset', 'int NULL'),
                                         ('statement_end_offset', 'int NULL')],
 '#CurrentTransactions_SourceSqlText': [('SqlHandle', 'varbinary(64) NOT NULL PRIMARY KEY'),
                                        ('Text', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')]}
PARAMETERS=[('@SessionIds', 'nvarchar(max) = NULL'), ('@MinAlterSekunden', 'int = 0'), ('@NurSleeping', 'bit = 0'), ('@SystemSessionsEinbeziehen', 'bit = 0'), ('@MitSqlText', 'bit = 1'), ('@MaxSqlTextZeichen', 'int = 3000'), ('@MaxZeilen', 'int = 1000'), ('@ResultSetArt', "varchar(16) = 'CONSOLE'"), ('@ResultTablesJson', 'nvarchar(max) = NULL'), ('@JsonErzeugen', 'bit = 0'), ('@Json', 'nvarchar(max) = NULL OUTPUT'), ('@PrintMeldungen', 'bit = 1'), ('@Hilfe', 'bit = 0'), ('@ParentCurrentStateSnapshotId', 'uniqueidentifier = NULL')]
TOKENS={'Version      : 3.0.0': 1,
 'Stand        : 2026-07-23': 1,
 '2 AS [schemaVersion]': 1,
 '[ContractVersion]=2': 1,
 '[OwnerSessionId]=CONVERT(smallint,@@SPID)': 1,
 '[SnapshotId]=@ParentCurrentStateSnapshotId': 8,
 "'INVALID_PARENT_SNAPSHOT'": 1,
 'SELECT TOP (@Candidates)': 1,
 'SELECT TOP (@Limit) *': 2,
 "@SourceTable=N'#CurrentTransactions_Result'": 2,
 "@SourceTable = N'#CurrentTransactions_Result'": 1,
 '@MaxSqlTextZeichen < 0': 1,
 '@MaxZeilen < 0': 1,
 'COALESCE(@MinAlterSekunden, -1) < 0': 1,
 'HAVING COUNT(*) > 1': 1,
 '[NumberValue] NOT BETWEEN 0 AND 32767': 1,
 "[s].[status] = N'sleeping'": 1,
 'DATEDIFF_BIG(SECOND, [at].[transaction_begin_time], GETDATE())': 3,
 '@RowCount = COUNT_BIG(*)': 1,
 '@RowCount > @Limit': 3,
 'IF @MitSqlText=1': 2,
 'CASE WHEN @MitSqlText = 1 THEN [statementText].[StatementText] END': 1}
CAP="DELETE FROM [R] WHERE [rn]>@Limit;"
REFERENCE_CAP='    IF @MaxZeilen IS NOT NULL AND @MaxZeilen>0\n    BEGIN\n        ;WITH [R] AS\n        (\n            SELECT *,ROW_NUMBER() OVER(ORDER BY [TransactionAgeSeconds] DESC,[SessionId],[TransactionId]) AS [rn]\n            FROM [#CurrentTransactions_Result]\n        )\n        DELETE FROM [R] WHERE [rn]>@Limit;\n    END;\n\n'

def normalize(value:str)->str:return re.sub(r"\s+"," ",value).strip()
def definitions(source:str)->dict[str,list[tuple[str,str]]]:
 return {m[1]:[(n,normalize(d)) for n,d in re.findall(r"^\s*(?:,\s*)?\[([^]]+)\]\s+([^\n]+)",m[2],re.M)] for m in re.finditer(r"CREATE TABLE \[(#CurrentTransactions_[^]]+)\]\s*\((.*?)\);",source,re.S)}
def findings(source:str)->list[str]:
 errors=[];actual=definitions(source)
 if list(actual)!=list(TABLES):errors.append("TABLE_NAMES_ORDER")
 for table,fields in TABLES.items():
  if actual.get(table)!=fields:errors.append("DDL:"+table)
 sig=source[source.find("CREATE OR ALTER PROCEDURE"):source.find("\nAS\n")]
 if [(n,normalize(d)) for n,d in re.findall(r"^\s*,?\s*(@\w+)\s+([^\n]+)",sig,re.M)]!=PARAMETERS:errors.append("PARAMETERS")
 for token,count in TOKENS.items():
  if source.count(token)!=count:errors.append("BOUNDARY:"+token)
 prepare=source.find("EXEC [monitor].[InternalPrepareSingleResultTable]");validation=source.find("IF @SessionIds IS NOT NULL")
 if prepare<0 or not prepare<validation:errors.append("EARLY_MAPPING")
 if source.count(CAP)!=1:errors.append("LATE_SHARED_CAP")
 else:
  cap=source.index(CAP);project=source.find("EXEC [monitor].[InternalProjectUnicodeTextColumn]");warning=source.find("EXEC [monitor].[InternalEmitTruncationWarning]")
  count=source.find("SELECT @RowCount = COUNT_BIG(*)");more=source.find("SET @HasMoreRows =");catch=source.find("END CATCH;",more);consumer=source.find("IF @OutputMode <> 'NONE'")
  if min(project,warning,count,more,catch,consumer)<0 or not project<warning<count<more<catch<cap<consumer:errors.append("CAP_AFTER_FULL_WORK_AND_CATCH")
  block=source[source.rfind("IF @MaxZeilen",0,cap):cap+len(CAP)]
  if not re.search(r"@MaxZeilen\s+IS NOT NULL\s+AND\s+@MaxZeilen\s*>\s*0",block):errors.append("CAP_UNLIMITED")
  if 'ROW_NUMBER() OVER(ORDER BY [TransactionAgeSeconds] DESC,[SessionId],[TransactionId])' not in block:errors.append("CAP_RANK")
  if 'FROM [#CurrentTransactions_Result]' not in block:errors.append("CAP_SOURCE")
  final=source[catch:consumer]
  if len(re.findall(r"\bDELETE\b",final,re.I))!=1 or re.search(r"\bTOP\s*\(",final,re.I) or '#CurrentTransactions_Source' in final:errors.append("FINAL_RESULT_CAP_ONLY")
 return errors
def self_test(source:str)->tuple[int,bool]:
 # An unrepaired original is an expected negative input. The reference cap below
 # is a validator fixture only; it is never written into the production source.
 original_missing=False
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
 assert len(parameter_lines)==14
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
  reference.replace('ORDER BY [TransactionAgeSeconds] DESC,[SessionId],[TransactionId]','ORDER BY [SessionId],[TransactionAgeSeconds] DESC,[TransactionId]',1),
  reference.replace('@MaxZeilen>0','@MaxZeilen>=0',1),
  reference.replace(REFERENCE_CAP,'',1).replace('        SELECT @RowCount = COUNT_BIG(*)',REFERENCE_CAP+'        SELECT @RowCount = COUNT_BIG(*)',1),
  reference.replace(REFERENCE_CAP,'',1).replace('    END TRY\n    BEGIN CATCH\n        SET @ErrorNumber = ERROR_NUMBER();',REFERENCE_CAP+'    END TRY\n    BEGIN CATCH\n        SET @ErrorNumber = ERROR_NUMBER();',1),
  reference.replace(CAP,CAP+"\nDELETE FROM [#CurrentTransactions_SourceSessions];",1)])
 for i,mutation in enumerate(mutations):assert mutation!=reference and findings(mutation),f'undetected mutation {i}'
 return len(mutations),original_missing

def main()->int:
 p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,default=Path('.'));p.add_argument('--self-test',action='store_true');a=p.parse_args()
 source=(a.repository_root/PROCEDURE_PATH).read_text(encoding='utf-8-sig')
 if a.self_test:
  count,_=self_test(source);print(f'CurrentTransactions self-test passed: mutations={count}');return 0
 errors=findings(source)
 if errors:print('CurrentTransactions contract failed: '+', '.join(errors));return 1
 print('CurrentTransactions contract passed: tables=9 fields=50 texts=15 public_fields=20 public_texts=7 parameters=14');return 0
if __name__=='__main__':raise SystemExit(main())
