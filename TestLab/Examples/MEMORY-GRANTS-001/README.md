# MEMORY-GRANTS-001

Das Beispiel verwendet `LAB-MEM-001`. Drei begrenzte Worker erzeugen speicherintensive Sortierarbeit; der Verify-Modus prüft eine sichtbare Grant-Zeile oder den ausdrücklich zugelassenen aktiven Sessionkontext und ruft `[monitor].[USP_CurrentMemoryGrants]` auf.

Im Interactive-Modus starten Sie die drei Session-Skripte und analysieren den Zustand innerhalb des kurzen Beobachtungsfensters. Ein fehlender wartender Grant ist bei abweichendem Scheduler-Timing zulässig. Exakte Grantgrößen und Wartezeiten werden nicht als stabile Werte behandelt.
