USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ExecutionPlanColumnReferences
Version      : 1.0.2
Stand        : 2026-07-21
Typ          : Inline Table-valued Function
Zweck        : Normalisiert Spaltenrollen aus Showplan-XML für zielgerichtete
               Index- und Statistikauflösung. Keine Katalogzugriffe.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================

Zweck und Eingabe
-----------------
Die Funktion erkennt ColumnReference-Elemente in ausgewählten RelOp-Pfaden
unter @PlanXml und ordnet jeder Fundstelle eine Nutzungsrolle zu.
@StatementId ist optional; NULL berücksichtigt alle gefundenen StmtSimple-
Elemente, ein Wert beschränkt die Ausgabe auf Elemente mit passender
StatementId. Die Funktion führt den Plan nicht aus und löst Spaltennamen nicht
gegen Kataloge auf.

Ausgabe
-------
ColumnReferenceOrdinal (bigint) nummeriert die Zeilen nach den Sortierschlüsseln
im Funktionskörper. StatementOrdinal (int), StatementId (int),
StatementCompId (int) und NodeId (int) ordnen eine Zeile dem gefundenen
Statement und RelOp zu. StatementOrdinal wird nach dem StatementId-Filter
berechnet. Bei gleichen Sortierschlüsseln ist die Nummerierung nicht stabil als
Identität; die Abfrage garantiert keine physische Ergebnisreihenfolge.

ColumnUsage (varchar(40)) nimmt die Werte SEEK, RESIDUAL, JOIN, ORDER_BY,
GROUP_BY oder OUTPUT an. ExpressionContext (varchar(80)) beschreibt den
erkannten Pfad als SEEK_PREDICATE, PREDICATE, JOIN_KEY_OR_PREDICATE,
ORDER_REQUIREMENT, GROUP_REQUIREMENT oder OUTPUT_LIST. DatabaseName,
SchemaName, ObjectName, AliasName und ColumnName sind nvarchar(256);
erkannte eckige Klammern und verdoppelte schließende Klammern werden normalisiert.
IsSeekColumn, IsResidualPredicateColumn, IsJoinColumn, IsGroupByColumn,
IsOrderByColumn, IsOutputColumn und IsPartitionColumn sind bit. Die ersten
sechs Flags werden ausschließlich aus ColumnUsage abgeleitet.
IsPartitionColumn ist konstant 0 und belegt nicht, dass keine Partitionsspalten
vorhanden sind.

Erkennung und Grenzen
---------------------
Die Statementsuche verwendet local-name() für StmtSimple und die Operator-
beziehungsweise Spaltenpfade für ihre jeweiligen Elementnamen. Das macht die
Namenssuche namespace-unabhängig, ist aber keine vollständige Showplan-
Validierung. Ausgewertet werden SeekPredicates, Predicate, die aufgeführten
Join-Schlüsselelemente, OrderBy/SortKeys, GroupBy sowie direkte
OutputList/ColumnReference-Kinder. Andere XML-Pfade werden nicht erfasst.
Fehlende oder leere Namensattribute werden NULL; Zeilen ohne Column-Attribut
werden verworfen. Mehrfach vorkommende Spalten und Pfadüberschneidungen können
mehrere Zeilen erzeugen und werden nicht dedupliziert. Bei NULL- oder
strukturell unpassendem XML entstehen keine passenden Zeilen. Ungültiger Text
kann nicht als xml-Parameter übergeben werden; ein Konvertierungsfehler
entsteht vor dem Funktionsaufruf.

Synthetisches Beispiel
----------------------
Das Fragment zeigt einen vom Funktionskörper erkannten Pfad und ist kein
vollständiger Showplan:

DECLARE @PlanXml xml = N'<ShowPlanXML>
  <BatchSequence><Batch><Statements><StmtSimple StatementId="1"
    StatementCompId="1"><QueryPlan><RelOp NodeId="0"><IndexScan>
      <SeekPredicates><SeekPredicateNew><SeekKeys><Prefix>
        <ColumnReference Database="[DemoDb]" Schema="[sales]"
          Table="[Orders]" Column="[OrderId]"/>
      </Prefix></SeekKeys></SeekPredicateNew></SeekPredicates>
    </IndexScan></RelOp></QueryPlan></StmtSimple></Statements></Batch></BatchSequence>
</ShowPlanXML>';
SELECT *
FROM [monitor].[TVF_ExecutionPlanColumnReferences](@PlanXml, NULL);

===============================================================================
*/
-- USAGE_SKILL_BEGIN monitor.TVF_ExecutionPlanColumnReferences 1.0.0
-- ---
-- skill_format_version: "1.0.0"
-- name: "monitor.TVF_ExecutionPlanColumnReferences"
-- schema_name: "monitor"
-- object_name: "TVF_ExecutionPlanColumnReferences"
-- object_type: "FUNCTION"
-- database_role: "framework"
-- is_internal: false
-- description: "Normalisiert Spaltenrollen aus Showplan-XML für zielgerichtete Index- und Statistikauflösung."
-- source_path: "Code/04_PlanCache/048_TVF_ExecutionPlanColumnReferences.sql"
-- ---
-- 
-- # monitor.TVF_ExecutionPlanColumnReferences
-- 
-- ## Zweck und Einsatz
-- 
-- Normalisiert Spaltenrollen aus Showplan-XML für zielgerichtete Index- und Statistikauflösung. Keine Katalogzugriffe.
-- 
-- ## Voraussetzungen und Rechte
-- 
-- Der lesende Aufruf braucht SELECT auf [monitor].[TVF_ExecutionPlanColumnReferences]. Die Funktion verarbeitet nur ihre übergebenen Werte; sie liest selbst weder DMVs noch fremde Datenbanken oder Dateien.
-- 
-- ## Parameter und Eingabe
-- 
-- „SQL-Bindungspflicht“ bezeichnet ein bei der SQL-Aufrufbindung erforderliches Argument ohne Default. Fachliche Wertpflichten und zulässige NULL-Werte stehen im jeweiligen Einzelvertrag.
-- 
-- | Parameter | SQL-Typ | SQL-Bindungspflicht | Default |
-- | --- | --- | --- | --- |
-- | @PlanXml | xml | ja | kein Default |
-- | @StatementId | int | nein | NULL |
-- 
-- **@PlanXml:** Pflichtwert xml, kein Default. Bereits vorliegender Showplan; NULL/strukturell unpassend liefert keine ColumnReference-Zeilen. Die Funktion führt den Plan nicht aus und löst Namen nicht gegen Kataloge auf.
-- 
-- **@StatementId:** Optionaler int-Wert, Default NULL. NULL berücksichtigt alle gefundenen StmtSimple-Elemente; ein Wert filtert auf passende StatementId. Die Rollen beruhen nur auf den implementierten RelOp-Pfaden.
-- 
-- ## Resultate und Ausgabe
-- 
-- Null bis mehrere Spaltenbezüge aus dem Plan-XML, nur bei vorhandenem ColumnRaw. Spalten: `ColumnReferenceOrdinal bigint`, `StatementOrdinal int`, `StatementId int`, `StatementCompId int`, `NodeId int`, `ColumnUsage varchar(40)`, `ExpressionContext varchar(80)`, `DatabaseName nvarchar(256)`, `SchemaName nvarchar(256)`, `ObjectName nvarchar(256)`, `AliasName nvarchar(256)`, `ColumnName nvarchar(256)` und die Bits `IsSeekColumn`, `IsResidualPredicateColumn`, `IsJoinColumn`, `IsGroupByColumn`, `IsOrderByColumn`, `IsOutputColumn`, `IsPartitionColumn`. XML-Namen können unvollständig sein; diese Bezüge ersetzen keine aktuelle Katalogprüfung.
-- 
-- ## Beispiel
-- 
-- ```sql
-- DECLARE @PlanXml xml = N'<ShowPlanXML>
-- <BatchSequence><Batch><Statements><StmtSimple StatementId="1"
-- StatementCompId="1"><QueryPlan><RelOp NodeId="0"><IndexScan>
-- <SeekPredicates><SeekPredicateNew><SeekKeys><Prefix>
--   <ColumnReference Database="[DemoDb]" Schema="[sales]"
--     Table="[Orders]" Column="[OrderId]"/>
-- </Prefix></SeekKeys></SeekPredicateNew></SeekPredicates>
-- </IndexScan></RelOp></QueryPlan></StmtSimple></Statements></Batch></BatchSequence>
-- </ShowPlanXML>';
-- SELECT *
-- FROM [monitor].[TVF_ExecutionPlanColumnReferences](@PlanXml, NULL);
-- ```
-- 
-- ## Aufwand, Nebenwirkungen, Fehler und Grenzen
-- 
-- Der Funktionsaufruf wertet die im Quelltext beschriebenen Eingaben und Quellen aus; er legt keine persistenten Objekte an. NULL-, Längen- und Fehlergrenzen folgen den konkret dokumentierten Eingaberegeln oben.
-- USAGE_SKILL_END monitor.TVF_ExecutionPlanColumnReferences
CREATE OR ALTER FUNCTION [monitor].[TVF_ExecutionPlanColumnReferences]
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
            , [StatementId],[StatementCompId],[StatementXml]
        FROM [StatementsBase]
        WHERE @StatementId IS NULL OR [StatementId]=@StatementId
    ),
    [RelOps] AS
    (
        SELECT
              [st].[StatementOrdinal],[st].[StatementId],[st].[StatementCompId]
            , [NodeId]=TRY_CONVERT(int,NULLIF([r].[n].value('string((@NodeId)[1])','nvarchar(50)'),N''))
            , [RelOpXml]=[r].[n].query('.')
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="RelOp"]') AS [r]([n])
    ),
    [Roles] AS
    (
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               CONVERT(varchar(40),'SEEK') COLLATE SQL_Latin1_General_CP1_CS_AS [ColumnUsage],CONVERT(varchar(80),'SEEK_PREDICATE') COLLATE SQL_Latin1_General_CP1_CS_AS [ExpressionContext],
               [ColumnReferenceXml]=[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('/*[local-name(.)="RelOp"]/*/*[local-name(.)="SeekPredicates"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'RESIDUAL','PREDICATE',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('/*[local-name(.)="RelOp"]/*/*[local-name(.)="Predicate"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'JOIN','JOIN_KEY_OR_PREDICATE',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('/*[local-name(.)="RelOp"]/*/*[local-name(.)="HashKeysBuild" or local-name(.)="HashKeysProbe" or local-name(.)="InnerSideJoinColumns" or local-name(.)="OuterSideJoinColumns" or local-name(.)="OuterReferences"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'ORDER_BY','ORDER_REQUIREMENT',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('/*[local-name(.)="RelOp"]/*/*[local-name(.)="OrderBy" or local-name(.)="SortKeys"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'GROUP_BY','GROUP_REQUIREMENT',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('/*[local-name(.)="RelOp"]/*/*[local-name(.)="GroupBy"]//*[local-name(.)="ColumnReference"]') AS [c]([n])

        UNION ALL
        SELECT [StatementOrdinal],[StatementId],[StatementCompId],[NodeId],
               'OUTPUT','OUTPUT_LIST',[c].[n].query('.')
        FROM [RelOps]
        CROSS APPLY [RelOpXml].nodes('/*[local-name(.)="RelOp"]/*[local-name(.)="OutputList"]/*[local-name(.)="ColumnReference"]') AS [c]([n])
    ),
    [Raw] AS
    (
        SELECT
              [StatementOrdinal],[StatementId],[StatementCompId],[NodeId]
            , [ColumnUsage],[ExpressionContext]
            , [DatabaseRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Database)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [SchemaRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Schema)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [ObjectRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Table)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [AliasRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Alias)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [ColumnRaw]=NULLIF([ColumnReferenceXml].value('string((/*/@Column)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
        FROM [Roles]
    )
    SELECT
          [ColumnReferenceOrdinal]=CONVERT(bigint,ROW_NUMBER() OVER
            (ORDER BY [StatementOrdinal],COALESCE([NodeId],2147483647),[ColumnUsage],COALESCE([ObjectRaw],N''),COALESCE([ColumnRaw],N'')))
        , [StatementOrdinal],[StatementId],[StatementCompId],[NodeId]
        , [ColumnUsage],[ExpressionContext]
        , [DatabaseName]=CASE WHEN LEFT([DatabaseRaw],1)=N'[' AND RIGHT([DatabaseRaw],1)=N']'
                              THEN REPLACE(SUBSTRING([DatabaseRaw],2,LEN([DatabaseRaw])-2),N']]',N']') ELSE [DatabaseRaw] END
        , [SchemaName]=CASE WHEN LEFT([SchemaRaw],1)=N'[' AND RIGHT([SchemaRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([SchemaRaw],2,LEN([SchemaRaw])-2),N']]',N']') ELSE [SchemaRaw] END
        , [ObjectName]=CASE WHEN LEFT([ObjectRaw],1)=N'[' AND RIGHT([ObjectRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([ObjectRaw],2,LEN([ObjectRaw])-2),N']]',N']') ELSE [ObjectRaw] END
        , [AliasName]=CASE WHEN LEFT([AliasRaw],1)=N'[' AND RIGHT([AliasRaw],1)=N']'
                           THEN REPLACE(SUBSTRING([AliasRaw],2,LEN([AliasRaw])-2),N']]',N']') ELSE [AliasRaw] END
        , [ColumnName]=CASE WHEN LEFT([ColumnRaw],1)=N'[' AND RIGHT([ColumnRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([ColumnRaw],2,LEN([ColumnRaw])-2),N']]',N']') ELSE [ColumnRaw] END
        , [IsSeekColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='SEEK' THEN 1 ELSE 0 END)
        , [IsResidualPredicateColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='RESIDUAL' THEN 1 ELSE 0 END)
        , [IsJoinColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='JOIN' THEN 1 ELSE 0 END)
        , [IsGroupByColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='GROUP_BY' THEN 1 ELSE 0 END)
        , [IsOrderByColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='ORDER_BY' THEN 1 ELSE 0 END)
        , [IsOutputColumn]=CONVERT(bit,CASE WHEN [ColumnUsage]='OUTPUT' THEN 1 ELSE 0 END)
        , [IsPartitionColumn]=CONVERT(bit,0)
    FROM [Raw]
    WHERE [ColumnRaw] IS NOT NULL
);
GO
