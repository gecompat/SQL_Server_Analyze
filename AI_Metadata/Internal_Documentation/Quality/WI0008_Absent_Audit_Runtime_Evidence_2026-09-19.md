# WI-0008: Laufzeitevidenz fuer fehlende Auditkonfiguration

**Stand:** 19. September 2026  
**Status:** `LOCAL_WORKTREE_EVIDENCE`  
**Datenbasis:** vorhandene SQL-Server-2019-Linux-Testumgebung; der fehlende und der eingeschränkte Fall verändern keine Auditobjekte, die deaktivierten und aktiven Fälle verwenden eigene synthetische Auditobjekte

Der fokussierte WI-0008-Runtimevertrag ruft `USP_AuditConfigurationAnalysis` mit einem reservierten, nicht vorhandenen Auditnamen auf. Er belegt den Status `AVAILABLE`, valides JSON, leere Audit- und Spezifikationsresultsets sowie drei vollstaendig verfuegbare Quellenstatuszeilen.

Der fehlende und der eingeschraenkte Fall erstellen, starten, stoppen, aendern oder loeschen kein Auditobjekt. Der Produktpfad liest in keinem der vier Faelle Auditdateien, Zielpfade, Payloads oder Ereignisinhalte. Nach dem Framework-Testlauf wird die temporaere Testdatenbank entfernt.

Der eingeschraenkte Pfad verwendet einen temporaeren loginlosen Datenbankbenutzer mit ausschliesslich `EXECUTE` auf der Procedure. Er belegt valides JSON, `AVAILABLE_LIMITED` und mindestens eine Quellenstatuszeile `DENIED_PERMISSION`. Der Benutzer wird im Erfolgs- und Fehlerpfad entfernt.

Der deaktivierte Pfad erstellt ein synthetisches Serveraudit unter seinem reservierten Namen mit dynamisch ermitteltem Standarddatenpfad. Er belegt `AVAILABLE_WITH_FINDING`, `AUDIT_DISABLED` und `MEDIUM`, ohne einen Zielpfad auszugeben. Das Audit bleibt deaktiviert und wird im Erfolgs- und Fehlerpfad entfernt.

Der aktive Pfad erstellt ein zweites synthetisches Serveraudit mit demselben dynamischen Datenschutzrahmen, aktiviert es kurz und belegt `AVAILABLE`, `STARTED` oder `RUNNING`, `AUDIT_CONFIGURED` und `INFO`. Das Audit wird vor dem Ende des Tests wieder deaktiviert und entfernt. Lokale Dateiartefakte mit dem reservierten Testnamen werden außerhalb des Repositorys bereinigt.

Die kontrollierten Fälle fehlend, eingeschraenkt, deaktiviert und aktiv sind damit nachgewiesen. Der Produktstatus ist `IMPLEMENTED_ACTIONS_GATE`.

## Remote-Nachtrag vom 16. November 2026

Der oben datierte lokale Bericht behält den Status `LOCAL_WORKTREE_EVIDENCE`. Auf dem exakten PR-702-Head `cecde05f9b592881cdee7e820ffb7b39434ed0fe` bestand der [native SQL-Server-2019-Lauf 43643920546](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43643920546), Job 132597678295, als `FULL_RELEASE` auf Linux mit Compatibility Level 150. Sein SQLCMD-Aufruf führte `Run_Release_Gate.sql` mit `:ON ERROR EXIT` aus. Das Gate band `124_WI0008_Audit_Configuration_Runtime_Contract.sql` verpflichtend genau einmal ein. Die Fixture prüft die Fälle fehlender Auditname, eingeschränkte Metadatensicht, eigenes deaktiviertes Audit und eigenes kurz aktives Audit einschließlich des vorgesehenen Rückbaus.

Auf SQL Server 2025 mit Compatibility Level 170 bestanden der [Head-Lauf 43641963899](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43641963899), Runtime-Job 132591342539 und Gate-Job 132596890254, sowie der [erste Mainlauf 43644539535](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/43644539535), Runtime-Job 132599317720 und Gate-Job 132604106744. Beide Impactpläne setzten `full_suite=true` und `run_release_tests=true`; der kanonische Runner band dafür dasselbe Release-Gate ein. Die aktuelle Produktquelle `d33e09b10f976d6d57ec669fba822cbc89af08e9`, Fixture 124 `d23f766c603ffc2a9202a3526bda6b872268ae78` und ihre erreichbaren Frameworkhelfer sind zu dem geprüften Head bytegleich. Die später geänderten Analyseviews 021 bis 023 gehören nicht zu diesem Aufrufpfad.

Ein separater SQL-stdout-Marker für Fixture 124 wurde nicht ausgewertet. Die eigenständige Common-Fixture 136 mit positiver Audit-/Spezifikationsparität war im eingefrorenen Release-Gate nicht enthalten und erhält daraus keinen neuen Remote-Nachweis. Der gebundene Nachweis betrifft die kontrollierten Katalog- und Statusfälle; Audit-Payloads, Zielpfade, Erfassungswirksamkeit, globale Vollständigkeit, externe Gesundheit und eine neue native SQL-Server-2022-Abnahme folgen daraus nicht. Die Audit-DDL gehört ausschließlich zur eigenen Testfixture, nicht zur Produktprozedur.
