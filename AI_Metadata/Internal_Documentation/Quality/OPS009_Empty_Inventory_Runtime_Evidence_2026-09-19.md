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
