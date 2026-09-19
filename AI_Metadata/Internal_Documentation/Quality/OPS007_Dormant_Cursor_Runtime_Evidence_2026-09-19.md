# OPS-007: Dormant-Cursor-Runtimeevidenz

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** ausschließlich synthetische Fixtures

## Ausgeführter Nachweis

Der fokussierte OPS-007-Runtimevertrag lief auf der vorhandenen Linux-Umgebung mit SQL Server 2019. Ein lokaler statischer Cursor blieb nach dem Öffnen länger als 60 Sekunden ruhend. `USP_CurrentCursorAnalysis` lieferte für diesen Cursor `DORMANT_CONTEXT`.

Der Test prüfte zusätzlich den sicheren Default, die Einzelsessionbegrenzung, den aktiven Cursor und die eingeschränkte Sicht. Der Framework-Testscope wurde nach dem Lauf entfernt.

## Aussagegrenze

Der Nachweis belegt keine fremde Session, keinen ressourcenauffälligen Cursor und keinen eigenständigen serverweiten Berechtigungsfehler. Die Procedure verändert keine Cursor.
