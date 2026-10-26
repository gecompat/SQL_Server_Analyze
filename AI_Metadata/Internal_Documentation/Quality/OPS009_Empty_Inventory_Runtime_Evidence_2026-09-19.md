# OPS-009: Empty-Inventory-Runtimeevidenz

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** ausschließlich synthetische Fixtures

Der fokussierte OPS-009-Runtimevertrag lief auf der vorhandenen Linux-Umgebung mit SQL Server 2019. Nach dem kontrollierten Entfernen der drei synthetischen Tabellen aus `master`, `model` und `msdb` lieferte `USP_SystemDatabaseObjectInventory` den Status `AVAILABLE_EMPTY` und ein leeres JSON-Array. Ein temporärer SQL-Login erhielt ausschließlich EXECUTE auf die Frameworkprocedure und lieferte anschließend `AVAILABLE_LIMITED` mit mindestens einer `DENIED_PERMISSION`-Statuszeile. Der Framework-Testscope, der Login und die Systemtabellen wurden anschließend entfernt.

Der Nachweis belegt keine partielle Metadatensichtbarkeit unter einem Berechtigungsprofil mit selektivem Zugriff auf Systemdatenbanken.

## Ergänzung vom 5. Oktober 2026

`TestLab/Invoke-Ops009SystemInventoryScenario.ps1` erzeugte ausschließlich ein
neues SQL-Server-2025-Docker-Lab. Frameworkinstallation, Smoke-Test und der
gehärtete OPS-009-Vertrag bestanden. Der Vertrag verlangte drei synthetische
Objekte in `master`, `model` und `msdb`, exakt eine begrenzte Ergebniszeile,
`AVAILABLE_LIMITED` mit Partialstatus und Berechtigungszeile für den
eingeschränkten Login sowie `AVAILABLE_EMPTY` nach Fixturebereinigung.
Status- und JSON-Prüfungen lehnen fehlende Rückgaben ausdrücklich ab.

Objekt-, Login- und Benutzernamen werden vor jeder Mutation geprüft.
Getrennte Erzeugungsmarker binden den Fehlercleanup an tatsächlich durch den
Test angelegte Fixtures. Container, Volume und temporärer State wurden
vollständig entfernt. Der Lauf belegt SQL Server 2025; die vollständige
Buildnummer wurde nicht erfasst. Ein nativer SQL-Server-2022-Nachweis ist
dadurch nicht belegt.

Ein zweiter frischer Gesamtlauf bestand zusätzlich mit einem selektiven
Metadatenprofil. Der eigene Login erhielt einen gemappten Benutzer in
`master` und ausschließlich `SELECT` auf dessen eigene Fixturetabelle.
Der Analyzer lieferte genau diese Masterfixture als `AVAILABLE`, keine
Fixture aus `model` oder `msdb` und eine `DENIED_PERMISSION`-Zeile für
`model`. Gesamtstatus und Partialstatus blieben `AVAILABLE_LIMITED` und
`1`. Auch dieser Lauf entfernte den eigenen Container, das Volume und den
temporären State vollständig.

## Ergänzung vom 26. Oktober 2026

Der manuelle Workflow [40403446152](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40403446152)
qualifizierte den unveränderten Quellstand `abb2324168e725583edcd22f3fa670c2c2ac5dab`
auf einer nativen SQL-Server-2022-Instanz mit `qualification_scope=FULL_RELEASE`.
Das native Release-Gate bestand alle 34 Kern-Suites und die Berechtigungsmatrix;
der Runner bestätigte außerdem den Cleanup. Das öffentliche Engine-Metadatum
bestätigte Hauptversion 16, ProductVersion 16.0.4305.5, Compatibility Level 160
und Linux. Der Workflow band die Evidenz an das aus demselben Commit gebaute
Releasepaket.

Der Action-Job führte `Code/Tests/Run_Release_Gate.sql` erfolgreich aus. Dessen
Quellstand enthält den OPS-009-Vertrag
`Code/Tests/ServerHealth/123_OPS009_System_Database_Objects_Runtime_Contract.sql`.
Ein einzelner testspezifischer PASS-Marker für Vertrag 123 wurde nicht exportiert.
Der enthaltene Vertrag prüft das nicht leere Inventar über `master`, `model` und
`msdb`, die exakte Ein-Zeilen-Begrenzung, den eingeschränkten EXECUTE-only-Pfad,
das selektive `master`-Metadatenprofil mit verweigertem `model`-Zugriff und den
abschließenden Leerfall. Diese Quellabdeckung gehört zum bestandenen nativen
Core-Gate. Die vom Test angelegten Tabellen und Principals wurden entfernt; der
Runner bestätigte den Container-Cleanup.
Der Lauf schließt den dokumentierten OPS-009-OpenScope. Er belegt den einzelnen nativen
`FULL_RELEASE`-Zielumfang, keine vollständige native Drei-Versionen-Matrix.
Der OPS-009-Status lautet `IMPLEMENTED_ACTIONS_GATE`.
