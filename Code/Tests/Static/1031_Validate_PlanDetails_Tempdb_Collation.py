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
        "IF @ResolveCandidateDetails=1 AND @MitPlanAttributes=1",
        "IF @ResolveCandidateDetails=1 AND @MitCompilePlan=1",
        "IF @ResolveCandidateDetails=1 AND @MitTextPlan=1",
        "IF @ResolveCandidateDetails=1 AND @MitLastActualPlan=1",
        "IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLivePlan=1",
        "IF @SingleSessionId IS NULL", "sys.dm_exec_query_plan_stats", "dm_exec_query_statistics_xml",
        "COALESCE(@SourceStartOffset,0),COALESCE(@SourceEndOffset,-1)",
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
    isolation=s[s.find("    OPEN [CandidateSourceCursor]"):s.find("    IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLivePlan=1")]
    catches=re.findall(r"BEGIN TRY(.*?)END TRY BEGIN CATCH(.*?)END CATCH;",isolation,re.S)
    sources=("dm_exec_plan_attributes(@SourcePlanHandle)","dm_exec_query_plan(@SourcePlanHandle)",
             "dm_exec_text_query_plan(@SourcePlanHandle,COALESCE(@SourceStartOffset,0),COALESCE(@SourceEndOffset,-1))",
             "dm_exec_query_plan_stats(@SourcePlanHandle)","dm_exec_sql_text](COALESCE(@SourceSqlHandle,@SourcePlanHandle))")
    first="SET @IsPartial=1;IF @StatusCode IN('AVAILABLE','PARTIAL') SET @StatusCode='PARTIAL';IF @ErrorMessage IS NULL BEGIN SET @ErrorNumber=ERROR_NUMBER();SET @ErrorMessage=ERROR_MESSAGE();END;"
    if len(catches)!=5: errors.append("ISOLATED_SOURCE_COUNT")
    for i,(body,catch) in enumerate(catches):
        if i>=5 or norm(sources[i]) not in norm(body): errors.append("ISOLATED_SOURCE:"+str(i))
        key="WHERE [o].[CandidateId]=@SourceCandidateId;" if i==4 else "WHERE [c].[CandidateId]=@SourceCandidateId;"
        if norm(key) not in norm(body) or norm(first) not in norm(catch): errors.append("ISOLATED_KEY_FIRST_ERROR:"+str(i))
        if i in(1,2,3):
            source=("COMPILE_XML","COMPILE_TEXT","LAST_ACTUAL_XML")[i-1]
            value="VALUES(@SourceCandidateId,'"+source+"','ERROR_HANDLED',NULL,NULL,NULL,NULL,NULL,ERROR_NUMBER(),ERROR_MESSAGE());"
            if norm(value) not in norm(catch): errors.append("ISOLATED_ERROR_ROW:"+source)
        elif "INSERT [#PlanDetails_Plans]" in catch or "DELETE" in catch: errors.append("ISOLATED_FAILURE_PRESERVATION")
    raw=s.find("    INSERT [#PlanDetails_CandidatesOutput]")
    cursor=s.find("    DECLARE [CandidateSourceCursor]")
    text=s.find("        UPDATE [o]")
    warning=s.find("    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE')")
    if not(0<raw<cursor<text<s.find("InternalEmitTruncationWarning")<warning<s.find("    IF @ResultSetArtNormalisiert<>'NONE'")): errors.append("RAW_FIRST_WARNING_LAST")
    if "FROM [#PlanDetails_Candidate];" not in s[raw:cursor] or "[StatementText]" in s[raw:cursor]: errors.append("RAW_CANDIDATE_PRESERVATION")
    for token in ("@ResolveCandidateDetails bit=CASE WHEN @StatusCode IN('AVAILABLE','PARTIAL') THEN 1 ELSE 0 END",
                  "SELECT [CandidateId],[PlanHandle],[SqlHandle],[StatementStartOffset],[StatementEndOffset]",
                  "INTO @SourceCandidateId,@SourcePlanHandle,@SourceSqlHandle,@SourceStartOffset,@SourceEndOffset;",
                  "CLOSE [CandidateSourceCursor];DEALLOCATE [CandidateSourceCursor];"):
        if norm(token) not in norm(s): errors.append("CURSOR:"+token)
    if re.search(r"(?:DATALENGTH|LEN)\s*\([^)]*(?:PlanHandle|SqlHandle)",s,re.I): errors.append("HANDLE_LENGTH_WHITELIST")
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
        ("IF @ResolveCandidateDetails=1 AND @MitCompilePlan=1","IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitCompilePlan=0"),("IF @ResolveCandidateDetails=1 AND @MitTextPlan=1","IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitTextPlan=0"),
        ("IF @ResolveCandidateDetails=1 AND @MitLastActualPlan=1","IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLastActualPlan=0"),("IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLivePlan=1","IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLivePlan=0"),
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
    isolated=s[s.index("    OPEN [CandidateSourceCursor]"):s.index("    IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitLivePlan=1")]
    for m in re.finditer(r"BEGIN TRY(.*?)END TRY BEGIN CATCH(.*?)END CATCH;",isolated,re.S):
        for old,new in (("BEGIN TRY","BEGIN"),("IF @ErrorMessage IS NULL","IF 1=1"),
                        ("SET @StatusCode='PARTIAL'","SET @StatusCode='ERROR_HANDLED'"),
                        ("@SourceCandidateId;","@SourceCandidateId+1;")):
            block=m.group(0);changed=block.replace(old,new,1)
            if changed==block: raise AssertionError("Isolation mutation target: "+old)
            mutations.append(s.replace(block,changed,1))
        block=m.group(0)
        if "VALUES(@SourceCandidateId," in block: mutations.append(s.replace(block,block.replace("VALUES(@SourceCandidateId,","VALUES(NULL,",1),1))
    for old,new in (("@ResolveCandidateDetails bit=CASE WHEN @StatusCode IN('AVAILABLE','PARTIAL') THEN 1 ELSE 0 END","@ResolveCandidateDetails bit=1"),
                    ("dm_exec_plan_attributes(@SourcePlanHandle)","dm_exec_plan_attributes(@PlanHandle)"),
                    ("dm_exec_query_plan(@SourcePlanHandle)","dm_exec_query_plan(@PlanHandle)"),
                    ("dm_exec_query_plan_stats(@SourcePlanHandle)","dm_exec_query_plan_stats(@PlanHandle)"),
                    ("COALESCE(@SourceSqlHandle,@SourcePlanHandle)","@SourceSqlHandle"),
                    ("CLOSE [CandidateSourceCursor];DEALLOCATE [CandidateSourceCursor];","CLOSE [CandidateSourceCursor];")):
        mutations.append(s.replace(old,new,1))
    warning_start=s.index("    IF @PrintMeldungen=1 AND @StatusCode NOT IN('AVAILABLE')")
    warning_end=s.index("    IF @ResultSetArtNormalisiert<>'NONE'",warning_start)
    warning=s[warning_start:warning_end]
    moved=s[:warning_start]+s[warning_end:]
    mutations.append(moved.replace("    BEGIN TRY\n        UPDATE [o]",warning+"    BEGIN TRY\n        UPDATE [o]",1))
    raw_start=s.index("    INSERT [#PlanDetails_CandidatesOutput]")
    raw_end=s.index("    DECLARE @ResolveCandidateDetails",raw_start)
    raw=s[raw_start:raw_end];moved=s[:raw_start]+s[raw_end:]
    mutations.append(moved.replace("    DECLARE @TruncatedValueCount",raw+"    DECLARE @TruncatedValueCount",1))
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
