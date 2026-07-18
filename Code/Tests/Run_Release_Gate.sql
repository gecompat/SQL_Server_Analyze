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

RAISERROR(N'RELEASE_GATE 1/13: Smoke Test',10,1) WITH NOWAIT;
:r Integration/110_Smoke_Test.sql

RAISERROR(N'RELEASE_GATE 2/13: Parameter-API-Vertrag',10,1) WITH NOWAIT;
:r Integration/163_Parameter_API_Vertrag.sql

RAISERROR(N'RELEASE_GATE 3/13: Filter- und Ausgabe-Vertrag',10,1) WITH NOWAIT;
:r Integration/165_Filter_Output_Contract.sql

RAISERROR(N'RELEASE_GATE 4/13: Spezialfall-API-Vertrag',10,1) WITH NOWAIT;
:r Integration/167_Special_Case_API_Contract.sql

RAISERROR(N'RELEASE_GATE 5/13: Spezialfall-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/168_Special_Case_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 6/13: Common',10,1) WITH NOWAIT;
:r Common/090_Test_und_Abnahme_Phase1A.sql

RAISERROR(N'RELEASE_GATE 7/13: Current State',10,1) WITH NOWAIT;
:r CurrentState/110_Test_und_Abnahme_Phase1B.sql

RAISERROR(N'RELEASE_GATE 8/13: Object und Index',10,1) WITH NOWAIT;
:r ObjectIndex/110_Test_und_Abnahme_Phase2.sql

RAISERROR(N'RELEASE_GATE 9/13: Plan Cache',10,1) WITH NOWAIT;
:r PlanCache/110_Test_und_Abnahme_Phase3.sql

RAISERROR(N'RELEASE_GATE 10/13: Query Store',10,1) WITH NOWAIT;
:r QueryStore/110_Test_und_Abnahme_Phase4.sql

RAISERROR(N'RELEASE_GATE 11/13: Extended Events',10,1) WITH NOWAIT;
:r ExtendedEvents/110_Test_und_Abnahme_Phase5.sql

RAISERROR(N'RELEASE_GATE 12/13: Infrastructure',10,1) WITH NOWAIT;
:r Infrastructure/110_Test_und_Abnahme_Phase6.sql

RAISERROR(N'RELEASE_GATE 13/13: Server Health',10,1) WITH NOWAIT;
:r ServerHealth/110_Test_und_Abnahme_Phase7.sql

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       CAST(13 AS int) AS [ExecutedSuites],
       N'Alle Integrationsverträge und Bereichs-Smoke-Tests wurden ohne SQL-Fehler beendet.' AS [Detail];
GO
