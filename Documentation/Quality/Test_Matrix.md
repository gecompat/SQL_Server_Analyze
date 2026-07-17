# Testmatrix und Freigabeprotokoll

**Stand:** 17. Juli 2026  
**Status:** ausfüllbare, datenschutzkonforme Vorlage  
**Maschinenlesbare Fassung:** `Metadata/Quality/Test_Matrix.csv`

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
3. `Code/Tests/Integration/110_Smoke_Test.sql` ausführen.
4. `Code/Tests/Integration/163_Parameter_API_Vertrag.sql` ausführen.
5. `Code/Tests/Integration/165_Filter_Output_Contract.sql` ausführen.
6. `Code/Tests/Integration/167_Special_Case_API_Contract.sql` ausführen.
7. Bereichstests für Common, Current State, Object/Index, Plan Cache, Query Store, Extended Events, Infrastructure und Server Health ausführen.
8. Neue Spezialfallmodule gegen Capability-, Leerzustands-, Positiv-, Berechtigungs-, Reset- und Lastfälle prüfen.
9. RAW-, CONSOLE-, NONE- und JSON-Verträge verifizieren.
10. Repository- und Liefergate ausführen.
11. Ergebnis und Einschränkungen ohne reale Umgebungswerte in der CSV festhalten.

## Freigaberegel

Ein Target gilt nur dann als freigegeben, wenn `TestStatus` mindestens `PASS_WITH_LIMITATIONS` ist, der getestete Commit exakt angegeben wurde und jede Einschränkung als generische Capability- oder Berechtigungsaussage dokumentiert ist. Nicht ausgeführte Zeilen bleiben ausdrücklich `NOT_EXECUTED`.

Die initialen Zeilen der CSV sind Planungseinträge und keine behaupteten Testergebnisse.
