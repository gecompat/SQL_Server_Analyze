# EXECUTION-PLAN-001

Das Beispiel verwendet `LAB-EXECPLAN-001`. Das Setup erzeugt einen synthetischen gecachten Plan, der Observer liest genau dieses Showplan-XML und übergibt es mit abgeleiteten Datenschutzmodi an `[monitor].[USP_ExecutionPlanAnalysis]`.

Im Interactive-Modus führen Sie das Analyseskript nach dem Setup aus und lesen Planquelle, Statements, Operatoren und Findings gemeinsam. Planhandle, Node-Reihenfolge und Kostenwerte sind keine dauerhaft stabilen Assertions. Das Beispiel liest keinen realen SQL-Text in ein Repositoryartefakt.
