# TEMPDB-001

Das Beispiel verwendet `LAB-TEMP-001`. Zwei begrenzte Worker erzeugen Sortier- und Worktable-Aktivität in `tempdb`; der Verify-Modus akzeptiert nur den sichtbaren synthetischen Session- und Allokationskontext und ruft `[monitor].[USP_CurrentTempDB]` auf.

Im Interactive-Modus starten Sie alle ausgegebenen Session-Skripte, warten bis beide Sessions aktiv sind und führen danach das Analyseskript aus. Exakte Page Counts, Waits und Laufzeiten bleiben hostabhängig. Das Cleanup beendet nur Sessions mit dem exakten Run-Token.
