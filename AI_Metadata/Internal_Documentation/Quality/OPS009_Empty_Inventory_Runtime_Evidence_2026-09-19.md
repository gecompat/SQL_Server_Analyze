# OPS-009: Empty-Inventory-Runtimeevidenz

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** ausschließlich synthetische Fixtures

Der fokussierte OPS-009-Runtimevertrag lief auf der vorhandenen Linux-Umgebung mit SQL Server 2019. Nach dem kontrollierten Entfernen der drei synthetischen Tabellen aus `master`, `model` und `msdb` lieferte `USP_SystemDatabaseObjectInventory` den Status `AVAILABLE_EMPTY` und ein leeres JSON-Array. Ein temporärer SQL-Login erhielt ausschließlich EXECUTE auf die Frameworkprocedure und lieferte anschließend `AVAILABLE_LIMITED` mit mindestens einer `DENIED_PERMISSION`-Statuszeile. Der Framework-Testscope, der Login und die Systemtabellen wurden anschließend entfernt.

Der Nachweis belegt keine partielle Metadatensichtbarkeit unter einem Berechtigungsprofil mit selektivem Zugriff auf Systemdatenbanken.
