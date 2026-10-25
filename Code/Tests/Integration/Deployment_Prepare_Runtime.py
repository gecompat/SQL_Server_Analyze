#!/usr/bin/env python3
"""Build a native synthetic deployment regression; never connect to a server.

The emitted SQL creates two explicitly named test databases only when neither
exists. It leaves its databases intact for inspection. Execute only in a
dedicated SQL Server test instance, for example the functional-impact CI job.
"""
from __future__ import annotations
import argparse
import importlib.util
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('deployment_generator', ROOT / 'Code/Install/deployment_generator.py')
g = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = g
spec.loader.exec_module(g)
FRAMEWORK = 'SQLServerAnalyzeDeploymentFramework'
TARGET = 'SQLServerAnalyzeDeploymentTarget'


def configured(sql, framework=FRAMEWORK, target=TARGET):
    return sql.replace("@FrameworkDatabase nvarchar(max)=N'DeineDatenbank'", '@FrameworkDatabase nvarchar(max)='+g.lit(framework), 1).replace('@SnapshotDatabase nvarchar(max)=NULL', '@SnapshotDatabase nvarchar(max)='+g.lit(target), 1)


def negative(sql, number, label, assert_sql=''):
    return (f"BEGIN TRY EXEC sys.sp_executesql {g.lit(sql)}; THROW 53800,{g.lit('Expected rejection: '+label)},1; END TRY\n"
            f"BEGIN CATCH IF ERROR_NUMBER()<>{number} THROW; END CATCH;\n{assert_sql}\nGO\n")


def binary_columns(table):
    return ','.join('CONVERT(varbinary(max),'+g.q(name)+') AS '+g.q(name) for name in table.columns)


def equal_rows(left, right, columns, label):
    return (f"IF EXISTS(SELECT {columns} FROM {left} EXCEPT SELECT {columns} FROM {right}) "
            f"OR EXISTS(SELECT {columns} FROM {right} EXCEPT SELECT {columns} FROM {left}) "
            f"OR (SELECT COUNT_BIG(*) FROM {left})<>(SELECT COUNT_BIG(*) FROM {right}) "
            f"THROW 53801,{g.lit('Binary value mismatch: '+label)},1;\n")


def snapshot_schema_cases(deployed, tables):
    """Exercise real canonical routes against a filled reconstructed V1 shape."""
    target_tables=[t for t in tables if t.role=='SNAPSHOT']
    schema=(ROOT/g.SNAPSHOT_SCHEMA_SOURCE).read_text(encoding='utf-8-sig')
    direct='\n'.join(g.split_batches(schema))
    standalone,_=g.generate_snapshot_target(ROOT)
    routes=[('DIRECT',direct),('STANDALONE',standalone),('COMBINED',deployed)]

    def shape(version):
        out=[]
        for table in target_tables:
            if table.name not in g.SNAPSHOT_LEGACY_CHECKS:
                continue
            current,legacy=g.SNAPSHOT_LEGACY_CHECKS[table.name]
            cname=next(n for n,k in table.constraints if k=='CHECK' and n in ('CK_snapshot_CollectorPolicy_CollectorCode','CK_snapshot_Scope_ScopeType'))
            out.append(f'ALTER TABLE {table.object_name} DROP CONSTRAINT {g.q(cname)};\n'
                       f'ALTER TABLE {table.object_name} WITH CHECK ADD CONSTRAINT {g.q(cname)} {legacy if version==1 else current};\n')
        out.append("UPDATE snapshot.PackageVersion SET PackageVersion='1.0.0',SchemaVersion=1 WHERE PackageCode='SC-023';\n" if version==1 else
                   "UPDATE snapshot.PackageVersion SET PackageVersion='1.1.0',SchemaVersion=2 WHERE PackageCode='SC-023';\n")
        return ''.join(out)

    def state(variable):
        items=[]
        for table in target_tables:
            items.append('JSON_QUERY((SELECT '+binary_columns(table)+' FROM '+table.object_name+' ORDER BY '+g.q(table.columns[0])+" FOR JSON PATH,INCLUDE_NULL_VALUES)) AS "+g.q(table.name))
        items += ["JSON_QUERY((SELECT name,type,create_date,modify_date FROM sys.objects WHERE schema_id=SCHEMA_ID(N'snapshot') ORDER BY object_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS objects",
                  "JSON_QUERY((SELECT name,object_id,parent_object_id,definition,is_disabled,is_not_trusted,is_not_for_replication FROM sys.check_constraints WHERE schema_id=SCHEMA_ID(N'snapshot') ORDER BY object_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS checks",
                  "JSON_QUERY((SELECT object_id,column_id,name,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name,is_identity FROM sys.columns WHERE object_id IN(SELECT object_id FROM sys.objects WHERE schema_id=SCHEMA_ID(N'snapshot')) ORDER BY object_id,column_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS columns",
                  "JSON_QUERY((SELECT object_id,definition,uses_ansi_nulls,uses_quoted_identifier FROM sys.sql_modules WHERE object_id IN(SELECT object_id FROM sys.objects WHERE schema_id=SCHEMA_ID(N'snapshot')) ORDER BY object_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS modules",
                  "JSON_QUERY((SELECT object_id,last_value FROM sys.identity_columns WHERE object_id IN(SELECT object_id FROM sys.objects WHERE schema_id=SCHEMA_ID(N'snapshot')) ORDER BY object_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS identities"]
        return f'SET {variable}=(SELECT '+','.join(items)+' FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);\n'

    negatives=[
        ('unknown version',"UPDATE snapshot.PackageVersion SET PackageVersion='9.9.9';",53935,"UPDATE snapshot.PackageVersion SET PackageVersion='1.0.0';"),
        ('missing CHECK','ALTER TABLE snapshot.CollectorPolicy DROP CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode;',53908,"ALTER TABLE snapshot.CollectorPolicy WITH CHECK ADD CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode CHECK(CollectorCode='PERFORMANCE_COUNTERS');"),
        ('disabled CHECK','ALTER TABLE snapshot.Scope NOCHECK CONSTRAINT CK_snapshot_Scope_ScopeType;',53908,'ALTER TABLE snapshot.Scope WITH CHECK CHECK CONSTRAINT CK_snapshot_Scope_ScopeType;'),
        ('untrusted CHECK','ALTER TABLE snapshot.Scope NOCHECK CONSTRAINT CK_snapshot_Scope_ScopeType; ALTER TABLE snapshot.Scope CHECK CONSTRAINT CK_snapshot_Scope_ScopeType;',53908,'ALTER TABLE snapshot.Scope WITH CHECK CHECK CONSTRAINT CK_snapshot_Scope_ScopeType;'),
        ('additional CHECK','ALTER TABLE snapshot.Scope ADD CONSTRAINT CK_ExampleAdditionalScope CHECK(ScopeId>0);',53908,'ALTER TABLE snapshot.Scope DROP CONSTRAINT CK_ExampleAdditionalScope;'),
        ('additional column','ALTER TABLE snapshot.Scope ADD ExampleUnexpectedColumn int NULL;',53906,'ALTER TABLE snapshot.Scope DROP COLUMN ExampleUnexpectedColumn;'),
        ('mixed domains',"ALTER TABLE snapshot.Scope DROP CONSTRAINT CK_snapshot_Scope_ScopeType; ALTER TABLE snapshot.Scope WITH CHECK ADD CONSTRAINT CK_snapshot_Scope_ScopeType CHECK([ScopeType] IN ('SERVER','PERFORMANCE_COUNTER','WAIT_TYPE'));",53908,shape(1)),
        ('unknown enum',"ALTER TABLE snapshot.CollectorPolicy DROP CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode; ALTER TABLE snapshot.CollectorPolicy WITH CHECK ADD CONSTRAINT CK_snapshot_CollectorPolicy_CollectorCode CHECK(CollectorCode IN('PERFORMANCE_COUNTERS','EXAMPLE_UNSUPPORTED'));",53908,shape(1)),
    ]
    out=['USE '+g.q(TARGET)+';\nGO\nCREATE TABLE qa.SnapshotMigrationInput(Route varchar(16) PRIMARY KEY,SqlText nvarchar(max) NOT NULL);\n']
    for label,route in routes:
        out.append('INSERT qa.SnapshotMigrationInput VALUES('+g.lit(label)+','+g.lit(route)+');\n')
    out.append('GO\n')
    for label,route in routes:
        call="DECLARE @SnapshotRouteSql nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route="+g.lit(label)+");\nEXEC sys.sp_executesql @SnapshotRouteSql;\n"
        # Preserve every old table row, including typed/binary payloads and
        # identity counters, rather than just a sample count.
        out.append(shape(1)+'GO\n')
        out.append(call+'GO\n')
        out.append("IF NOT EXISTS(SELECT 1 FROM snapshot.PackageVersion WHERE PackageCode='SC-023' AND PackageVersion='1.1.0' AND SchemaVersion=2) THROW 53813,N'Snapshot V1 migration version mismatch.',1;\n")
        for i,table in enumerate(tables,1):
            if table.role=='SNAPSHOT' and table.name!='PackageVersion':
                out.append(equal_rows(f'qa.Before_{i}',table.object_name,binary_columns(table),'Snapshot '+label+' V1 preservation '+table.name))
            elif table.role=='SNAPSHOT':
                out.append(equal_rows(f'qa.Before_{i}',table.object_name,'CONVERT(varbinary(max),PackageCode) AS PackageCode,CONVERT(varbinary(max),InstalledAtUtc) AS InstalledAtUtc','Snapshot '+label+' installed-at preservation'))
        out.append('GO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n'+state('@Before'))
        out.append(call+state('@After'))
        # Repetition may update LastInstallerRunUtc; compare this explicitly
        # normalized field while retaining every other data/metadata facet.
        out.append("SET @Before=JSON_MODIFY(JSON_MODIFY(@Before,'$.PackageVersion[0].LastInstallerRunUtc',NULL),'$.objects',NULL); SET @After=JSON_MODIFY(JSON_MODIFY(@After,'$.PackageVersion[0].LastInstallerRunUtc',NULL),'$.objects',NULL);\n"
                   "IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) THROW 53814,N'Snapshot repetition changed existing state.',1;\nGO\n")
        if label=='STANDALONE':
            out.append('SET QUOTED_IDENTIFIER OFF; SET ANSI_NULLS OFF; SET ANSI_PADDING OFF; SET ANSI_WARNINGS OFF; SET ARITHABORT OFF; SET CONCAT_NULL_YIELDS_NULL OFF; SET NUMERIC_ROUNDABORT ON; SET LOCK_TIMEOUT -1;\n'+call)
            out.append('SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; SET LOCK_TIMEOUT 10000;\n')
            out.append("IF (SELECT COUNT(*) FROM sys.procedures WHERE schema_id=SCHEMA_ID(N'snapshot'))<>5 OR EXISTS(SELECT 1 FROM sys.procedures p JOIN sys.sql_modules m ON m.object_id=p.object_id WHERE p.schema_id=SCHEMA_ID(N'snapshot') AND (m.uses_ansi_nulls<>1 OR m.uses_quoted_identifier<>1)) THROW 53820,N'Snapshot standalone inherited noncanonical module settings.',1;\nGO\n")
            out.append('SET XACT_ABORT ON; BEGIN TRANSACTION;\n')
            out.append(negative(route,50000,'Snapshot standalone caller transaction',"IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR (@@OPTIONS & 16384)=0 THROW 53817,N'Snapshot standalone changed caller transaction/options.',1; ROLLBACK TRANSACTION;"))
            out.append('SET IMPLICIT_TRANSACTIONS ON;\n')
            out.append(negative(route,50000,'Snapshot standalone implicit transactions',"IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=0 THROW 53818,N'Snapshot standalone changed implicit transaction state.',1; SET IMPLICIT_TRANSACTIONS OFF;"))
        if label=='DIRECT':
            out.append(shape(1)+'GO\nBEGIN TRANSACTION;\n'+call)
            out.append("IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 53819,N'Direct Snapshot installer completed caller transaction.',1; ROLLBACK TRANSACTION;\n"
                       "IF NOT EXISTS(SELECT 1 FROM snapshot.PackageVersion WHERE PackageVersion='1.0.0' AND SchemaVersion=1) THROW 53819,N'Direct Snapshot caller rollback failed.',1;\nGO\n")
            out.append('SET XACT_ABORT ON; SET IMPLICIT_TRANSACTIONS ON;\n')
            out.append(negative(route,50000,'Direct Snapshot implicit transactions',"IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=0 OR (@@OPTIONS & 16384)=0 THROW 53818,N'Direct Snapshot changed implicit transaction state.',1; SET IMPLICIT_TRANSACTIONS OFF;"))
        out.append(shape(1)+'GO\n')
        selected=negatives if label!='COMBINED' else [negatives[i] for i in (0,5,6)]
        for case,arrange,error,restore in selected:
            out.append(arrange+'\nGO\nDECLARE @Before nvarchar(max),@After nvarchar(max);\n'+state('@Before'))
            out.append("DECLARE @SnapshotRouteSql nvarchar(max)=(SELECT SqlText FROM qa.SnapshotMigrationInput WHERE Route="+g.lit(label)+");\n")
            out.append(f'BEGIN TRY EXEC sys.sp_executesql @SnapshotRouteSql; THROW 53815,{g.lit("Expected Snapshot rejection: "+label+" "+case)},1; END TRY\n'
                       f'BEGIN CATCH IF ERROR_NUMBER()<>{error} THROW; END CATCH;\n')
            out.append(state('@After')+"IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After) OR @@TRANCOUNT<>0 THROW 53816,N'Rejected Snapshot route changed state.',1;\nGO\n"+restore+'\nGO\n')
        out.append(shape(2)+'GO\n')
    out.append("SELECT N'PASS' AS SnapshotSchemaMigration,N'3 real routes, 3 V1 upgrades, 3 repetitions, 19 shape/version rejections with preservation' AS Scope;\nGO\n")
    return ''.join(out)


def prepare_snapshot_schema_only():
    sql,_=g.generate(ROOT,True)
    _,tables,_=g.load_sources(ROOT,True)
    deployed=configured(sql)
    out=["USE master;\nGO\nSET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;\n",
         f"IF DB_ID({g.lit(FRAMEWORK)}) IS NOT NULL OR DB_ID({g.lit(TARGET)}) IS NOT NULL THROW 53802,N'Regression requires absent dedicated test databases.',1;\n",
         f'CREATE DATABASE {g.q(FRAMEWORK)} COLLATE SQL_Latin1_General_CP1_CS_AS;\nGO\nCREATE DATABASE {g.q(TARGET)} COLLATE Latin1_General_100_CS_AS;\nGO\n',deployed+'\nGO\nUSE '+g.q(TARGET)+';\nGO\nCREATE SCHEMA qa AUTHORIZATION dbo;\nGO\n']
    out.append((ROOT/'Code/Tests/Integration/Deployment_Filled_Target.sql').read_text(encoding='utf-8-sig').replace('USE [DeineDatenbank];','USE '+g.q(TARGET)+';',1))
    for i,table in enumerate(tables,1):
        if table.role=='SNAPSHOT':
            out.append(f'SELECT * INTO qa.Before_{i} FROM {table.object_name};\n')
    out.append('GO\n'+snapshot_schema_cases(deployed,tables))
    return ''.join(out)


def prepare(packaged_installer=None):
    sql, info = g.generate(ROOT, True)
    if packaged_installer is not None:
        packaged = packaged_installer.read_text(encoding='utf-8-sig')
        if packaged != sql:
            raise g.BuildError('Packaged combined deployment differs from canonical sources')
        sql = packaged
    _, tables, _ = g.load_sources(ROOT, True)
    deployed = configured(sql)
    out = ["USE [master];\nGO\nSET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ARITHABORT ON; SET XACT_ABORT ON;\n",
           f"IF DB_ID({g.lit(FRAMEWORK)}) IS NOT NULL OR DB_ID({g.lit(TARGET)}) IS NOT NULL THROW 53802,N'Regression requires absent dedicated test databases.',1;\n",
           f"CREATE DATABASE {g.q(FRAMEWORK)} COLLATE SQL_Latin1_General_CP1_CS_AS;\nGO\n",
           f"CREATE DATABASE {g.q(TARGET)} COLLATE Latin1_General_100_CS_AS;\nGO\n",
           deployed+'\nGO\n']
    # Fresh receipts exist in both contexts with no pre-existing table manifest.
    for role, db in [('FRAMEWORK',FRAMEWORK), ('SNAPSHOT',TARGET)]:
        check = ("DECLARE @Run sysname=(SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%');\n"
                 "IF @Run IS NULL THROW 53803,N'Missing fresh receipt.',1;\n"
                 "DECLARE @Check nvarchar(max)=N'IF EXISTS(SELECT 1 FROM monitor_deployment.'+QUOTENAME(@Run)+N' WHERE Manifest<>N''[]'' OR FormatVersion<>1 OR DatabaseRole<>@Role OR SourceSha256<>@Digest) THROW 53803,N''Invalid fresh receipt.'',1;';\n"
                 f"EXEC sys.sp_executesql @Check,N'@Role varchar(16),@Digest binary(32)',@Role='{role}',@Digest=0x{info['digest']};\n")
        out.append('USE '+g.q(db)+';\nGO\n'+check+'GO\nCREATE SCHEMA qa AUTHORIZATION dbo;\nGO\n')
    for role, db, file in [('FRAMEWORK',FRAMEWORK,'Deployment_Filled_Core.sql'), ('SNAPSHOT',TARGET,'Deployment_Filled_Target.sql')]:
        fixture = (ROOT/'Code/Tests/Integration'/file).read_text(encoding='utf-8-sig')
        out.append(fixture.replace('USE [DeineDatenbank];','USE '+g.q(db)+';',1))
        out.append('USE '+g.q(db)+';\nGO\n')
        out.append("CREATE TABLE qa.BeforeMeta(TableSchema sysname,TableName sysname,IdentityValue decimal(38,0) NULL);\n")
        for i, table in enumerate(tables,1):
            if table.role!=role:
                continue
            cols=','.join('CONVERT(binary(8),'+g.q(c)+') AS '+g.q(c) if 'rowversion' in table.column_specs[c].lower() else
                          'CONVERT('+g.ident(g.tokens(table.column_specs[c])[1])+','+g.q(c)+') AS '+g.q(c) if 'IDENTITY' in table.column_specs[c].upper() else g.q(c) for c in table.columns)
            out.append(f"IF NOT EXISTS(SELECT 1 FROM {table.object_name}) THROW 53804,{g.lit('Unfilled table fixture: '+table.object_name)},1;\n")
            out.append(f"SELECT {cols} INTO qa.Before_{i} FROM {table.object_name};\n")
            out.append(f"INSERT qa.BeforeMeta VALUES({g.lit(table.schema)},{g.lit(table.name)},CONVERT(decimal(38,0),IDENT_CURRENT({g.lit(table.object_name)})));\n")
        if role=='FRAMEWORK':
            out.append("SELECT OBJECT_DEFINITION(OBJECT_ID(N'monitor.VW_AnalyseAccessPolicy')) AS Definition INTO qa.BeforePolicy;\n")
            for name in ['FrameworkInstallationHistory','FrameworkExpectedObject','FrameworkProcedureContract']:
                out.append(f'SELECT * INTO qa.Before_{name} FROM monitor.{name};\n')
        out.append('GO\n')
    # All failed preflights are followed by native product and receipt checks.
    out.append(negative(configured(sql,'missing synthetic framework'),53922,'missing database'))
    out.append(negative(configured(sql,FRAMEWORK,FRAMEWORK),53921,'same target'))
    out.append(negative(configured(sql,FRAMEWORK,'master'),53922,'system target'))
    out.append(negative(configured(sql,'x'*129),53920,'overlength database'))
    out.append('USE '+g.q(FRAMEWORK)+';\nGO\n')
    out.append("ALTER TABLE monitor.WaitTypeCatalog ADD UnexpectedLocalColumn int NULL;\nGO\n")
    out.append(negative(deployed,53906,'extra column'))
    out.append("ALTER TABLE monitor.WaitTypeCatalog DROP COLUMN UnexpectedLocalColumn;\nGO\n")
    wait_contract=next(t for t in tables if t.name=='WaitTypeCatalog')
    default_names=[name for name,kind in wait_contract.constraints if kind=='DEFAULT'][:2]
    def swap_names(names):
        first,second=names
        return ''.join('EXEC sys.sp_rename '+g.lit('monitor.'+old)+','+g.lit(new)+",N'OBJECT';\n"
                       for old,new in [(first,'SQLSA_RegressionSwap'),(second,first),('SQLSA_RegressionSwap',second)])+'GO\n'
    out.append(swap_names(default_names))
    out.append(negative(deployed,53908,'default name-parent binding'))
    out.append(swap_names(default_names))
    out.append("UPDATE monitor.WaitTypeCatalogSource SET IsFrameworkDefault=0 WHERE WaitType=N'CURSOR';\nGO\n")
    out.append(negative(deployed,53930,'custom retired reference'))
    out.append("UPDATE monitor.WaitTypeCatalogSource SET IsFrameworkDefault=1 WHERE WaitType=N'CURSOR';\nGO\n")
    out.append("UPDATE monitor.WaitTypeCatalogSource SET IsFrameworkDefault=0 WHERE WaitType=N'CXPACKET' AND SourceOrdinal=1;\nGO\n")
    out.append(negative(deployed,53933,'custom required source collision'))
    out.append("UPDATE monitor.WaitTypeCatalogSource SET IsFrameworkDefault=1 WHERE WaitType=N'CXPACKET' AND SourceOrdinal=1;\nGO\n")
    out.append("UPDATE monitor.SqlServerBuildCatalog SET ReleaseName=N'SYNTHETIC_CONFLICT' WHERE BuildVersion=(SELECT MIN(BuildVersion) FROM monitor.SqlServerBuildCatalog WHERE ProductMajorVersion<>99);\nGO\n")
    out.append(negative(deployed,53931,'markerless conflict'))
    out.append("UPDATE c SET ReleaseName=b.ReleaseName FROM monitor.SqlServerBuildCatalog c JOIN qa.Before_"+str(next(i for i,t in enumerate(tables,1) if t.name=='SqlServerBuildCatalog'))+" b ON b.BuildVersion=c.BuildVersion;\nGO\n")
    # A direct rejection must preserve an already active, committable caller TX
    # and the caller's XACT_ABORT option even through nested sp_executesql.
    out.append("SET XACT_ABORT ON; BEGIN TRANSACTION; INSERT qa.BeforeMeta VALUES(N'caller',N'caller',NULL);\n")
    out.append(negative(deployed,50000,'caller transaction',"IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR (@@OPTIONS & 16384)=0 OR NOT EXISTS(SELECT 1 FROM qa.BeforeMeta WHERE TableSchema=N'caller') THROW 53805,N'Caller transaction or option changed.',1; ROLLBACK TRANSACTION;"))
    fault=g.invoke('SELECT [SQLSA_IntentionalMissingColumn] FROM [monitor].[WaitTypeCatalog];','@FrameworkDatabase','Intentional lower-scope compile failure')
    prefix,commit,suffix=deployed.rpartition('COMMIT TRANSACTION;')
    if not commit:
        raise g.BuildError('Native regression could not locate the outer commit')
    out.append(negative(prefix+fault+commit+suffix,207,'late compile failure'))
    for role,db in [('FRAMEWORK',FRAMEWORK),('SNAPSHOT',TARGET)]:
        out.append('USE '+g.q(db)+';\nGO\n')
        for i,table in enumerate(tables,1):
            if table.role==role:
                out.append(equal_rows(f'qa.Before_{i}',table.object_name,binary_columns(table),table.object_name+' late rollback'))
        out.append("IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%')<>1 OR EXISTS(SELECT 1 FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'State[_]%') THROW 53806,N'Rejected deployment wrote receipts or state tables.',1;\nGO\n")
    out.append('USE '+g.q(FRAMEWORK)+';\nGO\n')
    out.append("IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%')<>1 THROW 53806,N'Rejected deployment wrote receipts.',1;\nGO\n")
    out.append(deployed+'\nGO\n')
    for role, db in [('FRAMEWORK',FRAMEWORK),('SNAPSHOT',TARGET)]:
        out.append('USE '+g.q(db)+';\nGO\n')
        out.append("IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%')<>2 THROW 53806,N'Reapply receipt count mismatch.',1;\n")
        out.append("DECLARE @Run sysname=(SELECT TOP(1) name FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%' ORDER BY create_date DESC,object_id DESC),@Manifest nvarchar(max),@Read nvarchar(max),@State sysname,@Compare nvarchar(max);\nSET @Read=N'SELECT @Result=Manifest FROM monitor_deployment.'+QUOTENAME(@Run); EXEC sys.sp_executesql @Read,N'@Result nvarchar(max) OUTPUT',@Manifest OUTPUT;\n")
        for i, table in enumerate(tables,1):
            if table.role!=role:
                continue
            cols=binary_columns(table)
            before=f'qa.Before_{i}'
            # The archive target is selected by the receipt's source identity,
            # not a parallel hardcoded ordinal map of mutable table names.
            out.append(f"SET @State=NULL; SELECT @State=archiveName FROM OPENJSON(@Manifest) WITH(originalSchema sysname,originalObject sysname,archiveName sysname) WHERE originalSchema={g.lit(table.schema)} AND originalObject={g.lit(table.name)};\n")
            compare=equal_rows(before,'monitor_deployment.[ARCHIVE]',cols,table.object_name+' archive')
            out.append('IF @State IS NOT NULL BEGIN SET @Compare=REPLACE('+g.lit(compare)+",N'[ARCHIVE]',QUOTENAME(@State)); EXEC sys.sp_executesql @Compare; END;\n")
            if 'IsFrameworkDefault' in table.columns:
                before += ' WHERE IsFrameworkDefault=0'
                active=table.object_name+' WHERE IsFrameworkDefault=0'
                out.append(equal_rows('('+f'SELECT * FROM {before}'+') b','('+f'SELECT * FROM {active}'+') a',cols,table.object_name+' custom'))
            elif table.name not in ('FrameworkVersion','PackageVersion'):
                out.append(equal_rows(before,table.object_name,cols,table.object_name+' active'))
            out.append(f"IF EXISTS(SELECT 1 FROM qa.BeforeMeta WHERE TableSchema={g.lit(table.schema)} AND TableName={g.lit(table.name)} AND IdentityValue<>CONVERT(decimal(38,0),IDENT_CURRENT({g.lit(table.object_name)}))) THROW 53807,N'Identity counter changed.',1;\n")
        if role=='FRAMEWORK':
            out.append("IF EXISTS(SELECT 1 FROM qa.BeforePolicy WHERE CONVERT(varbinary(max),Definition)<>CONVERT(varbinary(max),OBJECT_DEFINITION(OBJECT_ID(N'monitor.VW_AnalyseAccessPolicy')))) THROW 53808,N'Policy definition changed.',1;\n")
            for name, columns in [('FrameworkInstallationHistory','CONVERT(varbinary(max),Id) AS Id,CONVERT(varbinary(max),Value) AS Value'),('FrameworkExpectedObject','CONVERT(varbinary(max),Id) AS Id,CONVERT(varbinary(max),Value) AS Value'),('FrameworkProcedureContract','CONVERT(varbinary(max),Id) AS Id,CONVERT(varbinary(max),Value) AS Value')]:
                out.append(equal_rows('qa.Before_'+name,'monitor.'+name,columns,name+' legacy'))
            out.append("IF EXISTS(SELECT 1 FROM monitor.PlanAnalysisProfile WHERE ProfileCode='BALANCED' AND IsEnabled<>0) OR EXISTS(SELECT 1 FROM monitor.PlanAnalysisRuleThreshold WHERE ProfileCode='BALANCED' AND IsEnabled<>0) OR EXISTS(SELECT 1 FROM monitor.ToolBackgroundQueryPattern WHERE RuleCode='SSMS_OBJECT_EXPLORER' AND IsEnabled<>0) THROW 53809,N'Operator activation overwritten.',1;\n")
            out.append("IF EXISTS(SELECT 1 FROM monitor.WaitTypeCatalog WHERE WaitType=N'CURSOR') OR EXISTS(SELECT 1 FROM monitor.WaitTypeCatalogSource WHERE WaitType=N'CURSOR') THROW 53810,N'Retired defaults remain active.',1;\n")
        out.append('GO\n')
    # Reconstruct the known old Wait shape without relying on canonical fresh
    # column_id values. This fixture is synthetic; production code never drops
    # these columns. The next deployment must add all twelve by name/facets.
    wait=next(t for t in tables if t.name=='WaitTypeCatalog')
    out.append('USE '+g.q(FRAMEWORK)+';\nGO\nDECLARE @Default sysname,@Drop nvarchar(max);\n')
    for column in wait.additions:
        out.append(f"SET @Default=NULL; SELECT @Default=d.name FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=OBJECT_ID(N'monitor.WaitTypeCatalog') AND c.name={g.lit(column)}; IF @Default IS NOT NULL BEGIN SET @Drop=N'ALTER TABLE monitor.WaitTypeCatalog DROP CONSTRAINT '+QUOTENAME(@Default); EXEC sys.sp_executesql @Drop; END; ALTER TABLE monitor.WaitTypeCatalog DROP COLUMN {g.q(column)};\n")
    remaining=[c for c in wait.columns if c not in wait.additions]
    out.append('SELECT '+','.join(g.q(c) for c in remaining)+' INTO qa.BeforeOldWait FROM monitor.WaitTypeCatalog;\nGO\n')
    out.append(deployed+'\nGO\nUSE '+g.q(FRAMEWORK)+';\nGO\n')
    for column in wait.additions:
        out.append(f"IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'monitor.WaitTypeCatalog') AND name={g.lit(column)}) THROW 53811,N'Known additive migration omitted a column.',1;\n")
    out.append("DECLARE @Run sysname=(SELECT TOP(1) name FROM sys.tables WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND name LIKE N'Run[_]%' ORDER BY create_date DESC,object_id DESC),@Manifest nvarchar(max),@Read nvarchar(max),@State sysname,@Compare nvarchar(max); SET @Read=N'SELECT @Result=Manifest FROM monitor_deployment.'+QUOTENAME(@Run); EXEC sys.sp_executesql @Read,N'@Result nvarchar(max) OUTPUT',@Manifest OUTPUT; SELECT @State=archiveName FROM OPENJSON(@Manifest) WITH(originalObject sysname,archiveName sysname) WHERE originalObject=N'WaitTypeCatalog'; IF @State IS NULL THROW 53812,N'Missing old-shape archive.',1;\n")
    old_columns=','.join('CONVERT(varbinary(max),'+g.q(c)+') AS '+g.q(c) for c in remaining)
    comparison=equal_rows('qa.BeforeOldWait','monitor_deployment.[ARCHIVE]',old_columns,'known old Wait shape')
    out.append('SET @Compare=REPLACE('+g.lit(comparison)+",N'[ARCHIVE]',QUOTENAME(@State)); EXEC sys.sp_executesql @Compare;\nGO\n")
    out.append(snapshot_schema_cases(deployed,tables))
    out.append("SELECT N'PASS' AS DeploymentRuntimeContract,N'Fresh, filled all20, binary archives, custom/legacy/policy/identity, Snapshot migration and preflight rejection' AS Scope;\nGO\n")
    return ''.join(out)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--packaged-installer', type=Path)
    parser.add_argument('--snapshot-schema-only', action='store_true')
    args=parser.parse_args()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    if args.snapshot_schema_only and args.packaged_installer:
        parser.error('The focused local scope does not replace packaged full-deployment qualification.')
    args.output.write_text(prepare_snapshot_schema_only() if args.snapshot_schema_only else prepare(args.packaged_installer),encoding='utf-8',newline='\n')
    print('Prepared native synthetic deployment regression:',args.output)


if __name__=='__main__':
    main()
