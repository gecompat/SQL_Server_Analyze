#!/usr/bin/env python3
"""Validate QueryHashAnalysis work-table ABI, shared output and snapshot/rank boundaries."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys

PROCEDURE_PATH = Path("Code/04_PlanCache/020_USP_QueryHashAnalysis.sql")
TABLES = {'#QueryHashAnalysis_Hash': [('QueryHash', 'binary(8) NOT NULL'), ('PlanVariantCount', 'int NOT NULL'), ('PlanHandleCount', 'int NOT NULL'), ('CompilationCount', 'bigint NOT NULL'), ('ExecutionCount', 'bigint NOT NULL'), ('TotalCpuUs', 'bigint NOT NULL'), ('TotalElapsedUs', 'bigint NOT NULL'), ('TotalReads', 'bigint NOT NULL'), ('TotalWrites', 'bigint NOT NULL'), ('TotalSpills', 'bigint NOT NULL'), ('MaxGrantKb', 'bigint NOT NULL'), ('FirstCreationTime', 'datetime NULL'), ('LastExecutionTime', 'datetime NULL'), ('SampleSqlHandle', 'varbinary(64) NULL'), ('SampleStartOffset', 'int NULL'), ('SampleEndOffset', 'int NULL')], '#QueryHashAnalysis_QueryStatsSource': [('query_hash', 'binary(8) NULL'), ('query_plan_hash', 'binary(8) NULL'), ('plan_handle', 'varbinary(64) NULL'), ('sql_handle', 'varbinary(64) NULL'), ('statement_start_offset', 'int NULL'), ('statement_end_offset', 'int NULL'), ('execution_count', 'bigint NULL'), ('total_worker_time', 'bigint NULL'), ('total_elapsed_time', 'bigint NULL'), ('total_logical_reads', 'bigint NULL'), ('total_logical_writes', 'bigint NULL'), ('total_spills', 'bigint NULL'), ('max_grant_kb', 'bigint NULL'), ('creation_time', 'datetime NULL'), ('last_execution_time', 'datetime NULL')], '#QueryHashAnalysis_Output': [('QueryHash', 'binary(8) NOT NULL'), ('PlanVariantCount', 'int NOT NULL'), ('PlanHandleCount', 'int NOT NULL'), ('CompilationCount', 'bigint NOT NULL'), ('ExecutionCount', 'bigint NOT NULL'), ('TotalCpuMs', 'decimal(38,3) NULL'), ('AvgCpuMs', 'decimal(38,3) NULL'), ('TotalElapsedMs', 'decimal(38,3) NULL'), ('AvgElapsedMs', 'decimal(38,3) NULL'), ('TotalReads', 'bigint NOT NULL'), ('AvgReads', 'decimal(38,3) NULL'), ('TotalWrites', 'bigint NOT NULL'), ('TotalSpills', 'bigint NOT NULL'), ('MaxGrantKb', 'bigint NOT NULL'), ('FirstCreationTime', 'datetime NULL'), ('LastExecutionTime', 'datetime NULL'), ('SampleStatementTextCharacters', 'bigint NULL'), ('SampleStatementTextBytes', 'bigint NULL'), ('SampleStatementTextIsTruncated', 'bit NOT NULL DEFAULT(0)'), ('SampleStatementText', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')]}

def normalized(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip()).lower()

def findings(source: str) -> list[str]:
    issues=[]
    for table, fields in TABLES.items():
        match=re.search(r"CREATE\s+TABLE\s+\["+re.escape(table)+r"\]\s*\((.*?)\);",source,re.I|re.S)
        actual=[] if match is None else [(n,normalized(d.rstrip(','))) for n,d in
            re.findall(r"\[(\w+)\]\s+(.+?)(?=,\s*\[|$)",match.group(1).strip(),re.S)]
        if actual!=[(n,normalized(d)) for n,d in fields]: issues.append("DDL:"+table)
    rank=re.search(r"\), R AS\s*\((.*?)\)\s*INSERT \[#QueryHashAnalysis_Hash\]",source,re.S|re.I)
    if rank is None or not re.search(r"ORDER BY \[rn\]\s*$",rank.group(1).strip(),re.I): issues.append("TOP_RANK_ORDER")
    for sort,field in (("CPU_TOTAL","TotalCpuUs"),("ELAPSED_TOTAL","TotalElapsedUs"),
        ("READS_TOTAL","TotalReads"),("WRITES_TOTAL","TotalWrites"),("EXECUTIONS","ExecutionCount"),
        ("PLAN_VARIANTS","PlanVariantCount"),("SPILLS_TOTAL","TotalSpills")):
        if rank is None or f"WHEN '{sort}' THEN [{field}]" not in rank.group(1): issues.append("RANK:"+sort)
    for token in (
        "[LastExecutionTime] DESC) AS [rn]",
        "HAVING SUM([qs].[execution_count])>=@MinExecutionCount AND COUNT(DISTINCT [qs].[query_plan_hash])>=@MinPlanVarianten",
        "FROM [#PlanCacheAnalysis_QueryStatsSnapshot]",
        "IF @ParentQueryStatsSnapshot=1",
        "IF @StatusCode='AVAILABLE' AND (@AnalyseModus='VOLL' OR @QueryHash IS NULL OR @EffectiveMaxZeilen>1000)",
        "@AnalysisClass='PLAN_CACHE_DEEP'",
        "WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807)",
        "@MaxZeilen<0", "@MaxSqlTextZeichen < 0", "@ParentQueryStatsSnapshot IS NULL",
        "SET @RowCount=@@ROWCOUNT", "COUNT_BIG(*) AS [CompilationCount]",
        "ORDER BY [qs].[total_worker_time] DESC", "OUTER APPLY [sys].[dm_exec_sql_text]",
        "OUTER APPLY [monitor].[TVF_StatementText]", "InternalEmitTruncationWarning",
        "COALESCE(@DataJson,N'[]')", "INCLUDE_NULL_VALUES"):
        if token not in source: issues.append("BOUNDARY:"+token)
    if not re.search(r"IF @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen >= 0\s+EXEC \[monitor\]\.\[InternalProjectUnicodeTextColumn\]",source):
        issues.append("NEGATIVE_TEXT_PROJECTION")
    for helper in ("InternalProjectUnicodeTextColumn","InternalEmitConsoleResult","InternalWriteResultTable"):
        helper_call=re.search(r"EXEC \[monitor\]\.\["+helper+r"\](.*?);",source,re.S)
        if helper_call is None or not re.search(r"@SourceTable\s*=\s*N'#QueryHashAnalysis_Output'",helper_call.group(1)):
            issues.append("SHARED:"+helper)
    if len(re.findall(r"SELECT \* FROM \[#QueryHashAnalysis_Output\]",source))!=2: issues.append("SHARED_RAW_JSON")
    return issues

def self_test(source: str) -> int:
    mutations=[]
    for table, fields in TABLES.items():
        body=re.search(r"CREATE TABLE \["+re.escape(table)+r"\]\s*\((.*?)\);",source,re.S).group(1)
        for name, definition in fields:
            for replacement in (f"[Broken{name}] {definition}",f"[{name}] sql_variant NULL",
                f"[{name}] "+definition.replace("NOT NULL","NULL") if "NOT NULL" in definition else f"[{name}] "+definition.replace("NULL","NOT NULL")):
                pattern=r"\["+name+r"\]\s+"+re.escape(definition).replace(r"\ ",r"\s+")
                changed,n=re.subn(pattern,lambda _:replacement,body,count=1)
                if n!=1: raise AssertionError("mutation target:"+table+"/"+name)
                mutations.append(source.replace(body,changed,1))
            if "COLLATE" in definition:
                mutations.append(source.replace(body,body.replace("COLLATE SQL_Latin1_General_CP1_CS_AS", "COLLATE DATABASE_DEFAULT",1),1))
    for old,new in (("ORDER BY [rn]",""),
        ("IF @MaxSqlTextZeichen IS NULL OR @MaxSqlTextZeichen >= 0", "IF 1=1"),
        ("FROM [#PlanCacheAnalysis_QueryStatsSnapshot]","FROM [#BrokenSnapshot]"),
        ("@AnalysisClass='PLAN_CACHE_DEEP'","@AnalysisClass='BROKEN'"),
        ("SET @RowCount=@@ROWCOUNT","SET @RowCount=0"),
        ("WHEN @MaxZeilen IS NULL OR @MaxZeilen=0", "WHEN @MaxZeilen=0"),
        ("HAVING SUM([qs].[execution_count])>=@MinExecutionCount", "HAVING 1=1")):
        if old not in source: raise AssertionError("mutation target:"+old)
        mutations.append(source.replace(old,new,1))
    for sort,field in (("CPU_TOTAL","TotalCpuUs"),("ELAPSED_TOTAL","TotalElapsedUs"),
        ("READS_TOTAL","TotalReads"),("WRITES_TOTAL","TotalWrites"),("EXECUTIONS","ExecutionCount"),
        ("PLAN_VARIANTS","PlanVariantCount"),("SPILLS_TOTAL","TotalSpills")):
        mutations.append(source.replace(f"WHEN '{sort}' THEN [{field}]",f"WHEN '{sort}' THEN [BrokenRank]",1))
    for helper in ("InternalProjectUnicodeTextColumn","InternalEmitConsoleResult","InternalWriteResultTable"):
        match=re.search(r"EXEC \[monitor\]\.\["+helper+r"\](.*?);",source,re.S)
        mutations.append(source[:match.start()]+match.group(0).replace("#QueryHashAnalysis_Output","#BrokenOutput")+source[match.end():])
    for match in re.finditer(r"SELECT \* FROM \[#QueryHashAnalysis_Output\]",source):
        mutations.append(source[:match.start()]+match.group(0).replace("#QueryHashAnalysis_Output","#BrokenOutput")+source[match.end():])
    for altered in mutations:
        if not findings(altered): raise AssertionError("undetected mutation")
    return len(mutations)

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root",type=Path,required=True)
    parser.add_argument("--self-test",action="store_true")
    args=parser.parse_args()
    source=(args.repository_root.resolve()/PROCEDURE_PATH).read_text(encoding="utf-8-sig")
    errors=findings(source)
    if errors:
        print("QueryHashAnalysis contract failed: "+", ".join(errors),file=sys.stderr); return 1
    count=self_test(source) if args.self_test else 0
    print(f"QueryHashAnalysis contract passed: tables=3 fields=51 output_fields=20 text_collations=1 mutations={count}")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
