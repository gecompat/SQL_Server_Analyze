# Vertrag für das spätere Snapshot- und Baseline-Paket

Stand: 2026-07-20
Backlog: SC-023
Status: `DESIGN_APPROVED_IMPLEMENTATION_DEFERRED`

## Ziel und Paketgrenze

SC-023 ergänzt den zustandslosen Frameworkkern später um ein ausdrücklich installierbares Persistenzpaket. Pro SQL-Server-Instanz wird eine eigene Snapshot-Datenbank verwendet. Sie darf alle realen Laufzeitwerte speichern, die ein berechtigter Frameworkaufruf liefert: Messwerte, Namen, technische Identitäten, SQL- und Planinformationen, freie Texte, Fehlerkontext und versionierte Rohpayloads. Die Berechtigung zur Speicherung erweitert jedoch weder die Quellabfragen noch den Sicherheitskontext eines Sammlers; Secrets, Kennwörter oder Schlüsselmaterial werden nicht neu erhoben.

Die Beschränkung auf synthetische Daten gilt ausschließlich für Repository-, GitHub-, Test-, Dokumentations- und Downloadartefakte. Die betriebliche Snapshot-Datenbank ist kein Repositoryartefakt. Ein späterer anonymisierter Export ist ein eigenes Vorhaben und nicht Teil der ersten Implementierung.

Der bestehende Frameworkkern bleibt ohne installiertes SC-023-Paket zustandslos. Dieses Dokument genehmigt den Entwurf, erstellt aber noch keine Datenbank, Tabelle, Berechtigung oder SQL-Agent-Aufgabe.

## Konfigurationsmodell

Ein allgemeiner Key-Value-Speicher ist nicht der Primärvertrag. Bekannte, validierbare Einstellungen erhalten typisierte Spalten und Constraints. Erweiterbare Mengen werden als eigene Zeilen modelliert.

- Eine typisierte Frameworktabelle `monitor.SnapshotTargetConfiguration` beschreibt die aktive Zieldatenbank, Aktivierung, Schedulerart und paketweite Defaults. Der generische Defaultname lautet `SQL_Server_Analyze_History`, ist aber vollständig konfigurierbar.
- Die Zieldatenbank enthält `snapshot.CollectorPolicy` mit genau einer Richtlinie je Sammler: Aktivierung, Intervall, Modus, Scope-/Zeilenlimit, Payloadschalter und RetentionPolicy.
- `snapshot.RetentionPolicy` hält Aufbewahrung, Größenbudget, Purgeintervall, Batchgröße und Verhalten am Limit.
- Für neue, noch nicht vertraglich bekannte Optionen ist eine versionierte Erweiterungstabelle zulässig. Sie ersetzt keine bereits bekannte typisierte Einstellung.
- Datenbank- und Schemanamen werden vor dynamischer Verwendung validiert und mit `QUOTENAME` begrenzt. Es gibt keinen hart codierten Umgebungsnamen.

Die separate Datenbank je Instanz ist die lokale SC-023-Grenze. Instanzübergreifende Korrelation und zentraler Transport gehören zu SC-024.

## Datenmodell der Snapshot-Datenbank

Das Modell kombiniert normalisierte Zeitreihen mit verlustfreiem, versioniertem Payload. Weder reines EAV noch ausschließliches JSON genügt für alle Zwecke.

| Objekt | Verantwortung |
|---|---|
| `snapshot.CaptureRun` | Lauf-ID, Scheduler, Start/Ende in UTC, Vertragsversion, Reset-Epoche und Gesamtstatus |
| `snapshot.ModuleStatus` | Childstatus, Partialität, Auslassungs- und Fehlerkontext je Sammler |
| `snapshot.Scope` | Hierarchie und reale Identitäten für Server, Datenbank, Datei, Schema, Objekt, Index, Statistik, Session, Request, Query und Plan |
| `snapshot.MetricDefinition` | stabiler Metrikcode, Datentyp, Einheit, Aggregation und Vertragsversion |
| `snapshot.MetricSample` | typisierte numerische oder kategorische Werte mit Lauf, Scope und UTC-Zeitpunkt |
| `snapshot.PayloadSnapshot` | vollständige JSON-, Text-, XML-, SQL-, Plan-, Fehler- oder Pfadpayloads einschließlich Format- und Quellversion; bei Bedarf komprimiert |
| `snapshot.Rollup` | verdichtete, zeitfensterbezogene Werte mit Herkunft und Aggregationsart |
| `snapshot.PurgeRun` | begrenzte Löschläufe, Umfang, Grund, Ergebnis und Größenstatus ohne Payloadkopie |

Die Scopehierarchie reicht von Server und Datenbank bis zu Datei, Schema, Objekt, Index, Statistik, Session, Request, Query, Query Hash, Plan, Plan Hash und Plan Handle. Technische IDs werden, soweit verfügbar, mit Erfassungszeit, Erstellungszeit und Reset-Epoche kombiniert, damit eine spätere Wiederverwendung derselben numerischen ID nicht als dieselbe Entität gilt.

## Erfassung und Wiederverwendung

Ein schedulerneutraler Einstieg, konzeptionell `snapshot.USP_RunCollectionCycle`, führt einen Sammlungslauf aus. SQL Server Agent startet zunächst diesen Einstieg; ein externer Scheduler kann später denselben Vertrag aufrufen. Der Agentjob enthält keine fachliche Sammellogik und wird als separates idempotentes DDL-Paket geliefert.

Innerhalb eines Laufes wird eine Quelle nur einmal gelesen und das Ergebnis an alle abhängigen Sammler weitergereicht. Das gilt insbesondere für Plan Cache, Query Stats und andere teure oder zeitlich veränderliche Quellen. Ein eigenständig gestarteter Sammler liest stets frisch und übernimmt keine Daten eines früheren Laufes. Teilweise überlesene oder blockierte Teilmengen werden als unvollständig markiert; nur der fehlende Scope darf gezielt nachgelesen werden.

Pro Instanz läuft höchstens ein Collection Cycle gleichzeitig. Der Einstieg verwendet eine benannte Anwendungssperre ohne Wartezeit; ein Parallelaufruf endet kontrolliert als übersprungen. Steuerdaten werden konsistent gelesen. Für die Snapshot-Datenbank sind `READ_COMMITTED_SNAPSHOT ON` und Recovery Model `SIMPLE` sinnvolle, aber konfigurierbare Defaults. `NOLOCK`, `LOCK_TIMEOUT 0` und ein best-effort Zugriff auf Systemquellen folgen dem bestehenden Projektvertrag. `READPAST` ist kein pauschaler Default: Es ist nur bei Quellen zulässig, bei denen ausgelassene Zeilen fachlich erkennbar, als partiell dokumentiert und später gezielt nachlesbar sind.

## Granularität und Sammlerdefaults

Alle Werte bleiben je Sammler steuerbar. Die ersten Defaults sind:

| Sammlerklasse | Standardintervall | Standardumfang |
|---|---:|---|
| leichte Server- und Laufzeitmetriken | 30 Sekunden | vollständiger zulässiger Scope |
| Datenbank-, Datei-, Log-, TempDB- und Kapazitätsmetriken | 5 Minuten | alle sichtbaren Datenbanken |
| Query- und Planaggregate | 5 Minuten | Top 100 je konfigurierter Rangfolge |
| Konfiguration und Objektinventar | 1 Stunde | alle sichtbaren Objekte |

Der initiale Sammlerkatalog umfasst CPU/Performance Counter, Speicher/Buffer Pool, Waits mit Resetbezug, IO, TempDB, Log/Kapazität, Plan-Cache-Aggregate sowie Modulstatus und Partialität. Große SQL-, Text-, XML- und Planpayloads sind wegen Volumen und Laufzeit zunächst deaktiviert, aber vollständig unterstützt und je Sammler aktivierbar. Diese Voreinstellung ist keine Datenschutzmaskierung.

## Reset-, Zeit- und Qualitätsvertrag

- Alle Zeitpunkte werden in UTC gespeichert.
- Serverstart, Counterreset, Cache-Eviction, Quellversions- oder Schemawechsel beginnen eine neue Reset-Epoche.
- Deltas und Raten werden nie über Epochen hinweg berechnet.
- Ein fehlender Messwert ist nicht null und nicht gesund. Partialität bleibt in Sample, Rollup und Status erhalten.
- Rollups nennen Fenster, Quellgranularität und Aggregationsart; sie überschreiben keine Rohdaten.
- Neue Payload- oder Metrikverträge werden versioniert, alte Zeilen bleiben interpretierbar.

## Retention, Größe und Löschung

Sämtliche Werte sind in `snapshot.RetentionPolicy` steuerbar. Die Startdefaults lauten:

| Datenklasse | Default |
|---|---:|
| typisierte Rohmetriken | 14 Tage |
| große Payloads | 7 Tage |
| Rollups | 180 Tage |
| weiches Datenbankbudget | 10 GB |
| Purgeintervall | 1 Stunde |

Purge läuft in begrenzten Batches, protokolliert nur technische Summen und löscht zuerst regulär abgelaufene Daten. Das Defaultverhalten am weiterhin überschrittenen Budget lautet `PURGE_EXPIRED_THEN_STOP`: Nicht abgelaufene Daten werden nicht stillschweigend gelöscht; betroffene Sammler stoppen kontrolliert und melden ihren Status. Alternative Löschstrategien, Batchgröße und Grenzwerte sind explizit konfigurierbar.

Eine Deinstallation bewahrt die Snapshot-Datenbank und deren Inhalt standardmäßig. Purge oder Drop benötigen einen eigenen ausdrücklichen Betriebsaufruf. Export ist standardmäßig deaktiviert.

## Rechte, Betrieb und Exportgrenze

Das Paket erstellt keine Logins, Benutzer, Rollenmitgliedschaften oder Grants. Die Betriebsstelle konfiguriert einen dedizierten Ausführer und vergibt die dokumentierten minimalen Rechte auf Quelle und Snapshot-Datenbank. Datenbank-, Tabellen- und Agent-DDL werden ausschließlich im expliziten SC-023-Installationspfad angeboten.

Die Snapshot-Datenbank darf reale Laufzeitdaten vollständig enthalten und nach den Regeln der Zielumgebung gesichert oder betrieblich weiterverarbeitet werden. Ein Export in ein Repository, GitHub-Artefakt, Testfixture, Dokument oder Downloadpaket ist davon nicht erlaubt. Eine spätere Exportfunktion ist standardmäßig aus, benötigt ein ausdrückliches Ziel und erhält separat steuerbare Modi für vollständigen betrieblichen Export und anonymisierten externen Export. Die Anonymisierung ist nicht Teil der ersten Umsetzung.

## Umsetzungsreihenfolge

1. Paketvertrag, typisierte Zielkonfiguration und versioniertes Basisschema.
2. Ein leichter vertikaler Sammler einschließlich Lauf, Scope, Metrik und Partialstatus.
3. Retention, Größenbudget, begrenzter Purge und Deinstallationsvertrag.
4. Schedulerneutraler Einstieg sowie getrenntes SQL-Agent-DDL; externer Scheduler gegen denselben Einstieg.
5. Datenbank-, Objekt-, Query- und Plan-Cache-Sammler mit laufinterner Wiederverwendung.
6. Rollups und ein späterer, separat entschiedener Exportvertrag.

## Abnahmekriterien

- SQL Server 2019, 2022 und 2025 bestehen UTC-, Restart-, Reset-, Versions-, Partialitäts- und Schedulerverträglichkeitstests.
- Concurrency, Retention, Batch-Purge, Größenlimit und `PURGE_EXPIRED_THEN_STOP` werden mit synthetischen Fixtures geprüft.
- Agent und externer Scheduler erzeugen über denselben Einstieg denselben Laufvertrag.
- Ein vollständig synthetischer Payload mit sensibel wirkenden Feldklassen wird in der Zielstruktur verlustfrei gespeichert; damit wird die fehlende Runtime-Maskierung bewiesen, ohne reale Daten ins Repository zu übernehmen.
- Repository- und Liefergates blockieren weiterhin markierte reale Artefaktdaten. Alle eingecheckten Fixtures bleiben eindeutig synthetisch.
- Ein partieller oder übersprungener Read erzeugt weder einen scheinbar vollständigen Trend noch einen erfundenen Nullwert.
- Kein Installations- oder Laufpfad vergibt Rechte oder löscht bei Deinstallation automatisch Historie.

## Nächster Schritt

Der Architekturentscheid ist freigegeben und für eine spätere Umsetzung dokumentiert. Die Implementierung beginnt erst mit einem eigenen Auftrag und startet mit der kleinen vertikalen Umsetzung aus den Schritten 1 und 2; SC-023 bleibt bis dahin fachlich entschieden, aber technisch unimplementiert.
