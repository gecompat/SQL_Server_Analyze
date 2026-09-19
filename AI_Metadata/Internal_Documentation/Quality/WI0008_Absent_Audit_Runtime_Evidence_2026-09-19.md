# WI-0008: Laufzeitevidenz fuer fehlende Auditkonfiguration

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** vorhandene SQL-Server-2019-Linux-Testumgebung ohne Auditobjektmutation

Der fokussierte WI-0008-Runtimevertrag ruft `USP_AuditConfigurationAnalysis` mit einem reservierten, nicht vorhandenen Auditnamen auf. Er belegt den Status `AVAILABLE`, valides JSON, leere Audit- und Spezifikationsresultsets sowie drei vollstaendig verfuegbare Quellenstatuszeilen.

Der Test erstellt, startet, stoppt, aendert oder loescht kein Auditobjekt. Er liest weder Auditdateien noch Zielpfade, Payloads oder Ereignisinhalte. Nach dem Framework-Testlauf wird die temporaere Testdatenbank entfernt.

Der Nachweis deckt keine deaktivierte Auditkonfiguration, keine partielle oder verweigerte Metadatensicht und keinen auffaelligen Runtimezustand ab.
