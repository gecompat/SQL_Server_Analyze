USE [DeineDatenbank];
GO

/* OPS-005: Liest ausschließlich die zum zuvor erfassten Guardstate gehörenden Werte. */
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
IF @GuardState IS NULL OR @GuardState NOT BETWEEN 1 AND 7
    THROW 54896,N'OPS005_DIAGNOSTIC_STATE_INVALID',1;

DECLARE @Details nvarchar(max),@Definition nvarchar(max),@DefinitionStart int;
IF @GuardState=1
    SELECT @Details=(SELECT CONVERT(bit,CASE WHEN TRY_CONVERT(uniqueidentifier,@OperationId) IS NULL THEN 0 ELSE 1 END) AS [OperationValid],
        CONVERT(bit,CASE WHEN TRY_CONVERT(uniqueidentifier,@OperationId)='00000000-0000-0000-0000-000000000000' THEN 1 ELSE 0 END) AS [OperationEmpty]
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
ELSE IF @GuardState=2
    SELECT @Details=(SELECT CONVERT(nvarchar(36),TRY_CONVERT(uniqueidentifier,@OperationId)) AS [ExpectedMarker],
        CONVERT(nvarchar(128),(SELECT [value] FROM sys.extended_properties WHERE [class]=0 AND [major_id]=0 AND [minor_id]=0
            AND [name]=N'SQLANALYZE.Ops005Operation')) AS [ActualMarker]
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
ELSE IF @GuardState=3
    SELECT @Details=(SELECT CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion')) AS [MajorVersion],
        (SELECT [compatibility_level] FROM sys.databases WHERE [database_id]=DB_ID()) AS [CompatibilityLevel],
        CONVERT(nvarchar(128),SERVERPROPERTY(N'Collation')) AS [ServerCollation],
        CONVERT(nvarchar(128),DATABASEPROPERTYEX(N'master',N'Collation')) AS [MasterCollation],
        CONVERT(nvarchar(128),DATABASEPROPERTYEX(N'tempdb',N'Collation')) AS [TempdbCollation],
        CONVERT(nvarchar(128),DATABASEPROPERTYEX(DB_NAME(),N'Collation')) AS [DatabaseCollation],
        IS_SRVROLEMEMBER(N'sysadmin') AS [IsSysadmin],@@TRANCOUNT AS [TranCount]
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
ELSE IF @GuardState=4
    SELECT @Details=(SELECT (SELECT COUNT(*) FROM sys.databases WHERE [database_id]>4 AND [database_id]<>DB_ID()) AS [OtherUserDatabases],
        (SELECT COUNT(*) FROM sys.servers WHERE [server_id]<>0) AS [NonlocalServers]
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
ELSE IF @GuardState IN (5,6)
BEGIN
    SET @Definition=OBJECT_DEFINITION(OBJECT_ID(N'monitor.USP_LinkedServerAnalysis'));
    SET @DefinitionStart=CHARINDEX(N'CREATE OR ALTER PROCEDURE',@Definition);
    IF COALESCE(@DefinitionStart,0)=0
    BEGIN
        SET @DefinitionStart=CHARINDEX(N'CREATE   PROCEDURE [monitor].[USP_LinkedServerAnalysis]',@Definition);
        IF @DefinitionStart>0
            SET @Definition=STUFF(@Definition,@DefinitionStart,DATALENGTH(N'CREATE   ')/2,N'CREATE OR ALTER ');
    END;
    SELECT @Details=(SELECT OBJECT_ID(N'monitor.USP_LinkedServerAnalysis') AS [ObjectId],
        LEFT(@Definition,96) AS [DefinitionPrefix],@DefinitionStart AS [DefinitionStart],DATALENGTH(@Definition) AS [DefinitionBytes],
        DATALENGTH(@ExpectedDefinitionHash) AS [ExpectedHashBytes],CONVERT(varchar(64),@ExpectedDefinitionHash,2) AS [ExpectedHash],
        CASE WHEN @DefinitionStart>0 THEN CONVERT(varchar(64),HASHBYTES('SHA2_256',
            TRIM(NCHAR(9)+NCHAR(10)+NCHAR(13)+N' ' FROM REPLACE(SUBSTRING(@Definition,@DefinitionStart,LEN(@Definition)),NCHAR(13)+NCHAR(10),NCHAR(10)))),2) END AS [ActualNormalizedHash]
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);
END;
ELSE IF @GuardState=7
    SELECT @Details=(SELECT OBJECT_ID(N'monitor.USP_LinkedServerAnalysis') AS [ObjectId],
        JSON_QUERY((SELECT [parameter_id] AS [Id],[name] AS [Name],TYPE_NAME([system_type_id]) AS [Type],
            [max_length] AS [Length],[is_output] AS [Output] FROM sys.parameters
            WHERE [object_id]=OBJECT_ID(N'monitor.USP_LinkedServerAnalysis') ORDER BY [parameter_id]
            FOR JSON PATH,INCLUDE_NULL_VALUES)) AS [Parameters]
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES);

IF @Details IS NULL OR ISJSON(@Details)<>1 OR DATALENGTH(@Details)>65536
    THROW 54896,N'OPS005_DIAGNOSTIC_DETAILS_INVALID',2;
SELECT N'OPS005_PREREQUISITE_DETAILS' AS [Scope],CONVERT(int,@GuardState) AS [GuardState],@Details AS [DetailsJson];
