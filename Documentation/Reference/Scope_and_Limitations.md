# Scope und Grenzen des Frameworks

**Stand:** 25. Juli 2026

Dieses Dokument fasst zusammen, was SQL Server Analyze **tut** und was es
**ausdrücklich nicht tut**. Die modulspezifischen Aussagegrenzen stehen
zusätzlich in den jeweiligen Procedure-Headern und in
[Special_Case_Modules.md](../Architecture/Special_Case_Modules.md).

## Was das Framework tut

- Lesende, zustandslose Diagnose auf SQL Server 2019, 2022 und 2025.
- Analyse laufender Sessions, Requests, Blocking, Waits, Memory, TempDB und I/O.
- Objekt-, Index-, Statistik-, Partitions- und Columnstore-Kataloganalyse.
- Plan Cache, Query Store, Ausführungsplananalyse.
- Extended Events: Session-Inventar, Deadlocks, Blocked Process.
- Infrastruktur: SQL Agent, Resource Governor, HA/DR, Backup, Log Shipping.
- Server Health: CPU, NUMA, Memory, TempDB, Konfiguration, Sicherheit.
- Spezialfeatures: In-Memory OLTP, Temporal Tables, Service Broker, Full-Text, CDC, Encryption, CLR, External Runtime.
- Normalisierte diagnostische Findings mit Priorität und Konfidenz.
- Versionsadaptive Capability-Erkennung und Feature-Inventar.
- Optionales Snapshot-/Baseline-Paket für Verlaufsvergleiche.

## Was das Framework NICHT tut

### Diagnosekern, Installation und optionales Paket

Die Ausschlüsse der folgenden Tabelle gelten für fachliche Diagnoseaktionen
gegen die untersuchten Systeme. Der Diagnosekern verändert keine analysierten
Anwendungsdaten oder deren Konfiguration. Er materialisiert jedoch lokale
Arbeitstabellen; die Ausgabeart TABLE kann leere lokale Zieltabellen des
Aufrufers anpassen und Ergebnisse darin ergänzen.

Die einmalige Installation und das Gesamtdeployment erstellen oder migrieren
Frameworkobjekte. Das optionale Snapshotpaket schreibt nach expliziter
Zielbindung eigene Evidenz und entfernt abgelaufene eigene Evidenz nach seiner
Retentionpolicy. Diese Operationen gehören nicht zum lesenden Diagnosekern.

| Aktion | Ausschluss |
|---|---|
| `KILL` | Keine Session wird beendet. |
| Index CREATE/DROP/REBUILD | Keine Indexoperationen. |
| Statistikupdate | Keine Statistikänderungen. |
| Plan Forcing | Kein automatisches Forcieren. |
| Konfiguration ändern | Kein `sp_configure`, kein `ALTER DATABASE`. |
| Failover | Kein AG-Failover oder Restart. |
| Repair | Kein `DBCC CHECKDB ... REPAIR`. |
| DDL | Die Diagnosepfade ändern keine Anwendungsobjekte. Installation und Deployment verwenden `[monitor]`, das optionale Zielpaket auch `[snapshot]`; TABLE kann lokale `#Temp`-Tabellen anpassen. |
| Berechtigungen | Keine GRANTs, keine Loginverwaltung. |
| Cleanup/Purge | Keine Löschung analysierter Anwendungsdaten, Logs oder Backups. Das optionale Paket löscht ausschließlich eigene abgelaufene Snapshotdaten. |

Der Corebestand umfasst 158 Objekte, das optionale Paket weitere 19.
`Install_All.sql` installiert ausschließlich den Core. Das Gesamtdeployment
kann das Paket ausdrücklich einschließen. Voraussetzungen, Archivierung und
Transaktionsverhalten stehen in der [Deploymentreferenz](Deployment.md);
Sammlung und Purge im [Snapshotvertrag](../Architecture/Snapshot_Baseline_Package_Contract.md).

### Keine automatischen Urteile

- Ein Finding ist **kein Handlungsauftrag**. `CRITICAL` erfordert manuelle Prüfung.
- `HIGH` Confidence bezieht sich auf die technische Beobachtung, nicht auf die Ursache.
- Kein Modul empfiehlt eine konkrete Lösung ohne zweite Evidenzquelle.
- Schwellenwerte sind statistische Auffälligkeiten, keine Sollwerte.

### Keine externen Zugriffe

- Kein Netzwerkzugriff, kein Internet, kein Dateisystemschreiben.
- Keine Credentials, Secrets oder gespeicherte Passwörter.
- Keine Verbindung zu anderen SQL-Server-Instanzen.
- Keine Cloud-APIs, Azure-Metriken oder externe Monitoring-Systeme.

### Keine Datensicht auf geschützte Inhalte

- Keine Tabellenzeilen, Geschäftsdaten oder Payload-Werte.
- Keine Nachrichteninhalte (Service Broker).
- Keine indizierten Dokumente (Full-Text).
- Keine Schlüssel, Secrets oder Zertifikat-Privatekeys.
- Keine Change-Data-Zeilen (CDC/CT).
- Keine Assembly-Binärdaten.
- Keine Script-Parameter oder Runtime-Inhalte (External Runtime).

Diese Grenzen schließen sensible Inhalte in SQL-Text, Input Buffer,
Plan-XML oder Event-Payload nicht aus. Solche Diagnoseoptionen können
Literale und Anwendungskontext offenlegen; der
[Parameterleitfaden](../Analysis_Guides/Parameter_Reading_Guide.md) beschreibt
die erforderliche Prüfung vor Export oder Weitergabe.

### Keine Vollständigkeitsgarantie

| Aspekt | Grenze |
|---|---|
| Live-DMVs | Momentaufnahme; kann Millisekunden später veraltet sein. |
| Kumulative Zähler | Seit letztem Reset (Restart, DB-Online, Cache-Eviction). |
| Query Store | Nur innerhalb von Retention und aktiviertem Capture. |
| Extended Events | Nur laufende Sessions und vorhandene Targets. |
| Errorlog | Nur sichtbare und nicht überschriebene Logeinträge. |
| Backup-Historie | msdb-Einträge beweisen keinen erfolgreichen Restore. |
| Statistik-Histogramme | Stichprobe, keine exakte Vollverteilung. |
| Fragmentierung | Bei unter 1000 Seiten nicht aussagekräftig. |

### Keine Plattformabdeckung

- Kein Azure SQL Database (PaaS) – nur SQL Server on-premises/VM/Container.
- Kein Azure SQL Managed Instance (Teilkompatibilität möglich, nicht getestet).
- Kein Monitoring-Agent, kein Hintergrunddienst, kein Scheduler.
- Kein grafisches Dashboard – rein T-SQL-basierte Resultsets.

### Keine Performance-Garantie

- Das Framework erzeugt selbst Last (Reads, CPU) bei der Analyse.
- Breite Scans (`CATALOG_DEEP`, `PHYSICAL_STATS_DEEP`) können auf großen Systemen sekunden- bis minutenlang laufen.
- `@HighImpactConfirmed = 1` ist erforderlich für teure Pfade.
- Concurrent Sessions sehen Frameworkqueries in DMVs (filtert sich per Default selbst).

## Modulübergreifende Prinzipien

1. **Erst Status lesen** – `StatusCode`, `IsPartial` und Warnungen vor Fachdaten.
2. **Nenner suchen** – Prozent- und Durchschnittswerte ohne Bezugsgröße sind wertlos.
3. **Gegenprobe ausführen** – `NextProcedureName` im Navigator zeigt die zweite Quelle.
4. **Scope begrenzen** – Klein anfangen, nur bei Bedarf erweitern.
5. **Nie unmittelbar verändern** – Kein einzelner Befund rechtfertigt eine Aktion.

## Weiterführend

- [Hier beginnen](../Analysis_Guides/Start_Here.md)
- [Einsteiger-Leseleitfaden](../Analysis_Guides/Beginner_Reading_Guide.md)
- [Spezialfallmodule: Evidenz und Kosten](../Architecture/Special_Case_Modules.md)
- [Performance- und Risikobewertung](../Quality/Performance_and_Risk_Assessment.md)
- [Bekannte Einschränkungen](../Quality/Known_Issues.md)
