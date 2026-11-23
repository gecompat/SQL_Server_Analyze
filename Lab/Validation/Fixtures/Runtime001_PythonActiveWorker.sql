SET NOCOUNT ON;

INSERT [dbo].[ExampleActiveRuntimeSignal]([Id],[SessionId],[Finished]) VALUES(1,@@SPID,0);
EXEC sys.sp_execute_external_script
    @language=N'Python',
    @script=N'import time
assert int(InputDataSet.iloc[0, 0]) == 42
time.sleep(30)
OutputDataSet = InputDataSet',
    @input_data_1=N'SELECT CAST(42 AS int) AS ProbeValue'
    WITH RESULT SETS ((ProbeValue int NOT NULL));

UPDATE [dbo].[ExampleActiveRuntimeSignal] SET [Finished]=1 WHERE [Id]=1 AND [SessionId]=@@SPID;
IF @@ROWCOUNT<>1 THROW 56984,N'The owned Python worker signal did not finish.',1;
GO
