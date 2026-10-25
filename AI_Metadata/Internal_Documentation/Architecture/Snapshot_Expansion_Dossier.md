# Ausbau der lokalen Snapshot- und Baseline-Erfassung

**Stand:** 25. Oktober 2026.
**Status:** Schema-2-Vorbereitung über PR #447 integriert; Head-, Main- und native Risikoabnahme bestehen. Der konkrete Wait-Kontextvertrag ist unabhängig geprüft. Der Wait-Collector ist noch nicht implementiert.
**Artefakt-UID:** `urn:uuid:01a17312-4ac5-78b9-b77d-536e996e2817`.
**Registrierung:** `DEFERRED`; keine neue finale lesbare Kennung vergeben.
**Bestehende Zuordnung:** SC-023-EXPANSION, Rang 10 der
[Entwicklungswellen](../Quality/Development_Waves_2026-10.md).

## Ausgangslage und nächster Nutzen

Das [optionale Snapshotpaket](../../../Documentation/Architecture/Snapshot_Baseline_Package_Contract.md)
persistiert derzeit ausschließlich Performance-Counter-Evidenz. Configure,
Collection Cycle, Retention, Budgetreaktion, Scopeidentitäten, typisierte
Metriken und Modulstatus sind vorhanden. Wait-/Datei-I/O-Zeitreihen sind
keine bereits ausgelieferte Funktion dieses Pakets.

Die erste Ausbauwelle soll instanzweite Wait-Counter über getrennte lokale
Collection Cycles vergleichen können. Danach folgt Datei-I/O mit eigener
Datenbank-/Dateiidentität. Kapazität, Ressourcendruck, Rollups, Scheduler und
Exporte sind nachfolgende getrennte Schritte. Der Frameworkkern bleibt
zustandslos; neue persistente Daten liegen ausschließlich im ausdrücklich
installierten eigenen Snapshotziel.

Die separate SSIS-Arbeit umfasst aktuell Datenflusskorrelation. Diese Welle
übernimmt weder deren Parser-/Lineagearbeit noch deren erhaltene SSISDB.
Der nächste unabhängige Gesamtauftrag kann Rang 10 bearbeiten, während die
SSIS-Zuständigkeit und ein freier Vergleichsscope weiter abgeglichen werden.
Die gelieferten Sicherheitsbausteine und der erste Endpoint-Slice werden
dabei nicht erneut implementiert.

## Quellen und vorhandene Wiederverwendung

Die nativen Grundquellen sind sys.dm_os_wait_stats und
sys.dm_io_virtual_file_stats. sys.dm_os_sys_info liefert den Engine-Startkontext;
Datenbank- und Dateikataloge liefern getrennte Identitätsbelege. SQL2019
benötigt für die beiden Counterquellen VIEW SERVER STATE, SQL2022+ VIEW SERVER
PERFORMANCE STATE. Sichtbarkeit, Identitätsquellen und Zielschreibrechte
bleiben getrennte Quellen-/Berechtigungsgrenzen.

CurrentWaits besitzt bereits kumulative Instanzwerte und ein begrenztes
lokales Sampling. Seine aktive Tasksicht, SQLtexte, Filter, Benign-Auswahl
und Top-Prozentdarstellung sind jedoch kein vollständiger Persistenzvertrag.
CurrentIO besitzt bereits Datenbankauswahl, native Datei-Caches und lokale
Delta-/Pending-Diagnostik. Die Erweiterung prüft deren wiederverwendbare
Quellen- und Identitätslogik, übernimmt aber keine gefilterte oder gekappte
Darstellung als vollständigen Basiswert. Eine zusätzliche öffentliche
Liveanalyse wird durch diesen Scope nicht begründet.

Die bestehenden Snapshothelper sind derzeit fest an PERFORMANCE_COUNTERS
gebunden. Vor einer Implementierung werden Prepare, Complete, Finalize,
Policy, Installer, Versionsprüfung und Purge gemeinsam angepasst. Ein
zusätzlicher Seed allein aktiviert keinen nutzbaren Collector.

## Reset- und Zeitgrenzen

Microsoft dokumentiert Wait-Counter kumulativ seit Engine-Start oder letztem
Reset. DBCC SQLPERF kann sie ohne Engine-Neustart zurücksetzen. Gleicher
sqlserver_start_time-Wert und monotone Counterschnappschüsse beweisen daher
keine lückenlose Kontinuität: Ein unbeobachteter Reset kann vor der zweiten
Aufnahme durch erneute Zunahme verdeckt werden.

Der Vertrag muss diese Beobachtungsgrenze erhalten. Rohwerte, beobachtete
Differenz und nachgewiesene Kontinuität sind getrennte Aussagen. Ein
monotoner Differenzkandidat darf nur mit ausdrücklich sichtbarer unbewiesener
Resetkontinuität ausgegeben werden; er erhält keinen vorbehaltlosen VALID-
oder Gesundheitsstatus. Reset-sicher bedeutet hier, dass erkannte oder
unbekannte Grenzen nicht als nachgewiesene durchgehende Messung ausgegeben
werden. Die zusätzliche externe Resetkontinuität wird nicht erfunden.

Ein erkannter Neustart, Counterrückgang, fehlender notwendiger Vorwert,
Quellenfehler, Teilaufnahme, Ausgabelimit oder inkompatibler Vertrag verhindert
einen als vergleichbar ausgewiesenen Wert. Eine erkannte globale
Wait-Counterrücksetzung betrifft den gesamten Wait-Aufnahmebereich, nicht
nur den zufällig rückläufigen Waittyp. Fehlende Werte werden nicht als Null
ersetzt. Eine dokumentierte Nullunterdrückung benötigt einen eigenen
Vollständigkeitsbeleg; der erste Slice darf stattdessen FIRST_OBSERVATION
mit unbekannter Differenz liefern.

waiting_tasks_count zählt begonnene Waits, während die DMV abgeschlossene
Waitzeit beschreibt. Wartezeiten über Threads können sich überlappen;
eine Summe ist keine vergangene Wandzeit. max_wait_time_ms ist ein Maximum
und keine additive kumulative Metrik. Eine Differenz von Maxima oder eine
unbelegte durchschnittliche Dauer eines identischen Ereignissatzes wird
nicht als neue Metrik eingeführt.

UTC-Grenzen bezeichnen tatsächliche Aufnahmezeitpunkte. Der native
sqlserver_start_time-Kontext wird als native Engineidentität behandelt und
nicht ohne Zeitzonenbeleg in einen UTC-Zeitpunkt umbenannt. Der vorhandene
Performance-Counter-Adapter schreibt diesen nativen JSON-Kontext derzeit
in SqlServerStartTimeUtc; der neue Collector darf diese Benennung nicht
ungeprüft als UTC-Nachweis übernehmen. Eine nötige kompatible Korrektur wird
vor dem Produktvertrag samt Migration und bestehendem Consumerumfang
festgelegt. Fehlender Startkontext darf keine gemeinsame geratene Epoche
erzeugen.

## Vorgeschlagene erste vertikale Lieferung

Der erste Produktschritt erweitert bestehende Konfigurations- und
Collection-Einstiege um einen ausdrücklich gewählten WAIT_STATS-Collector.
Der bisherige PERFORMANCE_COUNTERS-Pfad bleibt der Default. Pro Aufruf wird
genau ein ausgewählter Collector mit einem CaptureRun verarbeitet; der
skalare CaptureRunIdOut erhält dadurch keine mehrdeutige Bedeutung.
Die genaue additive Parametrierung und Paketversion werden vor dem Code
im typisierten Vorvertrag unabhängig geprüft.

Waittypen bilden lokale technische Scopes. Rohwerte werden als BIGINT mit
festen Metrikcodes, Einheiten, ContractVersion, ResetEpochId und QualityCode
persistiert. SQLtexte, Session-/Clientidentitäten und Nutzdaten gehören nicht
zum neuen Collector. Die Aufnahme liest die native Quelle vor jeder fachlichen
Kappung. MaxRows und Softbudget begrenzen echte Zielwrites; eine dadurch
partielle Aufnahme begründet keinen vollständigen Vergleich. Nur neu
aktivierte eigene Policies starten den neuen Pfad. Payload bleibt standardmäßig
aus und ein vorhandenes Target erhält keine implizite neue Sammlung.

Die Ableitung benötigt zwei vollständig gebundene erfolgreiche Aufnahmen.
Vorherige Werte werden nach Collector, Scope, Metrik, Einheit, Vertrag und
Epoche ausgewählt; parallele oder ältere ungeeignete Läufe werden nicht
still als Vorwert gewählt. Ein UTC-Intervall muss positiv und eindeutig sein.
Die erste Lieferung spezifiziert ausdrücklich, wo nur ein monotoner
Differenzkandidat mit unbekannter Resetkontinuität vorliegt und wo Werte
unterdrückt werden. Ein erfolgreich gespeicherter Rohwert ist kein Beweis
eines qualifizierten Deltas.

## Getrennte Datei-I/O-Fortsetzung

Datei-I/O folgt nach dem Wait-Slice mit dem festen Datenbankauswahlvertrag:
alle sichtbaren zugänglichen ONLINE-Benutzerdatenbanken, optionale
bracket-aware Pipe-Namen und getrenntes Pattern, Systemdatenbanken opt-in;
kein CURRENT-Default oder MaxDatenbanken. Eine native Aufnahme erfolgt
höchstens einmal pro Messzeitpunkt; Pending-I/O, physische Pfade und
zusätzliche Hostproben bleiben außerhalb dieser Persistenzwelle.

Datenbank-ID und Datei-ID allein sind keine dauerhafte Objektidentität.
Neuanlage, Wiederverwendung, Restore, Dateiwechsel, fehlende GUIDs und
geänderte Handles müssen vor Implementierung als eigene Abnahmefälle
festgelegt werden. sample_ms beschreibt Hostuptime und ist kein UTC-
Zeitstempel. size_on_disk_bytes ist ein Gauge; Read-/Write-/Byte-/Stallcounter
besitzen andere Einheiten und dürfen nicht als gleichartige Werte aggregiert
werden. Dateiname oder Laufwerksbuchstabe beweisen keine stabile Identität.

## Migration, Betrieb und Grenzen

Die Erweiterung bleibt optional, lokal und schedulerneutral. Sie erzeugt
keine Datenbank, fremden Benutzer, Rechte oder Agentjobs. Entwicklungstests
installieren und verändern ausschließlich gebundene eigene Labziele.
Versionierte Tabellen, Constraints, Seeds, Properties, Target-/Framework-
Installer und der Gesamtdeploymentweg müssen denselben Stand erkennen.
Unbekannte oder inkompatible Ziele werden vor Fachwrites abgelehnt.

Eine erforderliche Migration bewahrt vorhandene Counterdaten, eigene
Policies und Fremdobjekte. Wiederholung muss idempotent sein; eine fehlende
Spalte oder ein fehlender neuer Helper darf keine halbe Aktivierung erlauben.
Retention bleibt child-first und begrenzt; neue Metriken, Scopes und optionale
Payloads erhalten denselben Lösch- und Budgetpfad. Ein aktiver Run, ein
Purgefehler oder ein fehlgeschlagener Collector darf einen älteren Erfolg
nicht zu einer scheinbar vollständigen neuen Messung machen.

Die Snapshotdatenbank speichert echte Laufzeitwerte innerhalb ihres bestehenden
Datenschutz-, Zugriffs-, Backup- und Löschvertrags. Repositoryartefakte und
Beispiele bleiben synthetisch. Vorhandene Nutzerdaten werden weder exportiert
noch in Entwicklungsartefakte kopiert. Die Erweiterung führt keine automatische
Anonymisierung oder externe Übertragung ein.

## Abnahme und noch festzulegender Feldvertrag

Vor Implementierung werden öffentliche Parameter, Resultsets und JSON-Version,
Paket-/Schemaversion, Collectorcodes, Metrikcodes, ValueType, Unit, QualityCode,
Epochenbildung, Vorwertauswahl und atomare Schreibgrenzen vollständig festgelegt.
Dies ist der nächste konkrete Vertragsabschluss; diese Konzeptseite ist noch
kein eingefrorener öffentlicher API- oder Migrationsvertrag.

Unabhängige typisierte Sollwerte prüfen mindestens frische Installation und
Upgrade mit erhaltenen Performance-Counter-Samples, Default-Opt-out,
explizite Aktivierung, Wiederholung, aktuelle und veraltete Zielversion,
fehlende Rechte, partielle Quelle, native Leerquelle, Writecap, Softbudget,
Retention, parallele Collection und fehlgeschlagene Finalisierung. Zeit-,
Scope-, Einheiten- und Vertragswechsel sowie Reset, fehlender Vorwert,
monotoner Kandidat und verdeckter Reset brauchen getrennte Oracles.
Ein synthetischer Projektionsfall wird nicht als vollständiger nativer
Reset-Fault durch die ganze SUT ausgegeben.

Die primäre Engine ist SQL2025. Zusätzliche native Versionen werden nur am
konkreten Engine-/Berechtigungs-/Schemaschnitt gemäß
[CI-Teststrategie](../../../Documentation/Quality/CI_Test_Strategy.md)
geprüft. Ein Restartszenario oder DBCC-Reset darf ausschließlich eine eigene
isolierte Testinstanz betreffen. Unveränderte bestehende erfolgreiche Gates
werden nicht wegen eines Timers erneut ausgeführt. Ein neuer Collector mit
fehlender nativer Qualifikation bleibt als Teillieferung sichtbar.

## Wait-Spezifikationsentwurf und vorgeschalteter Schema-Vorvertrag

Konzeptreview und Review des vorgeschalteten Migrationsvertrags bestehen.
Die nachfolgende Collectorauswahl bleibt ein Entwurf und ist noch kein
gelieferter Collector. Die vorgeschaltete PackageVersion 1.1.0 führt SchemaVersion 2 ein, ohne
neue persistente Spalte oder Tabelle. Sie erweitert ausschließlich zwei
bekannte CHECK-Domänen und liefert noch keinen Wait-Collector. Der spätere
Collector wird als PackageVersion 1.2.0 mit SchemaVersion 2 konkretisiert. Neue Prozeduren und Seeds sind eine ausdrückliche Installation;
Configure führt kein implizites Upgrade aus. Ein unbekannter Versions- oder
Strukturstand wird vor Änderungen abgelehnt.

### Vorgeschaltete Schemawelle und exakte Altzustände

Die erste Produktwelle dieser Erweiterung implementiert ausschließlich die
Schema- und Deploymentvorbereitung. Der bestehende Performance-Counter-Pfad,
seine öffentlichen Parameter, MetricDefinition-Seeds und CollectorPolicy-
Werte bleiben erhalten. WAIT_STATS-Policy, Waitmetriken und neue Collector-
Helper werden erst mit der nachfolgenden Collectorlieferung installiert.
Die Typisierung von WAIT_CAPTURE_CONTEXT wird im folgenden eigenständigen
Feldvertrag konkretisiert. Diese vorgeschaltete Welle lieferte ausschließlich
die Schema- und Installationsvorbereitung, keinen Collector.

Die Migration akzeptiert ausschließlich diese bekannten Zustände:

| Paket-/Schemastand | CollectorPolicy-Domäne | Scope-Domäne | Aktion |
|---|---|---|---|
| keine Snapshotobjekte | keine | keine | Frische Installation als 1.1.0 / Schema 2. |
| 1.0.0 / Schema 1 | PERFORMANCE_COUNTERS | SERVER und PERFORMANCE_COUNTER | Datenbewahrende Erweiterung beider bekannten CHECKs. |
| 1.1.0 / Schema 2 | PERFORMANCE_COUNTERS und WAIT_STATS | SERVER, PERFORMANCE_COUNTER und WAIT_TYPE | Idempotente Wiederholung ohne Policy- oder Sampleänderung. |
| anderer, gemischter oder unbekannter Stand | beliebig | beliebig | Ablehnung vor der Migration. |

Die beiden bekannten Constraints heißen
CK_snapshot_CollectorPolicy_CollectorCode und CK_snapshot_Scope_ScopeType.
Beide müssen aktiviert, vertrauenswürdig und nicht NOT FOR REPLICATION sein.
Die genaue semantische Definitionsmenge wird anhand nativer Referenztabellen
verglichen; beliebige zusätzliche Tokens, Werte oder weitere CHECKs werden
nicht als zulässiger Altzustand umgedeutet. Name, Spaltenfacetten, Schlüssel,
Defaults und bestehende übrige Constraints müssen zum bekannten V1- oder
V2-Modell passen. Ein bloß passender Versionswert genügt nicht.

Nur für den vollständig erkannten V1-Zustand werden diese zwei CHECKs in
derselben geschützten Transaktion wie der vollständige Preflight ersetzt
und mit WITH CHECK validiert. Die vorhandenen TABLOCKX-/HOLDLOCK-Sperren
bleiben bis zum Transaktionsende erhalten; zwischen Prüfung und Änderung
wird keine ungeschützte Lücke zugelassen.
Anschließend wird die Paketversion atomar auf 1.1.0 / Schema 2 gesetzt.
Bestehende Samples, Scopes, Collector-/Retentionwerte und fremde Objekte
werden nicht gelöscht oder umgeschrieben. Unbekannte oder widersprüchliche
Struktur führt vor DDL/DML zur Ablehnung; die Migration versucht keine
Reparatur unbekannter Nutzeränderungen. Der Vertragsreview verlangt
gemeinsame Transaktionsbindung und Abbruch über alle Standalone-Batches.
Die konkrete Implementierung wird vor Integration unabhängig geprüft.

Der generierte Gesamtdeploymentweg erkennt zusätzlich zum exakten aktuellen
Modell genau das freigegebene V1-Modell mit diesen beiden abweichenden
Domänen und passender 1.0.0-/Schema-1-Metadatenzeile. Alle anderen Abweichungen
bleiben unzulässig. Die generische Zustandsprüfung wird nicht global gelockert.
Der SQLCMD-Master behält ON ERROR EXIT. Der erzeugte Target-Standaloneweg
muss über Batchgrenzen fail-closed sein: Die kanonischen Batches werden in
einem gemeinsamen bewachten Ausführungsrahmen mit getrennten notwendigen
Kompilationsebenen ausgeführt. Der erste Fehler beendet diesen Rahmen vor
jeder nachfolgenden Quelle. Er verlangt vor eigenen Transaktionsänderungen
TRANCOUNT=0 und IMPLICIT_TRANSACTIONS OFF; eine Callertransaktion wird weder
übernommen noch abgeschlossen. Eine abgelehnte Datenbank muss einschließlich
vorhandener Helperdefinitionen und SET-Metadaten unverändert bleiben. Die
Negativabnahme prüft genau diesen Standaloneweg und nicht nur SQLCMD oder
Gesamtdeployment. Die konkrete Builderumsetzung wird mit dem Produktdiff
geprüft; bloßes Entfernen von ON ERROR EXIT mit anschließender GO-Verkettung
ist für Schema 2 unzulässig.

Die Target-Quelle und der generierte Weg müssen dieselbe bekannte Migration
anwenden. Der direkte Targetweg erhält einen read-only Prüfblock, der aus
dem kanonischen Tabellenmodell und genau dieser Legacy-Auswahl generiert
wird; die erwarteten Spalten-/Schlüssel-/CHECK-Definitionen werden nicht als
zweiter handgepflegter Vertrag geführt. Der Prüfblock wird in einem eindeutig
markierten Bereich der kanonischen Targetquelle gespeichert und durch den
Builder deterministisch auf Synchronität geprüft. Sein Erzeugungshash schließt
diesen Bereich selbst aus. Eine veraltete oder veränderte generierte Prüfung
führt vor Artefakterzeugung zu Ablehnung.

Der Gesamtdeployment-Builder führt bereits seine entsprechende vollständige
Prüfung aus. Er entfernt deshalb ausschließlich diesen exakt erkannten
read-only Bereich aus seinem erzeugten Sourcebatch. Diese statische
Transformation wird im Builder geprüft; es gibt keinen zur Laufzeit durch
einen Caller fälschbaren Skip-Schalter. Die eigentliche Migration bleibt
in beiden Wegen derselbe kanonische Code. Datenbankkontextprüfung und
kritische V1-/V2-Migrationsbedingungen werden nicht entfernt. Pro Route
bleibt genau eine vollständige Strukturvorprüfung; die vorgeschriebene
strikte Nachprüfung des Gesamtdeployments bleibt zusätzlich erhalten. Eine halb erkannte Kombination aus V1- und V2-Domänen gilt nicht
als erfolgreiche frühere Installation.

Abnahme umfasst frische Installation, V1-Upgrade mit eigenen zuvor gespeicherten
Counterwerten und Policies, exakte Wiederholung, Rollback nach einem
kontrollierten Fehler sowie unveränderte fremde Objekte. Negative Kontrollen
prüfen unbekannte Version, zusätzliche Domänenwerte, fehlende beziehungsweise
nicht vertrauenswürdige oder deaktivierte Constraints, weitere CHECKs,
veränderte Spalten und gemischte V1-/V2-Domänen. Unveränderte vollständige
Werte und Struktur werden vor und nach einer abgelehnten Migration verglichen.
Diese Welle behauptet keine Wait-Quelle, Differenz, Reset- oder Collectorabnahme.

Der direkte Targetweg eröffnet bei eigenem Aufruf ohne Ambienttransaktion
eine eigene Transaktion vor dem vollständigen Preflight und beendet sie
erst nach Migration und Versionsabschluss. Innerhalb des generierten Deployments verwendet sie eine lokale
Savepointgrenze und übernimmt weder Commit noch Rollback einer äußeren
Callertransaktion. Bei einem nativen nicht mehr committable äußeren Zustand
wird dieser Fehler weitergegeben; eine pauschale Erhaltungsgarantie nach
jedem DDL-/Enginefehler wird nicht behauptet. Der generierte Installer behält
seinen vorhandenen eigenen vollständigen Rollbackweg.

Die Fehlerabnahme benötigt eine nativ bestätigte eigene Sch-S-only-Sperre
auf Scope, die den TABLOCKX-Preflight zulässt und erst den Sch-M-Zugriff des
zweiten ALTER blockiert. Die Sperrart, ihre eigene Session und der tatsächlich
abgeschlossene erste DDL-Schritt werden beobachtet. Ein vorab gehaltener
Daten-S-Lock genügt nicht, weil bereits der Preflight darauf warten würde.
Der native Fehlerabschluss muss beide CHECKs und die Paketzeile vollständig
zurücknehmen. Der Sperrmechanismus erhält zunächst eine getrennte gebundene
Probe. Ohne diesen Nachweis bleibt die Fehlerabnahme offen; ein kopierter
Projektionsblock oder ein nur behaupteter Zwischenfehler genügt nicht.
Die Wiederholung darf die vorgesehenen Installerzeitmetadaten aktualisieren,
verändert aber keine Sample-, Scope-, Collector- oder Retentionwerte.

Für den gezielten älteren Snapshotnachweis wird der vorhandene manuelle
Native-Matrixworkflow um ein ausdrücklich gewähltes Snapshot-Risikogate
für die einzelne angeforderte Engine erweitert. Bestehende Defaults und
Release-Candidate-Matrizen bleiben erhalten. Der normale zusätzliche
SQL2025-Snapshotlauf wird nicht doppelt ausgeführt. Die geänderte Workflow-
auswahl erhält eigene deterministische Negativ-/Auswahlprüfungen; der
zentrale Installer verlangt weiterhin das volle SQL2025-Gate.

Der nachfolgende Collectorentwurf ist noch nicht freigegebenes Produktverhalten.
Insbesondere benötigt WAIT_CAPTURE_CONTEXT vor Collectorcode einen exakten
JSON-Feldvertrag mit Datentypen, NULL-Regeln, Konsistenzprüfung und vollständiger
Rohsampledeckung. Fehlender, widersprüchlicher oder inkompatibler Kontext
muss Vergleiche sperren. Dieser offene Befund wird nicht durch die separate
Datenbank-Domänenmigration als erledigt ausgegeben.

Der unabhängige Vertragsreview ist nach gezielter Nachprüfung ohne
verbleibende P1-/P2-Befunde für diese vorgeschaltete Migration abgeschlossen.
Die frühere Daten-S-Lock-Annahme und die Standalone-Batchlücke wurden im
Vertrag korrigiert. Dies ist ein Spezifikationsnachweis; ausgeführter
Produktcode, native Sch-S-Probe, Migrations- und Erhaltungsabnahme bleiben
NOT_EXECUTED.

### API und ausdrückliche Aktivierung

ConfigureSnapshotTarget erhält nach seinen bisherigen 19 Parametern:

```sql
    , @CollectorCode varchar(64) = 'PERFORMANCE_COUNTERS'
    , @CollectorEnabled bit = 1
    , @UpdateSharedPolicy bit = NULL
```

RunSnapshotCollectionCycle erhält nach seinen bisherigen 13 Parametern:

```sql
    , @CollectorCode varchar(64) = 'PERFORMANCE_COUNTERS'
```

Steuerwerte werden getrimmt und großgeschrieben. Zulässig sind nur
PERFORMANCE_COUNTERS und WAIT_STATS; NULL oder unbekannte Collectorcodes
sind ungültig. Die bisherigen positionalen Aufrufe und der ausgelieferte
Performance-Counter-Default behalten ihren Verhaltensteil. WAIT_STATS wird
als deaktivierte Policy installiert und ausschließlich ausdrücklich gewählt.

UpdateSharedPolicy=NULL bedeutet für den bisherigen Default 1 und für
WAIT_STATS 0. Mit 0 muss eine passende bestehende Framework-Zielbindung
vorliegen; der Aufruf ändert nur die ausgewählte Collectorpolicy. Gemeinsame
Retention, Zielaktivierung, Zielbindung und Schedulerherkunft bleiben dann
unverändert. Mit ausdrücklich gewähltem 1 dürfen die angegebenen gemeinsamen
Werte im bestehenden Konfigurationsumfang übernommen werden. CollectorEnabled
steuert ausschließlich den ausgewählten Collector. Ein unveränderter Default-
Aufruf aktiviert oder verändert keine WAIT_STATS-Policy.

Ein altes 1.0.0-Ziel bleibt mit dem bisherigen Performance-Counter-Aufruf
nutzbar. Neue Optionen benötigen das bekannte 1.2.0-Ziel mit allen neuen
Objekten und Seeds; der Aufruf lehnt andernfalls mit TARGET_UNAVAILABLE
und präzisem Upgradehinweis ab. Alte Helpersignaturen erhalten im Legacy-
Default keine neu erfundenen Argumente. Ein WAIT_STATS-Aufruf innerhalb
einer Callertransaktion wird vor Fachzugriff oder persistentem Write als
INVALID_PARAMETER mit 51011 abgelehnt. Der Caller behält seine Transaktion,
Optionen und seine unabhängigen Änderungen.

### Ausgaben und neuer Ausführungspfad

Der neue Frameworkhelper monitor.InternalRunSnapshotWaitStatsCycle kapselt
den ausdrücklich gewählten Wait-Pfad. Der Legacy-Pfad des öffentlichen
Collection-Einstiegs bleibt getrennt erhalten. RAW und TABLE behalten die
beiden vorhandenen run-/modules-Schemas; JSON behält ContractVersion 1 mit
run-Objekt und modules-Array. Der CollectorCode im Lauf ist WAIT_STATS.
WAIT_STATS akzeptiert CONSOLE, RAW, TABLE und NONE; optionales JSON bleibt
OUTPUT. Der historische zusätzliche Ausgabeartwert JSON gilt allein für
den bisherigen Performance-Counter-Pfad.

CONSOLE des Wait-Pfads verwendet ein gemeinsames Grid aus Run und Modulstatus
mit dem kanonischen Renderer. Die native Quelltabelle enthält Scope
nvarchar(32) NOT NULL, CaptureRunId bigint NULL, CollectorCode varchar(64)
NULL, ModuleName sysname NULL, StatusCode varchar(40) NOT NULL, IsPartial
bit NOT NULL und Detail nvarchar(max) NOT NULL. Alle Textspalten verwenden
SQL_Latin1_General_CP1_CS_AS. Der Renderer ergänzt sein vorhandenes Ergebnisfeld.
Das Grid erhält Quellenfehler auch neben erhaltenem Run-Kontext.

Ungültige neue API-/TABLE-Parameter liefern regulären Diagnose-RETURN 51011,
Status und Fehler-OUTPUT sowie JSON-NULL. Vor Fachzugriff wird die gemeinsame
benannte TABLE-Zuordnung geprüft. Erwartete native Quellenfehler liefern einen
materialisierten Run-/Modulbericht mit RETURN 0; Status und Fehler-OUTPUT sind
maßgeblich. Vor erstem Zielwrite fehlgeschlagene Validierung erzeugt keinen
CaptureRun. Ein gefangener Writefehler liefert keine erfundene erfolgreiche
Finalisierung. Hilfe, Source-Opt-out und abgelehnte Ziele öffnen keine Quelle.

### Native Aufnahme und transienter Vertrag

sys.dm_os_wait_stats wird einmal vollständig in einen eigenen Cache gelesen.
Die SQL2025-Vorprobe bestätigt WaitType nvarchar(60) sowie WaitingTasksCount,
WaitTimeMs, MaxWaitTimeMs und SignalWaitTimeMs als bigint, jeweils NOT NULL.
Die Startfelder sind sqlserver_start_time datetime und
sqlserver_start_time_ms_ticks bigint, jeweils NOT NULL. Die Charakterisierung
endete absichtlich mit 57355 und eigenem erfolgreichen Labcleanup; sie ist
keine Produktabnahme.

Vor und nach dem Counterread werden native Startidentität und ServerName
verglichen. Die Identität besteht aus nativem ServerName, lokalem
sqlserver_start_time und sqlserver_start_time_ms_ticks. NULL-Kontext,
Kontextwechsel, negative Counter oder doppelte Waittypen sind keine gültige
Aufnahme. Der lokale Startzeitpunkt ist ausdrücklich keine UTC-Zeit.
WAIT_STATS lässt CaptureRun.SqlServerStartTimeUtc NULL und hält die native
Identität im versionierten Kontext. Der Performance-Counter-v1-Wert wird
weder nachträglich geraten noch umgerechnet; dessen historische Feldbenennung
bleibt als bekannte Grenze dokumentiert.

Der transiente interne JSON-Vertrag besitzt SchemaVersion 1 und resultName
SnapshotWaitStats. meta enthält measurementStartUtc, measurementEndUtc,
statusCode, isPartial, errorNumber, errorMessage, nativeRows, sourceComplete
und engineContext. engineContext enthält serverName, sqlServerStartTimeLocal
und sqlServerStartTimeMsTicks. waits enthält die fünf oben genannten Felder
mit exakter Groß-/Kleinschreibung. Ein fehlgeschlagener Read besitzt unbekannte
Counts und keine behauptete vollständige waits-Menge. Ein leerer nativer
Katalog erhält EMPTY_UNPROVEN. Explizite Quellencounter bleiben unverändert;
Timeouts werden nicht in Wiederholungsschleifen versteckt.

### Persistenz, Vorwerte und Qualitätscodes

Der neue Targethelper snapshot.InternalCompleteWaitStatsCycle schreibt nur
einen bereits eröffneten WAIT_STATS-Run. Ziel-ID, Zielname und create_date
werden vor Targetaufruf erfasst und im tatsächlichen Targetkontext vor
Writes erneut geprüft. Eine unbekannte oder geänderte Bindung erzeugt
keinen Fremdwrite. Diese Guards sind keine globale atomare Rename-/Restore-
Garantie. Ziel und vorheriger Lauf müssen denselben lokalen Paketvertrag
und denselben Collector besitzen.

Die folgenden neuen Metrikdefinitionen besitzen ContractVersion 1:

| MetricCode | ValueType | Unit | Bedeutung |
|---|---|---|---|
| WAIT_TASK_COUNT | BIGINT | count | Nativer kumulativer waiting_tasks_count. |
| WAIT_TIME_MS | BIGINT | ms | Native kumulative gesamte Waitzeit. |
| WAIT_SIGNAL_TIME_MS | BIGINT | ms | Native kumulative Signalwaitzeit. |
| WAIT_MAX_TIME_MS | BIGINT | ms | Native Maximalzeit; kein additiver Counter. |
| WAIT_TASK_COUNT_DELTA_CANDIDATE | BIGINT | count | Monotone Differenz mit unbewiesener Resetkontinuität. |
| WAIT_TIME_MS_DELTA_CANDIDATE | BIGINT | ms | Entsprechender Waitzeitkandidat. |
| WAIT_SIGNAL_TIME_MS_DELTA_CANDIDATE | BIGINT | ms | Entsprechender Signalzeitkandidat. |
| WAIT_DELTA_STATUS | STRING | status | Expliziter Grund für Kandidat oder Unterdrückung. |
| WAIT_CAPTURE_CONTEXT | STRING | json | Versionierter Aufnahme-/Vergleichskontext auf SERVER-Scope. |

Waittypen besitzen ScopeType WAIT_TYPE unter dem vorhandenen lokalen SERVER-
Scope. Scopeidentität und Hash entstehen aus exakt gebundenem Waittyp;
Metrik, Einheit, Version und ResetEpochId bleiben getrennte Vergleichsschlüssel.
WAIT_CAPTURE_CONTEXT enthält Engineidentität, Aufnahmezeiten, native und
persistierte Counts, Kappung, Vorwert-Run und die Epochenentscheidung. Sein
SchemaVersion-1-JSON bleibt unter der vorhandenen StringValue-Grenze von
4000 UTF-16-Codeeinheiten. Eine Überschreitung führt zu Ablehnung statt Abschneiden.

Persistiert werden aktive Waittypen mit mindestens einem positiven Counter
sowie die Waittypen der unmittelbar vorherigen Aufnahme, soweit sie aktuell
nativ vorhanden sind. Der vollständige native Cache bleibt für Reset- und
Fehlwertprüfungen verfügbar. Fehlende Native-Waittypen werden nicht mit Null
aufgefüllt. Ein bisher nicht gespeicherter Typ erhält FIRST_OBSERVATION;
der erste Vergleich erfindet keinen früheren Nullwert. Native vollständig
beobachtete Nullzeilen für vorherige Scopes dürfen als echte Nullwerte
persistiert werden.

MaxRows begrenzt gespeicherte Waittypen, nicht Datenbanken oder den nativen
Read. Pro gespeicherten Typ entstehen vier Rohwerte, ein Status und höchstens
drei Kandidaten; hinzu kommt höchstens ein Aufnahmekontext. Die Schranke lautet
8*MaxRows+1 MetricSamples. Bei Kappung wird kein vollständiger Vergleich
behauptet; die stabil nach Waittyp ausgewählten Rohwerte und Counts bleiben
als gemessene Rohwerte erhalten; Run und Kontext kennzeichnen die technisch
partielle Aufnahme. Softbudget, Retention und
Payloadpolicy gelten zusätzlich. Payload bleibt defaultmäßig deaktiviert.

Als Vergleichsbasis dient ausschließlich der unmittelbar vorherige finalisierte
WAIT_STATS-Run, nicht still ein älterer grüner Lauf. Er muss denselben Kontext,
dieselbe Metrikversion und eine vollständige nicht gekappte Aufnahme besitzen.
Eine fehlgeschlagene oder technisch partielle Zwischenaufnahme unterbricht
den Vergleich. Die rein fachliche Kennzeichnung der Kandidaten als
IsPartial=1 wird dabei nicht mit unvollständigem SourceRead oder Writecap
verwechselt: sourceComplete, Kappung und finalisierte Rohsampledeckung im
WAIT_CAPTURE_CONTEXT bestimmen die technische Vollständigkeit.
Das aktuelle UTC-Messfenster darf nicht vor dem vorherigen Ende beginnen;
die Endzeitdifferenz muss positiv sein. Keine Rate und kein Mittelwert wird
aus den Kandidaten abgeleitet.

Bei gleicher beobachteter Engineidentität und monotonen vollständigen Countern
bleibt die Epoche erhalten; Kandidaten erhalten QualityCode und Status
MONOTONIC_CONTINUITY_UNPROVEN mit IsPartial=1. Raw-Quality bleibt davon
getrennt MEASURED_CUMULATIVE. Der erste Lauf, Kontextwechsel, nichtpositive
Zeit, Kappung oder fehlende Basis unterdrücken Kandidatmetriken und erhalten
FIRST_OBSERVATION, ENGINE_CONTEXT_CHANGED, INTERVAL_NOT_POSITIVE,
WRITE_LIMITED, PREVIOUS_CAPTURE_PARTIAL, PREVIOUS_CONTEXT_INVALID oder
PREVIOUS_RAW_INCOMPLETE gemäß der nachfolgenden Statuspriorität.
Ein fehlender früherer Typ erhält FIRST_OBSERVATION. Ein fehlender notwendiger
aktueller Typ unterbricht den gesamten Vergleich mit WAIT_TYPE_MISSING.

Ein Counterrückgang einschließlich MaxWaitTimeMs erzeugt für den ganzen
Wait-Aufnahmebereich COUNTER_DECREASE und eine neue Epoche; alle Kandidaten
bleiben unterdrückt. Diese Klassifikation beweist keine einzelne Resetursache.
Bei unbekanntem Enginekontext entsteht keine geratene gemeinsame Epoche und
kein MetricSample, dessen notwendige EpochId nur erfunden wäre. Ein neuer
beobachteter Kontext erhält erst nach erfolgreicher Aufnahme eine eigene
EpochId. Unbekannte Kandidaten werden wegen des ExactlyOneValue-Vertrags
nicht als NULL-Samples eingefügt: der Status ist vorhanden, die entsprechende
numerische Kandidatmetrik fehlt. Die fehlende Metrik bedeutet nicht Null.

### Exakter WAIT_CAPTURE_CONTEXT-v1-Vertrag

Dieser Feldvertrag konkretisiert ausschließlich den nachfolgenden Wait-Slice.
Er ist noch keine implementierte Collector- oder API-Abnahme. Der Targethelper
muss vor dem ersten Collectorwrite PackageVersion 1.2.0, SchemaVersion 2 und
die vollständige benötigte Helperclosure prüfen; eine Versionszeile allein
qualifiziert keine möglicherweise abgebrochene Installation. Configure führt
kein implizites Upgrade aus.

Der Kontext ist genau ein JSON-Objekt ohne Arrays. Alle nachfolgend genannten
Member sind vorhanden und exakt case-sensitiv. Zusätzliche oder doppelte
Member, falsche JSON-Typen und stillschweigende Konvertierungen sind unzulässig.
Eine ausdrücklich nullable Eigenschaft bleibt als JSON null enthalten.
Die Container engine, window, capture und comparison sind jeweils genau ein
JSON object und weder null noch Array; ihre Membermengen entsprechen exakt
der Tabelle. Das gesamte StringValue umfasst höchstens 4000 UTF-16-Codeeinheiten,
gemessen mit DATALENGTH(StringValue)/2 statt LEN; Überlänge
wird abgewiesen und nicht abgeschnitten. Diese Datenprüfung bestätigt interne
Konsistenz, keine kryptografische Herkunft oder Unveränderbarkeit gegenüber
einem berechtigten Administrator.

DECIMAL_STRING bezeichnet JSON string mit kanonischen Dezimalziffern: entweder
0 oder eine Ziffer 1 bis 9 mit folgenden Ziffern, ohne Vorzeichen, Leerraum,
Dezimalpunkt und Exponent. Der Wert muss verlustfrei als nichtnegativer SQL-
bigint darstellbar sein. Positive IDs erlauben 0 nicht. Headerzahlen sind
JSON number mit exakt der kanonischen Ganzzahlenschreibweise des Vertragswerts
ohne Dezimalpunkt oder Exponent; boolesche Felder sind
JSON boolean. OPENJSON-Typ und Memberhäufigkeit werden vor typed WITH geprüft;
JSON_VALUE und TRY_CONVERT allein beweisen diese Grenzen nicht.

UTC_MS bezeichnet eine gültige datetime2(3)-Zeit als
YYYY-MM-DDTHH:mm:ss.fffZ. LOCAL_MS besitzt dieselbe Darstellung ohne Z und
beschreibt ausdrücklich lokale native SQL-Server-Zeit. Die Komponenten
werden verlustfrei geparst und kanonisch zurückserialisiert; Offsetangaben,
abweichende Präzision und eine stillschweigende UTC-Umrechnung sind unzulässig.
GUID bezeichnet eine uniqueidentifier-Darstellung mit 36 Zeichen
in kanonischer Kleinbuchstabenschreibung; die Null-GUID ist ausgeschlossen. SHA256 bezeichnet 64 hexadezimale
Kleinbuchstaben ohne Präfix. Die Serialisierung benutzt diese Regeln auch
bei Werten, die JavaScript nicht mehr als sichere Ganzzahl darstellen kann.

| JSON-Pfad | Typ und NULL-Regel | Verbindliche Bedeutung |
|---|---|---|
| schemaVersion | number, genau 1 | Version dieses Kontextobjekts. |
| collectorCode | string, genau WAIT_STATS | Bindung an den eigenen Collector. |
| metricContractVersion | number, genau 1 | Gemeinsame Version der neun Waitmetrikdefinitionen. |
| captureRunId | positive DECIMAL_STRING, NOT NULL | Muss dem tatsächlich geschriebenen CaptureRun entsprechen. |
| serverScopeId | positive DECIMAL_STRING, NOT NULL | ScopeId des tatsächlich verwendeten lokalen SERVER-Scopes. |
| resetEpochId | GUID, NOT NULL | Muss CaptureRun und allen Samples dieses Wait-Laufs entsprechen. |
| engine.serverName | string, 1 bis 128 UTF-16-Einheiten, NOT NULL | Unverändert beobachteter nativer ServerName; kein Trim oder Casefold. |
| engine.sqlServerStartTimeLocal | LOCAL_MS, NOT NULL | Verlustfreie Millisekundendarstellung des nativen datetime-Startwerts. |
| engine.sqlServerStartTimeMsTicks | DECIMAL_STRING, NOT NULL | Nativer bigint-Starttick; kein UTC-Wert und keine gemessene Intervalllänge. |
| window.measurementStartUtc | UTC_MS, NOT NULL | Zeitpunkt unmittelbar vor dem vollständigen nativen Counterread. |
| window.measurementEndUtc | UTC_MS, NOT NULL | Zeitpunkt unmittelbar nach diesem Read. |
| capture.sourceComplete | boolean, genau true | Der einmalige native Read ist beendet; dies behauptet keine instanzweite atomare DMV-Sicht. |
| capture.nativeWaitTypeCount | DECIMAL_STRING, NOT NULL | Zahl aller nativen Cachezeilen einschließlich Nullcounter. |
| capture.activeTypeCount | DECIMAL_STRING, NOT NULL | Native Typen mit mindestens einem positiven der vier Rohcounter. |
| capture.eligibleTypeCount | DECIMAL_STRING, NOT NULL | Vor Kappung vereinigte aktive Typen und aktuell nativ vorhandene Vorwerttypen. |
| capture.writtenTypeCount | DECIMAL_STRING, NOT NULL | Tatsächlich persistierte eindeutige WAIT_TYPE-Scopes dieses Laufs. |
| capture.writeLimited | boolean, NOT NULL | Wahr genau dann, wenn die berechtigte Typmenge durch MaxRows gekappt wurde. |
| capture.rawMetricSampleCount | DECIMAL_STRING, NOT NULL | Tatsächliche Zahl der vier Rohmetriken je geschriebenem Typ. |
| capture.rawProjectionSha256 | SHA256, NOT NULL | Hash der tatsächlich gespeicherten kanonischen Rohprojektion. |
| comparison.previousCaptureRunId | positive DECIMAL_STRING oder null | Unmittelbar vorheriger finalisierter WAIT_STATS-Run, auch bei dessen Fehler. |
| comparison.previousContextVersion | positive kanonische JSON-Ganzzahl bis 2147483647 oder null | Beobachtete schemaVersion des Vorwertkontexts; null bei fehlendem oder ungültigem Versionsmember. Eine syntaktisch gültige unbekannte Version bleibt sichtbar und qualifiziert keinen Vergleich. |
| comparison.status | string aus der nachfolgenden Menge, NOT NULL | Globaler Vergleichsstatus dieses Laufs. |
| comparison.comparableTypeCount | DECIMAL_STRING, NOT NULL | Geschriebene Typen mit vier eindeutig belegten Vorwerten bei grundsätzlich zulässigem Vergleich. |
| comparison.candidateSampleCount | DECIMAL_STRING, NOT NULL | Tatsächlich geschriebene drei Differenzkandidaten je vergleichbarem Typ. |
| epochDecision | string aus der nachfolgenden Menge, NOT NULL | Explizite Entscheidung über die logische Vergleichsepoche. |

Enginekontext und Zählwerte sind nur nach erfolgreichem Read und bestandenem
Vorher-/Nachhervergleich zulässig. Fehlgeschlagene, negative oder doppelte
Quellzeilen und unbekannter Enginekontext erzeugen keinen Kontextsample und
keine erfundene Epoche; der finalisierte Fehlerlauf bleibt dennoch als nächste
Vorwertreferenz gemäß der nachfolgenden Retentionsgrenze sichtbar.
Ein vollständig gelesener leerer Katalog darf einen
Kontext mit SOURCE_EMPTY_UNPROVEN erhalten, qualifiziert jedoch keinen
numerischen Vergleich. capture.sourceComplete=true allein bedeutet deshalb
weder verwertbare Rohwerte noch Resetkontinuität.

Der transiente Sourcevertrag verwendet dieselben drei engine-Felder und
Zeitdarstellungen. nativeRows ist DECIMAL_STRING oder null bei Lesefehler;
sourceComplete ist boolean. Die fünf waits-Member heißen exakt WaitType,
WaitingTasksCount, WaitTimeMs, MaxWaitTimeMs und SignalWaitTimeMs. WaitType ist
ein nichtleerer nvarchar(60), die übrigen Werte sind nichtnegative native
bigint als kanonische ganzzahlige JSON number ohne Exponent oder Dezimalpunkt.
Deren SQL-Verarbeitung bleibt verlustfrei;
eine Umwandlung durch JavaScript Number ist keine zulässige Zwischenstufe.
Ein Sourcefehler besitzt keine behauptete vollständige waits-Menge.

#### Scope-, Rohwert- und Mengenbindung

Der lokale SERVER-Scope verwendet den bereits vorhandenen kanonischen
Identitätswert {"scope":"SERVER"}. Der neue WAIT_TYPE-Scope besitzt exakt
{"waitType":<nativer WaitType>} als mit FOR JSON erzeugtes Identitätsobjekt,
mit diesem SERVER-Scope als Parent. Sein SHA2_256-Schlüssel wird aus den
UTF-16LE-Bytes dieser kanonischen Identität ohne BOM gebildet. Vorhandene
Scopezeilen mit widersprüchlicher Identität, Parentbindung oder Hash werden
nicht still übernommen. Diese Identität ist ziel-lokal; mehrere Frameworks
an demselben Target sind bis zu eigener Abnahme nicht unterstützt.

Die Rohprojektion wird erst aus den in derselben Targettransaktion tatsächlich
geschriebenen vier BIGINT-Samples rekonstruiert. Pro WaitType enthält sie die
fünf oben genannten Member in genau dieser Reihenfolge. WaitType wird nach
Latin1_General_100_BIN2 sortiert; die Serialisierung erfolgt mit FOR JSON PATH,
INCLUDE_NULL_VALUES. SHA2_256 wird über CONVERT(varbinary(max),@RawJson), also
UTF-16LE ohne BOM, berechnet und als SHA256 serialisiert. Erwartete Auswahl
und gespeicherte Projektion müssen übereinstimmen. Counts allein ersetzen
keine Rohwertdeckung. Dieser Hash ist eine Konsistenzprüfung und kein
Herkunftsnachweis.

writtenTypeCount darf eligibleTypeCount nicht überschreiten; eligibleTypeCount
liegt höchstens bei nativeWaitTypeCount. writeLimited entspricht exakt dem
Vergleich writtenTypeCount<eligibleTypeCount. rawMetricSampleCount ist genau
4*writtenTypeCount. Jeder Typ besitzt zusätzlich genau einen WAIT_DELTA_STATUS;
je vergleichbarem Typ entstehen genau drei Kandidaten, sonst keiner.
candidateSampleCount ist deshalb genau 3*comparableTypeCount, höchstens
3*writtenTypeCount. Bei unterdrücktem globalem Vergleich sind beide Counts 0.
Der Kontextsample selbst liegt genau einmal auf dem gebundenen SERVER-Scope.
Der Gesamtumfang ist damit 5*writtenTypeCount+candidateSampleCount+1 und bei
positivem MaxRows höchstens 8*MaxRows+1. CaptureRun.MetricSampleCount muss dem
tatsächlichen Umfang entsprechen.

Alle Samples verwenden die beschriebenen neun Metrikcodes mit ValueType,
Unit und ContractVersion 1. Fehlende, doppelte, zusätzliche oder falsch
gebundene Waitmetriken, Raw-IsPartial, unbekannte Scopes und widersprüchliche
EpochIds qualifizieren keine vollständige Aufnahme. Die vier Rohwerte sind
nicht NULL, besitzen QualityCode MEASURED_CUMULATIVE und IsPartial=0.
Kandidatensamples besitzen MONOTONIC_CONTINUITY_UNPROVEN und IsPartial=1.
Diese fachliche Partialität verhindert nicht allein einen späteren Vergleich
mit vollständigen Rohwerten.

#### Zeit-, Vorwert- und Statuskonsistenz

measurementStartUtc liegt nicht nach measurementEndUtc. Alle Wait-Samples
benutzen measurementEndUtc als CollectedAtUtc. Bei einem finalisierten Lauf
liegt dessen tatsächliches StartedAtUtc nicht nach dem Messbeginn und dessen
EndedAtUtc nicht vor dem Messende. Der Kontext behauptet vor Finalisierung
keine zukünftige Endzeit. Vorwertwahl ist der unmittelbar vorherige Lauf mit
EndedAtUtc, CollectorCode WAIT_STATS und kleinerer CaptureRunId; ein Fehlerlauf
wird nicht zugunsten eines älteren grünen Laufs übersprungen.

Dafür muss die spätere Collectorlieferung den bestehenden Purge gezielt
anpassen: Die CaptureRun-Zeile mit der größten finalisierten WAIT_STATS-
CaptureRunId bleibt unabhängig von Status und vorhandenen Kindern erhalten,
auch nach Ablauf der Rohretention. Rohsamples, Payloads, Modulstatus und
nicht mehr referenzierte Scopes unterliegen weiter der begrenzten Retention.
Ein erhaltener Lauf ohne notwendige Kinder ist keine gültige numerische
Vergleichsbasis. Erst wenn ein neuerer Wait-Lauf tatsächlich finalisiert ist,
darf die bisher erhaltene Zeile im regulären Purge entfallen. Diese Ausnahme
hält höchstens eine zusätzliche finalisierte Laufzeile als Vergleichsgrenze;
sie ist keine verlängerte Rohdatenaufbewahrung. Der Performance-Counter-Pfad
behält seine bisherige Retention. Der vorhandene 1.1.0-Purge besitzt diese
neue Wait-Garantie noch nicht; sie ist Pflicht vor WAIT_STATS-Aktivierung.
Eine manuelle privilegierte Löschung der letzten Laufzeile kann ohne zusätzliche
Historie nicht rekonstruiert werden und ist keine zugesagte Herkunftsgarantie.

Für einen Vergleich müssen Vorwertlauf, genau ein unterstützter Kontext,
Rohprojektion, Scope-/Metrikversionen und Counts konsistent sein. Die gesamte
benötigte Rohmenge wird geprüft, nicht nur später angezeigte Typen. Ein
Retentionsverlust an Kontext, Scope, Rohsample oder Statusmetrik sperrt den
Vergleich; er wird nicht zu Null. Der aktuelle Messbeginn liegt frühestens
am vorherigen Messende, und die Endzeitdifferenz ist positiv. Es wird keine
Rate oder mittlere Waitdauer aus diesen Kandidaten berechnet.

Der globale Status wird in dieser Priorität gewählt: SOURCE_EMPTY_UNPROVEN,
WRITE_LIMITED, FIRST_OBSERVATION bei fehlendem vorherigem Lauf,
PREVIOUS_CAPTURE_PARTIAL bei dessen Fehler/technischer Partialität,
PREVIOUS_CONTEXT_INVALID bei fehlendem, ungültigem oder unbekanntem Kontext,
PREVIOUS_RAW_INCOMPLETE bei fehlender oder widersprüchlicher Rohdeckung,
ENGINE_CONTEXT_CHANGED, INTERVAL_NOT_POSITIVE, WAIT_TYPE_MISSING,
COUNTER_DECREASE, NO_COMPARABLE_TYPES und andernfalls
MONOTONIC_CONTINUITY_UNPROVEN. Ein Rückgang eines der vier Counter auf einem
belegten Vorwerttyp, einschließlich MaxWaitTimeMs, sperrt alle Kandidaten.
Er beweist keine einzelne Resetursache. Ein neuer Typ erhält selbst bei
sonst zulässigem Vergleich FIRST_OBSERVATION und keine fiktiven Nullvorwerte.

Der erste Kontext erhält NEW_FIRST. Eine belegte Engineänderung erhält
NEW_ENGINE_CONTEXT, ein belegter Counterrückgang NEW_COUNTER_DECREASE.
Andere technische Vergleichsunterbrechungen einschließlich Kappung, leerer
Quelle, fehlendem Vorwertkontext oder unzulässigem Zeitfenster erzeugen
NEW_COMPARISON_BREAK. Ein konsistenter gleicher Kontext erhält RETAIN_CONTEXT
und genau die vorherige EpochId; dies gilt auch bei NO_COMPARABLE_TYPES,
sofern die technische Rohdeckung vollständig ist. Alle NEW-Entscheidungen
verwenden eine neue nichtleere EpochId und behaupten keinen bewiesenen
DBCC-Reset. Die tatsächlich geschriebene EpochId wird in Run, Kontext und
Samples atomar gleich gebunden.

Die Epochenentscheidung besitzt eine eigene feste Priorität: Ohne vorherigen
finalisierten Lauf gilt NEW_FIRST. Danach geht eine anhand eines gültigen
Vorwertkontexts belegte Engineänderung vor; danach folgt ein bei gleicher
Engine anhand vollständig geprüfter Vorrohwerte und des gesamten aktuellen
Caches belegter Counterrückgang. Erst danach folgt NEW_COMPARISON_BREAK für
andere technische Unterbrechungen, andernfalls RETAIN_CONTEXT. Ein unbekannter
Vorwertkontext belegt weder Enginegleichheit noch Engineänderung. Diese
Priorität gilt auch bei gleichzeitigem Writecap oder leerer Quelle; ein
belegter Enginewechsel kann deshalb mit Status WRITE_LIMITED einhergehen.
Status und Epochenentscheidung werden zusammen geprüft. Ein Rohwertfehler,
ein fehlender aktueller Vorwerttyp oder eine unzulässige Zeit erlaubt keinen
numerischen Kandidaten. Jede neue EpochId unterscheidet sich von der gültigen
vorherigen EpochId.


#### Erforderliche Gegenfälle vor Collectorlieferung

Die Abnahme prüft fehlende, doppelte, zusätzliche und case-falsche Member,
JSON-Typverwechslungen, übergroße IDs, Vorzeichen/Exponenten, ungültige Zeit-
und GUID-Darstellungen sowie Kontextüberlänge ohne Abschneiden. Sie prüft
Engine-/Epoch-/Run-/Scopewidersprüche, falsche Mengen und Rohhashes, entfernte
Roh- oder Statussamples, unbekannte Versionen und technisch partielle
Zwischenläufe. Jede solche Basis unterdrückt numerische Kandidaten.
Neue Typen, echte gespeicherte Nullen, Counterrückgang, gleiche Zeitfenster,
Kappung und leere Quellen erhalten getrennte Oracles. Quelle und Aufnahme
werden einmal gelesen; ein Ergebnisfehler löst keine versteckte Wiederholung
aus. Ein tatsächlicher DBCC-Reset bleibt eine getrennte eigene isolierte
Lababnahme mit ausdrücklichem Opt-in und ersetzt diese Konsistenzfälle nicht.

Ein zusätzlicher echter Purgefall verwendet einen abgelaufenen älteren Erfolg
mit mehr Rohsamples als ein kleiner Purgebatch abbauen kann sowie einen
jüngeren finalisierten Fehlerlauf ohne Samples. Nach genau einem begrenzten
Purge bleibt der Fehlerlauf als unmittelbare Vorwertgrenze erhalten und
numerische Kandidaten bleiben gesperrt; der ältere erhaltene Erfolg darf
nicht übernehmen. Ein weiterer Fall entfernt Kinder der letzten erfolgreichen
Aufnahme und verlangt PREVIOUS_RAW_INCOMPLETE statt eines Rückfalls. Nach
Finalisierung eines neuen Wait-Laufs darf die alte abgelaufene Grenzzeile
wieder regulär entfernt werden. Diese Fälle prüfen den tatsächlichen Purge
und den tatsächlichen Collector gemeinsam, keine nachgebildete Löschfunktion.


### Atomarität, Betrieb und Abnahmegrenzen

Der neue Collection-Pfad prüft Aktivierung und Fälligkeit vor SourceRead und
vor neuem Purge-/Capturewrite. RunEvenIfNotDue umgeht ausschließlich Fälligkeit.
Eine gemeinsame Session-Applock mit Wartezeit 0 serialisiert alle Collector.
Der Wait-Slice berücksichtigt jeden finalisierten vorherigen Wait-Lauf für
Intervall und Vergleichsauswahl, auch einen fehlgeschlagenen; Force kann
explizit früher erneut messen. Der bestehende Performance-Counter-Intervallpfad
behält sein bisheriges Verhalten.

Der Targethelper schreibt Scopes, Samples und Modulstatus für seinen Run in
einer eigenen kurzen Transaktion. Ein Writefehler rollt nur diese eigene
Transaktion zurück; die Fehlerfinalisierung bleibt sichtbar, soweit die
Zielrechte dies erlauben. Unfinalisierte Läufe werden nicht zu Vorwerten.
Erfolg und Fehler geben die Session-Applock frei und erhalten Calleroptionen.
Quelle, Budgetstop, Versionsablehnung und leere/partielle Daten besitzen
getrennte Oracles; ein erlaubter Erfolg bedeutet keine tatsächliche Kontrolle
über konkurrierende Administratoraktionen.

Upgrade, Wiederholung, Opt-out und eigene Policies werden nativ mit zuvor
geschriebenen Performance-Counter-Samples geprüft. Alte Paket- und Helper-
Signaturen bleiben im Default nutzbar. Die neuen Metrikseeds dürfen bestehende
abweichende Definitionen nicht blind überschreiben. Kollisionen, unbekannte
Versionen oder fremde Zielstruktur erzeugen vor Änderungen einen konkreten
Konflikt. Die gespeicherten Differenzkandidaten können nach Retention ihrer
älteren Basis nicht mehr vollständig aus den Rohsamples nachgerechnet werden;
der erhaltene Kontext ist Provenienz und keine zugesagte ewige Reproduzierbarkeit.

Ein tatsächliches DBCC-Wait-Reset ist eine globale Engineaktion und gehört
nicht automatisch in den allgemein ausführbaren Release-SQL-Runner. Seine
Ende-zu-Ende-Abnahme benötigt eine getrennt nachgewiesene eigene isolierte
Labinstanz und ausdrückliches Reset-Opt-in. Die normale Fixture prüft
konstruierte Vergleichsstufen getrennt von der vollständigen SUT. Ein solcher
Stufenfall wird nicht als nativer Engine-Reset ausgegeben. Der neue Collector
selbst führt keinen Reset, Restart oder Hosteingriff aus.

Die Target-Quellen verwenden bereits den ausdrücklich gewählten und im ersten
Targetskript geprüften Installationskontext. Der allgemeine USE-Satz im
Projektkontext widerspricht diesem bestehenden Paketweg. Dieser begrenzte
TARGET_INTERNAL_CONFLICT wird vor der neuen Targetquelle durch eine enge
nachvollziehbare Ausnahme für den kanonischen Targetinstaller und seine
Targetquellen aufgelöst; gewöhnliche Frameworkquellen behalten ihren USE-
Header. Die Ausnahme erweitert keine Datenbankauswahl oder Runtimeberechtigung.

## Primärquellen

- Microsoft Learn: [Wait-Stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-wait-stats-transact-sql?view=sql-server-ver17).
- Microsoft Learn: [Datei-I/O-Stats](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-io-virtual-file-stats-transact-sql?view=sql-server-ver17).

- Microsoft Learn: [Engine-Startkontext](https://learn.microsoft.com/en-us/sql/relational-databases/system-dynamic-management-objects/sys-dm-os-sys-info-transact-sql?view=sql-server-ver17).


## Historie der Schema-2-Implementierung

Die folgenden Zwischenstände dokumentieren die Entwicklung bis zum
Liefercommit von PR #447. Ihre damaligen offenen Gates sind im anschließenden
Abschlussstand aufgelöst; frühere Fehler bleiben als eigene Evidenz erhalten.

Der aktuelle Änderungskandidat enthält ausschließlich die vorgeschaltete
Migration und ihre drei Installationswege. Lokal bestehen auf SQL2025 die
frische Installation, die Wiederholung und das Upgrade aus dem zuvor gesicherten
tatsächlichen 1.0.0-Targetskript mit erhaltenen Counterdaten und Policies.
Der fokussierte native Deploymentvertrag besteht für drei gefüllte V1-Upgrades,
drei Wiederholungen und 19 gezielte Versions-/Strukturablehnungen. Die nachfolgenden
Callertransaktionsfälle werden am Korrekturstand gesondert nachgewiesen. Eine frühere Fixture-
Wiederherstellung versuchte einen fehlenden CHECK erneut zu löschen; dieser
Testfehler ist korrigiert. Der separate frühere 1222 vor Migration bleibt ohne
behauptete Sperrursache sichtbar.

Die eigene native Sch-S-Abnahme besteht mit dem tatsächlichen kanonischen
Targetbatch auf SQL Server 2025, ProductVersion 17.0.4075.5. Der erste CHECK-
Austausch ist über CompletedStage=1 belegt, der zweite Schritt scheitert mit
1222. Alle zehn Tabellendaten und CHECK-Definitionen bleiben nach Rollback
unverändert; die anschließende Wiederholung migriert erfolgreich. Cleanup
bestätigt die Entfernung der eigenen Container- und Volumeressourcen.
Das ist eine lokale Abnahme des benannten Kandidaten, kein Main-, PR- oder
SQL2019-Nachweis. Unabhängiger Produktreview, vollständiges SQL2025-Gate,
gezielte native SQL2019-Abnahme und reguläre PR-Integration bleiben offen.


Der Produktreview des ersten Kandidaten benennt zwei P2-Befunde: Der
Versionsread musste seine PackageVersion-Sperre bereits vor Klassifikation
halten; außerdem fehlte dem Standalone-Rahmen der gemeinsame ANSI-/
QUOTED_IDENTIFIER-/LOCK_TIMEOUT-Kontext für spätere Helperkompilationen.
Der gebündelte Korrekturpass bindet die Versionszeile zuerst mit
TABLOCKX/HOLDLOCK und setzt den kanonischen begrenzten Kompilationskontext
nach der frühen Callerablehnung. Ein positiver Gegenfall beginnt mit
QUOTED_IDENTIFIER OFF und LOCK_TIMEOUT -1 und verlangt korrekte gespeicherte
SET-Metadaten aller fünf Helper. Die frühe Ablehnung verwendet wie das
Gesamtdeployment einen getrennten XACT_ABORT-OFF-/RAISERROR-Rahmen. Der
neue Callerfall hatte zuvor den Zustand nach erwarteter Ablehnung verletzt;
sein Oracle bleibt unverändert. Folgeprüfung und native Wiederholung dieses
Korrekturstands sind noch offen.


### Abschlussstand des lokalen Korrekturpasses

Der unabhängige Folgecheck schließt beide P2 und den eng begrenzten
Callerablehnungsfix ohne neue Befunde. Die vollständige lokale Suite besteht
am ersten Kandidaten mit 74 Validatoren; alle 19 betroffenen Deployment-
Grammarprüfungen bestehen erneut am Korrekturstand. Metadaten-/Tempnamen-,
Snapshotvertrags-, Stil-, Privacy- und Regelkontextprüfung bestehen. Der
Datenschutzselbsttest besteht ebenfalls; der neue Testdatenbankkontext ist
als exakt pfad-/wertgebundener synthetischer Kontext klassifiziert.

Der korrigierte native SQL2025-Vertrag besteht für drei reale Installationswege,
V1-Upgrades, Wiederholungen, 19 Struktur-/Versionskonflikte sowie die zusätzlichen
Caller- und abweichenden Kompilationsoptionen. Der eigene Lab-Cleanup ist
bestätigt. Der korrigierte kanonische Fehlerlauf besteht auf SQL Server 2019,
ProductVersion 15.0.4480.2, einschließlich Stage 1, nativem Fehler 1222,
Rollback aller zehn Tabellen und CHECKs, Recovery und Cleanup. Die lokale
Batchbindung lautet 2427938116a1ac158c17216427bc364d5f8bb53311dd265b1ba2424b7e14bb5c.
Das frühere 53817 des Standalone-Callerfalls bleibt als fehlgeschlagener
Vorstand erhalten; sein unverändertes Oracle besteht nach der Korrektur.

Die reguläre vollständige SQL2025-Head-CI und das gezielt gewählte native
SQL2019-Snapshot-/Migrationsrisikogate sind noch auszuführen. Lokale Ergebnisse
ersetzen diese Required Checks nicht. WAIT_CAPTURE_CONTEXT und der spätere
Wait-Collector bleiben offen; neue WAIT-Policies oder Metriken werden mit
dieser Welle nicht geliefert.


### Erstes Remote-Paketgate und Installerkontextkorrektur

Das native SQL2019-Paketgate 40207013284 besteht am Lieferkandidaten f31f9fae
mit tatsächlicher Snapshot-/Migrationsrisikoauswahl. Paketvalidierung,
Core-Release-Gate, Berechtigungen, gefülltes Deployment, Snapshot- und
Nebenläufigkeitsverträge sowie Cleanup bestehen. Dieser Erfolg gehört zu
diesem Head und wird nicht still auf einen späteren Paketdigest übertragen.

Die Dokumentations-CI desselben Heads scheitert im unveränderten allgemeinen
Standalone-Installertest 191. Drei bereits in der Basis vorhandene Quellen
hatten unmittelbar nach dem führenden GO keine Leerzeile; der bestehende
Builder entfernte deshalb ihre USE-Header nicht. Je eine zusätzliche Leerzeile
in CurrentCallerPermissionAnalysis, InternalSsisScopePathMatch und
InternalSsisExecutionScopes stellt den vorgesehenen einen Installerkontext
her. Der lokale Tokenvergleich belegt identisches ausführbares T-SQL; der
unabhängige mechanische Delta-Review bestätigt dies. Die unveränderten
Installertests 191, 192 und 194 bestehen danach. Der frühere Fehllauf bleibt
erhalten; neue erforderliche Gates binden den korrigierten Lieferhead.


Die folgende CI erkennt den noch nicht neu erzeugten versionierten OPS-005-
Installer. Der vorgesehene Adapter-Builder aktualisiert ihn um genau sechs
entfallende redundante USE-/GO-Zeilen aus den drei korrigierten Quellen.
Sein unveränderter strenger Quellenvergleich besteht danach mit acht
Repräsentationsfällen. Der Test wurde nicht abgeschwächt; das abgeleitete
Artefakt und die kanonischen Quellen werden gemeinsam geliefert.


### Gezielter älterer Versionsumfang und offene Vollrun-Befunde

Am Head d286e9f5 besteht die vollständige statische CI. Der native Vollrun
40208646875 scheitert in Versuch 1 und im begrenzten Versuch 2 vor Snapshot
in Legacy202 an TARGET_SCHEMA_ADAPT / 51010, einmal findings C022, danach
iterations C012. Cleanup ist jeweils bestätigt. Die unveränderte 202-Fixture
besteht isoliert lokal auf SQL2019. Die SQL2025-Head-CI 40208610598 scheitert
im bestehenden Standalone-Plan-Test mit 1222 in CreateExecutionEvidenceJson.
Der frühere 2eaba0cc-Lauf scheiterte an CONT-PAGE / 54504. Ursachen bleiben
UNKNOWN; ein weiterer unveränderter blinder Wiederlauf ist nicht vorgesehen.

Ein unabhängiger Scopecheck bestätigt den gemäß kanonischer 1+0+N-Strategie
zulässigen expliziten Modus SNAPSHOT_SCHEMA_RISK. Der volle primäre SQL2025-
Required-Check und der Default FULL_RELEASE werden nicht eingeschränkt.
Die native Risikoabnahme prüft commit-/paketgebunden Frameworkinstallation
und Smoke, drei Snapshot-Migrationsrouten und Erhaltung, Caller-/Options-
und gezielte Installationsrechte sowie Snapshot und Nebenläufigkeit. Die
Evidenz erklärt Core-Release und dessen allgemeine Berechtigungsmatrix als
NOT_EXECUTED. Ein eigenes Artefakt und der scopegebundene Validator verhindern
die Ausgabe eines vollständigen nativen Releaseerfolgs. Die gescheiterten
Vollruns bleiben als offene allgemeine TABLE-/Temp-DDL-Zuverlässigkeit sichtbar.


Der neue gezielte native Rechtescope besteht lokal auf SQL2019: Ein eigener
synthetischer Login mit CONTROL DATABASE und VIEW ANY DEFINITION kann den
kanonischen Targetbatch ausführen. Der Entzug jeweils einer Voraussetzung
liefert den erwarteten Fehler 53901 ohne Daten-/Strukturänderung. Eigene
Principals und das Lab werden bereinigt. Die neuen statischen Scope-/
Evidenzgegenfälle bestehen für FULL_RELEASE-Defaults und SNAPSHOT_SCHEMA_RISK,
einschließlich Abweisung falscher Vollerfolgsangaben. Eine Remoteausführung
dieses expliziten Modus ist vor dessen Code-/Scopefolgecheck noch nicht erfolgt.


## Integrierter Schema-2-Abschlussstand

[PR #447](https://github.com/gecompat/SQL_Server_Analyze/pull/447) integriert
PackageVersion 1.1.0 und SchemaVersion 2 als `ce8b5e30`. Der Liefercommit
`459c19ae` besteht alle acht Head-Checks einschließlich des vollständigen
[SQL2025-Laufs](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40211876502).
Der getrennte vollständige
[Main-Nachlauf](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40212817038)
sowie Dokumentation, Datenschutz, Commitnachrichten und Cleanupvertrag
bestehen ebenfalls. Der unabhängige Produktreview und seine konkreten
Folgechecks sind ohne offene Befunde abgeschlossen.

Die gezielte native
[SQL2019-Risikoqualifizierung](https://github.com/gecompat/SQL_Server_Analyze/actions/runs/40211873213)
bindet denselben Liefercommit und das Paket mit SHA256
`0e0f7151af38cd3b401276b2e70d5518a3c68a65765f38fe00be2a9026c14085`.
Sie besteht auf Linux mit ProductVersion 15.0.4500.2, Compatibility Level 150
und SQL_Latin1_General_CP1_CS_AS. Der ausdrückliche Scope SNAPSHOT_SCHEMA_RISK
führt genau FRAMEWORK_SMOKE, SNAPSHOT_SCHEMA_MIGRATION_AND_PERMISSION,
SNAPSHOT_BASELINE_195 und SNAPSHOT_CONCURRENCY_196_197 aus. Migration und
Rechte umfassen drei gefüllte reale Installationswege, 19 gezielte Ablehnungen,
Callertransaktionen, Kompilationsoptionen und positive/negative
Installationsrechte. Cleanup besteht. Core-Release und dessen allgemeine
Berechtigungsmatrix bleiben NOT_EXECUTED; dies ist keine vollständige native
Releaseabnahme. Frühere fehlgeschlagene Vollruns bleiben unverändert erhalten.

Die Lieferung erweitert ausschließlich die beiden CHECK-Domänen und den
zugehörigen Installations-/Validierungsweg. Sie enthält keine WAIT_STATS-
Policy, keine neuen Waitmetriken und keinen Wait-Collector. Als nächster
Schritt folgt nach dem unabhängig geschlossenen WAIT_CAPTURE_CONTEXT-v1-
Vertragsreview die Collectorimplementierung mit PackageVersion 1.2.0 und unveränderter
SchemaVersion 2. Datei-I/O bleibt ein getrennter späterer Slice.


Der unabhängige Kontextreview ist einschließlich eines gezielten
Retentionsfolgechecks ohne offene Befunde abgeschlossen. Der P2 betraf das
mögliche Entfernen eines jüngeren Fehlerlaufs vor einem älteren erhaltenen
Erfolg. Die ausdrücklich erst mit dem Wait-Produkt zu implementierende
Erhaltung der letzten finalisierten Laufzeile und die echten Purgegegenfälle
schließen diese Vertragslücke. 74 lokale statische Validatoren, Stilprüfung,
Regelkontext und Datenschutz bestehen. Eine SQL-Laufzeitabnahme des neuen
Kontextvertrags ist vor Collectorcode nicht erfolgt und wird nicht behauptet.


## Abgegrenzter Retentionspatch vor Wait-Persistenz

Die nächste kohärente Produktwelle implementiert zunächst die im Kontextreview
festgelegte Runerhaltung im gemeinsamen Purge. Target-PackageVersion 1.1.1
behält SchemaVersion 2, akzeptiert das bekannte 1.1.0-Target und liefert
keinen Wait-Collector, keine Policy und keine neuen Metrikseeds. Die Trennung
ermöglicht eine eigene native Abnahme des gemeinsamen Löschpfads vor der
späteren Target-Persistenz und öffentlichen Aktivierung mit 1.2.0.

Die tatsächliche 195-Fixture prüft den jüngeren Fehlerlauf bei noch erhaltenen
Kindern des älteren Erfolgs, die getrennte Collector-/Finalisierungsgrenze
und die Löschbarkeit der alten Grenze nach neuer Finalisierung. Kinder der
neuen letzten erfolgreichen Aufnahme laufen weiterhin ab. Die vollständige
spätere Collectorprüfung gegen PREVIOUS_RAW_INCOMPLETE und unterdrückte
Kandidaten bleibt vor Aktivierung erforderlich.

Die erweiterte tatsächliche 195-Fixture besteht lokal auf einer eigenen
SQL2025-Instanz. Dieselbe Fixture mit dem ursprünglichen 070-Helper scheitert
gezielt mit 53751 / SC023_WAIT_RETENTION_FAILED_RUN_FENCE. Beide eigenen
Labs sind bereinigt. Der unabhängige Produktreview schließt zwei konkrete
Befunde am Upgradeoracle: Die 1.1.0-Basis enthält nun den gebundenen alten
Helper statt nur einer zurückgesetzten Versionszeile; die direkte Patchroute
liest unveränderte kanonische Quelldateien mit erhaltenem nativem Guard.

Die historische Helperfixture aus `4ca1916c` ist mit UTF-8-/LF-SHA256
`ebf85095ea0800d39ac05daf136a5c6a20d10b3a4742d890883d44ce53cea408` gebunden.
Der Zustandserhaltungscheck erlaubt ausschließlich den beabsichtigten
Definitionsaustausch dieses Helpers und prüft danach dessen neue Definition
bytegenau. Alle übrigen Daten, Policies, Definitionen und gespeicherten
SET-Metadaten bleiben gebunden. Ein nativer Zwischenlauf des fehlerhaften
parserbereinigten Testpfads bestätigt 137; sein Cleanup besteht.

Die korrigierte lokale SQL2025-Abnahme besteht für alle drei tatsächlichen
Patchinstallationswege mit altem Helper und gefülltem 1.1.0-Target. Der
zusätzliche V1-/Wiederholungs-/19-Ablehnungsumfang, Calleroptionen und gezielte
Installationsrechte bestehen ebenfalls. Alle fünf eigenen lokalen
Labversuche sind bereinigt; zwei ersetzte Testzwischenstände qualifizieren
das endgültige Upgrade nicht. Der Abgleich mit SSIS-PR #445 ist konfliktfrei;
die gebundenen Snapshotproduktdateien bleiben unverändert. Die frischen
regulären Head-/Main-Gates prüfen den gemeinsamen Lieferstand und stehen
noch aus. Es wird keine ältere native Patchabnahme behauptet.
