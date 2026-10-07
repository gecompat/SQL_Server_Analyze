#!/usr/bin/env python3
"""Protect the Replica Analysis ABI, explicit text boundaries and bounded invalid-TABLE contract."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys

PROCEDURE_PATH = Path("Code/05_QueryStore/100_USP_QueryStoreReplicaAnalysis.sql")
COLLATION = "SQL_Latin1_General_CP1_CS_AS"
SCHEMAS = {'Replicas': 'CapturedAtUtc datetime2(3) NOT NULL\nDatabaseId int NOT NULL\nDatabaseName sysname NOT NULL\nCurrentQueryStoreStateDesc nvarchar(60) NULL\nCurrentConnectionRoleDesc varchar(40) NOT NULL\nReplicaGroupId bigint NOT NULL\nRoleType tinyint NULL\nRoleTypeDesc varchar(40) NOT NULL\nRoleClass varchar(24) NOT NULL\nReplicaName nvarchar(4000) NULL\nIsPrimaryRole bit NOT NULL\nIsSecondaryRole bit NOT NULL\nIsNamedReplica bit NOT NULL\nStatusCode varchar(40) NOT NULL\nEvidenceLimit nvarchar(1000) NOT NULL', 'RuntimeByReplica': 'CapturedAtUtc datetime2(3) NOT NULL\nDatabaseId int NOT NULL\nDatabaseName sysname NOT NULL\nCurrentConnectionRoleDesc varchar(40) NOT NULL\nReplicaGroupId bigint NULL\nRoleType tinyint NULL\nRoleTypeDesc varchar(40) NOT NULL\nRoleClass varchar(24) NOT NULL\nReplicaName nvarchar(4000) NULL\nMappingStatusCode varchar(40) NOT NULL\nRecordedRows bigint NOT NULL\nQueryCount bigint NOT NULL\nPlanCount bigint NOT NULL\nExecutionCount bigint NOT NULL\nFirstExecutionTimeUtc datetimeoffset NULL\nLastExecutionTimeUtc datetimeoffset NULL\nTotalDurationMs decimal(38,3) NULL\nTotalCpuMs decimal(38,3) NULL\nTotalLogicalReads decimal(38,3) NULL\nTotalLogicalWrites decimal(38,3) NULL\nEvidenceLimit nvarchar(1000) NOT NULL', 'WaitsByReplica': 'CapturedAtUtc datetime2(3) NOT NULL\nDatabaseId int NOT NULL\nDatabaseName sysname NOT NULL\nCurrentConnectionRoleDesc varchar(40) NOT NULL\nReplicaGroupId bigint NULL\nRoleType tinyint NULL\nRoleTypeDesc varchar(40) NOT NULL\nRoleClass varchar(24) NOT NULL\nReplicaName nvarchar(4000) NULL\nMappingStatusCode varchar(40) NOT NULL\nExecutionTypeDesc nvarchar(128) NULL\nWaitCategory tinyint NULL\nWaitCategoryDesc nvarchar(128) NULL\nRecordedRows bigint NOT NULL\nFirstIntervalStartUtc datetimeoffset NULL\nLastIntervalEndUtc datetimeoffset NULL\nTotalQueryWaitTimeMs bigint NULL\nMaxQueryWaitTimeMs bigint NULL\nEvidenceLimit nvarchar(1000) NOT NULL', 'ForcingByReplica': 'CapturedAtUtc datetime2(3) NOT NULL\nDatabaseId int NOT NULL\nDatabaseName sysname NOT NULL\nCurrentConnectionRoleDesc varchar(40) NOT NULL\nReplicaGroupId bigint NULL\nRoleType tinyint NULL\nRoleTypeDesc varchar(40) NOT NULL\nRoleClass varchar(24) NOT NULL\nReplicaName nvarchar(4000) NULL\nMappingStatusCode varchar(40) NOT NULL\nForcingLocationCount bigint NOT NULL\nForcedQueryCount bigint NOT NULL\nForcedPlanCount bigint NOT NULL\nEvidenceLimit nvarchar(1000) NOT NULL', 'SourceStatus': 'SourceOrdinal int NOT NULL\nDatabaseId int NULL\nDatabaseName sysname NULL\nSourceName sysname NOT NULL\nSourceObject nvarchar(256) NOT NULL\nCapturedAtUtc datetime2(3) NOT NULL\nStatusCode varchar(40) NOT NULL\nIsPartial bit NOT NULL\nReturnedRowCount bigint NOT NULL\nRequiredPermission nvarchar(256) NULL\nErrorNumber int NULL\nErrorMessage nvarchar(2048) NULL\nEvidenceLimit nvarchar(1000) NOT NULL', 'Warnings': 'WarningOrdinal int NOT NULL\nDatabaseName sysname NULL\nSourceName sysname NOT NULL\nStatusCode varchar(40) NOT NULL\nErrorNumber int NULL\nMessage nvarchar(2048) NOT NULL', 'ModuleStatus': 'ModuleName sysname NOT NULL\nCapturedAtUtc datetime2(3) NOT NULL\nStatusCode varchar(40) NOT NULL\nIsPartial bit NOT NULL\nProductMajorVersion int NULL\nCrossDatabaseRequested bit NOT NULL\nDatabaseCount int NOT NULL\nReplicaRowCount bigint NOT NULL\nRuntimeRowCount bigint NOT NULL\nWaitRowCount bigint NOT NULL\nForcingRowCount bigint NOT NULL\nHasMoreReplicaRows bit NOT NULL\nHasMoreRuntimeRows bit NOT NULL\nHasMoreWaitRows bit NOT NULL\nHasMoreForcingRows bit NOT NULL\nErrorNumber int NULL\nErrorMessage nvarchar(2048) NULL', 'ResultTableMap': 'ResultName sysname NOT NULL\nTargetTable sysname NOT NULL', 'DatabaseCandidates': 'DatabaseId int NOT NULL\nDatabaseName sysname NOT NULL\nStateDesc nvarchar(60) NULL\nUserAccessDesc nvarchar(60) NULL\nIsReadOnly bit NULL\nCompatibilityLevel tinyint NULL\nCollationName sysname NULL\nRecoveryModelDesc nvarchar(60) NULL\nIsSystemDatabase bit NULL\nRequestedOrdinal int NULL', 'CandidateWarnings': 'RequestedName sysname NULL\nStatusCode varchar(40) NOT NULL\nErrorMessage nvarchar(2048) NULL', 'ReplicaFilter': 'ItemOrdinal int NOT NULL\nReplicaGroupId bigint NULL\nIsValid bit NOT NULL'}

PUBLIC = ("Replicas", "RuntimeByReplica", "WaitsByReplica", "ForcingByReplica", "SourceStatus", "Warnings", "ModuleStatus")
RESULT_NAMES = ("replicas", "runtimeByReplica", "waitsByReplica", "forcingByReplica", "sourceStatus", "warnings", "moduleStatus")

def validate(source: str) -> list[str]:
    errors=[]
    for suffix, literal in SCHEMAS.items():
        name="#QueryStoreReplicaAnalysis_"+suffix
        match=re.search(r"CREATE\s+TABLE\s+\["+re.escape(name)+r"\]\s*\((.*?)\);",source,re.I|re.S)
        if not match:
            errors.append("Missing table "+name); continue
        actual=re.findall(r"^\s*(?:,\s*)?\[([^]]+)\]\s+([^\n]+)",match.group(1),re.M)
        expected=[line.split(" ",1) for line in literal.splitlines()]
        if len(actual)!=len(expected):
            errors.append("Field count "+name); continue
        for (field, declaration),(want, rest) in zip(actual,expected):
            nullable="NOT NULL" if rest.endswith(" NOT NULL") else "NULL"
            typ=rest[:-len(nullable)].strip()
            text=bool(re.match(r"(?:n?varchar|n?char|sysname)\b",typ,re.I))
            identity=" IDENTITY(1,1)" if field in ("SourceOrdinal","WarningOrdinal") else ""
            want_decl=typ+(" COLLATE "+COLLATION if text else "")+identity+" "+nullable
            got=re.sub(r"\s+"," ",declaration.strip()).removesuffix(" PRIMARY KEY").removesuffix(" UNIQUE")
            if field!=want or got.casefold()!=want_decl.casefold():
                errors.append(name+"."+want+" type/collation/nullability/identity/order")
    map_pos=source.find("EXEC [monitor].[InternalPrepareResultTables]")
    invalid=source.find("IF @MaxZeilen<0 OR @LockTimeoutMs")
    lock=source.find("EXEC [sys].[sp_executesql] @LockTimeoutSql;")
    if not (0<map_pos<invalid<lock): errors.append("TABLE preflight must precede semantic validation and LOCK_TIMEOUT")
    block=source[invalid:source.find("IF @StatusCode='AVAILABLE'",invalid)]
    if "IF @MaxZeilen<0 SET @Limit=0;" not in block: errors.append("Negative limit normalization")
    if "@StatusCode='INVALID_PARAMETER',@IsPartial=1" not in block: errors.append("Invalid rejection status")
    if source.count("IF @MaxZeilen<0 SET @Limit=0;")!=1: errors.append("Single negative normalization")
    for suffix in PUBLIC:
        if "EXEC [monitor].[InternalWriteResultTable] @SourceTable=N'#QueryStoreReplicaAnalysis_"+suffix+"'" not in source:
            errors.append("TABLE shared source "+suffix)
        if not re.search(r"SELECT \* FROM \[#QueryStoreReplicaAnalysis_"+suffix+r"\].*?FOR JSON PATH,INCLUDE_NULL_VALUES",source,re.S):
            errors.append("JSON shared source "+suffix)
        raw=source[source.find("IF @OutputMode='RAW'"):source.find("IF @OutputMode='TABLE'",source.find("IF @OutputMode='RAW'"))]
        if "SELECT * FROM [#QueryStoreReplicaAnalysis_"+suffix+"]" not in raw: errors.append("RAW shared source "+suffix)
    for name in RESULT_NAMES:
        statement="SET @TargetTable=(SELECT [TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'"+name+"');"
        if statement not in source: errors.append("Selective TABLE lookup "+name)
    if not re.search(r"EXEC \[monitor\].\[InternalEmitConsoleResult\]\s+@SourceTable=N'#QueryStoreReplicaAnalysis_ModuleStatus'",source): errors.append("CONSOLE module source")
    if "@ProductMajorVersion IS NULL OR @ProductMajorVersion<17" not in source: errors.append("Version boundary")
    if "@MaxZeilen IS NULL OR @MaxZeilen=0" not in source: errors.append("Unbounded contract")
    for token in ("@ReplicaCandidateCount>@Limit", "@RuntimeCandidateCount>@Limit", "@WaitCandidateCount>@Limit", "@ForcingCandidateCount>@Limit"):
        if token not in source: errors.append("Full candidate count "+token)
    return errors

def self_test(source: str) -> int:
    mutations=[]
    for suffix,literal in SCHEMAS.items():
        start=source.index("CREATE TABLE [#QueryStoreReplicaAnalysis_"+suffix+"]")
        end=source.index(");",start)+2
        body=source[start:end]
        for line in literal.splitlines():
            name,rest=line.split(" ",1)
            original=re.search(r"\["+re.escape(name)+r"\]\s+[^\n]+",body).group(0)
            changes=[original.replace("NOT NULL","NULL") if "NOT NULL" in original else original.replace(" NULL"," NOT NULL")]
            if "COLLATE "+COLLATION in original: changes.append(original.replace(" COLLATE "+COLLATION,""))
            changes.append(original.replace("["+name+"]","[ExampleChangedField]",1))
            typ=re.sub(r"\s+(?:NOT )?NULL$","",rest)
            replacement="nvarchar(128)" if typ=="sysname" else ("int" if typ=="bigint" else "bigint")
            changes.append(original.replace("] "+typ,"] "+replacement,1))
            for replacement in changes:
                mutations.append(source[:start]+body.replace(original,replacement,1)+source[end:])
    mutations.append(source.replace("IF @MaxZeilen<0 SET @Limit=0;","",1))
    mutations.append(source.replace("@StatusCode='INVALID_PARAMETER',@IsPartial=1","@StatusCode='AVAILABLE',@IsPartial=1",1))
    start=source.index("    IF @StatusCode='AVAILABLE' AND @OutputMode='TABLE'")
    end=source.index("\n\n",start)+2
    mapping=source[start:end]
    without=source[:start]+source[end:]
    pos=without.index("    IF @StatusCode='AVAILABLE'\n        EXEC [monitor].[USP_PrepareDatabaseCandidates]")
    mutations.append(without[:pos]+mapping+without[pos:])
    for suffix in PUBLIC:
        mutations.append(source.replace("@SourceTable=N'#QueryStoreReplicaAnalysis_"+suffix+"'","@SourceTable=N'#ExampleChangedSource'",1))
    for name in RESULT_NAMES:
        original="SET @TargetTable=(SELECT [TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'"+name+"');"
        replacement="SELECT @TargetTable=[TargetTable] FROM [#QueryStoreReplicaAnalysis_ResultTableMap] WHERE [ResultName]=N'"+name+"';"
        mutations.append(source.replace(original,replacement,1))
    raw_start=source.index("IF @OutputMode='RAW'")
    raw_end=source.index("IF @OutputMode='TABLE'",raw_start)
    for suffix in PUBLIC:
        raw=source[raw_start:raw_end]
        changed=raw.replace("FROM [#QueryStoreReplicaAnalysis_"+suffix+"]","FROM [#ExampleChangedSource]",1)
        mutations.append(source[:raw_start]+changed+source[raw_end:])
    for i,changed in enumerate(mutations):
        if not validate(changed):
            print(f"Mutation {i} survived",file=sys.stderr); return 1
    print(f"Replica Analysis validator self-test passed ({len(mutations)} real mutations).")
    return 0

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root",type=Path,required=True)
    parser.add_argument("--self-test",action="store_true")
    args=parser.parse_args()
    source=(args.repository_root/PROCEDURE_PATH).read_text(encoding="utf-8")
    errors=validate(source)
    if errors:
        print("\n".join(errors),file=sys.stderr); return 1
    if args.self_test: return self_test(source)
    print("Replica Analysis ABI/collation/invalid-TABLE validation passed.")
    return 0

if __name__=="__main__": raise SystemExit(main())
