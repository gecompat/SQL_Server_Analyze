# STATISTICS-001

Das Beispiel verwendet `LAB-PLAN-002`. Das Setup erzeugt eine vollständig aktualisierte synthetische Statistik und ändert anschließend die Datenverteilung, sodass ein positiver Modification-Counter als stabile Vorbedingung vorliegt. Der Verify-Modus ruft `[monitor].[USP_Statistics]` für das synthetische Objekt auf.

Im Interactive-Modus lesen Sie Statistikzeitpunkt, Modification-Counter und Verteilung gemeinsam. Der Zustand beweist weder einen schlechten Plan noch die Notwendigkeit eines automatischen Updates. Das Cleanup entfernt die Szenariodatenbank mit ihrem Run-Marker.
