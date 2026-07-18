:ON ERROR EXIT

/*
===============================================================================
Datei        : Run_Release_Gate.sql
Zweck        : Führt die verbindlichen Integrationsverträge eines installierten
               Frameworkstands in fester Reihenfolge aus.
Ausführung   : Im SQLCMD-Modus aus dem Verzeichnis Code/Tests starten.
Voraussetzung: Den generischen Platzhalter [DeineDatenbank] vor der Ausführung
               repositoryweit durch die vorgesehene Installationsdatenbank
               ersetzen. Install_All.sql muss erfolgreich ausgeführt sein.
Nebenwirkung : Die eingebundenen Tests sind lesend und erzeugen ausschließlich
               temporäre Objekte. Bei erstem SQL-Fehler endet der Runner.
Datenschutz  : Laufzeitausgaben werden nicht in Dateien geschrieben. Eine
               Übernahme in Repositoryartefakte ist separat zu prüfen.
===============================================================================
*/

RAISERROR(N'RELEASE_GATE 1/14: Smoke Test',10,1) WITH NOWAIT;
:r Integration/110_Smoke_Test.sql

RAISERROR(N'RELEASE_GATE 2/14: Parameter-API-Vertrag',10,1) WITH NOWAIT;
:r Integration/163_Parameter_API_Vertrag.sql

RAISERROR(N'RELEASE_GATE 3/14: Filter- und Ausgabe-Vertrag',10,1) WITH NOWAIT;
:r Integration/165_Filter_Output_Contract.sql

RAISERROR(N'RELEASE_GATE 4/14: Spezialfall-API-Vertrag',10,1) WITH NOWAIT;
:r Integration/167_Special_Case_API_Contract.sql

RAISERROR(N'RELEASE_GATE 5/14: Spezialfall-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/168_Special_Case_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 6/14: P0-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/169_P0_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 7/14: Common',10,1) WITH NOWAIT;
:r Common/090_Test_und_Abnahme_Phase1A.sql

RAISERROR(N'RELEASE_GATE 8/14: Current State',10,1) WITH NOWAIT;
:r CurrentState/110_Test_und_Abnahme_Phase1B.sql

RAISERROR(N'RELEASE_GATE 9/14: Object und Index',10,1) WITH NOWAIT;
:r ObjectIndex/110_Test_und_Abnahme_Phase2.sql

RAISERROR(N'RELEASE_GATE 10/14: Plan Cache',10,1) WITH NOWAIT;
:r PlanCache/110_Test_und_Abnahme_Phase3.sql

RAISERROR(N'RELEASE_GATE 11/14: Query Store',10,1) WITH NOWAIT;
:r QueryStore/110_Test_und_Abnahme_Phase4.sql

RAISERROR(N'RELEASE_GATE 12/14: Extended Events',10,1) WITH NOWAIT;
:r ExtendedEvents/110_Test_und_Abnahme_Phase5.sql

RAISERROR(N'RELEASE_GATE 13/14: Infrastructure',10,1) WITH NOWAIT;
:r Infrastructure/110_Test_und_Abnahme_Phase6.sql

RAISERROR(N'RELEASE_GATE 14/14: Server Health',10,1) WITH NOWAIT;
:r ServerHealth/110_Test_und_Abnahme_Phase7.sql

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       CAST(14 AS int) AS [ExecutedSuites],
       N'Alle Integrationsverträge und Bereichs-Smoke-Tests wurden ohne SQL-Fehler beendet.' AS [Detail];
GO
