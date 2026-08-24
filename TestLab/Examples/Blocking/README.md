# BLOCKING-001

Das Beispiel verwendet die synthetische Datenbank aus `LAB-CONC-001`.

1. `SessionA-Blocker.sql` hält eine Transaktion für höchstens 30 Sekunden.
2. `SessionB-Blocked.sql` wartet auf dieselbe synthetische Zeile.
3. Das gerenderte `Analyze-And-Validate.sql` prüft die Blocking-Invariante und
   führt `monitor.USP_CurrentBlocking` aus.
4. Das gerenderte `Cleanup.sql` beendet ausschließlich Sessions mit dem exakten
   Run-Token und entfernt nur die synthetische Szenariodatenbank.

Die Quelldateien enthalten nur lokale Platzhalter. Der Runner rendert sie in
den ignorierten Laufzeitordner unter `C:\rep\tmp\SQL_Server_Analyze`; Endpunkte
und Kennwörter werden nicht in Dateien geschrieben.
