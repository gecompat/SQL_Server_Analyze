# Testablauf für das Release-Gate

**Stand:** 18. Juli 2026
**Runner:** `Code/Tests/Run_Release_Gate.sql`  
**Zielstatus vor Ausführung:** `NOT_EXECUTED`

## 0. Statische Repositoryprüfung

Vor Installation oder Runtime-Tests aus dem Repositoryroot ausführen:

```powershell
pwsh ./Code/Tests/Static/900_Validate_Analysis_Documentation.ps1
```

Erwartung:

- Prozess-Exitcode `0`.
- `Referenced procedures`, `Canonical source procedures` und `Procedure pages` ergeben jeweils `81`.
- Letzte Meldung: `Analysis documentation validation succeeded.`
- Bei einem Fehler keine Installation und kein SQL-Release-Gate starten, sondern zuerst Referenz, SQL-Signatur, Procedure-Seite, Beispielparameter oder Markdownlink korrigieren.

Der gleiche Test läuft in GitHub Actions für relevante Pull Requests und Änderungen an `main`. Ein grüner statischer Test ersetzt weder die Runtime-Tests noch die manuelle fachliche und datenschutzbezogene Prüfung.

## 0.1 Automatisiertes synthetisches Linux-Target

Der Workflow `.github/workflows/sqlserver-2022-linux-release-gate.yml` führt für relevante T-SQL-Änderungen ein isoliertes Runtime-Gate gegen `mcr.microsoft.com/mssql/server:2022-latest` aus.

Dabei gilt:

- SQL Server 2022 Developer läuft nur für die Dauer des GitHub-Actions-Jobs in einem Container.
- Die Installationsdatenbank, das Kennwort und alle Laufzeitwerte werden erst im Job synthetisch erzeugt.
- Der Repositorybestand wird in ein temporäres Runnerverzeichnis kopiert; nur dort wird `[DeineDatenbank]` ersetzt.
- Der Container erhält die temporäre Codekopie schreibgeschützt.
- Installer und `Run_Release_Gate.sql` laufen mit `sqlcmd -b` und brechen beim ersten SQL-Fehler ab.
- Es werden keine SQLCMD-Ausgaben oder Resultsets als Artefakt gespeichert.
- Nach dem Lauf wird der Container auch bei Fehlern entfernt.

Dieses Target deckt SQL Server 2022 unter Linux mit Compatibility Level 160 und der case-sensitiven Collation `SQL_Latin1_General_CP1_CS_AS` ab. Es ersetzt keine Tests für Windows, SQL Server 2019, SQL Server 2025, optionale Features, reduzierte Berechtigungen oder produktionsnahe Lastzustände.

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

Für `USP_SpecialFeatureInventory` sind der vollständig sichtbare Leerzustand, eingeschränkte Metadatensichtbarkeit, die Ausgabegrenze und je ein positiver Fall für alle 18 Featurecodes getrennt vorgesehen. Eine Nullzählung gilt nicht als Abwesenheitsbeweis und `CONFIGURED_ONLY` nicht als Nutzungsnachweis.

Für `USP_InMemoryOltpAnalysis` müssen negativer Feature-Gate, schema-only Objekt, Tabellen-/Consumer-Speicher, Hashkatalog, kontrollierter Hashketten-Opt-in, Checkpointzustände, Transaktionsaggregate, benannter und Defaultpool, Quellberechtigungen, Filter und Ergebnisgrenzen getrennt dokumentiert werden. Hashketten nur gegen synthetische Testobjekte und unter kontrolliertem Lastbudget ausführen.

Für `USP_TemporalAnalysis` müssen negativer Feature-Gate, Current-/History-Zuordnung, sichtbare Periodenspalten, endliche und unendliche Retention, deaktivierter datenbankweiter Cleanup, approximative History-Größe/-Zeilen, Ratio-Grenze, vorhandene und fehlende Perioden-Indexbaseline, speicheroptimierte Current-Tabelle, Quellberechtigungen, Filter und Ergebnisgrenzen getrennt dokumentiert werden. Ein nach `SYSTEM_VERSIONING=OFF` getrenntes synthetisches Paar muss als bewusst nicht zuverlässig erkennbar bestätigt werden; keine echten Current- oder History-Zeilen als Evidenz speichern.

Für `USP_ServiceBrokerAnalysis` müssen negativer Feature-Gate, aktivierte Konfiguration ohne Objekte, deaktivierter Broker mit sichtbaren Objekten, Queue-Schalter, approximative Queue-Kapazität, Retention, interne Aktivierung, Transmission-Alter und gemeldeter Status, Conversation-Zustände und Lifetimes, isolierte Quellenberechtigungen, Filter und Ergebnisgrenzen getrennt dokumentiert werden. Der Contract-Test muss bestätigen, dass die Nachrichtenkörperspalte nicht referenziert und keine Queue- oder Conversation-Änderung ausgeführt wird. Testnachweise enthalten ausschließlich synthetische Zustände und niemals Queue-Nutzdaten.

Kostenintensive Pfade nur kontrolliert und opt-in testen:

- Page Details und Event-XML
- Contention-Sampling
- Buffer-Pool-Verteilung
- Schema-Design
- Statistikverteilung
- In-Memory-OLTP-Hashketten
- breite Cross-Database-Auswahl

## 5. Ergebnis zurückmelden

Für die Rückmeldung genügen je Target:

- synthetische `TargetId`
- getesteter Commit-SHA
- Exitcode der statischen Repositoryprüfung
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
