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
Nebenwirkung : Die eingebundenen Tests verwenden ausschließlich synthetische,
               rücksetzbare Fixtures und temporäre Objekte. Bei erstem
               SQL-Fehler endet der Runner.
Datenschutz  : Laufzeitausgaben werden nicht in Dateien geschrieben. Eine
               Übernahme in Repositoryartefakte ist separat zu prüfen.
Evidenz      : Versionsworkflows veröffentlichen commitbezogene Statuskontexte.
P1           : Suiten 170 bis 178 prüfen alle 40 P1-Fälle.
P2           : Suiten 179 bis 186 prüfen Feature Inventory, In-Memory OLTP,
               Temporal, Service Broker, Full-Text, Data Capture, Encryption
               und Maintenance capability-adaptiv und ohne reale Nutzdaten.
TABLE        : Suite 187 prüft Strukturadaption und typisierten Temp-Table-Output.
===============================================================================
*/

RAISERROR(N'RELEASE_GATE 1/32: Smoke Test',10,1) WITH NOWAIT;
:r Integration/110_Smoke_Test.sql

RAISERROR(N'RELEASE_GATE 2/32: Parameter-API-Vertrag',10,1) WITH NOWAIT;
:r Integration/163_Parameter_API_Vertrag.sql

RAISERROR(N'RELEASE_GATE 3/32: Filter- und Ausgabe-Vertrag',10,1) WITH NOWAIT;
:r Integration/165_Filter_Output_Contract.sql

RAISERROR(N'RELEASE_GATE 4/32: Spezialfall-API-Vertrag',10,1) WITH NOWAIT;
:r Integration/167_Special_Case_API_Contract.sql

RAISERROR(N'RELEASE_GATE 5/32: Spezialfall-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/168_Special_Case_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 6/32: P0-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/169_P0_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 7/32: P1-IQP-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/170_P1_IQP_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 8/32: P1-Contention-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/171_P1_Contention_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 9/32: P1-Speicher-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/172_P1_Memory_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 10/32: P1-Backupketten-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/173_P1_Backup_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 11/32: P1-Schema-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/174_P1_Schema_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 12/32: P1-Statistikverteilungs-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/175_P1_Statistics_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 13/32: P1-Availability-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/176_P1_Availability_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 14/32: P1-Agent-/Alert-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/177_P1_Agent_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 15/32: P1-Findings-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/178_P1_Diagnostic_Findings_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 16/32: P2-Spezialfeature-Inventur',10,1) WITH NOWAIT;
:r Integration/179_P2_Special_Feature_Inventory_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 17/32: P2-In-Memory-OLTP-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/180_P2_InMemory_Oltp_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 18/32: P2-Temporal-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/181_P2_Temporal_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 19/32: P2-Service-Broker-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/182_P2_Service_Broker_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 20/32: P2-Full-Text-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/183_P2_FullText_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 21/32: P2-Data-Capture-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/184_P2_Data_Capture_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 22/32: P2-Encryption-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/185_P2_Encryption_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 23/32: P2-Maintenance-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/186_P2_Maintenance_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 24/32: TABLE-Ausgabevertrag',10,1) WITH NOWAIT;
:r Integration/187_Table_Output_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 25/32: Common',10,1) WITH NOWAIT;
:r Common/090_Test_und_Abnahme_Phase1A.sql

RAISERROR(N'RELEASE_GATE 26/32: Current State',10,1) WITH NOWAIT;
:r CurrentState/110_Test_und_Abnahme_Phase1B.sql

RAISERROR(N'RELEASE_GATE 27/32: Object und Index',10,1) WITH NOWAIT;
:r ObjectIndex/110_Test_und_Abnahme_Phase2.sql

RAISERROR(N'RELEASE_GATE 28/32: Plan Cache',10,1) WITH NOWAIT;
:r PlanCache/110_Test_und_Abnahme_Phase3.sql

RAISERROR(N'RELEASE_GATE 29/32: Query Store',10,1) WITH NOWAIT;
:r QueryStore/110_Test_und_Abnahme_Phase4.sql

RAISERROR(N'RELEASE_GATE 30/32: Extended Events',10,1) WITH NOWAIT;
:r ExtendedEvents/110_Test_und_Abnahme_Phase5.sql

RAISERROR(N'RELEASE_GATE 31/32: Infrastructure',10,1) WITH NOWAIT;
:r Infrastructure/110_Test_und_Abnahme_Phase6.sql

RAISERROR(N'RELEASE_GATE 32/32: Server Health',10,1) WITH NOWAIT;
:r ServerHealth/110_Test_und_Abnahme_Phase7.sql

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       CAST(32 AS int) AS [ExecutedSuites],
       N'Alle Integrationsverträge und Bereichs-Smoke-Tests wurden ohne SQL-Fehler beendet.' AS [Detail];
GO
