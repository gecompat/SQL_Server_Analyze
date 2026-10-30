USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ExecutionPlanObjectReferences
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Inline Table-valued Function
Zweck        : Extrahiert statement- und operatorbezogene Objekt-/Indexreferenzen
               ausschließlich aus übergebenem Showplan-XML. Keine Katalogzugriffe.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================

Zweck und Eingabe
-----------------
Die Funktion liest Objekt- und Indexreferenzen aus dem übergebenen XML-Wert
@PlanXml. @StatementId ist optional; NULL berücksichtigt alle gefundenen
StmtSimple-Elemente, ein Wert beschränkt die Ausgabe auf Elemente mit passender
StatementId. Die Funktion führt den Plan nicht aus, erfasst keinen Plan und
löst Referenzen nicht gegen Kataloge auf.

Ausgabe
-------
ReferenceOrdinal (bigint) nummeriert die ausgegebenen Zeilen anhand der
Sortierschlüssel im Funktionskörper. StatementOrdinal (int), StatementId (int)
und StatementCompId (int) ordnen die Zeile dem ausgewählten Statement zu;
NodeId (int) stammt aus RelOp. StatementOrdinal wird nach dem StatementId-
Filter berechnet. Bei gleichen Sortierschlüsseln ist die Nummerierung nicht
stabil als Identität; auch die Abfrage garantiert keine physische Reihenfolge.

ReferenceType und ReferenceSource sind varchar(40). ReferenceType kennzeichnet
INDEX, wenn ein Indexname vorhanden ist, andernfalls TABLE; Namen mit Präfix
# beziehungsweise @ ergeben TEMPORARY_OBJECT beziehungsweise TABLE_VARIABLE.
ReferenceSource ist ACCESS_PATH für den aus RelOp abgeleiteten Operatorpfad und
DML_TARGET für die im Funktionskörper erkannten Schreiboperatoren. Diese Flags
beschreiben ausschließlich die XML-Auswertung und beweisen weder Objektart
noch tatsächliche Ausführung.

DatabaseName, SchemaName, ObjectName, IndexName, AliasName und StorageType
sind nvarchar(256). Eckige Klammern um erkannte Namensbestandteile werden
entfernt und verdoppelte schließende Klammern zurückgeführt. PlanObjectId und
PlanIndexId sind int; PlanObjectId wird aus dem Object-Element gelesen,
PlanIndexId bleibt NULL. IsTemporaryObject, IsTableVariable, IsRemoteObject und
IsDmlTarget sind bit. IsRemoteObject ist in dieser Funktion konstant 0;
IsPartitionColumn oder weitere Katalogeigenschaften werden nicht ermittelt.
ResolutionCapability und SourceElement sind varchar(40) beziehungsweise
nvarchar(128). ResolutionCapability meldet ausschließlich die im Funktionskörper
abgeleitete Einstufung: TEMP_OBJECT_CONTEXT_REQUIRED, PLAN_ONLY,
INCOMPLETE_REFERENCE oder CATALOG_RESOLVABLE. CATALOG_RESOLVABLE bestätigt
keine Existenz, Auflösbarkeit oder Gesundheit eines Katalogobjekts. SourceElement
kennzeichnet Object oder MissingIndex.

Erkennung und Grenzen
---------------------
Die Statementsuche verwendet local-name() für StmtSimple und ist damit
namespace-unabhängig; dies ist keine vollständige Showplan-Validierung. Pro
Statement werden RelOp/Object-Referenzen und MissingIndex-Elemente separat
ausgelesen. Fehlende Attribute werden durch NULLIF als NULL ausgegeben.
TRY_CONVERT liefert bei nicht konvertierbaren numerischen Attributen NULL.
Referenzen ohne ObjectName werden verworfen. Mehrere passende XML-Stellen
bleiben mehrere Zeilen; eine eindeutige Referenz oder ein physischer
Ausführungsnachweis wird nicht zugesichert. Bei NULL- oder strukturell
unpassendem XML entstehen keine passenden Zeilen. Ungültiger Text kann nicht
als xml-Parameter übergeben werden; ein Konvertierungsfehler entsteht vor dem
Funktionsaufruf.

Synthetisches Beispiel
----------------------
Das Fragment zeigt nur die von dieser Funktion gelesenen Pfade und ist kein
vollständiger Showplan:

DECLARE @PlanXml xml = N'<ShowPlanXML>
  <BatchSequence><Batch><Statements><StmtSimple StatementId="1"
    StatementCompId="1"><QueryPlan><RelOp NodeId="0" PhysicalOp="Index Seek">
      <IndexScan><Object Database="[DemoDb]" Schema="[sales]"
        Table="[Orders]" Index="[IX_Orders]" Alias="[o]"
        Storage="RowStore" ObjectId="12"/></IndexScan>
    </RelOp></QueryPlan></StmtSimple></Statements></Batch></BatchSequence>
</ShowPlanXML>';
SELECT *
FROM [monitor].[TVF_ExecutionPlanObjectReferences](@PlanXml, NULL);

===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ExecutionPlanObjectReferences]
(
      @PlanXml     xml
    , @StatementId int = NULL
)
RETURNS TABLE
AS
RETURN
(
    WITH [StatementsBase] AS
    (
        SELECT
              [StatementXml]=[s].[n].query('.')
            , [StatementId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementId)[1])','nvarchar(50)'),N''))
            , [StatementCompId]=TRY_CONVERT(int,NULLIF([s].[n].value('string((@StatementCompId)[1])','nvarchar(50)'),N''))
            , [StatementText]=NULLIF([s].[n].value('string((@StatementText)[1])','nvarchar(4000)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM @PlanXml.nodes('//*[local-name(.)="StmtSimple"]') AS [s]([n])
    ),
    [Statements] AS
    (
        SELECT
              [StatementOrdinal]=CONVERT(int,ROW_NUMBER() OVER
                (ORDER BY COALESCE([StatementId],2147483647),COALESCE([StatementCompId],2147483647),COALESCE([StatementText],N'')))
            , [StatementId]
            , [StatementCompId]
            , [StatementXml]
        FROM [StatementsBase]
        WHERE @StatementId IS NULL OR [StatementId]=@StatementId
    ),
    [AccessObjectsRaw] AS
    (
        SELECT
              [st].[StatementOrdinal]
            , [st].[StatementId]
            , [st].[StatementCompId]
            , [NodeId]=TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , [PhysicalOp]=NULLIF([r].[n].value('string((@PhysicalOp)[1])','nvarchar(128)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [DatabaseRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Database)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [SchemaRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Schema)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [ObjectRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Table)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [IndexRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Index)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [AliasRaw]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Alias)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [StorageType]=NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@Storage)[1])','nvarchar(128)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [PlanObjectId]=TRY_CONVERT(int,NULLIF([r].[n].value('string((./*/*[local-name(.)="Object"]/@ObjectId)[1])','nvarchar(50)'),N''))
            , [PlanIndexId]=CONVERT(int,NULL)
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n])
        WHERE [r].[n].exist('./*/*[local-name(.)="Object"]')=1
    ),
    [AccessObjects] AS
    (
        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],[PhysicalOp]
            , [DatabaseName]=CASE WHEN LEFT([DatabaseRaw],1)=N'[' AND RIGHT([DatabaseRaw],1)=N']'
                                  THEN REPLACE(SUBSTRING([DatabaseRaw],2,LEN([DatabaseRaw])-2),N']]',N']') ELSE [DatabaseRaw] END
            , [SchemaName]=CASE WHEN LEFT([SchemaRaw],1)=N'[' AND RIGHT([SchemaRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([SchemaRaw],2,LEN([SchemaRaw])-2),N']]',N']') ELSE [SchemaRaw] END
            , [ObjectName]=CASE WHEN LEFT([ObjectRaw],1)=N'[' AND RIGHT([ObjectRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([ObjectRaw],2,LEN([ObjectRaw])-2),N']]',N']') ELSE [ObjectRaw] END
            , [IndexName]=CASE WHEN LEFT([IndexRaw],1)=N'[' AND RIGHT([IndexRaw],1)=N']'
                               THEN REPLACE(SUBSTRING([IndexRaw],2,LEN([IndexRaw])-2),N']]',N']') ELSE [IndexRaw] END
            , [AliasName]=CASE WHEN LEFT([AliasRaw],1)=N'[' AND RIGHT([AliasRaw],1)=N']'
                               THEN REPLACE(SUBSTRING([AliasRaw],2,LEN([AliasRaw])-2),N']]',N']') ELSE [AliasRaw] END
            , [StorageType],[PlanObjectId],[PlanIndexId]
        FROM [AccessObjectsRaw]
    ),
    [MissingObjectsRaw] AS
    (
        SELECT
              [st].[StatementOrdinal]
            , [st].[StatementId]
            , [st].[StatementCompId]
            , [DatabaseRaw]=NULLIF([m].[n].value('string((@Database)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [SchemaRaw]=NULLIF([m].[n].value('string((@Schema)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [ObjectRaw]=NULLIF([m].[n].value('string((@Table)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="MissingIndex"]') AS [m]([n])
    ),
    [MissingObjects] AS
    (
        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId]
            , [DatabaseName]=CASE WHEN LEFT([DatabaseRaw],1)=N'[' AND RIGHT([DatabaseRaw],1)=N']'
                                  THEN REPLACE(SUBSTRING([DatabaseRaw],2,LEN([DatabaseRaw])-2),N']]',N']') ELSE [DatabaseRaw] END
            , [SchemaName]=CASE WHEN LEFT([SchemaRaw],1)=N'[' AND RIGHT([SchemaRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([SchemaRaw],2,LEN([SchemaRaw])-2),N']]',N']') ELSE [SchemaRaw] END
            , [ObjectName]=CASE WHEN LEFT([ObjectRaw],1)=N'[' AND RIGHT([ObjectRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([ObjectRaw],2,LEN([ObjectRaw])-2),N']]',N']') ELSE [ObjectRaw] END
        FROM [MissingObjectsRaw]
    ),
    [AllReferences] AS
    (
        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId],[NodeId]
            , [ReferenceType]=CONVERT(varchar(40),CASE
                  WHEN [ObjectName] LIKE N'#%' THEN 'TEMPORARY_OBJECT'
                  WHEN [ObjectName] LIKE N'@%' THEN 'TABLE_VARIABLE'
                  WHEN [IndexName] IS NOT NULL THEN 'INDEX'
                  ELSE 'TABLE' END) COLLATE SQL_Latin1_General_CP1_CS_AS
            , [ReferenceSource]=CONVERT(varchar(40),CASE
                  WHEN [PhysicalOp] LIKE N'%Update%' OR [PhysicalOp] LIKE N'%Insert%'
                    OR [PhysicalOp] LIKE N'%Delete%' OR [PhysicalOp]=N'Merge'
                    THEN 'DML_TARGET' ELSE 'ACCESS_PATH' END) COLLATE SQL_Latin1_General_CP1_CS_AS
            , [DatabaseName],[SchemaName],[ObjectName],[IndexName],[AliasName],[StorageType]
            , [PlanObjectId],[PlanIndexId]
            , [IsTemporaryObject]=CONVERT(bit,CASE WHEN [ObjectName] LIKE N'#%' OR [DatabaseName]=N'tempdb' THEN 1 ELSE 0 END)
            , [IsTableVariable]=CONVERT(bit,CASE WHEN [ObjectName] LIKE N'@%' THEN 1 ELSE 0 END)
            , [IsRemoteObject]=CONVERT(bit,0)
            , [IsDmlTarget]=CONVERT(bit,CASE
                  WHEN [PhysicalOp] LIKE N'%Update%' OR [PhysicalOp] LIKE N'%Insert%'
                    OR [PhysicalOp] LIKE N'%Delete%' OR [PhysicalOp]=N'Merge'
                    THEN 1 ELSE 0 END)
            , [ResolutionCapability]=CONVERT(varchar(40),CASE
                  WHEN [ObjectName] LIKE N'#%' THEN 'TEMP_OBJECT_CONTEXT_REQUIRED'
                  WHEN [ObjectName] LIKE N'@%' THEN 'PLAN_ONLY'
                  WHEN [DatabaseName] IS NULL OR [SchemaName] IS NULL OR [ObjectName] IS NULL THEN 'INCOMPLETE_REFERENCE'
                  ELSE 'CATALOG_RESOLVABLE' END) COLLATE SQL_Latin1_General_CP1_CS_AS
            , [SourceElement]=CONVERT(nvarchar(128),N'Object') COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM [AccessObjects]
        WHERE [ObjectName] IS NOT NULL

        UNION ALL

        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId],NULL
            , 'TABLE','MISSING_INDEX',[DatabaseName],[SchemaName],[ObjectName]
            , NULL,NULL,NULL,NULL,NULL,0,0,0,0
            , CASE WHEN [DatabaseName] IS NULL OR [SchemaName] IS NULL OR [ObjectName] IS NULL
                   THEN 'INCOMPLETE_REFERENCE' ELSE 'CATALOG_RESOLVABLE' END
            , N'MissingIndex'
        FROM [MissingObjects]
        WHERE [ObjectName] IS NOT NULL
    )
    SELECT
          [ReferenceOrdinal]=CONVERT(bigint,ROW_NUMBER() OVER
            (ORDER BY [StatementOrdinal],COALESCE([NodeId],2147483647),[ReferenceSource],COALESCE([DatabaseName],N''),COALESCE([SchemaName],N''),COALESCE([ObjectName],N''),COALESCE([IndexName],N'')))
        , [StatementOrdinal],[StatementId],[StatementCompId],[NodeId]
        , [ReferenceType],[ReferenceSource],[DatabaseName],[SchemaName],[ObjectName]
        , [IndexName],[AliasName],[StorageType],[PlanObjectId],[PlanIndexId]
        , [IsTemporaryObject],[IsTableVariable],[IsRemoteObject],[IsDmlTarget]
        , [ResolutionCapability],[SourceElement]
    FROM [AllReferences]
);
GO
