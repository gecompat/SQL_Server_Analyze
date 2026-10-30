USE [DeineDatenbank];
GO

/*
===============================================================================
Objekt       : monitor.TVF_ExecutionPlanStatisticsUsage
Version      : 1.0.0
Stand        : 2026-07-21
Typ          : Inline Table-valued Function
Zweck        : Extrahiert OptimizerStatsUsage je Statement aus Showplan-XML.
               Die Werte beschreiben den im Plan gespeicherten Compilezeitstand.
SQL-Version  : SQL Server 2019 oder neuer.
===============================================================================

Zweck und Eingabe
-----------------
Die Funktion liest StatisticsInfo-Elemente unter OptimizerStatsUsage aus
@PlanXml. @StatementId ist optional; NULL berücksichtigt alle gefundenen
StmtSimple-Elemente, ein Wert beschränkt die Ausgabe auf Elemente mit passender
StatementId. Die Zeit-, Änderungs- und Samplingwerte stammen aus dem im XML
gespeicherten Compilezeitstand. Die Funktion prüft weder die heutige
Statistikfrische noch, ob eine Statistik bei einer konkreten Ausführung
verwendet wurde.

Ausgabe
-------
StatisticsUsageOrdinal (bigint) nummeriert Zeilen anhand der Sortierschlüssel im
Funktionskörper. StatementOrdinal (int), StatementId (int) und
StatementCompId (int) ordnen jede Zeile dem ausgewählten Statement zu.
StatementOrdinal wird nach dem StatementId-Filter berechnet. Bei gleichen
Sortierschlüsseln ist die Nummerierung nicht stabil als Identität; die Abfrage
garantiert keine physische Ergebnisreihenfolge.

DatabaseName, SchemaName, ObjectName und StatisticsName sind nvarchar(256).
Erkannte eckige Klammern und verdoppelte schließende Klammern werden normalisiert.
LastUpdateAtCompile ist datetime2(7), ModificationCountAtCompile bigint und
SamplingPercentAtCompile decimal(19,6). Diese drei Werte werden mit
TRY_CONVERT aus den jeweiligen XML-Attributen gelesen; fehlt ein Attribut oder
ist es nicht konvertierbar, wird NULL ausgegeben. SourceElement ist
nvarchar(128) und bezeichnet OptimizerStatsUsage/StatisticsInfo.
ParseStatus ist varchar(40): AVAILABLE wird ausgegeben, wenn Objekt- und
Statistikname vorhanden sind; andernfalls INCOMPLETE_REFERENCE. Dieser Status
bewertet nur die gelesenen Namensattribute und ist kein Katalog- oder
Ausführungsnachweis.

Erkennung und Grenzen
---------------------
Die Statementsuche verwendet local-name() für StmtSimple und ist damit
namespace-unabhängig; dies ist keine vollständige Showplan-Validierung. Nur
StatisticsInfo-Elemente unter OptimizerStatsUsage werden berücksichtigt.
Fehlende oder leere Attribute werden NULL. Mehrere passende Stellen und
Duplikate bleiben getrennte Zeilen. Bei NULL- oder strukturell unpassendem XML
entstehen keine passenden Zeilen. Ungültiger Text kann nicht als xml-Parameter
übergeben werden; ein Konvertierungsfehler entsteht vor dem Funktionsaufruf.

Synthetisches Beispiel
----------------------
Das Fragment zeigt nur die gelesene Elementstruktur und ist kein vollständiger
Showplan:

DECLARE @PlanXml xml = N'<ShowPlanXML>
  <BatchSequence><Batch><Statements><StmtSimple StatementId="1"
    StatementCompId="1"><QueryPlan><OptimizerStatsUsage>
      <StatisticsInfo Database="[DemoDb]" Schema="[sales]"
        Table="[Orders]" Statistics="[IX_Orders]"
        LastUpdate="2026-01-01T00:00:00" ModificationCount="2"
        SamplingPercent="100"/>
    </OptimizerStatsUsage></QueryPlan></StmtSimple></Statements></Batch></BatchSequence>
</ShowPlanXML>';
SELECT *
FROM [monitor].[TVF_ExecutionPlanStatisticsUsage](@PlanXml, NULL);

===============================================================================
*/
CREATE OR ALTER FUNCTION [monitor].[TVF_ExecutionPlanStatisticsUsage]
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
    [Raw] AS
    (
        SELECT
              [st].[StatementOrdinal],[st].[StatementId],[st].[StatementCompId]
            , [DatabaseRaw]=NULLIF([i].[n].value('string((@Database)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [SchemaRaw]=NULLIF([i].[n].value('string((@Schema)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [ObjectRaw]=NULLIF([i].[n].value('string((@Table)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [StatisticsRaw]=NULLIF([i].[n].value('string((@Statistics)[1])','nvarchar(256)'),N'') COLLATE SQL_Latin1_General_CP1_CS_AS
            , [LastUpdateAtCompile]=TRY_CONVERT(datetime2(7),NULLIF([i].[n].value('string((@LastUpdate)[1])','nvarchar(100)'),N''))
            , [ModificationCountAtCompile]=TRY_CONVERT(bigint,NULLIF([i].[n].value('string((@ModificationCount)[1])','nvarchar(100)'),N''))
            , [SamplingPercentAtCompile]=TRY_CONVERT(decimal(19,6),NULLIF([i].[n].value('string((@SamplingPercent)[1])','nvarchar(100)'),N''))
        FROM [Statements] AS [st]
        CROSS APPLY [st].[StatementXml].nodes('.//*[local-name(.)="OptimizerStatsUsage"]/*[local-name(.)="StatisticsInfo"]') AS [i]([n])
    )
    SELECT
          [StatisticsUsageOrdinal]=CONVERT(bigint,ROW_NUMBER() OVER
            (ORDER BY [StatementOrdinal],COALESCE([DatabaseRaw],N''),COALESCE([SchemaRaw],N''),COALESCE([ObjectRaw],N''),COALESCE([StatisticsRaw],N'')))
        , [StatementOrdinal],[StatementId],[StatementCompId]
        , [DatabaseName]=CASE WHEN LEFT([DatabaseRaw],1)=N'[' AND RIGHT([DatabaseRaw],1)=N']'
                              THEN REPLACE(SUBSTRING([DatabaseRaw],2,LEN([DatabaseRaw])-2),N']]',N']') ELSE [DatabaseRaw] END
        , [SchemaName]=CASE WHEN LEFT([SchemaRaw],1)=N'[' AND RIGHT([SchemaRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([SchemaRaw],2,LEN([SchemaRaw])-2),N']]',N']') ELSE [SchemaRaw] END
        , [ObjectName]=CASE WHEN LEFT([ObjectRaw],1)=N'[' AND RIGHT([ObjectRaw],1)=N']'
                            THEN REPLACE(SUBSTRING([ObjectRaw],2,LEN([ObjectRaw])-2),N']]',N']') ELSE [ObjectRaw] END
        , [StatisticsName]=CASE WHEN LEFT([StatisticsRaw],1)=N'[' AND RIGHT([StatisticsRaw],1)=N']'
                                THEN REPLACE(SUBSTRING([StatisticsRaw],2,LEN([StatisticsRaw])-2),N']]',N']') ELSE [StatisticsRaw] END
        , [LastUpdateAtCompile],[ModificationCountAtCompile],[SamplingPercentAtCompile]
        , [SourceElement]=CONVERT(nvarchar(128),N'OptimizerStatsUsage/StatisticsInfo') COLLATE SQL_Latin1_General_CP1_CS_AS
        , [ParseStatus]=CONVERT(varchar(40),CASE
              WHEN [ObjectRaw] IS NOT NULL AND [StatisticsRaw] IS NOT NULL THEN 'AVAILABLE'
              ELSE 'INCOMPLETE_REFERENCE' END) COLLATE SQL_Latin1_General_CP1_CS_AS
    FROM [Raw]
);
GO
