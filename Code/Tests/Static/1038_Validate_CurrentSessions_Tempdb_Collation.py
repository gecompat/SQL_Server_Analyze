#!/usr/bin/env python3
"""Validate CurrentSessions literal work-table ABI, shared cap and consumer boundaries."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
PROCEDURE_PATH=Path("Code/02_CurrentState/010_USP_CurrentSessions.sql")
TABLES={'#CurrentSessions_SessionIdFilter': [('SessionId', 'smallint NOT NULL PRIMARY KEY')],
 '#CurrentSessions_StringFilter': [('FilterType', 'varchar(20) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                   ('StringValue', 'nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentSessions_Result': [('SessionId', 'smallint NOT NULL'),
                             ('RequestId', 'int NULL'),
                             ('IsUserProcess', 'bit NOT NULL'),
                             ('SessionStatus', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('RequestStatus', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('LoginName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('OriginalLoginName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('HostName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('ProgramName', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('IsToolBackgroundQuery', 'bit NOT NULL'),
                             ('ToolBackgroundRuleCode', 'varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('ToolBackgroundCategory', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('ToolBackgroundDetection', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('ToolBackgroundConfidence', 'varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('ClientInterfaceName', 'nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('LoginTime', 'datetime NULL'),
                             ('LastRequestStartTime', 'datetime NULL'),
                             ('LastRequestEndTime', 'datetime NULL'),
                             ('DatabaseId', 'smallint NULL'),
                             ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('OpenTransactionCount', 'int NULL'),
                             ('TransactionIsolationLevel', 'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('SessionCpuMs', 'int NULL'),
                             ('SessionReads', 'bigint NULL'),
                             ('SessionWrites', 'bigint NULL'),
                             ('SessionLogicalReads', 'bigint NULL'),
                             ('SessionMemoryMb', 'decimal(19,2) NULL'),
                             ('SessionRowCount', 'bigint NULL'),
                             ('RequestCpuMs', 'int NULL'),
                             ('RequestElapsedMs', 'int NULL'),
                             ('RequestLogicalReads', 'bigint NULL'),
                             ('RequestReads', 'bigint NULL'),
                             ('RequestWrites', 'bigint NULL'),
                             ('BlockingSessionId', 'smallint NULL'),
                             ('WaitType', 'nvarchar(120) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('WaitTimeMs', 'int NULL'),
                             ('WaitResource', 'nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('PercentComplete', 'real NULL'),
                             ('ClientNetAddress', 'varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('NetTransport', 'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('ProtocolType', 'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('EncryptOption', 'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('AuthScheme', 'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('CurrentStatementCharacters', 'bigint NULL'),
                             ('CurrentStatementBytes', 'bigint NULL'),
                             ('CurrentStatementIsTruncated', 'bit NOT NULL DEFAULT(0)'),
                             ('CurrentStatement', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                             ('BatchTextCharacters', 'bigint NULL'),
                             ('BatchTextBytes', 'bigint NULL'),
                             ('BatchTextIsTruncated', 'bit NOT NULL DEFAULT(0)'),
                             ('BatchText', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')],
 '#CurrentSessions_SourceSessions': [('session_id', 'smallint NOT NULL PRIMARY KEY'),
                                     ('is_user_process', 'bit NOT NULL'),
                                     ('status', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('login_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('original_login_name',
                                      'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('host_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('program_name', 'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('client_interface_name',
                                      'nvarchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('login_time', 'datetime NOT NULL'),
                                     ('last_request_start_time', 'datetime NOT NULL'),
                                     ('last_request_end_time', 'datetime NULL'),
                                     ('open_transaction_count', 'int NOT NULL'),
                                     ('transaction_isolation_level', 'smallint NOT NULL'),
                                     ('cpu_time', 'int NOT NULL'),
                                     ('reads', 'bigint NOT NULL'),
                                     ('writes', 'bigint NOT NULL'),
                                     ('logical_reads', 'bigint NOT NULL'),
                                     ('memory_usage', 'int NOT NULL'),
                                     ('row_count', 'bigint NOT NULL')],
 '#CurrentSessions_SourceRequests': [('session_id', 'smallint NOT NULL'),
                                     ('request_id', 'int NOT NULL'),
                                     ('status', 'nvarchar(30) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('database_id', 'smallint NOT NULL'),
                                     ('cpu_time', 'int NOT NULL'),
                                     ('total_elapsed_time', 'int NOT NULL'),
                                     ('logical_reads', 'bigint NOT NULL'),
                                     ('reads', 'bigint NOT NULL'),
                                     ('writes', 'bigint NOT NULL'),
                                     ('blocking_session_id', 'smallint NULL'),
                                     ('wait_type', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                     ('wait_time', 'int NOT NULL'),
                                     ('wait_resource', 'nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                     ('percent_complete', 'real NOT NULL'),
                                     ('sql_handle', 'varbinary(64) NULL'),
                                     ('statement_start_offset', 'int NULL'),
                                     ('statement_end_offset', 'int NULL')],
 '#CurrentSessions_SourceConnections': [('session_id', 'int NULL'),
                                        ('connection_id', 'uniqueidentifier NOT NULL PRIMARY KEY'),
                                        ('most_recent_sql_handle', 'varbinary(64) NULL'),
                                        ('client_net_address', 'varchar(48) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                        ('net_transport', 'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                        ('protocol_type', 'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                        ('encrypt_option',
                                         'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'),
                                        ('auth_scheme', 'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')],
 '#CurrentSessions_SourceSqlText': [('SqlHandle', 'varbinary(64) NOT NULL PRIMARY KEY'),
                                    ('text', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'),
                                    ('dbid', 'int NULL'),
                                    ('objectid', 'int NULL'),
                                    ('number', 'smallint NULL'),
                                    ('encrypted', 'bit NULL')]}
PARAMETERS=['@SessionIds', '@EigeneSessionsModus', '@AktuelleSessionEinbeziehen', '@SystemSessionsEinbeziehen', '@ToolHintergrundabfragenEinbeziehen', '@InaktiveSessionsEinbeziehen', '@LoginNames', '@LoginNamePattern', '@HostNames', '@HostNamePattern', '@ProgramNames', '@ProgramNamePattern', '@DatabaseNames', '@DatabaseNamePattern', '@HighImpactConfirmed', '@MitSqlText', '@MaxSqlTextZeichen', '@MaxZeilen', '@Sortierung', '@ResultSetArt', '@ResultTablesJson', '@JsonErzeugen', '@Json', '@PrintMeldungen', '@Hilfe', '@ParentCurrentStateSnapshotId']
TOKEN_COUNTS={'[SnapshotId]=@ParentCurrentStateSnapshotId': 6, 'ELSE CONVERT(bigint,@MaxZeilen)+1 END': 1, '@TruncatedValueCount=@TruncatedValueCount,@ParameterName': 1, 'INVALID_PARENT_SNAPSHOT': 2, 'Version      : 2.2.0': 1, 'Stand        : 2026-07-22': 1, 'SET LOCK_TIMEOUT 0;': 1, '3 AS [schemaVersion]': 1, 'FOR JSON PATH,INCLUDE_NULL_VALUES': 2, "@SourceTable=N'#CurrentSessions_Result'": 3, "@SourceTable = N'#CurrentSessions_Result'": 1, '@ParentCurrentStateSnapshotId IS NOT NULL': 1, '[ContractVersion]=2': 1, '[OwnerSessionId]=CONVERT(smallint,@@SPID)': 1, '@MaxZeilen<0': 1, '@MaxSqlTextZeichen<0': 1, '@HasRegex=1': 3, 'DELETE FROM [R] WHERE [rn]>@MaxZeilen;': 1, '[SourceCode] IN': 1, '@AktuelleSessionEinbeziehen=1 OR [s].[session_id]<>@@SPID': 1, '@TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable]': 1, 'CROSS APPLY [monitor].[TVF_WaitTypeInfo]': 2, 'ORDER BY [rr].[request_id]': 1, '@ToolHintergrundabfragenEinbeziehen=1 OR [tool].[IsToolBackgroundQuery]=0': 1, '@ParentSnapshotIsPartial=CONVERT(bit,MAX(CONVERT(int,[IsPartial])))': 1}

def definitions(source:str)->dict[str,list[tuple[str,str]]]:
 result={}
 for m in re.finditer(r"CREATE TABLE \[(#CurrentSessions_[^]]+)\]\s*\((.*?)\n    \);",source,re.S):
  fields=[]
  for part in re.split(r",\s*(?=\[|PRIMARY KEY)",m[2].strip()):
   f=re.fullmatch(r"\s*\[([^]]+)\]\s+(.*?)\s*",part,re.S)
   if f:fields.append((f[1],re.sub(r"\s+"," ",f[2])))
  result[m[1]]=fields
 return result

def validate(source:str)->list[str]:
 errors=[]
 actual=definitions(source)
 if list(actual)!=list(TABLES):errors.append("TABLE_ORDER")
 for table,fields in TABLES.items():
  if actual.get(table)!=fields:errors.append("DDL:"+table)
 for token,count in TOKEN_COUNTS.items():
  if source.count(token)!=count:errors.append("BOUNDARY:"+token)
 p=re.findall(r"^\s*,?\s*(@\w+)\s+",source[source.find("CREATE OR ALTER"):source.find("\nAS\n")],re.M)
 if p!=PARAMETERS:errors.append("PARAMETERS")
 positions=[source.find("SET @HasMoreRows=1"),source.find("DELETE FROM [R] WHERE [rn]>@MaxZeilen;"),source.find("EXEC [monitor].[InternalProjectUnicodeTextColumn]"),source.find("EXEC [monitor].[InternalEmitTruncationWarning]"),source.find("SELECT @RowCount=COUNT_BIG(*)"),source.find("IF @JsonErzeugen=1")]
 if any(i<0 for i in positions) or positions!=sorted(positions):errors.append("SHARED_CAP_ORDER")
 if "[wi].[WaitGroup] AS [waitGroup],[wi].[Severity] AS [waitSeverity],[wi].[Meaning] AS [waitMeaning]" not in source:errors.append("JSON_WAIT_FIELDS")
 if "[wi].[HelpUrl] AS [WaitHelpUrl],[wi].[InterpretationScope],[wi].[CatalogMatchType]" not in source:errors.append("RAW_WAIT_FIELDS")
 # The active helper consumers share the materialized result; the legacy branch is not their ABI.
 if source.find("CREATE TABLE [#CurrentSessions_Result]")>source.find("WITH NOWAIT"):errors.append("EARLY_DDL")
 return errors

def self_test(source:str)->int:
 assert not validate(source),validate(source)
 mutations=[]
 for table,fields in TABLES.items():
  start=source.index("CREATE TABLE ["+table+"]");end=source.index("\n    );",start)
  block=source[start:end]
  for name,definition in fields:
   original="["+name+"] "+definition
   # SQL permits arbitrary whitespace; locate the entire exact declaration in its own block.
   match=re.search(r"\["+re.escape(name)+r"\]\s+"+r"\s+".join(re.escape(x) for x in definition.split()),block)
   assert match,(table,name)
   literal=match[0]
   variants=[literal.replace("["+name+"]","[ExampleWrong]",1),literal.replace(definition.split()[0],"sql_variant",1)]
   if 'COLLATE ' in literal:variants.append(literal.replace('SQL_Latin1_General_CP1_CS_AS','Latin1_General_100_CI_AS'))
   variants.append(literal.replace('NOT NULL','NULL',1) if 'NOT NULL' in literal else re.sub(r'\bNULL\b','NOT NULL',literal,count=1))
   for variant in variants:mutations.append(source[:start]+block[:match.start()]+variant+block[match.end():]+source[end:])
 for token in TOKEN_COUNTS:mutations.append(source.replace(token,'EXAMPLE_REMOVED',1))
 for token in ['[wi].[WaitGroup] AS [waitGroup],[wi].[Severity] AS [waitSeverity],[wi].[Meaning] AS [waitMeaning]','[wi].[HelpUrl] AS [WaitHelpUrl],[wi].[InterpretationScope],[wi].[CatalogMatchType]']:
  mutations.append(source.replace(token,'EXAMPLE_REMOVED',1))
 cap='DELETE FROM [R] WHERE [rn]>@MaxZeilen;'
 mutations.append(source.replace(cap,'DELETE FROM [R] WHERE [rn]>=@MaxZeilen;',1))
 mutations.append(source.replace(cap,'',1).replace('SET @HasMoreRows=1',cap+'SET @HasMoreRows=1',1))
 for i,mutation in enumerate(mutations):assert validate(mutation),f'undetected mutation {i}'
 return len(mutations)

def main()->int:
 p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,default=Path('.'));p.add_argument('--self-test',action='store_true');args=p.parse_args()
 source=(args.repository_root/PROCEDURE_PATH).read_text(encoding='utf-8-sig')
 if args.self_test:
  count=self_test(source);print(f'Current Sessions self-test passed: mutations={count} findings=0');return 0
 errors=validate(source)
 if errors:print('Current Sessions contract failed: '+', '.join(errors));return 1
 print('Current Sessions contract passed: tables=7 fields=104 text_collations=39 public_fields=51 public_texts=22 findings=0');return 0
if __name__=='__main__':raise SystemExit(main())
