#!/usr/bin/env python3
"""Validate the bounded Database Mirroring inventory contract and bindings."""
from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

PROCEDURE = "Code/08_ServerHealth/310_USP_DatabaseMirroringInventory.sql"
RUNTIME = "Code/Tests/ServerHealth/141_DatabaseMirroringInventory_Runtime_Contract.sql"
CANDIDATE_HELPER = "Code/01_Common/083_USP_PrepareDatabaseCandidates.sql"
RESULT_TABLES_HELPER = "Code/01_Common/096_USP_InternalPrepareResultTables.sql"
WRITE_RESULT_TABLE_HELPER = "Code/01_Common/095_USP_InternalWriteResultTable.sql"
CONSOLE_RESULT_HELPER = "Code/01_Common/098_USP_InternalEmitConsoleResult.sql"
RESULT_NAMES = ("moduleStatus", "databaseMirroring", "sourceStatus", "warnings")
PARAMETERS = (
    ("DatabaseNames", "nvarchar(max)", "NULL"),
    ("SystemdatenbankenEinbeziehen", "bit", "0"),
    ("DatabaseNamePattern", "nvarchar(4000)", "NULL"),
    ("MaxZeilen", "int", "1000"),
    ("ResultSetArt", "varchar(16)", "'CONSOLE'"),
    ("ResultTablesJson", "nvarchar(max)", "NULL"),
    ("JsonErzeugen", "bit", "0"),
    ("Json", "nvarchar(max)", "NULL OUTPUT"),
    ("PrintMeldungen", "bit", "1"),
    ("Hilfe", "bit", "0"),
    ("StatusCodeOut", "varchar(40)", "NULL OUTPUT"),
    ("IsPartialOut", "bit", "NULL OUTPUT"),
    ("ErrorNumberOut", "int", "NULL OUTPUT"),
    ("ErrorMessageOut", "nvarchar(2048)", "NULL OUTPUT"),
)
FIELDS = (
    ("DatabaseId", "int", "NOT NULL"),
    ("DatabaseName", "sysname", "NOT NULL"),
    ("MirroringState", "tinyint", "NULL"),
    ("MirroringStateDesc", "nvarchar(60)", "NULL"),
    ("MirroringRole", "tinyint", "NULL"),
    ("MirroringRoleDesc", "nvarchar(60)", "NULL"),
    ("MirroringSafetyLevel", "tinyint", "NULL"),
    ("MirroringSafetyLevelDesc", "nvarchar(60)", "NULL"),
    ("MirroringWitnessState", "tinyint", "NULL"),
    ("MirroringWitnessStateDesc", "nvarchar(60)", "NULL"),
    ("ConfiguredRedoQueueLimitMb", "int", "NULL"),
    ("RedoQueueLimitType", "nvarchar(60)", "NULL"),
)

def csv_rows(value: str) -> list[list[str]]:
    return list(csv.reader(value.splitlines()))


def sql_tokens(source: str) -> tuple[tuple[str, str], ...]:
    """Tokenize executable T-SQL while dropping comments and string literals."""
    tokens: list[tuple[str, str]] = []
    i = 0
    while i < len(source):
        if source[i].isspace():
            i += 1
            continue
        if source.startswith("--", i):
            end = source.find("\n", i + 2)
            i = len(source) if end < 0 else end + 1
            continue
        if source.startswith("/*", i):
            i += 2
            depth = 1
            while i < len(source) and depth:
                if source.startswith("/*", i):
                    depth += 1
                    i += 2
                elif source.startswith("*/", i):
                    depth -= 1
                    i += 2
                else:
                    i += 1
            continue
        if source[i] == "'":
            i += 1
            while i < len(source):
                if source[i] == "'":
                    if i + 1 < len(source) and source[i + 1] == "'":
                        i += 2
                    else:
                        i += 1
                        break
                else:
                    i += 1
            continue
        if source[i] == "[":
            i += 1
            value = []
            while i < len(source):
                if source[i] == "]":
                    if i + 1 < len(source) and source[i + 1] == "]":
                        value.append("]")
                        i += 2
                    else:
                        i += 1
                        break
                else:
                    value.append(source[i])
                    i += 1
            tokens.append(("IDENT", "".join(value)))
            continue
        if source[i] == '"':
            i += 1
            value = []
            while i < len(source):
                if source[i] == '"':
                    if i + 1 < len(source) and source[i + 1] == '"':
                        value.append('"')
                        i += 2
                    else:
                        i += 1
                        break
                else:
                    value.append(source[i])
                    i += 1
            tokens.append(("IDENT", "".join(value)))
            continue
        if source[i] == "@" and i + 1 < len(source) and source[i + 1].isalpha():
            start = i
            i += 2
            while i < len(source) and (source[i].isalnum() or source[i] in "_#$"):
                i += 1
            tokens.append(("PARAM", source[start:i]))
            continue
        if source[i].isalpha() or source[i] == "_":
            start = i
            i += 1
            while i < len(source) and (source[i].isalnum() or source[i] in "_#$"):
                i += 1
            tokens.append(("WORD", source[start:i]))
            continue
        tokens.append(("SYMBOL", source[i]))
        i += 1
    return tuple(tokens)


def _keyword(sql_token: tuple[str, str], expected: str) -> bool:
    return sql_token[0] == "WORD" and sql_token[1].casefold() == expected.casefold()


def _name(sql_token: tuple[str, str], expected: str) -> bool:
    return sql_token[0] in ("IDENT", "WORD") and sql_token[1] == expected


def required_helper_parameters(source: str, procedure_name: str) -> tuple[str, ...] | None:
    tokens = sql_tokens(source)
    header = (
        ("WORD", "CREATE"), ("WORD", "OR"), ("WORD", "ALTER"),
        ("WORD", "PROCEDURE"),
    )
    for start in range(max(0, len(tokens) - 6)):
        if not all(_keyword(tokens[start + offset], word) for offset, (_, word) in enumerate(header)):
            continue
        if not (_name(tokens[start + 4], "monitor") and tokens[start + 5] == ("SYMBOL", ".")
                and _name(tokens[start + 6], procedure_name)):
            continue
        signature = tokens[start + 7:]
        end = next((i for i, sql_token in enumerate(signature) if _keyword(sql_token, "AS")), None)
        if end is None:
            return None
        signature = signature[:end]
        parameters: list[tuple[str, bool]] = []
        cross_seen = False
        positions = [i for i, sql_token in enumerate(signature) if sql_token[0] == "PARAM"]
        for ordinal, position in enumerate(positions):
            next_position = positions[ordinal + 1] if ordinal + 1 < len(positions) else len(signature)
            declaration = signature[position:next_position]
            has_default = any(sql_token == ("SYMBOL", "=") for sql_token in declaration)
            is_output = any(_keyword(sql_token, "OUTPUT") for sql_token in declaration)
            parameters.append((signature[position][1], has_default))
            if signature[position][1] == "@CrossDatabaseRequested":
                cross_seen = True
                if has_default or not is_output:
                    return None
        if procedure_name.casefold() == "usp_preparedatabasecandidates" and not cross_seen:
            return None
        return tuple(name for name, has_default in parameters if not has_default)
    return None


def helper_call_arguments(body: str, procedure_name: str) -> tuple[tuple[str, ...], ...]:
    tokens = sql_tokens(body)
    calls: list[tuple[str, ...]] = []
    for i in range(len(tokens) - 5):
        if not (_keyword(tokens[i], "EXEC") or _keyword(tokens[i], "EXECUTE")):
            continue
        if not (_name(tokens[i + 1], "monitor") and tokens[i + 2] == ("SYMBOL", ".")
                and _name(tokens[i + 3], procedure_name)):
            continue
        end = next((j for j in range(i + 4, len(tokens)) if tokens[j] == ("SYMBOL", ";")), len(tokens))
        arguments = tokens[i + 4:end]
        supplied = tuple(
            arguments[j][1]
            for j in range(len(arguments) - 1)
            if arguments[j][0] == "PARAM" and arguments[j + 1] == ("SYMBOL", "=")
        )
        calls.append(supplied)
    return tuple(calls)

def validate_contract(
    procedure: str, runtime: str, candidate_helper: str, objects: str, parameters: str,
    resultsets: str, sources: str, maturity: str, coverage: str,
    procedure_guide: str, guide_index: str, call_catalog: str,
    release_gate: str, installer: str, generated: str, ops_install: str,
    ops_update: str, docs_review: str, dossier: str,
    result_tables_helper: str, write_result_table_helper: str,
    console_result_helper: str,
) -> list[str]:
    errors: list[str] = []
    proc_marker = "CREATE OR ALTER PROCEDURE [monitor].[USP_DatabaseMirroringInventory]"
    start = procedure.find(proc_marker)
    signature_end = procedure.find("AS", start + len(proc_marker))
    if start < 0 or signature_end < 0:
        return ["canonical procedure declaration or parameter signature is missing"]
    signature = procedure[start + len(proc_marker):signature_end]
    actual_params = []
    for line in signature.splitlines():
        if "@" not in line or "=" not in line:
            continue
        left, default = line.split("=", 1)
        parts = left.strip().lstrip(",").split()
        if len(parts) < 2 or not parts[0].startswith("@"):
            continue
        actual_params.append((parts[0][1:], parts[1], default.strip().rstrip(",").strip()))
    if tuple((n.lower(),t.lower(),d.lower()) for n,t,d in actual_params) != tuple((n.lower(),t.lower(),d.lower()) for n,t,d in PARAMETERS):
        errors.append("public parameter names, order, types, defaults, or OUTPUT modes differ from the dossier")

    body = procedure[signature_end:]
    help_start = body.find("IF @Hilfe=1")
    help_end = body.find("END;", help_start) if help_start >= 0 else -1
    help_block = body[help_start:help_end] if help_start >= 0 and help_end >= 0 else ""
    if not help_block:
        errors.append("help branch is absent or has no bounded ending")
    help_prints = []
    for line in help_block.splitlines():
        marker = "PRINT N'"
        position = line.find(marker)
        if position < 0 or not line.endswith("';"):
            continue
        encoded = line[position + len(marker):-2]
        help_prints.append(encoded.replace("''", "'"))
    help_text = "\n".join(help_prints)
    if not help_prints:
        errors.append("help branch has no literal PRINT documentation")
    for name, typ, default in PARAMETERS:
        expected = "@" + name + " " + typ + "=" + default
        if expected not in help_text:
            errors.append("help parameter default or OUTPUT mode differs: @" + name)
    for sql_token in ("CONSOLE", "RAW", "TABLE", "NONE", "schemaVersion=1", "RESTORING",
                  "AVAILABLE_LIMITED", "VIEW SERVER PERFORMANCE STATE",
                  "keine weitere Serverberechtigung", "sysadmin", "like:", "regex:",
                  "regexi:", "SQL Server 2025", "170", "#Monitor", "116 Zeichen",
                  "@DatabaseNamePattern=N'like:Prod%'", "1 schließt sie ein",
                  "@Json=@Json OUTPUT"):
        if sql_token not in help_text:
            errors.append("help omits required option, output, permission, or scope detail: " + sql_token)
    mapping = "{\"moduleStatus\":\"#DbmiModule\",\"databaseMirroring\":\"#DbmiRows\",\"sourceStatus\":\"#DbmiSources\",\"warnings\":\"#DbmiWarnings\"}"
    if mapping not in help_text:
        errors.append("help TABLE mapping does not identify all four exact result names and local targets")
    if "exakt und Pattern schließen einander aus" not in help_text:
        errors.append("help must state the shared helper's mutually exclusive exact-name and pattern rule")
    if "@DatabaseNamePattern=N'like:Prod%', @ResultSetArt='CONSOLE'" not in help_text or "@DatabaseNames=N'[ExampleDatabase]'" not in help_text:
        errors.append("help examples do not demonstrate valid canonical pattern and exact-name selectors")
    json_example = "@DatabaseNames=N'[ExampleDatabase]', @JsonErzeugen=1, @Json=@Json OUTPUT; SELECT @Json AS [Json]"
    if json_example not in help_text:
        errors.append("help JSON example must capture the OUTPUT parameter and return it to the caller")
    if "@EffectiveDatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL" not in candidate_helper:
        errors.append("shared candidate helper no longer enforces the documented exact-name/pattern exclusion")
    if "@DatabaseNames=@DatabaseNames" not in body or "@DatabaseNamePattern=@DatabaseNamePattern" not in body:
        errors.append("procedure does not pass both documented selector parameters to the shared helper")
    selector_normalization = "NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NOT NULL"
    selector_pattern = "@DatabaseNamePattern IS NOT NULL"
    help_end = body.find("END;", help_start) if help_start >= 0 else -1
    guard_pos = body.find(selector_normalization)
    first_temp = body.find("CREATE TABLE [#DatabaseMirroringInventory_moduleStatus]")
    validation_pos = body.find("IF @Mode NOT IN")
    validation_end = body.find("END;", validation_pos) if validation_pos >= 0 else -1
    validation_block = body[validation_pos:validation_end] if validation_pos >= 0 and validation_end >= 0 else ""
    if (selector_pattern not in validation_block or selector_normalization not in validation_block
            or "@ErrorNumberOut=51011" not in validation_block or "RETURN 51011;" not in validation_block
            or help_end < 0 or not (help_end < validation_pos < guard_pos < first_temp)):
        errors.append("nonblank exact-name plus pattern conflict must return INVALID_PARAMETER after help and before source/temp work; blank exact names normalize to no selector")
    if help_start < 0 or "USP_PrepareDatabaseCandidates" in body[:help_start] or "sys.database_mirroring" in body[:help_start]:
        errors.append("help must return before database selection or source access")
    if "@DatabaseNames" not in help_block or "@DatabaseNamePattern" not in help_block or "getrennt" not in help_block.lower():
        errors.append("help must explain separate exact-name and pattern selectors")
    if "[ExampleDatabase]" not in help_block:
        errors.append("help must include a canonical monitor call with a synthetic example database")

    helpers = (
        ("USP_PrepareDatabaseCandidates", candidate_helper),
        ("InternalPrepareResultTables", result_tables_helper),
        ("InternalWriteResultTable", write_result_table_helper),
        ("InternalEmitConsoleResult", console_result_helper),
    )
    for helper_name, helper_source in helpers:
        required = required_helper_parameters(helper_source, helper_name)
        calls = helper_call_arguments(body, helper_name)
        if required is None:
            if helper_name == "USP_PrepareDatabaseCandidates":
                errors.append("shared candidate helper CrossDatabaseRequested output must remain required without a default")
            else:
                errors.append("required-helper signature source is missing or malformed: " + helper_name)
            continue
        if not calls:
            errors.append("required-helper call is missing: " + helper_name)
            continue
        if len(calls) != 1:
            errors.append("duplicate required-helper calls are not permitted: " + helper_name)
        for supplied in calls:
            for parameter in required:
                if parameter not in supplied:
                    errors.append("shared helper call omits required parameter " + parameter + " for " + helper_name)

    if "@MaxZeilen<0" not in body or "@MaxZeilen IS NULL OR @MaxZeilen=0" not in body:
        errors.append("negative and NULL/zero row-limit semantics are missing")
    if "@Mode NOT IN ('CONSOLE','RAW','TABLE','NONE')" not in body:
        errors.append("CONSOLE/RAW/TABLE/NONE mode validation is incomplete")
    if "SET LOCK_TIMEOUT 0" not in body or "@RestoreLock" not in body:
        errors.append("source LOCK_TIMEOUT 0 and caller restoration are required")
    if "SET XACT_ABORT OFF" not in body or "@PreviousXactAbort" not in body:
        errors.append("caller XACT_ABORT preservation is missing")
    if "SET TRANSACTION ISOLATION LEVEL" in body:
        errors.append("procedure must preserve caller isolation without setting it")
    for source in ("[master].[sys].[databases] AS [d] WITH (NOLOCK)",
                   "[master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)"):
        if source not in body:
            errors.append("native source is not directly bound with NOLOCK: " + source)
    if "ON [m].[database_id]=[d].[database_id]" not in body or "[c].[DatabaseId]" not in body:
        errors.append("database selection and native catalog rows must join by database_id")
    for forbidden in ("mirroring_guid", "mirroring_partner_name", "mirroring_partner_instance",
                      "mirroring_witness_name", "mirroring_failover_lsn",
                      "mirroring_end_of_log_lsn", "mirroring_replication_lsn",
                      "EXECUTE AS", "OPENQUERY", "OPENDATASOURCE", "BEGIN TRANSACTION",
                      "COMMIT TRANSACTION", "ROLLBACK TRANSACTION", "GRANT ", "REVOKE "):
        if forbidden.lower() in body.lower():
            errors.append("out-of-scope or unsafe source field/operation: " + forbidden)
    for field, typ, nullability in FIELDS:
        declaration = next((line for line in body.splitlines() if "[" + field + "] " + typ in line), "")
        if not declaration or nullability not in declaration:
            errors.append("business ABI field/type is missing: " + field)
    raw_start = body.find("IF @Mode='RAW'")
    raw_end = body.find("ELSE IF @Mode='TABLE'", raw_start)
    raw = body[raw_start:raw_end] if raw_start >= 0 and raw_end >= 0 else ""
    positions = [raw.find("SELECT * FROM [#DatabaseMirroringInventory_" + name + "]") for name in RESULT_NAMES]
    if any(pos < 0 for pos in positions) or positions != sorted(positions):
        errors.append("RAW resultsets do not match the frozen four-set order")
    if "@AllowedResultNames=N'moduleStatus|databaseMirroring|sourceStatus|warnings'" not in body:
        errors.append("TABLE whitelist differs from the frozen four-result contract")
    for name in RESULT_NAMES:
        if "@Json_" + name not in body:
            errors.append("JSON array is missing for " + name)
    if "N'DatabaseMirroringInventory' AS [resultName],1 AS [schemaVersion]" not in body:
        errors.append("JSON metadata name or schemaVersion is not bound to V1")
    if "FOR JSON PATH,INCLUDE_NULL_VALUES" not in body:
        errors.append("JSON arrays must preserve native NULL values")
    if "AVAILABLE_LIMITED" not in body or "IsPartial" not in body:
        errors.append("successful inventory must remain explicitly partial and limited")
    for status in ("DENIED_PERMISSION", "ERROR_HANDLED", "SOURCE_UNAVAILABLE",
                   "ROLE_VISIBILITY_LIMIT", "MIRRORING_NULLS_UNINTERPRETED"):
        if status not in body:
            errors.append("source failure or native interpretation boundary is missing: " + status)
    if "@Status='ERROR_HANDLED'" not in body or "@StatusCodeOut='INVALID_PARAMETER'" not in body:
        errors.append("caught errors or invalid parameters may be reported as successful empty inventory")

    schema = resultsets.replace("COLLATE SQL_Latin1_General_CP1_CS_AS ", "")
    schema_shape = ", ".join("[" + n + "] " + t + " " + null for n,t,null in FIELDS)
    if schema_shape not in schema:
        errors.append("ResultSets.csv physical business schema/order differs from the dossier")
    result_rows = [r for r in csv_rows(resultsets) if r and r[0] == "USP_DatabaseMirroringInventory"]
    if tuple(r[1] for r in result_rows) != RESULT_NAMES:
        errors.append("ResultSets.csv must register exactly the four frozen result names in order")
    object_rows = [r for r in csv_rows(objects) if len(r) >= 3 and r[1] == "USP_DatabaseMirroringInventory"]
    if object_rows != [["PROCEDURE", "USP_DatabaseMirroringInventory", PROCEDURE]]:
        errors.append("Objects.csv must bind one canonical procedure source path")
    parameter_rows = [r for r in csv_rows(parameters) if len(r) >= 4 and r[0] == "USP_DatabaseMirroringInventory"]
    if tuple((r[1],r[2],r[3]) for r in parameter_rows) != PARAMETERS:
        errors.append("Parameters.csv does not match the public 14-parameter API in order")
    if "sys.database_mirroring" not in sources or PROCEDURE not in sources:
        errors.append("SystemSources.csv omits the catalog or canonical module binding")
    if "Database Mirroring,USP_DatabaseMirroringInventory,PLANNED,NO,NO,NO,,PARTIAL" not in maturity:
        errors.append("module maturity must remain PLANNED with no unearned native evidence")
    if "DATABASE_MIRRORING" not in coverage or "PARTIAL_PRODUCT_FUNCTION" not in coverage or "RESTORING" not in coverage:
        errors.append("WI-0010 intake must record only the implemented partial scope")
    if "RESTORING" not in procedure_guide or "VIEW SERVER PERFORMANCE STATE" not in procedure_guide or "mirroring_" not in procedure_guide:
        errors.append("public procedure guide omits selector, permission, or native NULL boundary")
    if "USP_DatabaseMirroringInventory" not in guide_index or "USP_DatabaseMirroringInventory" not in call_catalog:
        errors.append("human navigation or public examples omit the procedure")
    if "USP_DatabaseMirroringInventory" not in dossier or "RESTORING" not in dossier:
        errors.append("architecture dossier does not bind the ONLINE-only selection limit")
    if release_gate.count("141_DatabaseMirroringInventory_Runtime_Contract.sql") != 1:
        errors.append("runtime contract 141 must be bound exactly once in the existing release gate")
    if "CAST(34 AS int)" not in release_gate:
        errors.append("nested Phase 7 contract must not create a new top-level release suite")
    if installer.count("310_USP_DatabaseMirroringInventory.sql") != 1:
        errors.append("canonical deployment installer must include the procedure exactly once")
    if generated and generated.count("-- BEGIN SOURCE: Code/08_ServerHealth/310_USP_DatabaseMirroringInventory.sql") != 1:
        errors.append("available generated deployment artifact must contain the procedure exactly once")
    if ops_install.count("-- BEGIN SOURCE: Code/08_ServerHealth/310_USP_DatabaseMirroringInventory.sql") != 1:
        errors.append("OPS-005 install/update snapshots must contain the new procedure exactly once")
    if "USP_DatabaseMirroringInventory,BASELINE,,1" not in docs_review:
        errors.append("documentation review manifest omits the new procedure page")

    for sql_token in ("MIRRORING_NULLS_UNINTERPRETED", "ROLE_VISIBILITY_LIMIT", "DENIED_PERMISSION",
                  "SET LOCK_TIMEOUT 0"):
        if sql_token not in runtime:
            errors.append("runtime fixture misses contract case: " + sql_token)
    for sql_token in ("#DbmiOut_moduleStatus]([Seed] int NULL)",
                  "#DbmiOut_databaseMirroring]([Seed] int NULL)",
                  "#DbmiOut_sourceStatus]([Seed] int NULL)",
                  "#DbmiOut_warnings]([Seed] int NULL)"):
        if sql_token not in runtime:
            errors.append("runtime fixture lacks empty one-Seed TABLE target: " + sql_token)
    for sql_token in ("TYPE_NAME([c].[system_type_id])", "[c].[max_length]", "[c].[precision]",
                  "[c].[scale]", "[c].[is_nullable]", "[c].[collation_name]",
                  "[c].[is_identity]", "[c].[is_computed]"):
        if sql_token not in runtime:
            errors.append("physical ABI oracle misses column facet: " + sql_token)
    abi_start = runtime.find("SET @AbiSql=N'")
    abi_end = runtime.find("EXEC [sys].[sp_executesql] @AbiSql;", abi_start)
    abi_contract = runtime[abi_start:abi_end] if abi_start >= 0 and abi_end >= 0 else ""
    if abi_contract.count("ROW_NUMBER() OVER(ORDER BY [c].[column_id]) AS [Ordinal]") != 4:
        errors.append("physical ABI oracle must map source column_id gaps to dense one-based ordinals in both directions")
    if abi_contract.count("EXCEPT") != 2 or "OR EXISTS" not in abi_contract:
        errors.append("physical ABI oracle must compare actual and expected metadata in both directions")
    for facet in ("[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName]",
                  "TYPE_NAME([c].[system_type_id]) COLLATE SQL_Latin1_General_CP1_CS_AS AS [BaseType]",
                  "[c].[max_length] AS [MaxLength]", "[c].[precision] AS [Precision]",
                  "[c].[scale] AS [Scale]", "[c].[is_nullable] AS [IsNullable]",
                  "[c].[collation_name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [CollationName]",
                  "[c].[is_identity] AS [IsIdentity]", "[c].[is_computed] AS [IsComputed]"):
        if abi_contract.count(facet) != 4:
            errors.append("physical ABI oracle must compare every column facet in both directions: " + facet)
    if "[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName]" not in abi_contract:
        errors.append("physical ABI column-name matching must be explicitly case-sensitive")
    expected_json_fields = "VALUES (N'DatabaseId',0),(N'DatabaseName',0),(N'MirroringState',1),(N'MirroringStateDesc',1),(N'MirroringRole',1),(N'MirroringRoleDesc',1),(N'MirroringSafetyLevel',1),(N'MirroringSafetyLevelDesc',1),(N'MirroringWitnessState',1),(N'MirroringWitnessStateDesc',1),(N'ConfiguredRedoQueueLimitMb',1),(N'RedoQueueLimitType',1);"
    json_key_checks = (
        "DECLARE @ExpectedJsonFields TABLE",
        "DECLARE @ActualJsonFields TABLE",
        expected_json_fields,
        "IF (SELECT COUNT(*) FROM @ActualJsonFields)<>12",
        "EXCEPT SELECT [FieldName] FROM @ActualJsonFields",
        "EXCEPT SELECT [FieldName] FROM @ExpectedJsonFields",
        "GROUP BY [FieldName] HAVING COUNT(*)<>1",
        "WHERE ([e].[MustBeNull]=1 AND [a].[JsonType]<>0)",
        "OR ([e].[MustBeNull]=0 AND [a].[JsonType]=0)",
    )
    if "OPENJSON(@JsonNull,N'$.databaseMirroring')" not in runtime:
        errors.append("runtime fixture must inspect the one native tempdb JSON object")
    for token in json_key_checks:
        if token not in runtime:
            errors.append("runtime fixture must prove all twelve JSON keys exactly once and all ten nullable values null: " + token)
    for sql_token in ("@MaxZeilen=1", "@SourceRows<2", "@MaxZeilen=0", "@MaxZeilen=NULL"):
        if sql_token not in runtime:
            errors.append("runtime limit cases must prove one-row and both unlimited forms: " + sql_token)
    for sql_token in ("@DatabaseNames=N'  ',@SystemdatenbankenEinbeziehen=1,",
                      "@DatabaseNamePattern=N'like:tempdb'", "THROW 57450"):
        if sql_token not in runtime:
            errors.append("runtime fixture must prove blank exact names normalize before valid pattern selection: " + sql_token)
    for sql_token in ("N'[Codex_Missing_Database]'", "@DatabaseNamePattern=N'like:%'",
                  "DENY VIEW SERVER PERFORMANCE STATE", "REVERT;", "DROP LOGIN", "DROP USER"):
        if sql_token not in runtime:
            errors.append("runtime fixture misses restricted/negative cleanup case: " + sql_token)
    if "IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) NOT IN (15,16,17)" not in runtime:
        errors.append("runtime fixture must admit its existing SQL Server 2019/2022/2025 release-gate targets")
    if "IF @ProductMajor>=16" not in runtime or "SQL Server 2019: no minimum catalog-denial permission is asserted" not in runtime:
        errors.append("runtime fixture must version-scope the 2022+ permission-denial case and state the 2019 boundary")
    if "sp_executesql] N'DROP USER" in runtime or "sp_executesql] N'DROP LOGIN" in runtime:
        errors.append("runtime cleanup passes concatenated expressions directly to sp_executesql instead of a variable")
    for sql_token in ("SET @Sql=N'DROP USER '+QUOTENAME(@Login)+N';';\n    EXEC [sys].[sp_executesql] @Sql;",
                  "SET @Sql=N'DROP LOGIN '+QUOTENAME(@Login)+N';';\n    EXEC [sys].[sp_executesql] @Sql;"):
        if sql_token not in runtime:
            errors.append("runtime fixture must assign each dynamic cleanup batch before sp_executesql")
    for mode in ("TABLE", "RAW", "CONSOLE", "NONE"):
        if "@ResultSetArt='" + mode + "'" not in runtime:
            errors.append("runtime fixture omits output mode " + mode)
    for source in ("master].[sys].[databases] AS [d] WITH (NOLOCK)",
                   "master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)"):
        if source not in runtime:
            errors.append("runtime oracle misses native NOLOCK source: " + source)
    for sql_token in ("BEGIN TRANSACTION", "ROLLBACK TRANSACTION", "@@LOCK_TIMEOUT<>137",
                  "transaction_isolation_level", "@@TRANCOUNT<>1"):
        if sql_token not in runtime:
            errors.append("runtime fixture misses caller-state condition: " + sql_token)
    isolation_check = "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;"
    isolation_level = "transaction_isolation_level] FROM sys.dm_exec_sessions WHERE [session_id]=@@SPID)<>3"
    if isolation_check not in runtime or isolation_level not in runtime or "THROW 57448" not in runtime:
        errors.append("runtime fixture must verify REPEATABLE READ as sys.dm_exec_sessions isolation level 3")
    caller_checks = (
        ("IF @Return<>0", "57440"),
        ("IF @Status<>'AVAILABLE_LIMITED'", "57441"),
        ("IF @Partial<>1", "57442"),
        ("IF ISJSON(@Json)<>1", "57443"),
        ("IF @@TRANCOUNT<>1", "57444"),
        ("IF XACT_STATE()<>1", "57445"),
        ("IF @@LOCK_TIMEOUT<>137", "57446"),
        ("IF (@@OPTIONS&16384)=0", "57447"),
        ("IF (SELECT [transaction_isolation_level] FROM sys.dm_exec_sessions WHERE [session_id]=@@SPID)<>3", "57448"),
        ("IF (SELECT COUNT(*) FROM [#DbmiMarker] WHERE [Marker]=57412)<>1", "57449"),
    )
    for condition, error_number in caller_checks:
        if condition + "\n        THROW " + error_number + "," not in runtime:
            errors.append("caller preservation condition must have its own fixed error: " + error_number)
    if "THROW 57413," in runtime:
        errors.append("caller preservation checks may not be recombined into the former aggregate assertion")
    for check in range(57440, 57450):
        if f"THROW {check}," not in runtime:
            errors.append(f"caller TABLE acceptance condition needs its separate fixed error {check}")
    if "MirroringRole]=2" in runtime or "mirroring_role]=2" in runtime:
        errors.append("runtime fixture may not synthesize a positive mirrored role")
    if runtime.count("EXCEPT") < 7:
        errors.append("runtime fixture lacks sufficient native, JSON, and TABLE value comparisons")
    return errors

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repository-root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    root = args.repository_root.resolve()
    paths = {
        "procedure": PROCEDURE, "runtime": RUNTIME,
        "candidate_helper": CANDIDATE_HELPER,
        "result_tables_helper": RESULT_TABLES_HELPER,
        "write_result_table_helper": WRITE_RESULT_TABLE_HELPER,
        "console_result_helper": CONSOLE_RESULT_HELPER,
        "objects": "Metadata/Inventory/Objects.csv",
        "parameters": "Metadata/Inventory/Parameters.csv",
        "resultsets": "Metadata/Inventory/ResultSets.csv",
        "sources": "Metadata/Inventory/SystemSources.csv",
        "maturity": "Metadata/Inventory/Module_Maturity.csv",
        "coverage": "Metadata/Quality/Diagnostic_Coverage_Landscape.csv",
        "procedure_guide": "Documentation/Analysis_Guides/Procedures/USP_DatabaseMirroringInventory.md",
        "guide_index": "Documentation/Analysis_Guides/Procedures/README.md",
        "call_catalog": "Documentation/Reference/Call_Catalog.md",
        "release_gate": "Code/Tests/Run_Release_Gate.sql",
        "installer": "Code/Install/Install_All.sql",
        "generated": "Code/Install/generated/Deploy_All.generated.sql",
        "ops_install": "TestLab/Adapters/OPS-005/sql/install.sql",
        "ops_update": "TestLab/Adapters/OPS-005/sql/update.sql",
        "docs_review": "Metadata/Quality/Analysis_Documentation_Review.csv",
        "dossier": "AI_Metadata/Internal_Documentation/Architecture/Database_Mirroring_Inventory_Dossier.md",
    }
    try:
        text = {
            name: (root / rel).read_text(encoding="utf-8-sig")
            for name, rel in paths.items()
            if name != "generated" or (root / rel).is_file()
        }
        text.setdefault("generated", "")
    except OSError as error:
        print("ERROR: " + str(error), file=sys.stderr)
        return 2
    errors = validate_contract(**text)
    if args.self_test and not errors:
        gap_column_ids = (1, 3)
        dense_ordinals = tuple(range(1, len(gap_column_ids) + 1))
        if gap_column_ids == dense_ordinals or dense_ordinals != (1, 2):
            errors.append("synthetic column_id gap fixture must distinguish source IDs from the dense ABI ordinal")
        clean_checkout = dict(text)
        clean_checkout["generated"] = ""
        if validate_contract(**clean_checkout):
            errors.append("clean tracked checkout without the ignored generated installer must remain valid")
        selector_clause = """       OR
       (
           @DatabaseNamePattern IS NOT NULL
           AND NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NOT NULL
       )
"""
        late_selector_guard = """        IF @DatabaseNamePattern IS NOT NULL
           AND NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NOT NULL
        BEGIN
            SELECT @StatusCodeOut='INVALID_PARAMETER',@IsPartialOut=1,@ErrorNumberOut=51011;
            RETURN 51011;
        END;
"""
        late_selector_mutation = text["procedure"].replace(selector_clause, "", 1).replace(
            "        SET @Started=SYSUTCDATETIME();", late_selector_guard + "        SET @Started=SYSUTCDATETIME();", 1
        )
        mutations = (
            ("NOLOCK", "procedure", text["procedure"].replace("[master].[sys].[database_mirroring] AS [m] WITH (NOLOCK)", "[master].[sys].[database_mirroring] AS [m]", 1), "native source"),
            ("ABI", "procedure", text["procedure"].replace("[ConfiguredRedoQueueLimitMb] int NULL", "[ConfiguredRedoQueueLimitMb] bigint NULL", 1), "business ABI"),
            ("ABI_RAW_COLUMN_ID", "runtime", text["runtime"].replace("ROW_NUMBER() OVER(ORDER BY [c].[column_id]) AS [Ordinal]", "[c].[column_id] AS [Ordinal]", 1), "dense one-based ordinals"),
            ("ABI_ONE_WAY", "runtime", text["runtime"].replace("        OR EXISTS\n        (\n            SELECT [Ordinal]", "        OR FALSE\n        (\n            SELECT [Ordinal]", 1), "compare actual and expected metadata in both directions"),
            ("ABI_MISSING_FACET", "runtime", text["runtime"].replace("[c].[is_computed] AS [IsComputed]", "CAST(0 AS bit) AS [IsComputed]", 1), "compare every column facet in both directions"),
            ("ABI_CASE_INSENSITIVE_NAME", "runtime", text["runtime"].replace("[c].[name] COLLATE SQL_Latin1_General_CP1_CS_AS AS [ColumnName]", "[c].[name] AS [ColumnName]", 1), "compare every column facet in both directions"),
            ("JSON_NULL_EXPECTATION", "runtime", text["runtime"].replace("N'MirroringRole',1", "N'MirroringRole',0", 1), "all twelve JSON keys exactly once and all ten nullable values null"),
            ("JSON_KEY_SUBSTITUTION", "runtime", text["runtime"].replace("N'RedoQueueLimitType',1", "N'UnknownRedoQueueField',1", 1), "all twelve JSON keys exactly once and all ten nullable values null"),
            ("JSON_KEY_UNIQUENESS", "runtime", text["runtime"].replace("GROUP BY [FieldName] HAVING COUNT(*)<>1", "GROUP BY [FieldName] HAVING COUNT(*)<>2", 1), "all twelve JSON keys exactly once and all ten nullable values null"),
            ("JSON_EXTRA_KEY_DIRECTION", "runtime", text["runtime"].replace("EXCEPT SELECT [FieldName] FROM @ExpectedJsonFields", "EXCEPT SELECT [FieldName] FROM @ActualJsonFields", 1), "all twelve JSON keys exactly once and all ten nullable values null"),
            ("SELECTOR_GUARD_REMOVED", "procedure", text["procedure"].replace("AND NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NOT NULL", "AND NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NULL", 1), "nonblank exact-name plus pattern conflict must return INVALID_PARAMETER"),
            ("SELECTOR_BLANK_NORMALIZATION", "procedure", text["procedure"].replace("NULLIF(LTRIM(RTRIM(COALESCE(@DatabaseNames,N''))),N'') IS NOT NULL", "COALESCE(@DatabaseNames,N'') IS NOT NULL", 1), "blank exact names normalize to no selector"),
            ("SELECTOR_GUARD_TOO_LATE", "procedure", late_selector_mutation, "before source/temp work"),
            ("PARAM_SIGNATURE", "procedure", text["procedure"].replace("@MaxZeilen int = 1000", "@MaxZeilen int = 500", 1), "public parameter names"),
            ("HELP_PARAMETER", "procedure", text["procedure"].replace("@ErrorMessageOut nvarchar(2048)=NULL OUTPUT", "RemovedHelpParam", 1), "help parameter default or OUTPUT mode"),
            ("HELP_DEFAULT", "procedure", text["procedure"].replace("@MaxZeilen int=1000", "@MaxZeilen int=500", 1), "help parameter default or OUTPUT mode"),
            ("HELP_OPTION", "procedure", text["procedure"].replace("regexi:", "regexx:", 1), "help omits required option"),
            ("HELP_SELECTOR", "procedure", text["procedure"].replace("exakt und Pattern schließen einander aus", "Filter sind verfügbar", 1), "mutually exclusive exact-name and pattern rule"),
            ("HELP_EXAMPLE", "procedure", text["procedure"].replace("@DatabaseNames=N''[ExampleDatabase]'', @JsonErzeugen=1, @Json=@Json OUTPUT;", "@DatabaseNames=N''[ExampleDatabase]'', @JsonErzeugen=1, @Json=@Json;", 1), "help JSON example"),
            ("SHARED_SELECTOR", "candidate_helper", text["candidate_helper"].replace("@EffectiveDatabaseNames IS NOT NULL AND @DatabaseNamePattern IS NOT NULL", "@EffectiveDatabaseNames IS NOT NULL AND 1=0", 1), "shared candidate helper"),
            ("LIMIT", "runtime", text["runtime"].replace("@SourceRows<2", "@SourceRows<1", 1), "limit cases"),
            ("NATIVE_VERSION_SCOPE", "runtime", text["runtime"].replace("NOT IN (15,16,17)", "<>17", 1), "existing SQL Server 2019/2022/2025 release-gate targets"),
            ("SP_EXECUTESQL_EXPRESSION", "runtime", text["runtime"].replace("SET @Sql=N'DROP USER '+QUOTENAME(@Login)+N';';\n    EXEC [sys].[sp_executesql] @Sql;", "EXEC [sys].[sp_executesql] N'DROP USER '+QUOTENAME(@Login)+N';';", 1), "concatenated expressions directly to sp_executesql"),
            ("ISOLATION_ORDINAL", "runtime", text["runtime"].replace("transaction_isolation_level] FROM sys.dm_exec_sessions WHERE [session_id]=@@SPID)<>3", "transaction_isolation_level] FROM sys.dm_exec_sessions WHERE [session_id]=@@SPID)<>4", 1), "REPEATABLE READ as sys.dm_exec_sessions isolation level 3"),
            ("CALLER_AGGREGATE", "runtime", text["runtime"].replace("IF @Return<>0\n        THROW 57440,", "IF @Return<>0 OR @Status<>'AVAILABLE_LIMITED'\n        THROW 57440,", 1), "caller preservation condition must have its own fixed error"),
            ("CANDIDATE_REQUIRED_ARGUMENT", "procedure", text["procedure"].replace("@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,\n", "", 1), "shared helper call omits required parameter @CrossDatabaseRequested"),
            ("CANDIDATE_COMMENT_DECOY", "procedure", text["procedure"].replace("@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,\n", "", 1).replace("EXEC [monitor].[USP_PrepareDatabaseCandidates]", "/* nested /* EXEC [monitor].[USP_PrepareDatabaseCandidates] @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT; */ */\nEXEC [monitor].[USP_PrepareDatabaseCandidates]", 1), "shared helper call omits required parameter @CrossDatabaseRequested"),
            ("CANDIDATE_STRING_DECOY", "procedure", text["procedure"].replace("@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT,\n", "", 1).replace("EXEC [monitor].[USP_PrepareDatabaseCandidates]", "PRINT N'EXEC [monitor].[USP_PrepareDatabaseCandidates] @CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT;';\n            EXEC [monitor].[USP_PrepareDatabaseCandidates]", 1), "shared helper call omits required parameter @CrossDatabaseRequested"),
            ("CANDIDATE_DUPLICATE_CALL", "procedure", text["procedure"].replace("@WarningTable=N'#DatabaseMirroringInventory_SelectionWarnings';", "@WarningTable=N'#DatabaseMirroringInventory_SelectionWarnings';\n            EXEC [monitor].[USP_PrepareDatabaseCandidates] @DatabaseNames=@DatabaseNames;", 1), "duplicate required-helper calls are not permitted"),
            ("CANDIDATE_WRONG_HELPER", "procedure", text["procedure"].replace("EXEC [monitor].[USP_PrepareDatabaseCandidates]", "EXEC [monitor].[USP_PrepareDatabaseCandidate]", 1), "required-helper call is missing: USP_PrepareDatabaseCandidates"),
            ("CANDIDATE_WRONG_CASE_HELPER", "procedure", text["procedure"].replace("EXEC [monitor].[USP_PrepareDatabaseCandidates]", "EXEC [monitor].[usp_PrepareDatabaseCandidates]", 1), "required-helper call is missing: USP_PrepareDatabaseCandidates"),
            ("CANDIDATE_WRONG_CASE_ARGUMENT", "procedure", text["procedure"].replace("@CrossDatabaseRequested=@CrossDatabaseRequested OUTPUT", "@crossdatabaserequested=@CrossDatabaseRequested OUTPUT", 1), "shared helper call omits required parameter @CrossDatabaseRequested"),
            ("CANDIDATE_OUTPUT_DEFAULT", "candidate_helper", text["candidate_helper"].replace("@CrossDatabaseRequested           bit            OUTPUT", "@CrossDatabaseRequested           bit            = 0 OUTPUT", 1), "CrossDatabaseRequested output must remain required without a default"),
            ("CANONICAL_INSTALLER_INCLUDE", "installer", text["installer"].replace("310_USP_DatabaseMirroringInventory.sql", "missing_procedure.sql", 1), "canonical deployment installer must include the procedure"),
        )
        for name, key, changed, expected in mutations:
            candidate = dict(text)
            candidate[key] = changed
            if not any(expected in error for error in validate_contract(**candidate)):
                errors.append("validator self-test did not reject meaningful " + name + " mutation")
        generated_marker = "-- BEGIN SOURCE: Code/08_ServerHealth/310_USP_DatabaseMirroringInventory.sql"
        generated_probe = dict(text)
        generated_probe["generated"] = generated_marker
        if validate_contract(**generated_probe):
            errors.append("generated-installer positive binding probe was unexpectedly rejected")
        generated_mutation = dict(generated_probe)
        generated_mutation["generated"] = generated_marker.replace("310_USP_DatabaseMirroringInventory.sql", "missing_procedure.sql")
        if not any("available generated deployment artifact" in error for error in validate_contract(**generated_mutation)):
            errors.append("validator self-test did not reject a missing source in a generated installer")
    if errors:
        for error in errors:
            print("ERROR: " + error)
        return 1
    print("PASS: Database Mirroring V1 source, metadata, runtime, documentation, and deployment bindings are consistent.")
    if args.self_test:
        print("PASS: source, ABI, help, runtime, clean-checkout deployment, generated-artifact, and mutation contracts are verified.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
