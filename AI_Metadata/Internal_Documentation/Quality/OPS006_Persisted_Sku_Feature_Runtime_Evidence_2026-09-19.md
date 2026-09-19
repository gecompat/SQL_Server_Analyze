# OPS-006: Persisted-SKU-Feature-Runtimeevidenz

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** ausschließlich synthetische Fixtures

## Ausgeführter Nachweis

Der fokussierte OPS-006-Runtimevertrag lief auf der vorhandenen Linux-Umgebung mit SQL Server 2019. Der Lauf installierte den aktuellen Frameworkstand in eine ausschließlich für den Test verwendete Datenbank und entfernte sie nach dem Vertragstest.

Der Vertrag erzeugte die synthetische Datenbank `ExampleOps006Feature`, eine Tabelle mit einem PAGE-komprimierten Clustered Index und einer synthetischen Zeile. `USP_DatabasePortabilityAnalysis` lieferte für diesen Scope mindestens eine Zeile vom Typ `PERSISTED_SKU_FEATURE`. Der bestehende Leer-, Uncontained-, Missing- und eingeschränkte Berechtigungspfad blieb Teil desselben erfolgreichen Vertragslaufs.

## Aussagegrenze

Dieser Nachweis belegt den kontrollierten positiven Featurepfad auf SQL Server 2019 unter Linux. Er belegt keine Zieledition, keine Restorefähigkeit und keine versionsübergreifende Feature-Evidenz. Der Nachweis für eine tatsächlich nicht unterstützte Quelle bleibt offen.
