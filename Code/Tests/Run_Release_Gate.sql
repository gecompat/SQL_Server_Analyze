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

PRINT N'RELEASE_GATE 1/12: Smoke Test';
:r Integration/110_Smoke_Test.sql

PRINT N'RELEASE_GATE 2/12: Parameter-API-Vertrag';
:r Integration/163_Parameter_API_Vertrag.sql

PRINT N'RELEASE_GATE 3/12: Filter- und Ausgabe-Vertrag';
:r Integration/165_Filter_Output_Contract.sql

PRINT N'RELEASE_GATE 4/12: Spezialfall-API-Vertrag';
:r Integration/167_Special_Case_API_Contract.sql

PRINT N'RELEASE_GATE 5/12: Common';
:r Common/090_Test_und_Abnahme_Phase1A.sql

PRINT N'RELEASE_GATE 6/12: Current State';
:r CurrentState/110_Test_und_Abnahme_Phase1B.sql

PRINT N'RELEASE_GATE 7/12: Object und Index';
:r ObjectIndex/110_Test_und_Abnahme_Phase2.sql

PRINT N'RELEASE_GATE 8/12: Plan Cache';
:r PlanCache/110_Test_und_Abnahme_Phase3.sql

PRINT N'RELEASE_GATE 9/12: Query Store';
:r QueryStore/110_Test_und_Abnahme_Phase4.sql

PRINT N'RELEASE_GATE 10/12: Extended Events';
:r ExtendedEvents/110_Test_und_Abnahme_Phase5.sql

PRINT N'RELEASE_GATE 11/12: Infrastructure';
:r Infrastructure/110_Test_und_Abnahme_Phase6.sql

PRINT N'RELEASE_GATE 12/12: Server Health';
:r ServerHealth/110_Test_und_Abnahme_Phase7.sql

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       CAST(12 AS int) AS [ExecutedSuites],
       N'Alle Integrationsverträge und Bereichs-Smoke-Tests wurden ohne SQL-Fehler beendet.' AS [Detail];
GO
