IF SCHEMA_ID(N'monitor_metadata') IS NULL
    EXEC [sys].[sp_executesql] N'CREATE SCHEMA [monitor_metadata] AUTHORIZATION [dbo];';
GO
