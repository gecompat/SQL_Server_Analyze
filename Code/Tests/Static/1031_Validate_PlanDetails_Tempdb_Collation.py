#!/usr/bin/env python3
"""Validate PlanDetails literal work-table, ABI and shared consumer boundaries."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys
PROCEDURE_PATH = Path("Code/04_PlanCache/040_USP_PlanDetails.sql")
TABLES = {'#PlanDetails_ResultTableMap': [('ResultName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL'), ('TargetTable', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL')], '#PlanDetails_SessionIdFilter': [('SessionId', 'smallint NOT NULL PRIMARY KEY')], '#PlanDetails_Candidate': [('CandidateId', 'int IDENTITY(1,1) PRIMARY KEY'), ('SessionId', 'smallint NULL'), ('RequestId', 'int NULL'), ('PlanHandle', 'varbinary(64) NULL'), ('SqlHandle', 'varbinary(64) NULL'), ('QueryHash', 'binary(8) NULL'), ('QueryPlanHash', 'binary(8) NULL'), ('StatementStartOffset', 'int NULL'), ('StatementEndOffset', 'int NULL'), ('CreationTime', 'datetime NULL'), ('LastExecutionTime', 'datetime NULL'), ('ExecutionCount', 'bigint NULL')], '#PlanDetails_Attributes': [('CandidateId', 'int'), ('AttributeName', 'varchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS'), ('AttributeValue', 'nvarchar(4000) COLLATE SQL_Latin1_General_CP1_CS_AS'), ('IsCacheKey', 'bit')], '#PlanDetails_Plans': [('CandidateId', 'int'), ('SourceType', 'varchar(24) COLLATE SQL_Latin1_General_CP1_CS_AS'), ('StatusCode', 'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS'), ('DatabaseId', 'int NULL'), ('ObjectId', 'int NULL'), ('IsEncrypted', 'bit NULL'), ('QueryPlanXml', 'xml NULL'), ('QueryPlanText', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('ErrorNumber', 'int NULL'), ('ErrorMessage', 'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL')], '#PlanDetails_CandidatesOutput': [('CandidateId', 'int'), ('SessionId', 'smallint NULL'), ('RequestId', 'int NULL'), ('PlanHandle', 'varbinary(64) NULL'), ('SqlHandle', 'varbinary(64) NULL'), ('QueryHash', 'binary(8) NULL'), ('QueryPlanHash', 'binary(8) NULL'), ('StatementStartOffset', 'int NULL'), ('StatementEndOffset', 'int NULL'), ('CreationTime', 'datetime NULL'), ('LastExecutionTime', 'datetime NULL'), ('ExecutionCount', 'bigint NULL'), ('StatementTextCharacters', 'bigint NULL'), ('StatementTextBytes', 'bigint NULL'), ('StatementTextIsTruncated', 'bit NOT NULL DEFAULT(0)'), ('StatementText', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('BatchTextCharacters', 'bigint NULL'), ('BatchTextBytes', 'bigint NULL'), ('BatchTextIsTruncated', 'bit NOT NULL DEFAULT(0)'), ('BatchText', 'nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('SqlTextDatabaseId', 'int NULL'), ('SqlTextDatabaseName', 'sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL'), ('SqlTextObjectId', 'int NULL')]}
ABI = "      @SessionIds            nvarchar(max)  = NULL\n    , @PlanHandle            varbinary(64)  = NULL\n    , @SqlHandle             varbinary(64)  = NULL\n    , @QueryHash             binary(8)      = NULL\n    , @MitPlanAttributes     bit            = 1\n    , @MitCompilePlan        bit            = 1\n    , @MitTextPlan           bit            = 0\n    , @MitLastActualPlan     bit            = 0\n    , @MitLivePlan           bit            = 0\n    , @MaxAnalyseobjekte      int            = 20\n    , @HighImpactConfirmed   bit            = 0\n    , @MaxSqlTextZeichen     int            = 8000\n    , @ResultSetArt          varchar(16)    = 'CONSOLE'\n    , @ResultTablesJson               nvarchar(max) = NULL\n    , @JsonErzeugen          bit            = 0\n    , @Json                   nvarchar(max)  = NULL OUTPUT\n    , @PrintMeldungen        bit            = 1\n    , @Hilfe                 bit            = 0"

def norm(s: str) -> str:
    return re.sub(r"\s+", "", s).lower()

def findings(s: str) -> list[str]:
    errors=[]
    matches=re.findall(r"CREATE\s+TABLE\s+\[(#PlanDetails_\w+)\]\s*\((.*?)\);",s,re.S|re.I)
    if len(matches)!=6: errors.append("TABLE_COUNT")
    for name,expected in TABLES.items():
        bodies=[b for n,b in matches if n==name]
        fields=[] if len(bodies)!=1 else [(n,norm(d)) for n,d in re.findall(r"\[(\w+)\]\s+(.+?)(?=,\s*\[|$)",bodies[0].strip(),re.S)]
        if fields!=[(n,norm(d)) for n,d in expected]: errors.append("DDL:"+name)
    abi=re.search(r"CREATE OR ALTER PROCEDURE.*?\n(.*?)\nAS",s,re.S)
    if abi is None or norm(abi.group(1))!=norm(ABI): errors.append("ABI")
    required=(
        "DECLARE @ProjectionMaxCharacters int=CASE WHEN @MaxSqlTextZeichen<0 THEN 0 ELSE @MaxSqlTextZeichen END;",
        "IF @MaxAnalyseobjekte<0 OR @MaxSqlTextZeichen < 0",
        "@ParameterValue=@MaxSqlTextZeichen", "@AllowedResultNames=N'candidates|attributes|plans'",
        "IF @TableResultRequested=0 AND NULLIF", "@ThrowOnError=1",
        "IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE'",
        "WHEN @MaxAnalyseobjekte IS NULL OR @MaxAnalyseobjekte=0",
        "IF @StatusCode='AVAILABLE' AND @EffectiveMaxAnalyseobjekte>20",
        "@AnalysisClass='PLAN_CACHE_DEEP'", "GROUP BY [NumberValue]",
        "SELECT @RowCount=COUNT_BIG(*) FROM [#PlanDetails_Candidate]",
        "ORDER BY [qs].[total_worker_time] DESC", "ORDER BY [CandidateId]",
        "IF @StatusCode='AVAILABLE' AND @MitPlanAttributes=1",
        "IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitCompilePlan=1",
        "IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitTextPlan=1",
        "IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLastActualPlan=1",
        "IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLivePlan=1",
        "IF @SingleSessionId IS NULL", "sys.dm_exec_query_plan_stats", "dm_exec_query_statistics_xml",
        "COALESCE([c].[StatementStartOffset],0),COALESCE([c].[StatementEndOffset],-1)",
        "OUTER APPLY [monitor].[TVF_StatementText]", "INCLUDE_NULL_VALUES", "N'PlanDetails' [resultName],1 [schemaVersion]",
        "WHEN N'candidates' THEN N'#PlanDetails_CandidatesOutput'",
        "WHEN N'attributes' THEN N'#PlanDetails_Attributes'", "WHEN N'plans' THEN N'#PlanDetails_Plans'",
        "@SourceTable=@TableSource,@TargetTable=@TableTarget,@ThrowOnError=1",
        "@SourceTable=N'#PlanDetails_CandidatesOutput'", "@EmptyMessage=N'Keine fachlichen Ergebnisse'")
    for token in required:
        if norm(token) not in norm(s): errors.append("BOUNDARY:"+token)
    project=list(re.finditer(r"EXEC \[monitor\]\.\[InternalProjectUnicodeTextColumn\](.*?);",s,re.S))
    if len(project)!=2: errors.append("PROJECTIONS")
    for m,col in zip(project,("StatementText","BatchText")):
        if f"@TextColumn=N'{col}'" not in m.group(1) or "@MaxCharacters=@ProjectionMaxCharacters" not in m.group(1): errors.append("PROJECT:"+col)
    prepare=s.find("EXEC [monitor].[InternalPrepareResultTables]")
    if not (0<prepare<s.find("IF @Hilfe=1")<s.find("IF @MaxAnalyseobjekte<0")): errors.append("EARLY_MAP")
    if len(re.findall(r"SELECT \* FROM \[#PlanDetails_CandidatesOutput\]",s))!=2: errors.append("CANDIDATES_SHARED")
    if len(re.findall(r"SELECT \* FROM \[#PlanDetails_Attributes\]",s))!=2: errors.append("ATTRIBUTES_SHARED")
    if "CONVERT(nvarchar(max),[QueryPlanXml]) [QueryPlanXml]" not in s: errors.append("XML_JSON")
    return errors

def self_test(s: str) -> int:
    mutations=[]
    for table,fields in TABLES.items():
        b=re.search(r"CREATE TABLE \["+re.escape(table)+r"\]\s*\((.*?)\);",s,re.S).group(1)
        for name,d in fields:
            pattern=r"\["+name+r"\]\s+"+re.escape(d).replace(r"\ ",r"\s+")
            # All literal field definitions are matched against their exact local body.
            m=re.search(r"\["+name+r"\]\s+(.+?)(?=,\s*\[|$)",b,re.S)
            for replacement in (f"[Broken{name}] {d}",f"[{name}] sql_variant NULL",f"[{name}] {d} DEFAULT(4242)"):
                changed=b[:m.start()]+replacement+b[m.end():]
                mutations.append(s.replace(b,changed,1))
            if "COLLATE" in d:
                changed=b[:m.start()]+m.group(0).replace("SQL_Latin1_General_CP1_CS_AS","DATABASE_DEFAULT")+b[m.end():]
                mutations.append(s.replace(b,changed,1))
    for m in re.finditer(r"@(\w+)\s+(\w+(?:\([^)]*\))?)\s*=\s*([^\n]+)",ABI):
        for old,new in ((m.group(1),"Broken"+m.group(1)),(m.group(2),"sql_variant"),(m.group(3),"4242")):
            a=ABI[:m.start()]+ABI[m.start():m.end()].replace(old,new,1)+ABI[m.end():]
            mutations.append(s.replace(ABI,a,1))
    mutations.append(s.replace("= NULL OUTPUT","= NULL",1))
    mutations.append(s.replace(ABI,ABI.replace("@SessionIds", "@SessionIdsSwap").replace("@PlanHandle", "@SessionIds").replace("@SessionIdsSwap", "@PlanHandle"),1))
    for old,new in (
        ("WHEN @MaxSqlTextZeichen<0 THEN 0","WHEN @MaxSqlTextZeichen<0 THEN @MaxSqlTextZeichen"),
        ("@ParameterValue=@MaxSqlTextZeichen","@ParameterValue=@ProjectionMaxCharacters"),
        ("@AllowedResultNames=N'candidates|attributes|plans'","@AllowedResultNames=N'candidates'"),
        ("@AnalysisClass='PLAN_CACHE_DEEP'","@AnalysisClass='BROKEN'"),
        ("IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitCompilePlan=1","IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitCompilePlan=0"),("IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitTextPlan=1","IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitTextPlan=0"),
        ("IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLastActualPlan=1","IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLastActualPlan=0"),("IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLivePlan=1","IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLivePlan=0"),
        ("IF @SingleSessionId IS NULL","IF 1=0"),
        ("WHEN @MaxAnalyseobjekte IS NULL OR @MaxAnalyseobjekte=0","WHEN @MaxAnalyseobjekte=0"),
        ("GROUP BY [NumberValue]","GROUP BY [IsValid]"),
        ("CONVERT(nvarchar(max),[QueryPlanXml]) [QueryPlanXml]","CONVERT(nvarchar(max),[QueryPlanText]) [QueryPlanXml]"),
        ("WHEN N'attributes' THEN N'#PlanDetails_Attributes'","WHEN N'attributes' THEN N'#PlanDetails_Plans'"),
        ("WHEN N'plans' THEN N'#PlanDetails_Plans'","WHEN N'plans' THEN N'#PlanDetails_Attributes'")):
        if old not in s: raise AssertionError("Mutation target: "+old)
        mutations.append(s.replace(old,new,1))
    for m in re.finditer(r"@MaxCharacters=@ProjectionMaxCharacters",s):
        mutations.append(s[:m.start()]+"@MaxCharacters=@MaxSqlTextZeichen"+s[m.end():])
    for m in re.finditer(r"SELECT \* FROM \[#PlanDetails_(?:CandidatesOutput|Attributes)\]",s):
        mutations.append(s[:m.start()]+m.group(0).replace("#PlanDetails_","#Broken_")+s[m.end():])
    for index,altered in enumerate(mutations):
        if altered==s or not findings(altered): raise AssertionError("Undetected mutation: "+str(index))
    return len(mutations)

def main() -> int:
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--repository-root",type=Path,required=True);p.add_argument("--self-test",action="store_true");a=p.parse_args()
    s=(a.repository_root/PROCEDURE_PATH).read_text(encoding="utf-8-sig")
    errors=findings(s)
    if errors: print("PlanDetails contract failed: "+", ".join(errors),file=sys.stderr);return 1
    n=self_test(s) if a.self_test else 0
    print(f"PlanDetails contract passed: tables=6 fields=52 text_collations=11 export_fields=37 ABI=18 mutations={n}");return 0
if __name__=="__main__":raise SystemExit(main())
