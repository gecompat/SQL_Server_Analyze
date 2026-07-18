# Testmatrix und Freigabeprotokoll

**Stand:** 18. Juli 2026
**Status:** commitbezogene 16-Suite-Actions-Evidenz für vollständiges P0, vier P1-IQP- und vier P1-Contention-Fälle auf SQL Server 2019, 2022 und 2025 vorhanden
**Maschinenlesbare Fassung:** `Metadata/Quality/Test_Matrix.csv`
**Integrationsrunner:** `Code/Tests/Run_Release_Gate.sql`  
**Suite-Evidenz:** `Metadata/Quality/Release_Gate_Evidence.csv`
**Ausführungsanleitung:** `Documentation/Quality/Release_Gate_Runbook.md`

Die zielunabhängigen Modulfälle stehen zusätzlich in `Metadata/Quality/Special_Case_Test_Cases.csv`. Zielmatrix und Modulfälle werden über `TargetId`, getesteten Commit und einen nicht sensitiven Evidence-Verweis gemeinsam dokumentiert.

## Zweck

Diese Matrix dokumentiert nachprüfbar, auf welchen SQL-Server-Ausprägungen ein Repositorystand installiert, kompiliert und getestet wurde. Ein allgemeiner Hinweis wie „vollständig getestet“ ersetzt keine konkrete Zielmatrix.

Technische Grundlage sind die offiziellen Verträge zum [Pullen beziehungsweise Pinnen eines Docker-Images per Digest](https://docs.docker.com/reference/cli/docker/image/pull/), zu den [SQL-Server-Linux-Containerimages](https://learn.microsoft.com/en-us/sql/linux/install-upgrade/quickstart-install-docker?view=sql-server-ver17) und zu [`SERVERPROPERTY('ProductVersion')`](https://learn.microsoft.com/en-us/sql/t-sql/functions/serverproperty-transact-sql?view=sql-server-ver17). `ProductVersion` wird als `major.minor.build.revision` validiert; der Digest wird als unveränderlicher Startbezug verwendet.

## Automatisierte Evidence

Commit `e26f246e7b9e21b2d882ac69feaa32fb3f5f36c9` hat Installer, den 16-Suite-Release-Gate-Vertrag einschließlich 15 P0-Laufzeitfällen, vier P1-IQP- und vier P1-Contention-Fällen sowie die Berechtigungsmatrix einschließlich zwei P0-Restricted-Login-Fällen auf den drei Linux-Targets erfolgreich abgeschlossen. Das SQL-Server-2025-Gate hat zusätzlich die eigenständige Regex-Matrix ausgeführt:

| Target | ProductVersion | Compatibility Level | Actions-Nachweis | Ergebnis |
|---|---|---:|---|---|
| SQL Server 2019 | `15.0.4480.2` | 150 | [Run 29638311804](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/29638311804) | `PASS_WITH_LIMITATIONS`; alle 17 P0-, vier P1-IQP- und vier P1-Contention-Fälle |
| SQL Server 2022 | `16.0.4265.3` | 160 | [Run 29638311795](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/29638311795) | `PASS_WITH_LIMITATIONS`; alle 17 P0-, vier P1-IQP- und vier P1-Contention-Fälle |
| SQL Server 2025 | `17.0.4065.4` | 170 | [Run 29638311799](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/29638311799) | `PASS_WITH_LIMITATIONS`; alle 17 P0-, vier P1-IQP- und vier P1-Contention-Fälle; `REGEX_MATRIX=PASS` |

Die Läufe haben nach dem Pull den aufgelösten Digest validiert und exakt diesen unveränderlichen Bezug gestartet:

| Target | Container-Image-Digest |
|---|---|
| SQL Server 2019 | `mcr.microsoft.com/mssql/server@sha256:46f719fd3457d4e7e8e5845fe00c35c20e7bae7ff1e8b9fe595f2a81029f5ba8` |
| SQL Server 2022 | `mcr.microsoft.com/mssql/server@sha256:ba4c8329f48fb8f02e1416be6a930ebfd71268caee78aa985f3af4315e457c89` |
| SQL Server 2025 | `mcr.microsoft.com/mssql/server@sha256:86cc6144ef39bb0fbed2329e1ad79b13ee82e7b2e4739213a0db0800e668a74a` |

Der [Dokumentations- und statische Vertrag](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/29638311830) und das [Repository-Datenschutzgate](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/29638311806) sind für denselben Commit ebenfalls grün. Die vollständigen maschinenlesbaren Build- und Digestwerte stehen in `Test_Matrix.csv`; P0-, P1-IQP-, P1-Contention- und Regex-Matrix sind als eigene Suitezeilen in `Release_Gate_Evidence.csv` vermerkt. Diese Evidence gilt für disposable synthetische Linux-Ziele. Der Page-Detail-Vertrag erzwang keinen aktuellen PAGELATCH-Wait; weitere Feature-Positiv-, Grenzwert-, Last-, Windows-, Azure-MI- oder externe Restore-Nachweise bleiben separat.

## Datenschutz

Das Protokoll enthält ausschließlich technische Produktmerkmale und synthetische Target-IDs. Nicht dokumentiert werden reale Server-, Instanz-, Benutzer-, Firmen-, Kunden-, Datenbank-, Domain-, Host- oder Infrastrukturbezeichner. Resultsets und OUTPUT-Parameter der getesteten Procedures bleiben davon unberührt.

## Pflichtfelder

| Feld | Bedeutung |
|---|---|
| TargetId | synthetische stabile Kennung, beispielsweise SQL2019-WINDOWS |
| ProductMajorVersion | 15, 16 oder 17 |
| ProductVersion | vollständige technische Buildnummer, sofern bestätigt |
| ContainerImageReference | beim Pull verwendeter öffentlicher MCR-Tag; für Nicht-Container-Ziele leer |
| ContainerImageDigest | beim Lauf aufgelöster unveränderlicher `repo@sha256`-Digest; für Nicht-Container-Ziele leer |
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

1. Bei Containerzielen den öffentlichen Image-Tag pullen, den aufgelösten `repo@sha256`-Digest validieren und exakt diesen Digest starten; nach Bereitschaft `SERVERPROPERTY('ProductVersion')` erfassen.
2. Installer im vorgesehenen Datenbankkontext ausführen.
3. Compile- und Objektbestand prüfen.
4. Im SQLCMD-Modus aus `Code/Tests` den Runner `Run_Release_Gate.sql` ausführen. Er startet die acht folgenden Verträge und danach acht Bereichs-Smoke-Tests in fester Reihenfolge; beim ersten SQL-Fehler wird beendet:
   - `Integration/110_Smoke_Test.sql`
   - `Integration/163_Parameter_API_Vertrag.sql`
   - `Integration/165_Filter_Output_Contract.sql`
   - `Integration/167_Special_Case_API_Contract.sql`
   - `Integration/168_Special_Case_Runtime_Contract.sql`
   - `Integration/169_P0_Runtime_Contract.sql`
   - `Integration/170_P1_IQP_Runtime_Contract.sql`
   - `Integration/171_P1_Contention_Runtime_Contract.sql`
   - Common, Current State, Object/Index, Plan Cache, Query Store, Extended Events, Infrastructure und Server Health
5. Bereichstests für Common, Current State, Object/Index, Plan Cache, Query Store, Extended Events, Infrastructure und Server Health ausführen.
6. Neue Spezialfallmodule gegen Capability-, Leerzustands-, Positiv-, Berechtigungs-, Reset- und Lastfälle prüfen; bei Statistikverteilung zusätzlich Uniform-, Dominanz-, Tail-, Modification-, Filter-, Incremental- und Kandidatengrenzfälle. Für `USP_SpecialFeatureInventory` sind Feature-absent, eingeschränkte Metadatensichtbarkeit, Begrenzung sowie je ein positiver Fall für alle 18 Featurecodes vorgesehen. Für `USP_InMemoryOltpAnalysis` sind No-XTP, Schema-only, Speicher-, Hashketten-, Checkpoint-, Transaktions-, Pool-, Berechtigungs-, Filter-, Begrenzungs- und Kostenfälle definiert. Für `USP_TemporalAnalysis` sind No-Temporal, Zuordnung/Period, Retention, Kapazität/Ratio, Indexbaseline, Memory-Optimized, Berechtigung, Filter, Begrenzung und die ausdrückliche Nichterkennbarkeit getrennter Paare vorgesehen. Für `USP_ServiceBrokerAnalysis` sind No-Broker, Konfiguration ohne Objekte, deaktivierter Broker mit Objekten, Queue-Schalter, approximative Kapazität, interne Aktivierung, Transmission-Alter/-Status, Conversation-Zustände, Retention, Berechtigungen, Filter, Begrenzung und ein statischer Payload-Ausschluss vorgesehen. Für `USP_FullTextAnalysis` sind Feature-/Katalogzustand, Indexschalter, Populationen, Batches, Fragmente, Semantik, Memory/FDHost, Berechtigungen, Filter, Begrenzung und Inhalts-/DDL-Ausschluss vorgesehen. Für `USP_DataCaptureDeepAnalysis` sind CT-Consumer-Versionen, CDC-Scan/Fehler/Jobs/Cleanup, lokale Replikationsagenten/Rückstand/Fehler, Remote-Topologielücke, Berechtigungen, Filter, Begrenzung und Nutzdaten-/Credential-/Command-/DDL-Ausschluss vorgesehen. `USP_EncryptionAnalysis` trennt TDE, Zertifikatslebenszyklus, explizite Backupverschlüsselung und aggregierte Always-Encrypted-/Ledger-Fälle. `USP_MaintenanceOperations` trennt pausierte/aktive Requests, PVS-Versionen, ungefilterte und explizit gefilterte Jobfälle sowie den statischen Änderungs- und Inhaltsausschluss. Alle Fälle stehen in `Special_Case_Test_Cases.csv`.
7. RAW-, CONSOLE-, NONE- und JSON-Verträge verifizieren.
8. Repository- und Liefergate ausführen.
9. Targetstatus in `Test_Matrix.csv` und jeden Suite-Status in `Release_Gate_Evidence.csv` festhalten. Reale Umgebungswerte, Resultsets und lokale Pfade dürfen nicht übernommen werden.

`Release_Gate_Evidence.csv` enthält ausschließlich vorab definierte synthetische Target- und Suitekennungen. `CommitSha`, `TestedAtUtc` und ein generischer Evidence-Verweis werden erst nach realer Ausführung ergänzt. Sobald ein vorgesehener Nachweis sensible oder nicht eindeutig generische Inhalte enthalten könnte, bleibt der Schreibvorgang angehalten und der zulässige Inhalt muss vorab geklärt werden.

## Freigaberegel

Ein Target gilt nur dann als freigegeben, wenn `TestStatus` mindestens `PASS_WITH_LIMITATIONS` ist, der getestete Commit exakt angegeben wurde und jede Einschränkung als generische Capability- oder Berechtigungsaussage dokumentiert ist. Nicht ausgeführte Zeilen bleiben ausdrücklich `NOT_EXECUTED`.

Die drei Windows-Zeilen der CSV bleiben Planungseinträge und keine behaupteten Testergebnisse.
