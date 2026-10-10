# WI-0002: TempDB-ADR- und PVS-Diagnostik – Analyse

**Referenz:** `WI-0002`  
**Status:** Analyse abgeschlossen; Spezifikation und Implementierung stehen aus.  
**Geltungsbereich:** SQL Server 2019 und neuer im bestehenden read-only Current-State-Pfad.

## Diagnosefrage und bestehende Abdeckung

`monitor.USP_CurrentTempDB` zeigt aktuell die Nutzung von User- und Internal-Objects je Session, die optionalen TempDB-Dateien sowie ab SQL Server 2025 die TempDB-Resource-Governance. Der bestehende Vertrag enthält keinen getrennten Export für den instanzweiten traditionellen Version Store oder für ADR Persistent Version Store (PVS). Die vorhandenen Sessionwerte dürfen nicht als vollständige Version-Store-Größe ausgelegt werden.

`sys.dm_tran_version_store_space_usage` liefert die je Datenbank in `tempdb` reservierte Version-Store-Größe. Die DMV ist ab SQL Server 2016 SP2 verfügbar; auf SQL Server 2022 und neuer erfordert sie `VIEW SERVER PERFORMANCE STATE`, auf älteren unterstützten Versionen `VIEW SERVER STATE`. [Microsoft Learn: sys.dm_tran_version_store_space_usage](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-tran-version-store-space-usage?view=sql-server-ver17)

`sys.dm_tran_persistent_version_store_stats` liefert ADR-PVS-Metriken je Datenbank. Die Quelle enthält Größe, Cleanup-Zeitpunkte und Ursachen für übersprungene Cleanup-Seiten. Die dokumentierten erweiterten Cleanupfelder gelten ab SQL Server 2022. Der Zugriff auf SQL Server und SQL Managed Instance erfordert `VIEW SERVER PERFORMANCE STATE`. [Microsoft Learn: sys.dm_tran_persistent_version_store_stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-tran-persistent-version-store-stats?view=sql-server-ver17)

Die Quellen messen verschiedene Speicherorte und Ursachen. Ein hoher PVS-Wert, ein hoher traditioneller Version Store oder eine lange Snapshot-Transaktion sind daher keine austauschbaren Befunde und keine automatische Kapazitäts- oder Konfigurationsursache. Microsoft weist außerdem darauf hin, dass lange Snapshot- oder RCSI-Transaktionen die Bereinigung des Version Store in `tempdb` auch ohne aktiviertes ADR verzögern können. [Microsoft Learn: Monitor and troubleshoot ADR](https://learn.microsoft.com/en-us/sql/relational-databases/accelerated-database-recovery-troubleshoot?view=sql-server-ver17)

## Architekturentscheidung für die Spezifikation

Die Analyse empfiehlt keine neue öffentliche Procedure. Der spätere Spezifikationsschritt bewertet eine Erweiterung von `monitor.USP_CurrentTempDB` und dessen `monitor.USP_CurrentOverview`-Snapshotroute. Ein möglicher zusätzlicher benannter Export muss getrennte Werte und getrennte Quellenstatus für den traditionellen Version Store und PVS ausweisen. Die bestehende `tempdbGovernance`-Menge bleibt unverändert, weil ihr Limit- und Workload-Group-Scope den Version Store ausdrücklich ausschließt.

Die spätere Implementierung muss jede DMV höchstens einmal pro Procedure und Aufruf lesen. Im Parentpfad sind die Werte in den bestehenden Current-State-Snapshot aufzunehmen und an `USP_CurrentTempDB` weiterzureichen. Direkte und Parentaufrufe dürfen keine voneinander abweichenden Quellenstatus erzeugen. Fehlende Rechte, fehlendes Quellschema, ein Lock-Timeout und andere Quellfehler müssen als begrenzter Quellenstatus behandelt werden; sie dürfen weder die bestehende Session- noch die Datei- oder Governanceausgabe unterdrücken.

## Nicht Bestandteil dieses Arbeitselements

Dieses Arbeitselement aktiviert oder deaktiviert ADR nicht, startet keine Bereinigung, beendet keine Session und ändert keine Datenbank- oder Serverkonfiguration. Es liest keine Abfrage-, Plan- oder Anwendungsdaten und persistiert keine Laufzeitwerte. Eine Momentaufnahme kann keinen Cleanup-Fortschritt, keine Ursache oder eine erforderliche Betriebsmaßnahme beweisen.

## Offene Spezifikationsentscheidungen

1. Das öffentliche Resultset, seine Spalten, die JSON-Repräsentation und die TABLE-Zuordnung müssen vor der Implementierung konkret festgelegt werden.
2. Die Versions- und Schema-Capability muss für die PVS-Quelle getrennt von der allgemeinen Produktversion entschieden werden; insbesondere dürfen die ab SQL Server 2022 dokumentierten Cleanupfelder nicht für ältere Versionen vorausgesetzt werden.
3. Die Ausgabe muss den traditionellen Version Store, PVS und die bereits vorhandene sessionbezogene TempDB-Nutzung fachlich und sprachlich voneinander trennen.
4. Die Laufzeitmatrix muss mindestens die vorgesehenen SQL-Server-2019-, 2022- und 2025-Pfade sowie Rechte-, leere-, positive-, Parent-, JSON-, TABLE-, Fehler- und Cleanupgrenzen abdecken. Die verbindliche CI-Teststrategie bestimmt den konkreten Umfang der zusätzlichen nativen Läufe.

## Nächster zulässiger Schritt

Als Nächstes wird die öffentliche Spezifikation erstellt. Sie benötigt eine funktionsbezogene Freigabe, bevor ein Resultsetinventar, SQL-Code, Installer oder Runtimefixture geändert werden.
