# OPS-007: Dormant-Cursor-Runtimeevidenz

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** ausschließlich synthetische Fixtures

## Ausgeführter Nachweis

Der fokussierte OPS-007-Runtimevertrag lief auf der vorhandenen Linux-Umgebung mit SQL Server 2019. Ein lokaler statischer Cursor blieb nach dem Öffnen länger als 60 Sekunden ruhend. `USP_CurrentCursorAnalysis` lieferte für diesen Cursor `DORMANT_CONTEXT`.

Der Test prüfte zusätzlich den sicheren Default, die Einzelsessionbegrenzung, den aktiven Cursor und die eingeschränkte Sicht. Der Framework-Testscope wurde nach dem Lauf entfernt.

## Aussagegrenze

Der Nachweis belegt keine fremde Session, keinen ressourcenauffälligen Cursor und keinen eigenständigen serverweiten Berechtigungsfehler. Die Procedure verändert keine Cursor.

## Ergänzung vom 5. Oktober 2026

Der neue Runner `TestLab/Invoke-Ops007ForeignCursorScenario.ps1` bestand auf
SQL Server `17.0.4075.5` in einem ausschließlich neu erzeugten Docker-Lab.
Frameworkinstallation, Smoke-Test und der bestehende Cursorvertrag waren
erfolgreich. Eine zweite eigene Verbindung hielt einen statischen Cursor
über 10.000 synthetische Zeilen offen. Die auf eine Zeile begrenzte Analyse
lieferte exakt dessen Session, Cursorkennung und Namen mit `RESOURCE_CONTEXT`.
Öffnungs- und Fetchzustand blieben unverändert.

Eine eigene Loginfixture erhielt ausschließlich das erforderliche
Ausführungsrecht auf den Analyzer. Die gezielte DMV-Verweigerung und die
serverweite Berechtigungsverweigerung im `master`-Kontext führten zu
`DENIED_PERMISSION`, Partialstatus, einer Berechtigungsfehlernummer und
leerem JSON. Fehlende Statuswerte bestehen die Prüfung nicht. Container,
Volume, Cursorverbindung, Benutzerfixtures und temporärer State wurden
vollständig entfernt.

Zwei verworfene Testanordnungen scheiterten zuvor mit `4629` beziehungsweise
`4621`, weil die Berechtigungsverweigerungen außerhalb von `master` gesetzt
wurden. Auch deren eigene Labs wurden vollständig entfernt. Der erfolgreiche
Gesamtlauf verwendete die korrigierte Testanordnung. Positive Ressourcenzähler
belegen keine Hochlast und keinen Cursorzustand einer fremden Betriebsumgebung.
