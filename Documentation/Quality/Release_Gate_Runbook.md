# Testablauf für das Release-Gate

**Stand:** 17. Juli 2026  
**Runner:** `Code/Tests/Run_Release_Gate.sql`  
**Zielstatus vor Ausführung:** `NOT_EXECUTED`

## 1. Lokale Testkopie vorbereiten

1. Exakt den zu testenden Commit in eine lokale, nicht zur Veröffentlichung vorgesehene Arbeitskopie übernehmen.
2. In dieser lokalen Testkopie den generischen Platzhalter `[DeineDatenbank]` in den SQL-Dateien durch die Testdatenbank ersetzen.
3. Die ersetzten Dateien, SQLCMD-Ausgaben und Resultsets niemals committen oder als Repositoryartefakt speichern.
4. Für die Verbindung integrierte Authentifizierung oder eine sichere interaktive Anmeldung verwenden. Kennwörter gehören weder in Befehlszeilen noch in Nachweise.

## 2. Installation prüfen

Aus dem Verzeichnis `Code/Install` den Gesamtinstaller im SQLCMD-Modus mit Abbruch bei SQL-Fehlern ausführen. Generische Befehlsform:

```text
sqlcmd -S "<ZIEL>" -d "<INSTALLATIONSDATENBANK>" -E -b -i "Install_All.sql"
```

Erwartung:

- Prozess-Exitcode `0`.
- Kein unbehandelter SQL-Fehler.
- Keine fehlende Include-Datei.
- Keine lokale Installer- oder Konsolenausgabe in das Repository übernehmen.

## 3. Automatisiertes Release-Gate ausführen

Aus dem Verzeichnis `Code/Tests` ausführen:

```text
sqlcmd -S "<ZIEL>" -d "<INSTALLATIONSDATENBANK>" -E -b -i "Run_Release_Gate.sql"
```

Der Runner beendet sich beim ersten SQL-Fehler und führt folgende zwölf Suiten aus:

1. Smoke Test
2. Parameter-API-Vertrag
3. Filter- und Ausgabe-Vertrag
4. Spezialfall-API-Vertrag
5. Common
6. Current State
7. Object und Index
8. Plan Cache
9. Query Store
10. Extended Events
11. Infrastructure
12. Server Health

Erwartung bei vollständigem Erfolg:

- Prozess-Exitcode `0`.
- Letztes Resultset: `StatusCode=AVAILABLE`, `IsPartial=0`, `ExecutedSuites=12`.
- Kein `THROW`, kein unbehandelter Fehler und kein vorzeitiges Ende.

## 4. Spezialfallmatrix ausführen

Danach die für das Target anwendbaren Fälle aus `Metadata/Quality/Special_Case_Test_Cases.csv` ausführen. Capability-, Leerzustands-, Positiv-, Grenzwert-, Berechtigungs-, Reset- und Lastfälle bleiben getrennte Nachweise. Nicht vorhandene Features dürfen nicht als erfolgreicher Positivtest gewertet werden.

Kostenintensive Pfade nur kontrolliert und opt-in testen:

- Page Details und Event-XML
- Contention-Sampling
- Buffer-Pool-Verteilung
- Schema-Design
- Statistikverteilung
- breite Cross-Database-Auswahl

## 5. Ergebnis zurückmelden

Für die Rückmeldung genügen je Target:

- synthetische `TargetId`
- getesteter Commit-SHA
- Exitcode des Installers
- Exitcode des Release-Gates
- letzte erfolgreich gestartete Suite oder generischer Fehlercode
- `PASS`, `PASS_WITH_LIMITATIONS` oder `FAIL`
- generische Einschränkungen, beispielsweise `FEATURE_NOT_AVAILABLE` oder `DENIED_PERMISSION`

Nicht zurückmelden oder in Dateien übernehmen:

- Server-, Instanz-, Domain-, Benutzer-, Firmen-, Kunden- oder Datenbanknamen
- interne Objekt-, Schema- oder Jobnamen
- SQL-/Plantexte, Pfade, Mailadressen oder freie Runtime-Meldungen
- Screenshots oder Logs mit nicht vorab geprüften Inhalten

Die Vorlagen `Metadata/Quality/Test_Matrix.csv` und `Metadata/Quality/Release_Gate_Evidence.csv` bleiben bis zur bestätigten realen Ausführung auf `NOT_EXECUTED`. Bevor Testergebnisse in Git oder downloadbare Dateien übernommen werden, wird der konkrete, bereits bereinigte Inhalt gemeinsam geprüft.
