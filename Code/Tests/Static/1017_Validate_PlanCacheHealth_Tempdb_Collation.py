#!/usr/bin/env python3
"""Validate the existing PlanCacheHealth schemas, ABI and consumer contracts."""
from __future__ import annotations
import argparse
import re
from pathlib import Path

PROCEDURE = 'Code/04_PlanCache/030_USP_PlanCacheHealth.sql'
CS = 'COLLATE SQL_Latin1_General_CP1_CS_AS'
TABLES = {
 '#PlanCacheHealth_Summary': [f'[CacheObjectType] nvarchar(34) {CS}',f'[ObjectType] nvarchar(16) {CS}','[PlanCount] bigint','[TotalSizeBytes] bigint','[SingleUsePlanCount] bigint','[SingleUseSizeBytes] bigint','[TotalUseCounts] bigint','[AverageUseCount] decimal(19,4)'],
 '#PlanCacheHealth_Db': ['[DatabaseId] int NULL',f'[DatabaseName] sysname {CS} NULL','[PlanCount] bigint','[TotalSizeBytes] bigint','[SingleUsePlanCount] bigint'],
 '#PlanCacheHealth_Single': ['[PlanHandle] varbinary(64)',f'[CacheObjectType] nvarchar(34) {CS}',f'[ObjectType] nvarchar(16) {CS}','[UseCounts] int','[SizeBytes] int','[DatabaseId] int NULL',f'[DatabaseName] sysname {CS} NULL','[SqlTextCharacters] bigint NULL','[SqlTextBytes] bigint NULL','[SqlTextIsTruncated] bit NOT NULL DEFAULT(0)',f'[SqlText] nvarchar(max) {CS}']
}
PARAMETERS = [('AnalyseModus','varchar(16)',"'SUMMARY'",False),('MitDatenbankVerteilung','bit','0',False),('MitSingleUseDetails','bit','0',False),('MaxZeilen','int','100',False),('HighImpactConfirmed','bit','0',False),('MaxSqlTextZeichen','int','4000',False),('ResultSetArt','varchar(16)',"'CONSOLE'",False),('ResultTablesJson','nvarchar(max)','NULL',False),('JsonErzeugen','bit','0',False),('Json','nvarchar(max)','NULL',True),('PrintMeldungen','bit','1',False),('Hilfe','bit','0',False)]
ROUTES = [
 "IF @TableResultRequested=1 EXEC [monitor].[InternalPrepareSingleResultTable] @ResultTablesJson=@ResultTablesJson,@ResultName=N'overview',@TargetTable=@TableTarget OUTPUT,@ThrowOnError=1;",
 "IF @TableResultRequested = 1 OR @ConsoleResultRequested = 1 SET @ResultSetArtNormalisiert = 'NONE';",
 'CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN CONVERT(bigint,9223372036854775807) ELSE CONVERT(bigint,@MaxZeilen) END',
 "IF @StatusCode='AVAILABLE' AND (@AnalyseModus='VOLL' OR @MitDatenbankVerteilung=1 OR @MitSingleUseDetails=1)",
 "@AnalysisClass='PLAN_CACHE_DEEP',@HighImpactConfirmed=@HighImpactConfirmed",
 "IF @StatusCode='AVAILABLE' AND @AnalyseModus='SUMMARY' AND (@MitDatenbankVerteilung=1 OR @MitSingleUseDetails=1)",
 'GROUP BY [cp].[cacheobjtype],[cp].[objtype] OPTION(MAXDOP 1);',
 "SET @RowCount=@@ROWCOUNT;SET @Detail=N'Plan-Cache-Zusammenfassung erfolgreich.';",
 "IF @StatusCode IN('AVAILABLE','PARTIAL') AND @MitSingleUseDetails=1",
 'SELECT TOP (@EffectiveMaxZeilen) [cp].[plan_handle],[cp].[cacheobjtype],[cp].[objtype],[cp].[usecounts],[cp].[size_in_bytes]',
 'WHERE [cp].[usecounts]<=1 ORDER BY [cp].[size_in_bytes] DESC',
 "@SourceTable=N'#PlanCacheHealth_Single',@TextColumn=N'SqlText'",
 "@IsTruncatedColumn=N'SqlTextIsTruncated',@MaxCharacters=@MaxSqlTextZeichen",
 'SELECT * FROM [#PlanCacheHealth_Summary] ORDER BY [TotalSizeBytes] DESC,[PlanCount] DESC;',
 'SELECT * FROM [#PlanCacheHealth_Db] ORDER BY [TotalSizeBytes] DESC,[PlanCount] DESC;',
 'SELECT * FROM [#PlanCacheHealth_Single] ORDER BY [SizeBytes] DESC,[PlanHandle];',
 "@SourceTable=N'#PlanCacheHealth_Summary' , @ResultLabel=N'PlanCacheHealth'",
 "@SourceTable = N'#PlanCacheHealth_Summary' , @TargetTable=@TableTarget",
 'FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES',
 'SELECT * FROM [#PlanCacheHealth_Summary] ORDER BY [TotalSizeBytes] DESC,[PlanCount] DESC FOR JSON PATH,INCLUDE_NULL_VALUES',
 'SELECT * FROM [#PlanCacheHealth_Db] ORDER BY [TotalSizeBytes] DESC,[PlanCount] DESC FOR JSON PATH,INCLUDE_NULL_VALUES',
 'SELECT * FROM [#PlanCacheHealth_Single] ORDER BY [SizeBytes] DESC,[PlanHandle] FOR JSON PATH,INCLUDE_NULL_VALUES',
 "N',\"warnings\":[]}'",
]

def clean(text: str) -> str:
    lexical_pattern = re.compile(r"'(?:''|[^'])*'|\[(?:\]\]|[^\]])*\]|--[^\n]*|/\*.*?\*/",re.S)
    return lexical_pattern.sub(lambda m:' ' if m[0].startswith(('--','/*')) else m[0],text)

def compact(text: str) -> str:
    return re.sub(r'\s+',' ',text.strip())

def ddls(text: str) -> list[tuple[str,list[str]]]:
    # DDL inside a documentation literal is not executable table creation.
    text = re.sub(r"'(?:''|[^'])*'", lambda m: ' ' * len(m[0]), text)
    result=[]
    for m in re.finditer(r'CREATE\s+TABLE\s+\[(#[^\]]+)\]\s*\(',text):
        depth,start,i,fields=1,m.end(),m.end(),[]
        while i<len(text) and depth:
            if text[i]=='(': depth+=1
            elif text[i]==')':
                depth-=1
                if not depth: fields.append(compact(text[start:i]))
            elif text[i]==',' and depth==1:
                fields.append(compact(text[start:i]));start=i+1
            i+=1
        result.append((m[1],fields))
    return result

def findings(raw: str) -> list[str]:
    text=clean(raw);s=compact(text);errors=[]
    if ddls(text)!=list(TABLES.items()): errors.append('LOCAL_DDL_24_7: ordered table/field/type/null/collation/noidentity contract')
    m=re.search(r'CREATE OR ALTER PROCEDURE \[monitor\]\.\[USP_PlanCacheHealth\](.*?)\bAS\s+BEGIN',text,re.S)
    actual=[] if m is None else [(a[1],a[2],a[3],bool(a[4])) for a in re.finditer(r"@(\w+)\s+(\w+(?:\([^)]*\))?)\s*=\s*('[^']*'|NULL|\d+)(\s+OUTPUT)?",m[1])]
    if actual!=PARAMETERS: errors.append('ABI_12')
    for i,r in enumerate(ROUTES):
        expected = 2 if r == 'FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES' else 1
        if s.count(compact(r)) != expected: errors.append(f'ROUTE_{i}')
    positions=[s.find(x) for x in ['EXEC [monitor].[InternalPrepareSingleResultTable]','IF @Hilfe=1','IF @AnalyseModus NOT IN','INSERT [#PlanCacheHealth_Summary]']]
    if min(positions)<0 or positions!=sorted(positions): errors.append('PREFLIGHT_PRIORITY')
    positions=[s.find(x) for x in ['SELECT TOP (@EffectiveMaxZeilen)','EXEC [monitor].[InternalProjectUnicodeTextColumn]','EXEC [monitor].[InternalEmitTruncationWarning]',"IF @ResultSetArtNormalisiert<>'NONE'"]]
    if min(positions)<0 or positions!=sorted(positions): errors.append('DETAIL_TOP_BEFORE_TEXT')
    if len(re.findall(r'TOP\s*\(\s*@EffectiveMaxZeilen\s*\)',text))!=1: errors.append('ONLY_SINGLE_USE_CAP')
    return errors

def self_test(raw: str) -> int:
    assert not findings(raw),findings(raw)
    mutations=[]
    for name,fields in TABLES.items():
        begin=raw.index('CREATE TABLE ['+name+']')
        for field in fields:
            offset=raw.index(field,begin)
            def change(value: str) -> str: return raw[:offset]+value+raw[offset+len(field):]
            mutations.extend([change(field.replace(']','Changed]',1)),change(field.replace(field.split()[1],'sql_variant',1)),change(field+' IDENTITY(1,1)'),change(field.replace(' NOT NULL',' NULL') if ' NOT NULL' in field else field.replace(' NULL',' NOT NULL') if ' NULL' in field else field+' NOT NULL')])
            if CS in field:
                mutations.extend([change(field.replace(CS,'COLLATE Latin1_General_100_CI_AS')),change(field.replace(CS,''))+'\n-- '+field,change(field.replace(CS,''))+"\nDECLARE @ExampleCopy nvarchar(max)=N'"+field+"';"])
            if '(' in field.split()[1]: mutations.append(change(re.sub(r'\([^)]*\)','(1)',field,count=1)))
        mutations.append(raw+'\nCREATE TABLE ['+name+']('+','.join(fields)+');')
        definition = re.search(r'CREATE TABLE \['+re.escape(name)+r'\]\(.*?\);',raw,re.S)
        assert definition
        literal = "DECLARE @ExampleDdl nvarchar(max)=N'"+definition[0].replace("'","''")+"';"
        mutations.append(raw[:definition.start()]+literal+raw[definition.end():])
        mutations.append(raw[:definition.start()]+'/* '+definition[0]+' */'+raw[definition.end():])
        mutations.append(raw[:begin]+raw[begin:].replace(fields[0]+','+fields[1],fields[1]+','+fields[0],1))
    for name,typ,default,output in PARAMETERS:
        match=re.search(r'@'+name+r'\s+'+re.escape(typ)+r'\s*=\s*'+re.escape(default)+(r'\s+OUTPUT' if output else ''),raw)
        assert match
        values=[match[0].replace('@'+name,'@ExampleChanged',1),match[0].replace(typ,'sql_variant',1),re.sub(r'=\s*'+re.escape(default),'= '+('NULL' if default!='NULL' else '0'),match[0]),match[0].replace(' OUTPUT','') if output else match[0]+' OUTPUT']
        mutations.extend(raw[:match.start()]+v+raw[match.end():] for v in values)
    m=re.search(r'(\s+@AnalyseModus[^\n]*\n)(\s*, @MitDatenbankVerteilung[^\n]*\n)',raw)
    assert m
    mutations.append(raw[:m.start()]+m[2].replace(', @','@',1)+m[1].replace('@AnalyseModus',', @AnalyseModus',1)+raw[m.end():])
    for route in ROUTES:
        match=re.search(r'\s+'.join(re.escape(p) for p in compact(route).split(' ')),raw)
        assert match,route
        mutations.append(raw[:match.start()]+'/* deleted route */'+raw[match.end():])
    for table in ['Summary','Db']:
        mutations.append(raw.replace('SELECT * FROM [#PlanCacheHealth_'+table+']','SELECT TOP (@EffectiveMaxZeilen) * FROM [#PlanCacheHealth_'+table+']',1))
    for i,mutation in enumerate(mutations):
        assert mutation!=raw,f'Unchanged mutation {i}'
        assert findings(mutation),f'Accepted mutation {i}'
    return len(mutations)

def main() -> int:
    p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,required=True);p.add_argument('--self-test',action='store_true');a=p.parse_args()
    raw=(a.repository_root/PROCEDURE).read_text(encoding='utf-8-sig');errors=findings(raw)
    if errors: print('PlanCacheHealth failed: '+'; '.join(errors));return 1
    if a.self_test: print(f'PlanCacheHealth self-test passed ({self_test(raw)} real mutations).')
    else: print('PlanCacheHealth passed (24 fields,7 text collations,12 parameters).')
    return 0
if __name__=='__main__': raise SystemExit(main())
