# Testmatrix und Freigabeprotokoll

**Stand:** 18. Juli 2026
**Status:** ausfüllbare, datenschutzkonforme Vorlage  
**Maschinenlesbare Fassung:** `Metadata/Quality/Test_Matrix.csv`
**Integrationsrunner:** `Code/Tests/Run_Release_Gate.sql`  
**Suite-Evidenz:** `Metadata/Quality/Release_Gate_Evidence.csv`
**Ausführungsanleitung:** `Documentation/Quality/Release_Gate_Runbook.md`

Die zielunabhängigen Modulfälle stehen zusätzlich in `Metadata/Quality/Special_Case_Test_Cases.csv`. Zielmatrix und Modulfälle werden über `TargetId`, getesteten Commit und einen nicht sensitiven Evidence-Verweis gemeinsam dokumentiert.

## Zweck

Diese Matrix dokumentiert nachprüfbar, auf welchen SQL-Server-Ausprägungen ein Repositorystand installiert, kompiliert und getestet wurde. Ein allgemeiner Hinweis wie „vollständig getestet“ ersetzt keine konkrete Zielmatrix.

## Datenschutz

Das Protokoll enthält ausschließlich technische Produktmerkmale und synthetische Target-IDs. Nicht dokumentiert werden reale Server-, Instanz-, Benutzer-, Firmen-, Kunden-, Datenbank-, Domain-, Host- oder Infrastrukturbezeichner. Resultsets und OUTPUT-Parameter der getesteten Procedures bleiben davon unberührt.

## Pflichtfelder

| Feld | Bedeutung |
|---|---|
| TargetId | synthetische stabile Kennung, beispielsweise SQL2019-WINDOWS |
| ProductMajorVersion | 15, 16 oder 17 |
| ProductVersion | vollständige technische Buildnummer, sofern bestätigt |
| EditionClass | EXPRESS, STANDARD, ENTERPRISE, DEVELOPER oder AZURE_MI |
| Platform | WINDOWS, LINUX oder AZURE_MI |
| CompatibilityLevel | getesteter Compatibility Level |
| Collation | erwartete case-sensitive Zielcollation |
| PermissionProfile | technische Berechtigungsklasse ohne Principalnamen |
| OptionalFeatures | Pipe-Liste generischer Featurecodes |
| CommitSha | exakt getesteter Commit |
| TestStatus | NOT_EXECUTED, PASS, PASS_WITH_LIMITATIONS oder FAIL |
| EvidenceStatus | REPORTED oder INDEPENDENTLY_VERIFIED |

## Verbindliche Prüffolge je Target

1. Installer im vorgesehenen Datenbankkontext ausführen.
2. Compile- und Objektbestand prüfen.
3. Im SQLCMD-Modus aus `Code/Tests` den Runner `Run_Release_Gate.sql` ausführen. Er startet die vier folgenden Verträge und danach acht Bereichs-Smoke-Tests in fester Reihenfolge; beim ersten SQL-Fehler wird beendet:
   - `Integration/110_Smoke_Test.sql`
   - `Integration/163_Parameter_API_Vertrag.sql`
   - `Integration/165_Filter_Output_Contract.sql`
   - `Integration/167_Special_Case_API_Contract.sql`
   - Common, Current State, Object/Index, Plan Cache, Query Store, Extended Events, Infrastructure und Server Health
4. Bereichstests für Common, Current State, Object/Index, Plan Cache, Query Store, Extended Events, Infrastructure und Server Health ausführen.
5. Neue Spezialfallmodule gegen Capability-, Leerzustands-, Positiv-, Berechtigungs-, Reset- und Lastfälle prüfen; bei Statistikverteilung zusätzlich Uniform-, Dominanz-, Tail-, Modification-, Filter-, Incremental- und Kandidatengrenzfälle. Für `USP_SpecialFeatureInventory` sind Feature-absent, eingeschränkte Metadatensichtbarkeit, Begrenzung sowie je ein positiver Fall für alle 18 Featurecodes vorgesehen. Für `USP_InMemoryOltpAnalysis` sind No-XTP, Schema-only, Speicher-, Hashketten-, Checkpoint-, Transaktions-, Pool-, Berechtigungs-, Filter-, Begrenzungs- und Kostenfälle definiert. Für `USP_TemporalAnalysis` sind No-Temporal, Zuordnung/Period, Retention, Kapazität/Ratio, Indexbaseline, Memory-Optimized, Berechtigung, Filter, Begrenzung und die ausdrückliche Nichterkennbarkeit getrennter Paare vorgesehen. Für `USP_ServiceBrokerAnalysis` sind No-Broker, Konfiguration ohne Objekte, deaktivierter Broker mit Objekten, Queue-Schalter, approximative Kapazität, interne Aktivierung, Transmission-Alter/-Status, Conversation-Zustände, Retention, Berechtigungen, Filter, Begrenzung und ein statischer Payload-Ausschluss vorgesehen. Alle Fälle stehen in `Special_Case_Test_Cases.csv`.
6. RAW-, CONSOLE-, NONE- und JSON-Verträge verifizieren.
7. Repository- und Liefergate ausführen.
8. Targetstatus in `Test_Matrix.csv` und jeden Suite-Status in `Release_Gate_Evidence.csv` festhalten. Reale Umgebungswerte, Resultsets und lokale Pfade dürfen nicht übernommen werden.

`Release_Gate_Evidence.csv` enthält ausschließlich vorab definierte synthetische Target- und Suitekennungen. `CommitSha`, `TestedAtUtc` und ein generischer Evidence-Verweis werden erst nach realer Ausführung ergänzt. Sobald ein vorgesehener Nachweis sensible oder nicht eindeutig generische Inhalte enthalten könnte, bleibt der Schreibvorgang angehalten und der zulässige Inhalt muss vorab geklärt werden.

## Freigaberegel

Ein Target gilt nur dann als freigegeben, wenn `TestStatus` mindestens `PASS_WITH_LIMITATIONS` ist, der getestete Commit exakt angegeben wurde und jede Einschränkung als generische Capability- oder Berechtigungsaussage dokumentiert ist. Nicht ausgeführte Zeilen bleiben ausdrücklich `NOT_EXECUTED`.

Die initialen Zeilen der CSV sind Planungseinträge und keine behaupteten Testergebnisse.
