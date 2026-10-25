USE [DeineDatenbank];
GO
IF OBJECT_ID(N'tempdb..#ExampleEndpointTransportRuntimeContract') IS NOT NULL
    THROW 57300,N'Endpoint scoped fixture procedure already exists.',1;
GO
CREATE PROCEDURE [#ExampleEndpointTransportRuntimeContract] @NativeTableCases int OUTPUT
AS
BEGIN
SET NOCOUNT ON;
DECLARE @Suffix nvarchar(32)=REPLACE(CONVERT(nvarchar(36),NEWID()),N'-',N''),
    @Endpoint sysname,@Certificate sysname,@Login sysname,@FrameworkUser sysname,@MasterUser sysname,
    @Sql nvarchar(max),@Credential nvarchar(128),@EndpointId int,@EndpointOwner int,@CertId int,@Thumbprint varbinary(64),
    @LoginId int,@LoginSid varbinary(85),@FrameworkUserId int,@FrameworkUserSid varbinary(85),@MasterUserId int,@MasterUserSid varbinary(85),
    @KeyGuid uniqueidentifier,@KeyId int,@KeyCreated datetime,@OwnKey bit=0,
    @MadeEndpoint bit=0,@MadeCert bit=0,@MadeLogin bit=0,@MadeFrameworkUser bit=0,@MadeMasterUser bit=0,
    @Failure int,@FailureMessage nvarchar(2048),@Cleanup nvarchar(max)=N'',@AllCases bit=0,
    @OriginalDb int=DB_ID(),@OriginalLock int=@@LOCK_TIMEOUT,@OriginalAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,
    @Json nvarchar(max),@Expected nvarchar(max),@Status varchar(40),@Partial bit,@Error int,@Message nvarchar(2048),@Return int,
    @Case int=0,@Limit int,@SourceLock int,@CallStart datetime2(3),@CallEnd datetime2(3),@Port int=32700,
    @OwnConnectionEndpoint int,@OwnNet nvarchar(40),@OwnProtocol nvarchar(40),@OwnEncrypt nvarchar(40),@OwnAuth nvarchar(40),
    @BeforeEndpoints nvarchar(max),@BeforeRights nvarchar(max),@BeforeCertificates nvarchar(max),@BeforeSymmetric nvarchar(max),@BeforeAsymmetric nvarchar(max),@BeforeCredentials nvarchar(max),@BeforeKeyEncryptions nvarchar(max);
IF @@TRANCOUNT<>0 OR COALESCE(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1
    THROW 57301,N'Endpoint fixture requires an isolated sysadmin target without ambient transaction.',1;
IF EXISTS(SELECT 1 FROM [sys].[database_mirroring_endpoints])
    THROW 57302,N'Endpoint fixture requires no pre-existing mirroring endpoint; existing endpoints are never changed.',1;
SELECT @Endpoint=N'ExampleTransport_'+@Suffix,@Certificate=N'ExampleTransportCert_'+@Suffix,
       @Login=N'ExampleTransportLogin_'+@Suffix,@FrameworkUser=N'ExampleTransportUser_'+@Suffix,@MasterUser=N'ExampleTransportMaster_'+@Suffix;
SET @BeforeEndpoints=(SELECT [endpoint_id],[name],[principal_id],[protocol],[protocol_desc],[type],[type_desc],[state],[state_desc],[is_admin_endpoint] FROM [sys].[endpoints] ORDER BY [endpoint_id] FOR JSON PATH,INCLUDE_NULL_VALUES);
SET @BeforeRights=(SELECT [class],[major_id],[minor_id],[grantee_principal_id],[grantor_principal_id],[type],[permission_name],[state] FROM [sys].[server_permissions] WHERE [class]=105 ORDER BY [major_id],[minor_id],[grantee_principal_id],[grantor_principal_id],[type] FOR JSON PATH,INCLUDE_NULL_VALUES);
SET @BeforeCertificates=(SELECT [certificate_id],[name],[thumbprint],[pvt_key_encryption_type],[start_date],[expiry_date] FROM [master].[sys].[certificates] ORDER BY [certificate_id] FOR JSON PATH,INCLUDE_NULL_VALUES);
SET @BeforeSymmetric=(SELECT [symmetric_key_id],[name],[key_guid],[create_date],[modify_date] FROM [master].[sys].[symmetric_keys] ORDER BY [symmetric_key_id] FOR JSON PATH,INCLUDE_NULL_VALUES);
SET @BeforeAsymmetric=(SELECT [asymmetric_key_id],[name],[thumbprint],[pvt_key_encryption_type] FROM [master].[sys].[asymmetric_keys] ORDER BY [asymmetric_key_id] FOR JSON PATH,INCLUDE_NULL_VALUES);
SET @BeforeCredentials=(SELECT [credential_id],[name],[create_date],[modify_date] FROM [master].[sys].[database_scoped_credentials] ORDER BY [credential_id] FOR JSON PATH,INCLUDE_NULL_VALUES);
SET @BeforeKeyEncryptions=(SELECT [key_id],[thumbprint],[crypt_type] FROM [master].[sys].[key_encryptions] ORDER BY [key_id],[thumbprint],[crypt_type] FOR JSON PATH,INCLUDE_NULL_VALUES);
CREATE TABLE [#ExampleTransport_Sentinel]([Id] int NOT NULL,[Value] int NOT NULL);
INSERT [#ExampleTransport_Sentinel] VALUES(1,9);
BEGIN TRY
 IF EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Login COLLATE SQL_Latin1_General_CP1_CS_AS)
 OR EXISTS(SELECT 1 FROM [master].[sys].[certificates] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Certificate COLLATE SQL_Latin1_General_CP1_CS_AS)
 OR EXISTS(SELECT 1 FROM [sys].[endpoints] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Endpoint COLLATE SQL_Latin1_General_CP1_CS_AS)
 OR EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@FrameworkUser COLLATE SQL_Latin1_General_CP1_CS_AS)
 OR EXISTS(SELECT 1 FROM [master].[sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@MasterUser COLLATE SQL_Latin1_General_CP1_CS_AS)
  THROW 57303,N'Owned endpoint fixture name collision.',1;
 IF NOT EXISTS(SELECT 1 FROM [master].[sys].[symmetric_keys] WHERE [name]=N'##MS_DatabaseMasterKey##')
 BEGIN
  SET @Credential=N'Example!'+CONVERT(nvarchar(36),NEWID());
  SET @Sql=N'CREATE MASTER KEY ENCRYPTION BY PASSWORD '+N'= '+QUOTENAME(@Credential,'''')+N';';
  EXEC [master].[sys].[sp_executesql] @Sql;SET @OwnKey=1;
  SELECT @KeyId=[symmetric_key_id],@KeyGuid=[key_guid],@KeyCreated=[create_date] FROM [master].[sys].[symmetric_keys] WHERE [name]=N'##MS_DatabaseMasterKey##';
  IF @KeyId IS NULL OR @KeyGuid IS NULL OR @KeyCreated IS NULL THROW 57304,N'Owned DMK binding missing.',1;
 END;
 SET @Sql=N'CREATE CERTIFICATE '+QUOTENAME(@Certificate)+N' WITH SUBJECT=N''Example transport fixture'', START_DATE=''20250101'', EXPIRY_DATE=''20990101'';';
 EXEC [master].[sys].[sp_executesql] @Sql;SET @MadeCert=1;
 SELECT @CertId=[certificate_id],@Thumbprint=[thumbprint] FROM [master].[sys].[certificates] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Certificate COLLATE SQL_Latin1_General_CP1_CS_AS;
 IF @CertId IS NULL OR @Thumbprint IS NULL THROW 57305,N'Owned certificate binding missing.',1;
 WHILE @Port<=32767 AND EXISTS(SELECT 1 FROM [sys].[tcp_endpoints] WHERE [port]=@Port) SET @Port+=1;
 IF @Port>32767 THROW 57306,N'No free bounded catalog port for owned endpoint.',1;
 SET @Sql=N'CREATE ENDPOINT '+QUOTENAME(@Endpoint)+N' STATE=STOPPED AS TCP(LISTENER_PORT='+CONVERT(nvarchar(10),@Port)+N') FOR DATABASE_MIRRORING(AUTHENTICATION=CERTIFICATE '+QUOTENAME(@Certificate)+N',ENCRYPTION=REQUIRED ALGORITHM AES,ROLE=ALL);';
 EXEC [master].[sys].[sp_executesql] @Sql;SET @MadeEndpoint=1;
 SELECT @EndpointId=[endpoint_id],@EndpointOwner=[principal_id] FROM [sys].[endpoints] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Endpoint COLLATE SQL_Latin1_General_CP1_CS_AS AND [type]=4;
 IF @EndpointId IS NULL OR @EndpointOwner IS NULL THROW 57307,N'Owned endpoint binding missing.',1;
 IF @BeforeEndpoints COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [endpoint_id],[name],[principal_id],[protocol],[protocol_desc],[type],[type_desc],[state],[state_desc],[is_admin_endpoint] FROM [sys].[endpoints] WHERE [endpoint_id]<>@EndpointId ORDER BY [endpoint_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
 OR @BeforeRights COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [class],[major_id],[minor_id],[grantee_principal_id],[grantor_principal_id],[type],[permission_name],[state] FROM [sys].[server_permissions] WHERE [class]=105 AND [major_id]<>@EndpointId ORDER BY [major_id],[minor_id],[grantee_principal_id],[grantor_principal_id],[type] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS THROW 57308,N'Existing endpoint state or permissions changed during owned arrange.',1;
 SELECT @OwnConnectionEndpoint=[endpoint_id],@OwnNet=[net_transport],@OwnProtocol=[protocol_type],@OwnEncrypt=[encrypt_option],@OwnAuth=[auth_scheme] FROM [sys].[dm_exec_connections] WHERE [session_id]=@@SPID AND [net_transport]<>N'Session';
 IF @OwnNet IS NULL THROW 57309,N'Own native connection counterprobe missing.',1;
 CREATE TABLE [#ExampleTransport_Expected_moduleStatus]
 (
    [ModuleName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [CapturedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [IsPartial] bit NOT NULL,
    [RowCount] bigint NOT NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#ExampleTransport_Expected_endpoints]
 (
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [PrincipalId] int NULL,
    [Protocol] tinyint NOT NULL,
    [ProtocolDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EndpointType] tinyint NOT NULL,
    [EndpointTypeDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EndpointState] tinyint NULL,
    [EndpointStateDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [IsAdminEndpoint] bit NOT NULL
 );
 CREATE TABLE [#ExampleTransport_Expected_tcpEndpoints]
 (
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [Port] int NOT NULL,
    [IsDynamicPort] bit NOT NULL,
    [IpAddress] nvarchar(45) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
 );
 CREATE TABLE [#ExampleTransport_Expected_mirroringEndpoints]
 (
    [EndpointId] int NOT NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [MirroringRole] tinyint NULL,
    [MirroringRoleDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [IsEncryptionEnabled] bit NOT NULL,
    [ConnectionAuthentication] tinyint NOT NULL,
    [ConnectionAuthenticationDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [CertificateId] int NOT NULL,
    [EncryptionAlgorithm] tinyint NOT NULL,
    [EncryptionAlgorithmDescription] nvarchar(60) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
 );
 CREATE TABLE [#ExampleTransport_Expected_connectionEncryptionSummary]
 (
    [EndpointId] int NULL,
    [EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EndpointType] tinyint NULL,
    [NetTransport] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ProtocolType] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [EncryptOption] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [AuthenticationScheme] nvarchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ConnectionRows] bigint NOT NULL,
    [EndpointContextStatus] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [EncryptionEvidence] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#ExampleTransport_Expected_sourceStatus]
 (
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKind] varchar(16) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [RowUnit] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [StartedAtUtc] datetime2(3) NOT NULL,
    [CompletedAtUtc] datetime2(3) NOT NULL,
    [StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [VisibilityScope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [ObservedRows] bigint NULL,
    [ReturnedRows] bigint NULL,
    [IsLimited] bit NOT NULL,
    [ErrorNumber] int NULL,
    [ErrorMessage] nvarchar(2048) COLLATE SQL_Latin1_General_CP1_CS_AS NULL
 );
 CREATE TABLE [#ExampleTransport_Expected_warnings]
 (
    [WarningCode] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,
    [SourceKey] varchar(64) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,
    [Detail] nvarchar(1000) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL
 );
 CREATE TABLE [#ExampleTransport_Shapes]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ExpectedName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[ActualName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 INSERT [#ExampleTransport_Shapes] VALUES
 (N'moduleStatus',N'#ExampleTransport_Expected_moduleStatus',N'#ExampleTransport_moduleStatus'),
 (N'endpoints',N'#ExampleTransport_Expected_endpoints',N'#ExampleTransport_endpoints'),
 (N'tcpEndpoints',N'#ExampleTransport_Expected_tcpEndpoints',N'#ExampleTransport_tcpEndpoints'),
 (N'mirroringEndpoints',N'#ExampleTransport_Expected_mirroringEndpoints',N'#ExampleTransport_mirroringEndpoints'),
 (N'connectionEncryptionSummary',N'#ExampleTransport_Expected_connectionEncryptionSummary',N'#ExampleTransport_connectionEncryptionSummary'),
 (N'sourceStatus',N'#ExampleTransport_Expected_sourceStatus',N'#ExampleTransport_sourceStatus'),
 (N'warnings',N'#ExampleTransport_Expected_warnings',N'#ExampleTransport_warnings');
 INSERT [#ExampleTransport_Expected_endpoints] SELECT [endpoint_id],[name],[principal_id],[protocol],[protocol_desc],[type],[type_desc],[state],[state_desc],[is_admin_endpoint] FROM [sys].[endpoints];
 INSERT [#ExampleTransport_Expected_tcpEndpoints] SELECT [endpoint_id],[name],[port],[is_dynamic_port],CONVERT(nvarchar(45),[ip_address]) FROM [sys].[tcp_endpoints];
 INSERT [#ExampleTransport_Expected_mirroringEndpoints] SELECT [endpoint_id],[name],[role],[role_desc],[is_encryption_enabled],[connection_auth],[connection_auth_desc],[certificate_id],[encryption_algorithm],[encryption_algorithm_desc] FROM [sys].[database_mirroring_endpoints];
 CREATE TABLE [#ExampleTransport_ExpectedFacets]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Ordinal] bigint NOT NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TypeId] tinyint NOT NULL,[Length] smallint NOT NULL,[Precision] tinyint NOT NULL,[Scale] tinyint NOT NULL,[Nullable] bit NOT NULL,[Collation] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 CREATE TABLE [#ExampleTransport_ActualFacets]([ResultName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[Ordinal] bigint NOT NULL,[ColumnName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[TypeId] tinyint NOT NULL,[Length] smallint NOT NULL,[Precision] tinyint NOT NULL,[Scale] tinyint NOT NULL,[Nullable] bit NOT NULL,[Collation] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL);
 INSERT [#ExampleTransport_ExpectedFacets] SELECT [s].[ResultName],ROW_NUMBER() OVER(PARTITION BY [s].[ResultName] ORDER BY [c].[column_id]),[c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],[c].[is_nullable],[c].[collation_name]
 FROM [#ExampleTransport_Shapes] AS [s] JOIN [tempdb].[sys].[columns] AS [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[s].[ExpectedName]);
 WHILE @Case<4
 BEGIN
  CREATE TABLE [#ExampleTransport_moduleStatus]([Seed] int NULL);
  CREATE TABLE [#ExampleTransport_endpoints]([Seed] int NULL);
  CREATE TABLE [#ExampleTransport_tcpEndpoints]([Seed] int NULL);
  CREATE TABLE [#ExampleTransport_mirroringEndpoints]([Seed] int NULL);
  CREATE TABLE [#ExampleTransport_connectionEncryptionSummary]([Seed] int NULL);
  CREATE TABLE [#ExampleTransport_sourceStatus]([Seed] int NULL);
  CREATE TABLE [#ExampleTransport_warnings]([Seed] int NULL);
  DECLARE @Map nvarchar(max)=N'{"moduleStatus":"#ExampleTransport_moduleStatus","endpoints":"#ExampleTransport_endpoints","tcpEndpoints":"#ExampleTransport_tcpEndpoints","mirroringEndpoints":"#ExampleTransport_mirroringEndpoints","connectionEncryptionSummary":"#ExampleTransport_connectionEncryptionSummary","sourceStatus":"#ExampleTransport_sourceStatus","warnings":"#ExampleTransport_warnings"}';
  SET @Limit=CASE WHEN @Case=1 THEN 1 WHEN @Case=2 THEN NULL ELSE 0 END;
  SET @SourceLock=CASE WHEN @Case%2=0 THEN 31 ELSE 0 END;
  IF @Case IN (2,3) SET XACT_ABORT ON;ELSE SET XACT_ABORT OFF;
  SET LOCK_TIMEOUT 43;
  IF @Case=3 BEGIN BEGIN TRANSACTION; UPDATE [#ExampleTransport_Sentinel] SET [Value]=11 WHERE [Id]=1; END;
  SET @CallStart=SYSUTCDATETIME();
  EXEC @Return=[monitor].[USP_EndpointTransportAnalysis] @MaxZeilen=@Limit,@LockTimeoutMs=@SourceLock,@ResultSetArt='TABLE',@ResultTablesJson=@Map,@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@IsPartialOut=@Partial OUTPUT,@ErrorNumberOut=@Error OUTPUT,@ErrorMessageOut=@Message OUTPUT;
  SET @CallEnd=SYSUTCDATETIME();
  IF COALESCE(@Return,-1)<>0 OR COALESCE(@Status COLLATE SQL_Latin1_General_CP1_CS_AS,'')<>'AVAILABLE_LIMITED' OR COALESCE(@Partial,0)<>1 OR @Error IS NOT NULL THROW 57310,N'Endpoint TABLE status differs.',1;
  IF @@LOCK_TIMEOUT<>43 OR @@TRANCOUNT<>CASE WHEN @Case=3 THEN 1 ELSE 0 END OR (@Case=3 AND XACT_STATE()<>1) OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>CASE WHEN @Case IN (2,3) THEN 1 ELSE 0 END OR DB_ID()<>@OriginalDb BEGIN SET @Message=CONCAT(N'Endpoint caller state differs; case=',@Case,N'; lock=',@@LOCK_TIMEOUT,N'; transaction=',@@TRANCOUNT,N'; xactState=',XACT_STATE(),N'; abort=',CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,N'; database=',DB_ID(),N'; expectedDatabase=',@OriginalDb);THROW 57311,@Message,1;END;
  IF @Case<>3 AND EXISTS(SELECT 1 FROM [sys].[dm_tran_session_transactions] WHERE [session_id]=@@SPID AND [is_user_transaction]=1) THROW 57311,N'Endpoint left a native user transaction without an ambient transaction.',1;
  IF ISJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS)<>1 OR (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS))<>8 OR (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS) WHERE [type]=4)<>7 OR JSON_VALUE(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.meta.schemaVersion')<>'1' THROW 57312,N'Endpoint JSON arrays or schema version differ.',1;
  DELETE FROM [#ExampleTransport_ActualFacets];
  INSERT [#ExampleTransport_ActualFacets] SELECT [s].[ResultName],ROW_NUMBER() OVER(PARTITION BY [s].[ResultName] ORDER BY [c].[column_id]),[c].[name],[c].[system_type_id],[c].[max_length],[c].[precision],[c].[scale],[c].[is_nullable],[c].[collation_name]
  FROM [#ExampleTransport_Shapes] AS [s] JOIN [tempdb].[sys].[columns] AS [c] ON [c].[object_id]=OBJECT_ID(N'tempdb..'+[s].[ActualName]);
  IF EXISTS(SELECT * FROM [#ExampleTransport_ActualFacets] EXCEPT SELECT * FROM [#ExampleTransport_ExpectedFacets]) OR EXISTS(SELECT * FROM [#ExampleTransport_ExpectedFacets] EXCEPT SELECT * FROM [#ExampleTransport_ActualFacets]) THROW 57313,N'Endpoint seven-set independent schema facets differ.',1;
  SET @Expected=(SELECT * FROM [#ExampleTransport_moduleStatus] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]')<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.moduleStatus'),N'[]') THROW 57314,N'Endpoint TABLE JSON parity differs: moduleStatus.',1;
  SET @Expected=(SELECT * FROM [#ExampleTransport_endpoints] ORDER BY [EndpointId] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]')<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.endpoints'),N'[]') THROW 57314,N'Endpoint TABLE JSON parity differs: endpoints.',1;
  SET @Expected=(SELECT * FROM [#ExampleTransport_tcpEndpoints] ORDER BY [EndpointId] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]')<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.tcpEndpoints'),N'[]') THROW 57314,N'Endpoint TABLE JSON parity differs: tcpEndpoints.',1;
  SET @Expected=(SELECT * FROM [#ExampleTransport_mirroringEndpoints] ORDER BY [EndpointId] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]')<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.mirroringEndpoints'),N'[]') THROW 57314,N'Endpoint TABLE JSON parity differs: mirroringEndpoints.',1;
  SET @Expected=(SELECT * FROM [#ExampleTransport_connectionEncryptionSummary] ORDER BY [EndpointId],[NetTransport],[ProtocolType],[EncryptOption],[AuthenticationScheme] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]')<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.connectionEncryptionSummary'),N'[]') THROW 57314,N'Endpoint TABLE JSON parity differs: connectionEncryptionSummary.',1;
  SET @Expected=(SELECT * FROM [#ExampleTransport_sourceStatus] ORDER BY [SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]')<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus'),N'[]') THROW 57314,N'Endpoint TABLE JSON parity differs: sourceStatus.',1;
  SET @Expected=(SELECT * FROM [#ExampleTransport_warnings] ORDER BY [WarningCode],[SourceKey] FOR JSON PATH,INCLUDE_NULL_VALUES);
  IF COALESCE(@Expected COLLATE SQL_Latin1_General_CP1_CS_AS,N'[]')<>COALESCE(JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.warnings'),N'[]') THROW 57314,N'Endpoint TABLE JSON parity differs: warnings.',1;
  IF EXISTS(SELECT * FROM [#ExampleTransport_endpoints] EXCEPT SELECT * FROM (SELECT TOP (CASE WHEN @Limit=1 THEN 1 ELSE 2147483647 END) * FROM [#ExampleTransport_Expected_endpoints] ORDER BY [EndpointId]) AS [ExpectedTop]) OR EXISTS(SELECT * FROM (SELECT TOP (CASE WHEN @Limit=1 THEN 1 ELSE 2147483647 END) * FROM [#ExampleTransport_Expected_endpoints] ORDER BY [EndpointId]) AS [ExpectedTop] EXCEPT SELECT * FROM [#ExampleTransport_endpoints]) THROW 57315,N'Endpoint independent native values differ: endpoints.',1;
  IF EXISTS(SELECT * FROM [#ExampleTransport_tcpEndpoints] EXCEPT SELECT * FROM (SELECT TOP (CASE WHEN @Limit=1 THEN 1 ELSE 2147483647 END) * FROM [#ExampleTransport_Expected_tcpEndpoints] ORDER BY [EndpointId]) AS [ExpectedTop]) OR EXISTS(SELECT * FROM (SELECT TOP (CASE WHEN @Limit=1 THEN 1 ELSE 2147483647 END) * FROM [#ExampleTransport_Expected_tcpEndpoints] ORDER BY [EndpointId]) AS [ExpectedTop] EXCEPT SELECT * FROM [#ExampleTransport_tcpEndpoints]) THROW 57315,N'Endpoint independent native values differ: tcpEndpoints.',1;
  IF EXISTS(SELECT * FROM [#ExampleTransport_mirroringEndpoints] EXCEPT SELECT * FROM (SELECT TOP (CASE WHEN @Limit=1 THEN 1 ELSE 2147483647 END) * FROM [#ExampleTransport_Expected_mirroringEndpoints] ORDER BY [EndpointId]) AS [ExpectedTop]) OR EXISTS(SELECT * FROM (SELECT TOP (CASE WHEN @Limit=1 THEN 1 ELSE 2147483647 END) * FROM [#ExampleTransport_Expected_mirroringEndpoints] ORDER BY [EndpointId]) AS [ExpectedTop] EXCEPT SELECT * FROM [#ExampleTransport_mirroringEndpoints]) THROW 57315,N'Endpoint independent native values differ: mirroringEndpoints.',1;
  IF (SELECT COUNT(*) FROM [#ExampleTransport_sourceStatus])<>5 OR (SELECT COUNT(*) FROM [#ExampleTransport_sourceStatus] WHERE [SourceKind]='NATIVE')<>4
  OR EXISTS(SELECT 1 FROM [#ExampleTransport_sourceStatus] WHERE [StartedAtUtc]<@CallStart OR [CompletedAtUtc]>@CallEnd OR [CompletedAtUtc]<[StartedAtUtc] OR [ErrorNumber] IS NOT NULL)
  OR NOT EXISTS(SELECT 1 FROM [#ExampleTransport_sourceStatus] WHERE [SourceKey]='CONNECTIONS' AND [RowUnit]='CONNECTION_ROW' AND [ObservedRows]>=1 AND [ReturnedRows] IS NULL AND [IsLimited]=0)
  OR NOT EXISTS(SELECT 1 FROM [#ExampleTransport_sourceStatus] WHERE [SourceKey]='CONNECTION_ENCRYPTION_SUMMARY' AND [SourceKind]='DERIVED' AND [RowUnit]='SUMMARY_GROUP' AND [ObservedRows]>=1 AND [ReturnedRows]=(SELECT COUNT_BIG(*) FROM [#ExampleTransport_connectionEncryptionSummary])) THROW 57316,N'Endpoint source timing counts or units differ.',1;
  IF NOT EXISTS(SELECT 1 FROM [#ExampleTransport_mirroringEndpoints] WHERE [EndpointId]=@EndpointId AND [EndpointName] COLLATE SQL_Latin1_General_CP1_CS_AS=@Endpoint COLLATE SQL_Latin1_General_CP1_CS_AS AND [IsEncryptionEnabled]=1 AND [ConnectionAuthentication]=4 AND [CertificateId]=@CertId AND [EncryptionAlgorithm]=2 AND [MirroringRole]=3) THROW 57317,N'Own positive mirroring configuration differs.',1;
  IF EXISTS(SELECT 1 FROM [#ExampleTransport_connectionEncryptionSummary] WHERE [ConnectionRows]<1)
  OR EXISTS(SELECT 1 FROM [#ExampleTransport_connectionEncryptionSummary] AS [a] JOIN [#ExampleTransport_Expected_endpoints] AS [e] ON [e].[EndpointId]=[a].[EndpointId] WHERE [a].[EndpointName] COLLATE SQL_Latin1_General_CP1_CS_AS<>[e].[EndpointName] COLLATE SQL_Latin1_General_CP1_CS_AS OR [a].[EndpointType]<>[e].[EndpointType] OR [a].[EndpointContextStatus]<>'MATCHED_VISIBLE_ENDPOINT') THROW 57318,N'Endpoint group namespace or positive row count differs.',1;
  IF @Case<>1
  BEGIN
   IF (SELECT SUM([ConnectionRows]) FROM [#ExampleTransport_connectionEncryptionSummary])<>(SELECT [ObservedRows] FROM [#ExampleTransport_sourceStatus] WHERE [SourceKey]='CONNECTIONS') THROW 57319,N'Native rows and summary-group units are conflated.',1;
   IF NOT EXISTS(SELECT 1 FROM [#ExampleTransport_connectionEncryptionSummary] WHERE [EndpointId]=@OwnConnectionEndpoint AND [NetTransport] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnNet COLLATE SQL_Latin1_General_CP1_CS_AS AND [ProtocolType] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnProtocol COLLATE SQL_Latin1_General_CP1_CS_AS AND [EncryptOption] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnEncrypt COLLATE SQL_Latin1_General_CP1_CS_AS AND [AuthenticationScheme] COLLATE SQL_Latin1_General_CP1_CS_AS=@OwnAuth COLLATE SQL_Latin1_General_CP1_CS_AS AND [ConnectionRows]>=1 AND [EncryptionEvidence]='TSQL_FLAG_ONLY') THROW 57320,N'Own native connection counterprobe differs.',1;
  END
  ELSE IF EXISTS(SELECT 1 FROM [#ExampleTransport_sourceStatus] WHERE [SourceKey] IN ('ENDPOINTS','TCP_ENDPOINTS','MIRRORING_ENDPOINTS','CONNECTION_ENCRYPTION_SUMMARY') AND [ReturnedRows]>1)
   OR NOT EXISTS(SELECT 1 FROM [#ExampleTransport_sourceStatus] WHERE [SourceKey]='ENDPOINTS' AND [ObservedRows]>1 AND [ReturnedRows]=1 AND [IsLimited]=1) THROW 57321,N'Endpoint independent output caps differ.',1;
  IF NOT EXISTS(SELECT 1 FROM [#ExampleTransport_moduleStatus] WHERE [RowCount]=(SELECT COUNT_BIG(*) FROM [#ExampleTransport_endpoints])+(SELECT COUNT_BIG(*) FROM [#ExampleTransport_tcpEndpoints])+(SELECT COUNT_BIG(*) FROM [#ExampleTransport_mirroringEndpoints])+(SELECT COUNT_BIG(*) FROM [#ExampleTransport_connectionEncryptionSummary])) THROW 57322,N'Endpoint module row count differs.',1;
  IF @Case=3
  BEGIN
   IF (SELECT [Value] FROM [#ExampleTransport_Sentinel] WHERE [Id]=1)<>11 THROW 57323,N'Endpoint ambient sentinel differs.',1;
   ROLLBACK TRANSACTION;
   IF (SELECT [Value] FROM [#ExampleTransport_Sentinel] WHERE [Id]=1)<>9 THROW 57323,N'Endpoint sentinel rollback differs.',1;
  END;
  DROP TABLE [#ExampleTransport_moduleStatus];
  DROP TABLE [#ExampleTransport_endpoints];
  DROP TABLE [#ExampleTransport_tcpEndpoints];
  DROP TABLE [#ExampleTransport_mirroringEndpoints];
  DROP TABLE [#ExampleTransport_connectionEncryptionSummary];
  DROP TABLE [#ExampleTransport_sourceStatus];
  DROP TABLE [#ExampleTransport_warnings];
  SET @Case+=1;
 END;
 EXEC @Return=[monitor].[USP_EndpointTransportAnalysis] @MaxZeilen=1,@ResultSetArt='RAW',@PrintMeldungen=0;
 IF @Return<>0 THROW 57324,N'Endpoint RAW execution failed.',1;
 CREATE TABLE [#ExampleTransport_Console]([Ergebnis] nvarchar(200) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Scope] varchar(32) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL,[EndpointId] int NULL,[EndpointName] sysname COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[StatusCode] varchar(40) COLLATE SQL_Latin1_General_CP1_CS_AS NULL,[Detail] nvarchar(max) COLLATE SQL_Latin1_General_CP1_CS_AS NOT NULL);
 INSERT [#ExampleTransport_Console] EXEC [monitor].[USP_EndpointTransportAnalysis] @MaxZeilen=1,@ResultSetArt='CONSOLE',@PrintMeldungen=0;
 IF NOT EXISTS(SELECT 1 FROM [#ExampleTransport_Console] WHERE [Scope]='ENDPOINT') OR (SELECT COUNT(*) FROM [#ExampleTransport_Console] WHERE [Scope]='SOURCE')<>5 OR NOT EXISTS(SELECT 1 FROM [#ExampleTransport_Console] WHERE [Scope]='WARNING' AND [Detail] LIKE N'TLS_DETAILS_UNPROVEN%') THROW 57325,N'Endpoint canonical console data and source evidence differ.',1;
 EXEC @Return=[monitor].[USP_EndpointTransportAnalysis] @Hilfe=1,@StatusCodeOut=@Status OUTPUT,@PrintMeldungen=0;
 IF @Return<>0 OR @Status COLLATE SQL_Latin1_General_CP1_CS_AS<>'AVAILABLE' THROW 57326,N'Endpoint help differs.',1;
 SET XACT_ABORT ON;SET LOCK_TIMEOUT 53;BEGIN TRANSACTION;
 UPDATE [#ExampleTransport_Sentinel] SET [Value]=11 WHERE [Id]=1;
 EXEC @Return=[monitor].[USP_EndpointTransportAnalysis] @MaxZeilen=-1,@ResultSetArt='NONE',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
 IF @Return<>51011 OR @Error<>51011 OR @Status COLLATE SQL_Latin1_General_CP1_CS_AS<>'INVALID_PARAMETER' OR @Json IS NOT NULL OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>53 OR (@@OPTIONS&16384)<>16384 THROW 57327,N'Endpoint invalid API or caller protection differs.',1;
 EXEC @Return=[monitor].[USP_EndpointTransportAnalysis] @ResultSetArt='TABLE',@ResultTablesJson=N'{"unknown":"#ExampleTransport_Console"}',@JsonErzeugen=1,@Json=@Json OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@Status OUTPUT,@ErrorNumberOut=@Error OUTPUT;
 IF @Return<>51011 OR @Error<>51011 OR @Json IS NOT NULL OR @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>53 OR (@@OPTIONS&16384)<>16384 THROW 57328,N'Endpoint TABLE preflight or caller protection differs.',1;
 ROLLBACK TRANSACTION;
 IF (SELECT [Value] FROM [#ExampleTransport_Sentinel] WHERE [Id]=1)<>9 THROW 57328,N'Endpoint API sentinel rollback differs.',1;
 SET XACT_ABORT OFF;
 SET @Credential=N'Example!'+CONVERT(nvarchar(36),NEWID());
 SET @Sql=N'CREATE LOGIN '+QUOTENAME(@Login)+N' WITH PASSWORD '+N'= '+QUOTENAME(@Credential,'''')+N',CHECK_POLICY=OFF,CHECK_EXPIRATION=OFF;';
 EXEC [master].[sys].[sp_executesql] @Sql;SET @MadeLogin=1;
 SELECT @LoginId=[principal_id],@LoginSid=[sid] FROM [sys].[server_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Login COLLATE SQL_Latin1_General_CP1_CS_AS;
 IF @LoginId IS NULL OR @LoginSid IS NULL THROW 57329,N'Owned restricted login binding missing.',1;
 SET @Sql=N'CREATE USER '+QUOTENAME(@FrameworkUser)+N' FOR LOGIN '+QUOTENAME(@Login)+N';';EXEC [sys].[sp_executesql] @Sql;SET @MadeFrameworkUser=1;
 SELECT @FrameworkUserId=[principal_id],@FrameworkUserSid=[sid] FROM [sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@FrameworkUser COLLATE SQL_Latin1_General_CP1_CS_AS;
 IF @FrameworkUserId IS NULL OR @FrameworkUserSid IS NULL THROW 57330,N'Owned framework user binding missing.',1;
 SET @Sql=N'GRANT EXECUTE ON [monitor].[USP_EndpointTransportAnalysis] TO '+QUOTENAME(@FrameworkUser)+N';';EXEC [sys].[sp_executesql] @Sql;
 SET @Sql=N'CREATE USER '+QUOTENAME(@MasterUser)+N' FOR LOGIN '+QUOTENAME(@Login)+N';';EXEC [master].[sys].[sp_executesql] @Sql;SET @MadeMasterUser=1;
 SELECT @MasterUserId=[principal_id],@MasterUserSid=[sid] FROM [master].[sys].[database_principals] WHERE [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@MasterUser COLLATE SQL_Latin1_General_CP1_CS_AS;
 IF @MasterUserId IS NULL OR @MasterUserSid IS NULL THROW 57331,N'Owned master user binding missing.',1;
 SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';
 BEGIN TRY
  IF SUSER_ID()<>@Id THROW 57332,N''Restricted native context differs.'',1;
  EXEC @Ret=[monitor].[USP_EndpointTransportAnalysis] @ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@ErrorNumberOut=@Err OUTPUT;
  REVERT;
 END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
 EXEC [sys].[sp_executesql] @Sql,N'@Id int,@Ret int OUTPUT,@J nvarchar(max) OUTPUT,@Err int OUTPUT',@Id=@LoginId,@Ret=@Return OUTPUT,@J=@Json OUTPUT,@Err=@Error OUTPUT;
 IF @Return<>0 OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([SourceKey] varchar(64),[StatusCode] varchar(40),[ErrorNumber] int,[ObservedRows] bigint,[ReturnedRows] bigint) WHERE [SourceKey]='CONNECTIONS' AND [StatusCode]='DENIED_PERMISSION' AND [ErrorNumber] IS NOT NULL AND [ObservedRows] IS NULL AND [ReturnedRows] IS NULL)
 OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([SourceKey] varchar(64),[StatusCode] varchar(40),[ObservedRows] bigint) WHERE [SourceKey]='CONNECTION_ENCRYPTION_SUMMARY' AND [StatusCode]='SOURCE_UNAVAILABLE' AND [ObservedRows] IS NULL) THROW 57333,N'Unprivileged native DMV failure or dependent unknown count differs.',1;
 SET @Sql=CASE WHEN TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))<16 THEN N'GRANT VIEW SERVER STATE TO ' ELSE N'GRANT VIEW SERVER PERFORMANCE STATE TO ' END+QUOTENAME(@Login)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
 IF TRY_CONVERT(int,SERVERPROPERTY(N'ProductMajorVersion'))>=16 BEGIN SET @Sql=N'GRANT VIEW SERVER SECURITY STATE TO '+QUOTENAME(@Login)+N';';EXEC [master].[sys].[sp_executesql] @Sql;END;
 SET @Sql=N'DENY SELECT ON [sys].[endpoints] TO '+QUOTENAME(@MasterUser)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
 SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';
 BEGIN TRY
  DECLARE @ProbeError int=NULL;
  BEGIN TRY DECLARE @Rows bigint=(SELECT COUNT_BIG(*) FROM [sys].[endpoints]);END TRY BEGIN CATCH SET @ProbeError=ERROR_NUMBER();END CATCH;
  IF COALESCE(@ProbeError,0)<>229 THROW 57334,N''Native endpoint SELECT denial not established.'',1;
  SET LOCK_TIMEOUT 53;SET XACT_ABORT ON;BEGIN TRANSACTION;
  EXEC @Ret=[monitor].[USP_EndpointTransportAnalysis] @ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@S OUTPUT,@ErrorNumberOut=@Err OUTPUT;
  IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 OR @@LOCK_TIMEOUT<>53 OR (@@OPTIONS&16384)<>16384 THROW 57335,N''Endpoint source fault damaged caller state.'',1;
  ROLLBACK TRANSACTION;REVERT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;REVERT;THROW;END CATCH;';
 EXEC [sys].[sp_executesql] @Sql,N'@Ret int OUTPUT,@J nvarchar(max) OUTPUT,@S varchar(40) OUTPUT,@Err int OUTPUT',@Ret=@Return OUTPUT,@J=@Json OUTPUT,@S=@Status OUTPUT,@Err=@Error OUTPUT;
 IF @Return<>0 OR @Status COLLATE SQL_Latin1_General_CP1_CS_AS<>'AVAILABLE_LIMITED' OR @Error<>229 OR NOT EXISTS(SELECT 1 FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.connectionEncryptionSummary') AS [g] WHERE TRY_CONVERT(int,JSON_VALUE([g].[value],N'$.EndpointId'))=@OwnConnectionEndpoint AND JSON_VALUE([g].[value],N'$.EndpointContextStatus') COLLATE SQL_Latin1_General_CP1_CS_AS=N'ENDPOINT_SOURCE_UNAVAILABLE' AND EXISTS(SELECT 1 FROM OPENJSON([g].[value]) AS [a] WHERE [a].[key] COLLATE SQL_Latin1_General_CP1_CS_AS=N'EndpointName' AND [a].[type]=0)) BEGIN
 SET @Message=LEFT(CONCAT(N'Endpoint partial native failure; return=',@Return,N'; status=',@Status COLLATE SQL_Latin1_General_CP1_CS_AS,N'; error=',@Error,N'; ownEndpoint=',@OwnConnectionEndpoint,N'; sources=',(SELECT [SourceKey],[StatusCode],[ErrorNumber],[ObservedRows] FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([SourceKey] varchar(64),[StatusCode] varchar(40),[ErrorNumber] int,[ObservedRows] bigint) FOR JSON PATH,INCLUDE_NULL_VALUES),N'; groups=',JSON_QUERY(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.connectionEncryptionSummary')),2048);
 THROW 57336,@Message,1;
 END;
 DELETE FROM [#ExampleTransport_Console];
 SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY INSERT [#ExampleTransport_Console] EXEC [monitor].[USP_EndpointTransportAnalysis] @ResultSetArt=''CONSOLE'',@MaxZeilen=1,@PrintMeldungen=0;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';EXEC [sys].[sp_executesql] @Sql;
 IF NOT EXISTS(SELECT 1 FROM [#ExampleTransport_Console] WHERE [Scope]='SOURCE' AND [StatusCode]='DENIED_PERMISSION' AND [Detail] LIKE N'ENDPOINTS%') OR NOT EXISTS(SELECT 1 FROM [#ExampleTransport_Console] WHERE [Scope]='CONNECTION_GROUP') THROW 57337,N'Endpoint console hides native partial source error.',1;
 SET @Sql=N'DENY SELECT ON [sys].[tcp_endpoints] TO '+QUOTENAME(@MasterUser)+N';DENY SELECT ON [sys].[database_mirroring_endpoints] TO '+QUOTENAME(@MasterUser)+N';DENY SELECT ON [sys].[dm_exec_connections] TO '+QUOTENAME(@MasterUser)+N';';EXEC [master].[sys].[sp_executesql] @Sql;
 SET @Sql=N'EXECUTE AS LOGIN='+QUOTENAME(@Login,'''')+N';BEGIN TRY EXEC @Ret=[monitor].[USP_EndpointTransportAnalysis] @ResultSetArt=''NONE'',@JsonErzeugen=1,@Json=@J OUTPUT,@PrintMeldungen=0,@StatusCodeOut=@S OUTPUT,@ErrorNumberOut=@Err OUTPUT;REVERT;END TRY BEGIN CATCH REVERT;THROW;END CATCH;';
 EXEC [sys].[sp_executesql] @Sql,N'@Ret int OUTPUT,@J nvarchar(max) OUTPUT,@S varchar(40) OUTPUT,@Err int OUTPUT',@Ret=@Return OUTPUT,@J=@Json OUTPUT,@S=@Status OUTPUT,@Err=@Error OUTPUT;
 IF @Return<>0 OR @Status COLLATE SQL_Latin1_General_CP1_CS_AS<>'DENIED_PERMISSION' OR @Error<>229 OR (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.sourceStatus') WITH([SourceKind] varchar(16),[StatusCode] varchar(40),[ErrorNumber] int,[ObservedRows] bigint,[ReturnedRows] bigint) WHERE [SourceKind]='NATIVE' AND [StatusCode]='DENIED_PERMISSION' AND [ErrorNumber]=229 AND [ObservedRows] IS NULL AND [ReturnedRows] IS NULL)<>4 OR (SELECT COUNT(*) FROM OPENJSON(@Json COLLATE SQL_Latin1_General_CP1_CS_AS,N'$.connectionEncryptionSummary'))<>0 THROW 57338,N'Endpoint all-native failure is masked by derived metadata.',1;
 SET @AllCases=1;
END TRY
BEGIN CATCH SELECT @Failure=ERROR_NUMBER(),@FailureMessage=ERROR_MESSAGE();IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;END CATCH;
SET XACT_ABORT OFF;
BEGIN TRY
 IF @MadeEndpoint=1
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM [sys].[endpoints] WHERE [endpoint_id]=@EndpointId AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Endpoint COLLATE SQL_Latin1_General_CP1_CS_AS AND [principal_id]=@EndpointOwner AND [type]=4) THROW 57340,N'Owned endpoint binding changed or missing; no unbound DROP.',1;
  SET @Sql=N'DROP ENDPOINT '+QUOTENAME(@Endpoint)+N';';EXEC [master].[sys].[sp_executesql] @Sql;SET @MadeEndpoint=0;
 END;
END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup COLLATE SQL_Latin1_General_CP1_CS_AS,N'; endpoint: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
BEGIN TRY
 IF @MadeCert=1
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM [master].[sys].[certificates] WHERE [certificate_id]=@CertId AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Certificate COLLATE SQL_Latin1_General_CP1_CS_AS AND [thumbprint]=@Thumbprint) THROW 57341,N'Owned certificate binding changed or missing; no unbound DROP.',1;
  SET @Sql=N'DROP CERTIFICATE '+QUOTENAME(@Certificate)+N';';EXEC [master].[sys].[sp_executesql] @Sql;SET @MadeCert=0;
 END;
END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup COLLATE SQL_Latin1_General_CP1_CS_AS,N'; certificate: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
BEGIN TRY
 IF @MadeFrameworkUser=1
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM [sys].[database_principals] WHERE [principal_id]=@FrameworkUserId AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@FrameworkUser COLLATE SQL_Latin1_General_CP1_CS_AS AND [sid]=@FrameworkUserSid) THROW 57342,N'Owned FrameworkUser binding changed or missing; no unbound DROP.',1;
  SET @Sql=N'DROP USER '+QUOTENAME(@FrameworkUser)+N';';EXEC [sys].[sp_executesql] @Sql;SET @MadeFrameworkUser=0;
 END;
END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup COLLATE SQL_Latin1_General_CP1_CS_AS,N'; FrameworkUser: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
BEGIN TRY
 IF @MadeMasterUser=1
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM [master].[sys].[database_principals] WHERE [principal_id]=@MasterUserId AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@MasterUser COLLATE SQL_Latin1_General_CP1_CS_AS AND [sid]=@MasterUserSid) THROW 57342,N'Owned MasterUser binding changed or missing; no unbound DROP.',1;
  SET @Sql=N'DROP USER '+QUOTENAME(@MasterUser)+N';';EXEC [master].[sys].[sp_executesql] @Sql;SET @MadeMasterUser=0;
 END;
END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup COLLATE SQL_Latin1_General_CP1_CS_AS,N'; MasterUser: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
BEGIN TRY
 IF @MadeLogin=1
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM [sys].[server_principals] WHERE [principal_id]=@LoginId AND [name] COLLATE SQL_Latin1_General_CP1_CS_AS=@Login COLLATE SQL_Latin1_General_CP1_CS_AS AND [sid]=@LoginSid) THROW 57342,N'Owned Login binding changed or missing; no unbound DROP.',1;
  SET @Sql=N'DROP LOGIN '+QUOTENAME(@Login)+N';';EXEC [master].[sys].[sp_executesql] @Sql;SET @MadeLogin=0;
 END;
END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup COLLATE SQL_Latin1_General_CP1_CS_AS,N'; Login: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
BEGIN TRY
 IF @OwnKey=1
 BEGIN
  IF NOT EXISTS(SELECT 1 FROM [master].[sys].[symmetric_keys] WHERE [symmetric_key_id]=@KeyId AND [key_guid]=@KeyGuid AND [create_date]=@KeyCreated AND [name]=N'##MS_DatabaseMasterKey##') THROW 57343,N'Owned DMK binding changed or missing; no unbound DROP.',1;
  IF @BeforeCertificates COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [certificate_id],[name],[thumbprint],[pvt_key_encryption_type],[start_date],[expiry_date] FROM [master].[sys].[certificates] ORDER BY [certificate_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
  OR @BeforeSymmetric COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [symmetric_key_id],[name],[key_guid],[create_date],[modify_date] FROM [master].[sys].[symmetric_keys] WHERE [symmetric_key_id]<>@KeyId ORDER BY [symmetric_key_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
  OR @BeforeAsymmetric COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [asymmetric_key_id],[name],[thumbprint],[pvt_key_encryption_type] FROM [master].[sys].[asymmetric_keys] ORDER BY [asymmetric_key_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
  OR @BeforeCredentials COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [credential_id],[name],[create_date],[modify_date] FROM [master].[sys].[database_scoped_credentials] ORDER BY [credential_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
  OR @BeforeKeyEncryptions COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [key_id],[thumbprint],[crypt_type] FROM [master].[sys].[key_encryptions] WHERE [key_id]<>@KeyId ORDER BY [key_id],[thumbprint],[crypt_type] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS THROW 57344,N'New or changed foreign master-key dependency; owned DMK retained for recovery.',1;
  EXEC [master].[sys].[sp_executesql] N'DROP MASTER KEY;';SET @OwnKey=0;
 END;
END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup COLLATE SQL_Latin1_General_CP1_CS_AS,N'; DMK: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
BEGIN TRY
 IF @BeforeEndpoints COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [endpoint_id],[name],[principal_id],[protocol],[protocol_desc],[type],[type_desc],[state],[state_desc],[is_admin_endpoint] FROM [sys].[endpoints] ORDER BY [endpoint_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
 OR @BeforeRights COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [class],[major_id],[minor_id],[grantee_principal_id],[grantor_principal_id],[type],[permission_name],[state] FROM [sys].[server_permissions] WHERE [class]=105 ORDER BY [major_id],[minor_id],[grantee_principal_id],[grantor_principal_id],[type] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
 OR @BeforeCertificates COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [certificate_id],[name],[thumbprint],[pvt_key_encryption_type],[start_date],[expiry_date] FROM [master].[sys].[certificates] ORDER BY [certificate_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
 OR @BeforeSymmetric COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [symmetric_key_id],[name],[key_guid],[create_date],[modify_date] FROM [master].[sys].[symmetric_keys] ORDER BY [symmetric_key_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
 OR @BeforeAsymmetric COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [asymmetric_key_id],[name],[thumbprint],[pvt_key_encryption_type] FROM [master].[sys].[asymmetric_keys] ORDER BY [asymmetric_key_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
 OR @BeforeCredentials COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [credential_id],[name],[create_date],[modify_date] FROM [master].[sys].[database_scoped_credentials] ORDER BY [credential_id] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
 OR @BeforeKeyEncryptions COLLATE SQL_Latin1_General_CP1_CS_AS<>(SELECT [key_id],[thumbprint],[crypt_type] FROM [master].[sys].[key_encryptions] ORDER BY [key_id],[thumbprint],[crypt_type] FOR JSON PATH,INCLUDE_NULL_VALUES) COLLATE SQL_Latin1_General_CP1_CS_AS
 OR @MadeEndpoint=1 OR @MadeCert=1 OR @MadeLogin=1 OR @MadeFrameworkUser=1 OR @MadeMasterUser=1 OR @OwnKey=1 THROW 57345,N'Endpoint fixture baseline or owned cleanup not restored.',1;
END TRY BEGIN CATCH SET @Cleanup=CONCAT(@Cleanup COLLATE SQL_Latin1_General_CP1_CS_AS,N'; baseline: ',ERROR_NUMBER(),N' ',ERROR_MESSAGE());END CATCH;
IF @Cleanup COLLATE SQL_Latin1_General_CP1_CS_AS<>N''
BEGIN
 DECLARE @Combined nvarchar(2048)=LEFT(CONCAT(N'Endpoint fixture cleanup failed; primary=',@Failure,N' ',@FailureMessage COLLATE SQL_Latin1_General_CP1_CS_AS,N'; cleanup=',@Cleanup COLLATE SQL_Latin1_General_CP1_CS_AS),2048);
 RAISERROR(N'%s',16,1,@Combined);RETURN 1;
END;
IF @Failure IS NOT NULL BEGIN RAISERROR(N'%s',16,1,@FailureMessage);RETURN 1;END;
IF @AllCases<>1 THROW 57346,N'Endpoint fixture cases incomplete.',1;
SET @NativeTableCases=@Case;RETURN 0;
END;
GO
DECLARE @ParentLock int=@@LOCK_TIMEOUT,@ParentAbort bit=CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END,@ParentTx int=@@TRANCOUNT,@ParentDb int=DB_ID(),@FixtureReturn int,@FixtureCases int;
BEGIN TRY
 EXEC @FixtureReturn=[#ExampleEndpointTransportRuntimeContract] @NativeTableCases=@FixtureCases OUTPUT;
 IF COALESCE(@FixtureReturn,-1)<>0 OR COALESCE(@FixtureCases,0)<>4 OR @@LOCK_TIMEOUT<>@ParentLock OR @@TRANCOUNT<>@ParentTx OR DB_ID()<>@ParentDb OR CASE WHEN (@@OPTIONS&16384)=16384 THEN 1 ELSE 0 END<>@ParentAbort THROW 57349,N'Endpoint scoped fixture did not restore parent.',1;
 DROP PROCEDURE [#ExampleEndpointTransportRuntimeContract];
 SELECT N'ENDPOINT_TRANSPORT_CONTRACT_PASS' AS [Result],@FixtureCases AS [NativeTableCases],CAST(1 AS bit) AS [PositiveMirroringCatalogRestrictedFaultsAndOwnedCleanup];
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>@ParentTx ROLLBACK TRANSACTION;
 IF OBJECT_ID(N'tempdb..#ExampleEndpointTransportRuntimeContract') IS NOT NULL DROP PROCEDURE [#ExampleEndpointTransportRuntimeContract];
 THROW;
END CATCH;
GO
