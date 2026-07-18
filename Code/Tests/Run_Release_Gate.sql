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
Statistik    : Suite 175 isoliert Child-Status, begrenzt Histogrammzugriffe und
               prüft positive, begrenzte sowie verweigerte Ausführungspfade.
Availability: Suite 176 prüft HADR-Abwesenheit und die gemeinsamen reinen
               Klassifikationspfade ohne Cluster- oder Konfigurationsänderung.
===============================================================================
*/

RAISERROR(N'RELEASE_GATE 1/21: Smoke Test',10,1) WITH NOWAIT;
:r Integration/110_Smoke_Test.sql

RAISERROR(N'RELEASE_GATE 2/21: Parameter-API-Vertrag',10,1) WITH NOWAIT;
:r Integration/163_Parameter_API_Vertrag.sql

RAISERROR(N'RELEASE_GATE 3/21: Filter- und Ausgabe-Vertrag',10,1) WITH NOWAIT;
:r Integration/165_Filter_Output_Contract.sql

RAISERROR(N'RELEASE_GATE 4/21: Spezialfall-API-Vertrag',10,1) WITH NOWAIT;
:r Integration/167_Special_Case_API_Contract.sql

RAISERROR(N'RELEASE_GATE 5/21: Spezialfall-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/168_Special_Case_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 6/21: P0-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/169_P0_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 7/21: P1-IQP-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/170_P1_IQP_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 8/21: P1-Contention-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/171_P1_Contention_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 9/21: P1-Speicher-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/172_P1_Memory_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 10/21: P1-Backupketten-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/173_P1_Backup_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 11/21: P1-Schema-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/174_P1_Schema_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 12/21: P1-Statistikverteilungs-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/175_P1_Statistics_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 13/21: P1-Availability-Laufzeitvertrag',10,1) WITH NOWAIT;
:r Integration/176_P1_Availability_Runtime_Contract.sql

RAISERROR(N'RELEASE_GATE 14/21: Common',10,1) WITH NOWAIT;
:r Common/090_Test_und_Abnahme_Phase1A.sql

RAISERROR(N'RELEASE_GATE 15/21: Current State',10,1) WITH NOWAIT;
:r CurrentState/110_Test_und_Abnahme_Phase1B.sql

RAISERROR(N'RELEASE_GATE 16/21: Object und Index',10,1) WITH NOWAIT;
:r ObjectIndex/110_Test_und_Abnahme_Phase2.sql

RAISERROR(N'RELEASE_GATE 17/21: Plan Cache',10,1) WITH NOWAIT;
:r PlanCache/110_Test_und_Abnahme_Phase3.sql

RAISERROR(N'RELEASE_GATE 18/21: Query Store',10,1) WITH NOWAIT;
:r QueryStore/110_Test_und_Abnahme_Phase4.sql

RAISERROR(N'RELEASE_GATE 19/21: Extended Events',10,1) WITH NOWAIT;
:r ExtendedEvents/110_Test_und_Abnahme_Phase5.sql

RAISERROR(N'RELEASE_GATE 20/21: Infrastructure',10,1) WITH NOWAIT;
:r Infrastructure/110_Test_und_Abnahme_Phase6.sql

RAISERROR(N'RELEASE_GATE 21/21: Server Health',10,1) WITH NOWAIT;
:r ServerHealth/110_Test_und_Abnahme_Phase7.sql

SELECT CAST('AVAILABLE' AS varchar(40)) AS [StatusCode],
       CAST(0 AS bit) AS [IsPartial],
       CAST(21 AS int) AS [ExecutedSuites],
       N'Alle Integrationsverträge und Bereichs-Smoke-Tests wurden ohne SQL-Fehler beendet.' AS [Detail];
GO
