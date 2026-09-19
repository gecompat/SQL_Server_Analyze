# WI-0008: Laufzeitevidenz fuer fehlende Auditkonfiguration

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** vorhandene SQL-Server-2019-Linux-Testumgebung ohne Auditobjektmutation

Der fokussierte WI-0008-Runtimevertrag ruft `USP_AuditConfigurationAnalysis` mit einem reservierten, nicht vorhandenen Auditnamen auf. Er belegt den Status `AVAILABLE`, valides JSON, leere Audit- und Spezifikationsresultsets sowie drei vollstaendig verfuegbare Quellenstatuszeilen.

Der Test erstellt, startet, stoppt, aendert oder loescht kein Auditobjekt. Er liest weder Auditdateien noch Zielpfade, Payloads oder Ereignisinhalte. Nach dem Framework-Testlauf wird die temporaere Testdatenbank entfernt.

Der eingeschraenkte Pfad verwendet einen temporaeren loginlosen Datenbankbenutzer mit ausschliesslich `EXECUTE` auf der Procedure. Er belegt valides JSON, `AVAILABLE_LIMITED` und mindestens eine Quellenstatuszeile `DENIED_PERMISSION`. Der Benutzer wird im Erfolgs- und Fehlerpfad entfernt.

Der deaktivierte Pfad erstellt ein synthetisches Serveraudit unter seinem reservierten Namen mit dynamisch ermitteltem Standarddatenpfad. Er belegt `AVAILABLE_WITH_FINDING`, `AUDIT_DISABLED` und `MEDIUM`, ohne einen Zielpfad auszugeben. Das Audit bleibt deaktiviert und wird im Erfolgs- und Fehlerpfad entfernt.

Der Nachweis deckt keinen auffaelligen Runtimezustand ab.
