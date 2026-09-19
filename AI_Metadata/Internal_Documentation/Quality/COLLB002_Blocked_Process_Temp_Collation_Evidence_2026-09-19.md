# COLL-B002: Blocked-Process-Temp-Tabellen-Kollationsevidenz

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`

`USP_ExtendedEventsBlockedProcesses` legt alle Zeichenfelder seiner sechs lokalen Ergebnis- und Quellenstatus-Temp-Tabellen mit `SQL_Latin1_General_CP1_CS_AS` an. Der statische Vertrag sichert diese Grenze gegen eine stille Rueckkehr zur `tempdb`-Kollation.

Der fokussierte Lauf erfolgt auf der vorhandenen SQL-Server-2019-Linux-Instanz mit abweichender Server- und `tempdb`-Kollation. Er installiert den kanonischen Stand in die Framework-Datenbank und prueft den lesenden deaktivierten Quellpfad ohne Extended-Events- oder Konfigurationsaenderung. Die temporaere Framework-Datenbank wird anschliessend entfernt.
