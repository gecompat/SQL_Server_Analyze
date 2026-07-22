# Externer Restore- und Hostnachweis

Stand: 2026-07-18  
Backlog: SC-025  
Status: `RUNBOOK_READY_EXTERNAL_EXECUTION_REQUIRED`

## Ziel

Dieser Runbook beschreibt den Nachweis, den ein read-only T-SQL-Diagnoseframework nicht selbst erbringen kann: Backup tatsächlich auf ein autorisiertes isoliertes Ziel restoren, Integrität dort prüfen und Betriebssystem-, Storage- und Netzwerkbeobachtungen getrennt belegen.

Das Repository enthält weder Backup, Schlüssel, Pfade, Endpunkte, Hostnamen, Konten, interne Strukturen noch Resultsets. Vor dem Eintragen irgendeines Laufzeitergebnisses in eine Datei oder Git-Operation muss der Benutzer den bereits bereinigten Inhalt ausdrücklich bestätigen.

## Voraussetzungen

1. schriftlich autorisiertes, isoliertes und löschbares Ziel;
2. freigegebene Backupkopie und gesondert geschütztes Schlüsselmaterial;
3. minimale administrative Rechte und benannter Ausführungsverantwortlicher außerhalb des Repositorys;
4. definiertes Zeit-, Speicher- und Abbruchbudget;
5. definierter sicherer Ort für Rohlogs, der nicht dieses Repository ist;
6. bestätigter Lösch- und Nachweisprozess.

## Ablauf

1. Zielisolation, freie Kapazität und Version/Edition prüfen.
2. Backup und erforderliches Schlüsselmaterial über den autorisierten Kanal bereitstellen.
3. Restore unter einem ausschließlich für diesen Lauf erzeugten synthetischen Zielnamen durchführen.
4. Restorefehler im geschützten Betriebslog behandeln; keine Rohmeldung in Git oder Downloads übernehmen.
5. `DBCC CHECKDB` auf dem isolierten Restoreziel nach freigegebenem Betriebsverfahren ausführen.
6. Anwendungsspezifische Start-/Lesetests nur mit synthetischen Eingaben und ohne externe Seiteneffekte ausführen.
7. Host-/Storage-/Netzwerkmetriken mit den jeweiligen Plattformwerkzeugen separat erfassen; SQL-Metadaten nicht als Ersatz darstellen.
8. Restoreziel, temporäre Credentials, bereitgestelltes Schlüsselmaterial und Arbeitskopien nach dem freigegebenen Verfahren entfernen.
9. Nur die generische Evidenzzeile aus `External_Evidence_Gates.csv` ausfüllen; vor Datei- oder Git-Schreibzugriff Datenschutzrückfrage durchführen.

## PASS-Kriterien

- Restore beendet sich erfolgreich.
- CHECKDB beendet sich entsprechend dem vorab definierten Integritätskriterium.
- synthetische Anwendungskontrolle erfüllt ihren festgelegten Erwartungswert.
- Host-, Storage- und Netzbeobachtung wurden durch zuständige externe Werkzeuge erhoben.
- Cleanup ist bestätigt.
- Der veröffentlichbare Nachweis enthält ausschließlich generische Statuscodes, UTC-Zeitpunkte, Commit-ID und synthetische Target-ID.

## Abbruchkriterien

Unklare Autorisierung, produktives Ziel, fehlendes Größenbudget, unklarer Schlüsselweg, mögliche externe Seiteneffekte, gefundene sensible Daten oder nicht bestätigter bereinigter Dateinhalt. Bei jedem dieser Punkte wird nicht fortgefahren.
