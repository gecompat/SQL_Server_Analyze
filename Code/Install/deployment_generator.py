"""Source-derived lossless SQL deployment generator; Python standard library only.

The supported grammar is intentionally narrow. Unsupported sources fail at build
time; runtime reference tables let SQL Server, rather than Python, canonicalize
type, default, check and index metadata. No database connection is used here.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import re

TOKEN_PATTERN=re.compile(r'[A-Za-z_@#][A-Za-z0-9_@$#]*|\d+(?:\.\d+)?|[^\s]')


class BuildError(ValueError):
    pass


@dataclass(frozen=True)
class Token:
    value: str
    start: int
    end: int
    kind: str


def tokens(sql: str) -> list[Token]:
    result = []
    i = 0
    while i < len(sql):
        if sql[i].isspace():
            i += 1
        elif sql.startswith('--', i):
            end = sql.find('\n', i)
            i = len(sql) if end < 0 else end + 1
        elif sql.startswith('/*', i):
            begin, depth = i, 1
            i += 2
            while depth and i < len(sql):
                if sql.startswith('/*', i):
                    depth += 1
                    i += 2
                elif sql.startswith('*/', i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            if depth:
                raise BuildError(f'Unclosed comment at {begin}')
        elif sql[i] == "'" or (sql[i] in 'Nn' and sql[i:i+2].upper() == "N'"):
            begin = i
            if sql[i] != "'":
                i += 1
            i += 1
            while i < len(sql):
                if sql[i] == "'":
                    if sql[i:i+2] == "''":
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
            else:
                raise BuildError(f'Unclosed string at {begin}')
            result.append(Token(sql[begin:i], begin, i, 'string'))
        elif sql[i] == '[':
            begin = i
            i += 1
            while i < len(sql):
                if sql[i] == ']':
                    if sql[i:i+2] == ']]':
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
            else:
                raise BuildError(f'Unclosed identifier at {begin}')
            result.append(Token(sql[begin:i], begin, i, 'identifier'))
        elif sql[i] == '"':
            raise BuildError('Double-quoted source tokens require an explicit grammar extension')
        else:
            match = TOKEN_PATTERN.match(sql,i)
            assert match
            end = i + len(match[0])
            result.append(Token(match[0], i, end, 'plain'))
            i = end
    return result


def ident(token: Token) -> str:
    return token.value[1:-1].replace(']]', ']') if token.kind == 'identifier' else token.value


def upper(token: Token) -> str:
    return token.value.upper() if token.kind == 'plain' else token.value


def q(name: str) -> str:
    return '[' + name.replace(']', ']]') + ']'


def lit(value: str) -> str:
    return "N'" + value.replace("'", "''") + "'"


def unstring(token: Token) -> str:
    text = token.value
    if text[0].upper() == 'N':
        text = text[1:]
    return text[1:-1].replace("''", "'")


def matching(ts: list[Token], start: int) -> int:
    depth = 0
    for i in range(start, len(ts)):
        if ts[i].value == '(':
            depth += 1
        elif ts[i].value == ')':
            depth -= 1
            if depth == 0:
                return i
    raise BuildError('Unclosed parenthesis')


def split_batches(sql: str) -> list[str]:
    ts = tokens(sql)
    separators = []
    for token in ts:
        if upper(token) != 'GO':
            continue
        start = sql.rfind('\n', 0, token.start) + 1
        end = sql.find('\n', token.end)
        if end < 0:
            end = len(sql)
        line = sql[start:end]
        if re.fullmatch(r'\s*GO\s*(?:--[^\n]*)?', line, re.I):
            separators.append((start, end))
        elif re.match(r'^\s*GO\b', line, re.I):
            raise BuildError('GO repeat counts or unsupported separator syntax')
    parts, start = [], 0
    for begin, end in separators:
        part = sql[start:begin].strip()
        if tokens(part):
            parts.append(part)
        start = end
    part = sql[start:].strip()
    if tokens(part):
        parts.append(part)
    return parts


def qualified(ts: list[Token], start: int) -> tuple[str, str, int]:
    if start + 2 >= len(ts) or ts[start+1].value != '.':
        raise BuildError('Expected a two-part object name')
    return ident(ts[start]), ident(ts[start+2]), start + 3


@dataclass
class Table:
    role: str
    schema: str
    name: str
    source: str
    create: str
    columns: list[str]
    constraints: list[tuple[str, str]]
    foreign_keys: list[tuple[str, list[str], str, str, list[str]]]
    indexes: list[str]
    additions: list[str]
    column_specs: dict[str,str]

    @property
    def object_name(self):
        return q(self.schema) + '.' + q(self.name)


@dataclass
class Source:
    role: str
    path: str
    text: str
    batches: list[str]
    module: tuple[str, str, str] | None


def table_definitions(sql: str, role: str, path: str) -> list[Table]:
    ts = tokens(sql)
    expanded = [sql]
    for token in ts:
        if token.kind == 'string' and re.match(r'^\s*CREATE\s+TABLE\b', unstring(token), re.I):
            expanded.append(unstring(token))
    result = []
    for text in expanded:
        ts = tokens(text)
        for i in range(len(ts)-4):
            if [upper(t) for t in ts[i:i+2]] != ['CREATE', 'TABLE']:
                continue
            if ident(ts[i+2]).startswith('#'):
                continue
            schema, name, pos = qualified(ts, i+2)
            if schema not in ('monitor', 'snapshot'):
                raise BuildError(f'Unsupported persistent schema in {path}')
            if ts[pos].value != '(':
                raise BuildError(f'Unsupported table DDL in {path}')
            end = matching(ts, pos)
            groups, group, depth = [], [], 0
            for token in ts[pos+1:end]:
                if token.value == ',' and depth == 0:
                    groups.append(group)
                    group = []
                    continue
                group.append(token)
                depth += (token.value == '(') - (token.value == ')')
            groups.append(group)
            columns, constraints, fks, pieces, column_specs = [], [], [], [], {}
            for group in groups:
                words = [upper(t) for t in group]
                if not group:
                    raise BuildError(f'Empty table clause in {path}')
                constraint_at = [j for j, word in enumerate(words) if word == 'CONSTRAINT']
                for j,word in enumerate(words):
                    if word in ('PRIMARY','UNIQUE','CHECK','DEFAULT','FOREIGN') and (j<2 or words[j-2]!='CONSTRAINT'):
                        raise BuildError(f'Unnamed constraint requires an explicit source contract in {path}')
                if upper(group[0]) != 'CONSTRAINT':
                    columns.append(ident(group[0]))
                    if upper(group[1]) not in ('SYSNAME','VARCHAR','NVARCHAR','CHAR','NCHAR','VARBINARY','BINARY','BIT','TINYINT','SMALLINT','INT','BIGINT','DECIMAL','NUMERIC','DATE','DATETIME2','UNIQUEIDENTIFIER','ROWVERSION'):
                        raise BuildError(f'Unsupported column type in {path}: {group[1].value}')
                for j in constraint_at:
                    cname = ident(group[j+1])
                    kind = words[j+2]
                    if kind not in ('PRIMARY','UNIQUE','CHECK','DEFAULT','FOREIGN'):
                        raise BuildError(f'Unsupported constraint {cname}')
                    constraints.append((cname, kind))
                if 'FOREIGN' in words:
                    if words[0] != 'CONSTRAINT' or 'REFERENCES' not in words:
                        raise BuildError('Unsupported foreign-key clause')
                    key = words.index('KEY') + 1
                    key_end = matching(group, key)
                    refs = words.index('REFERENCES')
                    rschema, rtable, rpos = qualified(group, refs+1)
                    rend = matching(group, rpos)
                    if rend != len(group)-1:
                        raise BuildError('Foreign-key actions require an explicit migration contract')
                    fks.append((ident(group[1]), [ident(t) for t in group[key+1:key_end] if t.value != ','], rschema, rtable, [ident(t) for t in group[rpos+1:rend] if t.value != ',']))
                    continue
                piece = text[group[0].start:group[-1].end]
                if words[0]!='CONSTRAINT':
                    column_specs[ident(group[0])]=piece
                # Implicit textual collation belongs to the selected target database,
                # even though the reference table itself is stored in tempdb.
                if words[0] != 'CONSTRAINT' and upper(group[1]) in ('SYSNAME','VARCHAR','NVARCHAR','CHAR','NCHAR') and 'COLLATE' not in words:
                    type_end = 1
                    if len(group) > 2 and group[2].value == '(':
                        type_end = matching(group, 2)
                    offset = group[type_end].end - group[0].start
                    piece = piece[:offset] + ' COLLATE DATABASE_DEFAULT' + piece[offset:]
                pieces.append(piece)
            result.append(Table(role, schema, name, path, 'CREATE TABLE {table}\n(\n' + ',\n'.join(pieces) + '\n);', columns, constraints, fks, [], [],column_specs))
    return result


def load_sources(root: Path, snapshot: bool) -> tuple[list[Source], list[Table], str]:
    masters = [('FRAMEWORK', 'Install_All.sql')]
    if snapshot:
        masters += [('SNAPSHOT', 'Install_SnapshotBaseline_Target.sql'), ('FRAMEWORK', 'Install_SnapshotBaseline_Framework.sql')]
    sources, seen, hashes = [], set(), []
    for role, master in masters:
        master_path = root / 'Code/Install' / master
        text = master_path.read_text(encoding='utf-8-sig').replace('\r\n','\n')
        includes = re.findall(r'^\s*:r\s+(.+?)\s*$', text, re.M)
        if not includes:
            raise BuildError(f'No includes in {master}')
        if re.search(r'^\s*:(?!r\s|ON ERROR EXIT\s*$)', text, re.M):
            raise BuildError(f'Unknown SQLCMD directive in {master}')
        local = set()
        hashes.append((master_path.relative_to(root).as_posix(), text))
        for include in includes:
            path = (master_path.parent / include.strip('"')).resolve()
            if not path.is_relative_to(root) or path.suffix != '.sql' or not path.is_file():
                raise BuildError(f'Invalid include in {master}: {include}')
            if path in local:
                raise BuildError(f'Duplicate include in {master}')
            local.add(path)
            key = (role, path)
            if key in seen:
                continue
            seen.add(key)
            content = path.read_text(encoding='utf-8-sig').replace('\r\n','\n')
            relative = path.relative_to(root).as_posix()
            hashes.append((relative, content))
            batches = split_batches(content)
            if batches and [upper(t) for t in tokens(batches[0])] == ['USE','[DeineDatenbank]',';']:
                batches = batches[1:]
            if any(upper(t) == 'USE' for batch in batches for t in tokens(batch)[:1]):
                raise BuildError(f'Unexpected source context in {relative}')
            module = None
            for batch in batches:
                bt = tokens(batch)
                if len(bt) > 4 and [upper(t) for t in bt[:3]] == ['CREATE','OR','ALTER']:
                    kind = upper(bt[3])
                    schema, name, _ = qualified(bt, 4)
                    otype = {'VIEW':'V','PROCEDURE':'P','PROC':'P','FUNCTION':'IF'}.get(kind)
                    if otype is None:
                        raise BuildError(f'Unsupported module in {relative}')
                    if kind == 'FUNCTION':
                        rest = ' '.join(upper(t) for t in bt)
                        otype = 'TF' if re.search(r'RETURNS @',rest) else ('IF' if re.search(r'RETURNS TABLE',rest) else 'FN')
                    if module:
                        raise BuildError(f'Multiple modules in {relative}')
                    module = (schema,name,otype)
            sources.append(Source(role,relative,content,batches,module))
    tables = []
    for source in sources:
        if not source.module:
            tables.extend(table_definitions(source.text,source.role,source.path))
    keys = [(table.role,table.schema,table.name) for table in tables]
    if len(keys) != len(set(keys)):
        raise BuildError('Duplicate canonical table definitions')
    for table in tables:
        source = next(s for s in sources if s.path == table.source)
        ts = tokens(source.text)
        for i in range(len(ts)-5):
            if [upper(t) for t in ts[i:i+2]] == ['ALTER','TABLE']:
                schema,name,pos = qualified(ts,i+2)
                if (schema,name) != (table.schema,table.name):
                    continue
                if upper(ts[pos]) != 'ADD':
                    raise BuildError('Only enumerated additive table clauses are supported')
                if table.name != 'WaitTypeCatalog' or source.path != 'Code/01_Common/074_WaitTypeCatalog.sql':
                    raise BuildError('Unknown additive migration source')
                column=ident(ts[pos+1])
                end=next((j for j in range(pos+1,len(ts)) if ts[j].value==';'),None)
                if end is None or column not in table.column_specs:
                    raise BuildError('Unknown additive migration column')
                clause=ts[pos+1:end]
                if [upper(t) for t in clause[-2:]]==['WITH','VALUES']:
                    clause=clause[:-2]
                normalized=lambda seq:[ident(t).upper() if t.kind!='string' else t.value for t in seq]
                if normalized(clause)!=normalized(tokens(table.column_specs[column])):
                    raise BuildError('Additive migration differs from its canonical column definition')
                table.additions.append(column)
            if upper(ts[i]) == 'CREATE' and upper(ts[i+1]) in ('INDEX','UNIQUE'):
                pos = i+2 if upper(ts[i+1]) == 'INDEX' else i+3
                if upper(ts[pos+1]) != 'ON':
                    raise BuildError('Unsupported index syntax')
                schema,name,_ = qualified(ts,pos+2)
                if (schema,name) != (table.schema,table.name):
                    continue
                end = next((j for j in range(pos,len(ts)) if ts[j].value == ';'),None)
                if end is None:
                    raise BuildError('Index must be terminated')
                table.indexes.append(source.text[ts[i].start:ts[end].end])
        if table.additions and (len(table.additions)!=12 or len(set(table.additions))!=12):
            raise BuildError('Known Wait additive contract requires twelve distinct clauses')
        if sum(kind=='UNIQUE' for _,kind in table.constraints)>1:
            raise BuildError('Multiple unique constraints require an explicit native index-name mapping')
    # Classify executable source forms independently of comments and seed text.
    for source in sources:
        if source.module:
            for batch in source.batches:
                bt = tokens(batch)
                if [upper(t) for t in bt[:3]]==['CREATE','OR','ALTER']:
                    continue
                if not bt or upper(bt[0])!='SET':
                    raise BuildError(f'Executable sidecar batch after module: {source.path}')
                validate_set_batch(bt,source.path)
            continue
        for batch in source.batches:
            bt = tokens(batch)
            if upper(bt[0]) not in ('SET','IF','DECLARE','CREATE','UPDATE','INSERT','DELETE'):
                raise BuildError(f'Unknown deployment batch prefix: {source.path}')
            for i,token in enumerate(bt):
                if upper(token) in ('TRUNCATE','MERGE','GRANT','DENY','REVOKE','COMMIT','ROLLBACK','SAVE','DBCC','BACKUP','RESTORE','USE','BULK'):
                    raise BuildError(f'Unsupported deployment operation in {source.path}: {token.value}')
                if upper(token)=='INTO' and (i==0 or upper(bt[i-1])!='INSERT'):
                    raise BuildError(f'Unclassified SELECT/OUTPUT INTO in {source.path}')
                if upper(token)=='BEGIN' and i+1<len(bt) and upper(bt[i+1]) in ('TRAN','TRANSACTION','DISTRIBUTED'):
                    raise BuildError(f'Deployment source may not start a transaction: {source.path}')
                if upper(token)=='INSERT':
                    pos=i+1+(upper(bt[i+1])=='INTO')
                    target=ident(bt[pos])
                    if target.startswith(('@','#')):
                        if not any(upper(bt[j])=='DECLARE' and ident(bt[j+1])==target and upper(bt[j+2])=='TABLE'
                                   or [upper(t) for t in bt[j:j+2]]==['CREATE','TABLE'] and ident(bt[j+2])==target
                                   for j in range(len(bt)-2)):
                            raise BuildError(f'Unclassified temporary INSERT target in {source.path}')
                    else:
                        schema,name,_=qualified(bt,pos)
                        if (source.role,schema,name) not in keys:
                            raise BuildError(f'Unclassified persistent INSERT target in {source.path}')
                if upper(token)=='ALTER':
                    if upper(bt[i+1])!='TABLE':
                        raise BuildError(f'Unsupported deployment ALTER in {source.path}')
                    schema,name,pos=qualified(bt,i+2)
                    if (source.role,schema,name) not in keys or upper(bt[pos])!='ADD':
                        raise BuildError(f'Unclassified additive ALTER in {source.path}')
                if upper(token)=='CREATE' and upper(bt[i+1]) in ('INDEX','UNIQUE'):
                    pos=i+4 if upper(bt[i+1])=='INDEX' else i+5
                    schema,name,_=qualified(bt,pos)
                    if (source.role,schema,name) not in keys:
                        raise BuildError(f'Unclassified CREATE INDEX target in {source.path}')
                if upper(token) == 'DROP' and source.path != 'Code/09_VersionAdaptive/005_Deprecated_Object_Cleanup.sql':
                    local_tables={ident(bt[j+2]) for j in range(len(bt)-2)
                                  if [upper(t) for t in bt[j:j+2]]==['CREATE','TABLE']
                                  and ident(bt[j+2]).startswith('#')}
                    if i+2>=len(bt) or upper(bt[i+1])!='TABLE' or ident(bt[i+2]) not in local_tables:
                        raise BuildError(f'Unsupported destructive source: {source.path}')
                if upper(token)=='CREATE' and upper(bt[i+1]) not in ('TABLE','INDEX','UNIQUE'):
                    raise BuildError(f'Unsupported source DDL: {source.path}')
                if source.path=='Code/09_VersionAdaptive/005_Deprecated_Object_Cleanup.sql' and upper(token) in ('CREATE','ALTER','INSERT','UPDATE','DELETE','EXEC','EXECUTE'):
                    raise BuildError('Legacy cleanup contains an unclassified operation')
                if upper(token)=='SET' and i+2<len(bt) and bt[i+1].kind=='plain' and not bt[i+1].value.startswith('@'):
                    validate_setting(bt[i+1],bt[i+2],source.path)
                if upper(token) in ('EXEC','EXECUTE'):
                    pos=i+1
                    if bt[pos].value=='(':
                        pos+=1
                    elif bt[pos].kind=='identifier' or upper(bt[pos])=='SYS':
                        schema,proc,pos=qualified(bt,pos)
                        if schema!='sys' or proc!='sp_executesql':
                            raise BuildError(f'Unsupported deployment procedure: {source.path}')
                    if bt[pos].kind!='string':
                        raise BuildError(f'Dynamic source EXEC must use a constant: {source.path}')
                    dynamic=tokens(unstring(bt[pos]))
                    if not dynamic:
                        raise BuildError('Empty executable source string')
                    if [upper(t) for t in dynamic[:2]]==['CREATE','SCHEMA']:
                        if len(dynamic)!=6 or ident(dynamic[2]) not in ('monitor','snapshot') or [upper(dynamic[3]),ident(dynamic[4]),dynamic[5].value]!=['AUTHORIZATION','dbo',';']:
                            raise BuildError('Unknown schema creation contract')
                    elif [upper(t) for t in dynamic[:2]]==['CREATE','TABLE']:
                        _,_,table_pos=qualified(dynamic,2)
                        if dynamic[table_pos].value!='(' or any(t.value!=';' for t in dynamic[matching(dynamic,table_pos)+1:]):
                            raise BuildError('A constant table EXEC may contain only its CREATE TABLE statement')
                        table_definitions(unstring(bt[pos]),source.role,source.path)
                    elif upper(dynamic[0])=='IF':
                        if any(upper(t) in ('UPDATE','DELETE','INSERT','EXEC','EXECUTE','CREATE','ALTER','DROP','TRUNCATE','MERGE','GRANT','DENY','REVOKE','COMMIT','ROLLBACK','SAVE','SET','DBCC','BACKUP','RESTORE','USE','BULK','INTO','OPENROWSET','OPENQUERY','OPENDATASOURCE','TRAN','TRANSACTION','DISTRIBUTED') for t in dynamic):
                            raise BuildError('A source preflight string may only inspect and abort')
                    else:
                        raise BuildError(f'Unknown dynamic source batch: {source.path}')
    for relative in ('Code/Install/deployment_generator.py','Code/Install/Build-DeploymentInstaller.ps1'):
        hashes.append((relative,(root/relative).read_text(encoding='utf-8-sig').replace('\r\n','\n')))
    digest = hashlib.sha256(json.dumps(hashes, ensure_ascii=False, separators=(',',':')).encode('utf-8')).hexdigest()
    return sources,tables,digest


def validate_setting(option: Token,value: Token,path: str):
    expected={'NOCOUNT':'ON','XACT_ABORT':'ON','ANSI_NULLS':'ON','QUOTED_IDENTIFIER':'ON',
              'ANSI_PADDING':'ON','ANSI_WARNINGS':'ON','ARITHABORT':'ON',
              'CONCAT_NULL_YIELDS_NULL':'ON','NUMERIC_ROUNDABORT':'OFF','LOCK_TIMEOUT':'0'}
    if expected.get(upper(option))!=upper(value):
        raise BuildError(f'Unsupported source SET option: {path}: {option.value} {value.value}')


def validate_set_batch(bt: list[Token],path: str):
    if len(bt)%4:
        raise BuildError(f'Unsupported module SET batch: {path}')
    for i in range(0,len(bt),4):
        if upper(bt[i])!='SET' or bt[i+3].value!=';':
            raise BuildError(f'Unsupported module sidecar: {path}')
        validate_setting(bt[i+1],bt[i+2],path)


def invoke(statement: str, database: str, label: str = '') -> str:
    # The wrapper context encloses the separate module compilation level.
    return (f'-- {label}\n' if label else '') + f"SET @DeploymentSql=N'USE '+QUOTENAME({database})+N'; SET LOCK_TIMEOUT 10000; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF; EXEC [sys].[sp_executesql] @InnerSql;';\nEXEC [sys].[sp_executesql] @DeploymentSql,N'@InnerSql nvarchar(max)',@InnerSql={lit(statement)};\n"


def constraint_template(table: Table, ordinal: int, include_indexes: bool=True) -> tuple[str,list[tuple[str,str]]]:
    template = table.create.replace('{table}',q(f'#SQLSA_Expected_{ordinal}'))
    names = []
    for cname,kind in table.constraints:
        if kind == 'FOREIGN':
            continue
        replacement = 'SQLSA_' + str(ordinal) + '_' + str(len(names))
        template,count = re.subn(r'\bCONSTRAINT\s+(?:'+re.escape(q(cname))+'|'+re.escape(cname)+r')(?=\s)', 'CONSTRAINT ' + q(replacement),template,flags=re.I)
        if count != 1:
            raise BuildError(f'Constraint template ambiguity: {cname}')
        names.append((replacement,cname))
    for index in table.indexes if include_indexes else []:
        template += '\n' + index.replace(table.object_name,q(f'#SQLSA_Expected_{ordinal}'))
    return template,names


def preflight(tables: list[Table], sources: list[Source], strict: bool=False) -> str:
    out = ["SET NOCOUNT ON; SET LOCK_TIMEOUT 10000;\n"
           "IF ISNULL(HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','CONTROL'),0)<>1 OR ISNULL(HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY DEFINITION'),0)<>1 THROW 53901,N'Deployment requires CONTROL DATABASE and visible server metadata.',1;\n"
           "IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_class=0 AND is_disabled=0) OR EXISTS(SELECT 1 FROM sys.server_triggers WHERE is_disabled=0) THROW 53902,N'Active DDL triggers are unsupported.',1;\n"
           "IF SCHEMA_ID(N'monitor_deployment') IS NOT NULL AND (NOT EXISTS(SELECT 1 FROM sys.schemas WHERE schema_id=SCHEMA_ID(N'monitor_deployment') AND principal_id=DATABASE_PRINCIPAL_ID(N'dbo')) OR NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=3 AND major_id=SCHEMA_ID(N'monitor_deployment') AND name=N'SQL_Server_Analyze.DeploymentFormat' AND CONVERT(nvarchar(30),value)=N'1')) THROW 53903,N'Unknown deployment schema ownership or format.',1;\n"
           "DECLARE @ObjectId int,@ExpectedId int,@LockCount bigint,@ConstraintSql nvarchar(max),@Prefix nvarchar(33);\n"
           "CREATE TABLE #SQLSA_ConstraintMap(CanonicalName sysname COLLATE DATABASE_DEFAULT NOT NULL,ParentColumn sysname COLLATE DATABASE_DEFAULT NULL,ConstraintType char(2) COLLATE DATABASE_DEFAULT NOT NULL,Definition nvarchar(max) COLLATE DATABASE_DEFAULT NULL,IsDisabled bit NOT NULL,IsNotTrusted bit NOT NULL,IsNotForReplication bit NOT NULL);\n"
           "CREATE TABLE #SQLSA_KnownForeignKeys(ParentSchema sysname COLLATE DATABASE_DEFAULT,ParentTable sysname COLLATE DATABASE_DEFAULT,ConstraintName sysname COLLATE DATABASE_DEFAULT);\n"]
    for schema in sorted({t.schema for t in tables}):
        out.append(f"IF SCHEMA_ID({lit(schema)}) IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.schemas WHERE name={lit(schema)} AND principal_id=DATABASE_PRINCIPAL_ID(N'dbo')) THROW 53903,N'Noncanonical product schema ownership.',1;\n")
    for table in tables:
        for cname,*_ in table.foreign_keys:
            out.append(f'INSERT #SQLSA_KnownForeignKeys VALUES({lit(table.schema)},{lit(table.name)},{lit(cname)});\n')
    for ordinal,table in enumerate(tables,1):
        template,_ = constraint_template(table,ordinal)
        # Temp tables must be created in this scope, not in a nested EXEC. Emit
        # unnamed constraints instead; catalog mapping is by shape and column.
        unnamed = re.sub(r'\bCONSTRAINT\s+\[[^\]]+\]\s+', '',template,flags=re.I)
        out.append(unnamed+'\n')
        # An isolated native reference carries GUID-prefixed constraint names.
        # Its metadata is inserted into the parent scope before the child temp
        # table expires. This binds each original name to its exact definition
        # and parent column without a second hand-maintained schema manifest.
        definition_template,names=constraint_template(table,ordinal,False)
        ref_name=q(f'#SQLSA_ConstraintRef_{ordinal}')
        definition_template=definition_template.replace(q(f'#SQLSA_Expected_{ordinal}'),ref_name)
        name_cases=' '.join('WHEN @Prefix+'+lit(short)+' THEN '+lit(original) for short,original in names)
        definition_template+=f"\nINSERT #SQLSA_ConstraintMap SELECT CASE o.name {name_cases} END,c.name,o.type,COALESCE(d.definition,k.definition),COALESCE(k.is_disabled,0),COALESCE(k.is_not_trusted,0),COALESCE(k.is_not_for_replication,0) FROM tempdb.sys.objects o LEFT JOIN tempdb.sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN tempdb.sys.check_constraints k ON k.object_id=o.object_id LEFT JOIN tempdb.sys.columns c ON c.object_id=o.parent_object_id AND c.column_id=COALESCE(d.parent_column_id,k.parent_column_id) WHERE o.parent_object_id=OBJECT_ID({lit('tempdb..'+ref_name)}) AND o.type IN('D','C');"
        out.append('DELETE FROM #SQLSA_ConstraintMap; SET @Prefix=REPLACE(CONVERT(nvarchar(36),NEWID()),N\'-\',N\'\')+N\'_\';\nSET @ConstraintSql='+lit(definition_template)+';\n')
        for short,_ in names:
            out.append('SET @ConstraintSql=REPLACE(@ConstraintSql,'+lit('CONSTRAINT '+q(short))+','+lit('CONSTRAINT [')+'+@Prefix+'+lit(short+']')+');\n')
        out.append("EXEC sys.sp_executesql @ConstraintSql,N'@Prefix nvarchar(33)',@Prefix;\n")
        out.append(f"SET @ExpectedId=OBJECT_ID(N'tempdb..#SQLSA_Expected_{ordinal}'); SET @ObjectId=OBJECT_ID({lit(table.object_name)});\n")
        if strict:
            out.append(f"IF @ObjectId IS NULL THROW 53904,{lit('Canonical table missing after deployment: '+table.object_name)},1;\n")
        out.append(f"IF @ObjectId IS NOT NULL AND OBJECTPROPERTY(@ObjectId,'IsUserTable')<>1 THROW 53904,{lit('Wrong table object type: '+table.object_name)},1;\n")
        out.append('IF @ObjectId IS NOT NULL BEGIN\n')
        out.append(f'SELECT TOP(1) @LockCount=1 FROM {table.object_name} WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1);\n')
        out.append("IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@ObjectId AND (temporal_type<>0 OR is_memory_optimized<>0 OR is_tracked_by_cdc<>0 OR is_replicated<>0 OR is_merge_published<>0 OR is_sync_tran_subscribed<>0 OR is_filetable<>0)) OR EXISTS(SELECT 1 FROM sys.change_tracking_tables WHERE object_id=@ObjectId) OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND (is_computed<>0 OR encryption_type IS NOT NULL OR is_sparse<>0 OR is_column_set<>0 OR generated_always_type<>0 OR is_hidden<>0 OR is_filestream<>0)) OR EXISTS(SELECT 1 FROM sys.indexes AS i JOIN sys.data_spaces AS d ON d.data_space_id=i.data_space_id WHERE i.object_id=@ObjectId AND (d.type<>'FG' OR i.type NOT IN (0,1,2))) THROW 53905,N'Unsupported table feature, trigger, policy or partitioning.',1;\n")
        out.append("IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id=@ObjectId AND data_compression<>0) THROW 53905,N'Noncanonical data compression.',1;\n")
        facets = '[name] COLLATE DATABASE_DEFAULT,[system_type_id],[user_type_id],[max_length],[precision],[scale],[is_nullable],[collation_name] COLLATE DATABASE_DEFAULT,[is_identity],[is_computed]'
        # sysname is the only alias type allowed; cross-database user_type IDs for
        # built-in aliases match, while user-defined types are rejected explicitly.
        additions = table.additions if not strict else []
        allow = ','.join(lit(n) for n in additions) or "N''"
        out.append(f"IF EXISTS(SELECT {facets} FROM sys.columns WHERE object_id=@ObjectId EXCEPT SELECT {facets} FROM tempdb.sys.columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT {facets} FROM tempdb.sys.columns ec WHERE object_id=@ExpectedId AND ([name] COLLATE DATABASE_DEFAULT NOT IN ({allow}) OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=ec.name COLLATE DATABASE_DEFAULT)) EXCEPT SELECT {facets} FROM sys.columns WHERE object_id=@ObjectId) THROW 53906,{lit('Column contract mismatch: '+table.object_name)},1;\n")
        out.append("IF EXISTS(SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId EXCEPT SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId) OR EXISTS(SELECT [seed_value],[increment_value] FROM tempdb.sys.identity_columns WHERE object_id=@ExpectedId EXCEPT SELECT [seed_value],[increment_value] FROM sys.identity_columns WHERE object_id=@ObjectId) THROW 53907,N'Identity contract mismatch.',1;\n")
        # Native SQL Server metadata canonicalizes CHECK expressions and defaults.
        for catalog,fields in [('default_constraints','c.name COLLATE DATABASE_DEFAULT,d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT'),('check_constraints',"d.name COLLATE DATABASE_DEFAULT,d.definition COLLATE DATABASE_DEFAULT,COALESCE(c.name,N'') COLLATE DATABASE_DEFAULT,d.is_disabled,d.is_not_trusted,d.is_not_for_replication")]:
            if catalog == 'default_constraints':
                actual = 'SELECT '+fields+' FROM sys.default_constraints d JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId'
                expected = 'SELECT ParentColumn,CanonicalName,Definition FROM #SQLSA_ConstraintMap k WHERE ConstraintType=\'D\''+f' AND (ParentColumn NOT IN ({allow}) OR EXISTS(SELECT 1 FROM sys.columns a WHERE a.object_id=@ObjectId AND a.name=k.ParentColumn))'
            else:
                actual = 'SELECT '+fields+' FROM sys.'+catalog+' d LEFT JOIN sys.columns c ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@ObjectId'
                expected = "SELECT CanonicalName,Definition,COALESCE(ParentColumn,N''),IsDisabled,IsNotTrusted,IsNotForReplication FROM #SQLSA_ConstraintMap WHERE ConstraintType='C'"
            out.append(f"IF EXISTS({actual} EXCEPT {expected}) OR EXISTS({expected} EXCEPT {actual}) THROW 53908,N'Constraint contract mismatch.',1;\n")
            if catalog=='check_constraints':
                out.append("IF (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=@ObjectId)<>(SELECT COUNT(*) FROM tempdb.sys.check_constraints WHERE parent_object_id=@ExpectedId) THROW 53908,N'Additional CHECK constraint.',1;\n")
        index_fields = 'i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.is_hypothetical,i.has_filter,i.filter_definition COLLATE DATABASE_DEFAULT,ic.key_ordinal,ic.is_descending_key,ic.is_included_column,c.name COLLATE DATABASE_DEFAULT'
        pk=next((name for name,kind in table.constraints if kind=='PRIMARY'),'')
        uq=next((name for name,kind in table.constraints if kind=='UNIQUE'),'')
        expected_name=f'CASE WHEN i.is_primary_key=1 THEN {lit(pk)} WHEN i.is_unique_constraint=1 THEN {lit(uq)} ELSE i.name COLLATE DATABASE_DEFAULT END'
        actual = f'SELECT i.name COLLATE DATABASE_DEFAULT,{index_fields} FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ObjectId'
        expected = f'SELECT {expected_name},{index_fields} FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@ExpectedId'
        out.append(f"IF EXISTS({actual} EXCEPT {expected}) OR EXISTS({expected} EXCEPT {actual}) THROW 53909,N'Index contract mismatch.',1;\n")
        out.append("IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@ExpectedId AND type<>0) THROW 53909,N'Additional index or unique constraint.',1;\n")
        # Names distinguish two otherwise identical indexes. Canonical index names
        # are required for nonconstraint indexes; PK/UQ shape is compared above.
        expected_names = [ident(tokens(index)[2 if upper(tokens(index)[1])=='INDEX' else 3]) for index in table.indexes]
        names_sql = ','.join(lit(n) for n in expected_names) or "N''"
        out.append(f"IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0 AND name NOT IN ({names_sql})) OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@ObjectId AND type<>0 AND is_primary_key=0 AND is_unique_constraint=0)<>{len(expected_names)} THROW 53910,N'Additional or missing named index.',1;\n")
        for cname,kind in table.constraints:
            if kind == 'FOREIGN':
                continue
            out.append(f"IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE parent_object_id=@ObjectId AND name={lit(cname)})")
            # An absent additive column also permits its not-yet-created default.
            if kind == 'DEFAULT' and additions:
                pattern = re.search(r'(\[[^\]]+\])[^,]*?CONSTRAINT\s+(?:'+re.escape(cname)+'|'+re.escape(q(cname))+r')\s+DEFAULT',table.create,re.I)
                column = pattern[1][1:-1] if pattern else ''
                if column in additions:
                    out.append(f" AND EXISTS(SELECT 1 FROM sys.columns WHERE object_id=@ObjectId AND name={lit(column)})")
            out.append(f" THROW 53911,{lit('Missing canonical constraint: '+cname)},1;\n")
        fknames = ','.join(lit(fk[0]) for fk in table.foreign_keys) or "N''"
        out.append(f"IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@ObjectId AND (name NOT IN ({fknames}) OR is_disabled=1 OR is_not_trusted=1 OR is_not_for_replication=1 OR delete_referential_action<>0 OR update_referential_action<>0)) OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@ObjectId)<>{len(table.foreign_keys)} THROW 53912,N'Foreign-key contract mismatch.',1;\n")
        out.append("IF EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.referenced_object_id=@ObjectId AND NOT EXISTS(SELECT 1 FROM #SQLSA_KnownForeignKeys k WHERE k.ParentSchema=OBJECT_SCHEMA_NAME(fk.parent_object_id) AND k.ParentTable=OBJECT_NAME(fk.parent_object_id) AND k.ConstraintName=fk.name)) THROW 53912,N'Noncanonical inbound foreign key.',1;\n")
        for cname,cols,rschema,rtable,rcols in table.foreign_keys:
            pairs = ' OR '.join(f'(fkc.constraint_column_id={i} AND pc.name={lit(c)} AND rc.name={lit(r)})' for i,(c,r) in enumerate(zip(cols,rcols),1))
            out.append(f"IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId AND fk.name={lit(cname)} AND fk.referenced_object_id=OBJECT_ID({lit(q(rschema)+'.'+q(rtable))})) OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id WHERE fk.parent_object_id=@ObjectId AND fk.name={lit(cname)})<>{len(cols)} OR (SELECT COUNT(*) FROM sys.foreign_key_columns fkc JOIN sys.foreign_keys fk ON fk.object_id=fkc.constraint_object_id JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fk.parent_object_id=@ObjectId AND fk.name={lit(cname)} AND ({pairs}))<>{len(cols)} THROW 53912,N'Foreign-key column contract mismatch.',1;\n")
        out.append('END;\n')
    for source in sources:
        if source.module:
            schema,name,otype = source.module
            obj = q(schema)+'.'+q(name)
            out.append(f"IF OBJECT_ID({lit(obj)}) IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.objects WHERE object_id=OBJECT_ID({lit(obj)}) AND type={lit(otype)}) THROW 53913,{lit('Module object type mismatch: '+obj)},1;\n")
            if strict:
                out.append(f"IF OBJECT_ID({lit(obj)}) IS NULL THROW 53913,{lit('Canonical module missing after deployment: '+obj)},1;\n")
                if name!='VW_AnalyseAccessPolicy':
                    out.append(f"IF NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID({lit(obj)}) AND uses_ansi_nulls=1 AND uses_quoted_identifier=1) THROW 53913,{lit('Noncanonical module settings after deployment: '+obj)},1;\n")
    # A custom policy view remains executable operator-owned code. Compare its
    # published output facets, preserving the definition and all policy values.
    policy = next((s for s in sources if s.module and s.module[1]=='VW_AnalyseAccessPolicy'),None)
    if policy:
        bt = tokens(policy.batches[0])
        aspos = next(i for i,t in enumerate(bt) if upper(t)=='AS')
        select = policy.batches[0][bt[aspos].end:].strip().rstrip(';')
        out.append('SELECT TOP(0) * INTO #SQLSA_PolicyExpected FROM ('+select+') AS p;\n')
        out.append("IF OBJECT_ID(N'[monitor].[VW_AnalyseAccessPolicy]') IS NOT NULL BEGIN\n"
                   "SELECT TOP(0) * INTO #SQLSA_PolicyActual FROM [monitor].[VW_AnalyseAccessPolicy];\n")
        fields = 'column_id,name COLLATE DATABASE_DEFAULT,system_type_id,max_length,precision,scale,collation_name COLLATE DATABASE_DEFAULT'
        out.append(f"IF EXISTS(SELECT {fields} FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#SQLSA_PolicyExpected') EXCEPT SELECT {fields} FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#SQLSA_PolicyActual')) OR EXISTS(SELECT {fields} FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#SQLSA_PolicyActual') EXCEPT SELECT {fields} FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#SQLSA_PolicyExpected')) THROW 53914,N'Incompatible operator policy view.',1; END;\n")
    # Predict the actual canonical source-key set in temporary reference tables.
    # This includes the analytical group migration before the source-role seeds.
    # Custom collisions are detected against desired keys before product writes.
    catalog = next(((i,t) for i,t in enumerate(tables,1) if t.name=='WaitTypeCatalog'),None)
    reference = next(((i,t) for i,t in enumerate(tables,1) if t.name=='WaitTypeCatalogSource'),None)
    if catalog and reference:
        ci,ct = catalog
        ri,rt = reference
        out.append("IF OBJECT_ID(N'[monitor].[WaitTypeCatalog]',N'U') IS NOT NULL AND OBJECT_ID(N'[monitor].[WaitTypeCatalogSource]',N'U') IS NOT NULL BEGIN\nDECLARE @WaitColumns nvarchar(max),@WaitCopy nvarchar(max);\n")
        out.append("SELECT @WaitColumns=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(name)),N',') WITHIN GROUP(ORDER BY column_id) FROM sys.columns WHERE object_id=OBJECT_ID(N'[monitor].[WaitTypeCatalog]');\n")
        out.append(f"SET @WaitCopy=N'INSERT [#SQLSA_Expected_{ci}]('+@WaitColumns+N') SELECT '+@WaitColumns+N' FROM [monitor].[WaitTypeCatalog];'; EXEC sys.sp_executesql @WaitCopy;\n")
        seed_sources = [s for s in sources if s.path.startswith('Code/01_Common/074') and not s.path.endswith('074_WaitTypeCatalog.sql')]
        for seed in seed_sources:
            for batch in seed.batches:
                scratch = re.sub(r'-- DEPLOYMENT_PREFLIGHT_BEGIN.*?-- DEPLOYMENT_PREFLIGHT_END','',batch,flags=re.S)
                scratch = scratch.replace(ct.object_name,q(f'#SQLSA_Expected_{ci}')).replace(rt.object_name,q(f'#SQLSA_Expected_{ri}'))
                out.append('EXEC sys.sp_executesql '+lit(scratch)+';\n')
        out.append(f"IF EXISTS(SELECT 1 FROM [monitor].[WaitTypeCatalogSource] s JOIN [#SQLSA_Expected_{ri}] e ON e.WaitType=s.WaitType AND e.SourceOrdinal=s.SourceOrdinal WHERE s.IsFrameworkDefault=0) THROW 53933,N'Custom Wait source collides with a required default source key.',1; END;\n")
        if strict:
            out.append(f"IF EXISTS(SELECT WaitType FROM [#SQLSA_Expected_{ci}] EXCEPT SELECT WaitType FROM [monitor].[WaitTypeCatalog]) THROW 53934,N'Canonical Wait seed key is missing after deployment.',1;\n")
    return ''.join(out)


def archive(tables: list[Table],digest: str,role: str) -> str:
    out = ["SET NOCOUNT ON;\n"
           "IF SCHEMA_ID(N'monitor_deployment') IS NULL BEGIN EXEC(N'CREATE SCHEMA [monitor_deployment] AUTHORIZATION [dbo];'); EXEC sys.sp_addextendedproperty @name=N'SQL_Server_Analyze.DeploymentFormat',@value=1,@level0type=N'SCHEMA',@level0name=N'monitor_deployment'; END;\n"
           "DECLARE @RunName sysname=N'Run_'+REPLACE(CONVERT(varchar(36),@RunId),'-',''),@StateName sysname,@Sql nvarchar(max),@ColumnList nvarchar(max),@RowCount bigint,@Manifest nvarchar(max)=N'[]',@Entry nvarchar(max),@ObjectId int;\n"
           "IF OBJECT_ID(N'[monitor_deployment].'+QUOTENAME(@RunName)) IS NOT NULL THROW 53915,N'Deployment Run-ID collision.',1;\n"]
    for ordinal,table in enumerate(tables,1):
        out.append(f"SET @ObjectId=OBJECT_ID({lit(table.object_name)}); IF @ObjectId IS NOT NULL BEGIN\n"
                   f"SET @StateName=N'State_'+REPLACE(CONVERT(varchar(36),@RunId),'-','')+N'_{ordinal}';\n"
                   "IF OBJECT_ID(N'[monitor_deployment].'+QUOTENAME(@StateName)) IS NOT NULL THROW 53915,N'Deployment State-ID collision.',1;\n"
                   "SELECT @ColumnList=STRING_AGG(CONVERT(nvarchar(max),CASE WHEN c.system_type_id=189 THEN N'CONVERT(binary(8),'+QUOTENAME(c.name)+N') AS '+QUOTENAME(c.name) WHEN c.is_identity=1 THEN N'CONVERT('+t.name+CASE WHEN t.name IN(N'decimal',N'numeric') THEN N'('+CONVERT(nvarchar(3),c.precision)+N','+CONVERT(nvarchar(3),c.scale)+N')' ELSE N'' END+N','+QUOTENAME(c.name)+N') AS '+QUOTENAME(c.name) ELSE QUOTENAME(c.name) END),N',') WITHIN GROUP(ORDER BY c.column_id) FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id WHERE c.object_id=@ObjectId;\n"
                   f"SET @Sql=N'SELECT '+@ColumnList+N' INTO [monitor_deployment].'+QUOTENAME(@StateName)+N' FROM {table.object_name} WITH (TABLOCKX,HOLDLOCK) OPTION(MAXDOP 1); SET @Rows=@@ROWCOUNT;';\n"
                   "EXEC sys.sp_executesql @Sql,N'@Rows bigint OUTPUT',@Rows=@RowCount OUTPUT;\n"
                   f"SET @Entry=(SELECT {lit(table.schema)} AS originalSchema,{lit(table.name)} AS originalObject,@StateName AS archiveName,@RowCount AS [rowCount],\n"
                   "JSON_QUERY((SELECT c.column_id,c.name,t.name AS originalType,c.system_type_id,c.user_type_id,c.max_length,c.precision,c.scale,c.is_nullable,c.collation_name,c.is_identity,CONVERT(bit,CASE WHEN c.system_type_id=189 THEN 1 ELSE 0 END) AS isRowversion,CONVERT(nvarchar(100),ic.seed_value) AS identitySeed,CONVERT(nvarchar(100),ic.increment_value) AS identityIncrement,CONVERT(nvarchar(100),ic.last_value) AS identityLastValue FROM sys.columns c JOIN sys.types t ON t.user_type_id=c.user_type_id LEFT JOIN sys.identity_columns ic ON ic.object_id=c.object_id AND ic.column_id=c.column_id WHERE c.object_id=@ObjectId ORDER BY c.column_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS columns,\n"
                   "JSON_QUERY((SELECT o.name,o.type,OBJECT_DEFINITION(o.object_id) AS definition,COALESCE(d.parent_column_id,k.parent_column_id) AS parentColumnId,COL_NAME(o.parent_object_id,COALESCE(d.parent_column_id,k.parent_column_id)) AS parentColumnName FROM sys.objects o LEFT JOIN sys.default_constraints d ON d.object_id=o.object_id LEFT JOIN sys.check_constraints k ON k.object_id=o.object_id WHERE o.parent_object_id=@ObjectId ORDER BY o.name FOR JSON PATH,INCLUDE_NULL_VALUES)) AS constraints,\n"
                   "JSON_QUERY((SELECT i.name,i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.filter_definition,i.is_disabled,JSON_QUERY((SELECT c.name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id ORDER BY ic.index_column_id FOR JSON PATH)) AS columns FROM sys.indexes i WHERE i.object_id=@ObjectId ORDER BY i.index_id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS indexes,\n"
                   "JSON_QUERY((SELECT fk.name,OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS referencedSchema,OBJECT_NAME(fk.referenced_object_id) AS referencedObject,fk.delete_referential_action,fk.update_referential_action,fk.is_disabled,fk.is_not_trusted,JSON_QUERY((SELECT pc.name AS parentColumn,rc.name AS referencedColumn,fkc.constraint_column_id FROM sys.foreign_key_columns fkc JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id WHERE fkc.constraint_object_id=fk.object_id ORDER BY fkc.constraint_column_id FOR JSON PATH)) AS columns FROM sys.foreign_keys fk WHERE fk.parent_object_id=@ObjectId FOR JSON PATH,INCLUDE_NULL_VALUES)) AS foreignKeys FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);\n"
                   "SET @Manifest=JSON_MODIFY(@Manifest,'append $',JSON_QUERY(@Entry)); END;\n")
    out.append("SET @Sql=N'CREATE TABLE [monitor_deployment].'+QUOTENAME(@RunName)+N'([RunId] uniqueidentifier NOT NULL,[FormatVersion] int NOT NULL,[SourceSha256] binary(32) NOT NULL,[DatabaseRole] varchar(16) NOT NULL,[FrameworkDatabase] sysname NOT NULL,[SnapshotDatabase] sysname NULL,[StartedAtUtc] datetime2(7) NOT NULL,[ReceiptAtUtc] datetime2(7) NOT NULL,[Manifest] nvarchar(max) NOT NULL); INSERT [monitor_deployment].'+QUOTENAME(@RunName)+N'([RunId],[FormatVersion],[SourceSha256],[DatabaseRole],[FrameworkDatabase],[SnapshotDatabase],[StartedAtUtc],[ReceiptAtUtc],[Manifest]) VALUES(@RunId,1,@Digest,@Role,@Framework,@Snapshot,@Started,SYSUTCDATETIME(),@Manifest);';\n"
               f"EXEC sys.sp_executesql @Sql,N'@RunId uniqueidentifier,@Digest binary(32),@Role varchar(16),@Framework sysname,@Snapshot sysname,@Started datetime2(7),@Manifest nvarchar(max)',@RunId,@Digest=0x{digest},@Role='{role}',@Framework=@FrameworkDatabase,@Snapshot=@SnapshotDatabase,@Started=@StartedAtUtc,@Manifest=@Manifest;\n")
    return ''.join(out)


def owns_predicate(predicate: list[Token], target_alias: str | None) -> bool:
    """Require a positive target-owned equality as a mandatory AND conjunct."""
    def unwrap(part):
        while part and part[0].value=='(' and matching(part,0)==len(part)-1:
            part=part[1:-1]
        return part
    predicate=unwrap(predicate)
    parts=[]
    begin=depth=0
    for i,token in enumerate(predicate):
        if token.value=='(':
            depth+=1
        elif token.value==')':
            depth-=1
        elif depth==0:
            if upper(token)=='OR':
                return False
            if upper(token)=='AND':
                parts.append(predicate[begin:i])
                begin=i+1
    parts.append(predicate[begin:])
    for part in parts:
        part=unwrap(part)
        if len(part)==5 and part[1].value=='.':
            if target_alias is None or ident(part[0])!=target_alias:
                continue
            part=part[2:]
        if len(part)==3 and ident(part[0])=='IsFrameworkDefault' and part[1].value=='=' and part[2].value=='1':
            return True
    return False


def dml_target(ts: list[Token], pos: int, end: int) -> tuple[str,str,str | None]:
    if pos+2<end and ts[pos+1].value=='.':
        schema,name,_=qualified(ts,pos)
        return schema,name,None
    target=ident(ts[pos])
    bindings=[]
    depth=0
    for i in range(pos,end):
        token=ts[i]
        if token.value=='(':
            depth+=1
        elif token.value==')':
            depth-=1
        elif depth==0 and upper(token) in ('FROM','JOIN'):
            j=i+1
            if j+2<end and ts[j+1].value=='.':
                schema,name,j=qualified(ts,j)
                physical=(schema,name)
                alias=name
            elif j<end and ident(ts[j]).startswith(('@','#')):
                physical=None
                alias=ident(ts[j])
                j+=1
            else:
                raise BuildError('Only qualified tables or local seed tables are supported in deployment DML')
            if j<end and upper(ts[j])=='AS':
                alias=ident(ts[j+1])
            elif j<end and (ts[j].kind=='identifier' or upper(ts[j]) not in ('WITH','JOIN','INNER','LEFT','RIGHT','FULL','CROSS','OUTER','ON','WHERE','GROUP','ORDER',';')):
                alias=ident(ts[j])
            if alias==target:
                bindings.append(physical)
    if len(bindings)!=1 or bindings[0] is None:
        raise BuildError(f'Unresolved or ambiguous persistent DML target alias: {target}')
    return *bindings[0],target


def generate(root: Path,snapshot: bool=False) -> tuple[str,dict]:
    sources,tables,digest = load_sources(root,snapshot)
    roles = ['FRAMEWORK','SNAPSHOT'] if snapshot else ['FRAMEWORK']
    # A full original state is retained for source-owned DML tables only. Runtime
    # snapshot histories and configuration are preserved in place and not copied.
    mutable = set()
    for source in sources:
        if source.module:
            continue
        ts = tokens(source.text)
        known = {(x.role,x.schema,x.name) for x in tables}
        for i,t in enumerate(ts):
            if upper(t) not in ('UPDATE','DELETE'):
                continue
            pos = i+1
            if upper(ts[pos])=='FROM':
                pos += 1
            end = next((j for j in range(pos,len(ts)) if ts[j].value==';'),len(ts))
            schema,name,target_alias=dml_target(ts,pos,end)
            pair = (source.role,schema,name)
            if pair not in known:
                raise BuildError(f'Unknown deployment DML target: {pair}')
            table=next(x for x in tables if (x.role,x.schema,x.name)==pair)
            if 'IsFrameworkDefault' not in table.columns:
                if upper(t)=='DELETE' or name not in ('FrameworkVersion','PackageVersion'):
                    raise BuildError(f'No owned mutation contract for {pair}')
            else:
                end=next((j for j in range(pos,len(ts)) if ts[j].value==';'),len(ts))
                where=next((j for j in range(pos,end) if upper(ts[j])=='WHERE'),None)
                predicate=ts[where+1:end] if where is not None else []
                if not owns_predicate(predicate,target_alias):
                    raise BuildError(f'Unprotected owned mutation predicate in {source.path}')
            mutable.add(pair)
    out = ["/* Generated from canonical sources. Do not edit source batches here.\n"
           "Set the explicit database data values below; execute the complete file.\n"
           f"Source SHA256: {digest}; optional Snapshot Baseline: {str(snapshot).lower()}. */\n"
           "DECLARE @FrameworkDatabase nvarchar(max)=N'DeineDatenbank',\n"
           "        @SnapshotDatabase nvarchar(max)=NULL;\n"
           "IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)<>0 BEGIN EXEC sys.sp_executesql N'SET XACT_ABORT OFF; RAISERROR(N''Deployment requires no caller transaction and IMPLICIT_TRANSACTIONS OFF.'',16,1);'; RETURN; END;\n"
           "SET NOCOUNT ON; SET XACT_ABORT ON;\n"
           "DECLARE @RunId uniqueidentifier=NEWID(),@StartedAtUtc datetime2(7)=SYSUTCDATETIME(),@DeploymentSql nvarchar(max),@LockResult int;\n"
           "SELECT @RunId AS DeploymentRunId;\n"
           "BEGIN TRY\n"
           "IF @FrameworkDatabase IS NULL OR @FrameworkDatabase=N'DeineDatenbank' OR LEN(@FrameworkDatabase)=0 OR DATALENGTH(@FrameworkDatabase)>256 THROW 53920,N'Choose an explicit framework database name of at most 128 characters.',1;\n"]
    if snapshot:
        out.append("IF @SnapshotDatabase IS NULL OR LEN(@SnapshotDatabase)=0 OR DATALENGTH(@SnapshotDatabase)>256 OR DB_ID(@SnapshotDatabase)=DB_ID(@FrameworkDatabase) THROW 53921,N'Choose a separate explicit snapshot database name of at most 128 characters.',1;\n")
    else:
        out.append("IF @SnapshotDatabase IS NOT NULL THROW 53921,N'This artifact includes Core only.',1;\n")
    for role in roles:
        db = '@FrameworkDatabase' if role=='FRAMEWORK' else '@SnapshotDatabase'
        out.append(f"IF NOT EXISTS(SELECT 1 FROM sys.databases d LEFT JOIN sys.database_mirroring m ON m.database_id=d.database_id WHERE d.name={db} AND d.database_id>4 AND d.state=0 AND d.is_read_only=0 AND d.group_database_id IS NULL AND m.mirroring_guid IS NULL AND HAS_DBACCESS(d.name)=1) THROW 53922,N'Unsupported, inaccessible or missing selected database.',1;\n")
        permission="IF ISNULL(HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','CONTROL'),0)<>1 OR ISNULL(HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY DEFINITION'),0)<>1 THROW 53901,N'Deployment requires CONTROL DATABASE and visible server metadata.',1;"
        out.append(invoke(permission,db,role+' permission gate before locks'))
    out.append('BEGIN TRANSACTION;\n')
    # Native reference DDL and catalog reads share tempdb metadata even when
    # selected product databases differ. Take this common lock first and keep
    # it until the same transaction ends; independent pairs cannot deadlock
    # each other while holding reference-table catalog locks.
    metadata_lock = "DECLARE @Result int; EXEC @Result=sys.sp_getapplock @Resource=N'SQL_Server_Analyze.DeploymentFormat1.TempMetadata',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000,@DbPrincipal=N'public'; IF @Result<0 THROW 53923,N'Deployment tempdb metadata application lock failed.',1;"
    out.append(invoke(metadata_lock,"N'tempdb'",'Acquire the instance-wide tempdb metadata application lock'))
    # Sort database names deterministically, including independent Core deployments.
    out.append("DECLARE @FirstDb sysname=@FrameworkDatabase,@SecondDb sysname=@SnapshotDatabase; IF @SecondDb IS NOT NULL AND @SecondDb COLLATE Latin1_General_100_BIN2<@FirstDb COLLATE Latin1_General_100_BIN2 SELECT @FirstDb=@SnapshotDatabase,@SecondDb=@FrameworkDatabase;\n")
    lock = "DECLARE @Result int; EXEC @Result=sys.sp_getapplock @Resource=N'SQL_Server_Analyze.DeploymentFormat1',@LockMode=N'Exclusive',@LockOwner=N'Transaction',@LockTimeout=10000,@DbPrincipal=N'public'; IF @Result<0 THROW 53923,N'Deployment application lock failed.',1;"
    out.append(invoke(lock,'@FirstDb','Acquire the first database application lock'))
    if snapshot:
        out.append(invoke(lock,'@SecondDb','Acquire the second database application lock'))
    for role in roles:
        out.append(invoke(preflight([t for t in tables if t.role==role],[s for s in sources if s.role==role]),'@FrameworkDatabase' if role=='FRAMEWORK' else '@SnapshotDatabase',role+' complete preflight before product writes'))
    # Seed conflict guards execute before archives or any product batch. Those
    # guards are derived from and colocated with canonical source seed contracts.
    for source in sources:
        for batch in source.batches:
            if 'DEPLOYMENT_PREFLIGHT_BEGIN' in batch:
                begin = batch.index('-- DEPLOYMENT_PREFLIGHT_BEGIN')
                end = batch.index('-- DEPLOYMENT_PREFLIGHT_END',begin)
                out.append(invoke(batch[begin:end],'@FrameworkDatabase' if source.role=='FRAMEWORK' else '@SnapshotDatabase',source.path+' seed preflight'))
    for role in roles:
        statement = archive([t for t in tables if t.role==role and (t.role,t.schema,t.name) in mutable],digest,role)
        db = '@FrameworkDatabase' if role=='FRAMEWORK' else '@SnapshotDatabase'
        # Archive receives the shared Run-ID and explicit contexts as parameters.
        out.append(f"SET @DeploymentSql=N'USE '+QUOTENAME({db})+N'; SET LOCK_TIMEOUT 10000; '+{lit(statement)};\nEXEC sys.sp_executesql @DeploymentSql,N'@RunId uniqueidentifier,@FrameworkDatabase sysname,@SnapshotDatabase sysname,@StartedAtUtc datetime2(7)',@RunId,@FrameworkDatabase,@SnapshotDatabase,@StartedAtUtc;\n")
    for source in sources:
        # Legacy objects remain in place in the lossless route. Older explicit
        # legacy installer behavior is kept separate from this source-derived route.
        if source.path=='Code/09_VersionAdaptive/005_Deprecated_Object_Cleanup.sql':
            out.append('-- BEGIN SOURCE: '+source.path+'\n-- Lossless route preserves existing legacy objects in place.\n-- END SOURCE: '+source.path+'\n')
            continue
        out.append('-- BEGIN SOURCE: '+source.path+'\n')
        for batch in source.batches:
            if source.module and source.module[1]=='VW_AnalyseAccessPolicy':
                statement = "IF OBJECT_ID(N'[monitor].[VW_AnalyseAccessPolicy]') IS NULL EXEC sys.sp_executesql "+lit(batch)+';'
            else:
                statement = batch
            out.append(invoke(statement,'@FrameworkDatabase' if source.role=='FRAMEWORK' else '@SnapshotDatabase'))
        out.append('-- END SOURCE: '+source.path+'\n')
    for role in roles:
        out.append(invoke(preflight([t for t in tables if t.role==role],[s for s in sources if s.role==role],True),'@FrameworkDatabase' if role=='FRAMEWORK' else '@SnapshotDatabase',role+' final structural verification'))
    out.append("IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 53924,N'Deployment transaction state changed unexpectedly.',1;\nCOMMIT TRANSACTION;\nSELECT @RunId AS DeploymentRunId,0x"+digest+" AS SourceSha256,N'COMMITTED' AS DeploymentStatus;\nEND TRY\nBEGIN CATCH\nIF XACT_STATE()<>0 ROLLBACK TRANSACTION;\nTHROW;\nEND CATCH;\n")
    return ''.join(out),{'sources':len(sources),'tables':len(tables),'digest':digest,'archives':len(mutable)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository-root',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--include-snapshot-baseline',action='store_true')
    args = parser.parse_args()
    try:
        sql,report = generate(args.repository_root.resolve(),args.include_snapshot_baseline)
        args.output.parent.mkdir(parents=True,exist_ok=True)
        temporary = args.output.with_suffix(args.output.suffix+'.tmp')
        temporary.write_text(sql,encoding='utf-8',newline='\n')
        temporary.replace(args.output)
        print('Generated lossless deployment: '+json.dumps(report,sort_keys=True))
    except (BuildError,OSError) as error:
        parser.exit(1,'DEPLOYMENT_BUILD_FAILED: '+str(error)+'\n')


if __name__=='__main__':
    main()
