#!/usr/bin/env python3
"""Validate QueryStats field ABI, existing rank semantics and late shared selection."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys
PROCEDURE_PATH=Path("Code/04_PlanCache/010_USP_QueryStats.sql")
TABLES={'#QueryStats_DatabaseCandidates': [('DatabaseId', 'int NOT NULL PRIMARY KEY'), ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'), ('StateDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('UserAccessDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('IsReadOnly', 'bit NULL'), ('CompatibilityLevel', 'tinyint NULL'), ('CollationName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('RecoveryModelDesc', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('IsSystemDatabase', 'bit NULL'), ('RequestedOrdinal', 'int NULL')], '#QueryStats_DatabaseCandidateWarnings': [('RequestedName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('StatusCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'), ('ErrorMessage', 'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')], '#QueryStats_Result': [('QueryHash', 'binary(8) NULL'), ('QueryPlanHash', 'binary(8) NULL'), ('PlanHandle', 'varbinary(64) NOT NULL'), ('SqlHandle', 'varbinary(64) NOT NULL'), ('StatementStartOffset', 'int NOT NULL'), ('StatementEndOffset', 'int NOT NULL'), ('PlanGenerationNumber', 'bigint NOT NULL'), ('DatabaseId', 'int NULL'), ('DatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('ObjectId', 'int NULL'), ('StatementTextCharacters', 'bigint NULL'), ('StatementTextBytes', 'bigint NULL'), ('StatementTextIsTruncated', 'bit NOT NULL DEFAULT(0)'), ('StatementText', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('BatchTextCharacters', 'bigint NULL'), ('BatchTextBytes', 'bigint NULL'), ('BatchTextIsTruncated', 'bit NOT NULL DEFAULT(0)'), ('BatchText', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('CreationTime', 'datetime NOT NULL'), ('LastExecutionTime', 'datetime NOT NULL'), ('ExecutionCount', 'bigint NOT NULL'), ('TotalCpuMs', 'decimal(38,3) NULL'), ('LastCpuMs', 'decimal(38,3) NULL'), ('MinCpuMs', 'decimal(38,3) NULL'), ('MaxCpuMs', 'decimal(38,3) NULL'), ('AvgCpuMs', 'decimal(38,3) NULL'), ('TotalElapsedMs', 'decimal(38,3) NULL'), ('LastElapsedMs', 'decimal(38,3) NULL'), ('MinElapsedMs', 'decimal(38,3) NULL'), ('MaxElapsedMs', 'decimal(38,3) NULL'), ('AvgElapsedMs', 'decimal(38,3) NULL'), ('TotalLogicalReads', 'bigint NOT NULL'), ('LastLogicalReads', 'bigint NOT NULL'), ('AvgLogicalReads', 'decimal(38,3) NULL'), ('TotalLogicalWrites', 'bigint NOT NULL'), ('LastLogicalWrites', 'bigint NOT NULL'), ('AvgLogicalWrites', 'decimal(38,3) NULL'), ('TotalPhysicalReads', 'bigint NOT NULL'), ('LastPhysicalReads', 'bigint NOT NULL'), ('TotalRows', 'bigint NOT NULL'), ('LastRows', 'bigint NOT NULL'), ('MinRows', 'bigint NOT NULL'), ('MaxRows', 'bigint NOT NULL'), ('LastDop', 'bigint NOT NULL'), ('MinDop', 'bigint NOT NULL'), ('MaxDop', 'bigint NOT NULL'), ('MaxGrantKb', 'bigint NOT NULL'), ('LastGrantKb', 'bigint NOT NULL'), ('LastUsedGrantKb', 'bigint NOT NULL'), ('LastIdealGrantKb', 'bigint NOT NULL'), ('TotalSpilledPages', 'bigint NOT NULL'), ('LastSpilledPages', 'bigint NOT NULL'), ('CacheObjectType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('ObjectType', 'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('PlanUseCounts', 'int NULL'), ('PlanSizeBytes', 'bigint NULL'), ('ResourcePoolId', 'int NULL'), ('SetOptions', 'int NULL'), ('CompileUserId', 'int NULL'), ('SortValue', 'decimal(38,4) NULL')]}
RANKS={'CPU_TOTAL': '[qs].[total_worker_time]', 'CPU_AVG': '[qs].[total_worker_time] * 1.0 / NULLIF([qs].[execution_count], 0)', 'ELAPSED_TOTAL': '[qs].[total_elapsed_time]', 'ELAPSED_AVG': '[qs].[total_elapsed_time] * 1.0 / NULLIF([qs].[execution_count], 0)', 'READS_TOTAL': '[qs].[total_logical_reads]', 'READS_AVG': '[qs].[total_logical_reads] * 1.0 / NULLIF([qs].[execution_count], 0)', 'WRITES_TOTAL': '[qs].[total_logical_writes]', 'WRITES_AVG': '[qs].[total_logical_writes] * 1.0 / NULLIF([qs].[execution_count], 0)', 'EXECUTIONS': '[qs].[execution_count]', 'GRANT_MAX': '[qs].[max_grant_kb]', 'SPILLS_TOTAL': '[qs].[total_spills]', 'ROWS_TOTAL': '[qs].[total_rows]', 'LAST_EXECUTION': "DATEDIFF_BIG(MILLISECOND, ''20000101'', [qs].[last_execution_time])"}
TOKENS=(
 "@MaxZeilen IS NULL OR @MaxZeilen = 0", "WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen) ELSE 0",
 "CONVERT(bigint, @MaxZeilen) + 1", "@MaxZeilen < 0", "@MaxSqlTextZeichen < 0", "@ParentQueryStatsSnapshot IS NULL",
 "@AnalysisClass='PLAN_CACHE_DEEP'", "@AnalysisClass = 'PLAN_CACHE_CURRENT'",
 "THEN N'[#PlanCacheAnalysis_QueryStatsSnapshot] AS [qs]'", "ELSE N'[sys].[dm_exec_query_stats] AS [qs] WITH (NOLOCK)'",
 "COALESCE([st].[dbid], [planDb].[DatabaseId])", "[qs].[execution_count] >= @MinExecutions",
 "(@Since IS NULL OR [qs].[last_execution_time] >= @Since)", "(@QH IS NULL OR [qs].[query_hash] = @QH)",
 "(@QPH IS NULL OR [qs].[query_plan_hash] = @QPH)", "(@SH IS NULL OR [qs].[sql_handle] = @SH)",
 "(@PH IS NULL OR [qs].[plan_handle] = @PH)", "InternalEmitTruncationWarning", "INCLUDE_NULL_VALUES",
 "@RowCount > @Limit", "COALESCE(@Data,N'[]')")
TOKEN_COUNTS={'@MaxZeilen IS NULL OR @MaxZeilen = 0': 2, 'WHEN @MaxZeilen > 0 THEN CONVERT(bigint, @MaxZeilen) ELSE 0': 1, 'CONVERT(bigint, @MaxZeilen) + 1': 1, '@MaxZeilen < 0': 1, '@MaxSqlTextZeichen < 0': 1, '@ParentQueryStatsSnapshot IS NULL': 1, "@AnalysisClass='PLAN_CACHE_DEEP'": 1, "@AnalysisClass = 'PLAN_CACHE_CURRENT'": 1, "THEN N'[#PlanCacheAnalysis_QueryStatsSnapshot] AS [qs]'": 1, "ELSE N'[sys].[dm_exec_query_stats] AS [qs] WITH (NOLOCK)'": 1, 'COALESCE([st].[dbid], [planDb].[DatabaseId])': 1, '[qs].[execution_count] >= @MinExecutions': 1, '(@Since IS NULL OR [qs].[last_execution_time] >= @Since)': 1, '(@QH IS NULL OR [qs].[query_hash] = @QH)': 1, '(@QPH IS NULL OR [qs].[query_plan_hash] = @QPH)': 1, '(@SH IS NULL OR [qs].[sql_handle] = @SH)': 1, '(@PH IS NULL OR [qs].[plan_handle] = @PH)': 1, 'InternalEmitTruncationWarning': 1, 'INCLUDE_NULL_VALUES': 3, '@RowCount > @Limit': 3, "COALESCE(@Data,N'[]')": 1}
def norm(value):return re.sub(r"\s+"," ",value.strip()).lower()
def findings(source):
 errors=[]
 for name,fields in TABLES.items():
  m=re.search(r"CREATE TABLE \["+re.escape(name)+r"\]\s*\((.*?)\);",source,re.S|re.I)
  actual=[] if m is None else [(n,norm(d.rstrip(','))) for n,d in re.findall(r"\[(\w+)\]\s+(.+?)(?=,\s*\[|$)",m[1].strip(),re.S)]
  if actual!=[(n,norm(d)) for n,d in fields]:errors.append("DDL:"+name)
 for rank,expr in RANKS.items():
  if "WHEN '"+rank+"' THEN N'"+expr+"'" not in source:errors.append("RANK:"+rank)
 for token in TOKENS:
  if source.count(token)!=TOKEN_COUNTS[token]:errors.append("BOUNDARY:"+token)
 selection=re.search(r";WITH \[Selection\] AS\s*\(\s*SELECT ROW_NUMBER\(\) OVER \(ORDER BY \[SortValue\] DESC, \[LastExecutionTime\] DESC\) AS \[SelectionOrdinal\]\s*FROM \[#QueryStats_Result\]\s*\)\s*DELETE FROM \[Selection\] WHERE \[SelectionOrdinal\] > @Limit;",source,re.S)
 count=source.find("SELECT @RowCount = COUNT_BIG(*) FROM [#QueryStats_Result];")
 more=source.find("SET @HasMoreRows = CONVERT(bit")
 warning=source.find("EXEC [monitor].[InternalEmitTruncationWarning]")
 consumer=source.find("IF @OutputMode <> 'NONE'")
 if selection is None or not warning<count<more<selection.start()<consumer:errors.append("LATE_SELECTION")
 for helper in ("InternalEmitConsoleResult","InternalWriteResultTable"):
  m=re.search(r"EXEC \[monitor\]\.\["+helper+r"\](.*?);",source,re.S)
  if m is None or not re.search(r"@SourceTable\s*=\s*N'#QueryStats_Result'",m[1]):errors.append("CONSUMER:"+helper)
 # The technical TABLE/CONSOLE shape includes SortValue; RAW and JSON retain their explicit 59 fields.
 for name,begin,end in (("RAW","IF @OutputMode = 'RAW'","ELSE"),("JSON","DECLARE @Data nvarchar(max)","DECLARE @Warnings nvarchar(max)")):
  body=source[source.index(begin):];body=body[:body.index(end)]
  projection=re.search(r"SELECT TOP \(@Limit\)(.*?)FROM \[#QueryStats_Result\]",body,re.S)
  actual=[] if projection is None else re.findall(r"\[([^]]+)\]",projection[1])
  if actual!=[n for n,d in TABLES['#QueryStats_Result'] if n!='SortValue']:errors.append("ABI:"+name)
 if not re.search(r"IF @StatusCode = 'AVAILABLE'\s*BEGIN TRY(.*?)InternalProjectUnicodeTextColumn",source,re.S):errors.append("VALID_ONLY_TEXT")
 return errors

def self_test(source):
 mutations=[]
 for name,fields in TABLES.items():
  body=re.search(r"CREATE TABLE \["+re.escape(name)+r"\]\s*\((.*?)\);",source,re.S)[1]
  for field,definition in fields:
   pattern=r"\["+field+r"\]\s+"+re.escape(definition).replace(r"\ ",r"\s+")
   variants=["[Broken"+field+"] "+definition,"["+field+"] sql_variant NULL","["+field+"] "+(definition.replace("NOT NULL","NULL") if "NOT NULL" in definition else definition.replace("NULL","NOT NULL"))]
   if 'COLLATE' in definition:variants.append("["+field+"] "+definition.replace('SQL_Latin1_General_CP1_CS_AS','DATABASE_DEFAULT'))
   for variant in variants:
    changed,n=re.subn(pattern,lambda _:variant,body,count=1)
    if n!=1:raise AssertionError('mutation target:'+name+'/'+field)
    mutations.append(source.replace(body,changed,1))
 for rank,expr in RANKS.items():mutations.append(source.replace("WHEN '"+rank+"' THEN N'"+expr+"'","WHEN '"+rank+"' THEN N'0'",1))
 for token in TOKENS:
  if token not in source:raise AssertionError('mutation target:'+token)
  mutations.append(source.replace(token,'BROKEN_BOUNDARY',1))
 for old,new in (("DELETE FROM [Selection] WHERE [SelectionOrdinal] > @Limit;","DELETE FROM [Selection] WHERE [SelectionOrdinal] >= @Limit;"),
  ("ORDER BY [SortValue] DESC, [LastExecutionTime] DESC) AS [SelectionOrdinal]","ORDER BY [SortValue] ASC, [LastExecutionTime] DESC) AS [SelectionOrdinal]"),
  ("SELECT @RowCount = COUNT_BIG(*) FROM [#QueryStats_Result];","SELECT @RowCount = 0;")):
  mutations.append(source.replace(old,new,1))
 selection=re.search(r"        ;WITH \[Selection\] AS.*?DELETE FROM \[Selection\] WHERE \[SelectionOrdinal\] > @Limit;",source,re.S)[0]
 early=source.replace(selection,'',1).replace("        SELECT @RowCount = COUNT_BIG(*) FROM [#QueryStats_Result];",selection+"\n        SELECT @RowCount = COUNT_BIG(*) FROM [#QueryStats_Result];",1)
 mutations.append(early)
 for helper in ("InternalEmitConsoleResult","InternalWriteResultTable"):
  m=re.search(r"EXEC \[monitor\]\.\["+helper+r"\](.*?);",source,re.S)
  mutations.append(source[:m.start()]+m[0].replace('#QueryStats_Result','#BrokenResult')+source[m.end():])
 for match in re.finditer(r"SELECT TOP \(@Limit\)(.*?)FROM \[#QueryStats_Result\]",source,re.S):
  if '[QueryHash]' in match[1]:mutations.append(source[:match.start()]+match[0].replace('[QueryHash]','[BrokenHash]',1)+source[match.end():])
 for altered in mutations:
  if not findings(altered):raise AssertionError('undetected mutation')
 return len(mutations)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--repository-root',type=Path,required=True);p.add_argument('--self-test',action='store_true');a=p.parse_args()
 source=(a.repository_root.resolve()/PROCEDURE_PATH).read_text(encoding='utf-8-sig');errors=findings(source)
 if errors:print('QueryStats contract failed: '+', '.join(errors),file=sys.stderr);return 1
 count=self_test(source) if a.self_test else 0
 print(f'QueryStats contract passed: tables=3 fields=73 result=60 raw_json=59 texts=13 mutations={count}');return 0
if __name__=='__main__':raise SystemExit(main())
