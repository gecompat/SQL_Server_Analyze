#!/usr/bin/env python3
"""Validate CurrentOverview literal ABI, all local shapes and output orchestration."""
from pathlib import Path
import argparse,re
SOURCE=Path('Code/02_CurrentState/100_USP_CurrentOverview.sql')
def norm(text): return re.sub(r'\s+',' ',text).strip()
TABLES={'#CurrentOverview_ResultTableMap': '[ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL '
                                    'PRIMARY KEY , [TargetTable] sysname COLLATE '
                                    'SQL_Latin1_General_CP1_CS_AS NOT NULL UNIQUE',
 '#CurrentOverview_ModulePayload': '[ModuleOrdinal] int NOT NULL PRIMARY KEY , [ResultName] sysname COLLATE '
                                   'SQL_Latin1_General_CP1_CS_AS NOT NULL , [ModuleName] sysname COLLATE '
                                   'SQL_Latin1_General_CP1_CS_AS NOT NULL , [SourceTable] sysname COLLATE '
                                   'SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsEnabled] bit NOT NULL , '
                                   '[IsRelevant] bit NOT NULL , [IsMaterialized] bit NOT NULL , [DurationMs] '
                                   'bigint NOT NULL , [JsonValue] nvarchar(max) COLLATE '
                                   'SQL_Latin1_General_CP1_CS_AS NULL , [ExecutionError] nvarchar(2048) '
                                   'COLLATE SQL_Latin1_General_CP1_CS_AS NULL',
 '#CurrentOverview_ModuleStatus': '[ModuleOrdinal] int NOT NULL , [ResultName] sysname COLLATE '
                                  'SQL_Latin1_General_CP1_CS_AS NOT NULL , [ModuleName] sysname COLLATE '
                                  'SQL_Latin1_General_CP1_CS_AS NOT NULL , [StatusCode] varchar(40) COLLATE '
                                  'SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , '
                                  '[ReturnedRowCount] bigint NOT NULL , [DurationMs] bigint NOT NULL , '
                                  '[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , '
                                  'PRIMARY KEY ([ModuleOrdinal])',
 '#CurrentOverview_Warnings': '[ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                              '[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                              '[Message] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL',
 '#CurrentOverview_Sessions': '[Seed] bit NULL',
 '#CurrentOverview_Requests': '[Seed] bit NULL',
 '#CurrentOverview_RequestContext': '[Seed] bit NULL',
 '#CurrentOverview_Statements': '[Seed] bit NULL',
 '#CurrentOverview_Batches': '[Seed] bit NULL',
 '#CurrentOverview_InputBuffers': '[Seed] bit NULL',
 '#CurrentOverview_RequestSnapshotStatus': '[Seed] bit NULL',
 '#CurrentOverview_Blocking': '[Seed] bit NULL',
 '#CurrentOverview_Waits': '[Seed] bit NULL',
 '#CurrentOverview_Transactions': '[Seed] bit NULL',
 '#CurrentOverview_MemoryGrants': '[Seed] bit NULL',
 '#CurrentOverview_TempDBSessions': '[Seed] bit NULL',
 '#CurrentOverview_TempDBGovernance': '[Seed] bit NULL',
 '#CurrentOverview_VersionStore': '[Seed] bit NULL',
 '#CurrentOverview_IO': '[Seed] bit NULL',
 '#CurrentOverview_Logs': '[Seed] bit NULL',
 '#CurrentOverview_SnapshotStatus': '[SourceOrdinal] int NOT NULL , [SnapshotId] uniqueidentifier NOT NULL , '
                                    '[SourceCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL '
                                    ', [SourceObject] nvarchar(256) COLLATE SQL_Latin1_General_CP1_CS_AS NOT '
                                    'NULL , [CapturedAtUtc] datetime2(3) NOT NULL , [CompletedAtUtc] '
                                    'datetime2(3) NOT NULL , [StatusCode] varchar(40) COLLATE '
                                    'SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] bit NOT NULL , '
                                    '[CapturedRowCount] bigint NOT NULL , [ErrorNumber] int NULL , '
                                    '[ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL '
                                    ', PRIMARY KEY ([SourceOrdinal])',
 '#CurrentOverview_CurrentStateSnapshot_Context': '[SnapshotId] uniqueidentifier NOT NULL PRIMARY KEY , '
                                                  '[OwnerSessionId] smallint NOT NULL , [CreatedAtUtc] '
                                                  'datetime2(3) NOT NULL , [ContractVersion] smallint NOT '
                                                  'NULL',
 '#CurrentOverview_CurrentStateSnapshot_SourceStatus': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                       '[SourceOrdinal] int NOT NULL , [SourceCode] '
                                                       'varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT '
                                                       'NULL , [SourceObject] nvarchar(256) COLLATE '
                                                       'SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                       '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                       '[CompletedAtUtc] datetime2(3) NOT NULL , '
                                                       '[StatusCode] varchar(40) COLLATE '
                                                       'SQL_Latin1_General_CP1_CS_AS NOT NULL , [IsPartial] '
                                                       'bit NOT NULL , [CapturedRowCount] bigint NOT NULL , '
                                                       '[ErrorNumber] int NULL , [ErrorMessage] '
                                                       'nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS '
                                                       'NULL , PRIMARY KEY ([SnapshotId],[SourceCode])',
 '#CurrentOverview_CurrentStateSnapshot_Sessions': '[SnapshotId] uniqueidentifier NOT NULL , [CapturedAtUtc] '
                                                   'datetime2(3) NOT NULL , [session_id] smallint NOT NULL , '
                                                   '[is_user_process] bit NOT NULL , [status] nvarchar(30) '
                                                   'COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                   '[login_name] nvarchar(128) COLLATE '
                                                   'SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                   '[original_login_name] nvarchar(128) COLLATE '
                                                   'SQL_Latin1_General_CP1_CS_AS NOT NULL , [host_name] '
                                                   'nvarchar(128) COLLATE SQL_Latin1_General_CP1_CS_AS NULL '
                                                   ', [program_name] nvarchar(128) COLLATE '
                                                   'SQL_Latin1_General_CP1_CS_AS NULL , '
                                                   '[client_interface_name] nvarchar(32) COLLATE '
                                                   'SQL_Latin1_General_CP1_CS_AS NULL , [login_time] '
                                                   'datetime NOT NULL , [last_request_start_time] datetime '
                                                   'NOT NULL , [last_request_end_time] datetime NULL , '
                                                   '[open_transaction_count] int NOT NULL , '
                                                   '[transaction_isolation_level] smallint NOT NULL , '
                                                   '[cpu_time] int NOT NULL , [reads] bigint NOT NULL , '
                                                   '[writes] bigint NOT NULL , [logical_reads] bigint NOT '
                                                   'NULL , [memory_usage] int NOT NULL , [row_count] bigint '
                                                   'NOT NULL , PRIMARY KEY ([SnapshotId],[session_id])',
 '#CurrentOverview_CurrentStateSnapshot_Requests': '[SnapshotId] uniqueidentifier NOT NULL , [CapturedAtUtc] '
                                                   'datetime2(3) NOT NULL , [session_id] smallint NOT NULL , '
                                                   '[request_id] int NOT NULL , [status] nvarchar(30) '
                                                   'COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                   '[command] nvarchar(32) COLLATE '
                                                   'SQL_Latin1_General_CP1_CS_AS NOT NULL , [start_time] '
                                                   'datetime NOT NULL , [sql_handle] varbinary(64) NULL , '
                                                   '[statement_start_offset] int NULL , '
                                                   '[statement_end_offset] int NULL , [plan_handle] '
                                                   'varbinary(64) NULL , [database_id] smallint NOT NULL , '
                                                   '[connection_id] uniqueidentifier NULL , '
                                                   '[blocking_session_id] smallint NULL , [wait_type] '
                                                   'nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL , '
                                                   '[wait_time] int NOT NULL , [last_wait_type] nvarchar(60) '
                                                   'COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                   '[wait_resource] nvarchar(256) COLLATE '
                                                   'SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                   '[open_transaction_count] int NOT NULL , '
                                                   '[open_resultset_count] int NOT NULL , [transaction_id] '
                                                   'bigint NOT NULL , [context_info] varbinary(128) NULL , '
                                                   '[percent_complete] real NOT NULL , '
                                                   '[estimated_completion_time] bigint NOT NULL , [cpu_time] '
                                                   'int NOT NULL , [total_elapsed_time] int NOT NULL , '
                                                   '[scheduler_id] int NULL , [task_address] varbinary(8) '
                                                   'NULL , [reads] bigint NOT NULL , [writes] bigint NOT '
                                                   'NULL , [logical_reads] bigint NOT NULL , '
                                                   '[transaction_isolation_level] smallint NOT NULL , '
                                                   '[row_count] bigint NOT NULL , [nest_level] int NOT NULL '
                                                   ', [executing_managed_code] bit NOT NULL , [group_id] int '
                                                   'NOT NULL , [query_hash] binary(8) NULL , '
                                                   '[query_plan_hash] binary(8) NULL , '
                                                   '[statement_sql_handle] varbinary(64) NULL , '
                                                   '[statement_context_id] bigint NULL , [dop] int NOT NULL '
                                                   ', [parallel_worker_count] int NULL , [is_resumable] bit '
                                                   'NOT NULL , PRIMARY KEY '
                                                   '([SnapshotId],[session_id],[request_id])',
 '#CurrentOverview_CurrentStateSnapshot_Connections': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                      '[CapturedAtUtc] datetime2(3) NOT NULL , [session_id] '
                                                      'int NULL , [connection_id] uniqueidentifier NOT NULL '
                                                      ', [most_recent_sql_handle] varbinary(64) NULL , '
                                                      '[client_net_address] varchar(48) COLLATE '
                                                      'SQL_Latin1_General_CP1_CS_AS NULL , [net_transport] '
                                                      'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT '
                                                      'NULL , [protocol_type] nvarchar(40) COLLATE '
                                                      'SQL_Latin1_General_CP1_CS_AS NULL , [encrypt_option] '
                                                      'nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT '
                                                      'NULL , [auth_scheme] nvarchar(40) COLLATE '
                                                      'SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                      '[connect_time] datetime NOT NULL , PRIMARY KEY '
                                                      '([SnapshotId],[connection_id])',
 '#CurrentOverview_CurrentStateSnapshot_WaitingTasks': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                       '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                       '[waiting_task_address] varbinary(8) NOT NULL , '
                                                       '[session_id] smallint NULL , [exec_context_id] int '
                                                       'NULL , [wait_duration_ms] bigint NOT NULL , '
                                                       '[wait_type] nvarchar(60) COLLATE '
                                                       'SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                       '[resource_address] varbinary(8) NULL , '
                                                       '[blocking_task_address] varbinary(8) NULL , '
                                                       '[blocking_session_id] smallint NULL , '
                                                       '[blocking_exec_context_id] int NULL , '
                                                       '[resource_description] nvarchar(3072) COLLATE '
                                                       'SQL_Latin1_General_CP1_CS_AS NULL',
 '#CurrentOverview_CurrentStateSnapshot_MemoryGrants': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                       '[CapturedAtUtc] datetime2(3) NOT NULL , [session_id] '
                                                       'smallint NOT NULL , [request_id] int NOT NULL , '
                                                       '[scheduler_id] int NULL , [dop] smallint NULL , '
                                                       '[request_time] datetime NULL , [grant_time] datetime '
                                                       'NULL , [wait_time_ms] bigint NULL , '
                                                       '[requested_memory_kb] bigint NOT NULL , '
                                                       '[required_memory_kb] bigint NULL , '
                                                       '[granted_memory_kb] bigint NULL , [used_memory_kb] '
                                                       'bigint NULL , [max_used_memory_kb] bigint NULL , '
                                                       '[ideal_memory_kb] bigint NULL , '
                                                       '[resource_semaphore_id] smallint NULL , [queue_id] '
                                                       'smallint NULL , [wait_order] int NULL , '
                                                       '[is_next_candidate] bit NULL , [is_small] bit NULL , '
                                                       '[plan_handle] varbinary(64) NULL , [sql_handle] '
                                                       'varbinary(64) NULL , [group_id] int NULL , [pool_id] '
                                                       'int NULL , [reserved_worker_count] bigint NULL , '
                                                       '[used_worker_count] bigint NULL , '
                                                       '[max_used_worker_count] bigint NULL',
 '#CurrentOverview_CurrentStateSnapshot_ResourceSemaphores': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                             '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                             '[pool_id] int NOT NULL , '
                                                             '[resource_semaphore_id] smallint NOT NULL , '
                                                             '[target_memory_kb] bigint NOT NULL , '
                                                             '[max_target_memory_kb] bigint NULL , '
                                                             '[total_memory_kb] bigint NOT NULL , '
                                                             '[available_memory_kb] bigint NOT NULL , '
                                                             '[granted_memory_kb] bigint NOT NULL , '
                                                             '[used_memory_kb] bigint NOT NULL , '
                                                             '[grantee_count] int NOT NULL , [waiter_count] '
                                                             'int NOT NULL , PRIMARY KEY '
                                                             '([SnapshotId],[pool_id],[resource_semaphore_id])',
 '#CurrentOverview_CurrentStateSnapshot_WorkloadGroups': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                         '[CapturedAtUtc] datetime2(3) NOT NULL , [group_id] '
                                                         'int NOT NULL , [name] sysname COLLATE '
                                                         'SQL_Latin1_General_CP1_CS_AS NOT NULL , [pool_id] '
                                                         'int NOT NULL , '
                                                         '[request_max_memory_grant_percent_numeric] '
                                                         'decimal(9,4) NULL , [max_request_grant_memory_kb] '
                                                         'bigint NULL , '
                                                         '[configured_group_max_tempdb_data_mb] '
                                                         'decimal(19,2) NULL , '
                                                         '[configured_group_max_tempdb_data_percent] '
                                                         'decimal(9,4) NULL , [tempdb_maximum_size_mb] '
                                                         'decimal(19,2) NULL , '
                                                         '[effective_group_max_tempdb_data_mb] decimal(19,2) '
                                                         'NULL , [effective_limit_source] varchar(40) '
                                                         'COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                         '[is_percent_limit_effective] bit NULL , '
                                                         '[tempdb_data_space_mb] decimal(19,2) NULL , '
                                                         '[peak_tempdb_data_space_mb] decimal(19,2) NULL , '
                                                         '[effective_limit_utilization_percent] decimal(9,2) '
                                                         'NULL , [total_tempdb_data_limit_violation_count] '
                                                         'bigint NULL , [has_recorded_limit_violation] bit '
                                                         'NULL , [statistics_start_time] datetime NULL , '
                                                         '[is_resource_governor_enabled] bit NULL , '
                                                         '[reconfiguration_pending] bit NULL , '
                                                         '[tempdb_governance_status_code] varchar(40) '
                                                         'COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                         '[tempdb_governance_is_partial] bit NOT NULL , '
                                                         '[tempdb_governance_evidence_limit] nvarchar(1000) '
                                                         'COLLATE SQL_Latin1_General_CP1_CS_AS NULL , '
                                                         'PRIMARY KEY ([SnapshotId],[group_id])',
 '#CurrentOverview_CurrentStateSnapshot_ResourcePools': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                        '[CapturedAtUtc] datetime2(3) NOT NULL , [pool_id] '
                                                        'int NOT NULL , [name] sysname COLLATE '
                                                        'SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                        '[max_memory_kb] bigint NULL , [target_memory_kb] '
                                                        'bigint NULL , [used_memory_kb] bigint NULL , '
                                                        'PRIMARY KEY ([SnapshotId],[pool_id])',
 '#CurrentOverview_CurrentStateSnapshot_Tasks': '[SnapshotId] uniqueidentifier NOT NULL , [CapturedAtUtc] '
                                                'datetime2(3) NOT NULL , [task_address] varbinary(8) NOT '
                                                'NULL , [task_state] nvarchar(60) COLLATE '
                                                'SQL_Latin1_General_CP1_CS_AS NOT NULL , [session_id] '
                                                'smallint NULL , [request_id] int NULL , [exec_context_id] '
                                                'int NULL , [scheduler_id] int NULL , [worker_address] '
                                                'varbinary(8) NULL , [parent_task_address] varbinary(8) NULL '
                                                ', PRIMARY KEY ([SnapshotId],[task_address])',
 '#CurrentOverview_CurrentStateSnapshot_Schedulers': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                     '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                     '[scheduler_address] varbinary(8) NOT NULL , '
                                                     '[scheduler_id] int NOT NULL , [parent_node_id] int NOT '
                                                     'NULL , [status] nvarchar(60) COLLATE '
                                                     'SQL_Latin1_General_CP1_CS_AS NOT NULL , [is_online] '
                                                     'bit NOT NULL , [is_idle] bit NOT NULL , '
                                                     '[current_tasks_count] int NOT NULL , '
                                                     '[runnable_tasks_count] int NOT NULL , '
                                                     '[current_workers_count] int NOT NULL , '
                                                     '[active_workers_count] int NOT NULL , '
                                                     '[work_queue_count] bigint NOT NULL , '
                                                     '[pending_disk_io_count] int NOT NULL , [load_factor] '
                                                     'int NOT NULL , PRIMARY KEY '
                                                     '([SnapshotId],[scheduler_id])',
 '#CurrentOverview_CurrentStateSnapshot_SessionTransactions': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                              '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                              '[session_id] int NOT NULL , [transaction_id] '
                                                              'bigint NOT NULL , [transaction_descriptor] '
                                                              'binary(8) NOT NULL , [enlist_count] int NOT '
                                                              'NULL , [is_user_transaction] bit NOT NULL , '
                                                              '[is_local] bit NOT NULL , [is_enlisted] bit '
                                                              'NOT NULL , [is_bound] bit NOT NULL , '
                                                              '[open_transaction_count] int NOT NULL , '
                                                              'PRIMARY KEY '
                                                              '([SnapshotId],[session_id],[transaction_id])',
 '#CurrentOverview_CurrentStateSnapshot_ActiveTransactions': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                             '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                             '[transaction_id] bigint NOT NULL , [name] '
                                                             'nvarchar(32) COLLATE '
                                                             'SQL_Latin1_General_CP1_CS_AS NOT NULL , '
                                                             '[transaction_begin_time] datetime NOT NULL , '
                                                             '[transaction_type] int NOT NULL , '
                                                             '[transaction_uow] uniqueidentifier NULL , '
                                                             '[transaction_state] int NOT NULL , '
                                                             '[transaction_status] int NOT NULL , PRIMARY '
                                                             'KEY ([SnapshotId],[transaction_id])',
 '#CurrentOverview_CurrentStateSnapshot_DatabaseTransactions': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                               '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                               '[transaction_id] bigint NOT NULL , '
                                                               '[database_id] int NOT NULL , '
                                                               '[database_transaction_begin_time] datetime '
                                                               'NULL , [database_transaction_type] int NOT '
                                                               'NULL , [database_transaction_state] int NOT '
                                                               'NULL , '
                                                               '[database_transaction_log_record_count] '
                                                               'bigint NOT NULL , '
                                                               '[database_transaction_log_bytes_used] bigint '
                                                               'NOT NULL , '
                                                               '[database_transaction_log_bytes_reserved] '
                                                               'bigint NOT NULL , '
                                                               '[database_transaction_log_bytes_used_system] '
                                                               'bigint NOT NULL , '
                                                               '[database_transaction_log_bytes_reserved_system] '
                                                               'bigint NOT NULL',
 '#CurrentOverview_CurrentStateSnapshot_TempDbSessionUsage': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                             '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                             '[session_id] smallint NOT NULL , '
                                                             '[user_objects_alloc_page_count] bigint NOT '
                                                             'NULL , [user_objects_dealloc_page_count] '
                                                             'bigint NOT NULL , '
                                                             '[internal_objects_alloc_page_count] bigint NOT '
                                                             'NULL , [internal_objects_dealloc_page_count] '
                                                             'bigint NOT NULL , PRIMARY KEY '
                                                             '([SnapshotId],[session_id])',
 '#CurrentOverview_CurrentStateSnapshot_TempDbTaskUsage': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                          '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                          '[session_id] smallint NOT NULL , [request_id] int '
                                                          'NOT NULL , [exec_context_id] int NOT NULL , '
                                                          '[user_objects_alloc_page_count] bigint NOT NULL , '
                                                          '[user_objects_dealloc_page_count] bigint NOT NULL '
                                                          ', [internal_objects_alloc_page_count] bigint NOT '
                                                          'NULL , [internal_objects_dealloc_page_count] '
                                                          'bigint NOT NULL',
 '#CurrentOverview_CurrentStateSnapshot_VersionStoreSpaceUsage': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                                  '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                                  '[database_id] int NOT NULL , '
                                                                  '[reserved_page_count] bigint NOT NULL , '
                                                                  'PRIMARY KEY ([SnapshotId],[database_id])',
 '#CurrentOverview_CurrentStateSnapshot_PersistentVersionStore': '[SnapshotId] uniqueidentifier NOT NULL , '
                                                                 '[CapturedAtUtc] datetime2(3) NOT NULL , '
                                                                 '[database_id] int NOT NULL , '
                                                                 '[pvs_filegroup_id] smallint NULL , '
                                                                 '[persistent_version_store_size_kb] bigint NULL , '
                                                                 '[online_index_version_store_size_kb] bigint NULL , '
                                                                 'PRIMARY KEY ([SnapshotId],[database_id])',
 '#CurrentOverview_CurrentStateSnapshot_SqlText': '[SnapshotId] uniqueidentifier NOT NULL , [CapturedAtUtc] '
                                                  'datetime2(3) NOT NULL , [SqlHandle] varbinary(64) NOT '
                                                  'NULL , [Text] nvarchar(max) COLLATE '
                                                  'SQL_Latin1_General_CP1_CS_AS NULL , [DatabaseId] int NULL '
                                                  ', [ObjectId] int NULL , [ObjectNumber] smallint NULL , '
                                                  '[IsEncrypted] bit NULL , [EvidenceStatus] varchar(40) '
                                                  'COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL , PRIMARY '
                                                  'KEY ([SnapshotId],[SqlHandle])'}
ABI=[('@SessionIds', 'nvarchar(max)', 'NULL'), ('@DatabaseNames', 'nvarchar(max)', 'NULL'), ('@SystemdatenbankenEinbeziehen', 'bit', '0'), ('@DatabaseNamePattern', 'nvarchar(4000)', 'NULL'), ('@HighImpactConfirmed', 'bit', '0'), ('@ToolHintergrundabfragenEinbeziehen', 'bit', '0'), ('@Detailgrad', 'varchar(16)', "'SUMMARY'"), ('@MitSessions', 'bit', '1'), ('@MitRequests', 'bit', '1'), ('@MitBlocking', 'bit', '1'), ('@BlockingObjektTiefe', 'varchar(16)', "'STANDARD'"), ('@MaxObjektAufloesungen', 'int', '100'), ('@MitWaits', 'bit', '1'), ('@MitTransactions', 'bit', '1'), ('@MitMemoryGrants', 'bit', '1'), ('@MitTempDB', 'bit', '1'), ('@MitIO', 'bit', '1'), ('@MitLog', 'bit', '1'), ('@MitSqlText', 'bit', '1'), ('@GesamtenSqlTextEinbeziehen', 'bit', '0'), ('@InputBufferEinbeziehen', 'bit', '0'), ('@ModulInfoEinbeziehen', 'bit', '1'), ('@MaxSqlTextZeichen', 'int', '4000'), ('@SampleSeconds', 'tinyint', '0'), ('@MaxZeilen', 'int', '500'), ('@ResultSetArt', 'varchar(16)', "'CONSOLE'"), ('@ResultTablesJson', 'nvarchar(max)', 'NULL'), ('@JsonErzeugen', 'bit', '0'), ('@Json', 'nvarchar(max)', 'NULL OUTPUT'), ('@PrintMeldungen', 'bit', '1'), ('@Hilfe', 'bit', '0')]
CHILD_CALLS={'USP_CurrentSessions': '@SessionIds=@SessionIds , '
                        '@ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen , '
                        '@MitSqlText=@MitSqlText , @MaxSqlTextZeichen=@MaxSqlTextZeichen , '
                        "@MaxZeilen=@MaxZeilen , @ResultSetArt='TABLE' , "
                        '@ResultTablesJson=N\'{"sessions":"#CurrentOverview_Sessions"}\' , @JsonErzeugen=1 , '
                        '@Json=@ChildJson OUTPUT , @PrintMeldungen=@PrintMeldungen , '
                        '@ParentCurrentStateSnapshotId=@SnapshotConsumerId',
 'USP_CurrentRequests': '@SessionIds=@SessionIds , '
                        '@ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen , '
                        '@MitSqlText=@MitSqlText , @GesamtenSqlTextEinbeziehen=@GesamtenSqlTextEinbeziehen , '
                        '@InputBufferEinbeziehen=@InputBufferEinbeziehen , '
                        '@ModulInfoEinbeziehen=@ModulInfoEinbeziehen , @MaxSqlTextZeichen=@MaxSqlTextZeichen '
                        ", @MaxZeilen=@MaxZeilen , @ResultSetArt='TABLE' , @ResultTablesJson=N'{ "
                        '"requests":"#CurrentOverview_Requests", '
                        '"requestContext":"#CurrentOverview_RequestContext", '
                        '"snapshotStatus":"#CurrentOverview_RequestSnapshotStatus", '
                        '"statements":"#CurrentOverview_Statements", "batches":"#CurrentOverview_Batches", '
                        '"inputBuffers":"#CurrentOverview_InputBuffers" }\' , @JsonErzeugen=1 , '
                        '@Json=@ChildJson OUTPUT , @PrintMeldungen=@PrintMeldungen , '
                        '@ParentCurrentStateSnapshotId=@SnapshotConsumerId',
 'USP_CurrentBlocking': '@SessionIds=@SessionIds , '
                        '@ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen , '
                        '@MitSqlText=@MitSqlText , @MaxSqlTextZeichen=@MaxSqlTextZeichen , '
                        '@BlockingObjektTiefe=@BlockingObjectDepth , '
                        '@MaxObjektAufloesungen=@MaxObjektAufloesungen , '
                        '@HighImpactConfirmed=@HighImpactConfirmed , @MaxZeilen=@MaxZeilen , '
                        "@ResultSetArt='TABLE' , "
                        '@ResultTablesJson=N\'{"blockingChains":"#CurrentOverview_Blocking"}\' , '
                        '@JsonErzeugen=1 , @Json=@ChildJson OUTPUT , @PrintMeldungen=@PrintMeldungen , '
                        '@ParentCurrentStateSnapshotId=@SnapshotConsumerId',
 'USP_CurrentWaits': '@SessionIds=@SessionIds , '
                     '@ToolHintergrundabfragenEinbeziehen=@ToolHintergrundabfragenEinbeziehen , '
                     '@MitSqlText=@MitSqlText , @MaxSqlTextZeichen=@MaxSqlTextZeichen , '
                     "@SampleSeconds=@SampleSeconds , @MaxZeilen=@MaxZeilen , @ResultSetArt='TABLE' , "
                     '@ResultTablesJson=N\'{"currentTasks":"#CurrentOverview_Waits"}\' , @JsonErzeugen=1 , '
                     '@Json=@ChildJson OUTPUT , @PrintMeldungen=@PrintMeldungen , '
                     '@ParentCurrentStateSnapshotId=@SnapshotConsumerId',
 'USP_CurrentTransactions': '@SessionIds=@SessionIds , @MitSqlText=@MitSqlText , '
                            '@MaxSqlTextZeichen=@MaxSqlTextZeichen , @MaxZeilen=@MaxZeilen , '
                            "@ResultSetArt='TABLE' , "
                            '@ResultTablesJson=N\'{"transactions":"#CurrentOverview_Transactions"}\' , '
                            '@JsonErzeugen=1 , @Json=@ChildJson OUTPUT , @PrintMeldungen=@PrintMeldungen , '
                            '@ParentCurrentStateSnapshotId=@SnapshotConsumerId',
 'USP_CurrentMemoryGrants': '@SessionIds=@SessionIds , @MitSqlText=@MitSqlText , '
                            '@MaxSqlTextZeichen=@MaxSqlTextZeichen , @MaxZeilen=@MaxZeilen , '
                            "@ResultSetArt='TABLE' , "
                            '@ResultTablesJson=N\'{"memoryGrants":"#CurrentOverview_MemoryGrants"}\' , '
                            '@JsonErzeugen=1 , @Json=@ChildJson OUTPUT , @PrintMeldungen=@PrintMeldungen , '
                            '@ParentCurrentStateSnapshotId=@SnapshotConsumerId',
 'USP_CurrentTempDB': "@SessionIds=@SessionIds , @MaxZeilen=@MaxZeilen , @ResultSetArt='TABLE' , "
                      '@ResultTablesJson=N\'{"sessions":"#CurrentOverview_TempDBSessions","tempdbGovernance":"#CurrentOverview_TempDBGovernance","versionStore":"#CurrentOverview_VersionStore"}\' '
                      ', @JsonErzeugen=1 , @Json=@ChildJson OUTPUT , @PrintMeldungen=@PrintMeldungen , '
                      '@ParentCurrentStateSnapshotId=@SnapshotConsumerId',
 'USP_CurrentIO': '@DatabaseNames=@DatabaseNames , '
                  '@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen , '
                  '@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed , '
                  "@SampleSeconds=@SampleSeconds , @MaxZeilen=@MaxZeilen , @ResultSetArt='TABLE' , "
                  '@ResultTablesJson=N\'{"files":"#CurrentOverview_IO"}\' , @JsonErzeugen=1 , '
                  '@Json=@ChildJson OUTPUT , @PrintMeldungen=@PrintMeldungen , '
                  '@ParentCurrentStateSnapshotId=@SnapshotConsumerId',
 'USP_CurrentLog': '@DatabaseNames=@DatabaseNames , '
                   '@SystemdatenbankenEinbeziehen=@SystemdatenbankenEinbeziehen , '
                   '@DatabaseNamePattern=@DatabaseNamePattern,@HighImpactConfirmed=@HighImpactConfirmed , '
                   "@MaxZeilen=@MaxZeilen , @ResultSetArt='TABLE' , "
                   '@ResultTablesJson=N\'{"logs":"#CurrentOverview_Logs"}\' , @JsonErzeugen=1 , '
                   '@Json=@ChildJson OUTPUT , @PrintMeldungen=@PrintMeldungen'}
OUTPUTS='BuildOutputs: IF @PrintMeldungen=1 AND (@FailedModules>0 OR @PartialModules>0) BEGIN SET @Message=FORMATMESSAGE(N\'HINWEIS USP_CurrentOverview: %d Modul(e) fehlgeschlagen, %d Modul(e) partiell; %d aktiviert.\',@FailedModules,@PartialModules,@ExecutedModules); RAISERROR(N\'%s\',10,1,@Message) WITH NOWAIT; END; IF @OutputMode IN (\'CONSOLE\',\'RAW\') BEGIN SELECT [ModuleName] , [StatusCode] , [IsPartial] , [ReturnedRowCount] , [DurationMs] , [ErrorMessage] FROM [#CurrentOverview_ModuleStatus] ORDER BY [ModuleOrdinal]; END; IF @OutputMode=\'RAW\' BEGIN SELECT [SourceOrdinal],[SnapshotId],[SourceCode],[SourceObject],[CapturedAtUtc],[CompletedAtUtc] , [StatusCode],[IsPartial],[CapturedRowCount],[ErrorNumber],[ErrorMessage] FROM [#CurrentOverview_SnapshotStatus] ORDER BY [SourceOrdinal]; SELECT [ModuleName],[StatusCode],[Message] FROM [#CurrentOverview_Warnings] ORDER BY [ModuleName]; END; IF @OutputMode=\'CONSOLE\' AND @DetailMode IN (\'RELEVANT\',\'ALL\') BEGIN DECLARE @DetailSourceTable sysname; DECLARE @DetailSql nvarchar(max); DECLARE [DetailCursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [p].[SourceTable] FROM [#CurrentOverview_ModulePayload] AS [p] INNER JOIN [#CurrentOverview_ModuleStatus] AS [s] ON [s].[ModuleOrdinal]=[p].[ModuleOrdinal] WHERE [p].[IsEnabled]=1 AND [p].[IsMaterialized]=1 AND [s].[ReturnedRowCount]>0 AND [s].[StatusCode] IN (\'AVAILABLE\',\'AVAILABLE_LIMITED\') AND (@DetailMode=\'ALL\' OR [p].[IsRelevant]=1) ORDER BY [p].[ModuleOrdinal]; OPEN [DetailCursor]; FETCH NEXT FROM [DetailCursor] INTO @DetailSourceTable; WHILE @@FETCH_STATUS=0 BEGIN SET @DetailSql=N\'SELECT * FROM \'+QUOTENAME(@DetailSourceTable)+N\';\'; EXEC [sys].[sp_executesql] @DetailSql; FETCH NEXT FROM [DetailCursor] INTO @DetailSourceTable; END; CLOSE [DetailCursor]; DEALLOCATE [DetailCursor]; END; IF @JsonErzeugen=1 BEGIN DECLARE @MetaJson nvarchar(max)= ( SELECT N\'CurrentOverview\' AS [resultName] , 4 AS [schemaVersion] , @StartedAtUtc AS [generatedAtUtc] , @StatusCode AS [statusCode] , @CurrentStateSnapshotId AS [evidenceSnapshotId] , CONVERT(bit,CASE WHEN @StatusCode=\'INVALID_PARAMETER\' OR @PartialModules>0 OR @FailedModules>0 OR @SnapshotPartial=1 THEN 1 ELSE 0 END) AS [isPartial] , @ExecutedModules AS [executedModules] , @FailedModules AS [failedModules] , @PartialModules AS [partialModules] , @ToolHintergrundabfragenEinbeziehen AS [toolBackgroundQueriesIncluded] FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES ); DECLARE @ModuleStatusJson nvarchar(max)= ( SELECT [ResultName],[ModuleName],[StatusCode],[IsPartial],[ReturnedRowCount],[DurationMs],[ErrorMessage] FROM [#CurrentOverview_ModuleStatus] ORDER BY [ModuleOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES ); DECLARE @SnapshotStatusJson nvarchar(max)= ( SELECT [SourceOrdinal],[SnapshotId],[SourceCode],[SourceObject],[CapturedAtUtc],[CompletedAtUtc] , [StatusCode],[IsPartial],[CapturedRowCount],[ErrorNumber],[ErrorMessage] FROM [#CurrentOverview_SnapshotStatus] ORDER BY [SourceOrdinal] FOR JSON PATH,INCLUDE_NULL_VALUES ); DECLARE @WarningsJson nvarchar(max)= ( SELECT [ModuleName],[StatusCode],[Message] FROM [#CurrentOverview_Warnings] ORDER BY [ModuleName] FOR JSON PATH,INCLUDE_NULL_VALUES ); DECLARE @ChildProperties nvarchar(max)= ( SELECT STRING_AGG ( CONVERT(nvarchar(max),CONCAT ( N\'"\' , STRING_ESCAPE([ResultName] COLLATE SQL_Latin1_General_CP1_CS_AS,\'json\') , N\'":\' , CASE WHEN ISJSON([JsonValue])=1 THEN [JsonValue] COLLATE SQL_Latin1_General_CP1_CS_AS ELSE N\'null\' END )) COLLATE SQL_Latin1_General_CP1_CS_AS, N\',\' ) WITHIN GROUP (ORDER BY [ModuleOrdinal]) FROM [#CurrentOverview_ModulePayload] WHERE [IsEnabled]=1 ); SET @Json=CONCAT ( N\'{"meta":\',COALESCE(@MetaJson,N\'{}\') , N\',"moduleStatus":\',COALESCE(@ModuleStatusJson,N\'[]\') , N\',"snapshotStatus":\',COALESCE(@SnapshotStatusJson,N\'[]\') , CASE WHEN NULLIF(@ChildProperties,N\'\') IS NULL THEN N\'\' ELSE N\',\'+@ChildProperties END , N\',"warnings":\',COALESCE(@WarningsJson,N\'[]\'),N\'}\' ); END; IF @OutputMode=\'TABLE\' BEGIN DECLARE @ExportResultName sysname; DECLARE @ExportTargetTable sysname; DECLARE @ExportSourceTable sysname; DECLARE @CanExport bit; DECLARE [ExportCursor] CURSOR LOCAL FAST_FORWARD FOR SELECT [ResultName],[TargetTable] FROM [#CurrentOverview_ResultTableMap] ORDER BY [ResultName]; OPEN [ExportCursor]; FETCH NEXT FROM [ExportCursor] INTO @ExportResultName,@ExportTargetTable; WHILE @@FETCH_STATUS=0 BEGIN SELECT @ExportSourceTable=CASE WHEN @ExportResultName=N\'moduleStatus\' THEN N\'#CurrentOverview_ModuleStatus\' WHEN @ExportResultName=N\'snapshotStatus\' THEN N\'#CurrentOverview_SnapshotStatus\' WHEN @ExportResultName=N\'requestContext\' THEN N\'#CurrentOverview_RequestContext\' WHEN @ExportResultName=N\'statements\' THEN N\'#CurrentOverview_Statements\' WHEN @ExportResultName=N\'batches\' THEN N\'#CurrentOverview_Batches\' WHEN @ExportResultName=N\'inputBuffers\' THEN N\'#CurrentOverview_InputBuffers\' WHEN @ExportResultName=N\'tempdbGovernance\' THEN N\'#CurrentOverview_TempDBGovernance\' WHEN @ExportResultName=N\'warnings\' THEN N\'#CurrentOverview_Warnings\' ELSE NULL END , @CanExport=CASE WHEN @ExportResultName=N\'tempdbGovernance\' THEN @MitTempDB WHEN @ExportResultName IN (N\'moduleStatus\',N\'snapshotStatus\',N\'requestContext\', N\'statements\',N\'batches\',N\'inputBuffers\',N\'warnings\') THEN 1 ELSE 0 END; IF @ExportSourceTable IS NULL SELECT @ExportSourceTable=[SourceTable] , @CanExport=[IsMaterialized] FROM [#CurrentOverview_ModulePayload] WHERE [ResultName]=@ExportResultName; IF @CanExport=1 EXEC [monitor].[InternalWriteResultTable] @SourceTable=@ExportSourceTable , @TargetTable=@ExportTargetTable , @ThrowOnError=1; FETCH NEXT FROM [ExportCursor] INTO @ExportResultName,@ExportTargetTable; END; CLOSE [ExportCursor]; DEALLOCATE [ExportCursor]; END;'
CAPTURE_FLAGS='SET @CaptureSessions=CASE WHEN @MitSessions=1 OR @MitRequests=1 OR @MitBlocking=1 OR @MitWaits=1 OR @MitTransactions=1 OR @MitMemoryGrants=1 OR @MitTempDB=1 THEN 1 ELSE 0 END; SET @CaptureRequests=CASE WHEN @MitSessions=1 OR @MitRequests=1 OR @MitBlocking=1 OR @MitWaits=1 OR @MitTransactions=1 OR @MitMemoryGrants=1 OR @MitIO=1 THEN 1 ELSE 0 END; SET @CaptureConnections=CASE WHEN @MitSessions=1 OR @MitRequests=1 OR @MitBlocking=1 THEN 1 ELSE 0 END; SET @CaptureWaitingTasks=CASE WHEN @MitRequests=1 OR @MitBlocking=1 OR @MitWaits=1 OR @MitIO=1 THEN 1 ELSE 0 END; SET @CaptureMemoryGrants=CASE WHEN @MitRequests=1 OR @MitMemoryGrants=1 THEN 1 ELSE 0 END; SET @CaptureResourceGovernor=CASE WHEN @MitRequests=1 OR @MitMemoryGrants=1 OR @MitTempDB=1 THEN 1 ELSE 0 END; SET @CaptureTasks=CASE WHEN @MitRequests=1 OR @MitIO=1 THEN 1 ELSE 0 END; SET @CaptureSchedulers=CASE WHEN @MitRequests=1 OR @MitIO=1 THEN 1 ELSE 0 END; SET @CaptureTransactions=CASE WHEN @MitRequests=1 OR @MitTransactions=1 THEN 1 ELSE 0 END; SET @CaptureTempDbUsage=CASE WHEN @MitRequests=1 OR @MitTempDB=1 THEN 1 ELSE 0 END; SET @CaptureVersionStore=CASE WHEN @MitTempDB=1 THEN 1 ELSE 0 END; SET @CaptureSqlText=CASE WHEN @MitSessions=1 AND @MitSqlText=1 THEN 1 WHEN @MitRequests=1 AND (@MitSqlText=1 OR @GesamtenSqlTextEinbeziehen=1 OR @ModulInfoEinbeziehen=1) THEN 1 WHEN @MitBlocking=1 AND @MitSqlText=1 THEN 1 WHEN @MitWaits=1 AND @MitSqlText=1 THEN 1 WHEN @MitTransactions=1 AND @MitSqlText=1 THEN 1 WHEN @MitMemoryGrants=1 AND @MitSqlText=1 THEN 1 ELSE 0 END; SET @MaxSqlTextHandles=CASE WHEN @MaxZeilen IS NULL OR @MaxZeilen=0 THEN 0 WHEN @MaxZeilen>=1073741800 THEN 2147483647 ELSE @MaxZeilen*2+32 END;'

def findings(s):
    result=[]
    actual={m[1]:norm(m[2]) for m in re.finditer(r'CREATE\s+TABLE\s+\[(#[^\]]+)\]\s*\((.*?)\);',s,re.S|re.I)}
    if len(re.findall(r'CREATE\s+TABLE\s+\[(#[^\]]+)\]\s*\((.*?)\);',s,re.S|re.I))!=41 or any(actual.get(name)!=ddl for name,ddl in TABLES.items()): result.append('LITERAL_DDL_41')
    head=s.split('AS\nBEGIN',1)[0]
    params=[(m[1],norm(m[2]),norm(m[3] or '')) for m in re.finditer(r'^\s*,?\s*(@\w+)\s+([a-zA-Z][a-zA-Z0-9]*(?:\([^\n]*?\))?)\s*(?:=\s*([^\n]+))?',head,re.M)]
    if params!=ABI: result.append('ABI_31_ORDER_TYPE_DEFAULT_OUTPUT')
    calls={m[1]:norm(m[2]) for m in re.finditer(r'EXEC \[monitor\]\.\[(USP_Current(?:Sessions|Requests|Blocking|Waits|Transactions|MemoryGrants|TempDB|IO|Log))\](.*?);',s,re.S)}
    if len(re.findall(r'EXEC \[monitor\]\.\[(USP_Current(?:Sessions|Requests|Blocking|Waits|Transactions|MemoryGrants|TempDB|IO|Log))\](.*?);',s,re.S))!=9 or calls!=CHILD_CALLS: result.append('NINE_CHILD_CALL_ARGUMENTS')
    positions=[s.find('InternalPrepareResultTables'),s.find('IF @Hilfe = 1'),s.find("IF @OutputMode NOT IN"),s.find('SET @CaptureSessions=')]
    if -1 in positions or positions!=sorted(positions): result.append('EARLY_MAPPING_PRIORITY')
    early=s[:positions[1]] if positions[1]>=0 else ''
    predicate="IF @OutputMode='TABLE' OR NULLIF(LTRIM(RTRIM(COALESCE(@ResultTablesJson,N''))),N'') IS NOT NULL"
    if predicate not in early or "@StatusCode='AVAILABLE' AND @OutputMode='TABLE'" in s: result.append('MAPPING_ALL_CONTEXTS')
    if "@AllowedResultNames=N'moduleStatus|snapshotStatus|sessions|requests|requestContext|statements|batches|inputBuffers|blocking|waits|transactions|memoryGrants|tempdbSessions|tempdbGovernance|versionStore|io|logs|warnings'" not in s: result.append('TABLE_RESULT_NAME_CONTRACT')
    if "WHEN @ExportResultName=N'tempdbGovernance' THEN 1" in s: result.append('TEMPDB_GOVERNANCE_EXPORT_GATE')
    if s.find('SET @Json = NULL;')<0 or s.find('SET @Json = NULL;')>positions[0]: result.append('JSON_CLEARING')
    try:
        body=norm(s[s.index('BuildOutputs:'):s.index('    SET @RestoreLockTimeoutSql',s.index('BuildOutputs:'))])
        output_tokens=(
            "WHEN @ExportResultName=N'tempdbGovernance' THEN N'#CurrentOverview_TempDBGovernance'",
            "WHEN @ExportResultName=N'versionStore' THEN N'#CurrentOverview_VersionStore'",
            "WHEN @ExportResultName=N'tempdbGovernance' THEN @MitTempDB",
            "WHEN @ExportResultName=N'versionStore' THEN @MitTempDB",
            "@StatusCode='INVALID_PARAMETER' OR @PartialModules>0",
            "N'tempdbGovernance'", "N'versionStore'", "#CurrentOverview_ModuleStatus",
            "#CurrentOverview_SnapshotStatus", "#CurrentOverview_Warnings",
            "[ResultName],[ModuleName],[StatusCode],[IsPartial],[ReturnedRowCount],[DurationMs],[ErrorMessage]",
            "@DetailMode='ALL' OR [p].[IsRelevant]=1",
            "FROM [#CurrentOverview_ModulePayload] WHERE [IsEnabled]=1",
        )
        if any(token not in body for token in output_tokens): result.append('CONSUMERS_SEED_JSON_STATUS_FACETS')
    except ValueError: result.append('CONSUMERS_MISSING')
    try:
        if norm(s[s.index('    SET @CaptureSessions='):s.index('    IF @CaptureSessions=1')])!=CAPTURE_FLAGS: result.append('CAPTURE_FLAGS_LIMIT_IDENTITY')
    except ValueError: result.append('CAPTURE_FLAGS_MISSING')
    if len(re.findall(r'EXEC \[monitor\]\.\[InternalCaptureCurrentStateSnapshot\]',s))!=1: result.append('ONE_EXISTING_OWNER_CAPTURE')
    return result

def self_test(s):
    if findings(s): raise AssertionError('baseline failed: '+','.join(findings(s)))
    mutations=[]
    ddl=re.search(r'CREATE\s+TABLE\s+\[#[^\]]+\]\s*\(.*?\);',s,re.S)[0]
    child=re.search(r'EXEC \[monitor\]\.\[USP_CurrentSessions\].*?;',s,re.S)[0]
    mutations.extend([s+"\n"+ddl,s+"\n"+child])
    for name,ddl in TABLES.items():
        match=re.search(r'CREATE\s+TABLE\s+\['+re.escape(name)+r'\]\s*\((.*?)\);',s,re.S)
        block=match[0]
        for field in re.finditer(r'\[([^\]]+)\]\s+([a-zA-Z][a-zA-Z0-9]*)(\([^\n]*?\))?\s*(?:COLLATE\s+\w+\s*)?(NOT NULL|NULL)',match[1]):
            original=field[0]
            for replacement in (original.replace('['+field[1]+']','[ExampleMutatedField]',1),original.replace(field[2],'sql_variant',1),original.replace(field[4],'NULL' if field[4]=='NOT NULL' else 'NOT NULL')):
                mutations.append(s.replace(block,block.replace(original,replacement,1),1))
        for collation in re.finditer(r'COLLATE SQL_Latin1_General_CP1_CS_AS',match[1]):
            at=match.start(1)+collation.start();mutations.append(s[:at]+s[at:].replace(collation[0],'COLLATE Latin1_General_100_CI_AS',1))
    for name,typ,default in ABI:
        m=re.search(r'^\s*,?\s*'+re.escape(name)+r'\s+[^\n]+',s,re.M);line=m[0]
        for changed in (line.replace(name,'@ExampleMutation',1),line.replace(typ,'sql_variant',1),line.split('=')[0]+'= 987654'):
            mutations.append(s.replace(line,changed,1))
    mutations.append(s.replace('NULL OUTPUT','NULL',1))
    a=re.search(r'(@SessionIds[^\n]+)\n\s*, (@DatabaseNames[^\n]+)',s);mutations.append(s[:a.start()]+a[2]+'\n    , '+a[1]+s[a.end():])
    for child in CHILD_CALLS:
        mutations.append(s.replace('[monitor].['+child+']','[monitor].[USP_ExampleChangedChild]',1))
        argument=CHILD_CALLS[child]
        if '@ParentCurrentStateSnapshotId=@SnapshotConsumerId' in argument:
            start=s.index('EXEC [monitor].['+child+']');end=s.index(';',start)
            block=s[start:end];mutations.append(s[:start]+block.replace('@ParentCurrentStateSnapshotId=@SnapshotConsumerId','@ParentCurrentStateSnapshotId=NULL')+s[end:])
    mutations.extend([
        s.replace("IF @OutputMode='TABLE' OR NULLIF", "IF @StatusCode='AVAILABLE' AND @OutputMode='TABLE' OR NULLIF",1),
        s.replace('    IF @Hilfe = 1','    IF @OutputMode NOT IN (\'TABLE\') RETURN;\n    IF @Hilfe = 1',1),
        s.replace("@StatusCode='INVALID_PARAMETER' OR @PartialModules>0",'@PartialModules>0',1),
        s.replace('SET @Json = NULL;','SET @Json = N\'Example\';',1),
        s.replace('requestContext|statements','ExampleContext|statements',1),
        s.replace('[ResultName],[ModuleName],[StatusCode],[IsPartial],[ReturnedRowCount],[DurationMs],[ErrorMessage]','[ResultName],[ModuleName],[StatusCode],[ReturnedRowCount],[DurationMs],[ErrorMessage]',1),
        s.replace("@DetailMode='ALL' OR [p].[IsRelevant]=1","@DetailMode='ALL'",1),
        s.replace('WHEN @ExportResultName=N\'tempdbGovernance\' THEN @MitTempDB','WHEN @ExportResultName=N\'tempdbGovernance\' THEN 1',1),
        s.replace('WHERE [IsEnabled]=1','WHERE 1=1',1),
        s.replace('@MaxZeilen*2+32','@MaxZeilen*2+31',1),
    ])
    for index,changed in enumerate(mutations):
        if changed==s or not findings(changed): raise AssertionError(f'mutation {index} was not rejected')
    return len(mutations)

def main():
    p=argparse.ArgumentParser();p.add_argument('--repository-root',type=Path,required=True);p.add_argument('--self-test',action='store_true');args=p.parse_args()
    s=(args.repository_root/SOURCE).read_text(encoding='utf-8')
    if args.self_test: print(f'CurrentOverview self-test PASS: {self_test(s)} real mutations');return
    errors=findings(s)
    if errors: raise SystemExit('\n'.join(errors))
    print('CurrentOverview PASS: ABI31/tables41/fields303/texts50/exports17/children9/snapshot tables20')
if __name__=='__main__': main()
