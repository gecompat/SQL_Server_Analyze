# Lokale Runtimeevidenz zum Reifeabschluss

**Stand:** 29. August 2026
**Status:** `LOCAL_WORKTREE_EVIDENCE`
**Datenbasis:** ausschließlich synthetische Fixtures

## Einordnung

Diese Evidenz beschreibt tatsächlich ausgeführte lokale Läufe des noch nicht commitgebundenen Arbeitsstands. Sie ersetzt weder die unabhängig verifizierte historische Release-Evidenz in `Metadata/Quality/Test_Matrix.csv` noch einen späteren Actions-Nachweis des resultierenden Commits. Konkrete Run-IDs, lokale Pfade, Credentials, Containerbezeichner und Laufzeitausgaben werden nicht im Repository gespeichert.

## Vollständige native Release-Gates

Der generierte Standalone-Installer umfasste 165 kanonische SQL-Dateien und wurde je Ziel vollständig installiert. Anschließend lief `Code/Tests/Run_Release_Gate.sql` mit 34 Suiten. Jede Umgebung verwendete `SQL_Latin1_General_CP1_CS_AS`, den Docker-Provider und ein scopegebundenes Cleanup.

| SQL Server | Plattform | Ergebnis | Cleanup |
|---|---|---|---|
| 2019 | Linux-Container über Docker | `PASS`, 34 Suiten | `CLEANUP_SUCCEEDED` |
| 2022 | Linux-Container über Docker | `PASS`, 34 Suiten | `CLEANUP_SUCCEEDED` |
| 2025 | Linux-Container über Docker | `PASS`, 34 Suiten | `CLEANUP_SUCCEEDED` |

Die Läufe bestätigen die in das Release-Gate aufgenommenen Basisverträge von `OPS-005` bis `OPS-009` sowie den TABLE-Collationvertrag auf den drei nativen Engineversionen. Sie bestätigen keine abweichende Server- oder `tempdb`-Collation.

## Analyze-Beispiele auf SQL Server 2025

Die sechs zuvor offenen Beispiele liefen mit ihrem katalogisierten Verify-Ablauf über den primären Docker-Provider. Jeder Lauf installierte den vollständigen Frameworkstand, führte Setup, Analyzer-Assertion und Cleanup aus und entfernte anschließend seine Labressourcen.

| Beispiel | Szenario | Ergebnis |
|---|---|---|
| `QUERY-STORE-001` | `LAB-QS-001` | `PASS` |
| `TEMPDB-001` | `LAB-TEMP-001` | `PASS` |
| `STATISTICS-001` | `LAB-PLAN-002` | `PASS` |
| `MEMORY-GRANTS-001` | `LAB-MEM-001` | `PASS` |
| `EXECUTION-PLAN-001` | `LAB-EXECPLAN-001` | `PASS` |
| `INDEX-USAGE-001` | `LAB-IDX-003` | `PASS` |

Zusammen mit der bereits vorhandenen Evidenz für `BLOCKING-001` ist der definierte Sieben-Beispiele-Umfang von `ANALYZE-LAB-001` umgesetzt. Die sechs neuen Beispiele benötigen nach der impact-basierten Teststrategie keine zusätzliche native Version oder einen zweiten Provider, weil ihre Änderungen keine provider- oder versionsspezifische Lifecyclelogik einführen.

## Durch Runtimeevidenz korrigierte Abweichungen

Die Läufe fanden und regressierten folgende Vertragsabweichungen:

- Der Runner bindet seine erlaubte temporäre Wurzel jetzt vor Änderungen an `TEMP` und `TMP`.
- Ein fehlgeschlagenes Interactive-Setup führt ohne `KeepOnFailure` ebenfalls das registrierte Cleanup aus.
- Das Query-Store-Fixture übergibt eine vorab berechnete Variable an `EXEC`.
- Die TempDB-Assertion unterscheidet aktive Task- und abgeschlossene Session-Allokation im expliziten `tempdb`-Kontext.
- Das Execution-Plan-Fixture übergibt keinen abgeleiteten Planquellenstatus als Eingabe und akzeptiert den öffentlichen Status `PARTIAL`.
- Die synthetische `OPS-006`-Procedure wird in einem eigenen dynamischen Batch erstellt.
- `USP_CurrentOverview` aggregiert Child-JSON über explizit collatierte temporäre Textfelder.

## Verbleibende Evidenzgrenzen

Die folgenden Fälle wurden nicht als bestanden verbucht:

- `OPS-005`: kontrollierter Remote-Erfolg, gesonderter Timeout, Providerabweichung und ein eigenständiger Berechtigungsfall;
- `OPS-006`: positiv featuregebundene persistierte SKU-Evidenz und eine tatsächlich nicht unterstützte Quelle;
- `OPS-007`: dormanter oder fremder ressourcenauffälliger Cursor und eigenständiger Berechtigungsfehler;
- `OPS-008`: kontrollierte kurze und lange Historien, Wachstum und fehlende optionale Quellen;
- `OPS-009`: expliziter Leerzustand und nachgewiesene partielle Metadatensichtbarkeit;
- `COLL-001`: abweichende Server-, `tempdb`- und Frameworkcollations sowie die vollständige per-Datei-Härtung;
- Podman-Läufe für die sechs neuen Analyze-Beispiele.

Diese Grenzen halten `OPS-005` bis `OPS-009` und `COLL-001` im Status `PARTIAL_PRODUCT_FUNCTION`. Sie erweitern die öffentliche Collationgarantie nicht.
